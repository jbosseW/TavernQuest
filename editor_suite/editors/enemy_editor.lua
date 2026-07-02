---------------------------------------------------------------------------
-- enemy_editor.lua - Enemy Editor Tab for the Tavern Quest Editor Suite
-- Full CRUD, CR range filtering, stat preview, resistance editing, undo/redo
---------------------------------------------------------------------------

local Theme      = require("core.theme")
local FontCache  = require("core.fontcache")
local UndoStack  = require("core.undo")
local Search     = require("core.search")
local IdGen      = require("core.id_generator")

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

local LEFT_PANEL_W   = 260
local RIGHT_PANEL_W  = 220
local LIST_ITEM_H    = 30
local BUTTON_H       = 28
local INPUT_H        = 26
local LABEL_W        = 130
local ROW_H          = 28
local SECTION_PAD    = 10
local SCROLLBAR_W    = 10
local TAG_H          = 24
local TAG_PAD        = 4
local SLIDER_H       = 18
local CR_MIN         = 0.25
local CR_MAX         = 20
local CR_STEP        = 0.25
local MULT_MIN       = 0.1
local MULT_MAX       = 10.0
local MULT_STEP      = 0.1
local RANGE_MIN      = 1
local RANGE_MAX      = 6
local RES_MIN        = -1.0
local RES_MAX        = 1.0
local RES_STEP       = 0.05

local DAMAGE_TYPES   = {"physical", "fire", "ice", "lightning", "holy", "poison", "dark", "arcane"}
local ATTACK_TYPES   = {"melee", "magic"}
local PREVIEW_LEVELS = {1, 5, 10, 15, 20}

local DAMAGE_TYPE_COLORS = {
    physical  = {0.75, 0.75, 0.75},
    fire      = {1.0,  0.4,  0.2},
    ice       = {0.3,  0.7,  1.0},
    lightning = {1.0,  1.0,  0.3},
    holy      = {1.0,  0.95, 0.6},
    poison    = {0.4,  0.85, 0.3},
    dark      = {0.6,  0.3,  0.8},
    arcane    = {0.5,  0.4,  1.0},
}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function round(v, step)
    return math.floor(v / step + 0.5) * step
end

