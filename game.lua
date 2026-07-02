-- Core game logic - poker battles
-- State machine, game flow, input handling
-- Delegates hand evaluation to poker_hands.lua and rendering to game_ui.lua

local Game = {}
local Cards = require("cards")
local AI = require("cardgame_ai")
local Jokers = require("jokers")
local UIAssets = require("uiassets")
local UI = require("ui")  -- Used by StoryMode subsection
local PokerHands = require("poker_hands")
local GameUI = require("game_ui")

-- Font cache for performance
local FontCache = require("fontcache")
local function getFont(size)
    return FontCache.get(size)
end

-- Game constants (can be modified by game mode)
local HAND_SIZE = 8
local MAX_HANDS = 4
local MAX_DISCARDS = 3
local CARDS_TO_PLAY = 5

-- Game mode settings
Game.modes = {
    standard = {
        name = "Standard",
        maxRounds = 3,
        startingHands = 4,
        startingDiscards = 3,
        targetScoreBase = 300,
        targetScoreIncrease = 150,
        description = "Classic 3-round battle"
    },
    extended = {
        name = "Extended",
        maxRounds = 5,
        startingHands = 5,
        startingDiscards = 4,
        targetScoreBase = 250,
        targetScoreIncrease = 100,
        description = "5 rounds with more resources"
    },
    marathon = {
        name = "Marathon",
        maxRounds = 999,
        startingHands = 4,
        startingDiscards = 3,
        targetScoreBase = 200,
        targetScoreIncrease = 50,
        bossEvery = 5,
        description = "Endless mode with bosses every 5 rounds"
    },
    blitz = {
        name = "Blitz",
        maxRounds = 3,
        startingHands = 2,
        startingDiscards = 1,
        targetScoreBase = 200,
        targetScoreIncrease = 100,
        description = "Fast mode with limited hands"
    },
    purist = {
        name = "Purist",
        maxRounds = 999,
        startingHands = 4,
        startingDiscards = 3,
        targetScoreBase = 150,
        targetScoreIncrease = 30,
        description = "Roguelike - build your deck during the run!",
        deckBuilding = true,
        starterDeckSize = 20
    }
}

-- Boss definitions for marathon mode
Game.bosses = {
    {name = "The Wall", effect = "Target score +100", modifier = function(gs) gs.targetScore = gs.targetScore + 100 end},
    {name = "The Miser", effect = "No coins this round", modifier = function(gs) gs.noCoins = true end},
    {name = "The Thief", effect = "Start with 1 less hand", modifier = function(gs) gs.handsLeft = gs.handsLeft - 1 end},
    {name = "The Debuff", effect = "All mults halved", modifier = function(gs) gs.multPenalty = 0.5 end},
    {name = "The Blind", effect = "Cards face down until played", modifier = function(gs) gs.blindMode = true end},
}

-- Purist Mode Opponent Ladder (15 opponents to victory)
-- Includes gender, age, profession, and wealth for each NPC
-- Using new folder structure for portraits
Game.puristLadder = {
    -- Tier 1: Beginners (Rounds 1-3)
    {name = "Rookie Rick", title = "The Newbie", color = {0.5, 0.7, 0.5}, targetBonus = 0, trait = nil, tier = 1, portrait = "Human/Men_Human/Human_10",
     gender = "male", age = 22, profession = "Farmhand", wealth = "poor"},
    {name = "Casual Carol", title = "The Tourist", color = {0.6, 0.6, 0.8}, targetBonus = 20, trait = nil, tier = 1, portrait = "Human/Women_Human/Human_15_woman",
     gender = "female", age = 34, profession = "Traveler", wealth = "common"},
    {name = "Timid Tim", title = "The Hesitant", color = {0.7, 0.7, 0.6}, targetBonus = 40, trait = nil, tier = 1, portrait = "Human/Men_Human/Human_01",
     gender = "male", age = 19, profession = "Apprentice", wealth = "poor"},

    -- Tier 2: Intermediates (Rounds 4-6)
    {name = "Steady Steve", title = "The Consistent", color = {0.5, 0.5, 0.8}, targetBonus = 60, trait = nil, tier = 2, portrait = "Human/Women_Human/Human_04",
     gender = "male", age = 41, profession = "Craftsman", wealth = "common"},
    {name = "Patient Paula", title = "The Planner", color = {0.6, 0.5, 0.7}, targetBonus = 80, trait = nil, tier = 2, portrait = "Human/Women_Human/Human_07_girl",
     gender = "female", age = 29, profession = "Scholar", wealth = "comfortable"},
    {name = "Lucky Lucy", title = "The Fortunate", color = {0.9, 0.7, 0.3}, targetBonus = 100, trait = "extra_mult", tier = 2, portrait = "Human/Women_Human/Human_42_queen",
     gender = "female", age = 24, profession = "Noblewoman", wealth = "wealthy"},

    -- Tier 3: Advanced (Rounds 7-9)
    {name = "Crafty Carl", title = "The Tactician", color = {0.8, 0.5, 0.3}, targetBonus = 130, trait = nil, tier = 3, portrait = "Human/Men_Human/Human_23_rogue",
     gender = "male", age = 36, profession = "Rogue", wealth = "comfortable"},
    {name = "Aggressive Anna", title = "The Rusher", color = {0.9, 0.3, 0.3}, targetBonus = 160, trait = "less_hands", tier = 3, portrait = "Human/Women_Human/Archer_woman",
     gender = "female", age = 27, profession = "Huntress", wealth = "common"},
    {name = "Sharp Shawn", title = "The Calculator", color = {0.3, 0.6, 0.8}, targetBonus = 190, trait = nil, tier = 3, portrait = "Human/Men_Human/Sage",
     gender = "male", age = 55, profession = "Mathematician", wealth = "wealthy"},

    -- Tier 4: Experts (Rounds 10-12)
    {name = "Veteran Vince", title = "The Experienced", color = {0.6, 0.4, 0.6}, targetBonus = 220, trait = nil, tier = 4, portrait = "Human/Men_Human/Knight_Man",
     gender = "male", age = 48, profession = "Knight", wealth = "wealthy"},
    {name = "Ruthless Rita", title = "The Merciless", color = {0.8, 0.2, 0.4}, targetBonus = 260, trait = "high_target", tier = 4, portrait = "Human/Women_Human/Human_50_amazon_warrior",
     gender = "female", age = 32, profession = "Assassin", wealth = "wealthy"},
    {name = "Mastermind Mike", title = "The Genius", color = {0.3, 0.3, 0.5}, targetBonus = 300, trait = "less_discards", tier = 4, portrait = "Human/Men_Human/Human_27_alchemyst",
     gender = "male", age = 45, profession = "Alchemist", wealth = "rich"},

    -- Tier 5: Champions (Rounds 13-15)
    {name = "Grand Greta", title = "The Formidable", color = {0.9, 0.6, 0.1}, targetBonus = 350, trait = nil, tier = 5, portrait = "Human/Women_Human/Human_42_queen",
     gender = "female", age = 52, profession = "Duchess", wealth = "noble"},
    {name = "Elite Edgar", title = "The Undefeated", color = {0.7, 0.7, 0.9}, targetBonus = 400, trait = "combo_penalty", tier = 5, portrait = "Human/Men_Human/DarkLord",
     gender = "male", age = 60, profession = "Dark Lord", wealth = "noble"},
    {name = "Champion Charlie", title = "The Legend", color = {1.0, 0.85, 0.0}, targetBonus = 500, trait = "final_boss", tier = 5, portrait = "God_Zeus",
     gender = "male", age = 99, profession = "Champion", wealth = "noble"},
}

-- Tier names and colors for progress display
Game.puristTiers = {
    {name = "Beginners", color = {0.4, 0.7, 0.4}},
    {name = "Intermediates", color = {0.5, 0.5, 0.8}},
    {name = "Advanced", color = {0.8, 0.5, 0.3}},
    {name = "Experts", color = {0.7, 0.3, 0.6}},
    {name = "Champions", color = {1.0, 0.85, 0.0}},
}

