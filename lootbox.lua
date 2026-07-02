-- Loot Box System - Gacha-style card/joker acquisition

local LootBox = {}
local Cards = require("cards")
local Jokers = require("jokers")
local UIAssets = require("uiassets")
local UI = require("ui")
local CardRenderer = require("ui_cardrenderer")

-- UI State
local selectedPack = nil
local openingPack = false
local openTimer = 0
local revealedCards = {}
local revealIndex = 0
local showingResults = false
local packScrollY = 0  -- Scroll position for pack selection
local maxPackScroll = 0  -- Maximum scroll amount

-- UI Components
local backButton = nil
local collectButton = nil

-- Pack definitions
LootBox.packs = {
    {
        id = "basic",
        name = "Basic Pack",
        description = "3 cards, mostly common",
        cost = 50,
        cardCount = 3,
        type = "cards",
        icon = "chest_common",
        rarityWeights = {
            common = 70,
            uncommon = 25,
            rare = 5,
            epic = 0,
            legendary = 0
        }
    },
    {
        id = "standard",
        name = "Standard Pack",
        description = "4 cards with better odds",
        cost = 100,
        cardCount = 4,
        type = "cards",
        icon = "chest_uncommon",
        rarityWeights = {
            common = 50,
            uncommon = 35,
            rare = 12,
            epic = 3,
            legendary = 0
        }
    },
    {
        id = "premium",
        name = "Premium Pack",
        description = "5 cards, guaranteed rare+",
        cost = 250,
        cardCount = 5,
        type = "cards",
        icon = "chest_rare",
        rarityWeights = {
            common = 20,
            uncommon = 40,
            rare = 30,
            epic = 8,
            legendary = 2
        },
        guaranteedRare = true
    },
    {
        id = "joker_basic",
        name = "Joker Pack",
        description = "2 random jokers",
        cost = 150,
        cardCount = 2,
        type = "jokers",
        icon = "chest_epic",
        rarityWeights = {
            common = 60,
            uncommon = 30,
            rare = 10,
            epic = 0,
            legendary = 0
        }
    },
    {
        id = "joker_premium",
        name = "Premium Joker Pack",
        description = "3 jokers, better odds",
        cost = 400,
        cardCount = 3,
        type = "jokers",
        icon = "chest_legendary",
        rarityWeights = {
            common = 30,
            uncommon = 40,
            rare = 20,
            epic = 8,
            legendary = 2
        }
    },
    {
        id = "mega",
        name = "Mega Pack",
        description = "5 cards + 1 joker!",
        cost = 500,
        cardCount = 6,
        type = "mixed",
        icon = "chest_legendary",
        rarityWeights = {
            common = 25,
            uncommon = 40,
            rare = 25,
            epic = 8,
            legendary = 2
        },
        guaranteedRare = true
    },
    -- Bulk packs for commons
    {
        id = "bulk_common",
        name = "Bulk Common Pack",
        description = "10 common cards - great value!",
        cost = 75,
        cardCount = 10,
        type = "cards",
        icon = "wooden_chest",
        rarityWeights = {
            common = 95,
            uncommon = 5,
            rare = 0,
            epic = 0,
            legendary = 0
        }
    },
    {
        id = "bulk_mixed",
        name = "Bulk Mixed Pack",
        description = "8 cards of varied rarity",
        cost = 120,
        cardCount = 8,
        type = "cards",
        icon = "wooden_box",
        rarityWeights = {
            common = 60,
            uncommon = 30,
            rare = 8,
            epic = 2,
            legendary = 0
        }
    },
    -- Budget joker pack
    {
        id = "joker_budget",
        name = "Budget Joker Pack",
        description = "1 joker - cheap entry!",
        cost = 60,
        cardCount = 1,
        type = "jokers",
        icon = "bag_brown",
        rarityWeights = {
            common = 80,
            uncommon = 18,
            rare = 2,
            epic = 0,
            legendary = 0
        }
    },
    {
        id = "joker_bulk",
        name = "Bulk Joker Pack",
        description = "5 jokers - best value!",
        cost = 350,
        cardCount = 5,
        type = "jokers",
        icon = "bag_master",
        rarityWeights = {
            common = 50,
            uncommon = 35,
            rare = 12,
            epic = 3,
            legendary = 0
        }
    },
    -- Ultra rare packs
    {
        id = "epic_hunter",
        name = "Epic Hunter Pack",
        description = "4 cards - epic odds boosted!",
        cost = 350,
        cardCount = 4,
        type = "cards",
        icon = "chest_epic",
        rarityWeights = {
            common = 10,
            uncommon = 30,
            rare = 35,
            epic = 20,
            legendary = 5
        },
        guaranteedRare = true
    },
    {
        id = "legendary_chase",
        name = "Legendary Chase Pack",
        description = "3 cards - chase the legendary!",
        cost = 600,
        cardCount = 3,
        type = "cards",
        icon = "chest_legendary",
        rarityWeights = {
            common = 0,
            uncommon = 20,
            rare = 40,
            epic = 30,
            legendary = 10
        },
        guaranteedRare = true
    },
    {
        id = "joker_legendary",
        name = "Legendary Joker Pack",
        description = "2 jokers - legendary odds!",
        cost = 750,
        cardCount = 2,
        type = "jokers",
        icon = "bag_master",
        rarityWeights = {
            common = 10,
            uncommon = 25,
            rare = 35,
            epic = 20,
            legendary = 10
        }
    },
    -- Ultimate pack
    {
        id = "ultimate",
        name = "Ultimate Pack",
        description = "8 cards + 2 jokers! Guaranteed epic+",
        cost = 1000,
        cardCount = 10,
        type = "mixed",
        icon = "chest_ultimate",
        rarityWeights = {
            common = 0,
            uncommon = 30,
            rare = 40,
            epic = 20,
            legendary = 10
        },
        guaranteedRare = true,
        guaranteedEpic = true
    },
    -- Mystery packs (new)
    {
        id = "mystery",
        name = "Mystery Box",
        description = "??? Anything can happen!",
        cost = 200,
        cardCount = 4,
        type = "mixed",
        icon = "mystery_box",
        rarityWeights = {
            common = 30,
            uncommon = 30,
            rare = 20,
            epic = 15,
            legendary = 5
        }
    },
    -- Mega bulk packs
    {
        id = "bulk_mega",
        name = "Mega Bulk Pack",
        description = "20 cards - massive value!",
        cost = 200,
        cardCount = 20,
        type = "cards",
        icon = "wooden_chest",
        rarityWeights = {
            common = 70,
            uncommon = 25,
            rare = 5,
            epic = 0,
            legendary = 0
        }
    },
    {
        id = "bulk_premium",
        name = "Premium Bulk Pack",
        description = "15 cards - better odds!",
        cost = 300,
        cardCount = 15,
        type = "cards",
        icon = "chest_uncommon",
        rarityWeights = {
            common = 45,
            uncommon = 35,
            rare = 15,
            epic = 5,
            legendary = 0
        }
    },
}

