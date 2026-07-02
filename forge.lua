-- Forge Game Mode - Craft weapons, armor, and traps!
-- A blacksmithing minigame with crafting, upgrading, and selling

local Forge = {}
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

-- Use UI library font cache
local function getFont(size)
    return UI.fonts.get(size)
end

-- Game state
local state = {
    active = false,
    currentRecipe = nil,
    craftingProgress = 0,
    forgeHeat = 0,
    craftedItem = nil,      -- Last crafted item awaiting disposition
    showOutput = false,     -- Show output options panel
    selectedRecipeIndex = 1,
    scrollOffset = 0,
    notification = nil,
    notificationTimer = 0,

    -- Employee system
    employees = {},           -- Hired employees
    hiringPool = {},          -- Available employees to hire
    showEmployeePanel = false,
    employeeProduction = 0,   -- Accumulated production from employees

    -- Upgrade system
    upgrades = {},            -- {upgradeId = level}
    currentBuild = nil,       -- Current upgrade being built
    showUpgradePanel = false,

    -- Time tracking
    lastSaveTime = 0,
    daysPassed = 0,
    season = "frosthollow",

    -- UI Components
    recipeList = nil,
    craftButton = nil,
    heatMeter = nil,
    craftingProgressBar = nil,
}

-- Crafting recipes for the forge
local RECIPES = {
    -- Basic weapons
    {
        id = "iron_sword", name = "Iron Sword", category = "weapon",
        materials = {{id = "iron_ore", qty = 3}, {id = "wood_planks", qty = 1}},
        goldCost = 20, craftTime = 5, skillRequired = 0,
        baseStats = {damage = 10},
        icon = "assets/icons/weapons/W_Sword001.png",
    },
    {
        id = "iron_dagger", name = "Iron Dagger", category = "weapon",
        materials = {{id = "iron_ore", qty = 2}, {id = "leather_scraps", qty = 1}},
        goldCost = 15, craftTime = 3, skillRequired = 0,
        baseStats = {damage = 8},
        icon = "assets/icons/weapons/W_Dagger001.png",
    },
    {
        id = "steel_sword", name = "Steel Sword", category = "weapon",
        materials = {{id = "steel_ingot", qty = 4}, {id = "wood_planks", qty = 1}, {id = "leather_scraps", qty = 1}},
        goldCost = 80, craftTime = 8, skillRequired = 5,
        baseStats = {damage = 18},
        icon = "assets/icons/weapons/W_Sword002.png",
    },
    {
        id = "steel_axe", name = "Steel Battleaxe", category = "weapon",
        materials = {{id = "steel_ingot", qty = 6}, {id = "wood_planks", qty = 2}},
        goldCost = 100, craftTime = 10, skillRequired = 8,
        baseStats = {damage = 22},
        icon = "assets/icons/weapons/W_Axe001.png",
    },
    {
        id = "mythril_blade", name = "Mythril Blade", category = "weapon",
        materials = {{id = "mythril_shard", qty = 3}, {id = "steel_ingot", qty = 2}, {id = "dragon_scale", qty = 1}},
        goldCost = 500, craftTime = 15, skillRequired = 15,
        baseStats = {damage = 35},
        icon = "assets/icons/weapons/W_Sword003.png",
    },

    -- Armor
    {
        id = "leather_armor", name = "Leather Armor", category = "armor",
        materials = {{id = "leather_scraps", qty = 5}},
        goldCost = 25, craftTime = 4, skillRequired = 0,
        baseStats = {defense = 5},
        icon = "assets/icons/armor/A_Armor01.png",
    },
    {
        id = "iron_helmet", name = "Iron Helmet", category = "armor",
        materials = {{id = "iron_ore", qty = 4}, {id = "leather_scraps", qty = 1}},
        goldCost = 30, craftTime = 5, skillRequired = 2,
        baseStats = {defense = 4},
        icon = "assets/icons/armor/A_Helm01.png",
    },
    {
        id = "chainmail", name = "Chainmail", category = "armor",
        materials = {{id = "iron_ore", qty = 8}, {id = "leather_scraps", qty = 2}},
        goldCost = 60, craftTime = 8, skillRequired = 5,
        baseStats = {defense = 12},
        icon = "assets/icons/armor/A_Armor02.png",
    },
    {
        id = "steel_shield", name = "Steel Shield", category = "armor",
        materials = {{id = "steel_ingot", qty = 5}, {id = "leather_scraps", qty = 2}},
        goldCost = 70, craftTime = 7, skillRequired = 6,
        baseStats = {defense = 8, blockChance = 15},
        icon = "assets/icons/armor/E_Shield01.png",
    },
    {
        id = "plate_armor", name = "Plate Armor", category = "armor",
        materials = {{id = "steel_ingot", qty = 15}, {id = "leather_scraps", qty = 5}},
        goldCost = 200, craftTime = 15, skillRequired = 12,
        baseStats = {defense = 25},
        icon = "assets/icons/armor/A_Armor03.png",
    },

    -- Traps
    {
        id = "spike_trap", name = "Spike Trap", category = "trap",
        materials = {{id = "iron_ore", qty = 3}, {id = "wood_planks", qty = 2}},
        goldCost = 25, craftTime = 4, skillRequired = 3,
        baseStats = {damage = 15},
        icon = "assets/icons/weapons/W_Throw001.png",
    },
    {
        id = "bear_trap", name = "Bear Trap", category = "trap",
        materials = {{id = "steel_ingot", qty = 4}, {id = "leather_scraps", qty = 1}},
        goldCost = 45, craftTime = 6, skillRequired = 7,
        baseStats = {damage = 10, stunDuration = 3},
        icon = "assets/icons/weapons/W_Throw002.png",
    },
}

