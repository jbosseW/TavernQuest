-- ==========================================================================
-- Renderer2D - Central 2D Sprite Renderer for Tavern Quest
-- ==========================================================================
-- Rendering backbone that replaces colored rectangles with sprite-based
-- tile rendering. Coordinates SpriteBatches, layered draw order, camera
-- integration, and provides a feature flag to toggle between old "classic"
-- rendering and new "sprite" rendering.
--
-- PERFORMANCE NOTES:
--   SpriteBatch is THE key performance win here. Instead of issuing one
--   love.graphics.draw() call per tile (which means one GPU draw call per
--   tile), we batch all tiles that share the same atlas texture into a
--   single SpriteBatch. The GPU then renders the entire batch in ONE draw
--   call. For a 50x50 map, that turns 2500 draw calls into 1.
--
--   Frustum culling in drawTileGrid ensures we only add tiles that are
--   actually visible on screen to the batch, avoiding wasted GPU work on
--   off-screen geometry.
-- ==========================================================================

local LPCLoader = require("lpcloader")
local Camera2D = require("camera2d")

local Renderer2D = {}

-- ==========================================================================
--                       GLOBAL RENDER MODE FLAG
-- ==========================================================================
-- "sprite" = use atlas-based SpriteBatch rendering
-- "classic" = use colored rectangles (legacy fallback)
-- Set this global before calling Renderer2D.init() to change default mode.
-- Can be toggled at runtime by any module.
RENDER_MODE = RENDER_MODE or "sprite"

-- ==========================================================================
--                         INTERNAL STATE
-- ==========================================================================

-- Atlas images keyed by name
local atlases = {}

-- SpriteBatch instances keyed by atlas name
local batches = {}

-- Atlas configuration: name -> { path, width, height, tileSize }
-- These map to the LPC asset directory structure used by LPCLoader.
local ATLAS_CONFIG = {
    terrain = {
        path = "tilesets/terrain/terrain_atlas.png",
        atlasW = 1024, atlasH = 1024,
        tileSize = 32,
    },
    walls = {
        path = "tilesets/walls/lpc-walls/walls.png",
        atlasW = 2048, atlasH = 3072,
        tileSize = 32,
    },
    buildings_castle = {
        path = "tilesets/buildings/castle_tiles.png",
        atlasW = 512, atlasH = 512,
        tileSize = 32,
    },
    buildings_city = {
        path = "tilesets/buildings/magecity.png",
        atlasW = 256, atlasH = 1450,
        tileSize = 32,
    },
    town_objects = {
        path = "tilesets/town_objects/cobblestone_paths.png",
        atlasW = 512, atlasH = 512,
        tileSize = 32,
    },
    outdoor = {
        path = "tilesets/terrain/base_out_atlas.png",
        atlasW = 1024, atlasH = 1024,
        tileSize = 32,
    },
    worldmap = {
        path = "tilesets/worldmap/worldmap_tileset.png",
        atlasW = 256, atlasH = 336,
        tileSize = 16,
    },
    desert = {
        path = "tilesets/desert/desert_tileset.png",
        atlasW = 208, atlasH = 384,
        tileSize = 16,
    },
    vegetation = {
        path = "tilesets/vegetation/trees-and-bushes.png",
        atlasW = 288, atlasH = 160,
        tileSize = nil,  -- varies; no fixed tile grid
    },
}

-- SpriteBatch capacity per atlas. 2048 sprites is enough for a large
-- visible area (e.g. 64x32 tiles) while keeping memory usage reasonable.
local BATCH_CAPACITY = 2048

-- Whether init() has been called
local initialized = false

-- ==========================================================================
--                           INITIALIZATION
-- ==========================================================================

