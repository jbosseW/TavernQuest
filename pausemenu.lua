-- Pause Menu System
-- Accessible from any game state via ESC key.
-- Provides: Resume, Settings, Save Game, Load Game, Quit to Main Menu

local PauseMenu = {}
local UI = require("ui")
local Options = require("options")
local SaveSystem = require("savesystem")
local KnowledgeCenter = require("knowledgecenter")
local Backpack = require("backpack")
local Progression = require("progression")

-- ============================================================================
--                          STATE
-- ============================================================================

local pauseState = {
    active = false,
    subMenu = nil,         -- nil, "settings", "save", "load", "confirm_quit", "confirm_save", "confirm_load"
    selectedButton = 1,
    saveSlotScroll = 0,
    confirmAction = nil,   -- For quit confirmation
    pendingSlot = nil,     -- Slot index for pending save/load confirmation
}

-- UI Component instances (created when entering sub-menus)
local uiComponents = {
    mainButtons = {},
    settingsControls = {},
    saveLoadSlots = {},
    confirmModal = nil,
    backButton = nil,
}

-- UI Component instances for panels (created when opening sub-menus)
local uiPanels = {
    mainPanel = nil,
    settingsPanel = nil,
    saveLoadPanel = nil,
}

-- Button definitions for main pause menu
local MAIN_BUTTONS = {
    {id = "resume",    label = "Resume Game",     variant = "ghost"},
    {id = "knowledge", label = "Knowledge Center", variant = "ghost"},
    {id = "settings",  label = "Settings",        variant = "ghost"},
    {id = "save",      label = "Save Game",       variant = "ghost"},
    {id = "load",      label = "Load Game",       variant = "ghost"},
    {id = "quit",      label = "Quit to Main Menu", variant = "danger"},
}

-- ============================================================================
--                        API
-- ============================================================================

function PauseMenu.isActive()
    return pauseState.active
end

function PauseMenu.open()
    pauseState.active = true
    pauseState.subMenu = nil
    pauseState.selectedButton = 1
    PauseMenu.createMainMenuButtons()
end

function PauseMenu.close()
    pauseState.active = false
    pauseState.subMenu = nil
    pauseState.pendingSlot = nil
    uiComponents.mainButtons = {}
    uiComponents.settingsControls = {}
    uiComponents.saveLoadSlots = {}
    uiComponents.confirmModal = nil
    uiComponents.backButton = nil
    uiPanels.mainPanel = nil
    uiPanels.settingsPanel = nil
    uiPanels.saveLoadPanel = nil
end

function PauseMenu.toggle()
    if pauseState.active then
        PauseMenu.close()
    else
        PauseMenu.open()
    end
end

-- ============================================================================
--                      SETTINGS SUB-MENU DATA
-- ============================================================================

