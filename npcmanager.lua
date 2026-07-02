-- NPC Manager - Handles 200-500 NPCs per town with tiered loading
-- Uses lazy generation and caching for memory efficiency

local NPCManager = {}

-- ============================================================================
--                              CONSTANTS
-- ============================================================================

local MAX_NPCS_PER_TOWN = 500
local DEFAULT_NPCS_PER_TOWN = 200
local MAX_CACHED_TOWNS = 10  -- Maximum number of towns to keep in memory

-- NPC categories with population distribution
local NPC_CATEGORIES = {
    {id = "merchant", name = "Merchants", percent = 0.10, priority = "core"},
    {id = "guard", name = "Guards", percent = 0.08, priority = "core"},
    {id = "innkeeper", name = "Innkeepers", percent = 0.02, priority = "core"},
    {id = "blacksmith", name = "Blacksmiths", percent = 0.02, priority = "core"},
    {id = "questgiver", name = "Quest Givers", percent = 0.08, priority = "core"},
    {id = "healer", name = "Healers", percent = 0.03, priority = "core"},
    {id = "craftsman", name = "Craftsmen", percent = 0.12, priority = "active"},
    {id = "farmer", name = "Farmers", percent = 0.15, priority = "background"},
    {id = "commoner", name = "Commoners", percent = 0.25, priority = "background"},
    {id = "noble", name = "Nobles", percent = 0.05, priority = "active"},
    {id = "traveler", name = "Travelers", percent = 0.05, priority = "background"},
    {id = "scholar", name = "Scholars", percent = 0.03, priority = "active"},
    {id = "entertainer", name = "Entertainers", percent = 0.02, priority = "active"},
}

-- ============================================================================
--                         RACIAL DATA
-- ============================================================================

