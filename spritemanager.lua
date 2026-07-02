-- Sprite Manager - LPC Character Sprite System
-- Manages layered sprite sheets for character rendering

local SpriteManager = {}

-- Sprite sheet cache: { [name] = { image = Image, width = N, height = N } }
local spriteCache = {}

-- LPC sprite sheet layout: 4 directions x 4 frames, each frame 64x64
local FRAME_WIDTH = 64
local FRAME_HEIGHT = 64
local DIRECTIONS = { down = 0, left = 1, right = 2, up = 3 }
local ANIM_FRAMES = 4
local ANIM_SPEED = 6  -- frames per second

-- Load a sprite sheet into cache
-- @param name: Unique name for the sprite
-- @param path: File path to the sprite sheet PNG
-- @return: Sprite data table or nil
function SpriteManager.loadSpriteSheet(name, path)
    if spriteCache[name] then
        return spriteCache[name]
    end

    local success, image = pcall(function()
        return love.graphics.newImage(path)
    end)

    if success and image then
        local data = {
            image = image,
            width = image:getWidth(),
            height = image:getHeight(),
            frameW = FRAME_WIDTH,
            frameH = FRAME_HEIGHT,
            path = path
        }
        spriteCache[name] = data
        return data
    end

    return nil
end

-- Get sprite info from cache
-- @param name: Sprite name
-- @return: Sprite data or nil
function SpriteManager.getSpriteInfo(name)
    return spriteCache[name]
end

-- Create a character instance with layered sprites
-- @param layers: Array of sprite layer names
-- @param x: Starting X position
-- @param y: Starting Y position
-- @return: Character instance table
function SpriteManager.createCharacter(layers, x, y)
    local character = {
        layers = layers or {},
        x = x or 0,
        y = y or 0,
        direction = "down",
        animFrame = 1,
        animTimer = 0,
        isMoving = false,
        scale = 1,
        flipX = false,
        visible = true,
        speed = 100,
        template = nil
    }
    return character
end

-- Update character animation
-- @param character: Character instance
-- @param dt: Delta time
function SpriteManager.updateCharacter(character, dt)
    if not character then return end

    if character.isMoving then
        character.animTimer = character.animTimer + dt * ANIM_SPEED
        if character.animTimer >= 1 then
            character.animTimer = character.animTimer - 1
            character.animFrame = character.animFrame + 1
            if character.animFrame > ANIM_FRAMES then
                character.animFrame = 1
            end
        end
    else
        character.animFrame = 1
        character.animTimer = 0
    end
end

-- Draw a character with all sprite layers
-- @param character: Character instance
function SpriteManager.drawCharacter(character)
    if not character or not character.visible then return end

    local dirRow = DIRECTIONS[character.direction] or 0
    local frame = (character.animFrame or 1) - 1

    local scale = character.scale or 1
    local sx = character.flipX and -scale or scale

    for _, layerName in ipairs(character.layers) do
        local spriteData = spriteCache[layerName]
        if spriteData and spriteData.image then
            -- Calculate quad for current frame
            local qx = frame * FRAME_WIDTH
            local qy = dirRow * FRAME_HEIGHT

            -- Ensure quad is within sprite sheet bounds
            if qx + FRAME_WIDTH <= spriteData.width and qy + FRAME_HEIGHT <= spriteData.height then
                local quad = love.graphics.newQuad(
                    qx, qy,
                    FRAME_WIDTH, FRAME_HEIGHT,
                    spriteData.width, spriteData.height
                )

                local ox = FRAME_WIDTH / 2
                local oy = FRAME_HEIGHT / 2

                love.graphics.draw(
                    spriteData.image, quad,
                    character.x, character.y,
                    0,
                    sx, scale,
                    ox, oy
                )
            end
        end
    end
end

-- Set character direction
-- @param character: Character instance
-- @param direction: "up", "down", "left", "right"
function SpriteManager.setDirection(character, direction)
    if character and DIRECTIONS[direction] then
        character.direction = direction
    end
end

-- Set character moving state
-- @param character: Character instance
-- @param moving: boolean
function SpriteManager.setMoving(character, moving)
    if character then
        character.isMoving = moving
    end
end

-- Move character in a direction
-- @param character: Character instance
-- @param dx: X delta
-- @param dy: Y delta
-- @param dt: Delta time
function SpriteManager.moveCharacter(character, dx, dy, dt)
    if not character then return end

    local speed = character.speed or 100
    character.x = character.x + dx * speed * dt
    character.y = character.y + dy * speed * dt

    -- Set direction based on movement
    if math.abs(dx) > math.abs(dy) then
        character.direction = dx > 0 and "right" or "left"
    elseif dy ~= 0 then
        character.direction = dy > 0 and "down" or "up"
    end

    character.isMoving = (dx ~= 0 or dy ~= 0)
end

-- Unload a sprite from cache
-- @param name: Sprite name
function SpriteManager.unload(name)
    if spriteCache[name] and spriteCache[name].image then
        spriteCache[name].image:release()
    end
    spriteCache[name] = nil
end

-- Clear all cached sprites
function SpriteManager.clearCache()
    for name, data in pairs(spriteCache) do
        if data.image then
            pcall(function() data.image:release() end)
        end
    end
    spriteCache = {}
end

return SpriteManager
