-- Property Ownership & Settlement System
-- Handles town property ownership, wild land claims, and settlements
-- Orchestrator: delegates farming, resources, and settlement expansion to sub-modules

local PropertySystem = {}

local Backpack = require("backpack")
local FarmingSystem = require("farming_system")
local ResourceProcessing = require("resource_processing")
local SettlementExpansion = require("settlement_expansion")

-- Forward declarations
local state  -- Will be set via init

-- Sync text RPG gold with main game currency (PlayerData.coins)
-- Must be called after every modification to state.player.gold
local function syncGoldToPlayerData()
    if state and state.player and PlayerData then
        PlayerData.coins = state.player.gold
    end
end

-- Reverse sync: pull latest PlayerData.coins into state.player.gold
-- Called at entry points so property system sees up-to-date balance
local function syncGoldFromPlayerData()
    if state and state.player and PlayerData then
        state.player.gold = PlayerData.coins
    end
end

-- ============================================================================
--                         PROPERTY DEFINITIONS
-- ============================================================================

-- Town business properties (require ownership to hire employees)
PropertySystem.BUSINESS_PROPERTIES = {
    forge = {
        id = "forge",
        name = "Forge",
        basePrice = 5000,
        dailyTax = 50,
        requiresLevel = 5,
        requiresReputation = 0,
        employeeMode = "forge",
        description = "A blacksmith's forge for crafting weapons and armor.",
        maxEmployees = 3,
    },
    wizardtower = {
        id = "wizardtower",
        name = "Wizard Tower",
        basePrice = 8000,
        dailyTax = 80,
        requiresLevel = 8,
        requiresReputation = 0,
        employeeMode = "wizardtower",
        description = "A tower for magical research and spell crafting.",
        maxEmployees = 3,
    },
    alchemist = {
        id = "alchemist",
        name = "Alchemist Shop",
        basePrice = 6000,
        dailyTax = 60,
        requiresLevel = 5,
        requiresReputation = 0,
        employeeMode = "alchemist",
        description = "An alchemy lab for brewing potions and elixirs.",
        maxEmployees = 3,
    },
    fishing = {
        id = "fishing",
        name = "Fishing Dock",
        basePrice = 3000,
        dailyTax = 30,
        requiresLevel = 3,
        requiresReputation = 0,
        employeeMode = "fishing",
        description = "A dock with boats and fishing equipment.",
        maxEmployees = 3,
    },
    hunting = {
        id = "hunting",
        name = "Hunter's Lodge",
        basePrice = 4000,
        dailyTax = 40,
        requiresLevel = 5,
        requiresReputation = 0,
        employeeMode = "hunting",
        description = "A lodge for hunters with tracking equipment.",
        maxEmployees = 3,
    },
    market = {
        id = "market",
        name = "Trading Post",
        basePrice = 8000,
        dailyTax = 100,
        requiresLevel = 8,
        requiresReputation = 25,
        employeeMode = "stock_market",
        description = "A marketplace for trading stocks and physical goods.",
        maxEmployees = 4,
    },
}

-- Town home properties (for storage and rest)
PropertySystem.HOME_PROPERTIES = {
    shack = {
        id = "shack",
        name = "Shack",
        basePrice = 500,
        dailyTax = 5,
        storageSlots = 10,
        description = "A tiny run-down shack. Not much, but it's home.",
    },
    cottage = {
        id = "cottage",
        name = "Cottage",
        basePrice = 1000,
        dailyTax = 10,
        storageSlots = 20,
        description = "A small but comfortable cottage.",
    },
    house = {
        id = "house",
        name = "House",
        basePrice = 2500,
        dailyTax = 25,
        storageSlots = 40,
        description = "A proper house with room for a family.",
    },
    farmhouse = {
        id = "farmhouse",
        name = "Farmhouse",
        basePrice = 3500,
        dailyTax = 35,
        storageSlots = 60,
        hasGarden = true,
        description = "A farmhouse with land for growing crops.",
    },
    warehouse = {
        id = "warehouse",
        name = "Warehouse",
        basePrice = 5000,
        dailyTax = 50,
        storageSlots = 200,
        description = "A large warehouse for storing goods.",
    },
    manor = {
        id = "manor",
        name = "Manor House",
        basePrice = 30000,
        dailyTax = 300,
        storageSlots = 80,
        requiresReputation = 75,
        description = "An elegant manor house befitting nobility.",
    },
    noble_estate = {
        id = "noble_estate",
        name = "Noble Estate",
        basePrice = 50000,
        dailyTax = 500,
        storageSlots = 100,
        requiresReputation = 100,
        description = "A grand estate with servants' quarters.",
    },
}

-- Wild land structures (built on claimed land)
PropertySystem.WILD_STRUCTURES = {
    tent = {
        id = "tent",
        name = "Tent",
        cost = {gold = 50},
        materials = {{"leather_scraps", 5}, {"wood_planks", 2}},
        buildTime = 0,  -- Instant (in game hours)
        maxResidents = 1,
        defenseRating = 0,
        upgradesTo = "cabin",
        description = "A simple tent. Provides shelter but no protection.",
    },
    cabin = {
        id = "cabin",
        name = "Cabin",
        cost = {gold = 500},
        materials = {{"wood_planks", 30}, {"iron_ore", 5}},
        buildTime = 24,  -- 1 day
        maxResidents = 2,
        defenseRating = 5,
        upgradesTo = "wild_house",
        description = "A small wooden cabin. Basic but sturdy.",
    },
    wild_house = {
        id = "wild_house",
        name = "House",
        cost = {gold = 2000},
        materials = {{"wood_planks", 50}, {"iron_ore", 15}, {"stone", 30}},
        buildTime = 72,  -- 3 days
        maxResidents = 4,
        defenseRating = 15,
        upgradesTo = "wild_manor",
        description = "A proper house with strong walls.",
    },
    wild_manor = {
        id = "wild_manor",
        name = "Manor",
        cost = {gold = 10000},
        materials = {{"wood_planks", 100}, {"steel_ingot", 20}, {"stone", 100}},
        buildTime = 168,  -- 7 days
        maxResidents = 8,
        defenseRating = 30,
        upgradesTo = nil,
        description = "A grand manor house with multiple rooms.",
    },
}

-- Defensive wall structures
PropertySystem.WALL_STRUCTURES = {
    wooden_fence = {
        id = "wooden_fence",
        name = "Wooden Fence",
        cost = {gold = 200},
        materials = {{"wood_planks", 20}},
        buildTime = 12,  -- Half day
        wallLevel = 1,
        defenseBonus = 10,
        requires = nil,
        description = "A basic wooden fence. Deters casual raiders.",
    },
    stone_wall = {
        id = "stone_wall",
        name = "Stone Wall",
        cost = {gold = 1000},
        materials = {{"stone", 50}, {"iron_ore", 10}},
        buildTime = 48,  -- 2 days
        wallLevel = 2,
        defenseBonus = 30,
        requires = "wooden_fence",
        description = "Strong stone walls. Keeps most threats out.",
    },
    fortified_wall = {
        id = "fortified_wall",
        name = "Fortified Wall",
        cost = {gold = 5000},
        materials = {{"stone", 100}, {"steel_ingot", 30}},
        buildTime = 96,  -- 4 days
        wallLevel = 3,
        defenseBonus = 60,
        requires = "stone_wall",
        description = "Heavily fortified walls with guard towers.",
    },
}

