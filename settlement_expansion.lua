-- Settlement Expansion Module
-- Extracted from propertysystem.lua
-- Handles: grid-based terrain, building placement, permits, expansion, settlement visualization

local SettlementExpansion = {}

local Backpack = require("backpack")

-- ============================================================================
--                  DYNAMIC SETTLEMENT GRID SYSTEM
-- ============================================================================

-- Initialize settlement grid with terrain features
-- Supports non-square grids via optional gridWidth/gridHeight parameters
function SettlementExpansion.initializeSettlementGrid(state, PropertySystem, claimKey, gridWidth, gridHeight)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim then return false end

    if claim.settlementGrid then
        return true  -- Already initialized
    end

    local w = gridWidth or 25
    local h = gridHeight or 25
    claim.settlementGrid = {
        size = math.max(w, h),  -- Legacy compat: size = max dimension
        width = w,
        height = h,
        initialized = true,
        lastModified = state.daysPassed or 0,
        tiles = {},
        buildings = {},
        walls = {},
        nextBuildingId = 1,
    }

    -- Get region for terrain theming
    local WorldGen = require("worldgen")
    local tile = WorldGen.getTile(claim.x, claim.y)
    local region = tile and tile.region or "temperate"
    local terrainType = tile and tile.type or "grass"

    -- Initialize 2D tile array with region-appropriate terrain
    for y = 1, h do
        claim.settlementGrid.tiles[y] = {}
        for x = 1, w do
            claim.settlementGrid.tiles[y][x] = {
                type = "empty",
                terrain = "grass",  -- Base terrain
                buildingId = nil,
                wallSides = {},
                feature = nil,  -- tree, rock, water, etc.
            }
        end
    end

    -- Add terrain features based on region and terrain type
    SettlementExpansion.generateSettlementTerrain(state, PropertySystem, claimKey, terrainType, region)

    return true
end

-- Generate natural terrain features (trees, rocks, water)
function SettlementExpansion.generateSettlementTerrain(state, PropertySystem, claimKey, terrainType, region)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim or not claim.settlementGrid then return end

    local grid = claim.settlementGrid
    local gw = grid.width or grid.size
    local gh = grid.height or grid.size

    -- Terrain density based on terrain type
    local treeDensity = 0.08  -- 8% of tiles
    local rockDensity = 0.05  -- 5% of tiles
    local waterChance = 0.15  -- 15% chance of water feature

    -- Adjust by terrain type
    if terrainType == "forest" or terrainType == "deepwood" then
        treeDensity = 0.20  -- 20% trees in forest
        rockDensity = 0.03
    elseif terrainType == "mountain" or terrainType == "hills" then
        rockDensity = 0.15  -- 15% rocks in mountains
        treeDensity = 0.05
    elseif terrainType == "desert" or terrainType == "sand_dunes" then
        treeDensity = 0.01  -- Almost no trees
        rockDensity = 0.10
        waterChance = 0.05  -- Rare water
    elseif terrainType == "swamp" or terrainType == "wetlands" then
        treeDensity = 0.12
        waterChance = 0.40  -- Lots of water
    end

    local totalTiles = gw * gh

    -- Place trees randomly
    local treeCount = math.floor(totalTiles * treeDensity)
    for i = 1, treeCount do
        local x = math.random(1, gw)
        local y = math.random(1, gh)
        local tile = grid.tiles[y] and grid.tiles[y][x]
        if tile and not tile.feature then
            tile.feature = "tree"
        end
    end

    -- Place rocks randomly
    local rockCount = math.floor(totalTiles * rockDensity)
    for i = 1, rockCount do
        local x = math.random(1, gw)
        local y = math.random(1, gh)
        local tile = grid.tiles[y] and grid.tiles[y][x]
        if tile and not tile.feature then
            tile.feature = "rock"
        end
    end

    -- Add water feature (river or lake)
    if math.random() < waterChance then
        if math.random() < 0.6 then
            -- River (horizontal or vertical)
            SettlementExpansion.generateRiver(grid, gw, gh)
        else
            -- Lake (small pond)
            SettlementExpansion.generateLake(grid, gw, gh)
        end
    end
end

-- Generate a river through the settlement
-- Accepts separate width/height or single size for legacy compat
function SettlementExpansion.generateRiver(grid, gridW, gridH)
    local gw = gridW or grid.width or grid.size
    local gh = gridH or grid.height or grid.size
    local isHorizontal = math.random() < 0.5

    if isHorizontal then
        -- Horizontal river
        local riverY = math.random(math.floor(gh * 0.3), math.max(1, math.floor(gh * 0.7)))
        local width = math.random(1, 2)  -- River width (1-2 tiles)

        for x = 1, gw do
            for w = 0, width - 1 do
                local y = riverY + w
                if y >= 1 and y <= gh and grid.tiles[y] and grid.tiles[y][x] then
                    grid.tiles[y][x].feature = "water"
                end
            end
        end
    else
        -- Vertical river
        local riverX = math.random(math.floor(gw * 0.3), math.max(1, math.floor(gw * 0.7)))
        local width = math.random(1, 2)

        for y = 1, gh do
            for w = 0, width - 1 do
                local x = riverX + w
                if x >= 1 and x <= gw and grid.tiles[y] and grid.tiles[y][x] then
                    grid.tiles[y][x].feature = "water"
                end
            end
        end
    end
end

-- Generate a small lake
function SettlementExpansion.generateLake(grid, gridW, gridH)
    local gw = gridW or grid.width or grid.size
    local gh = gridH or grid.height or grid.size
    local centerX = math.random(math.floor(gw * 0.3), math.max(1, math.floor(gw * 0.7)))
    local centerY = math.random(math.floor(gh * 0.3), math.max(1, math.floor(gh * 0.7)))
    local radius = math.random(2, 4)

    for y = math.max(1, centerY - radius), math.min(gh, centerY + radius) do
        for x = math.max(1, centerX - radius), math.min(gw, centerX + radius) do
            local dist = math.sqrt((x - centerX)^2 + (y - centerY)^2)
            if dist <= radius and grid.tiles[y] and grid.tiles[y][x] then
                grid.tiles[y][x].feature = "water"
            end
        end
    end
end

-- Sync helpers passed from PropertySystem
local function syncGoldFromPlayerData(state)
    if state and state.player and PlayerData then
        state.player.gold = PlayerData.coins
    end
