-- ============================================================================
-- PROCEDURAL TOWN GENERATION SYSTEM
-- ============================================================================
-- Produces varied, interesting town layouts with regional theming and
-- natural features. Supports 12+ layout types, 6 regional themes,
-- natural features (rivers, bridges, parks, ponds), and deterministic
-- generation from seeds.
--
-- Tile Legend:
--   0 = Empty / open ground
--   1 = Street / road
--   2 = Building
--   3 = Water (river, pond, canal)
--   4 = Bridge (passable over water)
--   5 = Plaza / town square
--   6 = Wall (fortification)
--   7 = Garden / park (trees, greenery)
--   8 = Dock / pier
--   9 = Decorative (fountain, statue, well, etc.)
--  10 = Gate (entry point in walls)
--  11 = Boardwalk / raised path (swamp stilts)
--  12 = Lighthouse
-- ============================================================================

local TownGen = {}
local SeededRandom = require("seedrandom")
local TileUtils = require("tileutils")

-- ============================================================================
--                      REGIONAL THEME DEFINITIONS
-- ============================================================================

local REGIONAL_THEMES = {
    desert = {
        name = "Desert",
        groundColor = {0.76, 0.65, 0.42},
        streetColor = {0.65, 0.55, 0.35},
        buildingColors = {
            {0.72, 0.58, 0.38}, -- adobe tan
            {0.68, 0.55, 0.35}, -- clay brown
            {0.78, 0.65, 0.42}, -- sandstone
            {0.62, 0.50, 0.32}, -- dark mud brick
        },
        roofColor = {0.58, 0.48, 0.30},
        waterColor = {0.25, 0.50, 0.55},
        wallColor = {0.68, 0.58, 0.40},
        featureColor = {0.55, 0.45, 0.28},
        treeChance = 0.02,           -- very rare
        gardenChance = 0.05,
        densityMultiplier = 1.3,     -- packed close for shade
        preferredLayouts = {"clustered", "radial", "grid"},
        decorations = {"well", "oasis", "sand_pile", "awning", "cactus"},
        description = "Adobe and sandstone buildings packed close for shade",
    },

    forest = {
        name = "Forest",
        groundColor = {0.22, 0.35, 0.18},
        streetColor = {0.30, 0.28, 0.20},
        buildingColors = {
            {0.45, 0.35, 0.22}, -- dark wood
            {0.50, 0.40, 0.25}, -- lighter wood
            {0.38, 0.32, 0.20}, -- aged timber
            {0.42, 0.38, 0.28}, -- brown-green
        },
        roofColor = {0.30, 0.40, 0.22},
        waterColor = {0.20, 0.40, 0.50},
        wallColor = {0.40, 0.35, 0.25},
        featureColor = {0.25, 0.40, 0.20},
        treeChance = 0.15,           -- lots of trees
        gardenChance = 0.10,
        densityMultiplier = 0.7,     -- spread out among trees
        preferredLayouts = {"organic", "clustered", "linear"},
        decorations = {"tree", "stump", "mushroom", "flower_bed", "log_fence"},
        description = "Wooden buildings spread among ancient trees",
    },

    mountain = {
        name = "Mountain",
        groundColor = {0.35, 0.33, 0.30},
        streetColor = {0.40, 0.38, 0.35},
        buildingColors = {
            {0.50, 0.48, 0.45}, -- light stone
            {0.42, 0.40, 0.38}, -- gray stone
            {0.55, 0.52, 0.48}, -- pale granite
            {0.38, 0.36, 0.34}, -- dark stone
        },
        roofColor = {0.35, 0.30, 0.28},
        waterColor = {0.25, 0.45, 0.60},
        wallColor = {0.45, 0.42, 0.38},
        featureColor = {0.40, 0.38, 0.35},
        treeChance = 0.05,
        gardenChance = 0.03,
        densityMultiplier = 1.2,     -- compact on slopes
        preferredLayouts = {"terraced", "fortified", "radial"},
        decorations = {"boulder", "mine_entrance", "stone_cairn", "torch"},
        description = "Stone buildings on terraced mountain slopes",
    },

    swamp = {
        name = "Swamp",
        groundColor = {0.20, 0.28, 0.18},
        streetColor = {0.32, 0.30, 0.22},
        buildingColors = {
            {0.30, 0.28, 0.20}, -- dark rotting wood
            {0.35, 0.30, 0.22}, -- mossy wood
            {0.28, 0.25, 0.18}, -- damp timber
            {0.32, 0.28, 0.22}, -- murky brown
        },
        roofColor = {0.25, 0.28, 0.18},
        waterColor = {0.18, 0.30, 0.22},
        wallColor = {0.30, 0.28, 0.22},
        featureColor = {0.22, 0.30, 0.18},
        treeChance = 0.08,
        gardenChance = 0.02,
        densityMultiplier = 0.8,
        preferredLayouts = {"riverside", "split", "organic"},
        decorations = {"mushroom", "moss", "dead_tree", "swamp_gas", "stilts"},
        useBoardwalks = true,        -- raised paths over water
        waterFrequency = 0.3,        -- lots of murky water
        description = "Stilted buildings connected by boardwalks over murky water",
    },

    coastal = {
        name = "Coastal",
        groundColor = {0.55, 0.52, 0.42},
        streetColor = {0.48, 0.45, 0.38},
        buildingColors = {
            {0.60, 0.58, 0.50}, -- whitewashed
            {0.55, 0.52, 0.45}, -- bleached wood
            {0.50, 0.48, 0.42}, -- driftwood gray
            {0.58, 0.55, 0.48}, -- pale plaster
        },
        roofColor = {0.40, 0.45, 0.50},
        waterColor = {0.20, 0.45, 0.65},
        wallColor = {0.50, 0.48, 0.42},
        featureColor = {0.45, 0.42, 0.38},
        treeChance = 0.04,
        gardenChance = 0.05,
        densityMultiplier = 1.0,
        preferredLayouts = {"riverside", "plaza", "grid"},
        decorations = {"anchor", "barrel", "net", "seagull", "lighthouse"},
        hasDocks = true,
        description = "Whitewashed buildings facing the harbor with docks",
    },

    plains = {
        name = "Plains",
        groundColor = {0.40, 0.50, 0.28},
        streetColor = {0.45, 0.42, 0.30},
        buildingColors = {
            {0.55, 0.48, 0.35}, -- thatch and daub
            {0.50, 0.45, 0.32}, -- wooden plank
            {0.58, 0.52, 0.38}, -- light timber
            {0.48, 0.42, 0.30}, -- stained wood
        },
        roofColor = {0.50, 0.45, 0.30},
        waterColor = {0.22, 0.42, 0.58},
        wallColor = {0.45, 0.40, 0.30},
        featureColor = {0.35, 0.48, 0.25},
        treeChance = 0.06,
        gardenChance = 0.12,         -- farming communities
        densityMultiplier = 0.7,     -- spread out farmsteads
        preferredLayouts = {"grid", "linear", "plaza"},
        decorations = {"hay_bale", "windmill", "fence", "well", "scarecrow"},
        description = "Spread out farmsteads with wide roads and market square",
    },

    -- Ice/tundra for Frostbound Reach and northern regions
    frozen = {
        name = "Frozen",
        groundColor = {0.60, 0.65, 0.70},
        streetColor = {0.55, 0.58, 0.62},
        buildingColors = {
            {0.48, 0.50, 0.55}, -- dark stone
            {0.55, 0.58, 0.62}, -- icy gray
            {0.42, 0.44, 0.48}, -- basalt
            {0.52, 0.55, 0.58}, -- frost stone
        },
        roofColor = {0.38, 0.40, 0.45},
        waterColor = {0.50, 0.60, 0.75},
        wallColor = {0.45, 0.48, 0.52},
        featureColor = {0.55, 0.58, 0.65},
        treeChance = 0.02,
        gardenChance = 0.01,
        densityMultiplier = 1.4,     -- huddled for warmth
        preferredLayouts = {"fortified", "clustered", "radial"},
        decorations = {"ice_pillar", "fire_pit", "fur_rack", "snow_drift"},
        description = "Compact stone buildings huddled against the cold",
    },
}

-- ============================================================================
--                  REGION-TO-THEME MAPPING
-- ============================================================================
-- Maps worldgen region IDs to visual themes

local REGION_THEME_MAP = {
    -- Main continent subregions
    dwarven_mountains = "mountain",
    orcish_steppes = "plains",
    holy_dominion = "plains",
    shadowfen = "swamp",
    eastern_forests = "forest",

    -- Gnomish Isles
    gnomish_isles = "coastal",
    mechspire_region = "coastal",
    clockwork_coast = "coastal",

    -- Desert regions
    great_endless_desert = "desert",
    scorched_sands = "desert",
    wastes_of_calidar = "desert",

    -- Water regions (unlikely to have towns but just in case)
    shimmering_sea = "coastal",
    western_ocean = "coastal",
    southern_ocean = "coastal",

    -- Frozen regions
    frostbound_reach = "frozen",
    northern_seas = "frozen",
    northern_tundra_continent = "frozen",
    southern_tundra = "frozen",
    polar_ocean = "frozen",

    -- Volcanic / archipelago
    ashen_archipelago = "coastal",
    great_western_isle = "forest",

    -- Hollow earth regions
    hollow_fungal_forests = "swamp",
    hollow_jungle = "forest",
    hollow_subterranean_seas = "coastal",
    hollow_crystal_caverns = "mountain",
    hollow_bone_wastes = "desert",
    hollow_storm_caverns = "mountain",
    hollow_deep_dwarven_realm = "mountain",
}

-- ============================================================================
--                      POPULATION ESTIMATION
-- ============================================================================

local function estimatePopulation(level, rng)
    -- Level 1: ~20-40 (small village)
    -- Level 5: ~60-100 (medium town)
    -- Level 10: ~140-200 (large town)
    -- Level 15+: ~200-400 (city)
    local variance = rng and rng:random(0, math.max(1, level * 5)) or math.random(0, math.max(1, level * 5))
    return math.floor(15 + level * 15 + variance)
end

local function getSizeCategory(population)
    if population < 50 then
        return "small"
    elseif population <= 150 then
        return "medium"
    elseif population <= 500 then
        return "large"
    elseif population <= 1500 then
        return "capital"
    else
        return "mega"
    end
end

-- ============================================================================
--                      GRID UTILITIES
-- ============================================================================

local function createGrid(width, height, defaultValue)
    local grid = {}
    for y = 1, height do
        grid[y] = {}
        for x = 1, width do
            grid[y][x] = defaultValue or 0
        end
    end
    return grid
end

-- Local alias for shared bounds check (keeps local-function performance)
local inBounds = TileUtils.isGridInBounds

local function setCell(grid, x, y, value, width, height)
    if inBounds(x, y, width, height) then
        grid[y][x] = value
        return true
    end
    return false
end

local function getCell(grid, x, y, width, height)
    if inBounds(x, y, width, height) then
        return grid[y][x]
    end
    return -1
end

-- Draw a filled rectangle on the grid
local function fillRect(grid, x1, y1, x2, y2, value, width, height)
    for y = math.max(1, y1), math.min(height, y2) do
        for x = math.max(1, x1), math.min(width, x2) do
            grid[y][x] = value
        end
    end
end

-- Draw a rectangle outline on the grid
local function outlineRect(grid, x1, y1, x2, y2, value, width, height)
    for x = math.max(1, x1), math.min(width, x2) do
        setCell(grid, x, y1, value, width, height)
        setCell(grid, x, y2, value, width, height)
    end
    for y = math.max(1, y1), math.min(height, y2) do
        setCell(grid, x1, y, value, width, height)
        setCell(grid, x2, y, value, width, height)
    end
end

-- Draw a line from (x1,y1) to (x2,y2) using Bresenham's
local function drawLine(grid, x1, y1, x2, y2, value, width, height)
    local dx = math.abs(x2 - x1)
    local dy = math.abs(y2 - y1)
    local sx = x1 < x2 and 1 or -1
    local sy = y1 < y2 and 1 or -1
    local err = dx - dy
    while true do
        setCell(grid, x1, y1, value, width, height)
        if x1 == x2 and y1 == y2 then break end
        local e2 = 2 * err
        if e2 > -dy then
            err = err - dy
            x1 = x1 + sx
        end
        if e2 < dx then
            err = err + dx
            y1 = y1 + sy
        end
    end
end

-- Draw a filled circle on the grid
local function fillCircle(grid, cx, cy, radius, value, width, height)
    for dy = -radius, radius do
        for dx = -radius, radius do
            if dx * dx + dy * dy <= radius * radius then
                setCell(grid, cx + dx, cy + dy, value, width, height)
            end
        end
    end
end

-- Check if a cell is adjacent to a given value
local function adjacentTo(grid, x, y, value, width, height)
    for dy = -1, 1 do
        for dx = -1, 1 do
            if not (dx == 0 and dy == 0) then
                if getCell(grid, x + dx, y + dy, width, height) == value then
                    return true
                end
            end
        end
    end
    return false
end

-- Check if a cell is adjacent to any of the given values
local function adjacentToAny(grid, x, y, values, width, height)
    for dy = -1, 1 do
        for dx = -1, 1 do
            if not (dx == 0 and dy == 0) then
                local cell = getCell(grid, x + dx, y + dy, width, height)
                for _, v in ipairs(values) do
                    if cell == v then return true end
                end
            end
        end
    end
    return false
end

-- ============================================================================
--                    ROAD DRAWING HELPERS
-- ============================================================================

-- Draw a winding/organic road from point A to point B
local function drawWindingRoad(grid, x1, y1, x2, y2, rng, width, height, roadWidth)
    roadWidth = roadWidth or 1
    local cx, cy = x1, y1
    local steps = math.abs(x2 - x1) + math.abs(y2 - y1) + 5
    for _ = 1, steps * 2 do
        -- Place road tiles (with width)
        for w = 0, roadWidth - 1 do
            setCell(grid, cx + w, cy, 1, width, height)
            setCell(grid, cx, cy + w, 1, width, height)
        end

        -- Move toward target with some randomness
        local dx = x2 - cx
        local dy = y2 - cy
        if math.abs(dx) + math.abs(dy) <= 1 then break end

        if rng:chance(0.7) then
            -- Move toward target
            if math.abs(dx) > math.abs(dy) then
                cx = cx + (dx > 0 and 1 or -1)
            else
                cy = cy + (dy > 0 and 1 or -1)
            end
        else
            -- Random drift
            if rng:chance(0.5) then
                cx = cx + (rng:chance(0.5) and 1 or -1)
            else
                cy = cy + (rng:chance(0.5) and 1 or -1)
            end
        end
        cx = math.max(1, math.min(width, cx))
        cy = math.max(1, math.min(height, cy))
    end
end

-- Draw a straight road (horizontal or vertical)
local function drawStraightRoad(grid, x1, y1, x2, y2, value, width, height, roadWidth)
    roadWidth = roadWidth or 1
    value = value or 1
    -- L-shaped path: horizontal first, then vertical
    local cx = x1
    local step = x2 > x1 and 1 or -1
    while cx ~= x2 do
        for w = 0, roadWidth - 1 do
            setCell(grid, cx, y1 + w, value, width, height)
        end
        cx = cx + step
    end
    local cy = y1
    step = y2 > y1 and 1 or -1
    while cy ~= y2 do
        for w = 0, roadWidth - 1 do
            setCell(grid, x2 + w, cy, value, width, height)
        end
        cy = cy + step
    end
    -- Final point
    for w = 0, roadWidth - 1 do
        setCell(grid, x2 + w, y2, value, width, height)
        setCell(grid, x2, y2 + w, value, width, height)
    end
end

-- ============================================================================
--                   NATURAL FEATURE GENERATORS
-- ============================================================================

