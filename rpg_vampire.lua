-- RPG Vampire System
-- Extracted from textrpg.lua
-- Contains all vampire-related functions, data tables, and the VampireInfiltration system.

local M = {}

-- Upvalues set by register()
local state
local F

-- Required modules (resolved at register-time or lazily)
local Backpack = require("backpack")

-- ============================================================================
--                          VAMPIRE DATA TABLES
-- ============================================================================

-- Race sleep schedules (used by isNPCAsleep and getNPCSchedule)
-- NOTE: This table is duplicated from textrpg.lua. If rpg_data.lua is created
-- in the future, this should be moved there and shared.
local RACE_SLEEP_SCHEDULES = {
    human = {
        name = "Human",
        sleepStart = 22,  -- 10 PM
        sleepEnd = 6,     -- 6 AM
        sleepDuration = 8,
        canSleep = true,
    },
    dwarf = {
        name = "Dwarf",
        sleepStart = 23,  -- 11 PM
        sleepEnd = 7,     -- 7 AM
        sleepDuration = 8,
        canSleep = true,
    },
    orc = {
        name = "Orc",
        sleepStart = 21,  -- 9 PM
        sleepEnd = 5,     -- 5 AM
        sleepDuration = 8,
        canSleep = true,
    },
    gnome = {
        name = "Gnome",
        sleepStart = 22,  -- 10 PM
        sleepEnd = 6,     -- 6 AM
        sleepDuration = 8,
        canSleep = true,
    },
    elf = {
        name = "Elf",
        sleepStart = 1,   -- 1 AM (elves stay up late)
        sleepEnd = 5,     -- 5 AM (sleep half the time)
        sleepDuration = 4,  -- 4 hours instead of 8
        canSleep = true,
    },
    vampire = {
        name = "Vampire",
        sleepStart = nil,
        sleepEnd = nil,
        sleepDuration = 0,
        canSleep = false,
        isUndead = true,
        activeAtNight = true,  -- More active at night
    },
    zombie = {
        name = "Zombie",
        sleepStart = nil,
        sleepEnd = nil,
        sleepDuration = 0,
        canSleep = false,
        isUndead = true,
    },
    werewolf = {
        name = "Werewolf",
        sleepStart = nil,
        sleepEnd = nil,
        sleepDuration = 0,
        canSleep = false,
        activeAtNight = true,
    },
    lich = {
        name = "Lich",
        sleepStart = nil,
        sleepEnd = nil,
        sleepDuration = 0,
        canSleep = false,
        isUndead = true,
    },
    skeleton = {
        name = "Skeleton",
        sleepStart = nil,
        sleepEnd = nil,
        sleepDuration = 0,
        canSleep = false,
        isUndead = true,
    },
    ghoul = {
        name = "Ghoul",
        sleepStart = nil,
        sleepEnd = nil,
        sleepDuration = 0,
        canSleep = false,
        isUndead = true,
        activeAtNight = true,
    },
}

-- Expose for external access if needed
M.RACE_SLEEP_SCHEDULES = RACE_SLEEP_SCHEDULES

-- Sunlight hours and damage
local SUNLIGHT_HOURS = {
    [6] = {period = "dawn", damage = 5},
    [7] = {period = "morning", damage = 15},
    [8] = {period = "morning", damage = 15},
    [9] = {period = "morning", damage = 15},
    [10] = {period = "morning", damage = 15},
    [11] = {period = "morning", damage = 15},
    [12] = {period = "noon", damage = 30},
    [13] = {period = "afternoon", damage = 15},
    [14] = {period = "afternoon", damage = 15},
    [15] = {period = "afternoon", damage = 15},
    [16] = {period = "afternoon", damage = 15},
    [17] = {period = "afternoon", damage = 15},
    [18] = {period = "dusk", damage = 5},
}

M.SUNLIGHT_HOURS = SUNLIGHT_HOURS

-- IDs of vampire-type enemies (affected by sunlight)
local VAMPIRE_ENEMY_IDS = {
    vampire = true,
    vampire_lord = true,
    vampire_spawn = true,
}

M.VAMPIRE_ENEMY_IDS = VAMPIRE_ENEMY_IDS

-- Vampire skill tree
local VAMPIRE_SKILLS = {
    -- Tier 1: Basic Powers
    {
        id = "blood_drain",
        name = "Blood Drain",
        tier = 1,
        cost = 1,
        prerequisite = nil,
        description = "Drain blood from enemies to heal yourself. Heals 25% of damage dealt.",
    },
    {
        id = "night_vision",
        name = "Night Vision",
        tier = 1,
        cost = 1,
        prerequisite = nil,
        description = "+20% damage and accuracy at night.",
    },
    {
        id = "mist_form",
        name = "Mist Form",
        tier = 1,
        cost = 1,
        prerequisite = nil,
        description = "Transform into mist to avoid 50% damage for 3 turns.",
    },
    -- Tier 2: Advanced Powers
    {
        id = "bat_swarm",
        name = "Bat Swarm",
        tier = 2,
        cost = 2,
        prerequisite = "mist_form",
        description = "Summon a swarm of bats to attack all enemies.",
    },
    {
        id = "hypnotic_gaze",
        name = "Hypnotic Gaze",
        tier = 2,
        cost = 2,
        prerequisite = "blood_drain",
        description = "Hypnotize NPCs to avoid detection (50% less detection).",
    },
    {
        id = "enhanced_regeneration",
        name = "Enhanced Regeneration",
        tier = 2,
        cost = 2,
        prerequisite = "blood_drain",
        description = "Regenerate 5% max HP per turn in combat.",
    },
    -- Tier 3: Master Powers
    {
        id = "shadow_step",
        name = "Shadow Step",
        tier = 3,
        cost = 3,
        prerequisite = "bat_swarm",
        description = "Teleport through shadows. Escape combat instantly.",
    },
    {
        id = "vampiric_lord",
        name = "Vampiric Lord",
        tier = 3,
        cost = 3,
        prerequisite = "enhanced_regeneration",
        description = "Transform into Vampire Lord. +50% all stats.",
    },
    {
        id = "blood_plague",
        name = "Blood Plague",
        tier = 3,
        cost = 3,
        prerequisite = "hypnotic_gaze",
        description = "Your bites spread vampirism 100% with no detection.",
    },
}

