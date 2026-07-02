-- Text-Based RPG Adventure - Card Quest
-- A fantasy text adventure with classes, quests, towns, and more!
-- ============================================================================
-- WIRING HARNESS: This file loads and wires together all RPG modules.
-- Game logic lives in rpg_*.lua modules; this file provides the glue.
-- ============================================================================

local TextRPG = {}

-- === EXTERNAL MODULE REQUIRES ===
local UI = require("ui")
local UIAssets = require("uiassets")
local Backpack = require("backpack")
local AutoPlay = require("autoplay")
local AutoTravel = require("auto_travel")
_G.AutoTravel = AutoTravel  -- Make globally accessible for worldgen, lore_books, etc
local LPCLoader = require("lpcloader")
local LPCTilemap = require("lpc_tilemap")
local PropertySystem = require("propertysystem")
local WorldMapOverlay = require("worldmapoverlay")
local MapEnemies = require("mapenemies")
local DungeonEnemies = require("dungeonenemies")
local TownNPCsVisible = require("townnpcsvisible")
local TownGen = require("towngen")
local PrisonEscape = require("prison_escape")
local Cutscenes = require("cutscenes")
local InteractiveTutorial = require("interactivetutorial")
local StealthSystem = nil
pcall(function() StealthSystem = require("stealth_system") end)
local LuminaryPatrols = require("luminarypatrols")
local WorldGen = require("worldgen")
local TileUtils = require("tileutils")

-- ============================================================================
-- TACTICAL COMBAT SYSTEM (FFT-Style Grid Combat)
-- Feature flag: Controls whether combat uses grid-based tactical mode
-- Players can toggle via Options menu or F9 key at any time
-- Setting is persisted in PlayerData.settings.tacticalCombat
-- ============================================================================
local TACTICAL_MODE = true  -- Default; overridden by PlayerData.settings on load

-- Tactical combat modules (loaded conditionally)
local TacticalCombat = nil
local TacticalUI = nil
local TacticalAI = nil

if TACTICAL_MODE then
    TacticalCombat = require("tactical_combat")
    TacticalUI = require("tactical_combat_ui")
    TacticalAI = require("tactical_combat_ai")
    TacticalAI.init(TacticalCombat)
    TacticalUI.init(TacticalCombat)
end

-- Active tactical combat state (nil when not in tactical combat)
local tacticalState = nil

-- === RPG MODULE REQUIRES ===
local Data = require("rpg_data")
local rpg_core = require("rpg_core")
local rpg_save = require("rpg_save")
local rpg_combat = require("rpg_combat")
local rpg_dungeon = require("rpg_dungeon")
local rpg_travel = require("rpg_travel")
local rpg_dialogue = require("rpg_dialogue")
local rpg_vampire = require("rpg_vampire")
local rpg_karma = require("rpg_karma")
local rpg_stats = require("rpg_stats")
local rpg_world = require("rpg_world")
local rpg_npc = require("rpg_npc")
local rpg_town = require("rpg_town")
local rpg_input = require("rpg_input")
local rpg_draw_creation = require("rpg_draw_creation")
local rpg_draw_world = require("rpg_draw_world")

-- ============================================================================
-- FUNCTION TABLE (shared across all modules via F-table pattern)
-- ============================================================================
local F = {}

-- Compatibility: Make F.functionName accessible as functionName using _G metatable
-- This allows existing code to call functionName() instead of F.functionName()
setmetatable(_G, {
    __index = function(t, k)
        if F[k] then return F[k] end
        return rawget(t, k)
    end
})

-- Forward declaration of state (initialized below)
local state

-- Graveyard for fallen heroes (persists across sessions)
local graveyard = {}

-- Sprite mode toggle
local spriteMode = false

