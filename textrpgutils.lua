-- TextRPG Utility Functions
-- Consolidates small helper functions to reduce local variable count in main file

local Utils = {}

-- Font cache for performance
local FontCache = require("fontcache")
function Utils.getFont(size)
    return FontCache.get(size)
end

-- Get karma level info based on current karma score
function Utils.getKarmaLevel(karma, KARMA_LEVELS)
    for _, level in ipairs(KARMA_LEVELS) do
        if karma >= level.min and karma <= level.max then
            return level
        end
    end
    return KARMA_LEVELS[3] -- Default to Neutral
end

-- Get detection description
function Utils.getDetectionDescription(detection)
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

-- Get portrait image for a character
function Utils.getPortraitImage(id, portraitMappings, UIAssets)
    local portraitName = portraitMappings[id]
    if portraitName then
        return UIAssets.getCharacter(portraitName)
    end
    return nil
end

-- Sunlight damage functions: canonical versions live in rpg_vampire.lua
-- (M.isInSunlight, M.calculateSunlightDamage) and are wired into the F-table.
-- Removed duplicate implementations that were never required by any module.

-- Get stat modifier
function Utils.getStatModifier(statValue)
    return math.floor((statValue - 10) / 2)
end

-- Get reputation level
function Utils.getReputationLevel(rep)
    if rep >= 75 then return "Exalted", {1, 0.8, 0} end
    if rep >= 50 then return "Revered", {0, 1, 0} end
    if rep >= 25 then return "Honored", {0, 0.8, 0} end
    if rep >= 0 then return "Friendly", {0, 0.6, 0} end
    if rep >= -25 then return "Neutral", {0.7, 0.7, 0.7} end
    if rep >= -50 then return "Unfriendly", {1, 0.5, 0} end
    if rep >= -75 then return "Hostile", {1, 0.3, 0} end
    return "Hated", {1, 0, 0}
end

-- Get time of day period
function Utils.getTimeOfDayPeriod(hour)
    if hour >= 0 and hour < 6 then
        return "night"
    elseif hour >= 6 and hour < 12 then
        return "morning"
    elseif hour >= 12 and hour < 18 then
        return "afternoon"
    elseif hour >= 18 and hour < 22 then
        return "evening"
    else
        return "night"
    end
end

-- Get time icon
function Utils.getTimeIcon(hour)
    if hour >= 6 and hour < 12 then
        return "🌅"  -- Morning
    elseif hour >= 12 and hour < 18 then
        return "☀️"  -- Afternoon
    elseif hour >= 18 and hour < 22 then
        return "🌆"  -- Evening
    else
        return "🌙"  -- Night
    end
end

-- Generate companion name
function Utils.generateCompanionName()
    local names = {
        "Aria", "Brom", "Cade", "Dana", "Eren", "Finn", "Gwen", "Hale",
        "Iris", "Jax", "Kara", "Liam", "Maya", "Nora", "Owen", "Pax",
        "Quinn", "Ren", "Sara", "Tara", "Uma", "Vale", "Wren", "Xara",
        "Yara", "Zane"
    }
    return names[math.random(#names)]
end

return Utils
