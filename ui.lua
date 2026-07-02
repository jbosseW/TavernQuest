-- ui.lua - Comprehensive UI Component Library for LÖVE2D
-- Provides reusable interactive components with theming, animations, and event handling
-- Compatible with existing game patterns and modules

local UI = {}

-- ============================================================================
-- THEME SYSTEM
-- ============================================================================

UI.theme = {
    colors = {
        bg = {0.08, 0.10, 0.14},
        bgLight = {0.12, 0.14, 0.20},
        bgDark = {0.05, 0.06, 0.09},
        panel = {0.10, 0.12, 0.18},
        panelBorder = {0.25, 0.30, 0.40},

        primary = {0.90, 0.65, 0.20},
        primaryHover = {1.0, 0.75, 0.30},
        secondary = {0.30, 0.50, 0.80},
        secondaryHover = {0.40, 0.60, 0.90},

        success = {0.30, 0.80, 0.40},
        warning = {0.90, 0.70, 0.20},
        danger = {0.80, 0.25, 0.25},
        dangerHover = {0.90, 0.35, 0.35},
        info = {0.40, 0.70, 0.90},

        text = {0.92, 0.92, 0.92},
        textDim = {0.55, 0.55, 0.60},
        textAccent = {1.0, 0.85, 0.30},

        scrollbar = {0.30, 0.30, 0.35},
        scrollbarThumb = {0.50, 0.50, 0.55},

        overlay = {0, 0, 0, 0.75},
    },
    spacing = {
        xs = 4,
        sm = 8,
        md = 12,
        lg = 16,
        xl = 24,
        xxl = 32
    },
    radius = {
        sm = 4,
        md = 8,
        lg = 12,
        pill = 999
    },
    border = {
        thin = 1,
        normal = 2,
        thick = 3
    },
}

-- ============================================================================
-- FONT CACHE SYSTEM
-- ============================================================================

UI.fonts = {}
local FontCache = require("fontcache")

function UI.fonts.get(size)
    return FontCache.get(size or 16)
end

-- ============================================================================
-- ANIMATION SYSTEM
-- ============================================================================

UI.anim = {}
UI.anim.tweens = {}

-- Easing functions
local easingFunctions = {
    linear = function(t) return t end,

    easeIn = function(t) return t * t end,

    easeOut = function(t) return t * (2 - t) end,

    easeInOut = function(t)
        if t < 0.5 then
            return 2 * t * t
        else
            return -1 + (4 - 2 * t) * t
        end
    end,

    bounce = function(t)
        if t < 0.5 then
            return 8 * t * t * t * t
        else
            local f = (t - 1)
            return 1 + 8 * f * f * f * f
        end
    end,

    elastic = function(t)
        if t == 0 or t == 1 then return t end
        local p = 0.3
        local s = p / 4
        return math.pow(2, -10 * t) * math.sin((t - s) * (2 * math.pi) / p) + 1
    end,
}

function UI.anim.tween(target, props, duration, easing, onComplete)
    easing = easing or "easeOut"
    duration = duration or 0.3

    local tween = {
        target = target,
        props = {},
        elapsed = 0,
        duration = duration,
        easing = easingFunctions[easing] or easingFunctions.easeOut,
        onComplete = onComplete,
    }

    -- Store start and end values
    for key, endValue in pairs(props) do
        tween.props[key] = {
            start = target[key] or 0,
            change = endValue - (target[key] or 0),
        }
    end

    table.insert(UI.anim.tweens, tween)
    return tween
end

function UI.anim.update(dt)
    for i = #UI.anim.tweens, 1, -1 do
        local tween = UI.anim.tweens[i]
        tween.elapsed = tween.elapsed + dt

        local t = math.min(tween.elapsed / tween.duration, 1)
        local easedT = tween.easing(t)

        -- Update all properties
        for key, prop in pairs(tween.props) do
            tween.target[key] = prop.start + prop.change * easedT
        end

        -- Remove completed tweens
        if t >= 1 then
            if tween.onComplete then
                tween.onComplete()
            end
            table.remove(UI.anim.tweens, i)
        end
    end
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

local function isPointInRect(px, py, x, y, w, h)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

local function clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function drawRoundedRect(mode, x, y, w, h, radius)
    radius = math.min(radius, w / 2, h / 2)

    if radius <= 0 then
        love.graphics.rectangle(mode, x, y, w, h)
        return
    end

    -- Use LOVE2D's built-in rounded rectangle support to avoid
    -- seams from overlapping shapes when using semi-transparent colors
    love.graphics.rectangle(mode, x, y, w, h, radius, radius)
end

-- ============================================================================
-- BUTTON COMPONENT
-- ============================================================================

UI.Button = {}