local SETTINGS_ITEMS = {
    {id = "music_toggle", label = "Music", type = "toggle",
        getValue = function()
            return not (PlayerData and PlayerData.settings and PlayerData.settings.musicMuted)
        end,
        setValue = function(val)
            if not PlayerData then return end
            if not PlayerData.settings then PlayerData.settings = {} end
            PlayerData.settings.musicMuted = not val
            if PlayerData.settings.musicMuted then
                if AudioSystem and AudioSystem.stopAll then AudioSystem.stopAll() end
            else
                if AudioSystem and AudioSystem.playMenuMusic then AudioSystem.playMenuMusic() end
            end
        end
    },
    {id = "music_volume", label = "Music Volume", type = "slider",
        getValue = function()
            return (PlayerData and PlayerData.settings and PlayerData.settings.musicVolume) or 0.3
        end,
        setValue = function(val)
            if not PlayerData then return end
            if not PlayerData.settings then PlayerData.settings = {} end
            PlayerData.settings.musicVolume = val
            if AudioSystem then
                local sources = {AudioSystem.menuMusic, AudioSystem.gameMusic, AudioSystem.combatMusic, AudioSystem.rpgMusic, AudioSystem.townMusic}
                for _, source in ipairs(sources) do
                    if source and type(source) ~= "string" then
                        pcall(function() source:setVolume(val) end)
                    end
                end
            end
        end
    },
    {id = "sfx_volume", label = "SFX Volume", type = "slider",
        getValue = function()
            return (PlayerData and PlayerData.settings and PlayerData.settings.sfxVolume) or 0.5
        end,
        setValue = function(val)
            if not PlayerData then return end
            if not PlayerData.settings then PlayerData.settings = {} end
            PlayerData.settings.sfxVolume = val
        end
    },
    {id = "fullscreen", label = "Fullscreen", type = "toggle",
        getValue = function()
            return love.window.getFullscreen()
        end,
        setValue = function(val)
            love.window.setFullscreen(val)
            if PlayerData and PlayerData.settings then
                PlayerData.settings.fullscreen = val
            end
        end
    },
    {id = "combat_mode", label = "Combat Mode", type = "cycle",
        options = {"Tactical Grid", "Classic"},
        getValue = function()
            local isTactical = PlayerData and PlayerData.settings and PlayerData.settings.tacticalCombat
            if isTactical == nil then isTactical = true end
            return isTactical and 1 or 2
        end,
        setValue = function(idx)
            if not PlayerData then return end
            if not PlayerData.settings then PlayerData.settings = {} end
            PlayerData.settings.tacticalCombat = (idx == 1)
            if Options then
                Options._combatModeChanged = true
                Options._newTacticalMode = (idx == 1)
            end
        end
    },
}

-- ============================================================================
--                      UI COMPONENT CREATION
-- ============================================================================

function PauseMenu.createMainMenuButtons()
    local screenW, screenH = love.graphics.getDimensions()
    local panelW = 360
    local panelH = 436
    local panelX = screenW/2 - panelW/2
    local panelY = screenH/2 - panelH/2

    local buttonW, buttonH = 280, 48
    local buttonX = screenW/2 - buttonW/2
    local startY = panelY + 80
    local spacing = 56

    -- Create main panel
    uiPanels.mainPanel = UI.Panel.new({
        x = panelX,
        y = panelY,
        w = panelW,
        h = panelH,
        title = nil,
        borderColor = {0.6, 0.5, 0.3},
    })

    -- Create buttons
    uiComponents.mainButtons = {}

    for i, btn in ipairs(MAIN_BUTTONS) do
        local btnY = startY + (i-1) * spacing

        uiComponents.mainButtons[i] = UI.Button.new({
            x = buttonX,
            y = btnY,
            w = buttonW,
            h = buttonH,
            text = btn.label,
            variant = btn.variant,
            onClick = function()
                PauseMenu.activateButton(btn)
            end
        })
    end
end

