-- RPG Travel & Camping System
-- Extracted from textrpg.lua
-- Contains: weather system, shelter/camping, cooking, ambush, travel home,
-- paid travel (carriage), camp chat, guard management.

local Backpack = require("backpack")

local M = {}

-- Upvalues set by register()
local state
local F

-- Data references (set during register from textrpg locals)
local ENEMIES

-- Module references (set during register)
local TextRPG

-- Forward-declared locals within this module
local log
local updateWeather
local lastBlightSpreadDay = 0

-- ============================================================================
-- TRAVEL-SPECIFIC DATA TABLES
-- ============================================================================

local WEATHER_STATES = {"sunny", "cloudy", "rainy", "stormy", "foggy", "snowy", "windy", "pleasant"}

-- Weather effects - defines how each weather impacts gameplay
local WEATHER_EFFECTS = {
    sunny = {
        icon = "\226\152\128", color = {1, 0.9, 0.3}, name = "Sunny",
        travelSpeed = 1.0, staminaDrain = 1.0, combatMod = 0,
        dangerous = false, needsShelter = false,
        desc = "Clear skies and warm sun.",
    },
    pleasant = {
        icon = "\240\159\140\164", color = {0.8, 0.9, 1}, name = "Pleasant",
        travelSpeed = 1.1, staminaDrain = 0.8, combatMod = 0,
        dangerous = false, needsShelter = false,
        desc = "Perfect weather for travel.",
    },
    cloudy = {
        icon = "\226\152\129", color = {0.6, 0.6, 0.7}, name = "Cloudy",
        travelSpeed = 1.0, staminaDrain = 0.9, combatMod = 0,
        dangerous = false, needsShelter = false,
        desc = "Overcast but mild.",
    },
    rainy = {
        icon = "\240\159\140\167", color = {0.4, 0.5, 0.7}, name = "Rainy",
        travelSpeed = 0.8, staminaDrain = 1.3, combatMod = -5,
        dangerous = false, needsShelter = true,
        desc = "Steady rain. Consider shelter.",
    },
    stormy = {
        icon = "\226\155\136", color = {0.3, 0.3, 0.5}, name = "Stormy",
        travelSpeed = 0.5, staminaDrain = 2.0, combatMod = -15,
        dangerous = true, needsShelter = true, damagePerHour = 5,
        desc = "Dangerous storm! Seek shelter!",
    },
    foggy = {
        icon = "\240\159\140\171", color = {0.7, 0.7, 0.75}, name = "Foggy",
        travelSpeed = 0.7, staminaDrain = 1.0, combatMod = -10,
        dangerous = false, needsShelter = false, ambushChance = 0.3,
        desc = "Limited visibility. Careful of ambushes.",
    },
    snowy = {
        icon = "\226\157\132", color = {0.85, 0.9, 1}, name = "Snowy",
        travelSpeed = 0.6, staminaDrain = 1.5, combatMod = -5,
        dangerous = false, needsShelter = true,
        desc = "Snow is falling. Warmth advised.",
    },
    windy = {
        icon = "\240\159\146\168", color = {0.6, 0.7, 0.8}, name = "Windy",
        travelSpeed = 0.9, staminaDrain = 1.2, combatMod = -5,
        dangerous = false, needsShelter = false,
        desc = "Strong winds slow travel.",
    },
}

-- Map region/subregion IDs to climate types for weather generation
local REGION_CLIMATE_MAP = {
    -- Temperate: pleasant summers, rain in autumn, no snow
    holy_dominion       = "temperate",
    gnomish_isles       = "temperate",
    mechspire_region    = "temperate",
    clockwork_coast     = "temperate",
    trade_ports_coast   = "temperate",
    -- Temperate forest: fog, rain, light snow only in deep winter
    eastern_forests     = "temperate_forest",
    -- Mountain: wind, snow in winter, storms
    dwarven_mountains   = "mountain",
    -- Steppe: wind-heavy, dry, some winter snow
    orcish_steppes      = "steppe",
    -- Swamp: fog and rain dominant, never snows
    shadowfen           = "swamp",
    -- Arid: sunny, windy, never snows or rains
    great_endless_desert = "arid",
    scorched_sands      = "arid",
    wastes_of_calidar   = "arid",
    -- Frozen: snow year-round, storms
    frostbound_reach    = "frozen",
    northern_tundra_continent = "frozen",
    southern_tundra     = "frozen",
    -- Tropical: warm, stormy seasons, never snows
    ashen_archipelago   = "tropical",
    great_western_isle  = "tropical",
    -- Ocean: stormy, windy, foggy
    silver_seas         = "ocean",
    western_ocean       = "ocean",
    southern_ocean      = "ocean",
    polar_ocean         = "ocean",
    northern_seas       = "ocean",
    shimmering_sea      = "ocean",
}

