-- ==========================================================================
-- TileQuadMaps - Maps game tile type IDs to atlas sprite positions
-- ==========================================================================
-- This is the "dictionary" that tells the renderer which part of which
-- sprite sheet to draw for each tile type. Each quad map is a table
-- keyed by tile type ID (numeric or string) whose values are LÖVE Quads.
-- ==========================================================================

local LPCLoader = require("lpcloader")

local TileQuadMaps = {}

-- Cached quad tables
TileQuadMaps.terrain = {}       -- Named terrain quads (grass, dirt, water, etc.)
TileQuadMaps.townGround = {}    -- TownGen ID (0-12) -> ground quad
TileQuadMaps.combat = {}        -- Combat tile name -> quad
TileQuadMaps.dungeon = {}       -- LPCTilemap TILES ID -> quad
TileQuadMaps.worldmap = {}      -- World tile name -> quad
TileQuadMaps.initialized = false

-- ==========================================================================
--                           HELPERS
-- ==========================================================================

-- Convert a Tiled Map Editor tile ID to column/row on the atlas
-- terrain.png is 32 columns wide (1024px / 32px)
function TileQuadMaps.tsxToColRow(tileID, columns)
    columns = columns or 32
    local col = tileID % columns
    local row = math.floor(tileID / columns)
    return col, row
end

-- Create a quad from a TSX tile ID on a given atlas
local function quadFromTSX(atlas, tileID, tileSize, columns)
    tileSize = tileSize or 32
    columns = columns or 32
    local col, row = TileQuadMaps.tsxToColRow(tileID, columns)
    return LPCLoader.getTileQuad(atlas, col, row, tileSize)
end

-- Create a quad from explicit col/row
local function quadFromPos(atlas, col, row, tileSize)
    tileSize = tileSize or 32
    return LPCLoader.getTileQuad(atlas, col, row, tileSize)
end

-- ==========================================================================
--                     TERRAIN QUAD MAP (terrain_atlas.png)
-- ==========================================================================
-- IMPORTANT: The terrain_atlas.png has a DIFFERENT layout from what the
-- Terrain.tsx describes. The positions below are verified by pixel sampling
-- on the actual atlas image (32-column, 32-row grid of 32x32 tiles).
-- ==========================================================================

