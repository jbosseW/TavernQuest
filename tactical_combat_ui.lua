-- ============================================================================
-- TACTICAL COMBAT UI
-- Grid rendering, unit display, input handling for tactical combat
-- ============================================================================

local UI = require("ui")
local Renderer2D = require("renderer2d")
local TileQuadMaps = require("tile_quad_maps")

local TacticalUI = {}
local TC     -- TacticalCombat module reference
local getFont -- font helper reference

-- Stealth system integration (loaded safely)
local StealthSystem = nil
pcall(function() StealthSystem = require("stealth_system") end)

-- Colors
local COLORS = {
    -- Tile colors
    floor =       {0.18, 0.20, 0.24},
    wall =        {0.35, 0.30, 0.28},
    obstacle =    {0.28, 0.25, 0.22},
    door =        {0.35, 0.28, 0.18},
    pit =         {0.08, 0.08, 0.12},
    water =       {0.15, 0.22, 0.35},
    rubble =      {0.25, 0.22, 0.20},
    grass =       {0.15, 0.22, 0.15},
    sand =        {0.78, 0.70, 0.42},
    snow =        {0.88, 0.90, 0.92},
    cobblestone = {0.32, 0.32, 0.34},
    -- Phase 10: hazard tile colors
    fire =      {0.55, 0.18, 0.08},
    poison =    {0.15, 0.30, 0.12},
    trap =      {0.30, 0.22, 0.12},
    ice =       {0.25, 0.35, 0.45},

    -- Height tints
    heightHigh = {1.15, 1.15, 1.15},  -- Multiplier for high ground
    heightLow =  {0.85, 0.85, 0.85},  -- Multiplier for low ground

    -- Overlay colors
    moveRange =     {0.25, 0.50, 0.85, 0.35},
    attackRange =   {0.85, 0.25, 0.25, 0.30},
    selectedTile =  {1.0, 1.0, 0.3, 0.40},
    hoveredTile =   {1.0, 1.0, 1.0, 0.20},
    pathLine =      {0.85, 0.85, 0.30, 0.70},
    losBlocked =    {0.9, 0.2, 0.2, 0.3},

    -- Unit colors
    allyUnit =      {0.30, 0.75, 0.95},
    enemyUnit =     {0.95, 0.35, 0.35},
    playerUnit =    {0.35, 0.95, 0.45},
    deadUnit =      {0.35, 0.35, 0.35},

    -- UI panel colors
    panelBg =       {0.10, 0.12, 0.16, 0.96},
    panelBorder =   {0.35, 0.40, 0.50},
    actionBtn =     {0.22, 0.28, 0.38},
    actionBtnHover= {0.32, 0.42, 0.55},
    actionBtnActive={0.40, 0.55, 0.70},
    textWhite =     {1, 1, 1},
    textGray =      {0.6, 0.6, 0.65},
    textGreen =     {0.35, 0.95, 0.45},
    textRed =       {0.95, 0.35, 0.35},
    textYellow =    {0.95, 0.85, 0.30},
    textBlue =      {0.40, 0.70, 0.95},
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function TacticalUI.init(tacticalCombat, fontFunc)
    TC = tacticalCombat
    getFont = fontFunc or UI.fonts.get
end

-- ============================================================================
-- MAIN DRAW FUNCTION
-- ============================================================================

function TacticalUI.draw(combatState, x, y, w, h, mx, my)
    if not combatState or not combatState.grid then return end
    if not TC then
        -- TacticalUI.init() was never called; cannot draw without TC reference
        love.graphics.setColor(1, 0.3, 0.3)
        love.graphics.printf("Tactical UI not initialized", x, y + 20, w, "center")
        return
    end

    local grid = combatState.grid
    local tileSize = TC.TILE_SIZE

    -- Calculate grid rendering position (centered in content area)
    local gridPixelW = grid.width * tileSize
    local gridPixelH = grid.height * tileSize

    -- Reserve space: left for grid, right for info panel, bottom for actions
    local infoPanelW = 180
    local actionPanelH = 110
    local logPanelH = 80

    local availW = w - infoPanelW - 20
    local availH = h - actionPanelH - logPanelH - 10

    -- Scale tile size to fit available space
    local scaleX = availW / gridPixelW
    local scaleY = availH / gridPixelH
    local scale = math.min(scaleX, scaleY, 1.0)  -- Don't scale up
    local renderTileSize = math.floor(tileSize * scale)

    local renderGridW = grid.width * renderTileSize
    local renderGridH = grid.height * renderTileSize
    local gridX = x + (availW - renderGridW) / 2
    local gridY = y + 5

    -- Store layout info for input handling
    combatState._layout = {
        gridX = gridX,
        gridY = gridY,
        tileSize = renderTileSize,
        infoPanelX = x + w - infoPanelW - 5,
        infoPanelY = y + 5,
        infoPanelW = infoPanelW,
        actionPanelX = x + 5,
        actionPanelY = y + h - actionPanelH - logPanelH,
        actionPanelW = w - infoPanelW - 15,
        actionPanelH = actionPanelH,
        logPanelX = x + 5,
        logPanelY = y + h - logPanelH,
        logPanelW = w - 15,
        logPanelH = logPanelH,
    }

    -- Phase 8: apply screen shake offset
    local shakeX, shakeY = 0, 0
    if combatState.screenShake then
        shakeX, shakeY = TC.updateScreenShake(combatState, love.timer.getDelta())
    end
    gridX = gridX + shakeX
    gridY = gridY + shakeY

    -- Phase 8: update floating texts + particles + move animations
    local dt = love.timer.getDelta()
    TC.updateFloatingTexts(combatState, dt)
    TC.updateParticles(combatState, dt)
    TC.updateAnimation(combatState, dt)
    TC.updateMoveAnimations(combatState, dt)

    -- Calculate hovered tile
    combatState.hoveredTile = TacticalUI.getTileFromMouse(combatState, mx, my)

    -- 1) Draw the grid
    TacticalUI.drawGrid(combatState, gridX, gridY, renderTileSize, mx, my)

    -- 2) Draw units on grid
    TacticalUI.drawUnits(combatState, gridX, gridY, renderTileSize)

    -- 3) Draw overlays (movement range, attack range, path)
    TacticalUI.drawOverlays(combatState, gridX, gridY, renderTileSize)

    -- 4) Draw info panel (right side)
    TacticalUI.drawInfoPanel(combatState, combatState._layout.infoPanelX,
        combatState._layout.infoPanelY, infoPanelW, availH)

    -- 5) Draw action panel (bottom)
    TacticalUI.drawActionPanel(combatState, combatState._layout.actionPanelX,
        combatState._layout.actionPanelY, combatState._layout.actionPanelW,
        actionPanelH, mx, my)

    -- 6) Draw combat log (very bottom)
    TacticalUI.drawCombatLog(combatState, combatState._layout.logPanelX,
        combatState._layout.logPanelY, combatState._layout.logPanelW, logPanelH)

    -- 7) Draw tooltip on hovered unit/tile
    TacticalUI.drawTooltip(combatState, mx, my, renderTileSize, gridX, gridY)

    -- 8) Draw skill menu if open
    if combatState.showSkillMenu then
        TacticalUI.drawSkillMenu(combatState, combatState._layout.actionPanelX,
            combatState._layout.actionPanelY - 200, 300, 190, mx, my)
    end

    -- 9) Phase 8: Draw floating damage/heal text
    TacticalUI.drawFloatingTexts(combatState, gridX, gridY, renderTileSize)

    -- 10) Phase 7: Draw status effect icons on units
    TacticalUI.drawStatusIcons(combatState, gridX, gridY, renderTileSize)

    -- 11) Phase 10: Draw hazard tile animations (fire flicker, poison bubbles)
    TacticalUI.drawHazardEffects(combatState, gridX, gridY, renderTileSize)

    -- 12) Phase 8: Draw particles
    TacticalUI.drawParticles(combatState, gridX, gridY, renderTileSize)

    -- 13) Phase 8: Draw attack/skill flash animations
    TacticalUI.drawAnimationEffects(combatState, gridX, gridY, renderTileSize)

    -- 14) Phase 10: Draw interactive object indicators
    TacticalUI.drawInteractiveObjects(combatState, gridX, gridY, renderTileSize)

    -- 15) Stealth: Draw light source icons on grid (when not in stealth visual mode)
    TacticalUI.drawLightSourceIcons(combatState, gridX, gridY, renderTileSize)
end

-- ============================================================================
-- GRID RENDERING
-- ============================================================================

