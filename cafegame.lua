-- Tavern Game Mode - Work at the local tavern!
-- A 2D tavern game where you serve hungry adventurers

local CafeGame = {}
local UIAssets = require("uiassets")
local Progression = require("progression")
local InteractiveTutorial = require("interactivetutorial")
local UI = require("ui")

local DAYS_PER_YEAR = 365

-- Menu items available in the tavern (with icon names from UIAssets.iconRegistry)
local menuItems = {
    -- Drinks
    {id = "ale", name = "Ale", price = 4, prepTime = 0.5, icon = "wine_bottle", iconFallback = "A", color = {0.7, 0.5, 0.2}, category = "drink"},
    {id = "mead", name = "Honey Mead", price = 6, prepTime = 0.8, icon = "honey", iconFallback = "M", color = {0.9, 0.7, 0.3}, category = "drink"},
    {id = "wine", name = "Wine", price = 8, prepTime = 0.6, icon = "wine_glass", iconFallback = "W", color = {0.6, 0.1, 0.2}, category = "drink"},
    {id = "cider", name = "Apple Cider", price = 5, prepTime = 0.7, icon = "fruit_juice", iconFallback = "C", color = {0.8, 0.6, 0.2}, category = "drink"},
    -- Food
    {id = "stew", name = "Hearty Stew", price = 12, prepTime = 2.0, icon = "soup", iconFallback = "S", color = {0.6, 0.4, 0.2}, category = "food"},
    {id = "bread", name = "Fresh Bread", price = 3, prepTime = 0.5, icon = "bread", iconFallback = "B", color = {0.85, 0.7, 0.4}, category = "food"},
    {id = "roast", name = "Roast Chicken", price = 15, prepTime = 2.5, icon = "chicken_leg", iconFallback = "R", color = {0.7, 0.3, 0.2}, category = "food"},
    {id = "pie", name = "Meat Pie", price = 10, prepTime = 1.5, icon = "steak", iconFallback = "P", color = {0.8, 0.6, 0.3}, category = "food"},
    {id = "cheese", name = "Cheese Platter", price = 8, prepTime = 0.8, icon = "cheese", iconFallback = "H", color = {1.0, 0.9, 0.4}, category = "food"},
    {id = "fish", name = "Grilled Fish", price = 11, prepTime = 1.8, icon = "fish_fried", iconFallback = "F", color = {0.5, 0.6, 0.7}, category = "food"},
}

-- Customer types with different patience levels (tavern patrons)
-- Using new folder structure: Human/Men_Human, Human/Women_Human, ELF/Men_ELF, ELF/Women_Elf, ORC/Men_ORC, ORC/Women_ORC
local customerTypes = {
    {type = "peasant", patience = 35, tipMultiplier = 0.8, color = {0.6, 0.5, 0.4},
     malePortraits = {"Human/Men_Human/Human_10", "Human/Men_Human/Human_28_thug", "Human/Men_Human/Human_47_convict", "Human/Men_Human/Homeless"},
     femalePortraits = {"Human/Women_Human/Human_16_girl", "Human/Women_Human/Old_woman", "Human/Women_Human/Human_07_girl"}},
    {type = "merchant", patience = 20, tipMultiplier = 1.5, color = {0.5, 0.4, 0.6},
     malePortraits = {"Human/Men_Human/Merchant", "Human/Men_Human/Trader", "Human/Men_Human/Human_27_alchemyst"},
     femalePortraits = {"Human/Women_Human/Human_15_woman", "Human/Women_Human/Human_42_queen"}},
    {type = "adventurer", patience = 25, tipMultiplier = 1.3, color = {0.4, 0.6, 0.4},
     malePortraits = {"Human/Men_Human/Warrior", "Human/Men_Human/Human_25_barbarian", "Human/Men_Human/Human_33_warrior", "Human/Men_Human/Viking"},
     femalePortraits = {"Human/Women_Human/Human_50_amazon_warrior", "Human/Women_Human/Archer_woman", "Human/Women_Human/Human_05_woman_knight"}},
    {type = "knight", patience = 15, tipMultiplier = 2.0, color = {0.7, 0.7, 0.8},
     malePortraits = {"Human/Men_Human/Knight_Man", "Human/Men_Human/Knight2_Man", "Human/Men_Human/Human_04_knight", "Human/Men_Human/Human_14_knight"},
     femalePortraits = {"Human/Women_Human/Human_05_woman_knight", "Human/Women_Human/Archer_woman"}},
    {type = "noble", patience = 12, tipMultiplier = 2.5, color = {0.8, 0.6, 0.9},
     malePortraits = {"Human/Men_Human/Duke", "Human/Men_Human/Human_11_lord", "Human/Men_Human/Human_12_lord", "Human/Men_Human/Human_19_Jarl"},
     femalePortraits = {"Human/Women_Human/Human_42_queen", "Human/Women_Human/Human_43_queen"}},
    {type = "dwarf", patience = 40, tipMultiplier = 1.2, color = {0.7, 0.5, 0.3},
     malePortraits = {"Dwarves/Dwarf", "Dwarves/MadDwarf", "Gnomes/Male Gnomes/Gnome_02", "Gnomes/Male Gnomes/Gnome_05"},
     femalePortraits = {"Gnomes/Female Gnomes/Gnome_01", "Gnomes/Female Gnomes/Gnome_03", "Gnomes/Female Gnomes/Gnome_04"}},
    {type = "elf", patience = 30, tipMultiplier = 1.4, color = {0.4, 0.7, 0.5},
     malePortraits = {"ELF/Men_ELF/Elf_05", "ELF/Men_ELF/Elf_07", "ELF/Men_ELF/Elf_08", "ELF/Men_ELF/ElfWarrior"},
     femalePortraits = {"ELF/Women_Elf/Elf_01", "ELF/Women_Elf/Elf_02", "ELF/Women_Elf/Elf_03", "ELF/Women_Elf/Elf_09", "ELF/Women_Elf/ElfMage"}},
}

-- Customer names by gender
local customerMaleNames = {
    "Aldric", "Bram", "Cedric", "Dorian", "Edmund", "Finnian", "Garrett", "Henrik",
    "Ivan", "Jasper", "Kieran", "Lucian", "Magnus", "Nolan", "Osric", "Percival",
    "Theron", "Ulric", "Victor", "Willem", "Barric", "Conrad", "Grimm", "Jorik",
}

local customerFemaleNames = {
    "Agnes", "Beatrix", "Clara", "Delia", "Elara", "Freya", "Gwen", "Helena",
    "Ivy", "Juliana", "Kira", "Lydia", "Mira", "Nadia", "Ophelia", "Priscilla",
    "Rosalind", "Selene", "Thalia", "Una", "Violet", "Wren", "Sage", "Luna",
}

-- Season definitions
local SEASONS = {"Frosthollow", "Brightbloom", "Sunreign", "Ashwane"}
local MONTH_DATA = {
    {name = "Deepmere",    days = 31},
    {name = "Ironveil",    days = 28},
    {name = "Thawmist",    days = 31},
    {name = "Greenward",   days = 30},
    {name = "Starbloom",   days = 31},
    {name = "Solaren",     days = 30},
    {name = "Highsun",     days = 31},
    {name = "Forgefire",   days = 31},
    {name = "Harvestmere", days = 30},
    {name = "Glassfall",   days = 31},
    {name = "Shadowmere",  days = 30},
    {name = "Voidwatch",   days = 31},
}

-- Get season from month number
local function getSeason(day)
    local totalDays = day - 1
    totalDays = totalDays % DAYS_PER_YEAR
    local month = 1
    for i = 1, 12 do
        if totalDays < MONTH_DATA[i].days then
            month = i
            break
        end
        totalDays = totalDays - MONTH_DATA[i].days
    end
    if month >= 3 and month <= 5 then return "Brightbloom"
    elseif month >= 6 and month <= 8 then return "Sunreign"
    elseif month >= 9 and month <= 11 then return "Ashwane"
    else return "Frosthollow" end
end

-- Get month and day of month
local function getDateFromDay(day)
    local totalDays = day - 1
    totalDays = totalDays % DAYS_PER_YEAR
    local month = 1
    for i = 1, 12 do
        if totalDays < MONTH_DATA[i].days then
            month = i
            break
        end
        totalDays = totalDays - MONTH_DATA[i].days
    end
    return MONTH_DATA[month].name, totalDays + 1
end

-- Get time of day string
local function getTimeOfDay(progress)
    -- 0-100 represents 5PM to 2AM (9 hours)
    local hoursPassed = progress * 9 / 100
    local startHour = 17  -- 5PM
    local currentHour = startHour + math.floor(hoursPassed)
    local minutes = math.floor((hoursPassed % 1) * 60)

    if currentHour >= 24 then
        currentHour = currentHour - 24
    end

    local period = currentHour >= 12 and "PM" or "AM"
    local displayHour = currentHour > 12 and currentHour - 12 or (currentHour == 0 and 12 or currentHour)

    return string.format("%d:%02d %s", displayHour, minutes, period)
end

-- Game state
local gameState = {
    money = 0,
    dayMoney = 0,
    day = 1,
    timeOfDay = 0,  -- 0-100, represents work shift
    dayLength = 120, -- seconds per day

    customers = {},  -- Active customers
    maxCustomers = 4,
    customerSpawnTimer = 0,
    customerSpawnRate = 5, -- seconds between spawns

    preparingItem = nil,
    preparingItems = {},  -- For multi-prep
    prepProgress = 0,

    servingTray = {},  -- Items ready to serve
    maxTrayItems = 3,

    totalServed = 0,
    customersLost = 0,
    perfectOrders = 0,

    dayOver = false,
    showDaySummary = false,
    showUpgrades = false,  -- Show upgrades shop

    autoMode = false,      -- Auto-chef mode
    autoTimer = 0,         -- Timer for auto prep

    upgrades = {
        traySize = 0,      -- +1 tray slot per level (max 3)
        prepSpeed = 0,     -- 20% faster prep per level (max 5)
        patience = 0,      -- +5 patience per level (max 5)
        tips = 0,          -- +15% tips per level (max 5)
        autoChef = 0,      -- Auto-chef level (max 3): 1=slow, 2=medium, 3=fast
        multiPrep = 0,     -- Prepare multiple items (max 2): 1=2 items, 2=3 items
        reputation = 0,    -- +10% more customers per level (max 5)
        quality = 0,       -- +10% order value per level (max 5)
        ambiance = 0,      -- +8% patience & tips per level (max 3)
    },

    -- Employees
    employees = {},        -- Hired employees
    employeeActions = {},  -- Current employee activities
    showEmployeeMenu = false,
    dailyWages = 0,        -- Total wages paid per day
    upgradeScroll = 0,     -- Scroll position for upgrades menu
    employeeScroll = 0,    -- Scroll position for employee menu

    -- Interactive mechanics (pouring/plating)
    activeMinigame = nil,  -- "pour" or "plate"
    minigameItem = nil,    -- Item being prepared
    minigameCustomer = nil, -- Customer ordering this item

    -- Pouring mechanic
    pourProgress = 0,      -- 0-100, fill level
    pouringActive = false, -- Is player holding pour button?
    selectedBottle = nil,  -- Which drink bottle selected
    pourQuality = "none",  -- "perfect", "good", "okay", "none"

    -- Plating mechanic
    platingStep = 0,       -- Current step in plating (0-2)
    plateProgress = 0,     -- Progress on current plating step
    platingQuality = "none", -- "perfect", "good", "okay", "none"
    platePerfectWindow = false, -- Is the perfect timing window active?
    platePerfectTimer = 0,      -- Timer for perfect window
}

-- Upgrade definitions (tavern improvements)
local upgradeDefinitions = {
    {id = "prepSpeed", name = "Quick Hands", desc = "+20% prep speed", maxLevel = 5, baseCost = 50, costMult = 1.5, icon = "H"},
    {id = "patience", name = "Cozy Tavern", desc = "+5 customer patience", maxLevel = 5, baseCost = 40, costMult = 1.4, icon = "T"},
    {id = "tips", name = "Silver Tongue", desc = "+15% tips", maxLevel = 5, baseCost = 60, costMult = 1.6, icon = "G"},
    {id = "traySize", name = "Bigger Tray", desc = "+1 tray slot", maxLevel = 3, baseCost = 80, costMult = 2.0, icon = "Y"},
    {id = "autoChef", name = "Kitchen Helper", desc = "Auto-prepare orders", maxLevel = 3, baseCost = 150, costMult = 2.5, icon = "K"},
    {id = "multiPrep", name = "Multi-Tasking", desc = "Prep multiple items", maxLevel = 2, baseCost = 200, costMult = 3.0, icon = "M"},
    -- New tavern upgrades
    {id = "reputation", name = "Reputation", desc = "+10% more customers", maxLevel = 5, baseCost = 100, costMult = 1.8, icon = "R"},
    {id = "quality", name = "Quality Ingredients", desc = "+10% order value", maxLevel = 5, baseCost = 120, costMult = 1.7, icon = "Q"},
    {id = "ambiance", name = "Better Ambiance", desc = "+8% patience & tips", maxLevel = 3, baseCost = 200, costMult = 2.0, icon = "A"},
}

