-- ==========================================================================
-- Extended Editor Widgets for Tavern Quest Editor Suite
-- Builds on core.ui with editor-specific widgets:
--   NumberInput, SearchBar, TagPicker, DropdownSelect, ColorPicker,
--   TreeView, IconPicker, PortraitPicker, PropertyGrid
-- ==========================================================================

local Theme = require("core.theme")
local FontCache = require("core.fontcache")
local UI = require("core.ui")

local W = {}

-- =========================================================================
-- Local helpers (mirrors from core.ui kept local for performance)
-- =========================================================================

local function pointInRect(px, py, x, y, w, h)
    return px >= x and px < x + w and py >= y and py < y + h
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function setColor(c)
    if c and type(c) == "table" then
        love.graphics.setColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
    end
end

local function roundRect(mode, x, y, w, h, r)
    r = r or 0
    if w <= 0 or h <= 0 then return end
    if r <= 0 then
        love.graphics.rectangle(mode, x, y, w, h)
    else
        love.graphics.rectangle(mode, x, y, w, h, r, r)
    end
end

local function hexToRGB(hex)
    hex = hex:gsub("#", "")
    if #hex == 6 then
        local r = tonumber(hex:sub(1, 2), 16)
        local g = tonumber(hex:sub(3, 4), 16)
        local b = tonumber(hex:sub(5, 6), 16)
        if r and g and b then
            return r / 255, g / 255, b / 255
        end
    end
    return nil, nil, nil
end

local function rgbToHex(r, g, b)
    return string.format("#%02X%02X%02X",
        clamp(math.floor(r * 255 + 0.5), 0, 255),
        clamp(math.floor(g * 255 + 0.5), 0, 255),
        clamp(math.floor(b * 255 + 0.5), 0, 255))
end

-- =========================================================================
-- NUMBERINPUT
-- =========================================================================

W.NumberInput = {}
W.NumberInput.__index = W.NumberInput

function W.NumberInput.new(opts)
    opts = opts or {}
    local self = setmetatable({}, W.NumberInput)
    self.value = opts.value or 0
    self.min = opts.min or nil
    self.max = opts.max or nil
    self.step = opts.step or 1
    self.decimals = opts.decimals or nil
    self.onChange = opts.onChange or nil
    self.fontSize = opts.fontSize or 13
    self.showSlider = opts.showSlider or false
    self.showButtons = opts.showButtons ~= false
    self.disabled = opts.disabled or false
    self.label = opts.label or nil
    -- internal widgets
    self._input = UI.TextInput.new({
        text = self:_formatValue(self.value),
        fontSize = self.fontSize,
        onChange = function(text)
            self:_onTextChange(text)
        end,
        onSubmit = function(text)
            self:_commitText(text)
        end,
    })
    self._slider = nil
    if self.showSlider and self.min and self.max then
        self._slider = UI.Slider.new({
            min = self.min,
            max = self.max,
            value = self.value,
            step = self.step,
            onChange = function(v)
                self:setValue(v, true)
            end,
        })
    end
    -- button state
    self._decHovered = false
    self._incHovered = false
    self._decPressed = false
    self._incPressed = false
    self._lastX = 0
    self._lastY = 0
    self._lastW = 0
    self._lastH = 0
    self._repeatTimer = 0
    self._repeatDir = 0
    self._repeatDelay = 0.4
    self._repeatRate = 0.08
    self._repeatAccum = 0
    return self
end

function W.NumberInput:_formatValue(v)
    if self.decimals then
        return string.format("%." .. self.decimals .. "f", v)
    elseif self.step and self.step >= 1 then
        return tostring(math.floor(v + 0.5))
    else
        local s = string.format("%.4f", v)
        s = s:gsub("%.?0+$", "")
        if s == "" or s == "-" then s = "0" end
        return s
    end
end

function W.NumberInput:_clampValue(v)
    if self.min then v = math.max(v, self.min) end
    if self.max then v = math.min(v, self.max) end
    return v
end

function W.NumberInput:_onTextChange(text)
    -- Allow partial entry like "-", ".", "-." without forcing a number
end

function W.NumberInput:_commitText(text)
    local num = tonumber(text)
    if num then
        self:setValue(num)
    else
        self._input:setText(self:_formatValue(self.value))
    end
end

function W.NumberInput:setValue(v, fromSlider)
    v = self:_clampValue(v)
    if v ~= self.value then
        self.value = v
        self._input:setText(self:_formatValue(v))
        if self._slider and not fromSlider then
            self._slider:setValue(v)
        end
        if self.onChange then
            self.onChange(v)
        end
    end
end

function W.NumberInput:_increment()
    self:setValue(self.value + self.step)
end

function W.NumberInput:_decrement()
    self:setValue(self.value - self.step)
end

function W.NumberInput:update(dt)
    self._input:update(dt)
    if self._slider then
        -- Slider has no update currently but future-proof
    end
    -- Button repeat
    if self._repeatDir ~= 0 then
        self._repeatTimer = self._repeatTimer + dt
        if self._repeatTimer >= self._repeatDelay then
            self._repeatAccum = self._repeatAccum + dt
            while self._repeatAccum >= self._repeatRate do
                self._repeatAccum = self._repeatAccum - self._repeatRate
                if self._repeatDir < 0 then
                    self:_decrement()
                else
                    self:_increment()
                end
            end
        end
    end
end

function W.NumberInput:draw(x, y, w, h)
    w = w or 140
    h = h or Theme.sizes.inputHeight

    self._lastX = x
    self._lastY = y
    self._lastW = w
    self._lastH = h

    local btnW = self.showButtons and h or 0
    local inputW = w - btnW * 2
    local mx, my = love.mouse.getPosition()

    if self.showSlider and self._slider then
        -- Slider mode: input on top, slider below
        local sliderH = 20
        local inputH = h
        self._input:draw(x + btnW, y, inputW, inputH)

        if self.showButtons then
            -- Decrement button
            local decX = x
            self._decHovered = pointInRect(mx, my, decX, y, btnW, inputH) and not self.disabled
            if self._decPressed then
                setColor(Theme.colors.primaryDark)
            elseif self._decHovered then
                setColor(Theme.colors.primaryHover)
            else
                setColor(Theme.colors.bgLight)
            end
            roundRect("fill", decX, y, btnW, inputH, Theme.radius.sm)
            setColor(Theme.colors.inputBorder)
            roundRect("line", decX + 0.5, y + 0.5, btnW - 1, inputH - 1, Theme.radius.sm)
            local font = FontCache.get(self.fontSize)
            love.graphics.setFont(font)
            setColor(self.disabled and Theme.colors.textDim or Theme.colors.text)
            local tw = font:getWidth("-")
            love.graphics.print("-", decX + math.floor((btnW - tw) / 2), y + math.floor((inputH - font:getHeight()) / 2))

            -- Increment button
            local incX = x + btnW + inputW
            self._incHovered = pointInRect(mx, my, incX, y, btnW, inputH) and not self.disabled
            if self._incPressed then
                setColor(Theme.colors.primaryDark)
            elseif self._incHovered then
                setColor(Theme.colors.primaryHover)
            else
                setColor(Theme.colors.bgLight)
            end
            roundRect("fill", incX, y, btnW, inputH, Theme.radius.sm)
            setColor(Theme.colors.inputBorder)
            roundRect("line", incX + 0.5, y + 0.5, btnW - 1, inputH - 1, Theme.radius.sm)
            setColor(self.disabled and Theme.colors.textDim or Theme.colors.text)
            tw = font:getWidth("+")
            love.graphics.print("+", incX + math.floor((btnW - tw) / 2), y + math.floor((inputH - font:getHeight()) / 2))
        end

        self._slider:draw(x, y + h + 2, w, sliderH)
    else
        -- Standard mode: [- input +]
        self._input:draw(x + btnW, y, inputW, h)

        if self.showButtons then
            local font = FontCache.get(self.fontSize)
            love.graphics.setFont(font)

            -- Decrement
            local decX = x
            self._decHovered = pointInRect(mx, my, decX, y, btnW, h) and not self.disabled
            if self._decPressed then
                setColor(Theme.colors.primaryDark)
            elseif self._decHovered then
                setColor(Theme.colors.primaryHover)
            else
                setColor(Theme.colors.bgLight)
            end
            roundRect("fill", decX, y, btnW, h, Theme.radius.sm)
            setColor(Theme.colors.inputBorder)
            roundRect("line", decX + 0.5, y + 0.5, btnW - 1, h - 1, Theme.radius.sm)
            setColor(self.disabled and Theme.colors.textDim or Theme.colors.text)
            local tw = font:getWidth("-")
            love.graphics.print("-", decX + math.floor((btnW - tw) / 2), y + math.floor((h - font:getHeight()) / 2))

            -- Increment
            local incX = x + btnW + inputW
            self._incHovered = pointInRect(mx, my, incX, y, btnW, h) and not self.disabled
            if self._incPressed then
                setColor(Theme.colors.primaryDark)
            elseif self._incHovered then
                setColor(Theme.colors.primaryHover)
            else
                setColor(Theme.colors.bgLight)
            end
            roundRect("fill", incX, y, btnW, h, Theme.radius.sm)
            setColor(Theme.colors.inputBorder)
            roundRect("line", incX + 0.5, y + 0.5, btnW - 1, h - 1, Theme.radius.sm)
            setColor(self.disabled and Theme.colors.textDim or Theme.colors.text)
            tw = font:getWidth("+")
            love.graphics.print("+", incX + math.floor((btnW - tw) / 2), y + math.floor((h - font:getHeight()) / 2))
        end
    end
end

function W.NumberInput:mousepressed(mx, my, button)
    if button ~= 1 or self.disabled then return false end
    local x, y, w, h = self._lastX, self._lastY, self._lastW, self._lastH
    local btnW = self.showButtons and h or 0
    local inputW = w - btnW * 2

    -- Check slider
    if self.showSlider and self._slider then
        if self._slider:mousepressed(mx, my, button) then return true end
    end

    -- Decrement button
    if self.showButtons and pointInRect(mx, my, x, y, btnW, h) then
        self._decPressed = true
        self:_decrement()
        self._repeatDir = -1
        self._repeatTimer = 0
        self._repeatAccum = 0
        return true
    end

    -- Increment button
    if self.showButtons and pointInRect(mx, my, x + btnW + inputW, y, btnW, h) then
        self._incPressed = true
        self:_increment()
        self._repeatDir = 1
        self._repeatTimer = 0
        self._repeatAccum = 0
        return true
    end

    -- Text input
    if self._input:mousepressed(mx, my, button) then return true end

    return false
end

function W.NumberInput:mousereleased(mx, my, button)
    if button ~= 1 then return false end
    local consumed = false
    if self._decPressed then
        self._decPressed = false
        self._repeatDir = 0
        consumed = true
    end
    if self._incPressed then
        self._incPressed = false
        self._repeatDir = 0
        consumed = true
    end
    if self._slider then
        if self._slider:mousereleased(mx, my, button) then consumed = true end
    end
    return consumed