function UI.Button.new(opts)
    local btn = {
        x = opts.x or 0,
        y = opts.y or 0,
        w = opts.w or 120,
        h = opts.h or 36,
        text = opts.text or "Button",
        variant = opts.variant or "primary",
        disabled = opts.disabled or false,
        icon = opts.icon or nil,
        onClick = opts.onClick or function() end,

        -- State
        hovered = false,
        pressed = false,
        hoverAlpha = 0,
        pressScale = 1,
    }

    function btn:update(dt)
        if self.disabled then
            self.hoverAlpha = 0
            return
        end

        local mx, my = love.mouse.getPosition()
        local wasHovered = self.hovered
        self.hovered = isPointInRect(mx, my, self.x, self.y, self.w, self.h)

        -- Animate hover
        local targetAlpha = self.hovered and 1 or 0
        if self.hoverAlpha ~= targetAlpha then
            local speed = 8
            self.hoverAlpha = lerp(self.hoverAlpha, targetAlpha, dt * speed)
            if math.abs(self.hoverAlpha - targetAlpha) < 0.01 then
                self.hoverAlpha = targetAlpha
            end
        end
    end

    function btn:draw()
        love.graphics.push()

        -- Apply press scale
        if self.pressed and not self.disabled then
            local centerX = self.x + self.w / 2
            local centerY = self.y + self.h / 2
            love.graphics.translate(centerX, centerY)
            love.graphics.scale(0.96, 0.96)
            love.graphics.translate(-centerX, -centerY)
        end

        -- Determine colors based on variant
        local bgColor, hoverColor, textColor
        if self.variant == "primary" then
            bgColor = UI.theme.colors.primary
            hoverColor = UI.theme.colors.primaryHover
            textColor = UI.theme.colors.bg
        elseif self.variant == "danger" then
            bgColor = UI.theme.colors.danger
            hoverColor = UI.theme.colors.dangerHover
            textColor = UI.theme.colors.text
        elseif self.variant == "success" then
            bgColor = UI.theme.colors.success
            hoverColor = UI.theme.colors.success
            textColor = UI.theme.colors.text
        elseif self.variant == "ghost" then
            bgColor = {0, 0, 0, 0}
            hoverColor = UI.theme.colors.bgLight
            textColor = UI.theme.colors.text
        else
            bgColor = UI.theme.colors.secondary
            hoverColor = UI.theme.colors.secondaryHover
            textColor = UI.theme.colors.text
        end

        -- Blend base and hover colors
        local finalColor = {
            lerp(bgColor[1], hoverColor[1], self.hoverAlpha),
            lerp(bgColor[2], hoverColor[2], self.hoverAlpha),
            lerp(bgColor[3], hoverColor[3], self.hoverAlpha),
            self.disabled and 0.5 or 1
        }

        -- Draw background
        love.graphics.setColor(finalColor)
        drawRoundedRect("fill", self.x, self.y, self.w, self.h, UI.theme.radius.md)

        -- Draw border for ghost variant
        if self.variant == "ghost" then
            love.graphics.setColor(UI.theme.colors.panelBorder)
            love.graphics.setLineWidth(UI.theme.border.normal)
            drawRoundedRect("line", self.x, self.y, self.w, self.h, UI.theme.radius.md)
            love.graphics.setLineWidth(1)
        end

        -- Draw text
        local font = UI.fonts.get(16)
        love.graphics.setFont(font)
        local textW = font:getWidth(self.text)
        local textH = font:getHeight()

        love.graphics.setColor(self.disabled and UI.theme.colors.textDim or textColor)
        love.graphics.print(
            self.text,
            math.floor(self.x + (self.w - textW) / 2),
            math.floor(self.y + (self.h - textH) / 2)
        )

        love.graphics.pop()
        love.graphics.setColor(1, 1, 1, 1)
    end

    function btn:mousepressed(x, y, button)
        if button ~= 1 or self.disabled then return false end
        if isPointInRect(x, y, self.x, self.y, self.w, self.h) then
            self.pressed = true
            return true
        end
        return false
    end

    function btn:mousereleased(x, y, button)
        if button ~= 1 or self.disabled then return false end
        if self.pressed then
            self.pressed = false
            if isPointInRect(x, y, self.x, self.y, self.w, self.h) then
                self.onClick()
                return true
            end
        end
        return false
    end

    function btn:keypressed(key)
        return false
    end

    return btn
end

-- ============================================================================
-- PANEL COMPONENT
-- ============================================================================

UI.Panel = {}

function UI.Panel.new(opts)
    local panel = {
        x = opts.x or 0,
        y = opts.y or 0,
        w = opts.w or 400,
        h = opts.h or 300,
        title = opts.title or nil,
        showClose = opts.showClose or false,
        borderColor = opts.borderColor or UI.theme.colors.panelBorder,
        children = opts.children or {},
        onClose = opts.onClose or nil,

        titleBarHeight = 40,
        closeButton = nil,
    }

    -- Create close button if needed
    if panel.showClose then
        panel.closeButton = UI.Button.new({
            x = panel.x + panel.w - 36,
            y = panel.y + 4,
            w = 32,
            h = 32,
            text = "X",
            variant = "ghost",
            onClick = function()
                if panel.onClose then
                    panel.onClose()
                end
            end
        })
    end

    function panel:update(dt)
        if self.closeButton then
            self.closeButton.x = self.x + self.w - 36
            self.closeButton.y = self.y + 4
            self.closeButton:update(dt)
        end

        for _, child in ipairs(self.children) do
            if child.update then
                child:update(dt)
            end
        end
    end

    function panel:draw()
        -- Draw main panel background
        love.graphics.setColor(UI.theme.colors.panel)
        drawRoundedRect("fill", self.x, self.y, self.w, self.h, UI.theme.radius.lg)

        -- Draw border
        love.graphics.setColor(self.borderColor)
        love.graphics.setLineWidth(UI.theme.border.normal)
        drawRoundedRect("line", self.x, self.y, self.w, self.h, UI.theme.radius.lg)
        love.graphics.setLineWidth(1)

        -- Draw title bar if title exists
        if self.title then
            love.graphics.setColor(UI.theme.colors.bgDark)
            drawRoundedRect("fill", self.x, self.y, self.w, self.titleBarHeight, UI.theme.radius.lg)
            love.graphics.rectangle("fill", self.x, self.y + self.titleBarHeight - UI.theme.radius.lg, self.w, UI.theme.radius.lg)

            local font = UI.fonts.get(18)
            love.graphics.setFont(font)
            love.graphics.setColor(UI.theme.colors.textAccent)
            love.graphics.print(self.title, self.x + UI.theme.spacing.lg, self.y + (self.titleBarHeight - font:getHeight()) / 2)
        end

        -- Draw close button
        if self.closeButton then
            self.closeButton:draw()
        end

        -- Draw children
        for _, child in ipairs(self.children) do
            if child.draw then
                child:draw()
            end
        end

        love.graphics.setColor(1, 1, 1, 1)
    end

    function panel:mousepressed(x, y, button)
        if self.closeButton and self.closeButton:mousepressed(x, y, button) then
            return true
        end

        for _, child in ipairs(self.children) do
            if child.mousepressed and child:mousepressed(x, y, button) then
                return true
            end
        end

        return isPointInRect(x, y, self.x, self.y, self.w, self.h)
    end

    function panel:mousereleased(x, y, button)
        if self.closeButton and self.closeButton.mousereleased then
            self.closeButton:mousereleased(x, y, button)
        end

        for _, child in ipairs(self.children) do
            if child.mousereleased then
                child:mousereleased(x, y, button)
            end
        end
    end

    function panel:keypressed(key)
        for _, child in ipairs(self.children) do
            if child.keypressed and child:keypressed(key) then
                return true
            end
        end
        return false
    end

    return panel
end

-- ============================================================================
-- TABBAR COMPONENT
-- ============================================================================

UI.TabBar = {}