local function deepCopy(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[deepCopy(k)] = deepCopy(v)
    end
    return copy
end

local function pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px < rx + rw and py >= ry and py < ry + rh
end

--- Draw a rounded rectangle (uses rectangles with arcs when radius > 0).
local function drawRoundedRect(mode, x, y, w, h, r)
    r = r or 0
    if r <= 0 then
        love.graphics.rectangle(mode, x, y, w, h)
    else
        love.graphics.rectangle(mode, x, y, w, h, r, r)
    end
end

--- Format a number for display, stripping trailing zeros.
local function fmtNum(n)
    if n == math.floor(n) then
        return tostring(math.floor(n))
    end
    local s = string.format("%.2f", n)
    s = s:gsub("0+$", ""):gsub("%.$", "")
    return s
end

--- Create a default enemy entry.
local function createDefaultEnemy(id)
    return {
        id          = id or "new_enemy",
        name        = "New Enemy",
        cr          = 1.0,
        portrait    = "E",
        hpMult      = 1.0,
        atkMult     = 1.0,
        defMult     = 1.0,
        xpMult      = 1.0,
        goldMult    = 1.0,
        attacks     = {},
        resistances = {},
        attackType  = "melee",
        attackRange = 1,
        damageType  = "physical",
        description = "",
        boss        = false,
        calidarOnly = false,
    }
end

--- Compute base stats at a given player level.
local function baseStatsAtLevel(level)
    return {
        hp  = 50 + level * 10,
        atk = 5  + level * 3,
        def = 3  + level * 2,
    }
end

---------------------------------------------------------------------------
-- Simple inline widget drawing helpers
-- These are self-contained drawing utilities so the editor does not
-- strictly require a separate UI/Widgets module at this stage.
---------------------------------------------------------------------------

local function drawSearchBar(state, x, y, w, h)
    local focused = (state._focusedField == "search")
    local borderColor = focused and Theme.colors.inputFocus or Theme.colors.inputBorder
    love.graphics.setColor(Theme.colors.input)
    drawRoundedRect("fill", x, y, w, h, Theme.radius.sm)
    love.graphics.setColor(borderColor)
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", x, y, w, h, Theme.radius.sm)

    local font = FontCache.get(13)
    love.graphics.setFont(font)
    local textY = y + math.floor((h - font:getHeight()) / 2)

    love.graphics.setScissor(x + 4, y, w - 8, h)
    if state.searchText == "" and not focused then
        love.graphics.setColor(Theme.colors.textDim)
        love.graphics.print("Search enemies...", x + 6, textY)
    else
        love.graphics.setColor(Theme.colors.text)
        love.graphics.print(state.searchText, x + 6, textY)
        if focused then
            -- cursor blink
            local cx = x + 6 + font:getWidth(state.searchText)
            if math.floor(love.timer.getTime() * 2) % 2 == 0 then
                love.graphics.setColor(Theme.colors.text)
                love.graphics.rectangle("fill", cx, textY, 1, font:getHeight())
            end
        end
    end
    love.graphics.setScissor()
end

local function drawButton(label, x, y, w, h, mx, my, colorKey, enabled)
    if enabled == nil then enabled = true end
    local hovered = enabled and pointInRect(mx, my, x, y, w, h)
    local baseColor = Theme.colors[colorKey] or Theme.colors.secondary
    local hoverColor = Theme.colors[colorKey .. "Hover"] or baseColor

    if not enabled then
        love.graphics.setColor(Theme.colors.bgLight)
    elseif hovered then
        love.graphics.setColor(hoverColor)
    else
        love.graphics.setColor(baseColor)
    end
    drawRoundedRect("fill", x, y, w, h, Theme.radius.sm)

    local font = FontCache.get(12)
    love.graphics.setFont(font)
    local tw = font:getWidth(label)
    local tx = x + math.floor((w - tw) / 2)
    local ty = y + math.floor((h - font:getHeight()) / 2)
    if not enabled then
        love.graphics.setColor(Theme.colors.textDim)
    else
        love.graphics.setColor(Theme.colors.text)
    end
    love.graphics.print(label, tx, ty)

    return hovered
end

local function drawSlider(x, y, w, h, value, minVal, maxVal, step)
    local trackY = y + math.floor((h - 4) / 2)
    love.graphics.setColor(Theme.colors.bgDark)
    drawRoundedRect("fill", x, trackY, w, 4, 2)

    local range = maxVal - minVal
    if range <= 0 then range = 1 end
    local t = (value - minVal) / range
    t = clamp(t, 0, 1)

    -- filled portion
    local fillW = math.floor(w * t)
    love.graphics.setColor(Theme.colors.primary)
    drawRoundedRect("fill", x, trackY, fillW, 4, 2)

    -- thumb
    local thumbX = x + fillW
    local thumbR = 7
    love.graphics.setColor(Theme.colors.primary)
    love.graphics.circle("fill", thumbX, y + math.floor(h / 2), thumbR)
    love.graphics.setColor(Theme.colors.text)
    love.graphics.circle("line", thumbX, y + math.floor(h / 2), thumbR)

    return t
end

local function drawToggle(x, y, w, h, value, label, mx, my)
    local boxSize = 16
    local boxX = x
    local boxY = y + math.floor((h - boxSize) / 2)
    local hovered = pointInRect(mx, my, x, y, w, h)

    love.graphics.setColor(value and Theme.colors.primary or Theme.colors.input)
    drawRoundedRect("fill", boxX, boxY, boxSize, boxSize, 3)
    love.graphics.setColor(value and Theme.colors.primaryHover or Theme.colors.inputBorder)
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", boxX, boxY, boxSize, boxSize, 3)

    if value then
        love.graphics.setColor(Theme.colors.text)
        love.graphics.setLineWidth(2)
        love.graphics.line(boxX + 3, boxY + 8, boxX + 6, boxY + 12, boxX + 13, boxY + 4)
        love.graphics.setLineWidth(1)
    end

    local font = FontCache.get(13)
    love.graphics.setFont(font)
    love.graphics.setColor(hovered and Theme.colors.text or Theme.colors.textDim)
    love.graphics.print(label, boxX + boxSize + 6, y + math.floor((h - font:getHeight()) / 2))

    return hovered
end

local function drawDropdown(x, y, w, h, value, options, label)
    love.graphics.setColor(Theme.colors.input)
    drawRoundedRect("fill", x, y, w, h, Theme.radius.sm)
    love.graphics.setColor(Theme.colors.inputBorder)
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", x, y, w, h, Theme.radius.sm)

    local font = FontCache.get(12)
    love.graphics.setFont(font)
    love.graphics.setColor(Theme.colors.text)
    local displayText = tostring(value or "none")
    local textY = y + math.floor((h - font:getHeight()) / 2)
    love.graphics.setScissor(x + 4, y, w - 20, h)
    love.graphics.print(displayText, x + 6, textY)
    love.graphics.setScissor()

    -- dropdown arrow
    local arrowX = x + w - 14
    local arrowY = y + math.floor(h / 2)
    love.graphics.setColor(Theme.colors.textDim)
    love.graphics.polygon("fill",
        arrowX, arrowY - 2,
        arrowX + 8, arrowY - 2,
        arrowX + 4, arrowY + 4)
end

local function drawTextInput(state, fieldKey, x, y, w, h, placeholder)
    local focused = (state._focusedField == fieldKey)
    local borderColor = focused and Theme.colors.inputFocus or Theme.colors.inputBorder
    love.graphics.setColor(Theme.colors.input)
    drawRoundedRect("fill", x, y, w, h, Theme.radius.sm)
    love.graphics.setColor(borderColor)
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", x, y, w, h, Theme.radius.sm)

    local font = FontCache.get(13)
    love.graphics.setFont(font)
    local textY = y + math.floor((h - font:getHeight()) / 2)
    local textVal = state._editBuffers[fieldKey] or ""

    love.graphics.setScissor(x + 4, y, w - 8, h)
    if textVal == "" and not focused then
        love.graphics.setColor(Theme.colors.textDim)
        love.graphics.print(placeholder or "", x + 6, textY)
    else
        love.graphics.setColor(Theme.colors.text)
        love.graphics.print(textVal, x + 6, textY)
        if focused then
            local cx = x + 6 + font:getWidth(textVal)
            if math.floor(love.timer.getTime() * 2) % 2 == 0 then
                love.graphics.setColor(Theme.colors.text)
                love.graphics.rectangle("fill", cx, textY, 1, font:getHeight())
            end
        end
    end
    love.graphics.setScissor()
end

---------------------------------------------------------------------------
-- EnemyEditor module
---------------------------------------------------------------------------

local EnemyEditor = {}
EnemyEditor.__index = EnemyEditor

function EnemyEditor.new(project)
    local self = setmetatable({}, EnemyEditor)

    self.project = project
    self.enemies = project.enemies or {}
    project.enemies = self.enemies

    self.undoStack = UndoStack.new(100)

    -- Selection
    self.selectedIndex = nil
    self.selectedEnemy = nil

    -- Search / filter state
    self.searchText     = ""
    self.crFilterMin    = CR_MIN
    self.crFilterMax    = CR_MAX
    self.attackTypeFilter = nil  -- nil = all
    self.damageTypeFilter = nil  -- nil = all
    self.sortMode       = "name"
    self.sortAscending  = true

    -- Filtered/sorted view
    self.filteredList = {}

    -- Scroll state
    self.listScrollY       = 0
    self.centerScrollY     = 0
    self.rightScrollY      = 0
    self.maxCenterScrollY  = 0
    self.maxRightScrollY   = 0

    -- Interactive state
    self._focusedField     = nil
    self._editBuffers      = {}
    self._activeSlider     = nil  -- {field, minVal, maxVal, step, x, w}
    self._activeDropdown   = nil  -- {field, options, x, y, w, h}
    self._dropdownScroll   = 0
    self._newAttackText    = ""
    self._newResType       = "physical"
    self._newResValue      = 0.0
    self._hoveredListIndex = nil
    self._draggingCrMin    = false
    self._draggingCrMax    = false

    -- Layout cache (set in draw)
    self._layoutX = 0
    self._layoutY = 0
    self._layoutW = 0
    self._layoutH = 0
    self._mouseX  = 0
    self._mouseY  = 0

    -- Dirty flag for filtered list rebuild
    self._filterDirty = true

    self:_rebuildFilteredList()
    return self
end

---------------------------------------------------------------------------
-- Data operations (with undo)
---------------------------------------------------------------------------

function EnemyEditor:_markDirty()
    self._filterDirty = true
end

function EnemyEditor:_rebuildFilteredList()
    local items = self.enemies

    -- Text filter
    if self.searchText ~= "" then
        items = Search.filterByText(items, self.searchText, {"name", "id", "description"})
    end

    -- CR range filter
    if self.crFilterMin > CR_MIN or self.crFilterMax < CR_MAX then
        items = Search.filterByRange(items, "cr", self.crFilterMin, self.crFilterMax)
    end

    -- Attack type filter
    if self.attackTypeFilter then
        items = Search.filterByCategory(items, "attackType", self.attackTypeFilter)
    end

    -- Damage type filter
    if self.damageTypeFilter then
        items = Search.filterByCategory(items, "damageType", self.damageTypeFilter)
    end

    -- Sort
    items = Search.sortBy(items, self.sortMode, self.sortAscending)

    self.filteredList = items
    self._filterDirty = false

    -- Maintain selection if possible
    if self.selectedEnemy then
        local found = false
        for i, e in ipairs(self.filteredList) do
            if e == self.selectedEnemy then
                self.selectedIndex = i
                found = true
                break
            end
        end
        if not found then
            self.selectedIndex = nil
            self.selectedEnemy = nil
            self._editBuffers = {}
        end
    end
end

function EnemyEditor:_selectEnemy(index)
    if index and index >= 1 and index <= #self.filteredList then
        self.selectedIndex = index
        self.selectedEnemy = self.filteredList[index]
        self:_syncBuffersFromEnemy()
        self.centerScrollY = 0
        self.rightScrollY = 0
    else
        self.selectedIndex = nil
        self.selectedEnemy = nil
        self._editBuffers = {}
    end
    self._focusedField = nil
    self._activeDropdown = nil
end

function EnemyEditor:_syncBuffersFromEnemy()
    local e = self.selectedEnemy
    if not e then
        self._editBuffers = {}
        return
    end
    self._editBuffers = {
        id          = e.id or "",
        name        = e.name or "",
        cr          = tostring(e.cr or 1),
        portrait    = e.portrait or "",
        hpMult      = tostring(e.hpMult or 1),
        atkMult     = tostring(e.atkMult or 1),
        defMult     = tostring(e.defMult or 1),
        xpMult      = tostring(e.xpMult or 1),
        goldMult    = tostring(e.goldMult or 1),
        attackRange = tostring(e.attackRange or 1),
        description = e.description or "",
    }
    self._newAttackText = ""
end

function EnemyEditor:_findEnemySourceIndex(enemy)
    for i, e in ipairs(self.enemies) do
        if e == enemy then return i end
    end
    return nil
end

function EnemyEditor:_setField(fieldName, newValue, description)
    local enemy = self.selectedEnemy
    if not enemy then return end

    local oldValue = enemy[fieldName]
    if oldValue == newValue then return end

    local desc = description or ("Set " .. fieldName)

    self.undoStack:push({
        description = desc,
        execute = function()
            enemy[fieldName] = newValue
        end,
        undo = function()
            enemy[fieldName] = oldValue
        end,
    })

    self:_syncBuffersFromEnemy()
    self:_markDirty()
end

function EnemyEditor:_addEnemy()
    local existingIds = {}
    for _, e in ipairs(self.enemies) do
        existingIds[e.id] = true
    end
    local newId = IdGen.ensureUnique("new_enemy", existingIds)
    local newEnemy = createDefaultEnemy(newId)

    self.undoStack:push({
        description = "Add enemy",
        execute = function()
            self.enemies[#self.enemies + 1] = newEnemy
        end,
        undo = function()
            for i, e in ipairs(self.enemies) do
                if e == newEnemy then
                    table.remove(self.enemies, i)
                    break
                end
            end
        end,
    })

    self:_markDirty()
    self:_rebuildFilteredList()

    -- Select the new enemy
    for i, e in ipairs(self.filteredList) do
        if e == newEnemy then
            self:_selectEnemy(i)
            break
        end
    end
end

function EnemyEditor:_duplicateEnemy()
    local src = self.selectedEnemy
    if not src then return end

    local existingIds = {}
    for _, e in ipairs(self.enemies) do
        existingIds[e.id] = true
    end

    local dup = deepCopy(src)
    dup.id = IdGen.ensureUnique(src.id .. "_copy", existingIds)
    dup.name = src.name .. " (Copy)"

    self.undoStack:push({
        description = "Duplicate enemy: " .. src.name,
        execute = function()
            self.enemies[#self.enemies + 1] = dup
        end,
        undo = function()
            for i, e in ipairs(self.enemies) do
                if e == dup then
                    table.remove(self.enemies, i)
                    break
                end
            end
        end,
    })

    self:_markDirty()
    self:_rebuildFilteredList()

    for i, e in ipairs(self.filteredList) do
        if e == dup then
            self:_selectEnemy(i)
            break
        end
    end
end

function EnemyEditor:_deleteEnemy()
    local target = self.selectedEnemy
    if not target then return end

    local sourceIdx = self:_findEnemySourceIndex(target)
    if not sourceIdx then return end

    local removedEnemy = target
    local removedIndex = sourceIdx

    self.undoStack:push({
        description = "Delete enemy: " .. (target.name or target.id),
        execute = function()
            for i, e in ipairs(self.enemies) do
                if e == removedEnemy then
                    table.remove(self.enemies, i)
                    break
                end
            end
        end,
        undo = function()
            table.insert(self.enemies, math.min(removedIndex, #self.enemies + 1), removedEnemy)
        end,
    })

    self:_markDirty()
    self:_rebuildFilteredList()

    -- Try to select the next enemy in list
    if #self.filteredList > 0 then
        local newIdx = math.min(self.selectedIndex or 1, #self.filteredList)
        self:_selectEnemy(newIdx)
    else
        self:_selectEnemy(nil)
    end
end

function EnemyEditor:_addAttack(attackName)
    local enemy = self.selectedEnemy
    if not enemy then return end
    if not attackName or attackName == "" then return end

    if not enemy.attacks then enemy.attacks = {} end

    -- Check for duplicate
    for _, a in ipairs(enemy.attacks) do
        if a == attackName then return end
    end

    self.undoStack:push({
        description = "Add attack: " .. attackName,
        execute = function()
            if not enemy.attacks then enemy.attacks = {} end
            enemy.attacks[#enemy.attacks + 1] = attackName
        end,
        undo = function()
            if enemy.attacks then
                for i, a in ipairs(enemy.attacks) do
                    if a == attackName then
                        table.remove(enemy.attacks, i)
                        break
                    end
                end
            end
        end,
    })
end

function EnemyEditor:_removeAttack(index)
    local enemy = self.selectedEnemy
    if not enemy or not enemy.attacks then return end
    if index < 1 or index > #enemy.attacks then return end

    local removed = enemy.attacks[index]
    local removedAt = index

    self.undoStack:push({
        description = "Remove attack: " .. removed,
        execute = function()
            for i, a in ipairs(enemy.attacks) do
                if a == removed and i == removedAt then
                    table.remove(enemy.attacks, i)
                    break
                end
            end
            -- fallback: just remove by value
            if not enemy.attacks then return end
            for i, a in ipairs(enemy.attacks) do
                if a == removed then
                    table.remove(enemy.attacks, i)
                    return
                end
            end
        end,
        undo = function()
            if not enemy.attacks then enemy.attacks = {} end
            table.insert(enemy.attacks, math.min(removedAt, #enemy.attacks + 1), removed)
        end,
    })
end

function EnemyEditor:_addResistance(dmgType, value)
    local enemy = self.selectedEnemy
    if not enemy then return end
    if not dmgType or dmgType == "" then return end

    if type(enemy.resistances) ~= "table" then
        enemy.resistances = {}
    end

    -- Check duplicate key
    for _, r in ipairs(enemy.resistances) do
        if type(r) == "table" and r.type == dmgType then return end
    end

    local newRes = {type = dmgType, value = value or 0}

    self.undoStack:push({
        description = "Add resistance: " .. dmgType,
        execute = function()
            if type(enemy.resistances) ~= "table" then
                enemy.resistances = {}
            end
            enemy.resistances[#enemy.resistances + 1] = newRes
        end,
        undo = function()
            if type(enemy.resistances) == "table" then
                for i, r in ipairs(enemy.resistances) do
                    if r == newRes then
                        table.remove(enemy.resistances, i)
                        break
                    end
                end
            end
        end,
    })
end

function EnemyEditor:_removeResistance(index)
    local enemy = self.selectedEnemy
    if not enemy or type(enemy.resistances) ~= "table" then return end
    if index < 1 or index > #enemy.resistances then return end

    local removed = enemy.resistances[index]
    local removedAt = index

    self.undoStack:push({
        description = "Remove resistance: " .. tostring(removed and removed.type or "?"),
        execute = function()
            if type(enemy.resistances) == "table" then
                for i, r in ipairs(enemy.resistances) do
                    if r == removed then
                        table.remove(enemy.resistances, i)
                        break
                    end
                end
            end
        end,
        undo = function()
            if type(enemy.resistances) ~= "table" then
                enemy.resistances = {}
            end
            table.insert(enemy.resistances, math.min(removedAt, #enemy.resistances + 1), removed)
        end,
    })
end

function EnemyEditor:_setResistanceValue(index, newValue)
    local enemy = self.selectedEnemy
    if not enemy or type(enemy.resistances) ~= "table" then return end
    local res = enemy.resistances[index]
    if not res then return end

    local oldValue = res.value
    if oldValue == newValue then return end

    self.undoStack:push({
        description = "Set resistance value: " .. tostring(res.type),
        execute = function()
            res.value = newValue
        end,
        undo = function()
            res.value = oldValue
        end,
    })
end

---------------------------------------------------------------------------
-- Draw
---------------------------------------------------------------------------

function EnemyEditor:draw(x, y, w, h)
    self._layoutX = x
    self._layoutY = y
    self._layoutW = w
    self._layoutH = h
    self._mouseX, self._mouseY = love.mouse.getPosition()
    local mx, my = self._mouseX, self._mouseY

    -- Background
    love.graphics.setColor(Theme.colors.bg)
    love.graphics.rectangle("fill", x, y, w, h)

    -- Panel dimensions
    local leftX = x
    local leftW = LEFT_PANEL_W
    local rightX = x + w - RIGHT_PANEL_W
    local rightW = RIGHT_PANEL_W
    local centerX = leftX + leftW + 1
    local centerW = w - leftW - rightW - 2
    if centerW < 100 then centerW = 100 end

    -- Draw panels
    self:_drawLeftPanel(leftX, y, leftW, h, mx, my)
    self:_drawCenterPanel(centerX, y, centerW, h, mx, my)
    self:_drawRightPanel(rightX, y, rightW, h, mx, my)

    -- Panel separators
    love.graphics.setColor(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", leftX + leftW, y, 1, h)
    love.graphics.rectangle("fill", rightX - 1, y, 1, h)

    -- Draw active dropdown overlay last (on top)
    if self._activeDropdown then
        self:_drawDropdownOverlay(mx, my)
    end
end

---------------------------------------------------------------------------
-- Left Panel
---------------------------------------------------------------------------

function EnemyEditor:_drawLeftPanel(x, y, w, h, mx, my)
    love.graphics.setScissor(x, y, w, h)

    love.graphics.setColor(Theme.colors.panel)
    love.graphics.rectangle("fill", x, y, w, h)

    local pad = Theme.spacing.lg
    local cy = y + pad

    -- Header
    local headerFont = FontCache.get(15)
    love.graphics.setFont(headerFont)
    love.graphics.setColor(Theme.colors.textAccent)
    love.graphics.print("Enemies", x + pad, cy)
    cy = cy + headerFont:getHeight() + pad

    -- Search bar
    local searchH = INPUT_H
    drawSearchBar(self, x + pad, cy, w - pad * 2, searchH)
    self._searchBarRect = {x + pad, cy, w - pad * 2, searchH}
    cy = cy + searchH + pad

    -- CR Range Filter
    local labelFont = FontCache.get(11)
    love.graphics.setFont(labelFont)
    love.graphics.setColor(Theme.colors.textDim)
    love.graphics.print("CR Range: " .. fmtNum(self.crFilterMin) .. " - " .. fmtNum(self.crFilterMax), x + pad, cy)
    cy = cy + labelFont:getHeight() + 2

    -- Min CR slider
    local sliderW = w - pad * 2
    self._crMinSliderRect = {x + pad, cy, sliderW, SLIDER_H}
    drawSlider(x + pad, cy, sliderW, SLIDER_H, self.crFilterMin, CR_MIN, CR_MAX, CR_STEP)
    cy = cy + SLIDER_H + 2

    -- Max CR slider
    self._crMaxSliderRect = {x + pad, cy, sliderW, SLIDER_H}
    drawSlider(x + pad, cy, sliderW, SLIDER_H, self.crFilterMax, CR_MIN, CR_MAX, CR_STEP)
    cy = cy + SLIDER_H + pad

    -- Attack type filter
    love.graphics.setFont(labelFont)
    love.graphics.setColor(Theme.colors.textDim)
    love.graphics.print("Attack Type", x + pad, cy)
    cy = cy + labelFont:getHeight() + 2
    local atkFilterVal = self.attackTypeFilter or "All"
    self._atkTypeDropdownRect = {x + pad, cy, sliderW, INPUT_H}
    drawDropdown(x + pad, cy, sliderW, INPUT_H, atkFilterVal, ATTACK_TYPES)
    cy = cy + INPUT_H + pad - 4

    -- Damage type filter
    love.graphics.setColor(Theme.colors.textDim)
    love.graphics.print("Damage Type", x + pad, cy)
    cy = cy + labelFont:getHeight() + 2
    local dmgFilterVal = self.damageTypeFilter or "All"
    self._dmgTypeDropdownRect = {x + pad, cy, sliderW, INPUT_H}
    drawDropdown(x + pad, cy, sliderW, INPUT_H, dmgFilterVal, DAMAGE_TYPES)
    cy = cy + INPUT_H + pad - 4

    -- Sort buttons
    love.graphics.setColor(Theme.colors.textDim)
    love.graphics.print("Sort by:", x + pad, cy)
    local sortLabelW = labelFont:getWidth("Sort by:") + 6
    local sortBtnW = 50
    local nameActive = (self.sortMode == "name")
    local crActive = (self.sortMode == "cr")

    -- Name sort button
    local nbx = x + pad + sortLabelW
    love.graphics.setColor(nameActive and Theme.colors.primary or Theme.colors.bgLight)
    drawRoundedRect("fill", nbx, cy - 2, sortBtnW, labelFont:getHeight() + 4, 3)
    love.graphics.setColor(Theme.colors.text)
    love.graphics.setFont(labelFont)
    love.graphics.print("Name", nbx + 8, cy)
    self._sortNameRect = {nbx, cy - 2, sortBtnW, labelFont:getHeight() + 4}

    -- CR sort button
    local cbx = nbx + sortBtnW + 4
    love.graphics.setColor(crActive and Theme.colors.primary or Theme.colors.bgLight)
    drawRoundedRect("fill", cbx, cy - 2, sortBtnW - 10, labelFont:getHeight() + 4, 3)
    love.graphics.setColor(Theme.colors.text)
    love.graphics.print("CR", cbx + 8, cy)
    self._sortCrRect = {cbx, cy - 2, sortBtnW - 10, labelFont:getHeight() + 4}

    -- Asc/Desc toggle
    local dirX = cbx + sortBtnW - 10 + 4
    local dirLabel = self.sortAscending and "Asc" or "Desc"
    love.graphics.setColor(Theme.colors.bgLight)
    drawRoundedRect("fill", dirX, cy - 2, 36, labelFont:getHeight() + 4, 3)
    love.graphics.setColor(Theme.colors.textDim)
    love.graphics.print(dirLabel, dirX + 4, cy)
    self._sortDirRect = {dirX, cy - 2, 36, labelFont:getHeight() + 4}

    cy = cy + labelFont:getHeight() + pad

    -- Enemy list
    local listTop = cy
    local listH = h - (cy - y) - BUTTON_H - pad * 3 - 16
    if listH < 50 then listH = 50 end

    love.graphics.setColor(Theme.colors.bgDark)
    love.graphics.rectangle("fill", x + 4, listTop, w - 8, listH)

    self._listRect = {x + 4, listTop, w - 8, listH}

    -- Clipped list rendering
    love.graphics.setScissor(x + 4, listTop, w - 8, listH)
    local listFont = FontCache.get(12)
    local crFont = FontCache.get(10)
    love.graphics.setFont(listFont)

    local maxScroll = math.max(0, #self.filteredList * LIST_ITEM_H - listH)
    self.listScrollY = clamp(self.listScrollY, 0, maxScroll)

    self._hoveredListIndex = nil

    for i, enemy in ipairs(self.filteredList) do
        local iy = listTop + (i - 1) * LIST_ITEM_H - self.listScrollY
        if iy + LIST_ITEM_H > listTop and iy < listTop + listH then
            local isSelected = (enemy == self.selectedEnemy)
            local isHovered = pointInRect(mx, my, x + 4, iy, w - 8, LIST_ITEM_H)
            if isHovered then self._hoveredListIndex = i end

            if isSelected then
                love.graphics.setColor(Theme.colors.listItemSelected)
            elseif isHovered then
                love.graphics.setColor(Theme.colors.listItemHover)
            elseif i % 2 == 0 then
                love.graphics.setColor(Theme.colors.listItemAlt)
            else
                love.graphics.setColor(Theme.colors.listItem)
            end
            love.graphics.rectangle("fill", x + 4, iy, w - 8, LIST_ITEM_H)

            -- Boss indicator
            if enemy.boss then
                love.graphics.setColor(Theme.colors.danger)
                love.graphics.rectangle("fill", x + 4, iy, 3, LIST_ITEM_H)
            end

            -- Enemy name
            love.graphics.setFont(listFont)
            love.graphics.setColor(isSelected and Theme.colors.textAccent or Theme.colors.text)
            local nameText = enemy.name or enemy.id or "?"
            local nameMaxW = w - 60
            love.graphics.setScissor(x + 10, iy, nameMaxW, LIST_ITEM_H)
            love.graphics.print(nameText, x + 10, iy + math.floor((LIST_ITEM_H - listFont:getHeight()) / 2))
            love.graphics.setScissor(x + 4, listTop, w - 8, listH)

            -- CR badge
            local crText = fmtNum(enemy.cr or 0)
            love.graphics.setFont(crFont)
            local crW = math.max(crFont:getWidth(crText) + 8, 28)
            local crX = x + w - 12 - crW
            local crY = iy + math.floor((LIST_ITEM_H - 16) / 2)
            local crColor = self:_getCrColor(enemy.cr or 0)
            love.graphics.setColor(crColor[1], crColor[2], crColor[3], 0.3)
            drawRoundedRect("fill", crX, crY, crW, 16, 8)
            love.graphics.setColor(crColor)
            love.graphics.print(crText, crX + math.floor((crW - crFont:getWidth(crText)) / 2), crY + 2)
        end
    end

    love.graphics.setScissor(x, y, w, h)

    -- Scrollbar for list
    if maxScroll > 0 then
        local sbX = x + w - 8 - SCROLLBAR_W + 4
        local sbH = listH
        local thumbH = math.max(20, (listH / (listH + maxScroll)) * sbH)
        local thumbY = listTop + (self.listScrollY / maxScroll) * (sbH - thumbH)
        love.graphics.setColor(Theme.colors.scrollbar)
        love.graphics.rectangle("fill", sbX, listTop, SCROLLBAR_W, sbH)
        love.graphics.setColor(Theme.colors.scrollbarThumb)
        drawRoundedRect("fill", sbX, thumbY, SCROLLBAR_W, thumbH, 3)
    end

    cy = listTop + listH + pad

    -- Action buttons
    local btnW = math.floor((w - pad * 2 - 8) / 3)
    drawButton("Add", x + pad, cy, btnW, BUTTON_H, mx, my, "success")
    self._addBtnRect = {x + pad, cy, btnW, BUTTON_H}

    drawButton("Dupe", x + pad + btnW + 4, cy, btnW, BUTTON_H, mx, my, "secondary", self.selectedEnemy ~= nil)
    self._dupeBtnRect = {x + pad + btnW + 4, cy, btnW, BUTTON_H}

    drawButton("Del", x + pad + (btnW + 4) * 2, cy, btnW, BUTTON_H, mx, my, "danger", self.selectedEnemy ~= nil)
    self._delBtnRect = {x + pad + (btnW + 4) * 2, cy, btnW, BUTTON_H}

    cy = cy + BUTTON_H + 4

    -- Enemy count
    love.graphics.setFont(FontCache.get(10))
    love.graphics.setColor(Theme.colors.textDim)
    local countText = #self.filteredList .. " / " .. #self.enemies .. " enemies"
    love.graphics.print(countText, x + pad, cy)

    love.graphics.setScissor()
end

function EnemyEditor:_getCrColor(cr)
    if cr <= 1 then
        return Theme.colors.success
    elseif cr <= 5 then
        return Theme.colors.info
    elseif cr <= 10 then
        return Theme.colors.warning
    else
        return Theme.colors.danger
    end
end

---------------------------------------------------------------------------
-- Center Panel (Property Grid)
---------------------------------------------------------------------------

function EnemyEditor:_drawCenterPanel(x, y, w, h, mx, my)
    love.graphics.setScissor(x, y, w, h)

    love.graphics.setColor(Theme.colors.bg)
    love.graphics.rectangle("fill", x, y, w, h)

    if not self.selectedEnemy then
        -- Empty state
        local font = FontCache.get(16)
        love.graphics.setFont(font)
        love.graphics.setColor(Theme.colors.textDim)
        local msg = "Select an enemy to edit"
        local tw = font:getWidth(msg)
        love.graphics.print(msg, x + math.floor((w - tw) / 2), y + math.floor(h / 2) - 10)
        love.graphics.setScissor()
        return
    end

    local enemy = self.selectedEnemy
    local pad = Theme.spacing.lg
    local fieldW = w - pad * 2 - LABEL_W
    if fieldW < 100 then fieldW = 100 end

    -- Track content height for scrolling
    local contentStartY = y - self.centerScrollY
    local cy = contentStartY + pad

    self._centerPanelRect = {x, y, w, h}
    self._centerFieldRects = {}

    -- === SECTION: Basic ===
    cy = self:_drawSectionHeader("Basic Info", x + pad, cy, w - pad * 2)

    -- ID (read-only display, editable via text input)
    cy = self:_drawPropertyRow("id", "ID", x + pad, cy, fieldW, mx, my, "text")
    cy = self:_drawPropertyRow("name", "Name", x + pad, cy, fieldW, mx, my, "text")

    -- CR slider
    cy = self:_drawPropertyLabel("CR", x + pad, cy)
    local crSliderX = x + pad + LABEL_W
    self._centerFieldRects["cr_slider"] = {crSliderX, cy, fieldW, SLIDER_H}
    drawSlider(crSliderX, cy, fieldW, SLIDER_H, enemy.cr or 1, CR_MIN, CR_MAX, CR_STEP)
    -- CR value text
    local crFont = FontCache.get(11)
    love.graphics.setFont(crFont)
    love.graphics.setColor(Theme.colors.textAccent)
    love.graphics.print(fmtNum(enemy.cr or 1), crSliderX + fieldW + 6, cy + 1)
    cy = cy + ROW_H

    -- Description
    cy = self:_drawPropertyRow("description", "Description", x + pad, cy, fieldW, mx, my, "text")

    cy = cy + SECTION_PAD

    -- === SECTION: Portrait ===
    cy = self:_drawSectionHeader("Portrait", x + pad, cy, w - pad * 2)
    cy = self:_drawPropertyRow("portrait", "Portrait Char", x + pad, cy, fieldW, mx, my, "text")

    -- Small portrait preview inline
    local previewSize = 48
    local previewX = x + pad + LABEL_W
    love.graphics.setColor(Theme.colors.bgDark)
    drawRoundedRect("fill", previewX, cy, previewSize, previewSize, Theme.radius.sm)
    love.graphics.setColor(Theme.colors.panelBorder)
    drawRoundedRect("line", previewX, cy, previewSize, previewSize, Theme.radius.sm)

    local portraitChar = enemy.portrait or "?"
    local portraitFont = FontCache.get(28)
    love.graphics.setFont(portraitFont)
    love.graphics.setColor(Theme.colors.textAccent)
    local pcW = portraitFont:getWidth(portraitChar)
    love.graphics.print(portraitChar,
        previewX + math.floor((previewSize - pcW) / 2),
        cy + math.floor((previewSize - portraitFont:getHeight()) / 2))
    cy = cy + previewSize + SECTION_PAD

    -- === SECTION: Multipliers ===
    cy = self:_drawSectionHeader("Stat Multipliers", x + pad, cy, w - pad * 2)

    local multFields = {"hpMult", "atkMult", "defMult", "xpMult", "goldMult"}
    local multLabels = {"HP Mult", "ATK Mult", "DEF Mult", "XP Mult", "Gold Mult"}
    local multColors = {
        {0.4, 0.9, 0.4},
        {0.9, 0.4, 0.3},
        {0.4, 0.6, 0.9},
        {0.9, 0.8, 0.3},
        {0.9, 0.7, 0.2},
    }

    for mi = 1, #multFields do
        cy = self:_drawPropertyLabel(multLabels[mi], x + pad, cy)
        local sliderX = x + pad + LABEL_W
        self._centerFieldRects[multFields[mi] .. "_slider"] = {sliderX, cy, fieldW, SLIDER_H}
        drawSlider(sliderX, cy, fieldW, SLIDER_H, enemy[multFields[mi]] or 1, MULT_MIN, MULT_MAX, MULT_STEP)

        local valFont = FontCache.get(11)
        love.graphics.setFont(valFont)
        love.graphics.setColor(multColors[mi])
        love.graphics.print(fmtNum(enemy[multFields[mi]] or 1), sliderX + fieldW + 6, cy + 1)
        cy = cy + ROW_H
    end

    cy = cy + SECTION_PAD

    -- === SECTION: Combat ===
    cy = self:_drawSectionHeader("Combat", x + pad, cy, w - pad * 2)

    -- Attack Type dropdown
    cy = self:_drawPropertyLabel("Attack Type", x + pad, cy)
    local atkDropX = x + pad + LABEL_W
    self._centerFieldRects["attackType_dropdown"] = {atkDropX, cy, fieldW, INPUT_H}
    drawDropdown(atkDropX, cy, fieldW, INPUT_H, enemy.attackType or "melee", ATTACK_TYPES)
    cy = cy + ROW_H + 2

    -- Attack Range slider
    cy = self:_drawPropertyLabel("Attack Range", x + pad, cy)
    local rangeSliderX = x + pad + LABEL_W
    self._centerFieldRects["attackRange_slider"] = {rangeSliderX, cy, fieldW, SLIDER_H}
    drawSlider(rangeSliderX, cy, fieldW, SLIDER_H, enemy.attackRange or 1, RANGE_MIN, RANGE_MAX, 1)
    local rangeFont = FontCache.get(11)
    love.graphics.setFont(rangeFont)
    love.graphics.setColor(Theme.colors.text)
    love.graphics.print(tostring(math.floor(enemy.attackRange or 1)), rangeSliderX + fieldW + 6, cy + 1)
    cy = cy + ROW_H

    -- Damage Type dropdown
    cy = self:_drawPropertyLabel("Damage Type", x + pad, cy)
    local dmgDropX = x + pad + LABEL_W
    self._centerFieldRects["damageType_dropdown"] = {dmgDropX, cy, fieldW, INPUT_H}
    drawDropdown(dmgDropX, cy, fieldW, INPUT_H, enemy.damageType or "physical", DAMAGE_TYPES)
    local dtColor = DAMAGE_TYPE_COLORS[enemy.damageType or "physical"] or Theme.colors.text
    love.graphics.setColor(dtColor)
    love.graphics.circle("fill", dmgDropX + fieldW + 12, cy + math.floor(INPUT_H / 2), 5)
    cy = cy + ROW_H + SECTION_PAD

    -- === SECTION: Attacks (Tag editor) ===
    cy = self:_drawSectionHeader("Attacks", x + pad, cy, w - pad * 2)

    local attacks = enemy.attacks or {}
    local tagX = x + pad
    local tagStartX = tagX
    local tagMaxW = w - pad * 2
    self._attackTagRects = {}

    for ai, atk in ipairs(attacks) do
        local tagFont = FontCache.get(11)
        local tagTextW = tagFont:getWidth(atk) + 20 -- +20 for padding and close button
        if tagX + tagTextW > x + pad + tagMaxW then
            tagX = tagStartX
            cy = cy + TAG_H + TAG_PAD
        end

        -- Tag background
        love.graphics.setColor(Theme.colors.secondary)
        drawRoundedRect("fill", tagX, cy, tagTextW, TAG_H, 12)

        -- Tag text
        love.graphics.setFont(tagFont)
        love.graphics.setColor(Theme.colors.text)
        love.graphics.print(atk, tagX + 6, cy + math.floor((TAG_H - tagFont:getHeight()) / 2))

        -- Close X
        local closeX = tagX + tagTextW - 14
        local closeY = cy + math.floor((TAG_H - 10) / 2)
        local closeHovered = pointInRect(mx, my, closeX - 2, closeY - 2, 14, 14)
        love.graphics.setColor(closeHovered and Theme.colors.danger or Theme.colors.textDim)
        love.graphics.setFont(FontCache.get(10))
        love.graphics.print("x", closeX, closeY)

        self._attackTagRects[ai] = {tagX, cy, tagTextW, TAG_H, closeX = closeX - 2, closeY = closeY - 2}
        tagX = tagX + tagTextW + TAG_PAD
    end

    if #attacks > 0 then
        cy = cy + TAG_H + TAG_PAD
    end

    -- Add attack input
    local addAtkInputW = tagMaxW - 52
    if addAtkInputW < 60 then addAtkInputW = 60 end
    self._centerFieldRects["newAttack"] = {x + pad, cy, addAtkInputW, INPUT_H}
    -- Draw the new attack text field
    local focused = (self._focusedField == "newAttack")
    local borderColor = focused and Theme.colors.inputFocus or Theme.colors.inputBorder
    love.graphics.setColor(Theme.colors.input)
    drawRoundedRect("fill", x + pad, cy, addAtkInputW, INPUT_H, Theme.radius.sm)
    love.graphics.setColor(borderColor)
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", x + pad, cy, addAtkInputW, INPUT_H, Theme.radius.sm)

    local atkInputFont = FontCache.get(12)
    love.graphics.setFont(atkInputFont)
    local atkInputY = cy + math.floor((INPUT_H - atkInputFont:getHeight()) / 2)
    love.graphics.setScissor(x + pad + 4, cy, addAtkInputW - 8, INPUT_H)
    if self._newAttackText == "" and not focused then
        love.graphics.setColor(Theme.colors.textDim)
        love.graphics.print("New attack name...", x + pad + 6, atkInputY)
    else
        love.graphics.setColor(Theme.colors.text)
        love.graphics.print(self._newAttackText, x + pad + 6, atkInputY)
        if focused and math.floor(love.timer.getTime() * 2) % 2 == 0 then
            local cx2 = x + pad + 6 + atkInputFont:getWidth(self._newAttackText)
            love.graphics.setColor(Theme.colors.text)
            love.graphics.rectangle("fill", cx2, atkInputY, 1, atkInputFont:getHeight())
        end
    end
    love.graphics.setScissor(x, y, w, h)

    -- Add attack button
    local addAtkBtnX = x + pad + addAtkInputW + 4
    self._addAtkBtnRect = {addAtkBtnX, cy, 48, INPUT_H}
    drawButton("+Add", addAtkBtnX, cy, 48, INPUT_H, mx, my, "success", self._newAttackText ~= "")

    cy = cy + INPUT_H + SECTION_PAD

    -- === SECTION: Resistances ===
    cy = self:_drawSectionHeader("Resistances", x + pad, cy, w - pad * 2)

    local resistances = enemy.resistances
    if type(resistances) ~= "table" then resistances = {} end
    self._resRowRects = {}

    for ri, res in ipairs(resistances) do
        if type(res) == "table" and res.type then
            local resRowY = cy
            local resTypeW = 90
            local resValW = fieldW - resTypeW - 34
            if resValW < 60 then resValW = 60 end

            -- Damage type label
            local dtc = DAMAGE_TYPE_COLORS[res.type] or Theme.colors.text
            love.graphics.setColor(dtc)
            love.graphics.circle("fill", x + pad + 6, cy + math.floor(ROW_H / 2), 4)
            local resFont = FontCache.get(12)
            love.graphics.setFont(resFont)
            love.graphics.setColor(Theme.colors.text)
            love.graphics.print(res.type, x + pad + 14, cy + math.floor((ROW_H - resFont:getHeight()) / 2))

            -- Resistance value slider
            local resSliderX = x + pad + resTypeW
            local resSliderW = resValW
            self._centerFieldRects["res_slider_" .. ri] = {resSliderX, cy + 4, resSliderW, SLIDER_H}
            drawSlider(resSliderX, cy + 4, resSliderW, SLIDER_H, res.value or 0, RES_MIN, RES_MAX, RES_STEP)

            -- Value text
            local valText = fmtNum(res.value or 0)
            local vFont = FontCache.get(10)
            love.graphics.setFont(vFont)
            local pctVal = (res.value or 0) * 100
            if pctVal > 0 then
                love.graphics.setColor(Theme.colors.success)
                valText = "+" .. fmtNum(res.value or 0)
            elseif pctVal < 0 then
                love.graphics.setColor(Theme.colors.danger)
            else
                love.graphics.setColor(Theme.colors.textDim)
            end
            love.graphics.print(valText, resSliderX + resSliderW + 4, cy + 6)

            -- Remove button
            local remX = x + pad + resTypeW + resValW + 28
            local remHovered = pointInRect(mx, my, remX, cy + 2, 20, ROW_H - 4)
            love.graphics.setColor(remHovered and Theme.colors.danger or Theme.colors.textDim)
            love.graphics.setFont(FontCache.get(14))
            love.graphics.print("x", remX + 4, cy + 3)
            self._resRowRects[ri] = {removeRect = {remX, cy + 2, 20, ROW_H - 4}}

            cy = cy + ROW_H + 2
        end
    end

    -- Add resistance row
    local addResTypeW = 100
    local addResValW = 60
    local addResBtnW = 48

    -- New resistance type dropdown
    self._centerFieldRects["newResType_dropdown"] = {x + pad, cy, addResTypeW, INPUT_H}
    drawDropdown(x + pad, cy, addResTypeW, INPUT_H, self._newResType, DAMAGE_TYPES)

    -- New resistance value display
    love.graphics.setFont(FontCache.get(11))
    love.graphics.setColor(Theme.colors.textDim)
    love.graphics.print(fmtNum(self._newResValue), x + pad + addResTypeW + 6, cy + math.floor((INPUT_H - FontCache.get(11):getHeight()) / 2))

    -- Add resistance button
    local addResBtnX = x + pad + addResTypeW + addResValW + 8
    self._addResBtnRect = {addResBtnX, cy, addResBtnW, INPUT_H}
    drawButton("+Add", addResBtnX, cy, addResBtnW, INPUT_H, mx, my, "success")

    cy = cy + INPUT_H + SECTION_PAD

    -- === SECTION: Flags ===
    cy = self:_drawSectionHeader("Flags", x + pad, cy, w - pad * 2)

    self._centerFieldRects["boss_toggle"] = {x + pad, cy, w - pad * 2, ROW_H}
    drawToggle(x + pad, cy, w - pad * 2, ROW_H, enemy.boss, "Boss Enemy", mx, my)
    cy = cy + ROW_H

    self._centerFieldRects["calidarOnly_toggle"] = {x + pad, cy, w - pad * 2, ROW_H}
    drawToggle(x + pad, cy, w - pad * 2, ROW_H, enemy.calidarOnly, "Calidar Only", mx, my)
    cy = cy + ROW_H + pad

    -- Track total content height
    self.maxCenterScrollY = math.max(0, (cy - contentStartY) - h)
    self.centerScrollY = clamp(self.centerScrollY, 0, self.maxCenterScrollY)

    -- Center panel scrollbar
    if self.maxCenterScrollY > 0 then
        local sbX = x + w - SCROLLBAR_W - 2
        local sbH = h
        local totalContent = cy - contentStartY
        local thumbH = math.max(20, (h / totalContent) * sbH)
        local thumbY = y + (self.centerScrollY / self.maxCenterScrollY) * (sbH - thumbH)
        love.graphics.setColor(Theme.colors.scrollbar)
        love.graphics.rectangle("fill", sbX, y, SCROLLBAR_W, sbH)
        love.graphics.setColor(Theme.colors.scrollbarThumb)
        drawRoundedRect("fill", sbX, thumbY, SCROLLBAR_W, thumbH, 3)
    end

    love.graphics.setScissor()
end

function EnemyEditor:_drawSectionHeader(title, x, cy, w)
    local font = FontCache.get(13)
    love.graphics.setFont(font)
    love.graphics.setColor(Theme.colors.primary)
    love.graphics.print(title, x, cy)
    cy = cy + font:getHeight() + 2
    love.graphics.setColor(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", x, cy, w, 1)
    cy = cy + Theme.spacing.md
    return cy
end

function EnemyEditor:_drawPropertyLabel(label, x, cy)
    local font = FontCache.get(12)
    love.graphics.setFont(font)
    love.graphics.setColor(Theme.colors.textDim)
    love.graphics.print(label, x, cy + math.floor((ROW_H - font:getHeight()) / 2))
    return cy
end

function EnemyEditor:_drawPropertyRow(fieldKey, label, x, cy, fieldW, mx, my, fieldType)
    self:_drawPropertyLabel(label, x, cy)
    local inputX = x + LABEL_W
    self._centerFieldRects[fieldKey] = {inputX, cy, fieldW, INPUT_H}
    drawTextInput(self, fieldKey, inputX, cy, fieldW, INPUT_H, "")
    return cy + ROW_H
end

---------------------------------------------------------------------------
-- Right Panel (Preview)
---------------------------------------------------------------------------

function EnemyEditor:_drawRightPanel(x, y, w, h, mx, my)
    love.graphics.setScissor(x, y, w, h)

    love.graphics.setColor(Theme.colors.panel)
    love.graphics.rectangle("fill", x, y, w, h)

    if not self.selectedEnemy then
        love.graphics.setScissor()
        return
    end

    local enemy = self.selectedEnemy
    local pad = Theme.spacing.lg
    local contentStartY = y - self.rightScrollY
    local cy = contentStartY + pad

    self._rightPanelRect = {x, y, w, h}

    -- Portrait preview (large)
    local previewSize = w - pad * 2
    if previewSize > 140 then previewSize = 140 end
    local previewX = x + math.floor((w - previewSize) / 2)

    love.graphics.setColor(Theme.colors.bgDark)
    drawRoundedRect("fill", previewX, cy, previewSize, previewSize, Theme.radius.lg)
    love.graphics.setColor(Theme.colors.panelBorder)
    love.graphics.setLineWidth(2)
    drawRoundedRect("line", previewX, cy, previewSize, previewSize, Theme.radius.lg)
    love.graphics.setLineWidth(1)

    -- Boss glow effect
    if enemy.boss then
        love.graphics.setColor(Theme.colors.danger[1], Theme.colors.danger[2], Theme.colors.danger[3], 0.15 + 0.1 * math.sin(love.timer.getTime() * 3))
        drawRoundedRect("fill", previewX - 2, cy - 2, previewSize + 4, previewSize + 4, Theme.radius.lg)
    end

    -- Portrait character
    local pChar = enemy.portrait or "?"
    local pFont = FontCache.get(math.floor(previewSize * 0.5))
    love.graphics.setFont(pFont)
    love.graphics.setColor(Theme.colors.textAccent)
    local pcW2 = pFont:getWidth(pChar)
    love.graphics.print(pChar,
        previewX + math.floor((previewSize - pcW2) / 2),
        cy + math.floor((previewSize - pFont:getHeight()) / 2))

    cy = cy + previewSize + pad

    -- Name and CR
    local nameFont = FontCache.get(14)
    love.graphics.setFont(nameFont)
    love.graphics.setColor(Theme.colors.text)
    local enemyName = enemy.name or "Unnamed"
    local nameW = nameFont:getWidth(enemyName)
    love.graphics.print(enemyName, x + math.floor((w - nameW) / 2), cy)
    cy = cy + nameFont:getHeight() + 2

    -- CR badge
    local crText = "CR " .. fmtNum(enemy.cr or 0)
    local crFont = FontCache.get(11)
    love.graphics.setFont(crFont)
    local crColor = self:_getCrColor(enemy.cr or 0)
    local crBadgeW = crFont:getWidth(crText) + 12
    local crBadgeX = x + math.floor((w - crBadgeW) / 2)
    love.graphics.setColor(crColor[1], crColor[2], crColor[3], 0.25)
    drawRoundedRect("fill", crBadgeX, cy, crBadgeW, 18, 9)
    love.graphics.setColor(crColor)
    love.graphics.print(crText, crBadgeX + 6, cy + 2)
    cy = cy + 24

    -- Boss badge
    if enemy.boss then
        local bossFont = FontCache.get(10)
        love.graphics.setFont(bossFont)
        local bossW = bossFont:getWidth("BOSS") + 12
        local bossX = x + math.floor((w - bossW) / 2)
        love.graphics.setColor(Theme.colors.danger[1], Theme.colors.danger[2], Theme.colors.danger[3], 0.3)
        drawRoundedRect("fill", bossX, cy, bossW, 16, 8)
        love.graphics.setColor(Theme.colors.danger)
        love.graphics.print("BOSS", bossX + 6, cy + 2)
        cy = cy + 22
    end

    -- Damage type indicator
    local dtFont = FontCache.get(10)
    love.graphics.setFont(dtFont)
    local dtName = enemy.damageType or "physical"
    local dtc2 = DAMAGE_TYPE_COLORS[dtName] or Theme.colors.text
    local dtTextW = dtFont:getWidth(dtName) + 16
    local dtX = x + math.floor((w - dtTextW) / 2)
    love.graphics.setColor(dtc2[1], dtc2[2], dtc2[3], 0.2)
    drawRoundedRect("fill", dtX, cy, dtTextW, 16, 8)
    love.graphics.setColor(dtc2)
    love.graphics.circle("fill", dtX + 7, cy + 8, 3)
    love.graphics.print(dtName, dtX + 14, cy + 2)
    cy = cy + 22 + SECTION_PAD

    -- === Stat Preview ===
    local headerFont = FontCache.get(12)
    love.graphics.setFont(headerFont)
    love.graphics.setColor(Theme.colors.primary)
    love.graphics.print("Stat Preview", x + pad, cy)
    cy = cy + headerFont:getHeight() + 4
    love.graphics.setColor(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", x + pad, cy, w - pad * 2, 1)
    cy = cy + 6

    -- Header row
    local statFont = FontCache.get(10)
    love.graphics.setFont(statFont)
    local colW = math.floor((w - pad * 2) / 4)
    local lvlColW = 30

    love.graphics.setColor(Theme.colors.textDim)
    love.graphics.print("Lvl", x + pad, cy)
    love.graphics.setColor(0.4, 0.9, 0.4)
    love.graphics.print("HP", x + pad + lvlColW, cy)
    love.graphics.setColor(0.9, 0.4, 0.3)
    love.graphics.print("ATK", x + pad + lvlColW + colW, cy)
    love.graphics.setColor(0.4, 0.6, 0.9)
    love.graphics.print("DEF", x + pad + lvlColW + colW * 2, cy)
    cy = cy + statFont:getHeight() + 3

    local barMaxW = colW - 6
    if barMaxW < 20 then barMaxW = 20 end

    -- Find max values for bar scaling
    local maxHP, maxATK, maxDEF = 0, 0, 0
    for _, lvl in ipairs(PREVIEW_LEVELS) do
        local base = baseStatsAtLevel(lvl)
        local ehp  = base.hp * (enemy.hpMult or 1)
        local eatk = base.atk * (enemy.atkMult or 1)
        local edef = base.def * (enemy.defMult or 1)
        if ehp > maxHP then maxHP = ehp end
        if eatk > maxATK then maxATK = eatk end
        if edef > maxDEF then maxDEF = edef end
    end
    if maxHP <= 0 then maxHP = 1 end
    if maxATK <= 0 then maxATK = 1 end
    if maxDEF <= 0 then maxDEF = 1 end

    for _, lvl in ipairs(PREVIEW_LEVELS) do
        local base = baseStatsAtLevel(lvl)
        local ehp  = math.floor(base.hp * (enemy.hpMult or 1))
        local eatk = math.floor(base.atk * (enemy.atkMult or 1))
        local edef = math.floor(base.def * (enemy.defMult or 1))

        love.graphics.setFont(statFont)
        love.graphics.setColor(Theme.colors.textDim)
        love.graphics.print(tostring(lvl), x + pad, cy + 1)

        -- HP bar
        local hpBarW = math.floor((ehp / maxHP) * barMaxW)
        love.graphics.setColor(0.4, 0.9, 0.4, 0.2)
        love.graphics.rectangle("fill", x + pad + lvlColW, cy, barMaxW, 12)
        love.graphics.setColor(0.4, 0.9, 0.4, 0.7)
        love.graphics.rectangle("fill", x + pad + lvlColW, cy, hpBarW, 12)
        love.graphics.setColor(Theme.colors.text)
        love.graphics.print(tostring(ehp), x + pad + lvlColW + 2, cy + 1)

        -- ATK bar
        local atkBarW = math.floor((eatk / maxATK) * barMaxW)
        love.graphics.setColor(0.9, 0.4, 0.3, 0.2)
        love.graphics.rectangle("fill", x + pad + lvlColW + colW, cy, barMaxW, 12)
        love.graphics.setColor(0.9, 0.4, 0.3, 0.7)
        love.graphics.rectangle("fill", x + pad + lvlColW + colW, cy, atkBarW, 12)
        love.graphics.setColor(Theme.colors.text)
        love.graphics.print(tostring(eatk), x + pad + lvlColW + colW + 2, cy + 1)

        -- DEF bar
        local defBarW = math.floor((edef / maxDEF) * barMaxW)
        love.graphics.setColor(0.4, 0.6, 0.9, 0.2)
        love.graphics.rectangle("fill", x + pad + lvlColW + colW * 2, cy, barMaxW, 12)
        love.graphics.setColor(0.4, 0.6, 0.9, 0.7)
        love.graphics.rectangle("fill", x + pad + lvlColW + colW * 2, cy, defBarW, 12)
        love.graphics.setColor(Theme.colors.text)
        love.graphics.print(tostring(edef), x + pad + lvlColW + colW * 2 + 2, cy + 1)

        cy = cy + 16
    end

    cy = cy + SECTION_PAD

    -- Resistance summary
    if type(enemy.resistances) == "table" and #enemy.resistances > 0 then
        love.graphics.setFont(FontCache.get(11))
        love.graphics.setColor(Theme.colors.primary)
        love.graphics.print("Resistances", x + pad, cy)
        cy = cy + 16

        for _, res in ipairs(enemy.resistances) do
            if type(res) == "table" and res.type then
                local rc = DAMAGE_TYPE_COLORS[res.type] or Theme.colors.text
                love.graphics.setColor(rc)
                love.graphics.circle("fill", x + pad + 5, cy + 5, 4)
                love.graphics.setFont(FontCache.get(10))
                love.graphics.setColor(Theme.colors.text)
                local resText = res.type .. ": "
                if (res.value or 0) > 0 then
                    resText = resText .. "+" .. fmtNum(res.value)
                else
                    resText = resText .. fmtNum(res.value or 0)
                end
                love.graphics.print(resText, x + pad + 14, cy)
                cy = cy + 14
            end
        end
        cy = cy + SECTION_PAD
    end

    -- Attack list summary
    if type(enemy.attacks) == "table" and #enemy.attacks > 0 then
        love.graphics.setFont(FontCache.get(11))
        love.graphics.setColor(Theme.colors.primary)
        love.graphics.print("Attacks", x + pad, cy)
        cy = cy + 16

        love.graphics.setFont(FontCache.get(10))
        for _, atk in ipairs(enemy.attacks) do
            love.graphics.setColor(Theme.colors.textDim)
            love.graphics.print("- " .. atk, x + pad + 4, cy)
            cy = cy + 13
        end
    end

    cy = cy + pad

    -- Track total content height for scrolling
    self.maxRightScrollY = math.max(0, (cy - contentStartY) - h)
    self.rightScrollY = clamp(self.rightScrollY, 0, self.maxRightScrollY)

    -- Right panel scrollbar
    if self.maxRightScrollY > 0 then
        local sbX = x + w - SCROLLBAR_W - 2
        local sbH = h
        local totalContent = cy - contentStartY
        local thumbH = math.max(20, (h / totalContent) * sbH)
        local thumbY = y + (self.rightScrollY / self.maxRightScrollY) * (sbH - thumbH)
        love.graphics.setColor(Theme.colors.scrollbar)
        love.graphics.rectangle("fill", sbX, y, SCROLLBAR_W, sbH)
        love.graphics.setColor(Theme.colors.scrollbarThumb)
        drawRoundedRect("fill", sbX, thumbY, SCROLLBAR_W, thumbH, 3)
    end

    love.graphics.setScissor()
end

---------------------------------------------------------------------------
-- Dropdown overlay (drawn on top of everything)
---------------------------------------------------------------------------

function EnemyEditor:_drawDropdownOverlay(mx, my)
    local dd = self._activeDropdown
    if not dd then return end

    local options = dd.options
    local ddX = dd.x
    local ddY = dd.y + dd.h
    local ddW = dd.w
    local itemH = 24
    local maxVisible = math.min(#options, 8)
    local ddH = maxVisible * itemH

    -- Adjust if going off screen
    local screenH = love.graphics.getHeight()
    if ddY + ddH > screenH then
        ddY = dd.y - ddH
    end

    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", ddX + 2, ddY + 2, ddW, ddH)

    -- Background
    love.graphics.setColor(Theme.colors.panel)
    love.graphics.rectangle("fill", ddX, ddY, ddW, ddH)
    love.graphics.setColor(Theme.colors.inputFocus)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", ddX, ddY, ddW, ddH)

    love.graphics.setScissor(ddX, ddY, ddW, ddH)

    local font = FontCache.get(12)
    love.graphics.setFont(font)

    local scrollOff = self._dropdownScroll * itemH
    for i, opt in ipairs(options) do
        local iy = ddY + (i - 1) * itemH - scrollOff
        if iy + itemH > ddY and iy < ddY + ddH then
            local hovered = pointInRect(mx, my, ddX, iy, ddW, itemH)
            local isCurrentValue = false

            if dd.field == "_atkTypeFilter" then
                if (opt == "All" and self.attackTypeFilter == nil) or opt == self.attackTypeFilter then
                    isCurrentValue = true
                end
            elseif dd.field == "_dmgTypeFilter" then
                if (opt == "All" and self.damageTypeFilter == nil) or opt == self.damageTypeFilter then
                    isCurrentValue = true
                end
            elseif self.selectedEnemy then
                if self.selectedEnemy[dd.field] == opt then
                    isCurrentValue = true
                end
            end

            if isCurrentValue then
                love.graphics.setColor(Theme.colors.listItemSelected)
            elseif hovered then
                love.graphics.setColor(Theme.colors.listItemHover)
            else
                love.graphics.setColor(Theme.colors.panel)
            end
            love.graphics.rectangle("fill", ddX, iy, ddW, itemH)

            -- Damage type color indicator
            if DAMAGE_TYPE_COLORS[opt] then
                local dtc3 = DAMAGE_TYPE_COLORS[opt]
                love.graphics.setColor(dtc3)
                love.graphics.circle("fill", ddX + 12, iy + math.floor(itemH / 2), 4)
            end

            love.graphics.setColor(isCurrentValue and Theme.colors.textAccent or Theme.colors.text)
            love.graphics.print(tostring(opt), ddX + (DAMAGE_TYPE_COLORS[opt] and 22 or 8), iy + math.floor((itemH - font:getHeight()) / 2))
        end
    end

    love.graphics.setScissor()
end

---------------------------------------------------------------------------
-- Mouse input
---------------------------------------------------------------------------

function EnemyEditor:mousepressed(mx, my, button)
    if button ~= 1 then return false end

    -- Dropdown overlay takes priority
    if self._activeDropdown then
        local dd = self._activeDropdown
        local options = dd.options
        local ddX = dd.x
        local ddY = dd.y + dd.h
        local ddW = dd.w
        local itemH = 24
        local maxVisible = math.min(#options, 8)
        local ddH = maxVisible * itemH

        local screenH = love.graphics.getHeight()
        if ddY + ddH > screenH then
            ddY = dd.y - ddH
        end

        if pointInRect(mx, my, ddX, ddY, ddW, ddH) then
            local scrollOff = self._dropdownScroll * itemH
            local clickedIdx = math.floor((my - ddY + scrollOff) / itemH) + 1
            if clickedIdx >= 1 and clickedIdx <= #options then
                local chosen = options[clickedIdx]
                if dd.field == "_atkTypeFilter" then
                    self.attackTypeFilter = (chosen == "All") and nil or chosen
                    self:_markDirty()
                elseif dd.field == "_dmgTypeFilter" then
                    self.damageTypeFilter = (chosen == "All") and nil or chosen
                    self:_markDirty()
                elseif dd.field == "_newResType" then
                    self._newResType = chosen
                elseif self.selectedEnemy then
                    self:_setField(dd.field, chosen, "Set " .. dd.field .. " to " .. chosen)
                end
            end
        end
        self._activeDropdown = nil
        self._dropdownScroll = 0
        return true
    end

    -- Check if click is inside our layout area
    if not pointInRect(mx, my, self._layoutX, self._layoutY, self._layoutW, self._layoutH) then
        return false
    end

    -- Left panel clicks
    local leftX = self._layoutX
    local leftW = LEFT_PANEL_W
    local rightX = self._layoutX + self._layoutW - RIGHT_PANEL_W
    local centerX = leftX + leftW + 1

    -- Search bar
    if self._searchBarRect and pointInRect(mx, my, unpack(self._searchBarRect)) then
        self._focusedField = "search"
        return true
    end

    -- CR min slider
    if self._crMinSliderRect and pointInRect(mx, my, unpack(self._crMinSliderRect)) then
        local rect = self._crMinSliderRect
        self._activeSlider = {field = "_crFilterMin", minVal = CR_MIN, maxVal = CR_MAX, step = CR_STEP, x = rect[1], w = rect[3], startValue = self.crFilterMin}
        self._focusedField = nil
        return true
    end

    -- CR max slider
    if self._crMaxSliderRect and pointInRect(mx, my, unpack(self._crMaxSliderRect)) then
        local rect = self._crMaxSliderRect
        self._activeSlider = {field = "_crFilterMax", minVal = CR_MIN, maxVal = CR_MAX, step = CR_STEP, x = rect[1], w = rect[3], startValue = self.crFilterMax}
        self._focusedField = nil
        return true
    end

    -- Attack type filter dropdown
    if self._atkTypeDropdownRect and pointInRect(mx, my, unpack(self._atkTypeDropdownRect)) then
        local rect = self._atkTypeDropdownRect
        local opts = {"All"}
        for _, at in ipairs(ATTACK_TYPES) do opts[#opts + 1] = at end
        self._activeDropdown = {field = "_atkTypeFilter", options = opts, x = rect[1], y = rect[2], w = rect[3], h = rect[4]}
        self._dropdownScroll = 0
        self._focusedField = nil
        return true
    end

    -- Damage type filter dropdown
    if self._dmgTypeDropdownRect and pointInRect(mx, my, unpack(self._dmgTypeDropdownRect)) then
        local rect = self._dmgTypeDropdownRect
        local opts = {"All"}
        for _, dt in ipairs(DAMAGE_TYPES) do opts[#opts + 1] = dt end
        self._activeDropdown = {field = "_dmgTypeFilter", options = opts, x = rect[1], y = rect[2], w = rect[3], h = rect[4]}
        self._dropdownScroll = 0
        self._focusedField = nil
        return true
    end

    -- Sort buttons
    if self._sortNameRect and pointInRect(mx, my, unpack(self._sortNameRect)) then
        self.sortMode = "name"
        self:_markDirty()
        return true
    end
    if self._sortCrRect and pointInRect(mx, my, unpack(self._sortCrRect)) then
        self.sortMode = "cr"
        self:_markDirty()
        return true
    end
    if self._sortDirRect and pointInRect(mx, my, unpack(self._sortDirRect)) then
        self.sortAscending = not self.sortAscending
        self:_markDirty()
        return true
    end

    -- List clicks
    if self._listRect and pointInRect(mx, my, unpack(self._listRect)) then
        if self._hoveredListIndex then
            self:_selectEnemy(self._hoveredListIndex)
        end
        self._focusedField = nil
        return true
    end

    -- Action buttons
    if self._addBtnRect and pointInRect(mx, my, unpack(self._addBtnRect)) then
        self:_addEnemy()
        return true
    end
    if self._dupeBtnRect and pointInRect(mx, my, unpack(self._dupeBtnRect)) and self.selectedEnemy then
        self:_duplicateEnemy()
        return true
    end
    if self._delBtnRect and pointInRect(mx, my, unpack(self._delBtnRect)) and self.selectedEnemy then
        self:_deleteEnemy()
        return true
    end

    -- Center panel clicks
    if self._centerPanelRect and pointInRect(mx, my, unpack(self._centerPanelRect)) then
        return self:_handleCenterPanelClick(mx, my)
    end

    -- If clicking anywhere else, clear focus
    self._focusedField = nil
    return false
end

function EnemyEditor:_handleCenterPanelClick(mx, my)
    local rects = self._centerFieldRects or {}

    -- Text input fields
    local textFields = {"id", "name", "description", "portrait"}
    for _, fieldKey in ipairs(textFields) do
        local rect = rects[fieldKey]
        if rect and pointInRect(mx, my, unpack(rect)) then
            self._focusedField = fieldKey
            return true
        end
    end

    -- New attack text field
    if rects["newAttack"] and pointInRect(mx, my, unpack(rects["newAttack"])) then
        self._focusedField = "newAttack"
        return true
    end

    -- Add attack button
    if self._addAtkBtnRect and pointInRect(mx, my, unpack(self._addAtkBtnRect)) then
        if self._newAttackText ~= "" then
            self:_addAttack(self._newAttackText)
            self._newAttackText = ""
        end
        return true
    end

    -- Attack tag close buttons
    if self._attackTagRects then
        for ai, tagRect in ipairs(self._attackTagRects) do
            if tagRect.closeX and pointInRect(mx, my, tagRect.closeX, tagRect.closeY, 14, 14) then
                self:_removeAttack(ai)
                return true
            end
        end
    end

    -- CR slider
    if rects["cr_slider"] and pointInRect(mx, my, unpack(rects["cr_slider"])) then
        local r = rects["cr_slider"]
        self._activeSlider = {field = "cr", minVal = CR_MIN, maxVal = CR_MAX, step = CR_STEP, x = r[1], w = r[3], startValue = self.selectedEnemy.cr}
        self._focusedField = nil
        return true
    end

    -- Multiplier sliders
    local multFields2 = {"hpMult", "atkMult", "defMult", "xpMult", "goldMult"}
    for _, mf in ipairs(multFields2) do
        local key = mf .. "_slider"
        if rects[key] and pointInRect(mx, my, unpack(rects[key])) then
            local r = rects[key]
            self._activeSlider = {field = mf, minVal = MULT_MIN, maxVal = MULT_MAX, step = MULT_STEP, x = r[1], w = r[3], startValue = self.selectedEnemy[mf]}
            self._focusedField = nil
            return true
        end
    end

    -- Attack range slider
    if rects["attackRange_slider"] and pointInRect(mx, my, unpack(rects["attackRange_slider"])) then
        local r = rects["attackRange_slider"]
        self._activeSlider = {field = "attackRange", minVal = RANGE_MIN, maxVal = RANGE_MAX, step = 1, x = r[1], w = r[3], startValue = self.selectedEnemy.attackRange}
        self._focusedField = nil
        return true
    end

    -- Combat dropdowns
    if rects["attackType_dropdown"] and pointInRect(mx, my, unpack(rects["attackType_dropdown"])) then
        local r = rects["attackType_dropdown"]
        self._activeDropdown = {field = "attackType", options = ATTACK_TYPES, x = r[1], y = r[2], w = r[3], h = r[4]}
        self._dropdownScroll = 0
        self._focusedField = nil
        return true
    end

    if rects["damageType_dropdown"] and pointInRect(mx, my, unpack(rects["damageType_dropdown"])) then
        local r = rects["damageType_dropdown"]
        self._activeDropdown = {field = "damageType", options = DAMAGE_TYPES, x = r[1], y = r[2], w = r[3], h = r[4]}
        self._dropdownScroll = 0
        self._focusedField = nil
        return true
    end

    -- New resistance type dropdown
    if rects["newResType_dropdown"] and pointInRect(mx, my, unpack(rects["newResType_dropdown"])) then
        local r = rects["newResType_dropdown"]
        self._activeDropdown = {field = "_newResType", options = DAMAGE_TYPES, x = r[1], y = r[2], w = r[3], h = r[4]}
        self._dropdownScroll = 0
        self._focusedField = nil
        return true
    end

    -- Add resistance button
    if self._addResBtnRect and pointInRect(mx, my, unpack(self._addResBtnRect)) then
        self:_addResistance(self._newResType, self._newResValue)
        return true
    end

    -- Resistance sliders
    if self.selectedEnemy and type(self.selectedEnemy.resistances) == "table" then
        for ri = 1, #self.selectedEnemy.resistances do
            local key = "res_slider_" .. ri
            if rects[key] and pointInRect(mx, my, unpack(rects[key])) then
                local r = rects[key]
                local res = self.selectedEnemy.resistances[ri]
                self._activeSlider = {
                    field = "_res_" .. ri,
                    minVal = RES_MIN,
                    maxVal = RES_MAX,
                    step = RES_STEP,
                    x = r[1],
                    w = r[3],
                    startValue = res.value or 0,
                    resIndex = ri,
                }
                self._focusedField = nil
                return true
            end
        end
    end

    -- Resistance remove buttons
    if self._resRowRects then
        for ri, rowData in pairs(self._resRowRects) do
            if rowData.removeRect and pointInRect(mx, my, unpack(rowData.removeRect)) then
                self:_removeResistance(ri)
                return true
            end
        end
    end

    -- Toggle fields
    if rects["boss_toggle"] and pointInRect(mx, my, unpack(rects["boss_toggle"])) then
        self:_setField("boss", not self.selectedEnemy.boss, "Toggle boss")
        return true
    end
    if rects["calidarOnly_toggle"] and pointInRect(mx, my, unpack(rects["calidarOnly_toggle"])) then
        self:_setField("calidarOnly", not self.selectedEnemy.calidarOnly, "Toggle calidarOnly")
        return true
    end

    self._focusedField = nil
    return true
end

function EnemyEditor:mousereleased(mx, my, button)
    if button ~= 1 then return false end

    -- Slider release is handled in update() to properly commit undo
    -- Handle resistance slider release here specifically
    if self._activeSlider and self._activeSlider.resIndex then
        local slider = self._activeSlider
        local ri = slider.resIndex
        local enemy = self.selectedEnemy
        if enemy and type(enemy.resistances) == "table" then
            local res = enemy.resistances[ri]
            if res then
                local currentVal = res.value
                if currentVal ~= slider.startValue then
                    res.value = slider.startValue
                    self:_setResistanceValue(ri, currentVal)
                end
            end
        end
        self._activeSlider = nil
        return true
    end

    return false
end

---------------------------------------------------------------------------
-- Scroll
---------------------------------------------------------------------------

function EnemyEditor:wheelmoved(wx, wy)
    local mx, my = love.mouse.getPosition()

    -- Dropdown scroll
    if self._activeDropdown then
        local dd = self._activeDropdown
        local maxScroll = math.max(0, #dd.options - 8)
        self._dropdownScroll = clamp(self._dropdownScroll - wy, 0, maxScroll)
        return true
    end

    -- List scroll
    if self._listRect and pointInRect(mx, my, unpack(self._listRect)) then
        self.listScrollY = self.listScrollY - wy * LIST_ITEM_H * 2
        local maxScroll = math.max(0, #self.filteredList * LIST_ITEM_H - self._listRect[4])
        self.listScrollY = clamp(self.listScrollY, 0, maxScroll)
        return true
    end

    -- Center panel scroll
    if self._centerPanelRect and pointInRect(mx, my, unpack(self._centerPanelRect)) then
        self.centerScrollY = self.centerScrollY - wy * 30
        self.centerScrollY = clamp(self.centerScrollY, 0, self.maxCenterScrollY)
        return true
    end

    -- Right panel scroll
    if self._rightPanelRect and pointInRect(mx, my, unpack(self._rightPanelRect)) then
        self.rightScrollY = self.rightScrollY - wy * 30
        self.rightScrollY = clamp(self.rightScrollY, 0, self.maxRightScrollY)
        return true
    end

    return false
end

---------------------------------------------------------------------------
-- Keyboard input
---------------------------------------------------------------------------

function EnemyEditor:keypressed(key)
    -- Undo/Redo
    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
    local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")

    if ctrl and key == "z" then
        if shift then
            self.undoStack:redo()
        else
            self.undoStack:undo()
        end
        self:_syncBuffersFromEnemy()
        self:_markDirty()
        return true
    end

    if ctrl and key == "y" then
        self.undoStack:redo()
        self:_syncBuffersFromEnemy()
        self:_markDirty()
        return true
    end

    -- Text field input
    if self._focusedField then
        if key == "escape" then
            self._focusedField = nil
            self:_syncBuffersFromEnemy()
            return true
        end

        if key == "return" or key == "kpenter" then
            self:_commitTextField()
            if self._focusedField == "newAttack" then
                if self._newAttackText ~= "" then
                    self:_addAttack(self._newAttackText)
                    self._newAttackText = ""
                end
            end
            self._focusedField = nil
            return true
        end

        if key == "tab" then
            self:_commitTextField()
            self:_advanceFocus()
            return true
        end

        if key == "backspace" then
            if self._focusedField == "search" then
                self.searchText = self.searchText:sub(1, -2)
                self:_markDirty()
            elseif self._focusedField == "newAttack" then
                self._newAttackText = self._newAttackText:sub(1, -2)
            elseif self._editBuffers[self._focusedField] then
                self._editBuffers[self._focusedField] = self._editBuffers[self._focusedField]:sub(1, -2)
            end
            return true
        end

        return true
    end

    -- Navigation shortcuts when no field focused
    if key == "delete" and self.selectedEnemy then
        self:_deleteEnemy()
        return true
    end

    if ctrl and key == "d" and self.selectedEnemy then
        self:_duplicateEnemy()
        return true
    end

    if ctrl and key == "n" then
        self:_addEnemy()
        return true
    end

    -- List navigation
    if key == "up" and self.selectedIndex then
        local newIdx = math.max(1, self.selectedIndex - 1)
        self:_selectEnemy(newIdx)
        self:_ensureListItemVisible(newIdx)
        return true
    end
    if key == "down" and self.selectedIndex then
        local newIdx = math.min(#self.filteredList, self.selectedIndex + 1)
        self:_selectEnemy(newIdx)
        self:_ensureListItemVisible(newIdx)
        return true
    end

    return false
end

function EnemyEditor:_ensureListItemVisible(index)
    if not self._listRect then return end
    local listH = self._listRect[4]
    local itemTop = (index - 1) * LIST_ITEM_H
    local itemBottom = itemTop + LIST_ITEM_H
    if itemTop < self.listScrollY then
        self.listScrollY = itemTop
    elseif itemBottom > self.listScrollY + listH then
        self.listScrollY = itemBottom - listH
    end
end

function EnemyEditor:textinput(t)
    if not self._focusedField then return false end

    if self._focusedField == "search" then
        self.searchText = self.searchText .. t
        self:_markDirty()
        return true
    end

    if self._focusedField == "newAttack" then
        self._newAttackText = self._newAttackText .. t
        return true
    end

    if self._editBuffers[self._focusedField] ~= nil then
        self._editBuffers[self._focusedField] = self._editBuffers[self._focusedField] .. t
        return true
    end

    return false
end

function EnemyEditor:_commitTextField()
    local field = self._focusedField
    if not field or not self.selectedEnemy then return end
    if field == "search" or field == "newAttack" then return end

    local buf = self._editBuffers[field]
    if buf == nil then return end

    local enemy = self.selectedEnemy

    -- Numeric fields
    if field == "cr" then
        local n = tonumber(buf)
        if n then
            n = round(clamp(n, CR_MIN, CR_MAX), CR_STEP)
            self:_setField("cr", n, "Set CR to " .. fmtNum(n))
        else
            self:_syncBuffersFromEnemy()
        end
        return
    end

    if field == "attackRange" then
        local n = tonumber(buf)
        if n then
            n = clamp(math.floor(n), RANGE_MIN, RANGE_MAX)
            self:_setField("attackRange", n, "Set attackRange to " .. n)
        else
            self:_syncBuffersFromEnemy()
        end
        return
    end

    -- Multiplier fields
    local multFields3 = {hpMult = true, atkMult = true, defMult = true, xpMult = true, goldMult = true}
    if multFields3[field] then
        local n = tonumber(buf)
        if n then
            n = round(clamp(n, MULT_MIN, MULT_MAX), MULT_STEP)
            self:_setField(field, n, "Set " .. field .. " to " .. fmtNum(n))
        else
            self:_syncBuffersFromEnemy()
        end
        return
    end

    -- String fields: id, name, description, portrait
    if field == "id" then
        local newId = IdGen.generateId(buf)
        if newId ~= enemy.id then
            -- Ensure unique
            local existingIds = {}
            for _, e in ipairs(self.enemies) do
                if e ~= enemy then
                    existingIds[e.id] = true
                end
            end
            newId = IdGen.ensureUnique(newId, existingIds)
            self:_setField("id", newId, "Set id to " .. newId)
        end
        return
    end

    -- Generic string fields
    if buf ~= (enemy[field] or "") then
        self:_setField(field, buf, "Set " .. field)
    end
end

function EnemyEditor:_advanceFocus()
    local order = {"id", "name", "description", "portrait"}
    local current = self._focusedField
    for i, f in ipairs(order) do
        if f == current then
            local nextField = order[i + 1]
            if nextField then
                self._focusedField = nextField
            else
                self._focusedField = nil
            end
            return
        end
    end
    self._focusedField = nil
end

---------------------------------------------------------------------------
-- Update
---------------------------------------------------------------------------

function EnemyEditor:update(dt)
    if self._filterDirty then
        self:_rebuildFilteredList()
    end

    -- Handle active slider dragging
    if self._activeSlider and love.mouse.isDown(1) then
        local mx2 = love.mouse.getX()
        local slider = self._activeSlider
        local t = clamp((mx2 - slider.x) / slider.w, 0, 1)
        local rawVal = slider.minVal + t * (slider.maxVal - slider.minVal)
        local snapped = round(rawVal, slider.step)
        snapped = clamp(snapped, slider.minVal, slider.maxVal)

        if slider.field == "_crFilterMin" then
            self.crFilterMin = math.min(snapped, self.crFilterMax)
            self:_markDirty()
        elseif slider.field == "_crFilterMax" then
            self.crFilterMax = math.max(snapped, self.crFilterMin)
            self:_markDirty()
        elseif slider.resIndex then
            -- Resistance slider
            local enemy = self.selectedEnemy
            if enemy and type(enemy.resistances) == "table" then
                local res = enemy.resistances[slider.resIndex]
                if res then
                    res.value = snapped
                end
            end
        elseif self.selectedEnemy then
            self.selectedEnemy[slider.field] = snapped
            self._editBuffers[slider.field] = fmtNum(snapped)
        end
    elseif self._activeSlider and not love.mouse.isDown(1) then
        local slider = self._activeSlider
        if slider.resIndex then
            -- Resistance slider release
            local ri = slider.resIndex
            local enemy = self.selectedEnemy
            if enemy and type(enemy.resistances) == "table" then
                local res = enemy.resistances[ri]
                if res then
                    local currentVal = res.value
                    if currentVal ~= slider.startValue then
                        res.value = slider.startValue
                        self:_setResistanceValue(ri, currentVal)
                    end
                end
            end
        elseif slider.field ~= "_crFilterMin" and slider.field ~= "_crFilterMax" then
            local enemy = self.selectedEnemy
            if enemy then
                local currentVal = enemy[slider.field]
                if currentVal ~= slider.startValue then
                    local field = slider.field
                    local oldVal = slider.startValue
                    local newVal = currentVal
                    enemy[field] = oldVal
                    self.undoStack:push({
                        description = "Set " .. field .. " to " .. fmtNum(newVal),
                        execute = function()
                            enemy[field] = newVal
                        end,
                        undo = function()
                            enemy[field] = oldVal
                        end,
                    })
                    self:_syncBuffersFromEnemy()
                    self:_markDirty()
                end
            end
        end
        self._activeSlider = nil
    end
end

return EnemyEditor
