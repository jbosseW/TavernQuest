-- Tile Utilities Module
-- Shared tile classification, bounds checking, and neighbor helpers.
-- Eliminates duplicated helper functions across worldgen consumers.

local TileUtils = {}

-- ============================================================================
--                        DIRECTION OFFSET TABLES
-- ============================================================================

-- 4-directional (cardinal) neighbor offsets.
-- Shared constant so callers do not recreate this table on every use.
TileUtils.DIRS4 = {{1,0},{-1,0},{0,1},{0,-1}}

-- 8-directional neighbor offsets (cardinal + diagonal).
TileUtils.DIRS8 = {
    {1,0},{-1,0},{0,1},{0,-1},
    {1,1},{-1,-1},{1,-1},{-1,1},
}

-- ============================================================================
--                        NEIGHBOR COORDINATE HELPERS
-- ============================================================================

-- Return a table of {x, y} positions for the 4 cardinal neighbors of (x, y).
function TileUtils.getNeighbors4(x, y)
    return {
        {x = x + 1, y = y},
        {x = x - 1, y = y},
        {x = x, y = y + 1},
        {x = x, y = y - 1},
    }
end

-- Return a table of {x, y} positions for all 8 neighbors of (x, y).
function TileUtils.getNeighbors8(x, y)
    return {
        {x = x + 1, y = y},
        {x = x - 1, y = y},
        {x = x, y = y + 1},
        {x = x, y = y - 1},
        {x = x + 1, y = y + 1},
        {x = x - 1, y = y - 1},
        {x = x + 1, y = y - 1},
        {x = x - 1, y = y + 1},
    }
end

-- ============================================================================
--                          BOUNDS CHECKING
-- ============================================================================

-- Check if (x, y) is within a 1-based grid of the given width and height.
-- This is the pattern used by towngen, dungeon grids, tactical combat grids, etc.
function TileUtils.isGridInBounds(x, y, width, height)
    return x >= 1 and x <= width and y >= 1 and y <= height
end

-- ============================================================================
--                      WORLD-MAP TILE CLASSIFICATION
-- ============================================================================

-- Set of tile types that represent water or aquatic terrain.
-- Used by multiple systems (mapenemies, luminarypatrols, auto_travel) to
-- determine basic land/water passability on the overworld.
TileUtils.WATER_TILES = {
    water = true,
    deep_ocean = true,
    shallow_water = true,
    coastal = true,
    reef = true,
    river = true,
    lake = true,
    ice = true,
    whirlpool = true,
    shipwreck = true,
    ocean_cave = true,
}

-- Check whether a tile type string represents water/aquatic terrain.
function TileUtils.isWaterTile(tileType)
    return TileUtils.WATER_TILES[tileType] == true
end

-- General-purpose world-map passability check.
-- Returns true if the tile at (x, y) is land that can be walked on.
-- Requires WorldGen to be loaded. Callers that need mount/flight awareness
-- (e.g. auto_travel) should use their own extended check on top of this.
--
-- blockedSet (optional): a table of additional tile types to treat as blocked
--   e.g. {town = true} for enemy movement.
function TileUtils.isWorldTilePassable(x, y, blockedSet)
    local WorldGen = require("worldgen")
    local tile = WorldGen.getTile(x, y)
    if not tile then return false end
    if TileUtils.WATER_TILES[tile.type] then return false end
    if blockedSet and blockedSet[tile.type] then return false end
    return true
end

return TileUtils
