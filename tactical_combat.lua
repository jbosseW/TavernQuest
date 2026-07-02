-- ============================================================================
-- TACTICAL GRID COMBAT ENGINE
-- Full FFT-Style 12x8 Tile-Based Tactical Combat System
-- ============================================================================
-- This module implements grid-based combat with:
--   - 12x8 tile battlefield
--   - A* pathfinding
--   - Movement system (move + action per turn)
--   - Range-based attacks (melee=1, ranged=3-5)
--   - Line-of-sight (Bresenham)
--   - Obstacles, walls, doors
--   - Height/terrain bonuses
--   - Flanking mechanics
--   - Multi-combatant turn order
-- ============================================================================

local TacticalCombat = {}

-- Shared utilities
local TileUtils = require("tileutils")
local MathUtil = require("mathutil")

-- Stealth system integration (loaded safely)
local StealthSystem = nil
pcall(function() StealthSystem = require("stealth_system") end)

-- ============================================================================
-- CONSTANTS
-- ============================================================================

TacticalCombat.GRID_WIDTH = 12
TacticalCombat.GRID_HEIGHT = 8
TacticalCombat.TILE_SIZE = 56   -- pixels per tile for rendering

-- Tile types
TacticalCombat.TILE_FLOOR = "floor"
TacticalCombat.TILE_WALL = "wall"
TacticalCombat.TILE_OBSTACLE = "obstacle"  -- low cover, blocks movement not LOS
TacticalCombat.TILE_DOOR = "door"          -- can be opened/closed
TacticalCombat.TILE_PIT = "pit"            -- impassable, blocks movement not LOS
TacticalCombat.TILE_WATER = "water"        -- slows movement (costs 2 move)
TacticalCombat.TILE_GRASS = "grass"        -- normal movement, grass terrain
TacticalCombat.TILE_SAND = "sand"          -- desert terrain, normal movement
TacticalCombat.TILE_SNOW = "snow"          -- arctic terrain, slightly slower
TacticalCombat.TILE_COBBLESTONE = "cobblestone"  -- town terrain

-- Height levels
TacticalCombat.HEIGHT_LOW = 0
TacticalCombat.HEIGHT_NORMAL = 1
TacticalCombat.HEIGHT_HIGH = 2

-- Terrain bonuses
TacticalCombat.TERRAIN = {
    floor =       { moveCost = 1, defBonus = 0, atkBonus = 0, name = "Floor" },
    wall =        { moveCost = 999, defBonus = 0, atkBonus = 0, name = "Wall" },
    obstacle =    { moveCost = 999, defBonus = 0.15, atkBonus = 0, name = "Obstacle" },
    door =        { moveCost = 1, defBonus = 0, atkBonus = 0, name = "Door" },
    pit =         { moveCost = 999, defBonus = 0, atkBonus = 0, name = "Pit" },
    water =       { moveCost = 2, defBonus = -0.10, atkBonus = 0, name = "Water" },
    rubble =      { moveCost = 2, defBonus = 0.10, atkBonus = 0, name = "Rubble" },
    grass =       { moveCost = 1, defBonus = 0, atkBonus = 0, name = "Grass" },
    sand =        { moveCost = 1, defBonus = 0, atkBonus = 0, name = "Sand" },
    snow =        { moveCost = 1.5, defBonus = 0, atkBonus = 0, name = "Snow" },
    cobblestone = { moveCost = 1, defBonus = 0, atkBonus = 0, name = "Cobblestone" },
}

-- Height bonuses
TacticalCombat.HEIGHT_BONUS = {
    -- attacker_height - target_height => damage multiplier
    [2] = 1.25,   -- 2 levels higher: +25% damage
    [1] = 1.10,   -- 1 level higher: +10% damage
    [0] = 1.00,   -- same level: normal
    [-1] = 0.90,  -- 1 level lower: -10% damage
    [-2] = 0.80,  -- 2 levels lower: -20% damage
}

-- Unit attack range types
TacticalCombat.RANGE_MELEE = 1
TacticalCombat.RANGE_SHORT = 2
TacticalCombat.RANGE_MEDIUM = 3
TacticalCombat.RANGE_LONG = 5
TacticalCombat.RANGE_MAGIC = 4

-- Default move ranges by archetype
TacticalCombat.MOVE_RANGES = {
    warrior = 3,
    mage = 2,
    rogue = 4,
    cleric = 2,
    ranger = 3,
    monk = 4,
    berserker = 3,
    thief = 4,
    -- Enemy defaults
    default = 3,
    slow = 2,
    fast = 4,
}

-- Default attack ranges by archetype
TacticalCombat.ATTACK_RANGES = {
    warrior = 1,
    mage = 4,
    rogue = 1,
    cleric = 3,
    ranger = 5,
    monk = 1,
    berserker = 1,
    thief = 1,
    -- Enemy defaults
    default = 1,
    ranged = 4,
    magic = 4,
}

-- Turn phases
TacticalCombat.PHASE_MOVE = "move"
TacticalCombat.PHASE_ACTION = "action"
TacticalCombat.PHASE_DONE = "done"
TacticalCombat.PHASE_ANIMATING = "animating"

-- ============================================================================
-- PHASE 10: ENVIRONMENTAL HAZARD TILE TYPES
-- ============================================================================
TacticalCombat.TILE_FIRE = "fire"        -- deals damage each turn
TacticalCombat.TILE_POISON = "poison"    -- poisons units standing on it
TacticalCombat.TILE_TRAP = "trap"        -- triggers once when stepped on
TacticalCombat.TILE_ICE = "ice"          -- slows movement (costs 2), chance to slip

-- Hazard tile terrain data
TacticalCombat.TERRAIN["fire"]   = { moveCost = 1, defBonus = 0, atkBonus = 0, name = "Fire",   hazardDmg = 8, hazardType = "fire" }
TacticalCombat.TERRAIN["poison"] = { moveCost = 1, defBonus = 0, atkBonus = 0, name = "Poison", hazardDmg = 5, hazardType = "poison" }
TacticalCombat.TERRAIN["trap"]   = { moveCost = 1, defBonus = 0, atkBonus = 0, name = "Trap",   hazardDmg = 12, hazardType = "trap" }
TacticalCombat.TERRAIN["ice"]    = { moveCost = 2, defBonus = -0.05, atkBonus = 0, name = "Ice", hazardType = "ice" }

-- ============================================================================
-- PHASE 7: STATUS EFFECTS (Balance-tuned)
-- ============================================================================
TacticalCombat.STATUS_EFFECTS = {
    slow =     { name = "Slow",     duration = 2, moveReduction = 1, color = {0.4, 0.5, 0.9} },
    stun =     { name = "Stun",     duration = 1, skipsAction = true, skipsBoth = true, color = {0.9, 0.9, 0.3} },
    root =     { name = "Root",     duration = 2, preventsMove = true, color = {0.5, 0.35, 0.2} },
    poison =   { name = "Poison",   duration = 3, dotDamage = 5, color = {0.4, 0.8, 0.3} },
    burn =     { name = "Burn",     duration = 2, dotDamage = 7, color = {0.9, 0.5, 0.2} },
    bleed =    { name = "Bleed",    duration = 3, dotDamage = 3, color = {0.8, 0.2, 0.2} },
    blessed =  { name = "Blessed",  duration = 3, atkBuff = 4, defBuff = 2, color = {0.9, 0.85, 0.4} },
    shield =   { name = "Shield",   duration = 2, damageReduction = 0.30, color = {0.4, 0.65, 0.9} },
    weaken =   { name = "Weaken",   duration = 2, atkDebuff = 3, color = {0.6, 0.4, 0.6} },
    marked =   { name = "Marked",   duration = 3, damageTakenMult = 1.25, color = {0.9, 0.3, 0.3} },
    dodge =    { name = "Evasion",  duration = 2, dodgeChance = 40, color = {0.7, 0.9, 0.7} },
    regen =    { name = "Regen",    duration = 3, hotHeal = 5, color = {0.3, 0.9, 0.5} },
    -- Stealth status effects
    hidden =   { name = "Hidden",   duration = 999, color = {0.3, 0.3, 0.5}, untargetable = true },
    smoke_zone = { name = "Smoke",  duration = 3, color = {0.5, 0.5, 0.5}, forcedLightLevel = "dark" },
}

-- ============================================================================
-- PHASE 7: BALANCE CONSTANTS
-- ============================================================================
TacticalCombat.BALANCE = {
    -- Damage formula: (ATK * atkMult - DEF * defMult + variance) * modifiers
    atkMultiplier = 1.2,        -- attack stat weight in damage
    defMultiplier = 0.8,        -- defense stat reduction weight
    minDamage = 1,              -- absolute minimum damage per hit
    varianceRange = 3,          -- +/- random variance
    -- Flanking
    flankBonus1 = 0.15,         -- 1 ally adjacent to target
    flankBonus2 = 0.30,         -- 2+ allies adjacent to target
    -- Level scaling for enemies
    levelScaleDmg = 0.05,       -- +5% damage per level difference
    -- Crit
    baseCritChance = 5,         -- default crit chance %
    baseCritDamage = 1.5,       -- default crit multiplier
    -- AI timing
    aiTurnDelay = 0.65,         -- seconds before AI acts
    aiAnimDelay = 0.35,         -- seconds between AI move and attack
}

-- ============================================================================
-- PHASE 10: INTERACTIVE OBJECT DEFINITIONS
-- ============================================================================
TacticalCombat.INTERACTIVE_OBJECTS = {
    barrel = {
        name = "Barrel",
        hp = 10,
        destroyedType = "rubble",
        blocksMove = true,
        blocksLOS = false,
        decoration = "barrel",
        dropChance = 0.3,
        dropEffect = "heal",   -- heal 10 HP on destroy
        dropAmount = 10,
    },
    crate = {
        name = "Crate",
        hp = 8,
        destroyedType = "rubble",
        blocksMove = true,
        blocksLOS = false,
        decoration = "crate",
        dropChance = 0.25,
        dropEffect = "mana",
        dropAmount = 8,
    },
    lever = {
        name = "Lever",
        hp = 999,          -- indestructible
        blocksMove = false,
        blocksLOS = false,
        decoration = "lever",
        interactable = true,
        activated = false,
        effect = "toggle_doors",  -- flips all doors on the map
    },
    explosive_barrel = {
        name = "Powder Keg",
        hp = 5,
        destroyedType = "fire",  -- creates fire tile when destroyed
        blocksMove = true,
        blocksLOS = false,
        decoration = "explosive_barrel",
        explosionRadius = 1,
        explosionDamage = 15,
    },
}

-- ============================================================================
-- PHASE 10: ELEVATION RANGE BONUS
-- ============================================================================
-- Ranged units on high ground get +1 attack range
TacticalCombat.ELEVATION_RANGE_BONUS = 1

-- ============================================================================
-- GRID CREATION & MAP GENERATION
-- ============================================================================

-- Create an empty grid
function TacticalCombat.createGrid(width, height)
    local grid = {
        width = width or TacticalCombat.GRID_WIDTH,
        height = height or TacticalCombat.GRID_HEIGHT,
        tiles = {},
    }

    for y = 1, grid.height do
        grid.tiles[y] = {}
        for x = 1, grid.width do
            grid.tiles[y][x] = {
                type = TacticalCombat.TILE_FLOOR,
                height = TacticalCombat.HEIGHT_NORMAL,
                unit = nil,       -- reference to unit occupying this tile
                decoration = nil, -- visual only (barrel, crate, etc.)
            }
        end
    end

    return grid
end

-- Generate a battlefield map with terrain features
function TacticalCombat.generateBattlefield(encounterType)
    local grid = TacticalCombat.createGrid()
    local w, h = grid.width, grid.height

    -- Different map layouts based on encounter type
    encounterType = encounterType or "open"

    if encounterType == "open" then
        -- Open field with a few scattered obstacles
        TacticalCombat._generateOpenField(grid)
    elseif encounterType == "dungeon" then
        -- Dungeon room with walls and corridors
        TacticalCombat._generateDungeonRoom(grid)
    elseif encounterType == "forest" then
        -- Forest clearing with trees
        TacticalCombat._generateForest(grid)
    elseif encounterType == "ruins" then
        -- Ruined building with walls and rubble
        TacticalCombat._generateRuins(grid)
    elseif encounterType == "bridge" then
        -- Narrow bridge encounter
        TacticalCombat._generateBridge(grid)
    -- THEMED MAPS
    elseif encounterType == "swamp" then
        TacticalCombat._generateSwamp(grid)
    elseif encounterType == "desert" then
        TacticalCombat._generateDesert(grid)
    elseif encounterType == "arctic" or encounterType == "ice" then
        TacticalCombat._generateArctic(grid)
    elseif encounterType == "mountain" then
        TacticalCombat._generateMountain(grid)
    elseif encounterType == "plains" or encounterType == "grass" then
        TacticalCombat._generatePlains(grid)
    elseif encounterType == "town" then
        TacticalCombat._generateTown(grid)
    elseif encounterType == "city" then
        TacticalCombat._generateCity(grid)
    elseif encounterType == "ocean" or encounterType == "ship" then
        TacticalCombat._generateShip(grid)
    elseif encounterType == "building_interior" then
        TacticalCombat._generateBuildingInterior(grid)
    else
        -- Default open field
        TacticalCombat._generateOpenField(grid)
    end

    return grid
end

function TacticalCombat._generateOpenField(grid)
    local w, h = grid.width, grid.height
    -- Scatter 3-6 obstacles
    local numObstacles = math.random(3, 6)
    for i = 1, numObstacles do
        local ox = math.random(3, w - 2)
        local oy = math.random(2, h - 1)
        grid.tiles[oy][ox].type = TacticalCombat.TILE_OBSTACLE
        grid.tiles[oy][ox].decoration = "rock"
    end

    -- Occasional height variation (1-2 raised tiles)
    local numHighGround = math.random(1, 2)
    for i = 1, numHighGround do
        local hx = math.random(4, w - 3)
        local hy = math.random(2, h - 1)
        grid.tiles[hy][hx].height = TacticalCombat.HEIGHT_HIGH
        -- Make adjacent tiles medium height for natural slope
        for _, d in ipairs({{0,1},{0,-1},{1,0},{-1,0}}) do
            local nx, ny = hx + d[1], hy + d[2]
            if nx >= 1 and nx <= w and ny >= 1 and ny <= h then
                if grid.tiles[ny][nx].type == TacticalCombat.TILE_FLOOR and
                   grid.tiles[ny][nx].height < TacticalCombat.HEIGHT_HIGH then
                    -- Leave as normal; the height difference creates tactical interest
                end
            end
        end
    end

    -- Occasional water patch
    if math.random() < 0.3 then
        local wx = math.random(4, w - 3)
        local wy = math.random(3, h - 2)
        for dy = -1, 1 do
            for dx = -1, 1 do
                if math.random() < 0.6 then
                    local tx, ty = wx + dx, wy + dy
                    if tx >= 1 and tx <= w and ty >= 1 and ty <= h then
                        grid.tiles[ty][tx].type = TacticalCombat.TILE_WATER
                    end
                end
            end
        end
    end