-- Climate-specific weather weights per season
-- Each climate defines weights for: brightbloom, sunreign, ashwane, frosthollow
local CLIMATE_WEATHER_WEIGHTS = {
    temperate = {
        brightbloom  = {sunny = 3, cloudy = 2, rainy = 2, pleasant = 3, windy = 1},
        sunreign     = {sunny = 4, cloudy = 1, pleasant = 4, windy = 1},
        ashwane      = {cloudy = 3, rainy = 3, foggy = 1, windy = 2, pleasant = 1},
        frosthollow  = {cloudy = 3, rainy = 2, foggy = 2, windy = 2, pleasant = 1},
    },
    temperate_forest = {
        brightbloom  = {sunny = 2, cloudy = 2, rainy = 3, foggy = 2, pleasant = 2},
        sunreign     = {sunny = 3, cloudy = 2, rainy = 1, pleasant = 3, foggy = 1},
        ashwane      = {cloudy = 3, rainy = 3, foggy = 3, windy = 1, pleasant = 1},
        frosthollow  = {cloudy = 2, rainy = 2, foggy = 2, snowy = 1, windy = 2},
    },
    mountain = {
        brightbloom  = {sunny = 2, cloudy = 2, rainy = 1, windy = 3, pleasant = 1},
        sunreign     = {sunny = 3, cloudy = 2, windy = 2, pleasant = 2, stormy = 1},
        ashwane      = {cloudy = 3, windy = 3, rainy = 2, stormy = 1, foggy = 1},
        frosthollow  = {snowy = 4, windy = 3, stormy = 2, cloudy = 2},
    },
    steppe = {
        brightbloom  = {sunny = 3, cloudy = 2, windy = 3, pleasant = 1},
        sunreign     = {sunny = 4, windy = 3, cloudy = 1, pleasant = 2},
        ashwane      = {cloudy = 3, windy = 4, sunny = 1, rainy = 1},
        frosthollow  = {windy = 4, cloudy = 3, snowy = 2, stormy = 1},
    },
    swamp = {
        brightbloom  = {foggy = 3, rainy = 3, cloudy = 2, pleasant = 1},
        sunreign     = {foggy = 2, rainy = 2, cloudy = 2, sunny = 2, pleasant = 1},
        ashwane      = {foggy = 4, rainy = 3, cloudy = 2, stormy = 1},
        frosthollow  = {foggy = 3, rainy = 3, cloudy = 2, windy = 1, stormy = 1},
    },
    arid = {
        brightbloom  = {sunny = 5, windy = 2, cloudy = 1},
        sunreign     = {sunny = 6, windy = 2},
        ashwane      = {sunny = 4, windy = 3, cloudy = 1},
        frosthollow  = {sunny = 3, windy = 3, cloudy = 2},
    },
    frozen = {
        brightbloom  = {snowy = 3, windy = 2, cloudy = 2, stormy = 1},
        sunreign     = {snowy = 2, cloudy = 3, windy = 2, foggy = 1},
        ashwane      = {snowy = 3, windy = 3, stormy = 2, cloudy = 1},
        frosthollow  = {snowy = 5, stormy = 3, windy = 2},
    },
    tropical = {
        brightbloom  = {sunny = 3, rainy = 2, pleasant = 2, cloudy = 1},
        sunreign     = {sunny = 4, pleasant = 3, stormy = 1, rainy = 1},
        ashwane      = {rainy = 3, stormy = 2, cloudy = 2, sunny = 1, windy = 1},
        frosthollow  = {rainy = 2, cloudy = 3, sunny = 2, windy = 1, pleasant = 1},
    },
    ocean = {
        brightbloom  = {windy = 3, cloudy = 2, rainy = 2, foggy = 1, stormy = 1},
        sunreign     = {sunny = 2, windy = 3, cloudy = 2, pleasant = 1},
        ashwane      = {stormy = 3, windy = 3, rainy = 2, foggy = 2},
        frosthollow  = {stormy = 3, windy = 3, snowy = 2, foggy = 1, cloudy = 1},
    },
}

-- Shelter types
local SHELTER_TYPES = {
    {id = "tent", name = "Set up Tent", cost = 0, quality = 0.6, time = 2,
        desc = "Basic shelter from the elements.", requiresItem = "tent"},
    {id = "makeshift", name = "Build Makeshift Shelter", cost = 0, quality = 0.4, time = 3,
        desc = "Gather branches and leaves for basic cover."},
    {id = "cave", name = "Find a Cave", cost = 0, quality = 0.8, time = 1,
        desc = "Search for natural shelter nearby.", chanceToFind = 0.4},
    {id = "inn", name = "Stay at Inn", cost = 15, quality = 1.0, time = 0,
        desc = "Comfortable rest with food and warmth.", townOnly = true},
}

-- Camp cooking recipes
local CAMP_FOODS = {
    {id = "simple_stew", name = "Simple Stew",
        ingredients = {{id = "meat", qty = 1}},
        effect = "heal", amount = 20, duration = 0,
        desc = "A hearty stew that restores 20 HP."},
    {id = "fish_dinner", name = "Grilled Fish",
        ingredients = {{id = "fish", qty = 1}},
        effect = "heal", amount = 15, duration = 0,
        desc = "Fresh grilled fish restores 15 HP."},
    {id = "travelers_bread", name = "Traveler's Bread",
        ingredients = {{id = "wheat", qty = 2}},
        effect = "stamina", amount = 10, duration = 0,
        desc = "Filling bread that reduces fatigue."},
    {id = "strength_meal", name = "Hunter's Feast",
        ingredients = {{id = "meat", qty = 2}, {id = "wheat", qty = 1}},
        effect = "buff_attack", amount = 3, duration = 5,
        desc = "+3 ATK for next 5 combats."},
    {id = "vitality_soup", name = "Vitality Soup",
        ingredients = {{id = "meat", qty = 1}, {id = "fish", qty = 1}},
        effect = "buff_maxhp", amount = 15, duration = 3,
        desc = "+15 Max HP for next 3 combats."},
    {id = "ale_boost", name = "Warming Ale",
        ingredients = {{id = "ale", qty = 1}},
        effect = "morale", amount = 20, duration = 0,
        desc = "Boosts party morale and conversation."},
}

-- Camp chat topics and dialogue
local CAMP_CHAT_TOPICS = {
    {id = "journey", name = "The Journey", icon = "\240\159\151\186",
        lines = {
            player = {"How are you holding up?", "What do you think of our travels?", "Any thoughts on where we're headed?"},
            responses = {
                "The road has been long, but I'm glad for the company.",
                "I've seen worse conditions. We'll manage.",
                "Each step brings us closer to our goal.",
                "I miss a warm bed, but adventure calls.",
                "The wilderness has its own beauty, doesn't it?",
            }
        }
    },
    {id = "stories", name = "Share Stories", icon = "\240\159\147\150",
        lines = {
            player = {"Tell me about yourself.", "Got any good stories?", "What brings you to adventuring?"},
            responses = {
                "I once fought a dragon... well, a large lizard. But it felt like a dragon!",
                "My village was peaceful until bandits came. That's when I learned to fight.",
                "I've traveled many roads. Each one taught me something new.",
                "Before this? I was a farmer's kid dreaming of adventure.",
                "Some say I'm running from my past. Maybe they're right.",
            }
        }
    },
    {id = "tactics", name = "Discuss Tactics", icon = "\226\154\148",
        lines = {
            player = {"Any combat tips?", "How should we approach our next fight?", "What's your fighting style?"},
            responses = {
                "Always watch your enemy's footwork. It reveals their next move.",
                "A good defense is worth two attacks.",
                "Protect the weak, strike the strong. That's my motto.",
                "Patience wins more battles than raw strength.",
                "Know when to retreat. There's no shame in living to fight again.",
            }
        }
    },
    {id = "dreams", name = "Talk Dreams", icon = "\240\159\146\173",
        lines = {
            player = {"What are your hopes for the future?", "Any dreams you're chasing?", "What will you do when this is over?"},
            responses = {
                "I dream of a small cottage by a stream. Simple, peaceful.",
                "Fame and fortune! What else is there?",
                "I want to find my family. They're out there somewhere.",
                "Maybe I'll write about our adventures. Future generations should know!",
                "Honestly? I haven't thought that far ahead.",
            }
        }
    },
}

