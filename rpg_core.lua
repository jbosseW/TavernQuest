-- RPG Core - TextRPG Lifecycle & Utility Functions
-- Extracted from textrpg.lua
-- Contains: TextRPG.init, TextRPG.update, TextRPG.draw, resetGame,
-- calendar helpers, NPC/time helpers, portrait helpers, small utilities.

local Data = require("rpg_data")
local UI = require("ui")
local UIAssets = require("uiassets")
local Backpack = require("backpack")
local AutoPlay = require("autoplay")
local AutoTravel = require("auto_travel")
local LPCLoader = require("lpcloader")
local LPCTilemap = require("lpc_tilemap")
local PropertySystem = require("propertysystem")
local WorldMapOverlay = require("worldmapoverlay")
local MapEnemies = require("mapenemies")
local DungeonEnemies = require("dungeonenemies")
local TownNPCsVisible = require("townnpcsvisible")
local PrisonEscape = require("prison_escape")
local InteractiveTutorial = require("interactivetutorial")
local LuminaryPatrols = require("luminarypatrols")

local M = {}

-- Upvalues set by register()
local state
local F
local TextRPG

-- Tactical combat references (set during register via deps)
local TacticalCombat
local TacticalUI
local TacticalAI
local tacticalStateRef    -- function returning current tacticalState
local setTacticalState    -- function to set tacticalState
local getTacticalMode     -- function returning current TACTICAL_MODE
local setTacticalMode     -- function to set TACTICAL_MODE

-- Data references (set during register from textrpg locals)
local ENEMIES
local STEALTH_TIME_MODIFIERS
local JOURNAL_TABS
local REGIONAL_NPC_POOLS

-- Module references
local StealthSystem = nil
pcall(function() StealthSystem = require("stealth_system") end)

-- Simple sprite mode toggle (for LPC sprites)
local spriteMode = false

-- Functions to register on F
M.F_FUNCTIONS = {
    "getFont", "getPortraitImage", "getCreationPortrait",
    "getNPCCurrentLocation", "updateNPCStates",
    "getTimeOfDayPeriod", "getTimeOfDayLighting", "getTimeIcon",
    "hasPassive", "resetGame", "drawPlayerSprite",
}

function M.register(s, f, rpg, deps)
    state = s
    F = f
    TextRPG = rpg

    -- Optional deps table for textrpg locals not accessible through F/_G
    if deps then
        TacticalCombat = deps.TacticalCombat
        TacticalUI = deps.TacticalUI
        TacticalAI = deps.TacticalAI
        tacticalStateRef = deps.getTacticalState
        setTacticalState = deps.setTacticalState
        getTacticalMode = deps.getTacticalMode
        setTacticalMode = deps.setTacticalMode
        ENEMIES = deps.ENEMIES
        STEALTH_TIME_MODIFIERS = deps.STEALTH_TIME_MODIFIERS
        JOURNAL_TABS = deps.JOURNAL_TABS
        REGIONAL_NPC_POOLS = deps.REGIONAL_NPC_POOLS
    end

    for _, name in ipairs(M.F_FUNCTIONS) do
        if M[name] then F[name] = M[name] end
    end
end

local function log(text, color)
    if F and F.log then F.log(text, color)
    elseif state and state.textLog then
        table.insert(state.textLog, {text = text, color = color or {0.8,0.8,0.8}, time = love.timer.getTime()})
        if #state.textLog > 100 then table.remove(state.textLog, 1) end
    end
end

-- Helper to get current tacticalState (mutable local in textrpg.lua)
local function getTacticalState()
    if tacticalStateRef then return tacticalStateRef() end
    return nil
end

-- Helper to get current TACTICAL_MODE flag
local function isTacticalMode()
    if getTacticalMode then return getTacticalMode() end
    return false
end

-- ============================================================================
-- SMALL UTILITY HELPERS
-- ============================================================================

M.getFont = function(size)
    return UI.fonts.get(size)
end
local getFont = M.getFont

local function toggleSpriteMode()
    spriteMode = not spriteMode
    return spriteMode
end

local function isSpriteEnabled()
    return spriteMode
end

local function drawPlayerSprite(x, y, fallbackFn)
    if RENDER_MODE == "sprite" then
        -- Draw a sprite-style character indicator (circle with head)
        -- Shadow
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.ellipse("fill", x, y + 10, 14, 5)
        -- Body
        love.graphics.setColor(0.15, 0.55, 0.25, 0.7)
        love.graphics.circle("fill", x, y, 14)
        local pulse = 0.7 + 0.3 * math.sin(love.timer.getTime() * 3)
        love.graphics.setColor(0.3, 0.9 * pulse, 0.4, 0.95)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", x, y, 14)
        -- Head
        love.graphics.setColor(0.4, 0.95, 0.5, 0.9)
        love.graphics.circle("fill", x, y - 8, 6)
        love.graphics.setColor(0.3, 0.9, 0.4)
        love.graphics.circle("line", x, y - 8, 6)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, 1)
    else
        if fallbackFn then fallbackFn() end
    end
end
M.drawPlayerSprite = drawPlayerSprite

M.getPortraitImage = function(id)
    local portraitMappings = Data.portraitMappings
    local portraitName = portraitMappings[id]
    if portraitName then
        return UIAssets.getCharacter(portraitName)
    end
    return nil
end
local getPortraitImage = M.getPortraitImage

