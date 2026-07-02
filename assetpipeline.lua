-- Asset Pipeline (consolidated module)
-- Combines: assetconfig.lua, assetloader.lua, assetscanner.lua
-- These three files form one logical system for asset configuration, loading, and scanning.

local AssetPipeline = {}

-- =====================================================================
-- SECTION 1: ASSET CONFIG
-- (formerly assetconfig.lua)
-- Defines folder structure, categorization, role assignments, etc.
-- =====================================================================

local AssetConfig = {}
AssetPipeline.config = AssetConfig

-- ============================================
-- FOLDER STRUCTURE DEFINITION
-- ============================================
-- Define your character asset folders here
-- Format: {path = "folder/subfolder", category = "category_name", gender = "male"/"female"/"neutral"}

AssetConfig.folders = {
    -- Human Characters (gendered)
    {path = "Human/Men_Human", category = "humans", gender = "male", race = "human"},
    {path = "Human/Women_Human", category = "humans", gender = "female", race = "human"},

    -- Elf Characters (gendered)
    {path = "ELF/Men_ELF", category = "elves", gender = "male", race = "elf"},
    {path = "ELF/Women_Elf", category = "elves", gender = "female", race = "elf"},

    -- Orc Characters (gendered)
    {path = "ORC/Men_ORC", category = "orcs", gender = "male", race = "orc"},
    {path = "ORC/Women_ORC", category = "orcs", gender = "female", race = "orc"},

    -- Animals (for pets and creature cards)
    {path = "Animals", category = "animals", gender = "neutral", race = "animal"},

    -- Monsters (for pets and creature cards)
    {path = "Monsters", category = "monsters", gender = "neutral", race = "monster"},

    -- ============================================
    -- ADD NEW RACE FOLDERS HERE
    -- ============================================
    -- Example: If you add a Dwarf race folder:
    -- {path = "DWARF/Men_Dwarf", category = "dwarves", gender = "male", race = "dwarf"},
    -- {path = "DWARF/Women_Dwarf", category = "dwarves", gender = "female", race = "dwarf"},
}

-- ============================================
-- ROOT FOLDER ASSETS
-- ============================================
-- Assets that remain in the root characters folder (not in subfolders)
-- These are typically special/unique characters

AssetConfig.rootAssets = {
    -- Gods (gender-neutral category but can be assigned)
    gods_male = {
        "God_Zeus", "God_Hades", "God_Poseidon", "God_Ares", "God_Apollo",
        "God_Hermes", "God_Hephaestus", "God_Dionysus",
    },
    gods_female = {
        "God_Athena", "God_Artemis", "God_Aphrodite", "God_Hera",
    },

    -- Demons
    demons = {
        "Demon_01", "Demon_02_imp", "Demon_03_Devil", "Demon_05_Lilith",
        "Demon_06_ice", "Demon_07_fire", "Demon_09_death", "Demon_10_succubus",
        "Demon_11_gargoyle", "Demon_13_guard", "CryingDemon",
    },

    -- Undead
    undead = {
        "Undead_01", "Undead_01_archer", "Undead_02", "Undead_02_knight",
        "Undead_03", "Undead_03_1", "Undead_04_warrior", "Undead_05",
        "Undead_05_skeleton", "Undead_06", "Undead_06_zombie", "Undead_07",
        "Undead_07_soulhunter", "Undead_08", "Undead_08_ice_queen",
        "Undead_09", "Undead_09_ghost", "Undead_10", "Undead_10_dragon",
        "Undead_11", "Undead_12", "Undead_13",
    },

    -- Giants/Titans
    giants = {
        "Gigant_01_cyclope", "Gigant_02_old_titan", "Gigant_03_yeti",
        "Gigant_04_ogre", "Gigant_06_ogre_warrior", "Gigant_07_ogre_mage",
        "Giant_StoneGolem",
    },

    -- Gnomes
    gnomes = {
        "Gnome_01", "Gnome_02", "Gnome_03", "Gnome_04",
        "Gnome_05", "Gnome_06", "Gnome_dark",
    },

    -- Goblins
    goblins = {
        "goblin_01", "goblin_02", "goblin_03", "goblin_04", "goblin_05",
    },

    -- Special/Misc characters in root
    misc = {
        "Dwarf", "MadDwarf", "Neanderthalensis", "RoyalGuard", "OldCultist",
        "Old_woman", "HadesServant", "homunculus", "Robot", "Robot2",
        "scientist", "StoneGuard", "Obelisk", "Mine",
    },

    -- Creatures that stayed in root (holy/special)
    special_creatures = {
        "Creatures_02_Archangel", "Creatures_04_gorgon", "Creatures_06_Hell_guard",
        "Creatures_09_golden_guard", "Creatures_13_Holy_Knight", "Creatures_16_troll",
    },
}

