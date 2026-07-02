-- TAVERN QUEST: A Tale of Tavern Times
-- Main entry point

-- Game states (game.lua must load before menu.lua because StoryMode is merged into game.lua
-- and menu.lua does require("storymode") which is satisfied via package.loaded)
local Game = require("game")
local StoryMode = require("storymode")
local Menu = require("menu")
local DeckBuilder = require("deckbuilder")
local Collection = require("collection")
local LootBox = require("lootbox")
local SaveSystem = require("savesystem")
local Credits = require("credits")
local CafeGame = require("cafegame")
local StockMarket = require("stockmarket")
local TradingCards = require("tradingcards")
local StatsPage = require("statspage")
local TextRPG = require("textrpg")
local PetSim = require("petsim")
local EndlessMode = require("endlessmode")
local Lore = require("lore")
local Tutorial = require("tutorial_menu")
local Fishing = require("fishing")
local Forge = require("forge")
local Hunting = require("hunting")
local WizardTower = require("wizardtower")
local Alchemist = require("alchemist")
local Progression = require("progression")
local Backpack = require("backpack")
local PauseMenu = require("pausemenu")
local Cutscenes = require("cutscenes")
local PrisonEscape = require("prison_escape")
local MapEditor = require("map_editor")
local UI = require("ui")
local InteractiveTutorial = require("interactivetutorial")
local KnowledgeCenter = require("knowledgecenter")

-- Sprite rendering systems
local LPCLoader = require("lpcloader")
local Camera2D = require("camera2d")
local SpriteManager = require("spritemanager")
local Renderer2D = require("renderer2d")
local TileQuadMaps = require("tile_quad_maps")

-- State module registry for table-driven dispatch
local stateModules = {
    menu = Menu,
    game = Game,
    deckbuilder = DeckBuilder,
    collection = Collection,
    storymode = StoryMode,
    lootbox = LootBox,
    credits = Credits,
    cafegame = CafeGame,
    stockmarket = StockMarket,
    tradingcards = TradingCards,
    statspage = StatsPage,
    textrpg = TextRPG,
    petsim = PetSim,
    endlessmode = EndlessMode,
    lore = Lore,
    tutorial = Tutorial,
    fishing = Fishing,
    forge = Forge,
    hunting = Hunting,
    prison_escape = PrisonEscape,
    wizardtower = WizardTower,
    alchemist = Alchemist,
    map_editor = MapEditor,
}

-- FPS Counter System (toggle with F3)
FPSCounter = {
    enabled = false,        -- Toggle with F3
    frames = 0,
    time = 0,
    current = 0,
    history = {},
    historySize = 60,
    avgFPS = 0,
    minFPS = 999,
    maxFPS = 0,
}

function FPSCounter.update(dt)
    FPSCounter.frames = FPSCounter.frames + 1
    FPSCounter.time = FPSCounter.time + dt

    if FPSCounter.time >= 0.5 then
        FPSCounter.current = math.floor(FPSCounter.frames / FPSCounter.time)

        -- Update history
        table.insert(FPSCounter.history, FPSCounter.current)
        if #FPSCounter.history > FPSCounter.historySize then
            table.remove(FPSCounter.history, 1)
        end

        -- Calculate stats
        local sum = 0
        FPSCounter.minFPS = 999
        FPSCounter.maxFPS = 0
        for _, fps in ipairs(FPSCounter.history) do
            sum = sum + fps
            if fps < FPSCounter.minFPS then FPSCounter.minFPS = fps end
            if fps > FPSCounter.maxFPS then FPSCounter.maxFPS = fps end
        end
        FPSCounter.avgFPS = math.floor(sum / #FPSCounter.history)

        FPSCounter.frames = 0
        FPSCounter.time = 0
    end
end

function FPSCounter.draw()
    if not FPSCounter.enabled then return end

    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 10, 10, 200, 100)

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("FPS: " .. FPSCounter.current, 20, 20)
    love.graphics.print("Avg: " .. FPSCounter.avgFPS, 20, 40)
    love.graphics.print("Min: " .. FPSCounter.minFPS, 20, 60)
    love.graphics.print("Max: " .. FPSCounter.maxFPS, 20, 80)
end

function FPSCounter.toggle()
    FPSCounter.enabled = not FPSCounter.enabled
    print("FPS Counter:", FPSCounter.enabled and "ON" or "OFF")
end