function TacticalUI.drawGrid(combatState, gridX, gridY, tileSize, mx, my)
    local grid = combatState.grid

    local spriteMode = Renderer2D.isSprite()
    local terrainAtlas = spriteMode and Renderer2D.getAtlas("terrain") or nil

    -- Map combat tile types to terrain quad names (verified atlas positions)
    local combatTileQuadMap = {
        floor = "stone_solid",       -- grey stone floor (verified)
        wall = "black_solid",        -- pure black wall (verified)
        obstacle = "dark_stone",     -- dark grey stone (verified)
        door = "wood",               -- brown wood door (verified)
        water = "water",             -- deep blue water (verified)
        grass = "grass",             -- grass tile
        sand = "sand",               -- sand tile (verified)
        ice = "ice",                 -- ice tile
        snow = "snow",               -- snow tile
        cobblestone = "cobblestone", -- cobblestone path (verified)
        rubble = "cobblestone",      -- cobblestone for rubble
        fire = "lava",               -- lava for fire
        poison = "long_grass",       -- long grass for poison
        trap = "dark_stone",         -- dark stone for trap
        lava = "lava",               -- lava tile
        pit = "black_solid",         -- pure black for pit
    }

    for ty = 1, grid.height do
        for tx = 1, grid.width do
            local tile = grid.tiles[ty][tx]
            local px = gridX + (tx - 1) * tileSize
            local py = gridY + (ty - 1) * tileSize

            -- Base tile color
            local baseColor = COLORS[tile.type] or COLORS.floor

            -- Apply height tint
            local r, g, b = baseColor[1], baseColor[2], baseColor[3]
            if tile.height == TC.HEIGHT_HIGH then
                r = r * 1.15
                g = g * 1.15
                b = b * 1.15
            elseif tile.height == TC.HEIGHT_LOW then
                r = r * 0.85
                g = g * 0.85
                b = b * 0.85
            end

            -- Checkerboard pattern for visual clarity
            local checker = (tx + ty) % 2 == 0
            if checker then
                r = r * 1.05
                g = g * 1.05
                b = b * 1.05
            end

            if terrainAtlas then
                local quadName = combatTileQuadMap[tile.type] or "stone_solid"
                local quad = TileQuadMaps.terrain[quadName]
                if quad then
                    local scale = (tileSize - 2) / 32
                    -- Use a light brightness tint so the sprite art shows through naturally.
                    -- Height and checkerboard are applied as subtle multipliers on a white base.
                    local tintR = math.min(1.0, 0.85 + (r * 0.6))
                    local tintG = math.min(1.0, 0.85 + (g * 0.6))
                    local tintB = math.min(1.0, 0.85 + (b * 0.6))
                    if checker then
                        tintR = tintR * 1.03
                        tintG = tintG * 1.03
                        tintB = tintB * 1.03
                    end
                    love.graphics.setColor(
                        math.min(1.0, tintR),
                        math.min(1.0, tintG),
                        math.min(1.0, tintB)
                    )
                    love.graphics.draw(terrainAtlas, quad, px + 1, py + 1, 0, scale, scale)
                else
                    love.graphics.setColor(r, g, b)
                    love.graphics.rectangle("fill", px + 1, py + 1, tileSize - 2, tileSize - 2)
                end
            else
                love.graphics.setColor(r, g, b)
                love.graphics.rectangle("fill", px + 1, py + 1, tileSize - 2, tileSize - 2)
            end

            -- Height indicator (small triangle for elevated tiles)
            if tile.height == TC.HEIGHT_HIGH then
                love.graphics.setColor(0.9, 0.85, 0.4, 0.5)
                love.graphics.polygon("fill",
                    px + tileSize - 10, py + 2,
                    px + tileSize - 2, py + 2,
                    px + tileSize - 2, py + 10
                )
            end

            -- Decoration hints
            if tile.decoration == "tree" then
                love.graphics.setColor(0.2, 0.45, 0.2, 0.7)
                love.graphics.circle("fill", px + tileSize/2, py + tileSize/2, tileSize * 0.3)
            elseif tile.decoration == "rock" then
                love.graphics.setColor(0.45, 0.42, 0.38, 0.6)
                love.graphics.circle("fill", px + tileSize/2, py + tileSize/2, tileSize * 0.25)
            elseif tile.decoration == "grass" then
                love.graphics.setColor(0.2, 0.35, 0.18, 0.3)
                love.graphics.rectangle("fill", px + 1, py + 1, tileSize - 2, tileSize - 2)
            -- SWAMP DECORATIONS
            elseif tile.decoration == "murky_water" then
                love.graphics.setColor(0.25, 0.35, 0.28, 0.6)
                love.graphics.rectangle("fill", px + 1, py + 1, tileSize - 2, tileSize - 2)
            elseif tile.decoration == "log" then
                love.graphics.setColor(0.35, 0.25, 0.15, 0.8)
                love.graphics.rectangle("fill", px + tileSize*0.2, py + tileSize*0.35, tileSize*0.6, tileSize*0.3)
            elseif tile.decoration == "toxic_fungi" then
                love.graphics.setColor(0.3, 0.6, 0.3, 0.5)
                love.graphics.circle("fill", px + tileSize*0.4, py + tileSize*0.5, tileSize*0.15)
                love.graphics.circle("fill", px + tileSize*0.6, py + tileSize*0.5, tileSize*0.12)
            elseif tile.decoration == "moss_stone" then
                love.graphics.setColor(0.35, 0.42, 0.35, 0.6)
                love.graphics.circle("fill", px + tileSize/2, py + tileSize/2, tileSize * 0.2)
            -- DESERT DECORATIONS
            elseif tile.decoration == "sand" then
                love.graphics.setColor(0.78, 0.70, 0.42, 0.4)
                love.graphics.rectangle("fill", px + 1, py + 1, tileSize - 2, tileSize - 2)
            elseif tile.decoration == "desert_rock" then
                love.graphics.setColor(0.65, 0.55, 0.42, 0.7)
                love.graphics.circle("fill", px + tileSize/2, py + tileSize/2, tileSize * 0.28)
            elseif tile.decoration == "cactus" then
                love.graphics.setColor(0.35, 0.52, 0.35, 0.8)
                love.graphics.rectangle("fill", px + tileSize*0.4, py + tileSize*0.25, tileSize*0.2, tileSize*0.5)
            elseif tile.decoration == "sand_dune" then
                love.graphics.setColor(0.85, 0.75, 0.48, 0.3)
                love.graphics.ellipse("fill", px + tileSize/2, py + tileSize/2, tileSize*0.4, tileSize*0.3)
            elseif tile.decoration == "heat_haze" then
                love.graphics.setColor(0.9, 0.7, 0.3, 0.2)
                love.graphics.rectangle("fill", px + 1, py + 1, tileSize - 2, tileSize - 2)
            -- ARCTIC DECORATIONS
            elseif tile.decoration == "snow" then
                love.graphics.setColor(0.88, 0.90, 0.92, 0.3)
                love.graphics.rectangle("fill", px + 1, py + 1, tileSize - 2, tileSize - 2)
            elseif tile.decoration == "ice" then
                love.graphics.setColor(0.65, 0.75, 0.85, 0.5)
                love.graphics.rectangle("fill", px + 1, py + 1, tileSize - 2, tileSize - 2)
            elseif tile.decoration == "snowdrift" then
                love.graphics.setColor(0.92, 0.94, 0.96, 0.7)
                love.graphics.ellipse("fill", px + tileSize/2, py + tileSize/2, tileSize*0.35, tileSize*0.25)
            elseif tile.decoration == "ice_boulder" then
                love.graphics.setColor(0.70, 0.80, 0.88, 0.8)
                love.graphics.circle("fill", px + tileSize/2, py + tileSize/2, tileSize * 0.26)
            -- MOUNTAIN DECORATIONS
            elseif tile.decoration == "rocky_ground" then
                love.graphics.setColor(0.42, 0.40, 0.38, 0.3)
                love.graphics.rectangle("fill", px + 1, py + 1, tileSize - 2, tileSize - 2)
            elseif tile.decoration == "cliff" then
                love.graphics.setColor(0.45, 0.42, 0.38, 0.5)
                love.graphics.rectangle("fill", px + 1, py + 1, tileSize - 2, tileSize - 2)
            elseif tile.decoration == "boulder" then
                love.graphics.setColor(0.50, 0.48, 0.44, 0.8)
                love.graphics.circle("fill", px + tileSize/2, py + tileSize/2, tileSize * 0.3)
            elseif tile.decoration == "loose_rocks" then
                love.graphics.setColor(0.40, 0.38, 0.35, 0.5)
                love.graphics.circle("fill", px + tileSize*0.3, py + tileSize*0.4, tileSize * 0.12)
                love.graphics.circle("fill", px + tileSize*0.6, py + tileSize*0.5, tileSize * 0.10)
                love.graphics.circle("fill", px + tileSize*0.5, py + tileSize*0.7, tileSize * 0.08)
            elseif tile.decoration == "hilltop" then
                love.graphics.setColor(0.25, 0.35, 0.20, 0.3)
                love.graphics.ellipse("fill", px + tileSize/2, py + tileSize/2, tileSize*0.4, tileSize*0.3)
            -- TOWN DECORATIONS
            elseif tile.decoration == "cobblestone" then
                love.graphics.setColor(0.32, 0.32, 0.34, 0.4)
                love.graphics.rectangle("fill", px + 1, py + 1, tileSize - 2, tileSize - 2)
            elseif tile.decoration == "fence" then
                love.graphics.setColor(0.45, 0.35, 0.25, 0.7)
                love.graphics.rectangle("fill", px + tileSize*0.1, py + tileSize*0.3, tileSize*0.8, tileSize*0.1)
                love.graphics.rectangle("fill", px + tileSize*0.2, py + tileSize*0.2, tileSize*0.08, tileSize*0.6)
                love.graphics.rectangle("fill", px + tileSize*0.5, py + tileSize*0.2, tileSize*0.08, tileSize*0.6)
                love.graphics.rectangle("fill", px + tileSize*0.7, py + tileSize*0.2, tileSize*0.08, tileSize*0.6)
            elseif tile.decoration == "barrel" then
                love.graphics.setColor(0.45, 0.35, 0.25, 0.8)
                love.graphics.ellipse("fill", px + tileSize/2, py + tileSize/2, tileSize*0.25, tileSize*0.28)
            elseif tile.decoration == "crate" then
                love.graphics.setColor(0.48, 0.38, 0.28, 0.8)
                love.graphics.rectangle("fill", px + tileSize*0.25, py + tileSize*0.25, tileSize*0.5, tileSize*0.5)
            elseif tile.decoration == "market_stall" then
                love.graphics.setColor(0.65, 0.45, 0.35, 0.7)
                love.graphics.rectangle("fill", px + tileSize*0.15, py + tileSize*0.35, tileSize*0.7, tileSize*0.5)
                love.graphics.setColor(0.75, 0.35, 0.35, 0.5)
                love.graphics.polygon("fill", px + tileSize*0.2, py + tileSize*0.35, px + tileSize*0.5, py + tileSize*0.15, px + tileSize*0.8, py + tileSize*0.35)
            -- CITY DECORATIONS
            elseif tile.decoration == "stone_floor" then
                love.graphics.setColor(0.30, 0.30, 0.32, 0.4)
                love.graphics.rectangle("fill", px + 1, py + 1, tileSize - 2, tileSize - 2)
            elseif tile.decoration == "stone_wall" then
                love.graphics.setColor(0.40, 0.38, 0.36, 0.6)
                love.graphics.rectangle("fill", px + 1, py + 1, tileSize - 2, tileSize - 2)
            elseif tile.decoration == "alley" then
                love.graphics.setColor(0.20, 0.20, 0.22, 0.5)
                love.graphics.rectangle("fill", px + 1, py + 1, tileSize - 2, tileSize - 2)
            -- SHIP DECORATIONS
            elseif tile.decoration == "wooden_deck" then
                love.graphics.setColor(0.45, 0.35, 0.25, 0.5)
                love.graphics.rectangle("fill", px + 1, py + 1, tileSize - 2, tileSize - 2)
                -- Wood planks
                love.graphics.setColor(0.35, 0.25, 0.18, 0.3)
                for i = 0, 2 do
                    love.graphics.line(px + 1, py + i * tileSize/3, px + tileSize - 1, py + i * tileSize/3)
                end
            elseif tile.decoration == "railing" then
                love.graphics.setColor(0.35, 0.30, 0.25, 0.7)
                love.graphics.rectangle("fill", px + tileSize*0.4, py + tileSize*0.1, tileSize*0.2, tileSize*0.8)
            elseif tile.decoration == "mast" then
                love.graphics.setColor(0.40, 0.30, 0.20, 0.9)
                love.graphics.rectangle("fill", px + tileSize*0.42, py + tileSize*0.1, tileSize*0.16, tileSize*0.8)
            -- BUILDING INTERIOR
            elseif tile.decoration == "wooden_floor" then
                love.graphics.setColor(0.40, 0.30, 0.22, 0.4)
                love.graphics.rectangle("fill", px + 1, py + 1, tileSize - 2, tileSize - 2)
            elseif tile.decoration == "door" then
                love.graphics.setColor(0.50, 0.38, 0.28, 0.8)
                love.graphics.rectangle("fill", px + tileSize*0.3, py + 2, tileSize*0.4, tileSize - 4)
            elseif tile.decoration == "table" then
                love.graphics.setColor(0.48, 0.38, 0.28, 0.8)
                love.graphics.rectangle("fill", px + tileSize*0.2, py + tileSize*0.3, tileSize*0.6, tileSize*0.4)
            elseif tile.decoration == "chair" then
                love.graphics.setColor(0.45, 0.35, 0.25, 0.8)
                love.graphics.rectangle("fill", px + tileSize*0.35, py + tileSize*0.4, tileSize*0.3, tileSize*0.3)
            elseif tile.decoration == "bookshelf" then
                love.graphics.setColor(0.42, 0.32, 0.24, 0.85)
                love.graphics.rectangle("fill", px + tileSize*0.2, py + tileSize*0.2, tileSize*0.6, tileSize*0.6)
            elseif tile.decoration == "bed" then
                love.graphics.setColor(0.55, 0.50, 0.45, 0.7)
                love.graphics.rectangle("fill", px + tileSize*0.15, py + tileSize*0.25, tileSize*0.7, tileSize*0.5)
            -- GENERAL
            elseif tile.decoration == "bush" then
                love.graphics.setColor(0.25, 0.42, 0.25, 0.6)
                love.graphics.circle("fill", px + tileSize/2, py + tileSize/2, tileSize * 0.25)
            end

            -- Door indicator
            if tile.type == TC.TILE_DOOR then
                love.graphics.setColor(0.6, 0.45, 0.25)
                love.graphics.rectangle("fill", px + tileSize * 0.3, py + 2, tileSize * 0.4, tileSize - 4)
            end

            -- Grid lines (subtle)
            love.graphics.setColor(0.3, 0.3, 0.35, 0.3)
            love.graphics.rectangle("line", px + 1, py + 1, tileSize - 2, tileSize - 2)

            -- Stealth: light level tint overlay
            if StealthSystem and tile.lightLevel then
                local overlay = StealthSystem.getLightOverlayColor(tile.lightLevel)
                if overlay and overlay[4] > 0 then
                    love.graphics.setColor(overlay)
                    love.graphics.rectangle("fill", px + 1, py + 1, tileSize - 2, tileSize - 2)
                end
            end

            -- Stealth: smoke zone overlay
            if tile.hasSmoke then
                local smokeColor = StealthSystem and StealthSystem.getSmokeOverlayColor()
                    or {0.5, 0.5, 0.5, 0.45}
                love.graphics.setColor(smokeColor)
                love.graphics.rectangle("fill", px + 1, py + 1, tileSize - 2, tileSize - 2)
            end
        end
    end

    -- Reset color to prevent bleeding into subsequent draw calls
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- OVERLAY RENDERING (movement range, attack range, path preview)
-- ============================================================================

