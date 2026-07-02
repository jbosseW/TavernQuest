-- Save System - Multiple save slots with management

local SaveSystem = {}

-- Maximum number of save slots
SaveSystem.MAX_SLOTS = 3

-- Current active slot (1-3)
SaveSystem.activeSlot = 1

-- Default player data template
SaveSystem.defaultPlayerData = {
    coins = 100,
    crystals = 10,  -- New currency for fusion upgrades
    fusionUpgrades = {
        splinterChance = 0,    -- +2% per level (bonus random card)
        mirrorChance = 0,      -- +1% per level (duplicate result)
        bonusChips = 0,        -- +5 chips per level
        bonusMult = 0,         -- +1 mult per level
        catalystChance = 0,    -- +1% per level (skip rarity)
        prismaticChance = 0,   -- +1% per level (add mutation)
        echoChance = 0,        -- +1% per level (return source card)
        fortifyChance = 0,     -- +2% per level (extra fusion slot)
    },
    collection = {},
    decks = {},
    currentDeck = nil,
    wins = 0,
    losses = 0,
    totalGamesPlayed = 0,
    highestRound = 0,
    equippedJokers = {},
    unlockedModes = {"standard"},
    settings = {
        musicVolume = 0.3,
        sfxVolume = 0.5,
        fullscreen = true,
        musicMuted = false
    },
    stats = {
        totalChipsScored = 0,
        totalMultEarned = 0,
        handsPlayed = 0,
        bestHand = "",
        bestHandScore = 0
    },
    -- Crafting system
    craftingSkills = {
        forging = 0,   -- XP for forge crafting
        wizardry = 0,  -- XP for wizard tower
        alchemy = 0,   -- XP for alchemist
    },
    craftedItems = {},   -- List of crafted items with rarity/quality
    marketListings = {}, -- Items listed for sale on market
    -- Cafe/Wage mode
    cafeUpgrades = {
        traySize = 0,
        prepSpeed = 0,
        patience = 0,
        tips = 0,
        autoChef = 0,
        multiPrep = 0,
        reputation = 0,
        quality = 0,
        ambiance = 0,
    },
    cafeEmployees = {},  -- List of hired cafe employees
    cafeDay = 1,         -- Current day in cafe mode
    -- Passive income system
    passiveIncome = 0,         -- Gold per second from all sources
    lastPassiveUpdate = 0,     -- Timestamp of last passive income update
    passiveIncomeBreakdown = {}, -- Sources breakdown {stockMarket = 0, etc}
    -- Property ownership system
    properties = {
        townProperties = {},   -- Owned businesses and homes in towns
        landClaims = {},       -- Wild land claims
        settlements = {},      -- Upgraded settlements
    },
    -- Rumor system
    rumors = {
        active = {},           -- Currently circulating rumors
        archived = {},         -- Old rumors no longer spreading
        townKnowledge = {},    -- What each town "knows"
        lastUpdate = 0,        -- Last day rumors were updated
        serialKillers = {},    -- Active serial killer events
        merchantRoutes = {},   -- Merchant travel patterns
    },
    -- Town vampire lairs (hidden buildings during epidemics)
    townVampireLairs = {},     -- Town ID -> lair data
    -- Race unlock system (persists across all saves)
    unlockedRaces = {},        -- {raceId = true} for permanently unlocked races
    discoveredLocations = {},  -- {locationId = locationData} for auto-travel system
    autoTravelState = {        -- Current auto-travel state (persists across save/load)
        active = false,
        targetLocation = nil,
        path = {},
        currentStep = 1,
        travelMethod = nil,
        timer = 0,
        moveDelay = 0.3,
        paused = false,
        pauseReason = nil,
        totalDistance = 0,
        distanceTraveled = 0,
    },
    achievements = {},         -- {achievementId = true} for achievement-based unlocks
    -- Ascension system (prestige - ACCOUNT-WIDE, persists across all characters)
    ascensionCount = 0,        -- Number of times player has ascended
    ascensionPoints = 0,       -- Current AP to spend on Ascension Tree
    totalAPEarned = 0,         -- Lifetime AP earned
    ascensionTree = {          -- Ascension skill ranks and paths (STACKABLE!)
        skillRanks = {},       -- {skillId = rank} - how many times skill was upgraded
        skillPaths = {},       -- {skillId = "A" or "B"} - which path chosen
    },
    ascensionHistory = {},     -- Record of each ascension
    createdAt = 0,
    lastPlayed = 0,
    -- Additional game modes
    endlessRun = false,        -- Whether endless mode is active
    favoriteModes = {},        -- List of favorite game modes {modeId = true}
    progression = {}           -- General progression tracking for various systems
}

-- Initialize save system
function SaveSystem.init()
    -- Load active slot preference
    if love.filesystem.getInfo("activeslot.txt") then
        local content = love.filesystem.read("activeslot.txt")
        SaveSystem.activeSlot = tonumber(content) or 1
    end
