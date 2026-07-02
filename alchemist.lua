-- Alchemist Table - Brew potions and poisons!
-- A potion crafting minigame with mixing and brewing

local Alchemist = {}
local UI = require("ui")
local UIAssets = require("uiassets")
local Backpack = require("backpack")
local CraftingCore = require("craftingcore")
local Progression = require("progression")
local Employees = require("employees")
local EmployeeUI = require("employee_ui")
local UpgradeSystem = require("upgradesystem")
local Tutorials = require("tutorials")
local InteractiveTutorial = require("interactivetutorial")

-- Use UI library fonts
local function getFont(size)
    return UI.fonts.get(size)
end

-- Game state
local state = {
    active = false,
    currentRecipe = nil,
    craftingProgress = 0,
    brewTemperature = 50,  -- Minigame: keep temperature stable
    craftedItem = nil,
    showOutput = false,
    selectedRecipeIndex = 1,
    scrollOffset = 0,
    notification = nil,
    notificationTimer = 0,
    bubbles = {},          -- Visual bubbles in the cauldron

    -- NEW: Interactive brewing phases
    brewPhase = "idle",    -- "idle", "prep", "pour", "heat", "distill", "complete"

    -- Prep phase (chopping)
    chopProgress = 0,
    chopTarget = 100,
    chopStreak = 0,
    lastChopTime = 0,
    chopParticles = {},
    ingredientsPrepared = {},
    currentPrepIndex = 1,

    -- Pour phase
    pourProgress = 0,
    pourTarget = 75,       -- Ideal fill level (70-80 is perfect)
    pouringActive = false,
    pourQuality = "none",  -- "perfect", "good", "okay", "overfill"
    pourSpeed = 40,        -- How fast liquid pours
    liquidColor = {0.4, 0.8, 0.4},
    pourSplashes = {},

    -- Heat phase (bellows)
    bellowsHeat = 50,      -- Current heat (0-100)
    bellowsTarget = 65,    -- Optimal heat zone (60-70)
    bellowsPumping = false,
    bellowsAngle = 0,      -- Visual angle for bellows animation
    heatTimer = 0,
    heatProgress = 0,      -- Progress towards completion
    heatRequired = 5,      -- Seconds of good heat needed
    flames = {},
    smoke = {},

    -- Distill phase (crank wheel)
    crankAngle = 0,
    crankSpeed = 0,
    crankingActive = false,
    distillProgress = 0,
    distillTarget = 100,
    distillType = "potion", -- "potion" or "powder"
    drips = {},
    steamParticles = {},

    -- Quality tracking
    totalQuality = 0,
    qualityChecks = 0,

    -- Employee system
    employees = {},           -- Hired employees
    hiringPool = {},          -- Available employees to hire
    showEmployeePanel = false,
    -- Employee production tracked per-employee via emp.craftProgress

    -- Upgrade system
    upgrades = {},            -- {upgradeId = level}
    showUpgradePanel = false,

    -- Time tracking
    lastSaveTime = 0,

    -- UI buttons for click detection
    buttons = {},

    -- UI Components
    uiRecipeList = nil,
    uiRecipePanel = nil,
    uiStatsPanel = nil,
    uiBrewButton = nil,
    uiEmployeePanel = nil,
    uiPrepProgressBar = nil,
    uiChopButton = nil,
    uiPourButton = nil,
    uiPourDoneButton = nil,
    uiPumpButton = nil,
    uiCrankButton = nil,
}

-- Alchemy recipes
local RECIPES = {
    -- Health & Mana Potions
    {
        id = "health_potion_crafted", name = "Health Potion", category = "potion",
        materials = {{id = "healing_herb", qty = 3}, {id = "empty_vial", qty = 1}},
        goldCost = 15, craftTime = 4, skillRequired = 0,
        baseStats = {healing = 50},
        icon = "assets/icons/loot/PotionRed.png",
    },
    {
        id = "mana_potion_crafted", name = "Mana Potion", category = "potion",
        materials = {{id = "moonflower", qty = 2}, {id = "empty_vial", qty = 1}},
        goldCost = 20, craftTime = 4, skillRequired = 0,
        baseStats = {manaRestore = 30},
        icon = "assets/icons/loot/PotionBlue.png",
    },
    {
        id = "greater_health", name = "Greater Health Potion", category = "potion",
        materials = {{id = "healing_herb", qty = 5}, {id = "troll_blood", qty = 1}, {id = "empty_vial", qty = 1}},
        goldCost = 50, craftTime = 6, skillRequired = 5,
        baseStats = {healing = 100},
        icon = "assets/icons/loot/PotionRed.png",
    },

    -- Buff Potions
    {
        id = "strength_potion", name = "Strength Potion", category = "potion",
        materials = {{id = "troll_blood", qty = 2}, {id = "healing_herb", qty = 1}, {id = "empty_vial", qty = 1}},
        goldCost = 35, craftTime = 5, skillRequired = 3,
        baseStats = {bonusDamage = 10, duration = 60},
        icon = "assets/icons/loot/PotionOrange.png",
    },
    {
        id = "speed_potion", name = "Speed Potion", category = "potion",
        materials = {{id = "moonflower", qty = 3}, {id = "empty_vial", qty = 1}},
        goldCost = 30, craftTime = 4, skillRequired = 2,
        baseStats = {bonusSpeed = 25, duration = 45},
        icon = "assets/icons/loot/PotionYellow.png",
    },
    {
        id = "defense_potion", name = "Iron Skin Potion", category = "potion",
        materials = {{id = "troll_blood", qty = 2}, {id = "moonflower", qty = 1}, {id = "empty_vial", qty = 1}},
        goldCost = 40, craftTime = 5, skillRequired = 4,
        baseStats = {bonusDefense = 15, duration = 60},
        icon = "assets/icons/loot/PotionGray.png",
    },
    {
        id = "regen_potion", name = "Regeneration Potion", category = "potion",
        materials = {{id = "troll_blood", qty = 3}, {id = "healing_herb", qty = 2}, {id = "empty_vial", qty = 1}},
        goldCost = 55, craftTime = 7, skillRequired = 6,
        baseStats = {healPerSecond = 3, duration = 30},
        icon = "assets/icons/loot/PotionPink.png",
    },

    -- Advanced Potions
    {
        id = "phoenix_elixir", name = "Phoenix Elixir", category = "potion",
        materials = {{id = "phoenix_feather", qty = 1}, {id = "troll_blood", qty = 2}, {id = "moonflower", qty = 2}, {id = "empty_vial", qty = 1}},
        goldCost = 200, craftTime = 12, skillRequired = 15,
        baseStats = {reviveHealth = 50, fireImmunity = 30},
        icon = "assets/icons/loot/PotionRed.png",
    },
    {
        id = "invisibility_potion", name = "Invisibility Potion", category = "potion",
        materials = {{id = "moonflower", qty = 5}, {id = "venom_sac", qty = 1}, {id = "empty_vial", qty = 1}},
        goldCost = 80, craftTime = 8, skillRequired = 10,
        baseStats = {invisible = true, duration = 20},
        icon = "assets/icons/loot/PotionWhite.png",
    },

    -- Poisons
    {
        id = "weak_poison", name = "Weak Poison", category = "poison",
        materials = {{id = "venom_sac", qty = 2}, {id = "empty_vial", qty = 1}},
        goldCost = 20, craftTime = 3, skillRequired = 0,
        baseStats = {dotDamage = 3, duration = 10},
        icon = "assets/icons/loot/PotionGreen.png",
    },
    {
        id = "paralyze_poison", name = "Paralyzing Poison", category = "poison",
        materials = {{id = "venom_sac", qty = 3}, {id = "moonflower", qty = 2}, {id = "empty_vial", qty = 1}},
        goldCost = 55, craftTime = 6, skillRequired = 5,
        baseStats = {stunChance = 30, duration = 5},
        icon = "assets/icons/loot/PotionPurple.png",
    },
    {
        id = "deadly_poison", name = "Deadly Poison", category = "poison",
        materials = {{id = "venom_sac", qty = 5}, {id = "troll_blood", qty = 1}, {id = "empty_vial", qty = 1}},
        goldCost = 70, craftTime = 8, skillRequired = 8,
        baseStats = {dotDamage = 8, duration = 15},
        icon = "assets/icons/loot/PotionBlack.png",
    },
    {
        id = "assassin_poison", name = "Assassin's Bane", category = "poison",
        materials = {{id = "venom_sac", qty = 5}, {id = "phoenix_feather", qty = 1}, {id = "troll_blood", qty = 2}, {id = "empty_vial", qty = 1}},
        goldCost = 150, craftTime = 10, skillRequired = 12,
        baseStats = {dotDamage = 15, critBonus = 25, duration = 20},
        icon = "assets/icons/loot/PotionBlack.png",
    },
}