-- Employee definitions (tavern staff) with gender info
-- Using new folder structure for portraits
local employeeTypes = {
    {
        id = "kitchen_hand",
        name = "Kitchen Hand",
        desc = "Helps prepare orders (slower than you)",
        hireCost = 100,
        dailyWage = 15,
        role = "prep",
        speed = 0.5,
        color = {0.4, 0.6, 0.9},
        gender = "any",
        malePortraits = {"Human/Men_Human/Human_01", "Human/Men_Human/Human_10", "Human/Men_Human/Human_28_thug"},
        femalePortraits = {"Human/Women_Human/Human_07", "Human/Women_Human/Human_16_girl"},
    },
    {
        id = "barmaid",
        name = "Barmaid",
        desc = "Expert at pouring drinks quickly",
        hireCost = 200,
        dailyWage = 25,
        role = "prep",
        speed = 0.9,
        specialties = {"ale", "mead", "wine", "cider"},
        color = {0.7, 0.5, 0.3},
        gender = "female",
        femalePortraits = {"Human/Women_Human/Human_15", "Human/Women_Human/Human_15_woman", "Human/Women_Human/Archer_woman"},
    },
    {
        id = "wench",
        name = "Serving Wench",
        desc = "Auto-serves ready items to customers",
        hireCost = 150,
        dailyWage = 20,
        role = "serve",
        serveSpeed = 2.0,
        color = {0.5, 0.8, 0.5},
        gender = "female",
        femalePortraits = {"Human/Women_Human/Human_07", "Human/Women_Human/Human_07_girl", "Human/Women_Human/Human_16_girl"},
    },
    {
        id = "cook",
        name = "Tavern Cook",
        desc = "Expert at preparing hearty meals",
        hireCost = 250,
        dailyWage = 30,
        role = "prep",
        speed = 0.85,
        specialties = {"stew", "roast", "pie", "fish"},
        color = {0.9, 0.7, 0.5},
        gender = "any",
        malePortraits = {"Human/Men_Human/Human_27_alchemyst", "Human/Men_Human/Human_06_Priest"},
        femalePortraits = {"Human/Women_Human/Human_30_witch", "Human/Women_Human/Human_31_witch"},
    },
    {
        id = "innkeeper",
        name = "Innkeeper",
        desc = "Customers wait 20% longer",
        hireCost = 300,
        dailyWage = 35,
        role = "buff",
        patienceBonus = 0.2,
        color = {0.8, 0.6, 0.9},
        gender = "any",
        malePortraits = {"Human/Men_Human/Human_11_lord", "Human/Men_Human/Merchant", "Human/Men_Human/Trader"},
        femalePortraits = {"Human/Women_Human/Human_15_woman", "Human/Women_Human/Old_woman", "Human/Women_Human/BlindWoman"},
    },
    {
        id = "bouncer",
        name = "Bouncer",
        desc = "Angry customers leave peacefully (+10% patience)",
        hireCost = 350,
        dailyWage = 40,
        role = "buff",
        patienceBonus = 0.1,
        color = {0.5, 0.4, 0.4},
        gender = "male",
        malePortraits = {"Human/Men_Human/Guard", "Human/Men_Human/BoldWarrior", "Human/Men_Human/Human_25_barbarian", "Human/Men_Human/Human_33_warrior"},
    },
    {
        id = "bard",
        name = "Bard",
        desc = "Entertains customers (+15% tips)",
        hireCost = 400,
        dailyWage = 45,
        role = "buff",
        tipBonus = 0.15,
        color = {0.6, 0.5, 0.8},
        gender = "any",
        malePortraits = {"ELF/Men_ELF/Elf_05", "ELF/Men_ELF/Elf_07", "Human/Men_Human/Human_23_rogue"},
        femalePortraits = {"ELF/Women_Elf/Elf_03", "ELF/Women_Elf/Elf_01", "ELF/Women_Elf/Elf_09", "ELF/Women_Elf/ElfMage"},
    },
    {
        id = "dwarf_brewer",
        name = "Dwarf Brewer",
        desc = "Master of ales and meads (very fast drinks)",
        hireCost = 500,
        dailyWage = 50,
        role = "prep",
        speed = 1.2,
        specialties = {"ale", "mead", "cider"},
        color = {0.7, 0.5, 0.3},
        gender = "male",
        malePortraits = {"Dwarves/Dwarf", "Dwarves/MadDwarf", "Gnomes/Male Gnomes/Gnome_02", "Gnomes/Male Gnomes/Gnome_05"},
    },
}

-- Employee name lists
local employeeMaleNames = {
    "Bjorn", "Gundric", "Halvar", "Tormund", "Ragnar", "Olaf", "Erik", "Sven",
    "Wilhelm", "Karl", "Fritz", "Hans", "Klaus", "Dieter", "Gunther", "Werner",
}

local employeeFemaleNames = {
    "Helga", "Ingrid", "Astrid", "Freya", "Sigrid", "Greta", "Hilda", "Brunhilde",
    "Gertrude", "Liesel", "Elke", "Heidi", "Katrin", "Monika", "Ursula", "Petra",
}

-- UI state
local buttons = {}
local selectedItem = nil
local hoverCustomer = nil
local showPauseMenu = false  -- Pause menu state

-- UI Components (panels, buttons created dynamically in draw functions)
local uiComponents = {
    daySummaryPanel = nil,
    upgradesPanel = nil,
    employeePanel = nil,
    pausePanel = nil,
    minigamePanel = nil,
}

function CafeGame.init()
    -- Initialize UI assets for character portraits
    UIAssets.init()

    -- Register tutorial region resolver
    InteractiveTutorial.registerRegionResolver("cafegame", CafeGame.getUIRegion)

    -- Play town music
    if AudioSystem and AudioSystem.playTownMusic then
        AudioSystem.playTownMusic()
    end

    CafeGame.reset()
end

-- Load saved upgrades from PlayerData
local function loadSavedUpgrades()
    if PlayerData.cafeUpgrades then
        return {
            traySize = PlayerData.cafeUpgrades.traySize or 0,
            prepSpeed = PlayerData.cafeUpgrades.prepSpeed or 0,
            patience = PlayerData.cafeUpgrades.patience or 0,
            tips = PlayerData.cafeUpgrades.tips or 0,
            autoChef = PlayerData.cafeUpgrades.autoChef or 0,
            multiPrep = PlayerData.cafeUpgrades.multiPrep or 0,
            reputation = PlayerData.cafeUpgrades.reputation or 0,
            quality = PlayerData.cafeUpgrades.quality or 0,
            ambiance = PlayerData.cafeUpgrades.ambiance or 0,
        }
    end
    return {
        traySize = 0,
        prepSpeed = 0,
        patience = 0,
        tips = 0,
        autoChef = 0,
        multiPrep = 0,
        reputation = 0,
        quality = 0,
        ambiance = 0,
    }
end

-- Load saved employees from PlayerData
local function loadSavedEmployees()
    if PlayerData.cafeEmployees then
        return PlayerData.cafeEmployees
    end
    return {}
end

-- Save upgrades and employees to PlayerData
local function saveUpgrades()
    PlayerData.cafeUpgrades = {
        traySize = gameState.upgrades.traySize,
        prepSpeed = gameState.upgrades.prepSpeed,
        patience = gameState.upgrades.patience,
        tips = gameState.upgrades.tips,
        autoChef = gameState.upgrades.autoChef,
        multiPrep = gameState.upgrades.multiPrep,
        reputation = gameState.upgrades.reputation,
        quality = gameState.upgrades.quality,
        ambiance = gameState.upgrades.ambiance,
    }
    PlayerData.cafeEmployees = gameState.employees
    PlayerData.cafeDay = gameState.day
    savePlayerData()
end

-- Get employee type definition by id
local function getEmployeeType(employeeId)
    for _, empType in ipairs(employeeTypes) do
        if empType.id == employeeId then
            return empType
        end
    end
    return nil
end

-- Calculate total daily wages
local function calculateDailyWages()
    local total = 0
    for _, emp in ipairs(gameState.employees) do
        local empType = getEmployeeType(emp.id)
        if empType then
            total = total + empType.dailyWage
        end
    end
    return total
end

-- Get patience bonus from managers
local function getManagerPatienceBonus()
    local bonus = 0
    for _, emp in ipairs(gameState.employees) do
        local empType = getEmployeeType(emp.id)
        if empType and empType.role == "buff" and empType.patienceBonus then
            bonus = bonus + empType.patienceBonus
        end
    end
    return bonus
end

-- Check if employee can prep an item (specialty check)
local function canEmployeePrep(empType, item)
    if empType.role ~= "prep" then return false end
    if not empType.specialties then return true end  -- No specialty = can prep anything
    for _, specialty in ipairs(empType.specialties) do
        if specialty == item.id then
            return true
        end
    end
    return false
end

-- Find an item that needs to be prepped (for employees)
local function findItemForEmployee(empType)
    for _, customer in ipairs(gameState.customers) do
        for _, orderItem in ipairs(customer.order) do
            if not orderItem.served and canEmployeePrep(empType, orderItem.item) then
                -- Check if already being prepped
                local alreadyPrepping = false
                if gameState.preparingItem and gameState.preparingItem.id == orderItem.item.id then
                    alreadyPrepping = true
                end
                for _, prep in ipairs(gameState.preparingItems) do
                    if prep.item.id == orderItem.item.id then
                        alreadyPrepping = true
                        break
                    end
                end
                -- Check employee prep queues
                for _, action in ipairs(gameState.employeeActions) do
                    if action.item and action.item.id == orderItem.item.id then
                        alreadyPrepping = true
                        break
                    end
                end
                if not alreadyPrepping then
                    return orderItem.item
                end
            end
        end
    end
    return nil
end

function CafeGame.reset()
    local savedUpgrades = loadSavedUpgrades()
    local savedEmployees = loadSavedEmployees()
    local savedDay = PlayerData.cafeDay or 1

    gameState = {
        money = PlayerData.coins or 100,
        startMoney = PlayerData.coins or 100,
        dayMoney = 0,
        day = savedDay,
        timeOfDay = 0,
        dayLength = 120,

        customers = {},
        maxCustomers = 4,
        customerSpawnTimer = 0,
        customerSpawnRate = 5,

        preparingItem = nil,
        preparingItems = {},  -- For multi-prep
        prepProgress = 0,

        servingTray = {},
        maxTrayItems = 3 + (savedUpgrades.traySize or 0),

        totalServed = 0,
        customersLost = 0,
        perfectOrders = 0,

        dayOver = false,
        showDaySummary = false,
        showUpgrades = false,
        showEmployeeMenu = false,

        autoMode = false,
        autoTimer = 0,

        upgrades = savedUpgrades,

        -- Employee system
        employees = savedEmployees,
        employeeActions = {},  -- Current employee activities
        dailyWages = 0,        -- Wages paid this day
        wagesPaid = false,     -- Track if wages paid this day

        -- Scroll positions for menus
        upgradeScroll = 0,
        employeeScroll = 0,
    }

    buttons = {}
    selectedItem = nil
    hoverCustomer = nil
end

function CafeGame.startNewDay()
    gameState.timeOfDay = 0
    gameState.dayMoney = 0
    gameState.customers = {}
    gameState.servingTray = {}
    gameState.preparingItem = nil
    gameState.preparingItems = {}
    gameState.prepProgress = 0
    gameState.customerSpawnTimer = 2  -- First customer comes quickly
    gameState.dayOver = false
    gameState.showDaySummary = false
    gameState.showUpgrades = false
    gameState.showEmployeeMenu = false
    gameState.totalServed = 0
    gameState.customersLost = 0
    gameState.perfectOrders = 0
    gameState.maxTrayItems = 3 + gameState.upgrades.traySize
    gameState.autoTimer = 0

    -- Reset employee state
    gameState.employeeActions = {}
    gameState.wagesPaid = false

    -- Pay employee wages at start of day (only if can afford)
    local wages = calculateDailyWages()
    if wages > 0 and gameState.money >= wages then
        gameState.money = gameState.money - wages
        gameState.dailyWages = wages
        gameState.wagesPaid = true
    elseif wages > 0 then
        -- Can't afford wages - pay what we can
        gameState.dailyWages = math.min(wages, math.max(0, gameState.money))
        gameState.money = math.max(0, gameState.money - gameState.dailyWages)
        gameState.wagesPaid = true
    else
        gameState.dailyWages = 0
    end
end

-- Find item that a customer needs (for auto mode)
local function findNeededItem()
    for _, customer in ipairs(gameState.customers) do
        for _, orderItem in ipairs(customer.order) do
            if not orderItem.served then
                -- Check if we're already preparing this item
                local alreadyPrepping = false
                if gameState.preparingItem and gameState.preparingItem.id == orderItem.item.id then
                    alreadyPrepping = true
                end
                for _, prep in ipairs(gameState.preparingItems) do
                    if prep.item.id == orderItem.item.id then
                        alreadyPrepping = true
                        break
                    end
                end
                if not alreadyPrepping then
                    return orderItem.item
                end
            end
        end
    end
    return nil
end

