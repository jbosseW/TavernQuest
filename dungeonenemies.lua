-- Dungeon Enemies System
-- Visible enemies on dungeon floors with patrol/chase AI, vision cones,
-- and collision-triggered combat. Extends the MapEnemies pattern for dungeons.

local DungeonEnemies = {}
local EnemyAI = require("enemyai")

-- Reference to game state (set via init)
local state = nil
local log = function(text, color)
    if _G.log then _G.log(text, color) end
end

-- External callbacks (set via init)
local startCombatFn = nil
local createEnemyInstanceFn = nil
local getEnemiesTableFn = nil

-- ============================================================================
--                              CONFIGURATION
-- ============================================================================

local CONFIG = {
    -- Movement
    patrolMoveInterval = 1.4,        -- Seconds between patrol moves
    chaseMoveInterval = 0.7,         -- Seconds between chase moves
    searchMoveInterval = 1.0,        -- Seconds between search moves
    idleDuration = 2.5,              -- Seconds idle before resuming patrol
    returnToPatrolDist = 10,         -- Give up chase beyond this distance

    -- Detection
    baseDetectionRadius = 3,         -- Default detection radius
    bossDetectionRadius = 5,         -- Boss detection radius

    -- Stealth detection (checked each move tick when player has stealthMode on)
    stealthDetectionInterval = 1.0,  -- Seconds between stealth detection rolls

    -- Animation
    pulseSpeed = 3.0,                -- Enemy icon pulse speed
    visionConeAlpha = 0.06,          -- Base alpha for vision cone
    visionConeAlphaStealth = 0.10,   -- Higher alpha when player is stealthed (so they see danger)
}

-- ============================================================================
--                     DUNGEON ENEMY TYPE DEFINITIONS
-- ============================================================================

-- Mapping dungeon types to visual enemy representations on the grid.
-- These define how enemies look and behave on the dungeon map; actual combat
-- stats come from the floor.enemies table generated during floor creation.
local DUNGEON_ENEMY_VISUALS = {
    -- Default enemy icons by enemy id prefix
    rat = {icon = "r", color = {0.5, 0.4, 0.3}, detectionRadius = 2},
    bat = {icon = "b", color = {0.4, 0.3, 0.4}, detectionRadius = 2},
    cave_spider = {icon = "x", color = {0.4, 0.2, 0.4}, detectionRadius = 3},
    spider = {icon = "x", color = {0.4, 0.2, 0.4}, detectionRadius = 3},
    goblin = {icon = "g", color = {0.3, 0.7, 0.3}, detectionRadius = 3},
    goblin_warrior = {icon = "G", color = {0.3, 0.6, 0.3}, detectionRadius = 3},
    skeleton = {icon = "k", color = {0.7, 0.7, 0.8}, detectionRadius = 3},
    skeleton_knight = {icon = "K", color = {0.8, 0.8, 0.9}, detectionRadius = 4},
    zombie = {icon = "z", color = {0.4, 0.5, 0.3}, detectionRadius = 2},
    orc = {icon = "o", color = {0.6, 0.4, 0.2}, detectionRadius = 3},
    orc_warrior = {icon = "O", color = {0.6, 0.4, 0.2}, detectionRadius = 3},
    orc_warlord = {icon = "O", color = {0.7, 0.5, 0.2}, detectionRadius = 4},
    troll = {icon = "T", color = {0.3, 0.5, 0.3}, detectionRadius = 3},
    ogre = {icon = "T", color = {0.4, 0.5, 0.3}, detectionRadius = 3},
    wraith = {icon = "W", color = {0.5, 0.5, 0.8}, detectionRadius = 4},
    scorpion = {icon = "s", color = {0.6, 0.5, 0.2}, detectionRadius = 3},
    slime = {icon = "~", color = {0.3, 0.6, 0.3}, detectionRadius = 2},
    vampire = {icon = "V", color = {0.5, 0.1, 0.2}, detectionRadius = 5},
    vampire_lord = {icon = "V", color = {0.6, 0.1, 0.2}, detectionRadius = 5},
    lich = {icon = "L", color = {0.4, 0.1, 0.5}, detectionRadius = 5},
    demon = {icon = "D", color = {0.8, 0.2, 0.2}, detectionRadius = 4},
    imp = {icon = "i", color = {0.7, 0.3, 0.2}, detectionRadius = 3},
    ghost = {icon = "G", color = {0.6, 0.7, 0.9}, detectionRadius = 4},
    wolf = {icon = "w", color = {0.5, 0.5, 0.6}, detectionRadius = 4},
    bear = {icon = "B", color = {0.5, 0.4, 0.3}, detectionRadius = 3},
    bandit = {icon = "b", color = {0.8, 0.3, 0.3}, detectionRadius = 4},
}