-- Get portrait for character creation based on class, gender, and index
M.getCreationPortrait = function(classId, gender, index)
    local CLASS_PORTRAIT_OPTIONS = Data.CLASS_PORTRAIT_OPTIONS
    local options = CLASS_PORTRAIT_OPTIONS[classId]
    if not options then return nil end

    local genderOptions = options[gender:lower()]
    if not genderOptions or #genderOptions == 0 then return nil end

    -- Wrap index around if out of bounds
    local wrappedIndex = ((index - 1) % #genderOptions) + 1
    local portraitName = genderOptions[wrappedIndex]

    -- Determine folder path based on gender
    local folder = gender:lower() == "male" and "Human/Men_Human" or "Human/Women_Human"
    local fullPath = folder .. "/" .. portraitName

    return UIAssets.getCharacter(fullPath), wrappedIndex, #genderOptions
end

-- ============================================================================
-- hasPassive HELPER
-- ============================================================================

M.hasPassive = function(player, passiveId)
    if not player or not player.background or not player.background.passives then return false end
    for _, pid in ipairs(player.background.passives) do
        if pid == passiveId then return true end
    end
    return false
end
local hasPassive = M.hasPassive

-- ============================================================================
-- NPC/TIME HELPERS
-- ============================================================================

M.getNPCCurrentLocation = function(npc)
    if not npc or not npc.race then
        return {location = "work", activity = "working"}
    end

    -- Initialize schedule if not exists
    if not npc.schedule then
        npc.schedule = F.getNPCSchedule(npc.profession, npc.race)
    end

    local hour = math.floor(state.timeOfDay or 12)
    return npc.schedule[hour] or {location = "work", activity = "working"}
end

-- Update NPC state based on time of day
M.updateNPCStates = function()
    if not state.world or not state.world.currentTown then return end
    local town = state.world.currentTown

    for _, npc in ipairs(town.npcs) do
        -- Initialize race if not set
        if not npc.race then
            -- Assign race based on profession or region
            if npc.profession.id == "elder" then
                npc.race = "human"  -- Elders are typically human
            else
                -- Region-aware race distribution
                local region = town.region
                local pool = REGIONAL_NPC_POOLS and REGIONAL_NPC_POOLS[region] or {"human","human","human","dwarf","elf","gnome","orc"}
                npc.race = pool[math.random(#pool)]
            end
        end

        -- Update current state
        local currentState = F.getNPCCurrentLocation(npc)
        npc.currentLocation = currentState.location
        npc.currentActivity = currentState.activity
        npc.isAsleep = F.isNPCAsleep(npc)
    end
end

-- === DAY/NIGHT VISUAL SYSTEM ===

-- Get time of day period
M.getTimeOfDayPeriod = function()
    local hour = state.timeOfDay or 12

    if hour >= 5 and hour < 7 then
        return "dawn"
    elseif hour >= 7 and hour < 12 then
        return "morning"
    elseif hour >= 12 and hour < 17 then
        return "afternoon"
    elseif hour >= 17 and hour < 20 then
        return "evening"
    elseif hour >= 20 and hour < 22 then
        return "dusk"
    else
        return "night"
    end
end
local getTimeOfDayPeriod = M.getTimeOfDayPeriod

-- Get lighting color based on time of day
M.getTimeOfDayLighting = function()
    local period = getTimeOfDayPeriod()

    if period == "dawn" then
        return {r = 1.0, g = 0.8, b = 0.6, brightness = 0.7}  -- Orange glow
    elseif period == "morning" then
        return {r = 1.0, g = 1.0, b = 0.95, brightness = 1.0}  -- Bright daylight
    elseif period == "afternoon" then
        return {r = 1.0, g = 1.0, b = 1.0, brightness = 1.0}  -- Full daylight
    elseif period == "evening" then
        return {r = 1.0, g = 0.9, b = 0.7, brightness = 0.8}  -- Warm light
    elseif period == "dusk" then
        return {r = 0.8, g = 0.6, b = 0.7, brightness = 0.5}  -- Purple dusk
    else  -- night
        return {r = 0.3, g = 0.4, b = 0.6, brightness = 0.3}  -- Blue moonlight
    end
end

-- Get time icon
M.getTimeIcon = function()
    local period = getTimeOfDayPeriod()
    local icons = {
        dawn = "\xF0\x9F\x8C\x85",
        morning = "\xE2\x98\x80\xEF\xB8\x8F",
        afternoon = "\xF0\x9F\x8C\x9E",
        evening = "\xF0\x9F\x8C\x86",
        dusk = "\xF0\x9F\x8C\x87",
        night = "\xF0\x9F\x8C\x99"
    }
    return icons[period] or "\xE2\x8F\xB0"
end

-- ============================================================================
-- RESET GAME
-- ============================================================================

M.resetGame = function()
    -- Reset game state for new adventure (preserves graveyard)
    state.phase = "class_select"
    state.player = nil

    -- Reset gold/coins to starting amount
    PlayerData.coins = 50  -- Starting gold for new character

    -- Clear the saved TextRPG data so fresh start
    PlayerData.textRPG = nil
    PlayerData.textRPGWorldGen = nil  -- Clear world generation data
    PlayerData.textRPGLichLairs = nil  -- Clear lich lair data

    -- Reset backpack for new character
    Backpack.reset()  -- Clear items and re-initialize with default state
    state.world = {
        mapData = {},
        mapWidth = 15,
        mapHeight = 15,
        towns = {},
        currentTown = nil,
        playerX = 7,
        playerY = 7,
        homeTown = nil,  -- The starting town
        pathHistory = {},  -- Path taken from home: {{x=, y=}, ...}
        mapEnemies = {},  -- Visible enemies on the world map
        mapEnemiesDefeated = 0,  -- Counter for defeated map enemies
    }
    state.travelingHome = {
        active = false,
        pathIndex = 0,
        timer = 0,
        stepDelay = 0.4,  -- Seconds between steps (base, adjusted by mount)
        speedMult = 1.0,  -- Speed multiplier from mounts
        timePerTile = 1.0,  -- In-game hours per tile (adjusted by mount)
    }
    state.paidTravel = {
        active = false,
        destination = nil,
        destX = 0,
        destY = 0,
        timer = 0,
        stepDelay = 0.2,
        totalSteps = 0,
        currentStep = 0,
        encounterChance = 0.01,
        speedMult = 2.0,
        timePerTile = 0.5,
    }
    state.combat = {
        enemies = {},
        selectedTarget = 1,
        turnOrder = {},
        currentTurnIndex = 0,
        isPlayerTurn = true,
        log = {},
        showSkills = false,
        showWeaponSwap = false,
    }
    state.dialogue = {
        npc = nil,
        text = "",
        options = {},
    }
    state.scroll = 0
    state.textLog = {}
    state.stats = {
        enemiesDefeated = 0,
        questsCompleted = 0,
        goldEarned = 0,
        itemsFound = 0,
        -- Additional stats for race unlocks
        healingDone = 0,
        itemsCrafted = 0,
        stealthKills = 0,
        fishCaught = 0,
        deaths = 0,
        locationsVisited = {},
    }
    state.deathInfo = {
        killedBy = nil,
        location = nil,
    }
    state.timeOfDay = 12
    state.daysPassed = 0
    state.season = "frosthollow"  -- Deepmere = Frosthollow
    state.seasonIndex = 4
    state.weather = {
        current = "pleasant",
        hoursExposed = 0,  -- Hours spent in bad weather without shelter
        sheltered = false,
        shelterType = nil,
        lastUpdate = 0,
    }
    state.camping = {
        active = false,
        type = nil,
        hoursRested = 0,
        -- Camp activity system
        guard = nil,           -- nil = no guard, "player" or companion name
        guardIndex = nil,      -- Index of companion on guard (nil if player)
        campfireLit = false,
        cookedMeals = {},      -- Prepared food bonuses
        chatHistory = {},      -- Recent chat log
        activity = "main",     -- "main", "cooking", "chat", "rest", "guard"
        morale = 50,           -- 0-100, affects chat quality and rest
        lastAmbushCheck = 0,
    }
    state.tradeRoutes = {}
    state.playerGoods = {}
    state.marketTab = "buy"
    state.dungeon = nil
    state.inDungeon = false
    state.prisonEscape = nil
    state.inPrisonEscape = false
    log("Choose your class to begin a new adventure.", {0.7, 0.7, 0.9})
end
local resetGame = M.resetGame

-- ============================================================================
-- CALENDAR HELPERS
-- ============================================================================

-- Seasons table (lore names for display, internal keys for logic)
local SEASONS = Data.SEASONS
local SEASON_DISPLAY = Data.SEASON_DISPLAY
local MONTHS = Data.MONTHS
local DAYS_PER_YEAR = Data.DAYS_PER_YEAR

-- Convert daysPassed to calendar date {year, month, day, monthName}
local function getCalendarDate(daysPassed)
    local totalDays = daysPassed
    local year = 1
    while totalDays >= DAYS_PER_YEAR do
        totalDays = totalDays - DAYS_PER_YEAR
        year = year + 1
    end
    local month = 1
    for i = 1, 12 do
        if totalDays < MONTHS[i].days then
            month = i
            break
        end
        totalDays = totalDays - MONTHS[i].days
    end
    return {
        year = year,
        month = month,
        day = totalDays + 1,
        monthName = MONTHS[month].name,
    }
end

-- Get season from month (Thawmist-Starbloom=brightbloom, Solaren-Forgefire=sunreign, Harvestmere-Shadowmere=ashwane, Voidwatch-Ironveil=frosthollow)
local function getSeasonFromMonth(month)
    if month >= 3 and month <= 5 then return "brightbloom"
    elseif month >= 6 and month <= 8 then return "sunreign"
    elseif month >= 9 and month <= 11 then return "ashwane"
    else return "frosthollow" end
end

-- ============================================================================
-- LOCAL HELPER: initUIComponents
-- ============================================================================

local function initUIComponents()
    state.uiComponents = {}

    -- Player info panel progress bars (initialized with default values, updated in draw)
    state.uiComponents.hpBar = UI.ProgressBar.new({
        x = 20, y = 100, w = 100, h = 14,
        value = 1.0,
        colorOverride = {0.8, 0.2, 0.2}
    })

    state.uiComponents.manaBar = UI.ProgressBar.new({
        x = 20, y = 120, w = 100, h = 14,
        value = 1.0,
        colorOverride = {0.2, 0.3, 0.8}
    })

    -- Combat action buttons (created dynamically in drawCombat)
    state.uiComponents.combatButtons = {}

    -- Navigation buttons (stealth, journal, autoplay, dev cheat)
    state.uiComponents.navButtons = {}
end

-- ============================================================================
-- LOCAL HELPER: processTacticalDotDeaths
-- ============================================================================

local function processTacticalDotDeaths(tState)
    if not tState or not tState._dotDeaths then return false end
    local deaths = tState._dotDeaths
    tState._dotDeaths = nil
    for _, death in ipairs(deaths) do
        local unit = death.unit
        if unit.isEnemy and unit.data then
            F.onEnemyDefeated(unit.data)
        end
        if unit.isPlayer then
            TacticalCombat.syncToGameState(tState, state.player)
            tState.combatEnded = true
            tState.victory = false
            F.endCombat(false)
            return true
        end
    end
    if TacticalCombat.checkAllEnemiesDefeated(tState) then
        TacticalCombat.syncToGameState(tState, state.player)
        tState.combatEnded = true
        tState.victory = true
        F.endCombat(true)
        return true
    end
    return false
end

-- ============================================================================
-- TextRPG.init
-- ============================================================================

M.init = function()
    state.textLog = {}
    state.scroll = 0

    -- Play RPG exploration music
    if AudioSystem and AudioSystem.playRPGMusic then
        AudioSystem.playRPGMusic()
    end

    if TextRPG.load() then
        -- If player is dead or on death screen, auto-start new character creation
        if state.phase == "death" or (not state.player and state.phase ~= "class_select") then
            resetGame()
            state.phase = "class_select"
            state.playerNameInput = "Adventurer"
            log("Welcome to Tavern Quest!", {0.9, 0.7, 0.2})
            log("Your previous hero has fallen. Begin a new adventure!", {0.7, 0.5, 0.5})
            if PlayerData.deathStash and PlayerData.deathStash.gold and PlayerData.deathStash.gold > 0 then
                log("Your fallen hero's belongings await at the nearest guild hall.", {1, 0.85, 0.2})
            end
        else
            log("Welcome back, adventurer!", {0.5, 0.8, 1})
            F.calculateStats()

            -- Ensure gold is synced with main game on every entry
            if state.player then
                PlayerData.coins = PlayerData.coins or 0
                state.player.gold = PlayerData.coins

                -- CRITICAL FIX: Always force journal closed on load to prevent stuck overlay
                if state.player.journal then
                    state.player.journal.isOpen = false
                end

                -- Phase 9: Restore tactical mode preference from saved settings
                if PlayerData.settings and PlayerData.settings.tacticalCombat ~= nil then
                    if setTacticalMode then setTacticalMode(PlayerData.settings.tacticalCombat) end
                    if isTacticalMode() and not TacticalCombat then
                        TacticalCombat = require("tactical_combat")
                        TacticalUI = require("tactical_combat_ui")
                        TacticalAI = require("tactical_combat_ai")
                        TacticalAI.init(TacticalCombat)
                        TacticalUI.init(TacticalCombat, getFont)
                        -- Update AutoPlay with newly loaded tactical references
                        AutoPlay.setTacticalReferences(TacticalCombat, TacticalAI, function() return getTacticalState() end, function() if setTacticalState then setTacticalState(nil) end end)
                    end
                end
            end
        end
    else
        state.phase = "class_select"
        state.playerNameInput = "Adventurer"  -- Reset name input for new character

        -- CRITICAL FIX: Force close journal during character creation
        if state.player and state.player.journal then
            state.player.journal.isOpen = false
        end

        log("Welcome to Tavern Quest!", {0.9, 0.7, 0.2})
        log("Enter your name and choose a class to begin.", {0.7, 0.7, 0.7})
    end

    -- Register UI region resolver for interactive tutorial
    InteractiveTutorial.registerRegionResolver("textrpg", TextRPG.getUIRegion)

    -- Initialize RumorSystem once at startup (not in update loops)
    local RumorSystem = require("rumorsystem")
    RumorSystem.init(state)

    -- Initialize PropertySystem
    PropertySystem.init(state)

    -- Initialize Luminary Patrols system
    LuminaryPatrols.init(state)
    LuminaryPatrols.setStartCombatFunction(F.startCombat)
    -- Expose LuminaryPatrols module on F so draw modules (rpg_draw_world) can access it
    F.LuminaryPatrols = LuminaryPatrols

    -- Initialize Map Enemies system (visible enemies on world map)
    MapEnemies.init(state, {
        generateEncounter = F.generateEncounter,
        createEnemyInstance = F.createEnemyInstance,
        startCombat = F.startCombat,
        getTileType = F.getTileType,
        getEnemiesTable = function() return ENEMIES or (F.getEnemiesTable and F.getEnemiesTable()) end,
    })
    -- Expose MapEnemies module on F so draw modules (rpg_draw_world) can access it
    F.MapEnemies = MapEnemies

    -- Initialize Dungeon Enemies system (visible enemies in dungeons)
    DungeonEnemies.init(state, {
        startCombat = F.startCombat,
        createEnemyInstance = F.createEnemyInstance,
        getEnemiesTable = function() return ENEMIES or (F.getEnemiesTable and F.getEnemiesTable()) end,
    })

    -- Initialize Town Visible NPCs system
    TownNPCsVisible.init(state)

    -- Load map enemies save data if present
    if PlayerData.textRPGMapEnemies then
        MapEnemies.loadSaveData(PlayerData.textRPGMapEnemies)
    end

    -- Initialize LPC Sprite Loader (optional - only loads when sprites are used)
    pcall(function()
        LPCLoader.init()
        LPCTilemap.init()
    end)

    -- CRITICAL FIX: Ensure phase is valid after load
    if state.player and (not state.phase or state.phase == "") then
        state.phase = "map"  -- Default to map if phase is missing
        log("Phase reset to map", {0.9, 0.5, 0.2})
    end

    -- Initialize UI components
    initUIComponents()
end

-- ============================================================================
-- TextRPG.update
-- ============================================================================

M.update = function(dt)
    local tacticalState = getTacticalState()
    local TACTICAL_MODE = isTacticalMode()

    -- Update UI animations
    UI.anim.update(dt)

    -- Update UI components
    if state.uiComponents then
        if state.uiComponents.hpBar then
            state.uiComponents.hpBar:update(dt)
        end
        if state.uiComponents.manaBar then
            state.uiComponents.manaBar:update(dt)
        end
        for _, btn in ipairs(state.uiComponents.combatButtons) do
            if btn and btn.update then
                btn:update(dt)
            end
        end
        for _, btn in ipairs(state.uiComponents.navButtons) do
            if btn and btn.update then
                btn:update(dt)
            end
        end
    end

    -- Update backpack UI (hover timers, scroll containers, animations)
    Backpack.update(dt)

    -- Update traveling home animation
    if state.phase == "traveling_home" and state.travelingHome and state.travelingHome.active then
        F.updateTravelingHome(dt)
    end

    -- Update paid travel animation
    if state.phase == "paid_travel" and state.paidTravel and state.paidTravel.active then
        F.updatePaidTravel(dt)
    end

    -- Update lockpicking minigame cursor
    if state.phase == "lockpicking" and state.lockpickState then
        local ls = state.lockpickState
        ls.cursorPos = ls.cursorPos + ls.speed * dt * ls.direction
        -- Bounce at edges
        if ls.cursorPos >= 1 then
            ls.cursorPos = 1
            ls.direction = -1
        elseif ls.cursorPos <= 0 then
            ls.cursorPos = 0
            ls.direction = 1
        end
    end

    -- Update vampire systems
    if state.player and state.player.isVampire then
        F.applySunlightDamage(dt)
    end

    -- Update auto-play system
    if state.autoPlay and state.autoPlay.enabled then
        AutoPlay.update(dt, state)
    end

    -- Update auto-travel system
    if AutoTravel then
        AutoTravel.update(dt, state)
    end

    -- Update chatbot free talk system
    if F.isFreeTalkActive and F.isFreeTalkActive() then
        F.updateFreeTalk(dt)
    end

    -- Update prison guard patrols
    if state.inPrisonEscape and state.dungeon and state.dungeon.isPrison then
        local currentFloor = state.dungeon.floors[state.dungeon.currentFloor]
        if currentFloor and currentFloor.guardPatrols then
            PrisonEscape.updateGuardPatrols(currentFloor.guardPatrols, dt, currentFloor)

            -- Check if a guard detects the player
            local stealthActive = state.player and state.player.stealthMode
            local detChance = stealthActive and F.calculateDetectionChance("move") or 1.0
            local detected, guard = PrisonEscape.checkGuardDetection(
                currentFloor.guardPatrols,
                state.dungeon.playerX,
                state.dungeon.playerY,
                stealthActive,
                detChance
            )
            if detected and guard then
                -- Guard encounter: start combat with the guard
                log("A " .. guard.name .. " spots you!", {0.9, 0.4, 0.4})
                local guardEnemy = {
                    name = guard.name,
                    hp = guard.hp,
                    maxHp = guard.maxHp,
                    attack = guard.atk,
                    defense = guard.def,
                    xpReward = guard.xp,
                    goldReward = guard.gold,
                    level = 3,
                    -- Prison guard data for post-combat handling
                    isPrisonGuard = true,
                    prisonDrops = guard.drops,
                }
                guard.alerted = true   -- Stop patrol while in combat
                guard.inCombat = true   -- Prevent re-detection during combat
                -- Store reference to actual guard so we can update it after combat
                state.dungeon.currentPrisonGuard = guard
                F.startCombat({guardEnemy})
            end
        end
    end

    -- LPC sprites don't need update (static or handled by character system)

    -- Check for player death (outside of combat)
    if state.player and state.player.hp <= 0 and state.phase ~= "combat" and state.phase ~= "death" then
        -- In prison: knocked out and dragged to cell instead of dying
        if state.inPrisonEscape and state.prisonEscape then
            state.player.hp = math.max(1, math.floor((state.player.maxHP or 100) * 0.25))
            local msg = PrisonEscape.onGuardCaught(state.prisonEscape)
            if msg then log(msg, {0.9, 0.4, 0.4}) end
            log("You collapse and are dragged back to your cell...", {0.7, 0.3, 0.3})
            if state.dungeon then
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
            state.phase = "dungeon"
        else
            state.phase = "death"
            state.deathReason = state.deathReason or "Unknown causes"
            log("You have died from " .. state.deathReason .. "!", {0.9, 0.1, 0.1})
        end
    end

    -- Vampire epidemic spread (happens regardless of player vampire status)
    -- This handles NPC vampires spreading, infiltration from dens, and lair spawning
    F.updateVampireSpread(dt)

    -- Update Luminary Inquest patrols
    LuminaryPatrols.update(dt)

    -- Update visible map enemies (patrol, chase, detection)
    MapEnemies.update(dt)

    -- Check for map enemy collision with player (triggers combat)
    if state.phase == "map" and state.world and state.world.mapEnemies then
        local collidedEnemy, collidedIndex = MapEnemies.checkPlayerCollision()
        if collidedEnemy then
            MapEnemies.triggerCombat(collidedEnemy, collidedIndex)
        end
    end

    -- Update visible dungeon enemies (patrol, chase, detection)
    DungeonEnemies.update(dt)

    -- Check for dungeon enemy collision with player (triggers combat)
    if state.phase == "dungeon" and state.dungeon then
        local collidedVisEnemy, collidedVisIndex = DungeonEnemies.checkPlayerCollision()
        if collidedVisEnemy then
            DungeonEnemies.triggerCombat(collidedVisEnemy, collidedVisIndex)
        end
    end

    -- Update wandering NPCs (guards, children, cats, etc.)
    if state.phase == "town" then
        F.updateWanderingNPCs(dt)
    end

    -- Update lich blight spreading (time-based, not day-based)
    -- Spread every 5 minutes of real-time to ensure corruption happens reliably
    if not state.lichBlightTimer then
        state.lichBlightTimer = 0
    end
    state.lichBlightTimer = state.lichBlightTimer + dt
    if state.lichBlightTimer >= 300 then  -- 300 seconds = 5 minutes
        state.lichBlightTimer = 0
        local WorldGen = require("worldgen")
        local activeLiches = WorldGen.getActiveLichLairs()
        if #activeLiches > 0 then
            local battleResults = WorldGen.spreadLichBlight()

            -- Report any battles
            if battleResults and #battleResults > 0 then
                local RumorSystem = require("rumorsystem")
                RumorSystem.init(state)
                for _, battle in ipairs(battleResults) do
                    RumorSystem.onLichBattle(battle, WorldGen)

                    -- Log major battles
                    if battle.isHolyIntervention then
                        if battle.lichDestroyed then
                            log("\xF0\x9F\x93\xB0 News: Holy Battalion destroys lich threat!", {0.9, 0.9, 0.3})
                        else
                            log("\xF0\x9F\x93\xB0 News: Holy Battalion defeated by lich forces!", {0.9, 0.3, 0.3})
                        end
                    elseif battle.townName and not battle.defenderWins then
                        log("\xF0\x9F\x93\xB0 Rumor: " .. battle.townName .. " has fallen to undead!", {0.8, 0.3, 0.3})
                    end
                end
            end

            -- Log corruption level if high
            local corruption = WorldGen.getWorldCorruptionLevel()
            if corruption > 50 and math.random() < 0.1 then
                log("The world grows darker as lich corruption spreads...", {0.6, 0.3, 0.6})
            end
        end
    end

    -- Update day/night cycle (1 game hour = 30 seconds real time)
    local prevHour = math.floor(state.timeOfDay or 12)
    state.timeOfDay = state.timeOfDay + (dt / 30) * 1  -- 1 hour per 30 seconds
    local currentHour = math.floor(state.timeOfDay)

    -- Update NPC locations when hour changes
    if currentHour ~= prevHour then
        local town = state.world and state.world.currentTown
        if town then
            F.updateNPCLocations(town)
        end
    end

    if state.timeOfDay >= 24 then
        state.timeOfDay = state.timeOfDay - 24
        state.daysPassed = state.daysPassed + 1

        -- Handle daily world events (lich blight spreading, etc.)
        F.onNewDay(state.daysPassed)

        -- Update season based on calendar month
        local cal = getCalendarDate(state.daysPassed)
        local newSeason = getSeasonFromMonth(cal.month)
        if newSeason ~= state.season then
            state.season = newSeason
            state.seasonIndex = ({frosthollow=1, brightbloom=2, sunreign=3, ashwane=4})[newSeason] or 1
            log("The season has changed to " .. (SEASON_DISPLAY[state.season] or state.season) .. "!", {0.7, 0.8, 0.9})
        end

        -- Process arriving caravans
        local arrivedRoutes = {}
        for i, route in ipairs(state.tradeRoutes) do
            if state.daysPassed >= route.arrivalDay then
                -- Caravan arrived!
                if not state.playerGoods[route.destination] then
                    state.playerGoods[route.destination] = {}
                end
                state.playerGoods[route.destination][route.goodId] =
                    (state.playerGoods[route.destination][route.goodId] or 0) + route.quantity
                log("Caravan arrived in " .. route.destination .. ": " .. route.goodName .. " x" .. route.quantity, {0.5, 0.9, 0.5})
                table.insert(arrivedRoutes, i)
            end
        end
        -- Remove arrived routes (in reverse to preserve indices)
        for i = #arrivedRoutes, 1, -1 do
            table.remove(state.tradeRoutes, arrivedRoutes[i])
        end

        -- Pay daily wages to party companions
        if state.player and state.player.party and #state.player.party > 0 then
            local totalWage = 0
            for _, companion in ipairs(state.player.party) do
                totalWage = totalWage + (companion.dailyWage or 0)
            end

            if totalWage > 0 then
                if state.player.gold >= totalWage then
                    state.player.gold = state.player.gold - totalWage
                    log("Paid " .. totalWage .. " gold in party wages.", {0.8, 0.7, 0.4})
                else
                    -- Can't afford wages - companions get upset
                    log("Can't afford party wages! Companions grow restless.", {0.9, 0.4, 0.4})
                    for _, companion in ipairs(state.player.party) do
                        companion.morale = math.max(0, companion.morale - 15)
                        if companion.morale <= 0 then
                            log(companion.name .. " has left the party due to unpaid wages!", {0.9, 0.3, 0.3})
                        end
                    end
                    -- Remove companions with 0 morale
                    for i = #state.player.party, 1, -1 do
                        if state.player.party[i].morale <= 0 then
                            table.remove(state.player.party, i)
                        end
                    end
                end
            end
        end
    end

    if state.phase == "combat" and not state.combat.isPlayerTurn then
        -- When manual party control is enabled (default), companion turns are
        -- player-controlled so skip the auto-timer for companions.
        -- manualPartyControl defaults to true (nil treated as true).
        -- Per-companion autoBattle overrides manual control for that companion.
        local currentCompanionAutoBattle = false
        if state.combat.isCompanionTurn and state.combat.currentCompanionIndex then
            local comp = state.player and state.player.party and state.player.party[state.combat.currentCompanionIndex]
            if comp and comp.autoBattle then
                currentCompanionAutoBattle = true
            end
        end
        local isManualCompanionTurn = state.combat.isCompanionTurn
            and state.player and state.player.manualPartyControl ~= false
            and not currentCompanionAutoBattle
        if not isManualCompanionTurn then
            if not state.combat.turnTimer then
                state.combat.turnTimer = 0
            end
            state.combat.turnTimer = state.combat.turnTimer + dt
            -- Scale turn delay based on total combatants for faster large fights
            local totalCombatants = #state.combat.enemies + (state.player.party and #state.player.party or 0)
            local turnDelay = totalCombatants > 12 and 0.25 or (totalCombatants > 8 and 0.4 or (totalCombatants > 5 and 0.6 or 0.8))
            -- Auto-battle companions act faster than enemies
            if currentCompanionAutoBattle then
                turnDelay = math.min(turnDelay, 0.4)
            end
            if state.combat.turnTimer >= turnDelay then
                state.combat.turnTimer = nil
                if state.combat.isCompanionTurn then
                    F.companionTurn()
                else
                    F.enemyTurn()
                end
            end
        end
    end

    -- ================================================================
    -- PHASE 9: SYNC OPTIONS MENU COMBAT MODE TOGGLE
    -- ================================================================
    local Options = require("options")
    if Options._combatModeChanged then
        if setTacticalMode then setTacticalMode(Options._newTacticalMode) end
        TACTICAL_MODE = isTacticalMode()
        Options._combatModeChanged = false
        Options._newTacticalMode = nil
        -- Lazy-load modules if switching to tactical for the first time
        if TACTICAL_MODE and not TacticalCombat then
            TacticalCombat = require("tactical_combat")
            TacticalUI = require("tactical_combat_ui")
            TacticalAI = require("tactical_combat_ai")
            TacticalAI.init(TacticalCombat)
            TacticalUI.init(TacticalCombat, getFont)
            -- Update AutoPlay with newly loaded tactical references
            AutoPlay.setTacticalReferences(TacticalCombat, TacticalAI, function() return getTacticalState() end, function() if setTacticalState then setTacticalState(nil) end end)
        end
        -- Sync back to PlayerData.settings
        if PlayerData and PlayerData.settings then
            PlayerData.settings.tacticalCombat = TACTICAL_MODE
        end
    end

    -- ================================================================
    -- TACTICAL COMBAT UPDATE
    -- ================================================================
    tacticalState = getTacticalState()
    if state.phase == "tactical_combat" and TACTICAL_MODE and tacticalState then
        -- Process any pending DOT/hazard deaths from start-of-turn effects
        if tacticalState._dotDeaths and not tacticalState.combatEnded then
            if processTacticalDotDeaths(tacticalState) then
                if setTacticalState then setTacticalState(nil) end
                return
            end
        end

        -- Process AI turns (enemy and non-player-controlled companion)
        local active = tacticalState.activeUnit
        if active and not active.isPlayer and not active.isPlayerControlled and not tacticalState.combatEnded then
            if not tacticalState._aiTimer then
                tacticalState._aiTimer = 0
            end
            tacticalState._aiTimer = tacticalState._aiTimer + dt

            -- Delay before AI acts (so player can see what's happening)
            if tacticalState._aiTimer >= 0.7 then
                tacticalState._aiTimer = nil

                local results = nil
                if active.isCompanion then
                    results = TacticalAI.executeCompanionTurn(tacticalState, active)
                elseif active.isEnemy then
                    results = TacticalAI.executeEnemyTurn(tacticalState, active)
                end

                -- Log AI actions
                if results then
                    if results.moved then
                        TacticalCombat.addLog(tacticalState,
                            active.name .. " moves to (" .. active.x .. "," .. active.y .. ")",
                            active.color or {0.7, 0.7, 0.7})
                    end
                    -- Phase 7: Log stun skip
                    if results.stunned then
                        TacticalCombat.addLog(tacticalState,
                            active.name .. " is stunned and cannot act!",
                            {0.9, 0.9, 0.3})
                    end
                    if results.attacked and results.attackResult then
                        local ar = results.attackResult
                        local targetName = results.target and results.target.name or "target"
                        local msg
                        if ar.dodged then
                            msg = active.name .. " attacks " .. targetName .. " but MISSES!"
                            TacticalCombat.addLog(tacticalState, msg, {0.6, 0.6, 0.7})
                        else
                            msg = active.name .. " attacks " .. targetName .. " for " .. ar.damage .. " damage"
                            if ar.isCrit then msg = "CRITICAL! " .. msg end
                            if ar.flanked then msg = msg .. " (flanked!)" end
                            TacticalCombat.addLog(tacticalState, msg,
                                active.faction == "ally" and {0.5, 0.8, 1} or {0.9, 0.4, 0.4})
                        end

                        if ar.targetDown then
                            local downTarget = results.target
                            TacticalCombat.addLog(tacticalState,
                                downTarget.name .. " is defeated!",
                                {0.9, 0.9, 0.3})

                            -- Handle enemy defeat (XP, gold, quest tracking)
                            if downTarget.isEnemy and downTarget.data then
                                F.onEnemyDefeated(downTarget.data)
                            end

                            -- Handle player defeat
                            if downTarget.isPlayer then
                                TacticalCombat.syncToGameState(tacticalState, state.player)
                                tacticalState.combatEnded = true
                                tacticalState.victory = false
                                F.endCombat(false)
                                if setTacticalState then setTacticalState(nil) end
                                return
                            end
                        end
                    end
                    if results.healed then
                        TacticalCombat.addLog(tacticalState,
                            active.name .. " heals " .. (results.healTarget and results.healTarget.name or "ally") ..
                            " for " .. (results.healAmount or 0) .. " HP!",
                            {0.3, 0.9, 0.5})
                    end
                end

                -- Check combat end conditions
                if TacticalCombat.checkAllEnemiesDefeated(tacticalState) then
                    TacticalCombat.syncToGameState(tacticalState, state.player)
                    tacticalState.combatEnded = true
                    tacticalState.victory = true
                    F.endCombat(true)
                    if setTacticalState then setTacticalState(nil) end
                    return
                end

                if TacticalCombat.checkPlayerDead(tacticalState) then
                    TacticalCombat.syncToGameState(tacticalState, state.player)
                    tacticalState.combatEnded = true
                    tacticalState.victory = false
                    F.endCombat(false)
                    if setTacticalState then setTacticalState(nil) end
                    return
                end

                -- Advance to next turn
                local nextUnit = TacticalCombat.advanceTurn(tacticalState)
                if processTacticalDotDeaths(tacticalState) then
                    if setTacticalState then setTacticalState(nil) end
                    return
                end
                if nextUnit then
                    TacticalCombat.addLog(tacticalState,
                        nextUnit.name .. "'s turn!",
                        nextUnit.color or {0.8, 0.8, 0.8})
                end
            end
        end

        -- Update path preview for mouse hover
        if active and active.isPlayer and TacticalUI then
            local mx, my = love.mouse.getPosition()
            TacticalUI.updatePathPreview(tacticalState, mx, my)
        end
    end
end

-- ============================================================================
-- TextRPG.draw
-- ============================================================================

M.draw = function()
    local tacticalState = getTacticalState()
    local TACTICAL_MODE = isTacticalMode()

    local screenW, screenH = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()

    -- Ensure state.player is loaded (safety check)
    if not state.player and state.phase ~= "class_select" and state.phase ~= "death" then
        if PlayerData.textRPG and PlayerData.textRPG.player then
            state.player = PlayerData.textRPG.player
            print("[DEBUG] Loaded state.player from PlayerData")
        else
            print("[DEBUG] ERROR: state.player is nil and PlayerData.textRPG.player doesn't exist!")
            print("[DEBUG] Current phase: " .. (state.phase or "nil"))
            print("[DEBUG] PlayerData.textRPG exists: " .. tostring(PlayerData.textRPG ~= nil))
            -- Force return to character creation
            if state.phase == "map" or state.phase == "town" then
                resetGame()
                state.phase = "class_select"
                state.playerNameInput = "Adventurer"
                log("Character data lost. Starting new character.", {0.9, 0.5, 0.5})
            end
        end
    end

    -- Clear tooltip state
    UIAssets.clearTooltip()

    -- Draw phase-appropriate background from Explore folder
    local bgDrawn = false
    if state.phase == "combat" then
        -- Combat backgrounds: Hunt1, Hunt2, Hunt3 (indices 4, 5, 6)
        local combatBgIndex = 4 + (math.floor(love.timer.getTime() / 30) % 3)  -- Cycle through hunt backgrounds
        bgDrawn = UIAssets.drawExploreBackground(combatBgIndex, 1)
    elseif state.phase == "map" then
        -- Exploration: Camp exploration background (index 1)
        bgDrawn = UIAssets.drawExploreBackground(1, 1)
    elseif state.phase == "town" or state.phase == "shop" or state.phase == "market" or
           state.phase == "npc_list" or state.phase == "dialogue" or state.phase == "job_board" or
           state.phase == "guild" or state.phase == "party" or state.phase == "stable" then
        -- Town phases: Tavern/Wage mode background (index 8)
        bgDrawn = UIAssets.drawExploreBackground(8, 1)
    else
        -- Default: Camp exploration
        bgDrawn = UIAssets.drawExploreBackground(1, 1)
    end

    -- Dark overlay for UI readability
    if bgDrawn then
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    else
        -- Fallback solid background
        love.graphics.setColor(0.08, 0.08, 0.12)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    end

    -- Apply day/night tint
    local nightAlpha = 0
    local drawTimeOfDay = state.timeOfDay or 12
    if drawTimeOfDay < 6 or drawTimeOfDay > 20 then
        -- Night time (8pm - 6am)
        nightAlpha = 0.25
    elseif drawTimeOfDay < 8 or drawTimeOfDay > 18 then
        -- Dawn/dusk
        nightAlpha = 0.1
    end
    if nightAlpha > 0 then
        love.graphics.setColor(0.05, 0.05, 0.15, nightAlpha)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    end

    -- Player info panel (left side)
    local panelW = 120
    local panelH = 180
    love.graphics.setColor(0.12, 0.12, 0.18)
    love.graphics.rectangle("fill", 10, 10, panelW, panelH, 8, 8)
    love.graphics.setColor(0.3, 0.4, 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", 10, 10, panelW, panelH, 8, 8)
    love.graphics.setLineWidth(1)

    if state.player then
        -- Class portrait image
        local playerClass = state.player.class
        local classId = playerClass and playerClass.id or "warrior"
        local className = playerClass and playerClass.name or "Unknown"
        local classColor = playerClass and playerClass.color or {0.7, 0.7, 0.7}
        local classPortraitText = playerClass and playerClass.portrait or "?"
        local playerLevel = state.player.level or 1

        local classPortrait = getPortraitImage(classId)
        if classPortrait then
            love.graphics.setColor(1, 1, 1)
            local imgW, imgH = classPortrait:getDimensions()
            local portraitSize = 45
            local scale = portraitSize / math.max(imgW, imgH)
            local portraitX = 10 + (panelW - imgW * scale) / 2
            love.graphics.draw(classPortrait, portraitX, 15, 0, scale, scale)
        else
            -- Fallback to text
            love.graphics.setColor(classColor)
            love.graphics.setFont(getFont(32))
            love.graphics.printf(classPortraitText, 10, 20, panelW, "center")
        end

        -- Player name
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(12))
        love.graphics.printf(state.player.name or "Adventurer", 10, 65, panelW, "center")

        -- Class and level
        love.graphics.setColor(0.7, 0.7, 0.8)
        love.graphics.setFont(getFont(10))
        love.graphics.printf(className .. " Lv." .. playerLevel, 10, 82, panelW, "center")

        -- HP bar (migrated to UI.ProgressBar)
        local barW = panelW - 20
        local playerHP = state.player.hp or 0
        local playerMaxHP = state.player.maxHP or 1
        if state.uiComponents and state.uiComponents.hpBar then
            state.uiComponents.hpBar.x = 20
            state.uiComponents.hpBar.y = 100
            state.uiComponents.hpBar.w = barW
            state.uiComponents.hpBar.value = playerHP / math.max(1, playerMaxHP)
            state.uiComponents.hpBar.label = playerHP .. "/" .. playerMaxHP
            state.uiComponents.hpBar:draw()
        end

        -- Mana bar (migrated to UI.ProgressBar)
        local playerMana = state.player.mana or 0
        local playerMaxMana = state.player.maxMana or 1
        if state.uiComponents and state.uiComponents.manaBar then
            state.uiComponents.manaBar.x = 20
            state.uiComponents.manaBar.y = 120
            state.uiComponents.manaBar.w = barW
            state.uiComponents.manaBar.value = playerMana / math.max(1, playerMaxMana)
            state.uiComponents.manaBar.label = playerMana .. "/" .. playerMaxMana
            state.uiComponents.manaBar:draw()
        end

        -- Gold with tooltip
        love.graphics.setFont(getFont(11))
        local goldX = 10 + (panelW - 60) / 2  -- Center the gold display
        UIAssets.drawCurrencyWithTooltip("coins", state.player.gold, goldX, 143, 16)

        -- XP
        love.graphics.setColor(0.5, 0.8, 1)
        love.graphics.printf("XP " .. (state.player.xp or 0) .. "/" .. (state.player.xpToLevel or 100), 10, 163, panelW, "center")
    end

    -- === STEALTH MODE SLIDE TOGGLE (exploration only - hidden during combat) ===
    if state.player and state.phase ~= "combat" and state.phase ~= "tactical_combat"
       and state.phase ~= "stealth_approach" and state.phase ~= "class_select" and state.phase ~= "death" then
        local toggleX = 10
        local toggleY = 195
        local toggleW = panelW
        local toggleH = 35

        -- Slide toggle background
        local bgColor = state.player.stealthMode and {0.15, 0.15, 0.25} or {0.18, 0.18, 0.22}
        love.graphics.setColor(bgColor)
        love.graphics.rectangle("fill", toggleX, toggleY, toggleW, toggleH, 6, 6)

        -- Border
        local borderColor = state.player.stealthMode and {0.5, 0.5, 0.7} or {0.35, 0.35, 0.4}
        love.graphics.setColor(borderColor)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", toggleX, toggleY, toggleW, toggleH, 6, 6)
        love.graphics.setLineWidth(1)

        -- Slide track
        local trackW = 50
        local trackH = 20
        local trackX = toggleX + toggleW - trackW - 10
        local trackY = toggleY + (toggleH - trackH) / 2

        local trackColor = state.player.stealthMode and {0.3, 0.5, 0.3} or {0.3, 0.3, 0.35}
        love.graphics.setColor(trackColor)
        love.graphics.rectangle("fill", trackX, trackY, trackW, trackH, 10, 10)

        -- Slide knob
        local knobSize = 16
        local knobX = state.player.stealthMode and (trackX + trackW - knobSize - 2) or (trackX + 2)
        local knobY = trackY + (trackH - knobSize) / 2

        local knobColor = state.player.stealthMode and {0.5, 0.9, 0.5} or {0.5, 0.5, 0.6}
        love.graphics.setColor(knobColor)
        love.graphics.circle("fill", knobX + knobSize/2, knobY + knobSize/2, knobSize/2)

        -- Label
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(11))
        local labelText = state.player.stealthMode and "\xF0\x9F\x8C\x91 Stealth" or "\xF0\x9F\x8C\x9E Normal"
        love.graphics.print(labelText, toggleX + 10, toggleY + 10)

        -- Store toggle bounds for mouse click
        state.stealthToggleBounds = {
            x = toggleX,
            y = toggleY,
            w = toggleW,
            h = toggleH
        }
    end

    -- === JOURNAL SLIDE TOGGLE ===
    if state.player and state.phase ~= "combat" and state.phase ~= "class_select" and state.phase ~= "death" then
        local toggleX = 10
        local toggleY = 235
        local toggleW = panelW
        local toggleH = 35

        local isOpen = state.player.journal and state.player.journal.isOpen

        -- Slide toggle background
        local bgColor = isOpen and {0.15, 0.2, 0.25} or {0.18, 0.18, 0.22}
        love.graphics.setColor(bgColor)
        love.graphics.rectangle("fill", toggleX, toggleY, toggleW, toggleH, 6, 6)

        -- Border
        local borderColor = isOpen and {0.5, 0.6, 0.7} or {0.35, 0.35, 0.4}
        love.graphics.setColor(borderColor)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", toggleX, toggleY, toggleW, toggleH, 6, 6)
        love.graphics.setLineWidth(1)

        -- Slide track
        local trackW = 50
        local trackH = 20
        local trackX = toggleX + toggleW - trackW - 10
        local trackY = toggleY + (toggleH - trackH) / 2

        local trackColor = isOpen and {0.3, 0.4, 0.5} or {0.3, 0.3, 0.35}
        love.graphics.setColor(trackColor)
        love.graphics.rectangle("fill", trackX, trackY, trackW, trackH, 10, 10)

        -- Slide knob
        local knobSize = 16
        local knobX = isOpen and (trackX + trackW - knobSize - 2) or (trackX + 2)
        local knobY = trackY + (trackH - knobSize) / 2

        local knobColor = isOpen and {0.5, 0.7, 0.9} or {0.5, 0.5, 0.6}
        love.graphics.setColor(knobColor)
        love.graphics.circle("fill", knobX + knobSize/2, knobY + knobSize/2, knobSize/2)

        -- Label
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(11))
        local labelText = isOpen and "\xF0\x9F\x93\x96 Journal" or "\xF0\x9F\x93\x95 Journal"
        love.graphics.print(labelText, toggleX + 10, toggleY + 10)

        -- Store toggle bounds for mouse click
        state.journalToggleBounds = {
            x = toggleX,
            y = toggleY,
            w = toggleW,
            h = toggleH
        }
    end

    -- === AUTO-PLAY TOGGLE BUTTON ===
    if state.player and state.phase ~= "combat" and state.phase ~= "class_select" and state.phase ~= "death" then
        local apToggleX = 10
        local apToggleY = 273  -- Right below journal (235 + 35 + 3px gap)
        local apToggleW = panelW
        local apToggleH = 35

        local apEnabled = state.autoPlay and state.autoPlay.enabled
        local apGoal = state.autoPlay and state.autoPlay.goal or "all"
        local goalData = AutoPlay.GOALS[apGoal]
        local goalIcon = goalData and goalData.icon or "\xE2\xAD\x90"

        -- Button background
        local bgColor = apEnabled and {0.15, 0.25, 0.15} or {0.18, 0.18, 0.22}
        love.graphics.setColor(bgColor)
        love.graphics.rectangle("fill", apToggleX, apToggleY, apToggleW, apToggleH, 6, 6)

        -- Border
        local borderColor = apEnabled and {0.4, 0.7, 0.4} or {0.35, 0.35, 0.4}
        love.graphics.setColor(borderColor)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", apToggleX, apToggleY, apToggleW, apToggleH, 6, 6)
        love.graphics.setLineWidth(1)

        -- Label
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(11))
        local labelText = apEnabled and (goalIcon .. " Auto-Play") or "\xF0\x9F\xA4\x96 Auto-Play"
        love.graphics.print(labelText, apToggleX + 10, apToggleY + 10)

        -- Store toggle bounds for mouse click
        state.autoPlayToggleBounds = {
            x = apToggleX,
            y = apToggleY,
            w = apToggleW,
            h = apToggleH
        }
    end

    -- === DEV CHEAT BUTTON === (REMOVE BEFORE RELEASE)
    if state.player and state.phase ~= "class_select" and state.phase ~= "death" then
        local devBtnX = 10
        local devBtnY = 311  -- Right below auto-play
        local devBtnW = panelW
        local devBtnH = 35

        -- Button background (bright red to stand out)
        love.graphics.setColor(0.3, 0.1, 0.1)
        love.graphics.rectangle("fill", devBtnX, devBtnY, devBtnW, devBtnH, 6, 6)

        -- Border
        love.graphics.setColor(0.8, 0.2, 0.2)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", devBtnX, devBtnY, devBtnW, devBtnH, 6, 6)
        love.graphics.setLineWidth(1)

        -- Label
        love.graphics.setColor(1, 0.8, 0.2)
        love.graphics.setFont(getFont(11))
        love.graphics.print("\xF0\x9F\x92\xB0 DEV CHEAT", devBtnX + 10, devBtnY + 10)

        -- Store button bounds for mouse click
        state.devCheatBounds = {
            x = devBtnX,
            y = devBtnY,
            w = devBtnW,
            h = devBtnH
        }
    end

    -- Day/Night and Season display panel (below dev button)
    love.graphics.setColor(0.1, 0.1, 0.15, 0.9)
    love.graphics.rectangle("fill", 10, 349, panelW, 75, 8, 8)
    love.graphics.setColor(0.25, 0.3, 0.4)
    love.graphics.rectangle("line", 10, 349, panelW, 75, 8, 8)

    -- Time/Date display
    love.graphics.setFont(getFont(10))
    local timeIcon = state.timeOfDay >= 6 and state.timeOfDay < 20 and "\xE2\x98\x80\xEF\xB8\x8F" or "\xF0\x9F\x8C\x99"
    local seasonIcons = {frosthollow = "\xE2\x9D\x84\xEF\xB8\x8F", brightbloom = "\xF0\x9F\x8C\xB8", sunreign = "\xE2\x98\x80\xEF\xB8\x8F", ashwane = "\xF0\x9F\x8D\x82"}
    local seasonIcon = seasonIcons[state.season] or "\xF0\x9F\x8C\xBF"
    local hour = math.floor(state.timeOfDay)
    local timeStr = string.format("%02d:00", hour)
    local cal = getCalendarDate(state.daysPassed)

    love.graphics.setColor(0.8, 0.8, 0.6)
    love.graphics.printf(timeIcon .. " " .. timeStr, 10, 354, panelW, "center")
    love.graphics.setColor(0.6, 0.7, 0.8)
    love.graphics.printf(seasonIcon .. " " .. cal.monthName .. " " .. cal.day, 10, 369, panelW, "center")
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.printf("Year " .. cal.year, 10, 384, panelW, "center")

    -- Mount/Pet display
    -- Using global Backpack
    local mount = Backpack.getEquippedMount()
    local pet = Backpack.getEquippedPet()
    local nextY = 366

    if mount or pet then
        love.graphics.setFont(getFont(9))
        if pet then
            love.graphics.setColor(0.6, 0.8, 0.9)
            love.graphics.printf("\xF0\x9F\x90\xBE " .. pet.name, 10, nextY, panelW, "center")
            nextY = nextY + 12
        end
        if mount then
            love.graphics.setColor(0.7, 0.6, 0.5)
            local speedMult = Backpack.getMountSpeedMultiplier()
            love.graphics.printf("\xF0\x9F\x90\xB4 " .. mount.name .. " (" .. speedMult .. "x)", 10, nextY, panelW, "center")
            nextY = nextY + 12
        end
    end

    -- Encumbrance/Weight panel
    local playerMight = state.player and state.player.stats and state.player.stats.MIGHT or 10
    local encumbrance = Backpack.getEncumbranceStatus(playerMight)
    local beast = Backpack.getEquippedBeast()
    local cart = Backpack.getEquippedCart()

    if beast or encumbrance.ratio > 0.3 then
        local encPanelY = 427
        local encPanelH = beast and 65 or 45
        love.graphics.setColor(0.1, 0.1, 0.15, 0.9)
        love.graphics.rectangle("fill", 10, encPanelY, panelW, encPanelH, 8, 8)
        love.graphics.setColor(0.25, 0.3, 0.4)
        love.graphics.rectangle("line", 10, encPanelY, panelW, encPanelH, 8, 8)

        -- Weight bar
        love.graphics.setFont(getFont(9))
        love.graphics.setColor(0.7, 0.7, 0.8)
        love.graphics.printf("Weight", 10, encPanelY + 4, panelW, "center")

        local barW = panelW - 20
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", 20, encPanelY + 18, barW, 10, 3, 3)

        -- Color based on encumbrance level
        local encColors = {
            light = {0.3, 0.7, 0.3},
            medium = {0.7, 0.7, 0.3},
            heavy = {0.8, 0.5, 0.2},
            overencumbered = {0.9, 0.3, 0.2},
            immobile = {0.8, 0.2, 0.2},
        }
        love.graphics.setColor(encColors[encumbrance.level] or {0.5, 0.5, 0.5})
        local fillRatio = math.min(1, encumbrance.ratio)
        love.graphics.rectangle("fill", 20, encPanelY + 18, barW * fillRatio, 10, 3, 3)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(8))
        local weightText = string.format("%.0f/%.0f", encumbrance.currentWeight, encumbrance.maxCapacity)
        love.graphics.printf(weightText, 20, encPanelY + 18, barW, "center")

        -- Beast of burden display
        if beast then
            local beastDef = Backpack.getBeastDef(beast.id)
            local beastCondition = Backpack.getBeastCondition()
            local condColor = beastCondition == "Good" and {0.4, 0.7, 0.4} or {0.9, 0.6, 0.3}

            love.graphics.setFont(getFont(9))
            love.graphics.setColor(0.6, 0.5, 0.4)
            love.graphics.printf("\xF0\x9F\x90\x8E " .. beast.name, 10, encPanelY + 33, panelW, "center")

            love.graphics.setColor(condColor)
            love.graphics.setFont(getFont(8))
            love.graphics.printf(beastCondition, 10, encPanelY + 46, panelW, "center")

            if cart then
                love.graphics.setColor(0.5, 0.5, 0.6)
                love.graphics.printf("+ " .. cart.name, 10, encPanelY + 56, panelW, "center")
            end
        end
    end

    -- === PARTY SIDE PANEL ===
    -- Compact display of party companions on the left side panel
    if state.player and state.player.party and #state.player.party > 0
       and state.phase ~= "class_select" and state.phase ~= "death" and state.phase ~= "combat" then
        local partyPanelY = 500  -- Below encumbrance panel
        local partySectionH = 0
        local party = state.player.party

        -- Party header
        love.graphics.setColor(0.1, 0.1, 0.15, 0.9)
        -- Calculate height: header(18) + each member(30) + padding(6)
        partySectionH = 22 + #party * 32 + 4
        love.graphics.rectangle("fill", 10, partyPanelY, panelW, partySectionH, 8, 8)
        love.graphics.setColor(0.3, 0.35, 0.5)
        love.graphics.rectangle("line", 10, partyPanelY, panelW, partySectionH, 8, 8)

        love.graphics.setColor(0.8, 0.7, 0.4)
        love.graphics.setFont(getFont(9))
        love.graphics.printf("Party (" .. #party .. "/" .. (state.player.maxPartySize or 99) .. ")", 10, partyPanelY + 3, panelW, "center")

        local memberY = partyPanelY + 18
        for i, companion in ipairs(party) do
            -- Companion name (truncated to fit)
            local displayName = companion.name or "???"
            if #displayName > 8 then
                displayName = displayName:sub(1, 7) .. "."
            end

            -- Class letter
            local classLetter = companion.class and companion.class.id and companion.class.id:sub(1, 1):upper() or "?"

            love.graphics.setFont(getFont(9))
            love.graphics.setColor(companion.color or {0.7, 0.7, 0.7})
            love.graphics.print(classLetter, 15, memberY)

            love.graphics.setColor(0.9, 0.9, 0.9)
            love.graphics.print(displayName, 26, memberY)

            -- Level
            love.graphics.setColor(0.6, 0.6, 0.7)
            love.graphics.setFont(getFont(8))
            love.graphics.print("L" .. (companion.level or 1), 90, memberY + 1)

            -- HP bar (compact, below name)
            local hpBarX = 15
            local hpBarY = memberY + 13
            local hpBarW = panelW - 20
            local hpBarH = 7

            local hpPct = math.max(0, math.min(1, (companion.hp or 0) / math.max(1, companion.maxHP or 1)))

            love.graphics.setColor(0.18, 0.18, 0.22)
            love.graphics.rectangle("fill", hpBarX, hpBarY, hpBarW, hpBarH, 2, 2)

            -- HP color based on percentage
            if hpPct > 0.5 then
                love.graphics.setColor(0.3, 0.7, 0.3)
            elseif hpPct > 0.25 then
                love.graphics.setColor(0.75, 0.7, 0.2)
            else
                love.graphics.setColor(0.8, 0.25, 0.25)
            end
            love.graphics.rectangle("fill", hpBarX, hpBarY, hpBarW * hpPct, hpBarH, 2, 2)

            -- HP text (tiny)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(getFont(7))
            love.graphics.printf((companion.hp or 0) .. "/" .. (companion.maxHP or 0), hpBarX, hpBarY - 1, hpBarW, "center")

            -- Morale indicator (colored dot)
            local morale = companion.morale or 100
            if morale >= 70 then
                love.graphics.setColor(0.3, 0.8, 0.3)
            elseif morale >= 40 then
                love.graphics.setColor(0.8, 0.7, 0.2)
            else
                love.graphics.setColor(0.8, 0.3, 0.3)
            end
            love.graphics.circle("fill", panelW + 5, memberY + 5, 3)

            memberY = memberY + 32
        end

        -- "[P] Party" hint at bottom
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.setFont(getFont(8))
        love.graphics.printf("[P] Details", 10, memberY - 6, panelW, "center")
    end

    -- Main content area
    local contentX = panelW + 25
    local contentY = 10
    local contentW = screenW - contentX - 15
    local contentH = screenH - 75

    love.graphics.setColor(0.1, 0.1, 0.14)
    love.graphics.rectangle("fill", contentX, contentY, contentW, contentH, 8, 8)

    -- Draw phase content
    if state.phase == "class_select" then
        F.drawClassSelect(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "town" then
        F.drawTown(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "map" then
        F.drawMap(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "combat" then
        F.drawCombat(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "tactical_combat" then
        -- FFT-style grid tactical combat
        if TACTICAL_MODE and TacticalUI and tacticalState then
            TacticalUI.draw(tacticalState, contentX, contentY, contentW, contentH, mx, my)
            -- Phase 9: help overlay
            if tacticalState._showHelp then
                TacticalUI.drawHelpOverlay(tacticalState,
                    contentX + 40, contentY + 20, contentW - 80, contentH - 40)
            end
        end
    elseif state.phase == "stealth_approach" then
        -- Stealth approach pre-combat menu
        if state.stealthApproach and StealthSystem and TacticalUI then
            -- Draw the world map underneath (same as map phase)
            F.drawMap(contentX, contentY, contentW, contentH, mx, my)
            -- Draw stealth approach overlay menu
            local screenW = love.graphics.getWidth()
            local screenH = love.graphics.getHeight()
            -- Dim background
            love.graphics.setColor(0, 0, 0, 0.6)
            love.graphics.rectangle("fill", 0, 0, screenW, screenH)
            -- Draw the stealth menu
            state.stealthApproach._buttons = TacticalUI.drawStealthApproachMenu(
                state.stealthApproach.result, screenW, screenH, mx, my, getFont
            )
        end
    elseif state.phase == "dialogue" then
        F.drawDialogue(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "inventory" then
        F.drawInventory(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "quest_log" then
        F.drawQuestLog(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "shop" then
        F.drawShop(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "market" then
        F.drawMarket(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "npc_list" then
        F.drawNPCList(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "tavern_interior" then
        F.drawTavernInterior(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "guild_interior" then
        F.drawGuildInterior(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "revive_hero" then
        F.drawReviveHero(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "building_interior" then
        F.drawBuildingInterior(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "npc_dialogue" then
        F.drawNPCDialogue(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "job_board" then
        F.drawJobBoard(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "death" then
        F.drawDeathScreen(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "graveyard" then
        F.drawGraveyard(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "guild" then
        F.drawGuild(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "party" then
        F.drawParty(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "camping" then
        F.drawCamping(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "camp" then
        F.drawCamp(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "resting" then
        F.drawResting(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "traveling_home" then
        F.drawTravelingHome(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "paid_travel" then
        F.drawPaidTravel(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "dungeon" then
        F.drawDungeon(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "stable" then
        F.drawStable(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "lockpick_prompt" then
        F.drawLockpickPrompt(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "lockpicking" then
        F.drawLockpicking(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "jail" or state.phase == "jailed" then
        F.drawJail(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "burglary_success" then
        F.drawBurglarySuccess(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "property_purchase" then
        F.drawPropertyPurchase(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "property_manage" then
        F.drawPropertyManage(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "land_claim" then
        F.drawLandClaim(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "land_manage" then
        F.drawLandManage(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "land_office" then
        F.drawLandOffice(contentX, contentY, contentW, contentH, mx, my)
    -- === CITY EXPANSION: New phase draw calls ===
    elseif state.phase == "district" then
        F.drawDistrict(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "guild_hall" then
        F.drawGuildHall(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "underbelly" then
        F.drawUnderbelly(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "bounty_board" then
        F.drawBountyBoard(contentX, contentY, contentW, contentH, mx, my)
    elseif state.phase == "courier_office" then
        F.drawCourierOffice(contentX, contentY, contentW, contentH, mx, my)
    else
        -- Catch-all: unhandled phase - show warning and auto-recover
        love.graphics.setColor(0.9, 0.5, 0.2)
        love.graphics.setFont(getFont(14))
        love.graphics.printf("Unknown phase: " .. tostring(state.phase), contentX + 20, contentY + 40, contentW - 40, "center")
        love.graphics.setColor(0.7, 0.7, 0.8)
        love.graphics.setFont(getFont(11))
        love.graphics.printf("Recovering... Click anywhere to return to map.", contentX + 20, contentY + 70, contentW - 40, "center")
        -- Auto-recover on next frame if player exists
        if state.player then
            if state.inDungeon and state.dungeon then
                state.phase = "dungeon"
            elseif state.world and state.world.currentTown then
                state.phase = "town"
            else
                state.phase = "map"
            end
        else
            state.phase = "class_select"
        end
    end

    -- Text log (bottom)
    local logY = screenH - 55
    love.graphics.setColor(0.05, 0.05, 0.08)
    love.graphics.rectangle("fill", 10, logY, screenW - 20, 45, 5, 5)

    love.graphics.setFont(getFont(10))
    local logCount = math.min(3, #state.textLog)
    for i = 1, logCount do
        local entry = state.textLog[#state.textLog - i + 1]
        if entry then
            love.graphics.setColor(entry.color[1], entry.color[2], entry.color[3], 0.95 - (i - 1) * 0.3)
            love.graphics.print(entry.text, 20, logY + 3 + (i - 1) * 13)
        end
    end

    -- Draw character sheet button (when player exists and not in class select or death)
    if state.player and state.phase ~= "class_select" and state.phase ~= "death" then
        local btnW, btnH = 30, 25
        local btnX = panelW + 10
        local btnY = screenH - 65
        local btnHover = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH

        love.graphics.setColor(btnHover and {0.35, 0.3, 0.45} or {0.2, 0.18, 0.28})
        love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 4, 4)

        -- Highlight if pending talent
        if state.player.pendingTalentSelection then
            love.graphics.setColor(0.9, 0.7, 0.2)
        else
            love.graphics.setColor(0.7, 0.6, 0.8)
        end
        love.graphics.setFont(getFont(14))
        love.graphics.printf("C", btnX, btnY + 5, btnW, "center")

        if btnHover then
            love.graphics.setColor(0.7, 0.7, 0.8)
            love.graphics.setFont(getFont(10))
            love.graphics.print("Character Sheet [C]", btnX + btnW + 5, btnY + 7)
        end

        -- Party button (P) - right of Character Sheet button
        local partyBtnW, partyBtnH = 30, 25
        local partyBtnX = btnX + btnW + 140
        local partyBtnY = btnY
        local partyBtnHover = mx >= partyBtnX and mx <= partyBtnX + partyBtnW and my >= partyBtnY and my <= partyBtnY + partyBtnH

        love.graphics.setColor(partyBtnHover and {0.3, 0.35, 0.4} or {0.18, 0.2, 0.25})
        love.graphics.rectangle("fill", partyBtnX, partyBtnY, partyBtnW, partyBtnH, 4, 4)

        -- Highlight P if party has members
        local hasParty = state.player.party and #state.player.party > 0
        love.graphics.setColor(hasParty and {0.7, 0.8, 0.5} or {0.5, 0.5, 0.6})
        love.graphics.setFont(getFont(14))
        love.graphics.printf("P", partyBtnX, partyBtnY + 5, partyBtnW, "center")

        if partyBtnHover then
            love.graphics.setColor(0.7, 0.7, 0.8)
            love.graphics.setFont(getFont(10))
            love.graphics.print("Party Status [P]", partyBtnX + partyBtnW + 5, partyBtnY + 7)
        end

        state.partyBtnBounds = {x = partyBtnX, y = partyBtnY, w = partyBtnW, h = partyBtnH}

        -- World Map button (M) - right of Party button with gap for tooltip
        local mapBtnW, mapBtnH = 30, 25
        local mapBtnX = partyBtnX + partyBtnW + 130
        local mapBtnY = btnY
        local mapBtnHover = mx >= mapBtnX and mx <= mapBtnX + mapBtnW and my >= mapBtnY and my <= mapBtnY + mapBtnH

        love.graphics.setColor(mapBtnHover and {0.3, 0.35, 0.45} or {0.18, 0.22, 0.3})
        love.graphics.rectangle("fill", mapBtnX, mapBtnY, mapBtnW, mapBtnH, 4, 4)
        love.graphics.setColor(state.fullMapOpen and {0.4, 0.8, 1.0} or {0.6, 0.7, 0.85})
        love.graphics.setFont(getFont(14))
        love.graphics.printf("M", mapBtnX, mapBtnY + 5, mapBtnW, "center")

        if mapBtnHover then
            love.graphics.setColor(0.7, 0.7, 0.8)
            love.graphics.setFont(getFont(10))
            love.graphics.print("World Map [M]", mapBtnX + mapBtnW + 5, mapBtnY + 7)
        end

        state.worldMapBtnBounds = {x = mapBtnX, y = mapBtnY, w = mapBtnW, h = mapBtnH}
    end

    -- Draw overlay UIs (on top of everything)
    if state.showCharacterSheet then
        F.drawCharacterSheet()
    end
    if state.showSkillTree then
        F.drawSkillTree()
    end
    if state.showTalentSelection then
        F.drawTalentSelection()
    end
    if state.showAscensionTree then
        F.drawAscensionTree()
    end
    if state.showSpecializationSelection then
        F.drawSpecializationSelection()
    end
    if state.showDevModePrompt then
        F.drawDevModePrompt()
    end
    if state.showPartyUI then
        F.drawPartyUI()
    end
    if state.companionSkillTreeIndex then
        F.drawCompanionSkillTree()
    end
    if state.companionTalentIndex then
        F.drawCompanionTalentSelection()
    end

    -- Draw full world map overlay (on top of all other overlays)
    if state.fullMapOpen then
        WorldMapOverlay.draw(state, getFont, F.getTileType)
    end

    -- Draw auto-play status (if enabled)
    if state.autoPlay and state.autoPlay.enabled then
        AutoPlay.drawStatus(state)
    end

    -- Draw auto-play goal menu (if open)
    if state.autoPlay and state.autoPlay.showMenu then
        AutoPlay.drawGoalMenu(state)
    end

    -- === VAMPIRE SUNLIGHT WARNING UI ===
    if state.player and state.player.isVampire then
        local hour = math.floor(state.timeOfDay or 12)
        if F.isInSunlight(hour) and not F.isVampireProtected(state.player) then
            -- Warning: In sunlight without protection!
            love.graphics.setColor(0.9, 0.2, 0.1, 0.95)
            love.graphics.rectangle("fill", screenW/2 - 200, 10, 400, 120, 8, 8)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(getFont(16))
            love.graphics.printf("\xE2\x9A\xA0\xEF\xB8\x8F SUNLIGHT EXPOSURE \xE2\x9A\xA0\xEF\xB8\x8F", screenW/2 - 200, 20, 400, "center")
            love.graphics.setFont(getFont(14))
            love.graphics.printf("You are burning in the sun!", screenW/2 - 200, 50, 400, "center")

            -- Show protection options
            local hasCoffin = Backpack.hasItem("tq_vampire_coffin")
            local hasCloth = Backpack.hasItem("tq_black_cloth")

            love.graphics.setFont(getFont(12))
            if hasCoffin then
                love.graphics.printf("[C] Use Coffin (Safe)", screenW/2 - 200, 80, 400, "center")
            end
            if hasCloth then
                love.graphics.printf("[W] Wrap in Cloth (30% fail chance)", screenW/2 - 200, 100, 400, "center")
            end
            if not hasCoffin and not hasCloth then
                love.graphics.setColor(1, 0.7, 0.7)
                love.graphics.printf("No protection available! Seek shelter!", screenW/2 - 200, 90, 400, "center")
            end
        end
    end

    -- === STEALTH MODE INDICATOR (exploration only - hidden during combat) ===
    if state.player and state.player.stealthMode
       and state.phase ~= "combat" and state.phase ~= "tactical_combat" and state.phase ~= "stealth_approach" then
        local desc, detection = F.getDetectionDescription()
        local percent = math.floor(detection * 100)

        -- Stealth indicator panel (top right)
        local stealthW = 250
        local stealthH = 160
        local stealthX = screenW - stealthW - 10
        local stealthY = 10

        -- Background
        love.graphics.setColor(0.1, 0.1, 0.15, 0.95)
        love.graphics.rectangle("fill", stealthX, stealthY, stealthW, stealthH, 8, 8)
        love.graphics.setColor(0.5, 0.5, 0.7)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", stealthX, stealthY, stealthW, stealthH, 8, 8)
        love.graphics.setLineWidth(1)

        -- Title
        love.graphics.setColor(0.6, 0.6, 0.8)
        love.graphics.setFont(getFont(14))
        love.graphics.printf("\xF0\x9F\x8C\x91 STEALTH MODE", stealthX, stealthY + 10, stealthW, "center")

        -- Detection percentage
        local detectionColor
        if percent <= 25 then
            detectionColor = {0.3, 1, 0.3}  -- Green - safe
        elseif percent <= 50 then
            detectionColor = {0.9, 0.9, 0.3}  -- Yellow - moderate
        elseif percent <= 75 then
            detectionColor = {0.9, 0.5, 0.2}  -- Orange - risky
        else
            detectionColor = {0.9, 0.2, 0.2}  -- Red - dangerous
        end

        love.graphics.setColor(detectionColor)
        love.graphics.setFont(getFont(16))
        love.graphics.printf("Detection: " .. percent .. "%", stealthX, stealthY + 35, stealthW, "center")

        -- Description
        love.graphics.setColor(0.8, 0.8, 0.9)
        love.graphics.setFont(getFont(12))
        love.graphics.printf(desc, stealthX, stealthY + 60, stealthW, "center")

        -- Modifier breakdown summary
        local hour = math.floor(state.timeOfDay or 12)
        local timeData = STEALTH_TIME_MODIFIERS and STEALTH_TIME_MODIFIERS[hour] or (STEALTH_TIME_MODIFIERS and STEALTH_TIME_MODIFIERS[12]) or {name = "Unknown", desc = ""}
        local isIndoorUI = state.inPrisonEscape or state.inDungeon or
            state.phase == "building_interior" or state.phase == "tavern_interior" or state.phase == "guild_interior"
        love.graphics.setFont(getFont(9))
        local breakdownY = stealthY + 80
        -- Time / location modifier
        love.graphics.setColor(0.6, 0.6, 0.7)
        if isIndoorUI then
            love.graphics.print("  Indoor (Dim lighting)", stealthX + 5, breakdownY)
        else
            love.graphics.print("  " .. timeData.name .. " (" .. timeData.desc .. ")", stealthX + 5, breakdownY)
        end
        breakdownY = breakdownY + 12
        -- Class modifier
        if state.player.classStealthBonus and state.player.classStealthBonus ~= 0 then
            local classColor = state.player.classStealthBonus > 0 and {0.5, 0.8, 0.5} or {0.8, 0.5, 0.5}
            love.graphics.setColor(classColor)
            love.graphics.print(string.format("  Class: %+.0f%%", state.player.classStealthBonus * 100), stealthX + 5, breakdownY)
            breakdownY = breakdownY + 12
        end
        -- Equipment modifier
        if state.player.equipmentStealthMod and state.player.equipmentStealthMod ~= 0 then
            local equipColor = state.player.equipmentStealthMod > 0 and {0.5, 0.8, 0.5} or {0.8, 0.5, 0.5}
            love.graphics.setColor(equipColor)
            love.graphics.print(string.format("  Gear: %+.0f%%", state.player.equipmentStealthMod * 100), stealthX + 5, breakdownY)
            breakdownY = breakdownY + 12
        end
        -- Skill modifier
        if state.player.skillStealthMod and state.player.skillStealthMod ~= 0 then
            love.graphics.setColor(0.5, 0.8, 0.5)
            love.graphics.print(string.format("  Skills: %+.0f%%", state.player.skillStealthMod * 100), stealthX + 5, breakdownY)
        end
    end

    -- === JOURNAL WINDOW ===
    if state.player and state.player.journal and state.player.journal.isOpen then
        -- Dark overlay
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)

        local w = 700
        local h = 500
        local x = screenW/2 - w/2
        local y = screenH/2 - h/2

        -- Journal window
        love.graphics.setColor(0.1, 0.1, 0.15)
        love.graphics.rectangle("fill", x, y, w, h, 10, 10)
        love.graphics.setColor(0.4, 0.4, 0.5)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", x, y, w, h, 10, 10)
        love.graphics.setLineWidth(1)

        -- Title
        love.graphics.setColor(0.9, 0.8, 0.6)
        love.graphics.setFont(getFont(18))
        love.graphics.print("\xF0\x9F\x93\x96 JOURNAL", x + 20, y + 15)

        -- Close button
        love.graphics.setColor(0.8, 0.3, 0.3)
        love.graphics.rectangle("fill", x + w - 35, y + 10, 25, 25, 4, 4)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(16))
        love.graphics.printf("X", x + w - 35, y + 12, 25, "center")

        -- Store close button bounds
        state.journalCloseBounds = {x = x + w - 35, y = y + 10, w = 25, h = 25}

        -- Draw tabs
        local tabY = y + 50
        local tabW = 95
        local tabH = 35
        local currentTab = state.player.journal.currentTab

        state.journalTabBounds = {}

        local journalTabs = JOURNAL_TABS or {
            {id = "events", name = "Events", icon = "\xF0\x9F\x93\x9C"},
            {id = "quests", name = "Quests", icon = "\xF0\x9F\x93\x8B"},
            {id = "actions", name = "Actions", icon = "\xF0\x9F\x93\x8A"},
            {id = "factions", name = "Factions", icon = "\xF0\x9F\x8F\x9B\xEF\xB8\x8F"},
            {id = "party", name = "Party", icon = "\xF0\x9F\x91\xA5"},
            {id = "stats", name = "Stats", icon = "\xF0\x9F\x93\x88"},
            {id = "status", name = "Status", icon = "\xF0\x9F\xA9\xBA"},
        }

        for i, tab in ipairs(journalTabs) do
            local tabX = x + 10 + (i-1) * (tabW + 5)
            local tabYPos = tabY

            -- Wrap to second row after 4 tabs
            if i > 4 then
                tabX = x + 10 + (i-5) * (tabW + 5)
                tabYPos = tabY + tabH + 5
            end

            local isActive = currentTab == tab.id

            -- Tab background
            if isActive then
                love.graphics.setColor(0.3, 0.3, 0.4)
            else
                love.graphics.setColor(0.15, 0.15, 0.2)
            end
            love.graphics.rectangle("fill", tabX, tabYPos, tabW, tabH, 5, 5)

            -- Tab border
            if isActive then
                love.graphics.setColor(0.6, 0.6, 0.7)
                love.graphics.setLineWidth(2)
            else
                love.graphics.setColor(0.3, 0.3, 0.35)
                love.graphics.setLineWidth(1)
            end
            love.graphics.rectangle("line", tabX, tabYPos, tabW, tabH, 5, 5)
            love.graphics.setLineWidth(1)

            -- Tab text
            love.graphics.setColor(isActive and {1, 1, 1} or {0.6, 0.6, 0.6})
            love.graphics.setFont(getFont(10))
            love.graphics.printf(tab.icon .. " " .. tab.name, tabX, tabYPos + 10, tabW, "center")

            -- Store bounds for clicking
            state.journalTabBounds[tab.id] = {x = tabX, y = tabYPos, w = tabW, h = tabH}
        end

        -- Content area
        local contentX = x + 20
        local contentY = y + 160
        local contentW = w - 40
        local contentH = h - 180

        -- Draw content based on current tab
        if currentTab == "events" then
            -- Event log header
            love.graphics.setColor(0.8, 0.8, 0.9)
            love.graphics.setFont(getFont(12))
            love.graphics.print("Event Log (" .. #state.player.journal.eventLog .. " entries)", contentX, contentY)

            if #state.player.journal.eventLog == 0 then
                love.graphics.setColor(0.5, 0.5, 0.5)
                love.graphics.setFont(getFont(11))
                love.graphics.printf("No events recorded yet.\nExplore, fight, and complete quests\nto fill your journal!", contentX, contentY + 80, contentW, "center")
            else
                -- Scrollable event list
                local scrollOffset = state.player.journal.scrollOffset or 0
                local entryHeight = 20
                local visibleHeight = contentH - 30
                local maxVisible = math.floor(visibleHeight / entryHeight)
                local totalEvents = #state.player.journal.eventLog

                -- Clamp scroll
                local maxScroll = math.max(0, (totalEvents - maxVisible) * entryHeight)
                if scrollOffset > maxScroll then
                    state.player.journal.scrollOffset = maxScroll
                    scrollOffset = maxScroll
                end

                -- Set clip region for scrolling
                love.graphics.setScissor(contentX, contentY + 22, contentW, visibleHeight)

                love.graphics.setFont(getFont(10))
                local startIdx = math.floor(scrollOffset / entryHeight)
                for i = totalEvents - startIdx, 1, -1 do
                    local displayIdx = totalEvents - i - startIdx
                    local drawY = contentY + 25 + displayIdx * entryHeight - (scrollOffset % entryHeight)
                    if drawY > contentY + visibleHeight + 22 then break end
                    if drawY >= contentY + 15 then
                        local event = state.player.journal.eventLog[i]
                        local timeStr = string.format("[Day %d, %02d:00]", event.day, event.hour)
                        love.graphics.setColor(0.45, 0.45, 0.55)
                        love.graphics.print(timeStr, contentX, drawY)
                        love.graphics.setColor(event.color[1], event.color[2], event.color[3], 0.95)
                        love.graphics.print(event.message, contentX + 110, drawY)
                    end
                end

                love.graphics.setScissor()

                -- Scroll indicators
                if scrollOffset > 0 then
                    love.graphics.setColor(0.7, 0.7, 0.8, 0.6)
                    love.graphics.setFont(getFont(10))
                    love.graphics.printf("^ Scroll up ^", contentX, contentY + 22, contentW, "center")
                end
                if scrollOffset < maxScroll then
                    love.graphics.setColor(0.7, 0.7, 0.8, 0.6)
                    love.graphics.setFont(getFont(10))
                    love.graphics.printf("v Scroll down v", contentX, contentY + visibleHeight + 5, contentW, "center")
                end
            end

        elseif currentTab == "quests" then
            love.graphics.setColor(0.8, 0.8, 0.9)
            love.graphics.setFont(getFont(12))
            love.graphics.print("Quests", contentX, contentY)

            love.graphics.setColor(0.6, 0.6, 0.7)
            love.graphics.setFont(getFont(10))
            love.graphics.print("Active Quests:", contentX, contentY + 25)

            local questY = contentY + 45
            if state.player.activeQuests and #state.player.activeQuests > 0 then
                for i, quest in ipairs(state.player.activeQuests) do
                    if i > 8 then break end
                    love.graphics.setColor(0.9, 0.7, 0.2)
                    love.graphics.print("\xE2\x80\xA2 " .. quest.name, contentX + 10, questY)
                    love.graphics.setColor(0.6, 0.6, 0.7)
                    love.graphics.print(quest.desc or "", contentX + 20, questY + 15)
                    questY = questY + 35
                end
            else
                love.graphics.setColor(0.5, 0.5, 0.5)
                love.graphics.print("No active quests", contentX + 10, questY)
            end

        elseif currentTab == "actions" then
            love.graphics.setColor(0.8, 0.8, 0.9)
            love.graphics.setFont(getFont(12))
            love.graphics.print("Actions Performed", contentX, contentY)

            local stats = state.player.journal.actionStats
            love.graphics.setColor(0.6, 0.6, 0.7)
            love.graphics.setFont(getFont(10))

            local statY = contentY + 25
            love.graphics.print("Combat:", contentX, statY)
            love.graphics.print("Enemies Defeated: " .. stats.combat.enemiesDefeated, contentX + 10, statY + 18)
            love.graphics.print("Damage Dealt: " .. stats.combat.damageDealt, contentX + 10, statY + 36)
            love.graphics.print("Deaths: " .. stats.combat.deaths, contentX + 10, statY + 54)

            statY = statY + 80
            love.graphics.print("Crimes:", contentX, statY)
            love.graphics.print("Crimes Committed: " .. stats.crimes.crimesCommitted, contentX + 10, statY + 18)
            love.graphics.print("Times Arrested: " .. stats.crimes.timesArrested, contentX + 10, statY + 36)
            love.graphics.print("Bounty Paid: " .. stats.crimes.bountyPaid .. "g", contentX + 10, statY + 54)

            statY = statY + 80
            love.graphics.print("Social:", contentX, statY)
            love.graphics.print("Quests Completed: " .. stats.social.questsCompleted, contentX + 10, statY + 18)
            love.graphics.print("NPCs Talked To: " .. stats.social.npcsTalkedTo, contentX + 10, statY + 36)

        elseif currentTab == "factions" then
            love.graphics.setColor(0.8, 0.8, 0.9)
            love.graphics.setFont(getFont(12))
            love.graphics.print("Faction Relations", contentX, contentY)

            love.graphics.setColor(0.6, 0.6, 0.7)
            love.graphics.setFont(getFont(10))

            local factionY = contentY + 25
            for factionId, rep in pairs(state.player.factionRep or {}) do
                if factionY > contentY + contentH - 40 then break end

                local repLevel = F.getReputationLevel(rep)
                love.graphics.setColor(repLevel.color)
                love.graphics.print(factionId:gsub("_", " "):upper() .. ": " .. repLevel.name .. " (" .. rep .. ")", contentX, factionY)
                factionY = factionY + 20
            end

            if not next(state.player.factionRep or {}) then
                love.graphics.setColor(0.5, 0.5, 0.5)
                love.graphics.printf("No faction relations yet", contentX, contentY + 100, contentW, "center")
            end

        elseif currentTab == "party" then
            love.graphics.setColor(0.8, 0.8, 0.9)
            love.graphics.setFont(getFont(12))
            love.graphics.print("Party Members", contentX, contentY)

            love.graphics.setColor(0.6, 0.6, 0.7)
            love.graphics.setFont(getFont(10))

            if state.player.party and #state.player.party > 0 then
                local partyY = contentY + 25
                for i, member in ipairs(state.player.party) do
                    love.graphics.setColor(0.7, 0.9, 0.7)
                    love.graphics.print(member.name .. " - Lv." .. member.level, contentX, partyY)
                    love.graphics.setColor(0.6, 0.6, 0.7)
                    love.graphics.print("HP: " .. member.hp .. "/" .. member.maxHP, contentX + 10, partyY + 18)
                    partyY = partyY + 45
                end
            else
                love.graphics.setColor(0.5, 0.5, 0.5)
                love.graphics.printf("No party members", contentX, contentY + 100, contentW, "center")
            end

        elseif currentTab == "stats" then
            love.graphics.setColor(0.8, 0.8, 0.9)
            love.graphics.setFont(getFont(12))
            love.graphics.print("Character Stats", contentX, contentY)

            local p = state.player
            love.graphics.setColor(0.6, 0.6, 0.7)
            love.graphics.setFont(getFont(10))

            local statY = contentY + 25
            local function fmtStat(name, val)
                val = val or 10
                return string.format("%s: %d (+%d)", name, val, F.getStatModifier(val))
            end
            love.graphics.print(fmtStat("MIGHT", p.stats.MIGHT), contentX, statY)
            love.graphics.print(fmtStat("VIGOR", p.stats.VIGOR), contentX + 150, statY)
            love.graphics.print(fmtStat("AGILITY", p.stats.AGILITY), contentX + 300, statY)

            statY = statY + 20
            love.graphics.print(fmtStat("MIND", p.stats.MIND), contentX, statY)
            love.graphics.print(fmtStat("SPIRIT", p.stats.SPIRIT), contentX + 150, statY)
            love.graphics.print(fmtStat("PRESENCE", p.stats.PRESENCE), contentX + 300, statY)

            statY = statY + 20
            love.graphics.print(fmtStat("FAITH", p.stats.FAITH), contentX, statY)

            statY = statY + 40
            love.graphics.print("Attack: " .. p.attack, contentX, statY)
            love.graphics.print("Defense: " .. p.defense, contentX + 120, statY)

            statY = statY + 20
            love.graphics.print("Crit: " .. (p.critChance or 5) .. "%", contentX, statY)
            love.graphics.print("Dodge: " .. (p.dodgeChance or 0) .. "%", contentX + 120, statY)

        elseif currentTab == "status" then
            love.graphics.setColor(0.8, 0.8, 0.9)
            love.graphics.setFont(getFont(12))
            love.graphics.print("Status Effects", contentX, contentY)

            love.graphics.setColor(0.6, 0.6, 0.7)
            love.graphics.setFont(getFont(10))

            local statusY = contentY + 25

            if state.player.isVampire then
                love.graphics.setColor(0.8, 0.2, 0.3)
                love.graphics.print("\xF0\x9F\xA6\x87 VAMPIRE CURSE", contentX, statusY)
                love.graphics.setColor(0.6, 0.6, 0.7)
                love.graphics.print("Transformed: Day " .. (state.player.vampireTransformDate or 0), contentX + 10, statusY + 18)
                love.graphics.print("Stats: 2x multiplier active", contentX + 10, statusY + 36)
                statusY = statusY + 60
            end

            love.graphics.setColor(0.6, 0.6, 0.7)
            love.graphics.print("Overall Status: Healthy", contentX, statusY)
        end
    end

    -- Draw auto-travel progress indicator
    if AutoTravel then
        AutoTravel.drawTravelProgress()
    end

    -- Draw auto-travel menu (overlays everything else)
    if AutoTravel and AutoTravel.menuOpen then
        AutoTravel.drawTravelMenu()
    end

    -- Draw full backpack overlay (on top of everything except tooltips)
    Backpack.draw()

    -- Draw chatbot free talk overlay (on top of everything except tooltips)
    if F.isFreeTalkActive and F.isFreeTalkActive() then
        F.drawFreeTalk()
    end

    -- Draw currency tooltips
    UIAssets.drawTooltip()
end

return M
