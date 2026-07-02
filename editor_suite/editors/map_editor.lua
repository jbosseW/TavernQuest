-- ==========================================================================
-- Map Editor Tab for Tavern Quest Editor Suite
-- A complete tile-based map editor with Dungeon, Town, and World modes.
-- LOVE2D 11.4 compatible.
-- ==========================================================================

local Theme = require("core.theme")
local FontCache = require("core.fontcache")
local UI = require("core.ui")
local UndoStack = require("core.undo")

-- =========================================================================
-- Local helpers
-- =========================================================================

local function pointInRect(px, py, x, y, w, h)
    return px >= x and px < x + w and py >= y and py < y + h
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
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

local function deepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[deepCopy(k)] = deepCopy(v)
    end
    return copy
end

-- =========================================================================
-- Tile definitions per mode
-- =========================================================================

local DUNGEON_TILES = {
    [0]  = { name = "Void",       color = {0.10, 0.10, 0.10} },
    [1]  = { name = "Wall",       color = {0.40, 0.35, 0.30} },
    [2]  = { name = "Floor",      color = {0.60, 0.55, 0.50} },
    [3]  = { name = "Corridor",   color = {0.55, 0.50, 0.45} },
    [4]  = { name = "Door",       color = {0.70, 0.50, 0.20} },
    [5]  = { name = "StairsUp",   color = {0.30, 0.80, 0.30} },
    [6]  = { name = "StairsDown", color = {0.80, 0.30, 0.30} },
    [7]  = { name = "Chest",      color = {0.90, 0.80, 0.20} },
    [8]  = { name = "Trap",       color = {0.80, 0.20, 0.60} },
    [9]  = { name = "Water",      color = {0.20, 0.40, 0.80} },
    [10] = { name = "Lava",       color = {0.90, 0.30, 0.10} },
    [11] = { name = "Pillar",     color = {0.50, 0.50, 0.50} },
    [12] = { name = "Altar",      color = {0.80, 0.80, 0.30} },
}

local TOWN_TILES = {
    [0]  = { name = "Grass",       color = {0.30, 0.65, 0.25} },
    [1]  = { name = "Road",        color = {0.55, 0.50, 0.40} },
    [2]  = { name = "BldgFloor",   color = {0.60, 0.50, 0.40} },
    [3]  = { name = "Wall",        color = {0.45, 0.40, 0.35} },
    [4]  = { name = "Door",        color = {0.65, 0.45, 0.20} },
    [5]  = { name = "Water",       color = {0.20, 0.45, 0.80} },
    [6]  = { name = "Bridge",      color = {0.55, 0.40, 0.25} },
    [7]  = { name = "Fence",       color = {0.50, 0.40, 0.30} },
    [8]  = { name = "Garden",      color = {0.35, 0.70, 0.30} },
    [9]  = { name = "Market",      color = {0.80, 0.60, 0.25} },
    [10] = { name = "Well",        color = {0.40, 0.55, 0.70} },
    [11] = { name = "Tree",        color = {0.20, 0.50, 0.15} },
    [12] = { name = "Decoration",  color = {0.70, 0.55, 0.65} },
}

local WORLD_TILES = {
    -- Grass biome (0-4)
    [0]  = { name = "Grass",       color = {0.30, 0.65, 0.25} },
    [1]  = { name = "TallGrass",   color = {0.25, 0.55, 0.20} },
    [2]  = { name = "Flowers",     color = {0.50, 0.65, 0.30} },
    [3]  = { name = "Farmland",    color = {0.50, 0.40, 0.25} },
    [4]  = { name = "Path",        color = {0.60, 0.55, 0.40} },
    -- Forest biome (5-8)
    [5]  = { name = "Forest",      color = {0.15, 0.45, 0.12} },
    [6]  = { name = "DenseForest", color = {0.10, 0.35, 0.08} },
    [7]  = { name = "Clearing",    color = {0.35, 0.60, 0.30} },
    [8]  = { name = "Stump",       color = {0.40, 0.30, 0.20} },
    -- Mountain biome (9-12)
    [9]  = { name = "Hills",       color = {0.50, 0.50, 0.35} },
    [10] = { name = "Mountain",    color = {0.55, 0.55, 0.50} },
    [11] = { name = "Peak",        color = {0.75, 0.75, 0.75} },
    [12] = { name = "Cliff",       color = {0.45, 0.40, 0.35} },
    -- Desert biome (13-16)
    [13] = { name = "Sand",        color = {0.85, 0.75, 0.50} },
    [14] = { name = "Dunes",       color = {0.80, 0.70, 0.45} },
    [15] = { name = "Oasis",       color = {0.30, 0.60, 0.45} },
    [16] = { name = "Cactus",      color = {0.35, 0.55, 0.25} },
    -- Swamp biome (17-20)
    [17] = { name = "Swamp",       color = {0.30, 0.40, 0.20} },
    [18] = { name = "Bog",         color = {0.25, 0.35, 0.18} },
    [19] = { name = "Mangrove",    color = {0.20, 0.40, 0.22} },
    [20] = { name = "MudFlat",     color = {0.45, 0.38, 0.25} },
    -- Coastal biome (21-24)
    [21] = { name = "ShallowSea",  color = {0.25, 0.50, 0.80} },
    [22] = { name = "DeepSea",     color = {0.12, 0.30, 0.65} },
    [23] = { name = "Beach",       color = {0.90, 0.82, 0.60} },
    [24] = { name = "Reef",        color = {0.30, 0.55, 0.60} },
    -- Frozen biome (25-28)
    [25] = { name = "Snow",        color = {0.85, 0.88, 0.92} },
    [26] = { name = "Ice",         color = {0.70, 0.80, 0.90} },
    [27] = { name = "Tundra",      color = {0.55, 0.60, 0.55} },
    [28] = { name = "FrozenLake",  color = {0.60, 0.72, 0.85} },
    -- Special (29-35)
    [29] = { name = "Road",        color = {0.55, 0.50, 0.40} },
    [30] = { name = "River",       color = {0.20, 0.45, 0.75} },
    [31] = { name = "Lake",        color = {0.18, 0.42, 0.72} },
    [32] = { name = "Lava",        color = {0.90, 0.30, 0.10} },
    [33] = { name = "Ruins",       color = {0.50, 0.45, 0.40} },
    [34] = { name = "Town",        color = {0.70, 0.55, 0.35} },
    [35] = { name = "Dungeon",     color = {0.40, 0.25, 0.30} },
}

local TILE_DEFS_BY_MODE = {
    dungeon = DUNGEON_TILES,
    town    = TOWN_TILES,
    world   = WORLD_TILES,
}

-- =========================================================================
-- Entity definitions per mode
-- =========================================================================

local ENTITY_DEFS = {
    npc = {
        { id = "npc_generic",    name = "Generic NPC",   letter = "N", color = {0.3, 0.7, 0.9} },
        { id = "npc_shopkeeper", name = "Shopkeeper",    letter = "S", color = {0.9, 0.7, 0.2} },
        { id = "npc_questgiver", name = "Quest Giver",   letter = "Q", color = {0.9, 0.9, 0.3} },
        { id = "npc_guard",      name = "Guard",         letter = "G", color = {0.5, 0.5, 0.8} },
        { id = "npc_priest",     name = "Priest",        letter = "P", color = {0.9, 0.9, 0.9} },
    },
    enemy = {
        { id = "enemy_goblin",   name = "Goblin",        letter = "g", color = {0.6, 0.8, 0.2} },
        { id = "enemy_skeleton", name = "Skeleton",       letter = "s", color = {0.8, 0.8, 0.7} },
        { id = "enemy_spider",   name = "Spider",        letter = "a", color = {0.4, 0.3, 0.2} },
        { id = "enemy_rat",      name = "Rat",           letter = "r", color = {0.5, 0.4, 0.3} },
        { id = "enemy_boss",     name = "Boss",          letter = "B", color = {0.9, 0.2, 0.2} },
    },
    item = {
        { id = "item_chest",     name = "Treasure Chest", letter = "C", color = {0.9, 0.8, 0.2} },
        { id = "item_potion",    name = "Potion",         letter = "!",  color = {0.9, 0.3, 0.3} },
        { id = "item_key",       name = "Key",            letter = "k", color = {0.9, 0.8, 0.1} },
        { id = "item_scroll",    name = "Scroll",         letter = "?", color = {0.8, 0.8, 0.6} },
    },
    poi = {
        { id = "poi_spawn",      name = "Spawn Point",    letter = "@", color = {0.2, 0.9, 0.2} },
        { id = "poi_exit",       name = "Exit",           letter = ">", color = {0.9, 0.3, 0.3} },
        { id = "poi_trigger",    name = "Trigger Zone",   letter = "T", color = {0.8, 0.5, 0.9} },
        { id = "poi_waypoint",   name = "Waypoint",       letter = "W", color = {0.5, 0.8, 0.9} },
    },
}

local ENTITY_CATEGORIES_ORDER = { "npc", "enemy", "item", "poi" }
local ENTITY_CATEGORY_LABELS = {
    npc   = "NPCs",
    enemy = "Enemies",
    item  = "Items",
    poi   = "Points of Interest",
}

-- =========================================================================
-- Town themes list
-- =========================================================================

local TOWN_THEMES = {
    "desert", "forest", "mountain", "swamp", "coastal", "plains", "frozen",
}

-- =========================================================================
-- Tool definitions
-- =========================================================================

local TOOLS = {
    { id = "paint",     name = "Paint",      key = "p", letter = "P" },
    { id = "rect",      name = "Rect Fill",  key = "r", letter = "R" },
    { id = "fill",      name = "Flood Fill", key = "f", letter = "F" },
    { id = "eraser",    name = "Eraser",     key = "e", letter = "E" },
    { id = "stamp",     name = "Entity",     key = "s", letter = "S" },
}

-- =========================================================================
-- MapEditor module
-- =========================================================================

local MapEditor = {}

