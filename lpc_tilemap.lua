-- LPC Tilemap Renderer
-- Renders dungeons/maps using LPC terrain assets
-- Integrates with TextRPG dungeon generation

local LPCTilemap = {}
local LPCLoader = require("lpcloader")

-- Tile definitions
LPCTilemap.TILES = {
    EMPTY = 0,
    FLOOR = 1,
    WALL = 2,
    DOOR_CLOSED = 3,
    DOOR_OPEN = 4,
    STAIRS_UP = 5,
    STAIRS_DOWN = 6,
    WATER = 7,
    GRASS = 8,
}

-- Initialize
function LPCTilemap.init()
    LPCTilemap.grid = {}
    LPCTilemap.width = 0
    LPCTilemap.height = 0
    LPCTilemap.tileSize = 32  -- LPC standard is 32x32

    -- Load terrain tileset
    LPCTilemap.terrainAtlas = LPCLoader.loadTerrainAtlas()

    -- Create tile quads (map tile types to atlas positions)
    LPCTilemap.tileQuads = {}

    if LPCTilemap.terrainAtlas then
        -- Grass tile (example: row 0, col 0)
        LPCTilemap.tileQuads[LPCTilemap.TILES.GRASS] = LPCLoader.getTileQuad(LPCTilemap.terrainAtlas, 0, 0, 32)

        -- Dirt/floor tile (example: row 1, col 0)
        LPCTilemap.tileQuads[LPCTilemap.TILES.FLOOR] = LPCLoader.getTileQuad(LPCTilemap.terrainAtlas, 1, 0, 32)

        -- Water tile (example: row 5, col 0)
        LPCTilemap.tileQuads[LPCTilemap.TILES.WATER] = LPCLoader.getTileQuad(LPCTilemap.terrainAtlas, 5, 0, 32)

        print("LPCTilemap: Terrain atlas loaded")
    else
        print("Warning: Terrain atlas not found, using colored rectangles")
    end

    print("LPCTilemap initialized")
end

-- Create grid from TextRPG dungeon floor
function LPCTilemap.fromDungeonFloor(floor)
    LPCTilemap.width = floor.width
    LPCTilemap.height = floor.height
    LPCTilemap.grid = {}

    for y = 1, floor.height do
        LPCTilemap.grid[y] = {}
        for x = 1, floor.width do
            local cell = floor.grid[y][x]

            -- Convert TextRPG cell types to tile IDs
            if cell.type == "wall" then
                LPCTilemap.grid[y][x] = LPCTilemap.TILES.WALL
            elseif cell.type == "floor" then
                LPCTilemap.grid[y][x] = LPCTilemap.TILES.FLOOR
            elseif cell.type == "door" then
                if cell.open then
                    LPCTilemap.grid[y][x] = LPCTilemap.TILES.DOOR_OPEN
                else
                    LPCTilemap.grid[y][x] = LPCTilemap.TILES.DOOR_CLOSED
                end
            elseif cell.type == "stairs_up" then
                LPCTilemap.grid[y][x] = LPCTilemap.TILES.STAIRS_UP
            elseif cell.type == "stairs_down" then
                LPCTilemap.grid[y][x] = LPCTilemap.TILES.STAIRS_DOWN
            else
                LPCTilemap.grid[y][x] = LPCTilemap.TILES.EMPTY
            end
        end
    end

    print("LPCTilemap: Converted " .. floor.width .. "x" .. floor.height .. " dungeon floor")
end

-- Create a simple grid (for testing)
function LPCTilemap.createSimple(width, height)
    LPCTilemap.width = width
    LPCTilemap.height = height
    LPCTilemap.grid = {}

    for y = 1, height do
        LPCTilemap.grid[y] = {}
        for x = 1, width do
            -- Border walls
            if x == 1 or x == width or y == 1 or y == height then
                LPCTilemap.grid[y][x] = LPCTilemap.TILES.WALL
            else
                LPCTilemap.grid[y][x] = LPCTilemap.TILES.FLOOR
            end
        end
    end
end

-- Get tile at position
function LPCTilemap.getTile(x, y)
    if y < 1 or y > LPCTilemap.height then return nil end
    if x < 1 or x > LPCTilemap.width then return nil end
    return LPCTilemap.grid[y][x]