-- Audio system
AudioSystem = {
    menuMusic = nil,
    gameMusic = nil,
    combatMusic = nil,
    rpgMusic = nil,
    townMusic = nil,
    currentTrack = nil,
    -- Menu/ambient tracks
    menuTracks = {
        "assets/music/07_Mountain_Halls__ExplorationTrack.WAV",
        "assets/music/09_The_Journey_Begins__ExplorationTrack.WAV",
    },
    -- Combat tracks (for battles/fights)
    combatTracks = {
        "assets/music/01_Horns_Of_War_BattleTrack.WAV",
        "assets/music/SW_Combat_1.WAV",
    },
    -- Exploration tracks (for RPG/adventure modes)
    explorationTracks = {
        "assets/music/05_Misty_Lands_ExplorationTrack.WAV",
        "assets/music/06_Through_The_Lands_-_Atmospheres_Part_I__ExplorationTrack.WAV",
        "assets/music/08_Through_The_Lands_-_Atmospheres_Part_II_ExplorationTrack.WAV",
        "assets/music/10_Through_The_Lands_-_Atmospheres_Part_III_ExplorationTrack.WAV",
        "assets/music/SW_Exploration_6.WAV",
    },
    -- Town tracks (for cafe, pet sim, etc.)
    townTracks = {
        "assets/music/SW_Town_1.WAV",
    },
    -- Legacy tracks (fallback)
    tracks = {
        "WAV_AquaAmbi_loop.WAV",
        "WAV_Sonar_Dreams_loop.WAV",
        "WAV_Ultramarine_loop.WAV",
        "WAV_Vistas_loop.WAV"
    }
}

-- Helper function to play a track from a list
local function playTrackFromList(trackList, fallbackList)
    local volume = (PlayerData and PlayerData.settings and PlayerData.settings.musicVolume) or 0.3

    -- Try new tracks first
    for _, track in ipairs(trackList) do
        if love.filesystem.getInfo(track) then
            local ok, source = pcall(love.audio.newSource, track, "stream")
            if ok and source then
                source:setVolume(volume)
                source:setLooping(true)
                love.audio.play(source)
                return source
            end
        end
    end

    -- Try fallback tracks
    if fallbackList then
        for _, track in ipairs(fallbackList) do
            if love.filesystem.getInfo(track) then
                local ok, source = pcall(love.audio.newSource, track, "stream")
                if ok and source then
                    source:setVolume(volume)
                    source:setLooping(true)
                    love.audio.play(source)
                    return source
                end
            end
        end
    end

    return nil
end

function AudioSystem.isMusicMuted()
    return PlayerData and PlayerData.settings and PlayerData.settings.musicMuted
end

function AudioSystem.playMenuMusic()
    if AudioSystem.currentTrack == "menu" then return end
    if AudioSystem.isMusicMuted() then return end

    AudioSystem.stopAll()
    AudioSystem.menuMusic = playTrackFromList(AudioSystem.menuTracks, AudioSystem.tracks)
    AudioSystem.currentTrack = "menu"
end

function AudioSystem.playGameMusic()
    if AudioSystem.currentTrack == "game" then return end
    if AudioSystem.isMusicMuted() then return end

    AudioSystem.stopAll()
    AudioSystem.gameMusic = playTrackFromList(AudioSystem.explorationTracks, AudioSystem.tracks)
    AudioSystem.currentTrack = "game"
end

function AudioSystem.playCombatMusic()
    if AudioSystem.currentTrack == "combat" then return end
    if AudioSystem.isMusicMuted() then return end

    AudioSystem.stopAll()
    AudioSystem.combatMusic = playTrackFromList(AudioSystem.combatTracks, AudioSystem.tracks)
    AudioSystem.currentTrack = "combat"
end

function AudioSystem.playRPGMusic()
    if AudioSystem.currentTrack == "rpg" then return end
    if AudioSystem.isMusicMuted() then return end

    AudioSystem.stopAll()
    AudioSystem.rpgMusic = playTrackFromList(AudioSystem.explorationTracks, {"SW_Exploration_6.WAV"})
    AudioSystem.currentTrack = "rpg"
end

function AudioSystem.playTownMusic()
    if AudioSystem.currentTrack == "town" then return end
    if AudioSystem.isMusicMuted() then return end

    AudioSystem.stopAll()
    AudioSystem.townMusic = playTrackFromList(AudioSystem.townTracks, {"SW_Town_1.WAV"})
    AudioSystem.currentTrack = "town"