-- Race definitions with name pools and traits
local RACES = {
    human = {
        id = "human",
        name = "Human",
        firstNames = {
            male = {"Aldric", "Bram", "Cedric", "Dorn", "Edmund", "Finn", "Gareth", "Harold",
                   "Ivan", "Jasper", "Kelvin", "Leoric", "Marcus", "Nolan", "Oscar", "Percy",
                   "Roland", "Stefan", "Thomas", "Victor", "William", "Albert", "Conrad", "Felix"},
            female = {"Ada", "Beatrice", "Clara", "Diana", "Elena", "Fiona", "Greta", "Helena",
                     "Julia", "Kira", "Luna", "Mira", "Nadia", "Ophelia", "Sara", "Talia",
                     "Vera", "Agatha", "Celeste", "Eliza", "Katherine", "Margaret", "Natalia", "Rosa"},
        },
        lastNames = {"Smith", "Baker", "Fletcher", "Cooper", "Miller", "Wright", "Mason", "Taylor",
                    "Blackwood", "Goldstein", "Silverhand", "Whitmore", "Greenfield", "Redwood",
                    "Highwater", "Winterborn", "Eastwood", "Westbrook", "Northwind", "Southgate"},
        traits = {"religious", "lawful", "institutional"},
    },

    elf = {
        id = "elf",
        name = "Elf",
        firstNames = {
            male = {"Aelindor", "Caelum", "Elowen", "Faenor", "Galadrim", "Ilthuriel", "Lorien",
                   "Mithrandir", "Sylvaris", "Thalion", "Vanyar", "Celeborn", "Finrod", "Gildor"},
            female = {"Aelindra", "Arwen", "Celebrian", "Elara", "Galadriel", "Isilme", "Luthien",
                     "Miriel", "Nimrodel", "Silmarien", "Tinuviel", "Vanesse", "Yavanna", "Idril"},
        },
        lastNames = {"Starweaver", "Moonwhisper", "Silverleaf", "Dawnbringer", "Nighthollow",
                    "Archiviste", "Quillmark", "Scrollkeeper", "Tomebound", "Inkwell"},
        traits = {"bureaucratic", "secretive", "long-lived"},
    },

    dwarf = {
        id = "dwarf",
        name = "Dwarf",
        firstNames = {
            -- Dwarves are asexual, no gender distinction
            neutral = {"Thorin", "Bram", "Durin", "Gimli", "Balin", "Dwalin", "Fili", "Kili",
                      "Dain", "Thrain", "Nori", "Dori", "Ori", "Bifur", "Bofur", "Bombur",
                      "Gloin", "Oin", "Fundin", "Groin", "Farin", "Borin", "Dara", "Rurik"},
        },
        lastNames = {"Ironforge", "Stoneheart", "Deepdelve", "Anvilborn", "Hammerfall",
                    "Copperbeard", "Goldvein", "Silvershard", "Coalfist", "Granitehide",
                    "Obsidiancore", "Quartzblood", "Marbleskull", "Basaltbone"},
        traits = {"stoic", "isolationist", "stone-revering"},
        asexual = true,
    },

    orc = {
        id = "orc",
        name = "Orc",
        firstNames = {
            male = {"Grommash", "Thrall", "Durotan", "Orgrim", "Blackhand", "Kilrogg", "Gul'dan",
                   "Kargath", "Ner'zhul", "Garrosh", "Saurfang", "Broxigar", "Nazgrel", "Rehgar"},
            female = {"Draka", "Garona", "Aggra", "Zaela", "Griselda", "Thura", "Jorin",
                     "Shagara", "Greatmother", "Rulkan", "Malka", "Grolla", "Drekka", "Ursa"},
        },
        lastNames = {"Hellscream", "Bloodfist", "Doomhammer", "Skullcrusher", "Bonechewer",
                    "Warsong", "Frostwolf", "Blackrock", "Shadowmoon", "Burning Blade"},
        traits = {"clan-loyal", "traditional", "nomadic"},
    },

    gnome = {
        id = "gnome",
        name = "Gnome",
        firstNames = {
            male = {"Fizz", "Cogsworth", "Gearloose", "Sprocket", "Widget", "Piston", "Ratchet",
                   "Tinker", "Wrench", "Crank", "Bolt", "Spark", "Flux", "Gyro", "Toggle"},
            female = {"Tink", "Whirla", "Gizmo", "Rivette", "Sprocket", "Cogsie", "Gearla",
                     "Clicka", "Windup", "Springy", "Buzzy", "Zippy", "Wirette", "Valva"},
        },
        lastNames = {"Gearspinner", "Steamwhistle", "Coppercoil", "Brassknob", "Springloader",
                    "Clockwork", "Ironpipe", "Cogturner", "Pressurevalve", "Turbineheart"},
        traits = {"inventive", "secretive", "industrialist"},
    },

    beast_folk = {
        id = "beast_folk",
        name = "Beast Folk",
        subtypes = {
            cat_folk = {
                name = "Cat Folk",
                firstNames = {
                    male = {"Whiskers", "Shadowpaw", "Razorclaw", "Swiftfoot", "Nighteyes",
                           "Silentpad", "Quicktail", "Goldenmane", "Moonwatcher", "Sunbask"},
                    female = {"Velvet", "Silkfur", "Brightwhisker", "Gracepaw", "Stargazer",
                             "Moonpelt", "Dawnfur", "Softpad", "Crystaleye", "Shimmercoat"},
                },
                traits = {"drawn to gambling", "probability-minded", "chance-loving"},
            },
            lizard_folk = {
                name = "Lizard Folk",
                firstNames = {
                    neutral = {"Sseth", "Krax", "Zithik", "Scales", "Fangbite", "Coldblood",
                              "Sunbasker", "Sandscale", "Dunewalker", "Heatseeker", "Stonegazer"},
                },
                traits = {"stoic", "nomadic", "guards", "scouts"},
            },
        },
        lastNames = {"Sanddancer", "Dustwalker", "Desertshadow", "Mirageseeker", "Oasisfinder",
                    "Suntracker", "Dunerunner", "Heatweaver", "Scorchfoot", "Shimmerscale"},
        traits = {"desert-born", "diaspora", "rare"},
    },

    -- HOLLOW EARTH RACES
    myconid = {
        id = "myconid",
        name = "Myconid",
        firstNames = {
            neutral = {"Sporecap", "Mycelus", "Funghul", "Capstone", "Stemwise", "Gillian",
                      "Porekeeper", "Rootmind", "Sporewhisper", "Mushara", "Capweaver",
                      "Threadling", "Mycora", "Sporeth", "Gillkeeper", "Stemhold"},
        },
        lastNames = {"of the Deep Grove", "of the Fungal Forests", "the Telepathic", "the Sporebearer",
                    "the Rootbound", "the Mycelial", "the Network", "the Collective", "the Fruiting Body"},
        traits = {"telepathic", "collective-minded", "fungal", "bioluminescent"},
        asexual = true,  -- Myconids reproduce via spores
    },

    saurian = {
        id = "saurian",
        name = "Saurian",
        firstNames = {
            male = {"Rexar", "Veloc", "Carnoth", "Theris", "Raptor", "Saurax", "Deinon",
                   "Tricero", "Pteros", "Ankyl", "Stegos", "Brachio", "Allos", "Pachy"},
            female = {"Rexa", "Velora", "Carnith", "Thera", "Raptora", "Saura", "Deina",
                     "Tricera", "Ptera", "Ankyla", "Stega", "Brachia", "Allosa", "Pachya"},
        },
        lastNames = {"Scaleheart", "Clawkeeper", "Jungleborn", "Ancientblood", "Primordial",
                    "Hollowscion", "Deepwalker", "Fossilkin", "Thunderstride", "Quickclaw"},
        traits = {"intelligent", "ancient", "jungle-dweller", "dinosaur-kin"},
    },

    deep_dwarf = {
        id = "deep_dwarf",
        name = "Deep Dwarf",
        firstNames = {
            neutral = {"Deepforge", "Voidhammer", "Darkstone", "Obsidiax", "Depthborn", "Ironmaw",
                      "Nethril", "Voidbeard", "Abyssal", "Corekeeper", "Magmaheart", "Steeldeep",
                      "Darkholm", "Voidmark", "Netherheart", "Depthguard"},
        },
        lastNames = {"Deepdelver", "Netherbane", "Voidforged", "Coreheart", "Abysswalker",
                    "Darkstone", "Ironvoid", "Depthkeeper", "Obsidianborn", "Magmakin"},
        traits = {"isolationist", "hostile", "master-smiths", "void-touched"},
        asexual = true,  -- Like surface dwarves
    },

    fish_folk = {
        id = "fish_folk",
        name = "Fish-folk",
        firstNames = {
            neutral = {"Finnegan", "Scaletide", "Gillwater", "Deepswim", "Blindeye", "Echosonar",
                      "Wavefeeler", "Currentsense", "Darkwater", "Abysskin", "Depthfinder",
                      "Sonarwhisper", "Tideless", "Voidfish", "Pressureborn", "Coldblood"},
        },
        lastNames = {"of the Sunless Seas", "the Blind", "the Echolocator", "the Deep Swimmer",
                    "the Abyssal", "the Pressureborn", "the Tideless", "the Darkwater"},
        traits = {"blind", "echolocation", "aquatic", "pressure-adapted"},
        asexual = false,
    },
}

