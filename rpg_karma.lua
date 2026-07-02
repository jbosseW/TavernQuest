-- RPG Karma, Crime, Stealth, Jail, Faction, Journal, Inventory, and Dev Mode
-- Extracted from textrpg.lua

local Backpack = require("backpack")
local Data = require("rpg_data")

local KARMA_LEVELS = Data.KARMA_LEVELS
local CRIME_TYPES = Data.CRIME_TYPES
local FACTIONS = Data.FACTIONS
local STAT_DEFINITIONS = Data.STAT_DEFINITIONS

local M = {}

-- Upvalues set by register()
local state
local F

-- Local log helper (delegates to the shared log via F table / _G)
local function log(text, color)
    if F and F.log then
        F.log(text, color)
    elseif _G.log then
        _G.log(text, color)
    elseif state and state.textLog then
        table.insert(state.textLog, {text = text, color = color or {0.8, 0.8, 0.8}, time = love.timer.getTime()})
        if #state.textLog > 100 then
            table.remove(state.textLog, 1)
        end
    end
end

-- ============================================================================
-- DATA TABLES (local to this module, copied from textrpg.lua)
-- ============================================================================

-- Time of day detection modifiers
local STEALTH_TIME_MODIFIERS = {
    [0] = {name = "Late Night", detection = 0.20, desc = "Excellent stealth"},
    [1] = {name = "Late Night", detection = 0.20, desc = "Excellent stealth"},
    [2] = {name = "Late Night", detection = 0.20, desc = "Excellent stealth"},
    [3] = {name = "Late Night", detection = 0.20, desc = "Excellent stealth"},
    [4] = {name = "Late Night", detection = 0.20, desc = "Excellent stealth"},
    [5] = {name = "Dawn", detection = 0.50, desc = "Good stealth"},
    [6] = {name = "Dawn", detection = 0.70, desc = "Fair stealth"},
    [7] = {name = "Morning", detection = 0.90, desc = "Poor stealth"},
    [8] = {name = "Morning", detection = 0.90, desc = "Poor stealth"},
    [9] = {name = "Morning", detection = 0.90, desc = "Poor stealth"},
    [10] = {name = "Morning", detection = 0.90, desc = "Poor stealth"},
    [11] = {name = "Morning", detection = 0.90, desc = "Poor stealth"},
    [12] = {name = "Noon", detection = 1.00, desc = "Worst stealth"},
    [13] = {name = "Noon", detection = 1.00, desc = "Worst stealth"},
    [14] = {name = "Afternoon", detection = 0.90, desc = "Poor stealth"},
    [15] = {name = "Afternoon", detection = 0.90, desc = "Poor stealth"},
    [16] = {name = "Afternoon", detection = 0.90, desc = "Poor stealth"},
    [17] = {name = "Afternoon", detection = 0.90, desc = "Poor stealth"},
    [18] = {name = "Dusk", detection = 0.60, desc = "Good stealth"},
    [19] = {name = "Evening", detection = 0.40, desc = "Very good stealth"},
    [20] = {name = "Evening", detection = 0.40, desc = "Very good stealth"},
    [21] = {name = "Evening", detection = 0.40, desc = "Very good stealth"},
    [22] = {name = "Night", detection = 0.20, desc = "Excellent stealth"},
    [23] = {name = "Night", detection = 0.20, desc = "Excellent stealth"},
}

-- Location detection modifiers
local STEALTH_LOCATION_MODIFIERS = {
    town_day = {multiplier = 1.5, name = "Open Street (Day)"},
    town_night = {multiplier = 1.0, name = "Open Street (Night)"},
    building = {multiplier = 0.3, name = "Building Interior"},
    alley = {multiplier = 0.5, name = "Shadows/Alleys"},
    market = {multiplier = 0.7, name = "Crowded Market"},
    square = {multiplier = 1.2, name = "Town Square"},
    wilderness = {multiplier = 0.6, name = "Wilderness"},
    house = {multiplier = 0.4, name = "Inside House"},
}

