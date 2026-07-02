-- Employees System - Hire and manage workers for crafting modes
-- Integrates with EntitySystem for aging, moods, diseases

local Employees = {}
local EntitySystem = require("entitysystem")

-- Font cache for performance
local FontCache = require("fontcache")
local function getFont(size)
    return FontCache.get(size)
end

-- Portrait paths for different professions
Employees.PORTRAITS = {
    male = {
        forge = {
            "assets/characters/Human/Men_Human/BoldWarrior.PNG",
            "assets/characters/Human/Men_Human/Human_01.PNG",
            "assets/characters/Human/Men_Human/Human_03_1.PNG",
            "assets/characters/Human/Men_Human/Human_04_1.PNG",
            "assets/characters/Human/Men_Human/Human_05_1.PNG",
            "assets/characters/Human/Men_Human/Footman.PNG",
        },
        wizardtower = {
            "assets/characters/Human/Men_Human/Human_06_Priest.PNG",
            "assets/characters/Human/Men_Human/Human_07_1.PNG",
            "assets/characters/Human/Men_Human/Human_08_1.PNG",
            "assets/characters/OldCultist.PNG",
            "assets/characters/scientist.PNG",
        },
        alchemist = {
            "assets/characters/Human/Men_Human/Human_09.PNG",
            "assets/characters/Human/Men_Human/Human_10.PNG",
            "assets/characters/scientist.PNG",
            "assets/characters/Gnome_01.PNG",
            "assets/characters/Gnome_02.PNG",
        },
        hunting = {
            "assets/characters/Human/Men_Human/Human_01_archer.PNG",
            "assets/characters/Human/Men_Human/Crossbowman.PNG",
            "assets/characters/Human/Men_Human/Human_11_1.PNG",
            "assets/characters/Human/Men_Human/Human_13_1.PNG",
        },
        fishing = {
            "assets/characters/Human/Men_Human/Human_14_1.PNG",
            "assets/characters/Human/Men_Human/Human_15_1.PNG",
            "assets/characters/Human/Men_Human/Homeless.PNG",
            "assets/characters/Gnome_03.PNG",
        },
        stock_market = {
            "assets/characters/Human/Men_Human/Human_07_1.PNG",
            "assets/characters/Human/Men_Human/Human_08_1.PNG",
            "assets/characters/Human/Men_Human/Human_09.PNG",
            "assets/characters/Human/Men_Human/Human_10.PNG",
            "assets/characters/Gnome_01.PNG",
        },
    },
    female = {
        forge = {
            "assets/characters/Human/Women_Human/Human_08_warrior.PNG",
            "assets/characters/Human/Women_Human/Human_05_woman_knight.PNG",
            "assets/characters/Human/Women_Human/Human_01_1.PNG",
            "assets/characters/Human/Women_Human/Human_02.PNG",
        },
        wizardtower = {
            "assets/characters/Human/Women_Human/FrostMage.PNG",
            "assets/characters/Human/Women_Human/Human_03.PNG",
            "assets/characters/Human/Women_Human/Human_04.PNG",
            "assets/characters/Human/Women_Human/Human_06.PNG",
            "assets/characters/Human/Women_Human/Cultist.PNG",
        },
        alchemist = {
            "assets/characters/Human/Women_Human/Human_07.PNG",
            "assets/characters/Human/Women_Human/Human_11.PNG",
            "assets/characters/Human/Women_Human/Human_12.PNG",
            "assets/characters/Human/Women_Human/Human_13.PNG",
        },
        hunting = {
            "assets/characters/Human/Women_Human/Archer_woman.PNG",
            "assets/characters/Human/Women_Human/Human_02_archer.PNG",
            "assets/characters/Human/Women_Human/Assassin.PNG",
            "assets/characters/Human/Women_Human/Human_15_woman.PNG",
        },
        fishing = {
            "assets/characters/Human/Women_Human/Human_14.PNG",
            "assets/characters/Human/Women_Human/Human_17.PNG",
            "assets/characters/Human/Women_Human/Human_07_girl.PNG",
            "assets/characters/Human/Women_Human/Human_16_girl.PNG",
        },
        stock_market = {
            "assets/characters/Human/Women_Human/Human_03.PNG",
            "assets/characters/Human/Women_Human/Human_04.PNG",
            "assets/characters/Human/Women_Human/Human_06.PNG",
            "assets/characters/Human/Women_Human/Human_11.PNG",
            "assets/characters/Human/Women_Human/Human_12.PNG",
        },
    },
}

