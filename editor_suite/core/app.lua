-- App: Tab switching, global shortcuts, project state management
local Theme = require("core.theme")
local FontCache = require("core.fontcache")
local FileIO = require("core.file_io")

local App = {}
App.__index = App

local TAB_NAMES = {
    "Items", "Enemies", "NPCs", "Quests",
    "Maps", "Prefabs", "Lore", "Classes/Races"
}

local TAB_KEYS = {
    "items", "enemies", "npcs", "quests",
    "maps", "prefabs", "lore", "classes_races"
}

local TAB_EDITOR_MODULES = {
    "editors.item_editor",
    "editors.enemy_editor",
    "editors.npc_editor",
    "editors.quest_editor",
    "editors.map_editor",
    "editors.prefab_editor",
    "editors.lore_editor",
    "editors.class_race_editor",
}

function App.new()
    local self = setmetatable({}, App)

    -- Project state
    self.project = nil
    self.projectFile = nil
    self.dirty = false

    -- Tab state
    self.activeTab = 1
    self.tabCount = #TAB_NAMES
    self.editors = {}
    self.editorsLoaded = {}

    -- UI state
    self.showModal = nil
    self.modalCallback = nil
    self.statusMessage = ""
    self.statusTimer = 0
    self.showHelp = false
    self.showExportPreview = false
    self.exportPreviewText = ""

    -- Tab bar dimensions
    self.tabBarHeight = Theme.sizes.tabBarHeight
    self.statusBarHeight = Theme.sizes.statusBarHeight
    self.toolbarHeight = Theme.sizes.toolbarHeight

    -- Initialize with empty project
    self:newProject()

    return self
end

function App:newProject()
    self.project = {
        metadata = {
            name = "New Project",
            version = "1.0",
            created = os.date("%Y-%m-%d %H:%M:%S"),
            modified = os.date("%Y-%m-%d %H:%M:%S"),
            author = "",
        },
        items = {},
        enemies = {},
        npcs = {},
        quests = {},
        maps = {},
        prefabs = {},
        lore = { books = {} },
        classes = {},
        races = {},
        backgrounds = {},
        worldgen = { regions = {}, anchorTowns = {}, dungeonWeights = {} },
    }
    self.projectFile = nil
    self.dirty = false
    self:reloadEditors()
    self:setStatus("New project created")
end

function App:reloadEditors()
    self.editors = {}
    self.editorsLoaded = {}
    -- Editors are lazy-loaded when tab is selected
end

function App:getEditor(tabIndex)
    if not self.editorsLoaded[tabIndex] then
        local ok, mod = pcall(require, TAB_EDITOR_MODULES[tabIndex])
        if ok and mod and mod.new then
            self.editors[tabIndex] = mod.new(self.project)
            if self.editors[tabIndex] then
                self.editors[tabIndex].app = self
            end
        else
            -- Create a placeholder editor
            self.editors[tabIndex] = self:createPlaceholder(tabIndex, ok and "Module loaded but no .new()" or tostring(mod))
        end
        self.editorsLoaded[tabIndex] = true
    end
    return self.editors[tabIndex]
end

function App:createPlaceholder(tabIndex, errMsg)
    return {
        update = function() end,
        draw = function(_, x, y, w, h)
            local font = FontCache.get(16)
            love.graphics.setFont(font)
            love.graphics.setColor(Theme.colors.textDim)
            local text = TAB_NAMES[tabIndex] .. " Editor"
            love.graphics.printf(text, x, y + h/2 - 30, w, "center")
            if errMsg then
                local errFont = FontCache.get(12)
                love.graphics.setFont(errFont)
                love.graphics.setColor(Theme.colors.danger)
                love.graphics.printf("Error: " .. errMsg, x + 20, y + h/2, w - 40, "center")
            end
        end,
        mousepressed = function() end,
        mousereleased = function() end,
        wheelmoved = function() end,
        keypressed = function() end,
        textinput = function() end,
    }
end

function App:setTab(index)
    if index >= 1 and index <= self.tabCount then
        self.activeTab = index
    end
end

function App:setStatus(msg)
    self.statusMessage = msg or ""
    self.statusTimer = 5
end

function App:markDirty()
    self.dirty = true
    self.project.metadata.modified = os.date("%Y-%m-%d %H:%M:%S")
end

function App:saveProject(filename)
    filename = filename or self.projectFile
    if not filename then
        filename = self.project.metadata.name:gsub("%s+", "_"):lower() .. ".lua"
    end
    local ok, err = FileIO.saveProject(self.project, filename)
    if ok then
        self.projectFile = filename
        self.dirty = false
        self:setStatus("Project saved: " .. filename)
    else
        self:setStatus("Save failed: " .. tostring(err))
    end
    return ok, err
