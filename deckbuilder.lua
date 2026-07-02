-- Deck builder interface

local DeckBuilder = {}
local Cards = require("cards")
local InteractiveTutorial = require("interactivetutorial")
local UI = require("ui")
local UITooltip = require("ui_tooltip")
local CardRenderer = require("ui_cardrenderer")

-- UI state
local deckScrollOffset = 0
local collectionScrollOffset = 0
local selectedDeckCard = nil
local selectedCollectionCard = nil
local currentDeck = {}
local message = ""
local messageTimer = 0
local hoveredCardInfo = nil
local hoveredCardPos = {x = 0, y = 0}

-- UI components
local saveButton = nil
local autoFillButton = nil
local clearButton = nil
local suitFilterButtons = {}
local rarityFilterButtons = {}

-- Filter state
local filters = {
    suit = "all",  -- all, hearts, diamonds, clubs, spades
    rarity = "all"  -- all, common, uncommon, rare, epic, legendary, mythic, divine, cosmic, transcendent, eternal, primordial
}

-- Layout
local layout = {
    cardWidth = 70,
    cardHeight = 100,
    cardSpacing = 80,
    deckAreaX = 20,
    deckAreaY = 100,
    deckAreaWidth = 500,
    deckAreaHeight = 400,
    collectionAreaX = 560,
    collectionAreaY = 180,  -- Moved down 10% to avoid filter overlap
    collectionAreaWidth = 660,
    collectionAreaHeight = 370,
    cardsPerRow = 7
}

-- Forward declarations
local drawMiniCard, saveDeck, autoFillDeck, showDeckMessage
local drawFilters, getFilteredCollection, initializeFilterButtons, updateButtonPositions

function DeckBuilder.init()
    -- Register UI region resolver for interactive tutorials
    InteractiveTutorial.registerRegionResolver("deckbuilder", DeckBuilder.getUIRegion)

    -- Reset scroll positions
    deckScrollOffset = 0
    collectionScrollOffset = 0

    -- Load current deck or create empty
    if PlayerData.currentDeck then
        currentDeck = {}
        for _, card in ipairs(PlayerData.currentDeck) do
            table.insert(currentDeck, card)
        end
    else
        currentDeck = {}
    end

    -- Initialize UI buttons
    local screenW, screenH = love.graphics.getDimensions()
    local buttonY = screenH - 80
    local buttonW, buttonH = 140, 45

    saveButton = UI.Button.new({
        x = screenW/2 - buttonW - 80,
        y = buttonY,
        w = buttonW,
        h = buttonH,
        text = "Save Deck",
        variant = "success",
        disabled = #currentDeck < 30,
        onClick = function()
            if #currentDeck >= 30 then
                saveDeck()
            else
                showDeckMessage("Need at least 30 cards!")
            end
        end
    })

    autoFillButton = UI.Button.new({
        x = screenW/2 - buttonW/2,
        y = buttonY,
        w = buttonW,
        h = buttonH,
        text = "Auto-Fill",
        variant = "secondary",
        onClick = function()
            autoFillDeck()
        end
    })

    clearButton = UI.Button.new({
        x = screenW/2 + 80,
        y = buttonY,
        w = buttonW,
        h = buttonH,
        text = "Clear Deck",
        variant = "danger",
        onClick = function()
            currentDeck = {}
            showDeckMessage("Deck cleared")
            saveButton.disabled = true
        end
    })

    -- Initialize filter buttons
    initializeFilterButtons()
end

