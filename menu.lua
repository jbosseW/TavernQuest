-- Menu system for the card game

local Menu = {}
local UI = require("ui")
local StoryMode = require("storymode")
local GameModes = require("gamemodes")
local Options = require("options")
local UIAssets = require("uiassets")
local KnowledgeCenter = require("knowledgecenter")
local Theme = require("theme")

-- UI Elements
local buttons = {}
local statusText = ""
local searchingForGame = false
local searchTimer = 0
local backgroundImage = nil

-- Menu states
local showGameModes = false
local showStoryMode = false
local gameModeScroll = 0
local storyButtons = {}

-- Game mode filters
local modeFilters = {
    category = "all",  -- all, poker, roguelike, story, action, adventure, simulation, minigame, shop
    showLocked = true,
    showUnimplemented = true,
    searchText = "",
}
local filterButtons = {}
local favoriteScroll = 0
local mainMenuFavorites = {}  -- Buttons for favorites quick access on main menu

-- Dev mode state
local showDevPassword = false
local devPasswordInput = ""
local devPasswordError = false
local devModeActive = false

-- Bug report state
local showBugReport = false
local bugReportText = ""
local bugReportStatus = ""
local bugReportStatusTimer = 0

-- Forward declarations
local drawDevPasswordDialog
local drawBugReportDialog
local submitBugReport

-- Colors (centralized in theme.lua)
local colors = Theme.colors

function Menu.init()
    -- Initialize UI assets
    UIAssets.init()

    -- Load background image (new main menu art)
    backgroundImage = UIAssets.get("mainmenu_bg")
    if not backgroundImage and love.filesystem.getInfo("assets/mainmenu.png") then
        backgroundImage = love.graphics.newImage("assets/mainmenu.png")
    end

    Options.init()

    local screenW, screenH = love.graphics.getDimensions()

    -- Main center column buttons
    local buttonW, buttonH = 180, 45
    local startY = 510  -- Moved down significantly
    local spacing = 52

    -- Right side column buttons (smaller)
    local sideButtonW, sideButtonH = 130, 38
    local sideX = screenW - sideButtonW - 30
    local sideStartY = 200
    local sideSpacing = 48

    buttons = {
        -- ===== CENTER COLUMN: Main Gameplay =====
        UI.Button.new({
            x = screenW/2 - buttonW/2,
            y = startY,
            w = buttonW,
            h = buttonH,
            text = "Tavern Quest",
            variant = "primary",
            onClick = function()
                local TextRPG = require("textrpg")
                TextRPG.init()
                GameState.current = "textrpg"
            end
        }),
        UI.Button.new({
            x = screenW/2 - buttonW/2,
            y = startY + spacing,
            w = buttonW,
            h = buttonH,
            text = "Quit",
            variant = "danger",
            onClick = function()
                savePlayerData()
                love.event.quit()
            end
        }),

        -- ===== RIGHT SIDE COLUMN: Secondary Options =====
        UI.Button.new({
            x = sideX,
            y = sideStartY,
            w = sideButtonW,
            h = sideButtonH,
            text = "Lore",
            variant = "ghost",
            onClick = function()
                local Lore = require("lore")
                Lore.init()
                GameState.current = "lore"
            end
        }),
        UI.Button.new({
            x = sideX,
            y = sideStartY + sideSpacing,
            w = sideButtonW,
            h = sideButtonH,
            text = "Options",
            variant = "ghost",
            onClick = function()
                Options.openOptions()
            end
        }),
        UI.Button.new({
            x = sideX,
            y = sideStartY + sideSpacing * 2,
            w = sideButtonW,
            h = sideButtonH,
            text = "Credits",
            variant = "ghost",
            onClick = function()
                local Credits = require("credits")
                Credits.init()
                GameState.current = "credits"
            end
        }),
        UI.Button.new({
            x = sideX,
            y = sideStartY + sideSpacing * 3,
            w = sideButtonW,
            h = sideButtonH,
            text = "Guide",
            variant = "success",
            onClick = function()
                KnowledgeCenter.init()
            end
        }),

        -- ===== LEFT SIDE: Utility =====
        UI.Button.new({
            x = 20,
            y = screenH - 70,
            w = 140,
            h = 40,
            text = "Report Bug",
            variant = "ghost",
            onClick = function()
                showBugReport = true
                bugReportText = ""
                bugReportScreenshot = nil
                bugReportScreenshotPath = nil
                bugReportStatus = ""
                bugReportStatusTimer = 0
            end
        })
    }

    -- Mark dev-only button
    buttons[3].devOnly = true  -- Lore button
end

-- Helper function to check if mode is favorited
local function isFavorite(modeId)
    if not PlayerData.favoriteModes then
        PlayerData.favoriteModes = {}
    end
    for _, id in ipairs(PlayerData.favoriteModes) do
        if id == modeId then return true end
    end
    return false
end

-- Toggle favorite status
local function toggleFavorite(modeId)
    if not PlayerData.favoriteModes then
        PlayerData.favoriteModes = {}
    end
    for i, id in ipairs(PlayerData.favoriteModes) do
        if id == modeId then
            table.remove(PlayerData.favoriteModes, i)
            savePlayerData()
            return
        end
    end
    table.insert(PlayerData.favoriteModes, modeId)
    savePlayerData()
end

-- Get filtered modes list
local function getFilteredModes()
    local filtered = {}
    for _, mode in ipairs(GameModes.modes) do
        local include = true

        -- Category filter
        if modeFilters.category ~= "all" and mode.category ~= modeFilters.category then
            include = false
        end

        -- All modes are unlocked, no filter needed

        -- Unimplemented filter (bypassed in dev mode)
        if not devModeActive and not modeFilters.showUnimplemented and not mode.implemented then
            include = false
        end

        if include then
            table.insert(filtered, mode)
        end
    end
    return filtered
end