function TacticalUI.drawOverlays(combatState, gridX, gridY, tileSize)
    -- Movement range overlay
    if combatState.showMoveRange and combatState.movementTiles then
        for _, tile in ipairs(combatState.movementTiles) do
            local px = gridX + (tile.x - 1) * tileSize
            local py = gridY + (tile.y - 1) * tileSize
            love.graphics.setColor(COLORS.moveRange)
            love.graphics.rectangle("fill", px + 2, py + 2, tileSize - 4, tileSize - 4, 3, 3)
        end
    end

    -- Attack range overlay
    if combatState.showAttackRange and combatState.attackTiles then
        for _, tile in ipairs(combatState.attackTiles) do
            local px = gridX + (tile.x - 1) * tileSize
            local py = gridY + (tile.y - 1) * tileSize
            love.graphics.setColor(COLORS.attackRange)
            love.graphics.rectangle("fill", px + 2, py + 2, tileSize - 4, tileSize - 4, 3, 3)
        end
    end

    -- Hovered tile highlight
    if combatState.hoveredTile then
        local hx, hy = combatState.hoveredTile.x, combatState.hoveredTile.y
        local px = gridX + (hx - 1) * tileSize
        local py = gridY + (hy - 1) * tileSize
        love.graphics.setColor(COLORS.hoveredTile)
        love.graphics.rectangle("fill", px + 1, py + 1, tileSize - 2, tileSize - 2)

        -- Yellow border on hovered tile
        love.graphics.setColor(1, 1, 0.5, 0.6)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", px + 1, py + 1, tileSize - 2, tileSize - 2)
        love.graphics.setLineWidth(1)
    end

    -- Selected tile highlight
    if combatState.selectedTile then
        local sx, sy = combatState.selectedTile.x, combatState.selectedTile.y
        local px = gridX + (sx - 1) * tileSize
        local py = gridY + (sy - 1) * tileSize
        love.graphics.setColor(COLORS.selectedTile)
        love.graphics.rectangle("fill", px + 1, py + 1, tileSize - 2, tileSize - 2)
    end

    -- Stealth: Draw light radius circles when player is hidden (via Hide action in combat)
    if StealthSystem and combatState.grid.lightSources and combatState.playerUnit then
        local playerUnit = combatState.playerUnit
        local showVisuals = playerUnit.isHidden
        if showVisuals then
            -- Draw light source radius circles
            for _, source in ipairs(combatState.grid.lightSources) do
                if source.active then
                    local spx = gridX + (source.x - 1) * tileSize + tileSize / 2
                    local spy = gridY + (source.y - 1) * tileSize + tileSize / 2
                    local radius = source.radius * tileSize
                    -- Yellow transparent circle
                    love.graphics.setColor(1, 1, 0, 0.12)
                    love.graphics.circle("fill", spx, spy, radius)
                    love.graphics.setColor(1, 1, 0, 0.25)
                    love.graphics.setLineWidth(1)
                    love.graphics.circle("line", spx, spy, radius)
                    -- Light source icon
                    love.graphics.setColor(source.color[1] or 1, source.color[2] or 0.7, source.color[3] or 0.3, 0.9)
                    love.graphics.setFont(getFont(math.floor(tileSize * 0.3)))
                    love.graphics.printf(source.icon or "T",
                        gridX + (source.x - 1) * tileSize,
                        gridY + (source.y - 1) * tileSize + tileSize * 0.35,
                        tileSize, "center")
                end
            end

            -- Draw NPC vision cones for living enemies
            for _, unit in ipairs(combatState.allUnits) do
                if unit.isEnemy and unit.hp > 0 then
                    local ux = gridX + (unit.x - 1) * tileSize + tileSize / 2
                    local uy = gridY + (unit.y - 1) * tileSize + tileSize / 2
                    local facing = unit.facing or 0
                    local visionRange = (unit.visionRange or 5) * tileSize
                    local halfAngle = (unit.visionAngle or 90) / 2
                    -- Convert facing to LOVE2D angle: 0=right, 90=down, 180=left, 270=up
                    local facingRad = math.rad(facing)
                    local startAngle = facingRad - math.rad(halfAngle)
                    local endAngle = facingRad + math.rad(halfAngle)
                    -- Red transparent arc
                    love.graphics.setColor(1, 0, 0, 0.12)
                    love.graphics.arc("fill", ux, uy, visionRange, startAngle, endAngle)
                    love.graphics.setColor(1, 0, 0, 0.25)
                    love.graphics.setLineWidth(1)
                    love.graphics.arc("line", "open", ux, uy, visionRange, startAngle, endAngle)
                end
            end
        end
    end

    -- Path preview
    if combatState.currentPath and #combatState.currentPath > 1 then
        love.graphics.setColor(COLORS.pathLine)
        love.graphics.setLineWidth(3)
        for i = 1, #combatState.currentPath - 1 do
            local from = combatState.currentPath[i]
            local to = combatState.currentPath[i + 1]
            local x1 = gridX + (from.x - 0.5) * tileSize
            local y1 = gridY + (from.y - 0.5) * tileSize
            local x2 = gridX + (to.x - 0.5) * tileSize
            local y2 = gridY + (to.y - 0.5) * tileSize
            love.graphics.line(x1, y1, x2, y2)
        end
        love.graphics.setLineWidth(1)

        -- Arrow at end of path
        local last = combatState.currentPath[#combatState.currentPath]
        local px = gridX + (last.x - 0.5) * tileSize
        local py = gridY + (last.y - 0.5) * tileSize
        love.graphics.setColor(COLORS.pathLine)
        love.graphics.circle("fill", px, py, 5)
    end

    -- Stealth: Snuff light mode - highlight snuffable light sources
    if combatState.selectedAction == "snuff_light" and combatState.snuffableLights then
        for _, lightInfo in ipairs(combatState.snuffableLights) do
            local px = gridX + (lightInfo.x - 1) * tileSize
            local py = gridY + (lightInfo.y - 1) * tileSize
            -- Pulsing orange highlight
            local pulse = 0.3 + 0.15 * math.sin(love.timer.getTime() * 4)
            love.graphics.setColor(1, 0.6, 0.1, pulse)
            love.graphics.rectangle("fill", px + 2, py + 2, tileSize - 4, tileSize - 4, 3, 3)
            love.graphics.setColor(1, 0.6, 0.1, 0.7)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", px + 2, py + 2, tileSize - 4, tileSize - 4, 3, 3)
            love.graphics.setLineWidth(1)
            -- Fire icon
            love.graphics.setColor(1, 0.7, 0.2, 0.9)
            love.graphics.setFont(getFont(math.floor(tileSize * 0.35)))
            love.graphics.printf(lightInfo.source.icon or "T",
                px, py + tileSize * 0.3, tileSize, "center")
        end
    end
end

-- ============================================================================
-- UNIT RENDERING
-- ============================================================================

function TacticalUI.drawUnits(combatState, gridX, gridY, tileSize)
    local activeUnit = combatState.activeUnit
    local spriteMode = Renderer2D.isSprite()

    for _, unit in ipairs(combatState.allUnits) do
        if unit.hp > 0 or true then  -- Draw dead units too (grayed out)
            -- Phase 8: Use animated position if available
            local animPos = TC.getAnimatedPosition(combatState, unit)
            local drawX = animPos and (animPos.x - 1) or (unit.x - 1)
            local drawY = animPos and (animPos.y - 1) or (unit.y - 1)
            local px = gridX + drawX * tileSize
            local py = gridY + drawY * tileSize
            local centerX = px + tileSize / 2
            local centerY = py + tileSize / 2
            local radius = tileSize * 0.35

            local isDead = unit.hp <= 0
            local isActive = (unit == activeUnit)

            -- Drop shadow under unit (sprite mode)
            if spriteMode then
                Renderer2D.drawShadow(centerX, py + tileSize - 2, tileSize * 0.5, tileSize * 0.15)
            end

            -- Active unit glow
            if isActive and not isDead then
                love.graphics.setColor(1, 1, 0.5, 0.3 + 0.15 * math.sin(love.timer.getTime() * 4))
                love.graphics.circle("fill", centerX, centerY, radius + 4)
            end

            -- Unit body (circle)
            if isDead then
                love.graphics.setColor(COLORS.deadUnit)
            elseif unit.isPlayer then
                love.graphics.setColor(COLORS.playerUnit)
            elseif unit.faction == "ally" then
                love.graphics.setColor(COLORS.allyUnit)
            else
                love.graphics.setColor(COLORS.enemyUnit)
            end
            love.graphics.circle("fill", centerX, centerY, radius)

            -- Unit border
            local borderColor = isDead and {0.5, 0.5, 0.5} or (isActive and {1, 1, 0.5} or {0.8, 0.8, 0.85})
            love.graphics.setColor(borderColor)
            love.graphics.setLineWidth(isActive and 2.5 or 1.5)
            love.graphics.circle("line", centerX, centerY, radius)
            love.graphics.setLineWidth(1)

            -- Unit letter/portrait indicator
            local letter = ""
            if unit.isPlayer then
                letter = "P"
            elseif unit.isCompanion then
                letter = string.sub(unit.name or "C", 1, 1)
            else
                letter = unit.portrait or string.sub(unit.name or "E", 1, 1)
            end

            love.graphics.setColor(isDead and {0.6, 0.6, 0.6} or {1, 1, 1})
            love.graphics.setFont(getFont(math.floor(tileSize * 0.32)))
            love.graphics.printf(letter, px, centerY - tileSize * 0.16, tileSize, "center")

            -- HP bar below unit
            if not isDead and unit.maxHP and unit.maxHP > 0 then
                local barW = tileSize * 0.7
                local barH = 4
                local barX = px + (tileSize - barW) / 2
                local barY = py + tileSize - barH - 3
                local hpPct = math.max(0, unit.hp / unit.maxHP)

                love.graphics.setColor(0.15, 0.15, 0.2)
                love.graphics.rectangle("fill", barX, barY, barW, barH, 1, 1)

                local barColor = hpPct > 0.5 and {0.3, 0.85, 0.3} or
                                (hpPct > 0.25 and {0.85, 0.85, 0.3} or {0.85, 0.3, 0.3})
                love.graphics.setColor(barColor)
                love.graphics.rectangle("fill", barX, barY, barW * hpPct, barH, 1, 1)
            end

            -- Stealth: Hidden status indicator (eye-slash icon)
            if not isDead and unit.isHidden then
                -- Dim the unit slightly
                love.graphics.setColor(0.3, 0.3, 0.5, 0.4)
                love.graphics.circle("fill", centerX, centerY, radius + 2)
                -- Draw eye-slash icon (using text for now)
                love.graphics.setColor(0.7, 0.7, 1.0, 0.9)
                love.graphics.setFont(getFont(math.floor(tileSize * 0.22)))
                love.graphics.printf("~", px, py + 1, tileSize, "center")
            end

            -- Dead X marker
            if isDead then
                love.graphics.setColor(0.8, 0.2, 0.2, 0.7)
                love.graphics.setLineWidth(2)
                love.graphics.line(centerX - radius * 0.5, centerY - radius * 0.5,
                                   centerX + radius * 0.5, centerY + radius * 0.5)
                love.graphics.line(centerX + radius * 0.5, centerY - radius * 0.5,
                                   centerX - radius * 0.5, centerY + radius * 0.5)
                love.graphics.setLineWidth(1)
            end
        end
    end
end

-- ============================================================================
-- INFO PANEL (Right side - Turn order + selected unit info)
-- ============================================================================

function TacticalUI.drawInfoPanel(combatState, x, y, w, h)
    -- Background
    love.graphics.setColor(COLORS.panelBg)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    love.graphics.setColor(COLORS.panelBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 6, 6)
    love.graphics.setLineWidth(1)

    local innerX = x + 8
    local innerW = w - 16
    local curY = y + 8

    -- Turn indicator
    love.graphics.setColor(COLORS.textYellow)
    love.graphics.setFont(getFont(11))
    love.graphics.printf("TURN " .. combatState.turnNumber, innerX, curY, innerW, "center")
    curY = curY + 18

    -- Active unit info
    local active = combatState.activeUnit
    if active then
        love.graphics.setColor((active.isPlayer or active.isPlayerControlled) and COLORS.playerUnit or
            (active.faction == "ally" and COLORS.allyUnit or COLORS.enemyUnit))
        love.graphics.setFont(getFont(10))
        love.graphics.printf(active.name, innerX, curY, innerW, "center")
        curY = curY + 14

        -- Phase indicator
        local phaseText = ""
        if combatState.turnPhase == "move" then
            phaseText = "[Move Phase]"
        elseif combatState.turnPhase == "action" then
            phaseText = "[Action Phase]"
        elseif combatState.turnPhase == "done" then
            phaseText = "[Turn Done]"
        end
        love.graphics.setColor(COLORS.textGray)
        love.graphics.setFont(getFont(9))
        love.graphics.printf(phaseText, innerX, curY, innerW, "center")
        curY = curY + 16
    end

    -- Divider
    love.graphics.setColor(COLORS.panelBorder)
    love.graphics.line(innerX, curY, innerX + innerW, curY)
    curY = curY + 6

    -- Turn order
    love.graphics.setColor(COLORS.textGray)
    love.graphics.setFont(getFont(9))
    love.graphics.print("TURN ORDER", innerX, curY)
    curY = curY + 14

    for i, entry in ipairs(combatState.turnOrder) do
        local unit = entry.unit
        local isCurrent = (i == combatState.currentTurnIndex)
        local isDead = unit.hp <= 0

        if isCurrent then
            love.graphics.setColor(0.25, 0.35, 0.28, 0.8)
            love.graphics.rectangle("fill", innerX - 2, curY - 1, innerW + 4, 14, 2, 2)
        end

        love.graphics.setFont(getFont(9))
        if isDead then
            love.graphics.setColor(COLORS.deadUnit)
        elseif unit.isPlayer or unit.isPlayerControlled then
            love.graphics.setColor(isCurrent and {0.4, 1, 0.5} or COLORS.playerUnit)
        elseif unit.faction == "ally" then
            love.graphics.setColor(isCurrent and {0.5, 0.9, 1} or COLORS.allyUnit)
        else
            love.graphics.setColor(isCurrent and {1, 0.5, 0.4} or COLORS.enemyUnit)
        end

        local prefix = isCurrent and "> " or "  "
        local name = string.sub(unit.name or "???", 1, 12)
        if isDead then name = name .. " (X)" end
        love.graphics.print(prefix .. name, innerX, curY)
        curY = curY + 14

        if curY > y + h - 90 then break end  -- Don't overflow
    end

    -- Hovered unit info (bottom of info panel)
    if combatState.hoveredTile then
        local hovUnit = TC.getUnitAt(combatState.grid,
            combatState.hoveredTile.x, combatState.hoveredTile.y)
        if hovUnit then
            curY = y + h - 85
            love.graphics.setColor(COLORS.panelBorder)
            love.graphics.line(innerX, curY, innerX + innerW, curY)
            curY = curY + 5

            love.graphics.setColor(hovUnit.faction == "ally" and COLORS.allyUnit or COLORS.enemyUnit)
            love.graphics.setFont(getFont(10))
            love.graphics.print(hovUnit.name, innerX, curY)
            curY = curY + 14

            -- HP
            love.graphics.setColor(COLORS.textWhite)
            love.graphics.setFont(getFont(9))
            love.graphics.print("HP: " .. math.max(0, hovUnit.hp) .. "/" .. (hovUnit.maxHP or hovUnit.hp or 0), innerX, curY)
            curY = curY + 12

            -- ATK/DEF
            love.graphics.print("ATK: " .. hovUnit.attack .. "  DEF: " .. hovUnit.defense, innerX, curY)
            curY = curY + 12

            -- Range
            love.graphics.setColor(COLORS.textGray)
            love.graphics.print("Move: " .. hovUnit.moveRange .. "  Range: " .. hovUnit.attackRange, innerX, curY)
            curY = curY + 12

            -- Position
            love.graphics.print("Pos: (" .. hovUnit.x .. "," .. hovUnit.y .. ")", innerX, curY)
            curY = curY + 12

            -- Phase 7: Show active status effects
            if hovUnit.statusEffects and #hovUnit.statusEffects > 0 then
                local statusNames = {}
                for _, s in ipairs(hovUnit.statusEffects) do
                    table.insert(statusNames, s.template.name .. "(" .. s.remaining .. ")")
                end
                love.graphics.setColor(0.9, 0.7, 0.3)
                love.graphics.print(table.concat(statusNames, " "), innerX, curY)
            end
        end
    end
end

-- ============================================================================
-- ACTION PANEL (Bottom - player action buttons)
-- ============================================================================

function TacticalUI.drawActionPanel(combatState, x, y, w, h, mx, my)
    -- Background
    love.graphics.setColor(COLORS.panelBg)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    love.graphics.setColor(COLORS.panelBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 6, 6)
    love.graphics.setLineWidth(1)

    local active = combatState.activeUnit

    -- If not player-controlled unit's turn, show waiting message
    if not active or not (active.isPlayer or active.isPlayerControlled) then
        love.graphics.setColor(COLORS.textGray)
        love.graphics.setFont(getFont(14))
        local waitText = "Waiting..."
        if active then
            waitText = active.name .. " is acting..."
        end
        love.graphics.printf(waitText, x, y + h/2 - 10, w, "center")
        return
    end

    -- Active unit stats bar
    local statY = y + 8
    love.graphics.setColor(COLORS.textGreen)
    love.graphics.setFont(getFont(11))
    love.graphics.print(active.name, x + 10, statY)

    -- HP bar
    local barX = x + 120
    local barW = 120
    local barH = 12
    local hpPct = math.max(0, active.hp / (active.maxHP or active.hp or 1))
    local hpColor = hpPct > 0.5 and {0.3, 0.85, 0.3} or
        (hpPct > 0.25 and {0.85, 0.85, 0.3} or {0.85, 0.3, 0.3})
    local hpBar = UI.ProgressBar.new({
        x = barX,
        y = statY + 2,
        w = barW,
        h = barH,
        value = hpPct,
        label = active.hp .. "/" .. (active.maxHP or active.hp or 0),
        colorOverride = hpColor
    })
    hpBar:draw()

    -- Mana bar (if player has mana)
    if active.isPlayer and active.data and active.data.mana then
        local manaBarX = barX + barW + 10
        local manaPct = math.max(0, active.data.mana / math.max(1, active.data.maxMana or 1))
        local manaBar = UI.ProgressBar.new({
            x = manaBarX,
            y = statY + 2,
            w = 80,
            h = barH,
            value = manaPct,
            label = active.data.mana .. "/" .. (active.data.maxMana or 0),
            colorOverride = {0.3, 0.4, 0.9}
        })
        manaBar:draw()
    end

    -- Phase status
    love.graphics.setColor(COLORS.textYellow)
    love.graphics.setFont(getFont(9))
    local phaseInfo = ""
    if not active.hasMoved and not active.hasActed then
        phaseInfo = "Move + Action available"
    elseif active.hasMoved and not active.hasActed then
        phaseInfo = "Action available"
    elseif not active.hasMoved and active.hasActed then
        phaseInfo = "Move available"
    else
        phaseInfo = "Turn complete - press End Turn"
    end
    love.graphics.print(phaseInfo, x + w - 220, statY + 2)

    -- Action buttons
    local btnY = y + 32
    local btnW = 90
    local btnH = 34
    local btnSpacing = 8
    local actions = {}

    -- Build action list based on current state
    if not active.hasMoved then
        table.insert(actions, {id = "move", name = "MOVE", key = "M", color = {0.3, 0.65, 0.9}})
    end
    if not active.hasActed then
        table.insert(actions, {id = "attack", name = "ATTACK", key = "A", color = {0.9, 0.35, 0.35}})
        -- Stealth: Shadow Strike button (when hidden, not moved, not acted)
        if StealthSystem and active.isHidden and not active.hasMoved then
            table.insert(actions, {id = "shadow_strike", name = "SHADOW", key = "X", color = {0.5, 0.3, 0.7}})
        end
        table.insert(actions, {id = "skill", name = "SKILL", key = "S", color = {0.5, 0.5, 0.95}})
        table.insert(actions, {id = "item", name = "ITEM", key = "I", color = {0.85, 0.7, 0.3}})
    end
    -- Stealth: HIDE button (when not hidden, not acted, near cover)
    if StealthSystem and not active.hasActed and not active.isHidden then
        local hideAction = StealthSystem.hookGetHideAction(active, combatState)
        if hideAction then
            table.insert(actions, {
                id = "hide",
                name = hideAction.name,
                key = hideAction.key,
                color = hideAction.available and hideAction.color or {0.3, 0.3, 0.4},
                available = hideAction.available,
                tooltip = hideAction.tooltip,
            })
        end
    end
    -- Stealth: SNUFF button (extinguish nearby light sources, costs action)
    if StealthSystem and not active.hasActed and combatState.grid.lightSources then
        local hasNearbyLight = false
        for _, source in ipairs(combatState.grid.lightSources) do
            if source.active and source.canSnuff then
                local dist = math.abs(source.x - active.x) + math.abs(source.y - active.y)
                if dist <= 1 then
                    hasNearbyLight = true
                    break
                end
            end
        end
        if hasNearbyLight then
            table.insert(actions, {id = "snuff_light", name = "SNUFF", key = "F",
                color = {0.7, 0.5, 0.2}})
        end
    end
    table.insert(actions, {id = "flee", name = "FLEE", key = "R", color = {0.85, 0.55, 0.2}})
    -- AUTO button for player-controlled companions (toggle to AI control)
    if active.isPlayerControlled then
        table.insert(actions, {id = "auto_companion", name = "AUTO", key = "T", color = {0.5, 0.7, 0.3}})
    end
    table.insert(actions, {id = "wait", name = "END TURN", key = "W", color = {0.6, 0.6, 0.65}})

    combatState._actionButtons = {}

    local totalBtnW = #actions * (btnW + btnSpacing) - btnSpacing
    local startX = x + (w - totalBtnW) / 2

    for i, action in ipairs(actions) do
        local bx = startX + (i - 1) * (btnW + btnSpacing)
        local hover = mx >= bx and mx <= bx + btnW and my >= btnY and my <= btnY + btnH
        local isSelected = (combatState.selectedAction == action.id)

        -- Button shadow
        love.graphics.setColor(0.05, 0.05, 0.08, 0.5)
        love.graphics.rectangle("fill", bx + 2, btnY + 2, btnW, btnH, 5, 5)

        -- Button fill
        if isSelected then
            love.graphics.setColor(action.color[1] * 0.7, action.color[2] * 0.7, action.color[3] * 0.7)
        elseif hover then
            love.graphics.setColor(action.color[1] * 0.5, action.color[2] * 0.5, action.color[3] * 0.5)
        else
            love.graphics.setColor(action.color[1] * 0.3, action.color[2] * 0.3, action.color[3] * 0.3)
        end
        love.graphics.rectangle("fill", bx, btnY, btnW, btnH, 5, 5)

        -- Button border
        love.graphics.setColor(action.color)
        love.graphics.setLineWidth((hover or isSelected) and 2.5 or 1.5)
        love.graphics.rectangle("line", bx, btnY, btnW, btnH, 5, 5)
        love.graphics.setLineWidth(1)

        -- Button text
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(11))
        love.graphics.printf(action.name, bx, btnY + 5, btnW, "center")
        love.graphics.setFont(getFont(8))
        love.graphics.setColor(0.7, 0.7, 0.75)
        love.graphics.printf("[" .. action.key .. "]", bx, btnY + 21, btnW, "center")

        -- Store button bounds for click detection
        combatState._actionButtons[i] = {
            x = bx, y = btnY, w = btnW, h = btnH,
            id = action.id,
        }
    end

    -- Instructions
    love.graphics.setColor(COLORS.textGray)
    love.graphics.setFont(getFont(9))
    local instrY = btnY + btnH + 8
    if combatState.selectedAction == "move" then
        love.graphics.print("Click a blue tile to move. Right-click or ESC to cancel.", x + 10, instrY)
    elseif combatState.selectedAction == "attack" then
        love.graphics.print("Click an enemy in red range to attack. Right-click or ESC to cancel.", x + 10, instrY)
    elseif combatState.selectedAction == "skill" then
        love.graphics.print("Select a skill, then click a target.", x + 10, instrY)
    elseif combatState.selectedAction == "shadow_strike" then
        love.graphics.setColor(0.6, 0.4, 0.9)
        love.graphics.print("SHADOW STRIKE: Click an enemy to move + attack from stealth!", x + 10, instrY)
    elseif combatState.selectedAction == "snuff_light" then
        love.graphics.setColor(0.7, 0.5, 0.2)
        love.graphics.print("SNUFF LIGHT: Click an adjacent light source to extinguish it. ESC to cancel.", x + 10, instrY)
    else
        -- Show stealth info if hidden
        if active and active.isHidden then
            love.graphics.setColor(0.6, 0.6, 0.9)
            love.graphics.print("HIDDEN - [X] Shadow Strike  [A] Attack (breaks stealth)  [Tab] cycle", x + 10, instrY)
        else
            love.graphics.print("Select an action. [Tab] to cycle targets.", x + 10, instrY)
        end
    end
