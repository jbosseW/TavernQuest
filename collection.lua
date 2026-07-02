-- Collection viewer and card shop
-- Main module: state management, init, tab switching, collection/joker tabs,
-- card drawing, tooltips, filters, and input dispatching to sub-modules

local Collection = {}
local Cards = require("cards")
local Jokers = require("jokers")
local UIAssets = require("uiassets")
local UI = require("ui")

-- Sub-modules
local shared = require("collection_shared")
local Effects = require("collection_effects")
local Fusion = require("collection_fusion")
local Shop = require("collection_shop")
local Themes = require("collection_themes")

-- ============================================
-- HELPERS
-- ============================================

-- Helper function to get next safe collection ID (avoids collisions after removals)
local function getNextCollectionId()
    local maxId = 0
    for _, c in ipairs(PlayerData.collection) do
        if c.id and c.id > maxId then
            maxId = c.id
        end
    end
    return maxId + 1
end

function getSellPrice(card)
    local basePrice = 5
    local rarityMult = {
        common = 1, uncommon = 2, rare = 4, epic = 8, legendary = 20,
        mythic = 40, divine = 80, cosmic = 150, transcendent = 300,
        eternal = 500, primordial = 1000
    }
    return basePrice * (rarityMult[card.rarity] or 1)
end

local function getFilteredCollection()
    local filtered = {}
    local filters = shared.filters
    for _, collCard in ipairs(PlayerData.collection) do
        local card = collCard.card
        local passFilter = true

        if filters.suit ~= "all" and card.suit ~= filters.suit then
            passFilter = false
        end
        if filters.rarity ~= "all" and card.rarity ~= filters.rarity then
            passFilter = false
        end

        if passFilter then
            table.insert(filtered, collCard)
        end
    end
    return filtered
end

-- ============================================
-- UI COMPONENTS INIT
-- ============================================

local function initUIComponents()
    local screenW, screenH = love.graphics.getDimensions()
    if not screenW or screenW == 0 then
        screenW = 1280
    end

    -- Main tab bar
    shared.mainTabBar = UI.TabBar.new({
        x = 50,
        y = 60,
        w = 650,
        tabs = {
            {id = "collection", label = "Cards"},
            {id = "shop", label = "Shop"},
            {id = "jokers", label = "Jokers"},
            {id = "upgrades", label = "Upgrades"},
            {id = "themes", label = "Themes"},
            {id = "portraits", label = "Portraits"}
        },
        activeTab = "collection",
        onChange = function(tabId)
            shared.currentTab = tabId
            shared.scrollOffset = 0
        end
    })

    -- Suit filter bar
    shared.suitFilterBar = UI.TabBar.new({
        x = 90,
        y = 102,
        w = 200,
        tabs = {
            {id = "all", label = "All"},
            {id = "hearts", label = "\xe2\x99\xa5"},
            {id = "diamonds", label = "\xe2\x99\xa6"},
            {id = "clubs", label = "\xe2\x99\xa3"},
            {id = "spades", label = "\xe2\x99\xa0"}
        },
        activeTab = "all",
        onChange = function(suit)
            shared.filters.suit = suit
            shared.scrollOffset = 0
        end
    })

    -- Rarity filter bar (first row)
    shared.rarityFilterBar = UI.TabBar.new({
        x = 350,
        y = 102,
        w = 348,
        tabs = {
            {id = "all", label = "All"},
            {id = "common", label = "Com"},
            {id = "uncommon", label = "Unc"},
            {id = "rare", label = "Rare"},
            {id = "epic", label = "Epic"},
            {id = "legendary", label = "Leg"}
        },
        activeTab = "all",
        onChange = function(rarity)
            shared.filters.rarity = rarity
            shared.scrollOffset = 0
        end
    })

    -- Fusion button
    shared.fusionButton = UI.Button.new({
        x = screenW - 320,
        y = 60,
        w = 100,
        h = 35,
        text = "Fusion",
        variant = "secondary",
        onClick = function()
            shared.fusionMode = not shared.fusionMode
            if shared.fusionMode then shared.sellMode = false end
            shared.fusionCards = {}
            shared.fusionButton.text = shared.fusionMode and "Cancel" or "Fusion"
        end
    })

    -- Sell button
    shared.sellButton = UI.Button.new({
        x = screenW - 210,
        y = 60,
        w = 100,
        h = 35,
        text = "Sell Mode",
        variant = "secondary",
        onClick = function()
            shared.sellMode = not shared.sellMode
            if shared.sellMode then shared.fusionMode = false end
            shared.fusionCards = {}
            shared.sellButton.text = shared.sellMode and "Cancel" or "Sell Mode"
        end
    })

    -- Card grid helper
    shared.cardGrid = UI.Grid.new(
        shared.layout.areaX + 20,
        shared.layout.areaY + 20,
        shared.layout.areaWidth,
        shared.layout.cardsPerRow,
        shared.layout.cardWidth,
        shared.layout.cardHeight,
        20
    )
end

-- ============================================
-- INIT
-- ============================================

function Collection.init()
    shared.reset()
    Shop.refreshShop()
    initUIComponents()
end

-- ============================================
-- WHEELMOVED
-- ============================================