end

function TacticalCombat._generateDungeonRoom(grid)
    local w, h = grid.width, grid.height

    -- Border walls
    for x = 1, w do
        grid.tiles[1][x].type = TacticalCombat.TILE_WALL
        grid.tiles[h][x].type = TacticalCombat.TILE_WALL
    end
    for y = 1, h do
        grid.tiles[y][1].type = TacticalCombat.TILE_WALL
        grid.tiles[y][w].type = TacticalCombat.TILE_WALL
    end

    -- Door on left wall (entrance)
    local doorY = math.random(3, h - 2)
    grid.tiles[doorY][1].type = TacticalCombat.TILE_DOOR

    -- Internal pillars or walls
    local numPillars = math.random(2, 4)
    for i = 1, numPillars do
        local px = math.random(4, w - 3)
        local py = math.random(3, h - 2)
        grid.tiles[py][px].type = TacticalCombat.TILE_WALL
    end

    -- Scatter some rubble
    for i = 1, math.random(2, 4) do
        local rx = math.random(3, w - 2)
        local ry = math.random(3, h - 2)
        if grid.tiles[ry][rx].type == TacticalCombat.TILE_FLOOR then
            grid.tiles[ry][rx].type = "rubble"
        end
    end
end

function TacticalCombat._generateForest(grid)
    local w, h = grid.width, grid.height

    -- Scatter trees (as obstacles)
    local numTrees = math.random(6, 10)
    for i = 1, numTrees do
        local tx = math.random(2, w - 1)
        local ty = math.random(2, h - 1)
        -- Don't place trees where units will spawn (left 3 cols, right 3 cols)
        if tx >= 4 and tx <= w - 3 then
            grid.tiles[ty][tx].type = TacticalCombat.TILE_OBSTACLE
            grid.tiles[ty][tx].decoration = "tree"
        end
    end

    -- Small clearing in the middle
    local cx, cy = math.floor(w / 2), math.floor(h / 2)
    for dy = -1, 1 do
        for dx = -1, 1 do
            local nx, ny = cx + dx, cy + dy
            if nx >= 1 and nx <= w and ny >= 1 and ny <= h then
                grid.tiles[ny][nx].type = TacticalCombat.TILE_FLOOR
                grid.tiles[ny][nx].decoration = "grass"
            end
        end
    end

    -- Height: slight hill somewhere
    if math.random() < 0.5 then
        local hx = math.random(4, w - 3)
        local hy = math.random(3, h - 2)
        if grid.tiles[hy][hx].type == TacticalCombat.TILE_FLOOR then
            grid.tiles[hy][hx].height = TacticalCombat.HEIGHT_HIGH
        end
    end
end

function TacticalCombat._generateRuins(grid)
    local w, h = grid.width, grid.height

    -- Partial walls (L-shapes, broken walls)
    -- Left structure
    for y = 2, 4 do
        grid.tiles[y][3].type = TacticalCombat.TILE_WALL
    end
    grid.tiles[2][4].type = TacticalCombat.TILE_WALL
    grid.tiles[2][5].type = TacticalCombat.TILE_WALL

    -- Right structure
    for y = 5, 7 do
        grid.tiles[y][w - 2].type = TacticalCombat.TILE_WALL
    end
    grid.tiles[7][w - 3].type = TacticalCombat.TILE_WALL
    grid.tiles[7][w - 4].type = TacticalCombat.TILE_WALL

    -- Central rubble
    for i = 1, math.random(4, 7) do
        local rx = math.random(4, w - 3)
        local ry = math.random(2, h - 1)
        if grid.tiles[ry][rx].type == TacticalCombat.TILE_FLOOR then
            grid.tiles[ry][rx].type = "rubble"
        end
    end

    -- A raised platform
    grid.tiles[4][6].height = TacticalCombat.HEIGHT_HIGH
    grid.tiles[4][7].height = TacticalCombat.HEIGHT_HIGH
    grid.tiles[5][6].height = TacticalCombat.HEIGHT_HIGH
    grid.tiles[5][7].height = TacticalCombat.HEIGHT_HIGH
end

function TacticalCombat._generateBridge(grid)
    local w, h = grid.width, grid.height

    -- Water everywhere except a bridge path
    for y = 1, h do
        for x = 1, w do
            grid.tiles[y][x].type = TacticalCombat.TILE_PIT
        end
    end

    -- Solid ground on left side (ally spawn area)
    for y = 1, h do
        for x = 1, 3 do
            grid.tiles[y][x].type = TacticalCombat.TILE_FLOOR
        end
    end

    -- Solid ground on right side (enemy spawn area)
    for y = 1, h do
        for x = w - 2, w do
            grid.tiles[y][x].type = TacticalCombat.TILE_FLOOR
        end
    end

    -- Bridge across the middle (2 tiles wide)
    local bridgeY1 = math.floor(h / 2)
    local bridgeY2 = bridgeY1 + 1
    for x = 1, w do
        grid.tiles[bridgeY1][x].type = TacticalCombat.TILE_FLOOR
        grid.tiles[bridgeY2][x].type = TacticalCombat.TILE_FLOOR
    end

    -- Optional second narrow bridge
    if math.random() < 0.5 then
        local bridgeY3 = math.random() < 0.5 and 2 or (h - 1)
        for x = 4, w - 3 do
            grid.tiles[bridgeY3][x].type = TacticalCombat.TILE_FLOOR
        end
    end
end

-- ============================================================================
-- THEMED MAP GENERATORS
-- ============================================================================

function TacticalCombat._generateSwamp(grid)
    local w, h = grid.width, grid.height

    -- Murky water patches scattered across the battlefield
    for i = 1, math.random(5, 8) do
        local wx = math.random(2, w - 1)
        local wy = math.random(2, h - 1)
        for dy = -1, 1 do
            for dx = -1, 1 do
                local tx, ty = wx + dx, wy + dy
                if tx >= 1 and tx <= w and ty >= 1 and ty <= h and math.random() < 0.7 then
                    grid.tiles[ty][tx].type = TacticalCombat.TILE_WATER
                    grid.tiles[ty][tx].decoration = "murky_water"
                end
            end
        end
    end

    -- Logs as obstacles (can take cover behind)
    for i = 1, math.random(4, 6) do
        local lx = math.random(3, w - 2)
        local ly = math.random(2, h - 1)
        if grid.tiles[ly][lx].type == TacticalCombat.TILE_FLOOR then
            grid.tiles[ly][lx].type = TacticalCombat.TILE_OBSTACLE
            grid.tiles[ly][lx].decoration = "log"
        end
    end

    -- Poison patches (hazards)
    for i = 1, math.random(2, 4) do
        local px = math.random(4, w - 3)
        local py = math.random(3, h - 2)
        if grid.tiles[py][px].type == TacticalCombat.TILE_FLOOR then
            grid.tiles[py][px].type = TacticalCombat.TILE_POISON
            grid.tiles[py][px].decoration = "toxic_fungi"
        end
    end

    -- Moss-covered stones
    for i = 1, math.random(3, 5) do
        local mx = math.random(3, w - 2)
        local my = math.random(2, h - 1)
        if grid.tiles[my][mx].type == TacticalCombat.TILE_FLOOR then
            grid.tiles[my][mx].decoration = "moss_stone"
        end
    end
end

function TacticalCombat._generateDesert(grid)
    local w, h = grid.width, grid.height

    -- All floor tiles become sand
    for y = 1, h do
        for x = 1, w do
            if grid.tiles[y][x].type == TacticalCombat.TILE_FLOOR then
                grid.tiles[y][x].decoration = "sand"
            end
        end
    end

    -- Rock formations
    for i = 1, math.random(5, 8) do
        local rx = math.random(3, w - 2)
        local ry = math.random(2, h - 1)
        grid.tiles[ry][rx].type = TacticalCombat.TILE_OBSTACLE
        grid.tiles[ry][rx].decoration = "desert_rock"
    end

    -- Cacti
    for i = 1, math.random(3, 6) do
        local cx = math.random(3, w - 2)
        local cy = math.random(2, h - 1)
        if grid.tiles[cy][cx].type == TacticalCombat.TILE_FLOOR then
            grid.tiles[cy][cx].type = TacticalCombat.TILE_OBSTACLE
            grid.tiles[cy][cx].decoration = "cactus"
        end
    end

    -- Sand dunes (raised areas)
    for i = 1, math.random(2, 3) do
        local dx = math.random(4, w - 3)
        local dy = math.random(3, h - 2)
        grid.tiles[dy][dx].height = TacticalCombat.HEIGHT_HIGH
        grid.tiles[dy][dx].decoration = "sand_dune"
    end

    -- Occasional fire hazard (heat shimmer/mirage)
    if math.random() < 0.3 then
        local fx = math.random(5, w - 4)
        local fy = math.random(4, h - 3)
        grid.tiles[fy][fx].type = TacticalCombat.TILE_FIRE
        grid.tiles[fy][fx].decoration = "heat_haze"
    end
end

function TacticalCombat._generateArctic(grid)
    local w, h = grid.width, grid.height

    -- All floor tiles become snow
    for y = 1, h do
        for x = 1, w do
            if grid.tiles[y][x].type == TacticalCombat.TILE_FLOOR then
                grid.tiles[y][x].decoration = "snow"
            end
        end
    end

    -- Ice patches (slippery)
    for i = 1, math.random(4, 7) do
        local ix = math.random(3, w - 2)
        local iy = math.random(2, h - 1)
        for dy = -1, 1 do
            for dx = -1, 1 do
                local tx, ty = ix + dx, iy + dy
                if tx >= 1 and tx <= w and ty >= 1 and ty <= h and math.random() < 0.6 then
                    grid.tiles[ty][tx].type = TacticalCombat.TILE_ICE
                    grid.tiles[ty][tx].decoration = "ice"
                end
            end
        end
    end

    -- Snowdrifts (obstacles)
    for i = 1, math.random(4, 6) do
        local sx = math.random(3, w - 2)
        local sy = math.random(2, h - 1)
        if grid.tiles[sy][sx].type == TacticalCombat.TILE_FLOOR then
            grid.tiles[sy][sx].type = TacticalCombat.TILE_OBSTACLE
            grid.tiles[sy][sx].decoration = "snowdrift"
        end
    end

    -- Frozen boulders
    for i = 1, math.random(3, 5) do
        local bx = math.random(3, w - 2)
        local by = math.random(2, h - 1)
        if grid.tiles[by][bx].type == TacticalCombat.TILE_FLOOR then
            grid.tiles[by][bx].type = TacticalCombat.TILE_OBSTACLE
            grid.tiles[by][bx].decoration = "ice_boulder"
        end
    end
end

function TacticalCombat._generateMountain(grid)
    local w, h = grid.width, grid.height

    -- Rocky terrain base
    for y = 1, h do
        for x = 1, w do
            if grid.tiles[y][x].type == TacticalCombat.TILE_FLOOR then
                grid.tiles[y][x].decoration = "rocky_ground"
            end
        end
    end

    -- Multiple height levels (cliffs)
    for i = 1, math.random(3, 5) do
        local hx = math.random(4, w - 3)
        local hy = math.random(3, h - 2)
        grid.tiles[hy][hx].height = TacticalCombat.HEIGHT_HIGH
        grid.tiles[hy][hx].decoration = "cliff"

        -- Adjacent tiles become medium height (slope)
        for _, d in ipairs({{0,1},{0,-1},{1,0},{-1,0}}) do
            local nx, ny = hx + d[1], hy + d[2]
            if nx >= 1 and nx <= w and ny >= 1 and ny <= h then
                if grid.tiles[ny][nx].type == TacticalCombat.TILE_FLOOR and grid.tiles[ny][nx].height < TacticalCombat.HEIGHT_HIGH then
                    -- Leave at normal height for tactical cliff advantage
                end
            end
        end
    end

    -- Large boulders
    for i = 1, math.random(6, 9) do
        local bx = math.random(3, w - 2)
        local by = math.random(2, h - 1)
        grid.tiles[by][bx].type = TacticalCombat.TILE_OBSTACLE
        grid.tiles[by][bx].decoration = "boulder"
    end

    -- Loose rocks (rubble)
    for i = 1, math.random(4, 6) do
        local rx = math.random(3, w - 2)
        local ry = math.random(2, h - 1)
        if grid.tiles[ry][rx].type == TacticalCombat.TILE_FLOOR then
            grid.tiles[ry][rx].type = "rubble"
            grid.tiles[ry][rx].decoration = "loose_rocks"
        end
    end
end

function TacticalCombat._generatePlains(grid)
    local w, h = grid.width, grid.height

    -- Grass everywhere
    for y = 1, h do
        for x = 1, w do
            if grid.tiles[y][x].type == TacticalCombat.TILE_FLOOR then
                grid.tiles[y][x].type = TacticalCombat.TILE_GRASS
                grid.tiles[y][x].decoration = "grass"
            end
        end
    end

    -- Occasional bushes (low cover)
    for i = 1, math.random(5, 8) do
        local bx = math.random(3, w - 2)
        local by = math.random(2, h - 1)
        if grid.tiles[by][bx].type == TacticalCombat.TILE_GRASS then
            grid.tiles[by][bx].type = TacticalCombat.TILE_OBSTACLE
            grid.tiles[by][bx].decoration = "bush"
        end
    end

    -- Few scattered rocks
    for i = 1, math.random(2, 4) do
        local rx = math.random(3, w - 2)
        local ry = math.random(2, h - 1)
        if grid.tiles[ry][rx].type == TacticalCombat.TILE_GRASS then
            grid.tiles[ry][rx].type = TacticalCombat.TILE_OBSTACLE
            grid.tiles[ry][rx].decoration = "rock"
        end
    end

    -- Gentle hill (slight elevation)
    if math.random() < 0.5 then
        local hx = math.random(5, w - 4)
        local hy = math.random(4, h - 3)
        grid.tiles[hy][hx].height = TacticalCombat.HEIGHT_HIGH
        grid.tiles[hy][hx].decoration = "hilltop"
    end
