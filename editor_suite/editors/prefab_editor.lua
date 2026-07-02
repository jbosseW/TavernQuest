-- ==========================================================================
-- Prefab Editor for Tavern Quest Editor Suite
-- Small tile grids (max 20x20) with entity placement and tags.
-- ==========================================================================

local Theme    = require("core.theme")
local FontCache = require("core.fontcache")
local UI       = require("core.ui")
local UndoStack = require("core.undo")

local Editor = {}

-- =========================================================================
-- Constants
-- =========================================================================

local LEFT_PANEL_W  = 240
local RIGHT_PANEL_W = 220
local MAX_PREFAB_SIZE = 20
local MIN_PREFAB_SIZE = 1

local TILE_MODES = { "dungeon", "town" }

local DUNGEON_TILES = {
    { id = 0, name = "Empty/Void",  color = {0.10, 0.10, 0.12} },
    { id = 1, name = "Wall",        color = {0.40, 0.35, 0.30} },
    { id = 2, name = "Floor",       color = {0.55, 0.50, 0.42} },
    { id = 3, name = "Corridor",    color = {0.48, 0.44, 0.38} },
    { id = 4, name = "Door",        color = {0.60, 0.40, 0.20} },
    { id = 5, name = "Stairs Up",   color = {0.30, 0.70, 0.50} },
    { id = 6, name = "Stairs Down", color = {0.70, 0.30, 0.30} },
    { id = 7, name = "Chest",       color = {0.85, 0.75, 0.20} },
    { id = 8, name = "Trap",        color = {0.80, 0.20, 0.20} },
    { id = 9, name = "Water",       color = {0.20, 0.40, 0.80} },
    { id = 10, name = "Lava",       color = {0.90, 0.30, 0.05} },
    { id = 11, name = "Pillar",     color = {0.50, 0.50, 0.55} },
    { id = 12, name = "Altar",      color = {0.70, 0.50, 0.80} },
}

local TOWN_TILES = {
    { id = 0, name = "Grass",         color = {0.30, 0.60, 0.25} },
    { id = 1, name = "Road",          color = {0.55, 0.50, 0.40} },
    { id = 2, name = "Building Floor",color = {0.60, 0.55, 0.45} },
    { id = 3, name = "Wall",          color = {0.45, 0.40, 0.35} },
    { id = 4, name = "Door",          color = {0.60, 0.40, 0.20} },
    { id = 5, name = "Water",         color = {0.20, 0.40, 0.80} },
    { id = 6, name = "Bridge",        color = {0.55, 0.45, 0.30} },
    { id = 7, name = "Fence",         color = {0.50, 0.42, 0.30} },
    { id = 8, name = "Garden",        color = {0.25, 0.70, 0.30} },
    { id = 9, name = "Market Stall",  color = {0.75, 0.55, 0.25} },
    { id = 10, name = "Well",         color = {0.35, 0.50, 0.65} },
    { id = 11, name = "Tree",         color = {0.15, 0.50, 0.15} },
    { id = 12, name = "Decoration",   color = {0.65, 0.60, 0.75} },
}

local ENTITY_TYPES = {
    { type = "npc",        label = "NPC",        icon = "N", color = {0.30, 0.80, 0.90} },
    { type = "item",       label = "Item",       icon = "I", color = {0.90, 0.80, 0.20} },
    { type = "decoration", label = "Decoration", icon = "D", color = {0.70, 0.55, 0.80} },
}

-- =========================================================================
-- Helpers
-- =========================================================================

local function pointInRect(px, py, x, y, w, h)
    return px >= x and px < x + w and py >= y and py < y + h
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function deepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[deepCopy(k)] = deepCopy(v)
    end
    return copy
end

local function setColorSafe(c)
    if c and type(c) == "table" then
        love.graphics.setColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
    end
end

local function drawRoundedRect(mode, x, y, w, h, r)
    r = r or 0
    if w <= 0 or h <= 0 then return end
    if r <= 0 then
        love.graphics.rectangle(mode, x, y, w, h)
    else
        love.graphics.rectangle(mode, x, y, w, h, r, r)
    end
end

-- =========================================================================
-- Prefab data helpers
-- =========================================================================

local function createBlankPrefab(name)
    local prefab = {
        name = name or "New Prefab",
        width = 5,
        height = 5,
        tileMode = "dungeon",
        tiles = {},
        entities = {},
        tags = {},
    }
    -- Initialize tiles to 0 (empty)
    for y = 1, prefab.height do
        prefab.tiles[y] = {}
        for x = 1, prefab.width do
            prefab.tiles[y][x] = 0
        end
    end
    return prefab
end

local function resizePrefabTiles(prefab, newW, newH)
    local oldTiles = prefab.tiles or {}
    local newTiles = {}
    for y = 1, newH do
        newTiles[y] = {}
        for x = 1, newW do
            if oldTiles[y] and oldTiles[y][x] then
                newTiles[y][x] = oldTiles[y][x]
            else
                newTiles[y][x] = 0
            end
        end
    end
    return newTiles
end

local function getTilePalette(tileMode)
    if tileMode == "town" then
        return TOWN_TILES
    end
    return DUNGEON_TILES
end

local function getTileColor(tileMode, tileId)
    local palette = getTilePalette(tileMode)
    for _, tile in ipairs(palette) do
        if tile.id == tileId then
            return tile.color
        end
    end
    return {0.10, 0.10, 0.12}
end

-- =========================================================================
-- Editor constructor
-- =========================================================================