end

function App:loadProject(filename)
    local proj, err = FileIO.loadProject(filename)
    if proj then
        self.project = proj
        self.projectFile = filename
        self.dirty = false
        self:reloadEditors()
        self:setStatus("Project loaded: " .. filename)
        return true
    else
        self:setStatus("Load failed: " .. tostring(err))
        return false, err
    end
end

function App:importFromGame()
    local ok, GameDataParser = pcall(require, "importers.game_data_parser")
    if not ok then
        self:setStatus("Import error: Could not load parser - " .. tostring(GameDataParser))
        return
    end

    local gamePath = love.filesystem.getSource()
    if gamePath then
        gamePath = gamePath:gsub("[\\/]editor_suite$", "")
        gamePath = gamePath:gsub("[\\/]editor_suite[\\/]?$", "")
    end

    local callOk, data = pcall(GameDataParser.importAll, gamePath)
    if not callOk then
        self:setStatus("Import crashed: " .. tostring(data))
        return
    end

    if not data then
        self:setStatus("Import produced no data")
        return
    end

    -- Count what was actually imported
    local imported = 0

    if data.items and #data.items > 0 then
        self.project.items = data.items
        imported = imported + 1
    end
    if data.enemies and #data.enemies > 0 then
        self.project.enemies = data.enemies
        imported = imported + 1
    end
    if data.classes and #data.classes > 0 then
        self.project.classes = data.classes
        imported = imported + 1
    end
    if data.races then
        -- Flatten base + unlockable into a single array for the editor
        local flatRaces = {}
        if data.races.base then
            for _, r in ipairs(data.races.base) do
                table.insert(flatRaces, r)
            end
        end
        if data.races.unlockable then
            for _, r in ipairs(data.races.unlockable) do
                table.insert(flatRaces, r)
            end
        end
        if #flatRaces > 0 then
            self.project.races = flatRaces
            imported = imported + 1
        end
    end
    if data.backgrounds and #data.backgrounds > 0 then
        self.project.backgrounds = data.backgrounds
        imported = imported + 1
    end
    if data.npcs then
        self.project.npcs = data.npcs
        imported = imported + 1
    end
    if data.quests then
        self.project.quests = data.quests
        imported = imported + 1
    end
    if data.lore and #data.lore > 0 then
        self.project.lore.books = data.lore
        imported = imported + 1
    end

    -- Worldgen data (regions, anchor towns, dungeon weights)
    if not self.project.worldgen then
        self.project.worldgen = { regions = {}, anchorTowns = {}, dungeonWeights = {} }
    end
    if data.regions then
        self.project.worldgen.regions = data.regions
        imported = imported + 1
    end
    if data.anchorTowns and #data.anchorTowns > 0 then
        self.project.worldgen.anchorTowns = data.anchorTowns
        imported = imported + 1
    end
    if data.regionDungeonWeights then
        self.project.worldgen.dungeonWeights = data.regionDungeonWeights
        imported = imported + 1
    end

    -- Report errors if any parsers failed
    local errorCount = 0
    local firstError = nil
    if data.errors then
        for name, err in pairs(data.errors) do
            errorCount = errorCount + 1
            if not firstError then firstError = name .. ": " .. err end
        end
    end

    self:markDirty()
    self:reloadEditors()

    if imported > 0 and errorCount == 0 then
        self:setStatus("Imported " .. imported .. " categories successfully")
    elseif imported > 0 and errorCount > 0 then
        self:setStatus("Imported " .. imported .. " categories, " .. errorCount .. " failed: " .. firstError)
    elseif errorCount > 0 then
        self:setStatus("Import failed: " .. errorCount .. " errors - " .. (firstError or "unknown"))
    else
        self:setStatus("Import found no game data (path: " .. tostring(gamePath) .. ")")
    end
end

function App:exportAll()
    local ok, err = FileIO.exportToDirectory(self.project, "exports")
    if ok then
        local savePath = love.filesystem.getSaveDirectory()
        self:setStatus("Exported to: " .. savePath .. "/exports/")
    else
        self:setStatus("Export failed: " .. tostring(err))
    end
end

-- UPDATE
function App:update(dt)
    -- Status message timer
    if self.statusTimer > 0 then
        self.statusTimer = self.statusTimer - dt
        if self.statusTimer <= 0 then
            self.statusMessage = ""
        end
    end

    -- Update active editor
    local editor = self:getEditor(self.activeTab)
    if editor and editor.update then
        editor:update(dt)
    end