end

function AudioSystem.stopAll()
    local sources = {"menuMusic", "gameMusic", "combatMusic", "rpgMusic", "townMusic"}
    for _, key in ipairs(sources) do
        if AudioSystem[key] then
            AudioSystem[key]:stop()
            AudioSystem[key] = nil
        end
    end
    AudioSystem.currentTrack = nil
end

-- Passive income accumulator (runs every frame, adds to coins)
local passiveIncomeAccumulator = 0
local PASSIVE_SAVE_INTERVAL = 30  -- Save every 30 seconds
local passiveSaveTimer = 0

function updatePassiveIncome(dt)
    if not PlayerData then return end
    if not PlayerData.passiveIncome or PlayerData.passiveIncome <= 0 then return end

    -- Accumulate passive income
    passiveIncomeAccumulator = passiveIncomeAccumulator + (PlayerData.passiveIncome * dt)

    -- Add whole coins when accumulated >= 1
    if passiveIncomeAccumulator >= 1 then
        local coinsToAdd = math.floor(passiveIncomeAccumulator)
        PlayerData.coins = PlayerData.coins + coinsToAdd
        passiveIncomeAccumulator = passiveIncomeAccumulator - coinsToAdd
    end

    -- Periodically save to prevent loss on crash
    passiveSaveTimer = passiveSaveTimer + dt
    if passiveSaveTimer >= PASSIVE_SAVE_INTERVAL then
        passiveSaveTimer = 0
        PlayerData.lastPassiveUpdate = os.time()
        -- Only save if we're not in a game mode that manages its own saving
        if GameState.current == "menu" then
            savePlayerData()
        end
    end
end

-- Calculate offline passive income when loading
function calculateOfflinePassiveIncome()
    if not PlayerData then return 0 end
    if not PlayerData.passiveIncome or PlayerData.passiveIncome <= 0 then return 0 end
    if not PlayerData.lastPassiveUpdate or PlayerData.lastPassiveUpdate <= 0 then
        PlayerData.lastPassiveUpdate = os.time()
        return 0
    end

    local now = os.time()
    local elapsed = now - PlayerData.lastPassiveUpdate
    local maxOfflineSeconds = 8 * 60 * 60  -- Cap at 8 hours
    elapsed = math.min(elapsed, maxOfflineSeconds)

    if elapsed > 60 then  -- Only count if away for more than a minute
        local offlineEarnings = PlayerData.passiveIncome * elapsed
        PlayerData.lastPassiveUpdate = now
        return math.floor(offlineEarnings)
    end

    PlayerData.lastPassiveUpdate = now
    return 0
end

-- Global helper: Update passive income from a specific source
-- Called by game modes when their employee roster changes
function updatePassiveIncomeSource(sourceName, rate)
    if not PlayerData then return end
    if not PlayerData.passiveIncomeBreakdown then
        PlayerData.passiveIncomeBreakdown = {}
    end

    -- Update this source's rate
    PlayerData.passiveIncomeBreakdown[sourceName] = rate or 0

    -- Recalculate total passive income from all sources
    local totalPassive = 0
    for source, sourceRate in pairs(PlayerData.passiveIncomeBreakdown) do
        totalPassive = totalPassive + (sourceRate or 0)
    end
    PlayerData.passiveIncome = totalPassive

    -- Save immediately so passive income persists
    savePlayerData()
end

-- Global state
GameState = {
    current = "menu",  -- menu, game, deckbuilder, collection, storymode, lootbox, credits, cafegame, tutorial, fishing, forge, hunting, textrpg, etc.
    player = nil,
    opponent = nil,
    isHost = false,
    isAI = false,
    isStoryMode = false,
    network = nil,
    playerUID = nil  -- Unique player ID for multiplayer
}
previousState = nil

-- Save/Load player data functions
function savePlayerData()
    SaveSystem.saveCurrentSlot(PlayerData)
end

