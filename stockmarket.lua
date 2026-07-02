-- Market Simulator Mode
-- Buy and sell goods that fluctuate randomly in price
-- Merged with physical goods trading system

local StockMarket = {}
local UI = require("ui")
local UIAssets = require("uiassets")
local Employees = require("employees")
local UpgradeSystem = require("upgradesystem")
local Backpack = require("backpack")
local InteractiveTutorial = require("interactivetutorial")

-- Cached item images
local itemImages = {}
local imagesLoaded = false

-- Load item images from assets
local function loadItemImages()
    if imagesLoaded then return end

    local itemPaths = {
        -- Stock images
        WHEAT = "assets/icons/resourcesandfood/Res_73_wheat.PNG",
        ALE = "assets/icons/resourcesandfood/BeerBottle.PNG",
        POTN = "assets/icons/loot/PotionBlue.png",
        IRON = "assets/icons/resources/Iron_bar.png",
        SILK = "assets/icons/resources/Res_68_cloth.PNG",
        GEMS = "assets/icons/resources/Ruby.png",
        FISH = "assets/icons/resourcesandfood/FishBlueFried.PNG",
        WINE = "assets/icons/resourcesandfood/Wine.PNG",
        -- Physical goods images
        iron_ore = "assets/icons/resources/Res_62_iron_ore.PNG",
        steel_ingot = "assets/icons/resources/Res_71_iron_bar.PNG",
        mythril_shard = "assets/icons/resources/Gem_05.png",
        dragon_scale = "assets/icons/resources/Res_69_scale.PNG",
        leather_scraps = "assets/icons/resources/Res_68_cloth.PNG",
        wood_planks = "assets/icons/resources/Res_67_coal.PNG",
        mana_crystal = "assets/icons/resourcesandfood/Res_167_MageCrystal.PNG",
        fire_essence = "assets/icons/resourcesandfood/Res_76_crystalRed.PNG",
        frost_essence = "assets/icons/resourcesandfood/Res_25_crystal.PNG",
        arcane_dust = "assets/icons/resourcesandfood/Res_75_crystalS.PNG",
        ancient_scroll = "assets/icons/quest/Quest_17_scroll.PNG",
        enchanted_ink = "assets/icons/resourcesandfood/BlackInk.PNG",
        healing_herb = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_01_herbs.PNG",
        moonflower = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_05_flower.PNG",
        venom_sac = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_05_poison.PNG",
        troll_blood = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_06_blood.PNG",
        phoenix_feather = "assets/icons/loot/Loot_157_ribbon.PNG",
        empty_vial = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_19_little_flask.PNG",
        gold_coin = "assets/icons/loot/Loot_01_coins.PNG",
        gem_ruby = "assets/icons/resourcesandfood/Res_25_crystal.PNG",
        gem_sapphire = "assets/icons/resourcesandfood/Res_76_crystalRed.PNG",
        gem_emerald = "assets/icons/resourcesandfood/Res_75_crystalS.PNG",
        iron_sword = "assets/icons/weapons/Sword_01.PNG",
        steel_sword = "assets/icons/weapons/Sword_05.PNG",
        iron_dagger = "assets/icons/weapons/Dagger_01.PNG",
        steel_axe = "assets/icons/weapons/Axe_01.PNG",
        leather_armor = "assets/icons/armor/LeatherChest1.PNG",
        chainmail = "assets/icons/armor/MailChest.PNG",
        iron_helmet = "assets/icons/armor/MetalHelmet.PNG",
        steel_shield = "assets/icons/weapons/Shield_01.PNG",
        health_potion = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_13_heal_potion.PNG",
        mana_potion = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_17_blue_potion.PNG",
        strength_potion = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_15_reactive_potion.PNG",
        speed_potion = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_24_energy_potion.PNG",
        fire_spell = "assets/icons/quest/Quest_143_spellscroll.PNG",
        frost_spell = "assets/icons/quest/Quest_144_spellscroll.PNG",
        heal_spell = "assets/icons/quest/Quest_145_spellscroll.PNG",
        lightning_spell = "assets/icons/quest/Quest_40_scroll.PNG",
    }

    for id, path in pairs(itemPaths) do
        local success, img = pcall(function()
            return love.graphics.newImage(path)
        end)
        if success then
            itemImages[id] = img
        end
    end

    imagesLoaded = true
end

-- Goods definitions (tradeable items with fluctuating prices)
local stocks = {
    {id = "WHEAT", name = "Wheat Bushels", color = {0.9, 0.85, 0.3}, volatility = 0.02, trend = 0.001},
    {id = "ALE", name = "Tavern Ale", color = {0.9, 0.7, 0.2}, volatility = 0.04, trend = 0},
    {id = "POTN", name = "Health Potions", color = {0.7, 0.3, 0.9}, volatility = 0.05, trend = 0},
    {id = "IRON", name = "Iron Ingots", color = {0.5, 0.5, 0.6}, volatility = 0.035, trend = 0},
    {id = "SILK", name = "Fine Silk", color = {0.8, 0.4, 0.6}, volatility = 0.045, trend = 0},
    {id = "GEMS", name = "Precious Gems", color = {0.9, 0.2, 0.3}, volatility = 0.06, trend = 0},
    {id = "FISH", name = "Fresh Fish", color = {0.2, 0.6, 0.8}, volatility = 0.03, trend = 0},
    {id = "WINE", name = "Aged Wine", color = {0.6, 0.2, 0.4}, volatility = 0.025, trend = 0.002},
}

