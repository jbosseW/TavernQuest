-- Upgrade System - Upgrades requiring materials, time, and gold
-- Used by forge, wizard tower, alchemist, hunting, fishing modes

local UpgradeSystem = {}
local Backpack = require("backpack")

-- Font cache for performance
local FontCache = require("fontcache")
local function getFont(size)
    return FontCache.get(size)
end

-- Upgrade definitions per mode
UpgradeSystem.UPGRADES = {
    -- Forge upgrades
    forge = {
        {id = "forge_efficiency", name = "Forge Efficiency", maxLevel = 5,
         description = "Reduces crafting time",
         effect = function(level) return {craftTimeReduction = level * 0.1} end,
         costs = {
             {gold = 100, materials = {{id = "iron_ore", qty = 10}}, buildTime = 30},
             {gold = 250, materials = {{id = "iron_ore", qty = 25}, {id = "coal", qty = 10}}, buildTime = 60},
             {gold = 500, materials = {{id = "steel_ingot", qty = 15}}, buildTime = 120},
             {gold = 1000, materials = {{id = "steel_ingot", qty = 30}, {id = "mythril_shard", qty = 5}}, buildTime = 240},
             {gold = 2000, materials = {{id = "mythril_shard", qty = 20}, {id = "dragon_scale", qty = 3}}, buildTime = 480},
         }},
        {id = "forge_quality", name = "Forge Quality", maxLevel = 5,
         description = "Increases item quality chance",
         effect = function(level) return {qualityBonus = level * 5} end,
         costs = {
             {gold = 150, materials = {{id = "iron_ore", qty = 15}}, buildTime = 45},
             {gold = 350, materials = {{id = "steel_ingot", qty = 10}}, buildTime = 90},
             {gold = 700, materials = {{id = "steel_ingot", qty = 20}, {id = "leather_scraps", qty = 20}}, buildTime = 180},
             {gold = 1400, materials = {{id = "mythril_shard", qty = 10}}, buildTime = 360},
             {gold = 2800, materials = {{id = "mythril_shard", qty = 25}, {id = "phoenix_feather", qty = 2}}, buildTime = 600},
         }},
        {id = "forge_capacity", name = "Forge Capacity", maxLevel = 3,
         description = "Allows more employees",
         effect = function(level) return {maxEmployees = level} end,
         costs = {
             {gold = 500, materials = {{id = "iron_ore", qty = 50}, {id = "wood_planks", qty = 30}}, buildTime = 120},
             {gold = 1500, materials = {{id = "steel_ingot", qty = 40}, {id = "wood_planks", qty = 50}}, buildTime = 300},
             {gold = 4000, materials = {{id = "mythril_shard", qty = 15}, {id = "dragon_scale", qty = 5}}, buildTime = 600},
         }},
    },

    -- Wizard tower upgrades
    wizardtower = {
        {id = "mana_efficiency", name = "Mana Efficiency", maxLevel = 5,
         description = "Reduces mana cost for crafting",
         effect = function(level) return {manaCostReduction = level * 0.1} end,
         costs = {
             {gold = 120, materials = {{id = "mana_crystal", qty = 5}}, buildTime = 40},
             {gold = 300, materials = {{id = "mana_crystal", qty = 12}, {id = "arcane_dust", qty = 8}}, buildTime = 80},
             {gold = 600, materials = {{id = "mana_crystal", qty = 25}}, buildTime = 160},
             {gold = 1200, materials = {{id = "mana_crystal", qty = 50}, {id = "phoenix_feather", qty = 2}}, buildTime = 320},
             {gold = 2400, materials = {{id = "enchanted_ink", qty = 20}, {id = "phoenix_feather", qty = 5}}, buildTime = 640},
         }},
        {id = "spell_power", name = "Spell Power", maxLevel = 5,
         description = "Increases spell effectiveness",
         effect = function(level) return {spellPowerBonus = level * 8} end,
         costs = {
             {gold = 180, materials = {{id = "arcane_dust", qty = 10}}, buildTime = 50},
             {gold = 400, materials = {{id = "arcane_dust", qty = 20}, {id = "mana_crystal", qty = 10}}, buildTime = 100},
             {gold = 800, materials = {{id = "fire_essence", qty = 10}, {id = "frost_essence", qty = 10}}, buildTime = 200},
             {gold = 1600, materials = {{id = "enchanted_ink", qty = 15}}, buildTime = 400},
             {gold = 3200, materials = {{id = "phoenix_feather", qty = 8}}, buildTime = 720},
         }},
        {id = "tower_expansion", name = "Tower Expansion", maxLevel = 3,
         description = "Allows more apprentices",
         effect = function(level) return {maxEmployees = level} end,
         costs = {
             {gold = 600, materials = {{id = "mana_crystal", qty = 30}, {id = "ancient_scroll", qty = 10}}, buildTime = 150},
             {gold = 1800, materials = {{id = "enchanted_ink", qty = 20}, {id = "ancient_scroll", qty = 25}}, buildTime = 350},
             {gold = 5000, materials = {{id = "phoenix_feather", qty = 10}}, buildTime = 700},
         }},
    },

    -- Alchemy upgrades
    alchemist = {
        {id = "brew_speed", name = "Brew Speed", maxLevel = 5,
         description = "Reduces brewing time",
         effect = function(level) return {brewTimeReduction = level * 0.1} end,
         costs = {
             {gold = 100, materials = {{id = "healing_herb", qty = 15}}, buildTime = 35},
             {gold = 250, materials = {{id = "healing_herb", qty = 30}, {id = "moonflower", qty = 10}}, buildTime = 70},
             {gold = 500, materials = {{id = "moonflower", qty = 25}}, buildTime = 140},
             {gold = 1000, materials = {{id = "venom_sac", qty = 15}, {id = "troll_blood", qty = 10}}, buildTime = 280},
             {gold = 2000, materials = {{id = "phoenix_feather", qty = 3}}, buildTime = 560},
         }},
        {id = "potion_potency", name = "Potion Potency", maxLevel = 5,
         description = "Increases potion effectiveness",
         effect = function(level) return {potencyBonus = level * 10} end,
         costs = {
             {gold = 140, materials = {{id = "moonflower", qty = 10}}, buildTime = 45},
             {gold = 350, materials = {{id = "troll_blood", qty = 8}}, buildTime = 90},
             {gold = 700, materials = {{id = "troll_blood", qty = 15}, {id = "venom_sac", qty = 10}}, buildTime = 180},
             {gold = 1400, materials = {{id = "phoenix_feather", qty = 2}}, buildTime = 360},
             {gold = 2800, materials = {{id = "phoenix_feather", qty = 6}}, buildTime = 600},
         }},
        {id = "lab_expansion", name = "Lab Expansion", maxLevel = 3,
         description = "Allows more assistants",
         effect = function(level) return {maxEmployees = level} end,
         costs = {
             {gold = 450, materials = {{id = "empty_vial", qty = 50}, {id = "healing_herb", qty = 40}}, buildTime = 120},
             {gold = 1400, materials = {{id = "moonflower", qty = 50}, {id = "troll_blood", qty = 20}}, buildTime = 300},
             {gold = 3500, materials = {{id = "phoenix_feather", qty = 8}}, buildTime = 600},
         }},
    },

    -- Hunting upgrades
    hunting = {
        {id = "tracking_skill", name = "Tracking Skill", maxLevel = 5,
         description = "Find rare animals more often",
         effect = function(level) return {rareChanceBonus = level * 0.05} end,
         costs = {
             {gold = 80, materials = {{id = "leather_scraps", qty = 10}}, buildTime = 30},
             {gold = 200, materials = {{id = "leather_scraps", qty = 25}, {id = "wood_planks", qty = 15}}, buildTime = 60},
             {gold = 400, materials = {{id = "antlers", qty = 3}}, buildTime = 120},
             {gold = 800, materials = {{id = "antlers", qty = 8}, {id = "legendary_pelt", qty = 5}}, buildTime = 240},
             {gold = 1600, materials = {{id = "mystical_antlers", qty = 2}}, buildTime = 480},
         }},
        {id = "hunting_accuracy", name = "Hunting Accuracy", maxLevel = 5,
         description = "Improves shot accuracy",
         effect = function(level) return {accuracyBonus = level * 0.05} end,
         costs = {
             {gold = 100, materials = {{id = "wood_planks", qty = 20}}, buildTime = 35},
             {gold = 250, materials = {{id = "iron_ore", qty = 15}}, buildTime = 70},
             {gold = 500, materials = {{id = "steel_ingot", qty = 10}}, buildTime = 140},
             {gold = 1000, materials = {{id = "steel_ingot", qty = 25}}, buildTime = 280},
             {gold = 2000, materials = {{id = "mythril_shard", qty = 5}}, buildTime = 560},
         }},
        {id = "hunting_lodge", name = "Hunting Lodge", maxLevel = 3,
         description = "Allows more hunters",
         effect = function(level) return {maxEmployees = level} end,
         costs = {
             {gold = 400, materials = {{id = "wood_planks", qty = 100}, {id = "leather_scraps", qty = 50}}, buildTime = 150},
             {gold = 1200, materials = {{id = "antlers", qty = 10}, {id = "legendary_pelt", qty = 10}}, buildTime = 350},
             {gold = 3000, materials = {{id = "mystical_antlers", qty = 3}}, buildTime = 700},
         }},
    },

    -- Fishing upgrades
    fishing = {
        {id = "fishing_skill", name = "Fishing Skill", maxLevel = 5,
         description = "Catch fish faster",
         effect = function(level) return {catchSpeedBonus = level * 0.15} end,
         costs = {
             {gold = 60, materials = {{id = "wood_planks", qty = 10}}, buildTime = 25},
             {gold = 150, materials = {{id = "wood_planks", qty = 25}, {id = "rope", qty = 10}}, buildTime = 50},
             {gold = 300, materials = {{id = "iron_ore", qty = 15}}, buildTime = 100},
             {gold = 600, materials = {{id = "steel_ingot", qty = 10}}, buildTime = 200},
             {gold = 1200, materials = {{id = "mythril_shard", qty = 3}}, buildTime = 400},
         }},
        {id = "rare_fish_chance", name = "Rare Fish Chance", maxLevel = 5,
         description = "Find rare fish more often",
         effect = function(level) return {rareChanceBonus = level * 0.08} end,
         costs = {
             {gold = 80, materials = {{id = "bait", qty = 20}}, buildTime = 30},
             {gold = 200, materials = {{id = "bait", qty = 50}, {id = "rare_fish", qty = 3}}, buildTime = 60},
             {gold = 400, materials = {{id = "rare_fish", qty = 8}}, buildTime = 120},
             {gold = 800, materials = {{id = "legendary_fish", qty = 2}}, buildTime = 240},
             {gold = 1600, materials = {{id = "legendary_fish", qty = 5}}, buildTime = 480},
         }},
        {id = "fishing_dock", name = "Fishing Dock", maxLevel = 3,
         description = "Allows more fishers",
         effect = function(level) return {maxEmployees = level} end,
         costs = {
             {gold = 350, materials = {{id = "wood_planks", qty = 80}, {id = "rope", qty = 30}}, buildTime = 120},
             {gold = 1000, materials = {{id = "wood_planks", qty = 150}, {id = "iron_ore", qty = 30}}, buildTime = 280},
             {gold = 2500, materials = {{id = "steel_ingot", qty = 20}, {id = "rare_fish", qty = 15}}, buildTime = 560},
         }},
    },

    -- Stock market upgrades
    stock_market = {
        {id = "market_insight", name = "Market Insight", maxLevel = 5,
         description = "Better chance to predict price movements",
         effect = function(level) return {insightBonus = level * 0.1} end,
         costs = {
             {gold = 200, materials = {}, buildTime = 30},
             {gold = 500, materials = {}, buildTime = 60},
             {gold = 1000, materials = {}, buildTime = 120},
             {gold = 2000, materials = {}, buildTime = 240},
             {gold = 4000, materials = {}, buildTime = 480},
         }},
        {id = "trading_speed", name = "Trading Speed", maxLevel = 5,
         description = "Market updates tick faster",
         effect = function(level) return {tickSpeedBonus = level * 0.15} end,
         costs = {
             {gold = 300, materials = {}, buildTime = 45},
             {gold = 700, materials = {}, buildTime = 90},
             {gold = 1400, materials = {}, buildTime = 180},
             {gold = 2800, materials = {}, buildTime = 360},
             {gold = 5500, materials = {}, buildTime = 600},
         }},
        {id = "trading_floor", name = "Trading Floor", maxLevel = 3,
         description = "Allows more traders",
         effect = function(level) return {maxEmployees = level} end,
         costs = {
             {gold = 800, materials = {}, buildTime = 150},
             {gold = 2500, materials = {}, buildTime = 350},
             {gold = 6000, materials = {}, buildTime = 700},
         }},
        {id = "dividend_boost", name = "Dividend Boost", maxLevel = 5,
         description = "Earn passive income from holdings",
         effect = function(level) return {dividendRate = level * 0.01} end,
         costs = {
             {gold = 400, materials = {}, buildTime = 60},
             {gold = 900, materials = {}, buildTime = 120},
             {gold = 1800, materials = {}, buildTime = 240},
             {gold = 3600, materials = {}, buildTime = 480},
             {gold = 7000, materials = {}, buildTime = 800},
         }},
    },
}

