-- Trading Card Simulator - Collect creature cards from packs!
-- Similar to Pokemon/TCG but with original creatures

local TradingCards = {}
local UIAssets = require("uiassets")
local UI = require("ui")

-- Creature portrait mappings (maps creature name to character icon path)
-- Uses Animals and Monsters folders only for creature cards
local creaturePortraits = {
    -- Flame creatures -> fire-themed (from Monsters folder)
    ["Emberpup"] = "Animals/Monsters_09",
    ["Blazefox"] = "Animals/Wolf_animal",
    ["Infernowolf"] = "Monsters/Creatures_05_werewolf",
    ["Pyrodrake"] = "Monsters/Creatures_11_Dragon",
    ["Cinder Wisp"] = "Monsters/Monster_Elemental",
    ["Magma Golem"] = "Monsters/Monster_Terrible",

    -- Aqua creatures -> water-themed (from Animals/Monsters folders)
    ["Bubblekin"] = "Animals/Dolphin_animal",
    ["Tidalfish"] = "Monsters/Monster_fish",
    ["Waveserpent"] = "Monsters/Monster_DemonicFish",
    ["Leviathan"] = "Monsters/Creatures_11_Dragon",
    ["Coral Sprite"] = "Monsters/Monster_Elemental",
    ["Storm Whale"] = "Monsters/Monster_waterm",

    -- Terra creatures -> nature-themed
    ["Sproutling"] = "Monsters/Monster_Flower",
    ["Thorncat"] = "Animals/Cat_animal",
    ["Mossback Bear"] = "Animals/Bear_animal",
    ["Ancient Oak"] = "Monsters/Monster_Flower2",
    ["Petal Fairy"] = "Monsters/Monster_Flower3",
    ["Jungle Titan"] = "Monsters/Gigant_05_pangolin",

    -- Volt creatures -> electric-themed
    ["Sparklet"] = "Animals/Bird_animal",
    ["Thundermouse"] = "Animals/Monsters_16",
    ["Stormhawk"] = "Monsters/Creatures_07_phoenix",
    ["Voltitan"] = "Monsters/Monster_DragonWarrior",
    ["Circuit Bug"] = "Monsters/Monster_Fly",
    ["Plasma Dragon"] = "Monsters/Creatures_11_Dragon",

    -- Shadow creatures -> dark-themed
    ["Shade Kitten"] = "Animals/Cat_animal",
    ["Nightstalker"] = "Monsters/Monster_Spider",
    ["Void Wraith"] = "Monsters/Monster_Eye",
    ["Abyssal Lord"] = "Monsters/Demon_12_skeleton_king",
    ["Gloom Bat"] = "Animals/Bat",
    ["Phantom King"] = "Monsters/Devourer",

    -- Light creatures -> holy-themed
    ["Glowfly"] = "Animals/Bird_animal",
    ["Sunrabbit"] = "Animals/Creatures_12_Dog",
    ["Radiant Pegasus"] = "Animals/Creatures_10_warhorse",
    ["Celestial Phoenix"] = "Monsters/Creatures_07_phoenix",
    ["Prism Butterfly"] = "Animals/Hawk_animal",
    ["Dawn Herald"] = "Monsters/Monster_Elemental",

    -- Frost creatures -> ice-themed
    ["Snowfluff"] = "Animals/Cat_animal",
    ["Ice Fox"] = "Animals/Wolf_animal",
    ["Glacier Bear"] = "Animals/Bear_animal",
    ["Blizzard Dragon"] = "Monsters/Creatures_11_Dragon",
    ["Frost Sprite"] = "Monsters/Monster_Flower",
    ["Permafrost Titan"] = "Monsters/Monster_DragonWarrior",

    -- Metal creatures -> mechanical-themed
    ["Coglet"] = "Monsters/Monster_Scorpion",
    ["Steelwolf"] = "Monsters/Creatures_05_werewolf",
    ["Iron Goliath"] = "Monsters/Gigant_08_minotaur",
    ["Mech Overlord"] = "Monsters/Monster_DragonWarrior",
    ["Brass Beetle"] = "Monsters/Monster_Fly",
    ["Chrome Serpent"] = "Monsters/Monster_SkeletonSnake",

    -- Fusion creatures
    ["Steamling"] = "Monsters/Monster_Elemental",
    ["Storm Sprite"] = "Monsters/Monster_Flower2",
    ["Nightbloom"] = "Monsters/Monster_Flower",
    ["Lumina Bot"] = "Monsters/Monster_Scorpion",
    ["Obsidian Imp"] = "Monsters/Monster_HungryDemon",
    ["Reef Dancer"] = "Monsters/Monster_waterm",
    ["Phantom Wire"] = "Monsters/Monster_SkeletonSnake",
    ["Aurora Fox"] = "Animals/Wolf_animal",
}

-- Get creature portrait image
local function getCreaturePortrait(creatureName)
    local portraitName = creaturePortraits[creatureName]
    if portraitName then
        return UIAssets.getCharacter(portraitName)
    end
    -- Fallback to random creature
    local img, name = UIAssets.getRandomCreature()
    return img
end

-- Creature types and elements
local ELEMENTS = {
    {id = "flame", name = "Flame", color = {0.9, 0.3, 0.2}, icon = "🔥"},
    {id = "aqua", name = "Aqua", color = {0.2, 0.5, 0.9}, icon = "💧"},
    {id = "terra", name = "Terra", color = {0.5, 0.7, 0.3}, icon = "🌿"},
    {id = "volt", name = "Volt", color = {0.9, 0.8, 0.2}, icon = "⚡"},
    {id = "shadow", name = "Shadow", color = {0.4, 0.2, 0.5}, icon = "🌙"},
    {id = "light", name = "Light", color = {0.9, 0.9, 0.6}, icon = "✨"},
    {id = "frost", name = "Frost", color = {0.6, 0.8, 0.95}, icon = "❄️"},
    {id = "metal", name = "Metal", color = {0.6, 0.6, 0.7}, icon = "⚙️"},
}

-- Rarities with drop rates
local RARITIES = {
    {id = "common", name = "Common", color = {0.7, 0.7, 0.7}, rate = 0.50, sellValue = 5},
    {id = "uncommon", name = "Uncommon", color = {0.3, 0.7, 0.3}, rate = 0.25, sellValue = 15},
    {id = "rare", name = "Rare", color = {0.3, 0.5, 0.9}, rate = 0.15, sellValue = 50},
    {id = "epic", name = "Epic", color = {0.7, 0.3, 0.9}, rate = 0.07, sellValue = 150},
    {id = "legendary", name = "Legendary", color = {0.9, 0.7, 0.2}, rate = 0.025, sellValue = 500},
    {id = "mythic", name = "Mythic", color = {0.9, 0.3, 0.5}, rate = 0.005, sellValue = 2000},
}

-- All creature cards (name, element, base power, description)
local CREATURES = {
    -- Flame creatures
    {name = "Emberpup", element = "flame", power = 15, desc = "A playful pup with a fiery tail"},
    {name = "Blazefox", element = "flame", power = 35, desc = "Swift hunter of the volcanic plains"},
    {name = "Infernowolf", element = "flame", power = 65, desc = "Pack leader wreathed in flames"},
    {name = "Pyrodrake", element = "flame", power = 85, desc = "Ancient dragon of the fire mountains"},
    {name = "Cinder Wisp", element = "flame", power = 10, desc = "Floating ember spirit"},
    {name = "Magma Golem", element = "flame", power = 70, desc = "Living lava guardian"},

    -- Aqua creatures
    {name = "Bubblekin", element = "aqua", power = 12, desc = "Tiny creature made of bubbles"},
    {name = "Tidalfish", element = "aqua", power = 30, desc = "Rides the ocean currents"},
    {name = "Waveserpent", element = "aqua", power = 60, desc = "Master of the deep waters"},
    {name = "Leviathan", element = "aqua", power = 90, desc = "Ancient ruler of the seas"},
    {name = "Coral Sprite", element = "aqua", power = 20, desc = "Guardian of the reef"},
    {name = "Storm Whale", element = "aqua", power = 75, desc = "Creates hurricanes when it surfaces"},

    -- Terra creatures
    {name = "Sproutling", element = "terra", power = 10, desc = "Just beginning to grow"},
    {name = "Thorncat", element = "terra", power = 32, desc = "Covered in protective thorns"},
    {name = "Mossback Bear", element = "terra", power = 55, desc = "Forest guardian with moss armor"},
    {name = "Ancient Oak", element = "terra", power = 80, desc = "Thousand-year-old tree spirit"},
    {name = "Petal Fairy", element = "terra", power = 25, desc = "Dances among the flowers"},
    {name = "Jungle Titan", element = "terra", power = 88, desc = "Walking fortress of vines"},

    -- Volt creatures
    {name = "Sparklet", element = "volt", power = 14, desc = "Tiny ball of electricity"},
    {name = "Thundermouse", element = "volt", power = 28, desc = "Quick as lightning"},
    {name = "Stormhawk", element = "volt", power = 58, desc = "Rides the lightning"},
    {name = "Voltitan", element = "volt", power = 82, desc = "Living storm cloud"},
    {name = "Circuit Bug", element = "volt", power = 18, desc = "Powers small devices"},
    {name = "Plasma Dragon", element = "volt", power = 92, desc = "Pure electrical energy given form"},

    -- Shadow creatures
    {name = "Shade Kitten", element = "shadow", power = 16, desc = "Hides in dark corners"},
    {name = "Nightstalker", element = "shadow", power = 40, desc = "Silent hunter of the dark"},
    {name = "Void Wraith", element = "shadow", power = 62, desc = "Exists between dimensions"},
    {name = "Abyssal Lord", element = "shadow", power = 88, desc = "Ruler of the endless void"},
    {name = "Gloom Bat", element = "shadow", power = 22, desc = "Sees only in darkness"},
    {name = "Phantom King", element = "shadow", power = 78, desc = "Commands armies of spirits"},

    -- Light creatures
    {name = "Glowfly", element = "light", power = 8, desc = "Gentle beacon in the night"},
    {name = "Sunrabbit", element = "light", power = 26, desc = "Brings warmth wherever it goes"},
    {name = "Radiant Pegasus", element = "light", power = 68, desc = "Flies on beams of light"},
    {name = "Celestial Phoenix", element = "light", power = 95, desc = "Reborn from pure light"},
    {name = "Prism Butterfly", element = "light", power = 20, desc = "Refracts rainbow colors"},
    {name = "Dawn Herald", element = "light", power = 72, desc = "Announces the sunrise"},

    -- Frost creatures
    {name = "Snowfluff", element = "frost", power = 11, desc = "Fluffy bundle of cold"},
    {name = "Ice Fox", element = "frost", power = 34, desc = "Leaves frost footprints"},
    {name = "Glacier Bear", element = "frost", power = 64, desc = "Sleeps for centuries"},
    {name = "Blizzard Dragon", element = "frost", power = 86, desc = "Breathing brings winter"},
    {name = "Frost Sprite", element = "frost", power = 18, desc = "Paints windows with ice"},
    {name = "Permafrost Titan", element = "frost", power = 80, desc = "Walking ice age"},

    -- Metal creatures
    {name = "Coglet", element = "metal", power = 13, desc = "Tiny mechanical helper"},
    {name = "Steelwolf", element = "metal", power = 38, desc = "Built for battle"},
    {name = "Iron Goliath", element = "metal", power = 70, desc = "Impenetrable armor"},
    {name = "Mech Overlord", element = "metal", power = 90, desc = "Perfect fusion of magic and machine"},
    {name = "Brass Beetle", element = "metal", power = 24, desc = "Shiny collector of treasures"},
    {name = "Chrome Serpent", element = "metal", power = 76, desc = "Slithers through solid metal"},
}

-- Pack types
local PACKS = {
    {id = "basic", name = "Basic Pack", cost = 50, cards = 5, guaranteedRare = false, icon = "📦"},
    {id = "premium", name = "Premium Pack", cost = 150, cards = 5, guaranteedRare = true, icon = "🎁"},
    {id = "elemental", name = "Elemental Pack", cost = 100, cards = 5, guaranteedRare = false, elementLocked = true, icon = "🌟"},
    {id = "mega", name = "Mega Pack", cost = 400, cards = 10, guaranteedRare = true, guaranteedEpic = true, icon = "💎"},
}

-- Element Weakness/Strength Chart
-- Format: element -> {strong_against = {}, weak_against = {}}
local ELEMENT_CHART = {
    flame = {strong = {"frost", "terra"}, weak = {"aqua", "metal"}},
    aqua = {strong = {"flame", "terra"}, weak = {"volt", "frost"}},
    terra = {strong = {"volt", "metal"}, weak = {"flame", "aqua"}},
    volt = {strong = {"aqua", "metal"}, weak = {"terra", "shadow"}},
    shadow = {strong = {"light", "volt"}, weak = {"terra", "flame"}},
    light = {strong = {"shadow", "frost"}, weak = {"volt", "metal"}},
    frost = {strong = {"aqua", "terra"}, weak = {"flame", "light"}},
    metal = {strong = {"light", "frost"}, weak = {"volt", "terra"}},
}

-- Moves per element type (each creature gets 2 moves)
local ELEMENT_MOVES = {
    flame = {
        {name = "Fireball", power = 25, desc = "Hurls a ball of fire"},
        {name = "Inferno", power = 40, desc = "Engulfs foe in flames"},
    },
    aqua = {
        {name = "Tidal Wave", power = 25, desc = "Crashes water on foe"},
        {name = "Whirlpool", power = 40, desc = "Traps in swirling water"},
    },
    terra = {
        {name = "Vine Whip", power = 25, desc = "Lashes with thorny vines"},
        {name = "Earthquake", power = 40, desc = "Shakes the ground"},
    },
    volt = {
        {name = "Spark", power = 25, desc = "Zaps with electricity"},
        {name = "Thunder Strike", power = 40, desc = "Calls down lightning"},
    },
    shadow = {
        {name = "Dark Pulse", power = 25, desc = "Emits dark energy"},
        {name = "Nightmare", power = 40, desc = "Invades the mind"},
    },
    light = {
        {name = "Holy Light", power = 25, desc = "Bathes in radiance"},
        {name = "Solar Beam", power = 40, desc = "Concentrated sunlight"},
    },
    frost = {
        {name = "Ice Shard", power = 25, desc = "Hurls frozen spikes"},
        {name = "Blizzard", power = 40, desc = "Summons a snowstorm"},
    },
    metal = {
        {name = "Iron Slam", power = 25, desc = "Strikes with metal"},
        {name = "Steel Crush", power = 40, desc = "Devastating metal blow"},
    },
}

