-- World Generation System with Chunk-Based Loading
-- Supports predefined landmasses with infinite surrounding regions

local WorldGen = {}

-- ============================================================================
--                              CONSTANTS
-- ============================================================================

local CHUNK_SIZE = 16  -- 16x16 tiles per chunk (80x80 km at 5km/tile)
local LOAD_RADIUS = 2  -- Load chunks within 2 chunks of player
local MAX_LOADED_CHUNKS = 25  -- 5x5 grid around player

-- World scale (matches WORLD_SCALE in textrpg.lua)
local WORLD_SCALE = {
    kmPerTile = 5,
    sqKmPerTile = 25,
    milesPerTile = 3.1,
}

-- Layer system - allows surface and hollow earth to coexist
local LAYERS = {
    SURFACE = 0,      -- Normal world (Y coordinates as expected)
    HOLLOW = -1000,   -- Hollow earth (Y offset by -1000 to prevent collision with surface chunks)
}

-- Hollow Earth Y-offset (prevents chunk coordinate collision)
local HOLLOW_EARTH_Y_OFFSET = -1000

-- ============================================================================
--                         DUNGEON TYPES
-- ============================================================================

-- Dungeon types with base weights (matches textrpg.lua)
local DUNGEON_TYPES = {
    {id = "dungeon", name = "Dungeon", baseWeight = 30},
    {id = "cave", name = "Cave", baseWeight = 25},
    {id = "mine", name = "Mine", baseWeight = 20},
    {id = "vampire_den", name = "Vampire Den", baseWeight = 15},
    {id = "crypt", name = "Crypt", baseWeight = 10},
    {id = "lich_lair", name = "Lich Lair", baseWeight = 1},  -- Very rare - world threat
}

-- Lich Lair configuration - these are world-altering threats
local LICH_LAIR_CONFIG = {
    minFloors = 8,           -- Massive dungeons
    maxFloors = 12,
    corruptionRadius = 5,    -- Tiles around the lair become corrupted
    spawnChance = 0.003,     -- 0.3% base chance per dungeon tile
    minDistanceFromTowns = 8, -- Must be at least 8 tiles from any town
    undeadPatrolRadius = 3,  -- Undead patrol the surrounding area
    blightSpreadRate = 0.1,  -- 10% chance to spread corruption per game day
}

-- Region-specific dungeon type modifiers
-- Higher value = more likely in that region
local REGION_DUNGEON_WEIGHTS = {
    dwarven_mountains = {
        mine = 3.0,        -- Dwarves love mines
        cave = 1.5,        -- Mountain caves
        dungeon = 1.0,
        crypt = 0.5,
        vampire_den = 0.3, -- Rare in mountains
        lich_lair = 0.1,   -- Ancient evils beneath the mountains
    },
    orcish_steppes = {
        dungeon = 2.0,     -- War camps, strongholds
        cave = 1.2,
        crypt = 1.0,       -- Ancient battlefields
        mine = 0.5,
        vampire_den = 0.5,
        lich_lair = 0.2,   -- Warlords who became liches
    },
    holy_dominion = {
        crypt = 2.0,       -- Holy burial sites
        dungeon = 1.5,     -- Old keeps
        vampire_den = 0.8, -- Hidden lairs
        cave = 0.5,
        mine = 0.3,
        lich_lair = 0.3,   -- Fallen priests, corrupted clergy
    },
    shadowfen = {
        vampire_den = 3.0, -- Swamps attract vampires
        crypt = 2.0,       -- Ancient tombs
        cave = 1.5,        -- Bog caves
        dungeon = 0.8,
        mine = 0.2,
        lich_lair = 0.8,   -- Dark magic thrives here - MOST COMMON
    },
    eastern_forests = {
        cave = 2.0,        -- Forest caves
        dungeon = 1.5,     -- Ruins overgrown
        crypt = 1.0,       -- Hidden tombs
        vampire_den = 1.0, -- Forest lairs
        mine = 0.3,
        lich_lair = 0.2,   -- Ancient elven necromancers
    },
    gnomish_isles = {
        mine = 2.5,        -- Gnome mining operations
        dungeon = 1.5,     -- Clockwork dungeons
        cave = 1.0,
        crypt = 0.5,
        vampire_den = 0.3,
        lich_lair = 0.05,  -- Very rare - gnomes don't tolerate dark magic
    },
    -- Infinite regions
    great_endless_desert = {
        crypt = 3.0,       -- Ancient buried tombs
        dungeon = 1.5,     -- Lost temples
        cave = 1.0,        -- Desert caves
        vampire_den = 0.5,
        mine = 0.3,
        lich_lair = 0.5,   -- Ancient pharaoh-liches in buried tombs
    },
    scorched_sands = {
        crypt = 2.5,
        dungeon = 1.5,
        cave = 1.2,
        vampire_den = 0.8,
        mine = 0.5,
        lich_lair = 0.4,   -- Desolate places attract necromancers
    },
    wastes_of_calidar = {
        crypt = 2.0,       -- Wasteland tombs
        vampire_den = 1.5, -- Desolate lairs
        dungeon = 1.2,
        cave = 1.0,
        mine = 0.5,
        lich_lair = 0.6,   -- Wasteland breeding ground for dark magic
    },
    shimmering_sea = {
        cave = 3.0,        -- Sea caves
        dungeon = 1.5,     -- Underwater ruins
        crypt = 1.0,       -- Sunken tombs
        vampire_den = 0.5,
        mine = 0.2,
        lich_lair = 0,     -- No lich lairs in open ocean (corruption cannot cross water)
    },
    -- Hollow Earth regions - different dungeon distributions
    hollow_fungal_forests = {
        cave = 4.0,        -- Natural caves in fungal regions
        dungeon = 1.5,     -- Myconid structures
        crypt = 0.8,
        vampire_den = 1.2, -- Dark places
        mine = 0.5,
        lich_lair = 0.3,   -- Ancient hollow earth necromancers
    },
    hollow_jungle = {
        cave = 3.5,
        dungeon = 2.0,     -- Ancient ruins
        crypt = 1.5,       -- Abandoned temples
        vampire_den = 0.8,
        mine = 0.3,
        lich_lair = 0.4,
    },
    hollow_subterranean_seas = {
        cave = 5.0,        -- Sea caves
        dungeon = 1.0,     -- Underwater structures
        crypt = 2.0,       -- Sunken tombs
        vampire_den = 0.3,
        mine = 0.2,
        lich_lair = 0.2,
    },
    hollow_crystal_caverns = {
        cave = 3.0,
        mine = 4.0,        -- Crystal mining
        dungeon = 1.5,
        crypt = 0.5,
        vampire_den = 0.5,
        lich_lair = 0.3,
    },
    hollow_bone_wastes = {
        crypt = 5.0,       -- Necropolis
        dungeon = 2.0,
        vampire_den = 1.0,
        cave = 1.0,
        mine = 0.2,
        lich_lair = 1.5,   -- HIGHEST lich concentration in game
    },
    hollow_storm_caverns = {
        cave = 4.0,
        dungeon = 2.5,
        mine = 1.0,
        crypt = 0.8,
        vampire_den = 0.5,
        lich_lair = 0.5,
    },
    hollow_deep_dwarven_realm = {
        mine = 5.0,        -- Deep dwarf mining
        dungeon = 3.0,     -- Ancient halls
        cave = 2.0,
        crypt = 1.0,
        vampire_den = 0.2,
        lich_lair = 0.1,   -- Deep dwarves don't tolerate necromancy
    },
}

-- ============================================================================
--                           REGION DEFINITIONS
-- ============================================================================