-- Get upgrades for a mode
function UpgradeSystem.getUpgrades(mode)
    return UpgradeSystem.UPGRADES[mode] or {}
end

-- Get specific upgrade
function UpgradeSystem.getUpgrade(mode, upgradeId)
    local upgrades = UpgradeSystem.getUpgrades(mode)
    for _, u in ipairs(upgrades) do
        if u.id == upgradeId then
            return u
        end
    end
    return nil
end

-- Get upgrade cost for next level
function UpgradeSystem.getCost(mode, upgradeId, currentLevel)
    local upgrade = UpgradeSystem.getUpgrade(mode, upgradeId)
    if not upgrade then return nil end

    local nextLevel = (currentLevel or 0) + 1
    if nextLevel > upgrade.maxLevel then return nil end

    return upgrade.costs[nextLevel]
end

-- Check if player can afford upgrade
function UpgradeSystem.canAfford(mode, upgradeId, currentLevel, playerCoins)
    local cost = UpgradeSystem.getCost(mode, upgradeId, currentLevel)
    if not cost then return false, "Max level reached" end

    -- Check gold
    if playerCoins < cost.gold then
        return false, "Not enough gold"
    end

    -- Check materials
    for _, mat in ipairs(cost.materials or {}) do
        local owned = Backpack.getItemCount(mat.id)
        if owned < mat.qty then
            local itemDef = Backpack.getItemDef(mat.id)
            local itemName = itemDef and itemDef.name or mat.id
            return false, "Need " .. mat.qty .. " " .. itemName
        end
    end

    return true
