-- Fishing Game Mode - Catch fish and sell them!
-- A relaxing fishing minigame with different fish types, locations, shop, and collection

local Fishing = {}
local UIAssets = require("uiassets")
local Progression = require("progression")
local Backpack = require("backpack")
local Tutorials = require("tutorials")
local InteractiveTutorial = require("interactivetutorial")
local UI = require("ui")

-- Font cache - now using UI library
local function getFont(size)
    return UI.fonts.get(size)
end

-- Game state
local state = {
    active = false,
    casting = false,
    reeling = false,
    fishOnLine = nil,
    castPower = 0,
    lineDepth = 0,
    tension = 0,
    fishCaught = {},        -- {fishId = {count, bestWeight}}
    totalFishCaught = 0,
    currentLocation = "pond",
    currentRod = "basic",
    currentBait = "worm",
    baitCount = 10,
    unlockedLocations = {pond = true},
    ownedRods = {basic = true},

    -- UI state
    showShop = false,
    showCollection = false,
    showEmployees = false,
    shopTab = "rods",       -- rods, bait, locations, upgrades
    notification = nil,
    notificationTimer = 0,
    lastCatch = nil,
    lastCatchTimer = 0,

    -- Visual state
    bobberY = 0,
    bobberBob = 0,
    lineWiggle = 0,
    splashParticles = {},
    waterRipples = {},

    -- Screen shake and juice effects
    screenShake = 0,
    screenShakeIntensity = 0,
    perfectPopups = {},       -- Floating "PERFECT!" text
    catchCelebration = nil,   -- Big celebration for rare catches
    celebrationTimer = 0,

    -- Fish on line indicator
    fishBiteTimer = 0,
    fishBiteFlash = false,
    reelingIndicator = 0,

    -- Input state for continuous reeling
    spaceHeld = false,
    reelButtonHeld = false,  -- For on-screen reel button
    leftHeld = false,
    rightHeld = false,

    -- NEW: Interactive fishing mechanics
    fishDirection = 0,          -- -1 (left), 0 (neutral), 1 (right)
    fishDirectionTimer = 0,
    fishStamina = 100,          -- Fish gets tired (0-100)
    fishMaxStamina = 100,       -- Based on fish rarity
    perfectReelWindow = false,  -- Sweet spot for perfect reels
    perfectReelTimer = 0,
    perfectWindowWarning = false, -- Pre-warning before perfect window
    lastDirectionChange = 0,
    playerDirection = 0,        -- Player's current direction input
    comboCounter = 0,           -- Perfect reel combo
    fishPullStrength = 0,       -- How hard fish is pulling
    lastReelPerfect = false,    -- Was last reel perfect?
    directionIndicatorFlash = 0, -- Flash timer for direction indicator
    directionChangeWarning = false, -- Warning before direction changes
    fishEscapeTimer = 0,        -- Timer for fish escape
    lowBaitWarning = false,     -- Warning when bait is low

    -- Employees and upgrades
    employees = {},
    upgrades = {},

    -- UI Components
    ui = {
        bottomButtons = {},
        shopPanel = nil,
        shopTabBar = nil,
        shopScroll = nil,
        shopButtons = {},
        collectionPanel = nil,
        collectionScroll = nil,
        employeesPanel = nil,
        employeesScroll = nil,
        employeesButtons = {},
        upgradesButtons = {},
    },
}

-- Rarity tier system
local RARITY_TIERS = {
    common = {name = "Common", color = {0.7, 0.7, 0.7}, spawnWeight = 0.40, valueMultiplier = 1.0},
    uncommon = {name = "Uncommon", color = {0.3, 0.9, 0.3}, spawnWeight = 0.30, valueMultiplier = 1.3},
    rare = {name = "Rare", color = {0.3, 0.5, 1.0}, spawnWeight = 0.20, valueMultiplier = 1.8},
    epic = {name = "Epic", color = {0.7, 0.3, 1.0}, spawnWeight = 0.08, valueMultiplier = 2.5},
    legendary = {name = "Legendary", color = {1, 0.8, 0.2}, spawnWeight = 0.015, valueMultiplier = 4.0},
    mythic = {name = "Mythic", color = {1, 0.3, 0.3}, spawnWeight = 0.005, valueMultiplier = 6.0},
}

-- Loot items (materials from fish)
local LOOT_ITEMS = {
    -- Common materials
    {id = "fish_bone", name = "Fish Bone", value = 2, rarity = "common", description = "Basic crafting material"},
    {id = "fish_scale", name = "Fish Scale", value = 3, rarity = "common", description = "Used in armor crafting"},
    {id = "fish_fin", name = "Fish Fin", value = 4, rarity = "common", description = "Potion ingredient"},
    -- Uncommon materials
    {id = "sharp_tooth", name = "Sharp Tooth", value = 8, rarity = "uncommon", description = "Weapon upgrade material"},
    {id = "swim_bladder", name = "Swim Bladder", value = 10, rarity = "uncommon", description = "Alchemy ingredient"},
    -- Rare materials
    {id = "iridescent_scale", name = "Iridescent Scale", value = 20, rarity = "rare", description = "Rare crafting material"},
    {id = "caviar", name = "Caviar", value = 25, rarity = "rare", description = "Valuable food item"},
    -- Epic materials
    {id = "dragon_scale", name = "Dragon Scale", value = 50, rarity = "epic", description = "Legendary armor material"},
    {id = "shark_tooth", name = "Shark Tooth", value = 40, rarity = "epic", description = "Powerful weapon material"},
    -- Legendary materials
    {id = "phoenix_feather", name = "Phoenix Feather", value = 100, rarity = "legendary", description = "Magic item material"},
    {id = "sea_crystal", name = "Sea Crystal", value = 120, rarity = "legendary", description = "Enchantment material"},
}

-- Treasure items
local TREASURE_ITEMS = {
    {id = "treasure_chest", name = "Treasure Chest", value = 500, description = "Contains gold and random items"},
    {id = "ancient_relic", name = "Ancient Relic", value = 300, description = "A mysterious artifact"},
    {id = "message_bottle", name = "Message in a Bottle", value = 50, description = "Contains a cryptic message"},
}

-- Junk items
local JUNK_ITEMS = {
    {id = "old_boot", name = "Old Boot", value = 1, description = "Smells terrible"},
    {id = "tin_can", name = "Tin Can", value = 1, description = "Rusty and empty"},
    {id = "soggy_newspaper", name = "Soggy Newspaper", value = 1, description = "Unreadable"},
    {id = "broken_rod", name = "Broken Rod", value = 5, description = "Could be recycled"},
}

-- Fish types with rarity tiers, values, depth requirements, fight strength, and loot tables
local FISH_TYPES = {
    -- COMMON TIER (Gray) - Easy fights, basic loot
    {id = "minnow", name = "Minnow", tier = "common", value = 5, rarity = 0.40, minDepth = 0, maxDepth = 30, locations = {"pond", "river"}, minWeight = 0.1, maxWeight = 0.3, fightStrength = 0.2,
        dropTable = {{item = "fish_bone", chance = 0.8}, {item = "fish_scale", chance = 0.5}}},
    {id = "perch", name = "Perch", tier = "common", value = 8, rarity = 0.35, minDepth = 10, maxDepth = 40, locations = {"pond", "river"}, minWeight = 0.3, maxWeight = 0.8, fightStrength = 0.25,
        dropTable = {{item = "fish_bone", chance = 0.8}, {item = "fish_scale", chance = 0.6}}},
    {id = "carp", name = "Carp", tier = "common", value = 15, rarity = 0.30, minDepth = 20, maxDepth = 60, locations = {"pond", "river"}, minWeight = 1, maxWeight = 5, fightStrength = 0.4,
        dropTable = {{item = "fish_bone", chance = 0.85}, {item = "fish_scale", chance = 0.7}, {item = "fish_fin", chance = 0.4}}},
    {id = "bluegill", name = "Bluegill", tier = "common", value = 12, rarity = 0.32, minDepth = 15, maxDepth = 50, locations = {"pond", "lake"}, minWeight = 0.5, maxWeight = 1.5, fightStrength = 0.3,
        dropTable = {{item = "fish_bone", chance = 0.75}, {item = "fish_scale", chance = 0.6}}},
    {id = "flounder", name = "Flounder", tier = "common", value = 18, rarity = 0.28, minDepth = 20, maxDepth = 60, locations = {"ocean"}, minWeight = 1, maxWeight = 3, fightStrength = 0.35,
        dropTable = {{item = "fish_bone", chance = 0.8}, {item = "fish_fin", chance = 0.5}}},

    -- UNCOMMON TIER (Green) - Moderate fights, better loot
    {id = "bass", name = "Bass", tier = "uncommon", value = 25, rarity = 0.25, minDepth = 30, maxDepth = 80, locations = {"pond", "river", "lake"}, minWeight = 2, maxWeight = 8, fightStrength = 0.6,
        dropTable = {{item = "fish_scale", chance = 0.8}, {item = "sharp_tooth", chance = 0.4}, {item = "fish_fin", chance = 0.6}}},
    {id = "trout", name = "Trout", tier = "uncommon", value = 35, rarity = 0.20, minDepth = 40, maxDepth = 90, locations = {"river", "lake"}, minWeight = 1, maxWeight = 6, fightStrength = 0.7,
        dropTable = {{item = "fish_scale", chance = 0.85}, {item = "sharp_tooth", chance = 0.35}, {item = "swim_bladder", chance = 0.3}}},
    {id = "walleye", name = "Walleye", tier = "uncommon", value = 32, rarity = 0.22, minDepth = 35, maxDepth = 85, locations = {"lake", "river"}, minWeight = 2, maxWeight = 7, fightStrength = 0.65,
        dropTable = {{item = "fish_scale", chance = 0.8}, {item = "sharp_tooth", chance = 0.4}, {item = "caviar", chance = 0.15}}},
    {id = "pickerel", name = "Pickerel", tier = "uncommon", value = 30, rarity = 0.23, minDepth = 30, maxDepth = 75, locations = {"pond", "lake"}, minWeight = 1.5, maxWeight = 6, fightStrength = 0.62,
        dropTable = {{item = "sharp_tooth", chance = 0.5}, {item = "fish_scale", chance = 0.7}}},
    {id = "mackerel", name = "Mackerel", tier = "uncommon", value = 40, rarity = 0.20, minDepth = 30, maxDepth = 70, locations = {"ocean"}, minWeight = 1, maxWeight = 4, fightStrength = 0.5,
        dropTable = {{item = "fish_scale", chance = 0.8}, {item = "swim_bladder", chance = 0.4}}},
    {id = "cod", name = "Cod", tier = "uncommon", value = 38, rarity = 0.21, minDepth = 35, maxDepth = 75, locations = {"ocean"}, minWeight = 2, maxWeight = 8, fightStrength = 0.55,
        dropTable = {{item = "fish_scale", chance = 0.75}, {item = "fish_fin", chance = 0.6}, {item = "swim_bladder", chance = 0.35}}},

    -- RARE TIER (Blue) - Challenging fights, valuable loot
    {id = "salmon", name = "Salmon", tier = "rare", value = 60, rarity = 0.15, minDepth = 50, maxDepth = 100, locations = {"river", "ocean"}, minWeight = 3, maxWeight = 15, fightStrength = 0.85,
        dropTable = {{item = "iridescent_scale", chance = 0.5}, {item = "caviar", chance = 0.6}, {item = "sharp_tooth", chance = 0.4}}},
    {id = "catfish", name = "Catfish", tier = "rare", value = 75, rarity = 0.12, minDepth = 60, maxDepth = 100, locations = {"lake", "river"}, minWeight = 5, maxWeight = 25, fightStrength = 0.9,
        dropTable = {{item = "iridescent_scale", chance = 0.45}, {item = "sharp_tooth", chance = 0.7}, {item = "swim_bladder", chance = 0.5}}},
    {id = "pike", name = "Pike", tier = "rare", value = 100, rarity = 0.10, minDepth = 70, maxDepth = 100, locations = {"lake"}, minWeight = 4, maxWeight = 20, fightStrength = 0.95,
        dropTable = {{item = "iridescent_scale", chance = 0.55}, {item = "sharp_tooth", chance = 0.8}, {item = "caviar", chance = 0.4}}},
    {id = "sturgeon", name = "Sturgeon", tier = "rare", value = 110, rarity = 0.09, minDepth = 65, maxDepth = 100, locations = {"lake", "river"}, minWeight = 10, maxWeight = 50, fightStrength = 1.0,
        dropTable = {{item = "iridescent_scale", chance = 0.6}, {item = "caviar", chance = 0.8}, {item = "swim_bladder", chance = 0.45}}},
    {id = "halibut", name = "Halibut", tier = "rare", value = 85, rarity = 0.11, minDepth = 55, maxDepth = 95, locations = {"ocean"}, minWeight = 8, maxWeight = 40, fightStrength = 0.88,
        dropTable = {{item = "iridescent_scale", chance = 0.5}, {item = "fish_fin", chance = 0.7}, {item = "caviar", chance = 0.5}}},

    -- EPIC TIER (Purple) - Very challenging, epic rewards
    {id = "tuna", name = "Tuna", tier = "epic", value = 150, rarity = 0.06, minDepth = 60, maxDepth = 100, locations = {"ocean"}, minWeight = 20, maxWeight = 100, fightStrength = 1.2,
        dropTable = {{item = "iridescent_scale", chance = 0.7}, {item = "shark_tooth", chance = 0.5}, {item = "caviar", chance = 0.6}}},
    {id = "swordfish", name = "Swordfish", tier = "epic", value = 200, rarity = 0.04, minDepth = 80, maxDepth = 100, locations = {"ocean"}, minWeight = 50, maxWeight = 200, fightStrength = 1.4,
        dropTable = {{item = "shark_tooth", chance = 0.8}, {item = "iridescent_scale", chance = 0.6}, {item = "dragon_scale", chance = 0.3}}},
    {id = "marlin", name = "Marlin", tier = "epic", value = 220, rarity = 0.03, minDepth = 75, maxDepth = 100, locations = {"ocean"}, minWeight = 60, maxWeight = 250, fightStrength = 1.5,
        dropTable = {{item = "shark_tooth", chance = 0.75}, {item = "dragon_scale", chance = 0.35}, {item = "caviar", chance = 0.5}}},
    {id = "mako_shark", name = "Mako Shark", tier = "epic", value = 240, rarity = 0.025, minDepth = 80, maxDepth = 100, locations = {"ocean"}, minWeight = 80, maxWeight = 300, fightStrength = 1.6,
        dropTable = {{item = "shark_tooth", chance = 0.9}, {item = "dragon_scale", chance = 0.4}, {item = "iridescent_scale", chance = 0.6}}},
    {id = "giant_squid", name = "Giant Squid", tier = "epic", value = 180, rarity = 0.05, minDepth = 85, maxDepth = 100, locations = {"ocean"}, minWeight = 40, maxWeight = 150, fightStrength = 1.3,
        dropTable = {{item = "dragon_scale", chance = 0.45}, {item = "swim_bladder", chance = 0.7}, {item = "iridescent_scale", chance = 0.65}}},

    -- LEGENDARY TIER (Gold) - Boss-level fights, legendary rewards
    {id = "golden_carp", name = "Golden Carp", tier = "legendary", value = 500, rarity = 0.010, minDepth = 50, maxDepth = 100, locations = {"pond", "lake"}, minWeight = 2, maxWeight = 10, fightStrength = 1.1,
        dropTable = {{item = "dragon_scale", chance = 0.8}, {item = "sea_crystal", chance = 0.5}, {item = "caviar", chance = 0.9}}},
    {id = "crystal_bass", name = "Crystal Bass", tier = "legendary", value = 550, rarity = 0.009, minDepth = 60, maxDepth = 100, locations = {"lake"}, minWeight = 3, maxWeight = 12, fightStrength = 1.15,
        dropTable = {{item = "sea_crystal", chance = 0.6}, {item = "iridescent_scale", chance = 0.9}, {item = "dragon_scale", chance = 0.7}}},
    {id = "moon_trout", name = "Moon Trout", tier = "legendary", value = 520, rarity = 0.008, minDepth = 55, maxDepth = 100, locations = {"river", "lake"}, minWeight = 2.5, maxWeight = 11, fightStrength = 1.12,
        dropTable = {{item = "sea_crystal", chance = 0.55}, {item = "phoenix_feather", chance = 0.4}, {item = "caviar", chance = 0.85}}},
    {id = "phantom_pike", name = "Phantom Pike", tier = "legendary", value = 580, rarity = 0.007, minDepth = 65, maxDepth = 100, locations = {"lake"}, minWeight = 5, maxWeight = 25, fightStrength = 1.2,
        dropTable = {{item = "phoenix_feather", chance = 0.5}, {item = "dragon_scale", chance = 0.75}, {item = "shark_tooth", chance = 0.8}}},

    -- MYTHIC TIER (Red) - Ultimate challenges, mythic rewards
    {id = "sea_dragon", name = "Sea Dragon", tier = "mythic", value = 1000, rarity = 0.003, minDepth = 90, maxDepth = 100, locations = {"ocean"}, minWeight = 100, maxWeight = 500, fightStrength = 2.5,
        dropTable = {{item = "dragon_scale", chance = 1.0}, {item = "phoenix_feather", chance = 0.8}, {item = "sea_crystal", chance = 0.9}, {item = "shark_tooth", chance = 0.85}}},
    {id = "leviathan", name = "Leviathan", tier = "mythic", value = 1200, rarity = 0.002, minDepth = 95, maxDepth = 100, locations = {"ocean"}, minWeight = 200, maxWeight = 800, fightStrength = 2.8,
        dropTable = {{item = "dragon_scale", chance = 1.0}, {item = "sea_crystal", chance = 1.0}, {item = "phoenix_feather", chance = 0.9}, {item = "shark_tooth", chance = 0.9}}},
    {id = "phoenix_koi", name = "Phoenix Koi", tier = "mythic", value = 1500, rarity = 0.001, minDepth = 80, maxDepth = 100, locations = {"pond", "lake"}, minWeight = 5, maxWeight = 20, fightStrength = 2.2,
        dropTable = {{item = "phoenix_feather", chance = 1.0}, {item = "sea_crystal", chance = 0.95}, {item = "dragon_scale", chance = 0.9}, {item = "caviar", chance = 1.0}}},
}