end

function W.NumberInput:mousemoved(mx, my)
    if self._slider then
        if self._slider:mousemoved(mx, my) then return true end
    end
    if self._input.mousemoved then
        if self._input:mousemoved(mx, my) then return true end
    end
    return false
end

function W.NumberInput:keypressed(key)
    if self._input:keypressed(key) then
        if key == "return" or key == "kpenter" then
            self:_commitText(self._input:getText())
        end
        return true
    end
    return false
end

function W.NumberInput:textinput(t)
    -- Only allow numeric chars, minus, dot
    if t:match("^[%d%.%-]$") then
        return self._input:textinput(t)
    end
    return false
end

function W.NumberInput:wheelmoved(wx, wy)
    local mx, my = love.mouse.getPosition()
    if pointInRect(mx, my, self._lastX, self._lastY, self._lastW, self._lastH) then
        if wy > 0 then
            self:_increment()
        elseif wy < 0 then
            self:_decrement()
        end
        return true
    end
    return false
end


-- =========================================================================
-- SEARCHBAR
-- =========================================================================

W.SearchBar = {}
W.SearchBar.__index = W.SearchBar

function W.SearchBar.new(opts)
    opts = opts or {}
    local self = setmetatable({}, W.SearchBar)
    self.placeholder = opts.placeholder or "Search..."
    self.onSearch = opts.onSearch or nil
    self.debounceTime = opts.debounceTime or 0.2
    self.fontSize = opts.fontSize or 13
    -- internal
    self._input = UI.TextInput.new({
        placeholder = self.placeholder,
        fontSize = self.fontSize,
        onChange = function(text)
            self._debounceTimer = self.debounceTime
            self._pendingText = text
        end,
        onSubmit = function(text)
            self._debounceTimer = 0
            self._pendingText = nil
            if self.onSearch then self.onSearch(text) end
        end,
    })
    self._debounceTimer = 0
    self._pendingText = nil
    self._clearHovered = false
    self._lastX = 0
    self._lastY = 0
    self._lastW = 0
    self._lastH = 0
    return self
end

function W.SearchBar:update(dt)
    self._input:update(dt)
    if self._debounceTimer > 0 then
        self._debounceTimer = self._debounceTimer - dt
        if self._debounceTimer <= 0 then
            self._debounceTimer = 0
            if self._pendingText and self.onSearch then
                self.onSearch(self._pendingText)
            end
            self._pendingText = nil
        end
    end
end

function W.SearchBar:draw(x, y, w, h)
    w = w or 200
    h = h or Theme.sizes.inputHeight

    self._lastX = x
    self._lastY = y
    self._lastW = w
    self._lastH = h

    local iconSize = h
    local clearSize = h
    local hasText = #self._input.text > 0
    local inputW = w - iconSize - (hasText and clearSize or 0)

    -- Search icon area
    local font = FontCache.get(self.fontSize)
    love.graphics.setFont(font)
    setColor(Theme.colors.textDim)
    local iconGlyph = "?"
    local gw = font:getWidth(iconGlyph)
    love.graphics.print(iconGlyph, x + math.floor((iconSize - gw) / 2), y + math.floor((h - font:getHeight()) / 2))

    -- Text input
    self._input:draw(x + iconSize, y, inputW, h)

    -- Clear button
    if hasText then
        local cx = x + iconSize + inputW
        local mx, my = love.mouse.getPosition()
        self._clearHovered = pointInRect(mx, my, cx, y, clearSize, h)

        if self._clearHovered then
            setColor(Theme.colors.dangerHover)
        else
            setColor(Theme.colors.textDim)
        end
        local xGlyph = "X"
        local xw = font:getWidth(xGlyph)
        love.graphics.print(xGlyph, cx + math.floor((clearSize - xw) / 2), y + math.floor((h - font:getHeight()) / 2))
    end
end

function W.SearchBar:getText()
    return self._input.text
end

function W.SearchBar:setText(text)
    self._input:setText(text or "")
    self._debounceTimer = 0
    self._pendingText = nil
end

function W.SearchBar:clear()
    self:setText("")
    if self.onSearch then self.onSearch("") end
end

function W.SearchBar:mousepressed(mx, my, button)
    if button ~= 1 then return false end
    -- Clear button
    local hasText = #self._input.text > 0
    if hasText then
        local iconSize = self._lastH
        local inputW = self._lastW - iconSize - self._lastH
        local cx = self._lastX + iconSize + inputW
        if pointInRect(mx, my, cx, self._lastY, self._lastH, self._lastH) then
            self:clear()
            return true
        end
    end
    -- Adjust click position for the offset input
    return self._input:mousepressed(mx, my, button)
end

function W.SearchBar:mousereleased(mx, my, button)
    return false
end

function W.SearchBar:keypressed(key)
    if key == "escape" and #self._input.text > 0 then
        self:clear()
        return true
    end
    return self._input:keypressed(key)
end

function W.SearchBar:textinput(t)
    return self._input:textinput(t)
end

function W.SearchBar:mousemoved(mx, my)
    if self._input.mousemoved then
        return self._input:mousemoved(mx, my)
    end
    return false
end


-- =========================================================================
-- TAGPICKER
-- =========================================================================

W.TagPicker = {}
W.TagPicker.__index = W.TagPicker