end

-- Start an upgrade (consumes resources, returns build info)
function UpgradeSystem.startUpgrade(mode, upgradeId, currentLevel, playerCoins)
    local canAfford, reason = UpgradeSystem.canAfford(mode, upgradeId, currentLevel, playerCoins)
    if not canAfford then
        return nil, reason
    end

    local cost = UpgradeSystem.getCost(mode, upgradeId, currentLevel)

    -- Consume materials
    for _, mat in ipairs(cost.materials or {}) do
        Backpack.removeItem(mat.id, mat.qty)
    end

    -- Deduct gold cost directly (materials are consumed here, gold should be too)
    if PlayerData and cost.gold then
        PlayerData.coins = (PlayerData.coins or 0) - cost.gold
    end

    -- Return build info
    return {
        upgradeId = upgradeId,
        mode = mode,
        targetLevel = currentLevel + 1,
        goldCost = cost.gold,
        goldDeducted = true, -- Flag: gold was already deducted by startUpgrade
        buildTime = cost.buildTime, -- In seconds
        startTime = os.time(),
        endTime = os.time() + cost.buildTime,
    }
end

-- Check if upgrade is complete
function UpgradeSystem.isComplete(buildInfo)
    if not buildInfo then return true end
    return os.time() >= buildInfo.endTime