end

-- Set tile at position
function LPCTilemap.setTile(x, y, tileType)
    if y < 1 or y > LPCTilemap.height then return end
    if x < 1 or x > LPCTilemap.width then return end
    LPCTilemap.grid[y][x] = tileType
end

-- Check if tile is solid (blocks movement)
function LPCTilemap.isSolid(x, y)
    local tile = LPCTilemap.getTile(x, y)
    if not tile then return true end  -- Out of bounds = solid

    return (tile == LPCTilemap.TILES.WALL or
            tile == LPCTilemap.TILES.DOOR_CLOSED or
            tile == LPCTilemap.TILES.WATER)
end

-- Draw tilemap (called within camera transform)
function LPCTilemap.draw(camX, camY)
    if not LPCTilemap.grid then return end

    camX = camX or 0
    camY = camY or 0

    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- Calculate visible tile range
    local startX = math.max(1, math.floor(camX / LPCTilemap.tileSize))
    local startY = math.max(1, math.floor(camY / LPCTilemap.tileSize))
    local endX = math.min(LPCTilemap.width, math.ceil((camX + screenW) / LPCTilemap.tileSize) + 1)
    local endY = math.min(LPCTilemap.height, math.ceil((camY + screenH) / LPCTilemap.tileSize) + 1)

    love.graphics.setColor(1, 1, 1)

    -- Draw visible tiles
    for y = startY, endY do
        for x = startX, endX do
            local tileType = LPCTilemap.grid[y][x]
            local worldX = (x - 1) * LPCTilemap.tileSize
            local worldY = (y - 1) * LPCTilemap.tileSize

            -- Draw with sprite if available, otherwise colored rectangle
            local quad = LPCTilemap.tileQuads[tileType]

            if quad and LPCTilemap.terrainAtlas then
                love.graphics.draw(LPCTilemap.terrainAtlas, quad, worldX, worldY)
            else
                -- Fallback: colored rectangles
                LPCTilemap.drawFallbackTile(tileType, worldX, worldY)
            end
        end
    end
end

-- Fallback rendering (colored rectangles)
function LPCTilemap.drawFallbackTile(tileType, x, y)
    if tileType == LPCTilemap.TILES.FLOOR then
        love.graphics.setColor(0.3, 0.3, 0.35)
    elseif tileType == LPCTilemap.TILES.WALL then
        love.graphics.setColor(0.5, 0.4, 0.35)
    elseif tileType == LPCTilemap.TILES.DOOR_CLOSED then
        love.graphics.setColor(0.6, 0.4, 0.2)
    elseif tileType == LPCTilemap.TILES.DOOR_OPEN then
        love.graphics.setColor(0.4, 0.3, 0.2)
    elseif tileType == LPCTilemap.TILES.WATER then
        love.graphics.setColor(0.2, 0.4, 0.6)
    elseif tileType == LPCTilemap.TILES.GRASS then
        love.graphics.setColor(0.3, 0.5, 0.3)
    else
        love.graphics.setColor(0.1, 0.1, 0.1)
    end

    love.graphics.rectangle("fill", x, y, LPCTilemap.tileSize, LPCTilemap.tileSize)

    -- Grid lines
    love.graphics.setColor(0.4, 0.4, 0.4)
    love.graphics.rectangle("line", x, y, LPCTilemap.tileSize, LPCTilemap.tileSize)

    love.graphics.setColor(1, 1, 1)
end

-- Convert world position to tile coordinates
function LPCTilemap.worldToTile(worldX, worldY)
    local tileX = math.floor(worldX / LPCTilemap.tileSize) + 1
    local tileY = math.floor(worldY / LPCTilemap.tileSize) + 1
    return tileX, tileY
end

-- Convert tile coordinates to world position (center of tile)
function LPCTilemap.tileToWorld(tileX, tileY)
    local worldX = (tileX - 1) * LPCTilemap.tileSize + LPCTilemap.tileSize / 2
    local worldY = (tileY - 1) * LPCTilemap.tileSize + LPCTilemap.tileSize / 2
    return worldX, worldY
end

return LPCTilemap