function PauseMenu.createSettingsControls()
    local screenW, screenH = love.graphics.getDimensions()
    local panelW, panelH = 450, 450
    local panelX = screenW/2 - panelW/2
    local panelY = screenH/2 - panelH/2
    local startY = panelY + 70
    local itemH = 55
    local contentX = panelX + 30
    local contentW = panelW - 60

    -- Create settings panel
    uiPanels.settingsPanel = UI.Panel.new({
        x = panelX,
        y = panelY,
        w = panelW,
        h = panelH,
        title = nil,
        borderColor = {0.6, 0.5, 0.3},
    })

    uiComponents.settingsControls = {}

    for i, item in ipairs(SETTINGS_ITEMS) do
        local itemY = startY + (i-1) * itemH

        if item.type == "toggle" then
            local toggleX = contentX + contentW - 80
            uiComponents.settingsControls[i] = UI.Toggle.new({
                x = toggleX,
                y = itemY,
                label = "",
                value = item.getValue(),
                onChange = function(val)
                    item.setValue(val)
                end
            })
        elseif item.type == "slider" then
            local sliderX = contentX + contentW - 200
            local sliderY2 = itemY + 22
            uiComponents.settingsControls[i] = UI.Slider.new({
                x = sliderX,
                y = itemY,
                w = 190,
                min = 0,
                max = 1,
                step = 0.01,
                value = item.getValue(),
                label = "",
                onChange = function(val)
                    item.setValue(val)
                end
            })
        elseif item.type == "cycle" then
            -- Cycle will be handled with custom button
            local cycleX = contentX + contentW - 160
            local cycleW, cycleH = 150, 28
            local idx = item.getValue()
            local optText = item.options[idx] or "?"

            uiComponents.settingsControls[i] = UI.Button.new({
                x = cycleX,
                y = itemY,
                w = cycleW,
                h = cycleH,
                text = optText,
                variant = "ghost",
                onClick = function()
                    local current = item.getValue()
                    local next = current + 1
                    if next > #item.options then next = 1 end
                    item.setValue(next)
                    -- Update button text
                    uiComponents.settingsControls[i].text = item.options[next]
                end
            })
        end
    end

    -- Back button
    local backW, backH = 120, 40
    local backX = panelX + panelW/2 - backW/2
    local backY = panelY + panelH - 60

    uiComponents.backButton = UI.Button.new({
        x = backX,
        y = backY,
        w = backW,
        h = backH,
        text = "Back",
        variant = "ghost",
        onClick = function()
            pauseState.subMenu = nil
            PauseMenu.createMainMenuButtons()
        end
    })
end

function PauseMenu.createConfirmQuitModal()
    uiComponents.confirmModal = UI.Modal.new({
        title = "Quit to Main Menu?",
        message = "Unsaved progress will be lost.",
        variant = "confirm",
        width = 380,
        height = 200,
        onConfirm = function()
            PauseMenu.close()
            if GameState then
                -- Save player data before quitting
                if savePlayerData then savePlayerData() end
                -- Try to save TextRPG-specific state
                local TextRPG = require("textrpg")
                if TextRPG and TextRPG.save then
                    pcall(function() TextRPG.save() end)
                end
                GameState.current = "menu"
            end
        end,
        onCancel = function()
            pauseState.subMenu = nil
            PauseMenu.createMainMenuButtons()
        end
    })
end

-- After loading a save, the global PlayerData table is replaced with a new table.
-- Modules that cached references to sub-tables of the OLD PlayerData (e.g., Backpack
-- caching PlayerData.backpack, Progression caching PlayerData.progression) will hold
-- stale references. We must re-initialize those modules so they pick up the new data.
function PauseMenu.reinitModulesAfterLoad()
    -- Backpack uses a weight/capacity cache that becomes stale when PlayerData changes.
    -- Invalidate those caches so the next access recomputes from the new data.
    -- Backpack functions access PlayerData.backpack through the global each call,
    -- so there are no stale table references -- only stale cached computations.
    if Backpack then
        if Backpack.invalidateWeightCache then
            pcall(function() Backpack.invalidateWeightCache() end)
        end
        if Backpack.invalidateCapacityCache then
            pcall(function() Backpack.invalidateCapacityCache() end)
        end
        -- Re-run init to ensure the new PlayerData.backpack sub-table exists and
        -- any migration steps are applied to the newly loaded data.
        if Backpack.init then
            pcall(function() Backpack.init() end)
        end
    end

    -- Progression reads PlayerData.progression; re-init ensures the sub-table exists
    -- in the newly loaded data and creates it with defaults if missing.
    if Progression and Progression.init then
        pcall(function() Progression.init() end)
    end

    -- RumorSystem caches an _initialized flag that persists across save slot switches.
    -- Reset it so the next init() call properly re-initializes with the new slot's data.
    local RumorSystem = require("rumorsystem")
    if RumorSystem and RumorSystem.reset then
        pcall(function() RumorSystem.reset() end)
    end

    -- CafeGame, StockMarket, and other game-mode modules read PlayerData lazily
    -- when their game state becomes active (via changeState -> Module.init()).
    -- They do not need explicit re-init here since they are never active while
    -- the pause menu is open.