function Collection.wheelmoved(x, y)
    local currentTab = shared.currentTab
    local layout = shared.layout

    if currentTab == "collection" or currentTab == "jokers" then
        local items = currentTab == "collection" and getFilteredCollection() or (PlayerData.ownedJokers or {})
        local rows = math.ceil(#items / layout.cardsPerRow)
        local contentHeight = rows * (layout.cardHeight + 20)
        local maxScroll = math.max(0, contentHeight - layout.areaHeight + 40)

        shared.scrollOffset = shared.scrollOffset - y * 40
        shared.scrollOffset = math.max(0, math.min(shared.scrollOffset, maxScroll))
    elseif currentTab == "themes" then
        local cardH = 100
        local contentHeight = 35 + math.ceil(8 / 5) * (cardH + 15) + 20 + 30 + 70 + 100 + 30 + 60 + 40
        local maxScroll = math.max(0, contentHeight - layout.areaHeight + 40)

        shared.scrollOffset = shared.scrollOffset - y * 40
        shared.scrollOffset = math.max(0, math.min(shared.scrollOffset, maxScroll))
    elseif currentTab == "portraits" then
        local cardH = 180
        local rows = math.ceil(12 / 7)
        local contentHeight = 70 + rows * (cardH + 15) + 40
        local maxScroll = math.max(0, contentHeight - layout.areaHeight + 40)

        shared.scrollOffset = shared.scrollOffset - y * 40
        shared.scrollOffset = math.max(0, math.min(shared.scrollOffset, maxScroll))
    elseif currentTab == "upgrades" then
        local cardH = 100
        local spacing = 15
        local rows = 2
        local contentHeight = 70 + rows * (cardH + spacing) + 100
        local maxScroll = math.max(0, contentHeight - layout.areaHeight + 40)

        shared.scrollOffset = shared.scrollOffset - y * 40
        shared.scrollOffset = math.max(0, math.min(shared.scrollOffset, maxScroll))
    end
end

-- ============================================
-- UPDATE
-- ============================================

function Collection.update(dt)
    Effects.updateFusionNotifications(dt)
    Effects.updateVisualEffects(dt)
    UI.anim.update(dt)

    -- Initialize UI components if needed
    if not shared.mainTabBar then
        initUIComponents()
    end

    -- Update UI components
    if shared.mainTabBar then shared.mainTabBar:update(dt) end
    if shared.suitFilterBar then shared.suitFilterBar:update(dt) end
    if shared.rarityFilterBar then shared.rarityFilterBar:update(dt) end
    if shared.fusionButton then shared.fusionButton:update(dt) end
    if shared.sellButton then shared.sellButton:update(dt) end
end

-- ============================================
-- CARD DRAWING (shared by collection tab, shop tab, details)
-- ============================================

local function drawCollectionCard(card, x, y, hovered, selected)
    local layout = shared.layout
    local rarity = Cards.rarities[card.rarity] or Cards.rarities.common
    local effectTime = Effects.getEffectTime()

    -- Track hovered card for tooltip
    if hovered then
        shared.hoveredCardInfo = card
        shared.hoveredCardPos = {x = x, y = y}
    end

    -- Try to load card image
    local cardImage = Cards.getCardImage(card)

    if cardImage then
        love.graphics.setColor(1, 1, 1)
        local imgW = cardImage:getWidth()
        local imgH = cardImage:getHeight()
        local scaleX = layout.cardWidth / imgW
        local scaleY = layout.cardHeight / imgH
        local scale = math.min(scaleX, scaleY)
        love.graphics.draw(cardImage, x, y, 0, scale, scale)
    else
        love.graphics.setColor(0.95, 0.95, 0.9)
        love.graphics.rectangle("fill", x, y, layout.cardWidth, layout.cardHeight, 6, 6)

        local suitColor = Cards.suitColors[card.suit] or {0.5, 0.3, 0.8}
        love.graphics.setColor(suitColor)

        love.graphics.setFont(UI.fonts.get(18))
        local symbol = Cards.suitSymbols[card.suit] or "\xe2\x98\x85"
        love.graphics.print(card.rank .. symbol, x + 8, y + 8)

        love.graphics.setFont(UI.fonts.get(32))
        love.graphics.print(symbol, x + layout.cardWidth/2 - 12, y + layout.cardHeight/2 - 20)
    end

    -- Border (selection/hover/rarity)
    if selected then
        love.graphics.setColor(0.9, 0.8, 0.2)
        love.graphics.setLineWidth(3)
    elseif hovered then
        love.graphics.setColor(0.7, 0.7, 0.9)
        love.graphics.setLineWidth(2)
    else
        love.graphics.setColor(rarity.color)
        love.graphics.setLineWidth(2)
    end
    love.graphics.rectangle("line", x, y, layout.cardWidth, layout.cardHeight, 6, 6)
    love.graphics.setLineWidth(1)

    -- Ability indicator
    if card.ability and card.ability ~= "none" then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", x, y + layout.cardHeight - 18, layout.cardWidth, 18, 0, 0, 6, 6)
        love.graphics.setColor(0.9, 0.7, 0.2)
        love.graphics.setFont(UI.fonts.get(10))
        local abilityInfo = Cards.abilities and Cards.abilities[card.ability]
        local abilityName = abilityInfo and abilityInfo.name or card.ability
        local abilityW = love.graphics.getFont():getWidth(abilityName)
        love.graphics.print(abilityName, x + layout.cardWidth/2 - abilityW/2, y + layout.cardHeight - 15)
    end

    -- Rarity dot
    love.graphics.setColor(rarity.color)
    love.graphics.circle("fill", x + layout.cardWidth - 10, y + 10, 5)

    -- Fusion count indicator (only in fusion mode)
    if shared.fusionMode then
        local fc = card.fusionCount or 0
        local maxed = fc >= shared.MAX_FUSION_COUNT
        love.graphics.setColor(maxed and {0.7, 0.2, 0.2, 0.9} or {0.2, 0.5, 0.7, 0.9})
        love.graphics.rectangle("fill", x + 2, y + 2, 24, 16, 3, 3)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.fonts.get(10))
        love.graphics.print(fc .. "/" .. shared.MAX_FUSION_COUNT, x + 4, y + 3)
    end

    -- Show "MAX" overlay if card can't be fused anymore
    if shared.fusionMode then
        local fc = card.fusionCount or 0
        if fc >= shared.MAX_FUSION_COUNT then
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.rectangle("fill", x, y, layout.cardWidth, layout.cardHeight, 6, 6)
            love.graphics.setColor(1, 0.3, 0.3)
            love.graphics.setFont(UI.fonts.get(14))
            local maxText = "MAX FUSED"
            local textW = love.graphics.getFont():getWidth(maxText)
            love.graphics.print(maxText, x + layout.cardWidth/2 - textW/2, y + layout.cardHeight/2 - 7)
        end
    end

    -- Card tint for special cards (glass, steel, gold)
    if card.ability == "glass" then
        love.graphics.setColor(0.5, 0.8, 1, 0.3)
        love.graphics.rectangle("fill", x, y, layout.cardWidth, layout.cardHeight, 6, 6)
    elseif card.ability == "steel" then
        love.graphics.setColor(0.7, 0.7, 0.8, 0.3)
        love.graphics.rectangle("fill", x, y, layout.cardWidth, layout.cardHeight, 6, 6)
    elseif card.ability == "gold" then
        love.graphics.setColor(1, 0.85, 0.2, 0.3)
        love.graphics.rectangle("fill", x, y, layout.cardWidth, layout.cardHeight, 6, 6)
    end

    -- HOLOGRAPHIC EFFECTS FOR FUSED CARDS
    local fusionCount = card.fusionCount or 0
    if fusionCount > 0 then
        love.graphics.setScissor(x, y, layout.cardWidth, layout.cardHeight)

        Effects.drawParallaxCard(card, x, y, layout.cardWidth, layout.cardHeight)

        local holoIntensity = math.min(fusionCount / 3, 1)
        Effects.drawHolographicEffect(x, y, layout.cardWidth, layout.cardHeight, holoIntensity)

        if fusionCount >= 2 then
            Effects.drawFoilEffect(x, y, layout.cardWidth, layout.cardHeight)
        end
        if fusionCount >= 3 then
            Effects.drawPrismaticEffect(x, y, layout.cardWidth, layout.cardHeight)
        end

        love.graphics.setScissor()

        -- Fusion level indicator glow
        local glowColors = {
            {0.6, 0.4, 1},
            {0.4, 0.8, 1},
            {1, 0.8, 0.4},
        }
        local glowColor = glowColors[fusionCount] or glowColors[3]

        local pulse = 0.5 + 0.5 * math.sin(effectTime * 3 + x * 0.01)
        love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], 0.3 * pulse)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x - 2, y - 2, layout.cardWidth + 4, layout.cardHeight + 4, 8, 8)
        love.graphics.setLineWidth(1)

        -- Fusion stars indicator
        love.graphics.setColor(1, 0.9, 0.5)
        love.graphics.setFont(UI.fonts.get(10))
        local stars = string.rep("\xe2\x98\x85", fusionCount)
        love.graphics.print(stars, x + 3, y + layout.cardHeight - 32)
    end

    -- Mutation effects (foil, holographic, etc.)
    if card.mutation then
        love.graphics.setScissor(x, y, layout.cardWidth, layout.cardHeight)
        if card.mutation == "foil" then
            Effects.drawFoilEffect(x, y, layout.cardWidth, layout.cardHeight)
        elseif card.mutation == "holographic" then
            Effects.drawHolographicEffect(x, y, layout.cardWidth, layout.cardHeight, 0.8)
        elseif card.mutation == "polychrome" then
            Effects.drawPrismaticEffect(x, y, layout.cardWidth, layout.cardHeight)
        end
        love.graphics.setScissor()

        -- Mutation badge
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", x + layout.cardWidth - 28, y + layout.cardHeight - 16, 26, 14, 3, 3)
        love.graphics.setColor(0.9, 0.7, 1)
        love.graphics.setFont(UI.fonts.get(8))
        local mutLabel = card.mutation:sub(1, 4):upper()
        love.graphics.print(mutLabel, x + layout.cardWidth - 26, y + layout.cardHeight - 14)
    end
