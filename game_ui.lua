-- game_ui.lua
-- All rendering/drawing functions for the poker card game
-- Receives game state as parameters - no global state access

local GameUI = {}

local Cards = require("cards")
local PokerHands = require("poker_hands")
local FontCache = require("fontcache")

local function getFont(size)
    return FontCache.get(size)
end

-- Visual effects time tracker for holographic effects
local effectTime = 0

-- Score popup animation system
local scorePopups = {}

-- HSL to RGB for rainbow effects
local function hslToRgb(h, s, l)
    local r, g, b
    if s == 0 then
        r, g, b = l, l, l
    else
        local function hue2rgb(p, q, t)
            if t < 0 then t = t + 1 end
            if t > 1 then t = t - 1 end
            if t < 1/6 then return p + (q - p) * 6 * t end
            if t < 1/2 then return q end
            if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
            return p
        end
        local q = l < 0.5 and l * (1 + s) or l + s - l * s
        local p = 2 * l - q
        r = hue2rgb(p, q, h + 1/3)
        g = hue2rgb(p, q, h)
        b = hue2rgb(p, q, h - 1/3)
    end
    return {r, g, b}
end

-- Update the internal effect timer
function GameUI.updateEffectTime(dt)
    effectTime = effectTime + dt
end

-- Get the current effect time (for external use if needed)
function GameUI.getEffectTime()
    return effectTime
end

-- Draw holographic shimmer on gameplay cards
function GameUI.drawHolographicEffect(x, y, w, h, intensity)
    intensity = intensity or 1
    local mx, my = love.mouse.getPosition()
    local cardCenterX = x + w / 2
    local cardCenterY = y + h / 2
    local dx = (mx - cardCenterX) / 200
    local dy = (my - cardCenterY) / 200

    -- Rainbow gradient based on mouse position and time
    local hue1 = (effectTime * 0.3 + dx * 0.5) % 1
    local color1 = hslToRgb(hue1, 0.7, 0.6)

    -- Diagonal shimmer band
    local bandWidth = w * 0.4
    local bandX = x + (effectTime * 100 + dx * 10) % (w + bandWidth * 2) - bandWidth
    local alpha = 0.2 * intensity

    love.graphics.setColor(color1[1], color1[2], color1[3], alpha)
    love.graphics.polygon("fill",
        bandX, y,
        bandX + bandWidth, y,
        bandX + bandWidth * 0.7, y + h,
        bandX - bandWidth * 0.3, y + h
    )

    -- Edge highlight
    local edgeAlpha = 0.2 * intensity * math.abs(dx)
    love.graphics.setColor(1, 1, 1, edgeAlpha)
    love.graphics.setLineWidth(2)
    if dx > 0 then
        love.graphics.line(x + w - 1, y + 2, x + w - 1, y + h - 2)
    else
        love.graphics.line(x + 1, y + 2, x + 1, y + h - 2)
    end
    love.graphics.setLineWidth(1)
end

-- Draw fusion glow on gameplay cards
function GameUI.drawFusionGlow(x, y, w, h, fusionCount)
    local glowColors = {
        {0.6, 0.4, 1},    -- Level 1: Purple
        {0.4, 0.8, 1},    -- Level 2: Cyan
        {1, 0.8, 0.4},    -- Level 3: Gold
    }
    local glowColor = glowColors[fusionCount] or glowColors[3]

    -- Pulsing glow
    local pulse = 0.5 + 0.5 * math.sin(effectTime * 3 + x * 0.01)
    love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], 0.35 * pulse)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x - 2, y - 2, w + 4, h + 4, 10, 10)
    love.graphics.setLineWidth(1)

    -- Fusion stars
    love.graphics.setColor(1, 0.9, 0.5, 0.9)
    love.graphics.setFont(getFont(10))
    local stars = string.rep("\226\152\133", fusionCount)
    love.graphics.print(stars, x + 3, y + h - 14)
end

-- Draw a single card
-- layout: {cardWidth, cardHeight}
function GameUI.drawCard(card, x, y, layout, faceUp, hovered)
    if faceUp == false then
        -- Card back
        love.graphics.setColor(0.2, 0.2, 0.6)
        love.graphics.rectangle("fill", x, y, layout.cardWidth, layout.cardHeight, 8, 8)
        love.graphics.setColor(0.3, 0.3, 0.7)
        love.graphics.rectangle("line", x, y, layout.cardWidth, layout.cardHeight, 8, 8)
        return
    end

    -- Try to load and draw card image
    local cardImage = Cards.getCardImage(card)

    if cardImage then
        -- Draw card image scaled to card size
        love.graphics.setColor(1, 1, 1)
        local imgW = cardImage:getWidth()
        local imgH = cardImage:getHeight()
        local scaleX = layout.cardWidth / imgW
        local scaleY = layout.cardHeight / imgH
        local scale = math.min(scaleX, scaleY)
        love.graphics.draw(cardImage, x, y, 0, scale, scale)

        -- Hover glow effect
        if hovered then
            love.graphics.setColor(1, 0.9, 0.3, 0.4)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", x - 2, y - 2, layout.cardWidth + 4, layout.cardHeight + 4, 10, 10)
            love.graphics.setLineWidth(1)
        end
    else
        -- Fallback: Card background based on rarity
        local rarity = Cards.rarities[card.rarity] or Cards.rarities.common
        love.graphics.setColor(0.95, 0.95, 0.9)
        love.graphics.rectangle("fill", x, y, layout.cardWidth, layout.cardHeight, 8, 8)

        -- Rarity border (or hover border)
        if hovered then
            love.graphics.setColor(1, 0.9, 0.3)
            love.graphics.setLineWidth(4)
        else
            love.graphics.setColor(rarity.color)
            love.graphics.setLineWidth(3)
        end
        love.graphics.rectangle("line", x, y, layout.cardWidth, layout.cardHeight, 8, 8)
        love.graphics.setLineWidth(1)

        -- Suit color
        local suitColor = Cards.suitColors[card.suit] or {0.5, 0.3, 0.8}
        love.graphics.setColor(suitColor)

        -- Rank and suit
        love.graphics.setFont(getFont(20))
        local symbol = Cards.suitSymbols[card.suit] or "?"
        love.graphics.print(card.rank, x + 8, y + 5)
        love.graphics.print(symbol, x + 8, y + 25)

        -- Center symbol
        love.graphics.setFont(getFont(32))
        local centerX = x + layout.cardWidth/2 - 12
        local centerY = y + layout.cardHeight/2 - 16
        love.graphics.print(symbol, centerX, centerY)

        -- Ability indicator
        if card.ability and card.ability ~= "none" then
            love.graphics.setColor(0.9, 0.7, 0.2)
            love.graphics.setFont(getFont(10))
            local abilityInfo = Cards.abilities and Cards.abilities[card.ability]
            local abilityName = abilityInfo and abilityInfo.name or card.ability
            local abilityW = love.graphics.getFont():getWidth(abilityName)
            love.graphics.print(abilityName, x + layout.cardWidth/2 - abilityW/2, y + layout.cardHeight - 18)
        end

        -- Chips value
        love.graphics.setColor(0.2, 0.5, 0.8)
        love.graphics.setFont(getFont(12))
        love.graphics.print("+" .. card.chips, x + layout.cardWidth - 25, y + 5)
    end

    -- Rarity border (over image)
    local rarity = Cards.rarities[card.rarity] or Cards.rarities.common
    love.graphics.setColor(rarity.color)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, layout.cardWidth, layout.cardHeight, 8, 8)
    love.graphics.setLineWidth(1)

    -- HOLOGRAPHIC EFFECTS FOR FUSED CARDS
    local fusionCount = card.fusionCount or 0
    if fusionCount > 0 then
        -- Clip to card bounds for shimmer effect
        love.graphics.setScissor(x, y, layout.cardWidth, layout.cardHeight)

        -- Holographic shimmer - intensity scales with fusion count
        local holoIntensity = math.min(fusionCount / 3, 1)
        GameUI.drawHolographicEffect(x, y, layout.cardWidth, layout.cardHeight, holoIntensity)

        love.graphics.setScissor()

        -- Fusion glow effect
        GameUI.drawFusionGlow(x, y, layout.cardWidth, layout.cardHeight, fusionCount)
    end

    -- Mutation effects
    if card.mutation then
        love.graphics.setScissor(x, y, layout.cardWidth, layout.cardHeight)
        -- Simple shimmer for mutations
        GameUI.drawHolographicEffect(x, y, layout.cardWidth, layout.cardHeight, 0.6)
        love.graphics.setScissor()

        -- Mutation badge
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", x + layout.cardWidth - 26, y + layout.cardHeight - 14, 24, 12, 2, 2)
        love.graphics.setColor(0.9, 0.7, 1)
        love.graphics.setFont(getFont(8))
        local mutLabel = card.mutation:sub(1, 4):upper()
        love.graphics.print(mutLabel, x + layout.cardWidth - 24, y + layout.cardHeight - 13)
    end
