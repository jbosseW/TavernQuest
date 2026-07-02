-- Backpack/Inventory System
-- Shared inventory across all game modes

local Backpack = {}
local UIAssets = require("uiassets")
local UI = require("ui")

-- === OPTIMIZATION: Initialization and weight caching ===
local _initialized = false  -- Track if Backpack.init() has run

-- Weight cache to avoid recalculating every frame
local _weightCache = {
    totalWeight = nil,      -- Cached total weight
    dirty = true,           -- True when cache needs recalculation
    lastMight = nil,        -- Last Might value used for capacity
    totalCapacity = nil,    -- Cached total capacity
    capacityDirty = true,   -- True when capacity cache needs recalculation
}

-- Invalidate weight cache (call when inventory changes)
local function invalidateWeightCache()
    _weightCache.dirty = true
end

-- Invalidate capacity cache (call when beast/cart changes)
local function invalidateCapacityCache()
    _weightCache.capacityDirty = true
end

-- Invalidate all caches
local function invalidateAllCaches()
    _weightCache.dirty = true
    _weightCache.capacityDirty = true
end

-- Item categories
Backpack.CATEGORIES = {
    "all", "consumable", "food", "material", "ore", "weapon", "armor", "spell", "potion", "poison", "treasure", "special", "tool", "trap", "tome", "ammo", "throwable", "trophy", "transport", "seed"
}

-- ========== WEIGHT/ENCUMBRANCE SYSTEM ==========

-- Default weights by category (in pounds)
Backpack.DEFAULT_WEIGHTS = {
    consumable = 0.5,
    material = 1.0,
    weapon = 3.0,
    armor = 8.0,
    spell = 0.2,
    potion = 0.5,
    treasure = 0.5,
    special = 1.0,
    trap = 2.0,
    transport = 0,  -- Carts don't count against carry weight
    seed = 0.1,     -- Seeds are very light
}

-- Encumbrance thresholds (percentage of max capacity)
Backpack.ENCUMBRANCE = {
    LIGHT = 0.50,      -- 0-50%: No penalty
    MEDIUM = 0.75,     -- 50-75%: -25% speed
    HEAVY = 1.00,      -- 75-100%: -50% speed, can't run from combat
    OVERENCUMBERED = 1.25,  -- 100-125%: -75% speed, combat penalties
    -- Above 125%: Cannot move
}

-- Speed multipliers for encumbrance levels
Backpack.ENCUMBRANCE_SPEED = {
    light = 1.0,
    medium = 0.75,
    heavy = 0.50,
    overencumbered = 0.25,
    immobile = 0,
}

-- Cart definitions
Backpack.CARTS = {
    {id = "handcart", name = "Handcart", carryCapacity = 50, requiresBeast = false,
     price = 100, speedPenalty = 0.15, desc = "A small cart you can push yourself"},
    {id = "small_wagon", name = "Small Wagon", carryCapacity = 150, requiresBeast = true,
     price = 300, speedPenalty = 0.10, desc = "Requires a beast of burden to pull"},
    {id = "large_wagon", name = "Large Wagon", carryCapacity = 400, requiresBeast = true,
     price = 800, speedPenalty = 0.20, desc = "Heavy wagon for serious hauling"},
    {id = "merchant_caravan", name = "Merchant Caravan", carryCapacity = 800, requiresBeast = true,
     price = 2000, speedPenalty = 0.30, desc = "Massive caravan for trade expeditions"},
}

-- Beast of burden definitions (supplement the pet system)
Backpack.BEASTS_OF_BURDEN = {
    {id = "donkey", name = "Donkey", carryCapacity = 80, price = 150,
     hungerRate = 0.4, staminaRate = 0.3, speed = 0.8, canPullCart = true,
     desc = "Reliable and hardy pack animal"},
    {id = "mule", name = "Mule", carryCapacity = 120, price = 300,
     hungerRate = 0.5, staminaRate = 0.4, speed = 0.9, canPullCart = true,
     desc = "Strong and sure-footed"},
    {id = "ox", name = "Ox", carryCapacity = 200, price = 500,
     hungerRate = 0.7, staminaRate = 0.5, speed = 0.6, canPullCart = true,
     desc = "Powerful draft animal, slow but strong"},
    {id = "pack_horse", name = "Pack Horse", carryCapacity = 150, price = 400,
     hungerRate = 0.6, staminaRate = 0.6, speed = 1.0, canPullCart = true,
     desc = "Fast and can carry decent weight"},
    {id = "camel", name = "Camel", carryCapacity = 180, price = 600,
     hungerRate = 0.2, staminaRate = 0.2, speed = 0.85, canPullCart = false,
     desc = "Excellent endurance, needs less water/food"},
    {id = "elephant", name = "War Elephant", carryCapacity = 500, price = 3000,
     hungerRate = 1.0, staminaRate = 0.8, speed = 0.7, canPullCart = false,
     desc = "Massive carrying capacity, intimidating"},
}