-- Regional demographics (race distribution by region)
local REGIONAL_DEMOGRAPHICS = {
    holy_dominion = {
        human = 0.70, elf = 0.15, beast_folk = 0.05, dwarf = 0.05, orc = 0.03, gnome = 0.02,
    },
    holy_dominion_gambling = {  -- For gambling cities (more beast folk)
        human = 0.55, elf = 0.12, beast_folk = 0.20, dwarf = 0.05, orc = 0.05, gnome = 0.03,
    },
    southern_reaches = {  -- Elven lands
        elf = 0.65, human = 0.25, beast_folk = 0.05, dwarf = 0.03, gnome = 0.02, orc = 0.00,
    },
    dwarven_mountains = {
        dwarf = 0.85, human = 0.08, gnome = 0.04, elf = 0.02, orc = 0.01, beast_folk = 0.00,
    },
    orcish_steppes = {
        orc = 0.75, human = 0.10, beast_folk = 0.08, elf = 0.04, dwarf = 0.02, gnome = 0.01,
    },
    gnomish_isles = {
        gnome = 0.92, human = 0.04, elf = 0.02, dwarf = 0.02, orc = 0.00, beast_folk = 0.00,
    },
    shadowfen = {
        human = 0.40, elf = 0.20, beast_folk = 0.15, orc = 0.15, dwarf = 0.05, gnome = 0.05,
    },
    frontier = {
        human = 0.45, orc = 0.20, beast_folk = 0.15, elf = 0.10, dwarf = 0.08, gnome = 0.02,
    },
    desert = {
        beast_folk = 0.60, human = 0.25, orc = 0.10, elf = 0.03, dwarf = 0.02, gnome = 0.00,
    },
    eastern_forests = {
        elf = 0.40, human = 0.30, beast_folk = 0.15, orc = 0.05, dwarf = 0.05, gnome = 0.05,
    },

    -- HOLLOW EARTH DEMOGRAPHICS
    hollow_fungal_forests = {
        myconid = 0.75, deep_dwarf = 0.10, fish_folk = 0.05, saurian = 0.05, human = 0.03, elf = 0.02,
    },
    hollow_jungle = {
        saurian = 0.80, myconid = 0.10, deep_dwarf = 0.05, fish_folk = 0.03, human = 0.02,
    },
    hollow_subterranean_seas = {
        fish_folk = 0.70, saurian = 0.15, myconid = 0.10, deep_dwarf = 0.03, human = 0.02,
    },
    hollow_crystal_caverns = {
        deep_dwarf = 0.50, myconid = 0.20, fish_folk = 0.15, saurian = 0.10, human = 0.05,
    },
    hollow_bone_wastes = {
        deep_dwarf = 0.40, myconid = 0.25, fish_folk = 0.15, saurian = 0.15, human = 0.05,
    },
    hollow_storm_caverns = {
        fish_folk = 0.35, deep_dwarf = 0.30, myconid = 0.20, saurian = 0.10, human = 0.05,
    },
    hollow_deep_dwarven_realm = {
        deep_dwarf = 0.85, myconid = 0.08, fish_folk = 0.04, saurian = 0.02, human = 0.01,
    },
}

