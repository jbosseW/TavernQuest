-- ==========================================================================
-- UI Widget Library for Tavern Quest Editor Suite
-- A comprehensive, production-quality LOVE2D 11.4 widget system
-- ==========================================================================

local Theme = require("core.theme")
local FontCache = require("core.fontcache")

local UI = {}

-- =========================================================================
-- Internal State
-- =========================================================================

local _focusedWidget = nil   -- currently focused TextInput (or nil)
local _activeModal = nil     -- currently displayed modal (or nil)
local _hotWidget = nil       -- widget under the mouse this frame
local _pressedWidget = nil   -- widget that received mousedown

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

local function shallowCopy(t)
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
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
-- Focus management
-- =========================================================================

function UI.setFocus(widget)
    if _focusedWidget and _focusedWidget ~= widget and _focusedWidget.onBlur then
        _focusedWidget:onBlur()
    end
    _focusedWidget = widget
    if widget and widget.onFocus then
        widget:onFocus()
    end
end

function UI.getFocus()
    return _focusedWidget
end

function UI.clearFocus()
    if _focusedWidget and _focusedWidget.onBlur then
        _focusedWidget:onBlur()
    end
    _focusedWidget = nil
end

function UI.setModal(modal)
    _activeModal = modal
end

function UI.getModal()
    return _activeModal
end

function UI.clearModal()
    _activeModal = nil
end

function UI.isModalActive()
    return _activeModal ~= nil
end


-- =========================================================================
-- LABEL
-- =========================================================================

UI.Label = {}
UI.Label.__index = UI.Label

function UI.Label.new(opts)
    opts = opts or {}
    local self = setmetatable({}, UI.Label)
    self.text = opts.text or ""
    self.color = opts.color or Theme.colors.text
    self.fontSize = opts.fontSize or 14
    self.align = opts.align or "left"
    self.bold = opts.bold or false
    return self
end

function UI.Label:draw(x, y, w, h)
    w = w or 200
    h = h or Theme.sizes.buttonHeight
    local font = self.bold and FontCache.getBold(self.fontSize) or FontCache.get(self.fontSize)
    love.graphics.setFont(font)
    setColorSafe(self.color)
    local textH = font:getHeight()
    local ty = y + math.floor((h - textH) / 2)
    love.graphics.printf(self.text, x, ty, w, self.align)
end

function UI.Label:setText(text)
    self.text = text or ""
end


-- =========================================================================
-- SEPARATOR
-- =========================================================================

UI.Separator = {}
UI.Separator.__index = UI.Separator

function UI.Separator.new(opts)
    opts = opts or {}
    local self = setmetatable({}, UI.Separator)
    self.orientation = opts.orientation or "horizontal"
    self.color = opts.color or Theme.colors.panelBorder
    self.thickness = opts.thickness or 1
    return self
end

function UI.Separator:draw(x, y, w, h)
    setColorSafe(self.color)
    if self.orientation == "horizontal" then
        local cy = y + math.floor((h or 1) / 2)
        love.graphics.rectangle("fill", x, cy, w or 100, self.thickness)
    else
        local cx = x + math.floor((w or 1) / 2)
        love.graphics.rectangle("fill", cx, y, self.thickness, h or 100)
    end
end


-- =========================================================================
-- BUTTON
-- =========================================================================

UI.Button = {}
UI.Button.__index = UI.Button

function UI.Button.new(opts)
    opts = opts or {}
    local self = setmetatable({}, UI.Button)
    self.text = opts.text or "Button"
    self.icon = opts.icon or nil
    self.variant = opts.variant or "primary"  -- primary, secondary, danger, ghost
    self.disabled = opts.disabled or false
    self.onClick = opts.onClick or nil
    self.fontSize = opts.fontSize or 13
    self.tooltip = opts.tooltip or nil
    -- internal state
    self._hovered = false
    self._pressed = false
    self._lastX = 0
    self._lastY = 0
    self._lastW = 0
    self._lastH = 0
    return self
end

function UI.Button:_getColors()
    local c = Theme.colors
    if self.disabled then
        return c.tabInactive, c.textDim, c.tabInactive
    end

    local variant = self.variant
    if variant == "primary" then
        if self._pressed then
            return c.primaryDark, c.bg, c.primaryDark
        elseif self._hovered then
            return c.primaryHover, c.bg, c.primaryHover
        else
            return c.primary, c.bg, c.primary
        end
    elseif variant == "secondary" then
        if self._pressed then
            return c.secondary, c.text, c.secondary
        elseif self._hovered then
            return c.secondaryHover, c.text, c.secondaryHover
        else
            return c.bgLight, c.text, c.inputBorder
        end
    elseif variant == "danger" then
        if self._pressed then
            return c.danger, c.text, c.danger
        elseif self._hovered then
            return c.dangerHover, c.text, c.dangerHover
        else
            return c.danger, c.text, c.danger
        end
    elseif variant == "ghost" then
        if self._pressed then
            return c.bgLight, c.text, nil
        elseif self._hovered then
            return c.tabHover, c.text, nil
        else
            return nil, c.textDim, nil
        end
    end
    -- fallback
    return c.primary, c.bg, c.primary
end

function UI.Button:draw(x, y, w, h)
    w = w or 100
    h = h or Theme.sizes.buttonHeight

    self._lastX = x
    self._lastY = y
    self._lastW = w
    self._lastH = h

    local mx, my = love.mouse.getPosition()
    self._hovered = pointInRect(mx, my, x, y, w, h) and not self.disabled

    local bgCol, fgCol, borderCol = self:_getColors()
    local r = Theme.radius.sm

    -- background
    if bgCol then
        setColorSafe(bgCol)
        drawRoundedRect("fill", x, y, w, h, r)
    end

    -- border
    if borderCol then
        setColorSafe(borderCol)
        love.graphics.setLineWidth(1)
        drawRoundedRect("line", x + 0.5, y + 0.5, w - 1, h - 1, r)
    end

    -- text
    local font = FontCache.get(self.fontSize)
    love.graphics.setFont(font)
    setColorSafe(fgCol)

    local textW = font:getWidth(self.text)
    local textH = font:getHeight()
    local iconW = 0
    local iconSpacing = 0

    if self.icon then
        iconW = textH
        iconSpacing = Theme.spacing.sm
    end

    local totalW = iconW + iconSpacing + textW
    local startX = x + math.floor((w - totalW) / 2)
    local textY = y + math.floor((h - textH) / 2)

    if self.icon then
        -- draw icon text (character icon placeholder)
        love.graphics.print(self.icon, startX, textY)
        startX = startX + iconW + iconSpacing
    end

    love.graphics.print(self.text, startX, textY)
end

function UI.Button:mousepressed(mx, my, button)
    if button ~= 1 or self.disabled then return false end
    if pointInRect(mx, my, self._lastX, self._lastY, self._lastW, self._lastH) then
        self._pressed = true
        return true
    end
    return false
end

function UI.Button:mousereleased(mx, my, button)
    if button ~= 1 then return false end
    local wasPressed = self._pressed
    self._pressed = false
    if wasPressed and not self.disabled
        and pointInRect(mx, my, self._lastX, self._lastY, self._lastW, self._lastH) then
        if self.onClick then
            self.onClick()
        end
        return true
    end
    return false
end

function UI.Button:setDisabled(disabled)
    self.disabled = disabled
    if disabled then
        self._pressed = false
        self._hovered = false
    end
end


-- =========================================================================
-- PANEL
-- =========================================================================

UI.Panel = {}
UI.Panel.__index = UI.Panel