-- Fallback visual for enemies without a specific definition
local DEFAULT_VISUAL = {icon = "E", color = {0.8, 0.3, 0.3}, detectionRadius = 3}

-- ============================================================================
--                              INITIALIZATION
-- ============================================================================

function DungeonEnemies.init(gameState, callbacks)
    state = gameState
    if callbacks then
        startCombatFn = callbacks.startCombat
        createEnemyInstanceFn = callbacks.createEnemyInstance
        getEnemiesTableFn = callbacks.getEnemiesTable
    end
end

function DungeonEnemies.setLogFunction(logFunc)
    log = logFunc
end

-- ============================================================================
--                          HELPER FUNCTIONS
-- ============================================================================

-- Distance functions (delegated to shared EnemyAI module)
local manhattanDist = EnemyAI.manhattanDist
local euclideanDist = EnemyAI.euclideanDist

-- Get visual info for an enemy based on its id
local function getEnemyVisual(enemyId)
    if not enemyId then return DEFAULT_VISUAL end
    -- Try exact match first
    if DUNGEON_ENEMY_VISUALS[enemyId] then
        return DUNGEON_ENEMY_VISUALS[enemyId]
    end
    -- Try prefix match (e.g. "goblin_warrior" matches "goblin")
    for key, visual in pairs(DUNGEON_ENEMY_VISUALS) do
        if enemyId:find(key) then
            return visual
        end
    end
    return DEFAULT_VISUAL
end

-- Check if a dungeon tile is passable for enemy movement
local function isDungeonTilePassable(floor, x, y)
    if not floor or not floor.grid then return false end
    if y < 1 or y > floor.height or x < 1 or x > floor.width then return false end
    local row = floor.grid[y]
    if not row then return false end
    local tile = row[x]
    if not tile then return false end
    local tileType = tile.type
    -- Passable tile types in dungeons
    return tileType == "floor" or tileType == "corridor" or tileType == "door"
        or tileType == "entrance" or tileType == "stairs_up" or tileType == "stairs_down"
        or tileType == "exit" or tileType == "hollow_portal" or tileType == "chest"
end

-- ============================================================================
--                     FLOOR ENEMY INITIALIZATION
-- ============================================================================

