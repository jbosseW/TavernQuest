-- RPG Input Handlers
-- Extracted from textrpg.lua - ALL input handler functions
-- mousepressed, wheelmoved, keypressed, textinput, getUIRegion

local M = {}

-- Upvalues set by register()
local state
local F
local TextRPG

-- Module references (set during register)
local UI, Backpack, PropertySystem
local MapEnemies, DungeonEnemies
local TacticalCombat, TacticalUI, TacticalAI
local StealthSystem, PrisonEscape
local WorldMapOverlay, AutoTravel, AutoPlay
local Cutscenes, InteractiveTutorial
local LPCLoader, LPCTilemap
local TownNPCsVisible, WorldGen, TileUtils

-- Data references
local Data  -- rpg_data module (CLASSES, RACES, UNLOCKABLE_RACES, BACKGROUNDS, etc.)

-- State references
local tacticalStateRef    -- function that returns tacticalState
local setTacticalStateRef -- function to set tacticalState (e.g. to nil)
local TACTICAL_MODE_REF   -- function that returns TACTICAL_MODE
local setTacticalModeRef  -- function to set TACTICAL_MODE
local graveyardRef        -- function that returns graveyard table
local spriteModeRef       -- table with .toggle() and .get()

function M.register(deps)
    state = deps.state
    F = deps.F
    TextRPG = deps.TextRPG
    UI = deps.UI or require("ui")
    Backpack = deps.Backpack or require("backpack")
    PropertySystem = deps.PropertySystem or require("propertysystem")
    MapEnemies = deps.MapEnemies or require("mapenemies")
    DungeonEnemies = deps.DungeonEnemies or require("dungeonenemies")
    TacticalCombat = deps.TacticalCombat
    TacticalUI = deps.TacticalUI
    TacticalAI = deps.TacticalAI
    StealthSystem = deps.StealthSystem
    PrisonEscape = deps.PrisonEscape or require("prison_escape")
    WorldMapOverlay = deps.WorldMapOverlay or require("worldmapoverlay")
    AutoTravel = deps.AutoTravel or require("auto_travel")
    AutoPlay = deps.AutoPlay or require("autoplay")
    Cutscenes = deps.Cutscenes or require("cutscenes")
    InteractiveTutorial = deps.InteractiveTutorial or require("interactivetutorial")
    LPCLoader = deps.LPCLoader or require("lpcloader")
    LPCTilemap = deps.LPCTilemap or require("lpc_tilemap")
    TownNPCsVisible = deps.TownNPCsVisible or require("townnpcsvisible")
    WorldGen = deps.WorldGen or require("worldgen")
    TileUtils = deps.TileUtils or require("tileutils")
    Data = deps.Data  -- rpg_data module
    tacticalStateRef = deps.getTacticalState
    setTacticalStateRef = deps.setTacticalState
    TACTICAL_MODE_REF = deps.getTacticalMode
    setTacticalModeRef = deps.setTacticalMode
    graveyardRef = deps.getGraveyard
    spriteModeRef = deps.spriteMode
end

-- Helper: get current tacticalState
local function getTacticalState()
    return tacticalStateRef and tacticalStateRef() or nil
end

-- Helper: set tacticalState (e.g. to nil after combat ends)
local function setTacticalState(val)
    if setTacticalStateRef then setTacticalStateRef(val) end
end

-- Helper: get current TACTICAL_MODE
local function getTacticalMode()
    return TACTICAL_MODE_REF and TACTICAL_MODE_REF() or false
end

-- Helper: set TACTICAL_MODE
local function setTacticalMode(val)
    if setTacticalModeRef then setTacticalModeRef(val) end
end

-- Helper: get graveyard
local function getGraveyard()
    return graveyardRef and graveyardRef() or {}
end

-- Helper: toggle sprite mode
local function toggleSpriteMode()
    if spriteModeRef and spriteModeRef.toggle then
        return spriteModeRef.toggle()
    end
    return false
end

-- log() is used extensively; it's stored in textrpg as both a local and F.log/TextRPG.addLog.
-- We create a local wrapper that delegates to the F table's log function.
local function log(msg, color)
    if TextRPG and TextRPG.addLog then
        TextRPG.addLog(msg, color)
    end
end

-- Helper: navigate a node-graph skill tree by spatial proximity.
-- Returns the index of the nearest node in the pressed direction.
local function navigateNodeGraph(tree, currentIdx, direction)
    if not tree or not tree.nodes or #tree.nodes == 0 then return currentIdx end
    local current = tree.nodes[currentIdx]
    if not current then return 1 end

    local bestIdx = currentIdx
    local bestDist = math.huge

    for i, node in ipairs(tree.nodes) do
        if i ~= currentIdx then
            local dx = node.x - current.x
            local dy = node.y - current.y

            local valid = false
            if direction == "up" and dy < -0.1 then
                valid = true
            elseif direction == "down" and dy > 0.1 then
                valid = true
            elseif direction == "left" and dx < -0.1 then
                valid = true
            elseif direction == "right" and dx > 0.1 then
                valid = true
            end

            if valid then
                -- Prefer nodes aligned with the direction
                local dist
                if direction == "up" or direction == "down" then
                    dist = math.abs(dy) + math.abs(dx) * 2
                else
                    dist = math.abs(dx) + math.abs(dy) * 2
                end
                if dist < bestDist then
                    bestDist = dist
                    bestIdx = i
                end
            end
        end
    end

    return bestIdx
end

-- Convenience aliases for F-table functions used heavily in input handlers.
-- These are resolved at call time through F, which is set during register().
-- Using F.xxx() directly in the code below; these comments document the dependency.
-- F.movePlayer, F.moveTownPlayer, F.moveDungeonPlayer, F.enterCurrentTownBuilding
-- F.enterDungeon, F.exitDungeon, F.enterCamp, F.breakCamp, F.toggleCampfire
-- F.cookMeal, F.canCookRecipe, F.campChat, F.campRest, F.setCampGuard
-- F.restInShelter, F.setupShelter, F.startTravelingHome, F.cancelTravelingHome
-- F.startPaidTravel, F.cancelPaidTravel, F.attemptLockpick, F.onNewDay
-- F.toggleStealthMode, F.playerAttack, F.advanceTurn (local in textrpg)
-- F.useSkill, F.useItem, F.getTQInventory, F.gainXP, F.resetGame
-- F.createPlayer, F.generateMap, F.startPrisonEscape, F.endCombat
-- F.onEnemyDefeated, F.generateQuest, F.buildDialogueOptions
-- F.addJournalEvent, F.calculateStats, F.checkDevModePassword
-- F.activateDevMode, F.attemptVampireBite, F.toggleJournal
-- F.generateMoodDialogue, F.generateWeatherDialogue, F.generatePoliticsDialogue
-- F.generateGossip, F.generateRaceOpinionDialogue, F.generateHealQuest
-- F.getSpecializationOptions, F.isInSunlight, F.isVampireProtected
-- F.isRaceUnlocked, F.getTileType, F.getDungeonTileType
-- F.getAvailableSkills, F.enterHollowEarthPortal
-- F.handleDistrictAction, F.handleGuildHallAction, F.handleUnderbellyAction
-- F.acceptQuest, F.completeQuest, F.modifyNPCRelationship
-- F.getNPCRelationship, F.getRelationshipDialogue, F.getEventDialogue
-- F.generateRaceGreeting, F.getTownBuildingAt, F.moveBuildingPlayer
-- F.lootBuildingChest, F.rankUpAscensionSkill