-- ============================================================================
-- GAME STATE
-- ============================================================================
state = {
    phase = "class_select",  -- class_select, town, map, combat, dialogue, inventory, quest_log, job_board, npc_list, death
    player = nil,
    playerNameInput = "Adventurer",  -- Name input for character creation
    -- Character creation system
    characterCreation = {
        step = 1,  -- 1=race, 2=class, 3=background, 4=gender, 5=portrait/name, 6=review
        selectedRace = nil,
        selectedClass = nil,
        selectedBackground = nil,
        selectedGender = "Male",
        portraitIndex = 1,
        chosenBonusStats = {},  -- For races with choice stats (e.g. Human): {"MIGHT", "AGILITY"}
    },
    showCharacterSheet = false,
    showPartyUI = false,
    partyUIScroll = 0,
    showSkillTree = false,
    -- Quest compass / tracking
    activeQuestIndex = nil,
    -- District exploration
    currentDistrict = nil,
    -- Underbelly exploration
    currentUnderbelly = nil,
    underbellyFloor = 1,
    -- Guild hall state
    currentGuildHall = nil,
    showTalentSelection = false,
    showAscensionTree = false,
    selectedAscensionIndex = 1,
    ascensionScrollOffset = 0,
    showSpecializationSelection = false,
    -- Full world map overlay
    fullMapOpen = false,
    fullMapZoom = 1,
    fullMapPanX = 0,
    fullMapPanY = 0,
    -- Dev mode
    showDevModePrompt = false,
    devModePassword = "",
    devModeEnabled = false,
    selectedSkillIndex = 1,
    selectedTalentIndex = 1,
    selectedSpecIndex = 1,
    world = {
        mapData = {},
        mapWidth = 15,
        mapHeight = 15,
        towns = {},
        currentTown = nil,
        playerX = 7,
        playerY = 7,
        homeTown = nil,
        pathHistory = {},
    },
    travelingHome = {
        active = false,
        pathIndex = 0,
        timer = 0,
        stepDelay = 0.4,
        speedMult = 1.0,
        timePerTile = 1.0,
    },
    paidTravel = {
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
    },
    combat = {
        enemies = {},
        selectedTarget = 1,
        turnOrder = {},
        currentTurnIndex = 0,
        isPlayerTurn = true,
        log = {},
        showSkills = false,
        showWeaponSwap = false,
    },
    dialogue = {
        npc = nil,
        text = "",
        options = {},
    },
    scroll = 0,
    textLog = {},
    stats = {
        enemiesDefeated = 0,
        questsCompleted = 0,
        goldEarned = 0,
        itemsFound = 0,
        healingDone = 0,
        itemsCrafted = 0,
        stealthKills = 0,
        fishCaught = 0,
        deaths = 0,
        locationsVisited = {},
    },
    deathInfo = {
        killedBy = nil,
        location = nil,
    },
    -- Day/night cycle and seasons
    timeOfDay = 12,
    daysPassed = 0,
    season = "frosthollow",
    seasonIndex = 4,
    -- Trade system
    tradeRoutes = {},
    playerGoods = {},
    marketTab = "buy",
    -- Dungeon system
    dungeon = nil,
    inDungeon = false,
    -- Auto-play system
    autoPlay = AutoPlay.createDefaultState(),
    -- Prison escape system
    prisonEscape = nil,
    inPrisonEscape = false,
    -- UI components
    uiComponents = {},
}

-- ============================================================================
-- LOG FUNCTION
-- ============================================================================
local log
log = function(text, color)
    table.insert(state.textLog, {text = text, color = color or {0.8, 0.8, 0.8}, time = love.timer.getTime()})
    if #state.textLog > 100 then
        table.remove(state.textLog, 1)
    end
end
F.log = log

-- Provide log function to external modules
AutoPlay.setLogFunction(log)
LuminaryPatrols.setLogFunction(log)
MapEnemies.setLogFunction(log)

-- ============================================================================
-- MODULE REGISTRATION
-- Order: data-only modules first, then game systems, then UI/drawing, then input
-- ============================================================================