-- Initialize forge
function Forge.init()
    state.active = true
    state.craftingProgress = 0
    state.forgeHeat = 0
    state.currentRecipe = nil
    state.craftedItem = nil
    state.showOutput = false
    state.selectedRecipeIndex = 1
    state.scrollOffset = 0
    state.showEmployeePanel = false
    state.showUpgradePanel = false
    Backpack.init()

    -- Load saved data
    Forge.loadSaveData()

    -- Generate initial hiring pool if empty
    if #state.hiringPool == 0 then
        state.hiringPool = Employees.generateHiringPool("forge", 3, Forge.getSkillLevel())
    end

    -- Calculate initial passive income rate
    Forge.updatePassiveIncomeRate()

    -- Register region resolver for interactive tutorial
    InteractiveTutorial.registerRegionResolver("forge", Forge.getUIRegion)

    -- Start tutorial if not completed
    if not Tutorials.hasCompleted("forge") then
        Tutorials.startTutorial("forge")
    end

    -- Initialize UI components
    Forge.initUIComponents()
end

-- Initialize UI components
function Forge.initUIComponents()
    local screenW, screenH = love.graphics.getDimensions()

    -- Recipe list (left panel)
    local recipeX = 10
    local recipeY = 150
    local recipeW = 220
    local recipeH = screenH - 200

    state.recipeList = UI.List.new({
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
            -- Recipe name with category color
            local catColors = {weapon = {0.9, 0.5, 0.3}, armor = {0.4, 0.6, 0.9}, trap = {0.6, 0.3, 0.6}}
            love.graphics.setColor(catColors[recipe.category] or {0.8, 0.8, 0.8})
            love.graphics.setFont(getFont(12))
            love.graphics.print(recipe.name, x + 5, y + 5)

            -- Skill requirement indicator
            local canCraft = Forge.canCraft(recipe)
            if not canCraft then
                love.graphics.setColor(0.6, 0.3, 0.3)
            else
                love.graphics.setColor(0.3, 0.6, 0.3)
            end
            love.graphics.print("Lv" .. (recipe.skillRequired or 0), x + w - 45, y + 8)
        end
    })
    state.recipeList.itemHeight = 35

    -- Craft button
    local detailX = 250
    local detailY = 60
    local detailW = 300
    local detailH = 280
    local craftBtnX = detailX + 15
    local craftBtnY = detailY + detailH - 50

    state.craftButton = UI.Button.new({
        x = craftBtnX,
        y = craftBtnY,
        w = detailW - 30,
        h = 40,
        text = "CRAFT",
        variant = "success",
        disabled = false,
        onClick = function()
            if not state.currentRecipe then
                local selectedRecipe = RECIPES[state.selectedRecipeIndex]
                if selectedRecipe then
                    Forge.startCraft(selectedRecipe)
                end
            end
        end
    })

    -- Heat meter (progress bar)
    local heatX = screenW / 2 - 100
    local heatY = screenH - 100

    state.heatMeter = UI.ProgressBar.new({
        x = heatX + 5,
        y = heatY + 5,
        w = 190,
        h = 30,
        value = 0,
        label = nil,
        colorOverride = nil
    })

    -- Crafting progress bar
    state.craftingProgressBar = UI.ProgressBar.new({
        x = screenW / 2 - 95,
        y = 55,
        w = 190,
        h = 20,
        value = 0,
        label = nil,
        colorOverride = {0.2, 0.7, 0.2}
    })
end

