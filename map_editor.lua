-- Map Editor - Visual dungeon map editor for Tavern Quest
-- Create, edit, save, and play custom dungeon maps

local MapEditor = {}
local Data = require("rpg_data")
local RpgDungeon = require("rpg_dungeon")

-- Cached fonts
local fontSmall = nil
local fontMedium = nil
local fontLarge = nil
local fontIcon = nil

local function ensureFonts()
    if not fontSmall then
        fontSmall = love.graphics.newFont(12)
        fontMedium = love.graphics.newFont(14)
        fontLarge = love.graphics.newFont(18)
        fontIcon = love.graphics.newFont(16)
    end
end

-- Tile type lookup cache (built once on init)
local tileTypeCache = {}

local function buildTileCache()
    tileTypeCache = {}
    for _, t in ipairs(Data.DUNGEON_TILE_TYPES) do
        tileTypeCache[t.id] = t
    end
end

-- Constants
local CELL_SIZE = 24

-- Game state
local state = {
    active = false,
    grid = {},           -- 2D grid [y][x] = {type = "wall", explored = false}
    gridWidth = 30,
    gridHeight = 25,
    selectedTile = "floor",  -- currently selected tile type from palette
    mapName = "Untitled",

    -- Camera/view
    cameraX = 0,
    cameraY = 0,
    zoom = 1.0,
    minZoom = 0.5,
    maxZoom = 3.0,

    -- Interaction
    painting = false,    -- true while mouse held and dragging
    erasing = false,     -- eraser mode active
    tool = "paint",      -- "paint" or "erase"

    -- UI regions (computed in draw)
    paletteWidth = 160,
    toolbarHeight = 50,
    statusBarHeight = 30,

    -- Text input
    editingName = false,
    nameInputText = "Untitled",
    nameInputCursor = 0,

    -- File management
    savedMaps = {},
    showLoadDialog = false,
    loadDialogScroll = 0,

    -- Grid resize
    showResizeDialog = false,
    resizeW = 30,
    resizeH = 25,

    -- Messages
    statusMessage = "",
    statusMessageTime = 0,

    -- Hover
    hoveredTileX = nil,
    hoveredTileY = nil,

    -- Rooms (for autodoors - detected from floor tiles)
    rooms = {},

    -- Scrolling with arrow keys
    scrollSpeed = 200,

    -- Palette scroll
    paletteScroll = 0,
}

-- ============================================================
-- Utility Functions
-- ============================================================

local function getTileColor(tileType)
    local t = tileTypeCache[tileType]
    if t then return t.color end
    return {0.5, 0.5, 0.5}
end

local function getTileIcon(tileType)
    local t = tileTypeCache[tileType]
    if t then return t.icon end
    return "?"
end

local function clamp(val, min, max)
    if val < min then return min end
    if val > max then return max end
    return val
end

local function sanitizeFilename(name)
    local result = name:lower()
    result = result:gsub("[^%w%-_]", "_")
    if result == "" then result = "untitled" end
    return result
end

local function setStatusMessage(msg)
    state.statusMessage = msg
    state.statusMessageTime = 3.0
end

-- ============================================================
-- Grid Functions
-- ============================================================

local function createEmptyGrid(w, h)
    local grid = {}
    for y = 1, h do
        grid[y] = {}
        for x = 1, w do
            grid[y][x] = {type = "wall", explored = false}
        end
    end
    state.gridWidth = w
    state.gridHeight = h
    return grid
end

-- Convert screen coordinates to grid coordinates
-- Returns gridX, gridY (1-based) or nil if outside grid
local function screenToGrid(sx, sy)
    local canvasX = state.paletteWidth
    local canvasY = state.toolbarHeight
    local screenW, screenH = love.graphics.getDimensions()
    local canvasW = screenW - state.paletteWidth
    local canvasH = screenH - state.toolbarHeight - state.statusBarHeight

    -- Check if within canvas area
    if sx < canvasX or sx >= canvasX + canvasW then return nil, nil end
    if sy < canvasY or sy >= canvasY + canvasH then return nil, nil end

    -- Convert to grid space accounting for camera and zoom
    local localX = sx - canvasX
    local localY = sy - canvasY

    local gx = math.floor((localX / state.zoom - state.cameraX) / CELL_SIZE) + 1
    local gy = math.floor((localY / state.zoom - state.cameraY) / CELL_SIZE) + 1

    if gx < 1 or gx > state.gridWidth then return nil, nil end
    if gy < 1 or gy > state.gridHeight then return nil, nil end

    return gx, gy
end

-- Paint a tile at grid position
local function paintTile(gx, gy)
    if not gx or not gy then return end
    if gx < 1 or gx > state.gridWidth then return end
    if gy < 1 or gy > state.gridHeight then return end
    if not state.grid[gy] or not state.grid[gy][gx] then return end

    if state.tool == "erase" then
        state.grid[gy][gx].type = "wall"
    else
        state.grid[gy][gx].type = state.selectedTile
    end
end

-- ============================================================
-- Room Detection (flood fill)
-- ============================================================