end

-- ============================================================================
-- COMBAT LOG (Very bottom)
-- ============================================================================

function TacticalUI.drawCombatLog(combatState, x, y, w, h)
    -- Background
    love.graphics.setColor(0.08, 0.08, 0.12, 0.92)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)

    -- Show last few log entries
    local logY = y + 4
    local maxLines = math.floor(h / 14) - 1
    local startIdx = math.max(1, #combatState.log - maxLines + 1)

    love.graphics.setFont(getFont(9))
    for i = startIdx, #combatState.log do
        local entry = combatState.log[i]
        love.graphics.setColor(entry.color or {0.7, 0.7, 0.7})
        love.graphics.print(entry.text, x + 6, logY)
        logY = logY + 13
        if logY > y + h - 5 then break end
    end
end

-- ============================================================================
-- SKILL MENU
-- ============================================================================

function TacticalUI.drawSkillMenu(combatState, x, y, w, h, mx, my)
    local active = combatState.activeUnit
    if not active or not (active.isPlayer or active.isPlayerControlled) then return end

    -- Background
    love.graphics.setColor(0.12, 0.14, 0.20, 0.98)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    love.graphics.setColor(0.5, 0.5, 0.95)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 6, 6)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(COLORS.textBlue)
    love.graphics.setFont(getFont(11))
    love.graphics.print("SKILLS", x + 10, y + 8)

    combatState._skillButtons = {}

    local skills = active.data and active.data.skills or active.skills or {}
    local btnY = y + 28
    local btnH = 28

    for i, skillName in ipairs(skills) do
        -- We'll access the global SKILLS table via the combat state's reference
        local skill = combatState._SKILLS and combatState._SKILLS[skillName]
        if skill then
            local sy = btnY + (i - 1) * (btnH + 4)
            local hover = mx >= x + 8 and mx <= x + w - 8 and my >= sy and my <= sy + btnH
            local canAfford = active.data and active.data.mana >= skill.manaCost

            -- Background
            if hover and canAfford then
                love.graphics.setColor(0.25, 0.28, 0.40)
            else
                love.graphics.setColor(0.16, 0.18, 0.24)
            end
            love.graphics.rectangle("fill", x + 8, sy, w - 16, btnH, 4, 4)

            -- Skill name and cost
            love.graphics.setColor(canAfford and COLORS.textWhite or {0.5, 0.5, 0.5})
            love.graphics.setFont(getFont(10))
            love.graphics.print(skillName, x + 14, sy + 3)

            love.graphics.setFont(getFont(9))
            love.graphics.setColor(canAfford and COLORS.textBlue or {0.4, 0.4, 0.5})
            love.graphics.printf(skill.manaCost .. " MP", x + 8, sy + 3, w - 24, "right")

            -- Description
            if skill.desc then
                love.graphics.setColor(0.5, 0.5, 0.55)
                love.graphics.setFont(getFont(8))
                love.graphics.print(skill.desc, x + 14, sy + 15)
            end

            combatState._skillButtons[i] = {
                x = x + 8, y = sy, w = w - 16, h = btnH,
                skillName = skillName, canAfford = canAfford,
            }

            if sy + btnH > y + h - 10 then break end
        end
    end