function Editor.new(project)
    local self = setmetatable({}, { __index = Editor })

    self.project = project
    self.prefabs = project.prefabs or {}
    if not project.prefabs then
        project.prefabs = self.prefabs
    end

    self.undoStack = UndoStack.new(100)

    -- Selection state
    self.selectedIndex = nil
    self.selectedPrefab = nil

    -- Tool state
    self.activeTool = "paint"   -- "paint" or "entity"
    self.selectedTileId = 0
    self.selectedEntityType = nil  -- ENTITY_TYPES entry

    -- Canvas state
    self.canvasOffsetX = 0
    self.canvasOffsetY = 0
    self.isPainting = false
    self.paintStrokeId = 0

    -- Left panel
    self.searchText = ""
    self.searchInput = UI.TextInput.new({
        placeholder = "Search prefabs...",
        fontSize = 12,
        onChange = function(text)
            self.searchText = text
        end,
    })
    self.tilePaletteScroll = UI.ScrollContainer.new({ contentHeight = 0 })
    self.entityPaletteScroll = UI.ScrollContainer.new({ contentHeight = 0 })
    self.prefabListScroll = UI.ScrollContainer.new({ contentHeight = 0 })

    -- Right panel
    self.nameInput = UI.TextInput.new({
        placeholder = "Prefab name",
        fontSize = 12,
        onChange = function(text)
            if self.selectedPrefab then
                self:_pushPropertyUndo("name", self.selectedPrefab.name, text)
                self.selectedPrefab.name = text
            end
        end,
    })
    self.tagInput = UI.TextInput.new({
        placeholder = "Add tag...",
        fontSize = 12,
        onSubmit = function(text)
            if self.selectedPrefab and text and text ~= "" then
                self:_addTag(text)
                self.tagInput:setText("")
            end
        end,
    })
    self.entityListScroll = UI.ScrollContainer.new({ contentHeight = 0 })
    self.tagListScroll = UI.ScrollContainer.new({ contentHeight = 0 })

    -- Buttons
    self.addBtn = UI.Button.new({
        text = "+Add", variant = "primary", fontSize = 11,
        onClick = function() self:_addPrefab() end,
    })
    self.deleteBtn = UI.Button.new({
        text = "Delete", variant = "danger", fontSize = 11,
        onClick = function() self:_deletePrefab() end,
    })
    self.dupBtn = UI.Button.new({
        text = "Dup", variant = "secondary", fontSize = 11,
        onClick = function() self:_duplicatePrefab() end,
    })

    -- Width/Height buttons
    self.widthDownBtn = UI.Button.new({
        text = "-", variant = "secondary", fontSize = 11,
        onClick = function() self:_resizePrefab(-1, 0) end,
    })
    self.widthUpBtn = UI.Button.new({
        text = "+", variant = "secondary", fontSize = 11,
        onClick = function() self:_resizePrefab(1, 0) end,
    })
    self.heightDownBtn = UI.Button.new({
        text = "-", variant = "secondary", fontSize = 11,
        onClick = function() self:_resizePrefab(0, -1) end,
    })
    self.heightUpBtn = UI.Button.new({
        text = "+", variant = "secondary", fontSize = 11,
        onClick = function() self:_resizePrefab(0, 1) end,
    })

    -- TileMode buttons
    self.tileModeButtons = {}
    for _, mode in ipairs(TILE_MODES) do
        self.tileModeButtons[mode] = UI.Button.new({
            text = mode, variant = "secondary", fontSize = 11,
            onClick = function() self:_setTileMode(mode) end,
        })
    end

    -- Undo/redo buttons
    self.undoBtn = UI.Button.new({
        text = "Undo", variant = "ghost", fontSize = 11,
        onClick = function() self.undoStack:undo() end,
    })
    self.redoBtn = UI.Button.new({
        text = "Redo", variant = "ghost", fontSize = 11,
        onClick = function() self.undoStack:redo() end,
    })

    -- Layout cache
    self._lastX = 0
    self._lastY = 0
    self._lastW = 0
    self._lastH = 0

    -- Left panel palette tab
    self.paletteTab = "tiles"  -- "tiles" or "entities"

    return self
end

-- =========================================================================
-- Undo helpers
-- =========================================================================