end

-- Get remaining build time
function UpgradeSystem.getRemainingTime(buildInfo)
    if not buildInfo then return 0 end
    local remaining = buildInfo.endTime - os.time()
    return math.max(0, remaining)
end

-- Get effect of upgrade at given level
function UpgradeSystem.getEffect(mode, upgradeId, level)
    local upgrade = UpgradeSystem.getUpgrade(mode, upgradeId)
    if not upgrade or not upgrade.effect then return {} end
    return upgrade.effect(level or 0)
end

-- Get combined effects of all upgrades for a mode
function UpgradeSystem.getCombinedEffects(mode, upgradeLevels)
    local combined = {
        craftTimeReduction = 0,
        qualityBonus = 0,
        maxEmployees = 0,
        manaCostReduction = 0,
        spellPowerBonus = 0,
        brewTimeReduction = 0,
        potencyBonus = 0,
        rareChanceBonus = 0,
        accuracyBonus = 0,
        catchSpeedBonus = 0,
        -- Stock market specific
        insightBonus = 0,
        tickSpeedBonus = 0,
        dividendRate = 0,
    }

    for upgradeId, level in pairs(upgradeLevels or {}) do
        local effect = UpgradeSystem.getEffect(mode, upgradeId, level)
        for key, value in pairs(effect) do
            -- Only add numeric values to prevent type mismatch errors
            if type(value) == "number" then
                if combined[key] and type(combined[key]) == "number" then
                    combined[key] = combined[key] + value
                else
                    combined[key] = value
                end
            end
        end
    end

    return combined
