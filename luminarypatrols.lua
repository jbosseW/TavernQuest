-- Luminary Inquest Roving Patrols System
-- Large groups of Luminary Inquest enforcers that rove around the map,
-- hunting vampires, werewolves, liches, and criminals.

local LuminaryPatrols = {}

-- Reference to log function (set from textrpg.lua)
local log = function(text, color)
    -- Fallback if not initialized - try global log
    if _G.log then
        _G.log(text, color)
    end
end

-- Reference to startCombat function (set from textrpg.lua)
local startCombatFn = nil

-- Function to set the log reference
function LuminaryPatrols.setLogFunction(logFunc)
    log = logFunc
end

-- Function to set the startCombat callback
function LuminaryPatrols.setStartCombatFunction(combatFunc)
    startCombatFn = combatFunc
end

-- ============================================================================
--                              CONFIGURATION
-- ============================================================================

local CONFIG = {
    maxPatrols = 5,                    -- Max simultaneous patrols
    spawnChancePerDay = 0.3,           -- 30% base per game day
    preferredSpawnDistance = 10,       -- Spawn ~10 tiles from player
    minDistanceBetweenPatrols = 15,    -- Avoid clustering

    baseSize = 8,                      -- Enforcers per patrol
    baseStrength = 50,
    baseMorale = 100,
    baseRadius = 2,                    -- 5x5 tile area (center ± 2)
    detectionRadius = 4,               -- Detection range

    minDaysActive = 3,
    maxDaysActive = 10,                -- Despawn after 10 days
    moveInterval = 120,                -- Seconds between moves (2 minutes)

    -- Detection base chance
    vampireDetectionChance = 0.7,      -- 70% base chance to detect vampires

    -- Threat priorities (higher = more urgent)
    threatPriority = {
        player_vampire = 10,
        lich_lair = 8,
        npc_vampire = 5,
        criminal = 3,
    },
}

-- ============================================================================
--                              STATE MANAGEMENT
-- ============================================================================

local patrolState = {
    activePatrols = {},        -- {patrolId: patrol}
    patrolHistory = {},        -- Movement history
    lastSpawnCheck = 0,        -- Spawn timer
    totalPatrols = 0,          -- ID counter
}

local state = nil  -- Will be set via init()

-- Initialize the patrol system
function LuminaryPatrols.init(gameState)
    state = gameState
end

-- ============================================================================
--                              HELPER FUNCTIONS
-- ============================================================================

local TileUtils = require("tileutils")
local MathUtil = require("mathutil")

-- Check if tile is passable (not water) using shared TileUtils
local function isTilePassable(x, y)
    if not state or not state.world then return false end
    return TileUtils.isWorldTilePassable(x, y)
end

-- Calculate distance between two points (Manhattan distance)
-- Wraps MathUtil.getDistance with nil-safety for patrol coordinate lookups
local function getDistance(x1, y1, x2, y2)
    if not x1 or not y1 or not x2 or not y2 then
        return math.huge  -- Return huge distance so nil-coordinate entries are safely ignored
    end
    return MathUtil.getDistance(x1, y1, x2, y2)
end

-- Find nearest town to coordinates
local function getNearestTown(x, y)
    if not state or not state.world then return nil end
    if not x or not y then return nil end

    local WorldGen = require("worldgen")
    local anchorTowns = WorldGen.getAnchorTowns()

    if not anchorTowns then return nil end

    local nearestTown = nil
    local minDist = math.huge

    for _, town in ipairs(anchorTowns) do
        -- Anchor towns store coordinates in town.position.x / town.position.y
        local townX = town.position and town.position.x or town.x
        local townY = town.position and town.position.y or town.y
        local dist = getDistance(x, y, townX, townY)
        if dist < minDist then
            minDist = dist
            nearestTown = town
        end
    end

    return nearestTown, minDist
end

