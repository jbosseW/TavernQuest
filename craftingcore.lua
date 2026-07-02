-- Crafting Core - Shared systems for all crafting modes
-- Provides rarity, quality, recipe validation, and output handling

local CraftingCore = {}
local Backpack = require("backpack")

-- Rarity system with stat multipliers and colors
CraftingCore.RARITIES = {
    {id = "common", name = "Common", color = {0.7, 0.7, 0.7}, statMult = 1.0, weight = 0.50},
    {id = "uncommon", name = "Uncommon", color = {0.3, 0.8, 0.3}, statMult = 1.25, weight = 0.30},
    {id = "rare", name = "Rare", color = {0.3, 0.5, 0.9}, statMult = 1.5, weight = 0.15},
    {id = "epic", name = "Epic", color = {0.7, 0.3, 0.9}, statMult = 2.0, weight = 0.04},
    {id = "legendary", name = "Legendary", color = {1.0, 0.8, 0.2}, statMult = 3.0, weight = 0.01},
}

-- Quality system based on crafting minigame performance
CraftingCore.QUALITIES = {
    {id = "masterwork", name = "Masterwork", statBonus = 0.25, color = {1.0, 0.9, 0.3}},
    {id = "excellent", name = "Excellent", statBonus = 0.15, color = {0.3, 0.9, 0.4}},
    {id = "good", name = "Good", statBonus = 0.0, color = {0.7, 0.7, 0.7}},
    {id = "poor", name = "Poor", statBonus = -0.15, color = {0.6, 0.4, 0.3}},
}

-- Get rarity by ID
function CraftingCore.getRarity(rarityId)
    for _, r in ipairs(CraftingCore.RARITIES) do
        if r.id == rarityId then
            return r
        end
    end
    return CraftingCore.RARITIES[1]  -- Default to common
end

-- Get quality by ID
function CraftingCore.getQuality(qualityId)
    for _, q in ipairs(CraftingCore.QUALITIES) do
        if q.id == qualityId then
            return q
        end
    end
    return CraftingCore.QUALITIES[3]  -- Default to good
end

-- Roll for rarity based on weights (optional custom weights)
function CraftingCore.rollRarity(customWeights)
    local weights = customWeights or {}

    -- Normalize weights so they always sum to 1.0
    local totalWeight = 0
    for _, r in ipairs(CraftingCore.RARITIES) do
        totalWeight = totalWeight + (weights[r.id] or r.weight)
    end

    if totalWeight <= 0 then
        return CraftingCore.RARITIES[1]  -- Fallback to common
    end

    local roll = math.random()
    local cumulative = 0

    for i = #CraftingCore.RARITIES, 1, -1 do
        local rarity = CraftingCore.RARITIES[i]
        local w = (weights[rarity.id] or rarity.weight) / totalWeight
        cumulative = cumulative + w
        if roll <= cumulative then
            return rarity
        end
    end

    return CraftingCore.RARITIES[1]  -- Fallback to common
end

-- Determine quality based on minigame performance (0-100 score)
function CraftingCore.getQualityFromScore(score)
    if score >= 90 then
        return CraftingCore.QUALITIES[1]  -- Masterwork
    elseif score >= 70 then
        return CraftingCore.QUALITIES[2]  -- Excellent
    elseif score >= 40 then
        return CraftingCore.QUALITIES[3]  -- Good
    else
        return CraftingCore.QUALITIES[4]  -- Poor
    end
end

-- Calculate final stats for a crafted item
function CraftingCore.calculateFinalStats(baseStats, rarity, quality)
    local finalStats = {}
    local rarityData = type(rarity) == "string" and CraftingCore.getRarity(rarity) or rarity
    local qualityData = type(quality) == "string" and CraftingCore.getQuality(quality) or quality

    for statName, baseValue in pairs(baseStats) do
        if type(baseValue) == "number" then
            local finalValue = baseValue * rarityData.statMult * (1 + qualityData.statBonus)
            finalStats[statName] = math.floor(finalValue + 0.5)
        else
            finalStats[statName] = baseValue  -- Pass through non-numeric stats (booleans, strings)
        end
    end

    return finalStats
end

-- Validate if player can craft a recipe
function CraftingCore.canCraft(recipe, craftingSkillLevel)
    craftingSkillLevel = craftingSkillLevel or 0

    -- Check skill requirement
    if recipe.skillRequired and recipe.skillRequired > craftingSkillLevel then
        return false, "Skill level " .. recipe.skillRequired .. " required"
    end

    -- Check gold cost
    if recipe.goldCost and PlayerData.coins < recipe.goldCost then
        return false, "Need " .. recipe.goldCost .. " gold"
    end

    -- Check materials
    for _, mat in ipairs(recipe.materials or {}) do
        if not Backpack.hasItem(mat.id, mat.qty) then
            local itemDef = Backpack.getItemDef(mat.id)
            local itemName = itemDef and itemDef.name or mat.id
            return false, "Need " .. mat.qty .. "x " .. itemName
        end
    end

    return true
end

-- Consume materials for crafting
function CraftingCore.consumeMaterials(recipe)
    -- Deduct gold
    if recipe.goldCost then
        PlayerData.coins = PlayerData.coins - recipe.goldCost
    end

    -- Remove materials from backpack
    for _, mat in ipairs(recipe.materials or {}) do
        Backpack.removeItem(mat.id, mat.qty)
    end

    savePlayerData()
end