end

local function syncGoldToPlayerData(state)
    if state and state.player and PlayerData then
        PlayerData.coins = state.player.gold
    end
end

-- Clear terrain feature (tree, rock, brush)
function SettlementExpansion.clearTerrain(state, PropertySystem, claimKey, x, y)
    syncGoldFromPlayerData(state)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim or not claim.settlementGrid then
        return false, "Settlement grid not initialized"
    end

    local grid = claim.settlementGrid
    local gw = grid.width or grid.size
    local gh = grid.height or grid.size
    if x < 1 or x > gw or y < 1 or y > gh then
        return false, "Position out of bounds"
    end

    local tile = grid.tiles[y] and grid.tiles[y][x]
    if not tile or not tile.feature then
        return false, "No terrain feature to clear"
    end

    local featureDef = PropertySystem.TERRAIN_FEATURES[tile.feature]
    if not featureDef or not featureDef.clearable then
        return false, "This terrain cannot be cleared"
    end

    -- Check cost
    if state.player.gold < featureDef.clearCost then
        return false, "Not enough gold (need " .. featureDef.clearCost .. "g)"
    end

    -- Deduct cost
    state.player.gold = state.player.gold - featureDef.clearCost
    syncGoldToPlayerData(state)

    -- Yield resources
    if featureDef.yieldsWood then
        Backpack.addItem("wood_planks", featureDef.yieldsWood)
    end
    if featureDef.yieldsStone then
        Backpack.addItem("stone", featureDef.yieldsStone)
    end

    -- Clear feature
    tile.feature = nil

    return true, "Terrain cleared! Gained resources."
end

-- Helper: Get tile data (supports rectangular grids)
function SettlementExpansion.getTile(grid, x, y)
    if not grid or not grid.tiles then return nil end
    local gw = grid.width or grid.size
    local gh = grid.height or grid.size
    if y < 1 or y > gh or x < 1 or x > gw then return nil end
    if not grid.tiles[y] then return nil end
    return grid.tiles[y][x]
end

-- Helper: Check if tile is empty
function SettlementExpansion.isTileEmpty(grid, x, y)
    local tile = SettlementExpansion.getTile(grid, x, y)
    if not tile then return false end
    return (tile.type == "empty" and not tile.buildingId and tile.feature ~= "water")
end

-- Helper: Validate building placement (supports rectangular grids)
function SettlementExpansion.validateBuildingPlacement(state, PropertySystem, grid, x, y, footprint, buildingType)
    local width = footprint.width
    local height = footprint.height
    local gw = grid.width or grid.size
    local gh = grid.height or grid.size

    -- Bounds check
    if x < 1 or y < 1 or x + width - 1 > gw or y + height - 1 > gh then
        return false, "Building doesn't fit within settlement bounds"
    end

    -- Overlap check (all tiles in footprint must be empty)
    for dy = 0, height - 1 do
        for dx = 0, width - 1 do
            local tx = x + dx
            local ty = y + dy
            local tile = grid.tiles[ty][tx]

            -- Check if occupied by building
            if tile.type == "occupied" or tile.buildingId then
                return false, "Space already occupied by a building"
            end

            -- Check if blocked by terrain
            if tile.feature == "water" then
                return false, "Cannot build on water"
            end

            if tile.feature == "tree" or tile.feature == "rock" then
                return false, "Clear terrain first (trees/rocks block building)"
            end

            -- Check for wall conflicts
            if next(tile.wallSides) then
                return false, "Cannot build on wall segments"
            end
        end
    end

    -- Check settlement building limit
    local settlement = state.player.properties.settlements[x .. "_" .. y] or
                      state.player.properties.settlements[(claim and claim.x or 0) .. "_" .. (claim and claim.y or 0)]

    if settlement then
        local buildingCount = 0
        for _ in pairs(grid.buildings) do
            buildingCount = buildingCount + 1
        end

        if buildingCount >= settlement.maxBuildings then
            return false, "Settlement at max building capacity. Upgrade settlement level!"
        end
    end

    return true, nil
end

-- Place a building in the settlement
function SettlementExpansion.placeBuilding(state, PropertySystem, claimKey, buildingType, x, y, tier)
    syncGoldFromPlayerData(state)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim or not claim.settlementGrid then
        return false, "Settlement grid not initialized"
    end

    local grid = claim.settlementGrid
    local buildingDef = PropertySystem.SETTLEMENT_BUILDINGS[buildingType]
    if not buildingDef then
        return false, "Invalid building type"
    end

    tier = tier or 1
    local tierData = buildingDef.tiers[tier]
    if not tierData then
        return false, "Invalid tier"
    end

    -- Validate placement
    local canPlace, reason = SettlementExpansion.validateBuildingPlacement(state, PropertySystem, grid, x, y, tierData.footprint, buildingType)
    if not canPlace then
        return false, reason
    end

    -- Check resources
    if state.player.gold < tierData.cost.gold then
        return false, "Not enough gold (need " .. tierData.cost.gold .. "g)"
    end

    if tierData.materials then
        for _, mat in ipairs(tierData.materials) do
            local itemId = mat[1]
            local qty = mat[2]
            if not Backpack.hasItem(itemId, qty) then
                local itemDef = Backpack.getItemDef(itemId)
                local itemName = itemDef and itemDef.name or itemId
                return false, "Need " .. qty .. "x " .. itemName
            end
        end
    end

    -- Deduct costs
    state.player.gold = state.player.gold - tierData.cost.gold
    syncGoldToPlayerData(state)
    if tierData.materials then
        for _, mat in ipairs(tierData.materials) do
            Backpack.removeItem(mat[1], mat[2])
        end
    end

    -- Create building instance
    local buildingId = "building_" .. grid.nextBuildingId
    grid.nextBuildingId = grid.nextBuildingId + 1

    local building = {
        id = buildingId,
        type = buildingType,
        tier = tier,
        x = x,
        y = y,
        width = tierData.footprint.width,
        height = tierData.footprint.height,
        hp = tierData.maxHp or 100,
        maxHp = tierData.maxHp or 100,
        effects = {},
        placedDay = state.daysPassed or 0,
    }

    -- Copy effects
    if tierData.effects then
        for k, v in pairs(tierData.effects) do
            building.effects[k] = v
        end
    end

    -- Construction time or instant?
    if tierData.buildTime > 0 then
        building.constructionProgress = {
            startDay = state.daysPassed or 0,
            hoursRemaining = tierData.buildTime,
            targetTier = tier,
        }
    end

    -- Mark tiles as occupied
    for dy = 0, building.height - 1 do
        for dx = 0, building.width - 1 do
            local ty = y + dy
            local tx = x + dx
            grid.tiles[ty][tx].type = "occupied"
            grid.tiles[ty][tx].buildingId = buildingId
        end
    end

    -- Add to building registry
    grid.buildings[buildingId] = building
    grid.lastModified = state.daysPassed or 0

    local msg = buildingDef.name .. " placed!"
    if tierData.buildTime > 0 then
        msg = msg .. " (Construction: " .. tierData.buildTime .. " hours)"
    end

    return true, msg