-- Convert static floor enemies into active visible entities with AI.
-- Called once when a floor is first visited or when entering a new floor.
-- Clears the grid content markers for enemies since they are now tracked
-- as visible entities that move independently of the grid.
function DungeonEnemies.initFloorEnemies(floor)
    if not floor then return end
    if floor.visibleEnemies then return end -- Already initialized

    floor.visibleEnemies = {}

    for _, enemy in ipairs(floor.enemies or {}) do
        if enemy.alive then
            local visual = getEnemyVisual(enemy.id)
            local visEnemy = {
                -- Link to original enemy data (for combat stats)
                enemyData = enemy,
                -- Position
                x = enemy.x,
                y = enemy.y,
                -- Visual
                icon = visual.icon,
                color = visual.color,
                -- AI state
                state = "patrol",      -- "patrol", "chase", "search", "idle"
                detectionRadius = visual.detectionRadius or CONFIG.baseDetectionRadius,
                moveCooldown = math.random() * 2, -- Stagger initial movement
                idleTimer = 0,
                alertTimer = 0,
                searchTimer = 0,
                searchTurns = 0,
                stealthDetectCooldown = 0,
                lastKnownPlayerX = nil,
                lastKnownPlayerY = nil,
                -- Patrol
                patrolOriginX = enemy.x,
                patrolOriginY = enemy.y,
                patrolRadius = 3,
                patrolTargetX = enemy.x,
                patrolTargetY = enemy.y,
                -- Boss flag
                isBoss = enemy.isBoss or false,
            }

            -- Clear the static grid content marker since this enemy is now a
            -- visible entity tracked by the DungeonEnemies system
            if floor.grid and floor.grid[enemy.y] and floor.grid[enemy.y][enemy.x] then
                local tile = floor.grid[enemy.y][enemy.x]
                if tile.content and tile.content.type == "enemy" then
                    tile.content = nil
                end
            end

            -- Bosses have larger detection radius
            if enemy.isBoss then
                visEnemy.detectionRadius = CONFIG.bossDetectionRadius
                visEnemy.icon = "B"
            end

            table.insert(floor.visibleEnemies, visEnemy)
        end
    end
end

-- ============================================================================
--                          ENEMY AI / MOVEMENT
-- ============================================================================

-- Patrol: wander near spawn point (delegates to shared module)
local function updatePatrol(floor, enemy, dt)
    local function isPassable(x, y)
        return isDungeonTilePassable(floor, x, y)
    end
    local function isOccupied(x, y, self)
        for _, other in ipairs(floor.visibleEnemies or {}) do
            if other ~= self and other.x == x and other.y == y and other.enemyData.alive then
                return true
            end
        end
        return false
    end
    EnemyAI.updateRadiusPatrol(enemy, isPassable, isOccupied)
end

-- Chase: pursue the player (delegates to shared module)
local function updateChase(floor, enemy, dt)
    if not state or not state.dungeon then return end
    local px, py = state.dungeon.playerX, state.dungeon.playerY
    local function isPassable(x, y)
        return isDungeonTilePassable(floor, x, y)
    end
    local function isOccupied(x, y, self)
        for _, other in ipairs(floor.visibleEnemies or {}) do
            if other ~= self and other.x == x and other.y == y and other.enemyData.alive then
                return true
            end
        end
        return false
    end
    EnemyAI.updateChase(enemy, px, py, CONFIG.returnToPatrolDist, isPassable, isOccupied)
end

-- Helper: Check if the player currently has stealth mode enabled
local function isPlayerStealthed()
    return state and state.player and state.player.stealthMode
end

-- Helper: Get the player's stealth stat (0-100)
local function getPlayerStealthStat()
    if not state or not state.player then return 0 end
    return (state.player.stealth or 0)
        + (state.player.equipmentStealthMod or 0) * 100
        + (state.player.classStealthBonus or 0) * 100
        + (state.player.skillStealthMod or 0) * 100
end