function TileQuadMaps.initTerrain(terrainAtlas)
    if not terrainAtlas then
        print("TileQuadMaps: No terrain atlas, skipping terrain quads")
        return false
    end

    local T = TileQuadMaps.terrain
    local p = function(col, row) return quadFromPos(terrainAtlas, col, row, 32) end

    -- ===== Stone tiles (verified grey/stone on atlas via 8x8 grid sampling) =====
    -- (27,8) was horizontal-line pattern (h_score=650); replaced with true stone
    T.stone_solid    = p(24, 11)  -- rgb(124,110,103) grey stone with subtle cracks, NO horiz lines
    T.stone_varied   = p(25, 11)  -- rgb(122,109,103) grey stone with natural variation
    T.dark_stone     = p(14, 15)  -- rgb(93,82,83)  darker stone blocks with mortar lines

    -- ===== Cobblestone tiles (verified grey cobblestone path textures) =====
    -- Row 15 tiles have 64 semi-transparent edge pixels; rows 16-17 cols 1-3 are fully opaque
    T.cobblestone    = p(1, 16)   -- rgb(151,150,145) cobblestone interior, fully opaque
    T.cobblestone_v2 = p(2, 16)   -- rgb(151,150,145) cobblestone variant, fully opaque
    T.cobblestone_v3 = p(3, 16)   -- rgb(125,126,122) cobblestone variant, fully opaque

    -- ===== Black/void tiles (verified pure black on atlas) =====
    T.black_solid    = p(28, 5)   -- rgb(0,0,0) pure black
    T.near_black     = p(18, 8)   -- rgb(16,20,20) near-black

    -- ===== Wood/brown tiles (verified brown wood on atlas) =====
    T.wood           = p(16, 2)   -- rgb(184,134,79) brown wood center
    T.wood_dark      = p(15, 2)   -- rgb(153,107,74) darker wood

    -- ===== Water tiles (verified blue on atlas) =====
    T.water_deep     = p(22, 14)  -- rgb(21,108,153)  deep blue water
    T.water_light    = p(28, 6)   -- rgb(106,141,142) teal/light water

    -- ===== Green/grass tiles =====
    -- Using row 9 area near original grass positions, with atlas-verified offsets
    T.grass_main     = p(1, 9)    -- main grass tile (TSX 289 area)
    T.dark_grass_t   = p(7, 9)    -- dark grass (TSX 295 area)
    T.short_grass_t  = p(10, 9)   -- short grass (TSX 298 area)
    T.long_grass_t   = p(13, 9)   -- long grass (TSX 301 area)

    -- ===== Sand/yellow tiles (verified on atlas) =====
    T.sand_golden    = p(0, 11)   -- rgb(222,195,69) golden/wheat
    T.sand_solid     = p(2, 12)   -- rgb(224,194,75) solid sand/golden

    -- ===== Lava =====
    T.lava_tile      = p(16, 3)   -- lava area (TSX 112 -> col 16, row 3)

    -- ===== Snow and ice =====
    T.snow_tile      = p(19, 15)  -- snow (TSX 499 -> col 19, row 15)
    T.ice_tile       = p(16, 15)  -- ice (TSX 496 -> col 16, row 15)

    -- ===== Agriculture =====
    T.wheat_tile     = p(16, 9)   -- wheat (TSX 304 -> col 16, row 9)

    -- ===== Additional stone positions for variety =====
    -- (25,8) was solid flat fill; (26,8) was semi-transparent; (30,9) was HORIZ-LINES
    T.stone_v2       = p(26, 11)  -- rgb(120,107,102) grey stone with crack detail
    T.stone_v3       = p(18, 15)  -- rgb(93,82,83) dark stone blocks with mortar
    T.stone_v4       = p(19, 14)  -- rgb(104,92,91) clean grey stone fill
    T.dark_stone_v2  = p(16, 29)  -- rgb(83,74,77) dark stone blocks, h=0.41
    T.dark_stone_v3  = p(18, 29)  -- rgb(88,78,80) dark stone variant, h=0.75
    T.cobble_v4      = p(1, 17)   -- rgb(151,150,145) cobblestone interior, fully opaque
    T.cobble_v5      = p(2, 17)   -- rgb(109,108,105) darker cobblestone, fully opaque
    T.cobble_v6      = p(3, 17)   -- rgb(125,126,122) cobblestone variant, fully opaque
    T.cobble_v7      = p(2, 16)   -- rgb(151,150,145) cobblestone variant, fully opaque
    T.cobble_v8      = p(3, 16)   -- rgb(125,126,122) cobblestone variant, fully opaque
    T.cobble_v9      = p(1, 16)   -- rgb(151,150,145) cobblestone variant, fully opaque
    T.cobble_v10     = p(3, 17)   -- rgb(125,126,122) cobblestone variant, fully opaque
    T.cobble_v11     = p(2, 17)   -- rgb(109,108,105) cobblestone variant, fully opaque
    T.black_v2       = p(28, 3)   -- rgb(0,0,0) pure black variant
    T.black_v3       = p(27, 5)   -- rgb(0,0,0) pure black variant
    T.black_v4       = p(29, 5)   -- rgb(0,0,0) pure black variant
    T.black_v5       = p(11, 8)   -- rgb(0,0,0) pure black variant
    T.wood_v2        = p(16, 0)   -- rgb(177,129,79) wood brown variant
    T.wood_v3        = p(17, 0)   -- rgb(182,131,79) wood brown variant
    T.wood_v4        = p(15, 0)   -- rgb(184,134,79) wood brown variant
    T.water_v2       = p(23, 14)  -- rgb(21,108,153) deep blue variant
    T.water_v3       = p(6, 14)   -- rgb(29,108,152) blue variant
    T.water_v4       = p(8, 14)   -- rgb(29,108,152) blue variant

    -- ======================================================================
    -- BACKWARD COMPATIBLE NAMES (used by dungeon, combat, town, world code)
    -- These map the old TSX-based names to verified atlas positions.
    -- ======================================================================
    T.grass         = T.grass_main     -- used by town, world, combat, dungeon
    T.dark_grass    = T.dark_grass_t   -- used by world (swamp)
    T.short_grass   = T.short_grass_t  -- used by world (plains), town (decorative)
    T.long_grass    = T.long_grass_t   -- used by town (garden), combat (poison)

    T.dark_dirt     = T.dark_stone     -- was q(100), now dark grey stone
    T.red_dirt      = T.dark_stone_v2  -- was q(103), now dark stone variant
    T.black_dirt    = T.black_solid    -- was q(106), now pure black
    T.grey_dirt     = T.stone_solid    -- was q(109), now correct solid stone
    T.dirt          = T.cobblestone    -- was q(537), now cobblestone
    T.earth         = T.wood           -- was q(676), now wood/brown

    T.water         = T.water_deep     -- was q(124), now deep blue
    T.lava          = T.lava_tile      -- was q(112), keep lava position

    T.sand          = T.sand_solid     -- was q(307), now verified sand
    T.snow          = T.snow_tile      -- was q(499), keep snow position
    T.ice           = T.ice_tile       -- was q(496), keep ice position

    T.brick_road    = T.cobblestone    -- was q(491), now correct cobblestone
    T.brick_road_v2 = T.cobblestone_v2 -- was q(492), lighter cobblestone
    T.brick_road_v3 = T.cobblestone_v3 -- was q(493), cobblestone variant
    T.brick_road_v4 = T.cobble_v4     -- was q(494), cobblestone variant

    T.sewer         = T.cobblestone    -- was q(484), row 15 IS cobblestone
    T.sewer_water   = T.cobble_v4     -- was q(481), cobblestone path
    T.hole          = T.near_black     -- was q(115), now near-black void
    T.red_hole      = T.dark_stone     -- was q(118), now dark stone
    T.black_hole    = T.black_solid    -- was q(121), now pure black

    T.wheat         = T.wheat_tile     -- was q(304), keep wheat position

    print("TileQuadMaps: " .. TileQuadMaps.countTable(T) .. " terrain quads initialized")
    return true