-- Find valid spawn location near a point
local function findSpawnLocation(nearX, nearY)
    -- Try positions in expanding radius
    for radius = CONFIG.preferredSpawnDistance - 2, CONFIG.preferredSpawnDistance + 5 do
        local attempts = {}

        -- Generate candidate positions around the circle
        for angle = 0, 360, 45 do
            local rad = math.rad(angle)
            local x = nearX + math.floor(math.cos(rad) * radius)
            local y = nearY + math.floor(math.sin(rad) * radius)
            table.insert(attempts, {x = x, y = y})
        end

        -- Shuffle attempts
        for i = #attempts, 2, -1 do
            local j = math.random(i)
            attempts[i], attempts[j] = attempts[j], attempts[i]
        end

        -- Try each position
        for _, pos in ipairs(attempts) do
            -- Check if passable
            if isTilePassable(pos.x, pos.y) then
                -- Check distance from other patrols
                local tooClose = false
                for _, patrol in pairs(patrolState.activePatrols) do
                    local dist = getDistance(pos.x, pos.y, patrol.centerX, patrol.centerY)
                    if dist < CONFIG.minDistanceBetweenPatrols then
                        tooClose = true
                        break
                    end
                end

                if not tooClose then
                    return pos.x, pos.y
                end
            end
        end
    end

    return nil, nil
end

-- ============================================================================
--                              SPAWNING SYSTEM
-- ============================================================================

