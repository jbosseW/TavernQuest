-- Card definitions for the game
-- Poker cards with special abilities

local Cards = {}

-- Card suits and ranks
Cards.suits = {"hearts", "diamonds", "clubs", "spades"}
Cards.ranks = {"2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"}
Cards.rankValues = {
    ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5, ["6"] = 6,
    ["7"] = 7, ["8"] = 8, ["9"] = 9, ["10"] = 10,
    ["J"] = 11, ["Q"] = 12, ["K"] = 13, ["A"] = 14
}

-- Suit colors
Cards.suitColors = {
    hearts = {1, 0.3, 0.3},
    diamonds = {1, 0.3, 0.3},
    clubs = {0.2, 0.2, 0.2},
    spades = {0.2, 0.2, 0.2},
    wild = {0.6, 0.3, 0.9}
}

-- Suit symbols
Cards.suitSymbols = {
    hearts = "♥",
    diamonds = "♦",
    clubs = "♣",
    spades = "♠",
    wild = "★"
}

-- Card rarities (11 levels total)
Cards.rarities = {
    common = {color = {0.7, 0.7, 0.7}, multiplier = 1, order = 1},
    uncommon = {color = {0.3, 0.8, 0.3}, multiplier = 1.5, order = 2},
    rare = {color = {0.3, 0.5, 1}, multiplier = 2, order = 3},
    epic = {color = {0.8, 0.3, 0.8}, multiplier = 3, order = 4},
    legendary = {color = {1, 0.8, 0.2}, multiplier = 5, order = 5},
    -- New higher rarities
    mythic = {color = {1, 0.4, 0.6}, multiplier = 8, order = 6},
    divine = {color = {1, 1, 0.9}, multiplier = 12, order = 7},
    cosmic = {color = {0.4, 0.2, 0.8}, multiplier = 18, order = 8},
    transcendent = {color = {0.2, 1, 1}, multiplier = 25, order = 9},
    eternal = {color = {0.9, 0.9, 1}, multiplier = 35, order = 10},
    primordial = {color = {0.1, 0.1, 0.1}, multiplier = 50, order = 11}  -- Black/void with white glow
}

-- Hidden/Secret cards - unlocked via special conditions
Cards.secretCards = {
    {
        id = "void_ace",
        name = "Void Ace",
        description = "Consumes all other cards, x10 mult",
        unlockCondition = "Win 50 games",
        unlockType = "wins",
        unlockValue = 50,
        rarity = "primordial",
        ability = "void_consume",
        chips = 100,
        mult = 10,
        multMult = 10
    },
    {
        id = "phoenix_king",
        name = "Phoenix King",
        description = "Revives from discard, +50 chips",
        unlockCondition = "Play 1000 hands",
        unlockType = "hands_played",
        unlockValue = 1000,
        rarity = "eternal",
        ability = "phoenix",
        chips = 50,
        mult = 5
    },
    {
        id = "time_queen",
        name = "Time Queen",
        description = "Replays your last hand",
        unlockCondition = "Win 25 games",
        unlockType = "wins",
        unlockValue = 25,
        rarity = "transcendent",
        ability = "time_replay",
        chips = 30,
        mult = 3
    },
    {
        id = "infinity_jack",
        name = "Infinity Jack",
        description = "Doubles your current mult",
        unlockCondition = "Score 100000 total chips",
        unlockType = "total_chips",
        unlockValue = 100000,
        rarity = "cosmic",
        ability = "infinity",
        chips = 25,
        multMult = 2
    },
    {
        id = "chaos_joker_card",
        name = "Chaos Card",
        description = "Random effect each play",
        unlockCondition = "Win 10 games with 3+ jokers",
        unlockType = "wins_with_jokers",
        unlockValue = 10,
        rarity = "mythic",
        ability = "chaos",
        chips = 20,
        mult = 2
    },
    {
        id = "mirror_ten",
        name = "Mirror Ten",
        description = "Copies the ability of adjacent cards",
        unlockCondition = "Play 5 Royal Flushes",
        unlockType = "royal_flushes",
        unlockValue = 5,
        rarity = "divine",
        ability = "mirror",
        chips = 15,
        mult = 1
    }
}

-- Check if a secret card is unlocked
function Cards.isSecretUnlocked(secretCard)
    if not PlayerData or not PlayerData.stats then return false end

    local unlockType = secretCard.unlockType
    local unlockValue = secretCard.unlockValue

    if unlockType == "wins" then
        return (PlayerData.wins or 0) >= unlockValue
    elseif unlockType == "hands_played" then
        return (PlayerData.stats.handsPlayed or 0) >= unlockValue
    elseif unlockType == "total_chips" then
        return (PlayerData.stats.totalChipsScored or 0) >= unlockValue
    elseif unlockType == "wins_with_jokers" then
        return (PlayerData.stats.winsWithJokers or 0) >= unlockValue
    elseif unlockType == "royal_flushes" then
        return (PlayerData.stats.royalFlushes or 0) >= unlockValue
    end

    return false