end

-- DRAW
function App:draw()
    local W, H = love.graphics.getDimensions()

    -- Background
    love.graphics.setColor(Theme.colors.bg)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Draw tab bar
    self:drawTabBar(W)

    -- Draw toolbar
    self:drawToolbar(W)

    -- Draw editor area
    local editorY = self.tabBarHeight + self.toolbarHeight
    local editorH = H - editorY - self.statusBarHeight
    local editor = self:getEditor(self.activeTab)
    if editor and editor.draw then
        -- Clip to editor area
        love.graphics.setScissor(0, editorY, W, editorH)
        editor:draw(0, editorY, W, editorH)
        love.graphics.setScissor()
    end

    -- Draw status bar
    self:drawStatusBar(W, H)

    -- Draw help overlay
    if self.showHelp then
        self:drawHelpOverlay(W, H)
    end
end

function App:drawTabBar(W)
    -- Tab bar background
    love.graphics.setColor(Theme.colors.bgDark)
    love.graphics.rectangle("fill", 0, 0, W, self.tabBarHeight)

    local tabWidth = math.min(140, (W - 200) / self.tabCount)
    local font = FontCache.get(13)
    love.graphics.setFont(font)

    local mx, my = love.mouse.getPosition()

    for i = 1, self.tabCount do
        local tx = (i - 1) * tabWidth
        local isActive = (i == self.activeTab)
        local isHover = mx >= tx and mx < tx + tabWidth and my >= 0 and my < self.tabBarHeight

        if isActive then
            love.graphics.setColor(Theme.colors.panel)
            love.graphics.rectangle("fill", tx, 0, tabWidth, self.tabBarHeight)
            love.graphics.setColor(Theme.colors.tabActive)
            love.graphics.rectangle("fill", tx, self.tabBarHeight - 3, tabWidth, 3)
            love.graphics.setColor(Theme.colors.text)
        elseif isHover then
            love.graphics.setColor(Theme.colors.tabHover)
            love.graphics.rectangle("fill", tx, 0, tabWidth, self.tabBarHeight)
            love.graphics.setColor(Theme.colors.text)
        else
            love.graphics.setColor(Theme.colors.textDim)
        end

        love.graphics.printf(TAB_NAMES[i], tx, (self.tabBarHeight - font:getHeight()) / 2, tabWidth, "center")
    end

    -- Right side: project name + dirty indicator
    love.graphics.setColor(Theme.colors.textDim)
    local projName = self.project.metadata.name
    if self.dirty then projName = projName .. " *" end
    love.graphics.printf(projName, W - 200, (self.tabBarHeight - font:getHeight()) / 2, 190, "right")

    -- Bottom border
    love.graphics.setColor(Theme.colors.panelBorder)
    love.graphics.line(0, self.tabBarHeight, W, self.tabBarHeight)
end

function App:drawToolbar(W)
    local ty = self.tabBarHeight
    love.graphics.setColor(Theme.colors.panelHeader)
    love.graphics.rectangle("fill", 0, ty, W, self.toolbarHeight)

    local font = FontCache.get(12)
    love.graphics.setFont(font)
    local mx, my = love.mouse.getPosition()

    -- Toolbar buttons
    local buttons = {
        {label = "New", x = 8},
        {label = "Open", x = 60},
        {label = "Save", x = 116},
        {label = "Import", x = 168},
        {label = "Export", x = 236},
        {label = "Undo", x = 310},
        {label = "Redo", x = 362},
    }

    for _, btn in ipairs(buttons) do
        local bw = font:getWidth(btn.label) + 16
        local bx = btn.x
        local by = ty + 3
        local bh = self.toolbarHeight - 6

        local hover = mx >= bx and mx < bx + bw and my >= by and my < by + bh

        if hover then
            love.graphics.setColor(Theme.colors.tabHover)
            love.graphics.rectangle("fill", bx, by, bw, bh, Theme.radius.sm, Theme.radius.sm)
            love.graphics.setColor(Theme.colors.text)
        else
            love.graphics.setColor(Theme.colors.textDim)
        end

        love.graphics.printf(btn.label, bx, by + (bh - font:getHeight()) / 2, bw, "center")
    end

    -- Help button on far right
    local helpW = font:getWidth("F1 Help") + 16
    local helpX = W - helpW - 8
    local helpHover = mx >= helpX and mx < helpX + helpW and my >= ty + 3 and my < ty + self.toolbarHeight - 3
    if helpHover then
        love.graphics.setColor(Theme.colors.tabHover)
        love.graphics.rectangle("fill", helpX, ty + 3, helpW, self.toolbarHeight - 6, Theme.radius.sm, Theme.radius.sm)
    end
    love.graphics.setColor(Theme.colors.info)
    love.graphics.printf("F1 Help", helpX, ty + 3 + (self.toolbarHeight - 6 - font:getHeight()) / 2, helpW, "center")

    -- Bottom border
    love.graphics.setColor(Theme.colors.panelBorder)
    love.graphics.line(0, ty + self.toolbarHeight, W, ty + self.toolbarHeight)
