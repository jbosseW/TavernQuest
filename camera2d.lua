-- 2D Camera System for Top-Down RPG
-- Smooth following, screen shake, zoom support

local Camera2D = {}

-- Initialize camera
function Camera2D.init(x, y)
    Camera2D.x = x or 0
    Camera2D.y = y or 0
    Camera2D.targetX = Camera2D.x
    Camera2D.targetY = Camera2D.y
    Camera2D.zoom = 1.0
    Camera2D.targetZoom = 1.0
    Camera2D.rotation = 0

    -- Follow settings
    Camera2D.followSpeed = 8.0  -- Higher = snappier following
    Camera2D.deadzone = {x = 32, y = 32}  -- Pixels before camera starts moving

    -- Screen shake
    Camera2D.shakeAmount = 0
    Camera2D.shakeDuration = 0
    Camera2D.shakeTimer = 0
    Camera2D.shakeOffsetX = 0
    Camera2D.shakeOffsetY = 0

    -- Bounds (optional map boundaries)
    Camera2D.bounds = nil  -- {minX, minY, maxX, maxY}

    print("Camera2D initialized")
end

-- Set camera position instantly (no interpolation)
function Camera2D.setPosition(x, y)
    Camera2D.x = x
    Camera2D.y = y
    Camera2D.targetX = x
    Camera2D.targetY = y
end

-- Set target position (camera will smoothly move to it)
function Camera2D.setTarget(x, y)
    Camera2D.targetX = x
    Camera2D.targetY = y
end

-- Follow an entity (player, NPC, etc.)
function Camera2D.follow(entity, offsetX, offsetY)
    offsetX = offsetX or 0
    offsetY = offsetY or 0

    -- Center camera on entity
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    Camera2D.targetX = entity.x + offsetX - screenW / 2
    Camera2D.targetY = entity.y + offsetY - screenH / 2
end

-- Set zoom level
function Camera2D.setZoom(zoom)
    Camera2D.targetZoom = math.max(0.1, math.min(4.0, zoom))
end

-- Screen shake effect
-- @param intensity: Shake strength in pixels
-- @param duration: Shake duration in seconds
function Camera2D.shake(intensity, duration)
    Camera2D.shakeAmount = intensity or 10
    Camera2D.shakeDuration = duration or 0.3
    Camera2D.shakeTimer = 0
end

-- Set camera bounds (prevent camera from going outside map)
function Camera2D.setBounds(minX, minY, maxX, maxY)
    Camera2D.bounds = {
        minX = minX,
        minY = minY,
        maxX = maxX,
        maxY = maxY
    }
end

-- Clear camera bounds
function Camera2D.clearBounds()
    Camera2D.bounds = nil
end

-- Update camera (call every frame)
function Camera2D.update(dt)
    -- Smooth following (lerp to target)
    local lerpSpeed = Camera2D.followSpeed * dt
    Camera2D.x = Camera2D.x + (Camera2D.targetX - Camera2D.x) * lerpSpeed
    Camera2D.y = Camera2D.y + (Camera2D.targetY - Camera2D.y) * lerpSpeed

    -- Smooth zoom
    local zoomLerpSpeed = 5.0 * dt
    Camera2D.zoom = Camera2D.zoom + (Camera2D.targetZoom - Camera2D.zoom) * zoomLerpSpeed

    -- Apply bounds (if set)
    if Camera2D.bounds then
        local screenW = love.graphics.getWidth()
        local screenH = love.graphics.getHeight()

        -- Account for zoom - when zoomed in, visible area is smaller
        local visibleW = screenW / Camera2D.zoom
        local visibleH = screenH / Camera2D.zoom

        -- Clamp camera to bounds (handle cases where map is smaller than screen)
        local maxX = math.max(Camera2D.bounds.minX, Camera2D.bounds.maxX - visibleW)
        local maxY = math.max(Camera2D.bounds.minY, Camera2D.bounds.maxY - visibleH)

        Camera2D.x = math.max(Camera2D.bounds.minX, math.min(Camera2D.x, maxX))
        Camera2D.y = math.max(Camera2D.bounds.minY, math.min(Camera2D.y, maxY))
    end

    -- Update screen shake
    if Camera2D.shakeTimer < Camera2D.shakeDuration then
        Camera2D.shakeTimer = Camera2D.shakeTimer + dt

        -- Random shake offset
        local progress = Camera2D.shakeTimer / Camera2D.shakeDuration
        local amount = Camera2D.shakeAmount * (1 - progress)  -- Decay over time

        Camera2D.shakeOffsetX = (math.random() * 2 - 1) * amount
        Camera2D.shakeOffsetY = (math.random() * 2 - 1) * amount
    else
        Camera2D.shakeOffsetX = 0
        Camera2D.shakeOffsetY = 0
    end