end

-- ============================================================================
-- TOOLTIP
-- ============================================================================

function TacticalUI.drawTooltip(combatState, mx, my, tileSize, gridX, gridY)
    if not combatState.hoveredTile then return end

    local hx, hy = combatState.hoveredTile.x, combatState.hoveredTile.y
    local tile = TC.getTile(combatState.grid, hx, hy)
    if not tile then return end

    local unit = tile.unit
    local active = combatState.activeUnit

    -- Show damage preview when hovering enemy in attack mode
    if unit and unit.faction ~= "ally" and active and (active.isPlayer or active.isPlayerControlled) and
       combatState.selectedAction == "attack" then
        local canHit = TC.canAttackTarget(combatState.grid, active, unit)
        if canHit then
            local tipW = 160
            local tipH = 65
            local tipX = math.min(mx + 15, love.graphics.getWidth() - tipW - 10)
            local tipY = math.max(my - tipH - 5, 10)

            love.graphics.setColor(0.1, 0.1, 0.15, 0.95)
            love.graphics.rectangle("fill", tipX, tipY, tipW, tipH, 5, 5)
            love.graphics.setColor(0.7, 0.7, 0.8)
            love.graphics.rectangle("line", tipX, tipY, tipW, tipH, 5, 5)

            -- Estimated damage
            local estDmg = math.max(1, active.attack - unit.defense)
            local estMin = math.max(1, estDmg - 3)
            local estMax = estDmg + 3

            love.graphics.setColor(COLORS.textWhite)
            love.graphics.setFont(getFont(10))
            love.graphics.print(unit.name, tipX + 8, tipY + 6)
            love.graphics.setFont(getFont(9))
            love.graphics.setColor(COLORS.textRed)
            love.graphics.print("Est. Damage: " .. estMin .. "-" .. estMax, tipX + 8, tipY + 22)
            love.graphics.setColor(COLORS.textYellow)
            love.graphics.print("Crit: " .. (active.critChance or 5) .. "%", tipX + 8, tipY + 36)

            -- Flanking indicator
            local flankBonus = TC.calculateFlankingBonus(combatState.grid, active, unit)
            if flankBonus > 0 then
                love.graphics.setColor(0.9, 0.7, 0.3)
                love.graphics.print("FLANKED +" .. math.floor(flankBonus * 100) .. "%", tipX + 8, tipY + 50)
            end
        end
    end

    -- Tile info (bottom of tooltip area) for terrain tiles
    if not unit and tile.type ~= TC.TILE_FLOOR then
        local terrain = TC.TERRAIN[tile.type]
        if terrain then
            love.graphics.setColor(COLORS.textGray)
            love.graphics.setFont(getFont(9))
            local tipX = mx + 12
            local tipY = my + 12
            love.graphics.setColor(0.1, 0.1, 0.15, 0.9)
            love.graphics.rectangle("fill", tipX, tipY, 100, 20, 3, 3)
            love.graphics.setColor(COLORS.textGray)
            love.graphics.print(terrain.name, tipX + 5, tipY + 3)
        end
    end
end

-- ============================================================================
-- INPUT HANDLING
-- ============================================================================

-- Convert mouse position to grid tile
function TacticalUI.getTileFromMouse(combatState, mx, my)
    if not combatState._layout then return nil end
    local layout = combatState._layout
    local gridX = layout.gridX
    local gridY = layout.gridY
    local tileSize = layout.tileSize

    local tx = math.floor((mx - gridX) / tileSize) + 1
    local ty = math.floor((my - gridY) / tileSize) + 1

    if tx >= 1 and tx <= combatState.grid.width and ty >= 1 and ty <= combatState.grid.height then
        return {x = tx, y = ty}
    end
    return nil
end

