-- Auto-Play System for Tavern Quest TextRPG
-- Allows AI to automatically play the game based on player-selected goals
-- Inspired by the card game auto-play system

local AutoPlay = {}

-- Reference to log function (set from textrpg.lua)
local log = function(text, color)
    -- Fallback if not initialized - try global log
    if _G.log then
        _G.log(text, color)
    end
end

-- Function to set the log reference
function AutoPlay.setLogFunction(logFunc)
    log = logFunc
end

-- Minor Issue Fix #30: Cache WorldGen module to avoid repeated requires
local WorldGen = package.loaded["worldgen"]

-- Tactical combat module references (set from textrpg.lua via setTacticalReferences)
local TacticalCombat = nil
local TacticalAI = nil
local tacticalStateRef = nil    -- function that returns current tacticalState
local tacticalStateClear = nil  -- function that sets tacticalState to nil

-- Function to set tactical combat module references (called from textrpg.lua)
-- Must be defined after the local declarations above so it captures them as upvalues
function AutoPlay.setTacticalReferences(tc, ai, stateGetter, stateClearer)
    TacticalCombat = tc
    TacticalAI = ai
    tacticalStateRef = stateGetter    -- function() that returns current tacticalState
    tacticalStateClear = stateClearer  -- function() that sets tacticalState = nil
end

-- Minor Issue Fix #29: Cache fonts to avoid creating new ones every frame
local FontCache = require("fontcache")
local function getFont(size)
    return FontCache.get(size)
end

-- ============================================================================
-- PLAYER POSITION HELPER
-- ============================================================================

-- Get the correct player position based on current phase.
-- During dungeon/prison phases, position is in state.dungeon.playerX/Y.
-- During normal world phases, position is in state.world.playerX/Y.
-- Returns nil, nil if no valid position is available.
local function getPlayerPosition(state)
    if state.inDungeon and state.dungeon then
        return state.dungeon.playerX, state.dungeon.playerY
    elseif state.world then
        return state.world.playerX, state.world.playerY
    end
    return nil, nil
end

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

-- Goal definitions with priorities and descriptions
AutoPlay.GOALS = {
    questing = {
        id = "questing",
        name = "Questing",
        icon = "🗡️",
        description = "Accept and complete quests",
        priority = {"accept_quests", "complete_quests", "travel_to_quest", "combat_for_quest"},
    },
    jobbing = {
        id = "jobbing",
        name = "Job Board",
        icon = "💼",
        description = "Focus on job board for gold",
        priority = {"accept_jobs", "complete_jobs", "travel_to_town"},
    },
    gathering = {
        id = "gathering",
        name = "Gathering",
        icon = "🌲",
        description = "Collect resources",
        priority = {"chop_lumber", "fishing", "mining", "travel_to_resources"},
    },
    fighting = {
        id = "fighting",
        name = "Combat",
        icon = "⚔️",
        description = "Seek out battles",
        priority = {"seek_combat", "enter_dungeons", "hunt_enemies"},
    },
    exploring = {
        id = "exploring",
        name = "Exploring",
        icon = "🗺️",
        description = "Discover new locations",
        priority = {"discover_tiles", "visit_towns", "enter_dungeons", "travel_far"},
    },
    all = {
        id = "all",
        name = "All Activities",
        icon = "⭐",
        description = "Balanced gameplay",
        priority = {"balanced_mix"},
    },
    testing = {
        id = "testing",
        name = "Testing Mode",
        icon = "🧪",
        description = "Run QA checklists",
        priority = {"execute_tests", "log_results", "detect_crashes"},
    },
}

-- Goal order for menu display
AutoPlay.GOAL_ORDER = {"questing", "jobbing", "gathering", "fighting", "exploring", "all", "testing"}

-- Configuration settings
AutoPlay.config = {
    actionDelay = 1.0,            -- Seconds between auto actions
    combatDelay = 0.5,            -- Faster delay for combat actions
    safetyThreshold = 0.3,        -- HP % to pause (30%)
    restThreshold = 0.5,          -- HP % to seek rest (50%)
    useCarriage = true,           -- Auto-use paid travel for long distances?
    autoSell = true,              -- Auto-sell junk items when inventory full?
    pauseOnLevelUp = true,        -- Pause for stat allocation?
    pauseOnQuestComplete = false, -- Pause to show quest rewards? (disabled for continuous play)
    pauseOnInventoryFull = false, -- Pause when inventory is nearly full? (disabled by default)
    stuckDetectionEnabled = true, -- Enable stuck detection with auto-retry?
    stuckTimeoutSeconds = 15,     -- Seconds before auto-retry when stuck (default: 15)
    debugMode = false,            -- Show debug messages?
}

-- ============================================================================
-- STATE MANAGEMENT
-- ============================================================================

-- Create default auto-play state
function AutoPlay.createDefaultState()
    return {
        enabled = false,              -- Auto-play active?
        goal = "all",                 -- Current goal ID
        timer = 0,                    -- Time accumulator for action delay
        actionDelay = AutoPlay.config.actionDelay,  -- Current delay
        currentAction = nil,          -- What AI is currently doing (string)
        targetLocation = nil,         -- {x, y, type} for navigation
        isPaused = false,             -- Temporarily paused?
        pauseReasons = {},            -- Array of pause reason strings
        showMenu = false,             -- Context menu visible?
        menuX = 0,                    -- Menu position
        menuY = 0,

        -- Statistics tracking
        stats = {
            totalTimeEnabled = 0,     -- Total seconds auto-play was active
            questsCompleted = 0,
            combatsWon = 0,
            goldEarned = 0,
            tilesExplored = 0,
            resourcesGathered = 0,
            actionsPerformed = 0,
        },

        -- Testing mode data
        testData = {
            checklist = {},            -- Array of test items to execute
            currentTestIndex = 1,      -- Which test we're on
            results = {},              -- Test results log
            crashesDetected = 0,
        },

        -- HIGH PRIORITY FIX #4: Action log (last 20 actions) - documentation corrected
        actionLog = {},

        -- Stuck detection with timeout-based retry
        lastPosition = nil,
        stuckCounter = 0,
        stuckTimer = 0,              -- Time spent stuck (in seconds)
        maxStuckTime = AutoPlay.config.stuckTimeoutSeconds or 15,  -- Timeout before retry
        retryAttempts = 0,           -- Number of retry attempts
        lastAction = nil,            -- Last action attempted (to avoid repeating)
    }
end

-- ============================================================================
-- MAIN UPDATE FUNCTION
-- ============================================================================

-- Update auto-play system (called every frame)
function AutoPlay.update(dt, state)
    if not state or not state.autoPlay then return end

    local ap = state.autoPlay

    -- Update statistics
    if ap.enabled and not ap.isPaused then
        ap.stats.totalTimeEnabled = ap.stats.totalTimeEnabled + dt
    end

    -- Don't process if paused or disabled
    if not ap.enabled or ap.isPaused then return end

    -- Accumulate timer
    ap.timer = ap.timer + dt

    -- Phase-specific stuck detection with different timeout rules
    local phaseTimeout = ap.maxStuckTime or 15  -- Default 15 seconds
    local shouldCheckStuck = true

    -- Adjust timeout and behavior based on current phase
    if state.phase == "combat" then
        -- Combat gets shorter timeout (5 seconds) since turns should be quick
        phaseTimeout = 5
        -- Only check stuck if it's player's turn (avoid false positives during enemy turns)
        shouldCheckStuck = state.combat and state.combat.isPlayerTurn
    elseif state.phase == "tactical_combat" then
        -- Tactical combat: longer timeout (10s) due to grid movement + attack animations
        phaseTimeout = 10
        -- Only check stuck if it's the player's turn in tactical combat
        local ts = tacticalStateRef and tacticalStateRef()
        if ts and ts.activeUnit then
            shouldCheckStuck = ts.activeUnit.isPlayer
        else
            shouldCheckStuck = false
        end
    elseif state.phase == "camping" or state.phase == "resting" then
        -- Resting phases shouldn't trigger stuck detection
        shouldCheckStuck = false
    elseif state.phase == "lockpicking" or state.phase == "jail" or state.phase == "burglary_success" then
        -- Special phases get shorter timeout
        phaseTimeout = 8
    elseif state.phase == "dungeon" then
        -- Dungeons might need navigation, give more time
        phaseTimeout = 20
    end

    -- Update stuck timer with actual delta time (for accurate timeout)
    local curPosX, curPosY = getPlayerPosition(state)
    if shouldCheckStuck and curPosX then
        if ap.lastPosition and ap.lastPosition.x == curPosX and ap.lastPosition.y == curPosY then
            ap.stuckTimer = (ap.stuckTimer or 0) + dt

            -- Check if we've been stuck for the phase-specific timeout
            if ap.stuckTimer >= phaseTimeout then
                AutoPlay.handleStuckState(state)
                ap.stuckTimer = 0
                ap.stuckCounter = 0
            end
        else
            -- Player moved - reset stuck detection
            ap.stuckTimer = 0
        end
    else
        -- Phase doesn't need stuck detection - keep timer at 0
        ap.stuckTimer = 0
    end

    -- Use faster delay during combat phases
    local effectiveDelay = ap.actionDelay
    if state.phase == "tactical_combat" or state.phase == "combat" then
        effectiveDelay = AutoPlay.config.combatDelay or 0.5
    end

    -- Execute action when timer exceeds delay
    if ap.timer >= effectiveDelay then
        ap.timer = 0  -- Reset timer

        -- Perform auto-play turn
        AutoPlay.performTurn(state)
    end
end