-- Colors
local colors = {
    bg = {0.08, 0.08, 0.12},
    panel = {0.12, 0.12, 0.17},
    button = {0.2, 0.3, 0.5},
    buttonHover = {0.3, 0.4, 0.6},
    buttonDisabled = {0.2, 0.2, 0.25},
    text = {1, 1, 1},
    textDim = {0.6, 0.6, 0.6},
    accent = {0.9, 0.6, 0.2},
    gold = {1, 0.85, 0.2},
    common = {0.7, 0.7, 0.7},
    uncommon = {0.3, 0.8, 0.3},
    rare = {0.3, 0.5, 1},
    epic = {0.8, 0.3, 0.8},
    legendary = {1, 0.8, 0.2}
}

function LootBox.init()
    selectedPack = nil
    openingPack = false
    openTimer = 0
    revealedCards = {}
    revealIndex = 0
    showingResults = false

    -- Initialize UI components
    local screenW, screenH = love.graphics.getDimensions()

    backButton = UI.Button.new({
        x = 20,
        y = screenH - 60,
        w = 100,
        h = 40,
        text = "Back",
        variant = "secondary",
        onClick = function()
            if showingResults then
                LootBox.collectCards()
                showingResults = false
                revealedCards = {}
                revealIndex = 0
            else
                local TextRPG = require("textrpg")
                TextRPG.init()
                GameState.current = "textrpg"
            end
        end
    })

    collectButton = UI.Button.new({
        x = 0,
        y = 0,
        w = 200,
        h = 50,
        text = "Collect!",
        variant = "primary",
        onClick = function()
            LootBox.collectCards()
            showingResults = false
            revealedCards = {}
            revealIndex = 0
        end
    })