-- Initialize UI components
local function initializeUIComponents()
    local screenW, screenH = love.graphics.getDimensions()

    -- Recipe list (left side)
    local recipeX = 10
    local recipeY = 150
    local recipeW = 220
    local recipeH = screenH - 200

    state.uiRecipeList = UI.List.new({
        x = recipeX,
        y = recipeY + 30,
        w = recipeW,
        h = recipeH - 40,
        items = RECIPES,
        selectedIndex = state.selectedRecipeIndex,
        onSelect = function(recipe, index)
            state.selectedRecipeIndex = index
        end,
        renderItem = function(recipe, x, y, w, h, isSelected)
            local catColors = {potion = {0.4, 0.8, 0.5}, poison = {0.7, 0.3, 0.7}}
            love.graphics.setColor(catColors[recipe.category] or {0.7, 0.8, 0.7})
            love.graphics.setFont(getFont(12))
            love.graphics.print(recipe.name, x, y + 5)

            local canCraft = Alchemist.canCraft(recipe)
            love.graphics.setColor(canCraft and {0.3, 0.6, 0.3} or {0.6, 0.3, 0.3})
            love.graphics.print("Lv" .. (recipe.skillRequired or 0), x + w - 50, y + 8)
        end
    })
    state.uiRecipeList.itemHeight = 35

    -- Brew button (will be positioned in draw)
    state.uiBrewButton = UI.Button.new({
        x = 0, y = 0, w = 0, h = 40,
        text = "BREW",
        variant = "success",
        onClick = function()
            if state.currentRecipe then return end
            local selectedRecipe = RECIPES[state.selectedRecipeIndex]
            if selectedRecipe then
                Alchemist.startCraft(selectedRecipe)
            end
        end
    })

    -- Chop button (prep phase)
    state.uiChopButton = UI.Button.new({
        x = 0, y = 0, w = 120, h = 100,
        text = "CHOP!",
        variant = "success",
        onClick = function()
            Alchemist.doChop()
        end
    })

    -- Pour button (pour phase)
    state.uiPourButton = UI.Button.new({
        x = 0, y = 0, w = 120, h = 80,
        text = "HOLD TO POUR",
        variant = "primary",
        onClick = function()
            state.pouringActive = true
        end
    })

    -- Pour done button (pour phase)
    state.uiPourDoneButton = UI.Button.new({
        x = 0, y = 0, w = 120, h = 40,
        text = "DONE",
        variant = "success",
        onClick = function()
            Alchemist.advancePhase()
        end
    })

    -- Pump button (heat phase)
    state.uiPumpButton = UI.Button.new({
        x = 0, y = 0, w = 120, h = 80,
        text = "PUMP!",
        variant = "primary",
        onClick = function()
            state.bellowsPumping = true
        end
    })

    -- Crank button (distill phase)
    state.uiCrankButton = UI.Button.new({
        x = 0, y = 0, w = 120, h = 80,
        text = "CRANK!",
        variant = "primary",
        onClick = function()
            Alchemist.doCrank()
        end
    })

    -- Prep progress bar
    state.uiPrepProgressBar = UI.ProgressBar.new({
        x = 0, y = 0, w = 200, h = 25,
        value = 0,
        colorOverride = {0.4, 0.8, 0.4}
    })
end

-- Initialize alchemist
function Alchemist.init()
    state.active = true
    state.craftingProgress = 0
    state.brewTemperature = 50
    state.currentRecipe = nil
    state.brewPhase = "idle"
    state.craftedItem = nil
    state.showOutput = false
    state.selectedRecipeIndex = 1
    state.scrollOffset = 0
    state.bubbles = {}
    state.showEmployeePanel = false
    state.showUpgradePanel = false
    Backpack.init()

    -- Load saved data
    Alchemist.loadSaveData()

    -- Generate initial hiring pool if empty
    if #state.hiringPool == 0 then
        state.hiringPool = Employees.generateHiringPool("alchemist", 3, Alchemist.getSkillLevel())
    end

    -- Calculate initial passive income rate
    Alchemist.updatePassiveIncomeRate()

    -- Initialize UI components
    initializeUIComponents()

    -- Register UI region resolver for interactive tutorials
    InteractiveTutorial.registerRegionResolver("alchemist", Alchemist.getUIRegion)

    -- Start tutorial if not completed
    if not Tutorials.hasCompleted("alchemist") then
        Tutorials.startTutorial("alchemist")
    end
end

-- Load saved alchemist data
function Alchemist.loadSaveData()
    if PlayerData.alchemistData then
        state.employees = Employees.load(PlayerData.alchemistData.employees)
        state.upgrades = UpgradeSystem.load(PlayerData.alchemistData.upgrades)
    else
        state.employees = {}
        state.upgrades = {}
    end
end

-- Save alchemist data
function Alchemist.saveData()
    PlayerData.alchemistData = {
        employees = Employees.save(state.employees),
        upgrades = UpgradeSystem.save(state.upgrades),
    }
    savePlayerData()
end

-- Calculate and update passive income from alchemist employees
function Alchemist.updatePassiveIncomeRate()
    local effects = UpgradeSystem.getCombinedEffects("alchemist", state.upgrades)
    local totalRate = 0

    -- Calculate income from all hired employees
    for _, emp in ipairs(state.employees) do
        if emp.isHired and not emp.isDead then
            local efficiency = Employees.getEfficiency(emp)
            -- Base rate: efficiency * 0.1 gold per second
            local empRate = efficiency * 0.1
            -- Apply quality bonus from upgrades
            empRate = empRate * (1 + (effects.qualityBonus or 0) * 0.01)
            totalRate = totalRate + empRate
        end
    end

    -- Use global helper to update passive income
    updatePassiveIncomeSource("alchemist", totalRate)
end