-- Detection: check if player is within enemy's detection radius and LOS.
-- When the player has stealthMode enabled, detection is NOT automatic --
-- instead it is a probability roll based on distance and stealth stats.
-- The roll happens on a cooldown so it is not checked every frame.
-- Returns: true (detected), false (not detected), or nil (no check performed
--          this frame due to stealth cooldown -- caller should preserve current
--          detection state rather than treating it as "not detected").
local function canDetectPlayer(floor, enemy, dt)
    if not state or not state.dungeon then return false end
    local px, py = state.dungeon.playerX, state.dungeon.playerY

    local blocksVision = function(cx, cy)
        return not isDungeonTilePassable(floor, cx, cy)
    end

    -- First: basic range + LOS check (same for stealth and non-stealth)
    local inRange = EnemyAI.canDetect(enemy, px, py, enemy.detectionRadius, blocksVision)

    if not inRange then
        return false
    end

    -- If player is NOT in stealth mode: always detected when in range + LOS
    if not isPlayerStealthed() then
        return true
    end

    -- Player IS stealthed: roll for detection on a cooldown
    enemy.stealthDetectCooldown = (enemy.stealthDetectCooldown or 0) - (dt or 0)
    if enemy.stealthDetectCooldown > 0 then
        -- No roll performed this frame; return nil so the caller knows to
        -- preserve the enemy's current AI state rather than interpreting this
        -- as "player not detected" (which would break chase/search behavior)
        return nil
    end
    enemy.stealthDetectCooldown = CONFIG.stealthDetectionInterval

    local dist = EnemyAI.euclideanDist(enemy.x, enemy.y, px, py)
    local playerStealth = getPlayerStealthStat()
    -- Consider the player "moving" if they moved recently (approximated by
    -- checking if last known position differs from current position)
    local isMoving = (enemy.lastKnownPlayerX ~= px or enemy.lastKnownPlayerY ~= py)
        or (enemy.lastKnownPlayerX == nil)

    -- Searching enemies are more perceptive (bonus to detection)
    local effectiveStealth = playerStealth
    if enemy.state == "search" or enemy.state == "chase" then
        effectiveStealth = effectiveStealth * 0.6  -- 40% reduction in stealth effectiveness
    end

    local detected = EnemyAI.rollStealthDetection(
        enemy.detectionRadius, dist, effectiveStealth, isMoving)

    if detected then
        log("An enemy spots you!", {0.9, 0.4, 0.3})
    end

    return detected
end

-- Search: move toward last known position, then wander nearby looking for player
local function updateSearch(floor, enemy, dt)
    local function isPassable(x, y)
        return isDungeonTilePassable(floor, x, y)
    end
    local function isOccupied(x, y, self)
        for _, other in ipairs(floor.visibleEnemies or {}) do
            if other ~= self and other.x == x and other.y == y and other.enemyData.alive then
                return true
            end
        end
        return false
    end
    EnemyAI.updateSearch(enemy, isPassable, isOccupied)
end

-- Update a single dungeon enemy
local function updateSingleEnemy(floor, enemy, dt)
    if not enemy.enemyData.alive then return end

    enemy.moveCooldown = enemy.moveCooldown - dt

    -- Detection state transitions (delegates to shared module)
    -- Pass useSearchState=true so enemies go chase -> search -> patrol
    -- canDetectPlayer returns nil when a stealth roll cooldown is active
    -- (no check was performed); in that case we skip the state transition
    -- so the enemy continues its current behavior (patrol, chase, search)
    -- instead of incorrectly being treated as "player not detected".
    local detected = canDetectPlayer(floor, enemy, dt)
    if detected ~= nil then
        EnemyAI.updateDetectionState(enemy, detected, dt, 4, true)
    end

    -- Movement (patrol, search, idle are real-time; chase is turn-based)
    -- Chase movement is handled by DungeonEnemies.onPlayerMoved() so enemies
    -- advance one step per player step, giving the player a fair chance to flee.
    if enemy.moveCooldown <= 0 then
        if enemy.state == "patrol" then
            enemy.moveCooldown = CONFIG.patrolMoveInterval
            updatePatrol(floor, enemy, dt)
        elseif enemy.state == "chase" then
            -- Chase movement is turn-based via onPlayerMoved(), not real-time.
            -- Just reset cooldown so detection keeps running.
            enemy.moveCooldown = CONFIG.chaseMoveInterval
        elseif enemy.state == "search" then
            enemy.moveCooldown = CONFIG.searchMoveInterval
            updateSearch(floor, enemy, dt)
        elseif enemy.state == "idle" then
            enemy.idleTimer = enemy.idleTimer + CONFIG.patrolMoveInterval
            enemy.moveCooldown = CONFIG.patrolMoveInterval
            if enemy.idleTimer > CONFIG.idleDuration then
                enemy.state = "patrol"
                enemy.idleTimer = 0
            end
        end
    end