function UI.TabBar.new(opts)
    local tabBar = {
        x = opts.x or 0,
        y = opts.y or 0,
        w = opts.w or 400,
        tabs = opts.tabs or {},
        activeTab = opts.activeTab or (opts.tabs[1] and opts.tabs[1].id) or nil,
        onChange = opts.onChange or function() end,

        height = 44,
        indicatorX = 0,
        indicatorW = 0,
    }

    function tabBar:update(dt)
        -- Animate indicator
        local activeIndex = 1
        for i, tab in ipairs(self.tabs) do
            if tab.id == self.activeTab then
                activeIndex = i
                break
            end
        end

        if #self.tabs == 0 then return end
        local tabWidth = self.w / #self.tabs
        local targetX = self.x + (activeIndex - 1) * tabWidth
        local targetW = tabWidth

        if self.indicatorX == 0 then
            self.indicatorX = targetX
            self.indicatorW = targetW
        else
            local speed = 10
            self.indicatorX = lerp(self.indicatorX, targetX, dt * speed)
            self.indicatorW = lerp(self.indicatorW, targetW, dt * speed)
        end
    end

    function tabBar:draw()
        -- Draw background
        love.graphics.setColor(UI.theme.colors.bgDark)
        love.graphics.rectangle("fill", self.x, self.y, self.w, self.height)

        -- Draw tabs
        if #self.tabs == 0 then return end
        local tabWidth = self.w / #self.tabs
        local font = UI.fonts.get(16)
        love.graphics.setFont(font)

        for i, tab in ipairs(self.tabs) do
            local tabX = self.x + (i - 1) * tabWidth
            local isActive = tab.id == self.activeTab

            -- Check hover
            local mx, my = love.mouse.getPosition()
            local isHovered = isPointInRect(mx, my, tabX, self.y, tabWidth, self.height)

            -- Draw hover background
            if isHovered and not isActive then
                love.graphics.setColor(UI.theme.colors.bgLight)
                love.graphics.rectangle("fill", tabX, self.y, tabWidth, self.height)
            end

            -- Draw text
            local textColor = isActive and UI.theme.colors.textAccent or UI.theme.colors.text
            love.graphics.setColor(textColor)
            local textW = font:getWidth(tab.label)
            local textH = font:getHeight()
            love.graphics.print(
                tab.label,
                math.floor(tabX + (tabWidth - textW) / 2),
                math.floor(self.y + (self.height - textH) / 2)
            )
        end

        -- Draw active indicator line
        love.graphics.setColor(UI.theme.colors.primary)
        love.graphics.rectangle("fill", self.indicatorX, self.y + self.height - 3, self.indicatorW, 3)

        love.graphics.setColor(1, 1, 1, 1)
    end

    function tabBar:mousepressed(x, y, button)
        if button ~= 1 then return false end
        if not isPointInRect(x, y, self.x, self.y, self.w, self.height) then
            return false
        end

        if #self.tabs == 0 then return false end
        local tabWidth = self.w / #self.tabs
        local clickedIndex = math.floor((x - self.x) / tabWidth) + 1

        if clickedIndex >= 1 and clickedIndex <= #self.tabs then
            local newTab = self.tabs[clickedIndex].id
            if newTab ~= self.activeTab then
                self.activeTab = newTab
                self.onChange(newTab)
            end
            return true
        end

        return false
    end

    function tabBar:keypressed(key)
        return false
    end

    return tabBar
end

-- ============================================================================
-- SCROLL CONTAINER COMPONENT
-- ============================================================================

UI.ScrollContainer = {}

function UI.ScrollContainer.new(opts)
    local container = {
        x = opts.x or 0,
        y = opts.y or 0,
        w = opts.w or 300,
        h = opts.h or 400,
        contentHeight = opts.contentHeight or 600,

        scrollY = 0,
        scrollVelocity = 0,
        draggingScrollbar = false,
        dragStartY = 0,
        dragStartScroll = 0,

        scrollbarWidth = 12,
        scrollbarPadding = 4,
    }

    function container:update(dt)
        -- Apply momentum
        if not self.draggingScrollbar then
            self.scrollVelocity = self.scrollVelocity * 0.9
            self.scrollY = self.scrollY + self.scrollVelocity
        end

        -- Clamp scroll and kill velocity at boundaries
        local maxScroll = math.max(0, self.contentHeight - self.h)
        local clampedY = clamp(self.scrollY, 0, maxScroll)
        if clampedY ~= self.scrollY then
            self.scrollVelocity = 0
            self.scrollY = clampedY
        end

        if math.abs(self.scrollVelocity) < 0.1 then
            self.scrollVelocity = 0
        end
    end

    function container:draw()
        -- Draw scrollbar background
        if self.contentHeight > self.h then
            local sbX = self.x + self.w - self.scrollbarWidth - self.scrollbarPadding
            love.graphics.setColor(UI.theme.colors.scrollbar)
            drawRoundedRect("fill", sbX, self.y, self.scrollbarWidth, self.h, UI.theme.radius.sm)

            -- Draw thumb
            local maxScroll = self.contentHeight - self.h
            local thumbHeight = math.max(20, (self.h / self.contentHeight) * self.h)
            local thumbY = self.y + (self.scrollY / maxScroll) * (self.h - thumbHeight)

            local mx, my = love.mouse.getPosition()
            local thumbHovered = isPointInRect(mx, my, sbX, thumbY, self.scrollbarWidth, thumbHeight)

            if thumbHovered or self.draggingScrollbar then
                love.graphics.setColor(UI.theme.colors.scrollbarThumb)
            else
                love.graphics.setColor(UI.theme.colors.scrollbarThumb[1], UI.theme.colors.scrollbarThumb[2], UI.theme.colors.scrollbarThumb[3], 0.7)
            end

            drawRoundedRect("fill", sbX, thumbY, self.scrollbarWidth, thumbHeight, UI.theme.radius.sm)
        end

        love.graphics.setColor(1, 1, 1, 1)
    end

    function container:mousepressed(x, y, button)
        if button ~= 1 then return false end

        if self.contentHeight > self.h then
            local sbX = self.x + self.w - self.scrollbarWidth - self.scrollbarPadding
            local maxScroll = self.contentHeight - self.h
            local thumbHeight = math.max(20, (self.h / self.contentHeight) * self.h)
            local thumbY = self.y + (self.scrollY / maxScroll) * (self.h - thumbHeight)

            if isPointInRect(x, y, sbX, thumbY, self.scrollbarWidth, thumbHeight) then
                self.draggingScrollbar = true
                self.dragStartY = y
                self.dragStartScroll = self.scrollY
                return true
            end
        end

        return false
    end

    function container:mousereleased(x, y, button)
        if button == 1 then
            self.draggingScrollbar = false
        end
    end

    function container:mousemoved(x, y, dx, dy)
        if self.draggingScrollbar then
            local maxScroll = self.contentHeight - self.h
            local thumbHeight = math.max(20, (self.h / self.contentHeight) * self.h)
            local scrollableHeight = self.h - thumbHeight

            local delta = y - self.dragStartY
            local scrollDelta = (delta / scrollableHeight) * maxScroll

            self.scrollY = clamp(self.dragStartScroll + scrollDelta, 0, maxScroll)
        end
    end

    function container:wheelmoved(x, y)
        local maxScroll = math.max(0, self.contentHeight - self.h)
        -- Prevent accumulating velocity when already at a scroll boundary
        if (self.scrollY <= 0 and y > 0) or (self.scrollY >= maxScroll and y < 0) then
            self.scrollVelocity = 0
            return
        end
        self.scrollVelocity = self.scrollVelocity - y * 30
        -- Immediately clamp scroll position and velocity to prevent overshoot
        self.scrollY = clamp(self.scrollY, 0, maxScroll)
    end

    function container:keypressed(key)
        return false
    end

    function container:scrollTo(y)
        self.scrollY = clamp(y, 0, math.max(0, self.contentHeight - self.h))
        self.scrollVelocity = 0
    end

    function container:getScroll()
        return self.scrollY
    end

    return container