function UI.Panel.new(opts)
    opts = opts or {}
    local self = setmetatable({}, UI.Panel)
    self.title = opts.title or nil
    self.showBorder = opts.showBorder ~= false  -- default true
    self.showHeader = opts.showHeader or (self.title ~= nil)
    self.headerHeight = opts.headerHeight or Theme.sizes.tabBarHeight
    self.bgColor = opts.bgColor or Theme.colors.panel
    self.borderColor = opts.borderColor or Theme.colors.panelBorder
    self.headerColor = opts.headerColor or Theme.colors.panelHeader
    self.titleColor = opts.titleColor or Theme.colors.text
    self.titleFontSize = opts.titleFontSize or 13
    self.padding = opts.padding or Theme.spacing.md
    self.children = opts.children or {}
    return self
end

function UI.Panel:draw(x, y, w, h)
    w = w or 200
    h = h or 200
    local r = Theme.radius.md

    -- background
    setColorSafe(self.bgColor)
    drawRoundedRect("fill", x, y, w, h, r)

    -- border
    if self.showBorder then
        setColorSafe(self.borderColor)
        love.graphics.setLineWidth(1)
        drawRoundedRect("line", x + 0.5, y + 0.5, w - 1, h - 1, r)
    end

    -- header
    if self.showHeader and self.title then
        setColorSafe(self.headerColor)
        -- top portion rounded, bottom flat
        love.graphics.rectangle("fill", x + 1, y + 1, w - 2, self.headerHeight, r, r)
        -- overwrite bottom rounded part of header
        love.graphics.rectangle("fill", x + 1, y + self.headerHeight - r, w - 2, r)

        -- header divider
        setColorSafe(self.borderColor)
        love.graphics.rectangle("fill", x, y + self.headerHeight, w, 1)

        -- title text
        local font = FontCache.get(self.titleFontSize)
        love.graphics.setFont(font)
        setColorSafe(self.titleColor)
        local textH = font:getHeight()
        local ty = y + math.floor((self.headerHeight - textH) / 2)
        love.graphics.print(self.title, x + Theme.spacing.lg, ty)
    end
end

function UI.Panel:getContentArea(x, y, w, h)
    local pad = self.padding
    local topOffset = 0
    if self.showHeader and self.title then
        topOffset = self.headerHeight + 1
    end
    return x + pad, y + topOffset + pad, w - pad * 2, h - topOffset - pad * 2
end


-- =========================================================================
-- TABBAR
-- =========================================================================

UI.TabBar = {}
UI.TabBar.__index = UI.TabBar

function UI.TabBar.new(opts)
    opts = opts or {}
    local self = setmetatable({}, UI.TabBar)
    self.tabs = opts.tabs or {}   -- array of {label=string, id=string/any}
    self.activeTab = opts.activeTab or (self.tabs[1] and self.tabs[1].id or nil)
    self.onTabChange = opts.onTabChange or nil
    self.fontSize = opts.fontSize or 13
    self.tabPadding = opts.tabPadding or Theme.spacing.xl
    self._tabRects = {}
    return self
end

function UI.TabBar:draw(x, y, w, h)
    h = h or Theme.sizes.tabBarHeight
    w = w or 400

    -- background
    setColorSafe(Theme.colors.panel)
    love.graphics.rectangle("fill", x, y, w, h)

    -- bottom border
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", x, y + h - 1, w, 1)

    local font = FontCache.get(self.fontSize)
    love.graphics.setFont(font)
    local textH = font:getHeight()
    local mx, my = love.mouse.getPosition()
    local tx = x

    self._tabRects = {}

    for i, tab in ipairs(self.tabs) do
        local label = tab.label or tostring(tab.id or i)
        local labelW = font:getWidth(label) + self.tabPadding * 2
        local isActive = (tab.id == self.activeTab)
        local isHovered = pointInRect(mx, my, tx, y, labelW, h)

        -- tab background
        if isActive then
            setColorSafe(Theme.colors.panel)
        elseif isHovered then
            setColorSafe(Theme.colors.tabHover)
        else
            setColorSafe(Theme.colors.tabInactive)
        end
        love.graphics.rectangle("fill", tx, y, labelW, h)

        -- active indicator bar
        if isActive then
            setColorSafe(Theme.colors.tabActive)
            love.graphics.rectangle("fill", tx, y + h - 3, labelW, 3)
        end

        -- text
        if isActive then
            setColorSafe(Theme.colors.tabText or Theme.colors.text)
        elseif isHovered then
            setColorSafe(Theme.colors.text)
        else
            setColorSafe(Theme.colors.tabTextInactive or Theme.colors.textDim)
        end
        local textY = y + math.floor((h - textH) / 2)
        love.graphics.print(label, tx + self.tabPadding, textY)

        -- store rect for click detection
        self._tabRects[i] = {x = tx, y = y, w = labelW, h = h, id = tab.id}
        tx = tx + labelW
    end
end

function UI.TabBar:mousepressed(mx, my, button)
    if button ~= 1 then return false end
    for _, rect in ipairs(self._tabRects) do
        if pointInRect(mx, my, rect.x, rect.y, rect.w, rect.h) then
            if rect.id ~= self.activeTab then
                self.activeTab = rect.id
                if self.onTabChange then
                    self.onTabChange(rect.id)
                end
            end
            return true
        end
    end
    return false
end

function UI.TabBar:setActive(id)
    self.activeTab = id
end


-- =========================================================================
-- TEXTINPUT
-- =========================================================================

UI.TextInput = {}
UI.TextInput.__index = UI.TextInput

function UI.TextInput.new(opts)
    opts = opts or {}
    local self = setmetatable({}, UI.TextInput)
    self.text = opts.text or ""
    self.placeholder = opts.placeholder or ""
    self.fontSize = opts.fontSize or 13
    self.onChange = opts.onChange or nil
    self.onSubmit = opts.onSubmit or nil
    self.maxLength = opts.maxLength or 1024
    self.readOnly = opts.readOnly or false
    self.password = opts.password or false
    -- internal
    self._focused = false
    self._cursorPos = #self.text   -- byte position (end of text)
    self._cursorBlink = 0
    self._scrollX = 0
    self._selStart = nil
    self._selEnd = nil
    self._lastX = 0
    self._lastY = 0
    self._lastW = 0
    self._lastH = 0
    return self
end

function UI.TextInput:update(dt)
    if self._focused then
        self._cursorBlink = self._cursorBlink + dt
        if self._cursorBlink > 1.0 then
            self._cursorBlink = self._cursorBlink - 1.0
        end
    end
end