-- ============================================
-- ASSET ROLE ASSIGNMENTS
-- ============================================
-- Define which assets are suitable for specific game roles
-- This helps when spawning NPCs for different contexts

AssetConfig.roleAssignments = {
    -- Tavern customers
    tavern_patrons = {
        categories = {"humans", "elves", "orcs", "dwarves"},
        include_root = {"gnomes", "misc"},
    },

    -- Poker/card game opponents
    card_opponents = {
        categories = {"humans", "elves", "orcs"},
        include_root = {"gods_male", "gods_female", "gnomes"},
    },

    -- Pet creatures (animals and friendly monsters)
    pets = {
        categories = {"animals", "monsters"},
        exclude_patterns = {"Demon", "Skeleton", "Undead", "Death"},
    },

    -- Trading card creatures
    creature_cards = {
        categories = {"animals", "monsters"},
        include_root = {"special_creatures"},
    },

    -- RPG enemies
    rpg_enemies = {
        categories = {"monsters"},
        include_root = {"demons", "undead", "giants", "goblins"},
    },

    -- Shop NPCs
    shopkeepers = {
        categories = {"humans", "elves"},
        include_root = {"gnomes"},
        preferred_patterns = {"Merchant", "Trader", "Dwarf"},
    },

    -- Guards/Warriors
    guards = {
        categories = {"humans", "orcs"},
        preferred_patterns = {"Guard", "Knight", "Warrior", "Soldier"},
    },
}

-- ============================================
-- CREATURE CARD ELEMENT MAPPINGS
-- ============================================
-- When adding new creature portraits, assign them to elements here

AssetConfig.creatureElements = {
    flame = {
        "Monsters/Monster_Elemental", "Monsters/Creatures_11_Dragon",
        "Monsters/Monster_Terrible", "Animals/Wolf_animal",
    },
    aqua = {
        "Monsters/Monster_fish", "Monsters/Monster_DemonicFish",
        "Monsters/Monster_waterm", "Animals/Dolphin_animal", "Animals/Shark_animal",
    },
    terra = {
        "Monsters/Monster_Flower", "Monsters/Monster_Flower2", "Monsters/Monster_Flower3",
        "Animals/Bear_animal", "Animals/Boar_animal", "Monsters/Gigant_05_pangolin",
    },
    volt = {
        "Monsters/Creatures_07_phoenix", "Monsters/Monster_DragonWarrior",
        "Animals/Hawk_animal", "Animals/Bird_animal",
    },
    shadow = {
        "Monsters/Monster_Spider", "Monsters/Monster_Eye", "Monsters/Devourer",
        "Animals/Bat", "Monsters/Demon_12_skeleton_king",
    },
    light = {
        "Animals/Creatures_12_Dog", "Animals/Creatures_10_warhorse",
        "Monsters/Creatures_07_phoenix", "Creatures_02_Archangel",
    },
    frost = {
        "Animals/Wolf_animal", "Animals/Bear_animal",
        "Monsters/Monster_DragonWarrior",
    },
    metal = {
        "Monsters/Monster_Scorpion", "Monsters/Creatures_05_werewolf",
        "Monsters/Gigant_08_minotaur", "Monsters/Monster_SkeletonSnake",
    },
}

-- ============================================
-- PET EVOLUTION PATHS
-- ============================================
-- Define evolution chains for pets

AssetConfig.petEvolutions = {
    -- Format: {base, evolved, final}
    slime = {"Monsters/Monster_Slime", "Monsters/Monster_Slime", "Monsters/Monster_Elemental"},
    bird = {"Animals/Bird_animal", "Animals/Hawk_animal", "Monsters/Creatures_07_phoenix"},
    cat = {"Animals/Cat_animal", "Animals/Cat_animal", "Animals/Creatures_12_Dog"},
    dog = {"Animals/Creatures_12_Dog", "Animals/Wolf_animal", "Monsters/Creatures_05_werewolf"},
    dragon = {"Animals/Monsters_09", "Monsters/Creatures_11_Dragon", "Monsters/Creatures_11_Dragon"},
    fish = {"Monsters/Monster_fish", "Monsters/Monster_fish", "Monsters/Monster_DemonicFish"},
    wolf = {"Animals/Wolf_animal", "Animals/Wolf_animal", "Monsters/Creatures_05_werewolf"},
    bear = {"Animals/Bear_animal", "Animals/Bear_animal", "Monsters/Gigant_05_pangolin"},
    hawk = {"Animals/Hawk_animal", "Animals/Hawk_animal", "Monsters/Creatures_07_phoenix"},
    bat = {"Animals/Bat", "Animals/Bat", "Monsters/Monster_Eye"},
}