function Editor:_pushPropertyUndo(key, oldVal, newVal)
    if oldVal == newVal then return end
    local prefab = self.selectedPrefab
    if not prefab then return end
    -- Don't execute -- caller sets the value
    local cmd = {
        description = "Change " .. key,
        execute = function()
            prefab[key] = newVal
        end,
        undo = function()
            prefab[key] = oldVal
            if key == "name" then
                self.nameInput:setText(oldVal)
            end
        end,
    }
    -- Push without execute since caller already changed it
    self.undoStack._undoStack[#self.undoStack._undoStack + 1] = cmd
    self.undoStack._redoStack = {}
end

function Editor:_pushTileUndo(px, py, oldTile, newTile)
    if oldTile == newTile then return end
    local prefab = self.selectedPrefab
    if not prefab then return end
    local cmd = {
        description = "Paint tile",
        execute = function()
            if prefab.tiles[py] then
                prefab.tiles[py][px] = newTile
            end
        end,
        undo = function()
            if prefab.tiles[py] then
                prefab.tiles[py][px] = oldTile
            end
        end,
    }
    self.undoStack:coalesce(cmd, "paint_" .. self.paintStrokeId)
end

-- =========================================================================
-- Prefab list operations
-- =========================================================================

function Editor:_getFilteredPrefabs()
    local results = {}
    local search = self.searchText:lower()
    for i, prefab in ipairs(self.prefabs) do
        if search == "" or prefab.name:lower():find(search, 1, true) then
            results[#results + 1] = { index = i, prefab = prefab }
        end
    end
    return results
end

function Editor:_selectPrefab(index)
    if index and index >= 1 and index <= #self.prefabs then
        self.selectedIndex = index
        self.selectedPrefab = self.prefabs[index]
        self.nameInput:setText(self.selectedPrefab.name)
        self.undoStack:clear()
    else
        self.selectedIndex = nil
        self.selectedPrefab = nil
        self.nameInput:setText("")
    end
end

function Editor:_addPrefab()
    local prefab = createBlankPrefab("Prefab " .. (#self.prefabs + 1))
    self.prefabs[#self.prefabs + 1] = prefab
    self:_selectPrefab(#self.prefabs)
end

function Editor:_deletePrefab()
    if not self.selectedIndex then return end
    table.remove(self.prefabs, self.selectedIndex)
    if #self.prefabs == 0 then
        self:_selectPrefab(nil)
    elseif self.selectedIndex > #self.prefabs then
        self:_selectPrefab(#self.prefabs)
    else
        self:_selectPrefab(self.selectedIndex)
    end
end

function Editor:_duplicatePrefab()
    if not self.selectedPrefab then return end
    local copy = deepCopy(self.selectedPrefab)
    copy.name = copy.name .. " (copy)"
    self.prefabs[#self.prefabs + 1] = copy
    self:_selectPrefab(#self.prefabs)
end

function Editor:_resizePrefab(dw, dh)
    if not self.selectedPrefab then return end
    local prefab = self.selectedPrefab
    local newW = clamp(prefab.width + dw, MIN_PREFAB_SIZE, MAX_PREFAB_SIZE)
    local newH = clamp(prefab.height + dh, MIN_PREFAB_SIZE, MAX_PREFAB_SIZE)
    if newW == prefab.width and newH == prefab.height then return end

    local oldW, oldH = prefab.width, prefab.height
    local oldTiles = deepCopy(prefab.tiles)
    local oldEntities = deepCopy(prefab.entities)

    local newTiles = resizePrefabTiles(prefab, newW, newH)

    -- Remove entities outside new bounds
    local newEntities = {}
    for _, ent in ipairs(prefab.entities) do
        if ent.x >= 1 and ent.x <= newW and ent.y >= 1 and ent.y <= newH then
            newEntities[#newEntities + 1] = ent
        end
    end

    local cmd = {
        description = "Resize prefab",
        execute = function()
            prefab.width = newW
            prefab.height = newH
            prefab.tiles = newTiles
            prefab.entities = newEntities
        end,
        undo = function()
            prefab.width = oldW
            prefab.height = oldH
            prefab.tiles = oldTiles
            prefab.entities = oldEntities
        end,
    }
    self.undoStack:push(cmd)
end

function Editor:_setTileMode(mode)
    if not self.selectedPrefab then return end
    if self.selectedPrefab.tileMode == mode then return end
    local oldMode = self.selectedPrefab.tileMode
    local prefab = self.selectedPrefab
    local cmd = {
        description = "Change tile mode",
        execute = function() prefab.tileMode = mode end,
        undo = function() prefab.tileMode = oldMode end,
    }
    self.undoStack:push(cmd)
    self.selectedTileId = 0
end

-- =========================================================================
-- Tag operations
-- =========================================================================

function Editor:_addTag(tag)
    if not self.selectedPrefab then return end
    local prefab = self.selectedPrefab
    -- Check for duplicates
    for _, t in ipairs(prefab.tags) do
        if t == tag then return end
    end
    local cmd = {
        description = "Add tag '" .. tag .. "'",
        execute = function()
            prefab.tags[#prefab.tags + 1] = tag
        end,
        undo = function()
            for i = #prefab.tags, 1, -1 do
                if prefab.tags[i] == tag then
                    table.remove(prefab.tags, i)
                    break
                end
            end
        end,
    }
    self.undoStack:push(cmd)
end

function Editor:_removeTag(index)
    if not self.selectedPrefab then return end
    local prefab = self.selectedPrefab
    if not prefab.tags[index] then return end
    local removedTag = prefab.tags[index]
    local cmd = {
        description = "Remove tag '" .. removedTag .. "'",
        execute = function()
            for i = #prefab.tags, 1, -1 do
                if prefab.tags[i] == removedTag then
                    table.remove(prefab.tags, i)
                    break
                end
            end
        end,
        undo = function()
            table.insert(prefab.tags, index, removedTag)
        end,
    }
    self.undoStack:push(cmd)
end

-- =========================================================================
-- Entity operations
-- =========================================================================

function Editor:_addEntity(entType, gx, gy)
    if not self.selectedPrefab then return end
    local prefab = self.selectedPrefab
    if gx < 1 or gx > prefab.width or gy < 1 or gy > prefab.height then return end

    local entity = {
        type = entType.type,
        x = gx,
        y = gy,
    }
    if entType.type == "npc" then
        entity.slot = "generic"
    elseif entType.type == "item" then
        entity.id = "item"
    elseif entType.type == "decoration" then
        entity.id = "deco"
    end

    local cmd = {
        description = "Place " .. entType.label,
        execute = function()
            prefab.entities[#prefab.entities + 1] = entity
        end,
        undo = function()
            for i = #prefab.entities, 1, -1 do
                if prefab.entities[i] == entity then
                    table.remove(prefab.entities, i)
                    break
                end
            end
        end,
    }
    self.undoStack:push(cmd)
end

function Editor:_removeEntity(index)
    if not self.selectedPrefab then return end
    local prefab = self.selectedPrefab
    if not prefab.entities[index] then return end
    local removed = prefab.entities[index]
    local removedCopy = deepCopy(removed)
    local cmd = {
        description = "Remove entity",
        execute = function()
            for i = #prefab.entities, 1, -1 do
                if prefab.entities[i] == removed then
                    table.remove(prefab.entities, i)
                    break
                end
            end
        end,
        undo = function()
            table.insert(prefab.entities, index, removedCopy)
            -- Reassign the reference so future removes still find it
            removed = removedCopy
        end,
    }
    self.undoStack:push(cmd)
end

-- =========================================================================
-- Canvas grid computations
-- =========================================================================

function Editor:_getCanvasParams(cx, cy, cw, ch)
    if not self.selectedPrefab then
        return cx, cy, 24, cw, ch
    end
    local prefab = self.selectedPrefab
    local maxCellW = math.floor((cw - 4) / prefab.width)
    local maxCellH = math.floor((ch - 4) / prefab.height)
    local cellSize = math.min(maxCellW, maxCellH)
    cellSize = clamp(cellSize, 8, 48)

    local gridW = prefab.width * cellSize
    local gridH = prefab.height * cellSize
    local gridX = cx + math.floor((cw - gridW) / 2)
    local gridY = cy + math.floor((ch - gridH) / 2)

    return gridX, gridY, cellSize, gridW, gridH
end

function Editor:_screenToGrid(mx, my, gridX, gridY, cellSize)
    local gx = math.floor((mx - gridX) / cellSize) + 1
    local gy = math.floor((my - gridY) / cellSize) + 1
    return gx, gy
end

-- =========================================================================
-- Update
-- =========================================================================

function Editor:update(dt)
    self.searchInput:update(dt)
    self.nameInput:update(dt)
    self.tagInput:update(dt)

    -- Update button disabled states
    local hasSel = self.selectedPrefab ~= nil
    self.deleteBtn:setDisabled(not hasSel)
    self.dupBtn:setDisabled(not hasSel)
    self.undoBtn:setDisabled(not self.undoStack:canUndo())
    self.redoBtn:setDisabled(not self.undoStack:canRedo())
end

-- =========================================================================
-- Draw
-- =========================================================================

function Editor:draw(x, y, w, h)
    self._lastX = x
    self._lastY = y
    self._lastW = w
    self._lastH = h

    -- Panel regions
    local leftX = x
    local leftW = LEFT_PANEL_W
    local rightX = x + w - RIGHT_PANEL_W
    local rightW = RIGHT_PANEL_W
    local centerX = leftX + leftW + 1
    local centerW = rightX - centerX - 1
    if centerW < 10 then centerW = 10 end

    -- Draw panels
    self:_drawLeftPanel(leftX, y, leftW, h)
    self:_drawCenter(centerX, y, centerW, h)
    self:_drawRightPanel(rightX, y, rightW, h)

    -- Panel dividers
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", leftX + leftW, y, 1, h)
    love.graphics.rectangle("fill", rightX - 1, y, 1, h)
end

-- =========================================================================
-- Left Panel
-- =========================================================================

function Editor:_drawLeftPanel(px, py, pw, ph)
    -- Background
    setColorSafe(Theme.colors.panel)
    love.graphics.rectangle("fill", px, py, pw, ph)

    local pad = Theme.spacing.md
    local cy = py + pad
    local innerW = pw - pad * 2

    -- Header
    local font = FontCache.get(14)
    love.graphics.setFont(font)
    setColorSafe(Theme.colors.textAccent)
    love.graphics.print("Prefabs", px + pad, cy)
    cy = cy + font:getHeight() + pad

    -- Search
    self.searchInput:draw(px + pad, cy, innerW, Theme.sizes.inputHeight)
    cy = cy + Theme.sizes.inputHeight + pad

    -- Buttons row
    local btnW = math.floor((innerW - pad * 2) / 3)
    local btnH = Theme.sizes.buttonHeight
    self.addBtn:draw(px + pad, cy, btnW, btnH)
    self.dupBtn:draw(px + pad + btnW + pad, cy, btnW, btnH)
    self.deleteBtn:draw(px + pad + (btnW + pad) * 2, cy, btnW, btnH)
    cy = cy + btnH + pad

    -- Prefab list
    local listH = math.floor((ph - (cy - py)) * 0.40)
    if listH < 40 then listH = 40 end
    self:_drawPrefabList(px + pad, cy, innerW, listH)
    cy = cy + listH + pad

    -- Palette tabs
    local tabFont = FontCache.get(12)
    love.graphics.setFont(tabFont)
    local tabH = 24
    local tabW = math.floor(innerW / 2)

    -- Tiles tab
    local tilesActive = (self.paletteTab == "tiles")
    if tilesActive then
        setColorSafe(Theme.colors.primary)
    else
        setColorSafe(Theme.colors.tabInactive)
    end
    love.graphics.rectangle("fill", px + pad, cy, tabW, tabH)
    if tilesActive then
        setColorSafe(Theme.colors.bg)
    else
        setColorSafe(Theme.colors.textDim)
    end
    love.graphics.print("Tiles", px + pad + 4, cy + 4)

    -- Entities tab
    local entActive = (self.paletteTab == "entities")
    if entActive then
        setColorSafe(Theme.colors.primary)
    else
        setColorSafe(Theme.colors.tabInactive)
    end
    love.graphics.rectangle("fill", px + pad + tabW, cy, tabW, tabH)
    if entActive then
        setColorSafe(Theme.colors.bg)
    else
        setColorSafe(Theme.colors.textDim)
    end
    love.graphics.print("Entities", px + pad + tabW + 4, cy + 4)

    self._paletteTabRect = { x = px + pad, y = cy, w = innerW, h = tabH, tabW = tabW }
    cy = cy + tabH + 2

    -- Palette content
    local paletteH = py + ph - cy - pad
    if paletteH < 20 then paletteH = 20 end
    if self.paletteTab == "tiles" then
        self:_drawTilePalette(px + pad, cy, innerW, paletteH)
    else
        self:_drawEntityPalette(px + pad, cy, innerW, paletteH)
    end
end

function Editor:_drawPrefabList(lx, ly, lw, lh)
    local filtered = self:_getFilteredPrefabs()
    local itemH = Theme.sizes.listItemHeight
    local totalH = #filtered * itemH
    self.prefabListScroll:setContentHeight(totalH)

    -- Border
    setColorSafe(Theme.colors.inputBorder)
    love.graphics.rectangle("line", lx - 1, ly - 1, lw + 2, lh + 2)

    self.prefabListScroll:beginDraw(lx, ly, lw, lh)

    local font = FontCache.get(12)
    love.graphics.setFont(font)
    local mx, my = love.mouse.getPosition()

    for i, entry in ipairs(filtered) do
        local iy = (i - 1) * itemH
        local screenY = ly + iy - self.prefabListScroll.scrollY
        local isSelected = (entry.index == self.selectedIndex)
        local isHovered = pointInRect(mx, my, lx, screenY, lw, itemH)

        if isSelected then
            setColorSafe(Theme.colors.listItemSelected)
            love.graphics.rectangle("fill", 0, iy, lw, itemH)
        elseif isHovered then
            setColorSafe(Theme.colors.listItemHover)
            love.graphics.rectangle("fill", 0, iy, lw, itemH)
        elseif i % 2 == 0 then
            setColorSafe(Theme.colors.listItemAlt)
            love.graphics.rectangle("fill", 0, iy, lw, itemH)
        end

        setColorSafe(Theme.colors.text)
        local textY = iy + math.floor((itemH - font:getHeight()) / 2)
        love.graphics.print(entry.prefab.name, 4, textY)

        -- Mode badge
        local modeFont = FontCache.get(10)
        love.graphics.setFont(modeFont)
        local modeStr = entry.prefab.tileMode or "?"
        local modeW = modeFont:getWidth(modeStr) + 8
        setColorSafe(Theme.colors.bgLight)
        drawRoundedRect("fill", lw - modeW - 4, iy + 4, modeW, itemH - 8, 3)
        setColorSafe(Theme.colors.textDim)
        love.graphics.print(modeStr, lw - modeW, iy + 5)
        love.graphics.setFont(font)
    end

    self.prefabListScroll:endDraw()

    self._prefabListRect = { x = lx, y = ly, w = lw, h = lh }
    self._filteredPrefabs = filtered
end

function Editor:_drawTilePalette(px, py, pw, ph)
    local prefab = self.selectedPrefab
    local palette = getTilePalette(prefab and prefab.tileMode or "dungeon")
    local itemH = 22
    local totalH = #palette * itemH
    self.tilePaletteScroll:setContentHeight(totalH)

    setColorSafe(Theme.colors.bgDark)
    love.graphics.rectangle("fill", px, py, pw, ph)

    self.tilePaletteScroll:beginDraw(px, py, pw, ph)

    local font = FontCache.get(11)
    love.graphics.setFont(font)
    local mx, my = love.mouse.getPosition()

    for i, tile in ipairs(palette) do
        local iy = (i - 1) * itemH
        local screenY = py + iy - self.tilePaletteScroll.scrollY
        local isSelected = (self.activeTool == "paint" and self.selectedTileId == tile.id)
        local isHovered = pointInRect(mx, my, px, screenY, pw, itemH)

        if isSelected then
            setColorSafe(Theme.colors.listItemSelected)
            love.graphics.rectangle("fill", 0, iy, pw, itemH)
        elseif isHovered then
            setColorSafe(Theme.colors.listItemHover)
            love.graphics.rectangle("fill", 0, iy, pw, itemH)
        end

        -- Color swatch
        setColorSafe(tile.color)
        love.graphics.rectangle("fill", 4, iy + 3, 16, itemH - 6)
        setColorSafe(Theme.colors.panelBorder)
        love.graphics.rectangle("line", 4, iy + 3, 16, itemH - 6)

        -- Name
        setColorSafe(Theme.colors.text)
        love.graphics.print(tile.name, 24, iy + 3)

        if isSelected then
            setColorSafe(Theme.colors.primary)
            love.graphics.rectangle("fill", 0, iy, 2, itemH)
        end
    end

    self.tilePaletteScroll:endDraw()

    self._tilePaletteRect = { x = px, y = py, w = pw, h = ph }
end

function Editor:_drawEntityPalette(px, py, pw, ph)
    local itemH = 28
    local totalH = #ENTITY_TYPES * itemH
    self.entityPaletteScroll:setContentHeight(totalH)

    setColorSafe(Theme.colors.bgDark)
    love.graphics.rectangle("fill", px, py, pw, ph)

    self.entityPaletteScroll:beginDraw(px, py, pw, ph)

    local font = FontCache.get(12)
    love.graphics.setFont(font)
    local mx, my = love.mouse.getPosition()

    for i, entType in ipairs(ENTITY_TYPES) do
        local iy = (i - 1) * itemH
        local screenY = py + iy - self.entityPaletteScroll.scrollY
        local isSelected = (self.activeTool == "entity" and self.selectedEntityType == entType)
        local isHovered = pointInRect(mx, my, px, screenY, pw, itemH)

        if isSelected then
            setColorSafe(Theme.colors.listItemSelected)
            love.graphics.rectangle("fill", 0, iy, pw, itemH)
        elseif isHovered then
            setColorSafe(Theme.colors.listItemHover)
            love.graphics.rectangle("fill", 0, iy, pw, itemH)
        end

        -- Icon circle
        setColorSafe(entType.color)
        local circleX = 16
        local circleY = iy + itemH / 2
        love.graphics.circle("fill", circleX, circleY, 10)

        -- Icon letter
        local iconFont = FontCache.get(13)
        love.graphics.setFont(iconFont)
        setColorSafe(Theme.colors.bg)
        local tw = iconFont:getWidth(entType.icon)
        love.graphics.print(entType.icon, circleX - tw / 2, circleY - iconFont:getHeight() / 2)

        -- Label
        love.graphics.setFont(font)
        setColorSafe(Theme.colors.text)
        love.graphics.print(entType.label, 32, iy + math.floor((itemH - font:getHeight()) / 2))

        if isSelected then
            setColorSafe(Theme.colors.primary)
            love.graphics.rectangle("fill", 0, iy, 2, itemH)
        end
    end

    self.entityPaletteScroll:endDraw()

    self._entityPaletteRect = { x = px, y = py, w = pw, h = ph }
end

-- =========================================================================
-- Center Canvas
-- =========================================================================

function Editor:_drawCenter(cx, cy, cw, ch)
    -- Background
    setColorSafe(Theme.colors.bgDark)
    love.graphics.rectangle("fill", cx, cy, cw, ch)

    if not self.selectedPrefab then
        -- No selection message
        local font = FontCache.get(16)
        love.graphics.setFont(font)
        setColorSafe(Theme.colors.textDim)
        local msg = "Select or create a prefab"
        local tw = font:getWidth(msg)
        love.graphics.print(msg, cx + (cw - tw) / 2, cy + ch / 2 - font:getHeight() / 2)
        return
    end

    -- Toolbar area at top
    local toolbarH = 30
    self:_drawCanvasToolbar(cx, cy, cw, toolbarH)

    local canvasY = cy + toolbarH
    local canvasH = ch - toolbarH
    if canvasH < 20 then canvasH = 20 end

    self._canvasRect = { x = cx, y = canvasY, w = cw, h = canvasH }

    love.graphics.setScissor(cx, canvasY, cw, canvasH)
    self:_drawGrid(cx, canvasY, cw, canvasH)
    love.graphics.setScissor()
end

function Editor:_drawCanvasToolbar(tx, ty, tw, th)
    setColorSafe(Theme.colors.panelHeader)
    love.graphics.rectangle("fill", tx, ty, tw, th)
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", tx, ty + th - 1, tw, 1)

    local pad = Theme.spacing.sm
    local btnH = th - 4
    local bx = tx + pad

    self.undoBtn:draw(bx, ty + 2, 50, btnH)
    bx = bx + 54
    self.redoBtn:draw(bx, ty + 2, 50, btnH)
    bx = bx + 54

    -- Tool indicator
    local font = FontCache.get(11)
    love.graphics.setFont(font)
    setColorSafe(Theme.colors.textDim)
    local toolText = "Tool: " .. self.activeTool
    if self.activeTool == "paint" then
        local palette = getTilePalette(self.selectedPrefab and self.selectedPrefab.tileMode or "dungeon")
        for _, tile in ipairs(palette) do
            if tile.id == self.selectedTileId then
                toolText = toolText .. " [" .. tile.name .. "]"
                break
            end
        end
    elseif self.activeTool == "entity" and self.selectedEntityType then
        toolText = toolText .. " [" .. self.selectedEntityType.label .. "]"
    end
    love.graphics.print(toolText, bx + pad, ty + math.floor((th - font:getHeight()) / 2))

    self._toolbarRect = { x = tx, y = ty, w = tw, h = th }
end

function Editor:_drawGrid(cx, cy, cw, ch)
    local prefab = self.selectedPrefab
    if not prefab then return end

    local gridX, gridY, cellSize, gridW, gridH = self:_getCanvasParams(cx, cy, cw, ch)

    -- Draw tiles
    for gy = 1, prefab.height do
        for gx = 1, prefab.width do
            local tileId = 0
            if prefab.tiles[gy] and prefab.tiles[gy][gx] then
                tileId = prefab.tiles[gy][gx]
            end
            local color = getTileColor(prefab.tileMode, tileId)
            local dx = gridX + (gx - 1) * cellSize
            local dy = gridY + (gy - 1) * cellSize

            setColorSafe(color)
            love.graphics.rectangle("fill", dx, dy, cellSize, cellSize)
        end
    end

    -- Draw grid lines
    love.graphics.setColor(1, 1, 1, 0.12)
    love.graphics.setLineWidth(1)
    for gx = 0, prefab.width do
        local dx = gridX + gx * cellSize
        love.graphics.line(dx, gridY, dx, gridY + gridH)
    end
    for gy = 0, prefab.height do
        local dy = gridY + gy * cellSize
        love.graphics.line(gridX, dy, gridX + gridW, dy)
    end

    -- Draw border
    love.graphics.setColor(1, 1, 1, 0.30)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", gridX - 1, gridY - 1, gridW + 2, gridH + 2)
    love.graphics.setLineWidth(1)

    -- Draw entities
    for _, ent in ipairs(prefab.entities) do
        local ex = gridX + (ent.x - 1) * cellSize
        local ey = gridY + (ent.y - 1) * cellSize

        -- Find entity type info
        local entInfo = nil
        for _, et in ipairs(ENTITY_TYPES) do
            if et.type == ent.type then
                entInfo = et
                break
            end
        end

        if entInfo then
            -- Entity background
            setColorSafe(entInfo.color)
            love.graphics.setColor(entInfo.color[1], entInfo.color[2], entInfo.color[3], 0.6)
            love.graphics.rectangle("fill", ex + 1, ey + 1, cellSize - 2, cellSize - 2)

            -- Icon
            local iconFont = FontCache.get(math.max(10, cellSize - 8))
            love.graphics.setFont(iconFont)
            setColorSafe(Theme.colors.bg)
            local iw = iconFont:getWidth(entInfo.icon)
            local ih = iconFont:getHeight()
            love.graphics.print(entInfo.icon, ex + (cellSize - iw) / 2, ey + (cellSize - ih) / 2)

            -- Border
            setColorSafe(entInfo.color)
            love.graphics.rectangle("line", ex + 1, ey + 1, cellSize - 2, cellSize - 2)
        end
    end

    -- Hover highlight
    local mx, my = love.mouse.getPosition()
    if self._canvasRect and pointInRect(mx, my, self._canvasRect.x, self._canvasRect.y,
            self._canvasRect.w, self._canvasRect.h) then
        local gx, gy = self:_screenToGrid(mx, my, gridX, gridY, cellSize)
        if gx >= 1 and gx <= prefab.width and gy >= 1 and gy <= prefab.height then
            local hx = gridX + (gx - 1) * cellSize
            local hy = gridY + (gy - 1) * cellSize
            love.graphics.setColor(1, 1, 1, 0.25)
            love.graphics.rectangle("fill", hx, hy, cellSize, cellSize)
        end
    end

    self._gridParams = { x = gridX, y = gridY, cellSize = cellSize }
end

-- =========================================================================
-- Right Panel
-- =========================================================================

function Editor:_drawRightPanel(rx, ry, rw, rh)
    -- Background
    setColorSafe(Theme.colors.panel)
    love.graphics.rectangle("fill", rx, ry, rw, rh)

    if not self.selectedPrefab then
        local font = FontCache.get(12)
        love.graphics.setFont(font)
        setColorSafe(Theme.colors.textDim)
        love.graphics.printf("No prefab selected", rx + 8, ry + 20, rw - 16, "center")
        return
    end

    local pad = Theme.spacing.md
    local cy = ry + pad
    local innerW = rw - pad * 2
    local prefab = self.selectedPrefab

    -- Header
    local headerFont = FontCache.get(13)
    love.graphics.setFont(headerFont)
    setColorSafe(Theme.colors.textAccent)
    love.graphics.print("Properties", rx + pad, cy)
    cy = cy + headerFont:getHeight() + pad

    -- Name field
    local labelFont = FontCache.get(11)
    love.graphics.setFont(labelFont)
    setColorSafe(Theme.colors.textDim)
    love.graphics.print("Name", rx + pad, cy)
    cy = cy + labelFont:getHeight() + 2
    self.nameInput:draw(rx + pad, cy, innerW, Theme.sizes.inputHeight)
    cy = cy + Theme.sizes.inputHeight + pad

    -- Width
    setColorSafe(Theme.colors.textDim)
    love.graphics.setFont(labelFont)
    love.graphics.print("Width: " .. prefab.width, rx + pad, cy)
    local dimBtnW = 24
    local dimBtnH = 20
    self.widthDownBtn:draw(rx + innerW - dimBtnW * 2 - 2, cy - 1, dimBtnW, dimBtnH)
    self.widthUpBtn:draw(rx + innerW - dimBtnW, cy - 1, dimBtnW, dimBtnH)
    cy = cy + dimBtnH + 4

    -- Height
    setColorSafe(Theme.colors.textDim)
    love.graphics.setFont(labelFont)
    love.graphics.print("Height: " .. prefab.height, rx + pad, cy)
    self.heightDownBtn:draw(rx + innerW - dimBtnW * 2 - 2, cy - 1, dimBtnW, dimBtnH)
    self.heightUpBtn:draw(rx + innerW - dimBtnW, cy - 1, dimBtnW, dimBtnH)
    cy = cy + dimBtnH + 4

    -- Tile mode
    setColorSafe(Theme.colors.textDim)
    love.graphics.setFont(labelFont)
    love.graphics.print("Tile Mode", rx + pad, cy)
    cy = cy + labelFont:getHeight() + 2
    local modeBtnW = math.floor((innerW - pad) / 2)
    for idx, mode in ipairs(TILE_MODES) do
        local btn = self.tileModeButtons[mode]
        if prefab.tileMode == mode then
            btn.variant = "primary"
        else
            btn.variant = "secondary"
        end
        btn:draw(rx + pad + (idx - 1) * (modeBtnW + pad), cy, modeBtnW, dimBtnH)
    end
    cy = cy + dimBtnH + pad

    -- Separator
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", rx + pad, cy, innerW, 1)
    cy = cy + pad

    -- Tags section
    setColorSafe(Theme.colors.textAccent)
    love.graphics.setFont(headerFont)
    love.graphics.print("Tags", rx + pad, cy)
    cy = cy + headerFont:getHeight() + 4

    -- Tag input
    self.tagInput:draw(rx + pad, cy, innerW, Theme.sizes.inputHeight)
    cy = cy + Theme.sizes.inputHeight + 4

    -- Tag list
    local tagH = math.min(80, #prefab.tags * 22 + 4)
    if tagH < 24 then tagH = 24 end
    self:_drawTagList(rx + pad, cy, innerW, tagH)
    cy = cy + tagH + pad

    -- Separator
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", rx + pad, cy, innerW, 1)
    cy = cy + pad

    -- Entity list
    setColorSafe(Theme.colors.textAccent)
    love.graphics.setFont(headerFont)
    love.graphics.print("Entities (" .. #prefab.entities .. ")", rx + pad, cy)
    cy = cy + headerFont:getHeight() + 4

    local entityListH = ry + rh - cy - pad
    if entityListH < 30 then entityListH = 30 end
    self:_drawEntityList(rx + pad, cy, innerW, entityListH)
end

function Editor:_drawTagList(tx, ty, tw, th)
    local prefab = self.selectedPrefab
    if not prefab then return end

    local itemH = 22
    local totalH = #prefab.tags * itemH
    self.tagListScroll:setContentHeight(totalH)

    setColorSafe(Theme.colors.bgDark)
    love.graphics.rectangle("fill", tx, ty, tw, th)

    self.tagListScroll:beginDraw(tx, ty, tw, th)

    local font = FontCache.get(11)
    love.graphics.setFont(font)
    local mx, my = love.mouse.getPosition()

    for i, tag in ipairs(prefab.tags) do
        local iy = (i - 1) * itemH

        setColorSafe(Theme.colors.text)
        love.graphics.print(tag, 4, iy + 3)

        -- Remove button (X)
        local removeX = tw - 18
        local screenY = ty + iy - self.tagListScroll.scrollY
        local removeHovered = pointInRect(mx, my, tx + removeX, screenY, 16, itemH)
        if removeHovered then
            setColorSafe(Theme.colors.dangerHover)
        else
            setColorSafe(Theme.colors.textDim)
        end
        love.graphics.print("x", removeX + 3, iy + 3)
    end

    self.tagListScroll:endDraw()

    self._tagListRect = { x = tx, y = ty, w = tw, h = th }
end

function Editor:_drawEntityList(ex, ey, ew, eh)
    local prefab = self.selectedPrefab
    if not prefab then return end

    local itemH = 24
    local totalH = #prefab.entities * itemH
    self.entityListScroll:setContentHeight(totalH)

    setColorSafe(Theme.colors.bgDark)
    love.graphics.rectangle("fill", ex, ey, ew, eh)

    self.entityListScroll:beginDraw(ex, ey, ew, eh)

    local font = FontCache.get(11)
    love.graphics.setFont(font)
    local mx, my = love.mouse.getPosition()

    for i, ent in ipairs(prefab.entities) do
        local iy = (i - 1) * itemH

        -- Find entity type color
        local entColor = Theme.colors.text
        for _, et in ipairs(ENTITY_TYPES) do
            if et.type == ent.type then
                entColor = et.color
                break
            end
        end

        -- Type badge
        setColorSafe(entColor)
        love.graphics.rectangle("fill", 2, iy + 4, 3, itemH - 8)

        -- Description
        setColorSafe(Theme.colors.text)
        local desc = ent.type
        if ent.slot then desc = desc .. ":" .. ent.slot end
        if ent.id then desc = desc .. ":" .. ent.id end
        desc = desc .. " @" .. ent.x .. "," .. ent.y
        love.graphics.print(desc, 8, iy + math.floor((itemH - font:getHeight()) / 2))

        -- Remove button
        local removeX = ew - 18
        local screenY = ey + iy - self.entityListScroll.scrollY
        local removeHovered = pointInRect(mx, my, ex + removeX, screenY, 16, itemH)
        if removeHovered then
            setColorSafe(Theme.colors.dangerHover)
        else
            setColorSafe(Theme.colors.textDim)
        end
        love.graphics.print("x", removeX + 3, iy + math.floor((itemH - font:getHeight()) / 2))
    end

    self.entityListScroll:endDraw()

    self._entityListRect = { x = ex, y = ey, w = ew, h = eh }
end

-- =========================================================================
-- Input: mousepressed
-- =========================================================================

function Editor:mousepressed(mx, my, button)
    if button ~= 1 then return false end

    -- Search input
    if self.searchInput:mousepressed(mx, my, button) then return true end
    if self.nameInput:mousepressed(mx, my, button) then return true end
    if self.tagInput:mousepressed(mx, my, button) then return true end

    -- Buttons
    if self.addBtn:mousepressed(mx, my, button) then return true end
    if self.deleteBtn:mousepressed(mx, my, button) then return true end
    if self.dupBtn:mousepressed(mx, my, button) then return true end
    if self.undoBtn:mousepressed(mx, my, button) then return true end
    if self.redoBtn:mousepressed(mx, my, button) then return true end
    if self.widthDownBtn:mousepressed(mx, my, button) then return true end
    if self.widthUpBtn:mousepressed(mx, my, button) then return true end
    if self.heightDownBtn:mousepressed(mx, my, button) then return true end
    if self.heightUpBtn:mousepressed(mx, my, button) then return true end

    -- Tile mode buttons
    for _, btn in pairs(self.tileModeButtons) do
        if btn:mousepressed(mx, my, button) then return true end
    end

    -- Palette tab click
    if self._paletteTabRect then
        local ptr = self._paletteTabRect
        if pointInRect(mx, my, ptr.x, ptr.y, ptr.w, ptr.h) then
            local relX = mx - ptr.x
            if relX < ptr.tabW then
                self.paletteTab = "tiles"
                self.activeTool = "paint"
            else
                self.paletteTab = "entities"
                self.activeTool = "entity"
            end
            return true
        end
    end

    -- Prefab list click
    if self._prefabListRect and self._filteredPrefabs then
        local plr = self._prefabListRect
        if pointInRect(mx, my, plr.x, plr.y, plr.w, plr.h) then
            -- Scrollbar
            if self.prefabListScroll:mousepressed(mx, my, button) then return true end
            -- Item click
            local relY = my - plr.y + self.prefabListScroll.scrollY
            local itemH = Theme.sizes.listItemHeight
            local idx = math.floor(relY / itemH) + 1
            if idx >= 1 and idx <= #self._filteredPrefabs then
                self:_selectPrefab(self._filteredPrefabs[idx].index)
            end
            return true
        end
    end

    -- Tile palette click
    if self._tilePaletteRect and self.paletteTab == "tiles" then
        local tpr = self._tilePaletteRect
        if pointInRect(mx, my, tpr.x, tpr.y, tpr.w, tpr.h) then
            if self.tilePaletteScroll:mousepressed(mx, my, button) then return true end
            local palette = getTilePalette(self.selectedPrefab and self.selectedPrefab.tileMode or "dungeon")
            local relY = my - tpr.y + self.tilePaletteScroll.scrollY
            local itemH = 22
            local idx = math.floor(relY / itemH) + 1
            if idx >= 1 and idx <= #palette then
                self.selectedTileId = palette[idx].id
                self.activeTool = "paint"
            end
            return true
        end
    end

    -- Entity palette click
    if self._entityPaletteRect and self.paletteTab == "entities" then
        local epr = self._entityPaletteRect
        if pointInRect(mx, my, epr.x, epr.y, epr.w, epr.h) then
            if self.entityPaletteScroll:mousepressed(mx, my, button) then return true end
            local relY = my - epr.y + self.entityPaletteScroll.scrollY
            local itemH = 28
            local idx = math.floor(relY / itemH) + 1
            if idx >= 1 and idx <= #ENTITY_TYPES then
                self.selectedEntityType = ENTITY_TYPES[idx]
                self.activeTool = "entity"
            end
            return true
        end
    end

    -- Tag list click (remove buttons)
    if self._tagListRect and self.selectedPrefab then
        local tlr = self._tagListRect
        if pointInRect(mx, my, tlr.x, tlr.y, tlr.w, tlr.h) then
            if self.tagListScroll:mousepressed(mx, my, button) then return true end
            local relY = my - tlr.y + self.tagListScroll.scrollY
            local itemH = 22
            local idx = math.floor(relY / itemH) + 1
            local removeX = tlr.w - 18
            if mx >= tlr.x + removeX and idx >= 1 and idx <= #self.selectedPrefab.tags then
                self:_removeTag(idx)
            end
            return true
        end
    end

    -- Entity list click (remove buttons)
    if self._entityListRect and self.selectedPrefab then
        local elr = self._entityListRect
        if pointInRect(mx, my, elr.x, elr.y, elr.w, elr.h) then
            if self.entityListScroll:mousepressed(mx, my, button) then return true end
            local relY = my - elr.y + self.entityListScroll.scrollY
            local itemH = 24
            local idx = math.floor(relY / itemH) + 1
            local removeX = elr.w - 18
            if mx >= elr.x + removeX and idx >= 1 and idx <= #self.selectedPrefab.entities then
                self:_removeEntity(idx)
            end
            return true
        end
    end

    -- Canvas click
    if self._canvasRect and self._gridParams and self.selectedPrefab then
        local cr = self._canvasRect
        if pointInRect(mx, my, cr.x, cr.y, cr.w, cr.h) then
            local gp = self._gridParams
            local gx, gy = self:_screenToGrid(mx, my, gp.x, gp.y, gp.cellSize)
            local prefab = self.selectedPrefab

            if gx >= 1 and gx <= prefab.width and gy >= 1 and gy <= prefab.height then
                if self.activeTool == "paint" then
                    self.isPainting = true
                    self.paintStrokeId = self.paintStrokeId + 1
                    local oldTile = 0
                    if prefab.tiles[gy] and prefab.tiles[gy][gx] then
                        oldTile = prefab.tiles[gy][gx]
                    end
                    self:_pushTileUndo(gx, gy, oldTile, self.selectedTileId)
                elseif self.activeTool == "entity" and self.selectedEntityType then
                    self:_addEntity(self.selectedEntityType, gx, gy)
                end
            end
            return true
        end
    end

    -- Toolbar buttons
    if self._toolbarRect then
        local tr = self._toolbarRect
        if pointInRect(mx, my, tr.x, tr.y, tr.w, tr.h) then
            return true
        end
    end

    return false
end

-- =========================================================================
-- Input: mousereleased
-- =========================================================================

function Editor:mousereleased(mx, my, button)
    if button ~= 1 then return false end
    self.isPainting = false

    -- Buttons
    self.addBtn:mousereleased(mx, my, button)
    self.deleteBtn:mousereleased(mx, my, button)
    self.dupBtn:mousereleased(mx, my, button)
    self.undoBtn:mousereleased(mx, my, button)
    self.redoBtn:mousereleased(mx, my, button)
    self.widthDownBtn:mousereleased(mx, my, button)
    self.widthUpBtn:mousereleased(mx, my, button)
    self.heightDownBtn:mousereleased(mx, my, button)
    self.heightUpBtn:mousereleased(mx, my, button)
    for _, btn in pairs(self.tileModeButtons) do
        btn:mousereleased(mx, my, button)
    end

    -- Scroll containers
    self.prefabListScroll:mousereleased(mx, my, button)
    self.tilePaletteScroll:mousereleased(mx, my, button)
    self.entityPaletteScroll:mousereleased(mx, my, button)
    self.entityListScroll:mousereleased(mx, my, button)
    self.tagListScroll:mousereleased(mx, my, button)

    return false
end

-- =========================================================================
-- Input: mousemoved (for painting drag)
-- =========================================================================

function Editor:mousemoved(mx, my)
    -- Scroll container drag
    self.prefabListScroll:mousemoved(mx, my)
    self.tilePaletteScroll:mousemoved(mx, my)
    self.entityPaletteScroll:mousemoved(mx, my)
    self.entityListScroll:mousemoved(mx, my)
    self.tagListScroll:mousemoved(mx, my)

    -- Text input drag for selection
    self.searchInput:mousemoved(mx, my)
    self.nameInput:mousemoved(mx, my)
    self.tagInput:mousemoved(mx, my)

    -- Paint drag on canvas
    if self.isPainting and self.activeTool == "paint" and self._gridParams and self.selectedPrefab then
        local gp = self._gridParams
        local gx, gy = self:_screenToGrid(mx, my, gp.x, gp.y, gp.cellSize)
        local prefab = self.selectedPrefab
        if gx >= 1 and gx <= prefab.width and gy >= 1 and gy <= prefab.height then
            local oldTile = 0
            if prefab.tiles[gy] and prefab.tiles[gy][gx] then
                oldTile = prefab.tiles[gy][gx]
            end
            if oldTile ~= self.selectedTileId then
                self:_pushTileUndo(gx, gy, oldTile, self.selectedTileId)
            end
        end
    end
end

-- =========================================================================
-- Input: wheelmoved
-- =========================================================================

function Editor:wheelmoved(wx, wy)
    local mx, my = love.mouse.getPosition()

    if self._prefabListRect and pointInRect(mx, my,
            self._prefabListRect.x, self._prefabListRect.y,
            self._prefabListRect.w, self._prefabListRect.h) then
        self.prefabListScroll:wheelmoved(wx, wy)
        return true
    end
    if self._tilePaletteRect and self.paletteTab == "tiles" and pointInRect(mx, my,
            self._tilePaletteRect.x, self._tilePaletteRect.y,
            self._tilePaletteRect.w, self._tilePaletteRect.h) then
        self.tilePaletteScroll:wheelmoved(wx, wy)
        return true
    end
    if self._entityPaletteRect and self.paletteTab == "entities" and pointInRect(mx, my,
            self._entityPaletteRect.x, self._entityPaletteRect.y,
            self._entityPaletteRect.w, self._entityPaletteRect.h) then
        self.entityPaletteScroll:wheelmoved(wx, wy)
        return true
    end
    if self._entityListRect and pointInRect(mx, my,
            self._entityListRect.x, self._entityListRect.y,
            self._entityListRect.w, self._entityListRect.h) then
        self.entityListScroll:wheelmoved(wx, wy)
        return true
    end
    if self._tagListRect and pointInRect(mx, my,
            self._tagListRect.x, self._tagListRect.y,
            self._tagListRect.w, self._tagListRect.h) then
        self.tagListScroll:wheelmoved(wx, wy)
        return true
    end

    return false
end

-- =========================================================================
-- Input: keypressed
-- =========================================================================

function Editor:keypressed(key)
    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")

    -- Undo/redo
    if ctrl and key == "z" then
        self.undoStack:undo()
        return true
    end
    if ctrl and key == "y" then
        self.undoStack:redo()
        return true
    end

    -- Delegate to focused text inputs
    if self.searchInput:keypressed(key) then return true end
    if self.nameInput:keypressed(key) then return true end
    if self.tagInput:keypressed(key) then return true end

    return false
end

-- =========================================================================
-- Input: textinput
-- =========================================================================

function Editor:textinput(t)
    if self.searchInput:textinput(t) then return true end
    if self.nameInput:textinput(t) then return true end
    if self.tagInput:textinput(t) then return true end
    return false
end

return Editor
