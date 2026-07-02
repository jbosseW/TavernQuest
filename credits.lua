-- Credits Page

local Credits = {}

-- Font cache for performance
local FontCache = require("fontcache")
local function getFont(size)
    return FontCache.get(size)
end

-- State
local state = {
    scrollY = 0,
    scrollSpeed = 30,
    autoScroll = true,
}

-- Colors
local colors = {
    bg = {0.05, 0.05, 0.1},
    title = {1, 0.8, 0.2},
    heading = {0.9, 0.6, 0.2},
    text = {0.9, 0.9, 0.9},
    textDim = {0.6, 0.6, 0.7},
    link = {0.4, 0.7, 1},
}

-- Credits content
local credits = {
    {type = "title", text = "TAVERN TIMES"},
    {type = "spacer"},
    {type = "spacer"},

    {type = "heading", text = "Developer"},
    {type = "name", text = "JB"},
    {type = "spacer"},
    {type = "spacer"},

    {type = "heading", text = "Version"},
    {type = "credit", text = "v1.0.0"},
    {type = "spacer"},
    {type = "spacer"},

    {type = "footer", text = "Thank you for playing!"},
    {type = "spacer"},
    {type = "spacer"},
    {type = "spacer"},
}

function Credits.init()
    state.scrollY = 0
    state.autoScroll = true
end

function Credits.update(dt)
    if state.autoScroll then
        state.scrollY = state.scrollY + state.scrollSpeed * dt
    end
end

function Credits.draw()
    local screenW, screenH = love.graphics.getDimensions()

    -- Background
    love.graphics.setColor(colors.bg)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Draw starfield effect
    love.graphics.setColor(1, 1, 1, 0.3)
    math.randomseed(42)  -- Consistent stars
    for i = 1, 100 do
        local x = math.random(0, screenW)
        local y = (math.random(0, screenH * 3) - state.scrollY * 0.5) % (screenH * 1.5)
        local size = math.random(1, 3)
        love.graphics.circle("fill", x, y, size)
    end
    math.randomseed(os.time())

    -- Calculate content area
    local contentX = screenW / 2
    local y = screenH / 2 - state.scrollY

    -- Draw credits
    for _, item in ipairs(credits) do
        if item.type == "title" then
            love.graphics.setColor(colors.title)
            love.graphics.setFont(getFont(48))
            local w = love.graphics.getFont():getWidth(item.text)
            love.graphics.print(item.text, contentX - w/2, y)
            y = y + 70

        elseif item.type == "subtitle" then
            love.graphics.setColor(colors.textDim)
            love.graphics.setFont(getFont(24))
            local w = love.graphics.getFont():getWidth(item.text)
            love.graphics.print(item.text, contentX - w/2, y)
            y = y + 50

        elseif item.type == "heading" then
            love.graphics.setColor(colors.heading)
            love.graphics.setFont(getFont(28))
            local w = love.graphics.getFont():getWidth(item.text)
            love.graphics.print(item.text, contentX - w/2, y)
            y = y + 45

        elseif item.type == "name" then
            love.graphics.setColor(colors.text)
            love.graphics.setFont(getFont(20))
            local w = love.graphics.getFont():getWidth(item.text)
            love.graphics.print(item.text, contentX - w/2, y)
            y = y + 30

        elseif item.type == "credit" then
            love.graphics.setColor(colors.textDim)
            love.graphics.setFont(getFont(18))
            local w = love.graphics.getFont():getWidth(item.text)
            love.graphics.print(item.text, contentX - w/2, y)
            y = y + 28

        elseif item.type == "footer" then
            love.graphics.setColor(colors.title)
            love.graphics.setFont(getFont(32))
            local w = love.graphics.getFont():getWidth(item.text)
            love.graphics.print(item.text, contentX - w/2, y)
            y = y + 50

        elseif item.type == "spacer" then
            y = y + 30
        end
    end

    -- Gradient overlay at top
    for i = 0, 80 do
        local alpha = 1 - (i / 80)
        love.graphics.setColor(colors.bg[1], colors.bg[2], colors.bg[3], alpha)
        love.graphics.rectangle("fill", 0, i, screenW, 1)
    end

    -- Instructions
    love.graphics.setColor(colors.textDim)
    love.graphics.setFont(getFont(14))
    love.graphics.print("Press ESC or click to return  |  Scroll or Arrow Keys to navigate", 20, screenH - 30)

    -- Back button
    local backW, backH = 100, 40
    local backX = screenW - backW - 20
    local backY = 20
    local mx, my = love.mouse.getPosition()
    local backHover = mx >= backX and mx <= backX + backW and my >= backY and my <= backY + backH

    love.graphics.setColor(backHover and {0.3, 0.3, 0.4} or {0.2, 0.2, 0.3})
    love.graphics.rectangle("fill", backX, backY, backW, backH, 8, 8)
    love.graphics.setColor(colors.title)
    love.graphics.rectangle("line", backX, backY, backW, backH, 8, 8)
    love.graphics.setColor(colors.text)
    love.graphics.setFont(getFont(16))
    love.graphics.print("Back", backX + 32, backY + 10)
end

function Credits.mousepressed(x, y, button)
    if button ~= 1 then return end

    local screenW, screenH = love.graphics.getDimensions()

    -- Back button
    local backW, backH = 100, 40
    local backX = screenW - backW - 20
    local backY = 20
    if x >= backX and x <= backX + backW and y >= backY and y <= backY + backH then
        GameState.current = "menu"
        return
    end

    -- Toggle auto-scroll on click anywhere else
    state.autoScroll = not state.autoScroll
end

function Credits.keypressed(key)
    if key == "escape" then
        GameState.current = "menu"
    elseif key == "up" then
        state.scrollY = state.scrollY - 50
        state.autoScroll = false
    elseif key == "down" then
        state.scrollY = state.scrollY + 50
        state.autoScroll = false
    elseif key == "space" then
        state.autoScroll = not state.autoScroll
    end
end

function Credits.wheelmoved(x, y)
    state.scrollY = state.scrollY - y * 40
    state.autoScroll = false
end

return Credits