-- NPC name pools (legacy - for backwards compatibility)
local FIRST_NAMES = RACES.human.firstNames

local LAST_NAMES = RACES.human.lastNames

-- NPC personality traits
local TRAITS = {
    "friendly", "grumpy", "cheerful", "suspicious", "helpful", "lazy",
    "hardworking", "curious", "secretive", "generous", "greedy", "wise",
    "foolish", "brave", "cowardly", "honest", "deceitful", "proud", "humble",
}

-- Dialogue templates by category
local DIALOGUE_TEMPLATES = {
    merchant = {
        greeting = {"Welcome! See anything you like?", "Finest goods in town!", "What can I get for you?"},
        farewell = {"Come back soon!", "Safe travels!", "Tell your friends!"},
        rumors = {"I heard there's trouble in the %s...", "Traders say the roads are dangerous lately.", "Business has been slow since the %s arrived."},
    },
    guard = {
        greeting = {"Stay out of trouble.", "Keep your weapons sheathed in town.", "What's your business here?"},
        farewell = {"Move along.", "Stay safe out there.", "Watch yourself."},
        rumors = {"We've had reports of bandits on the %s road.", "The captain is worried about the %s.", "Keep an eye out for suspicious characters."},
    },
    commoner = {
        greeting = {"Hello there!", "Nice day, isn't it?", "You're not from around here, are you?"},
        farewell = {"Take care!", "Goodbye!", "See you around!"},
        rumors = {"Did you hear about %s?", "My cousin saw something strange near the %s.", "They say the old %s is haunted."},
    },
    questgiver = {
        greeting = {"Ah, an adventurer! Just who I needed.", "You look capable. I have a job for you.", "Perfect timing! I need help."},
        farewell = {"Don't let me down.", "I'm counting on you.", "Return when it's done."},
        rumors = {"There's something valuable in the %s.", "The %s have been causing problems.", "I'll make it worth your while."},
    },
}

-- ============================================================================
--                           NPC STATE
-- ============================================================================

local npcState = {
    activeTownId = nil,         -- Currently loaded town
    loadedNPCs = {},            -- NPCs in current town
    npcCache = {},              -- LRU cache of recently unloaded NPCs
    generatedTowns = {},        -- Towns that have had NPCs generated
    townAccessOrder = {},       -- Track order of town access for LRU cleanup
}

-- Seeded random utilities (shared via seedrandom.lua)
local SeedRNG = require("seedrandom")
local function seededRandom(seed) return SeedRNG.hash(seed) end
local function seededRandomInt(seed, min, max) return SeedRNG.hashInt(seed, min, max) end
local function seededChoice(seed, list) return SeedRNG.hashChoice(seed, list) end

-- ============================================================================
--                      NPC GENERATION
-- ============================================================================

-- Generate a unique NPC ID
local function generateNPCId(townId, index)
    return townId .. "_npc_" .. index
end

