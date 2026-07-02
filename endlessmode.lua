-- Endless Mode - Roguelike poker with scaling difficulty, shop, and bosses
-- Save on exit, persist progress

local EndlessMode = {}
local Cards = require("cards")
local Jokers = require("jokers")

-- Font cache for performance
local FontCache = require("fontcache")
local function getFont(size)
    return FontCache.get(size)
end

-- Boss definitions (Major bosses every 5 rounds)
local BOSSES = {
    {name = "The Blind King", effect = "half_hands", desc = "You only get 2 hands this round", icon = "K", tier = 1},
    {name = "Discard Thief", effect = "no_discards", desc = "No discards allowed", icon = "D", tier = 1},
    {name = "Score Doubler", effect = "double_target", desc = "Target score is doubled", icon = "x2", tier = 1},
    {name = "Hand Limit", effect = "small_hand", desc = "Max 4 cards in hand", icon = "4", tier = 1},
    {name = "Mult Curse", effect = "half_mult", desc = "All multipliers halved", icon = "/2", tier = 2},
    {name = "Chip Drain", effect = "half_chips", desc = "All chips halved", icon = "C-", tier = 2},
    {name = "The Taxman", effect = "coin_penalty", desc = "Lose 50% coins if you lose", icon = "$", tier = 2},
    {name = "Speed Demon", effect = "timer", desc = "30 seconds per hand!", icon = "T", tier = 2},
    {name = "The Void", effect = "no_face_cards", desc = "Face cards score 0 chips", icon = "V", tier = 3},
    {name = "Chaos Lord", effect = "random_discard", desc = "1 random card discarded each hand", icon = "?", tier = 3},
    {name = "The Miser", effect = "no_shop", desc = "Skip next shop phase", icon = "X", tier = 3},
    {name = "Soul Reaper", effect = "joker_disable", desc = "Jokers disabled this round", icon = "R", tier = 3},
}

-- Mini-boss definitions (every 3 rounds, easier than main bosses)
local MINI_BOSSES = {
    {name = "Small Blind", effect = "minus_one_hand", desc = "One less hand this round", icon = "S"},
    {name = "Big Blind", effect = "higher_target", desc = "Target +25%", icon = "B"},
    {name = "The Hook", effect = "discard_random_start", desc = "Start with 2 cards discarded", icon = "H"},
    {name = "The Club", effect = "clubs_debuff", desc = "Clubs worth half", icon = "C"},
    {name = "The Goad", effect = "spades_debuff", desc = "Spades worth half", icon = "G"},
    {name = "The Window", effect = "diamonds_debuff", desc = "Diamonds worth half", icon = "W"},
    {name = "The Manacle", effect = "one_less_card", desc = "Hand size -1 this round", icon = "M"},
}

-- Shop items
local SHOP_CARD_PACKS = {
    {name = "Basic Pack", cost = 25, cards = 3, rarity = "common"},
    {name = "Standard Pack", cost = 50, cards = 3, rarity = "uncommon"},
    {name = "Rare Pack", cost = 100, cards = 3, rarity = "rare"},
    {name = "Epic Pack", cost = 200, cards = 2, rarity = "epic"},
    {name = "Mega Pack", cost = 500, cards = 5, rarity = "rare"},
}

local SHOP_UPGRADES = {
    {id = "extra_hand", name = "+1 Hand", desc = "Start with 1 extra hand", cost = 100, maxLevel = 5},
    {id = "extra_discard", name = "+1 Discard", desc = "Start with 1 extra discard", cost = 75, maxLevel = 5},
    {id = "bigger_hand", name = "+1 Hand Size", desc = "Draw 1 more card", cost = 150, maxLevel = 3},
    {id = "chip_bonus", name = "+10 Chips", desc = "All cards give +10 chips", cost = 200, maxLevel = 10},
    {id = "mult_bonus", name = "+1 Mult", desc = "All hands get +1 mult", cost = 250, maxLevel = 10},
    {id = "interest", name = "Interest", desc = "Gain 10% coins per round (max 50)", cost = 300, maxLevel = 5},
    {id = "boss_armor", name = "Boss Armor", desc = "Reduce boss effects by 25%", cost = 400, maxLevel = 2},
    {id = "card_mastery", name = "Card Mastery", desc = "Cards give +5 chips each", cost = 175, maxLevel = 5},
    {id = "lucky_draw", name = "Lucky Draw", desc = "10% chance for double score", cost = 350, maxLevel = 3},
    {id = "coin_magnet", name = "Coin Magnet", desc = "+20% coins from rounds", cost = 200, maxLevel = 3},
}

-- Special events that can occur
local EVENTS = {
    {id = "double_coins", name = "Golden Hour", desc = "Double coins this round!", chance = 0.1},
    {id = "free_joker", name = "Mysterious Gift", desc = "Free random joker!", chance = 0.05},
    {id = "heal_hand", name = "Second Wind", desc = "+2 extra hands this round!", chance = 0.08},
    {id = "card_blessing", name = "Card Blessing", desc = "All cards +5 chips this round!", chance = 0.1},
    {id = "mult_blessing", name = "Multiplier Surge", desc = "+3 base mult this round!", chance = 0.08},
}

-- Milestones with rewards
local MILESTONES = {
    {round = 10, reward = "coins", amount = 100, name = "Survivor"},
    {round = 25, reward = "coins", amount = 250, name = "Veteran"},
    {round = 50, reward = "coins", amount = 500, name = "Champion"},
    {round = 75, reward = "coins", amount = 750, name = "Legend"},
    {round = 100, reward = "coins", amount = 1000, name = "Immortal"},
}

-- Game state
local state = {
    phase = "playing",  -- playing, shop, boss, gameover, event

    -- Run stats
    round = 1,
    score = 0,
    totalScore = 0,
    targetScore = 200,
    coins = 0,
    highestRound = 0,

    -- Hands
    deck = {},
    hand = {},
    selectedCards = {},
    playedCards = {},
    handsLeft = 4,
    discardsLeft = 3,
    handSize = 8,

    -- Upgrades
    upgrades = {},

    -- Boss
    currentBoss = nil,
    bossActive = false,
    miniBossActive = false,
    timerActive = false,
    timer = 30,
    skipNextShop = false,

    -- Shop
    shopCards = {},
    shopJokers = {},
    shopPacks = {},

    -- Display
    lastHandName = "",
    lastHandScore = 0,
    scorePopups = {},
    notifications = {},

    -- Session jokers (temporary for this run)
    runJokers = {},

    -- Events
    activeEvent = nil,
    eventBonusChips = 0,
    eventBonusMult = 0,
    doubleCoins = false,

    -- Milestones
    claimedMilestones = {},

    -- Animation
    handAnim = 0,
    bossIntroTimer = 0,
    shakeTimer = 0,
    shakeIntensity = 0,

    -- Difficulty scaling
    difficultyMult = 1.0,

    -- Stats for this run
    runStats = {
        handsPlayed = 0,
        totalChips = 0,
        totalMult = 0,
        bossesDefeated = 0,
        cardsPlayed = 0,
    },
}

function EndlessMode.init()
    -- Check for saved run
    if PlayerData.endlessRun and PlayerData.endlessRun.round then
        loadRun()
    else
        startNewRun()
    end
end

