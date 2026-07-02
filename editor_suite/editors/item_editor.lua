-- ==========================================================================
-- Item Editor Tab for Tavern Quest Editor Suite
-- A complete, production-quality item editor that manages items matching
-- the game's Backpack.ITEMS data format.
-- ==========================================================================

local Theme = require("core.theme")
local FontCache = require("core.fontcache")
local UI = require("core.ui")
local UndoStack = require("core.undo")
local Schema = require("core.data_schema")
local Search = require("core.search")
local IdGen = require("core.id_generator")
local AssetLoader = require("core.asset_loader")

local ItemEditor = {}
ItemEditor.__index = ItemEditor

-- =========================================================================
-- Constants
-- =========================================================================

local CATEGORIES = {
    "consumable", "food", "material", "ore", "weapon", "armor", "spell",
    "potion", "poison", "treasure", "special", "tool", "trap", "tome",
    "ammo", "throwable", "trophy", "transport", "seed",
}

local CATEGORY_ICONS = {
    consumable = "[C]",
    food       = "[F]",
    material   = "[M]",
    ore        = "[O]",
    weapon     = "[W]",
    armor      = "[A]",
    spell      = "[S]",
    potion     = "[P]",
    poison     = "[X]",
    treasure   = "[T]",
    special    = "[*]",
    tool       = "[~]",
    trap       = "[!]",
    tome       = "[B]",
    ammo       = "[>]",
    throwable  = "[^]",
    trophy     = "[#]",
    transport  = "[=]",
    seed       = "[.]",
}

local CATEGORY_COLORS = {
    consumable = {0.30, 0.80, 0.40},
    food       = {0.85, 0.65, 0.30},
    material   = {0.60, 0.60, 0.60},
    ore        = {0.70, 0.55, 0.35},
    weapon     = {0.90, 0.30, 0.30},
    armor      = {0.40, 0.55, 0.80},
    spell      = {0.70, 0.40, 0.90},
    potion     = {0.40, 0.80, 0.70},
    poison     = {0.60, 0.90, 0.20},
    treasure   = {1.00, 0.85, 0.20},
    special    = {1.00, 0.60, 0.80},
    tool       = {0.55, 0.55, 0.50},
    trap       = {0.90, 0.50, 0.20},
    tome       = {0.50, 0.40, 0.70},
    ammo       = {0.80, 0.70, 0.50},
    throwable  = {0.80, 0.50, 0.50},
    trophy     = {0.90, 0.80, 0.30},
    transport  = {0.50, 0.70, 0.80},
    seed       = {0.50, 0.80, 0.40},
}

local SORT_OPTIONS = {
    {field = "name",      label = "Name"},
    {field = "sellValue", label = "Value"},
    {field = "weight",    label = "Weight"},
}

local LEFT_PANEL_W = 260
local RIGHT_PANEL_W = 200
local ICON_PREVIEW_SIZE = 128
local LIST_ITEM_H = 30
local PROP_ROW_H = 28
local PROP_LABEL_W = 120
local SECTION_HEADER_H = 26

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

--- Resolve a dot-path key on a table (e.g. "baseStats.damage").
local function resolveKey(tbl, key)
    if type(tbl) ~= "table" then return nil end
    if not string.find(key, ".", 1, true) then
        return tbl[key]
    end
    local current = tbl
    for segment in key:gmatch("[^%.]+") do
        if type(current) ~= "table" then return nil end
        current = current[segment]
    end
    return current
end