-- Physical goods definitions (from market.lua)
local PHYSICAL_GOODS = {
    -- Materials
    {id = "iron_ore", name = "Iron Ore", ticker = "IORE", basePrice = 15, category = "material", volatility = 0.15, trend = 0, lore = "Essential for smithing. Miners risk their lives in deep caverns to extract this precious ore.", color = {0.5, 0.4, 0.3}},
    {id = "steel_ingot", name = "Steel Ingot", ticker = "STLG", basePrice = 35, category = "material", volatility = 0.12, trend = 0, lore = "Refined steel from the master forges. The backbone of any warrior's equipment.", color = {0.6, 0.6, 0.7}},
    {id = "mythril_shard", name = "Mythril Shard", ticker = "MYTH", basePrice = 150, category = "material", volatility = 0.25, trend = 0, lore = "Fragments of the legendary mythril ore. Said to hold ancient magic within.", color = {0.7, 0.8, 0.9}},
    {id = "dragon_scale", name = "Dragon Scale", ticker = "DRGN", basePrice = 300, category = "material", volatility = 0.30, trend = 0, lore = "Scales shed by dragons during their molting season. Nearly indestructible.", color = {0.8, 0.2, 0.2}},
    {id = "leather_scraps", name = "Leather Scraps", ticker = "LTHR", basePrice = 12, category = "material", volatility = 0.10, trend = 0, lore = "Tanned leather from various beasts. A craftsman's staple material.", color = {0.5, 0.3, 0.2}},
    {id = "wood_planks", name = "Wood Planks", ticker = "WOOD", basePrice = 8, category = "material", volatility = 0.08, trend = 0, lore = "Sturdy planks from the Elderwood Forest. Excellent for handles and frames.", color = {0.5, 0.3, 0.1}},

    -- Wizard materials
    {id = "mana_crystal", name = "Mana Crystal", ticker = "MANA", basePrice = 45, category = "material", volatility = 0.20, trend = 0, lore = "Crystallized pure mana. Wizards hoard these like dragons hoard gold.", color = {0.4, 0.6, 1.0}},
    {id = "fire_essence", name = "Fire Essence", ticker = "FIRE", basePrice = 30, category = "material", volatility = 0.18, trend = 0, lore = "Captured flames from elemental beings. Handle with extreme caution.", color = {1.0, 0.4, 0.1}},
    {id = "frost_essence", name = "Frost Essence", ticker = "FRST", basePrice = 30, category = "material", volatility = 0.18, trend = 0, lore = "Frozen magical cores from the northern wastes. Cold to the touch even in summer.", color = {0.5, 0.8, 1.0}},
    {id = "arcane_dust", name = "Arcane Dust", ticker = "ARCD", basePrice = 22, category = "material", volatility = 0.15, trend = 0, lore = "Residue from powerful spells. Scholars pay handsomely for quality dust.", color = {0.7, 0.5, 0.9}},
    {id = "ancient_scroll", name = "Ancient Scroll", ticker = "SCRL", basePrice = 75, category = "material", volatility = 0.22, trend = 0, lore = "Scrolls bearing forgotten knowledge. What secrets do they hold?", color = {0.9, 0.8, 0.6}},
    {id = "enchanted_ink", name = "Enchanted Ink", ticker = "EINK", basePrice = 40, category = "material", volatility = 0.16, trend = 0, lore = "Ink infused with magical properties. Required for inscribing spells.", color = {0.3, 0.3, 0.6}},

    -- Alchemy materials
    {id = "healing_herb", name = "Healing Herb", ticker = "HERB", basePrice = 8, category = "material", volatility = 0.12, trend = 0, lore = "Common medicinal plant found in meadows. The foundation of healing arts.", color = {0.4, 0.7, 0.3}},
    {id = "moonflower", name = "Moonflower", ticker = "MOON", basePrice = 25, category = "material", volatility = 0.20, trend = 0, lore = "Blooms only under the full moon's light. Alchemists treasure its petals.", color = {0.8, 0.8, 1.0}},
    {id = "venom_sac", name = "Venom Sac", ticker = "VENM", basePrice = 35, category = "material", volatility = 0.22, trend = 0, lore = "Extracted from venomous creatures. Deadly in the wrong hands.", color = {0.5, 0.8, 0.3}},
    {id = "troll_blood", name = "Troll Blood", ticker = "TRBL", basePrice = 55, category = "material", volatility = 0.25, trend = 0, lore = "The regenerative properties are legendary. Trolls don't part with it willingly.", color = {0.6, 0.2, 0.2}},
    {id = "phoenix_feather", name = "Phoenix Feather", ticker = "PHNX", basePrice = 250, category = "material", volatility = 0.35, trend = 0, lore = "A feather from the immortal phoenix. Burns with eternal warmth.", color = {1.0, 0.5, 0.1}},
    {id = "empty_vial", name = "Empty Vial", ticker = "VIAL", basePrice = 5, category = "material", volatility = 0.05, trend = 0, lore = "Standard glass containers. Every alchemist needs a good supply.", color = {0.7, 0.7, 0.8}},

    -- Treasures
    {id = "gold_coin", name = "Gold Coin", ticker = "GCOIN", basePrice = 60, category = "treasure", volatility = 0.08, trend = 0, lore = "Ancient coins from the old kingdom. Collectors pay premium prices.", color = {1.0, 0.85, 0.2}},
    {id = "gem_ruby", name = "Ruby", ticker = "RUBY", basePrice = 120, category = "treasure", volatility = 0.18, trend = 0, lore = "The crimson fire ruby. Said to grant courage to its bearer.", color = {0.9, 0.1, 0.2}},
    {id = "gem_sapphire", name = "Sapphire", ticker = "SAPH", basePrice = 115, category = "treasure", volatility = 0.18, trend = 0, lore = "Deep blue sapphire from ocean depths. Sailors consider them lucky.", color = {0.1, 0.3, 0.9}},
    {id = "gem_emerald", name = "Emerald", ticker = "EMRD", basePrice = 110, category = "treasure", volatility = 0.18, trend = 0, lore = "The verdant emerald. Nature spirits are drawn to its presence.", color = {0.2, 0.8, 0.3}},

    -- Weapons
    {id = "iron_sword", name = "Iron Sword", ticker = "ISWD", basePrice = 80, category = "weapon", volatility = 0.10, trend = 0, lore = "A reliable blade for any adventurer. Won't let you down in battle.", color = {0.5, 0.5, 0.5}},
    {id = "steel_sword", name = "Steel Sword", ticker = "SSWD", basePrice = 180, category = "weapon", volatility = 0.12, trend = 0, lore = "Masterfully forged steel blade. The choice of veteran warriors.", color = {0.7, 0.7, 0.7}},
    {id = "iron_dagger", name = "Iron Dagger", ticker = "IDGR", basePrice = 55, category = "weapon", volatility = 0.10, trend = 0, lore = "Quick and deadly in skilled hands. Rogues favor these weapons.", color = {0.4, 0.4, 0.5}},
    {id = "steel_axe", name = "Steel Axe", ticker = "SAXE", basePrice = 160, category = "weapon", volatility = 0.14, trend = 0, lore = "A fearsome battle axe. One swing can cleave through armor.", color = {0.6, 0.5, 0.5}},

    -- Armor
    {id = "leather_armor", name = "Leather Armor", ticker = "LARM", basePrice = 65, category = "armor", volatility = 0.10, trend = 0, lore = "Light but protective. Preferred by scouts and archers.", color = {0.5, 0.3, 0.2}},
    {id = "chainmail", name = "Chainmail", ticker = "CHNM", basePrice = 150, category = "armor", volatility = 0.12, trend = 0, lore = "Thousands of linked rings. A soldier's trusted companion.", color = {0.5, 0.5, 0.6}},
    {id = "iron_helmet", name = "Iron Helmet", ticker = "IHLM", basePrice = 70, category = "armor", volatility = 0.10, trend = 0, lore = "Protects your head from enemy blows. Essential for frontline combat.", color = {0.4, 0.4, 0.5}},
    {id = "steel_shield", name = "Steel Shield", ticker = "SSHL", basePrice = 120, category = "armor", volatility = 0.11, trend = 0, lore = "A sturdy shield for blocking attacks. Defense is the best offense.", color = {0.6, 0.6, 0.7}},

    -- Potions
    {id = "health_potion", name = "Health Potion", ticker = "HPOT", basePrice = 25, category = "potion", volatility = 0.15, trend = 0, lore = "Restores vitality in times of need. Never adventure without one.", color = {0.9, 0.2, 0.2}},
    {id = "mana_potion", name = "Mana Potion", ticker = "MPOT", basePrice = 25, category = "potion", volatility = 0.15, trend = 0, lore = "Replenishes magical energy. A wizard's best friend.", color = {0.2, 0.4, 0.9}},
    {id = "strength_potion", name = "Strength Potion", ticker = "SPOT", basePrice = 55, category = "potion", volatility = 0.18, trend = 0, lore = "Temporarily grants the strength of ten men. Handle with care.", color = {0.8, 0.5, 0.2}},
    {id = "speed_potion", name = "Speed Potion", ticker = "ZPOT", basePrice = 50, category = "potion", volatility = 0.18, trend = 0, lore = "Makes you faster than the wind. Time seems to slow around you.", color = {0.7, 0.9, 0.3}},

    -- Spells
    {id = "fire_spell", name = "Fire Spell", ticker = "FSPL", basePrice = 85, category = "spell", volatility = 0.20, trend = 0, lore = "A scroll containing the secrets of flame. Burn your enemies to ash.", color = {1.0, 0.3, 0.1}},
    {id = "frost_spell", name = "Frost Spell", ticker = "CSPL", basePrice = 80, category = "spell", volatility = 0.20, trend = 0, lore = "Harness the cold of winter itself. Freeze foes in their tracks.", color = {0.4, 0.7, 1.0}},
    {id = "heal_spell", name = "Heal Spell", ticker = "HSPL", basePrice = 100, category = "spell", volatility = 0.18, trend = 0, lore = "Divine healing magic preserved on parchment. Mend wounds instantly.", color = {0.9, 0.9, 0.3}},
    {id = "lightning_spell", name = "Lightning Spell", ticker = "LSPL", basePrice = 110, category = "spell", volatility = 0.22, trend = 0, lore = "Command the fury of storms. Strike with thunderous power.", color = {0.8, 0.8, 1.0}},
}

-- Game state
local state = {
    cash = 1000,
    portfolio = {},  -- {stockId = quantity}
    stockPrices = {},  -- Current prices
    priceHistory = {},  -- History for charts
    historyLength = 100,

    -- Physical goods state
    physicalGoods = {},  -- Not used - items go to backpack
    goodsPrices = {},  -- Current prices for physical goods
    goodsHistory = {},  -- History for physical goods charts
    tradingSubTab = "stocks",  -- "stocks" or "goods"

    day = 1,
    hour = 9,  -- Market hours 9-16
    marketOpen = true,

    speed = 1,  -- 1 = normal, 2 = fast, 3 = faster
    paused = false,

    timer = 0,
    tickRate = 1,  -- seconds per market tick

    selectedStock = nil,
    buyAmount = 1,

    news = {},  -- Recent market news
    newsTimer = 0,
    goodsNews = {},  -- Recent goods market news
    goodsNewsTimer = 0,
    selectedGood = nil,  -- Currently selected physical good ID
    goodsBuyAmount = 1,  -- Buy/sell amount for goods
    goodsScroll = 0,  -- Scroll offset for goods list

    stats = {
        totalProfit = 0,
        totalTrades = 0,
        bestTrade = 0,
        worstTrade = 0,
    },

    -- Employees and upgrades
    employees = {},
    hiringPool = {},
    upgradeLevels = {},
    currentBuild = nil,
    tab = "trading",  -- "trading", "employees", "upgrades"
    playerLevel = 1,
    totalEarnings = 0,
    dividendTimer = 0,
}

local buttons = {}

-- UI Components
local uiComponents = {
    mainTabs = nil,
    tradingSubTabs = nil,
    speedButtons = {},
    pauseButton = nil,
    backButton = nil,
    amountButtons = {},
    buyButton = nil,
    sellButton = nil,
    goodsAmountButtons = {},
    buyGoodButton = nil,
    sellGoodButton = nil,
    refreshPoolButton = nil,
    hireButtons = {},
    fireButtons = {},
    upgradeButtons = {},
}

-- Initialize physical goods prices
local function initPhysicalGoodsPrices()
    for _, good in ipairs(PHYSICAL_GOODS) do
        if not state.goodsPrices[good.id] then
            -- Start at base price with small random variance
            local variance = 1 + (math.random() - 0.5) * 0.2
            state.goodsPrices[good.id] = math.floor(good.basePrice * variance)
        end
        if not state.goodsHistory[good.id] then
            -- Initialize history with some data
            state.goodsHistory[good.id] = {}
            local price = state.goodsPrices[good.id]
            for i = 1, state.historyLength do
                price = price * (1 + (math.random() - 0.5) * good.volatility)
                price = math.max(1, math.floor(price))
                table.insert(state.goodsHistory[good.id], price)
            end
            state.goodsPrices[good.id] = price
        end
    end
end

-- Save portfolio and state to PlayerData
function StockMarket.save()
    PlayerData.stockMarket = {
        portfolio = state.portfolio,
        stockPrices = state.stockPrices,
        priceHistory = state.priceHistory,
        day = state.day,
        stats = state.stats,
        employees = Employees.save(state.employees),
        upgradeLevels = state.upgradeLevels,
        currentBuild = state.currentBuild,
        playerLevel = state.playerLevel,
        totalEarnings = state.totalEarnings,
        goodsPrices = state.goodsPrices,
        goodsHistory = state.goodsHistory,
        tradingSubTab = state.tradingSubTab,
    }
    savePlayerData()
end

-- Load saved portfolio data
function StockMarket.load()
    if PlayerData.stockMarket then
        return PlayerData.stockMarket
    end
    return nil
end