-- Evolution chains (creature -> evolved form, requires rarity upgrade)
local EVOLUTION_CHAINS = {
    -- Flame evolutions
    ["Emberpup"] = "Blazefox",
    ["Blazefox"] = "Infernowolf",
    ["Cinder Wisp"] = "Magma Golem",
    ["Infernowolf"] = "Pyrodrake",
    -- Aqua evolutions
    ["Bubblekin"] = "Tidalfish",
    ["Tidalfish"] = "Waveserpent",
    ["Coral Sprite"] = "Storm Whale",
    ["Waveserpent"] = "Leviathan",
    -- Terra evolutions
    ["Sproutling"] = "Thorncat",
    ["Thorncat"] = "Mossback Bear",
    ["Petal Fairy"] = "Ancient Oak",
    ["Mossback Bear"] = "Jungle Titan",
    -- Volt evolutions
    ["Sparklet"] = "Thundermouse",
    ["Thundermouse"] = "Stormhawk",
    ["Circuit Bug"] = "Voltitan",
    ["Stormhawk"] = "Plasma Dragon",
    -- Shadow evolutions
    ["Shade Kitten"] = "Nightstalker",
    ["Nightstalker"] = "Void Wraith",
    ["Gloom Bat"] = "Phantom King",
    ["Void Wraith"] = "Abyssal Lord",
    -- Light evolutions
    ["Glowfly"] = "Sunrabbit",
    ["Sunrabbit"] = "Radiant Pegasus",
    ["Prism Butterfly"] = "Dawn Herald",
    ["Radiant Pegasus"] = "Celestial Phoenix",
    -- Frost evolutions
    ["Snowfluff"] = "Ice Fox",
    ["Ice Fox"] = "Glacier Bear",
    ["Frost Sprite"] = "Permafrost Titan",
    ["Glacier Bear"] = "Blizzard Dragon",
    -- Metal evolutions
    ["Coglet"] = "Steelwolf",
    ["Steelwolf"] = "Iron Goliath",
    ["Brass Beetle"] = "Chrome Serpent",
    ["Iron Goliath"] = "Mech Overlord",
}

-- Fusion recipes: {card1, card2} = result creature name
local FUSION_RECIPES = {
    -- Cross-element fusions create hybrid creatures
    {inputs = {"Emberpup", "Snowfluff"}, result = "Steamling", element = "aqua", power = 30, desc = "Born of fire and ice"},
    {inputs = {"Sparklet", "Bubblekin"}, result = "Storm Sprite", element = "volt", power = 28, desc = "Electric water spirit"},
    {inputs = {"Sproutling", "Shade Kitten"}, result = "Nightbloom", element = "shadow", power = 32, desc = "Flower that blooms in darkness"},
    {inputs = {"Glowfly", "Coglet"}, result = "Lumina Bot", element = "light", power = 26, desc = "Mechanical light bearer"},
    {inputs = {"Cinder Wisp", "Frost Sprite"}, result = "Obsidian Imp", element = "metal", power = 35, desc = "Forged in extremes"},
    {inputs = {"Coral Sprite", "Petal Fairy"}, result = "Reef Dancer", element = "aqua", power = 38, desc = "Guardian of coastal flowers"},
    {inputs = {"Gloom Bat", "Circuit Bug"}, result = "Phantom Wire", element = "shadow", power = 40, desc = "Haunted circuitry"},
    {inputs = {"Thundermouse", "Ice Fox"}, result = "Aurora Fox", element = "light", power = 50, desc = "Runs on northern lights"},
}

-- NPC opponent names for tavern battles (separated by gender)
local NPC_MALE_NAMES = {
    "Aldric", "Bram", "Cedric", "Dorian", "Edmund", "Finnian", "Garrett", "Henrik",
    "Ivan", "Jasper", "Kieran", "Lucian", "Magnus", "Nolan", "Osric", "Percival",
    "Quentin", "Roland", "Silas", "Theron", "Ulric", "Victor", "Willem", "Xavier",
    "Barric", "Conrad", "Darius", "Felix", "Grimm", "Hawke", "Jorik", "Kael",
}

local NPC_FEMALE_NAMES = {
    "Agnes", "Beatrix", "Clara", "Delia", "Elara", "Freya", "Gwendolyn", "Helena",
    "Ivy", "Juliana", "Kira", "Lydia", "Mira", "Nadia", "Ophelia", "Priscilla",
    "Rosalind", "Selene", "Thalia", "Una", "Violet", "Wren", "Yara", "Zelda",
    "Althea", "Brielle", "Cassia", "Dahlia", "Iliana", "Luna", "Petra", "Sage",
}

local NPC_LAST_NAMES = {
    "Blackwood", "Copperfield", "Dragonsbane", "Emberforge", "Frostwind", "Goldleaf",
    "Hawkstone", "Ironheart", "Jadewater", "Kingsley", "Lightbringer", "Moonweaver",
    "Nighthollow", "Oakenshield", "Proudfoot", "Quicksilver", "Ravenscroft", "Stormborn",
    "Thornwood", "Underhill", "Valorheart", "Winterbell", "the Wanderer", "the Bold",
}

local NPC_PROFESSIONS = {
    -- Common trades
    {title = "Merchant", desc = "Deals in rare goods", tier = 1},
    {title = "Blacksmith", desc = "Forges mighty weapons", tier = 2},
    {title = "Alchemist", desc = "Brews mysterious potions", tier = 2},
    {title = "Bard", desc = "Sings tales of old", tier = 1},
    {title = "Hunter", desc = "Tracks dangerous beasts", tier = 2},
    {title = "Scholar", desc = "Studies ancient lore", tier = 2},
    {title = "Guard", desc = "Protects the realm", tier = 1},
    {title = "Farmer", desc = "Tends the land", tier = 1},
    {title = "Sailor", desc = "Braves the seas", tier = 1},
    {title = "Miner", desc = "Delves deep underground", tier = 1},
    {title = "Herbalist", desc = "Knows nature's secrets", tier = 1},
    {title = "Innkeeper", desc = "Runs the local tavern", tier = 1},
    -- Skilled professions
    {title = "Knight", desc = "Sworn to honor and valor", tier = 3},
    {title = "Mage", desc = "Wields arcane power", tier = 3},
    {title = "Healer", desc = "Mends wounds with magic", tier = 2},
    {title = "Baker", desc = "Crafts delicious breads", tier = 1},
    {title = "Tailor", desc = "Sews fine garments", tier = 1},
    {title = "Cobbler", desc = "Makes sturdy boots", tier = 1},
    {title = "Jeweler", desc = "Creates precious trinkets", tier = 2},
    {title = "Scribe", desc = "Records ancient texts", tier = 2},
    {title = "Tanner", desc = "Works fine leathers", tier = 1},
    {title = "Cooper", desc = "Makes barrels and casks", tier = 1},
    {title = "Brewer", desc = "Crafts fine ales", tier = 1},
    {title = "Chandler", desc = "Makes candles and soap", tier = 1},
    -- Military/Combat
    {title = "Soldier", desc = "Fights for the realm", tier = 2},
    {title = "Mercenary", desc = "Sells sword for coin", tier = 2},
    {title = "Archer", desc = "Master of the bow", tier = 2},
    {title = "Veteran", desc = "Survived many battles", tier = 3},
    {title = "Captain", desc = "Commands a company", tier = 3},
    -- Nobles/Wealthy
    {title = "Noble", desc = "Born to privilege", tier = 4},
    {title = "Diplomat", desc = "Negotiates treaties", tier = 3},
    {title = "Collector", desc = "Seeks rare creatures", tier = 3},
    {title = "Patron", desc = "Sponsors adventurers", tier = 4},
    -- Adventurers
    {title = "Adventurer", desc = "Seeks fortune and glory", tier = 2},
    {title = "Explorer", desc = "Maps unknown lands", tier = 2},
    {title = "Treasure Hunter", desc = "Seeks lost riches", tier = 3},
    {title = "Monster Slayer", desc = "Hunts dangerous beasts", tier = 3},
    -- Specialists
    {title = "Enchanter", desc = "Imbues items with magic", tier = 3},
    {title = "Summoner", desc = "Calls forth creatures", tier = 4},
    {title = "Wildspeaker", desc = "Commands wild beasts", tier = 3},
    {title = "Card Master", desc = "Expert creature battler", tier = 4},
    {title = "Sage", desc = "Keeper of wisdom", tier = 4},
    {title = "Mystic", desc = "Sees beyond the veil", tier = 3},
}

-- Human-only portraits for tavern challengers
local HUMAN_MALE_PORTRAITS = {
    "Human/Men_Human/Human_01", "Human/Men_Human/Human_09", "Human/Men_Human/Human_10",
    "Human/Men_Human/Human_16", "Human/Men_Human/Human_21", "Human/Men_Human/Human_22",
    "Human/Men_Human/Human_23", "Human/Men_Human/Human_24", "Human/Men_Human/Human_25",
    "Human/Men_Human/Human_27", "Human/Men_Human/Human_28", "Human/Men_Human/Human_33",
    "Human/Men_Human/Knight_Man", "Human/Men_Human/Knight2_Man", "Human/Men_Human/Knight_Man3",
    "Human/Men_Human/Warrior", "Human/Men_Human/BoldWarrior", "Human/Men_Human/Guard",
    "Human/Men_Human/Merchant", "Human/Men_Human/Sage", "Human/Men_Human/Duke",
    "Human/Men_Human/Viking", "Human/Men_Human/Robber", "Human/Men_Human/Prophet",
    "Human/Men_Human/Footman", "Human/Men_Human/Spearman", "Human/Men_Human/Crossbowman",
    "Human/Men_Human/Human_06_Priest", "Human/Men_Human/Human_23_rogue", "Human/Men_Human/Human_24_ronin",
    "Human/Men_Human/Human_27_alchemyst", "Human/Men_Human/Human_20_Samurai",
}

local HUMAN_FEMALE_PORTRAITS = {
    "Human/Women_Human/Human_02", "Human/Women_Human/Human_03", "Human/Women_Human/Human_04",
    "Human/Women_Human/Human_05", "Human/Women_Human/Human_06", "Human/Women_Human/Human_07",
    "Human/Women_Human/Human_08", "Human/Women_Human/Human_11", "Human/Women_Human/Human_12",
    "Human/Women_Human/Human_13", "Human/Women_Human/Human_14", "Human/Women_Human/Human_15",
    "Human/Women_Human/Human_17", "Human/Women_Human/Human_18", "Human/Women_Human/Human_19",
    "Human/Women_Human/Human_20", "Human/Women_Human/Human_30", "Human/Women_Human/Human_32",
    "Human/Women_Human/Human_05_woman_knight", "Human/Women_Human/Human_07_girl",
    "Human/Women_Human/Human_30_witch", "Human/Women_Human/Human_31_witch",
    "Human/Women_Human/Human_42_queen", "Human/Women_Human/Human_43_queen",
    "Human/Women_Human/Human_50_amazon_warrior", "Human/Women_Human/Archer_woman",
    "Human/Women_Human/Assassin", "Human/Women_Human/FrostMage", "Human/Women_Human/BlindWoman",
}

-- Game state
local state = {
    collection = {},  -- Player's card collection
    packOpening = false,
    openedCards = {},
    currentPack = nil,
    revealIndex = 0,
    revealTimer = 0,
    selectedElement = nil,  -- For elemental packs
    viewMode = "collection",  -- collection, packs, battle, evolve, fuse, help
    collectionScroll = 0,
    sortBy = "element",  -- element, rarity, power, name
    filterElement = "all",
    selectedCard = nil,
    packsPurchased = 0,
    totalCardsCollected = 0,
    animations = {},
    -- New systems
    flux = 0,  -- Flux currency from breaking cards
    battleTeam = {},  -- Player's team of 5 creatures for battle
    battleState = nil,  -- Current battle state
    opponents = {},  -- Generated NPC opponents
    selectedForEvolve = nil,  -- Card selected for evolution
    selectedForFuse = {nil, nil},  -- Two cards selected for fusion
    showHelp = false,  -- Help overlay toggle
    hoveredElement = nil,  -- For tooltip display
    -- UI components
    ui = {
        tabBar = nil,
        backButton = nil,
        helpButton = nil,
        scrollContainer = nil,
    }
}

-- Helper to get element by id
local function getElement(id)
    for _, el in ipairs(ELEMENTS) do
        if el.id == id then return el end
    end
    return ELEMENTS[1]
end

-- Helper to get rarity by id
local function getRarity(id)
    for _, r in ipairs(RARITIES) do
        if r.id == id then return r end
    end
    return RARITIES[1]
end

-- Forward declaration (used inside generateCard before definition)
local getRarityIndex