end

-- Draw game info panel (scores, round info, opponent portrait)
-- gs: gameState, layout: layout table, opponent: currentOpponent table
function GameUI.drawGameInfo(gs, layout, opponent, screenW, screenH)
    love.graphics.setFont(getFont(18))

    -- Draw opponent portrait (top center, 200% bigger - sitting across the table)
    local portraitSize = 240  -- 200% of 80 = 240
    local portraitX = screenW/2 - portraitSize/2
    local portraitY = 5

    if gs.opponentPortrait then
        love.graphics.setColor(1, 1, 1)
        local imgW, imgH = gs.opponentPortrait:getDimensions()
        local scale = portraitSize / math.max(imgW, imgH)
        love.graphics.draw(gs.opponentPortrait, portraitX, portraitY, 0, scale, scale)
    else
        -- Fallback colored silhouette (no box frame)
        love.graphics.setColor(opponent.color[1], opponent.color[2], opponent.color[3], 0.6)
        love.graphics.circle("fill", screenW/2, portraitY + portraitSize/2, portraitSize/2 - 10)
    end

    -- Opponent name to the right of portrait
    love.graphics.setFont(getFont(20))
    local oppName = opponent.name or "Opponent"
    local nameX = portraitX + portraitSize + 15
    local nameY = portraitY + portraitSize/2 - 12
    -- Add text shadow for readability
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.print(oppName, nameX + 2, nameY + 2)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(oppName, nameX, nameY)

    -- Round info with goal prominently displayed
    love.graphics.setFont(getFont(18))
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.print(string.format("Round %d", gs.round), 20, 20)

    -- Goal score (prominent)
    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(24))
    love.graphics.print(string.format("GOAL: %d", gs.targetScore), 20, 45)

    -- Player score with progress bar
    love.graphics.setFont(getFont(18))
    love.graphics.setColor(0.3, 0.8, 0.3)
    love.graphics.print(string.format("Score: %d / %d", gs.roundScores.player, gs.targetScore), 20, 80)

    -- Progress bar
    local progressW = 150
    local progressH = 8
    local progress = math.min(1, gs.roundScores.player / gs.targetScore)
    love.graphics.setColor(0.2, 0.2, 0.25)
    love.graphics.rectangle("fill", 20, 105, progressW, progressH, 4, 4)
    love.graphics.setColor(0.3, 0.8, 0.3)
    love.graphics.rectangle("fill", 20, 105, progressW * progress, progressH, 4, 4)

    -- Hands and discards left (moved 20% left from right edge)
    local rightInfoX = screenW - screenW * 0.22
    love.graphics.setColor(0.7, 0.7, 0.9)
    love.graphics.setFont(getFont(18))
    love.graphics.print(string.format("Hands: %d  |  Discards: %d", gs.handsLeft, gs.discardsLeft), rightInfoX, 20)

    -- Deck count
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.print(string.format("Deck: %d", #gs.playerDeck), rightInfoX, 50)

    -- Target score reminder (top right near opponent)
    love.graphics.setColor(0.9, 0.5, 0.3)
    love.graphics.setFont(getFont(16))
    love.graphics.print(string.format("Target: %d", gs.targetScore), rightInfoX, 80)

    -- Date and time display (top right corner)
    love.graphics.setColor(0.7, 0.7, 0.8, 0.8)
    love.graphics.setFont(getFont(12))
    local dateStr = os.date("%B %d, %Y")
    local timeStr = os.date("%I:%M %p")
    love.graphics.print(dateStr, screenW - 120, 5)
    love.graphics.print(timeStr, screenW - 80, 20)

    -- Draw equipped jokers
    GameUI.drawJokersDisplay(gs, screenW, screenH)

    -- Boss info
    if gs.currentBoss then
        love.graphics.setColor(0.9, 0.3, 0.3)
        love.graphics.setFont(getFont(18))
        love.graphics.print("BOSS: " .. gs.currentBoss.name, screenW/2 - 100, 20)
        love.graphics.setColor(0.9, 0.5, 0.3)
        love.graphics.setFont(getFont(14))
        love.graphics.print(gs.currentBoss.effect, screenW/2 - 100, 45)
    end
end

-- Draw equipped jokers display
function GameUI.drawJokersDisplay(gs, screenW, screenH)
    local jokers = gs.playerJokers
    if not jokers or #jokers == 0 then return end

    local jokerW, jokerH = 60, 80
    local spacing = 10
    local startX = screenW - 220
    local startY = 80
    local mx, my = love.mouse.getPosition()

    -- Reset hovered joker
    gs.hoveredJoker = nil

    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(12))
    love.graphics.print("Equipped Jokers:", startX, startY - 15)

    for i, joker in ipairs(jokers) do
        if i > 3 then break end  -- Only show first 3
        local x = startX + (i-1) * (jokerW + spacing)
        local y = startY

        -- Check hover
        local hovered = mx >= x and mx <= x + jokerW and my >= y and my <= y + jokerH
        if hovered then
            gs.hoveredJoker = joker
            gs.hoveredJokerPos = {x = x, y = y}
        end

        -- Joker card background
        love.graphics.setColor(0.25, 0.18, 0.35)
        love.graphics.rectangle("fill", x, y, jokerW, jokerH, 6, 6)

        -- Border based on rarity
        local rarityColors = {
            common = {0.7, 0.7, 0.7},
            uncommon = {0.3, 0.8, 0.3},
            rare = {0.3, 0.5, 1},
            epic = {0.8, 0.3, 0.8},
            legendary = {1, 0.8, 0.2}
        }
        local borderColor = rarityColors[joker.rarity or "common"] or rarityColors.common

        if hovered then
            love.graphics.setColor(1, 0.9, 0.3)
            love.graphics.setLineWidth(3)
        else
            love.graphics.setColor(borderColor)
            love.graphics.setLineWidth(2)
        end
        love.graphics.rectangle("line", x, y, jokerW, jokerH, 6, 6)
        love.graphics.setLineWidth(1)

        -- Joker emoji/icon at top
        love.graphics.setColor(1, 0.9, 0.4)
        love.graphics.setFont(getFont(18))
        love.graphics.print("J", x + jokerW/2 - 5, y + 3)

        -- Joker name (abbreviated) - centered
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(8))
        local name = joker.name or "Joker"
        if #name > 10 then name = name:sub(1, 9) .. "." end
        local nameW = love.graphics.getFont():getWidth(name)
        love.graphics.print(name, x + jokerW/2 - nameW/2, y + 28)

        -- Effect type indicator
        local effectText = ""
        if joker.chipBonus then effectText = "+" .. joker.chipBonus .. "c"
        elseif joker.multBonus then effectText = "+" .. joker.multBonus .. "m"
        elseif joker.multMult then effectText = "x" .. joker.multMult
        end
        if effectText ~= "" then
            love.graphics.setColor(0.4, 0.9, 0.4)
            love.graphics.setFont(getFont(10))
            local effectW = love.graphics.getFont():getWidth(effectText)
            love.graphics.print(effectText, x + jokerW/2 - effectW/2, y + 42)
        end

        -- Condition hint
        love.graphics.setColor(0.6, 0.6, 0.7)
        love.graphics.setFont(getFont(7))
        local hint = ""
        if joker.condition then
            if joker.condition == "hearts" then hint = "\226\153\165"
            elseif joker.condition == "diamonds" then hint = "\226\153\166"
            elseif joker.condition == "clubs" then hint = "\226\153\163"
            elseif joker.condition == "spades" then hint = "\226\153\160"
            elseif joker.condition == "face" then hint = "Face"
            elseif joker.condition == "even" then hint = "Even"
            elseif joker.condition == "odd" then hint = "Odd"
            else hint = joker.condition:sub(1, 5)
            end
        end
        if hint ~= "" then
            local hintW = love.graphics.getFont():getWidth(hint)
            love.graphics.print(hint, x + jokerW/2 - hintW/2, y + 58)
        end

        -- Rarity dot indicator
        love.graphics.setColor(borderColor)
        love.graphics.circle("fill", x + jokerW - 8, y + jokerH - 8, 4)
    end