-- Handle mouse click (returns action result or nil)
function TacticalUI.handleClick(combatState, mx, my, button, SKILLS)
    local active = combatState.activeUnit
    if not active or not (active.isPlayer or active.isPlayerControlled) then return nil end

    -- Right-click: cancel current action
    if button == 2 then
        combatState.selectedAction = nil
        combatState.showMoveRange = false
        combatState.showAttackRange = false
        combatState.showSkillMenu = false
        combatState.currentPath = nil
        combatState.selectedTile = nil
        return {type = "cancel"}
    end

    -- Check action button clicks
    if combatState._actionButtons then
        for _, btn in ipairs(combatState._actionButtons) do
            if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                return TacticalUI.handleActionButton(combatState, btn.id)
            end
        end
    end

    -- Check skill menu clicks
    if combatState.showSkillMenu and combatState._skillButtons then
        for _, btn in ipairs(combatState._skillButtons) do
            if btn.canAfford and mx >= btn.x and mx <= btn.x + btn.w and
               my >= btn.y and my <= btn.y + btn.h then
                combatState.selectedSkill = btn.skillName
                combatState.showSkillMenu = false
                combatState.selectedAction = "skill_target"
                combatState.showAttackRange = true

                -- Calculate skill attack range
                local skill = SKILLS[btn.skillName]
                local skillRange = 1
                if skill then
                    skillRange = skill.range or active.attackRange
                    if type(skillRange) == "string" then
                        skillRange = skillRange == "ranged" and 5 or (skillRange == "melee" and 1 or 3)
                    end
                end
                combatState.attackTiles = TC.getAttackRange(
                    combatState.grid, active.x, active.y, 1, skillRange
                )

                return {type = "skill_selected", skill = btn.skillName}
            end
        end
    end

    -- Check grid tile clicks
    local tile = TacticalUI.getTileFromMouse(combatState, mx, my)
    if tile then
        return TacticalUI.handleTileClick(combatState, tile.x, tile.y, SKILLS)
    end

    return nil
end

-- Handle action button press
function TacticalUI.handleActionButton(combatState, actionId)
    local active = combatState.activeUnit
    if not active then return nil end

    combatState.showSkillMenu = false
    combatState.currentPath = nil

    if actionId == "move" then
        combatState.selectedAction = "move"
        combatState.showMoveRange = true
        combatState.showAttackRange = false
        -- Recalculate movement tiles from current position
        combatState.movementTiles = TC.getMovementRange(
            combatState.grid, active.x, active.y, TC.getEffectiveMoveRange(active)
        )
        return {type = "action_selected", action = "move"}

    elseif actionId == "attack" then
        combatState.selectedAction = "attack"
        combatState.showMoveRange = false
        combatState.showAttackRange = true
        combatState.attackTiles = TC.getAttackRange(
            combatState.grid, active.x, active.y,
            active.minAttackRange or 1, active.attackRange
        )
        return {type = "action_selected", action = "attack"}

    elseif actionId == "skill" then
        combatState.selectedAction = "skill"
        combatState.showSkillMenu = not combatState.showSkillMenu
        combatState.showMoveRange = false
        combatState.showAttackRange = false
        return {type = "action_selected", action = "skill"}

    elseif actionId == "item" then
        return {type = "open_inventory"}

    elseif actionId == "flee" then
        combatState.selectedAction = nil
        combatState.showMoveRange = false
        combatState.showAttackRange = false
        combatState.showSkillMenu = false
        return {type = "flee"}

    elseif actionId == "hide" then
        -- Stealth: Attempt to hide
        combatState.selectedAction = nil
        combatState.showMoveRange = false
        combatState.showAttackRange = false
        combatState.showSkillMenu = false
        return {type = "hide"}

    elseif actionId == "shadow_strike" then
        -- Stealth: Shadow Strike (move + attack from hidden)
        combatState.selectedAction = "shadow_strike"
        combatState.showMoveRange = false
        combatState.showAttackRange = true
        combatState.showSkillMenu = false
        -- Show extended attack range for shadow strike
        local moveRange = TC.getEffectiveMoveRange(active) + 2  -- Shadow strike bonus
        combatState.attackTiles = TC.getAttackRange(
            combatState.grid, active.x, active.y,
            1, moveRange + (active.attackRange or 1)
        )
        return {type = "action_selected", action = "shadow_strike"}

    elseif actionId == "snuff_light" then
        -- Stealth: Enter snuff light mode (click a nearby light source to extinguish)
        combatState.selectedAction = "snuff_light"
        combatState.showMoveRange = false
        combatState.showAttackRange = false
        combatState.showSkillMenu = false
        -- Highlight snuffable light sources adjacent to the player
        combatState.snuffableLights = {}
        if combatState.grid.lightSources then
            for idx, source in ipairs(combatState.grid.lightSources) do
                if source.active and source.canSnuff then
                    local dist = math.abs(source.x - active.x) + math.abs(source.y - active.y)
                    if dist <= 1 then
                        table.insert(combatState.snuffableLights, {
                            idx = idx, source = source,
                            x = source.x, y = source.y,
                        })
                    end
                end
            end
        end
        return {type = "action_selected", action = "snuff_light"}

    elseif actionId == "auto_companion" then
        combatState.selectedAction = nil
        combatState.showMoveRange = false
        combatState.showAttackRange = false
        combatState.showSkillMenu = false
        return {type = "auto_companion"}

    elseif actionId == "wait" then
        combatState.selectedAction = nil
        combatState.showMoveRange = false
        combatState.showAttackRange = false
        return {type = "end_turn"}
    end

    return nil
end

-- Handle clicking on a grid tile
function TacticalUI.handleTileClick(combatState, tx, ty, SKILLS)
    local active = combatState.activeUnit
    if not active then return nil end
    local grid = combatState.grid

    -- MOVE action: click a valid movement tile
    if combatState.selectedAction == "move" and not active.hasMoved then
        -- Check if the tile is in movement range
        local validMove = false
        for _, tile in ipairs(combatState.movementTiles or {}) do
            if tile.x == tx and tile.y == ty then
                validMove = true
                break
            end
        end

        if validMove and TC.isTilePassable(grid, tx, ty) then
            return {type = "move", targetX = tx, targetY = ty}
        end
    end

    -- SHADOW STRIKE action: click a tile with an enemy (extended range from hidden)
    if combatState.selectedAction == "shadow_strike" and not active.hasActed and active.isHidden then
        local targetUnit = TC.getUnitAt(grid, tx, ty)
        if targetUnit and targetUnit.faction ~= active.faction and targetUnit.hp > 0 then
            return {type = "shadow_strike", target = targetUnit, targetX = tx, targetY = ty}
        end
    end

    -- SNUFF LIGHT action: click a tile with a snuffable light source
    if combatState.selectedAction == "snuff_light" and not active.hasActed then
        if combatState.snuffableLights then
            for _, lightInfo in ipairs(combatState.snuffableLights) do
                if lightInfo.x == tx and lightInfo.y == ty then
                    return {type = "snuff_light", lightIdx = lightInfo.idx, source = lightInfo.source}
                end
            end
        end
    end

    -- ATTACK action: click a tile with an enemy or interactive object
    if combatState.selectedAction == "attack" and not active.hasActed then
        local targetUnit = TC.getUnitAt(grid, tx, ty)
        if targetUnit and targetUnit.faction ~= active.faction and targetUnit.hp > 0 then
            if TC.canAttackTarget(grid, active, targetUnit) then
                return {type = "attack", target = targetUnit}
            end
        end
        -- Phase 10: Attack interactive objects (barrels, crates, explosive barrels)
        local tile = TC.getTile(grid, tx, ty)
        if tile and tile.interactiveObject then
            local dist = TC.getDistance(active.x, active.y, tx, ty)
            if dist <= (active.attackRange or 1) then
                return {type = "interact_object", targetX = tx, targetY = ty}
            end
        end
    end

    -- SKILL TARGET: click a tile to target with selected skill
    if combatState.selectedAction == "skill_target" and combatState.selectedSkill and not active.hasActed then
        local targetUnit = TC.getUnitAt(grid, tx, ty)
        local skill = SKILLS and SKILLS[combatState.selectedSkill]

        if skill then
            -- Damage skills target enemies
            if skill.damage then
                if targetUnit and targetUnit.faction ~= active.faction and targetUnit.hp > 0 then
                    return {type = "skill", skillName = combatState.selectedSkill, targetX = tx, targetY = ty}
                end
            end
            -- Heal skills target allies
            if skill.heal then
                if targetUnit and targetUnit.faction == active.faction and targetUnit.hp > 0 then
                    return {type = "skill", skillName = combatState.selectedSkill, targetX = tx, targetY = ty}
                end
            end
            -- AOE skills can target any valid tile
            if skill.aoe then
                return {type = "skill", skillName = combatState.selectedSkill, targetX = tx, targetY = ty}
            end
        end
    end

    -- Default: just select the tile
    combatState.selectedTile = {x = tx, y = ty}
    return nil
end

