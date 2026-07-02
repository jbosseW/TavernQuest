-- Map Enemies System
-- Visible enemies on the world map with patrol/chase AI, vision cones,
-- and collision-triggered combat.

local MapEnemies = {}
local EnemyAI = require("enemyai")

-- Dependencies (loaded lazily)
local WorldGen
local StealthSystem = nil
pcall(function() StealthSystem = require("stealth_system") end)

-- Reference to game state and log function (set via init)
local state = nil
local log = function(text, color)
    if _G.log then _G.log(text, color) end
end

-- Reference to external functions (set via init)
local generateEncounterFn = nil
local createEnemyInstanceFn = nil
local startCombatFn = nil
local getTileTypeFn = nil
local getEnemiesTableFn = nil

-- ============================================================================
--                              CONFIGURATION
-- ============================================================================

local CONFIG = {
    -- Spawning
    spawnDensity = 25,               -- Average tiles per enemy in a region
    maxEnemiesPerChunk = 4,          -- Cap per 16x16 chunk
    maxTotalEnemies = 80,            -- Hard cap on total map enemies
    spawnRadius = 12,                -- Spawn within this range of player view
    despawnRadius = 30,              -- Remove enemies beyond this range
    minSpawnDistFromPlayer = 5,      -- Don't spawn too close to player
    minSpawnDistFromTown = 3,        -- Don't spawn adjacent to towns
    respawnCooldown = 60,            -- Seconds before area can respawn enemies

    -- Movement
    patrolMoveInterval = 1.2,        -- Seconds between patrol moves
    chaseMoveInterval = 0.6,         -- Seconds between chase moves
    idleDuration = 3.0,              -- Seconds idle before resuming patrol
    returnToPatrolDist = 8,          -- Legacy (chase give-up now uses 2x detectionRadius)

    -- Detection
    lineOfSightBlockers = {          -- Tile types that block line of sight
        town = true,
        mountain = true,
        water = true,
    },

    -- Animation
    pulseSpeed = 3.0,                -- Enemy icon pulse animation speed
    visionConeAlpha = 0.22,          -- Base alpha for vision cone overlay
}

-- ============================================================================
--                         ENEMY TYPE DEFINITIONS
-- ============================================================================

-- Map enemy types with different behaviors.
-- The "enemyIds" field references ENEMIES table ids from textrpg.lua so
-- combat encounters match the correct enemy data.
local MAP_ENEMY_TYPES = {
    bandit = {
        name = "Bandits",
        icon = "B",
        color = {0.8, 0.3, 0.3},
        detectionRadius = 4,
        perception = 12,  -- Experienced outlaws, watchful
        patrolMoveInterval = 1.0,
        chaseMoveInterval = 0.5,
        minCR = 2,
        maxCR = 3,
        enemyIds = {"bandit", "goblin_warrior"},
        biomes = {"grass", "forest", "ruins", "desert", "sand_dunes", "badlands"},
        minDistFromStart = 0,
        maxDistFromStart = 999,
        groupSize = {1, 3},
        dangerIcon = "!",
    },
    wolf = {
        name = "Wolf Pack",
        icon = "W",
        color = {0.5, 0.5, 0.6},
        detectionRadius = 5,
        perception = 16,  -- Keen animal senses
        patrolMoveInterval = 0.9,
        chaseMoveInterval = 0.45,
        minCR = 1,
        maxCR = 2,
        enemyIds = {"wolf"},
        biomes = {"grass", "forest", "mountain", "swamp", "ice"},
        minDistFromStart = 0,
        maxDistFromStart = 999,
        groupSize = {2, 4},
        dangerIcon = "!",
    },
    skeleton = {
        name = "Undead",
        icon = "K",
        color = {0.7, 0.7, 0.8},
        detectionRadius = 3,
        perception = 6,   -- Mindless, poor senses
        patrolMoveInterval = 1.5,
        chaseMoveInterval = 0.8,
        minCR = 0.5,
        maxCR = 2,
        enemyIds = {"skeleton", "skeleton_knight", "zombie"},
        biomes = {"ruins", "corrupted", "swamp", "dungeon"},
        minDistFromStart = 3,
        maxDistFromStart = 999,
        groupSize = {1, 3},
        dangerIcon = "!",
    },
    goblin = {
        name = "Goblins",
        icon = "G",
        color = {0.3, 0.7, 0.3},
        detectionRadius = 3,
        perception = 8,   -- Small, easily distracted
        patrolMoveInterval = 1.1,
        chaseMoveInterval = 0.65,
        minCR = 0.5,
        maxCR = 1,
        enemyIds = {"goblin", "goblin_warrior"},
        biomes = {"grass", "forest", "swamp", "mountain"},
        minDistFromStart = 0,
        maxDistFromStart = 50,
        groupSize = {2, 4},
        dangerIcon = "!",
    },
    orc = {
        name = "Orc Raiders",
        icon = "O",
        color = {0.6, 0.4, 0.2},
        detectionRadius = 4,
        perception = 10,  -- Average awareness
        patrolMoveInterval = 1.0,
        chaseMoveInterval = 0.55,
        minCR = 2,
        maxCR = 3,
        enemyIds = {"orc", "orc_warlord"},
        biomes = {"grass", "desert", "mountain", "ruins", "sand_dunes", "badlands"},
        minDistFromStart = 8,
        maxDistFromStart = 999,
        groupSize = {1, 3},
        dangerIcon = "!!",
    },
    spider = {
        name = "Giant Spiders",
        icon = "X",
        color = {0.4, 0.2, 0.4},
        detectionRadius = 3,
        perception = 14,  -- Vibration/tremor sense
        patrolMoveInterval = 1.3,
        chaseMoveInterval = 0.7,
        minCR = 1,
        maxCR = 1,
        enemyIds = {"spider"},
        biomes = {"forest", "swamp", "ruins", "dungeon"},
        minDistFromStart = 2,
        maxDistFromStart = 999,
        groupSize = {1, 3},
        dangerIcon = "!",
    },
    troll = {
        name = "Troll",
        icon = "T",
        color = {0.3, 0.5, 0.3},
        detectionRadius = 3,
        perception = 7,   -- Dim-witted, relies on smell
        patrolMoveInterval = 1.6,
        chaseMoveInterval = 0.9,
        minCR = 3,
        maxCR = 3,
        enemyIds = {"troll", "ogre"},
        biomes = {"mountain", "swamp", "forest", "ruins"},
        minDistFromStart = 12,
        maxDistFromStart = 999,
        groupSize = {1, 1},
        dangerIcon = "!!",
    },
    demon = {
        name = "Demons",
        icon = "D",
        color = {0.8, 0.2, 0.2},
        detectionRadius = 4,
        perception = 18,  -- Supernatural senses
        patrolMoveInterval = 1.1,
        chaseMoveInterval = 0.5,
        minCR = 4,
        maxCR = 5,
        enemyIds = {"demon", "imp"},
        biomes = {"corrupted", "ruins", "desert"},
        minDistFromStart = 20,
        maxDistFromStart = 999,
        groupSize = {1, 2},
        dangerIcon = "!!!",
    },
    vampire = {
        name = "Vampire",
        icon = "V",
        color = {0.5, 0.1, 0.2},
        detectionRadius = 5,
        perception = 20,  -- Supernatural night vision, blood sense
        patrolMoveInterval = 1.0,
        chaseMoveInterval = 0.45,
        minCR = 4,
        maxCR = 5,
        enemyIds = {"vampire", "vampire_lord"},
        biomes = {"forest", "swamp", "ruins", "corrupted"},
        minDistFromStart = 15,
        maxDistFromStart = 999,
        groupSize = {1, 1},
        dangerIcon = "!!!",
    },
}