end

-- ============================================================================
-- TEXT INPUT COMPONENT
-- ============================================================================

UI.TextInput = {}

function UI.TextInput.new(opts)
    local input = {
        x = opts.x or 0,
        y = opts.y or 0,
        w = opts.w or 200,
        h = opts.h or 36,
        placeholder = opts.placeholder or "",
        text = opts.text or "",
        onChange = opts.onChange or function() end,
        onSubmit = opts.onSubmit or function() end,

        focused = false,
        cursorBlink = 0,
        cursorVisible = true,
    }

    function input:update(dt)
        if self.focused then
            self.cursorBlink = self.cursorBlink + dt
            if self.cursorBlink >= 0.5 then
                self.cursorBlink = 0
                self.cursorVisible = not self.cursorVisible
            end
        else
            self.cursorVisible = false
        end
    end

    function input:draw()
        -- Draw background
        local bgColor = self.focused and UI.theme.colors.bgLight or UI.theme.colors.bg
        love.graphics.setColor(bgColor)
        drawRoundedRect("fill", self.x, self.y, self.w, self.h, UI.theme.radius.md)

        -- Draw border
        local borderColor = self.focused and UI.theme.colors.primary or UI.theme.colors.panelBorder
        love.graphics.setColor(borderColor)
        love.graphics.setLineWidth(UI.theme.border.normal)
        drawRoundedRect("line", self.x, self.y, self.w, self.h, UI.theme.radius.md)
        love.graphics.setLineWidth(1)

        -- Draw text or placeholder
        local font = UI.fonts.get(16)
        love.graphics.setFont(font)
        local textY = self.y + (self.h - font:getHeight()) / 2

        if self.text == "" and not self.focused then
            love.graphics.setColor(UI.theme.colors.textDim)
            love.graphics.print(self.placeholder, self.x + UI.theme.spacing.md, textY)
        else
            love.graphics.setColor(UI.theme.colors.text)
            love.graphics.print(self.text, self.x + UI.theme.spacing.md, textY)

            -- Draw cursor
            if self.focused and self.cursorVisible then
                local textWidth = font:getWidth(self.text)
                love.graphics.setColor(UI.theme.colors.textAccent)
                love.graphics.rectangle("fill", self.x + UI.theme.spacing.md + textWidth + 2, textY, 2, font:getHeight())
            end
        end

        love.graphics.setColor(1, 1, 1, 1)
    end

    function input:mousepressed(x, y, button)
        if button ~= 1 then return false end
        self.focused = isPointInRect(x, y, self.x, self.y, self.w, self.h)
        self.cursorBlink = 0
        self.cursorVisible = true
        return self.focused
    end

    function input:keypressed(key)
        if not self.focused then return false end

        if key == "backspace" then
            if #self.text > 0 then
                self.text = self.text:sub(1, -2)
                self.onChange(self.text)
            end
            return true
        elseif key == "return" or key == "kpenter" then
            self.onSubmit(self.text)
            return true
        elseif key == "escape" then
            self.focused = false
            return true
        end

        return false
    end

    function input:textinput(text)
        if not self.focused then return false end
        self.text = self.text .. text
        self.onChange(self.text)
        self.cursorBlink = 0
        self.cursorVisible = true
        return true
    end

    return input
end

-- ============================================================================
-- SLIDER COMPONENT
-- ============================================================================

UI.Slider = {}

