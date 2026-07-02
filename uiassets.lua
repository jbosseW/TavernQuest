-- UI Assets Module - Loads and provides UI graphics
local UIAssets = {}

-- Font cache for performance
local FontCache = require("fontcache")
local function getFont(size)
    return FontCache.get(size)
end

-- Try to load asset pipeline (optional, for dynamic asset management)
-- assetpipeline.lua consolidates assetconfig + assetloader + assetscanner
local AssetConfig = nil
pcall(function()
    local pipeline = require("assetpipeline")
    AssetConfig = pipeline.config
end)

-- Cached images
UIAssets.images = {}
UIAssets.loaded = false

-- Asset paths (restricted to assets/ folder)
local ASSETS_BASE = "assets/"
local UI_PATH = ASSETS_BASE .. "ui/"
local CHAR_PATH = ASSETS_BASE .. "characters/"
local MUSIC_PATH = ASSETS_BASE .. "music/"
local ICON_PATH = ASSETS_BASE .. "icons/"

-- Icon categories with subfolder paths
UIAssets.iconPaths = {
    armor = ICON_PATH .. "armor/",
    weapons = ICON_PATH .. "weapons/",
    items = ICON_PATH .. "items/",
    loot = ICON_PATH .. "loot/",
    resources = ICON_PATH .. "resourcesandfood/",
    food = ICON_PATH .. "resourcesandfood/",
    skills = ICON_PATH .. "skills/",
    quest = ICON_PATH .. "quest/",
    tech = ICON_PATH .. "tech/",
    building = ICON_PATH .. "buildingmaterialicons/",
    professions = ICON_PATH .. "professions/ProfessionAndCraftIcons/",
}

-- Commonly used icons mapped to friendly names
UIAssets.iconRegistry = {
    -- Currency
    gold_coin = {path = "resourcesandfood", file = "GoldCoin.PNG"},
    gold_coin_stack = {path = "resourcesandfood", file = "GoldCoinTen.PNG"},
    silver_coin = {path = "resourcesandfood", file = "SilverCoin.PNG"},
    silver_coin_stack = {path = "resourcesandfood", file = "SilverCoinTen.PNG"},
    copper_coin = {path = "resourcesandfood", file = "CopperCoin.PNG"},
    copper_coin_stack = {path = "resourcesandfood", file = "CopperCoinTen.PNG"},
    bag_of_gold = {path = "resourcesandfood", file = "BagOfGold.PNG"},

    -- Chests/Loot Boxes
    chest_common = {path = "loot", file = "Loot_101_chest.PNG"},
    chest_uncommon = {path = "loot", file = "Loot_102_chest.PNG"},
    chest_rare = {path = "loot", file = "Loot_103_chest.PNG"},
    chest_epic = {path = "loot", file = "Loot_104_chest.PNG"},
    chest_mythic = {path = "loot", file = "Loot_105_chest.PNG"},
    chest_legendary = {path = "loot", file = "Loot_106_chest.PNG"},
    chest_ultimate = {path = "loot", file = "Loot_107_chest.PNG"},
    wooden_chest = {path = "resourcesandfood", file = "WoodenChest.PNG"},
    wooden_box = {path = "resourcesandfood", file = "WoodenBox.PNG"},
    mystery_box = {path = "tech", file = "Tech_RandomBox.PNG"},

    -- Keys
    key_common = {path = "loot", file = "Loot_54_key.PNG"},
    key_silver = {path = "loot", file = "Loot_55_key.PNG"},
    key_gold = {path = "loot", file = "Loot_56_key.PNG"},
    key_magic = {path = "loot", file = "Loot_57_key.PNG"},
    key_ancient = {path = "loot", file = "Loot_58_key.PNG"},
    key_master = {path = "loot", file = "Loot_59_key.PNG"},

    -- Bags/Containers
    bag_brown = {path = "resourcesandfood", file = "BagBrown.PNG"},
    bag_black = {path = "resourcesandfood", file = "BlackBag.PNG"},
    bag_red = {path = "resourcesandfood", file = "RedBag.PNG"},
    bag_master = {path = "resourcesandfood", file = "MasterBag.PNG"},
    basket = {path = "resourcesandfood", file = "Basket.PNG"},

    -- Food Items
    bread = {path = "resourcesandfood", file = "Bread.PNG"},
    bread_alt = {path = "resourcesandfood", file = "Bread2.PNG"},
    cheese = {path = "resourcesandfood", file = "Cheese.PNG"},
    carrot = {path = "resourcesandfood", file = "Carrot.PNG"},
    egg = {path = "resourcesandfood", file = "Egg.PNG"},
    fried_egg = {path = "resourcesandfood", file = "FriedEgg.PNG"},
    chicken_leg = {path = "resourcesandfood", file = "FriedChickenLeg.PNG"},
    raw_chicken = {path = "resourcesandfood", file = "RawChickenLeg.PNG"},
    fish = {path = "resourcesandfood", file = "FishRed.PNG"},
    fish_fried = {path = "resourcesandfood", file = "FishRedFried.PNG"},
    steak = {path = "loot", file = "Loot_89_steak.PNG"},
    cake = {path = "resourcesandfood", file = "Cake.PNG"},
    honey = {path = "resourcesandfood", file = "Honey.PNG"},
    milk = {path = "resourcesandfood", file = "Milk.PNG"},
    wine_bottle = {path = "resourcesandfood", file = "BottleOfWine.PNG"},
    wine_glass = {path = "resourcesandfood", file = "GlassOfWine.PNG"},
    fruit_juice = {path = "resourcesandfood", file = "FruitJuice.PNG"},
    salad = {path = "resourcesandfood", file = "Salad.PNG"},
    soup = {path = "loot", file = "Soup.PNG"},
    mushrooms = {path = "resourcesandfood", file = "Mushrooms.PNG"},
    apple = {path = "resourcesandfood", file = "Res_135_apple.PNG"},
    banana = {path = "resourcesandfood", file = "Res_138_banana.PNG"},

    -- Potions
    potion_health = {path = "items", file = "Alchemy_13_heal_potion.PNG"},
    potion_health_small = {path = "items", file = "Alchemy_21_littleheal_flask.PNG"},
    potion_health_big = {path = "items", file = "Alchemy_31_bigheal_flask.PNG"},
    potion_mana = {path = "items", file = "Alchemy_17_blue_potion.PNG"},
    potion_mana_small = {path = "items", file = "Alchemy_20_littlemana_flask.PNG"},
    potion_mana_big = {path = "items", file = "Alchemy_30_bigmana_flask.PNG"},
    potion_energy = {path = "items", file = "Alchemy_24_energy_potion.PNG"},
    potion_stamina = {path = "items", file = "Alchemy_25_stamina_potion.PNG"},
    potion_poison = {path = "items", file = "Alchemy_14_poison.PNG"},
    potion_shadow = {path = "items", file = "Alchemy_16_shadow_potion.PNG"},
    potion_invisibility = {path = "items", file = "Alchemy_35_invisibility_flask.PNG"},
    potion_immortal = {path = "items", file = "Alchemy_26_immortal_potion.PNG"},
    potion_generic_1 = {path = "items", file = "Potion_01.PNG"},
    potion_generic_2 = {path = "items", file = "Potion_02.PNG"},
    potion_generic_3 = {path = "items", file = "Potion_03.PNG"},

    -- Resources/Bars
    gold_bar = {path = "resourcesandfood", file = "Res_03_goldenbar.PNG"},
    silver_bar = {path = "resourcesandfood", file = "SilverBar.PNG"},
    copper_bar = {path = "resourcesandfood", file = "CopperBar.PNG"},
    iron_bar = {path = "resourcesandfood", file = "Res_07_ironbar.PNG"},
    magic_bar = {path = "resourcesandfood", file = "Res_05_magicbar.PNG"},
    wood = {path = "resourcesandfood", file = "Res_04_wood.PNG"},
    logs = {path = "resourcesandfood", file = "Logs.PNG"},
    stones = {path = "resourcesandfood", file = "Stones.PNG"},
    coal = {path = "resourcesandfood", file = "Coal.PNG"},

    -- Misc Items
    book = {path = "resourcesandfood", file = "Book.PNG"},
    book_alt = {path = "resourcesandfood", file = "Book2.PNG"},
    candle = {path = "resourcesandfood", file = "Candle.PNG"},
    torch = {path = "resourcesandfood", file = "Torch.PNG"},
    torch_lit = {path = "resourcesandfood", file = "TorchFire.PNG"},
    crown = {path = "resourcesandfood", file = "Crown.PNG"},
    pearl = {path = "resourcesandfood", file = "Pearl.PNG"},
    ring_gold = {path = "resourcesandfood", file = "RingGold.PNG"},
    ring_silver = {path = "resourcesandfood", file = "RingSilver.PNG"},
    necklace_gold = {path = "resourcesandfood", file = "NecklaceGold.PNG"},
    gold_cup = {path = "resourcesandfood", file = "GoldCup.PNG"},
    gold_statue = {path = "resourcesandfood", file = "GoldStatue.PNG"},
    map = {path = "loot", file = "Loot_153_map.PNG"},
    compass = {path = "loot", file = "Loot_151_compass.PNG"},
    spyglass = {path = "loot", file = "Loot_150_Spyglass.PNG"},

    -- Combat Items
    bandage = {path = "loot", file = "Loot_165_bandage.PNG"},
    bomb = {path = "loot", file = "Loot_173_bomb.PNG"},
    dynamite = {path = "loot", file = "Loot_169_dynamite.PNG"},
    trap = {path = "loot", file = "Loot_152_trap.PNG"},

    -- Joker/Card related
    playing_cards = {path = "resourcesandfood", file = "poker.PNG"},

    -- Pet Food/Toys (for pet sim)
    pet_food_basic = {path = "resourcesandfood", file = "BowlMeat.PNG"},
    pet_food_fish = {path = "resourcesandfood", file = "FishRed.PNG"},
    pet_treat = {path = "resourcesandfood", file = "Res_147_candy.PNG"},

    -- Currency Icons (for UI displays)
    crystal = {path = "resourcesandfood", file = "Res_167_MageCrystal.PNG"},
    crystal_blue = {path = "resourcesandfood", file = "Res_25_crystal.PNG"},
    crystal_red = {path = "resourcesandfood", file = "Res_76_crystalRed.PNG"},
    crystal_small = {path = "resourcesandfood", file = "Res_75_crystalS.PNG"},
    flux = {path = "resourcesandfood", file = "Res_167_MageCrystal.PNG"},

    -- Mystery/Magic items
    mystery_crate = {path = "loot", file = "Loot_139_boxCOntainer.PNG"},
    rune_stone = {path = "loot", file = "Loot_82_runestone.PNG"},
    magic_orb = {path = "loot", file = "Loot_53_sphere.PNG"},

    -- Crafting/Resources
    leather = {path = "loot", file = "Loot_112_leather.PNG"},
    thread = {path = "loot", file = "Loot_115_thread.PNG"},
    nails = {path = "loot", file = "Loot_158_nails.PNG"},
    anvil = {path = "loot", file = "Loot_130_anvil.PNG"},

    -- Fishing items
    fishing_rod = {path = "quest", file = "Quest_70_fishingrod.PNG"},
    fishing_icon = {path = "quest", file = "Quest_71_fishing.PNG"},
    fish_raw = {path = "resourcesandfood", file = "Res_140_fish.PNG"},
    fish_cooked = {path = "resourcesandfood", file = "Cooking_47_fish_ready.PNG"},
    ocean_fish = {path = "professions/ProfessionAndCraftIcons/Cooking_fishing", file = "Cooking_60_oceanfish.PNG"},

    -- Forge/Crafting items
    forge = {path = "buildingmaterialicons", file = "Forge.PNG"},
    forge_tech = {path = "tech", file = "Tech_Forge.PNG"},
}

