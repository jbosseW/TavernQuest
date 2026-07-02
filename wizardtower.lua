-- Wizard Tower - Craft spells, tomes, and scrolls!
-- A magical crafting minigame with spell creation

local WizardTower = {}
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

-- Game state
local state = {
    active = false,
    currentRecipe = nil,
    craftingProgress = 0,
    manaCharge = 0,        -- Minigame: charge mana for crafting
    craftedItem = nil,
    showOutput = false,
    selectedRecipeIndex = 1,
    scrollOffset = 0,
    notification = nil,
    notificationTimer = 0,
    chargeParticles = {},  -- Visual particles during charging

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

    -- UI Components
    recipeList = nil,
    craftButton = nil,
    manaProgressBar = nil,
    craftingProgressBar = nil,
    outputPanel = nil,
    employeePanelComponent = nil,
}

-- Spell recipes
local RECIPES = {
    -- Attack Spells
    {
        id = "fire_spell", name = "Fireball Scroll", category = "spell",
        materials = {{id = "fire_essence", qty = 2}, {id = "ancient_scroll", qty = 1}},
        goldCost = 40, craftTime = 4, skillRequired = 0,
        baseStats = {damage = 25, manaCost = 10},
        icon = "assets/icons/spells/S_Fire01.png",
    },
    {
        id = "frost_spell", name = "Frost Bolt Scroll", category = "spell",
        materials = {{id = "frost_essence", qty = 2}, {id = "ancient_scroll", qty = 1}},
        goldCost = 35, craftTime = 4, skillRequired = 0,
        baseStats = {damage = 18, manaCost = 8, slowEffect = 20},
        icon = "assets/icons/spells/S_Ice01.png",
    },
    {
        id = "lightning_spell", name = "Lightning Bolt Scroll", category = "spell",
        materials = {{id = "mana_crystal", qty = 2}, {id = "arcane_dust", qty = 1}, {id = "ancient_scroll", qty = 1}},
        goldCost = 60, craftTime = 5, skillRequired = 5,
        baseStats = {damage = 30, manaCost = 14},
        icon = "assets/icons/spells/S_Thunder01.png",
    },
    {
        id = "arcane_blast", name = "Arcane Blast Scroll", category = "spell",
        materials = {{id = "mana_crystal", qty = 3}, {id = "arcane_dust", qty = 2}, {id = "ancient_scroll", qty = 1}},
        goldCost = 100, craftTime = 7, skillRequired = 10,
        baseStats = {damage = 45, manaCost = 20},
        icon = "assets/icons/spells/S_Magic01.png",
    },

    -- Support Spells
    {
        id = "heal_spell", name = "Healing Light Scroll", category = "spell",
        materials = {{id = "moonflower", qty = 2}, {id = "mana_crystal", qty = 1}, {id = "ancient_scroll", qty = 1}},
        goldCost = 50, craftTime = 5, skillRequired = 3,
        baseStats = {healing = 30, manaCost = 15},
        icon = "assets/icons/spells/S_Holy01.png",
    },
    {
        id = "shield_spell", name = "Arcane Shield Scroll", category = "spell",
        materials = {{id = "arcane_dust", qty = 2}, {id = "mana_crystal", qty = 1}, {id = "ancient_scroll", qty = 1}},
        goldCost = 45, craftTime = 5, skillRequired = 4,
        baseStats = {defense = 20, manaCost = 12, duration = 30},
        icon = "assets/icons/spells/S_Buff01.png",
    },
    {
        id = "haste_spell", name = "Haste Scroll", category = "spell",
        materials = {{id = "arcane_dust", qty = 3}, {id = "ancient_scroll", qty = 1}},
        goldCost = 55, craftTime = 4, skillRequired = 6,
        baseStats = {speedBonus = 30, manaCost = 10, duration = 45},
        icon = "assets/icons/spells/S_Buff02.png",
    },

    -- Tomes (permanent bonuses)
    {
        id = "tome_power", name = "Tome of Power", category = "tome",
        materials = {{id = "mana_crystal", qty = 5}, {id = "enchanted_ink", qty = 3}, {id = "ancient_scroll", qty = 2}},
        goldCost = 200, craftTime = 10, skillRequired = 8,
        baseStats = {bonusDamage = 5},
        icon = "assets/icons/loot/Book.png",
    },
    {
        id = "tome_wisdom", name = "Tome of Wisdom", category = "tome",
        materials = {{id = "arcane_dust", qty = 5}, {id = "enchanted_ink", qty = 3}, {id = "ancient_scroll", qty = 2}},
        goldCost = 200, craftTime = 10, skillRequired = 8,
        baseStats = {bonusMana = 20},
        icon = "assets/icons/loot/Book.png",
    },
    {
        id = "tome_protection", name = "Tome of Protection", category = "tome",
        materials = {{id = "frost_essence", qty = 3}, {id = "mana_crystal", qty = 2}, {id = "enchanted_ink", qty = 3}, {id = "ancient_scroll", qty = 2}},
        goldCost = 250, craftTime = 12, skillRequired = 10,
        baseStats = {bonusDefense = 5},
        icon = "assets/icons/loot/Book.png",
    },

    -- Advanced Spells
    {
        id = "meteor_spell", name = "Meteor Strike Scroll", category = "spell",
        materials = {{id = "fire_essence", qty = 5}, {id = "mana_crystal", qty = 3}, {id = "phoenix_feather", qty = 1}, {id = "ancient_scroll", qty = 1}},
        goldCost = 300, craftTime = 12, skillRequired = 15,
        baseStats = {damage = 80, manaCost = 35},
        icon = "assets/icons/spells/S_Fire02.png",
    },
    {
        id = "resurrect_spell", name = "Resurrection Scroll", category = "spell",
        materials = {{id = "phoenix_feather", qty = 2}, {id = "mana_crystal", qty = 5}, {id = "enchanted_ink", qty = 2}, {id = "ancient_scroll", qty = 1}},
        goldCost = 500, craftTime = 15, skillRequired = 20,
        baseStats = {resurrectHealth = 50, manaCost = 50},
        icon = "assets/icons/spells/S_Holy02.png",
    },
}