function DeckBuilder.wheelmoved(x, y)
    local mx, my = love.mouse.getPosition()

    -- Check if mouse is over deck area
    if mx >= layout.deckAreaX and mx <= layout.deckAreaX + layout.deckAreaWidth and
       my >= layout.deckAreaY and my <= layout.deckAreaY + layout.deckAreaHeight then
        local rows = math.ceil(#currentDeck / 6)
        local contentHeight = rows * (layout.cardHeight + 10)
        local maxScroll = math.max(0, contentHeight - layout.deckAreaHeight + 30)

        deckScrollOffset = deckScrollOffset - y * 30
        deckScrollOffset = math.max(0, math.min(deckScrollOffset, maxScroll))

    -- Check if mouse is over collection area
    elseif mx >= layout.collectionAreaX and mx <= layout.collectionAreaX + layout.collectionAreaWidth and
           my >= layout.collectionAreaY and my <= layout.collectionAreaY + layout.collectionAreaHeight then
        local collection = PlayerData and PlayerData.collection or {}
        local rows = math.ceil(#collection / layout.cardsPerRow)
        local contentHeight = rows * (layout.cardHeight + 10)
        local maxScroll = math.max(0, contentHeight - layout.collectionAreaHeight + 30)

        collectionScrollOffset = collectionScrollOffset - y * 30
        collectionScrollOffset = math.max(0, math.min(collectionScrollOffset, maxScroll))
    end
end

function DeckBuilder.update(dt)
    if messageTimer > 0 then
        messageTimer = messageTimer - dt
        if messageTimer <= 0 then
            message = ""
        end
    end

    -- Update UI components
    if saveButton then
        saveButton.disabled = #currentDeck < 30
        saveButton:update(dt)
    end
    if autoFillButton then
        autoFillButton:update(dt)
    end
    if clearButton then
        clearButton:update(dt)
    end

    -- Update filter buttons
    for _, btn in ipairs(suitFilterButtons) do
        btn:update(dt)
    end
    for _, btn in ipairs(rarityFilterButtons) do
        btn:update(dt)
    end
end

updateButtonPositions = function()
    local screenW, screenH = love.graphics.getDimensions()
    local buttonY = screenH - 80
    local buttonW = 140

    if saveButton then
        saveButton.x = screenW/2 - buttonW - 80
        saveButton.y = buttonY
    end
    if autoFillButton then
        autoFillButton.x = screenW/2 - buttonW/2
        autoFillButton.y = buttonY
    end
    if clearButton then
        clearButton.x = screenW/2 + 80
        clearButton.y = buttonY
    end
end

initializeFilterButtons = function()
    local filterY = 55

    -- Suit filter buttons
    suitFilterButtons = {}
    local suits = {"all", "hearts", "diamonds", "clubs", "spades"}
    local suitLabels = {all = "All", hearts = "♥", diamonds = "♦", clubs = "♣", spades = "♠"}

    for i, suit in ipairs(suits) do
        local btnX = 635 + (i-1) * 38
        local btn = UI.Button.new({
            x = btnX,
            y = filterY - 3,
            w = 34,
            h = 18,
            text = suitLabels[suit],
            variant = filters.suit == suit and "primary" or "ghost",
            onClick = function()
                filters.suit = suit
                collectionScrollOffset = 0
                -- Update all suit button variants
                for j, sb in ipairs(suitFilterButtons) do
                    sb.variant = suits[j] == suit and "primary" or "ghost"
                end
            end
        })
        table.insert(suitFilterButtons, btn)
    end

    -- Rarity filter buttons
    rarityFilterButtons = {}
    local rarities = {"all", "common", "uncommon", "rare", "epic", "legendary", "mythic", "divine", "cosmic", "transcendent", "eternal", "primordial"}
    local rarityLabels = {all = "All", common = "Com", uncommon = "Unc", rare = "Rare", epic = "Epic", legendary = "Leg", mythic = "Myth", divine = "Div", cosmic = "Cos", transcendent = "Tran", eternal = "Eter", primordial = "Prim"}

    for i, rarity in ipairs(rarities) do
        local btnX = 635 + (i-1) * 52
        local rowY = filterY + 17
        if i > 6 then
            btnX = 635 + (i-7) * 52
            rowY = filterY + 37
        end

        local btn = UI.Button.new({
            x = btnX,
            y = rowY,
            w = 48,
            h = 16,
            text = rarityLabels[rarity],
            variant = filters.rarity == rarity and "primary" or "ghost",
            onClick = function()
                filters.rarity = rarity
                collectionScrollOffset = 0
                -- Update all rarity button variants
                for j, rb in ipairs(rarityFilterButtons) do
                    rb.variant = rarities[j] == rarity and "primary" or "ghost"
                end
            end
        })
        table.insert(rarityFilterButtons, btn)
    end
end

getFilteredCollection = function()
    local filtered = {}
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

drawFilters = function(screenW)
    local filterY = 55
    love.graphics.setFont(UI.fonts.get(10))

    -- Suit filter label
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Suit:", 600, filterY)

    -- Draw suit filter buttons
    for _, btn in ipairs(suitFilterButtons) do
        btn:draw()
    end

    -- Rarity filter label
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Rarity:", 600, filterY + 20)

    -- Draw rarity filter buttons
    for _, btn in ipairs(rarityFilterButtons) do
        btn:draw()
    end
end

function DeckBuilder.draw()
    local screenW, screenH = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()

    -- Update button positions for window resize
    updateButtonPositions()

    -- Reset hover state
    hoveredCardInfo = nil

    -- Title (moved to left side)
    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(UI.fonts.get(28))
    love.graphics.print("Deck Builder", layout.deckAreaX, 20)

    -- Deck count
    love.graphics.setFont(UI.fonts.get(16))
    local deckColor = #currentDeck >= 30 and {0.3, 0.9, 0.3} or {0.9, 0.5, 0.3}
    love.graphics.setColor(deckColor)
    love.graphics.print(string.format("Deck: %d/30 cards", #currentDeck), layout.deckAreaX, 55)

    -- Deck area background
    love.graphics.setColor(0.15, 0.15, 0.2)
    love.graphics.rectangle("fill", layout.deckAreaX, layout.deckAreaY,
        layout.deckAreaWidth, layout.deckAreaHeight, 10, 10)
    love.graphics.setColor(0.3, 0.3, 0.4)
    love.graphics.rectangle("line", layout.deckAreaX, layout.deckAreaY,
        layout.deckAreaWidth, layout.deckAreaHeight, 10, 10)

    -- Draw deck cards (with clipping)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.setScissor(layout.deckAreaX, layout.deckAreaY, layout.deckAreaWidth, layout.deckAreaHeight)

    local deckX, deckY = layout.deckAreaX + 15, layout.deckAreaY + 15
    local col = 0

    for i, deckCard in ipairs(currentDeck) do
        local x = deckX + col * layout.cardSpacing
        local y = deckY + math.floor((i-1) / 6) * (layout.cardHeight + 10) - deckScrollOffset

        -- Only draw visible cards
        if y > layout.deckAreaY - layout.cardHeight and y < layout.deckAreaY + layout.deckAreaHeight then
            -- Check hover
            local hovered = mx >= x and mx <= x + layout.cardWidth and
                           my >= y and my <= y + layout.cardHeight and
                           my >= layout.deckAreaY and my <= layout.deckAreaY + layout.deckAreaHeight
            if hovered then
                hoveredCardInfo = deckCard.card
                hoveredCardPos = {x = x, y = y}
            end
            drawMiniCard(deckCard.card, x, y, selectedDeckCard == i, hovered)
        end

        col = col + 1
        if col >= 6 then col = 0 end
    end

    love.graphics.setScissor()

    -- Draw filters
    drawFilters(screenW)

    -- Collection area
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.setFont(UI.fonts.get(18))
    love.graphics.print("Your Collection", layout.collectionAreaX, 100)

    love.graphics.setColor(0.15, 0.2, 0.15)
    love.graphics.rectangle("fill", layout.collectionAreaX, layout.collectionAreaY,
        layout.collectionAreaWidth, layout.collectionAreaHeight, 10, 10)
    love.graphics.setColor(0.3, 0.4, 0.3)
    love.graphics.rectangle("line", layout.collectionAreaX, layout.collectionAreaY,
        layout.collectionAreaWidth, layout.collectionAreaHeight, 10, 10)

    -- Draw collection cards (with clipping)
    love.graphics.setScissor(layout.collectionAreaX, layout.collectionAreaY + 30, layout.collectionAreaWidth, layout.collectionAreaHeight - 30)

    local filteredCards = getFilteredCollection()
    local collX, collY = layout.collectionAreaX + 15, layout.collectionAreaY + 45
    col = 0

    for i, collCard in ipairs(filteredCards) do
        -- Check if already in deck
        local inDeck = false
        for _, dc in ipairs(currentDeck) do
            if dc.id == collCard.id then
                inDeck = true
                break
            end
        end

        local x = collX + col * layout.cardSpacing
        local y = collY + math.floor((i-1) / layout.cardsPerRow) * (layout.cardHeight + 10) - collectionScrollOffset

        if y > layout.collectionAreaY - layout.cardHeight and y < layout.collectionAreaY + layout.collectionAreaHeight then
            -- Check hover (within scissor area)
            local hovered = mx >= x and mx <= x + layout.cardWidth and
                           my >= y and my <= y + layout.cardHeight and
                           my >= layout.collectionAreaY + 30 and my <= layout.collectionAreaY + layout.collectionAreaHeight

            if inDeck then
                -- Draw card greyed out to show it's in deck
                drawMiniCard(collCard.card, x, y, false, false)
                -- Overlay with semi-transparent dark layer
                love.graphics.setColor(0.1, 0.1, 0.1, 0.7)
                love.graphics.rectangle("fill", x, y, layout.cardWidth, layout.cardHeight, 5, 5)
                -- "In Deck" text
                love.graphics.setColor(0.5, 0.8, 0.5)
                love.graphics.setFont(UI.fonts.get(9))
                love.graphics.printf("IN DECK", x, y + layout.cardHeight/2 - 5, layout.cardWidth, "center")
            else
                if hovered then
                    hoveredCardInfo = collCard.card
                    hoveredCardPos = {x = x, y = y}
                end
                drawMiniCard(collCard.card, x, y, selectedCollectionCard == i, hovered)
            end
        end

        col = col + 1
        if col >= layout.cardsPerRow then col = 0 end
    end

    love.graphics.setScissor()

    -- Buttons
    if saveButton then saveButton:draw() end
    if autoFillButton then autoFillButton:draw() end
    if clearButton then clearButton:draw() end

    -- Message
    if message ~= "" then
        love.graphics.setColor(0.9, 0.8, 0.3)
        love.graphics.setFont(UI.fonts.get(18))
        local msgW = love.graphics.getFont():getWidth(message)
        love.graphics.print(message, screenW/2 - msgW/2, screenH - 120)
    end

    -- Scroll hints and scrollbars
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.setFont(UI.fonts.get(12))

    local deckRows = math.ceil(#currentDeck / 6)
    local deckContentHeight = deckRows * (layout.cardHeight + 10)
    local deckMaxScroll = math.max(0, deckContentHeight - layout.deckAreaHeight + 30)
    if deckContentHeight > layout.deckAreaHeight then
        love.graphics.print("Scroll to see more", layout.deckAreaX, layout.deckAreaY + layout.deckAreaHeight + 5)
        -- Deck scrollbar
        local scrollbarX = layout.deckAreaX + layout.deckAreaWidth - 8
        local scrollbarH = layout.deckAreaHeight
        local thumbH = math.max(30, scrollbarH * (layout.deckAreaHeight / deckContentHeight))
        local thumbY = layout.deckAreaY + (deckScrollOffset / deckMaxScroll) * (scrollbarH - thumbH)
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", scrollbarX, layout.deckAreaY, 6, scrollbarH, 3, 3)
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.rectangle("fill", scrollbarX, thumbY, 6, thumbH, 3, 3)
    end

    local filteredCards = getFilteredCollection()
    local collRows = math.ceil(#filteredCards / layout.cardsPerRow)
    local collContentHeight = collRows * (layout.cardHeight + 10)
    local collMaxScroll = math.max(0, collContentHeight - layout.collectionAreaHeight + 30)
    if collContentHeight > layout.collectionAreaHeight then
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.print("Scroll to see more", layout.collectionAreaX + layout.collectionAreaWidth - 130, layout.collectionAreaY + layout.collectionAreaHeight + 5)
        -- Collection scrollbar
        local scrollbarX = layout.collectionAreaX + layout.collectionAreaWidth - 8
        local scrollbarH = layout.collectionAreaHeight
        local thumbH = math.max(30, scrollbarH * (layout.collectionAreaHeight / collContentHeight))
        local thumbY = layout.collectionAreaY + (collectionScrollOffset / math.max(1, collMaxScroll)) * (scrollbarH - thumbH)
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", scrollbarX, layout.collectionAreaY, 6, scrollbarH, 3, 3)
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.rectangle("fill", scrollbarX, thumbY, 6, thumbH, 3, 3)
    end

    -- Collection count (separated from scroll hint)
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print(string.format("Showing %d of %d cards", #filteredCards, #(PlayerData and PlayerData.collection or {})), layout.collectionAreaX, layout.collectionAreaY + layout.collectionAreaHeight + 5)

    -- Instructions
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.print("Click cards to add/remove from deck. Need 30 cards minimum. Use mouse wheel to scroll.", 50, screenH - 40)
    love.graphics.print("Press ESC to return to menu", 50, screenH - 20)

    -- Draw card tooltip last (on top of everything)
    if hoveredCardInfo then
        UITooltip.drawCardTooltip(hoveredCardInfo, hoveredCardPos.x, hoveredCardPos.y, screenW, screenH, UITooltip.COMPACT_STYLE)
    end
end

drawMiniCard = function(card, x, y, selected, hovered)
    CardRenderer.drawMiniCard(card, x, y, layout.cardWidth, layout.cardHeight, {
        selected = selected,
        hovered = hovered,
        cornerRadius = 5,
        showAbility = true,
        abilityMaxChars = 8,
        abilityFontSize = 8,
        abilityBarHeight = 14,
    })
end

function DeckBuilder.mousepressed(x, y, button)
    if button ~= 1 then return end

    local screenW, screenH = love.graphics.getDimensions()

    -- Check UI button clicks
    if saveButton and saveButton:mousepressed(x, y, button) then return end
    if autoFillButton and autoFillButton:mousepressed(x, y, button) then return end
    if clearButton and clearButton:mousepressed(x, y, button) then return end

    -- Check filter button clicks
    for _, btn in ipairs(suitFilterButtons) do
        if btn:mousepressed(x, y, button) then return end
    end
    for _, btn in ipairs(rarityFilterButtons) do
        if btn:mousepressed(x, y, button) then return end
    end

    -- Check deck area clicks
    if x >= layout.deckAreaX and x <= layout.deckAreaX + layout.deckAreaWidth and
       y >= layout.deckAreaY and y <= layout.deckAreaY + layout.deckAreaHeight then
        local col = math.floor((x - layout.deckAreaX - 15) / layout.cardSpacing)
        local row = math.floor((y - layout.deckAreaY - 15 + deckScrollOffset) / (layout.cardHeight + 10))
        local index = row * 6 + col + 1

        if index >= 1 and index <= #currentDeck then
            -- Remove card from deck
            table.remove(currentDeck, index)
            showDeckMessage("Card removed from deck")
        end
        return
    end

    -- Check collection area clicks
    if x >= layout.collectionAreaX and x <= layout.collectionAreaX + layout.collectionAreaWidth and
       y >= layout.collectionAreaY and y <= layout.collectionAreaY + layout.collectionAreaHeight then
        local col = math.floor((x - layout.collectionAreaX - 15) / layout.cardSpacing)
        local row = math.floor((y - layout.collectionAreaY - 45 + collectionScrollOffset) / (layout.cardHeight + 10))
        local index = row * layout.cardsPerRow + col + 1

        local filteredCards = getFilteredCollection()
        if index >= 1 and index <= #filteredCards then
            local collCard = filteredCards[index]

            -- Check if already in deck
            local inDeck = false
            for _, dc in ipairs(currentDeck) do
                if dc.id == collCard.id then
                    inDeck = true
                    break
                end
            end

            if not inDeck then
                if #currentDeck >= 52 then
                    showDeckMessage("Deck is full (max 52 cards)")
                else
                    table.insert(currentDeck, collCard)
                    showDeckMessage("Card added to deck")
                end
            end
        end
        return
    end
end

function DeckBuilder.mousereleased(x, y, button)
    if button ~= 1 then return end

    -- Release UI buttons
    if saveButton and saveButton.mousereleased then
        saveButton:mousereleased(x, y, button)
    end
    if autoFillButton and autoFillButton.mousereleased then
        autoFillButton:mousereleased(x, y, button)
    end
    if clearButton and clearButton.mousereleased then
        clearButton:mousereleased(x, y, button)
    end

    -- Release filter buttons
    for _, btn in ipairs(suitFilterButtons) do
        if btn.mousereleased then
            btn:mousereleased(x, y, button)
        end
    end
    for _, btn in ipairs(rarityFilterButtons) do
        if btn.mousereleased then
            btn:mousereleased(x, y, button)
        end
    end
end

saveDeck = function()
    PlayerData.currentDeck = {}
    for _, card in ipairs(currentDeck) do
        table.insert(PlayerData.currentDeck, card)
    end
    savePlayerData()
    showDeckMessage("Deck saved!")
end

autoFillDeck = function()
    -- Add cards until we have 30
    for _, collCard in ipairs(PlayerData.collection) do
        if #currentDeck >= 30 then break end

        -- Check if already in deck
        local inDeck = false
        for _, dc in ipairs(currentDeck) do
            if dc.id == collCard.id then
                inDeck = true
                break
            end
        end

        if not inDeck then
            table.insert(currentDeck, collCard)
        end
    end

    showDeckMessage("Deck auto-filled to " .. #currentDeck .. " cards")
end

showDeckMessage = function(msg)
    message = msg
    messageTimer = 2
end

function DeckBuilder.getUIRegion(regionId)
    local screenW, screenH = love.graphics.getDimensions()
    local regions = {
        -- Deck area (left panel showing current deck)
        deck_area = {x = layout.deckAreaX, y = layout.deckAreaY, w = layout.deckAreaWidth, h = layout.deckAreaHeight},
        -- Deck info (deck count display)
        deck_info = {x = layout.deckAreaX, y = 55, w = 200, h = 20},
        -- Collection area (right panel showing available cards)
        card_pool = {x = layout.collectionAreaX, y = layout.collectionAreaY, w = layout.collectionAreaWidth, h = layout.collectionAreaHeight},
        -- Save button (bottom center-left)
        save_button = {x = screenW/2 - 140 - 80, y = screenH - 80, w = 140, h = 45},
        -- Auto-fill button (bottom center)
        autofill_button = {x = screenW/2 - 70, y = screenH - 80, w = 140, h = 45},
        -- Clear button (bottom center-right)
        clear_button = {x = screenW/2 + 80, y = screenH - 80, w = 140, h = 45},
        -- Filter area (suit and rarity filters)
        filter_area = {x = 600, y = 55, w = 300, h = 60},
    }
    return regions[regionId]
end

return DeckBuilder
