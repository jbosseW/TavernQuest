-- collection_shared.lua
-- Shared state for all collection sub-modules

local shared = {}

-- Constants
shared.MAX_FUSION_COUNT = 3

-- UI state
shared.currentTab = "collection"  -- collection, shop, jokers, upgrades, themes, portraits
shared.scrollOffset = 0
shared.selectedCard = nil
shared.hoveredCard = nil
shared.hoveredJoker = nil
shared.hoveredJokerPos = {x = 0, y = 0}
shared.hoveredCardInfo = nil
shared.hoveredCardPos = {x = 0, y = 0}
shared.sellMode = false
shared.fusionMode = false
shared.fusionCards = {}

-- Filter state
shared.filters = {
    suit = "all",
    rarity = "all",
    ability = "all"
}

-- Shop inventory
shared.shopCards = {}
shared.shopJokers = {}
shared.shopRefreshCost = 5

-- Layout
shared.layout = {
    cardWidth = 90,
    cardHeight = 130,
    cardSpacing = 110,
    cardsPerRow = 10,
    areaX = 50,
    areaY = 160,
    areaWidth = 1180,
    areaHeight = 440
}

-- UI Components (set during init)
shared.mainTabBar = nil
shared.suitFilterBar = nil
shared.rarityFilterBar = nil
shared.fusionButton = nil
shared.sellButton = nil
shared.cardGrid = nil

-- Reset mutable state (called from Collection.init)
function shared.reset()
    shared.currentTab = "collection"
    shared.scrollOffset = 0
    shared.selectedCard = nil
    shared.hoveredCard = nil
    shared.hoveredJoker = nil
    shared.hoveredCardInfo = nil
    shared.sellMode = false
    shared.fusionMode = false
    shared.fusionCards = {}
    shared.filters = {suit = "all", rarity = "all", ability = "all"}
    shared.shopCards = {}
    shared.shopJokers = {}
end

return shared
