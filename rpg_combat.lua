-- RPG Combat System
-- Extracted from textrpg.lua
-- Contains: combat core functions, encounter generation, enemy creation,
-- damage resistance, skill availability, turn management, and combat flow.

local Backpack = require("backpack")
local MapEnemies = require("mapenemies")
local DungeonEnemies = require("dungeonenemies")
local PrisonEscape = require("prison_escape")
local WorldGen = require("worldgen")

local M = {}

-- Upvalues set by register()
local state
local F

-- Tactical combat references (set during register)
local TacticalCombat
local TacticalUI
local TacticalAI
local tacticalStateRef   -- function returning current tacticalState
local setTacticalState   -- function to set tacticalState

-- Data references (set during register from textrpg locals)
local ENEMIES
local SKILLS
local ENCOUNTER_TABLE
local DAMAGE_TYPES
local VAMPIRE_ENEMY_IDS
local UNDEAD_ENEMY_IDS
local SEA_ENEMIES
local WEATHER_EFFECTS
local TACTICAL_MODE

-- Module references (set during register)
local LuminaryPatrols
local AutoPlay

-- Forward-declared locals within this module
-- Local log helper (delegates to the shared log via F table)
local function log(text, color)
    if F and F.log then
        F.log(text, color)
    end
end
local onEnemyDefeated
local checkAllEnemiesDefeated
local endCombat
local advanceTurn
local startCombat
local generateEncounter
local createEnemyInstance
local graveyard

M.F_FUNCTIONS = {
    "playerAttack", "useSkill", "companionTurn", "companionAttackTarget",
    "companionDefend", "enemyTurn",
    "countExploredTiles", "generateEnemy", "applyDamageResistance",
    "getAvailableSkills", "getAvailableEnemiesForLevel", "getEncounterCount",
    "startCombat", "generateEncounter", "createEnemyInstance",
    "endCombat", "onEnemyDefeated", "advanceTurn",
    "checkAllEnemiesDefeated",
}

function M.register(s, f, deps)
    state = s
    F = f
    TacticalCombat = deps.TacticalCombat
    TacticalUI = deps.TacticalUI
    TacticalAI = deps.TacticalAI
    tacticalStateRef = deps.getTacticalState
    setTacticalState = deps.setTacticalState
    ENEMIES = deps.ENEMIES
    SKILLS = deps.SKILLS
    ENCOUNTER_TABLE = deps.ENCOUNTER_TABLE
    DAMAGE_TYPES = deps.DAMAGE_TYPES
    VAMPIRE_ENEMY_IDS = deps.VAMPIRE_ENEMY_IDS
    UNDEAD_ENEMY_IDS = deps.UNDEAD_ENEMY_IDS
    SEA_ENEMIES = deps.SEA_ENEMIES
    WEATHER_EFFECTS = deps.WEATHER_EFFECTS
    TACTICAL_MODE = deps.TACTICAL_MODE
    LuminaryPatrols = deps.LuminaryPatrols
    AutoPlay = deps.AutoPlay
    graveyard = deps.graveyard

    -- log is now a local function defined above that delegates to F.log

    for _, name in ipairs(M.F_FUNCTIONS) do
        if M[name] then
            F[name] = M[name]
        end
    end

    -- Also set up the module-local forward references so internal calls work
    onEnemyDefeated = M.onEnemyDefeated
    checkAllEnemiesDefeated = M.checkAllEnemiesDefeated
    endCombat = M.endCombat
    advanceTurn = M.advanceTurn
    startCombat = M.startCombat
    generateEncounter = M.generateEncounter
    createEnemyInstance = M.createEnemyInstance
end

-- ============================================================================
-- DAMAGE RESISTANCE
-- ============================================================================

M.applyDamageResistance = function(baseDamage, damageType, target)
    if not damageType or not target or not target.resistances then
        return baseDamage
    end

    local resistance = target.resistances[damageType] or 0
    -- Resistance: 0 = normal, 0.5 = 50% resist (take 50% damage), -0.5 = 50% weakness (take 150% damage)
    local multiplier = 1.0 - resistance
    local finalDamage = math.floor(baseDamage * multiplier)

    return math.max(1, finalDamage)  -- Minimum 1 damage
end

-- ============================================================================
-- SKILL AVAILABILITY
-- ============================================================================

M.getAvailableSkills = function()
    if not state.player then
        return {}
    end

    -- Use equipped skills if available (new system), otherwise use class skills (old system)
    local baseSkills = state.player.equippedSkills and #state.player.equippedSkills > 0
                       and state.player.equippedSkills
                       or state.player.skills or {}

    if not baseSkills or #baseSkills == 0 then
        return {}
    end

    local equippedWeapon = state.player.equipment and state.player.equipment.weapon
    local weaponType = equippedWeapon and equippedWeapon.weaponType or "melee"

    local availableSkills = {}
    for _, skillName in ipairs(baseSkills) do
        local skill = SKILLS[skillName]
        if skill then
            -- Include skill if it has no weapon requirement OR matches equipped weapon type
            if not skill.weaponType or skill.weaponType == weaponType then
                table.insert(availableSkills, skillName)
            end
        end
    end

    -- Add weapon-specific skills based on equipped weapon
    if weaponType == "bow" then
        -- Add basic bow skills if not already in list
        local bowSkills = {"Quick Shot", "Aimed Shot", "Multishot", "Piercing Arrow"}
        for _, skill in ipairs(bowSkills) do
            local found = false
            for _, existing in ipairs(availableSkills) do
                if existing == skill then found = true break end
            end
            if not found then
                table.insert(availableSkills, skill)
            end
        end
    elseif weaponType == "crossbow" then
        local crossbowSkills = {"Bolt Shot", "Explosive Bolt", "Sniper Shot"}
        for _, skill in ipairs(crossbowSkills) do
            local found = false
            for _, existing in ipairs(availableSkills) do
                if existing == skill then found = true break end
            end
            if not found then
                table.insert(availableSkills, skill)
            end
        end
    elseif weaponType == "thrown" then
        local thrownSkills = {"Fan of Blades", "Precision Throw"}
        for _, skill in ipairs(thrownSkills) do
            local found = false
            for _, existing in ipairs(availableSkills) do
                if existing == skill then found = true break end
            end
            if not found then
                table.insert(availableSkills, skill)
            end
        end
    elseif weaponType == "wand" then
        local wandSkills = {"Magic Missile", "Arcane Barrage", "Spell Burst"}
        for _, skill in ipairs(wandSkills) do
            local found = false
            for _, existing in ipairs(availableSkills) do
                if existing == skill then found = true break end
            end
            if not found then
                table.insert(availableSkills, skill)
            end
        end
    elseif weaponType == "melee" then
        -- Add basic melee skills
        local meleeSkills = {"Cleave", "Whirlwind", "Execute"}
        for _, skill in ipairs(meleeSkills) do
            local found = false
            for _, existing in ipairs(availableSkills) do
                if existing == skill then found = true break end
            end
            if not found then
                table.insert(availableSkills, skill)
            end
        end
    end

    return availableSkills
end

-- ============================================================================
-- ENCOUNTER TABLE LOOKUPS
-- ============================================================================

-- Get enemies available for a player level (based on CR they can handle)
M.getAvailableEnemiesForLevel = function(playerLevel)
    local available = {}
    local encounterData = ENCOUNTER_TABLE[math.min(20, playerLevel)] or ENCOUNTER_TABLE[20]

    for _, enemy in ipairs(ENEMIES) do
        if encounterData[enemy.cr] then
            table.insert(available, enemy)
        end
    end
    return available
end

-- Get encounter count based on player level and enemy CR
M.getEncounterCount = function(playerLevel, cr)
    local tableLevel = math.min(20, playerLevel)
    local encounterData = ENCOUNTER_TABLE[tableLevel] or ENCOUNTER_TABLE[20]
    local countRange = encounterData[cr]

    if not countRange then
        return 1  -- Default to 1 if CR not in table
    end

    local minCount = countRange[1]
    local maxCount = countRange[2]

    -- Scale encounter counts for levels beyond 20
    -- Every 10 levels above 20 adds ~25% more enemies
    if playerLevel > 20 then
        local scaleFactor = 1 + (playerLevel - 20) * 0.025  -- +2.5% per level above 20
        minCount = math.floor(minCount * scaleFactor)
        maxCount = math.floor(maxCount * scaleFactor)
        minCount = math.max(1, minCount)
    end

    return math.random(minCount, maxCount)
end

-- ============================================================================
-- ENEMY INSTANCE CREATION
-- ============================================================================