end

-- Apply camera transformation (call before drawing world)
function Camera2D.apply()
    love.graphics.push()

    -- Apply zoom (centered on screen)
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    if Camera2D.zoom ~= 1.0 then
        love.graphics.translate(screenW / 2, screenH / 2)
        love.graphics.scale(Camera2D.zoom, Camera2D.zoom)
        love.graphics.translate(-screenW / 2, -screenH / 2)
    end

    -- Apply camera position + shake
    local finalX = Camera2D.x + Camera2D.shakeOffsetX
    local finalY = Camera2D.y + Camera2D.shakeOffsetY
    love.graphics.translate(-finalX, -finalY)

    -- Apply rotation (if used)
    if Camera2D.rotation ~= 0 then
        love.graphics.translate(screenW / 2, screenH / 2)
        love.graphics.rotate(Camera2D.rotation)
        love.graphics.translate(-screenW / 2, -screenH / 2)
    end
end

-- Remove camera transformation (call after drawing world)
function Camera2D.reset()
    love.graphics.pop()
end

-- Convert screen position to world position
function Camera2D.screenToWorld(screenX, screenY)
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- Account for zoom transformation (centered on screen)
    local adjustedX = (screenX - screenW / 2) / Camera2D.zoom + screenW / 2
    local adjustedY = (screenY - screenH / 2) / Camera2D.zoom + screenH / 2

    local worldX = adjustedX + Camera2D.x
    local worldY = adjustedY + Camera2D.y
    return worldX, worldY
end

-- Convert world position to screen position
function Camera2D.worldToScreen(worldX, worldY)
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    local screenX = worldX - Camera2D.x
    local screenY = worldY - Camera2D.y

    -- Account for zoom transformation (centered on screen)
    screenX = (screenX - screenW / 2) * Camera2D.zoom + screenW / 2
    screenY = (screenY - screenH / 2) * Camera2D.zoom + screenH / 2

    return screenX, screenY
end

-- Get camera center in world coordinates
function Camera2D.getCenter()
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    return Camera2D.x + screenW / 2, Camera2D.y + screenH / 2
end

-- Check if a rectangle is visible on screen
function Camera2D.isVisible(x, y, w, h)
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()

    -- Account for zoom - when zoomed in, visible area is smaller
    local visibleW = screenW / Camera2D.zoom
    local visibleH = screenH / Camera2D.zoom

    return x + w >= Camera2D.x and
           x <= Camera2D.x + visibleW and
           y + h >= Camera2D.y and
           y <= Camera2D.y + visibleH
end

-- Instantly move camera to position (no lerp, for level transitions)
function Camera2D.snapTo(x, y)
    Camera2D.x = x
    Camera2D.y = y
    Camera2D.targetX = x
    Camera2D.targetY = y
    Camera2D.shakeOffsetX = 0
    Camera2D.shakeOffsetY = 0
end

-- Instantly center camera on position
function Camera2D.centerOn(x, y)
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    Camera2D.snapTo(x - screenW / 2, y - screenH / 2)
end

-- Debug draw (show camera bounds, center, etc.)
function Camera2D.drawDebug()
    Camera2D.reset()  -- Draw in screen space

    love.graphics.setColor(0, 1, 0, 0.5)

    -- Center crosshair
    local cx, cy = love.graphics.getWidth() / 2, love.graphics.getHeight() / 2
    love.graphics.line(cx - 10, cy, cx + 10, cy)
    love.graphics.line(cx, cy - 10, cx, cy + 10)

    -- Camera info
    love.graphics.setColor(0, 1, 0)
    love.graphics.print("Camera: " .. math.floor(Camera2D.x) .. ", " .. math.floor(Camera2D.y), 10, 90)
    love.graphics.print("Zoom: " .. string.format("%.2f", Camera2D.zoom), 10, 110)
    love.graphics.print("Shake: " .. string.format("%.1f", Camera2D.shakeAmount), 10, 130)

    Camera2D.apply()  -- Re-apply camera transform
end

return Camera2D