--- Load all configured atlases and create a SpriteBatch for each.
-- Safe to call multiple times; subsequent calls are no-ops.
function Renderer2D.init()
    if initialized then return end

    print("========================================")
    print("Renderer2D initializing...")
    print("  Render mode: " .. tostring(RENDER_MODE))
    print("========================================")

    -- Ensure LPCLoader is ready (sets nearest-neighbor filtering, etc.)
    LPCLoader.init()

    -- Load each atlas via LPCLoader (which prepends "assets/lpc/" and caches)
    for name, config in pairs(ATLAS_CONFIG) do
        local img = LPCLoader.loadImage(config.path)

        if img then
            atlases[name] = img

            -- Create a dynamic SpriteBatch for this atlas.
            -- "dynamic" usage hint tells the GPU the batch contents change
            -- every frame, which is true for us since we rebuild from the
            -- visible set each frame.
            batches[name] = love.graphics.newSpriteBatch(img, BATCH_CAPACITY, "dynamic")
            print("  Loaded atlas: " .. name .. " (" .. img:getWidth() .. "x" .. img:getHeight() .. ")")
        else
            print("  WARNING: Failed to load atlas '" .. name .. "' from " .. config.path)
            -- Leave atlases[name] and batches[name] as nil.
            -- All drawing functions check for nil and skip gracefully.
        end
    end

    initialized = true
    print("Renderer2D ready (" .. Renderer2D.atlasCount() .. " atlases loaded)")
end

--- Return the number of successfully loaded atlases.
function Renderer2D.atlasCount()
    local count = 0
    for _ in pairs(atlases) do
        count = count + 1
    end
    return count
end

-- ==========================================================================
--                         RENDER MODE QUERY
-- ==========================================================================

--- Returns true if the current render mode is "sprite".
-- Modules should check this to decide whether to draw sprites or
-- colored rectangles.
function Renderer2D.isSprite()
    return RENDER_MODE == "sprite"
end

-- ==========================================================================
--                       FRAME LIFECYCLE
-- ==========================================================================

--- Clear all SpriteBatches at the start of a frame.
-- Call this once at the top of love.draw() before any tile rendering.
function Renderer2D.beginFrame()
    for _, batch in pairs(batches) do
        batch:clear()
    end
end

--- End-of-frame hook. Currently a no-op because batches are drawn
-- immediately when drawTileGrid or flush is called, but this exists
-- as a consistent API point for future use (e.g. deferred rendering,
-- layer sorting).
function Renderer2D.endFrame()
    -- Intentionally empty. Batches are drawn via drawTileGrid / flush.
end

-- ==========================================================================
--                     TILE GRID RENDERING (BATCHED)
-- ==========================================================================

--- Render a 2D tile grid using SpriteBatch for maximum performance.
--
-- This is the primary rendering function for maps, dungeons, and overworld.
-- It performs frustum culling so only visible tiles are added to the batch,
-- then issues a single draw call for the entire visible layer.
--
-- @param grid      2D array: grid[y][x] = tileTypeID (1-based indices)
-- @param gridW     Width of the grid in tiles
-- @param gridH     Height of the grid in tiles
-- @param quadMap   Table mapping tileTypeID -> love.graphics.Quad
-- @param atlasName Which atlas to use (e.g. "terrain", "walls")
-- @param tileSize  Pixel size of each tile on screen (e.g. 32)
-- @param offsetX   Pixel X offset for the entire grid (default 0)
-- @param offsetY   Pixel Y offset for the entire grid (default 0)
function Renderer2D.drawTileGrid(grid, gridW, gridH, quadMap, atlasName, tileSize, offsetX, offsetY)
    if not grid then return end

    offsetX = offsetX or 0
    offsetY = offsetY or 0
    tileSize = tileSize or 32

    local batch = batches[atlasName]
    local atlas = atlases[atlasName]

    -- If the atlas or batch failed to load, silently skip.
    -- The caller should provide a classic fallback if needed.
    if not batch or not atlas then return end

    -- Clear this batch (in case it was already populated this frame
    -- by a prior call -- each drawTileGrid call is self-contained).
    batch:clear()

    -- -------------------------------------------------------------------
    -- Frustum culling: determine the range of tiles visible on screen.
    -- We use Camera2D state directly for efficiency rather than calling
    -- isVisible per-tile (which would be O(n) function calls).
    -- -------------------------------------------------------------------
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    local camX = Camera2D.x or 0
    local camY = Camera2D.y or 0
    local zoom = Camera2D.zoom or 1.0

    -- Visible area in world coordinates, accounting for zoom.
    local visibleW = screenW / zoom
    local visibleH = screenH / zoom

    -- Convert visible world rect to tile indices (1-based).
    -- Subtract offset so we are in grid-local coordinates.
    local startX = math.max(1, math.floor((camX - offsetX) / tileSize))
    local startY = math.max(1, math.floor((camY - offsetY) / tileSize))
    local endX   = math.min(gridW, math.ceil((camX - offsetX + visibleW) / tileSize) + 1)
    local endY   = math.min(gridH, math.ceil((camY - offsetY + visibleH) / tileSize) + 1)

    -- -------------------------------------------------------------------
    -- Populate the SpriteBatch with only the visible tiles.
    -- -------------------------------------------------------------------
    for y = startY, endY do
        local row = grid[y]
        if row then
            for x = startX, endX do
                local tileID = row[x]
                if tileID then
                    local quad = quadMap[tileID]
                    if quad then
                        local px = offsetX + (x - 1) * tileSize
                        local py = offsetY + (y - 1) * tileSize
                        batch:add(quad, px, py)
                    end
                    -- If quad is nil for this tileID, skip silently.
                    -- This handles unmapped tile types gracefully.
                end
            end
        end
    end

    -- -------------------------------------------------------------------
    -- Issue a SINGLE draw call for all visible tiles in this layer.
    -- This is where the SpriteBatch performance advantage materializes.
    -- -------------------------------------------------------------------
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(batch)
end