-- Game mode background art (in assets/ root folder)
UIAssets.gameBackgrounds = {
    fishing = "Fishing background art.png",
    forge = "ForgeBackgroundart.png",
    petsim = "Petsim.png",
    slots = "Slots.png",
    cafe = "WageModeBackground.png",
    poker = "Tavern Poker Table.png",
    camp = "Camp exploration.png",
    hunt1 = "Hunt1.png",
    hunt2 = "Hunt2.png",
    hunt3 = "Hunt3.png",
    wizardtower = "MageTowerMode.png",
    alchemist = "AlchemistTowerMode.png",
    backpack = "Backpack.png",
    market_buy = "MarketBuy.png",
    market_sell = "StallMarketSelling.png",
}

-- Exploration backgrounds for Text RPG mode (in assets/Explore/ folder)
UIAssets.exploreBackgrounds = {
    "Camp exploration.png",
    "Fishing background art.png",
    "ForgeBackgroundart.png",
    "Hunt1.png",
    "Hunt2.png",
    "Hunt3.png",
    "Tavern Poker Table.png",
    "WageModeBackground.png",
    "MarketBuy.png",
    "StallMarketSelling.png",
    "Petsim.png",
}

-- UI element definitions
UIAssets.elements = {
    -- Buttons
    button = "button.PNG",
    button2 = "button2.PNG",
    button_agree = "button_agree.PNG",
    button_cancel = "button_cancel.PNG",
    button_frame = "button_frame.PNG",
    button_ready_on = "button_ready_on.PNG",
    button_ready_off = "button_ready_off.PNG",
    button2_ready_on = "button2_ready_on.PNG",
    button2_ready_off = "button2_ready_off.PNG",
    button3_ready = "button3_ready.PNG",

    -- Frames
    frame_big = "Frame_big.PNG",
    frame_mid = "Frame_mid.PNG",
    frame_mid_2 = "Frame_mid_2.PNG",

    -- Backgrounds
    bg_big = "big_background.PNG",
    bg_mid = "mid_background.PNG",
    bg_mini = "Mini_background.PNG",
    bg_round_big = "big_roundframe.PNG",
    bg_round_small = "lil_roundbackground.PNG",

    -- Round frames
    round_frame_big = "big_roundframe.PNG",
    round_frame_small = "lil_roundframe.PNG",
    round_frame_ready = "lil_roundframe_ready.PNG",
    round_frame_ready2 = "lil_roundframe_ready2.PNG",

    -- Mini frames
    mini_frame0 = "Mini_frame0.PNG",
    mini_frame1 = "Mini_frame1.PNG",
    mini_frame2 = "Mini_frame2.PNG",

    -- HP/Status bars
    hp_frame = "Hp_frame.PNG",
    hp_line = "Hp_line.PNG",
    bar_ready = "bar_ready.PNG",
    barmid_ready = "barmid_ready.PNG",

    -- Name bars
    name_bar = "name_bar.PNG",
    name_bar2 = "name_bar2.PNG",
    name_bar3 = "name_bar3.PNG",
}