-- Create a crafted item instance
function CraftingCore.createCraftedItem(recipe, rarity, quality)
    local rarityData = type(rarity) == "string" and CraftingCore.getRarity(rarity) or rarity
    local qualityData = type(quality) == "string" and CraftingCore.getQuality(quality) or quality

    local item = {
        id = recipe.id,
        name = recipe.name,
        category = recipe.category,
        rarity = rarityData.id,
        quality = qualityData.id,
        baseStats = recipe.baseStats or {},
        finalStats = CraftingCore.calculateFinalStats(recipe.baseStats or {}, rarityData, qualityData),
        craftedAt = os.time(),
        icon = recipe.icon,
    }

    return item
end

-- Calculate sell value for a crafted item
function CraftingCore.getSellValue(item)
    local baseValue = 50  -- Default base value

    -- Get base value from item definition if available
    local itemDef = Backpack.getItemDef(item.id)
    if itemDef and itemDef.sellValue then
        baseValue = itemDef.sellValue
    end

    -- Apply rarity multiplier
    local rarity = CraftingCore.getRarity(item.rarity)
    local value = baseValue * rarity.statMult

    -- Apply quality multiplier
    local quality = CraftingCore.getQuality(item.quality)
    value = value * (1 + quality.statBonus)

    return math.floor(value + 0.5)
end

-- Sell crafted item immediately
function CraftingCore.sellItem(item)
    local value = CraftingCore.getSellValue(item)
    PlayerData.coins = PlayerData.coins + value
    savePlayerData()
    return value
end

-- Add item to player's backpack inventory
function CraftingCore.keepItem(item)
    -- Create a backpack-compatible item entry
    local success = Backpack.addItem(item.id, 1)

    -- Store the crafted item details in a separate crafted items list
    if not PlayerData.craftedItems then
        PlayerData.craftedItems = {}
    end
    table.insert(PlayerData.craftedItems, item)
    savePlayerData()

    return success
end

-- List item on market
function CraftingCore.listOnMarket(item, price)
    if not PlayerData.marketListings then
        PlayerData.marketListings = {}
    end

    local listing = {
        item = item,
        price = price,
        listedAt = os.time(),
    }

    table.insert(PlayerData.marketListings, listing)
    savePlayerData()
    return true
end

-- Award crafting XP based on recipe complexity
function CraftingCore.awardCraftingXP(recipe, skillType)
    -- Initialize crafting skills if not present
    if not PlayerData.craftingSkills then
        PlayerData.craftingSkills = {
            forging = 0,
            wizardry = 0,
            alchemy = 0,
        }
    end

    -- Calculate XP based on recipe complexity
    local baseXP = 10
    if recipe.materials then
        baseXP = baseXP + #recipe.materials * 5
    end
    if recipe.goldCost then
        baseXP = baseXP + math.floor(recipe.goldCost / 10)
    end

    -- Apply XP
    PlayerData.craftingSkills[skillType] = (PlayerData.craftingSkills[skillType] or 0) + baseXP
    savePlayerData()

    return baseXP
end

-- Get current crafting skill level
function CraftingCore.getSkillLevel(skillType)
    if not PlayerData.craftingSkills then
        return 1  -- Minimum level of 1
    end
    -- Skill level = XP / 100 (100 XP per level), minimum level 1
    return math.max(1, math.floor((PlayerData.craftingSkills[skillType] or 0) / 100))
end

-- Draw rarity-colored text
function CraftingCore.drawRarityText(text, x, y, rarityId)
    local rarity = CraftingCore.getRarity(rarityId)
    love.graphics.setColor(rarity.color)
    love.graphics.print(text, x, y)
    love.graphics.setColor(1, 1, 1)
end

-- Draw quality-colored text
function CraftingCore.drawQualityText(text, x, y, qualityId)
    local quality = CraftingCore.getQuality(qualityId)
    love.graphics.setColor(quality.color)
    love.graphics.print(text, x, y)
    love.graphics.setColor(1, 1, 1)
end

-- Draw a crafting progress bar
function CraftingCore.drawProgressBar(x, y, width, height, progress, color)
    -- Background
    love.graphics.setColor(0.15, 0.15, 0.2)
    love.graphics.rectangle("fill", x, y, width, height, 4, 4)

    -- Progress fill
    love.graphics.setColor(color or {0.3, 0.7, 0.4})
    love.graphics.rectangle("fill", x + 2, y + 2, (width - 4) * progress, height - 4, 3, 3)

    -- Border
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, width, height, 4, 4)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(1, 1, 1)
end

-- Draw crafting output options panel
function CraftingCore.drawOutputOptions(item, x, y, width, hoveredOption)
    local optionHeight = 40
    local options = {"Sell Now", "Keep", "List on Market"}
    local sellValue = CraftingCore.getSellValue(item)

    for i, opt in ipairs(options) do
        local optY = y + (i - 1) * (optionHeight + 5)
        local isHovered = hoveredOption == i

        -- Button background
        if isHovered then
            love.graphics.setColor(0.35, 0.45, 0.55)
        else
            love.graphics.setColor(0.2, 0.25, 0.3)
        end
        love.graphics.rectangle("fill", x, optY, width, optionHeight, 6, 6)

        -- Button text
        love.graphics.setColor(1, 1, 1)
        local text = opt
        if i == 1 then
            text = opt .. " (" .. sellValue .. " gold)"
        end
        love.graphics.printf(text, x, optY + 12, width, "center")
    end

    love.graphics.setColor(1, 1, 1)
end

-- Check which output option is hovered
function CraftingCore.getHoveredOption(mx, my, x, y, width, optionCount)
    local optionHeight = 40
    for i = 1, optionCount do
        local optY = y + (i - 1) * (optionHeight + 5)
        if mx >= x and mx <= x + width and my >= optY and my <= optY + optionHeight then
            return i
        end
    end
    return nil
end

return CraftingCore