function W.TagPicker.new(opts)
    opts = opts or {}
    local self = setmetatable({}, W.TagPicker)
    self.tags = {}
    if opts.tags then
        for _, t in ipairs(opts.tags) do
            self.tags[#self.tags + 1] = t
        end
    end
    self.suggestions = opts.suggestions or {}
    self.onChange = opts.onChange or nil
    self.fontSize = opts.fontSize or 12
    self.chipHeight = opts.chipHeight or 22
    self.maxTags = opts.maxTags or 50
    -- internal
    self._input = UI.TextInput.new({
        placeholder = "Add tag...",
        fontSize = self.fontSize,
        onSubmit = function(text)
            self:_addTag(text)
        end,
    })
    self._chipRects = {}  -- {x, y, w, h, closeX, tag}
    self._hoveredClose = nil
    self._showSuggestions = false
    self._filteredSuggestions = {}
    self._suggestHoveredIdx = nil
    self._lastX = 0
    self._lastY = 0
    self._lastW = 0
    self._lastH = 0
    self._contentHeight = 0
    return self
end

function W.TagPicker:_addTag(text)
    text = text and text:match("^%s*(.-)%s*$") or ""
    if #text == 0 then return end
    -- Check duplicates
    for _, t in ipairs(self.tags) do
        if t == text then
            self._input:setText("")
            return
        end
    end
    if #self.tags >= self.maxTags then return end
    self.tags[#self.tags + 1] = text
    self._input:setText("")
    self._showSuggestions = false
    if self.onChange then self.onChange(self.tags) end
end

function W.TagPicker:_removeTag(index)
    if index >= 1 and index <= #self.tags then
        table.remove(self.tags, index)
        if self.onChange then self.onChange(self.tags) end
    end
end

function W.TagPicker:_updateSuggestions()
    local text = self._input.text:lower()
    self._filteredSuggestions = {}
    if #text == 0 then
        self._showSuggestions = false
        return
    end
    for _, s in ipairs(self.suggestions) do
        -- Exclude already-added tags
        local isDup = false
        for _, t in ipairs(self.tags) do
            if t == s then isDup = true; break end
        end
        if not isDup and s:lower():find(text, 1, true) then
            self._filteredSuggestions[#self._filteredSuggestions + 1] = s
        end
    end
    self._showSuggestions = #self._filteredSuggestions > 0
end

-- Stable hash for chip color
local function tagColor(tag)
    local hash = 0
    for i = 1, #tag do
        hash = (hash * 31 + tag:byte(i)) % 360
    end
    -- HSL-ish -> RGB with fixed saturation/lightness
    local h = hash / 360
    local function hue2rgb(p, q, t)
        if t < 0 then t = t + 1 end
        if t > 1 then t = t - 1 end
        if t < 1/6 then return p + (q - p) * 6 * t end
        if t < 1/2 then return q end
        if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
        return p
    end
    local s, l = 0.5, 0.35
    local q = l + s - l * s
    local p = 2 * l - q
    return {hue2rgb(p, q, h + 1/3), hue2rgb(p, q, h), hue2rgb(p, q, h - 1/3)}
end

function W.TagPicker:update(dt)
    self._input:update(dt)
    self:_updateSuggestions()
end

function W.TagPicker:draw(x, y, w, h)
    w = w or 300
    h = h or 80

    self._lastX = x
    self._lastY = y
    self._lastW = w
    self._lastH = h

    local font = FontCache.get(self.fontSize)
    love.graphics.setFont(font)
    local pad = Theme.spacing.sm
    local chipPad = Theme.spacing.xs
    local chipH = self.chipHeight
    local closeW = 14
    local mx, my = love.mouse.getPosition()

    -- Background
    setColor(Theme.colors.input)
    roundRect("fill", x, y, w, h, Theme.radius.sm)
    setColor(Theme.colors.inputBorder)
    love.graphics.setLineWidth(1)
    roundRect("line", x + 0.5, y + 0.5, w - 1, h - 1, Theme.radius.sm)

    -- Scissor the chip area
    love.graphics.setScissor(x + 1, y + 1, w - 2, h - 2)

    -- Layout chips in flow
    self._chipRects = {}
    local cx = x + pad
    local cy = y + pad
    local maxX = x + w - pad

    for i, tag in ipairs(self.tags) do
        local tw = font:getWidth(tag) + pad * 2 + closeW + chipPad
        -- Wrap to next line
        if cx + tw > maxX and cx > x + pad then
            cx = x + pad
            cy = cy + chipH + chipPad
        end

        local col = tagColor(tag)
        setColor(col)
        roundRect("fill", cx, cy, tw, chipH, chipH / 2)

        -- Tag text
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(tag, cx + pad, cy + math.floor((chipH - font:getHeight()) / 2))

        -- Close button
        local closeX = cx + tw - closeW - 2
        local closeHovered = pointInRect(mx, my, closeX, cy, closeW, chipH)
        if closeHovered then
            love.graphics.setColor(1, 0.3, 0.3)
            self._hoveredClose = i
        else
            love.graphics.setColor(1, 1, 1, 0.7)
        end
        local xw = font:getWidth("x")
        love.graphics.print("x", closeX + math.floor((closeW - xw) / 2), cy + math.floor((chipH - font:getHeight()) / 2))

        self._chipRects[i] = {x = cx, y = cy, w = tw, h = chipH, closeX = closeX, tag = tag}
        cx = cx + tw + chipPad
    end

    -- Input field after chips
    if cx + 80 > maxX and cx > x + pad then
        cx = x + pad
        cy = cy + chipH + chipPad
    end
    local inputW = math.max(60, maxX - cx)
    local inputH = chipH
    self._input:draw(cx, cy, inputW, inputH)
    self._contentHeight = (cy - y) + chipH + pad

    love.graphics.setScissor()

    -- Autocomplete dropdown
    if self._showSuggestions and #self._filteredSuggestions > 0 then
        local dropY = y + h + 1
        local itemH = Theme.sizes.listItemHeight
        local dropH = math.min(#self._filteredSuggestions, 6) * itemH
        -- Shadow
        setColor(Theme.colors.shadow)
        roundRect("fill", x + 2, dropY + 2, w, dropH, Theme.radius.sm)
        -- Background
        setColor(Theme.colors.panel)
        roundRect("fill", x, dropY, w, dropH, Theme.radius.sm)
        setColor(Theme.colors.panelBorder)
        roundRect("line", x + 0.5, dropY + 0.5, w - 1, dropH - 1, Theme.radius.sm)

        love.graphics.setScissor(x, dropY, w, dropH)
        self._suggestHoveredIdx = nil
        for i, sug in ipairs(self._filteredSuggestions) do
            if i > 6 then break end
            local iy = dropY + (i - 1) * itemH
            local hovered = pointInRect(mx, my, x, iy, w, itemH)
            if hovered then
                setColor(Theme.colors.listItemHover)
                love.graphics.rectangle("fill", x, iy, w, itemH)
                self._suggestHoveredIdx = i
            end
            setColor(Theme.colors.text)
            love.graphics.print(sug, x + pad, iy + math.floor((itemH - font:getHeight()) / 2))
        end
        love.graphics.setScissor()
    end
end

function W.TagPicker:mousepressed(mx, my, button)
    if button ~= 1 then return false end

    -- Check autocomplete dropdown
    if self._showSuggestions and self._suggestHoveredIdx then
        local sug = self._filteredSuggestions[self._suggestHoveredIdx]
        if sug then
            self:_addTag(sug)
            return true
        end
    end

    -- Check close buttons on chips
    for i, rect in ipairs(self._chipRects) do
        if pointInRect(mx, my, rect.closeX, rect.y, 14, rect.h) then
            self:_removeTag(i)
            return true
        end
    end

    -- Input
    if self._input:mousepressed(mx, my, button) then return true end

    return pointInRect(mx, my, self._lastX, self._lastY, self._lastW, self._lastH)
end

function W.TagPicker:mousereleased(mx, my, button)
    return false
end

function W.TagPicker:keypressed(key)
    if key == "backspace" and #self._input.text == 0 and #self.tags > 0 then
        self:_removeTag(#self.tags)
        return true
    end
    return self._input:keypressed(key)
end

function W.TagPicker:textinput(t)
    return self._input:textinput(t)
end

function W.TagPicker:mousemoved(mx, my)
    if self._input.mousemoved then
        return self._input:mousemoved(mx, my)
    end
    return false
end

function W.TagPicker:setTags(tags)
    self.tags = {}
    if tags then
        for _, t in ipairs(tags) do
            self.tags[#self.tags + 1] = t
        end
    end
end

function W.TagPicker:getTags()
    local copy = {}
    for _, t in ipairs(self.tags) do copy[#copy + 1] = t end
    return copy
end


-- =========================================================================
-- DROPDOWNSELECT
-- =========================================================================

W.DropdownSelect = {}
W.DropdownSelect.__index = W.DropdownSelect

function W.DropdownSelect.new(opts)
    opts = opts or {}
    local self = setmetatable({}, W.DropdownSelect)
    self.options = opts.options or {}  -- array of strings or {label, value} tables
    self.value = opts.value or nil
    self.multi = opts.multi or false
    self.selected = {}  -- for multi-select: set of values
    if self.multi and opts.selected then
        for _, v in ipairs(opts.selected) do
            self.selected[v] = true
        end
    end
    self.placeholder = opts.placeholder or "Select..."
    self.onChange = opts.onChange or nil
    self.fontSize = opts.fontSize or 13
    self.maxVisible = opts.maxVisible or 8
    self.disabled = opts.disabled or false
    -- internal
    self._open = false
    self._searchText = ""
    self._searchInput = nil  -- created lazily
    self._hoveredIndex = nil
    self._scrollY = 0
    self._lastX = 0
    self._lastY = 0
    self._lastW = 0
    self._lastH = 0
    return self
end

function W.DropdownSelect:_getLabel(opt)
    if type(opt) == "table" then return opt.label or tostring(opt.value) end
    return tostring(opt)
end

function W.DropdownSelect:_getValue(opt)
    if type(opt) == "table" then return opt.value end
    return opt
end

function W.DropdownSelect:_getDisplayText()
    if self.multi then
        local parts = {}
        for _, opt in ipairs(self.options) do
            local v = self:_getValue(opt)
            if self.selected[v] then
                parts[#parts + 1] = self:_getLabel(opt)
            end
        end
        if #parts == 0 then return self.placeholder end
        return table.concat(parts, ", ")
    else
        if self.value == nil then return self.placeholder end
        for _, opt in ipairs(self.options) do
            if self:_getValue(opt) == self.value then
                return self:_getLabel(opt)
            end
        end
        return tostring(self.value)
    end
end

function W.DropdownSelect:_getFilteredOptions()
    if #self._searchText == 0 then return self.options end
    local lower = self._searchText:lower()
    local result = {}
    for _, opt in ipairs(self.options) do
        if self:_getLabel(opt):lower():find(lower, 1, true) then
            result[#result + 1] = opt
        end
    end
    return result
end

function W.DropdownSelect:_needsSearch()
    return #self.options > self.maxVisible
end

function W.DropdownSelect:update(dt)
    if self._searchInput then
        self._searchInput:update(dt)
    end
end

function W.DropdownSelect:draw(x, y, w, h)
    w = w or 180
    h = h or Theme.sizes.inputHeight

    self._lastX = x
    self._lastY = y
    self._lastW = w
    self._lastH = h

    local r = Theme.radius.sm
    local font = FontCache.get(self.fontSize)
    love.graphics.setFont(font)
    local mx, my = love.mouse.getPosition()
    local hovered = pointInRect(mx, my, x, y, w, h) and not self.disabled

    -- Button face
    if self._open then
        setColor(Theme.colors.inputFocus)
        roundRect("fill", x, y, w, h, r)
    elseif hovered then
        setColor(Theme.colors.bgLight)
        roundRect("fill", x, y, w, h, r)
    else
        setColor(Theme.colors.input)
        roundRect("fill", x, y, w, h, r)
    end

    -- Border
    setColor(self._open and Theme.colors.inputFocus or Theme.colors.inputBorder)
    love.graphics.setLineWidth(1)
    roundRect("line", x + 0.5, y + 0.5, w - 1, h - 1, r)

    -- Display text
    local pad = Theme.spacing.md
    local arrowW = 16
    love.graphics.setScissor(x + pad, y, w - pad * 2 - arrowW, h)
    local displayText = self:_getDisplayText()
    if (self.value == nil and not self.multi) or (self.multi and next(self.selected) == nil) then
        setColor(Theme.colors.textDim)
    else
        setColor(Theme.colors.text)
    end
    love.graphics.print(displayText, x + pad, y + math.floor((h - font:getHeight()) / 2))
    love.graphics.setScissor()

    -- Arrow
    setColor(Theme.colors.textDim)
    local arrow = self._open and "^" or "v"
    local aw = font:getWidth(arrow)
    love.graphics.print(arrow, x + w - pad - aw, y + math.floor((h - font:getHeight()) / 2))
end

-- Draws the dropdown overlay -- call AFTER all other widgets
function W.DropdownSelect:drawDropdown()
    if not self._open then return end

    local x = self._lastX
    local y = self._lastY + self._lastH + 1
    local w = self._lastW
    local font = FontCache.get(self.fontSize)
    love.graphics.setFont(font)
    local itemH = Theme.sizes.listItemHeight
    local mx, my = love.mouse.getPosition()

    local searchH = 0
    if self:_needsSearch() then
        searchH = Theme.sizes.inputHeight + Theme.spacing.sm
    end

    local filtered = self:_getFilteredOptions()
    local visCount = math.min(#filtered, self.maxVisible)
    local listH = visCount * itemH
    local totalH = searchH + listH

    -- Multi-select done button
    local doneH = 0
    if self.multi then
        doneH = Theme.sizes.buttonHeight + Theme.spacing.sm
        totalH = totalH + doneH
    end

    -- Ensure dropdown stays on screen
    local screenH = love.graphics.getHeight()
    if y + totalH > screenH - 4 then
        y = self._lastY - totalH - 1
        if y < 0 then y = 0 end
    end

    -- Shadow
    setColor(Theme.colors.shadow)
    roundRect("fill", x + 2, y + 2, w, totalH, Theme.radius.sm)

    -- Background
    setColor(Theme.colors.panel)
    roundRect("fill", x, y, w, totalH, Theme.radius.sm)
    setColor(Theme.colors.panelBorder)
    love.graphics.setLineWidth(1)
    roundRect("line", x + 0.5, y + 0.5, w - 1, totalH - 1, Theme.radius.sm)

    local cy = y

    -- Search input
    if self:_needsSearch() then
        if not self._searchInput then
            self._searchInput = UI.TextInput.new({
                placeholder = "Filter...",
                fontSize = self.fontSize,
                onChange = function(text)
                    self._searchText = text
                    self._scrollY = 0
                end,
            })
        end
        local pad = Theme.spacing.sm
        self._searchInput:draw(x + pad, cy + pad, w - pad * 2, Theme.sizes.inputHeight)
        cy = cy + searchH
    end

    -- Items list
    love.graphics.setScissor(x, cy, w, listH)
    self._hoveredIndex = nil
    local pad = Theme.spacing.md

    for i, opt in ipairs(filtered) do
        if i > self._scrollY and i <= self._scrollY + self.maxVisible then
            local drawIdx = i - self._scrollY
            local iy = cy + (drawIdx - 1) * itemH
            local label = self:_getLabel(opt)
            local val = self:_getValue(opt)
            local isHovered = pointInRect(mx, my, x, iy, w, itemH)
            local isSelected = false

            if self.multi then
                isSelected = self.selected[val] == true
            else
                isSelected = (val == self.value)
            end

            if isHovered then
                setColor(Theme.colors.listItemHover)
                love.graphics.rectangle("fill", x + 1, iy, w - 2, itemH)
                self._hoveredIndex = i
            end
            if isSelected then
                setColor(Theme.colors.listItemSelected)
                love.graphics.rectangle("fill", x + 1, iy, w - 2, itemH)
            end

            -- Checkbox for multi
            if self.multi then
                local cbSize = 14
                local cbX = x + pad
                local cbY = iy + math.floor((itemH - cbSize) / 2)
                setColor(Theme.colors.inputBorder)
                roundRect("line", cbX, cbY, cbSize, cbSize, 2)
                if isSelected then
                    setColor(Theme.colors.primary)
                    roundRect("fill", cbX + 2, cbY + 2, cbSize - 4, cbSize - 4, 1)
                end
                setColor(Theme.colors.text)
                love.graphics.print(label, cbX + cbSize + Theme.spacing.sm, iy + math.floor((itemH - font:getHeight()) / 2))
            else
                setColor(Theme.colors.text)
                love.graphics.print(label, x + pad, iy + math.floor((itemH - font:getHeight()) / 2))
            end
        end
    end
    love.graphics.setScissor()

    -- Done button for multi-select
    if self.multi then
        local btnY = cy + listH + Theme.spacing.sm
        local btnW = 60
        local btnX = x + w - btnW - Theme.spacing.sm
        local btnH = Theme.sizes.buttonHeight
        local btnHovered = pointInRect(mx, my, btnX, btnY, btnW, btnH)
        setColor(btnHovered and Theme.colors.primaryHover or Theme.colors.primary)
        roundRect("fill", btnX, btnY, btnW, btnH, Theme.radius.sm)
        love.graphics.setColor(0, 0, 0)
        local doneLabel = "Done"
        local tw = font:getWidth(doneLabel)
        love.graphics.print(doneLabel, btnX + math.floor((btnW - tw) / 2), btnY + math.floor((btnH - font:getHeight()) / 2))
    end
end

function W.DropdownSelect:open()
    if self.disabled then return end
    self._open = true
    self._searchText = ""
    self._scrollY = 0
    if self._searchInput then
        self._searchInput:setText("")
    end
end

function W.DropdownSelect:close()
    self._open = false
    self._searchText = ""
end

function W.DropdownSelect:toggle()
    if self._open then self:close() else self:open() end
end

function W.DropdownSelect:mousepressed(mx, my, button)
    if button ~= 1 then return false end

    -- If open, handle dropdown clicks
    if self._open then
        local x = self._lastX
        local y = self._lastY + self._lastH + 1
        local w = self._lastW
        local itemH = Theme.sizes.listItemHeight
        local searchH = self:_needsSearch() and (Theme.sizes.inputHeight + Theme.spacing.sm) or 0
        local filtered = self:_getFilteredOptions()
        local visCount = math.min(#filtered, self.maxVisible)
        local listH = visCount * itemH
        local doneH = self.multi and (Theme.sizes.buttonHeight + Theme.spacing.sm) or 0
        local totalH = searchH + listH + doneH

        -- Check if screen flip happened
        local screenH = love.graphics.getHeight()
        if self._lastY + self._lastH + 1 + totalH > screenH - 4 then
            y = self._lastY - totalH - 1
            if y < 0 then y = 0 end
        end

        -- Click in dropdown area
        if pointInRect(mx, my, x, y, w, totalH) then
            -- Search input
            if self:_needsSearch() and self._searchInput then
                if pointInRect(mx, my, x, y, w, searchH) then
                    self._searchInput:mousepressed(mx, my, button)
                    return true
                end
            end

            -- Done button (multi)
            if self.multi then
                local btnY = y + searchH + listH + Theme.spacing.sm
                local btnW = 60
                local btnX = x + w - btnW - Theme.spacing.sm
                local btnH = Theme.sizes.buttonHeight
                if pointInRect(mx, my, btnX, btnY, btnW, btnH) then
                    self:close()
                    return true
                end
            end

            -- Item click
            if self._hoveredIndex then
                local opt = filtered[self._hoveredIndex]
                if opt then
                    local val = self:_getValue(opt)
                    if self.multi then
                        if self.selected[val] then
                            self.selected[val] = nil
                        else
                            self.selected[val] = true
                        end
                        if self.onChange then
                            local sel = {}
                            for _, o in ipairs(self.options) do
                                local v2 = self:_getValue(o)
                                if self.selected[v2] then sel[#sel + 1] = v2 end
                            end
                            self.onChange(sel)
                        end
                    else
                        self.value = val
                        self:close()
                        if self.onChange then self.onChange(val) end
                    end
                    return true
                end
            end

            return true  -- consume click inside dropdown
        end

        -- Click on the button itself toggles
        if pointInRect(mx, my, self._lastX, self._lastY, self._lastW, self._lastH) then
            self:close()
            return true
        end

        -- Click outside -> close
        self:close()
        return false
    end

    -- Not open: check button click
    if pointInRect(mx, my, self._lastX, self._lastY, self._lastW, self._lastH) then
        self:open()
        return true
    end

    return false
end

function W.DropdownSelect:mousereleased(mx, my, button)
    return false
end

function W.DropdownSelect:keypressed(key)
    if self._open then
        if key == "escape" then
            self:close()
            return true
        end
        if self._searchInput then
            return self._searchInput:keypressed(key)
        end
    end
    return false
end

function W.DropdownSelect:textinput(t)
    if self._open and self._searchInput then
        return self._searchInput:textinput(t)
    end
    return false
end

function W.DropdownSelect:wheelmoved(wx, wy)
    if not self._open then return false end
    local filtered = self:_getFilteredOptions()
    local maxScroll = math.max(0, #filtered - self.maxVisible)
    self._scrollY = clamp(self._scrollY - wy, 0, maxScroll)
    return true
end

function W.DropdownSelect:setValue(v)
    if self.multi then
        self.selected = {}
        if type(v) == "table" then
            for _, val in ipairs(v) do self.selected[val] = true end
        end
    else
        self.value = v
    end
end

function W.DropdownSelect:getValue()
    if self.multi then
        local sel = {}
        for _, opt in ipairs(self.options) do
            local val = self:_getValue(opt)
            if self.selected[val] then sel[#sel + 1] = val end
        end
        return sel
    end
    return self.value
end

function W.DropdownSelect:isOpen()
    return self._open
end


-- =========================================================================
-- COLORPICKER
-- =========================================================================

W.ColorPicker = {}
W.ColorPicker.__index = W.ColorPicker

W.ColorPicker.PRESETS = {
    {1, 1, 1},       -- white
    {0, 0, 0},       -- black
    {0.8, 0.2, 0.2}, -- red
    {0.2, 0.8, 0.2}, -- green
    {0.2, 0.2, 0.8}, -- blue
    {0.9, 0.9, 0.2}, -- yellow
    {0.9, 0.5, 0.1}, -- orange
    {0.6, 0.2, 0.8}, -- purple
    {0.2, 0.8, 0.8}, -- cyan
    {0.8, 0.4, 0.6}, -- pink
    {0.4, 0.3, 0.2}, -- brown
    {0.5, 0.5, 0.5}, -- gray
}

function W.ColorPicker.new(opts)
    opts = opts or {}
    local self = setmetatable({}, W.ColorPicker)
    self.color = opts.color or {1, 1, 1}
    self.onChange = opts.onChange or nil
    self.fontSize = opts.fontSize or 12
    self.showHex = opts.showHex ~= false
    self.showPresets = opts.showPresets ~= false
    -- internal
    self._rSlider = UI.Slider.new({min = 0, max = 1, value = self.color[1], step = 0.01, label = "R",
        onChange = function(v) self:_onSlider("r", v) end})
    self._gSlider = UI.Slider.new({min = 0, max = 1, value = self.color[2], step = 0.01, label = "G",
        onChange = function(v) self:_onSlider("g", v) end})
    self._bSlider = UI.Slider.new({min = 0, max = 1, value = self.color[3], step = 0.01, label = "B",
        onChange = function(v) self:_onSlider("b", v) end})
    self._hexInput = UI.TextInput.new({
        text = rgbToHex(self.color[1], self.color[2], self.color[3]),
        fontSize = self.fontSize,
        maxLength = 7,
        onSubmit = function(text)
            self:_onHexSubmit(text)
        end,
    })
    self._presetHovered = nil
    self._lastX = 0
    self._lastY = 0
    self._lastW = 0
    self._lastH = 0
    return self
end

function W.ColorPicker:_onSlider(channel, v)
    if channel == "r" then self.color[1] = v
    elseif channel == "g" then self.color[2] = v
    elseif channel == "b" then self.color[3] = v
    end
    self._hexInput:setText(rgbToHex(self.color[1], self.color[2], self.color[3]))
    if self.onChange then self.onChange(self.color) end
end

function W.ColorPicker:_onHexSubmit(text)
    local r, g, b = hexToRGB(text)
    if r then
        self.color = {r, g, b}
        self._rSlider:setValue(r)
        self._gSlider:setValue(g)
        self._bSlider:setValue(b)
        if self.onChange then self.onChange(self.color) end
    else
        self._hexInput:setText(rgbToHex(self.color[1], self.color[2], self.color[3]))
    end
end

function W.ColorPicker:setColor(c)
    self.color = {c[1] or 1, c[2] or 1, c[3] or 1}
    self._rSlider:setValue(self.color[1])
    self._gSlider:setValue(self.color[2])
    self._bSlider:setValue(self.color[3])
    self._hexInput:setText(rgbToHex(self.color[1], self.color[2], self.color[3]))
end

function W.ColorPicker:update(dt)
    self._hexInput:update(dt)
end

function W.ColorPicker:draw(x, y, w, h)
    w = w or 240
    h = h or 160

    self._lastX = x
    self._lastY = y
    self._lastW = w
    self._lastH = h

    local font = FontCache.get(self.fontSize)
    love.graphics.setFont(font)
    local pad = Theme.spacing.md
    local mx, my = love.mouse.getPosition()

    -- Color preview swatch
    local swatchSize = 40
    setColor(self.color)
    roundRect("fill", x, y, swatchSize, swatchSize, Theme.radius.sm)
    -- Checker pattern behind for alpha indication
    setColor(Theme.colors.inputBorder)
    love.graphics.setLineWidth(1)
    roundRect("line", x + 0.5, y + 0.5, swatchSize - 1, swatchSize - 1, Theme.radius.sm)

    -- Hex input next to swatch
    if self.showHex then
        self._hexInput:draw(x + swatchSize + pad, y + math.floor((swatchSize - Theme.sizes.inputHeight) / 2),
            math.min(80, w - swatchSize - pad), Theme.sizes.inputHeight)
    end

    -- RGB Sliders
    local sliderY = y + swatchSize + pad
    local sliderH = 30
    self._rSlider:draw(x, sliderY, w, sliderH)
    sliderY = sliderY + sliderH + 2
    self._gSlider:draw(x, sliderY, w, sliderH)
    sliderY = sliderY + sliderH + 2
    self._bSlider:draw(x, sliderY, w, sliderH)
    sliderY = sliderY + sliderH + pad

    -- Preset swatches
    if self.showPresets then
        local presetSize = 18
        local gap = 4
        local px = x
        self._presetHovered = nil
        for i, preset in ipairs(W.ColorPicker.PRESETS) do
            if px + presetSize > x + w then
                break
            end
            local hov = pointInRect(mx, my, px, sliderY, presetSize, presetSize)
            if hov then self._presetHovered = i end
            setColor(preset)
            roundRect("fill", px, sliderY, presetSize, presetSize, 2)
            if hov then
                love.graphics.setColor(1, 1, 1)
                love.graphics.setLineWidth(2)
                roundRect("line", px, sliderY, presetSize, presetSize, 2)
                love.graphics.setLineWidth(1)
            else
                setColor(Theme.colors.inputBorder)
                roundRect("line", px + 0.5, sliderY + 0.5, presetSize - 1, presetSize - 1, 2)
            end
            px = px + presetSize + gap
        end
    end
end

function W.ColorPicker:mousepressed(mx, my, button)
    if button ~= 1 then return false end

    -- Preset click
    if self.showPresets and self._presetHovered then
        local preset = W.ColorPicker.PRESETS[self._presetHovered]
        if preset then
            self:setColor(preset)
            if self.onChange then self.onChange(self.color) end
            return true
        end
    end

    if self._rSlider:mousepressed(mx, my, button) then return true end
    if self._gSlider:mousepressed(mx, my, button) then return true end
    if self._bSlider:mousepressed(mx, my, button) then return true end
    if self._hexInput:mousepressed(mx, my, button) then return true end

    return pointInRect(mx, my, self._lastX, self._lastY, self._lastW, self._lastH)
end

function W.ColorPicker:mousereleased(mx, my, button)
    local consumed = false
    if self._rSlider:mousereleased(mx, my, button) then consumed = true end
    if self._gSlider:mousereleased(mx, my, button) then consumed = true end
    if self._bSlider:mousereleased(mx, my, button) then consumed = true end
    return consumed
end

function W.ColorPicker:mousemoved(mx, my)
    if self._rSlider:mousemoved(mx, my) then return true end
    if self._gSlider:mousemoved(mx, my) then return true end
    if self._bSlider:mousemoved(mx, my) then return true end
    if self._hexInput.mousemoved then
        if self._hexInput:mousemoved(mx, my) then return true end
    end
    return false
end

function W.ColorPicker:keypressed(key)
    return self._hexInput:keypressed(key)
end

function W.ColorPicker:textinput(t)
    return self._hexInput:textinput(t)
end


-- =========================================================================
-- TREEVIEW
-- =========================================================================

W.TreeView = {}
W.TreeView.__index = W.TreeView

function W.TreeView.new(opts)
    opts = opts or {}
    local self = setmetatable({}, W.TreeView)
    self.root = opts.root or {label = "Root", children = {}, data = {}, expanded = true}
    self.selectedNode = nil
    self.onSelect = opts.onSelect or nil
    self.onDoubleClick = opts.onDoubleClick or nil
    self.onAddChild = opts.onAddChild or nil
    self.onDelete = opts.onDelete or nil
    self.onReorder = opts.onReorder or nil
    self.fontSize = opts.fontSize or 13
    self.indentWidth = opts.indentWidth or 20
    self.nodeHeight = opts.nodeHeight or Theme.sizes.listItemHeight
    self.showControls = opts.showControls ~= false
    -- internal
    self._scroll = UI.ScrollContainer.new({contentHeight = 0})
    self._flatNodes = {}
    self._editingNode = nil
    self._editInput = nil
    self._lastClickTime = 0
    self._lastClickNode = nil
    self._hoveredNode = nil
    self._addBtnHovered = false
    self._delBtnHovered = false
    self._upBtnHovered = false
    self._downBtnHovered = false
    self._lastX = 0
    self._lastY = 0
    self._lastW = 0
    self._lastH = 0
    return self
end

function W.TreeView:_flatten(node, depth, parent, index)
    depth = depth or 0
    local entry = {node = node, depth = depth, parent = parent, index = index}
    self._flatNodes[#self._flatNodes + 1] = entry
    if node.expanded and node.children then
        for i, child in ipairs(node.children) do
            self:_flatten(child, depth + 1, node, i)
        end
    end
end

function W.TreeView:_rebuildFlat()
    self._flatNodes = {}
    self:_flatten(self.root, 0, nil, 1)
    self._scroll:setContentHeight(#self._flatNodes * self.nodeHeight)
end

function W.TreeView:_findEntry(node)
    for _, entry in ipairs(self._flatNodes) do
        if entry.node == node then return entry end
    end
    return nil
end

function W.TreeView:_startEdit(node)
    self._editingNode = node
    self._editInput = UI.TextInput.new({
        text = node.label or "",
        fontSize = self.fontSize,
        onSubmit = function(text)
            node.label = text
            self._editingNode = nil
            self._editInput = nil
        end,
    })
    -- Force focus
    self._editInput._focused = true
    UI.setFocus(self._editInput)
end

function W.TreeView:_cancelEdit()
    if self._editInput then
        UI.clearFocus()
    end
    self._editingNode = nil
    self._editInput = nil
end

function W.TreeView:update(dt)
    self:_rebuildFlat()
    if self._editInput then
        self._editInput:update(dt)
    end
end

function W.TreeView:draw(x, y, w, h)
    w = w or 260
    h = h or 300

    self._lastX = x
    self._lastY = y
    self._lastW = w
    self._lastH = h

    local font = FontCache.get(self.fontSize)
    love.graphics.setFont(font)
    local nh = self.nodeHeight
    local indent = self.indentWidth
    local pad = Theme.spacing.sm
    local mx, my = love.mouse.getPosition()

    -- Controls toolbar if selected
    local controlH = 0
    if self.showControls and self.selectedNode then
        controlH = Theme.sizes.buttonHeight + Theme.spacing.sm
        local btnSize = Theme.sizes.buttonHeight
        local btnX = x + pad
        local btnY = y + pad
        local btnGap = Theme.spacing.sm

        -- Add child button
        self._addBtnHovered = pointInRect(mx, my, btnX, btnY, btnSize, btnSize)
        setColor(self._addBtnHovered and Theme.colors.primaryHover or Theme.colors.bgLight)
        roundRect("fill", btnX, btnY, btnSize, btnSize, Theme.radius.sm)
        setColor(Theme.colors.text)
        local tw = font:getWidth("+")
        love.graphics.print("+", btnX + math.floor((btnSize - tw) / 2), btnY + math.floor((btnSize - font:getHeight()) / 2))
        btnX = btnX + btnSize + btnGap

        -- Delete button
        self._delBtnHovered = pointInRect(mx, my, btnX, btnY, btnSize, btnSize)
        setColor(self._delBtnHovered and Theme.colors.dangerHover or Theme.colors.bgLight)
        roundRect("fill", btnX, btnY, btnSize, btnSize, Theme.radius.sm)
        setColor(Theme.colors.text)
        tw = font:getWidth("X")
        love.graphics.print("X", btnX + math.floor((btnSize - tw) / 2), btnY + math.floor((btnSize - font:getHeight()) / 2))
        btnX = btnX + btnSize + btnGap

        -- Move up
        self._upBtnHovered = pointInRect(mx, my, btnX, btnY, btnSize, btnSize)
        setColor(self._upBtnHovered and Theme.colors.secondaryHover or Theme.colors.bgLight)
        roundRect("fill", btnX, btnY, btnSize, btnSize, Theme.radius.sm)
        setColor(Theme.colors.text)
        tw = font:getWidth("^")
        love.graphics.print("^", btnX + math.floor((btnSize - tw) / 2), btnY + math.floor((btnSize - font:getHeight()) / 2))
        btnX = btnX + btnSize + btnGap

        -- Move down
        self._downBtnHovered = pointInRect(mx, my, btnX, btnY, btnSize, btnSize)
        setColor(self._downBtnHovered and Theme.colors.secondaryHover or Theme.colors.bgLight)
        roundRect("fill", btnX, btnY, btnSize, btnSize, Theme.radius.sm)
        setColor(Theme.colors.text)
        tw = font:getWidth("v")
        love.graphics.print("v", btnX + math.floor((btnSize - tw) / 2), btnY + math.floor((btnSize - font:getHeight()) / 2))

        controlH = btnSize + Theme.spacing.sm * 2
    end

    -- Tree area
    local treeY = y + controlH
    local treeH = h - controlH

    self._scroll:beginDraw(x, treeY, w, treeH)

    self._hoveredNode = nil

    for idx, entry in ipairs(self._flatNodes) do
        local node = entry.node
        local depth = entry.depth
        local ny = (idx - 1) * nh
        local nx = depth * indent

        -- Visibility check
        local screenNodeY = treeY + ny - self._scroll.scrollY
        if screenNodeY + nh >= treeY and screenNodeY < treeY + treeH then
            local isSelected = (node == self.selectedNode)
            local nodeScreenX = x + nx
            local isHovered = pointInRect(mx, my, x, screenNodeY, w, nh)

            if isHovered then
                self._hoveredNode = node
            end

            -- Row background
            if isSelected then
                setColor(Theme.colors.listItemSelected)
                love.graphics.rectangle("fill", 0, ny, w, nh)
            elseif isHovered then
                setColor(Theme.colors.listItemHover)
                love.graphics.rectangle("fill", 0, ny, w, nh)
            end

            -- Connecting lines
            if depth > 0 then
                setColor(Theme.colors.textDark)
                love.graphics.setLineWidth(1)
                local lineX = nx - indent / 2
                -- Vertical line from parent
                love.graphics.line(lineX, ny, lineX, ny + nh / 2)
                -- Horizontal line to node
                love.graphics.line(lineX, ny + nh / 2, nx - 2, ny + nh / 2)
            end

            -- Expand/collapse arrow
            if node.children and #node.children > 0 then
                local arrowX = nx + 2
                local arrowY = ny + math.floor((nh - font:getHeight()) / 2)
                setColor(Theme.colors.textDim)
                if node.expanded then
                    love.graphics.print("v", arrowX, arrowY)
                else
                    love.graphics.print(">", arrowX, arrowY)
                end
            end

            -- Label
            local labelX = nx + 16
            if self._editingNode == node and self._editInput then
                self._editInput:draw(labelX, ny + 1, w - labelX - 4, nh - 2)
            else
                setColor(isSelected and Theme.colors.textAccent or Theme.colors.text)
                local label = node.label or "(unnamed)"
                love.graphics.print(label, labelX, ny + math.floor((nh - font:getHeight()) / 2))
            end
        end
    end

    self._scroll:endDraw()
end

function W.TreeView:mousepressed(mx, my, button)
    if button ~= 1 then return false end

    -- Control buttons
    if self.showControls and self.selectedNode then
        local entry = self:_findEntry(self.selectedNode)

        if self._addBtnHovered then
            if not self.selectedNode.children then
                self.selectedNode.children = {}
            end
            local newNode = {label = "New Node", children = {}, data = {}, expanded = false}
            self.selectedNode.children[#self.selectedNode.children + 1] = newNode
            self.selectedNode.expanded = true
            if self.onAddChild then self.onAddChild(self.selectedNode, newNode) end
            return true
        end

        if self._delBtnHovered and entry and entry.parent then
            local parent = entry.parent
            local idx = entry.index
            if idx and parent.children then
                table.remove(parent.children, idx)
                if self.onDelete then self.onDelete(self.selectedNode) end
                self.selectedNode = nil
            end
            return true
        end

        if self._upBtnHovered and entry and entry.parent then
            local parent = entry.parent
            local idx = entry.index
            if idx and idx > 1 and parent.children then
                parent.children[idx], parent.children[idx - 1] = parent.children[idx - 1], parent.children[idx]
                if self.onReorder then self.onReorder(self.selectedNode) end
            end
            return true
        end

        if self._downBtnHovered and entry and entry.parent then
            local parent = entry.parent
            local idx = entry.index
            if idx and parent.children and idx < #parent.children then
                parent.children[idx], parent.children[idx + 1] = parent.children[idx + 1], parent.children[idx]
                if self.onReorder then self.onReorder(self.selectedNode) end
            end
            return true
        end
    end

    -- Scrollbar
    if self._scroll:mousepressed(mx, my, button) then return true end

    -- Tree nodes
    if not pointInRect(mx, my, self._lastX, self._lastY, self._lastW, self._lastH) then
        return false
    end

    if self._editInput then
        if self._editInput:mousepressed(mx, my, button) then return true end
        self:_cancelEdit()
    end

    if self._hoveredNode then
        local node = self._hoveredNode
        local now = love.timer.getTime()

        -- Double-click detection
        if self._lastClickNode == node and (now - self._lastClickTime) < 0.35 then
            self:_startEdit(node)
            if self.onDoubleClick then self.onDoubleClick(node) end
            self._lastClickTime = 0
            return true
        end

        self._lastClickTime = now
        self._lastClickNode = node

        -- Expand/collapse check: if node has children, toggle on arrow area
        -- Simplified: toggle if clicking on the left portion
        local entry = self:_findEntry(node)
        if entry and node.children and #node.children > 0 then
            local arrowEndX = self._lastX + entry.depth * self.indentWidth + 16
            if mx < arrowEndX then
                node.expanded = not node.expanded
                return true
            end
        end

        -- Select
        self.selectedNode = node
        if self.onSelect then self.onSelect(node) end
        return true
    end

    return false
end

function W.TreeView:mousereleased(mx, my, button)
    return self._scroll:mousereleased(mx, my, button)
end

function W.TreeView:mousemoved(mx, my)
    return self._scroll:mousemoved(mx, my)
end

function W.TreeView:wheelmoved(wx, wy)
    return self._scroll:wheelmoved(wx, wy)
end

function W.TreeView:keypressed(key)
    if self._editInput then
        if key == "escape" then
            self:_cancelEdit()
            return true
        end
        return self._editInput:keypressed(key)
    end
    if key == "delete" and self.selectedNode then
        local entry = self:_findEntry(self.selectedNode)
        if entry and entry.parent then
            table.remove(entry.parent.children, entry.index)
            if self.onDelete then self.onDelete(self.selectedNode) end
            self.selectedNode = nil
            return true
        end
    end
    return false
end

function W.TreeView:textinput(t)
    if self._editInput then
        return self._editInput:textinput(t)
    end
    return false
end


-- =========================================================================
-- ICONPICKER (modal grid selector)
-- =========================================================================

W.IconPicker = {}
W.IconPicker.__index = W.IconPicker

function W.IconPicker.new(opts)
    opts = opts or {}
    local self = setmetatable({}, W.IconPicker)
    self.icons = opts.icons or {}       -- { {path="...", label="..."}, ... }
    self.categories = opts.categories or {}  -- { {id="cat", label="Cat", icons={...}}, ... }
    self.iconSize = opts.iconSize or Theme.sizes.iconMedium
    self.previewSize = opts.previewSize or Theme.sizes.iconPreview
    self.onSelect = opts.onSelect or nil
    self.onCancel = opts.onCancel or nil
    self.fontSize = opts.fontSize or 12
    -- internal
    self._visible = false
    self._selectedPath = nil
    self._activeCategory = nil
    self._searchBar = W.SearchBar.new({
        placeholder = "Filter icons...",
        fontSize = self.fontSize,
        onSearch = function(text)
            self._filterText = text
        end,
    })
    self._filterText = ""
    self._scroll = UI.ScrollContainer.new({contentHeight = 0})
    self._hoveredIcon = nil
    self._imageCache = {}
    return self
end

function W.IconPicker:show(selected)
    self._visible = true
    self._selectedPath = selected
    self._filterText = ""
    self._searchBar:setText("")
    self._scroll:scrollToTop()
    if #self.categories > 0 and not self._activeCategory then
        self._activeCategory = self.categories[1].id
    end
end

function W.IconPicker:hide()
    self._visible = false
end

function W.IconPicker:isVisible()
    return self._visible
end

function W.IconPicker:_getVisibleIcons()
    local pool = {}
    if #self.categories > 0 and self._activeCategory then
        for _, cat in ipairs(self.categories) do
            if cat.id == self._activeCategory then
                pool = cat.icons or {}
                break
            end
        end
    else
        pool = self.icons
    end

    if #self._filterText == 0 then return pool end
    local lower = self._filterText:lower()
    local result = {}
    for _, icon in ipairs(pool) do
        local label = type(icon) == "table" and (icon.label or icon.path) or tostring(icon)
        if label:lower():find(lower, 1, true) then
            result[#result + 1] = icon
        end
    end
    return result
end

function W.IconPicker:_getIconPath(icon)
    if type(icon) == "table" then return icon.path end
    return tostring(icon)
end

function W.IconPicker:_getIconLabel(icon)
    if type(icon) == "table" then return icon.label or icon.path end
    return tostring(icon)
end

function W.IconPicker:_loadImage(path)
    if self._imageCache[path] then return self._imageCache[path] end
    local ok, img = pcall(love.graphics.newImage, path)
    if ok then
        self._imageCache[path] = img
        return img
    end
    self._imageCache[path] = false
    return nil
end

function W.IconPicker:update(dt)
    if not self._visible then return end
    self._searchBar:update(dt)
end

function W.IconPicker:draw()
    if not self._visible then return end

    local screenW, screenH = love.graphics.getDimensions()
    local font = FontCache.get(self.fontSize)
    love.graphics.setFont(font)
    local mx, my = love.mouse.getPosition()

    -- Overlay
    setColor(Theme.colors.overlay)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Dialog
    local dw = math.min(600, screenW - 40)
    local dh = math.min(500, screenH - 40)
    local dx = math.floor((screenW - dw) / 2)
    local dy = math.floor((screenH - dh) / 2)

    -- Shadow + bg
    setColor(Theme.colors.shadow)
    roundRect("fill", dx + 3, dy + 3, dw, dh, Theme.radius.lg)
    setColor(Theme.colors.panel)
    roundRect("fill", dx, dy, dw, dh, Theme.radius.lg)
    setColor(Theme.colors.panelBorder)
    love.graphics.setLineWidth(1)
    roundRect("line", dx + 0.5, dy + 0.5, dw - 1, dh - 1, Theme.radius.lg)

    -- Title
    local titleH = 36
    setColor(Theme.colors.panelHeader)
    roundRect("fill", dx + 1, dy + 1, dw - 2, titleH, Theme.radius.lg)
    love.graphics.rectangle("fill", dx + 1, dy + titleH - Theme.radius.lg, dw - 2, Theme.radius.lg)
    setColor(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", dx, dy + titleH, dw, 1)
    setColor(Theme.colors.text)
    local titleFont = FontCache.get(14)
    love.graphics.setFont(titleFont)
    love.graphics.print("Select Icon", dx + Theme.spacing.lg, dy + math.floor((titleH - titleFont:getHeight()) / 2))
    love.graphics.setFont(font)

    local pad = Theme.spacing.md
    local contentY = dy + titleH + 1

    -- Category tabs
    local tabH = 0
    if #self.categories > 1 then
        tabH = Theme.sizes.buttonHeight + pad
        local tabX = dx + pad
        for _, cat in ipairs(self.categories) do
            local label = cat.label or cat.id
            local tw = font:getWidth(label) + pad * 2
            local isActive = (cat.id == self._activeCategory)
            local hov = pointInRect(mx, my, tabX, contentY + pad / 2, tw, Theme.sizes.buttonHeight)
            if isActive then
                setColor(Theme.colors.primary)
            elseif hov then
                setColor(Theme.colors.tabHover)
            else
                setColor(Theme.colors.tabInactive)
            end
            roundRect("fill", tabX, contentY + pad / 2, tw, Theme.sizes.buttonHeight, Theme.radius.sm)
            setColor(isActive and Theme.colors.bg or Theme.colors.text)
            love.graphics.print(label, tabX + pad, contentY + pad / 2 + math.floor((Theme.sizes.buttonHeight - font:getHeight()) / 2))
            tabX = tabX + tw + Theme.spacing.sm
        end
    end

    -- Search bar
    local searchY = contentY + tabH + pad
    self._searchBar:draw(dx + pad, searchY, dw - pad * 2 - self.previewSize - pad, Theme.sizes.inputHeight)

    -- Preview
    local previewX = dx + dw - self.previewSize - pad
    local previewY = contentY + tabH + pad
    setColor(Theme.colors.bgDark)
    roundRect("fill", previewX, previewY, self.previewSize, self.previewSize, Theme.radius.sm)
    if self._selectedPath then
        local img = self:_loadImage(self._selectedPath)
        if img then
            love.graphics.setColor(1, 1, 1)
            local iw, ih = img:getDimensions()
            local scale = math.min(self.previewSize / iw, self.previewSize / ih)
            local ox = previewX + math.floor((self.previewSize - iw * scale) / 2)
            local oy = previewY + math.floor((self.previewSize - ih * scale) / 2)
            love.graphics.draw(img, ox, oy, 0, scale, scale)
        end
        -- Label below preview
        setColor(Theme.colors.textDim)
        local pLabel = self._selectedPath
        if #pLabel > 25 then pLabel = "..." .. pLabel:sub(-22) end
        love.graphics.print(pLabel, previewX, previewY + self.previewSize + 2)
    end

    -- Grid
    local gridY = searchY + Theme.sizes.inputHeight + pad
    local gridW = dw - pad * 2 - self.previewSize - pad
    local gridH = dh - (gridY - dy) - Theme.sizes.buttonHeight - pad * 2
    local iconS = self.iconSize
    local gap = Theme.spacing.sm
    local cols = math.max(1, math.floor((gridW + gap) / (iconS + gap)))

    local visible = self:_getVisibleIcons()
    local rows = math.ceil(#visible / cols)
    self._scroll:setContentHeight(rows * (iconS + gap))

    self._scroll:beginDraw(dx + pad, gridY, gridW, gridH)

    self._hoveredIcon = nil
    for i, icon in ipairs(visible) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local ix = col * (iconS + gap)
        local iy = row * (iconS + gap)
        local path = self:_getIconPath(icon)
        local isSelected = (path == self._selectedPath)

        local screenIY = gridY + iy - self._scroll.scrollY
        if screenIY + iconS >= gridY and screenIY < gridY + gridH then
            local screenIX = dx + pad + ix
            local hov = pointInRect(mx, my, screenIX, screenIY, iconS, iconS)
            if hov then self._hoveredIcon = icon end

            -- Background
            if isSelected then
                setColor(Theme.colors.primary)
                roundRect("fill", ix - 2, iy - 2, iconS + 4, iconS + 4, Theme.radius.sm)
            elseif hov then
                setColor(Theme.colors.listItemHover)
                roundRect("fill", ix - 1, iy - 1, iconS + 2, iconS + 2, Theme.radius.sm)
            end

            -- Icon image
            local img = self:_loadImage(path)
            if img then
                love.graphics.setColor(1, 1, 1)
                local iw, ih = img:getDimensions()
                local scale = math.min(iconS / iw, iconS / ih)
                love.graphics.draw(img, ix, iy, 0, scale, scale)
            else
                setColor(Theme.colors.bgLight)
                roundRect("fill", ix, iy, iconS, iconS, 2)
                setColor(Theme.colors.textDim)
                love.graphics.print("?", ix + iconS / 2 - 3, iy + iconS / 2 - font:getHeight() / 2)
            end
        end
    end

    self._scroll:endDraw()

    -- Bottom buttons
    local btnY = dy + dh - Theme.sizes.buttonHeight - pad
    local btnW = 80
    local btnH = Theme.sizes.buttonHeight

    -- Cancel
    local cancelX = dx + dw - pad - btnW
    local cancelHov = pointInRect(mx, my, cancelX, btnY, btnW, btnH)
    setColor(cancelHov and Theme.colors.tabHover or Theme.colors.bgLight)
    roundRect("fill", cancelX, btnY, btnW, btnH, Theme.radius.sm)
    setColor(Theme.colors.text)
    local cl = "Cancel"
    love.graphics.print(cl, cancelX + math.floor((btnW - font:getWidth(cl)) / 2), btnY + math.floor((btnH - font:getHeight()) / 2))

    -- OK
    local okX = cancelX - btnW - pad
    local okEnabled = self._selectedPath ~= nil
    local okHov = okEnabled and pointInRect(mx, my, okX, btnY, btnW, btnH)
    setColor(okHov and Theme.colors.primaryHover or (okEnabled and Theme.colors.primary or Theme.colors.textDim))
    roundRect("fill", okX, btnY, btnW, btnH, Theme.radius.sm)
    love.graphics.setColor(0, 0, 0)
    local ol = "Select"
    love.graphics.print(ol, okX + math.floor((btnW - font:getWidth(ol)) / 2), btnY + math.floor((btnH - font:getHeight()) / 2))
end

function W.IconPicker:mousepressed(mx, my, button)
    if not self._visible or button ~= 1 then return false end

    local screenW, screenH = love.graphics.getDimensions()
    local dw = math.min(600, screenW - 40)
    local dh = math.min(500, screenH - 40)
    local dx = math.floor((screenW - dw) / 2)
    local dy = math.floor((screenH - dh) / 2)
    local pad = Theme.spacing.md
    local font = FontCache.get(self.fontSize)
    local btnW = 80
    local btnH = Theme.sizes.buttonHeight
    local btnY = dy + dh - btnH - pad

    -- Cancel button
    local cancelX = dx + dw - pad - btnW
    if pointInRect(mx, my, cancelX, btnY, btnW, btnH) then
        self:hide()
        if self.onCancel then self.onCancel() end
        return true
    end

    -- OK button
    local okX = cancelX - btnW - pad
    if self._selectedPath and pointInRect(mx, my, okX, btnY, btnW, btnH) then
        self:hide()
        if self.onSelect then self.onSelect(self._selectedPath) end
        return true
    end

    -- Category tabs
    if #self.categories > 1 then
        local titleH = 36
        local contentY = dy + titleH + 1
        local tabX = dx + pad
        for _, cat in ipairs(self.categories) do
            local label = cat.label or cat.id
            local tw = font:getWidth(label) + pad * 2
            if pointInRect(mx, my, tabX, contentY + pad / 2, tw, Theme.sizes.buttonHeight) then
                self._activeCategory = cat.id
                self._scroll:scrollToTop()
                return true
            end
            tabX = tabX + tw + Theme.spacing.sm
        end
    end

    -- Search bar
    if self._searchBar:mousepressed(mx, my, button) then return true end

    -- Scroll
    if self._scroll:mousepressed(mx, my, button) then return true end

    -- Grid icon click
    if self._hoveredIcon then
        self._selectedPath = self:_getIconPath(self._hoveredIcon)
        return true
    end

    return true  -- Modal consumes all clicks
end

function W.IconPicker:mousereleased(mx, my, button)
    if not self._visible then return false end
    self._scroll:mousereleased(mx, my, button)
    return true
end

function W.IconPicker:keypressed(key)
    if not self._visible then return false end
    if key == "escape" then
        self:hide()
        if self.onCancel then self.onCancel() end
        return true
    end
    if key == "return" and self._selectedPath then
        self:hide()
        if self.onSelect then self.onSelect(self._selectedPath) end
        return true
    end
    return self._searchBar:keypressed(key)
end

function W.IconPicker:textinput(t)
    if not self._visible then return false end
    return self._searchBar:textinput(t)
end

function W.IconPicker:wheelmoved(wx, wy)
    if not self._visible then return false end
    return self._scroll:wheelmoved(wx, wy)
end

function W.IconPicker:mousemoved(mx, my)
    if not self._visible then return false end
    self._scroll:mousemoved(mx, my)
    self._searchBar:mousemoved(mx, my)
    return true
end


-- =========================================================================
-- PORTRAITPICKER
-- =========================================================================

W.PortraitPicker = {}
W.PortraitPicker.__index = W.PortraitPicker

function W.PortraitPicker.new(opts)
    opts = opts or {}
    local self = setmetatable({}, W.PortraitPicker)
    -- Reuse IconPicker with larger thumbnails
    self._picker = W.IconPicker.new({
        icons = opts.portraits or opts.icons or {},
        categories = opts.categories or {},
        iconSize = opts.thumbnailSize or 64,
        previewSize = opts.previewSize or Theme.sizes.iconPreview,
        fontSize = opts.fontSize or 12,
        onSelect = opts.onSelect or nil,
        onCancel = opts.onCancel or nil,
    })
    return self
end

function W.PortraitPicker:show(selected)
    self._picker:show(selected)
end

function W.PortraitPicker:hide()
    self._picker:hide()
end

function W.PortraitPicker:isVisible()
    return self._picker:isVisible()
end

function W.PortraitPicker:update(dt)
    self._picker:update(dt)
end

function W.PortraitPicker:draw()
    self._picker:draw()
end

function W.PortraitPicker:mousepressed(mx, my, button)
    return self._picker:mousepressed(mx, my, button)
end

function W.PortraitPicker:mousereleased(mx, my, button)
    return self._picker:mousereleased(mx, my, button)
end

function W.PortraitPicker:keypressed(key)
    return self._picker:keypressed(key)
end

function W.PortraitPicker:textinput(t)
    return self._picker:textinput(t)
end

function W.PortraitPicker:wheelmoved(wx, wy)
    return self._picker:wheelmoved(wx, wy)
end

function W.PortraitPicker:mousemoved(mx, my)
    return self._picker:mousemoved(mx, my)
end


-- =========================================================================
-- PROPERTYGRID
-- =========================================================================

W.PropertyGrid = {}
W.PropertyGrid.__index = W.PropertyGrid

function W.PropertyGrid.new(opts)
    opts = opts or {}
    local self = setmetatable({}, W.PropertyGrid)
    self.schema = opts.schema or {}
    self.data = opts.data or {}
    self.onChange = opts.onChange or nil
    self.fontSize = opts.fontSize or 13
    self.labelWidth = opts.labelWidth or Theme.sizes.propertyLabelWidth
    self.rowHeight = opts.rowHeight or 30
    self.categoryHeaderHeight = opts.categoryHeaderHeight or 28
    -- internal
    self._scroll = UI.ScrollContainer.new({contentHeight = 0})
    self._widgets = {}        -- key -> widget instance
    self._collapsed = {}      -- category -> bool
    self._contentHeight = 0
    self._dropdownOverlays = {}
    self._lastX = 0
    self._lastY = 0
    self._lastW = 0
    self._lastH = 0
    self._dirty = true
    return self
end

function W.PropertyGrid:setSchema(schema, data)
    self.schema = schema or {}
    self.data = data or {}
    self._widgets = {}
    self._dirty = true
end

function W.PropertyGrid:setData(data)
    self.data = data or {}
    self._dirty = true
    -- Sync widget values
    for _, field in ipairs(self.schema) do
        local w = self._widgets[field.key]
        local val = self.data[field.key]
        if w and val ~= nil then
            if field.type == "string" or field.type == "text" then
                if w.setText then w:setText(tostring(val)) end
            elseif field.type == "number" then
                if w.setValue then w:setValue(val) end
            elseif field.type == "boolean" then
                if w.setValue then w:setValue(val) end
            elseif field.type == "select" then
                if w.setValue then w:setValue(val) end
            elseif field.type == "multiselect" then
                if w.setValue then w:setValue(val) end
            elseif field.type == "tags" then
                if w.setTags then w:setTags(val) end
            elseif field.type == "color" then
                if w.setColor then w:setColor(val) end
            end
        end
    end
end

function W.PropertyGrid:_fireChange(key, value)
    self.data[key] = value
    if self.onChange then
        self.onChange(key, value, self.data)
    end
end

function W.PropertyGrid:_ensureWidget(field)
    if self._widgets[field.key] then return self._widgets[field.key] end

    local key = field.key
    local val = self.data[key]
    local w

    if field.type == "string" then
        w = UI.TextInput.new({
            text = val and tostring(val) or (field.default and tostring(field.default) or ""),
            placeholder = field.tooltip or "",
            fontSize = self.fontSize,
            onChange = function(text) self:_fireChange(key, text) end,
        })

    elseif field.type == "text" then
        w = UI.TextInput.new({
            text = val and tostring(val) or (field.default and tostring(field.default) or ""),
            placeholder = field.tooltip or "",
            fontSize = self.fontSize,
            onChange = function(text) self:_fireChange(key, text) end,
        })

    elseif field.type == "number" then
        w = W.NumberInput.new({
            value = val or field.default or 0,
            min = field.min,
            max = field.max,
            step = field.step or 1,
            fontSize = self.fontSize,
            showSlider = (field.min ~= nil and field.max ~= nil),
            showButtons = true,
            onChange = function(v) self:_fireChange(key, v) end,
        })

    elseif field.type == "boolean" then
        w = UI.Toggle.new({
            value = val ~= nil and val or (field.default or false),
            fontSize = self.fontSize,
            onChange = function(v) self:_fireChange(key, v) end,
        })

    elseif field.type == "select" then
        w = W.DropdownSelect.new({
            options = field.options or {},
            value = val or field.default,
            placeholder = field.tooltip or "Select...",
            fontSize = self.fontSize,
            onChange = function(v) self:_fireChange(key, v) end,
        })

    elseif field.type == "multiselect" then
        w = W.DropdownSelect.new({
            options = field.options or {},
            multi = true,
            selected = val or field.default or {},
            placeholder = field.tooltip or "Select...",
            fontSize = self.fontSize,
            onChange = function(v) self:_fireChange(key, v) end,
        })

    elseif field.type == "tags" then
        w = W.TagPicker.new({
            tags = val or field.default or {},
            suggestions = field.options or {},
            fontSize = self.fontSize - 1,
            onChange = function(tags) self:_fireChange(key, tags) end,
        })

    elseif field.type == "color" then
        w = W.ColorPicker.new({
            color = val or field.default or {1, 1, 1},
            fontSize = self.fontSize - 1,
            onChange = function(c) self:_fireChange(key, c) end,
        })

    elseif field.type == "table" then
        -- Expandable sub-properties: render as nested PropertyGrid
        -- Placeholder: show a toggle to expand
        w = {
            _expanded = false,
            _subGrid = nil,
            _toggleBtn = UI.Button.new({
                text = "...",
                variant = "secondary",
                fontSize = self.fontSize - 1,
            }),
        }
    end

    if w then
        self._widgets[key] = w
    end
    return w
end

function W.PropertyGrid:_isFieldVisible(field)
    if field.condition then
        local ok, result = pcall(field.condition, self.data)
        if ok then return result end
        return true
    end
    return true
end

function W.PropertyGrid:_getFieldHeight(field)
    if field.type == "text" then
        return self.rowHeight * 3
    elseif field.type == "tags" then
        return math.max(self.rowHeight * 2.5, 70)
    elseif field.type == "color" then
        return 170
    elseif field.type == "number" and field.min ~= nil and field.max ~= nil then
        return self.rowHeight + 22
    elseif field.type == "table" then
        local w = self._widgets[field.key]
        if w and w._expanded and w._subGrid then
            return self.rowHeight + 200
        end
        return self.rowHeight
    end
    return self.rowHeight
end

function W.PropertyGrid:update(dt)
    for _, w in pairs(self._widgets) do
        if w.update then w:update(dt) end
    end
end

function W.PropertyGrid:draw(x, y, w, h)
    w = w or 300
    h = h or 400

    self._lastX = x
    self._lastY = y
    self._lastW = w
    self._lastH = h

    local font = FontCache.get(self.fontSize)
    love.graphics.setFont(font)
    local pad = Theme.spacing.md
    local labelW = self.labelWidth
    local editorX = labelW + pad
    local editorW = w - editorX - pad - Theme.sizes.scrollbarWidth

    -- Calculate total content height and build layout
    local totalH = 0
    local layout = {}  -- {field, y, h, category}
    local lastCategory = nil
    self._dropdownOverlays = {}

    for _, field in ipairs(self.schema) do
        if self:_isFieldVisible(field) then
            -- Category header
            local cat = field.category or ""
            if cat ~= lastCategory then
                layout[#layout + 1] = {type = "category", category = cat, y = totalH}
                totalH = totalH + self.categoryHeaderHeight
                lastCategory = cat
            end

            -- Skip if category collapsed
            if not self._collapsed[cat] then
                self:_ensureWidget(field)
                local fh = self:_getFieldHeight(field)
                layout[#layout + 1] = {type = "field", field = field, y = totalH, h = fh}
                totalH = totalH + fh + Theme.spacing.xs
            end
        end
    end

    self._contentHeight = totalH
    self._scroll:setContentHeight(totalH)

    self._scroll:beginDraw(x, y, w, h)

    local mx, my = love.mouse.getPosition()

    for _, item in ipairs(layout) do
        if item.type == "category" then
            local catY = item.y
            local collapsed = self._collapsed[item.category] or false

            -- Category header background
            setColor(Theme.colors.panelHeader)
            love.graphics.rectangle("fill", 0, catY, w - Theme.sizes.scrollbarWidth, self.categoryHeaderHeight)
            setColor(Theme.colors.panelBorder)
            love.graphics.rectangle("fill", 0, catY + self.categoryHeaderHeight - 1, w - Theme.sizes.scrollbarWidth, 1)

            -- Expand/collapse arrow
            setColor(Theme.colors.textDim)
            local arrowGlyph = collapsed and ">" or "v"
            love.graphics.print(arrowGlyph, pad, catY + math.floor((self.categoryHeaderHeight - font:getHeight()) / 2))

            -- Category label
            setColor(Theme.colors.text)
            local catLabel = #item.category > 0 and item.category or "General"
            love.graphics.print(catLabel, pad + 14, catY + math.floor((self.categoryHeaderHeight - font:getHeight()) / 2))

        elseif item.type == "field" then
            local field = item.field
            local fy = item.y
            local fh = item.h
            local widget = self._widgets[field.key]

            -- Label
            setColor(Theme.colors.text)
            local label = field.label or field.key
            if field.required then label = label .. " *" end
            love.graphics.printf(label, pad, fy + math.floor((math.min(fh, self.rowHeight) - font:getHeight()) / 2), labelW - pad, "left")

            -- Tooltip indicator
            if field.tooltip and #field.tooltip > 0 then
                setColor(Theme.colors.textDim)
                love.graphics.print("?", labelW - 10, fy + math.floor((math.min(fh, self.rowHeight) - font:getHeight()) / 2))
            end

            -- Editor widget
            if widget then
                if field.type == "table" then
                    -- Table field: show expand toggle
                    local btnW2 = 60
                    local btnH2 = Theme.sizes.buttonHeight
                    local expanded = widget._expanded
                    local screenBtnY = y + fy - self._scroll.scrollY
                    local btnHov = pointInRect(mx, my, x + editorX, screenBtnY, btnW2, btnH2)
                    setColor(btnHov and Theme.colors.primaryHover or Theme.colors.bgLight)
                    roundRect("fill", editorX, fy, btnW2, btnH2, Theme.radius.sm)
                    setColor(Theme.colors.text)
                    local tl = expanded and "Collapse" or "Expand"
                    love.graphics.print(tl, editorX + 4, fy + math.floor((btnH2 - font:getHeight()) / 2))
                else
                    widget:draw(editorX, fy, editorW, fh)

                    -- Track dropdown overlays for later drawing
                    if field.type == "select" or field.type == "multiselect" then
                        if widget._open then
                            self._dropdownOverlays[#self._dropdownOverlays + 1] = widget
                        end
                    end
                end
            end
        end
    end

    self._scroll:endDraw()

    -- Draw dropdown overlays on top of everything
    for _, dd in ipairs(self._dropdownOverlays) do
        dd:drawDropdown()
    end
end

function W.PropertyGrid:mousepressed(mx, my, button)
    if button ~= 1 then return false end

    -- Check dropdown overlays first (they render on top)
    for i = #self._dropdownOverlays, 1, -1 do
        local dd = self._dropdownOverlays[i]
        if dd:mousepressed(mx, my, button) then return true end
    end

    -- Scrollbar
    if self._scroll:mousepressed(mx, my, button) then return true end

    if not pointInRect(mx, my, self._lastX, self._lastY, self._lastW, self._lastH) then
        return false
    end

    -- Convert mouse to content coordinates
    local relY = my - self._lastY + self._scroll.scrollY
    local pad = Theme.spacing.md

    -- Check category headers
    local lastCategory = nil
    for _, field in ipairs(self.schema) do
        if self:_isFieldVisible(field) then
            local cat = field.category or ""
            if cat ~= lastCategory then
                -- Find this category's Y position
                local catY = self:_getCategoryY(cat)
                if catY and relY >= catY and relY < catY + self.categoryHeaderHeight then
                    self._collapsed[cat] = not self._collapsed[cat]
                    return true
                end
                lastCategory = cat
            end
        end
    end

    -- Check field widgets
    for _, field in ipairs(self.schema) do
        if self:_isFieldVisible(field) then
            local cat = field.category or ""
            if not self._collapsed[cat] then
                local widget = self._widgets[field.key]
                if widget then
                    if field.type == "table" then
                        -- Toggle expand
                        local fy = self:_getFieldY(field.key)
                        if fy and relY >= fy and relY < fy + self.rowHeight then
                            widget._expanded = not widget._expanded
                            return true
                        end
                    elseif widget.mousepressed then
                        if widget:mousepressed(mx, my, button) then
                            return true
                        end
                    end
                end
            end
        end
    end

    return true
end

function W.PropertyGrid:_getCategoryY(targetCat)
    local totalH = 0
    local lastCategory = nil
    for _, field in ipairs(self.schema) do
        if self:_isFieldVisible(field) then
            local cat = field.category or ""
            if cat ~= lastCategory then
                if cat == targetCat then return totalH end
                totalH = totalH + self.categoryHeaderHeight
                lastCategory = cat
            end
            if not self._collapsed[cat] then
                totalH = totalH + self:_getFieldHeight(field) + Theme.spacing.xs
            end
        end
    end
    return nil
end

function W.PropertyGrid:_getFieldY(targetKey)
    local totalH = 0
    local lastCategory = nil
    for _, field in ipairs(self.schema) do
        if self:_isFieldVisible(field) then
            local cat = field.category or ""
            if cat ~= lastCategory then
                totalH = totalH + self.categoryHeaderHeight
                lastCategory = cat
            end
            if not self._collapsed[cat] then
                if field.key == targetKey then return totalH end
                totalH = totalH + self:_getFieldHeight(field) + Theme.spacing.xs
            end
        end
    end
    return nil
end

function W.PropertyGrid:mousereleased(mx, my, button)
    if self._scroll:mousereleased(mx, my, button) then return true end
    for _, field in ipairs(self.schema) do
        local widget = self._widgets[field.key]
        if widget and widget.mousereleased then
            if widget:mousereleased(mx, my, button) then return true end
        end
    end
    return false
end

function W.PropertyGrid:mousemoved(mx, my)
    if self._scroll:mousemoved(mx, my) then return true end
    for _, field in ipairs(self.schema) do
        local widget = self._widgets[field.key]
        if widget and widget.mousemoved then
            if widget:mousemoved(mx, my) then return true end
        end
    end
    return false
end

function W.PropertyGrid:wheelmoved(wx, wy)
    -- Dropdown scroll takes priority
    for _, dd in ipairs(self._dropdownOverlays) do
        if dd:wheelmoved(wx, wy) then return true end
    end
    return self._scroll:wheelmoved(wx, wy)
end

function W.PropertyGrid:keypressed(key)
    for _, field in ipairs(self.schema) do
        local widget = self._widgets[field.key]
        if widget and widget.keypressed then
            if widget:keypressed(key) then return true end
        end
    end
    return false
end

function W.PropertyGrid:textinput(t)
    for _, field in ipairs(self.schema) do
        local widget = self._widgets[field.key]
        if widget and widget.textinput then
            if widget:textinput(t) then return true end
        end
    end
    return false
end

function W.PropertyGrid:getData()
    return self.data
end


-- =========================================================================
-- Module export
-- =========================================================================

return {
    NumberInput     = W.NumberInput,
    SearchBar       = W.SearchBar,
    TagPicker       = W.TagPicker,
    DropdownSelect  = W.DropdownSelect,
    ColorPicker     = W.ColorPicker,
    TreeView        = W.TreeView,
    IconPicker      = W.IconPicker,
    PortraitPicker  = W.PortraitPicker,
    PropertyGrid    = W.PropertyGrid,
}