-- Generate NPC stats based on category and level
local function generateStats(category, level, seed)
    local base = {
        str = 10, dex = 10, con = 10, int = 10, wis = 10, cha = 10
    }

    -- Modify based on category
    if category == "guard" then
        base.str = base.str + seededRandomInt(seed, 2, 5)
        base.con = base.con + seededRandomInt(seed + 1, 1, 4)
    elseif category == "merchant" then
        base.cha = base.cha + seededRandomInt(seed, 3, 6)
        base.int = base.int + seededRandomInt(seed + 1, 1, 3)
    elseif category == "scholar" then
        base.int = base.int + seededRandomInt(seed, 4, 8)
        base.wis = base.wis + seededRandomInt(seed + 1, 2, 5)
    elseif category == "craftsman" or category == "blacksmith" then
        base.str = base.str + seededRandomInt(seed, 1, 3)
        base.dex = base.dex + seededRandomInt(seed + 1, 2, 4)
    elseif category == "healer" then
        base.wis = base.wis + seededRandomInt(seed, 3, 6)
        base.int = base.int + seededRandomInt(seed + 1, 1, 3)
    end

    -- Scale with town level
    for stat, value in pairs(base) do
        base[stat] = value + math.floor(level * 0.5)
    end

    return base
end

-- Generate NPC schedule
local function generateSchedule(category, seed)
    local schedule = {}
    local locations = {"home", "workplace", "tavern", "market", "temple", "town_square"}

    -- Morning (6-12)
    schedule.morning = seededChoice(seed, {"workplace", "market", "town_square"})

    -- Afternoon (12-18)
    schedule.afternoon = seededChoice(seed + 1, {"workplace", "home", "market"})

    -- Evening (18-24)
    schedule.evening = seededChoice(seed + 2, {"tavern", "home", "town_square"})

    -- Night (0-6)
    schedule.night = "home"

    -- Category-specific overrides
    if category == "guard" then
        schedule.morning = "patrol"
        schedule.afternoon = "patrol"
        schedule.evening = "guardpost"
    elseif category == "innkeeper" then
        schedule.morning = "tavern"
        schedule.afternoon = "tavern"
        schedule.evening = "tavern"
    elseif category == "merchant" then
        schedule.morning = "shop"
        schedule.afternoon = "shop"
    end

    return schedule
end

-- Select a race based on regional demographics
local function selectRace(regionType, seed)
    local demographics = REGIONAL_DEMOGRAPHICS[regionType] or REGIONAL_DEMOGRAPHICS.frontier
    local roll = seededRandom(seed)
    local cumulative = 0

    -- Sort race keys to ensure deterministic iteration order
    local sortedRaces = {}
    for race, _ in pairs(demographics) do
        table.insert(sortedRaces, race)
    end
    table.sort(sortedRaces)

    -- Iterate in sorted order for deterministic selection
    for _, race in ipairs(sortedRaces) do
        cumulative = cumulative + demographics[race]
        if roll < cumulative then
            return race
        end
    end

    return "human"  -- Default fallback
end

-- Get name for a specific race
local function getRacialName(race, gender, seed)
    local raceData = RACES[race]
    if not raceData then
        raceData = RACES.human
    end

    local firstName, lastName

    -- Handle beast folk subtypes
    if race == "beast_folk" then
        -- Randomly choose subtype (60% cat folk, 40% lizard folk)
        local subtype = seededRandom(seed) < 0.6 and "cat_folk" or "lizard_folk"
        local subtypeData = raceData.subtypes[subtype]

        if subtypeData.firstNames.neutral then
            firstName = seededChoice(seed + 1, subtypeData.firstNames.neutral)
        else
            firstName = seededChoice(seed + 1, subtypeData.firstNames[gender] or subtypeData.firstNames.male)
        end
        lastName = seededChoice(seed + 2, raceData.lastNames)
        return firstName, lastName, subtype
    end

    -- Handle dwarves (asexual)
    if raceData.asexual then
        firstName = seededChoice(seed + 1, raceData.firstNames.neutral)
    else
        firstName = seededChoice(seed + 1, raceData.firstNames[gender] or raceData.firstNames.male)
    end

    lastName = seededChoice(seed + 2, raceData.lastNames)
    return firstName, lastName, nil
end