end

-- Get save file name for a slot
function SaveSystem.getSaveFileName(slot)
    return string.format("save_slot_%d.lua", slot)
end

-- Check if a save slot exists
function SaveSystem.slotExists(slot)
    return love.filesystem.getInfo(SaveSystem.getSaveFileName(slot)) ~= nil
end

-- Get save slot info (for display in menu)
function SaveSystem.getSlotInfo(slot)
    local filename = SaveSystem.getSaveFileName(slot)
    if not love.filesystem.getInfo(filename) then
        return {
            exists = false,
            slot = slot
        }
    end

    -- Use pcall to handle corrupted save files gracefully
    local success, chunk = pcall(love.filesystem.load, filename)
    if success and chunk then
        -- Sandbox: restrict the chunk's environment to prevent code injection
        local sandbox = {}
        setfenv(chunk, sandbox)
        local ok, data = pcall(chunk)
        if ok and data then
            return {
                exists = true,
                slot = slot,
                wins = data.wins or 0,
                losses = data.losses or 0,
                coins = data.coins or 0,
                lastPlayed = data.lastPlayed or 0,
                totalGamesPlayed = data.totalGamesPlayed or 0
            }
        end
    end

    -- File exists but is corrupted
    return {exists = true, slot = slot, corrupted = true, wins = 0, losses = 0, coins = 0}
end

-- Load data from a specific slot
function SaveSystem.loadSlot(slot)
    local filename = SaveSystem.getSaveFileName(slot)
    if not love.filesystem.getInfo(filename) then
        -- Return default data for new slot
        local newData = SaveSystem.copyTable(SaveSystem.defaultPlayerData)
        newData.createdAt = os.time()
        newData.lastPlayed = os.time()
        return newData
    end

    -- Use pcall to handle corrupted save files gracefully
    local success, chunk = pcall(love.filesystem.load, filename)
    if success and chunk then
        -- Sandbox: restrict the chunk's environment to prevent code injection
        local sandbox = {}
        setfenv(chunk, sandbox)
        local ok, data = pcall(chunk)
        if ok and data then
            -- Merge with defaults to handle missing fields
            return SaveSystem.mergeWithDefaults(data)
        end
    end

    -- Try backup file
    local backupFilename = filename .. ".bak"
    if love.filesystem.getInfo(backupFilename) then
        print("Attempting to load backup save for slot " .. slot)
        local bSuccess, bChunk = pcall(love.filesystem.load, backupFilename)
        if bSuccess and bChunk then
            local sandbox = {}
            setfenv(bChunk, sandbox)
            local bOk, bData = pcall(bChunk)
            if bOk and bData then
                return SaveSystem.mergeWithDefaults(bData)
            end
        end
    end

    -- Return default if load fails (corrupted save)
    print("Warning: Save file corrupted, returning defaults for slot " .. slot)
    local newData = SaveSystem.copyTable(SaveSystem.defaultPlayerData)
    newData.createdAt = os.time()
    newData.lastPlayed = os.time()
    return newData
end

-- Save data to a specific slot (atomic write with backup)
function SaveSystem.saveSlot(slot, data)
    local filename = SaveSystem.getSaveFileName(slot)
    local backupFilename = filename .. ".bak"
    local tempFilename = filename .. ".tmp"
    data.lastPlayed = os.time()
    local content = "return " .. SaveSystem.serializeTable(data)

    -- Write to temp file first
    local success, err = pcall(function()
        love.filesystem.write(tempFilename, content)
    end)

    if not success then
        print("ERROR: Failed to write temp save for slot " .. slot .. ": " .. tostring(err))
        return false, err
    end

    -- Backup existing save (if it exists)
    if love.filesystem.getInfo(filename) then
        -- Remove old backup
        if love.filesystem.getInfo(backupFilename) then
            love.filesystem.remove(backupFilename)
        end
        -- Read current save and write as backup
        local currentContent = love.filesystem.read(filename)
        if currentContent then
            love.filesystem.write(backupFilename, currentContent)
        end
    end

    -- Move temp to actual save file
    -- LOVE doesn't have rename, so we read temp and write to final
    local tempContent = love.filesystem.read(tempFilename)
    if tempContent then
        local writeOk, writeErr = pcall(function()
            love.filesystem.write(filename, tempContent)
        end)
        if not writeOk then
            print("ERROR: Failed to finalize save for slot " .. slot .. ": " .. tostring(writeErr))
            return false, writeErr
        end
        love.filesystem.remove(tempFilename)
    else
        print("ERROR: Could not read temp file for slot " .. slot)
        return false, "temp file read failed"
    end

    return true
end

-- Save current player data to active slot
function SaveSystem.saveCurrentSlot(playerData)
    local success, err = SaveSystem.saveSlot(SaveSystem.activeSlot, playerData)
    if not success then
        print("WARNING: Failed to save current slot: " .. tostring(err))
    end
    return success, err
