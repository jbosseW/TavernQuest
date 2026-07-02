-- poker_hands.lua
-- Pure poker hand evaluation logic - no UI or game state dependencies
-- Used by game.lua and cardgame_ai.lua

local PokerHands = {}

-- Hand rankings (best to worst)
PokerHands.handRankings = {
    {name = "Royal Flush", base = 100, mult = 8, check = "checkRoyalFlush"},
    {name = "Straight Flush", base = 100, mult = 8, check = "checkStraightFlush"},
    {name = "Four of a Kind", base = 60, mult = 7, check = "checkFourOfKind"},
    {name = "Full House", base = 40, mult = 4, check = "checkFullHouse"},
    {name = "Flush", base = 35, mult = 4, check = "checkFlush"},
    {name = "Straight", base = 30, mult = 4, check = "checkStraight"},
    {name = "Three of a Kind", base = 30, mult = 3, check = "checkThreeOfKind"},
    {name = "Two Pair", base = 20, mult = 2, check = "checkTwoPair"},
    {name = "Pair", base = 10, mult = 2, check = "checkPair"},
    {name = "High Card", base = 5, mult = 1, check = "checkHighCard"}
}

-- Helper: count ranks in hand
function PokerHands.countRanks(cards)
    local counts = {}
    for _, card in ipairs(cards) do
        counts[card.rank] = (counts[card.rank] or 0) + 1
    end
    return counts
end

-- Hand checking functions

function PokerHands.checkRoyalFlush(cards)
    if #cards < 5 then return false end
    if not PokerHands.checkFlush(cards) then return false end

    local ranks = {}
    for _, card in ipairs(cards) do
        ranks[card.rank] = true
    end
    return ranks["10"] and ranks["J"] and ranks["Q"] and ranks["K"] and ranks["A"]
end

function PokerHands.checkStraightFlush(cards)
    return PokerHands.checkFlush(cards) and PokerHands.checkStraight(cards)
end

function PokerHands.checkFourOfKind(cards)
    local counts = PokerHands.countRanks(cards)
    for rank, count in next, counts, nil do
        if count >= 4 then return true end
    end
    return false
end

function PokerHands.checkFullHouse(cards)
    local counts = PokerHands.countRanks(cards)
    local hasThree, hasTwo = false, false
    for rank, count in next, counts, nil do
        if count >= 3 then hasThree = true
        elseif count >= 2 then hasTwo = true end
    end
    return hasThree and hasTwo
end

function PokerHands.checkFlush(cards)
    if #cards < 5 then return false end
    local suits = {}
    for _, card in ipairs(cards) do
        local suit = card.ability == "wild" and "wild" or card.suit
        suits[suit] = (suits[suit] or 0) + 1
    end
    local wildCount = suits.wild or 0
    for suit, count in next, suits, nil do
        if suit ~= "wild" then
            if count + wildCount >= 5 then
                return true
            end
        end
    end
    -- Edge case: 5+ wild cards is also a flush
    if wildCount >= 5 then return true end
    return false
end

function PokerHands.checkStraight(cards)
    if #cards < 5 then return false end
    local values = {}
    for _, card in ipairs(cards) do
        table.insert(values, card.value)
    end
    table.sort(values)

    -- Check for consecutive values
    local consecutive = 1
    for i = 2, #values do
        if values[i] == values[i-1] + 1 then
            consecutive = consecutive + 1
            if consecutive >= 5 then return true end
        elseif values[i] ~= values[i-1] then
            consecutive = 1
        end
    end

    -- Check for A-2-3-4-5 (wheel)
    local hasAce = values[#values] == 14
    if hasAce then
        local wheel = {2, 3, 4, 5}
        local hasWheel = true
        for _, v in ipairs(wheel) do
            local found = false
            for _, cv in ipairs(values) do
                if cv == v then
                    found = true
                    break
                end
            end
            if not found then
                hasWheel = false
                break
            end
        end
        if hasWheel then return true end
    end

    return false
end

function PokerHands.checkThreeOfKind(cards)
    local counts = PokerHands.countRanks(cards)
    for rank, count in next, counts, nil do
        if count >= 3 then return true end
    end
    return false
end

function PokerHands.checkTwoPair(cards)
    local counts = PokerHands.countRanks(cards)
    local pairCount = 0
    for rank, count in next, counts, nil do
        if count >= 2 then pairCount = pairCount + 1 end
    end
    return pairCount >= 2
end

function PokerHands.checkPair(cards)
    local counts = PokerHands.countRanks(cards)
    for rank, count in next, counts, nil do
        if count >= 2 then return true end
    end
    return false
end

function PokerHands.checkHighCard(cards)
    return true
end

-- Evaluate a poker hand - returns handName, baseChips, baseMult
function PokerHands.evaluateHand(cards)
    for _, ranking in ipairs(PokerHands.handRankings) do
        if PokerHands[ranking.check](cards) then
            return ranking.name, ranking.base, ranking.mult
        end
    end
    return "High Card", 5, 1
end

-- Get cards that form the hand (scoring cards)
function PokerHands.getScoringCards(cards, handName)
    local counts = PokerHands.countRanks(cards)
    local scoringCards = {}

    if handName == "Royal Flush" or handName == "Straight Flush" or handName == "Flush" or handName == "Straight" then
        -- All cards score in these hands
        return cards
    elseif handName == "Four of a Kind" then
        for _, card in ipairs(cards) do
            if counts[card.rank] >= 4 then
                table.insert(scoringCards, card)
            end
        end
    elseif handName == "Full House" then
        return cards  -- All cards in full house score
    elseif handName == "Three of a Kind" then
        for _, card in ipairs(cards) do
            if counts[card.rank] >= 3 then
                table.insert(scoringCards, card)
            end
        end
    elseif handName == "Two Pair" then
        for _, card in ipairs(cards) do
            if counts[card.rank] >= 2 then
                table.insert(scoringCards, card)
            end
        end
    elseif handName == "Pair" then
        for _, card in ipairs(cards) do
            if counts[card.rank] >= 2 then
                table.insert(scoringCards, card)
            end
        end
    else
        -- High card
        local highest = cards[1]
        for _, card in ipairs(cards) do
            if card.value > highest.value then
                highest = card
            end
        end
        return {highest}
    end

    return #scoringCards > 0 and scoringCards or cards
end

-- Evaluate hand and return which cards form the hand
-- Returns: handName, baseChips, baseMult, scoringCards
function PokerHands.evaluateHandWithCards(cards)
    for _, ranking in ipairs(PokerHands.handRankings) do
        if PokerHands[ranking.check](cards) then
            local scoringCards = PokerHands.getScoringCards(cards, ranking.name)
            return ranking.name, ranking.base, ranking.mult, scoringCards
        end
    end
    -- High card - only highest card scores
    local highest = cards[1]
    for _, card in ipairs(cards) do
        if card.value > highest.value then
            highest = card
        end
    end
    return "High Card", 5, 1, {highest}
end

return PokerHands
