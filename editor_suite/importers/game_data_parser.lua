-- game_data_parser.lua - High-Level Game Data Importer
-- Reads Tavern Quest game source files and extracts all static data tables.
-- Uses LuaParser for safe extraction without executing game code.

local GameDataParser = {}
local LuaParser = require("importers.lua_parser")

-- ============================================================================
-- INTERNAL HELPERS
-- ============================================================================

--- Read a game file given the game root path and relative filename.
--- Tries the LOVE mounted "game/" virtual path first, then absolute path.
--- Returns file contents or nil + error.
local function readGameFile(gamePath, relPath)
    -- Try mounted "game/" virtual filesystem first (set up by AssetLoader.init)
    local mountedPath = "game/" .. relPath
    local content = LuaParser.readFile(mountedPath)
    if content then
        return content
    end

    -- Fallback to absolute path via io.open
    if gamePath then
        local fullPath = gamePath .. "/" .. relPath
        fullPath = fullPath:gsub("\\", "/"):gsub("//+", "/")
        return LuaParser.readFile(fullPath)
    end

    return nil, "No game path available and mounted path failed for: " .. relPath
end

--- Extract and evaluate a named table from a source string.
--- Returns the parsed Lua table or nil + error.
local function extractAndEval(source, tableName)
    local raw, err = LuaParser.extractTable(source, tableName)
    if not raw then
        return nil, err
    end
    local result, evalErr = LuaParser.evalTable(raw)
    if not result then
        return nil, "Failed to evaluate '" .. tableName .. "': " .. tostring(evalErr)
    end
    return result
end

--- Extract and evaluate a local table from a source string.
--- Returns the parsed Lua table or nil + error.
local function extractLocalAndEval(source, varName)
    local raw, err = LuaParser.extractLocalTable(source, varName)
    if not raw then
        return nil, err
    end
    local result, evalErr = LuaParser.evalTable(raw)
    if not result then
        return nil, "Failed to evaluate local '" .. varName .. "': " .. tostring(evalErr)
    end
    return result
end

-- ============================================================================
-- SOURCE CACHING
-- ============================================================================

-- Cache source files to avoid re-reading them for multiple table extractions
local _sourceCache = {}

--- Get the source contents of a game file, using cache.
local function getSource(gamePath, relPath)
    local key = tostring(gamePath) .. "::" .. relPath
    if _sourceCache[key] then
        return _sourceCache[key]
    end
    local source, err = readGameFile(gamePath, relPath)
    if not source then
        return nil, err
    end
    _sourceCache[key] = source
    return source
end

--- Clear the source cache (call after a full import or when files change).
function GameDataParser.clearCache()
    _sourceCache = {}
end

-- ============================================================================
-- INDIVIDUAL PARSERS
-- ============================================================================

--- Parse Backpack.ITEMS from backpack.lua.
--- Returns an array of item tables, or nil + error.
function GameDataParser.parseItems(gamePath)
    local source, err = getSource(gamePath, "backpack.lua")
    if not source then return nil, err end
    return extractAndEval(source, "Backpack.ITEMS")
end

--- Parse Data.ENEMIES from rpg_data.lua.
--- Returns an array of enemy tables, or nil + error.
function GameDataParser.parseEnemies(gamePath)
    local source, err = getSource(gamePath, "rpg_data.lua")
    if not source then return nil, err end
    return extractAndEval(source, "Data.ENEMIES")
end

--- Parse Data.CLASSES from rpg_data.lua.
--- Returns an array of class tables, or nil + error.
function GameDataParser.parseClasses(gamePath)
    local source, err = getSource(gamePath, "rpg_data.lua")
    if not source then return nil, err end
    return extractAndEval(source, "Data.CLASSES")
end

--- Parse Data.RACES from rpg_data.lua.
--- Returns a table with .base (Data.RACES) and .unlockable (Data.UNLOCKABLE_RACES).
function GameDataParser.parseRaces(gamePath)
    local source, err = getSource(gamePath, "rpg_data.lua")
    if not source then return nil, err end

    local baseRaces, err1 = extractAndEval(source, "Data.RACES")
    local unlockableRaces, err2 = extractAndEval(source, "Data.UNLOCKABLE_RACES")

    if not baseRaces and not unlockableRaces then
        return nil, "Could not parse races: " .. tostring(err1) .. " / " .. tostring(err2)
    end

    return {
        base = baseRaces or {},
        unlockable = unlockableRaces or {},
    }
end

--- Parse Data.BACKGROUNDS from rpg_data.lua.
--- Returns an array of background tables, or nil + error.
function GameDataParser.parseBackgrounds(gamePath)
    local source, err = getSource(gamePath, "rpg_data.lua")
    if not source then return nil, err end
    return extractAndEval(source, "Data.BACKGROUNDS")
end

--- Parse NPC_TEMPLATES from rpg_npc.lua.
--- Note: NPC_TEMPLATES is a local variable in rpg_npc.lua.
--- Returns a table keyed by profession name, or nil + error.
function GameDataParser.parseNPCTemplates(gamePath)
    local source, err = getSource(gamePath, "rpg_npc.lua")
    if not source then return nil, err end
    return extractLocalAndEval(source, "NPC_TEMPLATES")