function loadPlayerData()
    PlayerData = SaveSystem.loadSlot(SaveSystem.activeSlot)

    -- Ensure required fields exist (for backwards compatibility)
    if not PlayerData.settings then
        PlayerData.settings = {
            musicVolume = 0.3,
            sfxVolume = 0.5,
            fullscreen = true,
            musicMuted = false
        }
    end

    if not PlayerData.stats then
        PlayerData.stats = {
            totalChipsScored = 0,
            totalMultEarned = 0,
            handsPlayed = 0,
            bestHand = "",
            bestHandScore = 0
        }
    end

    -- Initialize passive income fields if missing
    if not PlayerData.passiveIncome then
        PlayerData.passiveIncome = 0
    end
    if not PlayerData.passiveIncomeBreakdown then
        PlayerData.passiveIncomeBreakdown = {}
    end
    if not PlayerData.lastPassiveUpdate then
        PlayerData.lastPassiveUpdate = os.time()
    end

    -- Calculate and award offline passive income
    local offlineEarnings = calculateOfflinePassiveIncome()
    if offlineEarnings > 0 then
        PlayerData.coins = PlayerData.coins + offlineEarnings
        -- Store for display on menu
        PlayerData.lastOfflineEarnings = offlineEarnings
    end
end

function love.load()
    love.window.setTitle("Tavern Quest")
    love.window.setMode(1280, 720, {resizable = true, minwidth = 800, minheight = 600})

    -- Set random seed
    math.randomseed(os.time())

    -- Initialize save system first
    SaveSystem.init()

    -- Load player data from active save slot
    loadPlayerData()

    -- Apply fullscreen setting from loaded data
    local shouldBeFullscreen = true
    if PlayerData.settings and PlayerData.settings.fullscreen ~= nil then
        shouldBeFullscreen = PlayerData.settings.fullscreen
    end
    love.window.setFullscreen(shouldBeFullscreen)

    -- Initialize all game modules
    Menu.init()
    Game.init()
    DeckBuilder.init()
    Collection.init()
    StoryMode.init()
    LootBox.init()
    Credits.init()
    CafeGame.init()
    StockMarket.init()
    Progression.init()
    Backpack.init()

    -- Initialize sprite rendering systems
    print("\n========================================")
    print("Initializing Sprite Rendering Systems")
    print("========================================")
    LPCLoader.init()
    Camera2D.init(0, 0)
    Renderer2D.init()

    -- Initialize tile quad maps with loaded atlases
    TileQuadMaps.init({
        terrain = Renderer2D.getAtlas("terrain"),
        town_objects = Renderer2D.getAtlas("town_objects"),
        worldmap = Renderer2D.getAtlas("worldmap"),
    })

    print("\n========================================")
    print("TAVERN QUEST - Main Game")
    print("========================================")
    print("Press ESC in menu to quit")
    print("F3 - Toggle FPS Counter")
    print("F4 - Toggle Render Mode (sprite/classic)")
    print("========================================\n")
end

function love.update(dt)
    FPSCounter.update(dt)
    Camera2D.update(dt)
    updatePassiveIncome(dt)

    -- Update UI animation system (always runs)
    UI.anim.update(dt)
    UI.Tooltip.update(dt)
    UI.Toast.update(dt)

    -- Update cutscene typewriter effect (runs even when paused for visual polish)
    Cutscenes.update(dt)

    -- Update interactive tutorial overlay (runs alongside game)
    InteractiveTutorial.update(dt)

    -- Update Knowledge Center if active
    if KnowledgeCenter.isActive() then
        KnowledgeCenter.update(dt)
    end

    -- Skip game updates when paused
    if PauseMenu.isActive() then
        PauseMenu.update(dt)
        return
    end

    local module = stateModules[GameState.current]
    if module and module.update then
        module.update(dt)
    end
end

function love.draw()
    local module = stateModules[GameState.current]
    if module and module.draw then
        module.draw()
    end

    FPSCounter.draw()

    -- Draw cutscene overlay (on top of everything except pause menu)
    Cutscenes.draw()

    -- Draw interactive tutorial overlay (on top of game, under pause menu)
    InteractiveTutorial.draw()

    -- Draw pause menu overlay (always on top)
    PauseMenu.draw()

    -- Draw Knowledge Center overlay (on top of everything)
    if KnowledgeCenter.isActive() then
        KnowledgeCenter.draw()
    end

    -- Draw UI overlays (toasts and tooltips always on top)
    UI.Toast.draw()
    UI.Tooltip.draw()
end