-- Property improvements (additional upgrades for land claims)
PropertySystem.IMPROVEMENTS = {
    well = {
        id = "well",
        name = "Well",
        cost = {gold = 300},
        materials = {{"stone", 20}},
        buildTime = 12,  -- Half day
        effects = {healthBonus = 5, description = "+5 max residents HP"},
        requires = "cabin",  -- Minimum structure requirement
        description = "Fresh water supply. Improves health of all residents.",
    },
    storage_cellar = {
        id = "storage_cellar",
        name = "Storage Cellar",
        cost = {gold = 500},
        materials = {{"stone", 30}, {"wood_planks", 15}},
        buildTime = 24,
        effects = {storageBonus = 20, description = "+20 storage slots"},
        requires = "cabin",
        description = "Underground storage. Increases capacity.",
    },
    watchtower = {
        id = "watchtower",
        name = "Watchtower",
        cost = {gold = 800},
        materials = {{"wood_planks", 40}, {"stone", 20}},
        buildTime = 36,
        effects = {defenseBonus = 15, earlyWarning = true, description = "+15 defense, early warning"},
        requires = "cabin",
        description = "Early warning of attacks. Bonus defense.",
    },
    trade_post = {
        id = "trade_post",
        name = "Trade Post",
        cost = {gold = 1500},
        materials = {{"wood_planks", 50}, {"iron_ore", 20}},
        buildTime = 48,
        effects = {incomeBonus = 25, description = "+25g daily income"},
        requires = "wild_house",
        description = "Establishes a trade route. Generates passive income.",
    },
    shrine = {
        id = "shrine",
        name = "Shrine",
        cost = {gold = 1000},
        materials = {{"stone", 40}},
        buildTime = 24,
        effects = {blessingBonus = true, description = "Daily blessing effect"},
        requires = "cabin",
        description = "A holy shrine. Provides daily blessings to residents.",
    },
    blacksmith = {
        id = "blacksmith",
        name = "Blacksmith",
        cost = {gold = 2000},
        materials = {{"stone", 50}, {"iron_ore", 30}},
        buildTime = 72,
        effects = {repairDiscount = 0.5, weaponBonus = 5, description = "50% repair cost, +5 weapon damage"},
        requires = "wild_house",
        description = "Repairs equipment and improves weapons.",
    },
    farm = {
        id = "farm",
        name = "Farm",
        cost = {gold = 800},
        materials = {{"wood_planks", 30}},
        buildTime = 24,
        effects = {
            interactive = true,
            farmSize = 3,  -- 3x3 grid
            description = "Interactive farming: plant, water, and harvest crops"
        },
        requires = "cabin",
        description = "Plant and harvest crops for food and materials.",
    },
    expanded_farm = {
        id = "expanded_farm",
        name = "Expanded Farm",
        cost = {gold = 2000},
        materials = {{"wood_planks", 50}, {"stone", 30}},
        buildTime = 48,
        effects = {
            farmExpansion = "5x5",
            description = "Expands farm to 5x5 (25 plots)"
        },
        requires = "wild_house",
        description = "Doubles your farming space to 5x5 grid.",
    },
    large_farm = {
        id = "large_farm",
        name = "Large Farm",
        cost = {gold = 5000},
        materials = {{"wood_planks", 100}, {"stone", 60}, {"steel_ingot", 20}},
        buildTime = 72,
        effects = {
            farmExpansion = "7x7",
            description = "Expands farm to 7x7 (49 plots)"
        },
        requires = "wild_manor",
        description = "Massive farming operation with 7x7 grid.",
    },
    irrigation = {
        id = "irrigation",
        name = "Irrigation System",
        cost = {gold = 1500},
        materials = {{"stone", 40}, {"iron_ore", 20}},
        buildTime = 36,
        effects = {
            autoWater = true,
            description = "Automatically waters crops daily"
        },
        requires = "wild_house",
        description = "Automated watering system. No more daily watering chores!",
    },
    greenhouse = {
        id = "greenhouse",
        name = "Greenhouse",
        cost = {gold = 3000},
        materials = {{"wood_planks", 80}, {"iron_ore", 30}, {"mana_crystal", 10}},
        buildTime = 96,
        effects = {
            ignoreSeason = true,
            description = "Crops ignore season restrictions"
        },
        requires = "wild_house",
        description = "Magical greenhouse allows any crop to grow year-round.",
    },
    preserving_station = {
        id = "preserving_station",
        name = "Preserving Station",
        cost = {gold = 1200},
        materials = {{"wood_planks", 40}, {"stone", 20}, {"iron_ore", 10}},
        buildTime = 36,
        effects = {
            processing = "pickles",
            description = "Preserve vegetables in brine"
        },
        requires = "cabin",
        description = "Pickle and preserve vegetables for longer shelf life.",
    },
    kitchen = {
        id = "kitchen",
        name = "Kitchen",
        cost = {gold = 1500},
        materials = {{"wood_planks", 50}, {"iron_ore", 15}, {"stone", 30}},
        buildTime = 48,
        effects = {
            processing = "baking",
            description = "Bake bread, pies, and other goods"
        },
        requires = "cabin",
        description = "Full kitchen for baking bread, pies, and cooking meals.",
    },
    jam_maker = {
        id = "jam_maker",
        name = "Jam Maker",
        cost = {gold = 1800},
        materials = {{"wood_planks", 45}, {"iron_ore", 20}, {"stone", 25}},
        buildTime = 42,
        effects = {
            processing = "jams",
            description = "Create sweet jams from fruits"
        },
        requires = "wild_house",
        description = "Process fruits into valuable jams and preserves.",
    },
    brewery = {
        id = "brewery",
        name = "Brewery",
        cost = {gold = 2500},
        materials = {{"wood_planks", 60}, {"iron_ore", 30}, {"stone", 40}},
        buildTime = 60,
        effects = {
            processing = "wine",
            description = "Ferment fruits into wine"
        },
        requires = "wild_house",
        description = "Ferment fruits into valuable wines. Takes time to age properly.",
    },
    juicer = {
        id = "juicer",
        name = "Juicer",
        cost = {gold = 800},
        materials = {{"wood_planks", 30}, {"iron_ore", 10}},
        buildTime = 24,
        effects = {
            processing = "juice",
            description = "Press fruits and vegetables into juice"
        },
        requires = "cabin",
        description = "Extract fresh juice from fruits and vegetables.",
    },
    stables = {
        id = "stables",
        name = "Stables",
        cost = {gold = 1200},
        materials = {{"wood_planks", 60}, {"iron_ore", 10}},
        buildTime = 36,
        effects = {mountSpeed = 1.5, description = "50% faster travel from here"},
        requires = "wild_house",
        description = "Houses mounts for faster travel.",
    },
}

-- ============================================================================
--                DYNAMIC SETTLEMENT BUILDING SYSTEM
-- ============================================================================