-- Launch a game mode
local function launchGameMode(mode)
    -- All modes are unlocked by default

    if mode.id == "visual_novel" then
        showGameModes = false
        showStoryMode = true
    elseif mode.id == "lootbox" then
        showGameModes = false
        local LootBox = require("lootbox")
        LootBox.init()
        GameState.current = "lootbox"
    elseif mode.id == "stock_market" then
        showGameModes = false
        local StockMarket = require("stockmarket")
        StockMarket.init()
        GameState.current = "stockmarket"
    elseif mode.id == "trading_cards" then
        showGameModes = false
        local TradingCards = require("tradingcards")
        TradingCards.init()
        GameState.current = "tradingcards"
    elseif mode.id == "stats_page" then
        showGameModes = false
        local StatsPage = require("statspage")
        StatsPage.init()
        GameState.current = "statspage"
    elseif mode.id == "text_rpg" then
        showGameModes = false
        local TextRPG = require("textrpg")
        TextRPG.init()
        GameState.current = "textrpg"
    elseif mode.id == "pet_sim" then
        showGameModes = false
        local PetSim = require("petsim")
        PetSim.init()
        GameState.current = "petsim"
    elseif mode.id == "fishing" then
        showGameModes = false
        local Fishing = require("fishing")
        Fishing.init()
        GameState.current = "fishing"
    elseif mode.id == "forge" then
        showGameModes = false
        local Forge = require("forge")
        Forge.init()
        GameState.current = "forge"
    elseif mode.id == "hunting" then
        showGameModes = false
        local Hunting = require("hunting")
        Hunting.init()
        GameState.current = "hunting"
    elseif mode.id == "wizardtower" then
        showGameModes = false
        local WizardTower = require("wizardtower")
        WizardTower.init()
        GameState.current = "wizardtower"
    elseif mode.id == "alchemist" then
        showGameModes = false
        local Alchemist = require("alchemist")
        Alchemist.init()
        GameState.current = "alchemist"
    elseif mode.id == "map_editor" then
        showGameModes = false
        local MapEditor = require("map_editor")
        MapEditor.init()
        GameState.current = "map_editor"
    elseif mode.implemented or devModeActive then
        showGameModes = false
        startAIGame(mode.id)
    else
        statusText = mode.name .. " - Coming Soon!"
    end
end