end

-- Draw joker tooltip for game screen
function GameUI.drawJokerTooltip(joker, cardX, cardY, screenW, screenH)
    local tooltipW = 220
    local tooltipH = 120
    local padding = 10

    -- Position tooltip below the card
    local tooltipX = cardX - 80
    local tooltipY = cardY + 90

    -- Adjust if tooltip would go off-screen
    if tooltipX + tooltipW > screenW - 10 then
        tooltipX = screenW - tooltipW - 10
    end
    if tooltipX < 10 then
        tooltipX = 10
    end
    if tooltipY + tooltipH > screenH - 10 then
        tooltipY = cardY - tooltipH - 10
    end

    -- Get rarity color
    local rarityColors = {
        common = {0.7, 0.7, 0.7},
        uncommon = {0.3, 0.8, 0.3},
        rare = {0.3, 0.5, 1},
        epic = {0.8, 0.3, 0.8},
        legendary = {1, 0.8, 0.2}
    }
    local rarityColor = rarityColors[joker.rarity or "common"] or rarityColors.common

    -- Background with shadow
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", tooltipX + 3, tooltipY + 3, tooltipW, tooltipH, 8, 8)

    -- Main background
    love.graphics.setColor(0.1, 0.1, 0.15, 0.98)
    love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipW, tooltipH, 8, 8)

    -- Border with rarity color
    love.graphics.setColor(rarityColor)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", tooltipX, tooltipY, tooltipW, tooltipH, 8, 8)
    love.graphics.setLineWidth(1)

    -- Joker name
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(13))
    love.graphics.print(joker.name or "Joker", tooltipX + padding, tooltipY + 8)

    -- Rarity
    love.graphics.setColor(rarityColor)
    love.graphics.setFont(getFont(10))
    local rarityText = (joker.rarity or "common"):sub(1, 1):upper() .. (joker.rarity or "common"):sub(2)
    local rarityW = love.graphics.getFont():getWidth(rarityText)
    love.graphics.print(rarityText, tooltipX + tooltipW - rarityW - padding, tooltipY + 10)

    -- Divider
    love.graphics.setColor(0.3, 0.3, 0.4)
    love.graphics.line(tooltipX + padding, tooltipY + 28, tooltipX + tooltipW - padding, tooltipY + 28)

    -- Full description with word wrap
    love.graphics.setColor(0.95, 0.9, 0.8)
    love.graphics.setFont(getFont(11))
    local desc = joker.description or ""
    local descFont = love.graphics.getFont()
    local maxTextW = tooltipW - padding * 2
    local lineHeight = 14
    local yPos = tooltipY + 34

    -- Word wrap
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
    end
end

-- Draw card tooltip for game screen
function GameUI.drawCardTooltip(card, cardX, cardY, layout, screenW, screenH)
    local tooltipW = 200
    local tooltipH = 130
    local padding = 8

    -- Position tooltip above the card
    local tooltipX = cardX - 50
    local tooltipY = cardY - tooltipH - 15

    -- Adjust if tooltip would go off-screen
    if tooltipX + tooltipW > screenW - 10 then
        tooltipX = screenW - tooltipW - 10
    end
    if tooltipX < 10 then
        tooltipX = 10
    end
    if tooltipY < 10 then
        tooltipY = cardY + layout.cardHeight + 10
    end

    -- Get rarity info
    local rarity = Cards.rarities[card.rarity] or Cards.rarities.common
    local rarityColor = rarity.color

    -- Background with shadow
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", tooltipX + 3, tooltipY + 3, tooltipW, tooltipH, 8, 8)

    -- Main background
    love.graphics.setColor(0.1, 0.1, 0.15, 0.98)
    love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipW, tooltipH, 8, 8)

    -- Border with rarity color
    love.graphics.setColor(rarityColor)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", tooltipX, tooltipY, tooltipW, tooltipH, 8, 8)
    love.graphics.setLineWidth(1)

    -- Card name
    local suitSymbol = Cards.suitSymbols[card.suit] or "?"
    local suitColor = Cards.suitColors[card.suit] or {0.5, 0.5, 0.5}
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(13))
    local cardName = card.rank .. " of " .. (card.suit and card.suit:sub(1,1):upper() .. card.suit:sub(2) or "?")
    love.graphics.print(cardName, tooltipX + padding, tooltipY + 6)

    -- Suit symbol
    love.graphics.setColor(suitColor)
    love.graphics.setFont(getFont(16))
    love.graphics.print(suitSymbol, tooltipX + tooltipW - 22, tooltipY + 4)

    -- Divider
    love.graphics.setColor(0.3, 0.3, 0.4)
    love.graphics.line(tooltipX + padding, tooltipY + 26, tooltipX + tooltipW - padding, tooltipY + 26)

    -- Stats
    local yPos = tooltipY + 32
    love.graphics.setFont(getFont(11))

    -- Chips
    love.graphics.setColor(0.3, 0.6, 1)
    local baseChips = Cards.rankValues[card.rank] or 0
    local bonusChips = card.chips or 0
    love.graphics.print(string.format("Chips: %d", baseChips + bonusChips), tooltipX + padding, yPos)
    if bonusChips > 0 then
        love.graphics.setColor(0.3, 0.9, 0.3)
        love.graphics.print(string.format(" (+%d)", bonusChips), tooltipX + 70, yPos)
    end
    yPos = yPos + 16

    -- Mult
    if card.mult and card.mult > 0 then
        love.graphics.setColor(1, 0.5, 0.3)
        love.graphics.print(string.format("Mult: +%d", card.mult), tooltipX + padding, yPos)
        yPos = yPos + 16
    end

    -- Rarity
    love.graphics.setColor(rarityColor)
    local rarityName = card.rarity and (card.rarity:sub(1,1):upper() .. card.rarity:sub(2)) or "Common"
    love.graphics.print("Rarity: " .. rarityName, tooltipX + padding, yPos)
    yPos = yPos + 16

    -- Ability
    if card.ability and card.ability ~= "none" then
        local abilityInfo = Cards.abilities and Cards.abilities[card.ability]
        if abilityInfo then
            love.graphics.setColor(0.9, 0.7, 0.2)
            love.graphics.print("Ability: " .. abilityInfo.name, tooltipX + padding, yPos)
            yPos = yPos + 14
            love.graphics.setColor(0.7, 0.7, 0.6)
            love.graphics.setFont(getFont(9))
            local desc = abilityInfo.description or ""
            if #desc > 30 then desc = desc:sub(1, 29) .. ".." end
            love.graphics.print(desc, tooltipX + padding, yPos)
        end
    end

    -- Viral effect
    if card.viralEffect and Cards.viralEffects then
        local viral = Cards.viralEffects[card.viralEffect]
        if viral then
            love.graphics.setColor(0.9, 0.4, 0.9)
            love.graphics.setFont(getFont(9))
            love.graphics.print(viral.symbol .. " " .. viral.name, tooltipX + padding, tooltipY + tooltipH - 16)
        end
    end