-- Generate a single NPC
local function generateNPC(townId, townLevel, index, category, seed, regionType)
    local npcSeed = seed + index * 7919  -- Prime number for better distribution

    -- Select race based on region
    local race = selectRace(regionType or "frontier", npcSeed)
    local raceData = RACES[race] or RACES.human

    -- Determine gender (dwarves are asexual)
    local gender
    if raceData.asexual then
        gender = "neutral"
    else
        gender = seededRandom(npcSeed + 0.5) > 0.5 and "male" or "female"
    end

    -- Get racial names
    local firstName, lastName, subtype = getRacialName(race, gender, npcSeed + 1)

    local npc = {
        id = generateNPCId(townId, index),
        townId = townId,
        index = index,

        -- Identity
        name = firstName .. " " .. lastName,
        firstName = firstName,
        lastName = lastName,
        gender = gender,
        race = race,
        subtype = subtype,  -- For beast folk (cat_folk, lizard_folk)
        category = category,
        title = nil,  -- Can be set for special NPCs

        -- Stats
        level = math.max(1, townLevel + seededRandomInt(npcSeed + 3, -2, 2)),
        stats = generateStats(category, townLevel, npcSeed + 4),

        -- Personality
        trait = seededChoice(npcSeed + 5, TRAITS),

        -- Racial traits
        racialTraits = raceData.traits or {},

        -- Schedule
        schedule = generateSchedule(category, npcSeed + 6),

        -- Relationships
        relationships = {
            player = 0,  -- -100 to 100 (neutral start)
        },

        -- Quest data (for quest givers)
        quests = {},
        completedQuests = {},

        -- Merchant data (for merchants)
        inventory = nil,  -- Generated on interaction

        -- State
        currentLocation = "home",
        isAlive = true,
        metPlayer = false,
        conversationCount = 0,
    }

    -- Generate title based on category and race
    if category == "merchant" then
        npc.title = "Merchant"
    elseif category == "guard" then
        npc.title = "Guard"
        -- Gnome guards might be automaton operators
        if race == "gnome" then
            npc.title = seededRandom(npcSeed + 7) > 0.7 and "Automaton Operator" or "Guard"
        end
    elseif category == "blacksmith" then
        npc.title = "Blacksmith"
        if race == "dwarf" then
            npc.title = "Master Smith"
        elseif race == "gnome" then
            npc.title = "Artificer"
        end
    elseif category == "innkeeper" then
        npc.title = "Innkeeper"
    elseif category == "healer" then
        npc.title = "Healer"
        if race == "elf" then
            npc.title = "Herbalist"
        elseif race == "human" then
            npc.title = seededRandom(npcSeed + 7) > 0.5 and "Priest of Helios" or "Healer"
        end
    elseif category == "noble" then
        if race == "human" then
            local titles = gender == "male" and {"Lord", "Baron", "Count"} or {"Lady", "Baroness", "Countess"}
            npc.title = seededChoice(npcSeed + 7, titles)
        elseif race == "elf" then
            npc.title = "Magistrate"
        elseif race == "orc" then
            npc.title = "Chieftain"
        elseif race == "dwarf" then
            npc.title = "Stonelord"
        elseif race == "gnome" then
            npc.title = "Guildmaster"
        end
    elseif category == "scholar" then
        npc.title = "Scholar"
        if race == "elf" then
            npc.title = seededRandom(npcSeed + 7) > 0.5 and "Archivist" or "Lorekeeper"
        elseif race == "gnome" then
            npc.title = "Engineer"
        end
    end

    return npc
end

-- Generate all NPCs for a town
local function generateTownNPCs(townId, townLevel, population, townSeed, regionType)
    local npcs = {}
    local npcIndex = 1

    -- Calculate NPC counts per category
    for _, cat in ipairs(NPC_CATEGORIES) do
        local count = math.floor(population * cat.percent + 0.5)

        for i = 1, count do
            local npc = generateNPC(townId, townLevel, npcIndex, cat.id, townSeed, regionType)
            npc.priority = cat.priority
            npcs[npc.id] = npc
            npcIndex = npcIndex + 1
        end
    end

    return npcs
end

-- ============================================================================
--                      TOWN NPC LOADING
-- ============================================================================