-- Based on the provided fantasy map
local REGIONS = {
    -- Main Continent (~38,690 sq mi / ~100,000 sq km = ~4000 tiles = 64x64)
    main_continent = {
        id = "main_continent",
        name = "The Realm",
        bounds = {x1 = 0, y1 = 0, x2 = 63, y2 = 63},
        defaultTerrain = "grass",

        -- Subregions within the continent
        subregions = {
            {
                id = "dwarven_mountains",
                name = "Dwarven Mountains",
                bounds = {x1 = 18, y1 = 0, x2 = 45, y2 = 18},
                terrain = "mountain",
                terrainWeight = 0.65,
                altTerrain = {forest = 0.15, grass = 0.1, dungeon = 0.05, river = 0.03, lake = 0.02},
            },
            {
                id = "orcish_steppes",
                name = "Orcish Steppes",
                bounds = {x1 = 8, y1 = 15, x2 = 28, y2 = 35},
                terrain = "grass",
                terrainWeight = 0.5,
                altTerrain = {desert = 0.25, ruins = 0.15, dungeon = 0.1},
            },
            {
                id = "holy_dominion",
                name = "The Holy Dominion",
                bounds = {x1 = 25, y1 = 25, x2 = 55, y2 = 50},
                terrain = "grass",
                terrainWeight = 0.55,
                altTerrain = {forest = 0.22, town = 0.08, ruins = 0.07, lake = 0.04, river = 0.04},
            },
            {
                id = "shadowfen",
                name = "Shadowfen",
                bounds = {x1 = 5, y1 = 45, x2 = 25, y2 = 63},
                terrain = "swamp",
                terrainWeight = 0.6,
                altTerrain = {forest = 0.2, lake = 0.05, river = 0.05, dungeon = 0.1},
            },
            {
                id = "eastern_forests",
                name = "Eastern Forests",
                bounds = {x1 = 50, y1 = 10, x2 = 63, y2 = 45},
                terrain = "forest",
                terrainWeight = 0.60,
                altTerrain = {grass = 0.18, mountain = 0.1, ruins = 0.05, river = 0.04, lake = 0.03},
            },
        },
    },

    -- Gnomish Isles (~8,470 sq mi / ~22,000 sq km = ~880 tiles = 30x30)
    -- EXPANDED OCEAN: Now at X=120-149 (56 tiles of ocean from mainland at X=64)
    -- Ocean distance: 280km (174 miles) - prevents casual naval invasion
    gnomish_isles = {
        id = "gnomish_isles",
        name = "Gnomish Isles",
        bounds = {x1 = 120, y1 = 25, x2 = 149, y2 = 54},
        defaultTerrain = "grass",
        isIsland = true,

        subregions = {
            {
                id = "mechspire_region",
                name = "Mechspire Region",
                bounds = {x1 = 120, y1 = 30, x2 = 135, y2 = 45},
                terrain = "grass",
                terrainWeight = 0.5,
                altTerrain = {mountain = 0.2, forest = 0.15, ruins = 0.1, dungeon = 0.05},
            },
            {
                id = "clockwork_coast",
                name = "Clockwork Coast",
                bounds = {x1 = 120, y1 = 45, x2 = 140, y2 = 54},
                terrain = "grass",
                terrainWeight = 0.6,
                altTerrain = {lake = 0.08, river = 0.07, swamp = 0.15, forest = 0.1},
            },
        },
    },

    -- Infinite Regions (procedurally generated, no bounds limit)
    great_endless_desert = {
        id = "great_endless_desert",
        name = "The Great Endless Desert",
        alternateName = "The Desert Continent",
        direction = "north",
        bounds = {x1 = -50, y1 = -50, x2 = 100, y2 = -1},  -- BOUNDED massive desert continent (connects east-west)
        terrain = "desert",
        terrainWeight = 0.85,
        altTerrain = {mountain = 0.05, ruins = 0.05, dungeon = 0.03, grass = 0.02},
        sparsity = 0.97,  -- 97% empty, 3% points of interest
        description = "Massive desert continent north of the known lands. Called 'endless' by the empire because no expedition has crossed it entirely - but it IS bounded. Connects Scorched Sands (west) to eastern coasts. Beyond its northern edge lie frozen seas and the Frostbound Reach island. Beast folk originated here. Lizard folk hidden river empires lie beneath the sands.",
        imperialKnowledge = "Partial. Empire knows it's vast but believes it infinite. 'Endless' is imperial assumption, not fact.",
        accessibility = "Difficult. 50+ tiles to cross. Water scarcity, heat, disorientation. Ancient beast folk/lizard folk know routes.",
        size = "150×50 tiles = 7,500 tiles = 187,500 sq km (roughly size of Cambodia or Uruguay) - MASSIVE but crossable",
    },

    scorched_sands = {
        id = "scorched_sands",
        name = "The Scorched Sands",
        direction = "west",
        startX = -1,  -- x < 0
        terrain = "desert",
        terrainWeight = 0.80,
        altTerrain = {mountain = 0.08, ruins = 0.06, dungeon = 0.04, swamp = 0.02},
        sparsity = 0.95,
        description = "Continental barrier. Extends west far beyond imperial maps. Eventually reaches Western Ocean.",
    },

    -- NEW REGIONS BEYOND THE EMPIRE --

    frostbound_reach = {
        id = "frostbound_reach",
        name = "The Frostbound Reach",
        type = "frozen_island",
        direction = "far_north",
        bounds = {x1 = 10, y1 = -100, x2 = 60, y2 = -50},  -- EXTREMELY LARGE frozen island far north
        terrain = "ice",  -- Ice terrain with volcanic ridges
        terrainWeight = 0.70,
        altTerrain = {mountain = 0.18, forest = 0.05, lake = 0.03, river = 0.01, dungeon = 0.02, ruins = 0.01},  -- Varied geography
        sparsity = 0.75,  -- 75% empty (large but has features)
        isIsland = true,
        description = "An extremely large frozen island far to the north, beyond the Great Endless Desert and across violent northern seas. Continent-sized landmass (50×50 tiles / 250km×250km) with diverse geography: jagged ice cliffs carved by glaciers, volcanic mountain ranges venting heat and sulfur, geothermal valleys with sparse vegetation, frozen rivers, and ice sheet plateaus. Steam rises where fire meets ice, creating perpetual fog banks visible from far offshore. Despite brutal climate, the island supports limited settlements near geothermal zones.",
        imperialKnowledge = "Sparse. Imperial charts mark it sparingly. Few maps agree on exact outline. Fewer record settlements.",
        accessibility = "Difficult. Requires crossing Great Endless Desert (50+ tiles) then violent frozen seas. Reachable by ship in brief summer window or gnomish airship year-round.",
        climate = "Arctic with volcanic activity. Geothermal areas create microclimates. Perpetual storms, brief summer thaw. Ice-choked harbors.",
        population = "Unknown. Estimated small settlements (100-500?) near volcanic vents and geothermal valleys.",
        landmarks = "Ice cliffs, volcanic ridges (central spine), geothermal valleys, glacier caves, frozen harbors, steam vents, fog banks",
        size = "50×50 tiles = 2,500 tiles = 62,500 sq km (larger than Tasmania, smaller than Iceland)",
    },

    -- Northern Frozen Seas (around Frostbound)
    northern_seas = {
        id = "northern_seas",
        name = "The Northern Frozen Seas",
        alternateName = "Ice-Choked Waters",
        direction = "circum_frostbound",
        bounds = {x1 = -20, y1 = -120, x2 = 80, y2 = -45},  -- Waters around Frostbound, excluding the island itself
        terrain = "deep_ocean",
        terrainWeight = 0.80,
        altTerrain = {shallow_water = 0.06, ice = 0.06, grass = 0.01, ruins = 0.01, whirlpool = 0.01, shipwreck = 0.02, reef = 0.02, ocean_cave = 0.01},  -- Ice floes, rare islands, sea features
        sparsity = 0.96,  -- 96% empty (violent waters)
        isOcean = true,
        description = "Frozen seas surrounding the Frostbound Reach. Ice-choked waters, violent storms, drifting icebergs. Navigation extremely dangerous except in brief summer thaw. These waters separate the desert continent from the frozen island.",
        imperialKnowledge = "None. Not on imperial maps.",
        accessibility = "Extreme. Storm-prone, ice navigation required, no safe harbors.",
        climate = "Arctic ocean, ice floes year-round, violent storms, brief summer navigability",
    },

    -- Northern Tundra Continent (FAR north, connects back to south)
    northern_tundra_continent = {
        id = "northern_tundra_continent",
        name = "The Northern Tundra Continent",
        alternateName = "The Frozen North",
        direction = "extreme_north",
        bounds = {x1 = -100, y1 = -350, x2 = 150, y2 = -120},  -- CONTINENT-SIZED frozen landmass
        terrain = "ice",
        terrainWeight = 0.80,
        altTerrain = {mountain = 0.10, desert = 0.05, dungeon = 0.03, ruins = 0.02},  -- Varied frozen terrain
        sparsity = 0.90,  -- 90% empty but has features
        description = "Continent-sized frozen tundra in the far north. If traversed northward from Frostbound Reach or desert, this massive landmass eventually loops back to connect with the southern polar regions, forming part of the world's circumnavigation route. Ice sheets, frozen mountains, ancient ruins, and possible unknown civilizations adapted to extreme cold.",
        imperialKnowledge = "None. Beyond all imperial knowledge.",
        accessibility = "Nearly impossible. Requires crossing desert AND frozen seas AND surviving continent-scale arctic traverse.",
        climate = "Extreme arctic, perpetual winter, possible geothermal zones, aurora visible",
        population = "Unknown. Possibly adapted civilizations unknown to empire.",
        size = "250×230 tiles = massive frozen continent (circumnavigation northern route)",
    },

    western_ocean = {
        id = "western_ocean",
        name = "The Western Ocean",
        alternateName = "The Outer Waters",
        direction = "far_west",
        startX = -100,  -- x < -100 (beyond Scorched Sands)
        terrain = "deep_ocean",
        terrainWeight = 0.88,
        altTerrain = {shallow_water = 0.04, grass = 0.02, ruins = 0.01, dungeon = 0.01, whirlpool = 0.01, shipwreck = 0.02, ocean_cave = 0.01},  -- Rare islands, sea features
        sparsity = 0.99,  -- 99% empty ocean
        isOcean = true,
        description = "Ocean beyond the Scorched Sands. Darker and colder than the Silver Seas. Called 'Outer Waters' by those who know it.",
        imperialKnowledge = "Denied. Official maps claim Scorched Sands extend infinitely.",
        accessibility = "Beyond imperial reach. Requires crossing desert or airship flight.",
    },

    ashen_archipelago = {
        id = "ashen_archipelago",
        name = "The Ashen Archipelago",
        alternateName = "The Volcanic Isles",
        direction = "far_west",
        bounds = {x1 = -220, y1 = 5, x2 = -140, y2 = 55},  -- EXPANDED: Chain of volcanic islands
        terrain = "grass",  -- Islands are habitable
        terrainWeight = 0.40,
        altTerrain = {mountain = 0.30, forest = 0.15, shallow_water = 0.05, coastal = 0.03, reef = 0.02, dungeon = 0.05},  -- Volcanic peaks, coastal waters
        sparsity = 0.82,  -- 82% water, 18% islands (more islands than before)
        description = "Chain of volcanic islands scattered across the Western Ocean. Includes dozens of smaller isles and ONE large island: The Great Western Isle. Active volcanic peaks, coral reefs, sheltered harbors, geothermal hot springs. Some islands inhabited by unknown peoples. Lizard folk charts show the archipelago in detail - empire denies its existence.",
        imperialKnowledge = "None. Not on official maps. Gap in imperial geography.",
        accessibility = "Extreme. Requires crossing Scorched Sands (100 tiles desert) then Western Ocean (50+ tiles). Gnomish airships could reach easily.",
        isVolcanic = true,
        islands = {
            "The Great Western Isle (largest - 40×30 tiles)",
            "Lesser Ash Isles (scattered volcanic peaks)",
            "Coral Atolls (southern chain)",
            "Steam Islands (northern geothermal)"
        },
        specialNote = "Great Western Isle is the largest and most significant island in the chain.",
    },

    great_western_isle = {
        id = "great_western_isle",
        name = "The Great Western Isle",
        alternateName = "The Volcano Isle",
        direction = "ashen_archipelago_main",
        bounds = {x1 = -200, y1 = 15, x2 = -160, y2 = 45},  -- NOW WITHIN ASHEN ARCHIPELAGO (largest island)
        terrain = "grass",
        terrainWeight = 0.55,
        altTerrain = {mountain = 0.25, forest = 0.12, dungeon = 0.05, lake = 0.02, river = 0.01},  -- Volcanic mountains, inland water
        sparsity = 0.70,  -- Less sparse (largest inhabited island)
        isIsland = true,
        partOfArchipelago = "ashen_archipelago",
        description = "The largest and most significant island in the Ashen Archipelago. A volcanic island 40 tiles wide by 30 tiles tall (200km × 150km = 30,000 sq km) - large enough to support its own ecosystem and civilization. Central active volcano (The Magma Throat) dominates the landscape. Fertile volcanic soil supports lush vegetation. Ancient ruins suggest advanced pre-empire civilization. Small independent settlements resist outside contact. At the volcano's heart lies THE VOLCANIC DESCENT - the only guaranteed passage to the Hollow Earth.",
        imperialKnowledge = "None. Empire doesn't acknowledge Ashen Archipelago exists.",
        accessibility = "Extreme. Requires ocean crossing from main continent (180+ tiles via desert + ocean route).",
        population = "Estimated 1,000-3,000 in scattered tribal settlements. Independent, uncontacted.",
        size = "40×30 tiles = 1,200 tiles = 30,000 sq km (size of Belgium or Maryland)",
        specialFeature = "Contains THE VOLCANIC DESCENT - anchor cave to Hollow Earth (100% guaranteed access)",
    },

    wastes_of_calidar = {
        id = "wastes_of_calidar",
        name = "Wastes of Calidar",
        alternateName = "The Glass Desert",
        direction = "south",
        bounds = {x1 = 20, y1 = 64, x2 = 50, y2 = 79},  -- 30×15 tiles = 450 tiles ≈ 11,250 sq km (matches 10,887 km² spec)
        terrain = "desert",
        terrainWeight = 0.75,
        altTerrain = {swamp = 0.1, ruins = 0.08, dungeon = 0.05, grass = 0.02},
        sparsity = 0.96,
        description = "Former elven homeland of Calidar, destroyed 500 years ago by Heaven's Atlas. Glass desert created from vitrified forests - extends 30×15 tiles to match destroyed nation's size (10,887 sq km / 4,203 sq mi). Called 'endless' by those who traverse it, but it does eventually reach the Southern Ocean coast. Millions died here. Elves remember every lost city's name.",
        imperialKnowledge = "Complete. Empire destroyed it, uses it as monument/warning.",
        accessibility = "Moderate but deadly. Glass shards, heat, no water, memory echoes, psychological horror.",
        size = "30×15 tiles = 450 tiles ≈ 11,250 sq km (matches historical Calidar extent)",
        historicalSize = "Pre-war Calidar: Thriving forest realm for thousands of years with millions of inhabitants.",
    },

    -- Southern Ocean (The Sunless Sea)
    southern_ocean = {
        id = "southern_ocean",
        name = "The Southern Ocean",
        alternateName = "The Sunless Sea",
        direction = "far_south",
        bounds = {x1 = -100, y1 = 80, x2 = 200, y2 = 249},  -- Starts Y:80 (after Wastes end at Y:79)
        terrain = "deep_ocean",
        terrainWeight = 0.88,
        altTerrain = {shallow_water = 0.04, grass = 0.02, ice = 0.01, ruins = 0.01, whirlpool = 0.01, shipwreck = 0.02, ocean_cave = 0.01},  -- Rare islands, sea features
        sparsity = 0.98,  -- 98% empty ocean
        isOcean = true,
        description = "Cold southern ocean beyond the Wastes of Calidar. Darker waters, violent storms, ice floes drift southward. Called 'Sunless Sea' by those who know it exists (empire denies it). 170 tiles from Wastes coast to Southern Tundra coast - vast cold barrier before polar region.",
        imperialKnowledge = "None. Empire claims Wastes extend infinitely southward (strategic ignorance to avoid acknowledging world's true size).",
        accessibility = "Extreme. Requires crossing Wastes (15 tiles glass desert) then ocean navigation (170 tiles = 850km).",
        climate = "Cold, stormy, treacherous currents, ice formations increase southward",
    },

    -- Southern Tundra (Polar Wastes)
    southern_tundra = {
        id = "southern_tundra",
        name = "The Southern Tundra",
        alternateName = "The Polar Wastes",
        direction = "extreme_south",
        startY = 250,  -- y >= 250 (but y < 350)
        bounds = {x1 = -100, y1 = 250, x2 = 200, y2 = 349},  -- Bounded polar region
        terrain = "ice",  -- Tundra/ice terrain
        terrainWeight = 0.92,
        altTerrain = {mountain = 0.04, ruins = 0.02, dungeon = 0.02},  -- Sparse features
        sparsity = 0.98,  -- 98% empty
        description = "Polar tundra beyond the Southern Ocean. Cold wasteland where ice meets sparse vegetation. Southern polar region—mirror of Frostbound Reach. Frozen rivers, permafrost, harsh winds.",
        imperialKnowledge = "None. Not even theorized.",
        accessibility = "Extreme. Glass desert → Ocean → Polar conditions.",
        climate = "Arctic tundra, permafrost, frozen wasteland, occasional geothermal activity",
    },

    -- Polar Ocean (The Encircling Sea) - Connects back to north
    polar_ocean = {
        id = "polar_ocean",
        name = "The Polar Ocean",
        alternateName = "The Encircling Sea",
        direction = "circumpolar",
        startY = 350,  -- y >= 350
        terrain = "deep_ocean",
        terrainWeight = 0.86,
        altTerrain = {shallow_water = 0.04, ice = 0.04, grass = 0.01, ruins = 0.01, whirlpool = 0.01, shipwreck = 0.02, ocean_cave = 0.01},  -- Ice sheets, sea features
        sparsity = 0.99,  -- 99% empty ocean
        isOcean = true,
        description = "Polar ocean encircling the southern ice cap. Connects east to west, forming a complete oceanic ring around the southern pole. Ice-choked waters, rare ice islands, perpetual storms. Theory: This ocean connects back to northern waters, making the world circumnavigable.",
        imperialKnowledge = "None. World believed to be flat or have southern edge.",
        accessibility = "Nearly impossible. Requires polar survival and ice-breaking ships or airships.",
        climate = "Frozen ocean, ice sheets, polar storms, treacherous currents",
        worldStructure = "CIRCUMNAVIGATION ROUTE: This ocean theoretically connects back to Great Endless Desert northern reaches, Frostbound Reach, or even loops to western/eastern oceans. World is spherical.",
    },

    shimmering_sea = {
        id = "shimmering_sea",
        name = "The Shimmering Sea",
        direction = "east",
        startX = 110,  -- x >= 110 (after Gnomish Isles)
        terrain = "deep_ocean",
        terrainWeight = 0.82,
        altTerrain = {shallow_water = 0.05, grass = 0.03, reef = 0.03, ruins = 0.02, dungeon = 0.01, whirlpool = 0.01, shipwreck = 0.02, ocean_cave = 0.01},  -- Islands, sea features
        sparsity = 0.98,
        isOcean = true,
    },

    -- Ocean between continent and isles (The Silver Seas)
    silver_seas = {
        id = "silver_seas",
        name = "The Silver Seas",
        bounds = {x1 = 64, y1 = 0, x2 = 119, y2 = 63},  -- EXPANDED: 56 tiles (280km) of ocean separation
        terrain = "deep_ocean",
        terrainWeight = 0.78,
        altTerrain = {shallow_water = 0.06, coastal = 0.04, grass = 0.04, reef = 0.03, ruins = 0.02, dungeon = 0.01, shipwreck = 0.01, ocean_cave = 0.01},  -- Small islands, sea features
        isOcean = true,
        description = "The waters separating the Main Continent from the Gnomish Isles.",
    },

    -- ========================================================================
    --                      HOLLOW EARTH REGIONS
    -- ========================================================================
    -- The world beneath the world - accessible through deep dungeons
    -- Uses Y-offset system: hollow_y = surface_y + HOLLOW_EARTH_Y_OFFSET
    -- This prevents chunk coordinate collision with surface world

    -- Fungal Forests (Hollow Earth - Northwest)
    hollow_fungal_forests = {
        id = "hollow_fungal_forests",
        name = "The Fungal Forests",
        layer = LAYERS.HOLLOW,
        bounds = {x1 = -50, y1 = -1050, x2 = 0, y2 = -1000},  -- Surface equivalent: x=-50 to 0, y=-50 to 0
        defaultTerrain = "forest",
        terrain = "fungal_forest",
        terrainWeight = 0.65,
        altTerrain = {cave = 0.15, swamp = 0.10, dungeon = 0.05, lake = 0.03, river = 0.02},
        sparsity = 0.70,
        description = "Vast forests of bioluminescent fungi stretching hundreds of kilometers beneath the surface. Massive mushroom trees tower 50 meters high, glowing in blues, greens, and purples. The air is thick with spores and the ground soft with decomposing matter. Fungal creatures and blind cave dwellers inhabit these alien woods. Rivers of phosphorescent slime wind through the fungal canopy.",
        features = {
            "bioluminescent_flora",
            "giant_mushrooms",
            "spore_clouds",
            "fungal_creatures",
            "underground_rivers",
        },
        inhabitants = "Myconids, blind cave folk, giant insects, fungal horrors",
        accessibility = "Through deep mine breaches (floors 15+) or volcanic tubes",
        hollowEarthZone = "outer_shell",
    },

    -- Hollow Jungle (Hollow Earth - Northeast)
    hollow_jungle = {
        id = "hollow_jungle",
        name = "The Hollow Jungle",
        alternateName = "The Sunless Green",
        layer = LAYERS.HOLLOW,
        bounds = {x1 = 50, y1 = -1050, x2 = 100, y2 = -1000},  -- Surface equivalent: x=50 to 100, y=-50 to 0
        defaultTerrain = "forest",
        terrain = "hollow_jungle",
        terrainWeight = 0.70,
        altTerrain = {swamp = 0.15, lake = 0.05, river = 0.03, ruins = 0.05, dungeon = 0.02},
        sparsity = 0.65,
        description = "An impossible jungle thriving in perpetual darkness, sustained by geothermal heat and bioluminescent energy. Massive trees with translucent leaves absorb ambient light from glowing crystals embedded in the cavern ceiling far above. Warm, humid air circulates through vast cave systems. LIVING FOSSILS stalk this realm: velociraptors hunt in coordinated packs, pterodactyls roost in the canopy, massive sauropods graze on glowing vegetation, and apex predators rivaling Tyrannosaurus prowl the undergrowth. The jungle teems with species extinct on the surface for millions of years—or perhaps this realm exists outside normal time. Ancient ruins of sophisticated architecture suggest a pre-empire saurian civilization: temples with astronomical alignments, aqueducts of precise engineering, carved monuments depicting upright reptilian builders. THE SAURIANS—intelligent dinosaur people—may still inhabit the jungle's depths. Lizard folk speak obliquely of 'deep cousins who never left.' Some expeditions report glimpsed cities built by scaled architects. The empire dismisses these as delusion. The stonework suggests otherwise.",
        features = {
            "geothermal_vents",
            "crystal_ceiling_light",
            "translucent_flora",
            "ancient_saurian_ruins",
            "thermal_predators",
            "dinosaur_nesting_grounds",
            "intelligent_saurian_settlements",
        },
        inhabitants = "Velociraptors (pack hunters), pterodactyls, sauropods, thermal tyrannosaurs, hollow apes, thermal serpents, blind jaguars, intelligent saurian tribes (rare), lost explorers gone feral",
        accessibility = "Through eastern forest dungeon breaches (floors 18+)",
        hollowEarthZone = "outer_shell",
        mysteries = "Who built the ruins? Are the saurians extinct or merely hidden? Why do dinosaurs thrive here when they vanished from the surface? Does this realm exist outside normal time?",
    },

    -- Subterranean Seas (Hollow Earth - Central West)
    hollow_subterranean_seas = {
        id = "hollow_subterranean_seas",
        name = "The Subterranean Seas",
        alternateName = "The Lightless Waters",
        layer = LAYERS.HOLLOW,
        bounds = {x1 = -40, y1 = -1030, x2 = 20, y2 = -980},  -- Large central sea
        defaultTerrain = "water",
        terrain = "underground_ocean",
        terrainWeight = 0.85,
        altTerrain = {cave = 0.08, island = 0.04, ruins = 0.02, dungeon = 0.01},
        sparsity = 0.80,
        isOcean = true,
        description = "Vast underground oceans stretching beyond sight, their surfaces reflecting the glow of bioluminescent plankton. The water is cold, black, and impossibly deep. Stone islands rise from the depths, some inhabited by blind fish-folk tribes. Ancient docks and harbors carved into cavern walls suggest ships once sailed these waters. Echoes carry for kilometers. The Lizard Folk speak of ancestral memories—their species originated here before migrating to the surface through underground rivers.",
        features = {
            "bioluminescent_plankton",
            "stone_islands",
            "ancient_harbors",
            "underground_currents",
            "echoing_depths",
        },
        inhabitants = "Blind fish-folk, cave krakens, phosphorescent eels, Lizard Folk pilgrims",
        accessibility = "Through Shadowfen deep dungeons (floors 20+) or following underground rivers",
        hollowEarthZone = "middle_shell",
        connection = "Underground rivers connect to surface swamps and coasts",
        lizardFolkSignificance = "Ancestral homeland - Lizard Folk originated in these waters",
    },

    -- Crystal Caverns (Hollow Earth - Southeast)
    hollow_crystal_caverns = {
        id = "hollow_crystal_caverns",
        name = "The Crystal Caverns",
        alternateName = "The Singing Halls",
        layer = LAYERS.HOLLOW,
        bounds = {x1 = 30, y1 = -1020, x2 = 80, y2 = -990},
        defaultTerrain = "cave",
        terrain = "crystal_cavern",
        terrainWeight = 0.75,
        altTerrain = {mountain = 0.10, dungeon = 0.08, ruins = 0.05, lake = 0.02},
        sparsity = 0.75,
        description = "Caverns filled with massive crystal formations that hum and resonate with ambient vibrations. The crystals range from tiny shards to towering spires 100 meters tall. Different crystal types produce different tones, creating a constant symphony of sound. Some crystals store magical energy naturally. Gnomish legends mention expeditions that discovered crystal caverns far beneath their isles, but official records deny these claims. The crystals seem to grow in geometric patterns that suggest artificial cultivation.",
        features = {
            "resonating_crystals",
            "crystal_spires",
            "harmonic_chambers",
            "natural_magic_storage",
            "geometric_growth_patterns",
        },
        inhabitants = "Crystal elementals, crystallized undead, rogue gnomish miners, echo bats",
        accessibility = "Through deep gnomish mine breaches (floors 22+) or eastern dungeon descents",
        hollowEarthZone = "middle_shell",
        gnomishConnection = "Denied officially, but gnomish miners know the truth",
        magicProperties = "Crystals can store and amplify magical energy naturally",
    },

    -- Bone Wastes (Hollow Earth - Southwest)
    hollow_bone_wastes = {
        id = "hollow_bone_wastes",
        name = "The Bone Wastes",
        alternateName = "The Ossuary",
        layer = LAYERS.HOLLOW,
        bounds = {x1 = -70, y1 = -1010, x2 = -20, y2 = -970},
        defaultTerrain = "desert",
        terrain = "bone_desert",
        terrainWeight = 0.80,
        altTerrain = {ruins = 0.10, cave = 0.05, dungeon = 0.05},
        sparsity = 0.88,
        description = "An underground desert of pulverized bone dust and fossilized remains stretching for hundreds of kilometers. Ancient battlefields from wars fought before recorded history. The ground is white with bone powder, and fossilized skeletons of enormous creatures protrude from dunes. Necromantic energy permeates the region—the dead do not rest here. Wind howls through hollow caverns, carrying whispers in forgotten languages. Goblin tribal legends speak of 'the white desert beneath' where their ancient kings fought and fell.",
        features = {
            "bone_dust_dunes",
            "fossilized_titans",
            "necromantic_energy",
            "whispering_winds",
            "ancient_battlefields",
        },
        inhabitants = "Bone wights, fossil golems, necromancer exiles, goblin bone-seekers",
        accessibility = "Through orcish steppes crypts (floors 20+) or western desert breaches",
        hollowEarthZone = "middle_shell",
        goblinSignificance = "Ancient goblin kingdoms fell here - tribal legends are TRUE",
        danger = "Necromantic energy causes spontaneous undead animation",
    },

    -- Storm Caverns (Hollow Earth - Central)
    hollow_storm_caverns = {
        id = "hollow_storm_caverns",
        name = "The Storm Caverns",
        alternateName = "The Howling Deep",
        layer = LAYERS.HOLLOW,
        bounds = {x1 = -10, y1 = -1005, x2 = 40, y2 = -975},
        defaultTerrain = "cave",
        terrain = "storm_cavern",
        terrainWeight = 0.70,
        altTerrain = {mountain = 0.15, lake = 0.05, river = 0.03, dungeon = 0.05, ruins = 0.02},
        sparsity = 0.78,
        description = "Massive caverns where underground weather systems rage eternally. Geothermal temperature differentials create permanent storm fronts—lightning arcs between crystal formations, rain falls upward in antigravity zones, and hurricane-force winds scream through tunnels for kilometers. The ceiling is so high it disappears into darkness and storm clouds. Reality becomes unstable here—gravity shifts, time dilates, and compass needles spin wildly. Scientists deny this place can exist. It exists anyway.",
        features = {
            "underground_storms",
            "antigravity_zones",
            "lightning_crystals",
            "reality_distortion",
            "impossible_weather",
        },
        inhabitants = "Storm elementals, gravity-adapted creatures, mad scientists, lost airship crews",
        accessibility = "Through central continent deep dungeons (floors 25+) or rare portal breaches",
        hollowEarthZone = "inner_shell",
        danger = "Extreme - reality becomes unreliable",
        scientificImplications = "Proves hollow earth theory, which is why empire suppresses evidence",
    },

    -- Deep Dwarven Realm (Hollow Earth - North Central)
    hollow_deep_dwarven_realm = {
        id = "hollow_deep_dwarven_realm",
        name = "The Deep Dwarven Realm",
        alternateName = "The Sundered Holds",
        layer = LAYERS.HOLLOW,
        bounds = {x1 = -30, y1 = -1040, x2 = 30, y2 = -1000},
        defaultTerrain = "cave",
        terrain = "deep_dwarf_city",
        terrainWeight = 0.60,
        altTerrain = {mountain = 0.20, dungeon = 0.10, ruins = 0.08, lava = 0.02},
        sparsity = 0.72,
        description = "Ancient dwarven cities carved into hollow earth stone, abandoned centuries ago when surface dwarves sealed the deep passages. The Deep Dwarves—those who refused to ascend—remain here still, isolated and changed by millennia underground. Their architecture is older and grander than anything on the surface. Massive halls, kilometers-long bridges spanning chasms, forge-temples powered by geothermal vents. They mine metals that don't exist on the surface. They remember what surface dwarves have forgotten. And they do not welcome visitors.",
        features = {
            "ancient_architecture",
            "geothermal_forges",
            "impossible_metals",
            "deep_dwarf_cities",
            "sealed_passages",
        },
        inhabitants = "Deep Dwarves (isolated, hostile), blind cave bears, magma elementals",
        accessibility = "Through dwarven mountain deep mines (floors 28+) or Volcanic Descent (floor 30 GUARANTEED)",
        hollowEarthZone = "middle_shell",
        dwarvenConnection = "CRITICAL - Surface dwarves know about this but DENY it publicly",
        culture = "Deep Dwarves maintain old ways - no surface contact for centuries",
        secrets = "Deep Dwarves possess knowledge and metals unknown to surface",
        hostility = "HIGH - Deep Dwarves consider surface dwarves traitors who abandoned the deep",
    },

}