end

-- ============================================================================
--                          COLLISION DETECTION
-- ============================================================================

-- Check if any visible enemy is on the player tile.
-- Returns the visible enemy and its original enemy data, or nil.
function DungeonEnemies.checkPlayerCollision()
    if not state or not state.dungeon then return nil end

    local dungeon = state.dungeon
    local floor = dungeon.floors and dungeon.floors[dungeon.currentFloor]
    if not floor or not floor.visibleEnemies then return nil end

    local px, py = dungeon.playerX, dungeon.playerY

    for i, visEnemy in ipairs(floor.visibleEnemies) do
        if visEnemy.x == px and visEnemy.y == py and visEnemy.enemyData.alive then
            return visEnemy, i
        end
    end

    return nil
end

-- Trigger combat with a visible dungeon enemy
function DungeonEnemies.triggerCombat(visEnemy, visIndex)
    if not state or not state.player then return false end
    if not startCombatFn then return false end

    local enemyData = visEnemy.enemyData
    if not enemyData or not enemyData.alive then return false end

    -- Build combat encounter (use maxHP uppercase to match combat UI convention)
    local combatEnemies = {{
        id = enemyData.id,
        name = enemyData.name,
        hp = enemyData.hp,
        maxHP = enemyData.maxHp or enemyData.maxHP or enemyData.hp,
        maxHp = enemyData.maxHp or enemyData.maxHP or enemyData.hp,
        atk = enemyData.atk,
        def = enemyData.def,
        xp = enemyData.xp,
        gold = enemyData.gold,
        isBoss = enemyData.isBoss,
    }}

    -- Store reference for post-combat cleanup, including the player's
    -- current position so we can restore it correctly if the player flees
    state.dungeon.currentVisibleEnemy = {
        visEnemy = visEnemy,
        visIndex = visIndex,
        preCombatPlayerX = state.dungeon.playerX,
        preCombatPlayerY = state.dungeon.playerY,
    }

    -- Log encounter
    if visEnemy.state == "chase" and visEnemy.alertTimer > 0 then
        log("The " .. enemyData.name .. " catches you!", {0.9, 0.4, 0.3})
    else
        log("You encounter " .. enemyData.name .. "!", {0.9, 0.5, 0.3})
    end

    -- Start combat
    startCombatFn(combatEnemies)

    return true
end

-- Handle combat result for dungeon enemies
function DungeonEnemies.onCombatEnd(victory)
    if not state or not state.dungeon then return end

    local ref = state.dungeon.currentVisibleEnemy
    if not ref then return end

    local visEnemy = ref.visEnemy
    local floor = state.dungeon.floors and state.dungeon.floors[state.dungeon.currentFloor]

    if victory then
        -- Mark enemy as dead
        visEnemy.enemyData.alive = false

        -- Remove from visible enemies list
        if floor and floor.visibleEnemies then
            for i = #floor.visibleEnemies, 1, -1 do
                if floor.visibleEnemies[i] == visEnemy then
                    table.remove(floor.visibleEnemies, i)
                    break
                end
            end
        end

        -- Clear the grid content marker too
        if floor and floor.grid then
            local row = floor.grid[visEnemy.y]
            if row then
                local tile = row[visEnemy.x]
                if tile and tile.content and tile.content.type == "enemy" then
                    tile.content = nil
                end
            end
        end

        -- Also clear at original spawn position in case enemy moved
        local origX = visEnemy.patrolOriginX
        local origY = visEnemy.patrolOriginY
        if floor and floor.grid and origX and origY then
            local origRow = floor.grid[origY]
            if origRow then
                local origTile = origRow[origX]
                if origTile and origTile.content and origTile.content.type == "enemy" then
                    if origTile.content.data and not origTile.content.data.alive then
                        origTile.content = nil
                    end
                end
            end
        end
    else
        -- Player fled or died - restore player to pre-combat position and
        -- push enemy away so they don't immediately re-collide.
        -- Restore position first (guards against anything that may have
        -- modified the dungeon position during the combat phase).
        local savedX = ref.preCombatPlayerX
        local savedY = ref.preCombatPlayerY
        if savedX and savedY then
            state.dungeon.playerX = savedX
            state.dungeon.playerY = savedY
        end

        local px, py = state.dungeon.playerX, state.dungeon.playerY

        if visEnemy and visEnemy.enemyData.alive then
            visEnemy.lastKnownPlayerX = px
            visEnemy.lastKnownPlayerY = py
            visEnemy.state = "search"
            visEnemy.searchTimer = 0
            visEnemy.searchTurns = 0
            visEnemy.alertTimer = 0
            -- Push enemy back slightly so player can flee
            local function isPassable(x, y)
                return floor and isDungeonTilePassable(floor, x, y)
            end
            EnemyAI.pushAwayFrom(visEnemy, px, py, isPassable)
        end
    end

    state.dungeon.currentVisibleEnemy = nil