function MapEditor.new(project)
    local self = setmetatable({}, { __index = MapEditor })

    self.project = project or {}
    self.undoStack = UndoStack.new(200)

    -- Layout dimensions
    self.leftPanelWidth = 240
    self.rightPanelWidth = 220

    -- Map data
    self.mapData = nil
    self.mode = "dungeon"

    -- Canvas state
    self.camX = 0
    self.camY = 0
    self.zoom = 1.0
    self.tileSize = 20     -- base tile size in pixels before zoom
    self.showGrid = true

    -- Tool state
    self.activeTool = "paint"
    self.selectedTileId = 1
    self.selectedEntityDef = nil  -- reference to an ENTITY_DEFS entry
    self.selectedEntityCategory = "npc"

    -- Mouse / input state
    self.isPanning = false
    self.panButton = 0
    self.panStartX = 0
    self.panStartY = 0
    self.panStartCamX = 0
    self.panStartCamY = 0
    self.spaceHeld = false

    self.isPainting = false
    self.paintStrokeId = 0       -- incremented each mouse-down for undo coalescing
    self.strokeIdCounter = 0
    self._rightClickErasing = false

    -- Rectangle fill drag state
    self.isRectDragging = false
    self.rectStartTileX = nil
    self.rectStartTileY = nil
    self.rectEndTileX = nil
    self.rectEndTileY = nil

    -- Mouse tile position (for display / cursor highlight)
    self.mouseTileX = nil
    self.mouseTileY = nil
    self.mouseWorldX = 0
    self.mouseWorldY = 0

    -- Selected entity on map (for property editing)
    self.selectedEntity = nil
    self.selectedEntityIndex = nil

    -- Left panel scroll
    self.leftScroll = UI.ScrollContainer.new({ contentHeight = 1200 })
    -- Right panel scroll
    self.rightScroll = UI.ScrollContainer.new({ contentHeight = 800 })

    -- Entity palette collapsed state
    self.entitySectionsCollapsed = {}
    for _, cat in ipairs(ENTITY_CATEGORIES_ORDER) do
        self.entitySectionsCollapsed[cat] = true
    end

    -- Worldgen browser state
    self.worldgenSections = {
        regions = false,        -- collapsed state (false = collapsed)
        towns = false,
        dungeonWeights = false,
    }
    self.selectedRegion = nil           -- region id string
    self.selectedTown = nil             -- town index in anchorTowns array
    self.selectedSubregion = nil        -- subregion id string
    self.worldgenScroll = 0             -- scroll offset for worldgen panel
    self._worldgenClickRects = {}       -- populated during draw

    -- Layer visibility
    self.layerVisibility = {
        terrain = true,
        entities = true,
    }

    -- UI widgets for right panel
    self.nameInput = UI.TextInput.new({
        text = "",
        placeholder = "Map name...",
        onChange = function(text)
            if self.mapData then
                self.mapData.name = text
            end
        end,
    })
    self.widthInput = UI.TextInput.new({
        text = "40",
        placeholder = "Width",
        onChange = function(text)
            self._pendingWidth = tonumber(text)
        end,
    })
    self.heightInput = UI.TextInput.new({
        text = "30",
        placeholder = "Height",
        onChange = function(text)
            self._pendingHeight = tonumber(text)
        end,
    })
    self._pendingWidth = 40
    self._pendingHeight = 30

    -- New map dimension inputs
    self.newWidthInput = UI.TextInput.new({
        text = "40",
        placeholder = "Width",
    })
    self.newHeightInput = UI.TextInput.new({
        text = "30",
        placeholder = "Height",
    })

    -- Theme dropdown state (for town mode)
    self.themeDropdownOpen = false
    self.selectedTheme = "plains"

    -- Resize confirmation modal
    self.resizeModal = UI.Modal.new({
        title = "Resize Map",
        width = 380,
        height = 200,
        message = "Resizing may cause data loss if the new dimensions are smaller. Continue?",
        okText = "Resize",
        cancelText = "Cancel",
        onOk = function()
            self:_doResize()
        end,
    })

    -- Store layout rects (populated in draw)
    self._layoutLeftX = 0
    self._layoutLeftY = 0
    self._layoutLeftW = 0
    self._layoutLeftH = 0
    self._layoutCenterX = 0
    self._layoutCenterY = 0
    self._layoutCenterW = 0
    self._layoutCenterH = 0
    self._layoutRightX = 0
    self._layoutRightY = 0
    self._layoutRightW = 0
    self._layoutRightH = 0

    -- Create a default map
    self:newMap(40, 30, "dungeon")

    return self
end

-- =========================================================================
-- Map creation and management
-- =========================================================================

function MapEditor:newMap(width, height, mode)
    width = math.max(4, math.min(512, width or 40))
    height = math.max(4, math.min(512, height or 30))
    mode = mode or "dungeon"

    local tiles = {}
    local defaultTile = 0
    if mode == "town" then defaultTile = 0 end  -- grass
    if mode == "world" then defaultTile = 0 end  -- grass

    for ty = 1, height do
        tiles[ty] = {}
        for tx = 1, width do
            tiles[ty][tx] = defaultTile
        end
    end

    self.mapData = {
        name = "Untitled " .. mode:sub(1,1):upper() .. mode:sub(2),
        mode = mode,
        width = width,
        height = height,
        theme = "plains",
        tiles = tiles,
        entities = {},
        layers = { "terrain", "entities" },
    }

    self.mode = mode
    self.selectedTileId = (mode == "dungeon") and 1 or 0
    self.selectedEntity = nil
    self.selectedEntityIndex = nil
    self.undoStack:clear()

    -- Update input text
    self.nameInput:setText(self.mapData.name)
    self.widthInput:setText(tostring(width))
    self.heightInput:setText(tostring(height))
    self._pendingWidth = width
    self._pendingHeight = height

    -- Center camera on the map
    self.camX = 0
    self.camY = 0
    self.zoom = 1.0
end

function MapEditor:switchMode(newMode)
    if newMode == self.mode then return end
    -- Create a fresh map for the new mode
    local w = self.mapData and self.mapData.width or 40
    local h = self.mapData and self.mapData.height or 30
    self:newMap(w, h, newMode)
end

function MapEditor:_doResize()
    if not self.mapData then return end
    local newW = self._pendingWidth
    local newH = self._pendingHeight
    if not newW or not newH then return end
    newW = math.max(4, math.min(512, math.floor(newW)))
    newH = math.max(4, math.min(512, math.floor(newH)))

    local oldTiles = deepCopy(self.mapData.tiles)
    local oldW = self.mapData.width
    local oldH = self.mapData.height

    -- Build new tile array
    local newTiles = {}
    local defaultTile = 0
    for ty = 1, newH do
        newTiles[ty] = {}
        for tx = 1, newW do
            if ty <= oldH and tx <= oldW and oldTiles[ty] and oldTiles[ty][tx] then
                newTiles[ty][tx] = oldTiles[ty][tx]
            else
                newTiles[ty][tx] = defaultTile
            end
        end
    end

    -- Push undo
    local mapRef = self.mapData
    local capturedOldTiles = oldTiles
    local capturedOldW = oldW
    local capturedOldH = oldH
    local capturedNewTiles = deepCopy(newTiles)
    local capturedNewW = newW
    local capturedNewH = newH

    self.undoStack:push({
        description = "Resize map to " .. newW .. "x" .. newH,
        execute = function()
            mapRef.tiles = deepCopy(capturedNewTiles)
            mapRef.width = capturedNewW
            mapRef.height = capturedNewH
        end,
        undo = function()
            mapRef.tiles = deepCopy(capturedOldTiles)
            mapRef.width = capturedOldW
            mapRef.height = capturedOldH
        end,
    })

    self.widthInput:setText(tostring(newW))
    self.heightInput:setText(tostring(newH))
end

-- =========================================================================
-- Tile access with bounds checking
-- =========================================================================

function MapEditor:getTile(tx, ty)
    if not self.mapData then return nil end
    if tx < 1 or ty < 1 or tx > self.mapData.width or ty > self.mapData.height then
        return nil
    end
    if not self.mapData.tiles[ty] then return nil end
    return self.mapData.tiles[ty][tx]
end

function MapEditor:setTile(tx, ty, tileId)
    if not self.mapData then return end
    if tx < 1 or ty < 1 or tx > self.mapData.width or ty > self.mapData.height then
        return
    end
    if not self.mapData.tiles[ty] then
        self.mapData.tiles[ty] = {}
    end
    self.mapData.tiles[ty][tx] = tileId
end

-- =========================================================================
-- Coordinate conversions
-- =========================================================================

function MapEditor:screenToWorld(sx, sy)
    local cx = self._layoutCenterX
    local cy = self._layoutCenterY
    local cw = self._layoutCenterW
    local ch = self._layoutCenterH

    -- Origin of the canvas viewport (center of canvas area)
    local viewCenterX = cx + cw / 2
    local viewCenterY = cy + ch / 2

    local wx = (sx - viewCenterX) / self.zoom + self.camX
    local wy = (sy - viewCenterY) / self.zoom + self.camY
    return wx, wy
end

function MapEditor:worldToScreen(wx, wy)
    local cx = self._layoutCenterX
    local cy = self._layoutCenterY
    local cw = self._layoutCenterW
    local ch = self._layoutCenterH

    local viewCenterX = cx + cw / 2
    local viewCenterY = cy + ch / 2

    local sx = (wx - self.camX) * self.zoom + viewCenterX
    local sy = (wy - self.camY) * self.zoom + viewCenterY
    return sx, sy
end

function MapEditor:worldToTile(wx, wy)
    local tx = math.floor(wx / self.tileSize) + 1
    local ty = math.floor(wy / self.tileSize) + 1
    return tx, ty
end

function MapEditor:screenToTile(sx, sy)
    local wx, wy = self:screenToWorld(sx, sy)
    return self:worldToTile(wx, wy)
end

-- =========================================================================
-- Get tile palette for current mode
-- =========================================================================

function MapEditor:getTileDefs()
    return TILE_DEFS_BY_MODE[self.mode] or DUNGEON_TILES
end

function MapEditor:getTileColor(tileId)
    local defs = self:getTileDefs()
    local def = defs[tileId]
    if def then
        return def.color
    end
    return {0.5, 0.0, 0.5}  -- magenta = missing definition
end

function MapEditor:getTileName(tileId)
    local defs = self:getTileDefs()
    local def = defs[tileId]
    if def then return def.name end
    return "?"
end

function MapEditor:getTileCount()
    local defs = self:getTileDefs()
    local maxId = 0
    for id, _ in pairs(defs) do
        if id > maxId then maxId = id end
    end
    return maxId
end

-- =========================================================================
-- Painting operations (with undo)
-- =========================================================================

function MapEditor:paintTile(tx, ty, tileId)
    if not self.mapData then return end
    if tx < 1 or ty < 1 or tx > self.mapData.width or ty > self.mapData.height then
        return
    end

    local oldTile = self:getTile(tx, ty)
    if oldTile == tileId then return end  -- no change

    local mapRef = self.mapData
    local capturedTx = tx
    local capturedTy = ty
    local capturedOld = oldTile
    local capturedNew = tileId

    self.undoStack:coalesce({
        description = "Paint tile",
        execute = function()
            if mapRef.tiles[capturedTy] then
                mapRef.tiles[capturedTy][capturedTx] = capturedNew
            end
        end,
        undo = function()
            if mapRef.tiles[capturedTy] then
                mapRef.tiles[capturedTy][capturedTx] = capturedOld
            end
        end,
    }, self.paintStrokeId)
end

function MapEditor:rectFill(x1, y1, x2, y2, tileId)
    if not self.mapData then return end

    local minX = math.max(1, math.min(x1, x2))
    local maxX = math.min(self.mapData.width, math.max(x1, x2))
    local minY = math.max(1, math.min(y1, y2))
    local maxY = math.min(self.mapData.height, math.max(y1, y2))

    -- Capture old tiles for undo
    local oldTiles = {}
    for ty = minY, maxY do
        for tx = minX, maxX do
            local key = ty .. "," .. tx
            oldTiles[key] = self:getTile(tx, ty)
        end
    end

    local mapRef = self.mapData
    local capturedMin = { x = minX, y = minY }
    local capturedMax = { x = maxX, y = maxY }
    local capturedOld = oldTiles
    local capturedNew = tileId

    self.undoStack:push({
        description = "Rectangle fill",
        execute = function()
            for ty = capturedMin.y, capturedMax.y do
                for tx = capturedMin.x, capturedMax.x do
                    if mapRef.tiles[ty] then
                        mapRef.tiles[ty][tx] = capturedNew
                    end
                end
            end
        end,
        undo = function()
            for ty = capturedMin.y, capturedMax.y do
                for tx = capturedMin.x, capturedMax.x do
                    local key = ty .. "," .. tx
                    if mapRef.tiles[ty] and capturedOld[key] ~= nil then
                        mapRef.tiles[ty][tx] = capturedOld[key]
                    end
                end
            end
        end,
    })
end

