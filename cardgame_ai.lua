-- AI opponent for the card game

local AI = {}
local Cards = require("cards")
local PokerHands = require("poker_hands")

-- AI difficulty settings
local difficulty = {
    easy = {handQuality = 0.3, bluffChance = 0.1},
    normal = {handQuality = 0.6, bluffChance = 0.2},
    hard = {handQuality = 0.9, bluffChance = 0.3}
}

local currentDifficulty = difficulty.normal

-- Build an AI deck
function AI.buildDeck(deck)
    -- AI gets a mix of basic and some rare cards
    local allCards = {}

    -- Add basic cards
    for _, card in ipairs(Cards.basicCards) do
        table.insert(allCards, Cards.copyCard(card))
    end

    -- Shuffle and pick 35 basic cards
    for i = #allCards, 2, -1 do
        local j = math.random(i)
        allCards[i], allCards[j] = allCards[j], allCards[i]
    end

    for i = 1, 35 do
        table.insert(deck, allCards[i])
    end

    -- Add 5 rare cards
    for i = 1, 5 do
        local rareCard = Cards.rareCards[math.random(#Cards.rareCards)]
        table.insert(deck, Cards.copyCard(rareCard))
    end
end

-- Get random jokers for AI
function AI.getRandomJokers(count)
    local Jokers = require("jokers")
    local jokers = {}
    local available = {}

    for _, joker in ipairs(Jokers.list) do
        if joker.rarity == "common" or joker.rarity == "uncommon" then
            table.insert(available, joker)
        end
    end

    for i = 1, math.min(count, #available) do
        local idx = math.random(#available)
        table.insert(jokers, {id = available[idx].id})
        table.remove(available, idx)
    end

    return jokers
end

-- AI takes its turn - plays hands one at a time
function AI.takeTurn(gameState)
    local handsToPlay = math.min(4, gameState.handsLeft or 4)
    local totalScore = 0

    -- Draw cards if needed
    while #gameState.opponentHand < 8 and #gameState.opponentDeck > 0 do
        table.insert(gameState.opponentHand, table.remove(gameState.opponentDeck))
    end

    -- Play hands
    for i = 1, handsToPlay do
        if #gameState.opponentHand >= 1 then
            local handResult = AI.playBestHand(gameState)
            totalScore = totalScore + handResult.score
            gameState.opponentLastHand = handResult

            -- Draw new cards
            while #gameState.opponentHand < 8 and #gameState.opponentDeck > 0 do
                table.insert(gameState.opponentHand, table.remove(gameState.opponentDeck))
            end
        end
    end

    gameState.roundScores.opponent = gameState.roundScores.opponent + totalScore

    -- Transition to checking round end
    gameState.animating = true
    gameState.animTimer = 1.5
end

-- Play the best hand from current cards
function AI.playBestHand(gameState)
    local hand = gameState.opponentHand
    local bestCards, bestHandName, bestChips, bestMult = AI.findBestHand(hand)

    -- Remove played cards from hand
    for _, playedCard in ipairs(bestCards) do
        for i = #hand, 1, -1 do
            if hand[i] == playedCard then
                table.remove(hand, i)
                break
            end
        end
    end

    -- Calculate chips from cards
    local chips = bestChips
    for _, card in ipairs(bestCards) do
        chips = chips + (card.chips or card.value or 0)
    end

    -- Apply AI jokers
    local Jokers = require("jokers")
    local context = {
        phase = "score",
        playedCards = bestCards,
        handName = bestHandName,
        chips = chips,
        mult = bestMult,
        jokers = gameState.opponentJokers
    }
    context = Jokers.applyAll(gameState.opponentJokers, context)

    -- Apply difficulty variance
    local variance = 1 + (math.random() - 0.5) * (1 - currentDifficulty.handQuality) * 0.5
    local score = math.floor(context.chips * context.mult * variance)

    return {
        cards = bestCards,
        handName = bestHandName,
        chips = context.chips,
        mult = context.mult,
        score = score
    }
end

-- Find the best poker hand from available cards
function AI.findBestHand(cards)
    if #cards == 0 then
        return {}, "Nothing", 0, 1
    end

    -- Sort by value for easier processing
    local sorted = {}
    for _, card in ipairs(cards) do
        -- Ensure card has a value (default to 0 if missing)
        if card and card.value then
            table.insert(sorted, card)
        elseif card then
            -- Card exists but has no value - assign based on rank
            local rankValues = {["2"]=2,["3"]=3,["4"]=4,["5"]=5,["6"]=6,["7"]=7,["8"]=8,["9"]=9,["10"]=10,["J"]=11,["Q"]=12,["K"]=13,["A"]=14}
            card.value = rankValues[card.rank] or 0
            table.insert(sorted, card)
        end
    end
    table.sort(sorted, function(a, b)
        local aVal = a.value or 0
        local bVal = b.value or 0
        return aVal > bVal
    end)

    -- Try to find best 5-card combination
    local bestCards = {}
    local bestHandName = "High Card"
    local bestChips = 5
    local bestMult = 1

    -- Check for each hand type and find the best
    local handChecks = {
        {name = "Royal Flush", base = 100, mult = 8, check = function(c) return PokerHands.checkRoyalFlush(c) end},
        {name = "Straight Flush", base = 100, mult = 8, check = function(c) return PokerHands.checkStraightFlush(c) end},
        {name = "Four of a Kind", base = 60, mult = 7, check = function(c) return PokerHands.checkFourOfKind(c) end},
        {name = "Full House", base = 40, mult = 4, check = function(c) return PokerHands.checkFullHouse(c) end},
        {name = "Flush", base = 35, mult = 4, check = function(c) return PokerHands.checkFlush(c) end},
        {name = "Straight", base = 30, mult = 4, check = function(c) return PokerHands.checkStraight(c) end},
        {name = "Three of a Kind", base = 30, mult = 3, check = function(c) return PokerHands.checkThreeOfKind(c) end},
        {name = "Two Pair", base = 20, mult = 2, check = function(c) return PokerHands.checkTwoPair(c) end},
        {name = "Pair", base = 10, mult = 2, check = function(c) return PokerHands.checkPair(c) end},
    }

    -- Get up to 5 cards
    for i = 1, math.min(5, #sorted) do
        table.insert(bestCards, sorted[i])
    end

    -- Find the best hand type these cards make
    for _, handType in ipairs(handChecks) do
        if handType.check(bestCards) then
            bestHandName = handType.name
            bestChips = handType.base
            bestMult = handType.mult
            break
        end
    end

    -- If we only found high card, maybe play fewer cards for better combos
    if bestHandName == "High Card" and #sorted >= 2 then
        -- Try to find pairs in remaining cards
        local counts = {}
        for _, card in ipairs(sorted) do
            counts[card.rank] = (counts[card.rank] or 0) + 1
        end

        for rank, count in next, counts, nil do
            if count >= 2 then
                -- Found a pair, select those cards
                bestCards = {}
                for _, card in ipairs(sorted) do
                    if card.rank == rank and #bestCards < 2 then
                        table.insert(bestCards, card)
                    end
                end
                bestHandName = "Pair"
                bestChips = 10
                bestMult = 2
                break
            end
        end
    end

    return bestCards, bestHandName, bestChips, bestMult
end

-- Set AI difficulty
function AI.setDifficulty(level)
    if difficulty[level] then
        currentDifficulty = difficulty[level]
    end
end

-- Make cardgame_ai accessible via old require("ai") for backwards compatibility
package.loaded["ai"] = AI

return AI