function love.keypressed(key)
    -- Global shortcuts
    if key == "f3" then
        FPSCounter.toggle()
        return
    end

    if key == "f4" then
        if RENDER_MODE == "sprite" then
            RENDER_MODE = "classic"
            print("Render mode: CLASSIC (colored rectangles)")
        else
            RENDER_MODE = "sprite"
            print("Render mode: SPRITE (tile-based)")
        end
        return
    end

    -- Knowledge Center hotkey [K] - global access (except when typing in text fields)
    if key == "k" and not KnowledgeCenter.isActive() and GameState.current ~= "menu" then
        if not PauseMenu.isActive() and not Cutscenes.isActive() then
            KnowledgeCenter.init()
            return
        end
    end

    -- Knowledge Center takes priority when active
    if KnowledgeCenter.isActive() then
        KnowledgeCenter.keypressed(key)
        return
    end

    -- Cutscene input takes priority (except pause menu)
    if Cutscenes.isActive() and not PauseMenu.isActive() then
        if key == "escape" then
            -- ESC during cutscene: skip cutscene (not open pause)
            Cutscenes.keypressed(key)
            return
        end
        Cutscenes.keypressed(key)
        return
    end

    -- Interactive tutorial takes priority over game input
    if InteractiveTutorial.isActive() then
        if InteractiveTutorial.keypressed(key) then
            return
        end
    end

    -- Pause menu takes top priority for ESC key (except on main menu)
    if key == "escape" and GameState.current ~= "menu" then
        if PauseMenu.isActive() then
            PauseMenu.keypressed(key)
            return
        else
            -- First, let the current game mode try to handle ESC (close overlays, etc.)
            if GameState.current == "textrpg" and TextRPG.handleEscape and TextRPG.handleEscape() then
                return  -- TextRPG consumed the ESC (closed an overlay/sub-phase)
            end
            -- If not consumed, open pause menu
            PauseMenu.open()
            return
        end
    end

    -- If pause menu is active, consume all input
    if PauseMenu.isActive() then
        PauseMenu.keypressed(key)
        return
    end

    local module = stateModules[GameState.current]
    if module and module.keypressed then
        module.keypressed(key)
    end
end

function love.mousepressed(x, y, button)
    -- Knowledge Center intercepts all clicks when active
    if KnowledgeCenter.isActive() then
        KnowledgeCenter.mousepressed(x, y, button)
        return
    end
    -- Pause menu intercepts all clicks when active
    if PauseMenu.isActive() then
        PauseMenu.mousepressed(x, y, button)
        return
    end
    -- Cutscene intercepts clicks when active
    if Cutscenes.isActive() then
        Cutscenes.mousepressed(x, y, button)
        return
    end
    -- Interactive tutorial intercepts clicks when active
    if InteractiveTutorial.isActive() then
        if InteractiveTutorial.mousepressed(x, y, button) then
            return
        end
    end
    local module = stateModules[GameState.current]
    if module and module.mousepressed then
        module.mousepressed(x, y, button)
    end
end

function love.mousereleased(x, y, button)
    -- Forward mousereleased to all modules that use UI.Button components
    -- UI.Button requires mousereleased to complete click actions
    if KnowledgeCenter.isActive() then
        if KnowledgeCenter.mousereleased then KnowledgeCenter.mousereleased(x, y, button) end
        return
    end
    if PauseMenu.isActive() then
        if PauseMenu.mousereleased then PauseMenu.mousereleased(x, y, button) end
        return
    end
    local module = stateModules[GameState.current]
    if module and module.mousereleased then
        module.mousereleased(x, y, button)
    end
end

function love.wheelmoved(x, y)
    -- Knowledge Center scroll
    if KnowledgeCenter.isActive() then
        if KnowledgeCenter.wheelmoved then
            KnowledgeCenter.wheelmoved(x, y)
        end
        return
    end
    -- Pause menu scroll
    if PauseMenu.isActive() then
        if PauseMenu.wheelmoved then
            PauseMenu.wheelmoved(x, y)
        end
        return
    end
    -- Forward to current game state
    local module = stateModules[GameState.current]
    if module and module.wheelmoved then
        module.wheelmoved(x, y)
    end
end

function love.textinput(text)
    -- Knowledge Center text input
    if KnowledgeCenter.isActive() then
        if KnowledgeCenter.textinput then
            KnowledgeCenter.textinput(text)
        end
        return
    end
    -- Forward to current game state
    local module = stateModules[GameState.current]
    if module and module.textinput then
        module.textinput(text)
    end
end

-- State management
function changeState(newState)
    previousState = GameState.current
    GameState.current = newState

    -- Initialize new state
    local module = stateModules[newState]
    if module and module.init then
        module.init()
    end
end