end

function LootBox.update(dt)
    if openingPack then
        openTimer = openTimer + dt

        -- Reveal cards one at a time
        if openTimer > 0.5 and revealIndex < #revealedCards then
            openTimer = 0
            revealIndex = revealIndex + 1
        end

        -- All cards revealed
        if revealIndex >= #revealedCards then
            showingResults = true
            openingPack = false
        end
    end

    -- Update UI components
    if backButton then
        local screenW, screenH = love.graphics.getDimensions()
        backButton.y = screenH - 60
        backButton:update(dt)
    end

    if collectButton and showingResults then
        local screenW, screenH = love.graphics.getDimensions()
        collectButton.x = screenW/2 - collectButton.w/2
        collectButton.y = screenH - 100
        collectButton:update(dt)
    end
end

function LootBox.draw()
    local screenW, screenH = love.graphics.getDimensions()

    -- Clear tooltip state
    UIAssets.clearTooltip()

    -- Background
    love.graphics.setColor(colors.bg)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Title
    love.graphics.setColor(colors.accent)
    love.graphics.setFont(UI.fonts.get(42))
    local title = "LOOT BOXES"
    local titleW = love.graphics.getFont():getWidth(title)
    love.graphics.print(title, screenW/2 - titleW/2, 30)

    -- Coins display with hover tooltip
    love.graphics.setFont(UI.fonts.get(24))
    UIAssets.drawCurrencyWithTooltip("coins", PlayerData.coins, screenW - 200, 38, 28)

    if showingResults then
        LootBox.drawResults(screenW, screenH)
    elseif openingPack then
        LootBox.drawOpening(screenW, screenH)
    else
        LootBox.drawPackSelection(screenW, screenH)
    end

    -- Draw UI components
    if backButton then
        backButton:draw()
    end

    -- Draw tooltip (must be last)
    UIAssets.drawTooltip()
end

