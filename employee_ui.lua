-- Employee UI - Shared employee panel rendering for minigames
-- Extracts the common panel layout, button management, and click handling
-- that was previously duplicated across forge, alchemist, wizardtower, hunting.
--
-- Uses Employees.drawEmployeeRow() for individual row rendering (not duplicated here).
-- This module handles the PANEL LAYOUT and BUTTON/CLICK MANAGEMENT that wraps those primitives.

local EmployeeUI = {}
local Employees = require("employees")
local UpgradeSystem = require("upgradesystem")
local UI = require("ui")

local function getFont(size)
    return UI.fonts.get(size)
end

-- Mode-specific theme configuration
-- Each minigame can override colors, labels, and sizes via this table.
local MODE_THEMES = {
    forge = {
        panelFill = {0.12, 0.14, 0.18},
        panelBorder = {0.8, 0.5, 0.3},
        titleColor = {1, 0.8, 0.4},
        title = "FORGE EMPLOYEES",
        workerLabel = "Workers",
        currentLabel = "Current Workers:",
        emptyLabel = "No workers hired yet. Hire someone below!",
        fireLabel = "Fire",
        sectionColor = {0.9, 0.7, 0.5},
        hireHeaderColor = {0.7, 0.9, 0.7},
        dividerColor = {0.3, 0.3, 0.35},
        closeHintColor = {0.5, 0.5, 0.6},
        emptyColor = {0.5, 0.5, 0.55},
        ownershipMsg = "You must own this forge to hire workers.",
        panelH = 550,
        rowHeight = 80,
        showGold = true,
        goldInfoX = -130,
    },
    alchemist = {
        panelFill = {0.12, 0.15, 0.12},
        panelBorder = {0.4, 0.8, 0.4},
        titleColor = {0.5, 0.9, 0.5},
        title = "ALCHEMIST ASSISTANTS",
        workerLabel = "Assistants",
        currentLabel = "Current Assistants:",
        emptyLabel = "No assistants hired yet. Hire someone below!",
        fireLabel = "Dismiss",
        sectionColor = {0.5, 0.9, 0.6},
        hireHeaderColor = {0.6, 0.9, 0.7},
        dividerColor = {0.3, 0.35, 0.3},
        closeHintColor = {0.5, 0.55, 0.5},
        emptyColor = {0.5, 0.55, 0.5},
        ownershipMsg = "You must own this shop to hire assistants.",
        panelH = 550,
        rowHeight = 70,
        showGold = true,
        goldInfoX = -140,
    },
    wizardtower = {
        panelFill = {0.12, 0.12, 0.2},
        panelBorder = {0.6, 0.4, 1},
        titleColor = {0.8, 0.6, 1},
        title = "WIZARD TOWER APPRENTICES",
        workerLabel = "Apprentices",
        currentLabel = "Current Apprentices:",
        emptyLabel = "No apprentices hired yet. Hire someone below!",
        fireLabel = "Dismiss",
        sectionColor = {0.8, 0.6, 1},
        hireHeaderColor = {0.6, 0.9, 0.7},
        dividerColor = {0.3, 0.3, 0.4},
        closeHintColor = {0.5, 0.5, 0.6},
        emptyColor = {0.5, 0.5, 0.6},
        ownershipMsg = "You must own this tower to hire apprentices.",
        panelH = 550,
        rowHeight = 70,
        showGold = true,
        goldInfoX = -150,
    },
    hunting = {
        panelFill = nil,  -- nil means use UI.theme.colors.panel
        panelBorder = nil,  -- nil means use UI.theme.colors.panelBorder
        titleColor = nil,  -- nil means use UI.theme.colors.textAccent
        title = "HUNTING CREW",
        workerLabel = "Hunters",
        currentLabel = "Current Hunters:",
        emptyLabel = "No hunters hired yet.",
        fireLabel = "Fire",
        sectionColor = {0.9, 0.7, 0.5},
        hireHeaderColor = {0.7, 0.9, 0.7},
        dividerColor = {0.3, 0.3, 0.35},
        closeHintColor = nil,  -- nil means use UI.theme.colors.textDim
        emptyColor = nil,  -- nil means use UI.theme.colors.textDim
        ownershipMsg = "You must own this lodge to hire hunters.",
        panelH = 500,
        rowHeight = 65,
        showGold = false,
        goldInfoX = -130,
    },
}