local function detectRooms()
    local rooms = {}
    local visited = {}
    for y = 1, state.gridHeight do
        visited[y] = {}
    end

    for y = 1, state.gridHeight do
        for x = 1, state.gridWidth do
            if not visited[y][x] and state.grid[y] and state.grid[y][x]
               and state.grid[y][x].type == "floor" then
                -- Flood fill to find this room
                local minX, minY, maxX, maxY = x, y, x, y
                local stack = {{x = x, y = y}}
                visited[y][x] = true

                while #stack > 0 do
                    local pos = table.remove(stack)
                    if pos.x < minX then minX = pos.x end
                    if pos.y < minY then minY = pos.y end
                    if pos.x > maxX then maxX = pos.x end
                    if pos.y > maxY then maxY = pos.y end

                    local dirs = {{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
                    for _, d in ipairs(dirs) do
                        local nx, ny = pos.x + d[1], pos.y + d[2]
                        if ny >= 1 and ny <= state.gridHeight
                           and nx >= 1 and nx <= state.gridWidth
                           and not visited[ny][nx]
                           and state.grid[ny] and state.grid[ny][nx]
                           and state.grid[ny][nx].type == "floor" then
                            visited[ny][nx] = true
                            table.insert(stack, {x = nx, y = ny})
                        end
                    end
                end

                table.insert(rooms, {
                    x = minX, y = minY,
                    w = maxX - minX + 1, h = maxY - minY + 1,
                    centerX = math.floor((minX + maxX) / 2),
                    centerY = math.floor((minY + maxY) / 2),
                })
            end
        end
    end

    return rooms
end

-- ============================================================
-- AutoDoors
-- ============================================================

local function runAutoDoors()
    local rooms = detectRooms()
    if #rooms == 0 then
        setStatusMessage("No rooms found! Draw floor tiles to create rooms first.")
        return
    end
    state.rooms = rooms
    RpgDungeon.addDoors(state.grid, rooms)
    setStatusMessage("AutoDoors: placed doors for " .. #rooms .. " room(s) (max 2 per room)")
end

-- ============================================================
-- Save/Load Functions
-- ============================================================

local function refreshMapList()
    state.savedMaps = {}
    love.filesystem.createDirectory("maps")
    local items = love.filesystem.getDirectoryItems("maps")
    for _, filename in ipairs(items) do
        if filename:match("%.lua$") then
            local path = "maps/" .. filename
            local ok, chunk = pcall(love.filesystem.load, path)
            if ok and chunk then
                local success, data = pcall(chunk)
                if success and type(data) == "table" then
                    table.insert(state.savedMaps, {
                        filename = filename,
                        path = path,
                        name = data.name or filename,
                        width = data.width or 0,
                        height = data.height or 0,
                    })
                end
            end
        end
    end
end

local function saveMap()
    love.filesystem.createDirectory("maps")

    local safeName = sanitizeFilename(state.mapName)

    -- Flatten grid to row-major array
    local tiles = {}
    for y = 1, state.gridHeight do
        for x = 1, state.gridWidth do
            if state.grid[y] and state.grid[y][x] then
                table.insert(tiles, '"' .. state.grid[y][x].type .. '"')
            else
                table.insert(tiles, '"wall"')
            end
        end
    end

    local content = "return {\n"
    content = content .. '    version = 1,\n'
    content = content .. '    name = "' .. state.mapName:gsub('"', '\\"') .. '",\n'
    content = content .. '    width = ' .. state.gridWidth .. ',\n'
    content = content .. '    height = ' .. state.gridHeight .. ',\n'
    content = content .. '    tiles = { ' .. table.concat(tiles, ", ") .. ' },\n'
    content = content .. '}\n'

    local path = "maps/" .. safeName .. ".lua"
    local success, err = love.filesystem.write(path, content)
    if success then
        setStatusMessage("Map saved: " .. path)
    else
        setStatusMessage("Save failed: " .. tostring(err))
    end

    refreshMapList()
end

local function loadMap(filename)
    local path = "maps/" .. filename
    local ok, chunk = pcall(love.filesystem.load, path)
    if not ok or not chunk then
        setStatusMessage("Failed to load: " .. tostring(chunk))
        return
    end

    local success, data = pcall(chunk)
    if not success or type(data) ~= "table" then
        setStatusMessage("Invalid map file: " .. filename)
        return
    end

    local w = data.width or 30
    local h = data.height or 25
    state.grid = createEmptyGrid(w, h)

    if data.tiles then
        local idx = 1
        for y = 1, h do
            for x = 1, w do
                if data.tiles[idx] then
                    state.grid[y][x].type = data.tiles[idx]
                end
                idx = idx + 1
            end
        end
    end

    state.mapName = data.name or "Untitled"
    state.nameInputText = state.mapName

    -- Center camera on loaded map
    local screenW, screenH = love.graphics.getDimensions()
    local canvasW = screenW - state.paletteWidth
    local canvasH = screenH - state.toolbarHeight - state.statusBarHeight
    state.cameraX = (canvasW / state.zoom - w * CELL_SIZE) / 2
    state.cameraY = (canvasH / state.zoom - h * CELL_SIZE) / 2

    state.showLoadDialog = false
    setStatusMessage("Loaded: " .. state.mapName .. " (" .. w .. "x" .. h .. ")")
end

-- ============================================================
-- Play Function
-- ============================================================

local function playMap()
    -- Validate: check for entrance and exit tiles
    local hasEntrance = false
    local hasExit = false

    for y = 1, state.gridHeight do
        for x = 1, state.gridWidth do
            if state.grid[y] and state.grid[y][x] then
                local t = state.grid[y][x].type
                if t == "entrance" or t == "stairs_up" then
                    hasEntrance = true
                end
                if t == "exit" or t == "stairs_down" then
                    hasExit = true
                end
            end
        end
    end

    if not hasEntrance then
        setStatusMessage("Cannot play: place an Entrance or Stairs Up tile!")
        return
    end
    if not hasExit then
        setStatusMessage("Cannot play: place an Exit or Stairs Down tile!")
        return
    end

    -- Deep copy the grid so the editor's copy is not mutated
    local gridCopy = {}
    for y = 1, state.gridHeight do
        gridCopy[y] = {}
        for x = 1, state.gridWidth do
            gridCopy[y][x] = {
                type = state.grid[y][x].type,
                explored = false,
            }
        end
    end

    local result = RpgDungeon.enterCustomDungeon(gridCopy, state.gridWidth, state.gridHeight, state.mapName)
    if result then
        GameState.current = "textrpg"
    else
        setStatusMessage("Failed to enter dungeon - check entrance/exit tiles!")
    end
end

-- ============================================================
-- Drawing Helpers
-- ============================================================

-- Track button rectangles for hit testing
local buttons = {}

local function clearButtons()
    buttons = {}
end

local function registerButton(id, x, y, w, h)
    table.insert(buttons, {id = id, x = x, y = y, w = w, h = h})
end

local function isPointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px < rx + rw and py >= ry and py < ry + rh
end

local function getHoveredButton(mx, my)
    for _, btn in ipairs(buttons) do
        if isPointInRect(mx, my, btn.x, btn.y, btn.w, btn.h) then
            return btn.id
        end
    end
    return nil
end

local function drawButton(x, y, w, h, text, hovered, activeColor)
    local bgColor = activeColor or {0.25, 0.25, 0.3}
    if hovered then
        love.graphics.setColor(bgColor[1] + 0.1, bgColor[2] + 0.1, bgColor[3] + 0.1)
    else
        love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3])
    end
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)

    -- Border
    love.graphics.setColor(0.4, 0.4, 0.45)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)

    -- Text centered
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fontMedium)
    local tw = fontMedium:getWidth(text)
    local th = fontMedium:getHeight()
    love.graphics.print(text, math.floor(x + (w - tw) / 2), math.floor(y + (h - th) / 2))