-- Update alchemist game
function Alchemist.update(dt)
    if not state.active then return end

    -- Update tutorial
    Tutorials.update(dt)

    -- Update notification timer
    if state.notification then
        state.notificationTimer = state.notificationTimer - dt
        if state.notificationTimer <= 0 then
            state.notification = nil
        end
    end

    local screenW, screenH = love.graphics.getDimensions()

    -- Update based on current brew phase
    if state.brewPhase == "prep" then
        -- Chopping phase - particles decay
        for i = #state.chopParticles, 1, -1 do
            local p = state.chopParticles[i]
            p.life = p.life - dt
            p.y = p.y + p.vy * dt
            p.vy = p.vy + 200 * dt  -- Gravity
            p.x = p.x + p.vx * dt
            if p.life <= 0 then
                table.remove(state.chopParticles, i)
            end
        end

        -- Chop streak decays if not chopping
        if love.timer.getTime() - state.lastChopTime > 0.5 then
            state.chopStreak = math.max(0, state.chopStreak - dt * 20)
        end

    elseif state.brewPhase == "pour" then
        -- Pour phase - fill cauldron
        if state.pouringActive then
            state.pourProgress = state.pourProgress + state.pourSpeed * dt

            -- Determine quality
            if state.pourProgress >= 70 and state.pourProgress <= 80 then
                state.pourQuality = "perfect"
            elseif state.pourProgress >= 60 and state.pourProgress <= 90 then
                state.pourQuality = "good"
            elseif state.pourProgress > 100 then
                state.pourQuality = "overfill"
            else
                state.pourQuality = "okay"
            end

            -- Add splashes
            if math.random() < dt * 15 then
                table.insert(state.pourSplashes, {
                    x = screenW / 2 + math.random(-30, 30),
                    y = screenH - 180 + (state.pourProgress / 100) * 60,
                    life = 0.5,
                    size = math.random(2, 5),
                })
            end
        end

        -- Update splashes
        for i = #state.pourSplashes, 1, -1 do
            local s = state.pourSplashes[i]
            s.life = s.life - dt
            s.y = s.y - dt * 30
            if s.life <= 0 then
                table.remove(state.pourSplashes, i)
            end
        end

    elseif state.brewPhase == "heat" then
        -- Heat phase - bellows control
        -- Heat naturally decreases
        state.bellowsHeat = math.max(0, state.bellowsHeat - dt * 8)

        -- Pumping bellows increases heat
        if state.bellowsPumping then
            state.bellowsHeat = math.min(100, state.bellowsHeat + dt * 35)
            state.bellowsAngle = math.sin(love.timer.getTime() * 10) * 15
        else
            state.bellowsAngle = state.bellowsAngle * 0.9  -- Return to rest
        end

        -- Check if heat is in optimal range (60-70)
        if state.bellowsHeat >= 55 and state.bellowsHeat <= 75 then
            state.heatProgress = state.heatProgress + dt
            state.heatTimer = state.heatTimer + dt

            -- Track quality
            if state.bellowsHeat >= 60 and state.bellowsHeat <= 70 then
                state.totalQuality = state.totalQuality + 1
            else
                state.totalQuality = state.totalQuality + 0.7
            end
            state.qualityChecks = state.qualityChecks + 1
        end

        -- Complete heat phase
        if state.heatProgress >= state.heatRequired then
            Alchemist.advancePhase()
        end

        -- Update flames
        if state.bellowsHeat > 30 then
            if math.random() < dt * (state.bellowsHeat / 10) then
                table.insert(state.flames, {
                    x = screenW / 2 + math.random(-40, 40),
                    y = screenH - 120,
                    life = 0.8,
                    size = math.random(8, 20) * (state.bellowsHeat / 100),
                    vx = math.random(-20, 20),
                })
            end
        end

        for i = #state.flames, 1, -1 do
            local f = state.flames[i]
            f.life = f.life - dt
            f.y = f.y - dt * 80
            f.x = f.x + f.vx * dt
            f.size = f.size * 0.98
            if f.life <= 0 then
                table.remove(state.flames, i)
            end
        end

        -- Update smoke
        if state.bellowsHeat > 50 and math.random() < dt * 3 then
            table.insert(state.smoke, {
                x = screenW / 2 + math.random(-30, 30),
                y = screenH - 200,
                life = 2,
                size = math.random(10, 25),
            })
        end

        for i = #state.smoke, 1, -1 do
            local s = state.smoke[i]
            s.life = s.life - dt
            s.y = s.y - dt * 40
            s.x = s.x + math.sin(love.timer.getTime() + s.size) * dt * 15
            if s.life <= 0 then
                table.remove(state.smoke, i)
            end
        end

    elseif state.brewPhase == "distill" then
        -- Distill phase - crank wheel
        -- Crank speed decays
        state.crankSpeed = math.max(0, state.crankSpeed - dt * 30)

        -- Update crank angle
        state.crankAngle = state.crankAngle + state.crankSpeed * dt

        -- Progress based on crank speed (optimal at 40-60)
        if state.crankSpeed >= 30 and state.crankSpeed <= 70 then
            local efficiency = 1 - math.abs(state.crankSpeed - 50) / 50
            state.distillProgress = state.distillProgress + dt * 25 * (0.5 + efficiency * 0.5)

            -- Track quality
            if state.crankSpeed >= 40 and state.crankSpeed <= 60 then
                state.totalQuality = state.totalQuality + 1
            else
                state.totalQuality = state.totalQuality + 0.6
            end
            state.qualityChecks = state.qualityChecks + 1
        end

        -- Determine output type based on crank speed history
        -- Slow cranking = powder, fast cranking = liquid potion
        if state.crankSpeed < 35 then
            state.distillType = "powder"
        else
            state.distillType = "potion"
        end

        -- Complete distill phase
        if state.distillProgress >= state.distillTarget then
            Alchemist.completeCraft()
        end

        -- Add drips when distilling
        if state.crankSpeed > 20 and math.random() < dt * 5 then
            table.insert(state.drips, {
                x = screenW / 2 + 100,
                y = screenH - 250,
                life = 1,
                vy = 0,
            })
        end

        for i = #state.drips, 1, -1 do
            local d = state.drips[i]
            d.life = d.life - dt
            d.vy = d.vy + 200 * dt
            d.y = d.y + d.vy * dt
            if d.life <= 0 or d.y > screenH then
                table.remove(state.drips, i)
            end
        end

        -- Steam particles
        if state.crankSpeed > 30 and math.random() < dt * 8 then
            table.insert(state.steamParticles, {
                x = screenW / 2 + 80 + math.random(-10, 10),
                y = screenH - 280,
                life = 1.5,
                size = math.random(5, 12),
            })
        end

        for i = #state.steamParticles, 1, -1 do
            local s = state.steamParticles[i]
            s.life = s.life - dt
            s.y = s.y - dt * 50
            s.x = s.x + math.sin(love.timer.getTime() * 3 + s.size) * dt * 20
            if s.life <= 0 then
                table.remove(state.steamParticles, i)
            end
        end
    end

    -- Update bubbles (always active when brewing)
    if state.brewPhase ~= "idle" then
        for i = #state.bubbles, 1, -1 do
            local b = state.bubbles[i]
            b.life = b.life - dt
            b.y = b.y - dt * 20
            b.x = b.x + math.sin(love.timer.getTime() * 5 + b.offset) * dt * 10
            if b.life <= 0 then
                table.remove(state.bubbles, i)
            end
        end

        -- Spawn bubbles
        if math.random() < dt * 3 then
            table.insert(state.bubbles, {
                x = screenW / 2 + math.random(-40, 40),
                y = screenH - 100,
                life = 1.5,
                size = math.random(3, 8),
                offset = math.random() * 10,
            })
        end
    end

    -- Employee production (per-employee accumulators for fair attribution)
    for _, emp in ipairs(state.employees) do
        if emp.isHired and not emp.isDead then
            local efficiency = Employees.getEfficiency(emp)
            emp.craftProgress = (emp.craftProgress or 0) + (efficiency * 0.1 * dt)

            -- When this employee produces enough, auto-brew basic items
            if emp.craftProgress >= 1.0 then
                emp.craftProgress = emp.craftProgress - 1.0
                local goldEarned = math.floor(10 * efficiency)
                PlayerData.coins = PlayerData.coins + goldEarned
                emp.totalEarned = (emp.totalEarned or 0) + goldEarned
                emp.itemsCrafted = (emp.itemsCrafted or 0) + 1
            end
        end
    end

    -- Auto-save periodically
    state.lastSaveTime = state.lastSaveTime + dt
    if state.lastSaveTime >= 30 then
        Alchemist.saveData()
        state.lastSaveTime = 0
    end

    -- Update UI components
    if state.uiRecipeList then
        state.uiRecipeList.selectedIndex = state.selectedRecipeIndex
        state.uiRecipeList:update(dt)
    end
    if state.uiBrewButton then
        state.uiBrewButton:update(dt)
    end
    if state.uiChopButton then
        state.uiChopButton:update(dt)
    end
    if state.uiPourButton then
        state.uiPourButton:update(dt)
    end
    if state.uiPourDoneButton then
        state.uiPourDoneButton:update(dt)
    end
    if state.uiPumpButton then
        state.uiPumpButton:update(dt)
    end
    if state.uiCrankButton then
        state.uiCrankButton:update(dt)
    end
    if state.uiPrepProgressBar then
        state.uiPrepProgressBar.value = state.chopProgress / state.chopTarget
        state.uiPrepProgressBar:update(dt)
    end
end

-- Advance to next brewing phase
function Alchemist.advancePhase()
    if state.brewPhase == "prep" then
        state.brewPhase = "pour"
        state.pourProgress = 0
        state.pourQuality = "none"
        state.notification = "Pour the mixture into the cauldron!"
        state.notificationTimer = 2
    elseif state.brewPhase == "pour" then
        -- Record pour quality
        if state.pourQuality == "perfect" then
            state.totalQuality = state.totalQuality + 100
        elseif state.pourQuality == "good" then
            state.totalQuality = state.totalQuality + 75
        else
            state.totalQuality = state.totalQuality + 50
        end
        state.qualityChecks = state.qualityChecks + 1

        state.brewPhase = "heat"
        state.bellowsHeat = 30
        state.heatProgress = 0
        state.notification = "Pump the bellows to heat! Keep it in the green zone!"
        state.notificationTimer = 2.5
    elseif state.brewPhase == "heat" then
        state.brewPhase = "distill"
        state.distillProgress = 0
        state.crankSpeed = 0
        state.notification = "Crank the wheel to distill! Steady pace for potions!"
        state.notificationTimer = 2.5
    end
end

-- Perform a chop action
function Alchemist.doChop()
    if state.brewPhase ~= "prep" then return end

    local now = love.timer.getTime()
    local timeSinceLastChop = now - state.lastChopTime

    -- Bonus for rhythm
    if timeSinceLastChop > 0.1 and timeSinceLastChop < 0.4 then
        state.chopStreak = math.min(100, state.chopStreak + 15)
    else
        state.chopStreak = math.max(0, state.chopStreak - 5)
    end

    state.lastChopTime = now

    -- Progress based on streak
    local chopPower = 5 + (state.chopStreak / 100) * 10
    state.chopProgress = math.min(state.chopTarget, state.chopProgress + chopPower)

    -- Spawn particles
    local screenW, screenH = love.graphics.getDimensions()
    for i = 1, 3 do
        table.insert(state.chopParticles, {
            x = screenW / 2 - 150 + math.random(-20, 20),
            y = screenH / 2 + math.random(-10, 10),
            vx = math.random(-100, 100),
            vy = math.random(-150, -50),
            life = 0.8,
            size = math.random(3, 6),
            color = {0.4 + math.random() * 0.3, 0.7 + math.random() * 0.2, 0.3},
        })
    end

    -- Check if prep is complete
    if state.chopProgress >= state.chopTarget then
        table.insert(state.ingredientsPrepared, state.currentPrepIndex)
        state.currentPrepIndex = state.currentPrepIndex + 1

        -- Check if all ingredients are prepped
        if state.currentPrepIndex > #state.currentRecipe.materials then
            Alchemist.advancePhase()
        else
            state.chopProgress = 0
            state.chopStreak = 0
            state.notification = "Ingredient prepared! Chop the next one!"
            state.notificationTimer = 1.5
        end
    end
end