-- Initialize UI components
local function initUIComponents()
    local screenW, screenH = love.graphics.getDimensions()

    -- Recipe list component
    state.recipeList = UI.List.new({
        x = 10,
        y = 180,
        w = 220,
        h = screenH - 230,
        items = RECIPES,
        selectedIndex = state.selectedRecipeIndex,
        onSelect = function(recipe, index)
            state.selectedRecipeIndex = index
        end,
        renderItem = function(recipe, x, y, w, h, isSelected)
            local catColors = {spell = {0.5, 0.7, 1}, tome = {0.9, 0.7, 0.3}}
            love.graphics.setColor(catColors[recipe.category] or {0.8, 0.8, 0.9})
            love.graphics.setFont(UI.fonts.get(12))
            love.graphics.print(recipe.name, x, y + 5)

            local canCraft = WizardTower.canCraft(recipe)
            love.graphics.setColor(canCraft and {0.3, 0.6, 0.3} or {0.6, 0.3, 0.3})
            love.graphics.print("Lv" .. (recipe.skillRequired or 0), x + w - 40, y + 8)
        end
    })

    -- Craft button
    local detailX = 250
    local detailY = 60
    local detailW = 300
    local detailH = 280
    state.craftButton = UI.Button.new({
        x = detailX + 15,
        y = detailY + detailH - 50,
        w = detailW - 30,
        h = 40,
        text = "INSCRIBE",
        variant = "primary",
        onClick = function()
            if not state.currentRecipe then
                local selectedRecipe = RECIPES[state.selectedRecipeIndex]
                if selectedRecipe then
                    WizardTower.startCraft(selectedRecipe)
                end
            end
        end
    })

    -- Mana progress bar
    state.manaProgressBar = UI.ProgressBar.new({
        x = screenW / 2 - 100,
        y = screenH - 100,
        w = 200,
        h = 40,
        value = 0,
        label = nil,
        colorOverride = {0.4, 0.3, 0.8}
    })

    -- Crafting progress bar
    state.craftingProgressBar = UI.ProgressBar.new({
        x = screenW / 2 - 100,
        y = 55,
        w = 190,
        h = 20,
        value = 0,
        label = nil,
        colorOverride = {0.5, 0.3, 0.8}
    })
end