function LootBox.drawPackSelection(screenW, screenH)
    local packW, packH = 180, 220
    local spacing = 20
    local packsPerRow = 3
    local totalWidth = packsPerRow * packW + (packsPerRow - 1) * spacing
    local startX = screenW/2 - totalWidth/2
    local startY = 100

    -- Calculate content height and scroll bounds
    local numRows = math.ceil(#LootBox.packs / packsPerRow)
    local contentHeight = numRows * (packH + spacing)
    local visibleHeight = screenH - 180  -- Area for packs
    maxPackScroll = math.max(0, contentHeight - visibleHeight)
    packScrollY = math.max(0, math.min(packScrollY, maxPackScroll))

    local mx, my = love.mouse.getPosition()

    -- Scroll indicator if needed
    if maxPackScroll > 0 then
        love.graphics.setColor(0.4, 0.4, 0.5)
        love.graphics.setFont(UI.fonts.get(12))
        if packScrollY < maxPackScroll then
            love.graphics.print("▼ Scroll for more ▼", screenW/2 - 60, screenH - 95)
        end
    end

    -- Set scissor to clip packs area
    love.graphics.setScissor(0, startY - 10, screenW, visibleHeight + 20)

    for i, pack in ipairs(LootBox.packs) do
        local row = math.floor((i-1) / packsPerRow)
        local col = (i-1) % packsPerRow
        local x = startX + col * (packW + spacing)
        local y = startY + row * (packH + spacing) - packScrollY

        -- Skip if pack is not visible
        if y + packH < startY - 10 or y > startY + visibleHeight + 10 then
            pack._bounds = nil  -- Clear bounds for non-visible packs
            goto continue
        end

        local hover = mx >= x and mx <= x + packW and my >= y and my <= y + packH and my >= startY - 10 and my <= startY + visibleHeight
        local canAfford = PlayerData.coins >= pack.cost

        -- Pack background
        if hover and canAfford then
            love.graphics.setColor(0.25, 0.3, 0.4)
        elseif canAfford then
            love.graphics.setColor(colors.panel)
        else
            love.graphics.setColor(0.15, 0.15, 0.18)
        end
        love.graphics.rectangle("fill", x, y, packW, packH, 12, 12)

        -- Border color based on pack type
        local borderColor = colors.accent
        if pack.type == "jokers" then
            borderColor = colors.epic
        elseif pack.type == "mixed" then
            borderColor = colors.legendary
        end
        love.graphics.setColor(borderColor)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x, y, packW, packH, 12, 12)
        love.graphics.setLineWidth(1)

        -- Pack icon
        local iconDrawn = false
        if pack.icon then
            local iconImg = UIAssets.getIconByName(pack.icon)
            if iconImg then
                love.graphics.setColor(1, 1, 1)
                local imgW, imgH = iconImg:getDimensions()
                local iconSize = 70
                local scale = iconSize / math.max(imgW, imgH)
                love.graphics.draw(iconImg, x + packW/2 - (imgW * scale)/2, y + 25, 0, scale, scale)
                iconDrawn = true
            end
        end
        -- Fallback placeholder if no icon
        if not iconDrawn then
            love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], 0.3)
            love.graphics.rectangle("fill", x + 40, y + 20, 100, 80, 8, 8)
        end

        -- Pack name
        love.graphics.setColor(canAfford and colors.text or colors.textDim)
        love.graphics.setFont(UI.fonts.get(16))
        local nameW = love.graphics.getFont():getWidth(pack.name)
        love.graphics.print(pack.name, x + packW/2 - nameW/2, y + 110)

        -- Description
        love.graphics.setColor(colors.textDim)
        love.graphics.setFont(UI.fonts.get(12))
        local descW = love.graphics.getFont():getWidth(pack.description)
        love.graphics.print(pack.description, x + packW/2 - descW/2, y + 135)

        -- Cost with coin icon
        love.graphics.setColor(canAfford and colors.gold or {0.6, 0.4, 0.4})
        love.graphics.setFont(UI.fonts.get(20))
        local costText = string.format("%d", pack.cost)
        local costW = love.graphics.getFont():getWidth(costText)

        -- Draw coin icon next to cost
        local costCoinIcon = UIAssets.getIconByName("gold_coin")
        local totalCostW = costW + 24
        local costStartX = x + packW/2 - totalCostW/2

        if costCoinIcon then
            love.graphics.setColor(canAfford and {1, 1, 1} or {0.5, 0.5, 0.5})
            local cImgW, cImgH = costCoinIcon:getDimensions()
            local cScale = 20 / math.max(cImgW, cImgH)
            love.graphics.draw(costCoinIcon, costStartX, y + 168, 0, cScale, cScale)
        end
        love.graphics.setColor(canAfford and colors.gold or {0.6, 0.4, 0.4})
        love.graphics.print(costText, costStartX + 22, y + 165)

        -- Store pack bounds for click detection
        pack._bounds = {x = x, y = y, w = packW, h = packH}

        ::continue::
    end

    -- Reset scissor
    love.graphics.setScissor()

    -- Scrollbar for pack list
    if maxPackScroll > 0 then
        local scrollbarX = screenW - 20
        local scrollbarY = startY
        local scrollbarH = visibleHeight
        local thumbH = math.max(30, scrollbarH * (visibleHeight / contentHeight))
        local thumbY = scrollbarY + (packScrollY / maxPackScroll) * (scrollbarH - thumbH)
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", scrollbarX, scrollbarY, 8, scrollbarH, 4, 4)
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.rectangle("fill", scrollbarX, thumbY, 8, thumbH, 4, 4)
    end

    -- Instructions
    love.graphics.setColor(colors.textDim)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.print("Click a pack to purchase and open it!", screenW/2 - 140, screenH - 115)