end

local function drawJokerCard(joker, x, y, hovered, equipped)
    local rarityColor = Jokers.rarityColors[joker.rarity] or {0.5, 0.5, 0.5}

    -- Track hovered joker for tooltip
    if hovered then
        shared.hoveredJoker = joker
        shared.hoveredJokerPos = {x = x, y = y}
    end

    -- Background with gradient effect
    love.graphics.setColor(0.15, 0.12, 0.2)
    love.graphics.rectangle("fill", x, y, 100, 120, 8, 8)

    -- Inner glow based on rarity
    love.graphics.setColor(rarityColor[1] * 0.2, rarityColor[2] * 0.2, rarityColor[3] * 0.2, 0.5)
    love.graphics.rectangle("fill", x + 3, y + 3, 94, 114, 6, 6)

    -- Border
    if equipped then
        love.graphics.setColor(0.2, 0.9, 0.2)
        love.graphics.setLineWidth(3)
    elseif hovered then
        love.graphics.setColor(1, 0.9, 0.3)
        love.graphics.setLineWidth(3)
    else
        love.graphics.setColor(rarityColor)
        love.graphics.setLineWidth(2)
    end
    love.graphics.rectangle("line", x, y, 100, 120, 8, 8)
    love.graphics.setLineWidth(1)

    -- Joker icon with shadow
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.setFont(UI.fonts.get(36))
    love.graphics.print("J", x + 34, y + 10)
    love.graphics.setColor(rarityColor)
    love.graphics.print("J", x + 32, y + 8)

    -- Name panel
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", x + 2, y + 48, 96, 20, 4, 4)

    -- Name
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(10))
    local name = joker.name
    local nameFont = love.graphics.getFont()
    local nameW = nameFont:getWidth(name)
    if nameW > 92 then
        name = name:sub(1, 12) .. ".."
        nameW = nameFont:getWidth(name)
    end
    love.graphics.print(name, x + 50 - nameW/2, y + 51)

    -- Description panel
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", x + 2, y + 70, 96, 26, 4, 4)

    -- Description with word wrap
    love.graphics.setColor(0.9, 0.85, 0.7)
    love.graphics.setFont(UI.fonts.get(9))
    local desc = joker.description
    local descFont = love.graphics.getFont()
    local maxWidth = 90

    local line1, line2 = desc, ""
    if descFont:getWidth(desc) > maxWidth then
        local words = {}
        for word in desc:gmatch("%S+") do
            table.insert(words, word)
        end
        line1 = ""
        line2 = ""
        local onLine1 = true
        for _, word in ipairs(words) do
            local testLine = line1 .. (line1 ~= "" and " " or "") .. word
            if onLine1 and descFont:getWidth(testLine) <= maxWidth then
                line1 = testLine
            else
                onLine1 = false
                line2 = line2 .. (line2 ~= "" and " " or "") .. word
            end
        end
        if descFont:getWidth(line2) > maxWidth then
            while descFont:getWidth(line2 .. "..") > maxWidth and #line2 > 0 do
                line2 = line2:sub(1, -2)
            end
            line2 = line2 .. ".."
        end
    end

    local line1W = descFont:getWidth(line1)
    love.graphics.print(line1, x + 50 - line1W/2, y + 71)
    if line2 ~= "" then
        local line2W = descFont:getWidth(line2)
        love.graphics.print(line2, x + 50 - line2W/2, y + 82)
    end

    -- Equipped indicator
    if equipped then
        love.graphics.setColor(0.1, 0.5, 0.1, 0.9)
        love.graphics.rectangle("fill", x + 2, y + 100, 96, 18, 0, 0, 6, 6)
        love.graphics.setColor(0.3, 1, 0.3)
        love.graphics.setFont(UI.fonts.get(11))
        love.graphics.print("EQUIPPED", x + 18, y + 102)
    end

    -- Rarity indicator
    love.graphics.setColor(rarityColor)
    love.graphics.circle("fill", x + 90, y + 10, 6)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.circle("line", x + 90, y + 10, 6)
