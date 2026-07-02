-- RPG World System
-- Extracted from textrpg.lua
-- Contains: world generation, map helpers, town generation, tile/terrain,
-- desert biomes, player movement, water events, and map expansion.

local Data = require("rpg_data")
local Backpack = require("backpack")
local WorldGen = require("worldgen")
local TownGen = require("towngen")
local MapEnemies = require("mapenemies")
local LuminaryPatrols = require("luminarypatrols")

local M = {}

-- Upvalues set by register()
local state
local F

-- Data references (set during register from textrpg locals)
local TOWN_PREFIXES
local TOWN_SUFFIXES
local NPC_FIRST_NAMES
local ENEMY_TIERS
local NPC_PROFESSIONS
local QUEST_ITEMS
local LOCATION_NAMES
local TILE_TYPES
local TRADE_GOODS
local TOWN_SPECIALIZATIONS
local SEA_ENEMIES
local WATER_EVENTS
local SEA_MERCHANT_GOODS
local DEBRIS_LOOT
local UNDEAD_ENEMY_IDS

-- Forward-declared locals for internal cross-references
local log
local generateTownName
local generateNPCName
local getEnemyTierForLevel
local generateQuest
local isInList
local generateTownNPCs
local generateTown
local convertAnchorToLegacyTown
local getTileType
local generateNewTile
local expandMap
local spawnRandomTown
local spawnDesertSettlement
local generateDesertSettlement
local generateDesertSettlementName
local generateDesertNPCs
local generateDesertShopInventory
local generateDesertQuest
local cleanupDistantTiles
local rollWaterEvent
local handleWaterEvent

-- Cache for market good icons
local marketIconCache = {}

M.F_FUNCTIONS = {
    "generateTownName", "generateNPCName", "getEnemyTierForLevel",
    "generateQuest", "generateBountyQuest", "generateBountyBoard",
    "generateCourierQuest", "generateCourierBoard",
    "generateTownNPCs", "isInList", "generateTown",
    "generateTownLayout", "convertAnchorToLegacyTown",
    "getTileFromWorldGen", "setTileInWorldGen",
    "generateMap", "generateMapLegacy",
    "rollWaterEvent", "handleWaterEvent",
    "getTileType", "generateNewTile",
    "generateDesertBiome", "generateDesertSettlement",
    "spawnRandomTown", "spawnDesertSettlement",
    "cleanupDistantTiles", "expandMap",
    "movePlayer",
    "getMarketIcon",
}

function M.register(s, f, deps)
    state = s
    F = f
    TOWN_PREFIXES = deps.TOWN_PREFIXES
    TOWN_SUFFIXES = deps.TOWN_SUFFIXES
    NPC_FIRST_NAMES = deps.NPC_FIRST_NAMES or Data.NPC_FIRST_NAMES
    ENEMY_TIERS = deps.ENEMY_TIERS or Data.ENEMY_TIERS
    NPC_PROFESSIONS = deps.NPC_PROFESSIONS or Data.NPC_PROFESSIONS
    QUEST_ITEMS = deps.QUEST_ITEMS
    LOCATION_NAMES = deps.LOCATION_NAMES
    TILE_TYPES = deps.TILE_TYPES or Data.TILE_TYPES
    TRADE_GOODS = deps.TRADE_GOODS
    TOWN_SPECIALIZATIONS = deps.TOWN_SPECIALIZATIONS
    SEA_ENEMIES = deps.SEA_ENEMIES
    WATER_EVENTS = deps.WATER_EVENTS
    SEA_MERCHANT_GOODS = deps.SEA_MERCHANT_GOODS
    DEBRIS_LOOT = deps.DEBRIS_LOOT
    UNDEAD_ENEMY_IDS = deps.UNDEAD_ENEMY_IDS

    log = deps.log

    for _, name in ipairs(M.F_FUNCTIONS) do
        if M[name] then
            F[name] = M[name]
        end
    end

    -- Set up module-local forward references so internal calls work
    generateTownName = M.generateTownName
    generateNPCName = M.generateNPCName
    getEnemyTierForLevel = M.getEnemyTierForLevel
    generateQuest = M.generateQuest
    isInList = M.isInList
    generateTownNPCs = M.generateTownNPCs
    generateTown = M.generateTown
    convertAnchorToLegacyTown = M.convertAnchorToLegacyTown
    getTileType = M.getTileType
    generateNewTile = M.generateNewTile
    expandMap = M.expandMap
    spawnRandomTown = M.spawnRandomTown
    spawnDesertSettlement = M.spawnDesertSettlement
    generateDesertSettlement = M.generateDesertSettlement
    cleanupDistantTiles = M.cleanupDistantTiles
    rollWaterEvent = M.rollWaterEvent
    handleWaterEvent = M.handleWaterEvent
end

-- ============================================================================
-- MARKET ICON HELPER
-- ============================================================================

M.getMarketIcon = function(iconPath)
    if not iconPath then return nil end
    if marketIconCache[iconPath] then return marketIconCache[iconPath] end
    local success, img = pcall(function()
        return love.graphics.newImage(iconPath)
    end)
    if success then
        marketIconCache[iconPath] = img
        return img
    end
    return nil
end

-- ============================================================================
-- TOWN NAME / NPC NAME GENERATORS
-- ============================================================================