end

function LootBox.drawOpening(screenW, screenH)
    -- Opening animation
    love.graphics.setColor(colors.text)
    love.graphics.setFont(UI.fonts.get(32))
    local openText = "Opening..."
    local openW = love.graphics.getFont():getWidth(openText)
    love.graphics.print(openText, screenW/2 - openW/2, 150)

    -- Show revealed cards
    local cardW, cardH = 100, 140
    local spacing = 20
    local totalWidth = #revealedCards * cardW + (#revealedCards - 1) * spacing
    local startX = screenW/2 - totalWidth/2

    for i, item in ipairs(revealedCards) do
        local x = startX + (i-1) * (cardW + spacing)
        local y = 250

        if i <= revealIndex then
            -- Revealed card
            local rarityColor = colors[item.rarity] or colors.common

            if item.isJoker then
                -- Draw joker card
                love.graphics.setColor(rarityColor[1] * 0.3, rarityColor[2] * 0.3, rarityColor[3] * 0.3)
                love.graphics.rectangle("fill", x, y, cardW, cardH, 8, 8)
                love.graphics.setColor(rarityColor)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", x, y, cardW, cardH, 8, 8)
                love.graphics.setLineWidth(1)

                -- Joker name
                love.graphics.setColor(colors.text)
                love.graphics.setFont(UI.fonts.get(12))
                local name = item.name or "Joker"
                love.graphics.printf(name, x + 5, y + 50, cardW - 10, "center")
            else
                -- Draw playing card with actual card art
                local cardImage = Cards.getCardImage(item)

                if cardImage then
                    -- Draw card image scaled to card size
                    love.graphics.setColor(1, 1, 1)
                    local imgW = cardImage:getWidth()
                    local imgH = cardImage:getHeight()
                    local scaleX = cardW / imgW
                    local scaleY = cardH / imgH
                    local scale = math.min(scaleX, scaleY)
                    love.graphics.draw(cardImage, x, y, 0, scale, scale)

                    -- Rarity glow border
                    love.graphics.setColor(rarityColor)
                    love.graphics.setLineWidth(3)
                    love.graphics.rectangle("line", x, y, cardW, cardH, 8, 8)
                    love.graphics.setLineWidth(1)
                else
                    -- Fallback: Draw card manually if no image
                    local suitColor = Cards.suitColors[item.suit] or {0.3, 0.3, 0.3}
                    local suitSymbol = Cards.suitSymbols[item.suit] or "?"

                    -- Card background (white/cream)
                    love.graphics.setColor(0.95, 0.93, 0.88)
                    love.graphics.rectangle("fill", x, y, cardW, cardH, 8, 8)

                    -- Rarity glow border
                    love.graphics.setColor(rarityColor)
                    love.graphics.setLineWidth(3)
                    love.graphics.rectangle("line", x, y, cardW, cardH, 8, 8)
                    love.graphics.setLineWidth(1)

                    -- Rank in corner
                    love.graphics.setColor(suitColor)
                    love.graphics.setFont(UI.fonts.get(18))
                    love.graphics.print(item.rank or "?", x + 8, y + 5)

                    -- Suit symbol in corner
                    love.graphics.setFont(UI.fonts.get(14))
                    love.graphics.print(suitSymbol, x + 8, y + 24)

                    -- Large suit symbol in center
                    love.graphics.setFont(UI.fonts.get(48))
                    local symbolW = love.graphics.getFont():getWidth(suitSymbol)
                    love.graphics.print(suitSymbol, x + cardW/2 - symbolW/2, y + 45)

                    -- Rank at bottom right (upside down style)
                    love.graphics.setFont(UI.fonts.get(18))
                    love.graphics.print(item.rank or "?", x + cardW - 25, y + cardH - 28)
                end
            end

            -- Rarity label at bottom
            love.graphics.setColor(rarityColor)
            love.graphics.setFont(UI.fonts.get(10))
            local rarityW = love.graphics.getFont():getWidth(item.rarity:upper())
            love.graphics.print(item.rarity:upper(), x + cardW/2 - rarityW/2, y + cardH - 15)
        else
            -- Unrevealed card (back)
            CardRenderer.drawCardBack(x, y, cardW, cardH, {accentColor = colors.accent})
        end
    end
