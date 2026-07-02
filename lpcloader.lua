-- LPC Sprite Loader for TextRPG Integration
-- Loads LPC Universal Spritesheet format (64x64 sprites)
-- Handles character layering, tilesets, and creatures

local LPCLoader = {}

-- Sprite cache
LPCLoader.cache = {}
LPCLoader.tilesets = {}
LPCLoader.characters = {}
LPCLoader.creatures = {}
LPCLoader.initialized = false

-- LPC animation layout (standard)
LPCLoader.ANIMS = {
    SPELLCAST = 0,  -- Row 0
    THRUST = 1,     -- Row 1
    WALK = 2,       -- Row 2
    SLASH = 3,      -- Row 3
    SHOOT = 4,      -- Row 4
    HURT = 5,       -- Row 5
}

-- LPC directions (in spritesheet rows)
LPCLoader.DIRS = {
    SOUTH = 0,  -- Facing down
    WEST = 1,   -- Facing left
    EAST = 2,   -- Facing right
    NORTH = 3,  -- Facing up
}

-- Initialize
function LPCLoader.init()
    if LPCLoader.initialized then return end

    print("========================================")
    print("LPC Sprite Loader Initializing")
    print("========================================")

    -- Set pixel-perfect rendering
    love.graphics.setDefaultFilter("nearest", "nearest")

    LPCLoader.initialized = true
    print("LPC Loader ready")
end

-- Load an image with caching
function LPCLoader.loadImage(path)
    if LPCLoader.cache[path] then
        return LPCLoader.cache[path]
    end

    local fullPath = "assets/lpc/" .. path
    local success, img = pcall(love.graphics.newImage, fullPath)

    if success then
        LPCLoader.cache[path] = img
        return img
    else
        print("Warning: Could not load " .. fullPath)
        return nil
    end
end

-- Create a quad for a specific frame
-- @param image: The sprite image
-- @param frameX: Frame X in spritesheet (0-based)
-- @param frameY: Frame Y in spritesheet (0-based)
-- @param frameW: Frame width (default 64)
-- @param frameH: Frame height (default 64)
function LPCLoader.createQuad(image, frameX, frameY, frameW, frameH)
    frameW = frameW or 64
    frameH = frameH or 64

    if not image then return nil end

    local imgW, imgH = image:getDimensions()
    return love.graphics.newQuad(
        frameX * frameW,
        frameY * frameH,
        frameW,
        frameH,
        imgW,
        imgH
    )
end

-- Create animation quads for a character sprite
-- @param image: The sprite image
-- @param anim: Animation row (LPCLoader.ANIMS.*)
-- @param frames: Number of frames (default 9)
function LPCLoader.createAnimQuads(image, anim, frames)
    frames = frames or 9
    local quads = {}

    for i = 0, frames - 1 do
        quads[i + 1] = LPCLoader.createQuad(image, i, anim)
    end

    return quads
end

-- Load a tileset from LPC tilesets directory
function LPCLoader.loadTileset(name)
    local path = "tilesets/" .. name .. ".png"
    return LPCLoader.loadImage(path)
end

-- Load terrain atlas (complete world building tileset)
function LPCLoader.loadTerrainAtlas()
    local img = LPCLoader.loadImage("tilesets/terrain/terrain_atlas.png")
    if not img then
        img = LPCLoader.loadImage("tilesets/terrain/terrain.png")
    end
    return img
end

-- Load the base outdoor atlas (fences, crops, outdoor objects)
function LPCLoader.loadBaseOutdoorAtlas()
    return LPCLoader.loadImage("tilesets/terrain/base_out_atlas.png")
end

-- Load walls atlas (2048x3072, 6144 tiles with Wang auto-tiling)
function LPCLoader.loadWallsAtlas()
    return LPCLoader.loadImage("tilesets/walls/lpc-walls/walls.png")
end

-- Load a building tileset by name
function LPCLoader.loadBuildingAtlas(name)
    return LPCLoader.loadImage("tilesets/buildings/" .. name .. ".png")
end

-- Load cobblestone paths and town objects
function LPCLoader.loadTownObjectsAtlas()
    return LPCLoader.loadImage("tilesets/town_objects/cobblestone_paths.png")
end

-- Load worldmap tileset (16x16 tiles)
function LPCLoader.loadWorldmapAtlas()
    return LPCLoader.loadImage("tilesets/worldmap/worldmap_tileset.png")
end

-- Load worldmap mountains overlay
function LPCLoader.loadWorldmapMountains()
    return LPCLoader.loadImage("tilesets/worldmap/worldmap_mountains.png")
end

-- Load worldmap water animation frames
function LPCLoader.loadWorldmapWater()
    return LPCLoader.loadImage("tilesets/worldmap/worldmap_water.png")
end

-- Load desert tileset
function LPCLoader.loadDesertAtlas()
    return LPCLoader.loadImage("tilesets/desert/desert_tileset.png")
end

-- Load vegetation sprites
function LPCLoader.loadVegetation()
    return LPCLoader.loadImage("tilesets/vegetation/trees-and-bushes.png")
end

-- Load enemy sprite by name
function LPCLoader.loadEnemy(name)
    return LPCLoader.loadImage("characters/enemies/" .. name .. ".png")