end

-- ============================================================
-- Init
-- ============================================================

function MapEditor.init()
    ensureFonts()
    buildTileCache()

    state.active = true
    state.grid = createEmptyGrid(30, 25)
    state.selectedTile = "floor"
    state.mapName = "Untitled"
    state.nameInputText = "Untitled"
    state.editingName = false
    state.tool = "paint"
    state.painting = false
    state.zoom = 1.0
    state.showLoadDialog = false
    state.showResizeDialog = false
    state.resizeW = 30
    state.resizeH = 25
    state.paletteScroll = 0
    state.loadDialogScroll = 0
    state.statusMessage = ""
    state.statusMessageTime = 0

    -- Center camera
    local screenW, screenH = love.graphics.getDimensions()
    local canvasW = screenW - state.paletteWidth
    local canvasH = screenH - state.toolbarHeight - state.statusBarHeight
    state.cameraX = (canvasW / state.zoom - state.gridWidth * CELL_SIZE) / 2
    state.cameraY = (canvasH / state.zoom - state.gridHeight * CELL_SIZE) / 2

    refreshMapList()

    setStatusMessage("Map Editor ready. Click tiles in palette, then paint on grid.")
end

-- ============================================================
-- Update
-- ============================================================

function MapEditor.update(dt)
    if not state.active then return end

    -- Arrow key scrolling
    local speed = state.scrollSpeed * dt / state.zoom
    if love.keyboard.isDown("up") then
        state.cameraY = state.cameraY + speed
    end
    if love.keyboard.isDown("down") then
        state.cameraY = state.cameraY - speed
    end
    if love.keyboard.isDown("left") then
        state.cameraX = state.cameraX + speed
    end
    if love.keyboard.isDown("right") then
        state.cameraX = state.cameraX - speed
    end

    -- Fade status message
    if state.statusMessageTime > 0 then
        state.statusMessageTime = state.statusMessageTime - dt
    end

    -- Track hovered grid tile
    local mx, my = love.mouse.getPosition()
    state.hoveredTileX, state.hoveredTileY = screenToGrid(mx, my)

    -- Continuous painting while mouse held
    if state.painting and state.hoveredTileX then
        paintTile(state.hoveredTileX, state.hoveredTileY)
    end
end

-- ============================================================
-- Load Dialog Drawing
-- ============================================================