end

-- ============================================
-- TOOLTIP DRAWING
-- ============================================

local function drawCardTooltip(card, cardX, cardY, screenW, screenH)
    local layout = shared.layout
    local tooltipW = 220
    local tooltipH = 160
    local padding = 10

    local tooltipX = cardX + layout.cardWidth + 10
    local tooltipY = cardY

    if tooltipX + tooltipW > screenW - 10 then
        tooltipX = cardX - tooltipW - 10
    end
    if tooltipY + tooltipH > screenH - 10 then
        tooltipY = screenH - tooltipH - 10
    end
    if tooltipY < 10 then
        tooltipY = 10
    end

    local rarity = Cards.rarities[card.rarity] or Cards.rarities.common
    local rarityColor = rarity.color

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", tooltipX + 4, tooltipY + 4, tooltipW, tooltipH, 10, 10)

    love.graphics.setColor(0.1, 0.1, 0.15, 0.98)
    love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipW, tooltipH, 10, 10)

    love.graphics.setColor(rarityColor)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", tooltipX, tooltipY, tooltipW, tooltipH, 10, 10)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(rarityColor[1] * 0.3, rarityColor[2] * 0.3, rarityColor[3] * 0.3, 0.8)
    love.graphics.rectangle("fill", tooltipX + 2, tooltipY + 2, tooltipW - 4, 28, 8, 8, 0, 0)

    local suitSymbol = Cards.suitSymbols[card.suit] or "?"
    local suitColor = Cards.suitColors[card.suit] or {0.5, 0.5, 0.5}
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(14))
    local cardName = card.rank .. " of " .. (card.suit and card.suit:sub(1,1):upper() .. card.suit:sub(2) or "?")
    love.graphics.print(cardName, tooltipX + padding, tooltipY + 6)

    love.graphics.setColor(suitColor)
    love.graphics.setFont(UI.fonts.get(18))
    love.graphics.print(suitSymbol, tooltipX + tooltipW - 25, tooltipY + 4)

    love.graphics.setColor(0.3, 0.3, 0.4)
    love.graphics.line(tooltipX + padding, tooltipY + 34, tooltipX + tooltipW - padding, tooltipY + 34)

    local yPos = tooltipY + 42
    love.graphics.setFont(UI.fonts.get(12))

    love.graphics.setColor(0.3, 0.6, 1)
    local baseChips = Cards.rankValues[card.rank] or 0
    local bonusChips = card.chips or 0
    love.graphics.print(string.format("Chips: %d", baseChips + bonusChips), tooltipX + padding, yPos)
    if bonusChips > 0 then
        love.graphics.setColor(0.3, 0.9, 0.3)
        love.graphics.print(string.format(" (+%d bonus)", bonusChips), tooltipX + 80, yPos)
    end
    yPos = yPos + 18

    if card.mult and card.mult > 0 then
        love.graphics.setColor(1, 0.5, 0.3)
        love.graphics.print(string.format("Mult: +%d", card.mult), tooltipX + padding, yPos)
        yPos = yPos + 18
    end

    love.graphics.setColor(rarityColor)
    local rarityName = card.rarity and (card.rarity:sub(1,1):upper() .. card.rarity:sub(2)) or "Common"
    love.graphics.print("Rarity: " .. rarityName, tooltipX + padding, yPos)
    yPos = yPos + 18

    if card.ability and card.ability ~= "none" then
        local abilityInfo = Cards.abilities[card.ability]
        if abilityInfo then
            love.graphics.setColor(0.9, 0.7, 0.2)
            love.graphics.print("Ability: " .. abilityInfo.name, tooltipX + padding, yPos)
            yPos = yPos + 16

            love.graphics.setColor(0.8, 0.8, 0.7)
            love.graphics.setFont(UI.fonts.get(10))
            local desc = abilityInfo.description or ""
            local maxW = tooltipW - padding * 2
            local descFont = love.graphics.getFont()
            if descFont:getWidth(desc) > maxW then
                local words = {}
                for word in desc:gmatch("%S+") do table.insert(words, word) end
                local line1, line2 = "", ""
                local onLine1 = true
                for _, word in ipairs(words) do
                    local testLine = line1 .. (line1 ~= "" and " " or "") .. word
                    if onLine1 and descFont:getWidth(testLine) <= maxW then
                        line1 = testLine
                    else
                        onLine1 = false
                        line2 = line2 .. (line2 ~= "" and " " or "") .. word
                    end
                end
                love.graphics.print(line1, tooltipX + padding, yPos)
                if line2 ~= "" then
                    yPos = yPos + 12
                    love.graphics.print(line2, tooltipX + padding, yPos)
                end
            else
                love.graphics.print(desc, tooltipX + padding, yPos)
            end
        end
    end

    if card.viralEffect then
        local viral = Cards.viralEffects[card.viralEffect]
        if viral then
            love.graphics.setColor(0.9, 0.4, 0.9)
            love.graphics.setFont(UI.fonts.get(10))
            love.graphics.print(viral.symbol .. " " .. viral.name .. " (Viral)", tooltipX + padding, tooltipY + tooltipH - 20)
        end
    end
end