-- Generate a random card
local function generateCard(elementLock)
    -- Pick rarity based on rates
    local roll = math.random()
    local cumulative = 0
    local rarity = RARITIES[1]
    for _, r in ipairs(RARITIES) do
        cumulative = cumulative + r.rate
        if roll <= cumulative then
            rarity = r
            break
        end
    end

    -- Filter creatures by element if locked
    local validCreatures = {}
    for _, c in ipairs(CREATURES) do
        if not elementLock or c.element == elementLock then
            table.insert(validCreatures, c)
        end
    end

    -- Pick random creature
    local creature = validCreatures[math.random(#validCreatures)]

    -- Create card instance
    local card = {
        id = math.random(100000, 999999),
        creature = creature.name,
        element = creature.element,
        basePower = creature.power,
        description = creature.desc,
        rarity = rarity.id,
        -- Rarity affects power
        power = math.floor(creature.power * (1 + (getRarityIndex(rarity.id) - 1) * 0.2)),
        level = 1,
        -- Unique variant
        variant = math.random(1, 1000),
        foil = rarity.id == "legendary" or rarity.id == "mythic" or math.random() < 0.05,
    }

    return card
end

-- Get rarity index for calculations
getRarityIndex = function(rarityId)
    for i, r in ipairs(RARITIES) do
        if r.id == rarityId then return i end
    end
    return 1
end

-- Get creature data by name
local function getCreatureByName(name)
    for _, c in ipairs(CREATURES) do
        if c.name == name then return c end
    end
    return nil
end

-- Calculate Flux value from breaking a card
local function getFluxValue(card)
    local rarityIndex = getRarityIndex(card.rarity)
    local baseFlux = 5 * rarityIndex
    local levelBonus = (card.level or 1) * 2
    local foilBonus = card.foil and 10 or 0
    return baseFlux + levelBonus + foilBonus
end

-- Break a card for Flux
local function breakCard(cardIndex)
    local card = state.collection[cardIndex]
    if not card then return 0 end

    local fluxGained = getFluxValue(card)
    state.flux = state.flux + fluxGained
    table.remove(state.collection, cardIndex)
    savePlayerData()
    return fluxGained
end

-- Get evolution cost in Flux
local function getEvolutionCost(card)
    local rarityIndex = getRarityIndex(card.rarity)
    return 50 * rarityIndex + (card.level or 1) * 10
end

-- Check if card can evolve
local function canEvolve(card)
    local evolvedName = EVOLUTION_CHAINS[card.creature]
    if not evolvedName then return false, "No evolution available" end
    local cost = getEvolutionCost(card)
    if state.flux < cost then return false, "Need " .. cost .. " Flux" end
    return true, evolvedName
end

-- Evolve a card
local function evolveCard(cardIndex)
    local card = state.collection[cardIndex]
    if not card then return false end

    local canDo, result = canEvolve(card)
    if not canDo then return false, result end

    local evolvedName = result
    local cost = getEvolutionCost(card)
    state.flux = state.flux - cost

    -- Get evolved creature data
    local evolvedCreature = getCreatureByName(evolvedName)
    if not evolvedCreature then return false end

    -- Upgrade the card
    card.creature = evolvedName
    card.basePower = evolvedCreature.power
    card.element = evolvedCreature.element
    card.description = evolvedCreature.desc
    -- Upgrade rarity by 1 if possible
    local newRarityIndex = math.min(getRarityIndex(card.rarity) + 1, #RARITIES)
    card.rarity = RARITIES[newRarityIndex].id
    -- Recalculate power
    card.power = math.floor(evolvedCreature.power * (1 + (newRarityIndex - 1) * 0.2) * (1 + ((card.level or 1) - 1) * 0.1))

    savePlayerData()
    return true, evolvedName
end

-- Get fusion cost in Flux
local function getFusionCost()
    return 100
end

-- Check if two cards can fuse
local function canFuse(card1, card2)
    if not card1 or not card2 then return false, "Select two cards" end
    if card1.id == card2.id then return false, "Cannot fuse same card" end

    for _, recipe in ipairs(FUSION_RECIPES) do
        if (card1.creature == recipe.inputs[1] and card2.creature == recipe.inputs[2]) or
           (card1.creature == recipe.inputs[2] and card2.creature == recipe.inputs[1]) then
            if state.flux < getFusionCost() then
                return false, "Need " .. getFusionCost() .. " Flux"
            end
            return true, recipe
        end
    end
    return false, "No fusion recipe"
end

-- Fuse two cards
local function fuseCards(cardIndex1, cardIndex2)
    local card1 = state.collection[cardIndex1]
    local card2 = state.collection[cardIndex2]

    local canDo, result = canFuse(card1, card2)
    if not canDo then return false, result end

    local recipe = result
    state.flux = state.flux - getFusionCost()

    -- Remove both cards (remove higher index first)
    if cardIndex1 > cardIndex2 then
        table.remove(state.collection, cardIndex1)
        table.remove(state.collection, cardIndex2)
    else
        table.remove(state.collection, cardIndex2)
        table.remove(state.collection, cardIndex1)
    end

    -- Create fused card
    local fusedCard = {
        id = math.random(100000, 999999),
        creature = recipe.result,
        element = recipe.element,
        basePower = recipe.power,
        description = recipe.desc,
        rarity = "rare",  -- Fusions start at rare
        power = math.floor(recipe.power * 1.4),
        variant = math.random(1, 1000),
        foil = math.random() < 0.15,
        level = 1,
        isFusion = true,
    }

    table.insert(state.collection, fusedCard)
    savePlayerData()
    return true, fusedCard
end

-- Level up a card with Flux
local function getLevelUpCost(card)
    local level = card.level or 1
    return 20 * level
end

local function levelUpCard(cardIndex)
    local card = state.collection[cardIndex]
    if not card then return false end

    local cost = getLevelUpCost(card)
    if state.flux < cost then return false, "Need " .. cost .. " Flux" end

    state.flux = state.flux - cost
    card.level = (card.level or 1) + 1
    -- Recalculate power with level bonus
    local rarityIndex = getRarityIndex(card.rarity)
    card.power = math.floor(card.basePower * (1 + (rarityIndex - 1) * 0.2) * (1 + (card.level - 1) * 0.1))

    savePlayerData()
    return true, card.level
end

-- Generate random NPC opponent with gender-matched name and portrait (humans only)
local function generateOpponent(difficulty)
    difficulty = difficulty or 1

    -- Determine gender first (50/50)
    local gender = math.random() < 0.5 and "male" or "female"

    -- Pick name based on gender
    local firstName
    if gender == "male" then
        firstName = NPC_MALE_NAMES[math.random(#NPC_MALE_NAMES)]
    else
        firstName = NPC_FEMALE_NAMES[math.random(#NPC_FEMALE_NAMES)]
    end
    local lastName = NPC_LAST_NAMES[math.random(#NPC_LAST_NAMES)]

    -- Pick profession based on difficulty tier
    local validProfessions = {}
    local maxTier = math.min(difficulty, 4)
    for _, prof in ipairs(NPC_PROFESSIONS) do
        if prof.tier <= maxTier then
            table.insert(validProfessions, prof)
        end
    end
    if #validProfessions == 0 then validProfessions = NPC_PROFESSIONS end
    local profession = validProfessions[math.random(#validProfessions)]

    -- Generate opponent's team
    local team = {}
    for i = 1, 5 do
        local creature = CREATURES[math.random(#CREATURES)]
        local rarityRoll = math.random()
        local rarity = "common"
        if rarityRoll < 0.1 * difficulty then rarity = "epic"
        elseif rarityRoll < 0.25 * difficulty then rarity = "rare"
        elseif rarityRoll < 0.5 * difficulty then rarity = "uncommon"
        end

        local card = {
            id = math.random(100000, 999999),
            creature = creature.name,
            element = creature.element,
            basePower = creature.power,
            description = creature.desc,
            rarity = rarity,
            power = math.floor(creature.power * (1 + (getRarityIndex(rarity) - 1) * 0.2)),
            level = math.random(1, difficulty + 1),
            hp = 100 + difficulty * 20,
            maxHp = 100 + difficulty * 20,
        }
        table.insert(team, card)
    end

    -- Get a human-only gender-matched portrait for the NPC
    UIAssets.init()
    local portrait, portraitName
    if gender == "male" then
        portraitName = HUMAN_MALE_PORTRAITS[math.random(#HUMAN_MALE_PORTRAITS)]
    else
        portraitName = HUMAN_FEMALE_PORTRAITS[math.random(#HUMAN_FEMALE_PORTRAITS)]
    end
    portrait = UIAssets.getCharacter(portraitName)

    -- Generate age based on difficulty (higher difficulty = more experienced)
    local age = math.random(20, 30) + (difficulty * 5) + math.random(0, 10)

    -- Wealth based on difficulty
    local wealthLevels = {"poor", "common", "comfortable", "wealthy", "rich"}
    local wealthIndex = math.min(difficulty + 1, #wealthLevels)
    local wealth = wealthLevels[wealthIndex]

    return {
        name = firstName .. " " .. lastName,
        gender = gender,
        age = age,
        profession = profession.title,
        professionDesc = profession.desc,
        wealth = wealth,
        team = team,
        difficulty = difficulty,
        reward = {flux = 30 * difficulty, coins = 50 * difficulty},
        portrait = portrait,
        portraitName = portraitName,
    }
end

-- Calculate damage with element effectiveness
local function calculateDamage(attacker, defender, move)
    local baseDamage = move.power + (attacker.power * 0.5)
    local attackerElement = attacker.element
    local defenderElement = defender.element

    local chart = ELEMENT_CHART[attackerElement]
    local multiplier = 1.0

    if chart then
        for _, strong in ipairs(chart.strong) do
            if strong == defenderElement then
                multiplier = 1.5
                break
            end
        end
        for _, weak in ipairs(chart.weak) do
            if weak == defenderElement then
                multiplier = 0.5
                break
            end
        end
    end

    -- Add some randomness
    local variance = 0.9 + math.random() * 0.2
    return math.floor(baseDamage * multiplier * variance), multiplier
end

-- Open a pack
local function openPack(packType)
    local pack = nil
    for _, p in ipairs(PACKS) do
        if p.id == packType then pack = p break end
    end
    if not pack then return end

    if PlayerData.coins < pack.cost then
        return false, "Not enough coins!"
    end

    PlayerData.coins = PlayerData.coins - pack.cost

    local cards = {}
    local elementLock = pack.elementLocked and state.selectedElement or nil

    for i = 1, pack.cards do
        local card = generateCard(elementLock)

        -- Guarantee rare on premium packs (at least one)
        if pack.guaranteedRare and i == pack.cards then
            local hasRare = false
            for _, c in ipairs(cards) do
                if getRarityIndex(c.rarity) >= 3 then hasRare = true break end
            end
            if not hasRare then
                local attempts = 0
                while getRarityIndex(card.rarity) < 3 and attempts < 500 do
                    card = generateCard(elementLock)
                    attempts = attempts + 1
                end
            end
        end

        -- Guarantee epic on mega packs
        if pack.guaranteedEpic and i == pack.cards - 1 then
            local hasEpic = false
            for _, c in ipairs(cards) do
                if getRarityIndex(c.rarity) >= 4 then hasEpic = true break end
            end
            if not hasEpic then
                local attempts = 0
                while getRarityIndex(card.rarity) < 4 and attempts < 500 do
                    card = generateCard(elementLock)
                    attempts = attempts + 1
                end
            end
        end

        table.insert(cards, card)
    end

    state.openedCards = cards
    state.packOpening = true
    state.currentPack = pack
    state.revealIndex = 0
    state.revealTimer = 0
    state.packsPurchased = state.packsPurchased + 1

    -- Track loot boxes opened for unlock
    if not PlayerData.lootBoxesOpened then
        PlayerData.lootBoxesOpened = 0
    end
    PlayerData.lootBoxesOpened = PlayerData.lootBoxesOpened + 1

    savePlayerData()
    return true
end

-- Add card to collection
local function addToCollection(card)
    table.insert(state.collection, card)
    state.totalCardsCollected = state.totalCardsCollected + 1
end

-- Sell a card
local function sellCard(cardIndex)
    local card = state.collection[cardIndex]
    if not card then return end

    local rarity = getRarity(card.rarity)
    local value = rarity.sellValue
    if card.foil then value = value * 2 end

    PlayerData.coins = PlayerData.coins + value
    table.remove(state.collection, cardIndex)
    savePlayerData()

    return value
end

-- Get sorted/filtered collection
local function getSortedCollection()
    local filtered = {}

    for i, card in ipairs(state.collection) do
        local include = true
        if state.filterElement ~= "all" and card.element ~= state.filterElement then
            include = false
        end
        if include then
            table.insert(filtered, {index = i, card = card})
        end
    end

    -- Sort
    table.sort(filtered, function(a, b)
        if state.sortBy == "element" then
            if a.card.element ~= b.card.element then
                return a.card.element < b.card.element
            end
            return a.card.power > b.card.power
        elseif state.sortBy == "rarity" then
            local rarA = getRarityIndex(a.card.rarity)
            local rarB = getRarityIndex(b.card.rarity)
            if rarA ~= rarB then return rarA > rarB end
            return a.card.power > b.card.power
        elseif state.sortBy == "power" then
            return a.card.power > b.card.power
        else -- name
            return a.card.creature < b.card.creature
        end
    end)

    return filtered
end

function TradingCards.init()
    -- Load saved collection
    if PlayerData.tradingCards then
        state.collection = PlayerData.tradingCards.collection or {}
        state.packsPurchased = PlayerData.tradingCards.packsPurchased or 0
        state.totalCardsCollected = PlayerData.tradingCards.totalCardsCollected or 0
        state.flux = PlayerData.tradingCards.flux or 0
        state.battleTeam = PlayerData.tradingCards.battleTeam or {}
    else
        state.collection = {}
        state.packsPurchased = 0
        state.totalCardsCollected = 0
        state.flux = 0
        state.battleTeam = {}
    end

    -- Ensure all cards have level
    for _, card in ipairs(state.collection) do
        card.level = card.level or 1
    end

    state.viewMode = "packs"
    state.packOpening = false
    state.collectionScroll = 0
    state.selectedCard = nil
    state.selectedForEvolve = nil
    state.selectedForFuse = {nil, nil}
    state.battleState = nil
    state.showHelp = false

    -- Generate initial opponents
    state.opponents = {}
    for i = 1, 5 do
        table.insert(state.opponents, generateOpponent(i))
    end

    -- Initialize UI components
    local screenW, screenH = love.graphics.getDimensions()

    state.ui.tabBar = UI.TabBar.new({
        x = 10,
        y = 65,
        w = 430,
        tabs = {
            {id = "packs", label = "📦 Packs"},
            {id = "collection", label = "🃏 Cards"},
            {id = "battle", label = "⚔️ Battle"},
            {id = "evolve", label = "⬆️ Evolve"},
            {id = "fuse", label = "🔮 Fuse"}
        },
        activeTab = "packs",
        onChange = function(tabId)
            state.viewMode = tabId
        end
    })

    state.ui.helpButton = UI.Button.new({
        x = screenW - 100,
        y = 65,
        w = 80,
        h = 35,
        text = "❓ Help",
        variant = "ghost",
        onClick = function()
            state.showHelp = not state.showHelp
        end
    })

    state.ui.backButton = UI.Button.new({
        x = 20,
        y = screenH - 50,
        w = 100,
        h = 35,
        text = "Back",
        variant = "danger",
        onClick = function()
            TradingCards.save()
            local TextRPG = require("textrpg"); TextRPG.init(); GameState.current = "textrpg"
        end
    })
end

function TradingCards.save()
    PlayerData.tradingCards = {
        collection = state.collection,
        packsPurchased = state.packsPurchased,
        totalCardsCollected = state.totalCardsCollected,
        flux = state.flux,
        battleTeam = state.battleTeam,
    }
    savePlayerData()
end

function TradingCards.update(dt)
    -- Update UI animation system
    UI.anim.update(dt)

    -- Update UI components
    local screenW, screenH = love.graphics.getDimensions()
    if state.ui.tabBar then
        state.ui.tabBar.activeTab = state.viewMode
        state.ui.tabBar:update(dt)
    end
    if state.ui.helpButton then
        state.ui.helpButton.x = screenW - 100
        state.ui.helpButton:update(dt)
    end
    if state.ui.backButton then
        state.ui.backButton.y = screenH - 50
        state.ui.backButton:update(dt)
    end

    if state.packOpening then
        state.revealTimer = state.revealTimer + dt

        -- Auto-reveal cards
        if state.revealTimer > 0.5 and state.revealIndex < #state.openedCards then
            state.revealIndex = state.revealIndex + 1
            state.revealTimer = 0

            -- Add sparkle animation for rare+
            local card = state.openedCards[state.revealIndex]
            if getRarityIndex(card.rarity) >= 3 then
                table.insert(state.animations, {
                    type = "sparkle",
                    x = 0, y = 0,
                    timer = 0,
                    duration = 1,
                    cardIndex = state.revealIndex
                })
            end
        end
    end

    -- Update animations
    for i = #state.animations, 1, -1 do
        local anim = state.animations[i]
        anim.timer = anim.timer + dt
        if anim.timer >= anim.duration then
            table.remove(state.animations, i)
        end
    end

    -- Battle opponent turn
    if state.battleState and state.battleState.phase == "opponent_turn" then
        state.battleState.turnTimer = (state.battleState.turnTimer or 0) + dt
        if state.battleState.turnTimer > 1 then
            state.battleState.turnTimer = 0
            local battle = state.battleState
            local oppCard = battle.opponent.team[battle.oppActive]
            local playerCard = battle.playerTeam[battle.playerActive]

            if oppCard and playerCard then
                local moves = ELEMENT_MOVES[oppCard.element]
                if moves then
                    local move = moves[math.random(#moves)]
                    local damage, mult = calculateDamage(oppCard, playerCard, move)
                    playerCard.hp = playerCard.hp - damage

                    local effectText = mult > 1 and " (Super effective!)" or mult < 1 and " (Not very effective...)" or ""
                    table.insert(battle.log, oppCard.creature .. " used " .. move.name .. "! " .. damage .. " damage!" .. effectText)

                    -- Check if player creature fainted
                    if playerCard.hp <= 0 then
                        table.insert(battle.log, playerCard.creature .. " fainted!")
                        -- Find next player creature
                        local foundNext = false
                        for j = battle.playerActive + 1, 5 do
                            if battle.playerTeam[j] and battle.playerTeam[j].hp > 0 then
                                battle.playerActive = j
                                foundNext = true
                                break
                            end
                        end
                        if not foundNext then
                            battle.phase = "defeat"
                            return
                        end
                    end
                    battle.phase = "player_turn"
                end
            end
        end
    end
end

function TradingCards.draw()
    local screenW, screenH = love.graphics.getDimensions()

    -- Background
    love.graphics.setColor(0.08, 0.08, 0.12)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Header
    love.graphics.setColor(0.12, 0.12, 0.18)
    love.graphics.rectangle("fill", 0, 0, screenW, 60)

    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(UI.fonts.get(24))
    love.graphics.print("CREATURE CARDS", 20, 15)

    -- Coins display
    love.graphics.setColor(1, 0.9, 0.3)
    love.graphics.setFont(UI.fonts.get(18))
    love.graphics.print(string.format("Coins: %d", PlayerData.coins), screenW - 180, 18)

    -- Stats with Flux
    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.print(string.format("Collection: %d | Packs: %d", #state.collection, state.packsPurchased), screenW - 180, 40)

    -- Flux display
    love.graphics.setColor(0.8, 0.4, 0.9)
    love.graphics.setFont(UI.fonts.get(16))
    love.graphics.print(string.format("Flux: %d", state.flux), screenW - 320, 18)

    -- Tab buttons using UI component
    if state.ui.tabBar then
        state.ui.tabBar:draw()
    end

    -- Help button using UI component
    if state.ui.helpButton then
        state.ui.helpButton:draw()
    end

    -- Main content area
    local contentY = 110
    local contentH = screenH - contentY - 60

    if state.packOpening then
        drawPackOpening(screenW, screenH, contentY, contentH)
    elseif state.battleState then
        drawBattleView(screenW, screenH, contentY, contentH)
    elseif state.viewMode == "packs" then
        drawPacksView(screenW, screenH, contentY, contentH)
    elseif state.viewMode == "collection" then
        drawCollectionView(screenW, screenH, contentY, contentH)
    elseif state.viewMode == "battle" then
        drawBattleSelectView(screenW, screenH, contentY, contentH)
    elseif state.viewMode == "evolve" then
        drawEvolveView(screenW, screenH, contentY, contentH)
    elseif state.viewMode == "fuse" then
        drawFuseView(screenW, screenH, contentY, contentH)
    end

    -- Help overlay
    if state.showHelp then
        drawHelpOverlay(screenW, screenH)
    end

    -- Back button using UI component
    if state.ui.backButton then
        state.ui.backButton:draw()
    end
end

function drawPacksView(screenW, screenH, contentY, contentH)
    local mx, my = love.mouse.getPosition()

    -- Draw packs
    local packW, packH = 180, 250
    local spacing = 30
    local totalW = #PACKS * packW + (#PACKS - 1) * spacing
    local startX = screenW / 2 - totalW / 2

    for i, pack in ipairs(PACKS) do
        local packX = startX + (i - 1) * (packW + spacing)
        local packY = contentY + 30

        local hover = mx >= packX and mx <= packX + packW and my >= packY and my <= packY + packH
        local canAfford = PlayerData.coins >= pack.cost

        -- Pack background
        if canAfford then
            if hover then
                love.graphics.setColor(0.3, 0.4, 0.5)
            else
                love.graphics.setColor(0.2, 0.25, 0.35)
            end
        else
            love.graphics.setColor(0.15, 0.15, 0.18)
        end
        love.graphics.rectangle("fill", packX, packY, packW, packH, 10, 10)

        -- Border
        love.graphics.setColor(canAfford and {0.5, 0.6, 0.8} or {0.3, 0.3, 0.35})
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", packX, packY, packW, packH, 10, 10)
        love.graphics.setLineWidth(1)

        -- Pack icon
        love.graphics.setFont(UI.fonts.get(48))
        love.graphics.setColor(1, 1, 1, canAfford and 1 or 0.4)
        love.graphics.printf(pack.icon, packX, packY + 30, packW, "center")

        -- Pack name
        love.graphics.setFont(UI.fonts.get(16))
        love.graphics.setColor(1, 1, 1, canAfford and 1 or 0.5)
        love.graphics.printf(pack.name, packX, packY + 100, packW, "center")

        -- Card count
        love.graphics.setFont(UI.fonts.get(12))
        love.graphics.setColor(0.7, 0.7, 0.8)
        love.graphics.printf(pack.cards .. " Cards", packX, packY + 125, packW, "center")

        -- Guarantees
        local guarantees = {}
        if pack.guaranteedRare then table.insert(guarantees, "1 Rare+") end
        if pack.guaranteedEpic then table.insert(guarantees, "1 Epic+") end
        if pack.elementLocked then table.insert(guarantees, "Single Element") end

        if #guarantees > 0 then
            love.graphics.setColor(0.3, 0.8, 0.4)
            love.graphics.setFont(UI.fonts.get(10))
            love.graphics.printf(table.concat(guarantees, ", "), packX + 5, packY + 145, packW - 10, "center")
        end

        -- Cost
        love.graphics.setColor(canAfford and {1, 0.9, 0.3} or {0.6, 0.4, 0.4})
        love.graphics.setFont(UI.fonts.get(18))
        love.graphics.printf(pack.cost .. " coins", packX, packY + 180, packW, "center")

        -- Buy button
        local btnY = packY + packH - 45
        local btnHover = hover and my >= btnY and my <= btnY + 35

        if canAfford then
            love.graphics.setColor(btnHover and {0.3, 0.6, 0.3} or {0.2, 0.5, 0.2})
        else
            love.graphics.setColor(0.3, 0.3, 0.3)
        end
        love.graphics.rectangle("fill", packX + 15, btnY, packW - 30, 35, 6, 6)

        love.graphics.setColor(1, 1, 1, canAfford and 1 or 0.5)
        love.graphics.setFont(UI.fonts.get(14))
        love.graphics.printf(canAfford and "Buy Pack" or "Can't Afford", packX + 15, btnY + 9, packW - 30, "center")
    end

    -- Element selection for elemental pack
    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.printf("Select element for Elemental Pack:", 0, contentY + packH + 60, screenW, "center")

    local elemW = 80
    local elemSpacing = 10
    local elemTotalW = #ELEMENTS * elemW + (#ELEMENTS - 1) * elemSpacing
    local elemStartX = screenW / 2 - elemTotalW / 2
    local elemY = contentY + packH + 90

    for i, elem in ipairs(ELEMENTS) do
        local elemX = elemStartX + (i - 1) * (elemW + elemSpacing)
        local isSelected = state.selectedElement == elem.id
        local hover = mx >= elemX and mx <= elemX + elemW and my >= elemY and my <= elemY + 50

        if isSelected then
            love.graphics.setColor(elem.color[1], elem.color[2], elem.color[3], 0.8)
        elseif hover then
            love.graphics.setColor(elem.color[1] * 0.6, elem.color[2] * 0.6, elem.color[3] * 0.6)
        else
            love.graphics.setColor(0.2, 0.22, 0.28)
        end
        love.graphics.rectangle("fill", elemX, elemY, elemW, 50, 6, 6)

        love.graphics.setColor(elem.color)
        love.graphics.setLineWidth(isSelected and 2 or 1)
        love.graphics.rectangle("line", elemX, elemY, elemW, 50, 6, 6)
        love.graphics.setLineWidth(1)

        love.graphics.setFont(UI.fonts.get(20))
        love.graphics.printf(elem.icon, elemX, elemY + 5, elemW, "center")

        love.graphics.setFont(UI.fonts.get(10))
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(elem.name, elemX, elemY + 32, elemW, "center")
    end
end

function drawCollectionView(screenW, screenH, contentY, contentH)
    local mx, my = love.mouse.getPosition()

    -- Filter bar
    love.graphics.setColor(0.15, 0.15, 0.2)
    love.graphics.rectangle("fill", 20, contentY, screenW - 40, 40, 6, 6)

    -- Sort buttons
    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.print("Sort:", 30, contentY + 12)

    local sortOptions = {"element", "rarity", "power", "name"}
    local sortNames = {element = "Element", rarity = "Rarity", power = "Power", name = "Name"}
    local sortX = 75

    for _, opt in ipairs(sortOptions) do
        local btnW = 60
        local isActive = state.sortBy == opt
        local hover = mx >= sortX and mx <= sortX + btnW and my >= contentY + 5 and my <= contentY + 35

        if isActive then
            love.graphics.setColor(0.4, 0.5, 0.7)
        elseif hover then
            love.graphics.setColor(0.3, 0.35, 0.45)
        else
            love.graphics.setColor(0.2, 0.22, 0.28)
        end
        love.graphics.rectangle("fill", sortX, contentY + 5, btnW, 30, 4, 4)

        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(sortNames[opt], sortX, contentY + 12, btnW, "center")

        sortX = sortX + btnW + 5
    end

    -- Element filter
    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.print("Filter:", sortX + 20, contentY + 12)

    local filterX = sortX + 65
    local allHover = mx >= filterX and mx <= filterX + 40 and my >= contentY + 5 and my <= contentY + 35

    if state.filterElement == "all" then
        love.graphics.setColor(0.4, 0.5, 0.7)
    elseif allHover then
        love.graphics.setColor(0.3, 0.35, 0.45)
    else
        love.graphics.setColor(0.2, 0.22, 0.28)
    end
    love.graphics.rectangle("fill", filterX, contentY + 5, 40, 30, 4, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("All", filterX, contentY + 12, 40, "center")

    filterX = filterX + 45
    for _, elem in ipairs(ELEMENTS) do
        local isActive = state.filterElement == elem.id
        local hover = mx >= filterX and mx <= filterX + 30 and my >= contentY + 5 and my <= contentY + 35

        if isActive then
            love.graphics.setColor(elem.color[1], elem.color[2], elem.color[3], 0.8)
        elseif hover then
            love.graphics.setColor(elem.color[1] * 0.5, elem.color[2] * 0.5, elem.color[3] * 0.5)
        else
            love.graphics.setColor(0.2, 0.22, 0.28)
        end
        love.graphics.rectangle("fill", filterX, contentY + 5, 30, 30, 4, 4)

        love.graphics.setFont(UI.fonts.get(16))
        love.graphics.printf(elem.icon, filterX, contentY + 8, 30, "center")

        filterX = filterX + 35
    end

    -- Card grid
    local gridY = contentY + 50
    local gridH = contentH - 60
    local cardW, cardH = 140, 190
    local cols = math.floor((screenW - 60) / (cardW + 15))
    local startX = (screenW - cols * (cardW + 15) + 15) / 2

    local sortedCards = getSortedCollection()
    local maxScroll = math.max(0, math.ceil(#sortedCards / cols) * (cardH + 15) - gridH)
    state.collectionScroll = math.max(0, math.min(state.collectionScroll, maxScroll))

    love.graphics.setScissor(0, gridY, screenW, gridH)

    for i, entry in ipairs(sortedCards) do
        local card = entry.card
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local cardX = startX + col * (cardW + 15)
        local cardY = gridY + row * (cardH + 15) - state.collectionScroll

        if cardY + cardH >= gridY and cardY <= gridY + gridH then
            drawCard(card, cardX, cardY, cardW, cardH, entry.index)
        end
    end

    love.graphics.setScissor()

    -- Scrollbar for collection
    if maxScroll > 0 then
        local scrollbarX = screenW - 20
        local scrollbarH = gridH
        local thumbH = math.max(30, scrollbarH * (gridH / (math.ceil(#sortedCards / cols) * (cardH + 15))))
        local thumbY = gridY + (state.collectionScroll / maxScroll) * (scrollbarH - thumbH)
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", scrollbarX, gridY, 8, scrollbarH, 4, 4)
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.rectangle("fill", scrollbarX, thumbY, 8, thumbH, 4, 4)
    end

    -- Empty collection message
    if #sortedCards == 0 then
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.setFont(UI.fonts.get(18))
        love.graphics.printf("No cards in collection.\nOpen some packs!", 0, gridY + 100, screenW, "center")
    end

    -- Selected card detail
    if state.selectedCard then
        drawCardDetail(screenW, screenH)
    end
end

function drawCard(card, x, y, w, h, index)
    local mx, my = love.mouse.getPosition()
    local hover = mx >= x and mx <= x + w and my >= y and my <= y + h
    local elem = getElement(card.element)
    local rarity = getRarity(card.rarity)

    -- Card background with element color
    if hover then
        love.graphics.setColor(elem.color[1] * 0.7, elem.color[2] * 0.7, elem.color[3] * 0.7)
    else
        love.graphics.setColor(elem.color[1] * 0.4, elem.color[2] * 0.4, elem.color[3] * 0.4)
    end
    love.graphics.rectangle("fill", x, y, w, h, 8, 8)

    -- Foil effect
    if card.foil then
        local time = love.timer.getTime()
        local shimmer = math.sin(time * 2 + x * 0.01) * 0.15 + 0.15
        love.graphics.setColor(1, 1, 1, shimmer)
        love.graphics.rectangle("fill", x, y, w, h, 8, 8)
    end

    -- Border (rarity color)
    love.graphics.setColor(rarity.color)
    love.graphics.setLineWidth(card.foil and 3 or 2)
    love.graphics.rectangle("line", x, y, w, h, 8, 8)
    love.graphics.setLineWidth(1)

    -- Creature portrait (instead of just element icon)
    local portrait = getCreaturePortrait(card.creature)
    if portrait then
        love.graphics.setColor(1, 1, 1)
        local imgW, imgH = portrait:getDimensions()
        local portraitSize = math.min(w - 10, 60)
        local scale = portraitSize / math.max(imgW, imgH)
        local portraitX = x + (w - imgW * scale) / 2
        local portraitY = y + 8
        love.graphics.draw(portrait, portraitX, portraitY, 0, scale, scale)

        -- Element icon small in corner
        love.graphics.setFont(UI.fonts.get(14))
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.print(elem.icon, x + 5, y + 5)
    else
        -- Fallback: Element icon large
        love.graphics.setFont(UI.fonts.get(32))
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.printf(elem.icon, x, y + 20, w, "center")
    end

    -- Creature name
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(card.creature, x + 5, y + 70, w - 10, "center")

    -- Power
    love.graphics.setFont(UI.fonts.get(24))
    love.graphics.setColor(1, 0.9, 0.3)
    love.graphics.printf(tostring(card.power), x, y + 110, w, "center")

    -- Rarity
    love.graphics.setFont(UI.fonts.get(10))
    love.graphics.setColor(rarity.color)
    love.graphics.printf(rarity.name, x, y + 145, w, "center")

    -- Foil indicator
    if card.foil then
        love.graphics.setColor(1, 0.9, 0.5)
        love.graphics.setFont(UI.fonts.get(10))
        love.graphics.print("FOIL", x + 5, y + 5)
    end

    -- Level indicator
    if card.level and card.level > 1 then
        love.graphics.setColor(0.5, 0.8, 0.9)
        love.graphics.setFont(UI.fonts.get(10))
        love.graphics.printf("Lv." .. card.level, x, y + 160, w, "center")
    end

    -- Element name
    love.graphics.setColor(elem.color)
    love.graphics.setFont(UI.fonts.get(10))
    love.graphics.printf(elem.name, x, y + h - 20, w, "center")
end

function drawCardDetail(screenW, screenH)
    local card = state.selectedCard
    local elem = getElement(card.element)
    local rarity = getRarity(card.rarity)

    -- Overlay
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Detail card (larger)
    local cardW, cardH = 280, 400
    local cardX = screenW / 2 - cardW / 2
    local cardY = screenH / 2 - cardH / 2 - 30

    -- Background
    love.graphics.setColor(elem.color[1] * 0.5, elem.color[2] * 0.5, elem.color[3] * 0.5)
    love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 15, 15)

    -- Foil effect
    if card.foil then
        local time = love.timer.getTime()
        for i = 0, 5 do
            local shimmer = math.sin(time * 3 + i * 0.5) * 0.1 + 0.1
            love.graphics.setColor(1, 1, 1, shimmer)
            love.graphics.rectangle("fill", cardX + i * 3, cardY + i * 3, cardW - i * 6, cardH - i * 6, 15 - i, 15 - i)
        end
    end

    -- Border
    love.graphics.setColor(rarity.color)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", cardX, cardY, cardW, cardH, 15, 15)
    love.graphics.setLineWidth(1)

    -- Creature portrait
    local portrait = getCreaturePortrait(card.creature)
    if portrait then
        love.graphics.setColor(1, 1, 1)
        local imgW, imgH = portrait:getDimensions()
        local portraitSize = 90
        local scale = portraitSize / math.max(imgW, imgH)
        local portraitX = cardX + (cardW - imgW * scale) / 2
        local portraitY = cardY + 20
        love.graphics.draw(portrait, portraitX, portraitY, 0, scale, scale)

        -- Element icon small in corner
        love.graphics.setFont(UI.fonts.get(24))
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.print(elem.icon, cardX + 15, cardY + 15)
    else
        -- Fallback: Element icon large
        love.graphics.setFont(UI.fonts.get(64))
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(elem.icon, cardX, cardY + 30, cardW, "center")
    end

    -- Creature name
    love.graphics.setFont(UI.fonts.get(24))
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(card.creature, cardX, cardY + 120, cardW, "center")

    -- Element name
    love.graphics.setColor(elem.color)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.printf(elem.name .. " Type", cardX, cardY + 150, cardW, "center")

    -- Power
    love.graphics.setFont(UI.fonts.get(48))
    love.graphics.setColor(1, 0.9, 0.3)
    love.graphics.printf(tostring(card.power), cardX, cardY + 180, cardW, "center")
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.printf("POWER", cardX, cardY + 235, cardW, "center")

    -- Description
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.printf(card.description, cardX + 20, cardY + 270, cardW - 40, "center")

    -- Rarity
    love.graphics.setColor(rarity.color)
    love.graphics.setFont(UI.fonts.get(16))
    love.graphics.printf(rarity.name, cardX, cardY + 320, cardW, "center")

    -- Foil indicator
    if card.foil then
        love.graphics.setColor(1, 0.9, 0.5)
        love.graphics.setFont(UI.fonts.get(14))
        love.graphics.printf("FOIL CARD", cardX, cardY + 345, cardW, "center")
    end

    -- Level display
    love.graphics.setColor(0.5, 0.8, 0.9)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.printf("Level " .. (card.level or 1), cardX, cardY + 345, cardW, "center")

    -- Sell/Flux values
    local sellValue = rarity.sellValue * (card.foil and 2 or 1)
    local fluxValue = getFluxValue(card)
    local levelCost = getLevelUpCost(card)
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.setFont(UI.fonts.get(11))
    love.graphics.printf("Sell: " .. sellValue .. " coins | Break: " .. fluxValue .. " Flux", cardX, cardY + cardH - 30, cardW, "center")

    -- Buttons
    local mx, my = love.mouse.getPosition()
    local btnY = cardY + cardH + 15
    local btnW = 85
    local btnH = 35
    local gap = 8

    -- Sell button
    local sellHover = mx >= cardX and mx <= cardX + btnW and my >= btnY and my <= btnY + btnH
    love.graphics.setColor(sellHover and {0.7, 0.3, 0.3} or {0.5, 0.2, 0.2})
    love.graphics.rectangle("fill", cardX, btnY, btnW, btnH, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.printf("Sell", cardX, btnY + 10, btnW, "center")

    -- Break button (for Flux)
    local breakX = cardX + btnW + gap
    local breakHover = mx >= breakX and mx <= breakX + btnW and my >= btnY and my <= btnY + btnH
    love.graphics.setColor(breakHover and {0.6, 0.3, 0.7} or {0.45, 0.2, 0.55})
    love.graphics.rectangle("fill", breakX, btnY, btnW, btnH, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Break", breakX, btnY + 10, btnW, "center")

    -- Level Up button
    local levelX = breakX + btnW + gap
    local canLevel = state.flux >= levelCost
    local levelHover = mx >= levelX and mx <= levelX + btnW and my >= btnY and my <= btnY + btnH
    if canLevel then
        love.graphics.setColor(levelHover and {0.3, 0.6, 0.4} or {0.2, 0.5, 0.3})
    else
        love.graphics.setColor(0.3, 0.3, 0.3)
    end
    love.graphics.rectangle("fill", levelX, btnY, btnW, btnH, 5, 5)
    love.graphics.setColor(1, 1, 1, canLevel and 1 or 0.5)
    love.graphics.setFont(UI.fonts.get(10))
    love.graphics.printf("Level Up\n" .. levelCost .. " Flux", levelX, btnY + 5, btnW, "center")

    -- Add to Team button (second row)
    local btnY2 = btnY + btnH + 5
    local inTeam = false
    for _, tc in ipairs(state.battleTeam) do
        if tc.id == card.id then inTeam = true break end
    end
    local teamBtnW = (btnW * 2 + gap)
    local teamHover = mx >= cardX and mx <= cardX + teamBtnW and my >= btnY2 and my <= btnY2 + btnH
    if inTeam then
        love.graphics.setColor(teamHover and {0.6, 0.4, 0.3} or {0.5, 0.3, 0.2})
    elseif #state.battleTeam < 5 then
        love.graphics.setColor(teamHover and {0.3, 0.5, 0.6} or {0.2, 0.4, 0.5})
    else
        love.graphics.setColor(0.3, 0.3, 0.3)
    end
    love.graphics.rectangle("fill", cardX, btnY2, teamBtnW, btnH, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.printf(inTeam and "Remove from Team" or "Add to Team", cardX, btnY2 + 10, teamBtnW, "center")

    -- Close button
    local closeX = cardX + teamBtnW + gap
    local closeHover = mx >= closeX and mx <= closeX + btnW and my >= btnY2 and my <= btnY2 + btnH
    love.graphics.setColor(closeHover and {0.4, 0.4, 0.5} or {0.3, 0.3, 0.4})
    love.graphics.rectangle("fill", closeX, btnY2, btnW, btnH, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Close", closeX, btnY2 + 10, btnW, "center")
end

function drawPackOpening(screenW, screenH, contentY, contentH)
    local mx, my = love.mouse.getPosition()

    -- Pack info
    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(UI.fonts.get(24))
    love.graphics.printf("Opening " .. state.currentPack.name .. "!", 0, contentY + 10, screenW, "center")

    -- Cards
    local cardW, cardH = 120, 170
    local totalW = #state.openedCards * cardW + (#state.openedCards - 1) * 15
    local startX = screenW / 2 - totalW / 2
    local cardY = contentY + 60

    for i, card in ipairs(state.openedCards) do
        local cardX = startX + (i - 1) * (cardW + 15)
        local revealed = i <= state.revealIndex

        if revealed then
            drawCard(card, cardX, cardY, cardW, cardH, nil)

            -- Sparkle animation for rare+
            for _, anim in ipairs(state.animations) do
                if anim.cardIndex == i then
                    local progress = anim.timer / anim.duration
                    local rarity = getRarity(card.rarity)
                    for j = 1, 8 do
                        local angle = (j / 8) * math.pi * 2 + progress * math.pi * 2
                        local dist = 40 + progress * 30
                        local sparkX = cardX + cardW / 2 + math.cos(angle) * dist
                        local sparkY = cardY + cardH / 2 + math.sin(angle) * dist
                        local alpha = 1 - progress
                        love.graphics.setColor(rarity.color[1], rarity.color[2], rarity.color[3], alpha)
                        love.graphics.circle("fill", sparkX, sparkY, 4 * (1 - progress * 0.5))
                    end
                end
            end
        else
            -- Face down card
            love.graphics.setColor(0.2, 0.25, 0.35)
            love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 8, 8)
            love.graphics.setColor(0.4, 0.5, 0.7)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", cardX, cardY, cardW, cardH, 8, 8)
            love.graphics.setLineWidth(1)

            -- Question mark
            love.graphics.setFont(UI.fonts.get(40))
            love.graphics.setColor(0.5, 0.6, 0.8)
            love.graphics.printf("?", cardX, cardY + cardH / 2 - 25, cardW, "center")
        end
    end

    -- Click to reveal faster
    if state.revealIndex < #state.openedCards then
        love.graphics.setColor(0.6, 0.6, 0.7)
        love.graphics.setFont(UI.fonts.get(14))
        love.graphics.printf("Click to reveal faster!", 0, cardY + cardH + 30, screenW, "center")
    else
        -- All revealed - add to collection button
        local btnW, btnH = 200, 45
        local btnX = screenW / 2 - btnW / 2
        local btnY = cardY + cardH + 30
        local hover = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH

        love.graphics.setColor(hover and {0.3, 0.6, 0.3} or {0.2, 0.5, 0.2})
        love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 8, 8)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.fonts.get(16))
        love.graphics.printf("Add to Collection", btnX, btnY + 13, btnW, "center")
    end
end

-- Draw battle opponent selection view
function drawBattleSelectView(screenW, screenH, contentY, contentH)
    local mx, my = love.mouse.getPosition()

    -- Title
    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(UI.fonts.get(20))
    love.graphics.printf("TAVERN CHALLENGERS", 0, contentY + 10, screenW, "center")

    -- Player team display
    love.graphics.setColor(0.8, 0.8, 0.9)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.print("Your Team (" .. #state.battleTeam .. "/5):", 30, contentY + 50)

    -- Team slots
    local slotW, slotH = 80, 100
    for i = 1, 5 do
        local slotX = 30 + (i - 1) * (slotW + 10)
        local slotY = contentY + 75
        local card = state.battleTeam[i]

        if card then
            local elem = getElement(card.element)
            love.graphics.setColor(elem.color[1] * 0.5, elem.color[2] * 0.5, elem.color[3] * 0.5)
            love.graphics.rectangle("fill", slotX, slotY, slotW, slotH, 5, 5)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(UI.fonts.get(10))
            love.graphics.printf(card.creature, slotX, slotY + 10, slotW, "center")
            love.graphics.setFont(UI.fonts.get(16))
            love.graphics.setColor(1, 0.9, 0.3)
            love.graphics.printf(tostring(card.power), slotX, slotY + 50, slotW, "center")
            love.graphics.setFont(UI.fonts.get(10))
            love.graphics.setColor(0.7, 0.7, 0.8)
            love.graphics.printf("Lv." .. (card.level or 1), slotX, slotY + 75, slotW, "center")
        else
            love.graphics.setColor(0.2, 0.2, 0.25)
            love.graphics.rectangle("fill", slotX, slotY, slotW, slotH, 5, 5)
            love.graphics.setColor(0.4, 0.4, 0.5)
            love.graphics.rectangle("line", slotX, slotY, slotW, slotH, 5, 5)
            love.graphics.setFont(UI.fonts.get(10))
            love.graphics.printf("Empty", slotX, slotY + 40, slotW, "center")
        end
    end

    -- Manage team button
    local manageBtnX = 30 + 5 * (slotW + 10) + 20
    local manageBtnY = contentY + 100
    local manageHover = mx >= manageBtnX and mx <= manageBtnX + 100 and my >= manageBtnY and my <= manageBtnY + 35
    love.graphics.setColor(manageHover and {0.35, 0.45, 0.55} or {0.25, 0.35, 0.45})
    love.graphics.rectangle("fill", manageBtnX, manageBtnY, 100, 35, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.printf("Manage", manageBtnX, manageBtnY + 10, 100, "center")

    -- Opponents list
    love.graphics.setColor(0.8, 0.8, 0.9)
    love.graphics.setFont(UI.fonts.get(16))
    love.graphics.print("Choose Your Opponent:", 30, contentY + 195)

    -- Refresh button to generate new challengers
    local refreshBtnX = 220
    local refreshBtnY = contentY + 192
    local refreshBtnW = 100
    local refreshBtnH = 28
    local refreshHover = mx >= refreshBtnX and mx <= refreshBtnX + refreshBtnW and my >= refreshBtnY and my <= refreshBtnY + refreshBtnH
    love.graphics.setColor(refreshHover and {0.4, 0.5, 0.6} or {0.3, 0.4, 0.5})
    love.graphics.rectangle("fill", refreshBtnX, refreshBtnY, refreshBtnW, refreshBtnH, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.printf("⟳ Refresh", refreshBtnX, refreshBtnY + 7, refreshBtnW, "center")

    local oppY = contentY + 225
    for i, opp in ipairs(state.opponents) do
        local oppH = 80
        local hover = mx >= 30 and mx <= screenW - 60 and my >= oppY and my <= oppY + oppH

        love.graphics.setColor(hover and {0.25, 0.3, 0.4} or {0.15, 0.18, 0.25})
        love.graphics.rectangle("fill", 30, oppY, screenW - 60, oppH, 8, 8)

        -- Draw opponent portrait
        local portraitSize = 60
        local portraitX = 40
        local portraitY = oppY + 10
        if opp.portrait then
            love.graphics.setColor(1, 1, 1)
            local imgW, imgH = opp.portrait:getDimensions()
            local scale = portraitSize / math.max(imgW, imgH)
            love.graphics.draw(opp.portrait, portraitX, portraitY, 0, scale, scale)
        else
            -- Fallback colored box
            love.graphics.setColor(0.3, 0.3, 0.4)
            love.graphics.rectangle("fill", portraitX, portraitY, portraitSize, portraitSize, 5, 5)
        end
        -- Portrait frame
        love.graphics.setColor(0.6, 0.5, 0.3)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", portraitX - 1, portraitY - 1, portraitSize + 2, portraitSize + 2, 5, 5)
        love.graphics.setLineWidth(1)

        -- Difficulty indicator (shifted right to account for portrait)
        local textStartX = portraitX + portraitSize + 15
        love.graphics.setColor(0.9, 0.4, 0.4)
        for d = 1, opp.difficulty do
            love.graphics.print("★", textStartX + (d - 1) * 15, oppY + 5)
        end

        -- Name and profession (shifted right to account for portrait)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.fonts.get(16))
        love.graphics.print(opp.name, textStartX, oppY + 25)
        love.graphics.setColor(0.7, 0.7, 0.8)
        love.graphics.setFont(UI.fonts.get(12))
        love.graphics.print(opp.profession .. " - " .. opp.professionDesc, textStartX, oppY + 48)

        -- Rewards
        love.graphics.setColor(0.8, 0.4, 0.9)
        love.graphics.print("Flux: " .. opp.reward.flux, screenW - 200, oppY + 25)
        love.graphics.setColor(1, 0.9, 0.3)
        love.graphics.print("Coins: " .. opp.reward.coins, screenW - 200, oppY + 45)

        -- Challenge button
        local btnX = screenW - 130
        local btnHover = hover and mx >= btnX and mx <= btnX + 90
        local canChallenge = #state.battleTeam == 5
        if canChallenge then
            love.graphics.setColor(btnHover and {0.4, 0.6, 0.4} or {0.3, 0.5, 0.3})
        else
            love.graphics.setColor(0.3, 0.3, 0.3)
        end
        love.graphics.rectangle("fill", btnX, oppY + 25, 90, 30, 5, 5)
        love.graphics.setColor(1, 1, 1, canChallenge and 1 or 0.5)
        love.graphics.setFont(UI.fonts.get(12))
        love.graphics.printf("Challenge", btnX, oppY + 32, 90, "center")

        oppY = oppY + oppH + 10
    end

    if #state.battleTeam < 5 then
        love.graphics.setColor(0.9, 0.5, 0.3)
        love.graphics.setFont(UI.fonts.get(12))
        love.graphics.printf("Select 5 creatures for your team to challenge opponents!", 0, contentY + 180, screenW, "center")
    end
end

-- Draw evolution view
function drawEvolveView(screenW, screenH, contentY, contentH)
    local mx, my = love.mouse.getPosition()

    -- Title
    love.graphics.setColor(0.2, 0.8, 0.4)
    love.graphics.setFont(UI.fonts.get(20))
    love.graphics.printf("EVOLUTION CHAMBER", 0, contentY + 10, screenW, "center")

    -- Instructions
    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.printf("Select a card to evolve it into a stronger form. Evolution increases rarity and power.", 50, contentY + 40, screenW - 100, "center")

    -- Cards grid (evolvable only)
    local gridY = contentY + 80
    local cardW, cardH = 120, 160
    local cols = math.floor((screenW - 60) / (cardW + 10))
    local startX = (screenW - cols * (cardW + 10) + 10) / 2

    local evolvableCards = {}
    for i, card in ipairs(state.collection) do
        if EVOLUTION_CHAINS[card.creature] then
            table.insert(evolvableCards, {index = i, card = card})
        end
    end

    for i, entry in ipairs(evolvableCards) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local cardX = startX + col * (cardW + 10)
        local cardY = gridY + row * (cardH + 50)

        local card = entry.card
        local elem = getElement(card.element)
        local rarity = getRarity(card.rarity)
        local canDo, result = canEvolve(card)
        local evolvedName = EVOLUTION_CHAINS[card.creature]
        local cost = getEvolutionCost(card)

        local hover = mx >= cardX and mx <= cardX + cardW and my >= cardY and my <= cardY + cardH + 40

        -- Card
        love.graphics.setColor(elem.color[1] * 0.4, elem.color[2] * 0.4, elem.color[3] * 0.4)
        love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 6, 6)
        love.graphics.setColor(rarity.color)
        love.graphics.rectangle("line", cardX, cardY, cardW, cardH, 6, 6)

        love.graphics.setFont(UI.fonts.get(10))
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(card.creature, cardX, cardY + 10, cardW, "center")
        love.graphics.setFont(UI.fonts.get(18))
        love.graphics.setColor(1, 0.9, 0.3)
        love.graphics.printf(tostring(card.power), cardX, cardY + 40, cardW, "center")
        love.graphics.setFont(UI.fonts.get(10))
        love.graphics.setColor(rarity.color)
        love.graphics.printf(rarity.name, cardX, cardY + 70, cardW, "center")
        love.graphics.setColor(0.7, 0.7, 0.8)
        love.graphics.printf("Lv." .. (card.level or 1), cardX, cardY + 90, cardW, "center")

        -- Evolution arrow and target
        love.graphics.setColor(0.2, 0.8, 0.4)
        love.graphics.printf("↓", cardX, cardY + 105, cardW, "center")
        love.graphics.setFont(UI.fonts.get(10))
        love.graphics.setColor(0.4, 0.9, 0.5)
        love.graphics.printf(evolvedName, cardX, cardY + 120, cardW, "center")

        -- Evolve button
        local btnY = cardY + cardH + 5
        if canDo then
            love.graphics.setColor(hover and {0.3, 0.7, 0.4} or {0.2, 0.6, 0.3})
        else
            love.graphics.setColor(0.3, 0.3, 0.3)
        end
        love.graphics.rectangle("fill", cardX, btnY, cardW, 30, 4, 4)
        love.graphics.setColor(1, 1, 1, canDo and 1 or 0.5)
        love.graphics.setFont(UI.fonts.get(10))
        love.graphics.printf("Evolve (" .. cost .. " Flux)", cardX, btnY + 8, cardW, "center")
    end

    if #evolvableCards == 0 then
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.setFont(UI.fonts.get(16))
        love.graphics.printf("No evolvable cards in your collection.\nCollect more creature cards!", 0, contentY + 150, screenW, "center")
    end
end

-- Draw fusion view
function drawFuseView(screenW, screenH, contentY, contentH)
    local mx, my = love.mouse.getPosition()

    -- Title
    love.graphics.setColor(0.8, 0.4, 0.9)
    love.graphics.setFont(UI.fonts.get(20))
    love.graphics.printf("FUSION LABORATORY", 0, contentY + 10, screenW, "center")

    -- Instructions
    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.printf("Select two cards to fuse them into a new creature. Both cards will be consumed.", 50, contentY + 40, screenW - 100, "center")

    -- Fusion slots
    local slotW, slotH = 140, 180
    local slot1X = screenW / 2 - slotW - 60
    local slot2X = screenW / 2 + 60
    local slotY = contentY + 80

    -- Slot 1
    local card1 = state.selectedForFuse[1]
    if card1 then
        local elem = getElement(card1.element)
        love.graphics.setColor(elem.color[1] * 0.5, elem.color[2] * 0.5, elem.color[3] * 0.5)
        love.graphics.rectangle("fill", slot1X, slotY, slotW, slotH, 8, 8)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.fonts.get(12))
        love.graphics.printf(card1.creature, slot1X, slotY + 60, slotW, "center")
        love.graphics.setFont(UI.fonts.get(20))
        love.graphics.setColor(1, 0.9, 0.3)
        love.graphics.printf(tostring(card1.power), slot1X, slotY + 90, slotW, "center")
    else
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", slot1X, slotY, slotW, slotH, 8, 8)
        love.graphics.setColor(0.4, 0.4, 0.5)
        love.graphics.rectangle("line", slot1X, slotY, slotW, slotH, 8, 8)
        love.graphics.setFont(UI.fonts.get(14))
        love.graphics.printf("Card 1", slot1X, slotY + 70, slotW, "center")
    end

    -- Plus sign
    love.graphics.setColor(0.8, 0.4, 0.9)
    love.graphics.setFont(UI.fonts.get(40))
    love.graphics.printf("+", screenW / 2 - 20, slotY + 60, 40, "center")

    -- Slot 2
    local card2 = state.selectedForFuse[2]
    if card2 then
        local elem = getElement(card2.element)
        love.graphics.setColor(elem.color[1] * 0.5, elem.color[2] * 0.5, elem.color[3] * 0.5)
        love.graphics.rectangle("fill", slot2X, slotY, slotW, slotH, 8, 8)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.fonts.get(12))
        love.graphics.printf(card2.creature, slot2X, slotY + 60, slotW, "center")
        love.graphics.setFont(UI.fonts.get(20))
        love.graphics.setColor(1, 0.9, 0.3)
        love.graphics.printf(tostring(card2.power), slot2X, slotY + 90, slotW, "center")
    else
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", slot2X, slotY, slotW, slotH, 8, 8)
        love.graphics.setColor(0.4, 0.4, 0.5)
        love.graphics.rectangle("line", slot2X, slotY, slotW, slotH, 8, 8)
        love.graphics.setFont(UI.fonts.get(14))
        love.graphics.printf("Card 2", slot2X, slotY + 70, slotW, "center")
    end

    -- Check fusion result
    local canDo, result = canFuse(card1, card2)
    local fuseY = slotY + slotH + 20

    if card1 and card2 then
        if canDo then
            love.graphics.setColor(0.4, 0.9, 0.5)
            love.graphics.setFont(UI.fonts.get(14))
            love.graphics.printf("= " .. result.result .. " =", 0, fuseY, screenW, "center")

            -- Fuse button
            local btnW, btnH = 150, 40
            local btnX = screenW / 2 - btnW / 2
            local btnY = fuseY + 30
            local btnHover = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH

            love.graphics.setColor(btnHover and {0.5, 0.3, 0.6} or {0.4, 0.2, 0.5})
            love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 6, 6)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(UI.fonts.get(14))
            love.graphics.printf("Fuse (" .. getFusionCost() .. " Flux)", btnX, btnY + 12, btnW, "center")
        else
            love.graphics.setColor(0.7, 0.4, 0.4)
            love.graphics.setFont(UI.fonts.get(12))
            love.graphics.printf(result, 0, fuseY, screenW, "center")
        end
    end

    -- Available recipes
    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.printf("Available Fusion Recipes:", 0, fuseY + 90, screenW, "center")

    local recipeY = fuseY + 115
    love.graphics.setFont(UI.fonts.get(11))
    for _, recipe in ipairs(FUSION_RECIPES) do
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.printf(recipe.inputs[1] .. " + " .. recipe.inputs[2] .. " = " .. recipe.result, 0, recipeY, screenW, "center")
        recipeY = recipeY + 18
    end

    -- Card selection area
    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.print("Click cards below to select for fusion:", 30, screenH - 200)

    local gridY = screenH - 175
    local cardW, cardH = 80, 100
    local startX = 30

    for i, card in ipairs(state.collection) do
        if i <= 10 then  -- Show first 10 cards
            local cardX = startX + (i - 1) * (cardW + 5)
            local elem = getElement(card.element)
            local isSelected = (card1 and card1.id == card.id) or (card2 and card2.id == card.id)

            love.graphics.setColor(elem.color[1] * 0.4, elem.color[2] * 0.4, elem.color[3] * 0.4)
            love.graphics.rectangle("fill", cardX, gridY, cardW, cardH, 4, 4)
            if isSelected then
                love.graphics.setColor(0.8, 0.4, 0.9)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", cardX, gridY, cardW, cardH, 4, 4)
                love.graphics.setLineWidth(1)
            end
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(UI.fonts.get(9))
            love.graphics.printf(card.creature, cardX, gridY + 30, cardW, "center")
        end
    end
end

-- Draw battle view (active battle)
function drawBattleView(screenW, screenH, contentY, contentH)
    local mx, my = love.mouse.getPosition()
    local battle = state.battleState

    -- Opponent info with portrait (use stored portrait, not random)
    local npcPortrait = battle.opponent.portrait
    if npcPortrait then
        love.graphics.setColor(1, 1, 1)
        local imgW, imgH = npcPortrait:getDimensions()
        local scale = 50 / math.max(imgW, imgH)
        love.graphics.draw(npcPortrait, 30, contentY + 5, 0, scale, scale)
    else
        -- Fallback colored box if no portrait
        love.graphics.setColor(0.3, 0.3, 0.4)
        love.graphics.rectangle("fill", 30, contentY + 5, 50, 50, 5, 5)
    end
    -- Portrait frame
    love.graphics.setColor(0.6, 0.5, 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 29, contentY + 4, 52, 52, 5, 5)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.9, 0.4, 0.4)
    love.graphics.setFont(UI.fonts.get(16))
    love.graphics.print(battle.opponent.name .. " - " .. battle.opponent.profession, 90, contentY + 15)

    -- Opponent's active creature
    local oppCard = battle.opponent.team[battle.oppActive]
    if oppCard then
        local elem = getElement(oppCard.element)
        love.graphics.setColor(elem.color[1] * 0.5, elem.color[2] * 0.5, elem.color[3] * 0.5)
        love.graphics.rectangle("fill", screenW / 2 - 80, contentY + 40, 160, 120, 8, 8)

        -- Creature portrait
        local oppPortrait = getCreaturePortrait(oppCard.creature)
        if oppPortrait then
            love.graphics.setColor(1, 1, 1)
            local imgW, imgH = oppPortrait:getDimensions()
            local scale = 50 / math.max(imgW, imgH)
            love.graphics.draw(oppPortrait, screenW / 2 - 25, contentY + 50, 0, scale, scale)
        end

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.fonts.get(14))
        love.graphics.printf(oppCard.creature, screenW / 2 - 80, contentY + 105, 160, "center")

        -- HP bar
        local hpPercent = oppCard.hp / oppCard.maxHp
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.rectangle("fill", screenW / 2 - 60, contentY + 130, 120, 15, 3, 3)
        love.graphics.setColor(hpPercent > 0.5 and {0.3, 0.8, 0.3} or hpPercent > 0.25 and {0.9, 0.7, 0.2} or {0.9, 0.3, 0.3})
        love.graphics.rectangle("fill", screenW / 2 - 60, contentY + 130, 120 * hpPercent, 15, 3, 3)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.fonts.get(10))
        love.graphics.printf(math.floor(oppCard.hp) .. "/" .. oppCard.maxHp, screenW / 2 - 60, contentY + 132, 120, "center")
    end

    -- Player's active creature
    local playerCard = battle.playerTeam[battle.playerActive]
    if playerCard then
        local elem = getElement(playerCard.element)
        love.graphics.setColor(elem.color[1] * 0.5, elem.color[2] * 0.5, elem.color[3] * 0.5)
        love.graphics.rectangle("fill", screenW / 2 - 80, contentY + 200, 160, 120, 8, 8)

        -- Creature portrait
        local playerPortrait = getCreaturePortrait(playerCard.creature)
        if playerPortrait then
            love.graphics.setColor(1, 1, 1)
            local imgW, imgH = playerPortrait:getDimensions()
            local scale = 50 / math.max(imgW, imgH)
            love.graphics.draw(playerPortrait, screenW / 2 - 25, contentY + 210, 0, scale, scale)
        end

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.fonts.get(14))
        love.graphics.printf(playerCard.creature, screenW / 2 - 80, contentY + 265, 160, "center")

        -- HP bar
        local hpPercent = playerCard.hp / playerCard.maxHp
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.rectangle("fill", screenW / 2 - 60, contentY + 290, 120, 15, 3, 3)
        love.graphics.setColor(hpPercent > 0.5 and {0.3, 0.8, 0.3} or hpPercent > 0.25 and {0.9, 0.7, 0.2} or {0.9, 0.3, 0.3})
        love.graphics.rectangle("fill", screenW / 2 - 60, contentY + 290, 120 * hpPercent, 15, 3, 3)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.fonts.get(10))
        love.graphics.printf(math.floor(playerCard.hp) .. "/" .. playerCard.maxHp, screenW / 2 - 60, contentY + 292, 120, "center")

        -- Move buttons
        local moves = ELEMENT_MOVES[playerCard.element]
        if moves and battle.phase == "player_turn" then
            for i, move in ipairs(moves) do
                local btnX = screenW / 2 - 150 + (i - 1) * 160
                local btnY = contentY + 340
                local btnHover = mx >= btnX and mx <= btnX + 140 and my >= btnY and my <= btnY + 50

                love.graphics.setColor(btnHover and {0.4, 0.5, 0.6} or {0.25, 0.35, 0.45})
                love.graphics.rectangle("fill", btnX, btnY, 140, 50, 6, 6)
                love.graphics.setColor(1, 1, 1)
                love.graphics.setFont(UI.fonts.get(12))
                love.graphics.printf(move.name, btnX, btnY + 8, 140, "center")
                love.graphics.setColor(0.7, 0.7, 0.8)
                love.graphics.setFont(UI.fonts.get(10))
                love.graphics.printf("Power: " .. move.power, btnX, btnY + 28, 140, "center")
            end
        end
    end

    -- Battle log
    love.graphics.setColor(0.15, 0.15, 0.2)
    love.graphics.rectangle("fill", 30, contentY + 400, screenW - 60, 80, 6, 6)
    love.graphics.setColor(0.8, 0.8, 0.9)
    love.graphics.setFont(UI.fonts.get(12))
    if battle.log and #battle.log > 0 then
        local logY = contentY + 410
        for i = math.max(1, #battle.log - 3), #battle.log do
            love.graphics.print(battle.log[i], 40, logY)
            logY = logY + 18
        end
    end

    -- Battle result overlay
    if battle.phase == "victory" or battle.phase == "defeat" then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)

        if battle.phase == "victory" then
            love.graphics.setColor(0.3, 0.9, 0.4)
            love.graphics.setFont(UI.fonts.get(36))
            love.graphics.printf("VICTORY!", 0, screenH / 2 - 80, screenW, "center")
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(UI.fonts.get(18))
            love.graphics.printf("Rewards: " .. battle.opponent.reward.flux .. " Flux, " .. battle.opponent.reward.coins .. " Coins", 0, screenH / 2 - 30, screenW, "center")
        else
            love.graphics.setColor(0.9, 0.3, 0.3)
            love.graphics.setFont(UI.fonts.get(36))
            love.graphics.printf("DEFEAT", 0, screenH / 2 - 80, screenW, "center")
        end

        -- Continue button
        local btnW, btnH = 150, 45
        local btnX = screenW / 2 - btnW / 2
        local btnY = screenH / 2 + 30
        local btnHover = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH

        love.graphics.setColor(btnHover and {0.4, 0.5, 0.6} or {0.3, 0.4, 0.5})
        love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 6, 6)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.fonts.get(16))
        love.graphics.printf("Continue", btnX, btnY + 13, btnW, "center")
    end
end

-- Draw help overlay
function drawHelpOverlay(screenW, screenH)
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    local panelW, panelH = 600, 500
    local panelX = screenW / 2 - panelW / 2
    local panelY = screenH / 2 - panelH / 2

    love.graphics.setColor(0.15, 0.18, 0.25)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)
    love.graphics.setColor(0.4, 0.5, 0.7)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 10, 10)

    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(UI.fonts.get(24))
    love.graphics.printf("HOW TO PLAY", panelX, panelY + 20, panelW, "center")

    local helpText = {
        {"CARDS & PACKS", "Open packs to collect creature cards. Each card has an element, power, and rarity."},
        {"FLUX CURRENCY", "Break unwanted cards to earn Flux. Use Flux for evolution and fusion."},
        {"EVOLUTION", "Evolve cards into stronger forms. Increases rarity and power. Costs Flux."},
        {"FUSION", "Combine two specific cards to create a new unique creature. Both cards are consumed."},
        {"LEVELING", "Use Flux to level up cards. Each level increases power by 10%."},
        {"BATTLES", "Build a team of 5 creatures. Challenge tavern NPCs in turn-based combat."},
        {"ELEMENTS", "8 elements with strengths/weaknesses. Strong = 1.5x damage, Weak = 0.5x damage."},
        {"", "Flame > Frost,Terra | Aqua > Flame,Terra | Volt > Aqua,Metal"},
        {"", "Shadow > Light,Volt | Light > Shadow,Frost | Frost > Aqua,Terra"},
        {"", "Terra > Volt,Metal | Metal > Light,Frost"},
    }

    local textY = panelY + 60
    love.graphics.setFont(UI.fonts.get(12))
    for _, entry in ipairs(helpText) do
        if entry[1] ~= "" then
            love.graphics.setColor(0.4, 0.8, 0.5)
            love.graphics.print(entry[1], panelX + 30, textY)
            textY = textY + 18
        end
        love.graphics.setColor(0.8, 0.8, 0.9)
        love.graphics.printf(entry[2], panelX + 30, textY, panelW - 60, "left")
        textY = textY + 30
    end

    -- Close button
    local mx, my = love.mouse.getPosition()
    local closeX = panelX + panelW - 40
    local closeY = panelY + 10
    local closeHover = mx >= closeX and mx <= closeX + 30 and my >= closeY and my <= closeY + 30

    love.graphics.setColor(closeHover and {0.6, 0.3, 0.3} or {0.4, 0.2, 0.2})
    love.graphics.rectangle("fill", closeX, closeY, 30, 30, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(18))
    love.graphics.printf("X", closeX, closeY + 5, 30, "center")
end

function TradingCards.mousepressed(x, y, button)
    if button ~= 1 then return end

    local screenW, screenH = love.graphics.getDimensions()
    local contentY = 110

    -- Check UI components first
    if state.ui.backButton and state.ui.backButton:mousepressed(x, y, button) then
        return
    end

    if state.ui.tabBar and state.ui.tabBar:mousepressed(x, y, button) then
        state.selectedCard = nil
        state.selectedForFuse = {nil, nil}
        return
    end

    if state.ui.helpButton and state.ui.helpButton:mousepressed(x, y, button) then
        return
    end

    -- Close help overlay
    if state.showHelp then
        local panelW, panelH = 600, 500
        local panelX = screenW / 2 - panelW / 2
        local panelY = screenH / 2 - panelH / 2
        local closeX = panelX + panelW - 40
        local closeY = panelY + 10
        if x >= closeX and x <= closeX + 30 and y >= closeY and y <= closeY + 30 then
            state.showHelp = false
        end
        return
    end

    -- Pack opening state
    if state.packOpening then
        -- Click to reveal faster
        if state.revealIndex < #state.openedCards then
            state.revealIndex = state.revealIndex + 1
            state.revealTimer = 0
            return
        else
            -- Add to collection button
            local contentH = screenH - contentY - 60
            local cardH = 170
            local btnW, btnH = 200, 45
            local btnX = screenW / 2 - btnW / 2
            local btnY = contentY + 60 + cardH + 30

            if x >= btnX and x <= btnX + btnW and y >= btnY and y <= btnY + btnH then
                for _, card in ipairs(state.openedCards) do
                    addToCollection(card)
                end
                state.packOpening = false
                state.openedCards = {}
                TradingCards.save()
                return
            end
        end
        return
    end

    -- Collection view
    if state.viewMode == "collection" then
        -- Card detail close/sell/break/level/team
        if state.selectedCard then
            local cardW, cardH = 280, 400
            local cardX = screenW / 2 - cardW / 2
            local cardY = screenH / 2 - cardH / 2 - 30
            local btnY = cardY + cardH + 15
            local btnW = 85
            local btnH = 35
            local gap = 8

            -- Find card index
            local cardIndex = nil
            for i, c in ipairs(state.collection) do
                if c.id == state.selectedCard.id then
                    cardIndex = i
                    break
                end
            end

            -- Sell button
            if x >= cardX and x <= cardX + btnW and y >= btnY and y <= btnY + btnH then
                if cardIndex then
                    sellCard(cardIndex)
                    state.selectedCard = nil
                end
                return
            end

            -- Break button
            local breakX = cardX + btnW + gap
            if x >= breakX and x <= breakX + btnW and y >= btnY and y <= btnY + btnH then
                if cardIndex then
                    breakCard(cardIndex)
                    state.selectedCard = nil
                    TradingCards.save()
                end
                return
            end

            -- Level Up button
            local levelX = breakX + btnW + gap
            if x >= levelX and x <= levelX + btnW and y >= btnY and y <= btnY + btnH then
                if cardIndex then
                    local cost = getLevelUpCost(state.selectedCard)
                    if state.flux >= cost then
                        levelUpCard(cardIndex)
                        -- Refresh selected card reference
                        state.selectedCard = state.collection[cardIndex]
                        TradingCards.save()
                    end
                end
                return
            end

            -- Second row buttons
            local btnY2 = btnY + btnH + 5
            local teamBtnW = (btnW * 2 + gap)

            -- Add/Remove from Team button
            if x >= cardX and x <= cardX + teamBtnW and y >= btnY2 and y <= btnY2 + btnH then
                local inTeamIdx = nil
                for i, tc in ipairs(state.battleTeam) do
                    if tc.id == state.selectedCard.id then
                        inTeamIdx = i
                        break
                    end
                end
                if inTeamIdx then
                    table.remove(state.battleTeam, inTeamIdx)
                elseif #state.battleTeam < 5 then
                    table.insert(state.battleTeam, state.selectedCard)
                end
                TradingCards.save()
                return
            end

            -- Close button
            local closeX = cardX + teamBtnW + gap
            if x >= closeX and x <= closeX + btnW and y >= btnY2 and y <= btnY2 + btnH then
                state.selectedCard = nil
                return
            end

            -- Click outside to close
            if x < cardX or x > cardX + cardW or y < cardY or y > btnY2 + btnH then
                state.selectedCard = nil
                return
            end
            return
        end

        -- Sort buttons
        local sortOptions = {"element", "rarity", "power", "name"}
        local sortX = 75
        for _, opt in ipairs(sortOptions) do
            local btnW = 60
            if x >= sortX and x <= sortX + btnW and y >= contentY + 5 and y <= contentY + 35 then
                state.sortBy = opt
                return
            end
            sortX = sortX + btnW + 5
        end

        -- Filter buttons
        local filterX = sortX + 65
        if x >= filterX and x <= filterX + 40 and y >= contentY + 5 and y <= contentY + 35 then
            state.filterElement = "all"
            return
        end

        filterX = filterX + 45
        for _, elem in ipairs(ELEMENTS) do
            if x >= filterX and x <= filterX + 30 and y >= contentY + 5 and y <= contentY + 35 then
                state.filterElement = elem.id
                return
            end
            filterX = filterX + 35
        end

        -- Card clicks
        local gridY = contentY + 50
        local gridH = screenH - contentY - 110
        local cardW, cardH = 140, 190
        local cols = math.floor((screenW - 60) / (cardW + 15))
        local startX = (screenW - cols * (cardW + 15) + 15) / 2

        if y >= gridY and y <= gridY + gridH then
            local sortedCards = getSortedCollection()
            for i, entry in ipairs(sortedCards) do
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)
                local cx = startX + col * (cardW + 15)
                local cy = gridY + row * (cardH + 15) - state.collectionScroll

                if x >= cx and x <= cx + cardW and y >= cy and y <= cy + cardH then
                    state.selectedCard = entry.card
                    return
                end
            end
        end
    end

    -- Packs view
    if state.viewMode == "packs" then
        -- Pack purchase
        local packW, packH = 180, 250
        local spacing = 30
        local totalW = #PACKS * packW + (#PACKS - 1) * spacing
        local startX = screenW / 2 - totalW / 2

        for i, pack in ipairs(PACKS) do
            local packX = startX + (i - 1) * (packW + spacing)
            local packY = contentY + 30

            if x >= packX and x <= packX + packW and y >= packY and y <= packY + packH then
                if PlayerData.coins >= pack.cost then
                    if pack.elementLocked and not state.selectedElement then
                        -- Need to select element first
                        return
                    end
                    openPack(pack.id)
                end
                return
            end
        end

        -- Element selection
        local elemW = 80
        local elemSpacing = 10
        local elemTotalW = #ELEMENTS * elemW + (#ELEMENTS - 1) * elemSpacing
        local elemStartX = screenW / 2 - elemTotalW / 2
        local elemY = contentY + packH + 120

        for i, elem in ipairs(ELEMENTS) do
            local elemX = elemStartX + (i - 1) * (elemW + elemSpacing)
            if x >= elemX and x <= elemX + elemW and y >= elemY and y <= elemY + 50 then
                state.selectedElement = elem.id
                return
            end
        end
    end

    -- Battle selection view
    if state.viewMode == "battle" and not state.battleState then
        -- Manage team button
        local slotW = 80
        local manageBtnX = 30 + 5 * (slotW + 10) + 20
        local manageBtnY = contentY + 100
        if x >= manageBtnX and x <= manageBtnX + 100 and y >= manageBtnY and y <= manageBtnY + 35 then
            -- Toggle team management mode - show collection to add/remove
            state.viewMode = "collection"
            return
        end

        -- Refresh challengers button
        local refreshBtnX = 220
        local refreshBtnY = contentY + 192
        local refreshBtnW = 100
        local refreshBtnH = 28
        if x >= refreshBtnX and x <= refreshBtnX + refreshBtnW and y >= refreshBtnY and y <= refreshBtnY + refreshBtnH then
            -- Regenerate all opponents with new random male/female challengers
            state.opponents = {}
            for i = 1, 5 do
                table.insert(state.opponents, generateOpponent(i))
            end
            return
        end

        -- Challenge opponents
        local oppY = contentY + 225
        for i, opp in ipairs(state.opponents) do
            local oppH = 80
            local btnX = screenW - 130
            if x >= btnX and x <= btnX + 90 and y >= oppY + 25 and y <= oppY + 55 then
                if #state.battleTeam == 5 then
                    -- Start battle
                    local playerTeamCopy = {}
                    for _, card in ipairs(state.battleTeam) do
                        local copy = {}
                        for k, v in pairs(card) do copy[k] = v end
                        copy.hp = 100 + (card.level or 1) * 20
                        copy.maxHp = copy.hp
                        table.insert(playerTeamCopy, copy)
                    end
                    state.battleState = {
                        opponent = opp,
                        playerTeam = playerTeamCopy,
                        playerActive = 1,
                        oppActive = 1,
                        phase = "player_turn",
                        log = {"Battle started against " .. opp.name .. "!"},
                    }
                end
                return
            end
            oppY = oppY + oppH + 10
        end
    end

    -- Active battle
    if state.battleState then
        local battle = state.battleState

        -- Victory/defeat continue button
        if battle.phase == "victory" or battle.phase == "defeat" then
            local btnW, btnH = 150, 45
            local btnX = screenW / 2 - btnW / 2
            local btnY = screenH / 2 + 30
            if x >= btnX and x <= btnX + btnW and y >= btnY and y <= btnY + btnH then
                if battle.phase == "victory" then
                    state.flux = state.flux + battle.opponent.reward.flux
                    PlayerData.coins = PlayerData.coins + battle.opponent.reward.coins
                    -- Regenerate this opponent
                    for i, opp in ipairs(state.opponents) do
                        if opp == battle.opponent then
                            state.opponents[i] = generateOpponent(opp.difficulty)
                            break
                        end
                    end
                end
                state.battleState = nil
                TradingCards.save()
                return
            end
        end

        -- Player move buttons
        if battle.phase == "player_turn" then
            local playerCard = battle.playerTeam[battle.playerActive]
            if playerCard then
                local moves = ELEMENT_MOVES[playerCard.element]
                if moves then
                    for i, move in ipairs(moves) do
                        local btnX = screenW / 2 - 150 + (i - 1) * 160
                        local btnY = contentY + 340
                        if x >= btnX and x <= btnX + 140 and y >= btnY and y <= btnY + 50 then
                            -- Execute player move
                            local oppCard = battle.opponent.team[battle.oppActive]
                            local damage, mult = calculateDamage(playerCard, oppCard, move)
                            oppCard.hp = oppCard.hp - damage

                            local effectText = mult > 1 and " (Super effective!)" or mult < 1 and " (Not very effective...)" or ""
                            table.insert(battle.log, playerCard.creature .. " used " .. move.name .. "! " .. damage .. " damage!" .. effectText)

                            -- Check if opponent creature fainted
                            if oppCard.hp <= 0 then
                                table.insert(battle.log, oppCard.creature .. " fainted!")
                                -- Find next opponent creature
                                local foundNext = false
                                for j = battle.oppActive + 1, 5 do
                                    if battle.opponent.team[j] and battle.opponent.team[j].hp > 0 then
                                        battle.oppActive = j
                                        foundNext = true
                                        break
                                    end
                                end
                                if not foundNext then
                                    battle.phase = "victory"
                                    return
                                end
                            else
                                battle.phase = "opponent_turn"
                            end
                            return
                        end
                    end
                end
            end
        end
        return
    end

    -- Evolution view
    if state.viewMode == "evolve" then
        local gridY = contentY + 80
        local cardW, cardH = 120, 160
        local cols = math.floor((screenW - 60) / (cardW + 10))
        local startX = (screenW - cols * (cardW + 10) + 10) / 2

        local evolvableCards = {}
        for i, card in ipairs(state.collection) do
            if EVOLUTION_CHAINS[card.creature] then
                table.insert(evolvableCards, {index = i, card = card})
            end
        end

        for i, entry in ipairs(evolvableCards) do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            local cardX = startX + col * (cardW + 10)
            local cardY = gridY + row * (cardH + 50)
            local btnY = cardY + cardH + 5

            -- Click evolve button
            if x >= cardX and x <= cardX + cardW and y >= btnY and y <= btnY + 30 then
                local canDo, _ = canEvolve(entry.card)
                if canDo then
                    evolveCard(entry.index)
                    TradingCards.save()
                end
                return
            end
        end
    end

    -- Fusion view
    if state.viewMode == "fuse" then
        -- Fuse button
        local card1 = state.selectedForFuse[1]
        local card2 = state.selectedForFuse[2]
        if card1 and card2 then
            local canDo, result = canFuse(card1, card2)
            if canDo then
                local slotH = 180
                local slotY = contentY + 80
                local fuseY = slotY + slotH + 20
                local btnW, btnH = 150, 40
                local btnX = screenW / 2 - btnW / 2
                local btnY = fuseY + 30
                if x >= btnX and x <= btnX + btnW and y >= btnY and y <= btnY + btnH then
                    -- Find indices
                    local idx1, idx2
                    for i, c in ipairs(state.collection) do
                        if c.id == card1.id then idx1 = i end
                        if c.id == card2.id then idx2 = i end
                    end
                    if idx1 and idx2 then
                        fuseCards(idx1, idx2)
                        state.selectedForFuse = {nil, nil}
                        TradingCards.save()
                    end
                    return
                end
            end
        end

        -- Card selection for fusion
        local gridY = screenH - 175
        local cardW, cardH = 80, 100
        local startX = 30

        for i, card in ipairs(state.collection) do
            if i <= 10 then
                local cardX = startX + (i - 1) * (cardW + 5)
                if x >= cardX and x <= cardX + cardW and y >= gridY and y <= gridY + cardH then
                    -- Toggle selection
                    if state.selectedForFuse[1] and state.selectedForFuse[1].id == card.id then
                        state.selectedForFuse[1] = nil
                    elseif state.selectedForFuse[2] and state.selectedForFuse[2].id == card.id then
                        state.selectedForFuse[2] = nil
                    elseif not state.selectedForFuse[1] then
                        state.selectedForFuse[1] = card
                    elseif not state.selectedForFuse[2] then
                        state.selectedForFuse[2] = card
                    end
                    return
                end
            end
        end
    end
end

function TradingCards.mousereleased(x, y, button)
    if button ~= 1 then return end

    -- Delegate to UI components
    if state.ui.backButton and state.ui.backButton.mousereleased then
        state.ui.backButton:mousereleased(x, y, button)
    end
    if state.ui.tabBar and state.ui.tabBar.mousereleased then
        state.ui.tabBar:mousereleased(x, y, button)
    end
    if state.ui.helpButton and state.ui.helpButton.mousereleased then
        state.ui.helpButton:mousereleased(x, y, button)
    end
end

function TradingCards.wheelmoved(x, y)
    if state.viewMode == "collection" and not state.selectedCard then
        state.collectionScroll = state.collectionScroll - y * 40

        local screenW, screenH = love.graphics.getDimensions()
        local contentY = 110
        local gridH = screenH - contentY - 110
        local cardH = 190
        local cols = math.floor((screenW - 60) / 155)
        local sortedCards = getSortedCollection()
        local maxScroll = math.max(0, math.ceil(#sortedCards / cols) * (cardH + 15) - gridH)
        state.collectionScroll = math.max(0, math.min(state.collectionScroll, maxScroll))
    end
end

function TradingCards.keypressed(key)
    if key == "escape" then
        if state.showHelp then
            state.showHelp = false
        elseif state.selectedCard then
            state.selectedCard = nil
        elseif state.packOpening then
            -- Can't escape during pack opening
        elseif state.battleState then
            -- Can't escape during battle (must finish or forfeit)
            if state.battleState.phase == "victory" or state.battleState.phase == "defeat" then
                state.battleState = nil
            end
        elseif state.selectedForFuse[1] or state.selectedForFuse[2] then
            state.selectedForFuse = {nil, nil}
        else
            TradingCards.save()
            local TextRPG = require("textrpg"); TextRPG.init(); GameState.current = "textrpg"
        end
    end
end

return TradingCards