end

function App:drawStatusBar(W, H)
    local sy = H - self.statusBarHeight
    love.graphics.setColor(Theme.colors.statusBar)
    love.graphics.rectangle("fill", 0, sy, W, self.statusBarHeight)

    local font = FontCache.get(11)
    love.graphics.setFont(font)

    -- Status message (left)
    if self.statusMessage ~= "" then
        local alpha = 1
        if self.statusTimer < 1 then alpha = math.max(0, self.statusTimer) end
        love.graphics.setColor(Theme.colors.textAccent[1], Theme.colors.textAccent[2], Theme.colors.textAccent[3], alpha)
        love.graphics.print(self.statusMessage, 8, sy + (self.statusBarHeight - font:getHeight()) / 2)
    end

    -- Right side info
    love.graphics.setColor(Theme.colors.statusText)
    local info = string.format("Tab: %s | Items: %d | Enemies: %d | NPCs: %d | Quests: %d",
        TAB_NAMES[self.activeTab],
        #self.project.items,
        #self.project.enemies,
        type(self.project.npcs) == "table" and #self.project.npcs or 0,
        type(self.project.quests) == "table" and #self.project.quests or 0
    )
    love.graphics.printf(info, W - 500, sy + (self.statusBarHeight - font:getHeight()) / 2, 490, "right")

    -- Top border
    love.graphics.setColor(Theme.colors.panelBorder)
    love.graphics.line(0, sy, W, sy)
end

function App:drawHelpOverlay(W, H)
    -- Overlay background
    love.graphics.setColor(Theme.colors.overlay)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Help panel
    local pw, ph = 500, 400
    local px, py = (W - pw) / 2, (H - ph) / 2

    love.graphics.setColor(Theme.colors.panel)
    love.graphics.rectangle("fill", px, py, pw, ph, Theme.radius.lg, Theme.radius.lg)
    love.graphics.setColor(Theme.colors.panelBorder)
    love.graphics.rectangle("line", px, py, pw, ph, Theme.radius.lg, Theme.radius.lg)

    local font = FontCache.get(16)
    love.graphics.setFont(font)
    love.graphics.setColor(Theme.colors.textAccent)
    love.graphics.printf("Keyboard Shortcuts", px, py + 12, pw, "center")

    local helpFont = FontCache.get(13)
    love.graphics.setFont(helpFont)
    love.graphics.setColor(Theme.colors.text)

    local shortcuts = {
        {"Ctrl+N", "New Project"},
        {"Ctrl+O", "Open Project"},
        {"Ctrl+S", "Save Project"},
        {"Ctrl+I", "Import from Game"},
        {"Ctrl+E", "Export All"},
        {"Ctrl+Z", "Undo"},
        {"Ctrl+Y", "Redo"},
        {"Ctrl+C/V", "Copy/Paste"},
        {"Ctrl+1-8", "Switch Tabs"},
        {"F1", "Toggle Help"},
        {"F5", "Refresh/Reload"},
        {"Delete", "Delete Selected"},
        {"", ""},
        {"Map Editor:", ""},
        {"P/R/F/E/S", "Paint/Rect/Fill/Erase/Stamp"},
        {"G", "Toggle Grid"},
        {"+/-", "Zoom In/Out"},
        {"Space+Drag", "Pan"},
    }

    local y = py + 40
    for _, s in ipairs(shortcuts) do
        if s[1] ~= "" then
            love.graphics.setColor(Theme.colors.primary)
            love.graphics.printf(s[1], px + 30, y, 120, "right")
            love.graphics.setColor(Theme.colors.text)
            love.graphics.print(s[2], px + 170, y)
        end
        y = y + 18
    end

    love.graphics.setColor(Theme.colors.textDim)
    love.graphics.printf("Press F1 or Escape to close", px, py + ph - 30, pw, "center")
end