-- Fishing locations
local LOCATIONS = {
    {id = "pond", name = "Village Pond", unlockCost = 0, fishBonus = 1.0, description = "Calm waters, good for beginners", waterColor = {0.2, 0.4, 0.5}},
    {id = "river", name = "Forest River", unlockCost = 200, fishBonus = 1.2, description = "Flowing water, better catches", waterColor = {0.15, 0.35, 0.45}},
    {id = "lake", name = "Mountain Lake", unlockCost = 800, fishBonus = 1.5, description = "Deep waters, rare fish", waterColor = {0.1, 0.3, 0.5}},
    {id = "ocean", name = "Deep Ocean", unlockCost = 2500, fishBonus = 2.0, description = "Dangerous but legendary fish await", waterColor = {0.05, 0.2, 0.4}},
}

-- Fishing rods
local RODS = {
    {id = "basic", name = "Basic Rod", castPower = 50, reelSpeed = 1.0, tensionMax = 50, cost = 0, description = "A simple wooden rod"},
    {id = "sturdy", name = "Sturdy Rod", castPower = 70, reelSpeed = 1.2, tensionMax = 75, cost = 300, description = "Reinforced for bigger catches"},
    {id = "pro", name = "Pro Rod", castPower = 90, reelSpeed = 1.5, tensionMax = 100, cost = 1200, description = "Professional grade equipment"},
    {id = "master", name = "Master Rod", castPower = 100, reelSpeed = 2.0, tensionMax = 150, cost = 5000, description = "The ultimate fishing rod"},
}

-- Bait types
local BAITS = {
    {id = "worm", name = "Worm", rarityBonus = 0, cost = 5, description = "Basic bait, attracts common fish"},
    {id = "cricket", name = "Cricket", rarityBonus = 0.02, cost = 15, description = "Attracts mid-tier fish"},
    {id = "shrimp", name = "Shrimp", rarityBonus = 0.05, cost = 35, description = "Good for rare catches"},
    {id = "golden_lure", name = "Golden Lure", rarityBonus = 0.15, cost = 150, description = "Legendary fish love this!"},
}

-- Employee types for fishing dock
local EMPLOYEE_TYPES = {
    {id = "dock_hand", name = "Dock Hand", baseSalary = 20, hireCost = 100, effect = "passive_coins", effectValue = 15, desc = "Earns passive income from dock duties"},
    {id = "bait_collector", name = "Bait Collector", baseSalary = 30, hireCost = 200, effect = "free_bait", effectValue = 2, desc = "Provides free bait each day"},
    {id = "fishing_instructor", name = "Fishing Instructor", baseSalary = 50, hireCost = 500, effect = "xp_bonus", effectValue = 0.15, desc = "+15% XP from fishing"},
    {id = "fish_finder", name = "Fish Finder", baseSalary = 75, hireCost = 800, effect = "rare_bonus", effectValue = 0.05, desc = "+5% chance for rare fish"},
    {id = "master_angler", name = "Master Angler", baseSalary = 100, hireCost = 1500, effect = "value_bonus", effectValue = 0.20, desc = "+20% fish selling value"},
}

-- Upgrades for fishing
local UPGRADES = {
    {id = "line_strength", name = "Reinforced Line", cost = 300, maxLevel = 5, effect = "tension_bonus", effectPerLevel = 10, desc = "+10 max tension per level"},
    {id = "quick_reel", name = "Quick Reel", cost = 500, maxLevel = 3, effect = "reel_speed", effectPerLevel = 0.15, desc = "+15% reel speed per level"},
    {id = "fish_sense", name = "Fish Sense", cost = 400, maxLevel = 4, effect = "bite_rate", effectPerLevel = 0.10, desc = "+10% bite chance per level"},
    {id = "lucky_charm", name = "Lucky Charm", cost = 750, maxLevel = 3, effect = "rare_chance", effectPerLevel = 0.03, desc = "+3% rare fish chance per level"},
    {id = "tackle_box", name = "Tackle Box", cost = 600, maxLevel = 5, effect = "bait_save", effectPerLevel = 0.05, desc = "+5% chance to not consume bait per level"},
}

-- Get fish by ID
local function getFishById(id)
    for _, fish in ipairs(FISH_TYPES) do
        if fish.id == id then return fish end
    end
    return nil
end

-- Get location by ID
local function getLocationById(id)
    for _, loc in ipairs(LOCATIONS) do
        if loc.id == id then return loc end
    end
    return LOCATIONS[1]
end

-- Get rod by ID
local function getRodById(id)
    for _, rod in ipairs(RODS) do
        if rod.id == id then return rod end
    end
    return RODS[1]
end

-- Get bait by ID
local function getBaitById(id)
    for _, bait in ipairs(BAITS) do
        if bait.id == id then return bait end
    end
    return BAITS[1]
end

-- Get loot item by ID
local function getLootItemById(id)
    for _, item in ipairs(LOOT_ITEMS) do
        if item.id == id then return item end
    end
    return nil
end

-- Get treasure item by ID
local function getTreasureItemById(id)
    for _, item in ipairs(TREASURE_ITEMS) do
        if item.id == id then return item end
    end
    return nil
end

-- Get junk item by ID
local function getJunkItemById(id)
    for _, item in ipairs(JUNK_ITEMS) do
        if item.id == id then return item end
    end
    return nil
end

-- Get rarity tier color for a fish
local function getRarityColor(fish)
    if fish.tier and RARITY_TIERS[fish.tier] then
        return RARITY_TIERS[fish.tier].color
    end
    return {0.7, 0.7, 0.7}  -- Default gray
end

-- Forward declarations for functions that are called before their definitions
local updateFishingPassiveIncome
local initializeBottomButtons
local getUpgradeLevel
local saveFishingData
local addNotification
local createShopUI
local createShopButtons
local createCollectionUI
local createEmployeesUI

-- Initialize fishing game
function Fishing.init()
    state.active = true
    state.casting = false
    state.reeling = false
    state.fishOnLine = nil
    state.castPower = 0
    state.lineDepth = 0
    state.tension = 0
    state.showShop = false
    state.showCollection = false
    state.showEmployees = false
    state.fishBiteTimer = 0
    state.fishBiteFlash = false
    state.reelingIndicator = 0
    state.spaceHeld = false
    state.reelButtonHeld = false
    state.fishEscapeTimer = 0

    -- Reset interactive fishing states
    state.fishDirection = 0
    state.fishDirectionTimer = 0
    state.fishStamina = 100
    state.fishMaxStamina = 100
    state.perfectReelWindow = false
    state.perfectReelTimer = 0
    state.perfectWindowWarning = false
    state.playerDirection = 0
    state.comboCounter = 0
    state.lastReelPerfect = false
    state.directionIndicatorFlash = 0
    state.directionChangeWarning = false
    state.leftHeld = false
    state.rightHeld = false

    -- Load saved fishing data or initialize
    if not PlayerData.fishingData then
        PlayerData.fishingData = {
            fishCaught = {},
            totalFishCaught = 0,
            unlockedLocations = {pond = true},
            ownedRods = {basic = true},
            currentRod = "basic",
            currentBait = "worm",
            baitCount = 10,
            currentLocation = "pond",
            employees = {},
            upgrades = {},
        }
        savePlayerData()
    end

    -- Load state from PlayerData
    state.fishCaught = PlayerData.fishingData.fishCaught or {}
    state.totalFishCaught = PlayerData.fishingData.totalFishCaught or 0
    state.unlockedLocations = PlayerData.fishingData.unlockedLocations or {pond = true}
    state.ownedRods = PlayerData.fishingData.ownedRods or {basic = true}
    state.currentRod = PlayerData.fishingData.currentRod or "basic"
    state.currentBait = PlayerData.fishingData.currentBait or "worm"
    state.baitCount = PlayerData.fishingData.baitCount or 10
    state.currentLocation = PlayerData.fishingData.currentLocation or "pond"
    state.employees = PlayerData.fishingData.employees or {}
    state.upgrades = PlayerData.fishingData.upgrades or {}

    Backpack.init()

    -- Calculate initial passive income rate
    updateFishingPassiveIncome()

    -- Register UI region resolver for interactive tutorials
    InteractiveTutorial.registerRegionResolver("fishing", Fishing.getUIRegion)

    -- Check if tutorial should start
    if not Tutorials.hasCompleted("fishing") then
        Tutorials.startTutorial("fishing")
    end

    -- Initialize UI components
    initializeBottomButtons()
end

-- Initialize bottom button row UI components
initializeBottomButtons = function()
    local screenW, screenH = love.graphics.getDimensions()
    local btnY = screenH - 45
    local btnH = 35

    state.ui.bottomButtons = {}

    -- Shop button
    table.insert(state.ui.bottomButtons, UI.Button.new({
        x = 20,
        y = btnY,
        w = 90,
        h = btnH,
        text = "[TAB] Shop",
        variant = "ghost",
        onClick = function()
            state.showShop = true
            createShopUI()
        end
    }))

    -- Collection button
    table.insert(state.ui.bottomButtons, UI.Button.new({
        x = 115,
        y = btnY,
        w = 90,
        h = btnH,
        text = "[C] Journal",
        variant = "ghost",
        onClick = function()
            state.showCollection = true
            createCollectionUI()
        end
    }))

    -- Employees button
    table.insert(state.ui.bottomButtons, UI.Button.new({
        x = 210,
        y = btnY,
        w = 90,
        h = btnH,
        text = "[E] Staff",
        variant = "ghost",
        onClick = function()
            state.showEmployees = true
            createEmployeesUI()
        end
    }))

    -- Bait button
    table.insert(state.ui.bottomButtons, UI.Button.new({
        x = 305,
        y = btnY,
        w = 90,
        h = btnH,
        text = "[Q] Bait",
        variant = "ghost",
        onClick = function()
            Fishing.cycleBait()
        end
    }))

    -- Reel button
    table.insert(state.ui.bottomButtons, UI.Button.new({
        x = 400,
        y = btnY,
        w = 100,
        h = btnH,
        text = "[R] Reel",
        variant = "ghost",
        onClick = function()
            if state.lineDepth > 0 and not state.casting then
                state.reelButtonHeld = true
            end
        end
    }))

    -- Store reel button bounds for compatibility
    state.reelButtonBounds = {x = 400, y = btnY, w = 100, h = btnH}
end

-- Create shop UI components
createShopUI = function()
    local screenW, screenH = love.graphics.getDimensions()
    local panelW, panelH = 600, 450
    local panelX = screenW/2 - panelW/2
    local panelY = screenH/2 - panelH/2

    -- Create tab bar
    state.ui.shopTabBar = UI.TabBar.new({
        x = panelX + 20,
        y = panelY + 55,
        w = 320,
        tabs = {
            {id = "rods", label = "Rods"},
            {id = "bait", label = "Bait"},
            {id = "locations", label = "Locations"}
        },
        activeTab = state.shopTab,
        onChange = function(tabId)
            state.shopTab = tabId
            createShopButtons()
        end
    })

    -- Create scroll container for items
    state.ui.shopScroll = UI.ScrollContainer.new({
        x = panelX + 20,
        y = panelY + 100,
        w = panelW - 40,
        h = panelH - 120,
        contentHeight = 0  -- Will be calculated when creating buttons
    })

    -- Create main panel
    state.ui.shopPanel = UI.Panel.new({
        x = panelX,
        y = panelY,
        w = panelW,
        h = panelH,
        title = "FISHING SHOP",
        showClose = true,
        onClose = function()
            state.showShop = false
            state.ui.shopPanel = nil
            state.ui.shopTabBar = nil
            state.ui.shopScroll = nil
            state.ui.shopButtons = {}
        end
    })

    createShopButtons()
end

