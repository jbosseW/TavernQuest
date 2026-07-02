-- collection_shop.lua
-- Shop tab: card/joker purchasing, shop refresh

local Cards = require("cards")
local Jokers = require("jokers")
local UI = require("ui")
local shared = require("collection_shared")

local Shop = {}

-- Refresh the shop inventory
function Shop.refreshShop()
    shared.shopCards = {}
    shared.shopJokers = {}

    -- Generate 8 random cards for sale
    for i = 1, 8 do
        local card
        local price

        local roll = math.random()
        if roll < 0.6 then
            card = Cards.copyCard(Cards.basicCards[math.random(#Cards.basicCards)])
            price = 10 + math.random(10)
        elseif roll < 0.9 then
            card = Cards.copyCard(Cards.rareCards[math.random(#Cards.rareCards)])
            price = 25 + math.random(25)
        else
            local epics = {}
            for _, c in ipairs(Cards.rareCards) do
                if c.rarity == "epic" or c.rarity == "legendary" then
                    table.insert(epics, c)
                end
            end
            if #epics > 0 then
                card = Cards.copyCard(epics[math.random(#epics)])
                price = 50 + math.random(50)
            else
                card = Cards.copyCard(Cards.rareCards[math.random(#Cards.rareCards)])
                price = 30 + math.random(20)
            end
        end

        table.insert(shared.shopCards, {card = card, price = price})
    end

    -- Generate 3 random jokers
    local ownedIds = {}
    if PlayerData.ownedJokers then
        for _, j in ipairs(PlayerData.ownedJokers) do
            table.insert(ownedIds, j.id)
        end
    end

    shared.shopJokers = Jokers.getRandomForShop(3, ownedIds)
end

-- Draw the shop tab (requires drawCollectionCard and drawJokerCard from main module)
function Shop.drawShopTab(drawCollectionCard, drawJokerCard)
    local layout = shared.layout
    local shopCards = shared.shopCards
    local shopJokers = shared.shopJokers
    local mx, my = love.mouse.getPosition()
    shared.hoveredCard = nil

    -- Refresh button
    love.graphics.setColor(0.4, 0.5, 0.6)
    love.graphics.rectangle("fill", layout.areaX + layout.areaWidth - 160, layout.areaY + 10, 140, 35, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.print(string.format("Refresh (%d)", shared.shopRefreshCost),
        layout.areaX + layout.areaWidth - 130, layout.areaY + 18)

    -- Cards section
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.setFont(UI.fonts.get(16))
    love.graphics.print("Cards:", layout.areaX + 20, layout.areaY + 15)

    local x, y = layout.areaX + 20, layout.areaY + 45
    local col = 0

    for i, shopItem in ipairs(shopCards) do
        local cardX = x + col * (layout.cardSpacing + 20)
        local cardY = y

        local hovered = mx >= cardX and mx <= cardX + layout.cardWidth and
                       my >= cardY and my <= cardY + layout.cardHeight + 30

        if hovered then
            shared.hoveredCard = {index = i, card = shopItem.card, type = "shop", price = shopItem.price}
        end

        -- Draw card using the passed-in function
        drawCollectionCard(shopItem.card, cardX, cardY, hovered, false)

        -- Price tag
        local canAfford = PlayerData.coins >= shopItem.price
        love.graphics.setColor(canAfford and {0.3, 0.7, 0.3} or {0.7, 0.3, 0.3})
        love.graphics.rectangle("fill", cardX, cardY + layout.cardHeight + 5, layout.cardWidth, 25, 4, 4)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.fonts.get(14))
        local priceText = string.format("%d coins", shopItem.price)
        local priceW = love.graphics.getFont():getWidth(priceText)
        love.graphics.print(priceText, cardX + layout.cardWidth/2 - priceW/2, cardY + layout.cardHeight + 9)

        col = col + 1
        if col >= 8 then
            col = 0
            y = y + layout.cardHeight + 60
        end
    end

    -- Jokers section
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.setFont(UI.fonts.get(16))
    love.graphics.print("Jokers:", layout.areaX + 20, layout.areaY + 220)

    local jx, jy = layout.areaX + 20, layout.areaY + 250
    for i, joker in ipairs(shopJokers) do
        local jokerX = jx + (i-1) * 130

        local hovered = mx >= jokerX and mx <= jokerX + 100 and
                       my >= jy and my <= jy + 150

        if hovered then
            shared.hoveredCard = {index = i, joker = joker, type = "shopJoker", price = joker.cost}
        end

        drawJokerCard(joker, jokerX, jy, hovered, false)

        -- Price tag
        local canAfford = PlayerData.coins >= joker.cost
        love.graphics.setColor(canAfford and {0.3, 0.7, 0.3} or {0.7, 0.3, 0.3})
        love.graphics.rectangle("fill", jokerX, jy + 125, 100, 25, 4, 4)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.fonts.get(12))
        love.graphics.print(joker.cost .. " coins", jokerX + 20, jy + 130)
    end
end

-- Handle shop refresh button click
function Shop.handleRefreshClick(x, y)
    local layout = shared.layout
    local refreshX = layout.areaX + layout.areaWidth - 160
    local refreshY = layout.areaY + 10
    if x >= refreshX and x <= refreshX + 140 and y >= refreshY and y <= refreshY + 35 then
        if PlayerData.coins >= shared.shopRefreshCost then
            PlayerData.coins = PlayerData.coins - shared.shopRefreshCost
            Shop.refreshShop()
            savePlayerData()
        end
        return true
    end
    return false
end

return Shop
