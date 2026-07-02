-- Comprehensive Stats Page - Track all game mode statistics

local StatsPage = {}
local UI = require("ui")

-- Stat categories with their icons
local CATEGORIES = {
    {id = "general", name = "General Stats", icon = "📊"},
    {id = "poker", name = "Poker Stats", icon = "🃏"},
    {id = "slots", name = "Slots Stats", icon = "🎰"},
    {id = "cafe", name = "Cafe Stats", icon = "☕"},
    {id = "market", name = "Market Stats", icon = "📈"},
    {id = "cards", name = "Trading Cards", icon = "🎴"},
    {id = "achievements", name = "Achievements", icon = "🏆"},
}

local state = {
    selectedCategory = "general",
    scroll = 0,
}

-- UI Components
local categoryTabs
local scrollContainer
local backButton

-- Initialize stats if they don't exist
local function ensureStats()
    if not PlayerData.gameStats then
        PlayerData.gameStats = {}
    end

    -- General stats
    if not PlayerData.gameStats.general then
        PlayerData.gameStats.general = {
            totalPlayTime = 0,
            sessionCount = 0,
            firstPlayed = os.time(),
            lastPlayed = os.time(),
        }
    end

    -- Poker stats
    if not PlayerData.gameStats.poker then
        PlayerData.gameStats.poker = {
            gamesPlayed = 0,
            gamesWon = 0,
            gamesLost = 0,
            totalChips = 0,
            totalMult = 0,
            handsPlayed = 0,
            bestHand = "None",
            bestHandScore = 0,
            highestRound = 0,
            perfectGames = 0,  -- Won without losing a round
            comebacks = 0,  -- Won after being behind
        }
    end

    -- Slots stats
    if not PlayerData.gameStats.slots then
        PlayerData.gameStats.slots = {
            totalSpins = 0,
            totalWagered = 0,
            totalWon = 0,
            biggestWin = 0,
            jackpots = 0,
            freeSpinsTriggered = 0,
            clustersFormed = 0,
            lineWins = 0,
        }
    end

    -- Cafe stats
    if not PlayerData.gameStats.cafe then
        PlayerData.gameStats.cafe = {
            daysWorked = 0,
            customersServed = 0,
            perfectOrders = 0,
            totalTips = 0,
            totalWages = 0,
            itemsPrepared = 0,
            customersLost = 0,
            bestDayEarnings = 0,
            upgradesPurchased = 0,
        }
    end

    -- Stock market stats
    if not PlayerData.gameStats.market then
        PlayerData.gameStats.market = {
            tradesExecuted = 0,
            totalBought = 0,
            totalSold = 0,
            biggestProfit = 0,
            biggestLoss = 0,
            daysTraded = 0,
            stocksOwned = 0,
            peakPortfolioValue = 0,
        }
    end

    -- Trading cards stats
    if not PlayerData.gameStats.cards then
        PlayerData.gameStats.cards = {
            packsOpened = 0,
            cardsCollected = 0,
            cardsSold = 0,
            uniqueCards = 0,
            mythicsFound = 0,
            legendariesFound = 0,
            foilsFound = 0,
            coinsFromSelling = 0,
        }
    end
end

-- Get formatted stat value
local function formatStat(value, type)
    if type == "number" then
        if value >= 1000000 then
            return string.format("%.1fM", value / 1000000)
        elseif value >= 1000 then
            return string.format("%.1fK", value / 1000)
        else
            return tostring(math.floor(value))
        end
    elseif type == "currency" then
        return string.format("%d coins", value)
    elseif type == "percent" then
        return string.format("%.1f%%", value * 100)
    elseif type == "time" then
        local hours = math.floor(value / 3600)
        local mins = math.floor((value % 3600) / 60)
        if hours > 0 then
            return string.format("%dh %dm", hours, mins)
        else
            return string.format("%dm", mins)
        end
    elseif type == "date" then
        return os.date("%Y-%m-%d", value)
    else
        return tostring(value)
    end
end

-- Forward declaration for getAchievements (defined below getStats)
local getAchievements