-- Character portrait categories for random selection
-- New folder structure: Human/Men_Human, Human/Women_Human, ELF/Men_ELF, ELF/Women_Elf, ORC/Men_ORC, ORC/Women_ORC, Animals, Monsters
UIAssets.characterCategories = {
    -- Male humans (in Human/Men_Human folder)
    humans_male = {
        "Human/Men_Human/Human_01", "Human/Men_Human/Human_09", "Human/Men_Human/Human_10", "Human/Men_Human/Human_16",
        "Human/Men_Human/Human_21", "Human/Men_Human/Human_22", "Human/Men_Human/Human_23", "Human/Men_Human/Human_24",
        "Human/Men_Human/Human_25", "Human/Men_Human/Human_26", "Human/Men_Human/Human_27", "Human/Men_Human/Human_28",
        "Human/Men_Human/Human_29", "Human/Men_Human/Human_33", "Human/Men_Human/Human_49",
        "Human/Men_Human/Knight_Man", "Human/Men_Human/Knight2_Man", "Human/Men_Human/Knight_Man3",
        "Human/Men_Human/BoldWarrior", "Human/Men_Human/Warrior", "Human/Men_Human/Guard",
        "Human/Men_Human/Duke", "Human/Men_Human/Merchant", "Human/Men_Human/Sage",
        "Human/Men_Human/Viking", "Human/Men_Human/Robber", "Human/Men_Human/Prophet",
        "Human/Men_Human/Footman", "Human/Men_Human/Spearman", "Human/Men_Human/Crossbowman",
        "Human/Men_Human/Human_06_Priest", "Human/Men_Human/Human_23_rogue", "Human/Men_Human/Human_24_ronin",
        "Human/Men_Human/Human_27_alchemyst", "Human/Men_Human/Human_25_barbarian", "Human/Men_Human/Human_20_Samurai",
    },
    -- Female humans (in Human/Women_Human folder)
    humans_female = {
        "Human/Women_Human/Human_02", "Human/Women_Human/Human_03", "Human/Women_Human/Human_04",
        "Human/Women_Human/Human_05", "Human/Women_Human/Human_06", "Human/Women_Human/Human_07",
        "Human/Women_Human/Human_08", "Human/Women_Human/Human_11", "Human/Women_Human/Human_12",
        "Human/Women_Human/Human_13", "Human/Women_Human/Human_14", "Human/Women_Human/Human_15",
        "Human/Women_Human/Human_17", "Human/Women_Human/Human_18", "Human/Women_Human/Human_19",
        "Human/Women_Human/Human_20", "Human/Women_Human/Human_30", "Human/Women_Human/Human_32",
        "Human/Women_Human/Archer_woman", "Human/Women_Human/Assassin", "Human/Women_Human/FrostMage",
        "Human/Women_Human/BlindWoman", "Human/Women_Human/Cultist",
        "Human/Women_Human/Human_05_woman_knight", "Human/Women_Human/Human_07_girl",
        "Human/Women_Human/Human_30_witch", "Human/Women_Human/Human_31_witch",
        "Human/Women_Human/Human_42_queen", "Human/Women_Human/Human_43_queen",
        "Human/Women_Human/Human_50_amazon_warrior",
    },
    -- Male elves (in ELF/Men_ELF folder)
    elves_male = {
        "ELF/Men_ELF/Elf_01_1", "ELF/Men_ELF/Elf_02_1", "ELF/Men_ELF/Elf_05",
        "ELF/Men_ELF/Elf_07", "ELF/Men_ELF/Elf_08", "ELF/Men_ELF/Elf_10",
        "ELF/Men_ELF/Elf_11", "ELF/Men_ELF/ElfWarrior",
    },
    -- Female elves (in ELF/Women_Elf folder)
    elves_female = {
        "ELF/Women_Elf/Elf_01", "ELF/Women_Elf/Elf_02", "ELF/Women_Elf/Elf_03",
        "ELF/Women_Elf/Elf_03_1", "ELF/Women_Elf/Elf_04", "ELF/Women_Elf/Elf_04_hunter",
        "ELF/Women_Elf/Elf_06", "ELF/Women_Elf/Elf_09", "ELF/Women_Elf/ElfMage",
    },
    -- Male orcs (in ORC/Men_ORC folder)
    orcs_male = {
        "ORC/Men_ORC/Orc_01_warrior", "ORC/Men_ORC/Orc_02", "ORC/Men_ORC/Orc_02_warlord",
        "ORC/Men_ORC/Orc_03_shaman", "ORC/Men_ORC/Orc_04_warlock", "ORC/Men_ORC/Orc_05",
        "ORC/Men_ORC/Orc_05_1", "ORC/Men_ORC/Orc_06", "ORC/Men_ORC/Orc_07",
        "ORC/Men_ORC/Orc_08", "ORC/Men_ORC/Orc_09", "ORC/Men_ORC/Orc_6_Hunter",
        "ORC/Men_ORC/Orc_7_Rider", "ORC/Men_ORC/Orc_8_oracle", "ORC/Men_ORC/Orc_9_slave_owner",
    },
    -- Female orcs (in ORC/Women_ORC folder)
    orcs_female = {
        "ORC/Women_ORC/Orc_01", "ORC/Women_ORC/Orc_03", "ORC/Women_ORC/Orc_04",
        "ORC/Women_ORC/Orc_11", "ORC/Women_ORC/Orc_12",
    },
    -- Animals (for pets and creature cards - in Animals folder)
    animals = {
        "Animals/Bat", "Animals/Bear_animal", "Animals/Bird_animal", "Animals/Boar_animal",
        "Animals/Camel_animal", "Animals/Cat_animal", "Animals/Dolphin_animal",
        "Animals/Hawk_animal", "Animals/hippopotamus_nb", "Animals/Horse_animal",
        "Animals/Shark_animal", "Animals/Wolf_animal",
        "Animals/Creatures_10_warhorse", "Animals/Creatures_12_Dog", "Animals/Creatures_15_goat",
        -- Beast-like monsters in Animals folder
        "Animals/Monsters_09", "Animals/Monsters_10", "Animals/Monsters_11", "Animals/Monsters_12",
        "Animals/Monsters_16", "Animals/Monsters_17", "Animals/Monsters_22", "Animals/Monsters_23",
        "Animals/Monsters_24", "Animals/Monsters_34", "Animals/Monsters_35", "Animals/Monsters_36",
        "Animals/Monsters_37", "Animals/Monsters_38", "Animals/Monsters_39", "Animals/Monsters_40",
        "Animals/Monsters_57", "Animals/Monsters_58",
    },
    -- Monsters (for pets and creature cards - in Monsters folder)
    monsters = {
        "Monsters/Creatures_01_Manticore", "Monsters/Creatures_03_griffin", "Monsters/Creatures_05_werewolf",
        "Monsters/Creatures_07_phoenix", "Monsters/Creatures_08_spider", "Monsters/Creatures_11_Dragon",
        "Monsters/Creatures_14_ratman", "Monsters/Demon_04_succubus", "Monsters/Demon_08_spider",
        "Monsters/Demon_12_skeleton_king", "Monsters/DemonicTentacles", "Monsters/Devourer",
        "Monsters/Gigant_05_pangolin", "Monsters/Gigant_08_minotaur",
        "Monsters/Monster_08", "Monsters/Monster_12", "Monsters/Monster_13",
        "Monsters/Monster_DemonicDog", "Monsters/Monster_DemonicEye", "Monsters/Monster_DemonicFish",
        "Monsters/Monster_DragonWarrior", "Monsters/Monster_Elemental", "Monsters/Monster_Eye",
        "Monsters/Monster_fish", "Monsters/Monster_Flower", "Monsters/Monster_Flower2", "Monsters/Monster_Flower3",
        "Monsters/Monster_Fly", "Monsters/Monster_HungryDemon", "Monsters/Monster_InfectedDog",
        "Monsters/Monster_Infection", "Monsters/Monster_Scorpion", "Monsters/Monster_SkeletonSnake",
        "Monsters/Monster_Slime", "Monsters/Monster_Spider", "Monsters/Monster_Swamp",
        "Monsters/Monster_Terrible", "Monsters/Monster_WarDragon", "Monsters/Monster_Wasp",
        "Monsters/Monster_waterm", "Monsters/Monster_Worm",
        "Monsters/Monsters_14", "Monsters/Monsters_18", "Monsters/Monsters_19", "Monsters/Monsters_20",
        "Monsters/Monsters_32", "Monsters/Monsters_42", "Monsters/Monsters_43", "Monsters/Monsters_50",
        "Monsters/Monsters_63", "Monsters/Monsters_64",
    },
    -- Gods (still in root characters folder)
    gods = {"God_Zeus", "God_Hades", "God_Poseidon", "God_Ares", "God_Athena", "God_Apollo", "God_Artemis",
            "God_Aphrodite", "God_Hermes", "God_Hera", "God_Dionysus", "God_Hephaestus"},
    -- Demons (still in root characters folder)
    demons = {"Demon_01", "Demon_02_imp", "Demon_03_Devil", "Demon_05_Lilith",
              "Demon_06_ice", "Demon_07_fire", "Demon_09_death", "Demon_10_succubus", "Demon_11_gargoyle", "Demon_13_guard"},
    -- Undead (still in root characters folder)
    undead = {"Undead_01_archer", "Undead_02_knight", "Undead_03", "Undead_04_warrior", "Undead_05_skeleton",
              "Undead_06_zombie", "Undead_07_soulhunter", "Undead_08_ice_queen", "Undead_09_ghost", "Undead_10_dragon"},
    -- Giants/Gnomes/Goblins (still in root characters folder)
    giants = {"Gigant_01_cyclope", "Gigant_02_old_titan", "Gigant_03_yeti", "Gigant_04_ogre",
              "Gigant_06_ogre_warrior", "Gigant_07_ogre_mage", "Giant_StoneGolem"},
    gnomes = {"Gnome_01", "Gnome_02", "Gnome_03", "Gnome_04", "Gnome_05", "Gnome_06", "Gnome_dark"},
    goblins = {"goblin_01", "goblin_02", "goblin_03", "goblin_04", "goblin_05"},
}

-- Music tracks
UIAssets.music = {
    combat = {
        "01_Horns_Of_War_BattleTrack.WAV",
        "SW_Combat_1.WAV",
    },
    exploration = {
        "05_Misty_Lands_ExplorationTrack.WAV",
        "06_Through_The_Lands_-_Atmospheres_Part_I__ExplorationTrack.WAV",
        "08_Through_The_Lands_-_Atmospheres_Part_II_ExplorationTrack.WAV",
        "09_The_Journey_Begins__ExplorationTrack.WAV",
        "10_Through_The_Lands_-_Atmospheres_Part_III_ExplorationTrack.WAV",
        "SW_Exploration_6.WAV",
    },
    town = {
        "SW_Town_1.WAV",
    },
    menu = {
        "07_Mountain_Halls__ExplorationTrack.WAV",
        "09_The_Journey_Begins__ExplorationTrack.WAV",
    },
}