function startNewRun()
    state.phase = "playing"
    state.round = 1
    state.score = 0
    state.totalScore = 0
    state.targetScore = 150  -- Start easier
    state.coins = 50  -- Starting coins
    state.handsLeft = 4
    state.discardsLeft = 3
    state.handSize = 8
    state.selectedCards = {}
    state.playedCards = {}
    state.lastHandName = ""
    state.lastHandScore = 0
    state.scorePopups = {}
    state.notifications = {}
    state.currentBoss = nil
    state.bossActive = false
    state.miniBossActive = false
    state.timerActive = false
    state.timer = 30
    state.runJokers = {}
    state.skipNextShop = false

    -- Events
    state.activeEvent = nil
    state.eventBonusChips = 0
    state.eventBonusMult = 0
    state.doubleCoins = false

    -- Milestones
    state.claimedMilestones = {}

    -- Animation
    state.bossIntroTimer = 0
    state.shakeTimer = 0
    state.shakeIntensity = 0

    -- Difficulty
    state.difficultyMult = 1.0
    state.highestRound = 0

    -- Run stats
    state.runStats = {
        handsPlayed = 0,
        totalChips = 0,
        totalMult = 0,
        bossesDefeated = 0,
        cardsPlayed = 0,
    }

    -- Reset upgrades
    state.upgrades = {}
    for _, upgrade in ipairs(SHOP_UPGRADES) do
        state.upgrades[upgrade.id] = 0
    end

    -- Build starting deck
    state.deck = {}
    for _, card in ipairs(Cards.basicCards) do
        table.insert(state.deck, Cards.copyCard(card))
    end

    shuffleDeck()
    dealHand()

    -- Check for random event on first round
    checkForEvent()

    saveRun()
end

-- Check for random event
function checkForEvent()
    state.activeEvent = nil
    state.eventBonusChips = 0
    state.eventBonusMult = 0
    state.doubleCoins = false

    for _, event in ipairs(EVENTS) do
        if math.random() < event.chance then
            state.activeEvent = event
            addNotification(event.name .. ": " .. event.desc, {0.3, 0.9, 0.4})

            -- Apply event effects
            if event.id == "double_coins" then
                state.doubleCoins = true
            elseif event.id == "heal_hand" then
                state.handsLeft = state.handsLeft + 2
            elseif event.id == "card_blessing" then
                state.eventBonusChips = 5
            elseif event.id == "mult_blessing" then
                state.eventBonusMult = 3
            elseif event.id == "free_joker" then
                -- Give a random joker
                if #state.runJokers < 5 then
                    local ownedIds = {}
                    for _, j in ipairs(state.runJokers) do
                        table.insert(ownedIds, j.id)
                    end
                    local newJokers = Jokers.getRandomForShop(1, ownedIds)
                    if #newJokers > 0 and newJokers[1] and newJokers[1].id and newJokers[1].name then
                        table.insert(state.runJokers, {id = newJokers[1].id})
                        addNotification("Got " .. newJokers[1].name .. "!", {0.9, 0.7, 0.2})
                    end
                end
            end
            break  -- Only one event per round
        end
    end
end

-- Add a notification to display
function addNotification(text, color)
    table.insert(state.notifications, {
        text = text,
        color = color or {1, 1, 1},
        timer = 3,
        y = 0
    })
end

-- Check and award milestones
function checkMilestones()
    for _, milestone in ipairs(MILESTONES) do
        if state.round >= milestone.round and not state.claimedMilestones[milestone.round] then
            state.claimedMilestones[milestone.round] = true
            if milestone.reward == "coins" then
                state.coins = state.coins + milestone.amount
                addNotification("MILESTONE: " .. milestone.name .. "! +" .. milestone.amount .. " coins!", {1, 0.8, 0.2})
            end
        end
    end
end

function loadRun()
    local run = PlayerData.endlessRun
    state.round = run.round or 1
    state.score = run.score or 0
    state.totalScore = run.totalScore or 0
    state.targetScore = run.targetScore or 200
    state.coins = run.coins or 0
    state.handsLeft = run.handsLeft or 4
    state.discardsLeft = run.discardsLeft or 3
    state.handSize = run.handSize or 8
    state.upgrades = run.upgrades or {}
    state.runJokers = run.runJokers or {}
    state.phase = run.phase or "playing"
    state.currentBoss = run.currentBoss
    state.bossActive = run.bossActive or false
    state.miniBossActive = run.miniBossActive or false
    state.claimedMilestones = run.claimedMilestones or {}
    state.runStats = run.runStats or {
        handsPlayed = 0,
        totalChips = 0,
        totalMult = 0,
        bossesDefeated = 0,
        cardsPlayed = 0,
    }
    state.highestRound = run.highestRound or state.round

    -- Reset visual state
    state.notifications = {}
    state.scorePopups = {}
    state.bossIntroTimer = 0
    state.shakeTimer = 0
    state.shakeIntensity = 0
    state.activeEvent = nil
    state.eventBonusChips = 0
    state.eventBonusMult = 0
    state.doubleCoins = false

    -- Rebuild deck
    state.deck = {}
    if run.deck then
        for _, cardData in ipairs(run.deck) do
            table.insert(state.deck, cardData)
        end
    else
        for _, card in ipairs(Cards.basicCards) do
            table.insert(state.deck, Cards.copyCard(card))
        end
    end

    state.selectedCards = {}
    state.playedCards = {}

    if state.phase == "playing" then
        shuffleDeck()
        dealHand()
    elseif state.phase == "shop" then
        generateShop()
    end
end

function saveRun()
    PlayerData.endlessRun = {
        round = state.round,
        score = state.score,
        totalScore = state.totalScore,
        targetScore = state.targetScore,
        coins = state.coins,
        handsLeft = state.handsLeft,
        discardsLeft = state.discardsLeft,
        handSize = state.handSize,
        upgrades = state.upgrades,
        runJokers = state.runJokers,
        deck = state.deck,
        phase = state.phase,
        currentBoss = state.currentBoss,
        bossActive = state.bossActive,
        miniBossActive = state.miniBossActive,
        claimedMilestones = state.claimedMilestones,
        runStats = state.runStats,
        highestRound = state.highestRound,
    }
    savePlayerData()
end

function shuffleDeck()
    for i = #state.deck, 2, -1 do
        local j = math.random(i)
        state.deck[i], state.deck[j] = state.deck[j], state.deck[i]
    end
end

