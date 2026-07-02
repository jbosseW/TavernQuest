-- ============================================================================
-- STEALTH SYSTEM
-- Comprehensive stealth mechanics for tactical combat, pre-combat encounters,
-- indoor lighting, detection zones, and stealth equipment integration.
-- ============================================================================
--
-- This module integrates with:
--   tactical_combat.lua  - In-combat stealth, initiative, hidden status
--   tactical_combat_ai.lua - AI awareness of hidden units
--   tactical_combat_ui.lua - Stealth UI overlays, light level rendering
--   mapenemies.lua - Pre-combat stealth approach, stealth kill/knockout
--   textrpg.lua - Detection formula, stealth mode, equipment bonuses
--
-- Reference design principles (from Mark Brown / GMTK, GDC talks):
--   - Hitman (2016): Multi-zone detection, NPC awareness states, disguises
--   - Dishonored: Light/dark matters, vertical play, lethal/nonlethal choice
--   - Into the Breach: Turn-based tactical transparency, telegraphed danger
--   - Fire Emblem: Fog of War on grid, vision ranges per unit
--   - XCOM 2: Concealment phase before combat, ambush mechanics
-- ============================================================================

local StealthSystem = {}
local TileUtils = require("tileutils")

-- ============================================================================
-- SECTION 1: CONSTANTS AND TUNING VALUES
-- ============================================================================

StealthSystem.VERSION = "1.0.0"

-- Detection thresholds (percentage ranges)
StealthSystem.DETECTION_THRESHOLDS = {
    UNDETECTED =    {min = 0,  max = 20,  label = "Undetected",  color = {0.2, 0.8, 0.2}},
    SUSPICIOUS =    {min = 21, max = 50,  label = "Suspicious",  color = {0.9, 0.9, 0.2}},
    ALERT =         {min = 51, max = 80,  label = "Alert",       color = {0.9, 0.6, 0.2}},
    DETECTED =      {min = 81, max = 100, label = "Detected",    color = {0.9, 0.2, 0.2}},
}

-- NPC awareness states
StealthSystem.AWARENESS = {
    UNAWARE =       {id = "unaware",    color = {0.2, 0.8, 0.2}, label = "Unaware"},
    SUSPICIOUS =    {id = "suspicious", color = {0.9, 0.9, 0.2}, label = "Suspicious"},
    ALERT =         {id = "alert",      color = {0.9, 0.6, 0.2}, label = "Alert"},
    COMBAT =        {id = "combat",     color = {0.9, 0.2, 0.2}, label = "Combat"},
}

-- Indoor light levels
StealthSystem.LIGHT_LEVEL = {
    BRIGHT = "bright",  -- 3+ sources or windows during day
    DIM =    "dim",     -- 1-2 sources
    DARK =   "dark",    -- 0 sources, nighttime
}

-- Light source definitions
StealthSystem.LIGHT_SOURCES = {
    torch = {
        name = "Torch",
        type = "wall",
        canSnuff = true,
        snuffAction = "snuff",
        snuffNoise = 0.3,       -- 30% chance NPCs within 2 tiles hear
        snuffTurns = 1,
        lightRadius = 3,        -- tiles of illumination
        brightness = 1.0,
        icon = "T",
        color = {1.0, 0.7, 0.3},
    },
    candle = {
        name = "Candle",
        type = "table",
        canSnuff = true,
        snuffAction = "blow",
        snuffNoise = 0.0,       -- silent
        snuffTurns = 1,
        lightRadius = 1,
        brightness = 0.5,
        icon = "c",
        color = {1.0, 0.9, 0.5},
    },
    lantern = {
        name = "Lantern",
        type = "portable",
        canSnuff = true,
        snuffAction = "douse",
        snuffNoise = 0.15,      -- 15% if player's, 35% if NPC's
        snuffNoiseNPC = 0.35,
        snuffTurns = 1,
        lightRadius = 2,
        brightness = 0.8,
        icon = "L",
        color = {1.0, 0.85, 0.4},
    },
    fireplace = {
        name = "Fireplace",
        type = "room",
        canSnuff = false,
        lightRadius = 4,
        brightness = 1.2,
        icon = "F",
        color = {1.0, 0.5, 0.2},
    },
    window = {
        name = "Window",
        type = "wall",
        canSnuff = false,
        lightRadius = 3,
        brightness = 1.0,       -- only during day, 0 at night
        daytimeOnly = true,
        icon = "W",
        color = {0.9, 0.9, 1.0},
    },
    magical_light = {
        name = "Magical Light",
        type = "ceiling",
        canSnuff = false,
        lightRadius = 4,
        brightness = 1.5,
        icon = "M",
        color = {0.6, 0.8, 1.0},
    },
}

-- Outdoor stealth modifiers
StealthSystem.OUTDOOR_MODIFIERS = {
    -- Time of day
    time = {
        night =     { mod = 0.40, label = "+40% stealth (Night)" },
        dawn =      { mod = 0.20, label = "+20% stealth (Dawn)" },
        dusk =      { mod = 0.20, label = "+20% stealth (Dusk)" },
        day =       { mod = -0.20, label = "-20% stealth (Day)" },
    },
    -- Weather
    weather = {
        foggy =     { mod = 0.30, label = "+30% stealth (Fog)" },
        rainy =     { mod = 0.30, label = "+30% stealth (Rain)" },
        stormy =    { mod = 0.50, label = "+50% stealth (Storm)" },
        snowy =     { mod = 0.20, label = "+20% stealth (Snow)" },
        cloudy =    { mod = 0.10, label = "+10% stealth (Cloudy)" },
        sunny =     { mod = 0.00, label = "No modifier (Clear)" },
        pleasant =  { mod = 0.00, label = "No modifier (Pleasant)" },
        windy =     { mod = 0.05, label = "+5% stealth (Windy)" },
    },
    -- Terrain
    terrain = {
        forest =        { mod = 0.20, label = "+20% stealth (Forest)" },
        deep_forest =   { mod = 0.30, label = "+30% stealth (Deep Forest)" },
        swamp =         { mod = 0.15, label = "+15% stealth (Swamp)" },
        ruins =         { mod = 0.10, label = "+10% stealth (Ruins)" },
        mountain =      { mod = 0.05, label = "+5% stealth (Mountain)" },
        town =          { mod = -0.10, label = "-10% stealth (Urban)" },
        grass =         { mod = -0.15, label = "-15% stealth (Open grass)" },
        plains =        { mod = -0.30, label = "-30% stealth (Open)" },
        desert =        { mod = -0.25, label = "-25% stealth (Desert)" },
        sand =          { mod = -0.25, label = "-25% stealth (Sand)" },
        ice =           { mod = -0.20, label = "-20% stealth (Ice)" },
    },
    -- Moon phase (0 = new moon, 7 = full moon in an 8-phase cycle)
    moon = {
        [0] = { mod = 0.10,  label = "+10% stealth (New Moon)" },
        [1] = { mod = 0.07,  label = "+7% stealth (Waxing Crescent)" },
        [2] = { mod = 0.03,  label = "+3% stealth (First Quarter)" },
        [3] = { mod = -0.02, label = "-2% stealth (Waxing Gibbous)" },
        [4] = { mod = -0.10, label = "-10% stealth (Full Moon)" },
        [5] = { mod = -0.05, label = "-5% stealth (Waning Gibbous)" },
        [6] = { mod = 0.0,   label = "No modifier (Last Quarter)" },
        [7] = { mod = 0.05,  label = "+5% stealth (Waning Crescent)" },
    },
}

-- Indoor stealth modifiers
StealthSystem.INDOOR_MODIFIERS = {
    -- Light level (primary)
    light = {
        dark =   { mod = 0.50, label = "+50% stealth (Dark)" },
        dim =    { mod = 0.20, label = "+20% stealth (Dim)" },
        bright = { mod = -0.30, label = "-30% stealth (Bright)" },
    },
    -- Room size
    roomSize = {
        small =  { mod = -0.10, label = "-10% stealth (Cramped)" },
        medium = { mod = 0.00,  label = "No modifier (Normal room)" },
        large =  { mod = 0.10,  label = "+10% stealth (Spacious)" },
    },
    -- Furniture/cover density
    cover = {
        heavy =  { mod = 0.15, label = "+15% stealth (Heavy cover)" },
        normal = { mod = 0.00, label = "No modifier (Normal)" },
        empty =  { mod = -0.15, label = "-15% stealth (Empty room)" },
    },
    -- Floor type
    floor = {
        carpet =      { mod = 0.10,  label = "+10% stealth (Carpet)" },
        stone =       { mod = 0.00,  label = "No modifier (Stone)" },
        wooden =      { mod = 0.00,  label = "No modifier (Wood)" },
        creaky_wood = { mod = -0.20, label = "-20% stealth (Creaky)" },
    },
    -- Time of day (secondary for indoor)
    timeIndoor = {
        night = { mod = 0.10, label = "+10% stealth (NPCs tired)" },
        day =   { mod = 0.00, label = "No modifier (Day)" },
    },
    -- NPC count penalty: each NPC is -15% detection chance (easier to be seen)
    npcPenaltyPer = -0.15,
}

-- Stealth equipment bonuses (extends existing system in backpack.lua)
StealthSystem.EQUIPMENT_BONUSES = {
    -- Existing items (reference IDs from backpack.lua)
    tq_stealth_cloak =     { stealthMod = 0.15, desc = "+15% stealth" },
    tq_dark_hood =         { stealthMod = 0.10, desc = "+10% stealth" },
    tq_soft_boots =        { stealthMod = 0.10, desc = "+10% stealth (quiet movement)" },
    -- New items
    tq_shadow_dye =        { stealthMod = 0.05, duration = 3600, consumable = true, desc = "+5% stealth (1 hour)" },
    tq_smoke_bomb =        { tactical = true, createsDarkZone = true, darkZoneDuration = 3,
                             escapeItem = true, desc = "Create dark zone for 3 turns" },
    tq_lockpicks =         { stealthMod = 0.0, silentEntry = true, desc = "Silent door entry" },
    tq_glass_cutter =      { stealthMod = 0.0, windowEntry = true, desc = "Silent window entry" },
    tq_climbing_rope =     { stealthMod = 0.0, verticalMovement = true,
                             desc = "Bypass ground-level patrols" },
}