-- Create shop item buttons based on current tab
createShopButtons = function()
    if not state.ui.shopScroll then return end

    state.ui.shopButtons = {}
    local screenW, screenH = love.graphics.getDimensions()
    local panelW, panelH = 600, 450
    local panelX = screenW/2 - panelW/2
    local panelY = screenH/2 - panelH/2
    local contentY = panelY + 100

    if state.shopTab == "rods" then
        local itemCount = #RODS
        state.ui.shopScroll.contentHeight = itemCount * 70

        for i, rod in ipairs(RODS) do
            local owned = state.ownedRods[rod.id]
            local equipped = state.currentRod == rod.id

            if not equipped then
                local btn = UI.Button.new({
                    x = panelX + panelW - 100,
                    y = contentY + (i - 1) * 70 + 15,
                    w = 70,
                    h = 30,
                    text = owned and "Equip" or (rod.cost .. "g"),
                    variant = owned and "success" or "primary",
                    disabled = not owned and PlayerData.coins < rod.cost,
                    onClick = function()
                        if owned then
                            state.currentRod = rod.id
                            saveFishingData()
                            createShopButtons()
                        else
                            Fishing.buyRod(rod.id)
                            createShopButtons()
                        end
                    end
                })
                table.insert(state.ui.shopButtons, btn)
            end
        end
    elseif state.shopTab == "bait" then
        local itemCount = #BAITS
        state.ui.shopScroll.contentHeight = itemCount * 70

        for i, bait in ipairs(BAITS) do
            local btn = UI.Button.new({
                x = panelX + panelW - 100,
                y = contentY + (i - 1) * 70 + 15,
                w = 70,
                h = 30,
                text = "5 for " .. (bait.cost * 5) .. "g",
                variant = "primary",
                disabled = PlayerData.coins < bait.cost * 5,
                onClick = function()
                    Fishing.buyBait(bait.id, 5)
                    createShopButtons()
                end
            })
            table.insert(state.ui.shopButtons, btn)
        end
    elseif state.shopTab == "locations" then
        local itemCount = #LOCATIONS
        state.ui.shopScroll.contentHeight = itemCount * 70

        for i, loc in ipairs(LOCATIONS) do
            local unlocked = state.unlockedLocations[loc.id]
            local isActive = state.currentLocation == loc.id

            if not isActive then
                local btn = UI.Button.new({
                    x = panelX + panelW - 100,
                    y = contentY + (i - 1) * 70 + 15,
                    w = 70,
                    h = 30,
                    text = unlocked and "Travel" or (loc.unlockCost .. "g"),
                    variant = unlocked and "success" or "primary",
                    disabled = not unlocked and PlayerData.coins < loc.unlockCost,
                    onClick = function()
                        if unlocked then
                            state.currentLocation = loc.id
                            saveFishingData()
                            createShopButtons()
                        else
                            Fishing.unlockLocation(loc.id)
                            createShopButtons()
                        end
                    end
                })
                table.insert(state.ui.shopButtons, btn)
            end
        end
    end
end