local function drawLoadDialog(screenW, screenH, mx, my)
    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Dialog panel
    local dlgW, dlgH = 400, 450
    local dlgX = math.floor((screenW - dlgW) / 2)
    local dlgY = math.floor((screenH - dlgH) / 2)

    love.graphics.setColor(0.18, 0.18, 0.22)
    love.graphics.rectangle("fill", dlgX, dlgY, dlgW, dlgH, 6, 6)
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.rectangle("line", dlgX, dlgY, dlgW, dlgH, 6, 6)

    -- Title
    love.graphics.setFont(fontLarge)
    love.graphics.setColor(0.9, 0.9, 0.95)
    love.graphics.print("Load Map", dlgX + 16, dlgY + 12)

    -- Map list
    local listY = dlgY + 44
    local listH = dlgH - 100
    local rowH = 36

    love.graphics.setScissor(dlgX + 8, listY, dlgW - 16, listH)

    if #state.savedMaps == 0 then
        love.graphics.setFont(fontMedium)
        love.graphics.setColor(0.5, 0.5, 0.55)
        love.graphics.print("No saved maps found.", dlgX + 16, listY + 10)
    else
        local maxScroll = math.max(0, #state.savedMaps * rowH - listH)
        state.loadDialogScroll = clamp(state.loadDialogScroll, 0, maxScroll)

        for i, mapInfo in ipairs(state.savedMaps) do
            local rowY = listY + (i - 1) * rowH - state.loadDialogScroll
            if rowY + rowH > listY and rowY < listY + listH then
                local isHovered = isPointInRect(mx, my, dlgX + 8, rowY, dlgW - 16, rowH)

                if isHovered then
                    love.graphics.setColor(0.25, 0.28, 0.35)
                    love.graphics.rectangle("fill", dlgX + 8, rowY, dlgW - 16, rowH, 3, 3)
                end

                love.graphics.setFont(fontMedium)
                love.graphics.setColor(0.9, 0.9, 0.9)
                love.graphics.print(mapInfo.name, dlgX + 18, rowY + 4)

                love.graphics.setFont(fontSmall)
                love.graphics.setColor(0.55, 0.55, 0.6)
                love.graphics.print(mapInfo.width .. "x" .. mapInfo.height .. "  [" .. mapInfo.filename .. "]",
                    dlgX + 18, rowY + 20)

                registerButton("load_" .. i, dlgX + 8, rowY, dlgW - 16, rowH)
            end
        end
    end

    love.graphics.setScissor()

    -- Cancel button
    local cancelW, cancelH = 100, 32
    local cancelX = dlgX + math.floor((dlgW - cancelW) / 2)
    local cancelY = dlgY + dlgH - 46
    registerButton("load_cancel", cancelX, cancelY, cancelW, cancelH)
    local hoveredBtn = getHoveredButton(mx, my)
    drawButton(cancelX, cancelY, cancelW, cancelH, "Cancel",
        hoveredBtn == "load_cancel", {0.35, 0.25, 0.25})
end

-- ============================================================
-- Resize Dialog Drawing
-- ============================================================

local function drawResizeDialog(screenW, screenH, mx, my)
    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Dialog panel
    local dlgW, dlgH = 300, 220
    local dlgX = math.floor((screenW - dlgW) / 2)
    local dlgY = math.floor((screenH - dlgH) / 2)

    love.graphics.setColor(0.18, 0.18, 0.22)
    love.graphics.rectangle("fill", dlgX, dlgY, dlgW, dlgH, 6, 6)
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.rectangle("line", dlgX, dlgY, dlgW, dlgH, 6, 6)

    -- Title
    love.graphics.setFont(fontLarge)
    love.graphics.setColor(0.9, 0.9, 0.95)
    love.graphics.print("Resize Grid", dlgX + 16, dlgY + 12)

    local hoveredBtn = getHoveredButton(mx, my)
    local rowY = dlgY + 50
    local btnSize = 32

    -- Width row
    love.graphics.setFont(fontMedium)
    love.graphics.setColor(0.8, 0.8, 0.85)
    love.graphics.print("Width:", dlgX + 20, rowY + 6)

    registerButton("resize_w_minus", dlgX + 100, rowY, btnSize, btnSize)
    drawButton(dlgX + 100, rowY, btnSize, btnSize, "-", hoveredBtn == "resize_w_minus")

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fontLarge)
    local wStr = tostring(state.resizeW)
    local wStrW = fontLarge:getWidth(wStr)
    love.graphics.print(wStr, dlgX + 145 + math.floor((40 - wStrW) / 2), rowY + 5)

    registerButton("resize_w_plus", dlgX + 195, rowY, btnSize, btnSize)
    drawButton(dlgX + 195, rowY, btnSize, btnSize, "+", hoveredBtn == "resize_w_plus")

    -- Range label
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(0.45, 0.45, 0.5)
    love.graphics.print("(10-80)", dlgX + 235, rowY + 8)

    -- Height row
    rowY = rowY + 48
    love.graphics.setFont(fontMedium)
    love.graphics.setColor(0.8, 0.8, 0.85)
    love.graphics.print("Height:", dlgX + 20, rowY + 6)

    registerButton("resize_h_minus", dlgX + 100, rowY, btnSize, btnSize)
    drawButton(dlgX + 100, rowY, btnSize, btnSize, "-", hoveredBtn == "resize_h_minus")

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(fontLarge)
    local hStr = tostring(state.resizeH)
    local hStrW = fontLarge:getWidth(hStr)
    love.graphics.print(hStr, dlgX + 145 + math.floor((40 - hStrW) / 2), rowY + 5)

    registerButton("resize_h_plus", dlgX + 195, rowY, btnSize, btnSize)
    drawButton(dlgX + 195, rowY, btnSize, btnSize, "+", hoveredBtn == "resize_h_plus")

    love.graphics.setFont(fontSmall)
    love.graphics.setColor(0.45, 0.45, 0.5)
    love.graphics.print("(10-60)", dlgX + 235, rowY + 8)

    -- Apply and Cancel buttons
    local actionY = dlgY + dlgH - 52
    local actionBtnW = 100
    local actionBtnH = 34

    registerButton("resize_apply", dlgX + 40, actionY, actionBtnW, actionBtnH)
    drawButton(dlgX + 40, actionY, actionBtnW, actionBtnH, "Apply",
        hoveredBtn == "resize_apply", {0.2, 0.4, 0.3})

    registerButton("resize_cancel", dlgX + 160, actionY, actionBtnW, actionBtnH)
    drawButton(dlgX + 160, actionY, actionBtnW, actionBtnH, "Cancel",
        hoveredBtn == "resize_cancel", {0.4, 0.25, 0.25})
end

-- ============================================================
-- Draw
-- ============================================================