local function drawJokerTooltip(joker, cardX, cardY, screenW, screenH)
    local tooltipW = 250
    local tooltipH = 140
    local padding = 12

    local tooltipX = cardX + 110
    local tooltipY = cardY

    if tooltipX + tooltipW > screenW - 10 then
        tooltipX = cardX - tooltipW - 10
    end
    if tooltipY + tooltipH > screenH - 10 then
        tooltipY = screenH - tooltipH - 10
    end
    if tooltipY < 10 then
        tooltipY = 10
    end

    local rarityColor = Jokers.rarityColors[joker.rarity] or {0.5, 0.5, 0.5}

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", tooltipX + 4, tooltipY + 4, tooltipW, tooltipH, 10, 10)

    love.graphics.setColor(0.1, 0.1, 0.15, 0.98)
    love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipW, tooltipH, 10, 10)

    love.graphics.setColor(rarityColor)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", tooltipX, tooltipY, tooltipW, tooltipH, 10, 10)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(rarityColor[1] * 0.3, rarityColor[2] * 0.3, rarityColor[3] * 0.3, 0.8)
    love.graphics.rectangle("fill", tooltipX + 2, tooltipY + 2, tooltipW - 4, 28, 8, 8, 0, 0)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.print(joker.name, tooltipX + padding, tooltipY + 6)

    love.graphics.setColor(rarityColor)
    love.graphics.setFont(UI.fonts.get(11))
    local rarityText = joker.rarity:sub(1, 1):upper() .. joker.rarity:sub(2)
    local rarityW = love.graphics.getFont():getWidth(rarityText)
    love.graphics.print(rarityText, tooltipX + tooltipW - rarityW - padding, tooltipY + 8)

    love.graphics.setColor(0.3, 0.3, 0.4)
    love.graphics.line(tooltipX + padding, tooltipY + 34, tooltipX + tooltipW - padding, tooltipY + 34)

    love.graphics.setColor(0.95, 0.9, 0.8)
    love.graphics.setFont(UI.fonts.get(12))
    local desc = joker.description
    local descFont = love.graphics.getFont()
    local maxTextW = tooltipW - padding * 2
    local lineHeight = 16
    local yPos = tooltipY + 42

    local words = {}
    for word in desc:gmatch("%S+") do
        table.insert(words, word)
    end

    local currentLine = ""
    for _, word in ipairs(words) do
        local testLine = currentLine .. (currentLine ~= "" and " " or "") .. word
        if descFont:getWidth(testLine) <= maxTextW then
            currentLine = testLine
        else
            love.graphics.print(currentLine, tooltipX + padding, yPos)
            yPos = yPos + lineHeight
            currentLine = word
        end
    end
    if currentLine ~= "" then
        love.graphics.print(currentLine, tooltipX + padding, yPos)
        yPos = yPos + lineHeight
    end

    love.graphics.setColor(0.9, 0.8, 0.2)
    love.graphics.setFont(UI.fonts.get(11))
    love.graphics.print(string.format("Cost: %d coins", joker.cost or 0), tooltipX + padding, tooltipY + tooltipH - 24)

    love.graphics.setColor(rarityColor)
    love.graphics.circle("fill", tooltipX + tooltipW - 20, tooltipY + tooltipH - 18, 5)
end

-- ============================================
-- TAB DRAWING FUNCTIONS
-- ============================================