-- Draw game modes menu
local function drawGameModesMenu(screenW, screenH)
    filterButtons = {}

    -- Background overlay
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Main panel (wider to fit favorites)
    local panelW, panelH = 900, 600
    local panelX = screenW/2 - panelW/2
    local panelY = screenH/2 - panelH/2

    love.graphics.setColor(0.1, 0.1, 0.14)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 15, 15)
    love.graphics.setColor(colors.accent)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 15, 15)
    love.graphics.setLineWidth(1)

    local mx, my = love.mouse.getPosition()

    -- Title
    love.graphics.setColor(colors.accent)
    love.graphics.setFont(UI.fonts.get(28))
    local title = "GAME MODES"
    love.graphics.print(title, panelX + 20, panelY + 12)

    -- Game count and wins (top right)
    local totalCount = GameModes.getTotalModes()
    love.graphics.setColor(colors.subtitle)
    love.graphics.setFont(UI.fonts.get(13))
    local progressText = string.format("Games: %d  |  Wins: %d", totalCount, PlayerData.wins or 0)
    love.graphics.print(progressText, panelX + panelW - 160, panelY + 18)

    -- === FAVORITES COLUMN (Left side) ===
    local favX = panelX + 15
    local favY = panelY + 50
    local favW = 180
    local favH = panelH - 110

    love.graphics.setColor(0.08, 0.08, 0.12)
    love.graphics.rectangle("fill", favX, favY, favW, favH, 8, 8)
    love.graphics.setColor(0.9, 0.7, 0.2, 0.6)
    love.graphics.rectangle("line", favX, favY, favW, favH, 8, 8)

    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.print("★ FAVORITES", favX + 10, favY + 8)

    -- Draw favorite modes
    local favItemH = 45
    local favStartY = favY + 35
    local favIndex = 0

    if PlayerData.favoriteModes and #PlayerData.favoriteModes > 0 then
        for _, modeId in ipairs(PlayerData.favoriteModes) do
            local mode = GameModes.getMode(modeId)
            if mode then
                local itemY = favStartY + favIndex * (favItemH + 5)
                if itemY + favItemH <= favY + favH - 5 then
                    local hover = mx >= favX + 5 and mx <= favX + favW - 5 and
                                  my >= itemY and my <= itemY + favItemH

                    local cat = GameModes.getCategory(mode.category)
                    local catColor = cat and cat.color or {0.3, 0.5, 0.7}

                    if hover then
                        love.graphics.setColor(catColor[1] * 0.7, catColor[2] * 0.7, catColor[3] * 0.7)
                    else
                        love.graphics.setColor(catColor[1] * 0.35, catColor[2] * 0.35, catColor[3] * 0.35)
                    end
                    love.graphics.rectangle("fill", favX + 5, itemY, favW - 10, favItemH, 6, 6)

                    love.graphics.setColor(colors.text)
                    love.graphics.setFont(UI.fonts.get(12))
                    love.graphics.print(mode.name, favX + 12, itemY + 8)

                    love.graphics.setColor(0.5, 0.5, 0.5)
                    love.graphics.setFont(UI.fonts.get(10))
                    local desc = mode.description:sub(1, 22)
                    if #mode.description > 22 then desc = desc .. "..." end
                    love.graphics.print(desc, favX + 12, itemY + 26)

                    filterButtons["fav_" .. mode.id] = {
                        x = favX + 5, y = itemY, w = favW - 10, h = favItemH,
                        mode = mode
                    }
                    favIndex = favIndex + 1
                end
            end
        end
    else
        love.graphics.setColor(0.4, 0.4, 0.45)
        love.graphics.setFont(UI.fonts.get(11))
        love.graphics.printf("Click ★ on any\nmode to add\nto favorites", favX + 10, favY + 50, favW - 20, "center")
    end

    -- === FILTER BAR ===
    local filterY = panelY + 50
    local filterX = favX + favW + 15

    -- Category filters
    love.graphics.setColor(colors.subtitle)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.print("Filter:", filterX, filterY + 5)

    local categories = {"all", "poker", "roguelike", "simulation", "minigame", "action", "adventure"}
    local catNames = {all = "All", poker = "Poker", roguelike = "Roguelike", simulation = "Sim", minigame = "Mini", action = "Action", adventure = "Adventure"}
    local catBtnX = filterX + 50
    local catBtnW = 55
    local catBtnH = 24

    for i, catId in ipairs(categories) do
        local btnX = catBtnX + (i - 1) * (catBtnW + 5)
        local hover = mx >= btnX and mx <= btnX + catBtnW and my >= filterY and my <= filterY + catBtnH

        if modeFilters.category == catId then
            love.graphics.setColor(colors.accent[1], colors.accent[2], colors.accent[3], 0.8)
        elseif hover then
            love.graphics.setColor(0.3, 0.3, 0.35)
        else
            love.graphics.setColor(0.2, 0.2, 0.25)
        end
        love.graphics.rectangle("fill", btnX, filterY, catBtnW, catBtnH, 4, 4)

        love.graphics.setColor(modeFilters.category == catId and colors.text or colors.subtitle)
        love.graphics.setFont(UI.fonts.get(10))
        love.graphics.printf(catNames[catId], btnX, filterY + 6, catBtnW, "center")

        filterButtons["cat_" .. catId] = {x = btnX, y = filterY, w = catBtnW, h = catBtnH, category = catId}
    end

    -- === MODES LIST ===
    local listX = favX + favW + 15
    local listY = filterY + 35
    local listW = panelW - favW - 45
    local listH = panelH - 150

    local filteredModes = getFilteredModes()
    local modeButtonH = 65
    local spacing = 70

    -- Calculate scroll
    local totalHeight = #filteredModes * spacing
    local maxScroll = math.max(0, totalHeight - listH)
    gameModeScroll = math.max(0, math.min(gameModeScroll, maxScroll))

    -- Clip area
    love.graphics.setScissor(listX, listY, listW, listH)

    -- Draw filtered modes
    for i, mode in ipairs(filteredModes) do
        local modeY = listY + (i - 1) * spacing - gameModeScroll

        if modeY + modeButtonH >= listY and modeY <= listY + listH then
            local hover = mx >= listX and mx <= listX + listW - 20 and
                          my >= modeY and my <= modeY + modeButtonH and
                          my >= listY and my <= listY + listH

            -- Button background
            local cat = GameModes.getCategory(mode.category)
            local catColor = cat and cat.color or {0.3, 0.5, 0.7}

            if hover then
                love.graphics.setColor(catColor[1] * 0.7, catColor[2] * 0.7, catColor[3] * 0.7)
            else
                love.graphics.setColor(catColor[1] * 0.35, catColor[2] * 0.35, catColor[3] * 0.35)
            end
            love.graphics.rectangle("fill", listX, modeY, listW - 20, modeButtonH, 8, 8)

            -- Border
            love.graphics.setColor(catColor[1], catColor[2], catColor[3], 0.6)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", listX, modeY, listW - 20, modeButtonH, 8, 8)

            -- Favorite star
            local starX = listX + 10
            local starY = modeY + 8
            local isFav = isFavorite(mode.id)
            local starHover = mx >= starX and mx <= starX + 20 and my >= starY and my <= starY + 20

            if isFav then
                love.graphics.setColor(0.9, 0.7, 0.2)
            elseif starHover then
                love.graphics.setColor(0.6, 0.5, 0.3)
            else
                love.graphics.setColor(0.4, 0.4, 0.45)
            end
            love.graphics.setFont(UI.fonts.get(16))
            love.graphics.print("★", starX, starY)

            filterButtons["star_" .. mode.id] = {x = starX, y = starY, w = 20, h = 20, modeId = mode.id}

            -- Mode name
            love.graphics.setFont(UI.fonts.get(18))
            love.graphics.setColor(colors.text)
            love.graphics.print(mode.name, listX + 35, modeY + 8)

            -- Description
            love.graphics.setFont(UI.fonts.get(12))
            love.graphics.setColor(colors.subtitle)
            love.graphics.print(mode.description, listX + 35, modeY + 32)

            -- Category tag
            if cat then
                love.graphics.setFont(UI.fonts.get(10))
                love.graphics.setColor(catColor[1], catColor[2], catColor[3], 0.8)
                love.graphics.print(cat.name, listX + listW - 100, modeY + 8)
            end

            -- Status (only show coming soon / dev test for unimplemented modes)
            if not mode.implemented and not devModeActive then
                love.graphics.setColor(colors.textDim)
                love.graphics.setFont(UI.fonts.get(10))
                love.graphics.print("Coming Soon", listX + listW - 90, modeY + 48)
            elseif not mode.implemented and devModeActive then
                love.graphics.setColor(0.9, 0.6, 0.2)
                love.graphics.setFont(UI.fonts.get(10))
                love.graphics.print("DEV TEST", listX + listW - 80, modeY + 48)
            end

            -- Store button for click
            filterButtons["mode_" .. mode.id] = {
                x = listX + 30, y = modeY, w = listW - 50, h = modeButtonH,
                mode = mode
            }
        end
    end

    love.graphics.setScissor()

    -- Scroll bar
    if totalHeight > listH then
        local scrollBarH = math.max(30, (listH / totalHeight) * listH)
        local scrollBarY = listY + (gameModeScroll / maxScroll) * (listH - scrollBarH)
        love.graphics.setColor(0.3, 0.3, 0.35)
        love.graphics.rectangle("fill", listX + listW - 12, listY, 8, listH, 4, 4)
        love.graphics.setColor(colors.accent)
        love.graphics.rectangle("fill", listX + listW - 12, scrollBarY, 8, scrollBarH, 4, 4)
    end

    -- No results message
    if #filteredModes == 0 then
        love.graphics.setColor(colors.textDim)
        love.graphics.setFont(UI.fonts.get(16))
        love.graphics.printf("No modes match your filters", listX, listY + listH / 2 - 20, listW - 20, "center")
    end

    -- Back button
    local backW, backH = 100, 36
    local backX = panelX + panelW / 2 - backW / 2
    local backY = panelY + panelH - 48
    local backHover = mx >= backX and mx <= backX + backW and my >= backY and my <= backY + backH

    love.graphics.setColor(backHover and colors.buttonHover or colors.button)
    love.graphics.rectangle("fill", backX, backY, backW, backH, 6, 6)
    love.graphics.setColor(colors.text)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.printf("Back", backX, backY + 10, backW, "center")

    filterButtons["back"] = {x = backX, y = backY, w = backW, h = backH}