local function spawnCustomer()
    if #gameState.customers >= gameState.maxCustomers then return end

    local customerType = customerTypes[math.random(#customerTypes)]
    local numItems = math.random(1, math.min(3, gameState.day))  -- More items as days progress

    local order = {}
    for i = 1, numItems do
        local item = menuItems[math.random(#menuItems)]
        table.insert(order, {
            item = item,
            served = false
        })
    end

    -- Calculate patience with upgrade bonus and manager bonus
    local basePatience = customerType.patience + (gameState.upgrades.patience * 5)
    local managerBonus = getManagerPatienceBonus()
    local patience = basePatience * (1 + managerBonus + gameState.upgrades.ambiance * 0.08)

    -- Generate gender-matched name and portrait
    local gender = math.random() < 0.5 and "male" or "female"
    local name, portrait
    if gender == "male" then
        name = customerMaleNames[math.random(#customerMaleNames)]
        local portraits = customerType.malePortraits or {"Human/Men_Human/Human_01"}
        portrait = portraits[math.random(#portraits)]
    else
        name = customerFemaleNames[math.random(#customerFemaleNames)]
        local portraits = customerType.femalePortraits or {"Human/Women_Human/Human_07"}
        portrait = portraits[math.random(#portraits)]
    end

    -- Generate age (weighted toward working adults)
    local age = math.random(18, 65)

    local customer = {
        type = customerType,
        name = name,
        gender = gender,
        age = age,
        portrait = portrait,
        order = order,
        patience = patience,
        maxPatience = patience,
        tipMultiplier = customerType.tipMultiplier * (1 + gameState.upgrades.tips * 0.15 + gameState.upgrades.ambiance * 0.08),
        position = #gameState.customers + 1,
        enterAnim = 0
    }

    table.insert(gameState.customers, customer)
end

local function getOrderTotal(order)
    local total = 0
    for _, orderItem in ipairs(order) do
        total = total + orderItem.item.price
    end
    return total
end

local function isOrderComplete(customer)
    for _, orderItem in ipairs(customer.order) do
        if not orderItem.served then
            return false
        end
    end
    return true
end

local function serveItemToCustomer(customer, itemId, removeFromTray)
    -- Check if customer ordered this item and hasn't been served it yet
    for _, orderItem in ipairs(customer.order) do
        if orderItem.item.id == itemId and not orderItem.served then
            orderItem.served = true

            -- Remove item from tray if specified
            if removeFromTray then
                for i, trayItem in ipairs(gameState.servingTray) do
                    if trayItem.id == itemId then
                        table.remove(gameState.servingTray, i)
                        break
                    end
                end
            end

            -- Check if order complete
            if isOrderComplete(customer) then
                local total = getOrderTotal(customer.order)
                local patienceBonus = customer.patience / customer.maxPatience
                local tip = math.floor(total * customer.tipMultiplier * patienceBonus)
                local earnings = total + tip

                gameState.money = gameState.money + earnings
                gameState.dayMoney = gameState.dayMoney + earnings
                gameState.totalServed = gameState.totalServed + 1

                -- Award XP for serving customer
                Progression.addXP(Progression.XP_REWARDS.serve_customer, "cafe")

                if patienceBonus > 0.8 then
                    gameState.perfectOrders = gameState.perfectOrders + 1
                end

                -- Remove customer
                for i, c in ipairs(gameState.customers) do
                    if c == customer then
                        table.remove(gameState.customers, i)
                        break
                    end
                end

                -- Reposition remaining customers
                for i, c in ipairs(gameState.customers) do
                    c.position = i
                end
            end

            return true
        end
    end

    return false
end

-- Find first customer who needs a specific item
local function findCustomerNeedingItem(itemId)
    for _, customer in ipairs(gameState.customers) do
        for _, orderItem in ipairs(customer.order) do
            if orderItem.item.id == itemId and not orderItem.served then
                return customer
            end
        end
    end
    return nil
end

-- Auto-serve item to first customer who needs it
local function autoServeItem(item)
    local customer = findCustomerNeedingItem(item.id)
    if customer then
        serveItemToCustomer(customer, item.id, false)
        return true
    end
    return false
end

-- Legacy function for manual serving from tray
local function serveCustomer(customer, itemId)
    return serveItemToCustomer(customer, itemId, true)
end

function CafeGame.update(dt)
    -- Pause menu stops all updates
    if showPauseMenu then
        return
    end

    if gameState.showDaySummary then
        return
    end

    if gameState.dayOver then
        return
    end

    -- Update interactive minigames
    if gameState.activeMinigame == "pour" then
        -- Pouring mechanic update
        if gameState.pouringActive then
            -- Fill the pour meter
            gameState.pourProgress = math.min(100, gameState.pourProgress + dt * 50)

            -- Determine quality based on fill level
            if gameState.pourProgress >= 70 and gameState.pourProgress <= 85 then
                gameState.pourQuality = "perfect"
            elseif gameState.pourProgress >= 60 and gameState.pourProgress <= 95 then
                gameState.pourQuality = "good"
            elseif gameState.pourProgress < 100 then
                gameState.pourQuality = "okay"
            else
                gameState.pourQuality = "okay"  -- Overfilled
            end
        end
    elseif gameState.activeMinigame == "plate" then
        -- Plating mechanic update
        if gameState.platingStep < 3 then
            -- Update perfect timing window
            gameState.platePerfectTimer = gameState.platePerfectTimer + dt

            -- Random chance to show perfect window
            if not gameState.platePerfectWindow and math.random() < 0.3 * dt then
                gameState.platePerfectWindow = true
                gameState.platePerfectTimer = 0
            end

            -- Perfect window expires after 0.8 seconds
            if gameState.platePerfectWindow and gameState.platePerfectTimer >= 0.8 then
                gameState.platePerfectWindow = false
                gameState.platePerfectTimer = 0
            end
        end
    end

    -- Update time of day
    gameState.timeOfDay = gameState.timeOfDay + (dt / gameState.dayLength) * 100

    if gameState.timeOfDay >= 100 then
        -- Day is over, but wait for remaining customers
        if #gameState.customers == 0 then
            gameState.dayOver = true
            gameState.showDaySummary = true
            -- Completing a work day counts towards global wins for unlocks
            PlayerData.wins = PlayerData.wins + 1
            PlayerData.coins = PlayerData.coins + (gameState.money - gameState.startMoney)
            gameState.startMoney = gameState.money
            -- Award XP for completing shift
            Progression.addXP(Progression.XP_REWARDS.complete_shift, "cafe")
            saveUpgrades()  -- Save upgrades, day, and player data
        end
    else
        -- Spawn customers
        gameState.customerSpawnTimer = gameState.customerSpawnTimer - dt
        if gameState.customerSpawnTimer <= 0 then
            spawnCustomer()
            -- Spawn rate increases as day progresses
            local rushMultiplier = 1 - (gameState.timeOfDay / 200)  -- Gets faster mid-day
            gameState.customerSpawnTimer = gameState.customerSpawnRate * math.max(0.5, rushMultiplier)
        end
    end

    -- Update customer patience
    for i = #gameState.customers, 1, -1 do
        local customer = gameState.customers[i]
        customer.patience = customer.patience - dt
        customer.enterAnim = math.min(1, customer.enterAnim + dt * 3)

        if customer.patience <= 0 then
            gameState.customersLost = gameState.customersLost + 1
            table.remove(gameState.customers, i)
            -- Reposition remaining
            for j, c in ipairs(gameState.customers) do
                c.position = j
            end
        end
    end

    -- Auto mode: automatically start preparing needed items
    if gameState.autoMode and gameState.upgrades.autoChef > 0 then
        gameState.autoTimer = gameState.autoTimer + dt
        -- Auto speed based on upgrade level: 1=2s, 2=1s, 3=0.5s
        local autoDelay = 2.5 - (gameState.upgrades.autoChef * 0.7)

        if gameState.autoTimer >= autoDelay then
            gameState.autoTimer = 0
            -- Find an item that's needed and not being prepared
            local maxPrepping = 1 + (gameState.upgrades.multiPrep or 0)
            local currentPrepping = gameState.preparingItem and 1 or 0
            currentPrepping = currentPrepping + #gameState.preparingItems

            if currentPrepping < maxPrepping then
                local neededItem = findNeededItem()
                if neededItem then
                    if not gameState.preparingItem then
                        gameState.preparingItem = neededItem
                        gameState.prepProgress = 0
                    else
                        table.insert(gameState.preparingItems, {item = neededItem, progress = 0})
                    end
                end
            end
        end
    end

    -- Update item preparation
    local speedMultiplier = 1 + (gameState.upgrades.prepSpeed * 0.2)  -- 20% per level

    if gameState.preparingItem then
        gameState.prepProgress = gameState.prepProgress + (dt / gameState.preparingItem.prepTime) * speedMultiplier

        if gameState.prepProgress >= 1 then
            -- Item ready - auto-serve to first customer who needs it
            local served = autoServeItem(gameState.preparingItem)

            -- If no customer needs it, add to tray as backup
            if not served then
                if #gameState.servingTray < gameState.maxTrayItems then
                    table.insert(gameState.servingTray, gameState.preparingItem)
                end
            end

            gameState.preparingItem = nil
            gameState.prepProgress = 0
        end
    end

    -- Update multi-prep items
    for i = #gameState.preparingItems, 1, -1 do
        local prep = gameState.preparingItems[i]
        prep.progress = prep.progress + (dt / prep.item.prepTime) * speedMultiplier

        if prep.progress >= 1 then
            local served = autoServeItem(prep.item)
            if not served then
                if #gameState.servingTray < gameState.maxTrayItems then
                    table.insert(gameState.servingTray, prep.item)
                end
            end
            table.remove(gameState.preparingItems, i)
        end
    end

    -- Update employee actions
    for i = #gameState.employeeActions, 1, -1 do
        local action = gameState.employeeActions[i]

        if action.type == "prep" then
            -- Update prep progress
            local empType = getEmployeeType(action.employeeId)
            local empSpeed = empType and empType.speed or 0.5
            action.progress = action.progress + (dt / action.item.prepTime) * empSpeed

            if action.progress >= 1 then
                -- Item ready - auto-serve
                local served = autoServeItem(action.item)
                if not served then
                    if #gameState.servingTray < gameState.maxTrayItems then
                        table.insert(gameState.servingTray, action.item)
                    end
                end
                table.remove(gameState.employeeActions, i)
            end
        elseif action.type == "serve" then
            -- Server auto-serve from tray
            action.timer = action.timer - dt
            if action.timer <= 0 then
                -- Find item in tray and serve to customer who needs it
                for j, trayItem in ipairs(gameState.servingTray) do
                    local customer = findCustomerNeedingItem(trayItem.id)
                    if customer then
                        serveItemToCustomer(customer, trayItem.id, true)
                        break
                    end
                end
                -- Reset serve timer
                local empType = getEmployeeType(action.employeeId)
                action.timer = empType and empType.serveSpeed or 2.0
            end
        end
    end

    -- Assign idle prep employees to work
    for _, emp in ipairs(gameState.employees) do
        local empType = getEmployeeType(emp.id)
        if empType and empType.role == "prep" then
            -- Check if already working
            local isWorking = false
            for _, action in ipairs(gameState.employeeActions) do
                if action.employeeId == emp.id then
                    isWorking = true
                    break
                end
            end

            if not isWorking then
                local item = findItemForEmployee(empType)
                if item then
                    table.insert(gameState.employeeActions, {
                        type = "prep",
                        employeeId = emp.id,
                        item = item,
                        progress = 0
                    })
                end
            end
        elseif empType and empType.role == "serve" then
            -- Check if server is already active
            local isWorking = false
            for _, action in ipairs(gameState.employeeActions) do
                if action.employeeId == emp.id then
                    isWorking = true
                    break
                end
            end

            if not isWorking and #gameState.servingTray > 0 then
                table.insert(gameState.employeeActions, {
                    type = "serve",
                    employeeId = emp.id,
                    timer = empType.serveSpeed or 2.0
                })
            end
        end
    end
end

function CafeGame.draw()
    local screenW, screenH = love.graphics.getDimensions()

    -- Clear tooltip state
    UIAssets.clearTooltip()

    -- Draw wage mode background
    if not UIAssets.drawGameBackground("cafe", 1) then
        -- Fallback: Draw tavern background (stone wall)
        love.graphics.setColor(0.25, 0.22, 0.2)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)

        -- Draw stone texture pattern
        love.graphics.setColor(0.28, 0.25, 0.22)
        for x = 0, screenW, 80 do
            for y = 0, screenH * 0.5, 40 do
                local offset = ((y / 40) % 2) * 40
                love.graphics.rectangle("fill", x + offset, y, 78, 38, 2, 2)
            end
        end

        -- Draw wooden bar counter
        love.graphics.setColor(0.4, 0.28, 0.15)
        love.graphics.rectangle("fill", 0, screenH * 0.48, screenW, screenH * 0.12)
        -- Counter top highlight
        love.graphics.setColor(0.5, 0.35, 0.2)
        love.graphics.rectangle("fill", 0, screenH * 0.48, screenW, 8)
        -- Counter edge shadow
        love.graphics.setColor(0.3, 0.2, 0.1)
        love.graphics.rectangle("fill", 0, screenH * 0.59, screenW, 4)

        -- Draw wooden floor
        love.graphics.setColor(0.45, 0.32, 0.18)
        love.graphics.rectangle("fill", 0, screenH * 0.6, screenW, screenH * 0.4)

        -- Draw wood plank pattern on floor
        love.graphics.setColor(0.4, 0.28, 0.15)
        for x = 0, screenW, 120 do
            love.graphics.rectangle("fill", x, screenH * 0.6, 3, screenH * 0.4)
        end
        -- Horizontal plank lines
        love.graphics.setColor(0.38, 0.26, 0.13)
        for y = screenH * 0.6, screenH, 30 do
            love.graphics.rectangle("fill", 0, y, screenW, 2)
        end
    end

    -- Draw header (dark wood beam)
    love.graphics.setColor(0.2, 0.14, 0.08)
    love.graphics.rectangle("fill", 0, 0, screenW, 60)
    -- Header highlight
    love.graphics.setColor(0.3, 0.2, 0.12)
    love.graphics.rectangle("fill", 0, 58, screenW, 4)

    -- Draw tavern name and date/time/season info
    love.graphics.setColor(0.9, 0.8, 0.5)
    love.graphics.setFont(UI.fonts.get(20))
    love.graphics.print("The Rusty Flagon", 20, 10)

    -- Show date, time, and season instead of "Night X"
    local monthName, dayOfMonth = getDateFromDay(gameState.day)
    local season = getSeason(gameState.day)
    local timeStr = getTimeOfDay(gameState.timeOfDay)

    love.graphics.setColor(0.7, 0.8, 0.9)
    love.graphics.setFont(UI.fonts.get(12))
    local cafeYear = math.floor((gameState.day - 1) / 365) + 1
    love.graphics.print(monthName .. " " .. dayOfMonth .. ", Year " .. cafeYear .. " - " .. season, 20, 32)
    love.graphics.setColor(0.9, 0.9, 0.7)
    love.graphics.print(timeStr, 20, 46)

    -- Draw money (coins) with hover tooltip
    love.graphics.setFont(UI.fonts.get(18))
    UIAssets.drawCurrencyWithTooltip("coins", gameState.money, 178, 16, 22)

    -- Draw night earnings with icon
    local silverIcon = UIAssets.getIconByName("silver_coin")
    if silverIcon then
        love.graphics.setColor(1, 1, 1)
        local imgW, imgH = silverIcon:getDimensions()
        local iconSize = 16
        local scale = iconSize / math.max(imgW, imgH)
        love.graphics.draw(silverIcon, 178, 38, 0, scale, scale)
    end
    love.graphics.setColor(0.7, 0.9, 0.7)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.print("+" .. gameState.dayMoney, 198, 38)

    -- Draw time bar using UI.ProgressBar (but draw manually to keep exact styling)
    local timeBarW = 200
    local timeBarH = 20
    local timeBarX = screenW - timeBarW - 20
    local timeBarY = 20

    love.graphics.setColor(UI.theme.colors.bgDark)
    love.graphics.rectangle("fill", timeBarX, timeBarY, timeBarW, timeBarH, UI.theme.radius.sm, UI.theme.radius.sm)

    local progress = math.min(1, gameState.timeOfDay / 100)
    local barColor = {0.3, 0.7, 1.0}
    if progress > 0.7 then
        barColor = {1.0, 0.5, 0.3}
    elseif progress > 0.9 then
        barColor = {1.0, 0.3, 0.3}
    end
    love.graphics.setColor(barColor)
    love.graphics.rectangle("fill", timeBarX + 2, timeBarY + 2, (timeBarW - 4) * progress, timeBarH - 4, UI.theme.radius.sm, UI.theme.radius.sm)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.printf("Shift Progress", timeBarX, timeBarY + 3, timeBarW, "center")

    -- Employee count indicator
    if #gameState.employees > 0 then
        local empIndX = timeBarX - 100
        local empIndY = 18

        love.graphics.setColor(0.5, 0.5, 0.7)
        love.graphics.setFont(UI.fonts.get(14))
        love.graphics.print("Staff: " .. #gameState.employees, empIndX, empIndY)
    end

    -- Auto mode toggle button (only show if auto chef upgrade unlocked)
    if gameState.upgrades.autoChef > 0 then
        local autoBtnW, autoBtnH = 80, 30
        local autoBtnX = timeBarX - 200
        local autoBtnY = 15

        if gameState.autoMode then
            love.graphics.setColor(UI.theme.colors.success)
        else
            love.graphics.setColor(0.5, 0.4, 0.4)
        end
        love.graphics.rectangle("fill", autoBtnX, autoBtnY, autoBtnW, autoBtnH, UI.theme.radius.sm, UI.theme.radius.sm)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.fonts.get(12))
        love.graphics.printf(gameState.autoMode and "AUTO ON" or "AUTO OFF", autoBtnX, autoBtnY + 8, autoBtnW, "center")

        buttons["auto_toggle"] = {x = autoBtnX, y = autoBtnY, w = autoBtnW, h = autoBtnH}
    end

    -- Draw customers
    drawCustomers(screenW, screenH)

    -- Draw menu items (kitchen)
    drawMenuItems(screenW, screenH)

    -- Draw serving tray
    drawServingTray(screenW, screenH)

    -- Draw preparation progress
    if gameState.preparingItem then
        drawPrepProgress(screenW, screenH)
    end

    -- Draw employee work indicators
    drawEmployeeWork(screenW, screenH)

    -- Draw day summary
    if gameState.showDaySummary then
        drawDaySummary(screenW, screenH)
    end

    -- Draw back button
    drawBackButton(screenW, screenH)

    -- Draw interactive minigames on top of game
    if gameState.activeMinigame then
        drawMinigameOverlay(screenW, screenH)
    end

    -- Draw pause menu on top of everything
    if showPauseMenu then
        drawPauseMenu(screenW, screenH)
    end

    -- Draw currency tooltips (must be last)
    UIAssets.drawTooltip()
end

function drawPauseMenu(screenW, screenH)
    -- Darken background using UI theme
    love.graphics.setColor(UI.theme.colors.overlay)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Pause menu box using UI panel style
    local boxW = 300
    local boxH = 200
    local boxX = screenW / 2 - boxW / 2
    local boxY = screenH / 2 - boxH / 2

    love.graphics.setColor(UI.theme.colors.panel)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, UI.theme.radius.lg, UI.theme.radius.lg)
    love.graphics.setColor(0.6, 0.5, 0.7)
    love.graphics.setLineWidth(UI.theme.border.normal)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, UI.theme.radius.lg, UI.theme.radius.lg)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(UI.theme.colors.text)
    love.graphics.setFont(UI.fonts.get(28))
    love.graphics.printf("PAUSED", boxX, boxY + 25, boxW, "center")

    -- Resume button (success variant)
    local btnW = 200
    local btnH = 45
    local btnX = boxX + (boxW - btnW) / 2

    local resumeY = boxY + 80
    love.graphics.setColor(UI.theme.colors.success)
    love.graphics.rectangle("fill", btnX, resumeY, btnW, btnH, UI.theme.radius.md, UI.theme.radius.md)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(18))
    love.graphics.printf("Resume", btnX, resumeY + 12, btnW, "center")
    buttons["pause_resume"] = {x = btnX, y = resumeY, w = btnW, h = btnH}

    -- Quit button (danger variant)
    local quitY = boxY + 135
    love.graphics.setColor(UI.theme.colors.danger)
    love.graphics.rectangle("fill", btnX, quitY, btnW, btnH, UI.theme.radius.md, UI.theme.radius.md)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Quit to Menu", btnX, quitY + 12, btnW, "center")
    buttons["pause_quit"] = {x = btnX, y = quitY, w = btnW, h = btnH}
end

function drawEmployeeWork(screenW, screenH)
    if #gameState.employeeActions == 0 then return end

    local startX = screenW - 320
    local startY = screenH * 0.75
    local barW = 120
    local barH = 20

    love.graphics.setFont(UI.fonts.get(11))

    for i, action in ipairs(gameState.employeeActions) do
        local empType = getEmployeeType(action.employeeId)
        if empType then
            local y = startY + (i - 1) * 35

            -- Employee name
            love.graphics.setColor(empType.color)
            love.graphics.print(empType.name, startX, y)

            if action.type == "prep" and action.item then
                -- Prep progress bar
                love.graphics.setColor(0.3, 0.3, 0.3)
                love.graphics.rectangle("fill", startX, y + 14, barW, barH, 3, 3)

                love.graphics.setColor(action.item.color)
                love.graphics.rectangle("fill", startX + 2, y + 16, (barW - 4) * action.progress, barH - 4, 2, 2)

                love.graphics.setColor(1, 1, 1)
                love.graphics.printf(action.item.name, startX, y + 15, barW, "center")
            elseif action.type == "serve" then
                love.graphics.setColor(0.8, 0.8, 0.4)
                love.graphics.print("Serving...", startX, y + 14)
            end
        end
    end
end

-- Tavern-themed order phrases
local orderPhrases = {
    "I'll have ",
    "Bring me ",
    "One ",
    "Give me ",
    "I need ",
    "Get me ",
}

function drawCustomers(screenW, screenH)
    local customerW = 120
    local customerH = 150
    local startX = 50
    local startY = screenH * 0.30
    local spacing = 160

    for i, customer in ipairs(gameState.customers) do
        local x = startX + (i - 1) * spacing
        local y = startY - (1 - customer.enterAnim) * 50

        -- Draw character portrait if available (use customer.portrait from spawning)
        local portrait = nil
        if customer.portrait then
            portrait = UIAssets.getCharacter(customer.portrait)
        elseif customer.type.portrait then
            portrait = UIAssets.getCharacter(customer.type.portrait)
        end

        if portrait then
            -- Draw portrait with border
            love.graphics.setColor(1, 1, 1, customer.enterAnim)
            local imgW, imgH = portrait:getDimensions()
            local scale = customerH / math.max(imgW, imgH)
            love.graphics.draw(portrait, x + (customerW - imgW * scale) / 2, y, 0, scale, scale)

            -- Border
            love.graphics.setColor(customer.type.color[1], customer.type.color[2], customer.type.color[3], customer.enterAnim)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", x, y, customerW, customerH, 8, 8)
            love.graphics.setLineWidth(1)
        else
            -- Fallback to simple representation
            local typeColor = customer.type.color
            love.graphics.setColor(typeColor[1], typeColor[2], typeColor[3], customer.enterAnim)
            love.graphics.rectangle("fill", x, y, customerW, customerH, 10, 10)

            -- Customer type label
            love.graphics.setColor(1, 1, 1, customer.enterAnim)
            love.graphics.setFont(UI.fonts.get(11))
            love.graphics.printf(customer.type.type:upper(), x, y + customerH/2 - 8, customerW, "center")
        end

        -- Patience bar below portrait
        local barW = customerW - 10
        local barH = 10
        local barY = y + customerH + 5
        love.graphics.setColor(0.2, 0.2, 0.25, customer.enterAnim)
        love.graphics.rectangle("fill", x + 5, barY, barW, barH, 4, 4)

        local patienceRatio = customer.patience / customer.maxPatience
        local patienceColor = {0.2, 0.8, 0.2}
        if patienceRatio < 0.25 then
            patienceColor = {0.9, 0.2, 0.2}
        elseif patienceRatio < 0.5 then
            patienceColor = {0.9, 0.6, 0.2}
        end
        love.graphics.setColor(patienceColor[1], patienceColor[2], patienceColor[3], customer.enterAnim)
        love.graphics.rectangle("fill", x + 5, barY, barW * patienceRatio, barH, 4, 4)

        -- Order bubble (above portrait)
        local bubbleW = 160
        local bubbleH = 30 + #customer.order * 22
        local bubbleX = x + customerW/2 - bubbleW/2
        local bubbleY = y - 20 - bubbleH

        -- Bubble background (parchment style)
        love.graphics.setColor(0.95, 0.9, 0.8, customer.enterAnim)
        love.graphics.rectangle("fill", bubbleX, bubbleY, bubbleW, bubbleH, 8, 8)
        love.graphics.setColor(0.6, 0.5, 0.4, customer.enterAnim)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", bubbleX, bubbleY, bubbleW, bubbleH, 8, 8)
        love.graphics.setLineWidth(1)

        -- Bubble pointer
        love.graphics.setColor(0.95, 0.9, 0.8, customer.enterAnim)
        love.graphics.polygon("fill",
            bubbleX + bubbleW/2 - 10, bubbleY + bubbleH,
            bubbleX + bubbleW/2, bubbleY + bubbleH + 12,
            bubbleX + bubbleW/2 + 10, bubbleY + bubbleH
        )

        -- Order items with tavern phrases
        love.graphics.setFont(UI.fonts.get(12))
        local phrase = orderPhrases[(i % #orderPhrases) + 1]
        for j, orderItem in ipairs(customer.order) do
            local itemY = bubbleY + 8 + (j - 1) * 22

            if orderItem.served then
                love.graphics.setColor(0.2, 0.6, 0.2, customer.enterAnim)
                love.graphics.print("Done: " .. orderItem.item.name, bubbleX + 10, itemY)
            else
                love.graphics.setColor(0.3, 0.25, 0.2, customer.enterAnim)
                love.graphics.print(phrase .. orderItem.item.name, bubbleX + 10, itemY)
            end
        end

        -- Store button info for clicking
        buttons["customer_" .. i] = {
            x = x, y = y, w = customerW, h = customerH + 20,
            customer = customer
        }
    end
end

function drawMenuItems(screenW, screenH)
    -- Doubled sizes (100% increase) - moved down 30%
    local itemW = 160
    local itemH = 140
    local startX = 30
    local startY = screenH * 0.55  -- Moved down 30% (was 0.42)
    local spacing = 175

    love.graphics.setFont(UI.fonts.get(24))

    -- Organize items by category
    local drinks = {}
    local foods = {}
    for _, item in ipairs(menuItems) do
        if item.category == "drink" then
            table.insert(drinks, item)
        else
            table.insert(foods, item)
        end
    end

    -- Draw drinks row
    love.graphics.setColor(0.9, 0.85, 0.7)
    love.graphics.setFont(UI.fonts.get(24))
    love.graphics.print("Drinks:", startX, startY - 35)

    for i, item in ipairs(drinks) do
        local x = startX + (i - 1) * spacing
        local y = startY

        -- Item background (wooden plaque style)
        local isSelected = selectedItem == item
        local isPrepping = gameState.preparingItem == item

        if isPrepping then
            love.graphics.setColor(0.6, 0.5, 0.2)
        elseif isSelected then
            love.graphics.setColor(0.4, 0.5, 0.3)
        else
            love.graphics.setColor(0.35, 0.25, 0.15)
        end
        love.graphics.rectangle("fill", x, y, itemW, itemH, 10, 10)

        -- Wood frame
        love.graphics.setColor(0.5, 0.35, 0.2)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x, y, itemW, itemH, 10, 10)
        love.graphics.setLineWidth(1)

        -- Item icon (use image if available, fallback to text)
        local iconSize = 64
        local iconX = x + (itemW - iconSize) / 2
        local iconY = y + 10
        if not UIAssets.drawIcon(item.icon, iconX, iconY, iconSize) then
            -- Fallback to text icon
            love.graphics.setColor(item.color[1], item.color[2], item.color[3])
            love.graphics.setFont(UI.fonts.get(56))
            love.graphics.printf(item.iconFallback or item.icon, x, y + 12, itemW, "center")
        end

        -- Item name and price
        love.graphics.setColor(0.9, 0.85, 0.7)
        love.graphics.setFont(UI.fonts.get(18))
        love.graphics.printf(item.name, x, y + 82, itemW, "center")
        love.graphics.setColor(1, 0.85, 0.3)
        love.graphics.setFont(UI.fonts.get(16))
        love.graphics.printf(item.price .. " coins", x, y + 108, itemW, "center")

        buttons["item_" .. item.id] = {
            x = x, y = y, w = itemW, h = itemH,
            item = item
        }
    end

    -- Draw foods row
    love.graphics.setColor(0.9, 0.85, 0.7)
    love.graphics.setFont(UI.fonts.get(24))
    love.graphics.print("Food:", startX, startY + itemH + 20)

    for i, item in ipairs(foods) do
        local x = startX + (i - 1) * spacing
        local y = startY + itemH + 55

        -- Item background (wooden plaque style)
        local isSelected = selectedItem == item
        local isPrepping = gameState.preparingItem == item

        if isPrepping then
            love.graphics.setColor(0.6, 0.5, 0.2)
        elseif isSelected then
            love.graphics.setColor(0.4, 0.5, 0.3)
        else
            love.graphics.setColor(0.35, 0.25, 0.15)
        end
        love.graphics.rectangle("fill", x, y, itemW, itemH, 10, 10)

        -- Wood frame
        love.graphics.setColor(0.5, 0.35, 0.2)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x, y, itemW, itemH, 10, 10)
        love.graphics.setLineWidth(1)

        -- Item icon (use image if available, fallback to text)
        local iconSize = 64
        local iconX = x + (itemW - iconSize) / 2
        local iconY = y + 10
        if not UIAssets.drawIcon(item.icon, iconX, iconY, iconSize) then
            -- Fallback to text icon
            love.graphics.setColor(item.color[1], item.color[2], item.color[3])
            love.graphics.setFont(UI.fonts.get(56))
            love.graphics.printf(item.iconFallback or item.icon, x, y + 12, itemW, "center")
        end

        -- Item name and price
        love.graphics.setColor(0.9, 0.85, 0.7)
        love.graphics.setFont(UI.fonts.get(18))
        love.graphics.printf(item.name, x, y + 82, itemW, "center")
        love.graphics.setColor(1, 0.85, 0.3)
        love.graphics.setFont(UI.fonts.get(16))
        love.graphics.printf(item.price .. " coins", x, y + 108, itemW, "center")

        buttons["item_" .. item.id] = {
            x = x, y = y, w = itemW, h = itemH,
            item = item
        }
    end
end

function drawServingTray(screenW, screenH)
    local trayW = 300
    local trayH = 70
    local trayX = screenW - trayW - 30
    local trayY = screenH * 0.65

    -- Tray background
    love.graphics.setColor(0.4, 0.3, 0.25)
    love.graphics.rectangle("fill", trayX, trayY, trayW, trayH, 10, 10)

    -- Tray rim
    love.graphics.setColor(0.5, 0.4, 0.35)
    love.graphics.rectangle("line", trayX, trayY, trayW, trayH, 10, 10)

    -- Label
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.print("Serving Tray", trayX + 10, trayY - 18)

    -- Slots
    local slotW = 60
    local slotSpacing = 70
    local startX = trayX + 20

    for i = 1, gameState.maxTrayItems do
        local slotX = startX + (i - 1) * slotSpacing
        local slotY = trayY + 10

        -- Slot background
        love.graphics.setColor(0.3, 0.25, 0.2)
        love.graphics.rectangle("fill", slotX, slotY, slotW, 50, 5, 5)

        -- Item if present
        if gameState.servingTray[i] then
            local item = gameState.servingTray[i]
            -- Draw icon image or fallback
            local iconSize = 28
            local iconX = slotX + (slotW - iconSize) / 2
            local iconY = slotY + 3
            if not UIAssets.drawIcon(item.icon, iconX, iconY, iconSize) then
                love.graphics.setColor(item.color)
                love.graphics.setFont(UI.fonts.get(28))
                love.graphics.printf(item.iconFallback or item.icon, slotX, slotY + 5, slotW, "center")
            end
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(UI.fonts.get(10))
            love.graphics.printf(item.name, slotX, slotY + 35, slotW, "center")

            buttons["tray_" .. i] = {
                x = slotX, y = slotY, w = slotW, h = 50,
                trayIndex = i,
                item = item
            }
        else
            -- Empty slot indicator
            love.graphics.setColor(0.4, 0.35, 0.3)
            love.graphics.setFont(UI.fonts.get(14))
            love.graphics.printf("Empty", slotX, slotY + 17, slotW, "center")
        end
    end
end

function drawPrepProgress(screenW, screenH)
    local totalPrepping = 1 + #gameState.preparingItems
    local barW = 180
    local barH = 25
    local spacing = 45
    local totalH = totalPrepping * spacing
    local startY = screenH * 0.55 - totalH / 2

    -- Background panel
    love.graphics.setColor(0.2, 0.2, 0.2, 0.9)
    love.graphics.rectangle("fill", screenW / 2 - barW / 2 - 15, startY - 10, barW + 30, totalH + 20, 8, 8)

    -- Main item
    local barX = screenW / 2 - barW / 2
    local barY = startY

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.printf(gameState.preparingItem.name, barX, barY, barW, "center")

    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", barX, barY + 15, barW, barH, 5, 5)

    love.graphics.setColor(gameState.preparingItem.color)
    love.graphics.rectangle("fill", barX + 2, barY + 17, (barW - 4) * gameState.prepProgress, barH - 4, 3, 3)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(11))
    love.graphics.printf(math.floor(gameState.prepProgress * 100) .. "%", barX, barY + 19, barW, "center")

    -- Additional items (multi-prep)
    for i, prep in ipairs(gameState.preparingItems) do
        barY = startY + i * spacing

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.fonts.get(12))
        love.graphics.printf(prep.item.name, barX, barY, barW, "center")

        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.rectangle("fill", barX, barY + 15, barW, barH, 5, 5)

        love.graphics.setColor(prep.item.color)
        love.graphics.rectangle("fill", barX + 2, barY + 17, (barW - 4) * prep.progress, barH - 4, 3, 3)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.fonts.get(11))
        love.graphics.printf(math.floor(prep.progress * 100) .. "%", barX, barY + 19, barW, "center")
    end
end

function drawDaySummary(screenW, screenH)
    -- Overlay using UI theme
    love.graphics.setColor(UI.theme.colors.overlay)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    if gameState.showUpgrades then
        -- Upgrades Shop
        drawUpgradesShop(screenW, screenH)
    elseif gameState.showEmployeeMenu then
        -- Employee Hiring
        drawEmployeeMenu(screenW, screenH)
    else
        -- Day Summary
        drawDayStats(screenW, screenH)
    end
end

function drawDayStats(screenW, screenH)
    -- Panel dimensions
    local boxW = 500
    local boxH = 450
    local boxX = screenW / 2 - boxW / 2
    local boxY = screenH / 2 - boxH / 2

    -- Draw panel using UI component
    love.graphics.setColor(UI.theme.colors.panel)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, UI.theme.radius.lg, UI.theme.radius.lg)
    love.graphics.setColor(0.6, 0.5, 0.4)
    love.graphics.setLineWidth(UI.theme.border.thick)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, UI.theme.radius.lg, UI.theme.radius.lg)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(1, 0.9, 0.7)
    love.graphics.setFont(UI.fonts.get(28))
    love.graphics.printf("Night " .. gameState.day .. " Closing Time!", boxX, boxY + 20, boxW, "center")

    -- Stats
    love.graphics.setFont(UI.fonts.get(18))
    local statsY = boxY + 80

    love.graphics.setColor(1, 0.85, 0.3)
    love.graphics.printf("Earnings: " .. gameState.dayMoney .. " coins", boxX, statsY, boxW, "center")

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Patrons Served: " .. gameState.totalServed, boxX, statsY + 35, boxW, "center")

    love.graphics.setColor(1, 0.8, 0.3)
    love.graphics.printf("Happy Customers: " .. gameState.perfectOrders, boxX, statsY + 70, boxW, "center")

    if gameState.customersLost > 0 then
        love.graphics.setColor(1, 0.4, 0.4)
        love.graphics.printf("Patrons Left Angry: " .. gameState.customersLost, boxX, statsY + 105, boxW, "center")
    end

    -- Show wages paid if any
    if gameState.dailyWages > 0 then
        love.graphics.setColor(1, 0.5, 0.5)
        love.graphics.printf("Staff Wages: -" .. gameState.dailyWages .. " coins", boxX, statsY + 140, boxW, "center")
    end

    -- Net profit
    local netProfit = gameState.dayMoney - gameState.dailyWages
    local profitY = statsY + 175
    if netProfit >= 0 then
        love.graphics.setColor(0.3, 0.9, 0.5)
        love.graphics.printf("Profit: " .. netProfit .. " coins", boxX, profitY, boxW, "center")
    else
        love.graphics.setColor(1, 0.4, 0.4)
        love.graphics.printf("Loss: -" .. math.abs(netProfit) .. " coins", boxX, profitY, boxW, "center")
    end

    -- Total money
    love.graphics.setColor(0.3, 1, 0.5)
    love.graphics.setFont(UI.fonts.get(22))
    love.graphics.printf("Coin Purse: " .. gameState.money .. " coins", boxX, profitY + 40, boxW, "center")

    -- Employee count
    if #gameState.employees > 0 then
        love.graphics.setColor(0.7, 0.7, 0.9)
        love.graphics.setFont(UI.fonts.get(14))
        love.graphics.printf("Employees: " .. #gameState.employees, boxX, profitY + 70, boxW, "center")
    end

    -- Buttons - adjusted to fit 4 buttons
    local btnW = 105
    local btnH = 45
    local btnY = boxY + boxH - 70
    local btnSpacing = 8
    local totalBtnsW = 4 * btnW + 3 * btnSpacing
    local startBtnX = boxX + (boxW - totalBtnsW) / 2

    -- Next Night button (success variant)
    love.graphics.setColor(UI.theme.colors.success)
    love.graphics.rectangle("fill", startBtnX, btnY, btnW, btnH, UI.theme.radius.md, UI.theme.radius.md)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(13))
    love.graphics.printf("Next Night", startBtnX, btnY + 15, btnW, "center")
    buttons["next_day"] = {x = startBtnX, y = btnY, w = btnW, h = btnH}

    -- Upgrades button (primary variant)
    local btn2X = startBtnX + btnW + btnSpacing
    love.graphics.setColor(UI.theme.colors.primary)
    love.graphics.rectangle("fill", btn2X, btnY, btnW, btnH, UI.theme.radius.md, UI.theme.radius.md)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Upgrades", btn2X, btnY + 15, btnW, "center")
    buttons["show_upgrades"] = {x = btn2X, y = btnY, w = btnW, h = btnH}

    -- Employees button (secondary variant)
    local btn3X = btn2X + btnW + btnSpacing
    love.graphics.setColor(UI.theme.colors.secondary)
    love.graphics.rectangle("fill", btn3X, btnY, btnW, btnH, UI.theme.radius.md, UI.theme.radius.md)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Employees", btn3X, btnY + 15, btnW, "center")
    buttons["show_employees"] = {x = btn3X, y = btnY, w = btnW, h = btnH}

    -- Exit button (danger variant)
    local btn4X = btn3X + btnW + btnSpacing
    love.graphics.setColor(UI.theme.colors.danger)
    love.graphics.rectangle("fill", btn4X, btnY, btnW, btnH, UI.theme.radius.md, UI.theme.radius.md)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Exit", btn4X, btnY + 15, btnW, "center")
    buttons["exit_cafe"] = {x = btn4X, y = btnY, w = btnW, h = btnH}
end

function drawUpgradesShop(screenW, screenH)
    local boxW = 600
    local boxH = 520
    local boxX = screenW / 2 - boxW / 2
    local boxY = screenH / 2 - boxH / 2

    -- Panel background using UI theme
    love.graphics.setColor(UI.theme.colors.panel)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, UI.theme.radius.lg, UI.theme.radius.lg)
    love.graphics.setColor(UI.theme.colors.primary)
    love.graphics.setLineWidth(UI.theme.border.thick)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, UI.theme.radius.lg, UI.theme.radius.lg)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(UI.theme.colors.textAccent)
    love.graphics.setFont(UI.fonts.get(28))
    love.graphics.printf("UPGRADES SHOP", boxX, boxY + 15, boxW, "center")

    -- Money display
    love.graphics.setColor(UI.theme.colors.success)
    love.graphics.setFont(UI.fonts.get(20))
    love.graphics.printf("Your Money: $" .. gameState.money, boxX, boxY + 50, boxW, "center")

    -- Scrollable upgrade area
    local listX = boxX + 20
    local listY = boxY + 90
    local listW = boxW - 40
    local listH = boxH - 160  -- Space for title, money, and back button

    local itemH = 55
    local itemSpacing = 8
    local totalItemHeight = itemH + itemSpacing

    -- Calculate total content height and max scroll
    local totalContentHeight = #upgradeDefinitions * totalItemHeight
    local maxScroll = math.max(0, totalContentHeight - listH)
    gameState.upgradeScroll = math.max(0, math.min(gameState.upgradeScroll, maxScroll))

    -- Set scissor for scrollable area
    love.graphics.setScissor(listX, listY, listW, listH)

    -- Draw upgrade items with scroll offset
    for i, upgrade in ipairs(upgradeDefinitions) do
        local itemX = listX
        local itemY = listY + (i - 1) * totalItemHeight - gameState.upgradeScroll

        -- Only draw if visible
        if itemY + itemH >= listY and itemY <= listY + listH then
            local currentLevel = gameState.upgrades[upgrade.id] or 0
            local maxed = currentLevel >= upgrade.maxLevel
            local cost = math.floor(upgrade.baseCost * (upgrade.costMult ^ currentLevel))
            local canAfford = gameState.money >= cost

            -- Background using UI theme
            if maxed then
                love.graphics.setColor(UI.theme.colors.bgLight)
            elseif canAfford then
                love.graphics.setColor(UI.theme.colors.bgLight)
            else
                love.graphics.setColor(UI.theme.colors.bgDark)
            end
            love.graphics.rectangle("fill", itemX, itemY, listW, itemH, UI.theme.radius.md, UI.theme.radius.md)

            -- Icon
            love.graphics.setColor(UI.theme.colors.text)
            love.graphics.setFont(UI.fonts.get(24))
            love.graphics.print(upgrade.icon, itemX + 15, itemY + 12)

            -- Name and description
            love.graphics.setColor(UI.theme.colors.text)
            love.graphics.setFont(UI.fonts.get(16))
            love.graphics.print(upgrade.name, itemX + 55, itemY + 8)

            love.graphics.setColor(UI.theme.colors.textDim)
            love.graphics.setFont(UI.fonts.get(12))
            love.graphics.print(upgrade.desc, itemX + 55, itemY + 30)

            -- Level display
            love.graphics.setColor(UI.theme.colors.textAccent)
            love.graphics.setFont(UI.fonts.get(14))
            local levelText = "Lv " .. currentLevel .. "/" .. upgrade.maxLevel
            love.graphics.print(levelText, itemX + 300, itemY + 18)

            -- Buy button
            local btnX = itemX + listW - 100
            local btnY = itemY + 10
            local btnW = 85
            local btnH = 35

            if maxed then
                love.graphics.setColor(UI.theme.colors.success)
                love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, UI.theme.radius.sm, UI.theme.radius.sm)
                love.graphics.setColor(UI.theme.colors.text)
                love.graphics.setFont(UI.fonts.get(14))
                love.graphics.printf("MAXED", btnX, btnY + 10, btnW, "center")
            else
                if canAfford then
                    love.graphics.setColor(UI.theme.colors.success)
                else
                    love.graphics.setColor(UI.theme.colors.bgDark)
                end
                love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, UI.theme.radius.sm, UI.theme.radius.sm)
                love.graphics.setColor(UI.theme.colors.text)
                love.graphics.setFont(UI.fonts.get(14))
                love.graphics.printf("$" .. cost, btnX, btnY + 10, btnW, "center")

                -- Store button position adjusted for scroll visibility check
                if itemY + 10 >= listY and itemY + 10 + btnH <= listY + listH then
                    buttons["upgrade_" .. upgrade.id] = {
                        x = btnX, y = btnY, w = btnW, h = btnH,
                        upgrade = upgrade,
                        cost = cost,
                        canAfford = canAfford
                    }
                end
            end
        end
    end

    love.graphics.setScissor()

    -- Draw scroll bar if needed using UI theme
    if totalContentHeight > listH then
        local scrollBarW = 8
        local scrollBarX = boxX + boxW - 25
        local scrollBarH = math.max(30, (listH / totalContentHeight) * listH)
        local scrollBarY = listY + (gameState.upgradeScroll / maxScroll) * (listH - scrollBarH)

        -- Track
        love.graphics.setColor(UI.theme.colors.scrollbar)
        love.graphics.rectangle("fill", scrollBarX, listY, scrollBarW, listH, UI.theme.radius.sm, UI.theme.radius.sm)

        -- Thumb
        love.graphics.setColor(UI.theme.colors.primary)
        love.graphics.rectangle("fill", scrollBarX, scrollBarY, scrollBarW, scrollBarH, UI.theme.radius.sm, UI.theme.radius.sm)

        -- Scroll hint
        love.graphics.setColor(UI.theme.colors.textDim)
        love.graphics.setFont(UI.fonts.get(10))
        love.graphics.printf("Scroll for more", boxX, listY + listH + 5, boxW, "center")
    end

    -- Back button (outside scroll area)
    local backBtnW = 120
    local backBtnH = 40
    local backBtnX = boxX + boxW / 2 - backBtnW / 2
    local backBtnY = boxY + boxH - 50

    love.graphics.setColor(UI.theme.colors.secondary)
    love.graphics.rectangle("fill", backBtnX, backBtnY, backBtnW, backBtnH, UI.theme.radius.md, UI.theme.radius.md)
    love.graphics.setColor(UI.theme.colors.text)
    love.graphics.setFont(UI.fonts.get(16))
    love.graphics.printf("Back", backBtnX, backBtnY + 10, backBtnW, "center")

    buttons["back_from_upgrades"] = {x = backBtnX, y = backBtnY, w = backBtnW, h = backBtnH}