-- ============================================================================
--                              INITIALIZATION
-- ============================================================================

function MapEnemies.init(gameState, callbacks)
    state = gameState
    if callbacks then
        generateEncounterFn = callbacks.generateEncounter
        createEnemyInstanceFn = callbacks.createEnemyInstance
        startCombatFn = callbacks.startCombat
        getTileTypeFn = callbacks.getTileType
        getEnemiesTableFn = callbacks.getEnemiesTable
    end
    WorldGen = require("worldgen")
end

function MapEnemies.setLogFunction(logFunc)
    log = logFunc
end

-- ============================================================================
--                          HELPER FUNCTIONS
-- ============================================================================

-- Get the starting town position for distance calculations
local function getStartPosition()
    if state and state.world and state.world.homeTown then
        local ht = state.world.homeTown
        local x = ht.x or (ht.position and ht.position.x) or 35
        local y = ht.y or (ht.position and ht.position.y) or 42
        return x, y
    end
    return 35, 42  -- Default human start
end

-- Distance functions (delegated to shared EnemyAI module)
local manhattanDist = EnemyAI.manhattanDist
local euclideanDist = EnemyAI.euclideanDist

-- Tile types that block enemy movement (hoisted for performance)
local BLOCKED_TILES = {
    town = true,
    water = true,
    deep_ocean = true,
    shallow_water = true,
    coastal = true,
    river = true,
    lake = true,
    whirlpool = true,
    shipwreck = true,
    ocean_cave = true,
}

-- Check if a tile is passable for enemy movement
local function isTilePassableForEnemy(x, y)
    local tile = WorldGen.getTile(x, y)
    if not tile then return false end
    if BLOCKED_TILES[tile.type] then return false end
    return true
end

-- Check if a tile is suitable for enemy spawning
local function isTileSuitableForSpawn(x, y, enemyType)
    local tile = WorldGen.getTile(x, y)
    if not tile then return false end
    if not tile.explored then return false end  -- Only spawn on explored tiles (visible to player)

    -- Check biome match
    local biomeMatch = false
    for _, biome in ipairs(enemyType.biomes) do
        if tile.type == biome then
            biomeMatch = true
            break
        end
    end
    if not biomeMatch then return false end

    -- Check distance from starting town
    local startX, startY = getStartPosition()
    local dist = euclideanDist(x, y, startX, startY)
    if dist < enemyType.minDistFromStart or dist > enemyType.maxDistFromStart then
        return false
    end

    -- Check distance from towns
    if state.world and state.world.useWorldGen then
        -- Check if any anchor town is too close
        local anchorTowns = WorldGen.getAnchorTowns()
        if anchorTowns then
            for _, anchor in ipairs(anchorTowns) do
                local ax = anchor.position and anchor.position.x or anchor.x
                local ay = anchor.position and anchor.position.y or anchor.y
                if ax and ay then
                    local townDist = manhattanDist(x, y, ax, ay)
                    if townDist < CONFIG.minSpawnDistFromTown then
                        return false
                    end
                end
            end
        end
    end

    return true
end