-- Allow external registration of new mode themes
function EmployeeUI.registerTheme(mode, theme)
    MODE_THEMES[mode] = theme
end

-- Get theme for a mode, falling back to forge defaults
function EmployeeUI.getTheme(mode)
    return MODE_THEMES[mode] or MODE_THEMES.forge
end

-- Helper: resolve a theme color, falling back to UI.theme if nil
local function resolveColor(themeColor, uiThemeKey)
    if themeColor then
        return themeColor
    end
    -- Navigate UI.theme.colors by key
    if UI.theme and UI.theme.colors and UI.theme.colors[uiThemeKey] then
        return UI.theme.colors[uiThemeKey]
    end
    return {0.5, 0.5, 0.5}
end

-- Compute standard panel geometry (shared by draw and click functions)
local function getPanelGeometry(screenW, screenH, theme)
    local panelW = 600
    local panelH = theme.panelH or 550
    local panelX = screenW / 2 - panelW / 2
    local panelY = screenH / 2 - panelH / 2
    return panelX, panelY, panelW, panelH
end

-----------------------------------------------------------
-- Draw the employee panel overlay
-----------------------------------------------------------
-- Parameters:
--   screenW, screenH: screen dimensions
--   mx, my: mouse position
--   mode: string key ("forge", "alchemist", "wizardtower", "hunting")
--   employees: list of hired employee entities
--   hiringPool: list of available-for-hire employee entities
--   upgrades: table of {upgradeId = level} for this mode
function EmployeeUI.drawEmployeePanel(screenW, screenH, mx, my, mode, employees, hiringPool, upgrades)
    local theme = EmployeeUI.getTheme(mode)
    local panelX, panelY, panelW, panelH = getPanelGeometry(screenW, screenH, theme)
    local rowHeight = theme.rowHeight or 70

    -- Full-screen dark overlay
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Panel background
    local fillColor = resolveColor(theme.panelFill, "panel")
    love.graphics.setColor(fillColor)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)

    -- Panel border
    local borderColor = resolveColor(theme.panelBorder, "panelBorder")
    love.graphics.setColor(borderColor)
    local borderWidth = (UI.theme and UI.theme.border and UI.theme.border.normal) or 2
    love.graphics.setLineWidth(borderWidth)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 10, 10)
    love.graphics.setLineWidth(1)

    -- Title
    local titleColor = resolveColor(theme.titleColor, "textAccent")
    love.graphics.setColor(titleColor)
    love.graphics.setFont(getFont(20))
    love.graphics.print(theme.title, panelX + 20, panelY + 15)

    -- Max employees info (top right area)
    local effects = UpgradeSystem.getCombinedEffects(mode, upgrades or {})
    local maxEmployees = effects.maxEmployees or 1
    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.setFont(getFont(14))
    local infoX = panelX + panelW + (theme.goldInfoX or -130)
    love.graphics.print(theme.workerLabel .. ": " .. #employees .. "/" .. maxEmployees, infoX, panelY + 18)

    -- Gold display (some modes show it, some don't)
    if theme.showGold then
        love.graphics.setColor(1, 0.9, 0.3)
        love.graphics.setFont(getFont(12))
        love.graphics.print("Gold: " .. PlayerData.coins, infoX, panelY + 38)
    end

    -- Divider below title
    love.graphics.setColor(theme.dividerColor or {0.3, 0.3, 0.35})
    love.graphics.rectangle("fill", panelX + 15, panelY + 55, panelW - 30, 2)

    -- Content area
    local contentY = panelY + 65

    -- Current employees section header
    love.graphics.setColor(theme.sectionColor or {0.9, 0.7, 0.5})
    love.graphics.setFont(getFont(14))
    love.graphics.print(theme.currentLabel, panelX + 20, contentY)
    contentY = contentY + 25

    if #employees == 0 then
        local emptyColor = resolveColor(theme.emptyColor, "textDim")
        love.graphics.setColor(emptyColor)
        love.graphics.setFont(getFont(12))
        love.graphics.print(theme.emptyLabel, panelX + 30, contentY + 10)
        contentY = contentY + 40
    else
        for i, emp in ipairs(employees) do
            local isHovered = mx >= panelX + 20 and mx <= panelX + panelW - 20
                and my >= contentY and my <= contentY + rowHeight - 5

            -- Draw employee row using the shared primitive from employees.lua
            Employees.drawEmployeeRow(emp, panelX + 20, contentY, panelW - 100, rowHeight - 5, isHovered)

            -- Fire/dismiss button
            local fireBtnX = panelX + panelW - 70
            local fireBtnY = contentY + (rowHeight - 5) / 2 - 15
            local fireHover = mx >= fireBtnX and mx <= fireBtnX + 55
                and my >= fireBtnY and my <= fireBtnY + 30
            love.graphics.setColor(fireHover and {0.9, 0.3, 0.3} or {0.7, 0.25, 0.25})
            love.graphics.rectangle("fill", fireBtnX, fireBtnY, 55, 30, 5, 5)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(getFont(11))
            love.graphics.printf(theme.fireLabel, fireBtnX, fireBtnY + 8, 55, "center")

            contentY = contentY + rowHeight
        end
    end

    -- Divider before hiring pool
    love.graphics.setColor(theme.dividerColor or {0.3, 0.3, 0.35})
    love.graphics.rectangle("fill", panelX + 15, contentY + 5, panelW - 30, 2)
    contentY = contentY + 15

    -- Available for hire section header
    love.graphics.setColor(theme.hireHeaderColor or {0.7, 0.9, 0.7})
    love.graphics.setFont(getFont(14))
    love.graphics.print("Available for Hire:", panelX + 20, contentY)
    contentY = contentY + 25

    -- Building ownership check
    local ownsBuilding = PlayerData.currentBuildingOwned == true

    if not ownsBuilding then
        love.graphics.setColor(0.8, 0.6, 0.4)
        love.graphics.setFont(getFont(11))
        love.graphics.printf(theme.ownershipMsg, panelX + 20, contentY, panelW - 40, "left")
        love.graphics.setColor(0.6, 0.6, 0.5)
        love.graphics.setFont(getFont(9))
        love.graphics.printf("Purchase from town property menu.", panelX + 20, contentY + 18, panelW - 40, "left")
        contentY = contentY + 45
    end

    for i, emp in ipairs(hiringPool) do
        if contentY + rowHeight < panelY + panelH - 40 then
            local empType = Employees.getType(emp.employeeType)
            local isHovered = mx >= panelX + 20 and mx <= panelX + panelW - 20
                and my >= contentY and my <= contentY + rowHeight - 5

            -- Draw employee row using the shared primitive
            Employees.drawEmployeeRow(emp, panelX + 20, contentY, panelW - 100, rowHeight - 5, isHovered)

            -- Hire button
            local hireBtnX = panelX + panelW - 70
            local hireBtnY = contentY + (rowHeight - 5) / 2 - 15
            local canAfford = PlayerData.coins >= (empType and empType.baseCost or 0)
            local hireHover = mx >= hireBtnX and mx <= hireBtnX + 55
                and my >= hireBtnY and my <= hireBtnY + 30

            if not ownsBuilding then
                love.graphics.setColor(0.3, 0.3, 0.3)
                love.graphics.rectangle("fill", hireBtnX, hireBtnY, 55, 30, 5, 5)
                love.graphics.setColor(0.5, 0.4, 0.4)
                love.graphics.setFont(getFont(9))
                love.graphics.printf("Locked", hireBtnX, hireBtnY + 8, 55, "center")
            elseif canAfford then
                love.graphics.setColor(hireHover and {0.4, 0.8, 0.4} or {0.3, 0.65, 0.3})
                love.graphics.rectangle("fill", hireBtnX, hireBtnY, 55, 30, 5, 5)
                love.graphics.setColor(1, 1, 1)
                love.graphics.setFont(getFont(10))
                love.graphics.printf((empType and empType.baseCost or 0) .. "g", hireBtnX, hireBtnY + 2, 55, "center")
                love.graphics.printf("Hire", hireBtnX, hireBtnY + 15, 55, "center")
            else
                love.graphics.setColor(0.4, 0.4, 0.4)
                love.graphics.rectangle("fill", hireBtnX, hireBtnY, 55, 30, 5, 5)
                love.graphics.setColor(1, 1, 1)
                love.graphics.setFont(getFont(10))
                love.graphics.printf((empType and empType.baseCost or 0) .. "g", hireBtnX, hireBtnY + 2, 55, "center")
                love.graphics.printf("Hire", hireBtnX, hireBtnY + 15, 55, "center")
            end

            contentY = contentY + rowHeight
        end
    end

    -- Close hint at bottom
    local hintColor = resolveColor(theme.closeHintColor, "textDim")
    love.graphics.setColor(hintColor)
    love.graphics.setFont(getFont(11))
    love.graphics.printf("Press [E] or [ESC] to close", panelX, panelY + panelH - 28, panelW, "center")
end

-----------------------------------------------------------
-- Handle click on the employee panel
-----------------------------------------------------------
-- Returns: "fire", index  if a fire button was clicked
--          "hire", index  if a hire button was clicked
--          nil             if no button was clicked (but click was in panel area)
--
-- The caller is responsible for calling their own hireEmployee/fireEmployee
-- with the returned index, e.g.:
--
--   local action, idx = EmployeeUI.handleEmployeePanelClick(x, y, mode, state.employees, state.hiringPool, state.upgrades)
--   if action == "fire" then Forge.fireEmployee(idx)
--   elseif action == "hire" then Forge.hireEmployee(idx)
--   end
--
function EmployeeUI.handleEmployeePanelClick(x, y, mode, employees, hiringPool, upgrades)
    local screenW, screenH = love.graphics.getDimensions()
    local theme = EmployeeUI.getTheme(mode)
    local panelX, panelY, panelW, panelH = getPanelGeometry(screenW, screenH, theme)
    local rowHeight = theme.rowHeight or 70

    -- Calculate starting position for current employees
    -- This must mirror the draw layout exactly
    local contentY = panelY + 90  -- panelY + 65 (content start) + 25 (section header)

    if #employees == 0 then
        contentY = contentY + 40
    else
        for i, emp in ipairs(employees) do
            local fireBtnX = panelX + panelW - 70
            local fireBtnY = contentY + (rowHeight - 5) / 2 - 15

            if x >= fireBtnX and x <= fireBtnX + 55 and
               y >= fireBtnY and y <= fireBtnY + 30 then
                return "fire", i
            end
            contentY = contentY + rowHeight
        end
    end

    -- After divider: +5 (spacing) + 2 (divider) + 10 (spacing) = 15, then +25 (section header) = 40
    contentY = contentY + 40

    -- Ownership check offset
    local ownsBuilding = PlayerData.currentBuildingOwned == true
    if not ownsBuilding then
        contentY = contentY + 45
    end

    for i, emp in ipairs(hiringPool) do
        if contentY + rowHeight < panelY + panelH - 40 then
            local hireBtnX = panelX + panelW - 70
            local hireBtnY = contentY + (rowHeight - 5) / 2 - 15

            if x >= hireBtnX and x <= hireBtnX + 55 and
               y >= hireBtnY and y <= hireBtnY + 30 then
                return "hire", i
            end
            contentY = contentY + rowHeight
        end
    end

    return nil
end

return EmployeeUI