-- ============================================
-- NAME POOLS
-- ============================================
-- Name lists by gender and race (for NPC generation)

AssetConfig.names = {
    human_male = {
        "Aldric", "Bran", "Cedric", "Duncan", "Edmund", "Felix", "Gareth", "Harold",
        "Ivan", "Jasper", "Klaus", "Leon", "Magnus", "Niles", "Oswald", "Percy",
        "Roland", "Silas", "Tobias", "Victor", "Wallace", "Xavier", "Theron", "Varen",
    },
    human_female = {
        "Adeline", "Beatrice", "Clara", "Diana", "Eleanor", "Fiona", "Gwen", "Helena",
        "Iris", "Julia", "Katherine", "Lydia", "Miriam", "Nora", "Ophelia", "Penelope",
        "Rosalind", "Selene", "Thalia", "Violet", "Wren", "Yara", "Zelda", "Luna",
    },
    elf_male = {
        "Aelindor", "Caelum", "Erevan", "Galinndan", "Heian", "Ivellios", "Laucian",
        "Mindartis", "Paelias", "Quarion", "Riardon", "Soveliss", "Thamior", "Varis",
    },
    elf_female = {
        "Adrie", "Birel", "Caelynn", "Drusilia", "Enna", "Felosial", "Galinnda",
        "Ielenia", "Keyleth", "Lia", "Mialee", "Naivara", "Quelenna", "Silaqui",
    },
    orc_male = {
        "Grok", "Thrak", "Morg", "Durg", "Krag", "Brug", "Zorn", "Gash",
        "Thok", "Grumsh", "Lurtz", "Azog", "Bolg", "Gothmog", "Shagrat",
    },
    orc_female = {
        "Grunda", "Shara", "Mogra", "Durga", "Kraga", "Bruga", "Zorna",
        "Thoka", "Grumsha", "Lurza", "Azoga", "Bolga", "Gothma", "Shagraa",
    },
    -- Add more races as needed
}

-- ============================================
-- ASSET CONFIG HELPER FUNCTIONS
-- ============================================

-- Get all folder paths for a specific category
function AssetConfig.getFoldersByCategory(category)
    local result = {}
    for _, folder in ipairs(AssetConfig.folders) do
        if folder.category == category then
            table.insert(result, folder)
        end
    end
    return result
end

-- Get folders by gender
function AssetConfig.getFoldersByGender(gender)
    local result = {}
    for _, folder in ipairs(AssetConfig.folders) do
        if folder.gender == gender then
            table.insert(result, folder)
        end
    end
    return result
end

-- Get root assets for a specific category
function AssetConfig.getRootAssets(categoryName)
    return AssetConfig.rootAssets[categoryName] or {}
end

-- Get all categories
function AssetConfig.getCategories()
    local categories = {}
    local seen = {}
    for _, folder in ipairs(AssetConfig.folders) do
        if not seen[folder.category] then
            seen[folder.category] = true
            table.insert(categories, folder.category)
        end
    end
    return categories
end

-- Get assets suitable for a specific role
function AssetConfig.getAssetsForRole(roleName)
    local role = AssetConfig.roleAssignments[roleName]
    if not role then return {} end

    local assets = {
        folders = {},
        rootAssets = {},
    }

    -- Get folder categories
    if role.categories then
        for _, cat in ipairs(role.categories) do
            local folders = AssetConfig.getFoldersByCategory(cat)
            for _, f in ipairs(folders) do
                table.insert(assets.folders, f)
            end
        end
    end

    -- Get root asset categories
    if role.include_root then
        for _, rootCat in ipairs(role.include_root) do
            assets.rootAssets[rootCat] = AssetConfig.getRootAssets(rootCat)
        end
    end

    return assets
end

-- Get names for a race and gender
function AssetConfig.getNames(race, gender)
    local key = race .. "_" .. gender
    return AssetConfig.names[key] or AssetConfig.names["human_" .. gender] or {}
end

