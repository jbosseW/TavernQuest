-- RPG Town - Town/Building management, District, Guild, Underbelly,
-- Companion, Lockpicking/Crime, and Prison systems
-- Extracted from textrpg.lua

local Data = require("rpg_data")

local M = {}

-- Upvalues set by register()
local state
local F

-- Data table aliases from rpg_data
local COMPANION_CLASSES = Data.COMPANION_CLASSES
local LOCKPICK_CONFIG = Data.LOCKPICK_CONFIG
local JAIL_CONFIG = Data.JAIL_CONFIG

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
-- LOCAL DATA TABLES (kept in this module)
-- ============================================================================

-- Main street column (no buildings here, just walkable path)
local TOWN_STREET_COL = 3

-- Horizontal street rows (walkable paths between building rows)
local TOWN_STREET_ROWS = {2, 4, 6, 8, 10}

-- Town grid dimensions (for navigation) - expanded layout with streets
local TOWN_GRID_COLS = 6
local TOWN_GRID_ROWS = 12

-- HIDDEN_TOWN_BUILDINGS is defined as a function to access the state upvalue
-- at call-time (the condition closures reference state).
local HIDDEN_TOWN_BUILDINGS = {
    -- Vampire lair - appears during epidemics (spawns on an empty spot or replaces theater)
    {
        id = "vampire_lair",
        name = "Abandoned Cellar",  -- Disguised name - player won't know it's a lair
        icon = "HOLE",              -- Looks like a dark hole/entrance
        action = "vampire_lair",
        color = {0.2, 0.15, 0.2},   -- Dark purple/black color (subtle hint)
        gridX = 4,                  -- Same position as theater (replaces it when lair exists)
        gridY = 9,
        desc = "An old cellar entrance. Something feels... wrong.",
        hidden = true,              -- Only shows when lair exists
        condition = function()
            if not state or not state.townVampireLairs then return false end
            local currentTown = state.world and state.world.currentTown
            if not currentTown then return false end
            local townId = currentTown.id or currentTown.name
            return state.townVampireLairs[townId] ~= nil
        end,
    },
}

-- Expose these for drawTown in textrpg.lua to reference
M.TOWN_STREET_COL = TOWN_STREET_COL
M.TOWN_STREET_ROWS = TOWN_STREET_ROWS
M.TOWN_GRID_COLS = TOWN_GRID_COLS
M.TOWN_GRID_ROWS = TOWN_GRID_ROWS
M.HIDDEN_TOWN_BUILDINGS = HIDDEN_TOWN_BUILDINGS

-- ============================================================================
-- DYNAMIC TOWN BUILDING ACCESSORS (local helpers)
-- ============================================================================

-- TOWN_BUILDINGS lives in textrpg.lua; access the fallback through F table
local function getTOWN_BUILDINGS()
    if F and F.TOWN_BUILDINGS then
        return F.TOWN_BUILDINGS
    end
    return {}
end

local function getCurrentTownBuildings()
    local town = state and state.world and state.world.currentTown
    if town and town.townBuildings and #town.townBuildings > 0 then
        return town.townBuildings
    end
    return getTOWN_BUILDINGS()
end
-- Export as M method so rpg_draw_world can access it via F table
M.getCurrentTownBuildings = getCurrentTownBuildings

local function getCurrentTownGridCols()
    local town = state and state.world and state.world.currentTown
    if town and town.townGridCols then
        return town.townGridCols
    end
    return TOWN_GRID_COLS
end

local function getCurrentTownGridRows()
    local town = state and state.world and state.world.currentTown
    if town and town.townGridRows then
        return town.townGridRows
    end
    return TOWN_GRID_ROWS
end

local function getCurrentTownStreetCol()
    local town = state and state.world and state.world.currentTown
    if town and town.townStreetCol then
        return town.townStreetCol
    end
    return TOWN_STREET_COL
end

local function getCurrentTownStreetRows()
    local town = state and state.world and state.world.currentTown
    if town and town.townStreetRows then
        return town.townStreetRows
    end
    return TOWN_STREET_ROWS
end

-- Check if a row is a horizontal street (dynamic)
local function isCurrentStreetRow(gridY)
    local rows = getCurrentTownStreetRows()
    for _, row in ipairs(rows) do
        if gridY == row then return true end
    end
    return false
end

-- ============================================================================
-- REGISTRATION
-- ============================================================================

M.F_FUNCTIONS = {
    -- Companion System
    "generateCompanionName",
    "createCompanion",
    "getAvailableCompanions",

    -- Lockpicking
    "attemptLockpick",

    -- District System
    "enterDistrict",
    "getDistrictOptions",
    "handleDistrictAction",

    -- Guild Hall System
    "enterGuildHall",
    "getGuildHallOptions",
    "checkGuildRequirements",
    "getGuildRank",
    "handleGuildHallAction",

    -- Underbelly System
    "enterUnderbelly",
    "getUnderbellyOptions",
    "handleUnderbellyAction",

    -- Bounty Board & Courier Office
    "openBountyBoard",
    "openCourierOffice",

    -- Prison System
    "startPrisonEscape",
    "completePrisonEscape",
    "skipPrisonEscape",
    "handlePrisonInteraction",

    -- Town/Building Management
    "getCurrentTownBuildings",
    "getVisibleHiddenBuilding",
    "isStreetRow",
    "getTownBuildingAt",
    "getTownBuildingById",
    "initTownPlayerPosition",
    "enterTownBuilding",
    "moveTownPlayer",
    "moveBuildingPlayer",
    "lootBuildingChest",
    "enterCurrentTownBuilding",
}

function M.register(s, f)
    state = s
    F = f
    for _, name in ipairs(M.F_FUNCTIONS) do
        if M[name] then F[name] = M[name] end
    end

    -- Export data tables needed by draw modules (not functions, so not in F_FUNCTIONS)
    F.TOWN_GRID_COLS = TOWN_GRID_COLS
    F.TOWN_GRID_ROWS = TOWN_GRID_ROWS
    F.TOWN_STREET_COL = TOWN_STREET_COL
    F.TOWN_STREET_ROWS = TOWN_STREET_ROWS
    F.HIDDEN_TOWN_BUILDINGS = HIDDEN_TOWN_BUILDINGS
end

-- ============================================================================
-- COMPANION SYSTEM
-- ============================================================================