end

-- ============================================================================
--                    TURN-BASED CHASE (on player move)
-- ============================================================================

-- Advance all chasing dungeon enemies by one step toward the player.
-- Called once per player move so enemies approach at the same pace as the
-- player, giving them time to be seen and evaded (mirrors MapEnemies pattern).
function DungeonEnemies.onPlayerMoved()
    if not state or not state.dungeon then return end

    local dungeon = state.dungeon
    local floor = dungeon.floors and dungeon.floors[dungeon.currentFloor]
    if not floor or not floor.visibleEnemies then return end

    local px, py = dungeon.playerX, dungeon.playerY

    local function isPassable(x, y)
        return isDungeonTilePassable(floor, x, y)
    end
    local function isOccupied(x, y, self)
        for _, other in ipairs(floor.visibleEnemies) do
            if other ~= self and other.x == x and other.y == y and other.enemyData.alive then
                return true
            end
        end
        return false
    end

    for _, visEnemy in ipairs(floor.visibleEnemies) do
        if visEnemy.state == "chase" and visEnemy.enemyData.alive then
            -- Give up chase if player is too far away
            local dist = EnemyAI.manhattanDist(visEnemy.x, visEnemy.y, px, py)
            if dist > CONFIG.returnToPatrolDist then
                visEnemy.state = "patrol"
                visEnemy.alertTimer = 0
                visEnemy.lastKnownPlayerX = nil
                visEnemy.lastKnownPlayerY = nil
            else
                -- Move one step toward the player
                EnemyAI.moveToward(visEnemy, px, py, isPassable, isOccupied)
                visEnemy.lastKnownPlayerX = px
                visEnemy.lastKnownPlayerY = py
            end
        end
    end
end

-- ============================================================================
--                           MAIN UPDATE
-- ============================================================================

function DungeonEnemies.update(dt)
    if not state or not state.dungeon then return end
    if state.phase ~= "dungeon" then return end

    local dungeon = state.dungeon
    local floor = dungeon.floors and dungeon.floors[dungeon.currentFloor]
    if not floor then return end

    -- Initialize visible enemies for this floor if needed
    DungeonEnemies.initFloorEnemies(floor)

    if not floor.visibleEnemies then return end

    -- Update each enemy
    for i = #floor.visibleEnemies, 1, -1 do
        local visEnemy = floor.visibleEnemies[i]
        if visEnemy.enemyData.alive then
            updateSingleEnemy(floor, visEnemy, dt)
        else
            table.remove(floor.visibleEnemies, i)
        end
    end
end

-- ============================================================================
--                              DRAWING
-- ============================================================================