function MapEditor:floodFill(startX, startY, newTileId)
    if not self.mapData then return end
    if startX < 1 or startY < 1 or startX > self.mapData.width or startY > self.mapData.height then
        return
    end

    local targetTile = self:getTile(startX, startY)
    if targetTile == nil or targetTile == newTileId then return end

    -- BFS flood fill
    local visited = {}
    local changedTiles = {}  -- {tx, ty, oldTile} for undo
    local queue = { {startX, startY} }
    local mapW = self.mapData.width
    local mapH = self.mapData.height
    local count = 0
    local maxFill = mapW * mapH  -- safety limit

    while #queue > 0 and count < maxFill do
        local pos = table.remove(queue, 1)
        local tx, ty = pos[1], pos[2]
        local key = ty * 10000 + tx

        if not visited[key] and tx >= 1 and tx <= mapW and ty >= 1 and ty <= mapH then
            visited[key] = true
            local current = self:getTile(tx, ty)
            if current == targetTile then
                changedTiles[#changedTiles + 1] = { tx = tx, ty = ty, old = current }
                self.mapData.tiles[ty][tx] = newTileId
                count = count + 1

                queue[#queue + 1] = { tx - 1, ty }
                queue[#queue + 1] = { tx + 1, ty }
                queue[#queue + 1] = { tx, ty - 1 }
                queue[#queue + 1] = { tx, ty + 1 }
            end
        end
    end

    if #changedTiles == 0 then return end

    -- Since we already applied changes, we push an undo that can reverse them
    -- We need to undo what we just did, then the execute re-applies.
    -- But UndoStack:push calls execute() immediately. So we need to structure this
    -- differently: undo restores old tiles, re-execute applies new tiles.
    local mapRef = self.mapData
    local capturedChanges = changedTiles
    local capturedNewTile = newTileId

    -- We already applied the fill, so we skip the initial execute in undo stack.
    -- Instead we push directly onto the stack.
    self.undoStack._undoStack[#self.undoStack._undoStack + 1] = {
        description = "Flood fill",
        execute = function()
            for _, c in ipairs(capturedChanges) do
                if mapRef.tiles[c.ty] then
                    mapRef.tiles[c.ty][c.tx] = capturedNewTile
                end
            end
        end,
        undo = function()
            for _, c in ipairs(capturedChanges) do
                if mapRef.tiles[c.ty] then
                    mapRef.tiles[c.ty][c.tx] = c.old
                end
            end
        end,
    }
    self.undoStack._redoStack = {}
    self.undoStack._lastCoalesceId = nil
    self.undoStack._lastCoalesceTime = 0
end

-- =========================================================================
-- Entity operations
-- =========================================================================

function MapEditor:placeEntity(tx, ty)
    if not self.mapData or not self.selectedEntityDef then return end
    if tx < 1 or ty < 1 or tx > self.mapData.width or ty > self.mapData.height then
        return
    end

    local def = self.selectedEntityDef
    local entity = {
        type = self.selectedEntityCategory,
        id = def.id,
        x = tx,
        y = ty,
        properties = {},
    }

    local mapRef = self.mapData
    local capturedEntity = deepCopy(entity)

    self.undoStack:push({
        description = "Place entity: " .. def.name,
        execute = function()
            mapRef.entities[#mapRef.entities + 1] = deepCopy(capturedEntity)
        end,
        undo = function()
            -- Remove the last entity with matching position and id
            for i = #mapRef.entities, 1, -1 do
                local e = mapRef.entities[i]
                if e.id == capturedEntity.id and e.x == capturedEntity.x and e.y == capturedEntity.y then
                    table.remove(mapRef.entities, i)
                    break
                end
            end
        end,
    })
end

function MapEditor:removeEntity(index)
    if not self.mapData or not index then return end
    if index < 1 or index > #self.mapData.entities then return end

    local removed = deepCopy(self.mapData.entities[index])
    local mapRef = self.mapData
    local capturedIndex = index
    local capturedEntity = removed

    self.undoStack:push({
        description = "Remove entity: " .. removed.id,
        execute = function()
            -- Find and remove by matching
            for i = #mapRef.entities, 1, -1 do
                local e = mapRef.entities[i]
                if e.id == capturedEntity.id and e.x == capturedEntity.x and e.y == capturedEntity.y then
                    table.remove(mapRef.entities, i)
                    break
                end
            end
        end,
        undo = function()
            table.insert(mapRef.entities, capturedIndex, deepCopy(capturedEntity))
        end,
    })

    if self.selectedEntityIndex == index then
        self.selectedEntity = nil
        self.selectedEntityIndex = nil
    end
end

function MapEditor:findEntityAt(tx, ty)
    if not self.mapData then return nil, nil end
    for i = #self.mapData.entities, 1, -1 do
        local e = self.mapData.entities[i]
        if e.x == tx and e.y == ty then
            return e, i
        end
    end
    return nil, nil
end

-- =========================================================================
-- Update
-- =========================================================================

function MapEditor:update(dt)
    self.nameInput:update(dt)
    self.widthInput:update(dt)
    self.heightInput:update(dt)
    self.newWidthInput:update(dt)
    self.newHeightInput:update(dt)

    -- Update space key held state
    self.spaceHeld = love.keyboard.isDown("space")
end

-- =========================================================================
-- Draw
-- =========================================================================

function MapEditor:draw(x, y, w, h)
    -- Compute layout regions
    local lpw = self.leftPanelWidth
    local rpw = self.rightPanelWidth
    local centerX = x + lpw
    local centerW = w - lpw - rpw

    self._layoutLeftX = x
    self._layoutLeftY = y
    self._layoutLeftW = lpw
    self._layoutLeftH = h

    self._layoutCenterX = centerX
    self._layoutCenterY = y
    self._layoutCenterW = centerW
    self._layoutCenterH = h

    self._layoutRightX = x + w - rpw
    self._layoutRightY = y
    self._layoutRightW = rpw
    self._layoutRightH = h

    -- Draw panels
    self:_drawLeftPanel(x, y, lpw, h)
    self:_drawCanvas(centerX, y, centerW, h)
    self:_drawRightPanel(x + w - rpw, y, rpw, h)

    -- Draw modal on top
    self.resizeModal:draw()
end

-- =========================================================================
-- Left Panel
-- =========================================================================

function MapEditor:_drawLeftPanel(px, py, pw, ph)
    -- Background
    setColorSafe(Theme.colors.panel)
    love.graphics.rectangle("fill", px, py, pw, ph)

    -- Right border
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", px + pw - 1, py, 1, ph)

    local font = FontCache.get(13)
    local fontSmall = FontCache.get(11)
    local fontBold = FontCache.getBold(13)
    love.graphics.setFont(font)

    local pad = Theme.spacing.md
    local curY = py + pad

    -- =====================================================================
    -- Mode switch buttons
    -- =====================================================================
    setColorSafe(Theme.colors.text)
    love.graphics.setFont(fontBold)
    love.graphics.print("Mode", px + pad, curY)
    curY = curY + 18

    local modeButtonW = math.floor((pw - pad * 2 - 4) / 3)
    local modeButtonH = 26
    local modes = { "dungeon", "town", "world" }
    local modeLabels = { "Dungeon", "Town", "World" }

    for i, m in ipairs(modes) do
        local bx = px + pad + (i - 1) * (modeButtonW + 2)
        local isActive = (self.mode == m)
        local mx, my = love.mouse.getPosition()
        local isHovered = pointInRect(mx, my, bx, curY, modeButtonW, modeButtonH)

        if isActive then
            setColorSafe(Theme.colors.primary)
        elseif isHovered then
            setColorSafe(Theme.colors.tabHover)
        else
            setColorSafe(Theme.colors.bgLight)
        end
        drawRoundedRect("fill", bx, curY, modeButtonW, modeButtonH, Theme.radius.sm)

        if isActive then
            love.graphics.setColor(0.05, 0.05, 0.08, 1)
        else
            setColorSafe(Theme.colors.text)
        end
        love.graphics.setFont(fontSmall)
        local tw = fontSmall:getWidth(modeLabels[i])
        love.graphics.print(modeLabels[i], bx + math.floor((modeButtonW - tw) / 2),
            curY + math.floor((modeButtonH - fontSmall:getHeight()) / 2))
    end
    curY = curY + modeButtonH + pad

    -- =====================================================================
    -- Active tool indicator
    -- =====================================================================
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", px + pad, curY, pw - pad * 2, 1)
    curY = curY + pad

    love.graphics.setFont(fontBold)
    setColorSafe(Theme.colors.text)
    love.graphics.print("Tool", px + pad, curY)
    curY = curY + 18

    local toolBtnW = math.floor((pw - pad * 2 - 4 * (#TOOLS - 1)) / #TOOLS)
    local toolBtnH = 24
    love.graphics.setFont(fontSmall)

    for i, tool in ipairs(TOOLS) do
        local bx = px + pad + (i - 1) * (toolBtnW + 4)
        local isActive = (self.activeTool == tool.id)
        local mx, my = love.mouse.getPosition()
        local isHovered = pointInRect(mx, my, bx, curY, toolBtnW, toolBtnH)

        if isActive then
            setColorSafe(Theme.colors.primary)
        elseif isHovered then
            setColorSafe(Theme.colors.tabHover)
        else
            setColorSafe(Theme.colors.bgLight)
        end
        drawRoundedRect("fill", bx, curY, toolBtnW, toolBtnH, Theme.radius.sm)

        if isActive then
            love.graphics.setColor(0.05, 0.05, 0.08, 1)
        else
            setColorSafe(Theme.colors.textDim)
        end
        local label = tool.letter
        local ltw = fontSmall:getWidth(label)
        love.graphics.print(label, bx + math.floor((toolBtnW - ltw) / 2),
            curY + math.floor((toolBtnH - fontSmall:getHeight()) / 2))
    end
    curY = curY + toolBtnH + pad

    -- =====================================================================
    -- Tile Palette
    -- =====================================================================
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", px + pad, curY, pw - pad * 2, 1)
    curY = curY + pad

    love.graphics.setFont(fontBold)
    setColorSafe(Theme.colors.text)
    love.graphics.print("Tiles", px + pad, curY)
    curY = curY + 18

    local tileDefs = self:getTileDefs()
    local swatchSize = 28
    local swatchSpacing = 2
    local cols = math.floor((pw - pad * 2 + swatchSpacing) / (swatchSize + swatchSpacing))
    if cols < 1 then cols = 1 end

    love.graphics.setFont(fontSmall)

    -- Iterate tile IDs in order
    local maxTileId = self:getTileCount()
    local tileIndex = 0

    -- Save scissor for left panel clipping
    love.graphics.setScissor(px, py, pw, ph)

    for tileId = 0, maxTileId do
        local def = tileDefs[tileId]
        if def then
            local col = tileIndex % cols
            local row = math.floor(tileIndex / cols)
            local sx = px + pad + col * (swatchSize + swatchSpacing)
            local sy = curY + row * (swatchSize + swatchSpacing)

            -- Only draw if visible
            if sy + swatchSize > py and sy < py + ph then
                -- Swatch background
                setColorSafe(def.color)
                love.graphics.rectangle("fill", sx, sy, swatchSize, swatchSize)

                -- Selection highlight
                if tileId == self.selectedTileId then
                    love.graphics.setColor(1, 1, 1, 0.9)
                    love.graphics.setLineWidth(2)
                    love.graphics.rectangle("line", sx - 1, sy - 1, swatchSize + 2, swatchSize + 2)
                    love.graphics.setLineWidth(1)
                else
                    -- Hover highlight
                    local mx, my = love.mouse.getPosition()
                    if pointInRect(mx, my, sx, sy, swatchSize, swatchSize) then
                        love.graphics.setColor(1, 1, 1, 0.4)
                        love.graphics.setLineWidth(1)
                        love.graphics.rectangle("line", sx, sy, swatchSize, swatchSize)
                    end
                end

                -- Tile ID label inside swatch
                love.graphics.setColor(0, 0, 0, 0.6)
                love.graphics.print(tostring(tileId), sx + 2, sy + 1)
                love.graphics.setColor(1, 1, 1, 0.9)
                love.graphics.print(tostring(tileId), sx + 1, sy)
            end

            tileIndex = tileIndex + 1
        end
    end

    local tileRows = math.ceil((tileIndex) / cols)
    curY = curY + tileRows * (swatchSize + swatchSpacing) + pad

    -- Tile name display
    setColorSafe(Theme.colors.textDim)
    love.graphics.setFont(fontSmall)
    local selName = self:getTileName(self.selectedTileId)
    love.graphics.print("Selected: " .. tostring(self.selectedTileId) .. " - " .. selName, px + pad, curY)
    curY = curY + 16

    -- =====================================================================
    -- Entity Palette
    -- =====================================================================
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", px + pad, curY, pw - pad * 2, 1)
    curY = curY + pad

    love.graphics.setFont(fontBold)
    setColorSafe(Theme.colors.text)
    love.graphics.print("Entities", px + pad, curY)
    curY = curY + 20

    love.graphics.setFont(fontSmall)

    for _, cat in ipairs(ENTITY_CATEGORIES_ORDER) do
        local collapsed = self.entitySectionsCollapsed[cat]
        local headerH = 22
        local mx, my = love.mouse.getPosition()
        local headerHovered = pointInRect(mx, my, px + pad, curY, pw - pad * 2, headerH)

        -- Category header
        if headerHovered then
            setColorSafe(Theme.colors.listItemHover)
        else
            setColorSafe(Theme.colors.bgLight)
        end
        love.graphics.rectangle("fill", px + pad, curY, pw - pad * 2, headerH)

        setColorSafe(Theme.colors.text)
        local arrow = collapsed and "+" or "-"
        love.graphics.print(arrow .. " " .. ENTITY_CATEGORY_LABELS[cat], px + pad + 4,
            curY + math.floor((headerH - fontSmall:getHeight()) / 2))
        curY = curY + headerH + 1

        if not collapsed then
            local ents = ENTITY_DEFS[cat] or {}
            for _, eDef in ipairs(ents) do
                local itemH = 22
                local isSelected = (self.selectedEntityDef == eDef and self.selectedEntityCategory == cat)
                local itemHovered = pointInRect(mx, my, px + pad, curY, pw - pad * 2, itemH)

                if isSelected then
                    setColorSafe(Theme.colors.listItemSelected)
                elseif itemHovered then
                    setColorSafe(Theme.colors.listItemHover)
                end
                if isSelected or itemHovered then
                    love.graphics.rectangle("fill", px + pad, curY, pw - pad * 2, itemH)
                end

                -- Entity letter icon
                setColorSafe(eDef.color)
                love.graphics.print(eDef.letter, px + pad + 6,
                    curY + math.floor((itemH - fontSmall:getHeight()) / 2))

                -- Entity name
                setColorSafe(Theme.colors.text)
                love.graphics.print(eDef.name, px + pad + 22,
                    curY + math.floor((itemH - fontSmall:getHeight()) / 2))

                curY = curY + itemH
            end
        end
    end

    love.graphics.setScissor()

    -- Store content height for potential future scrolling
    self.leftScroll:setContentHeight(curY - py + pad)
end

-- =========================================================================
-- Canvas (center panel)
-- =========================================================================

function MapEditor:_drawCanvas(cx, cy, cw, ch)
    if cw <= 0 or ch <= 0 then return end

    -- Background
    setColorSafe(Theme.colors.bgDark)
    love.graphics.rectangle("fill", cx, cy, cw, ch)

    love.graphics.setScissor(cx, cy, cw, ch)

    if self.mapData then
        local mapW = self.mapData.width
        local mapH = self.mapData.height
        local ts = self.tileSize * self.zoom

        -- View center
        local vcx = cx + cw / 2
        local vcy = cy + ch / 2

        -- Calculate visible tile range
        local worldLeft = self.camX - (cw / 2) / self.zoom
        local worldTop = self.camY - (ch / 2) / self.zoom
        local worldRight = self.camX + (cw / 2) / self.zoom
        local worldBottom = self.camY + (ch / 2) / self.zoom

        local minTX = math.max(1, math.floor(worldLeft / self.tileSize) + 1)
        local minTY = math.max(1, math.floor(worldTop / self.tileSize) + 1)
        local maxTX = math.min(mapW, math.ceil(worldRight / self.tileSize) + 1)
        local maxTY = math.min(mapH, math.ceil(worldBottom / self.tileSize) + 1)

        -- Draw terrain layer
        if self.layerVisibility.terrain then
            for ty = minTY, maxTY do
                for tx = minTX, maxTX do
                    local tileId = self:getTile(tx, ty)
                    if tileId ~= nil then
                        local worldPx = (tx - 1) * self.tileSize
                        local worldPy = (ty - 1) * self.tileSize
                        local screenX = (worldPx - self.camX) * self.zoom + vcx
                        local screenY = (worldPy - self.camY) * self.zoom + vcy

                        local color = self:getTileColor(tileId)
                        setColorSafe(color)
                        love.graphics.rectangle("fill", screenX, screenY, ts, ts)

                        -- Tile border (subtle)
                        if self.zoom >= 0.5 then
                            love.graphics.setColor(color[1] * 0.7, color[2] * 0.7, color[3] * 0.7, 0.5)
                            love.graphics.rectangle("line", screenX, screenY, ts, ts)
                        end
                    end
                end
            end
        end

        -- Draw grid overlay
        if self.showGrid and self.zoom >= 0.4 then
            local gridAlpha = clamp((self.zoom - 0.4) / 0.3, 0.0, 0.3)
            love.graphics.setColor(1, 1, 1, gridAlpha)
            love.graphics.setLineWidth(1)

            -- Vertical lines
            for tx = minTX, maxTX + 1 do
                local worldPx = (tx - 1) * self.tileSize
                local screenX = (worldPx - self.camX) * self.zoom + vcx
                love.graphics.line(screenX, cy, screenX, cy + ch)
            end

            -- Horizontal lines
            for ty = minTY, maxTY + 1 do
                local worldPy = (ty - 1) * self.tileSize
                local screenY = (worldPy - self.camY) * self.zoom + vcy
                love.graphics.line(cx, screenY, cx + cw, screenY)
            end
        end

        -- Draw map boundary
        local mapOriginSX, mapOriginSY = self:worldToScreen(0, 0)
        local mapEndSX, mapEndSY = self:worldToScreen(mapW * self.tileSize, mapH * self.tileSize)
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", mapOriginSX, mapOriginSY,
            mapEndSX - mapOriginSX, mapEndSY - mapOriginSY)
        love.graphics.setLineWidth(1)

        -- Draw entity layer
        if self.layerVisibility.entities and self.mapData.entities then
            local entFont = FontCache.get(math.max(8, math.floor(ts * 0.7)))
            love.graphics.setFont(entFont)

            for i, ent in ipairs(self.mapData.entities) do
                if ent.x >= minTX and ent.x <= maxTX and ent.y >= minTY and ent.y <= maxTY then
                    local worldPx = (ent.x - 1) * self.tileSize
                    local worldPy = (ent.y - 1) * self.tileSize
                    local screenX = (worldPx - self.camX) * self.zoom + vcx
                    local screenY = (worldPy - self.camY) * self.zoom + vcy

                    -- Find entity definition for color/letter
                    local eDef = nil
                    local catDefs = ENTITY_DEFS[ent.type]
                    if catDefs then
                        for _, d in ipairs(catDefs) do
                            if d.id == ent.id then
                                eDef = d
                                break
                            end
                        end
                    end

                    if eDef then
                        -- Entity background circle
                        local centerX = screenX + ts / 2
                        local centerY = screenY + ts / 2
                        local radius = ts * 0.4

                        love.graphics.setColor(0, 0, 0, 0.5)
                        love.graphics.circle("fill", centerX, centerY, radius + 1)
                        setColorSafe(eDef.color)
                        love.graphics.circle("fill", centerX, centerY, radius)

                        -- Entity letter
                        love.graphics.setColor(0, 0, 0, 0.8)
                        local lw = entFont:getWidth(eDef.letter)
                        local lh = entFont:getHeight()
                        love.graphics.print(eDef.letter,
                            centerX - lw / 2 + 1, centerY - lh / 2 + 1)
                        love.graphics.setColor(1, 1, 1, 1)
                        love.graphics.print(eDef.letter,
                            centerX - lw / 2, centerY - lh / 2)

                        -- Selection highlight
                        if i == self.selectedEntityIndex then
                            love.graphics.setColor(1, 1, 0, 0.8)
                            love.graphics.setLineWidth(2)
                            love.graphics.rectangle("line", screenX + 1, screenY + 1, ts - 2, ts - 2)
                            love.graphics.setLineWidth(1)
                        end
                    end
                end
            end
        end

        -- Draw rectangle preview
        if self.isRectDragging and self.rectStartTileX and self.rectEndTileX then
            local rMinX = math.min(self.rectStartTileX, self.rectEndTileX)
            local rMaxX = math.max(self.rectStartTileX, self.rectEndTileX)
            local rMinY = math.min(self.rectStartTileY, self.rectEndTileY)
            local rMaxY = math.max(self.rectStartTileY, self.rectEndTileY)

            local rsx1, rsy1 = self:worldToScreen((rMinX - 1) * self.tileSize, (rMinY - 1) * self.tileSize)
            local rsx2, rsy2 = self:worldToScreen(rMaxX * self.tileSize, rMaxY * self.tileSize)

            local tileColor = self:getTileColor(self.selectedTileId)
            love.graphics.setColor(tileColor[1], tileColor[2], tileColor[3], 0.4)
            love.graphics.rectangle("fill", rsx1, rsy1, rsx2 - rsx1, rsy2 - rsy1)
            love.graphics.setColor(1, 1, 1, 0.7)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", rsx1, rsy1, rsx2 - rsx1, rsy2 - rsy1)
            love.graphics.setLineWidth(1)
        end

        -- Draw brush cursor highlight
        if self.mouseTileX and self.mouseTileY
            and self.mouseTileX >= 1 and self.mouseTileX <= mapW
            and self.mouseTileY >= 1 and self.mouseTileY <= mapH
            and not self.isPanning then

            local worldPx = (self.mouseTileX - 1) * self.tileSize
            local worldPy = (self.mouseTileY - 1) * self.tileSize
            local screenX = (worldPx - self.camX) * self.zoom + vcx
            local screenY = (worldPy - self.camY) * self.zoom + vcy

            if self.activeTool == "stamp" and self.selectedEntityDef then
                love.graphics.setColor(self.selectedEntityDef.color[1],
                    self.selectedEntityDef.color[2], self.selectedEntityDef.color[3], 0.5)
                love.graphics.rectangle("fill", screenX, screenY, ts, ts)
            else
                love.graphics.setColor(1, 1, 1, 0.3)
                love.graphics.rectangle("fill", screenX, screenY, ts, ts)
            end
            love.graphics.setColor(1, 1, 1, 0.6)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", screenX, screenY, ts, ts)
        end
    end

    love.graphics.setScissor()

    -- Status bar at bottom of canvas
    local statusH = 22
    local statusY = cy + ch - statusH
    setColorSafe(Theme.colors.statusBar)
    love.graphics.rectangle("fill", cx, statusY, cw, statusH)
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", cx, statusY, cw, 1)

    local statusFont = FontCache.get(11)
    love.graphics.setFont(statusFont)
    setColorSafe(Theme.colors.statusText)

    local statusParts = {}
    if self.mouseTileX and self.mouseTileY then
        statusParts[#statusParts + 1] = "Tile: " .. self.mouseTileX .. "," .. self.mouseTileY
    end
    statusParts[#statusParts + 1] = "Zoom: " .. string.format("%.0f%%", self.zoom * 100)
    if self.mapData then
        statusParts[#statusParts + 1] = "Size: " .. self.mapData.width .. "x" .. self.mapData.height
    end
    -- Tool name
    for _, tool in ipairs(TOOLS) do
        if tool.id == self.activeTool then
            statusParts[#statusParts + 1] = "Tool: " .. tool.name
            break
        end
    end
    -- Undo/redo count
    statusParts[#statusParts + 1] = "Undo: " .. self.undoStack:getUndoCount()
        .. " / Redo: " .. self.undoStack:getRedoCount()

    local statusText = table.concat(statusParts, "  |  ")
    love.graphics.print(statusText, cx + 6, statusY + math.floor((statusH - statusFont:getHeight()) / 2))
end

-- =========================================================================
-- Right Panel
-- =========================================================================

function MapEditor:_drawRightPanel(px, py, pw, ph)
    -- Background
    setColorSafe(Theme.colors.panel)
    love.graphics.rectangle("fill", px, py, pw, ph)

    -- Left border
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", px, py, 1, ph)

    local font = FontCache.get(13)
    local fontSmall = FontCache.get(11)
    local fontBold = FontCache.getBold(13)
    local pad = Theme.spacing.md
    local contentW = pw - pad * 2
    local curY = py + pad

    love.graphics.setScissor(px, py, pw, ph)

    -- =====================================================================
    -- Map Properties section
    -- =====================================================================
    love.graphics.setFont(fontBold)
    setColorSafe(Theme.colors.textAccent)
    love.graphics.print("Map Properties", px + pad, curY)
    curY = curY + 20

    -- Name
    love.graphics.setFont(fontSmall)
    setColorSafe(Theme.colors.textDim)
    love.graphics.print("Name", px + pad, curY)
    curY = curY + 14
    self.nameInput:draw(px + pad, curY, contentW, 24)
    curY = curY + 28

    -- Width
    setColorSafe(Theme.colors.textDim)
    love.graphics.setFont(fontSmall)
    love.graphics.print("Width", px + pad, curY)
    curY = curY + 14
    self.widthInput:draw(px + pad, curY, contentW, 24)
    curY = curY + 28

    -- Height
    setColorSafe(Theme.colors.textDim)
    love.graphics.setFont(fontSmall)
    love.graphics.print("Height", px + pad, curY)
    curY = curY + 14
    self.heightInput:draw(px + pad, curY, contentW, 24)
    curY = curY + 28

    -- Resize button
    local resizeBtnH = 24
    local mx, my = love.mouse.getPosition()
    local resizeHovered = pointInRect(mx, my, px + pad, curY, contentW, resizeBtnH)

    if resizeHovered then
        setColorSafe(Theme.colors.secondaryHover)
    else
        setColorSafe(Theme.colors.secondary)
    end
    drawRoundedRect("fill", px + pad, curY, contentW, resizeBtnH, Theme.radius.sm)
    love.graphics.setFont(fontSmall)
    love.graphics.setColor(1, 1, 1, 1)
    local resizeLabel = "Resize Map"
    local rlw = fontSmall:getWidth(resizeLabel)
    love.graphics.print(resizeLabel, px + pad + math.floor((contentW - rlw) / 2),
        curY + math.floor((resizeBtnH - fontSmall:getHeight()) / 2))
    -- Store rect for click
    self._resizeBtnRect = { x = px + pad, y = curY, w = contentW, h = resizeBtnH }
    curY = curY + resizeBtnH + pad

    -- =====================================================================
    -- Theme dropdown (town mode only)
    -- =====================================================================
    if self.mode == "town" then
        setColorSafe(Theme.colors.panelBorder)
        love.graphics.rectangle("fill", px + pad, curY, contentW, 1)
        curY = curY + pad

        love.graphics.setFont(fontBold)
        setColorSafe(Theme.colors.textAccent)
        love.graphics.print("Theme", px + pad, curY)
        curY = curY + 18

        -- Dropdown button
        local ddH = 24
        local ddHovered = pointInRect(mx, my, px + pad, curY, contentW, ddH)
        if ddHovered or self.themeDropdownOpen then
            setColorSafe(Theme.colors.inputFocus)
        else
            setColorSafe(Theme.colors.inputBorder)
        end
        love.graphics.setLineWidth(1)
        drawRoundedRect("line", px + pad + 0.5, curY + 0.5, contentW - 1, ddH - 1, Theme.radius.sm)
        setColorSafe(Theme.colors.input)
        drawRoundedRect("fill", px + pad + 1, curY + 1, contentW - 2, ddH - 2, Theme.radius.sm)

        setColorSafe(Theme.colors.text)
        love.graphics.setFont(fontSmall)
        love.graphics.print(self.selectedTheme, px + pad + 6,
            curY + math.floor((ddH - fontSmall:getHeight()) / 2))
        -- dropdown arrow
        love.graphics.print(self.themeDropdownOpen and "-" or "+",
            px + pad + contentW - 16,
            curY + math.floor((ddH - fontSmall:getHeight()) / 2))

        self._themeDropdownRect = { x = px + pad, y = curY, w = contentW, h = ddH }
        curY = curY + ddH

        -- Dropdown list
        if self.themeDropdownOpen then
            local ddListY = curY
            for _, themeName in ipairs(TOWN_THEMES) do
                local itemH = 22
                local itemHovered = pointInRect(mx, my, px + pad, ddListY, contentW, itemH)

                if themeName == self.selectedTheme then
                    setColorSafe(Theme.colors.listItemSelected)
                elseif itemHovered then
                    setColorSafe(Theme.colors.listItemHover)
                else
                    setColorSafe(Theme.colors.input)
                end
                love.graphics.rectangle("fill", px + pad, ddListY, contentW, itemH)

                setColorSafe(Theme.colors.text)
                love.graphics.print(themeName, px + pad + 6,
                    ddListY + math.floor((itemH - fontSmall:getHeight()) / 2))

                ddListY = ddListY + itemH
            end
            -- Store dropdown list area
            self._themeDropdownListRect = {
                x = px + pad, y = curY, w = contentW,
                h = #TOWN_THEMES * 22,
            }
            curY = ddListY
        end

        curY = curY + pad
    end

    -- =====================================================================
    -- New Map section
    -- =====================================================================
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", px + pad, curY, contentW, 1)
    curY = curY + pad

    love.graphics.setFont(fontBold)
    setColorSafe(Theme.colors.textAccent)
    love.graphics.print("New Map", px + pad, curY)
    curY = curY + 20

    love.graphics.setFont(fontSmall)
    setColorSafe(Theme.colors.textDim)
    love.graphics.print("Width", px + pad, curY)
    curY = curY + 14
    self.newWidthInput:draw(px + pad, curY, contentW, 24)
    curY = curY + 28

    setColorSafe(Theme.colors.textDim)
    love.graphics.print("Height", px + pad, curY)
    curY = curY + 14
    self.newHeightInput:draw(px + pad, curY, contentW, 24)
    curY = curY + 28

    -- Create button
    local createBtnH = 26
    local createHovered = pointInRect(mx, my, px + pad, curY, contentW, createBtnH)
    if createHovered then
        setColorSafe(Theme.colors.primaryHover)
    else
        setColorSafe(Theme.colors.primary)
    end
    drawRoundedRect("fill", px + pad, curY, contentW, createBtnH, Theme.radius.sm)
    love.graphics.setColor(0.05, 0.05, 0.08, 1)
    love.graphics.setFont(fontSmall)
    local createLabel = "Create New Map"
    local clw = fontSmall:getWidth(createLabel)
    love.graphics.print(createLabel, px + pad + math.floor((contentW - clw) / 2),
        curY + math.floor((createBtnH - fontSmall:getHeight()) / 2))
    self._createBtnRect = { x = px + pad, y = curY, w = contentW, h = createBtnH }
    curY = curY + createBtnH + pad

    -- =====================================================================
    -- Layers section
    -- =====================================================================
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", px + pad, curY, contentW, 1)
    curY = curY + pad

    love.graphics.setFont(fontBold)
    setColorSafe(Theme.colors.textAccent)
    love.graphics.print("Layers", px + pad, curY)
    curY = curY + 20

    love.graphics.setFont(fontSmall)
    local layerNames = { "terrain", "entities" }
    local layerLabels = { terrain = "Terrain", entities = "Entities" }

    for _, layerName in ipairs(layerNames) do
        local itemH = 22
        local visible = self.layerVisibility[layerName]
        local layerHovered = pointInRect(mx, my, px + pad, curY, contentW, itemH)

        if layerHovered then
            setColorSafe(Theme.colors.listItemHover)
            love.graphics.rectangle("fill", px + pad, curY, contentW, itemH)
        end

        -- Visibility indicator
        if visible then
            setColorSafe(Theme.colors.success)
        else
            setColorSafe(Theme.colors.textDark)
        end
        love.graphics.print(visible and "[x]" or "[ ]", px + pad + 4,
            curY + math.floor((itemH - fontSmall:getHeight()) / 2))

        setColorSafe(Theme.colors.text)
        love.graphics.print(layerLabels[layerName] or layerName, px + pad + 30,
            curY + math.floor((itemH - fontSmall:getHeight()) / 2))

        -- Store rect
        if not self._layerRects then self._layerRects = {} end
        self._layerRects[layerName] = { x = px + pad, y = curY, w = contentW, h = itemH }

        curY = curY + itemH
    end
    curY = curY + pad

    -- =====================================================================
    -- Worldgen Data Browser (world mode only)
    -- =====================================================================
    if self.mode == "world" then
        curY = self:_drawWorldgenBrowser(px, curY, pw, ph, pad, contentW, fontBold, fontSmall, mx, my)
    end

    -- =====================================================================
    -- Selected Entity Properties
    -- =====================================================================
    if self.selectedEntity then
        setColorSafe(Theme.colors.panelBorder)
        love.graphics.rectangle("fill", px + pad, curY, contentW, 1)
        curY = curY + pad

        love.graphics.setFont(fontBold)
        setColorSafe(Theme.colors.textAccent)
        love.graphics.print("Entity", px + pad, curY)
        curY = curY + 20

        love.graphics.setFont(fontSmall)
        setColorSafe(Theme.colors.textDim)
        love.graphics.print("Type: ", px + pad, curY)
        setColorSafe(Theme.colors.text)
        love.graphics.print(self.selectedEntity.type or "?", px + pad + 40, curY)
        curY = curY + 16

        setColorSafe(Theme.colors.textDim)
        love.graphics.print("ID: ", px + pad, curY)
        setColorSafe(Theme.colors.text)
        love.graphics.print(self.selectedEntity.id or "?", px + pad + 40, curY)
        curY = curY + 16

        setColorSafe(Theme.colors.textDim)
        love.graphics.print("Pos: ", px + pad, curY)
        setColorSafe(Theme.colors.text)
        love.graphics.print(self.selectedEntity.x .. ", " .. self.selectedEntity.y, px + pad + 40, curY)
        curY = curY + 16

        -- Delete entity button
        curY = curY + 4
        local delBtnH = 24
        local delHovered = pointInRect(mx, my, px + pad, curY, contentW, delBtnH)
        if delHovered then
            setColorSafe(Theme.colors.dangerHover)
        else
            setColorSafe(Theme.colors.danger)
        end
        drawRoundedRect("fill", px + pad, curY, contentW, delBtnH, Theme.radius.sm)
        love.graphics.setColor(1, 1, 1, 1)
        local delLabel = "Delete Entity"
        local dlw = fontSmall:getWidth(delLabel)
        love.graphics.print(delLabel, px + pad + math.floor((contentW - dlw) / 2),
            curY + math.floor((delBtnH - fontSmall:getHeight()) / 2))
        self._deleteEntityBtnRect = { x = px + pad, y = curY, w = contentW, h = delBtnH }
        curY = curY + delBtnH + pad
    else
        self._deleteEntityBtnRect = nil
    end

    love.graphics.setScissor()

    self.rightScroll:setContentHeight(curY - py + pad)
end

-- =========================================================================
-- Worldgen Data Browser (drawn inside right panel in world mode)
-- =========================================================================

function MapEditor:_drawWorldgenBrowser(px, curY, pw, ph, pad, contentW, fontBold, fontSmall, mx, my)
    local wg = self.project and self.project.worldgen
    self._worldgenClickRects = {}

    -- Section separator
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", px + pad, curY, contentW, 1)
    curY = curY + pad

    -- Section title
    love.graphics.setFont(fontBold)
    setColorSafe(Theme.colors.textAccent)
    love.graphics.print("Worldgen Data", px + pad, curY)
    curY = curY + 20

    -- Check if data exists
    if not wg or (not wg.regions and not wg.anchorTowns and not wg.dungeonWeights) then
        love.graphics.setFont(fontSmall)
        setColorSafe(Theme.colors.textDim)
        love.graphics.print("No data imported", px + pad + 4, curY)
        curY = curY + 18
        return curY
    end

    love.graphics.setFont(fontSmall)
    local itemH = 20
    local subItemH = 18

    -- =================================================================
    -- Regions section
    -- =================================================================
    local regionCount = 0
    if wg.regions then
        for _ in pairs(wg.regions) do regionCount = regionCount + 1 end
    end

    local regHeaderH = 22
    local regHeaderHovered = pointInRect(mx, my, px + pad, curY, contentW, regHeaderH)
    if regHeaderHovered then
        setColorSafe(Theme.colors.listItemHover)
    else
        setColorSafe(Theme.colors.bgLight)
    end
    love.graphics.rectangle("fill", px + pad, curY, contentW, regHeaderH)

    setColorSafe(Theme.colors.text)
    local regArrow = self.worldgenSections.regions and "-" or "+"
    love.graphics.print(regArrow .. " Regions (" .. regionCount .. ")", px + pad + 4,
        curY + math.floor((regHeaderH - fontSmall:getHeight()) / 2))
    self._worldgenClickRects[#self._worldgenClickRects + 1] = {
        type = "sectionToggle", section = "regions",
        rect = { x = px + pad, y = curY, w = contentW, h = regHeaderH },
    }
    curY = curY + regHeaderH + 1

    if self.worldgenSections.regions and wg.regions then
        -- Sort region keys for consistent ordering
        local regionKeys = {}
        for k in pairs(wg.regions) do
            regionKeys[#regionKeys + 1] = k
        end
        table.sort(regionKeys)

        for _, rKey in ipairs(regionKeys) do
            local region = wg.regions[rKey]
            if region then
                local isSelected = (self.selectedRegion == rKey and self.selectedSubregion == nil)
                local rHovered = pointInRect(mx, my, px + pad, curY, contentW, itemH)

                if isSelected then
                    setColorSafe(Theme.colors.listItemSelected)
                    love.graphics.rectangle("fill", px + pad, curY, contentW, itemH)
                elseif rHovered then
                    setColorSafe(Theme.colors.listItemHover)
                    love.graphics.rectangle("fill", px + pad, curY, contentW, itemH)
                end

                setColorSafe(Theme.colors.text)
                local rName = region.name or rKey
                if fontSmall:getWidth(rName) > contentW - 12 then
                    -- Truncate long names
                    while fontSmall:getWidth(rName .. "...") > contentW - 12 and #rName > 1 do
                        rName = rName:sub(1, #rName - 1)
                    end
                    rName = rName .. "..."
                end
                love.graphics.print(rName, px + pad + 6,
                    curY + math.floor((itemH - fontSmall:getHeight()) / 2))

                self._worldgenClickRects[#self._worldgenClickRects + 1] = {
                    type = "region", id = rKey,
                    rect = { x = px + pad, y = curY, w = contentW, h = itemH },
                }
                curY = curY + itemH

                -- Subregions (shown when this region is selected)
                if self.selectedRegion == rKey and region.subregions then
                    for _, sub in ipairs(region.subregions) do
                        local subSelected = (self.selectedSubregion == sub.id)
                        local subHovered = pointInRect(mx, my, px + pad, curY, contentW, subItemH)

                        if subSelected then
                            setColorSafe(Theme.colors.listItemSelected)
                            love.graphics.rectangle("fill", px + pad, curY, contentW, subItemH)
                        elseif subHovered then
                            setColorSafe(Theme.colors.listItemHover)
                            love.graphics.rectangle("fill", px + pad, curY, contentW, subItemH)
                        end

                        setColorSafe(Theme.colors.textDim)
                        love.graphics.print("-", px + pad + 12,
                            curY + math.floor((subItemH - fontSmall:getHeight()) / 2))
                        setColorSafe(Theme.colors.text)
                        local sName = sub.name or sub.id or "?"
                        if fontSmall:getWidth(sName) > contentW - 28 then
                            while fontSmall:getWidth(sName .. "...") > contentW - 28 and #sName > 1 do
                                sName = sName:sub(1, #sName - 1)
                            end
                            sName = sName .. "..."
                        end
                        love.graphics.print(sName, px + pad + 20,
                            curY + math.floor((subItemH - fontSmall:getHeight()) / 2))

                        self._worldgenClickRects[#self._worldgenClickRects + 1] = {
                            type = "subregion", id = sub.id, parentRegion = rKey,
                            rect = { x = px + pad, y = curY, w = contentW, h = subItemH },
                        }
                        curY = curY + subItemH
                    end
                end
            end
        end
    end

    curY = curY + 2

    -- =================================================================
    -- Anchor Towns section
    -- =================================================================
    local townCount = wg.anchorTowns and #wg.anchorTowns or 0

    local townHeaderH = 22
    local townHeaderHovered = pointInRect(mx, my, px + pad, curY, contentW, townHeaderH)
    if townHeaderHovered then
        setColorSafe(Theme.colors.listItemHover)
    else
        setColorSafe(Theme.colors.bgLight)
    end
    love.graphics.rectangle("fill", px + pad, curY, contentW, townHeaderH)

    setColorSafe(Theme.colors.text)
    local townArrow = self.worldgenSections.towns and "-" or "+"
    love.graphics.print(townArrow .. " Anchor Towns (" .. townCount .. ")", px + pad + 4,
        curY + math.floor((townHeaderH - fontSmall:getHeight()) / 2))
    self._worldgenClickRects[#self._worldgenClickRects + 1] = {
        type = "sectionToggle", section = "towns",
        rect = { x = px + pad, y = curY, w = contentW, h = townHeaderH },
    }
    curY = curY + townHeaderH + 1

    if self.worldgenSections.towns and wg.anchorTowns then
        for i, town in ipairs(wg.anchorTowns) do
            local isSelected = (self.selectedTown == i)
            local tHovered = pointInRect(mx, my, px + pad, curY, contentW, itemH)

            if isSelected then
                setColorSafe(Theme.colors.listItemSelected)
                love.graphics.rectangle("fill", px + pad, curY, contentW, itemH)
            elseif tHovered then
                setColorSafe(Theme.colors.listItemHover)
                love.graphics.rectangle("fill", px + pad, curY, contentW, itemH)
            end

            setColorSafe(Theme.colors.text)
            local tName = town.name or town.id or ("Town " .. i)
            -- Add type/level tag
            local tag = ""
            if town.type or town.level then
                local parts = {}
                if town.type then parts[#parts + 1] = town.type end
                if town.level then parts[#parts + 1] = "Lv" .. town.level end
                tag = " [" .. table.concat(parts, ", ") .. "]"
            end
            local fullLabel = tName .. tag
            if fontSmall:getWidth(fullLabel) > contentW - 12 then
                -- Truncate name but keep tag
                while fontSmall:getWidth(tName .. "..." .. tag) > contentW - 12 and #tName > 1 do
                    tName = tName:sub(1, #tName - 1)
                end
                fullLabel = tName .. "..." .. tag
            end
            love.graphics.print(fullLabel, px + pad + 6,
                curY + math.floor((itemH - fontSmall:getHeight()) / 2))

            self._worldgenClickRects[#self._worldgenClickRects + 1] = {
                type = "town", index = i,
                rect = { x = px + pad, y = curY, w = contentW, h = itemH },
            }
            curY = curY + itemH
        end
    end

    curY = curY + 2

    -- =================================================================
    -- Dungeon Weights section
    -- =================================================================
    local dwCount = 0
    if wg.dungeonWeights then
        for _ in pairs(wg.dungeonWeights) do dwCount = dwCount + 1 end
    end

    local dwHeaderH = 22
    local dwHeaderHovered = pointInRect(mx, my, px + pad, curY, contentW, dwHeaderH)
    if dwHeaderHovered then
        setColorSafe(Theme.colors.listItemHover)
    else
        setColorSafe(Theme.colors.bgLight)
    end
    love.graphics.rectangle("fill", px + pad, curY, contentW, dwHeaderH)

    setColorSafe(Theme.colors.text)
    local dwArrow = self.worldgenSections.dungeonWeights and "-" or "+"
    love.graphics.print(dwArrow .. " Dungeon Weights (" .. dwCount .. ")", px + pad + 4,
        curY + math.floor((dwHeaderH - fontSmall:getHeight()) / 2))
    self._worldgenClickRects[#self._worldgenClickRects + 1] = {
        type = "sectionToggle", section = "dungeonWeights",
        rect = { x = px + pad, y = curY, w = contentW, h = dwHeaderH },
    }
    curY = curY + dwHeaderH + 1

    if self.worldgenSections.dungeonWeights and wg.dungeonWeights then
        -- Sort keys for consistent ordering
        local dwKeys = {}
        for k in pairs(wg.dungeonWeights) do
            dwKeys[#dwKeys + 1] = k
        end
        table.sort(dwKeys)

        for _, dwKey in ipairs(dwKeys) do
            local weights = wg.dungeonWeights[dwKey]
            if weights then
                -- Build weight summary string
                local parts = {}
                -- Sort weight keys too
                local wKeys = {}
                for wk in pairs(weights) do
                    wKeys[#wKeys + 1] = wk
                end
                table.sort(wKeys)
                for _, wk in ipairs(wKeys) do
                    parts[#parts + 1] = wk .. " " .. string.format("%.1f", weights[wk])
                end
                local summary = table.concat(parts, ", ")

                -- Region name label
                setColorSafe(Theme.colors.text)
                love.graphics.print(dwKey, px + pad + 6,
                    curY + math.floor((subItemH - fontSmall:getHeight()) / 2))
                curY = curY + subItemH

                -- Weight values (indented, possibly wrapped)
                setColorSafe(Theme.colors.textDim)
                if fontSmall:getWidth(summary) > contentW - 18 then
                    -- Wrap into multiple lines
                    local line = ""
                    for _, part in ipairs(parts) do
                        local test = line
                        if #test > 0 then test = test .. ", " end
                        test = test .. part
                        if fontSmall:getWidth(test) > contentW - 18 and #line > 0 then
                            love.graphics.print(line, px + pad + 12,
                                curY + math.floor((subItemH - fontSmall:getHeight()) / 2))
                            curY = curY + subItemH
                            line = part
                        else
                            line = test
                        end
                    end
                    if #line > 0 then
                        love.graphics.print(line, px + pad + 12,
                            curY + math.floor((subItemH - fontSmall:getHeight()) / 2))
                        curY = curY + subItemH
                    end
                else
                    love.graphics.print(summary, px + pad + 12,
                        curY + math.floor((subItemH - fontSmall:getHeight()) / 2))
                    curY = curY + subItemH
                end
            end
        end
    end

    curY = curY + pad

    -- =================================================================
    -- Selected Worldgen Details
    -- =================================================================
    local hasSelection = self.selectedRegion or self.selectedTown or self.selectedSubregion
    if hasSelection then
        setColorSafe(Theme.colors.panelBorder)
        love.graphics.rectangle("fill", px + pad, curY, contentW, 1)
        curY = curY + pad

        love.graphics.setFont(fontBold)
        setColorSafe(Theme.colors.textAccent)
        love.graphics.print("Selected Details", px + pad, curY)
        curY = curY + 20

        love.graphics.setFont(fontSmall)

        if self.selectedSubregion and self.selectedRegion and wg.regions then
            -- Show subregion details
            local region = wg.regions[self.selectedRegion]
            if region and region.subregions then
                local sub = nil
                for _, s in ipairs(region.subregions) do
                    if s.id == self.selectedSubregion then
                        sub = s
                        break
                    end
                end
                if sub then
                    curY = self:_drawWorldgenDetail(px, curY, pad, contentW, fontSmall, "Name", sub.name or sub.id)
                    curY = self:_drawWorldgenDetail(px, curY, pad, contentW, fontSmall, "Terrain", sub.terrain or "?")
                    if sub.terrainWeight then
                        curY = self:_drawWorldgenDetail(px, curY, pad, contentW, fontSmall, "Weight",
                            string.format("%.2f", sub.terrainWeight))
                    end
                    if sub.bounds then
                        local b = sub.bounds
                        curY = self:_drawWorldgenDetail(px, curY, pad, contentW, fontSmall, "Bounds",
                            (b.x1 or "?") .. "," .. (b.y1 or "?") .. " - " .. (b.x2 or "?") .. "," .. (b.y2 or "?"))
                    end
                    if sub.altTerrain then
                        local altParts = {}
                        if type(sub.altTerrain) == "table" then
                            for ak, av in pairs(sub.altTerrain) do
                                if type(ak) == "number" then
                                    altParts[#altParts + 1] = tostring(av)
                                else
                                    altParts[#altParts + 1] = ak .. "=" .. tostring(av)
                                end
                            end
                        end
                        if #altParts > 0 then
                            curY = self:_drawWorldgenDetail(px, curY, pad, contentW, fontSmall, "Alt Terrain",
                                table.concat(altParts, ", "))
                        end
                    end
                end
            end

        elseif self.selectedRegion and wg.regions then
            -- Show region details
            local region = wg.regions[self.selectedRegion]
            if region then
                curY = self:_drawWorldgenDetail(px, curY, pad, contentW, fontSmall, "Name", region.name or region.id)
                curY = self:_drawWorldgenDetail(px, curY, pad, contentW, fontSmall, "ID", region.id or self.selectedRegion)
                if region.defaultTerrain then
                    curY = self:_drawWorldgenDetail(px, curY, pad, contentW, fontSmall, "Terrain", region.defaultTerrain)
                end
                if region.bounds then
                    local b = region.bounds
                    curY = self:_drawWorldgenDetail(px, curY, pad, contentW, fontSmall, "Bounds",
                        (b.x1 or "?") .. "," .. (b.y1 or "?") .. " - " .. (b.x2 or "?") .. "," .. (b.y2 or "?"))
                end
                local subCount = region.subregions and #region.subregions or 0
                curY = self:_drawWorldgenDetail(px, curY, pad, contentW, fontSmall, "Subregions", tostring(subCount))
            end

        elseif self.selectedTown and wg.anchorTowns then
            -- Show town details
            local town = wg.anchorTowns[self.selectedTown]
            if town then
                curY = self:_drawWorldgenDetail(px, curY, pad, contentW, fontSmall, "Name", town.name or town.id)
                if town.region then
                    curY = self:_drawWorldgenDetail(px, curY, pad, contentW, fontSmall, "Region", town.region)
                end
                if town.level then
                    curY = self:_drawWorldgenDetail(px, curY, pad, contentW, fontSmall, "Level", tostring(town.level))
                end
                if town.type then
                    curY = self:_drawWorldgenDetail(px, curY, pad, contentW, fontSmall, "Type", town.type)
                end
                if town.population then
                    curY = self:_drawWorldgenDetail(px, curY, pad, contentW, fontSmall, "Population", tostring(town.population))
                end
                if town.position then
                    curY = self:_drawWorldgenDetail(px, curY, pad, contentW, fontSmall, "Position",
                        (town.position.x or "?") .. ", " .. (town.position.y or "?"))
                end
                if town.landmarks then
                    local lmNames = {}
                    if type(town.landmarks) == "table" then
                        for _, lm in ipairs(town.landmarks) do
                            if type(lm) == "string" then
                                lmNames[#lmNames + 1] = lm
                            elseif type(lm) == "table" and lm.name then
                                lmNames[#lmNames + 1] = lm.name
                            elseif type(lm) == "table" and lm.id then
                                lmNames[#lmNames + 1] = lm.id
                            end
                        end
                    end
                    if #lmNames > 0 then
                        curY = self:_drawWorldgenDetail(px, curY, pad, contentW, fontSmall, "Landmarks",
                            table.concat(lmNames, ", "))
                    end
                end
                if town.fixedNPCs then
                    local npcNames = {}
                    if type(town.fixedNPCs) == "table" then
                        for _, npc in ipairs(town.fixedNPCs) do
                            if type(npc) == "string" then
                                npcNames[#npcNames + 1] = npc
                            elseif type(npc) == "table" and npc.name then
                                npcNames[#npcNames + 1] = npc.name
                            elseif type(npc) == "table" and npc.id then
                                npcNames[#npcNames + 1] = npc.id
                            end
                        end
                    end
                    if #npcNames > 0 then
                        curY = self:_drawWorldgenDetail(px, curY, pad, contentW, fontSmall, "NPCs",
                            table.concat(npcNames, ", "))
                    end
                end
                if town.description then
                    curY = curY + 4
                    setColorSafe(Theme.colors.textDim)
                    love.graphics.print("Description:", px + pad, curY)
                    curY = curY + 14
                    -- Word-wrap description text
                    local desc = tostring(town.description)
                    local wrapWidth = contentW - 4
                    local _, wrappedLines = fontSmall:getWrap(desc, wrapWidth)
                    setColorSafe(Theme.colors.text)
                    for _, line in ipairs(wrappedLines) do
                        love.graphics.print(line, px + pad + 2, curY)
                        curY = curY + fontSmall:getHeight() + 1
                    end
                end
            end
        end
    end

    return curY
end

-- Helper to draw a single detail key-value line in worldgen details panel
function MapEditor:_drawWorldgenDetail(px, curY, pad, contentW, fontSmall, label, value)
    local lineH = 16
    setColorSafe(Theme.colors.textDim)
    love.graphics.print(label .. ":", px + pad, curY)
    local labelW = fontSmall:getWidth(label .. ": ")
    setColorSafe(Theme.colors.text)
    local val = tostring(value)
    local maxValW = contentW - labelW - 4
    if fontSmall:getWidth(val) > maxValW and maxValW > 20 then
        -- Wrap value text
        local _, wrappedLines = fontSmall:getWrap(val, maxValW)
        for li, line in ipairs(wrappedLines) do
            if li == 1 then
                love.graphics.print(line, px + pad + labelW, curY)
            else
                curY = curY + lineH
                love.graphics.print(line, px + pad + labelW, curY)
            end
        end
    else
        love.graphics.print(val, px + pad + labelW, curY)
    end
    curY = curY + lineH
    return curY
end

-- =========================================================================
-- Input: mousepressed
-- =========================================================================

function MapEditor:mousepressed(mx, my, button)
    -- Modal first
    if self.resizeModal.visible then
        self.resizeModal:mousepressed(mx, my, button)
        return true
    end

    -- Theme dropdown (close if clicking outside)
    if self.themeDropdownOpen then
        if self._themeDropdownListRect and
            pointInRect(mx, my, self._themeDropdownListRect.x, self._themeDropdownListRect.y,
                self._themeDropdownListRect.w, self._themeDropdownListRect.h) then
            -- Click on dropdown item
            local relY = my - self._themeDropdownListRect.y
            local idx = math.floor(relY / 22) + 1
            if idx >= 1 and idx <= #TOWN_THEMES then
                self.selectedTheme = TOWN_THEMES[idx]
                if self.mapData then
                    self.mapData.theme = self.selectedTheme
                end
            end
            self.themeDropdownOpen = false
            return true
        else
            self.themeDropdownOpen = false
            -- Fall through to other click handling
        end
    end

    -- Right panel widgets
    if pointInRect(mx, my, self._layoutRightX, self._layoutRightY,
            self._layoutRightW, self._layoutRightH) then

        -- Text inputs
        if self.nameInput:mousepressed(mx, my, button) then return true end
        if self.widthInput:mousepressed(mx, my, button) then return true end
        if self.heightInput:mousepressed(mx, my, button) then return true end
        if self.newWidthInput:mousepressed(mx, my, button) then return true end
        if self.newHeightInput:mousepressed(mx, my, button) then return true end

        -- Resize button
        if self._resizeBtnRect and button == 1 and
            pointInRect(mx, my, self._resizeBtnRect.x, self._resizeBtnRect.y,
                self._resizeBtnRect.w, self._resizeBtnRect.h) then
            -- Check if shrinking
            local newW = self._pendingWidth or (self.mapData and self.mapData.width)
            local newH = self._pendingHeight or (self.mapData and self.mapData.height)
            if self.mapData and (newW < self.mapData.width or newH < self.mapData.height) then
                self.resizeModal:show()
            else
                self:_doResize()
            end
            return true
        end

        -- Theme dropdown toggle
        if self._themeDropdownRect and button == 1 and self.mode == "town" and
            pointInRect(mx, my, self._themeDropdownRect.x, self._themeDropdownRect.y,
                self._themeDropdownRect.w, self._themeDropdownRect.h) then
            self.themeDropdownOpen = not self.themeDropdownOpen
            return true
        end

        -- Create new map button
        if self._createBtnRect and button == 1 and
            pointInRect(mx, my, self._createBtnRect.x, self._createBtnRect.y,
                self._createBtnRect.w, self._createBtnRect.h) then
            local nw = tonumber(self.newWidthInput:getText()) or 40
            local nh = tonumber(self.newHeightInput:getText()) or 30
            self:newMap(nw, nh, self.mode)
            return true
        end

        -- Layer toggles
        if self._layerRects and button == 1 then
            for layerName, rect in pairs(self._layerRects) do
                if pointInRect(mx, my, rect.x, rect.y, rect.w, rect.h) then
                    self.layerVisibility[layerName] = not self.layerVisibility[layerName]
                    return true
                end
            end
        end

        -- Worldgen browser clicks (world mode only)
        if self._worldgenClickRects and button == 1 and self.mode == "world" then
            for _, entry in ipairs(self._worldgenClickRects) do
                local r = entry.rect
                if pointInRect(mx, my, r.x, r.y, r.w, r.h) then
                    if entry.type == "sectionToggle" then
                        self.worldgenSections[entry.section] = not self.worldgenSections[entry.section]
                        return true
                    elseif entry.type == "region" then
                        if self.selectedRegion == entry.id and self.selectedSubregion == nil then
                            -- Clicking the already-selected region deselects it
                            self.selectedRegion = nil
                        else
                            self.selectedRegion = entry.id
                            self.selectedSubregion = nil
                        end
                        self.selectedTown = nil
                        return true
                    elseif entry.type == "subregion" then
                        if self.selectedSubregion == entry.id then
                            -- Clicking the already-selected subregion deselects it
                            self.selectedSubregion = nil
                        else
                            self.selectedSubregion = entry.id
                            self.selectedRegion = entry.parentRegion
                        end
                        self.selectedTown = nil
                        return true
                    elseif entry.type == "town" then
                        if self.selectedTown == entry.index then
                            self.selectedTown = nil
                        else
                            self.selectedTown = entry.index
                        end
                        self.selectedRegion = nil
                        self.selectedSubregion = nil
                        return true
                    end
                end
            end
        end

        -- Delete entity button
        if self._deleteEntityBtnRect and button == 1 and
            pointInRect(mx, my, self._deleteEntityBtnRect.x, self._deleteEntityBtnRect.y,
                self._deleteEntityBtnRect.w, self._deleteEntityBtnRect.h) then
            if self.selectedEntityIndex then
                self:removeEntity(self.selectedEntityIndex)
            end
            return true
        end

        return true
    end

    -- Left panel clicks
    if pointInRect(mx, my, self._layoutLeftX, self._layoutLeftY,
            self._layoutLeftW, self._layoutLeftH) then
        local lpx = self._layoutLeftX
        local lpy = self._layoutLeftY
        local lpw = self._layoutLeftW
        local lph = self._layoutLeftH
        local pad = Theme.spacing.md

        -- Mode buttons
        local modeButtonW = math.floor((lpw - pad * 2 - 4) / 3)
        local modeButtonH = 26
        local modeY = lpy + pad + 18  -- after "Mode" label

        if button == 1 then
            local modes = { "dungeon", "town", "world" }
            for i, m in ipairs(modes) do
                local bx = lpx + pad + (i - 1) * (modeButtonW + 2)
                if pointInRect(mx, my, bx, modeY, modeButtonW, modeButtonH) then
                    self:switchMode(m)
                    return true
                end
            end

            -- Tool buttons
            local toolY = modeY + modeButtonH + pad + pad + 18 + 1  -- after separator and "Tool" label
            local toolBtnW = math.floor((lpw - pad * 2 - 4 * (#TOOLS - 1)) / #TOOLS)
            local toolBtnH = 24

            for i, tool in ipairs(TOOLS) do
                local bx = lpx + pad + (i - 1) * (toolBtnW + 4)
                if pointInRect(mx, my, bx, toolY, toolBtnW, toolBtnH) then
                    self.activeTool = tool.id
                    return true
                end
            end

            -- Tile palette clicks
            local tileHeaderY = toolY + toolBtnH + pad + pad + 18 + 1  -- after separator and "Tiles" label
            local swatchSize = 28
            local swatchSpacing = 2
            local cols = math.floor((lpw - pad * 2 + swatchSpacing) / (swatchSize + swatchSpacing))
            if cols < 1 then cols = 1 end

            local tileDefs = self:getTileDefs()
            local maxTileId = self:getTileCount()
            local tileIndex = 0

            for tileId = 0, maxTileId do
                local def = tileDefs[tileId]
                if def then
                    local col = tileIndex % cols
                    local row = math.floor(tileIndex / cols)
                    local sx = lpx + pad + col * (swatchSize + swatchSpacing)
                    local sy = tileHeaderY + row * (swatchSize + swatchSpacing)

                    if pointInRect(mx, my, sx, sy, swatchSize, swatchSize) then
                        self.selectedTileId = tileId
                        -- Auto-switch to paint tool when selecting a tile
                        if self.activeTool == "stamp" then
                            self.activeTool = "paint"
                        end
                        return true
                    end
                    tileIndex = tileIndex + 1
                end
            end

            -- Entity palette clicks
            -- Need to reconstruct the layout positions... find the entity section start
            local tileRows = math.ceil(tileIndex / cols)
            local entityStartY = tileHeaderY + tileRows * (swatchSize + swatchSpacing) + pad + 16
            entityStartY = entityStartY + pad + 20 + 1  -- after separator + "Entities" label

            local entY = entityStartY
            for _, cat in ipairs(ENTITY_CATEGORIES_ORDER) do
                local headerH = 22
                if pointInRect(mx, my, lpx + pad, entY, lpw - pad * 2, headerH) then
                    self.entitySectionsCollapsed[cat] = not self.entitySectionsCollapsed[cat]
                    return true
                end
                entY = entY + headerH + 1

                if not self.entitySectionsCollapsed[cat] then
                    local ents = ENTITY_DEFS[cat] or {}
                    for _, eDef in ipairs(ents) do
                        local itemH = 22
                        if pointInRect(mx, my, lpx + pad, entY, lpw - pad * 2, itemH) then
                            self.selectedEntityDef = eDef
                            self.selectedEntityCategory = cat
                            self.activeTool = "stamp"
                            return true
                        end
                        entY = entY + itemH
                    end
                end
            end
        end

        return true
    end

    -- Canvas clicks
    if pointInRect(mx, my, self._layoutCenterX, self._layoutCenterY,
            self._layoutCenterW, self._layoutCenterH) then

        -- Clear text focus when clicking on canvas
        UI.clearFocus()

        -- Middle mouse (button 3) or space+left click for panning
        if button == 3 or (button == 1 and self.spaceHeld) then
            self.isPanning = true
            self.panButton = button
            self.panStartX = mx
            self.panStartY = my
            self.panStartCamX = self.camX
            self.panStartCamY = self.camY
            return true
        end

        local tx, ty = self:screenToTile(mx, my)

        if button == 1 then
            if self.activeTool == "paint" then
                self.isPainting = true
                self.strokeIdCounter = self.strokeIdCounter + 1
                self.paintStrokeId = self.strokeIdCounter
                self:paintTile(tx, ty, self.selectedTileId)
                return true

            elseif self.activeTool == "rect" then
                self.isRectDragging = true
                self.rectStartTileX = tx
                self.rectStartTileY = ty
                self.rectEndTileX = tx
                self.rectEndTileY = ty
                return true

            elseif self.activeTool == "fill" then
                self:floodFill(tx, ty, self.selectedTileId)
                return true

            elseif self.activeTool == "eraser" then
                self.isPainting = true
                self.strokeIdCounter = self.strokeIdCounter + 1
                self.paintStrokeId = self.strokeIdCounter
                self:paintTile(tx, ty, 0)
                return true

            elseif self.activeTool == "stamp" then
                if self.selectedEntityDef then
                    self:placeEntity(tx, ty)
                end
                return true
            end

        elseif button == 2 then
            -- Right click: erase tile or select entity
            if self.activeTool == "stamp" then
                -- Select entity at position
                local ent, idx = self:findEntityAt(tx, ty)
                if ent then
                    self.selectedEntity = ent
                    self.selectedEntityIndex = idx
                else
                    self.selectedEntity = nil
                    self.selectedEntityIndex = nil
                end
            else
                -- Erase tile (paint with 0)
                self.isPainting = true
                self.strokeIdCounter = self.strokeIdCounter + 1
                self.paintStrokeId = self.strokeIdCounter
                self._rightClickErasing = true
                self:paintTile(tx, ty, 0)
            end
            return true
        end
    end

    return false
end

-- =========================================================================
-- Input: mousereleased
-- =========================================================================

function MapEditor:mousereleased(mx, my, button)
    if self.resizeModal.visible then
        self.resizeModal:mousereleased(mx, my, button)
        return true
    end

    if self.isPanning and button == self.panButton then
        self.isPanning = false
        self.panButton = 0
        return true
    end

    if self.isPainting then
        if self._rightClickErasing and button == 2 then
            self.isPainting = false
            self._rightClickErasing = false
            return true
        elseif not self._rightClickErasing and button == 1 then
            self.isPainting = false
            return true
        end
    end

    if self.isRectDragging and button == 1 then
        self.isRectDragging = false
        -- Apply rectangle fill
        if self.rectStartTileX and self.rectEndTileX then
            self:rectFill(self.rectStartTileX, self.rectStartTileY,
                self.rectEndTileX, self.rectEndTileY, self.selectedTileId)
        end
        self.rectStartTileX = nil
        self.rectStartTileY = nil
        self.rectEndTileX = nil
        self.rectEndTileY = nil
        return true
    end

    return false
end

-- =========================================================================
-- Input: mousemoved
-- =========================================================================

function MapEditor:mousemoved(mx, my)
    -- Update world/tile coordinates
    if pointInRect(mx, my, self._layoutCenterX, self._layoutCenterY,
            self._layoutCenterW, self._layoutCenterH) then
        local wx, wy = self:screenToWorld(mx, my)
        self.mouseWorldX = wx
        self.mouseWorldY = wy
        self.mouseTileX, self.mouseTileY = self:worldToTile(wx, wy)
    else
        self.mouseTileX = nil
        self.mouseTileY = nil
    end

    -- Panning
    if self.isPanning then
        local dx = (mx - self.panStartX) / self.zoom
        local dy = (my - self.panStartY) / self.zoom
        self.camX = self.panStartCamX - dx
        self.camY = self.panStartCamY - dy
        return true
    end

    -- Continuous painting
    if self.isPainting and self.mouseTileX and self.mouseTileY then
        if self._rightClickErasing then
            self:paintTile(self.mouseTileX, self.mouseTileY, 0)
        elseif self.activeTool == "paint" then
            self:paintTile(self.mouseTileX, self.mouseTileY, self.selectedTileId)
        elseif self.activeTool == "eraser" then
            self:paintTile(self.mouseTileX, self.mouseTileY, 0)
        end
        return true
    end

    -- Rectangle drag update
    if self.isRectDragging and self.mouseTileX and self.mouseTileY then
        self.rectEndTileX = self.mouseTileX
        self.rectEndTileY = self.mouseTileY
        return true
    end

    -- Right panel text inputs
    self.nameInput:mousemoved(mx, my)
    self.widthInput:mousemoved(mx, my)
    self.heightInput:mousemoved(mx, my)
    self.newWidthInput:mousemoved(mx, my)
    self.newHeightInput:mousemoved(mx, my)

    return false
end

-- =========================================================================
-- Input: wheelmoved
-- =========================================================================

function MapEditor:wheelmoved(wx, wy)
    if self.resizeModal.visible then return true end

    local mx, my = love.mouse.getPosition()

    -- Only zoom when mouse is over canvas
    if pointInRect(mx, my, self._layoutCenterX, self._layoutCenterY,
            self._layoutCenterW, self._layoutCenterH) then

        local oldZoom = self.zoom
        local zoomFactor = 1.15
        if wy > 0 then
            self.zoom = self.zoom * zoomFactor
        elseif wy < 0 then
            self.zoom = self.zoom / zoomFactor
        end
        self.zoom = clamp(self.zoom, 0.25, 4.0)

        -- Zoom toward mouse position
        local worldX, worldY = self:screenToWorld(mx, my)
        -- After zoom change, the same screen point should map to the same world point
        -- Recalculate: worldX = (mx - vcx) / zoom + camX
        -- We want: oldWorldX = (mx - vcx) / newZoom + newCamX
        -- So: newCamX = oldWorldX - (mx - vcx) / newZoom
        -- But we already changed zoom, so we use the old world position
        local vcx = self._layoutCenterX + self._layoutCenterW / 2
        local vcy = self._layoutCenterY + self._layoutCenterH / 2

        -- worldX/worldY were computed before zoom change, but actually
        -- we already changed self.zoom. Let's recompute with old zoom:
        local oldWorldX = (mx - vcx) / oldZoom + self.camX
        local oldWorldY = (my - vcy) / oldZoom + self.camY
        self.camX = oldWorldX - (mx - vcx) / self.zoom
        self.camY = oldWorldY - (my - vcy) / self.zoom

        return true
    end

    -- Scroll on right panel
    if pointInRect(mx, my, self._layoutRightX, self._layoutRightY,
            self._layoutRightW, self._layoutRightH) then
        self.rightScroll:wheelmoved(wx, wy)
        return true
    end

    -- Scroll on left panel
    if pointInRect(mx, my, self._layoutLeftX, self._layoutLeftY,
            self._layoutLeftW, self._layoutLeftH) then
        self.leftScroll:wheelmoved(wx, wy)
        return true
    end

    return false
end

-- =========================================================================
-- Input: keypressed
-- =========================================================================

function MapEditor:keypressed(key)
    if self.resizeModal.visible then
        self.resizeModal:keypressed(key)
        return true
    end

    -- Let focused text inputs consume keys first
    local focus = UI.getFocus()
    if focus then
        if focus.keypressed and focus:keypressed(key) then
            return true
        end
    end

    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")

    -- Undo/Redo
    if ctrl and key == "z" then
        self.undoStack:undo()
        return true
    end
    if ctrl and key == "y" then
        self.undoStack:redo()
        return true
    end

    -- Tool shortcuts and grid toggle (only when no text input is focused)
    if not focus then
        -- Grid toggle
        if key == "g" then
            self.showGrid = not self.showGrid
            return true
        end

        if key == "p" then self.activeTool = "paint"; return true end
        if key == "r" then self.activeTool = "rect"; return true end
        if key == "f" then self.activeTool = "fill"; return true end
        if key == "e" then self.activeTool = "eraser"; return true end
        if key == "s" then self.activeTool = "stamp"; return true end
    end

    -- Zoom with +/- keys
    if key == "=" or key == "kp+" then
        self.zoom = clamp(self.zoom * 1.25, 0.25, 4.0)
        return true
    end
    if key == "-" or key == "kp-" then
        self.zoom = clamp(self.zoom / 1.25, 0.25, 4.0)
        return true
    end

    -- Delete selected entity
    if key == "delete" and self.selectedEntityIndex and not focus then
        self:removeEntity(self.selectedEntityIndex)
        return true
    end

    return false
end

-- =========================================================================
-- Input: textinput
-- =========================================================================

function MapEditor:textinput(t)
    if self.resizeModal.visible then return true end

    -- Forward to focused text input
    local focus = UI.getFocus()
    if focus and focus.textinput then
        return focus:textinput(t)
    end

    return false
end

-- =========================================================================
-- Serialization helpers (for project integration)
-- =========================================================================

function MapEditor:getMapData()
    return self.mapData
end

function MapEditor:setMapData(data)
    if not data then return end

    self.mapData = data
    self.mode = data.mode or "dungeon"
    self.selectedTileId = (self.mode == "dungeon") and 1 or 0
    self.selectedEntity = nil
    self.selectedEntityIndex = nil
    self.undoStack:clear()

    self.nameInput:setText(data.name or "")
    self.widthInput:setText(tostring(data.width or 40))
    self.heightInput:setText(tostring(data.height or 30))
    self._pendingWidth = data.width or 40
    self._pendingHeight = data.height or 30
    self.selectedTheme = data.theme or "plains"

    -- Center camera
    self.camX = (data.width or 40) * self.tileSize / 2
    self.camY = (data.height or 30) * self.tileSize / 2
end

return MapEditor