function UI.Slider.new(opts)
    local slider = {
        x = opts.x or 0,
        y = opts.y or 0,
        w = opts.w or 200,
        min = opts.min or 0,
        max = opts.max or 100,
        step = opts.step or 1,
        value = opts.value or 50,
        label = opts.label or "",
        onChange = opts.onChange or function() end,

        dragging = false,
        height = 24,
        knobRadius = 10,
    }

    function slider:update(dt)
        if self.dragging then
            local mx = love.mouse.getX()
            local t = clamp((mx - self.x) / self.w, 0, 1)
            local rawValue = self.min + t * (self.max - self.min)
            local newValue = math.floor(rawValue / self.step + 0.5) * self.step

            if newValue ~= self.value then
                self.value = clamp(newValue, self.min, self.max)
                self.onChange(self.value)
            end
        end
    end

    function slider:draw()
        local centerY = self.y + self.height / 2
        local trackHeight = 6

        -- Draw label
        if self.label ~= "" then
            local font = UI.fonts.get(14)
            love.graphics.setFont(font)
            love.graphics.setColor(UI.theme.colors.text)
            love.graphics.print(self.label, self.x, self.y - 20)
        end

        -- Draw track background
        love.graphics.setColor(UI.theme.colors.bgDark)
        drawRoundedRect("fill", self.x, centerY - trackHeight / 2, self.w, trackHeight, UI.theme.radius.sm)

        -- Draw fill
        local range = self.max - self.min
        local t = range ~= 0 and (self.value - self.min) / range or 0
        local fillWidth = self.w * t
        love.graphics.setColor(UI.theme.colors.primary)
        drawRoundedRect("fill", self.x, centerY - trackHeight / 2, fillWidth, trackHeight, UI.theme.radius.sm)

        -- Draw knob
        local knobX = self.x + fillWidth
        local mx, my = love.mouse.getPosition()
        local knobHovered = math.sqrt((mx - knobX) ^ 2 + (my - centerY) ^ 2) < self.knobRadius

        love.graphics.setColor((knobHovered or self.dragging) and UI.theme.colors.primaryHover or UI.theme.colors.primary)
        love.graphics.circle("fill", knobX, centerY, self.knobRadius)

        -- Draw value text
        local font = UI.fonts.get(14)
        love.graphics.setFont(font)
        love.graphics.setColor(UI.theme.colors.textAccent)
        local valueText = tostring(self.value)
        love.graphics.print(valueText, self.x + self.w + UI.theme.spacing.md, self.y + (self.height - font:getHeight()) / 2)

        love.graphics.setColor(1, 1, 1, 1)
    end

    function slider:mousepressed(x, y, button)
        if button ~= 1 then return false end

        local centerY = self.y + self.height / 2
        if isPointInRect(x, y, self.x - self.knobRadius, self.y, self.w + 2 * self.knobRadius, self.height) then
            self.dragging = true

            local t = clamp((x - self.x) / self.w, 0, 1)
            local rawValue = self.min + t * (self.max - self.min)
            self.value = clamp(math.floor(rawValue / self.step + 0.5) * self.step, self.min, self.max)
            self.onChange(self.value)

            return true
        end

        return false
    end

    function slider:mousereleased(x, y, button)
        if button == 1 then
            self.dragging = false
        end
    end

    function slider:keypressed(key)
        return false
    end

    return slider
end

-- ============================================================================
-- TOGGLE COMPONENT
-- ============================================================================

UI.Toggle = {}

function UI.Toggle.new(opts)
    local toggle = {
        x = opts.x or 0,
        y = opts.y or 0,
        label = opts.label or "",
        value = opts.value or false,
        onChange = opts.onChange or function() end,

        width = 50,
        height = 26,
        knobX = 0,
    }

    -- Initialize knob position
    toggle.knobX = toggle.value and toggle.width - toggle.height or 0

    function toggle:update(dt)
        -- Animate knob
        local targetX = self.value and (self.width - self.height) or 0
        if math.abs(self.knobX - targetX) > 0.5 then
            local speed = 12
            self.knobX = lerp(self.knobX, targetX, dt * speed)
        else
            self.knobX = targetX
        end
    end

    function toggle:draw()
        local toggleX = self.x

        -- Draw label
        if self.label ~= "" then
            local font = UI.fonts.get(16)
            love.graphics.setFont(font)
            love.graphics.setColor(UI.theme.colors.text)
            love.graphics.print(self.label, self.x, self.y + (self.height - font:getHeight()) / 2)
            toggleX = self.x + font:getWidth(self.label) + UI.theme.spacing.md
        end

        -- Draw track
        local trackColor = self.value and UI.theme.colors.success or UI.theme.colors.bgDark
        love.graphics.setColor(trackColor)
        drawRoundedRect("fill", toggleX, self.y, self.width, self.height, UI.theme.radius.pill)

        -- Draw knob
        local knobSize = self.height - 4
        love.graphics.setColor(UI.theme.colors.text)
        love.graphics.circle("fill", toggleX + self.knobX + self.height / 2, self.y + self.height / 2, knobSize / 2)

        love.graphics.setColor(1, 1, 1, 1)
    end

    function toggle:mousepressed(x, y, button)
        if button ~= 1 then return false end

        local toggleX = self.x
        if self.label ~= "" then
            local font = UI.fonts.get(16)
            toggleX = self.x + font:getWidth(self.label) + UI.theme.spacing.md
        end

        if isPointInRect(x, y, toggleX, self.y, self.width, self.height) then
            self.value = not self.value
            self.onChange(self.value)

            -- Animate with tween
            UI.anim.tween(self, {knobX = self.value and (self.width - self.height) or 0}, 0.2, "easeOut")

            return true
        end

        return false
    end

    function toggle:keypressed(key)
        return false
    end

    return toggle
end

-- ============================================================================
-- PROGRESS BAR COMPONENT
-- ============================================================================

UI.ProgressBar = {}

function UI.ProgressBar.new(opts)
    local bar = {
        x = opts.x or 0,
        y = opts.y or 0,
        w = opts.w or 200,
        h = opts.h or 24,
        value = opts.value or 0,
        label = opts.label or nil,
        colorOverride = opts.colorOverride or nil,

        animatedValue = opts.value or 0,
    }

    function bar:update(dt)
        -- Animate value changes
        if math.abs(self.animatedValue - self.value) > 0.001 then
            local speed = 5
            self.animatedValue = lerp(self.animatedValue, self.value, dt * speed)
        else
            self.animatedValue = self.value
        end
    end

    function bar:draw()
        -- Determine color
        local fillColor
        if self.colorOverride then
            fillColor = self.colorOverride
        elseif self.value > 0.6 then
            fillColor = UI.theme.colors.success
        elseif self.value > 0.3 then
            fillColor = UI.theme.colors.warning
        else
            fillColor = UI.theme.colors.danger
        end

        -- Draw background
        love.graphics.setColor(UI.theme.colors.bgDark)
        drawRoundedRect("fill", self.x, self.y, self.w, self.h, UI.theme.radius.sm)

        -- Draw fill
        local fillWidth = self.w * clamp(self.animatedValue, 0, 1)
        if fillWidth > 0 then
            love.graphics.setColor(fillColor)
            drawRoundedRect("fill", self.x, self.y, fillWidth, self.h, UI.theme.radius.sm)
        end

        -- Draw label
        if self.label then
            local font = UI.fonts.get(14)
            love.graphics.setFont(font)
            love.graphics.setColor(UI.theme.colors.text)
            local textW = font:getWidth(self.label)
            local textH = font:getHeight()
            love.graphics.print(self.label, math.floor(self.x + (self.w - textW) / 2), math.floor(self.y + (self.h - textH) / 2))
        end

        love.graphics.setColor(1, 1, 1, 1)
    end

    function bar:mousepressed(x, y, button)
        return false
    end

    function bar:keypressed(key)
        return false
    end

    return bar