-- Perform one auto-play turn (main decision function)
function AutoPlay.performTurn(state)
    -- Error handling wrapper to prevent crashes
    local success, errorMsg = pcall(function()
        -- Safety checks
        if not AutoPlay.canContinueAutoPlay(state) then
            AutoPlay.pauseAutoPlay(state, "safety")
            return
        end

        -- Increment action counter
        state.autoPlay.stats.actionsPerformed = state.autoPlay.stats.actionsPerformed + 1

        -- Phase-specific logic
        if state.phase == "combat" then
            AutoPlay.handleAutoCombat(state)
        elseif state.phase == "tactical_combat" then
            AutoPlay.handleAutoTacticalCombat(state)
        elseif state.phase == "town" then
            AutoPlay.handleAutoTown(state)
        elseif state.phase == "map" then
            AutoPlay.handleAutoMap(state)
        elseif state.phase == "npc_list" then
            AutoPlay.handleAutoNPCInteraction(state)
        elseif state.phase == "job_board" then
            AutoPlay.handleAutoJobBoard(state)
        elseif state.phase == "dialogue" then
            AutoPlay.handleAutoDialogue(state)
        elseif state.phase == "dungeon" then
            AutoPlay.handleAutoDungeon(state)
        elseif state.phase == "building_interior" or state.phase == "tavern_interior" or state.phase == "guild_interior" then
            -- In building - try to leave
            AutoPlay.debugLog("In building interior - attempting to leave")
            state.phase = "town"
        elseif state.phase == "npc_dialogue" then
            -- In dialogue - exit it
            AutoPlay.debugLog("In NPC dialogue - exiting")
            state.phase = "town"
        else
            -- Unknown phase, try to return to safe state
            AutoPlay.returnToSafePhase(state)
        end
    end)

    -- If an error occurred, log it and attempt recovery
    if not success then
        log("⚠️ Auto-play error: " .. tostring(errorMsg), {0.9, 0.5, 0.3})
        AutoPlay.debugLog("Error in performTurn: " .. tostring(errorMsg))

        -- Emergency recovery
        if AutoPlay.returnToSafePhase then
            AutoPlay.returnToSafePhase(state)
        else
            -- Fallback recovery if function doesn't exist
            state.phase = "map"
            state.autoPlay.targetLocation = nil
            state.autoPlay.currentAction = "Recovering from error..."
        end
    end
end

-- ============================================================================
-- SAFETY CHECKS
-- ============================================================================

-- Check if auto-play can continue safely
function AutoPlay.canContinueAutoPlay(state)
    if not state or not state.player then return false end

    local player = state.player
    local ap = state.autoPlay

    -- Check for death
    if player.hp <= 0 or state.phase == "game_over" or state.phase == "death" then
        AutoPlay.stopAutoPlay(state, "Player died")
        return false
    end

    -- Check for critically low HP
    if player.hp < (player.maxHP * AutoPlay.config.safetyThreshold) then
        AutoPlay.addPauseReason(state, "Low HP (" .. player.hp .. "/" .. player.maxHP .. ")")
        return false
    end

    -- Check for level up (pause to let player allocate stats)
    if AutoPlay.config.pauseOnLevelUp and state.phase == "levelup" then
        AutoPlay.addPauseReason(state, "Level up - allocate stats")
        return false
    end

    -- Check for inventory full (if config enabled)
    if AutoPlay.config.pauseOnInventoryFull then
        -- Check if backpack is close to full
        local Backpack = package.loaded["backpack"]
        if Backpack and Backpack.getInventoryStats then
            local stats = Backpack.getInventoryStats()
            if stats and stats.itemCount and stats.maxItems then
                if stats.itemCount >= stats.maxItems - 2 then
                    AutoPlay.addPauseReason(state, "Inventory nearly full (" .. stats.itemCount .. "/" .. stats.maxItems .. ")")
                    return false
                end
            end
        end
    end

    -- REMOVED OLD STUCK DETECTION - Now handled in update() with time-based system
    -- This prevents duplicate stuck detection that could cause pauses

    -- Update last position for stuck detection in update()
    local posX, posY = getPlayerPosition(state)
    if posX then
        if not ap.lastPosition then
            ap.lastPosition = {}
        end
        ap.lastPosition.x = posX
        ap.lastPosition.y = posY
    end

    -- All checks passed
    return true
end

-- Pause auto-play with reason
function AutoPlay.pauseAutoPlay(state, reason)
    if not state or not state.autoPlay then return end
    state.autoPlay.isPaused = true
    AutoPlay.addPauseReason(state, reason)
    log("⏸️ Auto-play paused: " .. reason, {0.9, 0.9, 0.3})
end

-- Add a pause reason to the list
function AutoPlay.addPauseReason(state, reason)
    if not state or not state.autoPlay then return end
    table.insert(state.autoPlay.pauseReasons, reason)

    -- HIGH PRIORITY FIX #3: Limit pause reasons to prevent accumulation
    local MAX_PAUSE_REASONS = 5
    while #state.autoPlay.pauseReasons > MAX_PAUSE_REASONS do
        table.remove(state.autoPlay.pauseReasons, 1)
    end
end

-- Resume auto-play (clear pause reasons)
function AutoPlay.resumeAutoPlay(state)
    if not state or not state.autoPlay then return end
    state.autoPlay.isPaused = false
    state.autoPlay.pauseReasons = {}
    log("▶️ Auto-play resumed", {0.3, 0.9, 0.3})
end

-- Handle stuck state by resetting and trying alternative action
function AutoPlay.handleStuckState(state)
    if not state or not state.autoPlay then return end

    local ap = state.autoPlay
    ap.retryAttempts = (ap.retryAttempts or 0) + 1

    -- Clear current objective to force new decision
    ap.targetLocation = nil
    local previousAction = ap.currentAction
    ap.currentAction = nil

    -- Log the retry attempt
    log("🔄 Stuck detected (attempt #" .. ap.retryAttempts .. ") - trying alternative approach", {0.9, 0.7, 0.3})

    -- Store last action to avoid immediate repeat
    ap.lastAction = previousAction

    -- Add variation to avoid getting stuck in same pattern
    local stuckPosX, stuckPosY = getPlayerPosition(state)
    if ap.retryAttempts % 3 == 0 and stuckPosX then
        -- Every 3rd retry, try moving to a random nearby location to unstick
        local randX = stuckPosX + math.random(-3, 3)
        local randY = stuckPosY + math.random(-3, 3)
        ap.targetLocation = {x = randX, y = randY, type = "unstuck_wander"}
        log("  → Moving randomly to unstick (" .. randX .. ", " .. randY .. ")", {0.7, 0.7, 0.7})
    elseif ap.retryAttempts % 5 == 0 then
        -- Every 5th retry, return to nearest town
        local nearestTown = AutoPlay.findNearestTown(state)
        if nearestTown then
            ap.targetLocation = {x = nearestTown.x, y = nearestTown.y, type = "return_to_town"}
            log("  → Returning to " .. nearestTown.name .. " to reset", {0.7, 0.7, 0.7})
        end
    else
        -- Normal retry - let decision AI pick a different action
        log("  → Branching to alternative action from goal priorities", {0.7, 0.7, 0.7})
    end

    -- Reset stuck timer for next detection cycle
    ap.stuckTimer = 0
end

-- Stop auto-play completely
function AutoPlay.stopAutoPlay(state, reason)
    if not state or not state.autoPlay then return end
    state.autoPlay.enabled = false
    state.autoPlay.isPaused = false
    state.autoPlay.pauseReasons = {}
    if reason then
        log("⏹️ Auto-play stopped: " .. reason, {0.9, 0.5, 0.5})
    end
end

-- ============================================================================
-- TOGGLE & GOAL SELECTION
-- ============================================================================

-- Toggle auto-play on/off (called by 'A' key)
function AutoPlay.toggleAutoPlay(state)
    if not state or not state.autoPlay then
        log("❌ Auto-play not initialized", {0.9, 0.3, 0.3})
        return
    end

    local ap = state.autoPlay

    -- If currently enabled, disable
    if ap.enabled then
        AutoPlay.stopAutoPlay(state, "Toggled off by player")
        return
    end

    -- Enable with current goal
    ap.enabled = true
    ap.isPaused = false
    ap.pauseReasons = {}
    ap.timer = 0

    local goalData = AutoPlay.GOALS[ap.goal]
    local goalName = goalData and goalData.name or ap.goal
    log("🤖 Auto-play enabled: " .. goalName, {0.3, 0.9, 0.3})
end

-- Set auto-play goal
function AutoPlay.setGoal(state, goalId)
    if not state or not state.autoPlay then return end
    if not AutoPlay.GOALS[goalId] then
        log("❌ Invalid goal: " .. tostring(goalId), {0.9, 0.3, 0.3})
        return
    end

    state.autoPlay.goal = goalId

    -- If already enabled, log the change
    if state.autoPlay.enabled then
        local goalData = AutoPlay.GOALS[goalId]
        log("🤖 Auto-play goal changed: " .. goalData.name, {0.3, 0.9, 0.9})
    end
end

-- ============================================================================
-- PHASE-SPECIFIC HANDLERS (Placeholders - to be implemented in later phases)
-- ============================================================================