end

-- Place wall segment on tile edge
function SettlementExpansion.placeWallSegment(state, PropertySystem, claimKey, x, y, side, wallType)
    syncGoldFromPlayerData(state)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim or not claim.settlementGrid then
        return false, "Settlement grid not initialized"
    end

    local grid = claim.settlementGrid
    wallType = wallType or "wooden_palisade"
    local wallDef = PropertySystem.WALL_SEGMENTS[wallType]
    if not wallDef then
        return false, "Invalid wall type"
    end

    -- Validate side
    if not (side == "north" or side == "south" or side == "east" or side == "west") then
        return false, "Invalid side"
    end

    -- Bounds check
    local gw = grid.width or grid.size
    local gh = grid.height or grid.size
    if x < 1 or x > gw or y < 1 or y > gh then
        return false, "Position out of bounds"
    end

    local tile = grid.tiles[y][x]

    -- Check if wall already exists on this side
    if tile.wallSides[side] then
        return false, "Wall already exists on this side"
    end

    -- Check resources
    if state.player.gold < wallDef.cost.gold then
        return false, "Not enough gold (need " .. wallDef.cost.gold .. "g)"
    end

    if wallDef.materials then
        for _, mat in ipairs(wallDef.materials) do
            if not Backpack.hasItem(mat[1], mat[2]) then
                local itemDef = Backpack.getItemDef(mat[1])
                return false, "Need " .. mat[2] .. "x " .. (itemDef and itemDef.name or mat[1])
            end
        end
    end

    -- Deduct costs
    state.player.gold = state.player.gold - wallDef.cost.gold
    syncGoldToPlayerData(state)
    if wallDef.materials then
        for _, mat in ipairs(wallDef.materials) do
            Backpack.removeItem(mat[1], mat[2])
        end
    end

    -- Create wall segment
    local wallSegment = {
        x = x,
        y = y,
        side = side,
        type = wallType,
        tier = wallDef.tier,
        hp = wallDef.hp,
        maxHp = wallDef.maxHp or wallDef.hp,
        defenseBonus = wallDef.defenseBonus,
        placedDay = state.daysPassed or 0,
    }

    -- Construction time
    if wallDef.buildTime > 0 then
        wallSegment.constructionProgress = {
            hoursRemaining = wallDef.buildTime,
        }
    end

    -- Add to grid
    tile.wallSides[side] = wallSegment
    table.insert(grid.walls, wallSegment)
    grid.lastModified = state.daysPassed or 0

    return true, wallDef.name .. " placed!"
end

-- Upgrade a building to next tier
function SettlementExpansion.upgradeBuilding(state, PropertySystem, claimKey, buildingId)
    syncGoldFromPlayerData(state)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim or not claim.settlementGrid then
        return false, "Settlement grid not initialized"
    end

    local grid = claim.settlementGrid
    local building = grid.buildings[buildingId]

    if not building then
        return false, "Building not found"
    end

    -- Check if already upgrading/constructing
    if building.constructionProgress then
        return false, "Building is currently under construction"
    end

    local buildingDef = PropertySystem.SETTLEMENT_BUILDINGS[building.type]
    if not buildingDef then
        return false, "Invalid building type"
    end

    local nextTier = building.tier + 1
    local nextTierData = buildingDef.tiers[nextTier]

    if not nextTierData then
        return false, "Building already at max tier"
    end

    -- Check resources
    if state.player.gold < nextTierData.cost.gold then
        return false, "Not enough gold (need " .. nextTierData.cost.gold .. "g)"
    end

    if nextTierData.materials then
        for _, mat in ipairs(nextTierData.materials) do
            if not Backpack.hasItem(mat[1], mat[2]) then
                local itemDef = Backpack.getItemDef(mat[1])
                return false, "Need " .. mat[2] .. "x " .. (itemDef and itemDef.name or mat[1])
            end
        end
    end

    -- Deduct costs
    state.player.gold = state.player.gold - nextTierData.cost.gold
    syncGoldToPlayerData(state)
    if nextTierData.materials then
        for _, mat in ipairs(nextTierData.materials) do
            Backpack.removeItem(mat[1], mat[2])
        end
    end

    -- Start upgrade
    building.constructionProgress = {
        startDay = state.daysPassed or 0,
        hoursRemaining = nextTierData.buildTime,
        targetTier = nextTier,
    }

    return true, "Upgrading " .. buildingDef.name .. " to tier " .. nextTier .. "! (" .. nextTierData.buildTime .. " hours)"
end

-- Demolish a building (50% refund)
function SettlementExpansion.demolishBuilding(state, PropertySystem, claimKey, buildingId)
    syncGoldFromPlayerData(state)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim or not claim.settlementGrid then
        return false, "Settlement grid not initialized"
    end

    local grid = claim.settlementGrid
    local building = grid.buildings[buildingId]

    if not building then
        return false, "Building not found"
    end

    local buildingDef = PropertySystem.SETTLEMENT_BUILDINGS[building.type]
    local tierData = buildingDef.tiers[building.tier]

    -- Refund 50% of gold cost
    local refund = math.floor(tierData.cost.gold * 0.5)
    state.player.gold = state.player.gold + refund
    syncGoldToPlayerData(state)

    -- Clear occupied tiles
    for dy = 0, building.height - 1 do
        for dx = 0, building.width - 1 do
            local ty = building.y + dy
            local tx = building.x + dx
            grid.tiles[ty][tx].type = "empty"
            grid.tiles[ty][tx].buildingId = nil
        end
    end

    -- Remove from registry
    grid.buildings[buildingId] = nil
    grid.lastModified = state.daysPassed or 0

    return true, buildingDef.name .. " demolished. Refunded " .. refund .. "g."