-- Print a summary of the configuration (for debugging)
function AssetConfig.printSummary()
    print("=== Asset Configuration Summary ===")
    print("\nFolders defined: " .. #AssetConfig.folders)
    for _, folder in ipairs(AssetConfig.folders) do
        print("  - " .. folder.path .. " (" .. folder.category .. ", " .. folder.gender .. ")")
    end

    print("\nRoot asset categories:")
    for name, assets in pairs(AssetConfig.rootAssets) do
        print("  - " .. name .. ": " .. #assets .. " assets")
    end

    print("\nRole assignments:")
    for name, _ in pairs(AssetConfig.roleAssignments) do
        print("  - " .. name)
    end
end


-- =====================================================================
-- SECTION 2: ASSET LOADER
-- (formerly assetloader.lua)
-- Loads and manages Dungeon Crawl, RPG GUI Kit, and Moderna assets
-- =====================================================================

local AssetLoader = {}
AssetPipeline.loader = AssetLoader

-- Asset paths
local LOADER_PATHS = {
    dungeonCrawl = "assets/dungeon_crawl/Dungeon Crawl Stone Soup Full/",
    rpgGUI = "assets/rpg_gui_kit/",
    moderna = "assets/moderna/",
}

-- Cached assets
AssetLoader.dungeonCrawl = {
    dungeon = {},
    monsters = {},
    items = {},
    player = {},
    effects = {},
    gui = {},
}

AssetLoader.rpgGUI = {
    spriteSheet = nil,
    background = nil,
    woodBG = nil,
    paperBG = nil,
}

AssetLoader.moderna = {
    interface = nil,
}

-----------------------------------------------------------
-- DUNGEON CRAWL: Load tile and sprite assets
-----------------------------------------------------------

function AssetLoader.loadDungeonCrawl()
    print("Loading Dungeon Crawl assets...")

    -- Dungeon tiles (floors, walls, doors)
    AssetLoader.loadDungeonTiles()

    -- Monster sprites
    AssetLoader.loadMonsters()

    -- Item sprites
    AssetLoader.loadItems()

    -- Player sprites
    AssetLoader.loadPlayer()

    -- Effect sprites (spells, particles)
    AssetLoader.loadEffects()

    -- GUI elements
    AssetLoader.loadDungeonGUI()

    print("Dungeon Crawl assets loaded!")
end

function AssetLoader.loadDungeonTiles()
    local basePath = LOADER_PATHS.dungeonCrawl .. "dungeon/"

    -- Floor tiles
    AssetLoader.dungeonCrawl.dungeon.floor = {}
    local floorPath = basePath .. "floor/"

    -- Try to load common floor tiles (using actual file names)
    local floorFiles = {
        "black_cobalt_1.png",
        "black_cobalt_2.png",
        "limestone_0.png",
        "limestone_1.png",
        "mesh_0.png",
        "pebble_brown_0.png",
        "pebble_brown_1.png",
    }

    for _, file in ipairs(floorFiles) do
        local path = floorPath .. file
        if love.filesystem.getInfo(path) then
            local name = file:gsub("%.png$", "")
            AssetLoader.dungeonCrawl.dungeon.floor[name] = love.graphics.newImage(path)
        end
    end

    -- Wall tiles
    AssetLoader.dungeonCrawl.dungeon.wall = {}
    local wallPath = basePath .. "wall/"

    local wallFiles = {
        "brick_brown_0.png",
        "brick_dark_0.png",
        "brick_gray_0.png",
        "catacombs_0.png",
        "crystal_wall_blue.png",
        "lair_0.png",
        "stone_gray_0.png",
        "stone_dark_0.png",
        "vault_0.png",
    }

    for _, file in ipairs(wallFiles) do
        local path = wallPath .. file
        if love.filesystem.getInfo(path) then
            local name = file:gsub("%.png$", "")
            AssetLoader.dungeonCrawl.dungeon.wall[name] = love.graphics.newImage(path)
        end
    end

    -- Doors
    AssetLoader.dungeonCrawl.dungeon.doors = {}
    local doorPath = basePath .. "doors/"

    local doorFiles = {
        "closed_door.png",
        "open_door.png",
        "gate_closed_left.png",
        "gate_open_left.png",
    }

    for _, file in ipairs(doorFiles) do
        local path = doorPath .. file
        if love.filesystem.getInfo(path) then
            local name = file:gsub("%.png$", "")
            AssetLoader.dungeonCrawl.dungeon.doors[name] = love.graphics.newImage(path)
        end
    end
end

function AssetLoader.loadMonsters()
    local basePath = LOADER_PATHS.dungeonCrawl .. "monster/"

    -- Common monster sprites
    local monsterFiles = {
        -- Animals
        "animals/rat.png",
        "animals/bat.png",
        "animals/giant_bat.png",

        -- Undead
        "angel.png",  -- Can be used for ghosts/spirits

        -- Generic
        "centaur.png",
        "cyclops_new.png",
        "daeva.png",
    }

    for _, file in ipairs(monsterFiles) do
        local path = basePath .. file
        if love.filesystem.getInfo(path) then
            local name = file:gsub(".*/", ""):gsub("%.png$", "")
            AssetLoader.dungeonCrawl.monsters[name] = love.graphics.newImage(path)
        end
    end

    print("  Loaded " .. #AssetLoader.dungeonCrawl.monsters .. " monster sprites")
end

function AssetLoader.loadItems()
    local basePath = LOADER_PATHS.dungeonCrawl .. "item/"

    -- Item categories
    local categories = {"weapon", "armor", "potion", "scroll", "gold", "food", "misc"}

    for _, category in ipairs(categories) do
        AssetLoader.dungeonCrawl.items[category] = {}

        -- Try to load a sprite sheet for this category
        local sheetPath = basePath .. category .. ".png"
        if love.filesystem.getInfo(sheetPath) then
            AssetLoader.dungeonCrawl.items[category].sheet = love.graphics.newImage(sheetPath)
        end
    end
end

function AssetLoader.loadPlayer()
    local basePath = LOADER_PATHS.dungeonCrawl .. "player/"

    -- Player body parts (for customization)
    AssetLoader.dungeonCrawl.player.base = {}

    -- Try to load base sprites
    local basePath = basePath .. "base/"
    if love.filesystem.getInfo(basePath .. "human_m.png") then
        AssetLoader.dungeonCrawl.player.base.human_male = love.graphics.newImage(basePath .. "human_m.png")
    end
    if love.filesystem.getInfo(basePath .. "human_f.png") then
        AssetLoader.dungeonCrawl.player.base.human_female = love.graphics.newImage(basePath .. "human_f.png")
    end
end

function AssetLoader.loadEffects()
    local basePath = LOADER_PATHS.dungeonCrawl .. "effect/"

    AssetLoader.dungeonCrawl.effects = {}

    -- Common effect sprites
    local effectFiles = {
        "explosion.png",
        "fireball.png",
        "magic_dart.png",
    }

    for _, file in ipairs(effectFiles) do
        local path = basePath .. file
        if love.filesystem.getInfo(path) then
            local name = file:gsub("%.png$", "")
            AssetLoader.dungeonCrawl.effects[name] = love.graphics.newImage(path)
        end
    end
end

function AssetLoader.loadDungeonGUI()
    local basePath = LOADER_PATHS.dungeonCrawl .. "gui/"

    AssetLoader.dungeonCrawl.gui = {}

    -- Load GUI elements if they exist
    if love.filesystem.getInfo(basePath) then
        -- GUI elements will be loaded here
    end
end

-----------------------------------------------------------
-- RPG GUI KIT: Load UI components
-----------------------------------------------------------

function AssetLoader.loadRPGGUI()
    print("Loading RPG GUI Kit assets...")

    local basePath = LOADER_PATHS.rpgGUI

    -- Main sprite sheet with all UI elements
    if love.filesystem.getInfo(basePath .. "RPG_GUI_v1.png") then
        AssetLoader.rpgGUI.spriteSheet = love.graphics.newImage(basePath .. "RPG_GUI_v1.png")
        print("  Loaded RPG GUI sprite sheet")
    end

    -- Background textures
    if love.filesystem.getInfo(basePath .. "wood background.png") then
        AssetLoader.rpgGUI.woodBG = love.graphics.newImage(basePath .. "wood background.png")
        print("  Loaded wood background")
    end

    if love.filesystem.getInfo(basePath .. "paper background.png") then
        AssetLoader.rpgGUI.paperBG = love.graphics.newImage(basePath .. "paper background.png")
        print("  Loaded paper background")
    end

    print("RPG GUI Kit assets loaded!")
end

-----------------------------------------------------------
-- MODERNA: Load modern interface
-----------------------------------------------------------

function AssetLoader.loadModerna()
    print("Loading Moderna interface...")

    local basePath = LOADER_PATHS.moderna

    -- PSD file exists but can't be loaded directly by LOVE2D
    -- You'll need to export layers to PNG in GIMP/Photoshop first

    if love.filesystem.getInfo(basePath .. "moderna_interface.psd") then
        print("  Moderna PSD found - export layers to PNG for use")
        print("  Use GIMP to open moderna_interface.psd and export:")
        print("    - HP bar")
        print("    - Mana bar")
        print("    - Inventory window")
        print("    - Quest window")
        print("    - Spell bar")
    end

    print("Moderna interface noted (requires manual export)")
end

-----------------------------------------------------------
-- INITIALIZATION: Load all assets
-----------------------------------------------------------

function AssetLoader.init()
    print("========================================")
    print("ASSET LOADER - Initializing...")
    print("========================================")

    -- Load all asset packs
    AssetLoader.loadDungeonCrawl()
    AssetLoader.loadRPGGUI()
    AssetLoader.loadModerna()

    print("========================================")
    print("All assets loaded successfully!")
    print("========================================")
end

-----------------------------------------------------------
-- UTILITY: Get specific assets
-----------------------------------------------------------

-- Get a floor tile
function AssetLoader.getFloorTile(tileName)
    return AssetLoader.dungeonCrawl.dungeon.floor[tileName]
end

-- Get a wall tile
function AssetLoader.getWallTile(tileName)
    return AssetLoader.dungeonCrawl.dungeon.wall[tileName]
end

-- Get a door sprite
function AssetLoader.getDoor(state)
    return AssetLoader.dungeonCrawl.dungeon.doors[state]
end

-- Get a monster sprite
function AssetLoader.getMonster(monsterName)
    return AssetLoader.dungeonCrawl.monsters[monsterName]
end

-- Get an item sprite
function AssetLoader.getItemSheet(category)
    return AssetLoader.dungeonCrawl.items[category] and
           AssetLoader.dungeonCrawl.items[category].sheet
end

-- Get RPG GUI sprite sheet
function AssetLoader.getGUISheet()
    return AssetLoader.rpgGUI.spriteSheet
end

-- Get background texture
function AssetLoader.getBackground(type)
    if type == "wood" then
        return AssetLoader.rpgGUI.woodBG
    elseif type == "paper" then
        return AssetLoader.rpgGUI.paperBG
    end
end


-- =====================================================================
-- SECTION 3: ASSET SCANNER
-- (formerly assetscanner.lua)
-- Scans the assets/characters folder and generates asset lists
-- =====================================================================

local AssetScanner = {}
AssetPipeline.scanner = AssetScanner

-- Base path for all assets (relative to game root)
local SCANNER_ASSETS_BASE = "assets/"
local CHARACTERS_PATH = SCANNER_ASSETS_BASE .. "characters/"

-- ============================================
-- FOLDER SCANNING
-- ============================================

-- Check if a file exists
local function fileExists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    return false
end

-- Get all PNG files in a directory (LOVE2D compatible)
local function scanDirectory(path)
    local files = {}

    -- Try using love.filesystem if available
    if love and love.filesystem then
        local items = love.filesystem.getDirectoryItems(path)
        for _, item in ipairs(items) do
            if item:match("%.PNG$") or item:match("%.png$") then
                -- Remove extension for asset name
                local name = item:gsub("%.PNG$", ""):gsub("%.png$", "")
                table.insert(files, name)
            end
        end
    else
        -- Fallback for running outside LOVE2D (command line)
        local handle = io.popen('dir "' .. path .. '" /b 2>nul')
        if handle then
            for line in handle:lines() do
                if line:match("%.PNG$") or line:match("%.png$") then
                    local name = line:gsub("%.PNG$", ""):gsub("%.png$", "")
                    table.insert(files, name)
                end
            end
            handle:close()
        end
    end

    return files
end

-- Check if directory exists
local function directoryExists(path)
    if love and love.filesystem then
        local info = love.filesystem.getInfo(path)
        return info and info.type == "directory"
    else
        -- Fallback for command line
        local handle = io.popen('dir "' .. path .. '" /b /ad 2>nul')
        if handle then
            local result = handle:read("*a")
            handle:close()
            return result ~= ""
        end
    end
    return false
end

-- ============================================
-- MAIN SCANNING FUNCTIONS
-- ============================================

-- Scan all configured folders and return asset lists
function AssetScanner.scanAll()
    local results = {
        byFolder = {},      -- Assets organized by folder path
        byCategory = {},    -- Assets organized by category
        byGender = {        -- Assets organized by gender
            male = {},
            female = {},
            neutral = {},
        },
        byRace = {},        -- Assets organized by race
        animals = {},       -- All animal assets (for pets/creatures)
        monsters = {},      -- All monster assets (for pets/creatures)
        allAssets = {},     -- Complete list of all assets
        errors = {},        -- Any scanning errors
    }

    print("=== Scanning Asset Folders ===")
    print("Base path: " .. CHARACTERS_PATH)

    -- Scan each configured folder
    for _, folder in ipairs(AssetConfig.folders) do
        local fullPath = CHARACTERS_PATH .. folder.path
        print("\nScanning: " .. folder.path)

        if directoryExists(fullPath) then
            local files = scanDirectory(fullPath)
            print("  Found " .. #files .. " assets")

            -- Store by folder
            results.byFolder[folder.path] = files

            -- Initialize category if needed
            if not results.byCategory[folder.category] then
                results.byCategory[folder.category] = {}
            end

            -- Initialize race if needed
            if not results.byRace[folder.race] then
                results.byRace[folder.race] = {}
            end

            -- Process each file
            for _, fileName in ipairs(files) do
                local fullAssetPath = folder.path .. "/" .. fileName

                -- Add to category
                table.insert(results.byCategory[folder.category], fullAssetPath)

                -- Add to gender list
                if folder.gender == "male" then
                    table.insert(results.byGender.male, fullAssetPath)
                elseif folder.gender == "female" then
                    table.insert(results.byGender.female, fullAssetPath)
                else
                    table.insert(results.byGender.neutral, fullAssetPath)
                end

                -- Add to race
                table.insert(results.byRace[folder.race], fullAssetPath)

                -- Add to animals/monsters if applicable
                if folder.category == "animals" then
                    table.insert(results.animals, fullAssetPath)
                elseif folder.category == "monsters" then
                    table.insert(results.monsters, fullAssetPath)
                end

                -- Add to complete list
                table.insert(results.allAssets, fullAssetPath)
            end
        else
            local err = "Folder not found: " .. fullPath
            print("  ERROR: " .. err)
            table.insert(results.errors, err)
        end
    end

    -- Scan root folder for uncategorized assets
    print("\nScanning root folder...")
    local rootFiles = scanDirectory(CHARACTERS_PATH)
    results.byFolder["_root"] = rootFiles
    print("  Found " .. #rootFiles .. " assets in root")

    return results
end

-- Scan only animals and monsters folders
function AssetScanner.scanCreatures()
    local results = {
        animals = {},
        monsters = {},
        all = {},
    }

    -- Scan Animals folder
    local animalsPath = CHARACTERS_PATH .. "Animals"
    if directoryExists(animalsPath) then
        local files = scanDirectory(animalsPath)
        for _, fileName in ipairs(files) do
            local fullPath = "Animals/" .. fileName
            table.insert(results.animals, fullPath)
            table.insert(results.all, fullPath)
        end
    end

    -- Scan Monsters folder
    local monstersPath = CHARACTERS_PATH .. "Monsters"
    if directoryExists(monstersPath) then
        local files = scanDirectory(monstersPath)
        for _, fileName in ipairs(files) do
            local fullPath = "Monsters/" .. fileName
            table.insert(results.monsters, fullPath)
            table.insert(results.all, fullPath)
        end
    end

    return results
end

-- Scan gendered NPC folders
function AssetScanner.scanNPCs()
    local results = {
        male = {},
        female = {},
        byRace = {},
    }

    for _, folder in ipairs(AssetConfig.folders) do
        if folder.gender == "male" or folder.gender == "female" then
            local fullPath = CHARACTERS_PATH .. folder.path

            if directoryExists(fullPath) then
                local files = scanDirectory(fullPath)

                -- Initialize race if needed
                if not results.byRace[folder.race] then
                    results.byRace[folder.race] = {male = {}, female = {}}
                end

                for _, fileName in ipairs(files) do
                    local fullAssetPath = folder.path .. "/" .. fileName

                    if folder.gender == "male" then
                        table.insert(results.male, fullAssetPath)
                        table.insert(results.byRace[folder.race].male, fullAssetPath)
                    else
                        table.insert(results.female, fullAssetPath)
                        table.insert(results.byRace[folder.race].female, fullAssetPath)
                    end
                end
            end
        end
    end

    return results
end

-- ============================================
-- FIND NEW/UNASSIGNED ASSETS
-- ============================================

-- Find assets that exist in folders but aren't in the config
function AssetScanner.findUnassigned()
    local scanResults = AssetScanner.scanAll()
    local unassigned = {
        creatures = {},  -- In Animals/Monsters but not assigned to elements
        npcs = {},       -- In NPC folders but not in any special list
    }

    -- Check creatures against element assignments
    local assignedCreatures = {}
    for _, creatures in pairs(AssetConfig.creatureElements) do
        for _, creature in ipairs(creatures) do
            assignedCreatures[creature] = true
        end
    end

    for _, creature in ipairs(scanResults.animals) do
        if not assignedCreatures[creature] then
            table.insert(unassigned.creatures, creature)
        end
    end
    for _, creature in ipairs(scanResults.monsters) do
        if not assignedCreatures[creature] then
            table.insert(unassigned.creatures, creature)
        end
    end

    return unassigned
end

-- ============================================
-- GENERATE CODE
-- ============================================

-- Generate Lua code for UIAssets lists (copy-paste ready)
function AssetScanner.generateUIAssetsCode()
    local npcs = AssetScanner.scanNPCs()
    local creatures = AssetScanner.scanCreatures()

    local code = {}

    -- Male portraits
    table.insert(code, "-- Auto-generated male portraits list")
    table.insert(code, "UIAssets.malePortraits = {")
    for _, portrait in ipairs(npcs.male) do
        table.insert(code, '    "' .. portrait .. '",')
    end
    table.insert(code, "}")
    table.insert(code, "")

    -- Female portraits
    table.insert(code, "-- Auto-generated female portraits list")
    table.insert(code, "UIAssets.femalePortraits = {")
    for _, portrait in ipairs(npcs.female) do
        table.insert(code, '    "' .. portrait .. '",')
    end
    table.insert(code, "}")
    table.insert(code, "")

    -- Animals
    table.insert(code, "-- Auto-generated animals list")
    table.insert(code, "UIAssets.characterCategories.animals = {")
    for _, animal in ipairs(creatures.animals) do
        table.insert(code, '    "' .. animal .. '",')
    end
    table.insert(code, "}")
    table.insert(code, "")

    -- Monsters
    table.insert(code, "-- Auto-generated monsters list")
    table.insert(code, "UIAssets.characterCategories.monsters = {")
    for _, monster in ipairs(creatures.monsters) do
        table.insert(code, '    "' .. monster .. '",')
    end
    table.insert(code, "}")

    return table.concat(code, "\n")
end

-- Generate a summary report
function AssetScanner.generateReport()
    local results = AssetScanner.scanAll()
    local report = {}

    table.insert(report, "=== ASSET SCAN REPORT ===")
    table.insert(report, "Generated: " .. os.date("%Y-%m-%d %H:%M:%S"))
    table.insert(report, "")

    -- Summary counts
    table.insert(report, "SUMMARY:")
    table.insert(report, "  Total assets: " .. #results.allAssets)
    table.insert(report, "  Male portraits: " .. #results.byGender.male)
    table.insert(report, "  Female portraits: " .. #results.byGender.female)
    table.insert(report, "  Neutral/Creature: " .. #results.byGender.neutral)
    table.insert(report, "  Animals: " .. #results.animals)
    table.insert(report, "  Monsters: " .. #results.monsters)
    table.insert(report, "")

    -- By category
    table.insert(report, "BY CATEGORY:")
    for category, assets in pairs(results.byCategory) do
        table.insert(report, "  " .. category .. ": " .. #assets)
    end
    table.insert(report, "")

    -- By race
    table.insert(report, "BY RACE:")
    for race, assets in pairs(results.byRace) do
        table.insert(report, "  " .. race .. ": " .. #assets)
    end
    table.insert(report, "")

    -- Errors
    if #results.errors > 0 then
        table.insert(report, "ERRORS:")
        for _, err in ipairs(results.errors) do
            table.insert(report, "  - " .. err)
        end
        table.insert(report, "")
    end

    -- Unassigned assets
    local unassigned = AssetScanner.findUnassigned()
    if #unassigned.creatures > 0 then
        table.insert(report, "UNASSIGNED CREATURES (need element assignment):")
        for _, creature in ipairs(unassigned.creatures) do
            table.insert(report, "  - " .. creature)
        end
    end

    return table.concat(report, "\n")
end

-- ============================================
-- CONSOLE COMMANDS (for debugging)
-- ============================================

-- Print scan results to console
function AssetScanner.printScan()
    local report = AssetScanner.generateReport()
    print(report)
end

-- Print generated code to console
function AssetScanner.printCode()
    local code = AssetScanner.generateUIAssetsCode()
    print(code)
end


-- =====================================================================
-- BACKWARD COMPATIBILITY
-- =====================================================================
-- Register sub-tables so that require("assetconfig"), require("assetloader"),
-- and require("assetscanner") all resolve to the correct sub-module tables.

package.loaded["assetconfig"] = AssetConfig
package.loaded["assetloader"] = AssetLoader
package.loaded["assetscanner"] = AssetScanner

return AssetPipeline