function MapEditor.draw()
    if not state.active then return end
    ensureFonts()

    local screenW, screenH = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()
    local hoveredBtn = getHoveredButton(mx, my)

    clearButtons()

    -- Background
    love.graphics.setColor(0.12, 0.12, 0.14)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- ========================================
    -- Toolbar (top bar)
    -- ========================================
    local tbH = state.toolbarHeight
    love.graphics.setColor(0.15, 0.15, 0.18)
    love.graphics.rectangle("fill", 0, 0, screenW, tbH)
    love.graphics.setColor(0.3, 0.3, 0.35)
    love.graphics.line(0, tbH, screenW, tbH)

    -- Toolbar buttons
    local btnW, btnH = 80, 35
    local btnY = math.floor((tbH - btnH) / 2)
    local btnX = 8
    local gap = 8

    local toolbarButtons = {
        {id = "new",       text = "New"},
        {id = "save",      text = "Save"},
        {id = "load",      text = "Load"},
        {id = "play",      text = "Play",      color = {0.2, 0.45, 0.2}},
        {id = "autodoors", text = "AutoDoors"},
        {id = "clear",     text = "Clear",     color = {0.45, 0.2, 0.2}},
        {id = "grid",      text = "Grid"},
    }

    for _, btn in ipairs(toolbarButtons) do
        local bw = btn.text == "AutoDoors" and 90 or btnW
        registerButton(btn.id, btnX, btnY, bw, btnH)
        drawButton(btnX, btnY, bw, btnH, btn.text, hoveredBtn == btn.id, btn.color)
        btnX = btnX + bw + gap
    end

    -- Map name field on right side of toolbar
    local nameFieldW = 200
    local nameFieldX = screenW - nameFieldW - 12
    local nameFieldY = btnY
    local nameFieldH = btnH

    registerButton("namefield", nameFieldX, nameFieldY, nameFieldW, nameFieldH)

    -- Name field background
    if state.editingName then
        love.graphics.setColor(0.2, 0.2, 0.25)
    else
        love.graphics.setColor(0.18, 0.18, 0.22)
    end
    love.graphics.rectangle("fill", nameFieldX, nameFieldY, nameFieldW, nameFieldH, 4, 4)
    love.graphics.setColor(state.editingName and {0.5, 0.6, 0.8} or {0.35, 0.35, 0.4})
    love.graphics.rectangle("line", nameFieldX, nameFieldY, nameFieldW, nameFieldH, 4, 4)

    -- Name text
    love.graphics.setFont(fontMedium)
    love.graphics.setColor(0.5, 0.5, 0.55)
    love.graphics.print("Name:", nameFieldX - 48, nameFieldY + math.floor((nameFieldH - fontMedium:getHeight()) / 2))

    love.graphics.setColor(1, 1, 1)
    local displayName = state.editingName and state.nameInputText or state.mapName
    -- Clip text to field width
    local nameText = displayName
    while fontMedium:getWidth(nameText) > nameFieldW - 12 and #nameText > 0 do
        nameText = nameText:sub(2)
    end
    love.graphics.print(nameText, nameFieldX + 6, nameFieldY + math.floor((nameFieldH - fontMedium:getHeight()) / 2))

    -- Cursor blink for editing
    if state.editingName then
        local cursorBlink = math.floor(love.timer.getTime() * 2) % 2 == 0
        if cursorBlink then
            local cursorX = nameFieldX + 6 + fontMedium:getWidth(state.nameInputText)
            cursorX = math.min(cursorX, nameFieldX + nameFieldW - 6)
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.rectangle("fill", cursorX, nameFieldY + 4, 2, nameFieldH - 8)
        end
    end

    -- ========================================
    -- Tile Palette (left sidebar)
    -- ========================================
    local palW = state.paletteWidth
    local palY = tbH
    local palH = screenH - tbH - state.statusBarHeight

    love.graphics.setColor(0.16, 0.16, 0.19)
    love.graphics.rectangle("fill", 0, palY, palW, palH)
    love.graphics.setColor(0.3, 0.3, 0.35)
    love.graphics.line(palW, palY, palW, palY + palH)

    -- Title
    love.graphics.setFont(fontLarge)
    love.graphics.setColor(0.8, 0.8, 0.85)
    love.graphics.print("Tiles", 10, palY + 6)

    -- Tile list
    local tileRowH = 28
    local tileStartY = palY + 32
    local tileTypes = Data.DUNGEON_TILE_TYPES
    local totalTileHeight = #tileTypes * tileRowH

    -- Clipping for palette scroll
    love.graphics.setScissor(0, tileStartY, palW, palH - 32 - 70) -- Leave room for tool buttons at bottom

    local maxScroll = math.max(0, totalTileHeight - (palH - 32 - 70))
    state.paletteScroll = clamp(state.paletteScroll, 0, maxScroll)

    for i, tileType in ipairs(tileTypes) do
        local rowY = tileStartY + (i - 1) * tileRowH - state.paletteScroll
        local rowVisible = rowY + tileRowH > tileStartY and rowY < tileStartY + palH - 32 - 70

        if rowVisible then
            local isSelected = (state.selectedTile == tileType.id)
            local isHovered = isPointInRect(mx, my, 0, rowY, palW, tileRowH)

            -- Background highlight
            if isSelected then
                love.graphics.setColor(0.25, 0.3, 0.4, 0.8)
                love.graphics.rectangle("fill", 2, rowY, palW - 4, tileRowH, 3, 3)
            elseif isHovered then
                love.graphics.setColor(0.22, 0.22, 0.26)
                love.graphics.rectangle("fill", 2, rowY, palW - 4, tileRowH, 3, 3)
            end

            -- Selection border
            if isSelected then
                love.graphics.setColor(0.5, 0.7, 1.0, 0.9)
                love.graphics.rectangle("line", 2, rowY, palW - 4, tileRowH, 3, 3)
            end

            -- Color swatch
            local col = tileType.color
            love.graphics.setColor(col[1], col[2], col[3])
            love.graphics.rectangle("fill", 8, rowY + 4, 20, 20, 2, 2)
            love.graphics.setColor(0.5, 0.5, 0.55)
            love.graphics.rectangle("line", 8, rowY + 4, 20, 20, 2, 2)

            -- Icon in swatch
            love.graphics.setFont(fontSmall)
            love.graphics.setColor(1, 1, 1)
            local iconW = fontSmall:getWidth(tileType.icon)
            love.graphics.print(tileType.icon, 8 + math.floor((20 - iconW) / 2), rowY + 6)

            -- Name
            love.graphics.setFont(fontSmall)
            love.graphics.setColor(0.85, 0.85, 0.88)
            love.graphics.print(tileType.name, 34, rowY + 7)

            -- Register for click detection
            registerButton("tile_" .. tileType.id, 0, rowY, palW, tileRowH)
        end
    end

    love.graphics.setScissor()

    -- Tool buttons at bottom of palette
    local toolBtnY = palY + palH - 64
    local toolBtnW = (palW - 16) / 2
    local toolBtnH = 28

    -- Paint tool
    local paintActive = (state.tool == "paint")
    registerButton("tool_paint", 4, toolBtnY, toolBtnW, toolBtnH)
    drawButton(4, toolBtnY, toolBtnW, toolBtnH, "Paint",
        hoveredBtn == "tool_paint", paintActive and {0.2, 0.4, 0.6} or nil)

    -- Erase tool
    local eraseActive = (state.tool == "erase")
    registerButton("tool_erase", 4 + toolBtnW + 8, toolBtnY, toolBtnW, toolBtnH)
    drawButton(4 + toolBtnW + 8, toolBtnY, toolBtnW, toolBtnH, "Erase",
        hoveredBtn == "tool_erase", eraseActive and {0.5, 0.25, 0.25} or nil)

    -- Tool label
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(0.5, 0.5, 0.55)
    love.graphics.print("Tools:", 8, toolBtnY - 16)

    -- ========================================
    -- Grid Canvas (main area)
    -- ========================================
    local canvasX = state.paletteWidth
    local canvasY = state.toolbarHeight
    local canvasW = screenW - state.paletteWidth
    local canvasH = screenH - state.toolbarHeight - state.statusBarHeight

    -- Clip to canvas area
    love.graphics.setScissor(canvasX, canvasY, canvasW, canvasH)

    -- Apply camera transform
    love.graphics.push()
    love.graphics.translate(canvasX, canvasY)
    love.graphics.scale(state.zoom, state.zoom)
    love.graphics.translate(state.cameraX, state.cameraY)

    -- Calculate visible tile range for culling
    local visMinX = math.max(1, math.floor(-state.cameraX / CELL_SIZE))
    local visMinY = math.max(1, math.floor(-state.cameraY / CELL_SIZE))
    local visMaxX = math.min(state.gridWidth, math.ceil((-state.cameraX + canvasW / state.zoom) / CELL_SIZE) + 1)
    local visMaxY = math.min(state.gridHeight, math.ceil((-state.cameraY + canvasH / state.zoom) / CELL_SIZE) + 1)

    -- Draw tiles
    love.graphics.setFont(fontIcon)
    for y = visMinY, visMaxY do
        for x = visMinX, visMaxX do
            if state.grid[y] and state.grid[y][x] then
                local tile = state.grid[y][x]
                local px = (x - 1) * CELL_SIZE
                local py = (y - 1) * CELL_SIZE

                -- Tile fill
                local col = getTileColor(tile.type)
                love.graphics.setColor(col[1], col[2], col[3])
                love.graphics.rectangle("fill", px, py, CELL_SIZE, CELL_SIZE)

                -- Grid lines
                love.graphics.setColor(0.2, 0.2, 0.22, 0.5)
                love.graphics.rectangle("line", px, py, CELL_SIZE, CELL_SIZE)

                -- Tile icon
                local icon = getTileIcon(tile.type)
                if tile.type ~= "wall" then
                    love.graphics.setColor(1, 1, 1, 0.7)
                    local iw = fontIcon:getWidth(icon)
                    local ih = fontIcon:getHeight()
                    love.graphics.print(icon, px + math.floor((CELL_SIZE - iw) / 2),
                                             py + math.floor((CELL_SIZE - ih) / 2))
                end
            end
        end
    end

    -- Highlight hovered tile
    if state.hoveredTileX and state.hoveredTileY then
        local hx = (state.hoveredTileX - 1) * CELL_SIZE
        local hy = (state.hoveredTileY - 1) * CELL_SIZE
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.setLineWidth(2 / state.zoom)
        love.graphics.rectangle("line", hx, hy, CELL_SIZE, CELL_SIZE)
        love.graphics.setLineWidth(1)

        -- Show selected tile preview when painting
        if state.tool == "paint" then
            local prevCol = getTileColor(state.selectedTile)
            love.graphics.setColor(prevCol[1], prevCol[2], prevCol[3], 0.4)
            love.graphics.rectangle("fill", hx, hy, CELL_SIZE, CELL_SIZE)
        end
    end

    love.graphics.pop()
    love.graphics.setScissor()

    -- ========================================
    -- Status Bar (bottom)
    -- ========================================
    local sbY = screenH - state.statusBarHeight
    love.graphics.setColor(0.15, 0.15, 0.18)
    love.graphics.rectangle("fill", 0, sbY, screenW, state.statusBarHeight)
    love.graphics.setColor(0.3, 0.3, 0.35)
    love.graphics.line(0, sbY, screenW, sbY)

    love.graphics.setFont(fontSmall)
    local sbTextY = sbY + math.floor((state.statusBarHeight - fontSmall:getHeight()) / 2)

    -- Tool info
    love.graphics.setColor(0.6, 0.7, 0.8)
    local toolName = state.tool == "paint" and "Paint" or "Erase"
    love.graphics.print("Tool: " .. toolName, 10, sbTextY)

    -- Selected tile
    local tileDef = tileTypeCache[state.selectedTile]
    local tileName = tileDef and tileDef.name or state.selectedTile
    love.graphics.setColor(0.7, 0.7, 0.75)
    love.graphics.print("Tile: " .. tileName, 120, sbTextY)

    -- Grid dimensions
    love.graphics.setColor(0.6, 0.6, 0.65)
    love.graphics.print("Grid: " .. state.gridWidth .. "x" .. state.gridHeight, 280, sbTextY)

    -- Cursor position
    if state.hoveredTileX and state.hoveredTileY then
        love.graphics.setColor(0.6, 0.6, 0.65)
        love.graphics.print("Pos: " .. state.hoveredTileX .. ", " .. state.hoveredTileY, 400, sbTextY)
    end

    -- Zoom level
    love.graphics.setColor(0.5, 0.5, 0.55)
    love.graphics.print("Zoom: " .. string.format("%.0f%%", state.zoom * 100), 510, sbTextY)

    -- Status message
    if state.statusMessageTime > 0 then
        local alpha = math.min(1.0, state.statusMessageTime)
        love.graphics.setColor(0.9, 0.85, 0.4, alpha)
        local msgW = fontSmall:getWidth(state.statusMessage)
        love.graphics.print(state.statusMessage, screenW - msgW - 12, sbTextY)
    end

    -- ========================================
    -- Load Dialog (overlay)
    -- ========================================
    if state.showLoadDialog then
        drawLoadDialog(screenW, screenH, mx, my)
    end

    -- ========================================
    -- Resize Dialog (overlay)
    -- ========================================
    if state.showResizeDialog then
        drawResizeDialog(screenW, screenH, mx, my)
    end

    -- Reset color
    love.graphics.setColor(1, 1, 1)