end

-- Get all unlocked secret cards
function Cards.getUnlockedSecrets()
    local unlocked = {}
    for _, card in ipairs(Cards.secretCards) do
        if Cards.isSecretUnlocked(card) then
            table.insert(unlocked, card)
        end
    end
    return unlocked
end

-- Special abilities
Cards.abilities = {
    none = {name = "None", description = "Standard card"},
    bonus_chip = {name = "Bonus Chips", description = "+10 chips when scored"},
    mult_boost = {name = "Mult Boost", description = "+2 mult when scored"},
    wild = {name = "Wild", description = "Counts as any suit"},
    glass = {name = "Glass", description = "x2 mult, 25% chance to break", tint = {0.5, 0.8, 1, 0.3}},
    steel = {name = "Steel", description = "x1.5 mult while in hand", tint = {0.7, 0.7, 0.8, 0.3}},
    gold = {name = "Gold", description = "+3 coins when round ends", tint = {1, 0.85, 0.2, 0.3}},
    lucky = {name = "Lucky", description = "1/5 chance for +20 mult", tint = {0.2, 1, 0.4, 0.2}},
    double = {name = "Double", description = "Counts as 2 cards for hands"},
    -- New abilities
    vampire = {name = "Vampire", description = "Steals +5 chips from opponent's score", tint = {0.4, 0.1, 0.2, 0.3}},
    phoenix = {name = "Phoenix", description = "Returns to hand after being played once", tint = {1, 0.5, 0.2, 0.3}},
    mirror = {name = "Mirror", description = "Copies the highest card's chips in hand", tint = {0.8, 0.8, 0.9, 0.2}},
    void = {name = "Void", description = "x3 mult but destroys one random card", tint = {0.1, 0.05, 0.15, 0.5}},
    blessed = {name = "Blessed", description = "+5 chips to all cards in same hand", tint = {1, 1, 0.7, 0.2}},
    cursed = {name = "Cursed", description = "x2.5 mult but -20 chips", tint = {0.3, 0, 0.3, 0.4}},
    echo = {name = "Echo", description = "Effect triggers twice when scored", tint = {0.6, 0.7, 0.9, 0.2}},
    anchor = {name = "Anchor", description = "+15 chips if leftmost or rightmost", tint = {0.4, 0.5, 0.6, 0.3}},
    magnet = {name = "Magnet", description = "Draws cards of same suit to your hand", tint = {0.7, 0.2, 0.2, 0.3}},
    shield = {name = "Shield", description = "Prevents negative effects for one round", tint = {0.5, 0.6, 0.7, 0.3}},
    gambler = {name = "Gambler", description = "50/50 chance for x4 or x0.5 mult", tint = {0.2, 0.7, 0.2, 0.2}},
    timewarp = {name = "Timewarp", description = "+1 hand this round when played", tint = {0.3, 0.3, 0.8, 0.3}},
    leech = {name = "Leech", description = "+1 chip per card in discard pile", tint = {0.5, 0.3, 0.3, 0.3}},
    prism = {name = "Prism", description = "Triggers all suit bonuses", tint = {1, 0.5, 1, 0.15}},
    -- Secret card abilities
    void_consume = {name = "Void Consume", description = "Destroys played cards for x2 mult each", chipBonus = 0, multBonus = 0, tint = {0.1, 0.05, 0.15, 0.5}},
    time_replay = {name = "Time Replay", description = "Replays the last scored hand", chipBonus = 0, multBonus = 5, tint = {0.3, 0.3, 0.8, 0.3}},
    infinity = {name = "Infinity", description = "Doubles the base chips", chipBonus = 0, multBonus = 0, tint = {0.4, 0.2, 0.8, 0.3}},
    chaos = {name = "Chaos", description = "Random effect each hand", chipBonus = 0, multBonus = 0, tint = {0.9, 0.3, 0.9, 0.3}},
}