-- Create collection UI components
createCollectionUI = function()
    local screenW, screenH = love.graphics.getDimensions()
    local panelW, panelH = 650, 500
    local panelX = screenW/2 - panelW/2
    local panelY = screenH/2 - panelH/2

    state.ui.collectionPanel = UI.Panel.new({
        x = panelX,
        y = panelY,
        w = panelW,
        h = panelH,
        title = "FISH JOURNAL",
        showClose = true,
        onClose = function()
            state.showCollection = false
            state.ui.collectionPanel = nil
            state.ui.collectionScroll = nil
        end
    })

    -- Calculate grid content height
    local cardH = 80
    local rows = math.ceil(#FISH_TYPES / 4)
    local contentHeight = rows * (cardH + 10)

    state.ui.collectionScroll = UI.ScrollContainer.new({
        x = panelX + 20,
        y = panelY + 80,
        w = panelW - 40,
        h = panelH - 100,
        contentHeight = contentHeight
    })
end

-- Create employees UI components
createEmployeesUI = function()
    local screenW, screenH = love.graphics.getDimensions()
    local panelW, panelH = 700, 520
    local panelX = screenW/2 - panelW/2
    local panelY = screenH/2 - panelH/2

    state.ui.employeesPanel = UI.Panel.new({
        x = panelX,
        y = panelY,
        w = panelW,
        h = panelH,
        title = "DOCK STAFF & UPGRADES",
        showClose = true,
        onClose = function()
            state.showEmployees = false
            state.ui.employeesPanel = nil
            state.ui.employeesScroll = nil
            state.ui.employeesButtons = {}
            state.ui.upgradesButtons = {}
        end
    })

    local contentY = panelY + 55
    local empY = contentY + 30

    -- Create employee hire buttons
    state.ui.employeesButtons = {}
    for i, empType in ipairs(EMPLOYEE_TYPES) do
        local owned = false
        for _, emp in ipairs(state.employees) do
            if emp.type == empType.id then
                owned = true
                break
            end
        end

        if not owned then
            local btn = UI.Button.new({
                x = panelX + 20 + 230,
                y = empY + (i - 1) * 70 + 15,
                w = 80,
                h = 30,
                text = "Hire " .. empType.hireCost .. "g",
                variant = "success",
                disabled = PlayerData.coins < empType.hireCost,
                onClick = function()
                    if PlayerData.coins >= empType.hireCost then
                        PlayerData.coins = PlayerData.coins - empType.hireCost
                        table.insert(state.employees, {type = empType.id, hiredDay = 1})
                        saveFishingData()
                        updateFishingPassiveIncome()
                        addNotification("Hired " .. empType.name .. "!", 2)
                        createEmployeesUI()
                    else
                        addNotification("Not enough coins!", 2)
                    end
                end
            })
            table.insert(state.ui.employeesButtons, btn)
        end
    end

    -- Create upgrade buttons
    state.ui.upgradesButtons = {}
    local upgY = contentY + 30
    for i, upg in ipairs(UPGRADES) do
        local currentLevel = getUpgradeLevel(upg.id)
        local maxed = currentLevel >= upg.maxLevel
        local cost = upg.cost * (currentLevel + 1)

        if not maxed then
            local btn = UI.Button.new({
                x = panelX + 360 + 230,
                y = upgY + (i - 1) * 70 + 15,
                w = 80,
                h = 30,
                text = cost .. "g",
                variant = "primary",
                disabled = PlayerData.coins < cost,
                onClick = function()
                    if PlayerData.coins >= cost then
                        PlayerData.coins = PlayerData.coins - cost
                        state.upgrades[upg.id] = currentLevel + 1
                        saveFishingData()
                        addNotification("Upgraded " .. upg.name .. " to level " .. (currentLevel + 1) .. "!", 2)
                        createEmployeesUI()
                    else
                        addNotification("Not enough coins!", 2)
                    end
                end
            })
            table.insert(state.ui.upgradesButtons, btn)
        end
    end
end

-- Called after init to update passive income
function Fishing.updatePassiveIncome()
    updateFishingPassiveIncome()
end

-- Save fishing data
saveFishingData = function()
    PlayerData.fishingData = {
        fishCaught = state.fishCaught,
        totalFishCaught = state.totalFishCaught,
        unlockedLocations = state.unlockedLocations,
        ownedRods = state.ownedRods,
        currentRod = state.currentRod,
        currentBait = state.currentBait,
        baitCount = state.baitCount,
        currentLocation = state.currentLocation,
        employees = state.employees,
        upgrades = state.upgrades,
    }
    savePlayerData()
end

-- Calculate and update passive income from fishing employees
updateFishingPassiveIncome = function()
    local totalRate = 0

    -- Calculate income from employees with passive_coins effect
    for _, emp in ipairs(state.employees) do
        for _, empType in ipairs(EMPLOYEE_TYPES) do
            if empType.id == emp.type and empType.effect == "passive_coins" then
                -- Convert daily rate to per-second rate (assuming 8 hour "day")
                -- effectValue is daily income, divide by 28800 (8*60*60) for per-second
                local perSecondRate = empType.effectValue / 28800
                totalRate = totalRate + perSecondRate
            end
        end
    end

    -- Use global helper to update passive income
    if updatePassiveIncomeSource then
        updatePassiveIncomeSource("fishing", totalRate)
    end
end

-- Get upgrade level
getUpgradeLevel = function(upgradeId)
    return state.upgrades[upgradeId] or 0
end

-- Get total bonus from employees of a specific type
local function getEmployeeBonus(effectType)
    local total = 0
    for _, emp in ipairs(state.employees) do
        for _, empType in ipairs(EMPLOYEE_TYPES) do
            if empType.id == emp.type and empType.effect == effectType then
                total = total + empType.effectValue
            end
        end
    end
    return total
end

-- Get total bonus from upgrades of a specific type
local function getUpgradeBonus(effectType)
    local total = 0
    for _, upg in ipairs(UPGRADES) do
        local level = getUpgradeLevel(upg.id)
        if upg.effect == effectType and level > 0 then
            total = total + (upg.effectPerLevel * level)
        end
    end
    return total
end

-- Add notification
addNotification = function(text, duration)
    state.notification = text
    state.notificationTimer = duration or 2
end

-- Add splash particles
local function addSplash(x, y)
    for i = 1, 8 do
        table.insert(state.splashParticles, {
            x = x,
            y = y,
            vx = (math.random() - 0.5) * 100,
            vy = -math.random() * 80 - 40,
            life = 0.5 + math.random() * 0.3,
            size = 3 + math.random() * 4,
        })
    end
end

-- Add water ripple
local function addRipple(x, y)
    table.insert(state.waterRipples, {
        x = x,
        y = y,
        radius = 5,
        maxRadius = 40 + math.random() * 20,
        alpha = 0.6,
    })
end

-- Trigger screen shake
local function triggerScreenShake(intensity, duration)
    state.screenShake = duration or 0.3
    state.screenShakeIntensity = intensity or 5
end

-- Spawn floating "PERFECT!" popup
local function spawnPerfectPopup(text, color)
    local screenW = love.graphics.getWidth()
    table.insert(state.perfectPopups, {
        text = text or "PERFECT!",
        x = screenW / 2 + (math.random() - 0.5) * 100,
        y = love.graphics.getHeight() * 0.5,
        vy = -80,
        life = 1.2,
        scale = 1.5,
        color = color or {0.3, 1, 0.3},
    })
end

-- Trigger catch celebration for rare fish
local function triggerCelebration(fish, rarity)
    local tierData = RARITY_TIERS[rarity]
    if rarity == "legendary" or rarity == "mythic" or rarity == "epic" then
        state.catchCelebration = {
            fishName = fish.name,
            rarity = rarity,
            color = tierData and tierData.color or {1, 1, 1},
        }
        state.celebrationTimer = 2.5
        triggerScreenShake(12, 0.5)
    elseif rarity == "rare" then
        triggerScreenShake(6, 0.3)
    end
end

-- Update fishing game
function Fishing.update(dt)
    if not state.active then return end

    -- Update tutorial
    Tutorials.update(dt)

    -- Update UI components
    for _, btn in ipairs(state.ui.bottomButtons) do
        if btn.update then btn:update(dt) end
    end

    if state.showShop and state.ui.shopPanel then
        state.ui.shopPanel:update(dt)
        if state.ui.shopTabBar then state.ui.shopTabBar:update(dt) end
        if state.ui.shopScroll then state.ui.shopScroll:update(dt) end
        for _, btn in ipairs(state.ui.shopButtons) do
            if btn.update then btn:update(dt) end
        end
    end

    if state.showCollection and state.ui.collectionPanel then
        state.ui.collectionPanel:update(dt)
        if state.ui.collectionScroll then state.ui.collectionScroll:update(dt) end
    end

    if state.showEmployees and state.ui.employeesPanel then
        state.ui.employeesPanel:update(dt)
        for _, btn in ipairs(state.ui.employeesButtons) do
            if btn.update then btn:update(dt) end
        end
        for _, btn in ipairs(state.ui.upgradesButtons) do
            if btn.update then btn:update(dt) end
        end
    end

    -- Update notification timer
    if state.notification then
        state.notificationTimer = state.notificationTimer - dt
        if state.notificationTimer <= 0 then
            state.notification = nil
        end
    end

    -- Update last catch display
    if state.lastCatch then
        state.lastCatchTimer = state.lastCatchTimer - dt
        if state.lastCatchTimer <= 0 then
            state.lastCatch = nil
        end
    end

    -- Update particles
    for i = #state.splashParticles, 1, -1 do
        local p = state.splashParticles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.vy = p.vy + 200 * dt  -- Gravity
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(state.splashParticles, i)
        end
    end

    -- Update ripples
    for i = #state.waterRipples, 1, -1 do
        local r = state.waterRipples[i]
        r.radius = r.radius + 40 * dt
        r.alpha = r.alpha - dt * 0.8
        if r.alpha <= 0 or r.radius >= r.maxRadius then
            table.remove(state.waterRipples, i)
        end
    end

    -- Update screen shake decay
    if state.screenShake > 0 then
        state.screenShake = state.screenShake - dt
        if state.screenShake < 0 then
            state.screenShake = 0
            state.screenShakeIntensity = 0
        end
    end

    -- Update perfect popups (floating text)
    for i = #state.perfectPopups, 1, -1 do
        local p = state.perfectPopups[i]
        p.y = p.y + p.vy * dt
        p.life = p.life - dt
        p.scale = p.scale * (1 - dt * 0.3)  -- Shrink slightly
        if p.life <= 0 then
            table.remove(state.perfectPopups, i)
        end
    end

    -- Update celebration timer
    if state.celebrationTimer > 0 then
        state.celebrationTimer = state.celebrationTimer - dt
        if state.celebrationTimer <= 0 then
            state.catchCelebration = nil
        end
    end

    -- Don't update gameplay if shop/collection is open or tutorial is active
    if state.showShop or state.showCollection or state.showEmployees or Tutorials.isActive() then
        return
    end

    -- Update casting power if holding cast
    if state.casting then
        state.castPower = state.castPower + dt * 80
        if state.castPower > 100 then
            state.castPower = 100
        end
    end

    -- Update bobber animation
    if state.lineDepth > 0 then
        state.bobberBob = state.bobberBob + dt * 3
        state.bobberY = math.sin(state.bobberBob) * 3
    end

    -- Update fish bite flash animation
    if state.fishOnLine then
        state.fishBiteTimer = state.fishBiteTimer + dt
        state.fishBiteFlash = math.floor(state.fishBiteTimer * 4) % 2 == 0
    else
        state.fishBiteTimer = 0
        state.fishBiteFlash = false
    end

    -- NEW: Interactive fish fighting mechanics
    if state.fishOnLine then
        local fish = state.fishOnLine.fish
        local fightStrength = fish.fightStrength or 0.5

        -- Direction change timer (faster changes for stronger fish)
        local directionChangeInterval = math.max(1.5, 4.5 - (fightStrength * 2))  -- 1.5-4.5 seconds
        state.fishDirectionTimer = state.fishDirectionTimer + dt

        -- Direction change warning (0.5 seconds before change)
        local timeUntilChange = directionChangeInterval - state.fishDirectionTimer
        state.directionChangeWarning = timeUntilChange <= 0.5 and timeUntilChange > 0

        if state.fishDirectionTimer >= directionChangeInterval then
            -- Change fish direction (-1, 0, or 1)
            local rand = math.random()
            if rand < 0.4 then
                state.fishDirection = -1  -- Left
            elseif rand < 0.8 then
                state.fishDirection = 1   -- Right
            else
                state.fishDirection = 0   -- Neutral
            end

            state.fishDirectionTimer = 0
            state.directionIndicatorFlash = 0  -- Reset flash
            state.directionChangeWarning = false
        end

        -- Flash indicator for new directions
        state.directionIndicatorFlash = state.directionIndicatorFlash + dt

        -- Perfect reel window logic
        state.perfectReelTimer = state.perfectReelTimer + dt

        -- Random chance to trigger perfect reel window (higher chance for harder fish)
        if not state.perfectReelWindow and not state.perfectWindowWarning then
            local perfectChance = 0.15 + (fightStrength * 0.1)  -- 15-35% chance per second
            if math.random() < perfectChance * dt then
                -- Show warning first, then window
                state.perfectWindowWarning = true
                state.perfectReelTimer = 0
            end
        end

        -- Warning phase transitions to actual window after 0.4 seconds
        if state.perfectWindowWarning and not state.perfectReelWindow then
            if state.perfectReelTimer >= 0.4 then
                state.perfectReelWindow = true
                state.perfectWindowWarning = false
                state.perfectReelTimer = 0
            end
        end

        -- Perfect window expires after 0.7 seconds (slightly longer than before)
        if state.perfectReelWindow and state.perfectReelTimer >= 0.7 then
            state.perfectReelWindow = false
            if state.comboCounter > 0 then
                state.comboCounter = math.max(0, state.comboCounter - 1)  -- Lose combo
            end
        end

        -- Direction matching bonus/penalty
        if state.fishDirection ~= 0 then  -- Fish is pulling left or right
            if state.playerDirection == state.fishDirection then
                -- MATCHING - reduce tension, bonus stamina drain
                state.tension = math.max(0, state.tension - 12 * dt)
                if state.reeling then
                    state.fishStamina = state.fishStamina - (8 + state.comboCounter * 2) * dt
                end
            elseif state.playerDirection ~= 0 and state.playerDirection ~= state.fishDirection then
                -- WRONG DIRECTION - big tension increase!
                state.tension = state.tension + 25 * dt * fightStrength
            else
                -- NEUTRAL (not pressing arrows) - normal tension
                if state.reeling then
                    state.tension = state.tension + 5 * dt
                end
            end
        end

        -- Fish stamina drain when reeling (even without direction match)
        if state.reeling then
            local staminaDrain = 5 * dt
            if state.lastReelPerfect then
                staminaDrain = staminaDrain * 2  -- Perfect reels drain 2x stamina
            end
            state.fishStamina = math.max(0, state.fishStamina - staminaDrain)
        end

        -- Exhausted fish = much easier catch
        if state.fishStamina <= 0 then
            state.tension = math.max(0, state.tension - 20 * dt)  -- Tension drops fast
        end
    else
        -- Reset interactive state when no fish
        state.fishDirection = 0
        state.playerDirection = 0
        state.perfectReelWindow = false
        state.perfectWindowWarning = false
        state.perfectReelTimer = 0
        state.directionChangeWarning = false
        state.comboCounter = 0
        state.fishStamina = 100
        state.lastReelPerfect = false
    end

    -- Update reeling indicator
    if state.reeling then
        state.reelingIndicator = math.min(1, state.reelingIndicator + dt * 4)
    else
        state.reelingIndicator = math.max(0, state.reelingIndicator - dt * 3)
    end

    -- Update fishing when line is in water
    if state.lineDepth > 0 and not state.casting then
        -- Continuous reeling while space or reel button is held
        if (state.spaceHeld or state.reelButtonHeld) and state.lineDepth > 0 then
            state.reeling = true
            local rod = Fishing.getCurrentRod()
            local reelSpeedBonus = 1 + getUpgradeBonus("reel_speed")
            local reelAmount = 50 * rod.reelSpeed * reelSpeedBonus * dt  -- Reel speed per second

            if state.fishOnLine then
                -- Reeling with fish - slower and adds tension
                state.lineDepth = state.lineDepth - reelAmount * 0.7
                state.tension = state.tension + 8 * dt  -- Tension builds while reeling

                -- Check if caught
                if state.lineDepth <= 0 then
                    state.lineDepth = 0
                    Fishing.catchFish()
                end
            else
                -- Reeling without fish - faster, no tension
                state.lineDepth = state.lineDepth - reelAmount * 1.5
                if state.lineDepth <= 0 then
                    state.lineDepth = 0
                    state.reeling = false
                end
            end
        else
            state.reeling = false
        end

        -- Random chance for fish to bite (only when not reeling)
        if not state.fishOnLine and not state.reeling then
            local bait = getBaitById(state.currentBait)
            local biteRateBonus = 1 + getUpgradeBonus("bite_rate")  -- Fish Sense upgrade
            -- Higher base chance: 0.8 base + bait bonus, multiply by dt for per-frame chance
            local biteChance = (0.8 + (bait.rarityBonus * 3)) * biteRateBonus  -- Better bait = more bites
            if math.random() < biteChance * dt then
                Fishing.tryHookFish()
            end
        end

        -- If fish on line, it fights (reduces tension when not reeling)
        if state.fishOnLine then
            state.lineWiggle = state.lineWiggle + dt * 20
            local fightStrength = state.fishOnLine.fish.value / 100  -- Valuable fish fight harder

            if state.reeling then
                -- Fish fights harder when being reeled
                state.tension = state.tension + (math.random() * 0.5) * dt * 15 * (1 + fightStrength)
            else
                -- Tension slowly decreases when not reeling, but fish may tug
                state.tension = state.tension + (math.random() - 0.6) * dt * 20 * (1 + fightStrength)
            end

            if state.tension < 0 then state.tension = 0 end

            -- Fish may escape if you don't reel for too long
            if not state.reeling then
                state.fishEscapeTimer = (state.fishEscapeTimer or 0) + dt
                if state.fishEscapeTimer > 8 then  -- 8 seconds without reeling
                    addNotification(state.fishOnLine.fish.name .. " got away! Reel faster!", 2)
                    state.fishOnLine = nil
                    state.tension = 0
                    state.fishEscapeTimer = 0
                    state.perfectReelWindow = false
                    state.perfectWindowWarning = false
                    state.perfectReelTimer = 0
                    state.directionChangeWarning = false
                end
            else
                state.fishEscapeTimer = 0
            end
        end
    end

    -- Check for line break
    local rod = Fishing.getCurrentRod()
    if state.tension > rod.tensionMax then
        Fishing.lineBreak()
    end
end

-- Try to hook a fish based on current conditions
function Fishing.tryHookFish()
    local location = state.currentLocation
    local depth = state.lineDepth
    local bait = getBaitById(state.currentBait)

    -- Check for treasure catch (1% chance)
    if math.random() < 0.01 then
        local treasure = TREASURE_ITEMS[math.random(#TREASURE_ITEMS)]
        -- Create special treasure catch
        local fakeFish = {
            id = treasure.id,
            name = treasure.name,
            value = treasure.value,
            tier = "legendary",
            fightStrength = 0.3,
            minWeight = 1,
            maxWeight = 5,
        }
        state.fishOnLine = {
            fish = fakeFish,
            weight = math.random() * 4 + 1,
            isTreasure = true,
        }
        state.tension = 10
        state.lineWiggle = 0

        -- Initialize minimal fishing state
        state.fishStamina = 50
        state.fishMaxStamina = 50
        state.fishDirection = 0
        state.fishDirectionTimer = 0
        state.playerDirection = 0
        state.perfectReelWindow = false
        state.perfectReelTimer = 0
        state.comboCounter = 0
        state.lastReelPerfect = false
        state.directionIndicatorFlash = 0

        local screenW = love.graphics.getWidth()
        addSplash(screenW / 2, love.graphics.getHeight() * 0.5)
        addRipple(screenW / 2, love.graphics.getHeight() * 0.5)
        addNotification("✨ " .. treasure.name .. " hooked!", 2)
        triggerScreenShake(10, 0.4)  -- Big shake for treasure!
        return
    end

    -- Check for junk catch (5% chance)
    if math.random() < 0.05 then
        local junk = JUNK_ITEMS[math.random(#JUNK_ITEMS)]
        -- Create special junk catch
        local fakeFish = {
            id = junk.id,
            name = junk.name,
            value = junk.value,
            tier = "common",
            fightStrength = 0.1,
            minWeight = 0.5,
            maxWeight = 2,
        }
        state.fishOnLine = {
            fish = fakeFish,
            weight = math.random() * 1.5 + 0.5,
            isJunk = true,
        }
        state.tension = 5
        state.lineWiggle = 0

        -- Initialize minimal fishing state
        state.fishStamina = 20
        state.fishMaxStamina = 20
        state.fishDirection = 0
        state.fishDirectionTimer = 0
        state.playerDirection = 0
        state.perfectReelWindow = false
        state.perfectReelTimer = 0
        state.comboCounter = 0
        state.lastReelPerfect = false
        state.directionIndicatorFlash = 0

        local screenW = love.graphics.getWidth()
        addSplash(screenW / 2, love.graphics.getHeight() * 0.5)
        addNotification(junk.name .. " hooked...", 1.5)
        return
    end

    -- Calculate rarity bonuses from employees and upgrades
    local rareBonus = getEmployeeBonus("rare_bonus") + getUpgradeBonus("rare_chance")

    -- Find eligible fish (all fish that match location and depth)
    local eligible = {}
    local totalWeight = 0
    for _, fish in ipairs(FISH_TYPES) do
        local locationMatch = false
        for _, loc in ipairs(fish.locations) do
            if loc == location then
                locationMatch = true
                break
            end
        end

        if locationMatch and depth >= fish.minDepth and depth <= fish.maxDepth then
            -- Use rarity as weight for selection (higher rarity = more common)
            local weight = fish.rarity + bait.rarityBonus + rareBonus
            table.insert(eligible, {fish = fish, weight = weight})
            totalWeight = totalWeight + weight
        end
    end

    -- Select a fish using weighted random selection
    if #eligible > 0 and totalWeight > 0 then
        local roll = math.random() * totalWeight
        local cumulative = 0
        local selectedFish = eligible[1].fish  -- Default to first

        for _, entry in ipairs(eligible) do
            cumulative = cumulative + entry.weight
            if roll <= cumulative then
                selectedFish = entry.fish
                break
            end
        end

        local fish = selectedFish
        local weight = fish.minWeight + math.random() * (fish.maxWeight - fish.minWeight)
        weight = math.floor(weight * 10) / 10  -- Round to 1 decimal

        -- Check for trophy variant (5% chance)
        local isTrophy = math.random() < 0.05
        local trophyName = fish.name
        if isTrophy then
            -- Trophy fish have special names
            local trophyPrefixes = {"Trophy ", "Lunker ", "Giant ", "Massive ", "Prize "}
            trophyName = trophyPrefixes[math.random(#trophyPrefixes)] .. fish.name
            weight = weight * 1.5  -- Trophy fish are 50% heavier
        end

        state.fishOnLine = {
            fish = fish,
            weight = weight,
            isTrophy = isTrophy,
            displayName = trophyName,
        }
        state.tension = 15 + fish.value / 20  -- Starting tension based on fish value
        state.lineWiggle = 0

        -- NEW: Initialize interactive fishing state
        local fightStrength = fish.fightStrength or 0.5
        state.fishStamina = 60 + (fightStrength * 50)  -- 60-185 stamina based on strength
        state.fishMaxStamina = state.fishStamina
        state.fishDirection = 0
        state.fishDirectionTimer = 0
        state.playerDirection = 0
        state.perfectReelWindow = false
        state.perfectReelTimer = 0
        state.comboCounter = 0
        state.lastReelPerfect = false
        state.directionIndicatorFlash = 0

        -- Visual feedback
        local screenW = love.graphics.getWidth()
        addSplash(screenW / 2, love.graphics.getHeight() * 0.5)
        addRipple(screenW / 2, love.graphics.getHeight() * 0.5)

        -- Screen shake based on fish rarity - more impressive fish = bigger shake
        local shakeIntensity = 4  -- base shake
        if fish.tier == "uncommon" then shakeIntensity = 5
        elseif fish.tier == "rare" then shakeIntensity = 7
        elseif fish.tier == "epic" then shakeIntensity = 9
        elseif fish.tier == "legendary" then shakeIntensity = 11
        elseif fish.tier == "mythic" then shakeIntensity = 14
        end
        if isTrophy then shakeIntensity = shakeIntensity + 3 end
        triggerScreenShake(shakeIntensity, 0.3)

        addNotification(trophyName .. " on the line!", 1.5)
    end
end

-- Get current rod stats (with upgrade bonuses applied)
function Fishing.getCurrentRod()
    local rod = getRodById(state.currentRod)
    -- Create a copy with upgrade bonuses
    local tensionBonus = getUpgradeBonus("tension_bonus")
    return {
        id = rod.id,
        name = rod.name,
        castPower = rod.castPower,
        reelSpeed = rod.reelSpeed,
        tensionMax = rod.tensionMax + tensionBonus,
        cost = rod.cost,
        description = rod.description
    }
end

-- Get current bait stats
function Fishing.getCurrentBait()
    return getBaitById(state.currentBait)
end

-- Line breaks - fish escapes
function Fishing.lineBreak()
    local fishName = state.fishOnLine and state.fishOnLine.fish.name or "Fish"
    addNotification("Line snapped! " .. fishName .. " got away!", 2)

    state.fishOnLine = nil
    state.tension = 0
    state.lineDepth = 0
    state.casting = false
    state.reeling = false
    state.lineWiggle = 0
    state.perfectReelWindow = false
    state.perfectWindowWarning = false
    state.perfectReelTimer = 0
    state.directionChangeWarning = false
    state.comboCounter = 0
    state.fishEscapeTimer = 0

    -- Visual feedback
    local screenW = love.graphics.getWidth()
    addSplash(screenW / 2, love.graphics.getHeight() * 0.5)
end

-- Catch the fish!
function Fishing.catchFish()
    if state.fishOnLine then
        local catch = state.fishOnLine
        local fish = catch.fish
        local weight = catch.weight
        local isTrophy = catch.isTrophy or false
        local location = getLocationById(state.currentLocation)

        -- Trophy fish get bonus value and weight
        local trophyMultiplier = isTrophy and 2.0 or 1.0

        -- Calculate value with all bonuses
        local weightBonus = 1 + (fish.maxWeight > 0 and (weight / fish.maxWeight) or 0) * 0.5  -- Up to 50% bonus for max weight
        local valueBonus = 1 + getEmployeeBonus("value_bonus")  -- Master Angler bonus
        local tierBonus = RARITY_TIERS[fish.tier] and RARITY_TIERS[fish.tier].valueMultiplier or 1.0
        local value = math.floor(fish.value * location.fishBonus * weightBonus * valueBonus * tierBonus * trophyMultiplier)

        -- Add to player's coins
        PlayerData.coins = PlayerData.coins + value

        -- Award XP based on fish tier with XP bonus from instructor
        local xpBonus = 1 + getEmployeeBonus("xp_bonus")
        local baseXP = 10
        if fish.tier == "uncommon" then baseXP = 15
        elseif fish.tier == "rare" then baseXP = 25
        elseif fish.tier == "epic" then baseXP = 40
        elseif fish.tier == "legendary" then baseXP = 60
        elseif fish.tier == "mythic" then baseXP = 100
        end
        if isTrophy then baseXP = baseXP * 1.5 end
        local xpReward = math.floor(baseXP * xpBonus)
        Progression.addXP(xpReward, "fishing")

        -- Trigger celebration for rare catches!
        triggerCelebration(fish, fish.tier)
        if isTrophy then
            spawnPerfectPopup("TROPHY!", {1, 0.84, 0})  -- Gold color for trophy
        end

        -- Process material drops from fish
        local droppedItems = {}
        if fish.dropTable then
            for _, drop in ipairs(fish.dropTable) do
                if math.random() < drop.chance then
                    local lootItem = getLootItemById(drop.item)
                    if lootItem then
                        -- Add to backpack
                        Backpack.addItem(lootItem.id, 1)
                        table.insert(droppedItems, lootItem.name)
                    end
                end
            end
        end

        -- Update fish caught records (only real fish, not treasure/junk)
        if not catch.isTreasure and not catch.isJunk then
            if not state.fishCaught[fish.id] then
                state.fishCaught[fish.id] = {count = 0, bestWeight = 0}
            end
            state.fishCaught[fish.id].count = state.fishCaught[fish.id].count + 1
            if weight > state.fishCaught[fish.id].bestWeight then
                state.fishCaught[fish.id].bestWeight = weight
            end
            state.totalFishCaught = state.totalFishCaught + 1
        end

        -- Use bait (with tackle box upgrade chance to save) - skip for junk catches
        if not catch.isJunk then
            local baitSaveChance = getUpgradeBonus("bait_save")
            if math.random() >= baitSaveChance then
                state.baitCount = state.baitCount - 1
                if state.baitCount <= 0 then
                    state.baitCount = 0
                    state.currentBait = "worm"  -- Fall back to basic
                    addNotification("Out of bait! Switched to worms.", 2)
                end
            else
                addNotification("Tackle Box saved your bait!", 1)
            end
        end

        -- Show material drops notification
        if #droppedItems > 0 then
            addNotification("Materials: " .. table.concat(droppedItems, ", "), 2)
        end

        -- Show catch result
        state.lastCatch = {fish = fish, weight = weight, value = value, isTrophy = isTrophy, materials = droppedItems}
        state.lastCatchTimer = 4

        -- Reset state
        state.fishOnLine = nil
        state.tension = 0
        state.lineDepth = 0
        state.lineWiggle = 0
        state.comboCounter = 0  -- Reset combo on successful catch
        state.perfectReelWindow = false
        state.perfectWindowWarning = false
        state.perfectReelTimer = 0
        state.directionChangeWarning = false
        state.fishEscapeTimer = 0

        -- Visual feedback
        local screenW = love.graphics.getWidth()
        addSplash(screenW / 2, love.graphics.getHeight() * 0.5)

        -- Save progress
        saveFishingData()

        return fish, value, weight
    end
    return nil
end

-- Buy rod
function Fishing.buyRod(rodId)
    local rod = getRodById(rodId)
    if not rod then return false, "Invalid rod" end
    if state.ownedRods[rodId] then return false, "Already owned" end
    if PlayerData.coins < rod.cost then return false, "Not enough coins" end

    PlayerData.coins = PlayerData.coins - rod.cost
    state.ownedRods[rodId] = true
    state.currentRod = rodId
    saveFishingData()
    addNotification("Purchased " .. rod.name .. "!", 2)
    return true
end

-- Buy bait
function Fishing.buyBait(baitId, amount)
    local bait = getBaitById(baitId)
    if not bait then return false, "Invalid bait" end
    local cost = bait.cost * amount
    if PlayerData.coins < cost then return false, "Not enough coins" end

    PlayerData.coins = PlayerData.coins - cost
    if state.currentBait == baitId then
        state.baitCount = state.baitCount + amount
    else
        state.currentBait = baitId
        state.baitCount = amount
    end
    saveFishingData()
    addNotification("Purchased " .. amount .. "x " .. bait.name .. "!", 2)
    return true
end

-- Cycle to next available bait type (or switch to worms if out)
function Fishing.cycleBait()
    -- Don't allow changing bait while fishing
    if state.lineDepth > 0 or state.casting or state.fishOnLine then
        addNotification("Can't change bait while fishing!", 1.5)
        return
    end

    -- If out of current bait, switch to worms
    if state.baitCount <= 0 then
        state.currentBait = "worm"
        state.baitCount = 5
        addNotification("Out of bait! Free worms x5", 1.5)
        saveFishingData()
        return
    end

    -- Show current bait info and prompt to use shop
    local bait = getBaitById(state.currentBait)
    addNotification("Using " .. bait.name .. " x" .. state.baitCount .. " | [TAB] Shop for more", 2)
end

-- Unlock location
function Fishing.unlockLocation(locationId)
    local location = getLocationById(locationId)
    if not location then return false, "Invalid location" end
    if state.unlockedLocations[locationId] then return false, "Already unlocked" end
    if PlayerData.coins < location.unlockCost then return false, "Not enough coins" end

    PlayerData.coins = PlayerData.coins - location.unlockCost
    state.unlockedLocations[locationId] = true
    state.currentLocation = locationId
    saveFishingData()
    addNotification("Unlocked " .. location.name .. "!", 2)
    return true
end

-- Draw the fishing game
function Fishing.draw()
    local screenW, screenH = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()

    UIAssets.clearTooltip()

    -- Apply screen shake
    love.graphics.push()
    if state.screenShake > 0 then
        local shakeX = (math.random() - 0.5) * 2 * state.screenShakeIntensity
        local shakeY = (math.random() - 0.5) * 2 * state.screenShakeIntensity
        love.graphics.translate(shakeX, shakeY)
    end

    -- Draw background
    local location = getLocationById(state.currentLocation)
    if not UIAssets.drawGameBackground("fishing", 1) then
        -- Fallback gradient background (sky)
        love.graphics.setColor(0.4, 0.6, 0.8)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH * 0.4)

        -- Water
        love.graphics.setColor(location.waterColor)
        love.graphics.rectangle("fill", 0, screenH * 0.4, screenW, screenH * 0.6)
    end

    -- Draw water ripples
    for _, r in ipairs(state.waterRipples) do
        love.graphics.setColor(1, 1, 1, r.alpha * 0.3)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", r.x, r.y, r.radius)
    end
    love.graphics.setLineWidth(1)

    -- Draw fishing line and bobber if cast
    if state.lineDepth > 0 or state.casting then
        local rodX = screenW * 0.3
        local rodY = screenH * 0.35
        local bobberX = screenW / 2
        local bobberBaseY = screenH * 0.5
        local bobberY = bobberBaseY + state.bobberY

        -- Line wiggle when fish is hooked
        local wiggleOffset = 0
        if state.fishOnLine then
            wiggleOffset = math.sin(state.lineWiggle) * 8
        end

        -- Draw fishing line
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.setLineWidth(2)
        love.graphics.line(rodX, rodY, bobberX + wiggleOffset, bobberY)
        love.graphics.setLineWidth(1)

        -- Draw bobber
        if state.lineDepth > 0 then
            love.graphics.setColor(1, 0.3, 0.2)
            love.graphics.circle("fill", bobberX + wiggleOffset, bobberY, 8)
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("fill", bobberX + wiggleOffset, bobberY - 4, 4)

            -- Depth indicator line going down
            love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
            local depthLineLen = math.min(state.lineDepth, 80)
            love.graphics.line(bobberX + wiggleOffset, bobberY + 8, bobberX + wiggleOffset, bobberY + 8 + depthLineLen)
        end
    end

    -- Draw splash particles
    for _, p in ipairs(state.splashParticles) do
        local alpha = p.life / 0.8
        love.graphics.setColor(0.7, 0.85, 1, alpha)
        love.graphics.circle("fill", p.x, p.y, p.size * alpha)
    end

    -- Draw UI overlay (stats panel)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 10, 10, 220, 140, 8, 8)

    love.graphics.setColor(0.4, 0.7, 1)
    love.graphics.setFont(getFont(20))
    love.graphics.print("FISHING", 20, 15)

    UIAssets.drawCurrencyWithTooltip("coins", PlayerData.coins, 20, 42, 16)

    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.setFont(getFont(12))
    love.graphics.print("Location: " .. location.name, 20, 68)
    love.graphics.print("Depth: " .. math.floor(state.lineDepth) .. "m", 20, 88)

    local rod = Fishing.getCurrentRod()
    local bait = Fishing.getCurrentBait()
    love.graphics.print("Rod: " .. rod.name, 20, 108)
    love.graphics.print("Bait: " .. bait.name .. " x" .. state.baitCount, 20, 128)

    -- Draw "Waiting for bite" indicator when line is in water but no fish yet
    if state.lineDepth > 0 and not state.fishOnLine and not state.casting then
        local waitPulse = (math.sin(love.timer.getTime() * 2) + 1) / 2  -- 0 to 1 pulsing

        if state.reeling then
            -- Reeling in (no fish)
            love.graphics.setColor(0.3, 0.5, 0.4, 0.85)
            love.graphics.rectangle("fill", screenW/2 - 100, 20, 200, 55, 8, 8)
            love.graphics.setColor(0.5, 0.8, 0.6, 0.8)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", screenW/2 - 100, 20, 200, 55, 8, 8)
            love.graphics.setLineWidth(1)

            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.setFont(getFont(14))
            love.graphics.printf("⚙️ Reeling in...", screenW/2 - 90, 28, 180, "center")
            love.graphics.setColor(0.8, 0.9, 0.8, 0.9)
            love.graphics.setFont(getFont(11))
            love.graphics.printf("Depth: " .. math.floor(state.lineDepth) .. "m", screenW/2 - 90, 48, 180, "center")
        else
            -- Waiting for bite
            love.graphics.setColor(0.2, 0.4, 0.6, 0.7 + waitPulse * 0.2)
            love.graphics.rectangle("fill", screenW/2 - 110, 20, 220, 60, 8, 8)
            love.graphics.setColor(0.4, 0.7, 1, 0.6 + waitPulse * 0.3)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", screenW/2 - 110, 20, 220, 60, 8, 8)
            love.graphics.setLineWidth(1)

            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.setFont(getFont(14))
            local dots = string.rep(".", math.floor(love.timer.getTime() * 2) % 4)
            love.graphics.printf("Waiting for bite" .. dots, screenW/2 - 100, 26, 200, "center")
            love.graphics.setColor(0.7, 0.8, 1, 0.8)
            love.graphics.setFont(getFont(10))
            love.graphics.printf("Depth: " .. math.floor(state.lineDepth) .. "m", screenW/2 - 100, 46, 200, "center")
            love.graphics.setColor(0.6, 0.7, 0.8, 0.7)
            love.graphics.setFont(getFont(9))
            love.graphics.printf("[Hold SPACE to reel in]", screenW/2 - 100, 60, 200, "center")
        end
    end

    -- Draw FISH ON LINE indicator (large, flashing)
    if state.fishOnLine then
        -- Flashing background
        local flashAlpha = state.fishBiteFlash and 0.95 or 0.85
        local flashColor = state.fishBiteFlash and {0.9, 0.3, 0.2} or {0.7, 0.2, 0.15}

        love.graphics.setColor(flashColor[1], flashColor[2], flashColor[3], flashAlpha)
        love.graphics.rectangle("fill", screenW/2 - 150, 20, 300, 100, 12, 12)

        -- Flashing border
        love.graphics.setColor(1, 1, state.fishBiteFlash and 0.3 or 0.6)
        love.graphics.setLineWidth(4)
        love.graphics.rectangle("line", screenW/2 - 150, 20, 300, 100, 12, 12)
        love.graphics.setLineWidth(1)

        -- FISH ON LINE! text
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(20))
        love.graphics.printf("🐟 FISH ON LINE! 🐟", screenW/2 - 140, 28, 280, "center")

        -- Fish name
        love.graphics.setColor(1, 0.95, 0.7)
        love.graphics.setFont(getFont(16))
        love.graphics.printf(state.fishOnLine.fish.name .. " (" .. state.fishOnLine.weight .. " kg)", screenW/2 - 140, 52, 280, "center")

        -- Tension bar
        local tensionPercent = state.tension / rod.tensionMax
        local tensionColor = {0.2, 0.8, 0.2}
        if tensionPercent > 0.8 then
            tensionColor = {0.9, 0.2, 0.2}
        elseif tensionPercent > 0.5 then
            tensionColor = {0.9, 0.9, 0.2}
        end

        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", screenW/2 - 130, 76, 260, 16, 4, 4)

        love.graphics.setColor(tensionColor)
        love.graphics.rectangle("fill", screenW/2 - 128, 78, 256 * tensionPercent, 12, 3, 3)

        -- Tension label
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.setFont(getFont(10))
        love.graphics.printf("TENSION - Hold SPACE to Reel!", screenW/2 - 130, 95, 260, "center")
    end

    -- Direction indicator
    if state.fishOnLine and state.fishDirection ~= 0 then
        local flashAlpha = (math.sin(state.directionIndicatorFlash * 10) + 1) / 2
        local dirText = state.fishDirection < 0 and "◄◄◄ LEFT! ◄◄◄" or "►►► RIGHT! ►►►"
        local arrowKey = state.fishDirection < 0 and "[← Arrow]" or "[→ Arrow]"
        local isMatching = state.playerDirection == state.fishDirection
        local dirColor = isMatching and {0.3, 1, 0.3} or {1, 0.3, 0.3}

        love.graphics.setColor(dirColor[1], dirColor[2], dirColor[3], 0.85 + flashAlpha * 0.15)
        love.graphics.setFont(getFont(20))
        love.graphics.printf(dirText, screenW/2 - 150, screenH * 0.32, 300, "center")

        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.setFont(getFont(12))
        love.graphics.printf(arrowKey, screenW/2 - 150, screenH * 0.32 + 26, 300, "center")
    end

    -- Perfect window warning (pre-warning before actual window)
    if state.perfectWindowWarning then
        local pulse = math.sin(love.timer.getTime() * 15) * 0.3 + 0.7
        love.graphics.setColor(0.9, 0.9, 0.3, pulse * 0.8)
        love.graphics.rectangle("fill", screenW/2 - 100, screenH * 0.68, 200, 40, 8, 8)

        love.graphics.setColor(0, 0, 0)
        love.graphics.setFont(getFont(14))
        love.graphics.printf("⚡ GET READY! ⚡", screenW/2 - 90, screenH * 0.68 + 12, 180, "center")
    end

    -- Perfect reel window
    if state.perfectReelWindow then
        local urgency = state.perfectReelTimer / 0.7
        love.graphics.setColor(0.3, 1, 0.3, 0.95 - urgency * 0.25)
        love.graphics.rectangle("fill", screenW/2 - 110, screenH * 0.68, 220, 45, 8, 8)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(18))
        love.graphics.printf("✨ SPACE NOW! ✨", screenW/2 - 100, screenH * 0.68 + 13, 200, "center")
    end

    -- Direction change warning
    if state.directionChangeWarning and state.fishOnLine then
        local pulse = math.sin(love.timer.getTime() * 20) * 0.4 + 0.6
        love.graphics.setColor(1, 0.6, 0.2, pulse)
        love.graphics.setFont(getFont(12))
        love.graphics.printf("⚠️ Direction changing soon!", screenW/2 - 100, screenH * 0.28, 200, "center")
    end

    -- Escape countdown timer
    if state.fishOnLine and state.fishEscapeTimer and state.fishEscapeTimer > 3 then
        local timeLeft = math.ceil(8 - state.fishEscapeTimer)
        local urgency = state.fishEscapeTimer / 8
        love.graphics.setColor(1, 0.3, 0.3, 0.5 + urgency * 0.5)
        love.graphics.rectangle("fill", screenW/2 - 90, 195, 180, 30, 6, 6)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(14))
        love.graphics.printf("⚠️ REEL! Fish escapes in " .. timeLeft .. "s!", screenW/2 - 85, 201, 170, "center")
    end

    -- Combo counter
    if state.comboCounter > 0 then
        love.graphics.setColor(1, 0.9, 0.3, 0.95)
        love.graphics.setFont(getFont(16 + state.comboCounter * 2))
        love.graphics.printf("COMBO x" .. state.comboCounter, screenW/2 - 100, 50, 200, "center")
    end

    -- Fish stamina bar (add below tension bar)
    if state.fishOnLine then
        local staminaPercent = state.fishStamina / state.fishMaxStamina
        local staminaColor = staminaPercent > 0.25 and {0.3, 0.8, 0.9} or {0.9, 0.3, 0.3}

        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", screenW/2 - 130, 160, 260, 12, 4, 4)

        love.graphics.setColor(staminaColor[1], staminaColor[2], staminaColor[3])
        love.graphics.rectangle("fill", screenW/2 - 128, 162, 256 * staminaPercent, 8, 3, 3)

        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.setFont(getFont(9))
        love.graphics.printf("FISH STAMINA", screenW/2 - 130, 174, 260, "center")
    end

    -- Draw reeling indicator
    if state.reelingIndicator > 0 and state.fishOnLine then
        local reelingAlpha = state.reelingIndicator * 0.9
        love.graphics.setColor(0.2, 0.7, 0.9, reelingAlpha)
        love.graphics.rectangle("fill", screenW/2 - 80, 125, 160, 30, 6, 6)

        love.graphics.setColor(1, 1, 1, reelingAlpha)
        love.graphics.setFont(getFont(14))
        love.graphics.printf("⚙️ REELING... ⚙️", screenW/2 - 75, 132, 150, "center")
    end

    -- Draw cast power meter
    if state.casting then
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", screenW/2 - 120, screenH - 100, 240, 50, 8, 8)

        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", screenW/2 - 110, screenH - 90, 220, 20, 4, 4)

        love.graphics.setColor(0.2, 0.6, 0.9)
        love.graphics.rectangle("fill", screenW/2 - 108, screenH - 88, 216 * (state.castPower / 100), 16, 3, 3)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(12))
        love.graphics.printf("Hold SPACE - Release to Cast", screenW/2 - 110, screenH - 65, 220, "center")
    end

    -- Draw "No Bait" warning when idle and out of bait
    if state.baitCount <= 0 and state.lineDepth == 0 and not state.casting then
        local warnPulse = (math.sin(love.timer.getTime() * 3) + 1) / 2
        love.graphics.setColor(0.7, 0.3, 0.2, 0.8 + warnPulse * 0.15)
        love.graphics.rectangle("fill", screenW/2 - 120, screenH - 110, 240, 50, 8, 8)
        love.graphics.setColor(1, 0.5, 0.3, 0.9)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", screenW/2 - 120, screenH - 110, 240, 50, 8, 8)
        love.graphics.setLineWidth(1)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(14))
        love.graphics.printf("OUT OF BAIT!", screenW/2 - 110, screenH - 102, 220, "center")
        love.graphics.setColor(1, 0.9, 0.7)
        love.graphics.setFont(getFont(11))
        love.graphics.printf("Press [Q] for free worms or [TAB] Shop", screenW/2 - 110, screenH - 82, 220, "center")
    end

    -- Draw "Low Bait" warning when bait is 1-3
    if state.baitCount > 0 and state.baitCount <= 3 and state.lineDepth == 0 and not state.casting then
        love.graphics.setColor(0.6, 0.5, 0.2, 0.85)
        love.graphics.rectangle("fill", screenW/2 + 80, screenH - 100, 100, 35, 6, 6)
        love.graphics.setColor(1, 0.9, 0.5)
        love.graphics.setFont(getFont(10))
        love.graphics.printf("Low Bait!", screenW/2 + 85, screenH - 95, 90, "center")
        love.graphics.printf(state.baitCount .. " left", screenW/2 + 85, screenH - 78, 90, "center")
    end

    -- Draw "Ready to Cast" prompt when idle with bait
    if state.baitCount > 0 and state.lineDepth == 0 and not state.casting and not state.fishOnLine then
        love.graphics.setColor(0.2, 0.4, 0.3, 0.8)
        love.graphics.rectangle("fill", screenW/2 - 100, screenH - 100, 200, 40, 8, 8)
        love.graphics.setColor(0.4, 0.8, 0.5, 0.8)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", screenW/2 - 100, screenH - 100, 200, 40, 8, 8)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(13))
        love.graphics.printf("Hold [SPACE] to Cast", screenW/2 - 90, screenH - 88, 180, "center")
    end

    -- Draw last catch popup
    if state.lastCatch then
        local hasMaterials = state.lastCatch.materials and #state.lastCatch.materials > 0
        local popupW = 320
        local popupH = hasMaterials and 140 or 120
        local popupX = screenW - popupW - 20
        local popupY = 20

        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.rectangle("fill", popupX, popupY, popupW, popupH, 10, 10)

        -- Use rarity tier color for border
        local rarityColor = getRarityColor(state.lastCatch.fish)
        love.graphics.setColor(rarityColor)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", popupX, popupY, popupW, popupH, 10, 10)
        love.graphics.setLineWidth(1)

        love.graphics.setColor(0.3, 0.9, 0.4)
        love.graphics.setFont(getFont(16))
        love.graphics.print("CAUGHT!", popupX + 15, popupY + 10)

        -- Show rarity tier
        if state.lastCatch.fish.tier and RARITY_TIERS[state.lastCatch.fish.tier] then
            local tierName = RARITY_TIERS[state.lastCatch.fish.tier].name
            love.graphics.setColor(rarityColor)
            love.graphics.setFont(getFont(11))
            love.graphics.print("[" .. tierName .. "]", popupX + 100, popupY + 12)
        end

        -- Show fish name (with trophy prefix if applicable)
        love.graphics.setColor(rarityColor)
        love.graphics.setFont(getFont(18))
        local displayName = state.lastCatch.displayName or state.lastCatch.fish.name
        if state.lastCatch.isTrophy then
            love.graphics.setColor(1, 0.85, 0.3)
            love.graphics.print("★ " .. displayName, popupX + 15, popupY + 35)
        else
            love.graphics.print(displayName, popupX + 15, popupY + 35)
        end

        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.setFont(getFont(12))
        love.graphics.print("Weight: " .. state.lastCatch.weight .. " kg", popupX + 15, popupY + 60)

        love.graphics.setColor(1, 0.9, 0.3)
        love.graphics.print("+" .. state.lastCatch.value .. " coins", popupX + 15, popupY + 80)

        -- Show materials dropped
        if hasMaterials then
            love.graphics.setColor(0.6, 0.9, 0.6)
            love.graphics.setFont(getFont(10))
            love.graphics.print("Materials:", popupX + 15, popupY + 100)
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.setFont(getFont(9))
            local materialText = table.concat(state.lastCatch.materials, ", ")
            -- Wrap text if too long
            if #materialText > 40 then
                materialText = string.sub(materialText, 1, 37) .. "..."
            end
            love.graphics.print(materialText, popupX + 15, popupY + 115)
        end
    end

    -- Draw bottom button row using UI components
    for i, btn in ipairs(state.ui.bottomButtons) do
        -- Update button text for special cases
        if i == 4 then
            -- Bait button - show current bait
            local bait = Fishing.getCurrentBait()
            btn.text = "[Q] " .. bait.name
        elseif i == 5 then
            -- Reel button - show state
            local reelActive = state.reelButtonHeld or state.spaceHeld
            local reelCanUse = state.lineDepth > 0 and not state.casting
            btn.text = reelActive and "REELING..." or "[R] Reel"
            btn.disabled = not reelCanUse
        end
        btn:draw()
    end

    -- Draw bait count overlay on bait button
    local bait = Fishing.getCurrentBait()
    love.graphics.setColor(0.8, 0.8, 0.6)
    love.graphics.setFont(getFont(9))
    love.graphics.printf("x" .. state.baitCount, 305, screenH - 45 + 22, 90, "center")
    love.graphics.setColor(1, 1, 1)

    -- Instructions
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.setFont(getFont(11))
    love.graphics.print("[SPACE] Cast/Reel  [Q] Change Bait  [B] Backpack  [ESC] Exit", screenW/2 - 175, screenH - 25)

    -- Draw notification
    if state.notification then
        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.rectangle("fill", screenW/2 - 160, screenH/2 - 25, 320, 50, 10, 10)
        love.graphics.setColor(1, 1, 0.7)
        love.graphics.setFont(getFont(14))
        love.graphics.printf(state.notification, screenW/2 - 150, screenH/2 - 10, 300, "center")
    end

    -- Draw shop overlay using UI components
    if state.showShop then
        drawShopOverlay(screenW, screenH, mx, my)
    end

    -- Draw collection overlay using UI components
    if state.showCollection then
        drawCollectionOverlay(screenW, screenH, mx, my)
    end

    -- Draw employees overlay using UI components
    if state.showEmployees then
        drawEmployeesOverlay(screenW, screenH, mx, my)
    end

    -- Draw tutorial (on top of everything)
    Tutorials.draw()

    -- End screen shake transform
    love.graphics.pop()

    -- Draw perfect popups (outside shake so they're stable)
    for _, p in ipairs(state.perfectPopups) do
        local alpha = math.min(1, p.life / 0.3)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.setFont(getFont(math.floor(18 * p.scale)))
        local textW = getFont(math.floor(18 * p.scale)):getWidth(p.text)
        love.graphics.print(p.text, p.x - textW/2, p.y)
    end

    -- Draw catch celebration overlay for rare fish
    if state.catchCelebration and state.celebrationTimer > 0 then
        local cel = state.catchCelebration
        local alpha = math.min(1, state.celebrationTimer / 0.5)

        -- Dramatic darkened overlay
        love.graphics.setColor(0, 0, 0, 0.5 * alpha)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)

        -- Glowing fish name with rarity color
        love.graphics.setColor(cel.color[1], cel.color[2], cel.color[3], alpha)
        love.graphics.setFont(getFont(28))
        local nameW = getFont(28):getWidth(cel.fishName)
        love.graphics.print(cel.fishName, screenW/2 - nameW/2, screenH/2 - 50)

        -- Rarity label
        love.graphics.setFont(getFont(16))
        local rarityLabel = string.upper(cel.rarity) .. " CATCH!"
        local rarityW = getFont(16):getWidth(rarityLabel)
        love.graphics.print(rarityLabel, screenW/2 - rarityW/2, screenH/2 - 15)
    end

    UIAssets.drawTooltip()