-- Milestone rewards for purist mode
Game.puristMilestones = {
    {opponent = 3, reward = 100, desc = "Tier 1 Complete!"},
    {opponent = 6, reward = 200, desc = "Tier 2 Complete!"},
    {opponent = 9, reward = 300, desc = "Tier 3 Complete!"},
    {opponent = 12, reward = 400, desc = "Tier 4 Complete!"},
    {opponent = 15, reward = 1000, desc = "CHAMPION! You've beaten them all!"},
}

-- Game state
local gameState = {
    phase = "draw",  -- draw, play, score, opponent, roundEnd, gameEnd
    round = 1,
    playerHand = {},
    playerDeck = {},
    playerDiscard = {},
    playerScore = 0,
    playerChips = 0,
    playerMult = 0,
    handsLeft = MAX_HANDS,
    discardsLeft = MAX_DISCARDS,

    opponentHand = {},
    opponentDeck = {},
    opponentDiscard = {},
    opponentScore = 0,
    opponentLastHand = nil,
    opponentPortrait = nil,
    opponentPortraitName = nil,

    selectedCards = {},
    animating = false,
    animTimer = 0,
    message = "",
    messageTimer = 0,

    targetScore = 300,
    roundScores = {player = 0, opponent = 0},
    won = false,

    -- Jokers
    playerJokers = {},
    opponentJokers = {},
    hoveredJoker = nil,
    hoveredJokerPos = {x = 0, y = 0},

    -- Card hover for tooltip
    hoveredCard = nil,
    hoveredCardPos = {x = 0, y = 0},

    -- Game mode
    gameMode = "standard",
    currentBoss = nil,
    multPenalty = 1,
    blindMode = false,

    -- Auto-play mode
    autoPlay = false,
    autoPlayTimer = 0,
    autoPlayDelay = 1.0,  -- Delay between auto-plays for visibility
    noCoins = false,

    -- Purist mode ladder tracking
    puristOpponent = 1,       -- Current opponent index (1-15)
    puristCurrentOpp = nil,   -- Current opponent data
    puristVictory = false,    -- True when all 15 beaten

    -- UI state
    showHandsReference = false,  -- Show poker hands reference panel
    showPauseMenu = false,       -- Show pause menu
}

-- UI layout
local layout = {
    cardWidth = 80,
    cardHeight = 120,
    cardSpacing = 90,
    handY = 500,
    playAreaY = 280,
    selectedOffset = -30
}

-- Forward declarations for local functions
local shuffleDeck, drawCards, showMessage, playHand, discardCards
local processNextPhase, checkRoundEnd, nextRound
local autoPlayTurn

-- Current opponent (forward declared, set at game start)
local currentOpponent = {name = "Poker Pete", color = {0.8, 0.5, 0.3}, symbol = "?"}

-- Poker table background
local pokerTableBG = nil

-- Shop items available between rounds
local shopItems = {
    {id = "chip_boost", name = "+20 Chips", description = "Add 20 to all card chips this round", cost = 30, effect = "chipBoost", value = 20},
    {id = "mult_boost", name = "+5 Mult", description = "Add 5 mult to your next hand", cost = 50, effect = "multBoost", value = 5},
    {id = "extra_hand", name = "+1 Hand", description = "Get an extra hand this round", cost = 40, effect = "extraHand", value = 1},
    {id = "extra_discard", name = "+1 Discard", description = "Get an extra discard this round", cost = 25, effect = "extraDiscard", value = 1},
    {id = "heal", name = "Refresh Deck", description = "Shuffle discard back into deck", cost = 20, effect = "refresh", value = 0},
}

-- Round bonuses from shop
local roundBonuses = {
    chipBoost = 0,
    multBoost = 0,
    extraHand = 0,
    extraDiscard = 0,
}

-- =============================================================================
-- BACKWARD COMPATIBILITY: Expose hand check functions on Game table
-- cardgame_ai.lua calls Game.checkRoyalFlush, Game.checkFlush, etc.
-- =============================================================================
Game.checkRoyalFlush = PokerHands.checkRoyalFlush
Game.checkStraightFlush = PokerHands.checkStraightFlush
Game.checkFourOfKind = PokerHands.checkFourOfKind
Game.checkFullHouse = PokerHands.checkFullHouse
Game.checkFlush = PokerHands.checkFlush
Game.checkStraight = PokerHands.checkStraight
Game.checkThreeOfKind = PokerHands.checkThreeOfKind
Game.checkTwoPair = PokerHands.checkTwoPair
Game.checkPair = PokerHands.checkPair
Game.checkHighCard = PokerHands.checkHighCard

-- =============================================================================
-- AI opponent portraits and names
-- =============================================================================
local aiOpponents = {
    {name = "Poker Pete", color = {0.8, 0.5, 0.3}, symbol = "?", portrait = "Human/Men_Human/Human_24_ronin",
     gender = "male", age = 35, profession = "Gambler", wealth = "comfortable"},
    {name = "Card Shark", color = {0.3, 0.5, 0.8}, symbol = "?", portrait = "Human/Men_Human/Viking",
     gender = "male", age = 42, profession = "Hustler", wealth = "wealthy"},
    {name = "Lucky Lou", color = {0.5, 0.8, 0.3}, symbol = "?", portrait = "Human/Men_Human/Human_27_alchemyst",
     gender = "male", age = 58, profession = "Alchemist", wealth = "comfortable"},
    {name = "Dealer Dan", color = {0.7, 0.3, 0.7}, symbol = "?", portrait = "Human/Men_Human/Merchant",
     gender = "male", age = 45, profession = "Merchant", wealth = "wealthy"},
    {name = "Ace Alice", color = {0.9, 0.4, 0.5}, symbol = "?", portrait = "Human/Women_Human/Human_15_woman",
     gender = "female", age = 28, profession = "Card Sharp", wealth = "comfortable"},
    {name = "Wild Will", color = {0.9, 0.7, 0.2}, symbol = "?", portrait = "Human/Men_Human/Viking",
     gender = "male", age = 38, profession = "Adventurer", wealth = "common"},
}

-- =============================================================================
-- GAME LIFECYCLE: init, setMode, startNewGame
-- =============================================================================

function Game.init()
    -- Load poker table background
    local success, img = pcall(function()
        return love.graphics.newImage("assets/Tavern Poker Table.png")
    end)
    if success then
        pokerTableBG = img
    end
end

function Game.setMode(modeName)
    if Game.modes[modeName] then
        gameState.gameMode = modeName
    end
end