-- Initialize UI components
local function initUIComponents()
    -- Main tabs
    uiComponents.mainTabs = UI.TabBar.new({
        x = 20,
        y = 62,
        w = 315,
        tabs = {
            {id = "trading", label = "Trading"},
            {id = "employees", label = "Employees"},
            {id = "upgrades", label = "Upgrades"}
        },
        activeTab = state.tab,
        onChange = function(tabId)
            state.tab = tabId
        end
    })

    -- Trading sub-tabs
    uiComponents.tradingSubTabs = UI.TabBar.new({
        x = 340,
        y = 62,
        w = 245,
        tabs = {
            {id = "stocks", label = "Stocks"},
            {id = "goods", label = "Physical Goods"}
        },
        activeTab = state.tradingSubTab,
        onChange = function(tabId)
            state.tradingSubTab = tabId
            state.selectedStock = nil
            state.selectedGood = nil
        end
    })

    -- Speed buttons
    for i = 1, 3 do
        local speed = i  -- Capture in local variable for closure
        uiComponents.speedButtons[i] = UI.Button.new({
            x = 500 + 50 + (i - 1) * 35,
            y = 18,
            w = 30,
            h = 25,
            text = i .. "x",
            variant = (state.speed == i) and "primary" or "ghost",
            onClick = function()
                state.speed = speed
                -- Update button variants
                for j = 1, 3 do
                    uiComponents.speedButtons[j].variant = (j == speed) and "primary" or "ghost"
                end
            end
        })
    end

    -- Pause button
    uiComponents.pauseButton = UI.Button.new({
        x = 500 + 160,
        y = 18,
        w = 50,
        h = 25,
        text = state.paused and "PLAY" or "PAUSE",
        variant = state.paused and "success" or "ghost",
        onClick = function()
            state.paused = not state.paused
            uiComponents.pauseButton.text = state.paused and "PLAY" or "PAUSE"
            uiComponents.pauseButton.variant = state.paused and "success" or "ghost"
        end
    })

    -- Back button
    uiComponents.backButton = UI.Button.new({
        x = 20,
        y = 0, -- Will be updated in draw
        w = 80,
        h = 35,
        text = "Back",
        variant = "danger",
        onClick = function()
            StockMarket.save()
            PlayerData.coins = math.floor(PlayerData.coins)
            savePlayerData()
            local TextRPG = require("textrpg")
            TextRPG.init()
            GameState.current = "textrpg"
        end
    })
end

function StockMarket.init()
    loadItemImages()

    -- Register UI region resolver for interactive tutorials
    InteractiveTutorial.registerRegionResolver("stockmarket", StockMarket.getUIRegion)

    local saved = StockMarket.load()

    state.selectedStock = nil
    state.selectedGood = nil
    state.goodsBuyAmount = 1
    state.goodsScroll = 0
    state.news = {}
    state.goodsNews = {}
    state.goodsNewsTimer = 0
    state.paused = false
    state.hour = 9
    state.marketOpen = true
    state.tab = "trading"

    if saved and saved.portfolio then
        -- Load saved data
        state.portfolio = saved.portfolio
        state.stockPrices = saved.stockPrices or {}
        state.priceHistory = saved.priceHistory or {}
        state.day = saved.day or 1
        state.stats = saved.stats or {totalProfit = 0, totalTrades = 0, bestTrade = 0, worstTrade = 0}

        -- Load employees and upgrades
        state.employees = Employees.load(saved.employees) or {}
        state.upgradeLevels = saved.upgradeLevels or {}
        state.currentBuild = saved.currentBuild
        state.playerLevel = saved.playerLevel or 1
        state.totalEarnings = saved.totalEarnings or 0

        -- Load physical goods state
        state.goodsPrices = saved.goodsPrices or {}
        state.goodsHistory = saved.goodsHistory or {}
        state.tradingSubTab = saved.tradingSubTab or "stocks"

        -- Make sure all stocks have prices and history
        for _, stock in ipairs(stocks) do
            if not state.stockPrices[stock.id] then
                state.stockPrices[stock.id] = 50 + math.random() * 100
            end
            if not state.priceHistory[stock.id] then
                state.priceHistory[stock.id] = {}
                local price = state.stockPrices[stock.id]
                for i = 1, state.historyLength do
                    price = price * (1 + (math.random() - 0.5) * stock.volatility)
                    price = math.max(1, price)
                    table.insert(state.priceHistory[stock.id], price)
                end
                state.stockPrices[stock.id] = price
            end
            if not state.portfolio[stock.id] then
                state.portfolio[stock.id] = 0
            end
        end
    else
        -- Fresh start
        PlayerData.coins = PlayerData.coins or 1000
        state.portfolio = {}
        state.stockPrices = {}
        state.priceHistory = {}
        state.day = 1
        state.stats = {totalProfit = 0, totalTrades = 0, bestTrade = 0, worstTrade = 0}

        -- Fresh employees and upgrades
        state.employees = {}
        state.upgradeLevels = {}
        state.currentBuild = nil
        state.playerLevel = 1
        state.totalEarnings = 0

        -- Fresh physical goods
        state.goodsPrices = {}
        state.goodsHistory = {}
        state.tradingSubTab = "stocks"

        -- Initialize stock prices
        for _, stock in ipairs(stocks) do
            state.stockPrices[stock.id] = 50 + math.random() * 100  -- $50-$150 starting price
            state.priceHistory[stock.id] = {}
            state.portfolio[stock.id] = 0

            -- Initialize history with some data
            local price = state.stockPrices[stock.id]
            for i = 1, state.historyLength do
                price = price * (1 + (math.random() - 0.5) * stock.volatility)
                price = math.max(1, price)
                table.insert(state.priceHistory[stock.id], price)
            end
            state.stockPrices[stock.id] = price
        end
    end

    -- Initialize physical goods prices
    initPhysicalGoodsPrices()

    -- Generate initial hiring pool
    state.hiringPool = Employees.generateHiringPool("stock_market", 3, state.playerLevel)

    -- Calculate initial passive income rate
    StockMarket.updatePassiveIncomeRate()

    -- Add initial news
    StockMarket.generateNews()
    StockMarket.generateGoodsNews()

    -- Initialize UI components
    initUIComponents()

    -- Initialize backpack
    if Backpack and Backpack.init then
        Backpack.init()
    end
end