end

function PauseMenu.createConfirmSaveModal(slotIndex)
    local slotLabel = "Slot " .. slotIndex
    local slots = SaveSystem.getAllSlotInfos and SaveSystem.getAllSlotInfos() or {}
    local slotInfo = slots[slotIndex]
    local message = "Save current progress to " .. slotLabel .. "?"
    if slotInfo and slotInfo.exists and not slotInfo.corrupted then
        message = "Overwrite existing save in " .. slotLabel .. "?\nThis will replace the current data in that slot."
    end

    uiComponents.confirmModal = UI.Modal.new({
        title = "Confirm Save",
        message = message,
        variant = "confirm",
        width = 400,
        height = 220,
        onConfirm = function()
            local TextRPG = require("textrpg")
            if TextRPG and TextRPG.save then
                pcall(function() TextRPG.save() end)
            end
            if SaveSystem.switchSlot then SaveSystem.switchSlot(slotIndex) end
            if SaveSystem.saveSlot and PlayerData then SaveSystem.saveSlot(slotIndex, PlayerData) end
            pauseState.subMenu = nil
            pauseState.pendingSlot = nil
            PauseMenu.createMainMenuButtons()
        end,
        onCancel = function()
            -- Return to the save slot list
            pauseState.subMenu = "save"
            pauseState.pendingSlot = nil
            PauseMenu.createSaveLoadControls("save")
        end
    })
end

function PauseMenu.createConfirmLoadModal(slotIndex)
    local slotLabel = "Slot " .. slotIndex

    uiComponents.confirmModal = UI.Modal.new({
        title = "Confirm Load",
        message = "Load save from " .. slotLabel .. "?\nAny unsaved progress will be lost.",
        variant = "confirm",
        width = 400,
        height = 220,
        onConfirm = function()
            -- Save current state before loading to prevent accidental data loss
            if savePlayerData then
                pcall(function() savePlayerData() end)
            end
            local TextRPG = require("textrpg")
            if TextRPG and TextRPG.save then
                pcall(function() TextRPG.save() end)
            end

            -- Switch to the target slot and load via the global loadPlayerData()
            -- which properly sets up PlayerData fields and calculates offline income.
            if SaveSystem.switchSlot then SaveSystem.switchSlot(slotIndex) end
            if loadPlayerData then
                loadPlayerData()
            else
                -- Fallback: direct assignment (less safe, but functional)
                if SaveSystem.loadSlot then PlayerData = SaveSystem.loadSlot(slotIndex) end
            end

            -- Re-load TextRPG state from the newly loaded PlayerData
            if TextRPG and TextRPG.load then
                pcall(function() TextRPG.load() end)
            end

            -- Re-initialize modules that may hold stale references to old PlayerData sub-tables
            PauseMenu.reinitModulesAfterLoad()

            pauseState.pendingSlot = nil
            PauseMenu.close()
        end,
        onCancel = function()
            -- Return to the load slot list
            pauseState.subMenu = "load"
            pauseState.pendingSlot = nil
            PauseMenu.createSaveLoadControls("load")
        end
    })
end

