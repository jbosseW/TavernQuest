-- RPG Dungeon Generation & Navigation
-- Extracted from textrpg.lua

local M = {}

local DungeonEnemies = require("dungeonenemies")
local Data = require("rpg_data")

-- Upvalues set by register()
local state
local F
local log

-- Functions wired into F
M.F_FUNCTIONS = {
    "pickDungeonType", "generateDungeonName", "createEmptyFloor",
    "carveRoom", "carveCorridor", "addDoors", "generateDungeonFloor",
    "generateDungeon", "enterDungeon", "exitDungeon", "moveDungeonPlayer",
    "checkDungeonBreach", "createHollowEarthPortal", "enterHollowEarthPortal",
    "getCurrentLayer", "isInHollowEarth", "getLayerFromCoordinates",
    "getDungeonTileType", "enterCustomDungeon",
}

function M.register(s, f)
    state = s
    F = f
    log = function(text, color)
        table.insert(state.textLog, {text = text, color = color or {0.8, 0.8, 0.8}, time = love.timer.getTime()})
        if #state.textLog > 100 then
            table.remove(state.textLog, 1)
        end
    end
    for _, name in ipairs(M.F_FUNCTIONS) do
        if M[name] then
            F[name] = M[name]
        end
    end
end

-- === DUNGEON TILE TYPE LOOKUP ===

-- Get dungeon tile type definition by id (delegates to Data.getDungeonTileType)
M.getDungeonTileType = function(id)
    return Data.getDungeonTileType(id)
end

-- === DUNGEON GENERATION FUNCTIONS ===

-- Pick a random dungeon type based on local biome
M.pickDungeonType = function(worldX, worldY, isWaterTile)
    -- Determine the biome at this location
    local biome = "grass"  -- Default biome

    if worldX and worldY then
        -- Try to get the actual tile type from the world map
        local tile = nil
        if state.world and state.world.mapData and state.world.mapData[worldY] then
            tile = state.world.mapData[worldY][worldX]
        end

        if tile and tile.type then
            biome = tile.type
        elseif isWaterTile then
            biome = "water"
        else
            -- Fallback to distance-based desert detection if tile not available
            local originX, originY = 7, 7
            local dx, dy = worldX - originX, worldY - originY
            local distFromOrigin = math.sqrt(dx*dx + dy*dy)

            if (worldY < 0 and distFromOrigin > 10) or
               (worldY > 20 and distFromOrigin > 15) or
               (worldX > 20 and worldY > 5 and distFromOrigin > 15) then
                biome = "desert"
            end
        end
    elseif isWaterTile then
        biome = "water"
    end

    -- Build available dungeon types for this biome
    local availableTypes = {}
    for _, dtype in ipairs(Data.DUNGEON_TYPES) do
        if dtype.biomes then
            for _, biomeName in ipairs(dtype.biomes) do
                if biomeName == biome then
                    table.insert(availableTypes, dtype)
                    break
                end
            end
        end
    end

    -- If no biome-specific dungeons, fall back to grass/generic dungeons
    if #availableTypes == 0 then
        for _, dtype in ipairs(Data.DUNGEON_TYPES) do
            if dtype.biomes then
                for _, biomeName in ipairs(dtype.biomes) do
                    if biomeName == "grass" then
                        table.insert(availableTypes, dtype)
                        break
                    end
                end
            end
        end
    end

    -- Calculate weights
    local totalWeight = 0
    for _, dtype in ipairs(availableTypes) do
        totalWeight = totalWeight + dtype.weight
    end

    -- Pick dungeon type by weight
    if totalWeight > 0 then
        local roll = math.random(1, totalWeight)
        local cumulative = 0
        for _, dtype in ipairs(availableTypes) do
            cumulative = cumulative + dtype.weight
            if roll <= cumulative then
                return dtype.id
            end
        end
    end

    -- Fallback to generic dungeon
    return "dungeon"
end

