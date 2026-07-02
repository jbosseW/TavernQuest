-- Options Menu System

local Options = {}

-- Font cache for performance
local FontCache = require("fontcache")
local Theme = require("theme")
local function getFont(size)
    return FontCache.get(size)
end

-- UI State
local showOptions = false
local showSaveMenu = false
local scrollOffset = 0

-- Colors (centralized in theme.lua)
local colors = Theme.colors

function Options.init()
    showOptions = false
    showSaveMenu = false
    scrollOffset = 0
end

function Options.isOpen()
    return showOptions or showSaveMenu
end

function Options.openOptions()
    showOptions = true
    showSaveMenu = false
end

function Options.openSaveMenu()
    showSaveMenu = true
    showOptions = false
end

function Options.close()
    showOptions = false
    showSaveMenu = false
end

function Options.update(dt)
    -- Nothing to update for now
end

function Options.draw()
    if showOptions then
        Options.drawOptionsMenu()
    elseif showSaveMenu then
        Options.drawSaveMenu()
    end
end

function Options.drawOptionsMenu()
    local screenW, screenH = love.graphics.getDimensions()
    local panelW, panelH = 400, 450
    local panelX = screenW/2 - panelW/2
    local panelY = screenH/2 - panelH/2

    -- Dim background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Panel background
    love.graphics.setColor(colors.panel)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 15, 15)
    love.graphics.setColor(colors.accent)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 15, 15)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(colors.accent)
    love.graphics.setFont(getFont(32))
    local title = "OPTIONS"
    local titleW = love.graphics.getFont():getWidth(title)
    love.graphics.print(title, panelX + panelW/2 - titleW/2, panelY + 20)

    local startY = panelY + 80
    local buttonW, buttonH = 300, 45
    local buttonX = panelX + panelW/2 - buttonW/2
    local spacing = 55

    local mx, my = love.mouse.getPosition()

    -- Music Toggle
    local musicMuted = PlayerData.settings and PlayerData.settings.musicMuted or false
    local musicText = musicMuted and "Music: OFF" or "Music: ON"
    local musicColor = musicMuted and colors.buttonDanger or colors.button
    local musicHover = mx >= buttonX and mx <= buttonX + buttonW and my >= startY and my <= startY + buttonH

    love.graphics.setColor(musicHover and colors.buttonHover or musicColor)
    love.graphics.rectangle("fill", buttonX, startY, buttonW, buttonH, 8, 8)
    love.graphics.setColor(colors.text)
    love.graphics.setFont(getFont(18))
    local textW = love.graphics.getFont():getWidth(musicText)
    love.graphics.print(musicText, buttonX + buttonW/2 - textW/2, startY + buttonH/2 - 9)

    -- Fullscreen Toggle
    local isFullscreen = love.window.getFullscreen()
    local fullscreenText = isFullscreen and "Fullscreen: ON" or "Fullscreen: OFF"
    local fullscreenY = startY + spacing
    local fullscreenHover = mx >= buttonX and mx <= buttonX + buttonW and my >= fullscreenY and my <= fullscreenY + buttonH

    love.graphics.setColor(fullscreenHover and colors.buttonHover or colors.button)
    love.graphics.rectangle("fill", buttonX, fullscreenY, buttonW, buttonH, 8, 8)
    love.graphics.setColor(colors.text)
    textW = love.graphics.getFont():getWidth(fullscreenText)
    love.graphics.print(fullscreenText, buttonX + buttonW/2 - textW/2, fullscreenY + buttonH/2 - 9)

    -- Combat Mode Toggle (Phase 9: Tactical vs Classic)
    local combatModeY = fullscreenY + spacing
    local isTactical = PlayerData.settings and PlayerData.settings.tacticalCombat
    if isTactical == nil then isTactical = true end  -- Default to tactical
    local combatText = isTactical and "Combat: Tactical Grid" or "Combat: Classic"
    local combatColor = isTactical and {0.2, 0.4, 0.6} or colors.button
    local combatHover = mx >= buttonX and mx <= buttonX + buttonW and my >= combatModeY and my <= combatModeY + buttonH

    love.graphics.setColor(combatHover and colors.buttonHover or combatColor)
    love.graphics.rectangle("fill", buttonX, combatModeY, buttonW, buttonH, 8, 8)
    love.graphics.setColor(colors.text)
    textW = love.graphics.getFont():getWidth(combatText)
    love.graphics.print(combatText, buttonX + buttonW/2 - textW/2, combatModeY + buttonH/2 - 9)

    -- Save Slots Button
    local saveY = combatModeY + spacing
    local saveHover = mx >= buttonX and mx <= buttonX + buttonW and my >= saveY and my <= saveY + buttonH

    love.graphics.setColor(saveHover and colors.buttonHover or colors.button)
    love.graphics.rectangle("fill", buttonX, saveY, buttonW, buttonH, 8, 8)
    love.graphics.setColor(colors.text)
    local saveText = "Manage Save Slots"
    textW = love.graphics.getFont():getWidth(saveText)
    love.graphics.print(saveText, buttonX + buttonW/2 - textW/2, saveY + buttonH/2 - 9)

    -- Volume slider display
    local volumeY = saveY + spacing + 20
    love.graphics.setColor(colors.textDim)
    love.graphics.setFont(getFont(14))
    local volume = PlayerData.settings and PlayerData.settings.musicVolume or 0.3
    love.graphics.print(string.format("Volume: %.0f%%", volume * 100), buttonX, volumeY)

    -- Volume slider
    local sliderY = volumeY + 25
    local sliderW = buttonW
    love.graphics.setColor(0.3, 0.3, 0.35)
    love.graphics.rectangle("fill", buttonX, sliderY, sliderW, 10, 5, 5)
    love.graphics.setColor(colors.accent)
    love.graphics.rectangle("fill", buttonX, sliderY, sliderW * volume, 10, 5, 5)
    love.graphics.setColor(colors.text)
    love.graphics.circle("fill", buttonX + sliderW * volume, sliderY + 5, 8)

    -- Close button
    local closeY = panelY + panelH - 65
    local closeHover = mx >= buttonX and mx <= buttonX + buttonW and my >= closeY and my <= closeY + buttonH

    love.graphics.setColor(closeHover and colors.buttonDangerHover or colors.buttonDanger)
    love.graphics.rectangle("fill", buttonX, closeY, buttonW, buttonH, 8, 8)
    love.graphics.setColor(colors.text)
    love.graphics.setFont(getFont(18))
    local closeText = "Close"
    textW = love.graphics.getFont():getWidth(closeText)
    love.graphics.print(closeText, buttonX + buttonW/2 - textW/2, closeY + buttonH/2 - 9)