-- LOS blocker check for world map tiles (passed to EnemyAI.hasLineOfSight)
local function mapTileBlocksVision(cx, cy)
    local tile = WorldGen.getTile(cx, cy)
    if tile and CONFIG.lineOfSightBlockers[tile.type] then
        return true
    end
    return false
end

-- Check line of sight between two points (delegates to shared Bresenham)
local function hasLineOfSight(x1, y1, x2, y2)
    return EnemyAI.hasLineOfSight(x1, y1, x2, y2, mapTileBlocksVision)
end

-- Get the ENEMIES table entry by id
local function getEnemyTypeById(id)
    if getEnemiesTableFn then
        local ENEMIES = getEnemiesTableFn()
        if ENEMIES then
            for _, e in ipairs(ENEMIES) do
                if e.id == id then
                    return e
                end
            end
        end
    end
    return nil
end

-- ============================================================================
--                          ENEMY SPAWNING
-- ============================================================================

-- Generate a random patrol route near a position (delegates to shared module)
local function generatePatrolRoute(x, y, length)
    return EnemyAI.generatePatrolRoute(x, y, isTilePassableForEnemy, length)
end

-- Determine enemy level based on distance from start and player level
local function getEnemyLevel(x, y, mapEnemyType)
    local startX, startY = getStartPosition()
    local dist = euclideanDist(x, y, startX, startY)
    local playerLevel = (state.player and state.player.level) or 1

    -- Base level from distance (farther = higher)
    local baseLevelFromDist = math.max(1, math.floor(dist / 5))

    -- Scale within a range around player level
    local minLevel = math.max(1, playerLevel - 2)
    local maxLevel = playerLevel + 2 + math.floor(dist / 10)

    local level = math.max(minLevel, math.min(maxLevel, baseLevelFromDist))

    -- Adjust by CR
    if mapEnemyType.minCR >= 4 then
        level = level + math.random(1, 3)
    elseif mapEnemyType.minCR >= 2 then
        level = level + math.random(0, 2)
    end

    return math.max(1, level)
end

