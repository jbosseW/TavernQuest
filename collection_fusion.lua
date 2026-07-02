-- collection_fusion.lua
-- Fusion system: upgrade definitions, fusion logic, fusion panel drawing, upgrades tab

local Cards = require("cards")
local UI = require("ui")
local shared = require("collection_shared")
local Effects = require("collection_effects")

local Fusion = {}

-- Fusion upgrade definitions
local FUSION_UPGRADES = {
    {id = "splinterChance", name = "Splinter Mastery", desc = "+2% splinter chance", effect = "Bonus random card on fusion", maxLevel = 10, baseCost = 5, costMult = 1.5, color = {1, 0.6, 0.2}},
    {id = "mirrorChance", name = "Mirror Polish", desc = "+1% mirror chance", effect = "Duplicate fused result", maxLevel = 15, baseCost = 8, costMult = 1.6, color = {0.8, 0.8, 0.9}},
    {id = "bonusChips", name = "Chip Infusion", desc = "+5 chips per fusion", effect = "Extra chips on result", maxLevel = 20, baseCost = 3, costMult = 1.3, color = {0.5, 0.7, 1}},
    {id = "bonusMult", name = "Mult Weaving", desc = "+1 mult per fusion", effect = "Extra mult on result", maxLevel = 10, baseCost = 10, costMult = 1.8, color = {1, 0.5, 0.5}},
    {id = "catalystChance", name = "Catalyst Spark", desc = "+1% rarity skip", effect = "Skip a rarity tier", maxLevel = 10, baseCost = 12, costMult = 1.7, color = {1, 0.9, 0.3}},
    {id = "prismaticChance", name = "Prismatic Touch", desc = "+1% mutation chance", effect = "Add random mutation", maxLevel = 10, baseCost = 15, costMult = 1.8, color = {0.9, 0.4, 0.9}},
    {id = "echoChance", name = "Echo Resonance", desc = "+1% card return", effect = "Return a source card", maxLevel = 10, baseCost = 6, costMult = 1.4, color = {0.3, 0.6, 1}},
    {id = "fortifyChance", name = "Fortification", desc = "+2% extra fusion slot", effect = "+1 max fusions on result", maxLevel = 8, baseCost = 20, costMult = 2.0, color = {0.3, 0.9, 0.4}},
}

-- Rarity order for fusion (all 11 rarities)
local RARITY_ORDER = {"common", "uncommon", "rare", "epic", "legendary", "mythic", "divine", "cosmic", "transcendent", "eternal", "primordial"}

-- Helper: get next safe collection ID (avoids collisions after removals)
local function getNextCollectionId()
    local maxId = 0
    for _, c in ipairs(PlayerData.collection) do
        if c.id and c.id > maxId then
            maxId = c.id
        end
    end
    return maxId + 1
end

-- Get upgrade cost for a level
local function getUpgradeCost(upgrade, currentLevel)
    return math.floor(upgrade.baseCost * (upgrade.costMult ^ currentLevel))
end

local function getRarityIndex(rarity)
    for i, r in ipairs(RARITY_ORDER) do
        if r == rarity then return i end
    end
    return 1
end