-- Placeable building types with multiple tiers
PropertySystem.SETTLEMENT_BUILDINGS = {

    -- ========== RESIDENTIAL BUILDINGS ==========
    cottage = {
        id = "cottage",
        name = "Cottage",
        category = "residential",
        description = "A small cozy dwelling for settlers.",
        tiers = {
            {tier = 1, name = "Basic Cottage", footprint = {width = 2, height = 2},
             cost = {gold = 300}, materials = {{"wood_planks", 20}, {"stone", 10}},
             buildTime = 24, maxHp = 100,
             effects = {population = 2, comfort = 5}, icon = "🏠"},

            {tier = 2, name = "Comfortable Cottage", footprint = {width = 2, height = 2},
             cost = {gold = 800}, materials = {{"wood_planks", 40}, {"stone", 25}, {"iron_ore", 10}},
             buildTime = 48, maxHp = 150,
             effects = {population = 3, comfort = 12, storage = 5}, icon = "🏡"},

            {tier = 3, name = "Luxurious Cottage", footprint = {width = 2, height = 2},
             cost = {gold = 2000}, materials = {{"wood_planks", 60}, {"stone", 40}, {"steel_ingot", 15}},
             buildTime = 72, maxHp = 200,
             effects = {population = 4, comfort = 20, happiness = 5, storage = 10}, icon = "🏘️"},
        },
    },

    house = {
        id = "house",
        name = "House",
        category = "residential",
        description = "A proper family home with multiple rooms.",
        tiers = {
            {tier = 1, name = "Simple House", footprint = {width = 3, height = 3},
             cost = {gold = 1200}, materials = {{"wood_planks", 50}, {"stone", 40}},
             buildTime = 72, maxHp = 150,
             effects = {population = 5, comfort = 15, storage = 10}, icon = "🏚️"},

            {tier = 2, name = "Well-Built House", footprint = {width = 3, height = 3},
             cost = {gold = 3000}, materials = {{"wood_planks", 80}, {"stone", 70}, {"steel_ingot", 20}},
             buildTime = 120, maxHp = 250,
             effects = {population = 7, comfort = 30, happiness = 10, storage = 20}, icon = "🏠"},

            {tier = 3, name = "Grand House", footprint = {width = 3, height = 3},
             cost = {gold = 6000}, materials = {{"wood_planks", 120}, {"stone", 100}, {"steel_ingot", 40}, {"mana_crystal", 5}},
             buildTime = 168, maxHp = 350,
             effects = {population = 10, comfort = 50, happiness = 20, storage = 40, prestige = 10}, icon = "🏛️"},
        },
    },

    manor = {
        id = "manor",
        name = "Manor",
        category = "residential",
        description = "A grand estate for nobility and wealth.",
        tiers = {
            {tier = 1, name = "Manor Estate", footprint = {width = 4, height = 4},
             cost = {gold = 8000}, materials = {{"wood_planks", 150}, {"stone", 120}, {"steel_ingot", 40}},
             buildTime = 240, maxHp = 400,
             effects = {population = 12, comfort = 50, happiness = 25, storage = 50, prestige = 25}, icon = "🏰"},

            {tier = 2, name = "Noble Manor", footprint = {width = 4, height = 4},
             cost = {gold = 20000}, materials = {{"wood_planks", 250}, {"stone", 200}, {"steel_ingot", 80}, {"mana_crystal", 20}},
             buildTime = 360, maxHp = 600,
             effects = {population = 18, comfort = 80, happiness = 40, storage = 80, prestige = 50, defenseRating = 10}, icon = "🏯"},
        },
    },

    -- ========== WORKSHOP BUILDINGS ==========
    forge = {
        id = "forge",
        name = "Forge",
        category = "workshop",
        description = "Metalworking facility for weapons and armor.",
        tiers = {
            {tier = 1, name = "Simple Forge", footprint = {width = 2, height = 2},
             cost = {gold = 1500}, materials = {{"stone", 60}, {"iron_ore", 40}},
             buildTime = 72, maxHp = 120,
             effects = {crafting = "weapons", repairDiscount = 0.25, employeeSlots = 1}, icon = "⚒️"},

            {tier = 2, name = "Master Forge", footprint = {width = 3, height = 2},
             cost = {gold = 4000}, materials = {{"stone", 100}, {"steel_ingot", 50}, {"mana_crystal", 5}},
             buildTime = 120, maxHp = 200,
             effects = {crafting = "weapons_armor", repairDiscount = 0.40, employeeSlots = 2, qualityBonus = 10}, icon = "⚔️"},
        },
    },

    kitchen = {
        id = "kitchen",
        name = "Kitchen",
        category = "workshop",
        description = "Food preparation and cooking facility.",
        tiers = {
            {tier = 1, name = "Simple Kitchen", footprint = {width = 2, height = 2},
             cost = {gold = 800}, materials = {{"wood_planks", 40}, {"stone", 30}, {"iron_ore", 10}},
             buildTime = 48, maxHp = 80,
             effects = {processing = "baking", employeeSlots = 1}, icon = "🍞"},

            {tier = 2, name = "Full Kitchen", footprint = {width = 3, height = 2},
             cost = {gold = 2000}, materials = {{"wood_planks", 60}, {"stone", 50}, {"steel_ingot", 15}},
             buildTime = 72, maxHp = 120,
             effects = {processing = "baking_advanced", employeeSlots = 2, foodQuality = 15}, icon = "👨‍🍳"},
        },
    },

    alchemy_lab = {
        id = "alchemy_lab",
        name = "Alchemy Lab",
        category = "workshop",
        description = "Potion brewing and alchemical research.",
        tiers = {
            {tier = 1, name = "Novice Lab", footprint = {width = 2, height = 2},
             cost = {gold = 2500}, materials = {{"wood_planks", 30}, {"stone", 40}, {"mana_crystal", 10}},
             buildTime = 96, maxHp = 100,
             effects = {crafting = "potions", employeeSlots = 1}, icon = "⚗️"},

            {tier = 2, name = "Master Lab", footprint = {width = 3, height = 3},
             cost = {gold = 6000}, materials = {{"stone", 80}, {"steel_ingot", 30}, {"mana_crystal", 25}},
             buildTime = 168, maxHp = 180,
             effects = {crafting = "potions_advanced", employeeSlots = 2, potionQuality = 20}, icon = "🧪"},
        },
    },

    -- ========== STORAGE BUILDINGS ==========
    warehouse = {
        id = "warehouse",
        name = "Warehouse",
        category = "storage",
        description = "Large storage facility for goods.",
        tiers = {
            {tier = 1, name = "Small Warehouse", footprint = {width = 3, height = 3},
             cost = {gold = 1500}, materials = {{"wood_planks", 80}, {"iron_ore", 20}},
             buildTime = 72, maxHp = 120,
             effects = {storage = 100}, icon = "📦"},

            {tier = 2, name = "Large Warehouse", footprint = {width = 4, height = 3},
             cost = {gold = 4000}, materials = {{"wood_planks", 150}, {"stone", 60}, {"steel_ingot", 40}},
             buildTime = 120, maxHp = 200,
             effects = {storage = 250}, icon = "🏭"},
        },
    },

    barn = {
        id = "barn",
        name = "Barn",
        category = "storage",
        description = "Agricultural storage and livestock housing.",
        tiers = {
            {tier = 1, name = "Simple Barn", footprint = {width = 3, height = 2},
             cost = {gold = 800}, materials = {{"wood_planks", 60}, {"stone", 20}},
             buildTime = 48, maxHp = 100,
             effects = {storage = 50, livestockCapacity = 5}, icon = "🚜"},

            {tier = 2, name = "Large Barn", footprint = {width = 4, height = 3},
             cost = {gold = 2200}, materials = {{"wood_planks", 100}, {"stone", 50}, {"iron_ore", 20}},
             buildTime = 96, maxHp = 180,
             effects = {storage = 120, livestockCapacity = 12}, icon = "🐄"},
        },
    },

    -- ========== DEFENSE BUILDINGS ==========
    barracks = {
        id = "barracks",
        name = "Barracks",
        category = "defense",
        description = "Training and housing for defenders.",
        tiers = {
            {tier = 1, name = "Basic Barracks", footprint = {width = 3, height = 2},
             cost = {gold = 2000}, materials = {{"wood_planks", 50}, {"stone", 60}, {"iron_ore", 30}},
             buildTime = 96, maxHp = 150,
             effects = {defenders = 3, defenseRating = 10, trainingSpeed = 1.0}, icon = "⚔️"},

            {tier = 2, name = "Fortified Barracks", footprint = {width = 4, height = 2},
             cost = {gold = 5000}, materials = {{"stone", 100}, {"steel_ingot", 50}, {"iron_ore", 40}},
             buildTime = 168, maxHp = 280,
             effects = {defenders = 6, defenseRating = 25, trainingSpeed = 1.5, veteranChance = 0.2}, icon = "🛡️"},

            {tier = 3, name = "Elite Barracks", footprint = {width = 4, height = 3},
             cost = {gold = 12000}, materials = {{"stone", 180}, {"steel_ingot", 100}, {"mana_crystal", 15}},
             buildTime = 240, maxHp = 400,
             effects = {defenders = 10, defenseRating = 50, trainingSpeed = 2.0, veteranChance = 0.5, eliteChance = 0.2}, icon = "⚔️"},
        },
    },

    watchtower = {
        id = "watchtower",
        name = "Watchtower",
        category = "defense",
        description = "Early warning tower and defensive position.",
        tiers = {
            {tier = 1, name = "Wooden Watchtower", footprint = {width = 1, height = 1},
             cost = {gold = 600}, materials = {{"wood_planks", 30}, {"stone", 20}},
             buildTime = 36, maxHp = 80,
             effects = {defenseRating = 5, earlyWarning = true, visionRange = 2}, icon = "🗼"},

            {tier = 2, name = "Stone Watchtower", footprint = {width = 2, height = 2},
             cost = {gold = 1800}, materials = {{"stone", 60}, {"steel_ingot", 20}},
             buildTime = 72, maxHp = 180,
             effects = {defenseRating = 15, earlyWarning = true, visionRange = 3, archers = 2}, icon = "🏯"},
        },
    },

    -- ========== ECONOMY BUILDINGS ==========
    market = {
        id = "market",
        name = "Market",
        category = "economy",
        description = "Trading hub for buying and selling goods.",
        tiers = {
            {tier = 1, name = "Small Market", footprint = {width = 3, height = 3},
             cost = {gold = 3000}, materials = {{"wood_planks", 80}, {"stone", 40}},
             buildTime = 96, maxHp = 100,
             effects = {dailyIncome = 50, tradeBonus = 0.10, employeeSlots = 2}, icon = "🏪"},

            {tier = 2, name = "Grand Bazaar", footprint = {width = 4, height = 4},
             cost = {gold = 8000}, materials = {{"wood_planks", 150}, {"stone", 100}, {"steel_ingot", 30}},
             buildTime = 168, maxHp = 180,
             effects = {dailyIncome = 150, tradeBonus = 0.25, employeeSlots = 5, attractsTraders = true}, icon = "🏬"},
        },
    },

    trade_post = {
        id = "trade_post",
        name = "Trade Post",
        category = "economy",
        description = "Caravan trading facility and rest stop.",
        tiers = {
            {tier = 1, name = "Trade Post", footprint = {width = 2, height = 2},
             cost = {gold = 1500}, materials = {{"wood_planks", 50}, {"iron_ore", 20}},
             buildTime = 72, maxHp = 100,
             effects = {dailyIncome = 25, caravanAccess = true}, icon = "🛒"},
        },
    },

    -- ========== AGRICULTURE BUILDINGS ==========
    farm_building = {
        id = "farm_building",
        name = "Farm Building",
        category = "agriculture",
        description = "Organized crop cultivation with built-in plots.",
        tiers = {
            {tier = 1, name = "Small Farm", footprint = {width = 3, height = 3},
             cost = {gold = 600}, materials = {{"wood_planks", 30}},
             buildTime = 36, maxHp = 80,
             effects = {cropSlots = 9, farmSize = "3x3"}, icon = "🌾"},

            {tier = 2, name = "Medium Farm", footprint = {width = 5, height = 3},
             cost = {gold = 1800}, materials = {{"wood_planks", 60}, {"stone", 30}},
             buildTime = 72, maxHp = 120,
             effects = {cropSlots = 15, farmSize = "5x3", yieldBonus = 0.10}, icon = "🚜"},

            {tier = 3, name = "Large Farm", footprint = {width = 5, height = 5},
             cost = {gold = 4500}, materials = {{"wood_planks", 120}, {"stone", 60}, {"steel_ingot", 20}},
             buildTime = 120, maxHp = 180,
             effects = {cropSlots = 25, farmSize = "5x5", yieldBonus = 0.25, autoIrrigation = true}, icon = "🌻"},
        },
    },

    greenhouse = {
        id = "greenhouse",
        name = "Greenhouse",
        category = "agriculture",
        description = "Climate-controlled growing facility for year-round crops.",
        tiers = {
            {tier = 1, name = "Small Greenhouse", footprint = {width = 3, height = 2},
             cost = {gold = 3000}, materials = {{"wood_planks", 60}, {"iron_ore", 30}, {"mana_crystal", 10}},
             buildTime = 96, maxHp = 100,
             effects = {cropSlots = 12, ignoreSeason = true, growthSpeed = 1.5}, icon = "🏡"},

            {tier = 2, name = "Advanced Greenhouse", footprint = {width = 4, height = 3},
             cost = {gold = 7000}, materials = {{"wood_planks", 100}, {"steel_ingot", 50}, {"mana_crystal", 25}},
             buildTime = 168, maxHp = 160,
             effects = {cropSlots = 24, ignoreSeason = true, growthSpeed = 2.0, rarityBonus = 0.15}, icon = "🌿"},
        },
    },

    -- ========== INFRASTRUCTURE ==========
    road = {
        id = "road",
        name = "Road",
        category = "infrastructure",
        description = "Paved pathway for efficient movement.",
        tiers = {
            {tier = 1, name = "Dirt Path", footprint = {width = 1, height = 1},
             cost = {gold = 5}, materials = {{"stone", 1}},
             buildTime = 1, maxHp = 50,
             effects = {movementSpeed = 1.1, adjacencyBonus = true}, icon = "🛤️"},

            {tier = 2, name = "Stone Road", footprint = {width = 1, height = 1},
             cost = {gold = 15}, materials = {{"stone", 5}},
             buildTime = 2, maxHp = 100,
             effects = {movementSpeed = 1.25, adjacencyBonus = true, prestigeBonus = 2}, icon = "🛣️"},
        },
    },

    well = {
        id = "well",
        name = "Well",
        category = "infrastructure",
        description = "Water source for the settlement.",
        tiers = {
            {tier = 1, name = "Simple Well", footprint = {width = 1, height = 1},
             cost = {gold = 300}, materials = {{"stone", 20}},
             buildTime = 12, maxHp = 100,
             effects = {waterRadius = 4, healthBonus = 5}, icon = "🚰"},

            {tier = 2, name = "Deep Well", footprint = {width = 1, height = 1},
             cost = {gold = 800}, materials = {{"stone", 40}, {"iron_ore", 15}},
             buildTime = 24, maxHp = 150,
             effects = {waterRadius = 6, healthBonus = 12, cleanWater = true}, icon = "💧"},
        },
    },

    fountain = {
        id = "fountain",
        name = "Fountain",
        category = "infrastructure",
        description = "Decorative water feature that boosts morale.",
        tiers = {
            {tier = 1, name = "Stone Fountain", footprint = {width = 2, height = 2},
             cost = {gold = 800}, materials = {{"stone", 40}, {"iron_ore", 10}},
             buildTime = 48, maxHp = 120,
             effects = {happiness = 10, prestige = 5, beautyRadius = 4}, icon = "⛲"},

            {tier = 2, name = "Grand Fountain", footprint = {width = 3, height = 3},
             cost = {gold = 2500}, materials = {{"stone", 80}, {"steel_ingot", 20}, {"mana_crystal", 10}},
             buildTime = 96, maxHp = 200,
             effects = {happiness = 25, prestige = 15, beautyRadius = 6, manaRegen = true}, icon = "⛲"},
        },
    },
}