-- ============================================================================
--                          ANCHOR TOWNS
-- ============================================================================

-- Fixed towns that are the same every playthrough (for story)
local ANCHOR_TOWNS = {
    -- Holy Dominion Capital
    {
        id = "solara",
        name = "Solara, City of Light",
        region = "holy_dominion",
        position = {x = 40, y = 38},
        level = 10,
        type = "capital",
        population = 1200,
        isAnchor = true,
        fixedNPCs = {"high_priest_aldric", "knight_commander_vex", "oracle_myria"},
        mainQuests = {"chapter_1_awakening", "chapter_3_revelation"},
        landmarks = {"grand_cathedral", "royal_palace", "sacred_grove"},
        hasDistricts = true,
        hasUnderbelly = true,
        description = "The shining capital of the Holy Dominion, seat of the High Priest.",
    },

    -- Dwarven Capital
    {
        id = "ironhold",
        name = "Ironhold",
        region = "dwarven_mountains",
        position = {x = 32, y = 8},
        level = 12,
        type = "capital",
        population = 800,
        isAnchor = true,
        fixedNPCs = {"king_thorin", "master_smith_bram", "runekeeper_dara"},
        mainQuests = {"chapter_2_forging"},
        landmarks = {"great_forge", "throne_of_stone", "deep_mines"},
        hasDistricts = true,
        hasUnderbelly = true,
        description = "Ancient dwarven stronghold carved into the mountain.",
    },

    -- Orcish Stronghold
    {
        id = "kragmor",
        name = "Kragmor",
        region = "orcish_steppes",
        position = {x = 18, y = 25},
        level = 8,
        type = "fortress",
        population = 300,
        isAnchor = true,
        fixedNPCs = {"warchief_grommash", "shaman_earthseer"},
        mainQuests = {"orc_alliance"},
        landmarks = {"blood_arena", "war_totems"},
        description = "The great orcish fortress, home of the united clans.",
    },

    -- Shadowfen Village
    {
        id = "murkmire",
        name = "Murkmire",
        region = "shadowfen",
        position = {x = 15, y = 52},
        level = 6,
        type = "village",
        population = 100,
        isAnchor = true,
        fixedNPCs = {"witch_morgana", "ferryman_charon"},
        mainQuests = {"swamp_secrets"},
        landmarks = {"black_tower", "sunken_temple"},
        description = "A mysterious village shrouded in perpetual mist.",
    },

    -- Gnomish Capital
    {
        id = "mechspire",
        name = "Mechspire",
        region = "gnomish_isles",
        position = {x = 128, y = 38},
        level = 15,
        type = "capital",
        population = 900,
        hasDistricts = true,
        hasUnderbelly = true,
        isAnchor = true,
        fixedNPCs = {"archinventor_fizz", "librarian_nix", "captain_gears"},
        mainQuests = {"chapter_4_discovery"},
        landmarks = {"clockwork_tower", "innovation_hall", "sky_docks"},
        description = "A marvel of gnomish engineering, filled with whirring machines.",
    },

    -- Gnomish Port
    {
        id = "clockwork_harbor",
        name = "Clockwork Harbor",
        region = "gnomish_isles",
        position = {x = 125, y = 50},
        level = 8,
        type = "port",
        population = 200,
        isAnchor = true,
        fixedNPCs = {"harbormaster_cogsworth", "merchant_princess_tink"},
        mainQuests = {},
        landmarks = {"lighthouse_automaton", "trading_docks"},
        description = "The main port connecting the Gnomish Isles to the mainland.",
    },

    -- Starting Town (player always starts here) - HUMBLE STARTING VILLAGE
    {
        id = "havenbrook",
        name = "Havenbrook",
        region = "holy_dominion",
        position = {x = 35, y = 42},
        level = 1,
        type = "village",
        population = 80,  -- Small humble village
        isAnchor = true,
        isStartingTown = true,
        fixedNPCs = {
            "tavern_keeper_mira",     -- Player's employer
            "stable_master_hank",
            "elder_brom",             -- Village elder
        },
        mainQuests = {"tutorial_quest", "tavern_troubles"},
        landmarks = {
            "the_lucky_coin_tavern",  -- Player works here
            "chapel_of_helios",       -- Small village chapel
        },
        description = "A humble crossroads village in the Holy Dominion. Quiet, cozy, and unremarkable—yet something about it draws travelers. The Lucky Coin tavern serves as the social heart of this small community.",
        culture = "A simple farming village where everyone knows each other. Travelers pass through on their way to the capital.",
    },

    -- Human Capital - Grand seat of imperial administration (MEGA CITY)
    {
        id = "kingshold",
        name = "Helios' Gate",
        region = "holy_dominion",
        position = {x = 30, y = 32},
        level = 12,
        type = "mega_city",
        population = 2500,  -- Largest human city - mega city status
        isAnchor = true,
        hasDistricts = true,
        hasUnderbelly = true,
        fixedNPCs = {
            "lord_governor_aldren",   -- Imperial Governor (secular administrator)
            "lord_chancellor_voss",   -- Chief advisor
            "knight_marshal_sera",    -- Military commander
            "imperial_archivist_penn",-- Keeper of histories
            "guild_master_thornton",  -- Head of merchants
        },
        mainQuests = {"imperial_audience", "palatine_conspiracy", "war_council"},
        landmarks = {
            "the_palatine_citadel",   -- Imperial administrative palace
            "grand_cathedral_of_dawn",-- Massive cathedral
            "war_academy",            -- Military training
            "great_library",          -- Repository of imperial knowledge
            "merchant_quarter",       -- Bustling trade district
            "noble_quarter",          -- Aristocratic residences
        },
        features = {
            "imperial_court",
            "military_academy",
            "grand_market",
            "noble_politics",
        },
        description = "The grand administrative capital of the Holy Dominion, second only to Solara in political importance. Towering walls of pale stone encircle sprawling districts—from the bustling Merchant Quarter to the stately Noble Quarter. At its heart rises the Palatine Citadel, seat of Lord Governor Aldren, who administers the secular affairs of the empire under the Emperor's divine mandate. The city pulses with ambition, politics, and the weight of imperial power.",
        culture = "A city of laws, ambition, and imperial service. Humans come from across the realm to seek fortune, serve the Dominion, or study at the Great Library. The War Academy trains the finest soldiers under Helios' light.",
        demographics = {human = 0.80, elf = 0.08, dwarf = 0.05, gnome = 0.04, beast_folk = 0.03},
    },

    -- Prison Harbor - Fortified coastal prison complex
    {
        id = "ironshore_prison",
        name = "The Sunken Ledger",
        region = "holy_dominion",
        position = {x = 55, y = 48},
        level = 8,
        type = "prison_fortress",
        population = 150,  -- Guards, wardens, and prisoners
        isAnchor = true,
        fixedNPCs = {
            "warden_blackthorn",      -- Prison warden
            "captain_of_the_watch",   -- Guard captain
            "prison_chaplain_mercy",  -- Offers spiritual guidance
            "smuggler_contact_rat",   -- Hidden NPC for dark quests
        },
        mainQuests = {"prison_break", "warden_secret", "smugglers_route"},
        landmarks = {
            "the_bastille",           -- Main prison block
            "wardens_tower",          -- Tallest structure
            "gallows_yard",           -- Public executions
            "prisoner_docks",         -- Where ships bring prisoners
            "fortress_walls",         -- Imposing gray stone walls
        },
        features = {
            "prison",
            "fortress",
            "harbor",
            "restricted_access",
        },
        description = "The Sunken Ledger, so named because those inscribed upon its rolls are struck from the world above. A vast subterranean prison complex carved into coastal cliffs, its lowest floors descend below the waterline where the condemned labor in perpetual darkness. The Holy Dominion sends its most dangerous criminals, political dissidents, and those it wishes forgotten to this place.",
        culture = "A place of punishment, secrets, and forgotten debts. The guards are ruthless, the warden answers to no one, and the lowest floors hold horrors older than the prison itself. Rumors persist of hidden tunnels, smuggling routes, and prisoners who discovered things in the deep that the warden desperately wants kept silent.",
        demographics = {human = 0.90, orc = 0.05, goblin = 0.03, elf = 0.02},
        specialFeatures = {
            "prisoner_labor",
            "restricted_zones",
            "smuggling_tunnels",
            "sunken_ledger_prison",  -- Special dungeon below the fortress
            "shadow_market",         -- Underground black market
            "identity_forger",       -- Shadow Syndicate identity forging
            "thieves_guild",         -- Criminal network
        },
        secrets = {"The Sunken Ledger has never had a successful escape... until now."},
    },

    -- Harbour Town near the Prison - Where escaped prisoners emerge
    {
        id = "ironshore",
        name = "Ironshore",
        region = "holy_dominion",
        position = {x = 53, y = 49},
        level = 3,
        type = "port",
        population = 120,
        isAnchor = true,
        fixedNPCs = {
            "harbormaster_greaves",    -- Runs the docks, looks the other way
            "tavern_keeper_sal",       -- The Rusty Anchor tavern
            "guild_fence_whisper",     -- Thieves guild contact / fence
        },
        mainQuests = {"smugglers_passage", "clear_your_name"},
        landmarks = {
            "the_rusty_anchor",        -- Dockside tavern, guild safehouse
            "western_cove",            -- Hidden cove used by smugglers
            "ironshore_docks",         -- Small fishing and trade docks
        },
        features = {
            "harbor",
            "smuggling_hub",
            "thieves_guild_presence",
        },
        description = "A weathered port town clinging to the cliffs west of The Sunken Ledger. Officially a fishing village and supply stop for the prison, Ironshore's true trade is conducted in shadow—smuggling, fencing, and providing passage for those who need to disappear. The Veiled Hand operates openly here under the guise of a dockworkers' guild.",
        culture = "A town of hard folk who ask no questions. Fishermen, smugglers, and ex-convicts share drinks at The Rusty Anchor while prison supply ships dock at the harbour. Everyone knows everyone's business, and everyone keeps their mouth shut.",
        demographics = {human = 0.70, goblin = 0.10, orc = 0.08, elf = 0.07, dwarf = 0.05},
    },

    -- Elven Administrative City (Southern Reaches)
    {
        id = "sylvaris",
        name = "Sylvaris",
        region = "holy_dominion",  -- South of human heartlands
        position = {x = 45, y = 55},
        level = 8,
        type = "administrative_city",
        population = 350,
        isAnchor = true,
        fixedNPCs = {"high_archivist_aelindra", "trade_magistrate_lorien", "keeper_of_secrets"},
        mainQuests = {"hidden_knowledge"},
        landmarks = {"great_archive", "trade_tribunal", "sealed_vault"},
        description = "The bureaucratic heart of elven administration. Diplomats, archivists, and legal scholars maintain the empire's records here.",
        culture = "Elves serve as the bureaucratic backbone of civilization—the empire's right hand.",
        secrets = {"Ancient magic hidden in sealed archives and forgotten bloodlines."},
    },

    -- Goblin Tribal Village
    {
        id = "bonetrap",
        name = "BoneTrap",
        region = "orcish_steppes",  -- Western borderlands, hidden in rocky terrain
        position = {x = 10, y = 38},
        level = 4,
        type = "tribal_warren",
        population = 120,
        isAnchor = true,
        fixedNPCs = {"boss_skrag", "tinkerer_grix", "shaman_zeek"},
        mainQuests = {"goblin_troubles", "warren_wars"},
        landmarks = {"scrap_heap", "boom_corner", "bosss_shack"},
        description = "A defiant goblin resistance warren built into rocky crevices and reclaimed ruins. No formal government—leadership rotates through merit and challenge. Fiercely anti-imperial. Outsiders interrogated for imperial ties. Collaborators executed.",
        culture = "The empire is illegitimate. The occupation ends when we say it ends. Goblins remember stolen homelands, imperial massacres, and fight for liberation through armed resistance.",
        demographics = {goblin = 0.95, human = 0.03, orc = 0.02},  -- 95% goblin
        specialFeatures = {"black_market", "illegal_goods", "smuggling_hub"},
    },

    -- Catfolk Desert Harbor (in the Great Endless Desert)
    {
        id = "fortunes_rest",
        name = "Fortune's Rest",
        region = "great_endless_desert",  -- Desert oasis harbor
        position = {x = 35, y = -8},  -- North of continent, IN the desert (Y < 0)
        level = 9,
        type = "desert_harbor",
        population = 300,
        isAnchor = true,
        fixedNPCs = {"matriarch_whisperwind", "casino_master_lucky", "harbormaster_sandclaw"},
        mainQuests = {"desert_mysteries", "nine_lives_pact"},
        landmarks = {"cats_eye_casino", "golden_docks", "arena_of_acrobats", "silk_bazaar"},
        description = "Where sands meet sea—a stunning desert oasis harbor built by catfolk traders. Sandstone architecture with billowing silk awnings. Fortune's Rest maintains an elegant atmosphere where gambling is art, not desperation—a jewel of catfolk culture.",
        culture = "Balance of luck and skill. Catfolk philosophy: chance reflects attention, timing, and respect for risk. Pattern recognition refined over generations.",
        demographics = {beast_folk = 0.70, human = 0.15, lizard_folk = 0.10, elf = 0.05},  -- 70% catfolk
        specialFeatures = {"luxury_gambling", "acrobat_performances", "desert_trade", "fortune_telling"},
        climate = "Desert oasis—hot days, cool nights, rare storms",
    },

    -- MEGA CITY: Crossroads - The great trade hub where all roads meet
    {
        id = "crossroads",
        name = "Valdris Crossing",
        region = "holy_dominion",
        position = {x = 38, y = 35},
        level = 10,
        type = "mega_city",
        population = 2000,
        isAnchor = true,
        hasDistricts = true,
        hasUnderbelly = true,
        fixedNPCs = {
            "governor_marcus_vale",       -- Trade governor
            "harbor_admiral_elena",       -- Fleet commander
            "underworld_boss_shade",      -- Criminal kingpin (hidden)
            "guild_coordinator_penn",     -- Manages all guild presences
            "foreign_ambassador_kenji",   -- Diplomatic envoy
        },
        mainQuests = {"trade_war", "underworld_uprising", "foreign_crisis"},
        landmarks = {
            "the_grand_exchange",         -- Massive trade hall
            "valdris_colosseum",          -- Arena for gladiatorial combat
            "tower_of_tongues",           -- Translator and diplomat center
            "the_undermarket",            -- Largest black market in the realm
            "crossroads_cathedral",       -- Multi-faith temple
            "guild_row",                  -- Street with all major guild halls
        },
        features = {
            "trade_hub",
            "multi_cultural",
            "criminal_underworld",
            "gladiatorial_games",
            "guild_headquarters",
        },
        description = "The largest trade city in the known world, where every road eventually leads. Valdris Crossing sits at the intersection of the major trade routes connecting all nations. Its population is a melting pot of every race and culture. Fortunes are made and lost in its Grand Exchange, blood is spilled in its Colosseum, and secrets flow through its infamous Undermarket like water through sewers. Every guild maintains a presence here. Every nation has an embassy. And beneath it all, the criminal underworld operates the largest smuggling network on the continent.",
        culture = "A city of opportunity, excess, and danger. Everyone comes to Valdris Crossing eventually—merchants to trade, warriors to fight, thieves to steal, and scholars to learn. The city has no king; it is governed by a council of trade guilds. Law is enforced by hired mercenaries, and justice is for sale.",
        demographics = {human = 0.40, elf = 0.12, dwarf = 0.10, orc = 0.08, gnome = 0.08, goblin = 0.07, beast_folk = 0.10, lizard_folk = 0.05},
    },

    -- MEGA CITY: Aelindor - Integrated Elven Administrative City (Dominion-Controlled)
    {
        id = "aelindor",
        name = "Aelindor, the Eternal City",
        region = "holy_dominion",  -- Integrated into Dominion, not independent
        position = {x = 50, y = 45},
        level = 14,
        type = "mega_city",
        population = 1800,
        isAnchor = true,
        hasDistricts = true,
        hasUnderbelly = true,
        fixedNPCs = {
            "high_administrator_miriel",  -- Senior Elven Administrator (Dominion-appointed)
            "imperial_overseer_cassius",  -- Dominion representative
            "forest_warden_nighthollow",  -- City guard commander
            "chief_archivist_idril",      -- Preserves imperial records
            "blade_captain_silmarien",    -- Military liaison
        },
        mainQuests = {"administrative_crisis", "archive_secrets", "forest_corruption"},
        landmarks = {
            "the_living_spire",           -- Ancient tree tower (pre-war architecture)
            "the_reflecting_pool",        -- Natural pool (rumored magical, closely watched)
            "moonlit_gardens",            -- Gardens with bioluminescent plants
            "the_great_archive",          -- Imperial records repository
            "starfall_observatory",       -- Astronomical research center
            "memorial_grove",             -- Monument to lost Calidar
        },
        features = {
            "living_architecture",
            "imperial_administration",
            "elven_culture",
            "archive_city",
            "forest_integration",
        },
        description = "The largest Dominion-administered elven city, built among ancient trees predating the empire itself. While technically under imperial authority, Aelindor maintains significant cultural autonomy as the administrative hub for elven bureaucrats serving the Holy Dominion. Living architecture—walls of shaped wood, vine bridges, towers grown from ancient trunks—testifies to pre-war elven craft, now maintained under Dominion oversight. The Great Archive houses imperial records spanning centuries. The Reflecting Pool, a natural landmark, is rumored to possess strange properties but remains under Luminary Inquest monitoring.",
        culture = "A delicate balance between preservation and compliance. Elves here serve the Dominion as archivists, administrators, and record-keepers while quietly maintaining cultural traditions. High Administrator Miriel governs with imperial approval, answering to the Emperor. The city welcomes travelers cautiously—it is beautiful but watched, ancient but controlled.",
        demographics = {elf = 0.75, human = 0.10, gnome = 0.05, beast_folk = 0.05, dwarf = 0.03, orc = 0.02},
    },

    -- Ashen Archipelago Anchor Cave (Volcanic Descent to Hollow Earth)
    -- Located specifically on THE GREAT WESTERN ISLE (largest island in archipelago)
    {
        id = "volcanic_descent",
        name = "The Volcanic Descent",
        alternateName = "The Magma Throat",
        region = "great_western_isle",  -- Specifically on Great Western Isle
        parentRegion = "ashen_archipelago",  -- Part of archipelago chain
        position = {x = -180, y = 30},  -- Central volcano on Great Western Isle
        level = 25,  -- Extremely dangerous
        type = "anchor_cave",  -- Special dungeon type - not a town
        dungeonType = "volcanic_breach",
        floors = 30,  -- Deepest anchor dungeon in the game
        population = 0,  -- No permanent population - it's a dungeon
        isAnchor = true,
        isDungeon = true,  -- Special flag for anchor dungeons
        fixedNPCs = {"fire_elemental_guardian", "mad_volcanologist_ignis", "exile_smith_magmara"},
        mainQuests = {"descent_into_fire", "hollow_earth_discovery"},
        landmarks = {
            "obsidian_gateway",
            "lava_falls_chamber",
            "ancient_dwarf_workings",
            "breach_point_omega",  -- Floor 30
        },
        description = "A massive volcanic tube descending through the heart of the archipelago's central volcano. Ancient dwarven excavations show evidence of deep mining operations that were abandoned centuries ago. The walls glow with magma heat, and the air shimmers with sulfurous fumes. Local legends speak of 'the world beneath the world,' and expeditions into the deeper levels have reported impossible geological phenomena—caverns that should not exist, echoing sounds from impossibly far below, and heat that intensifies rather than diminishes. Floor 30 opens into something that defies surface understanding: the Hollow Earth itself, specifically breaching into the Deep Dwarven Realm or the Magma Caverns.",
        features = {
            "volcanic_environment",
            "extreme_heat",
            "lava_hazards",
            "ancient_dwarf_ruins",
            "guaranteed_hollow_breach",  -- 100% breach on floor 30
        },
        floorThemes = {
            [1] = "Surface volcanic caves - obsidian and cooling lava",
            [5] = "Active lava tubes - magma rivers",
            [10] = "Abandoned dwarven mine works - ancient tools left behind",
            [15] = "Transition zone - geology becomes impossible",
            [20] = "Deep heat - reality begins to warp",
            [25] = "Pre-breach zone - echoing sounds from below",
            [30] = "HOLLOW EARTH BREACH - opens into Deep Dwarven Realm or Magma Caverns",
        },
        breachProbability = {
            [30] = 1.0,  -- 100% guaranteed on floor 30
        },
        culture = "A place of pilgrimage for those seeking forbidden knowledge. The mad volcanologist Ignis maintains a small research camp at the entrance, obsessed with proving his theory of 'thermal inversion layers' and 'impossible caverns.' He's right, but nobody believes him.",
        secrets = {
            "Ancient dwarves dug too deep and found the hollow earth centuries ago",
            "The volcano is actually a natural chimney connecting surface to hollow",
            "Deep Dwarves still use these passages but avoid surface contact",
        },
        accessibility = "Extreme. Requires crossing the Western Ocean to reach archipelago, then surviving 30 floors of volcanic hell.",
        imperialKnowledge = "None. Empire doesn't know this place exists.",
    },
}