-- Add a river flowing through the grid
local function addRiver(grid, rng, width, height, direction, riverWidth)
    riverWidth = riverWidth or rng:random(2, 3)
    local riverTiles = {}

    if direction == "horizontal" then
        local yStart = rng:random(math.floor(height * 0.3), math.floor(height * 0.7))
        local cy = yStart
        for x = 1, width do
            -- Slight meandering
            if rng:chance(0.3) then
                cy = cy + rng:random(-1, 1)
                cy = math.max(2, math.min(height - 1, cy))
            end
            for w = 0, riverWidth - 1 do
                local ry = cy + w
                if inBounds(x, ry, width, height) then
                    grid[ry][x] = 3
                    table.insert(riverTiles, {x = x, y = ry})
                end
            end
        end
    elseif direction == "vertical" then
        local xStart = rng:random(math.floor(width * 0.3), math.floor(width * 0.7))
        local cx = xStart
        for y = 1, height do
            if rng:chance(0.3) then
                cx = cx + rng:random(-1, 1)
                cx = math.max(2, math.min(width - 1, cx))
            end
            for w = 0, riverWidth - 1 do
                local rx = cx + w
                if inBounds(rx, y, width, height) then
                    grid[y][rx] = 3
                    table.insert(riverTiles, {x = rx, y = y})
                end
            end
        end
    elseif direction == "diagonal" then
        local startCorner = rng:random(1, 4)
        local sx, sy, ex, ey
        if startCorner == 1 then sx, sy, ex, ey = 1, 1, width, height
        elseif startCorner == 2 then sx, sy, ex, ey = width, 1, 1, height
        elseif startCorner == 3 then sx, sy, ex, ey = 1, height, width, 1
        else sx, sy, ex, ey = width, height, 1, 1 end

        local steps = math.max(width, height)
        for i = 0, steps do
            local t = i / steps
            local x = math.floor(sx + (ex - sx) * t + 0.5)
            local y = math.floor(sy + (ey - sy) * t + 0.5)
            -- Add some waviness
            local offset = math.floor(math.sin(i * 0.3) * 2)
            x = x + offset
            for w = 0, riverWidth - 1 do
                if inBounds(x + w, y, width, height) then
                    grid[y][x + w] = 3
                    table.insert(riverTiles, {x = x + w, y = y})
                end
            end
        end
    elseif direction == "sinusoidal" then
        local amplitude = math.floor(width / 5)
        local frequency = 2 * math.pi / height
        for y = 1, height do
            local x = math.floor(width / 2 + amplitude * math.sin(y * frequency) + 0.5)
            for w = 0, riverWidth - 1 do
                local rx = x + w - math.floor(riverWidth / 2)
                if inBounds(rx, y, width, height) then
                    grid[y][rx] = 3
                    table.insert(riverTiles, {x = rx, y = y})
                end
            end
        end
    end

    return riverTiles
end