-- Calculate spawn chance based on world state
local function calculateSpawnChance()
    local baseChance = CONFIG.spawnChancePerDay

    -- Increase by vampire count
    local vampireCount = 0
    for _, npc in ipairs(state.npcs or {}) do
        if npc.isVampire and not npc.isDead then
            vampireCount = vampireCount + 1
        end
    end
    baseChance = baseChance + (vampireCount * 0.05)

    -- Increase by player bounty
    if state.player and state.player.bounty and state.player.bounty >= 1000 then
        baseChance = baseChance + 0.20
    end

    -- Increase by lich lairs
    local WorldGen = require("worldgen")
    local lichLairs = WorldGen.getActiveLichLairs and WorldGen.getActiveLichLairs() or {}
    baseChance = baseChance + (#lichLairs * 0.15)

    -- Decrease by existing patrols
    local patrolCount = 0
    for _ in pairs(patrolState.activePatrols) do
        patrolCount = patrolCount + 1
    end
    baseChance = baseChance - (patrolCount * 0.10)

    return math.max(0, math.min(1, baseChance))
end

-- Spawn a new patrol
function LuminaryPatrols.spawnPatrol(nearX, nearY, reason)
    -- Check max patrols limit
    local activeCount = 0
    for _ in pairs(patrolState.activePatrols) do
        activeCount = activeCount + 1
    end

    if activeCount >= CONFIG.maxPatrols then
        return false
    end

    -- Find valid spawn location
    local spawnX, spawnY = findSpawnLocation(nearX, nearY)
    if not spawnX then
        return false
    end

    -- Create patrol
    patrolState.totalPatrols = patrolState.totalPatrols + 1
    local patrolId = "patrol_" .. patrolState.totalPatrols

    local nearestTown, townDist = getNearestTown(spawnX, spawnY)

    local patrol = {
        id = patrolId,
        centerX = spawnX,
        centerY = spawnY,
        radius = CONFIG.baseRadius,
        size = CONFIG.baseSize,
        strength = CONFIG.baseStrength,

        -- Movement
        moveTimer = 0,
        moveInterval = CONFIG.moveInterval,
        targetX = nil,
        targetY = nil,
        movementType = "random_patrol",

        -- Detection
        detectionRadius = CONFIG.detectionRadius,
        currentTarget = nil,

        -- State
        morale = CONFIG.baseMorale,
        daysActive = 0,
        lastCombat = nil,
        spawnedNearTown = nearestTown and nearestTown.name or "wilderness",
        spawnReason = reason or "routine_patrol",
        spawnDate = state.totalDaysElapsed or 0,
    }

    patrolState.activePatrols[patrolId] = patrol

    -- Generate rumor
    local RumorSystem = require("rumorsystem")
    RumorSystem.init(state)
    RumorSystem.onLuminaryPatrol(spawnX, spawnY, patrol.spawnedNearTown)

    -- Log message
    log("⚔️ Luminary Inquest enforcers have been spotted near " .. patrol.spawnedNearTown .. "!", {0.9, 0.85, 0.3})

    return true
end

-- ============================================================================
--                              MOVEMENT SYSTEM
-- ============================================================================

-- Move patrol to new location
local function movePatrol(patrol)
    local newX, newY

    if patrol.movementType == "hunting" and patrol.targetX and patrol.targetY then
        -- Move toward target
        local dx = patrol.targetX - patrol.centerX
        local dy = patrol.targetY - patrol.centerY

        -- Move 1-2 tiles toward target
        if math.abs(dx) > math.abs(dy) then
            newX = patrol.centerX + (dx > 0 and 1 or -1)
            newY = patrol.centerY
        else
            newX = patrol.centerX
            newY = patrol.centerY + (dy > 0 and 1 or -1)
        end
    else
        -- Random patrol movement
        local directions = {
            {dx = 0, dy = -1},  -- North
            {dx = 1, dy = 0},   -- East
            {dx = 0, dy = 1},   -- South
            {dx = -1, dy = 0},  -- West
        }

        -- Try random directions
        for i = #directions, 2, -1 do
            local j = math.random(i)
            directions[i], directions[j] = directions[j], directions[i]
        end

        for _, dir in ipairs(directions) do
            local moveDistance = math.random(1, 3)
            local testX = patrol.centerX + (dir.dx * moveDistance)
            local testY = patrol.centerY + (dir.dy * moveDistance)

            if isTilePassable(testX, testY) then
                newX = testX
                newY = testY
                break
            end
        end
    end

    -- Apply movement if valid
    if newX and newY and isTilePassable(newX, newY) then
        -- Record position in history
        table.insert(patrolState.patrolHistory, {
            patrolId = patrol.id,
            x = patrol.centerX,
            y = patrol.centerY,
            timestamp = state.totalDaysElapsed or 0,
        })

        -- Keep history limited
        if #patrolState.patrolHistory > 100 then
            table.remove(patrolState.patrolHistory, 1)
        end

        patrol.centerX = newX
        patrol.centerY = newY
        patrol.moveTimer = 0
    end
end

-- ============================================================================
--                              DETECTION SYSTEM
-- ============================================================================

-- Check for threats near patrol
local function checkPatrolDetection(patrol)
    local threats = {}
    if not state.player or not state.world then return threats end

    -- Check player vampire status
    if state.player.isVampire then
        local dist = getDistance(patrol.centerX, patrol.centerY,
                                state.world.playerX, state.world.playerY)
        if dist <= patrol.detectionRadius then
            table.insert(threats, {
                type = "player_vampire",
                priority = CONFIG.threatPriority.player_vampire,
                x = state.world.playerX,
                y = state.world.playerY,
                distance = dist,
            })
        end
    end

    -- Check player bounty
    if state.player.bounty and state.player.bounty >= 100 then
        local dist = getDistance(patrol.centerX, patrol.centerY,
                                state.world.playerX, state.world.playerY)
        if dist <= patrol.detectionRadius then
            table.insert(threats, {
                type = "criminal",
                priority = CONFIG.threatPriority.criminal,
                x = state.world.playerX,
                y = state.world.playerY,
                distance = dist,
            })
        end
    end

    -- Check for lich lairs
    local WorldGen = require("worldgen")
    local lichLairs = WorldGen.getActiveLichLairs and WorldGen.getActiveLichLairs() or {}
    for _, lair in ipairs(lichLairs) do
        if not lair.cleared then
            local dist = getDistance(patrol.centerX, patrol.centerY, lair.x, lair.y)
            if dist <= patrol.detectionRadius * 2 then  -- Lich lairs detected from farther
                table.insert(threats, {
                    type = "lich_lair",
                    priority = CONFIG.threatPriority.lich_lair,
                    x = lair.x,
                    y = lair.y,
                    distance = dist,
                })
            end
        end
    end

    -- Check for vampire NPCs
    -- OPTIMIZATION: Use vampire NPC cache instead of iterating all NPCs
    -- Cache is maintained by vampire spread system (updated every 30s)
    if state.vampireNPCCache and state.vampireNPCCache.vampires then
        -- Use cached vampire list (already filtered by distance in vampire spread)
        for _, vampData in ipairs(state.vampireNPCCache.vampires) do
            local dist = getDistance(patrol.centerX, patrol.centerY, vampData.x, vampData.y)

            if dist <= patrol.detectionRadius then
                table.insert(threats, {
                    type = "npc_vampire",
                    priority = CONFIG.threatPriority.npc_vampire,
                    x = vampData.x,
                    y = vampData.y,
                    distance = dist,
                    npc = vampData.npc,
                })
            end
        end
    else
        -- FALLBACK: If cache not available, iterate NPCs with distance pre-filter
        -- This only runs if vampire spread hasn't run yet (first 30 seconds of game)
        local PREFILTER_RADIUS = patrol.detectionRadius * 3

        for _, npc in ipairs(state.npcs or {}) do
            if npc.tileX and npc.tileY then
                local dist = getDistance(patrol.centerX, patrol.centerY, npc.tileX, npc.tileY)

                -- Skip NPCs that are too far away
                if dist <= PREFILTER_RADIUS and npc.isVampire and not npc.isDead then
                    if dist <= patrol.detectionRadius then
                        table.insert(threats, {
                            type = "npc_vampire",
                            priority = CONFIG.threatPriority.npc_vampire,
                            x = npc.tileX,
                            y = npc.tileY,
                            distance = dist,
                            npc = npc,
                        })
                    end
                end
            end
        end
    end

    -- Sort by priority (highest first)
    table.sort(threats, function(a, b)
        if a.priority == b.priority then
            return a.distance < b.distance
        end
        return a.priority > b.priority
    end)

    return threats
end

-- ============================================================================
--                              ENCOUNTER SYSTEM
-- ============================================================================

-- Handle encounter when player enters patrol area
function LuminaryPatrols.handlePatrolEncounter(patrol)
    if not state.player then return end

    -- Check if player is vampire
    if state.player.isVampire then
        -- Calculate detection chance
        local detectionChance = CONFIG.vampireDetectionChance

        -- Reduce by stealth skills
        if state.player.stealthMode then
            detectionChance = detectionChance * 0.5
        end

        -- Reduce by stealth XP bonus
        if state.player.stealthXPBonus and state.player.stealthXPBonus > 0 then
            local stealthReduction = math.min(0.3, state.player.stealthXPBonus / 1000 * 0.3)
            detectionChance = detectionChance - stealthReduction
        end

        if math.random() < detectionChance then
            -- Detected!
            log("🔥 The Luminary patrol detects your vampiric aura! They attack!", {0.9, 0.2, 0.1})
            LuminaryPatrols.triggerPatrolCombat(patrol, "vampire_detected")
            return
        else
            -- Passed undetected
            log("⚔️ You carefully pass the Luminary patrol without drawing attention...", {0.7, 0.7, 0.3})
        end
    end

    -- Check for bounty
    if state.player.bounty and state.player.bounty >= 100 then
        -- Check for documents
        local hasDocuments = false
        if state.player.inventory then
            for _, item in ipairs(state.player.inventory) do
                if item.id == "travel_papers" or item.id == "royal_writ" then
                    hasDocuments = true
                    break
                end
            end
        end

        if not hasDocuments then
            -- No documents - they arrest/fight you
            log("⚔️ The patrol demands to see your travel documents, but you have none!", {0.9, 0.5, 0.1})
            log("The enforcers move to apprehend you!", {0.9, 0.2, 0.1})
            LuminaryPatrols.triggerPatrolCombat(patrol, "no_documents")
            return
        else
            -- Has documents - just a warning
            log("⚔️ The patrol inspects your documents. They let you pass with a warning.", {0.7, 0.7, 0.3})
        end
    end

    -- Random inspection (10% chance)
    if math.random() < 0.1 then
        log("⚔️ The patrol stops you for a routine inspection.", {0.7, 0.7, 0.3})

        -- Check for travel documents
        local hasDocuments = false
        if state.player.inventory then
            for _, item in ipairs(state.player.inventory) do
                if item.id == "travel_papers" or item.id == "royal_writ" then
                    hasDocuments = true
                    break
                end
            end
        end

        if not hasDocuments then
            log("You lack proper travel documents. The patrol adds 50 gold to your bounty.", {0.9, 0.5, 0.1})
            state.player.bounty = (state.player.bounty or 0) + 50
        else
            log("Your documents are in order. You may proceed.", {0.7, 0.7, 0.3})
        end
    end
end

-- ============================================================================
--                              COMBAT SYSTEM
-- ============================================================================

-- Trigger combat with patrol
function LuminaryPatrols.triggerPatrolCombat(patrol, reason)
    if not state.player then return end

    -- Create enforcer enemies
    local enemies = {}
    for i = 1, patrol.size do
        local level = state.player.level + math.random(0, 2)
        local baseHP = 25 + level * 12
        local baseAtk = 4 + level * 3
        local baseDef = 2 + level * 2
        local enforcer = {
            id = "luminary_enforcer",
            name = "Luminary Enforcer",
            cr = 3,
            level = level,
            hp = math.floor(baseHP * 1.1),
            maxHP = math.floor(baseHP * 1.1),
            attack = math.floor(baseAtk * 1.2),
            defense = math.floor(baseDef * 1.1),
            xpReward = math.floor((15 + level * 8) * 1.5),
            goldReward = math.floor((8 + level * 4) * 1.2),
            attacks = {
                {name = "Holy Smite", damage = {12, 20}, type = "holy"},
                {name = "Purge", damage = {10, 18}, type = "holy"},
            },
            portrait = "Human/Men_Human/Knight_Man",
        }
        table.insert(enemies, enforcer)
    end

    -- Store patrol reference for combat callbacks
    state.currentPatrolCombat = {
        patrolId = patrol.id,
        reason = reason,
    }

    -- Start combat via callback
    if not startCombatFn then return end
    startCombatFn(enemies)
end

-- Handle patrol combat victory
function LuminaryPatrols.onPatrolCombatVictory()
    if not state.currentPatrolCombat then return end

    local patrolId = state.currentPatrolCombat.patrolId
    local patrol = patrolState.activePatrols[patrolId]

    if patrol then
        -- Reduce morale
        patrol.morale = patrol.morale - 30

        -- Despawn if morale too low
        if patrol.morale <= 0 then
            patrolState.activePatrols[patrolId] = nil
            log("⚔️ The Luminary patrol has been defeated and disperses!", {0.3, 0.9, 0.3})
        else
            log("⚔️ The patrol retreats but remains in the area...", {0.9, 0.7, 0.3})
        end
    end

    state.currentPatrolCombat = nil
end

-- Handle patrol combat defeat
function LuminaryPatrols.onPatrolCombatDefeat()
    if not state.currentPatrolCombat then return end

    -- Player captured - massive bounty increase
    state.player.bounty = (state.player.bounty or 0) + 1000

    -- Activate vampire hunters if player is vampire
    if state.player.isVampire then
        state.vampireHuntersActive = true
        log("🔥 The Luminary Inquest sends word across the realm - vampire hunters are mobilized!", {0.9, 0.2, 0.1})
    end

    log("You have been defeated by the Luminary patrol. Your bounty increases significantly.", {0.9, 0.3, 0.1})

    state.currentPatrolCombat = nil
end

-- ============================================================================
--                              UPDATE LOOP
-- ============================================================================

-- Main update function (called from textrpg.lua)
function LuminaryPatrols.update(dt)
    if not state then return end

    -- Spawn check (once per game day)
    local gameHourLength = 30  -- 30 seconds per game hour
    local gameDayLength = gameHourLength * 24  -- 720 seconds per game day

    patrolState.lastSpawnCheck = patrolState.lastSpawnCheck + dt

    if patrolState.lastSpawnCheck >= gameDayLength then
        patrolState.lastSpawnCheck = 0

        -- Calculate spawn chance
        local spawnChance = calculateSpawnChance()

        if math.random() < spawnChance then
            -- Spawn near player
            local playerX = state.world and state.world.playerX or 0
            local playerY = state.world and state.world.playerY or 0
            LuminaryPatrols.spawnPatrol(playerX, playerY, "routine_patrol")
        end
    end

    -- Update each patrol
    for patrolId, patrol in pairs(patrolState.activePatrols) do
        -- Increment days active
        local daysElapsed = state.totalDaysElapsed or 0
        patrol.daysActive = daysElapsed - patrol.spawnDate

        -- Despawn old patrols
        if patrol.daysActive >= CONFIG.maxDaysActive then
            patrolState.activePatrols[patrolId] = nil
            goto continue_patrol
        end

        -- Update move timer
        patrol.moveTimer = patrol.moveTimer + dt

        -- Check for threats
        local threats = checkPatrolDetection(patrol)

        if #threats > 0 then
            local topThreat = threats[1]
            patrol.movementType = "hunting"
            patrol.targetX = topThreat.x
            patrol.targetY = topThreat.y
            patrol.currentTarget = topThreat

            -- Warn player if they're being hunted
            if topThreat.type == "player_vampire" or topThreat.type == "criminal" then
                if topThreat.distance <= 5 and math.random() < 0.1 then
                    log("⚔️ Warning: Luminary patrols are closing in on your position!", {0.9, 0.5, 0.1})
                end
            end
        else
            patrol.movementType = "random_patrol"
            patrol.targetX = nil
            patrol.targetY = nil
            patrol.currentTarget = nil
        end

        -- Move patrol when timer expires
        if patrol.moveTimer >= patrol.moveInterval then
            movePatrol(patrol)
        end

        ::continue_patrol::
    end
end

-- ============================================================================
--                              SAVE/LOAD SYSTEM
-- ============================================================================

-- Get save data
function LuminaryPatrols.getSaveData()
    return {
        activePatrols = patrolState.activePatrols,
        patrolHistory = patrolState.patrolHistory,
        lastSpawnCheck = patrolState.lastSpawnCheck,
        totalPatrols = patrolState.totalPatrols,
    }
end

-- Load save data
function LuminaryPatrols.loadSaveData(saveData)
    if not saveData then return end

    patrolState.activePatrols = saveData.activePatrols or {}
    patrolState.patrolHistory = saveData.patrolHistory or {}
    patrolState.lastSpawnCheck = saveData.lastSpawnCheck or 0
    patrolState.totalPatrols = saveData.totalPatrols or 0
end

-- Get active patrols (for external use)
function LuminaryPatrols.getActivePatrols()
    return patrolState.activePatrols
end

-- Get patrol state (for debugging/testing)
function LuminaryPatrols.getState()
    return patrolState
end

-- Force spawn patrol (for testing)
function LuminaryPatrols.forceSpawn(x, y, reason)
    return LuminaryPatrols.spawnPatrol(x, y, reason or "debug_spawn")
end

return LuminaryPatrols