function AutoPlay.handleAutoCombat(state)
    -- Combat AI: Make intelligent combat decisions

    -- Failsafe: If combat doesn't exist, try to exit combat phase
    if not state.combat then
        AutoPlay.debugLog("Combat state missing - attempting to exit combat phase")
        state.phase = "map"  -- Force back to map
        return
    end

    if not state.combat.isPlayerTurn then
        AutoPlay.setCurrentAction(state, "Waiting for turn...")
        return
    end

    -- Combat turn timeout failsafe: If we've been waiting too long, force an attack
    state.autoPlay.combatTurnTimer = (state.autoPlay.combatTurnTimer or 0) + 1
    if state.autoPlay.combatTurnTimer > 10 then
        AutoPlay.debugLog("Combat turn timeout - forcing basic attack")
        state.autoPlay.combatTurnTimer = 0
        AutoPlay.attackEnemy(state)  -- Force attack to unstick
        return
    end

    local player = state.player
    local combat = state.combat

    -- Critical Bug Fix #1: Check if enemies exist
    if not combat.enemies or #combat.enemies == 0 then
        AutoPlay.debugLog("No enemies in combat")
        return
    end

    local hpPercent = player.hp / player.maxHP

    -- Get strongest enemy (highest current HP)
    local strongestEnemy = nil
    local strongestIdx = 1
    local maxEnemyHP = 0
    for i, enemy in ipairs(combat.enemies) do
        if enemy.hp > 0 and enemy.hp > maxEnemyHP then
            strongestEnemy = enemy
            strongestIdx = i
            maxEnemyHP = enemy.hp
        end
    end

    -- No valid targets, advance turn
    if not strongestEnemy then
        AutoPlay.debugLog("No valid enemy targets")
        return
    end

    -- Select strongest enemy as target
    combat.selectedTarget = strongestIdx

    -- Critical HP - try to run away
    if hpPercent < 0.3 then
        AutoPlay.setCurrentAction(state, "Attempting to flee (low HP)...")
        AutoPlay.attemptRunAway(state)
        return
    end

    -- Low HP - try to heal if we have healing skill
    -- Skills that heal: "Heal", "Divine Shield"
    if hpPercent < 0.5 and player.skills and player.mana >= 15 then
        for _, skillName in ipairs(player.skills) do
            if skillName == "Heal" and player.mana >= 15 then
                AutoPlay.setCurrentAction(state, "Using healing skill: " .. skillName)
                AutoPlay.useSkillSafe(state, skillName)
                return
            end
        end
    end

    -- Check if we should use offensive skills
    local enemyCount = 0
    for _, enemy in ipairs(combat.enemies) do
        if enemy.hp > 0 then
            enemyCount = enemyCount + 1
        end
    end

    -- Use powerful skills if we have mana (prioritize high damage skills)
    -- Lightning Bolt (30 mana, 50 damage), Fireball (20 mana, 35 damage), etc.
    if player.skills and player.mana >= 20 then
        local skillPriority = {
            -- AoE/high damage skills
            {name = "Lightning Bolt", mana = 30, minEnemies = 1},  -- Single powerful hit
            {name = "Fireball", mana = 20, minEnemies = 2},        -- Good for 2+ enemies
            {name = "Smite", mana = 20, minEnemies = 1},           -- Holy damage
            {name = "Backstab", mana = 15, minEnemies = 1},        -- High crit
            {name = "Power Strike", mana = 10, minEnemies = 1},    -- Basic damage skill
        }

        for _, skillInfo in ipairs(skillPriority) do
            if player.mana >= skillInfo.mana and enemyCount >= skillInfo.minEnemies then
                -- Check if player has this skill
                for _, playerSkill in ipairs(player.skills) do
                    if playerSkill == skillInfo.name then
                        AutoPlay.setCurrentAction(state, "Using skill: " .. skillInfo.name)
                        AutoPlay.useSkillSafe(state, skillInfo.name)
                        return
                    end
                end
            end
        end
    end

    -- Default: basic attack
    AutoPlay.setCurrentAction(state, "Attacking " .. strongestEnemy.name)
    AutoPlay.attackEnemy(state)
end

