-- Shared card tooltip drawing module
-- Used by deckbuilder.lua and collection.lua to avoid code duplication

local Cards = require("cards")
local UI = require("ui")

local UITooltip = {}

-- Default style options (collection.lua style - the more detailed variant)
local DEFAULT_OPTS = {
    tooltipW = 220,
    tooltipH = 160,
    padding = 10,
    cornerRadius = 10,
    shadowOffset = 4,
    cardWidth = 90,            -- layout.cardWidth used for positioning
    nameFontSize = 14,
    suitFontSize = 18,
    statsFontSize = 12,
    abilityDescFontSize = 10,
    viralFontSize = 10,
    suitSymbolOffsetX = 25,
    dividerY = 34,
    statsStartY = 42,
    lineSpacing = 18,
    bonusChipsFormat = " (+%d bonus)",
    bonusChipsOffsetX = 80,
    viralSuffix = " (Viral)",
    viralBottomOffset = 20,
    showHeaderBg = true,
    wordWrapAbility = true,
    abilityDescTruncate = nil,  -- nil means no truncation (use word-wrap instead)
}

-- Compact style options (deckbuilder.lua style)
UITooltip.COMPACT_STYLE = {
    tooltipW = 200,
    tooltipH = 140,
    padding = 8,
    cornerRadius = 8,
    shadowOffset = 3,
    cardWidth = 70,
    nameFontSize = 13,
    suitFontSize = 16,
    statsFontSize = 11,
    abilityDescFontSize = 9,
    viralFontSize = 9,
    suitSymbolOffsetX = 22,
    dividerY = 26,
    statsStartY = 32,
    lineSpacing = 16,
    bonusChipsFormat = " (+%d)",
    bonusChipsOffsetX = 70,
    viralSuffix = "",
    viralBottomOffset = 16,
    showHeaderBg = false,
    wordWrapAbility = false,
    abilityDescTruncate = 30,
}

-- Detailed style options (collection.lua style)
UITooltip.DETAILED_STYLE = {
    tooltipW = 220,
    tooltipH = 160,
    padding = 10,
    cornerRadius = 10,
    shadowOffset = 4,
    cardWidth = 90,
    nameFontSize = 14,
    suitFontSize = 18,
    statsFontSize = 12,
    abilityDescFontSize = 10,
    viralFontSize = 10,
    suitSymbolOffsetX = 25,
    dividerY = 34,
    statsStartY = 42,
    lineSpacing = 18,
    bonusChipsFormat = " (+%d bonus)",
    bonusChipsOffsetX = 80,
    viralSuffix = " (Viral)",
    viralBottomOffset = 20,
    showHeaderBg = true,
    wordWrapAbility = true,
    abilityDescTruncate = nil,
}