end

-- Draw shop overlay using UI components
local function drawShopOverlay(screenW, screenH, mx, my)
    -- Overlay background
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Draw panel
    if state.ui.shopPanel then
        state.ui.shopPanel:draw()
    end

    -- Draw coins display
    local panelW, panelH = 600, 450
    local panelX = screenW/2 - panelW/2
    local panelY = screenH/2 - panelH/2
    love.graphics.setColor(1, 0.9, 0.3)
    love.graphics.setFont(getFont(16))
    love.graphics.print("Coins: " .. PlayerData.coins, panelX + panelW - 150, panelY + 20)

    -- Draw tab bar
    if state.ui.shopTabBar then
        state.ui.shopTabBar:draw()
    end

    -- Draw content with scissor for scrolling
    local contentY = panelY + 100
    local contentH = panelH - 120
    if state.ui.shopScroll then
        love.graphics.setScissor(panelX + 20, contentY, panelW - 40, contentH)
        local scrollY = state.ui.shopScroll:getScroll()

        if state.shopTab == "rods" then
            for i, rod in ipairs(RODS) do
                local itemY = contentY + (i - 1) * 70 - scrollY
                local owned = state.ownedRods[rod.id]
                local equipped = state.currentRod == rod.id

                love.graphics.setColor(0.15, 0.18, 0.22)
                love.graphics.rectangle("fill", panelX + 20, itemY, panelW - 40, 60, 6, 6)

                love.graphics.setColor(owned and {0.4, 0.8, 0.4} or {0.8, 0.8, 0.8})
                love.graphics.setFont(getFont(14))
                love.graphics.print(rod.name .. (equipped and " (Equipped)" or ""), panelX + 30, itemY + 8)

                love.graphics.setColor(0.6, 0.6, 0.7)
                love.graphics.setFont(getFont(11))
                love.graphics.print(rod.description, panelX + 30, itemY + 28)
                love.graphics.print("Cast: " .. rod.castPower .. "  Reel: " .. rod.reelSpeed .. "x  Max Tension: " .. rod.tensionMax, panelX + 30, itemY + 43)
            end
        elseif state.shopTab == "bait" then
            for i, bait in ipairs(BAITS) do
                local itemY = contentY + (i - 1) * 70 - scrollY
                local isEquipped = state.currentBait == bait.id

                love.graphics.setColor(0.15, 0.18, 0.22)
                love.graphics.rectangle("fill", panelX + 20, itemY, panelW - 40, 60, 6, 6)

                love.graphics.setColor(isEquipped and {0.4, 0.8, 0.4} or {0.8, 0.8, 0.8})
                love.graphics.setFont(getFont(14))
                love.graphics.print(bait.name .. (isEquipped and " (x" .. state.baitCount .. " equipped)" or ""), panelX + 30, itemY + 8)

                love.graphics.setColor(0.6, 0.6, 0.7)
                love.graphics.setFont(getFont(11))
                love.graphics.print(bait.description, panelX + 30, itemY + 28)
                love.graphics.print("Rarity Bonus: +" .. (bait.rarityBonus * 100) .. "%", panelX + 30, itemY + 43)
            end
        elseif state.shopTab == "locations" then
            for i, loc in ipairs(LOCATIONS) do
                local itemY = contentY + (i - 1) * 70 - scrollY
                local unlocked = state.unlockedLocations[loc.id]
                local isActive = state.currentLocation == loc.id

                love.graphics.setColor(0.15, 0.18, 0.22)
                love.graphics.rectangle("fill", panelX + 20, itemY, panelW - 40, 60, 6, 6)

                love.graphics.setColor(unlocked and {0.4, 0.8, 0.4} or {0.6, 0.6, 0.6})
                love.graphics.setFont(getFont(14))
                love.graphics.print(loc.name .. (isActive and " (Current)" or ""), panelX + 30, itemY + 8)

                love.graphics.setColor(0.6, 0.6, 0.7)
                love.graphics.setFont(getFont(11))
                love.graphics.print(loc.description, panelX + 30, itemY + 28)
                love.graphics.print("Fish Value Bonus: " .. math.floor((loc.fishBonus - 1) * 100) .. "%", panelX + 30, itemY + 43)
            end
        end

        love.graphics.setScissor()

        -- Draw buttons
        for _, btn in ipairs(state.ui.shopButtons) do
            btn:draw()
        end

        -- Draw scrollbar
        state.ui.shopScroll:draw()
    end

    love.graphics.setColor(1, 1, 1)