function Game.startNewGame()
    -- Play game music
    AudioSystem.playGameMusic()

    -- Set random opponent
    Game.setRandomOpponent()

    local mode = Game.modes[gameState.gameMode] or Game.modes.standard

    -- Preserve auto-play state across games
    local preserveAutoPlay = gameState.autoPlay
    local preserveAutoPlayWins = gameState.autoPlayWins or 0

    -- Reset game state
    gameState.phase = "draw"
    gameState.round = 1
    gameState.playerScore = 0
    gameState.opponentScore = 0
    gameState.handsLeft = mode.startingHands
    gameState.discardsLeft = mode.startingDiscards
    gameState.selectedCards = {}
    gameState.message = ""
    gameState.targetScore = mode.targetScoreBase
    gameState.currentBoss = nil
    gameState.multPenalty = 1
    gameState.blindMode = false
    gameState.noCoins = false
    gameState.opponentLastHand = nil

    -- Reset shop round bonuses for new game
    roundBonuses.chipBoost = 0
    roundBonuses.multBoost = 0
    roundBonuses.extraHand = 0
    roundBonuses.extraDiscard = 0

    -- Restore auto-play state
    gameState.autoPlay = preserveAutoPlay
    gameState.autoPlayWins = preserveAutoPlayWins
    gameState.autoPlayContinueTimer = 0

    -- Check for boss in marathon mode
    if gameState.gameMode == "marathon" and mode.bossEvery and gameState.round % mode.bossEvery == 0 then
        gameState.currentBoss = Game.bosses[math.random(#Game.bosses)]
        gameState.currentBoss.modifier(gameState)
    end

    -- Initialize purist mode ladder
    if gameState.gameMode == "purist" then
        gameState.puristOpponent = 1
        gameState.puristVictory = false
        Game.setPuristOpponent(1)
        -- Set initial target based on first opponent
        gameState.targetScore = mode.targetScoreBase + Game.puristLadder[1].targetBonus
    end

    -- Load player jokers (none in purist mode at start)
    if mode.deckBuilding then
        gameState.playerJokers = {}
        gameState.isPuristMode = true
    else
        -- Load full joker data from equipped joker IDs
        gameState.playerJokers = {}
        if PlayerData.equippedJokers then
            for _, jokerData in ipairs(PlayerData.equippedJokers) do
                local fullJoker = jokerData and jokerData.id and Jokers.getById(jokerData.id)
                if fullJoker then
                    table.insert(gameState.playerJokers, fullJoker)
                end
            end
        end
        gameState.isPuristMode = false
    end

    -- Build player deck from current deck OR starter deck for purist mode
    gameState.playerDeck = {}
    gameState.playerDiscard = {}
    gameState.playerHand = {}

    if mode.deckBuilding then
        -- Purist mode: start with a basic starter deck
        local starterSize = mode.starterDeckSize or 20
        -- Add basic cards - 4 of each rank for a standard poker deck start
        local ranks = {"2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"}
        local suits = {"hearts", "diamonds", "clubs", "spades"}
        local cardsAdded = 0

        for _, rank in ipairs(ranks) do
            for _, suit in ipairs(suits) do
                if cardsAdded < starterSize then
                    -- Find matching basic card
                    for _, basicCard in ipairs(Cards.basicCards) do
                        if basicCard.rank == rank and basicCard.suit == suit then
                            table.insert(gameState.playerDeck, Cards.copyCard(basicCard))
                            cardsAdded = cardsAdded + 1
                            break
                        end
                    end
                end
            end
            if cardsAdded >= starterSize then break end
        end

        -- If not enough cards from matching, add random basic cards
        while cardsAdded < starterSize do
            local randomCard = Cards.basicCards[math.random(#Cards.basicCards)]
            table.insert(gameState.playerDeck, Cards.copyCard(randomCard))
            cardsAdded = cardsAdded + 1
        end
    else
        -- Normal mode: use player's constructed deck
        for _, deckCard in ipairs(PlayerData.currentDeck or {}) do
            if deckCard and deckCard.card then
                table.insert(gameState.playerDeck, Cards.copyCard(deckCard.card))
            end
        end
    end
    shuffleDeck(gameState.playerDeck)

    -- Build opponent deck (AI uses similar deck)
    gameState.opponentDeck = {}
    gameState.opponentDiscard = {}
    gameState.opponentHand = {}
    gameState.opponentJokers = AI.getRandomJokers(2)  -- AI gets 2 random jokers

    if GameState.isAI then
        AI.buildDeck(gameState.opponentDeck)
    end
    shuffleDeck(gameState.opponentDeck)

    -- Draw initial hands
    drawCards(gameState.playerHand, gameState.playerDeck, HAND_SIZE)
    drawCards(gameState.opponentHand, gameState.opponentDeck, HAND_SIZE)

    gameState.roundScores = {player = 0, opponent = 0}

    -- Transition to play phase
    gameState.phase = "play"

    showMessage("Round " .. gameState.round .. " - Score " .. gameState.targetScore .. " to win!")
end

-- =============================================================================
-- UPDATE
-- =============================================================================

function Game.update(dt)
    -- Update visual effect time (even when paused for shimmer effects)
    GameUI.updateEffectTime(dt)

    -- Don't update game logic while paused
    if gameState.showPauseMenu then return end

    -- Update message timer
    if gameState.messageTimer > 0 then
        gameState.messageTimer = gameState.messageTimer - dt
        if gameState.messageTimer <= 0 then
            gameState.message = ""
        end
    end

    -- Update animations
    if gameState.animating then
        gameState.animTimer = gameState.animTimer - dt
        if gameState.animTimer <= 0 then
            gameState.animating = false
            processNextPhase()
        end
    end

    -- Update score popups
    GameUI.updateScorePopups(dt)

    -- Auto-play for player
    if gameState.autoPlay and gameState.phase == "play" and not gameState.animating then
        gameState.autoPlayTimer = gameState.autoPlayTimer + dt
        if gameState.autoPlayTimer >= gameState.autoPlayDelay then
            gameState.autoPlayTimer = 0
            autoPlayTurn()
        end
    end

    -- AI turn
    if gameState.phase == "opponent" and GameState.isAI and not gameState.animating then
        AI.takeTurn(gameState)
    end

    -- Auto-play continue: start new game after win
    if gameState.phase == "autoPlayContinue" then
        gameState.autoPlayContinueTimer = (gameState.autoPlayContinueTimer or 0) + dt
        -- Wait 2 seconds to show victory before starting new game
        if gameState.autoPlayContinueTimer >= 2.0 then
            -- Start a new game, keeping autoPlay enabled
            Game.startNewGame()
        end
    end
end

-- =============================================================================
-- DRAW
-- =============================================================================

function Game.draw()
    local screenW, screenH = love.graphics.getDimensions()

    -- Draw poker table background
    if pokerTableBG then
        love.graphics.setColor(1, 1, 1)
        local imgW, imgH = pokerTableBG:getDimensions()
        local scaleX = screenW / imgW
        local scaleY = screenH / imgH
        local scale = math.max(scaleX, scaleY)
        local offsetX = (screenW - imgW * scale) / 2
        local offsetY = (screenH - imgH * scale) / 2
        love.graphics.draw(pokerTableBG, offsetX, offsetY, 0, scale, scale)
    else
        -- Fallback dark background
        love.graphics.setColor(0.1, 0.12, 0.15)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    end

    -- Reset hover states
    gameState.hoveredCard = nil

    -- Draw game info
    GameUI.drawGameInfo(gameState, layout, currentOpponent, screenW, screenH)

    -- Draw opponent area
    GameUI.drawOpponentArea(screenW)

    -- Draw purist mode ladder progress
    if gameState.isPuristMode then
        GameUI.drawPuristLadder(gameState, Game.puristLadder, Game.puristTiers, screenW, screenH)
    end

    -- Draw play area
    GameUI.drawPlayArea(gameState, layout, screenW)

    -- Draw player hand
    GameUI.drawHand(gameState.playerHand, gameState, layout, screenW, layout.handY, true)

    -- Draw message
    if gameState.message ~= "" then
        love.graphics.setColor(0.9, 0.7, 0.2)
        love.graphics.setFont(getFont(28))
        local msgW = love.graphics.getFont():getWidth(gameState.message)
        love.graphics.print(gameState.message, screenW/2 - msgW/2, 180)
    end

    -- Draw score popups (combo visualization)
    GameUI.drawScorePopups()

    -- Draw action buttons
    if gameState.phase == "play" then
        GameUI.drawGameButtons(gameState, layout, {CARDS_TO_PLAY = CARDS_TO_PLAY}, screenW, screenH)
        -- Draw hands reference panel (on top of buttons area)
        GameUI.drawHandsReference(gameState, screenW, screenH)
    end

    -- Draw round end screen
    if gameState.phase == "roundEnd" or gameState.phase == "gameEnd" then
        GameUI.drawRoundEndScreen(gameState, Game.modes, shopItems, Game.puristLadder, Game.puristMilestones, Game.puristTiers, UIAssets, screenW, screenH)
    end

    -- Draw auto-play continue screen
    if gameState.phase == "autoPlayContinue" then
        GameUI.drawAutoPlayContinue(gameState, screenW, screenH)
    end

    -- Draw tooltips on top of everything
    if gameState.hoveredCard and gameState.phase == "play" then
        GameUI.drawCardTooltip(gameState.hoveredCard, gameState.hoveredCardPos.x, gameState.hoveredCardPos.y, layout, screenW, screenH)
    end

    -- Draw joker tooltip on top
    if gameState.hoveredJoker and gameState.phase == "play" then
        GameUI.drawJokerTooltip(gameState.hoveredJoker, gameState.hoveredJokerPos.x, gameState.hoveredJokerPos.y, screenW, screenH)
    end

    -- Draw pause menu on top of everything
    GameUI.drawPauseMenu(gameState, screenW, screenH)
end

-- =============================================================================
-- INPUT HANDLING
-- =============================================================================

function Game.mousepressed(x, y, button)
    if button ~= 1 then return end

    local screenW, screenH = love.graphics.getDimensions()

    -- Pause menu handling
    if gameState.showPauseMenu then
        local panelW = 300
        local panelH = 200
        local panelX = screenW / 2 - panelW / 2
        local panelY = screenH / 2 - panelH / 2
        local btnW = 200
        local btnH = 45
        local btnX = panelX + panelW / 2 - btnW / 2

        -- Resume button
        local resumeY = panelY + 70
        if x >= btnX and x <= btnX + btnW and y >= resumeY and y <= resumeY + btnH then
            gameState.showPauseMenu = false
            return
        end

        -- Quit button
        local quitY = panelY + 130
        if x >= btnX and x <= btnX + btnW and y >= quitY and y <= quitY + btnH then
            gameState.showPauseMenu = false
            local TextRPG = require("textrpg"); TextRPG.init(); GameState.current = "textrpg"
            return
        end

        return  -- Block other clicks while paused
    end

    -- Round end screen
    if gameState.phase == "roundEnd" or gameState.phase == "gameEnd" then
        local panelW, panelH = 700, 520
        local panelX = screenW/2 - panelW/2
        local panelY = screenH/2 - panelH/2

        if gameState.phase == "gameEnd" then
            -- Continue button for game end (button is at y + 130 to y + 180)
            if x >= screenW/2 - 70 and x <= screenW/2 + 70 and
               y >= screenH/2 + 130 and y <= screenH/2 + 180 then
                if GameState.isStoryMode then
                    Game.StoryMode.endGame(gameState.won)
                    GameState.current = "storymode"
                    GameState.isStoryMode = false
                else
                    local TextRPG = require("textrpg"); TextRPG.init(); GameState.current = "textrpg"
                end
            end
        else
            -- Shop interactions for between-round
            local shopX = panelX + 460
            local shopY = panelY + 60
            local shopW = 220
            local itemY = shopY + 40

            -- Check shop item clicks
            for i, item in ipairs(shopItems) do
                if i <= 3 then
                    local itemX = shopX + 10
                    local itemW, itemH = shopW - 20, 40

                    if x >= itemX and x <= itemX + itemW and y >= itemY and y <= itemY + itemH then
                        if PlayerData.coins >= item.cost then
                            PlayerData.coins = PlayerData.coins - item.cost
                            -- Apply effect
                            if item.effect == "extraHand" then
                                gameState.handsLeft = gameState.handsLeft + item.value
                            elseif item.effect == "extraDiscard" then
                                gameState.discardsLeft = gameState.discardsLeft + item.value
                            elseif item.effect == "chipBoost" then
                                roundBonuses.chipBoost = roundBonuses.chipBoost + item.value
                            elseif item.effect == "multBoost" then
                                roundBonuses.multBoost = roundBonuses.multBoost + item.value
                            elseif item.effect == "refresh" then
                                for _, card in ipairs(gameState.playerDiscard) do
                                    table.insert(gameState.playerDeck, card)
                                end
                                gameState.playerDiscard = {}
                                shuffleDeck(gameState.playerDeck)
                            end
                            savePlayerData()
                        end
                        return
                    end
                    itemY = itemY + 45
                end
            end

            -- Check pack purchase clicks
            local packs = {
                {name = "basic", cost = 50, cards = 3, rareChance = 0.1},
                {name = "standard", cost = 100, cards = 5, rareChance = 0.2},
                {name = "premium", cost = 200, cards = 5, rareChance = 0.4},
            }
            local packBtnX = panelX + 40
            local packBtnY = panelY + 300

            for _, pack in ipairs(packs) do
                local packBtnW, packBtnH = 180, 30
                if x >= packBtnX and x <= packBtnX + packBtnW and y >= packBtnY and y <= packBtnY + packBtnH then
                    if PlayerData.coins >= pack.cost then
                        PlayerData.coins = PlayerData.coins - pack.cost

                        -- Generate cards from pack
                        local newCards = {}
                        for i = 1, pack.cards do
                            local cardPool = math.random() < pack.rareChance and Cards.rareCards or Cards.basicCards
                            local card = cardPool[math.random(#cardPool)]
                            table.insert(newCards, Cards.copyCard(card))
                        end

                        if gameState.isPuristMode then
                            -- Purist mode: add cards directly to game deck
                            for _, card in ipairs(newCards) do
                                table.insert(gameState.playerDeck, card)
                            end
                            shuffleDeck(gameState.playerDeck)
                            showMessage("Added " .. #newCards .. " cards to your deck!")
                        else
                            -- Normal mode: add cards to permanent collection
                            for _, card in ipairs(newCards) do
                                table.insert(PlayerData.collection, {
                                    id = #PlayerData.collection + 1,
                                    cardId = card.id,
                                    card = card
                                })
                            end
                        end
                        savePlayerData()
                    end
                    return
                end
                packBtnX = packBtnX + 200
            end

            -- Check joker pack purchase (purist mode only)
            if gameState.isPuristMode then
                local jokerPackY = panelY + 340
                local jokerPackW, jokerPackH = 200, 30
                local jokerPackX = panelX + 250

                if x >= jokerPackX and x <= jokerPackX + jokerPackW and
                   y >= jokerPackY and y <= jokerPackY + jokerPackH then
                    if PlayerData.coins >= 150 then
                        PlayerData.coins = PlayerData.coins - 150
                        -- Add a random joker
                        if Jokers.list and #Jokers.list > 0 then
                            local randomJoker = Jokers.list[math.random(#Jokers.list)]
                            local jokerCopy = {}
                            for k, v in pairs(randomJoker) do
                                jokerCopy[k] = v
                            end
                            jokerCopy.instanceId = #gameState.playerJokers + 1
                            table.insert(gameState.playerJokers, jokerCopy)
                            showMessage("Got joker: " .. jokerCopy.name .. "!")
                        end
                        savePlayerData()
                    end
                    return
                end
            end

            -- Continue button
            local continueW, continueH = 160, 50
            local continueX = screenW/2 - continueW/2
            local continueY = panelY + panelH - 70

            if x >= continueX and x <= continueX + continueW and y >= continueY and y <= continueY + continueH then
                nextRound()
            end
        end
        return
    end

    if gameState.phase ~= "play" then return end

    -- Check card clicks
    local startX = screenW/2 - (#gameState.playerHand * layout.cardSpacing)/2 + layout.cardSpacing/2 - layout.cardWidth/2

    for i, card in ipairs(gameState.playerHand) do
        local cardX = startX + (i-1) * layout.cardSpacing
        local cardY = layout.handY

        -- Check if already selected
        local selIndex = nil
        for j, selCard in ipairs(gameState.selectedCards) do
            if selCard == i then
                selIndex = j
                break
            end
        end

        if selIndex then
            cardY = layout.handY + layout.selectedOffset
        end

        if x >= cardX and x <= cardX + layout.cardWidth and
           y >= cardY and y <= cardY + layout.cardHeight then
            if selIndex then
                table.remove(gameState.selectedCards, selIndex)
            else
                if #gameState.selectedCards < CARDS_TO_PLAY then
                    table.insert(gameState.selectedCards, i)
                end
            end
            return
        end
    end

    -- Check button clicks
    local buttonY = screenH - 80
    local buttonW, buttonH = 120, 45

    -- Play button
    local playX = screenW/2 - buttonW - 20
    if x >= playX and x <= playX + buttonW and y >= buttonY and y <= buttonY + buttonH then
        if #gameState.selectedCards > 0 and gameState.handsLeft > 0 then
            playHand()
        end
        return
    end

    -- Discard button
    local discardX = screenW/2 + 20
    if x >= discardX and x <= discardX + buttonW and y >= buttonY and y <= buttonY + buttonH then
        if #gameState.selectedCards > 0 and gameState.discardsLeft > 0 then
            discardCards()
        end
        return
    end

    -- Hands Reference toggle button
    local handsX = 20
    local handsY = buttonY
    local handsW, handsH = 90, 45
    if x >= handsX and x <= handsX + handsW and y >= handsY and y <= handsY + handsH then
        gameState.showHandsReference = not gameState.showHandsReference
        return
    end

    -- Auto-Play toggle button
    local autoX = screenW - 140
    local autoY = buttonY
    local autoW, autoH = 120, 45
    if x >= autoX and x <= autoX + autoW and y >= autoY and y <= autoY + autoH then
        gameState.autoPlay = not gameState.autoPlay
        gameState.autoPlayTimer = 0  -- Reset timer when toggling
        return
    end
end

function Game.mousereleased(x, y, button)
end

function Game.keypressed(key)
    if key == "escape" then
        if gameState.showPauseMenu then
            gameState.showPauseMenu = false
        elseif gameState.showHandsReference then
            gameState.showHandsReference = false
        else
            gameState.showPauseMenu = true
        end
        return
    end

    -- Don't process other keys if paused
    if gameState.showPauseMenu then return end

    -- Toggle auto-play with 'a' key
    if key == "a" then
        -- If in autoPlayContinue phase, stop and go to regular game end
        if gameState.phase == "autoPlayContinue" then
            gameState.autoPlay = false
            gameState.phase = "gameEnd"
            gameState.won = true
        else
            -- Toggle auto-play
            gameState.autoPlay = not gameState.autoPlay
            gameState.autoPlayTimer = 0
            if not gameState.autoPlay then
                gameState.autoPlayWins = 0
            end
        end
        return
    end

    if key == "space" and gameState.phase == "play" then
        if #gameState.selectedCards > 0 and gameState.handsLeft > 0 then
            playHand()
        end
    elseif key == "d" and gameState.phase == "play" then
        if #gameState.selectedCards > 0 and gameState.discardsLeft > 0 then
            discardCards()
        end
    end
end

-- =============================================================================
-- GAME LOGIC: play hand, discard, scoring, round management
-- =============================================================================

-- Play the selected hand
playHand = function()
    if #gameState.selectedCards == 0 then return end

    local screenW = love.graphics.getDimensions()

    -- Get played cards
    local playedCards = {}
    table.sort(gameState.selectedCards)
    for i = #gameState.selectedCards, 1, -1 do
        local cardIndex = gameState.selectedCards[i]
        table.insert(playedCards, 1, table.remove(gameState.playerHand, cardIndex))
    end

    -- Evaluate hand and get scoring cards
    local handName, baseChips, baseMult, scoringCards = PokerHands.evaluateHandWithCards(playedCards)

    local chips = baseChips
    local mult = baseMult

    -- Only add chips from cards that form the hand (scoring cards)
    -- Extra cards don't contribute unless joker allows
    local hasAllCardsScoreJoker = false
    for _, joker in ipairs(gameState.playerJokers) do
        if joker.effect == "all_cards_score" then
            hasAllCardsScoreJoker = true
            break
        end
    end

    local cardsToScore = hasAllCardsScoreJoker and playedCards or scoringCards

    -- Apply card chips and abilities
    for i, card in ipairs(cardsToScore) do
        chips = chips + card.chips

        -- Add popup for each card scored
        local popupX = screenW/2 + (i - #cardsToScore/2) * 50
        GameUI.addScorePopup("+" .. card.chips, popupX, layout.playAreaY + 50, {0.3, 0.8, 0.3})

        if card.ability == "mult_boost" then
            mult = mult + (card.mult or 2)
            GameUI.addScorePopup("+2 mult", popupX, layout.playAreaY + 80, {0.8, 0.3, 0.8})
        elseif card.ability == "glass" then
            mult = mult * (card.multMult or 2)
            GameUI.addScorePopup("x2 mult!", popupX, layout.playAreaY + 80, {0.5, 0.8, 1})
            -- Glass might break
            if math.random() < 0.25 then
                showMessage(Cards.getDisplayName(card) .. " shattered!")
            else
                table.insert(gameState.playerDiscard, card)
            end
        elseif card.ability == "lucky" then
            if math.random(5) == 1 then
                mult = mult + (card.luckyMult or 20)
                GameUI.addScorePopup("+20 mult!", popupX, layout.playAreaY + 80, {1, 0.8, 0.2})
                showMessage("Lucky! +20 mult!")
            end
            table.insert(gameState.playerDiscard, card)
        else
            table.insert(gameState.playerDiscard, card)
        end
    end

    -- Handle non-scoring cards (discard them without adding chips)
    if not hasAllCardsScoreJoker then
        for _, card in ipairs(playedCards) do
            local isScoring = false
            for _, sc in ipairs(scoringCards) do
                if sc == card then
                    isScoring = true
                    break
                end
            end
            if not isScoring then
                table.insert(gameState.playerDiscard, card)
            end
        end
    end

    -- Apply jokers
    local context = {
        phase = "score",
        playedCards = playedCards,
        scoringCards = cardsToScore,
        handName = handName,
        chips = chips,
        mult = mult,
        jokers = gameState.playerJokers
    }
    context = Jokers.applyAll(gameState.playerJokers, context)

    -- Add joker effect popups
    if context.chips > chips then
        GameUI.addScorePopup("+" .. (context.chips - chips) .. " chips", screenW/2 + 100, layout.playAreaY + 30, {0.9, 0.6, 0.2})
    end
    if context.mult > mult then
        GameUI.addScorePopup("+" .. (context.mult - mult) .. " mult", screenW/2 + 100, layout.playAreaY + 60, {0.9, 0.3, 0.8})
    end

    chips = context.chips
    mult = context.mult

    -- Apply shop round bonuses (chipBoost and multBoost)
    if roundBonuses.chipBoost > 0 then
        chips = chips + roundBonuses.chipBoost
        GameUI.addScorePopup("+" .. roundBonuses.chipBoost .. " chips (shop)", screenW/2 + 100, layout.playAreaY + 10, {0.2, 0.8, 0.6})
    end
    if roundBonuses.multBoost > 0 then
        mult = mult + roundBonuses.multBoost
        GameUI.addScorePopup("+" .. roundBonuses.multBoost .. " mult (shop)", screenW/2 + 100, layout.playAreaY + 90, {0.8, 0.2, 0.6})
    end

    -- Apply boss mult penalty (e.g. "The Debuff" halves mult)
    mult = mult * (gameState.multPenalty or 1)

    -- Apply purist opponent traits
    if gameState.isPuristMode and gameState.puristCurrentOpp then
        local opp = gameState.puristCurrentOpp

        -- extra_mult: opponent has bonus mult, making them harder to beat
        if opp.trait == "extra_mult" then
            -- Opponent has 1.5x mult advantage, so player needs higher scores
            mult = mult * 0.85  -- Player gets 85% mult to make it harder
        end

        -- combo_penalty: each hand played reduces mult (discourages playing many hands)
        if opp.trait == "combo_penalty" then
            local mode = Game.modes[gameState.gameMode]
            local handsUsed = mode.startingHands - gameState.handsLeft
            -- Reduce mult by 5% for each hand already played
            local penalty = math.max(0.5, 1 - (handsUsed * 0.05))
            mult = mult * penalty
        end
    end

    -- Calculate final score
    local score = chips * mult
    gameState.roundScores.player = gameState.roundScores.player + score
    gameState.handsLeft = gameState.handsLeft - 1

    -- Big score popup
    GameUI.addScorePopup(tostring(score), screenW/2 - 40, layout.playAreaY - 80, {1, 1, 0})

    showMessage(string.format("%s! %d x %d = %d", handName, chips, mult, score))

    -- Update stats
    if PlayerData.stats then
        PlayerData.stats.totalChipsScored = (PlayerData.stats.totalChipsScored or 0) + chips
        PlayerData.stats.totalMultEarned = (PlayerData.stats.totalMultEarned or 0) + mult
        PlayerData.stats.handsPlayed = (PlayerData.stats.handsPlayed or 0) + 1
        if score > (PlayerData.stats.bestHandScore or 0) then
            PlayerData.stats.bestHandScore = score
            PlayerData.stats.bestHand = handName
        end
    end

    -- Clear selection
    gameState.selectedCards = {}

    -- Draw new cards
    local cardsToDraw = math.min(HAND_SIZE - #gameState.playerHand, #gameState.playerDeck)
    drawCards(gameState.playerHand, gameState.playerDeck, cardsToDraw)

    -- Check if player hit target score immediately
    if gameState.roundScores.player >= gameState.targetScore then
        gameState.animating = true
        gameState.animTimer = 1.0
        gameState.phase = "opponent"  -- Will trigger checkRoundEnd via processNextPhase
    -- Check for round end (out of hands/cards)
    elseif gameState.handsLeft <= 0 or #gameState.playerHand == 0 then
        gameState.phase = "opponent"
        gameState.animating = true
        gameState.animTimer = 1.5
    end
end

-- Auto-play: Find and play the best hand automatically
autoPlayTurn = function()
    if #gameState.playerHand == 0 then return end
    if gameState.handsLeft <= 0 and gameState.discardsLeft <= 0 then return end

    -- Use AI logic to find best hand
    local bestCards, bestHandName, bestChips, bestMult = AI.findBestHand(gameState.playerHand)

    -- Decide whether to play or discard
    local shouldDiscard = false

    -- If we only have high card and have discards left, consider discarding
    if bestHandName == "High Card" and gameState.discardsLeft > 0 then
        -- Discard non-valuable cards to try for better hand
        shouldDiscard = true
    end

    if shouldDiscard and gameState.discardsLeft > 0 then
        -- Select cards to discard (keep high value cards, discard low ones)
        gameState.selectedCards = {}
        local sorted = {}
        for i, card in ipairs(gameState.playerHand) do
            table.insert(sorted, {index = i, card = card})
        end
        table.sort(sorted, function(a, b) return a.card.value < b.card.value end)

        -- Discard up to 5 lowest cards
        local discardCount = math.min(5, #sorted)
        for i = 1, discardCount do
            table.insert(gameState.selectedCards, sorted[i].index)
        end

        -- Sort indices in descending order for safe removal
        table.sort(gameState.selectedCards, function(a, b) return a > b end)

        -- Perform discard
        if #gameState.selectedCards > 0 then
            discardCards()
            showMessage("Auto-discarding " .. discardCount .. " cards...")
        end
    elseif gameState.handsLeft > 0 then
        -- Select the cards that form the best hand
        gameState.selectedCards = {}
        for _, bestCard in ipairs(bestCards) do
            for i, handCard in ipairs(gameState.playerHand) do
                if handCard == bestCard then
                    table.insert(gameState.selectedCards, i)
                    break
                end
            end
        end

        -- Play the hand
        if #gameState.selectedCards > 0 then
            showMessage("Auto-playing: " .. bestHandName)
            playHand()
        end
    end
end

-- Discard selected cards and draw new ones
discardCards = function()
    if #gameState.selectedCards == 0 or gameState.discardsLeft <= 0 then return end

    local numDiscarded = #gameState.selectedCards

    -- Remove selected cards
    table.sort(gameState.selectedCards)
    for i = #gameState.selectedCards, 1, -1 do
        local cardIndex = gameState.selectedCards[i]
        local card = table.remove(gameState.playerHand, cardIndex)
        table.insert(gameState.playerDiscard, card)
    end

    gameState.discardsLeft = gameState.discardsLeft - 1
    gameState.selectedCards = {}

    -- Draw new cards
    local cardsToDraw = math.min(HAND_SIZE - #gameState.playerHand, #gameState.playerDeck)
    drawCards(gameState.playerHand, gameState.playerDeck, cardsToDraw)

    showMessage("Discarded " .. numDiscarded .. " cards")
end

-- =============================================================================
-- UTILITY FUNCTIONS
-- =============================================================================

-- Shuffle a deck
shuffleDeck = function(deck)
    for i = #deck, 2, -1 do
        local j = math.random(i)
        deck[i], deck[j] = deck[j], deck[i]
    end
end

-- Draw cards from deck to hand
drawCards = function(hand, deck, count)
    for i = 1, count do
        if #deck > 0 then
            table.insert(hand, table.remove(deck))
        end
    end
end

-- Show a message
showMessage = function(msg)
    gameState.message = msg
    gameState.messageTimer = 2
end

-- Process next game phase
processNextPhase = function()
    if gameState.phase == "opponent" then
        -- AI has played, check round end
        checkRoundEnd()
    end
end

-- Check if round should end
checkRoundEnd = function()
    -- Check if player hit target score (instant win condition)
    if gameState.roundScores.player >= gameState.targetScore then
        PlayerData.wins = PlayerData.wins + 1
        if not gameState.noCoins then
            PlayerData.coins = PlayerData.coins + 10 + gameState.round * 5
        end
        -- Award crystals for winning (5-10 based on round)
        local crystalReward = 5 + gameState.round * 2
        PlayerData.crystals = (PlayerData.crystals or 0) + crystalReward
        savePlayerData()

        local mode = Game.modes[gameState.gameMode] or Game.modes.standard
        if gameState.round >= mode.maxRounds then
            -- If autoPlay is enabled, start a new game instead of ending
            if gameState.autoPlay then
                -- Track consecutive wins for auto-play
                gameState.autoPlayWins = (gameState.autoPlayWins or 0) + 1
                -- Brief pause before starting new game
                gameState.phase = "autoPlayContinue"
                gameState.autoPlayContinueTimer = 0
                gameState.won = true
            else
                gameState.phase = "gameEnd"
                gameState.won = true
            end
        else
            gameState.phase = "roundEnd"
        end
        return
    end

    local playerDone = gameState.handsLeft <= 0 or #gameState.playerHand == 0
    local opponentDone = true -- AI plays all at once

    if playerDone and opponentDone then
        -- Player ran out of hands without hitting target - loss
        PlayerData.losses = PlayerData.losses + 1
        savePlayerData()
        -- Auto-play stops on loss
        if gameState.autoPlay then
            gameState.autoPlay = false
        end
        gameState.phase = "gameEnd"
        gameState.won = false
    else
        gameState.phase = "play"
    end
end

-- Start next round
nextRound = function()
    gameState.round = gameState.round + 1

    local mode = Game.modes[gameState.gameMode] or Game.modes.standard
    gameState.handsLeft = mode.startingHands
    gameState.discardsLeft = mode.startingDiscards
    gameState.roundScores = {player = 0, opponent = 0}
    gameState.selectedCards = {}
    gameState.currentBoss = nil
    gameState.multPenalty = 1
    gameState.blindMode = false
    gameState.noCoins = false

    -- Reset shop round bonuses for the new round
    roundBonuses.chipBoost = 0
    roundBonuses.multBoost = 0
    roundBonuses.extraHand = 0
    roundBonuses.extraDiscard = 0

    -- Marathon mode: spawn bosses on appropriate rounds
    if mode.bossEvery and gameState.round % mode.bossEvery == 0 and #Game.bosses > 0 then
        local bossIndex = math.random(#Game.bosses)
        gameState.currentBoss = Game.bosses[bossIndex]
        if gameState.currentBoss.modifier then
            gameState.currentBoss.modifier(gameState)
        end
    end

    -- Purist mode: advance to next opponent
    if gameState.isPuristMode then
        local nextOpp = gameState.puristOpponent + 1

        -- Check for victory
        if nextOpp > #Game.puristLadder then
            gameState.puristVictory = true
            gameState.phase = "gameEnd"
            gameState.won = true
            -- Big reward for completing purist mode
            PlayerData.coins = PlayerData.coins + 1000
            PlayerData.crystals = (PlayerData.crystals or 0) + 50  -- Big crystal bonus!
            PlayerData.wins = PlayerData.wins + 15  -- Bonus wins for completing ladder
            savePlayerData()
            return
        end

        -- Set next opponent
        Game.setPuristOpponent(nextOpp)

        -- Calculate target based on base + opponent bonus
        gameState.targetScore = mode.targetScoreBase + Game.puristLadder[nextOpp].targetBonus

        -- Check for milestone rewards
        for _, milestone in ipairs(Game.puristMilestones) do
            if milestone.opponent == gameState.puristOpponent - 1 then  -- Just beat this opponent
                PlayerData.coins = PlayerData.coins + milestone.reward
                savePlayerData()
            end
        end
    else
        -- Normal mode: standard target increase
        gameState.targetScore = gameState.targetScore + mode.targetScoreIncrease
    end

    -- Return hand cards to deck first
    for _, card in ipairs(gameState.playerHand) do
        table.insert(gameState.playerDeck, card)
    end
    gameState.playerHand = {}

    -- Reshuffle discard into deck
    for _, card in ipairs(gameState.playerDiscard) do
        table.insert(gameState.playerDeck, card)
    end
    gameState.playerDiscard = {}
    shuffleDeck(gameState.playerDeck)

    -- Draw new hand
    drawCards(gameState.playerHand, gameState.playerDeck, HAND_SIZE)

    -- Reset opponent
    for _, card in ipairs(gameState.opponentDiscard) do
        table.insert(gameState.opponentDeck, card)
    end
    gameState.opponentDiscard = {}
    shuffleDeck(gameState.opponentDeck)
    gameState.opponentHand = {}
    drawCards(gameState.opponentHand, gameState.opponentDeck, HAND_SIZE)

    gameState.phase = "play"

    local roundMsg = "Round " .. gameState.round .. " - Target: " .. gameState.targetScore
    if gameState.currentBoss then
        roundMsg = roundMsg .. " [BOSS: " .. gameState.currentBoss.name .. " - " .. gameState.currentBoss.effect .. "]"
    end
    showMessage(roundMsg)
end

-- =============================================================================
-- OPPONENT MANAGEMENT
-- =============================================================================

-- Set random opponent at game start
function Game.setRandomOpponent()
    currentOpponent = aiOpponents[math.random(#aiOpponents)]

    -- Load opponent's assigned portrait
    UIAssets.init()
    if currentOpponent.portrait then
        gameState.opponentPortrait = UIAssets.getCharacter(currentOpponent.portrait)
        gameState.opponentPortraitName = currentOpponent.portrait
    else
        -- Fallback to random portrait
        local portrait, name = UIAssets.getRandomOpponent()
        gameState.opponentPortrait = portrait
        gameState.opponentPortraitName = name
    end
end

-- Set opponent for purist mode ladder
function Game.setPuristOpponent(oppIndex)
    if oppIndex > #Game.puristLadder then
        gameState.puristVictory = true
        return
    end

    local opp = Game.puristLadder[oppIndex]
    gameState.puristCurrentOpp = opp
    gameState.puristOpponent = oppIndex

    -- Set as current opponent (visual)
    currentOpponent = {
        name = opp.name,
        color = opp.color,
        description = opp.title,
        portrait = opp.portrait
    }

    -- Load opponent portrait
    UIAssets.init()
    if opp.portrait then
        gameState.opponentPortrait = UIAssets.getCharacter(opp.portrait)
        gameState.opponentPortraitName = opp.portrait
    else
        local portrait, name = UIAssets.getRandomOpponent()
        gameState.opponentPortrait = portrait
        gameState.opponentPortraitName = name
    end

    -- Apply opponent trait modifiers
    if opp.trait == "less_hands" then
        gameState.handsLeft = gameState.handsLeft - 1
    elseif opp.trait == "less_discards" then
        gameState.discardsLeft = math.max(0, gameState.discardsLeft - 1)
    elseif opp.trait == "high_target" then
        gameState.targetScore = gameState.targetScore + 50
    elseif opp.trait == "extra_mult" then
        -- Lucky Lucy - higher target score
        gameState.targetScore = gameState.targetScore + 75
    elseif opp.trait == "combo_penalty" then
        -- Elite Edgar - player loses one hand
        gameState.handsLeft = gameState.handsLeft - 1
    elseif opp.trait == "final_boss" then
        -- Final boss gets multiple debuffs
        gameState.handsLeft = gameState.handsLeft - 1
        gameState.targetScore = gameState.targetScore + 100
    end
end

-- Get current purist opponent for display
function Game.getCurrentPuristOpponent()
    return gameState.puristCurrentOpp
end

-- Expose game state for AI
function Game.getState()
    return gameState
end

-- =============================================================================
-- STORY MODE SUBSECTION
-- Visual Novel + Poker Gameplay (merged from storymode.lua)
-- =============================================================================

local StoryMode = {}
Game.StoryMode = StoryMode

-- Story state
local storyState = {
    mode = "storymode",  -- storymode, game, epilogue
    currentStory = nil,
    currentScene = 1,
    gameStarted = false,
    gameWon = false,
    playerWon = false
}

-- Story definitions
local stories = {
    {
        id = 1,
        title = "The Card Master's Challenge",
        character = "Luna",
        characterColor = {0.3, 0.5, 0.9},
        backgroundColorStart = {0.1, 0.15, 0.25},
        backgroundColorEnd = {0.25, 0.1, 0.15},
        scenes = {
            {
                text = "A mysterious figure approaches across the moonlit hall...\n\n\"I've been waiting for you, challenger.\"",
                character = "Luna",
                position = "right"
            },
            {
                text = "\"They call me Luna. I've never lost a card game.\n\nWill you face me?\"",
                character = "Luna",
                position = "right"
            }
        },
        epilogueWin = {
            text = "\"Incredible... I've finally met my match.\n\nYou are truly worthy of the title.\"",
            character = "Luna",
            position = "right"
        },
        epilogueLose = {
            text = "\"As expected. I am unbeatable.\n\nPerhaps you should try again... if you dare.\"",
            character = "Luna",
            position = "right"
        },
        gameMode = "standard"
    },
    {
        id = 2,
        title = "The Gambler's Gambit",
        character = "Vex",
        characterColor = {0.9, 0.3, 0.3},
        backgroundColorStart = {0.25, 0.1, 0.1},
        backgroundColorEnd = {0.1, 0.2, 0.25},
        scenes = {
            {
                text = "The tavern falls silent as a hooded figure sits across from you...\n\n\"Name's Vex. I've been waiting for a real challenger.\"",
                character = "Vex",
                position = "left"
            },
            {
                text = "\"They say you've got some skill. Let's see if it's enough.\n\nAll or nothing. You ready?\"",
                character = "Vex",
                position = "left"
            }
        },
        epilogueWin = {
            text = "\"Well I'll be... you actually did it.\n\nYou've got more guts than I gave you credit for.\"",
            character = "Vex",
            position = "left"
        },
        epilogueLose = {
            text = "\"Just as I thought. Better luck next time, friend.\n\nMaybe in another life...\"",
            character = "Vex",
            position = "left"
        },
        gameMode = "extended"
    },
    {
        id = 3,
        title = "The Ultimate Trial",
        character = "Cipher",
        characterColor = {0.7, 0.3, 0.9},
        backgroundColorStart = {0.15, 0.05, 0.2},
        backgroundColorEnd = {0.2, 0.15, 0.1},
        scenes = {
            {
                text = "An enigmatic presence materializes before you...\n\n\"So, you've come this far. Impressive.\"",
                character = "Cipher",
                position = "right"
            },
            {
                text = "\"I am Cipher, the keeper of cards.\n\nDefeat me, and you shall be legend.\"",
                character = "Cipher",
                position = "right"
            }
        },
        epilogueWin = {
            text = "\"Extraordinary! You have proven yourself worthy.\n\nThe title is yours. Welcome, true master.\"",
            character = "Cipher",
            position = "right"
        },
        epilogueLose = {
            text = "\"A valiant effort, but alas, not enough.\n\nReturn when you are stronger...\"",
            character = "Cipher",
            position = "right"
        },
        gameMode = "marathon"
    }
}

-- Forward declarations for story drawing
local drawStoryScene, drawStoryEpilogue

-- UI components for story mode
local storyReturnButton

function StoryMode.init()
    storyState.mode = "storymode"
    storyState.currentScene = 1
    storyState.gameStarted = false
end

function StoryMode.selectStory(storyId)
    for _, story in ipairs(stories) do
        if story.id == storyId then
            storyState.currentStory = story
            storyState.currentScene = 1
            storyState.mode = "storymode"
            storyState.gameStarted = false
            return true
        end
    end
    return false
end

function StoryMode.update(dt)
    -- Story mode doesn't need frame updates
    UI.anim.update(dt)
end

function StoryMode.draw()
    local screenW, screenH = love.graphics.getDimensions()

    if storyState.mode == "storymode" then
        drawStoryScene(screenW, screenH)
    elseif storyState.mode == "game" then
        -- Game is drawn by Game module
        Game.draw()
    elseif storyState.mode == "epilogue" then
        drawStoryEpilogue(screenW, screenH)
    end
end

drawStoryScene = function(screenW, screenH)
    if not storyState.currentStory then return end

    local story = storyState.currentStory
    local scene = story.scenes[storyState.currentScene]

    if not scene then return end

    -- Background gradient
    local bgColor = story.backgroundColorStart
    if storyState.currentScene > 1 then
        bgColor = story.backgroundColorEnd
    end
    love.graphics.setColor(bgColor[1] * 0.7, bgColor[2] * 0.7, bgColor[3] * 0.7)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Placeholder character portrait
    love.graphics.setColor(story.characterColor[1], story.characterColor[2], story.characterColor[3], 0.3)
    if scene.position == "right" then
        love.graphics.rectangle("fill", screenW * 0.6, screenH * 0.15, screenW * 0.35, screenH * 0.7)
    else
        love.graphics.rectangle("fill", 0.05 * screenW, screenH * 0.15, screenW * 0.35, screenH * 0.7)
    end

    -- Character name
    love.graphics.setColor(story.characterColor)
    love.graphics.setFont(UI.fonts.get(28))
    love.graphics.print(scene.character, 40, screenH * 0.1)

    -- Dialogue box
    love.graphics.setColor(0.1, 0.1, 0.15, 0.95)
    love.graphics.rectangle("fill", 40, screenH * 0.6, screenW - 80, screenH * 0.35, 10, 10)

    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 40, screenH * 0.6, screenW - 80, screenH * 0.35, 10, 10)
    love.graphics.setLineWidth(1)

    -- Dialogue text
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(18))
    local wrappedText = love.graphics.getFont():getWrap(scene.text, screenW - 120)
    love.graphics.printf(scene.text, 60, screenH * 0.65, screenW - 120, "left")

    -- Instructions
    love.graphics.setColor(0.6, 0.9, 0.6)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.print("Click to continue...", screenW - 280, screenH - 40)

    -- Story title
    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(UI.fonts.get(24))
    local titleW = love.graphics.getFont():getWidth(story.title)
    love.graphics.print(story.title, screenW/2 - titleW/2, 20)
end

drawStoryEpilogue = function(screenW, screenH)
    if not storyState.currentStory then return end

    local story = storyState.currentStory
    local epilogue = storyState.playerWon and story.epilogueWin or story.epilogueLose

    -- Background
    local bgColor = storyState.playerWon and {0.1, 0.25, 0.1} or {0.25, 0.1, 0.1}
    love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3])
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Placeholder character portrait
    love.graphics.setColor(story.characterColor[1], story.characterColor[2], story.characterColor[3], 0.3)
    if epilogue.position == "right" then
        love.graphics.rectangle("fill", screenW * 0.6, screenH * 0.15, screenW * 0.35, screenH * 0.7)
    else
        love.graphics.rectangle("fill", 0.05 * screenW, screenH * 0.15, screenW * 0.35, screenH * 0.7)
    end

    -- Result text
    love.graphics.setColor(storyState.playerWon and {0.3, 0.9, 0.3} or {0.9, 0.3, 0.3})
    love.graphics.setFont(UI.fonts.get(48))
    local resultText = storyState.playerWon and "VICTORY!" or "DEFEAT"
    local resultW = love.graphics.getFont():getWidth(resultText)
    love.graphics.print(resultText, screenW/2 - resultW/2, screenH * 0.15)

    -- Character name
    love.graphics.setColor(story.characterColor)
    love.graphics.setFont(UI.fonts.get(24))
    love.graphics.print(epilogue.character, 40, screenH * 0.4)

    -- Epilogue dialogue box
    love.graphics.setColor(0.1, 0.1, 0.15, 0.95)
    love.graphics.rectangle("fill", 40, screenH * 0.5, screenW - 80, screenH * 0.4, 10, 10)

    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 40, screenH * 0.5, screenW - 80, screenH * 0.4, 10, 10)
    love.graphics.setLineWidth(1)

    -- Dialogue text
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(18))
    love.graphics.printf(epilogue.text, 60, screenH * 0.55, screenW - 120, "left")

    -- Return button using UI component
    if not storyReturnButton then
        storyReturnButton = UI.Button.new({
            x = screenW/2 - 100,
            y = screenH - 80,
            w = 200,
            h = 50,
            text = "Return to Menu",
            variant = "secondary",
            onClick = function()
                local TextRPG = require("textrpg")
                TextRPG.init()
                GameState.current = "textrpg"
            end
        })
    else
        storyReturnButton.x = screenW/2 - 100
        storyReturnButton.y = screenH - 80
    end
    storyReturnButton:draw()
end

function StoryMode.mousepressed(x, y, button)
    if button ~= 1 then return end

    local screenW, screenH = love.graphics.getDimensions()

    if storyState.mode == "storymode" then
        -- Next scene or start game
        if storyState.currentStory and storyState.currentScene < #storyState.currentStory.scenes then
            storyState.currentScene = storyState.currentScene + 1
        else
            -- Start game
            storyState.mode = "game"
            storyState.gameStarted = true
            GameState.isStoryMode = true
            GameState.current = "game"
            Game.setMode(storyState.currentStory.gameMode)
            Game.startNewGame()
        end
    elseif storyState.mode == "epilogue" then
        if storyReturnButton then
            storyReturnButton:mousepressed(x, y, button)
        end
    end
end

function StoryMode.mousereleased(x, y, button)
    if storyState.mode == "epilogue" and storyReturnButton then
        storyReturnButton:mousereleased(x, y, button)
    end
end

function StoryMode.getStories()
    return stories
end

function StoryMode.startGame()
    storyState.mode = "game"
    GameState.isStoryMode = true
    Game.setMode(storyState.currentStory.gameMode)
    Game.startNewGame()
end

function StoryMode.endGame(playerWon)
    storyState.playerWon = playerWon
    storyState.mode = "epilogue"
end

-- Register StoryMode in package.loaded so require("storymode") still works
package.loaded["storymode"] = StoryMode

return Game