-- Wall segment types (placeable on tile edges)
PropertySystem.WALL_SEGMENTS = {
    wooden_palisade = {
        id = "wooden_palisade",
        name = "Wooden Palisade",
        tier = 1,
        cost = {gold = 50},
        materials = {{"wood_planks", 5}},
        buildTime = 6,
        defenseBonus = 3,
        hp = 30,
        maxHp = 30,
        upgradesTo = "stone_wall_segment",
        icon = "🪵",
    },
    stone_wall_segment = {
        id = "stone_wall_segment",
        name = "Stone Wall",
        tier = 2,
        cost = {gold = 150},
        materials = {{"stone", 15}, {"iron_ore", 5}},
        buildTime = 12,
        defenseBonus = 8,
        hp = 80,
        maxHp = 80,
        upgradesTo = "fortified_wall_segment",
        icon = "🧱",
    },
    fortified_wall_segment = {
        id = "fortified_wall_segment",
        name = "Fortified Wall",
        tier = 3,
        cost = {gold = 500},
        materials = {{"stone", 30}, {"steel_ingot", 10}},
        buildTime = 24,
        defenseBonus = 20,
        hp = 150,
        maxHp = 150,
        upgradesTo = nil,
        icon = "🏰",
    },
    gate = {
        id = "gate",
        name = "Gate",
        tier = 1,
        cost = {gold = 200},
        materials = {{"wood_planks", 15}, {"iron_ore", 10}},
        buildTime = 12,
        defenseBonus = 5,
        hp = 50,
        maxHp = 50,
        canOpen = true,
        isOpen = false,
        icon = "🚪",
    },
}

-- Terrain features (for settlement grid initialization)
PropertySystem.TERRAIN_FEATURES = {
    tree = {id = "tree", name = "Tree", clearable = true, clearCost = 10, clearTime = 2, yieldsWood = 5, icon = "🌲"},
    rock = {id = "rock", name = "Rock", clearable = true, clearCost = 15, clearTime = 3, yieldsStone = 8, icon = "🪨"},
    water = {id = "water", name = "Water", clearable = false, icon = "💧"},
    brush = {id = "brush", name = "Brush", clearable = true, clearCost = 5, clearTime = 1, icon = "🌿"},
}

-- Settlement upgrade levels
PropertySystem.SETTLEMENT_LEVELS = {
    {
        level = 1,
        name = "Homestead",
        maxPopulation = 5,
        maxBuildings = 2,
        cost = nil,  -- Starting level
        description = "A small homestead with a few residents.",
    },
    {
        level = 2,
        name = "Hamlet",
        maxPopulation = 15,
        maxBuildings = 5,
        cost = {gold = 5000},
        materials = {{"wood_planks", 100}, {"stone", 50}},
        description = "A tiny hamlet beginning to attract settlers.",
    },
    {
        level = 3,
        name = "Village",
        maxPopulation = 50,
        maxBuildings = 12,
        cost = {gold = 25000},
        materials = {{"wood_planks", 300}, {"stone", 200}, {"steel_ingot", 50}},
        description = "A proper village with shops and services.",
    },
    {
        level = 4,
        name = "Town",
        maxPopulation = 200,
        maxBuildings = 25,
        cost = {gold = 100000},
        materials = {{"wood_planks", 500}, {"stone", 500}, {"steel_ingot", 200}},
        description = "A bustling town with walls and markets.",
    },
    {
        level = 5,
        name = "City",
        maxPopulation = 500,
        maxBuildings = 50,
        cost = {gold = 500000},
        materials = {{"mythril_shard", 100}, {"stone", 1000}, {"steel_ingot", 500}},
        description = "A grand city rivaling the capitals.",
    },
}

-- Region danger levels for attack chance (daily)
PropertySystem.REGION_DANGER = {
    holy_dominion = 0.05,
    dwarven_mountains = 0.08,
    orcish_steppes = 0.15,
    shadowfen = 0.20,
    eastern_forests = 0.10,
    gnomish_isles = 0.03,
    great_endless_desert = 0.25,
    scorched_sands = 0.25,
    wastes_of_calidar = 0.30,
    shimmering_sea = 0.05,
}

-- Attacker types by region
PropertySystem.ATTACKERS_BY_REGION = {
    holy_dominion = {"bandits", "wolves", "thieves"},
    dwarven_mountains = {"goblins", "cave_trolls", "bandits"},
    orcish_steppes = {"orc_raiders", "bandits", "wolves"},
    shadowfen = {"undead", "swamp_creatures", "bandits"},
    eastern_forests = {"wolves", "bandits", "goblins"},
    gnomish_isles = {"pirates", "bandits"},
    great_endless_desert = {"desert_raiders", "scorpions", "bandits"},
    scorched_sands = {"desert_raiders", "fire_elementals"},
    wastes_of_calidar = {"undead", "demons", "bandits"},
    shimmering_sea = {"pirates", "sea_monsters"},
}

-- ============================================================================
--              EXPANSION CONSTANTS (forwarded from SettlementExpansion)
-- ============================================================================
PropertySystem.MAX_SETTLEMENT_WIDTH = SettlementExpansion.MAX_SETTLEMENT_WIDTH
PropertySystem.MAX_SETTLEMENT_HEIGHT = SettlementExpansion.MAX_SETTLEMENT_HEIGHT
PropertySystem.MAX_PLOTS_PER_SETTLEMENT = SettlementExpansion.MAX_PLOTS_PER_SETTLEMENT

-- ============================================================================
--              RESOURCE CONSTANTS (forwarded from ResourceProcessing)
-- ============================================================================
PropertySystem.FOREST_MAX_LUMBER = ResourceProcessing.FOREST_MAX_LUMBER
PropertySystem.LUMBER_REGEN_RATE = ResourceProcessing.LUMBER_REGEN_RATE
PropertySystem.DEFORESTATION_THRESHOLD = ResourceProcessing.DEFORESTATION_THRESHOLD

-- ============================================================================
--                         INITIALIZATION
-- ============================================================================

function PropertySystem.init(gameState)
    state = gameState

    -- During character creation, player doesn't exist yet.
    -- Store the state reference and return early; property data
    -- will be initialized when the player is actually created.
    if not state.player then
        return
    end

    -- Ensure property data structure exists
    if not state.player.properties then
        state.player.properties = {
            townProperties = {},
            landClaims = {},
            settlements = {},
        }
    end

    -- Ensure expansion permits field exists (migration for old saves)
    if state.player.expansionPermits == nil then
        state.player.expansionPermits = 0
    end

    -- Migrate old settlements to multi-plot structure if needed
    PropertySystem.migrateSettlementsToMultiPlot()

    -- Sync gold from main game currency on init
    syncGoldFromPlayerData()
end

function PropertySystem.getState()
    return state
end

-- ============================================================================
--                      TOWN PROPERTY FUNCTIONS
-- ============================================================================

-- Check if player owns a specific town property
function PropertySystem.ownsProperty(townId, buildingId)
    if not state or not state.player or not state.player.properties then
        return false
    end
    local key = townId .. "_" .. buildingId
    return state.player.properties.townProperties[key] ~= nil
end

-- Check if player owns any property of a type across all towns
function PropertySystem.ownsAnyPropertyOfType(buildingId)
    if not state or not state.player or not state.player.properties then
        return false
    end
    for key, prop in pairs(state.player.properties.townProperties) do
        if prop.buildingId == buildingId then
            return true
        end
    end
    return false
end

-- Get property definition (business or home)
function PropertySystem.getPropertyDef(buildingId)
    return PropertySystem.BUSINESS_PROPERTIES[buildingId] or PropertySystem.HOME_PROPERTIES[buildingId]
end

-- Check if player can purchase a property
function PropertySystem.canPurchaseProperty(townId, buildingId)
    local propDef = PropertySystem.getPropertyDef(buildingId)
    if not propDef then
        return false, "Property not found"
    end

    -- Already owned?
    if PropertySystem.ownsProperty(townId, buildingId) then
        return false, "You already own this property"
    end

    -- Check gold
    if state.player.gold < propDef.basePrice then
        return false, "Not enough gold (need " .. propDef.basePrice .. "g)"
    end

    -- Check level requirement
    local playerLevel = state.player.level or 1
    if propDef.requiresLevel and playerLevel < propDef.requiresLevel then
        return false, "Requires level " .. propDef.requiresLevel
    end

    -- Check reputation requirement
    if propDef.requiresReputation and propDef.requiresReputation > 0 then
        local reputation = state.player.reputation or state.player.karma or 0
        if reputation < propDef.requiresReputation then
            return false, "Requires " .. propDef.requiresReputation .. " reputation"
        end
    end

    return true, nil
end

-- Purchase a town property
function PropertySystem.purchaseProperty(townId, buildingId)
    syncGoldFromPlayerData()
    local canPurchase, reason = PropertySystem.canPurchaseProperty(townId, buildingId)
    if not canPurchase then
        return false, reason
    end

    local propDef = PropertySystem.getPropertyDef(buildingId)
    local isBusiness = PropertySystem.BUSINESS_PROPERTIES[buildingId] ~= nil

    -- Deduct gold
    state.player.gold = state.player.gold - propDef.basePrice
    syncGoldToPlayerData()

    -- Create property record
    local key = townId .. "_" .. buildingId
    state.player.properties.townProperties[key] = {
        townId = townId,
        buildingId = buildingId,
        propertyType = isBusiness and "business" or "home",
        purchaseDate = state.daysPassed or 0,
        purchasePrice = propDef.basePrice,

        -- Business fields
        employees = {},
        upgrades = {},
        dailyIncome = 0,
        lastCollectionDay = state.daysPassed or 0,

        -- Home fields
        storage = {},
        furnishings = {},
    }

    return true, propDef.name .. " purchased for " .. propDef.basePrice .. "g!"
end

-- Sell a town property (get 50% back)
function PropertySystem.sellProperty(townId, buildingId)
    syncGoldFromPlayerData()
    if not PropertySystem.ownsProperty(townId, buildingId) then
        return false, "You don't own this property"
    end

    local propDef = PropertySystem.getPropertyDef(buildingId)
    local key = townId .. "_" .. buildingId
    local prop = state.player.properties.townProperties[key]

    -- Refund 50% of purchase price
    local refund = math.floor(prop.purchasePrice * 0.5)
    state.player.gold = state.player.gold + refund
    syncGoldToPlayerData()

    -- Remove property
    state.player.properties.townProperties[key] = nil

    return true, "Sold " .. propDef.name .. " for " .. refund .. "g"