end

-- Draw collection overlay using UI components
local function drawCollectionOverlay(screenW, screenH, mx, my)
    -- Overlay background
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    local panelW, panelH = 650, 500
    local panelX = screenW/2 - panelW/2
    local panelY = screenH/2 - panelH/2

    -- Draw panel
    if state.ui.collectionPanel then
        state.ui.collectionPanel:draw()
    end

    -- Stats
    local caughtCount = 0
    for _ in pairs(state.fishCaught) do caughtCount = caughtCount + 1 end

    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.setFont(getFont(12))
    love.graphics.print("Species Discovered: " .. caughtCount .. "/" .. #FISH_TYPES, panelX + 20, panelY + 50)
    love.graphics.print("Total Fish Caught: " .. state.totalFishCaught, panelX + 250, panelY + 50)

    -- Draw fish grid with scroll
    if state.ui.collectionScroll then
        local gridX = panelX + 20
        local gridY = panelY + 80
        local cardW = 145
        local cardH = 80
        local cols = 4

        love.graphics.setScissor(gridX, gridY, panelW - 40, panelH - 100)
        local scrollY = state.ui.collectionScroll:getScroll()

        for i, fish in ipairs(FISH_TYPES) do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            local cardX = gridX + col * (cardW + 10)
            local cardY = gridY + row * (cardH + 10) - scrollY

            local caught = state.fishCaught[fish.id]
            local discovered = caught ~= nil

            if discovered then
                love.graphics.setColor(0.18, 0.22, 0.28)
            else
                love.graphics.setColor(0.1, 0.1, 0.12)
            end
            love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 6, 6)

            if discovered then
                local rarityColor = getRarityColor(fish)
                love.graphics.setColor(rarityColor)
                love.graphics.rectangle("fill", cardX, cardY, 6, cardH, 3, 0)

                love.graphics.setColor(rarityColor)
                love.graphics.setFont(getFont(12))
                love.graphics.print(fish.name, cardX + 12, cardY + 5)

                if fish.tier and RARITY_TIERS[fish.tier] then
                    local tierName = RARITY_TIERS[fish.tier].name
                    love.graphics.setColor(rarityColor[1] * 0.8, rarityColor[2] * 0.8, rarityColor[3] * 0.8)
                    love.graphics.setFont(getFont(8))
                    love.graphics.print("[" .. tierName .. "]", cardX + 12, cardY + 20)
                end

                love.graphics.setColor(0.6, 0.6, 0.7)
                love.graphics.setFont(getFont(10))
                love.graphics.print("Caught: " .. caught.count, cardX + 12, cardY + 35)
                love.graphics.print("Best: " .. caught.bestWeight .. " kg", cardX + 12, cardY + 50)
                love.graphics.print("Value: " .. fish.value .. "g", cardX + 12, cardY + 65)
            else
                love.graphics.setColor(0.3, 0.3, 0.35)
                love.graphics.setFont(getFont(14))
                love.graphics.printf("???", cardX, cardY + 30, cardW, "center")
            end
        end

        love.graphics.setScissor()
        state.ui.collectionScroll:draw()
    end

    love.graphics.setColor(1, 1, 1)