end

-- Update settlement construction progress
function SettlementExpansion.updateSettlementConstruction(state, PropertySystem, claimKey, hoursElapsed)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim or not claim.settlementGrid then return end

    local grid = claim.settlementGrid

    -- Update building construction
    for buildingId, building in pairs(grid.buildings) do
        if building.constructionProgress then
            building.constructionProgress.hoursRemaining =
                building.constructionProgress.hoursRemaining - hoursElapsed

            if building.constructionProgress.hoursRemaining <= 0 then
                -- Construction complete!
                local targetTier = building.constructionProgress.targetTier
                local buildingDef = PropertySystem.SETTLEMENT_BUILDINGS[building.type]
                local tierData = buildingDef.tiers[targetTier]

                building.tier = targetTier
                building.maxHp = tierData.maxHp or 100
                building.hp = building.maxHp
                building.effects = {}
                if tierData.effects then
                    for k, v in pairs(tierData.effects) do
                        building.effects[k] = v
                    end
                end
                building.constructionProgress = nil

                log(buildingDef.name .. " (Tier " .. targetTier .. ") construction complete!", {0.5, 0.9, 0.5})
            end
        end
    end

    -- Update wall construction
    for _, wall in ipairs(grid.walls) do
        if wall.constructionProgress then
            wall.constructionProgress.hoursRemaining =
                wall.constructionProgress.hoursRemaining - hoursElapsed

            if wall.constructionProgress.hoursRemaining <= 0 then
                wall.constructionProgress = nil
                log("Wall segment construction complete!", {0.5, 0.8, 0.9})
            end
        end
    end
end

-- Upgrade wall segment to next tier
function SettlementExpansion.upgradeWallSegment(state, PropertySystem, claimKey, x, y, side)
    syncGoldFromPlayerData(state)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim or not claim.settlementGrid then
        return false, "Settlement grid not initialized"
    end

    local grid = claim.settlementGrid
    local tile = grid.tiles[y][x]
    local currentWall = tile.wallSides[side]

    if not currentWall then
        return false, "No wall segment here"
    end

    local currentDef = PropertySystem.WALL_SEGMENTS[currentWall.type]
    if not currentDef.upgradesTo then
        return false, "Wall already at max tier"
    end

    local upgradeDef = PropertySystem.WALL_SEGMENTS[currentDef.upgradesTo]

    -- Check resources
    if state.player.gold < upgradeDef.cost.gold then
        return false, "Not enough gold"
    end

    if upgradeDef.materials then
        for _, mat in ipairs(upgradeDef.materials) do
            if not Backpack.hasItem(mat[1], mat[2]) then
                return false, "Need materials"
            end
        end
    end

    -- Deduct costs
    state.player.gold = state.player.gold - upgradeDef.cost.gold
    syncGoldToPlayerData(state)
    if upgradeDef.materials then
        for _, mat in ipairs(upgradeDef.materials) do
            Backpack.removeItem(mat[1], mat[2])
        end
    end

    -- Upgrade wall
    currentWall.type = upgradeDef.id
    currentWall.tier = upgradeDef.tier
    currentWall.maxHp = upgradeDef.maxHp
    currentWall.hp = upgradeDef.maxHp
    currentWall.defenseBonus = upgradeDef.defenseBonus

    if upgradeDef.buildTime > 0 then
        currentWall.constructionProgress = {
            hoursRemaining = upgradeDef.buildTime,
        }
    end

    return true, "Wall upgraded to " .. upgradeDef.name .. "!"
end

-- ============================================================================
--                  MULTI-PLOT LAND EXPANSION SYSTEM
-- ============================================================================

-- Maximum settlement grid dimensions (in tiles, 4x4 world plots = 100x100)
SettlementExpansion.MAX_SETTLEMENT_WIDTH = 100
SettlementExpansion.MAX_SETTLEMENT_HEIGHT = 100
SettlementExpansion.MAX_PLOTS_PER_SETTLEMENT = 16  -- 4x4 world plot grid

-- Get the number of land claim plots the player currently owns
function SettlementExpansion.getOwnedPlotCount(state)
    if not state or not state.player or not state.player.properties or not state.player.properties.landClaims then
        return 0
    end
    local count = 0
    for _ in pairs(state.player.properties.landClaims) do
        count = count + 1
    end
    return count
end

-- Get the number of plots in a specific settlement
function SettlementExpansion.getSettlementPlotCount(state, settlementId)
    if not state or not state.player or not state.player.properties or not state.player.properties.settlements then
        return 0
    end
    local settlement = state.player.properties.settlements[settlementId]
    if not settlement then return 0 end
    if settlement.plotCount then return settlement.plotCount end
    if settlement.claimKeys then return #settlement.claimKeys end
    return 1  -- Legacy single-plot settlement
end

-- Calculate expansion permit cost for a specific settlement based on its plot count
function SettlementExpansion.getPermitCostForSettlement(state, settlementId)
    local plotCount = SettlementExpansion.getSettlementPlotCount(state, settlementId)
    if plotCount <= 1 then
        return 0  -- First expansion is always free (plot 2)
    end
    -- plotCount is the current count; the NEXT plot would be plotCount + 1
    local nextPlot = plotCount + 1
    if nextPlot <= 2 then
        return 0  -- First expansion is free
    end
    -- Formula: 500 * 2^(nextPlot - 2)
    return math.floor(500 * (2 ^ (nextPlot - 2)))
end

-- Calculate expansion permit cost (legacy global version, returns cheapest option)
function SettlementExpansion.getPermitCost(state, settlementId)
    -- If a specific settlement is provided, use per-settlement cost
    if settlementId then
        return SettlementExpansion.getPermitCostForSettlement(state, settlementId)
    end
    -- For backward compatibility, return the cost for a new standalone settlement (0 = first expansion free)
    if not state or not state.player or not state.player.properties or not state.player.properties.settlements then
        return 0
    end
    local minCost = nil
    for settId, _ in pairs(state.player.properties.settlements) do
        local cost = SettlementExpansion.getPermitCostForSettlement(state, settId)
        if not minCost or cost < minCost then
            minCost = cost
        end
    end
    return minCost or 0