end

-- ============================================================
-- Input: Mouse
-- ============================================================

function MapEditor.mousepressed(x, y, button)
    if not state.active then return end

    local hoveredBtn = getHoveredButton(x, y)

    if button == 1 then
        -- Handle dialogs first
        if state.showLoadDialog then
            if hoveredBtn == "load_cancel" then
                state.showLoadDialog = false
                return
            end
            -- Check map load clicks
            if hoveredBtn then
                local idx = hoveredBtn:match("^load_(%d+)$")
                if idx then
                    idx = tonumber(idx)
                    if state.savedMaps[idx] then
                        loadMap(state.savedMaps[idx].filename)
                    end
                    return
                end
            end
            return -- Consume click when load dialog is open
        end

        if state.showResizeDialog then
            if hoveredBtn == "resize_w_minus" then
                state.resizeW = math.max(10, state.resizeW - 5)
                return
            elseif hoveredBtn == "resize_w_plus" then
                state.resizeW = math.min(80, state.resizeW + 5)
                return
            elseif hoveredBtn == "resize_h_minus" then
                state.resizeH = math.max(10, state.resizeH - 5)
                return
            elseif hoveredBtn == "resize_h_plus" then
                state.resizeH = math.min(60, state.resizeH + 5)
                return
            elseif hoveredBtn == "resize_apply" then
                state.grid = createEmptyGrid(state.resizeW, state.resizeH)
                state.showResizeDialog = false
                -- Recenter camera
                local screenW, screenH = love.graphics.getDimensions()
                local canvasW = screenW - state.paletteWidth
                local canvasH = screenH - state.toolbarHeight - state.statusBarHeight
                state.cameraX = (canvasW / state.zoom - state.gridWidth * CELL_SIZE) / 2
                state.cameraY = (canvasH / state.zoom - state.gridHeight * CELL_SIZE) / 2
                setStatusMessage("Grid resized to " .. state.gridWidth .. "x" .. state.gridHeight)
                return
            elseif hoveredBtn == "resize_cancel" then
                state.showResizeDialog = false
                return
            end
            return -- Consume click when resize dialog is open
        end

        -- Stop editing name if clicking elsewhere
        if state.editingName and hoveredBtn ~= "namefield" then
            state.editingName = false
            state.mapName = state.nameInputText
            if state.mapName == "" then
                state.mapName = "Untitled"
                state.nameInputText = "Untitled"
            end
        end

        -- Toolbar buttons
        if hoveredBtn == "new" then
            state.grid = createEmptyGrid(state.gridWidth, state.gridHeight)
            state.mapName = "Untitled"
            state.nameInputText = "Untitled"
            -- Recenter camera
            local screenW, screenH = love.graphics.getDimensions()
            local canvasW = screenW - state.paletteWidth
            local canvasH = screenH - state.toolbarHeight - state.statusBarHeight
            state.cameraX = (canvasW / state.zoom - state.gridWidth * CELL_SIZE) / 2
            state.cameraY = (canvasH / state.zoom - state.gridHeight * CELL_SIZE) / 2
            setStatusMessage("New map created")
            return
        elseif hoveredBtn == "save" then
            saveMap()
            return
        elseif hoveredBtn == "load" then
            refreshMapList()
            state.showLoadDialog = true
            state.loadDialogScroll = 0
            return
        elseif hoveredBtn == "play" then
            playMap()
            return
        elseif hoveredBtn == "autodoors" then
            runAutoDoors()
            return
        elseif hoveredBtn == "clear" then
            for gy = 1, state.gridHeight do
                for gx = 1, state.gridWidth do
                    if state.grid[gy] and state.grid[gy][gx] then
                        state.grid[gy][gx].type = "wall"
                    end
                end
            end
            setStatusMessage("Grid cleared to walls")
            return
        elseif hoveredBtn == "grid" then
            state.showResizeDialog = not state.showResizeDialog
            state.resizeW = state.gridWidth
            state.resizeH = state.gridHeight
            return
        elseif hoveredBtn == "namefield" then
            state.editingName = true
            return
        end

        -- Palette tile selection
        if hoveredBtn then
            local tileId = hoveredBtn:match("^tile_(.+)$")
            if tileId then
                state.selectedTile = tileId
                return
            end
        end

        -- Tool selection
        if hoveredBtn == "tool_paint" then
            state.tool = "paint"
            return
        elseif hoveredBtn == "tool_erase" then
            state.tool = "erase"
            return
        end

        -- Grid painting
        local gx, gy = screenToGrid(x, y)
        if gx and gy then
            state.painting = true
            paintTile(gx, gy)
            return
        end

    elseif button == 2 then
        -- Right click: quick erase (paint wall regardless of tool)
        local gx, gy = screenToGrid(x, y)
        if gx and gy then
            if state.grid[gy] and state.grid[gy][gx] then
                state.grid[gy][gx].type = "wall"
            end
        end
    end