--- Set a dot-path key on a table, creating intermediate tables as needed.
local function setNestedKey(tbl, key, value)
    if not string.find(key, ".", 1, true) then
        tbl[key] = value
        return
    end
    local segments = {}
    for segment in key:gmatch("[^%.]+") do
        segments[#segments + 1] = segment
    end
    local current = tbl
    for i = 1, #segments - 1 do
        local seg = segments[i]
        if current[seg] == nil then
            current[seg] = {}
        end
        current = current[seg]
    end
    current[segments[#segments]] = value
end

--- Build a set of all item IDs in an items array.
local function buildIdSet(items)
    local set = {}
    for _, item in ipairs(items) do
        if item.id then
            set[item.id] = true
        end
    end
    return set
end

-- =========================================================================
-- Constructor
-- =========================================================================

function ItemEditor.new(project)
    local self = setmetatable({}, ItemEditor)

    self.items = (project and project.items) or {}
    self.selectedIndex = nil
    self.undoStack = UndoStack.new(100)
    self.searchText = ""
    self.categoryFilter = "all"
    self.sortField = "name"
    self.sortAscending = true
    self.filteredItems = {}
    self.dirty = false
    self.onChange = nil

    -- Panel bounds (updated each frame in draw)
    self._bounds = {x = 0, y = 0, w = 0, h = 0}

    -- Left panel state
    self._leftScrollY = 0
    self._leftMaxScroll = 0
    self._leftHoveredIndex = nil

    -- Center panel state
    self._centerScrollY = 0
    self._centerMaxScroll = 0

    -- Delete confirmation state
    self._deleteConfirmActive = false
    self._deleteConfirmIndex = nil

    -- Dropdown state (category filter)
    self._dropdownOpen = false
    self._dropdownScrollY = 0

    -- Sort dropdown state
    self._sortDropdownOpen = false

    -- Focused text field tracking
    self._focusedField = nil   -- {key=string, widget=TextInput}
    self._fieldWidgets = {}    -- cache of TextInput widgets keyed by field key

    -- Interactive hit-test rectangles for property grid elements
    -- Rebuilt each draw frame. Keys are unique strings, values are rect tables.
    self._hitRects = {}

    -- Active text input for search
    self._searchInput = UI.TextInput.new({
        placeholder = "Search items...",
        fontSize = 12,
        onChange = function(text)
            self.searchText = text
            self:_rebuildFilteredList()
        end,
    })

    -- Buttons
    self._addBtn = UI.Button.new({
        text = "+ Add",
        variant = "primary",
        fontSize = 12,
        onClick = function() self:addNewItem() end,
    })
    self._dupBtn = UI.Button.new({
        text = "Dup",
        variant = "secondary",
        fontSize = 12,
        onClick = function() self:duplicateSelected() end,
    })
    self._delBtn = UI.Button.new({
        text = "Del",
        variant = "danger",
        fontSize = 12,
        onClick = function() self:requestDeleteSelected() end,
    })

    -- Confirmation buttons for delete
    self._confirmYesBtn = UI.Button.new({
        text = "Yes",
        variant = "danger",
        fontSize = 12,
        onClick = function() self:confirmDelete() end,
    })
    self._confirmNoBtn = UI.Button.new({
        text = "No",
        variant = "secondary",
        fontSize = 12,
        onClick = function() self:cancelDelete() end,
    })

    -- Build initial filtered list
    self:_rebuildFilteredList()

    return self
end

-- =========================================================================
-- Filtering and Sorting
-- =========================================================================

function ItemEditor:_rebuildFilteredList()
    local result = self.items

    -- Category filter
    if self.categoryFilter ~= "all" then
        result = Search.filterByCategory(result, "category", self.categoryFilter)
    end

    -- Text search
    if self.searchText ~= "" then
        result = Search.filterByText(result, self.searchText, {"name", "desc", "id"})
    end

    -- Sort
    result = Search.sortBy(result, self.sortField, self.sortAscending)

    self.filteredItems = result

    -- Fix selection if current selection is no longer in filtered list
    if self.selectedIndex then
        local selectedItem = nil
        -- Find the actual item at the old selected index from the source
        for i, item in ipairs(self.filteredItems) do
            if i == self.selectedIndex then
                selectedItem = item
                break
            end
        end
        if not selectedItem then
            if #self.filteredItems > 0 then
                self.selectedIndex = 1
            else
                self.selectedIndex = nil
            end
        end
    end
end

function ItemEditor:_getSelectedItem()
    if not self.selectedIndex then return nil end
    return self.filteredItems[self.selectedIndex]
end

--- Find the index of an item in the source items array.
function ItemEditor:_findSourceIndex(item)
    if not item then return nil end
    for i, v in ipairs(self.items) do
        if v == item then return i end
    end
    return nil
end

--- Find the index of an item in the filtered list.
function ItemEditor:_findFilteredIndex(item)
    if not item then return nil end
    for i, v in ipairs(self.filteredItems) do
        if v == item then return i end
    end
    return nil
end

-- =========================================================================
-- Dirty State
-- =========================================================================

function ItemEditor:_markDirty()
    self.dirty = true
    if self.onChange then
        self.onChange()
    end
end

-- =========================================================================
-- Item Operations (with Undo support)
-- =========================================================================

function ItemEditor:addNewItem()
    local newItem = Schema.getDefault(Schema.ItemSchema)
    newItem.name = "New Item"
    newItem.id = IdGen.ensureUnique(
        IdGen.generateId("New Item"),
        buildIdSet(self.items)
    )

    local items = self.items
    local editor = self

    self.undoStack:push({
        description = "Add item: " .. newItem.name,
        execute = function()
            items[#items + 1] = newItem
            editor:_rebuildFilteredList()
            local idx = editor:_findFilteredIndex(newItem)
            if idx then
                editor.selectedIndex = idx
            end
            editor:_markDirty()
        end,
        undo = function()
            for i = #items, 1, -1 do
                if items[i] == newItem then
                    table.remove(items, i)
                    break
                end
            end
            editor:_rebuildFilteredList()
            if editor.selectedIndex and editor.selectedIndex > #editor.filteredItems then
                editor.selectedIndex = #editor.filteredItems > 0 and #editor.filteredItems or nil
            end
            editor:_markDirty()
        end,
    })
end

function ItemEditor:duplicateSelected()
    local srcItem = self:_getSelectedItem()
    if not srcItem then return end

    local newItem = deepCopy(srcItem)
    newItem.id = IdGen.ensureUnique(srcItem.id .. "_copy", buildIdSet(self.items))
    newItem.name = srcItem.name .. " (Copy)"

    local items = self.items
    local editor = self
    local insertAfter = self:_findSourceIndex(srcItem)
    if not insertAfter then
        insertAfter = #items
    end

    self.undoStack:push({
        description = "Duplicate item: " .. srcItem.name,
        execute = function()
            table.insert(items, insertAfter + 1, newItem)
            editor:_rebuildFilteredList()
            local idx = editor:_findFilteredIndex(newItem)
            if idx then
                editor.selectedIndex = idx
            end
            editor:_markDirty()
        end,
        undo = function()
            for i = #items, 1, -1 do
                if items[i] == newItem then
                    table.remove(items, i)
                    break
                end
            end
            editor:_rebuildFilteredList()
            local idx = editor:_findFilteredIndex(srcItem)
            if idx then
                editor.selectedIndex = idx
            elseif #editor.filteredItems > 0 then
                editor.selectedIndex = math.min(editor.selectedIndex or 1, #editor.filteredItems)
            else
                editor.selectedIndex = nil
            end
            editor:_markDirty()
        end,
    })
end

function ItemEditor:requestDeleteSelected()
    if not self:_getSelectedItem() then return end
    self._deleteConfirmActive = true
    self._deleteConfirmIndex = self.selectedIndex
end

function ItemEditor:confirmDelete()
    self._deleteConfirmActive = false
    local item = self.filteredItems[self._deleteConfirmIndex]
    if not item then return end

    local items = self.items
    local editor = self
    local sourceIdx = self:_findSourceIndex(item)
    if not sourceIdx then return end

    local removedItem = item
    local removedSourceIdx = sourceIdx
    local oldSelectedIndex = self.selectedIndex

    self.undoStack:push({
        description = "Delete item: " .. (item.name or item.id or "unknown"),
        execute = function()
            for i = #items, 1, -1 do
                if items[i] == removedItem then
                    table.remove(items, i)
                    break
                end
            end
            editor:_rebuildFilteredList()
            if #editor.filteredItems == 0 then
                editor.selectedIndex = nil
            elseif oldSelectedIndex and oldSelectedIndex > #editor.filteredItems then
                editor.selectedIndex = #editor.filteredItems
            else
                editor.selectedIndex = oldSelectedIndex
                if editor.selectedIndex and editor.selectedIndex > #editor.filteredItems then
                    editor.selectedIndex = #editor.filteredItems > 0 and #editor.filteredItems or nil
                end
            end
            editor:_markDirty()
        end,
        undo = function()
            table.insert(items, removedSourceIdx, removedItem)
            editor:_rebuildFilteredList()
            local idx = editor:_findFilteredIndex(removedItem)
            if idx then
                editor.selectedIndex = idx
            end
            editor:_markDirty()
        end,
    })
end

function ItemEditor:cancelDelete()
    self._deleteConfirmActive = false
    self._deleteConfirmIndex = nil
end

--- Change a single field on an item, with undo support.
function ItemEditor:_setField(item, fieldKey, newValue, description)
    if not item then return end

    local oldValue = deepCopy(resolveKey(item, fieldKey))
    local newValueCopy = deepCopy(newValue)
    local editor = self

    self.undoStack:push({
        description = description or ("Set " .. fieldKey),
        execute = function()
            setNestedKey(item, fieldKey, deepCopy(newValueCopy))
            editor:_rebuildFilteredList()
            editor:_markDirty()
        end,
        undo = function()
            setNestedKey(item, fieldKey, deepCopy(oldValue))
            editor:_rebuildFilteredList()
            editor:_markDirty()
        end,
    })
end

-- =========================================================================
-- Update
-- =========================================================================

function ItemEditor:update(dt)
    self._searchInput:update(dt)

    -- Update any focused field widget
    if self._focusedField and self._focusedField.widget then
        self._focusedField.widget:update(dt)
    end
end

-- =========================================================================
-- Draw
-- =========================================================================

function ItemEditor:draw(x, y, w, h)
    self._bounds = {x = x, y = y, w = w, h = h}

    -- Clear interactive hit-test rects each frame (rebuilt during draw)
    self._hitRects = {}

    -- Background
    setColorSafe(Theme.colors.bg)
    love.graphics.rectangle("fill", x, y, w, h)

    local leftW = LEFT_PANEL_W
    local rightW = RIGHT_PANEL_W
    local centerW = w - leftW - rightW - 2  -- 2px for dividers
    if centerW < 100 then centerW = 100 end

    -- Divider positions
    local div1X = x + leftW
    local div2X = div1X + 1 + centerW + 1

    -- Draw the three panels
    self:_drawLeftPanel(x, y, leftW, h)

    -- Vertical divider 1
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", div1X, y, 1, h)

    self:_drawCenterPanel(div1X + 1, y, centerW, h)

    -- Vertical divider 2
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", div2X, y, 1, h)

    self:_drawRightPanel(div2X + 1, y, rightW, h)

    -- Delete confirmation overlay
    if self._deleteConfirmActive then
        self:_drawDeleteConfirm()
    end

    -- Category filter dropdown (drawn last so it overlays)
    if self._dropdownOpen then
        self:_drawCategoryDropdown()
    end

    -- Sort dropdown
    if self._sortDropdownOpen then
        self:_drawSortDropdown()
    end
end

-- =========================================================================
-- Left Panel: Search, Filter, List, Buttons
-- =========================================================================

function ItemEditor:_drawLeftPanel(x, y, w, h)
    -- Panel background
    setColorSafe(Theme.colors.panel)
    love.graphics.rectangle("fill", x, y, w, h)

    local pad = Theme.spacing.md
    local curY = y + pad

    -- Search bar
    self._searchInput:draw(x + pad, curY, w - pad * 2, Theme.sizes.inputHeight)
    curY = curY + Theme.sizes.inputHeight + pad

    -- Category filter button + Sort button row
    local filterBtnW = math.floor((w - pad * 3) * 0.6)
    local sortBtnW = w - pad * 3 - filterBtnW

    -- Category filter button
    local filterLabel = self.categoryFilter == "all" and "All Categories" or self.categoryFilter
    self:_drawDropdownButton(x + pad, curY, filterBtnW, Theme.sizes.buttonHeight, filterLabel, "filter")

    -- Sort button
    local sortLabel = "Sort: " .. self:_getSortLabel()
    local sortArrow = self.sortAscending and " ^" or " v"
    self:_drawDropdownButton(x + pad + filterBtnW + pad, curY, sortBtnW, Theme.sizes.buttonHeight, sortLabel .. sortArrow, "sort")

    -- Store dropdown button positions for click handling
    self._filterBtnRect = {x = x + pad, y = curY, w = filterBtnW, h = Theme.sizes.buttonHeight}
    self._sortBtnRect = {x = x + pad + filterBtnW + pad, y = curY, w = sortBtnW, h = Theme.sizes.buttonHeight}

    curY = curY + Theme.sizes.buttonHeight + pad

    -- Item count
    local font = FontCache.get(11)
    love.graphics.setFont(font)
    setColorSafe(Theme.colors.textDim)
    local countText = #self.filteredItems .. " / " .. #self.items .. " items"
    love.graphics.print(countText, x + pad, curY)
    curY = curY + font:getHeight() + Theme.spacing.sm

    -- Divider
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", x + pad, curY, w - pad * 2, 1)
    curY = curY + 1 + Theme.spacing.sm

    -- Item list area
    local listY = curY
    local btnAreaH = Theme.sizes.buttonHeight + pad * 2
    local listH = y + h - listY - btnAreaH
    if listH < 0 then listH = 0 end

    self._listRect = {x = x, y = listY, w = w, h = listH}
    self:_drawItemList(x, listY, w, listH)

    -- Bottom buttons
    local btnY = listY + listH + pad
    local btnW = math.floor((w - pad * 4) / 3)
    local btnH = Theme.sizes.buttonHeight

    self._addBtn:draw(x + pad, btnY, btnW, btnH)
    self._dupBtn:draw(x + pad * 2 + btnW, btnY, btnW, btnH)
    self._delBtn:draw(x + pad * 3 + btnW * 2, btnY, btnW, btnH)

    -- Store button area for disabling dup/del when nothing selected
    self._dupBtn.disabled = (self.selectedIndex == nil)
    self._delBtn.disabled = (self.selectedIndex == nil)
end

function ItemEditor:_drawDropdownButton(x, y, w, h, label, tag)
    local mx, my = love.mouse.getPosition()
    local hovered = pointInRect(mx, my, x, y, w, h)
    local isOpen = (tag == "filter" and self._dropdownOpen) or (tag == "sort" and self._sortDropdownOpen)

    if isOpen then
        setColorSafe(Theme.colors.primary)
    elseif hovered then
        setColorSafe(Theme.colors.listItemHover)
    else
        setColorSafe(Theme.colors.input)
    end
    drawRoundedRect("fill", x, y, w, h, Theme.radius.sm)

    setColorSafe(Theme.colors.inputBorder)
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", x + 0.5, y + 0.5, w - 1, h - 1, Theme.radius.sm)

    local font = FontCache.get(12)
    love.graphics.setFont(font)
    if isOpen then
        setColorSafe(Theme.colors.bg)
    else
        setColorSafe(Theme.colors.text)
    end
    local textH = font:getHeight()
    local textY = y + math.floor((h - textH) / 2)
    -- Truncate label if too wide
    local maxTextW = w - Theme.spacing.md * 2
    local displayLabel = label
    if font:getWidth(displayLabel) > maxTextW then
        while #displayLabel > 1 and font:getWidth(displayLabel .. "...") > maxTextW do
            displayLabel = displayLabel:sub(1, #displayLabel - 1)
        end
        displayLabel = displayLabel .. "..."
    end
    love.graphics.print(displayLabel, x + Theme.spacing.md, textY)
end

function ItemEditor:_getSortLabel()
    for _, opt in ipairs(SORT_OPTIONS) do
        if opt.field == self.sortField then
            return opt.label
        end
    end
    return "Name"
end

function ItemEditor:_drawItemList(x, y, w, h)
    if h <= 0 then return end

    local items = self.filteredItems
    local totalH = #items * LIST_ITEM_H
    self._leftMaxScroll = math.max(0, totalH - h)
    self._leftScrollY = clamp(self._leftScrollY, 0, self._leftMaxScroll)

    love.graphics.setScissor(x, y, w, h)

    local pad = Theme.spacing.md
    local font = FontCache.get(12)
    local smallFont = FontCache.get(10)
    local textH = font:getHeight()
    local mx, my = love.mouse.getPosition()

    -- Calculate scrollbar width adjustment
    local contentW = w
    local showScrollbar = totalH > h
    if showScrollbar then
        contentW = w - Theme.sizes.scrollbarWidth
    end

    for i, item in ipairs(items) do
        local iy = y + (i - 1) * LIST_ITEM_H - self._leftScrollY
        if iy + LIST_ITEM_H >= y and iy < y + h then
            local isSelected = (i == self.selectedIndex)
            local isHovered = pointInRect(mx, my, x, iy, contentW, LIST_ITEM_H) and not self._dropdownOpen and not self._sortDropdownOpen

            -- Row background
            if isSelected then
                setColorSafe(Theme.colors.listItemSelected)
                love.graphics.rectangle("fill", x, iy, contentW, LIST_ITEM_H)
            elseif isHovered then
                setColorSafe(Theme.colors.listItemHover)
                love.graphics.rectangle("fill", x, iy, contentW, LIST_ITEM_H)
            elseif i % 2 == 0 then
                setColorSafe(Theme.colors.listItemAlt)
                love.graphics.rectangle("fill", x, iy, contentW, LIST_ITEM_H)
            end

            -- Category icon
            local cat = item.category or "consumable"
            local catIcon = CATEGORY_ICONS[cat] or "[?]"
            local catColor = CATEGORY_COLORS[cat] or Theme.colors.textDim

            love.graphics.setFont(smallFont)
            setColorSafe(catColor)
            love.graphics.print(catIcon, x + pad, iy + math.floor((LIST_ITEM_H - smallFont:getHeight()) / 2))

            -- Item name
            love.graphics.setFont(font)
            setColorSafe(isSelected and Theme.colors.textAccent or Theme.colors.text)
            local nameX = x + pad + smallFont:getWidth("[XX]") + Theme.spacing.sm
            local nameW = contentW - nameX + x - pad
            local nameStr = item.name or item.id or "unnamed"
            -- Truncate if needed
            if font:getWidth(nameStr) > nameW then
                while #nameStr > 1 and font:getWidth(nameStr .. "..") > nameW do
                    nameStr = nameStr:sub(1, #nameStr - 1)
                end
                nameStr = nameStr .. ".."
            end
            love.graphics.print(nameStr, nameX, iy + math.floor((LIST_ITEM_H - textH) / 2))

            -- Bottom separator line
            setColorSafe(Theme.colors.bgDark)
            love.graphics.rectangle("fill", x + pad, iy + LIST_ITEM_H - 1, contentW - pad * 2, 1)
        end
    end

    -- Empty state
    if #items == 0 then
        love.graphics.setFont(font)
        setColorSafe(Theme.colors.textDim)
        local emptyText = #self.items == 0 and "No items yet. Click '+ Add' to create one." or "No items match your search."
        love.graphics.printf(emptyText, x + pad, y + h / 2 - textH, w - pad * 2, "center")
    end

    -- Scrollbar
    if showScrollbar then
        local sbW = Theme.sizes.scrollbarWidth
        local sbX = x + w - sbW
        local ratio = h / totalH
        local thumbH = math.max(20, ratio * h)
        local scrollRatio = self._leftMaxScroll > 0 and (self._leftScrollY / self._leftMaxScroll) or 0
        local thumbY = y + scrollRatio * (h - thumbH)

        setColorSafe(Theme.colors.scrollbar)
        love.graphics.rectangle("fill", sbX, y, sbW, h)

        local thumbHovered = pointInRect(mx, my, sbX, thumbY, sbW, thumbH)
        if thumbHovered then
            setColorSafe(Theme.colors.scrollbarThumbHover)
        else
            setColorSafe(Theme.colors.scrollbarThumb)
        end
        drawRoundedRect("fill", sbX + 1, thumbY, sbW - 2, thumbH, (sbW - 2) / 2)
    end

    love.graphics.setScissor()
end

-- =========================================================================
-- Center Panel: Property Grid
-- =========================================================================

function ItemEditor:_drawCenterPanel(x, y, w, h)
    setColorSafe(Theme.colors.bg)
    love.graphics.rectangle("fill", x, y, w, h)

    local item = self:_getSelectedItem()
    if not item then
        -- No selection placeholder
        local font = FontCache.get(14)
        love.graphics.setFont(font)
        setColorSafe(Theme.colors.textDim)
        love.graphics.printf("Select an item to edit its properties", x, y + h / 2 - 10, w, "center")
        return
    end

    -- Header: item name + undo/redo info
    local headerH = 36
    setColorSafe(Theme.colors.panelHeader)
    love.graphics.rectangle("fill", x, y, w, headerH)
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", x, y + headerH, w, 1)

    local titleFont = FontCache.get(14)
    love.graphics.setFont(titleFont)
    setColorSafe(Theme.colors.textAccent)
    local titleY = y + math.floor((headerH - titleFont:getHeight()) / 2)
    love.graphics.print(item.name or "Unnamed Item", x + Theme.spacing.lg, titleY)

    -- Undo/redo indicators
    local smallFont = FontCache.get(10)
    love.graphics.setFont(smallFont)
    setColorSafe(Theme.colors.textDim)
    local undoText = ""
    if self.undoStack:canUndo() then
        undoText = "Ctrl+Z: Undo"
    end
    if self.undoStack:canRedo() then
        undoText = undoText .. "  Ctrl+Y: Redo"
    end
    if undoText ~= "" then
        local undoW = smallFont:getWidth(undoText)
        love.graphics.print(undoText, x + w - undoW - Theme.spacing.lg, titleY + 2)
    end

    -- Property grid area
    local propY = y + headerH + 1
    local propH = h - headerH - 1
    self._centerRect = {x = x, y = propY, w = w, h = propH}

    -- Calculate total content height for scrolling
    local totalContentH = self:_calculatePropertyGridHeight(item)
    self._centerMaxScroll = math.max(0, totalContentH - propH)
    self._centerScrollY = clamp(self._centerScrollY, 0, self._centerMaxScroll)

    -- Draw property grid with scrolling
    love.graphics.setScissor(x, propY, w, propH)
    self:_drawPropertyGrid(item, x, propY, w, propH)

    -- Scrollbar for center panel
    if totalContentH > propH then
        local sbW = Theme.sizes.scrollbarWidth
        local sbX = x + w - sbW
        local ratio = propH / totalContentH
        local thumbH = math.max(20, ratio * propH)
        local scrollRatio = self._centerMaxScroll > 0 and (self._centerScrollY / self._centerMaxScroll) or 0
        local thumbY = propY + scrollRatio * (propH - thumbH)

        setColorSafe(Theme.colors.scrollbar)
        love.graphics.rectangle("fill", sbX, propY, sbW, propH)

        local mx, my = love.mouse.getPosition()
        local thumbHovered = pointInRect(mx, my, sbX, thumbY, sbW, thumbH)
        if thumbHovered then
            setColorSafe(Theme.colors.scrollbarThumbHover)
        else
            setColorSafe(Theme.colors.scrollbarThumb)
        end
        drawRoundedRect("fill", sbX + 1, thumbY, sbW - 2, thumbH, (sbW - 2) / 2)
    end

    love.graphics.setScissor()
end

function ItemEditor:_calculatePropertyGridHeight(item)
    if not item then return 0 end
    local groups = Schema.getFieldsByCategory(Schema.ItemSchema)
    local totalH = Theme.spacing.md
    for _, group in ipairs(groups) do
        -- Check if any field in this group is visible
        local hasVisible = false
        for _, field in ipairs(group.fields) do
            if not field.condition or field.condition(item) then
                hasVisible = true
                break
            end
        end
        if hasVisible then
            totalH = totalH + SECTION_HEADER_H
            for _, field in ipairs(group.fields) do
                if not field.condition or field.condition(item) then
                    if field.type == "text" then
                        totalH = totalH + PROP_ROW_H * 2
                    elseif field.type == "multiselect" then
                        totalH = totalH + PROP_ROW_H + 20
                    else
                        totalH = totalH + PROP_ROW_H
                    end
                end
            end
            totalH = totalH + Theme.spacing.sm
        end
    end
    return totalH + Theme.spacing.xl
end

function ItemEditor:_drawPropertyGrid(item, panelX, panelY, panelW, panelH)
    if not item then return end

    local groups = Schema.getFieldsByCategory(Schema.ItemSchema)
    local pad = Theme.spacing.lg
    local contentW = panelW - pad * 2
    if self._centerMaxScroll > 0 then
        contentW = contentW - Theme.sizes.scrollbarWidth
    end
    local curY = panelY + Theme.spacing.md - self._centerScrollY

    local labelFont = FontCache.get(12)
    local headerFont = FontCache.getBold(12)
    local valueFont = FontCache.get(12)

    for _, group in ipairs(groups) do
        -- Check if any field in this group is visible
        local hasVisible = false
        for _, field in ipairs(group.fields) do
            if not field.condition or field.condition(item) then
                hasVisible = true
                break
            end
        end
        if not hasVisible then goto continue_group end

        -- Section header
        setColorSafe(Theme.colors.panelHeader)
        drawRoundedRect("fill", panelX + pad, curY, contentW, SECTION_HEADER_H, Theme.radius.sm)
        love.graphics.setFont(headerFont)
        setColorSafe(Theme.colors.primary)
        local headerLabel = group.name:sub(1, 1):upper() .. group.name:sub(2)
        headerLabel = headerLabel:gsub("(%l)(%u)", "%1 %2") -- camelCase to spaces
        love.graphics.print(headerLabel, panelX + pad + Theme.spacing.md, curY + math.floor((SECTION_HEADER_H - headerFont:getHeight()) / 2))
        curY = curY + SECTION_HEADER_H

        for _, field in ipairs(group.fields) do
            if field.condition and not field.condition(item) then
                goto continue_field
            end

            local rowH = PROP_ROW_H
            if field.type == "text" then
                rowH = PROP_ROW_H * 2
            elseif field.type == "multiselect" then
                rowH = PROP_ROW_H + 20
            end

            -- Only draw if visible on screen
            if curY + rowH >= panelY and curY < panelY + panelH then
                self:_drawPropertyRow(item, field, panelX + pad, curY, contentW, rowH, labelFont, valueFont)
            end

            curY = curY + rowH

            ::continue_field::
        end

        curY = curY + Theme.spacing.sm

        ::continue_group::
    end
end

function ItemEditor:_drawPropertyRow(item, field, x, y, w, h, labelFont, valueFont)
    local labelW = PROP_LABEL_W
    local valueX = x + labelW + Theme.spacing.sm
    local valueW = w - labelW - Theme.spacing.sm
    if valueW < 50 then valueW = 50 end

    -- Label
    love.graphics.setFont(labelFont)
    setColorSafe(field.required and Theme.colors.text or Theme.colors.textDim)
    local labelY = y + math.floor((math.min(h, PROP_ROW_H) - labelFont:getHeight()) / 2)
    love.graphics.print(field.label, x, labelY)

    -- Value
    local value = resolveKey(item, field.key)
    local valueH = math.min(h, PROP_ROW_H) - 4

    if field.type == "string" then
        self:_drawStringField(item, field, valueX, y + 2, valueW, valueH, value)

    elseif field.type == "text" then
        self:_drawTextField(item, field, valueX, y + 2, valueW, h - 4, value)

    elseif field.type == "number" then
        self:_drawNumberField(item, field, valueX, y + 2, valueW, valueH, value)

    elseif field.type == "boolean" then
        self:_drawBooleanField(item, field, x + labelW - 40, y, 60, h, value)

    elseif field.type == "select" then
        self:_drawSelectField(item, field, valueX, y + 2, valueW, valueH, value)

    elseif field.type == "multiselect" then
        self:_drawMultiselectField(item, field, valueX, y + 2, valueW, h - 4, value)
    end

    -- Bottom line
    setColorSafe(Theme.withAlpha("panelBorder", 0.3))
    love.graphics.rectangle("fill", x, y + h - 1, w, 1)
end

function ItemEditor:_getOrCreateWidget(fieldKey, createFn)
    if not self._fieldWidgets[fieldKey] then
        self._fieldWidgets[fieldKey] = createFn()
    end
    return self._fieldWidgets[fieldKey]
end

function ItemEditor:_drawStringField(item, field, x, y, w, h, value)
    local key = field.key .. "_" .. tostring(item)
    local widget = self:_getOrCreateWidget(key, function()
        return UI.TextInput.new({
            text = tostring(value or ""),
            placeholder = field.tooltip or "",
            fontSize = 12,
        })
    end)

    -- Sync widget text with current value if not focused
    if not (self._focusedField and self._focusedField.key == key) then
        widget:setText(tostring(value or ""))
    end

    -- Set up onChange for this widget
    widget.onChange = function(text)
        self:_setField(item, field.key, text, "Set " .. field.label .. " = " .. text)
        -- Auto-generate ID from name if this is the name field
        if field.key == "name" then
            local newId = IdGen.ensureUnique(IdGen.generateId(text), buildIdSet(self.items))
            -- Only update ID if the current ID was auto-generated (looks like it matches old name pattern)
            local currentId = item.id or ""
            local currentName = item.name or ""
            local autoId = IdGen.generateId(currentName)
            if currentId == "" or currentId == autoId or currentId == IdGen.generateId(currentName) then
                setNestedKey(item, "id", newId)
                -- Invalidate the ID widget cache
                local idKey = "id_" .. tostring(item)
                self._fieldWidgets[idKey] = nil
            end
        end
    end

    widget:draw(x, y, w, h)
end

function ItemEditor:_drawTextField(item, field, x, y, w, h, value)
    local key = field.key .. "_" .. tostring(item)
    local widget = self:_getOrCreateWidget(key, function()
        return UI.TextInput.new({
            text = tostring(value or ""),
            placeholder = field.tooltip or "",
            fontSize = 12,
        })
    end)

    if not (self._focusedField and self._focusedField.key == key) then
        widget:setText(tostring(value or ""))
    end

    widget.onChange = function(text)
        self:_setField(item, field.key, text, "Set " .. field.label)
    end

    widget:draw(x, y, w, h)
end

function ItemEditor:_drawNumberField(item, field, x, y, w, h, value)
    local numVal = tonumber(value) or field.default or 0

    -- Draw as a text input with increment/decrement buttons
    local btnW = 20
    local inputW = w - btnW * 2 - 4

    -- Display the value
    local font = FontCache.get(12)
    love.graphics.setFont(font)

    -- Input background
    setColorSafe(Theme.colors.input)
    drawRoundedRect("fill", x + btnW + 2, y, inputW, h, Theme.radius.sm)
    setColorSafe(Theme.colors.inputBorder)
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", x + btnW + 2.5, y + 0.5, inputW - 1, h - 1, Theme.radius.sm)

    -- Value text
    setColorSafe(Theme.colors.text)
    local displayVal
    if field.step and field.step >= 1 then
        displayVal = tostring(math.floor(numVal))
    else
        displayVal = string.format("%.1f", numVal)
    end
    local textH = font:getHeight()
    love.graphics.print(displayVal, x + btnW + 2 + Theme.spacing.sm, y + math.floor((h - textH) / 2))

    -- Decrement button
    local mx, my = love.mouse.getPosition()
    local decHovered = pointInRect(mx, my, x, y, btnW, h)
    setColorSafe(decHovered and Theme.colors.listItemHover or Theme.colors.input)
    drawRoundedRect("fill", x, y, btnW, h, Theme.radius.sm)
    setColorSafe(Theme.colors.text)
    love.graphics.printf("-", x, y + math.floor((h - textH) / 2), btnW, "center")

    -- Increment button
    local incX = x + btnW + 2 + inputW + 2
    local incHovered = pointInRect(mx, my, incX, y, btnW, h)
    setColorSafe(incHovered and Theme.colors.listItemHover or Theme.colors.input)
    drawRoundedRect("fill", incX, y, btnW, h, Theme.radius.sm)
    setColorSafe(Theme.colors.text)
    love.graphics.printf("+", incX, y + math.floor((h - textH) / 2), btnW, "center")

    -- Store hit rects for click handling
    local fieldKey = field.key .. "_num_" .. tostring(item)
    self._hitRects["numDec_" .. fieldKey] = {x = x, y = y, w = btnW, h = h, item = item, field = field, delta = -(field.step or 1)}
    self._hitRects["numInc_" .. fieldKey] = {x = incX, y = y, w = btnW, h = h, item = item, field = field, delta = (field.step or 1)}
end

function ItemEditor:_drawBooleanField(item, field, x, y, w, h, value)
    local boolVal = value == true

    local toggleW = 36
    local toggleH = 18
    local toggleX = x
    local toggleY = y + math.floor((h - toggleH) / 2)

    -- Track
    local t = boolVal and 1.0 or 0.0
    local offColor = Theme.colors.scrollbar
    local onColor = Theme.colors.primary
    local trackColor = {
        offColor[1] + (onColor[1] - offColor[1]) * t,
        offColor[2] + (onColor[2] - offColor[2]) * t,
        offColor[3] + (onColor[3] - offColor[3]) * t,
    }
    setColorSafe(trackColor)
    drawRoundedRect("fill", toggleX, toggleY, toggleW, toggleH, toggleH / 2)

    -- Thumb
    local thumbR = (toggleH - 4) / 2
    local thumbMinX = toggleX + thumbR + 2
    local thumbMaxX = toggleX + toggleW - thumbR - 2
    local thumbCX = thumbMinX + (thumbMaxX - thumbMinX) * t
    local thumbCY = toggleY + toggleH / 2
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", thumbCX, thumbCY, thumbR)

    -- Store rect for click
    local fieldKey = field.key .. "_bool_" .. tostring(item)
    self._hitRects["toggle_" .. fieldKey] = {x = toggleX, y = toggleY, w = toggleW, h = toggleH, item = item, field = field}
end

function ItemEditor:_drawSelectField(item, field, x, y, w, h, value)
    local font = FontCache.get(12)
    love.graphics.setFont(font)

    setColorSafe(Theme.colors.input)
    drawRoundedRect("fill", x, y, w, h, Theme.radius.sm)
    setColorSafe(Theme.colors.inputBorder)
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", x + 0.5, y + 0.5, w - 1, h - 1, Theme.radius.sm)

    setColorSafe(Theme.colors.text)
    local textH = font:getHeight()
    local displayVal = tostring(value or field.default or "")
    love.graphics.print(displayVal, x + Theme.spacing.md, y + math.floor((h - textH) / 2))

    -- Arrow indicator
    setColorSafe(Theme.colors.textDim)
    love.graphics.print("v", x + w - 14, y + math.floor((h - textH) / 2))

    -- Store rect for dropdown handling
    local fieldKey = field.key .. "_sel_" .. tostring(item)
    self._hitRects["select_" .. fieldKey] = {x = x, y = y, w = w, h = h, item = item, field = field, options = field.options}
end

function ItemEditor:_drawMultiselectField(item, field, x, y, w, h, value)
    local font = FontCache.get(11)
    love.graphics.setFont(font)
    local textH = font:getHeight()

    local selectedSet = {}
    if type(value) == "table" then
        for _, v in ipairs(value) do
            selectedSet[v] = true
        end
    end

    local options = field.options or {}
    local chipX = x
    local chipY = y
    local chipH = 18
    local chipPad = 4

    for _, opt in ipairs(options) do
        local isSelected = selectedSet[opt] == true
        local chipW = font:getWidth(opt) + chipPad * 2 + 4

        -- Wrap to next line if needed
        if chipX + chipW > x + w and chipX > x then
            chipX = x
            chipY = chipY + chipH + 2
        end

        if isSelected then
            setColorSafe(Theme.colors.primary)
        else
            setColorSafe(Theme.colors.input)
        end
        drawRoundedRect("fill", chipX, chipY, chipW, chipH, chipH / 2)

        setColorSafe(isSelected and Theme.colors.bg or Theme.colors.textDim)
        love.graphics.print(opt, chipX + chipPad + 2, chipY + math.floor((chipH - textH) / 2))

        -- Store rect for click
        local chipKey = field.key .. "_ms_" .. opt .. "_" .. tostring(item)
        self._hitRects["chip_" .. chipKey] = {x = chipX, y = chipY, w = chipW, h = chipH, item = item, field = field, option = opt}

        chipX = chipX + chipW + 3
    end
end

-- =========================================================================
-- Right Panel: Icon Preview + Stat Bars
-- =========================================================================

function ItemEditor:_drawRightPanel(x, y, w, h)
    setColorSafe(Theme.colors.panel)
    love.graphics.rectangle("fill", x, y, w, h)

    local item = self:_getSelectedItem()
    if not item then return end

    local pad = Theme.spacing.lg
    local curY = y + pad

    -- Section header: Icon Preview
    local headerFont = FontCache.getBold(12)
    love.graphics.setFont(headerFont)
    setColorSafe(Theme.colors.primary)
    love.graphics.print("Icon Preview", x + pad, curY)
    curY = curY + headerFont:getHeight() + Theme.spacing.sm

    -- Icon preview box
    local previewSize = math.min(ICON_PREVIEW_SIZE, w - pad * 2)
    local previewX = x + math.floor((w - previewSize) / 2)

    setColorSafe(Theme.colors.bgDark)
    drawRoundedRect("fill", previewX, curY, previewSize, previewSize, Theme.radius.md)
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", previewX + 0.5, curY + 0.5, previewSize - 1, previewSize - 1, Theme.radius.md)

    -- Try to load and draw the icon
    local iconPath = item.icon or ""
    if iconPath ~= "" then
        -- Convert game asset paths: if it starts with "assets/" prepend the mount point
        local loadPath = iconPath
        if loadPath:sub(1, 7) == "assets/" then
            loadPath = AssetLoader.getMountPoint() .. "/" .. loadPath
        end
        local img = AssetLoader.loadImage(loadPath)
        if img then
            love.graphics.setColor(1, 1, 1, 1)
            local iw, ih = img:getDimensions()
            local scale = math.min(previewSize / iw, previewSize / ih) * 0.9
            local drawX = previewX + math.floor((previewSize - iw * scale) / 2)
            local drawY = curY + math.floor((previewSize - ih * scale) / 2)
            love.graphics.draw(img, drawX, drawY, 0, scale, scale)
        else
            -- Missing icon indicator
            local font = FontCache.get(11)
            love.graphics.setFont(font)
            setColorSafe(Theme.colors.textDim)
            love.graphics.printf("No icon\nloaded", previewX, curY + previewSize / 2 - font:getHeight(), previewSize, "center")
        end
    else
        local font = FontCache.get(11)
        love.graphics.setFont(font)
        setColorSafe(Theme.colors.textDim)
        love.graphics.printf("No icon\nset", previewX, curY + previewSize / 2 - font:getHeight(), previewSize, "center")
    end

    curY = curY + previewSize + Theme.spacing.sm

    -- Icon path display
    local smallFont = FontCache.get(10)
    love.graphics.setFont(smallFont)
    setColorSafe(Theme.colors.textDim)
    local displayPath = iconPath ~= "" and iconPath or "(no icon path)"
    -- Truncate path if too long
    local maxPathW = w - pad * 2
    if smallFont:getWidth(displayPath) > maxPathW then
        -- Show just the filename
        displayPath = "..." .. displayPath:match("[/\\]([^/\\]+)$") or displayPath
    end
    love.graphics.printf(displayPath, x + pad, curY, w - pad * 2, "center")
    curY = curY + smallFont:getHeight() + Theme.spacing.lg

    -- Divider
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", x + pad, curY, w - pad * 2, 1)
    curY = curY + 1 + Theme.spacing.lg

    -- Stat bars section
    love.graphics.setFont(headerFont)
    setColorSafe(Theme.colors.primary)
    love.graphics.print("Stats", x + pad, curY)
    curY = curY + headerFont:getHeight() + Theme.spacing.sm

    -- Draw stat bars
    local stats = item.baseStats or {}
    local statDefs = {
        {key = "damage",      label = "DMG",  max = 200, color = {0.90, 0.30, 0.30}},
        {key = "defense",     label = "DEF",  max = 200, color = {0.40, 0.55, 0.80}},
        {key = "healing",     label = "HEAL", max = 200, color = {0.30, 0.80, 0.40}},
        {key = "manaCost",    label = "MANA", max = 100, color = {0.40, 0.50, 0.90}},
        {key = "bonusDamage",  label = "+DMG", max = 100, color = {1.00, 0.50, 0.30}},
        {key = "bonusDefense", label = "+DEF", max = 100, color = {0.50, 0.65, 0.90}},
        {key = "duration",    label = "DUR",  max = 60,  color = {0.70, 0.60, 0.30}},
        {key = "stunChance",  label = "STUN", max = 100, color = {0.80, 0.70, 0.20}},
    }

    local barFont = FontCache.get(10)
    love.graphics.setFont(barFont)
    local barH = 14
    local barLabelW = 36
    local barMaxW = w - pad * 2 - barLabelW - Theme.spacing.sm

    local hasAnyStat = false
    for _, def in ipairs(statDefs) do
        local val = stats[def.key]
        if val and val > 0 then
            hasAnyStat = true

            -- Label
            setColorSafe(Theme.colors.textDim)
            love.graphics.print(def.label, x + pad, curY + math.floor((barH - barFont:getHeight()) / 2))

            -- Bar background
            local barX = x + pad + barLabelW + Theme.spacing.sm
            setColorSafe(Theme.colors.bgDark)
            drawRoundedRect("fill", barX, curY, barMaxW, barH, barH / 2)

            -- Bar fill
            local fillRatio = math.min(val / def.max, 1.0)
            local fillW = fillRatio * barMaxW
            if fillW > 0 then
                setColorSafe(def.color)
                drawRoundedRect("fill", barX, curY, fillW, barH, barH / 2)
            end

            -- Value text on bar
            love.graphics.setColor(1, 1, 1, 1)
            local valStr = tostring(math.floor(val))
            love.graphics.print(valStr, barX + 4, curY + math.floor((barH - barFont:getHeight()) / 2))

            curY = curY + barH + 3
        end
    end

    if not hasAnyStat then
        setColorSafe(Theme.colors.textDim)
        love.graphics.printf("No stats set", x + pad, curY, w - pad * 2, "center")
        curY = curY + barFont:getHeight() + Theme.spacing.sm
    end

    -- Additional info
    curY = curY + Theme.spacing.lg
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", x + pad, curY, w - pad * 2, 1)
    curY = curY + 1 + Theme.spacing.md

    love.graphics.setFont(smallFont)
    -- Category badge
    local cat = item.category or "consumable"
    local catColor = CATEGORY_COLORS[cat] or Theme.colors.textDim
    setColorSafe(catColor)
    local catLabel = (CATEGORY_ICONS[cat] or "") .. " " .. cat
    love.graphics.print(catLabel, x + pad, curY)
    curY = curY + smallFont:getHeight() + 2

    -- Weight and value
    setColorSafe(Theme.colors.textDim)
    love.graphics.print("Weight: " .. string.format("%.1f", item.weight or 0), x + pad, curY)
    curY = curY + smallFont:getHeight() + 2
    love.graphics.print("Value: " .. tostring(item.sellValue or 0) .. "g", x + pad, curY)
    curY = curY + smallFont:getHeight() + 2

    if item.stackable then
        love.graphics.print("Stack: " .. tostring(item.maxStack or 99), x + pad, curY)
    else
        love.graphics.print("Not stackable", x + pad, curY)
    end
end

-- =========================================================================
-- Overlay Draws: Dropdowns, Confirmations
-- =========================================================================

function ItemEditor:_drawCategoryDropdown()
    if not self._filterBtnRect then return end
    local r = self._filterBtnRect
    local options = {"all"}
    for _, cat in ipairs(CATEGORIES) do
        options[#options + 1] = cat
    end

    local itemH = 24
    local dropH = math.min(#options * itemH, 300)
    local dropX = r.x
    local dropY = r.y + r.h
    local dropW = r.w

    self._dropdownRect = {x = dropX, y = dropY, w = dropW, h = dropH}

    -- Shadow
    setColorSafe(Theme.colors.shadow)
    drawRoundedRect("fill", dropX + 2, dropY + 2, dropW, dropH, Theme.radius.sm)

    -- Background
    setColorSafe(Theme.colors.panel)
    drawRoundedRect("fill", dropX, dropY, dropW, dropH, Theme.radius.sm)
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", dropX + 0.5, dropY + 0.5, dropW - 1, dropH - 1, Theme.radius.sm)

    love.graphics.setScissor(dropX, dropY, dropW, dropH)

    local font = FontCache.get(12)
    love.graphics.setFont(font)
    local textH = font:getHeight()
    local mx, my = love.mouse.getPosition()

    for i, opt in ipairs(options) do
        local iy = dropY + (i - 1) * itemH - self._dropdownScrollY
        if iy + itemH >= dropY and iy < dropY + dropH then
            local hovered = pointInRect(mx, my, dropX, iy, dropW, itemH)
            local selected = opt == self.categoryFilter

            if selected then
                setColorSafe(Theme.colors.listItemSelected)
                love.graphics.rectangle("fill", dropX + 1, iy, dropW - 2, itemH)
            elseif hovered then
                setColorSafe(Theme.colors.listItemHover)
                love.graphics.rectangle("fill", dropX + 1, iy, dropW - 2, itemH)
            end

            if opt ~= "all" then
                local catColor = CATEGORY_COLORS[opt] or Theme.colors.textDim
                setColorSafe(catColor)
                local icon = CATEGORY_ICONS[opt] or ""
                love.graphics.print(icon, dropX + Theme.spacing.md, iy + math.floor((itemH - textH) / 2))
                setColorSafe(selected and Theme.colors.textAccent or Theme.colors.text)
                love.graphics.print(opt, dropX + Theme.spacing.md + 30, iy + math.floor((itemH - textH) / 2))
            else
                setColorSafe(selected and Theme.colors.textAccent or Theme.colors.text)
                love.graphics.print("All Categories", dropX + Theme.spacing.md, iy + math.floor((itemH - textH) / 2))
            end
        end
    end

    love.graphics.setScissor()
end

function ItemEditor:_drawSortDropdown()
    if not self._sortBtnRect then return end
    local r = self._sortBtnRect

    local options = {}
    for _, opt in ipairs(SORT_OPTIONS) do
        options[#options + 1] = {field = opt.field, label = opt.label, ascending = true}
        options[#options + 1] = {field = opt.field, label = opt.label .. " (desc)", ascending = false}
    end

    local itemH = 24
    local dropH = #options * itemH
    local dropX = r.x
    local dropY = r.y + r.h
    local dropW = r.w

    self._sortDropdownRect = {x = dropX, y = dropY, w = dropW, h = dropH}

    -- Shadow
    setColorSafe(Theme.colors.shadow)
    drawRoundedRect("fill", dropX + 2, dropY + 2, dropW, dropH, Theme.radius.sm)

    -- Background
    setColorSafe(Theme.colors.panel)
    drawRoundedRect("fill", dropX, dropY, dropW, dropH, Theme.radius.sm)
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", dropX + 0.5, dropY + 0.5, dropW - 1, dropH - 1, Theme.radius.sm)

    local font = FontCache.get(12)
    love.graphics.setFont(font)
    local textH = font:getHeight()
    local mx, my = love.mouse.getPosition()

    for i, opt in ipairs(options) do
        local iy = dropY + (i - 1) * itemH
        local hovered = pointInRect(mx, my, dropX, iy, dropW, itemH)
        local selected = opt.field == self.sortField and opt.ascending == self.sortAscending

        if selected then
            setColorSafe(Theme.colors.listItemSelected)
            love.graphics.rectangle("fill", dropX + 1, iy, dropW - 2, itemH)
        elseif hovered then
            setColorSafe(Theme.colors.listItemHover)
            love.graphics.rectangle("fill", dropX + 1, iy, dropW - 2, itemH)
        end

        setColorSafe(selected and Theme.colors.textAccent or Theme.colors.text)
        love.graphics.print(opt.label, dropX + Theme.spacing.md, iy + math.floor((itemH - textH) / 2))
    end
end

function ItemEditor:_drawDeleteConfirm()
    local screenW, screenH = love.graphics.getDimensions()

    -- Overlay
    setColorSafe(Theme.colors.overlay)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    local dw = 320
    local dh = 140
    local dx = math.floor((screenW - dw) / 2)
    local dy = math.floor((screenH - dh) / 2)

    -- Shadow
    setColorSafe(Theme.colors.shadow)
    drawRoundedRect("fill", dx + 3, dy + 3, dw, dh, Theme.radius.lg)

    -- Background
    setColorSafe(Theme.colors.panel)
    drawRoundedRect("fill", dx, dy, dw, dh, Theme.radius.lg)
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", dx + 0.5, dy + 0.5, dw - 1, dh - 1, Theme.radius.lg)

    -- Title
    local titleFont = FontCache.getBold(14)
    love.graphics.setFont(titleFont)
    setColorSafe(Theme.colors.danger)
    love.graphics.print("Delete Item?", dx + Theme.spacing.xl, dy + Theme.spacing.lg)

    -- Message
    local font = FontCache.get(12)
    love.graphics.setFont(font)
    setColorSafe(Theme.colors.text)
    local item = self.filteredItems[self._deleteConfirmIndex]
    local itemName = item and (item.name or item.id) or "this item"
    love.graphics.printf("Are you sure you want to delete \"" .. itemName .. "\"? This can be undone with Ctrl+Z.",
        dx + Theme.spacing.xl, dy + 44, dw - Theme.spacing.xl * 2, "left")

    -- Buttons
    local btnW = 80
    local btnH = Theme.sizes.buttonHeight
    local btnY = dy + dh - btnH - Theme.spacing.lg
    self._confirmNoBtn:draw(dx + dw - Theme.spacing.xl - btnW * 2 - Theme.spacing.md, btnY, btnW, btnH)
    self._confirmYesBtn:draw(dx + dw - Theme.spacing.xl - btnW, btnY, btnW, btnH)
end

-- =========================================================================
-- Input Handling
-- =========================================================================

function ItemEditor:mousepressed(mx, my, button)
    if button ~= 1 then return false end

    -- Delete confirmation takes priority
    if self._deleteConfirmActive then
        self._confirmYesBtn:mousepressed(mx, my, button)
        self._confirmNoBtn:mousepressed(mx, my, button)
        return true
    end

    -- Close dropdowns if clicking outside
    if self._dropdownOpen then
        if self._dropdownRect and pointInRect(mx, my, self._dropdownRect.x, self._dropdownRect.y, self._dropdownRect.w, self._dropdownRect.h) then
            -- Click inside dropdown: select option
            local itemH = 24
            local relY = my - self._dropdownRect.y + self._dropdownScrollY
            local idx = math.floor(relY / itemH) + 1
            local options = {"all"}
            for _, cat in ipairs(CATEGORIES) do
                options[#options + 1] = cat
            end
            if idx >= 1 and idx <= #options then
                self.categoryFilter = options[idx]
                self:_rebuildFilteredList()
                if self.selectedIndex and self.selectedIndex > #self.filteredItems then
                    self.selectedIndex = #self.filteredItems > 0 and #self.filteredItems or nil
                end
            end
            self._dropdownOpen = false
            return true
        else
            self._dropdownOpen = false
            -- Fall through to handle other clicks
        end
    end

    if self._sortDropdownOpen then
        if self._sortDropdownRect and pointInRect(mx, my, self._sortDropdownRect.x, self._sortDropdownRect.y, self._sortDropdownRect.w, self._sortDropdownRect.h) then
            local itemH = 24
            local relY = my - self._sortDropdownRect.y
            local idx = math.floor(relY / itemH) + 1
            local options = {}
            for _, opt in ipairs(SORT_OPTIONS) do
                options[#options + 1] = {field = opt.field, ascending = true}
                options[#options + 1] = {field = opt.field, ascending = false}
            end
            if idx >= 1 and idx <= #options then
                self.sortField = options[idx].field
                self.sortAscending = options[idx].ascending
                self:_rebuildFilteredList()
            end
            self._sortDropdownOpen = false
            return true
        else
            self._sortDropdownOpen = false
        end
    end

    -- Check bounds
    local b = self._bounds
    if not pointInRect(mx, my, b.x, b.y, b.w, b.h) then
        return false
    end

    -- Search input
    if self._searchInput:mousepressed(mx, my, button) then
        self._focusedField = {key = "_search", widget = self._searchInput}
        return true
    end

    -- Filter dropdown button
    if self._filterBtnRect and pointInRect(mx, my, self._filterBtnRect.x, self._filterBtnRect.y, self._filterBtnRect.w, self._filterBtnRect.h) then
        self._dropdownOpen = not self._dropdownOpen
        self._sortDropdownOpen = false
        self._dropdownScrollY = 0
        return true
    end

    -- Sort dropdown button
    if self._sortBtnRect and pointInRect(mx, my, self._sortBtnRect.x, self._sortBtnRect.y, self._sortBtnRect.w, self._sortBtnRect.h) then
        self._sortDropdownOpen = not self._sortDropdownOpen
        self._dropdownOpen = false
        return true
    end

    -- Item list clicks
    if self._listRect and pointInRect(mx, my, self._listRect.x, self._listRect.y, self._listRect.w, self._listRect.h) then
        local relY = my - self._listRect.y + self._leftScrollY
        local idx = math.floor(relY / LIST_ITEM_H) + 1
        if idx >= 1 and idx <= #self.filteredItems then
            self.selectedIndex = idx
            self._centerScrollY = 0
            -- Clear field widget cache when selection changes
            self._fieldWidgets = {}
            self._focusedField = nil
            UI.clearFocus()
        end
        return true
    end

    -- Bottom buttons
    if self._addBtn:mousepressed(mx, my, button) then return true end
    if self._dupBtn:mousepressed(mx, my, button) then return true end
    if self._delBtn:mousepressed(mx, my, button) then return true end

    -- Center panel field interactions
    local item = self:_getSelectedItem()
    if item and self._centerRect then
        if pointInRect(mx, my, self._centerRect.x, self._centerRect.y, self._centerRect.w, self._centerRect.h) then
            -- Check all registered field widgets
            local handled = self:_handlePropertyClick(item, mx, my, button)
            if handled then return true end
        end
    end

    -- Clear focus if clicking in empty area
    if self._focusedField then
        self._focusedField = nil
        UI.clearFocus()
    end

    return true
end

function ItemEditor:_handlePropertyClick(item, mx, my, button)
    -- Iterate the dedicated hit-rect table (populated during draw)
    for k, rect in pairs(self._hitRects) do
        if type(rect) == "table" and rect.item == item and rect.x then
            if pointInRect(mx, my, rect.x, rect.y, rect.w, rect.h) then
                -- Number increment / decrement
                if (k:sub(1, 6) == "numDec" or k:sub(1, 6) == "numInc") then
                    local field = rect.field
                    local currentVal = tonumber(resolveKey(item, field.key)) or field.default or 0
                    local newVal = currentVal + rect.delta
                    if field.min then newVal = math.max(newVal, field.min) end
                    if field.max then newVal = math.min(newVal, field.max) end
                    self:_setField(item, field.key, newVal, "Set " .. field.label .. " = " .. tostring(newVal))
                    return true

                -- Boolean toggles
                elseif k:sub(1, 7) == "toggle_" then
                    local field = rect.field
                    local currentVal = resolveKey(item, field.key)
                    self:_setField(item, field.key, not currentVal, "Toggle " .. field.label)
                    return true

                -- Select fields (cycle to next option on click)
                elseif k:sub(1, 7) == "select_" then
                    local field = rect.field
                    local options = rect.options or {}
                    if #options > 0 then
                        local currentVal = resolveKey(item, field.key) or ""
                        local currentIdx = 0
                        for i, opt in ipairs(options) do
                            if opt == currentVal then
                                currentIdx = i
                                break
                            end
                        end
                        local nextIdx = currentIdx % #options + 1
                        local newVal = options[nextIdx]
                        self:_setField(item, field.key, newVal, "Set " .. field.label .. " = " .. newVal)
                    end
                    return true

                -- Multiselect chips
                elseif k:sub(1, 5) == "chip_" then
                    local field = rect.field
                    local opt = rect.option
                    local currentVal = resolveKey(item, field.key)
                    if type(currentVal) ~= "table" then currentVal = {} end
                    local newVal = {}
                    local found = false
                    for _, v in ipairs(currentVal) do
                        if v == opt then
                            found = true
                        else
                            newVal[#newVal + 1] = v
                        end
                    end
                    if not found then
                        newVal[#newVal + 1] = opt
                    end
                    self:_setField(item, field.key, newVal, "Toggle " .. field.label .. ": " .. opt)
                    return true
                end
            end
        end
    end

    -- Check text input fields in property grid
    for key, widget in pairs(self._fieldWidgets) do
        if widget.mousepressed and widget:mousepressed(mx, my, button) then
            self._focusedField = {key = key, widget = widget}
            return true
        end
    end

    return false
end

function ItemEditor:mousereleased(mx, my, button)
    if button ~= 1 then return false end

    if self._deleteConfirmActive then
        self._confirmYesBtn:mousereleased(mx, my, button)
        self._confirmNoBtn:mousereleased(mx, my, button)
        return true
    end

    self._addBtn:mousereleased(mx, my, button)
    self._dupBtn:mousereleased(mx, my, button)
    self._delBtn:mousereleased(mx, my, button)

    return false
end

function ItemEditor:wheelmoved(wx, wy)
    local mx, my = love.mouse.getPosition()

    -- Category dropdown scroll
    if self._dropdownOpen and self._dropdownRect then
        if pointInRect(mx, my, self._dropdownRect.x, self._dropdownRect.y, self._dropdownRect.w, self._dropdownRect.h) then
            local totalOptions = 1 + #CATEGORIES
            local totalH = totalOptions * 24
            local maxScroll = math.max(0, totalH - self._dropdownRect.h)
            self._dropdownScrollY = clamp(self._dropdownScrollY - wy * 24, 0, maxScroll)
            return true
        end
    end

    -- Left panel scroll (item list)
    if self._listRect and pointInRect(mx, my, self._listRect.x, self._listRect.y, self._listRect.w, self._listRect.h) then
        self._leftScrollY = clamp(self._leftScrollY - wy * 30, 0, self._leftMaxScroll)
        return true
    end

    -- Center panel scroll (property grid)
    if self._centerRect and pointInRect(mx, my, self._centerRect.x, self._centerRect.y, self._centerRect.w, self._centerRect.h) then
        self._centerScrollY = clamp(self._centerScrollY - wy * 30, 0, self._centerMaxScroll)
        return true
    end

    return false
end

function ItemEditor:keypressed(key)
    -- Delete confirmation
    if self._deleteConfirmActive then
        if key == "return" or key == "kpenter" then
            self:confirmDelete()
            return true
        elseif key == "escape" then
            self:cancelDelete()
            return true
        end
        return true
    end

    -- Close dropdowns
    if key == "escape" then
        if self._dropdownOpen then
            self._dropdownOpen = false
            return true
        end
        if self._sortDropdownOpen then
            self._sortDropdownOpen = false
            return true
        end
        if self._focusedField then
            self._focusedField = nil
            UI.clearFocus()
            return true
        end
    end

    -- Ctrl shortcuts
    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")

    if ctrl and key == "z" then
        self.undoStack:undo()
        -- Refresh field widgets after undo
        self._fieldWidgets = {}
        return true
    end

    if ctrl and key == "y" then
        self.undoStack:redo()
        self._fieldWidgets = {}
        return true
    end

    if ctrl and key == "n" then
        self:addNewItem()
        return true
    end

    if ctrl and key == "d" then
        self:duplicateSelected()
        return true
    end

    if key == "delete" then
        if self:_getSelectedItem() and not self._focusedField then
            self:requestDeleteSelected()
            return true
        end
    end

    -- Forward to focused text field
    if self._focusedField and self._focusedField.widget and self._focusedField.widget.keypressed then
        if self._focusedField.widget:keypressed(key) then
            return true
        end
    end

    -- List navigation (only when no text field is focused)
    if not self._focusedField then
        if key == "up" and self.selectedIndex and self.selectedIndex > 1 then
            self.selectedIndex = self.selectedIndex - 1
            self._fieldWidgets = {}
            self:_ensureSelectedVisible()
            return true
        elseif key == "down" and self.selectedIndex and self.selectedIndex < #self.filteredItems then
            self.selectedIndex = self.selectedIndex + 1
            self._fieldWidgets = {}
            self:_ensureSelectedVisible()
            return true
        elseif key == "up" and not self.selectedIndex and #self.filteredItems > 0 then
            self.selectedIndex = 1
            self._fieldWidgets = {}
            return true
        elseif key == "down" and not self.selectedIndex and #self.filteredItems > 0 then
            self.selectedIndex = 1
            self._fieldWidgets = {}
            return true
        end
    end

    return false
end

function ItemEditor:_ensureSelectedVisible()
    if not self.selectedIndex or not self._listRect then return end
    local itemY = (self.selectedIndex - 1) * LIST_ITEM_H
    if itemY < self._leftScrollY then
        self._leftScrollY = itemY
    elseif itemY + LIST_ITEM_H > self._leftScrollY + self._listRect.h then
        self._leftScrollY = itemY + LIST_ITEM_H - self._listRect.h
    end
    self._leftScrollY = clamp(self._leftScrollY, 0, self._leftMaxScroll)
end

function ItemEditor:textinput(t)
    if self._deleteConfirmActive then return true end

    if self._focusedField and self._focusedField.widget and self._focusedField.widget.textinput then
        return self._focusedField.widget:textinput(t)
    end

    return false
end

-- =========================================================================
-- Public API
-- =========================================================================

function ItemEditor:getItems()
    return self.items
end

function ItemEditor:setItems(items)
    self.items = items or {}
    self.selectedIndex = nil
    self._fieldWidgets = {}
    self._focusedField = nil
    self.undoStack:clear()
    self:_rebuildFilteredList()
end

function ItemEditor:isDirty()
    return self.dirty
end

function ItemEditor:clearDirty()
    self.dirty = false
end

function ItemEditor:getSelectedItem()
    return self:_getSelectedItem()
end

function ItemEditor:getUndoStack()
    return self.undoStack
end

return ItemEditor