end

-- Check whether the player currently holds an unused expansion permit
function SettlementExpansion.hasExpansionPermit(state)
    if not state or not state.player then return false end
    return (state.player.expansionPermits or 0) > 0
end

-- Purchase an expansion permit from the Land Commissioner
function SettlementExpansion.purchaseExpansionPermit(state, settlementId)
    syncGoldFromPlayerData(state)
    if not state or not state.player then
        return false, "No player state available"
    end
    local plotCount = SettlementExpansion.getOwnedPlotCount(state)
    if plotCount < 1 then
        return false, "You must own at least one plot of land before purchasing an expansion permit."
    end

    local cost = SettlementExpansion.getPermitCost(state, settlementId)
    if cost == 0 then
        return false, "No permit needed - your next expansion is free!"
    end
    if state.player.gold < cost then
        return false, "Not enough gold. Permit costs " .. cost .. "g (you have " .. state.player.gold .. "g)."
    end

    state.player.gold = state.player.gold - cost
    syncGoldToPlayerData(state)
    state.player.expansionPermits = (state.player.expansionPermits or 0) + 1

    return true, "Expansion permit purchased for " .. cost .. "g! You now have " .. state.player.expansionPermits .. " permit(s)."
end

-- Get expansion details for a specific tile (used by Land Claim screen)
function SettlementExpansion.getExpansionDetailsForTile(state, PropertySystem, x, y)
    local isAdj, _, adjacentKey = SettlementExpansion.canClaimAdjacent(state, x, y)
    if not isAdj then
        return {
            isAdjacent = false,
            isNewSettlement = true,
        }
    end

    -- Find settlement for adjacent claim
    local settlementId, settlement = SettlementExpansion.findSettlementForClaim(state, adjacentKey)
    local isFirstFree = false
    local permitCost = 0
    local settlementName = "Unknown"
    local settPlotCount = 1

    if settlementId and settlement then
        isFirstFree = SettlementExpansion.isFirstExpansionFree(state, settlementId)
        permitCost = SettlementExpansion.getPermitCostForSettlement(state, settlementId)
        settlementName = settlement.customName or settlement.name or "Unknown"
        settPlotCount = SettlementExpansion.getSettlementPlotCount(state, settlementId)
    else
        -- No formal settlement yet, check if it is a single claim (first expansion free)
        local adjacentClaim = state.player.properties.landClaims[adjacentKey]
        if adjacentClaim then
            local adjacentPlots = 1
            for _, claim in pairs(state.player.properties.landClaims) do
                if claim.mergedInto == adjacentKey then
                    adjacentPlots = adjacentPlots + 1
                end
            end
            isFirstFree = (adjacentPlots == 1)
            settPlotCount = adjacentPlots
            -- For a single claim, next plot (2nd) is free
            if settPlotCount <= 1 then
                permitCost = 0
            else
                local nextPlot = settPlotCount + 1
                if nextPlot <= 2 then
                    permitCost = 0
                else
                    permitCost = math.floor(500 * (2 ^ (nextPlot - 2)))
                end
            end
            settlementName = "Your Land"
        end
    end

    return {
        isAdjacent = true,
        adjacentKey = adjacentKey,
        settlementId = settlementId,
        settlementName = settlementName,
        isFirstExpansionFree = isFirstFree,
        permitCost = permitCost,
        settlementPlotCount = settPlotCount,
    }
end

-- Check if a world tile at (x, y) is adjacent (NSEW) to any owned land claim
function SettlementExpansion.canClaimAdjacent(state, x, y)
    if x == nil or y == nil then
        return false, "Invalid coordinates", nil
    end
    if not state or not state.player or not state.player.properties or not state.player.properties.landClaims then
        return false, "No land claims", nil
    end

    local directions = {
        {dx = 0, dy = -1, name = "south"},  -- north on world map = row above
        {dx = 0, dy = 1, name = "north"},
        {dx = -1, dy = 0, name = "west"},
        {dx = 1, dy = 0, name = "east"},
    }

    for _, dir in ipairs(directions) do
        local nx = x + dir.dx
        local ny = y + dir.dy
        local neighborKey = nx .. "_" .. ny
        if state.player.properties.landClaims[neighborKey] then
            return true, nil, neighborKey
        end
    end

    return false, "This tile is not adjacent to any land you own", nil
end

-- Find which settlement (if any) a claim belongs to, by its claimKey
function SettlementExpansion.findSettlementForClaim(state, claimKey)
    for settId, settlement in pairs(state.player.properties.settlements) do
        if settlement.claimKeys then
            for _, ck in ipairs(settlement.claimKeys) do
                if ck == claimKey then
                    return settId, settlement
                end
            end
        elseif settId == claimKey then
            -- Legacy settlement keyed directly by the single claim key
            return settId, settlement
        end
    end
    return nil, nil
end

-- Get the bounding box of a settlement in world coordinates
function SettlementExpansion.getSettlementBounds(state, settlementId)
    local settlement = state.player.properties.settlements[settlementId]
    if not settlement then return nil end

    local keys = settlement.claimKeys
    if not keys or #keys == 0 then
        -- Legacy single-plot settlement
        local parts = {}
        for part in string.gmatch(settlementId, "[^_]+") do
            table.insert(parts, tonumber(part))
        end
        if #parts == 2 then
            return {minX = parts[1], maxX = parts[1], minY = parts[2], maxY = parts[2]}
        end
        return nil
    end

    local minX, maxX, minY, maxY
    for _, ck in ipairs(keys) do
        local claim = state.player.properties.landClaims[ck]
        if claim then
            if not minX or claim.x < minX then minX = claim.x end
            if not maxX or claim.x > maxX then maxX = claim.x end
            if not minY or claim.y < minY then minY = claim.y end
            if not maxY or claim.y > maxY then maxY = claim.y end
        end
    end

    return {minX = minX, maxX = maxX, minY = minY, maxY = maxY}
end

-- Determine grid expansion direction from adjacent claim to new claim
local function getExpansionDirection(existingClaim, newX, newY)
    local dx = newX - existingClaim.x
    local dy = newY - existingClaim.y
    if dx == 1 then return "east"
    elseif dx == -1 then return "west"
    elseif dy == 1 then return "south"
    elseif dy == -1 then return "north"
    end
    return nil
