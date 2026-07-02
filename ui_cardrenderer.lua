-- Shared card rendering module
-- Extracts common mini-card drawing logic from deckbuilder.lua and collection.lua

local Cards = require("cards")
local UI = require("ui")

local CardRenderer = {}

--- Draw a mini card at the given position.
-- @param card         The card data table (rank, suit, rarity, ability, etc.)
-- @param x            X position
-- @param y            Y position
-- @param width        Card width in pixels
-- @param height       Card height in pixels
-- @param options      Optional table with rendering flags:
--   selected          (bool) Whether the card is selected (gold border)
--   hovered           (bool) Whether the card is hovered
--   hoverColor        (table) Override hover border color {r,g,b} (default: bright yellow)
--   hoverLineWidth    (number) Override hover border line width (default: 3)
--   cornerRadius      (number) Corner radius (default: 5)
--   showRarityDot     (bool) Show rarity color dot in top-right corner
--   showAbility       (bool) Show ability name indicator at bottom (default: true)
--   abilityCentered   (bool) Center the ability text (default: false, left-aligned)
--   abilityMaxChars   (number) Max chars for ability name (default: 8 for left-aligned, nil for centered)
--   abilityBarHeight  (number) Height of the ability indicator bar (default: 14)
--   fallbackFontRank  (number) Font size for rank+symbol in fallback mode (default: 16)
--   fallbackFontCenter (number) Font size for center symbol in fallback mode (default: 24)
--   fallbackRankOffsetX (number) X offset for rank text (default: 5)
--   fallbackRankOffsetY (number) Y offset for rank text (default: 5)
function CardRenderer.drawMiniCard(card, x, y, width, height, options)
    options = options or {}
    local selected = options.selected or false
    local hovered = options.hovered or false
    local cornerRadius = options.cornerRadius or 5
    local showAbility = options.showAbility
    if showAbility == nil then showAbility = true end

    local rarity = Cards.rarities[card.rarity] or Cards.rarities.common

    -- Try to load card image
    local cardImage = Cards.getCardImage(card)

    if cardImage then
        -- Draw card image
        love.graphics.setColor(1, 1, 1)
        local imgW = cardImage:getWidth()
        local imgH = cardImage:getHeight()
        local scaleX = width / imgW
        local scaleY = height / imgH
        local scale = math.min(scaleX, scaleY)
        love.graphics.draw(cardImage, x, y, 0, scale, scale)
    else
        -- Fallback to text rendering
        love.graphics.setColor(0.95, 0.95, 0.9)
        love.graphics.rectangle("fill", x, y, width, height, cornerRadius, cornerRadius)

        local suitColor = Cards.suitColors[card.suit] or {0.5, 0.3, 0.8}
        love.graphics.setColor(suitColor)

        local rankFontSize = options.fallbackFontRank or 16
        local centerFontSize = options.fallbackFontCenter or 24
        local rankOffX = options.fallbackRankOffsetX or 5
        local rankOffY = options.fallbackRankOffsetY or 5

        love.graphics.setFont(UI.fonts.get(rankFontSize))
        local symbol = Cards.suitSymbols[card.suit] or "★"
        love.graphics.print(card.rank .. symbol, x + rankOffX, y + rankOffY)

        -- Center symbol
        love.graphics.setFont(UI.fonts.get(centerFontSize))
        love.graphics.print(symbol, x + width/2 - 12, y + height/2 - 20)
    end

    -- Border (selection/hover/rarity)
    if selected then
        love.graphics.setColor(0.9, 0.8, 0.2)
        love.graphics.setLineWidth(3)
    elseif hovered then
        local hoverColor = options.hoverColor or {1, 0.9, 0.3}
        local hoverLW = options.hoverLineWidth or 3
        love.graphics.setColor(hoverColor)
        love.graphics.setLineWidth(hoverLW)
    else
        love.graphics.setColor(rarity.color)
        love.graphics.setLineWidth(2)
    end
    love.graphics.rectangle("line", x, y, width, height, cornerRadius, cornerRadius)
    love.graphics.setLineWidth(1)

    -- Ability indicator
    if showAbility and card.ability and card.ability ~= "none" then
        local abilityDef = Cards.abilities and Cards.abilities[card.ability]
        local abilityName = abilityDef and abilityDef.name or card.ability

        local barH = options.abilityBarHeight or 14
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", x, y + height - barH, width, barH, 0, 0, cornerRadius, cornerRadius)
        love.graphics.setColor(0.9, 0.7, 0.2)

        local centered = options.abilityCentered or false
        if centered then
            local abFontSize = options.abilityFontSize or 10
            love.graphics.setFont(UI.fonts.get(abFontSize))
            local abilityW = love.graphics.getFont():getWidth(abilityName)
            love.graphics.print(abilityName, x + width/2 - abilityW/2, y + height - barH + 3)
        else
            local abFontSize = options.abilityFontSize or 8
            love.graphics.setFont(UI.fonts.get(abFontSize))
            local maxChars = options.abilityMaxChars or 8
            love.graphics.print(abilityName:sub(1, maxChars), x + 3, y + height - barH + 2)
        end
    end

    -- Rarity dot (optional, used by collection)
    if options.showRarityDot then
        love.graphics.setColor(rarity.color)
        love.graphics.circle("fill", x + width - 10, y + 10, 5)
    end
end

--- Draw a card back (unrevealed card).
-- @param x       X position
-- @param y       Y position
-- @param width   Card width
-- @param height  Card height
-- @param options Optional table:
--   accentColor   (table) Color for border and question mark (default: gold-ish)
--   cornerRadius  (number) Corner radius (default: 8)
function CardRenderer.drawCardBack(x, y, width, height, options)
    options = options or {}
    local accent = options.accentColor or {0.85, 0.7, 0.3}
    local cornerRadius = options.cornerRadius or 8

    -- Background
    love.graphics.setColor(0.15, 0.2, 0.35)
    love.graphics.rectangle("fill", x, y, width, height, cornerRadius, cornerRadius)

    -- Border
    love.graphics.setColor(accent)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, width, height, cornerRadius, cornerRadius)
    love.graphics.setLineWidth(1)

    -- Inner pattern
    love.graphics.setColor(0.25, 0.3, 0.45)
    love.graphics.rectangle("fill", x + 10, y + 10, width - 20, height - 20, 5, 5)

    -- Question mark
    love.graphics.setColor(accent)
    love.graphics.setFont(UI.fonts.get(40))
    love.graphics.print("?", x + width/2 - 12, y + 45)
end

return CardRenderer