end

-- Load a raw image from any path under assets/lpc/
function LPCLoader.loadRaw(relativePath)
    return LPCLoader.loadImage(relativePath)
end

-- Load a character body sprite
function LPCLoader.loadBody(gender, skinTone)
    local path = "characters/revised_basics/body/" .. gender .. "/" .. skinTone .. ".png"
    return LPCLoader.loadImage(path)
end

-- Load hair sprite
function LPCLoader.loadHair(style, gender, color)
    local path = "characters/revised_basics/hair/" .. style .. "/" .. gender .. "/" .. color .. ".png"
    return LPCLoader.loadImage(path)
end

-- Load clothing (torso, legs, feet)
function LPCLoader.loadClothing(category, type, gender, color)
    -- category: torso, legs, feet
    local path = "characters/revised_basics/" .. category .. "/" .. type .. "/" .. gender .. "/" .. color .. ".png"
    return LPCLoader.loadImage(path)
end

-- Load a creature sprite
function LPCLoader.loadCreature(type, variant)
    local path = "creatures/" .. type .. "/" .. variant .. ".png"
    return LPCLoader.loadImage(path)
end

-- Create a layered character sprite
-- @param config: Table with {body, hair, torso, legs, feet, weapon}
-- Returns table of images to draw in order
function LPCLoader.createCharacter(config)
    local layers = {}

    -- Load each layer
    if config.body then
        table.insert(layers, config.body)
    end

    if config.hair then
        table.insert(layers, config.hair)
    end

    if config.torso then
        table.insert(layers, config.torso)
    end

    if config.legs then
        table.insert(layers, config.legs)
    end

    if config.feet then
        table.insert(layers, config.feet)
    end

    if config.weapon then
        table.insert(layers, config.weapon)
    end

    return layers
end

-- Draw a layered character
-- @param layers: Array of sprite images
-- @param quad: The quad to use (or nil for whole sprite)
-- @param x, y: Position
-- @param scale: Scale factor (default 1)
function LPCLoader.drawCharacter(layers, quad, x, y, scale)
    scale = scale or 1

    for _, layer in ipairs(layers) do
        if layer then
            if quad then
                love.graphics.draw(layer, quad, x, y, 0, scale, scale)
            else
                love.graphics.draw(layer, x, y, 0, scale, scale)
            end
        end
    end
end

-- Get a simple terrain tile quad
-- @param tileset: The tileset image
-- @param tileX, tileY: Tile coordinates in the tileset
-- @param tileSize: Tile size (default 32)
function LPCLoader.getTileQuad(tileset, tileX, tileY, tileSize)
    tileSize = tileSize or 32

    if not tileset then return nil end

    local imgW, imgH = tileset:getDimensions()
    return love.graphics.newQuad(
        tileX * tileSize,
        tileY * tileSize,
        tileSize,
        tileSize,
        imgW,
        imgH
    )
end

-- Quick load presets for common character types
LPCLoader.presets = {
    warrior_male = function()
        return LPCLoader.createCharacter({
            body = LPCLoader.loadBody("male", "light"),
            hair = LPCLoader.loadHair("plain", "male", "brown"),
            torso = LPCLoader.loadClothing("torso", "chainmail", "male", "silver"),
            legs = LPCLoader.loadClothing("legs", "pants", "male", "teal")
        })
    end,

    mage_female = function()
        return LPCLoader.createCharacter({
            body = LPCLoader.loadBody("female", "light"),
            hair = LPCLoader.loadHair("princess", "female", "blonde"),
            torso = LPCLoader.loadClothing("torso", "robe", "female", "blue"),
            legs = LPCLoader.loadClothing("legs", "skirt", "female", "blue")
        })
    end,

    thief_male = function()
        return LPCLoader.createCharacter({
            body = LPCLoader.loadBody("male", "tan"),
            hair = LPCLoader.loadHair("messy", "male", "black"),
            torso = LPCLoader.loadClothing("torso", "leather", "male", "brown"),
            legs = LPCLoader.loadClothing("legs", "pants", "male", "black")
        })
    end
}

-- Helper: Check if LPC assets exist
function LPCLoader.checkAssets()
    local testPath = "assets/lpc/tilesets/terrain/terrain_atlas.png"
    local info = love.filesystem.getInfo(testPath)

    if info then
        print("LPC assets found at assets/lpc/")
        return true
    else
        -- Try fallback
        local fallback = love.filesystem.getInfo("assets/lpc/tilesets/terrain/terrain.png")
        if fallback then
            print("LPC assets found (terrain.png fallback)")
            return true
        end
        print("LPC assets not found at: assets/lpc/")
        return false
    end
end

-- Test function - draw a simple character
function LPCLoader.test()
    if not LPCLoader.checkAssets() then
        return false
    end

    print("\nTesting LPC sprite loading...")

    -- Try loading a simple body sprite
    local testBody = LPCLoader.loadBody("male", "light")
    if testBody then
        print("✓ Body sprite loaded successfully")
        print("  Dimensions:", testBody:getDimensions())
        return true
    else
        print("✗ Failed to load test sprite")
        return false
    end
end

return LPCLoader