M.VAMPIRE_SKILLS = VAMPIRE_SKILLS

-- ============================================================================
--                      FUNCTIONS TO WIRE INTO F TABLE
-- ============================================================================

M.F_FUNCTIONS = {
    "isInSunlight", "calculateSunlightDamage", "isVampireProtected",
    "applyVampireStats", "cureVampirism", "applySunlightDamage",
    "getVampireSkillPoints", "getTownIdFromLocation", "updateVampireSpread",
    "isCombatOutdoors", "applyVampireSunlightToCombatEnemy",
    "applyNPCVampireSunlight", "canVampireTravel",
    "transformPlayerIntoVampire", "attemptVampireBite",
    "cureVampirismMethod",
    "isNPCAsleep", "getNPCSchedule",
}

-- ============================================================================
--                    VAMPIRE DEN INFILTRATION SYSTEM
-- ============================================================================

-- Vampire infiltration system (merged from vampireinfiltration.lua)
-- Handles vampire den infiltration, epidemic tracking, and hidden lair spawning
local VampireInfiltration = {}
do
    -- Late-binding log function: always looks up the global at call time so that
    -- any runtime replacement of the logging system is picked up automatically.
    local function viLog(...)
        local fn = _G.log
        if fn then
            fn(...)
        end
    end

    -- Configuration for vampire infiltration
    local CONFIG = {
        infiltrationChancePerHour = 0.05,   -- 5% chance per game hour for nearby den to send vampire
        epidemicLairSpawnThreshold = 5,      -- Vampires needed in town to spawn hidden lair
        lairSpawnChance = 0.3,               -- 30% chance to spawn lair when threshold met
        maxInfiltrationRadius = 16,          -- Same as chunk size (tiles)
        denTypesToCheck = {"vampire_den"},   -- Dungeon types that can infiltrate
        debugLogging = false,                -- Enable debug logging for development (set to false for production)
    }

    -- Allow external configuration override
    function VampireInfiltration.setConfig(newConfig)
        for key, value in pairs(newConfig) do
            if CONFIG[key] ~= nil then
                CONFIG[key] = value
            end
        end
    end

    function VampireInfiltration.getConfig()
        return CONFIG
    end

    -- Helper: Normalize location name to proper town ID (handles case-sensitivity)
    -- Named viGetTownIdFromLocation to avoid shadowing F.getTownIdFromLocation in outer scope
    local function viGetTownIdFromLocation(locationName, viState)
        if not locationName or locationName == "" or locationName == "unknown" then
            return nil
        end

        -- Try to find matching town from anchor towns
        local WorldGen = require("worldgen")
        local anchorTowns = WorldGen.getAnchorTowns()
        if anchorTowns then
            for _, town in ipairs(anchorTowns) do
                -- Case-insensitive name match
                if town.name and town.name:lower() == locationName:lower() then
                    return town.id or town.name:lower()
                end
            end
        end

        -- Fallback: normalize to lowercase for consistency
        return locationName:lower()
    end

    -- Check if there are vampire dens near a town
    local function getVampireDensNearTown(townX, townY, radius)
        local WorldGen = require("worldgen")
        local nearbyDungeons = WorldGen.getNearbyDungeons(townX, townY, radius or CONFIG.maxInfiltrationRadius)
        local vampireDens = {}

        -- Debug: Log search parameters (check flag inline to avoid local variable)
        if CONFIG.debugLogging then
            viLog("DEBUG: Searching for vampire dens near (" .. townX .. "," .. townY .. ") radius=" .. (radius or CONFIG.maxInfiltrationRadius), {0.5, 0.5, 0.5})
            viLog("DEBUG: Found " .. #(nearbyDungeons or {}) .. " nearby dungeons total", {0.5, 0.5, 0.5})
        end

        for _, entry in ipairs(nearbyDungeons or {}) do
            local dungeon = entry.dungeon or entry
            -- Debug: Log why dungeons are filtered out
            if CONFIG.debugLogging then
                if not dungeon.type then
                    viLog("DEBUG: Skipping dungeon at (" .. (dungeon.x or "?") .. "," .. (dungeon.y or "?") .. ") - missing type", {0.5, 0.5, 0.5})
                elseif dungeon.type ~= "vampire_den" then
                    viLog("DEBUG: Skipping " .. dungeon.type .. " at (" .. dungeon.x .. "," .. dungeon.y .. ") - not vampire_den", {0.5, 0.5, 0.5})
                elseif dungeon.cleared then
                    viLog("DEBUG: Skipping vampire_den at (" .. dungeon.x .. "," .. dungeon.y .. ") - already cleared", {0.5, 0.5, 0.5})
                end
            end

            -- Only include active vampire dens
            if dungeon.type == "vampire_den" and not dungeon.cleared then
                table.insert(vampireDens, dungeon)
                if CONFIG.debugLogging then
                    viLog("DEBUG: Found active vampire_den at (" .. dungeon.x .. "," .. dungeon.y .. ")", {0.3, 0.8, 0.3})
                end
            end
        end

        if CONFIG.debugLogging then
            viLog("DEBUG: Total vampire dens found: " .. #vampireDens, {0.5, 0.5, 0.5})
        end

        return vampireDens
    end

    -- Spawn a hidden vampire lair building in a town during epidemic
    function VampireInfiltration.spawnTownVampireLair(viState, townId, townName)
        -- Initialize town vampire lairs if needed
        viState.townVampireLairs = viState.townVampireLairs or {}

        -- Check if this town already has a lair
        if viState.townVampireLairs[townId] then
            return false
        end

        -- Create the hidden vampire lair with expanded data structure (inline calculations to save locals)
        viState.townVampireLairs[townId] = {
            -- Core identification
            townId = townId,
            townName = townName,
            spawnDate = viState.totalDaysElapsed or 0,

            -- Discovery and generation tracking
            discovered = false,        -- Player hasn't found it yet
            dungeonGenerated = false,  -- Dungeon not yet created

            -- Combat data
            vampireCount = math.random(3, 7),  -- Vampires inside
            bossLevel = math.floor(((viState.player and viState.player.level) or 1) + 3),  -- Boss level
            defenseLevel = 100,        -- Lair strength (decreases as player fights, 0 = destroyed)

            -- Gameplay tracking
            searchProgress = 0,        -- Player investigation progress (0-100%, future feature)
            lastInfiltrationAttempt = viState.totalDaysElapsed or 0,  -- Cooldown tracking
            timesEntered = 0,          -- How many times player entered the lair

            -- Variation for depth (auto-scaled by player level)
            vampireType = ((viState.player and viState.player.level) or 1) >= 15 and (math.random() < 0.5 and "purebloods" or "mixed") or (((viState.player and viState.player.level) or 1) >= 8 and (math.random() < 0.3 and "mixed" or "thralls") or "thralls"),
            lairTier = ((viState.player and viState.player.level) or 1) >= 15 and (math.random() < 0.3 and "court" or "coven") or (((viState.player and viState.player.level) or 1) >= 8 and (math.random() < 0.3 and "coven" or "nest") or "nest"),

            -- Quest integration (future)
            associatedQuest = nil,     -- Quest ID if linked to quest system
        }

        -- Generate infiltration rumor
        local RumorSystem = require("rumorsystem")
        RumorSystem.init(viState)
        RumorSystem.onVampireLairInTown(townId, townName)

        viLog("\xF0\x9F\xA6\x87 Dark whispers suggest vampires have established a hidden den somewhere in " .. townName .. "...", {0.5, 0.2, 0.3})
        return true
    end

    -- Attempt vampire infiltration from nearby den into town
    function VampireInfiltration.attemptInfiltration(viState)
        -- Only check when in town
        if viState.phase ~= "town" and viState.phase ~= "map" then return end
        if not viState.world or not viState.world.useWorldGen then return end

        local currentTown = viState.world.currentTown
        if not currentTown then return end

        local townX = currentTown.x or (currentTown.position and currentTown.position.x) or viState.player.tileX
        local townY = currentTown.y or (currentTown.position and currentTown.position.y) or viState.player.tileY
        if not townX or not townY then return end
        local townId = currentTown.id or currentTown.name
        local townName = currentTown.name or "the town"

        -- Find nearby vampire dens
        local nearbyDens = getVampireDensNearTown(townX, townY)

        if #nearbyDens == 0 then return end

        -- Use shared MathUtil for direction calculation
        local viMathUtil = require("mathutil")

        -- Check each den for infiltration attempt
        for _, den in ipairs(nearbyDens) do
            if math.random() < CONFIG.infiltrationChancePerHour then
                -- Vampire infiltration! Create or boost a vampire NPC in town
                local denDirection = viMathUtil.getDirection(townX, townY, den.x, den.y)

                -- Find a suitable target NPC in this town to turn, or spawn infiltrator
                local infiltratorCreated = false

                -- Normalize town name for location matching (case-insensitive)
                local normalizedTownName = (townName or ""):lower()

                -- Collect eligible NPCs (not vampire, not dead, in this town)
                local eligibleNPCs = {}
                for _, npc in ipairs(viState.npcs or {}) do
                    local npcLoc = (npc.location or ""):lower()
                    if npcLoc == normalizedTownName and not npc.isVampire and not npc.isDead then
                        table.insert(eligibleNPCs, npc)
                    end
                end

                -- Try to turn one of the eligible NPCs (30% chance per eligible NPC, first one wins)
                if #eligibleNPCs > 0 then
                    -- Pick a random eligible NPC and attempt to turn them
                    local targetNpc = eligibleNPCs[math.random(#eligibleNPCs)]
                    if math.random() < 0.3 then
                        targetNpc.isVampire = true
                        targetNpc.vampireTransformDate = viState.totalDaysElapsed or 0
                        targetNpc.transformedBy = "vampire_den_infiltrator"
                        targetNpc.vampireInfectionRate = 0.08  -- Slightly higher than normal NPC
                        infiltratorCreated = true

                        viLog("\xF0\x9F\xA6\x87 Something dark stirs in " .. townName .. "... a new presence has joined the night.", {0.4, 0.2, 0.3})
                    end
                end

                -- Generate infiltration rumor (sometimes)
                if infiltratorCreated and math.random() < 0.5 then
                    local RumorSystem = require("rumorsystem")
                    RumorSystem.onVampireInfiltration(townId, townName, denDirection)
                end
            end
        end
    end

    -- Check if town has a vampire lair
    function VampireInfiltration.hasLair(viState, townId)
        return viState.townVampireLairs and viState.townVampireLairs[townId] ~= nil
    end

    -- Get lair data for a town
    function VampireInfiltration.getLair(viState, townId)
        return viState.townVampireLairs and viState.townVampireLairs[townId]
    end

    -- Remove lair from town (when cleared)
    function VampireInfiltration.removeLair(viState, townId)
        if viState.townVampireLairs and viState.townVampireLairs[townId] then
            viState.townVampireLairs[townId] = nil
            return true
        end
        return false
    end

    -- Get town ID from location name (exposed for external use)
    function VampireInfiltration.getTownIdFromLocation(viState, locationName)
        return viGetTownIdFromLocation(locationName, viState)
    end

    -- Update lair data (e.g., increment timesEntered, update defenseLevel)
    function VampireInfiltration.updateLair(viState, townId, updates)
        local lair = VampireInfiltration.getLair(viState, townId)
        if not lair then return false end

        for key, value in pairs(updates) do
            lair[key] = value
        end
        return true
    end
end -- end do block

-- Expose VampireInfiltration for external access
M.VampireInfiltration = VampireInfiltration

-- ============================================================================
--                          VAMPIRE FUNCTIONS
-- ============================================================================

-- Check if a given hour is during sunlight
-- Original: textrpg.lua line 1363
function M.isInSunlight(hour)
    return SUNLIGHT_HOURS[hour] ~= nil
end

-- Calculate sunlight damage for a given hour
-- Original: textrpg.lua line 1367
function M.calculateSunlightDamage(hour)
    if SUNLIGHT_HOURS[hour] then
        return SUNLIGHT_HOURS[hour].damage
    end
    return 0
end

-- Check if vampire is protected from sunlight
-- Original: textrpg.lua line 1375
function M.isVampireProtected(player)
    -- Inside building
    if state.phase == "town" or state.phase == "tavern" or
       state.phase == "shop" or state.phase == "forge" or
       state.phase == "manage_property" or state.phase == "inn" then
        return true
    end

    -- Inside dungeon/cave
    if state.inDungeon or state.phase == "cave_exploration" then
        return true
    end

    -- Has coffin (portable protection)
    if player.hasVampireCoffin and Backpack.hasItem("tq_vampire_coffin") then
        return true
    end

    -- Cloth wrapping (risky - 30% chance to fail each tick)
    if player.vampireClothWrapped then
        if math.random() > 0.3 then
            return true
        else
            -- Cloth fails!
            player.vampireClothWrapped = false
            log("Warning: Your cloth wrappings burn away in the sunlight!", {0.9, 0.3, 0.1})
            return false
        end
    end

    return false
end

-- Apply vampire stat doubling
-- Original: textrpg.lua line 1409
function M.applyVampireStats(player)
    if not player.isVampire then return end

    -- Store original stats on first transformation
    if not player.originalStats then
        player.originalStats = {
            maxHP = player.maxHP,
            attack = player.attack,
            defense = player.defense,
            maxMana = player.maxMana,
            MIGHT = player.stats.MIGHT,
            AGILITY = player.stats.AGILITY,
            VIGOR = player.stats.VIGOR,
            MIND = player.stats.MIND,
            SPIRIT = player.stats.SPIRIT,
            PRESENCE = player.stats.PRESENCE,
        }
    end

    -- Double all stats
    player.maxHP = player.originalStats.maxHP * 2
    player.hp = math.min(player.hp, player.maxHP)
    player.attack = player.originalStats.attack * 2
    player.defense = player.originalStats.defense * 2
    player.maxMana = player.originalStats.maxMana * 2
    player.mana = math.min(player.mana, player.maxMana)

    -- Double stats
    player.stats.MIGHT = player.originalStats.MIGHT * 2
    player.stats.AGILITY = player.originalStats.AGILITY * 2
    player.stats.VIGOR = player.originalStats.VIGOR * 2
    player.stats.MIND = player.originalStats.MIND * 2
    player.stats.SPIRIT = player.originalStats.SPIRIT * 2
    player.stats.PRESENCE = player.originalStats.PRESENCE * 2
end

-- Cure vampirism and restore original stats (basic version, takes player param)
-- Original: textrpg.lua line 1446
function M.cureVampirism(player)
    if not player then player = state.player end
    if not player or not player.isVampire then
        return false, "Not a vampire"
    end

    -- Restore original stats if we have them
    if player.originalStats then
        -- Restore combat stats
        player.maxHP = player.originalStats.maxHP
        player.hp = math.min(player.hp, player.maxHP)  -- Cap HP to new max
        player.attack = player.originalStats.attack
        player.defense = player.originalStats.defense
        player.maxMana = player.originalStats.maxMana
        player.mana = math.min(player.mana, player.maxMana)  -- Cap mana to new max

        -- Restore stats
        player.stats.MIGHT = player.originalStats.MIGHT
        player.stats.AGILITY = player.originalStats.AGILITY
        player.stats.VIGOR = player.originalStats.VIGOR
        player.stats.MIND = player.originalStats.MIND
        player.stats.SPIRIT = player.originalStats.SPIRIT
        player.stats.PRESENCE = player.originalStats.PRESENCE

        -- Clear original stats storage
        player.originalStats = nil
    end

    -- Clear all vampire-related state
    player.isVampire = false
    player.vampireTransformDate = nil
    player.vampireTransformLevel = nil
    player.vampireSkillTree = {}
    player.hasVampireCoffin = false
    player.vampireClothWrapped = false
    player.sunlightDamageTimer = 0

    -- Log the cure
    if log then
        log("The vampire curse has been lifted!", {0.8, 0.9, 0.3})
        log("Your stats have been restored to normal.", {0.7, 0.8, 0.3})
    end

    return true, "Vampirism cured"
end

-- Sunlight damage system
-- Original: textrpg.lua line 1493
function M.applySunlightDamage(dt)
    if not state.player or not state.player.isVampire then return end

    local hour = math.floor(state.timeOfDay or 12)
    if not M.isInSunlight(hour) then
        state.player.sunlightDamageTimer = 0
        return
    end

    if M.isVampireProtected(state.player) then
        state.player.sunlightDamageTimer = 0
        return
    end

    -- Apply damage every second
    state.player.sunlightDamageTimer = state.player.sunlightDamageTimer + dt
    if state.player.sunlightDamageTimer >= 1.0 then
        state.player.sunlightDamageTimer = state.player.sunlightDamageTimer - 1.0

        local damage = M.calculateSunlightDamage(hour)
        state.player.hp = state.player.hp - damage

        log(string.format("Sunlight burns you for %d damage!", damage), {0.9, 0.5, 0.1})

        if state.player.hp <= 0 then
            log("You have been incinerated by the sun!", {0.9, 0.1, 0.1})
            state.phase = "death"
            state.deathReason = "Burned to ashes by sunlight"
        end
    end
end

-- Get available vampire skill points
-- Original: textrpg.lua line 1605
function M.getVampireSkillPoints()
    if not state.player or not state.player.isVampire then return 0 end

    local vampireLevel = math.floor((state.player.level - (state.player.vampireTransformLevel or 1)) / 2) + 1
    local spentPoints = 0

    for skillId, unlocked in pairs(state.player.vampireSkillTree or {}) do
        if unlocked then
            for _, s in ipairs(VAMPIRE_SKILLS) do
                if s.id == skillId then
                    spentPoints = spentPoints + s.cost
                    break
                end
            end
        end
    end

    return vampireLevel - spentPoints
end

-- Helper to maintain compatibility with existing code
-- Original: textrpg.lua line 1887
function M.getTownIdFromLocation(locationName)
    return VampireInfiltration.getTownIdFromLocation(state, locationName)
end

-- Vampire epidemic spread system
-- Original: textrpg.lua line 1897
function M.updateVampireSpread(dt)
    state.vampireSpreadTimer = (state.vampireSpreadTimer or 0) + dt

    -- Check for spread every game hour (30 seconds)
    if state.vampireSpreadTimer < 30 then return end
    state.vampireSpreadTimer = 0

    -- Apply sunlight damage to NPC vampires caught outdoors during daytime
    M.applyNPCVampireSunlight()

    -- OPTIMIZATION: Distance-based NPC dormancy
    -- Only process NPCs within activity radius to prevent global iteration lag
    local ACTIVITY_RADIUS = 32  -- 2 chunks (matches chunk load radius)
    local playerX = state.world and state.world.playerX or 0
    local playerY = state.world and state.world.playerY or 0

    -- Helper: Check if NPC is within activity radius
    local function isNPCActive(npc)
        -- NPCs without position data are inactive
        if not npc.tileX or not npc.tileY then return false end

        local dist = math.abs(npc.tileX - playerX) + math.abs(npc.tileY - playerY)
        return dist <= ACTIVITY_RADIUS
    end

    -- Track vampires per location for epidemic/purge checks
    local vampiresByLocation = {}

    -- INDEX NPCs BY LOCATION for O(1) lookup (major performance optimization)
    -- This prevents O(vampires * all_npcs) nested loop, reducing to O(vampires * local_npcs)
    -- NEW: Only index NPCs within activity radius (reduces from ALL NPCs to nearby NPCs)
    local npcsByLocation = {}
    local activeNPCCount = 0
    local dormantNPCCount = 0

    for _, npc in ipairs(state.npcs or {}) do
        if not npc.isDead then
            -- DISTANCE CULLING: Skip NPCs too far from player
            if not isNPCActive(npc) then
                dormantNPCCount = dormantNPCCount + 1
                goto continue_npc
            end

            activeNPCCount = activeNPCCount + 1
            local loc = (npc.location or ""):lower()
            if loc ~= "" and loc ~= "unknown" then
                npcsByLocation[loc] = npcsByLocation[loc] or {}
                table.insert(npcsByLocation[loc], npc)
            end
        end
        ::continue_npc::
    end

    -- Performance logging (can be disabled in production)
    if dormantNPCCount > 0 then
        -- log("Vampire spread: " .. activeNPCCount .. " active NPCs, " .. dormantNPCCount .. " dormant (optimized)", {0.5, 0.8, 0.5})
    end

    -- Find vampire NPCs (only within activity radius)
    -- OPTIMIZATION: Build vampire NPC cache for use by other systems (Luminary Patrols)
    local vampireNPCs = {}
    state.vampireNPCCache = state.vampireNPCCache or {}
    state.vampireNPCCache.vampires = {}  -- Reset cache
    state.vampireNPCCache.lastUpdate = state.totalDaysElapsed or 0

    for _, npc in ipairs(state.npcs or {}) do
        if npc.isVampire and not npc.isDead then
            -- DISTANCE CULLING: Skip dormant vampire NPCs
            if not isNPCActive(npc) then
                goto continue_vampire_check
            end

            local loc = npc.location or "unknown"
            vampiresByLocation[loc] = (vampiresByLocation[loc] or 0) + 1

            -- Add to global vampire cache (for Luminary Patrol efficiency)
            if npc.tileX and npc.tileY then
                table.insert(state.vampireNPCCache.vampires, {
                    npc = npc,
                    x = npc.tileX,
                    y = npc.tileY,
                    location = npc.location
                })
            end

            if npc.vampireInfectionRate and npc.vampireInfectionRate > 0 then
                table.insert(vampireNPCs, npc)
            end
        end
        ::continue_vampire_check::
    end

    -- Each vampire NPC attempts to spread
    for _, vampire in ipairs(vampireNPCs) do
        if math.random() < vampire.vampireInfectionRate then
            -- Find nearby sleeping NPCs in same location
            local targets = {}

            -- Normalize vampire location for comparison
            local vampLoc = (vampire.location or ""):lower()
            if vampLoc == "" or vampLoc == "unknown" then
                goto continue_vampire  -- Skip vampires with invalid locations
            end

            -- Check current time for night activity bonus
            local hour = math.floor(state.timeOfDay or 12)
            local isNight = hour >= 22 or hour <= 6  -- Night hours when vampires are most active

            -- USE INDEXED LOOKUP: O(local_npcs) instead of O(all_npcs)
            -- This is a MAJOR performance improvement: 25,000 iterations -> ~250!
            local localNPCs = npcsByLocation[vampLoc] or {}
            for _, npc in ipairs(localNPCs) do
                if not npc.isVampire then
                    -- Check if NPC is vulnerable (asleep OR night time)
                    local asleep = M.isNPCAsleep(npc)
                    if asleep or isNight then
                        table.insert(targets, npc)
                    end
                end
            end

            if #targets > 0 then
                local target = targets[math.random(#targets)]

                -- 50% chance for NPC vampires to be detected
                if math.random() < 0.5 then
                    -- Detected! Vampire is killed by guards
                    vampire.isDead = true
                    vampire.deathReason = "Slain by vampire hunters"
                    log("Vampire " .. vampire.name .. " was discovered and destroyed!", {0.9, 0.5, 0.1})
                else
                    -- Success! Transform target
                    target.isVampire = true
                    target.vampireTransformDate = state.totalDaysElapsed or 0
                    target.transformedBy = vampire.name
                    target.vampireInfectionRate = 0.05  -- Lower rate for NPC-created vampires

                    -- Update vampire count for this location
                    local loc = target.location or "unknown"
                    vampiresByLocation[loc] = (vampiresByLocation[loc] or 0) + 1
                end
            end

            ::continue_vampire::
        end
    end

    -- Attempt vampire infiltration from nearby dens
    VampireInfiltration.attemptInfiltration(state)

    -- Check for epidemic/purge situations in each location
    local RumorSystem = require("rumorsystem")
    -- Note: RumorSystem.init() called once at game startup in TextRPG.init()

    for location, vampCount in pairs(vampiresByLocation) do
        -- Generate epidemic rumor if 3+ vampires
        if vampCount >= 3 then
            RumorSystem.checkTownVampireStatus(location, location, vampCount, 100)
        end

        -- Spawn hidden vampire lair in town during severe epidemic
        if vampCount >= VampireInfiltration.getConfig().epidemicLairSpawnThreshold then
            -- Normalize location to proper town ID (handles case-sensitivity)
            local townId = M.getTownIdFromLocation(location)
            if townId then
                -- Check if this town doesn't already have a lair
                state.townVampireLairs = state.townVampireLairs or {}
                if not state.townVampireLairs[townId] then
                    -- Chance to spawn lair
                    if math.random() < VampireInfiltration.getConfig().lairSpawnChance then
                        VampireInfiltration.spawnTownVampireLair(state, townId, location)  -- townId for lair key, location for display name
                    end
                end
            end
        end

        -- Holy City Purge at 5+ vampires
        if vampCount >= 5 then
            log("The Holy City has sent Inquisitors to " .. location .. "!", {0.9, 0.7, 0.2})

            -- Purge 50% of vampires in this location
            -- OPTIMIZATION: Only iterate active NPCs (already filtered above)
            local purged = 0
            local locationNPCs = npcsByLocation[location:lower()] or {}
            for _, npc in ipairs(locationNPCs) do
                if npc.isVampire and not npc.isDead then
                    if math.random() < 0.5 then
                        npc.isDead = true
                        npc.deathReason = "Purged by Holy City Inquisitors"
                        purged = purged + 1
                    end
                end
            end

            if purged > 0 then
                log(purged .. " vampires were destroyed in the purge!", {0.8, 0.5, 0.3})
                RumorSystem.onVampirePurge(location, location, purged)
            end
        end
    end
end

-- Check if a combat is happening outdoors (not sheltered from sunlight)
-- Original: textrpg.lua line 2107
function M.isCombatOutdoors()
    -- Dungeons/caves are sheltered
    if state.inDungeon or state.phase == "cave_exploration" then
        return false
    end
    -- Town/building phases are sheltered
    if state.phase == "town" or state.phase == "tavern" or
       state.phase == "shop" or state.phase == "forge" or
       state.phase == "inn" or state.phase == "manage_property" then
        return false
    end
    -- Everything else (overworld combat) is outdoors
    return true
end

-- Apply sunlight damage to vampire enemies during combat
-- Called at the start of each enemy vampire's turn
-- Original: textrpg.lua line 2124
function M.applyVampireSunlightToCombatEnemy(enemy)
    if not enemy or enemy.hp <= 0 then return false end

    -- Check if this enemy is a vampire type
    if not VAMPIRE_ENEMY_IDS[enemy.id] then return false end

    -- Check if it's daytime
    local hour = math.floor(state.timeOfDay or 12)
    if not M.isInSunlight(hour) then return false end

    -- Check if combat is outdoors
    if not M.isCombatOutdoors() then return false end

    -- Apply sunlight damage (percentage of max HP, same scale as player)
    local sunlightDamage = M.calculateSunlightDamage(hour)
    -- Scale to % of max HP so it's meaningful at all levels
    -- Dawn/dusk = ~5% max HP, morning/afternoon = ~10%, noon = ~20%
    local percentDamage = math.floor(enemy.maxHP * (sunlightDamage / 150))
    percentDamage = math.max(percentDamage, sunlightDamage)  -- At least the raw damage value

    enemy.hp = enemy.hp - percentDamage

    log("", {1, 1, 1})
    log("The sunlight burns " .. enemy.name .. " for " .. percentDamage .. " damage!", {0.9, 0.6, 0.1})

    if enemy.hp <= 0 then
        enemy.hp = 0
        log(enemy.name .. " is incinerated by the sun!", {0.9, 0.3, 0.1})
        return true  -- Enemy died
    end

    return false
end

-- Apply sunlight to NPC vampires in the overworld
-- Called during vampire spread update (every 30 seconds game time)
-- Original: textrpg.lua line 2160
function M.applyNPCVampireSunlight()
    local hour = math.floor(state.timeOfDay or 12)
    if not M.isInSunlight(hour) then return end

    local killed = 0

    for _, npc in ipairs(state.npcs or {}) do
        if npc.isVampire and not npc.isDead then
            -- NPCs with a town location are considered sheltered (indoors)
            local location = (npc.location or ""):lower()
            local isSheltered = location ~= "" and location ~= "unknown" and location ~= "wilderness"

            if not isSheltered then
                -- Unprotected NPC vampire in sunlight - they die
                npc.isDead = true
                npc.deathReason = "Burned to ashes by sunlight"
                killed = killed + 1
            end
        end
    end

    if killed > 0 then
        log(killed .. " vampire" .. (killed > 1 and "s were" or " was") .. " destroyed by sunlight!", {0.9, 0.6, 0.1})
    end
end

-- Check if vampire can travel
-- Original: textrpg.lua line 2187
function M.canVampireTravel()
    if not state.player or not state.player.isVampire then return true, nil end

    local hour = math.floor(state.timeOfDay or 12)

    -- Can travel at night (19:00 - 5:00)
    if hour >= 19 or hour <= 5 then
        return true, nil
    end

    -- Can travel during twilight (5:00-6:00, 18:00-19:00) but risky
    if (hour >= 5 and hour < 6) or (hour >= 18 and hour < 19) then
        if state.player.hasVampireCoffin then
            return true, "Traveling in twilight with coffin"
        else
            return true, "WARNING: Traveling in twilight without protection!"
        end
    end

    -- Cannot travel in daylight unless protected
    if state.player.hasVampireCoffin then
        return true, "Traveling in coffin"
    else
        return false, "Vampires cannot travel in daylight without a coffin!"
    end
end

-- Check if NPC is asleep based on race and time
-- Original: textrpg.lua line 2215
function M.isNPCAsleep(npc)
    if not npc or not npc.race then return false end

    local race = RACE_SLEEP_SCHEDULES[npc.race]
    if not race or not race.canSleep then return false end

    local hour = state.timeOfDay or 12

    -- Handle sleep times that cross midnight
    if race.sleepStart > race.sleepEnd then
        -- e.g., sleep 22 to 6 (10 PM to 6 AM)
        return hour >= race.sleepStart or hour < race.sleepEnd
    else
        -- e.g., sleep 1 to 5 (1 AM to 5 AM for elves)
        return hour >= race.sleepStart and hour < race.sleepEnd
    end
end

-- NPC daily schedule based on profession
-- Original: textrpg.lua line 2246
function M.getNPCSchedule(profession, race)
    local schedule = {}

    -- Default schedule for living races
    if RACE_SLEEP_SCHEDULES[race] and RACE_SLEEP_SCHEDULES[race].canSleep then
        local sleepStart = RACE_SLEEP_SCHEDULES[race].sleepStart
        local sleepEnd = RACE_SLEEP_SCHEDULES[race].sleepEnd

        -- Build hourly schedule
        for hour = 0, 23 do
            -- Check if sleeping
            if sleepStart > sleepEnd then
                if hour >= sleepStart or hour < sleepEnd then
                    schedule[hour] = {location = "home", activity = "sleeping"}
                end
            else
                if hour >= sleepStart and hour < sleepEnd then
                    schedule[hour] = {location = "home", activity = "sleeping"}
                end
            end

            -- Fill in waking hours based on profession
            if not schedule[hour] then
                if hour >= 8 and hour < 12 then
                    schedule[hour] = {location = "work", activity = "working"}
                elseif hour >= 12 and hour < 13 then
                    schedule[hour] = {location = "tavern", activity = "lunch"}
                elseif hour >= 13 and hour < 18 then
                    schedule[hour] = {location = "work", activity = "working"}
                elseif hour >= 18 and hour < 20 then
                    schedule[hour] = {location = "tavern", activity = "dinner"}
                elseif hour >= 20 and hour < sleepStart then
                    schedule[hour] = {location = "home", activity = "relaxing"}
                else
                    schedule[hour] = {location = "wandering", activity = "wandering"}
                end
            end
        end
    else
        -- Undead/non-sleeping races - always active
        for hour = 0, 23 do
            if hour >= 6 and hour < 18 then
                -- Day time (undead avoid bright daylight unless necessary)
                if RACE_SLEEP_SCHEDULES[race] and RACE_SLEEP_SCHEDULES[race].activeAtNight then
                    schedule[hour] = {location = "home", activity = "resting"}
                else
                    schedule[hour] = {location = "work", activity = "working"}
                end
            else
                -- Night time
                schedule[hour] = {location = "wandering", activity = "patrolling"}
            end
        end
    end

    return schedule
end

-- ============================================================================
--                  VAMPIRE TRANSFORMATION / BITE FUNCTIONS
-- ============================================================================

-- Transform the player into a vampire
-- Original: textrpg.lua line 10844
-- External dependencies: F.calculateStats (called as calculateStats() via _G metatable)
function M.transformPlayerIntoVampire()
    if state.player.isVampire then return end

    state.player.isVampire = true
    state.player.vampireTransformDate = state.totalDaysElapsed or 0
    state.player.vampireTransformLevel = state.player.level
    state.player.vampireSkillTree = {}

    -- Apply stat doubling
    M.applyVampireStats(state.player)
    F.calculateStats()

    log("You have become a vampire! Your stats have doubled!", {0.8, 0.2, 0.3})
    log("You must avoid sunlight or you will burn!", {0.9, 0.5, 0.1})

    -- Generate rumor about player becoming vampire
    local RumorSystem = require("rumorsystem")
    RumorSystem.init(state)
    local locationName = state.world.currentTown and state.world.currentTown.name or "the wilderness"
    RumorSystem.onPlayerBecameVampire(state.player.name, locationName)
end

-- Attempt to bite sleeping NPC
-- Original: textrpg.lua line 10867
-- External dependencies: F.calculateDetectionChance, F.checkDetection,
--   F.commitCrime, F.changeFactionRep, LuminaryPatrols (require("luminarypatrols"))
function M.attemptVampireBite(npc)
    if not state.player.isVampire then
        return false, "You are not a vampire"
    end

    if not M.isNPCAsleep(npc) then
        return false, "NPC is awake and will resist"
    end

    -- Use stealth detection system
    local detectionChance = F.calculateDetectionChance("vampire_bite")

    -- Reduce with hypnotic gaze skill
    if state.player.vampireSkillTree.hypnotic_gaze then
        detectionChance = detectionChance * 0.5
    end

    -- Blood plague makes detection 0%
    if state.player.vampireSkillTree.blood_plague then
        detectionChance = 0
    end

    -- Check for detection using stealth system
    local detected = F.checkDetection("vampire_bite")
    if detected and detectionChance > 0 then
        -- Detected! Commit major crime
        F.commitCrime("vampire_attack")

        -- Holy City sends hunters
        F.changeFactionRep("holy_dominion", -50)
        state.player.bounty = state.player.bounty + 1000
        state.vampireHuntersActive = true

        -- Spawn Luminary patrol near player
        if state.world and state.world.playerX and state.world.playerY then
            local LuminaryPatrols = require("luminarypatrols")
            LuminaryPatrols.spawnPatrol(state.world.playerX, state.world.playerY, "vampire_threat")
        end

        log("You've been detected! The Holy City sends vampire hunters!", {0.9, 0.2, 0.1})

        -- Generate rumor about the detected attack
        local RumorSystem = require("rumorsystem")
        RumorSystem.init(state)
        local townName = state.world.currentTown and state.world.currentTown.name or "an unknown location"
        local townId = state.world.currentTown and state.world.currentTown.id or nil
        RumorSystem.onVampireAttack(townId, townName, npc.name, true)
        RumorSystem.onPlayerVampireRevealed(townId, townName, state.player.name)

        return false, "Detected by witnesses"
    end

    -- Success! Transform NPC
    npc.isVampire = true
    npc.vampireTransformDate = state.totalDaysElapsed or 0
    npc.transformedBy = "player"

    -- Infection rate (chance to spread further)
    local infectionRate = 0.10  -- 10% base chance NPC will bite others
    if state.player.vampireSkillTree.blood_plague then
        infectionRate = 1.0
    end
    npc.vampireInfectionRate = infectionRate

    log("You successfully turn " .. npc.name .. " into a vampire!", {0.8, 0.2, 0.3})

    -- Generate rumor about the undetected attack (may still have witnesses)
    local RumorSystem = require("rumorsystem")
    RumorSystem.init(state)
    local townName = state.world.currentTown and state.world.currentTown.name or "an unknown location"
    local townId = state.world.currentTown and state.world.currentTown.id or nil
    RumorSystem.onVampireAttack(townId, townName, npc.name, false)

    return true
end

-- Cure vampirism (method-based version, e.g. "holy_water")
-- Original: textrpg.lua line 10943
-- This is a SECOND version of cureVampirism that takes a method parameter
-- and handles item consumption, side effects, etc.
-- External dependencies: Backpack, F.calculateStats
function M.cureVampirismMethod(method)
    if not state.player.isVampire then return false, "Not a vampire" end

    if method == "holy_water" then
        if not Backpack.hasItem("tq_holy_water") then
            return false, "Missing holy water"
        end

        Backpack.removeItem("tq_holy_water", 1)

        -- Restore original stats
        if state.player.originalStats then
            state.player.maxHP = state.player.originalStats.maxHP
            state.player.attack = state.player.originalStats.attack
            state.player.defense = state.player.originalStats.defense
            state.player.maxMana = state.player.originalStats.maxMana
            state.player.stats = {
                MIGHT = state.player.originalStats.MIGHT,
                AGILITY = state.player.originalStats.AGILITY,
                VIGOR = state.player.originalStats.VIGOR,
                MIND = state.player.originalStats.MIND,
                SPIRIT = state.player.originalStats.SPIRIT,
                PRESENCE = state.player.originalStats.PRESENCE,
                FAITH = state.player.originalStats.FAITH or 10,
            }
            state.player.originalStats = nil
        end

        -- Apply side effects
        state.player.hp = math.max(1, math.floor(state.player.maxHP * 0.5))  -- 50% HP loss
        state.player.karma = math.min(100, state.player.karma + 25)  -- Karma gain

        -- Clear vampire data
        state.player.isVampire = false
        state.player.vampireSkillTree = {}
        state.player.vampireTransformDate = nil
        state.player.vampireTransformLevel = nil
        state.player.hasVampireCoffin = false
        state.player.vampireClothWrapped = false

        F.calculateStats()

        log("You have been cured of vampirism!", {0.5, 1, 0.5})
        log("The holy water burned through your veins, but you are free.", {0.7, 0.8, 0.9})
        return true
    end

    return false, "Unknown cure method"
end

-- ============================================================================
--                          REGISTRATION
-- ============================================================================

function M.register(s, f)
    state = s
    F = f

    -- Wire all functions into F table
    for _, name in ipairs(M.F_FUNCTIONS) do
        if M[name] then
            F[name] = M[name]
        end
    end

    -- Also register VampireInfiltration into package.loaded for backward compatibility
    -- (any code doing require("vampireinfiltration") gets this table)
    package.loaded["vampireinfiltration"] = VampireInfiltration
end

return M