-- Pump bellows
function Alchemist.pumpBellows()
    if state.brewPhase ~= "heat" then return end
    state.bellowsHeat = math.min(100, state.bellowsHeat + 8)
end

-- Crank the wheel
function Alchemist.doCrank()
    if state.brewPhase ~= "distill" then return end
    state.crankSpeed = math.min(100, state.crankSpeed + 12)
end

-- Heat up (minigame action)
function Alchemist.heatUp()
    state.brewTemperature = math.min(100, state.brewTemperature + 10)
end

-- Cool down (minigame action)
function Alchemist.coolDown()
    state.brewTemperature = math.max(0, state.brewTemperature - 10)
end

-- Get current skill level
function Alchemist.getSkillLevel()
    return CraftingCore.getSkillLevel("alchemy")
end

-- Check if player can craft a recipe
function Alchemist.canCraft(recipe)
    return CraftingCore.canCraft(recipe, Alchemist.getSkillLevel())
end

-- Start crafting a recipe
function Alchemist.startCraft(recipe)
    local canCraft, reason = Alchemist.canCraft(recipe)
    if canCraft then
        CraftingCore.consumeMaterials(recipe)
        state.currentRecipe = recipe
        state.craftingProgress = 0
        state.showOutput = false

        -- Initialize new brewing system
        state.brewPhase = "prep"
        state.chopProgress = 0
        state.chopStreak = 0
        state.chopParticles = {}
        state.ingredientsPrepared = {}
        state.currentPrepIndex = 1
        state.pourProgress = 0
        state.pourQuality = "none"
        state.pourSplashes = {}
        state.bellowsHeat = 30
        state.heatProgress = 0
        state.flames = {}
        state.smoke = {}
        state.crankSpeed = 0
        state.crankAngle = 0
        state.distillProgress = 0
        state.drips = {}
        state.steamParticles = {}
        state.totalQuality = 0
        state.qualityChecks = 0
        state.distillType = "potion"

        -- Set liquid color based on recipe category
        if recipe.category == "poison" then
            state.liquidColor = {0.5, 0.2, 0.6}
        elseif recipe.category == "potion" then
            state.liquidColor = {0.3, 0.6, 0.8}
        else
            state.liquidColor = {0.4, 0.8, 0.4}
        end

        state.notification = "Chop the ingredients! Press SPACE or click rapidly!"
        state.notificationTimer = 2.5
        return true
    else
        state.notification = reason
        state.notificationTimer = 2
        return false
    end
end

-- Complete crafting
function Alchemist.completeCraft()
    if state.currentRecipe then
        -- Calculate quality from all phases
        local qualityScore = 50  -- Base
        if state.qualityChecks > 0 then
            qualityScore = (state.totalQuality / state.qualityChecks) * 100
        end

        -- Bonus for perfect pour
        if state.pourQuality == "perfect" then
            qualityScore = qualityScore + 10
        elseif state.pourQuality == "overfill" then
            qualityScore = qualityScore - 15
        end

        qualityScore = math.max(0, math.min(100, qualityScore))
        local quality = CraftingCore.getQualityFromScore(qualityScore)

        -- Roll for rarity (better quality = better chance for rare)
        local rarity = CraftingCore.rollRarity()
        if qualityScore > 85 then
            -- Reroll for better rarity
            local newRarity = CraftingCore.rollRarity()
            if newRarity.statMult > rarity.statMult then rarity = newRarity end
        end

        -- Create the crafted item
        state.craftedItem = CraftingCore.createCraftedItem(state.currentRecipe, rarity, quality)

        -- Modify name based on distill type
        if state.distillType == "powder" then
            state.craftedItem.name = state.craftedItem.name:gsub("Potion", "Powder"):gsub("Poison", "Toxic Powder")
            state.craftedItem.isPowder = true
        end

        -- Award XP (bonus for high quality)
        local xpGained = CraftingCore.awardCraftingXP(state.currentRecipe, "alchemy")
        if qualityScore > 80 then
            xpGained = math.floor(xpGained * 1.5)
        end
        Progression.addXP(xpGained, "alchemy")

        state.currentRecipe = nil
        state.craftingProgress = 0
        state.brewPhase = "idle"
        state.showOutput = true

        local typeStr = state.distillType == "powder" and "ground" or "brewed"
        state.notification = "Successfully " .. typeStr .. " " .. state.craftedItem.name .. "!"
        state.notificationTimer = 3
    end
end

-- Handle output choice
function Alchemist.handleOutputChoice(choice)
    if not state.craftedItem then return end

    if choice == 1 then
        local value = CraftingCore.sellItem(state.craftedItem)
        state.notification = "Sold for " .. value .. " gold!"
        state.notificationTimer = 2
    elseif choice == 2 then
        CraftingCore.keepItem(state.craftedItem)
        state.notification = "Added to backpack!"
        state.notificationTimer = 2
    elseif choice == 3 then
        local basePrice = CraftingCore.getSellValue(state.craftedItem)
        CraftingCore.listOnMarket(state.craftedItem, math.floor(basePrice * 1.5))
        state.notification = "Listed on market!"
        state.notificationTimer = 2
    end

    state.craftedItem = nil
    state.showOutput = false
end