end

-- Resize the settlement grid when a new plot is added
function SettlementExpansion.resizeSettlementGrid(state, claimKey, direction)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim or not claim.settlementGrid then return false, "No grid to resize" end

    local grid = claim.settlementGrid
    local oldW = grid.width or grid.size
    local oldH = grid.height or grid.size
    local blockSize = 25

    local newW = oldW
    local newH = oldH
    local offsetX = 0  -- How much to shift existing tiles in X
    local offsetY = 0  -- How much to shift existing tiles in Y

    if direction == "east" then
        newW = oldW + blockSize
    elseif direction == "west" then
        newW = oldW + blockSize
        offsetX = blockSize  -- Existing tiles shift right by 25
    elseif direction == "south" then
        newH = oldH + blockSize
    elseif direction == "north" then
        newH = oldH + blockSize
        offsetY = blockSize  -- Existing tiles shift down by 25
    else
        return false, "Invalid expansion direction"
    end

    -- Enforce maximum grid dimensions
    if newW > SettlementExpansion.MAX_SETTLEMENT_WIDTH or newH > SettlementExpansion.MAX_SETTLEMENT_HEIGHT then
        return false, "Settlement has reached maximum size"
    end

    -- Build a new tiles array
    local newTiles = {}
    for y = 1, newH do
        newTiles[y] = {}
        for x = 1, newW do
            newTiles[y][x] = {
                type = "empty",
                terrain = "grass",
                buildingId = nil,
                wallSides = {},
                feature = nil,
            }
        end
    end

    -- Copy existing tiles into new positions (shifted by offset)
    for y = 1, oldH do
        if grid.tiles[y] then
            for x = 1, oldW do
                if grid.tiles[y][x] then
                    local destY = y + offsetY
                    local destX = x + offsetX
                    if destY >= 1 and destY <= newH and destX >= 1 and destX <= newW then
                        newTiles[destY][destX] = grid.tiles[y][x]
                    end
                end
            end
        end
    end

    -- Update building positions if there was an offset
    if offsetX > 0 or offsetY > 0 then
        for buildingId, building in pairs(grid.buildings) do
            building.x = building.x + offsetX
            building.y = building.y + offsetY

            -- Update tile references for occupied tiles
            for dy = 0, building.height - 1 do
                for dx = 0, building.width - 1 do
                    local ty = building.y + dy
                    local tx = building.x + dx
                    if ty >= 1 and ty <= newH and tx >= 1 and tx <= newW then
                        newTiles[ty][tx].type = "occupied"
                        newTiles[ty][tx].buildingId = buildingId
                    end
                end
            end
        end

        -- Update wall positions
        for _, wall in ipairs(grid.walls) do
            wall.x = wall.x + offsetX
            wall.y = wall.y + offsetY
        end
    end

    -- Apply the new grid
    grid.tiles = newTiles
    grid.width = newW
    grid.height = newH
    grid.size = math.max(newW, newH)  -- Legacy compat
    grid.lastModified = state.daysPassed or 0

    return true, "Grid expanded to " .. newW .. "x" .. newH
end

-- Generate terrain only for the newly added region of a grid
local function generateTerrainForRegion(grid, startX, endX, startY, endY, terrainType, region)
    local totalNew = (endX - startX + 1) * (endY - startY + 1)

    -- Terrain density
    local treeDensity = 0.08
    local rockDensity = 0.05

    if terrainType == "forest" or terrainType == "deepwood" then
        treeDensity = 0.20; rockDensity = 0.03
    elseif terrainType == "mountain" or terrainType == "hills" then
        rockDensity = 0.15; treeDensity = 0.05
    elseif terrainType == "desert" or terrainType == "sand_dunes" then
        treeDensity = 0.01; rockDensity = 0.10
    elseif terrainType == "swamp" or terrainType == "wetlands" then
        treeDensity = 0.12
    end

    local treeCount = math.floor(totalNew * treeDensity)
    for i = 1, treeCount do
        local x = math.random(startX, endX)
        local y = math.random(startY, endY)
        local tile = grid.tiles[y] and grid.tiles[y][x]
        if tile and not tile.feature then
            tile.feature = "tree"
        end
    end

    local rockCount = math.floor(totalNew * rockDensity)
    for i = 1, rockCount do
        local x = math.random(startX, endX)
        local y = math.random(startY, endY)
        local tile = grid.tiles[y] and grid.tiles[y][x]
        if tile and not tile.feature then
            tile.feature = "rock"
        end
    end
end

-- Check if a settlement's next expansion is free (first expansion = plot 2 is always free)
function SettlementExpansion.isFirstExpansionFree(state, settlementId)
    if not settlementId then return false end
    local plotCount = SettlementExpansion.getSettlementPlotCount(state, settlementId)
    return plotCount == 1  -- Settlement has only 1 plot, so next one (plot 2) is free
end