end

-- Draw story selection screen
local function drawStorySelection(screenW, screenH)
    -- Background
    love.graphics.setColor(0.05, 0.05, 0.1)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Title
    love.graphics.setColor(colors.accent)
    love.graphics.setFont(UI.fonts.get(48))
    local title = "STORY MODE"
    local titleW = love.graphics.getFont():getWidth(title)
    love.graphics.print(title, screenW/2 - titleW/2, 40)

    -- Subtitle
    love.graphics.setColor(colors.subtitle)
    love.graphics.setFont(UI.fonts.get(20))
    local subtitle = "Choose Your Story"
    local subtitleW = love.graphics.getFont():getWidth(subtitle)
    love.graphics.print(subtitle, screenW/2 - subtitleW/2, 100)

    -- Draw story buttons
    local stories = StoryMode.getStories()
    local storyButtonW, storyButtonH = 250, 80
    local spacing = 120

    storyButtons = {}

    for i, story in ipairs(stories) do
        local storyX = screenW/2 - storyButtonW/2
        local storyY = 180 + (i-1) * spacing

        local mx, my = love.mouse.getPosition()
        local hover = mx >= storyX and mx <= storyX + storyButtonW and
                      my >= storyY and my <= storyY + storyButtonH

        -- Button background
        if hover then
            love.graphics.setColor(story.characterColor[1] * 0.8, story.characterColor[2] * 0.8, story.characterColor[3] * 0.8)
        else
            love.graphics.setColor(story.characterColor[1] * 0.4, story.characterColor[2] * 0.4, story.characterColor[3] * 0.4)
        end
        love.graphics.rectangle("fill", storyX, storyY, storyButtonW, storyButtonH, 10, 10)

        -- Button border
        love.graphics.setColor(story.characterColor)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", storyX, storyY, storyButtonW, storyButtonH, 10, 10)
        love.graphics.setLineWidth(1)

        -- Story title
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.fonts.get(20))
        local textW = love.graphics.getFont():getWidth(story.title)
        love.graphics.print(story.title, storyX + storyButtonW/2 - textW/2, storyY + 15)

        -- Character name
        love.graphics.setColor(story.characterColor)
        love.graphics.setFont(UI.fonts.get(16))
        local charW = love.graphics.getFont():getWidth("Character: " .. story.character)
        love.graphics.print("Character: " .. story.character, storyX + storyButtonW/2 - charW/2, storyY + 45)

        table.insert(storyButtons, {
            x = storyX,
            y = storyY,
            w = storyButtonW,
            h = storyButtonH,
            storyId = story.id
        })
    end

    -- Back button
    love.graphics.setColor(colors.button)
    love.graphics.rectangle("fill", 20, screenH - 60, 120, 45, 8, 8)
    love.graphics.setColor(colors.accent)
    love.graphics.rectangle("line", 20, screenH - 60, 120, 45, 8, 8)
    love.graphics.setColor(colors.text)
    love.graphics.setFont(UI.fonts.get(16))
    love.graphics.print("Back", 50, screenH - 50)
end

-- Timer for offline earnings display
local offlineEarningsTimer = 0
local OFFLINE_EARNINGS_DISPLAY_TIME = 8  -- seconds to show the notification

function Menu.update(dt)
    -- Play menu music if not already playing and not muted
    local muted = PlayerData.settings and PlayerData.settings.musicMuted
    if not muted and AudioSystem.currentTrack ~= "menu" then
        AudioSystem.playMenuMusic()
    end

    -- Clear offline earnings notification after a few seconds
    if PlayerData.lastOfflineEarnings and PlayerData.lastOfflineEarnings > 0 then
        offlineEarningsTimer = offlineEarningsTimer + dt
        if offlineEarningsTimer >= OFFLINE_EARNINGS_DISPLAY_TIME then
            PlayerData.lastOfflineEarnings = nil
            offlineEarningsTimer = 0
        end
    else
        offlineEarningsTimer = 0
    end

    if searchingForGame then
        searchTimer = searchTimer + dt

        -- Simulate finding a match after random time (2-5 seconds)
        if searchTimer > 2 + math.random() * 3 then
            searchingForGame = false
            searchTimer = 0
            startAIGame("standard")
            statusText = ""
        end
    end

    -- Clear deck warning if player now has 30+ cards
    if statusText:find("30 cards") and PlayerData.currentDeck and #PlayerData.currentDeck >= 30 then
        statusText = ""
    end

    Options.update(dt)

    -- Update bug report status timer
    if bugReportStatusTimer > 0 then
        bugReportStatusTimer = bugReportStatusTimer - dt
        -- Close dialog after successful submit
        if bugReportStatusTimer <= 0 and bugReportStatus:find("opened") then
            showBugReport = false
            bugReportText = ""
            bugReportScreenshot = nil
            bugReportScreenshotPath = nil
        end
    end

    -- Update UI buttons
    for _, btn in ipairs(buttons) do
        if not (btn.devOnly and not devModeActive) then
            btn:update(dt)
        end
    end
end