end

-- Draw employees overlay using UI components
local function drawEmployeesOverlay(screenW, screenH, mx, my)
    -- Overlay background
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    local panelW, panelH = 700, 520
    local panelX = screenW/2 - panelW/2
    local panelY = screenH/2 - panelH/2

    -- Draw panel
    if state.ui.employeesPanel then
        state.ui.employeesPanel:draw()
    end

    -- Coins display
    love.graphics.setColor(1, 0.9, 0.3)
    love.graphics.setFont(getFont(14))
    love.graphics.print("Coins: " .. (PlayerData.coins or 0), panelX + panelW - 140, panelY + 20)

    -- Left side: Employees
    local leftX = panelX + 20
    local contentY = panelY + 55

    love.graphics.setColor(0.7, 0.8, 0.5)
    love.graphics.setFont(getFont(16))
    love.graphics.print("EMPLOYEES (" .. #state.employees .. ")", leftX, contentY)

    local empY = contentY + 30
    for i, empType in ipairs(EMPLOYEE_TYPES) do
        local empItemY = empY + (i - 1) * 70
        local owned = false
        for _, emp in ipairs(state.employees) do
            if emp.type == empType.id then
                owned = true
                break
            end
        end

        love.graphics.setColor(0.15, 0.18, 0.15)
        love.graphics.rectangle("fill", leftX, empItemY, 320, 60, 6, 6)

        if owned then
            love.graphics.setColor(0.3, 0.6, 0.3)
            love.graphics.rectangle("fill", leftX, empItemY, 5, 60, 3, 0)
        end

        love.graphics.setColor(owned and {0.5, 0.9, 0.5} or {0.8, 0.8, 0.8})
        love.graphics.setFont(getFont(13))
        love.graphics.print(empType.name .. (owned and " (Hired)" or ""), leftX + 10, empItemY + 5)

        love.graphics.setColor(0.6, 0.6, 0.7)
        love.graphics.setFont(getFont(10))
        love.graphics.print(empType.desc, leftX + 10, empItemY + 24)
        love.graphics.print("Daily salary: " .. empType.baseSalary .. "g", leftX + 10, empItemY + 40)
    end

    -- Draw employee buttons
    for _, btn in ipairs(state.ui.employeesButtons) do
        btn:draw()
    end

    -- Right side: Upgrades
    local rightX = panelX + 360

    love.graphics.setColor(0.5, 0.7, 0.9)
    love.graphics.setFont(getFont(16))
    love.graphics.print("UPGRADES", rightX, contentY)

    local upgY = contentY + 30
    for i, upg in ipairs(UPGRADES) do
        local upgItemY = upgY + (i - 1) * 70
        local currentLevel = getUpgradeLevel(upg.id)
        local maxed = currentLevel >= upg.maxLevel

        love.graphics.setColor(0.15, 0.17, 0.22)
        love.graphics.rectangle("fill", rightX, upgItemY, 320, 60, 6, 6)

        -- Level indicator bar
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", rightX + 10, upgItemY + 48, 150, 8, 2, 2)
        if currentLevel > 0 then
            love.graphics.setColor(0.3, 0.6, 0.9)
            love.graphics.rectangle("fill", rightX + 10, upgItemY + 48, 150 * (currentLevel / upg.maxLevel), 8, 2, 2)
        end

        love.graphics.setColor(maxed and {0.4, 0.9, 0.4} or {0.8, 0.8, 0.8})
        love.graphics.setFont(getFont(13))
        love.graphics.print(upg.name .. " [" .. currentLevel .. "/" .. upg.maxLevel .. "]", rightX + 10, upgItemY + 5)

        love.graphics.setColor(0.6, 0.6, 0.7)
        love.graphics.setFont(getFont(10))
        love.graphics.print(upg.desc, rightX + 10, upgItemY + 24)

        if maxed then
            love.graphics.setColor(0.4, 0.7, 0.4)
            love.graphics.setFont(getFont(11))
            love.graphics.printf("MAXED", rightX + 230, upgItemY + 25, 80, "center")
        end
    end

    -- Draw upgrade buttons
    for _, btn in ipairs(state.ui.upgradesButtons) do
        btn:draw()
    end

    love.graphics.setColor(1, 1, 1)
end

-- LEGACY: Old draw functions kept for reference but not used
-- Draw shop UI
function Fishing.drawShop(screenW, screenH, mx, my)
    -- Overlay
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Panel
    local panelW, panelH = 600, 450
    local panelX = screenW/2 - panelW/2
    local panelY = screenH/2 - panelH/2

    love.graphics.setColor(0.12, 0.14, 0.18)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 12, 12)
    love.graphics.setColor(0.4, 0.5, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 12, 12)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(0.9, 0.8, 0.3)
    love.graphics.setFont(getFont(24))
    love.graphics.print("FISHING SHOP", panelX + 20, panelY + 15)

    -- Coins display
    love.graphics.setColor(1, 0.9, 0.3)
    love.graphics.setFont(getFont(16))
    love.graphics.print("Coins: " .. PlayerData.coins, panelX + panelW - 150, panelY + 20)

    -- Close button
    local closeX = panelX + panelW - 40
    local closeY = panelY + 10
    local closeHover = mx >= closeX and mx <= closeX + 30 and my >= closeY and my <= closeY + 30
    love.graphics.setColor(closeHover and {0.7, 0.3, 0.3} or {0.4, 0.25, 0.25})
    love.graphics.rectangle("fill", closeX, closeY, 30, 30, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("X", closeX, closeY + 7, 30, "center")

    -- Tabs
    local tabs = {"rods", "bait", "locations"}
    local tabNames = {rods = "Rods", bait = "Bait", locations = "Locations"}
    local tabX = panelX + 20
    local tabY = panelY + 55

    for _, tab in ipairs(tabs) do
        local isActive = state.shopTab == tab
        local tabW = 100
        local tabHover = mx >= tabX and mx <= tabX + tabW and my >= tabY and my <= tabY + 30

        if isActive then
            love.graphics.setColor(0.3, 0.4, 0.5)
        elseif tabHover then
            love.graphics.setColor(0.22, 0.28, 0.35)
        else
            love.graphics.setColor(0.15, 0.18, 0.22)
        end
        love.graphics.rectangle("fill", tabX, tabY, tabW, 30, 5, 5)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(12))
        love.graphics.printf(tabNames[tab], tabX, tabY + 8, tabW, "center")

        tabX = tabX + tabW + 10
    end

    -- Content area
    local contentY = panelY + 100
    local contentH = panelH - 120

    if state.shopTab == "rods" then
        for i, rod in ipairs(RODS) do
            local itemY = contentY + (i - 1) * 70
            local owned = state.ownedRods[rod.id]
            local equipped = state.currentRod == rod.id
            local canBuy = not owned and PlayerData.coins >= rod.cost
            local itemHover = mx >= panelX + 20 and mx <= panelX + panelW - 20 and my >= itemY and my <= itemY + 60

            love.graphics.setColor(itemHover and {0.2, 0.25, 0.3} or {0.15, 0.18, 0.22})
            love.graphics.rectangle("fill", panelX + 20, itemY, panelW - 40, 60, 6, 6)

            love.graphics.setColor(owned and {0.4, 0.8, 0.4} or {0.8, 0.8, 0.8})
            love.graphics.setFont(getFont(14))
            love.graphics.print(rod.name .. (equipped and " (Equipped)" or ""), panelX + 30, itemY + 8)

            love.graphics.setColor(0.6, 0.6, 0.7)
            love.graphics.setFont(getFont(11))
            love.graphics.print(rod.description, panelX + 30, itemY + 28)
            love.graphics.print("Cast: " .. rod.castPower .. "  Reel: " .. rod.reelSpeed .. "x  Max Tension: " .. rod.tensionMax, panelX + 30, itemY + 43)

            if owned then
                if not equipped then
                    love.graphics.setColor(0.3, 0.5, 0.3)
                    love.graphics.rectangle("fill", panelX + panelW - 100, itemY + 15, 70, 30, 5, 5)
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.printf("Equip", panelX + panelW - 100, itemY + 22, 70, "center")
                end
            else
                love.graphics.setColor(canBuy and {0.4, 0.5, 0.7} or {0.4, 0.3, 0.3})
                love.graphics.rectangle("fill", panelX + panelW - 100, itemY + 15, 70, 30, 5, 5)
                love.graphics.setColor(1, 1, 1)
                love.graphics.printf(rod.cost .. "g", panelX + panelW - 100, itemY + 22, 70, "center")
            end
        end
    elseif state.shopTab == "bait" then
        for i, bait in ipairs(BAITS) do
            local itemY = contentY + (i - 1) * 70
            local isEquipped = state.currentBait == bait.id
            local itemHover = mx >= panelX + 20 and mx <= panelX + panelW - 20 and my >= itemY and my <= itemY + 60
            local canBuy = PlayerData.coins >= bait.cost * 5

            love.graphics.setColor(itemHover and {0.2, 0.25, 0.3} or {0.15, 0.18, 0.22})
            love.graphics.rectangle("fill", panelX + 20, itemY, panelW - 40, 60, 6, 6)

            love.graphics.setColor(isEquipped and {0.4, 0.8, 0.4} or {0.8, 0.8, 0.8})
            love.graphics.setFont(getFont(14))
            love.graphics.print(bait.name .. (isEquipped and " (x" .. state.baitCount .. " equipped)" or ""), panelX + 30, itemY + 8)

            love.graphics.setColor(0.6, 0.6, 0.7)
            love.graphics.setFont(getFont(11))
            love.graphics.print(bait.description, panelX + 30, itemY + 28)
            love.graphics.print("Rarity Bonus: +" .. (bait.rarityBonus * 100) .. "%", panelX + 30, itemY + 43)

            love.graphics.setColor(canBuy and {0.4, 0.5, 0.7} or {0.4, 0.3, 0.3})
            love.graphics.rectangle("fill", panelX + panelW - 100, itemY + 15, 70, 30, 5, 5)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf("5 for " .. (bait.cost * 5) .. "g", panelX + panelW - 100, itemY + 18, 70, "center")
        end
    elseif state.shopTab == "locations" then
        for i, loc in ipairs(LOCATIONS) do
            local itemY = contentY + (i - 1) * 70
            local unlocked = state.unlockedLocations[loc.id]
            local isActive = state.currentLocation == loc.id
            local canBuy = not unlocked and PlayerData.coins >= loc.unlockCost
            local itemHover = mx >= panelX + 20 and mx <= panelX + panelW - 20 and my >= itemY and my <= itemY + 60

            love.graphics.setColor(itemHover and {0.2, 0.25, 0.3} or {0.15, 0.18, 0.22})
            love.graphics.rectangle("fill", panelX + 20, itemY, panelW - 40, 60, 6, 6)

            love.graphics.setColor(unlocked and {0.4, 0.8, 0.4} or {0.6, 0.6, 0.6})
            love.graphics.setFont(getFont(14))
            love.graphics.print(loc.name .. (isActive and " (Current)" or ""), panelX + 30, itemY + 8)

            love.graphics.setColor(0.6, 0.6, 0.7)
            love.graphics.setFont(getFont(11))
            love.graphics.print(loc.description, panelX + 30, itemY + 28)
            love.graphics.print("Fish Value Bonus: " .. math.floor((loc.fishBonus - 1) * 100) .. "%", panelX + 30, itemY + 43)

            if unlocked then
                if not isActive then
                    love.graphics.setColor(0.3, 0.5, 0.3)
                    love.graphics.rectangle("fill", panelX + panelW - 100, itemY + 15, 70, 30, 5, 5)
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.printf("Travel", panelX + panelW - 100, itemY + 22, 70, "center")
                end
            else
                love.graphics.setColor(canBuy and {0.4, 0.5, 0.7} or {0.4, 0.3, 0.3})
                love.graphics.rectangle("fill", panelX + panelW - 100, itemY + 15, 70, 30, 5, 5)
                love.graphics.setColor(1, 1, 1)
                love.graphics.printf(loc.unlockCost .. "g", panelX + panelW - 100, itemY + 22, 70, "center")
            end
        end
    end
end