end

--- Parse NPC_SCHEDULE_TEMPLATES from rpg_npc.lua.
--- Note: NPC_SCHEDULE_TEMPLATES is a local variable.
--- Returns a table keyed by profession name, or nil + error.
function GameDataParser.parseNPCSchedules(gamePath)
    local source, err = getSource(gamePath, "rpg_npc.lua")
    if not source then return nil, err end
    return extractLocalAndEval(source, "NPC_SCHEDULE_TEMPLATES")
end

--- Parse QUEST_TEMPLATES from rpg_npc.lua.
--- Note: QUEST_TEMPLATES is a local variable.
--- Returns a table keyed by NPC profession, each containing an array of quests.
function GameDataParser.parseQuestTemplates(gamePath)
    local source, err = getSource(gamePath, "rpg_npc.lua")
    if not source then return nil, err end
    return extractLocalAndEval(source, "QUEST_TEMPLATES")
end

--- Parse LoreBooks.BOOKS from lore_books.lua.
--- Note: This table contains references like LoreBooks.LOCATIONS.BURIED_ARCHIVE.
--- The parser converts these to string representations automatically.
--- Returns an array of book tables, or nil + error.
function GameDataParser.parseLoreBooks(gamePath)
    local source, err = getSource(gamePath, "lore_books.lua")
    if not source then return nil, err end

    -- First, parse the LOCATIONS table so we can resolve references
    local locations = extractAndEval(source, "LoreBooks.LOCATIONS")

    -- Parse the books
    local books, booksErr = extractAndEval(source, "LoreBooks.BOOKS")
    if not books then
        return nil, booksErr
    end

    -- Resolve location references: findLocation values will be strings like
    -- "LoreBooks.LOCATIONS.BURIED_ARCHIVE" after stubbing. We resolve these
    -- to the actual string values from the LOCATIONS table.
    if locations then
        for _, book in ipairs(books) do
            if type(book.findLocation) == "string" then
                local ref = book.findLocation
                -- Try to resolve "LoreBooks.LOCATIONS.KEY" -> locations[KEY]
                local key = ref:match("^LoreBooks%.LOCATIONS%.(.+)$")
                if key and locations[key] then
                    book.findLocation = locations[key]
                end
            end
        end
    end

    return books
end

--- Parse Data.SKILLS from rpg_data.lua.
--- Returns a table keyed by skill name, or nil + error.
function GameDataParser.parseSkills(gamePath)
    local source, err = getSource(gamePath, "rpg_data.lua")
    if not source then return nil, err end
    return extractAndEval(source, "Data.SKILLS")
end

--- Parse Data.portraitMappings from rpg_data.lua.
--- Returns a table mapping portrait keys to asset paths, or nil + error.
function GameDataParser.parsePortraitMappings(gamePath)
    local source, err = getSource(gamePath, "rpg_data.lua")
    if not source then return nil, err end
    return extractAndEval(source, "Data.portraitMappings")
end

--- Parse Backpack.CATEGORIES from backpack.lua.
--- Returns an array of category name strings, or nil + error.
function GameDataParser.parseItemCategories(gamePath)
    local source, err = getSource(gamePath, "backpack.lua")
    if not source then return nil, err end
    return extractAndEval(source, "Backpack.CATEGORIES")
end

--- Parse Backpack.CARTS from backpack.lua.
--- Returns an array of cart definition tables, or nil + error.
function GameDataParser.parseCarts(gamePath)
    local source, err = getSource(gamePath, "backpack.lua")
    if not source then return nil, err end
    return extractAndEval(source, "Backpack.CARTS")
end

--- Parse Backpack.BEASTS_OF_BURDEN from backpack.lua.
--- Returns an array of beast tables, or nil + error.
function GameDataParser.parseBeastsOfBurden(gamePath)
    local source, err = getSource(gamePath, "backpack.lua")
    if not source then return nil, err end
    return extractAndEval(source, "Backpack.BEASTS_OF_BURDEN")
end

--- Parse Data.CLASS_PORTRAIT_OPTIONS from rpg_data.lua.
--- Returns a table keyed by class id, or nil + error.
function GameDataParser.parseClassPortraits(gamePath)
    local source, err = getSource(gamePath, "rpg_data.lua")
    if not source then return nil, err end
    return extractAndEval(source, "Data.CLASS_PORTRAIT_OPTIONS")
end

--- Parse LoreBooks.LOCATIONS from lore_books.lua.
--- Returns a table of location name -> location id, or nil + error.
function GameDataParser.parseLoreLocations(gamePath)
    local source, err = getSource(gamePath, "lore_books.lua")
    if not source then return nil, err end
    return extractAndEval(source, "LoreBooks.LOCATIONS")
end