-- ============================================================================
-- MOUSEPRESSED
-- ============================================================================
function M.mousepressed(mx, my, button)
    -- === CHATBOT FREE TALK MOUSE INPUT ===
    if F.isFreeTalkActive and F.isFreeTalkActive() then
        F.freeTalkMousepressed(mx, my, button)
        return
    end

    local tacticalState = getTacticalState()
    local TACTICAL_MODE = getTacticalMode()

    -- DEBUG: Store that click entered this function
    state.debugClickReached = true
    state.debugLastClickAttempt = {mx = mx, my = my, button = button, time = love.timer.getTime()}

    -- Handle UI component clicks
    if state.uiComponents then
        for _, btn in ipairs(state.uiComponents.combatButtons) do
            if btn and btn.mousepressed and btn:mousepressed(mx, my, button) then
                return
            end
        end
        for _, btn in ipairs(state.uiComponents.navButtons) do
            if btn and btn.mousepressed and btn:mousepressed(mx, my, button) then
                return
            end
        end
    end

    local screenW, screenH = love.graphics.getDimensions()
    local panelW = 120
    local contentX = panelW + 25
    local contentY = 10
    local contentW = screenW - contentX - 15
    local contentH = screenH - 75

    -- === AUTO-PLAY MENU HANDLING ===
    -- Handle left-click on auto-play menu (if open)
    if button == 1 and state.autoPlay and state.autoPlay.showMenu then
        state.debugBlocker = "autoplay_menu"
        if AutoPlay.handleMenuClick(state, mx, my, button) then
            return  -- Menu handled the click
        end
    end

    -- Right-click auto-play menu removed - now accessible via UI button

    -- Allow right-click through for tactical combat (used for cancel)
    if button ~= 1 then
        if state.phase == "tactical_combat" and button == 2 then
            -- Pass through to tactical combat handler below
        else
            return
        end
    end

    -- === FULL WORLD MAP OVERLAY CLICK HANDLING ===
    if state.fullMapOpen then
        if WorldMapOverlay.handleClick(state, mx, my) then
            return
        end
    end

    -- === WORLD MAP BUTTON CLICK ===
    if state.worldMapBtnBounds and state.player then
        local bounds = state.worldMapBtnBounds
        if mx >= bounds.x and mx <= bounds.x + bounds.w and
           my >= bounds.y and my <= bounds.y + bounds.h then
            WorldMapOverlay.toggle(state)
            return
        end
    end

    -- === OVERLAY UI CLICK HANDLING ===

    -- === DEV CHEAT BUTTON CLICK === (REMOVE BEFORE RELEASE)
    if state.devCheatBounds and state.player then
        local bounds = state.devCheatBounds
        if mx >= bounds.x and mx <= bounds.x + bounds.w and
           my >= bounds.y and my <= bounds.y + bounds.h then
            -- Give max HP, tons of gold, and skill points
            state.player.hp = 9999
            state.player.maxHP = 9999
            state.player.skillPoints = (state.player.skillPoints or 0) + 9999
            PlayerData.coins = PlayerData.coins + 999999
            state.player.gold = PlayerData.coins
            F.log("DEV CHEAT: +999,999 gold, HP set to 9999, +9999 skill points!", {1, 0.8, 0.2})
            savePlayerData()
            return
        end
    end

    -- === JOURNAL TOGGLE BUTTON CLICK ===
    -- Check this FIRST, before journal window, so button works even when journal is open
    if state.journalToggleBounds and state.player then
        local bounds = state.journalToggleBounds
        if mx >= bounds.x and mx <= bounds.x + bounds.w and
           my >= bounds.y and my <= bounds.y + bounds.h then
            F.toggleJournal()
            return
        end
    end

    -- === JOURNAL WINDOW CLICK HANDLING ===
    -- Auto-close journal during combat and other action phases
    if state.player and state.player.journal and state.player.journal.isOpen then
        local phase = state.phase
        if phase == "combat" or phase == "death" or phase == "game_over" or phase == "lockpicking" then
            state.player.journal.isOpen = false
        end
    end
    -- Block clicks behind journal when open (skip during character creation)
    if state.phase ~= "class_select" and state.player and state.player.journal and state.player.journal.isOpen then
        state.debugBlocker = "journal_open"
        -- Close button
        if state.journalCloseBounds then
            local bounds = state.journalCloseBounds
            if mx >= bounds.x and mx <= bounds.x + bounds.w and
               my >= bounds.y and my <= bounds.y + bounds.h then
                F.toggleJournal()
                return
            end
        end

        -- Tab clicks
        if state.journalTabBounds then
            for tabId, bounds in pairs(state.journalTabBounds) do
                if mx >= bounds.x and mx <= bounds.x + bounds.w and
                   my >= bounds.y and my <= bounds.y + bounds.h then
                    state.player.journal.currentTab = tabId
                    return
                end
            end
        end

        -- Block clicks behind journal
        return
    end

    -- === AUTO-PLAY STATUS BOX CLICK (resume when paused) ===
    if state.autoPlayStatusBounds and state.autoPlay and state.autoPlay.enabled and state.autoPlay.isPaused then
        local bounds = state.autoPlayStatusBounds
        if mx >= bounds.x and mx <= bounds.x + bounds.w and
           my >= bounds.y and my <= bounds.y + bounds.h then
            AutoPlay.resumeAutoPlay(state)
            return
        end
    end

    -- === AUTO-PLAY TOGGLE BUTTON CLICK ===
    if state.autoPlayToggleBounds and state.player then
        local bounds = state.autoPlayToggleBounds
        if mx >= bounds.x and mx <= bounds.x + bounds.w and
           my >= bounds.y and my <= bounds.y + bounds.h then
            -- Open context menu at button position
            state.autoPlay.showMenu = not state.autoPlay.showMenu
            state.autoPlay.menuX = bounds.x + bounds.w + 10  -- Position menu to the right of button
            state.autoPlay.menuY = bounds.y
            return
        end
    end

    -- Dev mode prompt (block all other clicks)
    if state.showDevModePrompt then
        state.debugBlocker = "dev_mode_prompt"
        -- Just block clicks, keyboard handles input
        return
    end

    -- Character sheet close button and dev mode button
    if state.showCharacterSheet then
        state.debugBlocker = "character_sheet"
        local sheetW = math.min(600, screenW - 60)
        local sheetH = math.min(640, screenH - 60)
        local sheetX = screenW/2 - sheetW/2
        local sheetY = screenH/2 - sheetH/2
        local closeX, closeY, closeW, closeH = sheetX + sheetW - 35, sheetY + 10, 25, 25
        if mx >= closeX and mx <= closeX + closeW and my >= closeY and my <= closeY + closeH then
            state.showCharacterSheet = false
            return
        end
        -- Dev mode button click
        if state.devModeButton and not state.devModeEnabled then
            local btn = state.devModeButton
            if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                state.showDevModePrompt = true
                state.devModePassword = ""
                state.devModePasswordError = false
                return
            end
        end
        -- Block clicks behind character sheet
        return
    end

    -- Companion skill tree / talent overlays block clicks
    if state.companionSkillTreeIndex then
        state.debugBlocker = "companion_skill_tree"
        return
    end
    if state.companionTalentIndex then
        state.debugBlocker = "companion_talent"
        return
    end

    -- Party UI close button and click blocking
    if state.showPartyUI then
        state.debugBlocker = "party_ui"
        if state.partyUICloseBtn then
            local btn = state.partyUICloseBtn
            if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                state.showPartyUI = false
                state.partyUIScroll = 0
                return
            end
        end
        -- Block clicks behind party UI
        return
    end

    -- === FULL BACKPACK OVERLAY CLICK HANDLING ===
    -- When the backpack is open, intercept all clicks (it's a fullscreen overlay)
    if Backpack.isOpen() then
        state.debugBlocker = "backpack_open"
        Backpack.mousepressed(mx, my, button)
        return
    end

    -- Skill tree clicks (block other interactions)
    if state.showSkillTree then
        state.debugBlocker = "skill_tree"
        return
    end

    -- Talent selection clicks (block other interactions)
    if state.showTalentSelection then
        state.debugBlocker = "talent_selection"
        return
    end

    -- Ascension tree clicks (block other interactions)
    if state.showAscensionTree then
        state.debugBlocker = "ascension_tree"
        -- Close button detection
        local screenW2, screenH2 = love.graphics.getDimensions()
        local panelW2 = math.min(800, screenW2 - 40)
        local panelX = screenW2/2 - panelW2/2
        local panelY2 = screenH2/2 - (math.min(600, screenH2 - 40))/2
        local closeX, closeY, closeW, closeH = panelX + panelW2 - 35, panelY2 + 10, 25, 25
        if mx >= closeX and mx <= closeX + closeW and my >= closeY and my <= closeY + closeH then
            state.showAscensionTree = false
        end
        return
    end

    -- === STEALTH TOGGLE CLICK ===
    if state.stealthToggleBounds and state.player then
        local bounds = state.stealthToggleBounds
        if mx >= bounds.x and mx <= bounds.x + bounds.w and
           my >= bounds.y and my <= bounds.y + bounds.h then
            F.toggleStealthMode()
            return
        end
    end

    -- Character sheet button (C button on UI)
    if state.player and state.phase ~= "class_select" and state.phase ~= "death" then
        local btnW, btnH = 30, 25
        local btnX = panelW + 10
        local btnY = screenH - 65
        if mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH then
            state.showCharacterSheet = true
            return
        end
    end

    -- Party button (P button on UI)
    if state.player and state.phase ~= "class_select" and state.phase ~= "death" then
        if state.partyBtnBounds then
            local btn = state.partyBtnBounds
            if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                state.showPartyUI = not state.showPartyUI
                if not state.showPartyUI then
                    state.partyUIScroll = 0
                end
                return
            end
        end
    end

    -- Phase-specific clicks
    state.debugBlocker = "none_reached_phase_code"

    if state.phase == "class_select" then
        local cc = state.characterCreation

        -- DEBUG: Store last click for visual display
        state.debugLastClick = {mx = mx, my = my, time = love.timer.getTime()}
        state.debugBlocker = "in_class_select"

        -- STEP 1: Race Selection
        if cc.step == 1 then
            -- Left arrow
            if cc.leftArrowBounds then
                local bounds = cc.leftArrowBounds
                if mx >= bounds.x and mx <= bounds.x + bounds.w and
                   my >= bounds.y and my <= bounds.y + bounds.h then
                    -- Move to previous race
                    local allRaces = {}
                    for _, race in ipairs(Data.RACES) do table.insert(allRaces, race) end
                    for _, race in ipairs(Data.UNLOCKABLE_RACES) do
                        if F.isRaceUnlocked(race.id) then table.insert(allRaces, race) end
                    end
                    cc.raceIndex = (cc.raceIndex or 1) - 1
                    if cc.raceIndex < 1 then cc.raceIndex = #allRaces end
                    return
                end
            end

            -- Right arrow
            if cc.rightArrowBounds then
                local bounds = cc.rightArrowBounds
                if mx >= bounds.x and mx <= bounds.x + bounds.w and
                   my >= bounds.y and my <= bounds.y + bounds.h then
                    -- Move to next race
                    local allRaces = {}
                    for _, race in ipairs(Data.RACES) do table.insert(allRaces, race) end
                    for _, race in ipairs(Data.UNLOCKABLE_RACES) do
                        if F.isRaceUnlocked(race.id) then table.insert(allRaces, race) end
                    end
                    cc.raceIndex = (cc.raceIndex or 1) + 1
                    if cc.raceIndex > #allRaces then cc.raceIndex = 1 end
                    return
                end
            end

            -- Select button
            if cc.raceSelectBounds then
                local bounds = cc.raceSelectBounds
                if mx >= bounds.x and mx <= bounds.x + bounds.w and
                   my >= bounds.y and my <= bounds.y + bounds.h then
                    -- Get current race
                    local allRaces = {}
                    for _, race in ipairs(Data.RACES) do table.insert(allRaces, race) end
                    for _, race in ipairs(Data.UNLOCKABLE_RACES) do
                        if F.isRaceUnlocked(race.id) then table.insert(allRaces, race) end
                    end
                    local currentRace = allRaces[cc.raceIndex or 1]
                    if currentRace then
                        cc.selectedRace = currentRace.id
                        -- Check if race has choice stats (e.g. Human)
                        if currentRace.statMods and currentRace.statMods.choice1 then
                            cc.chosenBonusStats = {}
                            cc.step = "stat_alloc"
                        else
                            cc.step = 2
                        end
                    end
                    return
                end
            end

        -- STAT ALLOCATION step (for choice races like Human)
        elseif cc.step == "stat_alloc" then
            -- Check stat buttons
            if cc.statAllocBounds then
                for _, bounds in ipairs(cc.statAllocBounds) do
                    if mx >= bounds.x and mx <= bounds.x + bounds.w and
                       my >= bounds.y and my <= bounds.y + bounds.h then
                        local stat = bounds.stat
                        -- Toggle selection
                        local found = false
                        for j, s in ipairs(cc.chosenBonusStats) do
                            if s == stat then
                                table.remove(cc.chosenBonusStats, j)
                                found = true
                                break
                            end
                        end
                        if not found and #cc.chosenBonusStats < 2 then
                            table.insert(cc.chosenBonusStats, stat)
                        end
                        return
                    end
                end
            end
            -- Back button
            if cc.statAllocBackBounds then
                local bounds = cc.statAllocBackBounds
                if mx >= bounds.x and mx <= bounds.x + bounds.w and
                   my >= bounds.y and my <= bounds.y + bounds.h then
                    cc.chosenBonusStats = {}
                    cc.step = 1
                    return
                end
            end
            -- Confirm button
            if cc.statAllocConfirmBounds and #cc.chosenBonusStats == 2 then
                local bounds = cc.statAllocConfirmBounds
                if mx >= bounds.x and mx <= bounds.x + bounds.w and
                   my >= bounds.y and my <= bounds.y + bounds.h then
                    cc.step = 2
                    return
                end
            end

        -- STEP 2: Class Selection (Carousel)
        elseif cc.step == 2 then
            -- Left arrow
            if cc.leftArrowBoundsClass then
                local bounds = cc.leftArrowBoundsClass
                if mx >= bounds.x and mx <= bounds.x + bounds.w and
                   my >= bounds.y and my <= bounds.y + bounds.h then
                    cc.classIndex = (cc.classIndex or 1) - 1
                    if cc.classIndex < 1 then cc.classIndex = #Data.CLASSES end
                    return
                end
            end

            -- Right arrow
            if cc.rightArrowBoundsClass then
                local bounds = cc.rightArrowBoundsClass
                if mx >= bounds.x and mx <= bounds.x + bounds.w and
                   my >= bounds.y and my <= bounds.y + bounds.h then
                    cc.classIndex = (cc.classIndex or 1) + 1
                    if cc.classIndex > #Data.CLASSES then cc.classIndex = 1 end
                    return
                end
            end

            -- Back button
            if cc.backButtonBounds then
                local bounds = cc.backButtonBounds
                if mx >= bounds.x and mx <= bounds.x + bounds.w and
                   my >= bounds.y and my <= bounds.y + bounds.h then
                    cc.step = 1
                    return
                end
            end

            -- Select button
            if cc.classSelectBounds then
                local bounds = cc.classSelectBounds
                if mx >= bounds.x and mx <= bounds.x + bounds.w and
                   my >= bounds.y and my <= bounds.y + bounds.h then
                    local currentClass = Data.CLASSES[cc.classIndex or 1]
                    if currentClass then
                        cc.selectedClass = currentClass.id
                        cc.step = 3
                    end
                    return
                end
            end

        -- STEP 3: Background Selection (Carousel)
        elseif cc.step == 3 then
            -- Left arrow
            if cc.leftArrowBoundsBackground then
                local bounds = cc.leftArrowBoundsBackground
                if mx >= bounds.x and mx <= bounds.x + bounds.w and
                   my >= bounds.y and my <= bounds.y + bounds.h then
                    cc.backgroundIndex = (cc.backgroundIndex or 1) - 1
                    if cc.backgroundIndex < 1 then cc.backgroundIndex = #Data.BACKGROUNDS end
                    return
                end
            end

            -- Right arrow
            if cc.rightArrowBoundsBackground then
                local bounds = cc.rightArrowBoundsBackground
                if mx >= bounds.x and mx <= bounds.x + bounds.w and
                   my >= bounds.y and my <= bounds.y + bounds.h then
                    cc.backgroundIndex = (cc.backgroundIndex or 1) + 1
                    if cc.backgroundIndex > #Data.BACKGROUNDS then cc.backgroundIndex = 1 end
                    return
                end
            end

            -- Back button
            if cc.backgroundBackBounds then
                local bounds = cc.backgroundBackBounds
                if mx >= bounds.x and mx <= bounds.x + bounds.w and
                   my >= bounds.y and my <= bounds.y + bounds.h then
                    cc.step = 2
                    return
                end
            end

            -- Select button
            if cc.backgroundSelectBounds then
                local bounds = cc.backgroundSelectBounds
                if mx >= bounds.x and mx <= bounds.x + bounds.w and
                   my >= bounds.y and my <= bounds.y + bounds.h then
                    local currentBg = Data.BACKGROUNDS[cc.backgroundIndex or 1]
                    if currentBg then
                        cc.selectedBackground = currentBg.id
                        cc.step = 4
                    end
                    return
                end
            end

        -- STEP 4: Gender Selection
        elseif cc.step == 4 then
            local genders = {"Male", "Female"}  -- Removed "Other"
            local cardW = 220
            local cardH = 120
            local spacing = 60
            local startX = contentX + (contentW - (#genders * cardW + (#genders - 1) * spacing)) / 2
            local y = contentY + 30

            -- Check gender cards
            for i, gender in ipairs(genders) do
                local cx = startX + (i - 1) * (cardW + spacing)
                local cy = y + 120  -- Match drawing position

                if mx >= cx and mx <= cx + cardW and my >= cy and my <= cy + cardH then
                    cc.selectedGender = gender
                    return
                end
            end

            -- Back button
            local btnW, btnH = 100, 40
            local backX, backY = contentX + 20, contentY + contentH - btnH - 10
            if mx >= backX and mx <= backX + btnW and my >= backY and my <= backY + btnH then
                cc.step = 3
                return
            end

            -- Next button
            local nextX = contentX + contentW - btnW - 20
            local nextY = contentY + contentH - btnH - 10
            if mx >= nextX and mx <= nextX + btnW and my >= nextY and my <= nextY + btnH then
                cc.step = 5
                return
            end

        -- STEP 5: Portrait and Name
        elseif cc.step == 5 then
            -- Portrait cycling arrows
            local portraitSize = 120
            local portraitX = contentX + (contentW - portraitSize) / 2
            local portraitY = contentY + 150
            local arrowSize = 30
            local leftArrowX = portraitX - arrowSize - 20
            local rightArrowX = portraitX + portraitSize + 20
            local arrowY = portraitY + (portraitSize - arrowSize) / 2

            -- Left arrow
            if mx >= leftArrowX and mx <= leftArrowX + arrowSize and my >= arrowY and my <= arrowY + arrowSize then
                cc.portraitIndex = math.max(1, cc.portraitIndex - 1)
                return
            end

            -- Right arrow
            if mx >= rightArrowX and mx <= rightArrowX + arrowSize and my >= arrowY and my <= arrowY + arrowSize then
                cc.portraitIndex = cc.portraitIndex + 1
                return
            end

            -- Back button
            local btnW, btnH = 100, 40
            local backX, backY = contentX + 20, contentY + contentH - btnH - 10
            if mx >= backX and mx <= backX + btnW and my >= backY and my <= backY + btnH then
                cc.step = 4
                return
            end

            -- Next button
            local nextX = contentX + contentW - btnW - 20
            local nextY = contentY + contentH - btnH - 10
            if mx >= nextX and mx <= nextX + btnW and my >= nextY and my <= nextY + btnH then
                cc.step = 6
                return
            end

        -- STEP 6: Review and Create
        elseif cc.step == 6 then
            -- Back button
            local btnW, btnH = 120, 50
            local backX, backY = contentX + 20, contentY + contentH - btnH - 10
            if mx >= backX and mx <= backX + btnW and my >= backY and my <= backY + btnH then
                cc.step = 5
                return
            end

            -- Skip Tutorial button (centered between Back and Create)
            local skipW = 150
            local skipX = contentX + (contentW - skipW) / 2
            local skipY = contentY + contentH - btnH - 10
            if mx >= skipX and mx <= skipX + skipW and my >= skipY and my <= skipY + btnH then
                -- Create the character (same setup as CREATE)
                local playerName = state.playerNameInput or "Adventurer"
                state.player = F.createPlayer(
                    cc.selectedClass or "warrior",
                    playerName,
                    cc.selectedRace or "human",
                    cc.selectedGender or "Male",
                    cc.selectedBackground
                )
                F.generateMap(cc.selectedRace)

                -- Initialize map enemies system for new game
                MapEnemies.init(state, {
                    generateEncounter = F.generateEncounter,
                    createEnemyInstance = F.createEnemyInstance,
                    startCombat = F.startCombat,
                    getTileType = F.getTileType,
                    getEnemiesTable = function() return Data.ENEMIES end,
                })

                -- Initialize dungeon enemies system for new game
                DungeonEnemies.init(state, {
                    startCombat = F.startCombat,
                    createEnemyInstance = F.createEnemyInstance,
                    getEnemiesTable = function() return Data.ENEMIES end,
                })

                -- Initialize town visible NPCs system for new game
                TownNPCsVisible.init(state)

                -- Find selected race and class for logging
                local race, class
                for _, r in ipairs(Data.RACES) do
                    if r.id == cc.selectedRace then race = r break end
                end
                if not race then
                    for _, r in ipairs(Data.UNLOCKABLE_RACES) do
                        if r.id == cc.selectedRace then race = r break end
                    end
                end
                for _, c in ipairs(Data.CLASSES) do
                    if c.id == cc.selectedClass then class = c break end
                end

                log(playerName .. " the " .. (race and race.name or "Human") .. " " .. (class and class.name or "Warrior") .. " begins their adventure!", class and class.color or {0.9, 0.9, 0.9})

                -- Skip prison escape, go directly to world map with allies
                F.skipPrisonEscape()
                F.addJournalEvent("milestone", playerName .. " the " .. (race and race.name or "Human") .. " " .. (class and class.name or "Warrior") .. " begins their adventure!", {1, 0.9, 0.5})
                TextRPG.save()
                return
            end

            -- CREATE button
            local createX = contentX + contentW - btnW - 20
            local createY = contentY + contentH - btnH - 10
            if mx >= createX and mx <= createX + btnW and my >= createY and my <= createY + btnH then
                -- Create the character!
                local playerName = state.playerNameInput or "Adventurer"
                state.player = F.createPlayer(
                    cc.selectedClass or "warrior",
                    playerName,
                    cc.selectedRace or "human",
                    cc.selectedGender or "Male",
                    cc.selectedBackground
                )
                F.generateMap(cc.selectedRace)

                -- Initialize map enemies system for new game
                MapEnemies.init(state, {
                    generateEncounter = F.generateEncounter,
                    createEnemyInstance = F.createEnemyInstance,
                    startCombat = F.startCombat,
                    getTileType = F.getTileType,
                    getEnemiesTable = function() return Data.ENEMIES end,
                })

                -- Initialize dungeon enemies system for new game
                DungeonEnemies.init(state, {
                    startCombat = F.startCombat,
                    createEnemyInstance = F.createEnemyInstance,
                    getEnemiesTable = function() return Data.ENEMIES end,
                })

                -- Initialize town visible NPCs system for new game
                TownNPCsVisible.init(state)

                -- Find selected race and class for logging
                local race, class
                for _, r in ipairs(Data.RACES) do
                    if r.id == cc.selectedRace then race = r break end
                end
                if not race then
                    for _, r in ipairs(Data.UNLOCKABLE_RACES) do
                        if r.id == cc.selectedRace then race = r break end
                    end
                end
                for _, c in ipairs(Data.CLASSES) do
                    if c.id == cc.selectedClass then class = c break end
                end

                log(playerName .. " the " .. (race and race.name or "Human") .. " " .. (class and class.name or "Warrior") .. " begins their adventure!", class and class.color or {0.9, 0.9, 0.9})

                -- Start the Prison Escape sequence instead of going directly to town
                F.startPrisonEscape()
                log("You awaken in The Sunken Ledger...", {0.7, 0.5, 0.5})
                F.addJournalEvent("milestone", playerName .. " the " .. (race and race.name or "Human") .. " " .. (class and class.name or "Warrior") .. " begins their adventure!", {1, 0.9, 0.5})
                TextRPG.save()
                return
            end
        end

    elseif state.phase == "town" then
        -- Town navigation arrows
        local arrowSize = 40
        local arrowX = contentX + contentW - 80
        local arrowY = contentY + 80

        -- Up arrow
        if mx >= arrowX and mx <= arrowX + arrowSize and my >= arrowY and my <= arrowY + arrowSize then
            F.moveTownPlayer(0, -1)
            return
        end

        -- Down arrow
        local downY = arrowY + arrowSize * 2 + 10
        if mx >= arrowX and mx <= arrowX + arrowSize and my >= downY and my <= downY + arrowSize then
            F.moveTownPlayer(0, 1)
            return
        end

        -- Left arrow
        local leftX = arrowX - arrowSize - 5
        local leftY = arrowY + arrowSize + 5
        if mx >= leftX and mx <= leftX + arrowSize and my >= leftY and my <= leftY + arrowSize then
            F.moveTownPlayer(-1, 0)
            return
        end

        -- Right arrow
        local rightX = arrowX + arrowSize + 5
        if mx >= rightX and mx <= rightX + arrowSize and my >= leftY and my <= leftY + arrowSize then
            F.moveTownPlayer(1, 0)
            return
        end

        -- Enter button (in tooltip area)
        local mapX = contentX + 20
        local mapY = contentY + 45
        local mapW = contentW - 140
        local mapH = contentH - 100
        local tooltipW = 200
        local tooltipX = mapX + mapW/2 - tooltipW/2
        local tooltipY = mapY + mapH + 5
        local enterBtnW = 80
        local enterBtnH = 22
        local enterBtnX = tooltipX + tooltipW/2 - enterBtnW/2
        local enterBtnY = tooltipY + 70 - 28
        if mx >= enterBtnX and mx <= enterBtnX + enterBtnW and my >= enterBtnY and my <= enterBtnY + enterBtnH then
            F.enterCurrentTownBuilding()
            return
        end

        -- Bottom bar utility buttons (positioned to the right)
        local barY = contentY + contentH - 45
        local btnW = 100
        local btnH = 35
        local btnSpacing = 8
        local totalBtnW = btnW * 3 + btnSpacing * 2
        local btnStartX = contentX + contentW - totalBtnW - 20  -- Right-aligned

        -- Inventory button
        if mx >= btnStartX and mx <= btnStartX + btnW and my >= barY and my <= barY + btnH then
            state.phase = "inventory"
            return
        end

        -- Quest Log button
        local questX = btnStartX + btnW + btnSpacing
        if mx >= questX and mx <= questX + btnW and my >= barY and my <= barY + btnH then
            state.phase = "quest_log"
            return
        end

        -- Party button
        local partyX = questX + btnW + btnSpacing
        if mx >= partyX and mx <= partyX + btnW and my >= barY and my <= barY + btnH then
            state.phase = "party"
            return
        end

    elseif state.phase == "guild" then
        if not state.player then return end
        -- Handle guild companion hiring
        if state.guildButtons then
            for i, btn in ipairs(state.guildButtons) do
                if btn and mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                    if btn.canHire then
                        local companion = state.guildCompanions[i]
                        if companion and state.player.gold >= companion.hireCost then
                            -- Hire the companion
                            state.player.gold = state.player.gold - companion.hireCost
                            if not state.player.party then
                                state.player.party = {}
                            end
                            table.insert(state.player.party, companion)
                            table.remove(state.guildCompanions, i)
                            log("Hired " .. companion.name .. " the " .. companion.class.name .. "!", companion.color)
                            F.addJournalEvent("party", "Recruited " .. companion.name .. " the " .. companion.class.name, {0.4, 0.8, 0.9})
                            if state.player.journal then
                                state.player.journal.actionStats.social.partyMembers = #state.player.party
                            end
                            TextRPG.save()
                        end
                    end
                    return
                end
            end
        end

        -- Back button
        if state.guildBackButton then
            local btn = state.guildBackButton
            if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                state.phase = "town"
                return
            end
        end

    elseif state.phase == "party" then
        if not state.player then return end
        -- Handle party management
        if state.partyButtons then
            for i, btn in ipairs(state.partyButtons) do
                if btn then
                    -- Check dismiss button
                    local dismiss = btn.dismissBtn
                    if dismiss and mx >= dismiss.x and mx <= dismiss.x + dismiss.w and my >= dismiss.y and my <= dismiss.y + dismiss.h then
                        local companion = state.player.party[i]
                        if companion then
                            log("Dismissed " .. companion.name .. " from the party.", {0.8, 0.6, 0.4})
                            table.remove(state.player.party, i)
                            TextRPG.save()
                        end
                        return
                    end
                end
            end
        end

        -- Back button
        if state.partyBackButton then
            local btn = state.partyBackButton
            if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                state.phase = "town"
                return
            end
        end

    elseif state.phase == "stable" then
        if not state.player then return end
        -- Handle stable interactions
        if state.stableButtons then
            -- Tab clicks
            for _, tab in ipairs({"beasts", "carts", "current", "travel"}) do
                local btn = state.stableButtons["tab_" .. tab]
                if btn and mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                    state.stableTab = tab
                    return
                end
            end

            -- Paid Travel button clicks
            for i = 1, 20 do  -- Check up to 20 travel destinations
                local btn = state.stableButtons["travel_" .. i]
                if btn and mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                    if state.player.gold >= btn.cost then
                        -- Start paid travel to the destination
                        state.player.gold = state.player.gold - btn.cost
                        F.startPaidTravel(btn.town, btn.distance)
                        log("Boarded a carriage to " .. btn.town.name .. " for " .. btn.cost .. " gold.", {0.5, 0.7, 0.9})
                    else
                        log("Not enough gold for this journey!", {0.9, 0.3, 0.3})
                    end
                    return
                end
            end

            -- Beast purchase
            for i = 1, #Backpack.BEASTS_OF_BURDEN do
                local btn = state.stableButtons["beast_" .. i]
                if btn and mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                    if state.player.gold >= btn.price then
                        -- Check if already have a beast
                        local currentBeast = Backpack.getEquippedBeast()
                        if currentBeast then
                            log("You already have a " .. currentBeast.name .. "! Release it first.", {0.8, 0.6, 0.3})
                        else
                            state.player.gold = state.player.gold - btn.price
                            Backpack.equipBeast(btn.beastId)
                            local beastDef = Backpack.getBeastDef(btn.beastId)
                            log("Purchased a " .. beastDef.name .. "!", {0.5, 0.8, 0.5})
                            TextRPG.save()
                        end
                    else
                        log("Not enough gold!", {0.9, 0.3, 0.3})
                    end
                    return
                end
            end

            -- Cart purchase
            for i = 1, #Backpack.CARTS do
                local btn = state.stableButtons["cart_" .. i]
                if btn and mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                    if not btn.canUse then
                        log("You need a beast of burden to pull this cart!", {0.8, 0.5, 0.3})
                    elseif state.player.gold >= btn.price then
                        -- Check if already have a cart
                        local currentCart = Backpack.getEquippedCart()
                        if currentCart then
                            log("You already have a " .. currentCart.name .. "! Detach it first.", {0.8, 0.6, 0.3})
                        else
                            state.player.gold = state.player.gold - btn.price
                            Backpack.equipCart(btn.cartId)
                            local cartDef = Backpack.getCartDef(btn.cartId)
                            log("Purchased a " .. cartDef.name .. "!", {0.5, 0.8, 0.5})
                            TextRPG.save()
                        end
                    else
                        log("Not enough gold!", {0.9, 0.3, 0.3})
                    end
                    return
                end
            end

            -- Feed beast button
            local feedBtn = state.stableButtons.feed
            if feedBtn and mx >= feedBtn.x and mx <= feedBtn.x + feedBtn.w and my >= feedBtn.y and my <= feedBtn.y + feedBtn.h then
                -- Try to feed with available food
                local foods = {"premium_feed", "animal_feed", "raw_meat", "meat", "common_fish"}
                local fed = false
                for _, foodId in ipairs(foods) do
                    if Backpack.hasItem(foodId, 1) then
                        local success, amount = Backpack.feedBeast(foodId)
                        if success then
                            local itemDef = Backpack.getItemDef(foodId)
                            log("Fed your beast with " .. itemDef.name .. " (+" .. amount .. "% hunger)", {0.5, 0.8, 0.5})
                            fed = true
                            break
                        end
                    end
                end
                if not fed then
                    log("No suitable food in inventory!", {0.8, 0.5, 0.3})
                end
                return
            end

            -- Rest beast button
            local restBtn = state.stableButtons.rest
            if restBtn and mx >= restBtn.x and mx <= restBtn.x + restBtn.w and my >= restBtn.y and my <= restBtn.y + restBtn.h then
                local success, amount = Backpack.restBeast(1)
                if success then
                    log("Your beast rested for an hour (+" .. amount .. "% stamina)", {0.5, 0.7, 0.8})
                    -- Also advance time by 1 hour
                    if state.timeOfDay then
                        state.timeOfDay = (state.timeOfDay + 1) % 24
                    end
                end
                return
            end

            -- Dismiss beast button
            local dismissBtn = state.stableButtons.dismissBeast
            if dismissBtn and mx >= dismissBtn.x and mx <= dismissBtn.x + dismissBtn.w and my >= dismissBtn.y and my <= dismissBtn.y + dismissBtn.h then
                local beast = Backpack.getEquippedBeast()
                if beast then
                    log("Released your " .. beast.name .. " back into the wild.", {0.7, 0.6, 0.5})
                    Backpack.unequipBeast()
                    TextRPG.save()
                end
                return
            end

            -- Detach cart button
            local detachBtn = state.stableButtons.detachCart
            if detachBtn and mx >= detachBtn.x and mx <= detachBtn.x + detachBtn.w and my >= detachBtn.y and my <= detachBtn.y + detachBtn.h then
                local cart = Backpack.getEquippedCart()
                if cart then
                    log("Detached your " .. cart.name .. ".", {0.6, 0.6, 0.5})
                    Backpack.unequipCart()
                    TextRPG.save()
                end
                return
            end

            -- Back button
            local backBtn = state.stableButtons.back
            if backBtn and mx >= backBtn.x and mx <= backBtn.x + backBtn.w and my >= backBtn.y and my <= backBtn.y + backBtn.h then
                state.phase = "town"
                return
            end
        end

    elseif state.phase == "lockpick_prompt" then
        -- Lockpick prompt buttons
        if state.lockpickButtons then
            local attemptBtn = state.lockpickButtons.attempt
            if attemptBtn and mx >= attemptBtn.x and mx <= attemptBtn.x + attemptBtn.w and my >= attemptBtn.y and my <= attemptBtn.y + attemptBtn.h then
                -- Start lockpicking minigame
                state.lockpickState = nil  -- Reset for fresh start
                state.phase = "lockpicking"
                log("You kneel down and examine the lock...", {0.6, 0.6, 0.5})
                return
            end

            local leaveBtn = state.lockpickButtons.leave
            if leaveBtn and mx >= leaveBtn.x and mx <= leaveBtn.x + leaveBtn.w and my >= leaveBtn.y and my <= leaveBtn.y + leaveBtn.h then
                -- Return to town
                state.lockpickTarget = nil
                state.phase = "town"
                log("You decide not to risk it.", {0.6, 0.6, 0.7})
                return
            end
        end

    elseif state.phase == "lockpicking" then
        -- Handle lockpicking attempt (click to try picking)
        if state.lockpickState then
            -- Cancel button
            if state.lockpickButtons and state.lockpickButtons.cancel then
                local btn = state.lockpickButtons.cancel
                if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                    state.lockpickState = nil
                    state.lockpickTarget = nil
                    state.phase = "town"
                    log("You give up on the lock.", {0.6, 0.5, 0.5})
                    return
                end
            end

            -- Clicking anywhere else attempts to pick
            F.attemptLockpick()
            return
        end

    elseif state.phase == "jail" then
        if not state.player then return end
        -- Jail option buttons
        if state.jailButtons then
            local payBtn = state.jailButtons.payFine
            if payBtn and mx >= payBtn.x and mx <= payBtn.x + payBtn.w and my >= payBtn.y and my <= payBtn.y + payBtn.h then
                -- Pay fine and go free
                local fine = state.jailState.fine
                state.player.gold = state.player.gold - fine
                log("You paid " .. fine .. "g and were released.", {0.8, 0.8, 0.4})
                state.jailState = nil
                state.lockpickTarget = nil
                state.phase = "town"
                TextRPG.save()
                return
            end

            local serveBtn = state.jailButtons.serveTime
            if serveBtn and mx >= serveBtn.x and mx <= serveBtn.x + serveBtn.w and my >= serveBtn.y and my <= serveBtn.y + serveBtn.h then
                -- Serve time (advance game time)
                local hours = state.jailState.sentence
                state.timeOfDay = (state.timeOfDay + hours) % 24
                local daysServed = math.floor(hours / 24)
                for i = 1, daysServed do
                    state.daysPassed = state.daysPassed + 1
                    F.onNewDay(state.daysPassed)
                end
                log("You served " .. hours .. " hours in jail and were released.", {0.6, 0.6, 0.7})
                state.jailState = nil
                state.lockpickTarget = nil
                state.phase = "town"
                TextRPG.save()
                return
            end

            local escapeBtn = state.jailButtons.escape
            if escapeBtn and mx >= escapeBtn.x and mx <= escapeBtn.x + escapeBtn.w and my >= escapeBtn.y and my <= escapeBtn.y + escapeBtn.h then
                -- Attempt escape
                if math.random() < Data.JAIL_CONFIG.escapeChance then
                    log("You slipped past the guards and escaped!", {0.5, 0.9, 0.5})
                    state.jailState = nil
                    state.lockpickTarget = nil
                    state.phase = "town"
                else
                    state.jailState.sentence = state.jailState.sentence + Data.JAIL_CONFIG.escapeConsequence
                    log("Caught! Your sentence has been extended by " .. Data.JAIL_CONFIG.escapeConsequence .. " hours!", {0.9, 0.4, 0.4})
                end
                return
            end
        end

    elseif state.phase == "burglary_success" then
        -- Continue button after successful burglary
        if state.burglaryButtons and state.burglaryButtons.continue then
            local btn = state.burglaryButtons.continue
            if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                state.burglaryLoot = nil
                state.lockpickTarget = nil
                state.phase = "town"
                TextRPG.save()  -- Save to prevent burglary_success phase from persisting
                return
            end
        end

    elseif state.phase == "property_purchase" then
        -- Property purchase screen buttons
        if state.propertyButtons then
            -- Buy button
            local buyBtn = state.propertyButtons.buy
            if buyBtn and buyBtn.enabled and mx >= buyBtn.x and mx <= buyBtn.x + buyBtn.w and my >= buyBtn.y and my <= buyBtn.y + buyBtn.h then
                local building = state.propertyBuilding
                local townId = state.propertyTownId
                local propertyType = building.propertyType or "business"

                local success, message = PropertySystem.purchaseProperty(townId, building.id)

                if success then
                    log("Congratulations! You now own the " .. building.name .. "!", {0.5, 0.9, 0.5})
                    state.phase = "property_manage"
                    TextRPG.save()
                else
                    log(message or "Could not purchase property.", {0.9, 0.5, 0.5})
                end
                return
            end

            -- Cancel button
            local cancelBtn = state.propertyButtons.cancel
            if cancelBtn and mx >= cancelBtn.x and mx <= cancelBtn.x + cancelBtn.w and my >= cancelBtn.y and my <= cancelBtn.y + cancelBtn.h then
                state.propertyBuilding = nil
                state.propertyTownId = nil
                state.phase = "town"
                return
            end
        end

    elseif state.phase == "property_manage" then
        if not state.player then return end
        -- Property management screen buttons
        if state.propertyButtons then
            local building = state.propertyBuilding

            -- Enter business button
            local enterBtn = state.propertyButtons.enter
            if enterBtn and mx >= enterBtn.x and mx <= enterBtn.x + enterBtn.w and my >= enterBtn.y and my <= enterBtn.y + enterBtn.h then
                -- Enter the business (use original action)
                local action = building.id
                if action == "forge" then
                    local Forge = require("forge")
                    Forge.init(true)  -- true = owner mode
                    GameState.current = "forge"
                    log("You enter your forge...", {0.7, 0.4, 0.2})
                elseif action == "wizardtower" then
                    local WizardTower = require("wizardtower")
                    WizardTower.init(true)
                    GameState.current = "wizardtower"
                    log("You climb your wizard tower stairs...", {0.4, 0.3, 0.7})
                elseif action == "alchemist" then
                    local Alchemist = require("alchemist")
                    Alchemist.init(true)
                    GameState.current = "alchemist"
                    log("You enter your alchemist's laboratory...", {0.3, 0.6, 0.4})
                elseif action == "fishingdock" then
                    local Fishing = require("fishing")
                    Fishing.init(true)
                    GameState.current = "fishing"
                    log("You head to your fishing dock!", {0.3, 0.5, 0.7})
                elseif action == "huntinglodge" then
                    local Hunting = require("hunting")
                    Hunting.init(true)
                    GameState.current = "hunting"
                    log("You enter your hunter's lodge...", {0.5, 0.4, 0.3})
                elseif action == "market" then
                    local StockMarket = require("stockmarket")
                    StockMarket.init(true)
                    GameState.current = "stockmarket"
                    log("You enter your trading post...", {0.4, 0.5, 0.5})
                end
                return
            end

            -- Employees button
            local empBtn = state.propertyButtons.employees
            if empBtn and mx >= empBtn.x and mx <= empBtn.x + empBtn.w and my >= empBtn.y and my <= empBtn.y + empBtn.h then
                log("Employee management coming soon!", {0.7, 0.7, 0.5})
                return
            end

            -- Rest button (for homes)
            local restBtn = state.propertyButtons.rest
            if restBtn and mx >= restBtn.x and mx <= restBtn.x + restBtn.w and my >= restBtn.y and my <= restBtn.y + restBtn.h then
                state.player.hp = state.player.maxHP
                state.player.mana = state.player.maxMana
                if state.player.party then
                    for _, companion in ipairs(state.player.party) do
                        companion.hp = companion.maxHP
                    end
                end
                log("You rest in your home. Fully restored!", {0.5, 0.8, 0.5})
                return
            end

            -- Storage button
            local storageBtn = state.propertyButtons.storage
            if storageBtn and mx >= storageBtn.x and mx <= storageBtn.x + storageBtn.w and my >= storageBtn.y and my <= storageBtn.y + storageBtn.h then
                log("Property storage coming soon!", {0.7, 0.7, 0.5})
                return
            end

            -- Create settlement button
            local settlementBtn = state.propertyButtons.settlement
            if settlementBtn and mx >= settlementBtn.x and mx <= settlementBtn.x + settlementBtn.w and my >= settlementBtn.y and my <= settlementBtn.y + settlementBtn.h then
                local townId = state.propertyTownId
                local propertyKey = townId .. "_" .. building.id
                local success, message = PropertySystem.createSettlement(propertyKey, building.name .. " Settlement")
                if success then
                    log("You've established a new settlement!", {0.5, 0.9, 0.5})
                    TextRPG.save()
                else
                    log(message or "Cannot create settlement.", {0.9, 0.5, 0.5})
                end
                return
            end

            -- Sell button
            local sellBtn = state.propertyButtons.sell
            if sellBtn and mx >= sellBtn.x and mx <= sellBtn.x + sellBtn.w and my >= sellBtn.y and my <= sellBtn.y + sellBtn.h then
                local townId = state.propertyTownId
                local propertyType = building.propertyType or "business"
                local success, message = PropertySystem.sellProperty(townId, building.id)
                if success then
                    log("Property sold! " .. message, {0.8, 0.8, 0.4})
                    state.propertyBuilding = nil
                    state.propertyTownId = nil
                    state.phase = "town"
                    TextRPG.save()
                else
                    log(message or "Cannot sell property.", {0.9, 0.5, 0.5})
                end
                return
            end

            -- Back button
            local backBtn = state.propertyButtons.back
            if backBtn and mx >= backBtn.x and mx <= backBtn.x + backBtn.w and my >= backBtn.y and my <= backBtn.y + backBtn.h then
                state.propertyBuilding = nil
                state.propertyTownId = nil
                state.phase = "town"
                return
            end
        end

    elseif state.phase == "land_office" then
        if state.landOfficeButtons then
            -- Buy Permit button
            local buyBtn = state.landOfficeButtons.buyPermit
            if buyBtn and buyBtn.enabled and mx >= buyBtn.x and mx <= buyBtn.x + buyBtn.w and my >= buyBtn.y and my <= buyBtn.y + buyBtn.h then
                local success, message = PropertySystem.purchaseExpansionPermit()
                if success then
                    log(message, {0.5, 0.9, 0.5})
                    TextRPG.save()
                else
                    log(message or "Cannot purchase permit.", {0.9, 0.5, 0.5})
                end
                return
            end

            -- View Rules button
            local rulesBtn = state.landOfficeButtons.viewRules
            if rulesBtn and rulesBtn.enabled and mx >= rulesBtn.x and mx <= rulesBtn.x + rulesBtn.w and my >= rulesBtn.y and my <= rulesBtn.y + rulesBtn.h then
                state.landOfficeTab = (state.landOfficeTab == "rules") and "main" or "rules"
                return
            end

            -- Check Status button
            local statusBtn = state.landOfficeButtons.checkStatus
            if statusBtn and statusBtn.enabled and mx >= statusBtn.x and mx <= statusBtn.x + statusBtn.w and my >= statusBtn.y and my <= statusBtn.y + statusBtn.h then
                state.landOfficeTab = (state.landOfficeTab == "status") and "main" or "status"
                return
            end

            -- Back button
            local backBtn = state.landOfficeButtons.back
            if backBtn and backBtn.enabled and mx >= backBtn.x and mx <= backBtn.x + backBtn.w and my >= backBtn.y and my <= backBtn.y + backBtn.h then
                state.landOfficeTab = nil
                state.phase = "town"
                return
            end
        end

    elseif state.phase == "land_claim" then
        if state.landClaimButtons then
            local claimBtn = state.landClaimButtons.claim
            if claimBtn and claimBtn.enabled and mx >= claimBtn.x and mx <= claimBtn.x + claimBtn.w and my >= claimBtn.y and my <= claimBtn.y + claimBtn.h then
                local claimX, claimY = state.landClaimX, state.landClaimY
                -- Use expansion-aware claim that merges with adjacent settlements
                local success, message = PropertySystem.claimLandWithExpansion(claimX, claimY)
                if success then
                    log("You have claimed this land! " .. (message or ""), {0.5, 0.9, 0.5})
                    state.phase = "land_manage"
                    TextRPG.save()
                else
                    log(message or "Cannot claim this land.", {0.9, 0.5, 0.5})
                end
                return
            end
            local cancelBtn = state.landClaimButtons.cancel
            if cancelBtn and mx >= cancelBtn.x and mx <= cancelBtn.x + cancelBtn.w and my >= cancelBtn.y and my <= cancelBtn.y + cancelBtn.h then
                state.landClaimX = nil
                state.landClaimY = nil
                state.phase = "map"
                return
            end
        end

    elseif state.phase == "land_manage" then
        if state.landManageButtons and state.landClaimX and state.landClaimY then
            local claimKey = state.landClaimX .. "_" .. state.landClaimY

            -- Build Structure button
            local buildStructBtn = state.landManageButtons.buildStructure
            if buildStructBtn and buildStructBtn.enabled and mx >= buildStructBtn.x and mx <= buildStructBtn.x + buildStructBtn.w and my >= buildStructBtn.y and my <= buildStructBtn.y + buildStructBtn.h then
                local success, message = PropertySystem.startBuildStructure(claimKey, buildStructBtn.structureId)
                if success then
                    local structDef = PropertySystem.WILD_STRUCTURES[buildStructBtn.structureId]
                    log(message or "Building " .. (structDef and structDef.name or "structure") .. "!", {0.5, 0.8, 0.5})
                    TextRPG.save()
                else
                    log(message or "Cannot build.", {0.9, 0.5, 0.5})
                end
                return
            end

            -- Build Wall button
            local buildWallBtn = state.landManageButtons.buildWall
            if buildWallBtn and buildWallBtn.enabled and mx >= buildWallBtn.x and mx <= buildWallBtn.x + buildWallBtn.w and my >= buildWallBtn.y and my <= buildWallBtn.y + buildWallBtn.h then
                local success, message = PropertySystem.startBuildWall(claimKey, buildWallBtn.wallId)
                if success then
                    local wallDef = PropertySystem.WALL_STRUCTURES[buildWallBtn.wallId]
                    log(message or "Building " .. (wallDef and wallDef.name or "walls") .. "!", {0.5, 0.8, 0.5})
                    TextRPG.save()
                else
                    log(message or "Cannot build walls.", {0.9, 0.5, 0.5})
                end
                return
            end

            -- Repair button
            local repairBtn = state.landManageButtons.repair
            if repairBtn and repairBtn.enabled and mx >= repairBtn.x and mx <= repairBtn.x + repairBtn.w and my >= repairBtn.y and my <= repairBtn.y + repairBtn.h then
                local success, message = PropertySystem.repairStructure(claimKey)
                if success then
                    log(message or "Repairs complete!", {0.5, 0.8, 0.5})
                    TextRPG.save()
                else
                    log(message or "Cannot repair.", {0.9, 0.5, 0.5})
                end
                return
            end

            -- Found Settlement button
            local foundBtn = state.landManageButtons.foundSettlement
            if foundBtn and foundBtn.enabled and mx >= foundBtn.x and mx <= foundBtn.x + foundBtn.w and my >= foundBtn.y and my <= foundBtn.y + foundBtn.h then
                local success, message = PropertySystem.createSettlement(claimKey, "New Settlement")
                if success then
                    log(message or "Settlement founded!", {0.5, 0.9, 0.5})
                    TextRPG.save()
                else
                    log(message or "Cannot found settlement.", {0.9, 0.5, 0.5})
                end
                return
            end

            -- Upgrade Settlement button
            local upgradeBtn = state.landManageButtons.upgradeSettlement
            if upgradeBtn and upgradeBtn.enabled and mx >= upgradeBtn.x and mx <= upgradeBtn.x + upgradeBtn.w and my >= upgradeBtn.y and my <= upgradeBtn.y + upgradeBtn.h then
                local success, message = PropertySystem.upgradeSettlement(claimKey)
                if success then
                    log(message or "Settlement upgraded!", {0.5, 0.9, 0.5})
                    TextRPG.save()
                else
                    log(message or "Cannot upgrade settlement.", {0.9, 0.5, 0.5})
                end
                return
            end

            -- Build Improvement button
            local impBtn = state.landManageButtons.buildImprovement
            if impBtn and impBtn.enabled and mx >= impBtn.x and mx <= impBtn.x + impBtn.w and my >= impBtn.y and my <= impBtn.y + impBtn.h then
                local success, message = PropertySystem.startBuildImprovement(claimKey, impBtn.improvementId)
                if success then
                    local impDef = PropertySystem.IMPROVEMENTS[impBtn.improvementId]
                    log(message or "Building " .. (impDef and impDef.name or "improvement") .. "!", {0.5, 0.8, 0.5})
                    TextRPG.save()
                else
                    log(message or "Cannot build improvement.", {0.9, 0.5, 0.5})
                end
                return
            end

            -- Abandon button
            local abandonBtn = state.landManageButtons.abandon
            if abandonBtn and mx >= abandonBtn.x and mx <= abandonBtn.x + abandonBtn.w and my >= abandonBtn.y and my <= abandonBtn.y + abandonBtn.h then
                PropertySystem.abandonClaim(state.landClaimX, state.landClaimY)
                log("You abandoned your land claim.", {0.8, 0.7, 0.5})
                state.landClaimX = nil
                state.landClaimY = nil
                state.phase = "map"
                TextRPG.save()
                return
            end

            -- Back button
            local backBtn = state.landManageButtons.back
            if backBtn and mx >= backBtn.x and mx <= backBtn.x + backBtn.w and my >= backBtn.y and my <= backBtn.y + backBtn.h then
                state.landClaimX = nil
                state.landClaimY = nil
                state.phase = "map"
                return
            end
        end

    -- === CITY EXPANSION: Click handlers for new phases ===
    elseif state.phase == "district" then
        if state.districtButtons then
            for _, btn in pairs(state.districtButtons) do
                if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                    F.handleDistrictAction(btn.action)
                    return
                end
            end
        end

    elseif state.phase == "guild_hall" then
        if state.guildButtons then
            for _, btn in pairs(state.guildButtons) do
                if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                    F.handleGuildHallAction(btn.action)
                    return
                end
            end
        end

    elseif state.phase == "underbelly" then
        if state.underbellyButtons then
            for _, btn in pairs(state.underbellyButtons) do
                if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                    F.handleUnderbellyAction(btn.action)
                    return
                end
            end
        end

    elseif state.phase == "bounty_board" then
        -- Check bounty clicks (accept quest)
        if state.bountyButtons then
            for i, btn in pairs(state.bountyButtons) do
                if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                    local bounty = btn.bounty
                    if bounty and not bounty.accepted then
                        bounty.accepted = true
                        bounty.questType = "bounty"
                        state.player.quests = state.player.quests or {}
                        table.insert(state.player.quests, bounty)
                        -- Set as active quest for compass
                        state.activeQuestIndex = #state.player.quests
                        log("Bounty accepted: " .. (bounty.name or "Unknown"), {0.9, 0.6, 0.3})
                        log(bounty.desc or "", {0.7, 0.6, 0.5})
                        -- Remove from board
                        local town = state.world and state.world.currentTown
                        if town and town.bountyBoard then
                            for j, b in ipairs(town.bountyBoard) do
                                if b == bounty then
                                    table.remove(town.bountyBoard, j)
                                    break
                                end
                            end
                        end
                    end
                    return
                end
            end
        end
        -- Back button
        if state.bountyBackBtn then
            local btn = state.bountyBackBtn
            if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                state.phase = "town"
                return
            end
        end

    elseif state.phase == "courier_office" then
        -- Check courier clicks (accept delivery)
        if state.courierButtons then
            for i, btn in pairs(state.courierButtons) do
                if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                    local courier = btn.courier
                    if courier and not courier.accepted then
                        courier.accepted = true
                        courier.questType = "courier"
                        state.player.quests = state.player.quests or {}
                        table.insert(state.player.quests, courier)
                        state.activeQuestIndex = #state.player.quests
                        log("Delivery accepted: " .. (courier.name or "Delivery"), {0.4, 0.7, 0.8})
                        log(courier.desc or "", {0.6, 0.6, 0.7})
                        -- Remove from board
                        local town = state.world and state.world.currentTown
                        if town and town.courierBoard then
                            for j, c in ipairs(town.courierBoard) do
                                if c == courier then
                                    table.remove(town.courierBoard, j)
                                    break
                                end
                            end
                        end
                    end
                    return
                end
            end
        end
        -- Back button
        if state.courierBackBtn then
            local btn = state.courierBackBtn
            if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                state.phase = "town"
                return
            end
        end

    elseif state.phase == "map" then
        -- Use view-centered approach (matches drawMap rendering)
        local px, py = state.world.playerX, state.world.playerY
        local viewRange = 8
        local minViewX = px - viewRange
        local maxViewX = px + viewRange
        local minViewY = py - viewRange
        local maxViewY = py + viewRange
        local visibleW = maxViewX - minViewX + 1
        local visibleH = maxViewY - minViewY + 1

        local cellSize = math.min(52, math.floor((contentW - 150) / visibleW), math.floor((contentH - 120) / visibleH))
        local mapStartX = contentX + (contentW - visibleW * cellSize - 100) / 2
        local mapStartY = contentY + 88

        -- Check map tile clicks (view-centered coordinates)
        for cy = minViewY, maxViewY do
            for cx = minViewX, maxViewX do
                local screenCol = cx - minViewX
                local screenRow = cy - minViewY
                local cellX = mapStartX + screenCol * cellSize
                local cellY = mapStartY + screenRow * cellSize

                if mx >= cellX and mx < cellX + cellSize and my >= cellY and my < cellY + cellSize then
                    local dist = math.abs(cx - px) + math.abs(cy - py)
                    local tile
                    if state.world.useWorldGen then
                        tile = WorldGen.getTile(cx, cy)
                    else
                        tile = state.world.mapData[cy] and state.world.mapData[cy][cx]
                    end

                    if dist == 1 and tile and tile.explored then
                        local tileType = F.getTileType(tile.type)
                        if tileType.passable then
                            F.movePlayer(cx - px, cy - py)
                            return
                        end
                    end
                end
            end
        end

        -- Navigation arrows
        local arrowSize = 50
        local arrowX = contentX + contentW - 90
        local arrowY = contentY + 50

        -- Up
        if mx >= arrowX and mx <= arrowX + arrowSize and my >= arrowY and my <= arrowY + arrowSize then
            F.movePlayer(0, -1)
            return
        end
        -- Down
        local downY = arrowY + arrowSize * 2 + 10
        if mx >= arrowX and mx <= arrowX + arrowSize and my >= downY and my <= downY + arrowSize then
            F.movePlayer(0, 1)
            return
        end
        -- Left
        local leftX = arrowX - arrowSize - 5
        local leftY = arrowY + arrowSize + 5
        if mx >= leftX and mx <= leftX + arrowSize and my >= leftY and my <= leftY + arrowSize then
            F.movePlayer(-1, 0)
            return
        end
        -- Right
        local rightX = arrowX + arrowSize + 5
        if mx >= rightX and mx <= rightX + arrowSize and my >= leftY and my <= leftY + arrowSize then
            F.movePlayer(1, 0)
            return
        end

        -- Town button
        local currentTile
        if state.world.useWorldGen then
            currentTile = WorldGen.getTile(state.world.playerX, state.world.playerY)
        else
            currentTile = state.world.mapData[state.world.playerY] and state.world.mapData[state.world.playerY][state.world.playerX]
        end
        if currentTile and currentTile.type == "town" then
            local townBtnY = downY + arrowSize + 20
            if mx >= arrowX - 25 and mx <= arrowX + arrowSize + 25 and my >= townBtnY and my <= townBtnY + 35 then
                print("DEBUG: Enter Town clicked!")
                print("Current tile type:", currentTile.type)
                print("Town:", currentTile.town and currentTile.town.name or "nil")
                state.world.currentTown = currentTile.town
                state.phase = "town"
                log("Entering " .. (currentTile.town and currentTile.town.name or "Town"), {0.5, 0.8, 0.5})
                print("DEBUG: Phase set to 'town', currentTown set")
                return
            end
        end

        -- Enter Dungeon button click
        if currentTile and currentTile.type == "dungeon" then
            local dungeonBtnY = downY + arrowSize + 20
            if mx >= arrowX - 25 and mx <= arrowX + arrowSize + 25 and my >= dungeonBtnY and my <= dungeonBtnY + 35 then
                print("DEBUG: Enter Dungeon clicked!")
                print("Dungeon position:", state.world.playerX, state.world.playerY)
                F.enterDungeon(state.world.playerX, state.world.playerY, currentTile.isWaterDungeon)
                state.pendingDungeon = nil
                print("DEBUG: Entered dungeon")
                return
            end
        end

        -- Camp button (when not in town)
        if currentTile and currentTile.type ~= "town" then
            local weatherX = contentX + contentW - 480  -- Moved 200% left (was -160)
            local weatherY = contentY + 5
            local campBtnX = weatherX
            local campBtnY = weatherY + 405  -- Moved 200% lower (was 135)

            if mx >= campBtnX and mx <= campBtnX + 150 and my >= campBtnY and my <= campBtnY + 28 then
                if state.camping and state.camping.active then
                    -- Return to existing camp
                    state.camping.activity = "main"
                    state.phase = "camp"
                else
                    -- Set up new camp and enter camp phase
                    F.enterCamp()
                end
                return
            end

            -- Head Home button (always clickable if we have a home town)
            if state.world.homeTown then
                local homeBtnX = campBtnX
                local homeBtnY = campBtnY + 35

                if mx >= homeBtnX and mx <= homeBtnX + 150 and my >= homeBtnY and my <= homeBtnY + 28 then
                    if state.world.pathHistory and #state.world.pathHistory > 0 then
                        F.startTravelingHome()
                    else
                        log("You are already at your home town!", {0.8, 0.8, 0.5})
                    end
                    return
                end
            end

            -- Claim Land button
            if state.mapClaimBtn then
                local btn = state.mapClaimBtn
                if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                    if btn.mode == "claim" then
                        -- Open land claim phase
                        state.landClaimX = state.world.playerX
                        state.landClaimY = state.world.playerY
                        state.phase = "land_claim"
                    else
                        -- Open land management phase
                        state.landClaimX = state.world.playerX
                        state.landClaimY = state.world.playerY
                        state.phase = "land_manage"
                    end
                    return
                end
            end

            -- Chop Wood button
            if state.mapChopBtn then
                local btn = state.mapChopBtn
                if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                    local success, message, amount, deforested = PropertySystem.chopLumber(state.world.playerX, state.world.playerY)
                    if success then
                        log(message, deforested and {0.9, 0.6, 0.3} or {0.5, 0.8, 0.5})
                        TextRPG.save()
                    else
                        log(message, {0.9, 0.5, 0.5})
                    end
                    return
                end
            end
        end

    elseif state.phase == "traveling_home" then
        -- Cancel button
        local cancelX = contentX + contentW / 2 - 80
        local cancelY = contentY + contentH - 50

        if mx >= cancelX and mx <= cancelX + 160 and my >= cancelY and my <= cancelY + 35 then
            F.cancelTravelingHome()
            return
        end

    elseif state.phase == "paid_travel" then
        -- Cancel button for paid travel
        if state.paidTravelCancelBtn then
            local btn = state.paidTravelCancelBtn
            if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                F.cancelPaidTravel()
                return
            end
        end

    elseif state.phase == "dungeon" then
        -- Dungeon click handling
        if state.dungeon then
            local dungeon = state.dungeon
            local floor = dungeon.floors[dungeon.currentFloor]
            if floor then
                -- Calculate tile positions (same as drawing)
                local px, py = dungeon.playerX, dungeon.playerY
                local viewRange = 5
                local minViewX = math.max(1, px - viewRange)
                local maxViewX = math.min(floor.width, px + viewRange)
                local minViewY = math.max(1, py - viewRange)
                local maxViewY = math.min(floor.height, py + viewRange)

                -- Use fixed grid dimensions to match drawing code
                local fixedW = viewRange * 2 + 1
                local fixedH = viewRange * 2 + 1
                local gridOriginX = px - viewRange
                local gridOriginY = py - viewRange

                local cellSize = math.min(96, math.floor((contentW - 180) / fixedW), math.floor((contentH - 140) / fixedH))
                local mapStartX = contentX + (contentW - fixedW * cellSize - 100) / 2
                local mapStartY = contentY + 55

                -- Check tile clicks for movement
                for cy = minViewY, maxViewY do
                    for cx = minViewX, maxViewX do
                        local screenCol = cx - gridOriginX
                        local screenRow = cy - gridOriginY
                        local cellX = mapStartX + screenCol * cellSize
                        local cellY = mapStartY + screenRow * cellSize

                        if mx >= cellX and mx < cellX + cellSize and my >= cellY and my < cellY + cellSize then
                            local dist = math.abs(cx - px) + math.abs(cy - py)
                            local tile = floor.grid[cy] and floor.grid[cy][cx]

                            if dist == 1 and tile and tile.explored then
                                local tileType = F.getDungeonTileType(tile.type)
                                if tileType.passable then
                                    F.moveDungeonPlayer(cx - px, cy - py)
                                    return
                                end
                            end
                        end
                    end
                end
            end
        end

    elseif state.phase == "camping" then
        -- Camp menu options
        local menuX = contentX + contentW / 2 - 150
        local menuY = contentY + 80
        local optH = 45

        for i, shelter in ipairs(Data.SHELTER_TYPES) do
            if not shelter.townOnly then
                local optY = menuY + (i - 1) * (optH + 8)
                if mx >= menuX and mx <= menuX + 300 and my >= optY and my <= optY + optH then
                    local success, err = F.setupShelter(shelter.id)
                    if success then
                        state.phase = "resting"
                    else
                        log(err, {0.9, 0.5, 0.3})
                    end
                    return
                end
            end
        end

        -- Back button
        local backY = menuY + 200
        if mx >= menuX + 100 and mx <= menuX + 200 and my >= backY and my <= backY + 35 then
            state.phase = "map"
            return
        end

    elseif state.phase == "resting" then
        -- Rest duration options
        local menuX = contentX + contentW / 2 - 120
        local menuY = contentY + 120

        local restOptions = {
            {hours = 2, label = "Short Rest (2 hours)"},
            {hours = 4, label = "Rest (4 hours)"},
            {hours = 8, label = "Full Rest (8 hours)"},
        }

        for i, opt in ipairs(restOptions) do
            local optY = menuY + (i - 1) * 45
            if mx >= menuX and mx <= menuX + 240 and my >= optY and my <= optY + 38 then
                F.restInShelter(opt.hours)
                return
            end
        end

        -- Break camp button
        local breakY = menuY + 160
        if mx >= menuX and mx <= menuX + 240 and my >= breakY and my <= breakY + 38 then
            F.breakCamp()
            state.phase = "map"
            return
        end

    elseif state.phase == "camp" then
        if not state.player then return end
        -- Camp activity UI click handling
        local activity = state.camping.activity or "main"
        local party = state.player.party or {}

        -- Header area calculations
        local guardY = contentY + 65
        local contentAreaY = guardY + 40
        local contentAreaH = contentH - 150
        local barY = contentY + contentH - 45

        -- Break Camp button (always visible)
        local breakX = contentX + contentW - 140
        if mx >= breakX and mx <= breakX + 130 and my >= barY + 8 and my <= barY + 38 then
            F.breakCamp()
            state.phase = "map"
            return
        end

        if activity == "main" then
            -- Main camp menu clicks
            local btnW = 180
            local btnH = 55
            local btnSpacing = 15
            local cols = 2
            local startX = contentX + (contentW - (cols * btnW + (cols - 1) * btnSpacing)) / 2
            local startY = contentAreaY + 20

            local buttons = {"rest", "cooking", "guard", "chat"}

            for i, action in ipairs(buttons) do
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)
                local bx = startX + col * (btnW + btnSpacing)
                local by = startY + row * (btnH + btnSpacing)

                if mx >= bx and mx <= bx + btnW and my >= by and my <= by + btnH then
                    state.camping.activity = action
                    return
                end
            end

            -- Toggle campfire button
            local fireX = startX
            local fireY = startY + 2 * (btnH + btnSpacing)
            if mx >= fireX and mx <= fireX + btnW * 2 + btnSpacing and my >= fireY and my <= fireY + 40 then
                F.toggleCampfire()
                return
            end

            -- Process Lumber button
            if state.campLumberBtn then
                local btn = state.campLumberBtn
                if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                    local rawLumber = Backpack.getItemCount("raw_lumber") or 0
                    if rawLumber >= 2 then
                        local success, message = PropertySystem.processLumber(rawLumber)
                        if success then
                            log(message, {0.5, 0.8, 0.5})
                            TextRPG.save()
                        else
                            log(message, {0.9, 0.5, 0.5})
                        end
                    end
                    return
                end
            end

        elseif activity == "cooking" then
            -- Cooking submenu clicks
            if not state.camping.campfireLit then
                -- Back button when fire not lit
                local backX = contentX + contentW / 2 - 60
                local backY = contentAreaY + 100
                if mx >= backX and mx <= backX + 120 and my >= backY and my <= backY + 35 then
                    state.camping.activity = "main"
                    return
                end
            else
                -- Recipe cook buttons
                local recipeY = contentAreaY + 40
                local recipeH = 55
                for i, recipe in ipairs(Data.CAMP_FOODS) do
                    local ry = recipeY + (i - 1) * (recipeH + 8)
                    if ry + recipeH > contentAreaY + contentAreaH - 50 then break end

                    local canCook = F.canCookRecipe(recipe)
                    if canCook then
                        local cookX = contentX + contentW - 100
                        if mx >= cookX and mx <= cookX + 50 and my >= ry + 10 and my <= ry + 40 then
                            F.cookMeal(recipe.id)
                            return
                        end
                    end
                end

                -- Back button
                local backX = contentX + 20
                local backY = contentAreaY + contentAreaH - 45
                if mx >= backX and mx <= backX + 100 and my >= backY and my <= backY + 35 then
                    state.camping.activity = "main"
                    return
                end
            end

        elseif activity == "chat" then
            -- Chat topic buttons
            local topicY = contentAreaY + 40
            local topicW = 160
            local topicH = 45

            for i, topic in ipairs(Data.CAMP_CHAT_TOPICS) do
                local col = (i - 1) % 2
                local row = math.floor((i - 1) / 2)
                local tx = contentX + 30 + col * (topicW + 15)
                local ty = topicY + row * (topicH + 10)

                if mx >= tx and mx <= tx + topicW and my >= ty and my <= ty + topicH then
                    F.campChat(topic.id)
                    return
                end
            end

            -- Back button
            local backX = contentX + 20
            local backY = contentAreaY + contentAreaH - 45
            if mx >= backX and mx <= backX + 100 and my >= backY and my <= backY + 35 then
                state.camping.activity = "main"
                return
            end

        elseif activity == "rest" then
            -- Rest option buttons
            local restY = contentAreaY + 95
            local guardIsPlayer = state.camping.guard == "player"

            local restOptions = {
                {hours = 2},
                {hours = 4},
                {hours = 8},
            }

            if not guardIsPlayer then
                for i, opt in ipairs(restOptions) do
                    local ry = restY + (i - 1) * 50
                    if mx >= contentX + 60 and mx <= contentX + contentW - 80 and my >= ry and my <= ry + 42 then
                        local success, err = F.campRest(opt.hours)
                        if not success and err == "Ambushed!" then
                            -- Combat started from ambush
                            return
                        end
                        return
                    end
                end
            end

            -- Back button
            local backX = contentX + 20
            local backY = contentAreaY + contentAreaH - 45
            if mx >= backX and mx <= backX + 100 and my >= backY and my <= backY + 35 then
                state.camping.activity = "main"
                return
            end

        elseif activity == "guard" then
            -- Guard assignment clicks
            local guardY2 = contentAreaY + 60
            local guardH = 50

            -- Player option
            if mx >= contentX + 40 and mx <= contentX + contentW - 60 and my >= guardY2 and my <= guardY2 + guardH then
                if state.camping.guard == "player" then
                    F.setCampGuard(nil)  -- Remove guard
                else
                    F.setCampGuard("player")
                end
                return
            end

            -- Party member options
            for i, comp in ipairs(party) do
                local cy = guardY2 + guardH + 10 + (i - 1) * (guardH + 8)
                if comp.hp > 0 and mx >= contentX + 40 and mx <= contentX + contentW - 60 and my >= cy and my <= cy + guardH then
                    if state.camping.guard == comp.name then
                        F.setCampGuard(nil)  -- Remove guard
                    else
                        F.setCampGuard("companion", i)
                    end
                    return
                end
            end

            -- Remove guard button
            if state.camping.guard then
                local removeY = guardY2 + guardH + 10 + #party * (guardH + 8) + 15
                if mx >= contentX + 40 and mx <= contentX + contentW - 60 and my >= removeY and my <= removeY + 40 then
                    F.setCampGuard(nil)
                    return
                end
            end

            -- Back button
            local backX = contentX + 20
            local backY = contentAreaY + contentAreaH - 45
            if mx >= backX and mx <= backX + 100 and my >= backY and my <= backY + 35 then
                state.camping.activity = "main"
                return
            end
        end

    elseif state.phase == "stealth_approach" and state.stealthApproach then
        -- ================================================================
        -- STEALTH APPROACH MENU MOUSE INPUT
        -- ================================================================
        if state.stealthApproach._buttons then
            for i, btn in ipairs(state.stealthApproach._buttons) do
                if btn and mx >= btn.x and mx <= btn.x + btn.w
                    and my >= btn.y and my <= btn.y + btn.h then
                    local option = btn.option
                    if option and option.available then
                        local result = MapEnemies.executeStealthAction(option.id)
                        if result then
                            if result.message then
                                log(result.message, result.success and {0.5, 0.9, 0.5} or {0.9, 0.4, 0.3})
                            end
                            if result.enemyDefeated then
                                -- Track stealth kills/knockouts
                                if result.actionId == "stealth_kill" then
                                    state.player.stealthKills = (state.player.stealthKills or 0) + 1
                                    log("Stealth kill successful!", {0.7, 0.3, 0.3})
                                elseif result.actionId == "stealth_knockout" then
                                    state.player.stealthKnockouts = (state.player.stealthKnockouts or 0) + 1
                                    log("Target knocked out and captured.", {0.3, 0.6, 0.9})
                                end
                                -- Check for stealth perk unlocks
                                if StealthSystem and StealthSystem.checkPerkUnlocks then
                                    local newPerks = StealthSystem.checkPerkUnlocks(state.player)
                                    for _, perkName in ipairs(newPerks) do
                                        log("Stealth Perk Unlocked: " .. perkName .. "!", {0.9, 0.8, 0.2})
                                    end
                                end
                                if result.karmaChange and result.karmaChange ~= 0 then
                                    log("Karma: " .. result.karmaChange, {0.7, 0.5, 0.7})
                                end
                                -- Return to map
                                state.phase = "map"
                            elseif result.combatStarts then
                                -- Combat will be started by executeStealthAction
                                -- Phase is already set by startCombatFn
                            elseif not result.combatStarts then
                                -- Backed away or no combat
                                state.phase = "map"
                            end
                        end
                        return
                    end
                end
            end
        end
        return

    elseif state.phase == "tactical_combat" and TACTICAL_MODE and tacticalState then
        -- ================================================================
        -- TACTICAL COMBAT MOUSE INPUT
        -- ================================================================
        local active = tacticalState.activeUnit
        if active and (active.isPlayer or active.isPlayerControlled) then
            local result = TacticalUI.handleClick(tacticalState, mx, my, button, Data.SKILLS)
            if result then
                if result.type == "move" then
                    local success, path = TacticalCombat.moveUnit(tacticalState, active, result.targetX, result.targetY)
                    if success then
                        -- Phase 8: Queue smooth move animation
                        if path and #path > 1 then
                            TacticalCombat.queueMoveAnimation(tacticalState, active, path)
                        end
                        TacticalCombat.addLog(tacticalState,
                            active.name .. " moves to (" .. result.targetX .. "," .. result.targetY .. ")",
                            {0.3, 0.9, 0.4})
                        tacticalState.selectedAction = nil
                        tacticalState.showMoveRange = false
                        -- After moving, show attack range automatically
                        tacticalState.attackTiles = TacticalCombat.getAttackRange(
                            tacticalState.grid, active.x, active.y,
                            active.minAttackRange or 1, active.attackRange
                        )
                    end

                elseif result.type == "attack" then
                    local success, attackResult = TacticalCombat.performAttack(tacticalState, active, result.target)
                    if success then
                        local msg
                        if attackResult.dodged then
                            msg = active.name .. " attacks " .. result.target.name .. " but MISSES!"
                            TacticalCombat.addLog(tacticalState, msg, {0.6, 0.6, 0.7})
                        else
                            msg = active.name .. " attacks " .. result.target.name .. " for " .. attackResult.damage .. " damage!"
                            if attackResult.isCrit then msg = "CRITICAL! " .. msg end
                            if attackResult.flanked then msg = msg .. " (flanked!)" end
                            TacticalCombat.addLog(tacticalState, msg, {0.9, 0.6, 0.3})
                        end

                        if attackResult.targetDown then
                            TacticalCombat.addLog(tacticalState,
                                result.target.name .. " is defeated!", {0.9, 0.9, 0.3})
                            if result.target.isEnemy and result.target.data then
                                F.onEnemyDefeated(result.target.data)
                            end
                        end

                        tacticalState.selectedAction = nil
                        tacticalState.showAttackRange = false

                        -- Check end conditions
                        if TacticalCombat.checkAllEnemiesDefeated(tacticalState) then
                            TacticalCombat.syncToGameState(tacticalState, state.player)
                            F.endCombat(true)
                            setTacticalState(nil)
                            return
                        end

                        -- Auto end turn if both move and action used
                        if active.hasMoved and active.hasActed then
                            local nextUnit = TacticalCombat.advanceTurn(tacticalState)
                            if nextUnit then
                                TacticalCombat.addLog(tacticalState,
                                    nextUnit.name .. "'s turn!", nextUnit.color or {0.8, 0.8, 0.8})
                            end
                        end
                    end

                elseif result.type == "skill" then
                    local success, skillResult = TacticalCombat.useSkill(
                        tacticalState, active, result.skillName, result.targetX, result.targetY, Data.SKILLS)
                    if success then
                        TacticalCombat.addLog(tacticalState,
                            active.name .. " uses " .. result.skillName .. "!", {0.5, 0.5, 0.95})
                        for _, effect in ipairs(skillResult.effects or {}) do
                            if effect.type == "damage" or effect.type == "aoe_damage" then
                                TacticalCombat.addLog(tacticalState,
                                    effect.target.name .. " takes " .. effect.amount .. " damage!",
                                    {0.9, 0.4, 0.4})
                                if effect.targetDown then
                                    TacticalCombat.addLog(tacticalState,
                                        effect.target.name .. " is defeated!", {0.9, 0.9, 0.3})
                                    if effect.target.isEnemy and effect.target.data then
                                        F.onEnemyDefeated(effect.target.data)
                                    end
                                end
                            elseif effect.type == "heal" then
                                TacticalCombat.addLog(tacticalState,
                                    effect.target.name .. " heals for " .. effect.amount .. " HP!",
                                    {0.3, 0.9, 0.5})
                            end
                        end

                        tacticalState.selectedAction = nil
                        tacticalState.showAttackRange = false
                        tacticalState.showSkillMenu = false

                        -- Check end conditions
                        if TacticalCombat.checkAllEnemiesDefeated(tacticalState) then
                            TacticalCombat.syncToGameState(tacticalState, state.player)
                            F.endCombat(true)
                            setTacticalState(nil)
                            return
                        end

                        -- Auto end turn if both used
                        if active.hasMoved and active.hasActed then
                            local nextUnit = TacticalCombat.advanceTurn(tacticalState)
                            if nextUnit then
                                TacticalCombat.addLog(tacticalState,
                                    nextUnit.name .. "'s turn!", nextUnit.color or {0.8, 0.8, 0.8})
                            end
                        end
                    else
                        TacticalCombat.addLog(tacticalState,
                            "Cannot use skill: " .. tostring(skillResult), {0.8, 0.3, 0.3})
                    end

                elseif result.type == "interact_object" then
                    -- Phase 10: Interact with barrels, crates, levers, explosive barrels
                    local success, objResult = TacticalCombat.interactWithObject(
                        tacticalState, active, result.targetX, result.targetY)
                    if success then
                        tacticalState.selectedAction = nil
                        tacticalState.showAttackRange = false

                        -- Check if any units died from explosions
                        if TacticalCombat.checkAllEnemiesDefeated(tacticalState) then
                            TacticalCombat.syncToGameState(tacticalState, state.player)
                            F.endCombat(true)
                            setTacticalState(nil)
                            return
                        end
                        if TacticalCombat.checkPlayerDead(tacticalState) then
                            TacticalCombat.syncToGameState(tacticalState, state.player)
                            F.endCombat(false)
                            setTacticalState(nil)
                            return
                        end

                        -- Auto end turn if both used
                        if active.hasMoved and active.hasActed then
                            local nextUnit = TacticalCombat.advanceTurn(tacticalState)
                            if nextUnit then
                                TacticalCombat.addLog(tacticalState,
                                    nextUnit.name .. "'s turn!", nextUnit.color or {0.8, 0.8, 0.8})
                            end
                        end
                    end

                elseif result.type == "hide" then
                    -- Stealth: Attempt to hide in combat
                    if StealthSystem then
                        local success, msg = StealthSystem.attemptHide(active, tacticalState, TacticalCombat)
                        if success then
                            TacticalCombat.addLog(tacticalState, active.name .. " hides! " .. msg, {0.5, 0.5, 0.8})
                            TacticalCombat.addFloatingText(tacticalState, "HIDDEN", active.x, active.y, {0.5, 0.5, 0.8}, "status")
                        else
                            TacticalCombat.addLog(tacticalState, active.name .. " fails to hide! " .. msg, {0.9, 0.4, 0.4})
                            TacticalCombat.addFloatingText(tacticalState, "EXPOSED", active.x, active.y, {0.9, 0.4, 0.4}, "status")
                        end
                        -- Hide always costs the action
                        active.hasActed = true
                        -- Auto end turn if both used
                        if active.hasMoved and active.hasActed then
                            local nextUnit = TacticalCombat.advanceTurn(tacticalState)
                            if nextUnit then
                                TacticalCombat.addLog(tacticalState,
                                    nextUnit.name .. "'s turn!", nextUnit.color or {0.8, 0.8, 0.8})
                            end
                        end
                    end

                elseif result.type == "shadow_strike" then
                    -- Stealth: Shadow Strike (move + attack from hidden)
                    if StealthSystem and result.target then
                        local target = result.target
                        -- Check if shadow strike is valid
                        local canStrike, strikeMsg = StealthSystem.canShadowStrike(
                            active, target.x, target.y, tacticalState, TacticalCombat)
                        if canStrike then
                            -- Move adjacent to target first
                            local bestTile = nil
                            local bestDist = 999
                            local neighbors = TileUtils.DIRS4
                            for _, n in ipairs(neighbors) do
                                local nx, ny = target.x + n[1], target.y + n[2]
                                if TacticalCombat.isTilePassable(tacticalState.grid, nx, ny)
                                    and not TacticalCombat.getUnitAt(tacticalState.grid, nx, ny) then
                                    local dist = math.abs(active.x - nx) + math.abs(active.y - ny)
                                    if dist < bestDist then
                                        bestDist = dist
                                        bestTile = {x = nx, y = ny}
                                    end
                                end
                            end
                            -- Move to best tile if not already adjacent
                            local dist = math.abs(active.x - target.x) + math.abs(active.y - target.y)
                            if dist > (active.attackRange or 1) and bestTile then
                                -- Temporarily extend move range for shadow strike (+2 bonus)
                                local originalMoveRange = active.moveRange
                                active.moveRange = (active.moveRange or 3) + 2
                                TacticalCombat.moveUnit(tacticalState, active, bestTile.x, bestTile.y)
                                active.moveRange = originalMoveRange
                                TacticalCombat.addLog(tacticalState,
                                    active.name .. " shadow-steps to (" .. bestTile.x .. "," .. bestTile.y .. ")!",
                                    {0.5, 0.3, 0.7})
                            end
                            -- Perform the attack (stealth damage bonus applied via hookPerformAttack)
                            local success, attackResult = TacticalCombat.performAttack(tacticalState, active, target)
                            if success then
                                local msg = "SHADOW STRIKE! " .. active.name .. " strikes " .. target.name
                                    .. " for " .. (attackResult.damage or 0) .. " damage!"
                                if attackResult.isCrit then msg = "CRITICAL " .. msg end
                                TacticalCombat.addLog(tacticalState, msg, {0.6, 0.3, 0.8})
                                if attackResult.targetDown then
                                    TacticalCombat.addLog(tacticalState,
                                        target.name .. " is defeated!", {0.9, 0.9, 0.3})
                                    if target.isEnemy and target.data then
                                        F.onEnemyDefeated(target.data)
                                    end
                                end
                            end
                            -- Shadow strike uses both move and action
                            active.hasMoved = true
                            active.hasActed = true
                            tacticalState.selectedAction = nil
                            tacticalState.showAttackRange = false
                            -- Check end conditions
                            if TacticalCombat.checkAllEnemiesDefeated(tacticalState) then
                                TacticalCombat.syncToGameState(tacticalState, state.player)
                                F.endCombat(true)
                                setTacticalState(nil)
                                return
                            end
                            -- Auto advance turn
                            local nextUnit = TacticalCombat.advanceTurn(tacticalState)
                            if nextUnit then
                                TacticalCombat.addLog(tacticalState,
                                    nextUnit.name .. "'s turn!", nextUnit.color or {0.8, 0.8, 0.8})
                            end
                        else
                            TacticalCombat.addLog(tacticalState,
                                "Shadow Strike failed: " .. (strikeMsg or "unknown"), {0.9, 0.3, 0.3})
                        end
                    end

                elseif result.type == "flee" then
                    -- Attempt to flee from tactical combat (50% base + racial bonus)
                    local fleeChance = 0.5
                    local cBonus = state.player and state.player.characterBonuses
                    if cBonus and cBonus.fleeBonusPercent > 0 then
                        fleeChance = fleeChance + (cBonus.fleeBonusPercent / 100)
                    end
                    if math.random() < fleeChance then
                        TacticalCombat.addLog(tacticalState,
                            "You successfully flee from combat!", {0.7, 0.7, 0.3})
                        TacticalCombat.syncToGameState(tacticalState, state.player)
                        -- Handle map enemy flee (keep enemy on map with cooldown)
                        if state.world and state.world.currentMapEnemy then
                            MapEnemies.onPlayerFlee()
                        end
                        -- Handle dungeon enemy flee
                        if state.dungeon and state.dungeon.currentVisibleEnemy then
                            DungeonEnemies.onCombatEnd(false)
                        end
                        -- Handle prison guard flee (send back to cell)
                        if state.dungeon and state.dungeon.currentPrisonGuard then
                            local guard = state.dungeon.currentPrisonGuard
                            guard.inCombat = false
                            guard.alerted = false
                            if state.prisonEscape then
                                local msg2 = PrisonEscape.onGuardCaught(state.prisonEscape)
                                if msg2 then log(msg2, {0.9, 0.4, 0.4}) end
                                state.dungeon.currentFloor = state.prisonEscape.currentFloor
                                state.dungeon.playerX = state.prisonEscape.playerX
                                state.dungeon.playerY = state.prisonEscape.playerY
                                local curFloor = state.dungeon.floors[state.dungeon.currentFloor]
                                if curFloor then curFloor.visibleEnemies = nil end
                                -- Reveal tiles around new position
                                local resetFloor = state.dungeon.floors[state.dungeon.currentFloor]
                                if resetFloor then
                                    for ddy = -1, 1 do
                                        for ddx = -1, 1 do
                                            local nx, ny = state.dungeon.playerX + ddx, state.dungeon.playerY + ddy
                                            if resetFloor.grid[ny] and resetFloor.grid[ny][nx] then
                                                resetFloor.grid[ny][nx].explored = true
                                            end
                                        end
                                    end
                                end
                            end
                            state.dungeon.currentPrisonGuard = nil
                        end
                        -- Return to map/dungeon
                        if state.inDungeon then
                            state.phase = "dungeon"
                        else
                            state.phase = "map"
                        end
                        log("You escaped!", {0.7, 0.7, 0.3})
                        setTacticalState(nil)
                        return
                    else
                        TacticalCombat.addLog(tacticalState,
                            "Failed to escape! Turn lost.", {0.9, 0.3, 0.3})
                        -- Failed flee costs the rest of the turn
                        active.hasMoved = true
                        active.hasActed = true
                        local nextUnit = TacticalCombat.advanceTurn(tacticalState)
                        if nextUnit then
                            TacticalCombat.addLog(tacticalState,
                                nextUnit.name .. "'s turn!", nextUnit.color or {0.8, 0.8, 0.8})
                        end
                    end

                elseif result.type == "snuff_light" then
                    -- Stealth: Snuff an adjacent light source
                    if StealthSystem and result.source and result.lightIdx then
                        local source = result.source
                        -- Snuff the light source in stealth system
                        local snuffed, noise = StealthSystem.snuffLightSource(source.source, true)
                        if snuffed then
                            -- Mark as inactive in grid light sources
                            source.active = false
                            -- Recalculate room lighting if rooms exist
                            if tacticalState.grid.stealthRooms then
                                for _, room in ipairs(tacticalState.grid.stealthRooms) do
                                    StealthSystem.calculateRoomLightLevel(room, "day")
                                end
                                StealthSystem.applyLightingToGrid(
                                    tacticalState.grid, tacticalState.grid.stealthRooms, "day"
                                )
                            end
                            TacticalCombat.addLog(tacticalState,
                                active.name .. " extinguishes the " .. (source.name or "light") .. "!",
                                {0.7, 0.5, 0.2})
                            TacticalCombat.addFloatingText(tacticalState,
                                "SNUFFED", source.x, source.y, {0.7, 0.5, 0.2}, "status")
                            -- Noise check - enemies may hear
                            if noise > 0 and math.random() < noise then
                                TacticalCombat.addLog(tacticalState,
                                    "The noise alerts nearby enemies!", {0.9, 0.5, 0.3})
                            end
                        else
                            TacticalCombat.addLog(tacticalState,
                                "Cannot extinguish that light source.", {0.7, 0.4, 0.4})
                        end
                        active.hasActed = true
                        tacticalState.selectedAction = nil
                        tacticalState.snuffableLights = nil
                        -- Auto end turn if both used
                        if active.hasMoved and active.hasActed then
                            local nextUnit = TacticalCombat.advanceTurn(tacticalState)
                            if nextUnit then
                                TacticalCombat.addLog(tacticalState,
                                    nextUnit.name .. "'s turn!", nextUnit.color or {0.8, 0.8, 0.8})
                            end
                        end
                    end

                elseif result.type == "auto_companion" then
                    -- Toggle companion to AI control for this combat
                    if active.isPlayerControlled and active.isCompanion then
                        active.isPlayerControlled = false
                        if active.data then active.data.autoBattle = true end
                        TacticalCombat.addLog(tacticalState,
                            active.name .. " is now on AUTO.", {0.5, 0.7, 0.3})
                        -- Let AI take over immediately
                        local TacticalAI = require("tactical_combat_ai")
                        local results = TacticalAI.executeCompanionTurn(tacticalState, active)
                        if results and results.attacked and results.attackResult and results.attackResult.targetDown then
                            if results.target and results.target.isEnemy and results.target.data then
                                F.onEnemyDefeated(results.target.data)
                            end
                        end
                        -- Check combat end
                        if TacticalCombat.checkAllEnemiesDefeated(tacticalState) then
                            TacticalCombat.syncToGameState(tacticalState, state.player)
                            F.endCombat(true)
                            setTacticalState(nil)
                            return
                        end
                        local nextUnit = TacticalCombat.advanceTurn(tacticalState)
                        if nextUnit then
                            TacticalCombat.addLog(tacticalState,
                                nextUnit.name .. "'s turn!", nextUnit.color or {0.8, 0.8, 0.8})
                        end
                    end

                elseif result.type == "end_turn" then
                    local nextUnit = TacticalCombat.advanceTurn(tacticalState)
                    if nextUnit then
                        TacticalCombat.addLog(tacticalState,
                            nextUnit.name .. "'s turn!", nextUnit.color or {0.8, 0.8, 0.8})
                    end

                elseif result.type == "open_inventory" then
                    state.phase = "inventory"
                    state.combat.returnTo = "tactical_combat"
                end
            end
        end
        return

    elseif state.phase == "combat" then
        -- Auto-Party toggle button (works during any combat turn)
        if state.combat.autoPartyToggle and state.player and state.player.party and #state.player.party > 0 then
            local t = state.combat.autoPartyToggle
            if mx >= t.x and mx <= t.x + t.w and my >= t.y and my <= t.y + t.h then
                -- Check if all are auto - if so, turn all off; otherwise turn all on
                local allAuto = true
                for _, c in ipairs(state.player.party) do
                    if not c.autoBattle then allAuto = false; break end
                end
                for _, c in ipairs(state.player.party) do
                    c.autoBattle = not allAuto
                end
                return
            end
        end

        if not state.combat.isPlayerTurn and not state.combat.isCompanionTurn then
            return  -- Enemy turn, only toggle works
        end

    if state.combat.isPlayerTurn then
        if not state.player then return end
        -- Check enemy selection clicks first
        if state.combat.enemyButtons then
            for i, btn in ipairs(state.combat.enemyButtons) do
                if btn and not btn.dead and mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                    state.combat.selectedTarget = i
                    log("Targeting: " .. state.combat.enemies[i].name, {0.7, 0.9, 0.7})
                    return
                end
            end
        end

        -- Combat action buttons - must match drawCombat layout
        local combatAreaH = contentH - 80
        local enemyZoneH = combatAreaH * 0.45
        local middleY = contentY + enemyZoneH + 5
        local actY = middleY + 22
        local actions = {"attack", "skills", "items", "swap", "run"}
        local actW = 100
        local actH = 35
        local actionStartX = contentX + (contentW - 95 - #actions * (actW + 8)) / 2

        for i, action in ipairs(actions) do
            local ax = actionStartX + (i - 1) * (actW + 8)

            if mx >= ax and mx <= ax + actW and my >= actY and my <= actY + actH then
                if action == "attack" then
                    state.combat.showSkills = false
                    F.playerAttack()
                elseif action == "skills" then
                    state.combat.showSkills = not state.combat.showSkills
                elseif action == "items" then
                    state.combat.showSkills = false
                    state.phase = "inventory"
                    state.combat.returnTo = "combat"
                elseif action == "swap" then
                    -- Open weapon swap menu
                    state.combat.showSkills = false
                    state.combat.showWeaponSwap = true
                elseif action == "run" then
                    -- 50% base flee chance + racial bonus
                    local fleeChance = 0.5
                    local cBonus = state.player and state.player.characterBonuses
                    if cBonus and cBonus.fleeBonusPercent > 0 then
                        fleeChance = fleeChance + (cBonus.fleeBonusPercent / 100)
                    end
                    if math.random() < fleeChance then
                        log("You escaped!", {0.7, 0.7, 0.3})
                        -- If fleeing from a map enemy, respawn it nearby
                        if state.world and state.world.currentMapEnemy then
                            MapEnemies.onPlayerFlee()
                        end
                        -- Handle dungeon enemy flee
                        if state.dungeon and state.dungeon.currentVisibleEnemy then
                            DungeonEnemies.onCombatEnd(false)
                        end
                        -- Handle prison guard flee (send back to cell)
                        if state.dungeon and state.dungeon.currentPrisonGuard then
                            local guard = state.dungeon.currentPrisonGuard
                            guard.inCombat = false
                            guard.alerted = false
                            if state.prisonEscape then
                                local msg2 = PrisonEscape.onGuardCaught(state.prisonEscape)
                                if msg2 then log(msg2, {0.9, 0.4, 0.4}) end
                                state.dungeon.currentFloor = state.prisonEscape.currentFloor
                                state.dungeon.playerX = state.prisonEscape.playerX
                                state.dungeon.playerY = state.prisonEscape.playerY
                                local curFloor = state.dungeon.floors[state.dungeon.currentFloor]
                                if curFloor then curFloor.visibleEnemies = nil end
                                -- Reveal tiles around new position
                                local resetFloor = state.dungeon.floors[state.dungeon.currentFloor]
                                if resetFloor then
                                    for ddy = -1, 1 do
                                        for ddx = -1, 1 do
                                            local nx, ny = state.dungeon.playerX + ddx, state.dungeon.playerY + ddy
                                            if resetFloor.grid[ny] and resetFloor.grid[ny][nx] then
                                                resetFloor.grid[ny][nx].explored = true
                                            end
                                        end
                                    end
                                end
                            end
                            state.dungeon.currentPrisonGuard = nil
                        end
                        -- Return to correct phase
                        if state.inDungeon then
                            state.phase = "dungeon"
                        else
                            state.phase = "map"
                        end
                    else
                        log("Couldn't escape!", {0.9, 0.3, 0.3})
                        F.advanceTurn()
                    end
                end
                return
            end
        end

        -- Skills submenu
        if state.combat.showSkills then
            local availableSkills = F.getAvailableSkills()
            local skillY = actY + 42
            for i, skillName in ipairs(availableSkills) do
                local skill = Data.SKILLS[skillName]
                local sy = skillY + (i - 1) * 30

                if mx >= contentX + 30 and mx <= contentX + contentW - 120 and my >= sy and my <= sy + 26 then
                    if state.player.mana >= skill.manaCost then
                        F.useSkill(skillName)
                        state.combat.showSkills = false
                    end
                    return
                end
            end
        end

        -- Weapon swap submenu
        if state.combat.showWeaponSwap then
            -- Get all weapons from backpack
            local weaponItems = {}
            local allItems = Backpack.getAllItems()
            for _, item in ipairs(allItems) do
                if item.def.category == "tq_weapon" or item.def.category == "weapon" then
                    table.insert(weaponItems, item)
                end
            end

            local swapMenuX = contentX + 20
            local swapMenuY = actY - 8
            local swapMenuW = contentW - 120
            local skillY = swapMenuY + 25

            for i, item in ipairs(weaponItems) do
                local sy = skillY + (i - 1) * 32

                if mx >= swapMenuX + 8 and mx <= swapMenuX + swapMenuW - 8 and my >= sy and my <= sy + 28 then
                    local currentlyEquipped = state.player.equipment.weapon and state.player.equipment.weapon.backpackId == item.id
                    if not currentlyEquipped then
                        -- Swap weapon
                        F.useItem(item.indexInFilteredList or i)
                        log("Swapped to " .. item.def.name .. "!", {0.8, 0.7, 0.9})
                        state.combat.showWeaponSwap = false
                        -- Swapping weapon costs the turn
                        F.advanceTurn()
                    end
                    return
                end
            end
        end

    elseif state.combat.isCompanionTurn
           and state.player and state.player.manualPartyControl ~= false
           and not (state.combat.currentCompanionIndex and state.player.party
               and state.player.party[state.combat.currentCompanionIndex]
               and state.player.party[state.combat.currentCompanionIndex].autoBattle) then
        -- Manual companion turn: allow target selection and action buttons
        if not state.player then return end

        -- Check enemy selection clicks (same as player turn)
        if state.combat.enemyButtons then
            for i, btn in ipairs(state.combat.enemyButtons) do
                if btn and not btn.dead and mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                    state.combat.selectedTarget = i
                    log("Targeting: " .. state.combat.enemies[i].name, {0.7, 0.85, 1})
                    return
                end
            end
        end

        -- Companion action buttons (two hit regions to cover both UI layouts)
        -- Layout 1: combat_ui_simple style (middle zone)
        local combatAreaH = contentH - 80
        local enemyZoneH = combatAreaH * 0.45
        local middleY = contentY + enemyZoneH + 5
        local actY = middleY + 22
        local compActions = {"attack", "defend", "auto", "autoall"}
        local actW = 100
        local actH = 35
        local actionStartX = contentX + (contentW - 95 - #compActions * (actW + 8)) / 2

        for i, action in ipairs(compActions) do
            local ax = actionStartX + (i - 1) * (actW + 8)
            if mx >= ax and mx <= ax + actW and my >= actY and my <= actY + actH then
                if action == "attack" then
                    F.companionAttackTarget()
                elseif action == "defend" then
                    F.companionDefend()
                elseif action == "auto" then
                    local comp = state.player.party[state.combat.currentCompanionIndex]
                    if comp then
                        comp.autoBattle = not comp.autoBattle
                        if comp.autoBattle then F.companionTurn() end
                    end
                elseif action == "autoall" then
                    if state.player.party then
                        for _, c in ipairs(state.player.party) do
                            c.autoBattle = true
                        end
                    end
                    F.companionTurn()
                end
                return
            end
        end

        -- Layout 2: rpg_draw_world style (bottom action zone)
        local turnOrderW = F.turnOrderW or 80
        local actionZoneH = F.actionZoneH or 90
        local actionY2 = contentY + contentH - actionZoneH + 10 + 24
        local compActions2 = {"attack", "defend", "auto", "autoall"}
        local btnW2, btnH2 = 110, 45
        local btnSpacing2 = 10
        local totalBtnW2 = #compActions2 * btnW2 + (#compActions2 - 1) * btnSpacing2
        local btnStartX2 = contentX + (contentW - turnOrderW - totalBtnW2) / 2

        for i, action in ipairs(compActions2) do
            local bx = btnStartX2 + (i - 1) * (btnW2 + btnSpacing2)
            if mx >= bx and mx <= bx + btnW2 and my >= actionY2 and my <= actionY2 + btnH2 then
                if action == "attack" then
                    F.companionAttackTarget()
                elseif action == "defend" then
                    F.companionDefend()
                elseif action == "auto" then
                    local comp = state.player.party[state.combat.currentCompanionIndex]
                    if comp then
                        comp.autoBattle = not comp.autoBattle
                        if comp.autoBattle then F.companionTurn() end
                    end
                elseif action == "autoall" then
                    if state.player.party then
                        for _, c in ipairs(state.player.party) do
                            c.autoBattle = true
                        end
                    end
                    F.companionTurn()
                end
                return
            end
        end
    end -- end inner if isPlayerTurn / isCompanionTurn

    elseif state.phase == "dialogue" then
        if not state.player then return end
        local optY = contentY + 150
        for i, opt in ipairs(state.dialogue.options) do
            local oy = optY + (i - 1) * 40

            if mx >= contentX + 40 and mx <= contentX + contentW - 40 and my >= oy and my <= oy + 35 then
                local npc = state.dialogue.npc
                if opt.action == "leave" then
                    state.phase = "town"
                elseif opt.action == "ask_work" then
                    if npc.quest then
                        state.dialogue.text = "I have a task for you: " .. npc.quest.desc
                    end
                    state.dialogue.options = F.buildDialogueOptions(npc)
                elseif opt.action == "accept_quest" then
                    state.player.activeQuests = state.player.activeQuests or {}
                    table.insert(state.player.activeQuests, opt.quest)
                    opt.quest.accepted = true
                    npc.hasQuest = false
                    log("Accepted quest: " .. (opt.quest.name or "Unknown"), {0.9, 0.7, 0.2})
                    F.addJournalEvent("quest", "Accepted: " .. (opt.quest.name or "Unknown"), {0.9, 0.7, 0.2})
                    state.phase = "town"
                elseif opt.action == "ask_mood" then
                    state.dialogue.text = F.generateMoodDialogue(npc)
                    npc.dialogueState.talkedAbout.mood = true
                    state.dialogue.options = F.buildDialogueOptions(npc)
                elseif opt.action == "ask_weather" then
                    state.dialogue.text = F.generateWeatherDialogue(npc)
                    npc.dialogueState.talkedAbout.weather = true
                    state.dialogue.options = F.buildDialogueOptions(npc)
                elseif opt.action == "ask_politics" then
                    state.dialogue.text = F.generatePoliticsDialogue(npc)
                    npc.dialogueState.talkedAbout.politics = true
                    state.dialogue.options = F.buildDialogueOptions(npc)
                elseif opt.action == "ask_gossip" then
                    state.dialogue.text = F.generateGossip(npc)
                    npc.dialogueState.talkedAbout.gossip = true
                    state.dialogue.options = F.buildDialogueOptions(npc)
                elseif opt.action == "ask_location" then
                    -- Reveal location to auto-travel system
                    if AutoTravel and npc.revealsLocation then
                        AutoTravel.discoverLocation(npc.revealsLocation)
                        state.dialogue.text = string.format("Ah yes, I know of %s! It's %s. You should visit sometime.",
                            npc.revealsLocation.name,
                            npc.revealsLocation.description or "an interesting place")
                    else
                        state.dialogue.text = "I don't know of any special places around here."
                    end
                    npc.dialogueState.talkedAbout.location = true
                    state.dialogue.options = F.buildDialogueOptions(npc)
                elseif opt.action == "ask_race" then
                    state.dialogue.text = F.generateRaceOpinionDialogue(npc)
                    npc.dialogueState.talkedAbout.race = true
                    state.dialogue.options = F.buildDialogueOptions(npc)
                elseif opt.action == "ask_health" then
                    local healQuest = F.generateHealQuest(npc)
                    state.dialogue.text = healQuest.text
                    npc.dialogueState.talkedAbout.sickness = true
                    -- Add heal quest option
                    local opts = F.buildDialogueOptions(npc)
                    table.insert(opts, 1, {text = "I'll help you!", action = "accept_heal_quest", quest = healQuest.quest})
                    state.dialogue.options = opts
                elseif opt.action == "accept_heal_quest" then
                    state.player.activeQuests = state.player.activeQuests or {}
                    table.insert(state.player.activeQuests, opt.quest)
                    opt.quest.accepted = true
                    npc.dialogueState.healQuestGiven = true
                    log("Accepted quest: " .. (opt.quest.name or "Unknown"), {0.9, 0.7, 0.2})
                    F.addJournalEvent("quest", "Accepted: " .. opt.quest.name, {0.9, 0.7, 0.2})
                    state.dialogue.text = "Thank you so much! Please find me " .. opt.quest.cureItem .. " or help pay for my treatment..."
                    state.dialogue.options = F.buildDialogueOptions(npc)
                elseif opt.action == "vampire_bite" then
                    local success, message = F.attemptVampireBite(npc)
                    if success then
                        state.dialogue.text = "You sink your fangs into " .. npc.name .. "'s neck. They shudder as the dark curse takes hold..."
                        state.phase = "town"
                    else
                        if message == "Detected by witnesses" then
                            state.dialogue.text = "Guards burst in! You've been caught in the act!"
                            state.phase = "jailed"
                        else
                            state.dialogue.text = message
                            state.dialogue.options = F.buildDialogueOptions(npc)
                        end
                    end
                -- NEW QUEST SYSTEM: View quest details
                elseif opt.action == "view_quest_new" then
                    local template = opt.questInfo.template
                    state.dialogue.text = template.description .. "\n\nRewards: " .. template.rewards.gold .. " gold, " .. template.rewards.experience .. " XP"
                    local opts = F.buildDialogueOptions(npc)
                    -- Add accept button
                    table.insert(opts, 1, {text = "Accept Quest", action = "accept_quest_new", questInfo = opt.questInfo, color = {0.4, 1.0, 0.4}})
                    state.dialogue.options = opts
                -- NEW QUEST SYSTEM: Accept quest
                elseif opt.action == "accept_quest_new" then
                    F.acceptQuest(opt.questInfo.questId, npc.id, opt.questInfo.template)
                    F.modifyNPCRelationship(npc.id, 2, "quest_accept")
                    state.dialogue.text = "Good luck, adventurer!"
                    state.dialogue.options = F.buildDialogueOptions(npc)
                -- NEW QUEST SYSTEM: Complete quest
                elseif opt.action == "complete_quest_new" then
                    local success = F.completeQuest(opt.quest.questId)
                    if success then
                        state.dialogue.text = "Excellent work! Here's your reward."
                        state.phase = "town"
                    else
                        state.dialogue.text = "You haven't finished the quest yet."
                        state.dialogue.options = F.buildDialogueOptions(npc)
                    end
                -- NEW QUEST SYSTEM: View locked quest
                elseif opt.action == "view_quest_locked" then
                    state.dialogue.text = opt.questInfo.template.description .. "\n\n[Quest Locked: " .. opt.questInfo.requirementReason .. "]"
                    state.dialogue.options = F.buildDialogueOptions(npc)
                -- NEW RELATIONSHIP SYSTEM: View relationship
                elseif opt.action == "view_relationship" then
                    local rel = F.getNPCRelationship(npc.id)
                    state.dialogue.text = "Relationship Status: " .. rel.relationshipLevel .. "\nReputation: " .. rel.reputation .. "\nInteractions: " .. rel.interactions .. "\nQuests Completed: " .. rel.questsCompleted
                    state.dialogue.options = F.buildDialogueOptions(npc)
                -- CHATBOT: Free Talk mode
                elseif opt.action == "free_talk" then
                    if F.startFreeTalk then
                        F.startFreeTalk(npc)
                    end
                end
                return
            end
        end

    elseif state.phase == "npc_list" then
        if not state.player then return end
        local town = state.world.currentTown
        local npcY = contentY + 50

        for i, npc in ipairs(town.npcs) do
            local ny = npcY + (i - 1) * 55

            if mx >= contentX + 20 and mx <= contentX + contentW - 20 and my >= ny and my <= ny + 50 then
                -- Generate quest if needed
                if npc.hasQuest and not npc.quest then
                    npc.quest = F.generateQuest(npc.name, npc.profession, state.player.level)
                end

                state.dialogue.npc = npc

                -- Use relationship-based greeting if available
                local relationshipGreeting = F.getRelationshipDialogue(npc)
                if relationshipGreeting then
                    state.dialogue.text = relationshipGreeting
                -- Use event-based greeting if NPC is in an event
                elseif npc.currentEvent then
                    local eventDialogue = F.getEventDialogue(npc)
                    if eventDialogue and eventDialogue.greeting then
                        state.dialogue.text = eventDialogue.greeting
                    else
                        state.dialogue.text = npc.profession.greetings[math.random(#npc.profession.greetings)]
                    end
                else
                    -- Race-based greeting (non-neutral attitudes get race flavor)
                    local raceGreeting = F.generateRaceGreeting(npc)
                    if raceGreeting then
                        state.dialogue.text = raceGreeting
                    else
                        state.dialogue.text = npc.profession.greetings[math.random(#npc.profession.greetings)]
                    end
                end

                state.dialogue.options = F.buildDialogueOptions(npc)
                state.phase = "dialogue"

                -- Increase relationship slightly for chatting
                F.modifyNPCRelationship(npc.id, 1, "chat")
                return
            end
        end

        -- Back button
        local backY = contentY + contentH - 45
        if mx >= contentX + contentW/2 - 50 and mx <= contentX + contentW/2 + 50 and my >= backY and my <= backY + 35 then
            state.phase = "town"
            return
        end

    elseif state.phase == "tavern_interior" then
        if not state.player then return end
        -- Handle tavern button clicks
        if state.tavernButtons then
            for _, btn in ipairs(state.tavernButtons) do
                if not btn.disabled and mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                    if btn.id == "work" then
                        -- Launch cafe game
                        local townId = state.world.currentTown and state.world.currentTown.id or "havenbrook"

                        PlayerData.currentBuildingOwned = PropertySystem.ownsProperty(townId, "tavern")
                        PlayerData.currentBuildingTownId = townId
                        PlayerData.currentBuildingId = "tavern"

                        local CafeGame = require("cafegame")
                        CafeGame.init()
                        GameState.current = "cafegame"
                        log("Time to serve some customers!", {0.6, 0.5, 0.5})
                    elseif btn.id == "talk" then
                        -- Go to NPC list
                        state.phase = "npc_list"
                    elseif btn.id == "rest" then
                        -- Rest at the tavern (same as old inn functionality)
                        if state.player.gold >= 20 then
                            state.player.gold = state.player.gold - 20
                            state.player.hp = state.player.maxHP
                            state.player.mana = state.player.maxMana
                            if state.player.party then
                                for _, companion in ipairs(state.player.party) do
                                    companion.hp = companion.maxHP
                                end
                            end
                            log("Rested at the tavern for 20 gold. Fully restored!", {0.5, 0.8, 0.5})
                        else
                            log("Not enough gold for a room (need 20g)", {0.8, 0.4, 0.4})
                        end
                    elseif btn.id == "poker" then
                        local TradingCards = require("tradingcards")
                        TradingCards.init()
                        GameState.current = "tradingcards"
                        log("Time for a game of cards!", {0.5, 0.5, 0.8})
                    elseif btn.id == "collection" then
                        local Collection = require("collection")
                        Collection.init()
                        GameState.current = "collection"
                    elseif btn.id == "lootboxes" then
                        local LootBox = require("lootbox")
                        LootBox.init()
                        GameState.current = "lootbox"
                    elseif btn.id == "deckeditor" then
                        local DeckBuilder = require("deckbuilder")
                        DeckBuilder.init()
                        GameState.current = "deckbuilder"
                    end
                    return
                end
            end
        end

        -- Leave button
        local leaveBtn = state.tavernLeaveButton
        if leaveBtn and mx >= leaveBtn.x and mx <= leaveBtn.x + leaveBtn.w and my >= leaveBtn.y and my <= leaveBtn.y + leaveBtn.h then
            state.phase = "town"
            return
        end

    elseif state.phase == "guild_interior" then
        if not state.player then return end
        -- Handle guild button clicks
        if state.guildButtons then
            for _, btn in ipairs(state.guildButtons) do
                if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                    if btn.id == "questboard" then
                        state.phase = "job_board"
                    elseif btn.id == "recruitment" then
                        state.guildCompanions = nil
                        state.phase = "guild"
                    elseif btn.id == "retrieve_stash" then
                        -- Retrieve death stash belongings
                        local stash = PlayerData.deathStash
                        if stash then
                            local goldRetrieved = stash.gold or 0
                            local itemsRetrieved = 0
                            if goldRetrieved > 0 then
                                state.player.gold = (state.player.gold or 0) + goldRetrieved
                                log("Retrieved " .. goldRetrieved .. " gold from your fallen hero's belongings!", {1, 0.85, 0.2})
                            end
                            if stash.items and #stash.items > 0 then
                                for _, item in ipairs(stash.items) do
                                    if Backpack and Backpack.addItem then
                                        Backpack.addItem(item.id, item.count or 1)
                                        itemsRetrieved = itemsRetrieved + 1
                                    end
                                end
                                if itemsRetrieved > 0 then
                                    log("Retrieved " .. itemsRetrieved .. " items from the stash!", {0.5, 0.8, 1})
                                end
                            end
                            PlayerData.deathStash = nil
                            if savePlayerData then savePlayerData() end
                            TextRPG.save()
                            log("All belongings have been reclaimed.", {0.7, 1, 0.7})
                        end
                    elseif btn.id == "revive_hero" then
                        state.phase = "revive_hero"
                        state.reviveScroll = 0
                    end
                    return
                end
            end
        end

        -- Leave button
        local leaveBtn = state.guildLeaveButton
        if leaveBtn and mx >= leaveBtn.x and mx <= leaveBtn.x + leaveBtn.w and my >= leaveBtn.y and my <= leaveBtn.y + leaveBtn.h then
            state.phase = "town"
            return
        end

    elseif state.phase == "revive_hero" then
        if not state.player then return end
        -- Handle revive button clicks
        if state.reviveButtons then
            for _, btn in ipairs(state.reviveButtons) do
                if btn.canRevive and mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                    local graveyard = PlayerData.textRPGGraveyard
                    local hero = graveyard[btn.graveyardIdx]
                    if hero and state.player.gold >= btn.cost then
                        -- Deduct gold
                        state.player.gold = state.player.gold - btn.cost

                        -- Create companion from fallen hero (stats scale with level like normal companions)
                        local heroLevel = hero.level or 1
                        -- Use soldier-equivalent base stats for revived heroes
                        local baseHP, baseAtk, baseDef = 70, 11, 8
                        local companion = {
                            id = "revived_" .. (hero.name or "hero") .. "_" .. math.random(10000, 99999),
                            name = hero.name or "Revived Hero",
                            class = {name = hero.class or "Warrior", id = string.lower(hero.class or "warrior"),
                                     baseHP = baseHP, baseAtk = baseAtk, baseDef = baseDef},
                            level = heroLevel,
                            maxHP = math.floor(baseHP + heroLevel * 6.5),
                            attack = math.floor(baseAtk + heroLevel * 1.8),
                            defense = math.floor(baseDef + heroLevel * 1.1),
                            dailyWage = 5 + math.floor((heroLevel - 1) * 0.5) * 2,
                            portrait = "warrior",
                            color = {0.7, 0.5, 0.8},
                            attacks = {"Strike", "Guard", "Rally"},
                            morale = 80,
                            revived = true,
                        }
                        companion.hp = math.floor(companion.maxHP * 0.5) -- Revive at 50% HP

                        if not state.player.party then
                            state.player.party = {}
                        end
                        table.insert(state.player.party, companion)

                        -- Remove from graveyard
                        table.remove(graveyard, btn.graveyardIdx)
                        PlayerData.textRPGGraveyard = graveyard
                        if savePlayerData then savePlayerData() end
                        TextRPG.save()

                        log(hero.name .. " the " .. (hero.class or "Unknown") .. " has been revived!", {0.7, 0.5, 0.9})
                        log("They rejoin your party at 50% health, weakened but grateful.", {0.6, 0.6, 0.7})
                        F.addJournalEvent("party", "Revived " .. hero.name .. " the " .. (hero.class or "Unknown") .. " from the graveyard", {0.7, 0.5, 0.9})
                    end
                    return
                end
            end
        end

        -- Back button
        local backBtn = state.reviveBackButton
        if backBtn and mx >= backBtn.x and mx <= backBtn.x + backBtn.w and my >= backBtn.y and my <= backBtn.y + backBtn.h then
            state.phase = "guild_interior"
            return
        end

    elseif state.phase == "building_interior" then
        -- Leave button
        local leaveBtn = state.buildingLeaveButton
        if leaveBtn and mx >= leaveBtn.x and mx <= leaveBtn.x + leaveBtn.w and my >= leaveBtn.y and my <= leaveBtn.y + leaveBtn.h then
            state.phase = "town"
            state.buildingInterior = nil
            log("You leave the building.", {0.6, 0.6, 0.7})
            return
        end

        -- Talk to NPC if near one (same as pressing E)
        if state.buildingInteriorNearNPC then
            state.selectedNPC = state.buildingInteriorNearNPC
            state.phase = "npc_dialogue"
            log(state.buildingInteriorNearNPC.dialogue.greeting, {0.7, 0.7, 0.9})
            return
        end

    elseif state.phase == "npc_dialogue" then
        if not state.player then return end
        -- Handle NPC dialogue option clicks
        if state.npcDialogueButtons then
            for _, btn in ipairs(state.npcDialogueButtons) do
                if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                    local option = btn.option
                    local npc = state.selectedNPC

                    if option.action == "chat" then
                        -- Random chat response
                        if option.responses and #option.responses > 0 then
                            local response = option.responses[math.random(1, #option.responses)]
                            log(npc.name .. ": \"" .. response .. "\"", {0.7, 0.8, 0.9})
                        end
                    elseif option.action == "shop" then
                        -- Open shop
                        state.phase = "shop"
                        state.shopType = option.shopType or "general"
                        state.shopTitle = npc.building:gsub("^%l", string.upper) .. " Store"
                        log(npc.name .. " shows you their wares.", {0.6, 0.7, 0.6})
                    elseif option.action == "stable" then
                        -- Open stable
                        state.phase = "stable"
                        state.stableTab = "beasts"
                        log(npc.name .. " shows you the mounts.", {0.6, 0.7, 0.6})
                    elseif option.action == "blessing" then
                        -- Chapel blessing
                        if state.player.gold >= 10 then
                            state.player.gold = state.player.gold - 10
                            local healAmt = math.floor(state.player.maxHP * 0.3)
                            local manaAmt = math.floor(state.player.maxMana * 0.3)
                            state.player.hp = math.min(state.player.maxHP, state.player.hp + healAmt)
                            state.player.mana = math.min(state.player.maxMana, state.player.mana + manaAmt)
                            log("You offer 10g and receive a blessing. Restored " .. healAmt .. " HP and " .. manaAmt .. " MP.", {0.8, 0.8, 0.5})
                        else
                            log("You need 10 gold for a blessing.", {0.8, 0.4, 0.4})
                        end
                    elseif option.action == "forge" then
                        -- Launch forge
                        local townId = state.world.currentTown and state.world.currentTown.id or "havenbrook"
                        PlayerData.currentBuildingOwned = PropertySystem.ownsProperty(townId, "forge")
                        PlayerData.currentBuildingTownId = townId
                        PlayerData.currentBuildingId = "forge"
                        local Forge = require("forge")
                        Forge.init()
                        GameState.current = "forge"
                        log("You begin working at the forge...", {0.7, 0.4, 0.2})
                    elseif option.action == "alchemist" then
                        -- Launch alchemist
                        local townId = state.world.currentTown and state.world.currentTown.id or "havenbrook"
                        PlayerData.currentBuildingOwned = PropertySystem.ownsProperty(townId, "alchemist")
                        PlayerData.currentBuildingTownId = townId
                        PlayerData.currentBuildingId = "alchemist"
                        local Alchemist = require("alchemist")
                        Alchemist.init()
                        GameState.current = "alchemist"
                        log("You enter the alchemist's laboratory...", {0.3, 0.6, 0.4})
                    elseif option.action == "wizardtower" then
                        -- Launch wizard tower
                        local townId = state.world.currentTown and state.world.currentTown.id or "havenbrook"
                        PlayerData.currentBuildingOwned = PropertySystem.ownsProperty(townId, "wizardtower")
                        PlayerData.currentBuildingTownId = townId
                        PlayerData.currentBuildingId = "wizardtower"
                        local WizardTower = require("wizardtower")
                        WizardTower.init()
                        GameState.current = "wizardtower"
                        log("You climb the wizard tower stairs...", {0.4, 0.3, 0.7})
                    elseif option.action == "fishing" then
                        -- Launch fishing
                        local townId = state.world.currentTown and state.world.currentTown.id or "havenbrook"
                        PlayerData.currentBuildingOwned = PropertySystem.ownsProperty(townId, "fishing")
                        PlayerData.currentBuildingTownId = townId
                        PlayerData.currentBuildingId = "fishing"
                        local Fishing = require("fishing")
                        Fishing.init()
                        GameState.current = "fishing"
                        log("Time to cast your line!", {0.3, 0.5, 0.7})
                    elseif option.action == "hunting" then
                        -- Launch hunting
                        local townId = state.world.currentTown and state.world.currentTown.id or "havenbrook"
                        PlayerData.currentBuildingOwned = PropertySystem.ownsProperty(townId, "hunting")
                        PlayerData.currentBuildingTownId = townId
                        PlayerData.currentBuildingId = "hunting"
                        local Hunting = require("hunting")
                        Hunting.init()
                        GameState.current = "hunting"
                        log("You enter the hunter's lodge...", {0.5, 0.4, 0.3})
                    elseif option.action == "stockmarket" then
                        -- Launch trading post
                        local townId = state.world.currentTown and state.world.currentTown.id or "havenbrook"
                        PlayerData.currentBuildingOwned = PropertySystem.ownsProperty(townId, "market")
                        PlayerData.currentBuildingTownId = townId
                        PlayerData.currentBuildingId = "market"
                        local StockMarket = require("stockmarket")
                        StockMarket.init()
                        GameState.current = "stockmarket"
                        log("You enter the bustling trading post...", {0.4, 0.5, 0.5})
                    elseif option.action == "water" then
                        -- Draw water from well
                        local healAmt = math.floor(state.player.maxHP * 0.1)
                        state.player.hp = math.min(state.player.maxHP, state.player.hp + healAmt)
                        log("You drink from the cool, clear water. Restored " .. healAmt .. " HP.", {0.4, 0.6, 0.8})
                    elseif option.action == "land_office_permit" then
                        -- Open land office with permit purchase tab
                        state.phase = "land_office"
                        state.landOfficeTab = "main"
                        log("The Commissioner opens the permits ledger.", {0.55, 0.5, 0.35})
                    elseif option.action == "land_office_rules" then
                        -- Open land office with rules tab
                        state.phase = "land_office"
                        state.landOfficeTab = "rules"
                        log("The Commissioner explains the expansion rules.", {0.55, 0.5, 0.35})
                    elseif option.action == "land_office_status" then
                        -- Open land office with settlements status tab
                        state.phase = "land_office"
                        state.landOfficeTab = "status"
                        log("The Commissioner reviews your land holdings.", {0.55, 0.5, 0.35})
                    end
                    return
                end
            end
        end

        -- Back button
        local backBtn = state.npcDialogueBackButton
        if backBtn and mx >= backBtn.x and mx <= backBtn.x + backBtn.w and my >= backBtn.y and my <= backBtn.y + backBtn.h then
            state.phase = "building_interior"
            state.selectedNPC = nil
            return
        end

    elseif state.phase == "job_board" then
        if not state.player then return end
        local town = state.world.currentTown
        local questY = contentY + 50

        for i, quest in ipairs(town.jobBoard) do
            if i <= 5 then
                local qy = questY + (i - 1) * 70

                if mx >= contentX + 20 and mx <= contentX + contentW - 20 and my >= qy and my <= qy + 65 then
                    state.player.activeQuests = state.player.activeQuests or {}
                    table.insert(state.player.activeQuests, quest)
                    quest.accepted = true
                    table.remove(town.jobBoard, i)
                    log("Accepted quest: " .. (quest.name or "Unknown"), {0.9, 0.7, 0.2})
                    F.addJournalEvent("quest", "Accepted: " .. quest.name, {0.9, 0.7, 0.2})
                    return
                end
            end
        end

        -- Back button
        local backY = contentY + contentH - 45
        if mx >= contentX + contentW/2 - 50 and mx <= contentX + contentW/2 + 50 and my >= backY and my <= backY + 35 then
            state.phase = "town"
            return
        end

    elseif state.phase == "inventory" then
        if not state.player then return end
        local inventory = F.getTQInventory()
        local itemY = contentY + 162
        for i, item in ipairs(inventory) do
            if i <= 8 then
                local iy = itemY + (i - 1) * 28
                if mx >= contentX + 20 and mx <= contentX + 240 and my >= iy and my <= iy + 25 then
                    F.useItem(i)
                    return
                end
            end
        end

        -- Open Full Backpack button
        local bpY = contentY + contentH - 90
        if mx >= contentX + contentW/2 - 75 and mx <= contentX + contentW/2 + 75 and my >= bpY and my <= bpY + 35 then
            Backpack.toggle()
            return
        end

        local backY = contentY + contentH - 45
        if mx >= contentX + contentW/2 - 50 and mx <= contentX + contentW/2 + 50 and my >= backY and my <= backY + 35 then
            if state.combat.returnTo then
                state.phase = state.combat.returnTo
                state.combat.returnTo = nil
            else
                state.phase = "town"
            end
            return
        end

    elseif state.phase == "quest_log" then
        if not state.player then return end
        -- Visit Elders button (when no quests)
        if #(state.player.activeQuests or {}) == 0 then
            local btnY = contentY + 150
            if mx >= contentX + contentW/2 - 80 and mx <= contentX + contentW/2 + 80 and my >= btnY and my <= btnY + 40 then
                -- Go to town and find elder
                local town = state.world.currentTown
                if town then
                    for _, npc in ipairs(town.npcs) do
                        if npc.profession.isElder then
                            if not npc.quest then
                                npc.quest = F.generateQuest(npc.name, npc.profession, state.player.level)
                            end
                            state.dialogue.npc = npc
                            state.dialogue.text = npc.profession.greetings[math.random(#npc.profession.greetings)]
                            state.dialogue.options = F.buildDialogueOptions(npc)
                            state.phase = "dialogue"
                            return
                        end
                    end
                end
            end
        end

        -- Claim quest rewards
        local questY = contentY + 50
        local claimQuests = state.player.activeQuests or {}
        for i = #claimQuests, 1, -1 do
            local quest = claimQuests[i]
            local qy = questY + (i - 1) * 70
            if quest.completed and mx >= contentX + 20 and mx <= contentX + contentW - 20 and my >= qy and my <= qy + 65 then
                state.player.gold = state.player.gold + quest.rewardGold
                F.gainXP(quest.rewardXP)
                log("Quest reward: " .. quest.rewardGold .. "g, " .. quest.rewardXP .. "xp", {0.9, 0.7, 0.2})
                table.remove(state.player.activeQuests, i)
                state.stats.questsCompleted = state.stats.questsCompleted + 1
                PlayerData.wins = PlayerData.wins + 1
                savePlayerData()
                return
            end
        end

        local backY = contentY + contentH - 45
        if mx >= contentX + contentW/2 - 50 and mx <= contentX + contentW/2 + 50 and my >= backY and my <= backY + 35 then
            state.phase = "town"
            return
        end

    elseif state.phase == "shop" then
        if not state.player then return end
        local town = state.world.currentTown
        local shopType = state.shopType or "general"
        local shopInventory = (town.shops and town.shops[shopType]) or town.shop or {}
        local itemY = contentY + 65

        for i, item in ipairs(shopInventory) do
            if i <= 8 then
                local iy = itemY + (i - 1) * 38
                if mx >= contentX + 30 and mx <= contentX + contentW - 30 and my >= iy and my <= iy + 34 then
                    if state.player.gold >= item.value then
                        state.player.gold = state.player.gold - item.value
                        -- Add to shared backpack
                        if item.backpackId then
                            Backpack.addItem(item.backpackId, 1)
                        end
                        log("Bought " .. item.name .. " (added to Backpack)", {0.3, 0.8, 0.5})
                    else
                        log("Not enough gold!", {0.9, 0.3, 0.3})
                    end
                    return
                end
            end
        end

        local backY = contentY + contentH - 45
        if mx >= contentX + contentW/2 - 50 and mx <= contentX + contentW/2 + 50 and my >= backY and my <= backY + 35 then
            state.phase = "town"
            return
        end

    elseif state.phase == "market" then
        if not state.player then return end
        local town = state.world.currentTown
        if not town then return end

        -- Tab buttons
        local tabs = {"buy", "sell", "routes"}
        local tabW = 100
        local tabStartX = contentX + (contentW - #tabs * (tabW + 5)) / 2
        local tabY = contentY + 65

        for i, tab in ipairs(tabs) do
            local tx = tabStartX + (i - 1) * (tabW + 5)
            if mx >= tx and mx <= tx + tabW and my >= tabY and my <= tabY + 28 then
                state.marketTab = tab
                return
            end
        end

        local contentStartY = tabY + 60

        if state.marketTab == "buy" then
            -- Buy goods
            for i, good in ipairs(town.market) do
                if i <= 10 then
                    local iy = contentStartY + (i - 1) * 28
                    if mx >= contentX + 20 and mx <= contentX + contentW - 20 and my >= iy and my <= iy + 25 then
                        -- Apply shop discount from racial/background bonuses
                        local effectivePrice = good.buyPrice
                        local cBonus = state.player and state.player.characterBonuses
                        if cBonus and cBonus.shopDiscountBonus > 0 then
                            effectivePrice = math.max(1, math.floor(effectivePrice * (1 - cBonus.shopDiscountBonus / 100)))
                        end
                        if state.player.gold >= effectivePrice and good.stock > 0 then
                            state.player.gold = state.player.gold - effectivePrice
                            good.stock = good.stock - 1
                            -- Add to player's goods at this town
                            if not state.playerGoods[town.name] then
                                state.playerGoods[town.name] = {}
                            end
                            state.playerGoods[town.name][good.id] = (state.playerGoods[town.name][good.id] or 0) + 1
                            log("Bought " .. good.name .. " (stored in " .. town.name .. ")" .. (cBonus and cBonus.shopDiscountBonus > 0 and " (discounted!)" or ""), {0.3, 0.8, 0.5})
                        elseif good.stock <= 0 then
                            log("Out of stock!", {0.9, 0.5, 0.3})
                        else
                            log("Not enough gold!", {0.9, 0.3, 0.3})
                        end
                        return
                    end
                end
            end

        elseif state.marketTab == "sell" then
            -- Sell player's goods
            local playerStock = state.playerGoods[town.name] or {}
            local itemCount = 0
            for goodId, quantity in pairs(playerStock) do
                if quantity > 0 and itemCount < 10 then
                    local iy = contentStartY + itemCount * 28
                    if mx >= contentX + 20 and mx <= contentX + contentW - 20 and my >= iy and my <= iy + 25 then
                        -- Find sell price
                        for _, g in ipairs(town.market) do
                            if g.id == goodId then
                                local finalPrice = g.sellPrice
                                -- Passive: silver_tongue (+sell price)
                                local cBonus = state.player and state.player.characterBonuses
                                if cBonus and cBonus.sellPriceMult > 1 then
                                    finalPrice = math.floor(finalPrice * cBonus.sellPriceMult)
                                end
                                state.player.gold = state.player.gold + finalPrice
                                state.playerGoods[town.name][goodId] = quantity - 1
                                log("Sold " .. g.name .. " for " .. finalPrice .. "g", {0.3, 0.8, 0.5})
                                state.stats.goldEarned = (state.stats.goldEarned or 0) + finalPrice
                                break
                            end
                        end
                        return
                    end
                    itemCount = itemCount + 1
                end
            end

        elseif state.marketTab == "routes" then
            -- Click on destination town to start trade route
            local sendY = contentStartY + 200
            local btnY = sendY + 25
            local playerStock = state.playerGoods[town.name] or {}
            local hasGoods = false
            for _, qty in pairs(playerStock) do
                if qty > 0 then hasGoods = true break end
            end

            for _, t in ipairs(state.world.towns) do
                if t.name ~= town.name then
                    if mx >= contentX + 30 and mx <= contentX + contentW - 30 and my >= btnY and my <= btnY + 25 then
                        if hasGoods then
                            -- Send first available good
                            for goodId, qty in pairs(playerStock) do
                                if qty > 0 then
                                    local goodName = goodId
                                    for _, g in ipairs(town.market) do
                                        if g.id == goodId then goodName = g.name break end
                                    end
                                    local dist = math.abs(t.x - town.x) + math.abs(t.y - town.y)
                                    table.insert(state.tradeRoutes, {
                                        origin = town.name,
                                        destination = t.name,
                                        goodId = goodId,
                                        goodName = goodName,
                                        quantity = 1,
                                        departureDay = state.daysPassed,
                                        arrivalDay = state.daysPassed + dist,
                                    })
                                    state.playerGoods[town.name][goodId] = qty - 1
                                    log("Caravan sent to " .. t.name .. " (" .. dist .. " days)", {0.5, 0.8, 0.5})
                                    break
                                end
                            end
                        else
                            log("No goods to send! Buy some first.", {0.9, 0.5, 0.3})
                        end
                        return
                    end
                    btnY = btnY + 28
                    if btnY > contentY + contentH - 80 then break end
                end
            end
        end

        -- Back button
        local backY = contentY + contentH - 45
        if mx >= contentX + contentW/2 - 50 and mx <= contentX + contentW/2 + 50 and my >= backY and my <= backY + 35 then
            state.phase = "town"
            return
        end

    elseif state.phase == "death" then
        local btnW = 200
        local btnH = 42
        local btnY = contentY + contentH - 140
        local btnX = contentX + contentW/2 - btnW/2

        -- "New Adventure" button
        if mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH then
            -- Reset game and go back to class select
            F.resetGame()
            state.phase = "class_select"
            return
        end

        -- "View Graveyard" button
        local graveyard = getGraveyard()
        if #graveyard > 0 then
            local graveY = btnY + btnH + 10
            if mx >= btnX and mx <= btnX + btnW and my >= graveY and my <= graveY + 35 then
                state.phase = "graveyard"
                return
            end
        end

    elseif state.phase == "graveyard" then
        -- Back button
        local backY = contentY + contentH - 45
        if mx >= contentX + contentW/2 - 80 and mx <= contentX + contentW/2 + 80 and my >= backY and my <= backY + 35 then
            state.phase = "death"
            return
        end

        -- "Start New Adventure" button
        local newY = contentY + contentH - 90
        if mx >= contentX + contentW/2 - 100 and mx <= contentX + contentW/2 + 100 and my >= newY and my <= newY + 38 then
            F.resetGame()
            state.phase = "class_select"
            return
        end
    end
end

-- ============================================================================
-- WHEELMOVED
-- ============================================================================
function M.wheelmoved(wx, wy)
    -- === CHATBOT FREE TALK SCROLL ===
    if F.isFreeTalkActive and F.isFreeTalkActive() then
        F.freeTalkMousewheel(wx, wy)
        return
    end

    -- Backpack scrolling (must be first - fullscreen overlay)
    if Backpack.isOpen() then
        Backpack.wheelmoved(wx, wy)
        return
    end

    -- Party UI scrolling
    if state.showPartyUI then
        local scrollStep = 35
        state.partyUIScroll = (state.partyUIScroll or 0) - wy * scrollStep
        state.partyUIScroll = math.max(0, state.partyUIScroll)
        local maxScroll = state.partyUIMaxScroll or 0
        state.partyUIScroll = math.min(maxScroll, state.partyUIScroll)
        return
    end

    -- Journal scrolling
    if state.player and state.player.journal and state.player.journal.isOpen then
        local scrollStep = 30
        state.player.journal.scrollOffset = (state.player.journal.scrollOffset or 0) - wy * scrollStep
        state.player.journal.scrollOffset = math.max(0, state.player.journal.scrollOffset)
        return
    end

    -- Ascension tree scrolling
    if state.showAscensionTree then
        local scrollStep = 40
        state.ascensionScrollOffset = (state.ascensionScrollOffset or 0) - wy * scrollStep
        state.ascensionScrollOffset = math.max(0, state.ascensionScrollOffset)
        local maxScroll = state.maxAscensionScroll or 500
        state.ascensionScrollOffset = math.min(maxScroll, state.ascensionScrollOffset)
        return
    end

    -- Revive hero list scrolling
    if state.phase == "revive_hero" then
        local graveyard = PlayerData.textRPGGraveyard or {}
        state.reviveScroll = (state.reviveScroll or 0) - wy
        state.reviveScroll = math.max(0, state.reviveScroll)
        state.reviveScroll = math.min(math.max(0, #graveyard - 4), state.reviveScroll)
        return
    end

    -- Normal log scrolling
    state.scroll = state.scroll - wy * 30
    state.scroll = math.max(0, state.scroll)
end

-- ============================================================================
-- MOUSERELEASED
-- ============================================================================
function M.mousereleased(mx, my, button)
    -- Forward to backpack (needed for UI.Button close button and scroll container)
    if Backpack.isOpen() then
        Backpack.mousereleased(mx, my, button)
    end
end

-- ============================================================================
-- KEYPRESSED
-- ============================================================================
function M.keypressed(key)
    -- === CHATBOT FREE TALK INPUT (highest priority overlay) ===
    if F.isFreeTalkActive and F.isFreeTalkActive() then
        F.freeTalkKeypressed(key)
        return
    end

    local tacticalState = getTacticalState()
    local TACTICAL_MODE = getTacticalMode()

    -- === DEV MODE PASSWORD PROMPT ===
    if state.showDevModePrompt then
        if key == "escape" then
            state.showDevModePrompt = false
            state.devModePassword = ""
            state.devModePasswordError = false
            return
        elseif key == "return" then
            if F.checkDevModePassword(state.devModePassword) then
                state.showDevModePrompt = false
                state.devModePassword = ""
                state.devModePasswordError = false
                F.activateDevMode()
            else
                state.devModePasswordError = true
                state.devModePassword = ""
            end
            return
        elseif key == "backspace" then
            if #state.devModePassword > 0 then
                state.devModePassword = state.devModePassword:sub(1, -2)
            end
            return
        end
        return  -- Block all other input during password prompt
    end

    -- === FULL BACKPACK OVERLAY KEY HANDLING ===
    -- When the backpack is open, handle its keys (escape to close, b/i to toggle)
    if Backpack.isOpen() then
        if Backpack.keypressed(key) then
            return
        end
    end

    -- === FULL WORLD MAP OVERLAY KEY HANDLING ===
    if state.fullMapOpen then
        if WorldMapOverlay.handleKey(state, key) then
            return
        end
    end

    -- Toggle world map with M key (when player exists and not in modal states)
    -- Note: M key is used for Move in tactical combat, so exclude that phase
    if key == "m" and state.player and state.phase ~= "class_select" and state.phase ~= "death"
       and state.phase ~= "tactical_combat"
       and not state.showCharacterSheet and not state.showSkillTree
       and not state.showTalentSelection and not state.showAscensionTree
       and not state.showSpecializationSelection and not state.showPartyUI
       and not state.companionSkillTreeIndex and not state.companionTalentIndex then
        WorldMapOverlay.toggle(state)
        return
    end

    -- === STEALTH APPROACH KEY HANDLING ===
    if state.phase == "stealth_approach" and state.stealthApproach then
        if key == "escape" then
            -- Cancel stealth approach - back away
            local result = MapEnemies.executeStealthAction("back_away")
            if result and result.message then
                log(result.message, {0.5, 0.8, 0.5})
            end
            state.phase = "map"
            return
        end
        -- Number keys 1-5 select options
        local num = tonumber(key)
        if num and num >= 1 and num <= 5 then
            local options = state.stealthApproach.result and state.stealthApproach.result.options
            if options and options[num] and options[num].available then
                local option = options[num]
                local result = MapEnemies.executeStealthAction(option.id)
                if result then
                    if result.message then
                        log(result.message, result.success and {0.5, 0.9, 0.5} or {0.9, 0.4, 0.3})
                    end
                    if result.enemyDefeated then
                        if result.actionId == "stealth_kill" then
                            state.player.stealthKills = (state.player.stealthKills or 0) + 1
                        elseif result.actionId == "stealth_knockout" then
                            state.player.stealthKnockouts = (state.player.stealthKnockouts or 0) + 1
                        end
                        if result.karmaChange and result.karmaChange ~= 0 then
                            log("Karma: " .. result.karmaChange, {0.7, 0.5, 0.7})
                        end
                        state.phase = "map"
                    elseif result.combatStarts then
                        -- Combat started by executeStealthAction
                    elseif not result.combatStarts then
                        state.phase = "map"
                    end
                end
            end
            return
        end
        return
    end

    -- === TACTICAL COMBAT KEY HANDLING ===
    if state.phase == "tactical_combat" and TACTICAL_MODE and tacticalState and TacticalUI then
        -- Phase 9: Help overlay toggle (F1 always, H only when player cannot hide)
        if key == "f1" then
            tacticalState._showHelp = not tacticalState._showHelp
            return
        end
        if key == "h" then
            local active = tacticalState.activeUnit
            local canHide = StealthSystem and active and (active.isPlayer or active.isPlayerControlled)
                and not active.hasActed and not active.isHidden
            if not canHide then
                -- Use H for help toggle when hide is not available
                tacticalState._showHelp = not tacticalState._showHelp
                return
            end
            -- Otherwise fall through to let the UI handler process H as hide
        end

        -- If help is showing, any other key dismisses it
        if tacticalState._showHelp then
            tacticalState._showHelp = false
            return
        end

        local active = tacticalState.activeUnit
        if active and (active.isPlayer or active.isPlayerControlled) then
            local result = TacticalUI.handleKey(tacticalState, key, Data.SKILLS)
            if result then
                -- Handle the same result types as mouse clicks
                if result.type == "end_turn" then
                    local nextUnit = TacticalCombat.advanceTurn(tacticalState)
                    if nextUnit then
                        TacticalCombat.addLog(tacticalState,
                            nextUnit.name .. "'s turn!", nextUnit.color or {0.8, 0.8, 0.8})
                        -- Phase 10: log start-of-turn effects
                        if tacticalState._turnStartEffects then
                            for _, eff in ipairs(tacticalState._turnStartEffects) do
                                if eff.type == "dot" then
                                    TacticalCombat.addLog(tacticalState,
                                        nextUnit.name .. " takes " .. eff.amount .. " poison/burn damage!",
                                        {0.7, 0.4, 0.9})
                                elseif eff.type == "hazard" then
                                    TacticalCombat.addLog(tacticalState,
                                        nextUnit.name .. " takes " .. eff.amount .. " " .. (eff.hazard or "") .. " damage!",
                                        {0.9, 0.5, 0.2})
                                elseif eff.type == "slip" then
                                    TacticalCombat.addLog(tacticalState,
                                        nextUnit.name .. " slips on ice!",
                                        {0.5, 0.7, 0.9})
                                end
                            end
                        end
                    end
                elseif result.type == "flee" then
                    -- Attempt to flee from tactical combat (50% base + racial bonus)
                    local fleeChance = 0.5
                    local cBonus = state.player and state.player.characterBonuses
                    if cBonus and cBonus.fleeBonusPercent > 0 then
                        fleeChance = fleeChance + (cBonus.fleeBonusPercent / 100)
                    end
                    if math.random() < fleeChance then
                        TacticalCombat.addLog(tacticalState,
                            "You successfully flee from combat!", {0.7, 0.7, 0.3})
                        TacticalCombat.syncToGameState(tacticalState, state.player)
                        if state.world and state.world.currentMapEnemy then
                            MapEnemies.onPlayerFlee()
                        end
                        if state.dungeon and state.dungeon.currentVisibleEnemy then
                            DungeonEnemies.onCombatEnd(false)
                        end
                        if state.dungeon and state.dungeon.currentPrisonGuard then
                            local guard = state.dungeon.currentPrisonGuard
                            guard.inCombat = false
                            guard.alerted = false
                            if state.prisonEscape then
                                local msg2 = PrisonEscape.onGuardCaught(state.prisonEscape)
                                if msg2 then log(msg2, {0.9, 0.4, 0.4}) end
                                state.dungeon.currentFloor = state.prisonEscape.currentFloor
                                state.dungeon.playerX = state.prisonEscape.playerX
                                state.dungeon.playerY = state.prisonEscape.playerY
                                local curFloor = state.dungeon.floors[state.dungeon.currentFloor]
                                if curFloor then curFloor.visibleEnemies = nil end
                                local resetFloor = state.dungeon.floors[state.dungeon.currentFloor]
                                if resetFloor then
                                    for ddy = -1, 1 do
                                        for ddx = -1, 1 do
                                            local nx, ny = state.dungeon.playerX + ddx, state.dungeon.playerY + ddy
                                            if resetFloor.grid[ny] and resetFloor.grid[ny][nx] then
                                                resetFloor.grid[ny][nx].explored = true
                                            end
                                        end
                                    end
                                end
                            end
                            state.dungeon.currentPrisonGuard = nil
                        end
                        if state.inDungeon then
                            state.phase = "dungeon"
                        else
                            state.phase = "map"
                        end
                        log("You escaped!", {0.7, 0.7, 0.3})
                        setTacticalState(nil)
                        return
                    else
                        TacticalCombat.addLog(tacticalState,
                            "Failed to escape! Turn lost.", {0.9, 0.3, 0.3})
                        active.hasMoved = true
                        active.hasActed = true
                        local nextUnit = TacticalCombat.advanceTurn(tacticalState)
                        if nextUnit then
                            TacticalCombat.addLog(tacticalState,
                                nextUnit.name .. "'s turn!", nextUnit.color or {0.8, 0.8, 0.8})
                        end
                    end

                elseif result.type == "hide" then
                    if StealthSystem then
                        local success, msg = StealthSystem.attemptHide(active, tacticalState, TacticalCombat)
                        if success then
                            TacticalCombat.addLog(tacticalState, active.name .. " hides! " .. msg, {0.5, 0.5, 0.8})
                            TacticalCombat.addFloatingText(tacticalState, "HIDDEN", active.x, active.y, {0.5, 0.5, 0.8}, "status")
                        else
                            TacticalCombat.addLog(tacticalState, active.name .. " fails to hide! " .. msg, {0.9, 0.4, 0.4})
                            TacticalCombat.addFloatingText(tacticalState, "EXPOSED", active.x, active.y, {0.9, 0.4, 0.4}, "status")
                        end
                        active.hasActed = true
                        if active.hasMoved and active.hasActed then
                            local nextUnit = TacticalCombat.advanceTurn(tacticalState)
                            if nextUnit then
                                TacticalCombat.addLog(tacticalState,
                                    nextUnit.name .. "'s turn!", nextUnit.color or {0.8, 0.8, 0.8})
                            end
                        end
                    end

                elseif result.type == "shadow_strike" then
                    if StealthSystem and result.target then
                        local target = result.target
                        local canStrike, strikeMsg = StealthSystem.canShadowStrike(
                            active, target.x, target.y, tacticalState, TacticalCombat)
                        if canStrike then
                            local bestTile = nil
                            local bestDist = 999
                            local neighbors = TileUtils.DIRS4
                            for _, n in ipairs(neighbors) do
                                local nx, ny = target.x + n[1], target.y + n[2]
                                if TacticalCombat.isTilePassable(tacticalState.grid, nx, ny)
                                    and not TacticalCombat.getUnitAt(tacticalState.grid, nx, ny) then
                                    local dist = math.abs(active.x - nx) + math.abs(active.y - ny)
                                    if dist < bestDist then
                                        bestDist = dist
                                        bestTile = {x = nx, y = ny}
                                    end
                                end
                            end
                            local dist = math.abs(active.x - target.x) + math.abs(active.y - target.y)
                            if dist > (active.attackRange or 1) and bestTile then
                                local originalMoveRange = active.moveRange
                                active.moveRange = (active.moveRange or 3) + 2
                                TacticalCombat.moveUnit(tacticalState, active, bestTile.x, bestTile.y)
                                active.moveRange = originalMoveRange
                                TacticalCombat.addLog(tacticalState,
                                    active.name .. " shadow-steps to (" .. bestTile.x .. "," .. bestTile.y .. ")!",
                                    {0.5, 0.3, 0.7})
                            end
                            local success, attackResult = TacticalCombat.performAttack(tacticalState, active, target)
                            if success then
                                local msg = "SHADOW STRIKE! " .. active.name .. " strikes " .. target.name
                                    .. " for " .. (attackResult.damage or 0) .. " damage!"
                                if attackResult.isCrit then msg = "CRITICAL " .. msg end
                                TacticalCombat.addLog(tacticalState, msg, {0.6, 0.3, 0.8})
                                if attackResult.targetDown then
                                    TacticalCombat.addLog(tacticalState,
                                        target.name .. " is defeated!", {0.9, 0.9, 0.3})
                                    if target.isEnemy and target.data then
                                        F.onEnemyDefeated(target.data)
                                    end
                                end
                            end
                            active.hasMoved = true
                            active.hasActed = true
                            tacticalState.selectedAction = nil
                            tacticalState.showAttackRange = false
                            if TacticalCombat.checkAllEnemiesDefeated(tacticalState) then
                                TacticalCombat.syncToGameState(tacticalState, state.player)
                                F.endCombat(true)
                                setTacticalState(nil)
                                return
                            end
                            local nextUnit = TacticalCombat.advanceTurn(tacticalState)
                            if nextUnit then
                                TacticalCombat.addLog(tacticalState,
                                    nextUnit.name .. "'s turn!", nextUnit.color or {0.8, 0.8, 0.8})
                            end
                        else
                            TacticalCombat.addLog(tacticalState,
                                "Shadow Strike failed: " .. (strikeMsg or "unknown"), {0.9, 0.3, 0.3})
                        end
                    end

                elseif result.type == "snuff_light" then
                    if StealthSystem and result.source and result.lightIdx then
                        local source = result.source
                        local snuffed, noise = StealthSystem.snuffLightSource(source.source, true)
                        if snuffed then
                            source.active = false
                            if tacticalState.grid.stealthRooms then
                                for _, room in ipairs(tacticalState.grid.stealthRooms) do
                                    StealthSystem.calculateRoomLightLevel(room, "day")
                                end
                                StealthSystem.applyLightingToGrid(
                                    tacticalState.grid, tacticalState.grid.stealthRooms, "day"
                                )
                            end
                            TacticalCombat.addLog(tacticalState,
                                active.name .. " extinguishes the " .. (source.name or "light") .. "!",
                                {0.7, 0.5, 0.2})
                            TacticalCombat.addFloatingText(tacticalState,
                                "SNUFFED", source.x, source.y, {0.7, 0.5, 0.2}, "status")
                            if noise > 0 and math.random() < noise then
                                TacticalCombat.addLog(tacticalState,
                                    "The noise alerts nearby enemies!", {0.9, 0.5, 0.3})
                            end
                        else
                            TacticalCombat.addLog(tacticalState,
                                "Cannot extinguish that light source.", {0.7, 0.4, 0.4})
                        end
                        active.hasActed = true
                        tacticalState.selectedAction = nil
                        tacticalState.snuffableLights = nil
                        if active.hasMoved and active.hasActed then
                            local nextUnit = TacticalCombat.advanceTurn(tacticalState)
                            if nextUnit then
                                TacticalCombat.addLog(tacticalState,
                                    nextUnit.name .. "'s turn!", nextUnit.color or {0.8, 0.8, 0.8})
                            end
                        end
                    end

                elseif result.type == "auto_companion" then
                    -- Toggle companion to AI control for this combat
                    if active.isPlayerControlled and active.isCompanion then
                        active.isPlayerControlled = false
                        if active.data then active.data.autoBattle = true end
                        TacticalCombat.addLog(tacticalState,
                            active.name .. " is now on AUTO.", {0.5, 0.7, 0.3})
                        local TacticalAI = require("tactical_combat_ai")
                        local results = TacticalAI.executeCompanionTurn(tacticalState, active)
                        if results and results.attacked and results.attackResult and results.attackResult.targetDown then
                            if results.target and results.target.isEnemy and results.target.data then
                                F.onEnemyDefeated(results.target.data)
                            end
                        end
                        if TacticalCombat.checkAllEnemiesDefeated(tacticalState) then
                            TacticalCombat.syncToGameState(tacticalState, state.player)
                            F.endCombat(true)
                            setTacticalState(nil)
                            return
                        end
                        local nextUnit = TacticalCombat.advanceTurn(tacticalState)
                        if nextUnit then
                            TacticalCombat.addLog(tacticalState,
                                nextUnit.name .. "'s turn!", nextUnit.color or {0.8, 0.8, 0.8})
                        end
                    end

                elseif result.type == "open_inventory" then
                    state.phase = "inventory"
                    state.combat.returnTo = "tactical_combat"
                end
                -- Other results (action_selected, cancel, target_cycle) are handled by the UI module
            end
        end
        return  -- Block other key handling during tactical combat
    end

    -- === TACTICAL MODE TOGGLE (F9) - Permanent player preference ===
    if key == "f9" and state.player then
        local newMode = not TACTICAL_MODE
        setTacticalMode(newMode)
        TACTICAL_MODE = newMode
        if TACTICAL_MODE then
            -- Load modules if not already loaded
            if not TacticalCombat then
                TacticalCombat = require("tactical_combat")
                TacticalUI = require("tactical_combat_ui")
                TacticalAI = require("tactical_combat_ai")
                TacticalAI.init(TacticalCombat)
                TacticalUI.init(TacticalCombat, F.getFont)
                -- Update AutoPlay with newly loaded tactical references
                AutoPlay.setTacticalReferences(TacticalCombat, TacticalAI, function() return getTacticalState() end, function() setTacticalState(nil) end)
            end
            log("TACTICAL MODE: ON (Grid-based combat)", {0.9, 0.9, 0.3})
        else
            log("TACTICAL MODE: OFF (Classic combat)", {0.9, 0.9, 0.3})
        end
        -- Phase 9: Sync toggle to PlayerData.settings so Options menu stays in sync
        if PlayerData and not PlayerData.settings then PlayerData.settings = {} end
        if PlayerData and PlayerData.settings then
            PlayerData.settings.tacticalCombat = TACTICAL_MODE
        end
        return
    end

    -- === TEST TACTICAL COMBAT (F10) ===
    if key == "f10" and state.player then
        local testEnemies = {}
        table.insert(testEnemies, F.createEnemyInstance(Data.ENEMIES[4], state.player.level))  -- Goblin
        table.insert(testEnemies, F.createEnemyInstance(Data.ENEMIES[4], state.player.level))  -- Goblin
        table.insert(testEnemies, F.createEnemyInstance(Data.ENEMIES[11], state.player.level)) -- Orc
        F.startCombat(testEnemies)
        return
    end

    -- Handle backspace for name input during class selection
    if state.phase == "class_select" and key == "backspace" then
        if state.playerNameInput and #state.playerNameInput > 0 then
            state.playerNameInput = state.playerNameInput:sub(1, -2)
        end
        return
    end

    -- === VAMPIRE PROTECTION HANDLING ===
    if state.player and state.player.isVampire then
        local hour = math.floor(state.timeOfDay or 12)
        if F.isInSunlight(hour) and not F.isVampireProtected(state.player) then
            if key == "c" then
                if Backpack.hasItem("tq_vampire_coffin") then
                    state.player.hasVampireCoffin = true
                    log("You enter your coffin. You are safe from the sun.", {0.5, 0.8, 0.5})
                    return
                end
            elseif key == "w" then
                if Backpack.hasItem("tq_black_cloth") then
                    state.player.vampireClothWrapped = true
                    Backpack.removeItem("tq_black_cloth", 1)
                    log("You wrap yourself in cloth. This is risky...", {0.9, 0.7, 0.3})
                    return
                end
            end
        end
    end

    -- === OVERLAY UI HANDLING ===

    -- Specialization selection (cannot be escaped - must make a choice)
    if state.showSpecializationSelection then
        local specClassId = state.player and state.player.class and state.player.class.id or "warrior"
        local specs = F.getSpecializationOptions(specClassId)
        if #specs > 0 then
            if key == "left" or key == "a" then
                state.selectedSpecIndex = 1
            elseif key == "right" or key == "d" then
                state.selectedSpecIndex = 2
            elseif key == "return" or key == "space" then
                -- Confirm specialization choice
                local selectedSpec = specs[state.selectedSpecIndex]
                if selectedSpec then
                    local p = state.player
                    p.specialization = selectedSpec.id
                    p.specializationName = selectedSpec.name
                    p.pendingSpecialization = false
                    state.showSpecializationSelection = false

                    -- Apply specialization bonuses to stats
                    log("", {1, 1, 1})
                    log("You have become a " .. selectedSpec.name .. "!", selectedSpec.color)
                    for _, passive in ipairs(selectedSpec.passives or {}) do
                        log("  - " .. passive, {0.7, 0.7, 0.8})
                    end

                    -- Recalculate stats with new specialization
                    F.calculateStats()
                    TextRPG.save()
                end
            end
        end
        return  -- Block all other input during specialization selection
    end

    -- Close overlays with escape
    if key == "escape" then
        if state.companionTalentIndex then
            state.companionTalentIndex = nil
            state.selectedCompanionTalentIndex = 1
            return
        elseif state.companionSkillTreeIndex then
            state.companionSkillTreeIndex = nil
            state.selectedCompanionSkillIndex = 1
            return
        elseif state.showPartyUI then
            state.showPartyUI = false
            state.partyUIScroll = 0
            state.selectedPartyCompanion = nil
            return
        elseif state.showAscensionTree then
            state.showAscensionTree = false
            return
        elseif state.showTalentSelection then
            state.showTalentSelection = false
            return
        elseif state.showSkillTree then
            state.showSkillTree = false
            return
        elseif state.showCharacterSheet then
            state.showCharacterSheet = false
            return
        -- City expansion: escape to go back from new phases
        elseif state.phase == "district" then
            F.handleDistrictAction("district_leave")
            return
        elseif state.phase == "guild_hall" then
            F.handleGuildHallAction("guild_leave")
            return
        elseif state.phase == "underbelly" then
            F.handleUnderbellyAction("ub_leave")
            return
        elseif state.phase == "bounty_board" then
            state.phase = "town"
            return
        elseif state.phase == "courier_office" then
            state.phase = "town"
            return
        end
    end

    -- Active quest compass toggle (Q key while on map)
    if key == "q" and state.phase == "map" and state.player and state.player.quests then
        local quests = state.player.quests
        local activeQuests = {}
        for i, quest in ipairs(quests) do
            if quest.accepted and not quest.completed and quest.compassTarget then
                table.insert(activeQuests, i)
            end
        end
        if #activeQuests > 0 then
            -- Cycle through compass-trackable quests
            local currentIdx = 0
            for j, idx in ipairs(activeQuests) do
                if idx == state.activeQuestIndex then
                    currentIdx = j
                    break
                end
            end
            local nextIdx = (currentIdx % #activeQuests) + 1
            state.activeQuestIndex = activeQuests[nextIdx]
            local quest = quests[state.activeQuestIndex]
            log("Tracking: " .. (quest.name or "Quest"), {0.8, 0.8, 0.3})
        end
    end

    -- Character sheet toggle (C key)
    if key == "c" and state.player and state.phase ~= "class_select" and state.phase ~= "death" then
        if state.showSkillTree or state.showTalentSelection or state.showAscensionTree then
            state.showSkillTree = false
            state.showTalentSelection = false
            state.showAscensionTree = false
        end
        state.showCharacterSheet = not state.showCharacterSheet
        return
    end

    -- Skill tree from character sheet (S key)
    if key == "s" and state.showCharacterSheet then
        state.showSkillTree = true
        state.showCharacterSheet = false
        state.selectedSkillIndex = 1
        return
    end

    -- Talent selection from character sheet (T key)
    if key == "t" and state.showCharacterSheet then
        state.showTalentSelection = true
        state.showCharacterSheet = false
        state.selectedTalentIndex = 1
        return
    end

    -- P key: Ascension tree (from character sheet) OR Party UI toggle (otherwise)
    if key == "p" and state.player
       and state.phase ~= "class_select" and state.phase ~= "death" then
        if state.showCharacterSheet == true then
            -- Character sheet is open: P opens the Ascension/Prestige tree
            state.showAscensionTree = true
            state.showCharacterSheet = false
            state.selectedAscensionIndex = 1
            state.ascensionScrollOffset = 0
        else
            -- No character sheet: toggle Party UI
            -- Close any sub-overlays first
            if state.showSkillTree or state.showTalentSelection or state.showAscensionTree then
                state.showSkillTree = false
                state.showTalentSelection = false
                state.showAscensionTree = false
            end
            state.showPartyUI = not state.showPartyUI
            if not state.showPartyUI then
                state.partyUIScroll = 0
            end
        end
        return
    end

    -- Companion skill tree navigation
    if state.companionSkillTreeIndex then
        local compIdx = state.companionSkillTreeIndex
        local party = state.player and state.player.party
        local companion = party and party[compIdx]
        if companion then
            local tree = Data.SKILL_TREES and Data.SKILL_TREES.universal
            if tree then
                if key == "up" or key == "w" then
                    state.selectedCompanionSkillIndex = navigateNodeGraph(tree, state.selectedCompanionSkillIndex or 1, "up")
                elseif key == "down" or key == "s" then
                    state.selectedCompanionSkillIndex = navigateNodeGraph(tree, state.selectedCompanionSkillIndex or 1, "down")
                elseif key == "left" or key == "a" then
                    state.selectedCompanionSkillIndex = navigateNodeGraph(tree, state.selectedCompanionSkillIndex or 1, "left")
                elseif key == "right" or key == "d" then
                    state.selectedCompanionSkillIndex = navigateNodeGraph(tree, state.selectedCompanionSkillIndex or 1, "right")
                elseif key == "tab" then
                    companion.autoAllocate = not companion.autoAllocate
                elseif key == "return" or key == "space" then
                    local node = tree.nodes[state.selectedCompanionSkillIndex or 1]
                    if node then
                        if not companion.unlockedSkills then companion.unlockedSkills = {start = true} end
                        local isUnlocked = companion.unlockedSkills[node.id]
                        if not isUnlocked and node.cost > 0 then
                            local canUnlock = (companion.skillPoints or 0) >= node.cost
                            if canUnlock then
                                local hasAdjacentUnlocked = false
                                for _, connId in ipairs(node.connections or {}) do
                                    if companion.unlockedSkills[connId] then
                                        hasAdjacentUnlocked = true
                                        break
                                    end
                                end
                                if not hasAdjacentUnlocked then canUnlock = false end
                            end
                            if canUnlock then
                                companion.skillPoints = companion.skillPoints - node.cost
                                companion.unlockedSkills[node.id] = true
                                log(companion.name .. " unlocked: " .. node.name .. "!", {0.3, 0.9, 0.5})
                            end
                        end
                    end
                end
            end
        end
        return
    end

    -- Companion talent selection navigation
    if state.companionTalentIndex then
        local compIdx = state.companionTalentIndex
        local party = state.player and state.player.party
        local companion = party and party[compIdx]
        if companion then
            local mappedClass = Data.COMPANION_CLASS_MAP[companion.class and companion.class.id or ""]
            local availableTalents = {}
            for _, t in ipairs(Data.UNIVERSAL_TALENTS) do
                if t.level <= (companion.level or 1) then
                    local owned = companion.talents and companion.talents[t.id]
                    if not owned then
                        table.insert(availableTalents, {talent = t, type = "universal"})
                    end
                end
            end
            if mappedClass and Data.CLASS_TALENTS[mappedClass] then
                for _, t in ipairs(Data.CLASS_TALENTS[mappedClass]) do
                    if t.level <= (companion.level or 1) then
                        local owned = companion.talents and companion.talents[t.id]
                        if not owned then
                            table.insert(availableTalents, {talent = t, type = "class"})
                        end
                    end
                end
            end
            local talentCount = math.min(5, #availableTalents)
            if key == "up" or key == "w" then
                state.selectedCompanionTalentIndex = math.max(1, (state.selectedCompanionTalentIndex or 1) - 1)
            elseif key == "down" or key == "s" then
                state.selectedCompanionTalentIndex = math.min(talentCount, (state.selectedCompanionTalentIndex or 1) + 1)
            elseif key == "return" or key == "space" then
                local entry = availableTalents[state.selectedCompanionTalentIndex or 1]
                if entry then
                    if not companion.talents then companion.talents = {} end
                    companion.talents[entry.talent.id] = true
                    companion.pendingTalentSelection = false
                    state.companionTalentIndex = nil
                    state.selectedCompanionTalentIndex = 1
                end
            end
        end
        return
    end

    -- Party screen companion interaction (1-4 select, S/T/A keys)
    if state.showPartyUI then
        local party = state.player and state.player.party or {}
        -- Number keys to select a companion
        if key == "1" and party[1] then
            state.selectedPartyCompanion = 1
        elseif key == "2" and party[2] then
            state.selectedPartyCompanion = 2
        elseif key == "3" and party[3] then
            state.selectedPartyCompanion = 3
        elseif key == "4" and party[4] then
            state.selectedPartyCompanion = 4
        elseif state.selectedPartyCompanion then
            local ci = state.selectedPartyCompanion
            local comp = party[ci]
            if comp then
                if key == "s" then
                    -- Open companion skill tree
                    state.companionSkillTreeIndex = ci
                    state.selectedCompanionSkillIndex = 1
                    return
                elseif key == "t" and comp.pendingTalentSelection then
                    -- Open companion talent selection
                    state.companionTalentIndex = ci
                    state.selectedCompanionTalentIndex = 1
                    return
                elseif key == "a" then
                    -- Toggle auto-allocate
                    comp.autoAllocate = not comp.autoAllocate
                    return
                end
            end
        end
        -- Don't return here - let P key toggle and other handlers run
    end

    -- Skill tree navigation
    if state.showSkillTree then
        local tree = Data.SKILL_TREES and Data.SKILL_TREES.universal
        if tree then
            if key == "up" or key == "w" then
                state.selectedSkillIndex = navigateNodeGraph(tree, state.selectedSkillIndex or 1, "up")
            elseif key == "down" or key == "s" then
                state.selectedSkillIndex = navigateNodeGraph(tree, state.selectedSkillIndex or 1, "down")
            elseif key == "left" or key == "a" then
                state.selectedSkillIndex = navigateNodeGraph(tree, state.selectedSkillIndex or 1, "left")
            elseif key == "right" or key == "d" then
                state.selectedSkillIndex = navigateNodeGraph(tree, state.selectedSkillIndex or 1, "right")
            elseif key == "return" or key == "space" then
                local node = tree.nodes[state.selectedSkillIndex]
                if node then
                    local p = state.player
                    if not p.unlockedSkills then p.unlockedSkills = {start = true} end
                    local isUnlocked = p.unlockedSkills[node.id]
                    if not isUnlocked and node.cost > 0 then
                        local canUnlock = (p.skillPoints or 0) >= node.cost
                        -- Check graph adjacency: at least one connected node must be unlocked
                        if canUnlock then
                            local hasAdjacentUnlocked = false
                            for _, connId in ipairs(node.connections or {}) do
                                if p.unlockedSkills[connId] then
                                    hasAdjacentUnlocked = true
                                    break
                                end
                            end
                            if not hasAdjacentUnlocked then canUnlock = false end
                        end
                        if canUnlock then
                            p.skillPoints = p.skillPoints - node.cost
                            p.unlockedSkills[node.id] = true
                            log("Unlocked: " .. node.name .. "!", {0.3, 0.9, 0.5})
                        end
                    end
                end
            end
        end
        return
    end

    -- Talent selection navigation
    if state.showTalentSelection then
        local p = state.player
        local availableTalents = {}
        for _, t in ipairs(Data.UNIVERSAL_TALENTS) do
            if t.level <= p.level then
                local owned = p.talents and p.talents[t.id]
                if not owned then
                    table.insert(availableTalents, {talent = t, type = "universal"})
                end
            end
        end
        if Data.CLASS_TALENTS[p.class.id] then
            for _, t in ipairs(Data.CLASS_TALENTS[p.class.id]) do
                if t.level <= p.level then
                    local owned = p.talents and p.talents[t.id]
                    if not owned then
                        table.insert(availableTalents, {talent = t, type = "class"})
                    end
                end
            end
        end

        local talentCount = math.min(5, #availableTalents)
        if key == "up" or key == "w" then
            state.selectedTalentIndex = math.max(1, (state.selectedTalentIndex or 1) - 1)
        elseif key == "down" or key == "s" then
            state.selectedTalentIndex = math.min(talentCount, (state.selectedTalentIndex or 1) + 1)
        elseif key == "return" or key == "space" then
            -- Select talent
            local entry = availableTalents[state.selectedTalentIndex]
            if entry then
                if not p.talents then p.talents = {} end
                p.talents[entry.talent.id] = true
                p.pendingTalentSelection = false
                log("Gained talent: " .. entry.talent.name .. "!", {0.9, 0.7, 0.2})
                F.calculateStats()
                state.showTalentSelection = false
            end
        end
        return
    end

    -- Ascension tree navigation
    if state.showAscensionTree then
        local skillCount = #Data.ASCENSION_TREE
        local scrollStep = 120

        if key == "up" or key == "w" then
            state.selectedAscensionIndex = math.max(1, (state.selectedAscensionIndex or 1) - 1)
        elseif key == "down" or key == "s" then
            state.selectedAscensionIndex = math.min(skillCount, (state.selectedAscensionIndex or 1) + 1)
        elseif key == "left" then
            state.selectedAscensionIndex = math.max(1, (state.selectedAscensionIndex or 1) - 2)
        elseif key == "right" then
            state.selectedAscensionIndex = math.min(skillCount, (state.selectedAscensionIndex or 1) + 2)
        elseif key == "pageup" then
            state.ascensionScrollOffset = math.max(0, (state.ascensionScrollOffset or 0) - scrollStep)
        elseif key == "pagedown" then
            local maxScroll = state.maxAscensionScroll or 500
            state.ascensionScrollOffset = math.min(maxScroll, (state.ascensionScrollOffset or 0) + scrollStep)
        elseif key == "a" then
            local skill = Data.ASCENSION_TREE[state.selectedAscensionIndex]
            if skill then
                local success = F.rankUpAscensionSkill(skill.id, "A")
                if success then
                    F.calculateStats()
                end
            end
        elseif key == "b" then
            local skill = Data.ASCENSION_TREE[state.selectedAscensionIndex]
            if skill then
                local success = F.rankUpAscensionSkill(skill.id, "B")
                if success then
                    F.calculateStats()
                end
            end
        end
        return
    end

    -- Block other input when character sheet is open
    if state.showCharacterSheet then
        return
    end

    if key == "escape" then
        -- Cancel auto-travel if active
        if AutoTravel and AutoTravel.state.active then
            AutoTravel.cancelTravel("Cancelled by player")
            return
        end

        if state.phase == "inventory" or state.phase == "shop" or state.phase == "quest_log" or
           state.phase == "npc_list" or state.phase == "job_board" or state.phase == "stable" or
           state.phase == "guild" or state.phase == "party" or state.phase == "market" or
           state.phase == "lockpick_prompt" or state.phase == "burglary_success" then
            state.lockpickTarget = nil
            state.lockpickState = nil
            state.burglaryLoot = nil
            state.phase = "town"
        elseif state.phase == "traveling_home" then
            F.cancelTravelingHome()
        elseif state.phase == "paid_travel" then
            F.cancelPaidTravel()
        elseif state.phase == "dialogue" then
            state.phase = "town"
        elseif state.phase == "dungeon" then
            -- Leave dungeon if at entrance on floor 1
            if state.dungeon and state.dungeon.currentFloor == 1 then
                local floor = state.dungeon.floors[1]
                local tile = floor.grid[state.dungeon.playerY] and floor.grid[state.dungeon.playerY][state.dungeon.playerX]
                if tile and tile.type == "entrance" then
                    F.exitDungeon()
                end
            end
        elseif state.phase ~= "combat" and state.phase ~= "class_select" then
            -- Save and exit for map, town, camp, and other phases
            TextRPG.save()
            GameState.current = "menu"
        end
    end

    -- Arrow keys for map navigation
    if state.phase == "map" then
        -- Auto-travel menu
        if AutoTravel and AutoTravel.menuOpen then
            if AutoTravel.handleTravelMenuInput(key) then
                return
            end
        elseif key == "t" and not AutoTravel.state.active then
            -- Open travel menu
            if AutoTravel then
                AutoTravel.openTravelMenu()
            end
            return
        end

        if key == "up" or key == "w" then
            F.movePlayer(0, -1)
        elseif key == "down" or key == "s" then
            F.movePlayer(0, 1)
        elseif key == "left" or key == "a" then
            F.movePlayer(-1, 0)
        elseif key == "right" or key == "d" then
            F.movePlayer(1, 0)
        elseif key == "e" and state.pendingDungeon then
            -- Enter pending dungeon
            F.enterDungeon(state.pendingDungeon.x, state.pendingDungeon.y, state.pendingDungeon.isWaterDungeon)
            state.pendingDungeon = nil
        end
    end

    -- Town navigation
    if state.phase == "town" then
        if key == "up" or key == "w" then
            F.moveTownPlayer(0, -1)
        elseif key == "down" or key == "s" then
            F.moveTownPlayer(0, 1)
        elseif key == "left" or key == "a" then
            F.moveTownPlayer(-1, 0)
        elseif key == "right" or key == "d" then
            F.moveTownPlayer(1, 0)
        elseif key == "return" or key == "space" or key == "e" then
            -- Try building first, then NPC interaction
            local building = F.getTownBuildingAt(state.townPlayerX, state.townPlayerY)
            if building then
                F.enterCurrentTownBuilding()
            else
                -- No building - check for adjacent NPC to talk to
                local npc, npcType = TownNPCsVisible.getAdjacentNPC(state.townPlayerX, state.townPlayerY)
                if npc then
                    TownNPCsVisible.interactWithNPC(npc, npcType)
                end
            end
        elseif key == "i" then
            state.phase = "inventory"
        elseif key == "q" then
            state.phase = "quest_log"
        elseif key == "t" then
            state.phase = "party"
        elseif key == "v" then
            -- Toggle sprite mode
            local enabled = toggleSpriteMode()
            log(enabled and "Sprite mode enabled (WIP)" or "ASCII mode enabled", {0.7, 0.7, 0.9})
        end
    end

    -- Building interior navigation
    if state.phase == "building_interior" then
        if key == "up" or key == "w" then
            F.moveBuildingPlayer(0, -1)
        elseif key == "down" or key == "s" then
            F.moveBuildingPlayer(0, 1)
        elseif key == "left" or key == "a" then
            F.moveBuildingPlayer(-1, 0)
        elseif key == "right" or key == "d" then
            F.moveBuildingPlayer(1, 0)
        elseif key == "e" or key == "return" or key == "space" then
            -- Talk to NPC if adjacent
            if state.buildingInteriorNearNPC then
                state.selectedNPC = state.buildingInteriorNearNPC
                state.phase = "npc_dialogue"
            -- Loot chest if adjacent
            elseif state.buildingInteriorNearChest then
                F.lootBuildingChest(state.buildingInteriorNearChest)
            end
        elseif key == "escape" then
            -- Leave building
            state.buildingInterior = nil
            state.phase = "town"
            log("You leave the building.", {0.6, 0.6, 0.7})
        end
    end

    -- Lockpick prompt
    if state.phase == "lockpick_prompt" then
        if key == "1" or key == "return" then
            state.lockpickState = nil
            state.phase = "lockpicking"
            log("You kneel down and examine the lock...", {0.6, 0.6, 0.5})
        elseif key == "2" or key == "escape" then
            state.lockpickTarget = nil
            state.phase = "town"
            log("You decide not to risk it.", {0.6, 0.6, 0.7})
        end
    end

    -- Lockpicking minigame
    if state.phase == "lockpicking" then
        if key == "space" or key == "return" then
            F.attemptLockpick()
        elseif key == "escape" then
            state.lockpickState = nil
            state.lockpickTarget = nil
            state.phase = "town"
            log("You give up on the lock.", {0.6, 0.5, 0.5})
        end
    end

    -- Jail options
    if state.phase == "jail" then
        if key == "1" and state.jailState and state.jailState.canAffordFine then
            local fine = state.jailState.fine
            state.player.gold = state.player.gold - fine
            log("You paid " .. fine .. "g and were released.", {0.8, 0.8, 0.4})
            state.jailState = nil
            state.lockpickTarget = nil
            state.phase = "town"
            TextRPG.save()
        elseif key == "2" and state.jailState then
            local hours = state.jailState.sentence
            state.timeOfDay = (state.timeOfDay + hours) % 24
            local daysServed = math.floor(hours / 24)
            for i = 1, daysServed do
                state.daysPassed = state.daysPassed + 1
                F.onNewDay(state.daysPassed)
            end
            log("You served " .. hours .. " hours in jail and were released.", {0.6, 0.6, 0.7})
            state.jailState = nil
            state.lockpickTarget = nil
            state.phase = "town"
            TextRPG.save()
        elseif key == "3" then
            if math.random() < Data.JAIL_CONFIG.escapeChance then
                log("You slipped past the guards and escaped!", {0.5, 0.9, 0.5})
                state.jailState = nil
                state.lockpickTarget = nil
                state.phase = "town"
            else
                state.jailState.sentence = state.jailState.sentence + Data.JAIL_CONFIG.escapeConsequence
                log("Caught! Your sentence has been extended by " .. Data.JAIL_CONFIG.escapeConsequence .. " hours!", {0.9, 0.4, 0.4})
            end
        end
    end

    -- Burglary success
    if state.phase == "burglary_success" then
        if key == "return" or key == "space" or key == "escape" then
            state.burglaryLoot = nil
            state.lockpickTarget = nil
            state.phase = "town"
        end
    end

    -- Dungeon navigation
    if state.phase == "dungeon" then
        if key == "up" or key == "w" then
            F.moveDungeonPlayer(0, -1)
        elseif key == "down" or key == "s" then
            F.moveDungeonPlayer(0, 1)
        elseif key == "left" or key == "a" then
            F.moveDungeonPlayer(-1, 0)
        elseif key == "right" or key == "d" then
            F.moveDungeonPlayer(1, 0)
        elseif key == "i" then
            state.phase = "inventory"
            state.combat.returnTo = "dungeon"
        elseif key == "b" then
            -- Open full backpack directly from dungeon
            Backpack.toggle()
        elseif key == "space" then
            -- Use stairs, portals, or other interactive tiles
            if state.dungeon then
                local floor = state.dungeon.floors[state.dungeon.currentFloor]
                local tile = floor.grid[state.dungeon.playerY] and floor.grid[state.dungeon.playerY][state.dungeon.playerX]
                if tile then
                    -- Check for hollow earth portal first
                    if tile.type == "hollow_portal" and tile.portalData then
                        F.enterHollowEarthPortal(tile.portalData)
                        return
                    elseif tile.type == "stairs_down" and state.dungeon.currentFloor < state.dungeon.totalFloors then
                        state.dungeon.currentFloor = state.dungeon.currentFloor + 1
                        local nextFloor = state.dungeon.floors[state.dungeon.currentFloor]
                        state.dungeon.playerX = nextFloor.entranceX
                        state.dungeon.playerY = nextFloor.entranceY
                        nextFloor.grid[state.dungeon.playerY][state.dungeon.playerX].explored = true
                        log("You descend to floor " .. state.dungeon.currentFloor .. "...", {0.5, 0.6, 0.8})
                        -- Explore around new position
                        for dy = -1, 1 do
                            for dx = -1, 1 do
                                local nx, ny = state.dungeon.playerX + dx, state.dungeon.playerY + dy
                                if nextFloor.grid[ny] and nextFloor.grid[ny][nx] then
                                    nextFloor.grid[ny][nx].explored = true
                                end
                            end
                        end
                    elseif tile.type == "stairs_up" and state.dungeon.currentFloor > 1 then
                        state.dungeon.currentFloor = state.dungeon.currentFloor - 1
                        local prevFloor = state.dungeon.floors[state.dungeon.currentFloor]
                        state.dungeon.playerX = prevFloor.exitX
                        state.dungeon.playerY = prevFloor.exitY
                        log("You ascend to floor " .. state.dungeon.currentFloor .. "...", {0.6, 0.8, 0.5})
                    end
                end
            end
        end
    end

    -- Combat shortcuts
    if state.phase == "combat" and state.combat.isPlayerTurn then
        if key == "1" then
            F.playerAttack()
        elseif key == "2" then
            state.combat.showSkills = not state.combat.showSkills
        elseif key == "left" or key == "a" then
            -- Select previous enemy
            local newTarget = state.combat.selectedTarget - 1
            while newTarget >= 1 do
                if state.combat.enemies[newTarget] and state.combat.enemies[newTarget].hp > 0 then
                    state.combat.selectedTarget = newTarget
                    break
                end
                newTarget = newTarget - 1
            end
        elseif key == "right" or key == "d" then
            -- Select next enemy
            local newTarget = state.combat.selectedTarget + 1
            while newTarget <= #state.combat.enemies do
                if state.combat.enemies[newTarget] and state.combat.enemies[newTarget].hp > 0 then
                    state.combat.selectedTarget = newTarget
                    break
                end
                newTarget = newTarget + 1
            end
        elseif key == "tab" then
            -- Cycle to next living enemy
            local start = state.combat.selectedTarget
            local newTarget = start
            repeat
                newTarget = newTarget + 1
                if newTarget > #state.combat.enemies then newTarget = 1 end
                if state.combat.enemies[newTarget] and state.combat.enemies[newTarget].hp > 0 then
                    state.combat.selectedTarget = newTarget
                    break
                end
            until newTarget == start
        end
    end

    -- Auto-party toggle key (works during any combat phase)
    if state.phase == "combat" and key == "t" and state.player and state.player.party and #state.player.party > 0 then
        local allAuto = true
        for _, c in ipairs(state.player.party) do
            if not c.autoBattle then allAuto = false; break end
        end
        for _, c in ipairs(state.player.party) do
            c.autoBattle = not allAuto
        end
        local log = F and F.log or function() end
        log("Auto Party: " .. (not allAuto and "ON" or "OFF"), {0.5, 0.9, 0.5})
    end

    -- Manual companion turn shortcuts
    if state.phase == "combat" and state.combat.isCompanionTurn
       and state.player and state.player.manualPartyControl ~= false
       and not (state.combat.currentCompanionIndex and state.player.party
           and state.player.party[state.combat.currentCompanionIndex]
           and state.player.party[state.combat.currentCompanionIndex].autoBattle) then
        if key == "1" then
            F.companionAttackTarget()
        elseif key == "2" then
            F.companionDefend()
        elseif key == "3" then
            -- Toggle auto-battle for current companion
            local comp = state.player.party[state.combat.currentCompanionIndex]
            if comp then
                comp.autoBattle = not comp.autoBattle
                if comp.autoBattle then F.companionTurn() end
            end
        elseif key == "4" then
            -- Set all companions to auto-battle and execute current turn
            if state.player.party then
                for _, c in ipairs(state.player.party) do
                    c.autoBattle = true
                end
            end
            F.companionTurn()
        elseif key == "left" or key == "a" then
            local newTarget = state.combat.selectedTarget - 1
            while newTarget >= 1 do
                if state.combat.enemies[newTarget] and state.combat.enemies[newTarget].hp > 0 then
                    state.combat.selectedTarget = newTarget
                    break
                end
                newTarget = newTarget - 1
            end
        elseif key == "right" or key == "d" then
            local newTarget = state.combat.selectedTarget + 1
            while newTarget <= #state.combat.enemies do
                if state.combat.enemies[newTarget] and state.combat.enemies[newTarget].hp > 0 then
                    state.combat.selectedTarget = newTarget
                    break
                end
                newTarget = newTarget + 1
            end
        elseif key == "tab" then
            local start = state.combat.selectedTarget
            local newTarget = start
            repeat
                newTarget = newTarget + 1
                if newTarget > #state.combat.enemies then newTarget = 1 end
                if state.combat.enemies[newTarget] and state.combat.enemies[newTarget].hp > 0 then
                    state.combat.selectedTarget = newTarget
                    break
                end
            until newTarget == start
        end
    end
end

-- ============================================================================
-- TEXTINPUT
-- ============================================================================
function M.textinput(text)
    -- === CHATBOT FREE TALK TEXT INPUT ===
    if F.isFreeTalkActive and F.isFreeTalkActive() then
        F.freeTalkTextinput(text)
        return
    end

    -- Handle text input for dev mode password
    if state.showDevModePrompt then
        if not state.devModePassword then
            state.devModePassword = ""
        end
        -- Limit password length to 20 characters
        if #state.devModePassword < 20 then
            state.devModePassword = state.devModePassword .. text
            state.devModePasswordError = false  -- Clear error on new input
        end
        return
    end

    -- Handle text input for character name during class selection
    if state.phase == "class_select" then
        if not state.playerNameInput then
            state.playerNameInput = ""
        end
        -- Limit name length to 20 characters
        if #state.playerNameInput < 20 then
            state.playerNameInput = state.playerNameInput .. text
        end
    end
end

-- ============================================================================
-- GETUIREGION
-- ============================================================================
function M.getUIRegion(regionId)
    local screenW, screenH = love.graphics.getDimensions()

    -- Content area calculations (from draw function)
    local panelW = 120
    local contentX = panelW + 25
    local contentY = 10
    local contentW = screenW - contentX - 15
    local contentH = screenH - 75

    local regions = {
        -- Class selection card (step 2 of character creation)
        class_select = {
            x = contentX + (contentW - 600) / 2,
            y = contentY + 110,
            w = 600,
            h = 450
        },

        -- Combat action menu (bottom action buttons in combat)
        combat_menu = {
            x = contentX + 15,
            y = contentY + contentH - 70 + 24,
            w = contentW - 90,
            h = 45
        },

        -- Inventory/Equipment display (left side of inventory screen)
        inventory = {
            x = contentX + 20,
            y = contentY + 45,
            w = 240,
            h = 400
        },

        -- Shop button (building in town grid)
        shop_button = {
            x = contentX + 20,
            y = contentY + 45,
            w = 100,
            h = 100
        }
    }

    return regions[regionId]
end

return M