-- Initialize and load all UI assets
function UIAssets.init()
    if UIAssets.loaded then return end

    -- Load UI elements
    for name, filename in pairs(UIAssets.elements) do
        local path = UI_PATH .. filename
        local success, result = pcall(function()
            return love.graphics.newImage(path)
        end)
        if success then
            UIAssets.images[name] = result
        end
    end

    -- Load main menu background
    local menuBgPath = "assets/mainmenu.png"
    local success, result = pcall(function()
        return love.graphics.newImage(menuBgPath)
    end)
    if success then
        UIAssets.images.mainmenu_bg = result
    end

    -- Load game mode backgrounds
    for mode, filename in pairs(UIAssets.gameBackgrounds) do
        local bgPath = ASSETS_BASE .. filename
        local bgSuccess, bgResult = pcall(function()
            return love.graphics.newImage(bgPath)
        end)
        if bgSuccess then
            UIAssets.images["bg_" .. mode] = bgResult
        end
    end

    UIAssets.loaded = true
end

-- Get a game mode background image
function UIAssets.getGameBackground(mode)
    if not UIAssets.loaded then
        UIAssets.init()
    end
    return UIAssets.images["bg_" .. mode]
end

-- Draw a game mode background (scales to fill screen)
function UIAssets.drawGameBackground(mode, alpha)
    alpha = alpha or 1
    local bg = UIAssets.getGameBackground(mode)
    if bg then
        local screenW, screenH = love.graphics.getDimensions()
        local imgW, imgH = bg:getDimensions()
        local scaleX = screenW / imgW
        local scaleY = screenH / imgH
        local scale = math.max(scaleX, scaleY)  -- Cover entire screen

        -- Center the image
        local offsetX = (screenW - imgW * scale) / 2
        local offsetY = (screenH - imgH * scale) / 2

        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(bg, offsetX, offsetY, 0, scale, scale)
        love.graphics.setColor(1, 1, 1, 1)
        return true
    end
    return false
end

-- Load exploration backgrounds for Text RPG mode
function UIAssets.loadExploreBackgrounds()
    local EXPLORE_PATH = "assets/Explore/"
    for i, filename in ipairs(UIAssets.exploreBackgrounds) do
        local cacheKey = "explore_" .. i
        if not UIAssets.images[cacheKey] then
            local path = EXPLORE_PATH .. filename
            local success, result = pcall(function()
                return love.graphics.newImage(path)
            end)
            if success then
                UIAssets.images[cacheKey] = result
            end
        end
    end
end