function PauseMenu.createSaveLoadControls(mode)
    local screenW, screenH = love.graphics.getDimensions()
    local panelW, panelH = 500, 450
    local panelX = screenW/2 - panelW/2
    local panelY = screenH/2 - panelH/2

    -- Create save/load panel
    uiPanels.saveLoadPanel = UI.Panel.new({
        x = panelX,
        y = panelY,
        w = panelW,
        h = panelH,
        title = nil,
        borderColor = {0.6, 0.5, 0.3},
    })

    uiComponents.saveLoadSlots = {}

    -- Save slots
    local slotH = 90
    local slotW = panelW - 40
    local slotX = panelX + 20
    local startY = panelY + 60

    local slots = SaveSystem.getAllSlotInfos and SaveSystem.getAllSlotInfos() or {}
    for i, slot in ipairs(slots) do
        if i > 3 then break end

        if slot and slot.exists and not slot.corrupted then
            local actionW, actionH = 70, 26
            local actionX = slotX + slotW - actionW - 15
            local slotY = startY + (i-1) * (slotH + 10)
            local actionY2 = slotY + slotH - actionH - 10

            if mode == "save" then
                uiComponents.saveLoadSlots[i] = UI.Button.new({
                    x = actionX,
                    y = actionY2,
                    w = actionW,
                    h = actionH,
                    text = "Save",
                    variant = "ghost",
                    onClick = function()
                        pauseState.pendingSlot = i
                        pauseState.subMenu = "confirm_save"
                        PauseMenu.createConfirmSaveModal(i)
                    end
                })
            elseif mode == "load" then
                uiComponents.saveLoadSlots[i] = UI.Button.new({
                    x = actionX,
                    y = actionY2,
                    w = actionW,
                    h = actionH,
                    text = "Load",
                    variant = "ghost",
                    onClick = function()
                        pauseState.pendingSlot = i
                        pauseState.subMenu = "confirm_load"
                        PauseMenu.createConfirmLoadModal(i)
                    end
                })
            end
        elseif not (slot and slot.exists) and mode == "save" then
            -- Empty slot, allow save
            local actionW, actionH = 70, 26
            local actionX = slotX + slotW - actionW - 15
            local slotY = startY + (i-1) * (slotH + 10)
            local actionY2 = slotY + slotH - actionH - 10

            uiComponents.saveLoadSlots[i] = UI.Button.new({
                x = actionX,
                y = actionY2,
                w = actionW,
                h = actionH,
                text = "Save",
                variant = "ghost",
                onClick = function()
                    pauseState.pendingSlot = i
                    pauseState.subMenu = "confirm_save"
                    PauseMenu.createConfirmSaveModal(i)
                end
            })
        end
    end

    -- Back button
    local backW, backH = 120, 40
    local backX = panelX + panelW/2 - backW/2
    local backY = panelY + panelH - 55

    uiComponents.backButton = UI.Button.new({
        x = backX,
        y = backY,
        w = backW,
        h = backH,
        text = "Back",
        variant = "ghost",
        onClick = function()
            pauseState.subMenu = nil
            PauseMenu.createMainMenuButtons()
        end
    })
end

-- ============================================================================
--                      UPDATE
-- ============================================================================

function PauseMenu.update(dt)
    if not pauseState.active then return end

    -- Update UI animation system
    UI.anim.update(dt)

    -- Update components based on current menu
    if pauseState.subMenu == "confirm_quit"
        or pauseState.subMenu == "confirm_save"
        or pauseState.subMenu == "confirm_load" then
        if uiComponents.confirmModal then
            uiComponents.confirmModal:update(dt)
        end
    elseif pauseState.subMenu == "settings" then
        if uiPanels.settingsPanel then
            uiPanels.settingsPanel:update(dt)
        end
        for _, control in pairs(uiComponents.settingsControls) do
            if control and control.update then
                control:update(dt)
            end
        end
        if uiComponents.backButton then
            uiComponents.backButton:update(dt)
        end
    elseif pauseState.subMenu == "save" or pauseState.subMenu == "load" then
        if uiPanels.saveLoadPanel then
            uiPanels.saveLoadPanel:update(dt)
        end
        for _, slot in pairs(uiComponents.saveLoadSlots) do
            if slot and slot.update then
                slot:update(dt)
            end
        end
        if uiComponents.backButton then
            uiComponents.backButton:update(dt)
        end
    else
        -- Main menu
        if uiPanels.mainPanel then
            uiPanels.mainPanel:update(dt)
        end
        for _, btn in ipairs(uiComponents.mainButtons) do
            if btn and btn.update then
                btn:update(dt)
            end
        end
    end
end

-- ============================================================================
--                      DRAW
-- ============================================================================