end

-- ============================================================================
-- MODAL COMPONENT
-- ============================================================================

UI.Modal = {}

function UI.Modal.new(opts)
    local modal = {
        title = opts.title or "Modal",
        message = opts.message or "",
        variant = opts.variant or "confirm",
        onConfirm = opts.onConfirm or function() end,
        onCancel = opts.onCancel or function() end,
        children = opts.children or {},

        visible = true,
        width = opts.width or 400,
        height = opts.height or 200,
        confirmButton = nil,
        cancelButton = nil,
    }

    -- Create buttons based on variant
    if modal.variant == "confirm" then
        modal.confirmButton = UI.Button.new({
            x = 0, y = 0, w = 100, h = 36,
            text = "Confirm",
            variant = "primary",
            onClick = function()
                modal.visible = false
                modal.onConfirm()
            end
        })

        modal.cancelButton = UI.Button.new({
            x = 0, y = 0, w = 100, h = 36,
            text = "Cancel",
            variant = "ghost",
            onClick = function()
                modal.visible = false
                modal.onCancel()
            end
        })
    elseif modal.variant == "alert" then
        modal.confirmButton = UI.Button.new({
            x = 0, y = 0, w = 100, h = 36,
            text = "OK",
            variant = "primary",
            onClick = function()
                modal.visible = false
                modal.onConfirm()
            end
        })
    end

    function modal:update(dt)
        if not self.visible then return end

        if self.confirmButton then
            self.confirmButton:update(dt)
        end
        if self.cancelButton then
            self.cancelButton:update(dt)
        end

        for _, child in ipairs(self.children) do
            if child.update then
                child:update(dt)
            end
        end
    end

    function modal:draw()
        if not self.visible then return end

        local screenW, screenH = love.graphics.getDimensions()

        -- Draw overlay
        love.graphics.setColor(UI.theme.colors.overlay)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)

        -- Calculate modal position
        local modalX = (screenW - self.width) / 2
        local modalY = (screenH - self.height) / 2

        -- Draw modal background
        love.graphics.setColor(UI.theme.colors.panel)
        drawRoundedRect("fill", modalX, modalY, self.width, self.height, UI.theme.radius.lg)

        -- Draw border
        love.graphics.setColor(UI.theme.colors.panelBorder)
        love.graphics.setLineWidth(UI.theme.border.normal)
        drawRoundedRect("line", modalX, modalY, self.width, self.height, UI.theme.radius.lg)
        love.graphics.setLineWidth(1)

        -- Draw title
        local font = UI.fonts.get(20)
        love.graphics.setFont(font)
        love.graphics.setColor(UI.theme.colors.textAccent)
        love.graphics.print(self.title, modalX + UI.theme.spacing.lg, modalY + UI.theme.spacing.lg)

        -- Draw message
        if self.message ~= "" then
            local messageFont = UI.fonts.get(16)
            love.graphics.setFont(messageFont)
            love.graphics.setColor(UI.theme.colors.text)
            love.graphics.printf(
                self.message,
                modalX + UI.theme.spacing.lg,
                modalY + 60,
                self.width - 2 * UI.theme.spacing.lg,
                "left"
            )
        end

        -- Draw custom children
        for _, child in ipairs(self.children) do
            if child.draw then
                child:draw()
            end
        end

        -- Draw buttons
        local buttonY = modalY + self.height - 50

        if self.variant == "confirm" and self.confirmButton and self.cancelButton then
            local buttonSpacing = UI.theme.spacing.md
            local totalButtonWidth = 100 * 2 + buttonSpacing
            local buttonStartX = modalX + (self.width - totalButtonWidth) / 2

            self.cancelButton.x = buttonStartX
            self.cancelButton.y = buttonY
            self.cancelButton:draw()

            self.confirmButton.x = buttonStartX + 100 + buttonSpacing
            self.confirmButton.y = buttonY
            self.confirmButton:draw()
        elseif self.variant == "alert" and self.confirmButton then
            self.confirmButton.x = modalX + (self.width - 100) / 2
            self.confirmButton.y = buttonY
            self.confirmButton:draw()
        end

        love.graphics.setColor(1, 1, 1, 1)
    end

    function modal:mousepressed(x, y, button)
        if not self.visible then return false end

        if self.confirmButton and self.confirmButton:mousepressed(x, y, button) then
            return true
        end
        if self.cancelButton and self.cancelButton:mousepressed(x, y, button) then
            return true
        end

        for _, child in ipairs(self.children) do
            if child.mousepressed and child:mousepressed(x, y, button) then
                return true
            end
        end

        return true
    end

    function modal:mousereleased(x, y, button)
        if not self.visible then return end

        if self.confirmButton and self.confirmButton.mousereleased then
            self.confirmButton:mousereleased(x, y, button)
        end
        if self.cancelButton and self.cancelButton.mousereleased then
            self.cancelButton:mousereleased(x, y, button)
        end
    end

    function modal:keypressed(key)
        if not self.visible then return false end

        if key == "escape" and self.cancelButton then
            self.visible = false
            self.onCancel()
            return true
        elseif key == "return" or key == "kpenter" then
            self.visible = false
            self.onConfirm()
            return true
        end

        return true
    end

    function modal:close()
        self.visible = false
    end

    return modal
end

-- ============================================================================
-- LIST COMPONENT
-- ============================================================================

UI.List = {}