-- ============================================================================
--                         CHUNK STATE
-- ============================================================================

local chunkState = {
    loadedChunks = {},      -- Currently loaded chunks
    visitedChunks = {},     -- Chunks player has visited (saved state)
    worldSeed = nil,        -- World generation seed
    anchorTownsGenerated = false,
}

-- ============================================================================
--                      UTILITY FUNCTIONS
-- ============================================================================

-- Seeded random utilities (shared via seedrandom.lua)
local SeedRNG = require("seedrandom")
local function seededRandom(seed) return SeedRNG.hash(seed) end
local function combineSeed(seed1, seed2, seed3) return SeedRNG.combineSeed(seed1, seed2, seed3) end

-- Get chunk coordinates from tile coordinates
local function getChunkCoords(tileX, tileY)
    return math.floor(tileX / CHUNK_SIZE), math.floor(tileY / CHUNK_SIZE)
end

-- Get tile coordinates within a chunk
local function getLocalCoords(tileX, tileY)
    local chunkX, chunkY = getChunkCoords(tileX, tileY)
    return tileX - chunkX * CHUNK_SIZE, tileY - chunkY * CHUNK_SIZE
end

-- Get chunk key for storage
local function getChunkKey(chunkX, chunkY)
    return chunkX .. "," .. chunkY
end

-- ============================================================================
--                      REGION DETECTION
-- ============================================================================

-- Determine which region a tile belongs to
local function getRegionAt(tileX, tileY)
    -- LAYER CHECK FIRST: Determine if we're in surface or hollow earth
    local layer = WorldGen.getLayer(tileY)

    -- If in hollow earth layer, check hollow earth regions first
    if layer == LAYERS.HOLLOW then
        -- Check all hollow earth regions (bounded regions only)
        for id, region in pairs(REGIONS) do
            if region.layer == LAYERS.HOLLOW and region.bounds then
                local b = region.bounds
                if tileX >= b.x1 and tileX <= b.x2 and tileY >= b.y1 and tileY <= b.y2 then
                    return region, nil
                end
            end
        end
        -- Default hollow earth region if not in specific bounds
        return REGIONS.hollow_storm_caverns, nil  -- Storm Caverns as default hollow earth
    end

    -- SURFACE LAYER: Check infinite regions FIRST (fastest - simple comparisons, most common at world edges)
    -- Ordered by specificity: most specific checks first, then general

    -- FAR WEST: Check for Great Western Isle and Ashen Archipelago
    if tileX < -200 then
        -- Great Western Isle (distant continent)
        if tileY >= 0 and tileY <= 60 then
            return REGIONS.great_western_isle, nil
        end
        -- Beyond western isle = more western ocean
        return REGIONS.western_ocean, nil

    elseif tileX < -150 then
        -- Ashen Archipelago (volcanic islands) - bounded region
        if tileY >= 10 and tileY <= 50 then
            return REGIONS.ashen_archipelago, nil
        end
        -- Outside archipelago bounds = western ocean
        return REGIONS.western_ocean, nil

    elseif tileX < -100 then
        -- Western Ocean (Outer Waters)
        return REGIONS.western_ocean, nil

    -- EXTREME NORTH: Northern Tundra Continent (connects back to south - circumnavigation route)
    elseif tileY < -120 then
        return REGIONS.northern_tundra_continent, nil

    -- FAR NORTH: Check for Frostbound Reach island and Northern Seas
    elseif tileY < -45 then
        -- Check if within Frostbound Reach island bounds
        if tileX >= 10 and tileX <= 60 and tileY >= -100 and tileY <= -50 then
            return REGIONS.frostbound_reach, nil
        end
        -- Outside island = frozen seas
        return REGIONS.northern_seas, nil

    -- NORTH: Great Endless Desert (massive but bounded desert continent)
    elseif tileY < 0 then
        -- Check if within desert continent bounds
        if tileX >= -50 and tileX <= 100 then
            return REGIONS.great_endless_desert, nil
        end
        -- Outside desert bounds = ocean
        return REGIONS.northern_seas, nil  -- Waters around the desert

    -- WEST: Scorched Sands (transitions to Western Ocean)
    elseif tileX < 0 then
        return REGIONS.scorched_sands, nil

    -- CIRCUMPOLAR: Polar Ocean (encircling sea connects to north - CIRCUMNAVIGATION ROUTE)
    elseif tileY >= 350 then
        return REGIONS.polar_ocean, nil

    -- EXTREME SOUTH: Southern Tundra (polar wastes)
    elseif tileY >= 250 and tileY < 350 then
        return REGIONS.southern_tundra, nil

    -- FAR SOUTH: Southern Ocean (Sunless Sea beyond Calidar)
    elseif tileY >= 80 and tileY < 250 then
        return REGIONS.southern_ocean, nil

    -- FAR EAST: Shimmering Sea (infinite ocean)
    elseif tileX >= 150 then
        return REGIONS.shimmering_sea, nil
    end

    -- Check bounded regions (slower - requires bounds checking)
    -- Ordered by likelihood: main continent, then special regions
    local boundedRegions = {
        REGIONS.main_continent,
        REGIONS.wastes_of_calidar,  -- Glass desert (bounded for proper historical size)
        REGIONS.great_endless_desert,  -- Desert continent (bounded, connects east-west)
        REGIONS.frostbound_reach,  -- Large frozen island far north
        REGIONS.northern_tundra_continent,  -- Continent-sized tundra (circumnavigation route)
        REGIONS.northern_seas,  -- Frozen waters around Frostbound
        REGIONS.gnomish_isles,
        REGIONS.southern_ocean,  -- Bounded ocean beyond Wastes
        REGIONS.southern_tundra,  -- Bounded tundra beyond ocean
        REGIONS.ashen_archipelago,  -- Western volcanic islands
        REGIONS.great_western_isle,  -- Western continent
        REGIONS.silver_seas,
    }

    for _, region in ipairs(boundedRegions) do
        if region.bounds then
            local b = region.bounds
            if tileX >= b.x1 and tileX <= b.x2 and tileY >= b.y1 and tileY <= b.y2 then
                -- Check subregions
                if region.subregions then
                    for _, sub in ipairs(region.subregions) do
                        local sb = sub.bounds
                        if tileX >= sb.x1 and tileX <= sb.x2 and tileY >= sb.y1 and tileY <= sb.y2 then
                            return region, sub
                        end
                    end
                end
                return region, nil
            end
        end
    end

    -- Default to ocean for gaps (Silver Seas between continent and isles)
    return REGIONS.silver_seas, nil