-- Journal tab definitions
local JOURNAL_TABS = {
    {id = "events", name = "Events", icon = "\xF0\x9F\x93\x9C"},
    {id = "quests", name = "Quests", icon = "\xF0\x9F\x93\x8B"},
    {id = "actions", name = "Actions", icon = "\xF0\x9F\x93\x8A"},
    {id = "factions", name = "Factions", icon = "\xF0\x9F\x8F\x9B\xEF\xB8\x8F"},
    {id = "party", name = "Party", icon = "\xF0\x9F\x91\xA5"},
    {id = "stats", name = "Stats", icon = "\xF0\x9F\x93\x88"},
    {id = "status", name = "Status", icon = "\xF0\x9F\xA9\xBA"},
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================

M.F_FUNCTIONS = {
    "getKarmaLevel",
    "calculateDetectionChance",
    "getDetectionDescription",
    "toggleStealthMode",
    "checkDetection",
    "addJournalEvent",
    "toggleJournal",
    "commitCrime",
    "arrestPlayer",
    "payBounty",
    "serveJailTime",
    "attemptJailEscape",
    "changeFactionRep",
    "joinFaction",
    "getFactionBenefits",
    "getTQInventory",
    "useItem",
    "activateDevMode",
    "checkDevModePassword",
}

function M.register(s, f)
    state = s
    F = f
    for _, name in ipairs(M.F_FUNCTIONS) do
        if M[name] then F[name] = M[name] end
    end
end

-- ============================================================================
-- KARMA & DETECTION
-- ============================================================================

M.getKarmaLevel = function(karma)
    for _, level in ipairs(KARMA_LEVELS) do
        if karma >= level.min and karma <= level.max then
            return level
        end
    end
    return KARMA_LEVELS[3] -- Default to Neutral
end

-- Calculate detection chance for stealth action
M.calculateDetectionChance = function(action)
    if not state.player then return 1.0 end

    -- Base detection - indoors ignores time of day
    local hour = math.floor(state.timeOfDay or 12)
    local timeData = STEALTH_TIME_MODIFIERS[hour] or STEALTH_TIME_MODIFIERS[12]
    local baseDetection
    local isIndoor = state.inPrisonEscape or state.inDungeon or
        state.phase == "building_interior" or state.phase == "tavern_interior" or state.phase == "guild_interior"

    if isIndoor then
        baseDetection = 0.35  -- Dim indoor lighting, fixed
    else
        baseDetection = timeData.detection
    end

    -- Location modifier
    local locationMod = 1.0
    if isIndoor then
        locationMod = STEALTH_LOCATION_MODIFIERS.building and STEALTH_LOCATION_MODIFIERS.building.multiplier or 0.3
    elseif state.phase == "town" or state.phase == "npc_list" or state.phase == "dialogue" then
        if hour >= 6 and hour <= 18 then
            locationMod = STEALTH_LOCATION_MODIFIERS.town_day.multiplier
        else
            locationMod = STEALTH_LOCATION_MODIFIERS.town_night.multiplier
        end
    elseif state.phase == "lockpicking" or state.phase == "burglary_success" then
        locationMod = STEALTH_LOCATION_MODIFIERS.alley.multiplier
    elseif state.phase == "map" then
        locationMod = STEALTH_LOCATION_MODIFIERS.wilderness.multiplier
    end

    -- Class modifier
    local classMod = 0
    local classId = state.player.class and state.player.class.id or ""
    if classId == "rogue" then
        classMod = -0.30
    elseif state.player.specialization == "assassin" then
        classMod = -0.40
    elseif state.player.specialization == "shadow_rogue" then
        classMod = -0.35
    elseif classId == "warrior" then
        classMod = 0.10
    elseif classId == "cleric" then
        classMod = 0.05
    end

    -- Vampire modifier (time-dependent)
    if state.player.isVampire then
        if hour >= 19 or hour <= 5 then
            classMod = classMod - 0.25  -- Night bonus
        else
            classMod = classMod + 0.15  -- Day penalty
        end
    end

    -- Equipment modifier
    local equipMod = 0
    if state.player.equipment.armor then
        local armor = state.player.equipment.armor
        if armor.id and armor.id:find("plate") then
            equipMod = 0.15  -- Heavy armor
        elseif armor.id and armor.id:find("chain") then
            equipMod = 0.05  -- Medium armor
        elseif armor.id and armor.id:find("leather") then
            equipMod = -0.05  -- Light armor
        elseif armor.id and armor.id:find("cloth") then
            equipMod = -0.10  -- Cloth
        end
    end

    -- Stealth gear bonuses
    if Backpack.hasItem("tq_stealth_cloak") then
        equipMod = equipMod - 0.20
    end
    if Backpack.hasItem("tq_dark_hood") then
        equipMod = equipMod - 0.10
    end
    if Backpack.hasItem("tq_soft_boots") then
        equipMod = equipMod - 0.10
    end

    -- Stealth mode modifier
    local stealthMod = 0
    if state.player.stealthMode then
        stealthMod = -0.25  -- Major reduction when actively sneaking
    end

    -- Stealth perk modifiers (stealthPerks is a dictionary, not unlockedSkills)
    local skillMod = 0
    if state.player.stealthPerks then
        if state.player.stealthPerks.shadow_blend then
            skillMod = skillMod - 0.20
        end
        if state.player.stealthPerks.silent_step then
            skillMod = skillMod - 0.15
        end
        if state.player.stealthPerks.vanish then
            skillMod = skillMod - 0.25
        end
    end

    -- Vampire skills
    if state.player.vampireSkillTree then
        if state.player.vampireSkillTree.night_stalker and (hour >= 19 or hour <= 5) then
            skillMod = skillMod - 0.30
        end
    end

    -- Talent modifiers
    if state.player.talents then
        if state.player.talents.sneaky then
            skillMod = skillMod - 0.10
        end
        if state.player.talents.night_owl and (hour >= 19 or hour <= 5) then
            skillMod = skillMod - 0.20
        end
        if state.player.talents.urban_phantom and (state.phase == "town" or state.phase == "npc_list") then
            skillMod = skillMod - 0.15
        end
    end

    -- Calculate final detection
    local finalDetection = baseDetection * locationMod + classMod + equipMod + stealthMod + skillMod

    -- Cap between 1% and 100%
    finalDetection = math.max(0.01, math.min(1.0, finalDetection))

    -- If in stealth mode, cap maximum at 75%
    if state.player.stealthMode then
        finalDetection = math.min(0.75, finalDetection)
    end

    -- Sync computed modifiers to player state for cross-system access (mapenemies, combat)
    state.player.classStealthBonus = -classMod  -- Convert from detection penalty to stealth bonus
    state.player.skillStealthMod = -skillMod    -- Convert from detection penalty to stealth bonus
    state.player.equipmentStealthMod = -equipMod  -- Convert from detection penalty to stealth bonus

    return finalDetection
end

-- Get current detection chance description
M.getDetectionDescription = function()
    if not state.player then return "Unknown", 1.0 end

    local detection = calculateDetectionChance()
    local percent = math.floor(detection * 100)

    local desc
    if percent <= 10 then
        desc = "Hidden"
    elseif percent <= 25 then
        desc = "Very Low"
    elseif percent <= 40 then
        desc = "Low"
    elseif percent <= 60 then
        desc = "Moderate"
    elseif percent <= 80 then
        desc = "High"
    else
        desc = "Very High"
    end

    return desc, detection
end

-- Toggle stealth mode (exploration only - blocked during combat)
M.toggleStealthMode = function()
    if not state.player then return end
    -- Block toggling during combat - use Hide action instead
    if state.phase == "combat" or state.phase == "tactical_combat" or state.phase == "stealth_approach" then
        return
    end

    state.player.stealthMode = not state.player.stealthMode

    if state.player.stealthMode then
        log("\xF0\x9F\x8C\x91 Stealth mode ENABLED. Moving carefully...", {0.6, 0.6, 0.8})
        local desc, detection = getDetectionDescription()
        log("Detection chance: " .. math.floor(detection * 100) .. "% (" .. desc .. ")", {0.7, 0.7, 0.9})
    else
        log("\xF0\x9F\x8C\x9E Stealth mode DISABLED. Moving normally.", {0.8, 0.8, 0.8})
    end
end

-- Check if player is detected during action
M.checkDetection = function(action)
    local detection = calculateDetectionChance(action)
    local roll = math.random()

    -- Debug info in stealth mode
    if state.player.stealthMode then
        log("Detection roll: " .. math.floor(roll * 100) .. "% vs " .. math.floor(detection * 100) .. "%", {0.6, 0.6, 0.6})
    end

    return roll < detection
end

-- ============================================================================
-- JOURNAL
-- ============================================================================

-- Add event to journal log
M.addJournalEvent = function(eventType, message, color)
    if not state.player or not state.player.journal then return end

    table.insert(state.player.journal.eventLog, {
        day = state.daysPassed or 0,
        hour = math.floor(state.timeOfDay or 12),
        type = eventType,
        message = message,
        color = color or {1, 1, 1}
    })

    -- Keep only last 200 events to prevent memory bloat
    if #state.player.journal.eventLog > 200 then
        table.remove(state.player.journal.eventLog, 1)
    end
end

-- Toggle journal open/closed
M.toggleJournal = function()
    -- Debug logging
    print("toggleJournal called")
    print("state.player exists:", state.player ~= nil)
    if state.player then
        print("state.player.journal exists:", state.player.journal ~= nil)
        if state.player.journal then
            print("journal.isOpen:", state.player.journal.isOpen)
        end
    end

    if not state.player or not state.player.journal then
        print("WARNING: Cannot toggle journal - player or journal is nil!")
        return
    end

    state.player.journal.isOpen = not state.player.journal.isOpen
    print("Journal toggled to:", state.player.journal.isOpen)

    if state.player.journal.isOpen then
        log("\xF0\x9F\x93\x96 Journal opened", {0.7, 0.8, 0.9})
    else
        log("\xF0\x9F\x93\x95 Journal closed", {0.7, 0.7, 0.7})
    end
end

-- ============================================================================
-- CRIME / JAIL
-- ============================================================================

-- Commit a crime
M.commitCrime = function(crimeType)
    if not state.player then return end
    local crime = CRIME_TYPES[crimeType]
    if not crime then return end

    -- Add karma penalty
    state.player.karma = math.max(-100, (state.player.karma or 0) + crime.karma)

    -- Add bounty
    state.player.bounty = (state.player.bounty or 0) + crime.bounty

    -- Record crime
    state.player.crimes = state.player.crimes or {}
    table.insert(state.player.crimes, {
        type = crimeType,
        name = crime.name,
        location = state.currentTown or "Unknown",
        day = state.daysPassed or 0
    })

    log("Crime committed: " .. crime.name .. "! Bounty: +" .. crime.bounty .. " gold", {0.9, 0.3, 0.3})
    addJournalEvent("crime", crime.name .. " - Bounty +" .. crime.bounty .. "g", {0.9, 0.3, 0.3})
    if state.player.journal and state.player.journal.actionStats and state.player.journal.actionStats.crimes then
        state.player.journal.actionStats.crimes.crimesCommitted = (state.player.journal.actionStats.crimes.crimesCommitted or 0) + 1
        if not state.player.journal.actionStats.crimes.crimesByType then
            state.player.journal.actionStats.crimes.crimesByType = {}
        end
        if not state.player.journal.actionStats.crimes.crimesByType[crimeType] then
            state.player.journal.actionStats.crimes.crimesByType[crimeType] = 0
        end
        state.player.journal.actionStats.crimes.crimesByType[crimeType] = state.player.journal.actionStats.crimes.crimesByType[crimeType] + 1
    end

    -- Lose reputation with lawful factions
    changeFactionRep("holy_dominion", crime.karma)
    changeFactionRep("dwarven_kingdom", crime.karma)
    changeFactionRep("gnomish_republic", crime.karma)

    -- Gain reputation with crime organizations
    if crime.karma <= -10 then
        changeFactionRep("thieves_guild", math.abs(crime.karma) * 0.5)
        if crime.karma <= -20 then
            changeFactionRep("assassins_guild", math.abs(crime.karma) * 0.3)
        end
    end

    -- Check for guard response using stealth system
    if state.currentTown and state.player.bounty > 50 then
        -- Use stealth detection instead of simple bounty check
        local detected = checkDetection(crimeType)

        if detected then
            log("The guards have spotted you!", {0.9, 0.3, 0.3})
            arrestPlayer()
        else
            -- Crime committed but not caught!
            if state.player.stealthMode then
                log("You slip away unnoticed... (+25% XP bonus)", {0.5, 0.8, 0.5})
                -- Stealth XP bonus (applied to next XP gain)
                state.player.stealthXPBonus = (state.player.stealthXPBonus or 0) + 0.25
            end
        end
    end
end

-- Arrest the player
M.arrestPlayer = function()
    if not state.player then return end

    log("You have been arrested!", {0.9, 0.2, 0.2})

    -- Calculate jail time based on crimes
    local totalJailTime = 0
    for _, crime in ipairs(state.player.crimes) do
        local crimeData = CRIME_TYPES[crime.type]
        if crimeData then
            totalJailTime = totalJailTime + crimeData.jailTime
        end
    end

    -- Option 1: Pay bounty + 50% fine
    -- Option 2: Serve jail time
    -- Option 3: Attempt escape (risky)

    state.player.isJailed = true
    state.player.jailTimeRemaining = totalJailTime
    state.phase = "jailed"
end

-- Pay bounty to clear crimes
M.payBounty = function()
    if not state.player then return end
    local totalCost = math.floor(state.player.bounty * 1.5)  -- 50% fine

    if state.player.gold >= totalCost then
        state.player.gold = state.player.gold - totalCost
        PlayerData.coins = state.player.gold  -- Sync
        state.player.bounty = 0
        state.player.crimes = {}
        state.player.isJailed = false
        state.player.jailTimeRemaining = 0
        state.player.karma = math.min(100, state.player.karma + 10)  -- Slight karma restoration
        log("Bounty paid. Crimes cleared.", {0.5, 0.9, 0.5})
        state.phase = "town"
        return true
    else
        log("Not enough gold! Need " .. totalCost .. " gold.", {0.9, 0.3, 0.3})
        return false
    end
end

-- Serve jail time
M.serveJailTime = function()
    if not state.player then return end

    -- Fast-forward time
    local hoursServed = state.player.jailTimeRemaining
    state.player.jailTimeRemaining = 0
    state.player.isJailed = false
    state.player.bounty = 0
    state.player.crimes = {}
    state.player.karma = math.min(100, state.player.karma + 5)  -- Slight karma restoration

    -- Advance game time
    local daysServed = math.floor(hoursServed / 24)
    state.daysPassed = state.daysPassed + daysServed

    log("You served " .. daysServed .. " days in jail.", {0.7, 0.7, 0.7})
    state.phase = "town"
end

-- Attempt to escape from jail
M.attemptJailEscape = function()
    if not state.player then return end

    -- Escape chance based on AGILITY and rogue class
    local baseChance = 0.3
    local agilityMod = getStatModifier(state.player.stats.AGILITY or 10)
    local escapeChance = baseChance + (agilityMod * 0.05)

    if state.player.class and state.player.class.id == "rogue" then
        escapeChance = escapeChance + 0.2
    end

    if math.random() < escapeChance then
        log("You successfully escaped from jail!", {0.3, 0.9, 0.3})
        state.player.isJailed = false
        state.player.karma = math.max(-100, state.player.karma - 20)  -- Escaping is a crime
        state.player.bounty = state.player.bounty * 2  -- Double bounty for escaping
        state.phase = "town"
        commitCrime("trespassing")  -- Escaping counts as trespassing
    else
        log("Escape failed! Jail time increased.", {0.9, 0.3, 0.3})
        state.player.jailTimeRemaining = math.floor(state.player.jailTimeRemaining * 1.5)
        state.player.karma = math.max(-100, state.player.karma - 10)
    end
end

-- ============================================================================
-- FACTION SYSTEM
-- ============================================================================

-- Change reputation with a faction
M.changeFactionRep = function(factionId, amount)
    if not state.player or not state.player.factionRep then
        state.player.factionRep = {}
    end

    local currentRep = state.player.factionRep[factionId] or 0
    local newRep = math.max(-100, math.min(100, currentRep + amount))
    state.player.factionRep[factionId] = newRep

    local faction = FACTIONS[factionId]
    if faction then
        local oldLevel = getReputationLevel(currentRep)
        local newLevel = getReputationLevel(newRep)

        if oldLevel.name ~= newLevel.name then
            log("Reputation with " .. faction.name .. " changed to " .. newLevel.name, newLevel.color)
        end
    end

    -- Update allied/enemy factions
    if faction and faction.allies then
        for _, allyId in ipairs(faction.allies) do
            changeFactionRep(allyId, amount * 0.5)  -- Allies get 50% of rep change
        end
    end
    if faction and faction.enemies then
        for _, enemyId in ipairs(faction.enemies) do
            changeFactionRep(enemyId, -amount * 0.75)  -- Enemies get opposite rep
        end
    end
end

-- Join a faction
M.joinFaction = function(factionId)
    if not state.player then return false end
    local faction = FACTIONS[factionId]
    if not faction then return false end

    -- Check if already joined
    for _, id in ipairs(state.player.joinedFactions) do
        if id == factionId then
            log("You are already a member of " .. faction.name, {0.9, 0.7, 0.3})
            return false
        end
    end

    -- Check requirements
    local reqs = faction.joinRequirements or {}

    if reqs.minKarma and state.player.karma < reqs.minKarma then
        log("Your karma is too low to join " .. faction.name, {0.9, 0.3, 0.3})
        return false
    end

    if reqs.maxKarma and state.player.karma > reqs.maxKarma then
        log("Your karma is too high to join " .. faction.name, {0.9, 0.3, 0.3})
        return false
    end

    if reqs.gold and state.player.gold < reqs.gold then
        log("You need " .. reqs.gold .. " gold to join " .. faction.name, {0.9, 0.3, 0.3})
        return false
    end

    if reqs.enemiesDefeated and (state.stats.enemiesDefeated or 0) < reqs.enemiesDefeated then
        log("You need " .. reqs.enemiesDefeated .. " enemy kills to join", {0.9, 0.3, 0.3})
        return false
    end

    -- Pay gold fee if required
    if reqs.gold then
        state.player.gold = state.player.gold - reqs.gold
        PlayerData.coins = state.player.gold  -- Sync
    end

    -- Join the faction
    table.insert(state.player.joinedFactions, factionId)
    changeFactionRep(factionId, 30)  -- Start with Friendly status
    log("You have joined " .. faction.name .. "!", {0.3, 0.9, 0.3})

    return true
end

-- Get faction benefits for player
M.getFactionBenefits = function()
    local benefits = {}
    if not state.player or not state.player.joinedFactions then return benefits end

    for _, factionId in ipairs(state.player.joinedFactions) do
        local faction = FACTIONS[factionId]
        if faction and faction.benefits then
            for key, value in pairs(faction.benefits) do
                benefits[key] = (benefits[key] or 0) + value
            end
        end
    end

    return benefits
end

-- ============================================================================
-- INVENTORY
-- ============================================================================

-- Get Tavern Quest items from backpack
M.getTQInventory = function()
    local items = {}
    local allItems = Backpack.getAllItems()
    for _, item in ipairs(allItems) do
        -- Include TQ items and general consumables/materials
        if item.def.category and (
            item.def.category:sub(1, 3) == "tq_" or
            item.def.category == "consumable" or
            item.def.category == "potion" or
            item.def.category == "weapon" or
            item.def.category == "armor"
        ) then
            table.insert(items, item)
        end
    end
    return items
end

M.useItem = function(itemIndex)
    local inventory = getTQInventory()
    local item = inventory[itemIndex]
    if not item then return end

    local def = item.def
    local stats = def.baseStats or {}

    -- Potions and consumables
    if def.category == "tq_potion" or def.category == "consumable" or def.category == "potion" then
        if stats.heal then
            state.player.hp = math.min(state.player.maxHP, state.player.hp + stats.heal)
            log("Healed for " .. stats.heal .. " HP!", {0.3, 0.9, 0.3})
        end
        if stats.mana then
            state.player.mana = math.min(state.player.maxMana, state.player.mana + stats.mana)
            log("Restored " .. stats.mana .. " Mana!", {0.3, 0.5, 0.9})
        end
        if stats.manaRestore then
            state.player.mana = math.min(state.player.maxMana, state.player.mana + stats.manaRestore)
            log("Restored " .. stats.manaRestore .. " Mana!", {0.3, 0.5, 0.9})
        end
        if stats.healing then
            state.player.hp = math.min(state.player.maxHP, state.player.hp + stats.healing)
            log("Healed for " .. stats.healing .. " HP!", {0.3, 0.9, 0.3})
        end
        Backpack.removeItem(item.id, 1)
    -- Weapons
    elseif def.category == "tq_weapon" or def.category == "weapon" then
        -- Check class and stat requirements
        local reqs = def.requirements
        if reqs then
            -- Check class requirement
            if reqs.classes then
                local classAllowed = false
                for _, allowedClass in ipairs(reqs.classes) do
                    if state.player.class and state.player.class.id == allowedClass then
                        classAllowed = true
                        break
                    end
                end
                if not classAllowed then
                    log("Cannot equip " .. def.name .. " - wrong class!", {0.9, 0.3, 0.3})
                    return
                end
            end
            -- Check stat requirements
            local statChecks = {"MIGHT", "AGILITY", "VIGOR", "MIND", "SPIRIT", "PRESENCE"}
            for _, statName in ipairs(statChecks) do
                local req = reqs[statName]
                if req and state.player.stats then
                    local val = state.player.stats[statName] or 10
                    if val < req then
                        local displayName = STAT_DEFINITIONS[statName] and STAT_DEFINITIONS[statName].name or statName
                        log("Cannot equip " .. def.name .. " - need " .. req .. " " .. displayName .. "!", {0.9, 0.3, 0.3})
                        return
                    end
                end
            end
        end

        -- Unequip current weapon back to backpack
        if state.player.equipment.weapon then
            local oldWeapon = state.player.equipment.weapon
            if oldWeapon.backpackId then
                Backpack.addItem(oldWeapon.backpackId, 1)
            end
        end
        -- Equip new weapon with all stat bonuses
        state.player.equipment.weapon = {
            name = def.name,
            attack = stats.attack or stats.damage or 5,
            backpackId = item.id,
            weaponType = def.weaponType or "melee",  -- Track weapon type for skill filtering
            range = stats.range or 1,  -- Range for ranged weapons
            -- Stat bonuses
            MIGHT = stats.MIGHT,
            AGILITY = stats.AGILITY,
            VIGOR = stats.VIGOR,
            MIND = stats.MIND,
            SPIRIT = stats.SPIRIT,
            PRESENCE = stats.PRESENCE,
            critBonus = stats.critBonus,
            spellDamage = stats.spellDamage,
            healBonus = stats.healBonus,
            poisonDamage = stats.poisonDamage,
        }
        Backpack.removeItem(item.id, 1)
        calculateStats()
        log("Equipped " .. def.name, {0.8, 0.8, 0.3})
    -- Armor
    elseif def.category == "tq_armor" or def.category == "armor" then
        -- Check class and stat requirements
        local reqs = def.requirements
        if reqs then
            -- Check class requirement
            if reqs.classes then
                local classAllowed = false
                for _, allowedClass in ipairs(reqs.classes) do
                    if state.player.class and state.player.class.id == allowedClass then
                        classAllowed = true
                        break
                    end
                end
                if not classAllowed then
                    log("Cannot equip " .. def.name .. " - wrong class!", {0.9, 0.3, 0.3})
                    return
                end
            end
            -- Check stat requirements
            local statChecks = {"MIGHT", "AGILITY", "VIGOR", "MIND", "SPIRIT", "PRESENCE"}
            for _, statName in ipairs(statChecks) do
                local req = reqs[statName]
                if req and state.player.stats then
                    local val = state.player.stats[statName] or 10
                    if val < req then
                        local displayName = STAT_DEFINITIONS[statName] and STAT_DEFINITIONS[statName].name or statName
                        log("Cannot equip " .. def.name .. " - need " .. req .. " " .. displayName .. "!", {0.9, 0.3, 0.3})
                        return
                    end
                end
            end
        end

        -- Unequip current armor back to backpack
        if state.player.equipment.armor then
            local oldArmor = state.player.equipment.armor
            if oldArmor.backpackId then
                Backpack.addItem(oldArmor.backpackId, 1)
            end
        end
        -- Equip new armor with all stat bonuses
        state.player.equipment.armor = {
            name = def.name,
            defense = stats.defense or 3,
            backpackId = item.id,
            -- Stat bonuses
            MIGHT = stats.MIGHT,
            AGILITY = stats.AGILITY,
            VIGOR = stats.VIGOR,
            MIND = stats.MIND,
            SPIRIT = stats.SPIRIT,
            PRESENCE = stats.PRESENCE,
            dodgeBonus = stats.dodgeBonus,
            bonusMana = stats.bonusMana,
            healBonus = stats.healBonus,
        }
        Backpack.removeItem(item.id, 1)
        calculateStats()
        log("Equipped " .. def.name, {0.8, 0.8, 0.3})
    -- Accessories (rings, amulets, talismans, charms)
    elseif def.category == "tq_accessory" or def.category == "accessory" then
        -- Check stat requirements
        local reqs = def.requirements
        if reqs then
            -- Check class requirement
            if reqs.classes then
                local classAllowed = false
                for _, allowedClass in ipairs(reqs.classes) do
                    if state.player.class and state.player.class.id == allowedClass then
                        classAllowed = true
                        break
                    end
                end
                if not classAllowed then
                    log("Cannot equip " .. def.name .. " - wrong class!", {0.9, 0.3, 0.3})
                    return
                end
            end
            -- Check stat requirements
            local statChecks = {"MIGHT", "AGILITY", "VIGOR", "MIND", "SPIRIT", "PRESENCE"}
            for _, statName in ipairs(statChecks) do
                local req = reqs[statName]
                if req and state.player.stats then
                    local val = state.player.stats[statName] or 10
                    if val < req then
                        local displayName = STAT_DEFINITIONS[statName] and STAT_DEFINITIONS[statName].name or statName
                        log("Cannot equip " .. def.name .. " - need " .. req .. " " .. displayName .. "!", {0.9, 0.3, 0.3})
                        return
                    end
                end
            end
        end

        -- Unequip current accessory back to backpack
        if state.player.equipment.accessory then
            local oldAccessory = state.player.equipment.accessory
            if oldAccessory.backpackId then
                Backpack.addItem(oldAccessory.backpackId, 1)
            end
        end
        -- Equip new accessory with all stat bonuses
        state.player.equipment.accessory = {
            name = def.name,
            backpackId = item.id,
            -- Stat bonuses
            MIGHT = stats.MIGHT,
            AGILITY = stats.AGILITY,
            VIGOR = stats.VIGOR,
            MIND = stats.MIND,
            SPIRIT = stats.SPIRIT,
            PRESENCE = stats.PRESENCE,
            critBonus = stats.critBonus,
            defense = stats.defense,
            healBonus = stats.healBonus,
            stealthBonus = stats.stealthBonus,
        }
        Backpack.removeItem(item.id, 1)
        calculateStats()
        log("Equipped " .. def.name, {0.8, 0.8, 0.3})
    -- Shields
    elseif def.category == "tq_shield" or def.category == "shield" then
        -- Check class and stat requirements
        local reqs = def.requirements
        if reqs then
            -- Check class requirement
            if reqs.classes then
                local classAllowed = false
                for _, allowedClass in ipairs(reqs.classes) do
                    if state.player.class and state.player.class.id == allowedClass then
                        classAllowed = true
                        break
                    end
                end
                if not classAllowed then
                    log("Cannot equip " .. def.name .. " - wrong class!", {0.9, 0.3, 0.3})
                    return
                end
            end
            -- Check stat requirements
            local statChecks = {"MIGHT", "AGILITY", "VIGOR", "MIND", "SPIRIT", "PRESENCE"}
            for _, statName in ipairs(statChecks) do
                local req = reqs[statName]
                if req and state.player.stats then
                    local val = state.player.stats[statName] or 10
                    if val < req then
                        local displayName = STAT_DEFINITIONS[statName] and STAT_DEFINITIONS[statName].name or statName
                        log("Cannot equip " .. def.name .. " - need " .. req .. " " .. displayName .. "!", {0.9, 0.3, 0.3})
                        return
                    end
                end
            end
        end

        -- Unequip current shield back to backpack
        if state.player.equipment.shield then
            local oldShield = state.player.equipment.shield
            if oldShield.backpackId then
                Backpack.addItem(oldShield.backpackId, 1)
            end
        end
        -- Equip new shield with all stat bonuses
        state.player.equipment.shield = {
            name = def.name,
            defense = stats.defense or 2,
            blockChance = stats.blockChance or 10,
            backpackId = item.id,
            -- Stat bonuses
            MIGHT = stats.MIGHT,
            AGILITY = stats.AGILITY,
            VIGOR = stats.VIGOR,
            MIND = stats.MIND,
            SPIRIT = stats.SPIRIT,
            PRESENCE = stats.PRESENCE,
            reflectDamage = stats.reflectDamage,
            bonusMana = stats.bonusMana,
            healBonus = stats.healBonus,
        }
        Backpack.removeItem(item.id, 1)
        calculateStats()
        log("Equipped " .. def.name, {0.8, 0.8, 0.3})
    end
end

-- ============================================================================
-- DEV MODE
-- ============================================================================

M.activateDevMode = function()
    local p = state.player
    if not p then return end

    -- Max out gold
    p.gold = 999999

    -- Max out stats
    if p.stats then
        p.stats.MIGHT = 30
        p.stats.AGILITY = 30
        p.stats.VIGOR = 30
        p.stats.MIND = 30
        p.stats.SPIRIT = 30
        p.stats.PRESENCE = 30
        p.stats.FAITH = 30
    end

    -- Max out skill points
    p.skillPoints = 99

    -- Max out level (and give appropriate XP)
    p.level = 20
    p.xp = 0
    p.xpToLevel = 999999

    -- Recalculate stats (this will set HP/Mana based on new stats)
    calculateStats()

    -- Set HP and Mana to max
    p.hp = p.maxHP
    p.mana = p.maxMana

    -- Mark dev mode as enabled
    state.devModeEnabled = true

    log("", {1, 1, 1})
    log("=== DEV MODE ACTIVATED ===", {1, 0.3, 0.3})
    log("Stats, gold, and skill points maxed!", {0.9, 0.7, 0.3})
    log("Level set to 20", {0.9, 0.7, 0.3})
end

-- Check dev mode password
M.checkDevModePassword = function(password)
    return password == "Helios"
end

return M