-- ==========================================================================
--                    SINGLE TILE DRAWING (BATCHED)
-- ==========================================================================

--- Draw a single tile from an atlas. Useful for overlays, decorations,
-- and individual objects that don't belong to a grid.
--
-- This draws immediately (not batched) because single-tile draws are
-- typically sparse and don't benefit from batching.
--
-- @param atlasName  Which atlas to use
-- @param quad       love.graphics.Quad for the tile
-- @param x          World X position
-- @param y          World Y position
-- @param r          Rotation in radians (default 0)
-- @param sx         X scale (default 1)
-- @param sy         Y scale (default sx)
function Renderer2D.drawTile(atlasName, quad, x, y, r, sx, sy)
    if not quad then return end

    local atlas = atlases[atlasName]
    if not atlas then return end

    r  = r  or 0
    sx = sx or 1
    sy = sy or sx

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(atlas, quad, x, y, r, sx, sy)
end

-- ==========================================================================
--                   ENTITY / SPRITE DRAWING (IMMEDIATE)
-- ==========================================================================

--- Draw a sprite (character, NPC, creature) immediately.
-- NOT batched -- entities use their own per-character sprite sheets and
-- are drawn individually. This is fine because entity counts are low
-- compared to tile counts.
--
-- @param image  love.graphics.Image (the sprite sheet)
-- @param quad   love.graphics.Quad for the current frame
-- @param x      World X position
-- @param y      World Y position
-- @param r      Rotation in radians (default 0)
-- @param sx     X scale (default 1)
-- @param sy     Y scale (default sx)
-- @param ox     Origin X offset (default 0)
-- @param oy     Origin Y offset (default 0)
function Renderer2D.drawSprite(image, quad, x, y, r, sx, sy, ox, oy)
    if not image then return end

    r  = r  or 0
    sx = sx or 1
    sy = sy or sx
    ox = ox or 0
    oy = oy or 0

    love.graphics.setColor(1, 1, 1, 1)

    if quad then
        love.graphics.draw(image, quad, x, y, r, sx, sy, ox, oy)
    else
        love.graphics.draw(image, x, y, r, sx, sy, ox, oy)
    end
end

-- ==========================================================================
--                     RECTANGLE DRAWING (CONVENIENCE)
-- ==========================================================================