-- Initialize wizard tower
function WizardTower.init()
    state.active = true
    state.craftingProgress = 0
    state.manaCharge = 0
    state.currentRecipe = nil
    state.craftedItem = nil
    state.showOutput = false
    state.selectedRecipeIndex = 1
    state.scrollOffset = 0
    state.chargeParticles = {}
    state.showEmployeePanel = false
    state.showUpgradePanel = false
    Backpack.init()

    -- Load saved data
    WizardTower.loadSaveData()

    -- Generate initial hiring pool if empty
    if #state.hiringPool == 0 then
        state.hiringPool = Employees.generateHiringPool("wizardtower", 3, WizardTower.getSkillLevel())
    end

    -- Calculate initial passive income rate
    WizardTower.updatePassiveIncomeRate()

    -- Initialize UI components
    initUIComponents()

    -- Register region resolver for tutorial system
    InteractiveTutorial.registerRegionResolver("wizardtower", WizardTower.getUIRegion)

    -- Start tutorial if not completed
    if not Tutorials.hasCompleted("wizardtower") then
        Tutorials.startTutorial("wizardtower")
    end
end

-- Load saved wizard tower data
function WizardTower.loadSaveData()
    if PlayerData.wizardtowerData then
        state.employees = Employees.load(PlayerData.wizardtowerData.employees)
        state.upgrades = UpgradeSystem.load(PlayerData.wizardtowerData.upgrades)
    else
        state.employees = {}
        state.upgrades = {}
    end
end

-- Save wizard tower data
function WizardTower.saveData()
    PlayerData.wizardtowerData = {
        employees = Employees.save(state.employees),
        upgrades = UpgradeSystem.save(state.upgrades),
    }
    savePlayerData()
end

-- Calculate and update passive income from wizard tower employees
function WizardTower.updatePassiveIncomeRate()
    local effects = UpgradeSystem.getCombinedEffects("wizardtower", state.upgrades)
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
    updatePassiveIncomeSource("wizardtower", totalRate)
end

-- Update wizard tower game
function WizardTower.update(dt)
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

    -- Update mana charge decay
    if state.manaCharge > 0 then
        state.manaCharge = state.manaCharge - dt * 3
        if state.manaCharge < 0 then state.manaCharge = 0 end
    end

    -- Update crafting progress
    if state.currentRecipe and state.manaCharge > 50 then
        state.craftingProgress = state.craftingProgress + dt
        if state.craftingProgress >= state.currentRecipe.craftTime then
            WizardTower.completeCraft()
        end
    end

    -- Update particles
    for i = #state.chargeParticles, 1, -1 do
        local p = state.chargeParticles[i]
        p.life = p.life - dt
        p.y = p.y - dt * 30
        p.alpha = p.life / p.maxLife
        if p.life <= 0 then
            table.remove(state.chargeParticles, i)
        end
    end

    -- Employee production (per-employee accumulators for fair attribution)
    for _, emp in ipairs(state.employees) do
        if emp.isHired and not emp.isDead then
            local efficiency = Employees.getEfficiency(emp)
            emp.craftProgress = (emp.craftProgress or 0) + (efficiency * 0.1 * dt)

            -- When this employee produces enough, auto-craft basic items
            if emp.craftProgress >= 1.0 then
                emp.craftProgress = emp.craftProgress - 1.0
                local goldEarned = math.floor(10 * efficiency)
                PlayerData.coins = PlayerData.coins + goldEarned
                emp.totalEarned = (emp.totalEarned or 0) + goldEarned
                emp.itemsCrafted = (emp.itemsCrafted or 0) + 1
            end
        end
    end

    -- Update UI components
    if state.recipeList then
        state.recipeList:update(dt)
    end
    if state.craftButton then
        state.craftButton:update(dt)
    end
    if state.manaProgressBar then
        state.manaProgressBar.value = state.manaCharge / 100
        state.manaProgressBar:update(dt)
    end
    if state.craftingProgressBar and state.currentRecipe then
        state.craftingProgressBar.value = state.craftingProgress / state.currentRecipe.craftTime
        state.craftingProgressBar:update(dt)
    end

    -- Update output panel buttons
    if state.showOutput and state.outputPanel then
        state.outputPanel:update(dt)
    end

    -- Employee panel uses shared EmployeeUI module, no per-frame updates needed

    -- Auto-save periodically
    state.lastSaveTime = state.lastSaveTime + dt
    if state.lastSaveTime >= 30 then
        WizardTower.saveData()
        state.lastSaveTime = 0
    end
end