end

-- ==========================================================================
--                     TOWN GROUND QUAD MAP
-- ==========================================================================
-- Maps TownGen tile type IDs (0-12) to ground terrain quads.
-- These are the BASE GROUND tiles. Buildings, walls, and decorations
-- are drawn as separate layers on top.
--
-- TownGen IDs:
--   0=empty, 1=street, 2=building, 3=water, 4=bridge, 5=plaza,
--   6=wall, 7=garden, 8=dock, 9=decorative, 10=gate, 11=boardwalk,
--   12=lighthouse
-- ==========================================================================

function TileQuadMaps.initTownTiles(terrainAtlas, townObjAtlas)
    if not terrainAtlas then
        print("TileQuadMaps: No terrain atlas, skipping town quads")
        return false
    end

    local T = TileQuadMaps.terrain
    local TG = TileQuadMaps.townGround

    -- Map TownGen IDs to terrain quads (using verified atlas positions)
    TG[0]  = T.grass        -- empty/open ground (verified grass)
    TG[1]  = T.cobblestone  -- street/road (verified cobblestone path)
    TG[2]  = T.dark_stone   -- building (dark stone ground under building)
    TG[3]  = T.water        -- water (verified deep blue)
    TG[4]  = T.wood         -- bridge (verified brown wood)
    TG[5]  = T.stone_solid  -- plaza/town square (verified solid grey stone)
    TG[6]  = T.dark_stone   -- wall fortification (dark stone base)
    TG[7]  = T.long_grass   -- garden/park
    TG[8]  = T.sand         -- dock/pier (verified sand)
    TG[9]  = T.short_grass  -- decorative (fountain/statue ground)
    TG[10] = T.cobblestone  -- gate (same surface as road)
    TG[11] = T.wood         -- boardwalk (wood planks)
    TG[12] = T.sand         -- lighthouse (verified sand)

    -- Cobblestone quad from town objects atlas (if available)
    if townObjAtlas then
        -- cobblestone_paths.png: main cobblestone at approximately col 0, row 0
        TileQuadMaps.townCobblestone = quadFromPos(townObjAtlas, 0, 0, 32)
        -- Market stall quad (col 4, row 0 area)
        TileQuadMaps.townMarketStall = quadFromPos(townObjAtlas, 4, 0, 32)
    end

    print("TileQuadMaps: " .. TileQuadMaps.countTable(TG) .. " town ground quads initialized")
    return true