--- Draw a colored rectangle. Used for UI overlays, debug visualization,
-- and as a fallback when in "classic" render mode.
--
-- This is a thin wrapper around love.graphics.rectangle that matches
-- the Renderer2D API style. Color should be set by the caller before
-- calling this function.
--
-- @param mode  "fill" or "line"
-- @param x     X position
-- @param y     Y position
-- @param w     Width
-- @param h     Height
-- @param rx    X radius for rounded corners (optional)
-- @param ry    Y radius for rounded corners (optional)
function Renderer2D.drawRect(mode, x, y, w, h, rx, ry)
    love.graphics.rectangle(mode, x, y, w, h, rx or 0, ry or 0)
end

-- ==========================================================================
--                        ATLAS / BATCH ACCESS
-- ==========================================================================

--- Get the raw atlas image by name.
-- @param name  Atlas name (e.g. "terrain", "walls")
-- @return love.graphics.Image or nil
function Renderer2D.getAtlas(name)
    return atlases[name]
end

--- Get the SpriteBatch for a given atlas.
-- Advanced use only -- most callers should use drawTileGrid instead.
-- @param name  Atlas name
-- @return love.graphics.SpriteBatch or nil
function Renderer2D.getBatch(name)
    return batches[name]
end

-- ==========================================================================
--                        CAMERA HELPERS
-- ==========================================================================

--- Push camera transform onto the graphics stack.
-- Call before drawing world-space content. Pairs with popCamera().
-- @param camera  (optional) Unused; always uses the global Camera2D module.
--                Parameter kept for API consistency / future multi-camera.
function Renderer2D.pushCamera(camera)
    Camera2D.apply()
end

--- Pop camera transform from the graphics stack.
-- Call after drawing world-space content.
function Renderer2D.popCamera()
    Camera2D.reset()
end

--- Calculate the range of tile coordinates visible on screen.
-- Useful for systems that need to iterate over visible tiles without
-- going through drawTileGrid (e.g. entity culling, fog of war).
--
-- @param camera    (optional) Unused; uses global Camera2D.
-- @param tileSize  Pixel size of tiles (default 32)
-- @return startX, startY, endX, endY  (1-based tile coordinates)
function Renderer2D.getVisibleBounds(camera, tileSize)
    tileSize = tileSize or 32

    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    local camX = Camera2D.x or 0
    local camY = Camera2D.y or 0
    local zoom = Camera2D.zoom or 1.0

    local visibleW = screenW / zoom
    local visibleH = screenH / zoom

    local startX = math.max(1, math.floor(camX / tileSize))
    local startY = math.max(1, math.floor(camY / tileSize))
    local endX   = math.ceil((camX + visibleW) / tileSize) + 1
    local endY   = math.ceil((camY + visibleH) / tileSize) + 1

    return startX, startY, endX, endY
end

-- ==========================================================================
--                        DROP SHADOW HELPER
-- ==========================================================================

--- Draw an elliptical drop shadow under an entity.
-- Uses a semi-transparent black ellipse to give a grounded appearance
-- to characters and objects.
--
-- @param x  Center X of the shadow
-- @param y  Center Y (bottom of the entity, ground level)
-- @param w  Width of the shadow ellipse
-- @param h  Height of the shadow ellipse (typically w * 0.3 to 0.5)
function Renderer2D.drawShadow(x, y, w, h)
    w = w or 24
    h = h or 8

    -- Draw an ellipse by using a scaled circle.
    -- love.graphics.ellipse is available in modern LOVE (0.9+).
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.ellipse("fill", x, y, w / 2, h / 2)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ==========================================================================
--                     ATLAS CONFIG QUERY (UTILITY)
-- ==========================================================================

--- Get the configuration table for a named atlas.
-- Returns tile size, expected dimensions, and file path.
-- @param name  Atlas name
-- @return Config table or nil
function Renderer2D.getAtlasConfig(name)
    return ATLAS_CONFIG[name]
end

--- Get the list of all configured atlas names.
-- @return Array of atlas name strings
function Renderer2D.getAtlasNames()
    local names = {}
    for name in pairs(ATLAS_CONFIG) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

return Renderer2D