M.generateTownName = function()
    return TOWN_PREFIXES[math.random(#TOWN_PREFIXES)] .. TOWN_SUFFIXES[math.random(#TOWN_SUFFIXES)]
end

M.generateNPCName = function()
    return NPC_FIRST_NAMES[math.random(#NPC_FIRST_NAMES)]
end

-- ============================================================================
-- ENEMY TIER FOR LEVEL
-- ============================================================================

M.getEnemyTierForLevel = function(level)
    for _, tier in ipairs(ENEMY_TIERS) do
        if level >= tier.minLevel and level <= tier.maxLevel then
            return tier
        end
    end
    return ENEMY_TIERS[#ENEMY_TIERS]  -- Return highest tier if level is very high
end

-- ============================================================================
-- QUEST GENERATION
-- ============================================================================

M.generateQuest = function(giverName, giverProfession, playerLevel)
    local questTypes = giverProfession.questTypes or {"kill"}
    local questType = questTypes[math.random(#questTypes)]

    local quest = {
        type = questType,
        level = playerLevel,
        giver = giverName,
        accepted = false,
        completed = false,
        progress = 0,
    }

    -- Scale rewards to level
    local baseGold = 30 + playerLevel * 15
    local baseXP = 50 + playerLevel * 25

    if questType == "kill" then
        local tier = getEnemyTierForLevel(playerLevel)
        local enemy = tier.enemies[math.random(#tier.enemies)]
        local count = math.random(3, 5 + math.floor(playerLevel / 3))

        quest.name = "Hunt " .. enemy.name .. "s"
        quest.desc = "Defeat " .. count .. " " .. enemy.name .. "s in the wilderness."
        quest.target = count
        quest.enemyId = enemy.id
        quest.rewardGold = math.floor(baseGold * 1.2)
        quest.rewardXP = math.floor(baseXP * 1.3)

    elseif questType == "fetch" then
        local item = QUEST_ITEMS[math.random(#QUEST_ITEMS)]
        local count = math.random(2, 4 + math.floor(playerLevel / 4))

        quest.name = "Gather " .. item
        quest.desc = "Collect " .. count .. " " .. item .. " and return to " .. giverName .. "."
        quest.target = count
        quest.itemName = item
        quest.rewardGold = math.floor(baseGold * 1.0)
        quest.rewardXP = math.floor(baseXP * 1.0)

    elseif questType == "talk" then
        local targetName = generateNPCName()
        local location = LOCATION_NAMES[math.random(#LOCATION_NAMES)]

        quest.name = "Find " .. targetName
        quest.desc = "Travel to " .. location .. " and speak with " .. targetName .. "."
        quest.target = 1
        quest.targetName = targetName
        quest.location = location
        quest.rewardGold = math.floor(baseGold * 0.8)
        quest.rewardXP = math.floor(baseXP * 1.1)

    elseif questType == "deliver" then
        local item = QUEST_ITEMS[math.random(#QUEST_ITEMS)]
        local targetName = generateNPCName()

        quest.name = "Deliver " .. item
        quest.desc = "Deliver " .. item .. " to " .. targetName .. " in another town."
        quest.target = 1
        quest.itemName = item
        quest.targetName = targetName
        quest.rewardGold = math.floor(baseGold * 1.1)
        quest.rewardXP = math.floor(baseXP * 0.9)

    elseif questType == "bounty" then
        -- BOUNTY QUEST: Hunt a criminal NPC, capture or kill them, return to jail
        local criminalNames = {"Blackfinger Voss", "Red Mara", "The Butcher of Kragmor", "Silent Dirk",
            "Greycoat Mordecai", "Iron Teeth Grul", "The Whisperer", "Bloody Helena", "One-Eye Skarn",
            "Shadow Dane", "Corpse-Maker Kell", "Frostbite Nyx", "The Rat King", "Venom Sal",
            "Deadlock Thorn", "Ashhand Vek", "The Collector", "Marrow Spite", "Gilt-Tongue Rex"}
        local criminalCrimes = {"murder", "arson", "grand theft", "smuggling", "kidnapping",
            "treason", "piracy", "extortion", "poisoning", "assassination",
            "slave trading", "necromancy", "sedition", "banditry"}
        local criminalLocations = {"hiding in the wilderness", "lurking near trade routes",
            "sheltering in a bandit camp", "spotted near the border", "last seen heading east",
            "operating from a cave", "disguised as a merchant", "protected by thugs"}
        local criminalName = criminalNames[math.random(#criminalNames)]
        local crime = criminalCrimes[math.random(#criminalCrimes)]
        local location = criminalLocations[math.random(#criminalLocations)]
        local difficultyMult = 1.0 + (playerLevel * 0.1)

        quest.name = "Bounty: " .. criminalName
        quest.desc = "WANTED: " .. criminalName .. " for " .. crime .. ". Last known to be " .. location .. ". Capture alive for full bounty, or bring proof of death for half."
        quest.target = 1
        quest.criminalName = criminalName
        quest.crime = crime
        quest.bountyReward = math.floor(baseGold * 2.0 * difficultyMult)
        quest.bountyRewardDead = math.floor(baseGold * 1.0 * difficultyMult)
        quest.rewardGold = quest.bountyReward  -- Full bounty for alive capture
        quest.rewardXP = math.floor(baseXP * 1.5)
        quest.criminalLevel = playerLevel + math.random(0, 2)
        quest.criminalHP = math.floor(40 + quest.criminalLevel * 12)
        quest.criminalAttack = math.floor(8 + quest.criminalLevel * 3)
        quest.captureAlive = false  -- Set to true when player captures alive
        quest.questType = "bounty"
        quest.compassTarget = true  -- Show on compass

    elseif questType == "courier" then
        -- COURIER QUEST: Deliver a message/package to a specific nearby town
        local packageTypes = {"sealed letter", "diplomatic pouch", "merchant ledger", "urgent message",
            "rare medicine", "enchanted scroll", "noble's invitation", "guild communique",
            "military dispatch", "love letter", "trade contract", "ancient map fragment",
            "alchemical sample", "court summons", "religious relic"}
        local urgencyLevels = {
            {name = "Standard", timeMult = 1.0, goldMult = 1.0, desc = "Deliver at your convenience."},
            {name = "Urgent", timeMult = 0.7, goldMult = 1.5, desc = "Time-sensitive - deliver quickly!"},
            {name = "Critical", timeMult = 0.4, goldMult = 2.5, desc = "URGENT - deliver immediately or face penalties!"},
        }
        local package = packageTypes[math.random(#packageTypes)]
        local urgency = urgencyLevels[math.random(#urgencyLevels)]
        local targetName = generateNPCName()
        local location = LOCATION_NAMES[math.random(#LOCATION_NAMES)]

        quest.name = "Courier: " .. package
        quest.desc = urgency.name .. " delivery: Carry a " .. package .. " to " .. targetName .. " in " .. location .. ". " .. urgency.desc
        quest.target = 1
        quest.itemName = package
        quest.targetName = targetName
        quest.location = location
        quest.urgency = urgency.name
        quest.rewardGold = math.floor(baseGold * 0.9 * urgency.goldMult)
        quest.rewardXP = math.floor(baseXP * 0.7)
        quest.timeLimit = urgency.timeMult > 0 and math.floor(48 * urgency.timeMult) or nil  -- Hours to complete
        quest.questType = "courier"
        quest.compassTarget = true  -- Show on compass
    end

    return quest
end

-- ============================================================================
-- BOUNTY QUEST SYSTEM
-- ============================================================================
-- Generates bounty-specific quests for the bounty board

M.generateBountyQuest = function(playerLevel)
    local prof = {questTypes = {"bounty"}}
    return F.generateQuest("Bounty Board", prof, playerLevel)
end

-- Generate bounty board content for a city
M.generateBountyBoard = function(cityLevel, count)
    count = count or math.random(3, 6)
    local bounties = {}
    for i = 1, count do
        local bounty = F.generateBountyQuest(cityLevel + math.random(-1, 2))
        bounty.boardIndex = i
        table.insert(bounties, bounty)
    end
    return bounties
end

-- ============================================================================
-- COURIER QUEST SYSTEM
-- ============================================================================
-- Generates courier-specific quests for the courier office

M.generateCourierQuest = function(playerLevel)
    local prof = {questTypes = {"courier"}}
    return F.generateQuest("Courier Office", prof, playerLevel)
end

-- Generate courier office content for a city
M.generateCourierBoard = function(cityLevel, count)
    count = count or math.random(2, 5)
    local deliveries = {}
    for i = 1, count do
        local courier = F.generateCourierQuest(cityLevel + math.random(-1, 1))
        courier.boardIndex = i
        table.insert(deliveries, courier)
    end
    return deliveries
end

-- ============================================================================
-- TOWN NPC GENERATION
-- ============================================================================

M.generateTownNPCs = function(townLevel)
    local npcs = {}
    local npcCount = math.random(4, 7)
    local usedProfessions = {}

    -- Always include an elder
    local elderProf = nil
    for _, prof in ipairs(NPC_PROFESSIONS) do
        if prof.isElder then elderProf = prof break end
    end

    local elderNPC = {
        name = generateNPCName(),
        profession = elderProf,
        hasQuest = true,
        quest = nil,  -- Will be generated on demand
    }
    table.insert(npcs, elderNPC)
    usedProfessions["elder"] = true

    -- Add other NPCs
    for i = 2, npcCount do
        local prof
        repeat
            prof = NPC_PROFESSIONS[math.random(#NPC_PROFESSIONS)]
        until not usedProfessions[prof.id] and not prof.isElder
        usedProfessions[prof.id] = true

        local npc = {
            name = generateNPCName(),
            profession = prof,
            hasQuest = math.random() < 0.6,  -- 60% chance to have a quest
            quest = nil,
        }
        table.insert(npcs, npc)
    end

    return npcs
end

-- ============================================================================
-- HELPER: IS IN LIST
-- ============================================================================

M.isInList = function(item, list)
    for _, v in ipairs(list) do
        if v == item then return true end
    end
    return false
end

-- ============================================================================
-- SHOP INVENTORY GENERATION (shared by generateTown & convertAnchorToLegacyTown)
-- ============================================================================

-- Generate a shop inventory by randomly picking unique items from a pool,
-- scaling stats by the given level.
local function generateShopInventory(pool, count, level)
    local inventory = {}
    local usedItems = {}
    for i = 1, math.min(count, #pool) do
        local itemId = pool[math.random(#pool)]
        local attempts = 0
        while usedItems[itemId] and attempts < 20 do
            itemId = pool[math.random(#pool)]
            attempts = attempts + 1
        end
        usedItems[itemId] = true

        local itemDef = Backpack.getItemDef(itemId)
        if itemDef then
            local stats = itemDef.baseStats or {}
            table.insert(inventory, {
                backpackId = itemId,
                name = itemDef.name,
                category = itemDef.category,
                icon = itemDef.icon,
                attack = stats.attack and math.floor(stats.attack * (1 + level * 0.15)),
                defense = stats.defense and math.floor(stats.defense * (1 + level * 0.15)),
                heal = stats.heal or stats.healing,
                mana = stats.mana or stats.manaRestore,
                value = math.floor((itemDef.sellValue or 25) * (1 + level * 0.2) * 2),
                desc = itemDef.desc,
            })
        end
    end
    return inventory
end

-- ============================================================================
-- TOWN GENERATION
-- ============================================================================

M.generateTown = function(x, y, level)
    -- Pick a random specialization for this town
    local specialization = TOWN_SPECIALIZATIONS[math.random(#TOWN_SPECIALIZATIONS)]

    -- Determine region from coordinates
    local townRegion = nil
    local ok, WG = pcall(require, "worldgen")
    if ok and WG and WG.getRegionAt then
        local region, subregion = WG.getRegionAt(x, y)
        if subregion and subregion.id then
            townRegion = subregion.id
        elseif region and region.id then
            townRegion = region.id
        end
    end

    local town = {
        name = generateTownName(),
        level = level,
        x = x,
        y = y,
        npcs = generateTownNPCs(level),
        shop = {},
        jobBoard = {},
        specialization = specialization.name,
        market = {},
        region = townRegion,
    }

    -- Generate market prices based on specialization
    for _, good in ipairs(TRADE_GOODS) do
        local priceMultiplier = 1.0
        if isInList(good.id, specialization.produces) then
            priceMultiplier = 0.6 + math.random() * 0.2
        elseif isInList(good.category, specialization.consumes) or isInList(good.id, specialization.consumes) then
            priceMultiplier = 1.3 + math.random() * 0.3
        else
            priceMultiplier = 0.85 + math.random() * 0.3
        end
        priceMultiplier = priceMultiplier * (0.9 + math.random() * 0.2)
        local price = math.floor(good.basePrice * priceMultiplier)
        table.insert(town.market, {
            id = good.id,
            name = good.name,
            category = good.category,
            icon = good.icon,
            buyPrice = price,
            sellPrice = math.floor(price * 0.8),
            stock = math.random(5, 20),
        })
    end

    -- Shop inventories for each store type
    local shopPools = {
        general = {
            "tq_health_potion", "tq_mana_potion", "tq_elixir",
            "tq_rusty_sword", "tq_iron_sword", "tq_cloth_armor", "tq_leather_armor",
            "health_potion", "mana_potion",
            -- Tools
            "woodcutter_axe", "iron_saw", "steel_lumber_axe", "pickaxe", "steel_pickaxe",
        },
        butcher = {
            "tq_raw_steak", "tq_salted_meat", "tq_smoked_sausage", "tq_beef_jerky",
            "tq_prime_cut", "tq_monster_steak",
        },
        bakery = {
            "tq_bread_loaf", "tq_sweet_roll", "tq_meat_pie", "tq_honeycake",
            "tq_elven_waybread", "tq_adventure_rations",
        },
        tailor = {
            "tq_traveler_cloak", "tq_fine_tunic", "tq_noble_garb", "tq_ranger_hood",
            "tq_silk_gloves", "tq_sturdy_boots", "tq_enchanted_cape",
            "tq_cloth_armor", "tq_leather_armor",
        },
        jeweler = {
            "tq_copper_ring", "tq_silver_ring", "tq_gold_ring",
            "tq_ruby_amulet", "tq_sapphire_pendant", "tq_emerald_brooch",
            "tq_diamond_earring", "tq_lucky_charm", "tq_protection_talisman",
        },
    }

    -- Generate inventories for each shop type (uses shared generateShopInventory)
    town.shops = {
        general = generateShopInventory(shopPools.general, math.random(5, 8), level),
        butcher = generateShopInventory(shopPools.butcher, math.random(4, 6), level),
        bakery = generateShopInventory(shopPools.bakery, math.random(4, 6), level),
        tailor = generateShopInventory(shopPools.tailor, math.random(5, 7), level),
        jeweler = generateShopInventory(shopPools.jeweler, math.random(5, 7), level),
    }

    -- Keep town.shop as alias for general store (backwards compatibility)
    town.shop = town.shops.general

    -- Generate job board quests (3-5 quests)
    for i = 1, math.random(3, 5) do
        local prof = NPC_PROFESSIONS[math.random(#NPC_PROFESSIONS)]
        local quest = generateQuest("Job Board", prof, level)
        table.insert(town.jobBoard, quest)
    end

    -- PROCEDURAL LAYOUT GENERATION (skip for anchor towns/capitals)
    -- Generate creative town layouts with streets, buildings, rivers, and variety
    -- Uses the TownGen module for regional theming and varied layouts
    if not town.isAnchorTown and town.type ~= "capital" and town.type ~= "mega_city" then
        -- Create a deterministic seed from town position for reproducible layouts
        local townSeed = (x or 0) * 73856093 + (y or 0) * 19349663 + (level or 1) * 83492791
        town.layout = TownGen.generateTownLayout(level, specialization, townRegion, townSeed)

        -- Generate per-town building variety
        local themeKey = TownGen.getThemeKey(townRegion)
        local buildingSeed = townSeed + 777
        local buildingData = TownGen.generateTownBuildings({
            level = level,
            population = town.layout and town.layout.population or nil,
            sizeCategory = town.layout and town.layout.sizeCategory or nil,
            regionTheme = themeKey,
            specialization = specialization,
            isAnchor = false,
            seed = buildingSeed,
        })
        if buildingData then
            town.townBuildings = buildingData.buildings
            town.townGridCols = buildingData.gridCols
            town.townGridRows = buildingData.gridRows
            town.townStreetCol = buildingData.streetCol
            town.townStreetRows = buildingData.streetRows
        end
    end

    return town
end

-- ============================================================================
--                   PROCEDURAL TOWN LAYOUT GENERATION
-- ============================================================================
-- Now delegated to the TownGen module (towngen.lua) for regional theming,
-- varied layouts (12+ types), natural features (rivers, gardens, docks),
-- and deterministic seed-based generation.
-- NOTE: Does NOT affect anchor cities or capitals

M.generateTownLayout = function(level, specialization, regionId, townSeed)
    -- Delegate to the TownGen module which supports:
    --   12+ layout types (circular, linear, clustered, small_riverside,
    --     grid, radial, organic, riverside, split, fortified, terraced,
    --     plaza, district, walled, plaza_centric, canal)
    --   7 regional themes (desert, forest, mountain, swamp, coastal, plains, frozen)
    --   Natural features (rivers, bridges, gardens, ponds, docks, boardwalks)
    --   Deterministic generation from seeds
    local layout = TownGen.generateTownLayout(level, specialization, regionId, townSeed)
    -- Return in a format compatible with existing code
    return TownGen.toLegacyLayout(layout)
end

-- ============================================================================
--                      WORLDGEN INTEGRATION
-- ============================================================================

-- Convert WorldGen anchor town to legacy town format for UI compatibility
M.convertAnchorToLegacyTown = function(anchorTown)
    if not anchorTown then return nil end

    -- If it's already a legacy town (has shops), return as-is
    if anchorTown.shops then
        return anchorTown
    end

    -- Create legacy-compatible town from anchor town
    local town = {
        name = anchorTown.name,
        level = anchorTown.level or 1,
        x = anchorTown.position and anchorTown.position.x or 0,
        y = anchorTown.position and anchorTown.position.y or 0,
        npcs = generateTownNPCs(state.player and math.max(1, math.min(anchorTown.level or 1, state.player.level + 2)) or (anchorTown.level or 1)),
        shop = {},
        jobBoard = {},
        specialization = anchorTown.type or "Trading Hub",
        market = {},
        -- Preserve anchor town data
        isAnchorTown = true,
        anchorId = anchorTown.id,
        description = anchorTown.description,
        landmarks = anchorTown.landmarks,
        fixedNPCs = anchorTown.fixedNPCs,
        population = anchorTown.population,
        region = anchorTown.region,
    }

    -- Generate market prices (simplified for anchor towns)
    for _, good in ipairs(TRADE_GOODS) do
        local priceMultiplier = 0.85 + math.random() * 0.3
        local price = math.floor(good.basePrice * priceMultiplier)
        table.insert(town.market, {
            id = good.id,
            name = good.name,
            category = good.category,
            icon = good.icon,
            buyPrice = price,
            sellPrice = math.floor(price * 0.8),
            stock = math.random(5, 20),
        })
    end

    -- Generate shop inventories
    local shopPools = {
        general = {"tq_health_potion", "tq_mana_potion", "tq_elixir", "tq_rusty_sword", "tq_iron_sword", "tq_cloth_armor", "tq_leather_armor"},
        butcher = {"tq_raw_steak", "tq_salted_meat", "tq_smoked_sausage", "tq_beef_jerky", "tq_prime_cut"},
        bakery = {"tq_bread_loaf", "tq_sweet_roll", "tq_meat_pie", "tq_honeycake", "tq_elven_waybread"},
        tailor = {"tq_traveler_cloak", "tq_fine_tunic", "tq_noble_garb", "tq_ranger_hood", "tq_cloth_armor", "tq_leather_armor"},
        jeweler = {"tq_copper_ring", "tq_silver_ring", "tq_gold_ring", "tq_ruby_amulet", "tq_sapphire_pendant"},
    }

    -- Scale town content to player level so starting areas aren't impossibly hard
    -- Town keeps its base level for display, but shop/quest content scales to player
    local level = town.level
    if state.player then
        level = math.max(1, math.min(town.level, state.player.level + 2))
    end
    town.shops = {
        general = generateShopInventory(shopPools.general, math.random(5, 8), level),
        butcher = generateShopInventory(shopPools.butcher, math.random(4, 6), level),
        bakery = generateShopInventory(shopPools.bakery, math.random(4, 6), level),
        tailor = generateShopInventory(shopPools.tailor, math.random(5, 7), level),
        jeweler = generateShopInventory(shopPools.jeweler, math.random(5, 7), level),
    }
    town.shop = town.shops.general

    -- Generate job board quests
    for i = 1, math.random(3, 5) do
        local prof = NPC_PROFESSIONS[math.random(#NPC_PROFESSIONS)]
        local quest = generateQuest("Job Board", prof, level)
        table.insert(town.jobBoard, quest)
    end

    -- Generate anchor city building variety
    if anchorTown.id then
        local anchorSeed = (anchorTown.position and anchorTown.position.x or 0) * 73856093
                         + (anchorTown.position and anchorTown.position.y or 0) * 19349663
                         + (anchorTown.level or 1) * 83492791 + 12345
        local buildingData = TownGen.generateAnchorBuildings(anchorTown.id, anchorSeed)
        if buildingData then
            town.townBuildings = buildingData.buildings
            town.townGridCols = buildingData.gridCols
            town.townGridRows = buildingData.gridRows
            town.townStreetCol = buildingData.streetCol
            town.townStreetRows = buildingData.streetRows
        else
            -- Fallback: generate as a generic anchor town
            local themeKey = TownGen.getThemeKey(anchorTown.region)
            local genData = TownGen.generateTownBuildings({
                level = anchorTown.level or 1,
                population = anchorTown.population,
                regionTheme = themeKey,
                specialization = anchorTown.type,
                isAnchor = true,
                seed = anchorSeed,
            })
            if genData then
                town.townBuildings = genData.buildings
                town.townGridCols = genData.gridCols
                town.townGridRows = genData.gridRows
                town.townStreetCol = genData.streetCol
                town.townStreetRows = genData.streetRows
            end
        end
    end

    return town
end

-- ============================================================================
-- WORLDGEN TILE WRAPPERS
-- ============================================================================

-- Get tile from WorldGen (wrapper for compatibility)
M.getTileFromWorldGen = function(x, y)
    return WorldGen.getTile(x, y)
end

-- Set tile in WorldGen (wrapper for compatibility)
M.setTileInWorldGen = function(x, y, tileData)
    WorldGen.setTile(x, y, tileData)
end

-- ============================================================================
-- MAP GENERATION
-- ============================================================================

-- Initialize world using WorldGen chunk system
M.generateMap = function(raceId)
    -- Initialize WorldGen with a seed
    local seed = state.world.worldSeed or os.time()
    WorldGen.init(seed)
    state.world.worldSeed = WorldGen.getWorldSeed()

    -- Determine starting position based on race
    local startX, startY, startAnchorTown
    raceId = raceId or "human"

    -- Racial starting city coordinates (from ANCHOR_TOWNS in worldgen.lua)
    local racialStartPositions = {
        human = {x = 35, y = 42, town = "havenbrook"},      -- Havenbrook (humble starting village)
        elf = {x = 45, y = 55, town = "sylvaris"},          -- Sylvaris (elven administrative city)
        dwarf = {x = 32, y = 8, town = "ironhold"},         -- Ironhold (mountain stronghold)
        orc = {x = 18, y = 25, town = "kragmor"},           -- Kragmor (steppe fortress)
        goblin = {x = 10, y = 38, town = "bonetrap"},       -- BoneTrap (tribal goblin warren)
        gnome = {x = 128, y = 38, town = "mechspire"},      -- Mechspire (gnomish capital) - Fixed: was 95 (ocean), now 128 (correct island position)
        catfolk = {x = 35, y = -8, town = "fortunes_rest"}, -- Fortune's Rest (desert oasis harbor)
        lizardfolk = {x = 15, y = 52, town = "murkmire"},   -- Murkmire (shadowfen swamp citadel)
    }

    local raceStart = racialStartPositions[raceId] or racialStartPositions.human
    startX = raceStart.x
    startY = raceStart.y

    -- Get starting position from WorldGen (will override with racial start)
    local defaultStartX, defaultStartY, defaultAnchorTown = WorldGen.getStartingPosition()

    -- Load initial chunks around starting position
    WorldGen.updateLoadedChunks(startX, startY)

    -- Set player position
    state.world.playerX = startX
    state.world.playerY = startY

    -- Clear legacy map data (we now use WorldGen)
    state.world.mapData = nil  -- No longer used
    state.world.mapWidth = nil  -- Infinite world
    state.world.mapHeight = nil  -- Infinite world
    state.world.westOffset = nil
    state.world.eastOffset = nil
    state.world.northOffset = nil
    state.world.southOffset = nil

    -- Mark this as using WorldGen
    state.world.useWorldGen = true

    -- Get the starting tile and set up starting town
    local startTile = WorldGen.getTile(startX, startY)
    if startTile then
        startTile.explored = true
        WorldGen.exploreTile(startX, startY)

        -- Convert anchor town to legacy format for UI
        if startTile.town then
            local legacyTown = convertAnchorToLegacyTown(startTile.town)
            startTile.town = legacyTown
            table.insert(state.world.towns, legacyTown)
            state.world.currentTown = legacyTown
        else
            -- Fallback: create a town if none exists at start
            local fallbackTown = generateTown(startX, startY, 1)
            startTile.type = "town"
            startTile.town = fallbackTown
            table.insert(state.world.towns, fallbackTown)
            state.world.currentTown = fallbackTown
            WorldGen.setTile(startX, startY, startTile)
        end
    end

    -- Explore tiles around starting position
    for dy = -1, 1 do
        for dx = -1, 1 do
            local nx, ny = startX + dx, startY + dy
            WorldGen.exploreTile(nx, ny)
        end
    end

    -- Pre-register anchor towns in state.world.towns for reference
    local anchorTowns = WorldGen.getAnchorTowns()
    for _, anchor in ipairs(anchorTowns) do
        if not anchor.isStartingTown then
            -- These will be converted when player visits them
            -- For now, just note they exist
        end
    end

    -- Initialize map enemies array for the new world
    state.world.mapEnemies = {}
    state.world.mapEnemiesDefeated = 0

    log("World generated with seed: " .. state.world.worldSeed, {0.5, 0.7, 0.9})
end

-- Legacy generateMap for backwards compatibility with old saves
-- DEPRECATED: New games should use F.generateMap() which uses WorldGen
M.generateMapLegacy = function()
    -- This is the old map generation for migrating old saves
    -- Only used when loading saves that don't have state.world.useWorldGen flag
    state.world.mapData = {}
    local w, h = state.world.mapWidth or 15, state.world.mapHeight or 15

    for y = 0, h - 1 do
        state.world.mapData[y] = {}
        for x = 0, w - 1 do
            state.world.mapData[y][x] = {
                type = "grass",
                explored = false,
                town = nil,
            }
        end
    end

    for y = 0, h - 1 do
        for x = 0, w - 1 do
            local roll = math.random()
            if roll < 0.15 then
                state.world.mapData[y][x].type = "forest"
            elseif roll < 0.22 then
                state.world.mapData[y][x].type = "mountain"
            elseif roll < 0.27 then
                state.world.mapData[y][x].type = "swamp"
            elseif roll < 0.30 then
                state.world.mapData[y][x].type = "water"
            elseif roll < 0.33 then
                state.world.mapData[y][x].type = "ruins"
            elseif roll < 0.35 then
                state.world.mapData[y][x].type = "dungeon"
            end
        end
    end

    local startX, startY = math.floor(w / 2), math.floor(h / 2)
    local startTown = generateTown(startX, startY, 1)
    state.world.mapData[startY][startX] = {
        type = "town",
        explored = true,
        town = startTown,
    }
    table.insert(state.world.towns, startTown)
    state.world.currentTown = startTown
    state.world.playerX = startX
    state.world.playerY = startY

    for dy = -1, 1 do
        for dx = -1, 1 do
            local nx, ny = startX + dx, startY + dy
            if nx >= 0 and nx < w and ny >= 0 and ny < h then
                state.world.mapData[ny][nx].explored = true
            end
        end
    end

    local townCount = math.random(5, 8)
    for i = 2, townCount do
        local attempts = 0
        repeat
            local tx = math.random(1, w - 2)
            local ty = math.random(1, h - 2)
            local dist = math.abs(tx - startX) + math.abs(ty - startY)
            if dist >= 3 and state.world.mapData[ty][tx].type ~= "town" and state.world.mapData[ty][tx].type ~= "water" then
                local townLevel = math.max(1, math.floor(dist / 2))
                local town = generateTown(tx, ty, townLevel)
                state.world.mapData[ty][tx] = {
                    type = "town",
                    explored = false,
                    town = town,
                }
                table.insert(state.world.towns, town)
                break
            end
            attempts = attempts + 1
        until attempts > 50
    end
end

-- ============================================================================
-- WATER EVENT SYSTEM
-- ============================================================================

-- Roll for a water event on a water tile
M.rollWaterEvent = function(tileType)
    if not tileType or not tileType.isWater then return nil end
    -- Deep ocean has higher event chance
    local eventMult = 1.0
    if tileType.id == "deep_ocean" then eventMult = 1.5
    elseif tileType.id == "coastal" then eventMult = 0.7
    elseif tileType.id == "river" or tileType.id == "lake" then eventMult = 0.3
    end

    for _, event in ipairs(WATER_EVENTS) do
        if math.random() < event.chance * eventMult then
            return event
        end
    end
    return nil
end

-- Handle a water event
M.handleWaterEvent = function(event)
    if not event then return end

    log(event.message, event.color)

    if event.type == "trade" then
        -- Sea merchant - give gold rewards for now (full shop in future)
        local item = SEA_MERCHANT_GOODS[math.random(#SEA_MERCHANT_GOODS)]
        log("The merchant offers: " .. item.name .. " (" .. item.desc .. ") for " .. item.price .. " gold.", {0.6, 0.8, 0.6})
        if state.player.gold >= item.price then
            state.player.gold = state.player.gold - item.price
            log("You purchase the " .. item.name .. "!", {0.5, 0.9, 0.5})
            -- Apply immediate effects
            if item.id == "ship_repair_kit" then
                state.player.hp = math.min(state.player.hp + 50, state.player.maxHP)
                log("You restore 50 HP!", {0.4, 0.8, 0.4})
            end
        else
            log("You don't have enough gold. The merchant sails on.", {0.7, 0.5, 0.5})
        end

    elseif event.type == "loot" then
        -- Random debris loot
        local roll = math.random()
        local cumChance = 0
        for _, loot in ipairs(DEBRIS_LOOT) do
            cumChance = cumChance + loot.chance
            if roll < cumChance then
                log("You find: " .. loot.name .. "!", {0.7, 0.7, 0.4})
                if loot.gold then
                    local goldFound = math.random(loot.gold[1], loot.gold[2])
                    state.player.gold = state.player.gold + goldFound
                    log("+" .. goldFound .. " gold", {0.9, 0.8, 0.3})
                end
                if loot.xp then
                    state.player.xp = state.player.xp + loot.xp
                    log("+" .. loot.xp .. " XP", {0.5, 0.8, 0.5})
                end
                if loot.heal then
                    local healAmt = math.random(loot.heal[1], loot.heal[2])
                    state.player.hp = math.min(state.player.hp + healAmt, state.player.maxHP)
                    log("+" .. healAmt .. " HP restored", {0.4, 0.8, 0.4})
                end
                break
            end
        end

    elseif event.type == "buff" then
        -- Dolphins guide - temporary navigation buff
        state.waterBuff = {type = "dolphins", turnsLeft = 5, encounterReduction = 0.5}
        log("Encounter chance reduced for the next 5 water tiles!", {0.4, 0.7, 0.9})

    elseif event.type == "damage" then
        -- Sea storm damage
        local damage = math.random(10, 25 + state.player.level * 2)
        -- Spirit save to reduce
        local spiritMod = math.floor(((state.player.stats and state.player.stats.SPIRIT or 10) - 10) / 2)
        if math.random(1, 20) + spiritMod >= 12 then
            damage = math.floor(damage * 0.5)
            log("Your experience helps you weather the storm! (Half damage)", {0.6, 0.7, 0.8})
        end
        state.player.hp = math.max(1, state.player.hp - damage)
        log("The storm deals " .. damage .. " damage!", {0.9, 0.4, 0.4})
        if state.player.hp <= math.floor(state.player.maxHP * 0.25) then
            log("Your vessel is badly damaged! Find shelter!", {0.9, 0.3, 0.3})
        end

    elseif event.type == "teleport" then
        -- Whirlpool displacement
        local displaceX = math.random(-5, 5)
        local displaceY = math.random(-5, 5)
        if displaceX == 0 and displaceY == 0 then displaceX = 3 end
        state.world.playerX = state.world.playerX + displaceX
        state.world.playerY = state.world.playerY + displaceY
        local damage = math.random(5, 15)
        state.player.hp = math.max(1, state.player.hp - damage)
        log("The whirlpool drags you " .. math.abs(displaceX + displaceY) .. " tiles away! (" .. damage .. " damage)", {0.4, 0.5, 0.8})

    elseif event.type == "charm" then
        -- Siren song - Spirit save
        local spiritMod = math.floor(((state.player.stats and state.player.stats.SPIRIT or 10) - 10) / 2)
        if math.random(1, 20) + spiritMod >= 14 then
            log("You resist the siren's call! Your willpower holds firm.", {0.6, 0.8, 0.6})
            local xpBonus = 20 + state.player.level * 5
            state.player.xp = state.player.xp + xpBonus
            log("+" .. xpBonus .. " XP for resisting!", {0.5, 0.8, 0.5})
        else
            local damage = math.random(10, 20)
            local goldLost = math.random(10, 30)
            state.player.hp = math.max(1, state.player.hp - damage)
            state.player.gold = math.max(0, state.player.gold - goldLost)
            log("The siren's song clouds your mind! " .. damage .. " damage, " .. goldLost .. " gold lost!", {0.8, 0.4, 0.6})
        end

    elseif event.type == "combat" then
        -- Ghost ship encounter - fight spectral sailors
        local ghostEnemies = SEA_ENEMIES.deep
        local enemyDef = nil
        for _, e in ipairs(ghostEnemies) do
            if e.id == "ghost_ship_crew" then
                enemyDef = e
                break
            end
        end
        if enemyDef then
            local enemies = {}
            local count = math.random(2, 4)
            for i = 1, count do
                table.insert(enemies, F.createEnemyInstance(enemyDef, state.player.level))
            end
            log("Spectral sailors board your vessel!", {0.6, 0.6, 0.8})
            F.startCombat(enemies)
        end

    elseif event.type == "treasure" then
        -- Sunken treasure - big reward
        local goldFound = math.random(50, 200) + state.player.level * 10
        local xpFound = math.random(30, 80) + state.player.level * 5
        state.player.gold = state.player.gold + goldFound
        state.player.xp = state.player.xp + xpFound
        log("You haul up a treasure chest from the depths!", {0.9, 0.8, 0.3})
        log("+" .. goldFound .. " gold, +" .. xpFound .. " XP!", {0.9, 0.9, 0.4})

    elseif event.type == "quest" then
        -- Message in a bottle - lore/treasure map hint
        local messages = {
            "\"If you seek the Kraken's hoard, sail to where the whirlpools roar...\"",
            "\"The merfolk city lies beneath the coral reef, due south of the Silver Seas...\"",
            "\"Beware the Leviathan. It sleeps in the deepest trench. Do not wake it.\"",
            "\"Captain Redbeard buried his gold on the island with three palms. Look for the X.\"",
            "\"The underwater ruins hold secrets of an age before man walked the earth...\"",
            "\"To those who find this: the sea fortress holds prisoners still. Free them if you dare.\"",
            "\"My ship is sinking. If you find this, tell my family in Port Town I love them. - J.K.\"",
            "\"The siren's weakness is iron. Bring iron weapons and you shall be safe.\"",
        }
        log(messages[math.random(#messages)], {0.6, 0.7, 0.5})
        local xpFound = math.random(10, 30)
        state.player.xp = state.player.xp + xpFound
        log("+" .. xpFound .. " XP from the discovery!", {0.5, 0.8, 0.5})
    end
end

-- ============================================================================
-- TILE TYPE LOOKUP
-- ============================================================================

M.getTileType = function(tileId)
    for _, t in ipairs(TILE_TYPES) do
        if t.id == tileId then return t end
    end
    return TILE_TYPES[1]
end

-- ============================================================================
-- TILE GENERATION
-- ============================================================================

-- Generate a single tile for map expansion
M.generateNewTile = function(playerLevel, distance, x, y)
    local roll = math.random()
    local tileType = "grass"

    -- More dangerous terrain further from origin
    local dangerBonus = math.min(0.2, (distance or 0) * 0.02)

    -- DESERT REGION DETECTION (based on distance and direction)
    -- Far north, south, or east regions become desert zones
    local isDesertRegion = false
    if x and y then
        local originX, originY = 7, 7  -- Starting position
        local dx, dy = x - originX, y - originY
        local distFromOrigin = math.sqrt(dx*dx + dy*dy)

        -- Desert regions: Far north (y < 0), far south (y > 20), or far east (x > 20)
        if (y < 0 and distFromOrigin > 10) or
           (y > 20 and distFromOrigin > 15) or
           (x > 20 and y > 5 and distFromOrigin > 15) then
            isDesertRegion = true
        end
    end

    -- DESERT BIOME GENERATION (when in desert regions)
    if isDesertRegion then
        tileType = F.generateDesertBiome(x, y, distance, dangerBonus)
    else
        -- NORMAL TERRAIN GENERATION
        if roll < 0.15 then
            tileType = "forest"
        elseif roll < 0.22 then
            tileType = "mountain"
        elseif roll < 0.27 + dangerBonus then
            tileType = "swamp"
        elseif roll < 0.30 then
            -- Water tile with variety
            local waterRoll = math.random()
            if waterRoll < 0.4 then tileType = "lake"
            elseif waterRoll < 0.7 then tileType = "river"
            else tileType = "water"
            end
        elseif roll < 0.33 + dangerBonus then
            tileType = "ruins"
        elseif roll < 0.36 + dangerBonus then
            tileType = "dungeon"
        end
    end

    return {
        type = tileType,
        explored = false,
        town = nil,
    }
end

-- ============================================================================
--                   DESERT BIOME GENERATION SYSTEM
-- ============================================================================
-- Generates varied desert terrain types with geological features
-- Creates rare desert settlements and oases

M.generateDesertBiome = function(x, y, distance, dangerBonus)
    local roll = math.random()
    local biome = "desert"  -- Default basic desert

    -- Determine if this is Glass Wastes region (far south, very rare)
    local isGlassWastes = (y and y > 30 and math.random() < 0.4)

    -- GLASS WASTES (Wastes of Calidar region)
    if isGlassWastes then
        if roll < 0.60 then
            biome = "glass_desert"  -- Crystallized sand, lifeless
        elseif roll < 0.75 then
            biome = "obsidian_field"  -- Volcanic glass fields
        elseif roll < 0.85 then
            biome = "crystal_formations"  -- Jagged crystal spires
        elseif roll < 0.92 then
            biome = "desert_canyon"  -- Glass canyons
        elseif roll < 0.95 then
            biome = "ruins"  -- Ancient elven ruins (pre-destruction)
        else
            biome = "dungeon"  -- Buried temples, crypts (5% in Glass Wastes)
        end

    -- NORMAL DESERT REGIONS (varied biomes)
    else
        if roll < 0.30 then
            biome = "sand_dunes"  -- Rolling dunes (most common)
        elseif roll < 0.50 then
            biome = "desert"  -- Basic sandy desert
        elseif roll < 0.60 then
            biome = "badlands"  -- Rocky, eroded terrain
        elseif roll < 0.68 then
            biome = "salt_flats"  -- White salt plains
        elseif roll < 0.75 then
            biome = "desert_canyon"  -- Red rock canyons
        elseif roll < 0.80 then
            biome = "stone_pillars"  -- Natural stone formations
        elseif roll < 0.83 then
            biome = "desert_cave"  -- Cave systems
        elseif roll < 0.85 then
            biome = "desert_oasis"  -- Oasis with water
        elseif roll < 0.88 + dangerBonus then
            biome = "ruins"  -- Ancient desert ruins
        elseif roll < 0.94 + dangerBonus then
            biome = "dungeon"  -- Desert tombs/temples (HIGHER CHANCE - 6-9%)
        else
            -- Rare crystal formations (mana crystals)
            biome = "crystal_formations"
        end
    end

    return biome
end

-- ============================================================================
-- DESERT SETTLEMENT GENERATION
-- ============================================================================

-- Generate rare desert settlement (called separately with low probability)
M.generateDesertSettlement = function(x, y, level)
    local settlementTypes = {
        {name = "Nomad Camp", desc = "Temporary beast folk encampment", population = "10-30"},
        {name = "Caravan Rest", desc = "Trading post along ancient routes", population = "20-50"},
        {name = "Hidden Oasis Village", desc = "Settlement around secret water source", population = "50-150"},
        {name = "Lizard Folk River City", desc = "Ancient underground civilization", population = "200-500", hidden = true},
        {name = "Sand Tomb Outpost", desc = "Crypt explorers' base camp", population = "15-40"},
        {name = "Salt Traders' Post", desc = "Salt mining settlement", population = "30-80"},
        {name = "Desert Monastery", desc = "Isolated religious retreat", population = "10-25"},
        {name = "Glass Scavenger Camp", desc = "Those who harvest obsidian and glass", population = "20-60"}
    }

    local settlementType = settlementTypes[math.random(#settlementTypes)]

    local settlement = {
        name = generateDesertSettlementName(),
        level = level,
        x = x,
        y = y,
        npcs = generateDesertNPCs(level),
        shop = {},
        jobBoard = {},
        specialization = "Desert Trading Post",
        market = {},
        isDesertSettlement = true,
        settlementType = settlementType.name,
        description = settlementType.desc,
        population = settlementType.population,
        hidden = settlementType.hidden or false,
        -- Desert settlements have unique trade goods
        desertGoods = {
            "water_flask", "desert_herbs", "camel_hide", "sand_glass",
            "salt_blocks", "cactus_fruit", "lizard_scales", "obsidian_shard"
        }
    }

    -- Generate limited market (desert settlements are small)
    for _, good in ipairs(TRADE_GOODS) do
        -- Desert settlements have higher water prices, lower other goods
        local priceMultiplier = 1.0
        if good.category == "food" then
            priceMultiplier = 1.5 + math.random() * 0.5  -- Food expensive
        elseif good.id == "water" or good.id == "fish" then
            priceMultiplier = 2.0 + math.random() * 1.0  -- Water very expensive
        else
            priceMultiplier = 0.9 + math.random() * 0.3
        end

        local price = math.floor(good.basePrice * priceMultiplier)
        table.insert(settlement.market, {
            id = good.id,
            name = good.name,
            category = good.category,
            icon = good.icon,
            buyPrice = price,
            sellPrice = math.floor(price * 0.7),
            stock = math.random(2, 8),  -- Limited stock
        })
    end

    -- Desert shops (very limited)
    settlement.shops = {
        general = generateDesertShopInventory(level, 3),  -- Only 3 items
        supplies = generateDesertShopInventory(level, 4),
    }
    settlement.shop = settlement.shops.general

    -- Desert quests (exploration focused)
    for i = 1, math.random(1, 3) do
        local quest = generateDesertQuest("Desert Guide", level)
        table.insert(settlement.jobBoard, quest)
    end

    return settlement
end

-- Generate desert-themed settlement names
generateDesertSettlementName = function()
    local prefixes = {
        "Sun", "Sand", "Dune", "Mirage", "Oasis", "Salt", "Glass",
        "Stone", "Wind", "Scorched", "Hidden", "Lost", "Ancient",
        "Buried", "Shifting", "Crystal"
    }

    local suffixes = {
        "haven", "rest", "wells", "camp", "post", "crossing",
        "springs", "refuge", "watch", "pillars", "gates", "tomb"
    }

    return prefixes[math.random(#prefixes)] .. suffixes[math.random(#suffixes)]
end

-- Generate desert NPCs (different from normal towns)
generateDesertNPCs = function(level)
    local npcs = {}
    local npcCount = math.random(2, 4)  -- Fewer NPCs in desert settlements

    local desertProfessions = {
        "Caravan Leader", "Water Diviner", "Sand Guide", "Salt Trader",
        "Tomb Raider", "Glass Harvester", "Desert Hermit", "Lizard Folk Scout",
        "Nomad Elder", "Oasis Keeper", "Beast Folk Warrior"
    }

    for i = 1, npcCount do
        local profession = desertProfessions[math.random(#desertProfessions)]
        local npc = {
            name = NPC_FIRST_NAMES[math.random(#NPC_FIRST_NAMES)],
            profession = profession,
            level = level,
            hasQuest = math.random() < 0.4,  -- 40% chance of quest
        }
        table.insert(npcs, npc)
    end

    return npcs
end

-- Generate desert shop inventory
generateDesertShopInventory = function(level, count)
    local desertItems = {
        "tq_water_flask", "tq_health_potion", "tq_desert_cloak",
        "tq_sand_goggles", "tq_camel_hide_armor", "tq_cactus_fruit",
        "tq_salt_rations", "tq_sunstone_amulet"
    }

    local inventory = {}
    for i = 1, math.min(count, #desertItems) do
        local itemId = desertItems[math.random(#desertItems)]
        local itemDef = Backpack.getItemDef(itemId)
        if itemDef then
            local stats = itemDef.baseStats or {}
            table.insert(inventory, {
                backpackId = itemId,
                name = itemDef.name,
                category = itemDef.category,
                icon = itemDef.icon,
                attack = stats.attack,
                defense = stats.defense,
                heal = stats.heal,
                value = math.floor((itemDef.sellValue or 30) * (1 + level * 0.25) * 2),
                desc = itemDef.desc,
            })
        end
    end
    return inventory
end

-- Generate desert-specific quests
generateDesertQuest = function(profession, level)
    local questTypes = {
        {type = "find_oasis", name = "Locate Hidden Oasis", desc = "Find water source in the dunes"},
        {type = "escort_caravan", name = "Escort Caravan", desc = "Protect traders through dangerous sands"},
        {type = "explore_tomb", name = "Explore Ancient Tomb", desc = "Investigate buried crypt"},
        {type = "hunt_scorpions", name = "Hunt Giant Scorpions", desc = "Clear scorpion nest"},
        {type = "collect_glass", name = "Harvest Glass Shards", desc = "Collect obsidian from glass fields"},
        {type = "rescue_nomad", name = "Rescue Lost Nomad", desc = "Find missing traveler in sandstorm"},
    }

    local quest = questTypes[math.random(#questTypes)]
    return {
        type = quest.type,
        name = quest.name,
        description = quest.desc,
        giver = profession,
        level = level,
        rewardGold = 50 + level * 20,
        rewardXP = 100 + level * 30,
        completed = false,
    }
end

-- ============================================================================
-- TOWN SPAWNING
-- ============================================================================

-- Spawn a random town in newly expanded area
M.spawnRandomTown = function(direction, playerLevel, distance)
    local townLevel = math.max(1, playerLevel + math.floor((distance or 0) / 2))
    local attempts = 0

    repeat
        local tx, ty
        local w, h = state.world.mapWidth, state.world.mapHeight
        local wOff = state.world.westOffset or 0
        local nOff = state.world.northOffset or 0
        local eOff = state.world.eastOffset or 0
        local sOff = state.world.southOffset or 0

        if direction == "north" then
            tx = math.random(wOff, w - 1 + eOff)
            ty = nOff + math.random(0, 3)
        elseif direction == "south" then
            tx = math.random(wOff, w - 1 + eOff)
            ty = h - 1 + sOff - math.random(0, 3)
        elseif direction == "west" then
            tx = wOff + math.random(0, 3)
            ty = math.random(nOff, h - 1 + sOff)
        elseif direction == "east" then
            tx = w - 1 + eOff - math.random(0, 3)
            ty = math.random(nOff, h - 1 + sOff)
        end

        if state.world.mapData[ty] and state.world.mapData[ty][tx] and
           state.world.mapData[ty][tx].type ~= "water" and
           state.world.mapData[ty][tx].type ~= "town" then
            local town = generateTown(tx, ty, townLevel)
            state.world.mapData[ty][tx] = {
                type = "town",
                explored = false,
                town = town,
            }
            table.insert(state.world.towns, town)
            log("A distant settlement can be seen...", {0.8, 0.7, 0.4})
            return
        end
        attempts = attempts + 1
    until attempts > 20
end

-- Spawn a rare desert settlement in newly expanded desert areas
M.spawnDesertSettlement = function(direction, playerLevel, distance)
    local settlementLevel = math.max(1, playerLevel + math.floor((distance or 0) / 2))
    local attempts = 0

    repeat
        local tx, ty
        local w, h = state.world.mapWidth, state.world.mapHeight
        local wOff = state.world.westOffset or 0
        local nOff = state.world.northOffset or 0
        local eOff = state.world.eastOffset or 0
        local sOff = state.world.southOffset or 0

        if direction == "north" then
            tx = math.random(wOff, w - 1 + eOff)
            ty = nOff + math.random(0, 3)
        elseif direction == "south" then
            tx = math.random(wOff, w - 1 + eOff)
            ty = h - 1 + sOff - math.random(0, 3)
        elseif direction == "west" then
            tx = wOff + math.random(0, 3)
            ty = math.random(nOff, h - 1 + sOff)
        elseif direction == "east" then
            tx = w - 1 + eOff - math.random(0, 3)
            ty = math.random(nOff, h - 1 + sOff)
        end

        if state.world.mapData[ty] and state.world.mapData[ty][tx] then
            local tileType = state.world.mapData[ty][tx].type
            -- Only spawn on desert tiles (not water or existing settlements)
            if tileType ~= "water" and tileType ~= "town" and tileType ~= "desert_settlement" then
                local settlement = generateDesertSettlement(tx, ty, settlementLevel)
                state.world.mapData[ty][tx] = {
                    type = "desert_settlement",
                    explored = false,
                    town = settlement,
                    settlement = settlement,
                }
                table.insert(state.world.towns, settlement)
                log("A distant desert encampment shimmers in the heat...", {0.9, 0.8, 0.5})
                return
            end
        end
        attempts = attempts + 1
    until attempts > 20
end

-- ============================================================================
-- TILE CLEANUP & MAP EXPANSION
-- ============================================================================

-- Clean up distant tiles to prevent unbounded memory growth
-- Compresses tiles far from player to minimal representation
-- NOTE: Only for legacy map system - WorldGen handles its own chunk unloading
M.cleanupDistantTiles = function()
    -- Skip for WorldGen - it handles memory via chunk loading/unloading
    if state.world.useWorldGen then
        return 0, 0
    end

    -- Legacy system cleanup
    if not state.world.mapData then
        return 0, 0
    end

    local px, py = state.world.playerX, state.world.playerY
    local keepDistance = 60  -- Keep full data for tiles within 60 tiles of player
    local compressDistance = 100  -- Compress tiles beyond 100 tiles
    local tilesCompressed = 0
    local tilesRemoved = 0

    for y, row in pairs(state.world.mapData) do
        local rowEmpty = true
        for x, tile in pairs(row) do
            if tile then
                local dist = math.abs(x - px) + math.abs(y - py)

                -- Keep towns, dungeons, and player-owned properties intact
                local isImportant = tile.type == "town" or tile.dungeon or tile.property or tile.settlement

                if not isImportant and dist > compressDistance then
                    -- Very distant: compress to minimal data
                    if not tile.compressed then
                        state.world.mapData[y][x] = {
                            type = tile.type,
                            explored = tile.explored or false,
                            compressed = true,
                        }
                        tilesCompressed = tilesCompressed + 1
                    end
                end
                rowEmpty = false
            end
        end

        -- Don't remove rows - they may have sparse data we want to keep
    end

    -- Only log if we actually cleaned up something
    if tilesCompressed > 0 then
        -- Silent cleanup - no log spam
    end

    return tilesCompressed, tilesRemoved
end

-- Expand the map in a given direction (LEGACY SYSTEM - for old saves only)
-- New games use WorldGen which handles infinite expansion automatically
M.expandMap = function(direction)
    local expansion = 5  -- Add 5 tiles per expansion
    local w, h = state.world.mapWidth, state.world.mapHeight
    local playerLevel = state.player and state.player.level or 1
    local distanceFromOrigin = state.world.expansionCount or 0
    local wOff = state.world.westOffset or 0
    local eOff = state.world.eastOffset or 0
    local nOff = state.world.northOffset or 0
    local sOff = state.world.southOffset or 0

    if direction == "north" then
        -- Expand northward - add rows at y < 0
        for i = 1, expansion do
            local newY = nOff - i
            state.world.mapData[newY] = state.world.mapData[newY] or {}
            for x = wOff, w - 1 + eOff do
                state.world.mapData[newY][x] = generateNewTile(playerLevel, distanceFromOrigin, x, newY)
            end
        end
        state.world.northOffset = nOff - expansion
        state.world.mapHeight = state.world.mapHeight + expansion
        log("Discovered new lands to the north!", {0.5, 0.9, 0.6})

    elseif direction == "south" then
        -- Expand southward - add rows at y >= h
        local startY = h + sOff
        for i = 0, expansion - 1 do
            local newY = startY + i
            state.world.mapData[newY] = state.world.mapData[newY] or {}
            for x = wOff, w - 1 + eOff do
                state.world.mapData[newY][x] = generateNewTile(playerLevel, distanceFromOrigin, x, newY)
            end
        end
        state.world.southOffset = sOff + expansion
        state.world.mapHeight = state.world.mapHeight + expansion
        log("Discovered new lands to the south!", {0.5, 0.9, 0.6})

    elseif direction == "west" then
        -- Expand westward - add columns at x < 0
        -- Use calculated bounds instead of pairs() for better performance
        local minY = nOff
        local maxY = h - 1 + sOff
        for y = minY, maxY do
            if not state.world.mapData[y] then
                state.world.mapData[y] = {}
            end
            for i = 1, expansion do
                local newX = wOff - i
                state.world.mapData[y][newX] = generateNewTile(playerLevel, distanceFromOrigin, newX, y)
            end
        end
        state.world.westOffset = wOff - expansion
        state.world.mapWidth = state.world.mapWidth + expansion
        log("Discovered new lands to the west!", {0.5, 0.9, 0.6})

    elseif direction == "east" then
        -- Expand eastward - add columns at x >= w
        -- Use calculated bounds instead of pairs() for better performance
        local startX = w + eOff
        local minY = nOff
        local maxY = h - 1 + sOff
        for y = minY, maxY do
            if not state.world.mapData[y] then
                state.world.mapData[y] = {}
            end
            for i = 0, expansion - 1 do
                state.world.mapData[y][startX + i] = generateNewTile(playerLevel, distanceFromOrigin, startX + i, y)
            end
        end
        state.world.eastOffset = eOff + expansion
        state.world.mapWidth = state.world.mapWidth + expansion
        log("Discovered new lands to the east!", {0.5, 0.9, 0.6})
    end

    state.world.expansionCount = (state.world.expansionCount or 0) + 1

    -- Chance to spawn a new town/settlement in the expanded area
    -- Higher chance in desert regions for rare desert settlements
    local spawnChance = 0.3
    if math.random() < spawnChance then
        -- Check if in desert region - spawn desert settlement instead
        local isDesertZone = (direction == "south" and state.world.expansionCount > 5) or
                             (direction == "north" and state.world.expansionCount > 3) or
                             (direction == "east" and state.world.expansionCount > 5)

        if isDesertZone and math.random() < 0.15 then  -- 15% chance in deserts (very rare)
            spawnDesertSettlement(direction, playerLevel, distanceFromOrigin)
        else
            spawnRandomTown(direction, playerLevel, distanceFromOrigin)
        end
    end
end

-- ============================================================================
-- PLAYER MOVEMENT
-- ============================================================================

M.movePlayer = function(dx, dy)
    -- Don't allow movement if player doesn't exist yet
    if not state.player then
        return false
    end

    -- Check encumbrance before moving
    local playerMight = state.player.stats and state.player.stats.MIGHT or 10
    local encumbrance = Backpack.getEncumbranceStatus(playerMight)

    if not encumbrance.canMove then
        log("You are carrying too much weight to move! Drop some items or get a pack animal.", {0.9, 0.4, 0.3})
        return false
    end

    -- Warn about heavy encumbrance
    if encumbrance.level == "overencumbered" then
        log("Struggling under heavy load... (" .. math.floor(encumbrance.ratio * 100) .. "% capacity)", {0.8, 0.6, 0.3})
    elseif encumbrance.level == "heavy" then
        log("Heavy load slowing you down... (" .. math.floor(encumbrance.ratio * 100) .. "% capacity)", {0.7, 0.6, 0.4})
    end

    -- Check weather before moving
    local weatherFx = F.getWeatherEffects()
    if weatherFx.dangerous and not state.weather.sheltered then
        log(weatherFx.icon .. " Too dangerous to travel! " .. weatherFx.desc, {0.9, 0.4, 0.3})
        return false
    end

    -- Break camp if we move
    if state.camping and state.camping.active then
        F.breakCamp()
    end

    local newX = state.world.playerX + dx
    local newY = state.world.playerY + dy

    -- Get tile from WorldGen or legacy system
    local tile
    if state.world.useWorldGen then
        -- WorldGen: Update loaded chunks around new position
        WorldGen.updateLoadedChunks(newX, newY)
        tile = WorldGen.getTile(newX, newY)

        -- If tile doesn't exist (shouldn't happen with WorldGen), log error
        if not tile then
            log("ERROR: Could not load tile at " .. newX .. ", " .. newY, {0.9, 0.3, 0.3})
            return false
        end
    else
        -- Legacy system: Handle expansion and mapData access
        local w, h = state.world.mapWidth, state.world.mapHeight
        local wOff = state.world.westOffset or 0
        local eOff = state.world.eastOffset or 0
        local nOff = state.world.northOffset or 0
        local sOff = state.world.southOffset or 0

        -- Check if we're at the edge and need to expand
        if newX < wOff then
            expandMap("west")
            wOff = state.world.westOffset or 0
        elseif newX >= w + eOff then
            expandMap("east")
        end
        if newY < nOff then
            expandMap("north")
            nOff = state.world.northOffset or 0
        elseif newY >= h + sOff then
            expandMap("south")
        end

        -- Make sure the tile exists
        if not state.world.mapData[newY] then
            state.world.mapData[newY] = {}
        end
        if not state.world.mapData[newY][newX] then
            state.world.mapData[newY][newX] = generateNewTile(state.player.level, state.world.expansionCount or 0, newX, newY)
        end
        tile = state.world.mapData[newY][newX]
    end

    local tileType = getTileType(tile.type)

    -- Check for mount terrain traversal
    local mount = Backpack.getEquippedMount()
    local canTraverse = tileType.passable

    if not canTraverse and mount then
        -- Aquatic mounts can cross water
        if mount.mountType == "aquatic" and tileType.isWater then
            canTraverse = true
            log("Your " .. mount.name .. " swims across the " .. tileType.name:lower() .. "!", {0.4, 0.6, 0.8})
        -- Boat mounts can cross water
        elseif mount.mountType == "boat" and tileType.isWater then
            canTraverse = true
            log("Your " .. mount.name .. " sails across the " .. tileType.name:lower() .. "!", {0.4, 0.6, 0.8})
        -- Flying mounts can cross any terrain
        elseif mount.mountType == "flying" then
            canTraverse = true
            log("Your " .. mount.name .. " flies over the " .. tileType.name .. "!", {0.6, 0.7, 0.9})
        end
    end

    if not canTraverse then
        if tileType.isWater and not mount then
            log("You cannot cross " .. tileType.name .. ". Try equipping an aquatic mount, boat, or flying mount!", {0.7, 0.5, 0.5})
        else
            log("You cannot cross " .. tileType.name .. ".", {0.7, 0.5, 0.5})
        end
        return false
    end

    -- Track path history (for Head Home feature)
    local oldX, oldY = state.world.playerX, state.world.playerY
    if state.world.homeTown then
        local pathLen = #state.world.pathHistory
        if pathLen > 0 then
            local lastPos = state.world.pathHistory[pathLen]
            if lastPos.x == newX and lastPos.y == newY then
                table.remove(state.world.pathHistory)
            else
                table.insert(state.world.pathHistory, {x = oldX, y = oldY})
            end
        else
            table.insert(state.world.pathHistory, {x = oldX, y = oldY})
        end
    end

    state.world.playerX = newX
    state.world.playerY = newY

    -- Mark tile and adjacent tiles as explored
    if state.world.useWorldGen then
        WorldGen.exploreTile(newX, newY)
        for ddy = -1, 1 do
            for ddx = -1, 1 do
                WorldGen.exploreTile(newX + ddx, newY + ddy)
            end
        end
    else
        tile.explored = true
        for ddy = -1, 1 do
            for ddx = -1, 1 do
                local ax, ay = newX + ddx, newY + ddy
                if not state.world.mapData[ay] then state.world.mapData[ay] = {} end
                if not state.world.mapData[ay][ax] then
                    state.world.mapData[ay][ax] = generateNewTile(state.player.level, state.world.expansionCount or 0, ax, ay)
                end
                state.world.mapData[ay][ax].explored = true
            end
        end
    end

    -- Passive mana regen: recover 1 MP per step while exploring the overworld
    if state.player and state.player.mana and state.player.maxMana then
        local manaRegen = state.player.manaRegen or 1
        state.player.mana = math.min(state.player.maxMana, state.player.mana + manaRegen)
    end

    -- Advance chasing enemies one step toward the player (turn-based chase)
    MapEnemies.onPlayerMoved()

    -- Check for map enemy collision (visible enemies on the world map)
    if state.world.mapEnemies then
        local collidedEnemy, collidedIndex = MapEnemies.checkPlayerCollision()
        if collidedEnemy then
            MapEnemies.triggerCombat(collidedEnemy, collidedIndex)
            return true
        end
    end

    -- Check for town
    if tile.type == "town" then
        local town = tile.town

        -- Convert anchor town to legacy format if needed (WorldGen mode)
        if state.world.useWorldGen and town and not town.shops then
            town = convertAnchorToLegacyTown(town)
            tile.town = town

            -- Add to towns list if not already there
            local found = false
            for _, t in ipairs(state.world.towns) do
                if t.name == town.name then
                    found = true
                    break
                end
            end
            if not found then
                table.insert(state.world.towns, town)
            end
        end

        if town then
            state.world.currentTown = town
            state.phase = "town"
            if not state.world.homeTown then
                state.world.homeTown = {town = town, x = newX, y = newY}
                log("Welcome to " .. town.name .. "! This is now your home base.", {0.5, 0.8, 0.5})
            elseif state.world.homeTown.town == town then
                log("Welcome home to " .. town.name .. "!", {0.5, 0.9, 0.5})
            else
                log("Welcome to " .. town.name .. "!", {0.5, 0.8, 0.5})
            end
            F.addJournalEvent("exploration", "Entered " .. town.name .. " (Lv." .. (town.level or "?") .. ")", {0.5, 0.8, 0.5})
            if state.player.journal and state.player.journal.actionStats and state.player.journal.actionStats.exploration then
                state.player.journal.actionStats.exploration.townsDiscovered = (state.player.journal.actionStats.exploration.townsDiscovered or 0) + 1
            end
            state.world.pathHistory = {}
            return true
        end
    end

    -- Check for dungeon - offer to enter
    if tile.type == "dungeon" then
        state.pendingDungeon = {x = newX, y = newY}
        log("You stand before a dark dungeon entrance. Press [E] to enter or move away.", {0.7, 0.5, 0.5})
        return true
    elseif tileType.isOceanCave then
        state.pendingDungeon = {x = newX, y = newY, isWaterDungeon = true}
        log("You discover a sea cave entrance beneath the waves. Press [E] to dive in or move away.", {0.3, 0.5, 0.7})
        return true
    elseif tileType.isShipwreck then
        state.pendingDungeon = {x = newX, y = newY, isWaterDungeon = true}
        log("A shipwreck looms ahead, half-submerged. Press [E] to explore or move away.", {0.4, 0.35, 0.3})
        return true
    elseif tileType.isWhirlpool then
        -- Whirlpool is a forced event - you can't avoid it once you step on it
        log("You sail into a massive whirlpool!", {0.3, 0.4, 0.7})
        local whirlpoolRoll = math.random(100)
        if whirlpoolRoll <= 50 then
            -- 50% chance: pulled into underwater dungeon
            log("The whirlpool drags you beneath the surface into an underground sea cave!", {0.2, 0.3, 0.6})
            F.enterDungeon(newX, newY, true)
        elseif whirlpoolRoll <= 80 then
            -- 30% chance: damage and displacement
            local damage = math.random(15, 30 + state.player.level * 2)
            state.player.hp = math.max(1, state.player.hp - damage)
            local displaceX = math.random(-4, 4)
            local displaceY = math.random(-4, 4)
            if displaceX == 0 and displaceY == 0 then displaceX = 3 end
            state.world.playerX = state.world.playerX + displaceX
            state.world.playerY = state.world.playerY + displaceY
            log("The whirlpool batters you for " .. damage .. " damage and hurls you across the sea!", {0.9, 0.4, 0.4})
        else
            -- 20% chance: treasure from the depths
            local goldFound = math.random(80, 250) + state.player.level * 15
            local xpFound = math.random(40, 100)
            state.player.gold = state.player.gold + goldFound
            state.player.xp = state.player.xp + xpFound
            log("The whirlpool churns up treasure from the deep!", {0.9, 0.8, 0.3})
            log("+" .. goldFound .. " gold, +" .. xpFound .. " XP!", {0.9, 0.9, 0.4})
        end
        return true
    else
        state.pendingDungeon = nil
    end

    -- Random encounter based on terrain and weather
    -- Using global Backpack
    local mount = Backpack.getEquippedMount()
    local encounterChance = tileType.encounterRate

    -- Mounts reduce encounter rate (flying 70%, carts 50%, etc.)
    if mount then
        local encounterReduction = Backpack.getMountEncounterReduction()
        encounterChance = encounterChance * encounterReduction
    end

    -- Weather affects encounter chance (foggy = more ambushes)
    if weatherFx.ambushChance then
        encounterChance = encounterChance + weatherFx.ambushChance
    end

    if math.random() < encounterChance then
        local enemies = F.generateEncounter(state.player.level, tileType)
        if weatherFx.ambushChance and math.random() < 0.5 then
            log("Ambushed in the " .. weatherFx.name:lower() .. "!", {0.9, 0.5, 0.3})
        end
        -- Special message for corrupted terrain
        if tileType.undeadOnly then
            log("Undead rise from the corrupted ground!", {0.6, 0.2, 0.6})
        end
        -- Special messages for sea encounters
        if tileType.seaOnly then
            local seaMessages = {
                "Something stirs beneath the waves!",
                "Creatures emerge from the deep!",
                "The waters churn with hostile life!",
                "Danger surfaces from below!",
            }
            log(seaMessages[math.random(#seaMessages)], {0.3, 0.5, 0.8})
        end
        F.startCombat(enemies)
        return true
    end

    -- Water events (only on water tiles when no combat encounter)
    if tileType.isWater then
        -- Apply dolphin buff if active (reduces encounter rate, already applied above)
        if state.waterBuff and state.waterBuff.turnsLeft then
            state.waterBuff.turnsLeft = state.waterBuff.turnsLeft - 1
            if state.waterBuff.turnsLeft <= 0 then
                state.waterBuff = nil
                log("The dolphins' guidance fades.", {0.5, 0.6, 0.7})
            end
        end
        -- Roll for a water event
        local waterEvent = rollWaterEvent(tileType)
        if waterEvent then
            handleWaterEvent(waterEvent)
            -- If event started combat, return
            if state.phase == "combat" then
                return true
            end
        end
    end

    -- Calculate total travel speed (weather, mount, encumbrance, beast)
    local baseSpeed = weatherFx.travelSpeed
    local totalSpeedMult = Backpack.getTravelSpeedMultiplier(playerMight)
    local finalSpeed = baseSpeed * totalSpeedMult

    -- Update weather tracking (1 hour per tile traveled, affected by all speed modifiers)
    local travelTime = 1 / finalSpeed
    F.updateWeather(travelTime)

    -- Update beast needs during travel
    Backpack.updateBeastNeeds(travelTime * 60, true)  -- Convert to minutes, isMoving=true

    -- Check beast condition and warn player
    local beast = Backpack.getEquippedBeast()
    if beast then
        local beastCondition = Backpack.getBeastCondition()
        if beastCondition ~= "Good" then
            log("Your " .. beast.name .. " is " .. beastCondition:lower() .. "!", {0.9, 0.7, 0.3})
        end
    end

    -- Movement message with context
    local notes = {}
    if weatherFx.needsShelter then
        table.insert(notes, weatherFx.name:lower())
    end
    if encumbrance.level == "heavy" or encumbrance.level == "overencumbered" then
        table.insert(notes, "heavy load")
    end

    local contextNote = ""
    if #notes > 0 then
        contextNote = " (" .. table.concat(notes, ", ") .. " slows travel)"
    end

    if tileType.isWater and mount then
        -- Water-specific travel messages
        local waterMsgs = {
            deep_ocean = {
                "You sail across the vast deep ocean" .. contextNote .. "...",
                "Dark waters stretch endlessly in every direction" .. contextNote .. "...",
                "The deep ocean swells beneath your vessel" .. contextNote .. "...",
            },
            shallow_water = {
                "You navigate through shallow waters" .. contextNote .. "...",
                "The seafloor is visible through the clear shallows" .. contextNote .. "...",
            },
            coastal = {
                "You sail along the coast" .. contextNote .. "...",
                "Land is visible on the horizon as you travel" .. contextNote .. "...",
            },
            reef = {
                "You carefully navigate through the coral reef" .. contextNote .. "...",
                "Colorful coral formations surround you" .. contextNote .. "...",
            },
            river = {
                "You travel along the river" .. contextNote .. "...",
                "The current carries you downstream" .. contextNote .. "...",
            },
            lake = {
                "You cross the peaceful lake" .. contextNote .. "...",
                "Calm waters mirror the sky above" .. contextNote .. "...",
            },
        }
        local msgs = waterMsgs[tileType.id] or {"You sail across the " .. tileType.name:lower() .. contextNote .. "..."}
        log(msgs[math.random(#msgs)], {0.3, 0.5, 0.7})
    elseif mount then
        local speedMult = Backpack.getMountSpeedMultiplier()
        if speedMult > 1 then
            log("Riding " .. mount.name .. " through " .. tileType.name .. contextNote .. "...", {0.6, 0.6, 0.6})
        else
            log("Traveling through " .. tileType.name .. contextNote .. "...", {0.6, 0.6, 0.6})
        end
    else
        log("Traveling through " .. tileType.name .. contextNote .. "...", {0.6, 0.6, 0.6})
    end

    -- Check for nearby crypts/vampire dens and generate rumors (proximity-based)
    if state.world.useWorldGen and math.random() < 0.15 then  -- 15% chance per move
        local nearbyDungeons = WorldGen.getNearbyDungeons(newX, newY, 5)  -- 5 tile radius
        if nearbyDungeons and #nearbyDungeons > 0 then
            local RumorSystem = require("rumorsystem")
            RumorSystem.init(state)

            for _, entry in ipairs(nearbyDungeons) do
                local dungeon = entry.dungeon or entry
                if dungeon.type == "vampire_den" then
                    -- Vampire den proximity - eerie feeling
                    if math.random() < 0.4 then  -- 40% chance if nearby
                        log("You feel an unsettling presence nearby... something watches from the shadows.", {0.5, 0.3, 0.4})
                        RumorSystem.onVampireSighting(dungeon.x, dungeon.y, "a dark place nearby", nil)
                    end
                    break
                elseif dungeon.type == "crypt" then
                    -- Crypt proximity - ghostly sounds
                    if math.random() < 0.35 then  -- 35% chance if nearby
                        log("You hear faint moaning on the wind... spirits stir somewhere close.", {0.5, 0.5, 0.6})
                        RumorSystem.onGhostSighting(dungeon.x, dungeon.y, "an old burial ground nearby", nil)
                    end
                    break
                elseif dungeon.type == "lich_lair" then
                    -- Lich lair proximity - overwhelming dread
                    if math.random() < 0.5 then  -- 50% chance if nearby
                        log("A wave of dread washes over you. Dark magic permeates this area...", {0.4, 0.2, 0.5})
                        RumorSystem.onLichActivity({x = dungeon.x, y = dungeon.y, corruptedTiles = 0}, WorldGen)
                    end
                    break
                end
            end
        end
    end

    -- Periodic memory cleanup to prevent unbounded map growth
    state.world.moveCount = (state.world.moveCount or 0) + 1
    if state.world.moveCount % 100 == 0 then
        cleanupDistantTiles()
    end

    -- Check for Luminary patrol encounters
    local activePatrols = LuminaryPatrols.getActivePatrols()
    for patrolId, patrol in pairs(activePatrols) do
        local dist = math.abs(state.world.playerX - patrol.centerX) +
                    math.abs(state.world.playerY - patrol.centerY)
        if dist <= patrol.radius then
            LuminaryPatrols.handlePatrolEncounter(patrol)
            break
        end
    end

    return true
end

return M