end

-- ==========================================================================
--                     COMBAT TILE QUAD MAP
-- ==========================================================================
-- Maps tactical combat tile type strings to terrain quads.
-- Combat uses: floor, wall, obstacle, door, pit, water, grass,
-- sand, ice, lava, and various decorations.
-- ==========================================================================

function TileQuadMaps.initCombatTiles(terrainAtlas)
    if not terrainAtlas then return false end

    local T = TileQuadMaps.terrain
    local C = TileQuadMaps.combat

    C.floor     = T.stone_solid   -- grey stone floor (verified)
    C.wall      = T.black_solid   -- pure black wall base (verified)
    C.obstacle  = T.dark_stone    -- dark grey obstacle (verified)
    C.door      = T.wood          -- brown wood door (verified)
    C.pit       = nil             -- pits are drawn as dark voids
    C.water     = T.water         -- deep blue water (verified)
    C.grass     = T.grass         -- grass
    C.sand      = T.sand          -- sand (verified)
    C.ice       = T.ice           -- ice
    C.lava      = T.lava          -- lava
    C.snow      = T.snow          -- snow
    C.dirt      = T.cobblestone   -- cobblestone path (verified)
    C.mud       = T.dark_stone    -- dark stone for mud
    C.stone     = T.cobblestone   -- cobblestone path (verified)
    C.wood      = T.wood          -- brown wood (verified)

    print("TileQuadMaps: " .. TileQuadMaps.countTable(C) .. " combat tile quads initialized")
    return true
end

-- ==========================================================================
--                     DUNGEON TILE QUAD MAP
-- ==========================================================================
-- Maps LPCTilemap.TILES numeric IDs to terrain quads.
-- TILES: EMPTY=0, FLOOR=1, WALL=2, DOOR_CLOSED=3, DOOR_OPEN=4,
--        STAIRS_UP=5, STAIRS_DOWN=6, WATER=7, GRASS=8
-- ==========================================================================

function TileQuadMaps.initDungeonTiles(terrainAtlas)
    if not terrainAtlas then return false end

    local T = TileQuadMaps.terrain
    local D = TileQuadMaps.dungeon

    D[0] = nil              -- EMPTY: no tile (void/darkness)
    D[1] = T.stone_solid    -- FLOOR: solid grey stone (verified)
    D[2] = T.black_solid    -- WALL: pure black base (verified)
    D[3] = T.dark_stone     -- DOOR_CLOSED: dark stone base (procedural door overlay on top)
    D[4] = T.dark_stone     -- DOOR_OPEN: dark stone base (procedural door overlay on top)
    D[5] = T.cobblestone_v2 -- STAIRS_UP: lighter cobblestone (verified)
    D[6] = T.cobblestone_v3 -- STAIRS_DOWN: cobblestone variant (verified)
    D[7] = T.water          -- WATER: deep blue (verified)
    D[8] = T.grass          -- GRASS

    print("TileQuadMaps: " .. TileQuadMaps.countTable(D) .. " dungeon tile quads initialized")
    return true
end

-- ==========================================================================
--                     WORLDMAP TILE QUAD MAP
-- ==========================================================================
-- Maps world tile type strings to worldmap_tileset.png quads (16x16 tiles).
-- The worldmap tileset is 256x336 = 16 cols x 21 rows of 16x16 tiles.
-- Exact positions are approximate and may need adjustment based on
-- the actual tileset layout.
-- ==========================================================================