-- Update UI component positions (call when screen resizes or needed)
function Forge.updateUIComponentPositions()
    if not state.recipeList or not state.craftButton or not state.heatMeter or not state.craftingProgressBar then
        return
    end

    local screenW, screenH = love.graphics.getDimensions()

    -- Update recipe list position
    local recipeX = 10
    local recipeY = 150
    local recipeW = 220
    local recipeH = screenH - 200

    state.recipeList.x = recipeX
    state.recipeList.y = recipeY + 30
    state.recipeList.w = recipeW
    state.recipeList.h = recipeH - 40
    if state.recipeList.scrollContainer then
        state.recipeList.scrollContainer.x = recipeX
        state.recipeList.scrollContainer.y = recipeY + 30
        state.recipeList.scrollContainer.w = recipeW
        state.recipeList.scrollContainer.h = recipeH - 40
    end

    -- Update craft button position
    local detailX = 250
    local detailY = 60
    local detailW = 300
    local detailH = 280
    local craftBtnX = detailX + 15
    local craftBtnY = detailY + detailH - 50

    state.craftButton.x = craftBtnX
    state.craftButton.y = craftBtnY

    -- Update heat meter position
    local heatX = screenW / 2 - 100
    local heatY = screenH - 100

    state.heatMeter.x = heatX + 5
    state.heatMeter.y = heatY + 5

    -- Update crafting progress bar position
    state.craftingProgressBar.x = screenW / 2 - 95
    state.craftingProgressBar.y = 55
end

-- Load saved forge data
function Forge.loadSaveData()
    if PlayerData.forgeData then
        state.employees = Employees.load(PlayerData.forgeData.employees)
        state.upgrades = UpgradeSystem.load(PlayerData.forgeData.upgrades)
        state.currentBuild = PlayerData.forgeData.currentBuild
        state.daysPassed = PlayerData.forgeData.daysPassed or 0
        state.season = PlayerData.forgeData.season or "frosthollow"
        state.employeeProduction = PlayerData.forgeData.employeeProduction or 0
    else
        state.employees = {}
        state.upgrades = {}
        state.currentBuild = nil
        state.daysPassed = 0
        state.season = "frosthollow"
        state.employeeProduction = 0
    end
end

-- Save forge data
function Forge.saveData()
    PlayerData.forgeData = {
        employees = Employees.save(state.employees),
        upgrades = UpgradeSystem.save(state.upgrades),
        currentBuild = state.currentBuild,
        daysPassed = state.daysPassed,
        season = state.season,
        employeeProduction = state.employeeProduction,
    }
    savePlayerData()
end

-- Calculate and update passive income from forge employees
function Forge.updatePassiveIncomeRate()
    local effects = UpgradeSystem.getCombinedEffects("forge", state.upgrades)
    local totalRate = 0

    -- Calculate income from all hired employees
    for _, emp in ipairs(state.employees) do
        if emp.isHired and not emp.isDead then
            local efficiency = Employees.getEfficiency(emp)
            -- Base rate: efficiency * 0.1 gold per second (forge base rate)
            local empRate = efficiency * 0.1
            -- Apply quality bonus from upgrades (better items = more value)
            empRate = empRate * (1 + (effects.qualityBonus or 0) * 0.01)
            totalRate = totalRate + empRate
        end
    end

    -- Use global helper to update passive income
    updatePassiveIncomeSource("forge", totalRate)
end