-- Ambush encounter data
local CAMP_AMBUSH_CHANCE = {
    base = 0.25,           -- 25% base chance without guard
    perHour = 0.05,        -- +5% per hour of sleep
    guardReduction = 1.0,  -- Guard removes all chance
    weatherMod = {
        stormy = -0.15,    -- Storms drive creatures away
        rainy = -0.05,     -- Rain reduces movement
        foggy = 0.10,      -- Fog lets enemies approach
        clear = 0.05,      -- Clear nights are dangerous
    },
    shelterMod = {
        tent = -0.05,
        makeshift = 0.05,
        cave = -0.10,
    }
}

local AMBUSH_ENEMIES = {
    {name = "Wolves", enemies = {"wolf", "wolf"}, minLevel = 1, maxLevel = 5,
        announce = "Wolves circle your camp, eyes gleaming in the darkness!"},
    {name = "Bandits", enemies = {"bandit", "bandit"}, minLevel = 2, maxLevel = 8,
        announce = "Bandits emerge from the shadows, weapons drawn!"},
    {name = "Goblins", enemies = {"goblin", "goblin", "goblin"}, minLevel = 1, maxLevel = 6,
        announce = "Goblins emerge from the tunnels\226\128\148a resistance cell attacks! 'No one is illegal on stolen land!'"},
    {name = "Night Stalker", enemies = {"ghost"}, minLevel = 5, maxLevel = 12,
        announce = "A spectral creature materializes in your camp!"},
    {name = "Orc Scouts", enemies = {"orc", "orc"}, minLevel = 6, maxLevel = 15,
        announce = "Orc scouts stumble upon your camp and attack!"},
}

-- ============================================================================
-- EXPORTED DATA (for UI or other modules to reference)
-- ============================================================================

M.WEATHER_STATES = WEATHER_STATES
M.WEATHER_EFFECTS = WEATHER_EFFECTS
M.SHELTER_TYPES = SHELTER_TYPES
M.CAMP_FOODS = CAMP_FOODS
M.CAMP_CHAT_TOPICS = CAMP_CHAT_TOPICS
M.CAMP_AMBUSH_CHANCE = CAMP_AMBUSH_CHANCE
M.AMBUSH_ENEMIES = AMBUSH_ENEMIES

-- ============================================================================
-- FUNCTION LIST
-- ============================================================================

M.F_FUNCTIONS = {
    "canTravelSafely", "setupShelter", "restInShelter", "breakCamp",
    "enterCamp", "setCampGuard", "toggleCampfire", "canCookRecipe",
    "cookMeal", "getAmbushChance", "checkAmbush", "campRest", "campChat",
    "startTravelingHome", "updateTravelingHome", "cancelTravelingHome",
    "startPaidTravel", "updatePaidTravel", "cancelPaidTravel",
    "getCurrentWeather", "getWeatherEffects", "onNewDay",
    "updateWeather",
}

-- ============================================================================
-- REGISTER
-- ============================================================================

function M.register(s, f, deps)
    state = s
    F = f
    ENEMIES = deps.ENEMIES
    TextRPG = deps.TextRPG

    -- Bind the local log to the deps log
    log = deps.log

    for _, name in ipairs(M.F_FUNCTIONS) do
        if M[name] then
            F[name] = M[name]
        end
    end

    -- Export data tables needed by draw modules (not functions, so not in F_FUNCTIONS)
    F.WEATHER_EFFECTS = WEATHER_EFFECTS

    -- Set up module-local forward references so internal calls work
    updateWeather = M.updateWeather
end

-- ============================================================================
-- WEATHER SYSTEM
-- ============================================================================