end

-- Get all properties owned in a specific town
function PropertySystem.getPropertiesInTown(townId)
    local properties = {}
    for key, prop in pairs(state.player.properties.townProperties) do
        if prop.townId == townId then
            table.insert(properties, prop)
        end
    end
    return properties
end

-- Get all owned properties
function PropertySystem.getAllProperties()
    return state.player.properties.townProperties
end

-- ============================================================================
--                      WILD LAND CLAIM FUNCTIONS
-- ============================================================================

-- Check if a tile can be claimed
function PropertySystem.canClaimTile(x, y)
    -- Early return if coordinates are nil
    if x == nil or y == nil then
        return false, "Invalid coordinates"
    end

    local WorldGen = require("worldgen")
    local tile = WorldGen.getTile(x, y)

    if not tile then
        return false, "Invalid location"
    end

    -- Can't claim certain terrain types
    if tile.type == "town" then
        return false, "Cannot claim town land"
    end
    if tile.type == "water" then
        return false, "Cannot claim water"
    end
    if tile.type == "dungeon" then
        return false, "Cannot claim dungeon"
    end

    -- Check if already claimed
    local key = x .. "_" .. y
    if state.player.properties.landClaims[key] then
        return false, "You already own this land"
    end

    -- Check if claimed by world (NPC settlement, etc.)
    if tile.claimedBy then
        return false, "This land is already claimed"
    end

    return true, nil
end

-- Get claim cost based on region
function PropertySystem.getClaimCost(x, y)
    local WorldGen = require("worldgen")
    local region, _ = WorldGen.getRegionAt(x, y)
    if not region then
        return 100
    end
    local baseCost = 100

    -- More dangerous regions cost more
    local danger = PropertySystem.REGION_DANGER[region.id] or 0.1
    local dangerMultiplier = 1 + (danger * 2)

    -- Distance from starting area affects cost
    local distFromStart = math.abs(x - 35) + math.abs(y - 42)
    local distanceMultiplier = 1 + (distFromStart * 0.01)

    return math.floor(baseCost * dangerMultiplier * distanceMultiplier)
end

-- Claim a wild land tile
function PropertySystem.claimLand(x, y)
    syncGoldFromPlayerData()
    local canClaim, reason = PropertySystem.canClaimTile(x, y)
    if not canClaim then
        return false, reason
    end

    local claimCost = PropertySystem.getClaimCost(x, y)
    if state.player.gold < claimCost then
        return false, "Not enough gold (need " .. claimCost .. "g)"
    end

    local WorldGen = require("worldgen")
    local region, _ = WorldGen.getRegionAt(x, y)

    -- Deduct gold
    state.player.gold = state.player.gold - claimCost
    syncGoldToPlayerData()

    -- Create claim record
    local key = x .. "_" .. y
    state.player.properties.landClaims[key] = {
        x = x,
        y = y,
        claimDate = state.daysPassed or 0,
        region = region.id,

        -- Structure data
        structure = nil,
        structureLevel = 0,
        building = nil,  -- Active build in progress

        -- Defense data
        hasWalls = false,
        wallLevel = 0,
        wallBuilding = nil,  -- Active wall build
        defenseRating = 0,

        -- Attack tracking
        lastAttack = nil,
        attackLog = {},
        damageLevel = 0,  -- 0-100, 100 = destroyed

        -- Residents
        residents = {},
        maxResidents = 0,
    }

    -- Mark tile as claimed in world
    local tile = WorldGen.getTile(x, y)
    if tile then
        tile.claimedBy = "player"
    end

    return true, "Land claimed for " .. claimCost .. "g!"
end

-- Abandon a land claim
function PropertySystem.abandonClaim(x, y)
    local key = x .. "_" .. y
    local claim = state.player.properties.landClaims[key]

    if not claim then
        return false, "You don't own this land"
    end

    -- If this claim is merged into a settlement, remove it from the settlement's claimKeys
    local settId, settlement = PropertySystem.findSettlementForClaim(key)
    if settlement and settlement.claimKeys then
        for i, ck in ipairs(settlement.claimKeys) do
            if ck == key then
                table.remove(settlement.claimKeys, i)
                break
            end
        end
        -- If settlement now has no claims, remove it entirely
        if #settlement.claimKeys == 0 then
            state.player.properties.settlements[settId] = nil
        else
            -- Update bounds and plot count
            settlement.bounds = PropertySystem.getSettlementBounds(settId)
            settlement.plotCount = #settlement.claimKeys
        end
    end

    -- Remove claim
    state.player.properties.landClaims[key] = nil

    -- Also remove settlement if exists (for legacy single-key settlements)
    if state.player.properties.settlements[key] then
        state.player.properties.settlements[key] = nil
    end

    -- Unmark tile
    local WorldGen = require("worldgen")
    local tile = WorldGen.getTile(x, y)
    if tile then
        tile.claimedBy = nil
    end

    return true, "Land claim abandoned"
end

-- Get all land claims
function PropertySystem.getAllClaims()
    return state.player.properties.landClaims
end

-- Get claim at specific coordinates
function PropertySystem.getClaimAt(x, y)
    local key = x .. "_" .. y
    return state.player.properties.landClaims[key]
end

-- ============================================================================
--                      STRUCTURE BUILDING FUNCTIONS
-- ============================================================================

-- Check if player has required materials
local function hasMaterials(materials)
    for _, mat in ipairs(materials) do
        local itemId, required = mat[1], mat[2]
        local count = Backpack.getItemCount(itemId) or 0
        if count < required then
            return false, "Need " .. required .. " " .. itemId .. " (have " .. count .. ")"
        end
    end
    return true, nil
end

-- Consume materials from backpack
local function consumeMaterials(materials)
    for _, mat in ipairs(materials) do
        Backpack.removeItem(mat[1], mat[2])
    end
end

-- Check if can build a structure on claimed land
function PropertySystem.canBuildStructure(claimKey, structureId)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim then
        return false, "No claim found"
    end

    local structDef = PropertySystem.WILD_STRUCTURES[structureId]
    if not structDef then
        return false, "Invalid structure"
    end

    -- Check if already building something
    if claim.building then
        return false, "Already building something"
    end

    -- Check upgrade path
    if structDef.id ~= "tent" then
        -- Must have previous structure to upgrade
        local prevStruct = PropertySystem.WILD_STRUCTURES[claim.structure]
        if not prevStruct or prevStruct.upgradesTo ~= structureId then
            return false, "Must build " .. (claim.structure and "upgrade from " .. claim.structure or "a tent first")
        end
    elseif claim.structure then
        return false, "Already have a structure here"
    end

    -- Check gold
    if state.player.gold < structDef.cost.gold then
        return false, "Not enough gold (need " .. structDef.cost.gold .. "g)"
    end

    -- Check materials
    if structDef.materials then
        local hasMats, reason = hasMaterials(structDef.materials)
        if not hasMats then
            return false, reason
        end
    end

    return true, nil
end

-- Start building a structure
function PropertySystem.startBuildStructure(claimKey, structureId)
    syncGoldFromPlayerData()
    local canBuild, reason = PropertySystem.canBuildStructure(claimKey, structureId)
    if not canBuild then
        return false, reason
    end

    local claim = state.player.properties.landClaims[claimKey]
    local structDef = PropertySystem.WILD_STRUCTURES[structureId]

    -- Deduct gold and materials
    state.player.gold = state.player.gold - structDef.cost.gold
    syncGoldToPlayerData()
    if structDef.materials then
        consumeMaterials(structDef.materials)
    end

    -- Instant build?
    if structDef.buildTime == 0 then
        claim.structure = structureId
        claim.maxResidents = structDef.maxResidents
        claim.defenseRating = structDef.defenseRating
        return true, structDef.name .. " built!"
    end

    -- Start build progress
    claim.building = {
        structureId = structureId,
        startTime = state.daysPassed or 0,
        hoursRemaining = structDef.buildTime,
    }

    return true, "Started building " .. structDef.name .. " (will take " .. structDef.buildTime .. " hours)"
end

-- Check if can build walls
function PropertySystem.canBuildWall(claimKey, wallId)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim then
        return false, "No claim found"
    end

    -- Must have at least a tent
    if not claim.structure then
        return false, "Build a structure first"
    end

    local wallDef = PropertySystem.WALL_STRUCTURES[wallId]
    if not wallDef then
        return false, "Invalid wall type"
    end

    -- Check if already building walls
    if claim.wallBuilding then
        return false, "Already building walls"
    end

    -- Check prerequisite
    if wallDef.requires then
        local currentWall = nil
        for wid, wdef in pairs(PropertySystem.WALL_STRUCTURES) do
            if wdef.wallLevel == claim.wallLevel then
                currentWall = wid
                break
            end
        end
        if currentWall ~= wallDef.requires then
            return false, "Requires " .. PropertySystem.WALL_STRUCTURES[wallDef.requires].name .. " first"
        end
    elseif claim.wallLevel > 0 then
        return false, "Already have walls"
    end

    -- Check gold
    if state.player.gold < wallDef.cost.gold then
        return false, "Not enough gold (need " .. wallDef.cost.gold .. "g)"
    end

    -- Check materials
    if wallDef.materials then
        local hasMats, reason = hasMaterials(wallDef.materials)
        if not hasMats then
            return false, reason
        end
    end

    return true, nil
end

-- Start building walls
function PropertySystem.startBuildWall(claimKey, wallId)
    syncGoldFromPlayerData()
    local canBuild, reason = PropertySystem.canBuildWall(claimKey, wallId)
    if not canBuild then
        return false, reason
    end

    local claim = state.player.properties.landClaims[claimKey]
    local wallDef = PropertySystem.WALL_STRUCTURES[wallId]

    -- Deduct gold and materials
    state.player.gold = state.player.gold - wallDef.cost.gold
    syncGoldToPlayerData()
    if wallDef.materials then
        consumeMaterials(wallDef.materials)
    end

    -- Start build
    claim.wallBuilding = {
        wallId = wallId,
        startTime = state.daysPassed or 0,
        hoursRemaining = wallDef.buildTime,
    }

    return true, "Started building " .. wallDef.name .. " (will take " .. wallDef.buildTime .. " hours)"