end

function Options.drawSaveMenu()
    local SaveSystem = require("savesystem")
    local screenW, screenH = love.graphics.getDimensions()
    local panelW, panelH = 500, 500
    local panelX = screenW/2 - panelW/2
    local panelY = screenH/2 - panelH/2

    -- Dim background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Panel background
    love.graphics.setColor(colors.panel)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 15, 15)
    love.graphics.setColor(colors.accent)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 15, 15)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(colors.accent)
    love.graphics.setFont(getFont(28))
    local title = "SAVE SLOTS"
    local titleW = love.graphics.getFont():getWidth(title)
    love.graphics.print(title, panelX + panelW/2 - titleW/2, panelY + 20)

    local mx, my = love.mouse.getPosition()
    local slotH = 110
    local slotW = panelW - 40
    local slotX = panelX + 20
    local startY = panelY + 70

    -- Draw each slot
    local slots = SaveSystem.getAllSlotInfos()
    for i, slot in ipairs(slots) do
        local slotY = startY + (i-1) * (slotH + 10)
        local isActive = SaveSystem.activeSlot == i
        local hover = mx >= slotX and mx <= slotX + slotW and my >= slotY and my <= slotY + slotH

        -- Slot background
        if isActive then
            love.graphics.setColor(0.2, 0.35, 0.25)
        elseif hover then
            love.graphics.setColor(0.25, 0.25, 0.3)
        else
            love.graphics.setColor(0.18, 0.18, 0.22)
        end
        love.graphics.rectangle("fill", slotX, slotY, slotW, slotH, 10, 10)

        -- Border
        if isActive then
            love.graphics.setColor(colors.success)
        else
            love.graphics.setColor(0.4, 0.4, 0.45)
        end
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", slotX, slotY, slotW, slotH, 10, 10)
        love.graphics.setLineWidth(1)

        -- Slot info
        love.graphics.setFont(getFont(18))
        love.graphics.setColor(colors.text)
        local slotTitle = "Slot " .. i
        if isActive then slotTitle = slotTitle .. " (Active)" end
        love.graphics.print(slotTitle, slotX + 15, slotY + 10)

        if slot.exists then
            love.graphics.setFont(getFont(14))
            if slot.corrupted then
                love.graphics.setColor(0.9, 0.3, 0.3)
                love.graphics.print("CORRUPTED SAVE - Click Delete to remove", slotX + 15, slotY + 35)
                love.graphics.setColor(colors.textDim)
                love.graphics.print("This save file has invalid data", slotX + 15, slotY + 55)
            else
                love.graphics.setColor(colors.textDim)
                love.graphics.print(string.format("Wins: %d  |  Losses: %d  |  Coins: %d",
                    slot.wins, slot.losses, slot.coins), slotX + 15, slotY + 35)
                love.graphics.print(string.format("Games Played: %d", slot.totalGamesPlayed or 0),
                    slotX + 15, slotY + 55)
            end

            -- Action buttons
            local btnW, btnH = 80, 28
            local btnY = slotY + slotH - 40

            if slot.corrupted then
                -- Only show delete button for corrupted saves
                local delX = slotX + 15
                local delHover = mx >= delX and mx <= delX + btnW and my >= btnY and my <= btnY + btnH
                love.graphics.setColor(delHover and colors.buttonDangerHover or colors.buttonDanger)
                love.graphics.rectangle("fill", delX, btnY, btnW, btnH, 5, 5)
                love.graphics.setColor(colors.text)
                love.graphics.setFont(getFont(12))
                love.graphics.print("Delete", delX + 18, btnY + 7)
            else
                -- Load/Switch button (if not active)
                if not isActive then
                    local loadX = slotX + 15
                    local loadHover = mx >= loadX and mx <= loadX + btnW and my >= btnY and my <= btnY + btnH
                    love.graphics.setColor(loadHover and colors.buttonHover or colors.button)
                    love.graphics.rectangle("fill", loadX, btnY, btnW, btnH, 5, 5)
                    love.graphics.setColor(colors.text)
                    love.graphics.setFont(getFont(12))
                    love.graphics.print("Load", loadX + 25, btnY + 7)
                end

                -- Soft Delete button
                local softX = slotX + (isActive and 15 or 105)
                local softHover = mx >= softX and mx <= softX + btnW and my >= btnY and my <= btnY + btnH
                love.graphics.setColor(softHover and {0.9, 0.7, 0.2} or {0.7, 0.5, 0.1})
                love.graphics.rectangle("fill", softX, btnY, btnW, btnH, 5, 5)
                love.graphics.setColor(colors.text)
                love.graphics.setFont(getFont(12))
                love.graphics.print("Reset", softX + 22, btnY + 7)

                -- Delete button
                local delX = softX + 90
                local delHover = mx >= delX and mx <= delX + btnW and my >= btnY and my <= btnY + btnH
                love.graphics.setColor(delHover and colors.buttonDangerHover or colors.buttonDanger)
                love.graphics.rectangle("fill", delX, btnY, btnW, btnH, 5, 5)
                love.graphics.setColor(colors.text)
                love.graphics.print("Delete", delX + 18, btnY + 7)
            end
        else
            love.graphics.setFont(getFont(14))
            love.graphics.setColor(colors.textDim)
            love.graphics.print("Empty Slot - Click to create new save", slotX + 15, slotY + 45)
        end
    end

    -- Back button
    local backY = panelY + panelH - 55
    local backW, backH = 150, 40
    local backX = panelX + panelW/2 - backW/2
    local backHover = mx >= backX and mx <= backX + backW and my >= backY and my <= backY + backH

    love.graphics.setColor(backHover and colors.buttonHover or colors.button)
    love.graphics.rectangle("fill", backX, backY, backW, backH, 8, 8)
    love.graphics.setColor(colors.text)
    love.graphics.setFont(getFont(16))
    local backText = "Back"
    local textW = love.graphics.getFont():getWidth(backText)
    love.graphics.print(backText, backX + backW/2 - textW/2, backY + backH/2 - 8)