function PauseMenu.draw()
    if not pauseState.active then return end

    local screenW, screenH = love.graphics.getDimensions()

    -- Dim overlay
    love.graphics.setColor(UI.theme.colors.overlay)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    love.graphics.setColor(1, 1, 1, 1)

    if pauseState.subMenu == "settings" then
        PauseMenu.drawSettings(screenW, screenH)
    elseif pauseState.subMenu == "save" then
        PauseMenu.drawSaveLoad(screenW, screenH, "save")
    elseif pauseState.subMenu == "load" then
        PauseMenu.drawSaveLoad(screenW, screenH, "load")
    elseif pauseState.subMenu == "confirm_quit"
        or pauseState.subMenu == "confirm_save"
        or pauseState.subMenu == "confirm_load" then
        PauseMenu.drawConfirmQuit(screenW, screenH)
    else
        PauseMenu.drawMainMenu(screenW, screenH)
    end
end

function PauseMenu.drawMainMenu(screenW, screenH)
    local panelW, panelH = 360, 436
    local panelX = screenW/2 - panelW/2
    local panelY = screenH/2 - panelH/2

    -- Draw panel background using UI.Panel
    if uiPanels.mainPanel then
        uiPanels.mainPanel:draw()
    end

    -- Title
    love.graphics.setColor(UI.theme.colors.primary)
    love.graphics.setFont(UI.fonts.get(28))
    local title = "PAUSED"
    local titleW = love.graphics.getFont():getWidth(title)
    love.graphics.print(title, panelX + panelW/2 - titleW/2, panelY + 25)

    -- Draw buttons
    for _, btn in ipairs(uiComponents.mainButtons) do
        if btn then
            btn:draw()
        end
    end

    -- Hint text
    love.graphics.setColor(UI.theme.colors.textDim)
    love.graphics.setFont(UI.fonts.get(12))
    local hint = "ESC to resume   |   Arrow keys + Enter to navigate"
    local hintW = love.graphics.getFont():getWidth(hint)
    love.graphics.print(hint, panelX + panelW/2 - hintW/2, panelY + panelH - 30)

    love.graphics.setColor(1, 1, 1, 1)
end