-- Stealth skill tree
StealthSystem.SKILL_TREE = {
    -- Tier 1 (unlocked at stealth skill level 1)
    silent_step = {
        tier = 1,
        name = "Silent Step",
        desc = "Movement generates 50% less noise. Detection from movement reduced by 15%.",
        movementNoiseReduction = 0.50,
        detectionReduction = 0.15,
        icon = "SS",
        prerequisite = nil,
    },
    -- Tier 2 (unlocked at stealth skill level 3)
    shadow_blend = {
        tier = 2,
        name = "Shadow Blend",
        desc = "Re-hide in combat costs 1 less stamina. +20% stealth bonus in dim or dark light.",
        rehideCostReduction = 1,
        dimLightBonus = 0.20,
        icon = "SB",
        prerequisite = "silent_step",
    },
    -- Tier 3 (unlocked at stealth skill level 5)
    assassinate = {
        tier = 3,
        name = "Assassinate",
        desc = "Guaranteed stealth kill on unaware targets below 50% HP. Stealth kills grant +50% XP.",
        guaranteedKillThreshold = 0.50,
        stealthKillXPBonus = 0.50,
        icon = "AS",
        prerequisite = "shadow_blend",
    },
    -- Tier 4 (unlocked at stealth skill level 7)
    vanish = {
        tier = 4,
        name = "Vanish",
        desc = "Break all detection in combat. Costs 30 stamina. 5-turn cooldown.",
        staminaCost = 30,
        cooldownTurns = 5,
        icon = "VA",
        prerequisite = "assassinate",
    },
}

-- Stealth combat constants
StealthSystem.COMBAT = {
    -- Initiative
    stealthInitiativeBonus = 5,         -- bonus to initiative roll when stealthed

    -- Stealth attack damage
    stealthDamageMultiplier = 1.50,     -- +50% damage from hidden
    stealthGuaranteedCrit = true,       -- stealth attacks always crit

    -- Shadow Strike (move + attack in one turn)
    shadowStrikeEnabled = true,
    shadowStrikeMoveBonus = 2,          -- +2 tiles movement for shadow strike

    -- Hide action
    hideActionCost = "action",          -- costs the action for the turn
    hideBaseChance = 0.50,              -- 50% base chance to re-hide
    hideRequiresCover = true,           -- must be adjacent to obstacle/wall/shadow
    hideCoverBonus = 0.25,             -- +25% if adjacent to cover

    -- Detection in combat
    detectionOnAttack = true,           -- attacking reveals you
    detectionOnMove = false,            -- moving does NOT reveal (unless in bright)
    detectionBrightMoveReveal = true,   -- moving in bright DOES reveal
    revealDuration = 1,                 -- revealed for 1 turn after attacking

    -- Smoke bomb in combat
    smokeBombDarkRadius = 2,            -- 2-tile radius dark zone
    smokeBombDuration = 3,              -- lasts 3 turns
}

-- Pre-combat stealth approach
StealthSystem.PRE_COMBAT = {
    -- Stealth kill requirements
    stealthKill = {
        requiresBehind = true,          -- must be in 180-degree rear arc
        minStealthVsPerception = 0,     -- player stealth minus enemy perception >= 0
        karmaChange = -15,              -- karma penalty for stealth kill
        xpBonus = 0.25,                -- +25% XP for stealth kill
    },
    -- Stealth knockout requirements
    stealthKnockout = {
        requiresBehind = true,
        minStealthVsPerception = 0,
        karmaChange = -5,               -- less karma penalty (non-lethal)
        xpBonus = 0.15,
        createsPrisoner = true,          -- target becomes prisoner
    },
    -- Ambush attack
    ambushAttack = {
        damageBonus = 0.50,              -- +50% first hit damage
        guaranteedFirst = true,          -- player always goes first
    },
    -- Failure consequences
    failurePenalty = {
        enemyInitiativeBonus = 3,        -- enemy gets +3 initiative on failure
        alertAllNearby = true,           -- nearby enemies become alerted
        alertRadius = 5,                 -- tiles
    },
}


-- ============================================================================
-- SECTION 2: DETECTION FORMULA ENGINE
-- ============================================================================