-- Channel mana (minigame action)
function WizardTower.channelMana()
    state.manaCharge = math.min(100, state.manaCharge + 20)

    -- Add visual particles
    local screenW = love.graphics.getWidth()
    for i = 1, 3 do
        table.insert(state.chargeParticles, {
            x = screenW / 2 + math.random(-50, 50),
            y = love.graphics.getHeight() - 120 + math.random(-20, 20),
            life = 1,
            maxLife = 1,
            alpha = 1,
            color = {0.4 + math.random() * 0.3, 0.5 + math.random() * 0.3, 1},
        })
    end
end

-- Get current skill level
function WizardTower.getSkillLevel()
    return CraftingCore.getSkillLevel("wizardry")
end

-- Check if player can craft a recipe
function WizardTower.canCraft(recipe)
    return CraftingCore.canCraft(recipe, WizardTower.getSkillLevel())
end

-- Start crafting a recipe
function WizardTower.startCraft(recipe)
    local canCraft, reason = WizardTower.canCraft(recipe)
    if canCraft then
        CraftingCore.consumeMaterials(recipe)
        state.currentRecipe = recipe
        state.craftingProgress = 0
        state.showOutput = false
        return true
    else
        state.notification = reason
        state.notificationTimer = 2
        return false
    end
end

-- Complete crafting
function WizardTower.completeCraft()
    if state.currentRecipe then
        -- Quality based on mana charge level
        local qualityScore = state.manaCharge
        local quality = CraftingCore.getQualityFromScore(qualityScore)

        -- Roll for rarity
        local rarity = CraftingCore.rollRarity()

        -- Create the crafted item
        state.craftedItem = CraftingCore.createCraftedItem(state.currentRecipe, rarity, quality)

        -- Award XP
        local xpGained = CraftingCore.awardCraftingXP(state.currentRecipe, "wizardry")
        Progression.addXP(xpGained, "wizard")

        state.currentRecipe = nil
        state.craftingProgress = 0
        state.showOutput = true

        state.notification = "Created " .. state.craftedItem.name .. "!"
        state.notificationTimer = 3

        -- Create output panel with buttons
        WizardTower.createOutputPanel()
    end
end

-- Create output panel dynamically
function WizardTower.createOutputPanel()
    local screenW, screenH = love.graphics.getDimensions()
    local panelW, panelH = 350, 280
    local panelX = screenW / 2 - panelW / 2
    local panelY = screenH / 2 - panelH / 2
    local optionY = panelY + panelH - 140

    local sellButton = UI.Button.new({
        x = panelX + 20,
        y = optionY,
        w = panelW - 40,
        h = 35,
        text = "Sell for " .. CraftingCore.getSellValue(state.craftedItem) .. " gold",
        variant = "primary",
        onClick = function()
            WizardTower.handleOutputChoice(1)
        end
    })

    local keepButton = UI.Button.new({
        x = panelX + 20,
        y = optionY + 40,
        w = panelW - 40,
        h = 35,
        text = "Keep in Backpack",
        variant = "secondary",
        onClick = function()
            WizardTower.handleOutputChoice(2)
        end
    })

    local marketButton = UI.Button.new({
        x = panelX + 20,
        y = optionY + 80,
        w = panelW - 40,
        h = 35,
        text = "List on Market",
        variant = "secondary",
        onClick = function()
            WizardTower.handleOutputChoice(3)
        end
    })

    state.outputPanel = UI.Group.new({sellButton, keepButton, marketButton})
end

-- Handle output choice
function WizardTower.handleOutputChoice(choice)
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
    state.outputPanel = nil
end