-- Expand a settlement by adding an adjacent world plot
function SettlementExpansion.expandSettlement(state, PropertySystem, newX, newY)
    syncGoldFromPlayerData(state)
    local newKey = newX .. "_" .. newY

    -- Validate the tile is actually adjacent to an existing claim
    local isAdj, reason, adjacentKey = SettlementExpansion.canClaimAdjacent(state, newX, newY)
    if not isAdj then
        return false, reason or "Not adjacent to owned land"
    end

    -- Find which settlement the adjacent claim belongs to (if any)
    local adjacentClaim = state.player.properties.landClaims[adjacentKey]
    if not adjacentClaim then
        return false, "Adjacent claim data not found"
    end

    local settlementId, settlement = SettlementExpansion.findSettlementForClaim(state, adjacentKey)

    -- Determine if this is a first expansion (free, no permit needed)
    local isFirstExpansion = false
    if settlementId then
        isFirstExpansion = SettlementExpansion.isFirstExpansionFree(state, settlementId)
    else
        -- Adjacent claim has no settlement yet; treat as single-plot (first expansion)
        local adjacentPlots = 1
        for _, claim in pairs(state.player.properties.landClaims) do
            if claim.mergedInto == adjacentKey then
                adjacentPlots = adjacentPlots + 1
            end
        end
        isFirstExpansion = (adjacentPlots == 1)
    end

    -- Check expansion permit (skip if first expansion is free)
    if not isFirstExpansion then
        if not SettlementExpansion.hasExpansionPermit(state) then
            local neededCost = 0
            if settlementId then
                neededCost = SettlementExpansion.getPermitCostForSettlement(state, settlementId)
            end
            return false, "You need an expansion permit from the Land Commissioner." ..
                (neededCost > 0 and (" Cost: " .. neededCost .. "g") or "")
        end
    end

    -- Check plot limit per settlement
    local settlementPlots = 0
    if settlementId and settlement then
        settlementPlots = SettlementExpansion.getSettlementPlotCount(state, settlementId)
    end
    if settlementPlots >= SettlementExpansion.MAX_PLOTS_PER_SETTLEMENT then
        return false, "This settlement has reached maximum size (" .. SettlementExpansion.MAX_PLOTS_PER_SETTLEMENT .. " plots)."
    end

    local direction = getExpansionDirection(adjacentClaim, newX, newY)
    if not direction then
        return false, "Could not determine expansion direction"
    end

    -- First, claim the land normally
    local canClaim, claimReason = PropertySystem.canClaimTile(newX, newY)
    if not canClaim then
        return false, claimReason
    end

    local claimCost = PropertySystem.getClaimCost(newX, newY)
    if state.player.gold < claimCost then
        return false, "Not enough gold for land claim (need " .. claimCost .. "g)"
    end

    local WorldGen = require("worldgen")
    local regionData, _ = WorldGen.getRegionAt(newX, newY)

    -- Deduct gold for land
    state.player.gold = state.player.gold - claimCost
    syncGoldToPlayerData(state)

    -- Consume permit (only if not a free first expansion)
    if not isFirstExpansion then
        state.player.expansionPermits = state.player.expansionPermits - 1
    end

    -- Create claim record
    state.player.properties.landClaims[newKey] = {
        x = newX,
        y = newY,
        claimDate = state.daysPassed or 0,
        region = regionData and regionData.id or "unknown",
        structure = adjacentClaim.structure,  -- Inherit structure level from parent
        structureLevel = adjacentClaim.structureLevel or 0,
        building = nil,
        hasWalls = adjacentClaim.hasWalls or false,
        wallLevel = adjacentClaim.wallLevel or 0,
        wallBuilding = nil,
        defenseRating = adjacentClaim.defenseRating or 0,
        lastAttack = nil,
        attackLog = {},
        damageLevel = 0,
        residents = {},
        maxResidents = adjacentClaim.maxResidents or 0,
        -- Mark that this plot is part of a merged settlement (no own grid)
        mergedInto = adjacentKey,
    }

    -- Mark tile as claimed
    local tile = WorldGen.getTile(newX, newY)
    if tile then
        tile.claimedBy = "player"
    end

    -- Now expand the settlement grid on the adjacent (parent) claim
    local rootKey = adjacentKey
    local rootClaim = adjacentClaim
    while rootClaim.mergedInto do
        rootKey = rootClaim.mergedInto
        rootClaim = state.player.properties.landClaims[rootKey]
        if not rootClaim then break end
    end

    if rootClaim and rootClaim.settlementGrid then
        local oldW = rootClaim.settlementGrid.width or rootClaim.settlementGrid.size
        local oldH = rootClaim.settlementGrid.height or rootClaim.settlementGrid.size

        local success, resizeMsg = SettlementExpansion.resizeSettlementGrid(state, rootKey, direction)
        if success then
            local newGrid = rootClaim.settlementGrid
            local gw = newGrid.width or newGrid.size
            local gh = newGrid.height or newGrid.size

            local newStartX, newEndX, newStartY, newEndY
            if direction == "east" then
                newStartX = oldW + 1; newEndX = gw; newStartY = 1; newEndY = gh
            elseif direction == "west" then
                newStartX = 1; newEndX = 25; newStartY = 1; newEndY = gh
            elseif direction == "south" then
                newStartX = 1; newEndX = gw; newStartY = oldH + 1; newEndY = gh
            elseif direction == "north" then
                newStartX = 1; newEndX = gw; newStartY = 1; newEndY = 25
            end

            if newStartX and newEndX and newStartY and newEndY then
                local newTile = WorldGen.getTile(newX, newY)
                local tType = newTile and newTile.type or "grass"
                local tRegion = newTile and newTile.region or "temperate"
                generateTerrainForRegion(newGrid, newStartX, newEndX, newStartY, newEndY, tType, tRegion)
            end
        end
    end

    -- Point the new claim's grid reference to the root claim
    state.player.properties.landClaims[newKey].mergedInto = rootKey

    -- Update settlement data if it exists
    if settlement then
        if not settlement.claimKeys then
            settlement.claimKeys = {settlementId}
        end
        local found = false
        for _, ck in ipairs(settlement.claimKeys) do
            if ck == newKey then found = true; break end
        end
        if not found then
            table.insert(settlement.claimKeys, newKey)
        end

        settlement.plotCount = #settlement.claimKeys
        settlement.bounds = SettlementExpansion.getSettlementBounds(state, settlementId)

        if rootClaim and rootClaim.settlementGrid then
            settlement.gridWidth = rootClaim.settlementGrid.width or rootClaim.settlementGrid.size
            settlement.gridHeight = rootClaim.settlementGrid.height or rootClaim.settlementGrid.size
        end
    end

    local freeMsg = isFirstExpansion and " (First expansion FREE!)" or ""
    return true, "Land expanded " .. direction .. " for " .. claimCost .. "g" .. freeMsg .. "! Settlement grid is now " ..
        (rootClaim and rootClaim.settlementGrid and ((rootClaim.settlementGrid.width or 25) .. "x" .. (rootClaim.settlementGrid.height or 25)) or "25x25") .. "."
end