-- Draw all visible enemies on the dungeon map.
-- Parameters match drawDungeon's coordinate system:
--   mapStartX/Y: pixel position of top-left visible tile
--   cellSize: pixel size of each cell
--   minViewX/Y, maxViewX/Y: world tile range visible on screen
function DungeonEnemies.draw(mapStartX, mapStartY, cellSize, minViewX, minViewY, maxViewX, maxViewY)
    if not state or not state.dungeon then return end

    local dungeon = state.dungeon
    local floor = dungeon.floors and dungeon.floors[dungeon.currentFloor]
    if not floor or not floor.visibleEnemies then return end

    local time = love.timer.getTime()
    local getFont = _G.getFont
    local px, py = dungeon.playerX, dungeon.playerY

    for _, visEnemy in ipairs(floor.visibleEnemies) do
        if visEnemy.enemyData.alive then
            -- Only draw if within visible viewport AND on explored tile
            if visEnemy.x >= minViewX and visEnemy.x <= maxViewX and
               visEnemy.y >= minViewY and visEnemy.y <= maxViewY then

                -- Only show if tile is explored (player has seen this area)
                local tile = floor.grid[visEnemy.y] and floor.grid[visEnemy.y][visEnemy.x]
                if tile and tile.explored then
                    local screenCol = visEnemy.x - minViewX
                    local screenRow = visEnemy.y - minViewY
                    local cellX = mapStartX + screenCol * cellSize
                    local cellY = mapStartY + screenRow * cellSize

                    -- Draw vision cone (detection area)
                    DungeonEnemies.drawVisionCone(floor, visEnemy, mapStartX, mapStartY, cellSize, minViewX, minViewY, maxViewX, maxViewY, time)

                    -- Pulse animation
                    local pulse = 0.85 + 0.15 * math.sin(time * CONFIG.pulseSpeed + visEnemy.x * 0.7 + visEnemy.y * 1.3)

                    -- Enemy background color
                    local bgR, bgG, bgB = visEnemy.color[1], visEnemy.color[2], visEnemy.color[3]
                    if visEnemy.state == "chase" then
                        local chasePulse = 0.7 + 0.3 * math.sin(time * 6)
                        bgR = 0.9 * chasePulse
                        bgG = 0.2
                        bgB = 0.2
                    elseif visEnemy.state == "search" then
                        local searchPulse = 0.7 + 0.3 * math.sin(time * 3)
                        bgR = 0.9 * searchPulse
                        bgG = 0.6 * searchPulse
                        bgB = 0.1
                    end

                    -- Background rect
                    love.graphics.setColor(bgR * 0.6, bgG * 0.6, bgB * 0.6, 0.9 * pulse)
                    love.graphics.rectangle("fill", cellX + 1, cellY + 1, cellSize - 3, cellSize - 3, 3, 3)

                    -- Border
                    if visEnemy.state == "chase" then
                        love.graphics.setColor(0.9, 0.2, 0.2, 0.9)
                    elseif visEnemy.state == "search" then
                        love.graphics.setColor(0.9, 0.6, 0.15, 0.9)
                    elseif visEnemy.state == "idle" then
                        love.graphics.setColor(0.7, 0.7, 0.3, 0.7)
                    else
                        love.graphics.setColor(bgR, bgG, bgB, 0.7)
                    end
                    love.graphics.setLineWidth(1)
                    love.graphics.rectangle("line", cellX + 1, cellY + 1, cellSize - 3, cellSize - 3, 3, 3)

                    -- Icon
                    love.graphics.setColor(1, 1, 1, 0.95 * pulse)
                    if getFont then
                        love.graphics.setFont(getFont(math.floor(cellSize * 0.55)))
                    end
                    love.graphics.printf(visEnemy.icon, cellX, cellY + cellSize * 0.15, cellSize, "center")

                    -- Boss indicator
                    if visEnemy.isBoss then
                        love.graphics.setColor(0.9, 0.8, 0.2, 0.9)
                        if getFont then
                            love.graphics.setFont(getFont(math.max(6, math.floor(cellSize * 0.2))))
                        end
                        love.graphics.print("BOSS", cellX + 1, cellY + 1)
                    end

                    -- Alert indicator when chasing
                    if visEnemy.state == "chase" then
                        local alertFlash = math.sin(time * 8) > 0
                        if alertFlash then
                            love.graphics.setColor(1, 0.3, 0.3, 0.9)
                            if getFont then
                                love.graphics.setFont(getFont(math.max(7, math.floor(cellSize * 0.3))))
                            end
                            love.graphics.printf("!", cellX + cellSize - 10, cellY + 1, 8, "center")
                        end
                    end

                    -- Search indicator (? symbol, orange)
                    if visEnemy.state == "search" then
                        local searchFlash = math.sin(time * 4) > -0.3
                        if searchFlash then
                            love.graphics.setColor(0.9, 0.6, 0.15, 0.9)
                            if getFont then
                                love.graphics.setFont(getFont(math.max(7, math.floor(cellSize * 0.3))))
                            end
                            love.graphics.printf("?", cellX + cellSize - 10, cellY + 1, 8, "center")
                        end
                    end
                end
            end
        end
    end