end

function TacticalCombat._generateTown(grid)
    local w, h = grid.width, grid.height

    -- Cobblestone streets
    for y = 1, h do
        for x = 1, w do
            if grid.tiles[y][x].type == TacticalCombat.TILE_FLOOR then
                grid.tiles[y][x].decoration = "cobblestone"
            end
        end
    end

    -- Fences
    for i = 1, math.random(2, 4) do
        local fx = math.random(3, w - 2)
        local fy = math.random(2, h - 1)
        grid.tiles[fy][fx].type = TacticalCombat.TILE_OBSTACLE
        grid.tiles[fy][fx].decoration = "fence"
    end

    -- Barrels (destructible)
    for i = 1, math.random(3, 5) do
        local bx = math.random(3, w - 2)
        local by = math.random(2, h - 1)
        if grid.tiles[by][bx].type == TacticalCombat.TILE_FLOOR then
            grid.tiles[by][bx].type = TacticalCombat.TILE_OBSTACLE
            grid.tiles[by][bx].decoration = "barrel"
            grid.tiles[by][bx].interactiveObject = {
                type = "barrel",
                name = "Barrel",
                hp = 5,
                maxHP = 5,
                template = {name = "Barrel", hp = 5, decoration = "barrel", destructible = true},
                activated = false,
            }
        end
    end

    -- Crates (destructible)
    for i = 1, math.random(2, 4) do
        local cx = math.random(3, w - 2)
        local cy = math.random(2, h - 1)
        if grid.tiles[cy][cx].type == TacticalCombat.TILE_FLOOR then
            grid.tiles[cy][cx].type = TacticalCombat.TILE_OBSTACLE
            grid.tiles[cy][cx].decoration = "crate"
            grid.tiles[cy][cx].interactiveObject = {
                type = "crate",
                name = "Crate",
                hp = 8,
                maxHP = 8,
                template = {name = "Crate", hp = 8, decoration = "crate", destructible = true},
                activated = false,
            }
        end
    end

    -- Market stalls
    for i = 1, math.random(1, 3) do
        local mx = math.random(4, w - 3)
        local my = math.random(3, h - 2)
        if grid.tiles[my][mx].type == TacticalCombat.TILE_FLOOR then
            grid.tiles[my][mx].type = TacticalCombat.TILE_OBSTACLE
            grid.tiles[my][mx].decoration = "market_stall"
        end
    end
end

function TacticalCombat._generateCity(grid)
    local w, h = grid.width, grid.height

    -- Stone floors
    for y = 1, h do
        for x = 1, w do
            if grid.tiles[y][x].type == TacticalCombat.TILE_FLOOR then
                grid.tiles[y][x].decoration = "stone_floor"
            end
        end
    end

    -- Building walls
    for i = 1, math.random(3, 5) do
        local wx = math.random(3, w - 2)
        local wy = math.random(2, h - 1)
        -- Create wall segments
        local wallLength = math.random(2, 4)
        local horizontal = math.random() < 0.5
        for j = 0, wallLength - 1 do
            local tx, ty
            if horizontal then
                tx, ty = wx + j, wy
            else
                tx, ty = wx, wy + j
            end
            if tx >= 1 and tx <= w and ty >= 1 and ty <= h then
                grid.tiles[ty][tx].type = TacticalCombat.TILE_WALL
                grid.tiles[ty][tx].decoration = "stone_wall"
            end
        end
    end

    -- Barrels and crates (urban cover)
    for i = 1, math.random(4, 6) do
        local bx = math.random(3, w - 2)
        local by = math.random(2, h - 1)
        if grid.tiles[by][bx].type == TacticalCombat.TILE_FLOOR then
            grid.tiles[by][bx].type = TacticalCombat.TILE_OBSTACLE
            local decName = math.random() < 0.5 and "barrel" or "crate"
            grid.tiles[by][bx].decoration = decName
            grid.tiles[by][bx].interactiveObject = {
                type = decName,
                name = decName:sub(1,1):upper() .. decName:sub(2),
                hp = decName == "barrel" and 5 or 8,
                maxHP = decName == "barrel" and 5 or 8,
                template = {name = decName:sub(1,1):upper() .. decName:sub(2), hp = decName == "barrel" and 5 or 8, decoration = decName, destructible = true},
                activated = false,
            }
        end
    end

    -- Alleyways (narrow passages)
    if math.random() < 0.5 then
        local alleyX = math.random(5, w - 4)
        for y = 2, h - 1 do
            if grid.tiles[y][alleyX].type == TacticalCombat.TILE_WALL then
                grid.tiles[y][alleyX].type = TacticalCombat.TILE_FLOOR
                grid.tiles[y][alleyX].decoration = "alley"
            end
        end
    end
end

function TacticalCombat._generateShip(grid)
    local w, h = grid.width, grid.height

    -- Wooden deck
    for y = 2, h - 1 do
        for x = 3, w - 2 do
            grid.tiles[y][x].decoration = "wooden_deck"
        end
    end

    -- Water around edges
    for y = 1, h do
        grid.tiles[y][1].type = TacticalCombat.TILE_WATER
        grid.tiles[y][2].type = TacticalCombat.TILE_WATER
        grid.tiles[y][w].type = TacticalCombat.TILE_WATER
        grid.tiles[y][w - 1].type = TacticalCombat.TILE_WATER
    end
    for x = 1, w do
        grid.tiles[1][x].type = TacticalCombat.TILE_WATER
        grid.tiles[h][x].type = TacticalCombat.TILE_WATER
    end

    -- Ship railings (obstacles)
    for y = 2, h - 1 do
        if grid.tiles[y][3].type == TacticalCombat.TILE_FLOOR then
            grid.tiles[y][3].type = TacticalCombat.TILE_OBSTACLE
            grid.tiles[y][3].decoration = "railing"
        end
        if grid.tiles[y][w - 2].type == TacticalCombat.TILE_FLOOR then
            grid.tiles[y][w - 2].type = TacticalCombat.TILE_OBSTACLE
            grid.tiles[y][w - 2].decoration = "railing"
        end
    end

    -- Mast (tall obstacle)
    local mastX = math.floor(w / 2)
    local mastY = math.floor(h / 2)
    grid.tiles[mastY][mastX].type = TacticalCombat.TILE_OBSTACLE
    grid.tiles[mastY][mastX].decoration = "mast"
    grid.tiles[mastY][mastX].height = TacticalCombat.HEIGHT_HIGH

    -- Barrels on deck
    for i = 1, math.random(3, 5) do
        local bx = math.random(4, w - 3)
        local by = math.random(3, h - 2)
        if grid.tiles[by][bx].type == TacticalCombat.TILE_FLOOR then
            grid.tiles[by][bx].type = TacticalCombat.TILE_OBSTACLE
            grid.tiles[by][bx].decoration = "barrel"
            grid.tiles[by][bx].interactiveObject = {
                type = "barrel",
                name = "Barrel",
                hp = 5,
                maxHP = 5,
                template = {name = "Barrel", hp = 5, decoration = "barrel", destructible = true},
                activated = false,
            }
        end
    end
end