function TileQuadMaps.initWorldmap(worldmapAtlas)
    if not worldmapAtlas then
        print("TileQuadMaps: No worldmap atlas, skipping worldmap quads")
        return false
    end

    local W = TileQuadMaps.worldmap
    local q = function(col, row) return quadFromPos(worldmapAtlas, col, row, 16) end

    -- These positions are based on common worldmap tileset layouts
    -- Adjust col/row as needed after visual inspection
    W.plains    = q(0, 0)       -- Flat grassland
    W.forest    = q(1, 0)       -- Dense trees
    W.desert    = q(2, 0)       -- Sandy terrain
    W.mountain  = q(3, 0)       -- Rocky peaks
    W.water     = q(4, 0)       -- Ocean/lake
    W.deep_water = q(5, 0)     -- Deep ocean
    W.snow      = q(6, 0)       -- Snowy terrain
    W.swamp     = q(7, 0)       -- Murky wetland
    W.hills     = q(8, 0)       -- Rolling hills
    W.road      = q(9, 0)       -- Path/road
    W.town      = q(10, 0)      -- Town marker tile
    W.dungeon   = q(11, 0)      -- Dungeon entrance
    W.river     = q(12, 0)      -- River tile
    W.coast     = q(13, 0)      -- Coastal transition
    W.volcano   = q(14, 0)      -- Volcanic terrain
    W.ruins     = q(15, 0)      -- Ancient ruins

    print("TileQuadMaps: " .. TileQuadMaps.countTable(W) .. " worldmap quads initialized")
    return true
end

-- ==========================================================================
--                        MASTER INIT
-- ==========================================================================

function TileQuadMaps.init(atlases)
    if TileQuadMaps.initialized then return true end

    atlases = atlases or {}

    local terrainAtlas = atlases.terrain
    local townObjAtlas = atlases.town_objects
    local worldmapAtlas = atlases.worldmap

    local ok = false

    if terrainAtlas then
        ok = TileQuadMaps.initTerrain(terrainAtlas)
        if ok then
            TileQuadMaps.initTownTiles(terrainAtlas, townObjAtlas)
            TileQuadMaps.initCombatTiles(terrainAtlas)
            TileQuadMaps.initDungeonTiles(terrainAtlas)
        end
    else
        print("TileQuadMaps: WARNING - No terrain atlas provided")
    end

    if worldmapAtlas then
        TileQuadMaps.initWorldmap(worldmapAtlas)
    end

    TileQuadMaps.initialized = true
    print("TileQuadMaps: Initialization complete")
    return ok
end

-- ==========================================================================
--                        LOOKUP HELPERS
-- ==========================================================================

-- Get a terrain quad by name, with fallback
function TileQuadMaps.getTerrainQuad(name, fallback)
    return TileQuadMaps.terrain[name] or TileQuadMaps.terrain[fallback] or TileQuadMaps.terrain.grass
end

-- Get a town ground quad by TownGen ID, with fallback to grass
function TileQuadMaps.getTownQuad(towngenID)
    return TileQuadMaps.townGround[towngenID] or TileQuadMaps.terrain.grass
end

-- Get a combat tile quad by name, with fallback
function TileQuadMaps.getCombatQuad(tileName)
    return TileQuadMaps.combat[tileName] or TileQuadMaps.combat.floor or TileQuadMaps.terrain.stone_solid
end

-- Get a dungeon tile quad by LPCTilemap tile type ID
function TileQuadMaps.getDungeonQuad(tileTypeID)
    return TileQuadMaps.dungeon[tileTypeID]
end

-- Get a worldmap quad by tile name
function TileQuadMaps.getWorldmapQuad(tileName)
    return TileQuadMaps.worldmap[tileName] or TileQuadMaps.worldmap.plains
end

-- Count entries in a table (utility)
function TileQuadMaps.countTable(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

return TileQuadMaps