end

-- Draw vision cone for a dungeon enemy (delegates to shared module)
function DungeonEnemies.drawVisionCone(floor, visEnemy, mapStartX, mapStartY, cellSize, minViewX, minViewY, maxViewX, maxViewY, time)
    local radius = visEnemy.detectionRadius or 3
    -- When player is stealthed, show vision cones more prominently so the
    -- player can plan their movement and avoid detection zones
    local playerStealthed = state and state.player and state.player.stealthMode
    local alpha = playerStealthed and CONFIG.visionConeAlphaStealth or CONFIG.visionConeAlpha
    -- Only show vision on explored, passable dungeon tiles
    local function isTileVisible(tileX, tileY)
        local tile = floor.grid[tileY] and floor.grid[tileY][tileX]
        return tile and tile.explored and isDungeonTilePassable(floor, tileX, tileY)
    end
    EnemyAI.drawVisionCone(visEnemy, radius, visEnemy.state, mapStartX, mapStartY, cellSize, minViewX, minViewY, maxViewX, maxViewY, time, {visionConeAlpha = alpha}, isTileVisible)
end

-- ============================================================================
--                          PUBLIC QUERIES
-- ============================================================================

-- Get count of alive visible enemies on current floor
function DungeonEnemies.getAliveCount()
    if not state or not state.dungeon then return 0 end
    local floor = state.dungeon.floors and state.dungeon.floors[state.dungeon.currentFloor]
    if not floor or not floor.visibleEnemies then return 0 end

    local count = 0
    for _, ve in ipairs(floor.visibleEnemies) do
        if ve.enemyData.alive then
            count = count + 1
        end
    end
    return count
end

-- Check if player is being chased by any dungeon enemy
function DungeonEnemies.isPlayerBeingChased()
    if not state or not state.dungeon then return false end
    local floor = state.dungeon.floors and state.dungeon.floors[state.dungeon.currentFloor]
    if not floor or not floor.visibleEnemies then return false end

    for _, ve in ipairs(floor.visibleEnemies) do
        if ve.state == "chase" and ve.enemyData.alive then
            return true
        end
    end
    return false
end

-- Get nearby enemies for UI warnings
function DungeonEnemies.getNearbyEnemies(radius)
    if not state or not state.dungeon then return {} end
    local floor = state.dungeon.floors and state.dungeon.floors[state.dungeon.currentFloor]
    if not floor or not floor.visibleEnemies then return {} end

    local px, py = state.dungeon.playerX, state.dungeon.playerY
    local result = {}
    for _, ve in ipairs(floor.visibleEnemies) do
        if ve.enemyData.alive and manhattanDist(ve.x, ve.y, px, py) <= radius then
            table.insert(result, ve)
        end
    end
    return result
end

return DungeonEnemies