-- Shared tactical deps closure (avoids repeating closures for each module)
local tacticalDeps = {
    TacticalCombat = TacticalCombat,
    TacticalUI = TacticalUI,
    TacticalAI = TacticalAI,
    getTacticalState = function() return tacticalState end,
    setTacticalState = function(s) tacticalState = s end,
    getTacticalMode = function() return TACTICAL_MODE end,
    setTacticalMode = function(v) TACTICAL_MODE = v end,
}

-- Chatbot bridge (NPC free talk via external Python chatbot)
local ChatbotBridge = require("chatbot_bridge")

-- Simple modules (just state + F, no extra deps)
rpg_dialogue.register(state, F)
ChatbotBridge.register(state, F)
rpg_dungeon.register(state, F)
rpg_vampire.register(state, F)
rpg_karma.register(state, F)
rpg_npc.register(state, F)
rpg_town.register(state, F)
rpg_draw_world.register(state, F)

-- Stats system (needs Data tables)
rpg_stats.register(state, F, {
    CLASSES          = Data.CLASSES,
    RACES            = Data.RACES,
    UNLOCKABLE_RACES = Data.UNLOCKABLE_RACES,
    BACKGROUNDS      = Data.BACKGROUNDS,
    CLASS_BASE_STATS = Data.CLASS_BASE_STATS,
    STAT_DEFINITIONS = Data.STAT_DEFINITIONS,
    ASCENSION_CONFIG = Data.ASCENSION_CONFIG,
    ASCENSION_TREE   = Data.ASCENSION_TREE,
    SPECIALIZATIONS  = Data.SPECIALIZATIONS,
    TALENT_LOOKUP    = Data.TALENT_LOOKUP,
    REPUTATION_LEVELS = Data.REPUTATION_LEVELS,
    MAX_LEVEL        = Data.MAX_LEVEL,
    log = log,
})

-- Combat system (needs tactical refs + data)
rpg_combat.register(state, F, {
    TacticalCombat   = TacticalCombat,
    TacticalUI       = TacticalUI,
    TacticalAI       = TacticalAI,
    getTacticalState  = tacticalDeps.getTacticalState,
    setTacticalState  = tacticalDeps.setTacticalState,
    ENEMIES          = Data.ENEMIES,
    SKILLS           = Data.SKILLS,
    ENCOUNTER_TABLE  = Data.ENCOUNTER_TABLE,
    DAMAGE_TYPES     = Data.DAMAGE_TYPES,
    VAMPIRE_ENEMY_IDS = Data.VAMPIRE_ENEMY_IDS,
    UNDEAD_ENEMY_IDS = Data.UNDEAD_ENEMY_IDS,
    SEA_ENEMIES      = Data.SEA_ENEMIES,
    WEATHER_EFFECTS  = Data.WEATHER_EFFECTS,
    TACTICAL_MODE    = TACTICAL_MODE,
    LuminaryPatrols  = LuminaryPatrols,
    AutoPlay         = AutoPlay,
    graveyard        = graveyard,
})

-- Travel/camping system
rpg_travel.register(state, F, {
    ENEMIES  = Data.ENEMIES,
    TextRPG  = TextRPG,
    log      = log,
})

-- World generation & movement
rpg_world.register(state, F, {
    TOWN_PREFIXES       = Data.TOWN_PREFIXES,
    TOWN_SUFFIXES       = Data.TOWN_SUFFIXES,
    NPC_FIRST_NAMES     = Data.NPC_FIRST_NAMES,
    ENEMY_TIERS         = Data.ENEMY_TIERS,
    NPC_PROFESSIONS     = Data.NPC_PROFESSIONS,
    QUEST_ITEMS         = Data.QUEST_ITEMS,
    LOCATION_NAMES      = Data.LOCATION_NAMES,
    TILE_TYPES          = Data.TILE_TYPES,
    TRADE_GOODS         = Data.TRADE_GOODS,
    TOWN_SPECIALIZATIONS = Data.TOWN_SPECIALIZATIONS,
    SEA_ENEMIES         = Data.SEA_ENEMIES,
    WATER_EVENTS        = Data.WATER_EVENTS,
    SEA_MERCHANT_GOODS  = Data.SEA_MERCHANT_GOODS,
    DEBRIS_LOOT         = Data.DEBRIS_LOOT,
    UNDEAD_ENEMY_IDS    = Data.UNDEAD_ENEMY_IDS,
    log = log,
})