function dealHand()
    state.hand = {}
    state.selectedCards = {}
    local handSize = state.handSize + (state.upgrades.bigger_hand or 0)
    for i = 1, math.min(handSize, #state.deck) do
        table.insert(state.hand, table.remove(state.deck, 1))
    end
end

function applyBossEffect()
    if not state.currentBoss then return end

    local effect = state.currentBoss.effect
    local armorLevel = state.upgrades.boss_armor or 0
    local reduction = armorLevel * 0.25  -- 25% reduction per level

    if effect == "half_hands" then
        local hands = 2
        if reduction > 0 then hands = hands + math.floor(2 * reduction) end
        state.handsLeft = math.max(2, hands)
    elseif effect == "no_discards" then
        state.discardsLeft = armorLevel > 0 and 1 or 0
    elseif effect == "double_target" then
        local mult = 2 - reduction
        state.targetScore = math.floor(state.targetScore * mult)
    elseif effect == "small_hand" then
        local size = 4 + armorLevel
        state.handSize = size
        while #state.hand > size do
            table.insert(state.deck, table.remove(state.hand))
        end
    elseif effect == "timer" then
        state.timerActive = true
        state.timer = 30 + (armorLevel * 10)
    elseif effect == "no_face_cards" then
        -- Face cards debuff applied in scoring
    elseif effect == "random_discard" then
        -- Applied each hand
    elseif effect == "no_shop" then
        state.skipNextShop = true
    elseif effect == "joker_disable" then
        -- Jokers disabled in scoring
    -- Mini-boss effects
    elseif effect == "minus_one_hand" then
        state.handsLeft = state.handsLeft - 1
    elseif effect == "higher_target" then
        state.targetScore = math.floor(state.targetScore * 1.25)
    elseif effect == "discard_random_start" then
        -- Discard 2 random cards from hand
        for i = 1, 2 do
            if #state.hand > 3 then
                local idx = math.random(#state.hand)
                table.insert(state.deck, table.remove(state.hand, idx))
            end
        end
    elseif effect == "clubs_debuff" or effect == "spades_debuff" or effect == "diamonds_debuff" then
        -- Applied in scoring
    elseif effect == "one_less_card" then
        state.handSize = state.handSize - 1
        if #state.hand > state.handSize then
            table.insert(state.deck, table.remove(state.hand))
        end
    end

    -- Show boss intro animation
    state.bossIntroTimer = 2
    state.shakeTimer = 0.5
    state.shakeIntensity = 5
end

function playHand()
    if #state.selectedCards < 1 then return end
    if state.handsLeft <= 0 then return end

    state.handsLeft = state.handsLeft - 1
    state.runStats.handsPlayed = state.runStats.handsPlayed + 1

    -- Get played cards
    state.playedCards = {}
    table.sort(state.selectedCards)
    for i = #state.selectedCards, 1, -1 do
        local idx = state.selectedCards[i]
        table.insert(state.playedCards, 1, table.remove(state.hand, idx))
    end
    state.selectedCards = {}
    state.runStats.cardsPlayed = state.runStats.cardsPlayed + #state.playedCards

    -- Random discard boss effect
    if state.bossActive and state.currentBoss and state.currentBoss.effect == "random_discard" then
        if #state.hand > 0 then
            local idx = math.random(#state.hand)
            table.insert(state.deck, table.remove(state.hand, idx))
            addNotification("Chaos Lord discarded a card!", {0.9, 0.3, 0.3})
        end
    end

    -- Evaluate hand
    local handName, chips, mult = Cards.evaluateHand(state.playedCards)

    -- Apply card bonuses
    for _, card in ipairs(state.playedCards) do
        local cardChips = card.chips or 0
        local cardMult = card.mult or 0

        -- Boss suit debuffs
        if state.bossActive and state.currentBoss then
            if state.currentBoss.effect == "clubs_debuff" and card.suit == "clubs" then
                cardChips = math.floor(cardChips / 2)
            elseif state.currentBoss.effect == "spades_debuff" and card.suit == "spades" then
                cardChips = math.floor(cardChips / 2)
            elseif state.currentBoss.effect == "diamonds_debuff" and card.suit == "diamonds" then
                cardChips = math.floor(cardChips / 2)
            elseif state.currentBoss.effect == "no_face_cards" then
                local faceCards = {J = true, Q = true, K = true}
                if faceCards[card.rank] then
                    cardChips = 0
                end
            end
        end

        chips = chips + cardChips
        mult = mult + cardMult
    end

    -- Apply upgrade bonuses
    chips = chips + (state.upgrades.chip_bonus or 0) * 10
    chips = chips + (state.upgrades.card_mastery or 0) * 5 * #state.playedCards
    mult = mult + (state.upgrades.mult_bonus or 0)

    -- Apply event bonuses
    chips = chips + state.eventBonusChips * #state.playedCards
    mult = mult + state.eventBonusMult

    -- Apply boss effects
    if state.bossActive and state.currentBoss then
        if state.currentBoss.effect == "half_mult" then
            mult = math.floor(mult / 2)
        elseif state.currentBoss.effect == "half_chips" then
            chips = math.floor(chips / 2)
        end
    end

    -- Apply run jokers (unless disabled by boss)
    local jokersDisabled = state.bossActive and state.currentBoss and state.currentBoss.effect == "joker_disable"
    if not jokersDisabled then
        for _, jokerData in ipairs(state.runJokers) do
            local joker = Jokers.getById(jokerData.id)
            if joker then
                local context = {
                    playedCards = state.playedCards,
                    handName = handName,
                    chips = chips,
                    mult = mult
                }
                chips, mult = Jokers.applyAll({jokerData}, context, chips, mult)
            end
        end
    end

    -- Track stats
    state.runStats.totalChips = state.runStats.totalChips + chips
    state.runStats.totalMult = state.runStats.totalMult + mult

    local handScore = chips * mult

    -- Lucky draw upgrade
    if state.upgrades.lucky_draw and state.upgrades.lucky_draw > 0 then
        local luckyChance = state.upgrades.lucky_draw * 0.1
        if math.random() < luckyChance then
            handScore = handScore * 2
            addNotification("LUCKY DRAW! Double score!", {1, 0.9, 0.2})
        end
    end

    state.score = state.score + handScore
    state.totalScore = state.totalScore + handScore
    state.lastHandName = handName
    state.lastHandScore = handScore
    state.handAnim = 1

    -- Score popup
    table.insert(state.scorePopups, {
        score = handScore,
        name = handName,
        x = love.graphics.getWidth() / 2,
        y = 300,
        timer = 2,
        chips = chips,
        mult = mult
    })

    -- Put played cards back into deck (for endless play)
    for _, card in ipairs(state.playedCards) do
        table.insert(state.deck, card)
    end

    -- Draw new cards
    shuffleDeck()
    local cardsToDraw = math.min(#state.playedCards, #state.deck, state.handSize + (state.upgrades.bigger_hand or 0) - #state.hand)
    for i = 1, cardsToDraw do
        if #state.deck > 0 then
            table.insert(state.hand, table.remove(state.deck, 1))
        end
    end

    -- Check round end
    checkRoundEnd()
end

function discardCards()
    if #state.selectedCards < 1 then return end
    if state.discardsLeft <= 0 then return end

    state.discardsLeft = state.discardsLeft - 1

    -- Put discards back in deck
    table.sort(state.selectedCards)
    for i = #state.selectedCards, 1, -1 do
        local idx = state.selectedCards[i]
        table.insert(state.deck, table.remove(state.hand, idx))
    end
    state.selectedCards = {}

    -- Draw new cards
    shuffleDeck()
    local handSize = state.handSize + (state.upgrades.bigger_hand or 0)
    local cardsToDraw = math.min(handSize - #state.hand, #state.deck)
    for i = 1, cardsToDraw do
        if #state.deck > 0 then
            table.insert(state.hand, table.remove(state.deck, 1))
        end
    end
end

function checkRoundEnd()
    if state.score >= state.targetScore then
        -- Won round!
        local baseReward = 10 + state.round * 5
        local coinReward = baseReward

        -- Coin magnet upgrade
        if state.upgrades.coin_magnet and state.upgrades.coin_magnet > 0 then
            coinReward = math.floor(coinReward * (1 + state.upgrades.coin_magnet * 0.2))
        end

        -- Double coins event
        if state.doubleCoins then
            coinReward = coinReward * 2
            addNotification("Golden Hour: Double coins!", {1, 0.9, 0.2})
        end

        -- Boss defeat bonus
        if state.bossActive then
            local bossBonus = 50 + state.round * 10
            coinReward = coinReward + bossBonus
            state.runStats.bossesDefeated = state.runStats.bossesDefeated + 1
            addNotification("Boss defeated! +" .. bossBonus .. " bonus coins!", {0.9, 0.5, 0.9})
        end

        -- Interest bonus
        if state.upgrades.interest and state.upgrades.interest > 0 then
            local interest = math.min(50, math.floor(state.coins * 0.1 * state.upgrades.interest))
            coinReward = coinReward + interest
        end

        state.coins = state.coins + coinReward

        -- Track win
        PlayerData.wins = PlayerData.wins + 1

        -- Award crystals for endless mode progress (scales with round)
        local crystalReward = 3 + math.floor(state.round / 3)
        PlayerData.crystals = (PlayerData.crystals or 0) + crystalReward
        addNotification("+" .. crystalReward .. " Crystals!", {0.4, 0.8, 1})

        -- Update highest round
        if state.round > state.highestRound then
            state.highestRound = state.round
        end

        -- Check milestones
        state.round = state.round + 1
        checkMilestones()

        -- Check if shop should be skipped (boss effect)
        if state.skipNextShop then
            state.skipNextShop = false
            addNotification("The Miser's curse: Shop skipped!", {0.9, 0.3, 0.3})
            continueToNextRound()
        else
            -- Go to shop
            state.phase = "shop"
            generateShop()
        end

        saveRun()

    elseif state.handsLeft <= 0 then
        -- Lost!
        if state.bossActive and state.currentBoss and state.currentBoss.effect == "coin_penalty" then
            state.coins = math.floor(state.coins * 0.5)
        end

        -- Update player's endless record
        if not PlayerData.endlessRecord or state.round > PlayerData.endlessRecord then
            PlayerData.endlessRecord = state.round
            addNotification("NEW RECORD: Round " .. state.round .. "!", {1, 0.8, 0.2})
        end

        state.phase = "gameover"
        PlayerData.endlessRun = nil  -- Clear save
        savePlayerData()
    end
end

function generateShop()
    state.shopCards = {}
    state.shopJokers = {}
    state.shopPacks = {}

    -- Generate card packs
    for i = 1, 3 do
        local pack = SHOP_CARD_PACKS[math.random(#SHOP_CARD_PACKS)]
        table.insert(state.shopPacks, {
            name = pack.name,
            cost = pack.cost + state.round * 5,  -- Scale cost
            cards = pack.cards,
            rarity = pack.rarity
        })
    end

    -- Generate individual cards
    for i = 1, 4 do
        local roll = math.random()
        local card
        if roll < 0.5 then
            card = Cards.copyCard(Cards.basicCards[math.random(#Cards.basicCards)])
        elseif roll < 0.85 then
            card = Cards.copyCard(Cards.rareCards[math.random(#Cards.rareCards)])
        else
            local epics = {}
            for _, c in ipairs(Cards.rareCards) do
                if c.rarity == "epic" or c.rarity == "legendary" then
                    table.insert(epics, c)
                end
            end
            if #epics > 0 then
                card = Cards.copyCard(epics[math.random(#epics)])
            else
                card = Cards.copyCard(Cards.rareCards[math.random(#Cards.rareCards)])
            end
        end

        local price = 15 + state.round * 3
        if card.rarity == "rare" then price = price + 20 end
        if card.rarity == "epic" then price = price + 50 end
        if card.rarity == "legendary" then price = price + 100 end

        table.insert(state.shopCards, {card = card, cost = price})
    end

    -- Generate jokers
    local ownedIds = {}
    for _, j in ipairs(state.runJokers) do
        table.insert(ownedIds, j.id)
    end
    state.shopJokers = Jokers.getRandomForShop(3, ownedIds)
    -- Scale joker costs
    for _, joker in ipairs(state.shopJokers) do
        joker.cost = joker.cost + state.round * 10
    end
end

function buyPack(packIndex)
    local pack = state.shopPacks[packIndex]
    if not pack or state.coins < pack.cost then return end

    state.coins = state.coins - pack.cost

    -- Generate cards based on rarity
    local rarityPool = {}
    if pack.rarity == "common" then
        rarityPool = Cards.basicCards
    elseif pack.rarity == "uncommon" or pack.rarity == "rare" then
        rarityPool = Cards.rareCards
    else
        for _, c in ipairs(Cards.rareCards) do
            if c.rarity == pack.rarity or c.rarity == "epic" or c.rarity == "legendary" then
                table.insert(rarityPool, c)
            end
        end
        if #rarityPool == 0 then rarityPool = Cards.rareCards end
    end

    -- Add cards to deck
    for i = 1, pack.cards do
        if #rarityPool > 0 then
            local card = Cards.copyCard(rarityPool[math.random(#rarityPool)])
            table.insert(state.deck, card)
        end
    end

    table.remove(state.shopPacks, packIndex)
    saveRun()
end

function buyCard(cardIndex)
    local shopCard = state.shopCards[cardIndex]
    if not shopCard or state.coins < shopCard.cost then return end

    state.coins = state.coins - shopCard.cost
    table.insert(state.deck, shopCard.card)
    table.remove(state.shopCards, cardIndex)
    saveRun()
end

function buyJoker(jokerIndex)
    local joker = state.shopJokers[jokerIndex]
    if not joker or state.coins < joker.cost then return end
    if #state.runJokers >= 5 then return end  -- Max 5 jokers

    state.coins = state.coins - joker.cost
    table.insert(state.runJokers, {id = joker.id})
    table.remove(state.shopJokers, jokerIndex)
    saveRun()
end

function buyUpgrade(upgradeId)
    local upgrade = nil
    for _, u in ipairs(SHOP_UPGRADES) do
        if u.id == upgradeId then
            upgrade = u
            break
        end
    end
    if not upgrade then return end

    local currentLevel = state.upgrades[upgradeId] or 0
    if currentLevel >= upgrade.maxLevel then return end

    local cost = upgrade.cost * (currentLevel + 1)
    if state.coins < cost then return end

    state.coins = state.coins - cost
    state.upgrades[upgradeId] = currentLevel + 1
    saveRun()
end

function continueToNextRound()
    state.phase = "playing"
    state.score = 0

    -- More aggressive difficulty scaling
    -- Starts at 150, increases exponentially
    local baseTarget = 150
    local roundScaling = state.round * 40  -- Linear component
    local exponentialScaling = math.floor(math.pow(1.08, state.round) * 10)  -- Exponential component
    state.targetScore = baseTarget + roundScaling + exponentialScaling

    -- Reset round state
    state.handsLeft = 4 + (state.upgrades.extra_hand or 0)
    state.discardsLeft = 3 + (state.upgrades.extra_discard or 0)
    state.handSize = 8
    state.currentBoss = nil
    state.bossActive = false
    state.miniBossActive = false
    state.timerActive = false

    -- Reset event bonuses
    state.eventBonusChips = 0
    state.eventBonusMult = 0
    state.doubleCoins = false
    state.activeEvent = nil

    -- Check for boss round (every 5 rounds)
    if state.round % 5 == 0 then
        -- Select boss based on tier and round
        local availableBosses = {}
        local maxTier = math.min(3, math.ceil(state.round / 15))  -- Unlock higher tiers as rounds progress

        for _, boss in ipairs(BOSSES) do
            if boss.tier <= maxTier then
                table.insert(availableBosses, boss)
            end
        end

        if #availableBosses > 0 then
            state.currentBoss = availableBosses[math.random(#availableBosses)]
            state.bossActive = true
            state.targetScore = math.floor(state.targetScore * 1.3)  -- Boss rounds are 30% harder
            applyBossEffect()
        end
    -- Mini-boss every 3 rounds (but not on boss rounds)
    elseif state.round % 3 == 0 then
        if #MINI_BOSSES > 0 then
            state.currentBoss = MINI_BOSSES[math.random(#MINI_BOSSES)]
            state.miniBossActive = true
            state.bossActive = true
            applyBossEffect()
        end
    end

    -- Check for random events (not on boss rounds)
    if not state.bossActive then
        checkForEvent()
    end

    shuffleDeck()
    dealHand()
    saveRun()
end

-- Calculate the target score for a given round (for display)
function calculateTargetScore(round)
    local baseTarget = 150
    local roundScaling = round * 40
    local exponentialScaling = math.floor(math.pow(1.08, round) * 10)
    return baseTarget + roundScaling + exponentialScaling
end

function EndlessMode.update(dt)
    -- Update animations
    if state.handAnim > 0 then
        state.handAnim = state.handAnim - dt * 2
    end

    -- Boss intro animation
    if state.bossIntroTimer > 0 then
        state.bossIntroTimer = state.bossIntroTimer - dt
    end

    -- Screen shake
    if state.shakeTimer > 0 then
        state.shakeTimer = state.shakeTimer - dt
    end

    -- Update popups
    for i = #state.scorePopups, 1, -1 do
        local popup = state.scorePopups[i]
        popup.timer = popup.timer - dt
        popup.y = popup.y - dt * 40
        if popup.timer <= 0 then
            table.remove(state.scorePopups, i)
        end
    end

    -- Update notifications
    for i = #state.notifications, 1, -1 do
        local notif = state.notifications[i]
        notif.timer = notif.timer - dt
        notif.y = notif.y + dt * 20  -- Slide down
        if notif.timer <= 0 then
            table.remove(state.notifications, i)
        end
    end

    -- Timer for boss effect
    if state.timerActive and state.phase == "playing" then
        state.timer = state.timer - dt
        if state.timer <= 0 then
            -- Auto-play worst hand or lose hand
            if #state.hand > 0 then
                state.selectedCards = {1}  -- Select first card
                playHand()
            end
            state.timer = 30 + ((state.upgrades.boss_armor or 0) * 10)
        end
    end
end

function EndlessMode.draw()
    local screenW, screenH = love.graphics.getDimensions()

    -- Background
    love.graphics.setColor(0.08, 0.1, 0.12)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    if state.phase == "playing" then
        drawPlayingPhase(screenW, screenH)
    elseif state.phase == "shop" then
        drawShopPhase(screenW, screenH)
    elseif state.phase == "gameover" then
        drawGameOver(screenW, screenH)
    end

    -- Score popups
    for _, popup in ipairs(state.scorePopups) do
        local alpha = math.min(1, popup.timer)
        love.graphics.setColor(1, 0.9, 0.3, alpha)
        love.graphics.setFont(getFont(28))
        local text = popup.name .. " - " .. popup.score
        local textW = love.graphics.getFont():getWidth(text)
        love.graphics.print(text, popup.x - textW/2, popup.y)
    end
end

function drawPlayingPhase(screenW, screenH)
    -- Apply screen shake with push/pop to restore state
    love.graphics.push()
    if state.shakeTimer > 0 then
        local shakeX = math.random(-state.shakeIntensity, state.shakeIntensity)
        local shakeY = math.random(-state.shakeIntensity, state.shakeIntensity)
        love.graphics.translate(shakeX, shakeY)
    end

    -- Header gradient
    love.graphics.setColor(0.12, 0.15, 0.2)
    love.graphics.rectangle("fill", 0, 0, screenW, 70)
    love.graphics.setColor(0.08, 0.1, 0.15, 0.8)
    love.graphics.rectangle("fill", 0, 60, screenW, 10)

    love.graphics.setFont(getFont(24))
    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.print("ENDLESS MODE", 20, 10)

    love.graphics.setFont(getFont(18))
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Round " .. state.round, 20, 40)

    -- Progress bar for score
    local progressWidth = 200
    local progressX = 150
    local progress = math.min(1, state.score / state.targetScore)
    love.graphics.setColor(0.2, 0.2, 0.25)
    love.graphics.rectangle("fill", progressX, 42, progressWidth, 18, 4, 4)
    love.graphics.setColor(0.3, 0.9, 0.3)
    love.graphics.rectangle("fill", progressX, 42, progressWidth * progress, 18, 4, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(12))
    love.graphics.printf(string.format("%d / %d", state.score, state.targetScore), progressX, 45, progressWidth, "center")

    love.graphics.setFont(getFont(18))
    love.graphics.setColor(0.9, 0.8, 0.2)
    love.graphics.print("Coins: " .. state.coins, 380, 40)

    love.graphics.setColor(0.5, 0.7, 1)
    love.graphics.print("Hands: " .. state.handsLeft, 510, 40)

    love.graphics.setColor(0.9, 0.5, 0.3)
    love.graphics.print("Discards: " .. state.discardsLeft, 620, 40)

    love.graphics.setColor(0.9, 0.9, 0.3)
    love.graphics.print("Total: " .. state.totalScore, 760, 40)

    -- Record display
    if PlayerData.endlessRecord then
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.setFont(getFont(12))
        love.graphics.print("Record: Round " .. PlayerData.endlessRecord, 880, 45)
    end

    -- Timer (if boss effect active)
    if state.timerActive then
        local timerColor = state.timer > 10 and {0.3, 0.9, 0.3} or {0.9, 0.3, 0.3}
        love.graphics.setColor(timerColor)
        love.graphics.setFont(getFont(24))
        love.graphics.printf(string.format("%.1f", state.timer), screenW - 100, 35, 80, "center")
    end

    -- Event indicator
    if state.activeEvent then
        love.graphics.setColor(0.2, 0.6, 0.3, 0.9)
        love.graphics.rectangle("fill", 10, 75, 180, 30, 6, 6)
        love.graphics.setColor(0.5, 1, 0.6)
        love.graphics.setFont(getFont(12))
        love.graphics.printf(state.activeEvent.name, 15, 82, 170, "center")
    end

    -- Boss/Mini-boss indicator with animation
    if state.bossActive and state.currentBoss then
        local bossAlpha = state.bossIntroTimer > 0 and (0.5 + 0.5 * math.sin(state.bossIntroTimer * 10)) or 0.9
        local isMini = state.miniBossActive

        if isMini then
            love.graphics.setColor(0.7, 0.4, 0.1, bossAlpha)
        else
            love.graphics.setColor(0.9, 0.2, 0.2, bossAlpha)
        end

        local bossBoxY = state.bossIntroTimer > 0 and (80 - state.bossIntroTimer * 30) or 80
        love.graphics.rectangle("fill", screenW/2 - 200, bossBoxY, 400, 55, 8, 8)

        -- Boss icon
        love.graphics.setColor(1, 1, 1, bossAlpha)
        love.graphics.setFont(getFont(28))
        love.graphics.print(state.currentBoss.icon or "!", screenW/2 - 180, bossBoxY + 10)

        love.graphics.setColor(1, 0.9, 0.3)
        love.graphics.setFont(getFont(18))
        local prefix = isMini and "MINI-BOSS: " or "BOSS: "
        love.graphics.printf(prefix .. state.currentBoss.name, screenW/2 - 160, bossBoxY + 8, 350, "center")
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(14))
        love.graphics.printf(state.currentBoss.desc, screenW/2 - 160, bossBoxY + 30, 350, "center")
    end

    -- Draw notifications
    for i, notif in ipairs(state.notifications) do
        local alpha = math.min(1, notif.timer)
        local y = 140 + (i - 1) * 30 + notif.y
        love.graphics.setColor(notif.color[1], notif.color[2], notif.color[3], alpha)
        love.graphics.setFont(getFont(14))
        love.graphics.printf(notif.text, 0, y, screenW, "center")
    end

    -- Run jokers display
    if #state.runJokers > 0 then
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.setFont(getFont(14))
        love.graphics.print("Jokers:", screenW - 300, 10)

        for i, jokerData in ipairs(state.runJokers) do
            local joker = Jokers.getById(jokerData.id)
            if joker then
                local jx = screenW - 300 + (i-1) * 55
                local jy = 30

                local rarityColor = Jokers.rarityColors[joker.rarity] or {0.5, 0.5, 0.5}
                love.graphics.setColor(0.15, 0.12, 0.2)
                love.graphics.rectangle("fill", jx, jy, 50, 35, 4, 4)
                love.graphics.setColor(rarityColor)
                love.graphics.rectangle("line", jx, jy, 50, 35, 4, 4)
                love.graphics.setFont(getFont(10))
                love.graphics.print(joker.name:sub(1, 7), jx + 3, jy + 12)
            end
        end
    end

    -- Last hand result
    if state.lastHandName ~= "" then
        love.graphics.setColor(0.9, 0.7, 0.2)
        love.graphics.setFont(getFont(20))
        local resultText = state.lastHandName .. " - " .. state.lastHandScore
        local textW = love.graphics.getFont():getWidth(resultText)
        love.graphics.print(resultText, screenW/2 - textW/2, 150)
    end

    -- Draw hand
    local handY = screenH - 200
    local cardW = 90
    local cardH = 130
    local cardSpacing = 100
    local startX = (screenW - #state.hand * cardSpacing) / 2

    local mx, my = love.mouse.getPosition()

    for i, card in ipairs(state.hand) do
        local x = startX + (i - 1) * cardSpacing
        local y = handY

        local selected = false
        for _, idx in ipairs(state.selectedCards) do
            if idx == i then
                selected = true
                break
            end
        end

        if selected then y = y - 25 end

        local hovered = mx >= x and mx <= x + cardW and my >= y and my <= y + cardH
        local rarity = Cards.rarities[card.rarity] or Cards.rarities.common

        -- Card background
        love.graphics.setColor(0.95, 0.95, 0.9)
        love.graphics.rectangle("fill", x, y, cardW, cardH, 6, 6)

        -- Border
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
        love.graphics.rectangle("line", x, y, cardW, cardH, 6, 6)
        love.graphics.setLineWidth(1)

        -- Card content
        local suitColor = Cards.suitColors[card.suit] or {0.5, 0.3, 0.8}
        love.graphics.setColor(suitColor)

        love.graphics.setFont(getFont(18))
        local symbol = Cards.suitSymbols[card.suit] or "?"
        love.graphics.print(card.rank .. symbol, x + 5, y + 5)

        love.graphics.setFont(getFont(32))
        love.graphics.print(symbol, x + cardW/2 - 14, y + cardH/2 - 20)

        -- Ability indicator
        if card.ability and card.ability ~= "none" then
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.rectangle("fill", x, y + cardH - 18, cardW, 18, 0, 0, 6, 6)
            love.graphics.setColor(0.9, 0.7, 0.2)
            love.graphics.setFont(getFont(10))
            local abilityName = Cards.abilities[card.ability] and Cards.abilities[card.ability].name or card.ability
            love.graphics.print(abilityName:sub(1, 10), x + 3, y + cardH - 15)
        end
    end

    -- Hand preview
    if #state.selectedCards > 0 then
        local previewCards = {}
        for _, idx in ipairs(state.selectedCards) do
            table.insert(previewCards, state.hand[idx])
        end
        local handName, chips, mult = Cards.evaluateHand(previewCards)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(16))
        love.graphics.printf("Preview: " .. handName .. " (" .. chips .. " x " .. mult .. ")", 0, handY - 35, screenW, "center")
    end

    -- Buttons
    local buttonY = screenH - 55
    local buttonW = 130
    local buttonH = 45

    -- Play button
    local playX = screenW/2 - buttonW - 20
    local canPlay = #state.selectedCards > 0 and state.handsLeft > 0
    local playHover = mx >= playX and mx <= playX + buttonW and my >= buttonY and my <= buttonY + buttonH

    love.graphics.setColor(canPlay and (playHover and {0.3, 0.8, 0.4} or {0.2, 0.6, 0.3}) or {0.3, 0.3, 0.3})
    love.graphics.rectangle("fill", playX, buttonY, buttonW, buttonH, 8, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(18))
    love.graphics.print("Play Hand", playX + 20, buttonY + 12)

    -- Discard button
    local discardX = screenW/2 + 20
    local canDiscard = #state.selectedCards > 0 and state.discardsLeft > 0
    local discardHover = mx >= discardX and mx <= discardX + buttonW and my >= buttonY and my <= buttonY + buttonH

    love.graphics.setColor(canDiscard and (discardHover and {0.8, 0.5, 0.3} or {0.6, 0.4, 0.2}) or {0.3, 0.3, 0.3})
    love.graphics.rectangle("fill", discardX, buttonY, buttonW, buttonH, 8, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Discard", discardX + 30, buttonY + 12)

    -- Restore graphics state after shake
    love.graphics.pop()
end

function drawShopPhase(screenW, screenH)
    -- Header
    love.graphics.setColor(0.15, 0.1, 0.2)
    love.graphics.rectangle("fill", 0, 0, screenW, 80)

    love.graphics.setFont(getFont(28))
    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.print("SHOP - Round " .. state.round, 30, 15)

    love.graphics.setFont(getFont(20))
    love.graphics.setColor(0.9, 0.8, 0.2)
    love.graphics.print("Coins: " .. state.coins, 30, 50)

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.print("Deck: " .. #state.deck .. " cards", 200, 50)

    local mx, my = love.mouse.getPosition()

    -- Card Packs section
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.setFont(getFont(18))
    love.graphics.print("Card Packs:", 30, 100)

    for i, pack in ipairs(state.shopPacks) do
        local x = 30 + (i-1) * 180
        local y = 130
        local w, h = 160, 80

        local hovered = mx >= x and mx <= x + w and my >= y and my <= y + h
        local canBuy = state.coins >= pack.cost

        love.graphics.setColor(canBuy and (hovered and {0.3, 0.4, 0.5} or {0.2, 0.25, 0.35}) or {0.15, 0.15, 0.2})
        love.graphics.rectangle("fill", x, y, w, h, 8, 8)
        love.graphics.setColor(canBuy and {0.5, 0.6, 0.8} or {0.3, 0.3, 0.4})
        love.graphics.rectangle("line", x, y, w, h, 8, 8)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(14))
        love.graphics.printf(pack.name, x, y + 10, w, "center")
        love.graphics.setFont(getFont(12))
        love.graphics.printf(pack.cards .. " cards", x, y + 30, w, "center")
        love.graphics.setColor(0.9, 0.8, 0.2)
        love.graphics.printf(pack.cost .. " coins", x, y + 50, w, "center")
    end

    -- Individual Cards section
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.setFont(getFont(18))
    love.graphics.print("Cards:", 30, 230)

    for i, shopCard in ipairs(state.shopCards) do
        local card = shopCard.card
        local x = 30 + (i-1) * 110
        local y = 260
        local w, h = 90, 130

        local hovered = mx >= x and mx <= x + w and my >= y and my <= y + h + 25
        local canBuy = state.coins >= shopCard.cost
        local rarity = Cards.rarities[card.rarity] or Cards.rarities.common

        -- Card
        love.graphics.setColor(0.95, 0.95, 0.9)
        love.graphics.rectangle("fill", x, y, w, h, 5, 5)
        love.graphics.setColor(hovered and {1, 0.9, 0.3} or rarity.color)
        love.graphics.setLineWidth(hovered and 3 or 2)
        love.graphics.rectangle("line", x, y, w, h, 5, 5)
        love.graphics.setLineWidth(1)

        local suitColor = Cards.suitColors[card.suit] or {0.5, 0.3, 0.8}
        love.graphics.setColor(suitColor)
        love.graphics.setFont(getFont(16))
        local symbol = Cards.suitSymbols[card.suit] or "?"
        love.graphics.print(card.rank .. symbol, x + 5, y + 5)
        love.graphics.setFont(getFont(28))
        love.graphics.print(symbol, x + w/2 - 12, y + h/2 - 18)

        -- Price
        love.graphics.setColor(canBuy and {0.3, 0.7, 0.3} or {0.5, 0.3, 0.3})
        love.graphics.rectangle("fill", x, y + h + 5, w, 20, 4, 4)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(12))
        love.graphics.printf(shopCard.cost, x, y + h + 8, w, "center")
    end

    -- Jokers section
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.setFont(getFont(18))
    love.graphics.print("Jokers (" .. #state.runJokers .. "/5):", 30, 430)

    for i, joker in ipairs(state.shopJokers) do
        local x = 30 + (i-1) * 130
        local y = 460
        local w, h = 110, 100

        local hovered = mx >= x and mx <= x + w and my >= y and my <= y + h + 25
        local canBuy = state.coins >= joker.cost and #state.runJokers < 5
        local rarityColor = Jokers.rarityColors[joker.rarity] or {0.5, 0.5, 0.5}

        love.graphics.setColor(0.15, 0.12, 0.2)
        love.graphics.rectangle("fill", x, y, w, h, 6, 6)
        love.graphics.setColor(hovered and {1, 0.9, 0.3} or rarityColor)
        love.graphics.setLineWidth(hovered and 3 or 2)
        love.graphics.rectangle("line", x, y, w, h, 6, 6)
        love.graphics.setLineWidth(1)

        love.graphics.setColor(rarityColor)
        love.graphics.setFont(getFont(24))
        love.graphics.print("J", x + w/2 - 8, y + 10)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(10))
        love.graphics.printf(joker.name, x + 3, y + 45, w - 6, "center")
        love.graphics.setColor(0.8, 0.8, 0.7)
        love.graphics.setFont(getFont(8))
        local desc = joker.description:sub(1, 40)
        love.graphics.printf(desc, x + 3, y + 65, w - 6, "center")

        -- Price
        love.graphics.setColor(canBuy and {0.3, 0.7, 0.3} or {0.5, 0.3, 0.3})
        love.graphics.rectangle("fill", x, y + h + 5, w, 20, 4, 4)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(12))
        love.graphics.printf(joker.cost, x, y + h + 8, w, "center")
    end

    -- Upgrades section (now in two columns for more upgrades)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.setFont(getFont(18))
    love.graphics.print("Upgrades:", 550, 100)

    for i, upgrade in ipairs(SHOP_UPGRADES) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local x = 550 + col * 230
        local y = 130 + row * 52
        local w, h = 220, 46

        local currentLevel = state.upgrades[upgrade.id] or 0
        local maxed = currentLevel >= upgrade.maxLevel
        local cost = upgrade.cost * (currentLevel + 1)
        local canBuy = not maxed and state.coins >= cost

        local hovered = mx >= x and mx <= x + w and my >= y and my <= y + h

        love.graphics.setColor(canBuy and (hovered and {0.3, 0.4, 0.35} or {0.2, 0.3, 0.25}) or {0.15, 0.15, 0.18})
        love.graphics.rectangle("fill", x, y, w, h, 6, 6)
        love.graphics.setColor(canBuy and {0.4, 0.7, 0.4} or {0.3, 0.3, 0.35})
        love.graphics.rectangle("line", x, y, w, h, 6, 6)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(12))
        love.graphics.print(upgrade.name .. " (" .. currentLevel .. "/" .. upgrade.maxLevel .. ")", x + 8, y + 4)
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.setFont(getFont(9))
        love.graphics.print(upgrade.desc, x + 8, y + 18)

        if not maxed then
            love.graphics.setColor(0.9, 0.8, 0.2)
            love.graphics.setFont(getFont(10))
            love.graphics.print(cost .. " coins", x + 8, y + 32)
        else
            love.graphics.setColor(0.3, 0.8, 0.3)
            love.graphics.setFont(getFont(10))
            love.graphics.print("MAXED", x + 8, y + 32)
        end
    end

    -- Next round preview
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.setFont(getFont(14))
    local nextTarget = calculateTargetScore(state.round)
    local isBoss = state.round % 5 == 0
    local isMiniBoss = state.round % 3 == 0 and not isBoss
    local bossText = isBoss and " (BOSS ROUND!)" or (isMiniBoss and " (Mini-Boss)" or "")
    love.graphics.print("Next Round: " .. state.round .. bossText, 550, screenH - 120)
    love.graphics.print("Target Score: " .. nextTarget, 550, screenH - 100)

    -- Continue button
    local contX = screenW - 180
    local contY = screenH - 70
    local contW, contH = 150, 50
    local contHover = mx >= contX and mx <= contX + contW and my >= contY and my <= contY + contH

    love.graphics.setColor(contHover and {0.4, 0.7, 0.4} or {0.3, 0.5, 0.3})
    love.graphics.rectangle("fill", contX, contY, contW, contH, 8, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(18))
    love.graphics.printf("Continue", contX, contY + 14, contW, "center")
end

function drawGameOver(screenW, screenH)
    local centerX = screenW / 2
    local centerY = screenH / 2

    -- Panel
    love.graphics.setColor(0.1, 0.08, 0.15, 0.98)
    love.graphics.rectangle("fill", centerX - 250, centerY - 250, 500, 500, 15, 15)
    love.graphics.setColor(0.9, 0.3, 0.3)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", centerX - 250, centerY - 250, 500, 500, 15, 15)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(0.9, 0.3, 0.3)
    love.graphics.setFont(getFont(36))
    love.graphics.printf("GAME OVER", centerX - 230, centerY - 230, 460, "center")

    -- Check if new record
    local isNewRecord = PlayerData.endlessRecord and state.round >= PlayerData.endlessRecord
    if isNewRecord then
        love.graphics.setColor(1, 0.8, 0.2)
        love.graphics.setFont(getFont(18))
        love.graphics.printf("NEW RECORD!", centerX - 230, centerY - 185, 460, "center")
    end

    love.graphics.setFont(getFont(18))
    local statY = centerY - 150

    -- Main stats
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Round Reached: " .. state.round, centerX - 210, statY, 420, "center")
    statY = statY + 30

    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.printf("Total Score: " .. state.totalScore, centerX - 210, statY, 420, "center")
    statY = statY + 30

    love.graphics.setColor(0.5, 0.8, 1)
    love.graphics.printf("Deck Size: " .. #state.deck .. " cards", centerX - 210, statY, 420, "center")
    statY = statY + 30

    love.graphics.setColor(0.9, 0.5, 0.9)
    love.graphics.printf("Jokers Collected: " .. #state.runJokers, centerX - 210, statY, 420, "center")
    statY = statY + 40

    -- Run stats
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.setFont(getFont(14))
    love.graphics.printf("--- Run Statistics ---", centerX - 210, statY, 420, "center")
    statY = statY + 25

    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.printf("Hands Played: " .. (state.runStats.handsPlayed or 0), centerX - 210, statY, 420, "center")
    statY = statY + 22

    love.graphics.printf("Cards Played: " .. (state.runStats.cardsPlayed or 0), centerX - 210, statY, 420, "center")
    statY = statY + 22

    love.graphics.printf("Bosses Defeated: " .. (state.runStats.bossesDefeated or 0), centerX - 210, statY, 420, "center")
    statY = statY + 22

    love.graphics.printf("Total Chips: " .. (state.runStats.totalChips or 0), centerX - 210, statY, 420, "center")
    statY = statY + 22

    -- Personal record
    if PlayerData.endlessRecord then
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.setFont(getFont(14))
        love.graphics.printf("Personal Best: Round " .. PlayerData.endlessRecord, centerX - 210, statY + 10, 420, "center")
    end

    statY = statY + 50

    local mx, my = love.mouse.getPosition()

    -- New Run button
    local newX = centerX - 130
    local newY = statY
    local newW, newH = 120, 45
    local newHover = mx >= newX and mx <= newX + newW and my >= newY and my <= newY + newH

    love.graphics.setColor(newHover and {0.4, 0.7, 0.4} or {0.3, 0.5, 0.3})
    love.graphics.rectangle("fill", newX, newY, newW, newH, 8, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(16))
    love.graphics.printf("New Run", newX, newY + 12, newW, "center")

    -- Menu button
    local menuX = centerX + 10
    local menuY = statY
    local menuW, menuH = 120, 45
    local menuHover = mx >= menuX and mx <= menuX + menuW and my >= menuY and my <= menuY + menuH

    love.graphics.setColor(menuHover and {0.5, 0.4, 0.6} or {0.3, 0.3, 0.4})
    love.graphics.rectangle("fill", menuX, menuY, menuW, menuH, 8, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Menu", menuX, menuY + 12, menuW, "center")
end

function EndlessMode.mousepressed(x, y, button)
    if button ~= 1 then return end

    local screenW, screenH = love.graphics.getDimensions()

    if state.phase == "playing" then
        -- Card clicks
        local handY = screenH - 200
        local cardW = 90
        local cardH = 130
        local cardSpacing = 100
        local startX = (screenW - #state.hand * cardSpacing) / 2

        for i = 1, #state.hand do
            local cardX = startX + (i - 1) * cardSpacing
            local cardY = handY

            for _, idx in ipairs(state.selectedCards) do
                if idx == i then
                    cardY = cardY - 25
                    break
                end
            end

            if x >= cardX and x <= cardX + cardW and y >= cardY and y <= cardY + cardH then
                local found = false
                for j, idx in ipairs(state.selectedCards) do
                    if idx == i then
                        table.remove(state.selectedCards, j)
                        found = true
                        break
                    end
                end
                if not found and #state.selectedCards < 5 then
                    table.insert(state.selectedCards, i)
                end
                return
            end
        end

        -- Button clicks
        local buttonY = screenH - 55
        local buttonW = 130
        local buttonH = 45

        local playX = screenW/2 - buttonW - 20
        if x >= playX and x <= playX + buttonW and y >= buttonY and y <= buttonY + buttonH then
            if #state.selectedCards > 0 and state.handsLeft > 0 then
                playHand()
            end
            return
        end

        local discardX = screenW/2 + 20
        if x >= discardX and x <= discardX + buttonW and y >= buttonY and y <= buttonY + buttonH then
            if #state.selectedCards > 0 and state.discardsLeft > 0 then
                discardCards()
            end
            return
        end

    elseif state.phase == "shop" then
        -- Pack clicks
        for i, pack in ipairs(state.shopPacks) do
            local px = 30 + (i-1) * 180
            local py = 130
            local pw, ph = 160, 80

            if x >= px and x <= px + pw and y >= py and y <= py + ph then
                buyPack(i)
                return
            end
        end

        -- Card clicks
        for i, shopCard in ipairs(state.shopCards) do
            local cx = 30 + (i-1) * 110
            local cy = 260
            local cw, ch = 90, 155

            if x >= cx and x <= cx + cw and y >= cy and y <= cy + ch then
                buyCard(i)
                return
            end
        end

        -- Joker clicks
        for i, joker in ipairs(state.shopJokers) do
            local jx = 30 + (i-1) * 130
            local jy = 460
            local jw, jh = 110, 125

            if x >= jx and x <= jx + jw and y >= jy and y <= jy + jh then
                buyJoker(i)
                return
            end
        end

        -- Upgrade clicks (two-column layout)
        for i, upgrade in ipairs(SHOP_UPGRADES) do
            local col = (i - 1) % 2
            local row = math.floor((i - 1) / 2)
            local ux = 550 + col * 230
            local uy = 130 + row * 52
            local uw, uh = 220, 46

            if x >= ux and x <= ux + uw and y >= uy and y <= uy + uh then
                buyUpgrade(upgrade.id)
                return
            end
        end

        -- Continue button
        local contX = screenW - 180
        local contY = screenH - 70
        local contW, contH = 150, 50

        if x >= contX and x <= contX + contW and y >= contY and y <= contY + contH then
            continueToNextRound()
            return
        end

    elseif state.phase == "gameover" then
        local centerX = screenW / 2
        local centerY = screenH / 2

        -- Calculate button Y position (matches the draw function)
        -- statY starts at centerY - 150, then adds lines plus 50
        local statY = centerY - 150 + 30 * 4 + 40 + 25 + 22 * 4 + 10 + 50  -- Matches draw calculations

        -- New Run
        local newX = centerX - 130
        local newW, newH = 120, 45
        if x >= newX and x <= newX + newW and y >= statY and y <= statY + newH then
            startNewRun()
            return
        end

        -- Menu
        local menuX = centerX + 10
        local menuW, menuH = 120, 45
        if x >= menuX and x <= menuX + menuW and y >= statY and y <= statY + menuH then
            local TextRPG = require("textrpg"); TextRPG.init(); GameState.current = "textrpg"
            return
        end
    end
end

function EndlessMode.keypressed(key)
    if key == "escape" then
        saveRun()
        local TextRPG = require("textrpg"); TextRPG.init(); GameState.current = "textrpg"
    end
end

function EndlessMode.wheelmoved(x, y)
    -- Could add scrolling for shop if needed
end

return EndlessMode