end

function MapEditor.mousereleased(x, y, button)
    if not state.active then return end
    if button == 1 then
        state.painting = false
    end
end

-- ============================================================
-- Input: Keyboard
-- ============================================================

function MapEditor.keypressed(key)
    if not state.active then return end

    -- Text editing mode
    if state.editingName then
        if key == "escape" then
            state.editingName = false
            state.nameInputText = state.mapName -- Revert
            return
        elseif key == "return" or key == "kpenter" then
            state.editingName = false
            state.mapName = state.nameInputText
            if state.mapName == "" then
                state.mapName = "Untitled"
                state.nameInputText = "Untitled"
            end
            return
        elseif key == "backspace" then
            if #state.nameInputText > 0 then
                -- Remove last UTF-8 character
                local byteoffset = utf8.offset(state.nameInputText, -1)
                if byteoffset then
                    state.nameInputText = state.nameInputText:sub(1, byteoffset - 1)
                end
            end
            return
        end
        return -- Consume all other keys while editing name
    end

    -- Close dialogs
    if key == "escape" then
        if state.showLoadDialog then
            state.showLoadDialog = false
            return
        elseif state.showResizeDialog then
            state.showResizeDialog = false
            return
        else
            -- Return to menu
            state.active = false
            GameState.current = "menu"
            return
        end
    end

    -- Ctrl+S: save
    if key == "s" and (love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")) then
        saveMap()
        return
    end

    -- E: toggle eraser
    if key == "e" then
        if state.tool == "erase" then
            state.tool = "paint"
        else
            state.tool = "erase"
        end
        setStatusMessage("Tool: " .. (state.tool == "paint" and "Paint" or "Erase"))
        return
    end

    -- G: toggle resize dialog
    if key == "g" then
        state.showResizeDialog = not state.showResizeDialog
        state.resizeW = state.gridWidth
        state.resizeH = state.gridHeight
        return
    end
end

function MapEditor.keyreleased(key)
    -- Nothing special needed
end

-- ============================================================
-- Input: Text
-- ============================================================

function MapEditor.textinput(text)
    if not state.active then return end

    if state.editingName then
        -- Limit name length
        if #state.nameInputText < 40 then
            state.nameInputText = state.nameInputText .. text
        end
    end
end

-- ============================================================
-- Input: Mouse Wheel
-- ============================================================

function MapEditor.wheelmoved(x, y)
    if not state.active then return end

    -- If load dialog is open, scroll the list
    if state.showLoadDialog then
        state.loadDialogScroll = state.loadDialogScroll - y * 30
        return
    end

    -- If mouse is over palette, scroll palette
    local mx, my = love.mouse.getPosition()
    if mx < state.paletteWidth and my > state.toolbarHeight then
        state.paletteScroll = state.paletteScroll - y * 20
        return
    end

    -- Zoom toward mouse position
    local oldZoom = state.zoom
    state.zoom = clamp(state.zoom + y * 0.1, state.minZoom, state.maxZoom)

    if state.zoom ~= oldZoom then
        -- Adjust camera to zoom toward mouse cursor
        local canvasX = state.paletteWidth
        local canvasY = state.toolbarHeight

        local localMX = mx - canvasX
        local localMY = my - canvasY

        -- World position under mouse before zoom
        local worldX = localMX / oldZoom - state.cameraX
        local worldY = localMY / oldZoom - state.cameraY

        -- Adjust camera so same world position stays under mouse
        state.cameraX = localMX / state.zoom - worldX
        state.cameraY = localMY / state.zoom - worldY
    end
end

return MapEditor