-- Core lifecycle (init, update, draw, resetGame, utils)
rpg_core.register(state, F, TextRPG, {
    TacticalCombat       = TacticalCombat,
    TacticalUI           = TacticalUI,
    TacticalAI           = TacticalAI,
    getTacticalState     = tacticalDeps.getTacticalState,
    setTacticalState     = tacticalDeps.setTacticalState,
    getTacticalMode      = tacticalDeps.getTacticalMode,
    setTacticalMode      = tacticalDeps.setTacticalMode,
    ENEMIES              = Data.ENEMIES,
    STEALTH_TIME_MODIFIERS = Data.STEALTH_TIME_MODIFIERS,
    JOURNAL_TABS         = Data.JOURNAL_TABS,
    REGIONAL_NPC_POOLS   = Data.REGIONAL_NPC_POOLS,
})

-- Save/load system
rpg_save.register(state, F, TextRPG, graveyard, Data.CLASS_BASE_STATS, log)

-- Drawing: character creation & sheet
rpg_draw_creation.register(state, F, {
    SKILL_TREES = Data.SKILL_TREES,
})

-- Input handlers (needs many module refs)
rpg_input.register({
    state            = state,
    F                = F,
    TextRPG          = TextRPG,
    UI               = UI,
    Backpack         = Backpack,
    PropertySystem   = PropertySystem,
    MapEnemies       = MapEnemies,
    DungeonEnemies   = DungeonEnemies,
    TacticalCombat   = TacticalCombat,
    TacticalUI       = TacticalUI,
    TacticalAI       = TacticalAI,
    StealthSystem    = StealthSystem,
    PrisonEscape     = PrisonEscape,
    WorldMapOverlay  = WorldMapOverlay,
    AutoTravel       = AutoTravel,
    AutoPlay         = AutoPlay,
    Cutscenes        = Cutscenes,
    InteractiveTutorial = InteractiveTutorial,
    LPCLoader        = LPCLoader,
    LPCTilemap       = LPCTilemap,
    TownNPCsVisible  = TownNPCsVisible,
    WorldGen         = WorldGen,
    TileUtils        = TileUtils,
    Data             = Data,
    getTacticalState = tacticalDeps.getTacticalState,
    setTacticalState = tacticalDeps.setTacticalState,
    getTacticalMode  = tacticalDeps.getTacticalMode,
    setTacticalMode  = tacticalDeps.setTacticalMode,
    getGraveyard     = function() return graveyard end,
    spriteMode       = function() return spriteMode end,
})

-- ============================================================================
-- TEXTRPG LIFECYCLE WIRING
-- ============================================================================
TextRPG.init = rpg_core.init
TextRPG.update = rpg_core.update
TextRPG.draw = rpg_core.draw

TextRPG.save = rpg_save.save
TextRPG.load = rpg_save.load
TextRPG.getSharedStats = rpg_save.getSharedStats
TextRPG.exit = rpg_save.exit
TextRPG.hasOverlayOpen = rpg_save.hasOverlayOpen
TextRPG.handleEscape = rpg_save.handleEscape

TextRPG.mousepressed = rpg_input.mousepressed
TextRPG.mousereleased = rpg_input.mousereleased
TextRPG.wheelmoved = rpg_input.wheelmoved
TextRPG.keypressed = rpg_input.keypressed
TextRPG.textinput = rpg_input.textinput
TextRPG.getUIRegion = rpg_input.getUIRegion

-- ============================================================================
-- EXPORTS
-- ============================================================================
-- Export the internal function table so other modules (e.g. auto_travel) can call F.movePlayer
TextRPG.F = F
TextRPG.addLog = log

return TextRPG