end

-- ============================================================================
--                      IMPROVEMENT FUNCTIONS
-- ============================================================================

-- Check if can build an improvement
function PropertySystem.canBuildImprovement(claimKey, improvementId)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim then
        return false, "No claim found"
    end

    local impDef = PropertySystem.IMPROVEMENTS[improvementId]
    if not impDef then
        return false, "Invalid improvement"
    end

    -- Check if already building something
    if claim.improvementBuilding then
        return false, "Already building an improvement"
    end

    -- Check if already have this improvement
    claim.improvements = claim.improvements or {}
    if claim.improvements[improvementId] then
        return false, "Already have this improvement"
    end

    -- Check structure requirement
    if impDef.requires then
        local structureOrder = {tent = 1, cabin = 2, wild_house = 3, wild_manor = 4}
        local currentLevel = structureOrder[claim.structure] or 0
        local requiredLevel = structureOrder[impDef.requires] or 0
        if currentLevel < requiredLevel then
            return false, "Requires " .. (PropertySystem.WILD_STRUCTURES[impDef.requires] and PropertySystem.WILD_STRUCTURES[impDef.requires].name or impDef.requires)
        end
    end

    -- Check gold
    if state.player.gold < impDef.cost.gold then
        return false, "Not enough gold (need " .. impDef.cost.gold .. "g)"
    end

    -- Check materials
    if impDef.materials then
        local hasMats, reason = hasMaterials(impDef.materials)
        if not hasMats then
            return false, reason
        end
    end

    return true, nil
end

-- Start building an improvement
function PropertySystem.startBuildImprovement(claimKey, improvementId)
    syncGoldFromPlayerData()
    local canBuild, reason = PropertySystem.canBuildImprovement(claimKey, improvementId)
    if not canBuild then
        return false, reason
    end

    local claim = state.player.properties.landClaims[claimKey]
    local impDef = PropertySystem.IMPROVEMENTS[improvementId]

    -- Deduct gold and materials
    state.player.gold = state.player.gold - impDef.cost.gold
    syncGoldToPlayerData()
    if impDef.materials then
        consumeMaterials(impDef.materials)
    end

    -- Start build
    claim.improvementBuilding = {
        improvementId = improvementId,
        startTime = state.daysPassed or 0,
        hoursRemaining = impDef.buildTime,
    }

    return true, "Started building " .. impDef.name .. " (will take " .. impDef.buildTime .. " hours)"
end

-- Get available improvements for a claim
function PropertySystem.getAvailableImprovements(claimKey)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim then
        return {}
    end

    local available = {}
    claim.improvements = claim.improvements or {}

    for impId, impDef in pairs(PropertySystem.IMPROVEMENTS) do
        if not claim.improvements[impId] then
            local canBuild, reason = PropertySystem.canBuildImprovement(claimKey, impId)
            table.insert(available, {
                id = impId,
                def = impDef,
                canBuild = canBuild,
                reason = reason
            })
        end
    end

    return available
end

-- Get built improvements for a claim
function PropertySystem.getBuiltImprovements(claimKey)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim or not claim.improvements then
        return {}
    end

    local built = {}
    for impId, data in pairs(claim.improvements) do
        local impDef = PropertySystem.IMPROVEMENTS[impId]
        if impDef then
            table.insert(built, {
                id = impId,
                def = impDef,
                builtDate = data.builtDate
            })
        end
    end

    return built
end

-- Calculate total effects from improvements
function PropertySystem.getImprovementEffects(claimKey)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim or not claim.improvements then
        return {}
    end

    local effects = {
        defenseBonus = 0,
        incomeBonus = 0,
        storageBonus = 0,
        healthBonus = 0,
    }

    for impId, _ in pairs(claim.improvements) do
        local impDef = PropertySystem.IMPROVEMENTS[impId]
        if impDef and impDef.effects then
            effects.defenseBonus = effects.defenseBonus + (impDef.effects.defenseBonus or 0)
            effects.incomeBonus = effects.incomeBonus + (impDef.effects.incomeBonus or 0)
            effects.storageBonus = effects.storageBonus + (impDef.effects.storageBonus or 0)
            effects.healthBonus = effects.healthBonus + (impDef.effects.healthBonus or 0)
        end
    end

    return effects
end

-- ============================================================================
--                      SETTLEMENT FUNCTIONS
-- ============================================================================

-- Check if a claim can become a settlement
function PropertySystem.canCreateSettlement(claimKey)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim then
        return false, "No claim found"
    end

    -- Must have at least a cabin
    if not claim.structure or claim.structure == "tent" then
        return false, "Need at least a cabin to start a settlement"
    end

    -- Must have walls
    if not claim.hasWalls then
        return false, "Need walls to protect the settlement"
    end

    -- Check if already a settlement
    if state.player.properties.settlements[claimKey] then
        return false, "Already a settlement"
    end

    return true, nil
end