M.createEnemyInstance = function(enemyType, playerLevel)
    -- Enemy level scales with player but varies slightly
    local levelVariance = math.random(-1, 2)
    local level = math.max(1, playerLevel + levelVariance)

    -- Higher CR enemies get level bonus
    if enemyType.cr >= 4 then
        level = level + math.random(1, 3)
    elseif enemyType.cr >= 2 then
        level = level + math.random(0, 2)
    end

    local baseHP = 25 + level * 12
    local baseAtk = 4 + level * 3
    local baseDef = 2 + level * 2

    return {
        id = enemyType.id,
        type = enemyType,
        name = enemyType.name,
        portrait = enemyType.portrait,
        cr = enemyType.cr,
        level = level,
        maxHP = math.floor(baseHP * enemyType.hpMult),
        hp = math.floor(baseHP * enemyType.hpMult),
        attack = math.floor(baseAtk * enemyType.atkMult),
        defense = math.floor(baseDef * enemyType.defMult),
        xpReward = math.floor((15 + level * 8) * enemyType.xpMult),
        goldReward = math.floor((8 + level * 4) * enemyType.goldMult),
        attacks = enemyType.attacks,
    }
end

-- ============================================================================
-- ENCOUNTER GENERATION
-- ============================================================================

-- Generate a full encounter with potentially multiple enemies
-- Optional terrainType parameter for terrain-specific encounters
M.generateEncounter = function(playerLevel, terrainType)
    local enemies = {}

    -- Get available enemies for this player level
    local available = M.getAvailableEnemiesForLevel(playerLevel)
    if #available == 0 then
        -- Fallback to lowest tier
        available = {ENEMIES[1]}
    end

    -- Filter to undead only on corrupted terrain
    if terrainType and terrainType.undeadOnly then
        local undeadAvailable = {}
        for _, enemy in ipairs(available) do
            for _, undeadId in ipairs(UNDEAD_ENEMY_IDS) do
                if enemy.id == undeadId then
                    table.insert(undeadAvailable, enemy)
                    break
                end
            end
        end
        -- Use undead if available, otherwise fallback to regular enemies
        if #undeadAvailable > 0 then
            available = undeadAvailable
        end
    end

    -- Filter to sea enemies on water terrain
    if terrainType and terrainType.seaOnly then
        local seaTier = "coastal"
        if terrainType.id == "deep_ocean" or terrainType.id == "whirlpool" then
            seaTier = "deep"
        elseif terrainType.id == "shallow_water" or terrainType.id == "reef" or terrainType.id == "shipwreck" then
            seaTier = "shallow"
        end
        local seaAvailable = SEA_ENEMIES[seaTier] or SEA_ENEMIES.coastal
        -- Filter by player level using CR
        local levelFiltered = {}
        for _, e in ipairs(seaAvailable) do
            if playerLevel >= math.max(1, math.floor(e.cr * 2 - 2)) then
                table.insert(levelFiltered, e)
            end
        end
        if #levelFiltered > 0 then
            available = levelFiltered
        else
            available = seaAvailable  -- Fallback to all sea enemies for tier
        end
        -- Rare chance of boss encounter in deep ocean at high levels
        if seaTier == "deep" and playerLevel >= 12 and math.random() < 0.05 then
            local bossPool = SEA_ENEMIES.boss
            local bossFiltered = {}
            for _, e in ipairs(bossPool) do
                if playerLevel >= math.floor(e.cr * 1.5) then
                    table.insert(bossFiltered, e)
                end
            end
            if #bossFiltered > 0 then
                available = bossFiltered
            end
        end
    end

    -- Pick a random enemy type
    local enemyType = available[math.random(#available)]

    -- Determine how many of this enemy based on CR and player level
    local count = M.getEncounterCount(playerLevel, enemyType.cr)

    -- Cap enemies per encounter - scales with level
    -- Lv1-4: 4-5, Lv5-19: 8, Lv20-39: 10, Lv40-59: 12, Lv60-79: 14, Lv80+: 16
    local maxEnemies
    if playerLevel <= 2 then
        maxEnemies = 4
    elseif playerLevel <= 4 then
        maxEnemies = 5
    elseif playerLevel <= 19 then
        maxEnemies = 8
    else
        maxEnemies = math.min(16, 8 + math.floor((playerLevel - 20) / 20) * 2 + 2)
    end
    count = math.min(count, maxEnemies)

    -- Create the enemy instances
    for i = 1, count do
        local enemy = M.createEnemyInstance(enemyType, playerLevel)
        table.insert(enemies, enemy)
    end

    -- Occasionally mix in different enemy types for variety (25% chance)
    if count > 2 and math.random() < 0.25 then
        -- Replace some enemies with a different type of similar CR
        local similarCR = {}
        for _, e in ipairs(available) do
            if math.abs(e.cr - enemyType.cr) <= 0.5 and e.id ~= enemyType.id then
                table.insert(similarCR, e)
            end
        end

        if #similarCR > 0 then
            local altType = similarCR[math.random(#similarCR)]
            local replaceCount = math.floor(count / 3)
            for i = 1, replaceCount do
                enemies[i] = M.createEnemyInstance(altType, playerLevel)
            end
        end
    end

    return enemies
end

-- Legacy function for backwards compatibility
M.generateEnemy = function(playerLevel)
    local enemies = M.generateEncounter(playerLevel)
    return enemies[1]
end

-- ============================================================================
-- COMBAT INITIALIZATION (startCombat)
-- ============================================================================

M.startCombat = function(enemies)
    local tacticalState = tacticalStateRef()

    -- Track if player was sneaking when combat started (for combat advantage)
    local wasStealthed = state.player and state.player.stealthMode

    -- Handle both single enemy (legacy) and array of enemies
    local enemyList = enemies
    if enemies.name then
        -- Single enemy passed (legacy compatibility)
        enemyList = {enemies}
    end

    -- ================================================================
    -- TACTICAL MODE: Initialize grid-based tactical combat
    -- ================================================================
    if TACTICAL_MODE and TacticalCombat then
        -- Prevent re-initialization if combat is already active
        if tacticalState and not tacticalState.combatEnded then
            return  -- Combat already active, don't reinitialize
        end

        -- Save previous phase before overwriting
        local previousPhase = state.phase
        state.phase = "tactical_combat"

        -- Determine encounter type based on context
        local encounterType = "open"

        -- Priority 1: Check if in specific location phase
        if previousPhase == "town" or previousPhase == "tavern" or previousPhase == "shop" then
            encounterType = "town"
        elseif previousPhase == "lockpicking" or previousPhase == "burglary_success" then
            encounterType = "building_interior"
        elseif state.inPrisonEscape or (state.dungeon and state.dungeon.isPrison) then
            encounterType = "city"  -- Prison uses stone floor terrain
        elseif previousPhase == "dungeon" or state.inDungeon then
            -- Check dungeon type for more specific theming
            if state.currentDungeon then
                local dungeonId = state.currentDungeon.id or ""
                if dungeonId:find("crypt") or dungeonId:find("tomb") or dungeonId:find("vampire") then
                    encounterType = "dungeon"  -- Dark stone dungeon
                elseif dungeonId:find("mine") then
                    encounterType = "mountain"  -- Rocky mine
                elseif dungeonId:find("cave") then
                    encounterType = "dungeon"  -- Cave-like
                elseif dungeonId:find("temple") or dungeonId:find("ruins") then
                    encounterType = "ruins"
                elseif dungeonId:find("ship") or dungeonId:find("pirate") then
                    encounterType = "ship"
                else
                    encounterType = "dungeon"
                end
            else
                encounterType = "dungeon"
            end
        -- Priority 2: Check world biome
        elseif state.world and state.world.currentBiome then
            local biome = state.world.currentBiome
            if biome == "forest" or biome == "deep_forest" then
                encounterType = "forest"
            elseif biome == "swamp" then
                encounterType = "swamp"
            elseif biome == "desert" then
                encounterType = "desert"
            elseif biome == "ice" or biome == "snow" then
                encounterType = "arctic"
            elseif biome == "mountain" then
                encounterType = "mountain"
            elseif biome == "grass" or biome == "plains" then
                encounterType = "plains"
            elseif biome == "deep_ocean" or biome == "shallow_water" then
                encounterType = "ship"
            elseif biome == "ruins" then
                encounterType = "ruins"
            elseif biome == "town" then
                encounterType = "town"
            else
                encounterType = "open"
            end
        -- Priority 3: Check current tile terrain if available
        elseif state.world and state.world.player then
            local px, py = state.world.player.x, state.world.player.y
            local tile = state.world.map[py] and state.world.map[py][px]
            if tile then
                local terrain = tile.terrain or "grass"
                if terrain == "forest" or terrain == "deep_forest" then
                    encounterType = "forest"
                elseif terrain == "swamp" then
                    encounterType = "swamp"
                elseif terrain == "desert" then
                    encounterType = "desert"
                elseif terrain == "mountain" then
                    encounterType = "mountain"
                elseif terrain == "ice" or terrain == "snow" then
                    encounterType = "arctic"
                elseif terrain == "deep_ocean" or terrain == "shallow_water" then
                    encounterType = "ship"
                elseif terrain == "town" then
                    encounterType = "town"
                elseif terrain == "ruins" then
                    encounterType = "ruins"
                else
                    encounterType = "plains"
                end
            end
        end

        -- Initialize tactical combat state
        local newTacticalState = TacticalCombat.initCombat(state.player, enemyList, encounterType)
        newTacticalState._SKILLS = SKILLS  -- Pass skills reference for UI
        setTacticalState(newTacticalState)

        -- Now disable exploration stealth mode (combat uses Hide action instead)
        -- The initCombat above already checked stealthMode for the "enter from shadows" hidden bonus
        if wasStealthed then
            state.player.stealthMode = false
            log("Stealth Mode disabled. Use [H] Hide for combat stealth.", {0.7, 0.7, 0.9})
        end

        -- Also keep a reference to original enemy list in state.combat for quest/reward tracking
        state.combat = {
            enemies = enemyList,
            isTactical = true,
            selectedTarget = 1,
            turnOrder = {},
            currentTurnIndex = 0,
            isPlayerTurn = false,
            isCompanionTurn = false,
            currentCompanionIndex = nil,
            log = {},
            showSkills = false,
        showWeaponSwap = false,
            currentActorIndex = nil,
            secondWindUsed = false,
        }

        -- Log the encounter
        local totalCount = #enemyList
        if totalCount > 1 then
            TacticalCombat.addLog(newTacticalState, totalCount .. " enemies approach!", {0.9, 0.2, 0.2})
            for _, enemy in ipairs(enemyList) do
                TacticalCombat.addLog(newTacticalState, "  - " .. enemy.name .. " (Lv." .. (enemy.level or 1) .. ")", {0.9, 0.4, 0.4})
            end
        else
            TacticalCombat.addLog(newTacticalState, "A " .. enemyList[1].name .. " (Lv." .. (enemyList[1].level or 1) .. ") appears!", {0.9, 0.3, 0.3})
        end

        -- Log party
        if state.player.party and #state.player.party > 0 then
            TacticalCombat.addLog(newTacticalState, "Your party joins the fight!", {0.3, 0.7, 0.9})
        end

        TacticalCombat.addLog(newTacticalState, "Tactical combat begins!", {0.9, 0.9, 0.3})
        TacticalCombat.addLog(newTacticalState, "[M]ove [A]ttack [S]kill [I]tem [R]un [W]ait/End Turn", {0.6, 0.6, 0.7})

        -- Start first turn
        local firstUnit = TacticalCombat.advanceTurn(newTacticalState)
        if firstUnit then
            TacticalCombat.addLog(newTacticalState, firstUnit.name .. "'s turn!", firstUnit.color or {0.8, 0.8, 0.8})
        end

        return  -- Don't execute classic combat setup
    end

    -- ================================================================
    -- CLASSIC MODE: Original turn-based combat (unchanged below)
    -- ================================================================
    -- Disable exploration stealth in classic combat too
    if wasStealthed then
        state.player.stealthMode = false
        log("Stealth Mode disabled for combat.", {0.7, 0.7, 0.9})
    end
    state.phase = "combat"
    state.combat = {
        enemies = enemyList,
        selectedTarget = 1,
        turnOrder = {},
        currentTurnIndex = 0,
        isPlayerTurn = false,
        isCompanionTurn = false,
        currentCompanionIndex = nil,  -- Index of companion whose turn it is
        log = {},
        showSkills = false,
        showWeaponSwap = false,
        currentActorIndex = nil,  -- Index of enemy whose turn it is (nil for player)
        secondWindUsed = false,  -- For Second Wind talent (resets each combat)
        phaseUsed = false,  -- For Wraith phase-through-first-attack (resets each combat)
        killingBlowSurvived = false,  -- For Catfolk/Revenant survive killing blow (resets each combat)
        trapSenseUsed = false,  -- For Ruin Scavenger trap_sense passive (resets each combat)
    }

    -- Roll initiative for all combatants
    -- Player initiative: roll 1-20 + level/2
    local playerInit = math.random(1, 20) + math.floor((state.player.level or 1) / 2)
    local initiatives = {{type = "player", init = playerInit}}

    -- Companion initiatives: roll 1-20 + level/3
    if state.player.party then
        for i, companion in ipairs(state.player.party) do
            if (companion.hp or 0) > 0 then
                local compInit = math.random(1, 20) + math.floor((companion.level or 1) / 3)
                table.insert(initiatives, {type = "companion", index = i, init = compInit})
            end
        end
    end

    -- Enemy initiatives: roll 1-20 + CR
    for i, enemy in ipairs(enemyList) do
        local enemyInit = math.random(1, 20) + math.floor(enemy.cr or 1)
        table.insert(initiatives, {type = "enemy", index = i, init = enemyInit})
    end

    -- Sort by initiative (highest first)
    table.sort(initiatives, function(a, b) return a.init > b.init end)

    -- Build turn order
    state.combat.turnOrder = initiatives

    -- Log the encounter
    local totalCount = #enemyList
    if totalCount > 1 then
        log(totalCount .. " enemies approach!", {0.9, 0.2, 0.2})
        for _, enemy in ipairs(enemyList) do
            local enemyLevel = enemy.level or 1
            log("  - " .. enemy.name .. " (Lv." .. enemyLevel .. ")", {0.9, 0.4, 0.4})
        end
    else
        local enemyLevel = enemyList[1].level or 1
        log("A " .. enemyList[1].name .. " (Lv." .. enemyLevel .. ") appears!", {0.9, 0.3, 0.3})
    end

    -- Generate rumors for notable monster encounters (werewolves, etc.)
    local notableMonsters = {
        werewolf = true, dire_wolf = true, alpha_wolf = true,
        vampire = true, vampire_spawn = true, vampire_lord = true,
        ghost = true, specter = true, wraith = true, banshee = true,
        troll = true, ogre = true, giant = true,
    }
    for _, enemy in ipairs(enemyList) do
        local enemyId = enemy.id or enemy.name:lower():gsub(" ", "_")
        if notableMonsters[enemyId] then
            local RumorSystem = require("rumorsystem")
            RumorSystem.init(state)
            local px, py = state.world.playerX or 0, state.world.playerY or 0

            -- Determine rumor type based on enemy
            if enemyId:find("wolf") or enemyId:find("werewolf") then
                RumorSystem.onWerewolfSighting(px, py, "the wilderness", nil)
            elseif enemyId:find("vampire") then
                RumorSystem.onVampireSighting(px, py, "a dark place", nil)
            elseif enemyId:find("ghost") or enemyId:find("specter") or enemyId:find("wraith") or enemyId:find("banshee") then
                RumorSystem.onGhostSighting(px, py, "the wilds", nil)
            else
                -- Generic monster sighting
                RumorSystem.createRumorFromEvent(RumorSystem.TYPES.MONSTER_SIGHTING, {
                    x = px, y = py,
                    locationName = "the wilderness",
                    monster = enemy.name,
                })
            end
            break  -- Only one rumor per encounter
        end
    end

    -- Log party members
    if state.player.party and #state.player.party > 0 then
        log("Your party joins the fight!", {0.3, 0.7, 0.9})
        for _, companion in ipairs(state.player.party) do
            if companion.hp > 0 then
                log("  - " .. companion.name .. " the " .. companion.class.name, companion.color)
            end
        end
    end

    -- Log initiative order
    log("Initiative rolled!", {0.7, 0.7, 0.9})

    -- Start first turn
    advanceTurn()
end

-- ============================================================================
-- TURN MANAGEMENT (advanceTurn)
-- ============================================================================

-- Advance to the next turn in initiative order
M.advanceTurn = function()
    -- Find next valid turn (skip dead enemies and companions)
    local startIndex = state.combat.currentTurnIndex + 1
    local orderLen = #state.combat.turnOrder

    for i = 1, orderLen do
        local idx = ((startIndex - 1 + i - 1) % orderLen) + 1
        local turn = state.combat.turnOrder[idx]

        if turn.type == "player" then
            state.combat.currentTurnIndex = idx
            state.combat.isPlayerTurn = true
            state.combat.isCompanionTurn = false
            state.combat.currentActorIndex = nil
            state.combat.currentCompanionIndex = nil

            -- Regenerate stamina each turn (20 stamina per turn)
            if not state.player.stamina then state.player.stamina = 100 end
            if not state.player.maxStamina then state.player.maxStamina = 100 end
            state.player.stamina = math.min(state.player.maxStamina, state.player.stamina + 20)

            -- Racial HP regen per turn (e.g., Lizardfolk)
            local charBonus = state.player.characterBonuses
            if charBonus and charBonus.hpRegenPercent > 0 then
                local regenAmount = math.floor(state.player.maxHP * charBonus.hpRegenPercent / 100)
                if regenAmount > 0 and state.player.hp < state.player.maxHP then
                    state.player.hp = math.min(state.player.maxHP, state.player.hp + regenAmount)
                    log("Regenerated " .. regenAmount .. " HP", {0.3, 0.8, 0.5})
                end
            end

            -- Passive: survivors_will (HP regen when low HP)
            if charBonus and charBonus.lowHPRegenPercent > 0 and state.player.hp < state.player.maxHP * 0.25 then
                local regenAmount = math.floor(state.player.maxHP * charBonus.lowHPRegenPercent / 100)
                if regenAmount > 0 and state.player.hp < state.player.maxHP then
                    state.player.hp = math.min(state.player.maxHP, state.player.hp + regenAmount)
                    log("Survivor's Will: +" .. regenAmount .. " HP", {0.5, 0.9, 0.4})
                end
            end

            log("Your turn!", {0.3, 0.9, 0.3})
            return
        elseif turn.type == "companion" then
            local companion = state.player.party[turn.index]
            if companion and companion.hp > 0 then
                state.combat.currentTurnIndex = idx
                state.combat.isPlayerTurn = false
                state.combat.isCompanionTurn = true
                state.combat.currentActorIndex = nil
                state.combat.currentCompanionIndex = turn.index
                return
            end
        elseif turn.type == "enemy" then
            local enemy = state.combat.enemies[turn.index]
            if enemy and enemy.hp > 0 then
                state.combat.currentTurnIndex = idx
                state.combat.isPlayerTurn = false
                state.combat.isCompanionTurn = false
                state.combat.currentActorIndex = turn.index
                state.combat.currentCompanionIndex = nil
                return
            end
        end
    end
end

-- ============================================================================
-- PLAYER ATTACK
-- ============================================================================

M.playerAttack = function()
    local targetIdx = state.combat.selectedTarget
    local target = state.combat.enemies[targetIdx]

    if not target or target.hp <= 0 then
        log("Invalid target!", {0.8, 0.3, 0.3})
        return
    end

    -- Get pet battle bonus from backpack
    local petBonus = Backpack.getPetBattleBonus()

    -- Calculate base damage with stat bonuses
    local p = state.player
    local baseDamage = p.attack + petBonus - target.defense + math.random(-3, 3)

    -- Check for critical hit
    local charBonus = p.characterBonuses
    local critChance = p.critChance or 5
    -- Passive: desperate_luck (+crit when low HP)
    if charBonus and charBonus.lowHPCritBonus > 0 and p.hp < p.maxHP * 0.25 then
        critChance = critChance + charBonus.lowHPCritBonus
    end
    -- Passive: undead_slayer (+crit vs undead)
    if charBonus and charBonus.undeadCritBonus > 0 and target.isUndead then
        critChance = critChance + charBonus.undeadCritBonus
    end
    local isCrit = math.random(100) <= critChance
    local critMult = p.critDamage or 1.5
    -- Passive: stake_mastery (override crit mult vs undead)
    if isCrit and charBonus and charBonus.undeadCritMultOverride > 0 and target.isUndead then
        critMult = charBonus.undeadCritMultOverride
    end

    -- Apply crit multiplier
    local damage = math.max(1, baseDamage)
    if isCrit then
        damage = math.floor(damage * critMult)
        -- Apply "deadly" talent bonus
        if p.talents and p.talents.deadly then
            damage = math.floor(damage * 1.25)
        end
    end

    -- Apply racial/background melee damage bonus
    if charBonus then
        damage = math.floor(damage * charBonus.meleeDamageMult)
        -- Passive: brawler (+damage when unarmed)
        if charBonus.unarmedDamageMult > 1 and (not p.equipment or not p.equipment.weapon) then
            damage = math.floor(damage * charBonus.unarmedDamageMult)
        end
        -- Low HP bonus (e.g., Orc Savage Fury)
        if charBonus.lowHPDamageMult > 1 and p.hp < p.maxHP * 0.3 then
            damage = math.floor(damage * charBonus.lowHPDamageMult)
        end
        -- Undead damage bonus
        if charBonus.undeadDamageMult > 1 and target.isUndead then
            damage = math.floor(damage * charBonus.undeadDamageMult)
        end
    end

    target.hp = target.hp - damage

    -- Build damage message
    local msg = "You hit " .. target.name .. " for " .. damage .. " damage"
    if isCrit then
        msg = "CRITICAL HIT! " .. msg
    end
    if petBonus > 0 then
        local pet = Backpack.getEquippedPet()
        local petName = pet and pet.name or "companion"
        msg = msg .. " (" .. petName .. " helped)"
    end
    msg = msg .. "!"

    local color = isCrit and {1, 0.8, 0.2} or {0.9, 0.6, 0.3}
    log(msg, color)

    if target.hp <= 0 then
        onEnemyDefeated(target)
    end

    -- Check if all enemies defeated
    if checkAllEnemiesDefeated() then
        endCombat(true)
    else
        state.combat.showSkills = false
        advanceTurn()
    end
end

-- ============================================================================
-- ON ENEMY DEFEATED
-- ============================================================================

-- Called when an enemy is defeated
M.onEnemyDefeated = function(enemy)
    local enemyName = enemy.name or "Enemy"
    local enemyXP = enemy.xpReward or 0
    local enemyGold = enemy.goldReward or 0

    -- Apply racial/background gold bonus
    local charBonus = state.player.characterBonuses
    if charBonus then
        if charBonus.goldMult > 1 then
            enemyGold = math.floor(enemyGold * charBonus.goldMult)
        end
        enemyGold = enemyGold + (charBonus.extraGoldPerKill or 0)
        -- Passive: scam_artist (chance for double gold)
        if (charBonus.doubleGoldChance or 0) > 0 and math.random(100) <= charBonus.doubleGoldChance then
            enemyGold = enemyGold * 2
            log("Scam Artist: Double gold!", {1, 0.9, 0.3})
        end
    end

    log("Defeated " .. enemyName .. "!", {0.3, 0.9, 0.3})
    F.gainXP(enemyXP)
    state.player.gold = (state.player.gold or 0) + enemyGold
    log("+" .. enemyGold .. " gold", {1, 0.9, 0.3})
    state.stats.enemiesDefeated = (state.stats.enemiesDefeated or 0) + 1
    F.addJournalEvent("combat", "Defeated " .. enemyName .. " (Lv." .. (enemy.level or "?") .. ") +" .. enemyXP .. "xp +" .. enemyGold .. "g", {0.3, 0.9, 0.3})
    if state.player.journal and state.player.journal.actionStats then
        if state.player.journal.actionStats.combat then
            state.player.journal.actionStats.combat.enemiesDefeated = (state.player.journal.actionStats.combat.enemiesDefeated or 0) + 1
            state.player.journal.actionStats.combat.damageDealt = (state.player.journal.actionStats.combat.damageDealt or 0) + (enemy.maxHP or 0)
        end
        if state.player.journal.actionStats.economy then
            state.player.journal.actionStats.economy.goldEarned = (state.player.journal.actionStats.economy.goldEarned or 0) + enemyGold
        end
    end
    state.stats.goldEarned = (state.stats.goldEarned or 0) + enemyGold

    -- Racial heal on kill (e.g., Orc)
    if charBonus and charBonus.healOnKillPercent > 0 then
        local healAmount = math.floor(state.player.maxHP * charBonus.healOnKillPercent / 100)
        state.player.hp = math.min(state.player.maxHP, state.player.hp + healAmount)
        log("Healed " .. healAmount .. " HP on kill!", {0.3, 0.9, 0.5})
    end

    -- Check for dragon defeat achievement
    if enemy.type and enemy.type.id and enemy.type.id:match("dragon") then
        if not PlayerData.achievements then PlayerData.achievements = {} end
        if not PlayerData.achievements.defeat_dragon then
            PlayerData.achievements.defeat_dragon = true
            log("ACHIEVEMENT UNLOCKED: Dragon Slayer!", {1, 0.8, 0.2})
        end
    end

    -- Check quest progress for kill quests
    local enemyTypeId = enemy.type and enemy.type.id or nil
    for _, quest in ipairs(state.player.activeQuests or {}) do
        if quest.type == "kill" and enemyTypeId and quest.enemyId == enemyTypeId and not quest.completed then
            quest.progress = (quest.progress or 0) + 1
            log("Quest progress: " .. quest.progress .. "/" .. quest.target, {0.9, 0.7, 0.2})
            if quest.progress >= quest.target then
                quest.completed = true
                log("Quest complete: " .. quest.name .. "!", {0.3, 0.9, 0.3})
                F.addJournalEvent("quest", "Completed: " .. quest.name, {0.3, 0.9, 0.3})
                if state.player.journal and state.player.journal.actionStats and state.player.journal.actionStats.social then
                    state.player.journal.actionStats.social.questsCompleted = (state.player.journal.actionStats.social.questsCompleted or 0) + 1
                end
            end
        end
    end

    -- Random item drop
    local dropChance = #state.combat.enemies > 1 and 0.15 or 0.25
    -- Apply racial/background loot bonus
    if charBonus and charBonus.extraLootChance > 0 then
        dropChance = dropChance + (charBonus.extraLootChance / 100)
    end
    if math.random() < dropChance then
        local dropTable = {
            "tq_health_potion", "tq_mana_potion", "tq_elixir",
            "tq_rusty_sword", "tq_iron_sword", "tq_steel_sword",
            "tq_cloth_armor", "tq_leather_armor", "tq_chain_mail",
            "tq_healing_herbs", "tq_wolf_pelts", "tq_spider_silk",
            "tq_iron_ore", "tq_magic_crystal", "tq_skeleton_bone", "tq_goblin_ears"
        }
        local itemId = dropTable[math.random(#dropTable)]
        local itemDef = Backpack.getItemDef(itemId)
        if itemDef then
            Backpack.addItem(itemId, 1)
            log("Found: " .. itemDef.name, {0.8, 0.5, 0.9})
            F.addJournalEvent("loot", "Found " .. itemDef.name, {0.8, 0.5, 0.9})
            state.stats.itemsFound = state.stats.itemsFound + 1
        end
    end

    -- Check for fetch quest items
    for _, quest in ipairs(state.player.activeQuests or {}) do
        if quest.type == "fetch" and not quest.completed then
            if math.random() < 0.3 then
                quest.progress = quest.progress + 1
                log("Found " .. quest.itemName .. "! (" .. quest.progress .. "/" .. quest.target .. ")", {0.8, 0.7, 0.3})
                if quest.progress >= quest.target then
                    quest.completed = true
                    log("Quest complete: " .. quest.name .. "!", {0.3, 0.9, 0.3})
                end
            end
        end
    end

    -- Auto-select next living enemy
    for i, e in ipairs(state.combat.enemies) do
        if e.hp > 0 then
            state.combat.selectedTarget = i
            break
        end
    end
end

-- ============================================================================
-- CHECK ALL ENEMIES DEFEATED
-- ============================================================================

-- Check if all enemies are defeated
M.checkAllEnemiesDefeated = function()
    for _, enemy in ipairs(state.combat.enemies) do
        if enemy.hp > 0 then
            return false
        end
    end
    return true
end

-- ============================================================================
-- TACTICAL DOT DEATHS (local helper)
-- ============================================================================

-- Process DOT/hazard deaths that occurred during advanceTurn's start-of-turn effects.
-- Returns true if combat ended (all enemies defeated or player died), false otherwise.
local function processTacticalDotDeaths(tState)
    if not tState or not tState._dotDeaths then return false end
    local deaths = tState._dotDeaths
    tState._dotDeaths = nil
    for _, death in ipairs(deaths) do
        local unit = death.unit
        if unit.isEnemy and unit.data then
            onEnemyDefeated(unit.data)
        end
        if unit.isPlayer then
            TacticalCombat.syncToGameState(tState, state.player)
            tState.combatEnded = true
            tState.victory = false
            endCombat(false)
            return true
        end
    end
    if TacticalCombat.checkAllEnemiesDefeated(tState) then
        TacticalCombat.syncToGameState(tState, state.player)
        tState.combatEnded = true
        tState.victory = true
        endCombat(true)
        return true
    end
    return false
end

-- Expose processTacticalDotDeaths on M for external access if needed
M.processTacticalDotDeaths = processTacticalDotDeaths

-- ============================================================================
-- USE SKILL
-- ============================================================================

M.useSkill = function(skillName)
    local skill = SKILLS[skillName]
    if not skill then return end

    -- Calculate actual mana cost with racial/background bonuses
    local actualManaCost = skill.manaCost
    if actualManaCost then
        local charBonus = state.player.characterBonuses
        if charBonus then
            -- Free spell chance (e.g., Gnome)
            if charBonus.freeSpellChance > 0 and math.random(100) <= charBonus.freeSpellChance then
                actualManaCost = 0
                log("Free cast! (Racial bonus)", {0.5, 0.8, 1})
            else
                actualManaCost = math.floor(actualManaCost * charBonus.manaCostMult)
            end
        end
    end

    -- Check resource costs
    if actualManaCost and actualManaCost > 0 and state.player.mana < actualManaCost then
        log("Not enough mana!", {0.8, 0.3, 0.3})
        return
    end

    if skill.staminaCost then
        local currentStamina = state.player.stamina or 100
        if currentStamina < skill.staminaCost then
            log("Not enough stamina!", {0.8, 0.5, 0.3})
            return
        end
    end

    if skill.hpCost and state.player.hp <= skill.hpCost then
        log("Not enough HP! (Would kill you)", {0.9, 0.3, 0.3})
        return
    end

    -- Deduct resource costs
    if actualManaCost and actualManaCost > 0 then
        state.player.mana = state.player.mana - actualManaCost
    end

    if skill.staminaCost then
        state.player.stamina = (state.player.stamina or 100) - skill.staminaCost
    end

    if skill.hpCost then
        state.player.hp = state.player.hp - skill.hpCost
        log("Sacrificed " .. skill.hpCost .. " HP!", {0.9, 0.4, 0.4})
    end

    -- Get pet battle bonus from backpack
    local petBonus = Backpack.getPetBattleBonus()

    if skill.damage then
        local targetIdx = state.combat.selectedTarget
        local target = state.combat.enemies[targetIdx]
        if target and target.hp > 0 then
            local baseDamage = skill.damage + math.floor(state.player.attack * 0.5) + petBonus

            -- Apply racial/background magic damage bonus
            local charBonus = state.player.characterBonuses
            if charBonus then
                if skill.damageType and skill.damageType ~= "physical" then
                    baseDamage = math.floor(baseDamage * charBonus.magicDamageMult)
                end
                -- Apply melee damage bonus for physical skills
                if skill.damageType == "physical" then
                    baseDamage = math.floor(baseDamage * charBonus.meleeDamageMult)
                end
                -- Low HP bonus
                if charBonus.lowHPDamageMult > 1 and state.player.hp < state.player.maxHP * 0.3 then
                    baseDamage = math.floor(baseDamage * charBonus.lowHPDamageMult)
                end
                -- Undead bonus
                if charBonus.undeadDamageMult > 1 and target.isUndead then
                    baseDamage = math.floor(baseDamage * charBonus.undeadDamageMult)
                end
            end

            -- Apply damage type resistance
            local damage = M.applyDamageResistance(baseDamage, skill.damageType, target)

            target.hp = target.hp - damage

            -- Show damage type in log
            local damageTypeText = skill.damageType and (" (" .. (DAMAGE_TYPES[skill.damageType] and DAMAGE_TYPES[skill.damageType].name or skill.damageType) .. ")") or ""
            local resistanceText = ""
            if target.resistances and skill.damageType then
                local resist = target.resistances[skill.damageType] or 0
                if resist > 0.3 then
                    resistanceText = " [RESISTED!]"
                elseif resist < -0.3 then
                    resistanceText = " [CRITICAL!]"
                end
            end

            log("You use " .. skillName .. " on " .. target.name .. " for " .. damage .. " damage!" .. damageTypeText .. resistanceText, {0.5, 0.8, 1})

            if target.hp <= 0 then
                onEnemyDefeated(target)
            end
        end
    end

    if skill.heal then
        local healAmount = skill.heal
        local charBonus = state.player.characterBonuses
        if charBonus then
            healAmount = math.floor(healAmount * charBonus.healingDoneMult)
        end
        state.player.hp = math.min(state.player.maxHP, state.player.hp + healAmount)
        log("You heal for " .. healAmount .. " HP!", {0.3, 0.9, 0.3})
    end

    -- Check if all enemies defeated
    if checkAllEnemiesDefeated() then
        endCombat(true)
    else
        state.combat.showSkills = false
        advanceTurn()
    end
end

-- ============================================================================
-- COMPANION TURN
-- ============================================================================

-- Companion AI turn - attacks enemies or heals allies
M.companionTurn = function()
    local compIdx = state.combat.currentCompanionIndex
    if not compIdx then
        advanceTurn()
        return
    end

    local companion = state.player.party[compIdx]
    if not companion or companion.hp <= 0 then
        advanceTurn()
        return
    end

    -- Find a valid enemy target (first alive enemy)
    local targetEnemy = nil
    local targetIdx = nil
    for i, enemy in ipairs(state.combat.enemies) do
        if enemy.hp > 0 then
            targetEnemy = enemy
            targetIdx = i
            break
        end
    end

    if not targetEnemy then
        advanceTurn()
        return
    end

    -- Healer logic: heal player or companions if they're hurt
    -- Heal amount scales with companion level (~12% of typical companion HP)
    if companion.canHeal then
        local baseHealAmt = companion.healAmount or math.floor(10 + (companion.level or 1) * 0.8)
        -- Check if player needs healing (below 50%)
        if state.player.hp < state.player.maxHP * 0.5 then
            local healAmt = math.max(baseHealAmt, math.floor(state.player.maxHP * 0.12))
            state.player.hp = math.min(state.player.maxHP, state.player.hp + healAmt)
            log(companion.name .. " heals you for " .. healAmt .. " HP!", {0.3, 0.9, 0.5})
            advanceTurn()
            return
        end
        -- Check if any companion needs healing
        for _, ally in ipairs(state.player.party) do
            if ally ~= companion and ally.hp > 0 and ally.hp < ally.maxHP * 0.5 then
                local healAmt = math.max(baseHealAmt, math.floor(ally.maxHP * 0.12))
                ally.hp = math.min(ally.maxHP, ally.hp + healAmt)
                log(companion.name .. " heals " .. ally.name .. " for " .. healAmt .. " HP!", {0.3, 0.9, 0.5})
                advanceTurn()
                return
            end
        end
    end

    -- Attack the enemy
    local attackName = companion.attacks and companion.attacks[math.random(#companion.attacks)] or "Attack"

    -- Calculate damage with crit chance + talent bonuses
    local baseDamage = math.max(1, companion.attack - targetEnemy.defense + math.random(-2, 2))
    -- Talent: weapon_master (+20% damage)
    if companion.talents and companion.talents.weapon_master then
        baseDamage = math.floor(baseDamage * 1.2)
    end
    -- Passive: animal_bond (+companion damage)
    local cb = state.player.characterBonuses
    if cb and cb.companionDamageMult > 1 then
        baseDamage = math.floor(baseDamage * cb.companionDamageMult)
    end
    -- Talent: lucky (+5% crit) and precision (+15% crit)
    local critChance = companion.critBonus or 5
    if companion.talents then
        if companion.talents.lucky then critChance = critChance + 5 end
        if companion.talents.precision then critChance = critChance + 15 end
    end
    local isCrit = math.random(100) <= critChance
    -- Talent: deadly (+25% crit damage)
    local critMult = 1.5
    if companion.talents and companion.talents.deadly then critMult = critMult + 0.25 end
    local damage = isCrit and math.floor(baseDamage * critMult) or baseDamage

    targetEnemy.hp = targetEnemy.hp - damage

    if isCrit then
        log(companion.name .. " uses " .. attackName .. "! CRITICAL HIT for " .. damage .. " damage!", companion.color)
    else
        log(companion.name .. " uses " .. attackName .. "! " .. damage .. " damage to " .. targetEnemy.name, companion.color)
    end

    if targetEnemy.hp <= 0 then
        onEnemyDefeated(targetEnemy)
    end

    if checkAllEnemiesDefeated() then
        endCombat(true)
    else
        advanceTurn()
    end
end

-- ============================================================================
-- COMPANION MANUAL CONTROL: ATTACK TARGET
-- ============================================================================

-- Player-directed companion attack on the currently selected target.
-- Used when manualPartyControl is enabled instead of the AI companionTurn().
M.companionAttackTarget = function()
    local compIdx = state.combat.currentCompanionIndex
    if not compIdx then
        advanceTurn()
        return
    end

    local companion = state.player.party[compIdx]
    if not companion or companion.hp <= 0 then
        advanceTurn()
        return
    end

    -- Use the player's selected target instead of AI-chosen first alive enemy
    local targetIdx = state.combat.selectedTarget
    local targetEnemy = state.combat.enemies[targetIdx]

    -- Validate target is alive; if not, find first alive enemy as fallback
    if not targetEnemy or targetEnemy.hp <= 0 then
        targetEnemy = nil
        for i, enemy in ipairs(state.combat.enemies) do
            if enemy.hp > 0 then
                targetEnemy = enemy
                targetIdx = i
                state.combat.selectedTarget = i
                break
            end
        end
    end

    if not targetEnemy then
        advanceTurn()
        return
    end

    -- Attack the chosen enemy (same damage logic as companionTurn)
    local attackName = companion.attacks and companion.attacks[math.random(#companion.attacks)] or "Attack"
    local baseDamage = math.max(1, companion.attack - targetEnemy.defense + math.random(-2, 2))
    -- Talent: weapon_master (+20% damage)
    if companion.talents and companion.talents.weapon_master then
        baseDamage = math.floor(baseDamage * 1.2)
    end
    local cb = state.player.characterBonuses
    if cb and cb.companionDamageMult > 1 then
        baseDamage = math.floor(baseDamage * cb.companionDamageMult)
    end
    -- Talent: lucky (+5% crit) and precision (+15% crit)
    local critChance = companion.critBonus or 5
    if companion.talents then
        if companion.talents.lucky then critChance = critChance + 5 end
        if companion.talents.precision then critChance = critChance + 15 end
    end
    local isCrit = math.random(100) <= critChance
    -- Talent: deadly (+25% crit damage)
    local critMult = 1.5
    if companion.talents and companion.talents.deadly then critMult = critMult + 0.25 end
    local damage = isCrit and math.floor(baseDamage * critMult) or baseDamage

    targetEnemy.hp = targetEnemy.hp - damage

    if isCrit then
        log(companion.name .. " uses " .. attackName .. "! CRITICAL HIT for " .. damage .. " damage!", companion.color)
    else
        log(companion.name .. " uses " .. attackName .. "! " .. damage .. " damage to " .. targetEnemy.name, companion.color)
    end

    if targetEnemy.hp <= 0 then
        onEnemyDefeated(targetEnemy)
    end

    if checkAllEnemiesDefeated() then
        endCombat(true)
    else
        state.combat.showSkills = false
        advanceTurn()
    end
end

-- ============================================================================
-- COMPANION MANUAL CONTROL: DEFEND
-- ============================================================================

-- Companion defends (skip turn, could add a defense buff in the future).
M.companionDefend = function()
    local compIdx = state.combat.currentCompanionIndex
    if not compIdx then
        advanceTurn()
        return
    end

    local companion = state.player.party[compIdx]
    if not companion or companion.hp <= 0 then
        advanceTurn()
        return
    end

    -- Healer logic: when defending, heal the most injured ally instead
    -- Heal amount scales with companion level (~12% of target's max HP)
    if companion.canHeal then
        local baseHealAmt = companion.healAmount or math.floor(10 + (companion.level or 1) * 0.8)
        -- Find the most injured ally (player or companion)
        local bestTarget = nil
        local bestHpPercent = 1.0
        if state.player.hp < state.player.maxHP then
            local pct = state.player.hp / state.player.maxHP
            if pct < bestHpPercent then
                bestHpPercent = pct
                bestTarget = "player"
            end
        end
        for i, ally in ipairs(state.player.party) do
            if ally ~= companion and ally.hp > 0 and ally.hp < ally.maxHP then
                local pct = ally.hp / ally.maxHP
                if pct < bestHpPercent then
                    bestHpPercent = pct
                    bestTarget = i
                end
            end
        end
        if bestTarget and bestHpPercent < 0.8 then
            if bestTarget == "player" then
                local healAmt = math.max(baseHealAmt, math.floor(state.player.maxHP * 0.12))
                state.player.hp = math.min(state.player.maxHP, state.player.hp + healAmt)
                log(companion.name .. " heals you for " .. healAmt .. " HP!", {0.3, 0.9, 0.5})
            else
                local ally = state.player.party[bestTarget]
                local healAmt = math.max(baseHealAmt, math.floor(ally.maxHP * 0.12))
                ally.hp = math.min(ally.maxHP, ally.hp + healAmt)
                log(companion.name .. " heals " .. ally.name .. " for " .. healAmt .. " HP!", {0.3, 0.9, 0.5})
            end
            advanceTurn()
            return
        end
    end

    log(companion.name .. " takes a defensive stance.", companion.color or {0.6, 0.8, 0.9})
    advanceTurn()
end

-- ============================================================================
-- ENEMY TURN
-- ============================================================================

M.enemyTurn = function()
    local enemyIdx = state.combat.currentActorIndex
    if not enemyIdx then return end

    local enemy = state.combat.enemies[enemyIdx]
    if not enemy or enemy.hp <= 0 then
        advanceTurn()
        return
    end

    -- Vampire enemies take sunlight damage at the start of their turn
    local diedToSunlight = F.applyVampireSunlightToCombatEnemy(enemy)
    if diedToSunlight then
        onEnemyDefeated(enemy)
        if checkAllEnemiesDefeated() then
            endCombat(true)
        else
            advanceTurn()
        end
        return
    end

    local attackName = enemy.attacks and enemy.attacks[math.random(#enemy.attacks)] or "Attack"

    -- Enemies can target player or companions
    -- Build list of valid targets with weights
    local p = state.player

    -- Count alive enemies to scale player targeting weight
    local aliveEnemies = 0
    for _, e in ipairs(state.combat.enemies) do
        if e.hp > 0 then aliveEnemies = aliveEnemies + 1 end
    end

    -- With many enemies, reduce focus-fire on the player so damage spreads
    -- Player weight: 2.0 at 1-4 enemies, 1.5 at 5-8, 1.0 at 9-12, 0.7 at 13+
    local playerWeight
    if aliveEnemies <= 4 then
        playerWeight = 2.0
    elseif aliveEnemies <= 8 then
        playerWeight = 1.5
    elseif aliveEnemies <= 12 then
        playerWeight = 1.0
    else
        playerWeight = 0.7
    end

    local targets = {{type = "player", hp = p.hp, defense = p.defense, name = "you", dodgeChance = p.dodgeChance or 0, weight = playerWeight}}
    if p.party then
        for i, companion in ipairs(p.party) do
            if companion.hp > 0 then
                -- Soldiers with Taunt draw extra aggro (weight 1.5)
                local w = 1.0
                if companion.class and companion.class.skills then
                    for _, sk in ipairs(companion.class.skills) do
                        if sk == "Taunt" then w = 1.5; break end
                    end
                end
                local compDodge = 0
                if companion.talents and companion.talents.quick then compDodge = compDodge + 10 end
                local compDef = companion.defense or 0
                if companion.talents and companion.talents.sentinel then compDef = compDef + 5 end
                table.insert(targets, {type = "companion", index = i, hp = companion.hp, defense = compDef, name = companion.name, dodgeChance = compDodge, weight = w})
            end
        end
    end

    -- Weighted random target selection
    local totalWeight = 0
    for _, t in ipairs(targets) do totalWeight = totalWeight + t.weight end
    local roll = math.random() * totalWeight
    local targetData
    local cumulative = 0
    for _, t in ipairs(targets) do
        cumulative = cumulative + t.weight
        if roll <= cumulative then
            targetData = t
            break
        end
    end
    -- Fallback safety (should never happen, but guard against float edge cases)
    if not targetData then targetData = targets[#targets] end

    -- Enhanced attack display - show enemy prominently
    log("", {1, 1, 1})  -- Empty line for spacing
    log(">>> " .. enemy.name .. " <<<", {0.9, 0.4, 0.4})
    log("    uses \"" .. attackName .. "\"", {0.8, 0.3, 0.3})

    -- Phase through first attack (Wraith racial)
    if targetData.type == "player" then
        local charBonus = p.characterBonuses
        if charBonus and charBonus.phaseFirstAttack and not state.combat.phaseUsed then
            state.combat.phaseUsed = true
            log("    You phase through the attack! (Ethereal Form)", {0.5, 0.5, 0.9})
            advanceTurn()
            return
        end
    end

    -- Check for dodge (player only)
    local dodgeChance = targetData.dodgeChance or 0
    -- Passive: trap_sense (+dodge on first enemy attack per combat)
    if targetData.type == "player" then
        local cb = p.characterBonuses
        if cb and cb.firstAttackDodgeBonus > 0 and not state.combat.trapSenseUsed then
            dodgeChance = dodgeChance + cb.firstAttackDodgeBonus
            state.combat.trapSenseUsed = true
        end
    end
    if dodgeChance > 0 and math.random(100) <= dodgeChance then
        log("    " .. targetData.name .. " dodged the attack!", {0.3, 0.9, 0.5})
        advanceTurn()
        return
    end

    -- Calculate effective defense (with passive bonuses)
    local effectiveDefense = targetData.defense or 0
    -- Passive: vampire_sense (+defense vs undead)
    if targetData.type == "player" then
        local cb = p.characterBonuses
        if cb and cb.undeadDefenseBonus > 0 and enemy.isUndead then
            effectiveDefense = effectiveDefense + cb.undeadDefenseBonus
        end
    end
    local baseDamage = math.max(1, enemy.attack - effectiveDefense + math.random(-2, 2))

    -- Apply damage type resistance (if enemy has damageType and target has resistances)
    local damage = baseDamage
    if targetData.type == "player" and enemy.damageType then
        -- Initialize player resistances if not present
        if not p.resistances then p.resistances = {} end
        damage = M.applyDamageResistance(baseDamage, enemy.damageType, p)

        -- Show damage type in combat log
        local damageTypeText = enemy.damageType and (" [" .. (DAMAGE_TYPES[enemy.damageType] and DAMAGE_TYPES[enemy.damageType].name or enemy.damageType) .. "]") or ""
        if damage ~= baseDamage then
            log("    " .. damageTypeText .. " damage modified by resistance!", {0.8, 0.7, 0.5})
        end
    end

    if targetData.type == "player" then
        -- Check for shield block
        if p.equipment and p.equipment.shield and p.equipment.shield.blockChance then
            local blockChance = p.equipment.shield.blockChance
            if math.random(1, 100) <= blockChance then
                -- Block successful!
                local blockedDamage = damage
                damage = 0

                -- Apply reflect damage if shield has it
                if p.equipment.shield.reflectDamage and p.equipment.shield.reflectDamage > 0 then
                    local reflectDmg = p.equipment.shield.reflectDamage
                    enemy.hp = enemy.hp - reflectDmg
                    log("    BLOCKED! " .. blockedDamage .. " damage blocked! Reflected " .. reflectDmg .. " damage!", {0.3, 0.7, 0.9})
                    if enemy.hp <= 0 then
                        log("    " .. enemy.name .. " defeated by reflect damage!", {0.3, 0.9, 0.5})
                        advanceTurn()
                        return
                    end
                else
                    log("    BLOCKED! " .. blockedDamage .. " damage blocked!", {0.3, 0.7, 0.9})
                end
            end
        end

        -- Check for Second Wind talent
        if p.talents and p.talents.second_wind and not state.combat.secondWindUsed and damage > 0 then
            local triggerPercent = 0.2
            local oldHpPercent = p.hp / p.maxHP
            local newHpPercent = (p.hp - damage) / p.maxHP
            if oldHpPercent > triggerPercent and newHpPercent <= triggerPercent then
                local healAmount = math.floor(p.maxHP * 0.25)
                p.hp = p.hp + healAmount
                state.combat.secondWindUsed = true
                log("    SECOND WIND! Healed " .. healAmount .. " HP!", {0.3, 0.9, 0.5})
            end
        end

        -- Passive: thick_skinned (flat damage reduction)
        if damage > 0 then
            local cb = p.characterBonuses
            if cb and cb.flatDamageReduction > 0 then
                damage = math.max(1, damage - cb.flatDamageReduction)
            end
        end

        if damage > 0 then
            p.hp = p.hp - damage
            log("    " .. damage .. " damage to you!", {0.9, 0.3, 0.3})
        end

        -- Vampire bite transformation (check enemy.id since enemy instances use id, not race)
        if not p.isVampire and VAMPIRE_ENEMY_IDS[enemy.id] and math.random() < 0.15 then
            log("    The vampire's bite infects you with dark curse!", {0.8, 0.2, 0.3})
            log("    You will become a vampire after this battle...", {0.9, 0.5, 0.1})
            state.combat.playerBittenByVampire = true
        end

        if p.hp <= 0 then
            -- Survive killing blow (Catfolk Nine Lives / Revenant Undying Will)
            local charBonus = p.characterBonuses
            if charBonus and charBonus.surviveKillingBlow and not state.combat.killingBlowSurvived then
                p.hp = 1
                state.combat.killingBlowSurvived = true
                log("    You survive the killing blow! (1 HP)", {1, 0.8, 0.2})
                advanceTurn()
                return
            end
            endCombat(false)
            return
        end
    else
        local companion = p.party[targetData.index]
        companion.hp = math.max(0, companion.hp - damage)
        log("    " .. damage .. " damage to " .. companion.name .. "!", {0.9, 0.5, 0.3})

        if companion.hp <= 0 then
            companion.hp = 0
            log(companion.name .. " has fallen!", {0.7, 0.3, 0.3})
        end
    end

    advanceTurn()
end

-- ============================================================================
-- END COMBAT
-- ============================================================================

M.endCombat = function(victory)
    if victory then
        -- All enemies defeated - victory!
        local totalEnemies = #state.combat.enemies
        if totalEnemies > 1 then
            log("", {1, 1, 1})
            log("All " .. totalEnemies .. " enemies defeated!", {0.2, 1, 0.3})
        end
        log("Victory!", {0.3, 1, 0.3})

        -- Handle Luminary patrol combat victory
        if state.currentPatrolCombat then
            LuminaryPatrols.onPatrolCombatVictory()
        end

        -- Handle map enemy combat victory (remove enemy from map)
        if state.world and state.world.currentMapEnemy then
            MapEnemies.onCombatEnd(true)
        end

        -- Handle dungeon visible enemy combat victory
        if state.dungeon and state.dungeon.currentVisibleEnemy then
            DungeonEnemies.onCombatEnd(true)
        end

        -- Handle prison guard combat victory (mark guard dead, award drops)
        if state.dungeon and state.dungeon.currentPrisonGuard then
            local guard = state.dungeon.currentPrisonGuard
            guard.alive = false
            guard.inCombat = false

            -- Award prison-specific drops to prison inventory
            if guard.drops and state.prisonEscape then
                local prison = state.prisonEscape
                if not prison.prisonInventory then prison.prisonInventory = {} end
                for _, dropId in ipairs(guard.drops) do
                    -- Find the drop definition from scavenge items
                    local dropItem = nil
                    for _, scavItem in ipairs(PrisonEscape.SCAVENGE_ITEMS) do
                        if scavItem.id == dropId then
                            dropItem = scavItem
                            break
                        end
                    end
                    if dropItem then
                        -- Add to prison inventory (stack if exists)
                        local found = false
                        for _, invItem in ipairs(prison.prisonInventory) do
                            if invItem.id == dropItem.id then
                                invItem.qty = (invItem.qty or 1) + 1
                                found = true
                                break
                            end
                        end
                        if not found then
                            table.insert(prison.prisonInventory, {
                                id = dropItem.id,
                                name = dropItem.name,
                                desc = dropItem.desc,
                                category = dropItem.category,
                                qty = 1,
                                icon = dropItem.icon,
                                weight = dropItem.weight,
                                healAmount = dropItem.healAmount,
                            })
                        end
                        log("Guard dropped: " .. dropItem.name, {0.5, 0.9, 0.5})
                    end
                end
            end
            state.dungeon.currentPrisonGuard = nil
        end

        -- Check for vampire transformation
        if state.combat.playerBittenByVampire and not state.player.isVampire then
            log("", {1, 1, 1})
            log("The vampire's curse takes hold...", {0.8, 0.2, 0.3})
            F.transformPlayerIntoVampire()
        end

        -- Revive fallen companions with 25% HP after victory
        if state.player.party then
            for _, companion in ipairs(state.player.party) do
                if (companion.hp or 0) <= 0 then
                    companion.hp = math.max(1, math.floor((companion.maxHP or 50) * 0.25))
                    log(companion.name .. " recovers consciousness. (" .. companion.hp .. " HP)", {0.5, 0.8, 0.5})
                end
            end
        end

        -- Return to dungeon if we're in one, otherwise world map
        if state.inDungeon then
            state.phase = "dungeon"
        else
            state.phase = "map"
        end
    else
        -- Handle map enemy combat defeat (respawn enemy nearby)
        if state.world and state.world.currentMapEnemy then
            MapEnemies.onCombatEnd(false)
        end

        -- Handle dungeon visible enemy combat defeat
        if state.dungeon and state.dungeon.currentVisibleEnemy then
            DungeonEnemies.onCombatEnd(false)
        end

        -- Handle prison escape defeat: knocked out and dragged to cell instead of dying
        if state.inPrisonEscape and state.prisonEscape then
            local msg = PrisonEscape.onGuardCaught(state.prisonEscape)
            if msg then log(msg, {0.9, 0.4, 0.4}) end
            log("You are knocked unconscious and dragged back to your cell...", {0.7, 0.3, 0.3})
            -- Restore player to half HP (knocked out, not killed)
            state.player.hp = math.max(1, math.floor((state.player.maxHP or 100) * 0.25))
            -- Update dungeon position to match prison position
            state.dungeon.currentFloor = state.prisonEscape.currentFloor
            state.dungeon.playerX = state.prisonEscape.playerX
            state.dungeon.playerY = state.prisonEscape.playerY
            -- Clear visible enemies for current floor so they re-initialize at correct positions
            local curFloor = state.dungeon.floors[state.dungeon.currentFloor]
            if curFloor then curFloor.visibleEnemies = nil end
            -- Reveal tiles around new position
            local resetFloor = state.dungeon.floors[state.dungeon.currentFloor]
            if resetFloor then
                for ddy = -1, 1 do
                    for ddx = -1, 1 do
                        local nx, ny = state.dungeon.playerX + ddx, state.dungeon.playerY + ddy
                        if resetFloor.grid[ny] and resetFloor.grid[ny][nx] then
                            resetFloor.grid[ny][nx].explored = true
                        end
                    end
                end
            end
            state.phase = "dungeon"
            -- Clear any prison guard reference
            if state.dungeon.currentPrisonGuard then
                state.dungeon.currentPrisonGuard = nil
            end
            return  -- Skip permadeath - player is sent back to cell instead
        end

        -- Handle prison guard combat defeat/flee (use onGuardCaught to send back to cell)
        if state.dungeon and state.dungeon.currentPrisonGuard then
            local guard = state.dungeon.currentPrisonGuard
            guard.inCombat = false
            -- Reset guard to patrol (push away from player)
            guard.alerted = false
            if state.prisonEscape then
                local msg = PrisonEscape.onGuardCaught(state.prisonEscape)
                if msg then log(msg, {0.9, 0.4, 0.4}) end
                -- Update dungeon position to match prison position
                state.dungeon.currentFloor = state.prisonEscape.currentFloor
                state.dungeon.playerX = state.prisonEscape.playerX
                state.dungeon.playerY = state.prisonEscape.playerY
                -- Clear visible enemies for current floor so they re-initialize at correct positions
                local curFloor = state.dungeon.floors[state.dungeon.currentFloor]
                if curFloor then curFloor.visibleEnemies = nil end
                -- Reveal tiles around new position
                local resetFloor = state.dungeon.floors[state.dungeon.currentFloor]
                if resetFloor then
                    for ddy = -1, 1 do
                        for ddx = -1, 1 do
                            local nx, ny = state.dungeon.playerX + ddx, state.dungeon.playerY + ddy
                            if resetFloor.grid[ny] and resetFloor.grid[ny][nx] then
                                resetFloor.grid[ny][nx].explored = true
                            end
                        end
                    end
                end
                state.phase = "dungeon"
                state.dungeon.currentPrisonGuard = nil
                return  -- Skip permadeath - player is sent back to cell instead
            end
            state.dungeon.currentPrisonGuard = nil
        end

        -- PERMADEATH: Character dies!
        -- Find the enemy that killed the player
        local killerIdx = state.combat.currentActorIndex or 1
        local enemy = state.combat.enemies[killerIdx] or state.combat.enemies[1]

        -- Record death info
        state.deathInfo = {
            killedBy = enemy and enemy.name or "Unknown",
            killedByLevel = enemy and enemy.level or 1,
            location = state.world.currentTown and state.world.currentTown.name or "the wilderness",
        }

        -- Add to graveyard
        local gravestone = {
            name = state.player.name or "Hero",
            class = state.player.class and state.player.class.name or "Unknown",
            level = state.player.level or 1,
            killedBy = state.deathInfo.killedBy,
            location = state.deathInfo.location,
            enemiesDefeated = state.stats.enemiesDefeated,
            questsCompleted = state.stats.questsCompleted,
            goldEarned = state.stats.goldEarned,
            daysSurvived = state.daysPassed,
            deathTime = os.time(),
        }
        table.insert(graveyard, gravestone)

        -- Limit graveyard size to prevent unbounded memory growth
        local MAX_GRAVEYARD_SIZE = 50
        while #graveyard > MAX_GRAVEYARD_SIZE do
            table.remove(graveyard, 1)  -- Remove oldest entries
        end

        -- Store death stash (gold and items for retrieval at guild hall)
        local stashGold = state.player.gold or 0
        local stashItems = {}
        if Backpack and Backpack.getAllItems then
            local items = Backpack.getAllItems()
            if items then
                for _, item in ipairs(items) do
                    table.insert(stashItems, {id = item.id, count = item.count or 1})
                end
            end
        end
        if stashGold > 0 or #stashItems > 0 then
            -- Append to existing stash (multiple deaths accumulate)
            local existing = PlayerData.deathStash or {gold = 0, items = {}}
            existing.gold = (existing.gold or 0) + stashGold
            for _, item in ipairs(stashItems) do
                table.insert(existing.items, item)
            end
            existing.location = state.deathInfo.location or "the wilderness"
            existing.characterName = state.player.name or "Hero"
            PlayerData.deathStash = existing
        end

        -- Save graveyard and death stash
        if savePlayerData then
            PlayerData.textRPGGraveyard = graveyard
            savePlayerData()
        end

        -- Handle Luminary patrol combat defeat
        if state.currentPatrolCombat then
            LuminaryPatrols.onPatrolCombatDefeat()
        end

        log("", {1, 1, 1})
        log("YOU HAVE FALLEN!", {0.9, 0.1, 0.1})
        local className = state.player.class and state.player.class.name or "Hero"
        local playerLevel = state.player.level or 1
        local killedByName = state.deathInfo and state.deathInfo.killedBy or "Unknown"
        log(className .. " Lv." .. playerLevel .. " was slain by " .. killedByName, {0.7, 0.3, 0.3})
        F.addJournalEvent("death", "Slain by " .. killedByName, {0.9, 0.1, 0.1})
        if state.player.journal and state.player.journal.actionStats and state.player.journal.actionStats.combat then
            state.player.journal.actionStats.combat.deaths = (state.player.journal.actionStats.combat.deaths or 0) + 1
        end

        -- Track death for race unlock
        state.stats.deaths = (state.stats.deaths or 0) + 1

        -- Check for "died 5 times" achievement
        if state.stats.deaths >= 5 then
            if not PlayerData.achievements then PlayerData.achievements = {} end
            if not PlayerData.achievements.died_5_times then
                PlayerData.achievements.died_5_times = true
                log("ACHIEVEMENT UNLOCKED: Death is just the beginning...", {0.5, 0.3, 0.6})
            end
        end

        state.phase = "death"
    end
end

-- ============================================================================
-- COUNT EXPLORED TILES (for save/stats)
-- ============================================================================

M.countExploredTiles = function()
    local count = 0
    if state.world.useWorldGen then
        -- For WorldGen, count explored tiles in all loaded chunks
        local loadedChunks = WorldGen.getLoadedChunks()
        local chunkSize = WorldGen.getChunkSize()
        for _, chunk in pairs(loadedChunks) do
            if chunk.tiles then
                for y = 0, chunkSize - 1 do
                    if chunk.tiles[y] then
                        for x = 0, chunkSize - 1 do
                            local tile = chunk.tiles[y][x]
                            if tile and tile.explored then
                                count = count + 1
                            end
                        end
                    end
                end
            end
        end
    elseif state.world and state.world.mapData then
        for y, row in pairs(state.world.mapData) do
            for x, tile in pairs(row) do
                if tile.explored then count = count + 1 end
            end
        end
    end
    return count
end

return M
