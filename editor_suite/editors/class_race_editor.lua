-- ==========================================================================
-- Class / Race / Background Editor
-- Combined editor with three sub-tabs for managing character creation data.
-- ==========================================================================

local Theme    = require("core.theme")
local FontCache = require("core.fontcache")
local UI       = require("core.ui")
local Undo     = require("core.undo")
local Schema   = require("core.data_schema")
local Search   = require("core.search")
local IdGen    = require("core.id_generator")

-- =========================================================================
-- Local helpers
-- =========================================================================

local STAT_NAMES = { "MIGHT", "VIGOR", "AGILITY", "MIND", "PRESENCE", "SPIRIT", "FAITH" }
local STAT_SHORT = { "MIG", "VIG", "AGI", "MND", "PRS", "SPR", "FAI" }
local UNLOCK_TYPES = { "none", "metric", "location", "achievement" }

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

local function shallowCopy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

--- Build a set of existing ids from an array of entities.
local function collectIds(list)
    local ids = {}
    for _, e in ipairs(list) do
        if e.id then ids[e.id] = true end
    end
    return ids
end

--- Safe nested key read (supports "statMods.MIGHT" style).
local function resolveKey(tbl, key)
    local current = tbl
    for seg in key:gmatch("[^%.]+") do
        if type(current) ~= "table" then return nil end
        current = current[seg]
    end
    return current
end