function PauseMenu.drawSettings(screenW, screenH)
    local panelW, panelH = 450, 450
    local panelX = screenW/2 - panelW/2
    local panelY = screenH/2 - panelH/2

    -- Draw panel background using UI.Panel
    if uiPanels.settingsPanel then
        uiPanels.settingsPanel:draw()
    end

    -- Title
    love.graphics.setColor(UI.theme.colors.primary)
    love.graphics.setFont(UI.fonts.get(24))
    local title = "SETTINGS"
    local titleW = love.graphics.getFont():getWidth(title)
    love.graphics.print(title, panelX + panelW/2 - titleW/2, panelY + 20)

    -- Settings items
    local startY = panelY + 70
    local itemH = 55
    local contentX = panelX + 30

    for i, item in ipairs(SETTINGS_ITEMS) do
        local itemY = startY + (i-1) * itemH

        -- Label
        love.graphics.setColor(UI.theme.colors.text)
        love.graphics.setFont(UI.fonts.get(16))
        love.graphics.print(item.label, contentX, itemY)

        -- Draw control
        if uiComponents.settingsControls[i] then
            uiComponents.settingsControls[i]:draw()
        end
    end

    -- Back button
    if uiComponents.backButton then
        uiComponents.backButton:draw()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function PauseMenu.drawSaveLoad(screenW, screenH, mode)
    local panelW, panelH = 500, 450
    local panelX = screenW/2 - panelW/2
    local panelY = screenH/2 - panelH/2

    -- Draw panel background using UI.Panel
    if uiPanels.saveLoadPanel then
        uiPanels.saveLoadPanel:draw()
    end

    -- Title
    love.graphics.setColor(UI.theme.colors.primary)
    love.graphics.setFont(UI.fonts.get(24))
    local title = mode == "save" and "SAVE GAME" or "LOAD GAME"
    local titleW = love.graphics.getFont():getWidth(title)
    love.graphics.print(title, panelX + panelW/2 - titleW/2, panelY + 20)

    -- Save slots
    local slotH = 90
    local slotW = panelW - 40
    local slotX = panelX + 20
    local startY = panelY + 60

    local slots = SaveSystem.getAllSlotInfos and SaveSystem.getAllSlotInfos() or {}
    for i, slot in ipairs(slots) do
        if i > 3 then break end
        local slotY = startY + (i-1) * (slotH + 10)
        local isActive = SaveSystem.activeSlot == i

        -- Slot background
        if isActive then
            love.graphics.setColor(0.15, 0.30, 0.20)
        else
            love.graphics.setColor(0.14, 0.14, 0.18)
        end
        love.graphics.rectangle("fill", slotX, slotY, slotW, slotH, 8, 8)

        -- Border
        love.graphics.setColor(isActive and UI.theme.colors.success or {0.35, 0.35, 0.40})
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", slotX, slotY, slotW, slotH, 8, 8)

        -- Slot info
        love.graphics.setFont(UI.fonts.get(16))
        love.graphics.setColor(UI.theme.colors.text)
        local slotTitle = "Slot " .. i
        if isActive then slotTitle = slotTitle .. " (Current)" end
        love.graphics.print(slotTitle, slotX + 15, slotY + 10)

        if slot and slot.exists then
            love.graphics.setFont(UI.fonts.get(13))
            love.graphics.setColor(UI.theme.colors.textDim)
            if slot.corrupted then
                love.graphics.setColor(UI.theme.colors.danger)
                love.graphics.print("CORRUPTED", slotX + 15, slotY + 35)
            else
                love.graphics.print(string.format("Wins: %d | Losses: %d | Coins: %d",
                    slot.wins or 0, slot.losses or 0, slot.coins or 0), slotX + 15, slotY + 35)
                love.graphics.print(string.format("Games: %d", slot.totalGamesPlayed or 0), slotX + 15, slotY + 55)
            end

            -- Draw action button
            if uiComponents.saveLoadSlots[i] then
                uiComponents.saveLoadSlots[i]:draw()
            end
        else
            love.graphics.setFont(UI.fonts.get(13))
            love.graphics.setColor(UI.theme.colors.textDim)
            love.graphics.print("Empty Slot", slotX + 15, slotY + 40)

            if mode == "save" and uiComponents.saveLoadSlots[i] then
                uiComponents.saveLoadSlots[i]:draw()
            end
        end
    end

    -- Back button
    if uiComponents.backButton then
        uiComponents.backButton:draw()
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function PauseMenu.drawConfirmQuit(screenW, screenH)
    if uiComponents.confirmModal then
        uiComponents.confirmModal:draw()
    end
end

-- ============================================================================
--                     INPUT HANDLING
-- ============================================================================

function PauseMenu.keypressed(key)
    if not pauseState.active then return false end

    if pauseState.subMenu == "confirm_quit"
        or pauseState.subMenu == "confirm_save"
        or pauseState.subMenu == "confirm_load" then
        if uiComponents.confirmModal then
            return uiComponents.confirmModal:keypressed(key)
        end
        return true
    end

    if pauseState.subMenu then
        if key == "escape" then
            pauseState.subMenu = nil
            PauseMenu.createMainMenuButtons()
            return true
        end
        -- Sub-menus handle their own key input minimally
        return true
    end

    -- Main menu key handling
    if key == "escape" then
        PauseMenu.close()
        return true
    elseif key == "up" then
        pauseState.selectedButton = pauseState.selectedButton - 1
        if pauseState.selectedButton < 1 then pauseState.selectedButton = #MAIN_BUTTONS end
        return true
    elseif key == "down" then
        pauseState.selectedButton = pauseState.selectedButton + 1
        if pauseState.selectedButton > #MAIN_BUTTONS then pauseState.selectedButton = 1 end
        return true
    elseif key == "return" or key == "space" then
        PauseMenu.activateButton(MAIN_BUTTONS[pauseState.selectedButton])
        return true
    end

    return true