-- Clean up old towns when cache is full (LRU eviction)
local function cleanupOldTowns()
    local townCount = 0
    for _ in pairs(npcState.generatedTowns) do
        townCount = townCount + 1
    end

    -- Only cleanup if we exceed the limit
    if townCount <= MAX_CACHED_TOWNS then
        return
    end

    -- Remove oldest towns (those not in recent access order)
    local townsToRemove = townCount - MAX_CACHED_TOWNS
    local removedCount = 0

    -- Remove towns that are not in the access order list (oldest/least recently used)
    for townId, _ in pairs(npcState.generatedTowns) do
        if removedCount >= townsToRemove then
            break
        end

        -- Don't remove the currently active town
        if townId ~= npcState.activeTownId then
            -- Check if town is in recent access order
            local inRecentAccess = false
            for i = math.max(1, #npcState.townAccessOrder - MAX_CACHED_TOWNS + 1), #npcState.townAccessOrder do
                if npcState.townAccessOrder[i] == townId then
                    inRecentAccess = true
                    break
                end
            end

            -- Remove if not recently accessed
            if not inRecentAccess then
                npcState.generatedTowns[townId] = nil
                removedCount = removedCount + 1
            end
        end
    end
end

-- Load NPCs for a town
function NPCManager.loadTownNPCs(townId, townLevel, population, townSeed, regionType)
    -- Unload previous town's NPCs
    if npcState.activeTownId and npcState.activeTownId ~= townId then
        NPCManager.unloadTownNPCs(npcState.activeTownId)
    end

    population = population or DEFAULT_NPCS_PER_TOWN
    population = math.min(population, MAX_NPCS_PER_TOWN)
    regionType = regionType or "frontier"

    -- Check if we already generated NPCs for this town
    if npcState.generatedTowns[townId] then
        -- Load from saved state
        npcState.loadedNPCs = npcState.generatedTowns[townId]
    else
        -- Clean up old towns before generating new ones
        cleanupOldTowns()

        -- Generate new NPCs with regional demographics
        local npcs = generateTownNPCs(townId, townLevel, population, townSeed, regionType)
        npcState.loadedNPCs = npcs
        npcState.generatedTowns[townId] = npcs
    end

    -- Track access order for LRU cleanup
    table.insert(npcState.townAccessOrder, townId)
    -- Trim access order to prevent unbounded growth
    if #npcState.townAccessOrder > 100 then
        local trimmed = {}
        for i = #npcState.townAccessOrder - 49, #npcState.townAccessOrder do
            trimmed[#trimmed + 1] = npcState.townAccessOrder[i]
        end
        npcState.townAccessOrder = trimmed
    end

    npcState.activeTownId = townId
    return npcState.loadedNPCs
end

-- Unload NPCs for a town (save state)
function NPCManager.unloadTownNPCs(townId)
    if npcState.activeTownId == townId then
        -- Save NPC states
        npcState.generatedTowns[townId] = npcState.loadedNPCs
        npcState.loadedNPCs = {}
        npcState.activeTownId = nil
    end
end

-- ============================================================================
--                      NPC ACCESS
-- ============================================================================

-- Get all loaded NPCs
function NPCManager.getAllNPCs()
    return npcState.loadedNPCs
end

-- Get NPCs by category
function NPCManager.getNPCsByCategory(category)
    local result = {}
    for id, npc in pairs(npcState.loadedNPCs) do
        if npc.category == category then
            table.insert(result, npc)
        end
    end
    return result
end

-- Get NPCs by priority tier
function NPCManager.getNPCsByPriority(priority)
    local result = {}
    for id, npc in pairs(npcState.loadedNPCs) do
        if npc.priority == priority then
            table.insert(result, npc)
        end
    end
    return result
end

-- Get a specific NPC
function NPCManager.getNPC(npcId)
    return npcState.loadedNPCs[npcId]
end

-- Get NPCs at a location
function NPCManager.getNPCsAtLocation(location)
    local result = {}
    for id, npc in pairs(npcState.loadedNPCs) do
        if npc.currentLocation == location then
            table.insert(result, npc)
        end
    end
    return result
end

-- ============================================================================
--                      NPC INTERACTION
-- ============================================================================

-- Update NPC relationship with player
function NPCManager.updateRelationship(npcId, change)
    local npc = npcState.loadedNPCs[npcId]
    if npc then
        npc.relationships.player = math.max(-100, math.min(100, npc.relationships.player + change))
        npc.metPlayer = true
        return npc.relationships.player
    end
    return nil
end

-- Get NPC dialogue
function NPCManager.getDialogue(npcId, dialogueType)
    local npc = npcState.loadedNPCs[npcId]
    if not npc then return nil end

    local templates = DIALOGUE_TEMPLATES[npc.category] or DIALOGUE_TEMPLATES.commoner
    local dialogues = templates[dialogueType]

    if dialogues then
        return dialogues[math.random(#dialogues)]
    end

    return nil
end

-- Record conversation
function NPCManager.recordConversation(npcId)
    local npc = npcState.loadedNPCs[npcId]
    if npc then
        npc.conversationCount = npc.conversationCount + 1
        npc.metPlayer = true
    end
end

-- ============================================================================
--                      TIME SIMULATION
-- ============================================================================

-- Update NPC locations based on time of day
function NPCManager.updateTime(hour)
    local timeOfDay
    if hour >= 6 and hour < 12 then
        timeOfDay = "morning"
    elseif hour >= 12 and hour < 18 then
        timeOfDay = "afternoon"
    elseif hour >= 18 and hour < 24 then
        timeOfDay = "evening"
    else
        timeOfDay = "night"
    end

    for id, npc in pairs(npcState.loadedNPCs) do
        if npc.schedule[timeOfDay] then
            npc.currentLocation = npc.schedule[timeOfDay]
        end
    end
end

-- ============================================================================
--                      FIXED NPCs (Story Characters)
-- ============================================================================

local fixedNPCs = {}

-- Register a fixed/story NPC
function NPCManager.registerFixedNPC(npcData)
    fixedNPCs[npcData.id] = npcData
end

-- Get a fixed NPC
function NPCManager.getFixedNPC(npcId)
    return fixedNPCs[npcId]
end

-- Add fixed NPCs to a town
function NPCManager.addFixedNPCsToTown(townId, fixedNPCIds)
    for _, npcId in ipairs(fixedNPCIds) do
        local fixedNPC = fixedNPCs[npcId]
        if fixedNPC then
            local npc = {}
            for k, v in pairs(fixedNPC) do
                npc[k] = v
            end
            npc.townId = townId
            npc.isFixed = true
            npc.priority = "core"
            npcState.loadedNPCs[npcId] = npc

            -- Also save to generated state
            if npcState.generatedTowns[townId] then
                npcState.generatedTowns[townId][npcId] = npc
            end
        end
    end
end

-- ============================================================================
--                      SAVE/LOAD
-- ============================================================================

function NPCManager.getSaveData()
    return {
        generatedTowns = npcState.generatedTowns,
        fixedNPCs = fixedNPCs,
        townAccessOrder = npcState.townAccessOrder,
    }
end

function NPCManager.loadSaveData(data)
    if data then
        npcState.generatedTowns = data.generatedTowns or {}
        fixedNPCs = data.fixedNPCs or {}
        npcState.loadedNPCs = {}
        npcState.activeTownId = nil
        npcState.townAccessOrder = data.townAccessOrder or {}
    end
end

-- ============================================================================
--                      DEBUG/INFO
-- ============================================================================

function NPCManager.getDebugInfo()
    local loadedCount = 0
    local coreCount = 0
    local activeCount = 0
    local backgroundCount = 0

    for id, npc in pairs(npcState.loadedNPCs) do
        loadedCount = loadedCount + 1
        if npc.priority == "core" then
            coreCount = coreCount + 1
        elseif npc.priority == "active" then
            activeCount = activeCount + 1
        else
            backgroundCount = backgroundCount + 1
        end
    end

    local townCount = 0
    for _ in pairs(npcState.generatedTowns) do
        townCount = townCount + 1
    end

    return {
        activeTown = npcState.activeTownId,
        loadedNPCs = loadedCount,
        coreNPCs = coreCount,
        activeNPCs = activeCount,
        backgroundNPCs = backgroundCount,
        generatedTowns = townCount,
    }
end

-- ============================================================================
--                      RACIAL DATA ACCESS
-- ============================================================================

-- Get all race definitions
function NPCManager.getRaces()
    return RACES
end

-- Get a specific race
function NPCManager.getRace(raceId)
    return RACES[raceId]
end

-- Get regional demographics
function NPCManager.getRegionalDemographics(regionType)
    return REGIONAL_DEMOGRAPHICS[regionType] or REGIONAL_DEMOGRAPHICS.frontier
end

-- Get NPCs by race
function NPCManager.getNPCsByRace(raceId)
    local result = {}
    for id, npc in pairs(npcState.loadedNPCs) do
        if npc.race == raceId then
            table.insert(result, npc)
        end
    end
    return result
end

-- Get race distribution in current town
function NPCManager.getCurrentTownRaceDistribution()
    local distribution = {}
    local total = 0

    for id, npc in pairs(npcState.loadedNPCs) do
        local race = npc.race or "human"
        distribution[race] = (distribution[race] or 0) + 1
        total = total + 1
    end

    -- Convert to percentages
    if total > 0 then
        for race, count in pairs(distribution) do
            distribution[race] = {
                count = count,
                percent = math.floor((count / total) * 100),
            }
        end
    end

    distribution.total = total
    return distribution
end

-- ============================================================================
--                      INITIALIZATION
-- ============================================================================

function NPCManager.init()
    npcState.loadedNPCs = {}
    npcState.generatedTowns = {}
    npcState.activeTownId = nil
    npcState.npcCache = {}
    npcState.townAccessOrder = {}
end

return NPCManager