-- Draw collection/journal UI
function Fishing.drawCollection(screenW, screenH, mx, my)
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    local panelW, panelH = 650, 500
    local panelX = screenW/2 - panelW/2
    local panelY = screenH/2 - panelH/2

    love.graphics.setColor(0.12, 0.14, 0.18)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 12, 12)
    love.graphics.setColor(0.4, 0.6, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 12, 12)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(0.4, 0.8, 0.9)
    love.graphics.setFont(getFont(24))
    love.graphics.print("FISH JOURNAL", panelX + 20, panelY + 15)

    -- Stats
    local caughtCount = 0
    for _ in pairs(state.fishCaught) do caughtCount = caughtCount + 1 end

    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.setFont(getFont(12))
    love.graphics.print("Species Discovered: " .. caughtCount .. "/" .. #FISH_TYPES, panelX + 20, panelY + 50)
    love.graphics.print("Total Fish Caught: " .. state.totalFishCaught, panelX + 250, panelY + 50)

    -- Close button
    local closeX = panelX + panelW - 40
    local closeY = panelY + 10
    local closeHover = mx >= closeX and mx <= closeX + 30 and my >= closeY and my <= closeY + 30
    love.graphics.setColor(closeHover and {0.7, 0.3, 0.3} or {0.4, 0.25, 0.25})
    love.graphics.rectangle("fill", closeX, closeY, 30, 30, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("X", closeX, closeY + 7, 30, "center")

    -- Fish grid
    local gridX = panelX + 20
    local gridY = panelY + 80
    local cardW = 145
    local cardH = 80
    local cols = 4

    for i, fish in ipairs(FISH_TYPES) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local cardX = gridX + col * (cardW + 10)
        local cardY = gridY + row * (cardH + 10)

        local caught = state.fishCaught[fish.id]
        local discovered = caught ~= nil

        if discovered then
            love.graphics.setColor(0.18, 0.22, 0.28)
        else
            love.graphics.setColor(0.1, 0.1, 0.12)
        end
        love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 6, 6)

        if discovered then
            -- Color bar for rarity tier
            local rarityColor = getRarityColor(fish)
            love.graphics.setColor(rarityColor)
            love.graphics.rectangle("fill", cardX, cardY, 6, cardH, 3, 0)

            love.graphics.setColor(rarityColor)
            love.graphics.setFont(getFont(12))
            love.graphics.print(fish.name, cardX + 12, cardY + 5)

            -- Show rarity tier
            if fish.tier and RARITY_TIERS[fish.tier] then
                local tierName = RARITY_TIERS[fish.tier].name
                love.graphics.setColor(rarityColor[1] * 0.8, rarityColor[2] * 0.8, rarityColor[3] * 0.8)
                love.graphics.setFont(getFont(8))
                love.graphics.print("[" .. tierName .. "]", cardX + 12, cardY + 20)
            end

            love.graphics.setColor(0.6, 0.6, 0.7)
            love.graphics.setFont(getFont(10))
            love.graphics.print("Caught: " .. caught.count, cardX + 12, cardY + 35)
            love.graphics.print("Best: " .. caught.bestWeight .. " kg", cardX + 12, cardY + 50)
            love.graphics.print("Value: " .. fish.value .. "g", cardX + 12, cardY + 65)
        else
            love.graphics.setColor(0.3, 0.3, 0.35)
            love.graphics.setFont(getFont(14))
            love.graphics.printf("???", cardX, cardY + 30, cardW, "center")
        end
    end
end

-- Draw employees and upgrades UI
function Fishing.drawEmployees(screenW, screenH, mx, my)
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    local panelW, panelH = 700, 520
    local panelX = screenW/2 - panelW/2
    local panelY = screenH/2 - panelH/2

    love.graphics.setColor(0.12, 0.14, 0.18)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 12, 12)
    love.graphics.setColor(0.5, 0.5, 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 12, 12)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(0.9, 0.8, 0.4)
    love.graphics.setFont(getFont(22))
    love.graphics.print("DOCK STAFF & UPGRADES", panelX + 20, panelY + 15)

    -- Coins display
    love.graphics.setColor(1, 0.9, 0.3)
    love.graphics.setFont(getFont(14))
    love.graphics.print("Coins: " .. (PlayerData.coins or 0), panelX + panelW - 140, panelY + 20)

    -- Close button
    local closeX = panelX + panelW - 40
    local closeY = panelY + 10
    local closeHover = mx >= closeX and mx <= closeX + 30 and my >= closeY and my <= closeY + 30
    love.graphics.setColor(closeHover and {0.7, 0.3, 0.3} or {0.4, 0.25, 0.25})
    love.graphics.rectangle("fill", closeX, closeY, 30, 30, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("X", closeX, closeY + 7, 30, "center")

    -- Left side: Employees
    local leftX = panelX + 20
    local contentY = panelY + 55

    love.graphics.setColor(0.7, 0.8, 0.5)
    love.graphics.setFont(getFont(16))
    love.graphics.print("EMPLOYEES (" .. #state.employees .. ")", leftX, contentY)

    local empY = contentY + 30
    for i, empType in ipairs(EMPLOYEE_TYPES) do
        local empItemY = empY + (i - 1) * 70
        local owned = false
        for _, emp in ipairs(state.employees) do
            if emp.type == empType.id then
                owned = true
                break
            end
        end

        local canBuy = not owned and (PlayerData.coins or 0) >= empType.hireCost
        local itemHover = mx >= leftX and mx <= leftX + 320 and my >= empItemY and my <= empItemY + 60

        love.graphics.setColor(itemHover and {0.2, 0.25, 0.2} or {0.15, 0.18, 0.15})
        love.graphics.rectangle("fill", leftX, empItemY, 320, 60, 6, 6)

        if owned then
            love.graphics.setColor(0.3, 0.6, 0.3)
            love.graphics.rectangle("fill", leftX, empItemY, 5, 60, 3, 0)
        end

        love.graphics.setColor(owned and {0.5, 0.9, 0.5} or {0.8, 0.8, 0.8})
        love.graphics.setFont(getFont(13))
        love.graphics.print(empType.name .. (owned and " (Hired)" or ""), leftX + 10, empItemY + 5)

        love.graphics.setColor(0.6, 0.6, 0.7)
        love.graphics.setFont(getFont(10))
        love.graphics.print(empType.desc, leftX + 10, empItemY + 24)
        love.graphics.print("Daily salary: " .. empType.baseSalary .. "g", leftX + 10, empItemY + 40)

        if not owned then
            love.graphics.setColor(canBuy and {0.4, 0.5, 0.3} or {0.4, 0.3, 0.3})
            love.graphics.rectangle("fill", leftX + 230, empItemY + 15, 80, 30, 5, 5)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(getFont(11))
            love.graphics.printf("Hire " .. empType.hireCost .. "g", leftX + 230, empItemY + 22, 80, "center")
        end
    end

    -- Right side: Upgrades
    local rightX = panelX + 360

    love.graphics.setColor(0.5, 0.7, 0.9)
    love.graphics.setFont(getFont(16))
    love.graphics.print("UPGRADES", rightX, contentY)

    local upgY = contentY + 30
    for i, upg in ipairs(UPGRADES) do
        local upgItemY = upgY + (i - 1) * 70
        local currentLevel = getUpgradeLevel(upg.id)
        local maxed = currentLevel >= upg.maxLevel
        local cost = upg.cost * (currentLevel + 1)
        local canBuy = not maxed and (PlayerData.coins or 0) >= cost
        local itemHover = mx >= rightX and mx <= rightX + 320 and my >= upgItemY and my <= upgItemY + 60

        love.graphics.setColor(itemHover and {0.2, 0.22, 0.28} or {0.15, 0.17, 0.22})
        love.graphics.rectangle("fill", rightX, upgItemY, 320, 60, 6, 6)

        -- Level indicator bar
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", rightX + 10, upgItemY + 48, 150, 8, 2, 2)
        if currentLevel > 0 then
            love.graphics.setColor(0.3, 0.6, 0.9)
            love.graphics.rectangle("fill", rightX + 10, upgItemY + 48, 150 * (currentLevel / upg.maxLevel), 8, 2, 2)
        end

        love.graphics.setColor(maxed and {0.4, 0.9, 0.4} or {0.8, 0.8, 0.8})
        love.graphics.setFont(getFont(13))
        love.graphics.print(upg.name .. " [" .. currentLevel .. "/" .. upg.maxLevel .. "]", rightX + 10, upgItemY + 5)

        love.graphics.setColor(0.6, 0.6, 0.7)
        love.graphics.setFont(getFont(10))
        love.graphics.print(upg.desc, rightX + 10, upgItemY + 24)

        if not maxed then
            love.graphics.setColor(canBuy and {0.3, 0.4, 0.6} or {0.4, 0.3, 0.3})
            love.graphics.rectangle("fill", rightX + 230, upgItemY + 15, 80, 30, 5, 5)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(getFont(11))
            love.graphics.printf(cost .. "g", rightX + 230, upgItemY + 22, 80, "center")
        else
            love.graphics.setColor(0.4, 0.7, 0.4)
            love.graphics.setFont(getFont(11))
            love.graphics.printf("MAXED", rightX + 230, upgItemY + 25, 80, "center")
        end
    end
end

-- Handle mouse press
function Fishing.mousepressed(x, y, button)
    if button ~= 1 then return end

    -- Handle tutorial clicks first
    if Tutorials.isActive() then
        Tutorials.mousepressed(x, y, button)
        return
    end

    -- Handle UI overlay clicks
    if state.showShop and state.ui.shopPanel then
        if state.ui.shopPanel:mousepressed(x, y, button) then return end
        if state.ui.shopTabBar and state.ui.shopTabBar:mousepressed(x, y, button) then return end
        if state.ui.shopScroll and state.ui.shopScroll:mousepressed(x, y, button) then return end
        for _, btn in ipairs(state.ui.shopButtons) do
            if btn:mousepressed(x, y, button) then return end
        end
        return
    end

    if state.showCollection and state.ui.collectionPanel then
        if state.ui.collectionPanel:mousepressed(x, y, button) then return end
        if state.ui.collectionScroll and state.ui.collectionScroll:mousepressed(x, y, button) then return end
        return
    end

    if state.showEmployees and state.ui.employeesPanel then
        if state.ui.employeesPanel:mousepressed(x, y, button) then return end
        for _, btn in ipairs(state.ui.employeesButtons) do
            if btn:mousepressed(x, y, button) then return end
        end
        for _, btn in ipairs(state.ui.upgradesButtons) do
            if btn:mousepressed(x, y, button) then return end
        end
        return
    end

    -- Handle bottom button clicks
    for _, btn in ipairs(state.ui.bottomButtons) do
        if btn:mousepressed(x, y, button) then return end
    end
end

-- Handle mouse release
function Fishing.mousereleased(x, y, button)
    if button == 1 then
        state.reelButtonHeld = false

        -- Release UI components
        for _, btn in ipairs(state.ui.bottomButtons) do
            if btn.mousereleased then btn:mousereleased(x, y, button) end
        end

        if state.showShop then
            if state.ui.shopPanel and state.ui.shopPanel.mousereleased then
                state.ui.shopPanel:mousereleased(x, y, button)
            end
            if state.ui.shopScroll and state.ui.shopScroll.mousereleased then
                state.ui.shopScroll:mousereleased(x, y, button)
            end
            for _, btn in ipairs(state.ui.shopButtons) do
                if btn.mousereleased then btn:mousereleased(x, y, button) end
            end
        end

        if state.showCollection then
            if state.ui.collectionPanel and state.ui.collectionPanel.mousereleased then
                state.ui.collectionPanel:mousereleased(x, y, button)
            end
            if state.ui.collectionScroll and state.ui.collectionScroll.mousereleased then
                state.ui.collectionScroll:mousereleased(x, y, button)
            end
        end

        if state.showEmployees then
            if state.ui.employeesPanel and state.ui.employeesPanel.mousereleased then
                state.ui.employeesPanel:mousereleased(x, y, button)
            end
            for _, btn in ipairs(state.ui.employeesButtons) do
                if btn.mousereleased then btn:mousereleased(x, y, button) end
            end
            for _, btn in ipairs(state.ui.upgradesButtons) do
                if btn.mousereleased then btn:mousereleased(x, y, button) end
            end
        end
    end
end

-- Handle mouse moved (for scroll container dragging)
function Fishing.mousemoved(x, y, dx, dy)
    if state.showShop and state.ui.shopScroll and state.ui.shopScroll.mousemoved then
        state.ui.shopScroll:mousemoved(x, y, dx, dy)
    end
    if state.showCollection and state.ui.collectionScroll and state.ui.collectionScroll.mousemoved then
        state.ui.collectionScroll:mousemoved(x, y, dx, dy)
    end
end

-- Handle mouse wheel (for scrolling)
function Fishing.wheelmoved(x, y)
    if state.showShop and state.ui.shopScroll and state.ui.shopScroll.wheelmoved then
        state.ui.shopScroll:wheelmoved(x, y)
    end
    if state.showCollection and state.ui.collectionScroll and state.ui.collectionScroll.wheelmoved then
        state.ui.collectionScroll:wheelmoved(x, y)
    end
end

-- Handle key press
function Fishing.keypressed(key)
    -- Handle tutorial keys first
    if Tutorials.isActive() then
        Tutorials.keypressed(key)
        return
    end

    if state.showShop or state.showCollection or state.showEmployees then
        if key == "escape" or key == "tab" or key == "c" or key == "e" then
            state.showShop = false
            state.showCollection = false
            state.showEmployees = false
        end
        return
    end

    -- Arrow keys for direction matching
    if key == "left" then
        state.leftHeld = true
        state.playerDirection = -1
        return
    elseif key == "right" then
        state.rightHeld = true
        state.playerDirection = 1
        return
    end

    if key == "space" then
        state.spaceHeld = true

        -- Perfect reel detection
        if state.fishOnLine and state.perfectReelWindow then
            state.lastReelPerfect = true
            state.comboCounter = state.comboCounter + 1
            state.perfectReelWindow = false
            state.perfectReelTimer = 0
            state.tension = math.max(0, state.tension - 15)
            state.fishStamina = math.max(0, state.fishStamina - 18)
            addNotification("✨ PERFECT! Combo x" .. state.comboCounter, 1)
            -- Juice effects for perfect reels!
            spawnPerfectPopup("PERFECT!", {0.3, 1, 0.3})
            triggerScreenShake(3 + state.comboCounter, 0.15)  -- Bigger shake for higher combos
        else
            state.lastReelPerfect = false
        end

        if state.lineDepth == 0 and not state.casting and state.baitCount > 0 then
            -- Start casting
            state.casting = true
            state.castPower = 0
        end
        -- Reeling is now handled continuously in update() while spaceHeld is true
    elseif key == "tab" then
        state.showShop = not state.showShop
        state.showCollection = false
        state.showEmployees = false
        if state.showShop then
            createShopUI()
        end
    elseif key == "c" then
        state.showCollection = not state.showCollection
        state.showShop = false
        state.showEmployees = false
        if state.showCollection then
            createCollectionUI()
        end
    elseif key == "e" then
        state.showEmployees = not state.showEmployees
        state.showShop = false
        state.showCollection = false
        if state.showEmployees then
            createEmployeesUI()
        end
    elseif key == "b" then
        Backpack.toggle()
    elseif key == "q" then
        -- Cycle through available baits
        Fishing.cycleBait()
    elseif key == "r" then
        -- R key for reeling (same as holding the reel button)
        if state.lineDepth > 0 and not state.casting then
            state.reelButtonHeld = true
        end
    elseif key == "escape" then
        state.active = false
        return "menu"
    elseif key == "t" then
        -- Restart tutorial
        Tutorials.resetTutorial("fishing")
        Tutorials.startTutorial("fishing")
    end
end

-- Handle key release
function Fishing.keyreleased(key)
    if Tutorials.isActive() then return end

    if key == "space" then
        state.spaceHeld = false

        if state.casting then
            -- Release cast
            state.casting = false
            local rod = Fishing.getCurrentRod()
            state.lineDepth = state.castPower * rod.castPower / 100

            -- Visual feedback
            if state.lineDepth > 0 then
                local screenW = love.graphics.getWidth()
                addSplash(screenW / 2, love.graphics.getHeight() * 0.5)
                addRipple(screenW / 2, love.graphics.getHeight() * 0.5)
            end
        end
        state.reeling = false
    elseif key == "r" then
        state.reelButtonHeld = false
    elseif key == "left" or key == "right" then
        state.playerDirection = 0
        state.leftHeld = false
        state.rightHeld = false
    end
end

function Fishing.isActive()
    return state.active
end

function Fishing.exit()
    state.active = false
    saveFishingData()
end

-- Return UI region for interactive tutorial spotlight targeting
function Fishing.getUIRegion(regionId)
    local screenW, screenH = love.graphics.getDimensions()
    local regions = {
        -- Cast power meter (bottom center, shown while casting)
        cast_meter = {x = screenW/2 - 120, y = screenH - 100, w = 240, h = 50},
        -- Stats panel (top-left)
        stats_panel = {x = 10, y = 10, w = 220, h = 140},
        -- Depth display (inside stats panel)
        depth_display = {x = 10, y = 80, w = 220, h = 40},
        -- Tension meter (top center, shown when fish is on line)
        tension_meter = {x = screenW/2 - 130, y = 20, w = 260, h = 90},
        -- Direction indicator (mid-screen, shown when fish changes direction)
        direction_indicator = {x = screenW/2 - 150, y = screenH * 0.28, w = 300, h = 50},
        -- Fish stamina bar (below tension area)
        stamina_bar = {x = screenW/2 - 130, y = 155, w = 260, h = 35},
        -- Perfect reel window indicator
        perfect_window = {x = screenW/2 - 110, y = screenH * 0.68, w = 220, h = 45},
        -- Combo counter display
        combo_display = {x = screenW/2 - 100, y = 45, w = 200, h = 40},
        -- Shop button (bottom-left button row)
        shop_button = {x = 20, y = screenH - 45, w = 90, h = 35},
        -- Collection/Journal button
        collection_button = {x = 115, y = screenH - 45, w = 90, h = 35},
        -- Employees/Staff button
        employees_button = {x = 210, y = screenH - 45, w = 90, h = 35},
        -- Bait selection button
        bait_button = {x = 305, y = screenH - 45, w = 90, h = 35},
        -- Reel button
        reel_button = {x = 400, y = screenH - 45, w = 100, h = 35},
        -- Bottom button row (all action buttons)
        button_row = {x = 20, y = screenH - 45, w = 480, h = 35},
        -- Last catch popup (top-right)
        last_catch = {x = screenW - 340, y = 20, w = 320, h = 140},
        -- Ready to cast prompt
        cast_prompt = {x = screenW/2 - 100, y = screenH - 100, w = 200, h = 40},
        -- Waiting for bite indicator (top center)
        waiting_indicator = {x = screenW/2 - 110, y = 20, w = 220, h = 60},
    }
    return regions[regionId]
end

-- Handle window resize (update button positions)
function Fishing.resize(w, h)
    if state.active and #state.ui.bottomButtons > 0 then
        initializeBottomButtons()
    end
end

return Fishing