-- Get stats for a category
local function getStats(category)
    ensureStats()

    if category == "general" then
        local winRate = 0
        if PlayerData.wins + PlayerData.losses > 0 then
            winRate = PlayerData.wins / (PlayerData.wins + PlayerData.losses)
        end

        return {
            {name = "Total Coins", value = PlayerData.coins, type = "currency", color = {1, 0.9, 0.3}},
            {name = "Total Wins", value = PlayerData.wins, type = "number", color = {0.3, 0.8, 0.3}},
            {name = "Total Losses", value = PlayerData.losses, type = "number", color = {0.8, 0.3, 0.3}},
            {name = "Win Rate", value = winRate, type = "percent", color = {0.5, 0.7, 0.9}},
            {name = "Games Played", value = PlayerData.totalGamesPlayed or 0, type = "number"},
            {name = "Cards in Collection", value = #(PlayerData.collection or {}), type = "number"},
            {name = "Jokers Collected", value = #(PlayerData.jokerCollection or {}), type = "number"},
            {name = "Loot Boxes Opened", value = PlayerData.lootBoxesOpened or 0, type = "number"},
            {name = "Favorite Modes", value = #(PlayerData.favoriteModes or {}), type = "number"},
            {name = "First Played", value = PlayerData.gameStats.general.firstPlayed, type = "date"},
            {name = "Last Played", value = PlayerData.gameStats.general.lastPlayed, type = "date"},
        }
    elseif category == "poker" then
        local stats = PlayerData.gameStats.poker
        local winRate = 0
        if stats.gamesPlayed > 0 then
            winRate = stats.gamesWon / stats.gamesPlayed
        end

        return {
            {name = "Games Played", value = stats.gamesPlayed, type = "number"},
            {name = "Games Won", value = stats.gamesWon, type = "number", color = {0.3, 0.8, 0.3}},
            {name = "Games Lost", value = stats.gamesLost, type = "number", color = {0.8, 0.3, 0.3}},
            {name = "Win Rate", value = winRate, type = "percent", color = {0.5, 0.7, 0.9}},
            {name = "Total Chips Scored", value = stats.totalChips, type = "number", color = {0.3, 0.6, 0.9}},
            {name = "Total Mult Earned", value = stats.totalMult, type = "number", color = {0.9, 0.5, 0.3}},
            {name = "Hands Played", value = stats.handsPlayed, type = "number"},
            {name = "Best Hand", value = stats.bestHand, type = "string", color = {0.9, 0.7, 0.2}},
            {name = "Best Hand Score", value = stats.bestHandScore, type = "number", color = {0.9, 0.7, 0.2}},
            {name = "Highest Round", value = stats.highestRound, type = "number"},
            {name = "Perfect Games", value = stats.perfectGames, type = "number", color = {0.9, 0.8, 0.3}},
            {name = "Comebacks", value = stats.comebacks, type = "number", color = {0.8, 0.5, 0.9}},
        }
    elseif category == "slots" then
        local stats = PlayerData.gameStats.slots
        local netProfit = stats.totalWon - stats.totalWagered
        local rtp = 0
        if stats.totalWagered > 0 then
            rtp = stats.totalWon / stats.totalWagered
        end

        return {
            {name = "Total Spins", value = stats.totalSpins, type = "number"},
            {name = "Total Wagered", value = stats.totalWagered, type = "currency"},
            {name = "Total Won", value = stats.totalWon, type = "currency", color = {0.3, 0.8, 0.3}},
            {name = "Net Profit/Loss", value = netProfit, type = "currency", color = netProfit >= 0 and {0.3, 0.8, 0.3} or {0.8, 0.3, 0.3}},
            {name = "RTP", value = rtp, type = "percent"},
            {name = "Biggest Win", value = stats.biggestWin, type = "currency", color = {0.9, 0.7, 0.2}},
            {name = "Jackpots Hit", value = stats.jackpots, type = "number", color = {0.9, 0.3, 0.5}},
            {name = "Free Spins Triggered", value = stats.freeSpinsTriggered, type = "number"},
            {name = "Clusters Formed", value = stats.clustersFormed, type = "number"},
            {name = "Line Wins", value = stats.lineWins, type = "number"},
        }
    elseif category == "cafe" then
        local stats = PlayerData.gameStats.cafe
        local avgTips = 0
        if stats.daysWorked > 0 then
            avgTips = stats.totalTips / stats.daysWorked
        end
        local perfectRate = 0
        if stats.customersServed > 0 then
            perfectRate = stats.perfectOrders / stats.customersServed
        end

        return {
            {name = "Days Worked", value = stats.daysWorked, type = "number"},
            {name = "Customers Served", value = stats.customersServed, type = "number"},
            {name = "Perfect Orders", value = stats.perfectOrders, type = "number", color = {0.3, 0.8, 0.3}},
            {name = "Perfect Order Rate", value = perfectRate, type = "percent"},
            {name = "Customers Lost", value = stats.customersLost, type = "number", color = {0.8, 0.3, 0.3}},
            {name = "Total Tips", value = stats.totalTips, type = "currency", color = {0.3, 0.8, 0.3}},
            {name = "Total Wages", value = stats.totalWages, type = "currency"},
            {name = "Average Tips/Day", value = avgTips, type = "currency"},
            {name = "Best Day Earnings", value = stats.bestDayEarnings, type = "currency", color = {0.9, 0.7, 0.2}},
            {name = "Items Prepared", value = stats.itemsPrepared, type = "number"},
            {name = "Upgrades Purchased", value = stats.upgradesPurchased, type = "number"},
        }
    elseif category == "market" then
        local stats = PlayerData.gameStats.market
        local netGain = stats.totalSold - stats.totalBought

        return {
            {name = "Trades Executed", value = stats.tradesExecuted, type = "number"},
            {name = "Days Traded", value = stats.daysTraded, type = "number"},
            {name = "Total Bought", value = stats.totalBought, type = "currency"},
            {name = "Total Sold", value = stats.totalSold, type = "currency"},
            {name = "Net Gain/Loss", value = netGain, type = "currency", color = netGain >= 0 and {0.3, 0.8, 0.3} or {0.8, 0.3, 0.3}},
            {name = "Biggest Profit", value = stats.biggestProfit, type = "currency", color = {0.3, 0.8, 0.3}},
            {name = "Biggest Loss", value = stats.biggestLoss, type = "currency", color = {0.8, 0.3, 0.3}},
            {name = "Peak Portfolio Value", value = stats.peakPortfolioValue, type = "currency", color = {0.9, 0.7, 0.2}},
            {name = "Stocks Currently Owned", value = stats.stocksOwned, type = "number"},
        }
    elseif category == "cards" then
        local stats = PlayerData.gameStats.cards
        local tradingCards = PlayerData.tradingCards or {}

        return {
            {name = "Packs Opened", value = tradingCards.packsPurchased or stats.packsOpened, type = "number"},
            {name = "Cards Collected", value = tradingCards.totalCardsCollected or stats.cardsCollected, type = "number"},
            {name = "Cards in Collection", value = #(tradingCards.collection or {}), type = "number"},
            {name = "Cards Sold", value = stats.cardsSold, type = "number"},
            {name = "Unique Cards", value = stats.uniqueCards, type = "number"},
            {name = "Mythics Found", value = stats.mythicsFound, type = "number", color = {0.9, 0.3, 0.5}},
            {name = "Legendaries Found", value = stats.legendariesFound, type = "number", color = {0.9, 0.7, 0.2}},
            {name = "Foils Found", value = stats.foilsFound, type = "number", color = {0.8, 0.8, 0.9}},
            {name = "Coins from Selling", value = stats.coinsFromSelling, type = "currency"},
        }
    elseif category == "achievements" then
        return getAchievements()
    end

    return {}
end

-- Get achievements
getAchievements = function()
    local achievements = {}

    -- General achievements
    table.insert(achievements, {
        name = "First Steps",
        desc = "Win your first game",
        unlocked = PlayerData.wins >= 1,
        icon = "🎯"
    })
    table.insert(achievements, {
        name = "Getting Started",
        desc = "Win 10 games",
        unlocked = PlayerData.wins >= 10,
        icon = "🌟"
    })
    table.insert(achievements, {
        name = "Veteran",
        desc = "Win 50 games",
        unlocked = PlayerData.wins >= 50,
        icon = "⭐"
    })
    table.insert(achievements, {
        name = "Master",
        desc = "Win 100 games",
        unlocked = PlayerData.wins >= 100,
        icon = "👑"
    })
    table.insert(achievements, {
        name = "Rich",
        desc = "Have 10,000 coins",
        unlocked = PlayerData.coins >= 10000,
        icon = "💰"
    })
    table.insert(achievements, {
        name = "Wealthy",
        desc = "Have 100,000 coins",
        unlocked = PlayerData.coins >= 100000,
        icon = "💎"
    })
    table.insert(achievements, {
        name = "Collector",
        desc = "Collect 100 cards",
        unlocked = #(PlayerData.collection or {}) >= 100,
        icon = "🃏"
    })
    table.insert(achievements, {
        name = "Joker Fan",
        desc = "Collect 10 jokers",
        unlocked = #(PlayerData.jokerCollection or {}) >= 10,
        icon = "🤡"
    })

    -- Mode-specific achievements
    ensureStats()

    table.insert(achievements, {
        name = "High Roller",
        desc = "Win 10,000 in slots",
        unlocked = (PlayerData.gameStats.slots.totalWon or 0) >= 10000,
        icon = "🎰"
    })
    table.insert(achievements, {
        name = "Jackpot!",
        desc = "Hit a jackpot in slots",
        unlocked = (PlayerData.gameStats.slots.jackpots or 0) >= 1,
        icon = "🎊"
    })
    table.insert(achievements, {
        name = "Barista",
        desc = "Serve 100 customers in cafe",
        unlocked = (PlayerData.gameStats.cafe.customersServed or 0) >= 100,
        icon = "☕"
    })
    table.insert(achievements, {
        name = "Perfect Service",
        desc = "Get 50 perfect orders",
        unlocked = (PlayerData.gameStats.cafe.perfectOrders or 0) >= 50,
        icon = "✨"
    })
    table.insert(achievements, {
        name = "Day Trader",
        desc = "Execute 100 trades",
        unlocked = (PlayerData.gameStats.market.tradesExecuted or 0) >= 100,
        icon = "📈"
    })
    table.insert(achievements, {
        name = "Lucky Find",
        desc = "Find a mythic card",
        unlocked = (PlayerData.gameStats.cards.mythicsFound or 0) >= 1,
        icon = "🎴"
    })

    return achievements
end

function StatsPage.init()
    ensureStats()
    state.selectedCategory = "general"
    state.scroll = 0

    -- Update last played
    PlayerData.gameStats.general.lastPlayed = os.time()
    savePlayerData()

    -- Initialize UI components
    local screenW, screenH = love.graphics.getDimensions()

    -- Create category tabs
    local tabs = {}
    for _, cat in ipairs(CATEGORIES) do
        table.insert(tabs, {id = cat.id, label = cat.icon .. " " .. cat.name})
    end

    categoryTabs = UI.TabBar.new({
        x = 20,
        y = 80,
        w = 160,
        tabs = tabs,
        activeTab = state.selectedCategory,
        onChange = function(tabId)
            state.selectedCategory = tabId
            state.scroll = 0
        end
    })

    -- Create back button
    backButton = UI.Button.new({
        x = 20,
        y = screenH - 55,
        w = 100,
        h = 40,
        text = "Back",
        variant = "danger",
        onClick = function()
            local TextRPG = require("textrpg")
            TextRPG.init()
            GameState.current = "textrpg"
        end
    })
end

function StatsPage.update(dt)
    UI.anim.update(dt)
end

function StatsPage.draw()
    local screenW, screenH = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()

    -- Background
    love.graphics.setColor(0.08, 0.08, 0.12)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Header
    love.graphics.setColor(0.12, 0.12, 0.18)
    love.graphics.rectangle("fill", 0, 0, screenW, 60)

    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(UI.fonts.get(28))
    love.graphics.print("STATISTICS", 20, 15)

    -- Draw category tabs
    categoryTabs.y = 80
    categoryTabs:draw(mx, my)

    -- Stats content area
    local contentX = 200
    local contentY = 80
    local contentW = screenW - contentX - 40
    local contentH = screenH - contentY - 70

    love.graphics.setColor(0.12, 0.12, 0.16)
    love.graphics.rectangle("fill", contentX, contentY, contentW, contentH, 10, 10)

    -- Get current category
    local currentCat = nil
    for _, cat in ipairs(CATEGORIES) do
        if cat.id == state.selectedCategory then
            currentCat = cat
            break
        end
    end

    if currentCat then
        -- Category title
        love.graphics.setColor(0.9, 0.7, 0.2)
        love.graphics.setFont(UI.fonts.get(22))
        love.graphics.print(currentCat.icon .. " " .. currentCat.name, contentX + 20, contentY + 15)

        -- Stats list
        local stats = getStats(state.selectedCategory)
        local statY = contentY + 60
        local statH = 45

        love.graphics.setScissor(contentX, contentY + 55, contentW, contentH - 65)

        if state.selectedCategory == "achievements" then
            -- Draw achievements grid
            local achW = 280
            local achH = 70
            local cols = math.floor((contentW - 40) / (achW + 15))
            if cols < 1 then cols = 1 end

            for i, ach in ipairs(stats) do
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)
                local achX = contentX + 20 + col * (achW + 15)
                local achY = statY + row * (achH + 10) - state.scroll

                if achY + achH >= contentY + 55 and achY <= contentY + contentH then
                    -- Background
                    if ach.unlocked then
                        love.graphics.setColor(0.2, 0.35, 0.25)
                    else
                        love.graphics.setColor(0.18, 0.18, 0.22)
                    end
                    love.graphics.rectangle("fill", achX, achY, achW, achH, 8, 8)

                    -- Border
                    if ach.unlocked then
                        love.graphics.setColor(0.3, 0.7, 0.4)
                    else
                        love.graphics.setColor(0.3, 0.3, 0.35)
                    end
                    love.graphics.rectangle("line", achX, achY, achW, achH, 8, 8)

                    -- Icon
                    love.graphics.setFont(UI.fonts.get(28))
                    love.graphics.setColor(1, 1, 1, ach.unlocked and 1 or 0.3)
                    love.graphics.print(ach.icon, achX + 12, achY + 18)

                    -- Name
                    love.graphics.setFont(UI.fonts.get(14))
                    love.graphics.setColor(1, 1, 1, ach.unlocked and 1 or 0.5)
                    love.graphics.print(ach.name, achX + 55, achY + 12)

                    -- Description
                    love.graphics.setFont(UI.fonts.get(11))
                    love.graphics.setColor(0.7, 0.7, 0.7, ach.unlocked and 1 or 0.4)
                    love.graphics.print(ach.desc, achX + 55, achY + 32)

                    -- Unlocked indicator
                    if ach.unlocked then
                        love.graphics.setColor(0.3, 0.8, 0.4)
                        love.graphics.setFont(UI.fonts.get(12))
                        love.graphics.print("✓", achX + achW - 25, achY + 25)
                    else
                        love.graphics.setColor(0.5, 0.5, 0.5)
                        love.graphics.setFont(UI.fonts.get(12))
                        love.graphics.print("🔒", achX + achW - 25, achY + 25)
                    end
                end
            end
        else
            -- Draw regular stats
            for i, stat in ipairs(stats) do
                local sy = statY + (i - 1) * statH - state.scroll

                if sy + statH >= contentY + 55 and sy <= contentY + contentH then
                    -- Alternating row background
                    if i % 2 == 0 then
                        love.graphics.setColor(0.1, 0.1, 0.14)
                        love.graphics.rectangle("fill", contentX + 15, sy, contentW - 30, statH - 5, 4, 4)
                    end

                    -- Stat name
                    love.graphics.setColor(0.8, 0.8, 0.85)
                    love.graphics.setFont(UI.fonts.get(15))
                    love.graphics.print(stat.name, contentX + 25, sy + 12)

                    -- Stat value
                    local valueStr = formatStat(stat.value, stat.type)
                    local valueColor = stat.color or {1, 1, 1}
                    love.graphics.setColor(valueColor)
                    love.graphics.setFont(UI.fonts.get(16))
                    love.graphics.printf(valueStr, contentX + 25, sy + 12, contentW - 60, "right")
                end
            end
        end

        love.graphics.setScissor()

        -- Scroll indicator
        local totalItems = #stats
        local visibleItems = math.floor((contentH - 65) / (state.selectedCategory == "achievements" and 80 or 45))
        if totalItems > visibleItems then
            local scrollBarH = math.max(30, (visibleItems / totalItems) * (contentH - 70))
            local maxScroll = (totalItems - visibleItems) * (state.selectedCategory == "achievements" and 80 or 45)
            local scrollBarY = contentY + 55 + (state.scroll / math.max(1, maxScroll)) * (contentH - 70 - scrollBarH)

            love.graphics.setColor(0.25, 0.25, 0.3)
            love.graphics.rectangle("fill", contentX + contentW - 15, contentY + 55, 8, contentH - 70, 4, 4)
            love.graphics.setColor(0.5, 0.6, 0.8)
            love.graphics.rectangle("fill", contentX + contentW - 15, scrollBarY, 8, scrollBarH, 4, 4)
        end
    end

    -- Back button
    backButton.y = screenH - 55
    backButton:draw()

    -- Achievement count
    local achievements = getAchievements()
    local unlockedCount = 0
    for _, ach in ipairs(achievements) do
        if ach.unlocked then unlockedCount = unlockedCount + 1 end
    end

    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.printf(string.format("Achievements: %d/%d", unlockedCount, #achievements),
        screenW - 180, screenH - 40, 160, "right")
end

function StatsPage.mousepressed(x, y, button)
    if button ~= 1 then return end

    local screenW, screenH = love.graphics.getDimensions()

    -- Back button
    if backButton then
        if backButton:mousepressed(x, y, button) then return end
    end

    -- Category tabs
    if categoryTabs then
        categoryTabs:mousepressed(x, y, button)
    end
end

function StatsPage.mousereleased(x, y, button)
    if backButton then
        backButton:mousereleased(x, y, button)
    end
end

function StatsPage.wheelmoved(wx, wy)
    local stats = getStats(state.selectedCategory)
    local screenW, screenH = love.graphics.getDimensions()
    local contentH = screenH - 150

    local itemH = state.selectedCategory == "achievements" and 80 or 45
    local totalItems = #stats
    local visibleItems = math.floor(contentH / itemH)
    local maxScroll = math.max(0, (totalItems - visibleItems) * itemH)

    state.scroll = state.scroll - wy * 40
    state.scroll = math.max(0, math.min(state.scroll, maxScroll))
end

function StatsPage.keypressed(key)
    if key == "escape" then
        local TextRPG = require("textrpg")
        TextRPG.init()
        GameState.current = "textrpg"
    end
end

-- Helper function to update stats from other modules
function StatsPage.updateStat(category, stat, value, operation)
    ensureStats()

    if not PlayerData.gameStats[category] then return end
    if not PlayerData.gameStats[category][stat] then
        PlayerData.gameStats[category][stat] = 0
    end

    if operation == "add" then
        PlayerData.gameStats[category][stat] = PlayerData.gameStats[category][stat] + value
    elseif operation == "set" then
        PlayerData.gameStats[category][stat] = value
    elseif operation == "max" then
        PlayerData.gameStats[category][stat] = math.max(PlayerData.gameStats[category][stat], value)
    end

    savePlayerData()
end

return StatsPage