-- Update forge game
function Forge.update(dt)
    if not state.active then return end

    -- Update tutorial
    Tutorials.update(dt)

    -- Update UI components
    if state.recipeList then
        state.recipeList.items = RECIPES
        state.recipeList.selectedIndex = state.selectedRecipeIndex
        state.recipeList:update(dt)
    end

    if state.craftButton then
        local selectedRecipe = RECIPES[state.selectedRecipeIndex]
        local canCraft = selectedRecipe and Forge.canCraft(selectedRecipe)

        if state.currentRecipe then
            state.craftButton.text = "CRAFTING..."
            state.craftButton.disabled = true
            state.craftButton.variant = "ghost"
        elseif canCraft then
            state.craftButton.text = "CRAFT"
            state.craftButton.disabled = false
            state.craftButton.variant = "success"
        else
            local _, reason = Forge.canCraft(selectedRecipe)
            state.craftButton.text = reason or "Cannot Craft"
            state.craftButton.disabled = true
            state.craftButton.variant = "danger"
        end
        state.craftButton:update(dt)
    end

    if state.heatMeter then
        state.heatMeter.value = state.forgeHeat / 100
        -- Dynamic color based on heat
        if state.forgeHeat > 80 then
            state.heatMeter.colorOverride = {1, 0.2, 0}
        elseif state.forgeHeat > 50 then
            state.heatMeter.colorOverride = {1, 0.6, 0}
        elseif state.forgeHeat > 20 then
            state.heatMeter.colorOverride = {0.8, 0.4, 0}
        else
            state.heatMeter.colorOverride = {0.3, 0.3, 0.3}
        end
        state.heatMeter:update(dt)
    end

    if state.craftingProgressBar and state.currentRecipe then
        state.craftingProgressBar.value = state.craftingProgress / state.currentRecipe.craftTime
        state.craftingProgressBar:update(dt)
    end

    -- Update notification timer
    if state.notification then
        state.notificationTimer = state.notificationTimer - dt
        if state.notificationTimer <= 0 then
            state.notification = nil
        end
    end

    -- Update forge heat (needs to stay hot for crafting)
    if state.forgeHeat > 0 then
        state.forgeHeat = state.forgeHeat - dt * 5
        if state.forgeHeat < 0 then state.forgeHeat = 0 end
    end

    -- Employee production: employees slowly craft actual items based on their level
    for _, emp in ipairs(state.employees) do
        if emp.isHired and not emp.isDead then
            local efficiency = Employees.getEfficiency(emp)
            local empLevel = emp.level or 1

            -- Production rate scales with efficiency (base 10 seconds per item at efficiency 1.0)
            -- Higher level employees work faster
            local productionRate = efficiency * (1 + empLevel * 0.1) * 0.1
            emp.craftProgress = (emp.craftProgress or 0) + (productionRate * dt)

            -- When employee completes an item (every ~10 seconds at base rate)
            if emp.craftProgress >= 1.0 then
                emp.craftProgress = emp.craftProgress - 1.0

                -- Select a recipe the employee can craft based on their level
                local craftableRecipes = {}
                for _, recipe in ipairs(RECIPES) do
                    if (recipe.skillRequired or 0) <= empLevel then
                        table.insert(craftableRecipes, recipe)
                    end
                end

                if #craftableRecipes > 0 then
                    -- Pick a random craftable recipe
                    local recipe = craftableRecipes[math.random(#craftableRecipes)]

                    -- Quality based on employee level (higher level = better quality chance)
                    local qualityScore = 40 + empLevel * 10 + math.random(20)
                    qualityScore = math.min(100, qualityScore)
                    local quality = CraftingCore.getQualityFromScore(qualityScore)

                    -- Rarity based on employee level (small bonus to better rarities)
                    local rarityWeights = {
                        common = math.max(0.1, 0.50 - empLevel * 0.03),
                        uncommon = 0.30 + empLevel * 0.01,
                        rare = 0.15 + empLevel * 0.01,
                        epic = 0.04 + empLevel * 0.005,
                        legendary = 0.01 + empLevel * 0.002,
                    }
                    local rarity = CraftingCore.rollRarity(rarityWeights)

                    -- Create the crafted item
                    local craftedItem = CraftingCore.createCraftedItem(recipe, rarity, quality)

                    -- Calculate sell value and add to earnings
                    local sellValue = CraftingCore.getSellValue(craftedItem)
                    PlayerData.coins = PlayerData.coins + sellValue
                    emp.totalEarned = (emp.totalEarned or 0) + sellValue
                    emp.itemsCrafted = (emp.itemsCrafted or 0) + 1

                    -- Store last crafted item for display
                    emp.lastCraftedItem = craftedItem.name
                    emp.lastCraftedRarity = rarity.id
                    emp.lastCraftedQuality = quality.id

                    -- Notification when in forge mode
                    if state.active then
                        local rarityName = rarity.name or "Common"
                        local qualityName = quality.name or "Good"
                        state.notification = emp.name .. " crafted " .. qualityName .. " " .. rarityName .. " " .. recipe.name .. " (+" .. sellValue .. "g)"
                        state.notificationTimer = 2
                    end
                end
            end
        end
    end

    -- Check upgrade completion
    if state.currentBuild and UpgradeSystem.isComplete(state.currentBuild) then
        state.upgrades[state.currentBuild.upgradeId] = state.currentBuild.targetLevel
        state.notification = "Upgrade complete: " .. state.currentBuild.upgradeId
        state.notificationTimer = 3
        state.currentBuild = nil
        Forge.saveData()
    end

    -- Auto-save periodically
    state.lastSaveTime = state.lastSaveTime + dt
    if state.lastSaveTime >= 30 then
        Forge.saveData()
        state.lastSaveTime = 0
    end

    -- Update crafting progress
    if state.currentRecipe and state.forgeHeat > 50 then
        state.craftingProgress = state.craftingProgress + dt
        if state.craftingProgress >= state.currentRecipe.craftTime then
            Forge.completeCraft()
        end
    end
end

-- Pump bellows to heat forge
function Forge.pumpBellows()
    state.forgeHeat = math.min(100, state.forgeHeat + 15)
end

-- Get current skill level
function Forge.getSkillLevel()
    return CraftingCore.getSkillLevel("forging")
end

-- Check if player can craft a recipe
function Forge.canCraft(recipe)
    return CraftingCore.canCraft(recipe, Forge.getSkillLevel())
end

-- Start crafting a recipe
function Forge.startCraft(recipe)
    local canCraft, reason = Forge.canCraft(recipe)
    if canCraft then
        -- Consume materials
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
function Forge.completeCraft()
    if state.currentRecipe then
        -- Calculate quality based on heat level
        local qualityScore = state.forgeHeat
        local quality = CraftingCore.getQualityFromScore(qualityScore)

        -- Roll for rarity
        local rarity = CraftingCore.rollRarity()

        -- Create the crafted item
        state.craftedItem = CraftingCore.createCraftedItem(state.currentRecipe, rarity, quality)

        -- Award XP
        local xpGained = CraftingCore.awardCraftingXP(state.currentRecipe, "forging")
        Progression.addXP(xpGained, "forge")

        state.currentRecipe = nil
        state.craftingProgress = 0
        state.showOutput = true

        state.notification = "Crafted " .. state.craftedItem.name .. "!"
        state.notificationTimer = 3
    end
end

-- Handle output choice
function Forge.handleOutputChoice(choice)
    if not state.craftedItem then return end

    if choice == 1 then
        -- Sell Now
        local value = CraftingCore.sellItem(state.craftedItem)
        state.notification = "Sold for " .. value .. " gold!"
        state.notificationTimer = 2
    elseif choice == 2 then
        -- Keep in backpack
        CraftingCore.keepItem(state.craftedItem)
        state.notification = "Added to backpack!"
        state.notificationTimer = 2
    elseif choice == 3 then
        -- List on market (default price = 1.5x sell value)
        local basePrice = CraftingCore.getSellValue(state.craftedItem)
        CraftingCore.listOnMarket(state.craftedItem, math.floor(basePrice * 1.5))
        state.notification = "Listed on market!"
        state.notificationTimer = 2
    end

    state.craftedItem = nil
    state.showOutput = false
end

-- Draw the forge game
function Forge.draw()
    local screenW, screenH = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()

    -- Update UI component positions (handles screen resize)
    Forge.updateUIComponentPositions()

    -- Clear tooltip state
    UIAssets.clearTooltip()

    -- Draw background
    if not UIAssets.drawGameBackground("forge", 1) then
        -- Fallback gradient background
        love.graphics.setColor(0.3, 0.2, 0.1)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
        love.graphics.setColor(0.5, 0.3, 0.1)
        love.graphics.rectangle("fill", 0, screenH * 0.6, screenW, screenH * 0.4)
    end

    -- Draw dark overlay for readability
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Draw UI panel (left side - stats)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 10, 10, 220, 130, 8, 8)

    love.graphics.setColor(1, 0.8, 0.3)
    love.graphics.setFont(getFont(20))
    love.graphics.print("FORGE", 20, 15)

    -- Currency displays with tooltips
    UIAssets.drawCurrencyWithTooltip("coins", PlayerData.coins, 20, 45, 16)

    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.setFont(getFont(12))
    love.graphics.print("Skill Level: " .. Forge.getSkillLevel(), 20, 70)

    -- Show some materials
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Iron: " .. Backpack.getItemCount("iron_ore"), 20, 90)
    love.graphics.print("Steel: " .. Backpack.getItemCount("steel_ingot"), 120, 90)
    love.graphics.print("Leather: " .. Backpack.getItemCount("leather_scraps"), 20, 110)
    love.graphics.print("Wood: " .. Backpack.getItemCount("wood_planks"), 120, 110)

    -- Recipe list (left panel)
    local recipeX = 10
    local recipeY = 150
    local recipeW = 220
    local recipeH = screenH - 200

    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", recipeX, recipeY, recipeW, recipeH, 8, 8)

    love.graphics.setColor(1, 0.9, 0.5)
    love.graphics.setFont(getFont(14))
    love.graphics.print("RECIPES", recipeX + 10, recipeY + 8)

    -- Draw recipe list using UI component
    if state.recipeList then
        state.recipeList:draw()
    end

    -- Selected recipe details (center panel)
    local detailX = 250
    local detailY = 60
    local detailW = 300
    local detailH = 280

    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", detailX, detailY, detailW, detailH, 8, 8)

    local selectedRecipe = RECIPES[state.selectedRecipeIndex]
    if selectedRecipe then
        love.graphics.setColor(1, 0.9, 0.5)
        love.graphics.setFont(getFont(18))
        love.graphics.print(selectedRecipe.name, detailX + 15, detailY + 10)

        love.graphics.setColor(0.6, 0.6, 0.7)
        love.graphics.setFont(getFont(11))
        love.graphics.print(selectedRecipe.category:upper(), detailX + 15, detailY + 35)

        -- Materials required
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.setFont(getFont(12))
        love.graphics.print("Materials:", detailX + 15, detailY + 60)

        for j, mat in ipairs(selectedRecipe.materials) do
            local itemDef = Backpack.getItemDef(mat.id)
            local owned = Backpack.getItemCount(mat.id)
            local hasEnough = owned >= mat.qty

            if hasEnough then
                love.graphics.setColor(0.4, 0.8, 0.4)
            else
                love.graphics.setColor(0.8, 0.4, 0.4)
            end

            local itemName = itemDef and itemDef.name or mat.id
            love.graphics.print("  " .. itemName .. " x" .. mat.qty .. " (" .. owned .. ")", detailX + 20, detailY + 75 + (j - 1) * 18)
        end

        -- Gold cost
        local matCount = #selectedRecipe.materials
        love.graphics.setColor(1, 0.9, 0.3)
        love.graphics.print("Gold: " .. (selectedRecipe.goldCost or 0), detailX + 15, detailY + 80 + matCount * 18)

        -- Skill requirement
        love.graphics.setColor(0.7, 0.7, 0.9)
        love.graphics.print("Skill Required: " .. (selectedRecipe.skillRequired or 0), detailX + 15, detailY + 100 + matCount * 18)

        -- Base stats
        love.graphics.setColor(0.6, 0.9, 0.6)
        love.graphics.print("Base Stats:", detailX + 15, detailY + 125 + matCount * 18)
        local statY = detailY + 140 + matCount * 18
        for statName, statValue in pairs(selectedRecipe.baseStats or {}) do
            love.graphics.print("  " .. statName .. ": " .. statValue, detailX + 20, statY)
            statY = statY + 15
        end

        -- Draw craft button using UI component
        if state.craftButton then
            state.craftButton:draw()
        end
    end

    -- Forge heat meter (bottom center)
    local heatX = screenW / 2 - 100
    local heatY = screenH - 100
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", heatX, heatY, 200, 40, 8, 8)

    -- Draw heat meter using UI component
    if state.heatMeter then
        state.heatMeter:draw()
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(12))
    love.graphics.print("Forge Heat", heatX + 60, heatY - 20)

    -- Crafting progress bar
    if state.currentRecipe then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", screenW / 2 - 100, 50, 200, 50, 8, 8)

        -- Draw crafting progress using UI component
        if state.craftingProgressBar then
            state.craftingProgressBar:draw()
        end

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(12))
        love.graphics.print("Crafting: " .. state.currentRecipe.name, screenW / 2 - 60, 80)
    end

    -- Output options panel
    if state.showOutput and state.craftedItem then
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)

        local panelW, panelH = 350, 280
        local panelX = screenW / 2 - panelW / 2
        local panelY = screenH / 2 - panelH / 2

        love.graphics.setColor(0.15, 0.18, 0.22)
        love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)
        love.graphics.setColor(0.4, 0.5, 0.6)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 10, 10)
        love.graphics.setLineWidth(1)

        love.graphics.setColor(1, 0.9, 0.4)
        love.graphics.setFont(getFont(18))
        love.graphics.print("ITEM CRAFTED!", panelX + 20, panelY + 15)

        -- Item name with rarity color
        CraftingCore.drawRarityText(state.craftedItem.name, panelX + 20, panelY + 50, state.craftedItem.rarity)

        -- Quality
        love.graphics.setFont(getFont(12))
        CraftingCore.drawQualityText("Quality: " .. CraftingCore.getQuality(state.craftedItem.quality).name, panelX + 20, panelY + 75, state.craftedItem.quality)

        -- Final stats
        love.graphics.setColor(0.7, 0.9, 0.7)
        love.graphics.print("Stats:", panelX + 20, panelY + 100)
        local statY = panelY + 118
        for statName, statValue in pairs(state.craftedItem.finalStats or {}) do
            love.graphics.print("  " .. statName .. ": " .. statValue, panelX + 25, statY)
            statY = statY + 16
        end

        -- Output options
        local optionY = panelY + panelH - 140
        local hoveredOption = CraftingCore.getHoveredOption(mx, my, panelX + 20, optionY, panelW - 40, 3)
        CraftingCore.drawOutputOptions(state.craftedItem, panelX + 20, optionY, panelW - 40, hoveredOption)
    end

    -- Notification
    if state.notification then
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", screenW / 2 - 150, 120, 300, 40, 8, 8)
        love.graphics.setColor(1, 1, 0.6)
        love.graphics.setFont(getFont(14))
        love.graphics.printf(state.notification, screenW / 2 - 145, 130, 290, "center")
    end

    -- Employee count indicator (top right)
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", screenW - 130, 10, 120, 50, 6, 6)
    love.graphics.setColor(0.9, 0.7, 0.4)
    love.graphics.setFont(getFont(12))
    love.graphics.print("Employees: " .. #state.employees, screenW - 120, 18)
    -- Show passive income from employees
    local totalEfficiency = 0
    for _, emp in ipairs(state.employees) do
        if emp.isHired and not emp.isDead then
            totalEfficiency = totalEfficiency + Employees.getEfficiency(emp)
        end
    end
    love.graphics.setColor(0.4, 0.8, 0.4)
    love.graphics.print(string.format("+%.1f gold/s", totalEfficiency * 0.1 * 10), screenW - 120, 35)

    -- Instructions
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.setFont(getFont(12))
    love.graphics.print("[SPACE] Bellows  [B] Backpack  [E] Employees  [U] Upgrades  [ESC] Exit", screenW / 2 - 220, screenH - 30)

    -- Draw employee panel if open
    if state.showEmployeePanel then
        EmployeeUI.drawEmployeePanel(screenW, screenH, mx, my, "forge", state.employees, state.hiringPool, state.upgrades)
    end

    -- Draw upgrade panel if open
    if state.showUpgradePanel then
        Forge.drawUpgradePanel(screenW, screenH, mx, my)
    end

    -- Draw currency tooltips
    UIAssets.drawTooltip()

    -- Draw tutorial overlay
    Tutorials.draw()
end

-- Handle mouse press
function Forge.mousepressed(x, y, button)
    if button ~= 1 then return end

    -- Handle tutorial clicks first
    if Tutorials.isActive() then
        Tutorials.mousepressed(x, y, button)
        return
    end

    local screenW, screenH = love.graphics.getDimensions()

    -- Handle UI component clicks (when panels not open)
    if not state.showEmployeePanel and not state.showUpgradePanel and not state.showOutput then
        -- Handle recipe list clicks
        if state.recipeList and state.recipeList:mousepressed(x, y, button) then
            return
        end

        -- Handle craft button clicks
        if state.craftButton and state.craftButton:mousepressed(x, y, button) then
            return
        end
    end

    -- Handle employee panel clicks
    if state.showEmployeePanel then
        local action, idx = EmployeeUI.handleEmployeePanelClick(x, y, "forge", state.employees, state.hiringPool, state.upgrades)
        if action == "fire" then
            Forge.fireEmployee(idx)
        elseif action == "hire" then
            Forge.hireEmployee(idx)
        end
        return
    end

    -- Handle upgrade panel clicks
    if state.showUpgradePanel then
        local panelW, panelH = 450, 400
        local panelX = screenW / 2 - panelW / 2
        local panelY = screenH / 2 - panelH / 2

        local upgY = panelY + 50
        local upgrades = UpgradeSystem.getUpgrades("forge")

        for i, upgrade in ipairs(upgrades) do
            if x >= panelX + 20 and x <= panelX + panelW - 20 and
               y >= upgY and y <= upgY + 100 then
                Forge.startUpgrade(upgrade.id)
                return
            end
            upgY = upgY + 110
        end
        return
    end

    -- Handle output options
    if state.showOutput and state.craftedItem then
        local panelW, panelH = 350, 280
        local panelX = screenW / 2 - panelW / 2
        local panelY = screenH / 2 - panelH / 2
        local optionY = panelY + panelH - 140

        local choice = CraftingCore.getHoveredOption(x, y, panelX + 20, optionY, panelW - 40, 3)
        if choice then
            Forge.handleOutputChoice(choice)
        end
        return
    end
end

-- Handle mouse release
function Forge.mousereleased(x, y, button)
    if button ~= 1 then return end

    -- Handle UI component releases
    if state.recipeList and state.recipeList.mousereleased then
        state.recipeList:mousereleased(x, y, button)
    end

    if state.craftButton and state.craftButton.mousereleased then
        state.craftButton:mousereleased(x, y, button)
    end
end

-- Handle mouse moved
function Forge.mousemoved(x, y, dx, dy)
    if state.recipeList and state.recipeList.mousemoved then
        state.recipeList:mousemoved(x, y, dx, dy)
    end
end

-- Handle key press
function Forge.keypressed(key)
    -- Handle tutorial keypresses first
    if Tutorials.isActive() then
        Tutorials.keypressed(key)
        return
    end

    if key == "space" then
        Forge.pumpBellows()
    elseif key == "b" then
        Backpack.toggle()
    elseif key == "e" then
        -- Toggle employee panel
        state.showEmployeePanel = not state.showEmployeePanel
        state.showUpgradePanel = false
    elseif key == "u" then
        -- Toggle upgrade panel
        state.showUpgradePanel = not state.showUpgradePanel
        state.showEmployeePanel = false
    elseif key == "escape" then
        if state.showOutput then
            -- Cancel output selection, keep item
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
            Forge.saveData()
            state.active = false
            return "menu"
        end
    elseif key == "up" then
        state.selectedRecipeIndex = math.max(1, state.selectedRecipeIndex - 1)
    elseif key == "down" then
        state.selectedRecipeIndex = math.min(#RECIPES, state.selectedRecipeIndex + 1)
    elseif key == "return" or key == "kpenter" then
        if not state.currentRecipe and not state.showOutput then
            local selectedRecipe = RECIPES[state.selectedRecipeIndex]
            if selectedRecipe then
                Forge.startCraft(selectedRecipe)
            end
        end
    end
end

-- Handle scroll
function Forge.wheelmoved(x, y)
    -- Pass scroll events to UI components
    if state.recipeList and state.recipeList.wheelmoved then
        state.recipeList:wheelmoved(x, y)
    end
end

-- Check if forge is active
function Forge.isActive()
    return state.active
end

-- Exit forge mode
function Forge.exit()
    Forge.saveData()
    state.active = false
end

-- Hire an employee from the pool
function Forge.hireEmployee(index)
    -- Check if player owns this building
    if PlayerData.currentBuildingOwned ~= true then
        state.notification = "You must own this forge to hire workers!"
        state.notificationTimer = 2
        return false
    end

    local emp = state.hiringPool[index]
    if not emp then return false end

    local empType = Employees.getType(emp.employeeType)
    if not empType then return false end

    -- Check max employees from upgrades
    local effects = UpgradeSystem.getCombinedEffects("forge", state.upgrades)
    local maxEmployees = effects.maxEmployees or 1

    if #state.employees >= maxEmployees then
        state.notification = "Max employees reached! Upgrade capacity."
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
    local newCandidates = Employees.generateHiringPool("forge", 1, Forge.getSkillLevel())
    if #newCandidates > 0 then
        table.insert(state.hiringPool, newCandidates[1])
    end

    state.notification = "Hired " .. emp.name .. "!"
    state.notificationTimer = 2
    -- Update global passive income rate
    Forge.updatePassiveIncomeRate()
    Forge.saveData()
    return true
end

-- Fire an employee
function Forge.fireEmployee(index)
    local emp = state.employees[index]
    if emp then
        table.remove(state.employees, index)
        state.notification = "Fired " .. emp.name
        state.notificationTimer = 2
        -- Update global passive income rate
        Forge.updatePassiveIncomeRate()
        Forge.saveData()
        return true
    end
    return false
end

-- Start an upgrade
function Forge.startUpgrade(upgradeId)
    if state.currentBuild then
        state.notification = "Already building an upgrade!"
        state.notificationTimer = 2
        return false
    end

    local currentLevel = state.upgrades[upgradeId] or 0
    local canAfford, reason = UpgradeSystem.canAfford("forge", upgradeId, currentLevel, PlayerData.coins)

    if not canAfford then
        state.notification = reason
        state.notificationTimer = 2
        return false
    end

    local buildInfo, err = UpgradeSystem.startUpgrade("forge", upgradeId, currentLevel, PlayerData.coins)
    if not buildInfo then
        state.notification = err
        state.notificationTimer = 2
        return false
    end

    -- Deduct gold (skip if already deducted by startUpgrade)
    if not buildInfo.goldDeducted then
        PlayerData.coins = PlayerData.coins - buildInfo.goldCost
    end
    state.currentBuild = buildInfo

    state.notification = "Started upgrade: " .. upgradeId
    state.notificationTimer = 2
    Forge.saveData()
    return true
end

-- Draw employee panel (delegated to shared EmployeeUI module)
-- Forge.drawEmployeePanel kept as a thin wrapper for backward compatibility
function Forge.drawEmployeePanel(screenW, screenH, mx, my)
    EmployeeUI.drawEmployeePanel(screenW, screenH, mx, my, "forge", state.employees, state.hiringPool, state.upgrades)
end

-- Draw upgrade panel
function Forge.drawUpgradePanel(screenW, screenH, mx, my)
    local panelW, panelH = 450, 400
    local panelX = screenW / 2 - panelW / 2
    local panelY = screenH / 2 - panelH / 2

    -- Background
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    love.graphics.setColor(0.15, 0.18, 0.22)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)
    love.graphics.setColor(0.5, 0.4, 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 10, 10)

    -- Title
    love.graphics.setColor(1, 0.8, 0.4)
    love.graphics.setFont(getFont(18))
    love.graphics.print("UPGRADES", panelX + 20, panelY + 15)

    -- Upgrades list
    local y = panelY + 50
    local upgrades = UpgradeSystem.getUpgrades("forge")

    for i, upgrade in ipairs(upgrades) do
        local currentLevel = state.upgrades[upgrade.id] or 0
        local isHovered = mx >= panelX + 20 and mx <= panelX + panelW - 20 and my >= y and my <= y + 100
        local height = UpgradeSystem.drawUpgradeCard("forge", upgrade.id, currentLevel, panelX + 20, y, panelW - 40, isHovered, state.currentBuild)
        y = y + height + 10
    end

    -- Close hint
    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.printf("Press [U] or [ESC] to close  |  Click upgrade to start", panelX, panelY + panelH - 25, panelW, "center")
end

-- Get UI region for tutorial system
function Forge.getUIRegion(regionId)
    local screenW, screenH = love.graphics.getDimensions()

    local regions = {
        recipe_list = {
            x = 10,
            y = 150,
            w = 220,
            h = screenH - 200
        },
        recipe_details = {
            x = 250,
            y = 60,
            w = 300,
            h = 280
        },
        heat_meter = {
            x = screenW / 2 - 100,
            y = screenH - 100,
            w = 200,
            h = 40
        },
        output_options = {
            x = screenW / 2 - 175,
            y = screenH / 2 - 140,
            w = 350,
            h = 280
        }
    }

    return regions[regionId]
end

return Forge