function UI.List.new(opts)
    local list = {
        x = opts.x or 0,
        y = opts.y or 0,
        w = opts.w or 300,
        h = opts.h or 400,
        items = opts.items or {},
        selectedIndex = opts.selectedIndex or nil,
        onSelect = opts.onSelect or function() end,
        renderItem = opts.renderItem or nil,

        itemHeight = 40,
        scrollContainer = nil,
    }

    -- Create scroll container
    list.scrollContainer = UI.ScrollContainer.new({
        x = list.x,
        y = list.y,
        w = list.w,
        h = list.h,
        contentHeight = #list.items * list.itemHeight
    })

    function list:update(dt)
        self.scrollContainer.contentHeight = #self.items * self.itemHeight
        self.scrollContainer:update(dt)
    end

    function list:draw()
        -- Set up scissor for clipping
        love.graphics.setScissor(self.x, self.y, self.w - self.scrollContainer.scrollbarWidth - self.scrollContainer.scrollbarPadding * 2, self.h)

        local scrollY = self.scrollContainer:getScroll()
        local startIndex = math.max(1, math.floor(scrollY / self.itemHeight))
        local endIndex = math.min(#self.items, math.ceil((scrollY + self.h) / self.itemHeight) + 1)

        local mx, my = love.mouse.getPosition()
        local font = UI.fonts.get(16)
        love.graphics.setFont(font)

        for i = startIndex, endIndex do
            local item = self.items[i]
            local itemY = self.y + (i - 1) * self.itemHeight - scrollY

            local isSelected = i == self.selectedIndex
            local isHovered = isPointInRect(mx, my, self.x, itemY, self.w - self.scrollContainer.scrollbarWidth - self.scrollContainer.scrollbarPadding * 2, self.itemHeight)

            -- Draw background
            if isSelected then
                love.graphics.setColor(UI.theme.colors.primary[1], UI.theme.colors.primary[2], UI.theme.colors.primary[3], 0.3)
                love.graphics.rectangle("fill", self.x, itemY, self.w - self.scrollContainer.scrollbarWidth - self.scrollContainer.scrollbarPadding * 2, self.itemHeight)
            elseif isHovered then
                love.graphics.setColor(UI.theme.colors.bgLight)
                love.graphics.rectangle("fill", self.x, itemY, self.w - self.scrollContainer.scrollbarWidth - self.scrollContainer.scrollbarPadding * 2, self.itemHeight)
            end

            -- Render item
            if self.renderItem then
                self.renderItem(item, self.x + UI.theme.spacing.md, itemY, self.w - self.scrollContainer.scrollbarWidth - self.scrollContainer.scrollbarPadding * 2, self.itemHeight, isSelected)
            else
                -- Default rendering
                love.graphics.setColor(UI.theme.colors.text)
                local displayText = type(item) == "string" and item or tostring(item)
                love.graphics.print(displayText, self.x + UI.theme.spacing.md, itemY + (self.itemHeight - font:getHeight()) / 2)
            end
        end

        love.graphics.setScissor()

        -- Draw scrollbar
        self.scrollContainer:draw()

        love.graphics.setColor(1, 1, 1, 1)
    end

    function list:mousepressed(x, y, button)
        if button ~= 1 then return false end

        -- Check scrollbar first
        if self.scrollContainer:mousepressed(x, y, button) then
            return true
        end

        -- Check item click
        if isPointInRect(x, y, self.x, self.y, self.w - self.scrollContainer.scrollbarWidth - self.scrollContainer.scrollbarPadding * 2, self.h) then
            local scrollY = self.scrollContainer:getScroll()
            local clickedIndex = math.floor((y - self.y + scrollY) / self.itemHeight) + 1

            if clickedIndex >= 1 and clickedIndex <= #self.items then
                self.selectedIndex = clickedIndex
                self.onSelect(self.items[clickedIndex], clickedIndex)
                return true
            end
        end

        return false
    end

    function list:mousereleased(x, y, button)
        self.scrollContainer:mousereleased(x, y, button)
    end

    function list:mousemoved(x, y, dx, dy)
        if self.scrollContainer.mousemoved then
            self.scrollContainer:mousemoved(x, y, dx, dy)
        end
    end

    function list:wheelmoved(x, y)
        self.scrollContainer:wheelmoved(x, y)
    end

    function list:keypressed(key)
        return false
    end

    return list
end

-- ============================================================================
-- GRID LAYOUT HELPER
-- ============================================================================

UI.Grid = {}

function UI.Grid.new(x, y, w, cols, cellW, cellH, gap)
    local grid = {
        x = x or 0,
        y = y or 0,
        w = w or 400,
        cols = cols or 3,
        cellW = cellW or 100,
        cellH = cellH or 100,
        gap = gap or 8,
    }

    function grid:cellPosition(index)
        local row = math.floor((index - 1) / self.cols)
        local col = (index - 1) % self.cols

        return {
            x = self.x + col * (self.cellW + self.gap),
            y = self.y + row * (self.cellH + self.gap)
        }
    end

    function grid:totalHeight(itemCount)
        local rows = math.ceil(itemCount / self.cols)
        return rows * (self.cellH + self.gap) - self.gap
    end

    function grid:forEach(count, fn)
        for i = 1, count do
            local pos = self:cellPosition(i)
            fn(i, pos.x, pos.y)
        end
    end

    return grid
end

-- ============================================================================
-- GROUP COMPONENT
-- ============================================================================

UI.Group = {}

function UI.Group.new(children)
    local group = {
        children = children or {}
    }

    function group:update(dt)
        for _, child in ipairs(self.children) do
            if child.update then
                child:update(dt)
            end
        end
    end

    function group:draw()
        for _, child in ipairs(self.children) do
            if child.draw then
                child:draw()
            end
        end
    end

    function group:mousepressed(x, y, button)
        for _, child in ipairs(self.children) do
            if child.mousepressed and child:mousepressed(x, y, button) then
                return true
            end
        end
        return false
    end

    function group:mousereleased(x, y, button)
        for _, child in ipairs(self.children) do
            if child.mousereleased then
                child:mousereleased(x, y, button)
            end
        end
    end

    function group:mousemoved(x, y, dx, dy)
        for _, child in ipairs(self.children) do
            if child.mousemoved then
                child:mousemoved(x, y, dx, dy)
            end
        end
    end

    function group:wheelmoved(x, y)
        for _, child in ipairs(self.children) do
            if child.wheelmoved then
                child:wheelmoved(x, y)
            end
        end
    end

    function group:keypressed(key)
        for _, child in ipairs(self.children) do
            if child.keypressed and child:keypressed(key) then
                return true
            end
        end
        return false
    end

    function group:textinput(text)
        for _, child in ipairs(self.children) do
            if child.textinput and child:textinput(text) then
                return true
            end
        end
        return false
    end

    return group
end

-- ============================================================================
-- TOOLTIP SYSTEM
-- ============================================================================

UI.Tooltip = {
    text = "",
    title = "",
    x = 0,
    y = 0,
    visible = false,
    delay = 0.3,
    timer = 0,
    pending = false,
}

function UI.Tooltip.show(text, x, y, opts)
    opts = opts or {}
    UI.Tooltip.text = text or ""
    UI.Tooltip.title = opts.title or ""
    UI.Tooltip.x = x or 0
    UI.Tooltip.y = y or 0
    UI.Tooltip.delay = opts.delay or 0.3
    UI.Tooltip.timer = 0
    UI.Tooltip.pending = true
end

function UI.Tooltip.hide()
    UI.Tooltip.visible = false
    UI.Tooltip.pending = false
    UI.Tooltip.timer = 0
end

function UI.Tooltip.update(dt)
    if UI.Tooltip.pending then
        UI.Tooltip.timer = UI.Tooltip.timer + dt
        if UI.Tooltip.timer >= UI.Tooltip.delay then
            UI.Tooltip.visible = true
            UI.Tooltip.pending = false
        end
    end
end

function UI.Tooltip.draw()
    if not UI.Tooltip.visible then return end

    local padding = UI.theme.spacing.md
    local font = UI.fonts.get(14)
    local titleFont = UI.fonts.get(16)

    love.graphics.setFont(font)
    local textW = font:getWidth(UI.Tooltip.text)
    local textH = font:getHeight()

    local titleW = 0
    local titleH = 0
    if UI.Tooltip.title ~= "" then
        titleW = titleFont:getWidth(UI.Tooltip.title)
        titleH = titleFont:getHeight()
    end

    local boxW = math.max(textW, titleW) + padding * 2
    local boxH = textH + padding * 2
    if UI.Tooltip.title ~= "" then
        boxH = boxH + titleH + UI.theme.spacing.sm
    end

    -- Adjust position to keep tooltip on screen
    local screenW, screenH = love.graphics.getDimensions()
    local tooltipX = UI.Tooltip.x + 10
    local tooltipY = UI.Tooltip.y + 10

    if tooltipX + boxW > screenW then
        tooltipX = UI.Tooltip.x - boxW - 10
    end
    if tooltipY + boxH > screenH then
        tooltipY = UI.Tooltip.y - boxH - 10
    end

    -- Draw background
    love.graphics.setColor(UI.theme.colors.bgDark)
    drawRoundedRect("fill", tooltipX, tooltipY, boxW, boxH, UI.theme.radius.md)

    -- Draw border
    love.graphics.setColor(UI.theme.colors.panelBorder)
    love.graphics.setLineWidth(UI.theme.border.thin)
    drawRoundedRect("line", tooltipX, tooltipY, boxW, boxH, UI.theme.radius.md)
    love.graphics.setLineWidth(1)

    -- Draw title
    local yOffset = padding
    if UI.Tooltip.title ~= "" then
        love.graphics.setFont(titleFont)
        love.graphics.setColor(UI.theme.colors.textAccent)
        love.graphics.print(UI.Tooltip.title, tooltipX + padding, tooltipY + yOffset)
        yOffset = yOffset + titleH + UI.theme.spacing.sm
    end

    -- Draw text
    love.graphics.setFont(font)
    love.graphics.setColor(UI.theme.colors.text)
    love.graphics.print(UI.Tooltip.text, tooltipX + padding, tooltipY + yOffset)

    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- TOAST NOTIFICATION SYSTEM
-- ============================================================================

UI.Toast = {
    queue = {},
    active = {},
    maxActive = 3,
    toastHeight = 60,
    toastWidth = 300,
    padding = UI.theme.spacing.md,
    holdDuration = 3,
}

function UI.Toast.show(message, variant)
    variant = variant or "info"

    local toast = {
        message = message,
        variant = variant,
        timer = 0,
        state = "entering",
        alpha = 0,
        offsetY = -20,
    }

    table.insert(UI.Toast.queue, toast)
end

function UI.Toast.update(dt)
    -- Move toasts from queue to active
    while #UI.Toast.active < UI.Toast.maxActive and #UI.Toast.queue > 0 do
        local toast = table.remove(UI.Toast.queue, 1)
        table.insert(UI.Toast.active, toast)
    end

    -- Update active toasts
    for i = #UI.Toast.active, 1, -1 do
        local toast = UI.Toast.active[i]
        toast.timer = toast.timer + dt

        if toast.state == "entering" then
            toast.alpha = math.min(1, toast.alpha + dt * 4)
            toast.offsetY = lerp(toast.offsetY, 0, dt * 10)

            if toast.alpha >= 1 and math.abs(toast.offsetY) < 0.5 then
                toast.state = "holding"
                toast.timer = 0
                toast.offsetY = 0
            end
        elseif toast.state == "holding" then
            if toast.timer >= UI.Toast.holdDuration then
                toast.state = "exiting"
                toast.timer = 0
            end
        elseif toast.state == "exiting" then
            toast.alpha = math.max(0, toast.alpha - dt * 4)
            toast.offsetY = toast.offsetY - dt * 100

            if toast.alpha <= 0 then
                table.remove(UI.Toast.active, i)
            end
        end
    end
end

function UI.Toast.draw()
    local screenW, screenH = love.graphics.getDimensions()
    local startX = screenW - UI.Toast.toastWidth - UI.Toast.padding
    local startY = UI.Toast.padding

    for i, toast in ipairs(UI.Toast.active) do
        local y = startY + (i - 1) * (UI.Toast.toastHeight + UI.Toast.padding) + toast.offsetY

        -- Determine color based on variant
        local bgColor
        if toast.variant == "success" then
            bgColor = UI.theme.colors.success
        elseif toast.variant == "warning" then
            bgColor = UI.theme.colors.warning
        elseif toast.variant == "error" then
            bgColor = UI.theme.colors.danger
        else
            bgColor = UI.theme.colors.info
        end

        -- Draw background with alpha
        love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], toast.alpha)
        drawRoundedRect("fill", startX, y, UI.Toast.toastWidth, UI.Toast.toastHeight, UI.theme.radius.md)

        -- Draw message
        local font = UI.fonts.get(14)
        love.graphics.setFont(font)
        love.graphics.setColor(1, 1, 1, toast.alpha)
        love.graphics.printf(
            toast.message,
            startX + UI.theme.spacing.md,
            y + (UI.Toast.toastHeight - font:getHeight()) / 2,
            UI.Toast.toastWidth - UI.theme.spacing.md * 2,
            "left"
        )
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- MODULE RETURN
-- ============================================================================

return UI