function TacticalCombat._generateBuildingInterior(grid)
    local w, h = grid.width, grid.height

    -- Wooden floor
    for y = 1, h do
        for x = 1, w do
            if grid.tiles[y][x].type == TacticalCombat.TILE_FLOOR then
                grid.tiles[y][x].decoration = "wooden_floor"
            end
        end
    end

    -- Outer walls
    for x = 1, w do
        grid.tiles[1][x].type = TacticalCombat.TILE_WALL
        grid.tiles[h][x].type = TacticalCombat.TILE_WALL
    end
    for y = 1, h do
        grid.tiles[y][1].type = TacticalCombat.TILE_WALL
        grid.tiles[y][w].type = TacticalCombat.TILE_WALL
    end

    -- Door
    local doorY = math.random(3, h - 2)
    grid.tiles[doorY][1].type = TacticalCombat.TILE_DOOR
    grid.tiles[doorY][1].decoration = "door"

    -- Internal walls (rooms)
    if math.random() < 0.6 then
        local wallX = math.floor(w / 2)
        for y = 2, h - 1 do
            if math.random() < 0.7 then -- Leave gaps for doorways
                grid.tiles[y][wallX].type = TacticalCombat.TILE_WALL
            end
        end
    end

    -- Furniture (tables, chairs as obstacles)
    for i = 1, math.random(4, 7) do
        local fx = math.random(3, w - 2)
        local fy = math.random(3, h - 2)
        if grid.tiles[fy][fx].type == TacticalCombat.TILE_FLOOR then
            grid.tiles[fy][fx].type = TacticalCombat.TILE_OBSTACLE
            local furniture = {"table", "chair", "bookshelf", "bed"}
            grid.tiles[fy][fx].decoration = furniture[math.random(#furniture)]
        end
    end

    -- Crates/barrels
    for i = 1, math.random(2, 4) do
        local cx = math.random(3, w - 2)
        local cy = math.random(3, h - 2)
        if grid.tiles[cy][cx].type == TacticalCombat.TILE_FLOOR then
            grid.tiles[cy][cx].type = TacticalCombat.TILE_OBSTACLE
            local decName = math.random() < 0.5 and "crate" or "barrel"
            grid.tiles[cy][cx].decoration = decName
            grid.tiles[cy][cx].interactiveObject = {
                type = decName,
                name = decName:sub(1,1):upper() .. decName:sub(2),
                hp = decName == "barrel" and 5 or 8,
                maxHP = decName == "barrel" and 5 or 8,
                template = {name = decName:sub(1,1):upper() .. decName:sub(2), hp = decName == "barrel" and 5 or 8, decoration = decName, destructible = true},
                activated = false,
            }
        end
    end

    -- Stealth system: generate building lighting (light sources, per-tile light levels)
    if StealthSystem then
        local timeOfDay = "day"  -- Default; will be overridden by combat init if available
        grid.stealthRooms = StealthSystem.generateBuildingLighting(grid, timeOfDay)
        -- Collect all light sources for UI rendering
        grid.lightSources = {}
        if grid.stealthRooms then
            for _, room in ipairs(grid.stealthRooms) do
                for _, source in ipairs(room.lightSources) do
                    table.insert(grid.lightSources, {
                        x = source.x,
                        y = source.y,
                        type = source.type,
                        radius = (source.template and source.template.lightRadius) or 3,
                        brightness = (source.template and source.template.brightness) or 1.0,
                        active = source.isLit,
                        canSnuff = source.canSnuff or false,
                        noiseChance = (source.template and source.template.snuffNoise) or 0,
                        name = source.name or "Light",
                        icon = (source.template and source.template.icon) or "?",
                        color = (source.template and source.template.color) or {1, 1, 1},
                        source = source,  -- Reference for snuffing
                    })
                end
            end
        end
    end
end

-- ============================================================================
-- TILE UTILITIES
-- ============================================================================

function TacticalCombat.isValidTile(grid, x, y)
    return x >= 1 and x <= grid.width and y >= 1 and y <= grid.height
end

function TacticalCombat.getTile(grid, x, y)
    if not TacticalCombat.isValidTile(grid, x, y) then return nil end
    return grid.tiles[y][x]
end

function TacticalCombat.isTilePassable(grid, x, y)
    if not TacticalCombat.isValidTile(grid, x, y) then return false end
    local tile = grid.tiles[y][x]
    local tileType = tile.type
    if tileType == TacticalCombat.TILE_WALL then return false end
    if tileType == TacticalCombat.TILE_PIT then return false end
    if tileType == TacticalCombat.TILE_OBSTACLE then return false end
    if tile.unit then return false end  -- occupied by unit
    return true
end

function TacticalCombat.isTileBlocksLOS(grid, x, y)
    if not TacticalCombat.isValidTile(grid, x, y) then return true end
    local tile = grid.tiles[y][x]
    return tile.type == TacticalCombat.TILE_WALL
end

function TacticalCombat.getMoveCost(grid, x, y)
    if not TacticalCombat.isValidTile(grid, x, y) then return 999 end
    local tile = grid.tiles[y][x]
    local terrainData = TacticalCombat.TERRAIN[tile.type]
    if terrainData then
        return terrainData.moveCost
    end
    return 1
end

function TacticalCombat.getUnitAt(grid, x, y)
    if not TacticalCombat.isValidTile(grid, x, y) then return nil end
    return grid.tiles[y][x].unit
end

-- ============================================================================
-- A* PATHFINDING
-- ============================================================================

-- Manhattan distance heuristic (delegates to shared MathUtil via TacticalCombat.getDistance)
local function heuristic(x1, y1, x2, y2)
    return math.abs(x2 - x1) + math.abs(y2 - y1)
end

-- A* pathfinding - finds shortest path from (sx,sy) to (ex,ey)
-- Returns: array of {x,y} nodes forming the path, or nil if no path
function TacticalCombat.findPath(grid, sx, sy, ex, ey, maxDist)
    maxDist = maxDist or 999

    -- Validate endpoints
    if not TacticalCombat.isValidTile(grid, sx, sy) then return nil end
    if not TacticalCombat.isValidTile(grid, ex, ey) then return nil end

    -- Target must be passable (or be the start position)
    local targetTile = grid.tiles[ey][ex]
    if targetTile.type == TacticalCombat.TILE_WALL or
       targetTile.type == TacticalCombat.TILE_PIT or
       targetTile.type == TacticalCombat.TILE_OBSTACLE then
        return nil
    end

    -- If target is occupied by another unit, we cannot path there
    if targetTile.unit and (ex ~= sx or ey ~= sy) then
        return nil
    end

    -- A* data structures
    local openSet = {}     -- nodes to explore (min-heap by fScore)
    local closedSet = {}   -- explored nodes
    local gScore = {}      -- cost from start to node
    local fScore = {}      -- estimated total cost through node
    local cameFrom = {}    -- path reconstruction

    local function key(x, y) return y * 10000 + x end

    local startKey = key(sx, sy)
    gScore[startKey] = 0
    fScore[startKey] = heuristic(sx, sy, ex, ey)
    table.insert(openSet, {x = sx, y = sy, f = fScore[startKey]})

    -- Neighbor offsets (4-directional movement)
    local neighbors = TileUtils.DIRS4

    while #openSet > 0 do
        -- Find node with lowest fScore
        local bestIdx = 1
        for i = 2, #openSet do
            if openSet[i].f < openSet[bestIdx].f then
                bestIdx = i
            end
        end
        local current = table.remove(openSet, bestIdx)
        local cx, cy = current.x, current.y
        local cKey = key(cx, cy)

        -- Reached goal
        if cx == ex and cy == ey then
            -- Reconstruct path
            local path = {{x = cx, y = cy}}
            local k = cKey
            while cameFrom[k] do
                k = cameFrom[k]
                local py = math.floor(k / 10000)
                local px = k - py * 10000
                table.insert(path, 1, {x = px, y = py})
            end
            return path
        end

        closedSet[cKey] = true

        -- Explore neighbors
        for _, n in ipairs(neighbors) do
            local nx, ny = cx + n[1], cy + n[2]
            local nKey = key(nx, ny)

            if not closedSet[nKey] and TacticalCombat.isValidTile(grid, nx, ny) then
                local moveCost = TacticalCombat.getMoveCost(grid, nx, ny)
                local nTile = grid.tiles[ny][nx]

                -- Skip impassable tiles
                local canPass = moveCost < 999
                -- Skip occupied tiles (unless it's the destination)
                if nTile.unit and (nx ~= ex or ny ~= ey) then
                    canPass = false
                end

                if canPass then
                    local tentativeG = gScore[cKey] + moveCost

                    -- Check max distance constraint
                    if tentativeG <= maxDist then
                        if not gScore[nKey] or tentativeG < gScore[nKey] then
                            cameFrom[nKey] = cKey
                            gScore[nKey] = tentativeG
                            fScore[nKey] = tentativeG + heuristic(nx, ny, ex, ey)

                            -- Add to open set if not already there
                            local inOpen = false
                            for _, node in ipairs(openSet) do
                                if node.x == nx and node.y == ny then
                                    node.f = fScore[nKey]
                                    inOpen = true
                                    break
                                end
                            end
                            if not inOpen then
                                table.insert(openSet, {x = nx, y = ny, f = fScore[nKey]})
                            end
                        end
                    end
                end
            end
        end
    end

    return nil  -- No path found
end

-- Get all tiles reachable within a given move distance (BFS)
function TacticalCombat.getMovementRange(grid, sx, sy, moveDistance)
    local reachable = {}
    local visited = {}
    local queue = {{x = sx, y = sy, cost = 0}}
    local neighbors = TileUtils.DIRS4

    local function key(x, y) return y * 10000 + x end
    visited[key(sx, sy)] = true

    while #queue > 0 do
        local current = table.remove(queue, 1)

        table.insert(reachable, {x = current.x, y = current.y, cost = current.cost})

        if current.cost < moveDistance then
            for _, n in ipairs(neighbors) do
                local nx, ny = current.x + n[1], current.y + n[2]
                local nKey = key(nx, ny)

                if not visited[nKey] and TacticalCombat.isValidTile(grid, nx, ny) then
                    local moveCost = TacticalCombat.getMoveCost(grid, nx, ny)
                    local nTile = grid.tiles[ny][nx]
                    local newCost = current.cost + moveCost

                    -- Can pass through if tile is passable and within range
                    if moveCost < 999 and not nTile.unit and newCost <= moveDistance then
                        visited[nKey] = true
                        table.insert(queue, {x = nx, y = ny, cost = newCost})
                    end
                end
            end
        end
    end

    return reachable
end

-- Get all tiles within attack range (Manhattan distance)
function TacticalCombat.getAttackRange(grid, sx, sy, minRange, maxRange)
    local tiles = {}
    minRange = minRange or 1
    maxRange = maxRange or 1

    for dy = -maxRange, maxRange do
        for dx = -maxRange, maxRange do
            local dist = math.abs(dx) + math.abs(dy)
            if dist >= minRange and dist <= maxRange then
                local tx, ty = sx + dx, sy + dy
                if TacticalCombat.isValidTile(grid, tx, ty) then
                    table.insert(tiles, {x = tx, y = ty, distance = dist})
                end
            end
        end
    end

    return tiles
end

-- ============================================================================
-- LINE OF SIGHT (Bresenham's Line Algorithm)
-- ============================================================================

function TacticalCombat.hasLineOfSight(grid, x1, y1, x2, y2)
    -- Same tile always has LOS
    if x1 == x2 and y1 == y2 then return true end

    local dx = math.abs(x2 - x1)
    local dy = math.abs(y2 - y1)
    local sx = x1 < x2 and 1 or -1
    local sy = y1 < y2 and 1 or -1
    local err = dx - dy

    local x, y = x1, y1
    while true do
        -- Check intermediate tiles (skip start and end)
        if (x ~= x1 or y ~= y1) and (x ~= x2 or y ~= y2) then
            if TacticalCombat.isTileBlocksLOS(grid, x, y) then
                return false
            end
        end

        -- Reached destination
        if x == x2 and y == y2 then
            return true
        end

        local e2 = 2 * err
        if e2 > -dy then
            err = err - dy
            x = x + sx
        end
        if e2 < dx then
            err = err + dx
            y = y + sy
        end
    end
end

-- ============================================================================
-- UNIT MANAGEMENT
-- ============================================================================

-- Create a tactical unit from player data
function TacticalCombat.createPlayerUnit(playerData)
    local classId = playerData.class and playerData.class.id or "warrior"
    local hp = playerData.hp or 50
    local maxHP = playerData.maxHP or playerData.maxHp or hp
    return {
        id = "player",
        name = playerData.name or "Hero",
        faction = "ally",
        isPlayer = true,
        data = playerData,  -- reference to actual player data
        x = 0, y = 0,      -- grid position (set during placement)
        hp = hp,
        maxHP = maxHP,
        mana = playerData.mana,
        maxMana = playerData.maxMana,
        attack = playerData.attack,
        defense = playerData.defense,
        classId = classId,
        moveRange = TacticalCombat.MOVE_RANGES[classId] or 3,
        attackRange = TacticalCombat.ATTACK_RANGES[classId] or 1,
        minAttackRange = 1,
        skills = playerData.skills or {},
        portrait = classId,
        color = playerData.class and playerData.class.color or {0.3, 0.9, 0.4},
        critChance = playerData.critChance or 5,
        critDamage = playerData.critDamage or 1.5,
        dodgeChance = playerData.dodgeChance or 0,
        hasMoved = false,
        hasActed = false,
    }
end

-- Create a tactical unit from companion data
function TacticalCombat.createCompanionUnit(companionData, index, manualControl)
    local classId = companionData.class and companionData.class.id or "warrior"
    local hp = companionData.hp or 30
    local maxHP = companionData.maxHP or companionData.maxHp or hp
    local attack = companionData.attack or 5
    local defense = companionData.defense or 2
    local critBonus = companionData.critBonus or 5
    local healAmount = companionData.healAmount

    -- Apply companion talent bonuses
    local talents = companionData.talents
    if talents then
        if talents.tough then maxHP = math.floor(maxHP * 1.15) end
        if talents.sentinel then defense = defense + 5 end
        if talents.lucky then critBonus = critBonus + 5 end
        if talents.precision then critBonus = critBonus + 15 end
        if talents.blessed and healAmount then healAmount = math.floor(healAmount * 1.3) end
    end
    -- Clamp HP to new maxHP
    if hp > maxHP then hp = maxHP end

    -- Player controls this companion if manual party control is on and not auto-battle
    local playerControlled = manualControl and not companionData.autoBattle
    return {
        id = "companion_" .. index,
        name = companionData.name,
        faction = "ally",
        isCompanion = true,
        isPlayerControlled = playerControlled or false,
        companionIndex = index,
        data = companionData,
        x = 0, y = 0,
        hp = hp,
        maxHP = maxHP,
        attack = attack,
        defense = defense,
        classId = classId,
        moveRange = TacticalCombat.MOVE_RANGES[classId] or 3,
        attackRange = TacticalCombat.ATTACK_RANGES[classId] or 1,
        minAttackRange = 1,
        canHeal = companionData.canHeal,
        healAmount = healAmount,
        attacks = companionData.attacks or {"Attack"},
        portrait = companionData.portrait or classId,
        color = companionData.color or {0.5, 0.7, 0.9},
        critBonus = critBonus,
        hasMoved = false,
        hasActed = false,
        companionTalents = talents,  -- Store for combat-time checks (deadly, weapon_master, etc.)
    }
end

-- Create a tactical unit from enemy data
function TacticalCombat.createEnemyUnit(enemyData, index)
    -- Determine enemy archetype for movement/range
    local enemyId = enemyData.id or ""
    local moveRange = TacticalCombat.MOVE_RANGES.default
    local attackRange = TacticalCombat.ATTACK_RANGES.default

    -- Classify enemy by name/id patterns
    if enemyId:match("archer") or enemyId:match("ranger") or enemyId:match("scout") then
        attackRange = TacticalCombat.RANGE_LONG
        moveRange = TacticalCombat.MOVE_RANGES.default
    elseif enemyId:match("mage") or enemyId:match("shaman") or enemyId:match("necromancer")
        or enemyId:match("lich") or enemyId:match("demon") or enemyId:match("succubus") then
        attackRange = TacticalCombat.RANGE_MAGIC
        moveRange = TacticalCombat.MOVE_RANGES.slow
    elseif enemyId:match("rat") or enemyId:match("bat") or enemyId:match("wolf")
        or enemyId:match("spider") or enemyId:match("imp") then
        moveRange = TacticalCombat.MOVE_RANGES.fast
    elseif enemyId:match("troll") or enemyId:match("ogre") or enemyId:match("colossus")
        or enemyId:match("dragon") then
        moveRange = TacticalCombat.MOVE_RANGES.slow
    end

    -- Robust HP/stat extraction: handle multiple field naming conventions
    -- (createEnemyInstance uses maxHP/attack/defense, dungeon enemies use maxHp/atk/def,
    --  sea enemies use hp/atk/def)
    local hp = enemyData.hp or 30
    local maxHP = enemyData.maxHP or enemyData.maxHp or hp
    local attack = enemyData.attack or enemyData.atk or 8
    local defense = enemyData.defense or enemyData.def or 4

    return {
        id = "enemy_" .. index,
        name = enemyData.name,
        faction = "enemy",
        isEnemy = true,
        enemyIndex = index,
        data = enemyData,
        x = 0, y = 0,
        hp = hp,
        maxHP = maxHP,
        attack = attack,
        defense = defense,
        cr = enemyData.cr or 1,
        classId = enemyId,
        moveRange = moveRange,
        attackRange = attackRange,
        minAttackRange = attackRange > 2 and 2 or 1,  -- ranged units have min range of 2
        attacks = enemyData.attacks or {"Attack"},
        portrait = enemyData.portrait or "?",
        portraitId = enemyData.id,
        color = {0.9, 0.35, 0.35},
        xpReward = enemyData.xpReward or 0,
        goldReward = enemyData.goldReward or 0,
        hasMoved = false,
        hasActed = false,
        -- Stealth system: facing and vision
        facing = 180,  -- Enemies face left (toward player side) by default in degrees
        visionRange = enemyData.visionRange or 5,
        visionAngle = enemyData.visionAngle or 90,
    }
end

-- ============================================================================
-- UNIT PLACEMENT
-- ============================================================================

-- Place ally units on the left side of the grid
function TacticalCombat.placeAllyUnits(grid, units)
    -- Allies spawn in columns 1-3
    local spawnTiles = {}
    for y = 1, grid.height do
        for x = 1, 3 do
            if TacticalCombat.isTilePassable(grid, x, y) then
                table.insert(spawnTiles, {x = x, y = y})
            end
        end
    end

    -- Sort by preference (center rows first)
    local centerY = math.floor(grid.height / 2)
    table.sort(spawnTiles, function(a, b)
        return math.abs(a.y - centerY) < math.abs(b.y - centerY)
    end)

    -- Place units (melee in front columns, ranged in back)
    local meleeUnits = {}
    local rangedUnits = {}
    for _, unit in ipairs(units) do
        if unit.attackRange > 1 then
            table.insert(rangedUnits, unit)
        else
            table.insert(meleeUnits, unit)
        end
    end

    -- Interleave: melee first (prefer column 3), ranged second (prefer column 1-2)
    local allUnits = {}
    for _, u in ipairs(meleeUnits) do table.insert(allUnits, u) end
    for _, u in ipairs(rangedUnits) do table.insert(allUnits, u) end

    local placedIdx = 1
    for _, unit in ipairs(allUnits) do
        if placedIdx <= #spawnTiles then
            local tile = spawnTiles[placedIdx]
            unit.x = tile.x
            unit.y = tile.y
            grid.tiles[tile.y][tile.x].unit = unit
            placedIdx = placedIdx + 1
        end
    end
end

-- Place enemy units on the right side of the grid
function TacticalCombat.placeEnemyUnits(grid, units)
    -- Enemies spawn in columns (width-2) to width
    local spawnTiles = {}
    for y = 1, grid.height do
        for x = grid.width - 2, grid.width do
            if TacticalCombat.isTilePassable(grid, x, y) then
                table.insert(spawnTiles, {x = x, y = y})
            end
        end
    end

    -- Sort by preference (center rows first)
    local centerY = math.floor(grid.height / 2)
    table.sort(spawnTiles, function(a, b)
        return math.abs(a.y - centerY) < math.abs(b.y - centerY)
    end)

    -- Place units (ranged in back columns, melee in front)
    local meleeUnits = {}
    local rangedUnits = {}
    for _, unit in ipairs(units) do
        if unit.attackRange > 1 then
            table.insert(rangedUnits, unit)
        else
            table.insert(meleeUnits, unit)
        end
    end

    -- Melee in front column (width-2), ranged in back columns (width-1, width)
    local allUnits = {}
    for _, u in ipairs(meleeUnits) do table.insert(allUnits, u) end
    for _, u in ipairs(rangedUnits) do table.insert(allUnits, u) end

    local placedIdx = 1
    for _, unit in ipairs(allUnits) do
        if placedIdx <= #spawnTiles then
            local tile = spawnTiles[placedIdx]
            unit.x = tile.x
            unit.y = tile.y
            grid.tiles[tile.y][tile.x].unit = unit
            placedIdx = placedIdx + 1
        end
    end
end

-- ============================================================================
-- COMBAT STATE MANAGEMENT
-- ============================================================================

-- Initialize a new tactical combat encounter
-- Returns the full combat state object
function TacticalCombat.initCombat(playerData, enemies, encounterType)
    -- Generate battlefield
    local grid = TacticalCombat.generateBattlefield(encounterType)

    -- Create tactical units
    local allyUnits = {}
    local enemyUnits = {}
    local allUnits = {}

    -- Player unit
    local playerUnit = TacticalCombat.createPlayerUnit(playerData)
    table.insert(allyUnits, playerUnit)
    table.insert(allUnits, playerUnit)

    -- Companion units (pass manual control flag for BG3/Divinity-style party control)
    local manualControl = playerData.manualPartyControl ~= false
    if playerData.party then
        for i, companion in ipairs(playerData.party) do
            if companion.hp > 0 then
                local compUnit = TacticalCombat.createCompanionUnit(companion, i, manualControl)
                table.insert(allyUnits, compUnit)
                table.insert(allUnits, compUnit)
            end
        end
    end

    -- Enemy units
    for i, enemy in ipairs(enemies) do
        local enemyUnit = TacticalCombat.createEnemyUnit(enemy, i)
        table.insert(enemyUnits, enemyUnit)
        table.insert(allUnits, enemyUnit)
    end

    -- Place units on grid
    TacticalCombat.placeAllyUnits(grid, allyUnits)
    TacticalCombat.placeEnemyUnits(grid, enemyUnits)

    -- Mark player for ambush initiative bonus (consumed in rollInitiative)
    if playerData._ambushBonus and playerData._ambushBonus.playerGoesFirst then
        playerUnit._ambushFirst = true
    end

    -- Roll initiative
    local turnOrder = TacticalCombat.rollInitiative(allUnits)

    -- Build the combat state
    local state = {
        grid = grid,
        allUnits = allUnits,
        allyUnits = allyUnits,
        enemyUnits = enemyUnits,
        playerUnit = playerUnit,

        -- Turn management
        turnOrder = turnOrder,
        currentTurnIndex = 0,
        activeUnit = nil,
        turnPhase = TacticalCombat.PHASE_MOVE,
        turnNumber = 0,

        -- Selection state (for player input)
        selectedTile = nil,       -- {x, y} of hovered/selected tile
        hoveredTile = nil,        -- {x, y} of mouse hover
        movementTiles = {},       -- cached reachable tiles for current unit
        attackTiles = {},         -- cached attackable tiles
        currentPath = nil,        -- path preview for movement
        showMoveRange = false,
        showAttackRange = false,

        -- Action state
        selectedAction = nil,     -- "move", "attack", "skill", "item", "wait"
        selectedSkill = nil,
        showSkillMenu = false,

        -- Animation state
        animating = false,
        animQueue = {},           -- queue of animations to play
        animTimer = 0,
        animDuration = 0.3,

        -- Combat log
        log = {},

        -- Enemy data reference (for rewards/quest tracking)
        originalEnemies = enemies,

        -- Flags
        combatEnded = false,
        victory = false,
    }

    return state
end

-- Roll initiative for all units
function TacticalCombat.rollInitiative(units)
    local initiatives = {}

    for _, unit in ipairs(units) do
        local roll = math.random(1, 20)
        local bonus = 0

        if unit.isPlayer then
            bonus = math.floor((unit.data.level or 1) / 2)
        elseif unit.isCompanion then
            bonus = math.floor((unit.data.level or 1) / 3)
        elseif unit.isEnemy then
            bonus = math.floor(unit.cr or 1)
        end

        local init = roll + bonus

        -- Stealth initiative bonus
        if StealthSystem then
            init = StealthSystem.hookInitiativeRoll(unit, roll, bonus)
        end

        -- Ambush bonus: player always goes first
        if unit.isPlayer and unit._ambushFirst then
            init = init + 100  -- Guarantee first turn
        end

        table.insert(initiatives, {unit = unit, initiative = init})
    end

    -- Sort by initiative (highest first)
    table.sort(initiatives, function(a, b) return a.initiative > b.initiative end)

    return initiatives
end

-- Advance to the next turn
function TacticalCombat.advanceTurn(combatState)
    local turnOrder = combatState.turnOrder
    local orderLen = #turnOrder

    -- Reset current unit's turn flags
    if combatState.activeUnit then
        combatState.activeUnit.hasMoved = false
        combatState.activeUnit.hasActed = false
    end

    -- Find next living unit
    local startIdx = combatState.currentTurnIndex
    for i = 1, orderLen do
        local idx = ((startIdx + i - 1) % orderLen) + 1
        local entry = turnOrder[idx]
        local unit = entry.unit

        if unit.hp > 0 then
            combatState.currentTurnIndex = idx
            combatState.activeUnit = unit
            combatState.turnPhase = TacticalCombat.PHASE_MOVE
            combatState.selectedAction = nil
            combatState.selectedSkill = nil
            combatState.showSkillMenu = false
            combatState.showMoveRange = false
            combatState.showAttackRange = false
            combatState.currentPath = nil
            combatState.selectedTile = nil

            -- Track turn number (when we wrap around to first unit)
            if idx <= startIdx or startIdx == 0 then
                combatState.turnNumber = combatState.turnNumber + 1
                -- Stealth: update smoke zones and guard patrols at start of each round
                if StealthSystem then
                    local stealthEvents = StealthSystem.hookStartOfRound(combatState, TacticalCombat)
                    if stealthEvents then
                        for _, evt in ipairs(stealthEvents) do
                            TacticalCombat.addLog(combatState, evt.message, evt.color)
                            if evt.type == "guard_spotted" and combatState.playerUnit then
                                TacticalCombat.addFloatingText(combatState, "SPOTTED!",
                                    combatState.playerUnit.x, combatState.playerUnit.y,
                                    {0.9, 0.4, 0.2}, "status")
                            end
                        end
                    end
                end
            end

            -- Phase 7: use effective move range (accounting for root/slow)
            local effectiveMove = TacticalCombat.getEffectiveMoveRange(unit)
            combatState.movementTiles = TacticalCombat.getMovementRange(
                combatState.grid, unit.x, unit.y, effectiveMove
            )

            -- Phase 10: process start-of-turn effects (DOT, hazards)
            combatState._turnStartEffects = TacticalCombat.processStartOfTurn(combatState, unit)

            -- Check if unit died from start-of-turn effects (DOT/hazard)
            if unit.hp <= 0 then
                -- Record the death so callers can process XP/gold/logs
                if not combatState._dotDeaths then combatState._dotDeaths = {} end
                table.insert(combatState._dotDeaths, {
                    unit = unit,
                    effects = combatState._turnStartEffects,
                })
                -- Log and floating text already handled in processStartOfTurn
                -- Skip this dead unit, continue searching for next living unit
            else
                -- Phase 7: if stunned, skip action phase
                if not TacticalCombat.canAct(unit) then
                    unit.hasActed = true
                end

                -- Phase 10: check battlefield events at start of each full round
                if idx == 1 or combatState._lastEventCheck ~= combatState.turnNumber then
                    combatState._lastEventCheck = combatState.turnNumber
                    combatState._battlefieldEvents = TacticalCombat.checkBattlefieldEvents(combatState)
                end

                return unit
            end
        end
    end

    return nil  -- No living units (shouldn't happen)
end

-- ============================================================================
-- COMBAT ACTIONS
-- ============================================================================

-- Move a unit along a path
function TacticalCombat.moveUnit(combatState, unit, targetX, targetY)
    local grid = combatState.grid

    -- Find path
    local path = TacticalCombat.findPath(grid, unit.x, unit.y, targetX, targetY, TacticalCombat.getEffectiveMoveRange(unit))
    if not path then return false end

    -- Remove unit from old tile
    grid.tiles[unit.y][unit.x].unit = nil

    -- Update facing direction based on movement
    if StealthSystem and unit.facing ~= nil then
        local dx = targetX - unit.x
        local dy = targetY - unit.y
        if dx ~= 0 or dy ~= 0 then
            unit.facing = StealthSystem.getFacingFromDirection(dx, dy)
        end
    end

    -- Store old position for doorway check
    local oldX, oldY = unit.x, unit.y

    -- Place unit on new tile
    unit.x = targetX
    unit.y = targetY
    grid.tiles[targetY][targetX].unit = unit
    unit.hasMoved = true

    -- Stealth: doorway check when crossing between rooms in building interiors
    if StealthSystem and grid.stealthRooms and unit.isHidden then
        local fromRoom, toRoom = nil, nil
        for _, room in ipairs(grid.stealthRooms) do
            if oldX >= room.x1 and oldX <= room.x2 and oldY >= room.y1 and oldY <= room.y2 then
                fromRoom = room
            end
            if targetX >= room.x1 and targetX <= room.x2 and targetY >= room.y1 and targetY <= room.y2 then
                toRoom = room
            end
        end
        -- If moved between different rooms, perform doorway detection check
        if fromRoom and toRoom and fromRoom.id ~= toRoom.id then
            local playerData = unit.data or {}
            local timeOfDay = combatState.timeOfDay or "day"
            local detected, chance, info = StealthSystem.doorwayStealthCheck(
                {
                    stealthMode = true,
                    equipmentStealthMod = playerData.equipmentStealthMod or 0,
                    classStealthBonus = playerData.classStealthBonus or 0,
                },
                nil, fromRoom, toRoom, timeOfDay
            )
            if detected then
                -- Reveal the unit at the doorway
                StealthSystem.removeHidden(unit, TacticalCombat)
                TacticalCombat.addLog(combatState,
                    unit.name .. " was spotted crossing between rooms! (" .. math.floor(chance * 100) .. "% chance)",
                    {0.9, 0.5, 0.2})
                TacticalCombat.addFloatingText(combatState, "SPOTTED!", unit.x, unit.y, {0.9, 0.4, 0.2}, "status")
            else
                TacticalCombat.addLog(combatState,
                    unit.name .. " slips through the doorway unnoticed. (" .. math.floor(chance * 100) .. "% chance)",
                    {0.5, 0.7, 0.5})
            end
        end
    end

    -- Recalculate attack range from new position
    combatState.attackTiles = TacticalCombat.getAttackRange(
        grid, unit.x, unit.y, unit.minAttackRange or 1, unit.attackRange
    )

    return true, path
end

-- Perform a basic attack (Phase 7: balance-tuned damage formula)
function TacticalCombat.performAttack(combatState, attacker, target)
    local grid = combatState.grid
    local BAL = TacticalCombat.BALANCE

    -- Cannot attack hidden/untargetable targets (unless attacker is the hidden player attacking out)
    if target.isHidden and not attacker.isPlayer then
        return false, "Target is hidden"
    end

    -- Update facing toward target
    if StealthSystem and attacker.facing ~= nil then
        local dx = target.x - attacker.x
        local dy = target.y - attacker.y
        if dx ~= 0 or dy ~= 0 then
            attacker.facing = StealthSystem.getFacingFromDirection(dx, dy)
        end
    end

    -- Distance check (Phase 10: elevation range bonus)
    local dist = math.abs(attacker.x - target.x) + math.abs(attacker.y - target.y)
    local effectiveRange = TacticalCombat.getEffectiveAttackRange(grid, attacker)
    if dist < (attacker.minAttackRange or 1) or dist > effectiveRange then
        return false, "Out of range"
    end

    -- Line of sight check
    if not TacticalCombat.hasLineOfSight(grid, attacker.x, attacker.y, target.x, target.y) then
        return false, "No line of sight"
    end

    -- Phase 7: Check target dodge/evasion
    local dodged = false
    local targetDodge = TacticalCombat.getEffectiveDodge(target)
    if targetDodge > 0 and math.random(100) <= targetDodge then
        dodged = true
    end

    if dodged then
        -- Phase 8: floating "MISS" text
        if combatState then
            TacticalCombat.addFloatingText(combatState, "MISS", target.x, target.y, {0.7, 0.7, 0.8}, "status")
        end
        attacker.hasActed = true
        return true, {
            damage = 0,
            isCrit = false,
            dodged = true,
            heightBonus = false,
            flanked = false,
            targetDown = false,
        }
    end

    -- Phase 7: Balance-tuned damage formula
    local atkStat = TacticalCombat.getEffectiveAttack(attacker)
    local defStat = TacticalCombat.getEffectiveDefense(target)
    local baseDamage = (atkStat * BAL.atkMultiplier) - (defStat * BAL.defMultiplier)
        + math.random(-BAL.varianceRange, BAL.varianceRange)

    -- Height bonus
    local attackerTile = grid.tiles[attacker.y][attacker.x]
    local targetTile = grid.tiles[target.y][target.x]
    local heightDiff = attackerTile.height - targetTile.height
    heightDiff = math.max(-2, math.min(2, heightDiff))
    local heightMult = TacticalCombat.HEIGHT_BONUS[heightDiff] or 1.0

    -- Terrain defense bonus for target
    local targetTerrain = TacticalCombat.TERRAIN[targetTile.type]
    local terrainDefMult = 1.0
    if targetTerrain and targetTerrain.defBonus ~= 0 then
        terrainDefMult = 1.0 - targetTerrain.defBonus
    end

    -- Flanking bonus: count allies adjacent to target
    local flankBonus = TacticalCombat.calculateFlankingBonus(grid, attacker, target)

    -- Critical hit
    local critChance = attacker.critChance or attacker.critBonus or BAL.baseCritChance
    local isCrit = math.random(100) <= critChance
    local critMult = isCrit and (attacker.critDamage or BAL.baseCritDamage) or 1.0

    -- Phase 7: Marked status on target increases damage taken
    local markedMult = TacticalCombat.getMarkedMultiplier(target)

    -- Apply damage reduction from shield status (Phase 7)
    local dmgReduction = TacticalCombat.getDamageReduction(target)

    -- Stealth damage bonus: if attacker is hidden, apply stealth multiplier and force crit
    if StealthSystem and attacker.isHidden then
        local stealthDmg, stealthCrit = StealthSystem.hookPerformAttack(attacker, baseDamage, isCrit, TacticalCombat)
        baseDamage = stealthDmg
        if stealthCrit then
            isCrit = true
            critMult = attacker.critDamage or BAL.baseCritDamage
        end
    end

    -- Ambush damage bonus: +50% on first hit from ambush approach
    if combatState.ambushBonus and combatState.ambushBonus.active
        and attacker.isPlayer then
        baseDamage = math.floor(baseDamage * (1.0 + combatState.ambushBonus.firstHitDamageBonus))
        combatState.ambushBonus.active = false  -- Consume after first hit
        TacticalCombat.addFloatingText(combatState, "AMBUSH!", attacker.x, attacker.y, {0.9, 0.6, 0.2}, "status")
    end

    -- Calculate final damage
    local damage = math.max(BAL.minDamage, math.floor(
        baseDamage * heightMult * terrainDefMult * critMult
        * (1 + flankBonus) * dmgReduction * markedMult
    ))

    -- Apply damage
    target.hp = target.hp - damage

    -- Phase 8: floating text + screen shake + attack animation
    if combatState then
        local ftColor = isCrit and {1, 0.9, 0.2} or {1, 0.4, 0.3}
        local ftStyle = isCrit and "crit" or "damage"
        TacticalCombat.addFloatingText(combatState, damage, target.x, target.y, ftColor, ftStyle)
        -- Phase 8: attack flash animation on target
        TacticalCombat.queueAnimation(combatState, "attack_flash", {
            targetX = target.x, targetY = target.y,
            attackerX = attacker.x, attackerY = attacker.y,
            isCrit = isCrit, duration = 0.3,
        })
        -- Phase 8: spawn hit particles
        TacticalCombat.spawnParticles(combatState, "hit", target.x, target.y,
            isCrit and {1, 0.9, 0.2} or {1, 0.5, 0.3}, isCrit and 8 or 4)
        if isCrit then
            TacticalCombat.triggerScreenShake(combatState, 6, 0.25)
        else
            TacticalCombat.triggerScreenShake(combatState, 3, 0.15)
        end
    end

    -- Sync back to source data
    if target.data then
        target.data.hp = target.hp
    end

    attacker.hasActed = true

    return true, {
        damage = damage,
        isCrit = isCrit,
        dodged = false,
        heightBonus = heightDiff ~= 0,
        flanked = flankBonus > 0,
        targetDown = target.hp <= 0,
    }
end

-- Calculate flanking bonus
function TacticalCombat.calculateFlankingBonus(grid, attacker, target)
    local adjacentAllies = 0
    local neighbors = TileUtils.DIRS4

    for _, n in ipairs(neighbors) do
        local nx, ny = target.x + n[1], target.y + n[2]
        local adjUnit = TacticalCombat.getUnitAt(grid, nx, ny)
        if adjUnit and adjUnit ~= attacker and adjUnit.faction == attacker.faction and adjUnit.hp > 0 then
            adjacentAllies = adjacentAllies + 1
        end
    end

    -- First flanking ally: +20%, diminishing returns after
    if adjacentAllies >= 2 then
        return 0.30  -- 2+ allies flanking: +30%
    elseif adjacentAllies == 1 then
        return 0.15  -- 1 ally flanking: +15%
    end
    return 0
end

-- Use a skill (Phase 7+10: balance-tuned, status effects, positional AOE)
function TacticalCombat.useSkill(combatState, attacker, skillName, targetX, targetY, SKILLS)
    local skill = SKILLS[skillName]
    if not skill then return false, "Unknown skill" end

    -- Check mana
    local mana = attacker.isPlayer and attacker.data.mana or (attacker.data and attacker.data.mana or 0)
    if mana < skill.manaCost then
        return false, "Not enough mana"
    end

    local grid = combatState.grid
    local results = {skillName = skillName, effects = {}}

    -- Range check (shared for all skill types)
    local skillRange = skill.range or attacker.attackRange
    if type(skillRange) == "string" then
        skillRange = skillRange == "ranged" and 5 or (skillRange == "melee" and 1 or 3)
    end
    local dist = math.abs(attacker.x - targetX) + math.abs(attacker.y - targetY)
    if dist > skillRange then
        return false, "Out of range"
    end

    -- LOS check for damage/targeted skills (not self-buffs)
    if skill.damage or skill.aoe then
        if not TacticalCombat.hasLineOfSight(grid, attacker.x, attacker.y, targetX, targetY) then
            return false, "No line of sight"
        end
    end

    -- Deduct mana
    if attacker.isPlayer then
        attacker.data.mana = attacker.data.mana - skill.manaCost
        attacker.mana = attacker.data.mana
    end

    -- Phase 10: AOE skills - positional area damage centered on target tile
    if skill.aoe then
        local aoeRadius = skill.aoeRadius or 2   -- default 2-tile radius
        local aoeDamageMult = skill.aoeDamageMult or 0.65
        local baseDmg = (skill.damage or 0) + math.floor(attacker.attack * 0.4)
        local aoeDamage = math.max(1, math.floor(baseDmg * aoeDamageMult))
        local targetFaction = attacker.faction == "ally" and "enemy" or "ally"

        -- Hit all enemy units within aoeRadius of the target tile
        for _, unit in ipairs(combatState.allUnits) do
            if unit.hp > 0 and unit.faction == targetFaction then
                local unitDist = math.abs(unit.x - targetX) + math.abs(unit.y - targetY)
                if unitDist <= aoeRadius then
                    -- Damage falls off at edge
                    local falloff = unitDist == 0 and 1.0 or (1.0 - (unitDist / (aoeRadius + 1)) * 0.3)
                    local finalDmg = math.max(1, math.floor(aoeDamage * falloff))
                    unit.hp = unit.hp - finalDmg
                    if unit.data then unit.data.hp = unit.hp end
                    table.insert(results.effects, {
                        type = "aoe_damage",
                        target = unit,
                        amount = finalDmg,
                        targetDown = unit.hp <= 0,
                    })
                    -- Phase 8: floating text for each AOE hit
                    if combatState then
                        TacticalCombat.addFloatingText(combatState, finalDmg, unit.x, unit.y, {1, 0.6, 0.2}, "damage")
                        TacticalCombat.spawnParticles(combatState, "aoe", unit.x, unit.y, {1, 0.7, 0.3}, 3)
                    end
                end
            end
        end
        -- Phase 8: AOE ground effect visual
        if combatState then
            TacticalCombat.queueAnimation(combatState, "aoe_blast", {
                centerX = targetX, centerY = targetY, radius = aoeRadius,
                color = {1, 0.6, 0.2, 0.4}, duration = 0.5,
            })
            TacticalCombat.triggerScreenShake(combatState, 5, 0.3)
        end
    -- Single-target damage skills
    elseif skill.damage then
        local target = TacticalCombat.getUnitAt(grid, targetX, targetY)
        if target and target.hp > 0 then
            -- Phase 7: balanced skill damage = base + scaling from attack stat
            local baseDmg = skill.damage + math.floor(attacker.attack * 0.5)
            -- Multi-hit skills (Flurry of Blows)
            local hits = skill.hits or 1
            local totalDmg = 0
            for h = 1, hits do
                local hitDmg = math.max(1, baseDmg + math.random(-2, 2))
                -- Crit bonus from skill
                if skill.critBonus then
                    local critRoll = math.random(100)
                    if critRoll <= (skill.critBonus + (attacker.critChance or 5)) then
                        hitDmg = math.floor(hitDmg * 1.5)
                        if h == 1 then
                            TacticalCombat.addFloatingText(combatState, "CRIT!", target.x, target.y, {1, 0.9, 0.2}, "crit")
                        end
                    end
                end
                totalDmg = totalDmg + hitDmg
            end

            -- Phase 7: Marked multiplier
            local markedMult = TacticalCombat.getMarkedMultiplier(target)
            totalDmg = math.floor(totalDmg * markedMult)

            target.hp = target.hp - totalDmg
            if target.data then target.data.hp = target.hp end

            table.insert(results.effects, {
                type = "damage",
                target = target,
                amount = totalDmg,
                hits = hits,
                targetDown = target.hp <= 0,
            })

            -- Phase 7: Apply status effects from skills
            if skill.stun and target.hp > 0 then
                TacticalCombat.applyStatus(target, "stun", 1)
                table.insert(results.effects, {type = "status", target = target, status = "stun"})
            end
            if skill.slow and target.hp > 0 then
                TacticalCombat.applyStatus(target, "slow", 2)
                table.insert(results.effects, {type = "status", target = target, status = "slow"})
            end
            if skill.dot and target.hp > 0 then
                TacticalCombat.applyStatus(target, "poison", skill.dotDuration or 3)
                table.insert(results.effects, {type = "status", target = target, status = "poison"})
            end

            -- Phase 8: visual feedback
            if combatState then
                TacticalCombat.addFloatingText(combatState, totalDmg, target.x, target.y, {0.6, 0.4, 1}, "damage")
                TacticalCombat.spawnParticles(combatState, "skill", target.x, target.y, {0.6, 0.4, 1}, 5)
                TacticalCombat.queueAnimation(combatState, "skill_flash", {
                    targetX = target.x, targetY = target.y, duration = 0.25,
                    color = skill.type == "magic" and {0.4, 0.4, 1} or {1, 0.6, 0.3},
                })
            end
        end
    end

    -- Heal skills
    if skill.heal then
        local target = TacticalCombat.getUnitAt(grid, targetX, targetY)
        if not target and targetX == attacker.x and targetY == attacker.y then
            target = attacker  -- Self-cast
        end
        if target and target.faction == attacker.faction and target.hp > 0 then
            local healAmt = skill.heal
            local prevHP = target.hp
            target.hp = math.min(target.maxHP, target.hp + healAmt)
            local actualHeal = target.hp - prevHP
            if target.data then target.data.hp = target.hp end

            table.insert(results.effects, {
                type = "heal",
                target = target,
                amount = actualHeal,
            })

            -- Phase 8: heal visual
            if combatState then
                TacticalCombat.addFloatingText(combatState, "+" .. actualHeal, target.x, target.y, {0.3, 0.95, 0.5}, "heal")
                TacticalCombat.spawnParticles(combatState, "heal", target.x, target.y, {0.3, 0.95, 0.5}, 6)
            end
        end
    end

    -- Phase 7: Buff skills (Battle Cry, Divine Shield, Vanish, Inner Focus)
    if skill.buff then
        if skill.buff == "attack" then
            TacticalCombat.applyStatus(attacker, "blessed", skill.duration or 3)
            table.insert(results.effects, {type = "status", target = attacker, status = "blessed"})
        elseif skill.buff == "defense" then
            TacticalCombat.applyStatus(attacker, "shield", skill.duration or 2)
            table.insert(results.effects, {type = "status", target = attacker, status = "shield"})
        end
        if combatState then
            TacticalCombat.addFloatingText(combatState, skill.buff:upper(), attacker.x, attacker.y, {0.9, 0.85, 0.4}, "status")
            TacticalCombat.spawnParticles(combatState, "buff", attacker.x, attacker.y, {0.9, 0.85, 0.4}, 5)
        end
    end
    if skill.shield then
        TacticalCombat.applyStatus(attacker, "shield", skill.duration or 2)
        table.insert(results.effects, {type = "status", target = attacker, status = "shield"})
        if combatState then
            TacticalCombat.addFloatingText(combatState, "SHIELD", attacker.x, attacker.y, {0.4, 0.65, 0.9}, "status")
        end
    end
    if skill.dodge then
        TacticalCombat.applyStatus(attacker, "dodge", skill.dodge or 2)
        table.insert(results.effects, {type = "status", target = attacker, status = "dodge"})
        if combatState then
            TacticalCombat.addFloatingText(combatState, "EVASION", attacker.x, attacker.y, {0.7, 0.9, 0.7}, "status")
        end
    end

    -- Phase 7: Debuff skills (Hunter's Mark)
    if skill.debuff then
        local target = TacticalCombat.getUnitAt(grid, targetX, targetY)
        if target and target.hp > 0 and target.faction ~= attacker.faction then
            if skill.debuff == "marked" then
                TacticalCombat.applyStatus(target, "marked", skill.duration or 3)
                table.insert(results.effects, {type = "status", target = target, status = "marked"})
            end
            if combatState then
                TacticalCombat.addFloatingText(combatState, "MARKED", target.x, target.y, {0.9, 0.3, 0.3}, "status")
            end
        end
    end

    attacker.hasActed = true

    return true, results
end

-- ============================================================================
-- COMBAT RESOLUTION
-- ============================================================================

-- Check if all enemies are defeated
function TacticalCombat.checkAllEnemiesDefeated(combatState)
    for _, unit in ipairs(combatState.enemyUnits) do
        if unit.hp > 0 then
            return false
        end
    end
    return true
end

-- Check if all allies are defeated
function TacticalCombat.checkAllAlliesDefeated(combatState)
    for _, unit in ipairs(combatState.allyUnits) do
        if unit.hp > 0 then
            return false
        end
    end
    return true
end

-- Check if player is dead
function TacticalCombat.checkPlayerDead(combatState)
    return combatState.playerUnit.hp <= 0
end

-- Sync tactical unit state back to original game data
function TacticalCombat.syncToGameState(combatState, playerData)
    -- Sync player HP/mana
    local pu = combatState.playerUnit
    playerData.hp = pu.hp
    playerData.mana = pu.mana or playerData.mana

    -- Sync companion HP
    if playerData.party then
        for _, unit in ipairs(combatState.allyUnits) do
            if unit.isCompanion and unit.companionIndex then
                local companion = playerData.party[unit.companionIndex]
                if companion then
                    companion.hp = unit.hp
                end
            end
        end
    end
end

-- ============================================================================
-- COMBAT LOG
-- ============================================================================

function TacticalCombat.addLog(combatState, message, color)
    table.insert(combatState.log, {
        text = message,
        color = color or {0.8, 0.8, 0.8},
        time = love.timer.getTime(),
    })
    -- Keep log bounded
    if #combatState.log > 50 then
        table.remove(combatState.log, 1)
    end
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Get Manhattan distance between two points (delegates to shared MathUtil)
function TacticalCombat.getDistance(x1, y1, x2, y2)
    return MathUtil.getDistance(x1, y1, x2, y2)
end

-- Check if a unit can attack a target from its current position
function TacticalCombat.canAttackTarget(grid, attacker, target)
    -- Cannot attack hidden/untargetable units
    if target.isHidden then return false end
    if TacticalCombat.hasStatus(target, "hidden") then return false end

    local dist = TacticalCombat.getDistance(attacker.x, attacker.y, target.x, target.y)
    -- Phase 10: elevation range bonus for ranged units on high ground
    local effectiveRange = TacticalCombat.getEffectiveAttackRange(grid, attacker)
    if dist < (attacker.minAttackRange or 1) or dist > effectiveRange then
        return false
    end
    return TacticalCombat.hasLineOfSight(grid, attacker.x, attacker.y, target.x, target.y)
end

-- Get all valid attack targets for a unit
function TacticalCombat.getValidTargets(combatState, unit)
    local targets = {}
    local grid = combatState.grid
    local targetList = unit.faction == "ally" and combatState.enemyUnits or combatState.allyUnits

    for _, target in ipairs(targetList) do
        if target.hp > 0 and not target.isHidden then
            if TacticalCombat.canAttackTarget(grid, unit, target) then
                table.insert(targets, target)
            end
        end
    end

    return targets
end

-- Get all living units of a faction
function TacticalCombat.getLivingUnits(combatState, faction)
    local units = {}
    for _, unit in ipairs(combatState.allUnits) do
        if unit.hp > 0 and unit.faction == faction then
            table.insert(units, unit)
        end
    end
    return units
end

-- ============================================================================
-- PHASE 7: STATUS EFFECT MANAGEMENT
-- ============================================================================

-- Apply a status effect to a unit
function TacticalCombat.applyStatus(unit, statusId, duration)
    if not unit.statusEffects then unit.statusEffects = {} end
    local template = TacticalCombat.STATUS_EFFECTS[statusId]
    if not template then return end
    for _, s in ipairs(unit.statusEffects) do
        if s.id == statusId then
            s.remaining = duration or template.duration
            return
        end
    end
    table.insert(unit.statusEffects, {
        id = statusId,
        remaining = duration or template.duration,
        template = template,
    })
end

function TacticalCombat.tickStatusEffects(unit)
    if not unit.statusEffects then return 0, 0 end
    local totalDot = 0
    local totalHot = 0
    local i = 1
    while i <= #unit.statusEffects do
        local s = unit.statusEffects[i]
        s.remaining = s.remaining - 1
        if s.template.dotDamage then
            totalDot = totalDot + s.template.dotDamage
        end
        if s.template.hotHeal then
            totalHot = totalHot + s.template.hotHeal
        end
        if s.remaining <= 0 then
            table.remove(unit.statusEffects, i)
        else
            i = i + 1
        end
    end
    return totalDot, totalHot
end

function TacticalCombat.hasStatus(unit, statusId)
    if not unit.statusEffects then return false end
    for _, s in ipairs(unit.statusEffects) do
        if s.id == statusId then return true end
    end
    return false
end

function TacticalCombat.getEffectiveMoveRange(unit)
    local base = unit.moveRange
    if TacticalCombat.hasStatus(unit, "root") then return 0 end
    if TacticalCombat.hasStatus(unit, "slow") then base = math.max(1, base - 1) end
    return base
end

function TacticalCombat.canAct(unit)
    return not TacticalCombat.hasStatus(unit, "stun")
end

function TacticalCombat.getEffectiveAttack(unit)
    local base = unit.attack
    if not unit.statusEffects then return base end
    for _, s in ipairs(unit.statusEffects) do
        if s.template.atkBuff then base = base + s.template.atkBuff end
        if s.template.atkDebuff then base = base - s.template.atkDebuff end
    end
    return math.max(1, base)
end

function TacticalCombat.getEffectiveDefense(unit)
    local base = unit.defense
    if not unit.statusEffects then return base end
    for _, s in ipairs(unit.statusEffects) do
        if s.template.defBuff then base = base + s.template.defBuff end
    end
    return math.max(0, base)
end

function TacticalCombat.getDamageReduction(unit)
    if not unit.statusEffects then return 1.0 end
    local reduction = 1.0
    for _, s in ipairs(unit.statusEffects) do
        if s.template.damageReduction then
            reduction = reduction * (1.0 - s.template.damageReduction)
        end
    end
    return reduction
end

-- Phase 7: Get dodge chance from evasion status
function TacticalCombat.getEffectiveDodge(unit)
    local base = unit.dodgeChance or 0
    if not unit.statusEffects then return base end
    for _, s in ipairs(unit.statusEffects) do
        if s.template.dodgeChance then base = base + s.template.dodgeChance end
    end
    return math.min(75, base)  -- Cap at 75% dodge
end

-- Phase 7: Get marked damage multiplier
function TacticalCombat.getMarkedMultiplier(unit)
    if not unit.statusEffects then return 1.0 end
    for _, s in ipairs(unit.statusEffects) do
        if s.template.damageTakenMult then return s.template.damageTakenMult end
    end
    return 1.0
end

-- ============================================================================
-- PHASE 10: ENVIRONMENTAL HAZARD PROCESSING
-- ============================================================================

function TacticalCombat.processStartOfTurn(combatState, unit)
    local effects = {}
    local grid = combatState.grid

    -- Phase 7: tick status effects (DOT + HOT)
    local dotDamage, hotHeal = TacticalCombat.tickStatusEffects(unit)
    if dotDamage > 0 then
        unit.hp = unit.hp - dotDamage
        if unit.data then unit.data.hp = unit.hp end
        table.insert(effects, {type = "dot", amount = dotDamage})
        -- Phase 8: floating DOT text
        if combatState then
            TacticalCombat.addFloatingText(combatState, dotDamage, unit.x, unit.y, {0.8, 0.3, 0.8}, "damage")
        end
        -- Death check: DOT damage can kill a unit
        if unit.hp <= 0 then
            unit.hp = 0
            if unit.data then unit.data.hp = 0 end
            if combatState then
                TacticalCombat.addFloatingText(combatState, "DEFEATED", unit.x, unit.y, {0.9, 0.2, 0.2}, "status")
                TacticalCombat.addLog(combatState, unit.name .. " succumbs to damage over time!", {0.9, 0.4, 0.4})
            end
            table.insert(effects, {type = "death", source = "dot", unit = unit})
            return effects
        end
    end
    if hotHeal > 0 and unit.hp > 0 then
        local prevHP = unit.hp
        unit.hp = math.min(unit.maxHP, unit.hp + hotHeal)
        local actualHeal = unit.hp - prevHP
        if unit.data then unit.data.hp = unit.hp end
        if actualHeal > 0 then
            table.insert(effects, {type = "hot", amount = actualHeal})
            if combatState then
                TacticalCombat.addFloatingText(combatState, "+" .. actualHeal, unit.x, unit.y, {0.3, 0.9, 0.5}, "heal")
            end
        end
    end

    -- Phase 10: hazard tile processing
    local tile = grid.tiles[unit.y][unit.x]
    local terrain = TacticalCombat.TERRAIN[tile.type]
    if terrain and terrain.hazardDmg then
        if terrain.hazardType == "trap" and tile._trapTriggered then
            -- skip already triggered trap
        else
            local hazDmg = terrain.hazardDmg
            unit.hp = unit.hp - hazDmg
            if unit.data then unit.data.hp = unit.hp end
            table.insert(effects, {type = "hazard", hazard = terrain.hazardType, amount = hazDmg})
            -- Phase 8: hazard damage floating text
            if combatState then
                local hazColor = terrain.hazardType == "fire" and {1, 0.5, 0.2} or
                    (terrain.hazardType == "poison" and {0.4, 0.9, 0.3} or {0.9, 0.4, 0.2})
                TacticalCombat.addFloatingText(combatState, hazDmg .. " " .. (terrain.hazardType or ""), unit.x, unit.y, hazColor, "damage")
            end
            if terrain.hazardType == "trap" then
                tile.type = TacticalCombat.TILE_FLOOR
                tile._trapTriggered = true
                -- Phase 8: trap trigger effect
                if combatState then
                    TacticalCombat.triggerScreenShake(combatState, 4, 0.2)
                    TacticalCombat.spawnParticles(combatState, "trap", unit.x, unit.y, {0.9, 0.7, 0.2}, 6)
                end
            end
            if terrain.hazardType == "fire" then
                TacticalCombat.applyStatus(unit, "burn")
            elseif terrain.hazardType == "poison" then
                TacticalCombat.applyStatus(unit, "poison")
            end
            -- Death check: hazard damage can kill a unit
            if unit.hp <= 0 then
                unit.hp = 0
                if unit.data then unit.data.hp = 0 end
                if combatState then
                    TacticalCombat.addFloatingText(combatState, "DEFEATED", unit.x, unit.y, {0.9, 0.2, 0.2}, "status")
                    TacticalCombat.addLog(combatState, unit.name .. " is killed by " .. (terrain.hazardType or "hazard") .. "!", {0.9, 0.4, 0.4})
                end
                table.insert(effects, {type = "death", source = "hazard", unit = unit})
                return effects
            end
        end
    end

    if tile.type == TacticalCombat.TILE_ICE then
        if math.random() < 0.25 then
            TacticalCombat.applyStatus(unit, "slow", 1)
            table.insert(effects, {type = "slip"})
            if combatState then
                TacticalCombat.addFloatingText(combatState, "SLIP!", unit.x, unit.y, {0.6, 0.8, 1}, "status")
            end
        end
    end

    return effects
end

-- ============================================================================
-- PHASE 10: DESTRUCTIBLE OBSTACLES + BATTLEFIELD EVENTS
-- ============================================================================

function TacticalCombat.attackObstacle(combatState, attacker, tileX, tileY)
    local grid = combatState.grid
    local tile = grid.tiles[tileY][tileX]
    if tile.type ~= TacticalCombat.TILE_OBSTACLE then return false end
    tile.type = "rubble"
    tile.decoration = "debris"
    attacker.hasActed = true
    return true
end

function TacticalCombat.checkBattlefieldEvents(combatState)
    local events = {}
    local turn = combatState.turnNumber

    if turn == 5 then
        local livingEnemies = 0
        for _, u in ipairs(combatState.enemyUnits) do
            if u.hp > 0 then livingEnemies = livingEnemies + 1 end
        end
        if livingEnemies <= 1 and not combatState._reinforcementsSpawned then
            combatState._reinforcementsSpawned = true
            table.insert(events, {type = "reinforcements"})
        end
    end

    if turn > 1 and turn % 3 == 0 then
        local grid = combatState.grid
        local newFires = {}
        for y = 1, grid.height do
            for x = 1, grid.width do
                if grid.tiles[y][x].type == TacticalCombat.TILE_FIRE then
                    for _, n in ipairs(TileUtils.DIRS4) do
                        local nx, ny = x + n[1], y + n[2]
                        if TacticalCombat.isValidTile(grid, nx, ny) then
                            local adj = grid.tiles[ny][nx]
                            if adj.type == TacticalCombat.TILE_FLOOR and math.random() < 0.2 then
                                table.insert(newFires, {x = nx, y = ny})
                            end
                        end
                    end
                end
            end
        end
        for _, f in ipairs(newFires) do
            grid.tiles[f.y][f.x].type = TacticalCombat.TILE_FIRE
            table.insert(events, {type = "fire_spread", x = f.x, y = f.y})
        end
    end

    if turn > 6 then
        local grid = combatState.grid
        for y = 1, grid.height do
            for x = 1, grid.width do
                if grid.tiles[y][x].type == "poison" and math.random() < 0.3 then
                    grid.tiles[y][x].type = TacticalCombat.TILE_FLOOR
                    table.insert(events, {type = "poison_clear", x = x, y = y})
                end
            end
        end
    end

    return events
end

-- ============================================================================
-- PHASE 10: ELEVATION RANGE BONUS
-- ============================================================================

function TacticalCombat.getEffectiveAttackRange(grid, unit)
    local base = unit.attackRange
    if base > 1 then
        local tile = grid.tiles[unit.y][unit.x]
        if tile.height == TacticalCombat.HEIGHT_HIGH then
            base = base + TacticalCombat.ELEVATION_RANGE_BONUS
        end
    end
    return base
end

-- ============================================================================
-- PHASE 8: ANIMATION + FLOATING TEXT + SCREEN SHAKE
-- ============================================================================

function TacticalCombat.queueAnimation(combatState, animType, data)
    if not combatState.animQueue then combatState.animQueue = {} end
    table.insert(combatState.animQueue, {
        type = animType,
        data = data or {},
        timer = 0,
        duration = data and data.duration or 0.4,
        finished = false,
    })
end

function TacticalCombat.getCurrentAnimation(combatState)
    if not combatState.animQueue or #combatState.animQueue == 0 then return nil end
    return combatState.animQueue[1]
end

function TacticalCombat.updateAnimation(combatState, dt)
    local anim = TacticalCombat.getCurrentAnimation(combatState)
    if not anim then
        combatState.animating = false
        return false
    end
    anim.timer = anim.timer + dt
    if anim.timer >= anim.duration then
        anim.finished = true
        table.remove(combatState.animQueue, 1)
        combatState.animating = (#combatState.animQueue > 0)
        return true
    end
    combatState.animating = true
    return false
end

function TacticalCombat.addFloatingText(combatState, text, x, y, color, style)
    if not combatState.floatingTexts then combatState.floatingTexts = {} end
    table.insert(combatState.floatingTexts, {
        text = tostring(text),
        worldX = x,
        worldY = y,
        color = color or {1, 1, 1},
        style = style or "damage",
        timer = 0,
        duration = 1.2,
        offsetY = 0,
        scale = style == "crit" and 1.4 or 1.0,
    })
end

function TacticalCombat.updateFloatingTexts(combatState, dt)
    if not combatState.floatingTexts then return end
    local i = 1
    while i <= #combatState.floatingTexts do
        local ft = combatState.floatingTexts[i]
        ft.timer = ft.timer + dt
        ft.offsetY = ft.offsetY - 40 * dt
        if ft.timer >= ft.duration then
            table.remove(combatState.floatingTexts, i)
        else
            i = i + 1
        end
    end
end

function TacticalCombat.triggerScreenShake(combatState, intensity, duration)
    combatState.screenShake = {
        intensity = intensity or 4,
        duration = duration or 0.2,
        timer = 0,
    }
end

function TacticalCombat.updateScreenShake(combatState, dt)
    if not combatState.screenShake then return 0, 0 end
    local shake = combatState.screenShake
    shake.timer = shake.timer + dt
    if shake.timer >= shake.duration then
        combatState.screenShake = nil
        return 0, 0
    end
    local progress = shake.timer / shake.duration
    local fade = 1.0 - progress
    local sx = (math.random() * 2 - 1) * shake.intensity * fade
    local sy = (math.random() * 2 - 1) * shake.intensity * fade
    return sx, sy
end

-- ============================================================================
-- PHASE 8: PARTICLE SYSTEM
-- ============================================================================

function TacticalCombat.spawnParticles(combatState, particleType, x, y, color, count)
    if not combatState.particles then combatState.particles = {} end
    count = count or 4
    for i = 1, count do
        local angle = math.random() * math.pi * 2
        local speed = 20 + math.random() * 40
        table.insert(combatState.particles, {
            type = particleType,
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            color = {color[1] or 1, color[2] or 1, color[3] or 1},
            life = 0,
            maxLife = 0.5 + math.random() * 0.5,
            size = 2 + math.random() * 3,
        })
    end
end

function TacticalCombat.updateParticles(combatState, dt)
    if not combatState.particles then return end
    local i = 1
    while i <= #combatState.particles do
        local p = combatState.particles[i]
        p.life = p.life + dt
        p.x = p.x + p.vx * dt / 56  -- normalize to tile coords
        p.y = p.y + p.vy * dt / 56
        p.vy = p.vy + 30 * dt  -- gravity
        if p.life >= p.maxLife then
            table.remove(combatState.particles, i)
        else
            i = i + 1
        end
    end
end

-- ============================================================================
-- PHASE 8: MOVEMENT ANIMATION
-- ============================================================================

function TacticalCombat.queueMoveAnimation(combatState, unit, path)
    if not path or #path < 2 then return end
    if not combatState.moveAnims then combatState.moveAnims = {} end
    table.insert(combatState.moveAnims, {
        unit = unit,
        path = path,
        pathIndex = 1,
        timer = 0,
        stepDuration = 0.12,  -- seconds per tile
        finished = false,
    })
    combatState.animating = true
end

function TacticalCombat.updateMoveAnimations(combatState, dt)
    if not combatState.moveAnims then return false end
    local anyActive = false
    local i = 1
    while i <= #combatState.moveAnims do
        local anim = combatState.moveAnims[i]
        if anim.finished then
            table.remove(combatState.moveAnims, i)
        else
            anim.timer = anim.timer + dt
            if anim.timer >= anim.stepDuration then
                anim.timer = anim.timer - anim.stepDuration
                anim.pathIndex = anim.pathIndex + 1
                if anim.pathIndex >= #anim.path then
                    anim.finished = true
                end
            end
            anyActive = true
            i = i + 1
        end
    end
    if not anyActive then
        combatState.moveAnims = nil
    end
    return anyActive
end

-- Get animated position for a unit (returns fractional tile coords or nil)
function TacticalCombat.getAnimatedPosition(combatState, unit)
    if not combatState.moveAnims then return nil end
    for _, anim in ipairs(combatState.moveAnims) do
        if anim.unit == unit and not anim.finished then
            local from = anim.path[anim.pathIndex]
            local to = anim.path[math.min(anim.pathIndex + 1, #anim.path)]
            if from and to then
                local t = anim.timer / anim.stepDuration
                t = math.min(1, math.max(0, t))
                -- Smooth interpolation
                local smooth = t * t * (3 - 2 * t)
                return {
                    x = from.x + (to.x - from.x) * smooth,
                    y = from.y + (to.y - from.y) * smooth,
                }
            end
        end
    end
    return nil
end

-- ============================================================================
-- PHASE 8: SOUND HOOKS (framework - actual audio integration via host game)
-- ============================================================================

TacticalCombat.SOUND_EVENTS = {
    attack_hit = "combat_hit",
    attack_crit = "combat_crit",
    attack_miss = "combat_miss",
    skill_fire = "skill_fire",
    skill_ice = "skill_ice",
    skill_heal = "skill_heal",
    skill_buff = "skill_buff",
    unit_move = "unit_step",
    unit_death = "unit_death",
    hazard_fire = "hazard_fire",
    hazard_trap = "hazard_trap",
    turn_start = "turn_start",
    combat_victory = "combat_victory",
    combat_defeat = "combat_defeat",
}

function TacticalCombat.triggerSound(combatState, soundEvent)
    if not combatState._soundQueue then combatState._soundQueue = {} end
    table.insert(combatState._soundQueue, {
        event = soundEvent,
        soundId = TacticalCombat.SOUND_EVENTS[soundEvent] or soundEvent,
        time = love.timer.getTime(),
    })
end

function TacticalCombat.consumeSoundQueue(combatState)
    local queue = combatState._soundQueue
    combatState._soundQueue = {}
    return queue or {}
end

-- ============================================================================
-- PHASE 10: INTERACTIVE OBJECT SYSTEM
-- ============================================================================

-- Place an interactive object on a tile
function TacticalCombat.placeInteractiveObject(grid, x, y, objectType)
    local template = TacticalCombat.INTERACTIVE_OBJECTS[objectType]
    if not template then return false end
    if not TacticalCombat.isValidTile(grid, x, y) then return false end

    local tile = grid.tiles[y][x]
    if tile.type ~= TacticalCombat.TILE_FLOOR then return false end
    if tile.unit then return false end

    tile.interactiveObject = {
        type = objectType,
        name = template.name,
        hp = template.hp,
        maxHP = template.hp,
        template = template,
        activated = false,
    }

    if template.blocksMove then
        tile.type = TacticalCombat.TILE_OBSTACLE
    end
    tile.decoration = template.decoration

    return true
end

-- Interact with an object (attack or activate)
function TacticalCombat.interactWithObject(combatState, unit, tileX, tileY)
    local grid = combatState.grid
    local tile = grid.tiles[tileY][tileX]
    if not tile.interactiveObject then return false, "No object here" end

    local obj = tile.interactiveObject
    local template = obj.template

    -- Lever: toggle effect
    if template.interactable and not obj.activated then
        obj.activated = true
        if template.effect == "toggle_doors" then
            -- Toggle all doors on the map
            for gy = 1, grid.height do
                for gx = 1, grid.width do
                    local t = grid.tiles[gy][gx]
                    if t.type == TacticalCombat.TILE_DOOR then
                        t.type = TacticalCombat.TILE_FLOOR
                        t.decoration = "open_door"
                    end
                end
            end
            TacticalCombat.addLog(combatState, unit.name .. " pulls the lever! Doors open!", {0.9, 0.85, 0.3})
        end
        unit.hasActed = true
        return true, {type = "interact", object = obj.type}
    end

    -- Destructible: attack it
    if obj.hp < 999 then
        local dmg = math.max(1, math.floor(unit.attack * 0.5))
        obj.hp = obj.hp - dmg

        if obj.hp <= 0 then
            -- Object destroyed
            local destroyedType = template.destroyedType or "rubble"
            tile.type = destroyedType == "fire" and TacticalCombat.TILE_FIRE or TacticalCombat.TILE_FLOOR
            if destroyedType == "rubble" then tile.type = "rubble" end
            tile.decoration = "debris"

            -- Explosive barrel: deal AOE damage
            if template.explosionDamage then
                local radius = template.explosionRadius or 1
                local exDmg = template.explosionDamage
                for _, u in ipairs(combatState.allUnits) do
                    if u.hp > 0 then
                        local d = TacticalCombat.getDistance(tileX, tileY, u.x, u.y)
                        if d <= radius then
                            u.hp = u.hp - exDmg
                            if u.data then u.data.hp = u.hp end
                            TacticalCombat.addLog(combatState,
                                u.name .. " caught in explosion for " .. exDmg .. " damage!",
                                {1, 0.5, 0.2})
                            if combatState then
                                TacticalCombat.addFloatingText(combatState, exDmg, u.x, u.y, {1, 0.5, 0.2}, "damage")
                            end
                        end
                    end
                end
                TacticalCombat.triggerScreenShake(combatState, 8, 0.4)
                TacticalCombat.spawnParticles(combatState, "explosion", tileX, tileY, {1, 0.6, 0.1}, 12)
            end

            -- Drop effect (heal/mana)
            if template.dropChance and math.random() < template.dropChance then
                if template.dropEffect == "heal" then
                    unit.hp = math.min(unit.maxHP, unit.hp + template.dropAmount)
                    if unit.data then unit.data.hp = unit.hp end
                    TacticalCombat.addLog(combatState,
                        unit.name .. " finds a potion! +" .. template.dropAmount .. " HP", {0.3, 0.9, 0.5})
                    TacticalCombat.addFloatingText(combatState, "+" .. template.dropAmount, unit.x, unit.y, {0.3, 0.9, 0.5}, "heal")
                elseif template.dropEffect == "mana" and unit.isPlayer and unit.data then
                    unit.data.mana = math.min(unit.data.maxMana or 0, (unit.data.mana or 0) + template.dropAmount)
                    unit.mana = unit.data.mana
                    TacticalCombat.addLog(combatState,
                        unit.name .. " finds a scroll! +" .. template.dropAmount .. " MP", {0.4, 0.5, 0.9})
                end
            end

            tile.interactiveObject = nil
            TacticalCombat.addLog(combatState, obj.name .. " destroyed!", {0.7, 0.7, 0.5})
        end

        unit.hasActed = true
        return true, {type = "attack_object", object = obj.type, destroyed = obj.hp <= 0}
    end

    return false, "Cannot interact"
end

-- ============================================================================
-- PHASE 10: HAZARD-ENHANCED MAP GENERATION
-- ============================================================================

-- Add hazard tiles to any generated battlefield
function TacticalCombat.addHazards(grid, encounterType, intensity)
    local w, h = grid.width, grid.height
    intensity = intensity or 1.0  -- 0.0 = none, 1.0 = normal, 2.0 = lots

    -- Fire hazards: more common in ruins, dungeon
    if encounterType == "ruins" or encounterType == "dungeon" then
        local numFire = math.floor(math.random(1, 3) * intensity)
        for i = 1, numFire do
            local fx = math.random(4, w - 3)
            local fy = math.random(2, h - 1)
            if grid.tiles[fy][fx].type == TacticalCombat.TILE_FLOOR and not grid.tiles[fy][fx].unit then
                grid.tiles[fy][fx].type = TacticalCombat.TILE_FIRE
            end
        end
    end

    -- Poison hazards: more common in forests, dungeons
    if encounterType == "forest" or encounterType == "dungeon" then
        local numPoison = math.floor(math.random(1, 2) * intensity)
        for i = 1, numPoison do
            local px = math.random(4, w - 3)
            local py = math.random(2, h - 1)
            if grid.tiles[py][px].type == TacticalCombat.TILE_FLOOR and not grid.tiles[py][px].unit then
                grid.tiles[py][px].type = "poison"
            end
        end
    end

    -- Trap tiles: any encounter type
    if math.random() < 0.4 * intensity then
        local numTraps = math.floor(math.random(1, 2) * intensity)
        for i = 1, numTraps do
            local tx = math.random(4, w - 3)
            local ty = math.random(2, h - 1)
            if grid.tiles[ty][tx].type == TacticalCombat.TILE_FLOOR and not grid.tiles[ty][tx].unit then
                grid.tiles[ty][tx].type = "trap"
            end
        end
    end

    -- Ice tiles: bridges, open
    if encounterType == "bridge" or (encounterType == "open" and math.random() < 0.3) then
        local numIce = math.floor(math.random(2, 4) * intensity)
        for i = 1, numIce do
            local ix = math.random(3, w - 2)
            local iy = math.random(2, h - 1)
            if grid.tiles[iy][ix].type == TacticalCombat.TILE_FLOOR and not grid.tiles[iy][ix].unit then
                grid.tiles[iy][ix].type = "ice"
            end
        end
    end
end

-- Add interactive objects to battlefield
function TacticalCombat.addInteractiveObjects(grid, encounterType)
    local w, h = grid.width, grid.height

    -- Barrels/crates in dungeon and ruins
    if encounterType == "dungeon" or encounterType == "ruins" then
        local numObjects = math.random(1, 3)
        for i = 1, numObjects do
            local ox = math.random(4, w - 3)
            local oy = math.random(2, h - 1)
            if grid.tiles[oy][ox].type == TacticalCombat.TILE_FLOOR and not grid.tiles[oy][ox].unit then
                local objType = math.random() < 0.5 and "barrel" or "crate"
                TacticalCombat.placeInteractiveObject(grid, ox, oy, objType)
            end
        end
    end

    -- Explosive barrels (rare)
    if math.random() < 0.15 then
        local ox = math.random(5, w - 4)
        local oy = math.random(3, h - 2)
        if grid.tiles[oy][ox].type == TacticalCombat.TILE_FLOOR and not grid.tiles[oy][ox].unit then
            TacticalCombat.placeInteractiveObject(grid, ox, oy, "explosive_barrel")
        end
    end

    -- Lever in dungeon (rare)
    if encounterType == "dungeon" and math.random() < 0.2 then
        -- Place lever near a wall
        for y = 2, h - 1 do
            for x = 2, w - 1 do
                local tile = grid.tiles[y][x]
                if tile.type == TacticalCombat.TILE_FLOOR and not tile.unit then
                    -- Check if adjacent to a wall
                    local nearWall = false
                    for _, d in ipairs(TileUtils.DIRS4) do
                        local nx, ny = x + d[1], y + d[2]
                        if TacticalCombat.isValidTile(grid, nx, ny) and grid.tiles[ny][nx].type == TacticalCombat.TILE_WALL then
                            nearWall = true
                            break
                        end
                    end
                    if nearWall then
                        TacticalCombat.placeInteractiveObject(grid, x, y, "lever")
                        return  -- Only one lever per map
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- PHASE 10: ENHANCED INIT - Wire hazards and objects into combat init
-- ============================================================================

-- Override initCombat to include hazard/object generation
local _originalInitCombat = TacticalCombat.initCombat
TacticalCombat.initCombat = function(playerData, enemies, encounterType)
    local combatState = _originalInitCombat(playerData, enemies, encounterType)

    -- Phase 10: Add hazards and interactive objects after unit placement
    local playerLevel = playerData.level or 1
    local hazardIntensity = playerLevel >= 5 and 1.0 or (playerLevel >= 3 and 0.6 or 0.3)
    TacticalCombat.addHazards(combatState.grid, encounterType, hazardIntensity)
    TacticalCombat.addInteractiveObjects(combatState.grid, encounterType)

    -- Phase 8: Initialize particle + animation state
    combatState.particles = {}
    combatState.moveAnims = nil
    combatState.floatingTexts = combatState.floatingTexts or {}

    -- Stealth system initialization
    if StealthSystem then
        combatState.smokeZones = {}
        -- If player was in stealth mode when combat started, apply hidden status
        if playerData.stealthMode and combatState.playerUnit then
            StealthSystem.applyHidden(combatState.playerUnit, TacticalCombat)
            TacticalCombat.addLog(combatState, "You enter combat from the shadows! (Hidden)", {0.5, 0.5, 0.8})
        end
        -- Apply ambush bonus from pre-combat stealth approach
        if playerData._ambushBonus and combatState.playerUnit then
            combatState.ambushBonus = {
                firstHitDamageBonus = playerData._ambushBonus.firstHitDamageBonus or 0.50,
                playerGoesFirst = playerData._ambushBonus.playerGoesFirst or false,
                active = true,
            }
            playerData._ambushBonus = nil  -- Consume the bonus
            TacticalCombat.addLog(combatState, "Ambush! +50% damage on first hit!", {0.9, 0.6, 0.2})
        end
        -- Store encounter type for stealth context
        combatState.encounterType = encounterType
        -- Initialize facing for enemy units based on player position
        if combatState.playerUnit then
            for _, unit in ipairs(combatState.enemyUnits) do
                if unit.hp > 0 then
                    local dx = combatState.playerUnit.x - unit.x
                    local dy = combatState.playerUnit.y - unit.y
                    unit.facing = StealthSystem.getFacingFromDirection(dx, dy)
                end
            end
        end
    end

    return combatState
end

return TacticalCombat