function UI.TextInput:_displayText()
    if self.password then
        -- One mask character per byte; cursor position maps directly.
        -- For pure ASCII passwords this is correct. Multi-byte UTF-8 in
        -- passwords will show extra mask characters but remain functional.
        return string.rep("*", #self.text)
    end
    return self.text
end

function UI.TextInput:draw(x, y, w, h)
    w = w or 200
    h = h or Theme.sizes.inputHeight

    self._lastX = x
    self._lastY = y
    self._lastW = w
    self._lastH = h

    local r = Theme.radius.sm
    local pad = Theme.spacing.md
    local font = FontCache.get(self.fontSize)
    love.graphics.setFont(font)

    -- background
    setColorSafe(Theme.colors.input)
    drawRoundedRect("fill", x, y, w, h, r)

    -- border
    if self._focused then
        setColorSafe(Theme.colors.inputFocus)
    else
        setColorSafe(Theme.colors.inputBorder)
    end
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", x + 0.5, y + 0.5, w - 1, h - 1, r)

    -- clip text area
    local clipX = x + pad
    local clipW = w - pad * 2
    if clipW < 1 then clipW = 1 end

    love.graphics.setScissor(clipX, y, clipW, h)

    local displayText = self:_displayText()
    local textH = font:getHeight()
    local textY = y + math.floor((h - textH) / 2)

    -- cursor position in pixels
    local cursorPx = font:getWidth(displayText:sub(1, self._cursorPos))

    -- auto-scroll to keep cursor visible
    if cursorPx - self._scrollX > clipW - 2 then
        self._scrollX = cursorPx - clipW + 2
    end
    if cursorPx - self._scrollX < 0 then
        self._scrollX = cursorPx
    end
    if self._scrollX < 0 then
        self._scrollX = 0
    end

    local drawX = clipX - self._scrollX

    -- selection highlight
    if self._focused and self._selStart and self._selEnd and self._selStart ~= self._selEnd then
        local s1 = math.min(self._selStart, self._selEnd)
        local s2 = math.max(self._selStart, self._selEnd)
        local selXStart = font:getWidth(displayText:sub(1, s1))
        local selXEnd = font:getWidth(displayText:sub(1, s2))
        setColorSafe(Theme.colors.listItemSelected)
        love.graphics.rectangle("fill", drawX + selXStart, y + 2, selXEnd - selXStart, h - 4)
    end

    -- text or placeholder
    if #displayText > 0 then
        setColorSafe(Theme.colors.text)
        love.graphics.print(displayText, drawX, textY)
    elseif not self._focused then
        setColorSafe(Theme.colors.textDim)
        love.graphics.print(self.placeholder, drawX, textY)
    else
        setColorSafe(Theme.colors.textDim)
        love.graphics.print(self.placeholder, drawX, textY)
    end

    -- cursor
    if self._focused and self._cursorBlink < 0.5 then
        setColorSafe(Theme.colors.text)
        local cx = drawX + cursorPx
        love.graphics.rectangle("fill", cx, y + 4, 1, h - 8)
    end

    love.graphics.setScissor()
end

function UI.TextInput:_byteToCharPos(bytePos)
    -- count UTF-8 characters up to byte position
    local chars = 0
    local i = 1
    while i <= bytePos and i <= #self.text do
        local b = self.text:byte(i)
        if b < 128 then i = i + 1
        elseif b < 224 then i = i + 2
        elseif b < 240 then i = i + 3
        else i = i + 4
        end
        chars = chars + 1
    end
    return chars
end

function UI.TextInput:_charToBytePos(charPos)
    local i = 1
    local chars = 0
    while chars < charPos and i <= #self.text do
        local b = self.text:byte(i)
        if b < 128 then i = i + 1
        elseif b < 224 then i = i + 2
        elseif b < 240 then i = i + 3
        else i = i + 4
        end
        chars = chars + 1
    end
    return i - 1
end

function UI.TextInput:_prevCursorPos()
    if self._cursorPos <= 0 then return 0 end
    -- _cursorPos is a 0-based byte offset (0 = before first byte, #text = after last byte)
    -- Walk backwards from current position to find start of previous UTF-8 character
    local i = self._cursorPos  -- 1-indexed position of byte AT cursor (the one we are skipping back over)
    -- Skip continuation bytes (10xxxxxx, range 128..191)
    while i > 1 do
        local b = self.text:byte(i)
        if not b or b < 128 or b >= 192 then
            -- This is either ASCII or a UTF-8 leading byte - this is the start of the char
            break
        end
        i = i - 1
    end
    -- Cursor position is the 0-based offset before this byte
    return i - 1
end

function UI.TextInput:_nextCursorPos()
    if self._cursorPos >= #self.text then return #self.text end
    -- _cursorPos is 0-based. The byte at 1-indexed position (cursorPos + 1) starts the next char.
    local i = self._cursorPos + 1  -- 1-indexed start of next character
    local b = self.text:byte(i)
    if not b or b < 128 then
        return self._cursorPos + 1
    elseif b < 224 then
        return math.min(self._cursorPos + 2, #self.text)
    elseif b < 240 then
        return math.min(self._cursorPos + 3, #self.text)
    else
        return math.min(self._cursorPos + 4, #self.text)
    end
end

function UI.TextInput:_deleteSelection()
    if not self._selStart or not self._selEnd or self._selStart == self._selEnd then
        return false
    end
    local s1 = math.min(self._selStart, self._selEnd)
    local s2 = math.max(self._selStart, self._selEnd)
    self.text = self.text:sub(1, s1) .. self.text:sub(s2 + 1)
    self._cursorPos = s1
    self._selStart = nil
    self._selEnd = nil
    return true
end

function UI.TextInput:_getSelectedText()
    if not self._selStart or not self._selEnd or self._selStart == self._selEnd then
        return ""
    end
    local s1 = math.min(self._selStart, self._selEnd)
    local s2 = math.max(self._selStart, self._selEnd)
    return self.text:sub(s1 + 1, s2)
end

function UI.TextInput:_pixelToCursorPos(px)
    local font = FontCache.get(self.fontSize)
    local displayText = self:_displayText()
    local pad = Theme.spacing.md
    local relX = px - self._lastX - pad + self._scrollX
    if relX <= 0 then return 0 end

    -- Iterate through UTF-8 character boundaries
    local best = 0
    local bytePos = 0
    local i = 1
    while i <= #displayText do
        local b = displayText:byte(i)
        local charLen = 1
        if b >= 240 then charLen = 4
        elseif b >= 224 then charLen = 3
        elseif b >= 192 then charLen = 2
        end
        local nextBytePos = math.min(i - 1 + charLen, #displayText)
        local w = font:getWidth(displayText:sub(1, nextBytePos))
        if w > relX then
            local prevW = font:getWidth(displayText:sub(1, bytePos))
            if (relX - prevW) < (w - relX) then
                return bytePos
            else
                return nextBytePos
            end
        end
        bytePos = nextBytePos
        best = bytePos
        i = i + charLen
    end
    return best
end

function UI.TextInput:mousepressed(mx, my, button)
    if button ~= 1 then return false end
    if pointInRect(mx, my, self._lastX, self._lastY, self._lastW, self._lastH) then
        if not self._focused then
            self._focused = true
            UI.setFocus(self)
        end
        self._cursorBlink = 0
        self._cursorPos = self:_pixelToCursorPos(mx)
        self._selStart = self._cursorPos
        self._selEnd = self._cursorPos
        return true
    else
        if self._focused then
            self._focused = false
            self._selStart = nil
            self._selEnd = nil
            if UI.getFocus() == self then
                UI.clearFocus()
            end
        end
        return false
    end
end

function UI.TextInput:mousemoved(mx, my)
    if not self._focused then return false end
    if love.mouse.isDown(1) and self._selStart then
        self._selEnd = self:_pixelToCursorPos(mx)
        self._cursorPos = self._selEnd
        self._cursorBlink = 0
        return true
    end
    return false
end

function UI.TextInput:keypressed(key)
    if not self._focused or self.readOnly then return false end

    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
    local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")

    if key == "backspace" then
        if self:_deleteSelection() then
            -- deleted selection
        elseif self._cursorPos > 0 then
            local prevPos = self:_prevCursorPos()
            self.text = self.text:sub(1, prevPos) .. self.text:sub(self._cursorPos + 1)
            self._cursorPos = prevPos
        end
        self._cursorBlink = 0
        if self.onChange then self.onChange(self.text) end
        return true

    elseif key == "delete" then
        if self:_deleteSelection() then
            -- deleted selection
        elseif self._cursorPos < #self.text then
            local nextPos = self:_nextCursorPos()
            self.text = self.text:sub(1, self._cursorPos) .. self.text:sub(nextPos + 1)
        end
        self._cursorBlink = 0
        if self.onChange then self.onChange(self.text) end
        return true

    elseif key == "left" then
        if shift then
            if not self._selStart then self._selStart = self._cursorPos end
            if self._cursorPos > 0 then
                self._cursorPos = self:_prevCursorPos()
            end
            self._selEnd = self._cursorPos
        else
            if self._selStart and self._selEnd and self._selStart ~= self._selEnd then
                self._cursorPos = math.min(self._selStart, self._selEnd)
            elseif self._cursorPos > 0 then
                self._cursorPos = self:_prevCursorPos()
            end
            self._selStart = nil
            self._selEnd = nil
        end
        self._cursorBlink = 0
        return true

    elseif key == "right" then
        if shift then
            if not self._selStart then self._selStart = self._cursorPos end
            if self._cursorPos < #self.text then
                self._cursorPos = self:_nextCursorPos()
            end
            self._selEnd = self._cursorPos
        else
            if self._selStart and self._selEnd and self._selStart ~= self._selEnd then
                self._cursorPos = math.max(self._selStart, self._selEnd)
            elseif self._cursorPos < #self.text then
                self._cursorPos = self:_nextCursorPos()
            end
            self._selStart = nil
            self._selEnd = nil
        end
        self._cursorBlink = 0
        return true

    elseif key == "home" then
        if shift then
            if not self._selStart then self._selStart = self._cursorPos end
            self._cursorPos = 0
            self._selEnd = 0
        else
            self._cursorPos = 0
            self._selStart = nil
            self._selEnd = nil
        end
        self._cursorBlink = 0
        return true

    elseif key == "end" then
        if shift then
            if not self._selStart then self._selStart = self._cursorPos end
            self._cursorPos = #self.text
            self._selEnd = #self.text
        else
            self._cursorPos = #self.text
            self._selStart = nil
            self._selEnd = nil
        end
        self._cursorBlink = 0
        return true

    elseif key == "return" or key == "kpenter" then
        if self.onSubmit then
            self.onSubmit(self.text)
        end
        return true

    elseif ctrl and key == "a" then
        self._selStart = 0
        self._selEnd = #self.text
        self._cursorPos = #self.text
        return true

    elseif ctrl and key == "c" then
        local sel = self:_getSelectedText()
        if #sel > 0 then
            love.system.setClipboardText(sel)
        end
        return true

    elseif ctrl and key == "x" then
        local sel = self:_getSelectedText()
        if #sel > 0 then
            love.system.setClipboardText(sel)
            self:_deleteSelection()
            if self.onChange then self.onChange(self.text) end
        end
        return true

    elseif ctrl and key == "v" then
        local clip = love.system.getClipboardText() or ""
        -- remove newlines
        clip = clip:gsub("\n", ""):gsub("\r", "")
        if #clip > 0 then
            self:_deleteSelection()
            if #self.text + #clip <= self.maxLength then
                self.text = self.text:sub(1, self._cursorPos) .. clip .. self.text:sub(self._cursorPos + 1)
                self._cursorPos = self._cursorPos + #clip
                if self.onChange then self.onChange(self.text) end
            end
        end
        return true
    end

    return false
end

function UI.TextInput:textinput(t)
    if not self._focused or self.readOnly then return false end
    self:_deleteSelection()
    if #self.text + #t <= self.maxLength then
        self.text = self.text:sub(1, self._cursorPos) .. t .. self.text:sub(self._cursorPos + 1)
        self._cursorPos = self._cursorPos + #t
        self._cursorBlink = 0
        if self.onChange then self.onChange(self.text) end
    end
    return true
end

function UI.TextInput:onFocus()
    self._focused = true
    self._cursorBlink = 0
end

function UI.TextInput:onBlur()
    self._focused = false
    self._selStart = nil
    self._selEnd = nil
end

function UI.TextInput:setText(text)
    self.text = text or ""
    self._cursorPos = math.min(self._cursorPos, #self.text)
    self._selStart = nil
    self._selEnd = nil
end

function UI.TextInput:getText()
    return self.text
end


-- =========================================================================
-- SLIDER
-- =========================================================================

UI.Slider = {}
UI.Slider.__index = UI.Slider

function UI.Slider.new(opts)
    opts = opts or {}
    local self = setmetatable({}, UI.Slider)
    self.min = opts.min or 0
    self.max = opts.max or 100
    self.value = clamp(opts.value or self.min, self.min, self.max)
    self.step = opts.step or 0
    self.label = opts.label or nil
    self.showValue = opts.showValue ~= false
    self.onChange = opts.onChange or nil
    self.fontSize = opts.fontSize or 13
    self.disabled = opts.disabled or false
    -- internal
    self._dragging = false
    self._lastX = 0
    self._lastY = 0
    self._lastW = 0
    self._lastH = 0
    return self
end

function UI.Slider:_snapToStep(v)
    if self.step and self.step > 0 then
        v = math.floor((v - self.min) / self.step + 0.5) * self.step + self.min
    end
    return clamp(v, self.min, self.max)
end

function UI.Slider:_getTrackRect(x, y, w, h)
    local trackH = 6
    local labelOffset = 0
    if self.label then
        labelOffset = 16
    end
    local trackY = y + labelOffset + math.floor((h - labelOffset - trackH) / 2)
    return x, trackY, w, trackH
end

function UI.Slider:_getThumbX(trackX, trackW)
    if self.max == self.min then return trackX end
    local t = (self.value - self.min) / (self.max - self.min)
    return trackX + t * trackW
end

function UI.Slider:draw(x, y, w, h)
    w = w or 200
    h = h or 32

    self._lastX = x
    self._lastY = y
    self._lastW = w
    self._lastH = h

    local font = FontCache.get(self.fontSize)
    love.graphics.setFont(font)

    -- label
    local labelOffset = 0
    if self.label then
        labelOffset = 16
        setColorSafe(Theme.colors.text)
        love.graphics.print(self.label, x, y)
        if self.showValue then
            local valStr = tostring(self.value)
            if self.step and self.step >= 1 then
                valStr = tostring(math.floor(self.value))
            else
                valStr = string.format("%.2f", self.value)
            end
            local valW = font:getWidth(valStr)
            setColorSafe(Theme.colors.textDim)
            love.graphics.print(valStr, x + w - valW, y)
        end
    end

    -- track
    local trackX, trackY, trackW, trackH = self:_getTrackRect(x, y, w, h)
    local thumbR = 7
    local trackInset = thumbR
    local innerTrackX = trackX + trackInset
    local innerTrackW = trackW - trackInset * 2
    if innerTrackW < 1 then innerTrackW = 1 end

    -- track background
    setColorSafe(Theme.colors.scrollbar)
    drawRoundedRect("fill", innerTrackX, trackY, innerTrackW, trackH, trackH / 2)

    -- filled portion
    local thumbX = self:_getThumbX(innerTrackX, innerTrackW)
    if thumbX > innerTrackX then
        if self.disabled then
            setColorSafe(Theme.colors.textDim)
        else
            setColorSafe(Theme.colors.primary)
        end
        local fillW = thumbX - innerTrackX
        if fillW > 0 then
            drawRoundedRect("fill", innerTrackX, trackY, fillW, trackH, trackH / 2)
        end
    end

    -- thumb
    local thumbCY = trackY + trackH / 2
    if self.disabled then
        setColorSafe(Theme.colors.textDim)
    elseif self._dragging then
        setColorSafe(Theme.colors.primaryHover)
    else
        local mx, my = love.mouse.getPosition()
        local dist = math.sqrt((mx - thumbX)^2 + (my - thumbCY)^2)
        if dist <= thumbR + 2 then
            setColorSafe(Theme.colors.primaryHover)
        else
            setColorSafe(Theme.colors.primary)
        end
    end
    love.graphics.circle("fill", thumbX, thumbCY, thumbR)

    -- value display without label
    if not self.label and self.showValue then
        local valStr
        if self.step and self.step >= 1 then
            valStr = tostring(math.floor(self.value))
        else
            valStr = string.format("%.2f", self.value)
        end
        setColorSafe(Theme.colors.textDim)
        local valW = font:getWidth(valStr)
        love.graphics.print(valStr, x + w - valW, y + h - font:getHeight() - 2)
    end
end

function UI.Slider:_updateValueFromMouse(mx)
    local trackX, _, trackW, _ = self:_getTrackRect(self._lastX, self._lastY, self._lastW, self._lastH)
    local thumbR = 7
    local innerTrackX = trackX + thumbR
    local innerTrackW = trackW - thumbR * 2
    if innerTrackW < 1 then innerTrackW = 1 end

    local t = (mx - innerTrackX) / innerTrackW
    t = clamp(t, 0, 1)
    local newVal = self.min + t * (self.max - self.min)
    newVal = self:_snapToStep(newVal)

    if newVal ~= self.value then
        self.value = newVal
        if self.onChange then
            self.onChange(self.value)
        end
    end
end

function UI.Slider:mousepressed(mx, my, button)
    if button ~= 1 or self.disabled then return false end
    if pointInRect(mx, my, self._lastX, self._lastY, self._lastW, self._lastH) then
        self._dragging = true
        self:_updateValueFromMouse(mx)
        return true
    end
    return false
end

function UI.Slider:mousereleased(mx, my, button)
    if button ~= 1 then return false end
    if self._dragging then
        self._dragging = false
        return true
    end
    return false
end

function UI.Slider:mousemoved(mx, my)
    if self._dragging then
        self:_updateValueFromMouse(mx)
        return true
    end
    return false
end

function UI.Slider:update(dt)
    -- No time-based behaviour yet; stub keeps the widget interface
    -- consistent with TextInput and Toggle so callers can iterate
    -- all widgets and call :update(dt) uniformly.
end

function UI.Slider:setValue(v)
    self.value = self:_snapToStep(clamp(v, self.min, self.max))
end


-- =========================================================================
-- TOGGLE
-- =========================================================================

UI.Toggle = {}
UI.Toggle.__index = UI.Toggle

function UI.Toggle.new(opts)
    opts = opts or {}
    local self = setmetatable({}, UI.Toggle)
    self.value = opts.value or false
    self.label = opts.label or nil
    self.onChange = opts.onChange or nil
    self.disabled = opts.disabled or false
    self.fontSize = opts.fontSize or 13
    -- internal
    self._anim = self.value and 1.0 or 0.0
    self._lastX = 0
    self._lastY = 0
    self._lastW = 0
    self._lastH = 0
    return self
end

function UI.Toggle:update(dt)
    local target = self.value and 1.0 or 0.0
    if self._anim ~= target then
        local speed = 8
        if self._anim < target then
            self._anim = math.min(self._anim + speed * dt, target)
        else
            self._anim = math.max(self._anim - speed * dt, target)
        end
    end
end

function UI.Toggle:draw(x, y, w, h)
    h = h or Theme.sizes.buttonHeight
    w = w or 200

    self._lastX = x
    self._lastY = y
    self._lastW = w
    self._lastH = h

    local toggleW = 36
    local toggleH = 18
    local toggleR = toggleH / 2

    local toggleX = x
    local toggleY = y + math.floor((h - toggleH) / 2)

    -- track
    local offColor = Theme.colors.scrollbar
    local onColor = Theme.colors.primary
    local trackColor = {
        offColor[1] + (onColor[1] - offColor[1]) * self._anim,
        offColor[2] + (onColor[2] - offColor[2]) * self._anim,
        offColor[3] + (onColor[3] - offColor[3]) * self._anim,
    }
    if self.disabled then
        trackColor = Theme.colors.tabInactive
    end
    setColorSafe(trackColor)
    drawRoundedRect("fill", toggleX, toggleY, toggleW, toggleH, toggleR)

    -- thumb circle
    local thumbR = (toggleH - 4) / 2
    local thumbMinX = toggleX + thumbR + 2
    local thumbMaxX = toggleX + toggleW - thumbR - 2
    local thumbCX = thumbMinX + (thumbMaxX - thumbMinX) * self._anim
    local thumbCY = toggleY + toggleH / 2

    if self.disabled then
        setColorSafe(Theme.colors.textDim)
    else
        love.graphics.setColor(1, 1, 1, 1)
    end
    love.graphics.circle("fill", thumbCX, thumbCY, thumbR)

    -- label
    if self.label then
        local font = FontCache.get(self.fontSize)
        love.graphics.setFont(font)
        if self.disabled then
            setColorSafe(Theme.colors.textDim)
        else
            setColorSafe(Theme.colors.text)
        end
        local textH = font:getHeight()
        local textY = y + math.floor((h - textH) / 2)
        love.graphics.print(self.label, toggleX + toggleW + Theme.spacing.md, textY)
    end
end

function UI.Toggle:mousepressed(mx, my, button)
    if button ~= 1 or self.disabled then return false end
    if pointInRect(mx, my, self._lastX, self._lastY, self._lastW, self._lastH) then
        self.value = not self.value
        if self.onChange then
            self.onChange(self.value)
        end
        return true
    end
    return false
end

function UI.Toggle:setValue(v)
    self.value = v
end


-- =========================================================================
-- SCROLLCONTAINER
-- =========================================================================

UI.ScrollContainer = {}
UI.ScrollContainer.__index = UI.ScrollContainer

function UI.ScrollContainer.new(opts)
    opts = opts or {}
    local self = setmetatable({}, UI.ScrollContainer)
    self.contentHeight = opts.contentHeight or 0
    self.scrollY = 0
    self.scrollSpeed = opts.scrollSpeed or 40
    self.showScrollbar = opts.showScrollbar ~= false
    -- internal
    self._lastX = 0
    self._lastY = 0
    self._lastW = 0
    self._lastH = 0
    self._scrollbarDragging = false
    self._scrollbarDragOffset = 0
    self._thumbHovered = false
    return self
end

function UI.ScrollContainer:_maxScroll(viewH)
    return math.max(0, self.contentHeight - viewH)
end

function UI.ScrollContainer:_scrollbarGeometry(x, y, w, h)
    local sbW = Theme.sizes.scrollbarWidth
    local sbX = x + w - sbW
    local sbY = y
    local sbH = h

    if self.contentHeight <= h or self.contentHeight <= 0 then
        return sbX, sbY, sbW, sbH, sbY, sbH  -- thumb = full height (hidden effectively)
    end

    local ratio = h / self.contentHeight
    local thumbH = math.max(20, ratio * sbH)
    local maxScroll = self:_maxScroll(h)
    local scrollRatio = maxScroll > 0 and (self.scrollY / maxScroll) or 0
    local thumbY = sbY + scrollRatio * (sbH - thumbH)

    return sbX, sbY, sbW, sbH, thumbY, thumbH
end

function UI.ScrollContainer:beginDraw(x, y, w, h)
    self._lastX = x
    self._lastY = y
    self._lastW = w
    self._lastH = h

    -- clamp scroll
    self.scrollY = clamp(self.scrollY, 0, self:_maxScroll(h))

    love.graphics.setScissor(x, y, w, h)
    love.graphics.push()
    love.graphics.translate(x, y - self.scrollY)
end

function UI.ScrollContainer:endDraw()
    love.graphics.pop()
    love.graphics.setScissor()

    -- draw scrollbar
    local x, y, w, h = self._lastX, self._lastY, self._lastW, self._lastH
    if self.showScrollbar and self.contentHeight > h then
        local sbX, sbY, sbW, sbH, thumbY, thumbH = self:_scrollbarGeometry(x, y, w, h)

        -- scrollbar track
        setColorSafe(Theme.colors.scrollbar)
        love.graphics.rectangle("fill", sbX, sbY, sbW, sbH)

        -- scrollbar thumb
        local mx, my = love.mouse.getPosition()
        local thumbHovered = pointInRect(mx, my, sbX, thumbY, sbW, thumbH)
        if thumbHovered or self._scrollbarDragging then
            setColorSafe(Theme.colors.scrollbarThumbHover)
        else
            setColorSafe(Theme.colors.scrollbarThumb)
        end
        drawRoundedRect("fill", sbX + 1, thumbY, sbW - 2, thumbH, (sbW - 2) / 2)
    end
end

function UI.ScrollContainer:getContentOffset()
    return -self.scrollY
end

function UI.ScrollContainer:wheelmoved(wx, wy)
    local mx, my = love.mouse.getPosition()
    if not pointInRect(mx, my, self._lastX, self._lastY, self._lastW, self._lastH) then
        return false
    end
    -- Note: love passes (x, y) - we only care about vertical
    -- This is called from love.wheelmoved which gets (x, y) args
    local scrollAmount = wy
    if type(scrollAmount) ~= "number" then scrollAmount = 0 end
    self.scrollY = self.scrollY - scrollAmount * self.scrollSpeed
    self.scrollY = clamp(self.scrollY, 0, self:_maxScroll(self._lastH))
    return true
end

function UI.ScrollContainer:mousepressed(mx, my, button)
    if button ~= 1 then return false end
    if not pointInRect(mx, my, self._lastX, self._lastY, self._lastW, self._lastH) then
        return false
    end

    -- check scrollbar thumb
    if self.showScrollbar and self.contentHeight > self._lastH then
        local sbX, sbY, sbW, sbH, thumbY, thumbH = self:_scrollbarGeometry(
            self._lastX, self._lastY, self._lastW, self._lastH)
        if pointInRect(mx, my, sbX, thumbY, sbW, thumbH) then
            self._scrollbarDragging = true
            self._scrollbarDragOffset = my - thumbY
            return true
        end
        -- click on track (jump)
        if pointInRect(mx, my, sbX, sbY, sbW, sbH) then
            local ratio = (my - sbY - thumbH / 2) / (sbH - thumbH)
            ratio = clamp(ratio, 0, 1)
            self.scrollY = ratio * self:_maxScroll(self._lastH)
            return true
        end
    end

    return false
end

function UI.ScrollContainer:mousereleased(mx, my, button)
    if button ~= 1 then return false end
    if self._scrollbarDragging then
        self._scrollbarDragging = false
        return true
    end
    return false
end

function UI.ScrollContainer:mousemoved(mx, my)
    if self._scrollbarDragging then
        local _, sbY, _, sbH, _, thumbH = self:_scrollbarGeometry(
            self._lastX, self._lastY, self._lastW, self._lastH)
        local trackSpace = sbH - thumbH
        if trackSpace > 0 then
            local ratio = (my - self._scrollbarDragOffset - sbY) / trackSpace
            ratio = clamp(ratio, 0, 1)
            self.scrollY = ratio * self:_maxScroll(self._lastH)
        end
        return true
    end
    return false
end

function UI.ScrollContainer:scrollToTop()
    self.scrollY = 0
end

function UI.ScrollContainer:scrollToBottom()
    self.scrollY = self:_maxScroll(self._lastH)
end

function UI.ScrollContainer:setContentHeight(h)
    self.contentHeight = h or 0
end


-- =========================================================================
-- LIST
-- =========================================================================

UI.List = {}
UI.List.__index = UI.List

function UI.List.new(opts)
    opts = opts or {}
    local self = setmetatable({}, UI.List)
    self.items = opts.items or {}   -- array of {text=string, id=any, ...}
    self.selectedIndex = opts.selectedIndex or nil
    self.onSelect = opts.onSelect or nil
    self.itemHeight = opts.itemHeight or Theme.sizes.listItemHeight
    self.fontSize = opts.fontSize or 13
    self.showAlternatingRows = opts.showAlternatingRows ~= false
    -- scroll container
    self._scroll = UI.ScrollContainer.new({
        contentHeight = #self.items * (opts.itemHeight or Theme.sizes.listItemHeight),
    })
    self._lastX = 0
    self._lastY = 0
    self._lastW = 0
    self._lastH = 0
    return self
end

function UI.List:setItems(items)
    self.items = items or {}
    self._scroll:setContentHeight(#self.items * self.itemHeight)
    if self.selectedIndex and self.selectedIndex > #self.items then
        self.selectedIndex = nil
    end
end

function UI.List:draw(x, y, w, h)
    w = w or 200
    h = h or 200

    self._lastX = x
    self._lastY = y
    self._lastW = w
    self._lastH = h

    self._scroll:setContentHeight(#self.items * self.itemHeight)

    local font = FontCache.get(self.fontSize)
    love.graphics.setFont(font)
    local textH = font:getHeight()
    local mx, my = love.mouse.getPosition()
    local pad = Theme.spacing.md

    -- scrollbar width adjustment
    local contentW = w
    if self._scroll.contentHeight > h then
        contentW = w - Theme.sizes.scrollbarWidth
    end

    self._scroll:beginDraw(x, y, w, h)

    for i, item in ipairs(self.items) do
        local iy = (i - 1) * self.itemHeight
        local isSelected = (i == self.selectedIndex)

        -- only draw visible items
        if iy + self.itemHeight > self._scroll.scrollY - self.itemHeight
            and iy < self._scroll.scrollY + h + self.itemHeight then

            -- convert item y to screen coords for hover check
            local screenY = y + iy - self._scroll.scrollY
            local isHovered = pointInRect(mx, my, x, screenY, contentW, self.itemHeight)

            -- row background
            if isSelected then
                setColorSafe(Theme.colors.listItemSelected)
                love.graphics.rectangle("fill", 0, iy, contentW, self.itemHeight)
            elseif isHovered then
                setColorSafe(Theme.colors.listItemHover)
                love.graphics.rectangle("fill", 0, iy, contentW, self.itemHeight)
            elseif self.showAlternatingRows and i % 2 == 0 then
                setColorSafe(Theme.colors.listItemAlt)
                love.graphics.rectangle("fill", 0, iy, contentW, self.itemHeight)
            end

            -- text
            if isSelected then
                setColorSafe(Theme.colors.text)
            else
                setColorSafe(Theme.colors.text)
            end
            local label = item.text or tostring(item.id or item)
            local textY = iy + math.floor((self.itemHeight - textH) / 2)
            love.graphics.print(label, pad, textY)
        end
    end

    self._scroll:endDraw()
end

function UI.List:mousepressed(mx, my, button)
    if button ~= 1 then return false end
    if not pointInRect(mx, my, self._lastX, self._lastY, self._lastW, self._lastH) then
        return false
    end

    -- check scrollbar first
    if self._scroll:mousepressed(mx, my, button) then
        return true
    end

    -- figure out which item was clicked
    local relY = my - self._lastY + self._scroll.scrollY
    local idx = math.floor(relY / self.itemHeight) + 1
    if idx >= 1 and idx <= #self.items then
        self.selectedIndex = idx
        if self.onSelect then
            self.onSelect(idx, self.items[idx])
        end
        return true
    end

    return false
end

function UI.List:mousereleased(mx, my, button)
    return self._scroll:mousereleased(mx, my, button)
end

function UI.List:mousemoved(mx, my)
    return self._scroll:mousemoved(mx, my)
end

function UI.List:wheelmoved(wx, wy)
    return self._scroll:wheelmoved(wx, wy)
end

function UI.List:getSelected()
    if self.selectedIndex and self.items[self.selectedIndex] then
        return self.selectedIndex, self.items[self.selectedIndex]
    end
    return nil, nil
end

function UI.List:setSelectedIndex(idx)
    if idx and idx >= 1 and idx <= #self.items then
        self.selectedIndex = idx
    else
        self.selectedIndex = nil
    end
end


-- =========================================================================
-- TOOLBAR
-- =========================================================================

UI.Toolbar = {}
UI.Toolbar.__index = UI.Toolbar

function UI.Toolbar.new(opts)
    opts = opts or {}
    local self = setmetatable({}, UI.Toolbar)
    self.items = {}  -- array of Button widgets or "separator"
    self.bgColor = opts.bgColor or Theme.colors.panelHeader
    self.height = opts.height or Theme.sizes.toolbarHeight
    self.padding = opts.padding or Theme.spacing.sm
    self.spacing = opts.spacing or Theme.spacing.sm

    -- build items from opts
    if opts.items then
        for _, item in ipairs(opts.items) do
            if item == "separator" or item.type == "separator" then
                table.insert(self.items, {type = "separator"})
            else
                local btn = UI.Button.new({
                    text = item.text or "",
                    icon = item.icon,
                    variant = item.variant or "ghost",
                    onClick = item.onClick,
                    disabled = item.disabled,
                    fontSize = item.fontSize or 12,
                })
                table.insert(self.items, {type = "button", widget = btn, width = item.width})
            end
        end
    end

    return self
end

function UI.Toolbar:draw(x, y, w, h)
    h = h or self.height
    w = w or 400

    -- background
    setColorSafe(self.bgColor)
    love.graphics.rectangle("fill", x, y, w, h)

    -- bottom border
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", x, y + h - 1, w, 1)

    -- items
    local ix = x + self.padding
    local iy = y + math.floor((h - Theme.sizes.buttonHeight) / 2)
    local btnH = Theme.sizes.buttonHeight

    for _, item in ipairs(self.items) do
        if item.type == "separator" then
            local sepX = ix + self.spacing
            setColorSafe(Theme.colors.panelBorder)
            love.graphics.rectangle("fill", sepX, y + 4, 1, h - 8)
            ix = sepX + 1 + self.spacing
        elseif item.type == "button" and item.widget then
            local font = FontCache.get(item.widget.fontSize)
            local btnW = item.width or (font:getWidth(item.widget.text) + Theme.spacing.xl * 2)
            if item.widget.icon then
                btnW = btnW + font:getHeight() + Theme.spacing.sm
            end
            btnW = math.max(btnW, btnH)
            item.widget:draw(ix, iy, btnW, btnH)
            ix = ix + btnW + self.spacing
        end
    end
end

function UI.Toolbar:mousepressed(mx, my, button)
    for _, item in ipairs(self.items) do
        if item.type == "button" and item.widget then
            if item.widget:mousepressed(mx, my, button) then
                return true
            end
        end
    end
    return false
end

function UI.Toolbar:mousereleased(mx, my, button)
    for _, item in ipairs(self.items) do
        if item.type == "button" and item.widget then
            if item.widget:mousereleased(mx, my, button) then
                return true
            end
        end
    end
    return false
end

function UI.Toolbar:addButton(opts)
    local btn = UI.Button.new({
        text = opts.text or "",
        icon = opts.icon,
        variant = opts.variant or "ghost",
        onClick = opts.onClick,
        disabled = opts.disabled,
        fontSize = opts.fontSize or 12,
    })
    table.insert(self.items, {type = "button", widget = btn, width = opts.width})
    return btn
end

function UI.Toolbar:addSeparator()
    table.insert(self.items, {type = "separator"})
end


-- =========================================================================
-- MODAL
-- =========================================================================

UI.Modal = {}
UI.Modal.__index = UI.Modal

function UI.Modal.new(opts)
    opts = opts or {}
    local self = setmetatable({}, UI.Modal)
    self.title = opts.title or "Dialog"
    self.width = opts.width or 400
    self.height = opts.height or 250
    self.visible = opts.visible or false
    self.onOk = opts.onOk or nil
    self.onCancel = opts.onCancel or nil
    self.showOk = opts.showOk ~= false
    self.showCancel = opts.showCancel ~= false
    self.okText = opts.okText or "OK"
    self.cancelText = opts.cancelText or "Cancel"
    self.drawContent = opts.drawContent or nil   -- function(self, cx, cy, cw, ch)
    self.fontSize = opts.fontSize or 13
    self.titleFontSize = opts.titleFontSize or 15
    self.message = opts.message or nil

    -- buttons
    self._okBtn = UI.Button.new({
        text = self.okText,
        variant = "primary",
        onClick = function()
            if self.onOk then self.onOk() end
            self:hide()
        end,
    })
    self._cancelBtn = UI.Button.new({
        text = self.cancelText,
        variant = "secondary",
        onClick = function()
            if self.onCancel then self.onCancel() end
            self:hide()
        end,
    })

    return self
end

function UI.Modal:show()
    self.visible = true
    UI.setModal(self)
end

function UI.Modal:hide()
    self.visible = false
    if UI.getModal() == self then
        UI.clearModal()
    end
end

function UI.Modal:draw()
    if not self.visible then return end

    local screenW, screenH = love.graphics.getDimensions()

    -- overlay
    setColorSafe(Theme.colors.overlay)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- dialog box
    local dw = math.min(self.width, screenW - 40)
    local dh = math.min(self.height, screenH - 40)
    local dx = math.floor((screenW - dw) / 2)
    local dy = math.floor((screenH - dh) / 2)

    -- shadow
    setColorSafe(Theme.colors.shadow)
    drawRoundedRect("fill", dx + 4, dy + 4, dw, dh, Theme.radius.lg)

    -- background
    setColorSafe(Theme.colors.panel)
    drawRoundedRect("fill", dx, dy, dw, dh, Theme.radius.lg)

    -- border
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", dx + 0.5, dy + 0.5, dw - 1, dh - 1, Theme.radius.lg)

    -- title bar
    local titleH = 40
    setColorSafe(Theme.colors.panelHeader)
    -- top of dialog with rounded corners
    drawRoundedRect("fill", dx + 1, dy + 1, dw - 2, titleH, Theme.radius.lg)
    -- bottom half of title (square corners)
    love.graphics.rectangle("fill", dx + 1, dy + titleH - Theme.radius.lg, dw - 2, Theme.radius.lg)

    -- title divider
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", dx, dy + titleH, dw, 1)

    -- title text
    local titleFont = FontCache.get(self.titleFontSize)
    love.graphics.setFont(titleFont)
    setColorSafe(Theme.colors.text)
    local titleTextH = titleFont:getHeight()
    love.graphics.print(self.title, dx + Theme.spacing.lg, dy + math.floor((titleH - titleTextH) / 2))

    -- content area
    local btnAreaH = 48
    local contentX = dx + Theme.spacing.xl
    local contentY = dy + titleH + Theme.spacing.lg
    local contentW = dw - Theme.spacing.xl * 2
    local contentH = dh - titleH - btnAreaH - Theme.spacing.lg

    if self.drawContent then
        self.drawContent(self, contentX, contentY, contentW, contentH)
    elseif self.message then
        local font = FontCache.get(self.fontSize)
        love.graphics.setFont(font)
        setColorSafe(Theme.colors.text)
        love.graphics.printf(self.message, contentX, contentY, contentW, "left")
    end

    -- buttons
    local btnY = dy + dh - btnAreaH + Theme.spacing.md
    local btnW = 90
    local btnH = Theme.sizes.buttonHeight
    local btnSpacing = Theme.spacing.md

    local totalBtnW = 0
    if self.showOk then totalBtnW = totalBtnW + btnW end
    if self.showCancel then totalBtnW = totalBtnW + btnW end
    if self.showOk and self.showCancel then totalBtnW = totalBtnW + btnSpacing end

    local btnX = dx + dw - Theme.spacing.xl - totalBtnW

    if self.showCancel then
        self._cancelBtn:draw(btnX, btnY, btnW, btnH)
        btnX = btnX + btnW + btnSpacing
    end
    if self.showOk then
        self._okBtn:draw(btnX, btnY, btnW, btnH)
    end
end

function UI.Modal:mousepressed(mx, my, button)
    if not self.visible then return false end
    -- modal captures all input
    if self.showCancel then
        self._cancelBtn:mousepressed(mx, my, button)
    end
    if self.showOk then
        self._okBtn:mousepressed(mx, my, button)
    end
    return true  -- always consume
end

function UI.Modal:mousereleased(mx, my, button)
    if not self.visible then return false end
    if self.showCancel then
        self._cancelBtn:mousereleased(mx, my, button)
    end
    if self.showOk then
        self._okBtn:mousereleased(mx, my, button)
    end
    return true
end

function UI.Modal:keypressed(key)
    if not self.visible then return false end
    if key == "return" or key == "kpenter" then
        if self.onOk then self.onOk() end
        self:hide()
        return true
    elseif key == "escape" then
        if self.onCancel then self.onCancel() end
        self:hide()
        return true
    end
    return true  -- consume all keypresses
end


-- =========================================================================
-- SPLITPANE
-- =========================================================================

UI.SplitPane = {}
UI.SplitPane.__index = UI.SplitPane

function UI.SplitPane.new(opts)
    opts = opts or {}
    local self = setmetatable({}, UI.SplitPane)
    self.orientation = opts.orientation or "horizontal"  -- horizontal = left|right, vertical = top|bottom
    self.splitPos = opts.splitPos or 0.5   -- 0..1 ratio, or absolute pixels if > 1
    self.minFirst = opts.minFirst or 50
    self.minSecond = opts.minSecond or 50
    self.dividerSize = opts.dividerSize or 4
    self.dividerColor = opts.dividerColor or Theme.colors.panelBorder
    self.dividerHoverColor = opts.dividerHoverColor or Theme.colors.primary
    self.drawFirst = opts.drawFirst or nil   -- function(x, y, w, h)
    self.drawSecond = opts.drawSecond or nil -- function(x, y, w, h)
    -- internal
    self._dragging = false
    self._hovered = false
    self._lastX = 0
    self._lastY = 0
    self._lastW = 0
    self._lastH = 0
    return self
end

function UI.SplitPane:_getSplitPixels(totalSize)
    if self.splitPos > 1 then
        return clamp(self.splitPos, self.minFirst, totalSize - self.minSecond - self.dividerSize)
    else
        local px = self.splitPos * totalSize
        return clamp(px, self.minFirst, totalSize - self.minSecond - self.dividerSize)
    end
end

function UI.SplitPane:getAreas(x, y, w, h)
    if self.orientation == "horizontal" then
        local split = self:_getSplitPixels(w)
        local x1, y1, w1, h1 = x, y, split, h
        local divX = x + split
        local x2 = divX + self.dividerSize
        local w2 = w - split - self.dividerSize
        if w2 < 0 then w2 = 0 end
        return x1, y1, w1, h1, x2, y1, w2, h1, divX, y, self.dividerSize, h
    else
        local split = self:_getSplitPixels(h)
        local x1, y1, w1, h1 = x, y, w, split
        local divY = y + split
        local y2 = divY + self.dividerSize
        local h2 = h - split - self.dividerSize
        if h2 < 0 then h2 = 0 end
        return x1, y1, w1, h1, x1, y2, w1, h2, x, divY, w, self.dividerSize
    end
end

function UI.SplitPane:draw(x, y, w, h)
    w = w or 400
    h = h or 300

    self._lastX = x
    self._lastY = y
    self._lastW = w
    self._lastH = h

    local x1, y1, w1, h1, x2, y2, w2, h2, dx, dy, dw, dh = self:getAreas(x, y, w, h)

    -- draw first panel
    if self.drawFirst and w1 > 0 and h1 > 0 then
        love.graphics.setScissor(x1, y1, w1, h1)
        self.drawFirst(x1, y1, w1, h1)
        love.graphics.setScissor()
    end

    -- draw second panel
    if self.drawSecond and w2 > 0 and h2 > 0 then
        love.graphics.setScissor(x2, y2, w2, h2)
        self.drawSecond(x2, y2, w2, h2)
        love.graphics.setScissor()
    end

    -- divider
    local mx, my = love.mouse.getPosition()
    self._hovered = pointInRect(mx, my, dx, dy, dw, dh)

    if self._dragging or self._hovered then
        setColorSafe(self.dividerHoverColor)
    else
        setColorSafe(self.dividerColor)
    end
    love.graphics.rectangle("fill", dx, dy, dw, dh)

    -- set cursor hint
    -- (LOVE2D does not easily support cursor changes without creating cursor objects,
    --  but the visual divider highlight serves the same purpose)
end

function UI.SplitPane:mousepressed(mx, my, button)
    if button ~= 1 then return false end
    local _, _, _, _, _, _, _, _, dx, dy, dw, dh = self:getAreas(
        self._lastX, self._lastY, self._lastW, self._lastH)
    if pointInRect(mx, my, dx, dy, dw, dh) then
        self._dragging = true
        return true
    end
    return false
end

function UI.SplitPane:mousereleased(mx, my, button)
    if button ~= 1 then return false end
    if self._dragging then
        self._dragging = false
        return true
    end
    return false
end

function UI.SplitPane:mousemoved(mx, my)
    if not self._dragging then return false end

    if self.orientation == "horizontal" then
        local relX = mx - self._lastX
        local totalW = self._lastW
        relX = clamp(relX, self.minFirst, totalW - self.minSecond - self.dividerSize)
        if self.splitPos > 1 then
            self.splitPos = relX
        else
            self.splitPos = relX / totalW
        end
    else
        local relY = my - self._lastY
        local totalH = self._lastH
        relY = clamp(relY, self.minFirst, totalH - self.minSecond - self.dividerSize)
        if self.splitPos > 1 then
            self.splitPos = relY
        else
            self.splitPos = relY / totalH
        end
    end
    return true
end

function UI.SplitPane:isDragging()
    return self._dragging
end


-- =========================================================================
-- Global event dispatch helpers
-- =========================================================================

--- Call this from love.update(dt) to update widgets that need it
function UI.update(dt)
    -- currently only focused text input needs per-frame update
    if _focusedWidget and _focusedWidget.update then
        _focusedWidget:update(dt)
    end
end

--- Call from love.mousepressed: dispatches to modal if active
function UI.globalMousepressed(mx, my, button)
    if _activeModal then
        return _activeModal:mousepressed(mx, my, button)
    end
    return false
end

--- Call from love.mousereleased
function UI.globalMousereleased(mx, my, button)
    if _activeModal then
        return _activeModal:mousereleased(mx, my, button)
    end
    return false
end

--- Call from love.keypressed
function UI.globalKeypressed(key)
    if _activeModal then
        return _activeModal:keypressed(key)
    end
    if _focusedWidget and _focusedWidget.keypressed then
        return _focusedWidget:keypressed(key)
    end
    return false
end

--- Call from love.textinput
function UI.globalTextinput(t)
    if _activeModal then return true end
    if _focusedWidget and _focusedWidget.textinput then
        return _focusedWidget:textinput(t)
    end
    return false
end

--- Call from love.wheelmoved
function UI.globalWheelmoved(wx, wy)
    if _activeModal then return true end
    return false
end

--- Draw modal overlay (call last in love.draw)
function UI.drawModal()
    if _activeModal then
        _activeModal:draw()
    end
end


return UI