-- Draw the wizard tower
function WizardTower.draw()
    local screenW, screenH = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()

    UIAssets.clearTooltip()

    -- Draw background image if available
    if not UIAssets.drawGameBackground("wizardtower", 1) then
        -- Fallback: Background (mystical tower interior)
        love.graphics.setColor(0.1, 0.1, 0.2)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)

        -- Starry background effect
        love.graphics.setColor(0.3, 0.3, 0.5, 0.5)
        for i = 1, 50 do
            local x = (i * 37) % screenW
            local y = (i * 53 + math.sin(love.timer.getTime() + i) * 5) % screenH
            love.graphics.circle("fill", x, y, 1 + math.sin(love.timer.getTime() * 2 + i) * 0.5)
        end
    end

    -- Dark overlay
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Draw mana particles
    for _, p in ipairs(state.chargeParticles) do
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], p.alpha)
        love.graphics.circle("fill", p.x, p.y, 4)
    end

    -- Stats panel
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 10, 10, 220, 130, 8, 8)

    love.graphics.setColor(0.6, 0.4, 1)
    love.graphics.setFont(UI.fonts.get(20))
    love.graphics.print("WIZARD TOWER", 20, 15)

    UIAssets.drawCurrencyWithTooltip("coins", PlayerData.coins, 20, 45, 16)

    love.graphics.setColor(0.8, 0.8, 1)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.print("Wizardry Level: " .. WizardTower.getSkillLevel(), 20, 70)

    -- Show some materials
    love.graphics.setColor(0.7, 0.7, 0.9)
    love.graphics.print("Mana Crystal: " .. Backpack.getItemCount("mana_crystal"), 20, 90)
    love.graphics.print("Fire Ess: " .. Backpack.getItemCount("fire_essence"), 130, 90)
    love.graphics.print("Arcane Dust: " .. Backpack.getItemCount("arcane_dust"), 20, 110)
    love.graphics.print("Scrolls: " .. Backpack.getItemCount("ancient_scroll"), 130, 110)

    -- Recipe list header
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 10, 150, 220, 30, 8, 8)
    love.graphics.setColor(0.8, 0.6, 1)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.print("SPELL RECIPES", 20, 158)

    -- Draw recipe list component
    if state.recipeList then
        state.recipeList:draw()
    end

    -- Recipe details panel
    local detailX = 250
    local detailY = 60
    local detailW = 300
    local detailH = 280

    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", detailX, detailY, detailW, detailH, 8, 8)

    local selectedRecipe = RECIPES[state.selectedRecipeIndex]
    if selectedRecipe then
        love.graphics.setColor(0.8, 0.7, 1)
        love.graphics.setFont(UI.fonts.get(18))
        love.graphics.print(selectedRecipe.name, detailX + 15, detailY + 10)

        love.graphics.setColor(0.5, 0.5, 0.7)
        love.graphics.setFont(UI.fonts.get(11))
        love.graphics.print(selectedRecipe.category:upper(), detailX + 15, detailY + 35)

        love.graphics.setColor(0.9, 0.9, 1)
        love.graphics.setFont(UI.fonts.get(12))
        love.graphics.print("Materials:", detailX + 15, detailY + 60)

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

        love.graphics.setColor(0.7, 0.7, 0.9)
        love.graphics.print("Skill Required: " .. (selectedRecipe.skillRequired or 0), detailX + 15, detailY + 100 + matCount * 18)

        love.graphics.setColor(0.6, 0.8, 1)
        love.graphics.print("Effects:", detailX + 15, detailY + 125 + matCount * 18)
        local statY = detailY + 140 + matCount * 18
        for statName, statValue in pairs(selectedRecipe.baseStats or {}) do
            love.graphics.print("  " .. statName .. ": " .. statValue, detailX + 20, statY)
            statY = statY + 15
        end

        -- Update and draw craft button
        if state.craftButton then
            local canCraft, reason = WizardTower.canCraft(selectedRecipe)

            if state.currentRecipe then
                state.craftButton.text = "CHANNELING..."
                state.craftButton.disabled = true
            elseif canCraft then
                state.craftButton.text = "INSCRIBE"
                state.craftButton.disabled = false
            else
                state.craftButton.text = reason or "Cannot Craft"
                state.craftButton.disabled = true
            end

            state.craftButton:draw()
        end
    end

    -- Mana charge meter with label
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.print("Mana Channel", screenW / 2 - 45, screenH - 120)

    if state.manaProgressBar then
        -- Update color based on charge level
        if state.manaCharge > 80 then
            state.manaProgressBar.colorOverride = {0.6, 0.4, 1}
        elseif state.manaCharge > 50 then
            state.manaProgressBar.colorOverride = {0.4, 0.3, 0.8}
        elseif state.manaCharge > 20 then
            state.manaProgressBar.colorOverride = {0.3, 0.25, 0.6}
        else
            state.manaProgressBar.colorOverride = {0.2, 0.2, 0.4}
        end
        state.manaProgressBar:draw()
    end

    -- Crafting progress
    if state.currentRecipe then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", screenW / 2 - 100, 50, 200, 50, 8, 8)

        if state.craftingProgressBar then
            state.craftingProgressBar:draw()
        end

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.fonts.get(12))
        love.graphics.print("Inscribing: " .. state.currentRecipe.name, screenW / 2 - 65, 80)
    end

    -- Output options panel
    if state.showOutput and state.craftedItem then
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)

        local panelW, panelH = 350, 280
        local panelX = screenW / 2 - panelW / 2
        local panelY = screenH / 2 - panelH / 2

        love.graphics.setColor(0.12, 0.12, 0.2)
        love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)
        love.graphics.setColor(0.5, 0.4, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 10, 10)
        love.graphics.setLineWidth(1)

        love.graphics.setColor(0.8, 0.7, 1)
        love.graphics.setFont(UI.fonts.get(18))
        love.graphics.print("SPELL CREATED!", panelX + 20, panelY + 15)

        CraftingCore.drawRarityText(state.craftedItem.name, panelX + 20, panelY + 50, state.craftedItem.rarity)

        love.graphics.setFont(UI.fonts.get(12))
        CraftingCore.drawQualityText("Quality: " .. CraftingCore.getQuality(state.craftedItem.quality).name, panelX + 20, panelY + 75, state.craftedItem.quality)

        love.graphics.setColor(0.7, 0.8, 1)
        love.graphics.print("Effects:", panelX + 20, panelY + 100)
        local statY = panelY + 118
        for statName, statValue in pairs(state.craftedItem.finalStats or {}) do
            love.graphics.print("  " .. statName .. ": " .. statValue, panelX + 25, statY)
            statY = statY + 16
        end

        -- Draw output panel buttons
        if state.outputPanel then
            state.outputPanel:draw()
        end
    end

    -- Notification
    if state.notification then
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", screenW / 2 - 150, 120, 300, 40, 8, 8)
        love.graphics.setColor(0.8, 0.7, 1)
        love.graphics.setFont(UI.fonts.get(14))
        love.graphics.printf(state.notification, screenW / 2 - 145, 130, 290, "center")
    end

    -- Employee count indicator (top right)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", screenW - 130, 10, 120, 50, 6, 6)
    love.graphics.setColor(0.7, 0.5, 1)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.print("Apprentices: " .. #state.employees, screenW - 120, 18)
    -- Show passive income from employees
    local totalEfficiency = 0
    for _, emp in ipairs(state.employees) do
        if emp.isHired and not emp.isDead then
            totalEfficiency = totalEfficiency + Employees.getEfficiency(emp)
        end
    end
    love.graphics.setColor(0.4, 0.8, 0.4)
    love.graphics.print(string.format("+%.1f gold/s", totalEfficiency * 0.1), screenW - 120, 35)

    -- Instructions
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.print("[SPACE] Channel Mana  [B] Backpack  [E] Employees  [ESC] Exit", screenW / 2 - 200, screenH - 30)

    -- Draw employee panel if open
    if state.showEmployeePanel then
        EmployeeUI.drawEmployeePanel(screenW, screenH, mx, my, "wizardtower", state.employees, state.hiringPool, state.upgrades)
    end

    UIAssets.drawTooltip()

    -- Draw tutorial overlay
    Tutorials.draw()

    -- Reset color
    love.graphics.setColor(1, 1, 1, 1)
end

-- Handle mouse press
function WizardTower.mousepressed(x, y, button)
    if button ~= 1 then return end

    -- Handle tutorial clicks first
    if Tutorials.isActive() then
        Tutorials.mousepressed(x, y, button)
        return
    end

    local screenW, screenH = love.graphics.getDimensions()

    -- Handle employee panel clicks
    if state.showEmployeePanel then
        local action, idx = EmployeeUI.handleEmployeePanelClick(x, y, "wizardtower", state.employees, state.hiringPool, state.upgrades)
        if action == "fire" then
            WizardTower.fireEmployee(idx)
        elseif action == "hire" then
            WizardTower.hireEmployee(idx)
        end
        return
    end

    -- Handle output panel clicks
    if state.showOutput and state.outputPanel then
        if state.outputPanel:mousepressed(x, y, button) then
            return
        end
        return
    end

    -- Recipe list clicks
    if state.recipeList then
        if state.recipeList:mousepressed(x, y, button) then
            return
        end
    end

    -- Craft button
    if state.craftButton then
        if state.craftButton:mousepressed(x, y, button) then
            return
        end
    end
end

-- Handle mouse release
function WizardTower.mousereleased(x, y, button)
    if button ~= 1 then return end

    -- Handle output panel
    if state.showOutput and state.outputPanel then
        state.outputPanel:mousereleased(x, y, button)
        return
    end

    -- Handle recipe list
    if state.recipeList then
        state.recipeList:mousereleased(x, y, button)
    end

    -- Handle craft button
    if state.craftButton then
        state.craftButton:mousereleased(x, y, button)
    end
end

-- Handle mouse movement
function WizardTower.mousemoved(x, y, dx, dy)
    if state.recipeList then
        state.recipeList:mousemoved(x, y, dx, dy)
    end
end

-- Handle key press
function WizardTower.keypressed(key)
    -- Handle tutorial keypresses first
    if Tutorials.isActive() then
        Tutorials.keypressed(key)
        return
    end

    if key == "space" then
        WizardTower.channelMana()
    elseif key == "b" then
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
            state.outputPanel = nil
        elseif state.showEmployeePanel then
            state.showEmployeePanel = false
        elseif state.showUpgradePanel then
            state.showUpgradePanel = false
        else
            WizardTower.saveData()
            state.active = false
            return "menu"
        end
    elseif key == "up" then
        state.selectedRecipeIndex = math.max(1, state.selectedRecipeIndex - 1)
        if state.recipeList then
            state.recipeList.selectedIndex = state.selectedRecipeIndex
        end
    elseif key == "down" then
        state.selectedRecipeIndex = math.min(#RECIPES, state.selectedRecipeIndex + 1)
        if state.recipeList then
            state.recipeList.selectedIndex = state.selectedRecipeIndex
        end
    elseif key == "return" or key == "kpenter" then
        if not state.currentRecipe and not state.showOutput then
            local selectedRecipe = RECIPES[state.selectedRecipeIndex]
            if selectedRecipe then
                WizardTower.startCraft(selectedRecipe)
            end
        end
    end
end

-- Handle scroll
function WizardTower.wheelmoved(x, y)
    if state.recipeList then
        state.recipeList:wheelmoved(x, y)
    end
end

function WizardTower.isActive()
    return state.active
end

function WizardTower.exit()
    WizardTower.saveData()
    state.active = false
end

-- Hire an employee from the pool
function WizardTower.hireEmployee(index)
    -- Check if player owns this building
    if PlayerData.currentBuildingOwned ~= true then
        state.notification = "You must own this tower to hire apprentices!"
        state.notificationTimer = 2
        return false
    end

    local emp = state.hiringPool[index]
    if not emp then return false end

    local empType = Employees.getType(emp.employeeType)
    if not empType then return false end

    -- Check max employees from upgrades
    local effects = UpgradeSystem.getCombinedEffects("wizardtower", state.upgrades)
    local maxEmployees = effects.maxEmployees or 1

    if #state.employees >= maxEmployees then
        state.notification = "Max apprentices reached! Upgrade capacity."
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
    local newCandidates = Employees.generateHiringPool("wizardtower", 1, WizardTower.getSkillLevel())
    if #newCandidates > 0 then
        table.insert(state.hiringPool, newCandidates[1])
    end

    state.notification = "Hired " .. emp.name .. "!"
    state.notificationTimer = 2
    -- Update global passive income rate
    WizardTower.updatePassiveIncomeRate()
    WizardTower.saveData()
    return true
end

-- Fire an employee
function WizardTower.fireEmployee(index)
    local emp = state.employees[index]
    if emp then
        table.remove(state.employees, index)
        state.notification = "Dismissed " .. emp.name
        state.notificationTimer = 2
        -- Update global passive income rate
        WizardTower.updatePassiveIncomeRate()
        WizardTower.saveData()
        return true
    end
    return false
end

-- Draw employee panel (delegated to shared EmployeeUI module)
function WizardTower.drawEmployeePanel(screenW, screenH, mx, my)
    EmployeeUI.drawEmployeePanel(screenW, screenH, mx, my, "wizardtower", state.employees, state.hiringPool, state.upgrades)
end

-- Get UI region coordinates for interactive tutorials
function WizardTower.getUIRegion(regionId)
    local screenW, screenH = love.graphics.getDimensions()
    local regions = {
        -- Materials display (in stats panel, shows key materials)
        materials_display = {x = 10, y = 85, w = 220, h = 50},
        -- Mana meter (bottom center, shows charging level)
        mana_meter = {x = screenW / 2 - 100, y = screenH - 100, w = 200, h = 40},
        -- Recipe list (left panel, scrollable recipe list)
        recipe_list = {x = 10, y = 150, w = 220, h = screenH - 200},
    }
    return regions[regionId]
end

return WizardTower