--- Draw a card tooltip with configurable style.
-- @param card       The card data table
-- @param cardX      X position of the card being hovered
-- @param cardY      Y position of the card being hovered
-- @param screenW    Screen width
-- @param screenH    Screen height
-- @param opts       Optional style overrides table (defaults to DETAILED_STYLE)
function UITooltip.drawCardTooltip(card, cardX, cardY, screenW, screenH, opts)
    opts = opts or DEFAULT_OPTS

    local tooltipW = opts.tooltipW or DEFAULT_OPTS.tooltipW
    local tooltipH = opts.tooltipH or DEFAULT_OPTS.tooltipH
    local padding = opts.padding or DEFAULT_OPTS.padding
    local cornerRadius = opts.cornerRadius or DEFAULT_OPTS.cornerRadius
    local shadowOffset = opts.shadowOffset or DEFAULT_OPTS.shadowOffset
    local cardWidth = opts.cardWidth or DEFAULT_OPTS.cardWidth

    -- Position tooltip to the right of the card, or left if not enough space
    local tooltipX = cardX + cardWidth + 10
    local tooltipY = cardY

    -- Adjust if tooltip would go off-screen
    if tooltipX + tooltipW > screenW - 10 then
        tooltipX = cardX - tooltipW - 10
    end
    if tooltipY + tooltipH > screenH - 10 then
        tooltipY = screenH - tooltipH - 10
    end
    if tooltipY < 10 then
        tooltipY = 10
    end

    -- Get rarity info
    local rarity = Cards.rarities[card.rarity] or Cards.rarities.common
    local rarityColor = rarity.color

    -- Background with shadow
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", tooltipX + shadowOffset, tooltipY + shadowOffset, tooltipW, tooltipH, cornerRadius, cornerRadius)

    -- Main background
    love.graphics.setColor(0.1, 0.1, 0.15, 0.98)
    love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipW, tooltipH, cornerRadius, cornerRadius)

    -- Border with rarity color
    love.graphics.setColor(rarityColor)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", tooltipX, tooltipY, tooltipW, tooltipH, cornerRadius, cornerRadius)
    love.graphics.setLineWidth(1)

    -- Optional header background (collection style)
    if opts.showHeaderBg then
        love.graphics.setColor(rarityColor[1] * 0.3, rarityColor[2] * 0.3, rarityColor[3] * 0.3, 0.8)
        love.graphics.rectangle("fill", tooltipX + 2, tooltipY + 2, tooltipW - 4, 28, 8, 8, 0, 0)
    end

    -- Card name (rank + suit)
    local suitSymbol = Cards.suitSymbols[card.suit] or "?"
    local suitColor = Cards.suitColors[card.suit] or {0.5, 0.5, 0.5}
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(opts.nameFontSize or DEFAULT_OPTS.nameFontSize))
    local cardName = card.rank .. " of " .. (card.suit and card.suit:sub(1,1):upper() .. card.suit:sub(2) or "?")
    love.graphics.print(cardName, tooltipX + padding, tooltipY + 6)

    -- Suit symbol
    love.graphics.setColor(suitColor)
    love.graphics.setFont(UI.fonts.get(opts.suitFontSize or DEFAULT_OPTS.suitFontSize))
    love.graphics.print(suitSymbol, tooltipX + tooltipW - (opts.suitSymbolOffsetX or DEFAULT_OPTS.suitSymbolOffsetX), tooltipY + 4)

    -- Divider line
    local dividerY = opts.dividerY or DEFAULT_OPTS.dividerY
    love.graphics.setColor(0.3, 0.3, 0.4)
    love.graphics.line(tooltipX + padding, tooltipY + dividerY, tooltipX + tooltipW - padding, tooltipY + dividerY)

    -- Stats section
    local lineSpacing = opts.lineSpacing or DEFAULT_OPTS.lineSpacing
    local yPos = tooltipY + (opts.statsStartY or DEFAULT_OPTS.statsStartY)
    love.graphics.setFont(UI.fonts.get(opts.statsFontSize or DEFAULT_OPTS.statsFontSize))

    -- Chips
    love.graphics.setColor(0.3, 0.6, 1)
    local baseChips = Cards.rankValues[card.rank] or 0
    local bonusChips = card.chips or 0
    love.graphics.print(string.format("Chips: %d", baseChips + bonusChips), tooltipX + padding, yPos)
    if bonusChips > 0 then
        love.graphics.setColor(0.3, 0.9, 0.3)
        local fmt = opts.bonusChipsFormat or DEFAULT_OPTS.bonusChipsFormat
        local offsetX = opts.bonusChipsOffsetX or DEFAULT_OPTS.bonusChipsOffsetX
        love.graphics.print(string.format(fmt, bonusChips), tooltipX + offsetX, yPos)
    end
    yPos = yPos + lineSpacing

    -- Mult
    if card.mult and card.mult > 0 then
        love.graphics.setColor(1, 0.5, 0.3)
        love.graphics.print(string.format("Mult: +%d", card.mult), tooltipX + padding, yPos)
        yPos = yPos + lineSpacing
    end

    -- Rarity
    love.graphics.setColor(rarityColor)
    local rarityName = card.rarity and (card.rarity:sub(1,1):upper() .. card.rarity:sub(2)) or "Common"
    love.graphics.print("Rarity: " .. rarityName, tooltipX + padding, yPos)
    yPos = yPos + lineSpacing

    -- Ability
    local abilityDescFontSize = opts.abilityDescFontSize or DEFAULT_OPTS.abilityDescFontSize
    local wordWrap = opts.wordWrapAbility
    if wordWrap == nil then wordWrap = DEFAULT_OPTS.wordWrapAbility end
    local truncateLen = opts.abilityDescTruncate or DEFAULT_OPTS.abilityDescTruncate

    if card.ability and card.ability ~= "none" then
        local abilityInfo = Cards.abilities and Cards.abilities[card.ability]
        if abilityInfo then
            love.graphics.setColor(0.9, 0.7, 0.2)
            love.graphics.print("Ability: " .. abilityInfo.name, tooltipX + padding, yPos)
            yPos = yPos + 16

            -- Ability description
            local descColor = wordWrap and {0.8, 0.8, 0.7} or {0.7, 0.7, 0.6}
            love.graphics.setColor(descColor)
            love.graphics.setFont(UI.fonts.get(abilityDescFontSize))
            local desc = abilityInfo.description or ""

            if wordWrap then
                -- Word-wrap mode (collection style)
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
            else
                -- Truncation mode (deckbuilder style)
                if truncateLen and #desc > truncateLen then
                    desc = desc:sub(1, truncateLen - 1) .. ".."
                end
                love.graphics.print(desc, tooltipX + padding, yPos)
            end
        end
    end

    -- Viral effect indicator
    local viralFontSize = opts.viralFontSize or DEFAULT_OPTS.viralFontSize
    local viralSuffix = opts.viralSuffix or DEFAULT_OPTS.viralSuffix
    local viralBottomOffset = opts.viralBottomOffset or DEFAULT_OPTS.viralBottomOffset

    if card.viralEffect then
        local viralEffects = Cards.viralEffects
        if viralEffects then
            local viral = viralEffects[card.viralEffect]
            if viral then
                love.graphics.setColor(0.9, 0.4, 0.9)
                love.graphics.setFont(UI.fonts.get(viralFontSize))
                love.graphics.print(viral.symbol .. " " .. viral.name .. viralSuffix, tooltipX + padding, tooltipY + tooltipH - viralBottomOffset)
            end
        end
    end
end

return UITooltip