M.getCurrentWeather = function()
    if not state then return "pleasant" end
    local season = state.season or "frosthollow"
    local timeOfDay = state.timeOfDay or 12

    -- Global fallback weather weights (original behavior)
    local globalWeatherWeights = {
        brightbloom  = {sunny = 2, cloudy = 2, rainy = 3, pleasant = 2, windy = 1},
        sunreign     = {sunny = 4, cloudy = 1, stormy = 1, pleasant = 3, windy = 1},
        ashwane      = {cloudy = 3, rainy = 2, foggy = 2, windy = 2, pleasant = 1},
        frosthollow  = {cloudy = 2, snowy = 3, stormy = 1, foggy = 1, windy = 2},
    }

    -- Try region-aware weather weights
    local weights = nil
    if state.world and state.world.useWorldGen then
        local playerX = state.world.playerX
        local playerY = state.world.playerY
        if playerX and playerY then
            local ok, WorldGen = pcall(require, "worldgen")
            if ok and WorldGen and WorldGen.getRegionAt then
                local region, subregion = WorldGen.getRegionAt(playerX, playerY)
                -- Subregion takes priority over parent region
                local climate = nil
                if subregion and subregion.id then
                    climate = REGION_CLIMATE_MAP[subregion.id]
                end
                if not climate and region and region.id then
                    climate = REGION_CLIMATE_MAP[region.id]
                end
                if climate and CLIMATE_WEATHER_WEIGHTS[climate] then
                    weights = CLIMATE_WEATHER_WEIGHTS[climate][season]
                end
            end
        end
    end

    -- Fallback to global season-based weights
    if not weights then
        weights = globalWeatherWeights[season] or globalWeatherWeights.frosthollow
    end

    local options = {}
    for weather, weight in pairs(weights) do
        for i = 1, weight do
            table.insert(options, weather)
        end
    end

    -- Use day count as seed for consistent weather per day
    if #options == 0 then return "pleasant" end
    local dayIndex = ((state.daysPassed or 0) % #options) + 1
    return options[((dayIndex + math.floor(timeOfDay / 6)) % #options) + 1]
end

-- Get weather effects for current weather
M.getWeatherEffects = function()
    local weatherType = M.getCurrentWeather()
    return WEATHER_EFFECTS[weatherType] or WEATHER_EFFECTS.pleasant
end

-- Handle daily world events (called when a new day passes)
M.onNewDay = function(dayNum)
    -- Spread lich blight once per day
    if dayNum > lastBlightSpreadDay then
        lastBlightSpreadDay = dayNum

        local WorldGen = require("worldgen")
        local activeLiches = WorldGen.getActiveLichLairs()

        if #activeLiches > 0 then
            local battleResults = WorldGen.spreadLichBlight()

            -- Report any lich vs village battles and generate rumors
            if battleResults and #battleResults > 0 then
                local RumorSystem = require("rumorsystem")
                RumorSystem.init(state)

                for _, battle in ipairs(battleResults) do
                    -- Generate rumor for this battle
                    RumorSystem.onLichBattle(battle, WorldGen)

                    if battle.isHolyIntervention then
                        -- Holy Capital intervention
                        if battle.defenderWins then
                            log("VICTORY! The Holy Capital's battalion has vanquished the lich!", {0.9, 0.8, 0.2})
                            log("The " .. battle.battalionSize .. " holy warriors defeated " .. battle.hordeSize .. " undead!", {0.8, 0.7, 0.3})
                        else
                            log("TRAGEDY! The Holy Capital's battalion has fallen to the lich!", {0.9, 0.2, 0.2})
                            log(battle.defenderCasualties .. " soldiers rise again as undead...", {0.7, 0.3, 0.4})
                        end
                    else
                        -- Village vs horde battle
                        if battle.defenderWins then
                            local mageText = battle.hadMageSupport and " (aided by royal mages)" or ""
                            log(battle.townName .. " repelled the undead horde!" .. mageText, {0.5, 0.8, 0.5})
                            log("Defenders: " .. battle.villagePopulation .. " vs Horde: " .. battle.hordeSize ..
                                " - " .. battle.attackerCasualties .. " undead destroyed", {0.6, 0.7, 0.5})
                        else
                            log(battle.townName .. " has fallen to the undead!", {0.9, 0.3, 0.3})
                            log(battle.villagePopulation .. " villagers slain. Their corpses join the horde...", {0.8, 0.4, 0.4})

                            -- Check how many villages have been destroyed
                            local destroyedCount = WorldGen.getDestroyedVillagesCount()
                            if destroyedCount >= 2 then
                                log("The Holy Capital is mobilizing a battalion against the lich threat!", {0.9, 0.7, 0.3})
                            end
                        end
                    end
                end
            end

            -- Generate lich activity rumors periodically
            if math.random() < 0.2 then  -- 20% chance per day when lich is active
                local RumorSystem = require("rumorsystem")
                RumorSystem.init(state)
                for _, lich in ipairs(activeLiches) do
                    RumorSystem.onLichActivity(lich, WorldGen)
                end
            end

            -- Warn player about corruption level
            local corruptionLevel = WorldGen.getWorldCorruptionLevel()
            if corruptionLevel >= 75 then
                log("The world is overwhelmed by undead corruption! Seek out the lich lairs!", {0.9, 0.2, 0.2})
            elseif corruptionLevel >= 50 then
                log("Corruption spreads across the land. The liches grow stronger...", {0.8, 0.4, 0.3})
            elseif corruptionLevel >= 25 then
                log("Dark corruption seeps into the world from the lich domains...", {0.6, 0.4, 0.5})
            end
        end
    end

    -- Process property income, taxes, and attacks
    if state.player and state.player.properties then
        local PropertySystem = require("propertysystem")
        PropertySystem.init(state)  -- Ensure PropertySystem has current state
        local report = PropertySystem.onDayAdvance(dayNum, 24)

        -- Report income
        if report.income and report.income > 0 then
            log("Property income: +" .. report.income .. "g", {0.5, 0.8, 0.5})
        end

        -- Report taxes
        if report.taxes and report.taxes > 0 then
            log("Property taxes: -" .. report.taxes .. "g", {0.8, 0.7, 0.4})
        end

        -- Report attacks on land claims
        if report.attacks and #report.attacks > 0 then
            for _, attack in ipairs(report.attacks) do
                if attack.defended then
                    log("Your " .. (attack.structureName or "property") .. " was attacked but defenses held!", {0.6, 0.7, 0.5})
                else
                    log("Your " .. (attack.structureName or "property") .. " was attacked! Damage: " .. (attack.damage or 0), {0.9, 0.4, 0.4})
                end
            end
        end

        -- Lumber regeneration and settlement consumption
        local WorldGen = require("worldgen")
        PropertySystem.regenerateForests(WorldGen)

        local consumptionLog = PropertySystem.settlementLumberConsumption(WorldGen)
        for _, log_entry in ipairs(consumptionLog) do
            if log_entry.deforested then
                log("Forest near " .. log_entry.settlement .. " has been depleted!", {0.8, 0.6, 0.3})
            end
        end
    end

    -- Update rumor system
    local RumorSystem = require("rumorsystem")
    RumorSystem.init(state)
    local WorldGen = require("worldgen")
    RumorSystem.spreadRumors(WorldGen)
    RumorSystem.updateSerialKillers()

    -- Small chance to spawn a serial killer event
    if math.random() < 0.005 then  -- 0.5% chance per day
        local anchorTowns = WorldGen.getAnchorTowns()
        if anchorTowns and #anchorTowns > 0 then
            local town = anchorTowns[math.random(#anchorTowns)]
            if town and not town.type == "capital" then  -- Not in capitals
                RumorSystem.spawnSerialKiller(town.id, town.name, town.position.x, town.position.y)
            end
        end
    end
end

-- Update weather state (call when time passes)
M.updateWeather = function(hoursElapsed)
    if not state.weather then
        state.weather = {current = "pleasant", hoursExposed = 0, sheltered = false}
    end

    local newWeather = M.getCurrentWeather()
    local effects = WEATHER_EFFECTS[newWeather] or WEATHER_EFFECTS.pleasant

    -- Weather changed?
    if state.weather.current ~= newWeather then
        state.weather.current = newWeather
        state.weather.hoursExposed = 0
        if effects.dangerous then
            log(effects.icon .. " " .. effects.name .. "! " .. effects.desc, {0.9, 0.5, 0.3})
        elseif effects.needsShelter then
            log(effects.icon .. " " .. effects.name .. ". " .. effects.desc, {0.7, 0.7, 0.8})
        end
    end

    -- Track exposure if not sheltered
    if not state.weather.sheltered and (effects.dangerous or effects.needsShelter) then
        state.weather.hoursExposed = state.weather.hoursExposed + hoursElapsed

        -- Take damage from dangerous weather
        if effects.dangerous and effects.damagePerHour then
            local damage = math.floor(effects.damagePerHour * hoursElapsed)
            if damage > 0 and state.player then
                state.player.hp = math.max(1, state.player.hp - damage)
                log("The " .. effects.name:lower() .. " weather damages you for " .. damage .. " HP!", {0.9, 0.3, 0.3})
            end
        end
    end
end

-- ============================================================================
-- TRAVEL SAFETY
-- ============================================================================

-- Check if player can travel safely
M.canTravelSafely = function()
    local effects = M.getWeatherEffects()
    if effects.dangerous and not state.weather.sheltered then
        return false, "Too dangerous to travel in this weather!"
    end
    return true, nil
end

-- ============================================================================
-- SHELTER & CAMPING
-- ============================================================================

-- Set up camp/shelter
M.setupShelter = function(shelterType)
    local shelter = nil
    for _, s in ipairs(SHELTER_TYPES) do
        if s.id == shelterType then
            shelter = s
            break
        end
    end
    if not shelter then return false, "Invalid shelter type" end

    -- Check requirements
    if shelter.townOnly and state.phase ~= "town" then
        return false, "Only available in towns"
    end
    if shelter.requiresItem then
        local hasItem = false
        local getTQInventory = F.getTQInventory
        local inventory = getTQInventory and getTQInventory() or {}
        for _, item in ipairs(inventory) do
            if item.id == shelter.requiresItem then hasItem = true break end
        end
        if not hasItem then return false, "You need a " .. shelter.requiresItem end
    end
    if shelter.cost > 0 and (state.player.gold or 0) < shelter.cost then
        return false, "Not enough gold"
    end
    if shelter.chanceToFind and math.random() > shelter.chanceToFind then
        return false, "Couldn't find suitable shelter"
    end

    -- Pay cost
    if shelter.cost > 0 then
        state.player.gold = (state.player.gold or 0) - shelter.cost
    end

    -- Set up shelter
    state.weather.sheltered = true
    state.weather.shelterType = shelter
    state.camping.active = true
    state.camping.type = shelter
    state.camping.hoursRested = 0

    log("You " .. shelter.name:lower() .. ". " .. shelter.desc, {0.5, 0.8, 0.5})
    return true, nil
end

-- Rest in shelter
M.restInShelter = function(hours)
    if not state.camping.active then return false, "No shelter set up" end

    local shelter = state.camping.type
    local quality = shelter.quality or 0.5

    -- Pass time
    state.timeOfDay = state.timeOfDay + hours
    while state.timeOfDay >= 24 do
        state.timeOfDay = state.timeOfDay - 24
        state.daysPassed = state.daysPassed + 1
        F.onNewDay(state.daysPassed)
    end

    -- Heal based on shelter quality
    local healAmount = math.floor(hours * 3 * quality)
    local manaRegen = math.floor(hours * 2 * quality)
    if state.player then
        local actualHeal = math.min(state.player.maxHP - state.player.hp, healAmount)
        state.player.hp = math.min(state.player.maxHP, state.player.hp + healAmount)
        state.player.mana = math.min(state.player.maxMana, state.player.mana + manaRegen)
        -- Track healing for race unlock
        state.stats.healingDone = (state.stats.healingDone or 0) + actualHeal
    end

    state.camping.hoursRested = state.camping.hoursRested + hours
    state.weather.hoursExposed = 0  -- Reset exposure

    log("Rested for " .. hours .. " hours. Recovered " .. healAmount .. " HP and " .. manaRegen .. " mana.", {0.5, 0.8, 0.5})

    -- Update weather
    updateWeather(hours)
    return true, nil
end

-- Break camp
M.breakCamp = function()
    state.camping.active = false
    state.camping.type = nil
    state.camping.guard = nil
    state.camping.guardIndex = nil
    state.camping.campfireLit = false
    state.camping.activity = "main"
    state.weather.sheltered = false
    state.weather.shelterType = nil
    log("You pack up and prepare to move.", {0.7, 0.7, 0.7})
end

-- Set up camp (enters camp phase)
M.enterCamp = function()
    -- Ensure weather state exists
    if not state.weather then
        state.weather = {
            current = "pleasant",
            hoursExposed = 0,
            sheltered = false,
            shelterType = nil,
            lastUpdate = 0,
        }
    end

    -- Ensure camping state exists
    if not state.camping then
        state.camping = {
            active = false,
            type = nil,
            hoursRested = 0,
            guard = nil,
            guardIndex = nil,
            campfireLit = false,
            cookedMeals = {},
            chatHistory = {},
            activity = "main",
            morale = 50,
            lastAmbushCheck = 0,
        }
    end

    if not state.camping.active then
        -- Auto-setup makeshift shelter if no shelter exists
        local success, err = F.setupShelter("makeshift")
        if not success then
            log(err or "Couldn't set up camp here.", {0.9, 0.5, 0.3})
            return false
        end
    end
    state.camping.activity = "main"
    state.phase = "camp"
    return true
end

-- ============================================================================
-- CAMP GUARD
-- ============================================================================

-- Set or remove guard
M.setCampGuard = function(guardType, guardIndex)
    if guardType == nil then
        -- Remove guard
        if state.camping.guard then
            if state.camping.guard == "player" then
                log("You stop keeping watch.", {0.7, 0.7, 0.7})
            else
                log(state.camping.guard .. " stops keeping watch.", {0.7, 0.7, 0.7})
            end
        end
        state.camping.guard = nil
        state.camping.guardIndex = nil
    elseif guardType == "player" then
        state.camping.guard = "player"
        state.camping.guardIndex = nil
        log("You take watch, keeping an eye out for danger.", {0.6, 0.8, 0.6})
    else
        -- Party member guard
        local party = state.player.party or {}
        if guardIndex and party[guardIndex] and party[guardIndex].hp > 0 then
            state.camping.guard = party[guardIndex].name
            state.camping.guardIndex = guardIndex
            log(party[guardIndex].name .. " takes watch, allowing others to rest safely.", {0.6, 0.8, 0.6})
        else
            return false, "That companion can't keep watch"
        end
    end
    return true
end

-- ============================================================================
-- CAMPFIRE & COOKING
-- ============================================================================

-- Toggle campfire
M.toggleCampfire = function()
    state.camping.campfireLit = not state.camping.campfireLit
    if state.camping.campfireLit then
        log("You light a campfire. The warmth is comforting.", {1, 0.7, 0.3})
        state.camping.morale = math.min(100, (state.camping.morale or 50) + 10)
    else
        log("You extinguish the campfire.", {0.6, 0.6, 0.6})
    end
end

-- Check if player has ingredients for a recipe
M.canCookRecipe = function(recipe)
    local getTQInventory = F.getTQInventory
    local inventory = getTQInventory and getTQInventory() or {}
    for _, ing in ipairs(recipe.ingredients) do
        local found = 0
        for _, item in ipairs(inventory) do
            if item.id == ing.id then
                found = found + (item.quantity or 1)
            end
        end
        if found < ing.qty then
            return false, ing.id
        end
    end
    return true
end

-- Cook a meal at camp
M.cookMeal = function(recipeId)
    if not state.camping.campfireLit then
        return false, "Light the campfire first!"
    end

    local recipe = nil
    for _, r in ipairs(CAMP_FOODS) do
        if r.id == recipeId then
            recipe = r
            break
        end
    end
    if not recipe then return false, "Unknown recipe" end

    local canCook, missing = M.canCookRecipe(recipe)
    if not canCook then
        return false, "Missing ingredient: " .. (missing or "unknown")
    end

    -- Consume ingredients
    for _, ing in ipairs(recipe.ingredients) do
        if Backpack and Backpack.removeItem then
            for _ = 1, ing.qty do
                Backpack.removeItem(ing.id, 1)
            end
        end
    end

    -- Apply effect immediately or store buff
    if recipe.effect == "heal" then
        local actualHeal = math.min(state.player.maxHP - state.player.hp, recipe.amount)
        state.player.hp = math.min(state.player.maxHP, state.player.hp + recipe.amount)
        -- Track healing for race unlock
        state.stats.healingDone = (state.stats.healingDone or 0) + actualHeal
        log("You eat " .. recipe.name .. ". Restored " .. recipe.amount .. " HP!", {0.5, 0.9, 0.5})
    elseif recipe.effect == "buff_attack" then
        table.insert(state.camping.cookedMeals, {
            effect = "attack",
            amount = recipe.amount,
            duration = recipe.duration,
        })
        log("You eat " .. recipe.name .. ". +" .. recipe.amount .. " ATK for next " .. recipe.duration .. " combats!", {0.9, 0.7, 0.3})
    elseif recipe.effect == "buff_maxhp" then
        table.insert(state.camping.cookedMeals, {
            effect = "maxhp",
            amount = recipe.amount,
            duration = recipe.duration,
        })
        log("You eat " .. recipe.name .. ". +" .. recipe.amount .. " Max HP for next " .. recipe.duration .. " combats!", {0.9, 0.5, 0.5})
    elseif recipe.effect == "morale" then
        state.camping.morale = math.min(100, (state.camping.morale or 50) + recipe.amount)
        log("You share " .. recipe.name .. " with the party. Morale boosted!", {0.9, 0.8, 0.3})
    elseif recipe.effect == "stamina" then
        state.player.hp = math.min(state.player.maxHP, state.player.hp + recipe.amount)
        log("You eat " .. recipe.name .. ". Feeling refreshed!", {0.6, 0.8, 0.6})
    end

    state.camping.morale = math.min(100, (state.camping.morale or 50) + 5)
    return true
end

-- ============================================================================
-- AMBUSH SYSTEM
-- ============================================================================

-- Calculate ambush chance
M.getAmbushChance = function(restHours)
    local chance = CAMP_AMBUSH_CHANCE.base
    chance = chance + (restHours * CAMP_AMBUSH_CHANCE.perHour)

    -- Guard negates all ambush chance
    if state.camping.guard then
        return 0
    end

    -- Weather modifier
    local weather = M.getCurrentWeather and M.getCurrentWeather() or "pleasant"
    local weatherMod = CAMP_AMBUSH_CHANCE.weatherMod[weather] or 0
    chance = chance + weatherMod

    -- Shelter modifier
    local shelter = state.camping.type
    if shelter then
        local shelterMod = CAMP_AMBUSH_CHANCE.shelterMod[shelter.id] or 0
        chance = chance + shelterMod
    end

    -- Night is more dangerous
    local hour = state.timeOfDay or 12
    if hour >= 22 or hour <= 5 then
        chance = chance + 0.10
    end

    -- Dungeons are much more dangerous for camping (50% increase)
    if state.inDungeon then
        chance = chance * 1.5
    end

    return math.max(0, math.min(0.9, chance))  -- Cap at 90% (higher cap for dungeons)
end

-- Check for ambush when sleeping
M.checkAmbush = function(restHours)
    local chance = M.getAmbushChance(restHours)
    if math.random() > chance then
        return false  -- No ambush
    end

    -- Pick appropriate enemies for player level
    local level = state.player.level or 1
    local validAmbushes = {}
    for _, amb in ipairs(AMBUSH_ENEMIES) do
        if level >= amb.minLevel and level <= amb.maxLevel then
            table.insert(validAmbushes, amb)
        end
    end

    if #validAmbushes == 0 then
        return false  -- No valid ambush for this level
    end

    local ambush = validAmbushes[math.random(#validAmbushes)]

    log("AMBUSH! " .. ambush.announce, {1, 0.3, 0.3})

    -- Generate enemies using proper enemy creation
    local enemies = {}
    for _, enemyId in ipairs(ambush.enemies) do
        -- Find enemy template in ENEMIES table
        local enemyType = nil
        for _, e in ipairs(ENEMIES) do
            if e.id == enemyId then
                enemyType = e
                break
            end
        end

        if enemyType and F.createEnemyInstance then
            local enemy = F.createEnemyInstance(enemyType, level)
            table.insert(enemies, enemy)
        end
    end

    if #enemies > 0 then
        -- Start combat (player is surprised - enemies get first turn)
        F.startCombat(enemies)
        state.combat.playerSurprised = true
        state.combat.isPlayerTurn = false
        -- Find first enemy turn
        for i, turn in ipairs(state.combat.turnOrder) do
            if turn.type == "enemy" then
                state.combat.currentTurnIndex = i
                state.combat.currentActorIndex = turn.index
                break
            end
        end
        return true
    end

    return false
end

-- ============================================================================
-- CAMP REST & CHAT
-- ============================================================================

-- Rest at camp with ambush check
M.campRest = function(hours)
    -- Check for guard
    local hasGuard = state.camping.guard ~= nil
    local guardIsPlayer = state.camping.guard == "player"

    if guardIsPlayer then
        log("You can't rest while keeping watch!", {0.9, 0.6, 0.3})
        return false, "Can't rest while on guard duty"
    end

    -- Check for ambush
    if not hasGuard then
        local wasAmbushed = M.checkAmbush(hours)
        if wasAmbushed then
            state.phase = "combat"
            return false, "Ambushed!"
        end
    elseif state.camping.guardIndex then
        -- Companion was on guard - they don't rest
        if state.player.party then
            local companion = state.player.party[state.camping.guardIndex]
            if companion then
                log(companion.name .. " kept watch while you rested.", {0.5, 0.7, 0.9})
            end
        end
    end

    -- Rest was successful
    return M.restInShelter(hours)
end

-- Camp chat with party
M.campChat = function(topicId)
    local party = state.player.party or {}
    if #party == 0 then
        log("You sit by the fire, contemplating your journey alone.", {0.6, 0.6, 0.7})
        state.camping.morale = math.min(100, (state.camping.morale or 50) + 3)
        return true
    end

    local topic = nil
    for _, t in ipairs(CAMP_CHAT_TOPICS) do
        if t.id == topicId then
            topic = t
            break
        end
    end
    if not topic then return false, "Unknown topic" end

    -- Pick a random companion to respond
    local aliveCompanions = {}
    for i, comp in ipairs(party) do
        if comp.hp > 0 then
            table.insert(aliveCompanions, {comp = comp, index = i})
        end
    end

    if #aliveCompanions == 0 then
        log("Your companions are too injured to chat.", {0.7, 0.5, 0.5})
        return false
    end

    local responder = aliveCompanions[math.random(#aliveCompanions)]
    local playerLine = topic.lines.player[math.random(#topic.lines.player)]
    local response = topic.lines.responses[math.random(#topic.lines.responses)]

    log("You: \"" .. playerLine .. "\"", {0.5, 0.8, 0.5})
    log(responder.comp.name .. ": \"" .. response .. "\"", {0.7, 0.8, 1})

    -- Store in chat history
    table.insert(state.camping.chatHistory, {
        topic = topic.name,
        speaker = responder.comp.name,
        line = response,
    })

    -- Boost morale
    local moraleGain = state.camping.campfireLit and 8 or 5
    state.camping.morale = math.min(100, (state.camping.morale or 50) + moraleGain)

    return true
end

-- ============================================================================
-- TRAVELING HOME
-- ============================================================================

-- Start traveling home
M.startTravelingHome = function()
    if not state.world.homeTown then
        log("You have no home to return to!", {0.9, 0.5, 0.3})
        return false
    end

    if #state.world.pathHistory == 0 then
        log("You're already at a town!", {0.7, 0.7, 0.5})
        return false
    end

    -- Check weather
    local weatherFx = M.getWeatherEffects()
    if weatherFx.dangerous then
        log("Too dangerous to travel in this weather!", {0.9, 0.4, 0.3})
        return false
    end

    -- Break camp if active
    if state.camping and state.camping.active then
        M.breakCamp()
    end

    -- Calculate travel speed (affected by mount, weather, encumbrance)
    local distance = #state.world.pathHistory
    local weatherFx2 = M.getWeatherEffects()
    local baseSpeed = weatherFx2.travelSpeed
    local playerMight = state.player.stats and state.player.stats.MIGHT or 10
    local mountSpeedMult = Backpack.getTravelSpeedMultiplier(playerMight)
    local finalSpeed = baseSpeed * mountSpeedMult

    -- Calculate travel time estimate (1 hour base per tile, reduced by speed)
    local timePerTile = 1 / finalSpeed
    local timeEstimate = math.ceil(distance * timePerTile)

    -- Calculate animation speed (faster mounts = faster animation)
    -- Base: 0.4 seconds per tile at 1x speed
    local baseStepDelay = 0.4
    local animStepDelay = math.max(0.08, baseStepDelay / finalSpeed)  -- Min 0.08s to stay visible

    -- Calculate encounter chance (reduced by mounts)
    local baseEncounterChance = 0.1  -- 10% base when traveling home
    local encounterReduction = Backpack.getMountEncounterReduction()
    local finalEncounterChance = baseEncounterChance * encounterReduction

    state.travelingHome = {
        active = true,
        pathIndex = #state.world.pathHistory,  -- Start from end of path
        timer = 0,
        stepDelay = animStepDelay,  -- Seconds between visual steps (faster with mounts)
        totalSteps = distance,
        currentStep = 0,
        encounterChance = finalEncounterChance,  -- Lower encounter chance (reduced by mounts)
        startTime = state.timeOfDay,
        speedMult = finalSpeed,  -- Store for time calculations
        timePerTile = timePerTile,  -- Store for accurate time tracking
    }

    state.phase = "traveling_home"
    local mountMsg = finalSpeed > 1.1 and " (Mount: " .. string.format("%.1fx", finalSpeed) .. " speed)" or ""
    local homeTownName = (state.world.homeTown and state.world.homeTown.town and state.world.homeTown.town.name) or "home"
    log("Heading back to " .. homeTownName .. "... (Est. " .. timeEstimate .. " hours)" .. mountMsg, {0.6, 0.8, 0.6})
    return true
end

-- Update traveling home (called each frame)
M.updateTravelingHome = function(dt)
    if not state.travelingHome.active then return end

    state.travelingHome.timer = state.travelingHome.timer + dt

    if state.travelingHome.timer >= state.travelingHome.stepDelay then
        state.travelingHome.timer = 0
        state.travelingHome.currentStep = state.travelingHome.currentStep + 1

        -- Move to next position in path
        if state.travelingHome.pathIndex > 0 then
            local pos = state.world.pathHistory[state.travelingHome.pathIndex]
            state.world.playerX = pos.x
            state.world.playerY = pos.y
            state.travelingHome.pathIndex = state.travelingHome.pathIndex - 1

            -- Remove from path
            table.remove(state.world.pathHistory)

            -- Small chance of encounter while traveling
            if math.random() < state.travelingHome.encounterChance then
                state.travelingHome.active = false
                local enemies = F.generateEncounter(state.player.level)
                log("Ambushed on the way home!", {0.9, 0.5, 0.3})
                F.startCombat(enemies)
                return
            end

            -- Update weather/time (use mount-adjusted time per tile)
            local timePerTile = state.travelingHome.timePerTile or 0.5
            updateWeather(timePerTile)
        else
            -- Arrived at home!
            state.travelingHome.active = false
            local home = state.world.homeTown
            state.world.playerX = home.x
            state.world.playerY = home.y
            state.world.currentTown = home.town
            state.world.pathHistory = {}
            state.phase = "town"

            -- Calculate time passed (use mount-adjusted time per tile)
            local timePerTile = state.travelingHome.timePerTile or 0.5
            local timePassed = state.travelingHome.totalSteps * timePerTile
            state.timeOfDay = state.timeOfDay + timePassed
            while state.timeOfDay >= 24 do
                state.timeOfDay = state.timeOfDay - 24
                state.daysPassed = state.daysPassed + 1
                F.onNewDay(state.daysPassed)
            end

            log("Arrived safely at " .. home.town.name .. "! (Traveled " .. math.floor(timePassed) .. " hours)", {0.5, 0.9, 0.5})
        end
    end
end

-- Cancel traveling home
M.cancelTravelingHome = function()
    if state.travelingHome.active then
        state.travelingHome.active = false
        state.phase = "map"
        log("Stopped traveling.", {0.7, 0.7, 0.5})
    end
end

-- ============================================================================
-- PAID TRAVEL (CARRIAGE)
-- ============================================================================

-- Start paid travel to an anchor city (carriage service)
M.startPaidTravel = function(destinationTown, distance)
    if not destinationTown then
        log("No destination specified!", {0.9, 0.5, 0.3})
        return false
    end

    -- Paid travel uses carriage: 2x speed, 90% less encounters
    local carriageSpeed = 2.0
    local timePerTile = 1 / carriageSpeed  -- 0.5 hours per tile
    local timeEstimate = math.ceil(distance * timePerTile)

    -- Faster animation for carriage
    local animStepDelay = 0.2  -- Fast animation (carriage)

    state.paidTravel = {
        active = true,
        destination = destinationTown,
        destX = destinationTown.position.x,
        destY = destinationTown.position.y,
        timer = 0,
        stepDelay = animStepDelay,
        totalSteps = distance,
        currentStep = 0,
        encounterChance = 0.01,  -- 1% encounter chance (90% reduction from normal 10%)
        startTime = state.timeOfDay,
        speedMult = carriageSpeed,
        timePerTile = timePerTile,
        startX = state.world.playerX,
        startY = state.world.playerY,
    }

    state.phase = "paid_travel"
    log("The carriage departs for " .. destinationTown.name .. "... (Est. " .. timeEstimate .. " hours)", {0.5, 0.7, 0.9})
    return true
end

-- Update paid travel (called each frame)
M.updatePaidTravel = function(dt)
    if not state.paidTravel or not state.paidTravel.active then return end

    state.paidTravel.timer = state.paidTravel.timer + dt

    if state.paidTravel.timer >= state.paidTravel.stepDelay then
        state.paidTravel.timer = 0
        state.paidTravel.currentStep = state.paidTravel.currentStep + 1

        -- Calculate interpolated position
        local progress = state.paidTravel.currentStep / state.paidTravel.totalSteps
        local newX = math.floor(state.paidTravel.startX + (state.paidTravel.destX - state.paidTravel.startX) * progress + 0.5)
        local newY = math.floor(state.paidTravel.startY + (state.paidTravel.destY - state.paidTravel.startY) * progress + 0.5)

        state.world.playerX = newX
        state.world.playerY = newY

        -- Update weather/time (use carriage-adjusted time per tile)
        local timePerTile = state.paidTravel.timePerTile or 0.5
        updateWeather(timePerTile)

        -- Very small chance of encounter (bandits attacking carriage)
        if math.random() < state.paidTravel.encounterChance then
            state.paidTravel.active = false
            local enemies = F.generateEncounter(state.player.level)
            log("Bandits attack the carriage!", {0.9, 0.4, 0.3})
            F.startCombat(enemies)
            return
        end

        -- Check if arrived
        if state.paidTravel.currentStep >= state.paidTravel.totalSteps then
            -- Arrived at destination!
            state.paidTravel.active = false
            local dest = state.paidTravel.destination
            state.world.playerX = dest.position.x
            state.world.playerY = dest.position.y

            -- Load the destination town
            local WorldGen = require("worldgen")
            local townData = WorldGen.getTownAtPosition(dest.position.x, dest.position.y)
            if townData then
                state.world.currentTown = townData
            else
                -- Create basic town data from anchor definition
                state.world.currentTown = {
                    id = dest.id,
                    name = dest.name,
                    type = dest.type,
                    population = dest.population,
                    level = dest.level,
                    region = dest.region,
                }
            end

            -- Clear path history (we teleported)
            state.world.pathHistory = {}

            state.phase = "town"

            -- Calculate time passed
            local timePassed = state.paidTravel.totalSteps * (state.paidTravel.timePerTile or 0.5)
            state.timeOfDay = state.timeOfDay + timePassed
            while state.timeOfDay >= 24 do
                state.timeOfDay = state.timeOfDay - 24
                state.daysPassed = state.daysPassed + 1
                F.onNewDay(state.daysPassed)
            end

            log("The carriage arrives at " .. dest.name .. "! (Traveled " .. math.floor(timePassed) .. " hours)", {0.5, 0.9, 0.5})
            if TextRPG and TextRPG.save then
                TextRPG.save()
            end
        end
    end
end

-- Cancel paid travel
M.cancelPaidTravel = function()
    if state.paidTravel and state.paidTravel.active then
        state.paidTravel.active = false
        state.phase = "map"
        log("You leave the carriage early.", {0.7, 0.7, 0.5})
    end
end

return M