end

function Options.mousepressed(x, y, button)
    if button ~= 1 then return false end

    local screenW, screenH = love.graphics.getDimensions()

    if showOptions then
        local panelW, panelH = 400, 450
        local panelX = screenW/2 - panelW/2
        local panelY = screenH/2 - panelH/2
        local buttonW, buttonH = 300, 45
        local buttonX = panelX + panelW/2 - buttonW/2
        local startY = panelY + 80
        local spacing = 55

        -- Music toggle
        if x >= buttonX and x <= buttonX + buttonW and y >= startY and y <= startY + buttonH then
            if not PlayerData.settings then PlayerData.settings = {} end
            PlayerData.settings.musicMuted = not PlayerData.settings.musicMuted
            if PlayerData.settings.musicMuted then
                if AudioSystem then AudioSystem.stopAll() end
            else
                if AudioSystem then AudioSystem.playMenuMusic() end
            end
            local SaveSystem = require("savesystem")
            SaveSystem.saveCurrentSlot(PlayerData)
            return true
        end

        -- Fullscreen toggle
        local fullscreenY = startY + spacing
        if x >= buttonX and x <= buttonX + buttonW and y >= fullscreenY and y <= fullscreenY + buttonH then
            local isFullscreen = love.window.getFullscreen()
            love.window.setFullscreen(not isFullscreen)
            if not PlayerData.settings then PlayerData.settings = {} end
            PlayerData.settings.fullscreen = not isFullscreen
            local SaveSystem = require("savesystem")
            SaveSystem.saveCurrentSlot(PlayerData)
            return true
        end

        -- Combat mode toggle (Phase 9)
        local combatModeY = fullscreenY + spacing
        if x >= buttonX and x <= buttonX + buttonW and y >= combatModeY and y <= combatModeY + buttonH then
            if not PlayerData.settings then PlayerData.settings = {} end
            if PlayerData.settings.tacticalCombat == nil then
                PlayerData.settings.tacticalCombat = true
            end
            PlayerData.settings.tacticalCombat = not PlayerData.settings.tacticalCombat
            -- Signal textrpg to update TACTICAL_MODE
            Options._combatModeChanged = true
            Options._newTacticalMode = PlayerData.settings.tacticalCombat
            local SaveSystem = require("savesystem")
            SaveSystem.saveCurrentSlot(PlayerData)
            return true
        end

        -- Save slots button
        local saveY = combatModeY + spacing
        if x >= buttonX and x <= buttonX + buttonW and y >= saveY and y <= saveY + buttonH then
            Options.openSaveMenu()
            return true
        end

        -- Volume slider (bar is 10px tall, knob radius is 8, centered at bar+5)
        local volumeY = saveY + spacing + 45
        local knobRadius = 8
        if y >= volumeY - knobRadius and y <= volumeY + 10 + knobRadius and x >= buttonX - knobRadius and x <= buttonX + buttonW + knobRadius then
            local volume = (x - buttonX) / buttonW
            volume = math.max(0, math.min(1, volume))
            if not PlayerData.settings then PlayerData.settings = {} end
            PlayerData.settings.musicVolume = volume
            if AudioSystem and AudioSystem.menuMusic then
                AudioSystem.menuMusic:setVolume(volume)
            end
            if AudioSystem and AudioSystem.gameMusic then
                AudioSystem.gameMusic:setVolume(volume)
            end
            local SaveSystem = require("savesystem")
            SaveSystem.saveCurrentSlot(PlayerData)
            return true
        end

        -- Close button
        local closeY = panelY + panelH - 65
        if x >= buttonX and x <= buttonX + buttonW and y >= closeY and y <= closeY + buttonH then
            Options.close()
            return true
        end

        return true  -- Consume click on options panel
    end

    if showSaveMenu then
        local SaveSystem = require("savesystem")
        local panelW, panelH = 500, 500
        local panelX = screenW/2 - panelW/2
        local panelY = screenH/2 - panelH/2
        local slotH = 110
        local slotW = panelW - 40
        local slotX = panelX + 20
        local startY = panelY + 70

        local slots = SaveSystem.getAllSlotInfos()
        for i, slot in ipairs(slots) do
            local slotY = startY + (i-1) * (slotH + 10)
            local isActive = SaveSystem.activeSlot == i

            -- Check if clicked on this slot
            if x >= slotX and x <= slotX + slotW and y >= slotY and y <= slotY + slotH then
                local btnW, btnH = 80, 28
                local btnY = slotY + slotH - 40

                if slot.exists then
                    if slot.corrupted then
                        -- Only Delete button for corrupted saves
                        local delX = slotX + 15
                        if x >= delX and x <= delX + btnW and y >= btnY and y <= btnY + btnH then
                            SaveSystem.deleteSlot(i)
                            if isActive then
                                PlayerData = SaveSystem.loadSlot(i)
                            end
                            return true
                        end
                    else
                        -- Load button (if not active)
                        if not isActive then
                            local loadX = slotX + 15
                            if x >= loadX and x <= loadX + btnW and y >= btnY and y <= btnY + btnH then
                                SaveSystem.switchSlot(i)
                                PlayerData = SaveSystem.loadSlot(i)
                                return true
                            end
                        end

                        -- Soft Delete button
                        local softX = slotX + (isActive and 15 or 105)
                        if x >= softX and x <= softX + btnW and y >= btnY and y <= btnY + btnH then
                            SaveSystem.softDeleteSlot(i)
                            if isActive then
                                PlayerData = SaveSystem.loadSlot(i)
                            end
                            return true
                        end

                        -- Delete button
                        local delX = softX + 90
                        if x >= delX and x <= delX + btnW and y >= btnY and y <= btnY + btnH then
                            SaveSystem.deleteSlot(i)
                            if isActive then
                                PlayerData = SaveSystem.loadSlot(i)
                            end
                            return true
                        end
                    end
                else
                    -- Create new save
                    SaveSystem.switchSlot(i)
                    PlayerData = SaveSystem.loadSlot(i)
                    SaveSystem.saveSlot(i, PlayerData)
                    return true
                end
            end
        end

        -- Back button
        local backY = panelY + panelH - 55
        local backW, backH = 150, 40
        local backX = panelX + panelW/2 - backW/2
        if x >= backX and x <= backX + backW and y >= backY and y <= backY + backH then
            showSaveMenu = false
            showOptions = true
            return true
        end

        return true  -- Consume click on save menu
    end

    return false
end

function Options.wheelmoved(x, y)
    -- Handle scrolling if needed
    return false
end

return Options