M.generateDungeonName = function(dungeonType)
    local typeNames = Data.DUNGEON_NAMES[dungeonType] or Data.DUNGEON_NAMES.dungeon
    local prefix = typeNames.prefixes[math.random(#typeNames.prefixes)]
    local suffix = typeNames.suffixes[math.random(#typeNames.suffixes)]
    return prefix .. " " .. suffix
end

-- Create an empty dungeon floor grid
M.createEmptyFloor = function(width, height)
    local grid = {}
    for y = 1, height do
        grid[y] = {}
        for x = 1, width do
            grid[y][x] = {type = "wall", explored = false, content = nil}
        end
    end
    return grid
end

-- Carve a room into the dungeon grid
M.carveRoom = function(grid, roomX, roomY, roomW, roomH)
    for y = roomY, roomY + roomH - 1 do
        for x = roomX, roomX + roomW - 1 do
            if grid[y] and grid[y][x] then
                grid[y][x].type = "floor"
            end
        end
    end
    return {x = roomX, y = roomY, w = roomW, h = roomH, centerX = math.floor(roomX + roomW/2), centerY = math.floor(roomY + roomH/2)}
end

-- Carve a corridor between two points
M.carveCorridor = function(grid, x1, y1, x2, y2)
    local x, y = x1, y1
    -- Horizontal first, then vertical
    while x ~= x2 do
        if grid[y] and grid[y][x] then
            if grid[y][x].type == "wall" then
                grid[y][x].type = "corridor"
            end
        end
        x = x + (x2 > x1 and 1 or -1)
    end
    while y ~= y2 do
        if grid[y] and grid[y][x] then
            if grid[y][x].type == "wall" then
                grid[y][x].type = "corridor"
            end
        end
        y = y + (y2 > y1 and 1 or -1)
    end
end

-- Check if any of the 4 cardinal neighbors is already a door
local function hasAdjacentDoor(grid, x, y)
    local offsets = {{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
    for _, off in ipairs(offsets) do
        local nx, ny = x + off[1], y + off[2]
        if grid[ny] and grid[ny][nx] and grid[ny][nx].type == "door" then
            return true
        end
    end
    return false
end

-- Helper: find distinct corridor entrance groups along a room edge.
-- Returns a list of entrance groups, where each group is a list of {dx, dy}
-- positions (the room-edge tile where a door could go).
-- Each contiguous run of corridor-adjacent tiles is one group, and we pick
-- at most one door position (the middle of the run) per group.
local function findEntranceGroups(grid, positions, checkPositions)
    -- positions: list of {x=roomX, y=roomY} on the room edge
    -- checkPositions: list of {x=corrX, y=corrY} just outside the room edge
    local groups = {}
    local currentGroup = {}
    for i, pos in ipairs(positions) do
        local cp = checkPositions[i]
        local isCorridorAdj = grid[cp.y] and grid[cp.y][cp.x]
            and grid[cp.y][cp.x].type == "corridor"
        if isCorridorAdj then
            table.insert(currentGroup, pos)
        else
            if #currentGroup > 0 then
                table.insert(groups, currentGroup)
                currentGroup = {}
            end
        end
    end
    if #currentGroup > 0 then
        table.insert(groups, currentGroup)
    end
    return groups
end

-- Add doors at room entrances (max 2 per room, only at room-to-corridor transitions)
M.addDoors = function(grid, rooms)
    for _, room in ipairs(rooms) do
        -- Collect ALL entrance candidates for this room across all 4 edges,
        -- then pick at most 2 to place doors on.
        local candidates = {}

        -- Top edge
        local topPos, topCheck = {}, {}
        for x = room.x, room.x + room.w - 1 do
            table.insert(topPos, {x = x, y = room.y})
            table.insert(topCheck, {x = x, y = room.y - 1})
        end
        for _, group in ipairs(findEntranceGroups(grid, topPos, topCheck)) do
            local mid = group[math.ceil(#group / 2)]
            table.insert(candidates, mid)
        end

        -- Bottom edge
        local botPos, botCheck = {}, {}
        for x = room.x, room.x + room.w - 1 do
            local doorY = room.y + room.h - 1
            local checkY = room.y + room.h
            table.insert(botPos, {x = x, y = doorY})
            table.insert(botCheck, {x = x, y = checkY})
        end
        for _, group in ipairs(findEntranceGroups(grid, botPos, botCheck)) do
            local mid = group[math.ceil(#group / 2)]
            table.insert(candidates, mid)
        end

        -- Left edge
        local leftPos, leftCheck = {}, {}
        for y = room.y, room.y + room.h - 1 do
            table.insert(leftPos, {x = room.x, y = y})
            table.insert(leftCheck, {x = room.x - 1, y = y})
        end
        for _, group in ipairs(findEntranceGroups(grid, leftPos, leftCheck)) do
            local mid = group[math.ceil(#group / 2)]
            table.insert(candidates, mid)
        end

        -- Right edge
        local rightPos, rightCheck = {}, {}
        for y = room.y, room.y + room.h - 1 do
            local doorX = room.x + room.w - 1
            local checkX = room.x + room.w
            table.insert(rightPos, {x = doorX, y = y})
            table.insert(rightCheck, {x = checkX, y = y})
        end
        for _, group in ipairs(findEntranceGroups(grid, rightPos, rightCheck)) do
            local mid = group[math.ceil(#group / 2)]
            table.insert(candidates, mid)
        end

        -- Shuffle candidates so door placement is not biased toward top/left edges
        for i = #candidates, 2, -1 do
            local j = math.random(1, i)
            candidates[i], candidates[j] = candidates[j], candidates[i]
        end

        -- Place at most 2 doors per room from the candidate list
        local maxDoorsPerRoom = 2
        local doorsPlaced = 0
        for _, mid in ipairs(candidates) do
            if doorsPlaced >= maxDoorsPerRoom then break end
            if not hasAdjacentDoor(grid, mid.x, mid.y) then
                grid[mid.y][mid.x].type = "door"
                doorsPlaced = doorsPlaced + 1
            end
        end
    end

    -- Second pass: remove any door that ended up adjacent to another door.
    -- This catches edge cases where doors from different rooms were placed
    -- near each other, or where the placement order allowed neighbors.
    local height = #grid
    local width = grid[1] and #grid[1] or 0
    local toRemove = {}
    for y = 1, height do
        for x = 1, width do
            if grid[y][x].type == "door" then
                if hasAdjacentDoor(grid, x, y) then
                    table.insert(toRemove, {x = x, y = y})
                end
            end
        end
    end
    -- From each cluster of adjacent doors, keep only one (the first in scan order).
    for _, pos in ipairs(toRemove) do
        if grid[pos.y][pos.x].type == "door" and hasAdjacentDoor(grid, pos.x, pos.y) then
            grid[pos.y][pos.x].type = "floor"
        end
    end
end

-- Generate a dungeon floor with rooms and corridors
M.generateDungeonFloor = function(width, height, floorNum, totalFloors, playerLevel, dungeonType)
    local grid = F.createEmptyFloor(width, height)
    local enemyTable = F.getDungeonEnemiesForType(dungeonType)
    local rooms = {}
    local numRooms = math.random(5, 8)
    local attempts = 0
    local maxAttempts = 100

    while #rooms < numRooms and attempts < maxAttempts do
        attempts = attempts + 1
        local roomW = math.random(4, 7)
        local roomH = math.random(4, 6)
        local roomX = math.random(2, width - roomW - 1)
        local roomY = math.random(2, height - roomH - 1)

        -- Check for overlap with existing rooms (with padding)
        local overlaps = false
        for _, existingRoom in ipairs(rooms) do
            if roomX < existingRoom.x + existingRoom.w + 2 and
               roomX + roomW + 2 > existingRoom.x and
               roomY < existingRoom.y + existingRoom.h + 2 and
               roomY + roomH + 2 > existingRoom.y then
                overlaps = true
                break
            end
        end

        if not overlaps then
            local room = F.carveRoom(grid, roomX, roomY, roomW, roomH)
            table.insert(rooms, room)
        end
    end

    -- Connect rooms with corridors
    for i = 2, #rooms do
        F.carveCorridor(grid, rooms[i-1].centerX, rooms[i-1].centerY, rooms[i].centerX, rooms[i].centerY)
    end

    -- Add some random extra connections
    if #rooms > 3 then
        for _ = 1, math.random(1, 2) do
            local r1 = math.random(1, #rooms)
            local r2 = math.random(1, #rooms)
            if r1 ~= r2 then
                F.carveCorridor(grid, rooms[r1].centerX, rooms[r1].centerY, rooms[r2].centerX, rooms[r2].centerY)
            end
        end
    end

    -- Add doors
    F.addDoors(grid, rooms)

    -- Place entrance (stairs up) in first room
    local entranceRoom = rooms[1]
    local entranceX = entranceRoom.centerX
    local entranceY = entranceRoom.centerY
    if floorNum == 1 then
        grid[entranceY][entranceX].type = "entrance"
    else
        grid[entranceY][entranceX].type = "stairs_up"
    end

    -- Place stairs down or exit in last room
    local exitRoom = rooms[#rooms]
    local exitX = exitRoom.centerX
    local exitY = exitRoom.centerY
    if floorNum == totalFloors then
        grid[exitY][exitX].type = "exit"
    else
        grid[exitY][exitX].type = "stairs_down"
    end

    -- Place enemies
    local enemies = {}
    local enemyTier = "shallow"
    if floorNum >= 5 then enemyTier = "deep"
    elseif floorNum >= 3 then enemyTier = "mid" end

    local numEnemies = math.random(3, 5) + math.floor(floorNum / 2)
    for _ = 1, numEnemies do
        local roomIdx = math.random(2, math.max(2, #rooms - 1))  -- Not in entrance or exit room
        local room = rooms[roomIdx]
        if room then
            local ex = math.random(room.x + 1, room.x + room.w - 2)
            local ey = math.random(room.y + 1, room.y + room.h - 2)
            if grid[ey] and grid[ey][ex] and grid[ey][ex].type == "floor" then
                local enemyPool = enemyTable[enemyTier]
                local enemyTemplate = enemyPool[math.random(#enemyPool)]
                local enemy = {
                    id = enemyTemplate.id,
                    name = enemyTemplate.name,
                    hp = math.floor(enemyTemplate.hp * (1 + playerLevel * 0.1)),
                    maxHp = math.floor(enemyTemplate.hp * (1 + playerLevel * 0.1)),
                    atk = math.floor(enemyTemplate.atk * (1 + playerLevel * 0.08)),
                    def = math.floor(enemyTemplate.def * (1 + playerLevel * 0.05)),
                    xp = math.floor(enemyTemplate.xp * (1 + floorNum * 0.2)),
                    gold = math.floor(enemyTemplate.gold * (1 + floorNum * 0.15)),
                    x = ex,
                    y = ey,
                    alive = true
                }
                table.insert(enemies, enemy)
                grid[ey][ex].content = {type = "enemy", data = enemy}
            end
        end
    end

    -- Place boss on final floor
    if floorNum == totalFloors then
        local bossRoom = rooms[math.max(1, #rooms - 1)]
        local bx = bossRoom.centerX
        local by = bossRoom.centerY
        if grid[by] and grid[by][bx] then
            local bossPool = enemyTable.boss
            local bossTemplate = bossPool[math.random(#bossPool)]
            local boss = {
                id = bossTemplate.id,
                name = bossTemplate.name,
                hp = math.floor(bossTemplate.hp * (1 + playerLevel * 0.15)),
                maxHp = math.floor(bossTemplate.hp * (1 + playerLevel * 0.15)),
                atk = math.floor(bossTemplate.atk * (1 + playerLevel * 0.1)),
                def = math.floor(bossTemplate.def * (1 + playerLevel * 0.08)),
                xp = math.floor(bossTemplate.xp * (1 + totalFloors * 0.3)),
                gold = math.floor(bossTemplate.gold * (1 + totalFloors * 0.25)),
                x = bx,
                y = by,
                alive = true,
                isBoss = true
            }
            table.insert(enemies, boss)
            grid[by][bx].content = {type = "enemy", data = boss}
        end
    end

    -- Place treasure chests
    local numChests = math.random(1, 3)
    for _ = 1, numChests do
        local roomIdx = math.random(2, #rooms)
        local room = rooms[roomIdx]
        if room then
            local cx = math.random(room.x, room.x + room.w - 1)
            local cy = math.random(room.y, room.y + room.h - 1)
            if grid[cy] and grid[cy][cx] and grid[cy][cx].type == "floor" and not grid[cy][cx].content then
                local lootTier = "common"
                if floorNum >= 4 or math.random() < 0.2 then lootTier = "uncommon" end
                if floorNum >= 6 or math.random() < 0.1 then lootTier = "rare" end
                local lootPool = Data.DUNGEON_LOOT[lootTier]
                local loot = lootPool[math.random(#lootPool)]
                grid[cy][cx].type = "chest"
                grid[cy][cx].content = {type = "chest", loot = loot, opened = false}
            end
        end
    end

    -- Place traps (hidden)
    local numTraps = math.random(0, 2) + math.floor(floorNum / 3)
    for _ = 1, numTraps do
        local attempts2 = 0
        while attempts2 < 20 do
            attempts2 = attempts2 + 1
            local ty = math.random(2, height - 1)
            local tx = math.random(2, width - 1)
            if grid[ty] and grid[ty][tx] and (grid[ty][tx].type == "floor" or grid[ty][tx].type == "corridor") and not grid[ty][tx].content then
                grid[ty][tx].content = {type = "trap", triggered = false, damage = 10 + floorNum * 5}
                break
            end
        end
    end

    -- Place NPCs (prisoners, etc.) - 30% chance per floor
    local npcs = {}
    if math.random() < 0.3 then
        local roomIdx = math.random(2, #rooms)
        local room = rooms[roomIdx]
        if room then
            local nx = room.centerX + math.random(-1, 1)
            local ny = room.centerY + math.random(-1, 1)
            if grid[ny] and grid[ny][nx] and grid[ny][nx].type == "floor" and not grid[ny][nx].content then
                local npcTemplate = Data.DUNGEON_NPCS[math.random(#Data.DUNGEON_NPCS)]
                local npc = {
                    id = npcTemplate.id,
                    name = npcTemplate.name,
                    dialogue = npcTemplate.dialogue,
                    reward = npcTemplate.reward,
                    rewardId = npcTemplate.rewardId,
                    rewardAmount = npcTemplate.rewardAmount,
                    x = nx,
                    y = ny,
                    rescued = false
                }
                table.insert(npcs, npc)
                grid[ny][nx].content = {type = "npc", data = npc}
            end
        end
    end

    return {
        grid = grid,
        width = width,
        height = height,
        rooms = rooms,
        enemies = enemies,
        npcs = npcs,
        entranceX = entranceX,
        entranceY = entranceY,
        exitX = exitX,
        exitY = exitY,
        floorNum = floorNum
    }
end

-- Generate a complete dungeon with multiple floors
M.generateDungeon = function(worldX, worldY, playerLevel, isWaterDungeon)
    local numFloors = math.random(3, 6)
    local dungeonWidth = 25
    local dungeonHeight = 20

    -- Pick dungeon type (pass coordinates for desert/water detection)
    local dungeonType = F.pickDungeonType(worldX, worldY, isWaterDungeon)

    -- Find the dungeon type info for display color
    local dungeonTypeInfo = nil
    for _, dtype in ipairs(Data.DUNGEON_TYPES) do
        if dtype.id == dungeonType then
            dungeonTypeInfo = dtype
            break
        end
    end

    local dungeon = {
        name = F.generateDungeonName(dungeonType),
        dungeonType = dungeonType,
        dungeonTypeName = dungeonTypeInfo and dungeonTypeInfo.name or "Dungeon",
        dungeonColor = dungeonTypeInfo and dungeonTypeInfo.color or {0.4, 0.3, 0.35},
        floors = {},
        currentFloor = 1,
        totalFloors = numFloors,
        playerX = 0,
        playerY = 0,
        worldX = worldX,
        worldY = worldY,
        cleared = false
    }

    -- Generate all floors with dungeon type
    for i = 1, numFloors do
        dungeon.floors[i] = F.generateDungeonFloor(dungeonWidth, dungeonHeight, i, numFloors, playerLevel, dungeonType)
    end

    -- Set player starting position
    local firstFloor = dungeon.floors[1]
    dungeon.playerX = firstFloor.entranceX
    dungeon.playerY = firstFloor.entranceY

    -- Mark entrance tile as explored
    firstFloor.grid[dungeon.playerY][dungeon.playerX].explored = true

    return dungeon
end

-- === DUNGEON NAVIGATION FUNCTIONS ===

-- Enter a dungeon from the world map
M.enterDungeon = function(worldX, worldY, isWaterDungeon)
    local playerLevel = state.player.level or 1
    state.dungeon = F.generateDungeon(worldX, worldY, playerLevel, isWaterDungeon)
    state.inDungeon = true
    state.phase = "dungeon"
    F.addJournalEvent("exploration", "Entered " .. (state.dungeon.name or "a dungeon"), {0.7, 0.5, 0.8})

    -- Track location for race unlocks
    if not PlayerData.visitedLocations then PlayerData.visitedLocations = {} end
    local locationType = state.dungeon.dungeonType or "dungeon"
    PlayerData.visitedLocations[locationType] = true

    -- Track specific locations for unlocks (e.g., void_sanctum would be tracked here)
    if state.dungeon.name and state.dungeon.name:lower():match("void") then
        PlayerData.visitedLocations["void_sanctum"] = true
    end

    -- Explore tiles around player
    local floor = state.dungeon.floors[state.dungeon.currentFloor]
    for dy = -1, 1 do
        for dx = -1, 1 do
            local nx, ny = state.dungeon.playerX + dx, state.dungeon.playerY + dy
            if floor.grid[ny] and floor.grid[ny][nx] then
                floor.grid[ny][nx].explored = true
            end
        end
    end

    -- Type-specific entry message
    local typeColor = state.dungeon.dungeonColor or {0.7, 0.5, 0.8}
    local typeMsg = ""
    if state.dungeon.dungeonType == "lich_lair" then
        typeMsg = " An overwhelming sense of dread washes over you. The dead walk these halls..."
        log("You enter " .. state.dungeon.name .. "...", {0.4, 0.1, 0.5})
        log(typeMsg, {0.5, 0.2, 0.6})
        log("WARNING: This is a Lich's domain. Prepare for the fight of your life!", {0.9, 0.3, 0.3})
        -- Register this lich lair with the world system
        local WorldGen = require("worldgen")
        local dungeonData = WorldGen.getDungeonAt(worldX, worldY)
        if dungeonData and dungeonData.isLichLair then
            WorldGen.registerLichLair(dungeonData)
        end
    elseif state.dungeon.dungeonType == "vampire_den" then
        typeMsg = " The air reeks of death and blood..."
        log("You enter " .. state.dungeon.name .. "...", {0.6, 0.2, 0.3})
        log(typeMsg, {0.5, 0.15, 0.2})
        -- Generate vampire sighting rumor
        local RumorSystem = require("rumorsystem")
        RumorSystem.init(state)
        RumorSystem.onVampireSighting(worldX, worldY, state.dungeon.name, nil)
    elseif state.dungeon.dungeonType == "crypt" then
        typeMsg = " Ancient bones crunch beneath your feet..."
        log("You enter " .. state.dungeon.name .. "...", {0.5, 0.5, 0.6})
        log(typeMsg, {0.4, 0.4, 0.5})
        -- Generate ghost sighting rumor (crypts often have ghosts)
        if math.random() < 0.5 then
            local RumorSystem = require("rumorsystem")
            RumorSystem.init(state)
            RumorSystem.onGhostSighting(worldX, worldY, state.dungeon.name, nil)
        end
    elseif state.dungeon.dungeonType == "cave" then
        typeMsg = " Dripping water echoes in the darkness..."
        log("You enter " .. state.dungeon.name .. "...", {0.4, 0.5, 0.6})
        log(typeMsg, {0.35, 0.45, 0.55})
    elseif state.dungeon.dungeonType == "mine" then
        typeMsg = " Old mining equipment litters the tunnels..."
        log("You enter " .. state.dungeon.name .. "...", {0.5, 0.45, 0.4})
        log(typeMsg, {0.45, 0.4, 0.35})
    elseif state.dungeon.dungeonType == "ocean_cave" then
        typeMsg = " Bioluminescent algae light the dripping walls..."
        log("You dive into " .. state.dungeon.name .. "...", {0.2, 0.4, 0.6})
        log(typeMsg, {0.3, 0.5, 0.7})
    elseif state.dungeon.dungeonType == "sunken_ship" then
        typeMsg = " Barnacle-encrusted timbers creak ominously..."
        log("You board " .. state.dungeon.name .. "...", {0.35, 0.3, 0.25})
        log(typeMsg, {0.4, 0.35, 0.3})
    elseif state.dungeon.dungeonType == "underwater_ruins" then
        typeMsg = " Ancient coral-covered columns stretch into the gloom..."
        log("You descend into " .. state.dungeon.name .. "...", {0.3, 0.5, 0.45})
        log(typeMsg, {0.25, 0.45, 0.4})
    elseif state.dungeon.dungeonType == "sea_fortress" then
        typeMsg = " Waves crash against the fortress walls as you enter..."
        log("You breach " .. state.dungeon.name .. "...", {0.4, 0.4, 0.5})
        log(typeMsg, {0.35, 0.35, 0.45})
    elseif state.dungeon.dungeonType == "kraken_lair" then
        typeMsg = " Massive tentacle marks score the walls. Something enormous lives here..."
        log("You enter " .. state.dungeon.name .. "...", {0.15, 0.2, 0.4})
        log(typeMsg, {0.2, 0.25, 0.5})
        log("WARNING: A Kraken dwells in these depths. Only the bravest survive!", {0.9, 0.3, 0.3})
    else
        log("You enter " .. state.dungeon.name .. "...", {0.7, 0.5, 0.8})
    end
    log("Floor 1 of " .. state.dungeon.totalFloors .. " (" .. state.dungeon.dungeonTypeName .. ")", {0.6, 0.6, 0.7})
end

-- Exit the dungeon back to world map
M.exitDungeon = function()
    if state.dungeon then
        -- Check if this was a town vampire lair that was cleared
        if state.dungeon.isTownLair and state.dungeon.bossDefeated then
            local townId = state.dungeon.lairTownId
            if townId and state.townVampireLairs and state.townVampireLairs[townId] then
                -- Remove the vampire lair from the town
                local townName = state.townVampireLairs[townId].townName or "the town"
                state.townVampireLairs[townId] = nil
                log("\xF0\x9F\x8F\x86 You have purged the vampire nest from " .. townName .. "!", {0.9, 0.7, 0.2})

                -- Generate hero rumor for clearing the lair
                local RumorSystem = require("rumorsystem")
                RumorSystem.init(state)
                RumorSystem.createRumorFromEvent(RumorSystem.TYPES.HERO, {
                    locationName = townName,
                })

                -- Reward the player
                local goldReward = math.random(200, 500)
                state.player.gold = state.player.gold + goldReward
                log("The grateful townsfolk reward you with " .. goldReward .. " gold!", {0.8, 0.8, 0.3})
            end
            -- Town lair - return to town instead of world map
            state.dungeon = nil
            state.inDungeon = false
            state.phase = "town"
            log("You climb back up into " .. (state.world.currentTown and state.world.currentTown.name or "town") .. ".", {0.7, 0.8, 0.5})
            return
        end

        state.world.playerX = state.dungeon.worldX
        state.world.playerY = state.dungeon.worldY
    end
    state.dungeon = nil
    state.inDungeon = false
    state.phase = "map"
    log("You emerge from the dungeon into daylight.", {0.7, 0.8, 0.5})
end

-- Move player within dungeon
M.moveDungeonPlayer = function(dx, dy)
    if not state.dungeon then return false end

    local floor = state.dungeon.floors[state.dungeon.currentFloor]
    local newX = state.dungeon.playerX + dx
    local newY = state.dungeon.playerY + dy

    -- Check bounds
    if newY < 1 or newY > floor.height or newX < 1 or newX > floor.width then
        return false
    end

    local tile = floor.grid[newY][newX]
    local tileType = F.getDungeonTileType(tile.type)

    -- Check if passable
    if not tileType.passable then
        return false
    end

    -- Move player
    state.dungeon.playerX = newX
    state.dungeon.playerY = newY
    tile.explored = true

    -- Passive mana regen: recover 1 MP per step while exploring
    if state.player and state.player.mana and state.player.maxMana then
        local manaRegen = state.player.manaRegen or 1
        state.player.mana = math.min(state.player.maxMana, state.player.mana + manaRegen)
    end

    -- Explore adjacent tiles
    for ddy = -1, 1 do
        for ddx = -1, 1 do
            local nx, ny = newX + ddx, newY + ddy
            if floor.grid[ny] and floor.grid[ny][nx] then
                floor.grid[ny][nx].explored = true
            end
        end
    end

    -- Advance chasing dungeon enemies by one step (turn-based chase)
    DungeonEnemies.onPlayerMoved()

    -- Check collision with visible dungeon enemies (moving AI entities)
    local collidedVisEnemy, collidedVisIndex = DungeonEnemies.checkPlayerCollision()
    if collidedVisEnemy then
        DungeonEnemies.triggerCombat(collidedVisEnemy, collidedVisIndex)
        return true
    end

    -- Handle tile content (static enemies still use the old system as fallback)
    if tile.content then
        if tile.content.type == "enemy" and tile.content.data.alive then
            -- Start combat with dungeon enemy
            local enemy = tile.content.data
            log("You encounter " .. enemy.name .. "!", {0.9, 0.5, 0.3})
            local enemies = {{
                id = enemy.id,
                name = enemy.name,
                hp = enemy.hp,
                maxHp = enemy.maxHp,
                atk = enemy.atk,
                def = enemy.def,
                xp = enemy.xp,
                gold = enemy.gold,
                isBoss = enemy.isBoss
            }}
            F.startCombat(enemies)
            tile.content.data.alive = false
            tile.content = nil
            return true
        elseif tile.content.type == "trap" and not tile.content.triggered then
            -- Trigger trap
            tile.content.triggered = true
            local damage = tile.content.damage
            state.player.hp = math.max(1, state.player.hp - damage)
            log("You triggered a trap! Took " .. damage .. " damage!", {0.9, 0.3, 0.3})
            return true
        elseif tile.content.type == "npc" and not tile.content.data.rescued then
            -- Interact with NPC
            local npc = tile.content.data
            log(npc.name .. ": \"" .. npc.dialogue .. "\"", {0.7, 0.8, 0.5})
            npc.rescued = true
            -- Give reward
            if npc.reward == "gold" then
                state.player.gold = state.player.gold + npc.rewardAmount
                log("Received " .. npc.rewardAmount .. " gold!", {0.9, 0.8, 0.2})
            elseif npc.reward == "mana" then
                state.player.mana = math.min(state.player.maxMana, state.player.mana + npc.rewardAmount)
                log("Recovered " .. npc.rewardAmount .. " mana!", {0.4, 0.6, 0.9})
            end
            return true
        elseif tile.content.type == "chest" and not tile.content.opened then
            -- Open chest
            tile.content.opened = true
            local loot = tile.content.loot
            if loot.type == "gold" then
                local amount = math.random(loot.minAmount, loot.maxAmount)
                state.player.gold = state.player.gold + amount
                log("Found " .. amount .. " gold in the chest!", {0.9, 0.8, 0.2})
            else
                log("Found " .. loot.name .. "!", {0.7, 0.9, 0.5})
                -- Add to inventory if possible
            end
            tile.type = "floor"  -- Chest becomes floor after opening
            return true
        end
    end

    -- Handle prison-specific interactions
    if state.inPrisonEscape and state.prisonEscape then
        if F.handlePrisonInteraction(tile, state.dungeon.playerX, state.dungeon.playerY) then
            return true
        end
    end

    -- Handle special tiles
    if tile.type == "entrance" and state.dungeon.currentFloor == 1 then
        -- Option to leave dungeon will be shown
    elseif tile.type == "hollow_portal" then
        -- Hollow Earth Portal
        if tile.portalData then
            log("You stand before a shimmering portal to the Hollow Earth.", {0.6, 0.8, 1.0})
            log("Destination: " .. (tile.portalData.targetRegion or "Unknown"), {0.7, 0.9, 0.8})
            log("Press [SPACE] to enter the portal, or move away to leave it.", {0.8, 0.8, 0.9})
            state.standingOnPortal = true
            state.portalData = tile.portalData
        end
    elseif tile.type == "stairs_down" then
        -- Go down to next floor
        if state.dungeon.currentFloor < state.dungeon.totalFloors then
            state.dungeon.currentFloor = state.dungeon.currentFloor + 1
            if state.inPrisonEscape and state.prisonEscape then
                state.prisonEscape.currentFloor = state.dungeon.currentFloor
            end
            local nextFloor = state.dungeon.floors[state.dungeon.currentFloor]
            state.dungeon.playerX = nextFloor.entranceX
            state.dungeon.playerY = nextFloor.entranceY
            nextFloor.grid[state.dungeon.playerY][state.dungeon.playerX].explored = true
            log("You descend to floor " .. state.dungeon.currentFloor .. "...", {0.5, 0.6, 0.8})
            -- Explore around new position
            for ddy = -1, 1 do
                for ddx = -1, 1 do
                    local nx, ny = state.dungeon.playerX + ddx, state.dungeon.playerY + ddy
                    if nextFloor.grid[ny] and nextFloor.grid[ny][nx] then
                        nextFloor.grid[ny][nx].explored = true
                    end
                end
            end

            -- Check for hollow earth breach
            F.checkDungeonBreach()
        end
    elseif tile.type == "stairs_up" then
        -- Go up to previous floor
        if state.dungeon.currentFloor > 1 then
            state.dungeon.currentFloor = state.dungeon.currentFloor - 1
            if state.inPrisonEscape and state.prisonEscape then
                state.prisonEscape.currentFloor = state.dungeon.currentFloor
            end
            local prevFloor = state.dungeon.floors[state.dungeon.currentFloor]
            state.dungeon.playerX = prevFloor.exitX
            state.dungeon.playerY = prevFloor.exitY
            log("You ascend to floor " .. state.dungeon.currentFloor .. "...", {0.6, 0.8, 0.5})
        end
    elseif tile.type == "exit" then
        -- Dungeon cleared!
        state.dungeon.cleared = true
        log("You found the dungeon exit!", {0.9, 0.9, 0.3})
        -- Bonus rewards for clearing
        local bonusGold = 50 * state.dungeon.totalFloors
        local bonusXP = 100 * state.dungeon.totalFloors

        -- Lich lairs give massive bonus rewards and cleanse the corruption
        if state.dungeon.dungeonType == "lich_lair" then
            bonusGold = bonusGold * 5  -- 5x gold for lich lairs
            bonusXP = bonusXP * 5      -- 5x XP for lich lairs
            log("THE LICH HAS BEEN DESTROYED!", {0.9, 0.8, 0.2})
            log("The corruption begins to fade from the land...", {0.5, 0.9, 0.5})

            -- Cleanse the corruption from the world
            local WorldGen = require("worldgen")
            local dungeonId = "dungeon_" .. state.dungeon.worldX .. "_" .. state.dungeon.worldY
            local cleansedCount = WorldGen.cleanseLichCorruption(dungeonId)
            if cleansedCount > 0 then
                log(cleansedCount .. " corrupted tiles have been cleansed!", {0.4, 0.9, 0.4})
            end

            -- Mark the dungeon as defeated in worldgen
            WorldGen.markDungeonCleared(state.dungeon.worldX, state.dungeon.worldY)
        end

        state.player.gold = state.player.gold + bonusGold
        state.player.xp = state.player.xp + bonusXP
        log("Dungeon cleared! +" .. bonusGold .. " gold, +" .. bonusXP .. " XP!", {0.9, 0.8, 0.2})
        F.exitDungeon()
        return true
    elseif tile.type == "escape_exit" then
        -- Prison escape exit
        if state.inPrisonEscape then
            log("You reach the escape route! Freedom awaits!", {0.2, 0.9, 0.2})
            F.completePrisonEscape()
            return true
        else
            -- Treat as normal exit if not in prison
            F.exitDungeon()
            return true
        end
    end

    return true
end

-- ============================================================================
--                     HOLLOW EARTH BREACH SYSTEM
-- ============================================================================

M.checkDungeonBreach = function()
    if not state.dungeon then return end

    -- Only check on floor 15+
    if state.dungeon.currentFloor < 15 then return end

    -- Check if already breached
    if state.dungeon.hasBreached then return end

    -- Call WorldGen to check for breach
    local WorldGen = require("worldgen")
    local hasBreached, targetRegion, breachType = WorldGen.checkHollowEarthBreach(
        state.dungeon.currentFloor,
        state.dungeon.dungeonType or "dungeon",
        state.currentRegion or "unknown",
        state.dungeon.worldX,
        state.dungeon.worldY
    )

    if not hasBreached then
        -- Show warning signs as you go deeper
        if state.dungeon.currentFloor == 15 then
            log("The air grows strange here. Heavy. As if vast emptiness presses from beyond the walls.", {0.7, 0.7, 0.8})
        elseif state.dungeon.currentFloor == 18 then
            log("Cracks appear in the stone. Ancient cracks. You hear... something. Distant. Breathing?", {0.7, 0.8, 0.7})
        elseif state.dungeon.currentFloor == 20 then
            log("The walls are thin here. You sense it. Something vast lies beyond.", {0.8, 0.8, 0.6})
        end
        return
    end

    -- BREACH EVENT!
    state.dungeon.hasBreached = true
    state.dungeon.breachRegion = targetRegion
    state.dungeon.breachType = breachType

    -- Get breach description from WorldGen
    local desc = WorldGen.getBreachDescription(breachType, targetRegion)

    -- Dramatic announcement
    log("", {1, 1, 1})  -- Empty line for drama
    log("\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90", {0.9, 0.6, 0.3})
    log("    THE WALLS CRACK BENEATH YOUR FEET    ", {0.9, 0.8, 0.3})
    log("\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90", {0.9, 0.6, 0.3})
    log("", {1, 1, 1})
    log("Ancient stone that has held for millennia suddenly gives way.", {0.8, 0.7, 0.6})
    log("The floor beneath you SHATTERS.", {0.9, 0.6, 0.4})
    log("", {1, 1, 1})
    log(desc.prefix .. " " .. desc[targetRegion] or "a vast darkness below.", {0.7, 0.9, 0.7})
    log("", {1, 1, 1})
    log("You've broken through to THE HOLLOW EARTH.", {1, 0.9, 0.3})
    log("", {1, 1, 1})

    -- Create portal tile in a nearby room
    F.createHollowEarthPortal(breachType, targetRegion)
end

M.createHollowEarthPortal = function(breachType, targetRegion)
    if not state.dungeon then return end

    local floor = state.dungeon.floors[state.dungeon.currentFloor]

    -- Find a suitable location for the portal (in a random room, not on stairs or entrance)
    local attempts = 0
    while attempts < 50 do
        attempts = attempts + 1
        local px = math.random(2, floor.width - 1)
        local py = math.random(2, floor.height - 1)

        if floor.grid[py] and floor.grid[py][px] then
            local tile = floor.grid[py][px]
            if tile.type == "floor" and not tile.content then
                -- Create portal here
                tile.type = "hollow_portal"
                tile.portalData = {
                    targetRegion = targetRegion,
                    breachType = breachType,
                    hollowX = state.dungeon.worldX,
                    hollowY = state.dungeon.worldY - 1000,  -- Offset to hollow layer
                    isPermanent = (breachType == "major_breach"),
                    discovered = true
                }

                -- Mark the portal location
                state.dungeon.portalX = px
                state.dungeon.portalY = py

                log("A shimmering portal appears nearby, leading into the breach!", {0.6, 0.8, 1.0})
                log("You can use it to descend into the Hollow Earth.", {0.7, 0.7, 0.9})
                if breachType ~= "major_breach" then
                    log("WARNING: This portal looks unstable. It may not remain open long.", {0.9, 0.6, 0.4})
                end

                return
            end
        end
    end

    log("The breach opened, but you can't reach it safely from here.", {0.9, 0.7, 0.5})
end

M.enterHollowEarthPortal = function(portalData)
    if not portalData then
        log("Error: No portal data available.", {0.9, 0.3, 0.3})
        return
    end

    -- Dramatic transition
    log("", {1, 1, 1})
    log("\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90", {0.7, 0.9, 1.0})
    log("    YOU DESCEND INTO THE HOLLOW EARTH    ", {0.7, 0.9, 1.0})
    log("\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90\xE2\x95\x90", {0.7, 0.9, 1.0})
    log("", {1, 1, 1})
    log("Reality shifts. Gravity pulls you DOWN.", {0.8, 0.8, 0.9})
    log("The world inverts. What was beneath is now... everywhere.", {0.7, 0.8, 0.9})
    log("", {1, 1, 1})

    -- Update player position to hollow earth layer
    local hollowX = portalData.hollowX or state.x
    local hollowY = portalData.hollowY or (state.y - 1000)

    -- Set current layer to HOLLOW
    state.world = state.world or {}
    state.world.currentLayer = "HOLLOW"

    -- Teleport player
    state.x = hollowX
    state.y = hollowY

    -- Exit dungeon to hollow earth surface
    F.exitDungeon()

    -- Welcome message
    log("You emerge in " .. (portalData.targetRegion or "the Hollow Earth") .. ".", {0.6, 0.9, 0.7})
    log("The air here is different. Heavy. Ancient.", {0.7, 0.8, 0.8})
    log("Above you, where sky should be... only darkness. And stone.", {0.8, 0.8, 0.9})
    log("Bioluminescent light emanates from the walls and vegetation.", {0.6, 0.8, 0.9})
    log("", {1, 1, 1})
    log("Welcome to the world beneath the world.", {0.7, 0.9, 1.0})

    -- Mark that player has discovered hollow earth
    state.hollowEarthDiscovered = true
end

M.getCurrentLayer = function()
    if not state.world then return "SURFACE" end
    return state.world.currentLayer or "SURFACE"
end

M.isInHollowEarth = function()
    return F.getCurrentLayer() == "HOLLOW"
end

M.getLayerFromCoordinates = function(x, y)
    -- Hollow earth is Y < -500 (using -1000 offset)
    if y < -500 then
        return "HOLLOW"
    else
        return "SURFACE"
    end
end

-- Enter a custom dungeon from the map editor
-- grid: 2D array [y][x] = {type = "wall"/"floor"/etc, explored = false}
-- width, height: grid dimensions
-- mapName: display name for the dungeon
M.enterCustomDungeon = function(grid, width, height, mapName)
    -- Find entrance (stairs_up or entrance tile) and exit (stairs_down or exit tile)
    local entranceX, entranceY, exitX, exitY
    for y = 1, height do
        for x = 1, width do
            if grid[y] and grid[y][x] then
                local t = grid[y][x].type
                if (t == "stairs_up" or t == "entrance") and not entranceX then
                    entranceX, entranceY = x, y
                elseif (t == "stairs_down" or t == "exit") and not exitX then
                    exitX, exitY = x, y
                end
            end
        end
    end

    -- Fallback: if no entrance/exit found, use first/last floor tile
    if not entranceX then
        for y = 1, height do
            for x = 1, width do
                if grid[y] and grid[y][x] and grid[y][x].type == "floor" then
                    entranceX, entranceY = x, y
                    break
                end
            end
            if entranceX then break end
        end
    end
    if not exitX then
        for y = height, 1, -1 do
            for x = width, 1, -1 do
                if grid[y] and grid[y][x] and grid[y][x].type == "floor" then
                    exitX, exitY = x, y
                    break
                end
            end
            if exitX then break end
        end
    end

    if not entranceX or not exitX then
        if log then log("Cannot enter dungeon: no valid entrance or exit tiles!", {0.9, 0.3, 0.3}) end
        return false
    end

    -- Mark all tiles as explored (custom maps are fully visible)
    for y = 1, height do
        for x = 1, width do
            if grid[y] and grid[y][x] then
                grid[y][x].explored = true
            end
        end
    end

    -- Detect rooms for the floor data (flood-fill floor regions)
    local rooms = {}
    local visited = {}
    for y = 1, height do
        visited[y] = {}
    end
    for y = 1, height do
        for x = 1, width do
            if not visited[y][x] and grid[y][x] and grid[y][x].type == "floor" then
                -- Flood fill to find this room's extent
                local minX, minY, maxX, maxY = x, y, x, y
                local stack = {{x = x, y = y}}
                visited[y][x] = true
                while #stack > 0 do
                    local pos = table.remove(stack)
                    if pos.x < minX then minX = pos.x end
                    if pos.y < minY then minY = pos.y end
                    if pos.x > maxX then maxX = pos.x end
                    if pos.y > maxY then maxY = pos.y end
                    local dirs = {{0,-1},{0,1},{-1,0},{1,0}}
                    for _, d in ipairs(dirs) do
                        local nx, ny = pos.x + d[1], pos.y + d[2]
                        if ny >= 1 and ny <= height and nx >= 1 and nx <= width
                           and not visited[ny][nx] and grid[ny][nx] and grid[ny][nx].type == "floor" then
                            visited[ny][nx] = true
                            table.insert(stack, {x = nx, y = ny})
                        end
                    end
                end
                table.insert(rooms, {
                    x = minX, y = minY,
                    w = maxX - minX + 1, h = maxY - minY + 1,
                    centerX = math.floor((minX + maxX) / 2),
                    centerY = math.floor((minY + maxY) / 2),
                })
            end
        end
    end

    -- Build single-floor dungeon
    local floorData = {
        grid = grid,
        width = width,
        height = height,
        rooms = rooms,
        enemies = {},
        npcs = {},
        entranceX = entranceX,
        entranceY = entranceY,
        exitX = exitX,
        exitY = exitY,
        floorNum = 1,
    }

    state.dungeon = {
        name = mapName or "Custom Dungeon",
        dungeonType = "custom",
        dungeonTypeName = "Custom Map",
        dungeonColor = {0.5, 0.7, 0.9},
        floors = { floorData },
        currentFloor = 1,
        totalFloors = 1,
        playerX = entranceX,
        playerY = entranceY,
        worldX = 0,
        worldY = 0,
        cleared = false,
    }

    state.inDungeon = true
    state.phase = "dungeon"

    if log then
        log("You enter " .. (mapName or "a custom dungeon") .. "...", {0.5, 0.7, 0.9})
        log("Floor 1 of 1 (Custom Map)", {0.6, 0.6, 0.7})
    end

    return true
end

return M