-- Card mutations (stackable effects on cards)
Cards.mutations = {
    foil = {
        name = "Foil",
        description = "+50 chips",
        chipBonus = 50,
        tint = {0.7, 0.8, 1, 0.25},
        shine = true
    },
    holographic = {
        name = "Holographic",
        description = "+10 Mult",
        multBonus = 10,
        tint = {0.9, 0.6, 1, 0.2},
        rainbow = true
    },
    polychrome = {
        name = "Polychrome",
        description = "x1.5 Mult",
        multMult = 1.5,
        tint = {1, 0.9, 0.7, 0.15},
        shimmer = true
    },
    negative = {
        name = "Negative",
        description = "+1 Joker slot",
        jokerSlot = 1,
        tint = {0.2, 0.2, 0.3, 0.4},
        invert = true
    },
    stone = {
        name = "Stone",
        description = "+50 chips, no rank",
        chipBonus = 50,
        noRank = true,
        tint = {0.5, 0.5, 0.5, 0.4}
    },
    -- New mutations
    gilded = {
        name = "Gilded",
        description = "+2 coins when scored",
        coinBonus = 2,
        tint = {1, 0.85, 0.3, 0.3},
        sparkle = true
    },
    ancient = {
        name = "Ancient",
        description = "+25 chips, x1.2 mult",
        chipBonus = 25,
        multMult = 1.2,
        tint = {0.6, 0.5, 0.3, 0.3}
    },
    ethereal = {
        name = "Ethereal",
        description = "x2 mult, destroyed after use",
        multMult = 2.0,
        destroyOnUse = true,
        tint = {0.8, 0.9, 1, 0.15},
        glow = true
    },
    corrupt = {
        name = "Corrupt",
        description = "+100 chips, -5 mult",
        chipBonus = 100,
        multPenalty = 5,
        tint = {0.4, 0.1, 0.4, 0.35}
    },
    blessed_mut = {
        name = "Blessed",
        description = "Cannot be destroyed, +20 chips",
        chipBonus = 20,
        indestructible = true,
        tint = {1, 1, 0.8, 0.2}
    },
    frozen = {
        name = "Frozen",
        description = "+30 chips, delays scoring by 1 card",
        chipBonus = 30,
        delayScore = true,
        tint = {0.6, 0.8, 1, 0.3}
    },
    burning = {
        name = "Burning",
        description = "x1.3 mult, spreads to adjacent (30%)",
        multMult = 1.3,
        spreadChance = 0.3,
        tint = {1, 0.4, 0.2, 0.35}
    },
    lucky_mut = {
        name = "Lucky",
        description = "20% chance to double all bonuses",
        doubleChance = 0.2,
        tint = {0.3, 0.9, 0.4, 0.2}
    }
}

-- Viral effects (spread to adjacent cards during play)
Cards.viralEffects = {
    flame = {
        name = "Flame",
        description = "Spreads +5 chips to adjacent cards",
        spreadChips = 5,
        spreadChance = 0.7,
        tint = {1, 0.4, 0.1, 0.3},
        symbol = "🔥"
    },
    frost = {
        name = "Frost",
        description = "Spreads +2 mult to adjacent cards",
        spreadMult = 2,
        spreadChance = 0.6,
        tint = {0.4, 0.7, 1, 0.3},
        symbol = "❄️"
    },
    poison = {
        name = "Poison",
        description = "Reduces opponent score by 10%",
        opponentPenalty = 0.1,
        spreadChance = 0.5,
        tint = {0.3, 0.8, 0.2, 0.3},
        symbol = "☠️"
    },
    lightning = {
        name = "Lightning",
        description = "Chain x1.2 mult through matching suits",
        chainMult = 1.2,
        spreadChance = 0.8,
        tint = {1, 1, 0.3, 0.3},
        symbol = "⚡"
    },
    shadow = {
        name = "Shadow",
        description = "Hidden +10 chips revealed when scored",
        hiddenChips = 10,
        spreadChance = 0.4,
        tint = {0.2, 0.1, 0.3, 0.5},
        symbol = "🌑"
    },
    blood = {
        name = "Blood",
        description = "Sacrifice 5 chips to gain x1.5 mult",
        sacrificeChips = 5,
        gainMult = 1.5,
        spreadChance = 0.3,
        tint = {0.6, 0.1, 0.1, 0.4},
        symbol = "🩸"
    },
    crystal = {
        name = "Crystal",
        description = "Doubles effect of mutations on this card",
        doubleMutation = true,
        spreadChance = 0.2,
        tint = {0.8, 0.9, 1, 0.2},
        symbol = "💎"
    },
    radiance = {
        name = "Radiance",
        description = "All cards in hand gain +2 chips",
        areaChips = 2,
        spreadChance = 0.5,
        tint = {1, 1, 0.8, 0.2},
        symbol = "✨"
    },
    -- New viral effects
    plague = {
        name = "Plague",
        description = "Spreads ability to random cards (40%)",
        spreadAbility = true,
        spreadChance = 0.4,
        tint = {0.5, 0.6, 0.2, 0.35},
        symbol = "☣️"
    },
    echo_virus = {
        name = "Echo",
        description = "Copies mult bonus to next card played",
        copyMult = true,
        spreadChance = 0.6,
        tint = {0.6, 0.6, 0.8, 0.25},
        symbol = "📢"
    },
    golden_touch = {
        name = "Golden Touch",
        description = "Cards touched gain +1 coin value",
        coinSpread = 1,
        spreadChance = 0.5,
        tint = {1, 0.9, 0.4, 0.25},
        symbol = "👑"
    },
    void_spread = {
        name = "Void",
        description = "25% chance to nullify adjacent card effects",
        nullifyChance = 0.25,
        spreadChance = 0.35,
        tint = {0.1, 0.05, 0.15, 0.5},
        symbol = "🕳️"
    },
    life = {
        name = "Life",
        description = "Restores destroyed cards (20%)",
        restoreChance = 0.2,
        spreadChance = 0.3,
        tint = {0.4, 0.9, 0.5, 0.25},
        symbol = "💚"
    },
    chaos = {
        name = "Chaos",
        description = "Random effect each time played",
        randomEffect = true,
        spreadChance = 0.5,
        tint = {0.9, 0.3, 0.9, 0.3},
        symbol = "🎲"
    },
    mimic = {
        name = "Mimic",
        description = "Copies highest adjacent card's viral",
        copyViral = true,
        spreadChance = 0.45,
        tint = {0.5, 0.5, 0.7, 0.3},
        symbol = "🎭"
    },
    arcane = {
        name = "Arcane",
        description = "+3 mult per viral card in hand",
        multPerViral = 3,
        spreadChance = 0.35,
        tint = {0.5, 0.2, 0.8, 0.3},
        symbol = "🔮"
    }
}