-- Handle keyboard input
function TacticalUI.handleKey(combatState, key, SKILLS)
    local active = combatState.activeUnit
    if not active or not (active.isPlayer or active.isPlayerControlled) then return nil end

    if key == "m" then
        return TacticalUI.handleActionButton(combatState, "move")
    elseif key == "a" then
        return TacticalUI.handleActionButton(combatState, "attack")
    elseif key == "s" then
        return TacticalUI.handleActionButton(combatState, "skill")
    elseif key == "i" then
        return TacticalUI.handleActionButton(combatState, "item")
    elseif key == "h" and not combatState._showHelp then
        -- Stealth: Hide action (H key, but only if not showing help overlay)
        if StealthSystem and not active.hasActed and not active.isHidden then
            return TacticalUI.handleActionButton(combatState, "hide")
        end
    elseif key == "x" then
        -- Stealth: Shadow Strike (X key)
        if StealthSystem and active.isHidden and not active.hasMoved and not active.hasActed then
            return TacticalUI.handleActionButton(combatState, "shadow_strike")
        end
    elseif key == "f" then
        -- Stealth: Snuff light (F key)
        if StealthSystem and not active.hasActed and combatState.grid.lightSources then
            local hasNearbyLight = false
            for _, source in ipairs(combatState.grid.lightSources) do
                if source.active and source.canSnuff then
                    local dist = math.abs(source.x - active.x) + math.abs(source.y - active.y)
                    if dist <= 1 then
                        hasNearbyLight = true
                        break
                    end
                end
            end
            if hasNearbyLight then
                return TacticalUI.handleActionButton(combatState, "snuff_light")
            end
        end
    elseif key == "t" then
        if active.isPlayerControlled then
            return TacticalUI.handleActionButton(combatState, "auto_companion")
        end
    elseif key == "r" then
        return TacticalUI.handleActionButton(combatState, "flee")
    elseif key == "w" or key == "space" then
        return TacticalUI.handleActionButton(combatState, "wait")
    elseif key == "escape" then
        combatState.selectedAction = nil
        combatState.showMoveRange = false
        combatState.showAttackRange = false
        combatState.showSkillMenu = false
        combatState.currentPath = nil
        combatState.selectedTile = nil
        combatState.snuffableLights = nil
        return {type = "cancel"}
    elseif key == "tab" then
        -- Cycle through enemy targets
        local enemies = TC.getLivingUnits(combatState, "enemy")
        if #enemies > 0 then
            local currentIdx = 1
            if combatState.selectedTile then
                for i, e in ipairs(enemies) do
                    if e.x == combatState.selectedTile.x and e.y == combatState.selectedTile.y then
                        currentIdx = i
                        break
                    end
                end
            end
            local nextIdx = (currentIdx % #enemies) + 1
            local nextEnemy = enemies[nextIdx]
            combatState.selectedTile = {x = nextEnemy.x, y = nextEnemy.y}
            combatState.hoveredTile = {x = nextEnemy.x, y = nextEnemy.y}
            return {type = "target_cycle"}
        end
    end

    return nil
end

-- Update path preview when mouse moves over movement tiles
function TacticalUI.updatePathPreview(combatState, mx, my)
    if combatState.selectedAction ~= "move" then
        combatState.currentPath = nil
        return
    end

    local active = combatState.activeUnit
    if not active or active.hasMoved then return end

    local tile = TacticalUI.getTileFromMouse(combatState, mx, my)
    if tile and TC.isTilePassable(combatState.grid, tile.x, tile.y) then
        combatState.currentPath = TC.findPath(
            combatState.grid, active.x, active.y, tile.x, tile.y, TC.getEffectiveMoveRange(active)
        )
    else
        combatState.currentPath = nil
    end
end

-- ============================================================================
-- PHASE 8: FLOATING DAMAGE / HEAL TEXT
-- ============================================================================

function TacticalUI.drawFloatingTexts(combatState, gridX, gridY, tileSize)
    if not combatState.floatingTexts then return end

    for _, ft in ipairs(combatState.floatingTexts) do
        local px = gridX + (ft.worldX - 0.5) * tileSize
        local py = gridY + (ft.worldY - 0.5) * tileSize + ft.offsetY

        local alpha = 1.0
        if ft.timer > ft.duration * 0.6 then
            alpha = 1.0 - ((ft.timer - ft.duration * 0.6) / (ft.duration * 0.4))
        end

        local fontSize = 14
        if ft.style == "crit" then fontSize = 18 end
        if ft.style == "heal" then fontSize = 13 end
        if ft.style == "status" then fontSize = 10 end

        love.graphics.setColor(0, 0, 0, alpha * 0.7)
        love.graphics.setFont(getFont(fontSize))
        love.graphics.printf(ft.text, px - 50 + 1, py + 1, 100, "center")

        love.graphics.setColor(ft.color[1], ft.color[2], ft.color[3], alpha)
        love.graphics.printf(ft.text, px - 50, py, 100, "center")
    end
end

-- ============================================================================
-- PHASE 7: STATUS EFFECT ICONS ON UNITS
-- ============================================================================

function TacticalUI.drawStatusIcons(combatState, gridX, gridY, tileSize)
    for _, unit in ipairs(combatState.allUnits) do
        if unit.hp > 0 and unit.statusEffects and #unit.statusEffects > 0 then
            local px = gridX + (unit.x - 1) * tileSize
            local py = gridY + (unit.y - 1) * tileSize
            local iconX = px + 2
            local iconY = py + 1

            for j, s in ipairs(unit.statusEffects) do
                local col = s.template.color or {0.8, 0.8, 0.8}
                love.graphics.setColor(col[1], col[2], col[3], 0.9)
                love.graphics.circle("fill", iconX + 4, iconY + 4, 3)
                love.graphics.setColor(1, 1, 1, 0.85)
                love.graphics.setFont(getFont(7))
                love.graphics.print(string.sub(s.template.name, 1, 1), iconX + 1, iconY - 1)
                iconX = iconX + 9
                if j >= 3 then break end
            end
        end
    end
end

-- ============================================================================
-- PHASE 10: HAZARD TILE ANIMATED EFFECTS
-- ============================================================================

function TacticalUI.drawHazardEffects(combatState, gridX, gridY, tileSize)
    local grid = combatState.grid
    local t = love.timer.getTime()

    for ty = 1, grid.height do
        for tx = 1, grid.width do
            local tile = grid.tiles[ty][tx]
            local px = gridX + (tx - 1) * tileSize
            local py = gridY + (ty - 1) * tileSize

            if tile.type == "fire" then
                local flicker = 0.5 + 0.3 * math.sin(t * 6 + tx * 1.7 + ty * 2.3)
                love.graphics.setColor(0.95, 0.45 * flicker, 0.1, 0.45)
                love.graphics.rectangle("fill", px + 3, py + 3, tileSize - 6, tileSize - 6, 2, 2)
                love.graphics.setColor(1, 0.8, 0.2, 0.3 * flicker)
                love.graphics.circle("fill", px + tileSize/2 + math.sin(t*4)*3, py + tileSize/2, tileSize*0.15)

            elseif tile.type == "poison" then
                local bubble = 0.5 + 0.3 * math.sin(t * 3 + tx * 2.1)
                love.graphics.setColor(0.3, 0.75, 0.2, 0.35)
                love.graphics.rectangle("fill", px + 3, py + 3, tileSize - 6, tileSize - 6, 2, 2)
                love.graphics.setColor(0.4, 0.9, 0.3, 0.25 * bubble)
                love.graphics.circle("fill", px + tileSize*0.3, py + tileSize*0.6 + math.sin(t*2)*2, 3)
                love.graphics.circle("fill", px + tileSize*0.7, py + tileSize*0.4 + math.cos(t*2.5)*2, 2)

            elseif tile.type == "trap" and not tile._trapTriggered then
                local pulse = 0.2 + 0.1 * math.sin(t * 2)
                love.graphics.setColor(0.8, 0.6, 0.2, pulse)
                love.graphics.setFont(getFont(math.floor(tileSize * 0.3)))
                love.graphics.printf("!", px, py + tileSize * 0.3, tileSize, "center")

            elseif tile.type == "ice" then
                local sheen = 0.15 + 0.05 * math.sin(t * 1.5 + tx + ty)
                love.graphics.setColor(0.6, 0.8, 1.0, sheen)
                love.graphics.rectangle("fill", px + 2, py + 2, tileSize - 4, tileSize - 4, 2, 2)
            end
        end
    end
end

-- ============================================================================
-- PHASE 9: HELP / TUTORIAL OVERLAY
-- ============================================================================

function TacticalUI.drawHelpOverlay(combatState, x, y, w, h)
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", x, y, w, h, 8, 8)
    love.graphics.setColor(0.5, 0.6, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 8, 8)
    love.graphics.setLineWidth(1)

    local cx = x + 20
    local cy = y + 15

    love.graphics.setColor(COLORS.textYellow)
    love.graphics.setFont(getFont(16))
    love.graphics.print("TACTICAL COMBAT - QUICK REFERENCE", cx, cy)
    cy = cy + 28

    love.graphics.setFont(getFont(11))
    local lines = {
        {"CONTROLS", COLORS.textYellow},
        {"[M] Move       - Select a blue tile to move your unit", COLORS.textWhite},
        {"[A] Attack     - Select an enemy in red range to strike", COLORS.textWhite},
        {"[S] Skill      - Open skill menu, then click a target", COLORS.textWhite},
        {"[I] Item       - Open inventory for consumables", COLORS.textWhite},
        {"[R] Flee       - Attempt to escape (50% chance, costs turn on fail)", COLORS.textWhite},
        {"[W] End Turn   - Pass to the next combatant", COLORS.textWhite},
        {"[Tab] Cycle    - Cycle through enemy targets", COLORS.textWhite},
        {"[Esc] Cancel   - Cancel current action selection", COLORS.textWhite},
        {"Right-Click    - Cancel current action", COLORS.textWhite},
        {"", COLORS.textWhite},
        {"MECHANICS", COLORS.textYellow},
        {"Each turn you get one MOVE and one ACTION.", COLORS.textGray},
        {"Flanking: allies adjacent to target grant +15/30% damage.", COLORS.textGray},
        {"High ground: +10/25% damage, ranged units get +1 range.", COLORS.textGray},
        {"Terrain: water slows, rubble gives defense, walls block LOS.", COLORS.textGray},
        {"", COLORS.textWhite},
        {"STATUS EFFECTS", COLORS.textYellow},
        {"Poison/Burn/Bleed: damage over time. Stun: skip turn.", COLORS.textGray},
        {"Root: cannot move. Slow: -1 move range. Weaken: -3 ATK.", COLORS.textGray},
        {"Shield: -30% damage taken. Blessed: +4 ATK/+2 DEF.", COLORS.textGray},
        {"Marked: +25% damage taken. Evasion: 40% dodge chance.", COLORS.textGray},
        {"", COLORS.textWhite},
        {"ENVIRONMENT", COLORS.textYellow},
        {"Fire tiles: 8 damage + burn. Poison tiles: 5 damage + poison.", COLORS.textGray},
        {"Trap tiles: 12 damage (one-time). Ice tiles: may cause slip.", COLORS.textGray},
        {"Barrels/Crates: destroy for possible potions or scrolls.", COLORS.textGray},
        {"Powder Kegs: explode on destroy dealing 15 AOE damage.", COLORS.textGray},
        {"Levers: activate to toggle doors on the battlefield.", COLORS.textGray},
        {"Skills with AOE hit enemies within radius of target tile.", COLORS.textGray},
        {"", COLORS.textWhite},
        {"Press [H] or [F1] to toggle this help screen.", COLORS.textBlue},
        {"Press [F9] or Options menu to switch combat modes.", COLORS.textBlue},
    }

    for _, line in ipairs(lines) do
        love.graphics.setColor(line[2])
        love.graphics.print(line[1], cx, cy)
        cy = cy + 15
    end
end

-- ============================================================================
-- PHASE 8: PARTICLE RENDERING
-- ============================================================================

function TacticalUI.drawParticles(combatState, gridX, gridY, tileSize)
    if not combatState.particles then return end

    for _, p in ipairs(combatState.particles) do
        local progress = p.life / p.maxLife
        local alpha = 1.0 - progress  -- fade out
        local size = p.size * (1.0 - progress * 0.5)

        local px = gridX + (p.x - 0.5) * tileSize
        local py = gridY + (p.y - 0.5) * tileSize

        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha * 0.85)

        if p.type == "explosion" then
            -- Bright expanding circle
            local expSize = size * (1 + progress * 2)
            love.graphics.circle("fill", px, py, expSize)
        elseif p.type == "heal" then
            -- Rising sparkle
            love.graphics.circle("fill", px, py - progress * 20, size * 0.8)
        elseif p.type == "buff" then
            -- Spiraling upward
            local spiral = progress * math.pi * 4
            love.graphics.circle("fill", px + math.sin(spiral) * 6, py - progress * 15, size * 0.7)
        else
            -- Default: scattered sparks
            love.graphics.circle("fill", px, py, size)
        end
    end
end

-- ============================================================================
-- PHASE 8: ANIMATION EFFECT RENDERING (attack flash, skill flash, AOE blast)
-- ============================================================================

function TacticalUI.drawAnimationEffects(combatState, gridX, gridY, tileSize)
    local anim = TC.getCurrentAnimation(combatState)
    if not anim then return end

    local t = anim.timer / anim.duration
    local alpha = 1.0 - t

    if anim.type == "attack_flash" then
        local data = anim.data
        local px = gridX + (data.targetX - 0.5) * tileSize
        local py = gridY + (data.targetY - 0.5) * tileSize
        local flashSize = tileSize * 0.6 * (1 + t * 0.5)

        if data.isCrit then
            -- Large bright flash for crits
            love.graphics.setColor(1, 0.9, 0.2, alpha * 0.7)
            love.graphics.circle("fill", px, py, flashSize)
            love.graphics.setColor(1, 1, 1, alpha * 0.5)
            love.graphics.circle("fill", px, py, flashSize * 0.5)
        else
            -- Quick white flash
            love.graphics.setColor(1, 1, 1, alpha * 0.6)
            love.graphics.circle("fill", px, py, flashSize * 0.7)
        end

        -- Directional line from attacker to target
        if data.attackerX and data.attackerY then
            local ax = gridX + (data.attackerX - 0.5) * tileSize
            local ay = gridY + (data.attackerY - 0.5) * tileSize
            love.graphics.setColor(1, 0.8, 0.3, alpha * 0.5)
            love.graphics.setLineWidth(2)
            love.graphics.line(ax + (px - ax) * t, ay + (py - ay) * t, px, py)
            love.graphics.setLineWidth(1)
        end

    elseif anim.type == "skill_flash" then
        local data = anim.data
        local px = gridX + (data.targetX - 0.5) * tileSize
        local py = gridY + (data.targetY - 0.5) * tileSize
        local col = data.color or {0.5, 0.5, 1}
        local size = tileSize * 0.5 * (1 + t)

        love.graphics.setColor(col[1], col[2], col[3], alpha * 0.6)
        love.graphics.circle("fill", px, py, size)
        -- Inner bright core
        love.graphics.setColor(1, 1, 1, alpha * 0.4)
        love.graphics.circle("fill", px, py, size * 0.3)

    elseif anim.type == "aoe_blast" then
        local data = anim.data
        local cx = gridX + (data.centerX - 0.5) * tileSize
        local cy = gridY + (data.centerY - 0.5) * tileSize
        local radius = data.radius * tileSize * t
        local col = data.color or {1, 0.6, 0.2, 0.4}

        -- Expanding ring
        love.graphics.setColor(col[1], col[2], col[3], alpha * 0.4)
        love.graphics.circle("fill", cx, cy, radius)
        love.graphics.setColor(col[1], col[2], col[3], alpha * 0.6)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", cx, cy, radius)
        love.graphics.setLineWidth(1)
    end