local function drawTabs(screenW)
    local tabY = 60

    if shared.mainTabBar then
        shared.mainTabBar.activeTab = shared.currentTab
        shared.mainTabBar:draw()
    end

    if shared.fusionButton then
        shared.fusionButton.text = shared.fusionMode and "Cancel" or "Fusion"
        shared.fusionButton:draw()
    end

    if shared.sellButton then
        shared.sellButton.text = shared.sellMode and "Cancel" or "Sell Mode"
        shared.sellButton:draw()
    end

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.print(string.format("Total: %d cards, %d jokers",
        #PlayerData.collection, #(PlayerData.ownedJokers or {})), screenW - 470, tabY + 10)

    love.graphics.setColor(1, 1, 1)
end

local function drawFilters(screenW)
    local filterY = 105
    local filters = shared.filters
    love.graphics.setFont(UI.fonts.get(11))

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Suit:", 50, filterY)

    if shared.suitFilterBar then
        shared.suitFilterBar.activeTab = filters.suit
        shared.suitFilterBar:draw()
    end

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Rarity:", 300, filterY)

    if shared.rarityFilterBar then
        shared.rarityFilterBar.activeTab = filters.rarity
        shared.rarityFilterBar:draw()
    end

    -- Second row of rarity filters (mythic through primordial)
    local rarities2 = {"mythic", "divine", "cosmic", "transcendent", "eternal", "primordial"}
    local rarityLabels = {mythic = "Myth", divine = "Div", cosmic = "Cos", transcendent = "Tran", eternal = "Eter", primordial = "Prim"}

    local filterY2 = 124
    for i, rarity in ipairs(rarities2) do
        local btnX = 350 + (i-1) * 58
        local selected = filters.rarity == rarity

        local mx, my = love.mouse.getPosition()
        local isHovered = mx >= btnX and mx <= btnX + 54 and my >= filterY2 and my <= filterY2 + 18

        love.graphics.setColor(selected and UI.theme.colors.secondary or UI.theme.colors.bgDark)
        love.graphics.rectangle("fill", btnX, filterY2, 54, 18, 3, 3)

        if isHovered and not selected then
            love.graphics.setColor(UI.theme.colors.bgLight)
            love.graphics.rectangle("fill", btnX, filterY2, 54, 18, 3, 3)
        end

        local rarityColor = Cards.rarities[rarity] and Cards.rarities[rarity].color or {1,1,1}
        love.graphics.setColor(rarityColor)
        love.graphics.setFont(UI.fonts.get(10))
        love.graphics.print(rarityLabels[rarity], btnX + 4, filterY2 + 3)
    end

    love.graphics.setColor(1, 1, 1)
end

local function drawCollectionTab()
    local layout = shared.layout
    local mx, my = love.mouse.getPosition()
    shared.hoveredCard = nil

    love.graphics.setFont(UI.fonts.get(12))

    love.graphics.setScissor(layout.areaX, layout.areaY, layout.areaWidth, layout.areaHeight)

    local filteredCards = getFilteredCollection()
    local x, y = layout.areaX + 20, layout.areaY + 20
    local col = 0

    for i, collCard in ipairs(filteredCards) do
        local cardX = x + col * layout.cardSpacing
        local cardY = y + math.floor((i-1) / layout.cardsPerRow) * (layout.cardHeight + 20) - shared.scrollOffset

        if cardY > layout.areaY - layout.cardHeight and cardY < layout.areaY + layout.areaHeight then
            local hovered = mx >= cardX and mx <= cardX + layout.cardWidth and
                           my >= cardY and my <= cardY + layout.cardHeight

            if hovered then
                shared.hoveredCard = {index = i, card = collCard.card, type = "collection", collCard = collCard}
            end

            drawCollectionCard(collCard.card, cardX, cardY, hovered, shared.selectedCard and shared.selectedCard.collCard and shared.selectedCard.collCard.id == collCard.id)

            -- Show sell price in sell mode with coin icon
            if shared.sellMode and hovered then
                local sellPrice = getSellPrice(collCard.card)
                local coinImg = UIAssets.getIconByName("gold_coin")
                if coinImg then
                    love.graphics.setColor(1, 1, 1)
                    local imgW, imgH = coinImg:getDimensions()
                    local scale = 14 / math.max(imgW, imgH)
                    love.graphics.draw(coinImg, cardX, cardY - 18, 0, scale, scale)
                end
                love.graphics.setColor(0.9, 0.8, 0.2)
                love.graphics.setFont(UI.fonts.get(14))
                love.graphics.print(sellPrice, cardX + 18, cardY - 18)
            end
        end

        col = col + 1
        if col >= layout.cardsPerRow then col = 0 end
    end

    love.graphics.setScissor()

    -- Show scroll hint
    local rows = math.ceil(#filteredCards / layout.cardsPerRow)
    local contentHeight = rows * (layout.cardHeight + 20)
    local maxScroll = math.max(0, contentHeight - layout.areaHeight + 40)
    if contentHeight > layout.areaHeight then
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.setFont(UI.fonts.get(12))
        love.graphics.print("Scroll to see more cards", layout.areaX + layout.areaWidth - 180, layout.areaY + layout.areaHeight + 5)
        local scrollbarX = layout.areaX + layout.areaWidth - 8
        local scrollbarH = layout.areaHeight
        local thumbH = math.max(30, scrollbarH * (layout.areaHeight / contentHeight))
        local thumbY = layout.areaY + (shared.scrollOffset / math.max(1, maxScroll)) * (scrollbarH - thumbH)
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", scrollbarX, layout.areaY, 6, scrollbarH, 3, 3)
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.rectangle("fill", scrollbarX, thumbY, 6, thumbH, 3, 3)
    end

    -- Show filtered count
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print(string.format("Showing %d of %d cards", #filteredCards, #PlayerData.collection),
        layout.areaX, layout.areaY + layout.areaHeight + 5)
end

local function drawJokersTab()
    local layout = shared.layout
    local mx, my = love.mouse.getPosition()
    shared.hoveredCard = nil

    if not PlayerData.ownedJokers then
        PlayerData.ownedJokers = {}
    end
    if not PlayerData.equippedJokers then
        PlayerData.equippedJokers = {}
    end

    love.graphics.setScissor(layout.areaX, layout.areaY, layout.areaWidth, layout.areaHeight)

    -- Equipped jokers section
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.setFont(UI.fonts.get(16))
    love.graphics.print("Equipped Jokers (max 5):", layout.areaX + 20, layout.areaY + 10)

    for i, jokerData in ipairs(PlayerData.equippedJokers) do
        local joker = Jokers.getById(jokerData.id)
        if joker then
            local jx = layout.areaX + 20 + (i-1) * 120
            local jy = layout.areaY + 40
            drawJokerCard(joker, jx, jy, false, true)
        end
    end

    -- Owned jokers section
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print("Owned Jokers:", layout.areaX + 20, layout.areaY + 180)

    local x, y = layout.areaX + 20, layout.areaY + 210
    local col = 0

    for i, jokerData in ipairs(PlayerData.ownedJokers) do
        local joker = Jokers.getById(jokerData.id)
        if joker then
            local jx = x + col * 120
            local jy = y + math.floor((i-1) / 9) * 140 - shared.scrollOffset

            if jy > layout.areaY and jy < layout.areaY + layout.areaHeight then
                local hovered = mx >= jx and mx <= jx + 100 and my >= jy and my <= jy + 120

                if hovered then
                    shared.hoveredCard = {index = i, joker = joker, type = "joker", jokerData = jokerData}
                end

                local equipped = false
                for _, eq in ipairs(PlayerData.equippedJokers) do
                    if eq.id == jokerData.id then
                        equipped = true
                        break
                    end
                end

                drawJokerCard(joker, jx, jy, hovered, equipped)

                if shared.sellMode and hovered then
                    local sellPrice = math.floor(joker.cost * 0.5)
                    local coinImg = UIAssets.getIconByName("gold_coin")
                    if coinImg then
                        love.graphics.setColor(1, 1, 1)
                        local imgW, imgH = coinImg:getDimensions()
                        local scale = 14 / math.max(imgW, imgH)
                        love.graphics.draw(coinImg, jx, jy - 18, 0, scale, scale)
                    end
                    love.graphics.setColor(0.9, 0.8, 0.2)
                    love.graphics.setFont(UI.fonts.get(14))
                    love.graphics.print(sellPrice, jx + 18, jy - 18)
                end
            end

            col = col + 1
            if col >= 9 then col = 0 end
        end
    end

    love.graphics.setScissor()
end

local function drawCardDetails(screenW, screenH)
    local card = shared.selectedCard.card
    if not card then return end

    love.graphics.setColor(0.1, 0.1, 0.15, 0.95)
    love.graphics.rectangle("fill", screenW/2 - 200, screenH/2 - 150, 400, 300, 10, 10)

    local rarity = Cards.rarities[card.rarity] or Cards.rarities.common
    love.graphics.setColor(rarity.color)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", screenW/2 - 200, screenH/2 - 150, 400, 300, 10, 10)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(28))
    local name = Cards.getDisplayName(card)
    local nameW = love.graphics.getFont():getWidth(name)
    love.graphics.print(name, screenW/2 - nameW/2, screenH/2 - 130)

    love.graphics.setColor(rarity.color)
    love.graphics.setFont(UI.fonts.get(18))
    local rarityName = card.rarity:sub(1,1):upper() .. card.rarity:sub(2)
    local rarityW = love.graphics.getFont():getWidth(rarityName)
    love.graphics.print(rarityName, screenW/2 - rarityW/2, screenH/2 - 90)

    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.setFont(UI.fonts.get(16))
    love.graphics.print(string.format("Chips: +%d", card.chips), screenW/2 - 60, screenH/2 - 50)
    if card.mult and card.mult > 0 then
        love.graphics.print(string.format("Mult: +%d", card.mult), screenW/2 - 60, screenH/2 - 25)
    end

    if card.ability and card.ability ~= "none" then
        local ability = Cards.abilities[card.ability]
        love.graphics.setColor(0.9, 0.7, 0.2)
        love.graphics.setFont(UI.fonts.get(18))
        love.graphics.print(ability.name, screenW/2 - 80, screenH/2 + 20)

        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.setFont(UI.fonts.get(14))
        love.graphics.print(ability.description, screenW/2 - 120, screenH/2 + 50)
    end

    local sellPrice = getSellPrice(card)
    love.graphics.setColor(0.9, 0.8, 0.3)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.print(string.format("Sell value: %d coins", sellPrice), screenW/2 - 60, screenH/2 + 90)

    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.print("Click anywhere to close", screenW/2 - 70, screenH/2 + 120)
end

-- ============================================
-- DRAW (main dispatcher)
-- ============================================

function Collection.draw()
    local screenW, screenH = love.graphics.getDimensions()
    local layout = shared.layout

    -- Reset hover states at start of frame
    shared.hoveredJoker = nil
    shared.hoveredCardInfo = nil

    -- Clear currency tooltip state
    UIAssets.clearTooltip()

    -- Title and coins
    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(UI.fonts.get(32))
    love.graphics.print("Collection", 50, 20)

    -- Coins display with hover tooltip
    love.graphics.setFont(UI.fonts.get(18))
    local coinX = screenW - 280
    UIAssets.drawCurrencyWithTooltip("coins", PlayerData.coins, coinX, 22, 22)

    -- Crystal display with hover tooltip
    local crystalX = screenW - 150
    UIAssets.drawCurrencyWithTooltip("crystals", PlayerData.crystals or 0, crystalX, 22, 22)

    -- Tab buttons
    drawTabs(screenW)

    -- Filters (for collection tab)
    if shared.currentTab == "collection" then
        drawFilters(screenW)
    end

    -- Main area background
    love.graphics.setColor(0.12, 0.12, 0.18)
    love.graphics.rectangle("fill", layout.areaX, layout.areaY,
        layout.areaWidth, layout.areaHeight, 10, 10)

    if shared.currentTab == "collection" then
        drawCollectionTab()
    elseif shared.currentTab == "shop" then
        Shop.drawShopTab(drawCollectionCard, drawJokerCard)
    elseif shared.currentTab == "jokers" then
        drawJokersTab()
    elseif shared.currentTab == "upgrades" then
        Fusion.drawUpgradesTab()
    elseif shared.currentTab == "themes" then
        Themes.drawThemesTab()
    elseif shared.currentTab == "portraits" then
        Themes.drawPortraitsTab()
    end

    -- Card details panel (if card selected)
    if shared.selectedCard then
        drawCardDetails(screenW, screenH)
    end

    -- Sell mode indicator
    if shared.sellMode then
        love.graphics.setColor(0.9, 0.3, 0.3)
        love.graphics.setFont(UI.fonts.get(16))
        love.graphics.print("SELL MODE - Click cards to sell them", screenW/2 - 150, layout.areaY + layout.areaHeight + 10)
    end

    -- Fusion mode indicator and panel
    if shared.fusionMode then
        love.graphics.setColor(0.7, 0.4, 0.9)
        love.graphics.setFont(UI.fonts.get(16))
        love.graphics.print("FUSION MODE - Select 2 cards to fuse", screenW/2 - 150, layout.areaY + layout.areaHeight + 10)

        Fusion.drawFusionPanel(screenW, screenH)
    end

    -- Instructions
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.print("Click a card to see details. Press ESC to return to menu.", 50, screenH - 25)

    -- Draw fusion particles
    Effects.drawParticles()

    -- Draw fusion notifications (floating text)
    local fusionNotifications = Effects.getFusionNotifications()
    love.graphics.setFont(UI.fonts.get(16))
    for i, notif in ipairs(fusionNotifications) do
        love.graphics.setColor(notif.color[1], notif.color[2], notif.color[3], notif.alpha)
        local notifY = screenH - 150 - notif.y - (i - 1) * 25
        love.graphics.printf(notif.text, 0, notifY, screenW, "center")
    end

    -- Draw screen effects (flash overlay)
    Effects.drawScreenEffects(screenW, screenH)

    -- Draw tooltips last (on top of everything)
    if shared.hoveredCardInfo and not shared.hoveredJoker then
        drawCardTooltip(shared.hoveredCardInfo, shared.hoveredCardPos.x, shared.hoveredCardPos.y, screenW, screenH)
    end
    if shared.hoveredJoker then
        drawJokerTooltip(shared.hoveredJoker, shared.hoveredJokerPos.x, shared.hoveredJokerPos.y, screenW, screenH)
    end

    -- Draw currency tooltips (on top of everything)
    UIAssets.drawTooltip()
end

-- ============================================
-- MOUSEPRESSED (main dispatcher)
-- ============================================

function Collection.mousepressed(x, y, button)
    if button ~= 1 then return end

    local screenW, screenH = love.graphics.getDimensions()

    -- Fusion button click
    if shared.fusionMode and #shared.fusionCards == 2 then
        if Fusion.handleFuseButtonClick(x, y) then
            return
        end
    end

    -- Close card details
    if shared.selectedCard then
        shared.selectedCard = nil
        return
    end

    -- UI Components input handling
    if shared.mainTabBar and shared.mainTabBar:mousepressed(x, y, button) then
        return
    end

    if shared.fusionButton and shared.fusionButton:mousepressed(x, y, button) then
        return
    end

    if shared.sellButton and shared.sellButton:mousepressed(x, y, button) then
        return
    end

    -- Filter clicks (collection tab only)
    if shared.currentTab == "collection" then
        if shared.suitFilterBar and shared.suitFilterBar:mousepressed(x, y, button) then
            return
        end

        if shared.rarityFilterBar and shared.rarityFilterBar:mousepressed(x, y, button) then
            return
        end

        -- Rarity filters (second row - custom)
        local rarities2 = {"mythic", "divine", "cosmic", "transcendent", "eternal", "primordial"}
        local filterY2 = 124
        for i, rarity in ipairs(rarities2) do
            local btnX = 350 + (i-1) * 58
            if x >= btnX and x <= btnX + 54 and y >= filterY2 and y <= filterY2 + 18 then
                shared.filters.rarity = rarity
                shared.scrollOffset = 0
                return
            end
        end
    end

    -- Shop refresh button
    if shared.currentTab == "shop" then
        if Shop.handleRefreshClick(x, y) then
            return
        end
    end

    -- Upgrade purchase clicks
    if shared.currentTab == "upgrades" then
        if Fusion.handleUpgradeClick(x, y) then
            return
        end
    end

    -- Card/Joker clicks
    local hoveredCard = shared.hoveredCard
    if hoveredCard then
        if hoveredCard.type == "shop" then
            -- Buy card
            local shopItem = shared.shopCards[hoveredCard.index]
            if PlayerData.coins >= shopItem.price then
                PlayerData.coins = PlayerData.coins - shopItem.price
                table.insert(PlayerData.collection, {
                    id = getNextCollectionId(),
                    cardId = shopItem.card.id,
                    card = shopItem.card
                })
                table.remove(shared.shopCards, hoveredCard.index)
                savePlayerData()
            end
        elseif hoveredCard.type == "shopJoker" then
            -- Buy joker
            local joker = shared.shopJokers[hoveredCard.index]
            if PlayerData.coins >= joker.cost then
                PlayerData.coins = PlayerData.coins - joker.cost
                if not PlayerData.ownedJokers then PlayerData.ownedJokers = {} end
                table.insert(PlayerData.ownedJokers, {id = joker.id})
                table.remove(shared.shopJokers, hoveredCard.index)
                savePlayerData()
            end
        elseif hoveredCard.type == "collection" then
            if shared.sellMode then
                -- Sell card
                local collCard = hoveredCard.collCard
                local sellPrice = getSellPrice(collCard.card)
                PlayerData.coins = PlayerData.coins + sellPrice

                -- Award crystals for epic+ cards
                local crystalRewards = {epic = 1, legendary = 2, mythic = 3, divine = 3, cosmic = 3, transcendent = 3, eternal = 3, primordial = 3}
                local crystalBonus = crystalRewards[collCard.card.rarity] or 0
                if crystalBonus > 0 then
                    PlayerData.crystals = (PlayerData.crystals or 0) + crystalBonus
                    Effects.addFusionNotification("+" .. crystalBonus .. " Crystals from sale!", {0.4, 0.8, 1})
                end

                for i, c in ipairs(PlayerData.collection) do
                    if c.id == collCard.id then
                        table.remove(PlayerData.collection, i)
                        break
                    end
                end

                if PlayerData.currentDeck then
                    for i, dc in ipairs(PlayerData.currentDeck) do
                        if dc.id == collCard.id then
                            table.remove(PlayerData.currentDeck, i)
                            break
                        end
                    end
                end

                savePlayerData()
            elseif shared.fusionMode then
                -- Add card to fusion selection
                local collCard = hoveredCard.collCard

                local alreadySelected = false
                for i, fc in ipairs(shared.fusionCards) do
                    if fc.id == collCard.id then
                        table.remove(shared.fusionCards, i)
                        alreadySelected = true
                        break
                    end
                end

                local fusionCount = collCard.card.fusionCount or 0
                local canFuse = fusionCount < shared.MAX_FUSION_COUNT

                if not alreadySelected and #shared.fusionCards < 2 and canFuse then
                    table.insert(shared.fusionCards, collCard)
                end
            else
                shared.selectedCard = hoveredCard
            end
        elseif hoveredCard.type == "joker" then
            if shared.sellMode then
                -- Sell joker
                local jokerData = hoveredCard.jokerData
                local joker = hoveredCard.joker
                local sellPrice = math.floor(joker.cost * 0.5)
                PlayerData.coins = PlayerData.coins + sellPrice

                for i, j in ipairs(PlayerData.ownedJokers) do
                    if j.id == jokerData.id then
                        table.remove(PlayerData.ownedJokers, i)
                        break
                    end
                end

                if PlayerData.equippedJokers then
                    for i, j in ipairs(PlayerData.equippedJokers) do
                        if j.id == jokerData.id then
                            table.remove(PlayerData.equippedJokers, i)
                            break
                        end
                    end
                end

                savePlayerData()
            else
                -- Toggle equip
                if not PlayerData.equippedJokers then PlayerData.equippedJokers = {} end

                local isEquipped = false
                local equipIndex = nil
                for i, j in ipairs(PlayerData.equippedJokers) do
                    if j.id == hoveredCard.jokerData.id then
                        isEquipped = true
                        equipIndex = i
                        break
                    end
                end

                if isEquipped then
                    table.remove(PlayerData.equippedJokers, equipIndex)
                elseif #PlayerData.equippedJokers < 5 then
                    table.insert(PlayerData.equippedJokers, {id = hoveredCard.jokerData.id})
                end

                savePlayerData()
            end
        end
    end
end

-- ============================================
-- MOUSERELEASED
-- ============================================

function Collection.mousereleased(x, y, button)
    if button ~= 1 then return end

    if shared.fusionButton and shared.fusionButton:mousereleased(x, y, button) then
        return
    end

    if shared.sellButton and shared.sellButton:mousereleased(x, y, button) then
        return
    end
end

return Collection
