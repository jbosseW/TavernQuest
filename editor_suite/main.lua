-- Tavern Quest Editor Suite - Main Entry Point
-- A standalone LOVE2D editor for creating and editing game content

local App = require("core.app")
local AssetLoader = require("core.asset_loader")

local app = nil

function love.load()
    -- Set up window
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.graphics.setBackgroundColor(0.08, 0.10, 0.14)

    -- Initialize asset loader (mount parent game directory)
    AssetLoader.init()

    -- Create directories
    love.filesystem.createDirectory("projects")
    love.filesystem.createDirectory("exports")

    -- Create the application
    app = App.new()
end

function love.update(dt)
    if app then
        app:update(dt)
    end
end

function love.draw()
    if app then
        app:draw()
    end
end

function love.mousepressed(x, y, button)
    if app then
        app:mousepressed(x, y, button)
    end
end

function love.mousereleased(x, y, button)
    if app then
        app:mousereleased(x, y, button)
    end
end

function love.mousemoved(x, y, dx, dy)
    if app then
        app:mousemoved(x, y, dx, dy)
    end
end

function love.wheelmoved(x, y)
    if app then
        app:wheelmoved(x, y)
    end
end

function love.keypressed(key)
    if app then
        app:keypressed(key)
    end
end

function love.textinput(t)
    if app then
        app:textinput(t)
    end
end

function love.resize(w, h)
    if app then
        app:resize(w, h)
    end
end

function love.quit()
    -- Could prompt to save if dirty
    return false
end