-- Pick a suitable enemy type for a given position
local function pickEnemyTypeForPosition(x, y)
    local tile = WorldGen.getTile(x, y)
    if not tile then return nil end

    local candidates = {}
    local startX, startY = getStartPosition()
    local dist = euclideanDist(x, y, startX, startY)

    for typeId, etype in pairs(MAP_ENEMY_TYPES) do
        -- Check biome
        local biomeMatch = false
        for _, biome in ipairs(etype.biomes) do
            if tile.type == biome then
                biomeMatch = true
                break
            end
        end

        -- Check distance requirements
        if biomeMatch and dist >= etype.minDistFromStart and dist <= etype.maxDistFromStart then
            table.insert(candidates, typeId)
        end
    end

    if #candidates == 0 then return nil end
    return candidates[math.random(#candidates)]
end

-- Spawn a single map enemy at a position
local function spawnEnemy(x, y, typeId)
    local etype = MAP_ENEMY_TYPES[typeId]
    if not etype then return nil end

    local level = getEnemyLevel(x, y, etype)
    local patrolRoute = generatePatrolRoute(x, y)

    local enemy = {
        x = x,
        y = y,
        type = typeId,
        typeDef = etype,
        level = level,
        detectionRadius = etype.detectionRadius,
        patrolRoute = patrolRoute,
        patrolIndex = 1,
        patrolForward = true,          -- Direction along patrol route
        state = "patrol",              -- "patrol", "chase", "idle", "combat"
        moveCooldown = math.random() * 2, -- Stagger initial movement
        idleTimer = 0,
        icon = etype.icon,
        color = etype.color,
        alertTimer = 0,                -- Time since player was detected
        lastKnownPlayerX = nil,
        lastKnownPlayerY = nil,
        spawnTime = love.timer.getTime(),
        id = tostring(love.timer.getTime()) .. "_" .. math.random(10000, 99999),
    }

    return enemy
end

-- Attempt to spawn enemies around the player's visible area
function MapEnemies.spawnAroundPlayer()
    if not state or not state.world or not state.player then return end

    local enemies = state.world.mapEnemies
    if not enemies then
        state.world.mapEnemies = {}
        enemies = state.world.mapEnemies
    end

    -- Don't exceed cap
    if #enemies >= CONFIG.maxTotalEnemies then return end

    local px, py = state.world.playerX, state.world.playerY

    -- Try to spawn a few enemies in the visible area
    local attempts = 0
    local maxAttempts = 20
    local spawned = 0
    local maxSpawnPerCall = 3

    while attempts < maxAttempts and spawned < maxSpawnPerCall and #enemies < CONFIG.maxTotalEnemies do
        attempts = attempts + 1

        -- Pick a random position within spawn radius but not too close
        local angle = math.random() * 2 * math.pi
        local dist = CONFIG.minSpawnDistFromPlayer + math.random() * (CONFIG.spawnRadius - CONFIG.minSpawnDistFromPlayer)
        local tx = px + math.floor(math.cos(angle) * dist + 0.5)
        local ty = py + math.floor(math.sin(angle) * dist + 0.5)

        -- Check if there's already an enemy nearby
        local tooClose = false
        for _, e in ipairs(enemies) do
            if manhattanDist(tx, ty, e.x, e.y) < 3 then
                tooClose = true
                break
            end
        end

        if not tooClose then
            local typeId = pickEnemyTypeForPosition(tx, ty)
            if typeId then
                local etype = MAP_ENEMY_TYPES[typeId]
                if isTileSuitableForSpawn(tx, ty, etype) then
                    local enemy = spawnEnemy(tx, ty, typeId)
                    if enemy then
                        table.insert(enemies, enemy)
                        spawned = spawned + 1
                    end
                end
            end
        end
    end
end

-- ============================================================================
--                          ENEMY AI / MOVEMENT
-- ============================================================================

-- Patrol AI: follow patrol route (delegates to shared module)
local function updatePatrol(enemy, dt)
    EnemyAI.updateRoutePatrol(enemy, isTilePassableForEnemy)
end

-- Chase AI is now turn-based: see MapEnemies.onPlayerMoved() below.
-- Enemies in chase state advance one step per player move instead of in
-- real-time, so the player can see them approaching and evade.

-- Detection: check if player is within enemy's detection radius and LOS.
-- When the player has stealthMode enabled, detection is NOT automatic --
-- instead it uses the StealthSystem (if available) or falls back to the
-- shared EnemyAI.rollStealthDetection() probability roll, matching the
-- dungeon enemy approach.  The roll happens on a cooldown so it is not
-- checked every frame.
local function canDetectPlayer(enemy, dt)
    if not state or not state.world or not state.player then return false end

    local px, py = state.world.playerX, state.world.playerY
    local dist = euclideanDist(enemy.x, enemy.y, px, py)

    -- Base detection radius
    local effectiveRadius = enemy.detectionRadius or 3

    -- Quick range cull (non-stealth and stealth both need to be within range)
    if dist > effectiveRadius then return false end

    -- Line of sight check (shared Bresenham via EnemyAI)
    if not hasLineOfSight(enemy.x, enemy.y, px, py) then return false end

    -- If player is NOT in stealth mode: always detected when in range + LOS
    if not state.player.stealthMode then
        return true
    end

    -- Player IS stealthed: roll for detection on a cooldown
    enemy.stealthDetectCooldown = (enemy.stealthDetectCooldown or 0) - (dt or 0)
    if enemy.stealthDetectCooldown > 0 then
        return false  -- Not time for a new roll yet
    end
    enemy.stealthDetectCooldown = 1.0  -- 1 second between stealth detection rolls

    -- Stealth mode: use StealthSystem (richer overworld context) if available
    if StealthSystem and StealthSystem.calculateDetection then
        local enemyPerception = enemy.perception or 10
        local playerStealth = state.player.stealth or 10
        local equipMod = state.player.equipmentStealthMod or 0
        local classMod = state.player.classStealthBonus or 0
        local skillMod = state.player.skillStealthMod or 0

        local params = {
            distance = dist,
            maxDetectionRange = enemy.detectionRadius,
            enemyPerception = enemyPerception,
            playerStealth = playerStealth,
            equipmentMod = equipMod,
            classBonus = classMod,
            skillMod = skillMod,
            timeOfDay = StealthSystem.getTimePeriod and
                (StealthSystem.getTimePeriod(math.floor(state.timeOfDay or 12))) or "day",
            terrain = state.world.terrain or "grass",
            weather = state.weather or "clear",
            stealthMode = true,
        }
        local detectionChance = StealthSystem.calculateDetection(params) or 0.5
        local detected = math.random() < detectionChance
        if detected then
            log("An enemy spots you!", {0.9, 0.4, 0.3})
        end
        return detected
    end

    -- Fallback: use shared EnemyAI.rollStealthDetection() (same as dungeon enemies)
    local playerStealth = (state.player.stealth or 0)
        + (state.player.equipmentStealthMod or 0) * 100
        + (state.player.classStealthBonus or 0) * 100
        + (state.player.skillStealthMod or 0) * 100

    -- Consider the player "moving" if they moved recently
    local isMoving = (enemy.lastKnownPlayerX ~= px or enemy.lastKnownPlayerY ~= py)
        or (enemy.lastKnownPlayerX == nil)

    -- Searching/chasing enemies are more perceptive
    local effectiveStealth = playerStealth
    if enemy.state == "search" or enemy.state == "chase" then
        effectiveStealth = effectiveStealth * 0.6  -- 40% reduction in stealth effectiveness
    end

    local detected = EnemyAI.rollStealthDetection(
        effectiveRadius, dist, effectiveStealth, isMoving)

    if detected then
        log("An enemy spots you!", {0.9, 0.4, 0.3})
    end

    return detected
end

-- Main update for a single enemy (real-time, runs every frame)
-- NOTE: Chase movement is NOT done here. Chasing enemies move one step per
-- player move via MapEnemies.onPlayerMoved() so the player can see them
-- approaching and has a fair chance to evade.
local function updateSingleEnemy(enemy, dt)
    -- Decrement cooldown (still used for patrol/idle movement)
    enemy.moveCooldown = enemy.moveCooldown - dt

    -- Tick down flee cooldown (enemy cannot detect player during this period)
    if enemy.fleeCooldown and enemy.fleeCooldown > 0 then
        enemy.fleeCooldown = enemy.fleeCooldown - dt
        if enemy.fleeCooldown <= 0 then
            enemy.fleeCooldown = nil
            -- Cooldown expired: resume patrol behavior (can now search for player again)
            enemy.state = "patrol"
            enemy.alertTimer = 0
        end
        return  -- Skip all AI logic while on flee cooldown
    end

    -- State transitions based on detection (delegates to shared module)
    if enemy.state ~= "combat" then
        local prevState = enemy.state
        local detected = canDetectPlayer(enemy, dt)
        EnemyAI.updateDetectionState(enemy, detected, dt, 5)

        -- Log when an enemy first spots the player and starts pursuing
        if enemy.state == "chase" and prevState ~= "chase" then
            local etype = enemy.typeDef or MAP_ENEMY_TYPES[enemy.type]
            if etype then
                log(etype.name .. " spotted you and is approaching!", {0.9, 0.6, 0.3})
            end
        end
    end

    -- Movement based on state (patrol and idle only -- chase is turn-based)
    if enemy.moveCooldown <= 0 then
        local etype = enemy.typeDef or MAP_ENEMY_TYPES[enemy.type]
        if not etype then return end

        if enemy.state == "patrol" then
            enemy.moveCooldown = etype.patrolMoveInterval or CONFIG.patrolMoveInterval
            updatePatrol(enemy, dt)
        elseif enemy.state == "chase" then
            -- Chase movement is handled by onPlayerMoved(), not here.
            -- Just reset cooldown so we don't spin.
            enemy.moveCooldown = etype.chaseMoveInterval or CONFIG.chaseMoveInterval
        elseif enemy.state == "idle" then
            enemy.idleTimer = enemy.idleTimer + (etype.patrolMoveInterval or CONFIG.patrolMoveInterval)
            enemy.moveCooldown = etype.patrolMoveInterval or CONFIG.patrolMoveInterval
            if enemy.idleTimer > CONFIG.idleDuration then
                enemy.state = "patrol"
                enemy.idleTimer = 0
            end
        end
    end
end

-- Advance all chasing enemies by one step toward the player.
-- Called once per player move so enemies approach at the same pace as the
-- player, giving them time to be seen and evaded.
function MapEnemies.onPlayerMoved()
    if not state or not state.world or not state.world.mapEnemies then return end
    if not state.player then return end

    local px, py = state.world.playerX, state.world.playerY
    local enemies = state.world.mapEnemies

    for _, enemy in ipairs(enemies) do
        if enemy.state == "chase" then
            -- Calculate give-up distance: 2x the enemy's detection radius
            local giveUpDist = (enemy.detectionRadius or 3) * 2
            local dist = manhattanDist(enemy.x, enemy.y, px, py)

            if dist > giveUpDist then
                -- Player escaped: enemy gives up and returns to patrol
                enemy.state = "patrol"
                enemy.alertTimer = 0
                enemy.lastKnownPlayerX = nil
                enemy.lastKnownPlayerY = nil
                local etype = enemy.typeDef or MAP_ENEMY_TYPES[enemy.type]
                if etype then
                    log("The " .. etype.name .. " lost interest and turned back.", {0.6, 0.7, 0.6})
                end
            else
                -- Move one step toward the player
                EnemyAI.moveToward(enemy, px, py, isTilePassableForEnemy)
                enemy.lastKnownPlayerX = px
                enemy.lastKnownPlayerY = py
            end
        end
    end
end

-- ============================================================================
--                          COLLISION DETECTION
-- ============================================================================

-- Check if any enemy is on the same tile as the player
-- Returns the enemy if collision found, nil otherwise
function MapEnemies.checkPlayerCollision()
    if not state or not state.world or not state.world.mapEnemies then return nil end

    local px, py = state.world.playerX, state.world.playerY

    for i, enemy in ipairs(state.world.mapEnemies) do
        if enemy.x == px and enemy.y == py and enemy.state ~= "combat" then
            -- Skip enemies on flee cooldown (cannot re-engage until cooldown expires)
            if not enemy.fleeCooldown or enemy.fleeCooldown <= 0 then
                return enemy, i
            end
        end
    end

    return nil
end

-- Trigger combat with a map enemy
function MapEnemies.triggerCombat(enemy, enemyIndex)
    if not state or not state.player then return false end
    if not startCombatFn then return false end

    local etype = enemy.typeDef or MAP_ENEMY_TYPES[enemy.type]
    if not etype then return false end

    -- Stealth system: intercept with stealth approach menu if player is in stealth mode
    if StealthSystem and state.player.stealthMode then
        local playerData = {
            stealth = state.player.stealth or 10,
            stealthMode = true,
            equipmentStealthMod = state.player.equipmentStealthMod or 0,
            classStealthBonus = state.player.classStealthBonus or 0,
            skillStealthMod = state.player.skillStealthMod or 0,
            hasAssassinate = state.player.stealthPerks and state.player.stealthPerks.assassinate,
        }
        local enemyData = {
            perception = etype.perception or 10,
            detectionRadius = etype.detectionRadius or 6,
            hpPercent = 1.0,  -- Map enemies are at full HP
            name = etype.name,
            level = enemy.level or (state.player.level or 1),
        }
        local gameState = {
            timeOfDay = state.timeOfDay or 12,
            weather = (state.world and state.world.weather) or "sunny",
            currentBiome = (state.world and state.world.currentBiome) or "grass",
            gameDay = state.daysPassed or 0,
        }

        local approachResult = StealthSystem.hookPreCombat(playerData, enemyData, enemy, gameState)
        if approachResult then
            -- Store data for the stealth approach menu phase
            state.stealthApproach = {
                result = approachResult,
                enemy = enemy,
                enemyIndex = enemyIndex,
                etype = etype,
                enemyData = enemyData,
                playerData = playerData,
            }
            state.phase = "stealth_approach"
            return true
        end
    end

    -- Normal combat path (no stealth or stealth not applicable)
    return MapEnemies._startCombatWithEnemy(enemy, enemyIndex, etype)
end

-- Internal: actually start combat after stealth approach decision
function MapEnemies._startCombatWithEnemy(enemy, enemyIndex, etype)
    if not etype then
        etype = enemy.typeDef or MAP_ENEMY_TYPES[enemy.type]
    end
    if not etype then return false end

    -- Build combat encounter based on enemy type
    local combatEnemies = {}
    local groupMin = etype.groupSize and etype.groupSize[1] or 1
    local groupMax = etype.groupSize and etype.groupSize[2] or 1
    local count = math.random(groupMin, groupMax)
    local playerLevel = state.player.level or 1

    -- Pick from the enemy type's enemy IDs
    local validEnemyIds = etype.enemyIds
    if not validEnemyIds or #validEnemyIds == 0 then
        return false
    end

    for i = 1, count do
        local enemyId = validEnemyIds[math.random(#validEnemyIds)]
        local enemyTypeDef = getEnemyTypeById(enemyId)

        if enemyTypeDef and createEnemyInstanceFn then
            local instance = createEnemyInstanceFn(enemyTypeDef, enemy.level or playerLevel)
            if instance then
                table.insert(combatEnemies, instance)
            end
        end
    end

    if #combatEnemies == 0 then
        -- Fallback: use generateEncounter if we couldn't build specific enemies
        if generateEncounterFn then
            combatEnemies = generateEncounterFn(playerLevel)
        end
    end

    if #combatEnemies == 0 then return false end

    -- Mark enemy as in combat
    enemy.state = "combat"

    -- Store reference so we can remove it after combat
    state.world.currentMapEnemy = {
        enemy = enemy,
        index = enemyIndex,
    }

    -- Log encounter message based on enemy state
    if enemy.alertTimer and enemy.alertTimer > 0 then
        log("The " .. etype.name .. " caught up to you!", {0.9, 0.4, 0.3})
    else
        log("You stumbled into " .. etype.name .. "!", {0.9, 0.5, 0.3})
    end

    -- Start combat
    startCombatFn(combatEnemies)
    return true
end

-- Handle combat result (call after combat ends)
function MapEnemies.onCombatEnd(victory)
    if not state or not state.world then return end

    local mapEnemyRef = state.world.currentMapEnemy
    if not mapEnemyRef then return end

    if victory then
        -- Remove enemy from map
        local enemies = state.world.mapEnemies
        if enemies then
            for i = #enemies, 1, -1 do
                if enemies[i].id == mapEnemyRef.enemy.id then
                    table.remove(enemies, i)
                    break
                end
            end
        end

        -- Track stat
        state.world.mapEnemiesDefeated = (state.world.mapEnemiesDefeated or 0) + 1
    else
        -- Player died or fled - respawn enemy nearby
        local enemy = mapEnemyRef.enemy
        if enemy then
            enemy.state = "patrol"
            enemy.alertTimer = 0
            -- Move enemy 2 tiles away from player to avoid instant re-collision
            local px, py = state.world.playerX, state.world.playerY
            EnemyAI.pushAwayFrom(enemy, px, py, isTilePassableForEnemy)
        end
    end

    state.world.currentMapEnemy = nil
end

-- Called when player flees combat (special case of onCombatEnd)
-- Keeps enemy on the map and adds a 3-second cooldown before it can re-engage
function MapEnemies.onPlayerFlee()
    if not state or not state.world then return end

    local mapEnemyRef = state.world.currentMapEnemy
    if not mapEnemyRef then
        -- Fallback: still clear the reference
        state.world.currentMapEnemy = nil
        return
    end

    local enemy = mapEnemyRef.enemy
    if enemy then
        -- Keep enemy on map but set idle state with a cooldown
        enemy.state = "idle"
        enemy.alertTimer = 0
        enemy.idleTimer = 0
        -- 3-second cooldown: enemy cannot detect or chase the player during this period
        enemy.fleeCooldown = 3.0

        -- Move enemy 2 tiles away from player to avoid instant re-collision
        local px, py = state.world.playerX, state.world.playerY
        EnemyAI.pushAwayFrom(enemy, px, py, isTilePassableForEnemy)
    end

    state.world.currentMapEnemy = nil
end

-- ============================================================================
--                   STEALTH APPROACH EXECUTION
-- ============================================================================

-- Execute a stealth approach action chosen from the menu.
-- Called from textrpg.lua when player selects an option in stealth_approach phase.
function MapEnemies.executeStealthAction(actionId)
    if not state or not state.stealthApproach then return nil end
    if not StealthSystem then return nil end

    local approach = state.stealthApproach
    local result = StealthSystem.executeStealthAction(
        actionId,
        approach.playerData,
        approach.enemyData,
        approach.result
    )

    if not result then return nil end

    if result.enemyDefeated then
        -- Enemy was killed/knocked out without combat
        local enemy = approach.enemy
        local etype = approach.etype

        -- Remove enemy from map
        if state.world and state.world.mapEnemies then
            for i = #state.world.mapEnemies, 1, -1 do
                if state.world.mapEnemies[i] == enemy then
                    table.remove(state.world.mapEnemies, i)
                    break
                end
            end
        end
        state.world.mapEnemiesDefeated = (state.world.mapEnemiesDefeated or 0) + 1

        -- Apply karma change
        if result.karmaChange and result.karmaChange ~= 0 then
            state.player.karma = (state.player.karma or 0) + result.karmaChange
        end

        -- Apply XP bonus
        if result.xpBonus and result.xpBonus > 0 then
            local baseXP = (approach.enemyData.level or 1) * 15
            local bonusXP = math.floor(baseXP * result.xpBonus)
            state.player.xp = (state.player.xp or 0) + baseXP + bonusXP
        end

        -- Prisoner handling for knockout
        if result.createsPrisoner then
            if not state.player.prisoners then state.player.prisoners = {} end
            table.insert(state.player.prisoners, {
                name = approach.enemyData.name or "Prisoner",
                level = approach.enemyData.level or 1,
                capturedDay = state.daysPassed or 0,
            })
        end

    elseif result.combatStarts then
        -- Start actual combat (with possible ambush bonus)
        if result.ambushActive then
            -- Store ambush data so startCombat can use it
            state.player._ambushBonus = {
                playerGoesFirst = result.playerGoesFirst,
                firstHitDamageBonus = result.firstHitDamageBonus,
            }
        end
        if result.enemyAlerted then
            -- Enemy was alerted, no stealth bonuses
            state.player.stealthMode = false
        end
        MapEnemies._startCombatWithEnemy(approach.enemy, approach.enemyIndex, approach.etype)
    end

    -- Clear stealth approach state
    state.stealthApproach = nil

    return result
end

-- ============================================================================
--                           MAIN UPDATE
-- ============================================================================

-- Spawn timer tracking
local spawnTimer = 0
local SPAWN_INTERVAL = 5  -- Check for spawns every 5 seconds

function MapEnemies.update(dt)
    if not state or not state.world or not state.player then return end
    if state.phase ~= "map" then return end  -- Only update when on world map

    local enemies = state.world.mapEnemies
    if not enemies then
        state.world.mapEnemies = {}
        enemies = state.world.mapEnemies
    end

    local px, py = state.world.playerX, state.world.playerY

    -- Update each enemy
    for i = #enemies, 1, -1 do
        local enemy = enemies[i]
        if enemy and enemy.state ~= "combat" then
            -- Despawn enemies that are too far from player
            local dist = manhattanDist(enemy.x, enemy.y, px, py)
            if dist > CONFIG.despawnRadius then
                table.remove(enemies, i)
            else
                updateSingleEnemy(enemy, dt)
            end
        end
    end

    -- Periodically spawn new enemies
    spawnTimer = spawnTimer + dt
    if spawnTimer >= SPAWN_INTERVAL then
        spawnTimer = 0
        MapEnemies.spawnAroundPlayer()
    end
end

-- ============================================================================
--                              DRAWING
-- ============================================================================

-- Draw all visible enemies on the map
-- Parameters match the drawMap coordinate system:
--   mapStartX/Y: pixel position of the top-left visible tile
--   cellSize: pixel size of each tile cell
--   minViewX/Y: world tile coordinates of the top-left visible tile
--   maxViewX/Y: world tile coordinates of the bottom-right visible tile
function MapEnemies.draw(mapStartX, mapStartY, cellSize, minViewX, minViewY, maxViewX, maxViewY)
    if not state or not state.world or not state.world.mapEnemies then return end

    local enemies = state.world.mapEnemies
    local time = love.timer.getTime()
    -- getFont is accessible as a global via textrpg.lua's _G metatable
    local getFont = _G.getFont

    for _, enemy in ipairs(enemies) do
        if enemy.state ~= "combat" then
            -- Check if enemy is within the visible viewport
            if enemy.x >= minViewX and enemy.x <= maxViewX and
               enemy.y >= minViewY and enemy.y <= maxViewY then

                local screenCol = enemy.x - minViewX
                local screenRow = enemy.y - minViewY
                local cellX = mapStartX + screenCol * cellSize
                local cellY = mapStartY + screenRow * cellSize

                local etype = enemy.typeDef or MAP_ENEMY_TYPES[enemy.type]
                if etype then
                    -- Draw vision cone / detection radius
                    MapEnemies.drawVisionCone(enemy, etype, mapStartX, mapStartY, cellSize, minViewX, minViewY, maxViewX, maxViewY, time)

                    -- Pulse animation for visibility
                    local pulse = 0.85 + 0.15 * math.sin(time * CONFIG.pulseSpeed + enemy.x * 0.7 + enemy.y * 1.3)

                    -- Enemy background circle
                    local bgR, bgG, bgB = etype.color[1], etype.color[2], etype.color[3]
                    if enemy.state == "chase" then
                        -- Red pulsing background when chasing
                        local chasePulse = 0.7 + 0.3 * math.sin(time * 6)
                        bgR = 0.9 * chasePulse
                        bgG = 0.2
                        bgB = 0.2
                    end

                    -- Draw enemy background
                    love.graphics.setColor(bgR * 0.6, bgG * 0.6, bgB * 0.6, 0.9 * pulse)
                    love.graphics.rectangle("fill", cellX + 2, cellY + 2, cellSize - 5, cellSize - 5, 4, 4)

                    -- Draw enemy border (color based on state)
                    if enemy.state == "chase" then
                        love.graphics.setColor(0.9, 0.2, 0.2, 0.9)
                    elseif enemy.state == "idle" then
                        love.graphics.setColor(0.7, 0.7, 0.3, 0.7)
                    else
                        love.graphics.setColor(bgR, bgG, bgB, 0.7)
                    end
                    love.graphics.setLineWidth(2)
                    love.graphics.rectangle("line", cellX + 2, cellY + 2, cellSize - 5, cellSize - 5, 4, 4)
                    love.graphics.setLineWidth(1)

                    -- Draw enemy icon
                    love.graphics.setColor(1, 1, 1, 0.95 * pulse)
                    if getFont then
                        love.graphics.setFont(getFont(math.floor(cellSize * 0.55)))
                    end
                    love.graphics.printf(etype.icon, cellX, cellY + cellSize * 0.15, cellSize, "center")

                    -- Draw level indicator (small text in corner)
                    love.graphics.setColor(1, 1, 1, 0.8)
                    if getFont then
                        love.graphics.setFont(getFont(math.max(7, math.floor(cellSize * 0.22))))
                    end
                    love.graphics.print(tostring(enemy.level), cellX + 3, cellY + 2)

                    -- Draw danger indicator when chasing
                    if enemy.state == "chase" then
                        local alertFlash = math.sin(time * 8) > 0
                        if alertFlash then
                            love.graphics.setColor(1, 0.3, 0.3, 0.9)
                            if getFont then
                                love.graphics.setFont(getFont(math.max(8, math.floor(cellSize * 0.3))))
                            end
                            love.graphics.printf("!", cellX + cellSize - 12, cellY + 1, 10, "center")
                        end
                    end
                end
            end
        end
    end
end

-- Draw vision cone for an enemy (delegates to shared module)
function MapEnemies.drawVisionCone(enemy, etype, mapStartX, mapStartY, cellSize, minViewX, minViewY, maxViewX, maxViewY, time)
    local radius = enemy.detectionRadius or 3
    EnemyAI.drawVisionCone(enemy, radius, enemy.state, mapStartX, mapStartY, cellSize, minViewX, minViewY, maxViewX, maxViewY, time, {visionConeAlpha = CONFIG.visionConeAlpha})
end

-- ============================================================================
--                          SAVE / LOAD
-- ============================================================================

-- Get save-safe data (strip typeDef references which contain functions)
function MapEnemies.getSaveData()
    if not state or not state.world or not state.world.mapEnemies then
        return {}
    end

    local saveData = {
        enemies = {},
        defeatedCount = state.world.mapEnemiesDefeated or 0,
    }

    for _, enemy in ipairs(state.world.mapEnemies) do
        if enemy.state ~= "combat" then
            table.insert(saveData.enemies, {
                x = enemy.x,
                y = enemy.y,
                type = enemy.type,
                level = enemy.level,
                detectionRadius = enemy.detectionRadius,
                patrolRoute = enemy.patrolRoute,
                patrolIndex = enemy.patrolIndex,
                patrolForward = enemy.patrolForward,
                state = enemy.state,
                icon = enemy.icon,
                color = enemy.color,
                id = enemy.id,
            })
        end
    end

    return saveData
end

-- Load enemies from save data
function MapEnemies.loadSaveData(saveData)
    if not state or not state.world then return end

    state.world.mapEnemies = {}
    state.world.mapEnemiesDefeated = 0

    if not saveData then return end

    state.world.mapEnemiesDefeated = saveData.defeatedCount or 0

    if saveData.enemies then
        for _, saved in ipairs(saveData.enemies) do
            local etype = MAP_ENEMY_TYPES[saved.type]
            if etype then
                local enemy = {
                    x = saved.x,
                    y = saved.y,
                    type = saved.type,
                    typeDef = etype,
                    level = saved.level or 1,
                    detectionRadius = saved.detectionRadius or etype.detectionRadius,
                    patrolRoute = saved.patrolRoute,
                    patrolIndex = saved.patrolIndex or 1,
                    patrolForward = saved.patrolForward ~= false,
                    state = saved.state or "patrol",
                    moveCooldown = math.random() * 2,
                    idleTimer = 0,
                    icon = saved.icon or etype.icon,
                    color = saved.color or etype.color,
                    alertTimer = 0,
                    lastKnownPlayerX = nil,
                    lastKnownPlayerY = nil,
                    spawnTime = love.timer.getTime(),
                    id = saved.id or (tostring(love.timer.getTime()) .. "_" .. math.random(10000, 99999)),
                }
                -- Reset chase state on load (always resume patrol)
                if enemy.state == "chase" then
                    enemy.state = "patrol"
                end
                table.insert(state.world.mapEnemies, enemy)
            end
        end
    end
end

-- ============================================================================
--                          PUBLIC QUERY FUNCTIONS
-- ============================================================================

-- Get count of active map enemies
function MapEnemies.getCount()
    if not state or not state.world or not state.world.mapEnemies then return 0 end
    return #state.world.mapEnemies
end

-- Get count of defeated map enemies
function MapEnemies.getDefeatedCount()
    if not state or not state.world then return 0 end
    return state.world.mapEnemiesDefeated or 0
end

-- Get enemies near a position (for minimap or other purposes)
function MapEnemies.getEnemiesNear(x, y, radius)
    if not state or not state.world or not state.world.mapEnemies then return {} end

    local result = {}
    for _, enemy in ipairs(state.world.mapEnemies) do
        if manhattanDist(enemy.x, enemy.y, x, y) <= radius then
            table.insert(result, enemy)
        end
    end
    return result
end

-- Check if an enemy is currently chasing the player
function MapEnemies.isPlayerBeingChased()
    if not state or not state.world or not state.world.mapEnemies then return false end

    for _, enemy in ipairs(state.world.mapEnemies) do
        if enemy.state == "chase" then
            return true
        end
    end
    return false
end

-- Get the MAP_ENEMY_TYPES table for external reference
function MapEnemies.getEnemyTypes()
    return MAP_ENEMY_TYPES
end

return MapEnemies