M.generateCompanionName = function()
    local firstNames = {"Aldric", "Bram", "Cael", "Dorn", "Eld", "Finn", "Grim", "Hawk", "Ivan", "Jax",
        "Kira", "Lyra", "Mira", "Nyx", "Orin", "Pax", "Quinn", "Raven", "Sven", "Talia",
        "Uma", "Vale", "Wren", "Xara", "Yara", "Zev", "Ash", "Blade", "Cole", "Drake"}
    return firstNames[math.random(#firstNames)]
end

-- Create a companion instance from a class template
M.createCompanion = function(classId)
    local class = nil
    for _, c in ipairs(COMPANION_CLASSES) do
        if c.id == classId then
            class = c
            break
        end
    end
    if not class then return nil end

    local compLevel = math.max(1, state.player.level - 1 + math.random(-1, 1))
    -- Companion stats scale with level to stay relevant vs enemies (target ~65% of enemy stats).
    -- Enemy formulas: HP = 25 + level*12, ATK = 4 + level*3, DEF = 2 + level*2.
    -- Companion scaling: HP = base + level*6.5, ATK = base + level*1.8, DEF = base + level*1.1.
    local scaledHP = math.floor(class.baseHP + compLevel * 6.5)
    local scaledAtk = math.floor(class.baseAtk + compLevel * 1.8)
    local scaledDef = math.floor(class.baseDef + compLevel * 1.1)
    local levelBonus = math.floor((state.player.level - 1) * 0.5)
    -- Healer heal amount scales with level: ~12% of a typical companion's max HP
    local scaledHeal = class.healAmount and math.floor(10 + compLevel * 0.8) or nil

    return {
        id = class.id .. "_" .. math.random(10000, 99999),
        name = F.generateCompanionName(),
        class = class,
        level = compLevel,
        maxHP = scaledHP,
        hp = scaledHP,
        attack = scaledAtk,
        defense = scaledDef,
        dailyWage = class.dailyWage + levelBonus,
        hireCost = class.hireCost + levelBonus * 20,
        portrait = class.portrait,
        color = class.color,
        attacks = class.attacks,
        canHeal = class.canHeal,
        healAmount = scaledHeal,
        critBonus = class.critBonus or 0,
        morale = 100,  -- Morale affects performance
        -- Progression system
        xp = 0,
        xpToLevel = math.floor(100 * (1.5 ^ math.max(0, compLevel - 1))),
        skillPoints = 0,
        unlockedSkills = {start = true},
        talents = {},
        pendingTalentSelection = false,
        autoAllocate = true,
    }
end

-- Get list of available companions for hire at tavern
M.getAvailableCompanions = function()
    -- Generate 3-5 random companions available for hire
    local available = {}
    local count = math.random(3, 5)
    local usedClasses = {}

    for i = 1, count do
        -- Pick random class that hasn't been used yet
        local attempts = 0
        local classIdx
        repeat
            classIdx = math.random(#COMPANION_CLASSES)
            attempts = attempts + 1
        until not usedClasses[classIdx] or attempts > 10

        usedClasses[classIdx] = true
        local companion = F.createCompanion(COMPANION_CLASSES[classIdx].id)
        if companion then
            table.insert(available, companion)
        end
    end

    return available
end

-- ============================================================================
-- LOCKPICKING SYSTEM
-- ============================================================================

-- Lockpicking attempt function (called on click/spacebar during minigame)
M.attemptLockpick = function()
    if not state.lockpickState then return end

    local ls = state.lockpickState
    local building = state.lockpickTarget or {id = "home1"}
    local difficulty = LOCKPICK_CONFIG.difficulties[building.id] or LOCKPICK_CONFIG.defaultDifficulty

    -- Check if cursor is in sweet spot
    local inSweetSpot = ls.cursorPos >= ls.sweetSpotStart and
                        ls.cursorPos <= (ls.sweetSpotStart + ls.sweetSpotSize)

    if inSweetSpot then
        -- Success! Check if caught
        local hour = state.timeOfDay or 12
        local isNight = hour >= 22 or hour < 6
        local detectionChance = LOCKPICK_CONFIG.baseDetectionChance
        if isNight then
            detectionChance = detectionChance + LOCKPICK_CONFIG.nightBonus
        end
        detectionChance = math.max(0.05, math.min(0.95, detectionChance))

        if math.random() < detectionChance then
            -- Caught!
            log("The lock clicks open but a guard spots you!", {0.9, 0.4, 0.4})
            state.lockpickState = nil
            state.phase = "jail"
        else
            -- Clean getaway - generate loot
            log("*Click* The lock opens! You slip inside unnoticed.", {0.5, 0.9, 0.5})

            local lootTable = JAIL_CONFIG.lootTables[building.id] or JAIL_CONFIG.defaultLoot
            local goldRange = lootTable.gold
            local goldFound = math.random(goldRange[1], goldRange[2])

            -- Pick 1-2 random items from the loot table
            local itemsFound = {}
            if lootTable.items and #lootTable.items > 0 then
                local numItems = math.random(1, math.min(2, #lootTable.items))
                local availableItems = {unpack(lootTable.items)}  -- Copy
                for i = 1, numItems do
                    if #availableItems > 0 then
                        local idx = math.random(#availableItems)
                        table.insert(itemsFound, availableItems[idx])
                        table.remove(availableItems, idx)
                    end
                end
            end

            -- Pick 1-2 random notes/books
            local notesFound = {}
            if lootTable.notes and #lootTable.notes > 0 then
                local numNotes = math.random(1, math.min(2, #lootTable.notes))
                local availableNotes = {unpack(lootTable.notes)}
                for i = 1, numNotes do
                    if #availableNotes > 0 then
                        local idx = math.random(#availableNotes)
                        table.insert(notesFound, availableNotes[idx])
                        table.remove(availableNotes, idx)
                    end
                end
            end

            -- Combine items and notes
            for _, note in ipairs(notesFound) do
                table.insert(itemsFound, note)
            end

            -- Award immediate loot (gold + some items)
            state.player.gold = state.player.gold + goldFound

            -- Add items to backpack
            local Backpack = require("backpack")
            for _, item in ipairs(itemsFound) do
                Backpack.addItem(item, 1)
            end

            -- Mark building as broken into
            local town = state.world and state.world.currentTown
            if town then
                if not town.brokenIntoBuildings then
                    town.brokenIntoBuildings = {}
                end
                town.brokenIntoBuildings[building.id] = {
                    chestsRemaining = lootTable.chests or 1,
                    timestamp = state.daysPassed or 0
                }
            end

            state.burglaryLoot = {
                gold = goldFound,
                items = itemsFound,
                notes = notesFound
            }

            state.lockpickState = nil
            state.phase = "burglary_success"
            if F and F.save then F.save() end
        end
    else
        -- Failed attempt
        ls.attempts = ls.attempts - 1

        if ls.attempts <= 0 then
            -- Lock jammed, check if caught
            log("The pick snaps! The lock is jammed.", {0.9, 0.5, 0.4})

            local hour = state.timeOfDay or 12
            local isNight = hour >= 22 or hour < 6
            local detectionChance = LOCKPICK_CONFIG.baseDetectionChance + 0.2  -- Higher chance on failure
            if isNight then
                detectionChance = detectionChance + LOCKPICK_CONFIG.nightBonus
            end

            if math.random() < detectionChance then
                log("A patrol heard the noise and found you!", {0.9, 0.3, 0.3})
                state.lockpickState = nil
                state.phase = "jail"
            else
                log("You slip away before anyone notices.", {0.7, 0.7, 0.5})
                state.lockpickState = nil
                state.lockpickTarget = nil
                state.phase = "town"
            end
        else
            -- Missed but can try again
            log("*Click* Missed the tumbler. " .. ls.attempts .. " attempts left.", {0.8, 0.6, 0.4})
            -- Move sweet spot for next attempt (makes it harder)
            ls.sweetSpotStart = math.random() * (1 - ls.sweetSpotSize)
        end
    end
end

-- ============================================================================
-- DISTRICT SYSTEM
-- ============================================================================

M.enterDistrict = function(districtId)
    local TownGenModule = require("towngen")
    local districtDef = TownGenModule.DISTRICT_DEFINITIONS[districtId]
    if not districtDef then
        log("That district is not accessible.", {0.7, 0.5, 0.3})
        return
    end

    state.currentDistrict = {
        id = districtId,
        def = districtDef,
        visited = true,
        encounterCooldown = 0,
    }
    state.phase = "district"
    log("You enter " .. districtDef.name .. ".", {0.7, 0.8, 0.9})
    log(districtDef.description, {0.6, 0.6, 0.7})
end

M.getDistrictOptions = function()
    if not state.currentDistrict or not state.currentDistrict.def then return {} end
    local district = state.currentDistrict.def
    local opts = {}

    -- Explore option (chance for encounter)
    table.insert(opts, {text = "Explore the " .. district.name, action = "district_explore"})

    -- Talk to locals
    table.insert(opts, {text = "Talk to locals", action = "district_talk"})

    -- District-specific shops (if any)
    if district.id == "market" then
        table.insert(opts, {text = "Browse the market stalls", action = "district_shop"})
    elseif district.id == "slums" then
        table.insert(opts, {text = "Look for the black market", action = "district_black_market"})
    elseif district.id == "artisan" then
        table.insert(opts, {text = "Commission craftwork", action = "district_craft"})
    elseif district.id == "entertainment" then
        table.insert(opts, {text = "Watch a performance (5g)", action = "district_performance"})
        table.insert(opts, {text = "Try your luck gambling (10g)", action = "district_gamble"})
    elseif district.id == "temple" then
        table.insert(opts, {text = "Seek a blessing (10g)", action = "district_blessing"})
        table.insert(opts, {text = "Pray at the shrine", action = "district_pray"})
    elseif district.id == "harbor" then
        table.insert(opts, {text = "Check the docks for work", action = "district_dock_work"})
    elseif district.id == "scholars" then
        table.insert(opts, {text = "Study at the library", action = "district_study"})
    elseif district.id == "military" then
        table.insert(opts, {text = "Challenge the training dummies", action = "district_train"})
    end

    -- Leave district
    table.insert(opts, {text = "Return to the city", action = "district_leave"})

    return opts
end

M.handleDistrictAction = function(action)
    if not state.currentDistrict or not state.currentDistrict.def then return end
    local district = state.currentDistrict.def

    if action == "district_explore" then
        -- Random encounter based on district type
        local encounters = district.encounters or {}
        if #encounters > 0 and math.random() < 0.6 then
            local encounter = encounters[math.random(#encounters)]
            -- Dangerous districts may trigger combat
            if district.dangerLevel >= 3 and math.random() < 0.4 then
                log("You are ambushed in " .. district.name .. "!", {0.9, 0.3, 0.3})
                -- Generate a combat encounter
                local enemyLevel = (state.player.level or 1) + math.random(-1, district.dangerLevel)
                local enemyNames = {"Street Thug", "Desperate Brigand", "Cutpurse", "Violent Drunk", "Gang Enforcer"}
                log("A " .. enemyNames[math.random(#enemyNames)] .. " attacks you!", {0.9, 0.4, 0.3})
            else
                log(encounter, {0.7, 0.7, 0.8})
            end
        else
            local ambientTexts = {
                "You wander through " .. district.name .. " taking in the sights.",
                "The atmosphere here is " .. (district.atmosphere or "unremarkable") .. ".",
                "You explore the winding streets and alleys of " .. district.name .. ".",
                "Nothing unusual catches your eye, but you learn the layout a bit better.",
            }
            log(ambientTexts[math.random(#ambientTexts)], {0.6, 0.6, 0.7})
        end

        -- Small chance to find loot
        if math.random() < 0.15 then
            local loot = district.lootTable or {}
            if #loot > 0 then
                local found = loot[math.random(#loot)]
                log("You find something: " .. found, {0.8, 0.8, 0.3})
            end
        end

    elseif action == "district_talk" then
        local npcTypes = district.npcs or {"commoner"}
        local npc = npcTypes[math.random(#npcTypes)]
        local rumors = {
            "I heard strange noises from the sewers last night...",
            "The guilds are always recruiting, if you know where to look.",
            "Watch your coin purse in the slums. Thieves everywhere.",
            "There is work at the bounty board if you have the stomach for it.",
            "A courier arrived this morning with urgent news. Something is happening.",
            "The nobles are throwing a grand feast. Security will be tight.",
            "I heard the catacombs beneath the city are haunted.",
            "There is a hidden entrance to the smuggler tunnels, or so they say.",
        }
        log("A " .. npc .. " tells you: \"" .. rumors[math.random(#rumors)] .. "\"", {0.6, 0.7, 0.6})

    elseif action == "district_performance" then
        if state.player.gold >= 5 then
            state.player.gold = state.player.gold - 5
            log("You enjoy a wonderful performance. The artistry lifts your spirits.", {0.7, 0.6, 0.8})
            -- Small morale/stamina boost
        else
            log("You cannot afford the show.", {0.7, 0.5, 0.3})
        end

    elseif action == "district_gamble" then
        if state.player.gold >= 10 then
            state.player.gold = state.player.gold - 10
            local roll = math.random(1, 100)
            if roll <= 40 then
                local winnings = math.random(15, 30)
                state.player.gold = state.player.gold + winnings
                log("Lady luck smiles! You win " .. winnings .. " gold!", {0.8, 0.8, 0.3})
            elseif roll <= 70 then
                log("You break even. Better luck next time.", {0.6, 0.6, 0.6})
                state.player.gold = state.player.gold + 10
            else
                log("You lose your wager. The house always wins.", {0.7, 0.4, 0.3})
            end
        else
            log("You cannot afford to gamble.", {0.7, 0.5, 0.3})
        end

    elseif action == "district_blessing" then
        if state.player.gold >= 10 then
            state.player.gold = state.player.gold - 10
            local mhp = state.player.maxHp or state.player.maxHP or 100
            state.player.hp = math.min(mhp, state.player.hp + math.floor(mhp * 0.25))
            log("The priest blesses you. You feel rejuvenated. (+25% HP)", {0.8, 0.8, 0.5})
        else
            log("You cannot afford the offering.", {0.7, 0.5, 0.3})
        end

    elseif action == "district_pray" then
        log("You kneel in quiet prayer. A sense of peace washes over you.", {0.7, 0.7, 0.8})
        state.player.karma = math.min(100, (state.player.karma or 0) + 1)

    elseif action == "district_study" then
        log("You spend time studying in the library. You feel a bit wiser.", {0.6, 0.7, 0.8})
        -- Small XP boost
        local xpGain = math.floor(10 + (state.player.level or 1) * 3)
        state.player.xp = (state.player.xp or 0) + xpGain
        log("Gained " .. xpGain .. " XP from studying.", {0.5, 0.8, 0.5})

    elseif action == "district_train" then
        log("You train at the military grounds. Your combat skills improve slightly.", {0.7, 0.6, 0.5})
        local xpGain = math.floor(15 + (state.player.level or 1) * 4)
        state.player.xp = (state.player.xp or 0) + xpGain
        log("Gained " .. xpGain .. " XP from training.", {0.5, 0.8, 0.5})

    elseif action == "district_leave" then
        log("You return to the main city.", {0.6, 0.6, 0.7})
        state.currentDistrict = nil
        state.phase = "town"
    end
end

-- ============================================================================
-- GUILD HALL SYSTEM
-- ============================================================================

M.enterGuildHall = function(guildId)
    local TownGenModule = require("towngen")
    local guildData = TownGenModule.GUILD_DATA[guildId]
    if not guildData then
        log("The guild hall is closed.", {0.7, 0.5, 0.3})
        return
    end

    state.currentGuildHall = {
        id = guildId,
        data = guildData,
    }
    state.phase = "guild_hall"
    log("You enter " .. guildData.name .. ".", {0.7, 0.8, 0.9})
    log(guildData.description, {0.6, 0.6, 0.7})
    log("\"" .. guildData.motto .. "\"", {0.7, 0.7, 0.5})
end

M.getGuildHallOptions = function()
    if not state.currentGuildHall or not state.currentGuildHall.data then return {} end
    local guild = state.currentGuildHall.data
    local opts = {}
    local playerGuilds = state.player.guilds or {}
    local isMember = playerGuilds[guild.id] ~= nil

    if isMember then
        local memberData = playerGuilds[guild.id]
        local currentRank = F.getGuildRank(guild.id)
        table.insert(opts, {text = "View rank: " .. (currentRank and currentRank.name or "Unknown") .. " (Rep: " .. (memberData.reputation or 0) .. ")", action = "guild_status"})
        table.insert(opts, {text = "Take a guild quest", action = "guild_quest"})
        table.insert(opts, {text = "View guild benefits", action = "guild_benefits"})
    else
        table.insert(opts, {text = "Ask about joining", action = "guild_join_info"})
        -- Check if player meets requirements
        local meetsReqs, reason = F.checkGuildRequirements(guild)
        if meetsReqs then
            table.insert(opts, {text = "Join " .. guild.name, action = "guild_join", color = {0.4, 1.0, 0.4}})
        else
            table.insert(opts, {text = "Join " .. guild.name .. " (" .. reason .. ")", action = "guild_join_fail", color = {0.6, 0.6, 0.6}})
        end
    end

    table.insert(opts, {text = "Leave guild hall", action = "guild_leave"})
    return opts
end

M.checkGuildRequirements = function(guild)
    local reqs = guild.joinRequirements or {}
    if reqs.minLevel and (state.player.level or 1) < reqs.minLevel then
        return false, "Need level " .. reqs.minLevel
    end
    if reqs.minKarma and (state.player.karma or 0) < reqs.minKarma then
        return false, "Karma too low"
    end
    if reqs.maxKarma and (state.player.karma or 0) > reqs.maxKarma then
        return false, "Karma too high"
    end
    if reqs.minGold and (state.player.gold or 0) < reqs.minGold then
        return false, "Need " .. reqs.minGold .. " gold"
    end
    return true, nil
end

M.getGuildRank = function(guildId)
    local TownGenModule = require("towngen")
    local guildData = TownGenModule.GUILD_DATA[guildId]
    if not guildData then return nil end
    local playerGuilds = state.player.guilds or {}
    local memberData = playerGuilds[guildId]
    if not memberData then return nil end

    local currentRank = guildData.ranks[1]
    for _, rank in ipairs(guildData.ranks) do
        if (memberData.reputation or 0) >= rank.minRep then
            currentRank = rank
        end
    end
    return currentRank
end

M.handleGuildHallAction = function(action)
    if not state.currentGuildHall or not state.currentGuildHall.data then return end
    local guild = state.currentGuildHall.data

    if action == "guild_join" then
        state.player.guilds = state.player.guilds or {}
        state.player.guilds[guild.id] = {
            reputation = 0,
            joinDate = state.world.gameTime or 0,
            questsCompleted = 0,
        }
        log("You have joined " .. guild.name .. "! Welcome, " .. guild.ranks[1].name .. ".", {0.4, 1.0, 0.4})

    elseif action == "guild_join_info" then
        log("To join " .. guild.name .. ", you must meet certain requirements.", {0.7, 0.7, 0.8})
        local reqs = guild.joinRequirements or {}
        if reqs.minLevel then log("  - Minimum level: " .. reqs.minLevel, {0.6, 0.6, 0.7}) end
        if reqs.minKarma then log("  - Minimum karma: " .. reqs.minKarma, {0.6, 0.6, 0.7}) end
        if reqs.maxKarma then log("  - Maximum karma: " .. reqs.maxKarma, {0.6, 0.6, 0.7}) end
        if reqs.minGold then log("  - Joining fee: " .. reqs.minGold .. " gold", {0.6, 0.6, 0.7}) end

    elseif action == "guild_join_fail" then
        log("You do not meet the requirements to join this guild.", {0.7, 0.5, 0.3})

    elseif action == "guild_quest" then
        -- Generate a guild-specific quest
        local questTypes = guild.questTypes or {"kill"}
        local questType = questTypes[math.random(#questTypes)]
        local prof = {questTypes = {questType}}
        local quest = F.generateQuest(guild.name, prof, state.player.level)
        quest.guildId = guild.id
        quest.isGuildQuest = true
        quest.compassTarget = true

        state.player.quests = state.player.quests or {}
        table.insert(state.player.quests, quest)
        quest.accepted = true
        log("New guild quest: " .. quest.name, {0.9, 0.8, 0.3})
        log(quest.desc, {0.7, 0.7, 0.8})

    elseif action == "guild_status" then
        local memberData = state.player.guilds[guild.id]
        local rank = F.getGuildRank(guild.id)
        log("Guild: " .. guild.name, {0.7, 0.8, 0.9})
        log("Rank: " .. (rank and rank.name or "Unknown"), {0.8, 0.8, 0.3})
        log("Reputation: " .. (memberData.reputation or 0) .. "/100", {0.6, 0.6, 0.7})
        log("Quests completed: " .. (memberData.questsCompleted or 0), {0.6, 0.6, 0.7})

    elseif action == "guild_benefits" then
        local rank = F.getGuildRank(guild.id)
        if rank and rank.benefits then
            log("Current rank benefits:", {0.7, 0.8, 0.9})
            for k, v in pairs(rank.benefits) do
                if type(v) == "number" then
                    local pct = v * 100
                    log("  " .. k .. ": +" .. string.format("%.0f%%", pct), {0.5, 0.8, 0.5})
                end
            end
        end

    elseif action == "guild_leave" then
        state.currentGuildHall = nil
        state.phase = "town"
        log("You leave the guild hall.", {0.6, 0.6, 0.7})
    end
end

-- ============================================================================
-- UNDERBELLY EXPLORATION SYSTEM
-- ============================================================================

M.enterUnderbelly = function(underbellyType)
    local TownGenModule = require("towngen")
    local underbellyDef = TownGenModule.UNDERBELLY_TYPES[underbellyType]
    if not underbellyDef then
        log("The entrance is sealed.", {0.7, 0.5, 0.3})
        return
    end

    local floors = math.random(underbellyDef.floors.min, underbellyDef.floors.max)
    state.currentUnderbelly = {
        type = underbellyType,
        def = underbellyDef,
        floor = 1,
        maxFloors = floors,
        explored = {},
        enemiesDefeated = 0,
        lootFound = {},
        bossDefeated = false,
    }
    state.underbellyFloor = 1
    state.phase = "underbelly"
    log("You descend into " .. underbellyDef.name .. ".", {0.7, 0.5, 0.4})
    log(underbellyDef.description, {0.6, 0.6, 0.7})
    log("This area has " .. floors .. " levels to explore.", {0.5, 0.5, 0.6})
end

M.getUnderbellyOptions = function()
    if not state.currentUnderbelly or not state.currentUnderbelly.def then return {} end
    local ub = state.currentUnderbelly
    local def = ub.def
    local opts = {}

    -- Explore current floor
    table.insert(opts, {text = "Explore (Floor " .. ub.floor .. "/" .. ub.maxFloors .. ")", action = "ub_explore"})

    -- Go deeper (if not on last floor and current floor explored enough)
    if ub.floor < ub.maxFloors then
        table.insert(opts, {text = "Descend deeper", action = "ub_descend"})
    end

    -- Go up
    if ub.floor > 1 then
        table.insert(opts, {text = "Go up a level", action = "ub_ascend"})
    end

    -- Boss fight (only on last floor, if not defeated)
    if ub.floor == ub.maxFloors and not ub.bossDefeated then
        table.insert(opts, {text = "Challenge the boss", action = "ub_boss", color = {0.9, 0.3, 0.3}})
    end

    -- Search for loot
    table.insert(opts, {text = "Search for hidden caches", action = "ub_search"})

    -- Return to surface
    table.insert(opts, {text = "Return to the surface", action = "ub_leave"})

    return opts
end

M.handleUnderbellyAction = function(action)
    if not state.currentUnderbelly or not state.currentUnderbelly.def then return end
    local ub = state.currentUnderbelly
    local def = ub.def

    if action == "ub_explore" then
        -- Random encounter or atmospheric text
        local encounters = def.encounters or {}
        local roll = math.random(1, 100)

        if roll <= 45 then
            -- Combat encounter
            local enemies = def.enemies or {}
            if #enemies > 0 then
                local enemy = enemies[math.random(#enemies)]
                local scaledEnemy = {
                    name = enemy.name,
                    hp = math.floor(enemy.hp * (1 + (state.player.level or 1) * 0.1)),
                    maxHp = math.floor(enemy.hp * (1 + (state.player.level or 1) * 0.1)),
                    attack = math.floor(enemy.attack * (1 + (state.player.level or 1) * 0.08)),
                    xp = math.floor(enemy.xp * (1 + (state.player.level or 1) * 0.15)),
                    gold = enemy.gold + math.random(0, state.player.level or 1),
                }
                log("A " .. scaledEnemy.name .. " emerges from the darkness!", {0.9, 0.4, 0.3})
                log("HP: " .. scaledEnemy.hp .. " | ATK: " .. scaledEnemy.attack, {0.7, 0.5, 0.4})

                -- Simplified combat: auto-resolve
                local playerDmg = math.max(1, (state.player.attack or 10) - math.floor(scaledEnemy.attack * 0.3))
                local enemyDmg = math.max(1, scaledEnemy.attack - math.floor((state.player.defense or 5) * 0.5))
                local rounds = math.ceil(scaledEnemy.hp / playerDmg)
                local damageTaken = enemyDmg * math.max(1, rounds - 1)

                state.player.hp = state.player.hp - damageTaken
                if state.player.hp <= 0 then
                    log("You are defeated! You flee to the surface badly wounded.", {0.9, 0.2, 0.2})
                    state.player.hp = 1
                    state.currentUnderbelly = nil
                    state.phase = "town"
                    return
                end

                state.player.xp = (state.player.xp or 0) + scaledEnemy.xp
                state.player.gold = (state.player.gold or 0) + scaledEnemy.gold
                ub.enemiesDefeated = ub.enemiesDefeated + 1
                log("You defeat the " .. scaledEnemy.name .. "! (+" .. scaledEnemy.xp .. " XP, +" .. scaledEnemy.gold .. "g)", {0.5, 0.8, 0.5})
                log("You took " .. damageTaken .. " damage. HP: " .. state.player.hp .. "/" .. (state.player.maxHp or state.player.maxHP or 100), {0.7, 0.6, 0.4})
            end
        elseif roll <= 75 then
            -- Atmospheric encounter
            if #encounters > 0 then
                log(encounters[math.random(#encounters)], {0.6, 0.6, 0.7})
            end
        else
            -- Find some gold or items
            local goldFound = math.random(5, 20 + (state.player.level or 1) * 3)
            state.player.gold = (state.player.gold or 0) + goldFound
            log("You find " .. goldFound .. " gold scattered on the ground.", {0.8, 0.8, 0.3})
        end

    elseif action == "ub_descend" then
        ub.floor = ub.floor + 1
        state.underbellyFloor = ub.floor
        log("You descend to level " .. ub.floor .. " of " .. def.name .. ".", {0.6, 0.5, 0.5})
        log("The air grows colder and the darkness thicker.", {0.5, 0.5, 0.6})

    elseif action == "ub_ascend" then
        ub.floor = ub.floor - 1
        state.underbellyFloor = ub.floor
        log("You climb back to level " .. ub.floor .. ".", {0.6, 0.6, 0.7})

    elseif action == "ub_boss" then
        -- Boss fight!
        local bosses = def.bosses or {}
        if #bosses > 0 then
            local boss = bosses[math.random(#bosses)]
            local scaledBoss = {
                name = boss.name,
                hp = math.floor(boss.hp * (1 + (state.player.level or 1) * 0.12)),
                attack = math.floor(boss.attack * (1 + (state.player.level or 1) * 0.1)),
                xp = math.floor(boss.xp * (1 + (state.player.level or 1) * 0.2)),
                gold = boss.gold + math.random(0, state.player.level * 5),
                drops = boss.drops or {},
            }
            log("BOSS BATTLE: " .. scaledBoss.name .. "!", {1.0, 0.3, 0.3})
            log("HP: " .. scaledBoss.hp .. " | ATK: " .. scaledBoss.attack, {0.9, 0.5, 0.4})

            -- Boss combat (simplified auto-resolve, tougher than normal)
            local playerDmg = math.max(1, (state.player.attack or 10) - math.floor(scaledBoss.attack * 0.2))
            local bossDmg = math.max(1, scaledBoss.attack - math.floor((state.player.defense or 5) * 0.4))
            local rounds = math.ceil(scaledBoss.hp / playerDmg)
            local damageTaken = bossDmg * math.max(1, rounds - 1)

            state.player.hp = state.player.hp - damageTaken
            if state.player.hp <= 0 then
                log("The " .. scaledBoss.name .. " defeats you! You barely escape alive.", {0.9, 0.2, 0.2})
                state.player.hp = 1
                state.currentUnderbelly = nil
                state.phase = "town"
                return
            end

            ub.bossDefeated = true
            state.player.xp = (state.player.xp or 0) + scaledBoss.xp
            state.player.gold = (state.player.gold or 0) + scaledBoss.gold
            log("You defeated " .. scaledBoss.name .. "!", {1.0, 0.85, 0.3})
            log("Rewards: +" .. scaledBoss.xp .. " XP, +" .. scaledBoss.gold .. " gold", {0.5, 0.9, 0.5})
            if #scaledBoss.drops > 0 then
                for _, drop in ipairs(scaledBoss.drops) do
                    log("Found: " .. drop, {0.9, 0.8, 0.3})
                    table.insert(ub.lootFound, drop)
                end
            end
            log("You took " .. damageTaken .. " damage. HP: " .. state.player.hp .. "/" .. (state.player.maxHp or state.player.maxHP or 100), {0.7, 0.6, 0.4})
        end

    elseif action == "ub_search" then
        local loot = def.loot or {}
        if #loot > 0 and math.random() < 0.35 then
            local found = loot[math.random(#loot)]
            log("You discover a hidden cache: " .. found, {0.8, 0.8, 0.3})
            table.insert(ub.lootFound, found)
        else
            log("You search carefully but find nothing new.", {0.5, 0.5, 0.6})
        end

    elseif action == "ub_leave" then
        log("You climb back to the surface, leaving " .. def.name .. " behind.", {0.6, 0.7, 0.6})
        if ub.enemiesDefeated > 0 then
            log("Enemies defeated: " .. ub.enemiesDefeated, {0.6, 0.6, 0.7})
        end
        if #ub.lootFound > 0 then
            log("Items found: " .. table.concat(ub.lootFound, ", "), {0.7, 0.7, 0.5})
        end
        state.currentUnderbelly = nil
        state.phase = "town"
    end
end

-- ============================================================================
-- BOUNTY BOARD & COURIER OFFICE HANDLERS
-- ============================================================================

M.openBountyBoard = function()
    local town = state.world and state.world.currentTown
    local level = town and town.level or state.player.level or 1
    if not town then return end

    town.bountyBoard = town.bountyBoard or F.generateBountyBoard(level)
    state.phase = "bounty_board"
    log("You examine the bounty board. Wanted posters line the wall.", {0.7, 0.6, 0.4})
end

M.openCourierOffice = function()
    local town = state.world and state.world.currentTown
    local level = town and town.level or state.player.level or 1
    if not town then return end

    town.courierBoard = town.courierBoard or F.generateCourierBoard(level)
    state.phase = "courier_office"
    log("The courier office is busy with dispatchers organizing deliveries.", {0.6, 0.7, 0.7})
end

-- ============================================================================
-- PRISON SYSTEM
-- ============================================================================

M.startPrisonEscape = function()
    if not state.player then return end

    local PrisonEscape = require("prison_escape")
    local Cutscenes = require("cutscenes")

    -- Generate the prison dungeon
    state.prisonEscape = PrisonEscape.generatePrison()
    state.inPrisonEscape = true

    -- Initialize tracking fields that PrisonEscape.init() would normally set
    state.prisonEscape.cuffsEquipped = true
    state.prisonEscape.prisonTutorialStep = 0
    state.prisonEscape.combatReturnPhase = nil

    -- Apply cuffs debuff
    PrisonEscape.applyCuffsDebuff(state.player)

    -- Set player to have no starting gear or gold
    state.player.gold = 0
    PlayerData.coins = 0

    -- Clear any starting equipment (player starts with bare fists)
    state.player.equipment = state.player.equipment or {}
    state.player.equipment.weapon = nil
    state.player.equipment.armor = nil
    state.player.equipment.shield = nil

    -- Set the prison dungeon as the active dungeon (reuse existing dungeon system)
    state.dungeon = {
        name = state.prisonEscape.name,
        dungeonType = "prison",
        dungeonTypeName = "Prison",
        dungeonColor = {0.35, 0.35, 0.42},
        floors = state.prisonEscape.floors,
        currentFloor = 1,
        totalFloors = state.prisonEscape.totalFloors,
        playerX = state.prisonEscape.playerX,
        playerY = state.prisonEscape.playerY,
        worldX = 55,  -- The Sunken Ledger's position
        worldY = 48,
        cleared = false,
        -- Prison-specific data
        isPrison = true,
        prisonData = state.prisonEscape,
    }
    state.inDungeon = true
    state.phase = "dungeon"

    -- Log the start
    log("You awaken in dim light. Cold stone. Iron cuffs. The Sunken Ledger.", {0.7, 0.5, 0.5})
    log("Your wrists burn under heavy iron cuffs. All stats reduced.", {0.9, 0.4, 0.4})
    log("Search your cell for anything useful. SPACE to interact.", {0.6, 0.8, 0.6})

    -- Trigger intro cutscene
    Cutscenes.queue("intro_wake_up", function()
        -- After cutscene, player is in the dungeon
        log("[Objective] Lockpick your cuffs and escape your cell.", {1, 0.9, 0.4})
        log("[Objective] Find allies among the other prisoners.", {1, 0.9, 0.4})
    end)
end

-- Complete the prison escape (called when player exits The Sunken Ledger)
M.completePrisonEscape = function()
    if not state.inPrisonEscape then return end

    local PrisonEscape = require("prison_escape")
    local Cutscenes = require("cutscenes")

    state.inPrisonEscape = false

    -- Transfer prison inventory to main backpack
    if state.prisonEscape then
        PrisonEscape.transferInventoryToBackpack(state.prisonEscape)
    end

    -- Give player some starting gold from the escape
    state.player.gold = 25
    PlayerData.coins = 25

    -- Remove cuffs if still on (should be removed already)
    if state.player.prisonCuffs then
        PrisonEscape.removeCuffsDebuff(state.player)
    end

    -- Add recruited allies to party
    if not state.player.party then state.player.party = {} end
    local addedAllies = {}

    -- Track allies already in player.party (synced during prison recruitment)
    for _, existingAlly in ipairs(state.player.party) do
        if existingAlly.id then
            addedAllies[existingAlly.id] = true
        end
    end

    -- Primary source: prison.party (populated immediately on recruitment)
    if state.prisonEscape and state.prisonEscape.party then
        for _, partyAlly in ipairs(state.prisonEscape.party) do
            if not addedAllies[partyAlly.id] then
                local allyClass = partyAlly.class or "warrior"
                table.insert(state.player.party, {
                    id = partyAlly.id,
                    name = partyAlly.name,
                    race = partyAlly.race,
                    class = type(allyClass) == "table" and allyClass or {
                        id = allyClass,
                        name = allyClass:sub(1,1):upper() .. allyClass:sub(2),
                    },
                    hp = partyAlly.hp or partyAlly.maxHp or partyAlly.maxHP or 50,
                    maxHP = partyAlly.maxHp or partyAlly.maxHP or 50,
                    attack = partyAlly.atk or partyAlly.attack or 10,
                    defense = partyAlly.def or partyAlly.defense or 5,
                    color = partyAlly.color or {0.6, 0.8, 1.0},
                    level = 1,
                    isAlly = true,
                })
                addedAllies[partyAlly.id] = true
                log(partyAlly.name .. " escapes with you!", {0.3, 0.9, 0.5})
            end
        end
    end

    -- Fallback: alliesRecruited dictionary (in case party list was missed)
    if state.prisonEscape and state.prisonEscape.alliesRecruited then
        for allyId, _ in pairs(state.prisonEscape.alliesRecruited) do
            if not addedAllies[allyId] then
                for _, allyDef in ipairs(PrisonEscape.ALLIES) do
                    if allyDef.id == allyId then
                        local allyClass2 = allyDef.class or "warrior"
                        table.insert(state.player.party, {
                            id = allyDef.id,
                            name = allyDef.name,
                            race = allyDef.race,
                            class = type(allyClass2) == "table" and allyClass2 or {
                                id = allyClass2,
                                name = allyClass2:sub(1,1):upper() .. allyClass2:sub(2),
                            },
                            hp = allyDef.maxHp or allyDef.maxHP or 50,
                            maxHP = allyDef.maxHp or allyDef.maxHP or 50,
                            attack = allyDef.atk or allyDef.attack or 10,
                            defense = allyDef.def or allyDef.defense or 5,
                            color = allyDef.color or {0.6, 0.8, 1.0},
                            level = 1,
                            isAlly = true,
                        })
                        addedAllies[allyDef.id] = true
                        log(allyDef.name .. " escapes with you!", {0.3, 0.9, 0.5})
                        break
                    end
                end
            end
        end
    end

    -- Trigger escape and thieves guild cutscenes
    Cutscenes.queue("escape_surface")
    Cutscenes.queue("meet_thieves_guild", function()
        -- After thieves guild cutscene, transition to normal game
        state.inDungeon = false
        state.dungeon = nil
        state.prisonEscape = nil
        state.phase = "map"

        -- Ensure player has valid world position - place at Ironshore (harbour near prison)
        if state.world then
            if not state.world.playerX or not state.world.playerY then
                state.world.playerX = 53
                state.world.playerY = 49
            end
        end

        -- Set player bounty (they are escaped prisoners)
        state.player.bounty = 500
        state.player.crimes = state.player.crimes or {}
        table.insert(state.player.crimes, {
            type = "prison_escape",
            description = "Escaped from The Sunken Ledger",
            bounty = 500,
            dayCommitted = state.daysPassed,
        })

        log("You have escaped The Sunken Ledger!", {0.3, 0.9, 0.3})
        log("The Veiled Hand has given you a new identity, but your bounty remains.", {0.9, 0.7, 0.3})
        log("Clear your name or live as a fugitive.", {0.8, 0.6, 0.4})
        log("Welcome to " .. (state.world.currentTown and state.world.currentTown.name or "the surface") .. ".", {0.5, 0.8, 0.5})

        if F and F.save then F.save() end
    end)
end

-- Skip the prison escape entirely (called from character creation "Skip Tutorial" button)
M.skipPrisonEscape = function()
    -- Add all 4 prison allies to party
    if not state.player.party then state.player.party = {} end

    local allies = {
        {
            id = "grimjaw",
            name = "Grimjaw",
            race = "orc",
            class = {id = "warrior", name = "Warrior"},
            hp = 50, maxHP = 50,
            attack = 12, defense = 8,
            color = {0.6, 0.8, 0.3},
            level = 1,
            isAlly = true,
        },
        {
            id = "sera_voss",
            name = "Sera Voss",
            race = "human",
            class = {id = "rogue", name = "Rogue"},
            hp = 35, maxHP = 35,
            attack = 10, defense = 5,
            color = {0.8, 0.5, 0.8},
            level = 1,
            isAlly = true,
        },
        {
            id = "brother_aldric",
            name = "Brother Aldric",
            race = "human",
            class = {id = "cleric", name = "Cleric"},
            hp = 40, maxHP = 40,
            attack = 6, defense = 6,
            color = {1.0, 0.9, 0.5},
            level = 1,
            isAlly = true,
        },
        {
            id = "nyx",
            name = "Nyx",
            race = "goblin",
            class = {id = "mage", name = "Mage"},
            hp = 25, maxHP = 25,
            attack = 14, defense = 3,
            color = {0.4, 0.9, 0.6},
            level = 1,
            isAlly = true,
        },
    }

    for _, ally in ipairs(allies) do
        table.insert(state.player.party, ally)
    end

    -- Set post-prison game state
    state.player.gold = 25
    PlayerData.coins = 25
    state.player.bounty = 500
    state.player.crimes = state.player.crimes or {}
    table.insert(state.player.crimes, {
        type = "prison_escape",
        description = "Escaped from The Sunken Ledger",
        bounty = 500,
        dayCommitted = state.daysPassed or 0,
    })

    state.inPrisonEscape = false
    state.inDungeon = false
    state.dungeon = nil
    state.prisonEscape = nil
    state.phase = "map"

    -- Place player at Ironshore (harbour town near the prison)
    if state.world then
        state.world.playerX = 53
        state.world.playerY = 49

        -- Reveal tiles around spawn position so the map isn't all fog of war
        local WorldGen = require("worldgen")
        if state.world.useWorldGen then
            for dy = -2, 2 do
                for dx = -2, 2 do
                    WorldGen.exploreTile(53 + dx, 49 + dy)
                end
            end
        end
    end

    -- Initialize quest system and add credentials quest
    if F and F.initializeQuestSystem then
        F.initializeQuestSystem()
    elseif not state.quests then
        state.quests = {
            available = {},
            active = {},
            completed = {},
            completedTimestamps = {},
        }
    end

    table.insert(state.quests.active, {
        questId = "skip_tutorial_credentials",
        npcId = nil,
        name = "Obtain Travel Papers",
        description = "The Veiled Hand has contacts in Ironshore who can forge travel papers. Find the guild fence at The Rusty Anchor tavern.",
        type = "delivery",
        objectives = {
            {type = "collect", item = "travel_papers", amount = 1, current = 0, completed = false}
        },
        rewards = {
            gold = 0,
            experience = 50,
            reputation = 0,
        },
        acceptedDay = 0,
    })

    -- Log narrative messages
    log("You escaped The Sunken Ledger with your allies.", {0.3, 0.9, 0.3})
    log("The Veiled Hand has given you a new identity, but your bounty remains.", {0.9, 0.7, 0.3})
    log("You've reached Ironshore, the harbour town near the prison. Seek out the guild contacts here.", {0.5, 0.8, 0.5})

    if F and F.addJournalEvent then
        F.addJournalEvent("milestone", "Escaped The Sunken Ledger and joined the Veiled Hand.", {1, 0.9, 0.5})
    end
end

-- Check prison escape events when player interacts with tiles
M.handlePrisonInteraction = function(tile, x, y)
    if not state.inPrisonEscape or not state.prisonEscape then return false end

    local PrisonEscape = require("prison_escape")
    local Cutscenes = require("cutscenes")
    local prison = state.prisonEscape

    if tile and tile.content then
        -- Scavenge interaction
        if tile.content.type == "scavenge" and not tile.content.searched then
            local item = PrisonEscape.scavengeTile(prison, x, y)
            if item then
                log("Found: " .. item.name .. " - " .. (item.desc or ""), {0.5, 0.9, 0.5})
                return true
            end
        end

        -- Ally interaction
        if tile.content.type == "ally" and tile.content.data and not tile.content.data.recruited then
            local ally = tile.content.data

            -- Recruit the ally immediately (don't depend on cutscene callback)
            ally.recruited = true
            if not prison.alliesRecruited then prison.alliesRecruited = {} end
            prison.alliesRecruited[ally.id] = true

            -- Add to prison escape party for immediate use
            if not prison.party then prison.party = {} end
            local alreadyInParty = false
            for _, p in ipairs(prison.party) do
                if p.id == ally.id then alreadyInParty = true break end
            end
            if not alreadyInParty then
                -- Find full ally definition for stats
                local allyDef = nil
                for _, def in ipairs(PrisonEscape.ALLIES) do
                    if def.id == ally.id then allyDef = def break end
                end
                table.insert(prison.party, {
                    id = ally.id,
                    name = ally.name,
                    race = ally.race or (allyDef and allyDef.race) or "unknown",
                    class = ally.class or (allyDef and allyDef.class) or "unknown",
                    hp = ally.hp or (allyDef and allyDef.maxHp) or 50,
                    maxHp = ally.maxHp or (allyDef and allyDef.maxHp) or 50,
                    atk = ally.atk or (allyDef and allyDef.atk) or 8,
                    def = ally.def or (allyDef and allyDef.def) or 5,
                    isAlly = true,
                })

                -- Also sync to player.party so Party Status screen and combat system can see them
                if not state.player.party then state.player.party = {} end
                local alreadyInPlayerParty = false
                for _, pp in ipairs(state.player.party) do
                    if pp.id == ally.id then alreadyInPlayerParty = true break end
                end
                if not alreadyInPlayerParty then
                    local allyClass = ally.class or (allyDef and allyDef.class) or "warrior"
                    table.insert(state.player.party, {
                        id = ally.id,
                        name = ally.name,
                        race = ally.race or (allyDef and allyDef.race) or "unknown",
                        class = type(allyClass) == "table" and allyClass or {
                            id = type(allyClass) == "string" and allyClass or "warrior",
                            name = type(allyClass) == "string" and (allyClass:sub(1,1):upper() .. allyClass:sub(2)) or "Warrior",
                        },
                        hp = ally.hp or (allyDef and allyDef.maxHp) or 50,
                        maxHP = ally.maxHp or (allyDef and allyDef.maxHp) or 50,
                        attack = ally.atk or (allyDef and allyDef.atk) or 10,
                        defense = ally.def or (allyDef and allyDef.def) or 5,
                        color = (allyDef and allyDef.color) or {0.6, 0.8, 1.0},
                        level = 1,
                        isAlly = true,
                    })
                end
            end

            -- Play cutscene dialogue for flavor, then confirm recruitment
            local cutsceneId = "meet_" .. (ally.id == "sera_voss" and "sera" or
                                           ally.id == "brother_aldric" and "aldric" or
                                           ally.id)
            if Cutscenes.SCENES[cutsceneId] then
                Cutscenes.queue(cutsceneId, function()
                    log(ally.name .. " has joined your escape party!", {0.3, 0.9, 0.5})
                    log(ally.name .. " (" .. (ally.race or "unknown") .. " " .. (ally.class or "unknown") .. ") will fight alongside you.", {0.5, 0.8, 0.7})
                end)
            else
                log(ally.name .. " has joined your escape party!", {0.3, 0.9, 0.5})
                log(ally.name .. " (" .. (ally.race or "unknown") .. " " .. (ally.class or "unknown") .. ") will fight alongside you.", {0.5, 0.8, 0.7})
            end
            return true
        end
    end

    -- Check for cuffs lockpicking opportunity (any tile interaction while cuffs are equipped)
    if prison.cuffsEquipped then
        local hasLockpickSet = false
        local hasImprovTool = false
        local improvToolName = nil
        local improvToolId = nil
        if prison.prisonInventory then
            for _, item in ipairs(prison.prisonInventory) do
                if item.id == "lockpick_set" and (item.qty or 1) > 0 then
                    hasLockpickSet = true
                    break
                elseif (item.id == "bone_fragment" or item.id == "scrap_metal" or item.id == "wire_coil") and (item.qty or 1) > 0 then
                    hasImprovTool = true
                    improvToolName = item.name or item.id
                    improvToolId = item.id
                end
            end
        end

        if hasLockpickSet then
            -- Crafted lockpick: guaranteed success, consume the item
            PrisonEscape.removeCuffsDebuff(state.player)
            prison.cuffsEquipped = false
            -- Consume the lockpick set
            for _, item in ipairs(prison.prisonInventory) do
                if item.id == "lockpick_set" then
                    item.qty = (item.qty or 1) - 1
                    break
                end
            end
            -- Clean up zero-quantity items
            local cleanInv = {}
            for _, item in ipairs(prison.prisonInventory) do
                if item.qty and item.qty > 0 then
                    table.insert(cleanInv, item)
                end
            end
            prison.prisonInventory = cleanInv
            PrisonEscape.completeObjective(prison, "remove_cuffs")
            log("You deftly pick the lock on your cuffs with the improvised lockpick. Freedom!", {0.4, 1.0, 0.4})
            log("[Objective Complete] Lockpick your cuffs", {1, 0.9, 0.4})
            return true
        elseif hasImprovTool then
            -- Raw material: AGILITY-based skill check
            local agility = (state.player.stats and state.player.stats.AGILITY) or 10
            local getStatModifier = F.getStatModifier
            local agilityMod = getStatModifier(agility)
            local roll = math.random(1, 20) + agilityMod
            local dc = 12

            if roll >= dc then
                PrisonEscape.removeCuffsDebuff(state.player)
                prison.cuffsEquipped = false
                -- Consume the improvised tool on success
                for _, item in ipairs(prison.prisonInventory) do
                    if item.id == improvToolId then
                        item.qty = (item.qty or 1) - 1
                        break
                    end
                end
                local cleanInv = {}
                for _, item in ipairs(prison.prisonInventory) do
                    if item.qty and item.qty > 0 then
                        table.insert(cleanInv, item)
                    end
                end
                prison.prisonInventory = cleanInv
                PrisonEscape.completeObjective(prison, "remove_cuffs")
                log("Using the " .. improvToolName .. ", you manage to pick the lock on your cuffs! (Roll: " .. roll .. " vs DC " .. dc .. ")", {0.4, 1.0, 0.4})
                log("[Objective Complete] Lockpick your cuffs", {1, 0.9, 0.4})
                return true
            else
                log("You fumble with the cuffs lock using the " .. improvToolName .. "... (Roll: " .. roll .. " vs DC " .. dc .. ")", {0.8, 0.6, 0.3})
                log("Try again or craft a proper lockpick for a guaranteed result.", {0.7, 0.7, 0.5})
                return true
            end
        else
            log("Your iron cuffs weigh heavily. Find bone fragments, scrap metal, or wire to pick the lock.", {0.7, 0.7, 0.5})
            return true
        end
    end

    -- Check for escape exit (tile.type set by prison generation, or content/roomType fallback)
    if tile and (tile.type == "escape_exit" or (tile.content and tile.content.type == "escape_exit") or (tile.roomType == "escape_exit")) then
        F.completePrisonEscape()
        return true
    end

    return false
end

-- ============================================================================
-- TOWN / BUILDING MANAGEMENT
-- ============================================================================

M.getVisibleHiddenBuilding = function(gridX, gridY)
    for _, building in ipairs(HIDDEN_TOWN_BUILDINGS) do
        if building.gridX == gridX and building.gridY == gridY then
            if building.condition and building.condition() then
                return building
            end
        end
    end
    return nil
end

-- Check if a row is a horizontal street (uses dynamic town data)
M.isStreetRow = function(gridY)
    local town = state and state.world and state.world.currentTown
    local rows = (town and town.townStreetRows) or TOWN_STREET_ROWS
    for _, row in ipairs(rows) do
        if gridY == row then return true end
    end
    return false
end

-- Get building at a grid position (returns nil if empty/path)
M.getTownBuildingAt = function(gridX, gridY)
    -- First check for visible hidden buildings (like vampire lair)
    local hiddenBuilding = F.getVisibleHiddenBuilding(gridX, gridY)
    if hiddenBuilding then
        return hiddenBuilding
    end

    -- Use per-town buildings if available, else static list
    local buildingList = getCurrentTownBuildings()

    -- Then check normal buildings
    for _, building in ipairs(buildingList) do
        if building.wide then
            -- Wide buildings span 2 columns (e.g. gate at 2.5 spans cols 2-3)
            local startCol = math.floor(building.gridX)
            local endCol = math.ceil(building.gridX + 0.5)
            if gridY == building.gridY and gridX >= startCol and gridX <= endCol then
                return building
            end
        else
            if gridX == building.gridX and gridY == building.gridY then
                -- Skip if a hidden building replaced this spot
                if F.getVisibleHiddenBuilding(building.gridX, building.gridY) then
                    return nil
                end
                return building
            end
        end
    end
    return nil
end

-- Get town building by ID
M.getTownBuildingById = function(buildingId)
    -- Check per-town buildings first
    local buildingList = getCurrentTownBuildings()
    for _, building in ipairs(buildingList) do
        if building.id == buildingId then
            return building
        end
    end
    -- Check hidden buildings
    for _, building in ipairs(HIDDEN_TOWN_BUILDINGS) do
        if building.id == buildingId then
            return building
        end
    end
    return nil
end

-- Initialize town player position (at the gate)
M.initTownPlayerPosition = function()
    if not state.townPlayerX or not state.townPlayerY then
        -- Start at the town gate (last row, street column)
        local town = state.world and state.world.currentTown
        local gateRow = (town and town.townGridRows) or TOWN_GRID_ROWS
        local streetCol = (town and town.townStreetCol) or TOWN_STREET_COL
        state.townPlayerX = streetCol
        state.townPlayerY = gateRow
    end
end

-- Handle entering a building based on action
M.enterTownBuilding = function(building)
    local action = building.action

    if action == "shop" then
        state.phase = "shop"
        state.shopType = "general"
        state.shopTitle = "General Store"
    elseif action == "guild_interior" then
        state.phase = "guild_interior"
        log("You enter the Guild Hall. Adventurers gather around quest postings and recruitment tables.", {0.5, 0.4, 0.6})
    elseif action == "stable" then
        state.phase = "stable"
        state.stableTab = "beasts"
    elseif action == "elders" then
        state.phase = "quest_log"
    elseif action == "job_board" then
        state.phase = "job_board"
    elseif action == "stockmarket" then
        -- Check ownership for employee hiring
        local PropertySystem = require("propertysystem")
        local townId = state.world.currentTown and state.world.currentTown.id or "havenbrook"
        PlayerData.currentBuildingOwned = PropertySystem.ownsProperty(townId, "market")
        PlayerData.currentBuildingTownId = townId
        PlayerData.currentBuildingId = "market"
        local StockMarket = require("stockmarket")
        StockMarket.init()
        GameState.current = "stockmarket"
        log("You enter the bustling trading post...", {0.4, 0.5, 0.5})
    elseif action == "npc_list" then
        state.phase = "npc_list"
    elseif action == "tavern_interior" then
        state.phase = "tavern_interior"
        log("You enter the warm tavern. The smell of ale and roasted meat fills the air.", {0.6, 0.5, 0.3})
    elseif action == "map" then
        state.phase = "map"
        -- Reset town player position for next visit
        state.townPlayerX = nil
        state.townPlayerY = nil

        -- Ensure state.player is loaded (in case it was lost)
        if not state.player and PlayerData.textRPG and PlayerData.textRPG.player then
            state.player = PlayerData.textRPG.player
        end

        -- Explore tiles around player when leaving town
        if state.world.useWorldGen then
            local WorldGen = require("worldgen")
            local px, py = state.world.playerX, state.world.playerY
            -- Explore 3x3 area around player
            for dy = -1, 1 do
                for dx = -1, 1 do
                    WorldGen.exploreTile(px + dx, py + dy)
                end
            end
        else
            -- Legacy map system
            local px, py = state.world.playerX, state.world.playerY
            for dy = -1, 1 do
                for dx = -1, 1 do
                    local tx, ty = px + dx, py + dy
                    if state.world.mapData[ty] and state.world.mapData[ty][tx] then
                        state.world.mapData[ty][tx].explored = true
                    end
                end
            end
        end

        log("You leave through the town gate...", {0.6, 0.6, 0.7})
    elseif action == "forge" then
        -- Check ownership for employee hiring
        local PropertySystem = require("propertysystem")
        local townId = state.world.currentTown and state.world.currentTown.id or "havenbrook"
        PlayerData.currentBuildingOwned = PropertySystem.ownsProperty(townId, "forge")
        PlayerData.currentBuildingTownId = townId
        PlayerData.currentBuildingId = "forge"
        local Forge = require("forge")
        Forge.init()
        GameState.current = "forge"
        log("You enter the blacksmith's forge...", {0.7, 0.4, 0.2})
    elseif action == "wizardtower" then
        -- Check ownership for employee hiring
        local PropertySystem = require("propertysystem")
        local townId = state.world.currentTown and state.world.currentTown.id or "havenbrook"
        PlayerData.currentBuildingOwned = PropertySystem.ownsProperty(townId, "wizardtower")
        PlayerData.currentBuildingTownId = townId
        PlayerData.currentBuildingId = "wizardtower"
        local WizardTower = require("wizardtower")
        WizardTower.init()
        GameState.current = "wizardtower"
        log("You climb the wizard tower stairs...", {0.4, 0.3, 0.7})
    elseif action == "alchemist" then
        -- Check ownership for employee hiring
        local PropertySystem = require("propertysystem")
        local townId = state.world.currentTown and state.world.currentTown.id or "havenbrook"
        PlayerData.currentBuildingOwned = PropertySystem.ownsProperty(townId, "alchemist")
        PlayerData.currentBuildingTownId = townId
        PlayerData.currentBuildingId = "alchemist"
        local Alchemist = require("alchemist")
        Alchemist.init()
        GameState.current = "alchemist"
        log("You enter the alchemist's laboratory...", {0.3, 0.6, 0.4})
    elseif action == "fishing" then
        -- Check ownership for employee hiring
        local PropertySystem = require("propertysystem")
        local townId = state.world.currentTown and state.world.currentTown.id or "havenbrook"
        PlayerData.currentBuildingOwned = PropertySystem.ownsProperty(townId, "fishing")
        PlayerData.currentBuildingTownId = townId
        PlayerData.currentBuildingId = "fishing"
        local Fishing = require("fishing")
        Fishing.init()
        GameState.current = "fishing"
        log("Time to cast your line!", {0.3, 0.5, 0.7})
    elseif action == "hunting" then
        -- Check ownership for employee hiring
        local PropertySystem = require("propertysystem")
        local townId = state.world.currentTown and state.world.currentTown.id or "havenbrook"
        PlayerData.currentBuildingOwned = PropertySystem.ownsProperty(townId, "hunting")
        PlayerData.currentBuildingTownId = townId
        PlayerData.currentBuildingId = "hunting"
        local Hunting = require("hunting")
        Hunting.init()
        GameState.current = "hunting"
        log("You enter the hunter's lodge...", {0.5, 0.4, 0.3})
    elseif action == "land_office" then
        -- Enter the Land Office for expansion permits
        state.phase = "land_office"
        state.landOfficeTab = "main"
        log("You enter the Land Office. The Land Commissioner sits behind a desk piled with deeds and maps.", {0.55, 0.5, 0.35})
    elseif action == "locked" then
        -- Offer player choice to attempt lockpicking
        local currentBuilding = F.getTownBuildingAt(state.townPlayerX, state.townPlayerY)
        state.lockpickTarget = currentBuilding
        state.phase = "lockpick_prompt"
        log("This building is locked. You could try to pick the lock...", {0.6, 0.5, 0.4})
    elseif action == "chapel" then
        -- Blessing mechanic - restore some HP/MP for small donation
        if state.player.gold >= 10 then
            state.player.gold = state.player.gold - 10
            local healAmt = math.floor(state.player.maxHP * 0.3)
            local manaAmt = math.floor(state.player.maxMana * 0.3)
            state.player.hp = math.min(state.player.maxHP, state.player.hp + healAmt)
            state.player.mana = math.min(state.player.maxMana, state.player.mana + manaAmt)
            log("You offer 10g and receive a blessing. Restored " .. healAmt .. " HP and " .. manaAmt .. " MP.", {0.8, 0.8, 0.5})
        else
            log("You pray quietly but have no offering to give.", {0.6, 0.6, 0.7})
        end
    elseif action == "building_interior" then
        -- Generic building interior - player can explore, talk to NPCs, find loot
        local currentBuilding = F.getTownBuildingAt(state.townPlayerX, state.townPlayerY)

        -- Initialize town NPCs if not already done
        local town = state.world and state.world.currentTown
        if town then
            F.initializeTownNPCs(town)
        end

        -- Get NPCs present in this building
        local npcsHere = F.getNPCsAtBuilding(currentBuilding.id)

        -- Check if building should be locked (no NPCs and requires NPC)
        local requiresNPC = true -- Most buildings require NPCs to be open
        if currentBuilding.id == "shack" or currentBuilding.id == "farmhouse" then
            requiresNPC = false -- These can be explored even when empty
        end

        -- Check if building was already broken into
        if not town.brokenIntoBuildings then
            town.brokenIntoBuildings = {}
        end
        local alreadyBrokenInto = town.brokenIntoBuildings[currentBuilding.id]

        if #npcsHere == 0 and requiresNPC then
            if alreadyBrokenInto then
                -- Already looted, just explore the empty interior
                log("The lock is broken. The building appears abandoned and looted.", {0.6, 0.6, 0.7})
                -- Continue to enter building as normal (will be empty with no loot)
            else
                -- Locked - offer lockpicking
                state.lockpickTarget = currentBuilding
                state.phase = "lockpick_prompt"
                log("The building is locked. Nobody appears to be here.", {0.8, 0.6, 0.4})
                return
            end
        end

        -- Get building interior map
        local map = F.getBuildingInteriorMap(currentBuilding.id)

        -- Position NPCs in the interior
        for i, npc in ipairs(npcsHere) do
            if i == 1 then
                -- First NPC goes to designated spawn position
                npc.interiorX = map.npcSpawn.x
                npc.interiorY = map.npcSpawn.y
            else
                -- Additional NPCs placed nearby (for multi-NPC buildings)
                npc.interiorX = map.npcSpawn.x + (i - 1)
                npc.interiorY = map.npcSpawn.y
            end
        end

        -- Generate chests if building was broken into
        local chests = {}
        if alreadyBrokenInto and alreadyBrokenInto.chestsRemaining and alreadyBrokenInto.chestsRemaining > 0 then
            -- Place chests in the building
            for i = 1, alreadyBrokenInto.chestsRemaining do
                local chestX, chestY
                -- Try to place chest in a valid location (not on furniture or NPCs)
                for attempt = 1, 20 do
                    chestX = math.random(2, map.width - 1)
                    chestY = math.random(2, map.height - 1)

                    -- Check if position is free
                    local positionFree = true
                    for _, furn in ipairs(map.furniture) do
                        if furn.x == chestX and furn.y == chestY then
                            positionFree = false
                            break
                        end
                    end

                    if positionFree then
                        table.insert(chests, {
                            x = chestX,
                            y = chestY,
                            looted = false,
                            sprite = "\xF0\x9F\x93\xA6"
                        })
                        break
                    end
                end
            end
        end

        state.buildingInterior = {
            building = currentBuilding,
            npcs = npcsHere,
            map = map,
            playerX = map.playerSpawn.x,
            playerY = map.playerSpawn.y,
            lootChecked = false,
            chests = chests,
            brokenInto = alreadyBrokenInto ~= nil
        }
        state.phase = "building_interior"

        local buildingNames = {
            shop = "general store",
            stable = "stable",
            chapel = "chapel",
            well = "town well",
            butcher = "butcher shop",
            bakery = "bakery",
            tailor = "tailor's shop",
            jeweler = "jeweler's shop",
            forge = "forge",
            alchemist = "alchemist's laboratory",
            wizardtower = "wizard tower",
            fishing = "fishing dock",
            hunting = "hunter's lodge",
            market = "trading post"
        }
        local name = buildingNames[currentBuilding.id] or "building"
        log("You enter the " .. name .. ".", currentBuilding.color)
    elseif action == "well" then
        -- Free minor HP restore
        local healAmt = math.floor(state.player.maxHP * 0.1)
        state.player.hp = math.min(state.player.maxHP, state.player.hp + healAmt)
        log("You drink from the cool, clear water. Restored " .. healAmt .. " HP.", {0.4, 0.6, 0.8})
    elseif action == "property" then
        -- Property purchase/management for homes and businesses
        local PropertySystem = require("propertysystem")
        local townId = state.currentTown or "havenbrook"
        local buildingId = building.id

        -- Check if player owns this property
        if PropertySystem.ownsProperty(townId, buildingId) then
            -- Show property management UI
            state.propertyBuilding = building
            state.propertyTownId = townId
            state.phase = "property_manage"
            log("Welcome to your " .. building.name .. "!", {0.5, 0.7, 0.5})
        else
            -- Show property purchase UI
            state.propertyBuilding = building
            state.propertyTownId = townId
            state.phase = "property_purchase"
            log("This " .. building.name .. " is for sale.", {0.6, 0.6, 0.4})
        end
    -- === CITY EXPANSION: New building actions ===
    elseif action == "enter_district" then
        -- Enter a city district for exploration
        local districtId = building.districtId
        if districtId then
            F.enterDistrict(districtId)
        else
            log("This district is not yet accessible.", {0.7, 0.5, 0.3})
        end
    elseif action == "guild_hall" then
        -- Enter a guild hall
        local guildId = building.guildId
        if guildId then
            F.enterGuildHall(guildId)
        else
            log("The guild hall is closed.", {0.7, 0.5, 0.3})
        end
    elseif action == "enter_underbelly" then
        -- Enter an underground area
        local underbellyType = building.underbellyType
        if underbellyType then
            F.enterUnderbelly(underbellyType)
        else
            log("The entrance is sealed shut.", {0.7, 0.5, 0.3})
        end
    elseif action == "bounty_board" then
        -- Open the bounty board
        F.openBountyBoard()
    elseif action == "courier_office" then
        -- Open the courier office
        F.openCourierOffice()
    elseif action == "city_jail" then
        -- Visit the city jail
        log("The city jail holds captured criminals. Guards patrol the corridors.", {0.5, 0.5, 0.6})
        -- Check if player has captured bounties to turn in
        if state.player.capturedBounties and #state.player.capturedBounties > 0 then
            log("You have " .. #state.player.capturedBounties .. " captured criminal(s) to turn in!", {0.4, 1.0, 0.4})
            for i, bounty in ipairs(state.player.capturedBounties) do
                local reward = bounty.bountyReward or 100
                state.player.gold = (state.player.gold or 0) + reward
                state.player.karma = math.min(100, (state.player.karma or 0) + 5)
                log("Turned in " .. (bounty.criminalName or "criminal") .. " for " .. reward .. " gold!", {0.5, 0.9, 0.5})
            end
            state.player.capturedBounties = {}
        else
            log("You have no prisoners to turn in. Check the bounty board for work.", {0.6, 0.6, 0.7})
        end

    elseif action == "vampire_lair" then
        -- Hidden vampire lair dungeon - player discovered it!
        local currentTown = state.world and state.world.currentTown
        local townId = currentTown and (currentTown.id or currentTown.name) or "unknown"
        local townName = currentTown and currentTown.name or "the town"

        -- Mark the lair as discovered
        if state.townVampireLairs and state.townVampireLairs[townId] then
            state.townVampireLairs[townId].discovered = true

            -- Generate the vampire lair dungeon
            local lair = state.townVampireLairs[townId]
            local dungeonLevel = lair.bossLevel or (state.player.level + 3)

            log("\xF0\x9F\xA6\x87 You descend into the dark cellar... the stench of blood fills your nostrils.", {0.4, 0.15, 0.2})
            log("This is no ordinary cellar - it's a vampire nest!", {0.6, 0.2, 0.3})

            -- Set up the dungeon
            state.phase = "dungeon"
            state.dungeon = {
                floorNum = 1,
                maxFloors = math.random(3, 5),  -- Smaller dungeon since it's in-town
                dungeonType = "vampire_den",
                dungeonName = "Vampire Nest of " .. townName,
                isTownLair = true,
                lairTownId = townId,
                roomNum = 1,
                maxRooms = 5,
                currentRoom = nil,
                visitedRooms = {},
                bossDefeated = false,
                enemyLevel = dungeonLevel,
                started = true,
            }

            -- Generate first room
            state.dungeon.currentRoom = {
                description = "The cellar opens into a damp cavern carved from the earth. Coffins line the walls, and the air is thick with malevolence.",
                exits = {"north", "east"},
                event = nil,
                loot = nil,
            }

            -- Add rumor that player found the lair
            local RumorSystem = require("rumorsystem")
            RumorSystem.init(state)
            RumorSystem.createRumorFromEvent(RumorSystem.TYPES.HERO, {
                locationName = townName,
                townId = townId,
            })
        else
            log("The cellar is empty and abandoned. Nothing but dust and cobwebs.", {0.5, 0.5, 0.5})
        end
    end
end

-- Move player in town grid (cursor-style navigation)
-- Dynamic grid size with main street column and horizontal street rows
M.moveTownPlayer = function(dx, dy)
    -- Ensure position is initialized
    F.initTownPlayerPosition()

    local town = state.world and state.world.currentTown
    local gridCols = (town and town.townGridCols) or TOWN_GRID_COLS
    local gridRows = (town and town.townGridRows) or TOWN_GRID_ROWS
    local streetCol = (town and town.townStreetCol) or TOWN_STREET_COL

    local newX = state.townPlayerX + dx
    local newY = state.townPlayerY + dy

    -- Check bounds
    if newX < 1 or newX > gridCols then return false end
    if newY < 1 or newY > gridRows then return false end

    -- Special handling for gate row (last row - only street column valid)
    if newY == gridRows and newX ~= streetCol then
        return false
    end

    -- Move to new position (don't auto-enter, player must press Enter/Space/E)
    state.townPlayerX = newX
    state.townPlayerY = newY

    -- Check if we walked onto a wandering NPC on a street (not in a building)
    -- Only auto-greet wandering NPCs on streets; building NPCs require E to interact
    local building = F.getTownBuildingAt(newX, newY)
    if not building then
        -- On a street or open area - check for wandering NPCs
        if state.world and state.world.currentTown and state.world.currentTown.wanderingNPCs then
            local TownNPCsVisible = require("townnpcsvisible")
            for _, wnpc in ipairs(state.world.currentTown.wanderingNPCs) do
                if wnpc.gridX == newX and wnpc.gridY == newY and wnpc.visible ~= false then
                    TownNPCsVisible.interactWithNPC(wnpc, "wandering")
                    break
                end
            end
        end
    end

    return true
end

-- Function to move player within a building interior
M.moveBuildingPlayer = function(dx, dy)
    if not state.buildingInterior then return false end

    local map = state.buildingInterior.map
    if not map then return false end

    local newX = state.buildingInterior.playerX + dx
    local newY = state.buildingInterior.playerY + dy

    -- Check bounds
    if newX < 1 or newX > map.width or newY < 1 or newY > map.height then
        return false
    end

    -- Check collision with furniture
    if map.furniture then
        for _, furn in ipairs(map.furniture) do
            if furn.x == newX and furn.y == newY then
                return false -- Can't walk through furniture
            end
        end
    end

    -- Check collision with NPCs
    if state.buildingInterior.npcs then
        for _, npc in ipairs(state.buildingInterior.npcs) do
            if npc.interiorX == newX and npc.interiorY == newY then
                return false -- Can't walk through NPCs
            end
        end
    end

    -- Move player
    state.buildingInterior.playerX = newX
    state.buildingInterior.playerY = newY

    return true
end

-- Loot a chest in the building interior
M.lootBuildingChest = function(chest)
    if not chest or chest.looted then return end

    -- Mark chest as looted
    chest.looted = true

    -- Generate loot from the building's loot table
    local building = state.buildingInterior.building
    local lootTable = JAIL_CONFIG.lootTables[building.id] or JAIL_CONFIG.defaultLoot

    -- Generate gold
    local goldFound = math.random(lootTable.gold[1], lootTable.gold[2])
    goldFound = math.floor(goldFound * 0.5) -- Chests have less gold than initial break-in

    -- Generate items (1-3 items)
    local itemsFound = {}
    if lootTable.items and #lootTable.items > 0 then
        local numItems = math.random(1, math.min(3, #lootTable.items))
        local availableItems = {unpack(lootTable.items)}
        for i = 1, numItems do
            if #availableItems > 0 then
                local idx = math.random(#availableItems)
                table.insert(itemsFound, availableItems[idx])
                table.remove(availableItems, idx)
            end
        end
    end

    -- Generate notes/books (30% chance)
    if lootTable.notes and #lootTable.notes > 0 and math.random() < 0.3 then
        local note = lootTable.notes[math.random(#lootTable.notes)]
        table.insert(itemsFound, note)
    end

    -- Award loot
    state.player.gold = state.player.gold + goldFound

    local Backpack = require("backpack")
    for _, item in ipairs(itemsFound) do
        Backpack.addItem(item, 1)
    end

    -- Log results
    local lootMsg = "Found " .. goldFound .. "g"
    if #itemsFound > 0 then
        lootMsg = lootMsg .. " and " .. #itemsFound .. " item(s)"
    end
    log(lootMsg .. " in the chest!", {0.8, 0.7, 0.3})

    -- Decrement chests remaining
    local town = state.world and state.world.currentTown
    if town and town.brokenIntoBuildings and town.brokenIntoBuildings[building.id] then
        local brokenInfo = town.brokenIntoBuildings[building.id]
        brokenInfo.chestsRemaining = math.max(0, (brokenInfo.chestsRemaining or 1) - 1)
    end

    if F and F.save then F.save() end
end

-- Enter the building the player is currently standing on
M.enterCurrentTownBuilding = function()
    -- Ensure position is initialized
    F.initTownPlayerPosition()

    local building = F.getTownBuildingAt(state.townPlayerX, state.townPlayerY)
    if building then
        F.enterTownBuilding(building)
        return true
    end
    return false
end

return M