-- ============================================================================
-- TACTICAL COMBAT AUTO-PLAY HANDLER
-- Uses the TacticalAI companion logic to control the player unit on the grid
-- ============================================================================
function AutoPlay.handleAutoTacticalCombat(state)
    -- Lazy-load tactical combat modules if not yet set via setTacticalReferences
    if not TacticalCombat or not TacticalAI then
        local ok1, tc = pcall(require, "tactical_combat")
        local ok2, tai = pcall(require, "tactical_combat_ai")
        if ok1 and ok2 and tc and tai then
            TacticalCombat = tc
            TacticalAI = tai
            if TacticalAI.init then TacticalAI.init(TacticalCombat) end
            AutoPlay.debugLog("Lazy-loaded tactical combat modules for auto-play")
        else
            AutoPlay.debugLog("Tactical combat modules not available - cannot auto-fight")
            AutoPlay.setCurrentAction(state, "Waiting (tactical modules unavailable)...")
            return
        end
    end

    -- Get current tactical combat state
    local ts = tacticalStateRef and tacticalStateRef()
    if not ts then
        AutoPlay.debugLog("No active tactical combat state - exiting tactical phase")
        -- Tactical state is nil but phase is still tactical_combat: combat already ended
        return
    end

    -- Combat already ended (victory/defeat handled by textrpg.lua update loop)
    if ts.combatEnded then
        AutoPlay.setCurrentAction(state, "Combat ending...")
        return
    end

    -- Get the active unit in the turn order
    local active = ts.activeUnit
    if not active then
        AutoPlay.setCurrentAction(state, "Waiting for turn order...")
        return
    end

    -- If it's not a player-controlled unit's turn, wait for the AI update loop in textrpg.lua
    -- Enemy and AI companion turns are handled by the tactical combat update in textrpg.lua
    if not active.isPlayer and not active.isPlayerControlled then
        AutoPlay.setCurrentAction(state, "Waiting for " .. (active.name or "enemy") .. "'s turn...")
        -- Set timer near threshold so we retry quickly (0.1s) instead of full delay
        local ap = state.autoPlay
        if ap then
            local effectiveDelay = AutoPlay.config.combatDelay or 0.5
            ap.timer = math.max(ap.timer, effectiveDelay - 0.1)
        end
        return
    end

    -- It's the player's turn! Use the TacticalAI companion logic to decide and execute actions.
    -- The companion AI already handles: find target, move toward target, attack, heal.
    AutoPlay.setCurrentAction(state, "Fighting tactically...")

    local results = TacticalAI.executeCompanionTurn(ts, active)

    -- Log the AI's actions
    if results then
        if results.stunned then
            TacticalCombat.addLog(ts,
                active.name .. " is stunned and cannot act!",
                {0.9, 0.9, 0.3})
        end

        if results.moved then
            TacticalCombat.addLog(ts,
                active.name .. " moves to (" .. active.x .. "," .. active.y .. ")",
                {0.3, 0.9, 0.4})
            AutoPlay.setCurrentAction(state, "Moved to (" .. active.x .. "," .. active.y .. ")")
        end

        if results.attacked and results.attackResult then
            local ar = results.attackResult
            local targetName = results.target and results.target.name or "target"
            local msg
            if ar.dodged then
                msg = active.name .. " attacks " .. targetName .. " but MISSES!"
                TacticalCombat.addLog(ts, msg, {0.6, 0.6, 0.7})
            else
                msg = active.name .. " attacks " .. targetName .. " for " .. ar.damage .. " damage!"
                if ar.isCrit then msg = "CRITICAL! " .. msg end
                if ar.flanked then msg = msg .. " (flanked!)" end
                TacticalCombat.addLog(ts, msg, {0.9, 0.6, 0.3})
            end
            AutoPlay.setCurrentAction(state, "Attacked " .. targetName)

            if ar.targetDown then
                TacticalCombat.addLog(ts,
                    results.target.name .. " is defeated!", {0.9, 0.9, 0.3})
                -- Track enemy defeat for XP/gold/quest progress
                -- Use global lookup (onEnemyDefeated is exposed via F table + _G metatable in textrpg.lua)
                if results.target.isEnemy and results.target.data then
                    if onEnemyDefeated then
                        onEnemyDefeated(results.target.data)
                    end
                end
            end
        end

        if results.healed then
            TacticalCombat.addLog(ts,
                active.name .. " heals " .. (results.healTarget and results.healTarget.name or "ally") ..
                " for " .. (results.healAmount or 0) .. " HP!",
                {0.3, 0.9, 0.5})
            AutoPlay.setCurrentAction(state, "Healed " .. (results.healTarget and results.healTarget.name or "ally"))
        end
    end

    -- Check combat end conditions
    if TacticalCombat.checkAllEnemiesDefeated(ts) then
        TacticalCombat.syncToGameState(ts, state.player)
        ts.combatEnded = true
        ts.victory = true
        -- endCombat is exposed via F table + _G metatable in textrpg.lua
        if endCombat then
            endCombat(true)
        end
        -- Clear the tacticalState local in textrpg.lua
        if tacticalStateClear then tacticalStateClear() end
        state.autoPlay.stats.combatsWon = state.autoPlay.stats.combatsWon + 1
        AutoPlay.debugLog("Tactical combat won! Total wins: " .. state.autoPlay.stats.combatsWon)
        AutoPlay.checkQuestCompletion(state)
        -- Reset combat turn timer
        state.autoPlay.combatTurnTimer = 0
        return
    end

    if TacticalCombat.checkPlayerDead(ts) then
        TacticalCombat.syncToGameState(ts, state.player)
        ts.combatEnded = true
        ts.victory = false
        if endCombat then
            endCombat(false)
        end
        -- Clear the tacticalState local in textrpg.lua
        if tacticalStateClear then tacticalStateClear() end
        return
    end

    -- Advance to the next turn (player's turn is done)
    local nextUnit = TacticalCombat.advanceTurn(ts)
    if nextUnit then
        TacticalCombat.addLog(ts,
            nextUnit.name .. "'s turn!",
            nextUnit.color or {0.8, 0.8, 0.8})
    end
end

-- Helper: Attempt to run away from combat
function AutoPlay.attemptRunAway(state)
    if math.random() < 0.5 then
        state.phase = "map"
        log("🏃 Auto-play: Escaped from combat!", {0.7, 0.7, 0.3})
        AutoPlay.setCurrentAction(state, "Escaped from combat")
        -- Reset combat timer when leaving combat
        state.autoPlay.combatTurnTimer = 0
    else
        log("⚠️ Auto-play: Couldn't escape!", {0.9, 0.3, 0.3})
        AutoPlay.setCurrentAction(state, "Failed to escape")
        -- Critical Bug Fix #3: advanceTurn is not accessible from autoplay module
        -- Combat will continue naturally - no need to manually advance turn
    end
end

-- Helper: Attack selected enemy
function AutoPlay.attackEnemy(state)
    -- Call the player attack function from textrpg.lua
    if F and F.playerAttack then
        F.playerAttack()
    elseif playerAttack then
        playerAttack()
    else
        log("❌ Auto-play: playerAttack function not found", {0.9, 0.3, 0.3})
        return
    end

    -- Check if combat ended (victory)
    if state.phase ~= "combat" then
        state.autoPlay.stats.combatsWon = state.autoPlay.stats.combatsWon + 1
        AutoPlay.debugLog("Combat won! Total wins: " .. state.autoPlay.stats.combatsWon)

        -- Reset combat timer when leaving combat
        state.autoPlay.combatTurnTimer = 0

        -- Check if any quests were completed
        AutoPlay.checkQuestCompletion(state)
    end
end

-- Check if any quests were just completed and update statistics
function AutoPlay.checkQuestCompletion(state)
    if not state.player.activeQuests then return end

    for _, quest in ipairs(state.player.activeQuests) do
        -- CRITICAL FIX #2: Add nil checks for quest properties
        if quest and quest.progress and quest.target then
            -- Check if quest was just completed (progress >= target but not marked complete yet)
            if quest.progress >= quest.target and not quest.wasCompleted then
                quest.wasCompleted = true  -- Mark to avoid double-counting
                state.autoPlay.stats.questsCompleted = state.autoPlay.stats.questsCompleted + 1
                log("✅ Auto-play: Quest completed! (" .. state.autoPlay.stats.questsCompleted .. " total)", {0.3, 0.9, 0.3})
            end
        end
    end
end

-- Helper: Use skill safely
function AutoPlay.useSkillSafe(state, skillName)
    if not skillName then return end

    -- Call the useSkill function from textrpg.lua
    if F and F.useSkill then
        F.useSkill(skillName)
    elseif useSkill then
        useSkill(skillName)
    else
        log("❌ Auto-play: useSkill function not found", {0.9, 0.3, 0.3})
    end
end

function AutoPlay.handleAutoTown(state)
    -- Town AI: Handle town actions based on needs and goals

    local player = state.player
    local goal = state.autoPlay.goal

    -- First priority: If low HP, go to inn
    local hpPercent = player.hp / player.maxHP
    if hpPercent < 0.8 then
        AutoPlay.setCurrentAction(state, "Resting at inn...")
        -- TODO: Implement inn rest action
        -- For now, just heal to full and leave
        player.hp = player.maxHP
        player.mana = player.maxMana
        log("🏨 Auto-play: Rested at inn (HP/Mana restored)", {0.3, 0.9, 0.3})
        -- Small delay before leaving
        state.autoPlay.timer = -0.5  -- Wait an extra half second
        state.phase = "map"
        return
    end

    -- Second priority: If inventory full, go to shop
    -- TODO: Check inventory fullness and sell items

    -- Goal-specific town actions
    if goal == "questing" or goal == "jobbing" then
        -- Check if we need quests
        local needsQuest = not state.player.activeQuests or #state.player.activeQuests == 0

        if needsQuest then
            -- Go to job board to get quests
            AutoPlay.setCurrentAction(state, "Checking job board...")
            state.phase = "job_board"
        else
            -- Already have quests, leave town
            AutoPlay.setCurrentAction(state, "Leaving town to complete quests...")
            state.phase = "map"
        end

    elseif goal == "gathering" then
        -- Check if town has fishing dock
        AutoPlay.setCurrentAction(state, "Checking for gathering opportunities...")
        -- Leave town to gather in the wild
        state.phase = "map"
    else
        -- Default: Just leave town
        AutoPlay.setCurrentAction(state, "Leaving town...")
        state.phase = "map"
    end
end

function AutoPlay.handleAutoMap(state)
    -- Map AI: Navigate based on goal

    local goal = state.autoPlay.goal
    local player = state.player
    local world = state.world

    -- Safety: If low HP, travel to nearest town for rest
    local hpPercent = player.hp / player.maxHP
    if hpPercent < 0.5 then
        AutoPlay.setCurrentAction(state, "Low HP - seeking town...")
        AutoPlay.travelToNearestTown(state)
        return
    end

    -- Goal-specific behavior
    if goal == "questing" then
        AutoPlay.handleQuesting(state)
    elseif goal == "jobbing" then
        AutoPlay.handleJobbing(state)
    elseif goal == "gathering" then
        AutoPlay.handleGathering(state)
    elseif goal == "fighting" then
        AutoPlay.handleFighting(state)
    elseif goal == "exploring" then
        AutoPlay.handleExploring(state)
    elseif goal == "all" then
        AutoPlay.handleAllActivities(state)
    elseif goal == "testing" then
        AutoPlay.handleTesting(state)
    else
        -- Unknown goal, explore
        AutoPlay.handleExploring(state)
    end
end

-- ============================================================================
-- GOAL-SPECIFIC MAP HANDLERS
-- ============================================================================

function AutoPlay.handleQuesting(state)
    AutoPlay.setCurrentAction(state, "Questing mode...")

    -- Check if we have active quests
    if state.player.activeQuests and #state.player.activeQuests > 0 then
        -- Check if any quests are completed
        local hasCompletedQuest = false
        for _, quest in ipairs(state.player.activeQuests) do
            -- CRITICAL FIX #2: Add nil check
            if quest and quest.completed then
                hasCompletedQuest = true
                break
            end
        end

        if hasCompletedQuest then
            -- Go turn in completed quests
            AutoPlay.setCurrentAction(state, "Returning to turn in quest...")
            AutoPlay.travelToNearestTown(state)
        else
            -- Work on active quests
            local quest = state.player.activeQuests[1]  -- Focus on first quest

            if quest.type == "kill" then
                -- Critical Bug Fix #8: Nil-safe quest progress
                local progress = quest.progress or 0
                local target = quest.target or "?"
                AutoPlay.setCurrentAction(state, "Hunting " .. (quest.enemyId or "enemies") .. " (" .. progress .. "/" .. target .. ")")
                -- Move around to trigger encounters
                AutoPlay.moveRandomDirection(state)

            elseif quest.type == "fetch" then
                -- Critical Bug Fix #8: Nil-safe quest progress
                local progress = quest.progress or 0
                local target = quest.target or "?"
                AutoPlay.setCurrentAction(state, "Collecting " .. (quest.itemName or "items") .. " (" .. progress .. "/" .. target .. ")")
                -- Move around to get items from enemies
                AutoPlay.moveRandomDirection(state)

            elseif quest.type == "talk" or quest.type == "deliver" then
                AutoPlay.setCurrentAction(state, "Traveling to " .. (quest.location or "destination") .. "...")
                -- Try to find the target location (town)
                local targetTown = AutoPlay.findTownByName(state, quest.location)
                if targetTown then
                    AutoPlay.moveTowardsTarget(state, targetTown.x, targetTown.y)
                else
                    -- Don't know where it is, explore
                    AutoPlay.moveRandomDirection(state)
                end
            else
                -- Unknown quest type
                AutoPlay.moveRandomDirection(state)
            end
        end
    else
        -- No quests, go to nearest town to get some
        AutoPlay.setCurrentAction(state, "Finding quests...")
        AutoPlay.travelToNearestTown(state)
    end
end

function AutoPlay.handleJobbing(state)
    AutoPlay.setCurrentAction(state, "Jobbing mode...")

    -- Similar to questing, but more focused on gold rewards
    if state.player.activeQuests and #state.player.activeQuests > 0 then
        -- Work on active jobs
        local quest = state.player.activeQuests[1]

        if quest.completed then
            -- Turn in completed job
            AutoPlay.setCurrentAction(state, "Turning in job for reward...")
            AutoPlay.travelToNearestTown(state)
        else
            -- Complete the job
            AutoPlay.setCurrentAction(state, "Working on job: " .. quest.name)

            if quest.type == "kill" then
                AutoPlay.moveRandomDirection(state)  -- Hunt enemies
            elseif quest.type == "fetch" then
                AutoPlay.moveRandomDirection(state)  -- Collect items
            elseif quest.type == "talk" or quest.type == "deliver" then
                local targetTown = AutoPlay.findTownByName(state, quest.location)
                if targetTown then
                    AutoPlay.moveTowardsTarget(state, targetTown.x, targetTown.y)
                else
                    AutoPlay.moveRandomDirection(state)
                end
            end
        end
    else
        -- No jobs, get more from town
        AutoPlay.setCurrentAction(state, "Traveling to town for jobs...")
        AutoPlay.travelToNearestTown(state)
    end
end

function AutoPlay.handleGathering(state)
    -- Look for resource tiles (forests for lumber, etc.)
    local playerX, playerY = getPlayerPosition(state)
    if not playerX then
        AutoPlay.debugLog("No valid player position for gathering")
        return
    end

    -- Check current tile
    local currentTile = AutoPlay.getTileAt(state, playerX, playerY)
    if currentTile and currentTile.type == "forest" then
        -- We're on a forest tile - try to gather lumber
        AutoPlay.setCurrentAction(state, "Gathering lumber...")

        -- Try to chop lumber
        local chopSuccess = AutoPlay.chopLumberSafe(state, playerX, playerY)

        if chopSuccess then
            -- Successfully gathered lumber
            state.autoPlay.stats.resourcesGathered = state.autoPlay.stats.resourcesGathered + 1
            log("🪓 Auto-play: Gathered lumber!", {0.3, 0.9, 0.3})

            -- Stay on this tile and gather more (or move to next forest)
            -- For variety, 50% chance to move after gathering
            if math.random() < 0.5 then
                AutoPlay.moveRandomDirection(state)
            end
        else
            -- Can't gather here (no tool, already gathered, etc.)
            -- Move to find another forest tile
            local targetTile = AutoPlay.findNearbyTileOfType(state, "forest", 10)
            if targetTile then
                AutoPlay.moveTowardsTarget(state, targetTile.x, targetTile.y)
            else
                AutoPlay.moveRandomDirection(state)
            end
        end
    else
        -- Move towards forest tiles
        AutoPlay.setCurrentAction(state, "Seeking resources...")
        local targetTile = AutoPlay.findNearbyTileOfType(state, "forest", 10)
        if targetTile then
            AutoPlay.moveTowardsTarget(state, targetTile.x, targetTile.y)
        else
            AutoPlay.moveRandomDirection(state)
        end
    end
end

-- Helper: Safely chop lumber
function AutoPlay.chopLumberSafe(state, x, y)
    -- Check if PropertySystem is available
    local hasPropertySystem, PropertySystem = pcall(require, "propertysystem")
    if not hasPropertySystem then
        AutoPlay.debugLog("PropertySystem not available for lumber gathering")
        return false
    end

    -- Check if player has lumber tool
    if PropertySystem.hasLumberTool and not PropertySystem.hasLumberTool() then
        AutoPlay.debugLog("No lumber tool equipped")
        return false
    end

    -- Try to chop lumber
    if PropertySystem.chopLumber then
        local success, message, amount, deforested = PropertySystem.chopLumber(x, y)
        if success and amount and amount > 0 then
            return true
        end
    end

    return false
end

function AutoPlay.handleFighting(state)
    -- Seek out combat encounters
    AutoPlay.setCurrentAction(state, "Seeking combat...")

    -- Check for dungeons nearby
    local dungeon = AutoPlay.findNearbyTileOfType(state, "dungeon", 8)
    if dungeon then
        AutoPlay.setCurrentAction(state, "Moving to dungeon...")
        AutoPlay.moveTowardsTarget(state, dungeon.x, dungeon.y)
    else
        -- Just move around to trigger encounters
        AutoPlay.moveRandomDirection(state)
    end
end

function AutoPlay.handleExploring(state)
    -- Find unexplored tiles and explore them
    AutoPlay.setCurrentAction(state, "Exploring new areas...")

    local unexploredTile = AutoPlay.findNearestUnexploredTile(state, 10)
    if unexploredTile then
        AutoPlay.moveTowardsTarget(state, unexploredTile.x, unexploredTile.y)
    else
        -- All nearby tiles explored, move in a direction
        AutoPlay.moveRandomDirection(state)
    end
end

function AutoPlay.handleAllActivities(state)
    -- Balanced rotation of activities
    local activityIndex = math.floor(state.autoPlay.stats.actionsPerformed / 10) % 5

    if activityIndex == 0 then
        AutoPlay.handleQuesting(state)
    elseif activityIndex == 1 then
        AutoPlay.handleFighting(state)
    elseif activityIndex == 2 then
        AutoPlay.handleGathering(state)
    elseif activityIndex == 3 then
        AutoPlay.handleExploring(state)
    else
        AutoPlay.handleJobbing(state)
    end
end

function AutoPlay.handleTesting(state)
    -- Testing mode: Execute QA checklist systematically
    local testData = state.autoPlay.testData

    -- Initialize test checklist if not set
    if not testData.checklist or #testData.checklist == 0 then
        AutoPlay.initializeTestChecklist(state)
    end

    -- Check if all tests complete
    if testData.currentTestIndex > #testData.checklist then
        AutoPlay.setCurrentAction(state, "All tests complete!")
        AutoPlay.generateTestReport(state)
        -- Stop auto-play after tests complete
        AutoPlay.stopAutoPlay(state, "Testing complete")
        return
    end

    -- Get current test
    local currentTest = testData.checklist[testData.currentTestIndex]
    if not currentTest then
        testData.currentTestIndex = testData.currentTestIndex + 1
        return
    end

    -- Execute the test
    AutoPlay.setCurrentAction(state, "Testing: " .. currentTest.name)
    local success, error = AutoPlay.executeTest(state, currentTest)

    -- Log result
    local result = {
        test = currentTest.name,
        success = success,
        error = error,
        timestamp = os.date("%H:%M:%S"),
    }
    table.insert(testData.results, result)

    -- CRITICAL FIX #1: Limit test results to prevent unbounded growth
    local MAX_TEST_RESULTS = 100
    while #testData.results > MAX_TEST_RESULTS do
        table.remove(testData.results, 1)
    end

    -- Log to console
    if success then
        log("✅ Test PASSED: " .. currentTest.name, {0.3, 0.9, 0.3})
    else
        log("❌ Test FAILED: " .. currentTest.name .. " (" .. (error or "unknown error") .. ")", {0.9, 0.3, 0.3})
        testData.crashesDetected = testData.crashesDetected + 1
    end

    -- Move to next test
    testData.currentTestIndex = testData.currentTestIndex + 1
end

-- ============================================================================
-- TESTING MODE IMPLEMENTATION
-- ============================================================================

-- Initialize default test checklist
function AutoPlay.initializeTestChecklist(state)
    local testData = state.autoPlay.testData

    -- Define comprehensive test checklist
    testData.checklist = {
        -- Basic Movement Tests
        {name = "Move North", action = "move", params = {dx = 0, dy = -1}},
        {name = "Move East", action = "move", params = {dx = 1, dy = 0}},
        {name = "Move South", action = "move", params = {dx = 0, dy = 1}},
        {name = "Move West", action = "move", params = {dx = -1, dy = 0}},

        -- Combat Tests
        {name = "Trigger Combat Encounter", action = "seek_combat", params = {attempts = 5}},
        {name = "Basic Attack in Combat", action = "combat_attack", params = {}},
        {name = "Use Skill in Combat", action = "combat_skill", params = {}},
        {name = "Flee from Combat", action = "combat_flee", params = {}},

        -- Navigation Tests
        {name = "Find Nearest Town", action = "find_town", params = {}},
        {name = "Travel to Town", action = "travel_to_town", params = {}},
        {name = "Enter Town", action = "enter_town", params = {}},
        {name = "Leave Town", action = "leave_town", params = {}},

        -- Quest Tests
        {name = "Go to Job Board", action = "go_to_job_board", params = {}},
        {name = "Accept Quest", action = "accept_quest", params = {}},
        {name = "Check Active Quests", action = "check_quests", params = {}},

        -- Gathering Tests
        {name = "Find Forest Tile", action = "find_forest", params = {}},
        {name = "Attempt Lumber Gathering", action = "gather_lumber", params = {}},

        -- Exploration Tests
        {name = "Find Unexplored Tile", action = "find_unexplored", params = {}},
        {name = "Explore New Area", action = "explore", params = {}},

        -- UI Tests
        {name = "Check Player HP", action = "check_hp", params = {}},
        {name = "Check Player Gold", action = "check_gold", params = {}},
        {name = "Check Inventory", action = "check_inventory", params = {}},

        -- Phase Transition Tests
        {name = "Phase: Map to Town", action = "phase_transition", params = {from = "map", to = "town"}},
        {name = "Phase: Town to Map", action = "phase_transition", params = {from = "town", to = "map"}},
    }

    testData.currentTestIndex = 1
    testData.results = {}
    testData.crashesDetected = 0

    log("🧪 Testing Mode: Initialized " .. #testData.checklist .. " tests", {0.7, 0.7, 0.9})
end

-- Execute a single test
function AutoPlay.executeTest(state, test)
    -- Wrap in pcall to catch errors
    local success, error = pcall(function()
        local action = test.action
        local params = test.params or {}

        if action == "move" then
            return AutoPlay.testMove(state, params.dx, params.dy)

        elseif action == "seek_combat" then
            return AutoPlay.testSeekCombat(state, params.attempts or 5)

        elseif action == "combat_attack" then
            return AutoPlay.testCombatAttack(state)

        elseif action == "combat_skill" then
            return AutoPlay.testCombatSkill(state)

        elseif action == "combat_flee" then
            return AutoPlay.testCombatFlee(state)

        elseif action == "find_town" then
            return AutoPlay.testFindTown(state)

        elseif action == "travel_to_town" then
            return AutoPlay.testTravelToTown(state)

        elseif action == "enter_town" then
            return AutoPlay.testEnterTown(state)

        elseif action == "leave_town" then
            return AutoPlay.testLeaveTown(state)

        elseif action == "go_to_job_board" then
            return AutoPlay.testGoToJobBoard(state)

        elseif action == "accept_quest" then
            return AutoPlay.testAcceptQuest(state)

        elseif action == "check_quests" then
            return AutoPlay.testCheckQuests(state)

        elseif action == "find_forest" then
            return AutoPlay.testFindForest(state)

        elseif action == "gather_lumber" then
            return AutoPlay.testGatherLumber(state)

        elseif action == "find_unexplored" then
            return AutoPlay.testFindUnexplored(state)

        elseif action == "explore" then
            return AutoPlay.testExplore(state)

        elseif action == "check_hp" then
            return AutoPlay.testCheckHP(state)

        elseif action == "check_gold" then
            return AutoPlay.testCheckGold(state)

        elseif action == "check_inventory" then
            return AutoPlay.testCheckInventory(state)

        elseif action == "phase_transition" then
            return AutoPlay.testPhaseTransition(state, params.from, params.to)

        else
            error("Unknown test action: " .. action)
        end
    end)

    if success and error == nil then
        return true, nil
    elseif success then
        return error, nil  -- Test function returned success/error
    else
        return false, tostring(error)
    end
end

-- ============================================================================
-- TEST IMPLEMENTATIONS
-- ============================================================================

function AutoPlay.testMove(state, dx, dy)
    local oldX, oldY = getPlayerPosition(state)
    if not oldX then return false, "No valid player position" end
    local success = AutoPlay.moveSafe(state, dx, dy)

    if success then
        local newX, newY = getPlayerPosition(state)
        if newX ~= oldX or newY ~= oldY then
            return true
        else
            return false, "Position didn't change"
        end
    else
        return false, "Move failed"
    end
end

function AutoPlay.testSeekCombat(state, maxAttempts)
    -- Move around to trigger combat
    for i = 1, maxAttempts do
        AutoPlay.moveRandomDirection(state)
        if state.phase == "combat" then
            return true
        end
    end
    return false, "Combat not triggered after " .. maxAttempts .. " moves"
end

function AutoPlay.testCombatAttack(state)
    if state.phase ~= "combat" then
        return false, "Not in combat"
    end

    if not state.combat.isPlayerTurn then
        return false, "Not player's turn"
    end

    AutoPlay.attackEnemy(state)
    return true
end

function AutoPlay.testCombatSkill(state)
    if state.phase ~= "combat" then
        return false, "Not in combat"
    end

    if not state.combat.isPlayerTurn then
        return false, "Not player's turn"
    end

    -- Try to use first available skill
    if state.player.skills and #state.player.skills > 0 then
        local skillName = state.player.skills[1]
        AutoPlay.useSkillSafe(state, skillName)
        return true
    else
        return false, "No skills available"
    end
end

function AutoPlay.testCombatFlee(state)
    if state.phase ~= "combat" then
        return false, "Not in combat"
    end

    AutoPlay.attemptRunAway(state)
    return true
end

function AutoPlay.testFindTown(state)
    local town = AutoPlay.findNearestTown(state)
    if town then
        return true
    else
        return false, "No towns found"
    end
end

function AutoPlay.testTravelToTown(state)
    local town = AutoPlay.findNearestTown(state)
    if not town then
        return false, "No towns found"
    end

    -- Move one step toward town
    AutoPlay.moveTowardsTarget(state, town.x, town.y)
    return true
end

function AutoPlay.testEnterTown(state)
    if state.phase == "town" then
        return true
    else
        -- Try to move to a town tile
        local town = AutoPlay.findNearestTown(state)
        if town then
            local pX, pY = getPlayerPosition(state)
            local dist = pX and (math.abs(town.x - pX) + math.abs(town.y - pY)) or math.huge
            if dist == 0 then
                return true  -- Already in town
            else
                return false, "Not at town location"
            end
        else
            return false, "No towns available"
        end
    end
end

function AutoPlay.testLeaveTown(state)
    if state.phase ~= "town" then
        return false, "Not in town"
    end

    state.phase = "map"
    return true
end

function AutoPlay.testGoToJobBoard(state)
    if state.phase ~= "town" then
        return false, "Not in town"
    end

    state.phase = "job_board"
    return true
end

function AutoPlay.testAcceptQuest(state)
    if state.phase == "job_board" then
        local town = state.world.currentTown
        if town and town.jobBoard and #town.jobBoard > 0 then
            -- Accept first quest
            local quest = town.jobBoard[1]
            table.insert(state.player.activeQuests, quest)
            quest.accepted = true
            table.remove(town.jobBoard, 1)
            return true
        else
            return false, "No quests available on job board"
        end
    else
        return false, "Not at job board"
    end
end

function AutoPlay.testCheckQuests(state)
    if state.player.activeQuests then
        return true
    else
        return false, "Active quests table not found"
    end
end

function AutoPlay.testFindForest(state)
    local forestTile = AutoPlay.findNearbyTileOfType(state, "forest", 10)
    if forestTile then
        return true
    else
        return false, "No forest tiles found within 10 tiles"
    end
end

function AutoPlay.testGatherLumber(state)
    local playerX, playerY = getPlayerPosition(state)
    if not playerX then return false, "No valid player position" end
    local currentTile = AutoPlay.getTileAt(state, playerX, playerY)

    if currentTile and currentTile.type == "forest" then
        local success = AutoPlay.chopLumberSafe(state, playerX, playerY)
        if success then
            return true
        else
            return false, "Lumber gathering failed (no tool or already gathered)"
        end
    else
        return false, "Not on forest tile"
    end
end

function AutoPlay.testFindUnexplored(state)
    local unexploredTile = AutoPlay.findNearestUnexploredTile(state, 10)
    if unexploredTile then
        return true
    else
        return false, "All nearby tiles explored"
    end
end

function AutoPlay.testExplore(state)
    local oldExplored = state.autoPlay.stats.tilesExplored
    AutoPlay.moveRandomDirection(state)
    local newExplored = state.autoPlay.stats.tilesExplored

    if newExplored > oldExplored then
        return true
    else
        return false, "No new tiles explored"
    end
end

function AutoPlay.testCheckHP(state)
    if state.player and state.player.hp and state.player.maxHP then
        if state.player.hp > 0 and state.player.maxHP > 0 then
            return true
        else
            return false, "HP values invalid"
        end
    else
        return false, "HP not found"
    end
end

function AutoPlay.testCheckGold(state)
    if state.player and state.player.gold ~= nil then
        if state.player.gold >= 0 then
            return true
        else
            return false, "Gold value is negative"
        end
    else
        return false, "Gold not found"
    end
end

function AutoPlay.testCheckInventory(state)
    local Backpack = package.loaded["backpack"]
    if Backpack then
        return true
    else
        return false, "Backpack system not loaded"
    end
end

function AutoPlay.testPhaseTransition(state, fromPhase, toPhase)
    if state.phase == fromPhase then
        state.phase = toPhase
        return true
    else
        return false, "Not in '" .. fromPhase .. "' phase (currently in '" .. state.phase .. "')"
    end
end

-- ============================================================================
-- TEST REPORT GENERATION
-- ============================================================================

function AutoPlay.generateTestReport(state)
    local testData = state.autoPlay.testData
    local results = testData.results

    local totalTests = #results
    local passedTests = 0
    local failedTests = 0

    for _, result in ipairs(results) do
        if result.success then
            passedTests = passedTests + 1
        else
            failedTests = failedTests + 1
        end
    end

    local passRate = totalTests > 0 and (passedTests / totalTests * 100) or 0

    log("", {1, 1, 1})
    log("========================================", {0.7, 0.7, 0.9})
    log("       TESTING MODE REPORT", {0.7, 0.7, 0.9})
    log("========================================", {0.7, 0.7, 0.9})
    log("Total Tests: " .. totalTests, {0.9, 0.9, 0.9})
    log("✅ Passed: " .. passedTests, {0.3, 0.9, 0.3})
    log("❌ Failed: " .. failedTests, {0.9, 0.3, 0.3})
    log("Pass Rate: " .. string.format("%.1f%%", passRate), {0.9, 0.9, 0.3})
    log("Crashes Detected: " .. testData.crashesDetected, {0.9, 0.5, 0.3})
    log("========================================", {0.7, 0.7, 0.9})

    -- Log failed tests
    if failedTests > 0 then
        log("", {1, 1, 1})
        log("Failed Tests:", {0.9, 0.5, 0.5})
        for _, result in ipairs(results) do
            if not result.success then
                log("  - " .. result.test .. ": " .. (result.error or "unknown"), {0.9, 0.3, 0.3})
            end
        end
    end

    log("========================================", {0.7, 0.7, 0.9})
    log("Testing complete! 🧪", {0.7, 0.9, 0.7})
end

-- ============================================================================
-- NAVIGATION UTILITIES
-- ============================================================================

-- Move towards a target location
function AutoPlay.moveTowardsTarget(state, targetX, targetY)
    local playerX, playerY = getPlayerPosition(state)
    if not playerX then
        AutoPlay.debugLog("Player position not initialized")
        return
    end

    -- Calculate direction
    local dx = 0
    local dy = 0

    if targetX > playerX then
        dx = 1
    elseif targetX < playerX then
        dx = -1
    end

    if targetY > playerY then
        dy = 1
    elseif targetY < playerY then
        dy = -1
    end

    -- Try to move in the calculated direction
    if dx ~= 0 or dy ~= 0 then
        AutoPlay.moveSafe(state, dx, dy)
    end
end

-- Move in a random direction (for exploration/wandering)
function AutoPlay.moveRandomDirection(state)
    local directions = {
        {dx = 0, dy = -1},  -- North
        {dx = 1, dy = 0},   -- East
        {dx = 0, dy = 1},   -- South
        {dx = -1, dy = 0},  -- West
    }

    local dir = directions[math.random(#directions)]
    AutoPlay.moveSafe(state, dir.dx, dir.dy)
end

-- Safe movement wrapper
function AutoPlay.moveSafe(state, dx, dy)
    -- Medium Issue Fix #18: Only count newly explored tiles
    local preMoveX, preMoveY = getPlayerPosition(state)
    local currentTile = preMoveX and AutoPlay.getTileAt(state, preMoveX, preMoveY) or nil
    local wasExplored = currentTile and currentTile.explored

    -- Call movePlayer from textrpg.lua
    if F and F.movePlayer then
        local success = F.movePlayer(dx, dy)
        if success then
            -- Track exploration (only if tile was not previously explored)
            local postMoveX, postMoveY = getPlayerPosition(state)
            if postMoveX then
                local newTile = AutoPlay.getTileAt(state, postMoveX, postMoveY)
                if newTile and newTile.explored and not wasExplored then
                    state.autoPlay.stats.tilesExplored = state.autoPlay.stats.tilesExplored + 1
                end
            end
        end
        return success
    elseif movePlayer then
        local success = movePlayer(dx, dy)
        if success then
            -- Track exploration (only if tile was not previously explored)
            local postMoveX, postMoveY = getPlayerPosition(state)
            if postMoveX then
                local newTile = AutoPlay.getTileAt(state, postMoveX, postMoveY)
                if newTile and newTile.explored and not wasExplored then
                    state.autoPlay.stats.tilesExplored = state.autoPlay.stats.tilesExplored + 1
                end
            end
        end
        return success
    else
        log("❌ Auto-play: movePlayer function not found", {0.9, 0.3, 0.3})
        return false
    end
end

-- Travel to nearest town
function AutoPlay.travelToNearestTown(state)
    local nearestTown = AutoPlay.findNearestTown(state)

    if nearestTown then
        AutoPlay.setCurrentAction(state, "Traveling to " .. (nearestTown.name or "town") .. "...")
        AutoPlay.moveTowardsTarget(state, nearestTown.x, nearestTown.y)
    else
        -- No towns found, just explore
        AutoPlay.setCurrentAction(state, "Seeking civilization...")
        AutoPlay.moveRandomDirection(state)
    end
end

-- Find nearest town
function AutoPlay.findNearestTown(state)
    if not state.world or not state.world.towns or #state.world.towns == 0 then
        return nil
    end

    local playerX, playerY = getPlayerPosition(state)
    if not playerX then return nil end
    local nearestTown = nil
    local minDistance = math.huge

    for _, town in ipairs(state.world.towns) do
        if town.x and town.y then
            local distance = math.abs(town.x - playerX) + math.abs(town.y - playerY)
            if distance < minDistance then
                minDistance = distance
                nearestTown = town
            end
        end
    end

    return nearestTown
end

-- Find town by name (case-insensitive)
function AutoPlay.findTownByName(state, townName)
    if not state.world or not state.world.towns or not townName then
        return nil
    end

    local searchName = townName:lower()

    for _, town in ipairs(state.world.towns) do
        if town.name and town.name:lower() == searchName and town.x and town.y then
            return town
        end
    end

    return nil
end

-- Get tile at specific coordinates
function AutoPlay.getTileAt(state, x, y)
    if state.world.useWorldGen then
        -- Minor Issue Fix #30: Use cached WorldGen module
        if WorldGen and WorldGen.getTile then
            return WorldGen.getTile(x, y)
        end
    else
        -- Use legacy system
        if state.world.mapData[y] and state.world.mapData[y][x] then
            return state.world.mapData[y][x]
        end
    end
    return nil
end

-- Find nearby tile of specific type
function AutoPlay.findNearbyTileOfType(state, tileType, searchRadius)
    local playerX, playerY = getPlayerPosition(state)
    if not playerX then return nil end

    -- Search in expanding squares
    for radius = 1, searchRadius do
        for dy = -radius, radius do
            for dx = -radius, radius do
                -- Only check perimeter of current square
                if math.abs(dx) == radius or math.abs(dy) == radius then
                    local checkX = playerX + dx
                    local checkY = playerY + dy
                    local tile = AutoPlay.getTileAt(state, checkX, checkY)

                    if tile and tile.type == tileType then
                        return {x = checkX, y = checkY, tile = tile}
                    end
                end
            end
        end
    end

    return nil
end

-- Find nearest unexplored tile
function AutoPlay.findNearestUnexploredTile(state, searchRadius)
    local playerX, playerY = getPlayerPosition(state)
    if not playerX then return nil end

    -- Search in expanding squares
    for radius = 1, searchRadius do
        for dy = -radius, radius do
            for dx = -radius, radius do
                if math.abs(dx) == radius or math.abs(dy) == radius then
                    local checkX = playerX + dx
                    local checkY = playerY + dy
                    local tile = AutoPlay.getTileAt(state, checkX, checkY)

                    -- Check if tile is unexplored
                    if not tile or not tile.explored then
                        return {x = checkX, y = checkY}
                    end
                end
            end
        end
    end

    return nil
end

function AutoPlay.handleAutoNPCInteraction(state)
    -- NPC interaction phase - check for quest turn-ins
    AutoPlay.setCurrentAction(state, "Interacting with NPCs...")

    -- Check if we have completed quests to turn in
    local hasCompletedQuest = false
    if state.player.activeQuests then
        for i = #state.player.activeQuests, 1, -1 do
            local quest = state.player.activeQuests[i]
            if quest.completed then
                -- Turn in the quest
                log("✅ Auto-play: Turned in quest: " .. quest.name, {0.3, 0.9, 0.3})

                -- Critical Bug Fix #4 & #17: Nil-safe quest rewards
                local rewardGold = quest.rewardGold or 0
                local rewardXP = quest.rewardXP or 0
                log("💰 Reward: " .. rewardGold .. " gold, " .. rewardXP .. " XP", {1, 0.9, 0.3})

                -- Give rewards
                state.player.gold = state.player.gold + rewardGold

                -- Critical Bug Fix #40: Actually give XP rewards
                if rewardXP > 0 then
                    if F and F.gainXP then
                        F.gainXP(rewardXP)
                    elseif gainXP then
                        gainXP(rewardXP)
                    end
                end

                -- Track statistics
                state.autoPlay.stats.goldEarned = state.autoPlay.stats.goldEarned + rewardGold

                -- Remove from active quests
                table.remove(state.player.activeQuests, i)
                hasCompletedQuest = true
            end
        end
    end

    if hasCompletedQuest then
        log("🎉 Auto-play: All completed quests turned in!", {0.3, 0.9, 0.3})
    end

    -- Return to town
    state.phase = "town"
end

function AutoPlay.handleAutoJobBoard(state)
    -- Job board phase - accept a quest if available
    AutoPlay.setCurrentAction(state, "Checking job board...")

    local town = state.world.currentTown

    -- Critical Bug Fix #5: Check if jobBoard is a valid table
    if not town or not town.jobBoard or type(town.jobBoard) ~= "table" then
        log("⚠️ Auto-play: No job board in this town", {0.9, 0.6, 0.3})
        state.phase = "town"
        return
    end

    -- Accept the first available quest
    if #town.jobBoard > 0 then
        local quest = town.jobBoard[1]

        -- Critical Bug Fix #6: Initialize activeQuests if it doesn't exist
        state.player.activeQuests = state.player.activeQuests or {}

        -- Accept the quest
        table.insert(state.player.activeQuests, quest)
        quest.accepted = true
        table.remove(town.jobBoard, 1)

        log("📋 Auto-play: Accepted quest: " .. quest.name, {0.3, 0.9, 0.3})
        AutoPlay.setCurrentAction(state, "Accepted quest: " .. quest.name)

        -- Track statistics
        state.autoPlay.stats.actionsPerformed = state.autoPlay.stats.actionsPerformed + 1

        -- Return to town phase
        state.phase = "town"
    else
        log("📋 Auto-play: No quests available on job board", {0.9, 0.6, 0.3})
        state.phase = "town"
    end
end

function AutoPlay.handleAutoDialogue(state)
    -- Dialogue phase - end dialogue and return to town
    AutoPlay.setCurrentAction(state, "Ending conversation...")
    log("💬 Auto-play: Ending dialogue", {0.7, 0.7, 0.3})
    state.phase = "town"
end

function AutoPlay.handleAutoDungeon(state)
    -- Prison escape requires manual exploration
    if state.inPrisonEscape then
        AutoPlay.setCurrentAction(state, "Disabled in prison...")
        log("Auto-play disabled in prison - explore manually.", {0.9, 0.7, 0.3})
        AutoPlay.toggleAutoPlay(state)  -- Turn off auto-play
        return
    end

    -- Dungeon phase - exit dungeon for now (will be implemented in Phase 8)
    AutoPlay.setCurrentAction(state, "In dungeon (exiting for now)...")
    log("Auto-play: Exiting dungeon", {0.7, 0.7, 0.3})

    -- Exit dungeon
    if F and F.exitDungeon then
        F.exitDungeon()
    elseif exitDungeon then
        exitDungeon()
    else
        -- Fallback: return to map
        state.phase = "map"
        state.inDungeon = false
    end
end

function AutoPlay.returnToSafePhase(state)
    AutoPlay.setCurrentAction(state, "Returning to safe state...")
    state.phase = "map"
    state.inCombat = false
    state.inDungeon = false
    state.inShop = false
end

-- Set current action description
function AutoPlay.setCurrentAction(state, action)
    if not state or not state.autoPlay then return end
    state.autoPlay.currentAction = action

    -- Add to action log
    AutoPlay.logAction(state, action)
end

-- Log an action to the action history
function AutoPlay.logAction(state, action)
    if not state or not state.autoPlay then return end

    local timestamp = os.date("%H:%M:%S")
    table.insert(state.autoPlay.actionLog, {
        time = timestamp,
        action = action,
    })

    -- Keep only last 20 actions
    while #state.autoPlay.actionLog > 20 do
        table.remove(state.autoPlay.actionLog, 1)
    end
end

-- ============================================================================
-- UI RENDERING
-- ============================================================================

-- Draw auto-play status indicator (top-right corner)
function AutoPlay.drawStatus(state)
    if not state or not state.autoPlay then return end

    local ap = state.autoPlay
    if not ap.enabled then return end

    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- Status box position (top-right with padding)
    local boxW = 350
    local boxH = 80
    local boxX = screenW - boxW - 10
    local boxY = 10

    -- Draw background box
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 5, 5)

    -- Draw border
    if ap.isPaused then
        love.graphics.setColor(0.9, 0.6, 0.2, 1)  -- Orange for paused
    else
        love.graphics.setColor(0.3, 0.9, 0.3, 1)  -- Green for active
    end
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 5, 5)

    -- Get goal data
    local goalData = AutoPlay.GOALS[ap.goal]
    local goalName = goalData and goalData.name or ap.goal
    local goalIcon = goalData and goalData.icon or "🤖"

    -- Draw title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(getFont(14))
    local title = ap.isPaused and "⏸️ AUTO-PAUSED" or (goalIcon .. " AUTO: " .. goalName)
    love.graphics.print(title, boxX + 10, boxY + 10)

    -- Draw current action or pause reason
    love.graphics.setFont(getFont(12))
    love.graphics.setColor(0.9, 0.9, 0.9, 1)
    -- Store status box bounds for click-to-resume
    state.autoPlayStatusBounds = {x = boxX, y = boxY, w = boxW, h = boxH}

    if ap.isPaused and #ap.pauseReasons > 0 then
        love.graphics.print("Reason: " .. ap.pauseReasons[1], boxX + 10, boxY + 35)
        love.graphics.setColor(0.5, 0.9, 0.5, 1)
        love.graphics.print("Click here to resume", boxX + 10, boxY + 55)
    else
        local action = ap.currentAction or "Thinking..."
        love.graphics.print("📍 " .. action, boxX + 10, boxY + 35)

        -- Show retry status if stuck detection is active
        if ap.stuckTimer and ap.stuckTimer > 5 then
            local timeLeft = math.ceil((ap.maxStuckTime or 15) - ap.stuckTimer)
            love.graphics.setColor(0.9, 0.7, 0.3, 1)
            love.graphics.print("⏱️ Retry in " .. timeLeft .. "s (attempt #" .. (ap.retryAttempts or 0) .. ")", boxX + 10, boxY + 55)
        end

        -- Special display for testing mode
        if ap.goal == "testing" and ap.testData and ap.testData.checklist then
            local testProgress = string.format("%d/%d tests", ap.testData.currentTestIndex - 1, #ap.testData.checklist)
            love.graphics.print("🧪 " .. testProgress, boxX + 10, boxY + 55)
        else
            love.graphics.print("⏱️ Next action: " .. string.format("%.1fs", ap.actionDelay - ap.timer), boxX + 10, boxY + 55)
        end
    end
end

-- Draw goal selection context menu
function AutoPlay.drawGoalMenu(state)
    if not state or not state.autoPlay then return end

    local ap = state.autoPlay
    if not ap.showMenu then return end

    -- Menu dimensions
    local menuW = 250
    local menuItemH = 35
    local menuH = 60 + (#AutoPlay.GOAL_ORDER * menuItemH) + 50  -- Header + goals + disable button

    -- Center menu if position not set
    local menuX = ap.menuX or (love.graphics.getWidth() / 2 - menuW / 2)
    local menuY = ap.menuY or (love.graphics.getHeight() / 2 - menuH / 2)

    -- Clamp to screen bounds
    menuX = math.max(10, math.min(menuX, love.graphics.getWidth() - menuW - 10))
    menuY = math.max(10, math.min(menuY, love.graphics.getHeight() - menuH - 10))

    -- Draw background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.95)
    love.graphics.rectangle("fill", menuX, menuY, menuW, menuH, 5, 5)

    -- Draw border
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", menuX, menuY, menuW, menuH, 5, 5)

    -- Draw header
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(getFont(16))
    love.graphics.print("🤖 AUTO-PLAY GOALS", menuX + 15, menuY + 15)

    -- Draw separator
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.line(menuX + 10, menuY + 45, menuX + menuW - 10, menuY + 45)

    -- Draw goals
    local itemY = menuY + 60
    for _, goalId in ipairs(AutoPlay.GOAL_ORDER) do
        local goal = AutoPlay.GOALS[goalId]
        if goal then
            -- Check if this is the current goal
            local isSelected = (ap.goal == goalId)

            -- Highlight on hover or selection
            local mouseX, mouseY = love.mouse.getPosition()
            local isHovered = mouseX >= menuX and mouseX <= menuX + menuW and
                             mouseY >= itemY and mouseY <= itemY + menuItemH

            -- Draw background for hover/selection
            if isSelected then
                love.graphics.setColor(0.2, 0.5, 0.3, 0.6)
                love.graphics.rectangle("fill", menuX + 5, itemY, menuW - 10, menuItemH)
            elseif isHovered then
                love.graphics.setColor(0.3, 0.3, 0.4, 0.8)
                love.graphics.rectangle("fill", menuX + 5, itemY, menuW - 10, menuItemH)
            end

            -- Draw goal icon and name
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setFont(getFont(14))
            local checkmark = isSelected and "✓ " or "  "
            love.graphics.print(checkmark .. goal.icon .. " " .. goal.name, menuX + 15, itemY + 5)

            -- Draw description (smaller font)
            love.graphics.setColor(0.7, 0.7, 0.7, 1)
            love.graphics.setFont(getFont(11))
            love.graphics.print(goal.description, menuX + 40, itemY + 20)

            itemY = itemY + menuItemH
        end
    end

    -- Draw separator before disable button
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.line(menuX + 10, itemY + 5, menuX + menuW - 10, itemY + 5)
    itemY = itemY + 15

    -- Draw disable button
    local mouseX, mouseY = love.mouse.getPosition()
    local isHovered = mouseX >= menuX and mouseX <= menuX + menuW and
                     mouseY >= itemY and mouseY <= itemY + 30

    if isHovered then
        love.graphics.setColor(0.4, 0.2, 0.2, 0.8)
        love.graphics.rectangle("fill", menuX + 5, itemY, menuW - 10, 30)
    end

    love.graphics.setColor(1, 0.5, 0.5, 1)
    love.graphics.print("❌ Disable Auto-Play", menuX + 15, itemY + 6)
end

-- ============================================================================
-- MOUSE INPUT HANDLING
-- ============================================================================

-- Handle mouse clicks on goal menu
function AutoPlay.handleMenuClick(state, x, y, button)
    if not state or not state.autoPlay then return false end

    local ap = state.autoPlay
    if not ap.showMenu then return false end

    -- Menu dimensions (must match drawGoalMenu)
    local menuW = 250
    local menuItemH = 35
    local menuH = 60 + (#AutoPlay.GOAL_ORDER * menuItemH) + 50

    local menuX = ap.menuX or (love.graphics.getWidth() / 2 - menuW / 2)
    local menuY = ap.menuY or (love.graphics.getHeight() / 2 - menuH / 2)

    menuX = math.max(10, math.min(menuX, love.graphics.getWidth() - menuW - 10))
    menuY = math.max(10, math.min(menuY, love.graphics.getHeight() - menuH - 10))

    -- Check if click is outside menu (close menu)
    if x < menuX or x > menuX + menuW or y < menuY or y > menuY + menuH then
        ap.showMenu = false
        return true
    end

    -- Check goal items
    local itemY = menuY + 60
    for _, goalId in ipairs(AutoPlay.GOAL_ORDER) do
        if y >= itemY and y <= itemY + menuItemH then
            -- Goal clicked
            AutoPlay.setGoal(state, goalId)
            if not ap.enabled then
                ap.enabled = true
                ap.isPaused = false
                ap.pauseReasons = {}
                log("🤖 Auto-play enabled: " .. AutoPlay.GOALS[goalId].name, {0.3, 0.9, 0.3})
            end
            ap.showMenu = false
            return true
        end
        itemY = itemY + menuItemH
    end

    -- Check disable button
    itemY = itemY + 20  -- Account for separator
    if y >= itemY and y <= itemY + 30 then
        AutoPlay.stopAutoPlay(state, "Disabled via menu")
        ap.showMenu = false
        return true
    end

    return true  -- Click was inside menu, consume it
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Debug logging (only if debug mode enabled)
function AutoPlay.debugLog(message)
    if AutoPlay.config.debugMode then
        log("[AutoPlay] " .. message, {0.7, 0.7, 0.7})
    end
end

-- Get statistics summary for display
function AutoPlay.getStatsSummary(state)
    if not state or not state.autoPlay then return "" end

    local stats = state.autoPlay.stats
    local summary = string.format(
        "⚔️ Combats: %d | ✅ Quests: %d | 💰 Gold: %d | 🗺️ Tiles: %d | 🌲 Resources: %d",
        stats.combatsWon,
        stats.questsCompleted,
        stats.goldEarned,
        stats.tilesExplored,
        stats.resourcesGathered
    )
    return summary
end

-- ============================================================================
-- TESTING MODE - PUBLIC API
-- ============================================================================

-- Add a custom test to the checklist
function AutoPlay.addCustomTest(state, testName, testAction, testParams)
    if not state or not state.autoPlay or not state.autoPlay.testData then return end

    table.insert(state.autoPlay.testData.checklist, {
        name = testName,
        action = testAction,
        params = testParams or {}
    })

    log("🧪 Added custom test: " .. testName, {0.7, 0.7, 0.9})
end

-- Clear test results and reset testing
function AutoPlay.resetTesting(state)
    if not state or not state.autoPlay or not state.autoPlay.testData then return end

    state.autoPlay.testData.currentTestIndex = 1
    state.autoPlay.testData.results = {}
    state.autoPlay.testData.crashesDetected = 0

    log("🧪 Testing reset", {0.7, 0.7, 0.9})
end

-- Get test results
function AutoPlay.getTestResults(state)
    if not state or not state.autoPlay or not state.autoPlay.testData then return nil end
    return state.autoPlay.testData.results
end

return AutoPlay