-- Generate a default settlement name based on region/location
function PropertySystem.generateSettlementName(claimKey)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim then return "New Settlement" end

    local regionNames = {
        holy_dominion = "Holy",
        dwarven_mountains = "Mountain",
        orcish_steppes = "Steppe",
        shadowfen = "Fen",
        eastern_forests = "Forest",
        gnomish_isles = "Island",
        great_endless_desert = "Desert",
        scorched_sands = "Sands",
        wastes_of_calidar = "Wastes",
        shimmering_sea = "Coastal",
    }

    local suffixes = {"Homestead", "Outpost", "Camp", "Settlement", "Hold", "Rest", "Haven", "Post"}

    local prefix = regionNames[claim.region] or "Frontier"
    local suffix = suffixes[math.random(#suffixes)]

    return prefix .. " " .. suffix
end

-- Create a settlement from a claim
function PropertySystem.createSettlement(claimKey, name)
    local canCreate, reason = PropertySystem.canCreateSettlement(claimKey)
    if not canCreate then
        return false, reason
    end

    local claim = state.player.properties.landClaims[claimKey]
    local level1 = PropertySystem.SETTLEMENT_LEVELS[1]

    -- Generate a contextual name if none provided
    local settlementName = name or PropertySystem.generateSettlementName(claimKey)

    -- Collect all claim keys that belong to this settlement (including merged plots)
    local claimKeys = {claimKey}
    for key, c in pairs(state.player.properties.landClaims) do
        if c.mergedInto == claimKey and key ~= claimKey then
            table.insert(claimKeys, key)
        end
    end

    state.player.properties.settlements[claimKey] = {
        name = settlementName,
        customName = nil,  -- Player can set a custom name
        level = 1,
        levelName = level1.name,
        population = 0,
        maxPopulation = level1.maxPopulation,
        buildings = {},
        maxBuildings = level1.maxBuildings,
        resources = {},
        dailyIncome = 0,
        lastUpdate = state.daysPassed or 0,
        claimKeys = claimKeys,
        plotCount = #claimKeys,
        bounds = PropertySystem.getSettlementBounds(claimKey) or {
            minX = claim.x, maxX = claim.x,
            minY = claim.y, maxY = claim.y,
        },
        gridWidth = (claim.settlementGrid and (claim.settlementGrid.width or claim.settlementGrid.size)) or 25,
        gridHeight = (claim.settlementGrid and (claim.settlementGrid.height or claim.settlementGrid.size)) or 25,
    }

    return true, "Founded " .. settlementName .. "!"
end

-- Rename a settlement
function PropertySystem.renameSettlement(settlementId, newName)
    if not state or not state.player or not state.player.properties or not state.player.properties.settlements then
        return false, "No settlements found"
    end
    local settlement = state.player.properties.settlements[settlementId]
    if not settlement then
        return false, "Settlement not found"
    end
    if not newName or newName == "" then
        return false, "Name cannot be empty"
    end
    -- Limit name length
    if #newName > 30 then
        newName = string.sub(newName, 1, 30)
    end
    settlement.customName = newName
    settlement.name = newName
    return true, "Settlement renamed to " .. newName .. "!"
end

-- Check if can upgrade settlement
function PropertySystem.canUpgradeSettlement(claimKey)
    local settlement = state.player.properties.settlements[claimKey]
    if not settlement then
        return false, "Not a settlement"
    end

    if settlement.level >= #PropertySystem.SETTLEMENT_LEVELS then
        return false, "Settlement is at maximum level"
    end

    local nextLevel = PropertySystem.SETTLEMENT_LEVELS[settlement.level + 1]

    -- Check gold
    if state.player.gold < nextLevel.cost.gold then
        return false, "Not enough gold (need " .. nextLevel.cost.gold .. "g)"
    end

    -- Check materials
    if nextLevel.materials then
        local hasMats, reason = hasMaterials(nextLevel.materials)
        if not hasMats then
            return false, reason
        end
    end

    return true, nil
end

-- Upgrade a settlement
function PropertySystem.upgradeSettlement(claimKey)
    syncGoldFromPlayerData()
    local canUpgrade, reason = PropertySystem.canUpgradeSettlement(claimKey)
    if not canUpgrade then
        return false, reason
    end

    local settlement = state.player.properties.settlements[claimKey]
    local nextLevel = PropertySystem.SETTLEMENT_LEVELS[settlement.level + 1]

    -- Deduct costs
    state.player.gold = state.player.gold - nextLevel.cost.gold
    syncGoldToPlayerData()
    if nextLevel.materials then
        consumeMaterials(nextLevel.materials)
    end

    -- Upgrade
    settlement.level = settlement.level + 1
    settlement.levelName = nextLevel.name
    settlement.maxPopulation = nextLevel.maxPopulation
    settlement.maxBuildings = nextLevel.maxBuildings

    return true, "Settlement upgraded to " .. nextLevel.name .. "!"
end

-- Get all settlements
function PropertySystem.getAllSettlements()
    return state.player.properties.settlements
end

-- ============================================================================
--                      RESIDENT FUNCTIONS
-- ============================================================================

-- Add a party member as resident to a settlement
function PropertySystem.addResident(claimKey, partyMemberIndex)
    local claim = state.player.properties.landClaims[claimKey]
    local settlement = state.player.properties.settlements[claimKey]

    if not claim then
        return false, "No claim found"
    end

    -- Check capacity
    local maxResidents = claim.maxResidents
    if settlement then
        maxResidents = settlement.maxPopulation
    end

    if #claim.residents >= maxResidents then
        return false, "No room for more residents"
    end

    -- Get party member
    if not state.player.party or not state.player.party[partyMemberIndex] then
        return false, "Invalid party member"
    end

    local member = state.player.party[partyMemberIndex]

    -- Add to residents
    table.insert(claim.residents, {
        type = "party_member",
        name = member.name,
        class = member.class.id,
        level = member.level,
        assignedDate = state.daysPassed or 0,
    })

    -- Remove from party
    table.remove(state.player.party, partyMemberIndex)

    if settlement then
        settlement.population = settlement.population + 1
    end

    return true, member.name .. " is now a resident"
end

-- Remove a resident
function PropertySystem.removeResident(claimKey, residentIndex)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim then
        return false, "No claim found"
    end

    if not claim.residents[residentIndex] then
        return false, "Invalid resident"
    end

    local resident = claim.residents[residentIndex]
    table.remove(claim.residents, residentIndex)

    local settlement = state.player.properties.settlements[claimKey]
    if settlement then
        settlement.population = math.max(0, settlement.population - 1)
    end

    return true, resident.name .. " is no longer a resident"
end

-- ============================================================================
--                      DAILY UPDATE FUNCTIONS
-- ============================================================================

-- Update construction progress
function PropertySystem.updateConstruction(hoursElapsed)
    for key, claim in pairs(state.player.properties.landClaims) do
        -- Update structure building
        if claim.building then
            claim.building.hoursRemaining = claim.building.hoursRemaining - hoursElapsed
            if claim.building.hoursRemaining <= 0 then
                local structDef = PropertySystem.WILD_STRUCTURES[claim.building.structureId]
                claim.structure = claim.building.structureId
                claim.maxResidents = structDef.maxResidents
                claim.defenseRating = structDef.defenseRating
                claim.building = nil
                -- Log completion
            end
        end

        -- Update wall building
        if claim.wallBuilding then
            claim.wallBuilding.hoursRemaining = claim.wallBuilding.hoursRemaining - hoursElapsed
            if claim.wallBuilding.hoursRemaining <= 0 then
                local wallDef = PropertySystem.WALL_STRUCTURES[claim.wallBuilding.wallId]
                claim.hasWalls = true
                claim.wallLevel = wallDef.wallLevel
                claim.defenseRating = claim.defenseRating + wallDef.defenseBonus
                claim.wallBuilding = nil
                -- Log completion
            end
        end

        -- Update improvement building
        if claim.improvementBuilding then
            claim.improvementBuilding.hoursRemaining = claim.improvementBuilding.hoursRemaining - hoursElapsed
            if claim.improvementBuilding.hoursRemaining <= 0 then
                local impDef = PropertySystem.IMPROVEMENTS[claim.improvementBuilding.improvementId]
                claim.improvements = claim.improvements or {}
                claim.improvements[claim.improvementBuilding.improvementId] = {
                    builtDate = state.daysPassed or 0,
                }
                -- Apply defense bonus from improvement
                if impDef and impDef.effects and impDef.effects.defenseBonus then
                    claim.defenseRating = (claim.defenseRating or 0) + impDef.effects.defenseBonus
                end

                -- Initialize farm plots if farm improvement
                if claim.improvementBuilding.improvementId == "farm" then
                    PropertySystem.initializeFarm(key, 3)  -- 3x3 grid
                elseif claim.improvementBuilding.improvementId == "expanded_farm" then
                    PropertySystem.expandFarm(key, 5)  -- 5x5 grid
                elseif claim.improvementBuilding.improvementId == "large_farm" then
                    PropertySystem.expandFarm(key, 7)  -- 7x7 grid
                end

                claim.improvementBuilding = nil
                -- Log completion
            end
        end
    end
end

-- Simulate attacks on unprotected properties
function PropertySystem.simulateAttacks(daysPassed)
    local attacks = {}

    for key, claim in pairs(state.player.properties.landClaims) do
        -- Only attack if no walls
        if not claim.hasWalls and claim.structure then
            local danger = PropertySystem.REGION_DANGER[claim.region] or 0.1

            if math.random() < danger then
                -- Attack occurs!
                local attackers = PropertySystem.ATTACKERS_BY_REGION[claim.region] or {"bandits"}
                local attacker = attackers[math.random(#attackers)]

                -- Calculate damage (10-50 base, reduced by defense)
                local baseDamage = 10 + math.random(40)
                local defense = claim.defenseRating
                local actualDamage = math.max(5, baseDamage - defense)

                -- Apply damage
                claim.damageLevel = math.min(100, claim.damageLevel + actualDamage)

                -- Log attack
                table.insert(claim.attackLog, {
                    day = daysPassed,
                    attacker = attacker,
                    damage = actualDamage,
                })
                claim.lastAttack = daysPassed

                table.insert(attacks, {
                    location = key,
                    x = claim.x,
                    y = claim.y,
                    attacker = attacker,
                    damage = actualDamage,
                    totalDamage = claim.damageLevel,
                })

                -- Check if destroyed
                if claim.damageLevel >= 100 then
                    claim.structure = nil
                    claim.maxResidents = 0
                    claim.defenseRating = 0
                    claim.residents = {}
                end
            end
        end
    end

    return attacks
end

-- Collect daily income from business properties
function PropertySystem.collectDailyIncome(daysPassed)
    syncGoldFromPlayerData()
    local totalIncome = 0
    local incomeBreakdown = {}

    for key, prop in pairs(state.player.properties.townProperties) do
        if prop.propertyType == "business" then
            local propDef = PropertySystem.BUSINESS_PROPERTIES[prop.buildingId]
            local income = 0

            -- Base income from employees
            for _, emp in ipairs(prop.employees) do
                -- Each employee generates some base income
                income = income + 10 * (emp.efficiency or 1)
            end

            -- Store income
            prop.dailyIncome = math.floor(income)
            totalIncome = totalIncome + prop.dailyIncome

            if prop.dailyIncome > 0 then
                table.insert(incomeBreakdown, {
                    property = propDef.name,
                    town = prop.townId,
                    income = prop.dailyIncome,
                })
            end
        end
    end

    -- Add income to player
    state.player.gold = state.player.gold + totalIncome
    syncGoldToPlayerData()

    return totalIncome, incomeBreakdown
end

-- Deduct daily property taxes
function PropertySystem.deductPropertyTaxes(daysPassed)
    syncGoldFromPlayerData()
    local totalTax = 0
    local taxBreakdown = {}

    for key, prop in pairs(state.player.properties.townProperties) do
        local propDef = PropertySystem.getPropertyDef(prop.buildingId)
        if propDef and propDef.dailyTax then
            -- Validate tax is non-negative
            local tax = propDef.dailyTax
            if tax < 0 then
                tax = 0  -- Invalid tax rate, set to 0
            end
            totalTax = totalTax + tax
            table.insert(taxBreakdown, {
                property = propDef.name,
                town = prop.townId,
                tax = tax,
            })
        end
    end

    -- Deduct tax (minimum gold is 0)
    state.player.gold = math.max(0, state.player.gold - totalTax)
    syncGoldToPlayerData()

    return totalTax, taxBreakdown
end

-- Deduct daily wages for business employees
function PropertySystem.deductEmployeeWages(daysPassed)
    syncGoldFromPlayerData()
    local totalWages = 0
    local wageBreakdown = {}

    for key, prop in pairs(state.player.properties.townProperties) do
        if prop.propertyType == "business" and prop.employees then
            local propertyWages = 0
            for _, emp in ipairs(prop.employees) do
                if emp.isHired and not emp.isDead then
                    local wage = emp.dailyWage or 10  -- Default wage if not set
                    -- Validate wage is non-negative
                    if wage < 0 then
                        wage = 0
                        emp.dailyWage = 0  -- Fix corrupted wage value
                    end
                    propertyWages = propertyWages + wage
                end
            end

            if propertyWages > 0 then
                totalWages = totalWages + propertyWages
                local propDef = PropertySystem.BUSINESS_PROPERTIES[prop.buildingId]
                table.insert(wageBreakdown, {
                    property = propDef and propDef.name or prop.buildingId,
                    town = prop.townId,
                    wages = propertyWages,
                    employeeCount = #prop.employees,
                })
            end
        end
    end

    -- Deduct wages (minimum gold is 0)
    -- If can't afford, employees become unhappy but still work
    if state.player.gold >= totalWages then
        state.player.gold = state.player.gold - totalWages
        syncGoldToPlayerData()
    else
        -- Partial payment or no payment - reduce employee morale
        local paid = state.player.gold
        state.player.gold = 0
        syncGoldToPlayerData()
        -- Mark employees as unpaid (reduces efficiency next day)
        for key, prop in pairs(state.player.properties.townProperties) do
            if prop.employees then
                for _, emp in ipairs(prop.employees) do
                    emp.unpaidDays = (emp.unpaidDays or 0) + 1
                end
            end
        end
    end

    return totalWages, wageBreakdown
end

-- Main daily update function (call from onNewDay)
function PropertySystem.onDayAdvance(daysPassed, hoursElapsed)
    hoursElapsed = hoursElapsed or 24

    -- Update construction
    PropertySystem.updateConstruction(hoursElapsed)

    -- Simulate attacks
    local attacks = PropertySystem.simulateAttacks(daysPassed)

    -- Collect income, pay wages, and pay taxes
    local income, incomeBreakdown = PropertySystem.collectDailyIncome(daysPassed)
    local wages, wageBreakdown = PropertySystem.deductEmployeeWages(daysPassed)
    local taxes, taxBreakdown = PropertySystem.deductPropertyTaxes(daysPassed)

    -- Update farm plots (delegated to FarmingSystem)
    for key, claim in pairs(state.player.properties.landClaims) do
        if claim.farmPlots then
            PropertySystem.updateFarmPlots(key, hoursElapsed)
        end
        -- Update processing (delegated to ResourceProcessing)
        if claim.processing then
            PropertySystem.updateProcessing(key, hoursElapsed)
        end
        -- Update settlement construction (delegated to SettlementExpansion)
        if claim.settlementGrid then
            PropertySystem.updateSettlementConstruction(key, hoursElapsed)
        end
    end

    return {
        attacks = attacks,
        income = income,
        incomeBreakdown = incomeBreakdown,
        wages = wages,
        wageBreakdown = wageBreakdown,
        taxes = taxes,
        taxBreakdown = taxBreakdown,
        netIncome = income - wages - taxes,
    }
end

-- ============================================================================
--                      REPAIR FUNCTIONS
-- ============================================================================

-- Get repair cost for damaged structure
function PropertySystem.getRepairCost(claimKey)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim then
        return 0
    end

    if claim.damageLevel == 0 then
        return 0
    end

    -- Base cost per damage point
    local costPerDamage = 10
    return math.floor(claim.damageLevel * costPerDamage)
end

-- Repair a damaged structure
function PropertySystem.repairStructure(claimKey)
    syncGoldFromPlayerData()
    local claim = state.player.properties.landClaims[claimKey]
    if not claim then
        return false, "No claim found"
    end

    if claim.damageLevel == 0 then
        return false, "No damage to repair"
    end

    local cost = PropertySystem.getRepairCost(claimKey)
    if state.player.gold < cost then
        return false, "Not enough gold (need " .. cost .. "g)"
    end

    state.player.gold = state.player.gold - cost
    syncGoldToPlayerData()
    claim.damageLevel = 0

    return true, "Repairs complete for " .. cost .. "g"
end

-- ============================================================================
--                      SAVE/LOAD HELPERS
-- ============================================================================

function PropertySystem.getSaveData()
    if not state or not state.player then
        return nil
    end
    return state.player.properties
end

function PropertySystem.loadSaveData(data)
    if state and state.player and data then
        state.player.properties = data
    end
end

-- ============================================================================
--          DELEGATED FUNCTIONS: FARMING SYSTEM (farming_system.lua)
-- ============================================================================

function PropertySystem.initializeFarm(claimKey, gridSize)
    return FarmingSystem.initializeFarm(state, claimKey, gridSize)
end

function PropertySystem.expandFarm(claimKey, newSize)
    return FarmingSystem.expandFarm(state, claimKey, newSize)
end

function PropertySystem.plantSeed(claimKey, plotIndex, seedId)
    return FarmingSystem.plantSeed(state, claimKey, plotIndex, seedId)
end

function PropertySystem.waterPlot(claimKey, plotIndex)
    return FarmingSystem.waterPlot(state, claimKey, plotIndex)
end

function PropertySystem.waterAllPlots(claimKey)
    return FarmingSystem.waterAllPlots(state, claimKey)
end

function PropertySystem.harvestPlot(claimKey, plotIndex)
    return FarmingSystem.harvestPlot(state, claimKey, plotIndex)
end

function PropertySystem.clearPlot(claimKey, plotIndex)
    return FarmingSystem.clearPlot(state, claimKey, plotIndex)
end

function PropertySystem.fertilizePlot(claimKey, plotIndex)
    return FarmingSystem.fertilizePlot(state, claimKey, plotIndex)
end

function PropertySystem.updateFarmPlots(claimKey, hoursElapsed)
    return FarmingSystem.updateFarmPlots(state, claimKey, hoursElapsed)
end

-- ============================================================================
--      DELEGATED FUNCTIONS: RESOURCE PROCESSING (resource_processing.lua)
-- ============================================================================

function PropertySystem.hasLumberTool()
    return ResourceProcessing.hasLumberTool()
end

function PropertySystem.getBestLumberTool()
    return ResourceProcessing.getBestLumberTool()
end

function PropertySystem.getForestLumber(tileX, tileY)
    return ResourceProcessing.getForestLumber(state, tileX, tileY)
end

function PropertySystem.chopLumber(tileX, tileY)
    return ResourceProcessing.chopLumber(state, tileX, tileY)
end

function PropertySystem.processLumber(amount)
    return ResourceProcessing.processLumber(amount)
end

function PropertySystem.regenerateForests(WorldGen)
    return ResourceProcessing.regenerateForests(state, WorldGen)
end

function PropertySystem.settlementLumberConsumption(WorldGen)
    return ResourceProcessing.settlementLumberConsumption(state, WorldGen)
end

function PropertySystem.startProcessing(claimKey, improvementType, recipeId)
    return ResourceProcessing.startProcessing(state, claimKey, improvementType, recipeId)
end

function PropertySystem.processRecipe(claimKey, improvementType, recipe)
    return ResourceProcessing.processRecipe(state, claimKey, improvementType, recipe)
end

function PropertySystem.collectProcessed(claimKey, improvementType)
    return ResourceProcessing.collectProcessed(state, claimKey, improvementType)
end

function PropertySystem.updateProcessing(claimKey, hoursElapsed)
    return ResourceProcessing.updateProcessing(state, claimKey, hoursElapsed)
end

-- ============================================================================
--      DELEGATED FUNCTIONS: SETTLEMENT EXPANSION (settlement_expansion.lua)
-- ============================================================================

function PropertySystem.initializeSettlementGrid(claimKey, gridWidth, gridHeight)
    return SettlementExpansion.initializeSettlementGrid(state, PropertySystem, claimKey, gridWidth, gridHeight)
end

function PropertySystem.generateSettlementTerrain(claimKey, terrainType, region)
    return SettlementExpansion.generateSettlementTerrain(state, PropertySystem, claimKey, terrainType, region)
end

function PropertySystem.generateRiver(grid, gridW, gridH)
    return SettlementExpansion.generateRiver(grid, gridW, gridH)
end

function PropertySystem.generateLake(grid, gridW, gridH)
    return SettlementExpansion.generateLake(grid, gridW, gridH)
end

function PropertySystem.clearTerrain(claimKey, x, y)
    return SettlementExpansion.clearTerrain(state, PropertySystem, claimKey, x, y)
end

function PropertySystem.getTile(grid, x, y)
    return SettlementExpansion.getTile(grid, x, y)
end

function PropertySystem.isTileEmpty(grid, x, y)
    return SettlementExpansion.isTileEmpty(grid, x, y)
end

function PropertySystem.validateBuildingPlacement(grid, x, y, footprint, buildingType)
    return SettlementExpansion.validateBuildingPlacement(state, PropertySystem, grid, x, y, footprint, buildingType)
end

function PropertySystem.placeBuilding(claimKey, buildingType, x, y, tier)
    return SettlementExpansion.placeBuilding(state, PropertySystem, claimKey, buildingType, x, y, tier)
end

function PropertySystem.placeWallSegment(claimKey, x, y, side, wallType)
    return SettlementExpansion.placeWallSegment(state, PropertySystem, claimKey, x, y, side, wallType)
end

function PropertySystem.upgradeBuilding(claimKey, buildingId)
    return SettlementExpansion.upgradeBuilding(state, PropertySystem, claimKey, buildingId)
end

function PropertySystem.demolishBuilding(claimKey, buildingId)
    return SettlementExpansion.demolishBuilding(state, PropertySystem, claimKey, buildingId)
end

function PropertySystem.updateSettlementConstruction(claimKey, hoursElapsed)
    return SettlementExpansion.updateSettlementConstruction(state, PropertySystem, claimKey, hoursElapsed)
end

function PropertySystem.upgradeWallSegment(claimKey, x, y, side)
    return SettlementExpansion.upgradeWallSegment(state, PropertySystem, claimKey, x, y, side)
end

function PropertySystem.getOwnedPlotCount()
    return SettlementExpansion.getOwnedPlotCount(state)
end

function PropertySystem.getSettlementPlotCount(settlementId)
    return SettlementExpansion.getSettlementPlotCount(state, settlementId)
end

function PropertySystem.getPermitCostForSettlement(settlementId)
    return SettlementExpansion.getPermitCostForSettlement(state, settlementId)
end

function PropertySystem.getPermitCost(settlementId)
    return SettlementExpansion.getPermitCost(state, settlementId)
end

function PropertySystem.hasExpansionPermit()
    return SettlementExpansion.hasExpansionPermit(state)
end

function PropertySystem.purchaseExpansionPermit(settlementId)
    return SettlementExpansion.purchaseExpansionPermit(state, settlementId)
end

function PropertySystem.getExpansionDetailsForTile(x, y)
    return SettlementExpansion.getExpansionDetailsForTile(state, PropertySystem, x, y)
end

function PropertySystem.canClaimAdjacent(x, y)
    return SettlementExpansion.canClaimAdjacent(state, x, y)
end

function PropertySystem.findSettlementForClaim(claimKey)
    return SettlementExpansion.findSettlementForClaim(state, claimKey)
end

function PropertySystem.getSettlementBounds(settlementId)
    return SettlementExpansion.getSettlementBounds(state, settlementId)
end

function PropertySystem.resizeSettlementGrid(claimKey, direction)
    return SettlementExpansion.resizeSettlementGrid(state, claimKey, direction)
end

function PropertySystem.isFirstExpansionFree(settlementId)
    return SettlementExpansion.isFirstExpansionFree(state, settlementId)
end

function PropertySystem.expandSettlement(newX, newY)
    return SettlementExpansion.expandSettlement(state, PropertySystem, newX, newY)
end

function PropertySystem.getExpansionInfo()
    return SettlementExpansion.getExpansionInfo(state, PropertySystem)
end

function PropertySystem.migrateSettlementsToMultiPlot()
    return SettlementExpansion.migrateSettlementsToMultiPlot(state)
end

function PropertySystem.claimLandWithExpansion(x, y)
    syncGoldFromPlayerData()
    -- Check if this tile is adjacent to an existing claim
    local isAdj, _, adjacentKey = PropertySystem.canClaimAdjacent(x, y)

    if isAdj then
        -- This is an expansion of an existing settlement
        return PropertySystem.expandSettlement(x, y)
    else
        -- Non-adjacent claim: this creates a new independent settlement
        -- Always allowed (no permit needed for initial claims)
        return PropertySystem.claimLand(x, y)
    end
end

function PropertySystem.migrateOldClaims()
    return SettlementExpansion.migrateOldClaims(state, PropertySystem)
end

return PropertySystem