function StockMarket.generateNews()
    local newsTemplates = {
        {text = "%s reports bountiful season profits!", effect = 0.1},
        {text = "Royal inspectors investigate %s practices", effect = -0.08},
        {text = "Guild masters recommend %s shares", effect = 0.05},
        {text = "%s announces new trade route to Eastmarch", effect = 0.07},
        {text = "Bandit raids disrupt %s operations", effect = -0.05},
        {text = "%s unveils new enchanted wares", effect = 0.06},
        {text = "Rumors of embezzlement at %s", effect = -0.1},
        {text = "%s exceeds harvest expectations", effect = 0.08},
        {text = "Rival guild challenges %s dominance", effect = -0.04},
        {text = "%s secures contract with Crown", effect = 0.09},
        {text = "Dragon sighting near %s warehouses", effect = -0.06},
        {text = "%s discovers new ore vein!", effect = 0.12},
        {text = "Mysterious illness affects %s workers", effect = -0.07},
        {text = "Festival boosts %s sales", effect = 0.05},
        {text = "%s master craftsman wins royal favor", effect = 0.08},
    }

    local stock = stocks[math.random(#stocks)]
    local template = newsTemplates[math.random(#newsTemplates)]

    local newsItem = {
        text = string.format(template.text, stock.name),
        stockId = stock.id,
        effect = template.effect,
        time = state.day .. ":" .. string.format("%02d", state.hour)
    }

    table.insert(state.news, 1, newsItem)
    if #state.news > 5 then
        table.remove(state.news)
    end

    -- Apply effect to stock's trend
    for _, s in ipairs(stocks) do
        if s.id == stock.id then
            s.trend = s.trend + template.effect * 0.5
            s.trend = math.max(-0.1, math.min(0.1, s.trend))
            break
        end
    end

    return newsItem
end

function StockMarket.generateGoodsNews()
    local newsTemplates = {
        {text = "%s supply caravan ambushed on trade road!", effect = -0.08},
        {text = "Massive %s deposit discovered in the mines!", effect = 0.10},
        {text = "Royal army places bulk order for %s", effect = 0.07},
        {text = "Flood destroys %s warehouse stocks", effect = -0.10},
        {text = "New crafting technique increases %s demand", effect = 0.06},
        {text = "Merchants boycott %s imports from Eastmarch", effect = -0.05},
        {text = "Festival season drives %s sales through the roof!", effect = 0.09},
        {text = "Counterfeit %s scandal rocks the market", effect = -0.07},
        {text = "Adventurer guild stockpiling %s for expedition", effect = 0.08},
        {text = "Overproduction of %s floods market with surplus", effect = -0.06},
        {text = "Alchemist breakthrough increases %s value!", effect = 0.11},
        {text = "Trade embargo cuts off %s supply lines", effect = -0.09},
        {text = "Noble house commissions massive %s order", effect = 0.07},
        {text = "Thieves guild raids %s storehouse", effect = -0.05},
        {text = "Enchantment craze boosts %s demand!", effect = 0.08},
    }

    local good = PHYSICAL_GOODS[math.random(#PHYSICAL_GOODS)]
    local template = newsTemplates[math.random(#newsTemplates)]

    local newsItem = {
        text = string.format(template.text, good.name),
        goodId = good.id,
        effect = template.effect,
        time = state.day .. ":" .. string.format("%02d", state.hour)
    }

    table.insert(state.goodsNews, 1, newsItem)
    if #state.goodsNews > 5 then
        table.remove(state.goodsNews)
    end

    -- Apply effect to good's trend
    for _, g in ipairs(PHYSICAL_GOODS) do
        if g.id == good.id then
            g.trend = (g.trend or 0) + template.effect * 0.5
            g.trend = math.max(-0.1, math.min(0.1, g.trend))
            break
        end
    end

    return newsItem
end

function StockMarket.updatePrices()
    -- Update stock prices
    for _, stock in ipairs(stocks) do
        local price = state.stockPrices[stock.id]

        -- Random walk with trend and volatility
        local change = (math.random() - 0.5) * 2 * stock.volatility
        change = change + stock.trend

        -- Mean reversion for extreme prices
        if price > 300 then
            change = change - 0.02
        elseif price < 10 then
            change = change + 0.02
        end

        price = price * (1 + change)
        price = math.max(1, price)  -- Minimum $1

        state.stockPrices[stock.id] = price

        -- Update history
        table.insert(state.priceHistory[stock.id], price)
        if #state.priceHistory[stock.id] > state.historyLength then
            table.remove(state.priceHistory[stock.id], 1)
        end

        -- Decay trend over time
        stock.trend = stock.trend * 0.95
    end

    -- Update physical goods prices
    for _, good in ipairs(PHYSICAL_GOODS) do
        local currentPrice = state.goodsPrices[good.id]
        local volatility = good.volatility or 0.1

        -- Random walk with trend and mean reversion
        local change = (math.random() - 0.5) * 2 * volatility
        change = change + (good.trend or 0)
        local meanReversion = (good.basePrice - currentPrice) / good.basePrice * 0.1

        local newPrice = currentPrice * (1 + change + meanReversion)
        newPrice = math.max(math.floor(good.basePrice * 0.5), math.floor(newPrice))  -- Min 50% of base
        newPrice = math.min(math.floor(good.basePrice * 2), newPrice)  -- Max 200% of base

        state.goodsPrices[good.id] = newPrice

        -- Update history
        table.insert(state.goodsHistory[good.id], newPrice)
        if #state.goodsHistory[good.id] > state.historyLength then
            table.remove(state.goodsHistory[good.id], 1)
        end

        -- Decay trend over time
        good.trend = (good.trend or 0) * 0.95
    end
end

function StockMarket.buy(stockId, amount)
    local price = state.stockPrices[stockId]
    local totalCost = math.floor(price * amount)

    if PlayerData.coins >= totalCost and state.marketOpen then
        PlayerData.coins = PlayerData.coins - totalCost
        state.portfolio[stockId] = (state.portfolio[stockId] or 0) + amount
        state.stats.totalTrades = state.stats.totalTrades + 1
        return true
    end
    return false
end

function StockMarket.sell(stockId, amount)
    local owned = state.portfolio[stockId] or 0
    if owned >= amount and state.marketOpen then
        local price = state.stockPrices[stockId]
        local totalValue = math.floor(price * amount)

        PlayerData.coins = PlayerData.coins + totalValue
        state.portfolio[stockId] = owned - amount
        state.stats.totalTrades = state.stats.totalTrades + 1
        return true
    end
    return false
end

-- Buy physical goods (goes to backpack)
function StockMarket.buyPhysicalGood(goodId, amount)
    local price = state.goodsPrices[goodId]
    local totalCost = math.floor(price * amount)

    if PlayerData.coins >= totalCost and state.marketOpen then
        PlayerData.coins = PlayerData.coins - totalCost

        -- Add to backpack
        if Backpack and Backpack.addItem then
            Backpack.addItem(goodId, amount)
        end

        state.stats.totalTrades = state.stats.totalTrades + 1
        return true
    end
    return false
end

-- Sell physical goods (from backpack)
function StockMarket.sellPhysicalGood(goodId, amount)
    -- Check if player has the item in backpack
    if not Backpack or not Backpack.hasItem or not Backpack.hasItem(goodId, amount) then
        return false
    end

    if state.marketOpen then
        local price = state.goodsPrices[goodId]
        local totalValue = math.floor(price * 0.8 * amount)  -- Sell at 80% of buy price

        -- Remove from backpack
        Backpack.removeItem(goodId, amount)
        PlayerData.coins = PlayerData.coins + totalValue

        state.stats.totalTrades = state.stats.totalTrades + 1
        state.totalEarnings = state.totalEarnings + totalValue
        return true
    end
    return false
end

function StockMarket.getPortfolioValue()
    local value = 0
    for stockId, quantity in pairs(state.portfolio) do
        value = value + (state.stockPrices[stockId] or 0) * quantity
    end
    return value
end

-- Calculate and update the global passive income rate from stock market employees
function StockMarket.updatePassiveIncomeRate()
    local effects = UpgradeSystem.getCombinedEffects("stock_market", state.upgradeLevels)
    local totalRate = 0

    -- Calculate income from all hired employees
    for _, emp in ipairs(state.employees) do
        if emp.isHired and not emp.isDead then
            local efficiency = Employees.getEfficiency(emp)
            -- Base rate: efficiency * 0.15 gold per second
            local empRate = efficiency * 0.15
            -- Apply insight bonus from upgrades
            empRate = empRate * (1 + (effects.insightBonus or 0))
            totalRate = totalRate + empRate
        end
    end

    -- Use global helper to update passive income
    updatePassiveIncomeSource("stockMarket", totalRate)
end

function StockMarket.update(dt)
    if state.paused then return end

    -- Get upgrade effects
    local effects = UpgradeSystem.getCombinedEffects("stock_market", state.upgradeLevels)

    -- Apply tick speed bonus from upgrades
    local tickMult = 1 + (effects.tickSpeedBonus or 0)
    state.timer = state.timer + dt * state.speed * tickMult

    if state.timer >= state.tickRate then
        state.timer = 0

        -- Advance time
        state.hour = state.hour + 1

        if state.hour > 16 then
            -- Market closes
            state.hour = 9
            state.day = state.day + 1
            state.marketOpen = true

            -- Pay employees at end of day
            for _, emp in ipairs(state.employees) do
                if emp.isHired then
                    local success, wage = Employees.payWage(emp, PlayerData.coins)
                    if success then
                        PlayerData.coins = PlayerData.coins - wage
                    end
                end
            end

            -- Generate news at start of day
            if math.random() < 0.7 then
                StockMarket.generateNews()
            end
            if math.random() < 0.7 then
                StockMarket.generateGoodsNews()
            end

            -- Update player level based on total earnings
            state.playerLevel = math.floor(state.totalEarnings / 1000) + 1
        end

        -- Update prices during market hours
        if state.hour >= 9 and state.hour <= 16 then
            state.marketOpen = true
            StockMarket.updatePrices()
        else
            state.marketOpen = false
        end

        -- Random news during the day
        state.newsTimer = state.newsTimer + 1
        if state.newsTimer >= 10 and math.random() < 0.3 then
            state.newsTimer = 0
            StockMarket.generateNews()
        end
        state.goodsNewsTimer = (state.goodsNewsTimer or 0) + 1
        if state.goodsNewsTimer >= 10 and math.random() < 0.3 then
            state.goodsNewsTimer = 0
            StockMarket.generateGoodsNews()
        end
    end

    -- Note: Employee passive income is now handled globally via PlayerData.passiveIncome
    -- This allows income to accumulate even when not in stock market mode

    -- Update UI components
    UI.anim.update(dt)
    if uiComponents.mainTabs then
        uiComponents.mainTabs.activeTab = state.tab
        uiComponents.mainTabs:update(dt)
    end
    if uiComponents.tradingSubTabs then
        uiComponents.tradingSubTabs.activeTab = state.tradingSubTab
        uiComponents.tradingSubTabs:update(dt)
    end
    for i = 1, 3 do
        if uiComponents.speedButtons[i] then
            uiComponents.speedButtons[i]:update(dt)
        end
    end
    if uiComponents.pauseButton then
        uiComponents.pauseButton:update(dt)
    end
    if uiComponents.backButton then
        uiComponents.backButton:update(dt)
    end

    -- Check if upgrade is complete
    if state.currentBuild and UpgradeSystem.isComplete(state.currentBuild) then
        state.upgradeLevels[state.currentBuild.upgradeId] = state.currentBuild.targetLevel
        state.currentBuild = nil
        -- Recalculate passive income (upgrade bonuses may have changed)
        StockMarket.updatePassiveIncomeRate()
    end
end

function StockMarket.draw()
    local screenW, screenH = love.graphics.getDimensions()
    buttons = {}

    -- Background
    love.graphics.setColor(0.08, 0.1, 0.12)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Header
    love.graphics.setColor(0.12, 0.15, 0.18)
    love.graphics.rectangle("fill", 0, 0, screenW, 60)

    -- Title
    love.graphics.setColor(0.2, 0.8, 0.4)
    love.graphics.setFont(UI.fonts.get(28))
    love.graphics.print("STOCK MARKET", 20, 12)

    -- Level indicator
    love.graphics.setColor(0.8, 0.7, 0.3)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.print("Level " .. state.playerLevel, 180, 8)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.print("Earnings: $" .. math.floor(state.totalEarnings), 180, 24)

    -- Passive income indicator
    local passiveRate = PlayerData.passiveIncomeBreakdown and PlayerData.passiveIncomeBreakdown.stockMarket or 0
    if passiveRate > 0 then
        love.graphics.setColor(0.3, 0.9, 0.4)
        love.graphics.setFont(UI.fonts.get(11))
        love.graphics.print(string.format("+$%.2f/s passive", passiveRate), 180, 40)
    end

    -- Day/Time
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.setFont(UI.fonts.get(16))
    local timeStr = string.format("Day %d | %02d:00", state.day, state.hour)
    love.graphics.print(timeStr, 200, 20)

    -- Market status
    if state.marketOpen then
        love.graphics.setColor(0.2, 0.9, 0.3)
        love.graphics.print("MARKET OPEN", 350, 20)
    else
        love.graphics.setColor(0.9, 0.3, 0.3)
        love.graphics.print("MARKET CLOSED", 350, 20)
    end

    -- Cash and portfolio value with icons
    local coinIcon = UIAssets.getIconByName("gold_coin")
    if coinIcon then
        love.graphics.setColor(1, 1, 1)
        local imgW, imgH = coinIcon:getDimensions()
        local iconSize = 18
        local scale = iconSize / math.max(imgW, imgH)
        love.graphics.draw(coinIcon, screenW - 352, 10, 0, scale, scale)
    end
    love.graphics.setColor(0.3, 0.9, 0.4)
    love.graphics.setFont(UI.fonts.get(18))
    love.graphics.print(string.format("$%.2f", PlayerData.coins), screenW - 328, 10)

    local portfolioValue = StockMarket.getPortfolioValue()
    local bagIcon = UIAssets.getIconByName("bag_of_gold")
    if bagIcon then
        love.graphics.setColor(1, 1, 1)
        local imgW, imgH = bagIcon:getDimensions()
        local iconSize = 18
        local scale = iconSize / math.max(imgW, imgH)
        love.graphics.draw(bagIcon, screenW - 352, 32, 0, scale, scale)
    end
    love.graphics.setColor(0.4, 0.7, 1.0)
    love.graphics.print(string.format("$%.2f", portfolioValue), screenW - 328, 32)

    love.graphics.setColor(1, 0.9, 0.3)
    love.graphics.print(string.format("Total: $%.2f", PlayerData.coins + portfolioValue), screenW - 150, 20)

    -- Speed controls label
    local speedX = 500
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.print("Speed:", speedX, 22)

    -- Draw speed buttons using UI components
    for i = 1, 3 do
        if uiComponents.speedButtons[i] then
            uiComponents.speedButtons[i]:draw()
        end
    end

    -- Draw pause button using UI component
    if uiComponents.pauseButton then
        uiComponents.pauseButton:draw()
    end

    -- Draw main tabs using UI component
    if uiComponents.mainTabs then
        uiComponents.mainTabs:draw()
    end

    -- Draw based on current tab
    if state.tab == "trading" then
        drawTradingTab(screenW, screenH)
    elseif state.tab == "employees" then
        drawEmployeesTab(screenW, screenH)
    elseif state.tab == "upgrades" then
        drawUpgradesTab(screenW, screenH)
    end

    -- Draw back button using UI component
    if uiComponents.backButton then
        uiComponents.backButton.y = screenH - 50
        uiComponents.backButton:draw()
    end
end

function drawTradingTab(screenW, screenH)
    -- Draw trading sub-tabs using UI component
    if uiComponents.tradingSubTabs then
        uiComponents.tradingSubTabs:draw()
    end

    -- Draw appropriate content based on sub-tab
    if state.tradingSubTab == "stocks" then
        drawStocksTab(screenW, screenH)
    else
        drawPhysicalGoodsTab(screenW, screenH)
    end
end

function drawStocksTab(screenW, screenH)
    -- Stock list
    local listX = 20
    local listY = 100
    local listW = 350
    local itemH = 50

    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.print("STOCKS", listX, listY - 20)

    for i, stock in ipairs(stocks) do
        local y = listY + (i - 1) * (itemH + 5)
        local price = state.stockPrices[stock.id]
        local owned = state.portfolio[stock.id] or 0
        local history = state.priceHistory[stock.id]
        local prevPrice = history[#history - 1] or price
        local change = (price - prevPrice) / prevPrice * 100

        -- Background
        local isSelected = state.selectedStock == stock.id
        if isSelected then
            love.graphics.setColor(0.2, 0.25, 0.3)
        else
            love.graphics.setColor(0.12, 0.14, 0.18)
        end
        love.graphics.rectangle("fill", listX, y, listW, itemH, 6, 6)

        -- Stock color indicator
        love.graphics.setColor(stock.color)
        love.graphics.rectangle("fill", listX, y, 5, itemH, 3, 0, 0, 3)

        -- Item image
        local itemImg = itemImages[stock.id]
        local textOffset = 15
        if itemImg then
            love.graphics.setColor(1, 1, 1)
            local imgW, imgH = itemImg:getDimensions()
            local imgSize = 36
            local scale = imgSize / math.max(imgW, imgH)
            love.graphics.draw(itemImg, listX + 12, y + 6, 0, scale, scale)
            textOffset = 55
        end

        -- Stock name and ticker
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.fonts.get(14))
        love.graphics.print(stock.id, listX + textOffset, y + 5)

        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.setFont(UI.fonts.get(11))
        love.graphics.print(stock.name, listX + textOffset, y + 22)

        -- Price
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.fonts.get(16))
        love.graphics.printf(string.format("$%.2f", price), listX + 120, y + 8, 80, "right")

        -- Change
        if change >= 0 then
            love.graphics.setColor(0.2, 0.9, 0.3)
            love.graphics.printf(string.format("+%.2f%%", change), listX + 200, y + 28, 60, "right")
        else
            love.graphics.setColor(0.9, 0.3, 0.3)
            love.graphics.printf(string.format("%.2f%%", change), listX + 200, y + 28, 60, "right")
        end

        -- Owned
        if owned > 0 then
            love.graphics.setColor(0.4, 0.7, 1.0)
            love.graphics.setFont(UI.fonts.get(12))
            love.graphics.printf("Own: " .. owned, listX + 270, y + 15, 70, "right")
        end

        -- Mini chart
        local chartX = listX + listW - 60
        local chartY = y + 10
        local chartW = 50
        local chartH = 30

        if #history > 1 then
            local minP, maxP = history[1], history[1]
            for _, p in ipairs(history) do
                minP = math.min(minP, p)
                maxP = math.max(maxP, p)
            end
            local range = maxP - minP
            if range < 0.01 then range = 0.01 end

            love.graphics.setColor(stock.color[1], stock.color[2], stock.color[3], 0.5)
            for j = 2, #history do
                local x1 = chartX + (j - 2) / (#history - 1) * chartW
                local x2 = chartX + (j - 1) / (#history - 1) * chartW
                local y1 = chartY + chartH - ((history[j - 1] - minP) / range) * chartH
                local y2 = chartY + chartH - ((history[j] - minP) / range) * chartH
                love.graphics.line(x1, y1, x2, y2)
            end
        end

        buttons["stock_" .. stock.id] = {x = listX, y = y, w = listW, h = itemH, stockId = stock.id}
    end

    -- Selected stock details and trading
    if state.selectedStock then
        drawTradingPanel(screenW, screenH)
    end

    -- News panel
    drawNewsPanel(screenW, screenH)
end

function drawPhysicalGoodsTab(screenW, screenH)
    -- Identical layout to drawStocksTab: vertical list on left, detail panel + news on right
    local listX = 20
    local listY = 100
    local listW = 350
    local itemH = 50
    local maxVisible = 8
    local scroll = state.goodsScroll or 0

    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.print("PHYSICAL GOODS", listX, listY - 20)

    -- Scroll indicator
    if #PHYSICAL_GOODS > maxVisible then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.setFont(UI.fonts.get(10))
        love.graphics.printf(string.format("%d-%d of %d", scroll + 1, math.min(scroll + maxVisible, #PHYSICAL_GOODS), #PHYSICAL_GOODS), listX + 150, listY - 18, 200, "left")
    end

    -- Clip to list area
    local visibleCount = 0
    for i = scroll + 1, math.min(scroll + maxVisible, #PHYSICAL_GOODS) do
        local good = PHYSICAL_GOODS[i]
        local y = listY + visibleCount * (itemH + 5)
        visibleCount = visibleCount + 1

        local price = state.goodsPrices[good.id]
        local history = state.goodsHistory[good.id]
        local prevPrice = history and history[#history - 1] or price
        local change = prevPrice and prevPrice > 0 and ((price - prevPrice) / prevPrice * 100) or 0

        local owned = 0
        if Backpack and Backpack.getItemCount then
            owned = Backpack.getItemCount(good.id)
        end

        -- Background
        local isSelected = state.selectedGood == good.id
        if isSelected then
            love.graphics.setColor(0.2, 0.25, 0.3)
        else
            love.graphics.setColor(0.12, 0.14, 0.18)
        end
        love.graphics.rectangle("fill", listX, y, listW, itemH, 6, 6)

        -- Color indicator
        if good.color then
            love.graphics.setColor(good.color)
            love.graphics.rectangle("fill", listX, y, 5, itemH, 3, 0, 0, 3)
        end

        -- Item image
        local itemImg = itemImages[good.id]
        if not itemImg and Backpack and Backpack.getItemImage then
            itemImg = Backpack.getItemImage(good.id)
        end
        local textOffset = 15
        if itemImg then
            love.graphics.setColor(1, 1, 1)
            local imgW, imgH = itemImg:getDimensions()
            local imgSize = 36
            local scale = imgSize / math.max(imgW, imgH)
            love.graphics.draw(itemImg, listX + 12, y + 6, 0, scale, scale)
            textOffset = 55
        end

        -- Ticker and name
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.fonts.get(14))
        love.graphics.print(good.ticker or good.id, listX + textOffset, y + 5)

        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.setFont(UI.fonts.get(11))
        love.graphics.print(good.name, listX + textOffset, y + 22)

        -- Price
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.fonts.get(16))
        love.graphics.printf(string.format("$%d", price), listX + 120, y + 8, 80, "right")

        -- Change %
        if change >= 0 then
            love.graphics.setColor(0.2, 0.9, 0.3)
            love.graphics.printf(string.format("+%.1f%%", change), listX + 200, y + 28, 60, "right")
        else
            love.graphics.setColor(0.9, 0.3, 0.3)
            love.graphics.printf(string.format("%.1f%%", change), listX + 200, y + 28, 60, "right")
        end

        -- Owned
        if owned > 0 then
            love.graphics.setColor(0.4, 0.7, 1.0)
            love.graphics.setFont(UI.fonts.get(12))
            love.graphics.printf("Own: " .. owned, listX + 270, y + 15, 70, "right")
        end

        -- Mini chart
        local chartX = listX + listW - 60
        local chartY = y + 10
        local chartW = 50
        local chartH = 30

        if history and #history > 1 then
            local minP, maxP = history[1], history[1]
            for _, p in ipairs(history) do
                minP = math.min(minP, p)
                maxP = math.max(maxP, p)
            end
            local range = maxP - minP
            if range < 0.01 then range = 0.01 end

            local c = good.color or {0.5, 0.5, 0.5}
            love.graphics.setColor(c[1], c[2], c[3], 0.5)
            for j = 2, #history do
                local x1 = chartX + (j - 2) / (#history - 1) * chartW
                local x2 = chartX + (j - 1) / (#history - 1) * chartW
                local y1 = chartY + chartH - ((history[j - 1] - minP) / range) * chartH
                local y2 = chartY + chartH - ((history[j] - minP) / range) * chartH
                love.graphics.line(x1, y1, x2, y2)
            end
        end

        buttons["good_" .. good.id] = {x = listX, y = y, w = listW, h = itemH, goodId = good.id}
    end

    -- Store list bounds for scroll detection
    buttons["goods_list_area"] = {x = listX, y = listY, w = listW, h = maxVisible * (itemH + 5)}

    -- Selected good details and trading
    if state.selectedGood then
        drawGoodsTradingPanel(screenW, screenH)
    end

    -- Goods news panel
    drawGoodsNewsPanel(screenW, screenH)
end

function drawGoodsTradingPanel(screenW, screenH)
    local panelX = 400
    local panelY = 80
    local panelW = screenW - panelX - 20
    local panelH = 300

    love.graphics.setColor(0.12, 0.14, 0.18)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)

    -- Find selected good
    local good = nil
    for _, g in ipairs(PHYSICAL_GOODS) do
        if g.id == state.selectedGood then
            good = g
            break
        end
    end

    if not good then return end

    local price = state.goodsPrices[good.id]
    local owned = 0
    if Backpack and Backpack.getItemCount then
        owned = Backpack.getItemCount(good.id)
    end

    -- Header with item image
    local headerOffset = 20
    local itemImg = itemImages[good.id]
    if not itemImg and Backpack and Backpack.getItemImage then
        itemImg = Backpack.getItemImage(good.id)
    end
    if itemImg then
        love.graphics.setColor(1, 1, 1)
        local imgW, imgH = itemImg:getDimensions()
        local imgSize = 50
        local scale = imgSize / math.max(imgW, imgH)
        love.graphics.draw(itemImg, panelX + 20, panelY + 15, 0, scale, scale)
        headerOffset = 80
    end

    local c = good.color or {0.7, 0.7, 0.7}
    love.graphics.setColor(c)
    love.graphics.setFont(UI.fonts.get(24))
    love.graphics.print(good.name .. " (" .. (good.ticker or good.id) .. ")", panelX + headerOffset, panelY + 15)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(28))
    love.graphics.print(string.format("$%d", price), panelX + headerOffset, panelY + 50)

    -- Large chart
    local chartX = panelX + 20
    local chartY = panelY + 100
    local chartW = panelW - 40
    local chartH = 120

    love.graphics.setColor(0.08, 0.1, 0.12)
    love.graphics.rectangle("fill", chartX, chartY, chartW, chartH, 5, 5)

    local history = state.goodsHistory[good.id]
    if history and #history > 1 then
        local minP, maxP = history[1], history[1]
        for _, p in ipairs(history) do
            minP = math.min(minP, p)
            maxP = math.max(maxP, p)
        end
        local range = maxP - minP
        if range < 0.01 then range = 0.01 end

        -- Grid lines
        love.graphics.setColor(0.2, 0.2, 0.25)
        for gi = 0, 4 do
            local gy = chartY + (gi / 4) * chartH
            love.graphics.line(chartX, gy, chartX + chartW, gy)
        end

        -- Price line
        love.graphics.setColor(c)
        love.graphics.setLineWidth(2)
        for j = 2, #history do
            local x1 = chartX + (j - 2) / (#history - 1) * chartW
            local x2 = chartX + (j - 1) / (#history - 1) * chartW
            local y1 = chartY + chartH - ((history[j - 1] - minP) / range) * chartH
            local y2 = chartY + chartH - ((history[j] - minP) / range) * chartH
            love.graphics.line(x1, y1, x2, y2)
        end
        love.graphics.setLineWidth(1)

        -- Price labels
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.setFont(UI.fonts.get(10))
        love.graphics.printf(string.format("$%d", maxP), chartX + chartW + 5, chartY, 40, "left")
        love.graphics.printf(string.format("$%d", minP), chartX + chartW + 5, chartY + chartH - 10, 40, "left")
    end

    -- Trading controls
    local ctrlY = panelY + panelH - 70

    -- Buy amount control
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.print("Amount: " .. state.goodsBuyAmount, panelX + 20, ctrlY)

    -- Amount buttons
    local amounts = {1, 5, 10, 50, 100}
    for ai, amt in ipairs(amounts) do
        local btnX = panelX + 100 + (ai - 1) * 45
        local btnY = ctrlY - 5
        local btnW, btnH = 40, 25

        if state.goodsBuyAmount == amt then
            love.graphics.setColor(0.3, 0.5, 0.7)
        else
            love.graphics.setColor(0.25, 0.28, 0.32)
        end
        love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 4, 4)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.fonts.get(12))
        love.graphics.printf(tostring(amt), btnX, btnY + 5, btnW, "center")

        buttons["goods_amount_" .. amt] = {x = btnX, y = btnY, w = btnW, h = btnH, amount = amt}
    end

    -- Buy/Sell buttons
    local btnW, btnH = 100, 40
    local buyX = panelX + 20
    local sellX = panelX + 130
    local btnY = ctrlY + 25

    local totalCost = price * state.goodsBuyAmount
    local canBuy = PlayerData.coins >= totalCost and state.marketOpen
    local canSell = owned >= state.goodsBuyAmount and state.marketOpen

    if canBuy then
        love.graphics.setColor(0.2, 0.7, 0.3)
    else
        love.graphics.setColor(0.3, 0.35, 0.35)
    end
    love.graphics.rectangle("fill", buyX, btnY, btnW, btnH, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(16))
    love.graphics.printf("BUY", buyX, btnY + 10, btnW, "center")
    buttons["buy_good"] = {x = buyX, y = btnY, w = btnW, h = btnH, canBuy = canBuy}

    if canSell then
        love.graphics.setColor(0.8, 0.3, 0.3)
    else
        love.graphics.setColor(0.35, 0.3, 0.3)
    end
    love.graphics.rectangle("fill", sellX, btnY, btnW, btnH, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("SELL", sellX, btnY + 10, btnW, "center")
    buttons["sell_good"] = {x = sellX, y = btnY, w = btnW, h = btnH, canSell = canSell}

    -- Cost/Value display
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.print(string.format("Cost: $%d", totalCost), sellX + btnW + 20, btnY + 2)
    love.graphics.print(string.format("You own: %d", owned), sellX + btnW + 20, btnY + 17)
    love.graphics.setColor(0.9, 0.6, 0.3)
    love.graphics.setFont(UI.fonts.get(10))
    love.graphics.print(string.format("Sell at 80%%: $%d", math.floor(price * 0.8 * state.goodsBuyAmount)), sellX + btnW + 20, btnY + 32)
end

function drawGoodsNewsPanel(screenW, screenH)
    local panelX = 400
    local panelY = 400
    local panelW = screenW - panelX - 20
    local panelH = screenH - panelY - 60

    love.graphics.setColor(0.12, 0.14, 0.18)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)

    love.graphics.setColor(0.9, 0.7, 0.3)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.print("GOODS MARKET NEWS", panelX + 15, panelY + 10)

    love.graphics.setFont(UI.fonts.get(12))
    for i, news in ipairs(state.goodsNews) do
        if i > 5 then break end
        local y = panelY + 35 + (i - 1) * 35

        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print(news.time, panelX + 15, y)

        if news.effect > 0 then
            love.graphics.setColor(0.3, 0.8, 0.4)
        else
            love.graphics.setColor(0.8, 0.4, 0.3)
        end
        love.graphics.print(news.text, panelX + 60, y)
    end
end

function drawTradingPanel(screenW, screenH)
    local panelX = 400
    local panelY = 80
    local panelW = screenW - panelX - 20
    local panelH = 300

    love.graphics.setColor(0.12, 0.14, 0.18)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)

    -- Find selected stock
    local stock = nil
    for _, s in ipairs(stocks) do
        if s.id == state.selectedStock then
            stock = s
            break
        end
    end

    if not stock then return end

    local price = state.stockPrices[stock.id]
    local owned = state.portfolio[stock.id] or 0

    -- Stock header with item image
    local headerOffset = 20
    local itemImg = itemImages[stock.id]
    if itemImg then
        love.graphics.setColor(1, 1, 1)
        local imgW, imgH = itemImg:getDimensions()
        local imgSize = 50
        local scale = imgSize / math.max(imgW, imgH)
        love.graphics.draw(itemImg, panelX + 20, panelY + 15, 0, scale, scale)
        headerOffset = 80
    end

    love.graphics.setColor(stock.color)
    love.graphics.setFont(UI.fonts.get(24))
    love.graphics.print(stock.name .. " (" .. stock.id .. ")", panelX + headerOffset, panelY + 15)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(28))
    love.graphics.print(string.format("$%.2f", price), panelX + headerOffset, panelY + 50)

    -- Large chart
    local chartX = panelX + 20
    local chartY = panelY + 100
    local chartW = panelW - 40
    local chartH = 120

    love.graphics.setColor(0.08, 0.1, 0.12)
    love.graphics.rectangle("fill", chartX, chartY, chartW, chartH, 5, 5)

    local history = state.priceHistory[stock.id]
    if #history > 1 then
        local minP, maxP = history[1], history[1]
        for _, p in ipairs(history) do
            minP = math.min(minP, p)
            maxP = math.max(maxP, p)
        end
        local range = maxP - minP
        if range < 0.01 then range = 0.01 end

        -- Grid lines
        love.graphics.setColor(0.2, 0.2, 0.25)
        for i = 0, 4 do
            local gy = chartY + (i / 4) * chartH
            love.graphics.line(chartX, gy, chartX + chartW, gy)
        end

        -- Price line
        love.graphics.setColor(stock.color)
        love.graphics.setLineWidth(2)
        for j = 2, #history do
            local x1 = chartX + (j - 2) / (#history - 1) * chartW
            local x2 = chartX + (j - 1) / (#history - 1) * chartW
            local y1 = chartY + chartH - ((history[j - 1] - minP) / range) * chartH
            local y2 = chartY + chartH - ((history[j] - minP) / range) * chartH
            love.graphics.line(x1, y1, x2, y2)
        end
        love.graphics.setLineWidth(1)

        -- Price labels
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.setFont(UI.fonts.get(10))
        love.graphics.printf(string.format("$%.0f", maxP), chartX + chartW + 5, chartY, 40, "left")
        love.graphics.printf(string.format("$%.0f", minP), chartX + chartW + 5, chartY + chartH - 10, 40, "left")
    end

    -- Trading controls
    local ctrlY = panelY + panelH - 70

    -- Buy amount control
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.print("Amount: " .. state.buyAmount, panelX + 20, ctrlY)

    -- Amount buttons
    local amounts = {1, 5, 10, 50, 100}
    for i, amt in ipairs(amounts) do
        local btnX = panelX + 100 + (i - 1) * 45
        local btnY = ctrlY - 5
        local btnW, btnH = 40, 25

        if state.buyAmount == amt then
            love.graphics.setColor(0.3, 0.5, 0.7)
        else
            love.graphics.setColor(0.25, 0.28, 0.32)
        end
        love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 4, 4)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.fonts.get(12))
        love.graphics.printf(tostring(amt), btnX, btnY + 5, btnW, "center")

        buttons["amount_" .. amt] = {x = btnX, y = btnY, w = btnW, h = btnH, amount = amt}
    end

    -- Buy/Sell buttons
    local btnW, btnH = 100, 40
    local buyX = panelX + 20
    local sellX = panelX + 130
    local btnY = ctrlY + 25

    local canBuy = PlayerData.coins >= price * state.buyAmount and state.marketOpen
    local canSell = owned >= state.buyAmount and state.marketOpen

    if canBuy then
        love.graphics.setColor(0.2, 0.7, 0.3)
    else
        love.graphics.setColor(0.3, 0.35, 0.35)
    end
    love.graphics.rectangle("fill", buyX, btnY, btnW, btnH, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(16))
    love.graphics.printf("BUY", buyX, btnY + 10, btnW, "center")
    buttons["buy"] = {x = buyX, y = btnY, w = btnW, h = btnH, canBuy = canBuy}

    if canSell then
        love.graphics.setColor(0.8, 0.3, 0.3)
    else
        love.graphics.setColor(0.35, 0.3, 0.3)
    end
    love.graphics.rectangle("fill", sellX, btnY, btnW, btnH, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("SELL", sellX, btnY + 10, btnW, "center")
    buttons["sell"] = {x = sellX, y = btnY, w = btnW, h = btnH, canSell = canSell}

    -- Cost/Value display
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.print(string.format("Cost: $%.2f", price * state.buyAmount), sellX + btnW + 20, btnY + 5)
    love.graphics.print(string.format("You own: %d", owned), sellX + btnW + 20, btnY + 22)
end

function drawNewsPanel(screenW, screenH)
    local panelX = 400
    local panelY = 400
    local panelW = screenW - panelX - 20
    local panelH = screenH - panelY - 60

    love.graphics.setColor(0.12, 0.14, 0.18)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)

    love.graphics.setColor(0.9, 0.8, 0.3)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.print("MARKET NEWS", panelX + 15, panelY + 10)

    love.graphics.setFont(UI.fonts.get(12))
    for i, news in ipairs(state.news) do
        local y = panelY + 35 + (i - 1) * 35

        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.print(news.time, panelX + 15, y)

        if news.effect > 0 then
            love.graphics.setColor(0.3, 0.8, 0.4)
        else
            love.graphics.setColor(0.8, 0.4, 0.3)
        end
        love.graphics.print(news.text, panelX + 60, y)
    end
end

function drawEmployeesTab(screenW, screenH)
    local mx, my = love.mouse.getPosition()
    local contentY = 100

    -- Hired employees section
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.setFont(UI.fonts.get(16))
    love.graphics.print("Hired Traders (" .. #state.employees .. ")", 30, contentY)

    local empY = contentY + 30
    local effects = UpgradeSystem.getCombinedEffects("stock_market", state.upgradeLevels)
    local maxEmployees = effects.maxEmployees or 1

    if #state.employees == 0 then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.setFont(UI.fonts.get(12))
        love.graphics.print("No traders hired yet. Hire from the pool below!", 30, empY)
        empY = empY + 30
    else
        for i, emp in ipairs(state.employees) do
            local cardH = 80
            local isHovered = mx >= 30 and mx <= 380 and my >= empY and my <= empY + cardH
            Employees.drawEmployeeCard(emp, 30, empY, 350, cardH, isHovered, false)

            -- Fire button
            local fireX = 390
            love.graphics.setColor(0.6, 0.25, 0.25)
            love.graphics.rectangle("fill", fireX, empY + 25, 60, 28, 4, 4)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(UI.fonts.get(11))
            love.graphics.printf("Fire", fireX, empY + 31, 60, "center")
            buttons["fire_" .. i] = {x = fireX, y = empY + 25, w = 60, h = 28, index = i}

            empY = empY + cardH + 10
        end
    end

    -- Hiring pool section
    local poolY = math.max(empY + 30, 350)
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.setFont(UI.fonts.get(16))
    love.graphics.print("Available for Hire (Max: " .. maxEmployees .. ")", 30, poolY)

    -- Refresh pool button
    local refreshX = 280
    love.graphics.setColor(0.3, 0.5, 0.6)
    love.graphics.rectangle("fill", refreshX, poolY - 2, 80, 24, 4, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(11))
    love.graphics.printf("Refresh", refreshX, poolY + 2, 80, "center")
    buttons["refresh_pool"] = {x = refreshX, y = poolY - 2, w = 80, h = 24}

    local hireY = poolY + 30
    if #state.hiringPool == 0 then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.setFont(UI.fonts.get(12))
        love.graphics.print("No candidates available. Click Refresh to find new traders.", 30, hireY)
    else
        for i, emp in ipairs(state.hiringPool) do
            local cardH = 100
            local isHovered = mx >= 30 and mx <= 380 and my >= hireY and my <= hireY + cardH
            Employees.drawEmployeeCard(emp, 30, hireY, 350, cardH, isHovered, true)

            -- Hire button
            local empType = Employees.getType(emp.employeeType)
            local canAfford = PlayerData.coins >= (empType and empType.baseCost or 0)
            local canHire = #state.employees < maxEmployees and canAfford

            local hireX = 390
            if canHire then
                love.graphics.setColor(0.25, 0.55, 0.3)
            else
                love.graphics.setColor(0.3, 0.3, 0.3)
            end
            love.graphics.rectangle("fill", hireX, hireY + 35, 70, 30, 4, 4)
            love.graphics.setColor(canHire and {1, 1, 1} or {0.5, 0.5, 0.5})
            love.graphics.setFont(UI.fonts.get(12))
            love.graphics.printf("Hire", hireX, hireY + 42, 70, "center")
            buttons["hire_" .. i] = {x = hireX, y = hireY + 35, w = 70, h = 30, index = i, canHire = canHire}

            hireY = hireY + cardH + 10
        end
    end

    -- Stats panel on right
    local statsX = 500
    local statsY = 100
    love.graphics.setColor(0.12, 0.14, 0.18)
    love.graphics.rectangle("fill", statsX, statsY, screenW - statsX - 20, 200, 8, 8)

    love.graphics.setColor(0.9, 0.8, 0.3)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.print("TRADER STATS", statsX + 15, statsY + 10)

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.print("Hired Traders: " .. #state.employees .. " / " .. maxEmployees, statsX + 15, statsY + 40)

    local totalEff = 0
    local totalWages = 0
    for _, emp in ipairs(state.employees) do
        totalEff = totalEff + Employees.getEfficiency(emp)
        totalWages = totalWages + Employees.getDailyWage(emp)
    end
    love.graphics.print("Total Efficiency: " .. string.format("%.0f%%", totalEff * 100), statsX + 15, statsY + 60)
    love.graphics.print("Daily Wages: $" .. totalWages, statsX + 15, statsY + 80)

    love.graphics.setColor(0.5, 0.8, 0.5)
    love.graphics.print("Insight Bonus: +" .. string.format("%.0f%%", (effects.insightBonus or 0) * 100), statsX + 15, statsY + 110)

    -- Show passive income rate
    local passiveRate = PlayerData.passiveIncomeBreakdown and PlayerData.passiveIncomeBreakdown.stockMarket or 0
    love.graphics.setColor(1, 0.9, 0.3)
    love.graphics.setFont(UI.fonts.get(13))
    love.graphics.print("PASSIVE INCOME", statsX + 15, statsY + 140)
    love.graphics.setColor(0.3, 0.9, 0.4)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.print(string.format("$%.2f / second", passiveRate), statsX + 15, statsY + 158)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.setFont(UI.fonts.get(10))
    love.graphics.print("(Earns even when offline!)", statsX + 15, statsY + 176)
end

function drawUpgradesTab(screenW, screenH)
    local mx, my = love.mouse.getPosition()
    local contentY = 100

    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.setFont(UI.fonts.get(16))
    love.graphics.print("Trading Floor Upgrades", 30, contentY)

    love.graphics.setColor(1, 0.9, 0.4)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.print("Cash: $" .. string.format("%.0f", PlayerData.coins), 300, contentY)

    local upgrades = UpgradeSystem.getUpgrades("stock_market")
    local upgradeY = contentY + 40
    local upgradeW = 400

    for i, upgrade in ipairs(upgrades) do
        local currentLevel = state.upgradeLevels[upgrade.id] or 0
        local isHovered = mx >= 30 and mx <= 30 + upgradeW and my >= upgradeY and my <= upgradeY + 100

        local cardH = UpgradeSystem.drawUpgradeCard("stock_market", upgrade.id, currentLevel, 30, upgradeY, upgradeW, isHovered, state.currentBuild)

        -- Upgrade button (if not maxed and not building)
        if currentLevel < upgrade.maxLevel and not state.currentBuild then
            local canAfford, reason = UpgradeSystem.canAfford("stock_market", upgrade.id, currentLevel, PlayerData.coins)

            local btnX = 30 + upgradeW + 15
            if canAfford then
                love.graphics.setColor(0.25, 0.55, 0.3)
            else
                love.graphics.setColor(0.3, 0.3, 0.3)
            end
            love.graphics.rectangle("fill", btnX, upgradeY + 30, 80, 35, 5, 5)
            love.graphics.setColor(canAfford and {1, 1, 1} or {0.5, 0.5, 0.5})
            love.graphics.setFont(UI.fonts.get(12))
            love.graphics.printf("Upgrade", btnX, upgradeY + 40, 80, "center")
            buttons["upgrade_" .. upgrade.id] = {x = btnX, y = upgradeY + 30, w = 80, h = 35, upgradeId = upgrade.id, canAfford = canAfford}
        end

        upgradeY = upgradeY + cardH + 15
    end

    -- Current effects panel
    local effectsX = 550
    local effectsY = 100
    love.graphics.setColor(0.12, 0.14, 0.18)
    love.graphics.rectangle("fill", effectsX, effectsY, screenW - effectsX - 20, 250, 8, 8)

    love.graphics.setColor(0.9, 0.8, 0.3)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.print("CURRENT BONUSES", effectsX + 15, effectsY + 10)

    local effects = UpgradeSystem.getCombinedEffects("stock_market", state.upgradeLevels)
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.setFont(UI.fonts.get(12))
    local effY = effectsY + 40
    love.graphics.print("Market Insight: +" .. string.format("%.0f%%", (effects.insightBonus or 0) * 100), effectsX + 15, effY)
    love.graphics.print("Trading Speed: +" .. string.format("%.0f%%", (effects.tickSpeedBonus or 0) * 100), effectsX + 15, effY + 22)
    love.graphics.print("Max Traders: " .. (effects.maxEmployees or 1), effectsX + 15, effY + 44)
    love.graphics.print("Dividend Rate: +" .. string.format("%.1f%%", (effects.dividendRate or 0) * 100), effectsX + 15, effY + 66)

    -- Building status
    if state.currentBuild then
        local remaining = UpgradeSystem.getRemainingTime(state.currentBuild)
        love.graphics.setColor(0.5, 0.8, 0.5)
        love.graphics.print("Building: " .. state.currentBuild.upgradeId, effectsX + 15, effY + 100)
        love.graphics.print("Time left: " .. remaining .. "s", effectsX + 15, effY + 120)
    end
end

function StockMarket.mousepressed(x, y, button)
    if button ~= 1 then return end

    -- Try UI components first
    if uiComponents.backButton and uiComponents.backButton:mousepressed(x, y, button) then
        return
    end

    if uiComponents.mainTabs and uiComponents.mainTabs:mousepressed(x, y, button) then
        return
    end

    if uiComponents.pauseButton and uiComponents.pauseButton:mousepressed(x, y, button) then
        return
    end

    for i = 1, 3 do
        if uiComponents.speedButtons[i] and uiComponents.speedButtons[i]:mousepressed(x, y, button) then
            return
        end
    end

    -- Trading tab interactions
    if state.tab == "trading" then
        -- Sub-tab buttons
        if uiComponents.tradingSubTabs and uiComponents.tradingSubTabs:mousepressed(x, y, button) then
            return
        end

        if state.tradingSubTab == "stocks" then
            -- Stock selection
            for _, stock in ipairs(stocks) do
                local btn = buttons["stock_" .. stock.id]
                if btn and isInside(x, y, btn) then
                    state.selectedStock = stock.id
                    return
                end
            end

            -- Amount buttons
            local amounts = {1, 5, 10, 50, 100}
            for _, amt in ipairs(amounts) do
                local btn = buttons["amount_" .. amt]
                if btn and isInside(x, y, btn) then
                    state.buyAmount = amt
                    return
                end
            end

            -- Buy button
            if buttons["buy"] and isInside(x, y, buttons["buy"]) and buttons["buy"].canBuy then
                StockMarket.buy(state.selectedStock, state.buyAmount)
                return
            end

            -- Sell button
            if buttons["sell"] and isInside(x, y, buttons["sell"]) and buttons["sell"].canSell then
                StockMarket.sell(state.selectedStock, state.buyAmount)
                return
            end
        elseif state.tradingSubTab == "goods" then
            -- Good selection from list
            for _, good in ipairs(PHYSICAL_GOODS) do
                local btn = buttons["good_" .. good.id]
                if btn and isInside(x, y, btn) then
                    state.selectedGood = good.id
                    return
                end
            end

            -- Amount buttons for goods
            local amounts = {1, 5, 10, 50, 100}
            for _, amt in ipairs(amounts) do
                local btn = buttons["goods_amount_" .. amt]
                if btn and isInside(x, y, btn) then
                    state.goodsBuyAmount = amt
                    return
                end
            end

            -- Buy button for selected good
            if buttons["buy_good"] and isInside(x, y, buttons["buy_good"]) and buttons["buy_good"].canBuy then
                StockMarket.buyPhysicalGood(state.selectedGood, state.goodsBuyAmount)
                return
            end

            -- Sell button for selected good
            if buttons["sell_good"] and isInside(x, y, buttons["sell_good"]) and buttons["sell_good"].canSell then
                StockMarket.sellPhysicalGood(state.selectedGood, state.goodsBuyAmount)
                return
            end
        end
    end

    -- Employees tab interactions
    if state.tab == "employees" then
        -- Refresh pool button
        if buttons["refresh_pool"] and isInside(x, y, buttons["refresh_pool"]) then
            state.hiringPool = Employees.generateHiringPool("stock_market", 3, state.playerLevel)
            return
        end

        -- Hire buttons
        for i = 1, #state.hiringPool do
            local btn = buttons["hire_" .. i]
            if btn and isInside(x, y, btn) and btn.canHire then
                local emp = state.hiringPool[i]
                local empType = Employees.getType(emp.employeeType)
                if empType and PlayerData.coins >= empType.baseCost then
                    PlayerData.coins = PlayerData.coins - empType.baseCost
                    emp.isHired = true
                    emp.hireDay = state.day
                    table.insert(state.employees, emp)
                    table.remove(state.hiringPool, i)
                    -- Update global passive income rate
                    StockMarket.updatePassiveIncomeRate()
                end
                return
            end
        end

        -- Fire buttons
        for i = 1, #state.employees do
            local btn = buttons["fire_" .. i]
            if btn and isInside(x, y, btn) then
                table.remove(state.employees, i)
                -- Update global passive income rate
                StockMarket.updatePassiveIncomeRate()
                return
            end
        end
    end

    -- Upgrades tab interactions
    if state.tab == "upgrades" then
        local upgrades = UpgradeSystem.getUpgrades("stock_market")
        for _, upgrade in ipairs(upgrades) do
            local btn = buttons["upgrade_" .. upgrade.id]
            if btn and isInside(x, y, btn) and btn.canAfford then
                local currentLevel = state.upgradeLevels[upgrade.id] or 0
                local buildInfo, reason = UpgradeSystem.startUpgrade("stock_market", upgrade.id, currentLevel, PlayerData.coins)
                if buildInfo then
                    -- Deduct gold (skip if already deducted by startUpgrade)
                    if not buildInfo.goldDeducted then
                        PlayerData.coins = PlayerData.coins - buildInfo.goldCost
                    end
                    state.currentBuild = buildInfo
                end
                return
            end
        end
    end
end

function StockMarket.mousereleased(x, y, button)
    if button ~= 1 then return end

    -- Route to UI components
    if uiComponents.backButton and uiComponents.backButton.mousereleased then
        uiComponents.backButton:mousereleased(x, y, button)
    end

    if uiComponents.mainTabs and uiComponents.mainTabs.mousereleased then
        uiComponents.mainTabs:mousereleased(x, y, button)
    end

    if uiComponents.tradingSubTabs and uiComponents.tradingSubTabs.mousereleased then
        uiComponents.tradingSubTabs:mousereleased(x, y, button)
    end

    if uiComponents.pauseButton and uiComponents.pauseButton.mousereleased then
        uiComponents.pauseButton:mousereleased(x, y, button)
    end

    for i = 1, 3 do
        if uiComponents.speedButtons[i] and uiComponents.speedButtons[i].mousereleased then
            uiComponents.speedButtons[i]:mousereleased(x, y, button)
        end
    end
end

function isInside(x, y, btn)
    return x >= btn.x and x <= btn.x + btn.w and
           y >= btn.y and y <= btn.y + btn.h
end

function StockMarket.wheelmoved(x, y)
    if state.tab == "trading" and state.tradingSubTab == "goods" then
        local mx, my = love.mouse.getPosition()
        local listArea = buttons["goods_list_area"]
        if listArea and mx >= listArea.x and mx <= listArea.x + listArea.w and my >= listArea.y and my <= listArea.y + listArea.h then
            state.goodsScroll = (state.goodsScroll or 0) - y
            state.goodsScroll = math.max(0, math.min(#PHYSICAL_GOODS - 8, state.goodsScroll))
        end
    end
end

function StockMarket.keypressed(key)
    if key == "escape" then
        -- Save portfolio state (keeps stocks)
        StockMarket.save()
        -- Update coins with just the cash (not selling stocks)
        PlayerData.coins = math.floor(PlayerData.coins)
        savePlayerData()
        local TextRPG = require("textrpg"); TextRPG.init(); GameState.current = "textrpg"
    elseif key == "space" then
        state.paused = not state.paused
    end
end

function StockMarket.getUIRegion(regionId)
    local screenW, screenH = love.graphics.getDimensions()
    local regions = {
        -- Stock list (left panel showing all stocks)
        stock_list = {x = 20, y = 100, w = 350, h = 440},
        -- Buy/sell trading panel (right side when stock selected)
        buy_panel = {x = 400, y = 80, w = screenW - 420, h = 300},
        -- Portfolio value display (top-right header area)
        portfolio = {x = screenW - 352, y = 10, w = 340, h = 50},
    }
    return regions[regionId]
end

return StockMarket