end

-- Draw upgrade card
function UpgradeSystem.drawUpgradeCard(mode, upgradeId, currentLevel, x, y, width, isHovered, buildInfo)
    local upgrade = UpgradeSystem.getUpgrade(mode, upgradeId)
    if not upgrade then return end

    local height = 100
    local isMaxed = currentLevel >= upgrade.maxLevel
    local isBuilding = buildInfo and buildInfo.upgradeId == upgradeId

    -- Background
    if isBuilding then
        love.graphics.setColor(0.3, 0.35, 0.25)
    elseif isMaxed then
        love.graphics.setColor(0.2, 0.25, 0.2)
    elseif isHovered then
        love.graphics.setColor(0.25, 0.28, 0.32)
    else
        love.graphics.setColor(0.18, 0.2, 0.25)
    end
    love.graphics.rectangle("fill", x, y, width, height, 6, 6)

    -- Border
    love.graphics.setColor(0.4, 0.45, 0.5)
    love.graphics.rectangle("line", x, y, width, height, 6, 6)

    -- Name and level
    love.graphics.setColor(1, 0.95, 0.8)
    love.graphics.setFont(getFont(14))
    love.graphics.print(upgrade.name, x + 10, y + 8)

    -- Level indicator
    love.graphics.setColor(0.5, 0.7, 0.9)
    love.graphics.setFont(getFont(12))
    love.graphics.print("Lv " .. currentLevel .. "/" .. upgrade.maxLevel, x + width - 60, y + 8)

    -- Description
    love.graphics.setColor(0.7, 0.7, 0.75)
    love.graphics.setFont(getFont(11))
    love.graphics.print(upgrade.description, x + 10, y + 28)

    -- Show effect at NEXT level (what you'll get when you upgrade)
    local displayLevel = isMaxed and currentLevel or (currentLevel + 1)
    local effect = upgrade.effect(displayLevel)
    local effectStr = ""
    for k, v in pairs(effect) do
        if type(v) == "number" then
            -- Format based on value type
            if k == "maxEmployees" then
                effectStr = effectStr .. k .. ": " .. v .. " "
            elseif v < 1 then
                effectStr = effectStr .. k .. ": " .. math.floor(v * 100) .. "% "
            else
                effectStr = effectStr .. k .. ": " .. v .. "% "
            end
        end
    end
    -- Color based on whether maxed or showing next level bonus
    if isMaxed then
        love.graphics.setColor(0.5, 0.8, 0.5)
    else
        love.graphics.setColor(0.9, 0.8, 0.3) -- Yellow for "what you'll get"
    end
    love.graphics.print(effectStr, x + 10, y + 45)

    -- Building progress or cost
    if isBuilding then
        local remaining = UpgradeSystem.getRemainingTime(buildInfo)
        local progress = 1 - (remaining / buildInfo.buildTime)

        -- Progress bar
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.rectangle("fill", x + 10, y + 70, width - 20, 12, 3, 3)
        love.graphics.setColor(0.4, 0.7, 0.4)
        love.graphics.rectangle("fill", x + 10, y + 70, (width - 20) * progress, 12, 3, 3)

        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(string.format("Building... %ds", remaining), x + 10, y + 85, width - 20, "center")
    elseif not isMaxed then
        local cost = upgrade.costs[currentLevel + 1]
        if cost then
            love.graphics.setColor(1, 0.9, 0.4)
            love.graphics.print("Cost: " .. cost.gold .. " gold", x + 10, y + 65)

            -- Materials
            local matStr = ""
            for _, mat in ipairs(cost.materials or {}) do
                local itemDef = Backpack.getItemDef(mat.id)
                matStr = matStr .. (itemDef and itemDef.name or mat.id) .. " x" .. mat.qty .. "  "
            end
            love.graphics.setColor(0.7, 0.7, 0.8)
            love.graphics.print(matStr, x + 10, y + 82)
        end
    else
        love.graphics.setColor(0.5, 0.8, 0.5)
        love.graphics.printf("MAXED", x, y + 70, width, "center")
    end

    return height
end

-- Save upgrade data
function UpgradeSystem.save(data)
    return data or {}
end

-- Load upgrade data
function UpgradeSystem.load(data)
    return data or {}
end

return UpgradeSystem