end

function drawEmployeeMenu(screenW, screenH)
    local boxW = 650
    local boxH = 550
    local boxX = screenW / 2 - boxW / 2
    local boxY = screenH / 2 - boxH / 2

    -- Panel background using UI theme
    love.graphics.setColor(UI.theme.colors.panel)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, UI.theme.radius.lg, UI.theme.radius.lg)
    love.graphics.setColor(UI.theme.colors.secondary)
    love.graphics.setLineWidth(UI.theme.border.thick)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, UI.theme.radius.lg, UI.theme.radius.lg)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(UI.theme.colors.textAccent)
    love.graphics.setFont(UI.fonts.get(28))
    love.graphics.printf("EMPLOYEE MANAGEMENT", boxX, boxY + 15, boxW, "center")

    -- Money and daily wages display
    love.graphics.setColor(UI.theme.colors.success)
    love.graphics.setFont(UI.fonts.get(18))
    love.graphics.printf("Your Money: $" .. gameState.money, boxX, boxY + 50, boxW, "center")

    local dailyWageCost = calculateDailyWages()
    if dailyWageCost > 0 then
        love.graphics.setColor(UI.theme.colors.warning)
        love.graphics.setFont(UI.fonts.get(14))
        love.graphics.printf("Daily Wages: $" .. dailyWageCost .. "/day", boxX, boxY + 75, boxW, "center")
    end

    -- Scrollable content area
    local scrollAreaX = boxX + 15
    local scrollAreaY = boxY + 95
    local scrollAreaW = boxW - 45  -- Leave room for scrollbar
    local scrollAreaH = boxH - 160  -- Room for header and back button
    local scrollBarW = 12

    -- Calculate total content height
    local hiredH = 35
    local hiredSpacing = 5
    local itemH = 65
    local itemSpacing = 5
    local sectionGap = 30

    local hiredSectionH = 25 + math.max(1, #gameState.employees) * (hiredH + hiredSpacing)
    local hireSectionH = 25 + #employeeTypes * (itemH + itemSpacing)
    local totalContentHeight = hiredSectionH + sectionGap + hireSectionH + 20

    -- Clamp scroll
    local maxScroll = math.max(0, totalContentHeight - scrollAreaH)
    gameState.employeeScroll = gameState.employeeScroll or 0
    gameState.employeeScroll = math.max(0, math.min(gameState.employeeScroll, maxScroll))

    -- Store scroll area for wheelmoved
    gameState.employeeScrollArea = {x = scrollAreaX, y = scrollAreaY, w = scrollAreaW + scrollBarW, h = scrollAreaH}

    -- Begin scissor clipping
    love.graphics.setScissor(scrollAreaX, scrollAreaY, scrollAreaW, scrollAreaH)

    local contentY = scrollAreaY - gameState.employeeScroll

    -- Hired employees section
    love.graphics.setColor(0.9, 0.9, 0.7)
    love.graphics.setFont(UI.fonts.get(16))
    love.graphics.print("Your Staff (" .. #gameState.employees .. ")", scrollAreaX + 5, contentY)

    -- List hired employees
    for i, emp in ipairs(gameState.employees) do
        local empType = getEmployeeType(emp.id)
        if empType then
            local y = contentY + 25 + (i - 1) * (hiredH + hiredSpacing)

            -- Only draw and register buttons if visible
            if y + hiredH > scrollAreaY and y < scrollAreaY + scrollAreaH then
                -- Background
                love.graphics.setColor(0.15, 0.18, 0.22)
                love.graphics.rectangle("fill", scrollAreaX + 5, y, scrollAreaW - 10, hiredH, 5, 5)

                -- Employee color indicator
                love.graphics.setColor(empType.color)
                love.graphics.rectangle("fill", scrollAreaX + 10, y + 5, 8, hiredH - 10, 2, 2)

                -- Name and role
                love.graphics.setColor(1, 1, 1)
                love.graphics.setFont(UI.fonts.get(14))
                love.graphics.print(empType.name, scrollAreaX + 30, y + 10)

                -- Daily wage
                love.graphics.setColor(1, 0.7, 0.5)
                love.graphics.setFont(UI.fonts.get(12))
                love.graphics.print("$" .. empType.dailyWage .. "/day", scrollAreaX + 180, y + 12)

                -- Fire button
                local fireBtnW = 60
                local fireBtnH = 25
                local fireBtnX = scrollAreaX + scrollAreaW - fireBtnW - 15
                local fireBtnY = y + 5

                love.graphics.setColor(0.6, 0.25, 0.25)
                love.graphics.rectangle("fill", fireBtnX, fireBtnY, fireBtnW, fireBtnH, 4, 4)
                love.graphics.setColor(1, 1, 1)
                love.graphics.setFont(UI.fonts.get(11))
                love.graphics.printf("Fire", fireBtnX, fireBtnY + 6, fireBtnW, "center")

                -- Only register button if fully visible
                if fireBtnY >= scrollAreaY and fireBtnY + fireBtnH <= scrollAreaY + scrollAreaH then
                    buttons["fire_emp_" .. i] = {x = fireBtnX, y = fireBtnY, w = fireBtnW, h = fireBtnH, index = i}
                end
            end
        end
    end

    -- Available to hire section
    local hireY = contentY + hiredSectionH + sectionGap
    love.graphics.setColor(0.7, 0.9, 0.7)
    love.graphics.setFont(UI.fonts.get(16))
    love.graphics.print("Available to Hire", scrollAreaX + 5, hireY)

    -- Check if player owns this building
    local ownsBuilding = PlayerData.currentBuildingOwned == true

    -- Show ownership requirement message if not owned
    if not ownsBuilding then
        love.graphics.setColor(0.8, 0.6, 0.4)
        love.graphics.setFont(UI.fonts.get(12))
        love.graphics.printf("You must own this business to hire employees.", scrollAreaX + 5, hireY + 22, scrollAreaW - 10, "left")
        love.graphics.setColor(0.6, 0.6, 0.5)
        love.graphics.setFont(UI.fonts.get(10))
        love.graphics.printf("Purchase this property in town to unlock employee management.", scrollAreaX + 5, hireY + 40, scrollAreaW - 10, "left")
    end

    -- List employee types for hiring
    for i, empType in ipairs(employeeTypes) do
        local y = hireY + 25 + (i - 1) * (itemH + itemSpacing)

        -- Only draw if visible
        if y + itemH > scrollAreaY and y < scrollAreaY + scrollAreaH then
            -- Check if already hired (can only have one of each type)
            local alreadyHired = false
            for _, emp in ipairs(gameState.employees) do
                if emp.id == empType.id then
                    alreadyHired = true
                    break
                end
            end

            local canAfford = gameState.money >= empType.hireCost

            -- Background
            if alreadyHired then
                love.graphics.setColor(0.12, 0.15, 0.12)
            elseif canAfford then
                love.graphics.setColor(0.18, 0.2, 0.25)
            else
                love.graphics.setColor(0.12, 0.1, 0.12)
            end
            love.graphics.rectangle("fill", scrollAreaX + 5, y, scrollAreaW - 10, itemH, 8, 8)

            -- Color indicator
            love.graphics.setColor(empType.color)
            love.graphics.rectangle("fill", scrollAreaX + 13, y + 10, 10, itemH - 20, 3, 3)

            -- Name
            love.graphics.setColor(1, 0.95, 0.85)
            love.graphics.setFont(UI.fonts.get(16))
            love.graphics.print(empType.name, scrollAreaX + 35, y + 8)

            -- Description
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.setFont(UI.fonts.get(12))
            love.graphics.print(empType.desc, scrollAreaX + 35, y + 28)

            -- Daily wage info
            love.graphics.setColor(1, 0.7, 0.5)
            love.graphics.print("Wage: $" .. empType.dailyWage .. "/day", scrollAreaX + 35, y + 45)

            -- Hire button
            local hireBtnW = 90
            local hireBtnH = 35
            local hireBtnX = scrollAreaX + scrollAreaW - hireBtnW - 15
            local hireBtnY = y + (itemH - hireBtnH) / 2

            if alreadyHired then
                love.graphics.setColor(0.3, 0.4, 0.3)
                love.graphics.rectangle("fill", hireBtnX, hireBtnY, hireBtnW, hireBtnH, 5, 5)
                love.graphics.setColor(0.7, 0.9, 0.7)
                love.graphics.setFont(UI.fonts.get(13))
                love.graphics.printf("HIRED", hireBtnX, hireBtnY + 10, hireBtnW, "center")
            else
                -- Show locked/unavailable if not owned, otherwise show price
                if not ownsBuilding then
                    love.graphics.setColor(0.25, 0.2, 0.2)
                    love.graphics.rectangle("fill", hireBtnX, hireBtnY, hireBtnW, hireBtnH, 5, 5)
                    love.graphics.setColor(0.5, 0.4, 0.4)
                    love.graphics.setFont(UI.fonts.get(11))
                    love.graphics.printf("Locked", hireBtnX, hireBtnY + 10, hireBtnW, "center")
                    -- Don't register button if not owned
                elseif canAfford then
                    love.graphics.setColor(0.2, 0.5, 0.3)
                    love.graphics.rectangle("fill", hireBtnX, hireBtnY, hireBtnW, hireBtnH, 5, 5)
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.setFont(UI.fonts.get(13))
                    love.graphics.printf("$" .. empType.hireCost, hireBtnX, hireBtnY + 10, hireBtnW, "center")

                    -- Only register button if fully visible and player owns building
                    if hireBtnY >= scrollAreaY and hireBtnY + hireBtnH <= scrollAreaY + scrollAreaH then
                        buttons["hire_" .. empType.id] = {
                            x = hireBtnX, y = hireBtnY, w = hireBtnW, h = hireBtnH,
                            empType = empType,
                            canAfford = canAfford
                        }
                    end
                else
                    love.graphics.setColor(0.35, 0.25, 0.25)
                    love.graphics.rectangle("fill", hireBtnX, hireBtnY, hireBtnW, hireBtnH, 5, 5)
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.setFont(UI.fonts.get(13))
                    love.graphics.printf("$" .. empType.hireCost, hireBtnX, hireBtnY + 10, hireBtnW, "center")
                end
            end
        end
    end

    -- End scissor clipping
    love.graphics.setScissor()

    -- Draw scrollbar if content exceeds view using UI theme
    if totalContentHeight > scrollAreaH then
        local scrollBarX = boxX + boxW - scrollBarW - 18
        local scrollBarH = scrollAreaH
        local thumbH = math.max(30, (scrollAreaH / totalContentHeight) * scrollBarH)
        local thumbY = scrollAreaY + (gameState.employeeScroll / maxScroll) * (scrollBarH - thumbH)

        -- Scrollbar track
        love.graphics.setColor(UI.theme.colors.scrollbar)
        love.graphics.rectangle("fill", scrollBarX, scrollAreaY, scrollBarW, scrollBarH, UI.theme.radius.sm, UI.theme.radius.sm)

        -- Scrollbar thumb
        love.graphics.setColor(UI.theme.colors.scrollbarThumb)
        love.graphics.rectangle("fill", scrollBarX, thumbY, scrollBarW, thumbH, UI.theme.radius.sm, UI.theme.radius.sm)
    end

    -- Back button (outside scroll area)
    local backBtnW = 120
    local backBtnH = 40
    local backBtnX = boxX + boxW / 2 - backBtnW / 2
    local backBtnY = boxY + boxH - 55

    love.graphics.setColor(UI.theme.colors.secondary)
    love.graphics.rectangle("fill", backBtnX, backBtnY, backBtnW, backBtnH, UI.theme.radius.md, UI.theme.radius.md)
    love.graphics.setColor(UI.theme.colors.text)
    love.graphics.setFont(UI.fonts.get(16))
    love.graphics.printf("Back", backBtnX, backBtnY + 10, backBtnW, "center")

    buttons["back_from_employees"] = {x = backBtnX, y = backBtnY, w = backBtnW, h = backBtnH}
end

function drawBackButton(screenW, screenH)
    if not gameState.showDaySummary then
        local btnW = 100
        local btnH = 35
        local btnX = screenW - btnW - 10
        local btnY = screenH - btnH - 10

        love.graphics.setColor(UI.theme.colors.danger)
        love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, UI.theme.radius.sm, UI.theme.radius.sm)
        love.graphics.setColor(UI.theme.colors.text)
        love.graphics.setFont(UI.fonts.get(14))
        love.graphics.printf("Back", btnX, btnY + 10, btnW, "center")

        buttons["back"] = {x = btnX, y = btnY, w = btnW, h = btnH}
    end
end

function drawMinigameOverlay(screenW, screenH)
    -- Darken background using UI theme
    love.graphics.setColor(UI.theme.colors.overlay)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    if gameState.activeMinigame == "pour" then
        -- DRINK POURING MINIGAME
        local boxW = 400
        local boxH = 500
        local boxX = screenW / 2 - boxW / 2
        local boxY = screenH / 2 - boxH / 2

        -- Background panel using UI theme
        love.graphics.setColor(UI.theme.colors.panel)
        love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, UI.theme.radius.lg, UI.theme.radius.lg)
        love.graphics.setColor(UI.theme.colors.primary)
        love.graphics.setLineWidth(UI.theme.border.thick)
        love.graphics.rectangle("line", boxX, boxY, boxW, boxH, UI.theme.radius.lg, UI.theme.radius.lg)
        love.graphics.setLineWidth(1)

        -- Title
        love.graphics.setColor(UI.theme.colors.textAccent)
        love.graphics.setFont(UI.fonts.get(24))
        love.graphics.printf("Pour " .. gameState.minigameItem.name, boxX, boxY + 20, boxW, "center")

        -- Instructions
        love.graphics.setColor(UI.theme.colors.text)
        love.graphics.setFont(UI.fonts.get(14))
        love.graphics.printf("Hold SPACE to pour. Stop at the green zone for perfect pour!", boxX + 20, boxY + 60, boxW - 40, "center")

        -- Draw bottle (visual representation)
        local bottleX = boxX + boxW / 2 - 40
        local bottleY = boxY + 120
        love.graphics.setColor(gameState.minigameItem.color)
        love.graphics.rectangle("fill", bottleX, bottleY, 80, 120, 8, 8)
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.rectangle("fill", bottleX + 25, bottleY - 20, 30, 25, 4, 4)
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.setFont(UI.fonts.get(12))
        love.graphics.printf(gameState.minigameItem.name, bottleX, bottleY + 40, 80, "center")

        -- Draw cup with fill level
        local cupX = boxX + boxW / 2 - 50
        local cupY = boxY + 280
        local cupW = 100
        local cupH = 140

        -- Cup outline
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.setLineWidth(3)
        love.graphics.line(cupX + 10, cupY, cupX, cupY + cupH)
        love.graphics.line(cupX + cupW - 10, cupY, cupX + cupW, cupY + cupH)
        love.graphics.line(cupX, cupY + cupH, cupX + cupW, cupY + cupH)
        love.graphics.setLineWidth(1)

        -- Fill level
        local fillPercent = gameState.pourProgress / 100
        local fillH = cupH * fillPercent
        love.graphics.setColor(gameState.minigameItem.color[1], gameState.minigameItem.color[2], gameState.minigameItem.color[3], 0.8)
        local fillX1 = cupX + (10 * (1 - fillPercent))
        local fillX2 = cupX + cupW - (10 * (1 - fillPercent))
        love.graphics.polygon("fill",
            fillX1, cupY + cupH - fillH,
            fillX2, cupY + cupH - fillH,
            cupX + cupW, cupY + cupH,
            cupX, cupY + cupH
        )

        -- Pour zones
        local zoneY = boxY + boxH - 90
        local zoneW = boxW - 80
        local zoneX = boxX + 40
        local zoneH = 30

        -- Background
        love.graphics.setColor(0.2, 0.2, 0.2)
        love.graphics.rectangle("fill", zoneX, zoneY, zoneW, zoneH, 4, 4)

        -- Perfect zone (70-85%)
        local perfectStart = zoneX + (zoneW * 0.70)
        local perfectWidth = zoneW * 0.15
        love.graphics.setColor(0.3, 0.8, 0.3, 0.6)
        love.graphics.rectangle("fill", perfectStart, zoneY, perfectWidth, zoneH, 4, 4)

        -- Good zone (60-95%)
        love.graphics.setColor(0.7, 0.7, 0.3, 0.3)
        love.graphics.rectangle("fill", zoneX + (zoneW * 0.60), zoneY, zoneW * 0.35, zoneH, 4, 4)

        -- Current fill marker
        local markerX = zoneX + (zoneW * fillPercent)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setLineWidth(3)
        love.graphics.line(markerX, zoneY, markerX, zoneY + zoneH)
        love.graphics.setLineWidth(1)

        -- Quality indicator
        if gameState.pourQuality ~= "none" then
            local qualityColor = {0.7, 0.7, 0.7}
            local qualityText = "OKAY"
            if gameState.pourQuality == "perfect" then
                qualityColor = {0.3, 1, 0.3}
                qualityText = "✨ PERFECT! ✨"
            elseif gameState.pourQuality == "good" then
                qualityColor = {0.8, 0.8, 0.3}
                qualityText = "GOOD"
            end

            love.graphics.setColor(qualityColor)
            love.graphics.setFont(UI.fonts.get(20))
            love.graphics.printf(qualityText, boxX, zoneY - 40, boxW, "center")
        end

        -- Confirm button (only show when pour is done) using UI theme
        if gameState.pourProgress > 50 then
            local btnW = 120
            local btnH = 40
            local btnX = boxX + boxW / 2 - btnW / 2
            local btnY = boxY + boxH - 50

            love.graphics.setColor(UI.theme.colors.success)
            love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, UI.theme.radius.md, UI.theme.radius.md)
            love.graphics.setColor(UI.theme.colors.text)
            love.graphics.setFont(UI.fonts.get(16))
            love.graphics.printf("Serve", btnX, btnY + 10, btnW, "center")

            buttons["serve_pour"] = {x = btnX, y = btnY, w = btnW, h = btnH}
        end

    elseif gameState.activeMinigame == "plate" then
        -- FOOD PLATING MINIGAME
        local boxW = 450
        local boxH = 500
        local boxX = screenW / 2 - boxW / 2
        local boxY = screenH / 2 - boxH / 2

        -- Background panel using UI theme
        love.graphics.setColor(UI.theme.colors.panel)
        love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, UI.theme.radius.lg, UI.theme.radius.lg)
        love.graphics.setColor(UI.theme.colors.primary)
        love.graphics.setLineWidth(UI.theme.border.thick)
        love.graphics.rectangle("line", boxX, boxY, boxW, boxH, UI.theme.radius.lg, UI.theme.radius.lg)
        love.graphics.setLineWidth(1)

        -- Title
        love.graphics.setColor(UI.theme.colors.textAccent)
        love.graphics.setFont(UI.fonts.get(24))
        love.graphics.printf("Plate " .. gameState.minigameItem.name, boxX, boxY + 20, boxW, "center")

        -- Instructions
        love.graphics.setColor(UI.theme.colors.text)
        love.graphics.setFont(UI.fonts.get(14))
        love.graphics.printf("Click SPACE when the green window appears! Do it 3 times!", boxX + 20, boxY + 60, boxW - 40, "center")

        -- Progress (3 steps)
        local stepW = 80
        local stepH = 80
        local stepSpacing = 30
        local totalW = (stepW * 3) + (stepSpacing * 2)
        local stepStartX = boxX + (boxW - totalW) / 2
        local stepY = boxY + 140

        for i = 1, 3 do
            local stepX = stepStartX + ((i - 1) * (stepW + stepSpacing))
            local completed = i <= gameState.platingStep
            local active = i == gameState.platingStep + 1

            if completed then
                -- Completed step - green
                love.graphics.setColor(0.3, 0.8, 0.3, 0.8)
                love.graphics.rectangle("fill", stepX, stepY, stepW, stepH, 8, 8)
                love.graphics.setColor(1, 1, 1)
                love.graphics.setFont(UI.fonts.get(32))
                love.graphics.printf("✓", stepX, stepY + 20, stepW, "center")
            elseif active then
                -- Active step - highlight
                love.graphics.setColor(0.7, 0.7, 0.3, 0.6)
                love.graphics.rectangle("fill", stepX, stepY, stepW, stepH, 8, 8)
                love.graphics.setColor(1, 1, 1)
                love.graphics.setFont(UI.fonts.get(20))
                love.graphics.printf("Step " .. i, stepX, stepY + 28, stepW, "center")
            else
                -- Pending step - gray
                love.graphics.setColor(0.3, 0.3, 0.3, 0.4)
                love.graphics.rectangle("fill", stepX, stepY, stepW, stepH, 8, 8)
                love.graphics.setColor(0.6, 0.6, 0.6)
                love.graphics.setFont(UI.fonts.get(20))
                love.graphics.printf("Step " .. i, stepX, stepY + 28, stepW, "center")
            end
        end

        -- Perfect timing window
        if gameState.platePerfectWindow then
            local windowW = 300
            local windowH = 100
            local windowX = boxX + (boxW - windowW) / 2
            local windowY = boxY + 280

            local urgency = gameState.platePerfectTimer / 0.8
            love.graphics.setColor(0.3, 1, 0.3, 0.9 - urgency * 0.3)
            love.graphics.rectangle("fill", windowX, windowY, windowW, windowH, 12, 12)

            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(UI.fonts.get(24))
            love.graphics.printf("✨ SPACE NOW! ✨", windowX, windowY + 35, windowW, "center")
        end

        -- Draw plate visual
        local plateX = boxX + boxW / 2 - 80
        local plateY = boxY + 320
        love.graphics.setColor(0.9, 0.9, 0.95, 0.8)
        love.graphics.ellipse("fill", plateX + 80, plateY + 20, 100, 15)
        love.graphics.setColor(0.7, 0.7, 0.75, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.ellipse("line", plateX + 80, plateY + 20, 100, 15)
        love.graphics.setLineWidth(1)

        -- Draw food on plate (based on steps completed)
        if gameState.platingStep > 0 then
            love.graphics.setColor(gameState.minigameItem.color)
            love.graphics.circle("fill", plateX + 60, plateY + 15, 20)
        end
        if gameState.platingStep > 1 then
            love.graphics.setColor(gameState.minigameItem.color)
            love.graphics.circle("fill", plateX + 100, plateY + 15, 20)
        end
        if gameState.platingStep > 2 then
            love.graphics.setColor(gameState.minigameItem.color)
            love.graphics.circle("fill", plateX + 80, plateY + 5, 20)
        end

        -- Quality indicator
        if gameState.platingStep >= 3 then
            -- All steps complete - show serve button
            local btnW = 120
            local btnH = 40
            local btnX = boxX + boxW / 2 - btnW / 2
            local btnY = boxY + boxH - 50

            love.graphics.setColor(UI.theme.colors.success)
            love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, UI.theme.radius.md, UI.theme.radius.md)
            love.graphics.setColor(UI.theme.colors.text)
            love.graphics.setFont(UI.fonts.get(16))
            love.graphics.printf("Serve", btnX, btnY + 10, btnW, "center")

            buttons["serve_plate"] = {x = btnX, y = btnY, w = btnW, h = btnH}

            -- Show quality
            love.graphics.setColor(UI.theme.colors.success)
            love.graphics.setFont(UI.fonts.get(18))
            love.graphics.printf("Plated!", boxX, boxY + 400, boxW, "center")
        end
    end

    -- Cancel button (ESC hint)
    love.graphics.setColor(0.8, 0.8, 0.8, 0.6)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.printf("Press ESC to cancel", 0, screenH - 30, screenW, "center")