-- Calculate comprehensive detection chance for a given scenario
-- Returns: detectionChance (0.0 to 1.0), breakdownTable
function StealthSystem.calculateDetection(params)
    -- params fields:
    --   playerStealth: number (player's stealth stat, typically 0-100)
    --   enemyPerception: number (enemy's perception stat, typically 0-100)
    --   distance: number (tiles between player and enemy)
    --   maxDetectionRange: number (enemy's max detection range in tiles)
    --   isIndoor: boolean
    --   lightLevel: "bright" / "dim" / "dark" (for indoor)
    --   timeOfDay: "night" / "dawn" / "dusk" / "day" (for outdoor)
    --   weather: string (weather state ID)
    --   terrain: string (terrain type ID)
    --   moonPhase: number 0-7 (for outdoor night)
    --   roomSize: "small" / "medium" / "large" (for indoor)
    --   coverLevel: "heavy" / "normal" / "empty" (for indoor)
    --   floorType: "carpet" / "stone" / "wooden" / "creaky_wood" (for indoor)
    --   npcCountInRoom: number (for indoor)
    --   equipmentMod: number (total equipment stealth modifier)
    --   isBehindEnemy: boolean (is player behind the enemy)
    --   enemyAwareness: string ("unaware" / "suspicious" / "alert" / "combat")
    --   stealthMode: boolean (is stealth mode toggled on)
    --   classBonus: number (class-based stealth modifier)
    --   skillMod: number (skill tree stealth modifier)

    local breakdown = {}
    local baseDetection = 50  -- 50% base detection at medium range

    -- 1. Distance modifier: farther = harder to detect
    local distance = params.distance or 1
    local maxRange = params.maxDetectionRange or 6
    local distanceMod = 1.0
    if distance > 0 and maxRange > 0 then
        distanceMod = math.max(0.1, 1.0 - (distance / maxRange) * 0.6)
    end
    table.insert(breakdown, {
        name = "Distance",
        value = distanceMod,
        desc = string.format("%.0f%% (%.0f/%d tiles)", distanceMod * 100, distance, maxRange),
    })

    -- 2. Light modifier (primary for indoor, secondary for outdoor)
    local lightMod = 1.0
    if params.isIndoor then
        local lightLevel = params.lightLevel or "bright"
        local lightData = StealthSystem.INDOOR_MODIFIERS.light[lightLevel]
        if lightData then
            lightMod = 1.0 - lightData.mod  -- mod is stealth bonus, so subtract from detection
            table.insert(breakdown, {
                name = "Light Level",
                value = lightMod,
                desc = lightData.label,
            })
        end
    else
        -- Outdoor: time of day is the "light" equivalent
        local timeOfDay = params.timeOfDay or "day"
        local timeData = StealthSystem.OUTDOOR_MODIFIERS.time[timeOfDay]
        if timeData then
            lightMod = 1.0 - timeData.mod
            table.insert(breakdown, {
                name = "Time of Day",
                value = lightMod,
                desc = timeData.label,
            })
        end
    end

    -- 3. Cover modifier (indoor furniture / outdoor terrain)
    local coverMod = 1.0
    if params.isIndoor then
        local coverLevel = params.coverLevel or "normal"
        local coverData = StealthSystem.INDOOR_MODIFIERS.cover[coverLevel]
        if coverData then
            coverMod = 1.0 - coverData.mod
            table.insert(breakdown, {
                name = "Cover",
                value = coverMod,
                desc = coverData.label,
            })
        end
    else
        local terrain = params.terrain or "grass"
        local terrainData = StealthSystem.OUTDOOR_MODIFIERS.terrain[terrain]
        if terrainData then
            coverMod = 1.0 - terrainData.mod
            table.insert(breakdown, {
                name = "Terrain",
                value = coverMod,
                desc = terrainData.label,
            })
        end
    end

    -- 4. Equipment modifier
    local equipMod = 1.0
    local equipBonus = params.equipmentMod or 0
    equipMod = 1.0 - equipBonus
    if equipBonus ~= 0 then
        table.insert(breakdown, {
            name = "Equipment",
            value = equipMod,
            desc = string.format("%+.0f%% stealth from gear", equipBonus * 100),
        })
    end

    -- 5. Environmental modifier (weather for outdoor, floor for indoor)
    local envMod = 1.0
    if params.isIndoor then
        -- Floor type
        local floorType = params.floorType or "stone"
        local floorData = StealthSystem.INDOOR_MODIFIERS.floor[floorType]
        if floorData then
            envMod = 1.0 - floorData.mod
            table.insert(breakdown, {
                name = "Floor Type",
                value = envMod,
                desc = floorData.label,
            })
        end
        -- Room size
        local roomSize = params.roomSize or "medium"
        local roomData = StealthSystem.INDOOR_MODIFIERS.roomSize[roomSize]
        if roomData and roomData.mod ~= 0 then
            local roomMod = 1.0 - roomData.mod
            envMod = envMod * roomMod
            table.insert(breakdown, {
                name = "Room Size",
                value = roomMod,
                desc = roomData.label,
            })
        end
        -- NPC count
        local npcCount = params.npcCountInRoom or 0
        if npcCount > 0 then
            local npcMod = 1.0 - (StealthSystem.INDOOR_MODIFIERS.npcPenaltyPer * npcCount)
            npcMod = math.max(0.5, math.min(2.0, npcMod))  -- clamp
            envMod = envMod * npcMod
            table.insert(breakdown, {
                name = "NPCs in Room",
                value = npcMod,
                desc = string.format("%d NPCs (x%.2f detection)", npcCount, npcMod),
            })
        end
        -- Indoor time secondary
        local timeOfDay = params.timeOfDay or "day"
        local indoorTimeKey = (timeOfDay == "night" or timeOfDay == "dawn" or timeOfDay == "dusk")
            and "night" or "day"
        local indoorTimeData = StealthSystem.INDOOR_MODIFIERS.timeIndoor[indoorTimeKey]
        if indoorTimeData and indoorTimeData.mod ~= 0 then
            local timeMod = 1.0 - indoorTimeData.mod
            envMod = envMod * timeMod
            table.insert(breakdown, {
                name = "Time (Indoor)",
                value = timeMod,
                desc = indoorTimeData.label,
            })
        end
    else
        -- Weather
        local weather = params.weather or "sunny"
        local weatherData = StealthSystem.OUTDOOR_MODIFIERS.weather[weather]
        if weatherData and weatherData.mod ~= 0 then
            envMod = 1.0 - weatherData.mod
            table.insert(breakdown, {
                name = "Weather",
                value = envMod,
                desc = weatherData.label,
            })
        end
        -- Moon phase (only at night)
        local timeOfDay = params.timeOfDay or "day"
        if timeOfDay == "night" then
            local moonPhase = params.moonPhase or 0
            local moonData = StealthSystem.OUTDOOR_MODIFIERS.moon[moonPhase]
            if moonData and moonData.mod ~= 0 then
                local moonMod = 1.0 - moonData.mod
                envMod = envMod * moonMod
                table.insert(breakdown, {
                    name = "Moon Phase",
                    value = moonMod,
                    desc = moonData.label,
                })
            end
        end
    end

    -- 6. Stat-based modifier: player stealth vs enemy perception
    local statMod = 1.0
    local playerStealth = params.playerStealth or 10
    local enemyPerception = params.enemyPerception or 10
    local statDiff = playerStealth - enemyPerception
    -- Each point of difference = ~2% detection change
    statMod = math.max(0.2, math.min(2.0, 1.0 - (statDiff * 0.02)))
    table.insert(breakdown, {
        name = "Stealth vs Perception",
        value = statMod,
        desc = string.format("Player %d vs Enemy %d (diff %+d)",
            playerStealth, enemyPerception, statDiff),
    })

    -- 7. Class and skill modifiers
    local classMod = 1.0
    local classBonus = (params.classBonus or 0) + (params.skillMod or 0)
    if classBonus ~= 0 then
        classMod = 1.0 - classBonus
        table.insert(breakdown, {
            name = "Class & Skills",
            value = classMod,
            desc = string.format("%+.0f%% from class/skills", classBonus * 100),
        })
    end

    -- 8. Stealth mode modifier
    local stealthModeMod = 1.0
    if params.stealthMode then
        stealthModeMod = 0.75  -- 25% reduction when actively sneaking
        table.insert(breakdown, {
            name = "Stealth Mode",
            value = stealthModeMod,
            desc = "Active stealth: -25% detection",
        })
    end

    -- 9. Position modifier (behind enemy)
    local positionMod = 1.0
    if params.isBehindEnemy then
        positionMod = 0.50  -- 50% detection when behind
        table.insert(breakdown, {
            name = "Behind Enemy",
            value = positionMod,
            desc = "-50% detection (rear approach)",
        })
    end

    -- 10. Awareness state modifier
    local awarenessMod = 1.0
    local awareness = params.enemyAwareness or "unaware"
    if awareness == "suspicious" then
        awarenessMod = 1.30   -- +30% detection when already suspicious
        table.insert(breakdown, {
            name = "Enemy Suspicious",
            value = awarenessMod,
            desc = "+30% detection (already alert)",
        })
    elseif awareness == "alert" then
        awarenessMod = 1.60   -- +60% detection when actively searching
        table.insert(breakdown, {
            name = "Enemy Alert",
            value = awarenessMod,
            desc = "+60% detection (actively searching)",
        })
    end

    -- FINAL FORMULA: multiplicative stacking
    -- detectionChance = base * distance * light * cover * equip * env * stat * class * stealth * position * awareness
    local finalDetection = baseDetection / 100.0
        * distanceMod
        * lightMod
        * coverMod
        * equipMod
        * envMod
        * statMod
        * classMod
        * stealthModeMod
        * positionMod
        * awarenessMod

    -- Clamp to 1%-100%
    finalDetection = math.max(0.01, math.min(1.0, finalDetection))

    return finalDetection, breakdown
end

-- Get the detection level label from a detection chance
function StealthSystem.getDetectionLevel(detectionChance)
    local percent = math.floor(detectionChance * 100)
    for _, threshold in pairs(StealthSystem.DETECTION_THRESHOLDS) do
        if percent >= threshold.min and percent <= threshold.max then
            return threshold.label, threshold.color
        end
    end
    return "Detected", {0.9, 0.2, 0.2}
end


-- ============================================================================
-- SECTION 3: INDOOR LIGHTING SYSTEM
-- ============================================================================

-- Room data structure for indoor environments
-- Each room tracks its own light sources, NPC count, and alert level.
function StealthSystem.createRoom(params)
    return {
        id = params.id or "room_" .. tostring(math.random(10000, 99999)),
        name = params.name or "Room",
        -- Grid bounds (tile coordinates within the tactical grid)
        x1 = params.x1 or 1,
        y1 = params.y1 or 1,
        x2 = params.x2 or 6,
        y2 = params.y2 or 4,
        -- Light sources in this room
        lightSources = params.lightSources or {},
        -- Computed light level
        lightLevel = "bright",
        -- Room properties
        size = params.size or "medium",         -- small/medium/large
        floorType = params.floorType or "stone", -- carpet/stone/wooden/creaky_wood
        coverLevel = params.coverLevel or "normal", -- heavy/normal/empty
        -- NPC tracking
        npcCount = params.npcCount or 0,
        -- Alert state
        alertLevel = 0,  -- 0 = calm, 1 = suspicious, 2 = alert, 3 = alarmed
        -- Doorways connecting to other rooms (list of {x, y, targetRoomId})
        doorways = params.doorways or {},
    }
end

-- Create a light source in a room
function StealthSystem.createLightSource(sourceType, x, y, isLit)
    local template = StealthSystem.LIGHT_SOURCES[sourceType]
    if not template then return nil end

    return {
        type = sourceType,
        template = template,
        x = x,
        y = y,
        isLit = isLit ~= false,  -- default true
        name = template.name,
        canSnuff = template.canSnuff,
    }
end

-- Calculate the light level for a room based on its active light sources
-- and time of day (for windows)
function StealthSystem.calculateRoomLightLevel(room, timeOfDay)
    local activeSources = 0
    local totalBrightness = 0

    for _, source in ipairs(room.lightSources) do
        if source.isLit then
            local template = source.template or StealthSystem.LIGHT_SOURCES[source.type]
            if template then
                -- Windows only count during day
                if template.daytimeOnly then
                    if timeOfDay == "day" then
                        activeSources = activeSources + 1
                        totalBrightness = totalBrightness + template.brightness
                    end
                else
                    activeSources = activeSources + 1
                    totalBrightness = totalBrightness + template.brightness
                end
            end
        end
    end

    -- Determine light level
    if activeSources >= 3 or totalBrightness >= 2.5 then
        room.lightLevel = StealthSystem.LIGHT_LEVEL.BRIGHT
    elseif activeSources >= 1 or totalBrightness >= 0.5 then
        room.lightLevel = StealthSystem.LIGHT_LEVEL.DIM
    else
        room.lightLevel = StealthSystem.LIGHT_LEVEL.DARK
    end

    return room.lightLevel, activeSources, totalBrightness
end

-- Attempt to snuff a light source; returns success, noise generated
function StealthSystem.snuffLightSource(source, isPlayerOwned)
    if not source or not source.isLit then return false, 0 end

    local template = source.template or StealthSystem.LIGHT_SOURCES[source.type]
    if not template or not template.canSnuff then
        return false, 0  -- cannot be snuffed
    end

    source.isLit = false

    -- Calculate noise
    local noise = template.snuffNoise or 0
    if not isPlayerOwned and template.snuffNoiseNPC then
        noise = template.snuffNoiseNPC
    end

    return true, noise
end

-- Get the light level at a specific tile (considering all light sources in range)
-- This is for per-tile light calculation on the tactical grid.
function StealthSystem.getTileLightLevel(grid, tileX, tileY, rooms, timeOfDay)
    local maxBrightness = 0

    for _, room in ipairs(rooms) do
        -- Check if tile is in this room
        if tileX >= room.x1 and tileX <= room.x2 and tileY >= room.y1 and tileY <= room.y2 then
            for _, source in ipairs(room.lightSources) do
                if source.isLit then
                    local template = source.template or StealthSystem.LIGHT_SOURCES[source.type]
                    if template then
                        local effectiveBrightness = template.brightness
                        -- Windows only during day
                        if template.daytimeOnly then
                            if not (timeOfDay == "day") then
                                effectiveBrightness = 0
                            end
                        end
                        -- Distance falloff
                        local dist = math.abs(source.x - tileX) + math.abs(source.y - tileY)
                        if dist <= template.lightRadius then
                            local falloff = 1.0 - (dist / (template.lightRadius + 1))
                            maxBrightness = maxBrightness + effectiveBrightness * falloff
                        end
                    end
                end
            end
        end
    end

    -- Convert brightness to light level
    if maxBrightness >= 1.5 then
        return StealthSystem.LIGHT_LEVEL.BRIGHT, maxBrightness
    elseif maxBrightness >= 0.3 then
        return StealthSystem.LIGHT_LEVEL.DIM, maxBrightness
    else
        return StealthSystem.LIGHT_LEVEL.DARK, maxBrightness
    end
end


-- ============================================================================
-- SECTION 4: NPC AWARENESS AND VISION SYSTEM
-- ============================================================================

-- NPC awareness data structure
function StealthSystem.createNPCAwareness(npc)
    return {
        npcId = npc.id or "unknown",
        state = "unaware",          -- unaware / suspicious / alert / combat
        facing = npc.facing or 0,   -- angle in degrees (0 = right, 90 = down, etc.)
        visionRange = npc.visionRange or 5,
        visionAngle = npc.visionAngle or 90,  -- degrees (total cone width)
        perceptionStat = npc.perception or 10,
        suspicionTimer = 0,         -- time spent suspicious before escalating
        suspicionThreshold = 3.0,   -- seconds before suspicious -> alert
        alertTimer = 0,
        alertThreshold = 5.0,       -- seconds before alert -> returns to patrol
        lastKnownPlayerX = nil,
        lastKnownPlayerY = nil,
        patrolRoute = npc.patrolRoute or {},
        patrolIndex = 1,
    }
end

-- Check if a position is within an NPC's vision cone
function StealthSystem.isInVisionCone(npcX, npcY, npcFacing, visionAngle, visionRange, targetX, targetY)
    local dx = targetX - npcX
    local dy = targetY - npcY
    local dist = math.sqrt(dx * dx + dy * dy)

    -- Out of range
    if dist > visionRange then
        return false, dist
    end

    -- Calculate angle to target
    local angleToTarget = math.deg(math.atan2(dy, dx))
    if angleToTarget < 0 then angleToTarget = angleToTarget + 360 end

    -- Normalize facing
    local facing = npcFacing % 360

    -- Check if angle is within cone
    local halfCone = visionAngle / 2
    local angleDiff = math.abs(angleToTarget - facing)
    if angleDiff > 180 then angleDiff = 360 - angleDiff end

    return angleDiff <= halfCone, dist
end

-- Check if a position is behind an NPC (within 180-degree rear arc)
function StealthSystem.isBehindNPC(npcX, npcY, npcFacing, targetX, targetY)
    local dx = targetX - npcX
    local dy = targetY - npcY

    local angleToTarget = math.deg(math.atan2(dy, dx))
    if angleToTarget < 0 then angleToTarget = angleToTarget + 360 end

    local facing = npcFacing % 360
    local angleDiff = math.abs(angleToTarget - facing)
    if angleDiff > 180 then angleDiff = 360 - angleDiff end

    -- Behind = angle difference > 90 degrees from facing direction
    return angleDiff > 90
end

-- Update NPC awareness state based on detection results
function StealthSystem.updateNPCAwareness(awarenessData, detected, dt)
    local state = awarenessData.state

    if detected then
        if state == "unaware" then
            awarenessData.state = "suspicious"
            awarenessData.suspicionTimer = 0
        elseif state == "suspicious" then
            awarenessData.suspicionTimer = awarenessData.suspicionTimer + dt
            if awarenessData.suspicionTimer >= awarenessData.suspicionThreshold then
                awarenessData.state = "alert"
                awarenessData.alertTimer = 0
            end
        elseif state == "alert" then
            awarenessData.alertTimer = 0  -- reset alert decay timer
            -- Alert stays alert while detecting; combat transition handled by combat trigger
        end
    else
        -- Not detecting player: decay awareness
        if state == "suspicious" then
            awarenessData.suspicionTimer = awarenessData.suspicionTimer - dt * 0.5
            if awarenessData.suspicionTimer <= 0 then
                awarenessData.state = "unaware"
                awarenessData.suspicionTimer = 0
            end
        elseif state == "alert" then
            awarenessData.alertTimer = awarenessData.alertTimer + dt
            if awarenessData.alertTimer >= awarenessData.alertThreshold then
                awarenessData.state = "suspicious"
                awarenessData.suspicionTimer = awarenessData.suspicionThreshold * 0.5
            end
        end
    end

    return awarenessData.state
end

-- Get facing direction for a unit based on grid position
-- Maps cardinal directions to degrees for the vision cone system.
function StealthSystem.getFacingFromDirection(dx, dy)
    if dx > 0 then return 0       -- facing right
    elseif dx < 0 then return 180 -- facing left
    elseif dy > 0 then return 90  -- facing down
    elseif dy < 0 then return 270 -- facing up
    end
    return 0  -- default: facing right
end


-- ============================================================================
-- SECTION 5: PRE-COMBAT STEALTH APPROACH
-- ============================================================================

-- Evaluate stealth approach options when player reaches an enemy on the map.
-- Returns a table of available actions and their success chances.
function StealthSystem.evaluateStealthApproach(playerData, enemyData, context)
    -- context fields:
    --   isIndoor, lightLevel, timeOfDay, weather, terrain, moonPhase,
    --   isBehindEnemy, enemyAwareness, distance

    local options = {}

    -- Calculate detection
    local detectionChance, breakdown = StealthSystem.calculateDetection({
        playerStealth = playerData.stealth or 10,
        enemyPerception = enemyData.perception or 10,
        distance = context.distance or 1,
        maxDetectionRange = enemyData.detectionRadius or 6,
        isIndoor = context.isIndoor or false,
        lightLevel = context.lightLevel or "bright",
        timeOfDay = context.timeOfDay or "day",
        weather = context.weather or "sunny",
        terrain = context.terrain or "grass",
        moonPhase = context.moonPhase or 0,
        equipmentMod = playerData.equipmentStealthMod or 0,
        isBehindEnemy = context.isBehindEnemy or false,
        enemyAwareness = context.enemyAwareness or "unaware",
        stealthMode = playerData.stealthMode or false,
        classBonus = playerData.classStealthBonus or 0,
        skillMod = playerData.skillStealthMod or 0,
        roomSize = context.roomSize,
        coverLevel = context.coverLevel,
        floorType = context.floorType,
        npcCountInRoom = context.npcCountInRoom,
    })

    local detectionPercent = math.floor(detectionChance * 100)
    local detectionLevel, detectionColor = StealthSystem.getDetectionLevel(detectionChance)

    -- Determine available options based on detection level and position

    -- Option 1: Stealth Kill
    local canStealthKill = false
    local stealthKillChance = 0
    if detectionPercent <= 20 then  -- Must be undetected
        local req = StealthSystem.PRE_COMBAT.stealthKill
        if (not req.requiresBehind or context.isBehindEnemy) then
            local stealthVsPerc = (playerData.stealth or 10) - (enemyData.perception or 10)
            if stealthVsPerc >= req.minStealthVsPerception then
                canStealthKill = true
                -- Success chance based on how far below detection threshold
                stealthKillChance = math.max(0.30, 1.0 - detectionChance * 2)
                -- Assassinate skill: guaranteed if target below HP threshold
                if playerData.hasAssassinate and enemyData.hpPercent
                    and enemyData.hpPercent <= StealthSystem.SKILL_TREE.assassinate.guaranteedKillThreshold then
                    stealthKillChance = 1.0
                end
            end
        end
    end

    if canStealthKill then
        table.insert(options, {
            id = "stealth_kill",
            name = "Stealth Kill",
            desc = "Instant kill from behind. Karma penalty: "
                .. StealthSystem.PRE_COMBAT.stealthKill.karmaChange,
            chance = stealthKillChance,
            karmaChange = StealthSystem.PRE_COMBAT.stealthKill.karmaChange,
            xpBonus = StealthSystem.PRE_COMBAT.stealthKill.xpBonus,
            requiresBehind = true,
            available = true,
            color = {0.9, 0.2, 0.2},
        })
    else
        table.insert(options, {
            id = "stealth_kill",
            name = "Stealth Kill",
            desc = canStealthKill == false and detectionPercent > 20
                and "Too exposed (detection > 20%)"
                or "Must be behind enemy",
            chance = 0,
            available = false,
            color = {0.4, 0.2, 0.2},
        })
    end

    -- Option 2: Stealth Knockout
    local canStealthKnockout = false
    local knockoutChance = 0
    if detectionPercent <= 20 then
        local req = StealthSystem.PRE_COMBAT.stealthKnockout
        if (not req.requiresBehind or context.isBehindEnemy) then
            local stealthVsPerc = (playerData.stealth or 10) - (enemyData.perception or 10)
            if stealthVsPerc >= req.minStealthVsPerception then
                canStealthKnockout = true
                knockoutChance = math.max(0.35, 1.0 - detectionChance * 1.8)
            end
        end
    end

    if canStealthKnockout then
        table.insert(options, {
            id = "stealth_knockout",
            name = "Stealth Knockout",
            desc = "Non-lethal takedown. Target becomes prisoner. Karma: "
                .. StealthSystem.PRE_COMBAT.stealthKnockout.karmaChange,
            chance = knockoutChance,
            karmaChange = StealthSystem.PRE_COMBAT.stealthKnockout.karmaChange,
            xpBonus = StealthSystem.PRE_COMBAT.stealthKnockout.xpBonus,
            requiresBehind = true,
            available = true,
            createsPrisoner = true,
            color = {0.2, 0.6, 0.9},
        })
    else
        table.insert(options, {
            id = "stealth_knockout",
            name = "Stealth Knockout",
            desc = canStealthKnockout == false and detectionPercent > 20
                and "Too exposed (detection > 20%)"
                or "Must be behind enemy",
            chance = 0,
            available = false,
            color = {0.2, 0.3, 0.4},
        })
    end

    -- Option 3: Ambush Attack (always available if somewhat hidden)
    if detectionPercent <= 50 then
        table.insert(options, {
            id = "ambush",
            name = "Ambush Attack",
            desc = string.format("Start combat with initiative. +%d%% first hit damage.",
                StealthSystem.PRE_COMBAT.ambushAttack.damageBonus * 100),
            chance = 1.0,  -- guaranteed if detection is low enough
            damageBonus = StealthSystem.PRE_COMBAT.ambushAttack.damageBonus,
            available = true,
            color = {0.9, 0.6, 0.2},
        })
    else
        table.insert(options, {
            id = "ambush",
            name = "Ambush Attack",
            desc = "Too exposed for ambush (detection > 50%)",
            chance = 0,
            available = false,
            color = {0.4, 0.3, 0.2},
        })
    end

    -- Option 4: Normal combat (always available)
    table.insert(options, {
        id = "normal_combat",
        name = "Initiate Combat",
        desc = "Start combat normally. No stealth bonuses.",
        chance = 1.0,
        available = true,
        color = {0.6, 0.6, 0.6},
    })

    -- Option 5: Back away (always available unless already in combat)
    table.insert(options, {
        id = "back_away",
        name = "Back Away",
        desc = "Cancel approach and remain hidden.",
        chance = 1.0,
        available = detectionPercent <= 50,  -- can only back away if not too detected
        color = {0.3, 0.7, 0.3},
    })

    return {
        options = options,
        detectionChance = detectionChance,
        detectionPercent = detectionPercent,
        detectionLevel = detectionLevel,
        detectionColor = detectionColor,
        breakdown = breakdown,
    }
end

-- Execute a stealth approach option
-- Returns result table with success/failure and effects
function StealthSystem.executeStealthAction(actionId, playerData, enemyData, approachResult)
    local result = {
        success = false,
        actionId = actionId,
        message = "",
        combatStarts = false,
        enemyDefeated = false,
        karmaChange = 0,
        xpBonus = 0,
        enemyAlerted = false,
    }

    if actionId == "stealth_kill" then
        -- Find the option
        local option = nil
        for _, opt in ipairs(approachResult.options) do
            if opt.id == "stealth_kill" and opt.available then
                option = opt
                break
            end
        end
        if not option then
            result.message = "Stealth kill not available."
            result.combatStarts = true
            result.enemyAlerted = true
            return result
        end

        -- Roll for success
        local roll = math.random()
        if roll <= option.chance then
            result.success = true
            result.enemyDefeated = true
            result.karmaChange = option.karmaChange
            result.xpBonus = option.xpBonus
            result.message = "You silently dispatch the target from the shadows."
        else
            result.success = false
            result.combatStarts = true
            result.enemyAlerted = true
            result.message = "Your strike misses! The enemy is alerted!"
        end

    elseif actionId == "stealth_knockout" then
        local option = nil
        for _, opt in ipairs(approachResult.options) do
            if opt.id == "stealth_knockout" and opt.available then
                option = opt
                break
            end
        end
        if not option then
            result.message = "Stealth knockout not available."
            result.combatStarts = true
            result.enemyAlerted = true
            return result
        end

        local roll = math.random()
        if roll <= option.chance then
            result.success = true
            result.enemyDefeated = true
            result.createsPrisoner = true
            result.karmaChange = option.karmaChange
            result.xpBonus = option.xpBonus
            result.message = "You knock the target unconscious. They are now your prisoner."
        else
            result.success = false
            result.combatStarts = true
            result.enemyAlerted = true
            result.message = "The target resists! Combat begins!"
        end

    elseif actionId == "ambush" then
        result.success = true
        result.combatStarts = true
        result.ambushActive = true
        result.playerGoesFirst = true
        result.firstHitDamageBonus = StealthSystem.PRE_COMBAT.ambushAttack.damageBonus
        result.message = "You launch a surprise attack!"

    elseif actionId == "normal_combat" then
        result.success = true
        result.combatStarts = true
        result.message = "You engage the enemy directly."

    elseif actionId == "back_away" then
        result.success = true
        result.combatStarts = false
        result.message = "You silently withdraw from the area."
    end

    return result
end


-- ============================================================================
-- SECTION 6: TACTICAL COMBAT STEALTH INTEGRATION
-- ============================================================================

-- Status effect definition for "hidden" in tactical combat
StealthSystem.HIDDEN_STATUS = {
    id = "hidden",
    name = "Hidden",
    duration = 999,     -- indefinite until broken
    color = {0.3, 0.3, 0.5},
    -- Custom properties
    untargetable = true,         -- enemies cannot target directly
    stealthDamageBonus = 0.50,   -- +50% damage on first attack
    guaranteedCrit = true,       -- first attack from hidden is always crit
}

-- Status effect for "smoke" (dark zone from smoke bomb)
StealthSystem.SMOKE_STATUS = {
    id = "smoke_zone",
    name = "Smoke",
    duration = 3,
    color = {0.5, 0.5, 0.5},
    -- Tiles within smoke zone count as "dark" for stealth purposes
    forcedLightLevel = "dark",
}

-- Apply hidden status to a unit (used at combat start if stealthed)
function StealthSystem.applyHidden(unit, TC)
    if TC and TC.applyStatus then
        -- Use existing status system
        TC.applyStatus(unit, "hidden", 999)
    end
    -- Also set custom flag for stealth-specific logic
    unit.isHidden = true
    unit.stealthDamageBonus = StealthSystem.HIDDEN_STATUS.stealthDamageBonus
    unit.guaranteedCrit = StealthSystem.HIDDEN_STATUS.guaranteedCrit
end

-- Remove hidden status from a unit (when revealed)
function StealthSystem.removeHidden(unit, TC)
    unit.isHidden = false
    unit.stealthDamageBonus = nil
    unit.guaranteedCrit = nil
    -- Remove from status effect list
    if unit.statusEffects then
        for i = #unit.statusEffects, 1, -1 do
            if unit.statusEffects[i].id == "hidden" then
                table.remove(unit.statusEffects, i)
            end
        end
    end
end

-- Check if a unit should be revealed based on their action
function StealthSystem.checkReveal(unit, action, combatState, TC)
    if not unit.isHidden then return false end

    if action == "attack" or action == "skill" then
        -- Attacking always reveals
        StealthSystem.removeHidden(unit, TC)
        return true
    end

    if action == "move" then
        -- Check if moving into bright tile
        if combatState and combatState.grid then
            local tile = combatState.grid.tiles[unit.y] and combatState.grid.tiles[unit.y][unit.x]
            -- On outdoor / non-interior maps, lightLevel may be nil; default to
            -- "bright" (full daylight) so stealth isn't free outdoors.
            local light = (tile and tile.lightLevel) or "bright"
            if light == "bright" then
                if StealthSystem.COMBAT.detectionBrightMoveReveal then
                    StealthSystem.removeHidden(unit, TC)
                    return true
                end
            end
        end
        -- Moving in dim/dark does not reveal
        return false
    end

    return false
end

-- Attempt to re-hide during combat
-- Returns success (boolean), message (string)
function StealthSystem.attemptHide(unit, combatState, TC)
    if not combatState or not combatState.grid then
        return false, "No valid combat state"
    end

    -- Check if adjacent to cover
    local hasCover = false
    if StealthSystem.COMBAT.hideRequiresCover then
        local neighbors = TileUtils.DIRS4
        for _, n in ipairs(neighbors) do
            local nx, ny = unit.x + n[1], unit.y + n[2]
            if TC and TC.isValidTile(combatState.grid, nx, ny) then
                local tile = combatState.grid.tiles[ny][nx]
                if tile.type == "wall" or tile.type == "obstacle" then
                    hasCover = true
                    break
                end
                -- Check if tile is in a smoke/dark zone
                if tile.lightLevel == "dark" or tile.hasSmoke then
                    hasCover = true
                    break
                end
            end
        end
    else
        hasCover = true
    end

    if not hasCover then
        return false, "No cover nearby - need wall, obstacle, or dark zone"
    end

    -- Calculate hide chance
    local hideChance = StealthSystem.COMBAT.hideBaseChance
    if hasCover then
        hideChance = hideChance + StealthSystem.COMBAT.hideCoverBonus
    end

    -- Light level bonus
    local tile = combatState.grid.tiles[unit.y] and combatState.grid.tiles[unit.y][unit.x]
    if tile then
        if tile.lightLevel == "dark" then
            hideChance = hideChance + 0.30
        elseif tile.lightLevel == "dim" then
            hideChance = hideChance + 0.15
        elseif tile.lightLevel == "bright" then
            hideChance = hideChance - 0.20
        end
    end

    -- Shadow Blend skill bonus
    if unit.data and unit.data.stealthPerks and unit.data.stealthPerks.shadow_blend then
        hideChance = hideChance + 0.20
    end

    -- Roll
    local roll = math.random()
    if roll <= hideChance then
        StealthSystem.applyHidden(unit, TC)
        return true, string.format("Hidden! (%.0f%% chance)", hideChance * 100)
    else
        return false, string.format("Failed to hide! (%.0f%% chance, rolled %.0f%%)",
            hideChance * 100, roll * 100)
    end
end

-- Shadow Strike: combined move + attack action from stealth
-- Returns whether the shadow strike is valid and the details
function StealthSystem.canShadowStrike(unit, targetX, targetY, combatState, TC)
    if not unit.isHidden then
        return false, "Must be hidden to Shadow Strike"
    end
    if not StealthSystem.COMBAT.shadowStrikeEnabled then
        return false, "Shadow Strike not enabled"
    end
    if unit.hasMoved or unit.hasActed then
        return false, "Already used move or action"
    end

    -- Extended movement range for shadow strike
    local moveRange = unit.moveRange + StealthSystem.COMBAT.shadowStrikeMoveBonus
    if TC and TC.getEffectiveMoveRange then
        moveRange = TC.getEffectiveMoveRange(unit) + StealthSystem.COMBAT.shadowStrikeMoveBonus
    end

    -- Check if target is in extended range (Manhattan distance)
    local dist = math.abs(unit.x - targetX) + math.abs(unit.y - targetY)
    local attackRange = unit.attackRange or 1

    -- We need to be able to reach a tile adjacent to target within moveRange
    -- and then attack the target
    if dist > moveRange + attackRange then
        return false, "Target too far for Shadow Strike"
    end

    -- Verify a reachable adjacent tile exists via pathfinding
    if TC and combatState and combatState.grid then
        local grid = combatState.grid
        local neighbors = TileUtils.DIRS4
        local hasReachableTile = false
        for _, n in ipairs(neighbors) do
            local nx, ny = targetX + n[1], targetY + n[2]
            -- Already adjacent? No move needed
            if nx == unit.x and ny == unit.y then
                hasReachableTile = true
                break
            end
            -- Check tile is passable and unoccupied
            if TC.isTilePassable and TC.isTilePassable(grid, nx, ny)
                and (not TC.getUnitAt or not TC.getUnitAt(grid, nx, ny)) then
                -- Verify A* path exists and is within extended range
                if TC.findPath then
                    local path = TC.findPath(grid, unit.x, unit.y, nx, ny)
                    if path and #path <= moveRange then
                        hasReachableTile = true
                        break
                    end
                else
                    -- Fallback: accept if Manhattan distance is within range
                    local moveDist = math.abs(unit.x - nx) + math.abs(unit.y - ny)
                    if moveDist <= moveRange then
                        hasReachableTile = true
                        break
                    end
                end
            end
        end
        if not hasReachableTile then
            return false, "No reachable position adjacent to target"
        end
    end

    return true, "Shadow Strike available"
end

-- Modify initiative rolls for stealth
function StealthSystem.modifyInitiative(unit, baseInitiative, isStealthed)
    if isStealthed then
        return baseInitiative + StealthSystem.COMBAT.stealthInitiativeBonus
    end
    return baseInitiative
end

-- Modify damage for stealth attacks
function StealthSystem.modifyStealthDamage(baseDamage, unit)
    if unit.isHidden then
        local mult = StealthSystem.COMBAT.stealthDamageMultiplier
        local isCrit = StealthSystem.COMBAT.stealthGuaranteedCrit
        -- Stealth crit multiplier is on top of the damage bonus
        local critMult = isCrit and 1.5 or 1.0
        return math.floor(baseDamage * mult * critMult), isCrit
    end
    return baseDamage, false
end


-- ============================================================================
-- SECTION 7: TACTICAL GRID LIGHT LEVEL INTEGRATION
-- ============================================================================

-- Apply light levels to all tiles in a tactical grid (for building_interior maps)
function StealthSystem.applyLightingToGrid(grid, rooms, timeOfDay)
    if not grid or not rooms then return end

    for y = 1, grid.height do
        for x = 1, grid.width do
            local lightLevel, brightness = StealthSystem.getTileLightLevel(
                grid, x, y, rooms, timeOfDay
            )
            if grid.tiles[y] and grid.tiles[y][x] then
                grid.tiles[y][x].lightLevel = lightLevel
                grid.tiles[y][x].brightness = brightness
            end
        end
    end
end

-- Generate light sources for a building_interior map
-- Called during map generation to populate rooms with appropriate lighting.
function StealthSystem.generateBuildingLighting(grid, timeOfDay)
    local rooms = {}

    -- Detect rooms by finding enclosed areas (simplified: use grid sections)
    -- For the 12x8 grid, a building interior typically has 1-3 rooms
    local hasInternalWall = false
    local wallX = nil

    -- Check for internal walls
    for x = 3, grid.width - 2 do
        local wallCount = 0
        for y = 2, grid.height - 1 do
            if grid.tiles[y][x].type == "wall" then
                wallCount = wallCount + 1
            end
        end
        -- If more than half the column is wall, it is a divider
        if wallCount >= (grid.height - 2) * 0.5 then
            hasInternalWall = true
            wallX = x
            break
        end
    end

    if hasInternalWall and wallX then
        -- Two rooms
        local room1 = StealthSystem.createRoom({
            id = "room_left",
            name = "Left Room",
            x1 = 2, y1 = 2,
            x2 = wallX - 1, y2 = grid.height - 1,
            size = (wallX - 2) <= 4 and "small" or "medium",
            floorType = math.random() < 0.4 and "creaky_wood" or "wooden",
            coverLevel = "normal",
        })
        local room2 = StealthSystem.createRoom({
            id = "room_right",
            name = "Right Room",
            x1 = wallX + 1, y1 = 2,
            x2 = grid.width - 1, y2 = grid.height - 1,
            size = (grid.width - 1 - wallX) <= 4 and "small" or "medium",
            floorType = math.random() < 0.3 and "carpet" or "stone",
            coverLevel = math.random() < 0.5 and "heavy" or "normal",
        })

        -- Add light sources to each room
        StealthSystem._addRoomLighting(room1, timeOfDay)
        StealthSystem._addRoomLighting(room2, timeOfDay)

        table.insert(rooms, room1)
        table.insert(rooms, room2)
    else
        -- Single room
        local room = StealthSystem.createRoom({
            id = "room_main",
            name = "Main Room",
            x1 = 2, y1 = 2,
            x2 = grid.width - 1, y2 = grid.height - 1,
            size = "large",
            floorType = math.random() < 0.3 and "carpet" or "wooden",
            coverLevel = "normal",
        })
        StealthSystem._addRoomLighting(room, timeOfDay)
        table.insert(rooms, room)
    end

    -- Calculate light levels for all rooms
    for _, room in ipairs(rooms) do
        StealthSystem.calculateRoomLightLevel(room, timeOfDay)
    end

    -- Apply to grid tiles
    StealthSystem.applyLightingToGrid(grid, rooms, timeOfDay)

    -- Generate guard patrol routes for each room with NPCs
    grid.guardPatrols = {}
    for _, room in ipairs(rooms) do
        if room.npcCount and room.npcCount > 0 then
            -- Create a patrol route along the room perimeter
            local route = {}
            -- Patrol walks along inner edge: top-left -> top-right -> bot-right -> bot-left
            local x1, y1, x2, y2 = room.x1 + 1, room.y1 + 1, room.x2 - 1, room.y2 - 1
            if x1 <= x2 and y1 <= y2 then
                table.insert(route, {x = x1, y = y1})
                if x2 > x1 then table.insert(route, {x = x2, y = y1}) end
                if y2 > y1 then table.insert(route, {x = x2, y = y2}) end
                if x2 > x1 and y2 > y1 then table.insert(route, {x = x1, y = y2}) end
            end
            if #route >= 2 then
                local guard = StealthSystem.createGuardPatrol({
                    id = "guard_" .. room.id,
                    route = route,
                    visionRange = 3,
                    visionAngle = 90,
                    perception = 12,
                    moveInterval = 2.0,
                })
                table.insert(grid.guardPatrols, guard)
            end
        end
    end

    return rooms
end

-- Internal: add appropriate light sources to a room
function StealthSystem._addRoomLighting(room, timeOfDay)
    local w = room.x2 - room.x1 + 1
    local h = room.y2 - room.y1 + 1

    -- Always add a window on an outer wall
    table.insert(room.lightSources, StealthSystem.createLightSource(
        "window", room.x1, room.y1, true
    ))

    -- Add 1-3 torches on walls depending on room size
    local numTorches = room.size == "large" and math.random(2, 3) or math.random(0, 2)
    for i = 1, numTorches do
        local tx = room.x1 + math.random(0, w - 1)
        local ty = (i % 2 == 0) and room.y1 or room.y2
        table.insert(room.lightSources, StealthSystem.createLightSource("torch", tx, ty, true))
    end

    -- Add candles on tables (if there are obstacle/furniture tiles)
    local numCandles = math.random(0, 2)
    for i = 1, numCandles do
        local cx = room.x1 + math.random(1, math.max(1, w - 2))
        local cy = room.y1 + math.random(1, math.max(1, h - 2))
        table.insert(room.lightSources, StealthSystem.createLightSource("candle", cx, cy, true))
    end

    -- 30% chance of a fireplace in larger rooms
    if room.size ~= "small" and math.random() < 0.3 then
        table.insert(room.lightSources, StealthSystem.createLightSource(
            "fireplace",
            room.x1 + math.floor(w / 2),
            room.y2,
            true
        ))
    end
end


-- ============================================================================
-- SECTION 8: SMOKE BOMB AND DARK ZONE MECHANICS
-- ============================================================================

-- Deploy a smoke bomb on the tactical grid
-- Creates a "dark zone" centered on the given position
function StealthSystem.deploySmokeBomb(combatState, x, y, TC)
    if not combatState or not combatState.grid then return false end

    local radius = StealthSystem.COMBAT.smokeBombDarkRadius
    local duration = StealthSystem.COMBAT.smokeBombDuration
    local grid = combatState.grid

    -- Track smoke zones for turn countdown
    if not combatState.smokeZones then
        combatState.smokeZones = {}
    end

    local zone = {
        centerX = x,
        centerY = y,
        radius = radius,
        turnsRemaining = duration,
        tiles = {},
    }

    -- Apply dark zone to tiles
    for dy = -radius, radius do
        for dx = -radius, radius do
            local tx, ty = x + dx, y + dy
            if math.abs(dx) + math.abs(dy) <= radius then  -- Manhattan distance
                if TC and TC.isValidTile(grid, tx, ty) then
                    grid.tiles[ty][tx].lightLevel = "dark"
                    grid.tiles[ty][tx].hasSmoke = true
                    table.insert(zone.tiles, {x = tx, y = ty})
                end
            end
        end
    end

    table.insert(combatState.smokeZones, zone)

    -- Visual effect
    if TC and combatState then
        TC.addFloatingText(combatState, "SMOKE!", x, y, {0.7, 0.7, 0.7}, "status")
        if TC.spawnParticles then
            TC.spawnParticles(combatState, "smoke", x, y, {0.5, 0.5, 0.5}, 12)
        end
        if TC.triggerScreenShake then
            TC.triggerScreenShake(combatState, 2, 0.2)
        end
    end

    return true
end

-- Update smoke zones (called at start of each round)
function StealthSystem.updateSmokeZones(combatState)
    if not combatState.smokeZones then return end

    local grid = combatState.grid
    local i = 1
    while i <= #combatState.smokeZones do
        local zone = combatState.smokeZones[i]
        zone.turnsRemaining = zone.turnsRemaining - 1

        if zone.turnsRemaining <= 0 then
            -- Remove smoke from tiles
            for _, tile in ipairs(zone.tiles) do
                if grid.tiles[tile.y] and grid.tiles[tile.y][tile.x] then
                    grid.tiles[tile.y][tile.x].hasSmoke = false
                    -- Restore original light level (will be recalculated)
                    grid.tiles[tile.y][tile.x].lightLevel = nil
                end
            end
            table.remove(combatState.smokeZones, i)
        else
            i = i + 1
        end
    end
end


-- ============================================================================
-- SECTION 9: EQUIPMENT STEALTH MODIFIER CALCULATOR
-- ============================================================================

-- Calculate total stealth modifier from player equipment and consumables
function StealthSystem.calculateEquipmentMod(playerData, Backpack)
    local totalMod = 0

    -- Check backpack for stealth items
    if Backpack and Backpack.hasItem then
        for itemId, bonus in pairs(StealthSystem.EQUIPMENT_BONUSES) do
            if bonus.stealthMod and bonus.stealthMod > 0 then
                if not bonus.consumable then
                    -- Permanent equipment
                    if Backpack.hasItem(itemId) then
                        totalMod = totalMod + bonus.stealthMod
                    end
                else
                    -- Consumable: check if active effect is present
                    if playerData.activeEffects and playerData.activeEffects[itemId] then
                        totalMod = totalMod + bonus.stealthMod
                    end
                end
            end
        end
    end

    -- Armor type penalty/bonus (from existing system in textrpg.lua)
    if playerData.equipment and playerData.equipment.armor then
        local armor = playerData.equipment.armor
        local armorId = armor.id or ""
        if armorId:find("plate") then
            totalMod = totalMod - 0.15  -- heavy armor penalty
        elseif armorId:find("chain") then
            totalMod = totalMod - 0.05
        elseif armorId:find("leather") then
            totalMod = totalMod + 0.05
        elseif armorId:find("cloth") then
            totalMod = totalMod + 0.10
        end
    end

    return totalMod
end


-- ============================================================================
-- SECTION 10: HELPER UTILITIES
-- ============================================================================

-- Get time period category from hour
function StealthSystem.getTimePeriod(hour)
    if hour >= 22 or hour <= 4 then return "night"
    elseif hour >= 5 and hour <= 6 then return "dawn"
    elseif hour >= 18 and hour <= 19 then return "dusk"
    else return "day"
    end
end

-- Calculate moon phase from game day (simple 8-phase cycle)
function StealthSystem.getMoonPhase(gameDay)
    return (gameDay or 0) % 8
end

-- Get outdoor stealth modifier breakdown for the current environment
function StealthSystem.getOutdoorBreakdown(timeOfDay, weather, terrain, moonPhase)
    local breakdown = {}
    local totalMod = 0

    local timeData = StealthSystem.OUTDOOR_MODIFIERS.time[timeOfDay]
    if timeData then
        totalMod = totalMod + timeData.mod
        table.insert(breakdown, { name = "Time", desc = timeData.label, mod = timeData.mod })
    end

    local weatherData = StealthSystem.OUTDOOR_MODIFIERS.weather[weather]
    if weatherData then
        totalMod = totalMod + weatherData.mod
        table.insert(breakdown, { name = "Weather", desc = weatherData.label, mod = weatherData.mod })
    end

    local terrainData = StealthSystem.OUTDOOR_MODIFIERS.terrain[terrain]
    if terrainData then
        totalMod = totalMod + terrainData.mod
        table.insert(breakdown, { name = "Terrain", desc = terrainData.label, mod = terrainData.mod })
    end

    if timeOfDay == "night" then
        local moonData = StealthSystem.OUTDOOR_MODIFIERS.moon[moonPhase or 0]
        if moonData then
            totalMod = totalMod + moonData.mod
            table.insert(breakdown, { name = "Moon", desc = moonData.label, mod = moonData.mod })
        end
    end

    return totalMod, breakdown
end

-- Get indoor stealth modifier breakdown for a room
function StealthSystem.getIndoorBreakdown(room, timeOfDay, npcCount)
    local breakdown = {}
    local totalMod = 0

    local lightData = StealthSystem.INDOOR_MODIFIERS.light[room.lightLevel]
    if lightData then
        totalMod = totalMod + lightData.mod
        table.insert(breakdown, { name = "Light", desc = lightData.label, mod = lightData.mod })
    end

    local roomData = StealthSystem.INDOOR_MODIFIERS.roomSize[room.size]
    if roomData then
        totalMod = totalMod + roomData.mod
        table.insert(breakdown, { name = "Room Size", desc = roomData.label, mod = roomData.mod })
    end

    local coverData = StealthSystem.INDOOR_MODIFIERS.cover[room.coverLevel]
    if coverData then
        totalMod = totalMod + coverData.mod
        table.insert(breakdown, { name = "Cover", desc = coverData.label, mod = coverData.mod })
    end

    local floorData = StealthSystem.INDOOR_MODIFIERS.floor[room.floorType]
    if floorData then
        totalMod = totalMod + floorData.mod
        table.insert(breakdown, { name = "Floor", desc = floorData.label, mod = floorData.mod })
    end

    if npcCount and npcCount > 0 then
        local npcMod = StealthSystem.INDOOR_MODIFIERS.npcPenaltyPer * npcCount
        totalMod = totalMod + npcMod
        table.insert(breakdown, {
            name = "NPCs",
            desc = string.format("%d NPCs (%+.0f%%)", npcCount, npcMod * 100),
            mod = npcMod,
        })
    end

    local timeKey = StealthSystem.getTimePeriod(
        type(timeOfDay) == "number" and timeOfDay or 12
    )
    local indoorKey = (timeKey == "night" or timeKey == "dawn" or timeKey == "dusk")
        and "night" or "day"
    local timeIndoorData = StealthSystem.INDOOR_MODIFIERS.timeIndoor[indoorKey]
    if timeIndoorData and timeIndoorData.mod ~= 0 then
        totalMod = totalMod + timeIndoorData.mod
        table.insert(breakdown, { name = "Time", desc = timeIndoorData.label, mod = timeIndoorData.mod })
    end

    return totalMod, breakdown
end

-- Format a detection breakdown into readable text lines
function StealthSystem.formatBreakdown(breakdown)
    local lines = {}
    for _, entry in ipairs(breakdown) do
        local valueStr
        if entry.value then
            valueStr = string.format("x%.2f", entry.value)
        elseif entry.mod then
            valueStr = string.format("%+.0f%%", entry.mod * 100)
        else
            valueStr = ""
        end
        table.insert(lines, string.format("  %s: %s (%s)", entry.name, entry.desc or "", valueStr))
    end
    return lines
end


-- ============================================================================
-- SECTION 11: GUARD PATROL ROUTE SYSTEM (for indoor stealth)
-- ============================================================================

-- Create a guard patrol definition for indoor environments
function StealthSystem.createGuardPatrol(params)
    return {
        id = params.id or "guard_" .. math.random(10000, 99999),
        route = params.route or {},     -- list of {x, y} waypoints
        currentIndex = 1,
        forward = true,                 -- true = forward along route, false = reverse
        speed = params.speed or 1.0,    -- tiles per second
        moveTimer = 0,
        moveInterval = params.moveInterval or 1.5,  -- seconds between moves
        facing = 0,                     -- current facing direction (degrees)
        -- Vision properties
        visionRange = params.visionRange or 4,
        visionAngle = params.visionAngle or 90,
        perception = params.perception or 12,
        -- State
        awareness = StealthSystem.createNPCAwareness({
            id = params.id,
            visionRange = params.visionRange or 4,
            visionAngle = params.visionAngle or 90,
            perception = params.perception or 12,
            patrolRoute = params.route or {},
        }),
    }
end

-- Update a guard patrol (call each frame with delta time)
function StealthSystem.updateGuardPatrol(guard, dt)
    guard.moveTimer = guard.moveTimer + dt
    if guard.moveTimer < guard.moveInterval then return end
    guard.moveTimer = guard.moveTimer - guard.moveInterval

    local route = guard.route
    if not route or #route < 2 then return end

    -- Move to next waypoint
    local target = route[guard.currentIndex]
    if not target then return end

    -- Update facing based on movement direction
    local nextIndex
    if guard.forward then
        nextIndex = guard.currentIndex + 1
        if nextIndex > #route then
            guard.forward = false
            nextIndex = guard.currentIndex - 1
        end
    else
        nextIndex = guard.currentIndex - 1
        if nextIndex < 1 then
            guard.forward = true
            nextIndex = guard.currentIndex + 1
        end
    end

    if nextIndex >= 1 and nextIndex <= #route then
        local nextTarget = route[nextIndex]
        local dx = nextTarget.x - target.x
        local dy = nextTarget.y - target.y
        guard.facing = StealthSystem.getFacingFromDirection(dx, dy)
        guard.currentIndex = nextIndex
    end
end

-- Check if a guard can see a position (combines vision cone + LOS)
function StealthSystem.guardCanSeePosition(guard, targetX, targetY, route)
    local guardPos = route[guard.currentIndex]
    if not guardPos then return false, 999 end

    return StealthSystem.isInVisionCone(
        guardPos.x, guardPos.y,
        guard.facing,
        guard.awareness.visionAngle,
        guard.awareness.visionRange,
        targetX, targetY
    )
end


-- ============================================================================
-- SECTION 12: DOORWAY STEALTH CHECKS
-- ============================================================================

-- When moving between rooms, a stealth check is required at doorways.
-- This represents the moment of vulnerability when transitioning.
function StealthSystem.doorwayStealthCheck(playerData, doorway, fromRoom, toRoom, timeOfDay)
    -- Base difficulty: average of the two rooms' detection conditions
    local fromLight = StealthSystem.INDOOR_MODIFIERS.light[fromRoom.lightLevel]
    local toLight = StealthSystem.INDOOR_MODIFIERS.light[toRoom.lightLevel]

    local fromMod = fromLight and fromLight.mod or 0
    local toMod = toLight and toLight.mod or 0
    local avgLightMod = (fromMod + toMod) / 2

    -- Doorway is a choke point: easier to detect
    local doorwayPenalty = -0.10  -- -10% stealth penalty at doorways

    -- Floor type of destination room
    local floorData = StealthSystem.INDOOR_MODIFIERS.floor[toRoom.floorType]
    local floorMod = floorData and floorData.mod or 0

    -- Total stealth modifier
    local totalMod = avgLightMod + doorwayPenalty + floorMod

    -- Equipment
    local equipMod = playerData.equipmentStealthMod or 0

    -- Calculate detection chance
    local baseDetection = 0.40  -- 40% base at doorways (tighter space)
    local finalDetection = baseDetection * (1.0 - totalMod) * (1.0 - equipMod)

    -- Stealth mode
    if playerData.stealthMode then
        finalDetection = finalDetection * 0.75
    end

    -- Class bonus
    finalDetection = finalDetection * (1.0 - (playerData.classStealthBonus or 0))

    -- Clamp
    finalDetection = math.max(0.01, math.min(0.90, finalDetection))

    -- NPC count in destination room increases detection
    if toRoom.npcCount and toRoom.npcCount > 0 then
        finalDetection = finalDetection * (1.0 + toRoom.npcCount * 0.15)
        finalDetection = math.min(0.95, finalDetection)
    end

    -- Roll
    local roll = math.random()
    local detected = roll < finalDetection

    return detected, finalDetection, {
        avgLightMod = avgLightMod,
        doorwayPenalty = doorwayPenalty,
        floorMod = floorMod,
        equipMod = equipMod,
        finalChance = finalDetection,
        roll = roll,
    }
end


-- ============================================================================
-- SECTION 13: INTEGRATION HOOKS
-- ============================================================================
-- These functions are designed to be called from the existing game systems.

-- Hook: Called from tactical_combat.lua rollInitiative() to add stealth bonus
-- Usage: Replace the initiative calculation in TacticalCombat.rollInitiative
function StealthSystem.hookInitiativeRoll(unit, baseRoll, baseBonus)
    local total = baseRoll + baseBonus
    if unit.isHidden then
        total = total + StealthSystem.COMBAT.stealthInitiativeBonus
    end
    return total
end

-- Hook: Called from tactical_combat.lua performAttack() to apply stealth damage
-- Usage: Wrap TacticalCombat.performAttack to check for stealth bonus
function StealthSystem.hookPerformAttack(attacker, baseDamage, isCrit, TC)
    if attacker.isHidden then
        local stealthMult = StealthSystem.COMBAT.stealthDamageMultiplier
        local newDamage = math.floor(baseDamage * stealthMult)
        local forceCrit = StealthSystem.COMBAT.stealthGuaranteedCrit
        -- Remove hidden after attack
        StealthSystem.removeHidden(attacker, TC)
        return newDamage, forceCrit or isCrit
    end
    return baseDamage, isCrit
end

-- Hook: Called from mapenemies.lua triggerCombat() to offer stealth approach
-- Usage: Check before startCombatFn is called
function StealthSystem.hookPreCombat(playerData, enemyData, mapEnemy, gameState)
    -- Only offer stealth options if player is in stealth mode
    if not playerData.stealthMode then
        return nil  -- proceed to normal combat
    end

    -- Determine context
    local timeOfDay = StealthSystem.getTimePeriod(math.floor(gameState.timeOfDay or 12))
    local weather = gameState.weather or "sunny"
    local terrain = gameState.currentBiome or "grass"
    local moonPhase = StealthSystem.getMoonPhase(gameState.gameDay or 0)

    -- Check if enemy was chasing (alert) or patrolling (unaware)
    local enemyAwareness = "unaware"
    if mapEnemy and mapEnemy.state == "chase" then
        enemyAwareness = "alert"
    elseif mapEnemy and mapEnemy.alertTimer and mapEnemy.alertTimer > 0 then
        enemyAwareness = "suspicious"
    end

    -- Determine if behind enemy (based on approach direction)
    local isBehind = false
    if mapEnemy and mapEnemy.lastKnownPlayerX then
        -- If enemy was NOT chasing, we can approach from behind
        if mapEnemy.state == "patrol" or mapEnemy.state == "idle" then
            isBehind = true  -- simplified: if enemy is unaware, assume rear approach
        end
    end

    -- Build stealth context
    local context = {
        isIndoor = false,
        timeOfDay = timeOfDay,
        weather = weather,
        terrain = terrain,
        moonPhase = moonPhase,
        isBehindEnemy = isBehind,
        enemyAwareness = enemyAwareness,
        distance = 1,  -- adjacent (collision)
    }

    -- Evaluate approach options
    local approachResult = StealthSystem.evaluateStealthApproach(
        playerData, enemyData, context
    )

    return approachResult
end

-- Hook: Called from tactical_combat.lua advanceTurn() to update smoke zones and guard patrols
-- Returns a list of events that occurred (for combat log messages)
function StealthSystem.hookStartOfRound(combatState, TC)
    StealthSystem.updateSmokeZones(combatState)

    local events = {}

    -- Update guard patrols in building interiors
    if combatState.grid and combatState.grid.guardPatrols then
        local dt = 1.5  -- Approximate one round in seconds
        for _, guard in ipairs(combatState.grid.guardPatrols) do
            StealthSystem.updateGuardPatrol(guard, dt)
            -- Check if guard can see any hidden player units
            if combatState.playerUnit and combatState.playerUnit.isHidden then
                local player = combatState.playerUnit
                local canSee, dist = StealthSystem.guardCanSeePosition(
                    guard, player.x, player.y, guard.route
                )
                if canSee then
                    -- Guard spotted the hidden player
                    StealthSystem.removeHidden(player, TC)
                    table.insert(events, {
                        type = "guard_spotted",
                        message = "A patrolling guard spotted you!",
                        color = {0.9, 0.4, 0.2},
                        guardId = guard.id,
                    })
                end
            end
        end
    end

    return events
end

-- Hook: Called from tactical_combat_ui.lua to add "HIDE" button
-- Returns action definition if hide should be available
function StealthSystem.hookGetHideAction(unit, combatState)
    if unit.isHidden then
        return nil  -- already hidden, no need for hide button
    end
    if unit.hasActed then
        return nil  -- already used action
    end
    -- Check if there's cover nearby
    local hasCover = false
    local neighbors = TileUtils.DIRS4
    if combatState and combatState.grid then
        for _, n in ipairs(neighbors) do
            local nx, ny = unit.x + n[1], unit.y + n[2]
            local tile = combatState.grid.tiles[ny] and combatState.grid.tiles[ny][nx]
            if tile then
                if tile.type == "wall" or tile.type == "obstacle"
                    or tile.lightLevel == "dark" or tile.hasSmoke then
                    hasCover = true
                    break
                end
            end
        end
    end

    return {
        id = "hide",
        name = "HIDE",
        key = "H",
        color = {0.4, 0.4, 0.7},
        available = hasCover,
        tooltip = hasCover and "Attempt to hide (requires cover)" or "No cover nearby",
    }
end


-- ============================================================================
-- SECTION 14: UI RENDERING HELPERS
-- ============================================================================

-- Get the color overlay for a tile based on its light level (for UI rendering)
function StealthSystem.getLightOverlayColor(lightLevel)
    if lightLevel == "dark" then
        return {0, 0, 0.05, 0.55}      -- dark blue-black overlay
    elseif lightLevel == "dim" then
        return {0.05, 0.05, 0.1, 0.30} -- subtle dark overlay
    elseif lightLevel == "bright" then
        return {0.1, 0.1, 0.05, 0.05}  -- very slight warm overlay (almost invisible)
    end
    return {0, 0, 0, 0}  -- no overlay
end

-- Get color for smoke zone tiles
function StealthSystem.getSmokeOverlayColor()
    return {0.5, 0.5, 0.5, 0.45}  -- gray smoke
end

-- Get icon for a light source (for rendering on the grid)
function StealthSystem.getLightSourceIcon(source)
    if not source then return "?", {1, 1, 1} end
    local template = source.template or StealthSystem.LIGHT_SOURCES[source.type]
    if not template then return "?", {1, 1, 1} end

    if source.isLit then
        return template.icon, template.color
    else
        return template.icon, {0.3, 0.3, 0.3}  -- dimmed color when snuffed
    end
end

-- Get the awareness indicator for an NPC (color + icon for UI)
function StealthSystem.getAwarenessIndicator(awarenessState)
    if awarenessState == "unaware" then
        return nil, nil  -- no indicator when unaware
    elseif awarenessState == "suspicious" then
        return "?", {0.9, 0.9, 0.2}
    elseif awarenessState == "alert" then
        return "!", {0.9, 0.6, 0.2}
    elseif awarenessState == "combat" then
        return "!!", {0.9, 0.2, 0.2}
    end
    return nil, nil
end

-- Generate pre-combat stealth menu layout data (for UI rendering)
function StealthSystem.getStealthMenuLayout(approachResult, screenW, screenH)
    local menuW = 420
    local breakdownLines = approachResult.breakdown and #approachResult.breakdown or 0
    local menuH = 60 + breakdownLines * 11 + 8 + #approachResult.options * 48 + 80  -- header + breakdown + options + footer
    local menuX = (screenW - menuW) / 2
    local menuY = (screenH - menuH) / 2

    return {
        x = menuX,
        y = menuY,
        w = menuW,
        h = menuH,
        optionHeight = 48,
        headerHeight = 60,
        footerHeight = 80,
        detectionBarY = menuY + 30,
        detectionBarW = menuW - 40,
    }
end


-- ============================================================================
-- SECTION 15: STEALTH PERK UNLOCK SYSTEM
-- ============================================================================

-- Stealth perk unlock thresholds (total stealth kills + knockouts required)
StealthSystem.PERK_THRESHOLDS = {
    silent_step =   { required = 5,  tier = 1 },
    shadow_blend =  { required = 15, tier = 2 },
    assassinate =   { required = 30, tier = 3 },
    vanish =        { required = 50, tier = 4 },
}

-- Check if any new stealth perks should be unlocked.
-- Called after stealth kills or knockouts.
-- Returns list of newly unlocked perk names (for notification).
function StealthSystem.checkPerkUnlocks(playerData)
    if not playerData then return {} end

    local totalActions = (playerData.stealthKills or 0) + (playerData.stealthKnockouts or 0)
    local perks = playerData.stealthPerks
    if not perks then
        playerData.stealthPerks = {
            silent_step = false,
            shadow_blend = false,
            assassinate = false,
            vanish = false,
        }
        perks = playerData.stealthPerks
    end

    local newlyUnlocked = {}

    -- Check each perk in tier order
    local perkOrder = {"silent_step", "shadow_blend", "assassinate", "vanish"}
    for _, perkId in ipairs(perkOrder) do
        local threshold = StealthSystem.PERK_THRESHOLDS[perkId]
        if threshold and not perks[perkId] and totalActions >= threshold.required then
            -- Check prerequisite
            local skillDef = StealthSystem.SKILL_TREE[perkId]
            if skillDef then
                local prereqMet = true
                if skillDef.prerequisite then
                    prereqMet = perks[skillDef.prerequisite] == true
                end
                if prereqMet then
                    perks[perkId] = true
                    table.insert(newlyUnlocked, skillDef.name)
                    -- Also add to unlockedSkills dict for combat integration
                    if not playerData.unlockedSkills then
                        playerData.unlockedSkills = {start = true}
                    end
                    playerData.unlockedSkills[perkId] = true
                end
            end
        end
    end

    return newlyUnlocked
end

-- Get the stealth skill modifier from unlocked perks
-- Returns total skill stealth modifier for detection calculations
function StealthSystem.getSkillModFromPerks(playerData)
    if not playerData or not playerData.stealthPerks then return 0 end

    local mod = 0
    local perks = playerData.stealthPerks

    if perks.silent_step then
        mod = mod + StealthSystem.SKILL_TREE.silent_step.detectionReduction
    end
    if perks.shadow_blend then
        -- Shadow blend bonus is context-dependent (dim/dark light)
        -- Return a base modifier; context-specific bonus applied elsewhere
        mod = mod + 0.05  -- Small base benefit
    end

    return mod
end


return StealthSystem