end

-- Draw opponent area (currently empty/unused)
function GameUI.drawOpponentArea(screenW)
    -- Don't draw opponent area - the purist ladder already shows progression
end

-- Draw purist mode progress ladder
-- puristData: {isPuristMode, puristOpponent, puristLadder, puristTiers}
function GameUI.drawPuristLadder(gs, puristLadder, puristTiers, screenW, screenH)
    if not gs.isPuristMode then return end

    local ladderX = screenW - 180
    local ladderY = 130
    local ladderW = 160
    local entryH = 22
    local visibleCount = 7  -- Show 7 opponents at a time (centered on current)

    -- Calculate which opponents to show (centered on current)
    local startIdx = math.max(1, gs.puristOpponent - 3)
    local endIdx = math.min(#puristLadder, startIdx + visibleCount - 1)
    if endIdx - startIdx < visibleCount - 1 then
        startIdx = math.max(1, endIdx - visibleCount + 1)
    end

    local ladderH = (endIdx - startIdx + 1) * entryH + 45

    -- Background
    love.graphics.setColor(0.08, 0.08, 0.12, 0.9)
    love.graphics.rectangle("fill", ladderX, ladderY, ladderW, ladderH, 8, 8)
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.rectangle("line", ladderX, ladderY, ladderW, ladderH, 8, 8)

    -- Title
    love.graphics.setColor(0.9, 0.8, 0.3)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("LADDER", ladderX, ladderY + 5, ladderW, "center")

    -- Progress indicator
    love.graphics.setColor(0.6, 0.7, 0.6)
    love.graphics.setFont(getFont(10))
    love.graphics.printf(string.format("%d/15", gs.puristOpponent), ladderX, ladderY + 20, ladderW, "center")

    -- Draw opponent entries
    local y = ladderY + 38
    for i = endIdx, startIdx, -1 do  -- Draw bottom to top (15 at top)
        local opp = puristLadder[i]
        local isCurrent = i == gs.puristOpponent
        local isDefeated = i < gs.puristOpponent

        -- Entry background
        if isCurrent then
            love.graphics.setColor(opp.color[1] * 0.5, opp.color[2] * 0.5, opp.color[3] * 0.5)
            love.graphics.rectangle("fill", ladderX + 5, y, ladderW - 10, entryH - 2, 3, 3)
            love.graphics.setColor(opp.color)
            love.graphics.rectangle("line", ladderX + 5, y, ladderW - 10, entryH - 2, 3, 3)
        elseif isDefeated then
            love.graphics.setColor(0.15, 0.2, 0.15)
            love.graphics.rectangle("fill", ladderX + 5, y, ladderW - 10, entryH - 2, 3, 3)
        end

        -- Number
        love.graphics.setFont(getFont(10))
        if isDefeated then
            love.graphics.setColor(0.3, 0.6, 0.3)
            love.graphics.print("\226\156\147", ladderX + 10, y + 4)
        else
            love.graphics.setColor(isCurrent and {1, 1, 1} or {0.5, 0.5, 0.5})
            love.graphics.print(string.format("%d", i), ladderX + 10, y + 4)
        end

        -- Name
        love.graphics.setColor(isCurrent and opp.color or (isDefeated and {0.4, 0.5, 0.4} or {0.5, 0.5, 0.5}))
        love.graphics.print(opp.name, ladderX + 28, y + 4)

        y = y + entryH
    end

    -- Show "..." if there are more above or below
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.setFont(getFont(10))
    if startIdx > 1 then
        love.graphics.printf("...", ladderX, ladderY + ladderH - 15, ladderW, "center")
    end
end

-- Add a score popup
function GameUI.addScorePopup(text, x, y, color)
    table.insert(scorePopups, {
        text = text,
        x = x,
        y = y,
        color = color or {1, 1, 0},
        alpha = 1,
        timer = 2,
        vy = -50  -- velocity upward
    })
end

-- Update score popups
function GameUI.updateScorePopups(dt)
    for i = #scorePopups, 1, -1 do
        local popup = scorePopups[i]
        popup.timer = popup.timer - dt
        popup.y = popup.y + popup.vy * dt
        popup.alpha = popup.timer / 2

        if popup.timer <= 0 then
            table.remove(scorePopups, i)
        end
    end
end

-- Draw score popups
function GameUI.drawScorePopups()
    love.graphics.setFont(getFont(28))
    for _, popup in ipairs(scorePopups) do
        love.graphics.setColor(popup.color[1], popup.color[2], popup.color[3], popup.alpha)
        love.graphics.print(popup.text, popup.x, popup.y)
    end
end

-- Draw the play area (selected cards preview + hand info)
-- gs: gameState, layout: layout table
function GameUI.drawPlayArea(gs, layout, screenW)
    -- Draw play area background
    love.graphics.setColor(0.15, 0.2, 0.15)
    love.graphics.rectangle("fill", screenW/2 - 250, layout.playAreaY - 20, 500, 150, 10, 10)

    love.graphics.setColor(0.3, 0.4, 0.3)
    love.graphics.rectangle("line", screenW/2 - 250, layout.playAreaY - 20, 500, 150, 10, 10)

    -- Draw selected cards in play area
    if #gs.selectedCards > 0 then
        local startX = screenW/2 - (#gs.selectedCards * layout.cardSpacing)/2 + layout.cardSpacing/2 - layout.cardWidth/2

        for i, cardIndex in ipairs(gs.selectedCards) do
            local card = gs.playerHand[cardIndex]
            local x = startX + (i-1) * layout.cardSpacing
            GameUI.drawCard(card, x, layout.playAreaY, layout, true)
        end

        -- Calculate and display hand info
        local playedCards = {}
        for _, cardIndex in ipairs(gs.selectedCards) do
            table.insert(playedCards, gs.playerHand[cardIndex])
        end

        local handName, chips, mult = PokerHands.evaluateHand(playedCards)

        -- Add card chips
        for _, card in ipairs(playedCards) do
            chips = chips + card.chips
        end

        -- Display hand info
        love.graphics.setColor(0.9, 0.9, 0.3)
        love.graphics.setFont(getFont(16))
        local handStr = handName
        local handW = love.graphics.getFont():getWidth(handStr)
        love.graphics.print(handStr, screenW/2 - handW/2, layout.playAreaY - 50)

        -- Display chips and mult (below the green box)
        love.graphics.setColor(0.7, 0.9, 0.7)
        love.graphics.setFont(getFont(20))
        local statsStr = string.format("Score: %d x %d = %d", chips, mult, chips * mult)
        local statsW = love.graphics.getFont():getWidth(statsStr)
        love.graphics.print(statsStr, screenW/2 - statsW/2, layout.playAreaY + 170)
    else
        -- Show hint when nothing selected
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.setFont(getFont(14))
        love.graphics.print("Select cards to see hand info", screenW/2 - 130, layout.playAreaY + 50)
    end
end

-- Draw a hand of cards
function GameUI.drawHand(hand, gs, layout, screenW, y, interactive)
    local startX = screenW/2 - (#hand * layout.cardSpacing)/2 + layout.cardSpacing/2 - layout.cardWidth/2
    local mx, my = love.mouse.getPosition()

    for i, card in ipairs(hand) do
        local x = startX + (i-1) * layout.cardSpacing
        local cardY = y

        -- Check if selected
        local isSelected = false
        for _, selIndex in ipairs(gs.selectedCards) do
            if selIndex == i then
                isSelected = true
                break
            end
        end

        if isSelected then
            cardY = y + layout.selectedOffset
        end

        -- Hover effect and tooltip tracking
        local isHovered = false
        if interactive then
            if mx >= x and mx <= x + layout.cardWidth and
               my >= cardY and my <= cardY + layout.cardHeight then
                cardY = cardY - 10
                isHovered = true
                -- Track for tooltip
                gs.hoveredCard = card
                gs.hoveredCardPos = {x = x, y = cardY}
            end
        end

        -- In blind mode, show cards face-down in hand (until played)
        local shouldShowFaceDown = gs.blindMode and interactive
        GameUI.drawCard(card, x, cardY, layout, not shouldShowFaceDown, isHovered)
    end
end

-- Draw action buttons (Play, Discard, Auto-Play, Hands Reference)
-- gs: gameState, constants: {CARDS_TO_PLAY}
function GameUI.drawGameButtons(gs, layout, constants, screenW, screenH)
    local buttonY = screenH - 80
    local buttonW, buttonH = 120, 45

    -- Play button
    local playX = screenW/2 - buttonW - 20
    local canPlay = #gs.selectedCards > 0 and #gs.selectedCards <= constants.CARDS_TO_PLAY and gs.handsLeft > 0

    if canPlay then
        love.graphics.setColor(0.2, 0.6, 0.3)
    else
        love.graphics.setColor(0.3, 0.3, 0.3)
    end
    love.graphics.rectangle("fill", playX, buttonY, buttonW, buttonH, 8, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(18))
    love.graphics.print("Play", playX + 40, buttonY + 12)

    -- Discard button
    local discardX = screenW/2 + 20
    local canDiscard = #gs.selectedCards > 0 and gs.discardsLeft > 0

    if canDiscard then
        love.graphics.setColor(0.6, 0.3, 0.2)
    else
        love.graphics.setColor(0.3, 0.3, 0.3)
    end
    love.graphics.rectangle("fill", discardX, buttonY, buttonW, buttonH, 8, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Discard", discardX + 25, buttonY + 12)

    -- Auto-Play toggle button
    local autoX = screenW - 140
    local autoY = buttonY
    local autoW, autoH = 120, 45

    if gs.autoPlay then
        love.graphics.setColor(0.2, 0.7, 0.2)  -- Green when active
    else
        love.graphics.setColor(0.5, 0.4, 0.6)  -- Purple when inactive
    end
    love.graphics.rectangle("fill", autoX, autoY, autoW, autoH, 8, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(14))
    local autoText = gs.autoPlay and "AUTO: ON" or "AUTO: OFF"
    love.graphics.printf(autoText, autoX, autoY + 15, autoW, "center")

    -- Hands Reference button (left side)
    local handsX = 20
    local handsY = buttonY
    local handsW, handsH = 90, 45

    if gs.showHandsReference then
        love.graphics.setColor(0.3, 0.6, 0.8)
    else
        love.graphics.setColor(0.4, 0.5, 0.6)
    end
    love.graphics.rectangle("fill", handsX, handsY, handsW, handsH, 8, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(14))
    love.graphics.printf("Hands", handsX, handsY + 15, handsW, "center")
end

-- Draw poker hands reference panel
function GameUI.drawHandsReference(gs, screenW, screenH)
    if not gs.showHandsReference then return end

    local panelW = 320
    local panelH = 380
    local panelX = 20
    local panelY = screenH - panelH - 140

    -- Panel background
    love.graphics.setColor(0.1, 0.1, 0.15, 0.95)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)
    love.graphics.setColor(0.4, 0.5, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 10, 10)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(0.9, 0.8, 0.3)
    love.graphics.setFont(getFont(18))
    love.graphics.printf("POKER HANDS", panelX, panelY + 10, panelW, "center")

    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(getFont(11))
    love.graphics.printf("(Best to Worst)", panelX, panelY + 32, panelW, "center")

    -- Hand rankings with descriptions
    local handsInfo = {
        {name = "Royal Flush", chips = 100, mult = 8, desc = "A-K-Q-J-10 same suit"},
        {name = "Straight Flush", chips = 100, mult = 8, desc = "5 sequential, same suit"},
        {name = "Four of a Kind", chips = 60, mult = 7, desc = "4 cards same rank"},
        {name = "Full House", chips = 40, mult = 4, desc = "3 of a kind + pair"},
        {name = "Flush", chips = 35, mult = 4, desc = "5 cards same suit"},
        {name = "Straight", chips = 30, mult = 4, desc = "5 sequential cards"},
        {name = "Three of a Kind", chips = 30, mult = 3, desc = "3 cards same rank"},
        {name = "Two Pair", chips = 20, mult = 2, desc = "2 different pairs"},
        {name = "Pair", chips = 10, mult = 2, desc = "2 cards same rank"},
        {name = "High Card", chips = 5, mult = 1, desc = "No combination"},
    }

    local y = panelY + 52
    local rowH = 30

    for i, hand in ipairs(handsInfo) do
        -- Alternating row background
        if i % 2 == 0 then
            love.graphics.setColor(0.15, 0.15, 0.2, 0.5)
            love.graphics.rectangle("fill", panelX + 5, y, panelW - 10, rowH)
        end

        -- Hand name
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(12))
        love.graphics.print(hand.name, panelX + 10, y + 2)

        -- Chips and mult
        love.graphics.setColor(0.3, 0.7, 1)
        love.graphics.setFont(getFont(11))
        love.graphics.print(string.format("+%d", hand.chips), panelX + 130, y + 2)

        love.graphics.setColor(1, 0.5, 0.3)
        love.graphics.print(string.format("x%d", hand.mult), panelX + 170, y + 2)

        -- Description
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.setFont(getFont(9))
        love.graphics.print(hand.desc, panelX + 10, y + 16)

        y = y + rowH
    end

    -- Scoring explanation
    y = y + 10
    love.graphics.setColor(0.7, 0.7, 0.5)
    love.graphics.setFont(getFont(10))
    love.graphics.printf("Score = (Chips + Card Values) x Mult", panelX, y, panelW, "center")

    -- Close hint
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.setFont(getFont(9))
    love.graphics.printf("Click 'Hands' to close", panelX, panelY + panelH - 18, panelW, "center")
end

-- Draw pause menu
function GameUI.drawPauseMenu(gs, screenW, screenH)
    if not gs.showPauseMenu then return end

    -- Dim background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Panel
    local panelW = 300
    local panelH = 200
    local panelX = screenW / 2 - panelW / 2
    local panelY = screenH / 2 - panelH / 2

    love.graphics.setColor(0.15, 0.12, 0.2, 0.95)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)
    love.graphics.setColor(0.5, 0.4, 0.7)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 10, 10)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(24))
    love.graphics.printf("PAUSED", panelX, panelY + 20, panelW, "center")

    -- Buttons
    local btnW = 200
    local btnH = 45
    local btnX = panelX + panelW / 2 - btnW / 2
    local mx, my = love.mouse.getPosition()

    -- Resume button
    local resumeY = panelY + 70
    local resumeHover = mx >= btnX and mx <= btnX + btnW and my >= resumeY and my <= resumeY + btnH
    love.graphics.setColor(resumeHover and {0.3, 0.7, 0.3} or {0.2, 0.5, 0.2})
    love.graphics.rectangle("fill", btnX, resumeY, btnW, btnH, 8, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(18))
    love.graphics.printf("Resume", btnX, resumeY + 12, btnW, "center")

    -- Quit button
    local quitY = panelY + 130
    local quitHover = mx >= btnX and mx <= btnX + btnW and my >= quitY and my <= quitY + btnH
    love.graphics.setColor(quitHover and {0.8, 0.3, 0.3} or {0.6, 0.2, 0.2})
    love.graphics.rectangle("fill", btnX, quitY, btnW, btnH, 8, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Quit to Menu", btnX, quitY + 12, btnW, "center")

    -- ESC hint
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.setFont(getFont(11))
    love.graphics.printf("Press ESC to resume", panelX, panelY + panelH - 25, panelW, "center")
end

-- Draw round end screen (shop + stats between rounds, or game end)
-- gs: gameState, gameModes: Game.modes table, shopItems: shop items table,
-- puristLadder, puristMilestones, puristTiers: purist data tables
-- UIAssets: UIAssets module reference
function GameUI.drawRoundEndScreen(gs, gameModes, shopItems, puristLadder, puristMilestones, puristTiers, UIAssets, screenW, screenH)
    -- Overlay
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    local won = gs.roundScores.player >= gs.targetScore

    if gs.phase == "gameEnd" then
        -- Final game end screen
        local boxW = gs.isPuristMode and gs.puristVictory and 500 or 440
        local boxH = gs.isPuristMode and gs.puristVictory and 400 or 360

        love.graphics.setColor(0.12, 0.12, 0.18)
        love.graphics.rectangle("fill", screenW/2 - boxW/2, screenH/2 - boxH/2, boxW, boxH, 15, 15)

        -- Border color
        local borderColor = {0.9, 0.3, 0.3}
        if gs.isPuristMode and gs.puristVictory then
            borderColor = {1.0, 0.85, 0.0}  -- Gold for purist victory
        elseif won then
            borderColor = {0.3, 0.9, 0.3}
        end
        love.graphics.setColor(borderColor)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", screenW/2 - boxW/2, screenH/2 - boxH/2, boxW, boxH, 15, 15)
        love.graphics.setLineWidth(1)

        -- Title
        love.graphics.setFont(getFont(36))
        local title
        if gs.isPuristMode and gs.puristVictory then
            title = "CHAMPION!"
            love.graphics.setColor(1.0, 0.85, 0.0)
        elseif won then
            title = "VICTORY!"
            love.graphics.setColor(0.3, 0.9, 0.3)
        else
            title = "DEFEAT"
            love.graphics.setColor(0.9, 0.3, 0.3)
        end
        local titleW = love.graphics.getFont():getWidth(title)
        love.graphics.print(title, screenW/2 - titleW/2, screenH/2 - boxH/2 + 20)

        -- Purist mode victory content
        if gs.isPuristMode and gs.puristVictory then
            love.graphics.setFont(getFont(20))
            love.graphics.setColor(0.9, 0.9, 0.9)
            love.graphics.printf("You've defeated all 15 opponents!", screenW/2 - 200, screenH/2 - 80, 400, "center")

            love.graphics.setColor(0.9, 0.8, 0.3)
            love.graphics.setFont(getFont(18))
            love.graphics.printf("The ladder has been conquered!", screenW/2 - 200, screenH/2 - 40, 400, "center")

            love.graphics.setColor(0.3, 0.9, 0.5)
            love.graphics.setFont(getFont(22))
            love.graphics.printf("+1000 coins reward!", screenW/2 - 150, screenH/2 + 10, 300, "center")
            love.graphics.printf("+15 wins!", screenW/2 - 150, screenH/2 + 45, 300, "center")

            love.graphics.setColor(0.7, 0.7, 0.8)
            love.graphics.setFont(getFont(14))
            love.graphics.printf("You are now a true Purist Master.", screenW/2 - 180, screenH/2 + 90, 360, "center")
        else
            -- Normal game end stats
            love.graphics.setFont(getFont(18))
            love.graphics.setColor(0.9, 0.9, 0.9)
            love.graphics.print(string.format("Final Score: %d", gs.roundScores.player), screenW/2 - 80, screenH/2 - 80)

            if gs.isPuristMode then
                love.graphics.print(string.format("Opponents Defeated: %d/15", gs.puristOpponent - 1), screenW/2 - 100, screenH/2 - 50)
            else
                love.graphics.print(string.format("Rounds Completed: %d", gs.round), screenW/2 - 80, screenH/2 - 50)
            end

            if won then
                local reward = 20 + gs.round * 10
                love.graphics.setColor(0.9, 0.8, 0.2)
                love.graphics.print(string.format("Reward: +%d coins!", reward), screenW/2 - 80, screenH/2)
            end
        end

        -- Return button
        love.graphics.setColor(0.3, 0.5, 0.7)
        love.graphics.rectangle("fill", screenW/2 - 70, screenH/2 + 130, 140, 50, 8, 8)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(20))
        love.graphics.print("Continue", screenW/2 - 45, screenH/2 + 143)
    else
        -- Between-round shop screen
        local panelW, panelH = 700, 520
        local panelX = screenW/2 - panelW/2
        local panelY = screenH/2 - panelH/2

        love.graphics.setColor(0.12, 0.12, 0.18)
        love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 15, 15)
        love.graphics.setColor(0.9, 0.7, 0.2)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 15, 15)
        love.graphics.setLineWidth(1)

        -- Title
        love.graphics.setFont(getFont(28))
        love.graphics.setColor(0.9, 0.8, 0.3)
        local title
        if gs.isPuristMode and gs.puristCurrentOpp then
            title = gs.puristCurrentOpp.name .. " Defeated!"
        else
            title = "Round " .. gs.round .. " Complete!"
        end
        local titleW = love.graphics.getFont():getWidth(title)
        love.graphics.print(title, screenW/2 - titleW/2, panelY + 15)

        -- Left panel: Round stats
        local statsX = panelX + 20
        local statsY = panelY + 60
        local statsW = 200

        love.graphics.setColor(0.08, 0.08, 0.12)
        love.graphics.rectangle("fill", statsX, statsY, statsW, 180, 10, 10)

        love.graphics.setFont(getFont(16))
        love.graphics.setColor(0.9, 0.7, 0.2)
        love.graphics.print("Round Stats", statsX + 55, statsY + 10)

        love.graphics.setFont(getFont(14))
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print(string.format("Your Score: %d", gs.roundScores.player), statsX + 15, statsY + 40)
        love.graphics.print(string.format("Target: %d", gs.targetScore), statsX + 15, statsY + 60)
        local mode = gameModes[gs.gameMode] or gameModes.standard
        love.graphics.print(string.format("Hands Used: %d", mode.startingHands - gs.handsLeft), statsX + 15, statsY + 80)

        -- Purist mode: show ladder progress
        if gs.isPuristMode then
            love.graphics.setColor(0.9, 0.8, 0.3)
            love.graphics.print(string.format("Progress: %d/15", gs.puristOpponent), statsX + 15, statsY + 100)

            -- Check for milestone
            local milestone = nil
            for _, m in ipairs(puristMilestones) do
                if m.opponent == gs.puristOpponent then
                    milestone = m
                    break
                end
            end
            if milestone then
                love.graphics.setColor(0.3, 0.9, 0.5)
                love.graphics.print(milestone.desc, statsX + 15, statsY + 120)
                love.graphics.print(string.format("+%d bonus!", milestone.reward), statsX + 15, statsY + 138)
            end
        end

        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print(string.format("Coins: %d", PlayerData.coins), statsX + 15, statsY + 158)

        -- Reward (non-milestone)
        local reward = 10 + gs.round * 5
        if not gs.isPuristMode then
            love.graphics.setColor(0.3, 0.9, 0.3)
            love.graphics.print(string.format("+%d coins earned!", reward), statsX + 15, statsY + 178)
        end

        -- Middle panel: Next round preview
        local previewX = panelX + 240
        local previewY = panelY + 60
        local previewW = 200

        love.graphics.setColor(0.08, 0.08, 0.12)
        love.graphics.rectangle("fill", previewX, previewY, previewW, 180, 10, 10)

        local nextRoundNum = gs.round + 1

        -- Purist mode: show next opponent
        if gs.isPuristMode then
            local nextOppIdx = gs.puristOpponent + 1

            if nextOppIdx <= #puristLadder then
                local nextOpp = puristLadder[nextOppIdx]
                local nextTarget = mode.targetScoreBase + nextOpp.targetBonus

                love.graphics.setFont(getFont(16))
                love.graphics.setColor(0.9, 0.7, 0.2)
                love.graphics.print("Next Opponent", previewX + 45, previewY + 5)

                -- Draw opponent portrait
                local portraitSize = 50
                if nextOpp.portrait then
                    local portrait = UIAssets.getCharacter(nextOpp.portrait)
                    if portrait then
                        love.graphics.setColor(1, 1, 1)
                        local imgW, imgH = portrait:getDimensions()
                        local scale = portraitSize / math.max(imgW, imgH)
                        love.graphics.draw(portrait, previewX + previewW - portraitSize - 10, previewY + 25, 0, scale, scale)
                        -- Frame
                        love.graphics.setColor(nextOpp.color)
                        love.graphics.setLineWidth(2)
                        love.graphics.rectangle("line", previewX + previewW - portraitSize - 11, previewY + 24, portraitSize + 2, portraitSize + 2, 4, 4)
                        love.graphics.setLineWidth(1)
                    end
                end

                -- Opponent info
                love.graphics.setColor(nextOpp.color)
                love.graphics.setFont(getFont(14))
                love.graphics.print(nextOpp.name, previewX + 15, previewY + 30)

                love.graphics.setColor(0.7, 0.6, 0.5)
                love.graphics.setFont(getFont(11))
                love.graphics.print(nextOpp.title, previewX + 15, previewY + 48)

                love.graphics.setColor(0.8, 0.8, 0.8)
                love.graphics.setFont(getFont(13))
                love.graphics.print(string.format("Opponent: %d/15", nextOppIdx), previewX + 15, previewY + 70)
                love.graphics.print(string.format("Target: %d", nextTarget), previewX + 15, previewY + 90)
                love.graphics.print(string.format("Hands: %d", mode.startingHands), previewX + 15, previewY + 110)

                -- Trait warning
                if nextOpp.trait then
                    love.graphics.setColor(0.9, 0.4, 0.4)
                    love.graphics.setFont(getFont(11))
                    local traitText = {
                        extra_mult = "Has bonus mult!",
                        less_hands = "-1 Hand penalty!",
                        less_discards = "-1 Discard penalty!",
                        high_target = "+50 Target penalty!",
                        combo_penalty = "Very tough!",
                        final_boss = "THE FINAL BOSS!"
                    }
                    love.graphics.print(traitText[nextOpp.trait] or "", previewX + 15, previewY + 135)
                end

                -- Tier
                local tierInfo = puristTiers[nextOpp.tier]
                if tierInfo then
                    love.graphics.setColor(tierInfo.color)
                    love.graphics.setFont(getFont(10))
                    love.graphics.print("Tier " .. nextOpp.tier .. ": " .. tierInfo.name, previewX + 15, previewY + 155)
                end
            else
                -- Victory screen preview
                love.graphics.setFont(getFont(18))
                love.graphics.setColor(1, 0.85, 0)
                love.graphics.print("FINAL WIN!", previewX + 40, previewY + 60)
                love.graphics.setColor(0.8, 0.8, 0.8)
                love.graphics.setFont(getFont(12))
                love.graphics.print("You've beaten all 15!", previewX + 30, previewY + 90)
                love.graphics.print("+1000 coin reward!", previewX + 40, previewY + 110)
            end
        else
            -- Normal mode preview
            love.graphics.setFont(getFont(16))
            love.graphics.setColor(0.9, 0.7, 0.2)
            love.graphics.print("Next Round", previewX + 55, previewY + 10)

            local nextTarget = gs.targetScore + mode.targetScoreIncrease

            love.graphics.setFont(getFont(14))
            love.graphics.setColor(0.8, 0.8, 0.8)
            love.graphics.print(string.format("Round: %d", nextRoundNum), previewX + 15, previewY + 45)
            love.graphics.print(string.format("Target: %d", nextTarget), previewX + 15, previewY + 70)
            love.graphics.print(string.format("Hands: %d", mode.startingHands), previewX + 15, previewY + 95)
            love.graphics.print(string.format("Discards: %d", mode.startingDiscards), previewX + 15, previewY + 120)

            -- Boss warning
            if gs.gameMode == "marathon" and mode.bossEvery and nextRoundNum % mode.bossEvery == 0 then
                love.graphics.setColor(0.9, 0.3, 0.3)
                love.graphics.print("BOSS ROUND!", previewX + 50, previewY + 150)
            end
        end

        -- Right panel: Shop
        local shopX = panelX + 460
        local shopY = panelY + 60
        local shopW = 220

        love.graphics.setColor(0.08, 0.08, 0.12)
        love.graphics.rectangle("fill", shopX, shopY, shopW, 180, 10, 10)

        love.graphics.setFont(getFont(16))
        love.graphics.setColor(0.9, 0.7, 0.2)
        love.graphics.print("Quick Shop", shopX + 65, shopY + 10)

        -- Shop items
        local itemY = shopY + 40
        local mx, my = love.mouse.getPosition()
        love.graphics.setFont(getFont(12))

        for i, item in ipairs(shopItems) do
            if i <= 3 then  -- Show only 3 items
                local itemX = shopX + 10
                local itemW, itemH = shopW - 20, 40
                local hover = mx >= itemX and mx <= itemX + itemW and my >= itemY and my <= itemY + itemH
                local canAfford = PlayerData.coins >= item.cost

                if canAfford then
                    love.graphics.setColor(hover and {0.25, 0.35, 0.45} or {0.15, 0.2, 0.3})
                else
                    love.graphics.setColor(0.15, 0.15, 0.18)
                end
                love.graphics.rectangle("fill", itemX, itemY, itemW, itemH, 5, 5)

                love.graphics.setColor(canAfford and {0.9, 0.9, 0.9} or {0.5, 0.5, 0.5})
                love.graphics.print(item.name, itemX + 5, itemY + 5)
                love.graphics.setColor(0.9, 0.7, 0.2)
                love.graphics.print(item.cost .. "c", itemX + itemW - 30, itemY + 5)
                love.graphics.setColor(0.6, 0.6, 0.7)
                love.graphics.print(item.description, itemX + 5, itemY + 22)

                itemY = itemY + 45
            end
        end

        -- Pack purchase option
        local packAreaH = gs.isPuristMode and 120 or 80
        local packY = panelY + 260
        local packW = panelW - 40

        love.graphics.setColor(0.1, 0.1, 0.15)
        love.graphics.rectangle("fill", panelX + 20, packY, packW, packAreaH, 10, 10)

        love.graphics.setFont(getFont(18))
        love.graphics.setColor(0.9, 0.7, 0.2)
        local packTitle = gs.isPuristMode and "Card & Joker Packs (Added to Run Deck)" or "Card Packs"
        love.graphics.print(packTitle, panelX + 40, packY + 10)

        -- Deck size indicator for purist mode
        if gs.isPuristMode then
            love.graphics.setFont(getFont(12))
            love.graphics.setColor(0.6, 0.8, 0.6)
            love.graphics.print(string.format("Deck: %d cards | Jokers: %d",
                #gs.playerDeck + #gs.playerDiscard + #gs.playerHand,
                #gs.playerJokers), panelX + 450, packY + 12)
        end

        -- Pack buttons
        local packs = {
            {name = "Basic", cost = 50, cards = 3},
            {name = "Standard", cost = 100, cards = 5},
            {name = "Premium", cost = 200, cards = 5},
        }

        local packBtnX = panelX + 40
        local packBtnY = packY + 40
        for _, pack in ipairs(packs) do
            local packBtnW, packBtnH = 180, 30
            local hover = mx >= packBtnX and mx <= packBtnX + packBtnW and my >= packBtnY and my <= packBtnY + packBtnH
            local canAfford = PlayerData.coins >= pack.cost

            love.graphics.setColor(canAfford and (hover and {0.3, 0.5, 0.3} or {0.2, 0.35, 0.2}) or {0.2, 0.2, 0.25})
            love.graphics.rectangle("fill", packBtnX, packBtnY, packBtnW, packBtnH, 5, 5)

            love.graphics.setColor(canAfford and {0.9, 0.9, 0.9} or {0.5, 0.5, 0.5})
            love.graphics.setFont(getFont(14))
            love.graphics.print(string.format("%s Pack (%d cards) - %dc", pack.name, pack.cards, pack.cost), packBtnX + 10, packBtnY + 7)

            packBtnX = packBtnX + 200
        end

        -- Joker pack for purist mode
        if gs.isPuristMode then
            local jokerPackY = packY + 80
            local jokerPackW, jokerPackH = 200, 30
            local jokerPackX = panelX + 250
            local jokerHover = mx >= jokerPackX and mx <= jokerPackX + jokerPackW and
                               my >= jokerPackY and my <= jokerPackY + jokerPackH
            local canAffordJoker = PlayerData.coins >= 150

            love.graphics.setColor(canAffordJoker and (jokerHover and {0.5, 0.3, 0.5} or {0.35, 0.2, 0.35}) or {0.2, 0.2, 0.25})
            love.graphics.rectangle("fill", jokerPackX, jokerPackY, jokerPackW, jokerPackH, 5, 5)

            love.graphics.setColor(canAffordJoker and {0.9, 0.7, 0.9} or {0.5, 0.5, 0.5})
            love.graphics.setFont(getFont(14))
            love.graphics.print("Joker Pack (1) - 150c", jokerPackX + 15, jokerPackY + 7)
        end

        -- Continue button
        local continueW, continueH = 160, 50
        local continueX = screenW/2 - continueW/2
        local continueY = panelY + panelH - 70
        local continueHover = mx >= continueX and mx <= continueX + continueW and my >= continueY and my <= continueY + continueH

        love.graphics.setColor(continueHover and {0.3, 0.6, 0.3} or {0.2, 0.5, 0.2})
        love.graphics.rectangle("fill", continueX, continueY, continueW, continueH, 8, 8)
        love.graphics.setColor(0.9, 0.8, 0.2)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", continueX, continueY, continueW, continueH, 8, 8)
        love.graphics.setLineWidth(1)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(20))
        love.graphics.print("Next Round", continueX + 25, continueY + 13)
    end
end

-- Draw auto-play continue screen
function GameUI.drawAutoPlayContinue(gs, screenW, screenH)
    -- Dark overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Victory message with auto-continue
    local boxW, boxH = 400, 200
    local boxX, boxY = screenW/2 - boxW/2, screenH/2 - boxH/2

    love.graphics.setColor(0.15, 0.2, 0.15)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH, 12, 12)
    love.graphics.setColor(0.3, 0.7, 0.3)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH, 12, 12)

    love.graphics.setColor(0.4, 0.9, 0.4)
    love.graphics.setFont(getFont(28))
    love.graphics.printf("VICTORY!", boxX, boxY + 30, boxW, "center")

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(16))
    love.graphics.printf("Auto-Play: Starting next match...", boxX, boxY + 80, boxW, "center")

    -- Show streak
    love.graphics.setColor(1, 0.9, 0.4)
    love.graphics.setFont(getFont(20))
    local streak = gs.autoPlayWins or 0
    love.graphics.printf("Win Streak: " .. streak, boxX, boxY + 120, boxW, "center")

    -- Progress bar
    local progress = (gs.autoPlayContinueTimer or 0) / 2.0
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", boxX + 50, boxY + 160, boxW - 100, 15, 5, 5)
    love.graphics.setColor(0.4, 0.8, 0.4)
    love.graphics.rectangle("fill", boxX + 50, boxY + 160, (boxW - 100) * progress, 15, 5, 5)
end

return GameUI