-- Get expansion info for display in the Land Commissioner UI
function SettlementExpansion.getExpansionInfo(state, PropertySystem)
    local plotCount = SettlementExpansion.getOwnedPlotCount(state)
    local permitCost = SettlementExpansion.getPermitCost(state)
    local permits = (state and state.player and state.player.expansionPermits) or 0

    -- Find all adjacent tiles that could be expanded to
    local expandableTiles = {}
    local directions = {
        {dx = 0, dy = -1},
        {dx = 0, dy = 1},
        {dx = -1, dy = 0},
        {dx = 1, dy = 0},
    }

    if state and state.player and state.player.properties and state.player.properties.landClaims then
        for key, claim in pairs(state.player.properties.landClaims) do
            for _, dir in ipairs(directions) do
                local nx = claim.x + dir.dx
                local ny = claim.y + dir.dy
                local nk = nx .. "_" .. ny
                -- Only include if not already owned
                if not state.player.properties.landClaims[nk] then
                    local canClaim = PropertySystem.canClaimTile(nx, ny)
                    if canClaim then
                        expandableTiles[nk] = {x = nx, y = ny, adjacentTo = key}
                    end
                end
            end
        end
    end

    -- Build per-settlement info list
    local settlementsInfo = {}
    if state and state.player and state.player.properties and state.player.properties.settlements then
        for settId, settlement in pairs(state.player.properties.settlements) do
            local settPlotCount = SettlementExpansion.getSettlementPlotCount(state, settId)
            local nextCost = SettlementExpansion.getPermitCostForSettlement(state, settId)
            local gridW = settlement.gridWidth or 25
            local gridH = settlement.gridHeight or 25

            table.insert(settlementsInfo, {
                id = settId,
                name = settlement.customName or settlement.name or "Unnamed Settlement",
                plotCount = settPlotCount,
                gridWidth = gridW,
                gridHeight = gridH,
                nextPermitCost = nextCost,
                isFirstExpansionFree = (settPlotCount == 1),
                level = settlement.level or 1,
                levelName = settlement.levelName or "Camp",
                population = settlement.population or 0,
                maxPopulation = settlement.maxPopulation or 0,
            })
        end
        -- Sort by name for consistent display
        table.sort(settlementsInfo, function(a, b) return a.name < b.name end)
    end

    return {
        plotCount = plotCount,
        permitCost = permitCost,
        permits = permits,
        maxPlots = SettlementExpansion.MAX_PLOTS_PER_SETTLEMENT,
        expandableTiles = expandableTiles,
        settlementsInfo = settlementsInfo,
    }
end

-- Migrate existing settlements to the multi-plot data structure
function SettlementExpansion.migrateSettlementsToMultiPlot(state)
    if not state or not state.player or not state.player.properties then return end

    -- Ensure settlements table exists
    if not state.player.properties.settlements then
        state.player.properties.settlements = {}
    end

    -- Migrate settlement entries that lack claimKeys
    for settId, settlement in pairs(state.player.properties.settlements) do
        if not settlement.claimKeys then
            settlement.claimKeys = {settId}
            for key, claim in pairs(state.player.properties.landClaims) do
                if claim.mergedInto == settId and key ~= settId then
                    local found = false
                    for _, ck in ipairs(settlement.claimKeys) do
                        if ck == key then found = true; break end
                    end
                    if not found then
                        table.insert(settlement.claimKeys, key)
                    end
                end
            end
            local claim = state.player.properties.landClaims[settId]
            if claim then
                settlement.bounds = {
                    minX = claim.x, maxX = claim.x,
                    minY = claim.y, maxY = claim.y,
                }
                if claim.settlementGrid then
                    settlement.gridWidth = claim.settlementGrid.width or claim.settlementGrid.size or 25
                    settlement.gridHeight = claim.settlementGrid.height or claim.settlementGrid.size or 25
                else
                    settlement.gridWidth = 25
                    settlement.gridHeight = 25
                end
            end
        end

        if not settlement.plotCount then
            settlement.plotCount = settlement.claimKeys and #settlement.claimKeys or 1
        end

        if settlement.customName == nil then
            settlement.customName = nil
        end

        if not settlement.bounds then
            settlement.bounds = SettlementExpansion.getSettlementBounds(state, settId)
        end
    end

    -- Migrate settlement grids that lack width/height fields
    for key, claim in pairs(state.player.properties.landClaims) do
        if claim.settlementGrid then
            if not claim.settlementGrid.width then
                claim.settlementGrid.width = claim.settlementGrid.size or 25
            end
            if not claim.settlementGrid.height then
                claim.settlementGrid.height = claim.settlementGrid.size or 25
            end
        end
    end
end

-- Migrate old saves to new settlement grid system
function SettlementExpansion.migrateOldClaims(state, PropertySystem)
    for key, claim in pairs(state.player.properties.landClaims) do
        -- Old claims won't have settlementGrid but might have structure
        if not claim.settlementGrid and claim.structure then
            -- Initialize grid
            SettlementExpansion.initializeSettlementGrid(state, PropertySystem, key)

            -- Place legacy building in center of grid
            if claim.structure and claim.structure ~= "tent" then
                local grid = claim.settlementGrid
                local centerX = math.floor((grid.width or grid.size) / 2)
                local centerY = math.floor((grid.height or grid.size) / 2)

                -- Map old structure types to new building types
                local buildingMap = {
                    cabin = "cottage",
                    wild_house = "house",
                    wild_manor = "manor",
                }

                local buildingType = buildingMap[claim.structure]
                if buildingType then
                    local buildingDef = PropertySystem.SETTLEMENT_BUILDINGS[buildingType]
                    if buildingDef then
                        local tier1 = buildingDef.tiers[1]
                        local buildingId = "building_migrated_" .. grid.nextBuildingId
                        grid.nextBuildingId = grid.nextBuildingId + 1

                        local building = {
                            id = buildingId,
                            type = buildingType,
                            tier = 1,
                            x = centerX,
                            y = centerY,
                            width = tier1.footprint.width,
                            height = tier1.footprint.height,
                            hp = tier1.maxHp or 100,
                            maxHp = tier1.maxHp or 100,
                            effects = {},
                            placedDay = state.daysPassed or 0,
                        }

                        if tier1.effects then
                            for k, v in pairs(tier1.effects) do
                                building.effects[k] = v
                            end
                        end

                        -- Mark tiles
                        for dy = 0, building.height - 1 do
                            for dx = 0, building.width - 1 do
                                local ty = centerY + dy
                                local tx = centerX + dx
                                if ty >= 1 and ty <= (grid.height or grid.size) and tx >= 1 and tx <= (grid.width or grid.size) then
                                    grid.tiles[ty][tx].type = "occupied"
                                    grid.tiles[ty][tx].buildingId = buildingId
                                end
                            end
                        end

                        grid.buildings[buildingId] = building
                    end
                end
            end
        end
    end
end

return SettlementExpansion