-- Item definitions
Backpack.ITEMS = {
    -- Consumables (from fishing, hunting, cafe)
    {id = "health_potion", name = "Health Potion", category = "consumable", icon = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_13_heal_potion.PNG", stackable = true, maxStack = 99, desc = "Restores health", weight = 0.5},
    {id = "mana_potion", name = "Mana Potion", category = "consumable", icon = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_17_blue_potion.PNG", stackable = true, maxStack = 99, desc = "Restores mana", weight = 0.5},
    {id = "stamina_potion", name = "Stamina Potion", category = "consumable", icon = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_24_energy_potion.PNG", stackable = true, maxStack = 99, desc = "Restores stamina", weight = 0.5},
    {id = "lucky_charm", name = "Lucky Charm", category = "consumable", icon = "assets/icons/loot/Loot_147_jewelry.PNG", stackable = true, maxStack = 10, desc = "+10% luck for 5 spins", weight = 0.1},

    -- Fish (from fishing)
    {id = "common_fish", name = "Common Fish", category = "material", icon = "assets/icons/resourcesandfood/Res_140_fish.PNG", stackable = true, maxStack = 99, desc = "A common fish", sellValue = 5, weight = 1.0},
    {id = "rare_fish", name = "Rare Fish", category = "material", icon = "assets/icons/resourcesandfood/FishBlueFried.PNG", stackable = true, maxStack = 99, desc = "A rare catch", sellValue = 25, weight = 2.0},
    {id = "legendary_fish", name = "Legendary Fish", category = "material", icon = "assets/icons/resourcesandfood/FishRedFried.PNG", stackable = true, maxStack = 99, desc = "A legendary fish!", sellValue = 100, weight = 5.0},

    -- Hunt loot (from hunting)
    {id = "leather", name = "Leather", category = "material", icon = "assets/icons/loot/Loot_112_leather.PNG", stackable = true, maxStack = 99, desc = "Basic crafting material", sellValue = 10, weight = 1.0},
    {id = "meat", name = "Raw Meat", category = "material", icon = "assets/icons/resourcesandfood/FriedChickenLeg.PNG", stackable = true, maxStack = 99, desc = "Can be cooked", sellValue = 8, weight = 2.0},
    {id = "fur", name = "Fine Fur", category = "material", icon = "assets/icons/loot/Loot_113_leather.PNG", stackable = true, maxStack = 99, desc = "Valuable fur", sellValue = 30, weight = 1.5},
    {id = "antler", name = "Antler", category = "material", icon = "assets/icons/loot/Loot_155_horn.PNG", stackable = true, maxStack = 99, desc = "Trophy material", sellValue = 50, weight = 3.0},

    -- Treasures (from various modes)
    {id = "gold_coin", name = "Ancient Gold Coin", category = "treasure", icon = "assets/icons/loot/Loot_01_coins.PNG", stackable = true, maxStack = 999, desc = "Worth 50 coins", sellValue = 50, weight = 0.02},
    {id = "gem_ruby", name = "Ruby", category = "treasure", icon = "assets/icons/resourcesandfood/Res_25_crystal.PNG", stackable = true, maxStack = 99, desc = "A precious gem", sellValue = 100, weight = 0.1},
    {id = "gem_sapphire", name = "Sapphire", category = "treasure", icon = "assets/icons/resourcesandfood/Res_76_crystalRed.PNG", stackable = true, maxStack = 99, desc = "A blue gem", sellValue = 100, weight = 0.1},
    {id = "gem_emerald", name = "Emerald", category = "treasure", icon = "assets/icons/resourcesandfood/Res_75_crystalS.PNG", stackable = true, maxStack = 99, desc = "A green gem", sellValue = 100, weight = 0.1},

    -- Special items
    {id = "lucky_dice", name = "Lucky Dice", category = "special", icon = "assets/icons/loot/Loot_148_sots.PNG", stackable = false, desc = "Increases luck permanently"},
    {id = "xp_boost", name = "XP Tome", category = "special", icon = "assets/icons/resourcesandfood/Book.PNG", stackable = true, maxStack = 10, desc = "Grants 500 XP when used"},
    {id = "mystery_box", name = "Mystery Box", category = "special", icon = "assets/icons/loot/Loot_101_chest.PNG", stackable = true, maxStack = 10, desc = "Contains random rewards"},

    -- ========== PRISON ESCAPE MATERIALS ==========
    {id = "bone_fragment", name = "Bone Fragment", category = "material", stackable = true, maxStack = 99, desc = "A sharpened piece of bone scavenged from the prison.", sellValue = 1, weight = 0.3},
    {id = "scrap_metal", name = "Scrap Metal", category = "material", stackable = true, maxStack = 99, desc = "A bent piece of rusted metal from the prison.", sellValue = 2, weight = 1.0},
    {id = "cloth_strip", name = "Cloth Strip", category = "material", stackable = true, maxStack = 99, desc = "A torn strip of prison uniform.", sellValue = 1, weight = 0.1},
    {id = "wire_coil", name = "Wire Coil", category = "material", stackable = true, maxStack = 99, desc = "A short coil of copper wire.", sellValue = 2, weight = 0.2},
    {id = "wood_scrap", name = "Wood Scrap", category = "material", stackable = true, maxStack = 99, desc = "A piece of broken furniture.", sellValue = 1, weight = 0.5},
    {id = "prison_crystal_shard", name = "Crystal Shard", category = "material", stackable = true, maxStack = 99, desc = "A faintly glowing crystal fragment found in the prison depths.", sellValue = 15, weight = 0.2},
    {id = "stone_chunk", name = "Stone Chunk", category = "material", stackable = true, maxStack = 99, desc = "A small piece of hewn stone.", sellValue = 1, weight = 0.8},
    {id = "guard_weapon_parts", name = "Guard Weapon Parts", category = "material", stackable = true, maxStack = 99, desc = "Salvaged from a prison guard's equipment.", sellValue = 10, weight = 2.0},
    {id = "stale_bread", name = "Stale Bread", category = "consumable", stackable = true, maxStack = 99, desc = "Rock-hard prison bread. Barely edible. Restores 5 HP.", sellValue = 1, weight = 0.3},
    {id = "dirty_water", name = "Dirty Water", category = "consumable", stackable = true, maxStack = 99, desc = "Murky water from a dripping pipe. Restores 3 HP.", sellValue = 0, weight = 0.5},
    {id = "rusty_key", name = "Rusty Key", category = "special", stackable = true, maxStack = 10, desc = "An old key. Might fit something in the prison.", sellValue = 5, weight = 0.1},
    {id = "prisoner_note", name = "Prisoner's Note", category = "special", stackable = true, maxStack = 99, desc = "A scrawled note left by a previous inmate.", sellValue = 0, weight = 0.0},

    -- ========== PRISON CRAFTED WEAPONS ==========
    {id = "bone_shank", name = "Bone Shank", category = "weapon", stackable = false, desc = "A sharpened bone fragment. Crude but deadly.", sellValue = 3, weight = 0.5, baseStats = {damage = 3}},
    {id = "prison_shiv", name = "Prison Shiv", category = "weapon", stackable = false, desc = "A thin metal spike wrapped in cloth.", sellValue = 5, weight = 0.3, baseStats = {damage = 5}},
    {id = "makeshift_club", name = "Makeshift Club", category = "weapon", stackable = false, desc = "A broken chair leg reinforced with wire.", sellValue = 4, weight = 2.0, baseStats = {damage = 7}},
    {id = "makeshift_magic_focus", name = "Makeshift Magic Focus", category = "weapon", stackable = false, desc = "A crude focus allowing basic spellcasting.", sellValue = 8, weight = 0.5, baseStats = {damage = 4}},
    {id = "sling_shot", name = "Improvised Sling", category = "weapon", stackable = false, desc = "A strip of leather and some pebbles.", sellValue = 3, weight = 0.4, baseStats = {damage = 4}},
    {id = "guard_sword", name = "Guard's Short Sword", category = "weapon", stackable = false, desc = "A standard-issue prison guard blade.", sellValue = 30, weight = 3.0, baseStats = {damage = 12}},
    {id = "lockpick_set", name = "Improvised Lockpick", category = "special", stackable = true, maxStack = 10, desc = "Bent wire fashioned into a passable lockpick.", sellValue = 5, weight = 0.1},
    {id = "bandage_crude", name = "Crude Bandage", category = "consumable", stackable = true, maxStack = 20, desc = "Torn cloth strips. Restores 15 HP.", sellValue = 2, weight = 0.2},
    {id = "makeshift_armor", name = "Makeshift Armor", category = "armor", stackable = false, desc = "Scrap metal plates tied with wire. Better than nothing.", sellValue = 12, weight = 8.0, baseStats = {defense = 6}},

    -- ========== FORGE MATERIALS ==========
    {id = "iron_ore", name = "Iron Ore", category = "material", icon = "assets/icons/resources/Res_62_iron_ore.PNG", stackable = true, maxStack = 99, desc = "Raw iron ore for smelting", sellValue = 10},
    {id = "steel_ingot", name = "Steel Ingot", category = "material", icon = "assets/icons/resources/Res_71_iron_bar.PNG", stackable = true, maxStack = 99, desc = "Refined steel for crafting", sellValue = 25},
    {id = "mythril_shard", name = "Mythril Shard", category = "material", icon = "assets/icons/resources/Gem_05.png", stackable = true, maxStack = 99, desc = "Rare magical metal", sellValue = 100},
    {id = "dragon_scale", name = "Dragon Scale", category = "material", icon = "assets/icons/resources/Res_69_scale.PNG", stackable = true, maxStack = 99, desc = "Nearly indestructible", sellValue = 200},
    {id = "leather_scraps", name = "Leather Scraps", category = "material", icon = "assets/icons/resources/Res_68_cloth.PNG", stackable = true, maxStack = 99, desc = "For armor and grips", sellValue = 8},
    {id = "wood_planks", name = "Wood Planks", category = "material", icon = "assets/icons/resources/Res_67_coal.PNG", stackable = true, maxStack = 99, desc = "Basic crafting material", sellValue = 5},
    {id = "raw_lumber", name = "Raw Lumber", category = "material", icon = "assets/icons/resources/Res_67_coal.PNG", stackable = true, maxStack = 99, desc = "Unprocessed wood logs", sellValue = 3},
    {id = "stone", name = "Stone", category = "material", icon = "assets/icons/resources/Res_63_stones.PNG", stackable = true, maxStack = 99, desc = "Building material", sellValue = 2},
    {id = "coal", name = "Coal", category = "material", icon = "assets/icons/resources/Res_67_coal.PNG", stackable = true, maxStack = 99, desc = "Fuel for the forge", sellValue = 5},
    {id = "rope", name = "Rope", category = "material", icon = "assets/icons/resources/Res_68_cloth.PNG", stackable = true, maxStack = 99, desc = "Sturdy rope for construction and fishing", sellValue = 8},

    -- ========== TOOLS ==========
    {id = "woodcutter_axe", name = "Woodcutter's Axe", category = "tool", icon = "assets/icons/weapons/Axe_01.PNG", stackable = false, desc = "For chopping trees. Gathers 2-4 lumber per swing.", sellValue = 25, toolType = "lumber", efficiency = 1.0},
    {id = "iron_saw", name = "Iron Saw", category = "tool", icon = "assets/icons/weapons/Dagger_01.PNG", stackable = false, desc = "For cutting wood. Gathers 1-3 lumber per use.", sellValue = 35, toolType = "lumber", efficiency = 0.8},
    {id = "steel_lumber_axe", name = "Steel Lumber Axe", category = "tool", icon = "assets/icons/weapons/Axe_01.PNG", stackable = false, desc = "Quality axe. Gathers 3-6 lumber per swing.", sellValue = 75, toolType = "lumber", efficiency = 1.5},
    {id = "pickaxe", name = "Pickaxe", category = "tool", icon = "assets/icons/weapons/Mace_01.PNG", stackable = false, desc = "For mining stone and ore.", sellValue = 30, toolType = "mining", efficiency = 1.0},
    {id = "steel_pickaxe", name = "Steel Pickaxe", category = "tool", icon = "assets/icons/weapons/Mace_01.PNG", stackable = false, desc = "Quality pickaxe for mining.", sellValue = 80, toolType = "mining", efficiency = 1.5},

    -- ========== WIZARD MATERIALS ==========
    {id = "mana_crystal", name = "Mana Crystal", category = "material", icon = "assets/icons/resourcesandfood/Res_167_MageCrystal.PNG", stackable = true, maxStack = 99, desc = "Crystallized magical energy", sellValue = 30},
    {id = "fire_essence", name = "Fire Essence", category = "material", icon = "assets/icons/resourcesandfood/Res_76_crystalRed.PNG", stackable = true, maxStack = 99, desc = "Captured flame energy", sellValue = 20},
    {id = "frost_essence", name = "Frost Essence", category = "material", icon = "assets/icons/resourcesandfood/Res_25_crystal.PNG", stackable = true, maxStack = 99, desc = "Frozen magical core", sellValue = 20},
    {id = "arcane_dust", name = "Arcane Dust", category = "material", icon = "assets/icons/resourcesandfood/Res_75_crystalS.PNG", stackable = true, maxStack = 99, desc = "Powdered magic residue", sellValue = 15},
    {id = "ancient_scroll", name = "Ancient Scroll", category = "material", icon = "assets/icons/quest/Quest_17_scroll.PNG", stackable = true, maxStack = 99, desc = "Contains old knowledge", sellValue = 50},
    {id = "enchanted_ink", name = "Enchanted Ink", category = "material", icon = "assets/icons/resourcesandfood/BlackInk.PNG", stackable = true, maxStack = 99, desc = "For writing spells", sellValue = 25},

    -- ========== ALCHEMY MATERIALS ==========
    {id = "healing_herb", name = "Healing Herb", category = "material", icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_01_herbs.PNG", stackable = true, maxStack = 99, desc = "Common medicinal plant", sellValue = 5},
    {id = "moonflower", name = "Moonflower", category = "material", icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_05_flower.PNG", stackable = true, maxStack = 99, desc = "Blooms under moonlight", sellValue = 15},
    {id = "venom_sac", name = "Venom Sac", category = "material", icon = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_05_poison.PNG", stackable = true, maxStack = 99, desc = "Extracted from creatures", sellValue = 20},
    {id = "troll_blood", name = "Troll Blood", category = "material", icon = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_06_blood.PNG", stackable = true, maxStack = 99, desc = "Has regenerative properties", sellValue = 35},
    {id = "phoenix_feather", name = "Phoenix Feather", category = "material", icon = "assets/icons/loot/Loot_157_ribbon.PNG", stackable = true, maxStack = 99, desc = "Extremely rare, burns with magic", sellValue = 150},
    {id = "empty_vial", name = "Empty Vial", category = "material", icon = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_19_little_flask.PNG", stackable = true, maxStack = 99, desc = "Container for potions", sellValue = 2},

    -- ========== FORGE CRAFTED - WEAPONS ==========
    {id = "iron_sword", name = "Iron Sword", category = "weapon", icon = "assets/icons/weapons/Sword_01.PNG", stackable = false, desc = "Basic iron sword", sellValue = 50, baseStats = {damage = 10}, weight = 3.0},
    {id = "steel_sword", name = "Steel Sword", category = "weapon", icon = "assets/icons/weapons/Sword_05.PNG", stackable = false, desc = "Strong steel blade", sellValue = 120, baseStats = {damage = 18}, weight = 4.0},
    {id = "steel_axe", name = "Steel Axe", category = "weapon", icon = "assets/icons/weapons/Axe_01.PNG", stackable = false, desc = "Heavy battle axe", sellValue = 100, baseStats = {damage = 22}, weight = 6.0},
    {id = "mythril_blade", name = "Mythril Blade", category = "weapon", icon = "assets/icons/weapons/Sword_15.PNG", stackable = false, desc = "Magical mythril weapon", sellValue = 300, baseStats = {damage = 35}, weight = 2.0},
    {id = "iron_dagger", name = "Iron Dagger", category = "weapon", icon = "assets/icons/weapons/Dagger_01.PNG", stackable = false, desc = "Quick stabbing weapon", sellValue = 35, baseStats = {damage = 8}, weight = 1.0},

    -- ========== FORGE CRAFTED - ARMOR ==========
    {id = "leather_armor", name = "Leather Armor", category = "armor", icon = "assets/icons/armor/LeatherChest1.PNG", stackable = false, desc = "Light protective armor", sellValue = 40, baseStats = {defense = 5}, weight = 8.0},
    {id = "chainmail", name = "Chainmail", category = "armor", icon = "assets/icons/armor/MailChest.PNG", stackable = false, desc = "Linked metal rings", sellValue = 100, baseStats = {defense = 12}, weight = 20.0},
    {id = "plate_armor", name = "Plate Armor", category = "armor", icon = "assets/icons/armor/PlateMailChest.PNG", stackable = false, desc = "Heavy metal plates", sellValue = 250, baseStats = {defense = 25}, weight = 45.0},
    {id = "iron_helmet", name = "Iron Helmet", category = "armor", icon = "assets/icons/armor/MetalHelmet.PNG", stackable = false, desc = "Protects your head", sellValue = 45, baseStats = {defense = 4}, weight = 4.0},
    {id = "steel_shield", name = "Steel Shield", category = "armor", icon = "assets/icons/weapons/Shield_01.PNG", stackable = false, desc = "Blocks incoming attacks", sellValue = 80, baseStats = {defense = 8, blockChance = 15}, weight = 8.0},

    -- ========== FORGE CRAFTED - TRAPS ==========
    {id = "spike_trap", name = "Spike Trap", category = "trap", icon = "assets/icons/loot/Loot_152_trap.PNG", stackable = true, maxStack = 10, desc = "Damages enemies who step on it", sellValue = 30, baseStats = {damage = 15}},
    {id = "bear_trap", name = "Bear Trap", category = "trap", icon = "assets/icons/loot/Loot_152_trap.PNG", stackable = true, maxStack = 10, desc = "Immobilizes targets", sellValue = 50, baseStats = {damage = 10, stunDuration = 3}},

    -- ========== WIZARD CRAFTED - SPELLS ==========
    {id = "fire_spell", name = "Fireball Scroll", category = "spell", icon = "assets/icons/quest/Quest_143_spellscroll.PNG", stackable = true, maxStack = 10, desc = "Launches a ball of fire", sellValue = 60, baseStats = {damage = 25, manaCost = 10}},
    {id = "frost_spell", name = "Frost Bolt Scroll", category = "spell", icon = "assets/icons/quest/Quest_144_spellscroll.PNG", stackable = true, maxStack = 10, desc = "Chilling ice projectile", sellValue = 55, baseStats = {damage = 18, manaCost = 8, slowEffect = 20}},
    {id = "heal_spell", name = "Healing Light Scroll", category = "spell", icon = "assets/icons/quest/Quest_145_spellscroll.PNG", stackable = true, maxStack = 10, desc = "Restores health", sellValue = 70, baseStats = {healing = 30, manaCost = 15}},
    {id = "shield_spell", name = "Arcane Shield Scroll", category = "spell", icon = "assets/icons/quest/Quest_42_scrollSpell.PNG", stackable = true, maxStack = 10, desc = "Creates magical barrier", sellValue = 65, baseStats = {defense = 20, manaCost = 12, duration = 30}},
    {id = "lightning_spell", name = "Lightning Bolt Scroll", category = "spell", icon = "assets/icons/quest/Quest_40_scroll.PNG", stackable = true, maxStack = 10, desc = "Electric shock attack", sellValue = 75, baseStats = {damage = 30, manaCost = 14}},

    -- ========== WIZARD CRAFTED - TOMES ==========
    {id = "tome_power", name = "Tome of Power", category = "tome", icon = "assets/icons/resourcesandfood/Book.PNG", stackable = false, desc = "Permanently increases damage", sellValue = 150, baseStats = {bonusDamage = 5}},
    {id = "tome_wisdom", name = "Tome of Wisdom", category = "tome", icon = "assets/icons/resourcesandfood/Book2.PNG", stackable = false, desc = "Permanently increases mana", sellValue = 150, baseStats = {bonusMana = 20}},
    {id = "tome_protection", name = "Tome of Protection", category = "tome", icon = "assets/icons/resourcesandfood/Book.PNG", stackable = false, desc = "Permanently increases defense", sellValue = 150, baseStats = {bonusDefense = 5}},

    -- ========== ALCHEMY CRAFTED - POTIONS ==========
    {id = "health_potion_crafted", name = "Crafted Health Potion", category = "potion", icon = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_31_bigheal_flask.PNG", stackable = true, maxStack = 20, desc = "Restores health instantly", sellValue = 25, baseStats = {healing = 50}},
    {id = "mana_potion_crafted", name = "Crafted Mana Potion", category = "potion", icon = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_30_bigmana_flask.PNG", stackable = true, maxStack = 20, desc = "Restores mana instantly", sellValue = 25, baseStats = {manaRestore = 30}},
    {id = "strength_potion", name = "Strength Potion", category = "potion", icon = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_15_reactive_potion.PNG", stackable = true, maxStack = 20, desc = "Temporarily boosts damage", sellValue = 40, baseStats = {bonusDamage = 10, duration = 60}},
    {id = "speed_potion", name = "Speed Potion", category = "potion", icon = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_24_energy_potion.PNG", stackable = true, maxStack = 20, desc = "Increases movement speed", sellValue = 35, baseStats = {bonusSpeed = 25, duration = 45}},
    {id = "defense_potion", name = "Iron Skin Potion", category = "potion", icon = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_25_stamina_potion.PNG", stackable = true, maxStack = 20, desc = "Hardens your skin", sellValue = 45, baseStats = {bonusDefense = 15, duration = 60}},
    {id = "regen_potion", name = "Regeneration Potion", category = "potion", icon = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_12_magic_potion.PNG", stackable = true, maxStack = 20, desc = "Heals over time", sellValue = 50, baseStats = {healPerSecond = 3, duration = 30}},

    -- ========== HUNTING ITEMS ==========
    {id = "arrows", name = "Arrows", category = "ammo", icon = "assets/icons/weapons/Arrow_01.PNG", stackable = true, maxStack = 99, desc = "Basic hunting arrows", sellValue = 2},
    {id = "arrows_steel", name = "Steel Arrows", category = "ammo", icon = "assets/icons/weapons/Arrow_05.PNG", stackable = true, maxStack = 99, desc = "Stronger hunting arrows", sellValue = 5},
    {id = "raw_meat", name = "Raw Meat", category = "food", icon = "assets/icons/resourcesandfood/FriedChickenLeg.PNG", stackable = true, maxStack = 50, desc = "Fresh meat from hunting", sellValue = 8},
    {id = "small_hide", name = "Small Hide", category = "material", icon = "assets/icons/loot/Loot_112_leather.PNG", stackable = true, maxStack = 50, desc = "Hide from small game", sellValue = 10},
    {id = "fine_fur", name = "Fine Fur", category = "material", icon = "assets/icons/loot/Loot_113_leather.PNG", stackable = true, maxStack = 50, desc = "Soft fur from foxes", sellValue = 30},
    {id = "feathers", name = "Feathers", category = "material", icon = "assets/icons/loot/Loot_157_ribbon.PNG", stackable = true, maxStack = 99, desc = "Bird feathers", sellValue = 5},
    {id = "deer_hide", name = "Deer Hide", category = "material", icon = "assets/icons/loot/Loot_114_leather.PNG", stackable = true, maxStack = 30, desc = "Quality deer hide", sellValue = 25},
    {id = "boar_hide", name = "Boar Hide", category = "material", icon = "assets/icons/loot/Loot_114_leather.PNG", stackable = true, maxStack = 30, desc = "Tough boar hide", sellValue = 28},
    {id = "wolf_pelt", name = "Wolf Pelt", category = "material", icon = "assets/icons/resources/Res_68_cloth.PNG", stackable = true, maxStack = 20, desc = "Wolf pelt for crafting", sellValue = 40},
    {id = "elk_hide", name = "Elk Hide", category = "material", icon = "assets/icons/resources/Res_68_cloth.PNG", stackable = true, maxStack = 20, desc = "Large elk hide", sellValue = 50},
    {id = "bear_pelt", name = "Bear Pelt", category = "material", icon = "assets/icons/resources/Res_68_cloth.PNG", stackable = true, maxStack = 10, desc = "Massive bear pelt", sellValue = 80},
    {id = "antlers", name = "Antlers", category = "trophy", icon = "assets/icons/loot/Bone.png", stackable = true, maxStack = 20, desc = "Deer or elk antlers", sellValue = 50},
    {id = "tusks", name = "Tusks", category = "trophy", icon = "assets/icons/loot/Bone.png", stackable = true, maxStack = 20, desc = "Boar tusks", sellValue = 35},
    {id = "claws", name = "Claws", category = "trophy", icon = "assets/icons/loot/Bone.png", stackable = true, maxStack = 30, desc = "Animal claws", sellValue = 25},
    {id = "bear_fat", name = "Bear Fat", category = "material", icon = "assets/icons/loot/Bottle.png", stackable = true, maxStack = 20, desc = "Rendered bear fat", sellValue = 30},
    {id = "legendary_hide", name = "Legendary Hide", category = "rare", icon = "assets/icons/resources/Res_69_scale.PNG", stackable = true, maxStack = 5, desc = "Legendary creature hide", sellValue = 200},
    {id = "legendary_pelt", name = "Legendary Pelt", category = "rare", icon = "assets/icons/resources/Res_69_scale.PNG", stackable = true, maxStack = 5, desc = "Legendary creature pelt", sellValue = 300},
    {id = "mystical_antlers", name = "Mystical Antlers", category = "rare", icon = "assets/icons/loot/Bone.png", stackable = true, maxStack = 3, desc = "Antlers with magical properties", sellValue = 500},
    {id = "great_claws", name = "Great Claws", category = "rare", icon = "assets/icons/loot/Bone.png", stackable = true, maxStack = 3, desc = "Massive legendary claws", sellValue = 400},
    {id = "bait", name = "Animal Bait", category = "consumable", icon = "assets/icons/loot/MeatRaw.png", stackable = true, maxStack = 20, desc = "Attracts animals", sellValue = 15},

    -- ========== ALCHEMY CRAFTED - POISONS ==========
    {id = "weak_poison", name = "Weak Poison", category = "poison", icon = "assets/icons/loot/PotionGreen.png", stackable = true, maxStack = 20, desc = "Apply to weapons for damage", sellValue = 20, baseStats = {dotDamage = 3, duration = 10}},
    {id = "paralyze_poison", name = "Paralyzing Poison", category = "poison", icon = "assets/icons/loot/PotionPurple.png", stackable = true, maxStack = 20, desc = "Chance to stun enemies", sellValue = 60, baseStats = {stunChance = 30, duration = 5}},
    {id = "deadly_poison", name = "Deadly Poison", category = "poison", icon = "assets/icons/loot/PotionBlack.png", stackable = true, maxStack = 20, desc = "Powerful damage over time", sellValue = 80, baseStats = {dotDamage = 8, duration = 15}},

    -- ========== FARMING - SEEDS ==========
    -- Vegetable Seeds (Fast-growing staples)
    {id = "goldgrain_seed", name = "Goldgrain Seeds", category = "seed", stackable = true, maxStack = 99, sellValue = 5,
     desc = "Plant in spring or summer. Grows in 2 days. Staple grain crop.", weight = 0.1,
     icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_01_herbs.PNG",
     growthDays = 2, seasons = {"brightbloom", "sunreign"}, harvestItem = "goldgrain", harvestMin = 1, harvestMax = 3, baseRarity = "common"},

    {id = "crimsonbulb_seed", name = "Crimson Bulb Seeds", category = "seed", stackable = true, maxStack = 99, sellValue = 10,
     desc = "Plant in summer. Grows in 3 days. Juicy red fruit-vegetable.", weight = 0.1,
     icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_02_herbs.PNG",
     growthDays = 3, seasons = {"sunreign"}, harvestItem = "crimsonbulb", harvestMin = 2, harvestMax = 4, baseRarity = "common"},

    {id = "earthroot_seed", name = "Earthroot Seeds", category = "seed", stackable = true, maxStack = 99, sellValue = 8,
     desc = "Plant in spring or fall. Grows in 2 days. Hardy underground tuber.", weight = 0.1,
     icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_03_herbs.PNG",
     growthDays = 2, seasons = {"brightbloom", "ashwane"}, harvestItem = "earthroot", harvestMin = 2, harvestMax = 5, baseRarity = "common"},

    -- Herb Seeds (Potion ingredients)
    {id = "healing_herb_seed", name = "Healing Herb Seeds", category = "seed", stackable = true, maxStack = 99, sellValue = 15,
     desc = "Plant in spring, summer, or fall. Grows in 3 days.", weight = 0.1,
     icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_04_herbs.PNG",
     growthDays = 3, seasons = {"brightbloom", "sunreign", "ashwane"}, harvestItem = "healing_herb", harvestMin = 1, harvestMax = 2, baseRarity = "uncommon"},

    {id = "moonflower_seed", name = "Moonflower Seeds", category = "seed", stackable = true, maxStack = 99, sellValue = 25,
     desc = "Plant in fall or winter. Grows in 4 days.", weight = 0.1,
     icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_05_herbs.PNG",
     growthDays = 4, seasons = {"ashwane", "frosthollow"}, harvestItem = "moonflower", harvestMin = 1, harvestMax = 2, baseRarity = "rare"},

    -- Magical Plant Seeds (High value, rare)
    {id = "fire_blossom_seed", name = "Fire Blossom Seeds", category = "seed", stackable = true, maxStack = 99, sellValue = 50,
     desc = "Plant in summer only. Grows in 5 days. Produces fire essence.", weight = 0.1,
     icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_07_herbs.PNG",
     growthDays = 5, seasons = {"sunreign"}, harvestItem = "fire_essence", harvestMin = 1, harvestMax = 1, baseRarity = "rare"},

    {id = "frost_root_seed", name = "Frost Root Seeds", category = "seed", stackable = true, maxStack = 99, sellValue = 50,
     desc = "Plant in winter only. Grows in 5 days. Produces frost essence.", weight = 0.1,
     icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_08_herbs.PNG",
     growthDays = 5, seasons = {"frosthollow"}, harvestItem = "frost_essence", harvestMin = 1, harvestMax = 1, baseRarity = "rare"},

    {id = "mana_berry_seed", name = "Mana Berry Seeds", category = "seed", stackable = true, maxStack = 99, sellValue = 40,
     desc = "Plant in spring or fall. Grows in 6 days. Produces mana crystals.", weight = 0.1,
     icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_09_herbs.PNG",
     growthDays = 6, seasons = {"brightbloom", "ashwane"}, harvestItem = "mana_crystal", harvestMin = 1, harvestMax = 2, baseRarity = "epic"},

    -- More Vegetable Seeds
    {id = "spearoot_seed", name = "Spearoot Seeds", category = "seed", stackable = true, maxStack = 99, sellValue = 7,
     desc = "Plant in spring or fall. Grows in 2 days. Orange pointed root vegetable.", weight = 0.1,
     icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_10_herbs.PNG",
     growthDays = 2, seasons = {"brightbloom", "ashwane"}, harvestItem = "spearoot", harvestMin = 2, harvestMax = 4, baseRarity = "common"},

    {id = "leafhead_seed", name = "Leafhead Seeds", category = "seed", stackable = true, maxStack = 99, sellValue = 9,
     desc = "Plant in spring or fall. Grows in 3 days. Layered green vegetable.", weight = 0.1,
     icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_11_herbs.PNG",
     growthDays = 3, seasons = {"brightbloom", "ashwane"}, harvestItem = "leafhead", harvestMin = 1, harvestMax = 2, baseRarity = "common"},

    {id = "firebell_seed", name = "Firebell Seeds", category = "seed", stackable = true, maxStack = 99, sellValue = 12,
     desc = "Plant in summer. Grows in 3 days. Spicy bell-shaped pod.", weight = 0.1,
     icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_12_herbs.PNG",
     growthDays = 3, seasons = {"sunreign"}, harvestItem = "firebell", harvestMin = 2, harvestMax = 5, baseRarity = "common"},

    {id = "tearbulb_seed", name = "Tearbulb Seeds", category = "seed", stackable = true, maxStack = 99, sellValue = 6,
     desc = "Plant in spring, summer, or fall. Grows in 2 days. Makes you cry when cut!", weight = 0.1,
     icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_13_herbs.PNG",
     growthDays = 2, seasons = {"brightbloom", "sunreign", "ashwane"}, harvestItem = "tearbulb", harvestMin = 1, harvestMax = 3, baseRarity = "common"},

    {id = "harvestgourd_seed", name = "Harvest Gourd Seeds", category = "seed", stackable = true, maxStack = 99, sellValue = 20,
     desc = "Plant in fall. Grows in 4 days. Large orange gourd perfect for pies!", weight = 0.1,
     icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_14_herbs.PNG",
     growthDays = 4, seasons = {"ashwane"}, harvestItem = "harvestgourd", harvestMin = 1, harvestMax = 2, baseRarity = "uncommon"},

    {id = "goldcob_seed", name = "Goldcob Seeds", category = "seed", stackable = true, maxStack = 99, sellValue = 15,
     desc = "Plant in summer. Grows in 4 days. Tall grain with golden kernels.", weight = 0.1,
     icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_15_herbs.PNG",
     growthDays = 4, seasons = {"sunreign"}, harvestItem = "goldcob", harvestMin = 2, harvestMax = 4, baseRarity = "common"},

    -- Fruit Seeds (valuable, good for processing)
    {id = "crimsonstar_seed", name = "Crimson Star Seeds", category = "seed", stackable = true, maxStack = 99, sellValue = 25,
     desc = "Plant in spring. Grows in 3 days. Sweet red berries shaped like stars!", weight = 0.1,
     icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_16_herbs.PNG",
     growthDays = 3, seasons = {"brightbloom"}, harvestItem = "crimsonstar", harvestMin = 3, harvestMax = 6, baseRarity = "uncommon"},

    {id = "skyberry_seed", name = "Skyberry Seeds", category = "seed", stackable = true, maxStack = 99, sellValue = 30,
     desc = "Plant in summer. Grows in 4 days. Blue berries from the heavens!", weight = 0.1,
     icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_17_herbs.PNG",
     growthDays = 4, seasons = {"sunreign"}, harvestItem = "skyberry", harvestMin = 4, harvestMax = 8, baseRarity = "uncommon"},

    {id = "vinecluster_seed", name = "Vinecluster Seeds", category = "seed", stackable = true, maxStack = 99, sellValue = 35,
     desc = "Plant in summer or fall. Grows in 5 days. Purple clusters perfect for wine!", weight = 0.1,
     icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_18_herbs.PNG",
     growthDays = 5, seasons = {"sunreign", "ashwane"}, harvestItem = "vinecluster", harvestMin = 5, harvestMax = 10, baseRarity = "uncommon"},

    {id = "dewmelon_seed", name = "Dewmelon Seeds", category = "seed", stackable = true, maxStack = 99, sellValue = 40,
     desc = "Plant in summer. Grows in 5 days. Large fruit covered in morning dew!", weight = 0.1,
     icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_19_herbs.PNG",
     growthDays = 5, seasons = {"sunreign"}, harvestItem = "dewmelon", harvestMin = 1, harvestMax = 2, baseRarity = "uncommon"},

    -- Flower Seeds (decorative, some for potions)
    {id = "solbloom_seed", name = "Solbloom Seeds", category = "seed", stackable = true, maxStack = 99, sellValue = 18,
     desc = "Plant in summer. Grows in 3 days. Follows the sun across the sky!", weight = 0.1,
     icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_20_herbs.PNG",
     growthDays = 3, seasons = {"sunreign"}, harvestItem = "solbloom", harvestMin = 1, harvestMax = 2, baseRarity = "common"},

    {id = "mistflower_seed", name = "Mistflower Seeds", category = "seed", stackable = true, maxStack = 99, sellValue = 22,
     desc = "Plant in spring or summer. Grows in 3 days. Purple fragrant flowers.", weight = 0.1,
     icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_21_herbs.PNG",
     growthDays = 3, seasons = {"brightbloom", "sunreign"}, harvestItem = "mistflower", harvestMin = 2, harvestMax = 4, baseRarity = "uncommon"},

    -- ========== FARMING - HARVESTED CROPS ==========
    -- Vegetables
    {id = "goldgrain", name = "Goldgrain", category = "material", stackable = true, maxStack = 99, sellValue = 8,
     desc = "Golden stalks of grain. Used for bread and brewing.", weight = 0.2,
     icon = "assets/icons/resourcesandfood/Grain.png"},

    {id = "crimsonbulb", name = "Crimson Bulb", category = "consumable", stackable = true, maxStack = 99, sellValue = 15,
     desc = "Juicy red bulb. Restores some health.", weight = 0.5,
     icon = "assets/icons/resourcesandfood/Apple.png",
     baseStats = {healing = 15}},

    {id = "earthroot", name = "Earthroot", category = "consumable", stackable = true, maxStack = 99, sellValue = 12,
     desc = "Hardy tuber from the earth. Filling and nutritious.", weight = 0.5,
     icon = "assets/icons/resourcesandfood/Apple.png",
     baseStats = {healing = 12}},

    {id = "spearoot", name = "Spearoot", category = "consumable", stackable = true, maxStack = 99, sellValue = 10,
     desc = "Pointed orange root. Crunchy and sweet!", weight = 0.3,
     icon = "assets/icons/resourcesandfood/Apple.png",
     baseStats = {healing = 10}},

    {id = "leafhead", name = "Leafhead", category = "consumable", stackable = true, maxStack = 99, sellValue = 14,
     desc = "Layered green vegetable. Makes excellent preserves!", weight = 0.8,
     icon = "assets/icons/resourcesandfood/Apple.png",
     baseStats = {healing = 18}},

    {id = "firebell", name = "Firebell", category = "consumable", stackable = true, maxStack = 99, sellValue = 16,
     desc = "Spicy red pod. Wakes you right up!", weight = 0.2,
     icon = "assets/icons/resourcesandfood/Apple.png",
     baseStats = {healing = 12}},

    {id = "tearbulb", name = "Tearbulb", category = "consumable", stackable = true, maxStack = 99, sellValue = 8,
     desc = "Layered bulb that makes you cry. Essential cooking ingredient.", weight = 0.3,
     icon = "assets/icons/resourcesandfood/Apple.png",
     baseStats = {healing = 8}},

    {id = "harvestgourd", name = "Harvest Gourd", category = "consumable", stackable = true, maxStack = 99, sellValue = 35,
     desc = "Large orange gourd. Perfect for pies and soups!", weight = 2.0,
     icon = "assets/icons/resourcesandfood/Apple.png",
     baseStats = {healing = 30}},

    {id = "goldcob", name = "Goldcob", category = "consumable", stackable = true, maxStack = 99, sellValue = 18,
     desc = "Golden grain cob. Sweet and filling!", weight = 0.4,
     icon = "assets/icons/resourcesandfood/Apple.png",
     baseStats = {healing = 14}},

    -- Fruits
    {id = "crimsonstar", name = "Crimson Star", category = "consumable", stackable = true, maxStack = 99, sellValue = 20,
     desc = "Sweet red berries shaped like tiny stars. Perfect for preserves!", weight = 0.1,
     icon = "assets/icons/resourcesandfood/Apple.png",
     baseStats = {healing = 10}},

    {id = "skyberry", name = "Skyberry", category = "consumable", stackable = true, maxStack = 99, sellValue = 25,
     desc = "Brilliant blue berries. Rich and flavorful!", weight = 0.1,
     icon = "assets/icons/resourcesandfood/Apple.png",
     baseStats = {healing = 12}},

    {id = "vinecluster", name = "Vinecluster", category = "consumable", stackable = true, maxStack = 99, sellValue = 30,
     desc = "Purple clusters of sweet fruit. Makes the finest wines!", weight = 0.1,
     icon = "assets/icons/resourcesandfood/Apple.png",
     baseStats = {healing = 8}},

    {id = "dewmelon", name = "Dewmelon", category = "consumable", stackable = true, maxStack = 99, sellValue = 50,
     desc = "Massive fruit covered in sweet dew. Incredibly refreshing!", weight = 1.5,
     icon = "assets/icons/resourcesandfood/Apple.png",
     baseStats = {healing = 40}},

    -- Flowers
    {id = "solbloom", name = "Solbloom", category = "material", stackable = true, maxStack = 99, sellValue = 25,
     desc = "Bright golden flower that follows the sun. Used for oils and dyes.", weight = 0.3,
     icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_01_herbs.PNG"},

    {id = "mistflower", name = "Mistflower", category = "material", stackable = true, maxStack = 99, sellValue = 30,
     desc = "Fragrant purple flowers that bloom in the mist. Used in perfumes and potions.", weight = 0.1,
     icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_05_herbs.PNG"},

    -- ========== FARMING - PROCESSED GOODS ==========
    -- Pickled Vegetables (2x value, longer shelf life)
    {id = "preserved_crimsonbulb", name = "Preserved Crimson Bulbs", category = "consumable", stackable = true, maxStack = 50, sellValue = 35,
     desc = "Crimson bulbs preserved in brine. Lasts forever!", weight = 0.6,
     icon = "assets/icons/loot/Bottle.png",
     baseStats = {healing = 25}},

    {id = "preserved_leafhead", name = "Preserved Leafhead", category = "consumable", stackable = true, maxStack = 50, sellValue = 32,
     desc = "Tangy fermented leafhead. Traditional delicacy!", weight = 0.9,
     icon = "assets/icons/loot/Bottle.png",
     baseStats = {healing = 30}},

    {id = "preserved_firebell", name = "Preserved Firebells", category = "consumable", stackable = true, maxStack = 50, sellValue = 38,
     desc = "Spicy preserved pods. Burns twice as much!", weight = 0.3,
     icon = "assets/icons/loot/Bottle.png",
     baseStats = {healing = 20}},

    {id = "preserved_spearoot", name = "Preserved Spearoots", category = "consumable", stackable = true, maxStack = 50, sellValue = 24,
     desc = "Crisp preserved spearoots. Sweet and crunchy!", weight = 0.4,
     icon = "assets/icons/loot/Bottle.png",
     baseStats = {healing = 18}},

    -- Jams (3x value, high sell price)
    {id = "crimsonstar_jam", name = "Crimson Star Jam", category = "consumable", stackable = true, maxStack = 20, sellValue = 80,
     desc = "Sweet jam made from crimson star berries. Heavenly!", weight = 0.5,
     icon = "assets/icons/loot/PotionRed.png",
     baseStats = {healing = 35}},

    {id = "skyberry_jam", name = "Skyberry Jam", category = "consumable", stackable = true, maxStack = 20, sellValue = 95,
     desc = "Rich blue jam from skyberries. Premium quality!", weight = 0.5,
     icon = "assets/icons/loot/PotionPurple.png",
     baseStats = {healing = 40}},

    {id = "vinecluster_jam", name = "Vinecluster Jam", category = "consumable", stackable = true, maxStack = 20, sellValue = 110,
     desc = "Luxurious purple jam from vineclusters. Exquisite!", weight = 0.5,
     icon = "assets/icons/loot/PotionPurple.png",
     baseStats = {healing = 45}},

    -- Wine (4-5x value, takes time to age)
    {id = "crimsonstar_wine", name = "Crimson Star Wine", category = "consumable", stackable = true, maxStack = 12, sellValue = 120,
     desc = "Light fruit wine from crimson stars. Refreshing and sweet!", weight = 0.8,
     icon = "assets/icons/loot/PotionRed.png",
     baseStats = {healing = 30, manaRestore = 15}},

    {id = "skyberry_wine", name = "Skyberry Wine", category = "consumable", stackable = true, maxStack = 12, sellValue = 150,
     desc = "Deep blue wine from skyberries. Rich and mysterious!", weight = 0.8,
     icon = "assets/icons/loot/PotionPurple.png",
     baseStats = {healing = 35, manaRestore = 20}},

    {id = "vinecluster_wine", name = "Vinecluster Wine", category = "consumable", stackable = true, maxStack = 12, sellValue = 200,
     desc = "Classic wine from vineclusters. Premium vintage!", weight = 0.8,
     icon = "assets/icons/loot/PotionPurple.png",
     baseStats = {healing = 40, manaRestore = 25}},

    {id = "dewmelon_wine", name = "Dewmelon Wine", category = "consumable", stackable = true, maxStack = 12, sellValue = 250,
     desc = "Exotic wine from dewmelons. Rare and incredibly valuable!", weight = 0.8,
     icon = "assets/icons/loot/PotionGreen.png",
     baseStats = {healing = 50, manaRestore = 30}},

    -- Baked Goods
    {id = "goldgrain_bread", name = "Goldgrain Bread", category = "consumable", stackable = true, maxStack = 20, sellValue = 25,
     desc = "Fresh baked bread from goldgrain. Warm and filling!", weight = 0.5,
     icon = "assets/icons/resourcesandfood/Bread.png",
     baseStats = {healing = 35}},

    {id = "harvestgourd_pie", name = "Harvest Gourd Pie", category = "consumable", stackable = true, maxStack = 10, sellValue = 120,
     desc = "Delicious pie made from harvest gourds. Seasonal favorite!", weight = 1.0,
     icon = "assets/icons/resourcesandfood/Bread.png",
     baseStats = {healing = 80}},

    {id = "goldcob_bread", name = "Goldcob Bread", category = "consumable", stackable = true, maxStack = 20, sellValue = 35,
     desc = "Savory bread made from goldcobs. Hearty and golden!", weight = 0.6,
     icon = "assets/icons/resourcesandfood/Bread.png",
     baseStats = {healing = 45}},

    -- Juice
    {id = "crimsonbulb_juice", name = "Crimson Bulb Juice", category = "consumable", stackable = true, maxStack = 20, sellValue = 30,
     desc = "Fresh-pressed juice from crimson bulbs. Refreshing!", weight = 0.5,
     icon = "assets/icons/loot/PotionRed.png",
     baseStats = {healing = 25, manaRestore = 10}},

    {id = "dewmelon_juice", name = "Dewmelon Juice", category = "consumable", stackable = true, maxStack = 20, sellValue = 85,
     desc = "Sweet juice from dewmelons. Incredibly hydrating!", weight = 0.5,
     icon = "assets/icons/loot/PotionGreen.png",
     baseStats = {healing = 45, manaRestore = 20}},

    -- ========== FARMING - FERTILIZER ==========
    {id = "fertilizer", name = "Fertilizer", category = "special", stackable = true, maxStack = 99, sellValue = 10,
     desc = "Apply to plot before planting for better harvests.", weight = 0.5,
     icon = "assets/icons/resourcesandfood/Grain.png"},

    -- ========== HOLLOW EARTH ITEMS ==========
    -- Magic Amplifiers & Light Sources
    {id = "core_crystal", name = "Core Crystal", category = "rare", icon = "assets/icons/loot/Gem_10_diamond.png", stackable = true, maxStack = 10, desc = "Glowing crystal from hollow earth core. Amplifies magical power.", sellValue = 250, baseStats = {spellDamage = 15, manaRegen = 5}},
    {id = "bioluminescent_fungi", name = "Bioluminescent Fungi", category = "material", icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_06_fungus.PNG", stackable = true, maxStack = 99, desc = "Glowing mushrooms from fungal forests. Light source and alchemy ingredient.", sellValue = 35, baseStats = {lightRadius = 10}},

    -- Armor Materials
    {id = "dinosaur_scale", name = "Dinosaur Scale", category = "material", icon = "assets/icons/resources/Res_69_scale.PNG", stackable = true, maxStack = 30, desc = "Massive scale from hollow earth saurian. Exceptional armor material.", sellValue = 120, baseStats = {defense = 3}},

    -- Metals & Ores
    {id = "voidsteel_ore", name = "Voidsteel Ore", category = "ore", icon = "assets/icons/loot/Ore_05_black.png", stackable = true, maxStack = 50, desc = "Dark metal ore from deep dwarven mines. Absorbs light.", sellValue = 150},
    {id = "coregold_ingot", name = "Coregold Ingot", category = "material", icon = "assets/icons/resources/Res_03_goldbar.PNG", stackable = true, maxStack = 30, desc = "Gold from earth's core. Never tarnishes, eternal shine.", sellValue = 300},
    {id = "depthiron_bar", name = "Depthiron Bar", category = "material", icon = "assets/icons/loot/Ore_04_iron.png", stackable = true, maxStack = 40, desc = "Strongest metal known. Forged under immense pressure.", sellValue = 180},

    -- Weapons & Combat Items
    {id = "saurian_bone_weapon", name = "Saurian Bone Blade", category = "weapon", icon = "assets/icons/weapons/Sword_45.PNG", stackable = false, desc = "Weapon carved from ancient saurian bones. Incredibly sharp.", sellValue = 450, baseStats = {damage = 42, critBonus = 15}, weight = 3.5},
    {id = "spore_bomb", name = "Spore Bomb", category = "throwable", icon = "assets/icons/loot/Loot_155_bomb.PNG", stackable = true, maxStack = 20, desc = "Myconid spore cluster. Explodes in cloud of paralyzing spores.", sellValue = 90, baseStats = {damage = 25, stunChance = 40, area = 3}},

    -- Rare Hollow Earth Materials
    {id = "void_essence", name = "Void Essence", category = "rare", icon = "assets/icons/loot/PotionBlack.png", stackable = true, maxStack = 5, desc = "Extracted from storm caverns. Reality warps near it.", sellValue = 500, baseStats = {spellDamage = 25, manaCost = -5}},
    {id = "crystal_shard", name = "Harmonic Crystal Shard", category = "rare", icon = "assets/icons/loot/Gem_15_amethyst.png", stackable = true, maxStack = 10, desc = "Singing crystal from crystal caverns. Resonates with magic.", sellValue = 200, baseStats = {spellDamage = 10, manaRegen = 8}},
    {id = "bone_dust", name = "Ancient Bone Dust", category = "material", icon = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_17_white_powder.PNG", stackable = true, maxStack = 99, desc = "Pulverized bones from the Bone Wastes. Necromantic potential.", sellValue = 75, baseStats = {necroBonus = 5}},
    {id = "deep_water", name = "Deep Sea Water", category = "material", icon = "assets/icons/loot/PotionBlue.png", stackable = true, maxStack = 50, desc = "Water from subterranean seas. Never touched by sunlight.", sellValue = 40, baseStats = {healing = 15}},

    -- Hollow Earth Armor
    {id = "voidsteel_armor", name = "Voidsteel Plate", category = "armor", icon = "assets/icons/armor/PlateMailChest.PNG", stackable = false, desc = "Forged from voidsteel by deep dwarves. Absorbs damage.", sellValue = 800, baseStats = {defense = 35, damageReduction = 10}, weight = 40.0},
    {id = "saurian_scale_armor", name = "Saurian Scale Mail", category = "armor", icon = "assets/icons/armor/ScaleChest.PNG", stackable = false, desc = "Armor made from dinosaur scales. Light but incredibly tough.", sellValue = 650, baseStats = {defense = 28, dodgeBonus = 5}, weight = 18.0},
    {id = "mycelium_cloak", name = "Mycelium Cloak", category = "armor", icon = "assets/icons/armor/Cloth_01.PNG", stackable = false, desc = "Living fungal cloak. Regenerates wearer slowly.", sellValue = 500, baseStats = {defense = 12, healthRegen = 3}, weight = 3.0},

    -- Hollow Earth Consumables
    {id = "glowcap_potion", name = "Glowcap Extract", category = "potion", icon = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_28_fluorgreen_potion.PNG", stackable = true, maxStack = 20, desc = "Distilled bioluminescent fungi. Grants darkvision.", sellValue = 100, baseStats = {darkvision = 120, duration = 300}},
    {id = "depthiron_tonic", name = "Depthiron Tonic", category = "potion", icon = "assets/icons/loot/PotionGrey.png", stackable = true, maxStack = 20, desc = "Infused with depthiron essence. Hardens skin like metal.", sellValue = 120, baseStats = {bonusDefense = 25, duration = 90}},

    -- ========== TAVERN QUEST WEAPONS ==========
    -- Starter/Basic weapons (no requirements)
    {id = "tq_rusty_sword", name = "Rusty Sword", category = "tq_weapon", icon = "assets/icons/weapons/Sword_01.PNG", stackable = false, desc = "A worn but serviceable blade", sellValue = 10, baseStats = {attack = 3}},
    {id = "tq_iron_sword", name = "Iron Sword", category = "tq_weapon", icon = "assets/icons/weapons/Sword_05.PNG", stackable = false, desc = "Standard iron sword", sellValue = 50, baseStats = {attack = 8, MIGHT = 1}},

    -- Melee weapons (Warrior/Cleric)
    {id = "tq_steel_sword", name = "Steel Sword", category = "tq_weapon", icon = "assets/icons/weapons/Sword_15.PNG", stackable = false, desc = "Quality steel blade (+2 Might)", sellValue = 150, baseStats = {attack = 15, MIGHT = 2}, requirements = {classes = {"warrior", "cleric"}, MIGHT = 12}},
    {id = "tq_battle_axe", name = "Battle Axe", category = "tq_weapon", icon = "assets/icons/weapons/Sword_25.PNG", stackable = false, desc = "Heavy two-handed axe (+3 Might, +5% crit)", sellValue = 200, baseStats = {attack = 18, MIGHT = 3, critBonus = 5}, requirements = {classes = {"warrior"}, MIGHT = 14}},
    {id = "tq_holy_mace", name = "Holy Mace", category = "tq_weapon", icon = "assets/icons/weapons/Sword_30.PNG", stackable = false, desc = "Blessed weapon (+2 Spirit)", sellValue = 180, baseStats = {attack = 12, SPIRIT = 2, healBonus = 5}, requirements = {classes = {"cleric"}, SPIRIT = 12}},

    -- Rogue weapons
    {id = "tq_dagger", name = "Assassin's Dagger", category = "tq_weapon", icon = "assets/icons/weapons/Sword_10.PNG", stackable = false, desc = "Quick and deadly (+2 Agility, +10% crit)", sellValue = 120, baseStats = {attack = 10, AGILITY = 2, critBonus = 10}, requirements = {classes = {"rogue"}, AGILITY = 12}},
    {id = "tq_poisoned_blade", name = "Poisoned Blade", category = "tq_weapon", icon = "assets/icons/weapons/Sword_20.PNG", stackable = false, desc = "Coated in venom (+3 Agility)", sellValue = 250, baseStats = {attack = 14, AGILITY = 3, poisonDamage = 5}, requirements = {classes = {"rogue"}, AGILITY = 14}},

    -- Mage weapons
    {id = "tq_apprentice_staff", name = "Apprentice Staff", category = "tq_weapon", icon = "assets/icons/weapons/Sword_35.PNG", stackable = false, desc = "Channels arcane power (+2 Mind)", sellValue = 100, baseStats = {attack = 5, MIND = 2, spellDamage = 5}, requirements = {classes = {"mage"}, MIND = 10}},
    {id = "tq_magic_blade", name = "Magic Blade", category = "tq_weapon", icon = "assets/icons/weapons/Sword_40.PNG", stackable = false, desc = "Enchanted weapon (+3 Mind, +10 spell damage)", sellValue = 400, baseStats = {attack = 25, MIND = 3, spellDamage = 10}, requirements = {classes = {"mage"}, MIND = 14}},

    -- High-tier weapons (all classes but high stats)
    {id = "tq_legendary_sword", name = "Legendary Sword", category = "tq_weapon", icon = "assets/icons/weapons/Sword_65.PNG", stackable = false, desc = "A blade of legend (+4 Might, +10% crit)", sellValue = 1000, baseStats = {attack = 40, MIGHT = 4, critBonus = 10}, requirements = {MIGHT = 16}},

    -- Ranged weapons (Bows - Agility based)
    {id = "tq_shortbow", name = "Shortbow", category = "tq_weapon", weaponType = "bow", icon = "assets/icons/weapons/Sword_35.PNG", stackable = false, desc = "Simple hunting bow (+1 Agility)", sellValue = 60, baseStats = {attack = 7, range = 4, AGILITY = 1}, requirements = {AGILITY = 10}},
    {id = "tq_longbow", name = "Longbow", category = "tq_weapon", weaponType = "bow", icon = "assets/icons/weapons/Sword_40.PNG", stackable = false, desc = "Powerful long-range bow (+2 Agility, +5% crit)", sellValue = 180, baseStats = {attack = 14, range = 6, AGILITY = 2, critBonus = 5}, requirements = {AGILITY = 13}},
    {id = "tq_hunters_bow", name = "Hunter's Bow", category = "tq_weapon", weaponType = "bow", icon = "assets/icons/weapons/Sword_45.PNG", stackable = false, desc = "Masterwork hunting bow (+3 Agility, +8% crit)", sellValue = 320, baseStats = {attack = 18, range = 5, AGILITY = 3, critBonus = 8}, requirements = {classes = {"rogue"}, AGILITY = 14}},
    {id = "tq_elven_bow", name = "Elven Bow", category = "tq_weapon", weaponType = "bow", icon = "assets/icons/weapons/Sword_60.PNG", stackable = false, desc = "Legendary elven craftsmanship (+4 Agility, +12% crit)", sellValue = 850, baseStats = {attack = 28, range = 7, AGILITY = 4, critBonus = 12}, requirements = {AGILITY = 17}},

    -- Ranged weapons (Crossbows - Less Agility, more Might)
    {id = "tq_light_crossbow", name = "Light Crossbow", category = "tq_weapon", weaponType = "crossbow", icon = "assets/icons/weapons/Sword_30.PNG", stackable = false, desc = "Mechanical ranged weapon (+1 Might)", sellValue = 100, baseStats = {attack = 12, range = 5, MIGHT = 1}, requirements = {MIGHT = 10}},
    {id = "tq_heavy_crossbow", name = "Heavy Crossbow", category = "tq_weapon", weaponType = "crossbow", icon = "assets/icons/weapons/Sword_50.PNG", stackable = false, desc = "Powerful siege crossbow (+2 Might, +2 Vigor)", sellValue = 280, baseStats = {attack = 20, range = 6, MIGHT = 2, VIGOR = 2}, requirements = {classes = {"warrior"}, MIGHT = 13}},
    {id = "tq_repeating_crossbow", name = "Repeating Crossbow", category = "tq_weapon", weaponType = "crossbow", icon = "assets/icons/weapons/Sword_55.PNG", stackable = false, desc = "Rapid-fire mechanism (+2 Agility, +1 Might)", sellValue = 450, baseStats = {attack = 16, range = 4, AGILITY = 2, MIGHT = 1, critBonus = 5}, requirements = {AGILITY = 12, MIGHT = 11}},

    -- Throwing weapons (Stackable, consumed on use)
    {id = "tq_throwing_dagger", name = "Throwing Dagger", category = "tq_weapon", weaponType = "thrown", icon = "assets/icons/weapons/Sword_10.PNG", stackable = true, maxStack = 50, desc = "Balanced for throwing (+1 Agility)", sellValue = 15, baseStats = {attack = 6, range = 3, AGILITY = 1}},
    {id = "tq_throwing_axe", name = "Throwing Axe", category = "tq_weapon", weaponType = "thrown", icon = "assets/icons/weapons/Sword_25.PNG", stackable = true, maxStack = 30, desc = "Heavy throwing weapon (+1 Might)", sellValue = 25, baseStats = {attack = 10, range = 3, MIGHT = 1}},
    {id = "tq_shuriken", name = "Shuriken", category = "tq_weapon", weaponType = "thrown", icon = "assets/icons/weapons/Sword_10.PNG", stackable = true, maxStack = 99, desc = "Swift throwing stars (+10% crit)", sellValue = 10, baseStats = {attack = 5, range = 4, critBonus = 10}, requirements = {classes = {"rogue"}}},

    -- Magical ranged weapons (Wands - Mind based)
    {id = "tq_apprentice_wand", name = "Apprentice Wand", category = "tq_weapon", weaponType = "wand", icon = "assets/icons/weapons/Sword_35.PNG", stackable = false, desc = "Focuses magical energy (+2 Mind)", sellValue = 90, baseStats = {attack = 6, range = 5, MIND = 2, spellDamage = 8}, requirements = {classes = {"mage"}, MIND = 10}},
    {id = "tq_arcane_wand", name = "Arcane Wand", category = "tq_weapon", weaponType = "wand", icon = "assets/icons/weapons/Sword_40.PNG", stackable = false, desc = "Channeled arcane power (+3 Mind, +15 spell damage)", sellValue = 380, baseStats = {attack = 12, range = 6, MIND = 3, spellDamage = 15}, requirements = {classes = {"mage"}, MIND = 14}},

    -- ========== TAVERN QUEST ARMOR ==========
    -- Light armor (all classes)
    {id = "tq_cloth_armor", name = "Cloth Armor", category = "tq_armor", icon = "assets/icons/armor/Chest_01_farmer.PNG", stackable = false, desc = "Simple cloth protection", sellValue = 15, baseStats = {defense = 2}},
    {id = "tq_leather_armor", name = "Leather Armor", category = "tq_armor", icon = "assets/icons/armor/Chest_48_leather.PNG", stackable = false, desc = "Sturdy leather armor (+1 Agility)", sellValue = 60, baseStats = {defense = 5, AGILITY = 1}},

    -- Medium armor (Warrior, Cleric, Rogue)
    {id = "tq_chain_mail", name = "Chain Mail", category = "tq_armor", icon = "assets/icons/armor/MailChest.PNG", stackable = false, desc = "Linked metal rings (+2 Vigor)", sellValue = 200, baseStats = {defense = 10, VIGOR = 2}, requirements = {classes = {"warrior", "cleric", "rogue"}}},
    {id = "tq_studded_leather", name = "Studded Leather", category = "tq_armor", icon = "assets/icons/armor/Chest_48_leather.PNG", stackable = false, desc = "Reinforced leather (+2 Agility, +5% dodge)", sellValue = 180, baseStats = {defense = 8, AGILITY = 2, dodgeBonus = 5}, requirements = {classes = {"rogue"}, AGILITY = 12}},

    -- Heavy armor (Warrior, Cleric only)
    {id = "tq_plate_armor", name = "Plate Armor", category = "tq_armor", icon = "assets/icons/armor/PlateMailChest.PNG", stackable = false, desc = "Heavy plate protection (+3 Vigor, +2 Might)", sellValue = 500, baseStats = {defense = 18, VIGOR = 3, MIGHT = 2}, requirements = {classes = {"warrior", "cleric"}, MIGHT = 14}},

    -- Mage robes
    {id = "tq_arcane_robes", name = "Arcane Robes", category = "tq_armor", icon = "assets/icons/armor/Chest_01_farmer.PNG", stackable = false, desc = "Magical attire (+3 Mind, +10 mana)", sellValue = 300, baseStats = {defense = 4, MIND = 3, bonusMana = 10}, requirements = {classes = {"mage"}, MIND = 12}},

    -- Cleric vestments
    {id = "tq_holy_vestments", name = "Holy Vestments", category = "tq_armor", icon = "assets/icons/armor/Chest_01_farmer.PNG", stackable = false, desc = "Blessed garments (+3 Spirit, +10 healing)", sellValue = 280, baseStats = {defense = 6, SPIRIT = 3, healBonus = 10}, requirements = {classes = {"cleric"}, SPIRIT = 12}},

    -- ========== TAVERN QUEST SHIELDS ==========
    {id = "tq_wooden_shield", name = "Wooden Shield", category = "tq_shield", icon = "assets/icons/weapons/Shield_01.PNG", stackable = false, desc = "Basic wooden shield (10% block)", sellValue = 30, baseStats = {defense = 2, blockChance = 10}},
    {id = "tq_iron_shield", name = "Iron Shield", category = "tq_shield", icon = "assets/icons/weapons/Shield_01.PNG", stackable = false, desc = "Standard iron shield (+1 Vigor, 15% block)", sellValue = 120, baseStats = {defense = 5, blockChance = 15, VIGOR = 1}, requirements = {MIGHT = 10}},
    {id = "tq_steel_shield", name = "Steel Shield", category = "tq_shield", icon = "assets/icons/weapons/Shield_01.PNG", stackable = false, desc = "Quality steel shield (+2 Vigor, 20% block)", sellValue = 280, baseStats = {defense = 8, blockChance = 20, VIGOR = 2}, requirements = {classes = {"warrior", "cleric"}, MIGHT = 12}},
    {id = "tq_tower_shield", name = "Tower Shield", category = "tq_shield", icon = "assets/icons/weapons/Shield_01.PNG", stackable = false, desc = "Massive defensive shield (+3 Vigor, 25% block, -1 Agility)", sellValue = 450, baseStats = {defense = 12, blockChance = 25, VIGOR = 3, AGILITY = -1}, requirements = {classes = {"warrior"}, MIGHT = 14}},
    {id = "tq_blessed_shield", name = "Blessed Shield", category = "tq_shield", icon = "assets/icons/weapons/Shield_01.PNG", stackable = false, desc = "Holy protection (+2 Spirit, 18% block, +5 heal bonus)", sellValue = 380, baseStats = {defense = 7, blockChance = 18, SPIRIT = 2, healBonus = 5}, requirements = {classes = {"cleric"}, SPIRIT = 12}},
    {id = "tq_spiked_shield", name = "Spiked Shield", category = "tq_shield", icon = "assets/icons/weapons/Shield_01.PNG", stackable = false, desc = "Offensive shield (15% block, reflects 5 damage)", sellValue = 320, baseStats = {defense = 6, blockChance = 15, reflectDamage = 5, MIGHT = 1}, requirements = {classes = {"warrior"}, MIGHT = 11}},
    {id = "tq_arcane_buckler", name = "Arcane Buckler", category = "tq_shield", icon = "assets/icons/weapons/Shield_01.PNG", stackable = false, desc = "Magic-infused buckler (+2 Mind, 12% block, +5 mana)", sellValue = 350, baseStats = {defense = 4, blockChance = 12, MIND = 2, bonusMana = 5}, requirements = {classes = {"mage"}, MIND = 12}},

    -- ========== TAVERN QUEST POTIONS ==========
    {id = "tq_health_potion", name = "Health Potion", category = "tq_potion", icon = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_13_heal_potion.PNG", stackable = true, maxStack = 99, desc = "Restores 30 HP", sellValue = 25, baseStats = {heal = 30}},
    {id = "tq_mana_potion", name = "Mana Potion", category = "tq_potion", icon = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_17_blue_potion.PNG", stackable = true, maxStack = 99, desc = "Restores 30 Mana", sellValue = 25, baseStats = {mana = 30}},
    {id = "tq_elixir", name = "Elixir", category = "tq_potion", icon = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_12_magic_potion.PNG", stackable = true, maxStack = 50, desc = "Restores 100 HP and 50 Mana", sellValue = 100, baseStats = {heal = 100, mana = 50}},

    -- ========== TAVERN QUEST MATERIALS ==========
    {id = "tq_iron_ore", name = "Iron Ore", category = "tq_material", icon = "assets/icons/resources/Res_62_iron_ore.PNG", stackable = true, maxStack = 99, desc = "Quest material", sellValue = 10},
    {id = "tq_healing_herbs", name = "Healing Herbs", category = "tq_material", icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_01_herbs.PNG", stackable = true, maxStack = 99, desc = "Medicinal plants", sellValue = 8},
    {id = "tq_wolf_pelts", name = "Wolf Pelts", category = "tq_material", icon = "assets/icons/resources/Res_68_cloth.PNG", stackable = true, maxStack = 99, desc = "Fur from wolves", sellValue = 15},
    {id = "tq_spider_silk", name = "Spider Silk", category = "tq_material", icon = "assets/icons/loot/Loot_157_ribbon.PNG", stackable = true, maxStack = 99, desc = "Strong silk threads", sellValue = 20},
    {id = "tq_ancient_tome", name = "Ancient Tome", category = "tq_material", icon = "assets/icons/resourcesandfood/Book.PNG", stackable = true, maxStack = 99, desc = "Old knowledge", sellValue = 50},
    {id = "tq_magic_crystal", name = "Magic Crystal", category = "tq_material", icon = "assets/icons/resourcesandfood/Res_167_MageCrystal.PNG", stackable = true, maxStack = 99, desc = "Crystallized magic", sellValue = 40},
    {id = "tq_rare_mushrooms", name = "Rare Mushrooms", category = "tq_material", icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_09_mushroom.PNG", stackable = true, maxStack = 99, desc = "Exotic fungi", sellValue = 25},
    {id = "tq_dragon_scale", name = "Dragon Scale", category = "tq_material", icon = "assets/icons/resources/Res_69_scale.PNG", stackable = true, maxStack = 50, desc = "Nearly indestructible", sellValue = 200},
    {id = "tq_phoenix_feather", name = "Phoenix Feather", category = "tq_material", icon = "assets/icons/loot/Loot_157_ribbon.PNG", stackable = true, maxStack = 50, desc = "Burns with magic", sellValue = 150},
    {id = "tq_enchanted_gem", name = "Enchanted Gem", category = "tq_material", icon = "assets/icons/resourcesandfood/Res_25_crystal.PNG", stackable = true, maxStack = 99, desc = "Glowing gemstone", sellValue = 75},
    {id = "tq_sacred_water", name = "Sacred Water", category = "tq_material", icon = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_19_little_flask.PNG", stackable = true, maxStack = 99, desc = "Blessed water", sellValue = 30},
    {id = "tq_demon_horn", name = "Demon Horn", category = "tq_material", icon = "assets/icons/loot/Loot_155_horn.PNG", stackable = true, maxStack = 50, desc = "From dark creatures", sellValue = 100},
    {id = "tq_ghost_essence", name = "Ghost Essence", category = "tq_material", icon = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_05_poison.PNG", stackable = true, maxStack = 99, desc = "Spectral residue", sellValue = 60},
    {id = "tq_troll_blood", name = "Troll Blood", category = "tq_material", icon = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_06_blood.PNG", stackable = true, maxStack = 99, desc = "Regenerative blood", sellValue = 35},
    {id = "tq_goblin_ears", name = "Goblin Ears", category = "tq_material", icon = "assets/icons/loot/Loot_158_ear.PNG", stackable = true, maxStack = 99, desc = "Trophy item", sellValue = 5},
    {id = "tq_skeleton_bone", name = "Skeleton Bone", category = "tq_material", icon = "assets/icons/loot/Bone.png", stackable = true, maxStack = 99, desc = "Undead remains", sellValue = 10},

    -- ========== VAMPIRE SYSTEM ITEMS ==========
    {id = "tq_vampire_coffin", name = "Vampire's Coffin", category = "tq_special", icon = "assets/icons/loot/Chest.PNG", stackable = false, desc = "Dark wooden coffin. Provides complete protection from sunlight when carried. Very heavy (150 weight)", sellValue = 2000, weight = 150, baseStats = {vampireProtection = true}},
    {id = "tq_black_cloth", name = "Black Cloth", category = "tq_material", icon = "assets/icons/resources/Res_68_cloth.PNG", stackable = true, maxStack = 99, desc = "Dark, heavy cloth. Can be used to wrap yourself against sunlight (30% fail chance)", sellValue = 50, weight = 2},
    {id = "tq_holy_water", name = "Holy Water", category = "tq_special", icon = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_19_little_flask.PNG", stackable = true, maxStack = 20, desc = "Blessed water from Holy City. Can cure vampirism (costs 50% HP)", sellValue = 1000},
    {id = "tq_vampire_fang", name = "Vampire Fang", category = "tq_material", icon = "assets/icons/loot/Loot_158_ear.PNG", stackable = true, maxStack = 99, desc = "Sharp vampire fang. Trophy from defeated vampire", sellValue = 150},
    {id = "tq_dark_essence", name = "Dark Essence", category = "tq_material", icon = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_05_poison.PNG", stackable = true, maxStack = 99, desc = "Essence of vampiric power", sellValue = 200},
    {id = "tq_ritual_components", name = "Ritual Components", category = "tq_special", icon = "assets/icons/resourcesandfood/Res_25_crystal.PNG", stackable = true, maxStack = 10, desc = "Components for sun ritual cure (painful)", sellValue = 800},
    {id = "tq_wood", name = "Wood Planks", category = "tq_material", icon = "assets/icons/resources/Res_02_wood.PNG", stackable = true, maxStack = 99, desc = "Wooden planks for construction", sellValue = 5},
    {id = "tq_iron_ingot", name = "Iron Ingot", category = "tq_material", icon = "assets/icons/resources/Res_61_iron_bar.PNG", stackable = true, maxStack = 99, desc = "Smelted iron bar", sellValue = 20},

    -- ========== STEALTH SYSTEM ITEMS ==========
    {id = "tq_stealth_cloak", name = "Stealth Cloak", category = "tq_accessory", icon = "assets/icons/armor/Chest_48_leather.PNG", stackable = false, desc = "Dark cloak that helps you blend into shadows (-20% detection)", sellValue = 500, baseStats = {stealthBonus = 20}},
    {id = "tq_dark_hood", name = "Dark Hood", category = "tq_accessory", icon = "assets/icons/armor/Chest_01_farmer.PNG", stackable = false, desc = "Black hood that obscures your face (-10% detection)", sellValue = 150, baseStats = {stealthBonus = 10}},
    {id = "tq_soft_boots", name = "Soft Leather Boots", category = "tq_accessory", icon = "assets/icons/armor/Chest_48_leather.PNG", stackable = false, desc = "Silent footsteps (-10% detection)", sellValue = 200, baseStats = {stealthBonus = 10}},
    {id = "tq_shadow_dye", name = "Shadow Dye", category = "tq_consumable", icon = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_05_poison.PNG", stackable = true, maxStack = 20, desc = "Darkens armor for 1 hour (-15% detection)", sellValue = 50},
    {id = "tq_smoke_bomb", name = "Smoke Bomb", category = "tq_consumable", icon = "assets/icons/loot/Loot_155_horn.PNG", stackable = true, maxStack = 20, desc = "Creates a dark zone (2-tile radius) for 3 combat turns", sellValue = 100},
    {id = "tq_disguise_kit", name = "Disguise Kit", category = "tq_consumable", icon = "assets/icons/resourcesandfood/Book.PNG", stackable = true, maxStack = 10, desc = "Change appearance and reset detection", sellValue = 300},
    {id = "tq_quality_lockpicks", name = "Quality Lockpick Set", category = "tq_special", icon = "assets/icons/loot/Loot_157_ribbon.PNG", stackable = false, desc = "Professional lockpicks (+25% speed, quieter)", sellValue = 250, baseStats = {lockpickBonus = 25}},
    {id = "tq_silent_bell", name = "Silent Bell", category = "tq_accessory", icon = "assets/icons/loot/Loot_155_horn.PNG", stackable = false, desc = "Muffles all sounds you make (-5% detection)", sellValue = 80, baseStats = {stealthBonus = 5}},

    -- ========== TEXTRPG - FOOD (Butcher/Bakery) ==========
    -- Butcher items
    {id = "tq_raw_steak", name = "Raw Steak", category = "tq_food", icon = "assets/icons/resourcesandfood/FriedChickenLeg.PNG", stackable = true, maxStack = 20, desc = "Fresh cut of meat", sellValue = 15, baseStats = {heal = 20}},
    {id = "tq_salted_meat", name = "Salted Meat", category = "tq_food", icon = "assets/icons/resourcesandfood/FriedChickenLeg.PNG", stackable = true, maxStack = 30, desc = "Preserved meat rations", sellValue = 25, baseStats = {heal = 35}},
    {id = "tq_smoked_sausage", name = "Smoked Sausage", category = "tq_food", icon = "assets/icons/resourcesandfood/FriedChickenLeg.PNG", stackable = true, maxStack = 20, desc = "Tasty travel food", sellValue = 20, baseStats = {heal = 25}},
    {id = "tq_beef_jerky", name = "Beef Jerky", category = "tq_food", icon = "assets/icons/resourcesandfood/FriedChickenLeg.PNG", stackable = true, maxStack = 50, desc = "Long-lasting dried meat", sellValue = 12, baseStats = {heal = 15}},
    {id = "tq_prime_cut", name = "Prime Cut", category = "tq_food", icon = "assets/icons/resourcesandfood/FriedChickenLeg.PNG", stackable = true, maxStack = 10, desc = "Premium quality meat (+1 Might temp)", sellValue = 50, baseStats = {heal = 50, tempMIGHT = 1}},
    {id = "tq_monster_steak", name = "Monster Steak", category = "tq_food", icon = "assets/icons/resourcesandfood/FriedChickenLeg.PNG", stackable = true, maxStack = 10, desc = "Exotic meat with magical properties", sellValue = 80, baseStats = {heal = 75, tempVIGOR = 1}},

    -- Bakery items
    {id = "tq_bread_loaf", name = "Bread Loaf", category = "tq_food", icon = "assets/icons/resourcesandfood/Bread.PNG", stackable = true, maxStack = 20, desc = "Fresh baked bread", sellValue = 8, baseStats = {heal = 15}},
    {id = "tq_sweet_roll", name = "Sweet Roll", category = "tq_food", icon = "assets/icons/resourcesandfood/Bread.PNG", stackable = true, maxStack = 30, desc = "Delicious pastry", sellValue = 12, baseStats = {heal = 20}},
    {id = "tq_meat_pie", name = "Meat Pie", category = "tq_food", icon = "assets/icons/resourcesandfood/Bread.PNG", stackable = true, maxStack = 15, desc = "Hearty and filling", sellValue = 30, baseStats = {heal = 40}},
    {id = "tq_honeycake", name = "Honeycake", category = "tq_food", icon = "assets/icons/resourcesandfood/Bread.PNG", stackable = true, maxStack = 20, desc = "Sweet energy boost", sellValue = 25, baseStats = {heal = 25, mana = 15}},
    {id = "tq_elven_waybread", name = "Elven Waybread", category = "tq_food", icon = "assets/icons/resourcesandfood/Bread.PNG", stackable = true, maxStack = 10, desc = "Magical bread that sustains", sellValue = 60, baseStats = {heal = 60, mana = 30}},
    {id = "tq_adventure_rations", name = "Adventure Rations", category = "tq_food", icon = "assets/icons/resourcesandfood/Bread.PNG", stackable = true, maxStack = 50, desc = "Mixed bread and dried goods", sellValue = 15, baseStats = {heal = 25}},

    -- ========== TEXTRPG - ACCESSORIES (Jeweler) ==========
    {id = "tq_copper_ring", name = "Copper Ring", category = "tq_accessory", icon = "assets/icons/loot/Loot_147_jewelry.PNG", stackable = false, desc = "Simple copper band", sellValue = 20, baseStats = {}},
    {id = "tq_silver_ring", name = "Silver Ring", category = "tq_accessory", icon = "assets/icons/loot/Loot_147_jewelry.PNG", stackable = false, desc = "Elegant silver ring (+1 Presence)", sellValue = 75, baseStats = {PRESENCE = 1}},
    {id = "tq_gold_ring", name = "Gold Ring", category = "tq_accessory", icon = "assets/icons/loot/Loot_147_jewelry.PNG", stackable = false, desc = "Fine gold ring (+2 Presence)", sellValue = 200, baseStats = {PRESENCE = 2}},
    {id = "tq_ruby_amulet", name = "Ruby Amulet", category = "tq_accessory", icon = "assets/icons/loot/Loot_147_jewelry.PNG", stackable = false, desc = "Fiery gem (+2 Might)", sellValue = 300, baseStats = {MIGHT = 2}},
    {id = "tq_sapphire_pendant", name = "Sapphire Pendant", category = "tq_accessory", icon = "assets/icons/loot/Loot_147_jewelry.PNG", stackable = false, desc = "Cool blue gem (+2 Mind)", sellValue = 300, baseStats = {MIND = 2}},
    {id = "tq_emerald_brooch", name = "Emerald Brooch", category = "tq_accessory", icon = "assets/icons/loot/Loot_147_jewelry.PNG", stackable = false, desc = "Green gem of nature (+2 Spirit)", sellValue = 300, baseStats = {SPIRIT = 2}},
    {id = "tq_diamond_earring", name = "Diamond Earring", category = "tq_accessory", icon = "assets/icons/loot/Loot_147_jewelry.PNG", stackable = false, desc = "Sparkling diamond (+2 Agility)", sellValue = 350, baseStats = {AGILITY = 2}},
    {id = "tq_lucky_charm", name = "Lucky Charm", category = "tq_accessory", icon = "assets/icons/loot/Loot_147_jewelry.PNG", stackable = false, desc = "Brings good fortune (+5% crit)", sellValue = 250, baseStats = {critBonus = 5}},
    {id = "tq_protection_talisman", name = "Protection Talisman", category = "tq_accessory", icon = "assets/icons/loot/Loot_147_jewelry.PNG", stackable = false, desc = "Wards off harm (+3 defense)", sellValue = 280, baseStats = {defense = 3}},

    -- ========== TEXTRPG - CLOTHING (Tailor) ==========
    {id = "tq_traveler_cloak", name = "Traveler's Cloak", category = "tq_clothing", icon = "assets/icons/armor/Chest_01_farmer.PNG", stackable = false, desc = "Warm traveling cloak (+1 Vigor)", sellValue = 40, baseStats = {defense = 1, VIGOR = 1}},
    {id = "tq_fine_tunic", name = "Fine Tunic", category = "tq_clothing", icon = "assets/icons/armor/Chest_01_farmer.PNG", stackable = false, desc = "Elegant attire (+2 Presence)", sellValue = 80, baseStats = {PRESENCE = 2}},
    {id = "tq_noble_garb", name = "Noble Garb", category = "tq_clothing", icon = "assets/icons/armor/Chest_01_farmer.PNG", stackable = false, desc = "Regal clothing (+3 Presence, +1 Mind)", sellValue = 200, baseStats = {PRESENCE = 3, MIND = 1}},
    {id = "tq_ranger_hood", name = "Ranger's Hood", category = "tq_clothing", icon = "assets/icons/armor/Chest_01_farmer.PNG", stackable = false, desc = "Hooded cowl (+2 Agility)", sellValue = 120, baseStats = {AGILITY = 2}},
    {id = "tq_silk_gloves", name = "Silk Gloves", category = "tq_clothing", icon = "assets/icons/armor/Chest_01_farmer.PNG", stackable = false, desc = "Delicate handwear (+1 Agility)", sellValue = 60, baseStats = {AGILITY = 1}},
    {id = "tq_sturdy_boots", name = "Sturdy Boots", category = "tq_clothing", icon = "assets/icons/armor/Chest_01_farmer.PNG", stackable = false, desc = "Good walking boots (+1 Vigor)", sellValue = 50, baseStats = {VIGOR = 1}},
    {id = "tq_enchanted_cape", name = "Enchanted Cape", category = "tq_clothing", icon = "assets/icons/armor/Chest_01_farmer.PNG", stackable = false, desc = "Magical cape (+2 Mind, +1 defense)", sellValue = 180, baseStats = {MIND = 2, defense = 1}},

    -- ========== TRANSPORT - CARTS ==========
    {id = "handcart", name = "Handcart", category = "transport", icon = "assets/icons/loot/Loot_101_chest.PNG", stackable = false, desc = "Small cart (+50 lbs capacity)", sellValue = 50, weight = 0},
    {id = "small_wagon", name = "Small Wagon", category = "transport", icon = "assets/icons/loot/Loot_101_chest.PNG", stackable = false, desc = "Wagon (+150 lbs, needs beast)", sellValue = 150, weight = 0},
    {id = "large_wagon", name = "Large Wagon", category = "transport", icon = "assets/icons/loot/Loot_101_chest.PNG", stackable = false, desc = "Heavy wagon (+400 lbs, needs beast)", sellValue = 400, weight = 0},
    {id = "merchant_caravan", name = "Merchant Caravan", category = "transport", icon = "assets/icons/loot/Loot_101_chest.PNG", stackable = false, desc = "Massive caravan (+800 lbs, needs beast)", sellValue = 1000, weight = 0},

    -- ========== TRANSPORT - BEASTS OF BURDEN ==========
    {id = "donkey", name = "Donkey", category = "transport", icon = "assets/icons/loot/Loot_155_horn.PNG", stackable = false, desc = "Hardy pack animal (+80 lbs)", sellValue = 75, weight = 0},
    {id = "mule", name = "Mule", category = "transport", icon = "assets/icons/loot/Loot_155_horn.PNG", stackable = false, desc = "Strong and sure-footed (+120 lbs)", sellValue = 150, weight = 0},
    {id = "ox", name = "Ox", category = "transport", icon = "assets/icons/loot/Loot_155_horn.PNG", stackable = false, desc = "Powerful but slow (+200 lbs)", sellValue = 250, weight = 0},
    {id = "pack_horse", name = "Pack Horse", category = "transport", icon = "assets/icons/loot/Loot_155_horn.PNG", stackable = false, desc = "Fast pack animal (+150 lbs)", sellValue = 200, weight = 0},
    {id = "camel", name = "Camel", category = "transport", icon = "assets/icons/loot/Loot_155_horn.PNG", stackable = false, desc = "Desert specialist (+180 lbs)", sellValue = 300, weight = 0},
    {id = "elephant", name = "War Elephant", category = "transport", icon = "assets/icons/loot/Loot_155_horn.PNG", stackable = false, desc = "Massive capacity (+500 lbs)", sellValue = 1500, weight = 0},

    -- ========== BEAST FEED ==========
    {id = "animal_feed", name = "Animal Feed", category = "consumable", icon = "assets/icons/resourcesandfood/Res_140_fish.PNG", stackable = true, maxStack = 50, desc = "Basic feed for beasts", sellValue = 5, weight = 2.0},
    {id = "premium_feed", name = "Premium Feed", category = "consumable", icon = "assets/icons/resourcesandfood/Res_140_fish.PNG", stackable = true, maxStack = 30, desc = "High quality feed", sellValue = 15, weight = 2.0},
}

-- Build item lookup table
local itemLookup = {}

-- Rebuild the lookup table (call after adding items)
local function rebuildLookup()
    itemLookup = {}
    for _, item in ipairs(Backpack.ITEMS) do
        itemLookup[item.id] = item
    end
end

-- Initial build
rebuildLookup()

-- Cached item images
local itemImages = {}

-- Load item images
function Backpack.loadImages()
    for _, item in ipairs(Backpack.ITEMS) do
        if item.icon and not itemImages[item.id] then
            local success, img = pcall(function()
                return love.graphics.newImage(item.icon)
            end)
            if success then
                itemImages[item.id] = img
            end
        end
    end
end

-- Get item definition by ID
function Backpack.getItemDef(itemId)
    return itemLookup[itemId]
end

-- Get item image
function Backpack.getItemImage(itemId)
    return itemImages[itemId]
end

-- Reset backpack for new game (clears all data and re-initializes)
function Backpack.reset()
    _initialized = false
    PlayerData.backpack = nil
    Backpack.init()
end

-- Initialize backpack in PlayerData
-- OPTIMIZED: Uses _initialized flag to skip redundant work
function Backpack.init()
    -- Quick return if already initialized and backpack exists
    if _initialized and PlayerData.backpack then
        return
    end

    if not PlayerData.backpack then
        PlayerData.backpack = {
            items = {},  -- {itemId = quantity}
            maxSlots = 50,
            equippedPet = nil,    -- Pet companion for battle assist
            equippedMount = nil,  -- Mount for travel
            -- Weight/encumbrance system
            equippedBeast = nil,  -- Beast of burden for carrying
            equippedCart = nil,   -- Cart attached to beast
            beastNeeds = {        -- Beast needs tracking
                hunger = 100,     -- 0-100, lower = hungrier
                stamina = 100,    -- 0-100, lower = more tired
            },
        }
        -- Give starter crafting materials
        PlayerData.backpack.items = {
            -- Forge materials
            iron_ore = 10,
            steel_ingot = 3,
            leather_scraps = 8,
            wood_planks = 10,
            -- Wizard materials
            mana_crystal = 5,
            fire_essence = 4,
            frost_essence = 4,
            arcane_dust = 6,
            ancient_scroll = 5,
            enchanted_ink = 3,
            -- Alchemy materials
            healing_herb = 10,
            moonflower = 6,
            venom_sac = 5,
            empty_vial = 15,
            troll_blood = 2,
        }
        -- Invalidate caches for new backpack
        invalidateAllCaches()
    end

    -- Migration for existing backpacks (only run once)
    if not _initialized then
        if PlayerData.backpack.equippedPet == nil then
            PlayerData.backpack.equippedPet = nil
        end
        if PlayerData.backpack.equippedMount == nil then
            PlayerData.backpack.equippedMount = nil
        end
        -- Migration for weight system
        if PlayerData.backpack.equippedBeast == nil then
            PlayerData.backpack.equippedBeast = nil
        end
        if PlayerData.backpack.equippedCart == nil then
            PlayerData.backpack.equippedCart = nil
        end
        if PlayerData.backpack.beastNeeds == nil then
            PlayerData.backpack.beastNeeds = {hunger = 100, stamina = 100}
        end
        Backpack.loadImages()
        _initialized = true
    end
end

-- Equip a pet as companion (for battle assistance)
function Backpack.equipPet(pet)
    Backpack.init()
    if pet then
        PlayerData.backpack.equippedPet = {
            id = pet.id,
            name = pet.name,
            speciesId = pet.speciesId,
            element = pet.element,
            battlePower = pet.battlePower or 10,
            evolutionStage = pet.evolutionStage or 1,
            gender = pet.gender,
        }
        savePlayerData()
        return true
    end
    return false
end

-- Unequip pet companion
function Backpack.unequipPet()
    Backpack.init()
    PlayerData.backpack.equippedPet = nil
    savePlayerData()
end

-- Get equipped pet
function Backpack.getEquippedPet()
    Backpack.init()
    return PlayerData.backpack.equippedPet
end

-- Equip a mount (for travel)
function Backpack.equipMount(pet)
    Backpack.init()
    if pet and pet.mountType then
        PlayerData.backpack.equippedMount = {
            id = pet.id,
            name = pet.name,
            speciesId = pet.speciesId,
            element = pet.element,
            mountType = pet.mountType,
            evolutionStage = pet.evolutionStage or 1,
            gender = pet.gender,
        }
        savePlayerData()
        return true
    end
    return false, "This creature cannot be used as a mount"
end

-- Unequip mount
function Backpack.unequipMount()
    Backpack.init()
    PlayerData.backpack.equippedMount = nil
    savePlayerData()
end

-- Get equipped mount
function Backpack.getEquippedMount()
    Backpack.init()
    return PlayerData.backpack.equippedMount
end

-- Get mount speed multiplier based on mount type
function Backpack.getMountSpeedMultiplier()
    Backpack.init()
    local mount = PlayerData.backpack.equippedMount
    if not mount then return 1.0 end

    -- Check for custom speed multiplier (vehicles)
    if mount.speedMultiplier then
        return mount.speedMultiplier
    end

    if mount.mountType == "flying" then
        return 4.0  -- Birds fly 4x speed
    elseif mount.mountType == "land" then
        return 2.0  -- Land mounts 2x speed
    elseif mount.mountType == "aquatic" then
        return 2.0  -- Aquatic mounts 2x in water
    elseif mount.mountType == "boat" then
        return 2.5  -- Default boat speed (overridden by speedMultiplier if set)
    elseif mount.mountType == "cart" then
        return 1.5  -- Carts are slower but safer
    end
    return 1.0
end

-- Get encounter reduction multiplier from mount (lower = fewer encounters)
function Backpack.getMountEncounterReduction()
    Backpack.init()
    local mount = PlayerData.backpack.equippedMount
    if not mount then return 1.0 end

    -- Check for custom encounter reduction (carts, wagons)
    if mount.encounterReduction then
        return mount.encounterReduction
    end

    -- Default reductions by mount type
    if mount.mountType == "cart" then
        return 0.5  -- 50% less encounters in carts
    elseif mount.mountType == "flying" then
        return 0.7  -- 30% less encounters flying
    end
    return 1.0  -- No reduction
end

-- Get cargo bonus from mount (extra carry capacity)
function Backpack.getMountCargoBonus()
    Backpack.init()
    local mount = PlayerData.backpack.equippedMount
    if not mount then return 0 end

    return mount.cargoBonus or 0
end

-- Check if mount can traverse terrain
function Backpack.canMountTraverse(terrain)
    Backpack.init()
    local mount = PlayerData.backpack.equippedMount
    if not mount then return false end

    local terrainMap = {
        land = {"plains", "forest", "wasteland", "mountain"},
        flying = {"plains", "forest", "wasteland", "mountain", "ocean"},  -- Flying can go anywhere
        aquatic = {"ocean", "river", "lake", "coast"},
        boat = {"ocean", "river", "lake", "coast"},  -- Boats for water
        cart = {"plains", "forest", "road"},  -- Carts need roads or flat terrain
    }

    local allowed = terrainMap[mount.mountType] or {}
    for _, t in ipairs(allowed) do
        if t == terrain then return true end
    end
    return false
end

-- Get pet battle bonus (damage boost from companion)
function Backpack.getPetBattleBonus()
    Backpack.init()
    local pet = PlayerData.backpack.equippedPet
    if not pet then return 0 end

    -- Battle power scaled by evolution stage
    local baseBonus = pet.battlePower or 10
    local stageMultiplier = 1 + ((pet.evolutionStage or 1) - 1) * 0.5
    return math.floor(baseBonus * stageMultiplier)
end

-- ========== WEIGHT/ENCUMBRANCE FUNCTIONS ==========

-- Get weight of a single item (checks item definition, then category default)
function Backpack.getItemWeight(itemId)
    local itemDef = Backpack.getItemDef(itemId)
    if not itemDef then return 1.0 end

    -- Use item-specific weight if defined
    if itemDef.weight then
        return itemDef.weight
    end

    -- Fall back to category default
    local categoryWeight = Backpack.DEFAULT_WEIGHTS[itemDef.category]
    if categoryWeight then
        return categoryWeight
    end

    -- Default weight for unknown categories
    return 1.0
end

-- Calculate total weight of all items in backpack
-- OPTIMIZED: Uses cache to avoid recalculating every frame
function Backpack.getTotalWeight()
    Backpack.init()

    -- Return cached value if not dirty
    if not _weightCache.dirty and _weightCache.totalWeight then
        return _weightCache.totalWeight
    end

    -- Recalculate weight
    local totalWeight = 0
    for itemId, quantity in pairs(PlayerData.backpack.items) do
        if quantity > 0 then
            local weight = Backpack.getItemWeight(itemId)
            totalWeight = totalWeight + (weight * quantity)
        end
    end

    -- Cache the result
    _weightCache.totalWeight = totalWeight
    _weightCache.dirty = false

    return totalWeight
end

-- Force recalculation of weight (public API)
function Backpack.invalidateWeightCache()
    invalidateWeightCache()
end

-- Get base carry capacity (Might-based for player, fixed for NPCs)
function Backpack.getBaseCarryCapacity(might)
    might = might or 10  -- Default Might of 10
    -- Base 50 lbs + 5 lbs per Might point
    return 50 + (might * 5)
end

-- Get beast of burden definition by ID
function Backpack.getBeastDef(beastId)
    for _, beast in ipairs(Backpack.BEASTS_OF_BURDEN) do
        if beast.id == beastId then
            return beast
        end
    end
    return nil
end

-- Get cart definition by ID
function Backpack.getCartDef(cartId)
    for _, cart in ipairs(Backpack.CARTS) do
        if cart.id == cartId then
            return cart
        end
    end
    return nil
end

-- Get total carry capacity (player + beast + cart)
-- OPTIMIZED: Uses cache when might hasn't changed
function Backpack.getTotalCarryCapacity(might)
    Backpack.init()

    -- Check if we can use cached value (same might and cache not dirty)
    if not _weightCache.capacityDirty and
       _weightCache.lastMight == might and
       _weightCache.totalCapacity then
        return _weightCache.totalCapacity
    end

    local capacity = Backpack.getBaseCarryCapacity(might)

    -- Add beast capacity
    local beast = PlayerData.backpack.equippedBeast
    if beast then
        local beastDef = Backpack.getBeastDef(beast.id)
        if beastDef then
            -- Beast capacity reduced by fatigue/hunger
            local needs = PlayerData.backpack.beastNeeds or {hunger = 100, stamina = 100}
            -- Clamp needs to 0-100 range to prevent negative values from reducing base capacity
            local hungerClamped = math.max(0, math.min(100, needs.hunger))
            local staminaClamped = math.max(0, math.min(100, needs.stamina))
            local conditionMult = math.min(hungerClamped, staminaClamped) / 100
            capacity = capacity + (beastDef.carryCapacity * conditionMult)
        end
    end

    -- Add cart capacity (requires beast that can pull)
    local cart = PlayerData.backpack.equippedCart
    if cart and beast then
        local cartDef = Backpack.getCartDef(cart.id)
        local beastDef = Backpack.getBeastDef(beast.id)
        if cartDef and beastDef and beastDef.canPullCart then
            capacity = capacity + cartDef.carryCapacity
        end
    end

    -- Cache the result
    _weightCache.totalCapacity = capacity
    _weightCache.lastMight = might
    _weightCache.capacityDirty = false

    return capacity
end

-- Force recalculation of capacity (public API)
function Backpack.invalidateCapacityCache()
    invalidateCapacityCache()
end

-- Determine encumbrance level based on weight ratio
function Backpack.getEncumbranceLevel(currentWeight, maxCapacity)
    if maxCapacity <= 0 then return "immobile" end

    local ratio = currentWeight / maxCapacity

    if ratio > 1.25 then
        return "immobile"
    elseif ratio > 1.0 then
        return "overencumbered"
    elseif ratio > 0.75 then
        return "heavy"
    elseif ratio > 0.50 then
        return "medium"
    else
        return "light"
    end
end

-- Get speed multiplier based on encumbrance level
function Backpack.getSpeedMultiplier(encumbranceLevel)
    return Backpack.ENCUMBRANCE_SPEED[encumbranceLevel] or 1.0
end

-- Get current encumbrance status (convenience function)
function Backpack.getEncumbranceStatus(might)
    Backpack.init()
    local currentWeight = Backpack.getTotalWeight()
    local maxCapacity = Backpack.getTotalCarryCapacity(might)
    local level = Backpack.getEncumbranceLevel(currentWeight, maxCapacity)
    local speedMult = Backpack.getSpeedMultiplier(level)

    return {
        currentWeight = currentWeight,
        maxCapacity = maxCapacity,
        ratio = maxCapacity > 0 and (currentWeight / maxCapacity) or 0,
        level = level,
        speedMultiplier = speedMult,
        canRun = level ~= "heavy" and level ~= "overencumbered" and level ~= "immobile",
        canMove = level ~= "immobile",
    }
end

-- ========== BEAST OF BURDEN MANAGEMENT ==========

-- Equip a beast of burden
function Backpack.equipBeast(beastId)
    Backpack.init()
    local beastDef = Backpack.getBeastDef(beastId)
    if not beastDef then return false, "Unknown beast" end

    PlayerData.backpack.equippedBeast = {
        id = beastId,
        name = beastDef.name,
        purchaseTime = os.time(),
    }
    PlayerData.backpack.beastNeeds = {hunger = 100, stamina = 100}

    -- Invalidate capacity cache since beast affects carry capacity
    invalidateCapacityCache()

    savePlayerData()
    return true
end

-- Unequip beast of burden (also removes cart)
function Backpack.unequipBeast()
    Backpack.init()
    PlayerData.backpack.equippedBeast = nil
    PlayerData.backpack.equippedCart = nil  -- Cart needs beast
    PlayerData.backpack.beastNeeds = {hunger = 100, stamina = 100}

    -- Invalidate capacity cache since beast affects carry capacity
    invalidateCapacityCache()

    savePlayerData()
end

-- Get equipped beast
function Backpack.getEquippedBeast()
    Backpack.init()
    return PlayerData.backpack.equippedBeast
end

-- Equip a cart (requires compatible beast)
function Backpack.equipCart(cartId)
    Backpack.init()
    local cartDef = Backpack.getCartDef(cartId)
    if not cartDef then return false, "Unknown cart" end

    -- Check if cart requires beast
    if cartDef.requiresBeast then
        local beast = PlayerData.backpack.equippedBeast
        if not beast then
            return false, "Need a beast of burden to pull this cart"
        end
        local beastDef = Backpack.getBeastDef(beast.id)
        if not beastDef or not beastDef.canPullCart then
            return false, "This beast cannot pull a cart"
        end
    end

    PlayerData.backpack.equippedCart = {
        id = cartId,
        name = cartDef.name,
    }

    -- Invalidate capacity cache since cart affects carry capacity
    invalidateCapacityCache()

    savePlayerData()
    return true
end

-- Unequip cart
function Backpack.unequipCart()
    Backpack.init()
    PlayerData.backpack.equippedCart = nil

    -- Invalidate capacity cache since cart affects carry capacity
    invalidateCapacityCache()
    savePlayerData()
end

-- Get equipped cart
function Backpack.getEquippedCart()
    Backpack.init()
    return PlayerData.backpack.equippedCart
end

-- Update beast needs over time (call during travel/gameplay)
function Backpack.updateBeastNeeds(dt, isMoving)
    Backpack.init()
    local beast = PlayerData.backpack.equippedBeast
    if not beast then return end

    local beastDef = Backpack.getBeastDef(beast.id)
    if not beastDef then return end

    local needs = PlayerData.backpack.beastNeeds
    local cart = PlayerData.backpack.equippedCart

    -- Base drain rates (per second)
    local hungerDrain = beastDef.hungerRate * 0.01  -- Convert to per-second
    local staminaDrain = beastDef.staminaRate * 0.01

    -- Cart increases stamina drain
    if cart then
        local cartDef = Backpack.getCartDef(cart.id)
        if cartDef then
            staminaDrain = staminaDrain * (1 + cartDef.speedPenalty)
        end
    end

    -- Moving drains stamina faster
    if isMoving then
        staminaDrain = staminaDrain * 2
    end

    -- Apply drain
    needs.hunger = math.max(0, needs.hunger - (hungerDrain * dt))
    needs.stamina = math.max(0, needs.stamina - (staminaDrain * dt))

    -- Stamina regenerates when not moving (slowly)
    if not isMoving then
        needs.stamina = math.min(100, needs.stamina + (0.05 * dt))
    end

    PlayerData.backpack.beastNeeds = needs
end

-- Feed beast to restore hunger
function Backpack.feedBeast(foodItemId)
    Backpack.init()
    local beast = PlayerData.backpack.equippedBeast
    if not beast then return false, "No beast equipped" end

    -- Food items and their hunger restoration
    local foodValues = {
        raw_meat = 20,
        meat = 20,
        common_fish = 15,
        rare_fish = 25,
        legendary_fish = 40,
        healing_herb = 10,
        bait = 5,
        animal_feed = 30,
        premium_feed = 60,
    }

    local restoration = foodValues[foodItemId]
    if not restoration then return false, "Beast won't eat this" end

    if not Backpack.hasItem(foodItemId, 1) then
        return false, "You don't have this food"
    end

    Backpack.removeItem(foodItemId, 1)
    local needs = PlayerData.backpack.beastNeeds
    needs.hunger = math.min(100, needs.hunger + restoration)
    PlayerData.backpack.beastNeeds = needs
    savePlayerData()

    return true, restoration
end

-- Rest beast to restore stamina
function Backpack.restBeast(hours)
    Backpack.init()
    local beast = PlayerData.backpack.equippedBeast
    if not beast then return false, "No beast equipped" end

    hours = hours or 1
    local restoration = hours * 25  -- 25% per hour of rest

    local needs = PlayerData.backpack.beastNeeds
    needs.stamina = math.min(100, needs.stamina + restoration)
    PlayerData.backpack.beastNeeds = needs
    savePlayerData()

    return true, restoration
end

-- Get beast condition as a descriptive string
function Backpack.getBeastCondition()
    Backpack.init()
    local beast = PlayerData.backpack.equippedBeast
    if not beast then return nil end

    local needs = PlayerData.backpack.beastNeeds
    local conditions = {}

    -- Hunger status
    if needs.hunger <= 20 then
        table.insert(conditions, "Starving")
    elseif needs.hunger <= 50 then
        table.insert(conditions, "Hungry")
    end

    -- Stamina status
    if needs.stamina <= 20 then
        table.insert(conditions, "Exhausted")
    elseif needs.stamina <= 50 then
        table.insert(conditions, "Tired")
    end

    if #conditions == 0 then
        return "Good"
    end
    return table.concat(conditions, ", ")
end

-- Get travel speed multiplier considering beast, cart, and encumbrance
function Backpack.getTravelSpeedMultiplier(might)
    Backpack.init()
    local baseSpeed = 1.0

    -- Mount speed (if mounted, overrides walking)
    local mount = PlayerData.backpack.equippedMount
    if mount then
        baseSpeed = Backpack.getMountSpeedMultiplier()
    end

    -- Beast affects speed based on its speed stat
    local beast = PlayerData.backpack.equippedBeast
    if beast then
        local beastDef = Backpack.getBeastDef(beast.id)
        if beastDef then
            -- Beast slows you down if not mounted on it
            if not mount then
                baseSpeed = baseSpeed * beastDef.speed
            end

            -- Beast condition affects speed
            local needs = PlayerData.backpack.beastNeeds
            if needs.stamina < 20 then
                baseSpeed = baseSpeed * 0.5  -- Exhausted beast is very slow
            elseif needs.stamina < 50 then
                baseSpeed = baseSpeed * 0.75  -- Tired beast is slower
            end
        end
    end

    -- Cart speed penalty
    local cart = PlayerData.backpack.equippedCart
    if cart then
        local cartDef = Backpack.getCartDef(cart.id)
        if cartDef then
            baseSpeed = baseSpeed * (1 - cartDef.speedPenalty)
        end
    end

    -- Encumbrance penalty
    local encumbrance = Backpack.getEncumbranceStatus(might)
    baseSpeed = baseSpeed * encumbrance.speedMultiplier

    return baseSpeed
end

-- Add item to backpack
function Backpack.addItem(itemId, quantity)
    Backpack.init()
    quantity = quantity or 1

    local itemDef = Backpack.getItemDef(itemId)
    if not itemDef then return false, "Unknown item" end

    local current = PlayerData.backpack.items[itemId] or 0

    if itemDef.stackable then
        local maxStack = itemDef.maxStack or 99
        local spaceAvailable = maxStack - current

        -- Check if adding would overflow the stack
        if quantity > spaceAvailable then
            -- Add what we can and return overflow amount
            PlayerData.backpack.items[itemId] = maxStack
            local overflow = quantity - spaceAvailable

            -- Invalidate weight cache since inventory changed
            invalidateWeightCache()
            savePlayerData()

            return false, "Stack overflow: " .. overflow .. " items couldn't be added", overflow
        end

        PlayerData.backpack.items[itemId] = current + quantity
    else
        -- Non-stackable items - need to handle quantity > 1
        if quantity > 1 then
            return false, "Cannot add multiple non-stackable items at once. Item '" .. itemId .. "' is not stackable."
        end

        if current > 0 then
            return false, "Already have this item"
        end
        PlayerData.backpack.items[itemId] = 1
    end

    -- Invalidate weight cache since inventory changed
    invalidateWeightCache()

    savePlayerData()
    return true
end

-- Remove item from backpack
function Backpack.removeItem(itemId, quantity)
    Backpack.init()
    quantity = quantity or 1

    local current = PlayerData.backpack.items[itemId] or 0
    if current < quantity then
        return false, "Not enough items"
    end

    PlayerData.backpack.items[itemId] = current - quantity
    if PlayerData.backpack.items[itemId] <= 0 then
        PlayerData.backpack.items[itemId] = nil
    end

    -- Invalidate weight cache since inventory changed
    invalidateWeightCache()

    savePlayerData()
    return true
end

-- Check if has item
function Backpack.hasItem(itemId, quantity)
    Backpack.init()
    quantity = quantity or 1
    local current = PlayerData.backpack.items[itemId] or 0
    return current >= quantity
end

-- Get item count
function Backpack.getItemCount(itemId)
    Backpack.init()
    return PlayerData.backpack.items[itemId] or 0
end

-- Get all items as a list
function Backpack.getAllItems()
    Backpack.init()
    local items = {}
    for itemId, quantity in pairs(PlayerData.backpack.items) do
        if quantity > 0 then
            local itemDef = Backpack.getItemDef(itemId)
            if itemDef then
                table.insert(items, {
                    id = itemId,
                    quantity = quantity,
                    def = itemDef,
                })
            end
        end
    end
    return items
end

-- Get items by category
function Backpack.getItemsByCategory(category)
    local all = Backpack.getAllItems()
    if category == "all" then return all end

    local filtered = {}
    for _, item in ipairs(all) do
        if item.def.category == category then
            table.insert(filtered, item)
        end
    end
    return filtered
end

-- Sell item for coins
function Backpack.sellItem(itemId, quantity)
    Backpack.init()
    quantity = quantity or 1

    local itemDef = Backpack.getItemDef(itemId)
    if not itemDef or not itemDef.sellValue then
        return false, "Cannot sell this item"
    end

    if not Backpack.hasItem(itemId, quantity) then
        return false, "Not enough items"
    end

    local totalValue = itemDef.sellValue * quantity
    Backpack.removeItem(itemId, quantity)
    PlayerData.coins = PlayerData.coins + totalValue
    savePlayerData()

    return true, totalValue
end

-- Use consumable item
function Backpack.useItem(itemId)
    Backpack.init()

    local itemDef = Backpack.getItemDef(itemId)
    if not itemDef or (itemDef.category ~= "consumable" and itemDef.category ~= "special" and itemDef.category ~= "potion" and itemDef.category ~= "tq_potion") then
        return false, "Cannot use this item"
    end

    if not Backpack.hasItem(itemId) then
        return false, "Don't have this item"
    end

    -- Helper: get the RPG player data if available
    local function getRPGPlayer()
        if PlayerData and PlayerData.textRPG and PlayerData.textRPG.player then
            return PlayerData.textRPG.player
        end
        return nil
    end

    -- Handle special item effects
    local effect = nil
    if itemId == "xp_boost" then
        local Progression = require("progression")
        Progression.addXP(500, "game")
        effect = "Gained 500 XP!"
    elseif itemId == "lucky_charm" then
        effect = "Luck increased for 5 spins!"
        -- Would need to track this in game state
    elseif itemId == "health_potion" then
        local player = getRPGPlayer()
        if player then
            local maxHP = player.maxHP or player.maxHp or 100
            local healAmount = 30
            player.hp = math.min(maxHP, (player.hp or 0) + healAmount)
            effect = "Restored " .. healAmount .. " HP!"
        else
            effect = "Health restored!"
        end
    elseif itemId == "mana_potion" then
        local player = getRPGPlayer()
        if player then
            local maxMana = player.maxMana or 50
            local manaAmount = 20
            player.mana = math.min(maxMana, (player.mana or 0) + manaAmount)
            effect = "Restored " .. manaAmount .. " Mana!"
        else
            effect = "Mana restored!"
        end
    elseif itemId == "health_potion_crafted" then
        local player = getRPGPlayer()
        if player then
            local maxHP = player.maxHP or player.maxHp or 100
            local healAmount = (itemDef.baseStats and itemDef.baseStats.healing) or 50
            player.hp = math.min(maxHP, (player.hp or 0) + healAmount)
            effect = "Restored " .. healAmount .. " HP!"
        else
            effect = "Health restored!"
        end
    elseif itemId == "mana_potion_crafted" then
        local player = getRPGPlayer()
        if player then
            local maxMana = player.maxMana or 50
            local manaAmount = (itemDef.baseStats and itemDef.baseStats.manaRestore) or 30
            player.mana = math.min(maxMana, (player.mana or 0) + manaAmount)
            effect = "Restored " .. manaAmount .. " Mana!"
        else
            effect = "Mana restored!"
        end
    elseif itemId == "tq_health_potion" then
        local player = getRPGPlayer()
        if player then
            local maxHP = player.maxHP or player.maxHp or 100
            local healAmount = (itemDef.baseStats and itemDef.baseStats.heal) or 30
            player.hp = math.min(maxHP, (player.hp or 0) + healAmount)
            effect = "Restored " .. healAmount .. " HP!"
        else
            effect = "Health restored!"
        end
    elseif itemId == "tq_mana_potion" then
        local player = getRPGPlayer()
        if player then
            local maxMana = player.maxMana or 50
            local manaAmount = (itemDef.baseStats and itemDef.baseStats.mana) or 30
            player.mana = math.min(maxMana, (player.mana or 0) + manaAmount)
            effect = "Restored " .. manaAmount .. " Mana!"
        else
            effect = "Mana restored!"
        end
    elseif itemId == "tq_elixir" then
        local player = getRPGPlayer()
        if player then
            local maxHP = player.maxHP or player.maxHp or 100
            local maxMana = player.maxMana or 50
            local healAmount = (itemDef.baseStats and itemDef.baseStats.heal) or 100
            local manaAmount = (itemDef.baseStats and itemDef.baseStats.mana) or 50
            player.hp = math.min(maxHP, (player.hp or 0) + healAmount)
            player.mana = math.min(maxMana, (player.mana or 0) + manaAmount)
            effect = "Restored " .. healAmount .. " HP and " .. manaAmount .. " Mana!"
        else
            effect = "Health and Mana restored!"
        end
    elseif itemDef.category == "potion" and itemDef.baseStats then
        -- Generic handler for other crafted potions (strength, speed, defense, regen, etc.)
        local player = getRPGPlayer()
        if player then
            if itemDef.baseStats.healing then
                local maxHP = player.maxHP or player.maxHp or 100
                player.hp = math.min(maxHP, (player.hp or 0) + itemDef.baseStats.healing)
                effect = "Restored " .. itemDef.baseStats.healing .. " HP!"
            elseif itemDef.baseStats.manaRestore then
                local maxMana = player.maxMana or 50
                player.mana = math.min(maxMana, (player.mana or 0) + itemDef.baseStats.manaRestore)
                effect = "Restored " .. itemDef.baseStats.manaRestore .. " Mana!"
            elseif itemDef.baseStats.healPerSecond then
                effect = "Regeneration active for " .. (itemDef.baseStats.duration or 30) .. "s!"
            else
                effect = "Used " .. (itemDef.name or "potion") .. "!"
            end
        else
            effect = "Used " .. (itemDef.name or "potion") .. "!"
        end
    elseif itemId == "mystery_box" then
        -- Random reward
        local rewards = {"gold_coin", "gem_ruby", "xp_boost", "lucky_charm"}
        local reward = rewards[math.random(#rewards)]
        Backpack.addItem(reward, 1)
        local rewardDef = Backpack.getItemDef(reward)
        effect = "Found: " .. (rewardDef and rewardDef.name or reward)
    end

    Backpack.removeItem(itemId, 1)
    return true, effect
end

-- UI State for backpack view
local uiState = {
    isOpen = false,
    selectedCategory = "all",
    selectedItem = nil,
    scrollOffset = 0,
    maxScroll = 0,
    hoveredItem = nil,
    hoverTimer = 0,
}

-- UI Components (created dynamically)
local uiComponents = {
    tabBar = nil,
    scrollContainer = nil,
    closeButton = nil,
}

-- Toggle backpack UI
function Backpack.toggle()
    uiState.isOpen = not uiState.isOpen
    uiState.selectedItem = nil
    uiState.scrollOffset = 0
    uiState.hoveredItem = nil
end

function Backpack.isOpen()
    return uiState.isOpen
end

function Backpack.close()
    uiState.isOpen = false
end

-- Update hover timer and UI components
function Backpack.update(dt)
    if uiState.hoveredItem then
        uiState.hoverTimer = uiState.hoverTimer + dt
    else
        uiState.hoverTimer = 0
    end

    -- Update UI components
    if uiState.isOpen then
        UI.anim.update(dt)
        if uiComponents.tabBar then
            uiComponents.tabBar:update(dt)
        end
        if uiComponents.scrollContainer then
            uiComponents.scrollContainer:update(dt)
        end
        if uiComponents.closeButton then
            uiComponents.closeButton:update(dt)
        end
    end
end

-- Draw backpack UI overlay (FULLSCREEN)
function Backpack.draw()
    if not uiState.isOpen then return end

    Backpack.init()
    local UIAssets = require("uiassets")
    local screenW, screenH = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()

    -- Fullscreen overlay background
    love.graphics.setColor(UI.theme.colors.overlay)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Panel takes most of screen with padding
    local padding = 40
    local panelX = padding
    local panelY = padding
    local panelW = screenW - padding * 2
    local panelH = screenH - padding * 2

    -- Try to use backpack background image
    local backpackBg = UIAssets.getGameBackground("backpack")
    if backpackBg then
        love.graphics.setColor(1, 1, 1, 0.3)
        local imgW, imgH = backpackBg:getDimensions()
        local scaleX = panelW / imgW
        local scaleY = panelH / imgH
        local scale = math.max(scaleX, scaleY)
        love.graphics.draw(backpackBg, panelX, panelY, 0, scale, scale)
    end

    -- Dark panel overlay using UI theme
    love.graphics.setColor(UI.theme.colors.bg[1], UI.theme.colors.bg[2], UI.theme.colors.bg[3], 0.95)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, UI.theme.radius.lg, UI.theme.radius.lg)
    love.graphics.setColor(UI.theme.colors.panelBorder)
    love.graphics.setLineWidth(UI.theme.border.thick)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, UI.theme.radius.lg, UI.theme.radius.lg)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(UI.theme.colors.textAccent)
    love.graphics.setFont(UI.fonts.get(32))
    love.graphics.print("BACKPACK", panelX + 30, panelY + 20)

    -- Create/update close button
    local closeX = panelX + panelW - 50
    local closeY = panelY + 15
    if not uiComponents.closeButton then
        uiComponents.closeButton = UI.Button.new({
            x = closeX,
            y = closeY,
            w = 40,
            h = 40,
            text = "X",
            variant = "danger",
            onClick = function()
                Backpack.close()
            end
        })
    else
        -- Update position in case of window resize
        uiComponents.closeButton.x = closeX
        uiComponents.closeButton.y = closeY
    end
    uiComponents.closeButton:draw()

    -- Equipped slots section
    local equippedY = panelY + 70
    love.graphics.setColor(UI.theme.colors.bgDark)
    love.graphics.rectangle("fill", panelX + 30, equippedY, panelW - 60, 70, UI.theme.radius.md, UI.theme.radius.md)

    -- Pet companion slot
    local petSlotX = panelX + 50
    local petSlotY = equippedY + 10
    local petSlotW = 220
    local petSlotH = 50
    local equippedPet = Backpack.getEquippedPet()

    love.graphics.setColor(UI.theme.colors.bgLight)
    love.graphics.rectangle("fill", petSlotX, petSlotY, petSlotW, petSlotH, UI.theme.radius.sm, UI.theme.radius.sm)
    love.graphics.setColor(UI.theme.colors.panelBorder)
    love.graphics.setLineWidth(UI.theme.border.normal)
    love.graphics.rectangle("line", petSlotX, petSlotY, petSlotW, petSlotH, UI.theme.radius.sm, UI.theme.radius.sm)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(UI.fonts.get(11))
    love.graphics.setColor(UI.theme.colors.textDim)
    love.graphics.print("Pet Companion", petSlotX + 8, petSlotY + 4)

    if equippedPet then
        love.graphics.setColor(UI.theme.colors.text)
        love.graphics.setFont(UI.fonts.get(13))
        love.graphics.print(equippedPet.name, petSlotX + 12, petSlotY + 20)
        love.graphics.setColor(UI.theme.colors.success)
        love.graphics.setFont(UI.fonts.get(10))
        love.graphics.print("Battle +" .. Backpack.getPetBattleBonus(), petSlotX + 12, petSlotY + 36)
    else
        love.graphics.setColor(UI.theme.colors.textDim)
        love.graphics.setFont(UI.fonts.get(11))
        love.graphics.print("None equipped", petSlotX + 12, petSlotY + 26)
    end

    -- Mount slot
    local mountSlotX = panelX + 300
    local equippedMount = Backpack.getEquippedMount()

    love.graphics.setColor(UI.theme.colors.bgLight)
    love.graphics.rectangle("fill", mountSlotX, petSlotY, petSlotW, petSlotH, UI.theme.radius.sm, UI.theme.radius.sm)
    love.graphics.setColor(UI.theme.colors.panelBorder)
    love.graphics.setLineWidth(UI.theme.border.normal)
    love.graphics.rectangle("line", mountSlotX, petSlotY, petSlotW, petSlotH, UI.theme.radius.sm, UI.theme.radius.sm)
    love.graphics.setLineWidth(1)

    love.graphics.setFont(UI.fonts.get(11))
    love.graphics.setColor(UI.theme.colors.textDim)
    love.graphics.print("Mount", mountSlotX + 8, petSlotY + 4)

    if equippedMount then
        love.graphics.setColor(UI.theme.colors.text)
        love.graphics.setFont(UI.fonts.get(13))
        love.graphics.print(equippedMount.name, mountSlotX + 12, petSlotY + 20)

        local typeInfo = {land = "Land 2x", flying = "Flying 4x", aquatic = "Water 2x"}
        love.graphics.setColor(UI.theme.colors.info)
        love.graphics.setFont(UI.fonts.get(10))
        love.graphics.print(typeInfo[equippedMount.mountType] or "???", mountSlotX + 12, petSlotY + 36)
    else
        love.graphics.setColor(UI.theme.colors.textDim)
        love.graphics.setFont(UI.fonts.get(11))
        love.graphics.print("None equipped", mountSlotX + 12, petSlotY + 26)
    end

    -- Speed info
    love.graphics.setColor(UI.theme.colors.textDim)
    love.graphics.setFont(UI.fonts.get(12))
    local speedMult = Backpack.getMountSpeedMultiplier()
    love.graphics.print("Travel Speed: " .. speedMult .. "x", panelX + 550, petSlotY + 20)

    -- Category tabs using UI.TabBar
    local tabY = panelY + 155
    local tabX = panelX + 30
    local tabW = panelW - 60

    -- Create/update tab bar
    if not uiComponents.tabBar then
        local tabs = {}
        for _, cat in ipairs(Backpack.CATEGORIES) do
            table.insert(tabs, {id = cat, label = cat:upper()})
        end
        uiComponents.tabBar = UI.TabBar.new({
            x = tabX,
            y = tabY,
            w = tabW,
            tabs = tabs,
            activeTab = uiState.selectedCategory,
            onChange = function(tabId)
                uiState.selectedCategory = tabId
                uiState.selectedItem = nil
                uiState.scrollOffset = 0
            end
        })
    else
        -- Update position and active tab
        uiComponents.tabBar.x = tabX
        uiComponents.tabBar.y = tabY
        uiComponents.tabBar.w = tabW
        uiComponents.tabBar.activeTab = uiState.selectedCategory
    end
    uiComponents.tabBar:draw()

    -- Item grid area
    local gridX = panelX + 30
    local gridY = panelY + 205
    local gridW = panelW - 60
    local gridH = panelH - 290

    love.graphics.setColor(UI.theme.colors.bgDark)
    love.graphics.rectangle("fill", gridX, gridY, gridW, gridH, UI.theme.radius.md, UI.theme.radius.md)

    -- Get items for current category
    local items = Backpack.getItemsByCategory(uiState.selectedCategory)

    local itemSize = 80
    local itemPadding = 12
    local cols = math.max(1, math.floor((gridW - 20) / (itemSize + itemPadding)))
    local rows = math.ceil(#items / cols)
    local contentWidth = cols * (itemSize + itemPadding)
    local contentHeight = rows * (itemSize + itemPadding)
    local startX = gridX + (gridW - contentWidth) / 2

    -- Calculate max scroll
    uiState.maxScroll = math.max(0, contentHeight - gridH + 20)

    -- Create/update scroll container
    if not uiComponents.scrollContainer then
        uiComponents.scrollContainer = UI.ScrollContainer.new({
            x = gridX,
            y = gridY,
            w = gridW,
            h = gridH,
            contentHeight = contentHeight
        })
    else
        -- Update position and dimensions
        uiComponents.scrollContainer.x = gridX
        uiComponents.scrollContainer.y = gridY
        uiComponents.scrollContainer.w = gridW
        uiComponents.scrollContainer.h = gridH
        uiComponents.scrollContainer.contentHeight = contentHeight
    end

    -- Sync scroll offset with container
    uiState.scrollOffset = uiComponents.scrollContainer.scrollY

    -- Draw scrollbar using the scroll container
    uiComponents.scrollContainer:draw()

    love.graphics.setScissor(gridX, gridY, gridW - 20, gridH)

    uiState.hoveredItem = nil

    for i, item in ipairs(items) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local x = startX + col * (itemSize + itemPadding)
        local y = gridY + 10 + row * (itemSize + itemPadding) - uiState.scrollOffset

        if y + itemSize >= gridY and y <= gridY + gridH then
            local hover = mx >= x and mx <= x + itemSize and my >= y and my <= y + itemSize and my >= gridY and my <= gridY + gridH
            local isSelected = uiState.selectedItem == item.id

            if hover then
                uiState.hoveredItem = item
            end

            -- Item slot background with rarity color hint using UI theme
            local bgColor = UI.theme.colors.bgLight
            if item.def.category == "weapon" then
                bgColor = {0.2, 0.15, 0.15}
            elseif item.def.category == "armor" then
                bgColor = {0.15, 0.15, 0.2}
            elseif item.def.category == "spell" then
                bgColor = {0.15, 0.12, 0.2}
            elseif item.def.category == "potion" then
                bgColor = {0.12, 0.18, 0.15}
            end

            if isSelected then
                love.graphics.setColor(UI.theme.colors.secondary)
            elseif hover then
                if type(bgColor) == "table" and #bgColor == 3 then
                    love.graphics.setColor(bgColor[1] + 0.1, bgColor[2] + 0.1, bgColor[3] + 0.1)
                else
                    love.graphics.setColor(UI.theme.colors.bgLight)
                end
            else
                if type(bgColor) == "table" then
                    love.graphics.setColor(bgColor)
                else
                    love.graphics.setColor(UI.theme.colors.bgLight)
                end
            end
            love.graphics.rectangle("fill", x, y, itemSize, itemSize, UI.theme.radius.md, UI.theme.radius.md)

            -- Border
            if isSelected then
                love.graphics.setColor(UI.theme.colors.info)
                love.graphics.setLineWidth(UI.theme.border.normal)
            else
                love.graphics.setColor(UI.theme.colors.panelBorder)
                love.graphics.setLineWidth(UI.theme.border.thin)
            end
            love.graphics.rectangle("line", x, y, itemSize, itemSize, UI.theme.radius.md, UI.theme.radius.md)
            love.graphics.setLineWidth(1)

            -- Item image
            local img = itemImages[item.id]
            if img then
                love.graphics.setColor(1, 1, 1)
                local imgW, imgH = img:getDimensions()
                local imgSize = itemSize - 24
                local scale = imgSize / math.max(imgW, imgH)
                local drawX = x + (itemSize - imgW * scale) / 2
                local drawY = y + 4
                love.graphics.draw(img, drawX, drawY, 0, scale, scale)
            else
                -- Placeholder icon
                love.graphics.setColor(UI.theme.colors.textDim)
                love.graphics.rectangle("fill", x + 15, y + 10, itemSize - 30, itemSize - 35, 4, 4)
            end

            -- Item name (truncated)
            love.graphics.setColor(UI.theme.colors.text)
            love.graphics.setFont(UI.fonts.get(9))
            local displayName = item.def.name:sub(1, 10)
            if #item.def.name > 10 then displayName = displayName .. ".." end
            love.graphics.printf(displayName, x, y + itemSize - 18, itemSize, "center")

            -- Quantity badge
            if item.quantity > 1 then
                love.graphics.setColor(0, 0, 0, 0.8)
                love.graphics.rectangle("fill", x + itemSize - 26, y + 4, 22, 16, 4, 4)
                love.graphics.setColor(UI.theme.colors.textAccent)
                love.graphics.setFont(UI.fonts.get(11))
                love.graphics.printf(tostring(item.quantity), x + itemSize - 26, y + 5, 22, "center")
            end
        end
    end

    love.graphics.setScissor()

    -- Tooltip for hovered item using UI theme
    if uiState.hoveredItem and uiState.hoverTimer > 0.3 then
        local item = uiState.hoveredItem
        local tooltipW = 280
        local tooltipH = 120
        local tooltipX = math.min(mx + 15, screenW - tooltipW - 10)
        local tooltipY = math.min(my + 15, screenH - tooltipH - 10)

        -- Tooltip background
        love.graphics.setColor(UI.theme.colors.panel[1], UI.theme.colors.panel[2], UI.theme.colors.panel[3], 0.98)
        love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipW, tooltipH, UI.theme.radius.md, UI.theme.radius.md)
        love.graphics.setColor(UI.theme.colors.panelBorder)
        love.graphics.setLineWidth(UI.theme.border.normal)
        love.graphics.rectangle("line", tooltipX, tooltipY, tooltipW, tooltipH, UI.theme.radius.md, UI.theme.radius.md)
        love.graphics.setLineWidth(1)

        -- Item name
        love.graphics.setColor(UI.theme.colors.textAccent)
        love.graphics.setFont(UI.fonts.get(14))
        love.graphics.print(item.def.name, tooltipX + 10, tooltipY + 8)

        -- Category
        love.graphics.setColor(UI.theme.colors.textDim)
        love.graphics.setFont(UI.fonts.get(10))
        love.graphics.print("[" .. item.def.category:upper() .. "]", tooltipX + 10, tooltipY + 28)

        -- Description
        love.graphics.setColor(UI.theme.colors.text)
        love.graphics.setFont(UI.fonts.get(11))
        love.graphics.printf(item.def.desc or "No description", tooltipX + 10, tooltipY + 48, tooltipW - 20, "left")

        -- Stats if available
        if item.def.baseStats then
            local statY = tooltipY + 75
            love.graphics.setColor(UI.theme.colors.success)
            love.graphics.setFont(UI.fonts.get(10))
            for stat, value in pairs(item.def.baseStats) do
                love.graphics.print(stat .. ": " .. value, tooltipX + 10, statY)
                statY = statY + 12
            end
        end

        -- Sell value
        if item.def.sellValue then
            love.graphics.setColor(UI.theme.colors.warning)
            love.graphics.setFont(UI.fonts.get(10))
            love.graphics.print("Sell: " .. item.def.sellValue .. " gold", tooltipX + tooltipW - 90, tooltipY + tooltipH - 20)
        end

        -- Quantity
        love.graphics.setColor(UI.theme.colors.textDim)
        love.graphics.print("Qty: " .. item.quantity, tooltipX + 10, tooltipY + tooltipH - 20)
    end

    -- Selected item action bar at bottom using UI theme
    if uiState.selectedItem then
        local itemDef = Backpack.getItemDef(uiState.selectedItem)
        local quantity = Backpack.getItemCount(uiState.selectedItem)

        if itemDef then
            local actionY = panelY + panelH - 70
            love.graphics.setColor(UI.theme.colors.panel)
            love.graphics.rectangle("fill", panelX + 30, actionY, panelW - 60, 55, UI.theme.radius.md, UI.theme.radius.md)

            -- Item image in action bar
            local img = itemImages[uiState.selectedItem]
            if img then
                love.graphics.setColor(1, 1, 1)
                local imgW, imgH = img:getDimensions()
                local scale = 40 / math.max(imgW, imgH)
                love.graphics.draw(img, panelX + 45, actionY + 7, 0, scale, scale)
            end

            -- Item name and quantity
            love.graphics.setColor(UI.theme.colors.text)
            love.graphics.setFont(UI.fonts.get(16))
            love.graphics.print(itemDef.name .. " x" .. quantity, panelX + 100, actionY + 8)

            love.graphics.setColor(UI.theme.colors.textDim)
            love.graphics.setFont(UI.fonts.get(12))
            love.graphics.print(itemDef.desc or "", panelX + 100, actionY + 30)

            -- Action buttons
            local btnX = panelX + panelW - 200

            -- Sell button if sellable
            if itemDef.sellValue then
                local sellHover = mx >= btnX and mx <= btnX + 80 and my >= actionY + 10 and my <= actionY + 45
                love.graphics.setColor(sellHover and UI.theme.colors.success or {UI.theme.colors.success[1] * 0.7, UI.theme.colors.success[2] * 0.7, UI.theme.colors.success[3] * 0.7})
                love.graphics.rectangle("fill", btnX, actionY + 10, 80, 35, UI.theme.radius.sm, UI.theme.radius.sm)
                love.graphics.setColor(UI.theme.colors.text)
                love.graphics.setFont(UI.fonts.get(13))
                love.graphics.printf("Sell", btnX, actionY + 14, 80, "center")
                love.graphics.setFont(UI.fonts.get(10))
                love.graphics.printf(itemDef.sellValue .. "g", btnX, actionY + 30, 80, "center")
            end

            -- Use button if usable
            if itemDef.category == "consumable" or itemDef.category == "special" or itemDef.category == "potion" or itemDef.category == "tq_potion" then
                local useX = btnX + 90
                local useHover = mx >= useX and mx <= useX + 80 and my >= actionY + 10 and my <= actionY + 45
                love.graphics.setColor(useHover and UI.theme.colors.secondary or {UI.theme.colors.secondary[1] * 0.7, UI.theme.colors.secondary[2] * 0.7, UI.theme.colors.secondary[3] * 0.7})
                love.graphics.rectangle("fill", useX, actionY + 10, 80, 35, UI.theme.radius.sm, UI.theme.radius.sm)
                love.graphics.setColor(UI.theme.colors.text)
                love.graphics.setFont(UI.fonts.get(13))
                love.graphics.printf("Use", useX, actionY + 20, 80, "center")
            end
        end
    end

    -- Empty message
    if #items == 0 then
        love.graphics.setColor(UI.theme.colors.textDim)
        love.graphics.setFont(UI.fonts.get(18))
        love.graphics.printf("No items in this category", gridX, gridY + gridH/2 - 10, gridW, "center")
    end

    -- Controls hint
    love.graphics.setColor(UI.theme.colors.textDim)
    love.graphics.setFont(UI.fonts.get(11))
    love.graphics.print("[B] Close  |  Scroll to navigate  |  Click to select", panelX + 30, panelY + panelH - 25)
end

-- Handle mouse input
function Backpack.mousepressed(x, y, button)
    if not uiState.isOpen then return false end
    if button ~= 1 then return true end

    local screenW, screenH = love.graphics.getDimensions()
    local padding = 40
    local panelX = padding
    local panelY = padding
    local panelW = screenW - padding * 2
    local panelH = screenH - padding * 2

    -- Check close button component
    if uiComponents.closeButton then
        if uiComponents.closeButton:mousepressed(x, y, button) then
            return true
        end
    end

    -- Check tab bar component
    if uiComponents.tabBar then
        if uiComponents.tabBar:mousepressed(x, y, button) then
            return true
        end
    end

    -- Check scroll container
    if uiComponents.scrollContainer then
        if uiComponents.scrollContainer:mousepressed(x, y, button) then
            return true
        end
    end

    -- Item grid clicks
    local gridX = panelX + 30
    local gridY = panelY + 205
    local gridW = panelW - 60
    local gridH = panelH - 290

    if x >= gridX and x <= gridX + gridW - 20 and y >= gridY and y <= gridY + gridH then
        local items = Backpack.getItemsByCategory(uiState.selectedCategory)
        local itemSize = 80
        local itemPadding = 12
        local cols = math.max(1, math.floor((gridW - 20) / (itemSize + itemPadding)))
        local contentWidth = cols * (itemSize + itemPadding)
        local startX = gridX + (gridW - contentWidth) / 2

        for i, item in ipairs(items) do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            local ix = startX + col * (itemSize + itemPadding)
            local iy = gridY + 10 + row * (itemSize + itemPadding) - uiState.scrollOffset

            if x >= ix and x <= ix + itemSize and y >= iy and y <= iy + itemSize and y >= gridY and y <= gridY + gridH then
                uiState.selectedItem = item.id
                return true
            end
        end
    end

    -- Action buttons for selected item
    if uiState.selectedItem then
        local itemDef = Backpack.getItemDef(uiState.selectedItem)
        if itemDef then
            local actionY = panelY + panelH - 70
            local btnX = panelX + panelW - 200

            -- Sell button
            if itemDef.sellValue then
                if x >= btnX and x <= btnX + 80 and y >= actionY + 10 and y <= actionY + 45 then
                    Backpack.sellItem(uiState.selectedItem, 1)
                    if not Backpack.hasItem(uiState.selectedItem) then
                        uiState.selectedItem = nil
                    end
                    return true
                end
            end

            -- Use button
            if itemDef.category == "consumable" or itemDef.category == "special" or itemDef.category == "potion" or itemDef.category == "tq_potion" then
                local useX = btnX + 90
                if x >= useX and x <= useX + 80 and y >= actionY + 10 and y <= actionY + 45 then
                    Backpack.useItem(uiState.selectedItem)
                    if not Backpack.hasItem(uiState.selectedItem) then
                        uiState.selectedItem = nil
                    end
                    return true
                end
            end
        end
    end

    return true
end

-- Handle mouse release
function Backpack.mousereleased(x, y, button)
    if not uiState.isOpen then return false end

    -- Release close button
    if uiComponents.closeButton then
        uiComponents.closeButton:mousereleased(x, y, button)
    end

    -- Release scroll container
    if uiComponents.scrollContainer then
        if uiComponents.scrollContainer:mousereleased(x, y, button) then
            return true
        end
    end

    return false
end

-- Handle scroll
function Backpack.wheelmoved(x, y)
    if not uiState.isOpen then return false end

    -- Pass to scroll container component
    if uiComponents.scrollContainer then
        if uiComponents.scrollContainer:wheelmoved(x, y) then
            -- Sync back to uiState for compatibility
            uiState.scrollOffset = uiComponents.scrollContainer.scrollY
            return true
        end
    end

    -- Fallback to manual scroll
    uiState.scrollOffset = uiState.scrollOffset - y * 40
    uiState.scrollOffset = math.max(0, math.min(uiState.scrollOffset, uiState.maxScroll))
    return true
end

-- Handle keyboard
function Backpack.keypressed(key)
    if key == "b" or key == "i" then
        Backpack.toggle()
        return true
    end
    if uiState.isOpen and key == "escape" then
        Backpack.close()
        return true
    end
    return false
end

return Backpack