-- Get a random exploration background for Text RPG mode
function UIAssets.getRandomExploreBackground()
    if not UIAssets.loaded then
        UIAssets.init()
    end
    UIAssets.loadExploreBackgrounds()

    local index = math.random(1, #UIAssets.exploreBackgrounds)
    return UIAssets.images["explore_" .. index]
end

-- Get a specific exploration background by index
function UIAssets.getExploreBackground(index)
    if not UIAssets.loaded then
        UIAssets.init()
    end
    UIAssets.loadExploreBackgrounds()

    index = math.max(1, math.min(index, #UIAssets.exploreBackgrounds))
    return UIAssets.images["explore_" .. index]
end

-- Draw an exploration background (for Text RPG mode)
function UIAssets.drawExploreBackground(index, alpha)
    alpha = alpha or 1
    local bg = UIAssets.getExploreBackground(index)
    if bg then
        local screenW, screenH = love.graphics.getDimensions()
        local imgW, imgH = bg:getDimensions()
        local scaleX = screenW / imgW
        local scaleY = screenH / imgH
        local scale = math.max(scaleX, scaleY)

        local offsetX = (screenW - imgW * scale) / 2
        local offsetY = (screenH - imgH * scale) / 2

        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.draw(bg, offsetX, offsetY, 0, scale, scale)
        love.graphics.setColor(1, 1, 1, 1)
        return true
    end
    return false
end

-- Get a UI image by name
function UIAssets.get(name)
    if not UIAssets.loaded then
        UIAssets.init()
    end
    return UIAssets.images[name]
end

-- Get character portrait image
function UIAssets.getCharacter(name)
    if not UIAssets.loaded then
        UIAssets.init()
    end

    -- Check cache first
    local cacheKey = "char_" .. name
    if UIAssets.images[cacheKey] then
        return UIAssets.images[cacheKey]
    end

    -- Try to load the character image
    local path = CHAR_PATH .. name .. ".PNG"
    local success, result = pcall(function()
        return love.graphics.newImage(path)
    end)

    if success then
        UIAssets.images[cacheKey] = result
        return result
    end

    return nil
end

-- Get random character from a category
function UIAssets.getRandomCharacter(category)
    local chars = UIAssets.characterCategories[category]
    if not chars then
        chars = UIAssets.characterCategories.humans_male or UIAssets.characterCategories.humans_female
    end
    if not chars or #chars == 0 then return nil, nil end

    local name = chars[math.random(#chars)]
    return UIAssets.getCharacter(name), name
end

-- Get icon image by category and filename
function UIAssets.getIcon(category, filename)
    if not UIAssets.loaded then
        UIAssets.init()
    end

    -- Build cache key
    local cacheKey = "icon_" .. category .. "_" .. filename
    if UIAssets.images[cacheKey] then
        return UIAssets.images[cacheKey]
    end

    -- Get path for category
    local basePath = UIAssets.iconPaths[category]
    if not basePath then
        basePath = ICON_PATH .. category .. "/"
    end

    -- Try to load the icon
    local path = basePath .. filename
    local success, result = pcall(function()
        return love.graphics.newImage(path)
    end)

    if success then
        UIAssets.images[cacheKey] = result
        return result
    end

    return nil
end

-- Get icon by registered name (from iconRegistry)
function UIAssets.getIconByName(name)
    local entry = UIAssets.iconRegistry[name]
    if not entry then
        return nil
    end
    return UIAssets.getIcon(entry.path, entry.file)
end

-- Draw an icon at specified position and size
function UIAssets.drawIcon(iconName, x, y, size)
    local img = UIAssets.getIconByName(iconName)

    if img then
        love.graphics.setColor(1, 1, 1)
        local imgW, imgH = img:getDimensions()
        local scale = size / math.max(imgW, imgH)
        love.graphics.draw(img, x, y, 0, scale, scale)
        return true
    end

    return false
end

-- Draw icon with fallback to colored rectangle
function UIAssets.drawIconOrFallback(iconName, x, y, size, fallbackColor, fallbackText)
    if not UIAssets.drawIcon(iconName, x, y, size) then
        -- Draw fallback
        fallbackColor = fallbackColor or {0.3, 0.3, 0.4}
        love.graphics.setColor(fallbackColor)
        love.graphics.rectangle("fill", x, y, size, size, 4, 4)
        if fallbackText then
            love.graphics.setColor(1, 1, 1)
            local font = love.graphics.getFont()
            local textW = font:getWidth(fallbackText)
            love.graphics.print(fallbackText, x + size/2 - textW/2, y + size/2 - font:getHeight()/2)
        end
    end
end

-- Get a random icon from a weapon type
function UIAssets.getRandomWeaponIcon(weaponType)
    local weaponCounts = {
        sword = 66, axe = 53, dagger = 60, bow = 41, staff = 54,
        hammer = 54, spear = 40, shield = 51, crossbow = 10, scythe = 7
    }
    local count = weaponCounts[weaponType] or 10
    local num = string.format("%02d", math.random(1, count))
    local filename = weaponType:sub(1,1):upper() .. weaponType:sub(2) .. "_" .. num .. ".PNG"
    return UIAssets.getIcon("weapons", filename)
end

-- Get a random armor icon by slot
function UIAssets.getRandomArmorIcon(slot)
    local slotInfo = {
        helm = {prefix = "Helm_", count = 72},
        chest = {prefix = "Chest_", count = 83},
        boots = {prefix = "Boots_", count = 56},
        gloves = {prefix = "Gloves_", count = 28},
        belt = {prefix = "Belt_", count = 36},
        shoulder = {prefix = "Shoulder_", count = 71},
        pants = {prefix = "Pants_", count = 42},
        back = {prefix = "Back_", count = 16},
    }
    local info = slotInfo[slot]
    if not info then return nil end

    local num = string.format("%02d", math.random(1, info.count))
    local filename = info.prefix .. num .. ".PNG"
    return UIAssets.getIcon("armor", filename)
end

-- Get random potion icon
function UIAssets.getRandomPotionIcon()
    local potions = {
        "Potion_01.PNG", "Potion_02.PNG", "Potion_03.PNG", "Potion_04.PNG",
        "Potion_05.PNG", "Potion_06.PNG", "Potion_07.PNG",
        "Alchemy_13_heal_potion.PNG", "Alchemy_17_blue_potion.PNG",
        "Alchemy_24_energy_potion.PNG", "Alchemy_16_shadow_potion.PNG"
    }
    return UIAssets.getIcon("items", potions[math.random(#potions)])
end

-- Get random food icon
function UIAssets.getRandomFoodIcon()
    local foods = {
        "Bread.PNG", "Cheese.PNG", "Carrot.PNG", "FriedChickenLeg.PNG",
        "FishRed.PNG", "Cake.PNG", "Salad.PNG", "Egg.PNG", "Honey.PNG"
    }
    return UIAssets.getIcon("food", foods[math.random(#foods)])
end

-- Get chest icon by rarity
function UIAssets.getChestIcon(rarity)
    local chestMap = {
        common = "Loot_101_chest.PNG",
        uncommon = "Loot_102_chest.PNG",
        rare = "Loot_103_chest.PNG",
        epic = "Loot_104_chest.PNG",
        legendary = "Loot_106_chest.PNG",
        ultimate = "Loot_107_chest.PNG"
    }
    local filename = chestMap[rarity] or chestMap.common
    return UIAssets.getIcon("loot", filename)
end

-- Get coin icon by type
function UIAssets.getCoinIcon(coinType, stacked)
    local suffix = stacked and "Ten" or ""
    local filename = coinType:sub(1,1):upper() .. coinType:sub(2) .. "Coin" .. suffix .. ".PNG"
    return UIAssets.getIcon("resources", filename)
end

-- Get random opponent portrait (for poker games) - uses gendered NPC portraits
function UIAssets.getRandomOpponent()
    -- Use NPC system for proper gender matching
    local gender = math.random() < 0.5 and "male" or "female"
    local portrait
    if gender == "male" then
        portrait = UIAssets.malePortraits[math.random(#UIAssets.malePortraits)]
    else
        portrait = UIAssets.femalePortraits[math.random(#UIAssets.femalePortraits)]
    end
    return UIAssets.getCharacter(portrait), portrait
end

-- Get random creature (for trading cards and pets) - uses Animals and Monsters folders only
function UIAssets.getRandomCreature()
    local categories = {"animals", "monsters"}
    local category = categories[math.random(#categories)]
    return UIAssets.getRandomCharacter(category)
end

-- Get random animal (for pets)
function UIAssets.getRandomAnimal()
    return UIAssets.getRandomCharacter("animals")
end

-- Get random monster (for creature cards)
function UIAssets.getRandomMonster()
    return UIAssets.getRandomCharacter("monsters")
end

-- Get music track path
function UIAssets.getMusicPath(category)
    local tracks = UIAssets.music[category]
    if not tracks or #tracks == 0 then
        return nil
    end
    local track = tracks[math.random(#tracks)]
    return MUSIC_PATH .. track
end

-- Draw a button with the new UI assets
function UIAssets.drawButton(x, y, w, h, text, hover, active)
    local img = nil
    if active then
        img = UIAssets.get("button_ready_on")
    elseif hover then
        img = UIAssets.get("button2")
    else
        img = UIAssets.get("button")
    end

    if img then
        love.graphics.setColor(1, 1, 1)
        local imgW, imgH = img:getDimensions()
        local scaleX = w / imgW
        local scaleY = h / imgH
        love.graphics.draw(img, x, y, 0, scaleX, scaleY)
    else
        -- Fallback to colored rectangle
        if active then
            love.graphics.setColor(0.4, 0.5, 0.7)
        elseif hover then
            love.graphics.setColor(0.3, 0.4, 0.6)
        else
            love.graphics.setColor(0.2, 0.3, 0.5)
        end
        love.graphics.rectangle("fill", x, y, w, h, 8, 8)
    end

    -- Draw text
    love.graphics.setColor(1, 1, 1)
    local font = love.graphics.getFont()
    local textW = font:getWidth(text)
    local textH = font:getHeight()
    love.graphics.print(text, x + w/2 - textW/2, y + h/2 - textH/2)
end

-- Draw a frame/panel
function UIAssets.drawFrame(x, y, w, h, frameType)
    frameType = frameType or "mid"
    local img = nil

    if frameType == "big" then
        img = UIAssets.get("frame_big")
    elseif frameType == "small" then
        img = UIAssets.get("mini_frame1")
    else
        img = UIAssets.get("frame_mid")
    end

    if img then
        love.graphics.setColor(1, 1, 1)
        local imgW, imgH = img:getDimensions()
        local scaleX = w / imgW
        local scaleY = h / imgH
        love.graphics.draw(img, x, y, 0, scaleX, scaleY)
    else
        -- Fallback
        love.graphics.setColor(0.1, 0.1, 0.14)
        love.graphics.rectangle("fill", x, y, w, h, 10, 10)
        love.graphics.setColor(0.9, 0.6, 0.2)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, w, h, 10, 10)
        love.graphics.setLineWidth(1)
    end
end

-- Draw a background panel
function UIAssets.drawBackground(x, y, w, h, bgType)
    bgType = bgType or "mid"
    local img = nil

    if bgType == "big" then
        img = UIAssets.get("bg_big")
    elseif bgType == "mini" then
        img = UIAssets.get("bg_mini")
    elseif bgType == "round" then
        img = UIAssets.get("bg_round_small")
    else
        img = UIAssets.get("bg_mid")
    end

    if img then
        love.graphics.setColor(1, 1, 1)
        local imgW, imgH = img:getDimensions()
        local scaleX = w / imgW
        local scaleY = h / imgH
        love.graphics.draw(img, x, y, 0, scaleX, scaleY)
    else
        -- Fallback
        love.graphics.setColor(0.08, 0.08, 0.12)
        love.graphics.rectangle("fill", x, y, w, h, 8, 8)
    end
end

-- Draw HP bar
function UIAssets.drawHPBar(x, y, w, h, percent, color)
    color = color or {0.2, 0.8, 0.3}
    percent = math.max(0, math.min(1, percent))

    local frameImg = UIAssets.get("hp_frame")
    local lineImg = UIAssets.get("hp_line")

    if frameImg and lineImg then
        love.graphics.setColor(1, 1, 1)
        local frameW, frameH = frameImg:getDimensions()
        local scaleX = w / frameW
        local scaleY = h / frameH

        -- Draw fill first
        love.graphics.setColor(color)
        local lineW, lineH = lineImg:getDimensions()
        local fillW = (w - 6) * percent
        love.graphics.draw(lineImg, x + 3, y + 3, 0, fillW / lineW, (h - 6) / lineH)

        -- Draw frame on top
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(frameImg, x, y, 0, scaleX, scaleY)
    else
        -- Fallback
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", x, y, w, h, 4, 4)
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", x + 2, y + 2, (w - 4) * percent, h - 4, 3, 3)
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.rectangle("line", x, y, w, h, 4, 4)
    end
end

-- Draw character portrait
function UIAssets.drawPortrait(x, y, size, characterName)
    local img = UIAssets.getCharacter(characterName)

    if img then
        love.graphics.setColor(1, 1, 1)
        local imgW, imgH = img:getDimensions()
        local scale = size / math.max(imgW, imgH)
        love.graphics.draw(img, x, y, 0, scale, scale)
    else
        -- Fallback - draw placeholder
        love.graphics.setColor(0.3, 0.3, 0.4)
        love.graphics.rectangle("fill", x, y, size, size, 8, 8)
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.rectangle("line", x, y, size, size, 8, 8)
        love.graphics.setColor(0.6, 0.6, 0.7)
        love.graphics.print("?", x + size/2 - 5, y + size/2 - 10)
    end
end

-- Draw name bar with text
function UIAssets.drawNameBar(x, y, w, h, text)
    local img = UIAssets.get("name_bar")

    if img then
        love.graphics.setColor(1, 1, 1)
        local imgW, imgH = img:getDimensions()
        local scaleX = w / imgW
        local scaleY = h / imgH
        love.graphics.draw(img, x, y, 0, scaleX, scaleY)
    else
        love.graphics.setColor(0.15, 0.15, 0.2)
        love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    end

    -- Draw text
    love.graphics.setColor(1, 1, 1)
    local font = love.graphics.getFont()
    local textW = font:getWidth(text)
    love.graphics.print(text, x + w/2 - textW/2, y + h/2 - font:getHeight()/2)
end

-- ============================================
-- NPC SYSTEM - Gender-matched names & portraits
-- ============================================

-- Character portraits organized by gender (using new subfolder paths)
UIAssets.malePortraits = {
    -- Male Humans (Human/Men_Human folder)
    "Human/Men_Human/Human_01", "Human/Men_Human/Human_09", "Human/Men_Human/Human_10",
    "Human/Men_Human/Human_16", "Human/Men_Human/Human_21", "Human/Men_Human/Human_22",
    "Human/Men_Human/Human_23", "Human/Men_Human/Human_24", "Human/Men_Human/Human_25",
    "Human/Men_Human/Human_26", "Human/Men_Human/Human_27", "Human/Men_Human/Human_28",
    "Human/Men_Human/Human_29", "Human/Men_Human/Human_33", "Human/Men_Human/Human_49",
    "Human/Men_Human/Human_06_Priest", "Human/Men_Human/Human_23_rogue", "Human/Men_Human/Human_24_ronin",
    "Human/Men_Human/Human_25_barbarian", "Human/Men_Human/Human_26_barbarian", "Human/Men_Human/Human_27_alchemyst",
    "Human/Men_Human/Human_28_thug", "Human/Men_Human/Human_29_cannibal", "Human/Men_Human/Human_32_scout",
    "Human/Men_Human/Human_33_warrior", "Human/Men_Human/Human_34_Javelinmen", "Human/Men_Human/Human_35_Halberdier",
    "Human/Men_Human/Human_36_Slayer_of_knights", "Human/Men_Human/Human_38_aztec_elite_warrior",
    "Human/Men_Human/Human_39_chief", "Human/Men_Human/Human_40_aztec_shaman", "Human/Men_Human/Human_41_conquistador",
    "Human/Men_Human/Human_44_guard", "Human/Men_Human/Human_45_pharaon", "Human/Men_Human/Human_46_sage",
    "Human/Men_Human/Human_47_convict", "Human/Men_Human/Human_48_priest", "Human/Men_Human/Human_49_mangudai",
    "Human/Men_Human/Human_20_Samurai",
    -- Knights & Warriors
    "Human/Men_Human/Knight_Man", "Human/Men_Human/Knight2_Man", "Human/Men_Human/Knight_Man3",
    "Human/Men_Human/Warrior", "Human/Men_Human/BoldWarrior", "Human/Men_Human/Guard",
    "Human/Men_Human/Footman", "Human/Men_Human/Spearman", "Human/Men_Human/Crossbowman",
    -- Misc Male
    "Human/Men_Human/Merchant", "Human/Men_Human/Sage", "Human/Men_Human/Duke",
    "Human/Men_Human/Viking", "Human/Men_Human/Robber", "Human/Men_Human/Robber2",
    "Human/Men_Human/Prophet", "Human/Men_Human/Shaman", "Human/Men_Human/Homeless",
    "Human/Men_Human/Leper", "Human/Men_Human/Trader",
    -- Male Elves (ELF/Men_ELF folder)
    "ELF/Men_ELF/Elf_01_1", "ELF/Men_ELF/Elf_02_1", "ELF/Men_ELF/Elf_05",
    "ELF/Men_ELF/Elf_07", "ELF/Men_ELF/Elf_08", "ELF/Men_ELF/Elf_10",
    "ELF/Men_ELF/Elf_11", "ELF/Men_ELF/ElfWarrior",
    -- Male Orcs (ORC/Men_ORC folder)
    "ORC/Men_ORC/Orc_01_warrior", "ORC/Men_ORC/Orc_02", "ORC/Men_ORC/Orc_02_warlord",
    "ORC/Men_ORC/Orc_03_shaman", "ORC/Men_ORC/Orc_04_warlock", "ORC/Men_ORC/Orc_05",
    "ORC/Men_ORC/Orc_06", "ORC/Men_ORC/Orc_07", "ORC/Men_ORC/Orc_08", "ORC/Men_ORC/Orc_09",
    "ORC/Men_ORC/Orc_6_Hunter", "ORC/Men_ORC/Orc_7_Rider", "ORC/Men_ORC/Orc_8_oracle",
    -- Gnomes & Goblins (root folder)
    "Gnome_01", "Gnome_02", "Gnome_03", "Gnome_04", "Gnome_05", "Gnome_06", "Gnome_dark",
    "goblin_01", "goblin_02", "goblin_03", "goblin_04", "goblin_05",
    -- Gods (male, root folder)
    "God_Zeus", "God_Hades", "God_Poseidon", "God_Ares", "God_Apollo", "God_Hermes",
    "God_Hephaestus", "God_Dionysus",
    -- Misc (root folder)
    "Dwarf", "MadDwarf", "Neanderthalensis", "RoyalGuard", "OldCultist",
}

UIAssets.femalePortraits = {
    -- Female Humans (Human/Women_Human folder)
    "Human/Women_Human/Human_02", "Human/Women_Human/Human_03", "Human/Women_Human/Human_04",
    "Human/Women_Human/Human_05", "Human/Women_Human/Human_06", "Human/Women_Human/Human_07",
    "Human/Women_Human/Human_08", "Human/Women_Human/Human_11", "Human/Women_Human/Human_12",
    "Human/Women_Human/Human_13", "Human/Women_Human/Human_14", "Human/Women_Human/Human_15",
    "Human/Women_Human/Human_17", "Human/Women_Human/Human_18", "Human/Women_Human/Human_19",
    "Human/Women_Human/Human_20", "Human/Women_Human/Human_30", "Human/Women_Human/Human_32",
    "Human/Women_Human/Human_05_woman_knight", "Human/Women_Human/Human_07_girl",
    "Human/Women_Human/Human_15_woman", "Human/Women_Human/Human_16_girl",
    "Human/Women_Human/Human_30_witch", "Human/Women_Human/Human_31_witch",
    "Human/Women_Human/Human_42_queen", "Human/Women_Human/Human_43_queen",
    "Human/Women_Human/Human_50_amazon_warrior",
    -- Female characters
    "Human/Women_Human/Archer_woman", "Human/Women_Human/BlindWoman",
    "Human/Women_Human/Assassin", "Human/Women_Human/FrostMage", "Human/Women_Human/Cultist",
    -- Female Elves (ELF/Women_Elf folder)
    "ELF/Women_Elf/Elf_01", "ELF/Women_Elf/Elf_02", "ELF/Women_Elf/Elf_03",
    "ELF/Women_Elf/Elf_03_1", "ELF/Women_Elf/Elf_04", "ELF/Women_Elf/Elf_04_hunter",
    "ELF/Women_Elf/Elf_06", "ELF/Women_Elf/Elf_09", "ELF/Women_Elf/ElfMage",
    -- Female Orcs (ORC/Women_ORC folder)
    "ORC/Women_ORC/Orc_01", "ORC/Women_ORC/Orc_03", "ORC/Women_ORC/Orc_04",
    "ORC/Women_ORC/Orc_11", "ORC/Women_ORC/Orc_12",
    -- Gods (female, root folder)
    "God_Athena", "God_Artemis", "God_Aphrodite", "God_Hera",
    -- Demons (female, root folder)
    "Demon_05_Lilith", "Demon_10_succubus",
    -- Misc (root folder)
    "Old_woman",
}

-- Name lists by gender
UIAssets.maleNames = {
    -- Common
    "Aldric", "Bran", "Cedric", "Duncan", "Edmund", "Felix", "Gareth", "Harold",
    "Ivan", "Jasper", "Klaus", "Leon", "Magnus", "Niles", "Oswald", "Percy",
    "Quinn", "Roland", "Silas", "Tobias", "Ulric", "Victor", "Wallace", "Xavier",
    -- Medieval
    "Alaric", "Baldric", "Conrad", "Darius", "Egbert", "Florian", "Godfrey", "Henrik",
    "Ingram", "Jarvis", "Kelvin", "Lambert", "Mortimer", "Norbert", "Orion", "Percival",
    -- Fantasy
    "Theron", "Varen", "Zephyr", "Caelum", "Draven", "Fennick", "Grimm", "Hawke",
    "Iskander", "Jorik", "Kael", "Loric", "Malachar", "Nox", "Oberon", "Pyrus",
    -- Tavern regulars
    "Barley", "Copper", "Flint", "Grog", "Hopper", "Malt", "Rye", "Stout", "Timber",
}

UIAssets.femaleNames = {
    -- Common
    "Adeline", "Beatrice", "Clara", "Diana", "Eleanor", "Fiona", "Gwen", "Helena",
    "Iris", "Julia", "Katherine", "Lydia", "Miriam", "Nora", "Ophelia", "Penelope",
    "Rosalind", "Selene", "Thalia", "Una", "Violet", "Wren", "Yara", "Zelda",
    -- Medieval
    "Aldith", "Bronwyn", "Cressida", "Drusilla", "Edith", "Felicity", "Giselle", "Hildegard",
    "Isolde", "Jocelyn", "Katarina", "Lorraine", "Meredith", "Nicolette", "Odette", "Phillipa",
    -- Fantasy
    "Althea", "Brielle", "Cassia", "Dahlia", "Elara", "Freya", "Galena", "Hesper",
    "Iliana", "Jessamine", "Kira", "Luna", "Mira", "Nyssa", "Oriana", "Petra",
    -- Tavern workers
    "Barley", "Cinnamon", "Honey", "Ivy", "Maple", "Pearl", "Ruby", "Sage", "Willow",
}

-- Professions by wealth tier
UIAssets.professions = {
    poor = {"Beggar", "Peasant", "Vagrant", "Laborer", "Servant", "Stable Hand", "Scullery"},
    common = {"Farmer", "Fisher", "Miller", "Baker", "Butcher", "Tanner", "Cooper", "Potter", "Weaver"},
    skilled = {"Blacksmith", "Carpenter", "Mason", "Tailor", "Cobbler", "Chandler", "Brewer", "Innkeeper"},
    wealthy = {"Merchant", "Jeweler", "Goldsmith", "Banker", "Shipwright", "Guild Master", "Wine Trader"},
    noble = {"Knight", "Baron", "Lord", "Lady", "Duke", "Duchess", "Count", "Countess", "Prince", "Princess"},
    magical = {"Apprentice", "Hedge Witch", "Alchemist", "Wizard", "Sorcerer", "Enchanter", "Archmage"},
    military = {"Guard", "Soldier", "Mercenary", "Captain", "Commander", "General", "Veteran"},
    underworld = {"Thief", "Smuggler", "Fence", "Assassin", "Spy", "Bandit", "Pirate"},
    religious = {"Acolyte", "Priest", "Monk", "Nun", "Paladin", "Inquisitor", "High Priest"},
    entertainment = {"Bard", "Minstrel", "Jester", "Dancer", "Acrobat", "Fortune Teller"},
}

-- Wealth levels with coin ranges
UIAssets.wealthLevels = {
    {id = "destitute", name = "Destitute", minCoins = 0, maxCoins = 10, color = {0.4, 0.3, 0.3}},
    {id = "poor", name = "Poor", minCoins = 10, maxCoins = 50, color = {0.5, 0.4, 0.3}},
    {id = "common", name = "Common", minCoins = 50, maxCoins = 200, color = {0.6, 0.6, 0.5}},
    {id = "comfortable", name = "Comfortable", minCoins = 200, maxCoins = 500, color = {0.5, 0.6, 0.4}},
    {id = "wealthy", name = "Wealthy", minCoins = 500, maxCoins = 2000, color = {0.7, 0.6, 0.2}},
    {id = "rich", name = "Rich", minCoins = 2000, maxCoins = 10000, color = {0.9, 0.7, 0.2}},
    {id = "noble", name = "Noble", minCoins = 10000, maxCoins = 100000, color = {0.8, 0.5, 0.9}},
}

-- Generate a random NPC with matched gender name/portrait
function UIAssets.generateNPC(options)
    options = options or {}

    -- Determine gender
    local gender = options.gender
    if not gender then
        gender = math.random() < 0.5 and "male" or "female"
    end

    -- Select name based on gender
    local name
    if options.name then
        name = options.name
    elseif gender == "male" then
        name = UIAssets.maleNames[math.random(#UIAssets.maleNames)]
    else
        name = UIAssets.femaleNames[math.random(#UIAssets.femaleNames)]
    end

    -- Select portrait based on gender
    local portrait
    if options.portrait then
        portrait = options.portrait
    elseif gender == "male" then
        portrait = UIAssets.malePortraits[math.random(#UIAssets.malePortraits)]
    else
        portrait = UIAssets.femalePortraits[math.random(#UIAssets.femalePortraits)]
    end

    -- Generate age (weighted toward adults)
    local age = options.age
    if not age then
        local ageRoll = math.random()
        if ageRoll < 0.05 then
            age = math.random(10, 17)  -- Young
        elseif ageRoll < 0.60 then
            age = math.random(18, 35)  -- Young adult
        elseif ageRoll < 0.85 then
            age = math.random(36, 55)  -- Middle aged
        elseif ageRoll < 0.95 then
            age = math.random(56, 70)  -- Elder
        else
            age = math.random(71, 90)  -- Ancient
        end
    end

    -- Generate wealth level
    local wealthIndex = options.wealthIndex
    if not wealthIndex then
        local wealthRoll = math.random()
        if wealthRoll < 0.10 then
            wealthIndex = 1  -- Destitute
        elseif wealthRoll < 0.35 then
            wealthIndex = 2  -- Poor
        elseif wealthRoll < 0.65 then
            wealthIndex = 3  -- Common
        elseif wealthRoll < 0.82 then
            wealthIndex = 4  -- Comfortable
        elseif wealthRoll < 0.93 then
            wealthIndex = 5  -- Wealthy
        elseif wealthRoll < 0.98 then
            wealthIndex = 6  -- Rich
        else
            wealthIndex = 7  -- Noble
        end
    end
    local wealth = UIAssets.wealthLevels[wealthIndex]
    local coins = math.random(wealth.minCoins, wealth.maxCoins)

    -- Generate profession based on wealth
    local profession = options.profession
    if not profession then
        local profCategory
        if wealthIndex <= 2 then
            profCategory = UIAssets.professions.poor
        elseif wealthIndex == 3 then
            profCategory = UIAssets.professions.common
        elseif wealthIndex == 4 then
            profCategory = UIAssets.professions.skilled
        elseif wealthIndex <= 6 then
            -- Mix of wealthy and special professions
            local cats = {"wealthy", "military", "magical", "entertainment"}
            profCategory = UIAssets.professions[cats[math.random(#cats)]]
        else
            profCategory = UIAssets.professions.noble
        end
        profession = profCategory[math.random(#profCategory)]
    end

    return {
        name = name,
        gender = gender,
        age = age,
        portrait = portrait,
        profession = profession,
        wealth = wealth.id,
        wealthName = wealth.name,
        wealthColor = wealth.color,
        coins = coins,
    }
end

-- Generate NPC for specific role (opponent, customer, staff, etc.)
function UIAssets.generateOpponent(difficulty)
    difficulty = difficulty or "normal"

    local wealthIndex
    if difficulty == "easy" then
        wealthIndex = math.random(2, 4)
    elseif difficulty == "normal" then
        wealthIndex = math.random(3, 5)
    elseif difficulty == "hard" then
        wealthIndex = math.random(4, 6)
    else  -- boss
        wealthIndex = math.random(6, 7)
    end

    local npc = UIAssets.generateNPC({wealthIndex = wealthIndex})
    npc.difficulty = difficulty

    -- Add poker-specific stats
    if difficulty == "easy" then
        npc.skill = math.random(20, 40)
        npc.aggression = math.random(10, 30)
    elseif difficulty == "normal" then
        npc.skill = math.random(40, 60)
        npc.aggression = math.random(30, 50)
    elseif difficulty == "hard" then
        npc.skill = math.random(60, 80)
        npc.aggression = math.random(50, 70)
    else
        npc.skill = math.random(80, 100)
        npc.aggression = math.random(60, 90)
    end

    return npc
end

-- Generate customer for tavern/cafe
function UIAssets.generateCustomer(tier)
    tier = tier or "common"

    local wealthIndex
    if tier == "poor" then
        wealthIndex = math.random(1, 2)
    elseif tier == "common" then
        wealthIndex = math.random(2, 4)
    elseif tier == "wealthy" then
        wealthIndex = math.random(4, 6)
    else  -- noble
        wealthIndex = math.random(6, 7)
    end

    local npc = UIAssets.generateNPC({wealthIndex = wealthIndex})
    npc.customerTier = tier

    -- Customer-specific attributes
    npc.patience = math.random(50, 100)
    npc.tipMultiplier = 0.8 + (wealthIndex * 0.1) + (math.random() * 0.2)

    return npc
end

-- Generate staff/employee
function UIAssets.generateStaff(role)
    local professionMap = {
        kitchen = {"Cook", "Chef", "Kitchen Hand", "Baker"},
        server = {"Barmaid", "Waiter", "Serving Wench", "Server"},
        security = {"Bouncer", "Guard", "Doorman"},
        entertainment = {"Bard", "Minstrel", "Dancer", "Musician"},
        management = {"Innkeeper", "Manager", "Owner"},
    }

    local profs = professionMap[role] or professionMap.server
    local profession = profs[math.random(#profs)]

    local npc = UIAssets.generateNPC({
        profession = profession,
        wealthIndex = math.random(2, 4),
    })
    npc.role = role

    -- Staff-specific attributes
    npc.efficiency = math.random(50, 100)
    npc.wage = math.floor(10 + (npc.efficiency * 0.5))

    return npc
end

-- Get portrait for an existing named NPC (tries to match gender)
function UIAssets.getGenderedPortrait(name, gender)
    if gender == "female" then
        return UIAssets.femalePortraits[math.random(#UIAssets.femalePortraits)]
    else
        return UIAssets.malePortraits[math.random(#UIAssets.malePortraits)]
    end
end

-- Infer gender from name (basic heuristic)
function UIAssets.inferGender(name)
    -- Check against known names
    for _, n in ipairs(UIAssets.femaleNames) do
        if n == name then return "female" end
    end
    for _, n in ipairs(UIAssets.maleNames) do
        if n == name then return "male" end
    end

    -- Common female name endings
    local femaleEndings = {"a", "ia", "ina", "elle", "ette", "lyn", "een", "ine"}
    local nameLower = name:lower()
    for _, ending in ipairs(femaleEndings) do
        if nameLower:sub(-#ending) == ending then
            return "female"
        end
    end

    return "male"  -- Default
end

-- ============================================
-- ASSET CONFIG INTEGRATION
-- ============================================
-- These functions work with assetconfig.lua for dynamic asset management

-- Get the asset configuration module (if available)
function UIAssets.getAssetConfig()
    return AssetConfig
end

-- Check if asset config is available
function UIAssets.hasAssetConfig()
    return AssetConfig ~= nil
end

-- Get names for a specific race and gender from config
function UIAssets.getNamesForRace(race, gender)
    if AssetConfig and AssetConfig.getNames then
        local names = AssetConfig.getNames(race, gender)
        if names and #names > 0 then
            return names
        end
    end
    -- Fallback to default names
    if gender == "female" then
        return UIAssets.femaleNames
    else
        return UIAssets.maleNames
    end
end

-- Get a random name for race and gender
function UIAssets.getRandomNameForRace(race, gender)
    local names = UIAssets.getNamesForRace(race, gender)
    return names[math.random(#names)]
end

-- Get creature portrait for a specific element (for trading cards)
function UIAssets.getCreatureForElement(element)
    if AssetConfig and AssetConfig.creatureElements then
        local creatures = AssetConfig.creatureElements[element]
        if creatures and #creatures > 0 then
            local portraitPath = creatures[math.random(#creatures)]
            return UIAssets.getCharacter(portraitPath), portraitPath
        end
    end
    -- Fallback to random creature
    return UIAssets.getRandomCreature()
end

-- Get pet evolution portraits
function UIAssets.getPetEvolution(petType)
    if AssetConfig and AssetConfig.petEvolutions then
        local evolution = AssetConfig.petEvolutions[petType]
        if evolution then
            return {
                base = evolution[1],
                evolved = evolution[2],
                final = evolution[3],
            }
        end
    end
    -- Fallback
    return {
        base = "Animals/Cat_animal",
        evolved = "Animals/Cat_animal",
        final = "Monsters/Monster_Elemental",
    }
end

-- Scan and report available assets (for debugging)
function UIAssets.scanAssets()
    local AssetScanner = nil
    pcall(function()
        local pipeline = require("assetpipeline")
        AssetScanner = pipeline.scanner
    end)

    if AssetScanner then
        return AssetScanner.generateReport()
    else
        return "Asset scanner not available"
    end
end

-- Print asset scan to console
function UIAssets.printAssetScan()
    print(UIAssets.scanAssets())
end

-- Currency definitions with descriptions for tooltips
UIAssets.currencies = {
    coins = {
        name = "Gold Coins",
        description = "The primary currency. Earn from jobs, winning games, and selling items.",
        icon = "gold_coin",
        color = {1, 0.85, 0.2}
    },
    crystals = {
        name = "Crystals",
        description = "Rare currency earned from fusion and special activities. Used for upgrades.",
        icon = "crystal",
        color = {0.4, 0.8, 1}
    },
    reputation = {
        name = "Reputation",
        description = "Your standing in the community. Unlocks better customers and deals.",
        icon = "star",
        color = {1, 0.9, 0.3}
    },
    experience = {
        name = "Experience",
        description = "Gain XP to level up and unlock new abilities.",
        icon = "exp",
        color = {0.5, 0.8, 0.3}
    },
    ammo = {
        name = "Ammunition",
        description = "Arrows and bolts for hunting. Buy more at the shop.",
        icon = "arrow",
        color = {0.7, 0.5, 0.3}
    },
    materials = {
        name = "Materials",
        description = "Crafting resources like iron, steel, and leather.",
        icon = "ingot",
        color = {0.6, 0.6, 0.7}
    }
}

-- Tooltip state (for tracking hover)
UIAssets.tooltipState = {
    active = false,
    text = "",
    title = "",
    x = 0,
    y = 0,
    timer = 0
}

-- Queue a tooltip to be drawn (call this when hovering)
function UIAssets.queueTooltip(title, description, x, y)
    UIAssets.tooltipState.active = true
    UIAssets.tooltipState.title = title or ""
    UIAssets.tooltipState.text = description or ""
    UIAssets.tooltipState.x = x
    UIAssets.tooltipState.y = y
end

-- Clear tooltip state (call at start of each frame)
function UIAssets.clearTooltip()
    UIAssets.tooltipState.active = false
end

-- Draw any queued tooltip (call at end of draw, after everything else)
function UIAssets.drawTooltip()
    if not UIAssets.tooltipState.active then return end

    local state = UIAssets.tooltipState
    local screenW, screenH = love.graphics.getDimensions()

    -- Calculate tooltip size
    love.graphics.setFont(getFont(14))
    local titleW = love.graphics.getFont():getWidth(state.title)

    love.graphics.setFont(getFont(12))
    local maxLineW = 0
    local lines = {}
    for line in state.text:gmatch("[^\n]+") do
        table.insert(lines, line)
        local lineW = love.graphics.getFont():getWidth(line)
        if lineW > maxLineW then maxLineW = lineW end
    end

    local tooltipW = math.max(titleW, maxLineW) + 24
    local tooltipH = 28 + #lines * 16 + 10

    -- Position tooltip (keep on screen)
    local tooltipX = state.x + 15
    local tooltipY = state.y + 15

    if tooltipX + tooltipW > screenW - 10 then
        tooltipX = state.x - tooltipW - 10
    end
    if tooltipY + tooltipH > screenH - 10 then
        tooltipY = screenH - tooltipH - 10
    end

    -- Draw tooltip background
    love.graphics.setColor(0.1, 0.1, 0.15, 0.95)
    love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipW, tooltipH, 6, 6)

    -- Border
    love.graphics.setColor(0.9, 0.7, 0.3, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", tooltipX, tooltipY, tooltipW, tooltipH, 6, 6)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(1, 0.9, 0.5)
    love.graphics.setFont(getFont(14))
    love.graphics.print(state.title, tooltipX + 12, tooltipY + 6)

    -- Description lines
    love.graphics.setColor(0.85, 0.85, 0.85)
    love.graphics.setFont(getFont(12))
    for i, line in ipairs(lines) do
        love.graphics.print(line, tooltipX + 12, tooltipY + 24 + (i-1) * 16)
    end
end

-- Draw a currency display with icon, amount, and hover tooltip
-- Returns the bounds {x, y, w, h} for hover detection
function UIAssets.drawCurrency(currencyType, amount, x, y, size)
    size = size or 24
    local currency = UIAssets.currencies[currencyType]
    local iconName = currency and currency.icon or "gold_coin"
    local color = currency and currency.color or {1, 0.85, 0.2}

    -- Draw icon
    local iconDrawn = false
    local icon = UIAssets.getIconByName(iconName)
    if icon then
        love.graphics.setColor(1, 1, 1)
        local imgW, imgH = icon:getDimensions()
        local scale = size / math.max(imgW, imgH)
        love.graphics.draw(icon, x, y, 0, scale, scale)
        iconDrawn = true
    end

    if not iconDrawn then
        -- Fallback colored circle
        love.graphics.setColor(color)
        love.graphics.circle("fill", x + size/2, y + size/2, size/2 - 2)
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("line", x + size/2, y + size/2, size/2 - 2)
    end

    -- Draw amount text
    love.graphics.setColor(color)
    love.graphics.setFont(getFont(math.floor(size * 0.75)))
    local amountStr = tostring(amount)
    if amount >= 1000000 then
        amountStr = string.format("%.1fM", amount / 1000000)
    elseif amount >= 10000 then
        amountStr = string.format("%.1fK", amount / 1000)
    end
    love.graphics.print(amountStr, x + size + 6, y + (size - love.graphics.getFont():getHeight()) / 2)

    -- Calculate total width
    local textW = love.graphics.getFont():getWidth(amountStr)
    local totalW = size + 6 + textW

    return {x = x, y = y, w = totalW, h = size}
end

-- Check if mouse is hovering over currency and show tooltip
function UIAssets.checkCurrencyHover(currencyType, bounds)
    local mx, my = love.mouse.getPosition()
    if mx >= bounds.x and mx <= bounds.x + bounds.w and
       my >= bounds.y and my <= bounds.y + bounds.h then
        local currency = UIAssets.currencies[currencyType]
        if currency then
            UIAssets.queueTooltip(currency.name, currency.description, mx, my)
        end
        return true
    end
    return false
end

-- Combined draw + hover check for currency
function UIAssets.drawCurrencyWithTooltip(currencyType, amount, x, y, size)
    local bounds = UIAssets.drawCurrency(currencyType, amount, x, y, size)
    UIAssets.checkCurrencyHover(currencyType, bounds)
    return bounds
end

return UIAssets