end

-- ============================================================================
-- PHASE 10: INTERACTIVE OBJECT RENDERING
-- ============================================================================

function TacticalUI.drawInteractiveObjects(combatState, gridX, gridY, tileSize)
    local grid = combatState.grid
    local t = love.timer.getTime()

    for ty = 1, grid.height do
        for tx = 1, grid.width do
            local tile = grid.tiles[ty][tx]
            if tile.interactiveObject then
                local obj = tile.interactiveObject
                local px = gridX + (tx - 1) * tileSize
                local py = gridY + (ty - 1) * tileSize

                if obj.type == "barrel" then
                    love.graphics.setColor(0.55, 0.35, 0.2, 0.85)
                    love.graphics.rectangle("fill",
                        px + tileSize * 0.2, py + tileSize * 0.15,
                        tileSize * 0.6, tileSize * 0.7, 4, 4)
                    love.graphics.setColor(0.45, 0.28, 0.15)
                    love.graphics.rectangle("line",
                        px + tileSize * 0.2, py + tileSize * 0.15,
                        tileSize * 0.6, tileSize * 0.7, 4, 4)
                    -- Metal bands
                    love.graphics.setColor(0.5, 0.5, 0.5, 0.6)
                    love.graphics.line(px + tileSize * 0.2, py + tileSize * 0.4,
                        px + tileSize * 0.8, py + tileSize * 0.4)
                    love.graphics.line(px + tileSize * 0.2, py + tileSize * 0.65,
                        px + tileSize * 0.8, py + tileSize * 0.65)

                elseif obj.type == "crate" then
                    love.graphics.setColor(0.5, 0.38, 0.22, 0.85)
                    love.graphics.rectangle("fill",
                        px + tileSize * 0.15, py + tileSize * 0.15,
                        tileSize * 0.7, tileSize * 0.7, 2, 2)
                    love.graphics.setColor(0.4, 0.3, 0.15)
                    love.graphics.rectangle("line",
                        px + tileSize * 0.15, py + tileSize * 0.15,
                        tileSize * 0.7, tileSize * 0.7, 2, 2)
                    -- Cross planks
                    love.graphics.line(px + tileSize * 0.15, py + tileSize * 0.15,
                        px + tileSize * 0.85, py + tileSize * 0.85)
                    love.graphics.line(px + tileSize * 0.85, py + tileSize * 0.15,
                        px + tileSize * 0.15, py + tileSize * 0.85)

                elseif obj.type == "explosive_barrel" then
                    -- Red/orange barrel
                    love.graphics.setColor(0.65, 0.2, 0.15, 0.85)
                    love.graphics.rectangle("fill",
                        px + tileSize * 0.2, py + tileSize * 0.15,
                        tileSize * 0.6, tileSize * 0.7, 4, 4)
                    -- Warning glow
                    local glow = 0.3 + 0.2 * math.sin(t * 4)
                    love.graphics.setColor(1, 0.5, 0.1, glow)
                    love.graphics.circle("fill", px + tileSize/2, py + tileSize/2, tileSize * 0.15)
                    -- Danger symbol
                    love.graphics.setColor(1, 0.9, 0.2, 0.8)
                    love.graphics.setFont(getFont(math.floor(tileSize * 0.3)))
                    love.graphics.printf("!", px, py + tileSize * 0.2, tileSize, "center")

                elseif obj.type == "lever" then
                    local activated = obj.activated
                    love.graphics.setColor(0.5, 0.5, 0.5, 0.8)
                    love.graphics.rectangle("fill",
                        px + tileSize * 0.4, py + tileSize * 0.6,
                        tileSize * 0.2, tileSize * 0.3)
                    -- Lever arm
                    local armAngle = activated and -0.5 or 0.5
                    love.graphics.setColor(activated and {0.3, 0.8, 0.3, 0.9} or {0.7, 0.5, 0.2, 0.9})
                    love.graphics.setLineWidth(3)
                    love.graphics.line(
                        px + tileSize/2, py + tileSize * 0.6,
                        px + tileSize/2 + armAngle * tileSize * 0.25,
                        py + tileSize * 0.25
                    )
                    love.graphics.setLineWidth(1)
                    -- Knob
                    love.graphics.circle("fill",
                        px + tileSize/2 + armAngle * tileSize * 0.25,
                        py + tileSize * 0.25, 3)
                end

                -- HP bar for destructible objects
                if obj.hp < 999 and obj.hp < obj.maxHP then
                    local barW = tileSize * 0.6
                    local barH = 3
                    local barX = px + (tileSize - barW) / 2
                    local barY = py + 2
                    local hpPct = math.max(0, obj.hp / obj.maxHP)

                    love.graphics.setColor(0.15, 0.15, 0.2)
                    love.graphics.rectangle("fill", barX, barY, barW, barH, 1, 1)
                    love.graphics.setColor(0.8, 0.6, 0.2)
                    love.graphics.rectangle("fill", barX, barY, barW * hpPct, barH, 1, 1)
                end
            end
        end
    end
end

-- ============================================================================
-- STEALTH: LIGHT SOURCE ICONS ON GRID
-- ============================================================================

function TacticalUI.drawLightSourceIcons(combatState, gridX, gridY, tileSize)
    if not StealthSystem then return end
    local grid = combatState.grid
    if not grid.lightSources then return end

    -- Only draw small icons when player is NOT in stealth visual mode
    -- (stealth visual mode draws full radius circles in drawOverlays)
    local playerUnit = combatState.playerUnit
    local showVisuals = playerUnit and playerUnit.isHidden
    if showVisuals then return end  -- Already drawn in overlays

    -- Draw light source markers with icon letter and glow
    for _, source in ipairs(grid.lightSources) do
        local px = gridX + (source.x - 1) * tileSize
        local py = gridY + (source.y - 1) * tileSize
        local cx = px + tileSize - 8
        local cy = py + 8

        if source.active then
            -- Warm glow circle
            love.graphics.setColor(source.color[1] or 1, source.color[2] or 0.7, source.color[3] or 0.3, 0.3)
            love.graphics.circle("fill", cx, cy, 6)
            -- Bright center dot
            love.graphics.setColor(source.color[1] or 1, source.color[2] or 0.7, source.color[3] or 0.3, 0.8)
            love.graphics.circle("fill", cx, cy, 3)
            -- Icon letter
            local iconFont = getFont(math.max(8, math.floor(tileSize * 0.2)))
            love.graphics.setFont(iconFont)
            love.graphics.setColor(1, 1, 1, 0.7)
            love.graphics.print(source.icon or "?", cx - 3, cy - 5)
        else
            -- Snuffed: dim marker
            love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
            love.graphics.circle("fill", cx, cy, 3)
        end
    end
end

-- ============================================================================
-- STEALTH: PRE-COMBAT APPROACH MENU
-- ============================================================================

function TacticalUI.drawStealthApproachMenu(approachResult, screenW, screenH, mx, my, getFont_fn)
    if not approachResult or not StealthSystem then return end
    local gf = getFont_fn or getFont

    local layout = StealthSystem.getStealthMenuLayout(approachResult, screenW, screenH)
    local menuX, menuY, menuW, menuH = layout.x, layout.y, layout.w, layout.h

    -- Background
    love.graphics.setColor(0.08, 0.08, 0.12, 0.96)
    love.graphics.rectangle("fill", menuX, menuY, menuW, menuH, 8, 8)
    love.graphics.setColor(0.5, 0.5, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", menuX, menuY, menuW, menuH, 8, 8)
    love.graphics.setLineWidth(1)

    local curY = menuY + 12

    -- Title
    love.graphics.setColor(0.9, 0.9, 0.3)
    love.graphics.setFont(gf(14))
    love.graphics.printf("STEALTH APPROACH", menuX, curY, menuW, "center")
    curY = curY + 22

    -- Detection info
    local detColor = approachResult.detectionColor or {0.7, 0.7, 0.7}
    love.graphics.setColor(detColor)
    love.graphics.setFont(gf(11))
    love.graphics.printf(
        "Detection: " .. approachResult.detectionPercent .. "% (" .. approachResult.detectionLevel .. ")",
        menuX + 15, curY, menuW - 30, "center"
    )
    curY = curY + 18

    -- Detection breakdown (show what factors affect detection)
    if approachResult.breakdown and #approachResult.breakdown > 0 then
        love.graphics.setFont(gf(8))
        local breakdownLines = StealthSystem.formatBreakdown(approachResult.breakdown)
        for _, line in ipairs(breakdownLines) do
            love.graphics.setColor(0.55, 0.55, 0.65)
            love.graphics.print(line, menuX + 18, curY)
            curY = curY + 11
        end
        curY = curY + 4
    end

    -- Separator
    love.graphics.setColor(0.3, 0.3, 0.4)
    love.graphics.line(menuX + 15, curY, menuX + menuW - 15, curY)
    curY = curY + 8

    -- Options
    local buttons = {}
    for i, option in ipairs(approachResult.options) do
        local optY = curY
        local optH = layout.optionHeight
        local isHover = mx >= menuX + 10 and mx <= menuX + menuW - 10
            and my >= optY and my <= optY + optH

        -- Option background
        if isHover and option.available then
            love.graphics.setColor(0.18, 0.20, 0.30)
        else
            love.graphics.setColor(0.12, 0.12, 0.16)
        end
        love.graphics.rectangle("fill", menuX + 10, optY, menuW - 20, optH - 4, 4, 4)

        -- Option number and name
        local optColor = option.available and (option.color or {0.8, 0.8, 0.8}) or {0.4, 0.4, 0.4}
        love.graphics.setColor(optColor)
        love.graphics.setFont(gf(11))
        local chanceText = option.chance and option.chance > 0
            and string.format(" (%d%%)", math.floor(option.chance * 100)) or ""
        love.graphics.print("[" .. i .. "] " .. option.name .. chanceText, menuX + 18, optY + 4)

        -- Description
        love.graphics.setColor(option.available and {0.6, 0.6, 0.65} or {0.35, 0.35, 0.4})
        love.graphics.setFont(gf(9))
        love.graphics.print(option.desc or "", menuX + 30, optY + 20)

        -- Karma indicator
        if option.karmaChange and option.karmaChange ~= 0 then
            love.graphics.setColor(option.karmaChange < 0 and {0.9, 0.3, 0.3} or {0.3, 0.9, 0.3})
            love.graphics.printf(
                "Karma: " .. option.karmaChange,
                menuX + 10, optY + 4, menuW - 30, "right"
            )
        end

        buttons[i] = {
            x = menuX + 10, y = optY,
            w = menuW - 20, h = optH - 4,
            option = option,
        }
        curY = curY + optH
    end

    return buttons
end

return TacticalUI