end

function CafeGame.mousepressed(x, y, button)
    if button ~= 1 then return end

    -- Check minigame buttons first
    if gameState.activeMinigame then
        if buttons["serve_pour"] and isInside(x, y, buttons["serve_pour"]) then
            -- Complete pour and serve
            local customer = gameState.minigameCustomer
            local item = gameState.minigameItem

            -- Apply quality bonus to tips based on pour quality
            local qualityMultiplier = 1.0
            if gameState.pourQuality == "perfect" then
                qualityMultiplier = 1.5
            elseif gameState.pourQuality == "good" then
                qualityMultiplier = 1.2
            end

            -- Serve the item
            serveItemToCustomer(customer, item.id, false)

            -- Apply quality bonus to the customer's tip multiplier
            customer.tipMultiplier = customer.tipMultiplier * qualityMultiplier

            -- Close minigame
            gameState.activeMinigame = nil
            gameState.minigameItem = nil
            gameState.minigameCustomer = nil
            return
        elseif buttons["serve_plate"] and isInside(x, y, buttons["serve_plate"]) then
            -- Complete plating and serve
            local customer = gameState.minigameCustomer
            local item = gameState.minigameItem

            -- Apply quality bonus (perfect plating = all 3 steps perfect)
            local qualityMultiplier = 1.3  -- Default bonus for completing plating

            -- Serve the item
            serveItemToCustomer(customer, item.id, false)

            -- Apply quality bonus to the customer's tip multiplier
            customer.tipMultiplier = customer.tipMultiplier * qualityMultiplier

            -- Close minigame
            gameState.activeMinigame = nil
            gameState.minigameItem = nil
            gameState.minigameCustomer = nil
            return
        end
        -- Click outside minigame buttons does nothing
        return
    end

    -- Check pause menu first
    if showPauseMenu then
        if buttons["pause_resume"] and isInside(x, y, buttons["pause_resume"]) then
            showPauseMenu = false
            return
        end
        if buttons["pause_quit"] and isInside(x, y, buttons["pause_quit"]) then
            showPauseMenu = false
            PlayerData.coins = PlayerData.coins + (gameState.money - gameState.startMoney)
            gameState.startMoney = gameState.money
            saveUpgrades()
            local TextRPG = require("textrpg"); TextRPG.init(); GameState.current = "textrpg"
            return
        end
        -- Click outside menu does nothing (must use buttons)
        return
    end

    -- Check day summary buttons
    if gameState.showDaySummary then
        -- Upgrades shop view
        if gameState.showUpgrades then
            -- Back from upgrades
            if buttons["back_from_upgrades"] and isInside(x, y, buttons["back_from_upgrades"]) then
                gameState.showUpgrades = false
                return
            end

            -- Check upgrade purchases
            for id, btn in pairs(buttons) do
                if id:sub(1, 8) == "upgrade_" and isInside(x, y, btn) then
                    -- Re-verify affordability and max level at click time
                    local currentLevel = gameState.upgrades[btn.upgrade.id] or 0
                    local maxed = currentLevel >= btn.upgrade.maxLevel
                    local cost = math.floor(btn.upgrade.baseCost * (btn.upgrade.costMult ^ currentLevel))
                    local canAfford = gameState.money >= cost

                    if canAfford and not maxed then
                        gameState.money = gameState.money - cost
                        gameState.upgrades[btn.upgrade.id] = currentLevel + 1
                        -- Update tray size immediately if upgraded
                        if btn.upgrade.id == "traySize" then
                            gameState.maxTrayItems = 3 + gameState.upgrades.traySize
                        end
                        -- Save upgrades to PlayerData
                        saveUpgrades()
                    end
                    return
                end
            end
            return
        end

        -- Employee menu view
        if gameState.showEmployeeMenu then
            -- Back from employees
            if buttons["back_from_employees"] and isInside(x, y, buttons["back_from_employees"]) then
                gameState.showEmployeeMenu = false
                return
            end

            -- Check hire buttons
            for id, btn in pairs(buttons) do
                if id:sub(1, 5) == "hire_" and isInside(x, y, btn) then
                    -- Verify ownership at click time
                    if PlayerData.currentBuildingOwned ~= true then
                        return  -- Can't hire without owning the building
                    end
                    -- Re-verify affordability at click time
                    local canAfford = gameState.money >= btn.empType.hireCost
                    -- Check if already hired
                    local alreadyHired = false
                    for _, emp in ipairs(gameState.employees) do
                        if emp.id == btn.empType.id then
                            alreadyHired = true
                            break
                        end
                    end

                    if canAfford and not alreadyHired then
                        gameState.money = gameState.money - btn.empType.hireCost

                        -- Generate gender-matched name and portrait for employee
                        local empType = btn.empType
                        local gender, name, portrait

                        if empType.gender == "female" then
                            gender = "female"
                            name = employeeFemaleNames[math.random(#employeeFemaleNames)]
                            portrait = empType.femalePortraits[math.random(#empType.femalePortraits)]
                        elseif empType.gender == "male" then
                            gender = "male"
                            name = employeeMaleNames[math.random(#employeeMaleNames)]
                            portrait = empType.malePortraits[math.random(#empType.malePortraits)]
                        else  -- "any" gender
                            gender = math.random() < 0.5 and "male" or "female"
                            if gender == "male" and empType.malePortraits then
                                name = employeeMaleNames[math.random(#employeeMaleNames)]
                                portrait = empType.malePortraits[math.random(#empType.malePortraits)]
                            elseif empType.femalePortraits then
                                name = employeeFemaleNames[math.random(#employeeFemaleNames)]
                                portrait = empType.femalePortraits[math.random(#empType.femalePortraits)]
                            else
                                name = employeeMaleNames[math.random(#employeeMaleNames)]
                                portrait = "Human/Men_Human/Human_01"
                            end
                        end

                        table.insert(gameState.employees, {
                            id = empType.id,
                            name = name,
                            gender = gender,
                            portrait = portrait,
                            age = math.random(20, 50),
                        })
                        saveUpgrades()  -- This also saves employees
                    end
                    return
                end
            end

            -- Check fire buttons
            for id, btn in pairs(buttons) do
                if id:sub(1, 9) == "fire_emp_" and isInside(x, y, btn) then
                    -- Get employee id before removing
                    local firedEmpId = gameState.employees[btn.index] and gameState.employees[btn.index].id
                    -- Remove employee at index
                    table.remove(gameState.employees, btn.index)
                    -- Also remove any active actions for this employee
                    if firedEmpId then
                        for i = #gameState.employeeActions, 1, -1 do
                            if gameState.employeeActions[i].employeeId == firedEmpId then
                                table.remove(gameState.employeeActions, i)
                            end
                        end
                    end
                    saveUpgrades()
                    return
                end
            end
            return
        end

        -- Day stats view
        if buttons["next_day"] and isInside(x, y, buttons["next_day"]) then
            gameState.day = gameState.day + 1
            CafeGame.startNewDay()
            return
        end

        if buttons["show_upgrades"] and isInside(x, y, buttons["show_upgrades"]) then
            gameState.showUpgrades = true
            return
        end

        if buttons["show_employees"] and isInside(x, y, buttons["show_employees"]) then
            gameState.showEmployeeMenu = true
            return
        end

        if buttons["exit_cafe"] and isInside(x, y, buttons["exit_cafe"]) then
            -- Save money and upgrades to player data
            PlayerData.coins = PlayerData.coins + (gameState.money - gameState.startMoney)
            gameState.startMoney = gameState.money
            saveUpgrades()
            local TextRPG = require("textrpg"); TextRPG.init(); GameState.current = "textrpg"
            return
        end
        return
    end

    -- Check auto toggle button
    if buttons["auto_toggle"] and isInside(x, y, buttons["auto_toggle"]) then
        gameState.autoMode = not gameState.autoMode
        return
    end

    -- Check back button
    if buttons["back"] and isInside(x, y, buttons["back"]) then
        PlayerData.coins = PlayerData.coins + (gameState.money - gameState.startMoney)
        gameState.startMoney = gameState.money
        saveUpgrades()
        local TextRPG = require("textrpg"); TextRPG.init(); GameState.current = "textrpg"
        return
    end

    -- Check menu items (for preparation)
    for id, btn in pairs(buttons) do
        if id:sub(1, 5) == "item_" and isInside(x, y, btn) then
            -- Check if we're in auto mode (employees handle it) or manual mode (minigame)
            if gameState.autoMode or (gameState.upgrades.autoChef and gameState.upgrades.autoChef > 0) then
                -- Original auto-prep behavior
                local maxPrepping = 1 + (gameState.upgrades.multiPrep or 0)
                local currentPrepping = gameState.preparingItem and 1 or 0
                currentPrepping = currentPrepping + #gameState.preparingItems

                if currentPrepping < maxPrepping then
                    if not gameState.preparingItem then
                        gameState.preparingItem = btn.item
                        gameState.prepProgress = 0
                    else
                        table.insert(gameState.preparingItems, {item = btn.item, progress = 0})
                    end
                end
            else
                -- Manual interactive mode - start minigame
                local item = btn.item
                -- Find a customer who ordered this item
                local targetCustomer = nil
                for _, customer in ipairs(gameState.customers) do
                    for _, orderItem in ipairs(customer.order) do
                        if orderItem.item.id == item.id and not orderItem.served then
                            targetCustomer = customer
                            break
                        end
                    end
                    if targetCustomer then break end
                end

                if targetCustomer then
                    -- Start minigame
                    gameState.minigameItem = item
                    gameState.minigameCustomer = targetCustomer

                    if item.category == "drink" then
                        gameState.activeMinigame = "pour"
                        gameState.pourProgress = 0
                        gameState.pouringActive = false
                        gameState.selectedBottle = nil
                        gameState.pourQuality = "none"
                    elseif item.category == "food" then
                        gameState.activeMinigame = "plate"
                        gameState.platingStep = 0
                        gameState.plateProgress = 0
                        gameState.platingQuality = "none"
                        gameState.platePerfectWindow = false
                        gameState.platePerfectTimer = 0
                    end
                end
            end
            return
        end
    end

    -- Check tray items (for serving)
    for id, btn in pairs(buttons) do
        if id:sub(1, 5) == "tray_" and isInside(x, y, btn) then
            selectedItem = btn.item
            return
        end
    end

    -- Check customers (for serving)
    if selectedItem then
        for id, btn in pairs(buttons) do
            if id:sub(1, 9) == "customer_" and isInside(x, y, btn) then
                if serveCustomer(btn.customer, selectedItem.id) then
                    selectedItem = nil
                end
                return
            end
        end
    end
end

function isInside(x, y, btn)
    return x >= btn.x and x <= btn.x + btn.w and
           y >= btn.y and y <= btn.y + btn.h
end

function CafeGame.keypressed(key)
    -- Handle minigame controls first
    if gameState.activeMinigame then
        if key == "escape" then
            -- Cancel minigame
            gameState.activeMinigame = nil
            gameState.minigameItem = nil
            gameState.minigameCustomer = nil
            return
        elseif key == "space" then
            if gameState.activeMinigame == "pour" then
                -- Start/stop pouring
                gameState.pouringActive = true
            elseif gameState.activeMinigame == "plate" then
                -- Check for perfect timing on plating step
                if gameState.platingStep < 3 and gameState.platePerfectWindow then
                    -- Perfect click!
                    gameState.platingStep = gameState.platingStep + 1
                    gameState.platePerfectWindow = false
                    gameState.platePerfectTimer = 0
                    gameState.platingQuality = "perfect"
                elseif gameState.platingStep < 3 then
                    -- Missed the window, still advance but not perfect
                    gameState.platingStep = gameState.platingStep + 1
                    gameState.platingQuality = "okay"
                end
            end
        end
        return
    end

    if key == "escape" then
        if gameState.showDaySummary then
            -- In summary screen, ESC goes back to menu
            PlayerData.coins = PlayerData.coins + (gameState.money - gameState.startMoney)
            gameState.startMoney = gameState.money
            saveUpgrades()
            local TextRPG = require("textrpg"); TextRPG.init(); GameState.current = "textrpg"
        else
            -- During gameplay, toggle pause menu
            showPauseMenu = not showPauseMenu
        end
    end
end

function CafeGame.keyreleased(key)
    -- Handle pour release
    if gameState.activeMinigame == "pour" and key == "space" then
        gameState.pouringActive = false
    end
end

function CafeGame.wheelmoved(x, y)
    -- Handle scroll in upgrades menu
    if gameState.showUpgrades then
        gameState.upgradeScroll = gameState.upgradeScroll - y * 40
        -- Clamp scroll
        local itemH = 55
        local itemSpacing = 8
        local totalContentHeight = #upgradeDefinitions * (itemH + itemSpacing)
        local listH = 360  -- Matches the listH in drawUpgradesShop
        local maxScroll = math.max(0, totalContentHeight - listH)
        gameState.upgradeScroll = math.max(0, math.min(gameState.upgradeScroll, maxScroll))
    end

    -- Handle scroll in employees menu
    if gameState.showEmployeeMenu and gameState.employeeScrollArea then
        local mx, my = love.mouse.getPosition()
        local area = gameState.employeeScrollArea
        if mx >= area.x and mx <= area.x + area.w and my >= area.y and my <= area.y + area.h then
            gameState.employeeScroll = gameState.employeeScroll - y * 40
            -- Clamping is handled in drawEmployeeMenu
        end
    end
end

-- Get UI region for tutorial system
function CafeGame.getUIRegion(regionId)
    local screenW, screenH = love.graphics.getDimensions()

    local regions = {
        -- Customer queue/seating area (covers all customer positions)
        customer_area = {
            x = 50,
            y = screenH * 0.30 - 100,
            w = 700,
            h = 300
        },

        -- Menu panel (drinks and food items)
        menu_panel = {
            x = 30,
            y = screenH * 0.55 - 40,
            w = 900,
            h = 450
        },

        -- Serving tray area
        tray_area = {
            x = screenW - 330,
            y = screenH * 0.65 - 20,
            w = 300,
            h = 100
        },

        -- Time/shift progress display
        time_display = {
            x = screenW - 220,
            y = 20,
            w = 200,
            h = 20
        }
    }

    return regions[regionId]
end

return CafeGame