-- Place bridges over a river
local function addBridges(grid, rng, width, height, riverTiles, numBridges)
    numBridges = numBridges or rng:random(2, 4)
    local bridgePositions = {}

    -- Group river tiles by row to find good crossing points
    local rowWater = {}
    for _, tile in ipairs(riverTiles) do
        if not rowWater[tile.y] then
            rowWater[tile.y] = {}
        end
        table.insert(rowWater[tile.y], tile.x)
    end

    -- Also group by column
    local colWater = {}
    for _, tile in ipairs(riverTiles) do
        if not colWater[tile.x] then
            colWater[tile.x] = {}
        end
        table.insert(colWater[tile.x], tile.y)
    end

    -- Place bridges at evenly spaced intervals
    local waterRows = {}
    for row, _ in pairs(rowWater) do
        table.insert(waterRows, row)
    end
    table.sort(waterRows)

    if #waterRows > 0 then
        local spacing = math.max(1, math.floor(#waterRows / (numBridges + 1)))
        for i = 1, numBridges do
            local idx = math.min(#waterRows, i * spacing)
            local row = waterRows[idx]
            if rowWater[row] then
                for _, wx in ipairs(rowWater[row]) do
                    setCell(grid, wx, row, 4, width, height)
                end
                table.insert(bridgePositions, {y = row, tiles = rowWater[row]})
                -- Add approach roads
                if #rowWater[row] > 0 then
                    local minX = math.huge
                    local maxX = -math.huge
                    for _, wx in ipairs(rowWater[row]) do
                        minX = math.min(minX, wx)
                        maxX = math.max(maxX, wx)
                    end
                    -- Road approaching bridge from both sides
                    if minX > 1 then setCell(grid, minX - 1, row, 1, width, height) end
                    if maxX < width then setCell(grid, maxX + 1, row, 1, width, height) end
                end
            end
        end
    end

    return bridgePositions
end

-- Add a pond or fountain at a position
local function addPond(grid, rng, cx, cy, width, height, radius)
    radius = radius or rng:random(1, 2)
    for dy = -radius, radius do
        for dx = -radius, radius do
            if dx * dx + dy * dy <= radius * radius then
                setCell(grid, cx + dx, cy + dy, 3, width, height)
            end
        end
    end
    -- Fountain in center if small
    if radius <= 1 then
        setCell(grid, cx, cy, 9, width, height)
    end
end

-- Add a garden/park area
local function addGarden(grid, rng, cx, cy, width, height, size)
    size = size or rng:random(2, 3)
    for dy = -size, size do
        for dx = -size, size do
            local dist = math.abs(dx) + math.abs(dy)
            if dist <= size + 1 then
                local gx, gy = cx + dx, cy + dy
                if inBounds(gx, gy, width, height) and grid[gy][gx] == 0 then
                    grid[gy][gx] = 7  -- Garden
                end
            end
        end
    end
end

-- Add docks along one edge (for coastal/port towns)
local function addDocks(grid, rng, width, height, side)
    side = side or "south"
    local dockLength = rng:random(3, 6)
    local numPiers = rng:random(2, 4)

    if side == "south" then
        -- Water along bottom
        for x = 1, width do
            setCell(grid, x, height, 3, width, height)
            if height - 1 >= 1 then
                setCell(grid, x, height - 1, 3, width, height)
            end
        end
        -- Piers extending into water
        local spacing = math.floor(width / (numPiers + 1))
        for i = 1, numPiers do
            local px = i * spacing
            for dy = 0, 1 do
                setCell(grid, px, height - dy, 8, width, height)
            end
            -- Buildings face the docks
            if height - 2 >= 1 then
                setCell(grid, px, height - 2, 1, width, height) -- approach road
            end
        end
    elseif side == "east" then
        for y = 1, height do
            setCell(grid, width, y, 3, width, height)
            if width - 1 >= 1 then
                setCell(grid, width - 1, y, 3, width, height)
            end
        end
        local spacing = math.floor(height / (numPiers + 1))
        for i = 1, numPiers do
            local py = i * spacing
            for dx = 0, 1 do
                setCell(grid, width - dx, py, 8, width, height)
            end
            if width - 2 >= 1 then
                setCell(grid, width - 2, py, 1, width, height)
            end
        end
    end
end

-- ============================================================================
--                  BUILDING PLACEMENT (Improved)
-- ============================================================================

-- Fill empty spaces with buildings, respecting road adjacency and density
local function fillWithBuildings(grid, width, height, rng, densityMult, buffer)
    buffer = buffer or 1
    densityMult = densityMult or 1.0
    local baseProbability = 0.65 * densityMult

    for y = 1 + buffer, height - buffer do
        for x = 1 + buffer, width - buffer do
            if grid[y][x] == 0 then
                -- Must be adjacent to a street, plaza, bridge, or boardwalk to "face" it
                local nearRoad = adjacentToAny(grid, x, y, {1, 4, 5, 11}, width, height)

                if nearRoad then
                    -- Road-adjacent buildings are more likely
                    if rng:chance(math.min(0.9, baseProbability * 1.2)) then
                        grid[y][x] = 2
                    end
                else
                    -- Interior buildings (behind road-facing ones)
                    -- Check distance from nearest road
                    local nearBuilding = adjacentTo(grid, x, y, 2, width, height)
                    if nearBuilding and rng:chance(baseProbability * 0.5) then
                        grid[y][x] = 2
                    end
                end
            end
        end
    end

    -- Second pass: fill gaps between buildings (cluster effect)
    for y = 2, height - 1 do
        for x = 2, width - 1 do
            if grid[y][x] == 0 then
                -- Count adjacent buildings
                local buildingNeighbors = 0
                for dy = -1, 1 do
                    for dx = -1, 1 do
                        if not (dx == 0 and dy == 0) then
                            if getCell(grid, x + dx, y + dy, width, height) == 2 then
                                buildingNeighbors = buildingNeighbors + 1
                            end
                        end
                    end
                end
                -- Fill in surrounded empty spaces
                if buildingNeighbors >= 4 and rng:chance(0.6 * densityMult) then
                    grid[y][x] = 2
                end
            end
        end
    end
end

-- Place landmark buildings (larger, more prominent)
local function placeLandmark(grid, rng, cx, cy, width, height, size)
    size = size or 2
    -- Clear area and place a bigger "building" (plaza + buildings around it)
    fillRect(grid, cx - size, cy - size, cx + size, cy + size, 5, width, height)
    -- Buildings around the landmark plaza
    for dy = -(size + 1), size + 1 do
        for dx = -(size + 1), size + 1 do
            local ax, ay = cx + dx, cy + dy
            if inBounds(ax, ay, width, height) then
                if math.abs(dx) == size + 1 or math.abs(dy) == size + 1 then
                    if grid[ay][ax] == 0 and rng:chance(0.7) then
                        grid[ay][ax] = 2
                    end
                end
            end
        end
    end
end

-- ============================================================================
--                    LAYOUT GENERATORS
-- ============================================================================
-- Each returns a grid. They all follow the same interface:
--   generator(grid, width, height, rng, theme)

-- ----- SMALL VILLAGE LAYOUTS -----

-- Circular: ring of buildings around a central plaza
local function generateCircularLayout(grid, width, height, rng, theme)
    local cx = math.floor(width / 2)
    local cy = math.floor(height / 2)
    local maxRadius = math.min(cx, cy) - 2

    -- Central plaza
    fillCircle(grid, cx, cy, 2, 5, width, height)

    -- Ring of buildings
    local numBuildings = rng:random(6, 12)
    for i = 1, numBuildings do
        local angle = (i - 1) * (2 * math.pi / numBuildings)
        local radius = rng:random(math.floor(maxRadius * 0.5), maxRadius - 1)
        local bx = math.floor(cx + radius * math.cos(angle) + 0.5)
        local by = math.floor(cy + radius * math.sin(angle) + 0.5)
        setCell(grid, bx, by, 2, width, height)
        -- Path from building to center
        drawLine(grid, bx, by, cx, cy, 1, width, height)
    end

    -- Central feature (fountain or well)
    setCell(grid, cx, cy, 9, width, height)
end

-- Linear: buildings along a single main road
local function generateLinearLayout(grid, width, height, rng, theme)
    local isHorizontal = rng:chance(0.5)

    if isHorizontal then
        -- Main road across the middle
        local roadY = math.floor(height / 2)
        for x = 2, width - 1 do
            setCell(grid, x, roadY, 1, width, height)
        end
        -- Buildings on both sides
        for x = 3, width - 2, 2 do
            if rng:chance(0.8) then
                setCell(grid, x, roadY - 1, 2, width, height)
            end
            if rng:chance(0.8) then
                setCell(grid, x, roadY + 1, 2, width, height)
            end
            -- Some buildings set back further
            if rng:chance(0.4) then
                setCell(grid, x, roadY - 2, 2, width, height)
            end
            if rng:chance(0.4) then
                setCell(grid, x, roadY + 2, 2, width, height)
            end
        end
        -- Small plaza at center
        local mx = math.floor(width / 2)
        fillRect(grid, mx - 1, roadY - 1, mx + 1, roadY + 1, 5, width, height)
    else
        local roadX = math.floor(width / 2)
        for y = 2, height - 1 do
            setCell(grid, roadX, y, 1, width, height)
        end
        for y = 3, height - 2, 2 do
            if rng:chance(0.8) then
                setCell(grid, roadX - 1, y, 2, width, height)
            end
            if rng:chance(0.8) then
                setCell(grid, roadX + 1, y, 2, width, height)
            end
            if rng:chance(0.4) then
                setCell(grid, roadX - 2, y, 2, width, height)
            end
            if rng:chance(0.4) then
                setCell(grid, roadX + 2, y, 2, width, height)
            end
        end
        local my = math.floor(height / 2)
        fillRect(grid, roadX - 1, my - 1, roadX + 1, my + 1, 5, width, height)
    end
end

-- Clustered: small groups around a well/shrine
local function generateClusteredLayout(grid, width, height, rng, theme)
    local numClusters = rng:random(2, 4)
    local clusters = {}

    for i = 1, numClusters do
        local cx = rng:random(4, width - 4)
        local cy = rng:random(4, height - 4)
        table.insert(clusters, {x = cx, y = cy})

        -- Cluster center (well or shrine)
        setCell(grid, cx, cy, 9, width, height)

        -- Buildings surrounding the center
        local numBuildings = rng:random(3, 6)
        for j = 1, numBuildings do
            local angle = (j - 1) * (2 * math.pi / numBuildings) + rng:random() * 0.5
            local dist = rng:random(2, 3)
            local bx = math.floor(cx + dist * math.cos(angle) + 0.5)
            local by = math.floor(cy + dist * math.sin(angle) + 0.5)
            setCell(grid, bx, by, 2, width, height)
            -- Path to cluster center
            drawLine(grid, bx, by, cx, cy, 1, width, height)
        end
    end

    -- Connect clusters with paths
    for i = 1, #clusters - 1 do
        drawWindingRoad(grid, clusters[i].x, clusters[i].y,
                       clusters[i + 1].x, clusters[i + 1].y,
                       rng, width, height)
    end
end

-- Riverside (small): buildings along one side of a river
local function generateSmallRiversideLayout(grid, width, height, rng, theme)
    local direction = rng:chance(0.5) and "horizontal" or "vertical"
    local riverTiles = addRiver(grid, rng, width, height, direction, 2)
    local bridges = addBridges(grid, rng, width, height, riverTiles, rng:random(1, 2))

    -- Build on one side of the river
    if direction == "horizontal" then
        local buildSide = rng:chance(0.5) and "north" or "south"
        local roadY = buildSide == "north" and 3 or height - 3
        for x = 2, width - 1 do
            setCell(grid, x, roadY, 1, width, height)
        end
        local buildOffset = buildSide == "north" and -1 or 1
        for x = 3, width - 2, 2 do
            if rng:chance(0.75) then
                setCell(grid, x, roadY + buildOffset, 2, width, height)
            end
        end
    else
        local buildSide = rng:chance(0.5) and "west" or "east"
        local roadX = buildSide == "west" and 3 or width - 3
        for y = 2, height - 1 do
            setCell(grid, roadX, y, 1, width, height)
        end
        local buildOffset = buildSide == "west" and -1 or 1
        for y = 3, height - 2, 2 do
            if rng:chance(0.75) then
                setCell(grid, roadX + buildOffset, y, 2, width, height)
            end
        end
    end
end

-- ----- MEDIUM TOWN LAYOUTS -----

-- Grid: traditional grid layout (existing style, improved)
local function generateGridLayout(grid, width, height, rng, theme)
    local blockSize = rng:random(4, 6)

    -- Create grid streets
    for x = blockSize, width, blockSize + 1 do
        for y = 1, height do
            setCell(grid, x, y, 1, width, height)
        end
    end
    for y = blockSize, height, blockSize + 1 do
        for x = 1, width do
            setCell(grid, x, y, 1, width, height)
        end
    end

    -- Main plaza at a grid intersection
    local plazaX = blockSize + rng:random(0, math.max(0, math.floor((width - blockSize) / (blockSize + 1)))) * (blockSize + 1)
    local plazaY = blockSize + rng:random(0, math.max(0, math.floor((height - blockSize) / (blockSize + 1)))) * (blockSize + 1)
    plazaX = math.min(plazaX, width - 2)
    plazaY = math.min(plazaY, height - 2)
    fillRect(grid, plazaX - 2, plazaY - 2, plazaX + 2, plazaY + 2, 5, width, height)

    -- Fountain in plaza
    setCell(grid, plazaX, plazaY, 9, width, height)

    -- Fill blocks with buildings
    fillWithBuildings(grid, width, height, rng, theme and theme.densityMultiplier or 1.0)
end

-- Radial: roads radiating from center like spokes
local function generateRadialLayout(grid, width, height, rng, theme)
    local cx = math.floor(width / 2)
    local cy = math.floor(height / 2)
    local maxRadius = math.min(cx, cy) - 1

    -- Center plaza
    fillCircle(grid, cx, cy, 2, 5, width, height)
    setCell(grid, cx, cy, 9, width, height) -- fountain

    -- Radial streets (spokes)
    local numRadials = rng:random(4, 8)
    for i = 1, numRadials do
        local angle = (i - 1) * (2 * math.pi / numRadials)
        for r = 3, maxRadius do
            local x = math.floor(cx + r * math.cos(angle) + 0.5)
            local y = math.floor(cy + r * math.sin(angle) + 0.5)
            if inBounds(x, y, width, height) and grid[y][x] == 0 then
                grid[y][x] = 1
            end
        end
    end

    -- Ring streets at different radii
    local rings = rng:random(2, 4)
    for ring = 1, rings do
        local radius = math.floor(maxRadius * ring / (rings + 1))
        for angle = 0, 2 * math.pi, 0.12 do
            local x = math.floor(cx + radius * math.cos(angle) + 0.5)
            local y = math.floor(cy + radius * math.sin(angle) + 0.5)
            if inBounds(x, y, width, height) and grid[y][x] == 0 then
                grid[y][x] = 1
            end
        end
    end

    -- Fill with buildings
    fillWithBuildings(grid, width, height, rng, theme and theme.densityMultiplier or 1.0)
end

-- Organic: winding roads with irregular building placement
local function generateOrganicLayout(grid, width, height, rng, theme)
    -- Several winding paths through town
    local numPaths = rng:random(5, 10)
    local nodes = {}

    for i = 1, numPaths do
        local sx = rng:random(1, width)
        local sy = rng:random(1, height)
        local ex = rng:random(1, width)
        local ey = rng:random(1, height)
        table.insert(nodes, {x = sx, y = sy})
        table.insert(nodes, {x = ex, y = ey})

        -- Draw winding path
        drawWindingRoad(grid, sx, sy, ex, ey, rng, width, height)
    end

    -- Small plazas at intersections
    for i = 1, rng:random(2, 4) do
        local px = rng:random(3, width - 3)
        local py = rng:random(3, height - 3)
        fillRect(grid, px - 1, py - 1, px + 1, py + 1, 5, width, height)
    end

    fillWithBuildings(grid, width, height, rng, theme and theme.densityMultiplier or 1.0)
end

-- Split: river divides town, bridge connects halves
local function generateSplitLayout(grid, width, height, rng, theme)
    -- River through the middle
    local direction = rng:chance(0.5) and "sinusoidal" or "diagonal"
    local riverTiles = addRiver(grid, rng, width, height, direction, rng:random(2, 4))
    local bridges = addBridges(grid, rng, width, height, riverTiles, rng:random(3, 5))

    -- Streets on both sides
    for y = 1, height do
        for x = 1, width do
            if grid[y][x] == 0 and (x % 5 == 0 or y % 5 == 0) then
                grid[y][x] = 1
            end
        end
    end

    -- Plazas on each side of river
    local halfW = math.floor(width / 4)
    fillRect(grid, halfW - 1, math.floor(height / 2) - 1,
             halfW + 1, math.floor(height / 2) + 1, 5, width, height)
    fillRect(grid, width - halfW - 1, math.floor(height / 2) - 1,
             width - halfW + 1, math.floor(height / 2) + 1, 5, width, height)

    fillWithBuildings(grid, width, height, rng, theme and theme.densityMultiplier or 1.0)
end

-- Riverside (medium): built along a river with bridges
local function generateRiversideLayout(grid, width, height, rng, theme)
    local direction = rng:chance(0.5) and "horizontal" or "vertical"
    local riverWidth = rng:random(2, 4)
    local riverTiles = addRiver(grid, rng, width, height, direction, riverWidth)
    local bridges = addBridges(grid, rng, width, height, riverTiles, rng:random(2, 4))

    -- Streets parallel to river on both sides
    if direction == "horizontal" then
        local riverY = math.floor(height / 2)
        -- Streets above and below river
        for x = 1, width do
            if riverY - riverWidth >= 1 then
                setCell(grid, x, riverY - riverWidth, 1, width, height)
            end
            if riverY + riverWidth + 1 <= height then
                setCell(grid, x, riverY + riverWidth + 1, 1, width, height)
            end
        end
        -- Perpendicular streets
        for x = 5, width - 1, 6 do
            for y = 1, height do
                if grid[y][x] == 0 then
                    grid[y][x] = 1
                end
            end
        end
    else
        local riverX = math.floor(width / 2)
        for y = 1, height do
            if riverX - riverWidth >= 1 then
                setCell(grid, riverX - riverWidth, y, 1, width, height)
            end
            if riverX + riverWidth + 1 <= width then
                setCell(grid, riverX + riverWidth + 1, y, 1, width, height)
            end
        end
        for y = 5, height - 1, 6 do
            for x = 1, width do
                if grid[y][x] == 0 then
                    grid[y][x] = 1
                end
            end
        end
    end

    fillWithBuildings(grid, width, height, rng, theme and theme.densityMultiplier or 1.0)
end

-- ----- LARGE CITY LAYOUTS -----

-- District-based: multiple neighborhoods
local function generateDistrictLayout(grid, width, height, rng, theme)
    -- Divide into 4 districts
    local midX = math.floor(width / 2)
    local midY = math.floor(height / 2)

    -- Main cross-roads dividing districts (wide main streets)
    for x = 1, width do
        setCell(grid, x, midY, 1, width, height)
        setCell(grid, x, midY - 1, 1, width, height)
    end
    for y = 1, height do
        setCell(grid, midX, y, 1, width, height)
        setCell(grid, midX - 1, y, 1, width, height)
    end

    -- Central plaza at crossroads
    fillRect(grid, midX - 3, midY - 3, midX + 2, midY + 2, 5, width, height)
    setCell(grid, midX, midY, 9, width, height)

    -- Each district gets its own internal street pattern
    local districts = {
        {x1 = 1, y1 = 1, x2 = midX - 2, y2 = midY - 2},           -- NW: residential
        {x1 = midX + 1, y1 = 1, x2 = width, y2 = midY - 2},        -- NE: merchant
        {x1 = 1, y1 = midY + 1, x2 = midX - 2, y2 = height},       -- SW: crafts
        {x1 = midX + 1, y1 = midY + 1, x2 = width, y2 = height},    -- SE: noble
    }

    for idx, d in ipairs(districts) do
        local dw = d.x2 - d.x1 + 1
        local dh = d.y2 - d.y1 + 1

        -- Each district has a small plaza
        local pcx = d.x1 + math.floor(dw / 2)
        local pcy = d.y1 + math.floor(dh / 2)
        fillRect(grid, pcx - 1, pcy - 1, pcx + 1, pcy + 1, 5, width, height)

        -- Internal grid streets
        local blockSize = rng:random(3, 5)
        for x = d.x1 + blockSize, d.x2 - 1, blockSize + 1 do
            for y = d.y1, d.y2 do
                if grid[y][x] == 0 then
                    grid[y][x] = 1
                end
            end
        end
        for y = d.y1 + blockSize, d.y2 - 1, blockSize + 1 do
            for x = d.x1, d.x2 do
                if grid[y][x] == 0 then
                    grid[y][x] = 1
                end
            end
        end
    end

    fillWithBuildings(grid, width, height, rng, theme and theme.densityMultiplier or 1.0)
end

-- Walled: buildings inside walls with gates
local function generateWalledLayout(grid, width, height, rng, theme)
    -- Outer walls
    outlineRect(grid, 1, 1, width, height, 6, width, height)

    -- Gates (N, S, E, W)
    local gateX = math.floor(width / 2)
    local gateY = math.floor(height / 2)
    setCell(grid, gateX, 1, 10, width, height)      -- North gate
    setCell(grid, gateX, height, 10, width, height)  -- South gate
    setCell(grid, 1, gateY, 10, width, height)       -- West gate
    setCell(grid, width, gateY, 10, width, height)   -- East gate

    -- Main cross-streets from gate to gate
    for x = 2, width - 1 do
        setCell(grid, x, gateY, 1, width, height)
    end
    for y = 2, height - 1 do
        setCell(grid, gateX, y, 1, width, height)
    end

    -- Central keep/plaza
    fillRect(grid, gateX - 3, gateY - 3, gateX + 3, gateY + 3, 5, width, height)
    setCell(grid, gateX, gateY, 9, width, height)

    -- Internal grid streets
    for x = 5, width - 5, 5 do
        for y = 2, height - 1 do
            if grid[y][x] == 0 then
                grid[y][x] = 1
            end
        end
    end
    for y = 5, height - 5, 5 do
        for x = 2, width - 1 do
            if grid[y][x] == 0 then
                grid[y][x] = 1
            end
        end
    end

    -- Corner towers (thicker walls)
    fillRect(grid, 1, 1, 3, 3, 6, width, height)
    fillRect(grid, width - 2, 1, width, 3, 6, width, height)
    fillRect(grid, 1, height - 2, 3, height, 6, width, height)
    fillRect(grid, width - 2, height - 2, width, height, 6, width, height)

    fillWithBuildings(grid, width, height, rng, theme and theme.densityMultiplier or 1.0, 2)
end

-- Plaza-centric: multiple plazas connected by roads
local function generatePlazaCentricLayout(grid, width, height, rng, theme)
    local numPlazas = rng:random(3, 6)
    local plazas = {}

    -- Place plazas with minimum spacing
    for i = 1, numPlazas do
        local attempts = 0
        local px, py
        repeat
            px = rng:random(5, width - 5)
            py = rng:random(5, height - 5)
            local tooClose = false
            for _, p in ipairs(plazas) do
                if math.abs(px - p.x) + math.abs(py - p.y) < 6 then
                    tooClose = true
                    break
                end
            end
            if not tooClose then break end
            attempts = attempts + 1
        until attempts > 20

        local size = rng:random(2, 3)
        table.insert(plazas, {x = px, y = py, size = size})
        fillRect(grid, px - size, py - size, px + size, py + size, 5, width, height)

        -- Feature in each plaza
        if rng:chance(0.5) then
            setCell(grid, px, py, 9, width, height)  -- fountain/statue
        end
    end

    -- Connect plazas with main roads (wide)
    for i = 1, #plazas do
        local next = i < #plazas and i + 1 or 1
        local p1, p2 = plazas[i], plazas[next]
        drawStraightRoad(grid, p1.x, p1.y, p2.x, p2.y, 1, width, height, 2)
    end

    -- Secondary grid streets
    for y = 1, height do
        for x = 1, width do
            if grid[y][x] == 0 and (x % 6 == 0 or y % 6 == 0) then
                grid[y][x] = 1
            end
        end
    end

    fillWithBuildings(grid, width, height, rng, theme and theme.densityMultiplier or 1.0)
end

-- Canal system: waterways with bridges
local function generateCanalLayout(grid, width, height, rng, theme)
    -- Main canals (2-3 crossing the town)
    local numCanals = rng:random(2, 3)
    local allRiverTiles = {}

    for i = 1, numCanals do
        local direction
        if i == 1 then direction = "horizontal"
        elseif i == 2 then direction = "vertical"
        else direction = "sinusoidal"
        end

        local tiles = addRiver(grid, rng, width, height, direction, 2)
        for _, t in ipairs(tiles) do
            table.insert(allRiverTiles, t)
        end
    end

    -- Many bridges
    addBridges(grid, rng, width, height, allRiverTiles, rng:random(4, 8))

    -- Streets between canals
    for y = 1, height do
        for x = 1, width do
            if grid[y][x] == 0 and (x % 4 == 0 or y % 4 == 0) then
                grid[y][x] = 1
            end
        end
    end

    -- Central market plaza
    local cx, cy = math.floor(width / 2), math.floor(height / 2)
    -- Find a dry spot near center
    for r = 0, 5 do
        for dy = -r, r do
            for dx = -r, r do
                local tx, ty = cx + dx, cy + dy
                if inBounds(tx, ty, width, height) and grid[ty][tx] ~= 3 and grid[ty][tx] ~= 4 then
                    fillRect(grid, tx - 1, ty - 1, tx + 1, ty + 1, 5, width, height)
                    goto found_plaza
                end
            end
        end
    end
    ::found_plaza::

    fillWithBuildings(grid, width, height, rng, theme and theme.densityMultiplier or 1.0)
end

-- Terraced: built on hillside with elevation levels
local function generateTerracedLayout(grid, width, height, rng, theme)
    local numTerraces = rng:random(3, 5)
    local terraceHeight = math.floor(height / numTerraces)

    for terrace = 0, numTerraces - 1 do
        local y1 = terrace * terraceHeight + 1
        local y2 = math.min((terrace + 1) * terraceHeight, height)

        -- Terrace edge (wall/retaining wall)
        for x = 1, width do
            if y1 <= height then
                setCell(grid, x, y1, 1, width, height)
            end
        end

        -- Vertical streets (stairs/ramps) connecting terraces
        local numStairs = rng:random(2, 4)
        local spacing = math.floor(width / (numStairs + 1))
        for s = 1, numStairs do
            local sx = s * spacing
            for y = y1, y2 do
                if y <= height then
                    setCell(grid, sx, y, 1, width, height)
                end
            end
        end

        -- Horizontal mid-terrace street
        local midY = math.floor((y1 + y2) / 2)
        if midY <= height and midY ~= y1 then
            for x = 1, width do
                setCell(grid, x, midY, 1, width, height)
            end
        end
    end

    -- Plaza at top terrace (viewpoint)
    local topCenter = math.floor(width / 2)
    local topY = math.floor(terraceHeight / 2)
    topY = math.max(2, math.min(topY, height - 2))
    fillRect(grid, topCenter - 2, topY - 2, topCenter + 2, topY + 2, 5, width, height)
    setCell(grid, topCenter, topY, 9, width, height)

    fillWithBuildings(grid, width, height, rng, theme and theme.densityMultiplier or 1.0)
end

-- Fortified: defensive walls and gates (medium/large)
local function generateFortifiedLayout(grid, width, height, rng, theme)
    -- Use elliptical walls for variety
    local cx = math.floor(width / 2)
    local cy = math.floor(height / 2)
    local rx = math.floor(width / 2) - 1
    local ry = math.floor(height / 2) - 1

    -- Elliptical walls
    for angle = 0, 2 * math.pi, 0.05 do
        local wx = math.floor(cx + rx * math.cos(angle) + 0.5)
        local wy = math.floor(cy + ry * math.sin(angle) + 0.5)
        setCell(grid, wx, wy, 6, width, height)
    end

    -- Gates at cardinal directions
    setCell(grid, cx, 1, 10, width, height)        -- N
    setCell(grid, cx, height, 10, width, height)    -- S
    setCell(grid, 1, cy, 10, width, height)         -- W
    setCell(grid, width, cy, 10, width, height)     -- E

    -- Main roads gate to gate
    for x = 2, width - 1 do
        if grid[cy][x] ~= 6 then
            setCell(grid, x, cy, 1, width, height)
        end
    end
    for y = 2, height - 1 do
        if grid[y][cx] ~= 6 then
            setCell(grid, cx, y, 1, width, height)
        end
    end

    -- Central keep
    fillRect(grid, cx - 3, cy - 3, cx + 3, cy + 3, 5, width, height)
    setCell(grid, cx, cy, 9, width, height)

    -- Internal streets
    for x = 5, width - 5, 5 do
        for y = 2, height - 1 do
            if grid[y][x] == 0 then
                grid[y][x] = 1
            end
        end
    end
    for y = 5, height - 5, 5 do
        for x = 2, width - 1 do
            if grid[y][x] == 0 then
                grid[y][x] = 1
            end
        end
    end

    -- Remove buildings outside walls (mark as empty)
    for y = 1, height do
        for x = 1, width do
            if grid[y][x] == 0 then
                -- Check if outside the ellipse
                local dx = (x - cx) / rx
                local dy = (y - cy) / ry
                if dx * dx + dy * dy > 1.05 then
                    -- Outside walls, leave empty
                else
                    -- Inside walls, eligible for buildings
                end
            end
        end
    end

    fillWithBuildings(grid, width, height, rng, theme and theme.densityMultiplier or 1.0, 2)

    -- Clear outside ellipse
    for y = 1, height do
        for x = 1, width do
            local dx = (x - cx) / rx
            local dy = (y - cy) / ry
            if dx * dx + dy * dy > 1.1 and grid[y][x] == 2 then
                grid[y][x] = 0
            end
        end
    end
end

-- ============================================================================
--                  NATURAL FEATURES POST-PASS
-- ============================================================================

local function addNaturalFeatures(grid, width, height, rng, theme, layoutStyle)
    -- Add trees/gardens based on theme
    if theme then
        -- Scatter trees in empty spaces
        for y = 1, height do
            for x = 1, width do
                if grid[y][x] == 0 then
                    if rng:chance(theme.treeChance or 0.05) then
                        grid[y][x] = 7  -- Garden/tree
                    end
                end
            end
        end

        -- Add gardens near plazas
        for y = 2, height - 1 do
            for x = 2, width - 1 do
                if grid[y][x] == 0 and adjacentTo(grid, x, y, 5, width, height) then
                    if rng:chance(theme.gardenChance or 0.08) then
                        grid[y][x] = 7
                    end
                end
            end
        end

        -- Swamp: add boardwalks and water channels
        if theme.useBoardwalks then
            for y = 1, height do
                for x = 1, width do
                    -- Convert some streets to boardwalks
                    if grid[y][x] == 1 and rng:chance(0.3) then
                        grid[y][x] = 11  -- Boardwalk
                    end
                    -- Add water channels
                    if grid[y][x] == 0 and rng:chance(theme.waterFrequency or 0.1) then
                        grid[y][x] = 3  -- Water
                    end
                end
            end
        end

        -- Coastal: add docks
        if theme.hasDocks and layoutStyle ~= "riverside" and layoutStyle ~= "split" then
            addDocks(grid, rng, width, height, rng:chance(0.5) and "south" or "east")
        end
    end

    -- Random pond/fountain if no water features exist
    local hasWater = false
    for y = 1, height do
        for x = 1, width do
            if grid[y][x] == 3 or grid[y][x] == 4 then
                hasWater = true
                break
            end
        end
        if hasWater then break end
    end

    if not hasWater and rng:chance(0.4) then
        -- Add a small pond or fountain
        local cx = rng:random(4, width - 4)
        local cy = rng:random(4, height - 4)
        -- Find an empty spot
        for r = 0, 5 do
            for dy = -r, r do
                for dx = -r, r do
                    if inBounds(cx + dx, cy + dy, width, height) and
                       grid[cy + dy][cx + dx] == 0 then
                        addPond(grid, rng, cx + dx, cy + dy, width, height, 1)
                        goto found_pond_spot
                    end
                end
            end
        end
        ::found_pond_spot::
    end
end

-- ============================================================================
--                    REGIONAL THEME APPLICATION
-- ============================================================================

local function getThemeForRegion(regionId)
    if not regionId then return REGIONAL_THEMES.plains end
    local themeKey = REGION_THEME_MAP[regionId]
    if themeKey and REGIONAL_THEMES[themeKey] then
        return REGIONAL_THEMES[themeKey]
    end
    return REGIONAL_THEMES.plains  -- default
end

-- ============================================================================
--                    LAYOUT SELECTION LOGIC
-- ============================================================================

local SMALL_LAYOUTS = {"circular", "linear", "clustered", "small_riverside"}
local MEDIUM_LAYOUTS = {"grid", "radial", "organic", "riverside", "split", "fortified", "terraced", "plaza"}
local LARGE_LAYOUTS = {"district", "walled", "plaza_centric", "canal", "radial", "grid", "fortified"}

local LAYOUT_GENERATORS = {
    circular = generateCircularLayout,
    linear = generateLinearLayout,
    clustered = generateClusteredLayout,
    small_riverside = generateSmallRiversideLayout,
    grid = generateGridLayout,
    radial = generateRadialLayout,
    organic = generateOrganicLayout,
    riverside = generateRiversideLayout,
    split = generateSplitLayout,
    fortified = generateFortifiedLayout,
    terraced = generateTerracedLayout,
    plaza = generatePlazaCentricLayout,
    district = generateDistrictLayout,
    walled = generateWalledLayout,
    plaza_centric = generatePlazaCentricLayout,
    canal = generateCanalLayout,
}

local function selectLayout(rng, sizeCategory, theme, specialization)
    local pool

    if sizeCategory == "small" then
        pool = SMALL_LAYOUTS
    elseif sizeCategory == "medium" then
        pool = MEDIUM_LAYOUTS
    else
        pool = LARGE_LAYOUTS
    end

    -- Specialization overrides
    local specName = specialization and specialization.name or ""
    if specName == "Port City" then
        if sizeCategory == "small" then
            return rng:chance(0.7) and "small_riverside" or "linear"
        else
            return rng:chance(0.6) and "riverside" or "split"
        end
    elseif specName == "Mountain Hold" then
        return rng:chance(0.5) and "fortified" or "terraced"
    elseif specName == "Magic Academy" then
        return rng:chance(0.5) and "radial" or "plaza"
    elseif specName == "Trade Hub" then
        if sizeCategory == "large" then
            return rng:chance(0.5) and "district" or "grid"
        else
            return rng:chance(0.6) and "grid" or "plaza"
        end
    end

    -- Theme preferences (weighted choice)
    if theme and theme.preferredLayouts then
        -- 60% chance to use a theme-preferred layout
        if rng:chance(0.6) then
            local preferred = theme.preferredLayouts
            -- Filter to only layouts available in our size pool
            local validPreferred = {}
            for _, pref in ipairs(preferred) do
                for _, poolItem in ipairs(pool) do
                    if pref == poolItem then
                        table.insert(validPreferred, pref)
                        break
                    end
                end
            end
            if #validPreferred > 0 then
                return validPreferred[rng:random(1, #validPreferred)]
            end
        end
    end

    -- Random from pool
    return pool[rng:random(1, #pool)]
end

-- ============================================================================
--                     MAIN GENERATION FUNCTION
-- ============================================================================

function TownGen.generateTownLayout(level, specialization, regionId, townSeed)
    -- Determine seed for deterministic generation
    local seed = townSeed or (os.time() + (level or 1) * 1000 + math.random(0, 99999))
    local rng = SeededRandom.new(seed)

    -- Get theme based on region
    local theme = getThemeForRegion(regionId)
    local themeKey = REGION_THEME_MAP[regionId] or "plains"

    -- Estimate population and size category (using seeded RNG for determinism)
    local population = estimatePopulation(level or 1, rng)
    local sizeCategory = getSizeCategory(population)

    -- Determine grid dimensions based on level/population
    local baseSize
    if sizeCategory == "small" then
        baseSize = rng:random(10, 14)
    elseif sizeCategory == "medium" then
        baseSize = rng:random(16, 24)
    elseif sizeCategory == "large" then
        baseSize = rng:random(26, 34)
    elseif sizeCategory == "capital" then
        baseSize = rng:random(34, 44)
    else -- mega
        baseSize = rng:random(44, 56)
    end

    local gridWidth = baseSize + rng:random(-2, 2)
    local gridHeight = baseSize + rng:random(-2, 2)
    gridWidth = math.max(8, gridWidth)
    gridHeight = math.max(8, gridHeight)

    -- Select layout style
    local layoutStyle = selectLayout(rng, sizeCategory, theme, specialization)

    -- Create and populate grid
    local grid = createGrid(gridWidth, gridHeight, 0)

    -- Run the appropriate layout generator
    local generator = LAYOUT_GENERATORS[layoutStyle]
    if generator then
        generator(grid, gridWidth, gridHeight, rng, theme)
    else
        -- Fallback to grid layout
        generateGridLayout(grid, gridWidth, gridHeight, rng, theme)
        layoutStyle = "grid"
    end

    -- Add natural features as post-pass
    addNaturalFeatures(grid, gridWidth, gridHeight, rng, theme, layoutStyle)

    -- Count tile types for metadata
    local counts = {
        buildings = 0,
        streets = 0,
        water = 0,
        bridges = 0,
        plazas = 0,
        walls = 0,
        gardens = 0,
        docks = 0,
        decorative = 0,
        gates = 0,
        boardwalks = 0,
    }
    for y = 1, gridHeight do
        for x = 1, gridWidth do
            local cell = grid[y][x]
            if cell == 2 then counts.buildings = counts.buildings + 1
            elseif cell == 1 then counts.streets = counts.streets + 1
            elseif cell == 3 then counts.water = counts.water + 1
            elseif cell == 4 then counts.bridges = counts.bridges + 1
            elseif cell == 5 then counts.plazas = counts.plazas + 1
            elseif cell == 6 then counts.walls = counts.walls + 1
            elseif cell == 7 then counts.gardens = counts.gardens + 1
            elseif cell == 8 then counts.docks = counts.docks + 1
            elseif cell == 9 then counts.decorative = counts.decorative + 1
            elseif cell == 10 then counts.gates = counts.gates + 1
            elseif cell == 11 then counts.boardwalks = counts.boardwalks + 1
            end
        end
    end

    -- Assemble the layout data structure
    local layout = {
        -- Core data
        style = layoutStyle,
        width = gridWidth,
        height = gridHeight,
        grid = grid,
        seed = seed,

        -- Theme info
        theme = themeKey,
        themeName = theme.name,
        themeData = {
            groundColor = theme.groundColor,
            streetColor = theme.streetColor,
            buildingColors = theme.buildingColors,
            roofColor = theme.roofColor,
            waterColor = theme.waterColor,
            wallColor = theme.wallColor,
            featureColor = theme.featureColor,
            description = theme.description,
        },

        -- Feature flags
        hasRiver = counts.water > 0,
        hasBridges = counts.bridges > 0,
        hasWalls = counts.walls > 0,
        hasGardens = counts.gardens > 0,
        hasDocks = counts.docks > 0,
        hasBoardwalks = counts.boardwalks > 0,
        hasGates = counts.gates > 0,

        -- Metadata
        population = population,
        sizeCategory = sizeCategory,
        buildingCount = counts.buildings,
        tileCounts = counts,
    }

    return layout
end

-- ============================================================================
--                   TILE TYPE DEFINITIONS (for rendering)
-- ============================================================================
-- These define how each tile type should be drawn. The rendering code
-- in textrpg.lua can use these as defaults if no custom colors are set.

TownGen.TILE_TYPES = {
    [0]  = {name = "empty",      passable = true,  icon = " "},
    [1]  = {name = "street",     passable = true,  icon = "."},
    [2]  = {name = "building",   passable = false, icon = "#"},
    [3]  = {name = "water",      passable = false, icon = "~"},
    [4]  = {name = "bridge",     passable = true,  icon = "="},
    [5]  = {name = "plaza",      passable = true,  icon = "+"},
    [6]  = {name = "wall",       passable = false, icon = "W"},
    [7]  = {name = "garden",     passable = true,  icon = "T"},
    [8]  = {name = "dock",       passable = true,  icon = "P"},
    [9]  = {name = "decorative", passable = true,  icon = "*"},
    [10] = {name = "gate",       passable = true,  icon = "G"},
    [11] = {name = "boardwalk",  passable = true,  icon = "_"},
    [12] = {name = "lighthouse", passable = false, icon = "L"},
}

-- ============================================================================
--                   REGIONAL THEME ACCESSORS
-- ============================================================================

function TownGen.getThemeForRegion(regionId)
    return getThemeForRegion(regionId)
end

function TownGen.getThemeKey(regionId)
    return REGION_THEME_MAP[regionId] or "plains"
end

function TownGen.getRegionalThemes()
    return REGIONAL_THEMES
end

function TownGen.getRegionThemeMap()
    return REGION_THEME_MAP
end

-- ============================================================================
--                COMPATIBILITY: Legacy format conversion
-- ============================================================================
-- Converts a new-format layout back to the old grid-only format used
-- by the existing textrpg.lua renderer, so existing drawing code continues
-- to work without changes.

function TownGen.toLegacyLayout(layout)
    if not layout then return nil end
    return {
        style = layout.style,
        width = layout.width,
        height = layout.height,
        grid = layout.grid,
        buildingCount = layout.buildingCount,
        hasRiver = layout.hasRiver,
        hasBridges = layout.hasBridges,
        hasWalls = layout.hasWalls,
        -- New fields (ignored by old code, used by new code)
        theme = layout.theme,
        themeName = layout.themeName,
        themeData = layout.themeData,
        hasGardens = layout.hasGardens,
        hasDocks = layout.hasDocks,
        hasBoardwalks = layout.hasBoardwalks,
        hasGates = layout.hasGates,
        population = layout.population,
        sizeCategory = layout.sizeCategory,
        tileCounts = layout.tileCounts,
        seed = layout.seed,
    }
end

-- ============================================================================
--                    DEBUG: ASCII PRINT
-- ============================================================================
-- Useful for testing in the console

function TownGen.printLayout(layout)
    if not layout or not layout.grid then
        print("No layout to print")
        return
    end

    local tileChars = {}
    for id, def in pairs(TownGen.TILE_TYPES) do
        tileChars[id] = def.icon
    end

    print(string.format("=== %s layout (%s, %dx%d, pop %d) ===",
        layout.style, layout.themeName or "unknown",
        layout.width, layout.height, layout.population or 0))

    for y = 1, layout.height do
        local row = ""
        for x = 1, layout.width do
            local cell = layout.grid[y][x]
            row = row .. (tileChars[cell] or "?")
        end
        print(row)
    end

    print(string.format("Buildings: %d, Streets: %d, Water: %d, Bridges: %d",
        layout.tileCounts.buildings, layout.tileCounts.streets,
        layout.tileCounts.water, layout.tileCounts.bridges))
    print(string.format("Plazas: %d, Walls: %d, Gardens: %d, Docks: %d",
        layout.tileCounts.plazas, layout.tileCounts.walls,
        layout.tileCounts.gardens, layout.tileCounts.docks))
end

-- ============================================================================
--                BUILDING TYPE VARIETY SYSTEM
-- ============================================================================
-- Assigns specific building types to each town based on size, region,
-- specialization, and anchor status. Produces a per-town building list
-- that replaces the static TOWN_BUILDINGS when available.

-- Building type definitions: id, display name, icon text, action binding,
-- base color, description, and category for selection probability.
local BUILDING_DEFS = {
    -- Core buildings (always present)
    townhall    = {id="townhall",    name="Town Hall",      icon="HALL",  action="elders",            color={0.70,0.60,0.40}, desc="Visit the elders",           category="core"},
    market      = {id="market",      name="Trading Post",   icon="MKT",   action="stockmarket",       color={0.40,0.50,0.50}, desc="Trade stocks & goods",       category="core", purchasable=true, propertyType="business"},
    tavern      = {id="tavern",      name="Tavern",         icon="TAV",   action="tavern_interior",   color={0.60,0.50,0.30}, desc="Rest, work, & socialize",    category="core"},

    -- Common buildings (high chance)
    shop        = {id="shop",        name="General Store",  icon="SHOP",  action="building_interior", color={0.40,0.60,0.40}, desc="Visit the general store",    category="common"},
    forge       = {id="forge",       name="Forge",          icon="FORGE", action="forge",             color={0.70,0.40,0.20}, desc="Craft weapons & armor",      category="common", purchasable=true, propertyType="business"},
    stable      = {id="stable",      name="Stable",         icon="STABLE",action="building_interior", color={0.50,0.40,0.30}, desc="Visit the stable",           category="common"},
    house_1     = {id="house_1",     name="House",          icon="HUT",   action="property",          color={0.40,0.42,0.38}, desc="Residential house",          category="common", purchasable=true, propertyType="home"},
    house_2     = {id="house_2",     name="Cottage",        icon="HUT",   action="property",          color={0.45,0.40,0.35}, desc="Small cottage",              category="common", purchasable=true, propertyType="home"},
    house_3     = {id="house_3",     name="Dwelling",       icon="HUT",   action="property",          color={0.42,0.40,0.35}, desc="Modest dwelling",            category="common", purchasable=true, propertyType="home"},

    -- Uncommon buildings (medium chance)
    chapel      = {id="chapel",      name="Chapel",         icon="PRAY",  action="building_interior", color={0.80,0.80,0.60}, desc="Visit the chapel",           category="uncommon"},
    guild       = {id="guild",       name="Guild Hall",     icon="GUILD", action="guild_interior",    color={0.50,0.40,0.60}, desc="Quests & companions",        category="uncommon"},
    library     = {id="library",     name="Library",        icon="BOOK",  action="building_interior", color={0.50,0.45,0.55}, desc="Browse ancient tomes",       category="uncommon"},
    alchemist   = {id="alchemist",   name="Alchemist",      icon="ALCH",  action="alchemist",         color={0.30,0.60,0.40}, desc="Brew potions",               category="uncommon", purchasable=true, propertyType="business"},
    butcher     = {id="butcher",     name="Butcher",        icon="MEAT",  action="building_interior", color={0.70,0.35,0.35}, desc="Explore the butcher shop",   category="uncommon"},
    bakery      = {id="bakery",      name="Bakery",         icon="BAKE",  action="building_interior", color={0.80,0.70,0.50}, desc="Explore the bakery",         category="uncommon"},

    -- Rare buildings (low chance)
    wizardtower = {id="wizardtower", name="Wizard Tower",   icon="TOWER", action="wizardtower",       color={0.40,0.30,0.70}, desc="Create spells & scrolls",    category="rare", purchasable=true, propertyType="business"},
    cathedral   = {id="cathedral",   name="Cathedral",      icon="CATH",  action="building_interior", color={0.85,0.82,0.65}, desc="A grand place of worship",   category="rare"},
    graveyard   = {id="graveyard",   name="Graveyard",      icon="TOMB",  action="building_interior", color={0.35,0.35,0.40}, desc="Rows of weathered markers",  category="rare"},
    barracks    = {id="barracks",    name="Barracks",       icon="ARMY",  action="building_interior", color={0.50,0.42,0.35}, desc="The town garrison",          category="rare"},
    observatory = {id="observatory", name="Observatory",    icon="STAR",  action="building_interior", color={0.35,0.35,0.55}, desc="Study the heavens",          category="rare"},
    theater     = {id="theater",     name="Theater",        icon="STAGE", action="building_interior", color={0.60,0.40,0.50}, desc="Performances & drama",       category="rare"},
    arena       = {id="arena",       name="Arena",          icon="ARENA", action="building_interior", color={0.55,0.40,0.30}, desc="Gladiatorial combats",       category="rare"},

    -- Specialty buildings (based on region/type)
    harbor      = {id="harbor",      name="Harbor",         icon="DOCK",  action="building_interior", color={0.35,0.50,0.65}, desc="Ships come and go",          category="specialty"},
    mine_entrance={id="mine_entrance",name="Mine Entrance", icon="MINE",  action="building_interior", color={0.45,0.40,0.35}, desc="Descent into the earth",     category="specialty"},
    lumber_mill = {id="lumber_mill", name="Lumber Mill",    icon="MILL",  action="building_interior", color={0.50,0.42,0.28}, desc="Processing timber",          category="specialty"},
    oasis       = {id="oasis",       name="Oasis Garden",   icon="OASIS", action="building_interior", color={0.30,0.55,0.45}, desc="Cool shade and water",       category="specialty"},
    ice_lodge   = {id="ice_lodge",   name="Warming Lodge",  icon="FIRE",  action="building_interior", color={0.55,0.35,0.25}, desc="Warmth against the cold",    category="specialty"},

    -- Activity buildings
    fishing     = {id="fishing",     name="Fishing Dock",   icon="FISH",  action="fishing",           color={0.30,0.50,0.70}, desc="Cast your line",             category="common", purchasable=true, propertyType="business"},
    hunting     = {id="hunting",     name="Hunter's Lodge", icon="HUNT",  action="hunting",           color={0.50,0.40,0.30}, desc="Track wild game",            category="common", purchasable=true, propertyType="business"},

    -- Shops
    tailor      = {id="tailor",      name="Tailor",         icon="CLOTH", action="building_interior", color={0.60,0.50,0.70}, desc="Explore the tailor shop",    category="uncommon"},
    jeweler     = {id="jeweler",     name="Jeweler",        icon="GEM",   action="building_interior", color={0.50,0.70,0.80}, desc="Explore the jeweler",        category="uncommon"},

    -- Properties
    noble_estate= {id="noble_estate",name="Noble Estate",   icon="HOME",  action="property",          color={0.50,0.45,0.55}, desc="Grand residence",            category="rare", purchasable=true, propertyType="home"},
    manor       = {id="manor",       name="Manor House",    icon="HOME",  action="property",          color={0.55,0.50,0.60}, desc="Stately manor",              category="rare", purchasable=true, propertyType="home"},
    warehouse   = {id="warehouse",   name="Warehouse",      icon="CRATE", action="property",          color={0.40,0.40,0.40}, desc="Storage facility",           category="uncommon", purchasable=true, propertyType="home"},
    farmhouse   = {id="farmhouse",   name="Farmhouse",      icon="HUT",   action="property",          color={0.42,0.40,0.35}, desc="Farmstead with land",        category="common", purchasable=true, propertyType="home"},
    shack       = {id="shack",       name="Shack",          icon="HUT",   action="property",          color={0.38,0.36,0.34}, desc="Humble shelter",             category="common", purchasable=true, propertyType="home"},
    well        = {id="well",        name="Town Well",      icon="WELL",  action="building_interior", color={0.35,0.45,0.55}, desc="Visit the well",             category="common"},

    -- Gate (always present at bottom)
    gate        = {id="gate",        name="Town Gate",      icon="GATE",  action="map",               color={0.40,0.40,0.50}, desc="Leave town",                 category="core"},

    -- === DISTRICT MARKERS (capital/mega cities only) ===
    -- These act as navigation points to enter distinct city districts
    market_district   = {id="market_district",   name="Market District",    icon="DIST",  action="enter_district", color={0.70,0.60,0.30}, desc="Bustling trade quarter",        category="district", districtId="market"},
    noble_quarter     = {id="noble_quarter",     name="Noble Quarter",      icon="DIST",  action="enter_district", color={0.60,0.55,0.70}, desc="Aristocratic residences",       category="district", districtId="noble"},
    slums             = {id="slums",             name="The Slums",          icon="DIST",  action="enter_district", color={0.35,0.32,0.28}, desc="Poverty and desperation",       category="district", districtId="slums"},
    temple_district   = {id="temple_district",   name="Temple District",    icon="DIST",  action="enter_district", color={0.80,0.78,0.55}, desc="Holy ground and worship",       category="district", districtId="temple"},
    harbor_district   = {id="harbor_district",   name="Harbor District",    icon="DIST",  action="enter_district", color={0.35,0.50,0.65}, desc="Docks, sailors, and trade",     category="district", districtId="harbor"},
    artisan_quarter   = {id="artisan_quarter",   name="Artisan Quarter",    icon="DIST",  action="enter_district", color={0.55,0.45,0.35}, desc="Workshops and craftsmen",       category="district", districtId="artisan"},
    military_quarter  = {id="military_quarter",  name="Military Quarter",   icon="DIST",  action="enter_district", color={0.50,0.40,0.35}, desc="Barracks and training grounds", category="district", districtId="military"},
    scholars_row      = {id="scholars_row",      name="Scholar's Row",      icon="DIST",  action="enter_district", color={0.45,0.45,0.60}, desc="Libraries and academies",       category="district", districtId="scholars"},
    entertainment_dist= {id="entertainment_dist",name="Entertainment Dist.",icon="DIST",  action="enter_district", color={0.65,0.45,0.55}, desc="Theaters, taverns, and fun",    category="district", districtId="entertainment"},
    foreign_quarter   = {id="foreign_quarter",   name="Foreign Quarter",    icon="DIST",  action="enter_district", color={0.50,0.48,0.42}, desc="Immigrants and exotic wares",   category="district", districtId="foreign"},

    -- === GUILD HALLS (interactable guild buildings) ===
    thieves_guild_hall = {id="thieves_guild_hall", name="Shadowed Alley",    icon="THIEF", action="guild_hall",    color={0.25,0.22,0.30}, desc="Hidden thieves guild entrance",  category="guild", guildId="thieves_guild"},
    fighters_guild_hall= {id="fighters_guild_hall",name="Fighters Guild",    icon="SWORD", action="guild_hall",    color={0.60,0.40,0.30}, desc="Warriors for hire",              category="guild", guildId="fighters_guild"},
    mages_guild_hall   = {id="mages_guild_hall",   name="Mages Guild Tower", icon="MAGIC", action="guild_hall",    color={0.40,0.35,0.70}, desc="Arcane studies and missions",    category="guild", guildId="mages_guild"},
    merchants_guild_hall={id="merchants_guild_hall",name="Merchants Guild",   icon="GOLD",  action="guild_hall",    color={0.70,0.60,0.35}, desc="Trade consortium headquarters",  category="guild", guildId="merchants_guild"},
    assassins_den      = {id="assassins_den",      name="The Dark Alcove",   icon="SKULL", action="guild_hall",    color={0.20,0.18,0.25}, desc="Death for coin",                 category="guild", guildId="assassins_guild"},

    -- === UNDERBELLY ENTRANCES ===
    sewer_entrance    = {id="sewer_entrance",    name="Sewer Grate",        icon="DOWN",  action="enter_underbelly", color={0.30,0.32,0.28}, desc="Descend into the sewers",       category="underbelly", underbellyType="sewers"},
    catacomb_entrance = {id="catacomb_entrance", name="Catacomb Door",      icon="DOWN",  action="enter_underbelly", color={0.35,0.30,0.35}, desc="Enter the catacombs",            category="underbelly", underbellyType="catacombs"},
    smuggler_tunnel   = {id="smuggler_tunnel",   name="Suspicious Cellar",  icon="DOWN",  action="enter_underbelly", color={0.32,0.28,0.25}, desc="A hidden passage below",         category="underbelly", underbellyType="tunnels"},

    -- === CITY INFRASTRUCTURE (mega/capital only) ===
    city_jail         = {id="city_jail",         name="City Jail",          icon="LOCK",  action="city_jail",     color={0.40,0.38,0.42}, desc="Where criminals are held",       category="rare"},
    bounty_board      = {id="bounty_board",      name="Bounty Board",       icon="WANTED",action="bounty_board",  color={0.65,0.45,0.30}, desc="Criminal bounties posted here",  category="uncommon"},
    courier_office    = {id="courier_office",    name="Courier Office",     icon="MAIL",  action="courier_office",color={0.45,0.55,0.50}, desc="Deliver messages for pay",       category="uncommon"},
}

-- IDs for each selection pool
local CORE_BUILDING_IDS     = {"townhall", "market", "tavern"}
local COMMON_BUILDING_IDS   = {"shop", "forge", "stable", "house_1", "house_2", "fishing", "hunting", "well", "farmhouse", "shack"}
local UNCOMMON_BUILDING_IDS = {"chapel", "guild", "library", "alchemist", "butcher", "bakery", "tailor", "jeweler", "warehouse", "bounty_board", "courier_office"}
local RARE_BUILDING_IDS     = {"wizardtower", "cathedral", "graveyard", "barracks", "observatory", "theater", "arena", "noble_estate", "manor", "city_jail"}
-- District buildings only appear in capital/mega cities
local DISTRICT_BUILDING_IDS = {"market_district", "noble_quarter", "slums", "temple_district", "artisan_quarter", "military_quarter", "scholars_row", "entertainment_dist", "foreign_quarter", "harbor_district"}
-- Guild hall buildings (appear based on city size and karma)
local GUILD_HALL_IDS        = {"thieves_guild_hall", "fighters_guild_hall", "mages_guild_hall", "merchants_guild_hall", "assassins_den"}
-- Underbelly entrances (appear in larger cities)
local UNDERBELLY_IDS        = {"sewer_entrance", "catacomb_entrance", "smuggler_tunnel"}

-- Region-specific specialty mapping
local REGION_SPECIALTY_MAP = {
    coastal         = {"harbor", "fishing"},
    mountain        = {"mine_entrance", "barracks"},
    forest          = {"lumber_mill", "hunting"},
    desert          = {"oasis"},
    swamp           = {"fishing"},
    frozen          = {"ice_lodge"},
    plains          = {"farmhouse"},
}

-- Specialization bonus buildings (extra buildings that specialization adds)
local SPEC_BONUS = {
    ["Mining Town"]       = {"mine_entrance", "forge", "warehouse"},
    ["Farming Village"]   = {"farmhouse", "well", "bakery", "butcher"},
    ["Port City"]         = {"harbor", "fishing", "warehouse", "jeweler"},
    ["Forest Settlement"] = {"lumber_mill", "hunting", "stable"},
    ["Magic Academy"]     = {"wizardtower", "library", "alchemist", "observatory"},
    ["Trade Hub"]         = {"warehouse", "jeweler", "tailor"},
    ["Noble Estate"]      = {"noble_estate", "manor", "theater", "cathedral"},
    ["Mountain Hold"]     = {"mine_entrance", "forge", "barracks"},
}

-- Building count ranges by size category
local BUILDING_COUNT_RANGES = {
    small   = {min = 3,  max = 8},
    medium  = {min = 10, max = 20},
    large   = {min = 25, max = 50},
    capital = {min = 40, max = 70},
    mega    = {min = 60, max = 100},
    anchor  = {min = 30, max = 60},
}

-- ============================================================================
--            BUILDING SELECTION ALGORITHM
-- ============================================================================

--- Select buildings for a town.
-- @param rng           SeededRandom instance
-- @param sizeCategory  "small", "medium", "large", or "anchor"
-- @param regionTheme   string key from REGION_THEME_MAP (e.g. "mountain")
-- @param specialization  table with .name field (e.g. {name="Port City"})
-- @param isAnchor      boolean
-- @return              ordered list of building definition copies
local function selectTownBuildings(rng, sizeCategory, regionTheme, specialization, isAnchor)
    local effectiveSize = isAnchor and "anchor" or sizeCategory
    local range = BUILDING_COUNT_RANGES[effectiveSize] or BUILDING_COUNT_RANGES.medium
    local targetCount = rng:random(range.min, range.max)

    -- Track which building IDs we have already added
    local added = {}
    local result = {}

    local function addBuilding(bid)
        if added[bid] then return end
        local def = BUILDING_DEFS[bid]
        if not def then return end
        added[bid] = true
        -- Make a shallow copy so we can set per-instance position later
        local b = {}
        for k, v in pairs(def) do b[k] = v end
        table.insert(result, b)
    end

    -- 1) Always add core buildings
    for _, bid in ipairs(CORE_BUILDING_IDS) do
        addBuilding(bid)
    end

    -- 2) Common buildings (80% chance each)
    for _, bid in ipairs(COMMON_BUILDING_IDS) do
        if rng:chance(0.80) then
            addBuilding(bid)
        end
    end

    -- 3) Uncommon buildings (40% chance each)
    for _, bid in ipairs(UNCOMMON_BUILDING_IDS) do
        if rng:chance(0.40) then
            addBuilding(bid)
        end
    end

    -- 4) Rare buildings (15% chance each, higher for large/anchor)
    local rareChance = 0.15
    if effectiveSize == "large" then rareChance = 0.25 end
    if effectiveSize == "anchor" then rareChance = 0.40 end
    for _, bid in ipairs(RARE_BUILDING_IDS) do
        if rng:chance(rareChance) then
            addBuilding(bid)
        end
    end

    -- 5) Region specialty buildings (always added if region matches)
    if regionTheme and REGION_SPECIALTY_MAP[regionTheme] then
        for _, bid in ipairs(REGION_SPECIALTY_MAP[regionTheme]) do
            addBuilding(bid)
        end
    end

    -- 6) Specialization bonus buildings
    local specName = specialization and (type(specialization) == "table" and specialization.name or specialization) or ""
    if SPEC_BONUS[specName] then
        for _, bid in ipairs(SPEC_BONUS[specName]) do
            addBuilding(bid)
        end
    end

    -- 7) Anchor cities always get prestigious buildings
    if isAnchor then
        addBuilding("cathedral")
        addBuilding("library")
        addBuilding("guild")
        addBuilding("barracks")
        addBuilding("noble_estate")
        addBuilding("manor")
        addBuilding("chapel")
        addBuilding("alchemist")
        addBuilding("wizardtower")
        addBuilding("butcher")
        addBuilding("bakery")
        addBuilding("tailor")
        addBuilding("jeweler")
    end

    -- 7b) Capital/mega cities get district markers
    if effectiveSize == "capital" or effectiveSize == "mega" or isAnchor then
        -- Always add key districts
        addBuilding("market_district")
        addBuilding("noble_quarter")
        addBuilding("slums")
        addBuilding("bounty_board")
        addBuilding("courier_office")
        -- Guild halls (fighters and mages always, thieves in cities with slums)
        addBuilding("fighters_guild_hall")
        addBuilding("mages_guild_hall")
        addBuilding("merchants_guild_hall")
        if rng:chance(0.7) then addBuilding("thieves_guild_hall") end
        -- Additional districts based on size
        if effectiveSize == "mega" or isAnchor then
            addBuilding("temple_district")
            addBuilding("artisan_quarter")
            addBuilding("military_quarter")
            addBuilding("scholars_row")
            addBuilding("city_jail")
            if rng:chance(0.5) then addBuilding("entertainment_dist") end
            if rng:chance(0.4) then addBuilding("foreign_quarter") end
            if rng:chance(0.3) then addBuilding("assassins_den") end
        end
        -- Underbelly entrances
        addBuilding("sewer_entrance")
        if effectiveSize == "mega" or isAnchor then
            addBuilding("catacomb_entrance")
            if rng:chance(0.5) then addBuilding("smuggler_tunnel") end
        end
    elseif effectiveSize == "large" then
        -- Large towns get a bounty board and maybe a guild
        addBuilding("bounty_board")
        if rng:chance(0.5) then addBuilding("courier_office") end
        if rng:chance(0.4) then addBuilding("fighters_guild_hall") end
        if rng:chance(0.3) then addBuilding("sewer_entrance") end
    end

    -- 8) Trim or pad to target count (gate is added separately)
    -- If we have too many, remove from the end (rarest added last)
    while #result > targetCount and #result > 3 do
        -- Remove last non-core entry
        local removed = false
        for i = #result, 1, -1 do
            if result[i].category ~= "core" then
                added[result[i].id] = nil
                table.remove(result, i)
                removed = true
                break
            end
        end
        if not removed then break end
    end

    -- If we still need more, add filler houses
    local fillerIdx = 0
    while #result < targetCount do
        fillerIdx = fillerIdx + 1
        local fillId = "filler_house_" .. fillerIdx
        local houseColors = {
            {0.42, 0.40, 0.36}, {0.48, 0.44, 0.38}, {0.44, 0.42, 0.40},
            {0.46, 0.43, 0.37}, {0.40, 0.38, 0.35}, {0.50, 0.46, 0.40},
        }
        local c = houseColors[((fillerIdx - 1) % #houseColors) + 1]
        table.insert(result, {
            id = fillId,
            name = "House",
            icon = "HUT",
            action = "property",
            color = {c[1], c[2], c[3]},
            desc = "Residential house",
            category = "common",
            purchasable = true,
            propertyType = "home",
        })
    end

    -- Always add the gate as the very last building
    addBuilding("gate")

    return result
end

-- ============================================================================
--          BUILDING GRID PLACEMENT (assigns gridX, gridY)
-- ============================================================================
-- Places selected buildings onto the 6xN town grid used by textrpg.lua.
-- Column 3 is always the main street (empty). Even rows are horizontal
-- streets. Buildings fill odd rows (1, 3, 5, 7, ...) and the available
-- columns (1, 2, 4, 5, 6).

local function assignBuildingGridPositions(buildings)
    local STREET_COL = 3
    local buildingCols = {1, 2, 4, 5, 6}  -- columns where buildings can go

    -- Separate gate from the rest
    local gate = nil
    local others = {}
    for _, b in ipairs(buildings) do
        if b.id == "gate" then
            gate = b
        else
            table.insert(others, b)
        end
    end

    -- Calculate how many building rows we need
    -- Each row can hold up to 5 buildings (cols 1,2,4,5,6)
    local slotsPerRow = #buildingCols
    local numBuildingRows = math.ceil(#others / slotsPerRow)
    numBuildingRows = math.max(numBuildingRows, 3) -- at least 3 building rows

    -- Total grid rows: building rows interleaved with street rows, plus gate row
    -- Pattern: buildingRow, streetRow, buildingRow, streetRow, ...  gateRow
    -- Building row indices: 1, 3, 5, 7, ...
    -- Street row indices: 2, 4, 6, 8, ...
    local totalGridRows = numBuildingRows * 2  -- pairs of (building, street)
    totalGridRows = totalGridRows + 1  -- +1 for gate row at bottom

    -- Place buildings into slots
    local slotIdx = 0
    for _, b in ipairs(others) do
        local rowSlot = math.floor(slotIdx / slotsPerRow)
        local colSlot = (slotIdx % slotsPerRow) + 1
        local gridY = rowSlot * 2 + 1  -- odd rows: 1, 3, 5, 7 ...
        local gridX = buildingCols[colSlot]
        b.gridX = gridX
        b.gridY = gridY
        slotIdx = slotIdx + 1
    end

    -- Place gate at bottom center (street column, last row)
    if gate then
        gate.gridX = STREET_COL
        gate.gridY = totalGridRows
    end

    -- Build street row list (even rows below each building row)
    local streetRows = {}
    for r = 2, totalGridRows - 1, 2 do
        table.insert(streetRows, r)
    end

    return {
        buildings = buildings,
        gridCols = 6,
        gridRows = totalGridRows,
        streetCol = STREET_COL,
        streetRows = streetRows,
    }
end

-- ============================================================================
--       PUBLIC API: Generate building list for a town
-- ============================================================================

--- Generate a typed building list for a town.
-- Call this during town creation (generateTown / convertAnchorToLegacyTown).
-- @param opts table with keys: level, population, sizeCategory, regionTheme,
--             specialization (string or table), isAnchor, anchorId, seed
-- @return townBuildingData table {buildings, gridCols, gridRows, streetCol, streetRows}
function TownGen.generateTownBuildings(opts)
    opts = opts or {}
    local seed = opts.seed or os.time()
    local rng = SeededRandom.new(seed)

    local pop = opts.population or estimatePopulation(opts.level or 1, rng)
    local sizeCat = opts.sizeCategory or getSizeCategory(pop)
    local regionTheme = opts.regionTheme  -- e.g. "mountain", "desert", ...
    local specialization = opts.specialization
    local isAnchor = opts.isAnchor or false

    -- Select buildings
    local buildings = selectTownBuildings(rng, sizeCat, regionTheme, specialization, isAnchor)

    -- Assign grid positions
    local gridData = assignBuildingGridPositions(buildings)

    return gridData
end

-- ============================================================================
--       ANCHOR CITY PRESET LAYOUTS
-- ============================================================================
-- Each anchor city gets a hand-designed building list with extra unique
-- buildings and a larger grid. The preset determines WHICH buildings
-- appear; grid positions are computed automatically.

local ANCHOR_PRESETS = {
    -- -----------------------------------------------------------------------
    havenbrook = {
        displayName = "Havenbrook",
        themeOverride = "plains",
        sizeOverride = "small",  -- Small humble starting village (8-12 buildings)
        extraBuildings = {
            {id="lucky_coin",   name="The Lucky Coin",icon="COIN", action="tavern_interior",  color={0.70,0.55,0.25}, desc="Cozy village tavern",       category="landmark"},
            {id="chapel_helios",name="Chapel of Helios",icon="SUN",action="building_interior",color={0.85,0.80,0.55}, desc="Small sun chapel",          category="landmark"},
        },
        forceBuildings = {
            "townhall","market","tavern","shop","stable",
            "chapel","well","house_1","house_2","farmhouse",
        },
    },
    -- -----------------------------------------------------------------------
    ironhold = {
        displayName = "Ironhold",
        themeOverride = "mountain",
        extraBuildings = {
            {id="great_forge",   name="The Great Forge",  icon="ANVL", action="forge",             color={0.80,0.50,0.20}, desc="Legendary dwarven forge",    category="landmark"},
            {id="throne_stone",  name="Throne of Stone",  icon="CROWN",action="building_interior", color={0.55,0.52,0.48}, desc="Seat of dwarven power",      category="landmark"},
            {id="deep_mines",    name="Deep Mines",       icon="MINE", action="building_interior", color={0.40,0.38,0.35}, desc="Echoes from below",          category="landmark"},
            {id="rune_hall",     name="Rune Hall",        icon="RUNE", action="building_interior", color={0.50,0.48,0.58}, desc="Ancient rune inscriptions",  category="landmark"},
        },
        forceBuildings = {
            "townhall","market","tavern","shop","forge","stable","guild",
            "chapel","butcher","bakery","alchemist","mine_entrance",
            "barracks","warehouse","library","well",
            "house_1","house_2","house_3","noble_estate",
        },
    },
    -- -----------------------------------------------------------------------
    sylvaris = {
        displayName = "Sylvaris",
        themeOverride = "forest",
        extraBuildings = {
            {id="great_archive",  name="The Great Archive", icon="BOOK", action="building_interior", color={0.45,0.50,0.55}, desc="Repository of all knowledge", category="landmark"},
            {id="trade_tribunal", name="Trade Tribunal",    icon="LAW",  action="building_interior", color={0.50,0.48,0.52}, desc="Where disputes are settled",  category="landmark"},
            {id="ancient_tree",   name="The Ancient Tree",  icon="TREE", action="building_interior", color={0.25,0.50,0.25}, desc="Millennial sacred tree",      category="landmark"},
            {id="sealed_vault",   name="Sealed Vault",      icon="LOCK", action="building_interior", color={0.40,0.40,0.45}, desc="Forbidden knowledge within",  category="landmark"},
        },
        forceBuildings = {
            "townhall","market","tavern","shop","stable","guild",
            "chapel","library","alchemist","tailor","jeweler",
            "lumber_mill","hunting","warehouse",
            "house_1","house_2","house_3","noble_estate","manor",
        },
    },
    -- -----------------------------------------------------------------------
    murkmire = {
        displayName = "Murkmire",
        themeOverride = "swamp",
        extraBuildings = {
            {id="black_tower",    name="The Black Tower",   icon="DARK", action="building_interior", color={0.20,0.18,0.22}, desc="Witch Morgana's domain",     category="landmark"},
            {id="sunken_temple",  name="Sunken Temple",     icon="SINK", action="building_interior", color={0.25,0.30,0.22}, desc="Half-submerged ruins",        category="landmark"},
            {id="ferry_dock",     name="Ferryman's Dock",   icon="BOAT", action="building_interior", color={0.30,0.28,0.22}, desc="Charon waits here",           category="landmark"},
        },
        forceBuildings = {
            "townhall","market","tavern","shop","forge","stable",
            "chapel","alchemist","fishing","butcher",
            "house_1","house_2","well","shack",
            "graveyard",
        },
    },
    -- -----------------------------------------------------------------------
    solara = {
        displayName = "Solara, City of Light",
        themeOverride = "plains",
        sizeOverride = "large_capital",
        extraBuildings = {
            {id="grand_cathedral",name="Grand Cathedral",   icon="CATH", action="building_interior", color={0.90,0.85,0.60}, desc="Seat of the High Priest",     category="landmark"},
            {id="royal_palace",   name="Royal Palace",      icon="PALACE",action="building_interior",color={0.85,0.80,0.55}, desc="Halls of divine governance",  category="landmark"},
            {id="sacred_grove",   name="Sacred Grove",      icon="TREE", action="building_interior", color={0.30,0.55,0.30}, desc="Holy garden of contemplation", category="landmark"},
            {id="inquisition_hq", name="Inquisition HQ",    icon="EYE",  action="building_interior", color={0.60,0.55,0.45}, desc="The watchful order",          category="landmark"},
        },
        forceBuildings = {
            "townhall","market","tavern","shop","forge","stable","guild",
            "chapel","library","alchemist","butcher","bakery","tailor","jeweler",
            "wizardtower","barracks","theater","noble_estate","manor",
            "warehouse","fishing","hunting","well",
            "house_1","house_2","house_3","farmhouse",
            -- Districts
            "market_district","noble_quarter","slums","temple_district",
            "artisan_quarter","military_quarter","scholars_row",
            -- Guild halls
            "fighters_guild_hall","mages_guild_hall","merchants_guild_hall",
            -- Underbelly & infrastructure
            "sewer_entrance","catacomb_entrance",
            "city_jail","bounty_board","courier_office",
        },
    },
    -- -----------------------------------------------------------------------
    kragmor = {
        displayName = "Kragmor",
        themeOverride = "plains",
        extraBuildings = {
            {id="blood_arena",  name="Blood Arena",       icon="FIGHT",action="building_interior", color={0.65,0.30,0.25}, desc="Gladiatorial pit fights",     category="landmark"},
            {id="war_totems",   name="War Totems",        icon="TOTEM",action="building_interior", color={0.50,0.40,0.30}, desc="Sacred orcish monuments",     category="landmark"},
            {id="shaman_hut",   name="Shaman's Hut",      icon="SPIRIT",action="building_interior",color={0.40,0.45,0.35}, desc="Commune with the spirits",    category="landmark"},
        },
        forceBuildings = {
            "townhall","market","tavern","shop","forge","stable","guild",
            "butcher","hunting","barracks","warehouse",
            "house_1","house_2","shack","well",
        },
    },
    -- -----------------------------------------------------------------------
    mechspire = {
        displayName = "Mechspire",
        themeOverride = "coastal",
        extraBuildings = {
            {id="clockwork_tower", name="Clockwork Tower",  icon="GEAR", action="building_interior", color={0.55,0.55,0.60}, desc="Heart of gnomish ingenuity",  category="landmark"},
            {id="innovation_hall", name="Innovation Hall",  icon="IDEA", action="building_interior", color={0.50,0.52,0.58}, desc="Where inventions are born",   category="landmark"},
            {id="sky_docks",       name="Sky Docks",        icon="AIR",  action="building_interior", color={0.45,0.55,0.65}, desc="Airship landing platforms",   category="landmark"},
            {id="gear_market",     name="Gear Market",      icon="COG",  action="building_interior", color={0.48,0.50,0.55}, desc="Mechanical curiosities",      category="landmark"},
        },
        forceBuildings = {
            "townhall","market","tavern","shop","forge","stable","guild",
            "chapel","library","alchemist","wizardtower",
            "butcher","bakery","tailor","jeweler",
            "harbor","warehouse","fishing",
            "house_1","house_2","noble_estate","manor",
        },
    },
    -- -----------------------------------------------------------------------
    clockwork_harbor = {
        displayName = "Clockwork Harbor",
        themeOverride = "coastal",
        extraBuildings = {
            {id="lighthouse_auto", name="Lighthouse Automaton",icon="LIGHT",action="building_interior",color={0.60,0.60,0.55}, desc="Clockwork beacon",          category="landmark"},
            {id="trading_docks",   name="Trading Docks",      icon="SHIP", action="building_interior",color={0.45,0.50,0.55}, desc="International trade hub",   category="landmark"},
        },
        forceBuildings = {
            "townhall","market","tavern","shop","forge","stable",
            "harbor","fishing","warehouse","butcher","bakery",
            "house_1","house_2","well",
        },
    },
    -- -----------------------------------------------------------------------
    bonetrap = {
        displayName = "BoneTrap",
        themeOverride = "plains",
        extraBuildings = {
            {id="scrap_heap",  name="Scrap Heap",      icon="JUNK", action="building_interior", color={0.42,0.38,0.30}, desc="One goblin's treasure",       category="landmark"},
            {id="boom_corner", name="Boom Corner",     icon="BOOM", action="building_interior", color={0.55,0.35,0.25}, desc="Explosives workshop",         category="landmark"},
            {id="boss_shack",  name="Boss's Shack",    icon="BOSS", action="building_interior", color={0.45,0.40,0.32}, desc="Current boss lives here",     category="landmark"},
        },
        forceBuildings = {
            "townhall","market","tavern","shop","forge",
            "hunting","butcher","shack","well",
            "house_1","house_2",
        },
    },
    -- -----------------------------------------------------------------------
    fortunes_rest = {
        displayName = "Fortune's Rest",
        themeOverride = "desert",
        extraBuildings = {
            {id="cats_eye_casino",name="Cat's Eye Casino", icon="DICE", action="building_interior", color={0.80,0.65,0.30}, desc="Elegant games of chance",     category="landmark"},
            {id="golden_docks",   name="Golden Docks",     icon="DOCK", action="building_interior", color={0.75,0.60,0.25}, desc="Desert harbor piers",          category="landmark"},
            {id="silk_bazaar",    name="Silk Bazaar",       icon="SILK", action="building_interior", color={0.70,0.55,0.40}, desc="Exotic wares from afar",       category="landmark"},
            {id="acrobat_arena",  name="Arena of Acrobats", icon="FLIP", action="building_interior", color={0.65,0.50,0.35}, desc="Dazzling performances",        category="landmark"},
        },
        forceBuildings = {
            "townhall","market","tavern","shop","forge","stable","guild",
            "chapel","alchemist","butcher","bakery","tailor","jeweler",
            "harbor","fishing","warehouse",
            "house_1","house_2","noble_estate","oasis",
        },
    },
    -- -----------------------------------------------------------------------
    kingshold = {
        displayName = "Helios' Gate",
        themeOverride = "plains",
        sizeOverride = "mega_city",  -- Mega city - the largest in the game (60-100 buildings)
        extraBuildings = {
            {id="palatine_citadel", name="The Palatine Citadel", icon="CROWN",  action="building_interior", color={0.85,0.75,0.45}, desc="Seat of Lord Governor Aldren", category="landmark"},
            {id="grand_cathedral",  name="Grand Cathedral of Dawn",icon="CATH", action="building_interior", color={0.90,0.85,0.60}, desc="Massive cathedral of light",    category="landmark"},
            {id="war_academy",      name="War Academy",          icon="SWORD",  action="building_interior", color={0.55,0.45,0.35}, desc="Finest military training",      category="landmark"},
            {id="great_library",    name="The Great Library",    icon="BOOK",   action="building_interior", color={0.50,0.48,0.55}, desc="Repository of imperial knowledge", category="landmark"},
            {id="merchant_quarter", name="Merchant Quarter",     icon="GOLD",   action="building_interior", color={0.70,0.60,0.35}, desc="Bustling trade district",        category="landmark"},
            {id="noble_quarter",    name="Noble Quarter",        icon="HOME",   action="building_interior", color={0.60,0.55,0.65}, desc="Aristocratic residences",        category="landmark"},
            {id="imperial_gardens", name="Imperial Gardens",     icon="TREE",   action="building_interior", color={0.35,0.55,0.30}, desc="Manicured palatine gardens",    category="landmark"},
            {id="high_court",       name="The High Court",       icon="LAW",    action="building_interior", color={0.65,0.60,0.50}, desc="Imperial justice chambers",     category="landmark"},
            {id="herald_tower",     name="Herald's Tower",       icon="HORN",   action="building_interior", color={0.55,0.52,0.48}, desc="Imperial announcements & news", category="landmark"},
        },
        forceBuildings = {
            "townhall","market","tavern","shop","forge","stable","guild",
            "chapel","cathedral","library","alchemist","wizardtower",
            "butcher","bakery","tailor","jeweler",
            "barracks","theater","arena","observatory",
            "noble_estate","manor","warehouse","fishing","hunting",
            "house_1","house_2","house_3","farmhouse","well",
            "harbor","graveyard",
            -- Districts (mega city)
            "market_district","noble_quarter","slums","temple_district",
            "artisan_quarter","military_quarter","scholars_row",
            "entertainment_dist","foreign_quarter","harbor_district",
            -- Guild halls
            "fighters_guild_hall","mages_guild_hall","merchants_guild_hall",
            "thieves_guild_hall","assassins_den",
            -- Underbelly
            "sewer_entrance","catacomb_entrance","smuggler_tunnel",
            -- City infrastructure
            "city_jail","bounty_board","courier_office",
        },
    },
    -- -----------------------------------------------------------------------
    crossroads = {
        displayName = "Valdris Crossing",
        themeOverride = "plains",
        sizeOverride = "mega_city",
        extraBuildings = {
            {id="grand_exchange",    name="The Grand Exchange",    icon="TRADE", action="building_interior", color={0.75,0.65,0.35}, desc="Largest trade hall in the world",  category="landmark"},
            {id="valdris_colosseum", name="Valdris Colosseum",     icon="ARENA", action="building_interior", color={0.60,0.45,0.30}, desc="Blood sport and glory",            category="landmark"},
            {id="tower_of_tongues",  name="Tower of Tongues",      icon="TOWER", action="building_interior", color={0.50,0.55,0.60}, desc="Diplomats and translators",        category="landmark"},
            {id="the_undermarket",   name="The Undermarket",       icon="DARK",  action="building_interior", color={0.30,0.28,0.25}, desc="Largest black market",             category="landmark"},
            {id="crossroads_cathedral",name="Crossroads Cathedral",icon="CATH",  action="building_interior", color={0.80,0.78,0.60}, desc="Multi-faith worship",              category="landmark"},
            {id="guild_row",         name="Guild Row",             icon="GUILD", action="building_interior", color={0.55,0.48,0.42}, desc="Every guild has a presence",        category="landmark"},
        },
        forceBuildings = {
            "townhall","market","tavern","shop","forge","stable","guild",
            "chapel","cathedral","library","alchemist","wizardtower",
            "butcher","bakery","tailor","jeweler",
            "barracks","theater","arena","observatory",
            "noble_estate","manor","warehouse","fishing","hunting",
            "house_1","house_2","house_3","farmhouse","well",
            "harbor","graveyard",
            "market_district","noble_quarter","slums","temple_district",
            "artisan_quarter","military_quarter","scholars_row",
            "entertainment_dist","foreign_quarter","harbor_district",
            "fighters_guild_hall","mages_guild_hall","merchants_guild_hall",
            "thieves_guild_hall","assassins_den",
            "sewer_entrance","catacomb_entrance","smuggler_tunnel",
            "city_jail","bounty_board","courier_office",
        },
    },
    -- -----------------------------------------------------------------------
    aelindor = {
        displayName = "Aelindor, the Eternal City",
        themeOverride = "forest",
        sizeOverride = "mega_city",
        extraBuildings = {
            {id="living_spire",      name="The Living Spire",      icon="TREE",  action="building_interior", color={0.30,0.55,0.25}, desc="Ancient tree tower (pre-war)",     category="landmark"},
            {id="reflecting_pool",   name="The Reflecting Pool",   icon="WATER", action="building_interior", color={0.35,0.50,0.70}, desc="Natural pool under Inquest watch",  category="landmark"},
            {id="moonlit_gardens",   name="Moonlit Gardens",       icon="MOON",  action="building_interior", color={0.40,0.55,0.45}, desc="Bioluminescent plant gardens",     category="landmark"},
            {id="great_archive",     name="The Great Archive",     icon="BOOK",  action="building_interior", color={0.50,0.48,0.55}, desc="Imperial records repository",      category="landmark"},
            {id="starfall_obs",      name="Starfall Observatory",  icon="STAR",  action="building_interior", color={0.35,0.38,0.60}, desc="Astronomical research center",     category="landmark"},
            {id="memorial_grove",    name="Memorial Grove",        icon="LEAF",  action="building_interior", color={0.25,0.50,0.30}, desc="Monument to lost Calidar",         category="landmark"},
        },
        forceBuildings = {
            "townhall","market","tavern","shop","forge","stable","guild",
            "chapel","cathedral","library","alchemist","wizardtower",
            "butcher","bakery","tailor","jeweler",
            "barracks","theater","observatory",
            "noble_estate","manor","warehouse","fishing","hunting",
            "house_1","house_2","house_3","well",
            "graveyard",
            "market_district","noble_quarter","slums","temple_district",
            "artisan_quarter","scholars_row",
            "fighters_guild_hall","mages_guild_hall","merchants_guild_hall",
            "thieves_guild_hall",
            "sewer_entrance","catacomb_entrance",
            "city_jail","bounty_board","courier_office",
        },
    },
    -- -----------------------------------------------------------------------
    ironshore = {
        displayName = "Ironshore",
        themeOverride = "coastal",
        sizeOverride = "small",  -- Small harbour town (8-12 buildings)
        extraBuildings = {
            {id="rusty_anchor",     name="The Rusty Anchor",     icon="BEER", action="tavern_interior",   color={0.55,0.45,0.30}, desc="Dockside tavern and safehouse", category="landmark"},
            {id="western_cove",     name="Western Cove",         icon="WAVE", action="building_interior", color={0.35,0.45,0.55}, desc="Hidden smugglers' cove",        category="landmark"},
            {id="ironshore_docks",  name="Ironshore Docks",      icon="DOCK", action="building_interior", color={0.40,0.42,0.48}, desc="Fishing and trade docks",       category="landmark"},
        },
        forceBuildings = {
            "townhall","market","tavern","shop","stable",
            "harbor","fishing","warehouse","butcher",
            "house_1","house_2","well",
        },
    },
    -- -----------------------------------------------------------------------
    ironshore_prison = {
        displayName = "The Sunken Ledger",
        themeOverride = "coastal",
        sizeOverride = "medium_fortress",  -- Medium fortified prison (15-25 buildings)
        extraBuildings = {
            {id="the_bastille",     name="The Bastille",         icon="LOCK",   action="building_interior", color={0.38,0.38,0.42}, desc="Main prison block",             category="landmark"},
            {id="wardens_tower",    name="Warden's Tower",       icon="TOWER",  action="building_interior", color={0.42,0.40,0.45}, desc="Warden Blackthorn's domain",    category="landmark"},
            {id="gallows_yard",     name="Gallows Yard",         icon="DARK",   action="building_interior", color={0.35,0.32,0.30}, desc="Where sentences are carried out",category="landmark"},
            {id="prisoner_docks",   name="Prisoner Docks",       icon="DOCK",   action="building_interior", color={0.40,0.42,0.48}, desc="Ships bring the condemned",      category="landmark"},
            {id="fortress_walls",   name="Fortress Walls",       icon="WALL",   action="building_interior", color={0.45,0.43,0.42}, desc="Imposing gray stone ramparts",   category="landmark"},
            {id="guard_barracks",   name="Guard Barracks",       icon="ARMY",   action="building_interior", color={0.48,0.42,0.38}, desc="Housing for prison guards",      category="landmark"},
            {id="prison_infirmary", name="Prison Infirmary",     icon="HEAL",   action="building_interior", color={0.50,0.50,0.48}, desc="Tending to the broken",          category="landmark"},
            {id="solitary_block",   name="Solitary Block",       icon="CAGE",   action="building_interior", color={0.30,0.28,0.32}, desc="The hole—worst punishment",      category="landmark"},
            {id="interrogation_chamber",name="Interrogation Chamber",icon="EYE",action="building_interior", color={0.35,0.30,0.35}, desc="Where truth is extracted",       category="landmark"},
        },
        forceBuildings = {
            "townhall","market","tavern","shop","forge","stable",
            "chapel","barracks","harbor","warehouse",
            "house_1","house_2","well",
        },
    },
}

--- Generate buildings for an anchor city using its preset.
-- @param anchorId  string matching a key in ANCHOR_PRESETS
-- @param seed      number for deterministic generation
-- @return townBuildingData or nil if no preset found
function TownGen.generateAnchorBuildings(anchorId, seed)
    local preset = ANCHOR_PRESETS[anchorId]
    if not preset then return nil end

    seed = seed or os.time()
    local rng = SeededRandom.new(seed)

    -- Start with forced buildings
    local buildings = {}
    local added = {}

    local function addDef(bid)
        if added[bid] then return end
        local def = BUILDING_DEFS[bid]
        if not def then return end
        added[bid] = true
        local b = {}
        for k, v in pairs(def) do b[k] = v end
        table.insert(buildings, b)
    end

    -- Core always first
    for _, bid in ipairs(CORE_BUILDING_IDS) do
        addDef(bid)
    end

    -- Forced buildings from preset
    if preset.forceBuildings then
        for _, bid in ipairs(preset.forceBuildings) do
            addDef(bid)
        end
    end

    -- Extra unique landmark buildings
    if preset.extraBuildings then
        for _, extraDef in ipairs(preset.extraBuildings) do
            if not added[extraDef.id] then
                added[extraDef.id] = true
                local b = {}
                for k, v in pairs(extraDef) do b[k] = v end
                table.insert(buildings, b)
            end
        end
    end

    -- Determine target size based on preset's sizeOverride
    local minSize
    if preset.sizeOverride == "small" then
        minSize = 10   -- Small village: 8-12 buildings (forced + extras handle the rest)
    elseif preset.sizeOverride == "medium_fortress" then
        minSize = 20   -- Medium fortress: 15-25 buildings
    elseif preset.sizeOverride == "large_capital" then
        minSize = 40   -- Large capital: 35-50 buildings
    elseif preset.sizeOverride == "mega_city" then
        minSize = 70   -- Mega city: 60-100 buildings, the largest in the game
    else
        minSize = BUILDING_COUNT_RANGES.anchor.min  -- Default anchor size (30)
    end

    -- Pad with filler houses to reach target size
    local fillerIdx = 0
    local houseColors = {
        {0.42,0.40,0.36},{0.48,0.44,0.38},{0.44,0.42,0.40},
        {0.46,0.43,0.37},{0.40,0.38,0.35},{0.50,0.46,0.40},
    }
    while #buildings < minSize do
        fillerIdx = fillerIdx + 1
        local c = houseColors[((fillerIdx - 1) % #houseColors) + 1]
        table.insert(buildings, {
            id = "anchor_house_" .. fillerIdx,
            name = "House",
            icon = "HUT",
            action = "property",
            color = {c[1], c[2], c[3]},
            desc = "Residential house",
            category = "common",
            purchasable = true,
            propertyType = "home",
        })
    end

    -- Apply region theme color adjustments
    local theme = preset.themeOverride and REGIONAL_THEMES[preset.themeOverride]
    if theme and theme.buildingColors then
        -- Tint filler houses with regional palette
        for _, b in ipairs(buildings) do
            if b.id and b.id:find("anchor_house_") then
                local tc = theme.buildingColors[rng:random(1, #theme.buildingColors)]
                b.color = {tc[1], tc[2], tc[3]}
            end
        end
    end

    -- Gate always last
    local gateDef = BUILDING_DEFS["gate"]
    if gateDef and not added["gate"] then
        local g = {}
        for k, v in pairs(gateDef) do g[k] = v end
        table.insert(buildings, g)
    end

    -- Assign grid positions
    return assignBuildingGridPositions(buildings)
end

-- Expose building definitions for external use
TownGen.BUILDING_DEFS = BUILDING_DEFS
TownGen.ANCHOR_PRESETS = ANCHOR_PRESETS

-- ============================================================================
--                    DISTRICT SYSTEM
-- ============================================================================
-- Districts are sub-areas within capital/mega cities. Each district has
-- its own set of buildings, NPCs, atmosphere, and encounter types.

local DISTRICT_DEFINITIONS = {
    market = {
        id = "market",
        name = "Market District",
        description = "A sprawling bazaar of merchants, hawkers, and traders. The air is thick with the scent of spices and the sound of haggling.",
        atmosphere = "bustling",
        dangerLevel = 1,
        buildings = {"shop", "butcher", "bakery", "tailor", "jeweler", "warehouse", "market", "courier_office"},
        npcs = {"merchant", "craftsman", "traveler", "guard"},
        encounters = {"pickpocket", "merchant_deal", "rare_goods", "trade_dispute"},
        lootTable = {"gold", "trade_goods", "gems"},
    },
    noble = {
        id = "noble",
        name = "Noble Quarter",
        description = "Grand manors and manicured gardens line cobblestone avenues. Guards patrol regularly and commoners are watched with suspicion.",
        atmosphere = "refined",
        dangerLevel = 0,
        buildings = {"noble_estate", "manor", "chapel", "library", "theater", "cathedral"},
        npcs = {"noble", "guard", "scholar", "entertainer"},
        encounters = {"noble_quest", "political_intrigue", "high_society_event", "guard_patrol"},
        lootTable = {"jewelry", "fine_clothes", "documents"},
    },
    slums = {
        id = "slums",
        name = "The Slums",
        description = "Crumbling tenements and dark alleys where the desperate scrape by. The watch rarely ventures here. Opportunity and danger in equal measure.",
        atmosphere = "dangerous",
        dangerLevel = 4,
        buildings = {"shack", "tavern", "thieves_guild_hall", "well"},
        npcs = {"commoner", "thief", "beggar", "fence", "informant"},
        encounters = {"mugging", "fence_deal", "underground_fight", "desperate_plea", "hidden_entrance"},
        lootTable = {"stolen_goods", "lockpicks", "poison", "contraband"},
    },
    temple = {
        id = "temple",
        name = "Temple District",
        description = "Sacred ground where bells toll at dawn and incense fills the air. Pilgrims and priests walk among ancient shrines.",
        atmosphere = "serene",
        dangerLevel = 0,
        buildings = {"cathedral", "chapel", "library", "graveyard"},
        npcs = {"priest", "healer", "pilgrim", "monk"},
        encounters = {"blessing", "exorcism_quest", "holy_relic", "undead_sighting"},
        lootTable = {"holy_water", "scrolls", "prayer_beads", "relics"},
    },
    harbor = {
        id = "harbor",
        name = "Harbor District",
        description = "Salt-crusted docks where ships from distant lands tie up. Sailors, smugglers, and fishmongers crowd the waterfront.",
        atmosphere = "rough",
        dangerLevel = 2,
        buildings = {"harbor", "fishing", "warehouse", "tavern", "shop"},
        npcs = {"sailor", "fishmonger", "smuggler", "dockworker", "merchant"},
        encounters = {"smuggler_offer", "bar_brawl", "ship_arrival", "stowaway", "sea_rumors"},
        lootTable = {"fish", "exotic_goods", "maps", "rum"},
    },
    artisan = {
        id = "artisan",
        name = "Artisan Quarter",
        description = "The rhythmic clang of hammers and the glow of forges. Master craftsmen ply their trades in workshops passed down for generations.",
        atmosphere = "industrious",
        dangerLevel = 1,
        buildings = {"forge", "alchemist", "wizardtower", "stable", "lumber_mill"},
        npcs = {"blacksmith", "craftsman", "alchemist", "enchanter"},
        encounters = {"apprentice_quest", "rare_material", "forge_challenge", "enchantment_offer"},
        lootTable = {"raw_materials", "crafted_goods", "enchanted_items"},
    },
    military = {
        id = "military",
        name = "Military Quarter",
        description = "Disciplined rows of barracks, training yards, and armories. Soldiers drill relentlessly under watchful officers.",
        atmosphere = "disciplined",
        dangerLevel = 1,
        buildings = {"barracks", "arena", "forge", "stable"},
        npcs = {"guard", "soldier", "officer", "weaponmaster"},
        encounters = {"training_challenge", "recruitment", "patrol_duty", "military_intel"},
        lootTable = {"weapons", "armor", "military_supplies"},
    },
    scholars = {
        id = "scholars",
        name = "Scholar's Row",
        description = "Quiet streets lined with bookshops, lecture halls, and dimly lit studies. Knowledge seekers from across the realm gather here.",
        atmosphere = "intellectual",
        dangerLevel = 0,
        buildings = {"library", "wizardtower", "observatory", "chapel"},
        npcs = {"scholar", "mage", "archivist", "student"},
        encounters = {"research_quest", "lost_tome", "magical_anomaly", "lecture_series"},
        lootTable = {"books", "scrolls", "rare_ingredients", "maps"},
    },
    entertainment = {
        id = "entertainment",
        name = "Entertainment District",
        description = "Music, laughter, and the clink of tankards fill the night air. Theaters, taverns, and less reputable establishments line the streets.",
        atmosphere = "lively",
        dangerLevel = 2,
        buildings = {"theater", "tavern", "arena", "house_1"},
        npcs = {"entertainer", "bard", "gambler", "courtesan", "bouncer"},
        encounters = {"bar_game", "performance_quest", "gambling_opportunity", "rumor_mill"},
        lootTable = {"trinkets", "lucky_charms", "costumes", "instruments"},
    },
    foreign = {
        id = "foreign",
        name = "Foreign Quarter",
        description = "A melting pot of cultures, languages, and traditions. Exotic spices, unfamiliar music, and curious customs await around every corner.",
        atmosphere = "exotic",
        dangerLevel = 2,
        buildings = {"shop", "tavern", "chapel", "warehouse"},
        npcs = {"traveler", "merchant", "diplomat", "refugee", "spy"},
        encounters = {"cultural_exchange", "smuggling_ring", "diplomatic_mission", "exotic_goods"},
        lootTable = {"exotic_goods", "foreign_currency", "rare_spices", "unusual_weapons"},
    },
}

TownGen.DISTRICT_DEFINITIONS = DISTRICT_DEFINITIONS

-- Get districts for a city based on its size and type
function TownGen.getDistrictsForCity(population, cityType, anchorId)
    local size = getSizeCategory(population or 0)
    local districts = {}

    -- All capitals and mega cities get core districts
    if size == "capital" or size == "mega" or cityType == "capital" then
        table.insert(districts, DISTRICT_DEFINITIONS.market)
        table.insert(districts, DISTRICT_DEFINITIONS.noble)
        table.insert(districts, DISTRICT_DEFINITIONS.slums)
    end

    -- Mega cities and anchor capitals get more districts
    if size == "mega" or (anchorId and (cityType == "capital" or population >= 400)) then
        table.insert(districts, DISTRICT_DEFINITIONS.temple)
        table.insert(districts, DISTRICT_DEFINITIONS.artisan)
        table.insert(districts, DISTRICT_DEFINITIONS.military)
        table.insert(districts, DISTRICT_DEFINITIONS.scholars)
    end

    -- Only the biggest cities get these
    if size == "mega" or population >= 800 then
        table.insert(districts, DISTRICT_DEFINITIONS.entertainment)
        table.insert(districts, DISTRICT_DEFINITIONS.harbor)
        table.insert(districts, DISTRICT_DEFINITIONS.foreign)
    end

    return districts
end

-- ============================================================================
--                    UNDERBELLY SYSTEM
-- ============================================================================
-- Underground areas beneath cities: sewers, catacombs, and smuggler tunnels.
-- Each has its own encounter tables, enemy types, and rewards.

local UNDERBELLY_TYPES = {
    sewers = {
        id = "sewers",
        name = "City Sewers",
        description = "Dank tunnels running beneath the city streets. Water drips from arched stone ceilings and rats skitter in the shadows. The desperate and the dangerous make their homes here.",
        atmosphere = "oppressive",
        dangerLevel = 3,
        floors = {min = 2, max = 4},
        enemies = {
            {name = "Giant Rat", hp = 15, attack = 4, xp = 8, gold = 2},
            {name = "Sewer Slime", hp = 25, attack = 6, xp = 15, gold = 5},
            {name = "Ratfolk Thief", hp = 30, attack = 8, xp = 20, gold = 12},
            {name = "Sewer Gator", hp = 45, attack = 12, xp = 30, gold = 8},
            {name = "Plague Zombie", hp = 35, attack = 10, xp = 25, gold = 5},
        },
        bosses = {
            {name = "Rat King", hp = 120, attack = 18, xp = 100, gold = 75, drops = {"Plague Amulet", "Sewer Map"}},
            {name = "Sewer Abomination", hp = 180, attack = 22, xp = 150, gold = 100, drops = {"Toxic Core", "Rusted Crown"}},
        },
        loot = {"Sewer Key", "Stolen Goods", "Rat Poison", "Underground Map", "Smuggler's Stash", "Ancient Coin"},
        encounters = {
            "You hear splashing in the darkness ahead...",
            "A foul stench warns you of something nearby.",
            "Glowing eyes watch you from a drain pipe.",
            "You find a makeshift camp, recently abandoned.",
            "The walls here are covered in strange scratches.",
            "A locked gate blocks a side passage. Something glints beyond it.",
        },
        discoveryChance = 0.8,  -- Most cities have sewers
    },
    catacombs = {
        id = "catacombs",
        name = "Ancient Catacombs",
        description = "Burial tunnels from an age long past. Stone sarcophagi line the walls and the air is cold and still. The dead do not always rest peacefully here.",
        atmosphere = "haunted",
        dangerLevel = 5,
        floors = {min = 3, max = 6},
        enemies = {
            {name = "Skeleton Warrior", hp = 30, attack = 10, xp = 20, gold = 8},
            {name = "Restless Spirit", hp = 25, attack = 12, xp = 25, gold = 0},
            {name = "Tomb Guardian", hp = 50, attack = 15, xp = 35, gold = 15},
            {name = "Wraith", hp = 40, attack = 18, xp = 40, gold = 0},
            {name = "Necromancer Acolyte", hp = 35, attack = 14, xp = 45, gold = 25},
        },
        bosses = {
            {name = "Crypt Lord", hp = 200, attack = 25, xp = 200, gold = 150, drops = {"Crypt Lord's Phylactery", "Death Shroud"}},
            {name = "Ancient Revenant", hp = 250, attack = 30, xp = 250, gold = 200, drops = {"Revenant's Blade", "Soul Gem"}},
        },
        loot = {"Ancient Relic", "Burial Gold", "Bone Charm", "Necromantic Scroll", "Tomb Key", "Ancestral Blade"},
        encounters = {
            "Cold whispers echo from deep within the tunnels...",
            "A sarcophagus lid shifts slightly as you pass.",
            "You feel an icy hand brush your shoulder, but nothing is there.",
            "Ancient runes on the walls pulse with faint light.",
            "The bones scattered on the floor begin to rattle.",
            "A spectral figure points down a corridor, then vanishes.",
        },
        discoveryChance = 0.5,  -- Not all cities sit atop catacombs
    },
    tunnels = {
        id = "tunnels",
        name = "Smuggler's Tunnels",
        description = "A network of hidden passages used by the criminal underworld. Secret doors, hidden caches, and dangerous denizens lurk in the dark.",
        atmosphere = "secretive",
        dangerLevel = 4,
        floors = {min = 1, max = 3},
        enemies = {
            {name = "Smuggler Thug", hp = 25, attack = 9, xp = 15, gold = 20},
            {name = "Tunnel Rat", hp = 15, attack = 5, xp = 8, gold = 5},
            {name = "Dark Dealer", hp = 30, attack = 11, xp = 22, gold = 30},
            {name = "Hired Assassin", hp = 40, attack = 16, xp = 35, gold = 25},
            {name = "Tunnel Crawler", hp = 35, attack = 13, xp = 28, gold = 10},
        },
        bosses = {
            {name = "Smuggler King", hp = 150, attack = 20, xp = 150, gold = 200, drops = {"Smuggler King's Ledger", "Master Key"}},
            {name = "Shadow Broker", hp = 180, attack = 24, xp = 175, gold = 250, drops = {"Shadow Cloak", "Blackmail Documents"}},
        },
        loot = {"Contraband", "Lockpicks", "Secret Map", "Stolen Jewels", "Forged Documents", "Poison Vial"},
        encounters = {
            "A hidden door slides open, revealing a storeroom of illicit goods.",
            "You overhear voices negotiating a deal in the dark.",
            "Trip wires cross the passage ahead. A trap for the unwary.",
            "A coded message is scratched into the wall.",
            "The tunnel opens into a hidden underground market.",
            "Boot prints in the dust. Someone else has been through recently.",
        },
        discoveryChance = 0.4,  -- Only cities with criminal elements
    },
}

TownGen.UNDERBELLY_TYPES = UNDERBELLY_TYPES

-- Determine which underbelly areas a city has
function TownGen.getUnderbellyForCity(population, cityType, anchorId, seed)
    local rng = SeededRandom.new(seed or os.time())
    local underbellies = {}

    local size = getSizeCategory(population or 0)

    -- Sewers: most cities have them
    if (size == "large" or size == "capital" or size == "mega" or cityType == "capital") and rng:chance(UNDERBELLY_TYPES.sewers.discoveryChance) then
        local floors = rng:random(UNDERBELLY_TYPES.sewers.floors.min, UNDERBELLY_TYPES.sewers.floors.max)
        table.insert(underbellies, {type = UNDERBELLY_TYPES.sewers, floors = floors, explored = false, bossDefeated = false})
    end

    -- Catacombs: older, larger cities
    if (size == "capital" or size == "mega" or anchorId) and rng:chance(UNDERBELLY_TYPES.catacombs.discoveryChance) then
        local floors = rng:random(UNDERBELLY_TYPES.catacombs.floors.min, UNDERBELLY_TYPES.catacombs.floors.max)
        table.insert(underbellies, {type = UNDERBELLY_TYPES.catacombs, floors = floors, explored = false, bossDefeated = false})
    end

    -- Smuggler tunnels: cities with criminal elements
    if (size == "large" or size == "capital" or size == "mega") and rng:chance(UNDERBELLY_TYPES.tunnels.discoveryChance) then
        local floors = rng:random(UNDERBELLY_TYPES.tunnels.floors.min, UNDERBELLY_TYPES.tunnels.floors.max)
        table.insert(underbellies, {type = UNDERBELLY_TYPES.tunnels, floors = floors, explored = false, bossDefeated = false})
    end

    return underbellies
end

-- ============================================================================
--                    GUILD DATA SYSTEM
-- ============================================================================
-- Detailed guild definitions with ranks, quests, and benefits

local GUILD_DATA = {
    fighters_guild = {
        id = "fighters_guild",
        name = "The Steel Brotherhood",
        description = "Warriors, mercenaries, and monster hunters united under a common banner. They take contracts for combat, protection, and bounty hunting.",
        motto = "Steel answers all questions.",
        ranks = {
            {name = "Recruit",     minRep = 0,   benefits = {combatXPBonus = 0.05}},
            {name = "Swordarm",    minRep = 25,  benefits = {combatXPBonus = 0.10, shopDiscount = 0.05}},
            {name = "Veteran",     minRep = 50,  benefits = {combatXPBonus = 0.15, shopDiscount = 0.10, critBonus = 0.05}},
            {name = "Champion",    minRep = 75,  benefits = {combatXPBonus = 0.20, shopDiscount = 0.15, critBonus = 0.10}},
            {name = "Guildmaster", minRep = 100, benefits = {combatXPBonus = 0.25, shopDiscount = 0.20, critBonus = 0.15}},
        },
        joinRequirements = {minLevel = 3, minKarma = -20},
        questTypes = {"bounty", "monster_hunt", "arena_challenge", "escort", "clear_dungeon"},
        color = {0.60, 0.40, 0.30},
    },
    mages_guild = {
        id = "mages_guild",
        name = "The Sanctioned Arcanum",
        description = "State-authorized practitioners of controlled magic under Dominion oversight. Licensed by imperial decree, they study arcane phenomena within strict legal boundaries. All members carry imperial sanction papers and operate under Luminary Inquest supervision.",
        motto = "Knowledge serves the light.",
        ranks = {
            {name = "Licensed Initiate", minRep = 0,   benefits = {spellDamageBonus = 0.05}},
            {name = "Sanctioned Adept",  minRep = 25,  benefits = {spellDamageBonus = 0.10, manaRegenBonus = 1}},
            {name = "Authorized Mage",   minRep = 50,  benefits = {spellDamageBonus = 0.15, manaRegenBonus = 2, shopDiscount = 0.10}},
            {name = "Imperial Magister", minRep = 75,  benefits = {spellDamageBonus = 0.20, manaRegenBonus = 3, shopDiscount = 0.15}},
            {name = "Grand Licensor",    minRep = 100, benefits = {spellDamageBonus = 0.25, manaRegenBonus = 5, shopDiscount = 0.20}},
        },
        joinRequirements = {minLevel = 2, minKarma = 0},
        questTypes = {"research", "artifact_retrieval", "magical_anomaly", "controlled_experiment", "inquest_cooperation"},
        color = {0.40, 0.35, 0.70},
    },
    thieves_guild = {
        id = "thieves_guild",
        name = "The Shadow Network",
        description = "A web of thieves, pickpockets, informants, and burglars operating in the margins of society. They steal, spy, and profit from what others overlook.",
        motto = "What you don't see, we already took.",
        ranks = {
            {name = "Footpad",     minRep = 0,   benefits = {stealthBonus = 0.05, lockpickBonus = 0.10}},
            {name = "Prowler",     minRep = 25,  benefits = {stealthBonus = 0.10, lockpickBonus = 0.20, fenceDiscount = 0.10}},
            {name = "Shadowfoot",  minRep = 50,  benefits = {stealthBonus = 0.15, lockpickBonus = 0.30, fenceDiscount = 0.20}},
            {name = "Nightblade",  minRep = 75,  benefits = {stealthBonus = 0.20, lockpickBonus = 0.40, fenceDiscount = 0.30}},
            {name = "Shadowmaster",minRep = 100, benefits = {stealthBonus = 0.25, lockpickBonus = 0.50, fenceDiscount = 0.40}},
        },
        joinRequirements = {maxKarma = 10},
        questTypes = {"heist", "pickpocket_mission", "spy_mission", "smuggle", "blackmail"},
        color = {0.25, 0.22, 0.30},
    },
    merchants_guild = {
        id = "merchants_guild",
        name = "The Golden Ledger",
        description = "A consortium of traders, financiers, and merchants who control the flow of commerce across the realm. Wealth is their weapon.",
        motto = "Every coin tells a story. Ours is the longest.",
        ranks = {
            {name = "Associate",   minRep = 0,   benefits = {shopDiscount = 0.05, sellBonus = 0.05}},
            {name = "Trader",      minRep = 25,  benefits = {shopDiscount = 0.10, sellBonus = 0.10}},
            {name = "Merchant",    minRep = 50,  benefits = {shopDiscount = 0.15, sellBonus = 0.15, tradeBonusGold = 50}},
            {name = "Factor",      minRep = 75,  benefits = {shopDiscount = 0.20, sellBonus = 0.20, tradeBonusGold = 100}},
            {name = "Guildmaster", minRep = 100, benefits = {shopDiscount = 0.25, sellBonus = 0.25, tradeBonusGold = 200}},
        },
        joinRequirements = {minGold = 200, minKarma = -10},
        questTypes = {"courier", "trade_route", "collect_debt", "negotiate", "supply_run"},
        color = {0.70, 0.60, 0.35},
    },
    assassins_guild = {
        id = "assassins_guild",
        name = "The Silent Ledger",
        description = "Elite killers who operate beyond law and morality. Their contracts are whispered in dark corners and paid for in blood. Every death is recorded in their hidden ledger.",
        ranks = {
            {name = "Blade",        minRep = 0,   benefits = {critDamageBonus = 0.10, poisonBonus = 0.10}},
            {name = "Silencer",     minRep = 25,  benefits = {critDamageBonus = 0.15, poisonBonus = 0.20, stealthBonus = 0.10}},
            {name = "Phantom",      minRep = 50,  benefits = {critDamageBonus = 0.20, poisonBonus = 0.30, stealthBonus = 0.15}},
            {name = "Deathdealer",  minRep = 75,  benefits = {critDamageBonus = 0.25, poisonBonus = 0.40, stealthBonus = 0.20}},
            {name = "Grandmaster",  minRep = 100, benefits = {critDamageBonus = 0.30, poisonBonus = 0.50, stealthBonus = 0.25}},
        },
        joinRequirements = {maxKarma = -25, minLevel = 8},
        questTypes = {"assassination", "poison_target", "intimidation", "sabotage", "elimination"},
        color = {0.20, 0.18, 0.25},
    },
}

TownGen.GUILD_DATA = GUILD_DATA

return TownGen
