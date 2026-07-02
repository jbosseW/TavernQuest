-- Tutorial / Help Screen
-- Explains gameplay, tips, and game systems

local Tutorial = {}

-- Font cache for performance
local FontCache = require("fontcache")
local function getFont(size)
    return FontCache.get(size)
end

-- Tutorial state
local state = {
    currentPage = 1,
    totalPages = 5,
    scrollY = 0,
}

-- Colors
local colors = {
    bg = {0.08, 0.08, 0.12},
    panel = {0.12, 0.12, 0.18},
    accent = {0.9, 0.6, 0.2},
    text = {1, 1, 1},
    subtitle = {0.7, 0.7, 0.7},
    highlight = {0.4, 0.8, 0.4},
    warning = {0.9, 0.7, 0.2},
    tip = {0.3, 0.7, 0.9},
}

-- Tutorial pages content
local pages = {
    {
        title = "Welcome to Tavern Quest!",
        sections = {
            {
                header = "What is this game?",
                content = [[Tavern Quest is a poker-roguelike card game! You'll build a deck of cards, play poker hands for points, and try to beat increasingly difficult score targets.

The game combines classic poker hand rankings with special card abilities, jokers, and strategic deck-building.]],
            },
            {
                header = "Your Goal",
                content = [[Each round, you must reach a target score by playing poker hands. You have a limited number of hands to play and discards to use.

If you reach the target score before running out of hands, you win the round and advance! The targets get higher each round, so you'll need to improve your deck along the way.]],
            },
            {
                header = "Getting Started",
                content = [[1. First, visit the LOOT BOXES to open some card packs
2. Then go to DECK BUILDER to build a deck (minimum 30 cards)
3. Finally, hit PLAY VS AI to start your first match!

Don't worry about building a perfect deck right away - you can always improve it as you earn more coins.]],
            },
        }
    },
    {
        title = "How to Play Poker Hands",
        sections = {
            {
                header = "Basic Gameplay",
                content = [[During each hand, you'll see cards from your deck. Select cards to form a poker hand, then click PLAY to score points.

You can also DISCARD cards you don't want - they'll be replaced with new cards from your deck. Use discards wisely to fish for better combinations!]],
            },
            {
                header = "Poker Hand Rankings (Low to High)",
                content = [[- High Card: No matching cards (lowest)
- Pair: Two cards of same rank
- Two Pair: Two different pairs
- Three of a Kind: Three matching cards
- Straight: Five cards in sequence
- Flush: Five cards of same suit
- Full House: Three of a kind + a pair
- Four of a Kind: Four matching cards
- Straight Flush: Straight + Flush combined
- Royal Flush: A-K-Q-J-10 of same suit (highest)]],
            },
            {
                header = "Scoring System",
                content = [[Each hand has a BASE score and a MULTIPLIER:
- Better hands have higher base scores
- Card values add to the base (face cards = 10, Aces = 11)
- The multiplier increases with hand quality

FINAL SCORE = (Base + Card Values) x Multiplier

Special cards and jokers can boost both base and multiplier!]],
            },
        }
    },
    {
        title = "Building Your Deck",
        sections = {
            {
                header = "TIP: Start with Bulk Commons!",
                content = [[When you're starting out, spend your coins on BULK COMMON packs in the Loot Boxes. Here's why:

- Commons are cheap but still useful
- You need 40+ cards for a deck
- More cards = more consistency
- You can upgrade later with better cards

Don't chase rare cards early - build a solid foundation first!]],
                highlight = true,
            },
            {
                header = "Card Rarity",
                content = [[Cards come in different rarities:
- COMMON (Gray): Basic cards, easy to get
- UNCOMMON (Green): Slightly better stats
- RARE (Blue): Good abilities
- EPIC (Purple): Strong effects
- LEGENDARY (Orange): Powerful game-changers
- MYTHIC (Red): Extremely rare and powerful

Higher rarity cards have better stats and special abilities that trigger during play.]],
            },
            {
                header = "Deck Strategy",
                content = [[- Focus on ONE or TWO hand types you want to build
- Include cards that synergize together
- Don't make your deck too large (40-50 cards is good)
- Remove weak cards as you get better ones
- Balance between high-value cards and combo enablers]],
            },
        }
    },
    {
        title = "The Wage Job & Economy",
        sections = {
            {
                header = "Why Work the Wage Job?",
                content = [[The WAGE JOB (Cafe) is your reliable income source! Work there to:

- Earn steady coins for card packs
- Get tips from satisfied customers
- Build up savings for expensive purchases
- Fund your other activities and hobbies

Think of it as your day job while you build your card empire!]],
                highlight = true,
            },
            {
                header = "How the Cafe Works",
                content = [[At the cafe, you'll:
1. Take customer orders
2. Prepare their drinks/food
3. Serve them before they get impatient
4. Collect tips and wages at the end of each day

Better service = bigger tips! Upgrade your skills to serve faster and earn more.]],
            },
            {
                header = "Managing Your Economy",
                content = [[Your coins are used for:
- Opening loot boxes (card packs)
- Buying items in various shops
- Unlocking new game modes

The wage job provides steady income, while poker wins and other activities can give big payouts. Balance risk and reward!]],
            },
        }
    },
    {
        title = "Game Modes & Progression",
        sections = {
            {
                header = "Unlocking Content",
                content = [[As you win poker matches, you'll unlock new game modes! Each mode offers different gameplay:

- POKER MODES: Different rule variations
- ROGUELIKE: Build decks during the run
- SIMULATION: Idle games, farming, etc.
- MINIGAMES: Fishing, slots, creature cards
- ACTION: Survivor-style games]],
            },
            {
                header = "Recommended Path",
                content = [[1. Open loot boxes to get starting cards
2. Build your first deck in Deck Builder
3. Win some Standard matches
4. Work the Wage Job when low on coins
5. Try new modes as you unlock them
6. Experiment with different strategies!]],
            },
            {
                header = "Other Activities",
                content = [[Beyond poker, you can:
- FISHING: Catch fish and sell them
- FORGE: Craft weapons and armor
- HUNTING: Track and hunt wild game
- PET PARADISE: Adopt and raise pets
- STOCK MARKET: Trade virtual stocks
- CREATURE CARDS: Collect monster cards

Each activity has its own rewards and progression!]],
            },
        }
    },
}

function Tutorial.init()
    state.currentPage = 1
    state.scrollY = 0
end

function Tutorial.update(dt)
    -- Nothing to update currently
end

function Tutorial.draw()
    local screenW, screenH = love.graphics.getDimensions()

    -- Background
    love.graphics.setColor(colors.bg)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Main panel
    local panelW = math.min(800, screenW - 60)
    local panelH = screenH - 100
    local panelX = screenW/2 - panelW/2
    local panelY = 50

    love.graphics.setColor(colors.panel)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 12, 12)
    love.graphics.setColor(colors.accent)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 12, 12)
    love.graphics.setLineWidth(1)

    -- Page title
    local page = pages[state.currentPage]
    love.graphics.setColor(colors.accent)
    love.graphics.setFont(getFont(28))
    love.graphics.printf(page.title, panelX, panelY + 15, panelW, "center")

    -- Page indicator
    love.graphics.setColor(colors.subtitle)
    love.graphics.setFont(getFont(14))
    love.graphics.printf("Page " .. state.currentPage .. " of " .. state.totalPages,
        panelX, panelY + 50, panelW, "center")

    -- Content area with scrolling
    local contentX = panelX + 30
    local contentY = panelY + 80
    local contentW = panelW - 60
    local contentH = panelH - 150

    -- Set scissor for content area
    love.graphics.setScissor(contentX, contentY, contentW, contentH)

    local y = contentY - state.scrollY

    for _, section in ipairs(page.sections) do
        -- Section header
        if section.highlight then
            -- Highlighted tip box
            love.graphics.setColor(0.2, 0.35, 0.25)
            love.graphics.rectangle("fill", contentX, y, contentW, 20, 5, 5)
        end

        love.graphics.setColor(section.highlight and colors.highlight or colors.accent)
        love.graphics.setFont(getFont(18))
        love.graphics.print(section.header, contentX + 10, y)
        y = y + 28

        -- Section content
        love.graphics.setColor(colors.text)
        love.graphics.setFont(getFont(14))

        local _, wrappedText = love.graphics.getFont():getWrap(section.content, contentW - 20)
        for _, line in ipairs(wrappedText) do
            love.graphics.print(line, contentX + 10, y)
            y = y + 20
        end

        y = y + 20  -- Gap between sections
    end

    love.graphics.setScissor()

    -- Calculate total content height for scrollbar
    local totalContentHeight = y - contentY + state.scrollY
    local maxScroll = math.max(0, totalContentHeight - contentH)
    if maxScroll > 0 then
        local scrollbarX = contentX + contentW - 8
        local scrollbarH = contentH
        local thumbH = math.max(30, scrollbarH * (contentH / totalContentHeight))
        local thumbY = contentY + (state.scrollY / maxScroll) * (scrollbarH - thumbH)
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", scrollbarX, contentY, 6, scrollbarH, 3, 3)
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.rectangle("fill", scrollbarX, thumbY, 6, thumbH, 3, 3)
    end

    -- Navigation buttons
    local btnW, btnH = 120, 40
    local btnY = panelY + panelH - 55
    local mx, my = love.mouse.getPosition()

    -- Previous button
    if state.currentPage > 1 then
        local prevX = panelX + 30
        local prevHover = mx >= prevX and mx <= prevX + btnW and my >= btnY and my <= btnY + btnH

        love.graphics.setColor(prevHover and {0.35, 0.45, 0.6} or {0.25, 0.35, 0.5})
        love.graphics.rectangle("fill", prevX, btnY, btnW, btnH, 6, 6)
        love.graphics.setColor(colors.text)
        love.graphics.setFont(getFont(16))
        love.graphics.printf("< Previous", prevX, btnY + 11, btnW, "center")
    end

    -- Next button
    if state.currentPage < state.totalPages then
        local nextX = panelX + panelW - btnW - 30
        local nextHover = mx >= nextX and mx <= nextX + btnW and my >= btnY and my <= btnY + btnH

        love.graphics.setColor(nextHover and {0.35, 0.55, 0.45} or {0.25, 0.45, 0.35})
        love.graphics.rectangle("fill", nextX, btnY, btnW, btnH, 6, 6)
        love.graphics.setColor(colors.text)
        love.graphics.setFont(getFont(16))
        love.graphics.printf("Next >", nextX, btnY + 11, btnW, "center")
    end

    -- Back to Menu button (center)
    local backW = 140
    local backX = panelX + panelW/2 - backW/2
    local backHover = mx >= backX and mx <= backX + backW and my >= btnY and my <= btnY + btnH

    love.graphics.setColor(backHover and {0.5, 0.35, 0.35} or {0.4, 0.25, 0.25})
    love.graphics.rectangle("fill", backX, btnY, backW, btnH, 6, 6)
    love.graphics.setColor(colors.text)
    love.graphics.setFont(getFont(16))
    love.graphics.printf("Back to Menu", backX, btnY + 11, backW, "center")

    -- Keyboard hints
    love.graphics.setColor(colors.subtitle)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("[LEFT/RIGHT] Navigate pages  |  [ESC] Return to menu  |  [UP/DOWN] Scroll",
        0, screenH - 25, screenW, "center")
end

function Tutorial.mousepressed(x, y, button)
    if button ~= 1 then return end

    local screenW, screenH = love.graphics.getDimensions()
    local panelW = math.min(800, screenW - 60)
    local panelH = screenH - 100
    local panelX = screenW/2 - panelW/2
    local panelY = 50

    local btnW, btnH = 120, 40
    local btnY = panelY + panelH - 55

    -- Previous button
    if state.currentPage > 1 then
        local prevX = panelX + 30
        if x >= prevX and x <= prevX + btnW and y >= btnY and y <= btnY + btnH then
            state.currentPage = state.currentPage - 1
            state.scrollY = 0
            return
        end
    end

    -- Next button
    if state.currentPage < state.totalPages then
        local nextX = panelX + panelW - btnW - 30
        if x >= nextX and x <= nextX + btnW and y >= btnY and y <= btnY + btnH then
            state.currentPage = state.currentPage + 1
            state.scrollY = 0
            return
        end
    end

    -- Back button
    local backW = 140
    local backX = panelX + panelW/2 - backW/2
    if x >= backX and x <= backX + backW and y >= btnY and y <= btnY + btnH then
        GameState.current = "menu"
        return
    end
end

function Tutorial.keypressed(key)
    if key == "escape" then
        GameState.current = "menu"
        return true
    elseif key == "left" then
        if state.currentPage > 1 then
            state.currentPage = state.currentPage - 1
            state.scrollY = 0
        end
        return true
    elseif key == "right" then
        if state.currentPage < state.totalPages then
            state.currentPage = state.currentPage + 1
            state.scrollY = 0
        end
        return true
    elseif key == "up" then
        state.scrollY = math.max(0, state.scrollY - 30)
        return true
    elseif key == "down" then
        state.scrollY = state.scrollY + 30
        return true
    end
    return false
end

function Tutorial.wheelmoved(x, y)
    state.scrollY = math.max(0, state.scrollY - y * 40)
end

function Tutorial.isActive()
    return GameState.current == "tutorial"
end

return Tutorial