-- Draw favorites quick access panel on main menu
local function drawFavoritesQuickAccess(screenW, screenH)
    -- Clear previous buttons
    mainMenuFavorites = {}

    -- Check if player has favorites
    if not PlayerData.favoriteModes or #PlayerData.favoriteModes == 0 then
        return  -- Don't show panel if no favorites
    end

    local mx, my = love.mouse.getPosition()

    -- Panel positioning (left side)
    local panelW = 160
    local panelX = 20
    local panelY = 200
    local itemH = 36
    local maxVisible = 6  -- Maximum favorites to show
    local visibleFavs = math.min(#PlayerData.favoriteModes, maxVisible)
    local panelH = 45 + visibleFavs * (itemH + 4)

    -- Panel background
    love.graphics.setColor(0.08, 0.08, 0.12, 0.92)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)

    -- Panel border
    love.graphics.setColor(0.5, 0.4, 0.3, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 10, 10)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(0.9, 0.75, 0.4)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.print("Quick Play", panelX + 10, panelY + 8)

    -- Star icon
    love.graphics.setColor(1, 0.85, 0.2)
    love.graphics.print("★", panelX + panelW - 25, panelY + 8)

    -- Draw favorite modes
    local startY = panelY + 35
    for i, modeId in ipairs(PlayerData.favoriteModes) do
        if i > maxVisible then break end

        local mode = GameModes.getMode(modeId)
        if mode then
            local itemY = startY + (i - 1) * (itemH + 4)
            local isHover = mx >= panelX + 5 and mx <= panelX + panelW - 5 and
                            my >= itemY and my <= itemY + itemH

            -- Button background
            if isHover then
                love.graphics.setColor(0.3, 0.35, 0.45, 0.9)
            else
                love.graphics.setColor(0.15, 0.17, 0.22, 0.8)
            end
            love.graphics.rectangle("fill", panelX + 5, itemY, panelW - 10, itemH, 6, 6)

            -- Button border on hover
            if isHover then
                love.graphics.setColor(0.6, 0.5, 0.3)
                love.graphics.rectangle("line", panelX + 5, itemY, panelW - 10, itemH, 6, 6)
            end

            -- Category color indicator
            local category = GameModes.getCategory(mode.category)
            if category then
                love.graphics.setColor(category.color[1], category.color[2], category.color[3], 0.8)
                love.graphics.rectangle("fill", panelX + 8, itemY + 4, 3, itemH - 8, 2, 2)
            end

            -- Mode name
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(UI.fonts.get(12))
            love.graphics.print(mode.name, panelX + 16, itemY + 10)

            -- Store button for click detection
            mainMenuFavorites["fav_" .. i] = {
                x = panelX + 5,
                y = itemY,
                w = panelW - 10,
                h = itemH,
                mode = mode
            }
        end
    end

    -- "More" hint if there are more favorites
    if #PlayerData.favoriteModes > maxVisible then
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.setFont(UI.fonts.get(10))
        love.graphics.printf("+" .. (#PlayerData.favoriteModes - maxVisible) .. " more in Game Modes",
            panelX, panelY + panelH - 18, panelW, "center")
    end
end

function Menu.draw()
    local screenW, screenH = love.graphics.getDimensions()

    -- Clear tooltip state at start of frame
    UIAssets.clearTooltip()

    -- Draw story mode selection if active
    if showStoryMode then
        drawStorySelection(screenW, screenH)
        return
    end

    -- Draw background image (cover entire screen)
    if backgroundImage then
        love.graphics.setColor(1, 1, 1, 0.85)
        local imgW = backgroundImage:getWidth()
        local imgH = backgroundImage:getHeight()
        local scaleX = screenW / imgW
        local scaleY = screenH / imgH
        local scale = math.max(scaleX, scaleY)
        local x = (screenW - imgW * scale) / 2
        local y = (screenH - imgH * scale) / 2
        love.graphics.draw(backgroundImage, x, y, 0, scale, scale)

        -- Add slight dark overlay for text readability
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    end

    -- Title
    love.graphics.setColor(colors.accent)
    love.graphics.setFont(UI.fonts.get(48))
    local title = "TAVERN TIMES"
    local titleW = love.graphics.getFont():getWidth(title)
    love.graphics.print(title, screenW/2 - titleW/2, 100)

    -- Player stats with coin tooltip (wins/losses removed)
    love.graphics.setFont(UI.fonts.get(16))

    -- Draw coin icon with tooltip (centered)
    local coinSize = 22
    local coinTextW = love.graphics.getFont():getWidth(tostring(PlayerData.coins))
    local totalStatsW = coinSize + 6 + coinTextW
    local statsX = screenW/2 - totalStatsW/2

    UIAssets.drawCurrencyWithTooltip("coins", PlayerData.coins, statsX, 198, coinSize)

    -- Passive income display
    if PlayerData.passiveIncome and PlayerData.passiveIncome > 0 then
        love.graphics.setColor(0.3, 0.9, 0.4)
        love.graphics.setFont(UI.fonts.get(12))
        local passiveText = string.format("+$%.2f/s passive income", PlayerData.passiveIncome)
        local passiveW = love.graphics.getFont():getWidth(passiveText)
        love.graphics.print(passiveText, screenW/2 - passiveW/2, 218)
    end

    -- Offline earnings notification (shown once after loading)
    if PlayerData.lastOfflineEarnings and PlayerData.lastOfflineEarnings > 0 then
        love.graphics.setColor(1, 0.9, 0.3)
        love.graphics.setFont(UI.fonts.get(14))
        local offlineText = string.format("Welcome back! Earned $%d while away!", PlayerData.lastOfflineEarnings)
        local offlineW = love.graphics.getFont():getWidth(offlineText)
        love.graphics.print(offlineText, screenW/2 - offlineW/2, 235)
        -- Clear after displaying (will be cleared on next load anyway)
    end

    -- Deck status and next unlock removed for cleaner menu

    -- Equipped jokers display
    if PlayerData.equippedJokers and #PlayerData.equippedJokers > 0 then
        love.graphics.setColor(colors.subtitle)
        love.graphics.setFont(UI.fonts.get(14))
        local jokerText = string.format("Equipped Jokers: %d", #PlayerData.equippedJokers)
        local jokerW = love.graphics.getFont():getWidth(jokerText)
        love.graphics.print(jokerText, screenW/2 - jokerW/2, 280)
    end

    -- Draw UI buttons
    for _, btn in ipairs(buttons) do
        -- Skip dev-only buttons when not in dev mode
        if not (btn.devOnly and not devModeActive) then
            btn:draw()
        end
    end

    -- Status text (for matchmaking)
    if statusText ~= "" then
        love.graphics.setColor(colors.accent)
        love.graphics.setFont(UI.fonts.get(18))
        local statusW = love.graphics.getFont():getWidth(statusText)
        love.graphics.print(statusText, screenW/2 - statusW/2, screenH - 100)

        -- Animated dots
        if searchingForGame then
            local dots = string.rep(".", math.floor(searchTimer * 2) % 4)
            love.graphics.print(dots, screenW/2 + statusW/2, screenH - 100)
        end
    end

    -- Instructions
    love.graphics.setColor(colors.subtitle)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.print("Press ESC to quit", 20, screenH - 30)

    -- Draw favorites quick access panel (only when not in overlay menus)
    if not showGameModes and not Options.isOpen() and not showDevPassword and not showBugReport then
        drawFavoritesQuickAccess(screenW, screenH)
    end

    -- Draw game modes menu if open
    if showGameModes then
        drawGameModesMenu(screenW, screenH)
    end

    -- Draw options if open
    if Options.isOpen() then
        Options.draw()
    end

    -- Draw dev mode password dialog
    if showDevPassword then
        drawDevPasswordDialog(screenW, screenH)
    end

    -- Draw bug report dialog
    if showBugReport then
        drawBugReportDialog(screenW, screenH)
    end

    -- Draw currency tooltips (must be last to appear on top)
    UIAssets.drawTooltip()
end

-- Draw dev mode password dialog
drawDevPasswordDialog = function(screenW, screenH)
    local mx, my = love.mouse.getPosition()

    -- Overlay
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Dialog box
    local dialogW, dialogH = 350, 200
    local dialogX = screenW/2 - dialogW/2
    local dialogY = screenH/2 - dialogH/2

    love.graphics.setColor(0.12, 0.12, 0.18)
    love.graphics.rectangle("fill", dialogX, dialogY, dialogW, dialogH, 12, 12)
    love.graphics.setColor(0.5, 0.4, 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", dialogX, dialogY, dialogW, dialogH, 12, 12)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(0.8, 0.7, 0.9)
    love.graphics.setFont(UI.fonts.get(20))
    love.graphics.printf("Enter Dev Password", dialogX, dialogY + 20, dialogW, "center")

    -- Password input box
    local inputW, inputH = 250, 40
    local inputX = dialogX + dialogW/2 - inputW/2
    local inputY = dialogY + 70

    love.graphics.setColor(0.08, 0.08, 0.12)
    love.graphics.rectangle("fill", inputX, inputY, inputW, inputH, 6, 6)
    love.graphics.setColor(devPasswordError and {0.8, 0.3, 0.3} or {0.4, 0.4, 0.5})
    love.graphics.rectangle("line", inputX, inputY, inputW, inputH, 6, 6)

    -- Password text (hidden with asterisks)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(18))
    local displayText = string.rep("*", #devPasswordInput)
    if #displayText == 0 then
        love.graphics.setColor(0.4, 0.4, 0.5)
        displayText = "Type password..."
    end
    love.graphics.print(displayText, inputX + 15, inputY + 10)

    -- Blinking cursor
    if math.floor(love.timer.getTime() * 2) % 2 == 0 then
        love.graphics.setColor(1, 1, 1)
        local cursorX = inputX + 15 + love.graphics.getFont():getWidth(string.rep("*", #devPasswordInput))
        love.graphics.rectangle("fill", cursorX, inputY + 10, 2, 20)
    end

    -- Error message
    if devPasswordError then
        love.graphics.setColor(0.9, 0.3, 0.3)
        love.graphics.setFont(UI.fonts.get(14))
        love.graphics.printf("Incorrect password!", dialogX, inputY + 50, dialogW, "center")
    end

    -- Buttons
    local btnW, btnH = 100, 35
    local btnY = dialogY + dialogH - 55

    -- Cancel button
    local cancelX = dialogX + dialogW/2 - btnW - 15
    local cancelHover = mx >= cancelX and mx <= cancelX + btnW and my >= btnY and my <= btnY + btnH
    love.graphics.setColor(cancelHover and {0.5, 0.3, 0.3} or {0.4, 0.25, 0.25})
    love.graphics.rectangle("fill", cancelX, btnY, btnW, btnH, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.printf("Cancel", cancelX, btnY + 9, btnW, "center")

    -- Submit button
    local submitX = dialogX + dialogW/2 + 15
    local submitHover = mx >= submitX and mx <= submitX + btnW and my >= btnY and my <= btnY + btnH
    love.graphics.setColor(submitHover and {0.3, 0.5, 0.3} or {0.25, 0.4, 0.25})
    love.graphics.rectangle("fill", submitX, btnY, btnW, btnH, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Submit", submitX, btnY + 9, btnW, "center")
end

-- Submit bug report (opens email client)
submitBugReport = function()
    if #bugReportText == 0 then
        bugReportStatus = "Please enter a description!"
        bugReportStatusTimer = 2
        return false
    end

    local playerId = PlayerData.playerUID or "UNKNOWN"
    local subject = "Bug Report - " .. playerId
    local body = "Player ID: " .. playerId .. "\n\n"
    body = body .. "Description:\n" .. bugReportText .. "\n\n"
    body = body .. "Game Version: Alpha\n"
    body = body .. "Round/Mode: " .. (GameState.current or "menu") .. "\n"
    body = body .. "Wins: " .. (PlayerData.wins or 0) .. "\n"
    body = body .. "Coins: " .. (PlayerData.coins or 0) .. "\n"

    -- URL encode the body and subject
    local function urlEncode(str)
        str = string.gsub(str, "\n", "%%0A")
        str = string.gsub(str, " ", "%%20")
        str = string.gsub(str, ":", "%%3A")
        str = string.gsub(str, "/", "%%2F")
        str = string.gsub(str, "@", "%%40")
        return str
    end

    local email = "midwestmysterymeatstudios@gmail.com"
    local mailtoUrl = "mailto:" .. email .. "?subject=" .. urlEncode(subject) .. "&body=" .. urlEncode(body)

    -- Open default email client
    love.system.openURL(mailtoUrl)

    -- Also save the report to a local file for backup
    local reportFilename = "bug_report_" .. os.time() .. ".txt"
    local file = love.filesystem.newFile(reportFilename, "w")
    if file then
        file:write("Bug Report\n")
        file:write("==========\n\n")
        file:write("Player ID: " .. playerId .. "\n")
        file:write("Timestamp: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n\n")
        file:write("Description:\n" .. bugReportText .. "\n\n")
        file:close()
    end

    bugReportStatus = "Email client opened! Report saved locally."
    bugReportStatusTimer = 3
    return true
end

-- Draw bug report dialog
drawBugReportDialog = function(screenW, screenH)
    local mx, my = love.mouse.getPosition()

    -- Overlay
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Dialog box for text input
    local dialogW, dialogH = 500, 380
    local dialogX = screenW/2 - dialogW/2
    local dialogY = screenH/2 - dialogH/2

    love.graphics.setColor(0.12, 0.12, 0.18)
    love.graphics.rectangle("fill", dialogX, dialogY, dialogW, dialogH, 12, 12)
    love.graphics.setColor(0.3, 0.5, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", dialogX, dialogY, dialogW, dialogH, 12, 12)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(0.4, 0.7, 0.9)
    love.graphics.setFont(UI.fonts.get(22))
    love.graphics.printf("Bug Report", dialogX, dialogY + 15, dialogW, "center")

    -- Subtitle
    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.printf("Describe the issue you encountered", dialogX, dialogY + 45, dialogW, "center")

    -- Text input area
    local inputX = dialogX + 25
    local inputY = dialogY + 75
    local inputW = dialogW - 50
    local inputH = 180

    love.graphics.setColor(0.08, 0.08, 0.12)
    love.graphics.rectangle("fill", inputX, inputY, inputW, inputH, 8, 8)
    love.graphics.setColor(0.3, 0.4, 0.5)
    love.graphics.rectangle("line", inputX, inputY, inputW, inputH, 8, 8)

    -- Text content
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(14))
    local displayText = bugReportText
    if #displayText == 0 then
        love.graphics.setColor(0.4, 0.4, 0.5)
        displayText = "Type your bug description here..."
    end

    -- Word wrap the text
    local _, wrappedText = love.graphics.getFont():getWrap(displayText, inputW - 20)
    local lineY = inputY + 10
    for i, line in ipairs(wrappedText) do
        if lineY < inputY + inputH - 20 then
            love.graphics.print(line, inputX + 10, lineY)
            lineY = lineY + 18
        end
    end

    -- Blinking cursor (show even when empty)
    if math.floor(love.timer.getTime() * 2) % 2 == 0 then
        love.graphics.setColor(1, 1, 1)
        local lastLineWidth = 0
        local lineCount = 0
        if #bugReportText > 0 then
            local _, actualWrapped = love.graphics.getFont():getWrap(bugReportText, inputW - 20)
            lineCount = #actualWrapped
            if lineCount > 0 then
                lastLineWidth = love.graphics.getFont():getWidth(actualWrapped[lineCount])
            end
        end
        local cursorY = inputY + 10 + math.max(0, lineCount - 1) * 18
        love.graphics.rectangle("fill", inputX + 10 + lastLineWidth, cursorY, 2, 16)
    end

    -- Player ID display
    local idY = inputY + inputH + 20
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.setFont(UI.fonts.get(11))
    love.graphics.print("Your ID: " .. (PlayerData.playerUID or "UNKNOWN"), inputX, idY)

    -- Status message
    if bugReportStatusTimer > 0 then
        local statusColor = bugReportStatus:find("Please") and {0.9, 0.5, 0.3} or {0.3, 0.8, 0.4}
        love.graphics.setColor(statusColor)
        love.graphics.setFont(UI.fonts.get(13))
        love.graphics.printf(bugReportStatus, dialogX, idY + 25, dialogW, "center")
    end

    -- Buttons
    local btnW, btnH = 120, 40
    local btnY = dialogY + dialogH - 60

    -- Cancel button
    local cancelX = dialogX + dialogW/2 - btnW - 20
    local cancelHover = mx >= cancelX and mx <= cancelX + btnW and my >= btnY and my <= btnY + btnH
    love.graphics.setColor(cancelHover and {0.5, 0.3, 0.3} or {0.4, 0.25, 0.25})
    love.graphics.rectangle("fill", cancelX, btnY, btnW, btnH, 8, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(16))
    love.graphics.printf("Cancel", cancelX, btnY + 10, btnW, "center")

    -- Submit button
    local submitX = dialogX + dialogW/2 + 20
    local submitHover = mx >= submitX and mx <= submitX + btnW and my >= btnY and my <= btnY + btnH
    love.graphics.setColor(submitHover and {0.3, 0.6, 0.4} or {0.25, 0.5, 0.35})
    love.graphics.rectangle("fill", submitX, btnY, btnW, btnH, 8, 8)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Submit", submitX, btnY + 10, btnW, "center")
end

function Menu.mousepressed(x, y, button)
    if button ~= 1 then return end

    local screenW, screenH = love.graphics.getDimensions()

    -- Handle dev password dialog
    if showDevPassword then
        local dialogW, dialogH = 350, 200
        local dialogX = screenW/2 - dialogW/2
        local dialogY = screenH/2 - dialogH/2
        local btnW, btnH = 100, 35
        local btnY = dialogY + dialogH - 55

        -- Cancel button
        local cancelX = dialogX + dialogW/2 - btnW - 15
        if x >= cancelX and x <= cancelX + btnW and y >= btnY and y <= btnY + btnH then
            showDevPassword = false
            devPasswordInput = ""
            devPasswordError = false
            return
        end

        -- Submit button
        local submitX = dialogX + dialogW/2 + 15
        if x >= submitX and x <= submitX + btnW and y >= btnY and y <= btnY + btnH then
            if devPasswordInput == "Helios" then
                -- Correct password - activate dev mode
                devModeActive = true
                PlayerData.coins = 999999999
                PlayerData.wins = 999
                savePlayerData()
                showDevPassword = false
                devPasswordInput = ""
                devPasswordError = false
                statusText = "DEV MODE ACTIVATED!"
                Menu.init()  -- Refresh buttons to show new state
            else
                devPasswordError = true
                devPasswordInput = ""
            end
            return
        end
        return
    end

    -- Handle bug report dialog
    if showBugReport then
        local dialogW, dialogH = 500, 380
        local dialogX = screenW/2 - dialogW/2
        local dialogY = screenH/2 - dialogH/2
        local btnW, btnH = 120, 40
        local btnY = dialogY + dialogH - 60

        -- Cancel button
        local cancelX = dialogX + dialogW/2 - btnW - 20
        if x >= cancelX and x <= cancelX + btnW and y >= btnY and y <= btnY + btnH then
            showBugReport = false
            bugReportText = ""
            return
        end

        -- Submit button
        local submitX = dialogX + dialogW/2 + 20
        if x >= submitX and x <= submitX + btnW and y >= btnY and y <= btnY + btnH then
            if submitBugReport() then
                -- Keep dialog open briefly to show success message
                bugReportStatusTimer = 3
            end
            return
        end
        return
    end

    -- Handle options menu first
    if Options.isOpen() then
        Options.mousepressed(x, y, button)
        return
    end

    -- Handle story selection screen
    if showStoryMode then
        -- Check story button clicks
        for _, btn in ipairs(storyButtons) do
            if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                StoryMode.selectStory(btn.storyId)
                GameState.current = "storymode"
                showStoryMode = false
                return
            end
        end

        -- Check back button
        if x >= 20 and x <= 140 and y >= screenH - 60 and y <= screenH - 15 then
            showStoryMode = false
            return
        end
        return
    end

    -- Handle game modes menu
    if showGameModes then
        -- Check back button
        if filterButtons["back"] then
            local btn = filterButtons["back"]
            if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                showGameModes = false
                return
            end
        end

        -- Check category filter buttons
        for key, btn in pairs(filterButtons) do
            if key:match("^cat_") and x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                modeFilters.category = btn.category
                gameModeScroll = 0
                return
            end
        end

        -- Check star (favorite) buttons
        for key, btn in pairs(filterButtons) do
            if key:match("^star_") and x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                toggleFavorite(btn.modeId)
                return
            end
        end

        -- Check favorite mode clicks
        for key, btn in pairs(filterButtons) do
            if key:match("^fav_") and x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                local mode = btn.mode
                if mode then
                    launchGameMode(mode)
                end
                return
            end
        end

        -- Check mode clicks in main list
        for key, btn in pairs(filterButtons) do
            if key:match("^mode_") and x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                local mode = btn.mode
                if mode then
                    launchGameMode(mode)
                end
                return
            end
        end
        return
    end

    -- Check favorites quick access buttons on main menu
    for key, btn in pairs(mainMenuFavorites) do
        if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
            if btn.mode then
                launchGameMode(btn.mode)
            end
            return
        end
    end

    -- Check UI buttons
    for _, btn in ipairs(buttons) do
        -- Skip dev-only buttons when not in dev mode
        if not (btn.devOnly and not devModeActive) then
            if btn:mousepressed(x, y, button) then
                return
            end
        end
    end
end

function Menu.mousereleased(x, y, button)
    -- Forward to UI buttons
    for _, btn in ipairs(buttons) do
        if not (btn.devOnly and not devModeActive) then
            btn:mousereleased(x, y, button)
        end
    end
end

function Menu.wheelmoved(x, y)
    if showGameModes then
        gameModeScroll = gameModeScroll - y * 40

        -- Clamp scroll
        local panelH = 550
        local scrollAreaH = panelH - 140
        local spacing = 80
        local totalHeight = #GameModes.modes * spacing
        local maxScroll = math.max(0, totalHeight - scrollAreaH)
        gameModeScroll = math.max(0, math.min(gameModeScroll, maxScroll))
        return
    end

    if Options.isOpen() then
        Options.wheelmoved(x, y)
    end
end

function Menu.keypressed(key)
    -- Handle dev password dialog
    if showDevPassword then
        if key == "escape" then
            showDevPassword = false
            devPasswordInput = ""
            devPasswordError = false
            return true
        elseif key == "backspace" then
            devPasswordInput = devPasswordInput:sub(1, -2)
            devPasswordError = false
            return true
        elseif key == "return" or key == "kpenter" then
            -- Submit password
            if devPasswordInput == "Helios" then
                devModeActive = true
                PlayerData.coins = 999999999
                PlayerData.wins = 999
                savePlayerData()
                showDevPassword = false
                devPasswordInput = ""
                devPasswordError = false
                statusText = "DEV MODE ACTIVATED!"
                Menu.init()
            else
                devPasswordError = true
                devPasswordInput = ""
            end
            return true
        end
        return true
    end

    -- Handle bug report dialog
    if showBugReport then
        if key == "escape" then
            showBugReport = false
            bugReportText = ""
            bugReportScreenshot = nil
            bugReportScreenshotPath = nil
            return true
        elseif key == "backspace" then
            bugReportText = bugReportText:sub(1, -2)
            return true
        elseif key == "return" or key == "kpenter" then
            -- Add newline to bug report
            bugReportText = bugReportText .. "\n"
            return true
        end
        return true
    end

    return false
end

function Menu.textinput(text)
    -- Handle dev password input
    if showDevPassword then
        devPasswordInput = devPasswordInput .. text
        devPasswordError = false
        return true
    end

    -- Handle bug report text input
    if showBugReport then
        -- Limit text length to prevent overflow
        if #bugReportText < 1000 then
            bugReportText = bugReportText .. text
        end
        return true
    end

    return false
end

-- Start a game against AI with specific mode
function startAIGame(modeId)
    -- Purist mode doesn't require a pre-built deck
    local isPuristMode = (modeId == "purist")

    if not isPuristMode and (not PlayerData.currentDeck or #PlayerData.currentDeck < 30) then
        statusText = "Need a deck with at least 30 cards!"
        return
    end

    GameState.isAI = true
    GameState.isHost = true
    GameState.current = "game"

    local Game = require("game")
    Game.setMode(modeId)
    Game.startNewGame()
end

-- Start matchmaking
function startMatchmaking()
    if not PlayerData.currentDeck or #PlayerData.currentDeck < 30 then
        statusText = "Need a deck with at least 30 cards!"
        return
    end

    searchingForGame = true
    searchTimer = 0
    statusText = "Searching for opponent"
end

-- Host a game
function hostGame()
    if not PlayerData.currentDeck or #PlayerData.currentDeck < 30 then
        statusText = "Need a deck with at least 30 cards!"
        return
    end

    searchingForGame = true
    searchTimer = 0
    statusText = "Waiting for opponent"
end

return Menu