-- Chance for a card's effect to spread during play
Cards.VIRAL_SPREAD_BASE_CHANCE = 0.15  -- 15% base chance

-- Check if effect spreads from one card to another
function Cards.checkEffectSpread(sourceCard, targetCard)
    if not sourceCard or not targetCard then return false end
    if not sourceCard.ability or sourceCard.ability == "none" then return false end

    -- Get spread chance (viral effects have their own, abilities use base)
    local spreadChance = Cards.VIRAL_SPREAD_BASE_CHANCE
    if sourceCard.viralEffect then
        local viral = Cards.viralEffects[sourceCard.viralEffect]
        if viral then
            spreadChance = viral.spreadChance or spreadChance
        end
    end

    -- Mutations can increase spread chance
    if sourceCard.mutation then
        local mutation = Cards.mutations[sourceCard.mutation]
        if mutation and mutation.spreadChance then
            spreadChance = spreadChance + mutation.spreadChance
        end
    end

    return math.random() < spreadChance
end

-- Apply effect spread from source to target
function Cards.applyEffectSpread(sourceCard, targetCard)
    if not Cards.checkEffectSpread(sourceCard, targetCard) then
        return targetCard, false
    end

    -- Spread viral effect
    if sourceCard.viralEffect and not targetCard.viralEffect then
        targetCard.viralEffect = sourceCard.viralEffect
        return targetCard, true
    end

    -- Spread mutation (if plague viral or burning mutation)
    if sourceCard.mutation and not targetCard.mutation then
        if sourceCard.viralEffect == "plague" or
           (sourceCard.mutation == "burning" and math.random() < 0.3) then
            targetCard.mutation = sourceCard.mutation
            return targetCard, true
        end
    end

    -- Spread temporary chip/mult bonuses
    if sourceCard.viralEffect then
        local viral = Cards.viralEffects[sourceCard.viralEffect]
        if viral then
            if viral.spreadChips then
                targetCard.tempChipBonus = (targetCard.tempChipBonus or 0) + viral.spreadChips
            end
            if viral.spreadMult then
                targetCard.tempMultBonus = (targetCard.tempMultBonus or 0) + viral.spreadMult
            end
            return targetCard, true
        end
    end

    return targetCard, false
end

-- Apply viral effect to a card
function Cards.applyViralEffect(card, viralId)
    if not Cards.viralEffects[viralId] then return card end
    card.viralEffect = viralId
    return card
end

-- Spread viral effects to adjacent cards
function Cards.spreadViral(cards, sourceIndex)
    local sourceCard = cards[sourceIndex]
    if not sourceCard or not sourceCard.viralEffect then return cards end

    local viral = Cards.viralEffects[sourceCard.viralEffect]
    if not viral then return cards end

    -- Check left and right cards
    local adjacentIndices = {}
    if sourceIndex > 1 then table.insert(adjacentIndices, sourceIndex - 1) end
    if sourceIndex < #cards then table.insert(adjacentIndices, sourceIndex + 1) end

    for _, idx in ipairs(adjacentIndices) do
        if math.random() < viral.spreadChance then
            -- Spread the effect
            if not cards[idx].viralEffect then
                cards[idx].viralEffect = sourceCard.viralEffect
            end
        end
    end

    return cards
end