local function getNextRarity(rarity1, rarity2)
    local idx1 = getRarityIndex(rarity1)
    local idx2 = getRarityIndex(rarity2)
    local maxIdx = math.max(idx1, idx2)
    local nextIdx = math.min(maxIdx + 1, #RARITY_ORDER)
    return RARITY_ORDER[nextIdx]
end

-- Expose for fusion panel preview
Fusion.getNextRarity = getNextRarity

local function getPreviousRarity(rarity)
    local idx = getRarityIndex(rarity)
    local prevIdx = math.max(1, idx - 1)
    return RARITY_ORDER[prevIdx]
end

-- Roll for fusion special effects
local function rollFusionEffects()
    local effects = {}
    local upgrades = PlayerData.fusionUpgrades or {}

    local splinterChance = 0.08 + (upgrades.splinterChance or 0) * 0.02
    local mirrorChance = 0.04 + (upgrades.mirrorChance or 0) * 0.01
    local catalystChance = 0.05 + (upgrades.catalystChance or 0) * 0.01
    local prismaticChance = 0.03 + (upgrades.prismaticChance or 0) * 0.01
    local echoChance = 0.06 + (upgrades.echoChance or 0) * 0.01
    local fortifyChance = 0.07 + (upgrades.fortifyChance or 0) * 0.02

    -- Jackpot check first (1% - all effects trigger!)
    if math.random() < 0.01 then
        return {splinter=true, mirror=true, catalyst=true, prismatic=true, echo=true, fortify=true, jackpot=true}
    end

    if math.random() < splinterChance then effects.splinter = true end
    if math.random() < mirrorChance then effects.mirror = true end
    if math.random() < catalystChance then effects.catalyst = true end
    if math.random() < prismaticChance then effects.prismatic = true end
    if math.random() < echoChance then effects.echo = true end
    if math.random() < fortifyChance then effects.fortify = true end

    return effects
end

-- Generate a random splinter card (lower rarity than result)
local function generateSplinterCard(baseRarity)
    local splinterRarity = getPreviousRarity(baseRarity)
    local suits = {"hearts", "diamonds", "clubs", "spades"}
    local ranks = {"2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"}
    local rankValues = {["2"]=2,["3"]=3,["4"]=4,["5"]=5,["6"]=6,["7"]=7,["8"]=8,["9"]=9,["10"]=10,["J"]=11,["Q"]=12,["K"]=13,["A"]=14}

    local rank = ranks[math.random(#ranks)]
    local rarityInfo = Cards.rarities[splinterRarity] or Cards.rarities.common

    return {
        id = math.random(100000, 999999),
        suit = suits[math.random(#suits)],
        rank = rank,
        value = rankValues[rank],
        rarity = splinterRarity,
        chips = math.floor(10 * (rarityInfo.multiplier or 1)),
        mult = math.floor(2 * (rarityInfo.multiplier or 1) * 0.5),
        ability = "none",
        fusionCount = 0,
    }
end

-- Get random mutation for prismatic effect
local function getRandomMutation()
    local mutations = {"foil", "holographic", "polychrome", "gilded", "ancient", "blessed_mut"}
    return mutations[math.random(#mutations)]
end

-- Calculate crystal reward for fusion
local function calculateCrystalReward(rarity, effects)
    local rarityRewards = {
        common = 1, uncommon = 1, rare = 1, epic = 2, legendary = 2,
        mythic = 3, divine = 3, cosmic = 3, transcendent = 3, eternal = 3, primordial = 3
    }
    local base = rarityRewards[rarity] or 1
    local bonus = 0

    local effectCount = 0
    for k, v in pairs(effects) do
        if v and k ~= "jackpot" then effectCount = effectCount + 1 end
    end
    if effectCount > 0 then bonus = bonus + math.min(effectCount, 3) end
    if effects.jackpot then bonus = bonus + 5 end

    return base + bonus
end

-- Perform card fusion with special effects
function Fusion.performFusion()
    local fusionCards = shared.fusionCards
    if #fusionCards < 2 then return false end

    local card1 = fusionCards[1]
    local card2 = fusionCards[2]

    -- Check fusion limits
    local fc1 = card1.card.fusionCount or 0
    local fc2 = card2.card.fusionCount or 0
    if fc1 >= shared.MAX_FUSION_COUNT or fc2 >= shared.MAX_FUSION_COUNT then
        return false
    end

    -- Roll for special effects!
    local effects = rollFusionEffects()

    -- Calculate new rarity
    local newRarity
    local screenW, screenH = love.graphics.getDimensions()
    local effectX, effectY = screenW / 2, screenH / 2

    if effects.catalyst then
        local idx1 = getRarityIndex(card1.card.rarity)
        local idx2 = getRarityIndex(card2.card.rarity)
        local maxIdx = math.max(idx1, idx2)
        local nextIdx = math.min(maxIdx + 2, #RARITY_ORDER)
        newRarity = RARITY_ORDER[nextIdx]
        Effects.addFusionNotification("CATALYST! Skipped a rarity!", {1, 0.9, 0.3})
        Effects.triggerFusionEffect("catalyst", effectX, effectY)
    else
        newRarity = getNextRarity(card1.card.rarity, card2.card.rarity)
    end

    -- New fusion count is max of both parents + 1
    local newFusionCount = math.max(fc1, fc2) + 1

    -- Fortify effect
    if effects.fortify then
        newFusionCount = math.max(0, newFusionCount - 1)
        Effects.addFusionNotification("FORTIFY! Extra fusion capacity!", {0.3, 0.9, 0.4})
        Effects.triggerFusionEffect("fortify", effectX, effectY - 50)
    end

    -- Calculate bonus chips/mult from upgrades
    local upgrades = PlayerData.fusionUpgrades or {}
    local bonusChips = (upgrades.bonusChips or 0) * 5
    local bonusMult = (upgrades.bonusMult or 0) * 1

    -- Merge card properties
    local newRank = math.random() < 0.5 and card1.card.rank or card2.card.rank
    local rankValues = {["2"]=2,["3"]=3,["4"]=4,["5"]=5,["6"]=6,["7"]=7,["8"]=8,["9"]=9,["10"]=10,["J"]=11,["Q"]=12,["K"]=13,["A"]=14}
    local newCard = {
        id = math.random(100000, 999999),
        suit = math.random() < 0.5 and card1.card.suit or card2.card.suit,
        rank = newRank,
        value = rankValues[newRank] or 10,
        rarity = newRarity,
        chips = (card1.card.chips or 0) + (card2.card.chips or 0) + 5 + bonusChips,
        mult = (card1.card.mult or 0) + (card2.card.mult or 0) + bonusMult,
        ability = card1.card.ability ~= "none" and card1.card.ability or card2.card.ability,
        fusionCount = newFusionCount,
    }

    -- Prismatic effect: add random mutation
    if effects.prismatic then
        newCard.mutation = getRandomMutation()
        Effects.addFusionNotification("PRISMATIC! Gained " .. newCard.mutation .. " mutation!", {0.9, 0.4, 0.9})
        Effects.triggerFusionEffect("prismatic", effectX, effectY)
    end

    -- Store one source card for potential echo effect
    local echoCard = nil
    if effects.echo then
        echoCard = math.random() < 0.5 and card1 or card2
    end

    -- Remove both cards from collection
    for _, fc in ipairs(fusionCards) do
        for i, c in ipairs(PlayerData.collection) do
            if c.id == fc.id then
                table.remove(PlayerData.collection, i)
                break
            end
        end
        if PlayerData.currentDeck then
            for i, dc in ipairs(PlayerData.currentDeck) do
                if dc.id == fc.id then
                    table.remove(PlayerData.currentDeck, i)
                    break
                end
            end
        end
    end

    -- Add fused card to collection
    table.insert(PlayerData.collection, {
        id = getNextCollectionId(),
        cardId = newCard.id,
        card = newCard
    })

    -- Mirror effect: create a duplicate!
    if effects.mirror then
        local mirrorCard = {}
        for k, v in pairs(newCard) do mirrorCard[k] = v end
        mirrorCard.id = math.random(100000, 999999)
        table.insert(PlayerData.collection, {
            id = getNextCollectionId(),
            cardId = mirrorCard.id,
            card = mirrorCard
        })
        Effects.addFusionNotification("MIRROR! Created a duplicate!", {0.8, 0.8, 0.9})
        Effects.triggerFusionEffect("mirror", effectX - 80, effectY)
    end

    -- Splinter effect: bonus random card!
    if effects.splinter then
        local splinterCard = generateSplinterCard(newRarity)
        table.insert(PlayerData.collection, {
            id = getNextCollectionId(),
            cardId = splinterCard.id,
            card = splinterCard
        })
        Effects.addFusionNotification("SPLINTER! Bonus " .. splinterCard.rarity .. " card!", {1, 0.6, 0.2})
        Effects.triggerFusionEffect("splinter", effectX + 80, effectY)
    end

    -- Echo effect: return source card
    if effects.echo and echoCard then
        local returnCard = {}
        for k, v in pairs(echoCard.card) do returnCard[k] = v end
        returnCard.id = math.random(100000, 999999)
        table.insert(PlayerData.collection, {
            id = getNextCollectionId(),
            cardId = returnCard.id,
            card = returnCard
        })
        Effects.addFusionNotification("ECHO! Returned " .. returnCard.rank .. " of " .. returnCard.suit .. "!", {0.3, 0.6, 1})
        Effects.triggerFusionEffect("echo", effectX, effectY + 50)
    end

    -- Jackpot announcement
    if effects.jackpot then
        Effects.addFusionNotification("!!! JACKPOT !!! ALL EFFECTS TRIGGERED !!!", {1, 0.8, 0.2})
        Effects.triggerFusionEffect("jackpot", effectX, effectY)
    end

    -- Always trigger base fusion effect
    if not effects.jackpot then
        Effects.spawnFusionParticles("fusion", effectX, effectY)
    end

    -- Award crystals
    local crystalReward = calculateCrystalReward(newRarity, effects)
    PlayerData.crystals = (PlayerData.crystals or 0) + crystalReward
    Effects.addFusionNotification("+" .. crystalReward .. " Crystals", {0.4, 0.8, 1})

    shared.fusionCards = {}
    savePlayerData()
    return true
end

-- ============================================
-- DRAW FUSION PANEL
-- ============================================

function Fusion.drawFusionPanel(screenW, screenH)
    local layout = shared.layout
    local fusionCards = shared.fusionCards

    local panelW = 400
    local panelH = 200
    local panelX = screenW / 2 - panelW / 2
    local panelY = screenH - panelH - 70

    -- Background
    love.graphics.setColor(0.1, 0.08, 0.15, 0.95)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)
    love.graphics.setColor(0.6, 0.3, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 10, 10)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(0.8, 0.5, 1)
    love.graphics.setFont(UI.fonts.get(18))
    love.graphics.printf("Card Fusion", panelX, panelY + 10, panelW, "center")

    -- Card slots
    local slotW = 80
    local slotH = 110
    local slot1X = panelX + 50
    local slot2X = panelX + panelW - slotW - 50
    local slotY = panelY + 45

    for i = 1, 2 do
        local slotX = i == 1 and slot1X or slot2X
        local card = fusionCards[i]

        love.graphics.setColor(0.15, 0.12, 0.2)
        love.graphics.rectangle("fill", slotX, slotY, slotW, slotH, 6, 6)

        if card then
            local rarity = Cards.rarities[card.card.rarity] or Cards.rarities.common
            love.graphics.setColor(rarity.color)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", slotX, slotY, slotW, slotH, 6, 6)
            love.graphics.setLineWidth(1)

            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(UI.fonts.get(14))
            local suitSymbol = Cards.suitSymbols[card.card.suit] or "?"
            love.graphics.printf(card.card.rank, slotX, slotY + 15, slotW, "center")
            love.graphics.printf(suitSymbol, slotX, slotY + 40, slotW, "center")

            love.graphics.setColor(rarity.color)
            love.graphics.setFont(UI.fonts.get(10))
            local rarityName = card.card.rarity:sub(1,1):upper() .. card.card.rarity:sub(2,4)
            love.graphics.printf(rarityName, slotX, slotY + 70, slotW, "center")

            love.graphics.setColor(0.5, 0.7, 1)
            love.graphics.setFont(UI.fonts.get(9))
            love.graphics.printf("+" .. (card.card.chips or 0) .. " chips", slotX, slotY + 85, slotW, "center")

            local fc = card.card.fusionCount or 0
            love.graphics.setColor(0.7, 0.6, 0.9)
            love.graphics.printf("Fused: " .. fc .. "/" .. shared.MAX_FUSION_COUNT, slotX, slotY + 96, slotW, "center")
        else
            love.graphics.setColor(0.4, 0.3, 0.5)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", slotX, slotY, slotW, slotH, 6, 6)

            love.graphics.setColor(0.5, 0.4, 0.6)
            love.graphics.setFont(UI.fonts.get(12))
            love.graphics.printf("Empty", slotX, slotY + 45, slotW, "center")
        end
    end

    -- Plus sign
    love.graphics.setColor(0.7, 0.5, 0.9)
    love.graphics.setFont(UI.fonts.get(32))
    love.graphics.printf("+", panelX, slotY + 35, panelW, "center")

    -- Result preview
    if #fusionCards == 2 then
        local newRarity = getNextRarity(fusionCards[1].card.rarity, fusionCards[2].card.rarity)
        local rarityInfo = Cards.rarities[newRarity] or Cards.rarities.common

        love.graphics.setColor(0.3, 0.8, 0.4)
        love.graphics.setFont(UI.fonts.get(12))
        love.graphics.printf("Result: " .. newRarity:sub(1,1):upper() .. newRarity:sub(2) .. " card!", panelX, panelY + 160, panelW, "center")

        -- Fuse button
        local btnW = 100
        local btnH = 30
        local btnX = panelX + panelW / 2 - btnW / 2
        local btnY = panelY + panelH - 40

        local mx, my = love.mouse.getPosition()
        local hover = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH

        love.graphics.setColor(hover and {0.5, 0.9, 0.5} or {0.3, 0.7, 0.3})
        love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 5, 5)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.fonts.get(14))
        love.graphics.printf("FUSE!", btnX, btnY + 7, btnW, "center")
    else
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.setFont(UI.fonts.get(11))
        love.graphics.printf("Select 2 cards from your collection", panelX, panelY + 165, panelW, "center")
    end
end

-- ============================================
-- DRAW UPGRADES TAB
-- ============================================

function Fusion.drawUpgradesTab()
    local layout = shared.layout
    local scrollOffset = shared.scrollOffset
    local mx, my = love.mouse.getPosition()

    love.graphics.setScissor(layout.areaX, layout.areaY, layout.areaWidth, layout.areaHeight)

    -- Title
    love.graphics.setColor(0.8, 0.5, 1)
    love.graphics.setFont(UI.fonts.get(20))
    love.graphics.print("Fusion Upgrades", layout.areaX + 20, layout.areaY + 10)

    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.print("Spend Crystals to improve your fusion outcomes!", layout.areaX + 20, layout.areaY + 38)

    -- Current crystal balance
    love.graphics.setColor(0.4, 0.8, 1)
    love.graphics.setFont(UI.fonts.get(16))
    love.graphics.print("Your Crystals: " .. (PlayerData.crystals or 0), layout.areaX + layout.areaWidth - 200, layout.areaY + 15)

    -- Draw upgrade cards in a grid
    local cardW, cardH = 270, 100
    local spacing = 15
    local cols = 4
    local startX = layout.areaX + 20
    local startY = layout.areaY + 70

    for i, upgrade in ipairs(FUSION_UPGRADES) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local cardX = startX + col * (cardW + spacing)
        local cardY = startY + row * (cardH + spacing) - scrollOffset

        if cardY > layout.areaY - cardH and cardY < layout.areaY + layout.areaHeight then
            local currentLevel = (PlayerData.fusionUpgrades and PlayerData.fusionUpgrades[upgrade.id]) or 0
            local isMaxed = currentLevel >= upgrade.maxLevel
            local cost = getUpgradeCost(upgrade, currentLevel)
            local canAfford = (PlayerData.crystals or 0) >= cost

            local hovered = mx >= cardX and mx <= cardX + cardW and my >= cardY and my <= cardY + cardH
            if isMaxed then
                love.graphics.setColor(0.15, 0.2, 0.15, 0.9)
            elseif hovered and canAfford then
                love.graphics.setColor(0.2, 0.25, 0.35, 0.95)
            else
                love.graphics.setColor(0.12, 0.12, 0.18, 0.9)
            end
            love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 8, 8)

            love.graphics.setColor(upgrade.color[1], upgrade.color[2], upgrade.color[3], isMaxed and 0.5 or 1)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", cardX, cardY, cardW, cardH, 8, 8)
            love.graphics.setLineWidth(1)

            love.graphics.setColor(upgrade.color)
            love.graphics.setFont(UI.fonts.get(14))
            love.graphics.print(upgrade.name, cardX + 10, cardY + 8)

            love.graphics.setColor(0.7, 0.7, 0.8)
            love.graphics.setFont(UI.fonts.get(12))
            love.graphics.print("Lv." .. currentLevel .. "/" .. upgrade.maxLevel, cardX + cardW - 60, cardY + 8)

            love.graphics.setColor(0.6, 0.6, 0.7)
            love.graphics.setFont(UI.fonts.get(11))
            love.graphics.print(upgrade.desc, cardX + 10, cardY + 30)

            love.graphics.setColor(0.5, 0.5, 0.6)
            love.graphics.print(upgrade.effect, cardX + 10, cardY + 48)

            local bonusText = ""
            if upgrade.id == "splinterChance" or upgrade.id == "fortifyChance" then
                bonusText = string.format("Current: +%d%%", currentLevel * 2)
            elseif upgrade.id == "bonusChips" then
                bonusText = string.format("Current: +%d chips", currentLevel * 5)
            elseif upgrade.id == "bonusMult" then
                bonusText = string.format("Current: +%d mult", currentLevel * 1)
            else
                bonusText = string.format("Current: +%d%%", currentLevel * 1)
            end
            love.graphics.setColor(0.4, 0.7, 0.4)
            love.graphics.print(bonusText, cardX + 10, cardY + 66)

            if isMaxed then
                love.graphics.setColor(0.3, 0.6, 0.3)
                love.graphics.setFont(UI.fonts.get(12))
                love.graphics.print("MAXED", cardX + cardW - 60, cardY + cardH - 25)
            else
                local btnX = cardX + cardW - 80
                local btnY = cardY + cardH - 30
                local btnW, btnH = 70, 22
                local btnHover = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH

                love.graphics.setColor(canAfford and (btnHover and {0.3, 0.7, 0.9} or {0.2, 0.5, 0.7}) or {0.3, 0.3, 0.35})
                love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 4, 4)

                love.graphics.setColor(canAfford and {1, 1, 1} or {0.5, 0.5, 0.5})
                love.graphics.setFont(UI.fonts.get(11))
                love.graphics.printf(cost .. " ", btnX, btnY + 4, btnW, "center")
            end
        end
    end

    -- Effect chances summary at bottom
    local summaryY = startY + 2 * (cardH + spacing) + 20 - scrollOffset
    if summaryY > layout.areaY and summaryY < layout.areaY + layout.areaHeight then
        love.graphics.setColor(0.7, 0.7, 0.8)
        love.graphics.setFont(UI.fonts.get(14))
        love.graphics.print("Current Fusion Effect Chances:", layout.areaX + 20, summaryY)

        local upgrades = PlayerData.fusionUpgrades or {}
        local chances = {
            {name = "Splinter", base = 8, bonus = (upgrades.splinterChance or 0) * 2, color = {1, 0.6, 0.2}},
            {name = "Mirror", base = 4, bonus = (upgrades.mirrorChance or 0) * 1, color = {0.8, 0.8, 0.9}},
            {name = "Catalyst", base = 5, bonus = (upgrades.catalystChance or 0) * 1, color = {1, 0.9, 0.3}},
            {name = "Prismatic", base = 3, bonus = (upgrades.prismaticChance or 0) * 1, color = {0.9, 0.4, 0.9}},
            {name = "Echo", base = 6, bonus = (upgrades.echoChance or 0) * 1, color = {0.3, 0.6, 1}},
            {name = "Fortify", base = 7, bonus = (upgrades.fortifyChance or 0) * 2, color = {0.3, 0.9, 0.4}},
            {name = "JACKPOT", base = 1, bonus = 0, color = {1, 0.8, 0.2}},
        }

        love.graphics.setFont(UI.fonts.get(12))
        for i, chance in ipairs(chances) do
            local cx = layout.areaX + 20 + ((i-1) % 4) * 150
            local cy = summaryY + 25 + math.floor((i-1) / 4) * 20
            love.graphics.setColor(chance.color)
            local total = chance.base + chance.bonus
            love.graphics.print(string.format("%s: %d%%", chance.name, total), cx, cy)
        end
    end

    love.graphics.setScissor()
end

-- ============================================
-- HANDLE UPGRADE PURCHASE CLICKS
-- ============================================

function Fusion.handleUpgradeClick(x, y)
    local layout = shared.layout
    local scrollOffset = shared.scrollOffset

    local cardW, cardH = 270, 100
    local spacing = 15
    local cols = 4
    local startX = layout.areaX + 20
    local startY = layout.areaY + 70

    for i, upgrade in ipairs(FUSION_UPGRADES) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local cardX = startX + col * (cardW + spacing)
        local cardY = startY + row * (cardH + spacing) - scrollOffset

        local currentLevel = (PlayerData.fusionUpgrades and PlayerData.fusionUpgrades[upgrade.id]) or 0
        local isMaxed = currentLevel >= upgrade.maxLevel
        local cost = getUpgradeCost(upgrade, currentLevel)
        local canAfford = (PlayerData.crystals or 0) >= cost

        if not isMaxed then
            local btnX = cardX + cardW - 80
            local btnY = cardY + cardH - 30
            local btnW, btnH = 70, 22

            if x >= btnX and x <= btnX + btnW and y >= btnY and y <= btnY + btnH then
                if canAfford then
                    PlayerData.crystals = (PlayerData.crystals or 0) - cost
                    if not PlayerData.fusionUpgrades then
                        PlayerData.fusionUpgrades = {}
                    end
                    PlayerData.fusionUpgrades[upgrade.id] = currentLevel + 1
                    Effects.addFusionNotification(upgrade.name .. " upgraded to Lv." .. (currentLevel + 1) .. "!", upgrade.color)
                    savePlayerData()
                end
                return true
            end
        end
    end
    return false
end

-- ============================================
-- HANDLE FUSION BUTTON CLICK
-- ============================================

function Fusion.handleFuseButtonClick(x, y)
    local fusionCards = shared.fusionCards
    if #fusionCards < 2 then return false end

    local screenW, screenH = love.graphics.getDimensions()
    local panelW = 400
    local panelH = 200
    local panelX = screenW / 2 - panelW / 2
    local panelY = screenH - panelH - 70
    local btnW = 100
    local btnH = 30
    local btnX = panelX + panelW / 2 - btnW / 2
    local btnY = panelY + panelH - 40

    if x >= btnX and x <= btnX + btnW and y >= btnY and y <= btnY + btnH then
        Fusion.performFusion()
        return true
    end
    return false
end

return Fusion