-- INPUT HANDLING
function App:mousepressed(x, y, button)
    if self.showHelp then
        self.showHelp = false
        return
    end

    -- Tab bar clicks
    if y < self.tabBarHeight then
        local tabWidth = math.min(140, (love.graphics.getWidth() - 200) / self.tabCount)
        local clickedTab = math.floor(x / tabWidth) + 1
        if clickedTab >= 1 and clickedTab <= self.tabCount then
            self:setTab(clickedTab)
        end
        return
    end

    -- Toolbar clicks
    local toolbarY = self.tabBarHeight
    if y >= toolbarY and y < toolbarY + self.toolbarHeight then
        self:handleToolbarClick(x, y)
        return
    end

    -- Pass to editor
    local editor = self:getEditor(self.activeTab)
    if editor and editor.mousepressed then
        editor:mousepressed(x, y, button)
    end
end

function App:handleToolbarClick(x, y)
    local font = FontCache.get(12)
    -- Check each toolbar button
    local buttons = {
        {label = "New", x = 8, action = function() self:newProject() end},
        {label = "Open", x = 60, action = function() self:showOpenDialog() end},
        {label = "Save", x = 116, action = function() self:saveProject() end},
        {label = "Import", x = 168, action = function() self:importFromGame() end},
        {label = "Export", x = 236, action = function() self:exportAll() end},
        {label = "Undo", x = 310, action = function() self:undo() end},
        {label = "Redo", x = 362, action = function() self:redo() end},
    }

    local ty = self.tabBarHeight + 3
    local bh = self.toolbarHeight - 6

    for _, btn in ipairs(buttons) do
        local bw = font:getWidth(btn.label) + 16
        if x >= btn.x and x < btn.x + bw and y >= ty and y < ty + bh then
            btn.action()
            return
        end
    end

    -- Help button
    local W = love.graphics.getWidth()
    local helpW = font:getWidth("F1 Help") + 16
    local helpX = W - helpW - 8
    if x >= helpX and x < helpX + helpW then
        self.showHelp = not self.showHelp
    end
end

function App:showOpenDialog()
    local projects = FileIO.getProjectList()
    if #projects == 0 then
        self:setStatus("No saved projects found")
        return
    end
    -- Simple: load the most recent project
    -- In a full implementation, this would show a file browser modal
    self:setStatus("Use Ctrl+O - " .. #projects .. " projects available")
end

function App:undo()
    local editor = self:getEditor(self.activeTab)
    if editor and editor.undoStack and editor.undoStack.undo then
        editor.undoStack:undo()
        self:markDirty()
    end
end

function App:redo()
    local editor = self:getEditor(self.activeTab)
    if editor and editor.undoStack and editor.undoStack.redo then
        editor.undoStack:redo()
        self:markDirty()
    end
end

function App:mousereleased(x, y, button)
    local editor = self:getEditor(self.activeTab)
    if editor and editor.mousereleased then
        editor:mousereleased(x, y, button)
    end
end

function App:mousemoved(x, y, dx, dy)
    local editor = self:getEditor(self.activeTab)
    if editor and editor.mousemoved then
        editor:mousemoved(x, y, dx, dy)
    end
end

function App:wheelmoved(wx, wy)
    if self.showHelp then return end

    local editor = self:getEditor(self.activeTab)
    if editor and editor.wheelmoved then
        editor:wheelmoved(wx, wy)
    end
end

function App:keypressed(key)
    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")

    -- Global shortcuts
    if key == "f1" then
        self.showHelp = not self.showHelp
        return
    end

    if self.showHelp then
        if key == "escape" then
            self.showHelp = false
        end
        return
    end

    if ctrl then
        if key == "n" then
            self:newProject()
            return
        elseif key == "s" then
            self:saveProject()
            return
        elseif key == "o" then
            self:showOpenDialog()
            return
        elseif key == "i" then
            self:importFromGame()
            return
        elseif key == "e" then
            self:exportAll()
            return
        elseif key == "z" then
            self:undo()
            return
        elseif key == "y" then
            self:redo()
            return
        end

        -- Tab switching: Ctrl+1-8
        local num = tonumber(key)
        if num and num >= 1 and num <= self.tabCount then
            self:setTab(num)
            return
        end
    end

    -- Pass to editor
    local editor = self:getEditor(self.activeTab)
    if editor and editor.keypressed then
        editor:keypressed(key)
    end
end

function App:textinput(t)
    if self.showHelp then return end

    local editor = self:getEditor(self.activeTab)
    if editor and editor.textinput then
        editor:textinput(t)
    end
end

function App:resize(w, h)
    local editor = self:getEditor(self.activeTab)
    if editor and editor.resize then
        editor:resize(w, h)
    end
end

return App