end

-- Switch active slot
function SaveSystem.switchSlot(slot)
    if slot >= 1 and slot <= SaveSystem.MAX_SLOTS then
        SaveSystem.activeSlot = slot
        love.filesystem.write("activeslot.txt", tostring(slot))
        return true
    end
    return false
end

-- Delete a save slot (full delete)
function SaveSystem.deleteSlot(slot)
    local filename = SaveSystem.getSaveFileName(slot)
    if love.filesystem.getInfo(filename) then
        love.filesystem.remove(filename)
        return true
    end
    return false
end

-- Soft delete - clear stats but keep collection/unlocks
function SaveSystem.softDeleteSlot(slot)
    local data = SaveSystem.loadSlot(slot)
    data.wins = 0
    data.losses = 0
    data.totalGamesPlayed = 0
    data.highestRound = 0
    data.coins = 100  -- Reset to starting coins
    data.stats = SaveSystem.copyTable(SaveSystem.defaultPlayerData.stats)
    SaveSystem.saveSlot(slot, data)
    return true
end

-- Copy table helper
function SaveSystem.copyTable(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            copy[k] = SaveSystem.copyTable(v)
        else
            copy[k] = v
        end
    end
    return copy
end

-- Merge loaded data with defaults (for backwards compatibility)
function SaveSystem.mergeWithDefaults(loaded)
    local result = SaveSystem.copyTable(SaveSystem.defaultPlayerData)

    local function merge(target, source)
        for k, v in pairs(source) do
            if type(v) == "table" and type(target[k]) == "table" then
                merge(target[k], v)
            elseif type(v) == "table" and type(target[k]) ~= "table" then
                -- Default is a table but saved value is not - use default to prevent corruption
                -- (Don't overwrite target[k], keep the default table)
            elseif type(v) ~= "table" and type(target[k]) == "table" then
                -- Saved value is not a table but default is - use default to prevent corruption
                -- (Don't overwrite target[k], keep the default table)
            else
                target[k] = v
            end
        end
    end

    merge(result, loaded)

    -- Migration: Convert old visitedLocations boolean map to discoveredLocations
    if loaded.visitedLocations and not loaded.discoveredLocations then
        result.discoveredLocations = {}
        -- Old visitedLocations was just {locationId = true}
        -- We can't recover full location data, but we can preserve the IDs as stub entries
        -- Users will need to rediscover for full location data, but at least we don't lose the list
        for locationId, visited in pairs(loaded.visitedLocations) do
            if visited then
                result.discoveredLocations[locationId] = {
                    id = locationId,
                    name = locationId,  -- Fallback name
                    type = "unknown",
                    x = 0,
                    y = 0,
                    layer = 0,
                    discoveredBy = "migration",
                    region = "Unknown",
                    icon = "?",
                    description = "Location migrated from old save format",
                    visited = true,
                    visitCount = 1,
                    lastVisited = 0,
                }
            end
        end
        -- Keep visitedLocations for backwards compatibility (don't delete user data)
        -- result.visitedLocations = nil  -- REMOVED: Don't delete old data
    end

    return result
end

-- Serialize table to string (with circular reference protection)
function SaveSystem.serializeTable(t, indent, visited)
    indent = indent or ""
    visited = visited or {}

    -- Circular reference protection
    if visited[t] then
        return '"[circular reference]"'
    end
    visited[t] = true

    local result = "{\n"
    local nextIndent = indent .. "  "

    for k, v in pairs(t) do
        local key
        if type(k) == "number" then
            key = "[" .. k .. "]"
        elseif type(k) == "string" then
            key = '["' .. tostring(k) .. '"]'
        else
            goto continue  -- Skip non-string/number keys
        end

        local value
        local vtype = type(v)
        if vtype == "table" then
            value = SaveSystem.serializeTable(v, nextIndent, visited)
        elseif vtype == "string" then
            value = '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t') .. '"'
        elseif vtype == "boolean" then
            value = tostring(v)
        elseif vtype == "number" then
            -- Handle NaN and Infinity which are not valid Lua literals
            if v ~= v then
                value = "0"  -- NaN -> 0 (safe default)
            elseif v == math.huge or v == -math.huge then
                value = "999999999"  -- Infinity -> large finite value
            else
                value = tostring(v)
            end
        else
            -- Skip functions, userdata, threads (would produce invalid Lua)
            goto continue
        end

        result = result .. nextIndent .. key .. " = " .. value .. ",\n"
        ::continue::
    end

    return result .. indent .. "}"
end

-- Get all slot infos
function SaveSystem.getAllSlotInfos()
    local slots = {}
    for i = 1, SaveSystem.MAX_SLOTS do
        table.insert(slots, SaveSystem.getSlotInfo(i))
    end
    return slots
end

return SaveSystem