end

-- ============================================================================
--                      TERRAIN GENERATION
-- ============================================================================

-- Generate dungeon type based on region
local function generateDungeonType(regionId, seed)
    local weights = REGION_DUNGEON_WEIGHTS[regionId] or {}
    local totalWeight = 0
    local weightedTypes = {}

    -- Calculate weighted probabilities
    for _, dungeonType in ipairs(DUNGEON_TYPES) do
        local modifier = weights[dungeonType.id] or 1.0
        local weight = dungeonType.baseWeight * modifier
        totalWeight = totalWeight + weight
        table.insert(weightedTypes, {
            id = dungeonType.id,
            name = dungeonType.name,
            weight = weight,
        })
    end

    -- Roll for dungeon type
    local roll = seededRandom(seed) * totalWeight
    local cumulative = 0

    for _, wt in ipairs(weightedTypes) do
        cumulative = cumulative + wt.weight
        if roll < cumulative then
            return wt.id, wt.name
        end
    end

    -- Default to standard dungeon
    return "dungeon", "Dungeon"
end

-- Generate dungeon data for a dungeon tile
local function generateDungeonData(tileX, tileY, regionId, seed)
    local dungeonSeed = combineSeed(seed, tileX * 31, tileY * 37)
    local dungeonTypeId, dungeonTypeName = generateDungeonType(regionId, dungeonSeed)

    -- Generate dungeon level based on distance from center (35, 42 = Havenbrook)
    local distFromStart = math.abs(tileX - 35) + math.abs(tileY - 42)
    local baseLevel = math.max(1, math.floor(distFromStart / 4))

    -- Vampire dens and crypts tend to be harder
    if dungeonTypeId == "vampire_den" or dungeonTypeId == "crypt" then
        baseLevel = baseLevel + math.floor(seededRandom(dungeonSeed + 1) * 3) + 1
    end

    -- Lich lairs are extremely dangerous - minimum level 10
    if dungeonTypeId == "lich_lair" then
        baseLevel = math.max(10, baseLevel + 5)
    end

    -- Generate floor count (3-7 floors, harder dungeons have more)
    local floorCount = 3 + math.floor(seededRandom(dungeonSeed + 2) * 3)
    if dungeonTypeId == "vampire_den" then
        floorCount = floorCount + 1  -- Vampire dens are deeper
    end

    -- Lich lairs are massive - 8-12 floors as per LICH_LAIR_CONFIG
    if dungeonTypeId == "lich_lair" then
        floorCount = LICH_LAIR_CONFIG.minFloors + math.floor(seededRandom(dungeonSeed + 5) * (LICH_LAIR_CONFIG.maxFloors - LICH_LAIR_CONFIG.minFloors + 1))
    end

    -- Generate unique dungeon name
    local prefixes = {
        dungeon = {"Dark", "Ancient", "Forgotten", "Cursed", "Shadow", "Lost"},
        cave = {"Deep", "Crystal", "Echo", "Spider", "Bear", "Wind"},
        mine = {"Abandoned", "Collapsed", "Gold", "Iron", "Dark", "Deep"},
        vampire_den = {"Blood", "Night", "Crimson", "Shadow", "Dread", "Eternal"},
        crypt = {"Ancient", "Forgotten", "Cursed", "Silent", "Bone", "Death"},
        lich_lair = {"Doomed", "Blighted", "Eternal", "Dread", "Soul", "Unholy"},
    }
    local suffixes = {
        dungeon = {"Depths", "Keep", "Fortress", "Halls", "Prison", "Dungeon"},
        cave = {"Cavern", "Grotto", "Hollow", "Lair", "Den", "Caves"},
        mine = {"Mine", "Tunnels", "Shaft", "Excavation", "Pit", "Works"},
        vampire_den = {"Den", "Lair", "Crypt", "Manor", "Sanctum", "Tomb"},
        crypt = {"Crypt", "Tomb", "Mausoleum", "Catacomb", "Sepulcher", "Vault"},
        lich_lair = {"Citadel", "Necropolis", "Domain", "Throne", "Sanctum", "Fortress"},
    }

    local prefix = prefixes[dungeonTypeId] or prefixes.dungeon
    local suffix = suffixes[dungeonTypeId] or suffixes.dungeon
    local nameIndex1 = 1 + (math.floor(seededRandom(dungeonSeed + 3) * #prefix) % #prefix)
    local nameIndex2 = 1 + (math.floor(seededRandom(dungeonSeed + 4) * #suffix) % #suffix)
    local dungeonName = prefix[nameIndex1] .. " " .. suffix[nameIndex2]

    local dungeonData = {
        id = "dungeon_" .. tileX .. "_" .. tileY,
        name = dungeonName,
        type = dungeonTypeId,
        typeName = dungeonTypeName,
        level = baseLevel,
        floors = floorCount,
        x = tileX,
        y = tileY,
        cleared = false,
        bossDefeated = false,
        discovered = false,
    }

    -- Lich lairs have additional properties for corruption and world threat
    if dungeonTypeId == "lich_lair" then
        dungeonData.isLichLair = true
        dungeonData.corruptionRadius = LICH_LAIR_CONFIG.corruptionRadius
        dungeonData.blightSpreadRate = LICH_LAIR_CONFIG.blightSpreadRate
        dungeonData.undeadPatrolRadius = LICH_LAIR_CONFIG.undeadPatrolRadius
        dungeonData.lichActive = true  -- The lich is still alive and active
        dungeonData.corruptedTiles = {}  -- Track which tiles are corrupted
        dungeonData.worldThreatLevel = math.floor(baseLevel / 2)  -- How much this lair threatens the world
    end

    return dungeonData
end

-- Generate terrain type for a specific tile
local function generateTerrain(tileX, tileY, seed)
    local region, subregion = getRegionAt(tileX, tileY)
    local tileSeed = combineSeed(seed, tileX, tileY)
    local roll = seededRandom(tileSeed)

    -- Safety check for nil region (should not happen but defensive)
    if not region then
        return "grass", nil, "unknown"
    end

    -- Use subregion if available, otherwise region
    local source = subregion or region
    local regionId = (subregion and subregion.id) or region.id

    -- Check for sparsity (for infinite regions)
    if region.sparsity then
        local sparsityRoll = seededRandom(tileSeed + 1)
        if sparsityRoll < region.sparsity then
            return source.terrain or "grass", nil, regionId
        end
    end

    -- Roll for terrain type
    local weight = source.terrainWeight or 0.5
    if roll < weight then
        local terrain = source.terrain or "grass"
        if terrain == "dungeon" then
            local dungeonData = generateDungeonData(tileX, tileY, regionId, tileSeed)
            return "dungeon", dungeonData, regionId
        end
        return terrain, nil, regionId
    end

    -- Roll for alternate terrain
    local altRoll = seededRandom(tileSeed + 2)
    local cumulative = 0

    if source.altTerrain then
        -- Sort keys for deterministic iteration (pairs() order is non-deterministic)
        local sortedKeys = {}
        for terrainType, _ in pairs(source.altTerrain) do
            sortedKeys[#sortedKeys + 1] = terrainType
        end
        table.sort(sortedKeys)
        for _, terrainType in ipairs(sortedKeys) do
            local chance = source.altTerrain[terrainType]
            cumulative = cumulative + chance
            if altRoll < cumulative then
                if terrainType == "dungeon" then
                    local dungeonData = generateDungeonData(tileX, tileY, regionId, tileSeed)
                    return "dungeon", dungeonData, regionId
                end
                return terrainType, nil, regionId
            end
        end
    end

    return source.terrain or "grass", nil, regionId
end

-- ============================================================================
--                      CHUNK GENERATION
-- ============================================================================

-- Generate a single chunk
local function generateChunk(chunkX, chunkY, worldSeed)
    local chunk = {
        x = chunkX,
        y = chunkY,
        tiles = {},
        structures = {},
        dungeons = {},  -- Track dungeons in this chunk
        generated = true,
        modified = false,
    }

    local chunkSeed = combineSeed(worldSeed, chunkX, chunkY)

    -- Generate tiles
    for localY = 0, CHUNK_SIZE - 1 do
        chunk.tiles[localY] = {}
        for localX = 0, CHUNK_SIZE - 1 do
            local tileX = chunkX * CHUNK_SIZE + localX
            local tileY = chunkY * CHUNK_SIZE + localY

            local terrainType, dungeonData, regionId = generateTerrain(tileX, tileY, chunkSeed)

            local tile = {
                type = terrainType,
                explored = false,
                town = nil,
                x = tileX,
                y = tileY,
                region = regionId,
            }

            -- Add dungeon data if this is a dungeon tile
            if terrainType == "dungeon" and dungeonData then
                tile.dungeon = dungeonData
                table.insert(chunk.dungeons, dungeonData)
            end

            chunk.tiles[localY][localX] = tile
        end
    end

    -- Post-processing: Convert deep ocean tiles near land to coastal/shallow water
    local WATER_TYPES = {water = true, deep_ocean = true, shallow_water = true, coastal = true, reef = true, whirlpool = true, shipwreck = true, ocean_cave = true}
    local LAND_TYPES = {grass = true, forest = true, mountain = true, swamp = true, desert = true, town = true, dungeon = true, ruins = true,
                        sand_dunes = true, glass_desert = true, salt_flats = true, desert_canyon = true, desert_oasis = true, desert_cave = true,
                        obsidian_field = true, crystal_formations = true, badlands = true, stone_pillars = true, desert_settlement = true, ice = true}

    for localY = 0, CHUNK_SIZE - 1 do
        for localX = 0, CHUNK_SIZE - 1 do
            local tile = chunk.tiles[localY][localX]
            if tile.type == "deep_ocean" or tile.type == "water" then
                -- Check if any adjacent tile is land (within this chunk)
                local adjacentLand = false
                for dy = -2, 2 do
                    for dx = -2, 2 do
                        if dy ~= 0 or dx ~= 0 then
                            local ny, nx = localY + dy, localX + dx
                            if ny >= 0 and ny < CHUNK_SIZE and nx >= 0 and nx < CHUNK_SIZE then
                                local neighbor = chunk.tiles[ny][nx]
                                if neighbor and LAND_TYPES[neighbor.type] then
                                    adjacentLand = true
                                    break
                                end
                            end
                        end
                    end
                    if adjacentLand then break end
                end

                if adjacentLand then
                    -- Immediate neighbors get coastal
                    local immediateNeighbor = false
                    for dy = -1, 1 do
                        for dx = -1, 1 do
                            if dy ~= 0 or dx ~= 0 then
                                local ny, nx = localY + dy, localX + dx
                                if ny >= 0 and ny < CHUNK_SIZE and nx >= 0 and nx < CHUNK_SIZE then
                                    local neighbor = chunk.tiles[ny][nx]
                                    if neighbor and LAND_TYPES[neighbor.type] then
                                        immediateNeighbor = true
                                    end
                                end
                            end
                        end
                    end
                    if immediateNeighbor then
                        tile.type = "coastal"
                    else
                        tile.type = "shallow_water"
                    end
                end
            end
        end
    end

    return chunk
end

-- ============================================================================
--                      ANCHOR TOWN PLACEMENT
-- ============================================================================

-- Place all anchor towns in their fixed positions
local function placeAnchorTowns(worldSeed)
    if chunkState.anchorTownsGenerated then
        return
    end

    for _, anchorTown in ipairs(ANCHOR_TOWNS) do
        local pos = anchorTown.position
        local chunkX, chunkY = getChunkCoords(pos.x, pos.y)
        local chunkKey = getChunkKey(chunkX, chunkY)

        -- Ensure chunk exists in visited state
        if not chunkState.visitedChunks[chunkKey] then
            chunkState.visitedChunks[chunkKey] = {
                anchorTowns = {},
            }
        end

        -- Store anchor town reference
        local localX, localY = getLocalCoords(pos.x, pos.y)
        table.insert(chunkState.visitedChunks[chunkKey].anchorTowns, {
            townData = anchorTown,
            localX = localX,
            localY = localY,
        })
    end

    chunkState.anchorTownsGenerated = true
end

-- Apply anchor towns to a loaded chunk
local function applyAnchorTowns(chunk)
    local chunkKey = getChunkKey(chunk.x, chunk.y)
    local visited = chunkState.visitedChunks[chunkKey]

    if visited and visited.anchorTowns then
        for _, anchor in ipairs(visited.anchorTowns) do
            local tile = chunk.tiles[anchor.localY] and chunk.tiles[anchor.localY][anchor.localX]
            if tile then
                tile.type = "town"
                tile.town = anchor.townData
                tile.isAnchorTown = true

                -- Place water tiles around harbor/coastal towns
                local features = anchor.townData.features or {}
                local isHarbor = false
                for _, f in ipairs(features) do
                    if f == "harbor" or f == "port" or f == "coastal" then
                        isHarbor = true
                        break
                    end
                end
                if isHarbor then
                    -- Place water to the south and east of harbor towns
                    local waterOffsets = {{0,1},{1,1},{-1,1},{0,2},{1,0},{2,0},{1,2}}
                    for _, off in ipairs(waterOffsets) do
                        local wx = anchor.localX + off[1]
                        local wy = anchor.localY + off[2]
                        if chunk.tiles[wy] and chunk.tiles[wy][wx] then
                            local wt = chunk.tiles[wy][wx]
                            if wt.type ~= "town" and not wt.isAnchorTown then
                                wt.type = "water"
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ============================================================================
--                      CHUNK LOADING/UNLOADING
-- ============================================================================

-- Load a chunk (generate or restore from saved state)
function WorldGen.loadChunk(chunkX, chunkY)
    local chunkKey = getChunkKey(chunkX, chunkY)

    -- Already loaded?
    if chunkState.loadedChunks[chunkKey] then
        return chunkState.loadedChunks[chunkKey]
    end

    local chunk
    local visited = chunkState.visitedChunks[chunkKey]

    -- Always regenerate the chunk (deterministic from seed)
    chunk = generateChunk(chunkX, chunkY, chunkState.worldSeed)

    -- Apply saved modifications (explored tiles, towns, etc.)
    if visited and visited.modifiedTiles then
        for y, row in pairs(visited.modifiedTiles) do
            for x, savedTile in pairs(row) do
                if chunk.tiles[y] and chunk.tiles[y][x] then
                    local tile = chunk.tiles[y][x]
                    if savedTile.explored then tile.explored = true end
                    if savedTile.town then tile.town = savedTile.town; tile.type = "town" end
                    if savedTile.property then tile.property = savedTile.property end
                    if savedTile.settlement then tile.settlement = savedTile.settlement end
                end
            end
        end
    end

    -- Apply anchor towns (these override generated terrain)
    applyAnchorTowns(chunk)

    chunkState.loadedChunks[chunkKey] = chunk
    return chunk
end

-- Unload a chunk (save only modified tile data, not full chunk)
function WorldGen.unloadChunk(chunkX, chunkY)
    local chunkKey = getChunkKey(chunkX, chunkY)
    local chunk = chunkState.loadedChunks[chunkKey]

    if chunk and chunk.modified then
        -- Save only modified tile data (explored state, towns, etc.)
        -- This is more memory efficient than saving the full chunk
        if not chunkState.visitedChunks[chunkKey] then
            chunkState.visitedChunks[chunkKey] = {}
        end

        -- Extract only essential modified data
        local modifiedTiles = {}
        for y = 0, CHUNK_SIZE - 1 do
            if chunk.tiles[y] then
                for x = 0, CHUNK_SIZE - 1 do
                    local tile = chunk.tiles[y][x]
                    if tile and (tile.explored or tile.town or tile.property or tile.settlement) then
                        if not modifiedTiles[y] then modifiedTiles[y] = {} end
                        modifiedTiles[y][x] = {
                            explored = tile.explored,
                            town = tile.town,  -- Town data is important to preserve
                            property = tile.property,
                            settlement = tile.settlement,
                        }
                    end
                end
            end
        end

        chunkState.visitedChunks[chunkKey].modifiedTiles = modifiedTiles
        chunkState.visitedChunks[chunkKey].savedChunk = nil  -- Clear full chunk to save memory
    end

    chunkState.loadedChunks[chunkKey] = nil
end

-- Track update calls for periodic cleanup
local updateCallCount = 0

-- Update loaded chunks based on player position
function WorldGen.updateLoadedChunks(playerTileX, playerTileY)
    local playerChunkX, playerChunkY = getChunkCoords(playerTileX, playerTileY)

    -- Determine which chunks should be loaded
    local shouldBeLoaded = {}
    for dy = -LOAD_RADIUS, LOAD_RADIUS do
        for dx = -LOAD_RADIUS, LOAD_RADIUS do
            local cx, cy = playerChunkX + dx, playerChunkY + dy
            local key = getChunkKey(cx, cy)
            shouldBeLoaded[key] = {x = cx, y = cy}
        end
    end

    -- Unload chunks that are too far
    -- Collect keys to remove first to avoid concurrent modification
    local chunksToUnload = {}
    for key, chunk in pairs(chunkState.loadedChunks) do
        if not shouldBeLoaded[key] then
            table.insert(chunksToUnload, {x = chunk.x, y = chunk.y})
        end
    end
    -- Now unload them
    for _, coords in ipairs(chunksToUnload) do
        WorldGen.unloadChunk(coords.x, coords.y)
    end

    -- Load chunks that should be loaded
    for key, coords in pairs(shouldBeLoaded) do
        if not chunkState.loadedChunks[key] then
            WorldGen.loadChunk(coords.x, coords.y)
        end
    end

    -- Periodic memory cleanup (every 100 updates)
    updateCallCount = updateCallCount + 1
    if updateCallCount >= 100 then
        WorldGen.cleanupVisitedChunks(playerTileX, playerTileY)
        updateCallCount = 0
    end
end

-- ============================================================================
--                      TILE ACCESS
-- ============================================================================

-- Get a tile at world coordinates
function WorldGen.getTile(tileX, tileY)
    -- Validate input coordinates
    if tileX == nil or tileY == nil then
        print("WorldGen.getTile: nil coordinates provided")
        return nil
    end

    -- Ensure coordinates are integers
    tileX = math.floor(tileX)
    tileY = math.floor(tileY)

    local chunkX, chunkY = getChunkCoords(tileX, tileY)
    local localX, localY = getLocalCoords(tileX, tileY)

    -- Validate local coordinates are in expected range (0 to CHUNK_SIZE-1)
    if localX < 0 or localX >= CHUNK_SIZE or localY < 0 or localY >= CHUNK_SIZE then
        print("WorldGen.getTile: Invalid local coordinates", localX, localY, "for tile", tileX, tileY, "chunk", chunkX, chunkY)
        return nil
    end

    local chunkKey = getChunkKey(chunkX, chunkY)

    local chunk = chunkState.loadedChunks[chunkKey]
    if not chunk then
        -- Chunk not loaded, load it
        chunk = WorldGen.loadChunk(chunkX, chunkY)
        if not chunk then
            print("WorldGen.getTile: Failed to load chunk", chunkX, chunkY, "for tile", tileX, tileY)
            return nil
        end
    end

    -- Validate chunk structure
    if not chunk.tiles then
        print("WorldGen.getTile: Chunk has no tiles array", chunkX, chunkY)
        return nil
    end

    if not chunk.tiles[localY] then
        print("WorldGen.getTile: Chunk row missing", chunkX, chunkY, localY)
        return nil
    end

    local tile = chunk.tiles[localY][localX]
    if not tile then
        print("WorldGen.getTile: Tile missing at", tileX, tileY, "local", localX, localY, "chunk", chunkX, chunkY)
        return nil
    end

    return tile
end

-- Set a tile at world coordinates
function WorldGen.setTile(tileX, tileY, tileData)
    -- Validate input
    if tileX == nil or tileY == nil or tileData == nil then
        print("WorldGen.setTile: Invalid parameters")
        return false
    end

    -- Ensure coordinates are integers
    tileX = math.floor(tileX)
    tileY = math.floor(tileY)

    local chunkX, chunkY = getChunkCoords(tileX, tileY)
    local localX, localY = getLocalCoords(tileX, tileY)

    -- Validate local coordinates
    if localX < 0 or localX >= CHUNK_SIZE or localY < 0 or localY >= CHUNK_SIZE then
        print("WorldGen.setTile: Invalid local coordinates", localX, localY, "for tile", tileX, tileY)
        return false
    end

    local chunkKey = getChunkKey(chunkX, chunkY)

    local chunk = chunkState.loadedChunks[chunkKey]
    if not chunk then
        chunk = WorldGen.loadChunk(chunkX, chunkY)
        if not chunk then
            print("WorldGen.setTile: Failed to load chunk", chunkX, chunkY)
            return false
        end
    end

    -- Validate chunk structure
    if not chunk.tiles or not chunk.tiles[localY] then
        print("WorldGen.setTile: Invalid chunk structure", chunkX, chunkY)
        return false
    end

    chunk.tiles[localY][localX] = tileData
    chunk.modified = true
    return true
end

-- Mark a tile as explored
function WorldGen.exploreTile(tileX, tileY)
    local tile = WorldGen.getTile(tileX, tileY)
    if tile then
        tile.explored = true

        -- Mark chunk as modified
        local chunkX, chunkY = getChunkCoords(tileX, tileY)
        local chunkKey = getChunkKey(chunkX, chunkY)
        if chunkState.loadedChunks[chunkKey] then
            chunkState.loadedChunks[chunkKey].modified = true
        end
    end
end

-- ============================================================================
--                      INITIALIZATION
-- ============================================================================

-- Initialize the world with a seed
function WorldGen.init(seed)
    chunkState.worldSeed = seed or os.time()
    chunkState.loadedChunks = {}
    chunkState.visitedChunks = {}
    chunkState.anchorTownsGenerated = false

    -- Place anchor towns
    placeAnchorTowns(chunkState.worldSeed)

    return chunkState.worldSeed
end

-- Get starting position (Havenbrook village)
function WorldGen.getStartingPosition()
    for _, town in ipairs(ANCHOR_TOWNS) do
        if town.isStartingTown then
            return town.position.x, town.position.y, town
        end
    end
    -- Fallback to center of Holy Dominion
    return 35, 42, nil
end

-- ============================================================================
--                      GETTERS
-- ============================================================================

function WorldGen.getAnchorTowns()
    return ANCHOR_TOWNS
end

function WorldGen.getRegions()
    return REGIONS
end

function WorldGen.getWorldSeed()
    return chunkState.worldSeed
end

function WorldGen.getLoadedChunks()
    return chunkState.loadedChunks
end

function WorldGen.getChunkSize()
    return CHUNK_SIZE
end

function WorldGen.getRegionAt(tileX, tileY)
    return getRegionAt(tileX, tileY)
end

function WorldGen.getDungeonTypes()
    return DUNGEON_TYPES
end

-- Get all dungeons in currently loaded chunks
function WorldGen.getLoadedDungeons()
    local dungeons = {}
    for _, chunk in pairs(chunkState.loadedChunks) do
        if chunk.dungeons then
            for _, dungeon in ipairs(chunk.dungeons) do
                table.insert(dungeons, dungeon)
            end
        end
    end
    return dungeons
end

-- Get dungeon at specific coordinates
function WorldGen.getDungeonAt(tileX, tileY)
    local tile = WorldGen.getTile(tileX, tileY)
    if tile and tile.type == "dungeon" then
        return tile.dungeon
    end
    return nil
end

-- Mark dungeon as cleared
function WorldGen.markDungeonCleared(tileX, tileY)
    local tile = WorldGen.getTile(tileX, tileY)
    if tile and tile.dungeon then
        tile.dungeon.cleared = true
        tile.dungeon.bossDefeated = true

        -- Mark chunk as modified
        local chunkX, chunkY = getChunkCoords(tileX, tileY)
        local chunkKey = getChunkKey(chunkX, chunkY)
        if chunkState.loadedChunks[chunkKey] then
            chunkState.loadedChunks[chunkKey].modified = true
        end
        return true
    end
    return false
end

-- Mark dungeon as discovered
function WorldGen.markDungeonDiscovered(tileX, tileY)
    local tile = WorldGen.getTile(tileX, tileY)
    if tile and tile.dungeon then
        tile.dungeon.discovered = true

        -- Mark chunk as modified
        local chunkX, chunkY = getChunkCoords(tileX, tileY)
        local chunkKey = getChunkKey(chunkX, chunkY)
        if chunkState.loadedChunks[chunkKey] then
            chunkState.loadedChunks[chunkKey].modified = true
        end

        -- Add to auto-travel system
        local AutoTravel = _G.AutoTravel or require("auto_travel")
        if AutoTravel then
            local region = getRegionAt(tileX, tileY)
            local layer = WorldGen.getLayer(tileY)

            AutoTravel.discoverLocation({
                id = tile.dungeon.id,
                name = tile.dungeon.name,
                type = tile.dungeon.type,
                x = tileX,
                y = tileY,
                layer = layer,
                discoveredBy = "exploration",
                region = region and region.name or "Unknown",
                description = string.format("Level %d %s with %d floors", tile.dungeon.level, tile.dungeon.typeName, tile.dungeon.floors),
            })
        end

        return true
    end
    return false
end

-- Get dungeons by type in loaded chunks
function WorldGen.getDungeonsByType(dungeonType)
    local dungeons = {}
    for _, chunk in pairs(chunkState.loadedChunks) do
        if chunk.dungeons then
            for _, dungeon in ipairs(chunk.dungeons) do
                if dungeon.type == dungeonType then
                    table.insert(dungeons, dungeon)
                end
            end
        end
    end
    return dungeons
end

-- Get region name at coordinates (public helper for auto-travel)
function WorldGen.getRegionNameAt(x, y)
    local region = getRegionAt(x, y)
    return region and region.name or "Unknown"
end

-- Get nearby dungeons within a radius
-- Ensures all chunks within the search radius are generated before searching
function WorldGen.getNearbyDungeons(centerX, centerY, radius)
    -- Determine which chunks fall within the search radius and ensure they are loaded
    local minChunkX, minChunkY = getChunkCoords(centerX - radius, centerY - radius)
    local maxChunkX, maxChunkY = getChunkCoords(centerX + radius, centerY + radius)

    for cx = minChunkX, maxChunkX do
        for cy = minChunkY, maxChunkY do
            WorldGen.loadChunk(cx, cy)
        end
    end

    local dungeons = {}
    for _, chunk in pairs(chunkState.loadedChunks) do
        if chunk.dungeons then
            for _, dungeon in ipairs(chunk.dungeons) do
                local dist = math.abs(dungeon.x - centerX) + math.abs(dungeon.y - centerY)
                if dist <= radius then
                    table.insert(dungeons, {dungeon = dungeon, distance = dist})
                end
            end
        end
    end
    -- Sort by distance
    table.sort(dungeons, function(a, b) return a.distance < b.distance end)
    return dungeons
end

-- ============================================================================
--                      SAVE/LOAD
-- ============================================================================

function WorldGen.getSaveData()
    return {
        worldSeed = chunkState.worldSeed,
        visitedChunks = chunkState.visitedChunks,
        anchorTownsGenerated = chunkState.anchorTownsGenerated,
    }
end

function WorldGen.loadSaveData(data)
    if data then
        chunkState.worldSeed = data.worldSeed
        chunkState.visitedChunks = data.visitedChunks or {}
        chunkState.anchorTownsGenerated = data.anchorTownsGenerated or false
        chunkState.loadedChunks = {}
    end
end

-- ============================================================================
--                      DEBUG/INFO
-- ============================================================================

-- Maximum visited chunks to keep in memory (prevents unbounded growth)
local MAX_VISITED_CHUNKS = 500

-- Clean up old visited chunk data to limit memory usage
function WorldGen.cleanupVisitedChunks(playerTileX, playerTileY)
    local visitedCount = 0
    for _ in pairs(chunkState.visitedChunks) do
        visitedCount = visitedCount + 1
    end

    -- Only cleanup if we exceed the limit
    if visitedCount <= MAX_VISITED_CHUNKS then
        return 0
    end

    local playerChunkX, playerChunkY = getChunkCoords(playerTileX, playerTileY)

    -- Build list of chunks with distances
    local chunkList = {}
    for key, data in pairs(chunkState.visitedChunks) do
        -- Parse chunk coordinates from key
        local cx, cy = key:match("(-?%d+),(-?%d+)")
        cx, cy = tonumber(cx), tonumber(cy)
        if cx and cy then
            local dist = math.abs(cx - playerChunkX) + math.abs(cy - playerChunkY)
            table.insert(chunkList, {key = key, distance = dist, data = data})
        end
    end

    -- Sort by distance (farthest first)
    table.sort(chunkList, function(a, b) return a.distance > b.distance end)

    -- Remove farthest chunks until we're under the limit
    local removed = 0
    local targetCount = MAX_VISITED_CHUNKS * 0.8  -- Remove 20% to avoid frequent cleanups
    for i = 1, #chunkList do
        if visitedCount - removed <= targetCount then break end

        local chunk = chunkList[i]
        -- Don't remove chunks with important data (towns, properties)
        local hasImportant = false
        if chunk.data.modifiedTiles then
            for _, row in pairs(chunk.data.modifiedTiles) do
                for _, tile in pairs(row) do
                    if tile.town or tile.property or tile.settlement then
                        hasImportant = true
                        break
                    end
                end
                if hasImportant then break end
            end
        end

        if not hasImportant then
            chunkState.visitedChunks[chunk.key] = nil
            removed = removed + 1
        end
    end

    return removed
end

function WorldGen.getDebugInfo()
    local loadedCount = 0
    local loadedTiles = 0
    for _, chunk in pairs(chunkState.loadedChunks) do
        loadedCount = loadedCount + 1
        loadedTiles = loadedTiles + CHUNK_SIZE * CHUNK_SIZE
    end

    local visitedCount = 0
    local modifiedTileCount = 0
    for _, data in pairs(chunkState.visitedChunks) do
        visitedCount = visitedCount + 1
        if data.modifiedTiles then
            for _, row in pairs(data.modifiedTiles) do
                for _ in pairs(row) do
                    modifiedTileCount = modifiedTileCount + 1
                end
            end
        end
    end

    -- Rough memory estimate (bytes)
    -- Each loaded tile ~100 bytes, each modified tile entry ~50 bytes
    local estimatedMemoryKB = math.floor((loadedTiles * 100 + modifiedTileCount * 50) / 1024)

    return {
        seed = chunkState.worldSeed,
        loadedChunks = loadedCount,
        loadedTiles = loadedTiles,
        visitedChunks = visitedCount,
        modifiedTiles = modifiedTileCount,
        estimatedMemoryKB = estimatedMemoryKB,
        chunkSize = CHUNK_SIZE,
        loadRadius = LOAD_RADIUS,
        maxVisitedChunks = MAX_VISITED_CHUNKS,
    }
end

-- ============================================================================
--                      LICH LAIR CORRUPTION SYSTEM
-- ============================================================================

-- Track all known lich lairs for world state
local lichLairState = {
    activeLairs = {},      -- Active lich lairs by ID
    corruptedTiles = {},   -- Global map of corrupted tiles
    totalCorruption = 0,   -- World corruption level
    destroyedVillages = 0, -- Count of villages destroyed by lich corruption
    battleLog = {},        -- History of village battles
    holyIntervention = false, -- Whether Holy Capital has intervened
}

-- Lich battle configuration
local LICH_BATTLE_CONFIG = {
    baseHordeSize = 50,           -- Starting horde size per lich
    hordeGrowthPerDay = 5,        -- Horde grows each day
    hordePerCorruptedTile = 2,    -- Additional horde per corrupted tile
    villageDestroyThreshold = 3,  -- Villages destroyed before Holy Capital intervenes
    holyBattalionSize = 500,      -- Size of Holy Capital's army
    holyBattalionStrength = 1.5,  -- Combat multiplier for trained soldiers
    villagerStrength = 0.8,       -- Combat multiplier for villagers (untrained)
    undeadStrength = 1.0,         -- Combat multiplier for undead
    ruinsCorruptionChance = 0.3,  -- Chance for ruins to become new corruption point
    anchorCityMageBonus = 0.5,    -- Strength bonus from state-sanctioned mages at anchor cities
    capitalMageBonus = 0.8,       -- Extra bonus for capital cities (more mages)
}

-- Calculate lich horde size
local function getLichHordeSize(lichLair)
    local baseHorde = lichLair.hordeSize or LICH_BATTLE_CONFIG.baseHordeSize
    local corruptionBonus = 0

    -- Count corrupted tiles belonging to this lair
    for _, corruptData in pairs(lichLairState.corruptedTiles) do
        if corruptData.lichLairId == lichLair.id then
            corruptionBonus = corruptionBonus + LICH_BATTLE_CONFIG.hordePerCorruptedTile
        end
    end

    return baseHorde + corruptionBonus
end

-- Simulate a battle between village defenders and undead horde
local function simulateBattle(defenderCount, defenderStrength, attackerCount, attackerStrength)
    -- Combat power = count * strength * random factor
    local defenderPower = defenderCount * defenderStrength * (0.8 + math.random() * 0.4)
    local attackerPower = attackerCount * attackerStrength * (0.8 + math.random() * 0.4)

    local defenderWins = defenderPower > attackerPower

    -- Calculate casualties (losing side loses more)
    local powerRatio = defenderWins and (attackerPower / defenderPower) or (defenderPower / attackerPower)
    local winnerCasualties = math.floor(defenderWins and defenderCount * powerRatio * 0.3 or attackerCount * powerRatio * 0.3)
    local loserCasualties = defenderWins and attackerCount or defenderCount

    return {
        defenderWins = defenderWins,
        defenderCasualties = defenderWins and winnerCasualties or loserCasualties,
        attackerCasualties = defenderWins and loserCasualties or winnerCasualties,
        defenderSurvivors = defenderWins and (defenderCount - winnerCasualties) or 0,
        attackerSurvivors = defenderWins and 0 or (attackerCount - winnerCasualties),
    }
end

-- Get town population from tile data or anchor towns
local function getTownPopulation(tile, tileX, tileY)
    -- Check if it's an anchor town
    if tile.townData and tile.townData.population then
        return tile.townData.population
    end

    -- Check anchor towns list
    for _, anchorTown in ipairs(ANCHOR_TOWNS) do
        if anchorTown.position.x == tileX and anchorTown.position.y == tileY then
            return anchorTown.population or 100
        end
    end

    -- Default population based on town level
    local level = tile.townLevel or tile.level or 1
    return level * 50 + 50  -- Level 1 = 100, Level 5 = 300, etc.
end

-- Handle corruption attempting to spread to a town tile
local function attemptTownCorruption(tileX, tileY, lichLairId, tile)
    local lichLair = lichLairState.activeLairs[lichLairId]
    if not lichLair then return false end

    -- Get combatants
    local villagePopulation = getTownPopulation(tile, tileX, tileY)
    local hordeSize = getLichHordeSize(lichLair)

    -- Calculate defender strength with anchor city bonuses
    local defenderStrength = LICH_BATTLE_CONFIG.villagerStrength
    local isAnchorCity = tile.isAnchorTown or tile.isAnchor
    local isCapital = false
    local townName = (tile.townData and tile.townData.name) or tile.name or "Unknown Village"

    -- Check if this is an anchor city (state-sanctioned mages provide defense)
    if isAnchorCity then
        defenderStrength = defenderStrength + LICH_BATTLE_CONFIG.anchorCityMageBonus

        -- Check if it's a capital city (even more mages)
        for _, anchorTown in ipairs(ANCHOR_TOWNS) do
            if anchorTown.position.x == tileX and anchorTown.position.y == tileY then
                townName = anchorTown.name
                if anchorTown.type == "capital" or anchorTown.type == "mega_city" then
                    defenderStrength = defenderStrength + LICH_BATTLE_CONFIG.capitalMageBonus
                    isCapital = true
                end
                break
            end
        end
    end

    -- Simulate the battle
    local result = simulateBattle(
        villagePopulation,
        defenderStrength,
        hordeSize,
        LICH_BATTLE_CONFIG.undeadStrength
    )

    -- Log the battle
    local battleRecord = {
        day = _G.state and _G.state.daysPassed or 0,
        townName = townName,
        tileX = tileX,
        tileY = tileY,
        lichLairId = lichLairId,
        villagePopulation = villagePopulation,
        hordeSize = hordeSize,
        defenderWins = result.defenderWins,
        defenderCasualties = result.defenderCasualties,
        attackerCasualties = result.attackerCasualties,
        isAnchorCity = isAnchorCity,
        isCapital = isCapital,
        hadMageSupport = isAnchorCity,  -- Anchor cities have state mages
        defenderStrength = defenderStrength,
    }
    table.insert(lichLairState.battleLog, battleRecord)

    if result.defenderWins then
        -- Village wins - push back corruption, reduce horde
        lichLair.hordeSize = math.max(LICH_BATTLE_CONFIG.baseHordeSize,
            (lichLair.hordeSize or hordeSize) - result.attackerCasualties)

        -- Update village population (casualties from battle)
        if tile.townData then
            tile.townData.population = math.max(10, villagePopulation - result.defenderCasualties)
        end

        return false, battleRecord  -- Corruption blocked
    else
        -- Village falls - becomes ruins, dead join the horde
        tile.originalTerrain = "town"
        tile.type = "ruins"
        tile.wasVillage = true
        tile.destroyedBy = lichLairId
        tile.destroyedDay = _G.state and _G.state.daysPassed or 0
        tile.fallenpopulation = villagePopulation

        -- Dead villagers join the horde
        lichLair.hordeSize = (lichLair.hordeSize or hordeSize) + result.defenderCasualties

        -- Mark chunk as modified
        local chunkX, chunkY = getChunkCoords(tileX, tileY)
        local chunkKey = getChunkKey(chunkX, chunkY)
        if chunkState.loadedChunks[chunkKey] then
            chunkState.loadedChunks[chunkKey].modified = true
        end

        -- Track destroyed village
        lichLairState.destroyedVillages = lichLairState.destroyedVillages + 1

        -- Chance for ruins to become new corruption spreading point
        if math.random() < LICH_BATTLE_CONFIG.ruinsCorruptionChance then
            local tileKey = tileX .. "," .. tileY
            lichLairState.corruptedTiles[tileKey] = {
                x = tileX,
                y = tileY,
                lichLairId = lichLairId,
                level = 1,
                isSecondarySource = true,
            }
            tile.type = "corrupted"
            tile.corruptedBy = lichLairId
            tile.corruptionLevel = 1
            lichLairState.totalCorruption = lichLairState.totalCorruption + 1
        end

        return true, battleRecord  -- Village destroyed
    end
end

-- Corrupt a single tile (change its terrain to corrupted)
local function corruptTile(tileX, tileY, lichLairId)
    local tile = WorldGen.getTile(tileX, tileY)
    if not tile then return false end

    -- Already corrupted
    if tile.type == "corrupted" then
        return false
    end

    -- Town tiles trigger a battle instead of instant corruption
    if tile.type == "town" or tile.isAnchorTown then
        return attemptTownCorruption(tileX, tileY, lichLairId, tile)
    end

    -- LORE FIX: Water and ice block corruption (the dead cannot cross living waters)
    if tile.type == "water" or tile.type == "ice" or
       tile.type == "shallow_water" or tile.type == "deep_ocean" or
       tile.type == "coastal" or tile.type == "reef" or tile.type == "river" then
        return false
    end

    -- GAMEPLAY FIX: Protect dungeon entrances from being overwritten
    if tile.type == "dungeon" then
        return false
    end

    -- Store original terrain for restoration
    tile.originalTerrain = tile.originalTerrain or tile.type
    tile.type = "corrupted"
    tile.corruptedBy = lichLairId
    tile.corruptionLevel = 1

    -- Mark chunk as modified
    local chunkX, chunkY = getChunkCoords(tileX, tileY)
    local chunkKey = getChunkKey(chunkX, chunkY)
    if chunkState.loadedChunks[chunkKey] then
        chunkState.loadedChunks[chunkKey].modified = true
    end

    -- Track in global state
    local tileKey = tileX .. "," .. tileY
    lichLairState.corruptedTiles[tileKey] = {
        x = tileX,
        y = tileY,
        lichLairId = lichLairId,
        level = 1,
    }
    lichLairState.totalCorruption = lichLairState.totalCorruption + 1

    return true
end

-- Apply initial corruption around a lich lair
function WorldGen.applyLichLairCorruption(lichLairDungeon)
    if not lichLairDungeon or not lichLairDungeon.isLichLair then return end

    local centerX, centerY = lichLairDungeon.x, lichLairDungeon.y
    local radius = lichLairDungeon.corruptionRadius or LICH_LAIR_CONFIG.corruptionRadius

    -- Track this lair
    lichLairState.activeLairs[lichLairDungeon.id] = lichLairDungeon

    -- Corrupt tiles in radius (stronger near center)
    for dy = -radius, radius do
        for dx = -radius, radius do
            local dist = math.abs(dx) + math.abs(dy)
            if dist <= radius then
                local tileX, tileY = centerX + dx, centerY + dy
                -- Higher chance of corruption closer to center
                local corruptChance = 1.0 - (dist / (radius + 1))
                if math.random() < corruptChance then
                    corruptTile(tileX, tileY, lichLairDungeon.id)
                end
            end
        end
    end
end

-- Spread blight from active lich lairs (call this periodically, e.g., daily)
function WorldGen.spreadLichBlight()
    local battleResults = {}

    -- OPTIMIZATION: Distance-based lich dormancy
    -- Only spread corruption from liches within activity radius
    -- Distant liches remain dormant to prevent global tile iteration
    local ACTIVITY_RADIUS = 80  -- 5 chunks (400km radius)
    -- Use center of loaded chunks as player position estimate (gameState not accessible here)
    local playerX, playerY = 0, 0
    local foundPos = false
    if chunkState and chunkState.loadedChunks then
        for key, _ in pairs(chunkState.loadedChunks) do
            local cx, cy = key:match("(-?%d+),(-?%d+)")
            if cx then
                playerX = tonumber(cx) * CHUNK_SIZE + CHUNK_SIZE / 2
                playerY = tonumber(cy) * CHUNK_SIZE + CHUNK_SIZE / 2
                foundPos = true
                break
            end
        end
    end
    if not foundPos then ACTIVITY_RADIUS = 9999 end  -- No position known, process all liches

    local activeLichCount = 0
    local dormantLichCount = 0

    for lichId, lichLair in pairs(lichLairState.activeLairs) do
        if lichLair.lichActive then
            -- DISTANCE CULLING: Check if lich is within activity radius
            local lichDist = math.abs(lichLair.x - playerX) + math.abs(lichLair.y - playerY)

            if lichDist > ACTIVITY_RADIUS then
                -- Lich is dormant (too far from player)
                lichLair.dormant = true
                dormantLichCount = dormantLichCount + 1
                goto continue_lich
            end

            -- Lich is active
            lichLair.dormant = false
            activeLichCount = activeLichCount + 1

            -- Daily horde growth
            lichLair.hordeSize = (lichLair.hordeSize or LICH_BATTLE_CONFIG.baseHordeSize) +
                LICH_BATTLE_CONFIG.hordeGrowthPerDay

            local spreadRate = lichLair.blightSpreadRate or LICH_LAIR_CONFIG.blightSpreadRate

            -- Find all corrupted tiles belonging to this lair
            -- Collect tiles to spread from first to avoid concurrent modification
            local tilesToSpreadFrom = {}
            for tileKey, corruptData in pairs(lichLairState.corruptedTiles) do
                if corruptData.lichLairId == lichId then
                    table.insert(tilesToSpreadFrom, corruptData)
                end
            end

            -- Now spread from collected tiles
            for _, corruptData in ipairs(tilesToSpreadFrom) do
                -- Try to spread to adjacent tiles
                local dirs = {{0,1}, {0,-1}, {1,0}, {-1,0}}
                for _, dir in ipairs(dirs) do
                    if math.random() < spreadRate then
                        local newX = corruptData.x + dir[1]
                        local newY = corruptData.y + dir[2]

                        -- Check distance from lair center (secondary sources can spread further)
                        local distFromLair = math.abs(newX - lichLair.x) + math.abs(newY - lichLair.y)
                        local maxSpread = (lichLair.corruptionRadius or 5) * 2

                        -- Secondary corruption sources (fallen villages) can extend range
                        if corruptData.isSecondarySource then
                            maxSpread = maxSpread + 5
                        end

                        if distFromLair <= maxSpread then
                            local corrupted, battleRecord = corruptTile(newX, newY, lichId)
                            if battleRecord then
                                table.insert(battleResults, battleRecord)
                            end
                        end
                    end
                end
            end

        ::continue_lich::
        end
    end

    -- Performance logging (can be disabled in production)
    if dormantLichCount > 0 then
        -- print("Lich blight spread: " .. activeLichCount .. " active liches, " .. dormantLichCount .. " dormant (optimized)")
    end

    -- Check for Holy Capital intervention
    if lichLairState.destroyedVillages >= LICH_BATTLE_CONFIG.villageDestroyThreshold
       and not lichLairState.holyIntervention then
        local interventionResult = WorldGen.triggerHolyIntervention()
        if interventionResult then
            table.insert(battleResults, interventionResult)
        end
    end

    return battleResults
end

-- Trigger Holy Capital sending a battalion to fight the lich threat
function WorldGen.triggerHolyIntervention()
    lichLairState.holyIntervention = true

    -- Find the strongest active lich lair
    local targetLich = nil
    local maxHorde = 0

    for lichId, lichLair in pairs(lichLairState.activeLairs) do
        if lichLair.lichActive then
            local hordeSize = getLichHordeSize(lichLair)
            if hordeSize > maxHorde then
                maxHorde = hordeSize
                targetLich = lichLair
            end
        end
    end

    if not targetLich then
        return nil
    end

    -- Battle between Holy Battalion and the Lich's horde
    local battalionSize = LICH_BATTLE_CONFIG.holyBattalionSize
    local hordeSize = getLichHordeSize(targetLich)

    local result = simulateBattle(
        battalionSize,
        LICH_BATTLE_CONFIG.holyBattalionStrength,
        hordeSize,
        LICH_BATTLE_CONFIG.undeadStrength
    )

    local battleRecord = {
        day = _G.state and _G.state.daysPassed or 0,
        townName = "Holy Capital Battalion",
        isHolyIntervention = true,
        lichLairId = targetLich.id,
        battalionSize = battalionSize,
        hordeSize = hordeSize,
        defenderWins = result.defenderWins,
        defenderCasualties = result.defenderCasualties,
        attackerCasualties = result.attackerCasualties,
    }
    table.insert(lichLairState.battleLog, battleRecord)

    if result.defenderWins then
        -- Holy Battalion wins - lich is destroyed, corruption cleansed
        WorldGen.cleanseLichCorruption(targetLich.id)
        battleRecord.lichDestroyed = true

        -- Reset destroyed villages count (threat is over)
        lichLairState.destroyedVillages = 0
    else
        -- Battalion falls - their dead join the horde
        targetLich.hordeSize = (targetLich.hordeSize or hordeSize) + result.defenderCasualties
        battleRecord.lichDestroyed = false

        -- Holy Capital will try again after cooldown (reset intervention flag after some days)
        -- This is handled externally
    end

    return battleRecord
end

-- Reset holy intervention flag (call after cooldown period)
function WorldGen.resetHolyIntervention()
    lichLairState.holyIntervention = false
end

-- Get recent battle log
function WorldGen.getLichBattleLog(limit)
    limit = limit or 10
    local log = {}
    local startIdx = math.max(1, #lichLairState.battleLog - limit + 1)

    for i = startIdx, #lichLairState.battleLog do
        table.insert(log, lichLairState.battleLog[i])
    end

    return log
end

-- Get lich horde status
function WorldGen.getLichHordeStatus()
    local status = {}

    for lichId, lichLair in pairs(lichLairState.activeLairs) do
        if lichLair.lichActive then
            status[lichId] = {
                id = lichId,
                x = lichLair.x,
                y = lichLair.y,
                hordeSize = getLichHordeSize(lichLair),
                corruptedTiles = 0,
            }

            -- Count corrupted tiles
            for _, corruptData in pairs(lichLairState.corruptedTiles) do
                if corruptData.lichLairId == lichId then
                    status[lichId].corruptedTiles = status[lichId].corruptedTiles + 1
                end
            end
        end
    end

    return status
end

-- Get destroyed villages count
function WorldGen.getDestroyedVillagesCount()
    return lichLairState.destroyedVillages
end

-- Check if holy intervention is active
function WorldGen.isHolyInterventionActive()
    return lichLairState.holyIntervention
end

-- Cleanse corruption when a lich is defeated
function WorldGen.cleanseLichCorruption(lichLairId)
    local lichLair = lichLairState.activeLairs[lichLairId]
    if lichLair then
        lichLair.lichActive = false
    end

    -- Cleanse all tiles corrupted by this lair
    local cleansedCount = 0
    for tileKey, corruptData in pairs(lichLairState.corruptedTiles) do
        if corruptData.lichLairId == lichLairId then
            local tile = WorldGen.getTile(corruptData.x, corruptData.y)
            if tile and tile.type == "corrupted" then
                -- Restore original terrain
                tile.type = tile.originalTerrain or "grass"
                tile.originalTerrain = nil
                tile.corruptedBy = nil
                tile.corruptionLevel = nil

                -- Mark chunk as modified
                local chunkX, chunkY = getChunkCoords(corruptData.x, corruptData.y)
                local chunkKey = getChunkKey(chunkX, chunkY)
                if chunkState.loadedChunks[chunkKey] then
                    chunkState.loadedChunks[chunkKey].modified = true
                end

                cleansedCount = cleansedCount + 1
            end
            lichLairState.corruptedTiles[tileKey] = nil
        end
    end

    lichLairState.totalCorruption = math.max(0, lichLairState.totalCorruption - cleansedCount)

    return cleansedCount
end

-- Get all active lich lairs
function WorldGen.getActiveLichLairs()
    local active = {}
    for id, lair in pairs(lichLairState.activeLairs) do
        if lair.lichActive then
            table.insert(active, lair)
        end
    end
    return active
end

-- Get world corruption level (0-100)
function WorldGen.getWorldCorruptionLevel()
    -- Scale based on number of corrupted tiles and active liches
    local activeCount = 0
    for _, lair in pairs(lichLairState.activeLairs) do
        if lair.lichActive then
            activeCount = activeCount + 1
        end
    end

    local corruption = lichLairState.totalCorruption * 0.1 + activeCount * 10
    return math.min(100, corruption)
end

-- Check if a tile is corrupted
function WorldGen.isCorrupted(tileX, tileY)
    local tileKey = tileX .. "," .. tileY
    return lichLairState.corruptedTiles[tileKey] ~= nil
end

-- Check if player is in undead patrol range of a lich lair
function WorldGen.isInUndeadPatrolRange(tileX, tileY)
    for _, lichLair in pairs(lichLairState.activeLairs) do
        if lichLair.lichActive then
            local dist = math.abs(tileX - lichLair.x) + math.abs(tileY - lichLair.y)
            local patrolRadius = lichLair.undeadPatrolRadius or LICH_LAIR_CONFIG.undeadPatrolRadius
            if dist <= patrolRadius then
                return true, lichLair
            end
        end
    end
    return false, nil
end

-- Register a lich lair when discovered/generated
function WorldGen.registerLichLair(dungeon)
    if dungeon and dungeon.isLichLair then
        lichLairState.activeLairs[dungeon.id] = dungeon
        -- Apply initial corruption
        WorldGen.applyLichLairCorruption(dungeon)
    end
end

-- Get lich lair config for external use
function WorldGen.getLichLairConfig()
    return LICH_LAIR_CONFIG
end

-- Save lich lair state
function WorldGen.getLichLairSaveData()
    return {
        activeLairs = lichLairState.activeLairs,
        corruptedTiles = lichLairState.corruptedTiles,
        totalCorruption = lichLairState.totalCorruption,
        destroyedVillages = lichLairState.destroyedVillages,
        battleLog = lichLairState.battleLog,
        holyIntervention = lichLairState.holyIntervention,
    }
end

-- Load lich lair state
function WorldGen.loadLichLairSaveData(data)
    if data then
        lichLairState.activeLairs = data.activeLairs or {}
        lichLairState.corruptedTiles = data.corruptedTiles or {}
        lichLairState.totalCorruption = data.totalCorruption or 0
        lichLairState.destroyedVillages = data.destroyedVillages or 0
        lichLairState.battleLog = data.battleLog or {}
        lichLairState.holyIntervention = data.holyIntervention or false
    end
end

-- ============================================================================
--                     HOLLOW EARTH LAYER SYSTEM
-- ============================================================================

-- Convert surface coordinates to hollow earth coordinates
function WorldGen.getHollowEarthCoordinate(surfaceX, surfaceY)
    return surfaceX, surfaceY + HOLLOW_EARTH_Y_OFFSET
end

-- Convert hollow earth coordinates to surface coordinates
function WorldGen.getSurfaceCoordinate(hollowX, hollowY)
    return hollowX, hollowY - HOLLOW_EARTH_Y_OFFSET
end

-- Get layer from Y coordinate
function WorldGen.getLayer(tileY)
    if tileY >= -969 then
        return LAYERS.SURFACE
    else
        return LAYERS.HOLLOW
    end
end

-- Check if coordinates are in hollow earth
function WorldGen.isHollowEarth(tileX, tileY)
    return WorldGen.getLayer(tileY) == LAYERS.HOLLOW
end

-- Get all hollow earth regions
function WorldGen.getHollowEarthRegions()
    local hollowRegions = {}
    for id, region in pairs(REGIONS) do
        if region.layer == LAYERS.HOLLOW then
            table.insert(hollowRegions, region)
        end
    end
    return hollowRegions
end

-- ============================================================================
--                  HOLLOW EARTH BREACH PROBABILITY SYSTEM
-- ============================================================================

-- Check if a dungeon floor should breach into hollow earth
-- Returns: shouldBreach (boolean), targetRegion (string or nil), breachType (string)
function WorldGen.checkHollowEarthBreach(dungeonFloor, dungeonType, regionId, tileX, tileY)
    -- Floor-based base probability
    local baseProbability = 0

    if dungeonFloor < 15 then
        baseProbability = 0  -- No breaches before floor 15
    elseif dungeonFloor >= 15 and dungeonFloor < 20 then
        baseProbability = 0.02  -- 2% chance floors 15-19
    elseif dungeonFloor >= 20 and dungeonFloor < 25 then
        baseProbability = 0.10  -- 10% chance floors 20-24
    elseif dungeonFloor >= 25 and dungeonFloor < 30 then
        baseProbability = 0.25  -- 25% chance floors 25-29
    elseif dungeonFloor >= 30 then
        baseProbability = 0.50  -- 50% chance floor 30+
    end

    -- Dungeon type modifiers
    local typeModifier = 0
    if dungeonType == "mine" or dungeonType == "cave" then
        typeModifier = 0.10  -- +10% for mines and caves (they go deep)
    elseif dungeonType == "volcanic_breach" then
        typeModifier = 1.0  -- Volcanic Descent guaranteed at floor 30
    elseif dungeonType == "vampire_den" then
        typeModifier = -0.05  -- -5% for vampire dens (they avoid deep earth)
    elseif dungeonType == "crypt" then
        typeModifier = 0.05  -- +5% for crypts (ancient burial sites)
    elseif dungeonType == "lich_lair" then
        typeModifier = 0.15  -- +15% for lich lairs (they seek forbidden places)
    end

    -- Region modifiers
    local regionModifier = 0
    if regionId == "shadowfen" then
        regionModifier = 0.08  -- +8% in Shadowfen (swamp connects to hollow seas)
    elseif regionId == "dwarven_mountains" then
        regionModifier = 0.12  -- +12% in mountains (deep mines)
    elseif regionId == "holy_dominion" then
        regionModifier = -0.05  -- -5% in Holy Dominion (blessed ground resists)
    elseif regionId == "ashen_archipelago" then
        regionModifier = 0.20  -- +20% in volcanic region
    elseif regionId == "orcish_steppes" then
        regionModifier = 0.05  -- +5% (ancient battlefields connect to Bone Wastes)
    elseif regionId == "gnomish_isles" then
        regionModifier = 0.08  -- +8% (deep mining operations)
    elseif regionId == "eastern_forests" then
        regionModifier = 0.06  -- +6% (old growth connects to Hollow Jungle)
    end

    -- Calculate final probability
    local finalProbability = baseProbability + typeModifier + regionModifier
    finalProbability = math.max(0, math.min(1, finalProbability))  -- Clamp to 0-1

    -- Special case: Volcanic Descent floor 30 is GUARANTEED
    if dungeonType == "volcanic_breach" and dungeonFloor == 30 then
        return true, "hollow_deep_dwarven_realm", "volcanic_breach"
    end

    -- Roll for breach
    local roll = math.random()
    if roll > finalProbability then
        return false, nil, nil  -- No breach
    end

    -- Breach occurred - determine target region based on surface location and region
    local targetRegion = WorldGen.determineBreachTarget(regionId, tileX, tileY, dungeonType)
    local breachType = WorldGen.determineBreachType(dungeonType, dungeonFloor)

    return true, targetRegion, breachType
end

-- Determine which hollow earth region to breach into based on surface location
function WorldGen.determineBreachTarget(surfaceRegionId, tileX, tileY, dungeonType)
    -- Map surface regions to likely hollow earth regions
    local regionMapping = {
        shadowfen = {"hollow_subterranean_seas", "hollow_bone_wastes"},  -- Swamps → Seas or Bone
        dwarven_mountains = {"hollow_deep_dwarven_realm", "hollow_crystal_caverns"},  -- Mountains → Deep Dwarves
        orcish_steppes = {"hollow_bone_wastes", "hollow_fungal_forests"},  -- Steppes → Bone Wastes
        holy_dominion = {"hollow_crystal_caverns", "hollow_storm_caverns"},  -- Central → Storm or Crystals
        eastern_forests = {"hollow_jungle", "hollow_fungal_forests"},  -- Forests → Jungle or Fungal
        gnomish_isles = {"hollow_crystal_caverns", "hollow_storm_caverns"},  -- Isles → Crystals
        ashen_archipelago = {"hollow_deep_dwarven_realm", "hollow_storm_caverns"},  -- Volcanic → Deep Dwarves
        great_endless_desert = {"hollow_bone_wastes", "hollow_storm_caverns"},  -- Desert → Bone Wastes
        scorched_sands = {"hollow_bone_wastes"},  -- Scorched → Bone Wastes
        wastes_of_calidar = {"hollow_bone_wastes", "hollow_storm_caverns"},  -- Wastes → Horror zones
    }

    -- Dungeon type influences target
    if dungeonType == "mine" then
        -- Mines tend to hit Crystal Caverns or Deep Dwarven Realm
        return (math.random() < 0.5) and "hollow_crystal_caverns" or "hollow_deep_dwarven_realm"
    elseif dungeonType == "crypt" then
        -- Crypts connect to Bone Wastes
        return "hollow_bone_wastes"
    elseif dungeonType == "vampire_den" then
        -- Vampire dens hit dark places
        return (math.random() < 0.5) and "hollow_fungal_forests" or "hollow_bone_wastes"
    elseif dungeonType == "cave" then
        -- Caves can hit anywhere
        local targets = regionMapping[surfaceRegionId] or {"hollow_storm_caverns"}
        return targets[math.random(#targets)]
    end

    -- Default: use region mapping
    local targets = regionMapping[surfaceRegionId] or {"hollow_storm_caverns"}
    return targets[math.random(#targets)]
end

-- Determine breach type (affects what happens when player enters)
function WorldGen.determineBreachType(dungeonType, dungeonFloor)
    if dungeonFloor >= 30 then
        return "major_breach"  -- Stable portal, two-way travel possible
    elseif dungeonFloor >= 25 then
        return "unstable_breach"  -- Can enter, but might collapse
    elseif dungeonFloor >= 20 then
        return "minor_breach"  -- Small opening, dangerous to traverse
    else
        return "crack"  -- Tiny fissure, can glimpse hollow earth but not enter
    end
end

-- Get breach description for flavor text
function WorldGen.getBreachDescription(breachType, targetRegion)
    local descriptions = {
        major_breach = {
            prefix = "A massive breach tears through the dungeon floor, revealing",
            hollow_fungal_forests = "endless bioluminescent forests glowing in impossible colors below.",
            hollow_jungle = "a humid jungle thriving in perpetual darkness, sustained by geothermal heat.",
            hollow_subterranean_seas = "a vast underground ocean, its surface glowing with bioluminescent plankton.",
            hollow_crystal_caverns = "caverns filled with humming crystal formations that sing in harmony.",
            hollow_bone_wastes = "a white desert of pulverized bone stretching to the horizon.",
            hollow_storm_caverns = "caverns where lightning arcs between formations and rain falls upward.",
            hollow_deep_dwarven_realm = "ancient dwarven cities carved into stone, lit by forge-fires.",
        },
        unstable_breach = {
            prefix = "An unstable fissure cracks open, showing glimpses of",
            hollow_fungal_forests = "glowing mushroom forests far below. The breach groans and shifts.",
            hollow_jungle = "impossible vegetation in the darkness below. Reality feels thin here.",
            hollow_subterranean_seas = "black waters and distant echoes. The breach could collapse at any moment.",
            hollow_crystal_caverns = "singing crystals and geometric formations. The breach pulses with energy.",
            hollow_bone_wastes = "white dunes of bone dust. The breach whispers in forgotten languages.",
            hollow_storm_caverns = "underground storms and lightning. Gravity shifts near the breach.",
            hollow_deep_dwarven_realm = "ancient architecture and forge-light. The breach smells of metal and stone.",
        },
        minor_breach = {
            prefix = "A narrow crack opens in the floor, revealing",
            hollow_fungal_forests = "bioluminescent light and the smell of spores drifting up.",
            hollow_jungle = "humid air and the sound of something moving through alien vegetation.",
            hollow_subterranean_seas = "the sound of waves and the smell of ancient water.",
            hollow_crystal_caverns = "harmonic resonance and geometric light patterns.",
            hollow_bone_wastes = "bone dust rising on impossible winds and whispered words.",
            hollow_storm_caverns = "lightning flashes and the roar of underground weather.",
            hollow_deep_dwarven_realm = "the ring of hammers on anvils echoing from impossible depths.",
        },
        crack = {
            prefix = "A hairline crack in the floor allows",
            hollow_fungal_forests = "bioluminescent light to seep through. You smell spores.",
            hollow_jungle = "humid air to rise. You hear alien sounds from far below.",
            hollow_subterranean_seas = "the sound of distant waves to echo upward.",
            hollow_crystal_caverns = "harmonic tones to resonate through the stone.",
            hollow_bone_wastes = "whispers in forgotten languages to drift up.",
            hollow_storm_caverns = "the smell of ozone and sound of distant thunder.",
            hollow_deep_dwarven_realm = "the scent of metal and distant forge-fires.",
        },
    }

    local typeDescriptions = descriptions[breachType]
    if not typeDescriptions then
        return "something impossible in the depths below."
    end

    local prefix = typeDescriptions.prefix
    local suffix = typeDescriptions[targetRegion] or "the world beneath the world."

    return prefix .. " " .. suffix
end

-- Export layer constants for external use
function WorldGen.getLayers()
    return LAYERS
end

-- Export hollow earth offset for external use
function WorldGen.getHollowEarthOffset()
    return HOLLOW_EARTH_Y_OFFSET
end

return WorldGen