end

function LootBox.drawResults(screenW, screenH)
    -- Results display
    love.graphics.setColor(colors.accent)
    love.graphics.setFont(UI.fonts.get(32))
    local resultText = "You got:"
    local resultW = love.graphics.getFont():getWidth(resultText)
    love.graphics.print(resultText, screenW/2 - resultW/2, 80)

    -- Show all cards
    local cardW, cardH = 120, 170
    local spacing = 15

    -- Handle many cards by reducing size and wrapping
    local maxCardsPerRow = math.min(#revealedCards, math.floor((screenW - 100) / (cardW + spacing)))
    if #revealedCards > 10 then
        cardW, cardH = 100, 145
        spacing = 10
        maxCardsPerRow = math.min(#revealedCards, math.floor((screenW - 60) / (cardW + spacing)))
    end

    local rows = math.ceil(#revealedCards / maxCardsPerRow)
    local startY = 140

    for i, item in ipairs(revealedCards) do
        local row = math.floor((i-1) / maxCardsPerRow)
        local col = (i-1) % maxCardsPerRow
        local cardsInThisRow = math.min(maxCardsPerRow, #revealedCards - row * maxCardsPerRow)
        local rowWidth = cardsInThisRow * cardW + (cardsInThisRow - 1) * spacing
        local rowStartX = screenW/2 - rowWidth/2

        local x = rowStartX + col * (cardW + spacing)
        local y = startY + row * (cardH + 20)

        local rarityColor = colors[item.rarity] or colors.common

        -- Glow effect behind card
        love.graphics.setColor(rarityColor[1] * 0.3, rarityColor[2] * 0.3, rarityColor[3] * 0.3, 0.6)
        love.graphics.rectangle("fill", x - 4, y - 4, cardW + 8, cardH + 8, 12, 12)

        if item.isJoker then
            -- Joker card background
            love.graphics.setColor(rarityColor[1] * 0.4, rarityColor[2] * 0.4, rarityColor[3] * 0.4)
            love.graphics.rectangle("fill", x, y, cardW, cardH, 10, 10)

            love.graphics.setColor(rarityColor)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", x, y, cardW, cardH, 10, 10)
            love.graphics.setLineWidth(1)

            -- Joker label
            love.graphics.setColor(rarityColor)
            love.graphics.setFont(UI.fonts.get(12))
            love.graphics.printf("JOKER", x, y + 10, cardW, "center")

            -- Joker icon (jester hat style)
            love.graphics.setFont(UI.fonts.get(36))
            love.graphics.printf("J", x, y + 35, cardW, "center")

            -- Joker name
            love.graphics.setColor(colors.text)
            love.graphics.setFont(UI.fonts.get(11))
            love.graphics.printf(item.name or "Joker", x + 5, y + 85, cardW - 10, "center")

            -- Rarity
            love.graphics.setColor(rarityColor)
            love.graphics.setFont(UI.fonts.get(10))
            love.graphics.printf(item.rarity:upper(), x, y + cardH - 20, cardW, "center")
        else
            -- Playing card with actual card art
            local cardImage = Cards.getCardImage(item)

            if cardImage then
                -- Draw card image scaled to card size
                love.graphics.setColor(1, 1, 1)
                local imgW = cardImage:getWidth()
                local imgH = cardImage:getHeight()
                local scaleX = cardW / imgW
                local scaleY = cardH / imgH
                local scale = math.min(scaleX, scaleY)
                love.graphics.draw(cardImage, x, y, 0, scale, scale)

                -- Rarity glow border
                love.graphics.setColor(rarityColor)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", x, y, cardW, cardH, 10, 10)
                love.graphics.setLineWidth(1)
            else
                -- Fallback: Draw card manually if no image
                local suitColor = Cards.suitColors[item.suit] or {0.3, 0.3, 0.3}
                local suitSymbol = Cards.suitSymbols[item.suit] or "?"

                -- Card background (white/cream)
                love.graphics.setColor(0.97, 0.95, 0.90)
                love.graphics.rectangle("fill", x, y, cardW, cardH, 10, 10)

                -- Rarity glow border
                love.graphics.setColor(rarityColor)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", x, y, cardW, cardH, 10, 10)
                love.graphics.setLineWidth(1)

                -- Rank in top-left corner
                love.graphics.setColor(suitColor)
                love.graphics.setFont(UI.fonts.get(20))
                love.graphics.print(item.rank or "?", x + 8, y + 5)

                -- Suit symbol in top-left
                love.graphics.setFont(UI.fonts.get(16))
                love.graphics.print(suitSymbol, x + 8, y + 26)

                -- Large suit symbol(s) in center
                love.graphics.setFont(UI.fonts.get(42))
                local symbolW = love.graphics.getFont():getWidth(suitSymbol)
                love.graphics.print(suitSymbol, x + cardW/2 - symbolW/2, y + 50)

                -- Rank in bottom-right corner
                love.graphics.setFont(UI.fonts.get(20))
                local rankW = love.graphics.getFont():getWidth(item.rank or "?")
                love.graphics.print(item.rank or "?", x + cardW - rankW - 8, y + cardH - 48)

                -- Suit symbol in bottom-right
                love.graphics.setFont(UI.fonts.get(16))
                local symW = love.graphics.getFont():getWidth(suitSymbol)
                love.graphics.print(suitSymbol, x + cardW - symW - 8, y + cardH - 28)

                -- Ability indicator if present
                if item.ability and item.ability ~= "none" then
                    love.graphics.setColor(colors.accent)
                    love.graphics.setFont(UI.fonts.get(9))
                    local abilityName = Cards.abilities and Cards.abilities[item.ability] and Cards.abilities[item.ability].name or item.ability
                    love.graphics.printf(abilityName, x + 2, y + 105, cardW - 4, "center")
                end
            end

            -- Rarity label at very bottom
            love.graphics.setColor(rarityColor)
            love.graphics.setFont(UI.fonts.get(10))
            love.graphics.printf(item.rarity:upper(), x, y + cardH - 15, cardW, "center")
        end
    end

    -- Draw collect button
    if collectButton then
        collectButton:draw()
    end
end

function LootBox.mousepressed(x, y, button)
    if button ~= 1 then return end

    -- Handle UI button clicks
    if backButton and backButton:mousepressed(x, y, button) then
        return
    end

    if showingResults and collectButton and collectButton:mousepressed(x, y, button) then
        return
    end

    if openingPack or showingResults then
        return
    end

    -- Check pack clicks
    for _, pack in ipairs(LootBox.packs) do
        if pack._bounds then
            local b = pack._bounds
            if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
                if PlayerData.coins >= pack.cost then
                    LootBox.openPack(pack)
                end
                return
            end
        end
    end
end

function LootBox.mousereleased(x, y, button)
    if button ~= 1 then return end

    if backButton and backButton.mousereleased then
        backButton:mousereleased(x, y, button)
    end

    if collectButton and collectButton.mousereleased then
        collectButton:mousereleased(x, y, button)
    end
end

function LootBox.openPack(pack)
    -- Deduct cost
    PlayerData.coins = PlayerData.coins - pack.cost

    -- Generate cards
    revealedCards = {}
    revealIndex = 0
    openingPack = true
    openTimer = 0

    local guaranteedRareUsed = false
    local guaranteedEpicUsed = false

    for i = 1, pack.cardCount do
        local item

        -- Determine if this is a card or joker
        local isJoker = false
        if pack.type == "jokers" then
            isJoker = true
        elseif pack.type == "mixed" and i == pack.cardCount then
            isJoker = true  -- Last card is always a joker for mixed packs
        end

        -- Roll rarity
        local rarity = LootBox.rollRarity(pack.rarityWeights)

        -- Force rare if guaranteed and not yet used
        if pack.guaranteedRare and not guaranteedRareUsed and i == pack.cardCount then
            if rarity == "common" or rarity == "uncommon" then
                rarity = "rare"
            end
            guaranteedRareUsed = true
        end

        -- Force epic if guaranteed and not yet used
        if pack.guaranteedEpic and not guaranteedEpicUsed and i == pack.cardCount then
            if rarity == "common" or rarity == "uncommon" or rarity == "rare" then
                rarity = "epic"
            end
            guaranteedEpicUsed = true
        end

        if isJoker then
            item = LootBox.generateJoker(rarity)
            item.isJoker = true
        else
            item = LootBox.generateCard(rarity)
            item.isJoker = false
        end

        item.rarity = rarity
        table.insert(revealedCards, item)
    end
end

function LootBox.rollRarity(weights)
    local rarityOrder = {"common", "uncommon", "rare", "epic", "legendary"}
    local total = 0
    for _, rarity in ipairs(rarityOrder) do
        total = total + (weights[rarity] or 0)
    end

    local roll = math.random() * total
    local cumulative = 0

    for _, rarity in ipairs(rarityOrder) do
        cumulative = cumulative + (weights[rarity] or 0)
        if roll <= cumulative then
            return rarity
        end
    end

    return "common"
end

function LootBox.generateCard(rarity)
    local cardPool = {}

    -- Get cards from appropriate pool based on rarity
    if rarity == "common" then
        for _, card in ipairs(Cards.basicCards) do
            if card.rarity == "common" then
                table.insert(cardPool, card)
            end
        end
    else
        for _, card in ipairs(Cards.rareCards) do
            if card.rarity == rarity then
                table.insert(cardPool, card)
            end
        end
    end

    -- Fallback to basic cards if pool is empty
    if #cardPool == 0 then
        cardPool = Cards.basicCards
    end

    -- Pick random card
    local template = cardPool[math.random(#cardPool)]
    local card = Cards.copyCard(template)
    card.id = #PlayerData.collection + 1000 + math.random(10000)
    card.rarity = rarity

    return card
end

function LootBox.generateJoker(rarity)
    local jokerPool = {}

    for _, joker in ipairs(Jokers.jokerList) do
        if joker.rarity == rarity then
            table.insert(jokerPool, joker)
        end
    end

    -- Fallback to common jokers
    if #jokerPool == 0 then
        for _, joker in ipairs(Jokers.jokerList) do
            if joker.rarity == "common" then
                table.insert(jokerPool, joker)
            end
        end
    end

    -- Still empty? Use first joker
    if #jokerPool == 0 and #Jokers.jokerList > 0 then
        jokerPool = {Jokers.jokerList[1]}
    end

    if #jokerPool > 0 then
        local template = jokerPool[math.random(#jokerPool)]
        local joker = {}
        for k, v in pairs(template) do
            joker[k] = v
        end
        joker.instanceId = #PlayerData.collection + 2000 + math.random(10000)
        joker.rarity = rarity
        return joker
    end

    -- Fallback
    return {name = "Mystery Joker", rarity = rarity, effect = "Unknown"}
end

function LootBox.collectCards()
    for _, item in ipairs(revealedCards) do
        if item.isJoker then
            -- Add to joker collection
            if not PlayerData.jokerCollection then
                PlayerData.jokerCollection = {}
            end
            table.insert(PlayerData.jokerCollection, item)
        else
            -- Add to card collection
            table.insert(PlayerData.collection, {
                id = #PlayerData.collection + 1,
                cardId = item.id,
                card = item
            })
        end
    end

    -- Save
    savePlayerData()
end

-- Handle keyboard input
function LootBox.keypressed(key)
    if key == "escape" then
        if showingResults then
            showingResults = false
            revealedCards = {}
        else
            GameState.current = "menu"
        end
    end
end

-- Handle scroll wheel for pack selection
function LootBox.wheelmoved(x, y)
    if not showingResults and not openingPack then
        -- Scroll pack list
        packScrollY = packScrollY - y * 40  -- 40 pixels per scroll step
        packScrollY = math.max(0, math.min(packScrollY, maxPackScroll))
    end
end

return LootBox