--- Parse REGIONS from worldgen.lua.
--- Returns the regions table keyed by region id, or nil + error.
function GameDataParser.parseRegions(gamePath)
    local source, err = getSource(gamePath, "worldgen.lua")
    if not source then return nil, err end
    return extractLocalAndEval(source, "REGIONS")
end

--- Parse ANCHOR_TOWNS from worldgen.lua.
--- Returns an array of anchor town definitions, or nil + error.
function GameDataParser.parseAnchorTowns(gamePath)
    local source, err = getSource(gamePath, "worldgen.lua")
    if not source then return nil, err end
    return extractLocalAndEval(source, "ANCHOR_TOWNS")
end

--- Parse REGION_DUNGEON_WEIGHTS from worldgen.lua.
--- Returns a table keyed by region id with dungeon type weights, or nil + error.
function GameDataParser.parseRegionDungeonWeights(gamePath)
    local source, err = getSource(gamePath, "worldgen.lua")
    if not source then return nil, err end
    return extractLocalAndEval(source, "REGION_DUNGEON_WEIGHTS")
end

-- ============================================================================
-- BULK IMPORT
-- ============================================================================

--- Import all available game data at once.
--- gamePath should be the absolute path to the game root directory.
--- Returns a table with all parsed data, plus an `errors` sub-table
--- listing any tables that failed to parse.
function GameDataParser.importAll(gamePath)
    local errors = {}

    local function safeCall(name, fn, ...)
        local result, err = fn(...)
        if not result then
            errors[name] = tostring(err)
        end
        return result
    end

    local data = {
        items = safeCall("items", GameDataParser.parseItems, gamePath),
        enemies = safeCall("enemies", GameDataParser.parseEnemies, gamePath),
        classes = safeCall("classes", GameDataParser.parseClasses, gamePath),
        races = safeCall("races", GameDataParser.parseRaces, gamePath),
        backgrounds = safeCall("backgrounds", GameDataParser.parseBackgrounds, gamePath),
        npcs = safeCall("npcs", GameDataParser.parseNPCTemplates, gamePath),
        schedules = safeCall("schedules", GameDataParser.parseNPCSchedules, gamePath),
        quests = safeCall("quests", GameDataParser.parseQuestTemplates, gamePath),
        lore = safeCall("lore", GameDataParser.parseLoreBooks, gamePath),
        skills = safeCall("skills", GameDataParser.parseSkills, gamePath),
        portraits = safeCall("portraits", GameDataParser.parsePortraitMappings, gamePath),
        itemCategories = safeCall("itemCategories", GameDataParser.parseItemCategories, gamePath),
        carts = safeCall("carts", GameDataParser.parseCarts, gamePath),
        beasts = safeCall("beasts", GameDataParser.parseBeastsOfBurden, gamePath),
        classPortraits = safeCall("classPortraits", GameDataParser.parseClassPortraits, gamePath),
        loreLocations = safeCall("loreLocations", GameDataParser.parseLoreLocations, gamePath),
        regions = safeCall("regions", GameDataParser.parseRegions, gamePath),
        anchorTowns = safeCall("anchorTowns", GameDataParser.parseAnchorTowns, gamePath),
        regionDungeonWeights = safeCall("regionDungeonWeights", GameDataParser.parseRegionDungeonWeights, gamePath),
    }

    data.errors = errors
    GameDataParser.clearCache()

    return data
end

--- Print a summary of an import result (for debugging).
function GameDataParser.printSummary(data)
    print("=== Game Data Import Summary ===")

    local function countEntries(tbl)
        if not tbl then return 0 end
        if tbl[1] ~= nil then
            return #tbl
        end
        local count = 0
        for _ in pairs(tbl) do count = count + 1 end
        return count
    end

    local datasets = {
        {"Items", data.items},
        {"Enemies", data.enemies},
        {"Classes", data.classes},
        {"Base Races", data.races and data.races.base},
        {"Unlockable Races", data.races and data.races.unlockable},
        {"Backgrounds", data.backgrounds},
        {"NPC Templates", data.npcs},
        {"NPC Schedules", data.schedules},
        {"Quest Templates", data.quests},
        {"Lore Books", data.lore},
        {"Skills", data.skills},
        {"Portrait Mappings", data.portraits},
        {"Item Categories", data.itemCategories},
        {"Carts", data.carts},
        {"Beasts of Burden", data.beasts},
        {"Class Portraits", data.classPortraits},
        {"Lore Locations", data.loreLocations},
        {"Regions", data.regions},
        {"Anchor Towns", data.anchorTowns},
        {"Region Dungeon Weights", data.regionDungeonWeights},
    }

    for _, entry in ipairs(datasets) do
        local name, tbl = entry[1], entry[2]
        if tbl then
            print(string.format("  %-25s %d entries", name, countEntries(tbl)))
        else
            print(string.format("  %-25s FAILED", name))
        end
    end

    if data.errors and next(data.errors) then
        print("\n=== Errors ===")
        for name, err in pairs(data.errors) do
            print(string.format("  %s: %s", name, err))
        end
    else
        print("\nAll imports succeeded.")
    end
end

return GameDataParser