--- Safe nested key write.
local function setNestedKey(tbl, key, value)
    local segs = {}
    for seg in key:gmatch("[^%.]+") do segs[#segs + 1] = seg end
    local current = tbl
    for i = 1, #segs - 1 do
        if current[segs[i]] == nil then current[segs[i]] = {} end
        current = current[segs[i]]
    end
    current[segs[#segs]] = value
end

-- =========================================================================
-- ClassRaceEditor module
-- =========================================================================

local ClassRaceEditor = {}
ClassRaceEditor.__index = ClassRaceEditor

function ClassRaceEditor.new(project)
    local self = setmetatable({}, ClassRaceEditor)

    self.project = project or {}
    if not self.project.classes then self.project.classes = {} end
    if not self.project.races then self.project.races = {} end
    if not self.project.backgrounds then self.project.backgrounds = {} end

    self.undoStack = Undo.new(100)

    -- Sub-tab state
    self.activeSubTab = "classes"  -- "classes", "races", "backgrounds"
    self.subTabBar = UI.TabBar.new({
        tabs = {
            { label = "Classes",     id = "classes" },
            { label = "Races",       id = "races" },
            { label = "Backgrounds", id = "backgrounds" },
        },
        activeTab = "classes",
        onTabChange = function(id)
            self.activeSubTab = id
            self:_syncListToSubTab()
        end,
    })

    -- Per-sub-tab selection indices
    self.selectedClass = nil
    self.selectedRace = nil
    self.selectedBackground = nil

    -- Scroll containers for lists
    self.classListScroll = UI.ScrollContainer.new({})
    self.raceListScroll = UI.ScrollContainer.new({})
    self.bgListScroll = UI.ScrollContainer.new({})

    -- Scroll containers for center property area
    self.propScroll = UI.ScrollContainer.new({})

    -- Race filter: "all", "base", "unlockable"
    self.raceFilter = "all"

    -- Search / filter text
    self.searchText = ""
    self.searchInput = UI.TextInput.new({
        placeholder = "Search...",
        onChange = function(text)
            self.searchText = text or ""
        end,
    })

    -- Text input widgets for property editing (reused per frame, keyed by field key)
    self._inputWidgets = {}
    self._textAreaWidgets = {}

    -- Color picker state
    self._colorPickerOpen = false
    self._colorPickerTarget = nil  -- "class" or "race"
    self._colorPickerChannel = 1   -- 1=R, 2=G, 3=B
    self._colorSliders = {}

    -- Tag input state
    self._tagInputText = ""
    self._tagInputWidget = UI.TextInput.new({
        placeholder = "Add tag...",
        onChange = function(text) self._tagInputText = text or "" end,
        onSubmit = function(text)
            if self._tagSubmitCallback then
                self._tagSubmitCallback(text)
            end
        end,
    })
    self._tagSubmitCallback = nil

    -- Bonus editor state (for races)
    self._bonusNameInput = UI.TextInput.new({ placeholder = "Bonus name..." })
    self._bonusDescInput = UI.TextInput.new({ placeholder = "Bonus desc..." })

    -- Buttons (created once, callbacks set dynamically)
    self.addBtn = UI.Button.new({ text = "+ Add", variant = "primary", fontSize = 12 })
    self.dupBtn = UI.Button.new({ text = "Dup", variant = "secondary", fontSize = 12 })
    self.delBtn = UI.Button.new({ text = "Del", variant = "danger", fontSize = 12 })

    -- Delete confirmation modal
    self.deleteModal = UI.Modal.new({
        title = "Confirm Delete",
        message = "Are you sure you want to delete this entry?",
        width = 360,
        height = 180,
    })

    -- Track layout rects for input dispatch
    self._lastX = 0
    self._lastY = 0
    self._lastW = 0
    self._lastH = 0

    return self
end

-- =========================================================================
-- Data access helpers
-- =========================================================================

function ClassRaceEditor:_getActiveList()
    if self.activeSubTab == "classes" then
        return self.project.classes
    elseif self.activeSubTab == "races" then
        return self.project.races
    else
        return self.project.backgrounds
    end
end

function ClassRaceEditor:_getActiveSchema()
    if self.activeSubTab == "classes" then
        return Schema.ClassSchema
    elseif self.activeSubTab == "races" then
        return Schema.RaceSchema
    else
        return Schema.BackgroundSchema
    end
end

function ClassRaceEditor:_getSelectedIndex()
    if self.activeSubTab == "classes" then
        return self.selectedClass
    elseif self.activeSubTab == "races" then
        return self.selectedRace
    else
        return self.selectedBackground
    end
end

function ClassRaceEditor:_setSelectedIndex(idx)
    if self.activeSubTab == "classes" then
        self.selectedClass = idx
    elseif self.activeSubTab == "races" then
        self.selectedRace = idx
    else
        self.selectedBackground = idx
    end
end

function ClassRaceEditor:_getSelectedEntity()
    local list = self:_getActiveList()
    local idx = self:_getSelectedIndex()
    if idx and list[idx] then return list[idx] end
    return nil
end

function ClassRaceEditor:_getActiveListScroll()
    if self.activeSubTab == "classes" then
        return self.classListScroll
    elseif self.activeSubTab == "races" then
        return self.raceListScroll
    else
        return self.bgListScroll
    end
end

function ClassRaceEditor:_syncListToSubTab()
    -- Clear stale widgets when switching tabs
    self._inputWidgets = {}
    self._textAreaWidgets = {}
    self.propScroll.scrollY = 0
end

-- =========================================================================
-- Filtered list for display
-- =========================================================================

function ClassRaceEditor:_getFilteredList()
    local list = self:_getActiveList()
    local result = {}

    -- Race filter
    if self.activeSubTab == "races" and self.raceFilter ~= "all" then
        for _, e in ipairs(list) do
            if self.raceFilter == "base" and (not e.unlockType or e.unlockType == "none") then
                result[#result + 1] = e
            elseif self.raceFilter == "unlockable" and e.unlockType and e.unlockType ~= "none" then
                result[#result + 1] = e
            end
        end
    else
        for _, e in ipairs(list) do
            result[#result + 1] = e
        end
    end

    -- Text search
    if self.searchText and self.searchText ~= "" then
        result = Search.filterByText(result, self.searchText, { "id", "name", "desc" })
    end

    return result
end

--- Map a filtered-list index back to the real list index.
function ClassRaceEditor:_filteredToRealIndex(filteredIdx, filteredList)
    if not filteredIdx or not filteredList or not filteredList[filteredIdx] then return nil end
    local target = filteredList[filteredIdx]
    local list = self:_getActiveList()
    for i, e in ipairs(list) do
        if e == target then return i end
    end
    return nil
end

-- =========================================================================
-- CRUD operations (with undo)
-- =========================================================================

function ClassRaceEditor:_addEntity()
    local schema = self:_getActiveSchema()
    local entity = Schema.getDefault(schema)
    local list = self:_getActiveList()
    local tabName = self.activeSubTab

    -- Generate a unique id
    local baseName = "new_" .. tabName:sub(1, -2)  -- "new_class", "new_race", "new_background"
    entity.id = IdGen.ensureUnique(baseName, collectIds(list))
    entity.name = entity.id:gsub("_", " "):gsub("^%l", string.upper)

    local idx = #list + 1
    self.undoStack:push({
        description = "Add " .. tabName:sub(1, -2),
        execute = function()
            table.insert(list, idx, entity)
        end,
        undo = function()
            table.remove(list, idx)
        end,
    })
    self:_setSelectedIndex(idx)
    self._inputWidgets = {}
    self._textAreaWidgets = {}
end

function ClassRaceEditor:_duplicateEntity()
    local idx = self:_getSelectedIndex()
    local list = self:_getActiveList()
    if not idx or not list[idx] then return end

    local original = list[idx]
    local copy = deepCopy(original)
    copy.id = IdGen.ensureUnique(copy.id .. "_copy", collectIds(list))
    copy.name = copy.name .. " (Copy)"
    local tabName = self.activeSubTab
    local insertIdx = idx + 1

    self.undoStack:push({
        description = "Duplicate " .. tabName:sub(1, -2),
        execute = function()
            table.insert(list, insertIdx, copy)
        end,
        undo = function()
            table.remove(list, insertIdx)
        end,
    })
    self:_setSelectedIndex(insertIdx)
    self._inputWidgets = {}
    self._textAreaWidgets = {}
end

function ClassRaceEditor:_deleteEntity()
    local idx = self:_getSelectedIndex()
    local list = self:_getActiveList()
    if not idx or not list[idx] then return end

    local entity = list[idx]
    local tabName = self.activeSubTab

    self.undoStack:push({
        description = "Delete " .. tabName:sub(1, -2) .. " '" .. (entity.name or entity.id or "?") .. "'",
        execute = function()
            table.remove(list, idx)
        end,
        undo = function()
            table.insert(list, idx, entity)
        end,
    })

    if idx > #list then
        self:_setSelectedIndex(#list > 0 and #list or nil)
    end
    self._inputWidgets = {}
    self._textAreaWidgets = {}
end

function ClassRaceEditor:_setField(entity, key, newValue, description)
    local oldValue = deepCopy(resolveKey(entity, key))
    local newVal = deepCopy(newValue)
    description = description or ("Set " .. key)

    self.undoStack:push({
        description = description,
        execute = function()
            setNestedKey(entity, key, deepCopy(newVal))
        end,
        undo = function()
            setNestedKey(entity, key, deepCopy(oldValue))
        end,
    })
end

function ClassRaceEditor:_setFieldCoalesced(entity, key, newValue, groupId)
    local oldValue = deepCopy(resolveKey(entity, key))
    local newVal = deepCopy(newValue)

    self.undoStack:coalesce({
        description = "Edit " .. key,
        execute = function()
            setNestedKey(entity, key, deepCopy(newVal))
        end,
        undo = function()
            setNestedKey(entity, key, deepCopy(oldValue))
        end,
    }, groupId)
end

-- =========================================================================
-- Get or create an input widget for a given field
-- =========================================================================

function ClassRaceEditor:_getInput(key, entity, fieldDef)
    if not self._inputWidgets[key] then
        local currentVal = resolveKey(entity, key)
        self._inputWidgets[key] = UI.TextInput.new({
            text = currentVal ~= nil and tostring(currentVal) or "",
            placeholder = fieldDef and fieldDef.label or key,
            onChange = function(text)
                if not entity then return end
                if fieldDef and fieldDef.type == "number" then
                    local num = tonumber(text)
                    if num then
                        if fieldDef.min then num = math.max(num, fieldDef.min) end
                        if fieldDef.max then num = math.min(num, fieldDef.max) end
                        if fieldDef.step and fieldDef.step >= 1 then
                            num = math.floor(num)
                        end
                        self:_setFieldCoalesced(entity, key, num, "edit_" .. key)
                    end
                else
                    self:_setFieldCoalesced(entity, key, text, "edit_" .. key)
                end
            end,
        })
    end

    -- Sync display text if entity value changed externally (undo/redo)
    local w = self._inputWidgets[key]
    local currentVal = resolveKey(entity, key)
    local displayStr = currentVal ~= nil and tostring(currentVal) or ""
    if not w._focused and w.text ~= displayStr then
        w:setText(displayStr)
    end

    return w
end

function ClassRaceEditor:_getTextArea(key, entity)
    if not self._textAreaWidgets[key] then
        local currentVal = resolveKey(entity, key) or ""
        self._textAreaWidgets[key] = {
            text = tostring(currentVal),
            focused = false,
        }
    end
    local ta = self._textAreaWidgets[key]
    local currentVal = resolveKey(entity, key) or ""
    if not ta.focused and ta.text ~= tostring(currentVal) then
        ta.text = tostring(currentVal)
    end
    return ta
end

-- =========================================================================
-- Update
-- =========================================================================

function ClassRaceEditor:update(dt)
    self.searchInput:update(dt)
    self._tagInputWidget:update(dt)
    self._bonusNameInput:update(dt)
    self._bonusDescInput:update(dt)

    -- Update all active text input widgets
    for _, w in pairs(self._inputWidgets) do
        if w.update then w:update(dt) end
    end
end

-- =========================================================================
-- Drawing
-- =========================================================================

function ClassRaceEditor:draw(x, y, w, h)
    self:_wireButtons()

    self._lastX = x
    self._lastY = y
    self._lastW = w
    self._lastH = h

    -- Background
    setColorSafe(Theme.colors.bg)
    love.graphics.rectangle("fill", x, y, w, h)

    -- Sub-tab bar
    local tabH = Theme.sizes.tabBarHeight
    self.subTabBar:draw(x, y, w, tabH)

    local contentY = y + tabH
    local contentH = h - tabH

    -- Layout: left panel (list) | center (properties) | right (preview)
    local leftW = 220
    local rightW = 240
    local divW = 2
    local centerW = w - leftW - rightW - divW * 2
    if centerW < 200 then
        rightW = 0
        centerW = w - leftW - divW
    end

    local leftX = x
    local centerX = leftX + leftW + divW
    local rightX = centerX + centerW + divW

    -- Left panel
    love.graphics.setScissor(leftX, contentY, leftW, contentH)
    self:_drawLeftPanel(leftX, contentY, leftW, contentH)
    love.graphics.setScissor()

    -- Divider
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", leftX + leftW, contentY, divW, contentH)

    -- Center panel
    love.graphics.setScissor(centerX, contentY, centerW, contentH)
    self:_drawCenterPanel(centerX, contentY, centerW, contentH)
    love.graphics.setScissor()

    -- Right divider and panel
    if rightW > 0 then
        setColorSafe(Theme.colors.panelBorder)
        love.graphics.rectangle("fill", rightX - divW, contentY, divW, contentH)

        love.graphics.setScissor(rightX, contentY, rightW, contentH)
        self:_drawRightPanel(rightX, contentY, rightW, contentH)
        love.graphics.setScissor()
    end

    -- Modal overlay
    self.deleteModal:draw()
end

-- =========================================================================
-- Left panel: entity list + buttons
-- =========================================================================

function ClassRaceEditor:_drawLeftPanel(x, y, w, h)
    local pad = Theme.spacing.md
    local btnH = Theme.sizes.buttonHeight
    local itemH = Theme.sizes.listItemHeight + 2

    -- Panel background
    setColorSafe(Theme.colors.panel)
    love.graphics.rectangle("fill", x, y, w, h)

    local cy = y + pad

    -- Search bar
    self.searchInput:draw(x + pad, cy, w - pad * 2, Theme.sizes.inputHeight)
    cy = cy + Theme.sizes.inputHeight + pad

    -- Race filter buttons (only for races sub-tab)
    if self.activeSubTab == "races" then
        local filters = { "All", "Base", "Unlockable" }
        local filterKeys = { "all", "base", "unlockable" }
        local filterBtnW = math.floor((w - pad * 2 - Theme.spacing.sm * 2) / 3)
        local fx = x + pad
        local font = FontCache.get(11)
        love.graphics.setFont(font)
        for i, label in ipairs(filters) do
            local isActive = (self.raceFilter == filterKeys[i])
            if isActive then
                setColorSafe(Theme.colors.primary)
            else
                setColorSafe(Theme.colors.tabInactive)
            end
            drawRoundedRect("fill", fx, cy, filterBtnW, 22, Theme.radius.sm)
            if isActive then
                setColorSafe(Theme.colors.bg)
            else
                setColorSafe(Theme.colors.textDim)
            end
            local tw = font:getWidth(label)
            love.graphics.print(label, fx + math.floor((filterBtnW - tw) / 2), cy + 3)
            -- Store rect for click
            self["_raceFilterRect" .. i] = { x = fx, y = cy, w = filterBtnW, h = 22, key = filterKeys[i] }
            fx = fx + filterBtnW + Theme.spacing.sm
        end
        cy = cy + 22 + pad
    end

    -- Toolbar buttons
    local btnSpacing = Theme.spacing.sm
    local btnW3 = math.floor((w - pad * 2 - btnSpacing * 2) / 3)

    self.addBtn:draw(x + pad, cy, btnW3, btnH)
    self.dupBtn:draw(x + pad + btnW3 + btnSpacing, cy, btnW3, btnH)
    self.delBtn:draw(x + pad + (btnW3 + btnSpacing) * 2, cy, btnW3, btnH)
    cy = cy + btnH + pad

    -- Separator
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", x + pad, cy, w - pad * 2, 1)
    cy = cy + 1 + pad

    -- Entity list
    local listH = y + h - cy
    local filteredList = self:_getFilteredList()
    local selectedEntity = self:_getSelectedEntity()
    local scroll = self:_getActiveListScroll()
    local totalContentH = #filteredList * itemH
    scroll:setContentHeight(totalContentH)

    local font = FontCache.get(13)
    love.graphics.setFont(font)
    local textH = font:getHeight()
    local mx, my = love.mouse.getPosition()

    scroll:beginDraw(x, cy, w, listH)

    for i, entity in ipairs(filteredList) do
        local iy = (i - 1) * itemH
        local isSelected = (entity == selectedEntity)
        local screenItemY = cy + iy - scroll.scrollY
        local isHovered = pointInRect(mx, my, x, screenItemY, w, itemH)

        -- Row background
        if isSelected then
            setColorSafe(Theme.colors.listItemSelected)
            love.graphics.rectangle("fill", 0, iy, w, itemH)
        elseif isHovered then
            setColorSafe(Theme.colors.listItemHover)
            love.graphics.rectangle("fill", 0, iy, w, itemH)
        elseif i % 2 == 0 then
            setColorSafe(Theme.colors.listItemAlt)
            love.graphics.rectangle("fill", 0, iy, w, itemH)
        end

        -- Color dot (for classes and races)
        local dotX = pad + 4
        local dotCY = iy + math.floor(itemH / 2)
        if entity.color and type(entity.color) == "table" and #entity.color >= 3 then
            setColorSafe(entity.color)
            love.graphics.circle("fill", dotX, dotCY, 5)
            dotX = dotX + 14
        else
            dotX = pad
        end

        -- Name
        setColorSafe(isSelected and Theme.colors.textAccent or Theme.colors.text)
        local name = entity.name or entity.id or "???"
        local textY = iy + math.floor((itemH - textH) / 2)
        love.graphics.print(name, dotX, textY)
    end

    scroll:endDraw()

    -- Store list area for click detection
    self._listArea = { x = x, y = cy, w = w, h = listH, itemH = itemH }
end

-- =========================================================================
-- Center panel: property editor
-- =========================================================================

function ClassRaceEditor:_drawCenterPanel(x, y, w, h)
    setColorSafe(Theme.colors.bgLight)
    love.graphics.rectangle("fill", x, y, w, h)

    local entity = self:_getSelectedEntity()
    if not entity then
        local font = FontCache.get(15)
        love.graphics.setFont(font)
        setColorSafe(Theme.colors.textDim)
        love.graphics.printf("Select an item from the list to edit", x + 20, y + h / 2 - 10, w - 40, "center")
        return
    end

    local pad = Theme.spacing.lg
    local labelW = Theme.sizes.propertyLabelWidth
    local inputH = Theme.sizes.inputHeight
    local rowH = inputH + Theme.spacing.sm
    local contentW = w - pad * 2

    -- Calculate total content height for scroll
    local totalH = self:_calculatePropertyHeight(entity, contentW, labelW, rowH, pad)
    self.propScroll:setContentHeight(totalH)

    self.propScroll:beginDraw(x, y, w, h)

    local cy = pad
    cy = self:_drawPropertyFields(entity, x + pad - x, cy, contentW, labelW, inputH, rowH, pad)

    self.propScroll:endDraw()

    self._propArea = { x = x, y = y, w = w, h = h }
end

function ClassRaceEditor:_calculatePropertyHeight(entity, contentW, labelW, rowH, pad)
    local totalH = pad
    local schema = self:_getActiveSchema()

    if self.activeSubTab == "classes" then
        -- identity: id, name, desc
        totalH = totalH + rowH * 2  -- id, name
        totalH = totalH + 80 + Theme.spacing.sm  -- desc textarea
        -- header
        totalH = totalH + 28
        -- base stats: HP, Atk, Def, Mana
        totalH = totalH + rowH * 4
        -- header
        totalH = totalH + 28
        -- color picker
        totalH = totalH + 50
        -- header
        totalH = totalH + 28
        -- skills tags
        totalH = totalH + 80

    elseif self.activeSubTab == "races" then
        -- identity: id, name, desc
        totalH = totalH + rowH * 2
        totalH = totalH + 80 + Theme.spacing.sm
        -- header
        totalH = totalH + 28
        -- stat mods: 7 stats
        totalH = totalH + rowH * 7
        -- header
        totalH = totalH + 28
        -- bonuses list
        totalH = totalH + math.max(100, (#(entity.bonuses or {}) + 1) * 56)
        -- header
        totalH = totalH + 28
        -- color picker
        totalH = totalH + 50
        -- header
        totalH = totalH + 28
        -- unlock section
        totalH = totalH + rowH  -- unlockType
        if entity.unlockType and entity.unlockType ~= "none" then
            totalH = totalH + rowH  -- unlockCondition
            totalH = totalH + 60    -- unlockHint
        end

    elseif self.activeSubTab == "backgrounds" then
        -- identity: id, name, desc
        totalH = totalH + rowH * 2
        totalH = totalH + 80 + Theme.spacing.sm
        -- header
        totalH = totalH + 28
        -- startingGold
        totalH = totalH + rowH
        -- header
        totalH = totalH + 28
        -- stat mods: 7 stats
        totalH = totalH + rowH * 7
        -- header
        totalH = totalH + 28
        -- starting items tags
        totalH = totalH + 80
        -- header
        totalH = totalH + 28
        -- passives tags
        totalH = totalH + 80
        -- header
        totalH = totalH + 28
        -- general tags
        totalH = totalH + 80
    end

    totalH = totalH + pad * 2
    return totalH
end

function ClassRaceEditor:_drawPropertyFields(entity, x, cy, contentW, labelW, inputH, rowH, pad)
    local font = FontCache.get(13)
    local smallFont = FontCache.get(11)
    local headerFont = FontCache.get(14)
    love.graphics.setFont(font)
    local textH = font:getHeight()
    local fieldW = contentW - labelW - Theme.spacing.md

    -- Helper to draw a section header
    local function drawHeader(label)
        love.graphics.setFont(headerFont)
        setColorSafe(Theme.colors.primary)
        love.graphics.print(label, x, cy + 4)
        cy = cy + 22
        setColorSafe(Theme.colors.panelBorder)
        love.graphics.rectangle("fill", x, cy, contentW, 1)
        cy = cy + 6
        love.graphics.setFont(font)
    end

    -- Helper to draw a label
    local function drawLabel(label, yPos)
        setColorSafe(Theme.colors.textDim)
        love.graphics.setFont(font)
        love.graphics.print(label, x, yPos + math.floor((inputH - textH) / 2))
    end

    -- Helper to draw a text field row
    local function drawTextField(key, label, fieldDef)
        drawLabel(label, cy)
        local input = self:_getInput(key, entity, fieldDef)
        input:draw(x + labelW + Theme.spacing.md, cy, fieldW, inputH)
        cy = cy + rowH
    end

    -- Helper to draw a number row with +/- buttons
    local function drawNumberField(key, label, fieldDef, minVal, maxVal, step)
        drawLabel(label, cy)
        local fdef = fieldDef or { type = "number", min = minVal, max = maxVal, step = step or 1 }
        if not fdef.min then fdef.min = minVal end
        if not fdef.max then fdef.max = maxVal end
        if not fdef.step then fdef.step = step or 1 end
        fdef.type = "number"

        local input = self:_getInput(key, entity, fdef)
        local numFieldW = fieldW - 60
        if numFieldW < 60 then numFieldW = 60 end
        input:draw(x + labelW + Theme.spacing.md, cy, numFieldW, inputH)

        -- +/- buttons
        local btnSize = 24
        local btnX = x + labelW + Theme.spacing.md + numFieldW + 4
        local btnY = cy + math.floor((inputH - btnSize) / 2)
        local currentVal = resolveKey(entity, key) or 0
        if type(currentVal) ~= "number" then currentVal = 0 end

        -- Minus button
        local mx, my = love.mouse.getPosition()
        -- Adjust mouse pos for scroll offset
        local screenBtnY = btnY + self.propScroll.scrollY -- approximate
        local minusHovered = pointInRect(mx, my,
            self._propArea and (self._propArea.x + labelW + Theme.spacing.md + numFieldW + 4 + self._lastX - self._lastX) or btnX,
            0, btnSize, btnSize) -- simplified: we handle click separately
        setColorSafe(Theme.colors.secondary)
        drawRoundedRect("fill", btnX, btnY, btnSize, btnSize, Theme.radius.sm)
        setColorSafe(Theme.colors.text)
        love.graphics.setFont(FontCache.get(14))
        love.graphics.print("-", btnX + 8, btnY + 3)

        -- Plus button
        setColorSafe(Theme.colors.secondary)
        drawRoundedRect("fill", btnX + btnSize + 2, btnY, btnSize, btnSize, Theme.radius.sm)
        setColorSafe(Theme.colors.text)
        love.graphics.print("+", btnX + btnSize + 10, btnY + 3)

        love.graphics.setFont(font)

        -- Store rects for click handling
        self["_numBtn_" .. key] = {
            minusRect = { x = btnX, y = btnY, w = btnSize, h = btnSize },
            plusRect = { x = btnX + btnSize + 2, y = btnY, w = btnSize, h = btnSize },
            entity = entity,
            key = key,
            min = fdef.min,
            max = fdef.max,
            step = fdef.step,
        }

        cy = cy + rowH
    end

    -- Helper to draw a multiline text area
    local function drawTextArea(key, label, areaHeight)
        areaHeight = areaHeight or 70
        drawLabel(label, cy)
        local currentVal = resolveKey(entity, key) or ""
        if type(currentVal) ~= "string" then currentVal = tostring(currentVal) end

        -- Draw as a bordered area with text
        local areaX = x + labelW + Theme.spacing.md
        local areaW = fieldW

        setColorSafe(Theme.colors.input)
        drawRoundedRect("fill", areaX, cy, areaW, areaHeight, Theme.radius.sm)
        setColorSafe(Theme.colors.inputBorder)
        love.graphics.setLineWidth(1)
        drawRoundedRect("line", areaX + 0.5, cy + 0.5, areaW - 1, areaHeight - 1, Theme.radius.sm)

        -- Use a TextInput for editing (single line, but display is multiline)
        local input = self:_getInput(key, entity, { type = "string", label = label })
        input:draw(areaX + 2, cy + 2, areaW - 4, areaHeight - 4)

        -- Display wrapped text overlay if not focused
        if not input._focused then
            setColorSafe(Theme.colors.input)
            drawRoundedRect("fill", areaX + 1, cy + 1, areaW - 2, areaHeight - 2, Theme.radius.sm)
            love.graphics.setFont(smallFont)
            setColorSafe(currentVal ~= "" and Theme.colors.text or Theme.colors.textDim)
            local displayText = currentVal ~= "" and currentVal or "(empty)"
            love.graphics.printf(displayText, areaX + Theme.spacing.md, cy + Theme.spacing.sm, areaW - Theme.spacing.md * 2, "left")
        end

        love.graphics.setFont(font)
        cy = cy + areaHeight + Theme.spacing.sm
    end

    -- Helper to draw color picker
    local function drawColorPicker(key, label)
        drawLabel(label, cy)

        local color = resolveKey(entity, key)
        if not color or type(color) ~= "table" or #color < 3 then
            color = { 0.5, 0.5, 0.5 }
        end

        local pickerX = x + labelW + Theme.spacing.md
        local swatchSize = 36

        -- Color swatch
        setColorSafe(color)
        drawRoundedRect("fill", pickerX, cy + 2, swatchSize, swatchSize, Theme.radius.sm)
        setColorSafe(Theme.colors.panelBorder)
        love.graphics.setLineWidth(1)
        drawRoundedRect("line", pickerX + 0.5, cy + 2.5, swatchSize - 1, swatchSize - 1, Theme.radius.sm)

        -- RGB sliders (compact)
        local sliderX = pickerX + swatchSize + Theme.spacing.lg
        local sliderW = fieldW - swatchSize - Theme.spacing.lg
        if sliderW < 60 then sliderW = 60 end
        local channels = { "R", "G", "B" }
        local sliderH = 10
        local sliderSpacing = 2

        for c = 1, 3 do
            local sy = cy + 2 + (c - 1) * (sliderH + sliderSpacing)
            local val = color[c] or 0

            -- Channel label
            love.graphics.setFont(smallFont)
            setColorSafe(Theme.colors.textDim)
            love.graphics.print(channels[c], sliderX, sy - 1)

            -- Slider track
            local trackX = sliderX + 16
            local trackW = sliderW - 46
            if trackW < 30 then trackW = 30 end
            setColorSafe(Theme.colors.scrollbar)
            drawRoundedRect("fill", trackX, sy + 1, trackW, sliderH - 2, 3)

            -- Filled portion
            local fillColor
            if c == 1 then fillColor = { val, 0.2, 0.2 }
            elseif c == 2 then fillColor = { 0.2, val, 0.2 }
            else fillColor = { 0.2, 0.2, val } end
            setColorSafe(fillColor)
            local fillW = val * trackW
            if fillW > 0 then
                drawRoundedRect("fill", trackX, sy + 1, fillW, sliderH - 2, 3)
            end

            -- Thumb
            setColorSafe(Theme.colors.text)
            local thumbX = trackX + val * trackW
            love.graphics.circle("fill", thumbX, sy + sliderH / 2, 4)

            -- Value text
            love.graphics.setFont(smallFont)
            setColorSafe(Theme.colors.textDim)
            love.graphics.print(string.format("%.2f", val), trackX + trackW + 4, sy - 1)

            -- Store slider rect for click
            self["_colorSlider_" .. key .. "_" .. c] = {
                x = trackX, y = sy + 1, w = trackW, h = sliderH - 2,
                entity = entity, key = key, channel = c,
            }
        end

        love.graphics.setFont(font)
        cy = cy + 44
    end

    -- Helper to draw tag picker
    local function drawTagPicker(key, label, areaHeight)
        areaHeight = areaHeight or 70
        drawLabel(label, cy)

        local tags = resolveKey(entity, key)
        if not tags or type(tags) ~= "table" then tags = {} end

        local areaX = x + labelW + Theme.spacing.md
        local areaW = fieldW

        setColorSafe(Theme.colors.input)
        drawRoundedRect("fill", areaX, cy, areaW, areaHeight, Theme.radius.sm)
        setColorSafe(Theme.colors.inputBorder)
        love.graphics.setLineWidth(1)
        drawRoundedRect("line", areaX + 0.5, cy + 0.5, areaW - 1, areaHeight - 1, Theme.radius.sm)

        -- Draw tags as chips
        local chipX = areaX + Theme.spacing.sm
        local chipY = cy + Theme.spacing.sm
        local chipH = 20
        local maxTagsW = areaW - Theme.spacing.sm * 2
        love.graphics.setFont(smallFont)

        for i, tag in ipairs(tags) do
            local tagText = tostring(tag)
            local tagW = smallFont:getWidth(tagText) + 20 + 12  -- padding + X button

            -- Wrap to next line if needed
            if chipX + tagW > areaX + maxTagsW and chipX > areaX + Theme.spacing.sm then
                chipX = areaX + Theme.spacing.sm
                chipY = chipY + chipH + 3
            end

            -- Chip background
            setColorSafe(Theme.colors.secondary)
            drawRoundedRect("fill", chipX, chipY, tagW, chipH, chipH / 2)

            -- Chip text
            setColorSafe(Theme.colors.text)
            love.graphics.print(tagText, chipX + 8, chipY + 3)

            -- X button
            setColorSafe(Theme.colors.danger)
            love.graphics.print("x", chipX + tagW - 14, chipY + 3)

            -- Store chip rect for removal click
            self["_tagChip_" .. key .. "_" .. i] = {
                x = chipX + tagW - 18, y = chipY, w = 18, h = chipH,
                entity = entity, key = key, index = i,
            }

            chipX = chipX + tagW + 4
        end

        -- Tag input at bottom
        local inputY = cy + areaHeight - Theme.sizes.inputHeight - 2
        self._tagInputWidget:draw(areaX + 2, inputY, areaW - 4, Theme.sizes.inputHeight)

        -- Set up submit callback for this field
        self._tagSubmitCallback = function(text)
            if text and text ~= "" then
                local currentTags = resolveKey(entity, key)
                if not currentTags or type(currentTags) ~= "table" then currentTags = {} end
                local newTags = deepCopy(currentTags)
                table.insert(newTags, text)
                self:_setField(entity, key, newTags, "Add tag to " .. key)
                self._tagInputWidget:setText("")
                self._tagInputText = ""
            end
        end

        love.graphics.setFont(font)
        cy = cy + areaHeight + Theme.spacing.sm
    end

    -- Helper to draw stat mod row with +/- range
    local function drawStatModField(statName, parentKey)
        local key = parentKey .. "." .. statName
        local shortIdx = nil
        for i, s in ipairs(STAT_NAMES) do
            if s == statName then shortIdx = i; break end
        end
        local label = STAT_SHORT[shortIdx or 1] .. " (" .. statName .. ")"
        drawNumberField(key, label, nil, -5, 5, 1)
    end

    -- =====================================================================
    -- Draw fields based on active sub-tab
    -- =====================================================================

    if self.activeSubTab == "classes" then
        drawHeader("Identity")
        drawTextField("id", "ID", { type = "string", label = "ID" })
        drawTextField("name", "Name", { type = "string", label = "Name" })
        drawTextArea("desc", "Description", 70)

        drawHeader("Base Stats")
        drawNumberField("baseHP", "Base HP", nil, 1, 500, 5)
        drawNumberField("baseAtk", "Base ATK", nil, 1, 100, 1)
        drawNumberField("baseDef", "Base DEF", nil, 1, 100, 1)
        drawNumberField("baseMana", "Base Mana", nil, 0, 500, 5)

        drawHeader("Display")
        drawColorPicker("color", "Color")

        drawHeader("Skills")
        drawTagPicker("skills", "Skills", 80)

    elseif self.activeSubTab == "races" then
        drawHeader("Identity")
        drawTextField("id", "ID", { type = "string", label = "ID" })
        drawTextField("name", "Name", { type = "string", label = "Name" })
        drawTextArea("desc", "Description", 70)

        drawHeader("Stat Modifiers")
        -- Ensure statMods table exists
        if not entity.statMods then entity.statMods = {} end
        for _, stat in ipairs(STAT_NAMES) do
            if entity.statMods[stat] == nil then entity.statMods[stat] = 0 end
            drawStatModField(stat, "statMods")
        end

        drawHeader("Bonuses")
        self:_drawBonusEditor(entity, x, cy, contentW, labelW, fieldW)
        local bonuses = entity.bonuses or {}
        cy = cy + math.max(100, (#bonuses + 1) * 56)

        drawHeader("Display")
        drawColorPicker("color", "Color")

        drawHeader("Unlock")
        -- UnlockType dropdown (drawn as text field with known options)
        drawLabel("Unlock Type", cy)
        local utInput = self:_getInput("unlockType", entity, { type = "string", label = "Unlock Type" })
        utInput:draw(x + labelW + Theme.spacing.md, cy, fieldW, inputH)
        -- Draw option hints
        love.graphics.setFont(smallFont)
        setColorSafe(Theme.colors.textDim)
        love.graphics.print("Options: none, metric, location, achievement", x + labelW + Theme.spacing.md, cy + inputH + 1)
        love.graphics.setFont(font)
        cy = cy + rowH + 12

        if entity.unlockType and entity.unlockType ~= "none" then
            drawTextField("unlockHint", "Unlock Hint", { type = "string", label = "Hint" })
        end

    elseif self.activeSubTab == "backgrounds" then
        drawHeader("Identity")
        drawTextField("id", "ID", { type = "string", label = "ID" })
        drawTextField("name", "Name", { type = "string", label = "Name" })
        drawTextArea("desc", "Description", 70)

        drawHeader("Economics")
        drawNumberField("startingGold", "Starting Gold", nil, 0, 1000, 5)

        drawHeader("Stat Modifiers")
        if not entity.statMods then entity.statMods = {} end
        for _, stat in ipairs(STAT_NAMES) do
            if entity.statMods[stat] == nil then entity.statMods[stat] = 0 end
            drawStatModField(stat, "statMods")
        end

        drawHeader("Starting Items")
        drawTagPicker("startingItems", "Items", 80)

        drawHeader("Passives")
        drawTagPicker("passives", "Passives", 80)

        drawHeader("Tags")
        drawTagPicker("tags", "Tags", 80)
    end

    return cy
end

-- =========================================================================
-- Bonus list editor (for races)
-- =========================================================================

function ClassRaceEditor:_drawBonusEditor(entity, x, cy, contentW, labelW, fieldW)
    local bonuses = entity.bonuses or {}
    local font = FontCache.get(12)
    local smallFont = FontCache.get(11)
    love.graphics.setFont(font)

    local editorX = x + Theme.spacing.md
    local editorW = contentW - Theme.spacing.md * 2
    local itemH = 50
    local pad = Theme.spacing.sm

    self._bonusRects = {}

    for i, bonus in ipairs(bonuses) do
        local iy = cy + (i - 1) * (itemH + pad)

        -- Background
        setColorSafe(Theme.colors.listItemAlt)
        drawRoundedRect("fill", editorX, iy, editorW, itemH, Theme.radius.sm)

        -- Bonus name
        love.graphics.setFont(font)
        setColorSafe(Theme.colors.textAccent)
        love.graphics.print(bonus.name or "(unnamed)", editorX + pad, iy + 4)

        -- Bonus desc
        love.graphics.setFont(smallFont)
        setColorSafe(Theme.colors.textDim)
        love.graphics.printf(bonus.desc or "", editorX + pad, iy + 20, editorW - 40, "left")

        -- Delete button
        local delBtnX = editorX + editorW - 24
        local delBtnY = iy + 4
        setColorSafe(Theme.colors.danger)
        drawRoundedRect("fill", delBtnX, delBtnY, 20, 18, Theme.radius.sm)
        setColorSafe(Theme.colors.text)
        love.graphics.setFont(FontCache.get(11))
        love.graphics.print("X", delBtnX + 5, delBtnY + 2)

        self._bonusRects[i] = {
            delRect = { x = delBtnX, y = iy, w = 20, h = 20 },
            fullRect = { x = editorX, y = iy, w = editorW, h = itemH },
        }
    end

    -- Add bonus row
    local addY = cy + #bonuses * (itemH + pad)
    setColorSafe(Theme.colors.panel)
    drawRoundedRect("fill", editorX, addY, editorW, itemH, Theme.radius.sm)
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", editorX + 0.5, addY + 0.5, editorW - 1, itemH - 1, Theme.radius.sm)

    -- Name + Desc inputs on the add row
    local halfW = math.floor((editorW - pad * 3) / 2)
    self._bonusNameInput:draw(editorX + pad, addY + 4, halfW, 20)
    self._bonusDescInput:draw(editorX + pad + halfW + pad, addY + 4, halfW, 20)

    -- Add button
    love.graphics.setFont(FontCache.get(12))
    local addBtnW = 50
    local addBtnX = editorX + math.floor((editorW - addBtnW) / 2)
    local addBtnY = addY + 28
    setColorSafe(Theme.colors.primary)
    drawRoundedRect("fill", addBtnX, addBtnY, addBtnW, 18, Theme.radius.sm)
    setColorSafe(Theme.colors.bg)
    local tw = FontCache.get(12):getWidth("+ Add")
    love.graphics.print("+ Add", addBtnX + math.floor((addBtnW - tw) / 2), addBtnY + 2)

    self._addBonusRect = { x = addBtnX, y = addBtnY, w = addBtnW, h = 18, entity = entity }

    love.graphics.setFont(FontCache.get(13))
end

-- =========================================================================
-- Right panel: preview / visualization
-- =========================================================================

function ClassRaceEditor:_drawRightPanel(x, y, w, h)
    setColorSafe(Theme.colors.panel)
    love.graphics.rectangle("fill", x, y, w, h)

    local entity = self:_getSelectedEntity()
    if not entity then
        local font = FontCache.get(12)
        love.graphics.setFont(font)
        setColorSafe(Theme.colors.textDim)
        love.graphics.printf("No selection", x + 10, y + h / 2 - 8, w - 20, "center")
        return
    end

    local pad = Theme.spacing.lg
    local cy = y + pad

    if self.activeSubTab == "classes" then
        self:_drawClassPreview(entity, x, cy, w, h - pad * 2)
    elseif self.activeSubTab == "races" then
        self:_drawRacePreview(entity, x, cy, w, h - pad * 2)
    elseif self.activeSubTab == "backgrounds" then
        self:_drawBackgroundPreview(entity, x, cy, w, h - pad * 2)
    end
end

function ClassRaceEditor:_drawClassPreview(entity, x, cy, w, h)
    local pad = Theme.spacing.lg
    local font = FontCache.get(13)
    local headerFont = FontCache.get(15)
    local smallFont = FontCache.get(11)

    -- Title
    love.graphics.setFont(headerFont)
    setColorSafe(Theme.colors.textAccent)
    love.graphics.printf(entity.name or "Unnamed", x + pad, cy, w - pad * 2, "center")
    cy = cy + 24

    -- Color swatch preview
    if entity.color and type(entity.color) == "table" and #entity.color >= 3 then
        local swatchW = 60
        local swatchH = 20
        local sx = x + math.floor((w - swatchW) / 2)
        setColorSafe(entity.color)
        drawRoundedRect("fill", sx, cy, swatchW, swatchH, Theme.radius.sm)
        setColorSafe(Theme.colors.panelBorder)
        love.graphics.setLineWidth(1)
        drawRoundedRect("line", sx + 0.5, cy + 0.5, swatchW - 1, swatchH - 1, Theme.radius.sm)
        cy = cy + swatchH + Theme.spacing.lg
    else
        cy = cy + Theme.spacing.lg
    end

    -- Stat bars
    love.graphics.setFont(font)
    local stats = {
        { label = "HP",   value = entity.baseHP or 0,   max = 500, color = {0.3, 0.8, 0.3} },
        { label = "ATK",  value = entity.baseAtk or 0,  max = 100, color = {0.8, 0.3, 0.3} },
        { label = "DEF",  value = entity.baseDef or 0,  max = 100, color = {0.3, 0.5, 0.8} },
        { label = "Mana", value = entity.baseMana or 0, max = 500, color = {0.5, 0.3, 0.8} },
    }

    setColorSafe(Theme.colors.text)
    love.graphics.print("Stat Overview", x + pad, cy)
    cy = cy + 20

    for _, stat in ipairs(stats) do
        love.graphics.setFont(smallFont)
        setColorSafe(Theme.colors.textDim)
        love.graphics.print(stat.label, x + pad, cy + 1)

        local barX = x + pad + 40
        local barW = w - pad * 2 - 40 - 36
        local barH = 12

        -- Track
        setColorSafe(Theme.colors.scrollbar)
        drawRoundedRect("fill", barX, cy + 2, barW, barH, barH / 2)

        -- Fill
        local ratio = stat.max > 0 and clamp(stat.value / stat.max, 0, 1) or 0
        setColorSafe(stat.color)
        if ratio > 0 then
            drawRoundedRect("fill", barX, cy + 2, barW * ratio, barH, barH / 2)
        end

        -- Value text
        setColorSafe(Theme.colors.text)
        love.graphics.print(tostring(math.floor(stat.value)), barX + barW + 4, cy + 1)

        cy = cy + 20
    end

    -- Skills list
    cy = cy + Theme.spacing.lg
    love.graphics.setFont(font)
    setColorSafe(Theme.colors.text)
    love.graphics.print("Skills", x + pad, cy)
    cy = cy + 18

    love.graphics.setFont(smallFont)
    local skills = entity.skills or {}
    if #skills == 0 then
        setColorSafe(Theme.colors.textDim)
        love.graphics.print("(none)", x + pad + 8, cy)
    else
        for _, skill in ipairs(skills) do
            setColorSafe(Theme.colors.info)
            love.graphics.print("- " .. tostring(skill), x + pad + 8, cy)
            cy = cy + 16
        end
    end
end

function ClassRaceEditor:_drawRacePreview(entity, x, cy, w, h)
    local pad = Theme.spacing.lg
    local font = FontCache.get(13)
    local headerFont = FontCache.get(15)
    local smallFont = FontCache.get(11)

    -- Title
    love.graphics.setFont(headerFont)
    setColorSafe(Theme.colors.textAccent)
    love.graphics.printf(entity.name or "Unnamed", x + pad, cy, w - pad * 2, "center")
    cy = cy + 24

    -- Color swatch
    if entity.color and type(entity.color) == "table" and #entity.color >= 3 then
        local swatchW = 60
        local swatchH = 20
        local sx = x + math.floor((w - swatchW) / 2)
        setColorSafe(entity.color)
        drawRoundedRect("fill", sx, cy, swatchW, swatchH, Theme.radius.sm)
        setColorSafe(Theme.colors.panelBorder)
        love.graphics.setLineWidth(1)
        drawRoundedRect("line", sx + 0.5, cy + 0.5, swatchW - 1, swatchH - 1, Theme.radius.sm)
        cy = cy + swatchH + Theme.spacing.lg
    else
        cy = cy + Theme.spacing.lg
    end

    -- Stat modifier visualization (green positive, red negative)
    love.graphics.setFont(font)
    setColorSafe(Theme.colors.text)
    love.graphics.print("Stat Modifiers", x + pad, cy)
    cy = cy + 20

    local statMods = entity.statMods or {}
    local barMaxVal = 5
    local barW = w - pad * 2 - 50 - 30
    local barH = 12
    local centerX = x + pad + 50 + barW / 2

    for i, stat in ipairs(STAT_NAMES) do
        local val = statMods[stat] or 0

        love.graphics.setFont(smallFont)
        setColorSafe(Theme.colors.textDim)
        love.graphics.print(STAT_SHORT[i], x + pad, cy + 1)

        -- Center line
        setColorSafe(Theme.colors.scrollbar)
        drawRoundedRect("fill", x + pad + 50, cy + 2, barW, barH, barH / 2)

        -- Center marker
        setColorSafe(Theme.colors.panelBorder)
        love.graphics.rectangle("fill", centerX - 0.5, cy, 1, barH + 4)

        -- Value bar
        if val > 0 then
            setColorSafe(Theme.colors.success)
            local fillW = (val / barMaxVal) * (barW / 2)
            drawRoundedRect("fill", centerX, cy + 2, fillW, barH, barH / 2)
        elseif val < 0 then
            setColorSafe(Theme.colors.danger)
            local fillW = (math.abs(val) / barMaxVal) * (barW / 2)
            drawRoundedRect("fill", centerX - fillW, cy + 2, fillW, barH, barH / 2)
        end

        -- Value text
        setColorSafe(val > 0 and Theme.colors.success or (val < 0 and Theme.colors.danger or Theme.colors.textDim))
        local valStr = val > 0 and ("+" .. val) or tostring(val)
        love.graphics.print(valStr, x + pad + 50 + barW + 4, cy + 1)

        cy = cy + 20
    end

    -- Bonuses summary
    cy = cy + Theme.spacing.lg
    love.graphics.setFont(font)
    setColorSafe(Theme.colors.text)
    love.graphics.print("Bonuses", x + pad, cy)
    cy = cy + 18

    love.graphics.setFont(smallFont)
    local bonuses = entity.bonuses or {}
    if #bonuses == 0 then
        setColorSafe(Theme.colors.textDim)
        love.graphics.print("(none)", x + pad + 8, cy)
    else
        for _, bonus in ipairs(bonuses) do
            setColorSafe(Theme.colors.textAccent)
            love.graphics.print(bonus.name or "?", x + pad + 8, cy)
            cy = cy + 14
            setColorSafe(Theme.colors.textDim)
            love.graphics.printf(bonus.desc or "", x + pad + 16, cy, w - pad * 2 - 24, "left")
            cy = cy + 16
        end
    end

    -- Unlock info
    if entity.unlockType and entity.unlockType ~= "none" then
        cy = cy + Theme.spacing.lg
        love.graphics.setFont(font)
        setColorSafe(Theme.colors.warning)
        love.graphics.print("Unlock: " .. entity.unlockType, x + pad, cy)
        cy = cy + 16
        love.graphics.setFont(smallFont)
        setColorSafe(Theme.colors.textDim)
        if entity.unlockHint and entity.unlockHint ~= "" then
            love.graphics.printf("Hint: " .. entity.unlockHint, x + pad + 8, cy, w - pad * 2 - 16, "left")
        end
    end
end

function ClassRaceEditor:_drawBackgroundPreview(entity, x, cy, w, h)
    local pad = Theme.spacing.lg
    local font = FontCache.get(13)
    local headerFont = FontCache.get(15)
    local smallFont = FontCache.get(11)

    -- Title
    love.graphics.setFont(headerFont)
    setColorSafe(Theme.colors.textAccent)
    love.graphics.printf(entity.name or "Unnamed", x + pad, cy, w - pad * 2, "center")
    cy = cy + 24

    -- Starting gold
    love.graphics.setFont(font)
    setColorSafe(Theme.colors.primary)
    local goldStr = "Starting Gold: " .. tostring(entity.startingGold or 0)
    love.graphics.printf(goldStr, x + pad, cy, w - pad * 2, "center")
    cy = cy + 22

    -- Stat modifier visualization
    love.graphics.setFont(font)
    setColorSafe(Theme.colors.text)
    love.graphics.print("Stat Modifiers", x + pad, cy)
    cy = cy + 20

    local statMods = entity.statMods or {}
    local barMaxVal = 5
    local barW = w - pad * 2 - 50 - 30
    local barH = 12
    local centerBarX = x + pad + 50 + barW / 2

    for i, stat in ipairs(STAT_NAMES) do
        local val = statMods[stat] or 0

        love.graphics.setFont(smallFont)
        setColorSafe(Theme.colors.textDim)
        love.graphics.print(STAT_SHORT[i], x + pad, cy + 1)

        setColorSafe(Theme.colors.scrollbar)
        drawRoundedRect("fill", x + pad + 50, cy + 2, barW, barH, barH / 2)

        setColorSafe(Theme.colors.panelBorder)
        love.graphics.rectangle("fill", centerBarX - 0.5, cy, 1, barH + 4)

        if val > 0 then
            setColorSafe(Theme.colors.success)
            local fillW = (val / barMaxVal) * (barW / 2)
            drawRoundedRect("fill", centerBarX, cy + 2, fillW, barH, barH / 2)
        elseif val < 0 then
            setColorSafe(Theme.colors.danger)
            local fillW = (math.abs(val) / barMaxVal) * (barW / 2)
            drawRoundedRect("fill", centerBarX - fillW, cy + 2, fillW, barH, barH / 2)
        end

        setColorSafe(val > 0 and Theme.colors.success or (val < 0 and Theme.colors.danger or Theme.colors.textDim))
        local valStr = val > 0 and ("+" .. val) or tostring(val)
        love.graphics.print(valStr, x + pad + 50 + barW + 4, cy + 1)

        cy = cy + 20
    end

    -- Starting items
    cy = cy + Theme.spacing.lg
    love.graphics.setFont(font)
    setColorSafe(Theme.colors.text)
    love.graphics.print("Starting Items", x + pad, cy)
    cy = cy + 18

    love.graphics.setFont(smallFont)
    local items = entity.startingItems or {}
    if #items == 0 then
        setColorSafe(Theme.colors.textDim)
        love.graphics.print("(none)", x + pad + 8, cy)
        cy = cy + 14
    else
        for _, item in ipairs(items) do
            setColorSafe(Theme.colors.info)
            love.graphics.print("- " .. tostring(item), x + pad + 8, cy)
            cy = cy + 14
        end
    end

    -- Passives
    cy = cy + Theme.spacing.md
    love.graphics.setFont(font)
    setColorSafe(Theme.colors.text)
    love.graphics.print("Passives", x + pad, cy)
    cy = cy + 18

    love.graphics.setFont(smallFont)
    local passives = entity.passives or {}
    if #passives == 0 then
        setColorSafe(Theme.colors.textDim)
        love.graphics.print("(none)", x + pad + 8, cy)
        cy = cy + 14
    else
        for _, p in ipairs(passives) do
            setColorSafe(Theme.colors.success)
            love.graphics.print("- " .. tostring(p), x + pad + 8, cy)
            cy = cy + 14
        end
    end

    -- Tags
    cy = cy + Theme.spacing.md
    love.graphics.setFont(font)
    setColorSafe(Theme.colors.text)
    love.graphics.print("Tags", x + pad, cy)
    cy = cy + 18

    love.graphics.setFont(smallFont)
    local tags = entity.tags or {}
    if #tags == 0 then
        setColorSafe(Theme.colors.textDim)
        love.graphics.print("(none)", x + pad + 8, cy)
    else
        local tagLine = table.concat(tags, ", ")
        setColorSafe(Theme.colors.textDim)
        love.graphics.printf(tagLine, x + pad + 8, cy, w - pad * 2 - 16, "left")
    end
end

-- =========================================================================
-- Input: mousepressed
-- =========================================================================

function ClassRaceEditor:mousepressed(mx, my, button)
    if button ~= 1 then return false end

    -- Modal gets priority
    if self.deleteModal.visible then
        self.deleteModal:mousepressed(mx, my, button)
        return true
    end

    -- Sub-tab bar
    if self.subTabBar:mousepressed(mx, my, button) then
        return true
    end

    -- Search input
    if self.searchInput:mousepressed(mx, my, button) then
        return true
    end

    -- Race filter buttons
    if self.activeSubTab == "races" then
        for i = 1, 3 do
            local rect = self["_raceFilterRect" .. i]
            if rect and pointInRect(mx, my, rect.x, rect.y, rect.w, rect.h) then
                self.raceFilter = rect.key
                return true
            end
        end
    end

    -- CRUD buttons
    local tabH = Theme.sizes.tabBarHeight
    local contentY = self._lastY + tabH

    -- Determine if click is in left panel
    local leftW = 220
    if pointInRect(mx, my, self._lastX, contentY, leftW, self._lastH - tabH) then
        -- Add button
        if self.addBtn:mousepressed(mx, my, button) then return true end
        if self.dupBtn:mousepressed(mx, my, button) then return true end
        if self.delBtn:mousepressed(mx, my, button) then return true end

        -- List scroll
        local scroll = self:_getActiveListScroll()
        if scroll:mousepressed(mx, my, button) then return true end

        -- List item click
        if self._listArea then
            local la = self._listArea
            if pointInRect(mx, my, la.x, la.y, la.w, la.h) then
                local relY = my - la.y + scroll.scrollY
                local filteredIdx = math.floor(relY / la.itemH) + 1
                local filteredList = self:_getFilteredList()
                if filteredIdx >= 1 and filteredIdx <= #filteredList then
                    local realIdx = self:_filteredToRealIndex(filteredIdx, filteredList)
                    if realIdx then
                        self:_setSelectedIndex(realIdx)
                        self._inputWidgets = {}
                        self._textAreaWidgets = {}
                        self.propScroll.scrollY = 0
                    end
                end
                return true
            end
        end

        return true
    end

    -- Property area scroll and inputs
    if self._propArea and pointInRect(mx, my, self._propArea.x, self._propArea.y, self._propArea.w, self._propArea.h) then
        -- Scroll container
        if self.propScroll:mousepressed(mx, my, button) then return true end

        -- Handle color slider clicks
        self:_handleColorSliderClick(mx, my)

        -- Handle +/- number buttons
        self:_handleNumberButtonClick(mx, my)

        -- Handle tag chip removal
        self:_handleTagChipClick(mx, my)

        -- Handle bonus add/delete
        self:_handleBonusClick(mx, my)

        -- Text input widgets
        for _, w in pairs(self._inputWidgets) do
            if w.mousepressed then w:mousepressed(mx, my, button) end
        end

        -- Tag input
        self._tagInputWidget:mousepressed(mx, my, button)
        self._bonusNameInput:mousepressed(mx, my, button)
        self._bonusDescInput:mousepressed(mx, my, button)

        return true
    end

    return false
end

function ClassRaceEditor:_handleColorSliderClick(mx, my)
    for skey, slider in pairs(self) do
        if type(skey) == "string" and skey:match("^_colorSlider_") and type(slider) == "table" and slider.x then
            -- Content-space coords to screen: beginDraw translates by (propArea.x, propArea.y - scrollY)
            local screenX = self._propArea.x + slider.x
            local screenY = self._propArea.y - self.propScroll.scrollY + slider.y

            if pointInRect(mx, my, screenX, screenY, slider.w, slider.h + 4) then
                local t = clamp((mx - screenX) / slider.w, 0, 1)
                local entity = slider.entity
                local key = slider.key
                local channel = slider.channel
                local color = resolveKey(entity, key)
                if color and type(color) == "table" and #color >= 3 then
                    local newColor = { color[1], color[2], color[3] }
                    newColor[channel] = math.floor(t * 100) / 100
                    self:_setFieldCoalesced(entity, key, newColor, "color_" .. key .. "_" .. channel)
                end
                self._activeColorSlider = skey
                return
            end
        end
    end
end

function ClassRaceEditor:_handleNumberButtonClick(mx, my)
    for skey, info in pairs(self) do
        if type(skey) == "string" and skey:match("^_numBtn_") and type(info) == "table" and info.minusRect then
            -- Convert content-space rects to screen space
            local offsetX = self._propArea.x
            local offsetY = self._propArea.y - self.propScroll.scrollY

            local mr = info.minusRect
            local pr = info.plusRect
            local smx = mr.x + offsetX
            local smy = mr.y + offsetY
            local spx = pr.x + offsetX
            local spy = pr.y + offsetY

            if pointInRect(mx, my, smx, smy, mr.w, mr.h) then
                local currentVal = resolveKey(info.entity, info.key) or 0
                if type(currentVal) ~= "number" then currentVal = 0 end
                local newVal = clamp(currentVal - (info.step or 1), info.min or -999999, info.max or 999999)
                self:_setField(info.entity, info.key, newVal, "Decrease " .. info.key)
                -- Refresh the text input widget
                self._inputWidgets[info.key] = nil
                return
            end

            if pointInRect(mx, my, spx, spy, pr.w, pr.h) then
                local currentVal = resolveKey(info.entity, info.key) or 0
                if type(currentVal) ~= "number" then currentVal = 0 end
                local newVal = clamp(currentVal + (info.step or 1), info.min or -999999, info.max or 999999)
                self:_setField(info.entity, info.key, newVal, "Increase " .. info.key)
                self._inputWidgets[info.key] = nil
                return
            end
        end
    end
end

function ClassRaceEditor:_handleTagChipClick(mx, my)
    for skey, info in pairs(self) do
        if type(skey) == "string" and skey:match("^_tagChip_") and type(info) == "table" and info.x then
            local screenX = self._propArea.x + info.x
            local screenY = self._propArea.y - self.propScroll.scrollY + info.y

            if pointInRect(mx, my, screenX, screenY, info.w, info.h) then
                local currentTags = resolveKey(info.entity, info.key)
                if currentTags and type(currentTags) == "table" and info.index <= #currentTags then
                    local newTags = deepCopy(currentTags)
                    table.remove(newTags, info.index)
                    self:_setField(info.entity, info.key, newTags, "Remove tag from " .. info.key)
                end
                return
            end
        end
    end
end

function ClassRaceEditor:_handleBonusClick(mx, my)
    -- Add bonus button
    if self._addBonusRect then
        local r = self._addBonusRect
        local screenX = self._propArea.x + r.x
        local screenY = self._propArea.y - self.propScroll.scrollY + r.y

        if pointInRect(mx, my, screenX, screenY, r.w, r.h) then
            local entity = r.entity
            local name = self._bonusNameInput:getText()
            local desc = self._bonusDescInput:getText()
            if name ~= "" then
                local bonuses = entity.bonuses or {}
                local newBonuses = deepCopy(bonuses)
                table.insert(newBonuses, { name = name, desc = desc })
                self:_setField(entity, "bonuses", newBonuses, "Add bonus")
                self._bonusNameInput:setText("")
                self._bonusDescInput:setText("")
            end
            return
        end
    end

    -- Delete bonus buttons
    if self._bonusRects then
        for i, rects in ipairs(self._bonusRects) do
            if rects.delRect then
                local dr = rects.delRect
                local screenX = self._propArea.x + dr.x
                local screenY = self._propArea.y - self.propScroll.scrollY + dr.y

                if pointInRect(mx, my, screenX, screenY, dr.w, dr.h) then
                    local entity = self:_getSelectedEntity()
                    if entity and entity.bonuses then
                        local newBonuses = deepCopy(entity.bonuses)
                        table.remove(newBonuses, i)
                        self:_setField(entity, "bonuses", newBonuses, "Remove bonus")
                    end
                    return
                end
            end
        end
    end
end

-- =========================================================================
-- Input: mousereleased
-- =========================================================================

function ClassRaceEditor:mousereleased(mx, my, button)
    if button ~= 1 then return false end

    if self.deleteModal.visible then
        self.deleteModal:mousereleased(mx, my, button)
        return true
    end

    self.addBtn:mousereleased(mx, my, button)
    self.dupBtn:mousereleased(mx, my, button)
    self.delBtn:mousereleased(mx, my, button)

    local scroll = self:_getActiveListScroll()
    scroll:mousereleased(mx, my, button)
    self.propScroll:mousereleased(mx, my, button)

    self._activeColorSlider = nil

    return false
end

-- =========================================================================
-- Input: wheelmoved
-- =========================================================================

function ClassRaceEditor:wheelmoved(wx, wy)
    local mx, my = love.mouse.getPosition()

    -- Property area scroll
    if self._propArea and pointInRect(mx, my, self._propArea.x, self._propArea.y, self._propArea.w, self._propArea.h) then
        self.propScroll:wheelmoved(wx, wy)
        return true
    end

    -- List scroll
    local scroll = self:_getActiveListScroll()
    if scroll:wheelmoved(wx, wy) then
        return true
    end

    return false
end

-- =========================================================================
-- Input: keypressed
-- =========================================================================

function ClassRaceEditor:keypressed(key)
    if self.deleteModal.visible then
        self.deleteModal:keypressed(key)
        return true
    end

    -- Undo/Redo
    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
    local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")

    if ctrl and key == "z" then
        if shift then
            self.undoStack:redo()
        else
            self.undoStack:undo()
        end
        self._inputWidgets = {}
        self._textAreaWidgets = {}
        return true
    end

    if ctrl and key == "y" then
        self.undoStack:redo()
        self._inputWidgets = {}
        self._textAreaWidgets = {}
        return true
    end

    -- Delete key
    if key == "delete" then
        local focused = UI.getFocus()
        if not focused then
            local entity = self:_getSelectedEntity()
            if entity then
                self.deleteModal.onOk = function()
                    self:_deleteEntity()
                end
                self.deleteModal:show()
            end
            return true
        end
    end

    -- Forward to search input
    if self.searchInput:keypressed(key) then return true end

    -- Forward to tag input
    if self._tagInputWidget:keypressed(key) then return true end

    -- Forward to bonus inputs
    if self._bonusNameInput:keypressed(key) then return true end
    if self._bonusDescInput:keypressed(key) then return true end

    -- Forward to text input widgets
    for _, w in pairs(self._inputWidgets) do
        if w.keypressed and w:keypressed(key) then return true end
    end

    return false
end

-- =========================================================================
-- Input: textinput
-- =========================================================================

function ClassRaceEditor:textinput(t)
    if self.deleteModal.visible then return true end

    if self.searchInput:textinput(t) then return true end
    if self._tagInputWidget:textinput(t) then return true end
    if self._bonusNameInput:textinput(t) then return true end
    if self._bonusDescInput:textinput(t) then return true end

    for _, w in pairs(self._inputWidgets) do
        if w.textinput and w:textinput(t) then return true end
    end

    return false
end

-- =========================================================================
-- Button callback wiring (done once per frame, lightweight)
-- =========================================================================

function ClassRaceEditor:_wireButtons()
    local selfRef = self
    self.addBtn.onClick = function() selfRef:_addEntity() end
    self.dupBtn.onClick = function() selfRef:_duplicateEntity() end
    self.delBtn.onClick = function()
        local entity = selfRef:_getSelectedEntity()
        if entity then
            selfRef.deleteModal.onOk = function()
                selfRef:_deleteEntity()
            end
            selfRef.deleteModal.message = "Delete '" .. (entity.name or entity.id or "this entry") .. "'?"
            selfRef.deleteModal:show()
        end
    end

    -- Disable dup/del if nothing selected
    local hasSelection = self:_getSelectedEntity() ~= nil
    self.dupBtn.disabled = not hasSelection
    self.delBtn.disabled = not hasSelection
end

-- Support mousemoved for dragging color sliders and scroll
function ClassRaceEditor:mousemoved(mx, my)
    -- Scrollbar drag
    local scroll = self:_getActiveListScroll()
    if scroll:mousemoved(mx, my) then return true end
    if self.propScroll:mousemoved(mx, my) then return true end

    -- Color slider drag
    if self._activeColorSlider then
        local slider = self[self._activeColorSlider]
        if slider and slider.x and slider.w then
            local screenX = self._propArea.x + slider.x
            local t = clamp((mx - screenX) / slider.w, 0, 1)
            local entity = slider.entity
            local key = slider.key
            local channel = slider.channel
            local color = resolveKey(entity, key)
            if color and type(color) == "table" and #color >= 3 then
                local newColor = { color[1], color[2], color[3] }
                newColor[channel] = math.floor(t * 100) / 100
                self:_setFieldCoalesced(entity, key, newColor, "color_" .. key .. "_" .. channel)
            end
            return true
        end
    end

    -- Forward to text inputs for selection dragging
    if self.searchInput:mousemoved(mx, my) then return true end
    for _, w in pairs(self._inputWidgets) do
        if w.mousemoved and w:mousemoved(mx, my) then return true end
    end

    return false
end

return ClassRaceEditor