end

function PauseMenu.activateButton(btn)
    if not btn then return end
    if btn.id == "resume" then
        PauseMenu.close()
    elseif btn.id == "knowledge" then
        PauseMenu.close()
        KnowledgeCenter.init()
    elseif btn.id == "settings" then
        pauseState.subMenu = "settings"
        PauseMenu.createSettingsControls()
    elseif btn.id == "save" then
        pauseState.subMenu = "save"
        PauseMenu.createSaveLoadControls("save")
    elseif btn.id == "load" then
        pauseState.subMenu = "load"
        PauseMenu.createSaveLoadControls("load")
    elseif btn.id == "quit" then
        pauseState.subMenu = "confirm_quit"
        PauseMenu.createConfirmQuitModal()
    end
end

function PauseMenu.mousepressed(x, y, button)
    if not pauseState.active then return false end
    if button ~= 1 then return true end

    if pauseState.subMenu == "confirm_quit"
        or pauseState.subMenu == "confirm_save"
        or pauseState.subMenu == "confirm_load" then
        if uiComponents.confirmModal then
            return uiComponents.confirmModal:mousepressed(x, y, button)
        end
        return true
    end

    if pauseState.subMenu == "settings" then
        -- Check settings controls
        for _, control in pairs(uiComponents.settingsControls) do
            if control and control.mousepressed and control:mousepressed(x, y, button) then
                return true
            end
        end

        -- Check back button
        if uiComponents.backButton and uiComponents.backButton:mousepressed(x, y, button) then
            return true
        end

        return true
    end

    if pauseState.subMenu == "save" or pauseState.subMenu == "load" then
        -- Check slot buttons
        for _, slot in pairs(uiComponents.saveLoadSlots) do
            if slot and slot.mousepressed and slot:mousepressed(x, y, button) then
                return true
            end
        end

        -- Check back button
        if uiComponents.backButton and uiComponents.backButton:mousepressed(x, y, button) then
            return true
        end

        return true
    end

    -- Main menu buttons
    for i, btn in ipairs(uiComponents.mainButtons) do
        if btn and btn.mousepressed and btn:mousepressed(x, y, button) then
            pauseState.selectedButton = i
            return true
        end
    end

    return true
end

function PauseMenu.mousereleased(x, y, button)
    if not pauseState.active then return false end
    if button ~= 1 then return false end

    if pauseState.subMenu == "confirm_quit"
        or pauseState.subMenu == "confirm_save"
        or pauseState.subMenu == "confirm_load" then
        if uiComponents.confirmModal and uiComponents.confirmModal.mousereleased then
            uiComponents.confirmModal:mousereleased(x, y, button)
        end
        return true
    end

    if pauseState.subMenu == "settings" then
        for _, control in pairs(uiComponents.settingsControls) do
            if control and control.mousereleased then
                control:mousereleased(x, y, button)
            end
        end
        if uiComponents.backButton and uiComponents.backButton.mousereleased then
            uiComponents.backButton:mousereleased(x, y, button)
        end
        return true
    end

    if pauseState.subMenu == "save" or pauseState.subMenu == "load" then
        for _, slot in pairs(uiComponents.saveLoadSlots) do
            if slot and slot.mousereleased then
                slot:mousereleased(x, y, button)
            end
        end
        if uiComponents.backButton and uiComponents.backButton.mousereleased then
            uiComponents.backButton:mousereleased(x, y, button)
        end
        return true
    end

    -- Main menu
    for _, btn in ipairs(uiComponents.mainButtons) do
        if btn and btn.mousereleased then
            btn:mousereleased(x, y, button)
        end
    end

    return true
end

function PauseMenu.wheelmoved(wx, wy)
    if not pauseState.active then return false end
    return true
end

return PauseMenu