-- Apply viral effects during scoring
function Cards.applyViralEffects(cards, chips, mult)
    for i, card in ipairs(cards) do
        if card.viralEffect then
            local viral = Cards.viralEffects[card.viralEffect]
            if viral then
                if viral.spreadChips then
                    chips = chips + viral.spreadChips
                end
                if viral.spreadMult then
                    mult = mult + viral.spreadMult
                end
                if viral.chainMult then
                    mult = mult * viral.chainMult
                end
                if viral.hiddenChips then
                    chips = chips + viral.hiddenChips
                end
                if viral.areaChips then
                    chips = chips + (viral.areaChips * #cards)
                end
                if viral.sacrificeChips and viral.gainMult then
                    chips = chips - viral.sacrificeChips
                    mult = mult * viral.gainMult
                end
            end
        end
    end
    return chips, mult
end

-- Add random viral effect to a card
function Cards.addRandomViralEffect(card)
    local viralIds = {}
    for id, _ in pairs(Cards.viralEffects) do
        table.insert(viralIds, id)
    end

    if #viralIds > 0 then
        card.viralEffect = viralIds[math.random(#viralIds)]
    end

    return card
end

-- Get tint color for a card
function Cards.getTint(card)
    -- Check viral effect tint first (highest priority)
    if card.viralEffect and Cards.viralEffects[card.viralEffect] then
        return Cards.viralEffects[card.viralEffect].tint
    end

    -- Check ability tint
    if card.ability and Cards.abilities[card.ability] and Cards.abilities[card.ability].tint then
        return Cards.abilities[card.ability].tint
    end

    -- Check mutation tint
    if card.mutation and Cards.mutations[card.mutation] then
        return Cards.mutations[card.mutation].tint
    end

    return nil
end

-- Apply mutation effects to scoring
function Cards.applyMutationEffects(card, chips, mult)
    if not card.mutation then return chips, mult end

    local mutation = Cards.mutations[card.mutation]
    if mutation then
        if mutation.chipBonus then
            chips = chips + mutation.chipBonus
        end
        if mutation.multBonus then
            mult = mult + mutation.multBonus
        end
        if mutation.multMult then
            mult = mult * mutation.multMult
        end
    end

    return chips, mult
end

-- Add a random mutation to a card
function Cards.addRandomMutation(card)
    local mutationIds = {}
    for id, _ in pairs(Cards.mutations) do
        table.insert(mutationIds, id)
    end

    if #mutationIds > 0 then
        card.mutation = mutationIds[math.random(#mutationIds)]
    end

    return card
end

-- Generate basic cards (standard 52-card deck style)
Cards.basicCards = {}
local cardId = 1

for _, suit in ipairs(Cards.suits) do
    for _, rank in ipairs(Cards.ranks) do
        table.insert(Cards.basicCards, {
            id = cardId,
            suit = suit,
            rank = rank,
            value = Cards.rankValues[rank],
            rarity = "common",
            ability = "none",
            chips = Cards.rankValues[rank],
            mult = 0
        })
        cardId = cardId + 1
    end
end

-- Generate rare cards with abilities
Cards.rareCards = {}

-- Bonus chip cards
for _, suit in ipairs(Cards.suits) do
    for _, rank in ipairs({"J", "Q", "K", "A"}) do
        table.insert(Cards.rareCards, {
            id = cardId,
            suit = suit,
            rank = rank,
            value = Cards.rankValues[rank],
            rarity = "uncommon",
            ability = "bonus_chip",
            chips = Cards.rankValues[rank] + 10,
            mult = 0
        })
        cardId = cardId + 1
    end
end

-- Mult boost cards
for _, suit in ipairs(Cards.suits) do
    for _, rank in ipairs({"7", "8", "9", "10"}) do
        table.insert(Cards.rareCards, {
            id = cardId,
            suit = suit,
            rank = rank,
            value = Cards.rankValues[rank],
            rarity = "uncommon",
            ability = "mult_boost",
            chips = Cards.rankValues[rank],
            mult = 2
        })
        cardId = cardId + 1
    end
end

-- Wild cards (rare)
for _, rank in ipairs(Cards.ranks) do
    table.insert(Cards.rareCards, {
        id = cardId,
        suit = "wild",
        rank = rank,
        value = Cards.rankValues[rank],
        rarity = "rare",
        ability = "wild",
        chips = Cards.rankValues[rank],
        mult = 1
    })
    cardId = cardId + 1
end

-- Glass cards (epic)
for _, suit in ipairs(Cards.suits) do
    for _, rank in ipairs({"A", "K"}) do
        table.insert(Cards.rareCards, {
            id = cardId,
            suit = suit,
            rank = rank,
            value = Cards.rankValues[rank],
            rarity = "epic",
            ability = "glass",
            chips = Cards.rankValues[rank],
            mult = 0,
            multMult = 2
        })
        cardId = cardId + 1
    end
end

-- Steel cards (epic)
for _, suit in ipairs(Cards.suits) do
    for _, rank in ipairs({"Q", "J"}) do
        table.insert(Cards.rareCards, {
            id = cardId,
            suit = suit,
            rank = rank,
            value = Cards.rankValues[rank],
            rarity = "epic",
            ability = "steel",
            chips = Cards.rankValues[rank],
            mult = 0,
            multMult = 1.5
        })
        cardId = cardId + 1
    end
end

-- Gold cards (rare)
for _, suit in ipairs(Cards.suits) do
    table.insert(Cards.rareCards, {
        id = cardId,
        suit = suit,
        rank = "10",
        value = 10,
        rarity = "rare",
        ability = "gold",
        chips = 10,
        mult = 0,
        goldReward = 3
    })
    cardId = cardId + 1
end

-- Lucky cards (legendary)
for _, suit in ipairs(Cards.suits) do
    table.insert(Cards.rareCards, {
        id = cardId,
        suit = suit,
        rank = "A",
        value = 14,
        rarity = "legendary",
        ability = "lucky",
        chips = 14,
        mult = 0,
        luckyMult = 20
    })
    cardId = cardId + 1
end

-- Create a copy of a card
function Cards.copyCard(card)
    local copy = {}
    for k, v in pairs(card) do
        copy[k] = v
    end
    -- Ensure value is set (for AI sorting and evaluation)
    if not copy.value and copy.rank then
        copy.value = Cards.rankValues[copy.rank] or 10
    end
    return copy
end

-- Get card display name
function Cards.getDisplayName(card)
    local symbol = Cards.suitSymbols[card.suit] or "★"
    return card.rank .. symbol
end

-- Get full card description
function Cards.getDescription(card)
    local ability = Cards.abilities[card.ability]
    local desc = Cards.getDisplayName(card)
    if ability and ability.name ~= "None" then
        desc = desc .. " [" .. ability.name .. "]"
    end
    return desc
end

-- Card image cache
Cards.cardImageCache = {}

-- Get card image path
function Cards.getCardImagePath(card)
    if not card or not card.suit or not card.rank then
        return nil
    end

    local suitMap = {
        hearts = "Hearts",
        diamonds = "Diamonds",
        clubs = "Clubs",
        spades = "Spades",
        wild = "Spades"
    }

    local rankMap = {
        ["2"] = "2", ["3"] = "3", ["4"] = "4", ["5"] = "5", ["6"] = "6",
        ["7"] = "7", ["8"] = "8", ["9"] = "9", ["10"] = "10",
        ["J"] = "J", ["Q"] = "Q", ["K"] = "K", ["A"] = "A"
    }

    local suit = suitMap[card.suit] or "Spades"
    local rank = rankMap[card.rank] or "2"

    local filename = string.format("CardsImages/CardDeck/4ColorCards/726X1044/Deck1/T_4ColorCards_Deck1_HighRes_%s%s_Diffuse.PNG",
        suit, rank)

    return filename
end

-- Load card image
function Cards.getCardImage(card)
    if not card then return nil end

    local imagePath = Cards.getCardImagePath(card)
    if not imagePath then return nil end

    -- Check cache
    if Cards.cardImageCache[imagePath] then
        return Cards.cardImageCache[imagePath]
    end

    -- Try to load image (try directly without getInfo check as it can fail in archives)
    local success, image = pcall(love.graphics.newImage, imagePath)
    if success and image then
        Cards.cardImageCache[imagePath] = image
        return image
    end

    -- Try with backslashes (Windows archive compatibility)
    local altPath = imagePath:gsub("/", "\\")
    if altPath ~= imagePath then
        success, image = pcall(love.graphics.newImage, altPath)
        if success and image then
            Cards.cardImageCache[imagePath] = image
            return image
        end
    end

    return nil
end

-- ============================================================================
-- Jokers system - special cards that modify scoring
-- (Merged from jokers.lua)
-- ============================================================================

local Jokers = {}

-- Joker definitions
Jokers.list = {
    -- Common Jokers
    {
        id = "joker_mult",
        name = "Joker",
        description = "+4 Mult",
        rarity = "common",
        cost = 20,
        effect = function(context)
            if context.phase == "score" then
                context.mult = context.mult + 4
            end
            return context
        end
    },
    {
        id = "greedy_joker",
        name = "Greedy Joker",
        description = "+3 Mult for each Diamond card",
        rarity = "common",
        cost = 25,
        effect = function(context)
            if context.phase == "score" then
                for _, card in ipairs(context.playedCards) do
                    if card.suit == "diamonds" then
                        context.mult = context.mult + 3
                    end
                end
            end
            return context
        end
    },
    {
        id = "lusty_joker",
        name = "Lusty Joker",
        description = "+3 Mult for each Heart card",
        rarity = "common",
        cost = 25,
        effect = function(context)
            if context.phase == "score" then
                for _, card in ipairs(context.playedCards) do
                    if card.suit == "hearts" then
                        context.mult = context.mult + 3
                    end
                end
            end
            return context
        end
    },
    {
        id = "wrathful_joker",
        name = "Wrathful Joker",
        description = "+3 Mult for each Spade card",
        rarity = "common",
        cost = 25,
        effect = function(context)
            if context.phase == "score" then
                for _, card in ipairs(context.playedCards) do
                    if card.suit == "spades" then
                        context.mult = context.mult + 3
                    end
                end
            end
            return context
        end
    },
    {
        id = "glutton_joker",
        name = "Gluttonous Joker",
        description = "+3 Mult for each Club card",
        rarity = "common",
        cost = 25,
        effect = function(context)
            if context.phase == "score" then
                for _, card in ipairs(context.playedCards) do
                    if card.suit == "clubs" then
                        context.mult = context.mult + 3
                    end
                end
            end
            return context
        end
    },

    -- Uncommon Jokers
    {
        id = "jolly_joker",
        name = "Jolly Joker",
        description = "+8 Mult if hand contains a Pair",
        rarity = "uncommon",
        cost = 40,
        effect = function(context)
            if context.phase == "score" and context.handName == "Pair" then
                context.mult = context.mult + 8
            end
            return context
        end
    },
    {
        id = "zany_joker",
        name = "Zany Joker",
        description = "+12 Mult if hand contains Three of a Kind",
        rarity = "uncommon",
        cost = 45,
        effect = function(context)
            if context.phase == "score" and context.handName == "Three of a Kind" then
                context.mult = context.mult + 12
            end
            return context
        end
    },
    {
        id = "mad_joker",
        name = "Mad Joker",
        description = "+10 Mult if hand contains Two Pair",
        rarity = "uncommon",
        cost = 45,
        effect = function(context)
            if context.phase == "score" and context.handName == "Two Pair" then
                context.mult = context.mult + 10
            end
            return context
        end
    },
    {
        id = "crazy_joker",
        name = "Crazy Joker",
        description = "+12 Mult if hand contains a Straight",
        rarity = "uncommon",
        cost = 50,
        effect = function(context)
            if context.phase == "score" and context.handName == "Straight" then
                context.mult = context.mult + 12
            end
            return context
        end
    },
    {
        id = "droll_joker",
        name = "Droll Joker",
        description = "+10 Mult if hand contains a Flush",
        rarity = "uncommon",
        cost = 50,
        effect = function(context)
            if context.phase == "score" and context.handName == "Flush" then
                context.mult = context.mult + 10
            end
            return context
        end
    },
    {
        id = "half_joker",
        name = "Half Joker",
        description = "+20 Mult if hand has 3 or fewer cards",
        rarity = "uncommon",
        cost = 35,
        effect = function(context)
            if context.phase == "score" and #context.playedCards <= 3 then
                context.mult = context.mult + 20
            end
            return context
        end
    },

    -- Rare Jokers
    {
        id = "steel_joker",
        name = "Steel Joker",
        description = "x1.5 Mult",
        rarity = "rare",
        cost = 80,
        effect = function(context)
            if context.phase == "score" then
                context.mult = context.mult * 1.5
            end
            return context
        end
    },
    {
        id = "abstract_joker",
        name = "Abstract Joker",
        description = "+3 Mult for each Joker you own",
        rarity = "rare",
        cost = 60,
        effect = function(context)
            if context.phase == "score" then
                context.mult = context.mult + ((context.jokers and #context.jokers or 0) * 3)
            end
            return context
        end
    },
    {
        id = "baron",
        name = "Baron",
        description = "x1.5 Mult for each King in hand",
        rarity = "rare",
        cost = 75,
        effect = function(context)
            if context.phase == "score" then
                for _, card in ipairs(context.playedCards) do
                    if card.rank == "K" then
                        context.mult = context.mult * 1.5
                    end
                end
            end
            return context
        end
    },
    {
        id = "fibonacci",
        name = "Fibonacci",
        description = "+8 Mult for each Ace, 2, 3, 5, or 8",
        rarity = "rare",
        cost = 70,
        effect = function(context)
            if context.phase == "score" then
                local fibRanks = {["A"] = true, ["2"] = true, ["3"] = true, ["5"] = true, ["8"] = true}
                for _, card in ipairs(context.playedCards) do
                    if fibRanks[card.rank] then
                        context.mult = context.mult + 8
                    end
                end
            end
            return context
        end
    },

    -- Epic Jokers
    {
        id = "blueprint",
        name = "Blueprint",
        description = "Copies ability of Joker to the left",
        rarity = "epic",
        cost = 100,
        effect = function(context)
            -- Special handling in applyJokers
            return context
        end
    },
    {
        id = "the_duo",
        name = "The Duo",
        description = "x2 Mult if hand contains a Pair",
        rarity = "epic",
        cost = 100,
        effect = function(context)
            if context.phase == "score" and context.handName == "Pair" then
                context.mult = context.mult * 2
            end
            return context
        end
    },
    {
        id = "the_trio",
        name = "The Trio",
        description = "x3 Mult if hand contains Three of a Kind",
        rarity = "epic",
        cost = 120,
        effect = function(context)
            if context.phase == "score" and context.handName == "Three of a Kind" then
                context.mult = context.mult * 3
            end
            return context
        end
    },
    {
        id = "the_family",
        name = "The Family",
        description = "x4 Mult if hand contains Four of a Kind",
        rarity = "epic",
        cost = 150,
        effect = function(context)
            if context.phase == "score" and context.handName == "Four of a Kind" then
                context.mult = context.mult * 4
            end
            return context
        end
    },

    -- Legendary Jokers
    {
        id = "canio",
        name = "Canio",
        description = "x1 Mult, gains x1 when card is destroyed",
        rarity = "legendary",
        cost = 200,
        multGain = 1,
        effect = function(context)
            if context.phase == "score" then
                if not context.jokerData.multGain then
                    context.jokerData.multGain = 1
                end
                context.mult = context.mult * context.jokerData.multGain
            elseif context.phase == "card_destroyed" then
                if not context.jokerData.multGain then
                    context.jokerData.multGain = 1
                end
                context.jokerData.multGain = context.jokerData.multGain + 1
            end
            return context
        end
    },
    {
        id = "yorick",
        name = "Yorick",
        description = "x5 Mult, -1 every 23 cards discarded",
        rarity = "legendary",
        cost = 200,
        effect = function(context)
            if context.phase == "score" then
                if not context.jokerData.currentMult then
                    context.jokerData.currentMult = 5
                end
                if not context.jokerData.discardCount then
                    context.jokerData.discardCount = 0
                end
                context.mult = context.mult * context.jokerData.currentMult
            elseif context.phase == "discard" then
                if not context.jokerData.discardCount then
                    context.jokerData.discardCount = 0
                end
                if not context.jokerData.currentMult then
                    context.jokerData.currentMult = 5
                end
                context.jokerData.discardCount = context.jokerData.discardCount + 1
                if context.jokerData.discardCount >= 23 then
                    context.jokerData.discardCount = 0
                    context.jokerData.currentMult = math.max(1, context.jokerData.currentMult - 1)
                end
            end
            return context
        end
    },
}

-- Rarity colors
Jokers.rarityColors = {
    common = {0.5, 0.5, 0.5},
    uncommon = {0.3, 0.7, 0.3},
    rare = {0.3, 0.5, 0.9},
    epic = {0.7, 0.3, 0.9},
    legendary = {0.9, 0.7, 0.2}
}

-- Get a joker by ID
function Jokers.getById(id)
    for _, joker in ipairs(Jokers.list) do
        if joker.id == id then
            return joker
        end
    end
    return nil
end

-- Get random jokers for shop
function Jokers.getRandomForShop(count, excludeIds)
    excludeIds = excludeIds or {}
    local available = {}

    for _, joker in ipairs(Jokers.list) do
        local excluded = false
        for _, id in ipairs(excludeIds) do
            if joker.id == id then
                excluded = true
                break
            end
        end
        if not excluded then
            table.insert(available, joker)
        end
    end

    local result = {}
    for i = 1, math.min(count, #available) do
        local idx = math.random(#available)
        table.insert(result, available[idx])
        table.remove(available, idx)
    end

    return result
end

-- Apply all jokers to a scoring context
function Jokers.applyAll(jokers, context)
    for i, jokerData in ipairs(jokers) do
        local joker = Jokers.getById(jokerData.id)
        if joker then
            -- Handle Blueprint specially
            if joker.id == "blueprint" and i > 1 then
                local prevJoker = Jokers.getById(jokers[i-1].id)
                if prevJoker and prevJoker.effect then
                    context.jokerData = jokers[i-1]
                    context = prevJoker.effect(context)
                end
            elseif joker.effect then
                context.jokerData = jokerData
                context = joker.effect(context)
            end
        end
    end
    return context
end

-- Copy a joker
function Jokers.copy(joker)
    local copy = {}
    for k, v in next, joker, nil do
        copy[k] = v
    end
    return copy
end

-- Alias for compatibility (some files use jokerList)
Jokers.jokerList = Jokers.list

-- Store jokers on Cards for unified access
Cards.jokers = Jokers

-- Make jokers accessible as separate require for backwards compatibility
package.loaded["jokers"] = Jokers

return Cards