-- Cached portrait images
local portraitCache = {}

-- Load portrait image
function Employees.loadPortrait(path)
    if not path then return nil end
    if portraitCache[path] then return portraitCache[path] end

    local success, img = pcall(function()
        return love.graphics.newImage(path)
    end)

    if success then
        portraitCache[path] = img
        return img
    end
    return nil
end

-- Get random portrait for employee
function Employees.getRandomPortrait(gender, mode)
    local genderPortraits = Employees.PORTRAITS[gender]
    if not genderPortraits then return nil end

    local modePortraits = genderPortraits[mode]
    if not modePortraits or #modePortraits == 0 then return nil end

    return modePortraits[math.random(#modePortraits)]
end

-- Employee types for different modes
Employees.TYPES = {
    -- Forge employees
    {id = "apprentice_smith", name = "Apprentice Smith", mode = "forge",
     baseCost = 100, dailyWage = 5, efficiency = 0.5, unlockLevel = 1,
     description = "Young and eager to learn the trade"},
    {id = "journeyman_smith", name = "Journeyman Smith", mode = "forge",
     baseCost = 500, dailyWage = 15, efficiency = 1.0, unlockLevel = 5,
     description = "Experienced with most forging techniques"},
    {id = "master_smith", name = "Master Smith", mode = "forge",
     baseCost = 2000, dailyWage = 50, efficiency = 2.0, unlockLevel = 10,
     description = "A true master of the craft"},

    -- Wizard tower employees
    {id = "apprentice_mage", name = "Apprentice Mage", mode = "wizardtower",
     baseCost = 150, dailyWage = 8, efficiency = 0.5, unlockLevel = 1,
     description = "Still learning the arcane arts"},
    {id = "journeyman_mage", name = "Journeyman Mage", mode = "wizardtower",
     baseCost = 600, dailyWage = 20, efficiency = 1.0, unlockLevel = 5,
     description = "Competent in spell weaving"},
    {id = "archmage", name = "Archmage", mode = "wizardtower",
     baseCost = 2500, dailyWage = 60, efficiency = 2.0, unlockLevel = 10,
     description = "A master of magical knowledge"},

    -- Alchemy employees
    {id = "apprentice_alchemist", name = "Apprentice Alchemist", mode = "alchemist",
     baseCost = 120, dailyWage = 6, efficiency = 0.5, unlockLevel = 1,
     description = "Learning to mix basic potions"},
    {id = "journeyman_alchemist", name = "Journeyman Alchemist", mode = "alchemist",
     baseCost = 550, dailyWage = 18, efficiency = 1.0, unlockLevel = 5,
     description = "Skilled in potion brewing"},
    {id = "master_alchemist", name = "Master Alchemist", mode = "alchemist",
     baseCost = 2200, dailyWage = 55, efficiency = 2.0, unlockLevel = 10,
     description = "Creates legendary elixirs"},

    -- Hunting employees
    {id = "novice_hunter", name = "Novice Hunter", mode = "hunting",
     baseCost = 80, dailyWage = 4, efficiency = 0.5, unlockLevel = 1,
     description = "Learning to track and hunt"},
    {id = "skilled_hunter", name = "Skilled Hunter", mode = "hunting",
     baseCost = 400, dailyWage = 12, efficiency = 1.0, unlockLevel = 3,
     description = "Experienced wilderness tracker"},
    {id = "master_hunter", name = "Master Hunter", mode = "hunting",
     baseCost = 1500, dailyWage = 40, efficiency = 2.0, unlockLevel = 8,
     description = "Can track any beast"},

    -- Fishing employees
    {id = "novice_fisher", name = "Novice Fisher", mode = "fishing",
     baseCost = 60, dailyWage = 3, efficiency = 0.5, unlockLevel = 1,
     description = "Learning to cast a line"},
    {id = "skilled_fisher", name = "Skilled Fisher", mode = "fishing",
     baseCost = 300, dailyWage = 10, efficiency = 1.0, unlockLevel = 3,
     description = "Knows the best fishing spots"},
    {id = "master_fisher", name = "Master Fisher", mode = "fishing",
     baseCost = 1200, dailyWage = 35, efficiency = 2.0, unlockLevel = 8,
     description = "Legendary catches every time"},

    -- Stock market employees
    {id = "apprentice_trader", name = "Apprentice Trader", mode = "stock_market",
     baseCost = 200, dailyWage = 10, efficiency = 0.5, unlockLevel = 1,
     description = "Learning the ways of the market"},
    {id = "market_analyst", name = "Market Analyst", mode = "stock_market",
     baseCost = 800, dailyWage = 25, efficiency = 1.0, unlockLevel = 5,
     description = "Predicts trends with reasonable accuracy"},
    {id = "master_broker", name = "Master Broker", mode = "stock_market",
     baseCost = 3000, dailyWage = 75, efficiency = 2.0, unlockLevel = 10,
     description = "Legendary trader with insider knowledge"},
}

-- Names for random employee generation
local FIRST_NAMES_MALE = {"John", "William", "James", "Thomas", "Robert", "Charles", "Henry", "George", "Edward", "Samuel", "Marcus", "Felix", "Lars", "Erik", "Bjorn"}
local FIRST_NAMES_FEMALE = {"Mary", "Elizabeth", "Sarah", "Anna", "Margaret", "Emma", "Clara", "Rose", "Alice", "Helen", "Ingrid", "Freya", "Astrid", "Elsa", "Greta"}
local LAST_NAMES = {"Smith", "Cooper", "Baker", "Miller", "Wright", "Taylor", "Walker", "Hill", "Wood", "Stone", "Ironhand", "Firebrand", "Frostwind", "Shadowmend", "Goldforge"}

-- Get employee type info
function Employees.getType(typeId)
    for _, t in ipairs(Employees.TYPES) do
        if t.id == typeId then
            return t
        end
    end
    return nil
end

-- Get available employee types for a mode
function Employees.getTypesForMode(mode, playerLevel)
    local available = {}
    for _, t in ipairs(Employees.TYPES) do
        if t.mode == mode and (playerLevel or 1) >= t.unlockLevel then
            table.insert(available, t)
        end
    end
    return available
end

-- Generate a random employee
function Employees.generateEmployee(typeId)
    local empType = Employees.getType(typeId)
    if not empType then return nil end

    -- Random gender and name
    local gender = math.random() < 0.5 and "male" or "female"
    local firstName = gender == "male" and
        FIRST_NAMES_MALE[math.random(#FIRST_NAMES_MALE)] or
        FIRST_NAMES_FEMALE[math.random(#FIRST_NAMES_FEMALE)]
    local lastName = LAST_NAMES[math.random(#LAST_NAMES)]
    local fullName = firstName .. " " .. lastName

    -- Random age based on profession level
    local minAge, maxAge = 18, 60
    if empType.id:find("master") or empType.id:find("archmage") then
        minAge, maxAge = 35, 70  -- Masters are older
    elseif empType.id:find("journeyman") or empType.id:find("skilled") then
        minAge, maxAge = 25, 50  -- Journeymen are mid-age
    else
        minAge, maxAge = 16, 35  -- Apprentices are young
    end
    local age = math.random(minAge, maxAge)

    -- Create entity with EntitySystem
    local entity = EntitySystem.createEntity("human", fullName, age)

    -- Add employee-specific fields
    entity.employeeType = typeId
    entity.gender = gender
    entity.mode = empType.mode
    entity.baseEfficiency = empType.efficiency
    entity.dailyWage = empType.dailyWage
    entity.profession = empType.name
    entity.professionDesc = empType.description

    -- Get random portrait for this gender and mode
    entity.portrait = Employees.getRandomPortrait(gender, empType.mode)

    -- Random stats variance (+/- 20%)
    entity.skillVariance = 0.8 + math.random() * 0.4

    -- Employee level based on type (apprentice = 1-3, journeyman = 4-7, master = 8-12)
    local baseLevel = 1
    if empType.id:find("master") or empType.id:find("archmage") then
        baseLevel = 8 + math.random(0, 4)  -- Level 8-12
    elseif empType.id:find("journeyman") or empType.id:find("skilled") then
        baseLevel = 4 + math.random(0, 3)  -- Level 4-7
    else
        baseLevel = 1 + math.random(0, 2)  -- Level 1-3
    end
    entity.level = baseLevel

    -- Hired status
    entity.isHired = false
    entity.hireDay = 0

    -- Work tracking
    entity.itemsCrafted = 0
    entity.resourcesGathered = 0
    entity.totalWagesPaid = 0
    entity.totalEarned = 0
    entity.craftProgress = 0

    return entity
end

-- Hire an employee
function Employees.hire(employee, playerCoins)
    local empType = Employees.getType(employee.employeeType)
    if not empType then return false, "Invalid employee type" end

    if playerCoins < empType.baseCost then
        return false, "Not enough gold to hire"
    end

    employee.isHired = true
    employee.hireDay = os.time()
    return true, empType.baseCost
end

-- Fire an employee
function Employees.fire(employee)
    if not employee.isHired then return false end
    employee.isHired = false
    return true
end

-- Calculate employee's actual efficiency (base * entity factors)
function Employees.getEfficiency(employee)
    -- Validate employee data
    if not employee then return 0.01 end

    local baseEff = (employee.baseEfficiency or 1) * (employee.skillVariance or 1)
    local entityEff = EntitySystem.calculateWorkEfficiency(employee) or 1
    local result = baseEff * entityEff

    -- Clamp to reasonable range (min 0.01 to prevent zero production, max 10.0 to prevent exploits)
    return math.max(0.01, math.min(10.0, result))
end

-- Calculate daily wages (modified by mood - happy workers expect more)
function Employees.getDailyWage(employee)
    local baseWage = employee.dailyWage or 0
    local mood = EntitySystem.getMood(employee.mood or "content")
    if not mood then mood = {workMult = 1.0} end

    -- Happy workers want more pay
    if mood.workMult and mood.workMult > 1 then
        baseWage = baseWage * (1 + (mood.workMult - 1) * 0.5)
    end

    return math.floor(baseWage)
end

-- Pay an employee
function Employees.payWage(employee, playerCoins)
    employee.happiness = employee.happiness or 50
    employee.totalWagesPaid = employee.totalWagesPaid or 0
    employee.daysWorked = employee.daysWorked or 0

    local wage = Employees.getDailyWage(employee)

    if playerCoins < wage then
        -- Can't pay - employee becomes unhappy
        employee.happiness = math.max(0, employee.happiness - 20)
        return false, 0, "Not enough gold"
    end

    employee.totalWagesPaid = employee.totalWagesPaid + wage
    employee.daysWorked = employee.daysWorked + 1
    employee.lastPaid = os.time()

    -- Getting paid makes them happier
    employee.happiness = math.min(100, employee.happiness + 5)

    return true, wage
end

-- Simulate work for passive income/crafting
function Employees.simulateWork(employee, dt, mode)
    if not employee.isHired or employee.isDead then return 0 end

    local efficiency = Employees.getEfficiency(employee)

    -- Different modes produce different outputs
    local production = 0

    if mode == "forge" or mode == "wizardtower" or mode == "alchemist" then
        -- Crafting modes: produce items over time
        production = dt * efficiency * 0.1 -- Items per second
    elseif mode == "hunting" then
        -- Hunting: gather pelts/meat
        production = dt * efficiency * 0.05
    elseif mode == "fishing" then
        -- Fishing: catch fish
        production = dt * efficiency * 0.08
    elseif mode == "stock_market" then
        -- Stock market: generate passive income from trades
        production = dt * efficiency * 0.15
    end

    -- Consume energy while working (0.5/sec = ~200 seconds of work from full energy)
    employee.energy = math.max(0, employee.energy - dt * 0.5)

    -- If out of energy, efficiency drops to 0
    if employee.energy <= 0 then
        production = 0
        employee.happiness = math.max(0, employee.happiness - dt)
    end

    return production
end

-- Update all employees for a new day
function Employees.updateDaily(employees, currentSeason)
    local deadEmployees = {}

    for i, emp in ipairs(employees) do
        if emp.isHired then
            -- Use EntitySystem to update aging, diseases, etc.
            EntitySystem.updateDaily(emp, currentSeason)

            if emp.isDead then
                table.insert(deadEmployees, i)
            end
        end
    end

    -- Remove dead employees (iterate backwards)
    for i = #deadEmployees, 1, -1 do
        table.remove(employees, deadEmployees[i])
    end

    return #deadEmployees -- Return number of deaths
end

-- Get available employees for hire (generate new ones)
function Employees.generateHiringPool(mode, count, playerLevel)
    local pool = {}
    local types = Employees.getTypesForMode(mode, playerLevel)

    if #types == 0 then return pool end

    for i = 1, (count or 3) do
        local empType = types[math.random(#types)]
        local employee = Employees.generateEmployee(empType.id)
        if employee then
            table.insert(pool, employee)
        end
    end

    return pool
end

-- Draw employee card (for hire/management UI)
function Employees.drawEmployeeCard(employee, x, y, width, height, isHovered, showHireButton)
    local empType = Employees.getType(employee.employeeType)
    local portraitSize = 60

    -- Card background
    love.graphics.setColor(isHovered and {0.25, 0.28, 0.32} or {0.18, 0.2, 0.25})
    love.graphics.rectangle("fill", x, y, width, height, 8, 8)

    -- Border with profession color
    local borderColor = {0.4, 0.45, 0.5}
    if empType then
        if empType.mode == "forge" then
            borderColor = {0.8, 0.5, 0.3}
        elseif empType.mode == "wizardtower" then
            borderColor = {0.5, 0.4, 0.8}
        elseif empType.mode == "alchemist" then
            borderColor = {0.4, 0.7, 0.4}
        elseif empType.mode == "hunting" then
            borderColor = {0.6, 0.5, 0.3}
        elseif empType.mode == "fishing" then
            borderColor = {0.3, 0.5, 0.8}
        elseif empType.mode == "stock_market" then
            borderColor = {0.2, 0.8, 0.4}
        end
    end
    love.graphics.setColor(borderColor)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, width, height, 8, 8)
    love.graphics.setLineWidth(1)

    -- Portrait
    local portraitX = x + 8
    local portraitY = y + 8
    love.graphics.setColor(0.12, 0.14, 0.18)
    love.graphics.rectangle("fill", portraitX, portraitY, portraitSize, portraitSize, 6, 6)

    if employee.portrait then
        local img = Employees.loadPortrait(employee.portrait)
        if img then
            love.graphics.setColor(1, 1, 1)
            local imgW, imgH = img:getDimensions()
            local scale = portraitSize / math.max(imgW, imgH)
            local offsetX = (portraitSize - imgW * scale) / 2
            local offsetY = (portraitSize - imgH * scale) / 2
            love.graphics.draw(img, portraitX + offsetX, portraitY + offsetY, 0, scale, scale)
        end
    else
        -- Placeholder
        love.graphics.setColor(0.3, 0.3, 0.35)
        love.graphics.printf("?", portraitX, portraitY + portraitSize/2 - 10, portraitSize, "center")
    end

    -- Portrait border
    love.graphics.setColor(borderColor[1] * 0.7, borderColor[2] * 0.7, borderColor[3] * 0.7)
    love.graphics.rectangle("line", portraitX, portraitY, portraitSize, portraitSize, 6, 6)

    -- Text area starts after portrait
    local textX = x + portraitSize + 18

    -- Name
    love.graphics.setColor(1, 0.95, 0.8)
    love.graphics.setFont(getFont(14))
    love.graphics.print(employee.name, textX, y + 8)

    -- Type/Role
    love.graphics.setColor(borderColor)
    love.graphics.setFont(getFont(11))
    love.graphics.print(empType and empType.name or "Worker", textX, y + 26)

    -- Age and gender
    love.graphics.setColor(0.6, 0.65, 0.7)
    love.graphics.setFont(getFont(10))
    local genderStr = employee.gender == "male" and "Male" or "Female"
    love.graphics.print("Age: " .. employee.age .. " | " .. genderStr, textX, y + 42)

    -- Efficiency rating (right side)
    local efficiency = Employees.getEfficiency(employee)
    local effColor = {0.4, 0.8, 0.4}
    if efficiency < 0.5 then
        effColor = {0.8, 0.4, 0.4}
    elseif efficiency < 0.8 then
        effColor = {0.8, 0.7, 0.3}
    end
    love.graphics.setColor(effColor)
    love.graphics.setFont(getFont(12))
    love.graphics.print(string.format("Eff: %.0f%%", efficiency * 100), x + width - 75, y + 8)

    -- Daily wage
    love.graphics.setColor(1, 0.9, 0.4)
    love.graphics.setFont(getFont(11))
    love.graphics.print(Employees.getDailyWage(employee) .. " g/day", x + width - 75, y + 26)

    -- Status bars below portrait
    if height >= 100 then
        EntitySystem.drawStatusBars(employee, x + 8, y + portraitSize + 14, width - 16)
    end

    -- Hire cost and button (if not hired)
    if not employee.isHired and empType and showHireButton ~= false then
        love.graphics.setColor(0.9, 0.7, 0.3)
        love.graphics.setFont(getFont(12))
        love.graphics.print("Hire: " .. empType.baseCost .. " gold", textX, y + height - 25)
    end

    -- If hired, show work stats
    if employee.isHired then
        love.graphics.setColor(0.5, 0.7, 0.5)
        love.graphics.setFont(getFont(10))
        love.graphics.print("Items: " .. (employee.itemsCrafted or 0) .. " | Earned: " .. (employee.totalEarned or 0) .. "g", textX, y + height - 20)
    end
end

-- Draw compact employee row (for lists)
function Employees.drawEmployeeRow(employee, x, y, width, height, isHovered)
    local empType = Employees.getType(employee.employeeType)
    local portraitSize = height - 8

    -- Row background
    love.graphics.setColor(isHovered and {0.25, 0.28, 0.32} or {0.15, 0.17, 0.22})
    love.graphics.rectangle("fill", x, y, width, height, 5, 5)

    -- Portrait
    local portraitX = x + 4
    local portraitY = y + 4
    if employee.portrait then
        local img = Employees.loadPortrait(employee.portrait)
        if img then
            love.graphics.setColor(1, 1, 1)
            local imgW, imgH = img:getDimensions()
            local scale = portraitSize / math.max(imgW, imgH)
            love.graphics.draw(img, portraitX, portraitY, 0, scale, scale)
        end
    else
        love.graphics.setColor(0.3, 0.3, 0.35)
        love.graphics.rectangle("fill", portraitX, portraitY, portraitSize, portraitSize, 4, 4)
    end

    -- Name and Level
    love.graphics.setColor(1, 0.95, 0.8)
    love.graphics.setFont(getFont(12))
    local empLevel = employee.level or 1
    love.graphics.print(employee.name .. " (Lv." .. empLevel .. ")", x + portraitSize + 12, y + 4)

    -- Profession and items crafted
    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(getFont(10))
    local itemsCrafted = employee.itemsCrafted or 0
    love.graphics.print((empType and empType.name or "Worker") .. " - " .. itemsCrafted .. " items", x + portraitSize + 12, y + 20)

    -- Last crafted item (if any)
    if employee.lastCraftedItem then
        -- Color based on rarity
        local rarityColors = {
            common = {0.7, 0.7, 0.7},
            uncommon = {0.3, 0.8, 0.3},
            rare = {0.3, 0.5, 0.9},
            epic = {0.7, 0.3, 0.9},
            legendary = {1.0, 0.8, 0.2},
        }
        local rarityColor = rarityColors[employee.lastCraftedRarity] or {0.7, 0.7, 0.7}
        love.graphics.setColor(rarityColor)
        love.graphics.print("Last: " .. employee.lastCraftedItem, x + portraitSize + 12, y + 34)
    else
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.print("Age " .. employee.age, x + portraitSize + 12, y + 34)
    end

    -- Craft progress bar (small)
    if employee.craftProgress and employee.craftProgress > 0 then
        local barX = x + portraitSize + 12
        local barY = y + 50
        local barW = 80
        local barH = 4
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", barX, barY, barW, barH, 2, 2)
        love.graphics.setColor(0.4, 0.7, 0.4)
        love.graphics.rectangle("fill", barX, barY, barW * math.min(1, employee.craftProgress), barH, 2, 2)
    end

    -- Efficiency (right side)
    local efficiency = Employees.getEfficiency(employee)
    local effColor = efficiency >= 0.8 and {0.4, 0.8, 0.4} or (efficiency >= 0.5 and {0.8, 0.7, 0.3} or {0.8, 0.4, 0.4})
    love.graphics.setColor(effColor)
    love.graphics.setFont(getFont(11))
    love.graphics.print(string.format("%.0f%% eff", efficiency * 100), x + width - 100, y + 10)

    -- Total earned (right side)
    local totalEarned = employee.totalEarned or 0
    love.graphics.setColor(1, 0.9, 0.3)
    love.graphics.setFont(getFont(9))
    love.graphics.print(string.format("%dg earned", totalEarned), x + width - 100, y + 28)

    return height
end

-- Save employees to data
function Employees.save(employees)
    local data = {}
    for _, emp in ipairs(employees) do
        table.insert(data, emp)
    end
    return data
end

-- Load employees from data
function Employees.load(data)
    if not data then return {} end
    return data
end

return Employees