-- Draw the alchemist table
function Alchemist.draw()
    local screenW, screenH = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()

    UIAssets.clearTooltip()

    -- Draw background image if available
    if not UIAssets.drawGameBackground("alchemist", 1) then
        -- Fallback: Background (alchemist lab)
        love.graphics.setColor(0.15, 0.12, 0.1)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)

        -- Shelf pattern
        love.graphics.setColor(0.2, 0.15, 0.1)
        for i = 0, 5 do
            love.graphics.rectangle("fill", 0, i * 120, screenW, 3)
        end
    end

    -- Dark overlay
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Draw bubbles
    for _, b in ipairs(state.bubbles) do
        local alpha = b.life / 1.5
        love.graphics.setColor(0.3, 0.8, 0.4, alpha * 0.6)
        love.graphics.circle("fill", b.x, b.y, b.size)
    end

    -- Stats panel
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 10, 10, 220, 130, 8, 8)

    love.graphics.setColor(0.4, 0.9, 0.5)
    love.graphics.setFont(getFont(18))
    love.graphics.print("ALCHEMIST TABLE", 20, 15)

    UIAssets.drawCurrencyWithTooltip("coins", PlayerData.coins, 20, 45, 16)

    love.graphics.setColor(0.7, 0.9, 0.7)
    love.graphics.setFont(getFont(12))
    love.graphics.print("Alchemy Level: " .. Alchemist.getSkillLevel(), 20, 70)

    -- Show materials
    love.graphics.setColor(0.6, 0.8, 0.6)
    love.graphics.print("Herbs: " .. Backpack.getItemCount("healing_herb"), 20, 90)
    love.graphics.print("Moon: " .. Backpack.getItemCount("moonflower"), 120, 90)
    love.graphics.print("Venom: " .. Backpack.getItemCount("venom_sac"), 20, 110)
    love.graphics.print("Vials: " .. Backpack.getItemCount("empty_vial"), 120, 110)

    -- Recipe list (using UI component)
    local recipeX = 10
    local recipeY = 150
    local recipeW = 220
    local recipeH = screenH - 200

    -- Panel background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", recipeX, recipeY, recipeW, recipeH, 8, 8)

    -- Panel title
    love.graphics.setColor(0.5, 0.9, 0.5)
    love.graphics.setFont(getFont(14))
    love.graphics.print("BREW RECIPES", recipeX + 10, recipeY + 8)

    -- Draw recipe list UI component
    if state.uiRecipeList then
        state.uiRecipeList:draw()
    end

    -- Recipe details
    local detailX = 250
    local detailY = 60
    local detailW = 300
    local detailH = 280

    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", detailX, detailY, detailW, detailH, 8, 8)

    local selectedRecipe = RECIPES[state.selectedRecipeIndex]
    if selectedRecipe then
        love.graphics.setColor(0.5, 0.9, 0.6)
        love.graphics.setFont(getFont(18))
        love.graphics.print(selectedRecipe.name, detailX + 15, detailY + 10)

        local catColors = {potion = {0.4, 0.7, 0.5}, poison = {0.6, 0.3, 0.6}}
        love.graphics.setColor(catColors[selectedRecipe.category] or {0.5, 0.6, 0.5})
        love.graphics.setFont(getFont(11))
        love.graphics.print(selectedRecipe.category:upper(), detailX + 15, detailY + 35)

        love.graphics.setColor(0.8, 0.9, 0.8)
        love.graphics.setFont(getFont(12))
        love.graphics.print("Ingredients:", detailX + 15, detailY + 60)

        for j, mat in ipairs(selectedRecipe.materials) do
            local itemDef = Backpack.getItemDef(mat.id)
            local owned = Backpack.getItemCount(mat.id)
            love.graphics.setColor(owned >= mat.qty and {0.4, 0.8, 0.4} or {0.8, 0.4, 0.4})
            local itemName = itemDef and itemDef.name or mat.id
            love.graphics.print("  " .. itemName .. " x" .. mat.qty .. " (" .. owned .. ")", detailX + 20, detailY + 75 + (j - 1) * 18)
        end

        local matCount = #selectedRecipe.materials
        love.graphics.setColor(1, 0.9, 0.3)
        love.graphics.print("Gold: " .. (selectedRecipe.goldCost or 0), detailX + 15, detailY + 80 + matCount * 18)

        love.graphics.setColor(0.7, 0.8, 0.7)
        love.graphics.print("Skill Required: " .. (selectedRecipe.skillRequired or 0), detailX + 15, detailY + 100 + matCount * 18)

        love.graphics.setColor(0.5, 0.9, 0.6)
        love.graphics.print("Effects:", detailX + 15, detailY + 125 + matCount * 18)
        local statY = detailY + 140 + matCount * 18
        for statName, statValue in pairs(selectedRecipe.baseStats or {}) do
            love.graphics.print("  " .. statName .. ": " .. tostring(statValue), detailX + 20, statY)
            statY = statY + 15
        end

        -- Brew button (using UI component)
        local canCraft, reason = Alchemist.canCraft(selectedRecipe)
        local craftBtnX = detailX + 15
        local craftBtnY = detailY + detailH - 50
        local craftBtnW = detailW - 30
        local craftBtnH = 40

        if state.uiBrewButton then
            state.uiBrewButton.x = craftBtnX
            state.uiBrewButton.y = craftBtnY
            state.uiBrewButton.w = craftBtnW
            state.uiBrewButton.h = craftBtnH
            state.uiBrewButton.disabled = not canCraft or state.currentRecipe ~= nil

            if state.currentRecipe then
                state.uiBrewButton.text = "BREWING..."
                state.uiBrewButton.variant = "ghost"
            elseif canCraft then
                state.uiBrewButton.text = "BREW"
                state.uiBrewButton.variant = "success"
            else
                state.uiBrewButton.text = reason or "Cannot Brew"
                state.uiBrewButton.variant = "ghost"
            end

            state.uiBrewButton:draw()
        end
    end

    -- ============================================
    -- INTERACTIVE BREWING MINIGAMES
    -- ============================================

    state.buttons = {}  -- Clear buttons each frame

    if state.brewPhase == "prep" then
        -- CHOPPING PHASE
        local chopX = screenW / 2 - 150
        local chopY = screenH / 2 - 100

        -- Cutting board background
        love.graphics.setColor(0.4, 0.3, 0.2)
        love.graphics.rectangle("fill", chopX - 30, chopY - 30, 200, 160, 8, 8)
        love.graphics.setColor(0.5, 0.4, 0.3)
        love.graphics.rectangle("fill", chopX - 20, chopY - 20, 180, 140, 5, 5)

        -- Current ingredient
        if state.currentRecipe and state.currentRecipe.materials[state.currentPrepIndex] then
            local mat = state.currentRecipe.materials[state.currentPrepIndex]
            local itemDef = Backpack.getItemDef(mat.id)
            local itemName = itemDef and itemDef.name or mat.id

            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(getFont(14))
            love.graphics.printf("Chopping: " .. itemName, chopX - 30, chopY - 60, 200, "center")

            -- Ingredient visual (simple shape)
            love.graphics.setColor(0.3, 0.7, 0.3)
            love.graphics.ellipse("fill", chopX + 70, chopY + 40, 40, 25)
        end

        -- Chop particles
        for _, p in ipairs(state.chopParticles) do
            love.graphics.setColor(p.color[1], p.color[2], p.color[3], p.life)
            love.graphics.rectangle("fill", p.x, p.y, p.size, p.size)
        end

        -- Progress bar (using UI component)
        if state.uiPrepProgressBar then
            state.uiPrepProgressBar.x = chopX - 30
            state.uiPrepProgressBar.y = chopY + 100
            state.uiPrepProgressBar.w = 200
            state.uiPrepProgressBar:draw()
        end

        -- Streak indicator
        if state.chopStreak > 20 then
            love.graphics.setColor(1, 0.8, 0.2, state.chopStreak / 100)
            love.graphics.setFont(getFont(16))
            love.graphics.printf("COMBO x" .. math.floor(state.chopStreak / 20), chopX - 30, chopY + 130, 200, "center")
        end

        -- Chop button (using UI component)
        local chopBtnX = screenW / 2 + 80
        local chopBtnY = screenH / 2 - 50
        local chopBtnW = 120
        local chopBtnH = 100

        if state.uiChopButton then
            state.uiChopButton.x = chopBtnX
            state.uiChopButton.y = chopBtnY
            state.uiChopButton.w = chopBtnW
            state.uiChopButton.h = chopBtnH
            state.uiChopButton:draw()

            -- Draw additional instruction text
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(getFont(10))
            love.graphics.printf("[SPACE] or Click", chopBtnX, chopBtnY + 60, chopBtnW, "center")
        end

        state.buttons.chop = {x = chopBtnX, y = chopBtnY, w = chopBtnW, h = chopBtnH}

        -- Ingredient counter
        love.graphics.setColor(0.8, 0.9, 0.8)
        love.graphics.setFont(getFont(12))
        love.graphics.printf("Ingredient " .. state.currentPrepIndex .. "/" .. #state.currentRecipe.materials, chopX - 30, chopY - 80, 200, "center")

    elseif state.brewPhase == "pour" then
        -- POURING PHASE
        local cauldronX = screenW / 2
        local cauldronY = screenH - 150

        -- Cauldron
        love.graphics.setColor(0.25, 0.25, 0.3)
        love.graphics.ellipse("fill", cauldronX, cauldronY, 80, 40)
        love.graphics.setColor(0.15, 0.15, 0.2)
        love.graphics.ellipse("fill", cauldronX, cauldronY, 70, 35)

        -- Liquid in cauldron
        local fillHeight = (state.pourProgress / 100) * 60
        love.graphics.setColor(state.liquidColor[1], state.liquidColor[2], state.liquidColor[3], 0.8)
        love.graphics.ellipse("fill", cauldronX, cauldronY - fillHeight / 2, 65, 30)

        -- Pour splashes
        for _, s in ipairs(state.pourSplashes) do
            love.graphics.setColor(state.liquidColor[1], state.liquidColor[2], state.liquidColor[3], s.life)
            love.graphics.circle("fill", s.x, s.y, s.size)
        end

        -- Pouring vial (above cauldron when pouring)
        local vialX = cauldronX - 20
        local vialY = cauldronY - 150
        if state.pouringActive then
            -- Tilted vial
            love.graphics.push()
            love.graphics.translate(vialX + 15, vialY + 40)
            love.graphics.rotate(math.rad(45))
            love.graphics.setColor(0.7, 0.8, 0.9, 0.8)
            love.graphics.rectangle("fill", -8, -40, 16, 50, 3, 3)
            love.graphics.setColor(state.liquidColor[1], state.liquidColor[2], state.liquidColor[3])
            local remaining = math.max(0, 1 - state.pourProgress / 100)
            love.graphics.rectangle("fill", -6, -38 + (1 - remaining) * 40, 12, remaining * 40, 2, 2)
            love.graphics.pop()

            -- Pour stream
            love.graphics.setColor(state.liquidColor[1], state.liquidColor[2], state.liquidColor[3], 0.7)
            love.graphics.setLineWidth(3)
            love.graphics.line(vialX + 35, vialY + 20, cauldronX, cauldronY - 60)
            love.graphics.setLineWidth(1)
        else
            -- Upright vial
            love.graphics.setColor(0.7, 0.8, 0.9, 0.8)
            love.graphics.rectangle("fill", vialX, vialY, 30, 60, 5, 5)
            love.graphics.setColor(state.liquidColor[1], state.liquidColor[2], state.liquidColor[3])
            local remaining = math.max(0, 1 - state.pourProgress / 100)
            love.graphics.rectangle("fill", vialX + 3, vialY + 5 + (1 - remaining) * 50, 24, remaining * 50, 3, 3)
        end

        -- Fill meter
        local meterX = screenW / 2 + 120
        local meterY = screenH - 280
        local meterH = 200

        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", meterX, meterY, 40, meterH, 5, 5)

        -- Fill level
        local fillPercent = state.pourProgress / 100
        love.graphics.setColor(state.liquidColor[1], state.liquidColor[2], state.liquidColor[3])
        love.graphics.rectangle("fill", meterX + 3, meterY + meterH - fillPercent * meterH, 34, fillPercent * meterH, 3, 3)

        -- Perfect zone (70-80%)
        love.graphics.setColor(0.3, 0.8, 0.3, 0.4)
        love.graphics.rectangle("fill", meterX, meterY + meterH * 0.2, 40, meterH * 0.1)

        -- Good zone markers
        love.graphics.setColor(0.8, 0.8, 0.3, 0.3)
        love.graphics.rectangle("fill", meterX, meterY + meterH * 0.1, 40, meterH * 0.1)
        love.graphics.rectangle("fill", meterX, meterY + meterH * 0.3, 40, meterH * 0.1)

        -- Quality indicator
        love.graphics.setFont(getFont(14))
        if state.pourQuality == "perfect" then
            love.graphics.setColor(0.3, 1, 0.3)
            love.graphics.print("PERFECT!", meterX - 10, meterY - 25)
        elseif state.pourQuality == "good" then
            love.graphics.setColor(0.8, 0.8, 0.3)
            love.graphics.print("Good", meterX, meterY - 25)
        elseif state.pourQuality == "overfill" then
            love.graphics.setColor(0.9, 0.3, 0.3)
            love.graphics.print("Overfill!", meterX - 5, meterY - 25)
        end

        -- Pour button (using UI component)
        local pourBtnX = screenW / 2 - 180
        local pourBtnY = screenH - 200
        local pourBtnW = 120
        local pourBtnH = 80

        if state.uiPourButton then
            state.uiPourButton.x = pourBtnX
            state.uiPourButton.y = pourBtnY
            state.uiPourButton.w = pourBtnW
            state.uiPourButton.h = pourBtnH
            state.uiPourButton.text = state.pouringActive and "POURING..." or "HOLD TO POUR"
            state.uiPourButton:draw()

            -- Draw additional instruction text
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(getFont(10))
            love.graphics.printf("[SPACE] or Hold", pourBtnX, pourBtnY + 50, pourBtnW, "center")
        end

        state.buttons.pour = {x = pourBtnX, y = pourBtnY, w = pourBtnW, h = pourBtnH}

        -- Done button (when poured enough)
        if state.pourProgress >= 50 then
            local doneBtnX = screenW / 2 - 180
            local doneBtnY = screenH - 100
            local doneBtnW = 120
            local doneBtnH = 40

            if state.uiPourDoneButton then
                state.uiPourDoneButton.x = doneBtnX
                state.uiPourDoneButton.y = doneBtnY
                state.uiPourDoneButton.w = doneBtnW
                state.uiPourDoneButton.h = doneBtnH
                state.uiPourDoneButton:draw()
            end

            state.buttons.pourDone = {x = doneBtnX, y = doneBtnY, w = doneBtnW, h = doneBtnH}
        end

    elseif state.brewPhase == "heat" then
        -- BELLOWS/HEAT PHASE
        local cauldronX = screenW / 2
        local cauldronY = screenH - 120

        -- Fire underneath
        for _, f in ipairs(state.flames) do
            local alpha = f.life / 0.8
            love.graphics.setColor(1, 0.5 + f.life * 0.3, 0.1, alpha)
            love.graphics.circle("fill", f.x, f.y, f.size)
        end

        -- Smoke
        for _, s in ipairs(state.smoke) do
            local alpha = (s.life / 2) * 0.5
            love.graphics.setColor(0.5, 0.5, 0.55, alpha)
            love.graphics.circle("fill", s.x, s.y, s.size)
        end

        -- Cauldron
        love.graphics.setColor(0.25, 0.25, 0.3)
        love.graphics.ellipse("fill", cauldronX, cauldronY, 80, 40)
        love.graphics.setColor(state.liquidColor[1] * 0.8, state.liquidColor[2] * 0.8, state.liquidColor[3] * 0.8)
        love.graphics.ellipse("fill", cauldronX, cauldronY - 10, 70, 32)

        -- Bubbles in cauldron (based on heat)
        if state.bellowsHeat > 40 then
            for _, b in ipairs(state.bubbles) do
                local alpha = b.life / 1.5
                love.graphics.setColor(1, 1, 1, alpha * 0.6)
                love.graphics.circle("fill", b.x, b.y, b.size)
            end
        end

        -- Bellows visual
        local bellowsX = screenW / 2 - 180
        local bellowsY = screenH - 180

        love.graphics.push()
        love.graphics.translate(bellowsX + 50, bellowsY + 40)
        love.graphics.rotate(math.rad(state.bellowsAngle))

        -- Bellows body
        love.graphics.setColor(0.5, 0.35, 0.2)
        love.graphics.polygon("fill", -40, -20, 40, -10, 40, 10, -40, 20)
        love.graphics.setColor(0.6, 0.45, 0.3)
        love.graphics.polygon("fill", -40, -15, 35, -8, 35, 8, -40, 15)

        love.graphics.pop()

        -- Bellows nozzle
        love.graphics.setColor(0.4, 0.3, 0.25)
        love.graphics.rectangle("fill", bellowsX + 90, bellowsY + 30, 60, 20, 3, 3)

        -- Heat meter
        local heatMeterX = screenW / 2 + 100
        local heatMeterY = screenH - 280
        local heatMeterH = 200

        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", heatMeterX, heatMeterY, 50, heatMeterH, 5, 5)

        -- Heat level (gradient from blue to red)
        local heatPercent = state.bellowsHeat / 100
        local heatColor = {
            0.3 + heatPercent * 0.7,
            0.3 + (1 - math.abs(heatPercent - 0.5) * 2) * 0.5,
            0.8 - heatPercent * 0.6
        }
        love.graphics.setColor(heatColor[1], heatColor[2], heatColor[3])
        love.graphics.rectangle("fill", heatMeterX + 3, heatMeterY + heatMeterH - heatPercent * heatMeterH, 44, heatPercent * heatMeterH, 3, 3)

        -- Optimal zone (55-75%)
        love.graphics.setColor(0.3, 0.8, 0.3, 0.4)
        love.graphics.rectangle("fill", heatMeterX, heatMeterY + heatMeterH * 0.25, 50, heatMeterH * 0.2)

        -- Heat label
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(12))
        love.graphics.printf("HEAT", heatMeterX, heatMeterY - 20, 50, "center")

        -- Progress bar
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", screenW / 2 - 100, 80, 200, 30, 5, 5)
        love.graphics.setColor(0.8, 0.5, 0.2)
        love.graphics.rectangle("fill", screenW / 2 - 97, 83, 194 * (state.heatProgress / state.heatRequired), 24, 3, 3)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(11))
        love.graphics.printf("Heating Progress", screenW / 2 - 100, 85, 200, "center")

        -- Pump button (using UI component)
        local pumpBtnX = bellowsX - 20
        local pumpBtnY = bellowsY + 80
        local pumpBtnW = 140
        local pumpBtnH = 60

        if state.uiPumpButton then
            state.uiPumpButton.x = pumpBtnX
            state.uiPumpButton.y = pumpBtnY
            state.uiPumpButton.w = pumpBtnW
            state.uiPumpButton.h = pumpBtnH
            state.uiPumpButton.text = state.bellowsPumping and "PUMPING..." or "PUMP BELLOWS"
            state.uiPumpButton:draw()

            -- Draw additional instruction text
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(getFont(10))
            love.graphics.printf("[SPACE] or Hold", pumpBtnX, pumpBtnY + 38, pumpBtnW, "center")
        end

        state.buttons.pump = {x = pumpBtnX, y = pumpBtnY, w = pumpBtnW, h = pumpBtnH}

    elseif state.brewPhase == "distill" then
        -- DISTILLING/CRANK PHASE
        local crankX = screenW / 2 + 50
        local crankY = screenH - 200

        -- Distillation apparatus
        love.graphics.setColor(0.5, 0.55, 0.6)
        -- Main vessel
        love.graphics.ellipse("fill", crankX - 80, crankY + 50, 50, 30)
        -- Tube
        love.graphics.setLineWidth(8)
        love.graphics.setColor(0.45, 0.5, 0.55)
        love.graphics.line(crankX - 30, crankY + 30, crankX + 30, crankY - 30, crankX + 80, crankY - 30)
        love.graphics.setLineWidth(1)
        -- Collection flask
        love.graphics.setColor(0.6, 0.65, 0.7, 0.7)
        love.graphics.polygon("fill", crankX + 70, crankY - 20, crankX + 90, crankY - 20, crankX + 95, crankY + 40, crankX + 65, crankY + 40)

        -- Drips
        for _, d in ipairs(state.drips) do
            love.graphics.setColor(state.liquidColor[1], state.liquidColor[2], state.liquidColor[3], d.life)
            love.graphics.circle("fill", d.x, d.y, 3)
        end

        -- Collected liquid
        local collectPercent = state.distillProgress / state.distillTarget
        love.graphics.setColor(state.liquidColor[1], state.liquidColor[2], state.liquidColor[3], 0.8)
        local collectH = collectPercent * 50
        love.graphics.rectangle("fill", crankX + 67, crankY + 40 - collectH, 26, collectH)

        -- Steam
        for _, s in ipairs(state.steamParticles) do
            local alpha = (s.life / 1.5) * 0.6
            love.graphics.setColor(0.9, 0.9, 0.95, alpha)
            love.graphics.circle("fill", s.x, s.y, s.size)
        end

        -- Crank wheel
        local wheelRadius = 50
        love.graphics.push()
        love.graphics.translate(crankX - 150, crankY + 30)
        love.graphics.rotate(math.rad(state.crankAngle))

        -- Wheel
        love.graphics.setColor(0.4, 0.35, 0.3)
        love.graphics.circle("fill", 0, 0, wheelRadius)
        love.graphics.setColor(0.5, 0.45, 0.4)
        love.graphics.circle("line", 0, 0, wheelRadius)

        -- Spokes
        love.graphics.setColor(0.35, 0.3, 0.25)
        for i = 0, 5 do
            local angle = math.rad(i * 60)
            love.graphics.line(0, 0, math.cos(angle) * (wheelRadius - 5), math.sin(angle) * (wheelRadius - 5))
        end

        -- Handle
        love.graphics.setColor(0.6, 0.5, 0.4)
        love.graphics.circle("fill", wheelRadius - 10, 0, 12)

        love.graphics.pop()

        -- Speed meter
        local speedMeterX = screenW / 2 - 200
        local speedMeterY = screenH - 120
        local speedMeterW = 150

        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", speedMeterX, speedMeterY, speedMeterW, 30, 5, 5)

        -- Speed indicator
        local speedPercent = state.crankSpeed / 100
        local speedColor = {0.5, 0.8, 0.5}
        if state.crankSpeed < 30 or state.crankSpeed > 70 then
            speedColor = {0.8, 0.5, 0.3}
        elseif state.crankSpeed >= 40 and state.crankSpeed <= 60 then
            speedColor = {0.3, 0.9, 0.4}
        end
        love.graphics.setColor(speedColor[1], speedColor[2], speedColor[3])
        love.graphics.rectangle("fill", speedMeterX + 3, speedMeterY + 3, speedMeterW * speedPercent - 6, 24, 3, 3)

        -- Optimal zone markers
        love.graphics.setColor(0.3, 0.8, 0.3, 0.5)
        love.graphics.rectangle("fill", speedMeterX + speedMeterW * 0.4, speedMeterY, speedMeterW * 0.2, 30)

        -- Speed label
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(11))
        love.graphics.printf("Crank Speed", speedMeterX, speedMeterY - 18, speedMeterW, "center")

        -- Output type indicator
        love.graphics.setFont(getFont(14))
        if state.distillType == "powder" then
            love.graphics.setColor(0.8, 0.7, 0.5)
            love.graphics.printf("Making: POWDER", speedMeterX, speedMeterY + 40, speedMeterW, "center")
        else
            love.graphics.setColor(0.4, 0.7, 0.9)
            love.graphics.printf("Making: POTION", speedMeterX, speedMeterY + 40, speedMeterW, "center")
        end

        -- Progress bar
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", screenW / 2 - 100, 80, 200, 30, 5, 5)
        love.graphics.setColor(0.4, 0.6, 0.8)
        love.graphics.rectangle("fill", screenW / 2 - 97, 83, 194 * (state.distillProgress / state.distillTarget), 24, 3, 3)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(11))
        love.graphics.printf("Distilling: " .. math.floor(state.distillProgress) .. "%", screenW / 2 - 100, 85, 200, "center")

        -- Crank button (using UI component)
        local crankBtnX = crankX - 200
        local crankBtnY = crankY + 100
        local crankBtnW = 140
        local crankBtnH = 60

        if state.uiCrankButton then
            state.uiCrankButton.x = crankBtnX
            state.uiCrankButton.y = crankBtnY
            state.uiCrankButton.w = crankBtnW
            state.uiCrankButton.h = crankBtnH
            state.uiCrankButton.text = state.crankingActive and "CRANKING..." or "CRANK!"
            state.uiCrankButton:draw()

            -- Draw additional instruction text
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(getFont(10))
            love.graphics.printf("[SPACE] rapidly", crankBtnX, crankBtnY + 38, crankBtnW, "center")
        end

        state.buttons.crank = {x = crankBtnX, y = crankBtnY, w = crankBtnW, h = crankBtnH}
    end

    -- Phase indicator (top center)
    if state.brewPhase ~= "idle" and state.currentRecipe then
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", screenW / 2 - 120, 10, 240, 60, 8, 8)

        love.graphics.setColor(0.5, 0.9, 0.6)
        love.graphics.setFont(getFont(14))
        love.graphics.printf("Brewing: " .. state.currentRecipe.name, screenW / 2 - 110, 15, 220, "center")

        local phaseNames = {prep = "1. PREP", pour = "2. POUR", heat = "3. HEAT", distill = "4. DISTILL"}
        love.graphics.setColor(0.9, 0.8, 0.4)
        love.graphics.setFont(getFont(16))
        love.graphics.printf(phaseNames[state.brewPhase] or state.brewPhase, screenW / 2 - 110, 38, 220, "center")
    end

    -- Output options panel
    if state.showOutput and state.craftedItem then
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)

        local panelW, panelH = 350, 280
        local panelX = screenW / 2 - panelW / 2
        local panelY = screenH / 2 - panelH / 2

        love.graphics.setColor(0.12, 0.15, 0.12)
        love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)
        love.graphics.setColor(0.4, 0.7, 0.4)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 10, 10)
        love.graphics.setLineWidth(1)

        love.graphics.setColor(0.5, 0.9, 0.5)
        love.graphics.setFont(getFont(18))
        love.graphics.print("POTION BREWED!", panelX + 20, panelY + 15)

        CraftingCore.drawRarityText(state.craftedItem.name, panelX + 20, panelY + 50, state.craftedItem.rarity)

        love.graphics.setFont(getFont(12))
        CraftingCore.drawQualityText("Quality: " .. CraftingCore.getQuality(state.craftedItem.quality).name, panelX + 20, panelY + 75, state.craftedItem.quality)

        love.graphics.setColor(0.6, 0.9, 0.7)
        love.graphics.print("Effects:", panelX + 20, panelY + 100)
        local statY = panelY + 118
        for statName, statValue in pairs(state.craftedItem.finalStats or {}) do
            love.graphics.print("  " .. statName .. ": " .. tostring(statValue), panelX + 25, statY)
            statY = statY + 16
        end

        local optionY = panelY + panelH - 140
        local hoveredOption = CraftingCore.getHoveredOption(mx, my, panelX + 20, optionY, panelW - 40, 3)
        CraftingCore.drawOutputOptions(state.craftedItem, panelX + 20, optionY, panelW - 40, hoveredOption)
    end

    -- Notification
    if state.notification then
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", screenW / 2 - 150, 120, 300, 40, 8, 8)
        love.graphics.setColor(0.5, 0.9, 0.6)
        love.graphics.setFont(getFont(14))
        love.graphics.printf(state.notification, screenW / 2 - 145, 130, 290, "center")
    end

    -- Employee count indicator (top right)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", screenW - 130, 10, 120, 50, 6, 6)
    love.graphics.setColor(0.4, 0.9, 0.5)
    love.graphics.setFont(getFont(12))
    love.graphics.print("Assistants: " .. #state.employees, screenW - 120, 18)
    -- Show passive income from employees
    local totalEfficiency = 0
    for _, emp in ipairs(state.employees) do
        if emp.isHired and not emp.isDead then
            totalEfficiency = totalEfficiency + Employees.getEfficiency(emp)
        end
    end
    love.graphics.setColor(0.4, 0.8, 0.4)
    love.graphics.print(string.format("+%.1f gold/s", totalEfficiency * 0.1), screenW - 120, 35)

    -- Instructions (phase-dependent)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.setFont(getFont(12))
    local instructions = "[B] Backpack  [E] Employees  [ESC] Exit"
    if state.brewPhase == "prep" then
        instructions = "[SPACE] Chop  " .. instructions
    elseif state.brewPhase == "pour" then
        instructions = "[SPACE] Hold to Pour  [ENTER] Done  " .. instructions
    elseif state.brewPhase == "heat" then
        instructions = "[SPACE] Hold to Pump  " .. instructions
    elseif state.brewPhase == "distill" then
        instructions = "[SPACE] Crank  " .. instructions
    end
    love.graphics.printf(instructions, 0, screenH - 30, screenW, "center")

    -- Draw employee panel if open
    if state.showEmployeePanel then
        EmployeeUI.drawEmployeePanel(screenW, screenH, mx, my, "alchemist", state.employees, state.hiringPool, state.upgrades)
    end

    UIAssets.drawTooltip()

    -- Draw tutorial overlay
    Tutorials.draw()
end

-- Handle mouse press
function Alchemist.mousepressed(x, y, button)
    if button ~= 1 then return end

    -- Handle tutorial clicks first
    if Tutorials.isActive() then
        Tutorials.mousepressed(x, y, button)
        return
    end

    local screenW, screenH = love.graphics.getDimensions()

    -- Handle employee panel clicks
    if state.showEmployeePanel then
        local action, idx = EmployeeUI.handleEmployeePanelClick(x, y, "alchemist", state.employees, state.hiringPool, state.upgrades)
        if action == "fire" then
            Alchemist.fireEmployee(idx)
        elseif action == "hire" then
            Alchemist.hireEmployee(idx)
        end
        return
    end

    if state.showOutput and state.craftedItem then
        local panelW, panelH = 350, 280
        local panelX = screenW / 2 - panelW / 2
        local panelY = screenH / 2 - panelH / 2
        local optionY = panelY + panelH - 140

        local choice = CraftingCore.getHoveredOption(x, y, panelX + 20, optionY, panelW - 40, 3)
        if choice then
            Alchemist.handleOutputChoice(choice)
        end
        return
    end

    -- UI component click handling
    -- Recipe list
    if state.uiRecipeList and state.uiRecipeList:mousepressed(x, y, button) then
        return
    end

    -- Brew button
    if state.uiBrewButton and state.uiBrewButton:mousepressed(x, y, button) then
        return
    end

    -- Phase-specific UI buttons
    if state.brewPhase == "prep" and state.uiChopButton then
        if state.uiChopButton:mousepressed(x, y, button) then
            return
        end
    end

    if state.brewPhase == "pour" then
        if state.uiPourButton and state.uiPourButton:mousepressed(x, y, button) then
            return
        end
        if state.uiPourDoneButton and state.uiPourDoneButton:mousepressed(x, y, button) then
            return
        end
    end

    if state.brewPhase == "heat" and state.uiPumpButton then
        if state.uiPumpButton:mousepressed(x, y, button) then
            return
        end
    end

    if state.brewPhase == "distill" and state.uiCrankButton then
        if state.uiCrankButton:mousepressed(x, y, button) then
            return
        end
    end
end

-- Handle key press
function Alchemist.keypressed(key)
    -- Handle tutorial keypresses first
    if Tutorials.isActive() then
        Tutorials.keypressed(key)
        return
    end

    -- Phase-specific controls
    if key == "space" then
        if state.brewPhase == "prep" then
            Alchemist.doChop()
        elseif state.brewPhase == "pour" then
            state.pouringActive = true
        elseif state.brewPhase == "heat" then
            state.bellowsPumping = true
            Alchemist.pumpBellows()
        elseif state.brewPhase == "distill" then
            Alchemist.doCrank()
        end
        return
    elseif key == "return" or key == "kpenter" then
        -- Done button for pour phase
        if state.brewPhase == "pour" and state.pourProgress >= 50 then
            Alchemist.advancePhase()
            return
        elseif not state.currentRecipe and not state.showOutput and state.brewPhase == "idle" then
            local selectedRecipe = RECIPES[state.selectedRecipeIndex]
            if selectedRecipe then
                Alchemist.startCraft(selectedRecipe)
            end
            return
        end
    end

    if key == "b" then
        Backpack.toggle()
    elseif key == "e" then
        -- Toggle employee panel
        state.showEmployeePanel = not state.showEmployeePanel
        state.showUpgradePanel = false
    elseif key == "escape" then
        if state.showOutput then
            if state.craftedItem then
                CraftingCore.keepItem(state.craftedItem)
                state.notification = "Added to backpack!"
                state.notificationTimer = 2
            end
            state.craftedItem = nil
            state.showOutput = false
        elseif state.showEmployeePanel then
            state.showEmployeePanel = false
        elseif state.showUpgradePanel then
            state.showUpgradePanel = false
        else
            Alchemist.saveData()
            state.brewPhase = "idle"
            state.active = false
            return "menu"
        end
    elseif key == "up" then
        state.selectedRecipeIndex = math.max(1, state.selectedRecipeIndex - 1)
    elseif key == "down" then
        state.selectedRecipeIndex = math.min(#RECIPES, state.selectedRecipeIndex + 1)
    end
end

-- Handle key release (for hold-to-action mechanics)
function Alchemist.keyreleased(key)
    if key == "space" then
        if state.brewPhase == "pour" then
            state.pouringActive = false
        elseif state.brewPhase == "heat" then
            state.bellowsPumping = false
        end
    end
end

-- Handle mouse release (for hold-to-action mechanics)
function Alchemist.mousereleased(x, y, button)
    -- Pass to UI components first
    if state.uiRecipeList and state.uiRecipeList.mousereleased then
        state.uiRecipeList:mousereleased(x, y, button)
    end
    if state.uiBrewButton and state.uiBrewButton.mousereleased then
        state.uiBrewButton:mousereleased(x, y, button)
    end
    if state.uiChopButton and state.uiChopButton.mousereleased then
        state.uiChopButton:mousereleased(x, y, button)
    end
    if state.uiPourButton and state.uiPourButton.mousereleased then
        state.uiPourButton:mousereleased(x, y, button)
    end
    if state.uiPourDoneButton and state.uiPourDoneButton.mousereleased then
        state.uiPourDoneButton:mousereleased(x, y, button)
    end
    if state.uiPumpButton and state.uiPumpButton.mousereleased then
        state.uiPumpButton:mousereleased(x, y, button)
    end
    if state.uiCrankButton and state.uiCrankButton.mousereleased then
        state.uiCrankButton:mousereleased(x, y, button)
    end

    if button == 1 then
        -- Stop pouring
        if state.brewPhase == "pour" then
            state.pouringActive = false
        end
        -- Stop pumping bellows
        if state.brewPhase == "heat" then
            state.bellowsPumping = false
        end
    end
end

-- Handle scroll
function Alchemist.wheelmoved(x, y)
    -- Pass to UI components first (recipe list)
    if state.uiRecipeList and state.uiRecipeList.wheelmoved then
        state.uiRecipeList:wheelmoved(x, y)
    end
end

-- Handle mouse movement (for UI component interactions like scrollbar dragging)
function Alchemist.mousemoved(x, y, dx, dy)
    if state.uiRecipeList and state.uiRecipeList.mousemoved then
        state.uiRecipeList:mousemoved(x, y, dx, dy)
    end
end

function Alchemist.isActive()
    return state.active
end

function Alchemist.exit()
    Alchemist.saveData()
    state.active = false
end

-- Hire an employee from the pool
function Alchemist.hireEmployee(index)
    -- Check if player owns this building
    if PlayerData.currentBuildingOwned ~= true then
        state.notification = "You must own this shop to hire assistants!"
        state.notificationTimer = 2
        return false
    end

    local emp = state.hiringPool[index]
    if not emp then return false end

    local empType = Employees.getType(emp.employeeType)
    if not empType then return false end

    -- Check max employees from upgrades
    local effects = UpgradeSystem.getCombinedEffects("alchemist", state.upgrades)
    local maxEmployees = effects.maxEmployees or 1

    if #state.employees >= maxEmployees then
        state.notification = "Max assistants reached! Upgrade capacity."
        state.notificationTimer = 2
        return false
    end

    if PlayerData.coins < empType.baseCost then
        state.notification = "Not enough gold!"
        state.notificationTimer = 2
        return false
    end

    -- Hire the employee
    PlayerData.coins = PlayerData.coins - empType.baseCost
    emp.isHired = true
    emp.hireDay = os.time()
    table.insert(state.employees, emp)
    table.remove(state.hiringPool, index)

    -- Generate a new candidate
    local newCandidates = Employees.generateHiringPool("alchemist", 1, Alchemist.getSkillLevel())
    if #newCandidates > 0 then
        table.insert(state.hiringPool, newCandidates[1])
    end

    state.notification = "Hired " .. emp.name .. "!"
    state.notificationTimer = 2
    -- Update global passive income rate
    Alchemist.updatePassiveIncomeRate()
    Alchemist.saveData()
    return true
end

-- Fire an employee
function Alchemist.fireEmployee(index)
    local emp = state.employees[index]
    if emp then
        table.remove(state.employees, index)
        state.notification = "Dismissed " .. emp.name
        state.notificationTimer = 2
        -- Update global passive income rate
        Alchemist.updatePassiveIncomeRate()
        Alchemist.saveData()
        return true
    end
    return false
end

-- Draw employee panel (delegated to shared EmployeeUI module)
function Alchemist.drawEmployeePanel(screenW, screenH, mx, my)
    EmployeeUI.drawEmployeePanel(screenW, screenH, mx, my, "alchemist", state.employees, state.hiringPool, state.upgrades)
end

-- Get UI region bounds for interactive tutorials
function Alchemist.getUIRegion(regionId)
    local screenW, screenH = love.graphics.getDimensions()
    local regions = {
        -- Materials display in stats panel (herbs, moonflower, venom, vials)
        materials_display = {x = 10, y = 80, w = 220, h = 60},
        -- Recipe list panel
        recipe_list = {x = 10, y = 150, w = 220, h = screenH - 200},
        -- Prep area (chopping phase)
        prep_area = {x = screenW / 2 - 180, y = screenH / 2 - 130, w = 230, h = 240},
        -- Pour meter (fill level meter)
        pour_meter = {x = screenW / 2 + 120, y = screenH - 280, w = 40, h = 200},
        -- Heat meter (temperature control)
        heat_meter = {x = screenW / 2 + 100, y = screenH - 280, w = 50, h = 200},
        -- Crank wheel (distilling phase)
        crank_wheel = {x = screenW / 2 - 200, y = screenH - 230, w = 100, h = 100},
    }
    return regions[regionId]
end

return Alchemist
