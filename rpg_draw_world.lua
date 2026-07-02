-- rpg_draw_world.lua
-- Extracted world/town/combat/UI draw functions from textrpg.lua
-- Covers: town, stable, jail, property, camping, map, dungeon, combat,
--         dialogue, shop, death, graveyard, inventory, quest log, and misc UI draws.

local M = {}
local state, F

local Renderer2D = require("renderer2d")
local TileQuadMaps = require("tile_quad_maps")
local Camera2D = require("camera2d")
local SpriteManager = require("spritemanager")

-- Only list functions that are ACTUALLY extracted (have real code in this module).
-- Functions that remain in textrpg.lua are NOT listed here to avoid overwriting them.
M.F_FUNCTIONS = {
    "drawTown",
    "drawGuild",
    "drawStable",
    "drawLockpickPrompt",
    "drawLockpicking",
    "drawJail",
    "drawBurglarySuccess",
    "drawPropertyPurchase",
    "drawPropertyManage",
    "drawLandOffice",
    "drawLandClaim",
    "drawLandManage",
    "drawParty",
    "drawCamping",
    "drawCamp",
    "drawCampMain",
    "drawCampCooking",
    "drawCampChat",
    "drawCampRest",
    "drawCampGuard",
    "drawResting",
    "drawTravelingHome",
    "drawPaidTravel",
    "drawDistrict",
    "drawGuildHall",
    "drawUnderbelly",
    "drawBountyBoard",
    "drawCourierOffice",
    "drawCompass",
    "drawMap",
    "drawDungeon",
    "drawCombat",
    "drawDialogue",
    "drawNPCList",
    "drawTavernInterior",
    "drawJobBoard",
    "drawGuildInterior",
    "drawReviveHero",
    "drawBuildingInterior",
    "drawNPCDialogue",
    "drawDeathScreen",
    "drawGraveyard",
    "drawInventory",
    "drawQuestLog",
    "drawShop",
    "drawMarket",
}

function M.register(s, f)
    state = s
    F = f
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

-- Helper: access getFont through F
local function getFont(size)
    if F and F.getFont then return F.getFont(size) end
    return love.graphics.getFont()
end

-- ============================================================================
-- SPRITE-BASED TOWN MAP RENDERER
-- ============================================================================

-- Sprite-based town map rendering
-- Draws terrain tiles, building sprites, NPC sprites, and player sprite
-- Returns nothing; drawn in the map area defined by mapX, mapY, mapW, mapH
local function drawTownMapSprite(mapX, mapY, mapW, mapH, buildingW, buildingH, buildingPadX, buildingPadY, gridCols, gridRows, curStreetCol, curStreetRows, playerGridX, playerGridY, currentBuilding, activeBuildingList, mx, my)
    -- Clip to map area
    love.graphics.setScissor(mapX, mapY, mapW, mapH)

    -- Calculate tile size within each grid cell
    -- Each grid cell is buildingW x buildingH pixels
    -- We'll fill with 32x32 terrain tiles
    local tileSize = 32
    local terrainAtlas = Renderer2D.getAtlas("terrain")

    if not terrainAtlas then
        love.graphics.setScissor()
        return false  -- Signal caller to fall back to classic rendering
    end

    -- Draw ground terrain tiles filling the entire map area
    local tilesWide = math.ceil(mapW / tileSize)
    local tilesHigh = math.ceil(mapH / tileSize)

    local grassQuad = TileQuadMaps.terrain.grass
    local roadQuad = TileQuadMaps.terrain.cobblestone    -- verified cobblestone path
    local dirtQuad = TileQuadMaps.terrain.dark_stone     -- verified dark stone
    local plazaQuad = TileQuadMaps.terrain.stone_solid   -- verified solid grey stone
    local gardenQuad = TileQuadMaps.terrain.long_grass
    local waterQuad = TileQuadMaps.terrain.water
    local sandQuad = TileQuadMaps.terrain.sand

    -- Build a set of street rows for fast lookup
    local streetRowSet = {}
    for _, r in ipairs(curStreetRows) do streetRowSet[r] = true end

    love.graphics.setColor(1, 1, 1, 1)

    -- For each 32x32 tile in the map area, determine what terrain to draw
    for ty = 0, tilesHigh - 1 do
        for tx = 0, tilesWide - 1 do
            local px = mapX + tx * tileSize
            local py = mapY + ty * tileSize

            -- Determine which grid cell this tile falls in
            local relX = tx * tileSize - buildingPadX
            local relY = ty * tileSize - buildingPadY
            local gridX = math.floor(relX / buildingW) + 1
            local gridY = math.floor(relY / buildingH) + 1

            -- Default to grass
            local quad = grassQuad

            -- Check if this is a street tile
            if gridX == curStreetCol then
                quad = roadQuad
            elseif streetRowSet[gridY] then
                quad = roadQuad
            end

            -- Check if this tile is under a building
            if quad == grassQuad then
                for _, building in ipairs(activeBuildingList) do
                    if building.gridX and building.gridY then
                        local bCols = building.wide and 2 or 1
                        if gridX >= building.gridX and gridX < building.gridX + bCols and gridY == building.gridY then
                            quad = dirtQuad
                            break
                        end
                    end
                end
            end

            -- Draw the terrain tile
            if quad and terrainAtlas then
                love.graphics.draw(terrainAtlas, quad, px, py)
            end
        end
    end

    -- Draw buildings as sprite composites
    local castleAtlas = Renderer2D.getAtlas("buildings_castle")
    local wallsAtlas = Renderer2D.getAtlas("walls")

    for _, building in ipairs(activeBuildingList) do
        if building.gridX and building.gridY then
            local bx, by, bw, bh
            if building.wide then
                bw = buildingW * 2
                bh = buildingH - 10
                bx = mapX + buildingPadX + (building.gridX - 1) * buildingW
                by = mapY + buildingPadY + (building.gridY - 1) * buildingH
            else
                bw = buildingW - 10
                bh = buildingH - 10
                bx = mapX + buildingPadX + (building.gridX - 1) * buildingW + 5
                by = mapY + buildingPadY + (building.gridY - 1) * buildingH
            end

            local isSelected = currentBuilding and currentBuilding.id == building.id

            -- Draw building using tiles from castle atlas if available
            if castleAtlas then
                -- Fill building area with wall tiles from castle atlas
                local wallQuad = love.graphics.newQuad(0, 0, 32, 32, castleAtlas:getDimensions())
                local roofQuad = love.graphics.newQuad(32, 0, 32, 32, castleAtlas:getDimensions())
                local doorQuad = love.graphics.newQuad(64, 0, 32, 32, castleAtlas:getDimensions())

                love.graphics.setColor(1, 1, 1, 1)
                -- Draw wall tiles filling building area
                for bty = 0, math.floor(bh / tileSize) - 1 do
                    for btx = 0, math.floor(bw / tileSize) - 1 do
                        local tpx = bx + btx * tileSize
                        local tpy = by + bty * tileSize
                        if bty == 0 then
                            -- Top row = roof
                            love.graphics.draw(castleAtlas, roofQuad, tpx, tpy)
                        elseif bty == math.floor(bh / tileSize) - 1 and btx == math.floor(bw / tileSize / 2) then
                            -- Bottom center = door
                            love.graphics.draw(castleAtlas, doorQuad, tpx, tpy)
                        else
                            -- Everything else = wall
                            love.graphics.draw(castleAtlas, wallQuad, tpx, tpy)
                        end
                    end
                end
            else
                -- Fallback: tinted rectangle with building color (still better than pure colored rect)
                local bc = building.color
                love.graphics.setColor(bc[1], bc[2], bc[3], 0.85)
                love.graphics.rectangle("fill", bx, by, bw, bh, 4, 4)
            end

            -- Selection highlight border
            if isSelected then
                love.graphics.setColor(1, 0.9, 0.5, 0.9)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", bx, by, bw, bh, 4, 4)
                love.graphics.setLineWidth(1)
            else
                love.graphics.setColor(0.2, 0.2, 0.25, 0.6)
                love.graphics.rectangle("line", bx, by, bw, bh, 4, 4)
            end

            -- Building name label (small, below or inside building)
            love.graphics.setColor(1, 1, 1, 0.95)
            love.graphics.setFont(getFont(building.wide and 10 or 8))
            love.graphics.printf(building.name, bx, by + bh - 14, bw, "center")

            -- Lock overlay
            if building.locked then
                love.graphics.setColor(0.05, 0.05, 0.1, 0.5)
                love.graphics.rectangle("fill", bx, by, bw, bh, 4, 4)
                love.graphics.setColor(0.8, 0.6, 0.2, 0.9)
                love.graphics.printf("LOCKED", bx, by + bh/2 - 6, bw, "center")
            end
        end
    end

    -- Draw hidden buildings with eerie glow
    local HIDDEN_TOWN_BUILDINGS = F.HIDDEN_TOWN_BUILDINGS or {}
    for _, building in ipairs(HIDDEN_TOWN_BUILDINGS) do
        if building.condition and building.condition() then
            local bx = mapX + buildingPadX + (building.gridX - 1) * buildingW + 5
            local by = mapY + buildingPadY + (building.gridY - 1) * buildingH
            local bw = buildingW - 10
            local bh = buildingH - 10

            local pulse = 0.3 + 0.2 * math.sin(love.timer.getTime() * 2)
            love.graphics.setColor(0.4, 0.1, 0.5, pulse)
            love.graphics.rectangle("fill", bx, by, bw, bh, 4, 4)
            love.graphics.setColor(0.7, 0.3, 0.8, 0.8)
            love.graphics.printf(building.name, bx, by + bh/2 - 6, bw, "center")
        end
    end

    -- Draw NPCs on the map (using the new visible NPC system)
    local town = state.world.currentTown
    if F.initializeTownNPCs then F.initializeTownNPCs(town) end
    local TownNPCsVisible = require("townnpcsvisible")
    TownNPCsVisible.draw(mapX, mapY, buildingW, buildingH, buildingPadX, buildingPadY, playerGridX, playerGridY, mx, my)

    -- Draw player as a sprite or enhanced indicator
    local playerPulse = 0.7 + 0.3 * math.sin(love.timer.getTime() * 5)
    local playerDrawX = mapX + buildingPadX + (playerGridX - 1) * buildingW + buildingW/2
    local playerDrawY = mapY + buildingPadY + (playerGridY - 1) * buildingH + buildingH/2

    -- Draw drop shadow under player
    Renderer2D.drawShadow(playerDrawX, playerDrawY + 10, 24, 8)

    -- Draw player sprite (or enhanced fallback)
    local drawPlayerSprite = F.drawPlayerSprite or function(px, py, fallback) fallback() end
    drawPlayerSprite(playerDrawX, playerDrawY, function()
        -- Enhanced fallback: colored circle with white border instead of plain @
        love.graphics.setColor(0.1, 0.6, 0.2, 0.4)
        love.graphics.circle("fill", playerDrawX, playerDrawY, 16)
        love.graphics.setColor(0.2, 0.9 * playerPulse, 0.3)
        love.graphics.circle("fill", playerDrawX, playerDrawY, 12)
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("line", playerDrawX, playerDrawY, 12)
        love.graphics.setFont(getFont(14))
        love.graphics.printf("@", playerDrawX - 15, playerDrawY - 8, 30, "center")
    end)

    love.graphics.setScissor()
    return true  -- Signal success to caller
end

-- ============================================================================
-- TOWN DRAW
-- ============================================================================

M.drawTown = function(x, y, w, h, mx, my)
    local town = state.world.currentTown
    if not town then return end

    -- Initialize town player position if needed
    if F.initTownPlayerPosition then F.initTownPlayerPosition() end

    -- Title
    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(18))
    love.graphics.printf(town.name .. " (Lv." .. town.level .. ")", x, y + 5, w, "center")

    -- Show town specialization
    love.graphics.setColor(0.6, 0.7, 0.5)
    love.graphics.setFont(getFont(10))
    love.graphics.printf(town.specialization or "Trade Hub", x, y + 26, w, "center")

    -- Weather display (top right corner)
    local getCurrentWeather = F.getCurrentWeather or function() return "pleasant" end
    local WEATHER_EFFECTS = F.WEATHER_EFFECTS or {}
    local weather = getCurrentWeather()
    local weatherFx = WEATHER_EFFECTS[weather] or WEATHER_EFFECTS.pleasant or {color={0.7,0.7,0.7}, icon="?", name="Unknown", desc=""}
    local weatherX = x + w - 130
    local weatherY = y + 5

    love.graphics.setColor(0.1, 0.12, 0.15, 0.85)
    love.graphics.rectangle("fill", weatherX, weatherY, 120, 32, 4, 4)
    love.graphics.setColor(weatherFx.color)
    love.graphics.setFont(getFont(14))
    love.graphics.print(weatherFx.icon, weatherX + 6, weatherY + 4)
    love.graphics.setFont(getFont(10))
    love.graphics.print(weatherFx.name, weatherX + 28, weatherY + 5)
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.setFont(getFont(8))
    love.graphics.printf(weatherFx.desc, weatherX + 5, weatherY + 19, 110, "left")

    -- Town map area (adjusted for navigation arrows on right)
    local mapX = x + 20
    local mapY = y + 45
    local mapW = w - 140  -- Leave room for navigation arrows
    local mapH = h - 100

    -- Draw town ground/background
    love.graphics.setColor(0.15, 0.18, 0.12)
    love.graphics.rectangle("fill", mapX, mapY, mapW, mapH, 8, 8)

    -- Draw cobblestone path pattern
    love.graphics.setColor(0.22, 0.2, 0.18)
    for py = 0, mapH - 10, 20 do
        love.graphics.rectangle("fill", mapX + mapW/2 - 30, mapY + py, 60, 18, 2, 2)
    end

    -- Calculate building dimensions (dynamic grid from per-town data)
    local TOWN_GRID_COLS = F.TOWN_GRID_COLS or 6
    local TOWN_GRID_ROWS = F.TOWN_GRID_ROWS or 12
    local TOWN_STREET_COL = F.TOWN_STREET_COL or 3
    local TOWN_STREET_ROWS = F.TOWN_STREET_ROWS or {2, 4, 6, 8, 10}
    local gridCols = (town.townGridCols) or TOWN_GRID_COLS
    local gridRows = (town.townGridRows) or TOWN_GRID_ROWS
    local curStreetCol = (town.townStreetCol) or TOWN_STREET_COL
    local curStreetRows = (town.townStreetRows) or TOWN_STREET_ROWS
    local buildingW = math.floor((mapW - 40) / gridCols)
    local buildingH = math.floor((mapH - 30) / gridRows)
    local buildingPadX = (mapW - gridCols * buildingW) / 2
    local buildingPadY = 5

    -- Get player position (needed by both branches)
    local playerGridX = state.townPlayerX or 2.5
    local playerGridY = state.townPlayerY or 5
    local currentBuilding = F.getTownBuildingAt and F.getTownBuildingAt(playerGridX, playerGridY) or nil
    local getCurrentTownBuildings = F.getCurrentTownBuildings or function() return {} end
    local activeBuildingList = getCurrentTownBuildings()

    -- SPRITE MODE: Use tile-based rendering for the map area
    -- Falls back to classic mode if sprite rendering fails (e.g. terrain atlas not loaded)
    local spriteRendered = false
    if Renderer2D.isSprite() then
        local result = drawTownMapSprite(mapX, mapY, mapW, mapH, buildingW, buildingH, buildingPadX, buildingPadY, gridCols, gridRows, curStreetCol, curStreetRows, playerGridX, playerGridY, currentBuilding, activeBuildingList, mx, my)
        spriteRendered = (result ~= false)
    end
    if not spriteRendered then
    -- CLASSIC MODE: Original colored rectangle rendering

    -- Draw main street as a cobblestone path
    local streetX = mapX + buildingPadX + (curStreetCol - 1) * buildingW
    love.graphics.setColor(0.28, 0.25, 0.22)
    love.graphics.rectangle("fill", streetX, mapY, buildingW, mapH)
    -- Street cobblestone details
    love.graphics.setColor(0.32, 0.28, 0.24)
    for py = 0, mapH - 8, 16 do
        love.graphics.rectangle("fill", streetX + 5, mapY + py + 2, buildingW - 10, 12, 2, 2)
    end
    -- Street border lines
    love.graphics.setColor(0.2, 0.18, 0.15)
    love.graphics.setLineWidth(2)
    love.graphics.line(streetX, mapY, streetX, mapY + mapH)
    love.graphics.line(streetX + buildingW, mapY, streetX + buildingW, mapY + mapH)
    love.graphics.setLineWidth(1)

    -- Draw horizontal streets (dynamic rows)
    for _, streetRow in ipairs(curStreetRows) do
        local streetY = mapY + buildingPadY + (streetRow - 1) * buildingH
        -- Street base
        love.graphics.setColor(0.28, 0.25, 0.22)
        love.graphics.rectangle("fill", mapX, streetY, mapW, buildingH - 10)
        -- Street cobblestone details
        love.graphics.setColor(0.32, 0.28, 0.24)
        for px = 0, mapW - 16, 24 do
            love.graphics.rectangle("fill", mapX + px + 4, streetY + 3, 18, buildingH - 16, 2, 2)
        end
        -- Street border lines
        love.graphics.setColor(0.2, 0.18, 0.15)
        love.graphics.setLineWidth(1)
        love.graphics.line(mapX, streetY, mapX + mapW, streetY)
        love.graphics.line(mapX, streetY + buildingH - 10, mapX + mapW, streetY + buildingH - 10)
    end

    -- Helper function to draw a single building
    local function drawBuilding(building, isHiddenBuilding)
        local bx, by, bw, bh

        if building.wide then
            -- Wide building (like the gate) spans 2 columns
            bw = buildingW * 2
            bh = buildingH - 10
            bx = mapX + buildingPadX + (building.gridX - 1) * buildingW
            by = mapY + buildingPadY + (building.gridY - 1) * buildingH
        else
            bw = buildingW - 10
            bh = buildingH - 10
            bx = mapX + buildingPadX + (building.gridX - 1) * buildingW + 5
            by = mapY + buildingPadY + (building.gridY - 1) * buildingH
        end

        -- Check if player is currently on this building
        local isSelected = currentBuilding and currentBuilding.id == building.id

        -- Building shadow
        love.graphics.setColor(0.05, 0.05, 0.08, 0.5)
        love.graphics.rectangle("fill", bx + 3, by + 3, bw, bh, 6, 6)

        -- Building base
        local bc = building.color
        if isSelected then
            love.graphics.setColor(bc[1] * 1.3, bc[2] * 1.3, bc[3] * 1.3)
        else
            love.graphics.setColor(bc[1], bc[2], bc[3])
        end
        love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)

        -- Roof highlight
        love.graphics.setColor(bc[1] * 0.7, bc[2] * 0.7, bc[3] * 0.7)
        love.graphics.rectangle("fill", bx, by, bw, 12, 6, 6)
        love.graphics.rectangle("fill", bx, by + 6, bw, 6)

        -- Building border (highlight selected building)
        if isSelected then
            love.graphics.setColor(1, 0.9, 0.5)
            love.graphics.setLineWidth(3)
        else
            love.graphics.setColor(0.3, 0.3, 0.35)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", bx, by, bw, bh, 6, 6)
        love.graphics.setLineWidth(1)

        -- Building icon/text
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(building.wide and 14 or 9))
        love.graphics.printf(building.icon, bx, by + bh/2 - 14, bw, "center")

        -- Building name
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.setFont(getFont(building.wide and 10 or 7))
        love.graphics.printf(building.name, bx, by + bh - 14, bw, "center")

        -- Lock icon for locked buildings
        if building.locked then
            love.graphics.setColor(0.8, 0.6, 0.2)
            love.graphics.setFont(getFont(10))
            love.graphics.print("\xF0\x9F\x94\x92", bx + bw - 14, by + 2)
            -- Dim overlay for locked buildings
            love.graphics.setColor(0.1, 0.1, 0.15, 0.4)
            love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)
        end

        -- Special effect for hidden buildings (eerie glow)
        if isHiddenBuilding then
            local pulse = 0.3 + 0.2 * math.sin(love.timer.getTime() * 2)
            love.graphics.setColor(0.5, 0.1, 0.3, pulse)
            love.graphics.rectangle("fill", bx, by, bw, bh, 6, 6)
        end
    end

    -- Draw normal buildings (use per-town list if available, else static)
    for _, building in ipairs(activeBuildingList) do
        -- Skip buildings that have no grid position assigned
        if building.gridX and building.gridY then
            -- Check if a hidden building replaces this one
            local hiddenReplacement = F.getVisibleHiddenBuilding and F.getVisibleHiddenBuilding(building.gridX, building.gridY)
            if not hiddenReplacement then
                drawBuilding(building, false)
            end
        end
    end

    -- Draw visible hidden buildings
    local HIDDEN_TOWN_BUILDINGS = F.HIDDEN_TOWN_BUILDINGS or {}
    for _, building in ipairs(HIDDEN_TOWN_BUILDINGS) do
        if building.condition and building.condition() then
            drawBuilding(building, true)
        end
    end

    -- Draw NPCs on the map (using the new visible NPC system)
    if F.initializeTownNPCs then F.initializeTownNPCs(town) end  -- Ensure NPCs are initialized
    local TownNPCsVisible = require("townnpcsvisible")
    TownNPCsVisible.draw(mapX, mapY, buildingW, buildingH, buildingPadX, buildingPadY, playerGridX, playerGridY, mx, my)

    -- Draw player position (pulsing indicator)
    local pulse = 0.7 + 0.3 * math.sin(love.timer.getTime() * 5)

    -- Calculate player screen position (center of the grid cell)
    local playerDrawX = mapX + buildingPadX + (playerGridX - 1) * buildingW + buildingW/2
    local playerDrawY = mapY + buildingPadY + (playerGridY - 1) * buildingH + buildingH/2

    -- Player glow effect (only if using ASCII mode)
    local isSpriteEnabled = F.isSpriteEnabled or function() return false end
    if not isSpriteEnabled() then
        love.graphics.setColor(0.2 * pulse, 0.8 * pulse, 0.3 * pulse, 0.5)
        love.graphics.circle("fill", playerDrawX, playerDrawY, 20)
    end

    -- Player icon (sprite or ASCII)
    local drawPlayerSprite = F.drawPlayerSprite or function(px, py, fallback) fallback() end
    drawPlayerSprite(playerDrawX, playerDrawY, function()
        -- Fallback to ASCII rendering
        love.graphics.setColor(0.2, 0.9 * pulse, 0.3)
        love.graphics.circle("fill", playerDrawX, playerDrawY, 12)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(14))
        love.graphics.printf("@", playerDrawX - 15, playerDrawY - 8, 30, "center")
    end)

    end -- End of classic fallback branch (runs when sprite mode off or atlas missing)

    -- Draw info panel for current building
    if currentBuilding then
        local tooltipW = 200
        local tooltipH = 70
        local tooltipX = mapX + mapW/2 - tooltipW/2
        local tooltipY = mapY + mapH + 5

        love.graphics.setColor(0.1, 0.1, 0.15, 0.95)
        love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipW, tooltipH, 5, 5)
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.rectangle("line", tooltipX, tooltipY, tooltipW, tooltipH, 5, 5)

        love.graphics.setColor(0.9, 0.8, 0.4)
        love.graphics.setFont(getFont(14))
        love.graphics.printf(currentBuilding.name, tooltipX, tooltipY + 6, tooltipW, "center")

        love.graphics.setColor(0.7, 0.7, 0.8)
        love.graphics.setFont(getFont(10))
        love.graphics.printf(currentBuilding.desc, tooltipX, tooltipY + 24, tooltipW, "center")

        -- Enter button
        local enterBtnW = 80
        local enterBtnH = 22
        local enterBtnX = tooltipX + tooltipW/2 - enterBtnW/2
        local enterBtnY = tooltipY + tooltipH - 28
        local enterHover = mx >= enterBtnX and mx <= enterBtnX + enterBtnW and my >= enterBtnY and my <= enterBtnY + enterBtnH

        love.graphics.setColor(enterHover and {0.4, 0.6, 0.4} or {0.3, 0.5, 0.3})
        love.graphics.rectangle("fill", enterBtnX, enterBtnY, enterBtnW, enterBtnH, 4, 4)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(10))
        love.graphics.printf("[E] Enter", enterBtnX, enterBtnY + 5, enterBtnW, "center")
    else
        -- No building selected - show NPC interaction prompt if adjacent
        local TownNPCsVisible = require("townnpcsvisible")
        TownNPCsVisible.drawInteractionPrompt(x, y, w, h, playerGridX, playerGridY)
    end

    -- Navigation arrows (right side)
    local arrowSize = 40
    local arrowX = x + w - 80
    local arrowY = y + 80

    -- Up arrow (North)
    local upHover = mx >= arrowX and mx <= arrowX + arrowSize and my >= arrowY and my <= arrowY + arrowSize
    love.graphics.setColor(upHover and {0.4, 0.5, 0.6} or {0.25, 0.3, 0.35})
    love.graphics.rectangle("fill", arrowX, arrowY, arrowSize, arrowSize, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(16))
    love.graphics.printf("W", arrowX, arrowY + 10, arrowSize, "center")

    -- Down arrow (South)
    local downY = arrowY + arrowSize * 2 + 10
    local downHover = mx >= arrowX and mx <= arrowX + arrowSize and my >= downY and my <= downY + arrowSize
    love.graphics.setColor(downHover and {0.4, 0.5, 0.6} or {0.25, 0.3, 0.35})
    love.graphics.rectangle("fill", arrowX, downY, arrowSize, arrowSize, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("S", arrowX, downY + 10, arrowSize, "center")

    -- Left arrow (West)
    local leftX = arrowX - arrowSize - 5
    local leftY = arrowY + arrowSize + 5
    local leftHover = mx >= leftX and mx <= leftX + arrowSize and my >= leftY and my <= leftY + arrowSize
    love.graphics.setColor(leftHover and {0.4, 0.5, 0.6} or {0.25, 0.3, 0.35})
    love.graphics.rectangle("fill", leftX, leftY, arrowSize, arrowSize, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("A", leftX, leftY + 10, arrowSize, "center")

    -- Right arrow (East)
    local rightX = arrowX + arrowSize + 5
    local rightHover = mx >= rightX and mx <= rightX + arrowSize and my >= leftY and my <= leftY + arrowSize
    love.graphics.setColor(rightHover and {0.4, 0.5, 0.6} or {0.25, 0.3, 0.35})
    love.graphics.rectangle("fill", rightX, leftY, arrowSize, arrowSize, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("D", rightX, leftY + 10, arrowSize, "center")

    -- Control hints below arrows
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.setFont(getFont(9))
    love.graphics.printf("Click or WASD", arrowX - 30, downY + arrowSize + 8, arrowSize + 60, "center")
    love.graphics.printf("to move", arrowX - 30, downY + arrowSize + 20, arrowSize + 60, "center")

    -- Bottom bar with utility buttons (positioned to the right)
    local barY = y + h - 45
    local btnW = 100
    local btnH = 35
    local btnSpacing = 8
    local totalBtnW = btnW * 3 + btnSpacing * 2
    -- Move buttons 300% to the right (right-aligned with 20px padding)
    local btnStartX = x + w - totalBtnW - 20

    -- Inventory button
    local invHover = mx >= btnStartX and mx <= btnStartX + btnW and my >= barY and my <= barY + btnH
    love.graphics.setColor(invHover and {0.35, 0.4, 0.5} or {0.2, 0.25, 0.35})
    love.graphics.rectangle("fill", btnStartX, barY, btnW, btnH, 6, 6)
    love.graphics.setColor(0.9, 0.8, 0.4)
    love.graphics.setFont(getFont(10))
    love.graphics.printf("[I] Inventory", btnStartX, barY + 10, btnW, "center")

    -- Quest Log button
    local questX = btnStartX + btnW + btnSpacing
    local questHover = mx >= questX and mx <= questX + btnW and my >= barY and my <= barY + btnH
    love.graphics.setColor(questHover and {0.35, 0.4, 0.5} or {0.2, 0.25, 0.35})
    love.graphics.rectangle("fill", questX, barY, btnW, btnH, 6, 6)
    love.graphics.setColor(0.9, 0.8, 0.4)
    love.graphics.printf("[Q] Quests", questX, barY + 10, btnW, "center")

    -- Party button
    local partyX = questX + btnW + btnSpacing
    local partyHover = mx >= partyX and mx <= partyX + btnW and my >= barY and my <= barY + btnH
    love.graphics.setColor(partyHover and {0.35, 0.4, 0.5} or {0.2, 0.25, 0.35})
    love.graphics.rectangle("fill", partyX, barY, btnW, btnH, 6, 6)
    love.graphics.setColor(0.9, 0.8, 0.4)
    love.graphics.printf("[T] Party", partyX, barY + 10, btnW, "center")
end

-- ============================================================================
-- GUILD DRAW
-- ============================================================================

M.drawGuild = function(x, y, w, h, mx, my)
    if not state.player then return end
    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(20))
    love.graphics.printf("Adventurer's Guild", x, y + 5, w, "center")

    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(getFont(11))
    love.graphics.printf("Recruit brave companions to join your party", x, y + 30, w, "center")

    -- Show current party size
    local partySize = state.player.party and #state.player.party or 0
    local maxSize = state.player.maxPartySize or 99
    love.graphics.setColor(0.5, 0.8, 0.5)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Party: " .. partySize .. "/" .. maxSize, x, y + 45, w, "center")

    -- Generate available companions if not already done
    if not state.guildCompanions then
        local getAvailableCompanions = F.getAvailableCompanions or function() return {} end
        state.guildCompanions = getAvailableCompanions()
    end

    -- Draw available companions
    local startY = y + 70
    local cardW = 180
    local cardH = 120
    local cols = 3
    local spacing = 15
    local startX = x + (w - cols * (cardW + spacing)) / 2

    state.guildButtons = {}

    for i, companion in ipairs(state.guildCompanions) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local cx = startX + col * (cardW + spacing)
        local cy = startY + row * (cardH + spacing)

        local hover = mx >= cx and mx <= cx + cardW and my >= cy and my <= cy + cardH
        local canAfford = state.player.gold >= companion.hireCost
        local partyFull = partySize >= maxSize

        -- Card background
        if partyFull then
            love.graphics.setColor(0.2, 0.2, 0.2)
        elseif canAfford then
            love.graphics.setColor(hover and {0.25, 0.35, 0.3} or {0.15, 0.2, 0.18})
        else
            love.graphics.setColor(hover and {0.25, 0.2, 0.2} or {0.18, 0.12, 0.12})
        end
        love.graphics.rectangle("fill", cx, cy, cardW, cardH, 6, 6)

        -- Portrait
        local getPortraitImage = F.getPortraitImage or function() return nil end
        local portraitImg = getPortraitImage(companion.portrait)
        if portraitImg then
            love.graphics.setColor(1, 1, 1)
            local imgW, imgH = portraitImg:getDimensions()
            local scale = math.min(40 / imgW, 40 / imgH)
            love.graphics.draw(portraitImg, cx + 10, cy + 10, 0, scale, scale)
        else
            love.graphics.setColor(companion.color)
            love.graphics.setFont(getFont(24))
            love.graphics.print(companion.class.id:sub(1, 1):upper(), cx + 15, cy + 15)
        end

        -- Name and class
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(12))
        love.graphics.print(companion.name, cx + 55, cy + 10)
        love.graphics.setColor(companion.color)
        love.graphics.setFont(getFont(10))
        love.graphics.print(companion.class.name .. " Lv." .. companion.level, cx + 55, cy + 25)

        -- Stats
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.setFont(getFont(9))
        love.graphics.print("HP: " .. companion.maxHP .. "  ATK: " .. companion.attack .. "  DEF: " .. companion.defense, cx + 10, cy + 55)
        love.graphics.print(companion.class.desc, cx + 10, cy + 70)

        -- Hire cost and daily wage
        love.graphics.setColor(canAfford and {1, 0.9, 0.3} or {0.9, 0.4, 0.4})
        love.graphics.setFont(getFont(11))
        love.graphics.print("Hire: " .. companion.hireCost .. "g", cx + 10, cy + 90)
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.setFont(getFont(9))
        love.graphics.print("Wage: " .. companion.dailyWage .. "g/day", cx + 90, cy + 92)

        -- Hire button or status
        if partyFull then
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.setFont(getFont(10))
            love.graphics.printf("Party Full", cx, cy + cardH - 18, cardW, "center")
        elseif canAfford then
            love.graphics.setColor(0.3, 0.8, 0.4)
            love.graphics.setFont(getFont(10))
            love.graphics.printf("[CLICK TO HIRE]", cx, cy + cardH - 18, cardW, "center")
        else
            love.graphics.setColor(0.8, 0.4, 0.4)
            love.graphics.setFont(getFont(10))
            love.graphics.printf("Not enough gold", cx, cy + cardH - 18, cardW, "center")
        end

        state.guildButtons[i] = {x = cx, y = cy, w = cardW, h = cardH, canHire = canAfford and not partyFull}
    end

    -- Back button
    local backY = y + h - 35
    local backW = 120
    local backX = x + (w - backW) / 2
    local backHover = mx >= backX and mx <= backX + backW and my >= backY and my <= backY + 30
    love.graphics.setColor(backHover and {0.4, 0.3, 0.3} or {0.25, 0.2, 0.2})
    love.graphics.rectangle("fill", backX, backY, backW, 30, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Back to Town", backX, backY + 8, backW, "center")
    state.guildBackButton = {x = backX, y = backY, w = backW, h = 30}
end

-- ============================================================================
-- STABLE DRAW
-- ============================================================================

M.drawStable = function(x, y, w, h, mx, my)
    if not state.player then return end
    local Backpack = require("backpack")
    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(20))
    love.graphics.printf("Stable", x, y + 5, w, "center")

    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(getFont(11))
    love.graphics.printf("Buy beasts of burden and carts for carrying loot", x, y + 30, w, "center")

    -- Player gold
    love.graphics.setColor(1, 0.9, 0.3)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Gold: " .. (state.player.gold or 0), x, y + 48, w, "center")

    -- Tabs: Beasts, Carts, Current, Travel
    state.stableTab = state.stableTab or "beasts"
    local tabs = {"beasts", "carts", "current", "travel"}
    local tabNames = {beasts = "Beasts", carts = "Carts", current = "Your Animals", travel = "Paid Travel"}
    local tabW = 100
    local tabStartX = x + (w - #tabs * (tabW + 5)) / 2
    local tabY = y + 70

    state.stableButtons = state.stableButtons or {}

    for i, tab in ipairs(tabs) do
        local tx = tabStartX + (i - 1) * (tabW + 5)
        local isActive = state.stableTab == tab
        local hover = mx >= tx and mx <= tx + tabW and my >= tabY and my <= tabY + 28

        love.graphics.setColor(isActive and {0.3, 0.4, 0.5} or (hover and {0.25, 0.3, 0.35} or {0.15, 0.2, 0.25}))
        love.graphics.rectangle("fill", tx, tabY, tabW, 28, 5, 5)
        love.graphics.setColor(isActive and {1, 1, 1} or {0.7, 0.7, 0.7})
        love.graphics.setFont(getFont(11))
        love.graphics.printf(tabNames[tab], tx, tabY + 7, tabW, "center")

        state.stableButtons["tab_" .. tab] = {x = tx, y = tabY, w = tabW, h = 28}
    end

    local contentY = tabY + 40
    local contentH = h - 160

    if state.stableTab == "beasts" then
        -- Show beasts for sale
        love.graphics.setColor(0.5, 0.6, 0.5)
        love.graphics.setFont(getFont(10))
        love.graphics.print("Click to purchase a beast of burden:", x + 20, contentY)

        local itemY = contentY + 20
        for i, beast in ipairs(Backpack.BEASTS_OF_BURDEN) do
            local iy = itemY + (i - 1) * 50
            local hover = mx >= x + 20 and mx <= x + w - 20 and my >= iy and my <= iy + 45
            local canAfford = state.player.gold >= beast.price

            love.graphics.setColor(hover and {0.2, 0.25, 0.3} or {0.12, 0.15, 0.18})
            love.graphics.rectangle("fill", x + 20, iy, w - 40, 45, 5, 5)

            -- Beast name and icon
            love.graphics.setColor(canAfford and {1, 1, 1} or {0.5, 0.5, 0.5})
            love.graphics.setFont(getFont(13))
            love.graphics.print(beast.name, x + 30, iy + 5)

            -- Stats
            love.graphics.setColor(0.6, 0.7, 0.6)
            love.graphics.setFont(getFont(9))
            love.graphics.print("Carry: +" .. beast.carryCapacity .. " lbs  Speed: " .. (beast.speed * 100) .. "%", x + 30, iy + 22)
            love.graphics.setColor(0.5, 0.5, 0.6)
            love.graphics.print(beast.desc, x + 200, iy + 22)

            -- Price
            love.graphics.setColor(canAfford and {1, 0.9, 0.3} or {0.6, 0.4, 0.4})
            love.graphics.setFont(getFont(11))
            love.graphics.printf(beast.price .. "g", x + 20, iy + 12, w - 60, "right")

            state.stableButtons["beast_" .. i] = {x = x + 20, y = iy, w = w - 40, h = 45, beastId = beast.id, price = beast.price}
        end

    elseif state.stableTab == "carts" then
        -- Show carts for sale
        local beast = Backpack.getEquippedBeast()
        love.graphics.setColor(0.5, 0.6, 0.5)
        love.graphics.setFont(getFont(10))
        if beast then
            love.graphics.print("Click to purchase a cart (your " .. beast.name .. " can pull it):", x + 20, contentY)
        else
            love.graphics.setColor(0.8, 0.6, 0.4)
            love.graphics.print("You need a beast of burden to pull most carts!", x + 20, contentY)
        end

        local itemY = contentY + 20
        for i, cart in ipairs(Backpack.CARTS) do
            local iy = itemY + (i - 1) * 50
            local hover = mx >= x + 20 and mx <= x + w - 20 and my >= iy and my <= iy + 45
            local canAfford = state.player.gold >= cart.price

            -- Check if beast can pull (if required)
            local beastDef = beast and Backpack.getBeastDef(beast.id)
            local canUse = not cart.requiresBeast or (beastDef and beastDef.canPullCart)

            love.graphics.setColor(hover and {0.2, 0.25, 0.3} or {0.12, 0.15, 0.18})
            love.graphics.rectangle("fill", x + 20, iy, w - 40, 45, 5, 5)

            -- Cart name
            love.graphics.setColor((canAfford and canUse) and {1, 1, 1} or {0.5, 0.5, 0.5})
            love.graphics.setFont(getFont(13))
            love.graphics.print(cart.name, x + 30, iy + 5)

            -- Stats
            love.graphics.setColor(0.6, 0.7, 0.6)
            love.graphics.setFont(getFont(9))
            local requiresText = cart.requiresBeast and "(Requires beast)" or "(Can push yourself)"
            love.graphics.print("Capacity: +" .. cart.carryCapacity .. " lbs  " .. requiresText, x + 30, iy + 22)
            love.graphics.setColor(0.5, 0.5, 0.6)
            love.graphics.print(cart.desc, x + 280, iy + 22)

            -- Price or status
            if not canUse then
                love.graphics.setColor(0.7, 0.4, 0.4)
                love.graphics.setFont(getFont(10))
                love.graphics.printf("Need beast", x + 20, iy + 12, w - 60, "right")
            else
                love.graphics.setColor(canAfford and {1, 0.9, 0.3} or {0.6, 0.4, 0.4})
                love.graphics.setFont(getFont(11))
                love.graphics.printf(cart.price .. "g", x + 20, iy + 12, w - 60, "right")
            end

            state.stableButtons["cart_" .. i] = {x = x + 20, y = iy, w = w - 40, h = 45, cartId = cart.id, price = cart.price, canUse = canUse}
        end

    elseif state.stableTab == "current" then
        -- Show current beast and cart
        local beast = Backpack.getEquippedBeast()
        local cart = Backpack.getEquippedCart()
        local needs = PlayerData.backpack and PlayerData.backpack.beastNeeds or {hunger = 100, stamina = 100}

        if not beast and not cart then
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.setFont(getFont(14))
            love.graphics.printf("No beasts or carts owned", x, contentY + 50, w, "center")
            love.graphics.setFont(getFont(11))
            love.graphics.printf("Purchase from the Beasts or Carts tabs", x, contentY + 75, w, "center")
        else
            -- Beast info
            if beast then
                local beastDef = Backpack.getBeastDef(beast.id)
                local panelY = contentY + 10

                love.graphics.setColor(0.12, 0.15, 0.2)
                love.graphics.rectangle("fill", x + 30, panelY, w - 60, 100, 8, 8)

                love.graphics.setColor(0.8, 0.7, 0.5)
                love.graphics.setFont(getFont(16))
                love.graphics.print("Your " .. beast.name, x + 45, panelY + 10)

                -- Hunger bar
                love.graphics.setColor(0.7, 0.7, 0.8)
                love.graphics.setFont(getFont(10))
                love.graphics.print("Hunger:", x + 45, panelY + 35)
                love.graphics.setColor(0.2, 0.2, 0.25)
                love.graphics.rectangle("fill", x + 110, panelY + 35, 150, 14, 3, 3)
                local hungerColor = needs.hunger > 50 and {0.4, 0.7, 0.3} or (needs.hunger > 20 and {0.8, 0.6, 0.2} or {0.8, 0.3, 0.2})
                love.graphics.setColor(hungerColor)
                love.graphics.rectangle("fill", x + 110, panelY + 35, 150 * (needs.hunger / 100), 14, 3, 3)
                love.graphics.setColor(1, 1, 1)
                love.graphics.setFont(getFont(9))
                love.graphics.printf(math.floor(needs.hunger) .. "%", x + 110, panelY + 36, 150, "center")

                -- Stamina bar
                love.graphics.setColor(0.7, 0.7, 0.8)
                love.graphics.setFont(getFont(10))
                love.graphics.print("Stamina:", x + 45, panelY + 55)
                love.graphics.setColor(0.2, 0.2, 0.25)
                love.graphics.rectangle("fill", x + 110, panelY + 55, 150, 14, 3, 3)
                local staminaColor = needs.stamina > 50 and {0.3, 0.5, 0.7} or (needs.stamina > 20 and {0.6, 0.5, 0.3} or {0.7, 0.3, 0.3})
                love.graphics.setColor(staminaColor)
                love.graphics.rectangle("fill", x + 110, panelY + 55, 150 * (needs.stamina / 100), 14, 3, 3)
                love.graphics.setColor(1, 1, 1)
                love.graphics.setFont(getFont(9))
                love.graphics.printf(math.floor(needs.stamina) .. "%", x + 110, panelY + 56, 150, "center")

                -- Action buttons
                local feedHover = mx >= x + 300 and mx <= x + 400 and my >= panelY + 35 and my <= panelY + 60
                love.graphics.setColor(feedHover and {0.4, 0.6, 0.3} or {0.3, 0.5, 0.25})
                love.graphics.rectangle("fill", x + 300, panelY + 35, 100, 25, 5, 5)
                love.graphics.setColor(1, 1, 1)
                love.graphics.setFont(getFont(10))
                love.graphics.printf("Feed", x + 300, panelY + 40, 100, "center")
                state.stableButtons.feed = {x = x + 300, y = panelY + 35, w = 100, h = 25}

                local restHover = mx >= x + 300 and mx <= x + 400 and my >= panelY + 65 and my <= panelY + 90
                love.graphics.setColor(restHover and {0.3, 0.4, 0.6} or {0.25, 0.35, 0.5})
                love.graphics.rectangle("fill", x + 300, panelY + 65, 100, 25, 5, 5)
                love.graphics.setColor(1, 1, 1)
                love.graphics.printf("Rest (1hr)", x + 300, panelY + 70, 100, "center")
                state.stableButtons.rest = {x = x + 300, y = panelY + 65, w = 100, h = 25}

                -- Dismiss button
                local dismissHover = mx >= x + 420 and mx <= x + 500 and my >= panelY + 50 and my <= panelY + 75
                love.graphics.setColor(dismissHover and {0.7, 0.3, 0.3} or {0.5, 0.25, 0.25})
                love.graphics.rectangle("fill", x + 420, panelY + 50, 80, 25, 5, 5)
                love.graphics.setColor(1, 1, 1)
                love.graphics.setFont(getFont(10))
                love.graphics.printf("Release", x + 420, panelY + 55, 80, "center")
                state.stableButtons.dismissBeast = {x = x + 420, y = panelY + 50, w = 80, h = 25}
            end

            -- Cart info
            if cart then
                local cartDef = Backpack.getCartDef(cart.id)
                local cartPanelY = beast and contentY + 120 or contentY + 10

                love.graphics.setColor(0.12, 0.15, 0.2)
                love.graphics.rectangle("fill", x + 30, cartPanelY, w - 60, 60, 8, 8)

                love.graphics.setColor(0.7, 0.6, 0.5)
                love.graphics.setFont(getFont(14))
                love.graphics.print("Your " .. cart.name, x + 45, cartPanelY + 10)

                love.graphics.setColor(0.6, 0.7, 0.6)
                love.graphics.setFont(getFont(10))
                love.graphics.print("Adds +" .. (cartDef and cartDef.carryCapacity or 0) .. " lbs capacity", x + 45, cartPanelY + 32)

                -- Detach cart button
                local detachHover = mx >= x + 420 and mx <= x + 500 and my >= cartPanelY + 20 and my <= cartPanelY + 45
                love.graphics.setColor(detachHover and {0.7, 0.5, 0.3} or {0.5, 0.4, 0.3})
                love.graphics.rectangle("fill", x + 420, cartPanelY + 20, 80, 25, 5, 5)
                love.graphics.setColor(1, 1, 1)
                love.graphics.setFont(getFont(10))
                love.graphics.printf("Detach", x + 420, cartPanelY + 25, 80, "center")
                state.stableButtons.detachCart = {x = x + 420, y = cartPanelY + 20, w = 80, h = 25}
            end

            -- Weight summary
            local playerMight = state.player.stats and state.player.stats.MIGHT or 10
            local encumbrance = Backpack.getEncumbranceStatus(playerMight)
            local summaryY = h - 80

            love.graphics.setColor(0.7, 0.7, 0.8)
            love.graphics.setFont(getFont(12))
            love.graphics.printf(string.format("Total Capacity: %.0f / %.0f lbs (%s)",
                encumbrance.currentWeight, encumbrance.maxCapacity, encumbrance.level),
                x, y + summaryY, w, "center")
        end

    elseif state.stableTab == "travel" then
        -- Paid Travel to Anchor Cities (Land-based carriage only)
        love.graphics.setColor(0.5, 0.6, 0.7)
        love.graphics.setFont(getFont(11))
        love.graphics.printf("Hire a carriage to travel safely to major cities (90% less encounters)", x, contentY, w, "center")

        -- Get anchor towns from worldgen
        local WorldGen = require("worldgen")
        local anchorTowns = WorldGen.getAnchorTowns()
        local currentTown = state.world.currentTown

        -- Check if player is on main continent or gnomish isles
        local playerOnMainland = state.world.playerX < 64
        local playerOnGnomishIsles = state.world.playerX >= 80

        -- Filter out current town, calculate costs, and exclude cross-ocean destinations
        local travelOptions = {}
        for _, town in ipairs(anchorTowns) do
            if not currentTown or town.id ~= currentTown.id then
                local destX = town.position.x
                local destOnMainland = destX < 64
                local destOnGnomishIsles = destX >= 80

                local canReachByLand = (playerOnMainland and destOnMainland) or
                                       (playerOnGnomishIsles and destOnGnomishIsles)

                if canReachByLand then
                    local dx = town.position.x - state.world.playerX
                    local dy = town.position.y - state.world.playerY
                    local distance = math.sqrt(dx * dx + dy * dy)
                    local tiles = math.ceil(distance)
                    local cost = math.max(50, tiles * 5)
                    local travelTime = math.ceil(tiles * 0.5)

                    table.insert(travelOptions, {
                        town = town,
                        distance = tiles,
                        cost = cost,
                        travelTime = travelTime,
                    })
                end
            end
        end

        -- Sort by distance
        table.sort(travelOptions, function(a, b) return a.distance < b.distance end)

        if #travelOptions == 0 then
            love.graphics.setColor(0.6, 0.6, 0.5)
            love.graphics.setFont(getFont(14))
            love.graphics.printf("No carriage destinations available", x, contentY + 50, w, "center")
            love.graphics.setColor(0.5, 0.5, 0.6)
            love.graphics.setFont(getFont(11))
            if playerOnGnomishIsles then
                love.graphics.printf("You're on the Gnomish Isles - carriages can't cross the Silver Seas.", x, contentY + 75, w, "center")
                love.graphics.printf("You'll need a boat to reach the mainland.", x, contentY + 92, w, "center")
            elseif playerOnMainland then
                love.graphics.printf("All reachable cities are nearby. Explore the map!", x, contentY + 75, w, "center")
            else
                love.graphics.printf("You're in the middle of the ocean!", x, contentY + 75, w, "center")
            end
        else
            local itemY = contentY + 25
            local itemH = 55
            local maxVisible = math.floor((h - 180) / itemH)

            for i, option in ipairs(travelOptions) do
                if i > maxVisible then break end

                local iy = itemY + (i - 1) * itemH
                local hover = mx >= x + 20 and mx <= x + w - 20 and my >= iy and my <= iy + itemH - 5
                local canAfford = state.player.gold >= option.cost

                love.graphics.setColor(hover and {0.2, 0.25, 0.35} or {0.12, 0.15, 0.2})
                love.graphics.rectangle("fill", x + 20, iy, w - 40, itemH - 5, 5, 5)

                love.graphics.setColor(canAfford and {1, 1, 1} or {0.5, 0.5, 0.5})
                love.graphics.setFont(getFont(14))
                love.graphics.print(option.town.name, x + 35, iy + 5)

                local typeColors = {
                    capital = {0.9, 0.7, 0.2},
                    port = {0.3, 0.6, 0.9},
                    fortress = {0.7, 0.3, 0.3},
                    village = {0.5, 0.7, 0.4},
                    gambling_city = {0.8, 0.5, 0.8},
                    administrative_city = {0.6, 0.6, 0.8},
                    prison_fortress = {0.5, 0.4, 0.4},
                }
                local typeColor = typeColors[option.town.type] or {0.6, 0.6, 0.6}
                love.graphics.setColor(typeColor)
                love.graphics.setFont(getFont(9))
                local townTypeDisplay = option.town.type or "town"
                if townTypeDisplay == "gambling_city" then
                    townTypeDisplay = "THE GAMBLING CITY"
                elseif townTypeDisplay == "administrative_city" then
                    townTypeDisplay = "ADMINISTRATIVE CITY"
                elseif townTypeDisplay == "prison_fortress" then
                    townTypeDisplay = "PRISON FORTRESS"
                else
                    townTypeDisplay = string.upper(townTypeDisplay:gsub("_", " "))
                end
                love.graphics.print(townTypeDisplay, x + 35, iy + 22)

                love.graphics.setColor(0.6, 0.7, 0.6)
                love.graphics.setFont(getFont(10))
                love.graphics.print(option.distance .. " tiles (~" .. option.travelTime .. " hrs)", x + 150, iy + 22)

                love.graphics.setColor(0.5, 0.5, 0.6)
                love.graphics.setFont(getFont(9))
                local regionName = option.town.region and option.town.region:gsub("_", " "):gsub("(%a)([%w_']*)", function(a, b) return string.upper(a) .. b end) or "Unknown"
                love.graphics.print(regionName, x + 35, iy + 35)

                love.graphics.setColor(canAfford and {1, 0.9, 0.3} or {0.7, 0.4, 0.4})
                love.graphics.setFont(getFont(13))
                love.graphics.printf(option.cost .. "g", x + 20, iy + 15, w - 60, "right")

                state.stableButtons["travel_" .. i] = {
                    x = x + 20, y = iy, w = w - 40, h = itemH - 5,
                    town = option.town, cost = option.cost, distance = option.distance
                }
            end

            love.graphics.setColor(0.4, 0.6, 0.4)
            love.graphics.setFont(getFont(10))
            love.graphics.printf("Carriage travel is much safer - guards protect the route! (Land routes only)", x, y + h - 95, w, "center")
        end
    end

    -- Back button
    local backY = y + h - 35
    local backW = 120
    local backX = x + (w - backW) / 2
    local backHover = mx >= backX and mx <= backX + backW and my >= backY and my <= backY + 30
    love.graphics.setColor(backHover and {0.4, 0.3, 0.3} or {0.25, 0.2, 0.2})
    love.graphics.rectangle("fill", backX, backY, backW, 30, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Back to Town", backX, backY + 8, backW, "center")
    state.stableButtons.back = {x = backX, y = backY, w = backW, h = 30}
end

-- ============================================================================
-- LOCKPICKING / CRIME / JAIL DRAWS
-- ============================================================================

M.drawLockpickPrompt = function(x, y, w, h, mx, my)
    local building = state.lockpickTarget or {name = "Unknown", id = "home1"}
    local LOCKPICK_CONFIG = F.LOCKPICK_CONFIG
    local JAIL_CONFIG = F.JAIL_CONFIG
    local difficulty = LOCKPICK_CONFIG.difficulties[building.id] or LOCKPICK_CONFIG.defaultDifficulty

    love.graphics.setColor(0.9, 0.6, 0.2)
    love.graphics.setFont(getFont(20))
    love.graphics.printf("Locked: " .. building.name, x, y + 20, w, "center")

    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("You find a " .. difficulty.name .. " on this door.", x, y + 55, w, "center")

    local hour = state.timeOfDay or 12
    local isNight = hour >= 22 or hour < 6
    local timeIcon = isNight and "\xF0\x9F\x8C\x99" or "\xE2\x98\x80\xEF\xB8\x8F"
    local timeStr = string.format("%02d:00", math.floor(hour))

    love.graphics.setColor(isNight and {0.5, 0.6, 0.9} or {0.9, 0.8, 0.4})
    love.graphics.setFont(getFont(14))
    love.graphics.printf(timeIcon .. " " .. timeStr, x, y + 85, w, "center")

    local detectionChance = LOCKPICK_CONFIG.baseDetectionChance
    if isNight then
        detectionChance = detectionChance + LOCKPICK_CONFIG.nightBonus
    end
    detectionChance = math.max(0.05, math.min(0.95, detectionChance))

    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(getFont(11))
    love.graphics.printf("Detection Risk: " .. math.floor(detectionChance * 100) .. "%", x, y + 110, w, "center")
    if isNight then
        love.graphics.setColor(0.5, 0.7, 0.5)
        love.graphics.printf("(Night provides cover)", x, y + 128, w, "center")
    else
        love.graphics.setColor(0.8, 0.6, 0.4)
        love.graphics.printf("(Daytime - higher risk!)", x, y + 128, w, "center")
    end

    love.graphics.setColor(0.8, 0.5, 0.4)
    love.graphics.setFont(getFont(10))
    love.graphics.printf("If caught, fine: " .. math.floor(difficulty.fine * JAIL_CONFIG.fineMultiplier) .. "g or jail time", x, y + 155, w, "center")

    state.lockpickButtons = {}
    local btnW = 180
    local btnH = 40
    local btnY = y + 200
    local btnSpacing = 20

    local pickX = x + w/2 - btnW - btnSpacing/2
    local pickHover = mx >= pickX and mx <= pickX + btnW and my >= btnY and my <= btnY + btnH
    love.graphics.setColor(pickHover and {0.5, 0.4, 0.3} or {0.35, 0.3, 0.25})
    love.graphics.rectangle("fill", pickX, btnY, btnW, btnH, 6, 6)
    love.graphics.setColor(0.9, 0.8, 0.6)
    love.graphics.setFont(getFont(13))
    love.graphics.printf("\xF0\x9F\x94\x93 Pick Lock", pickX, btnY + 12, btnW, "center")
    state.lockpickButtons.attempt = {x = pickX, y = btnY, w = btnW, h = btnH}

    local leaveX = x + w/2 + btnSpacing/2
    local leaveHover = mx >= leaveX and mx <= leaveX + btnW and my >= btnY and my <= btnY + btnH
    love.graphics.setColor(leaveHover and {0.4, 0.4, 0.5} or {0.25, 0.25, 0.35})
    love.graphics.rectangle("fill", leaveX, btnY, btnW, btnH, 6, 6)
    love.graphics.setColor(0.8, 0.8, 0.9)
    love.graphics.printf("Leave", leaveX, btnY + 12, btnW, "center")
    state.lockpickButtons.leave = {x = leaveX, y = btnY, w = btnW, h = btnH}

    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.setFont(getFont(9))
    love.graphics.printf("Breaking in is a crime. Guards may catch you!", x, y + h - 50, w, "center")
end

M.drawLockpicking = function(x, y, w, h, mx, my)
    local building = state.lockpickTarget or {name = "Unknown", id = "home1"}
    local LOCKPICK_CONFIG = F.LOCKPICK_CONFIG
    local difficulty = LOCKPICK_CONFIG.difficulties[building.id] or LOCKPICK_CONFIG.defaultDifficulty

    if not state.lockpickState then
        state.lockpickState = {
            cursorPos = 0,
            sweetSpotStart = math.random() * (1 - difficulty.sweetSpot),
            sweetSpotSize = difficulty.sweetSpot,
            attempts = difficulty.attempts,
            maxAttempts = difficulty.attempts,
            speed = LOCKPICK_CONFIG.cursorSpeed,
            direction = 1,
            success = false,
            failed = false,
        }
    end

    local ls = state.lockpickState

    love.graphics.setColor(0.9, 0.6, 0.2)
    love.graphics.setFont(getFont(18))
    love.graphics.printf("Picking " .. difficulty.name, x, y + 15, w, "center")

    love.graphics.setColor(ls.attempts > 1 and {0.5, 0.8, 0.5} or {0.8, 0.5, 0.4})
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Attempts: " .. ls.attempts .. "/" .. ls.maxAttempts, x, y + 40, w, "center")

    local barX = x + 50
    local barY = y + 100
    local barW = w - 100
    local barH = 50

    love.graphics.setColor(0.15, 0.15, 0.2)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 8, 8)

    local sweetX = barX + ls.sweetSpotStart * barW
    local sweetW = ls.sweetSpotSize * barW
    love.graphics.setColor(0.25, 0.35, 0.25, 0.5)
    love.graphics.rectangle("fill", sweetX, barY, sweetW, barH, 4, 4)

    local cursorX = barX + ls.cursorPos * barW
    local cursorW = 8
    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.rectangle("fill", cursorX - cursorW/2, barY - 5, cursorW, barH + 10, 3, 3)

    love.graphics.setColor(1, 0.9, 0.4, 0.3)
    love.graphics.rectangle("fill", cursorX - cursorW, barY - 8, cursorW * 2, barH + 16, 5, 5)

    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", barX, barY, barW, barH, 8, 8)
    love.graphics.setLineWidth(1)

    local lockCenterX = x + w/2
    local lockY = barY + barH + 40
    love.graphics.setColor(0.3, 0.3, 0.35)
    love.graphics.circle("fill", lockCenterX, lockY, 40)
    love.graphics.setColor(0.2, 0.2, 0.25)
    love.graphics.circle("fill", lockCenterX, lockY, 30)
    love.graphics.setColor(0.15, 0.15, 0.18)
    love.graphics.rectangle("fill", lockCenterX - 5, lockY - 35, 10, 25, 2, 2)

    love.graphics.setColor(0.8, 0.8, 0.9)
    love.graphics.setFont(getFont(14))
    love.graphics.printf("Press SPACE or CLICK when the cursor is in the sweet spot!", x, y + h - 80, w, "center")

    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.setFont(getFont(10))
    love.graphics.printf("The lock will click when you're close...", x, y + h - 55, w, "center")

    local cancelW = 100
    local cancelH = 30
    local cancelX = x + w/2 - cancelW/2
    local cancelY = y + h - 40
    local cancelHover = mx >= cancelX and mx <= cancelX + cancelW and my >= cancelY and my <= cancelY + cancelH
    love.graphics.setColor(cancelHover and {0.5, 0.3, 0.3} or {0.35, 0.25, 0.25})
    love.graphics.rectangle("fill", cancelX, cancelY, cancelW, cancelH, 5, 5)
    love.graphics.setColor(0.9, 0.8, 0.8)
    love.graphics.setFont(getFont(10))
    love.graphics.printf("Give Up", cancelX, cancelY + 8, cancelW, "center")

    state.lockpickButtons = state.lockpickButtons or {}
    state.lockpickButtons.cancel = {x = cancelX, y = cancelY, w = cancelW, h = cancelH}
end

M.drawJail = function(x, y, w, h, mx, my)
    if not state.player then return end
    local LOCKPICK_CONFIG = F.LOCKPICK_CONFIG
    local JAIL_CONFIG = F.JAIL_CONFIG

    love.graphics.setColor(0.6, 0.4, 0.4)
    love.graphics.setFont(getFont(22))
    love.graphics.printf("\xE2\x9B\x93\xEF\xB8\x8F TOWN JAIL \xE2\x9B\x93\xEF\xB8\x8F", x, y + 20, w, "center")

    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("You were caught attempting to break into private property!", x, y + 60, w, "center")

    if not state.jailState then
        local building = state.lockpickTarget or {id = "home1"}
        local difficulty = LOCKPICK_CONFIG.difficulties[building.id] or LOCKPICK_CONFIG.defaultDifficulty
        local fine = math.floor(difficulty.fine * JAIL_CONFIG.fineMultiplier)

        state.jailState = {
            fine = fine,
            sentence = JAIL_CONFIG.baseSentence,
            hoursServed = 0,
            canAffordFine = state.player.gold >= fine,
        }
    end

    local js = state.jailState

    local panelW = 350
    local panelH = 200
    local panelX = x + (w - panelW) / 2
    local panelY = y + 100

    love.graphics.setColor(0.12, 0.12, 0.15)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 8, 8)
    love.graphics.setColor(0.3, 0.3, 0.35)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 8, 8)

    state.jailButtons = {}
    local btnW = panelW - 40
    local btnH = 45
    local btnX = panelX + 20

    local fineY = panelY + 20
    local fineHover = js.canAffordFine and mx >= btnX and mx <= btnX + btnW and my >= fineY and my <= fineY + btnH
    love.graphics.setColor(js.canAffordFine and (fineHover and {0.4, 0.5, 0.3} or {0.3, 0.4, 0.25}) or {0.2, 0.2, 0.2})
    love.graphics.rectangle("fill", btnX, fineY, btnW, btnH, 6, 6)
    love.graphics.setColor(js.canAffordFine and {1, 0.9, 0.4} or {0.5, 0.5, 0.5})
    love.graphics.setFont(getFont(13))
    love.graphics.printf("\xF0\x9F\x92\xB0 Pay Fine: " .. js.fine .. "g", btnX, fineY + 8, btnW, "center")
    love.graphics.setColor(js.canAffordFine and {0.7, 0.7, 0.8} or {0.4, 0.4, 0.4})
    love.graphics.setFont(getFont(9))
    love.graphics.printf(js.canAffordFine and "(Walk free immediately)" or "(Not enough gold: " .. (state.player.gold or 0) .. "g)", btnX, fineY + 28, btnW, "center")
    if js.canAffordFine then
        state.jailButtons.payFine = {x = btnX, y = fineY, w = btnW, h = btnH}
    end

    local serveY = panelY + 75
    local serveHover = mx >= btnX and mx <= btnX + btnW and my >= serveY and my <= serveY + btnH
    love.graphics.setColor(serveHover and {0.4, 0.4, 0.5} or {0.25, 0.25, 0.35})
    love.graphics.rectangle("fill", btnX, serveY, btnW, btnH, 6, 6)
    love.graphics.setColor(0.8, 0.8, 0.9)
    love.graphics.setFont(getFont(13))
    love.graphics.printf("\xE2\x8F\xB0 Serve Time: " .. js.sentence .. " hours", btnX, serveY + 8, btnW, "center")
    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(getFont(9))
    love.graphics.printf("(Time passes, you'll be released after)", btnX, serveY + 28, btnW, "center")
    state.jailButtons.serveTime = {x = btnX, y = serveY, w = btnW, h = btnH}

    local escapeY = panelY + 130
    local escapeHover = mx >= btnX and mx <= btnX + btnW and my >= escapeY and my <= escapeY + btnH
    love.graphics.setColor(escapeHover and {0.5, 0.35, 0.35} or {0.35, 0.25, 0.25})
    love.graphics.rectangle("fill", btnX, escapeY, btnW, btnH, 6, 6)
    love.graphics.setColor(0.9, 0.6, 0.5)
    love.graphics.setFont(getFont(13))
    love.graphics.printf("\xF0\x9F\x8F\x83 Attempt Escape", btnX, escapeY + 8, btnW, "center")
    love.graphics.setColor(0.7, 0.5, 0.5)
    love.graphics.setFont(getFont(9))
    love.graphics.printf("(" .. math.floor(JAIL_CONFIG.escapeChance * 100) .. "% chance - failure adds " .. JAIL_CONFIG.escapeConsequence .. "hrs)", btnX, escapeY + 28, btnW, "center")
    state.jailButtons.escape = {x = btnX, y = escapeY, w = btnW, h = btnH}

    love.graphics.setColor(0.5, 0.4, 0.4)
    love.graphics.setFont(getFont(9))
    love.graphics.printf("Your reputation in this town has been damaged.", x, y + h - 40, w, "center")
end

M.drawBurglarySuccess = function(x, y, w, h, mx, my)
    if not state.lockpickTarget then
        state.phase = "town"
        state.burglaryLoot = nil
        state.lockpickState = nil
        return
    end

    love.graphics.setColor(0.4, 0.8, 0.4)
    love.graphics.setFont(getFont(20))
    love.graphics.printf("\xF0\x9F\x8E\x89 Break-in Successful!", x, y + 20, w, "center")

    local building = state.lockpickTarget
    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("You slipped into " .. building.name .. " unnoticed.", x, y + 55, w, "center")

    if state.burglaryLoot then
        local loot = state.burglaryLoot
        local panelW = 300
        local panelH = 150
        local panelX = x + (w - panelW) / 2
        local panelY = y + 90

        love.graphics.setColor(0.12, 0.15, 0.12)
        love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 8, 8)
        love.graphics.setColor(0.4, 0.5, 0.4)
        love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 8, 8)

        love.graphics.setColor(0.9, 0.8, 0.4)
        love.graphics.setFont(getFont(14))
        love.graphics.printf("\xF0\x9F\x92\xB0 Loot Found:", panelX, panelY + 15, panelW, "center")

        love.graphics.setColor(1, 0.9, 0.3)
        love.graphics.setFont(getFont(16))
        love.graphics.printf(loot.gold .. " gold", panelX, panelY + 45, panelW, "center")

        if loot.items and #loot.items > 0 then
            love.graphics.setColor(0.7, 0.8, 0.7)
            love.graphics.setFont(getFont(11))
            local itemStr = table.concat(loot.items, ", ")
            love.graphics.printf("Items: " .. itemStr, panelX + 10, panelY + 80, panelW - 20, "center")
        end
    end

    state.burglaryButtons = {}
    local btnW = 150
    local btnH = 40
    local btnX = x + (w - btnW) / 2
    local btnY = y + h - 80
    local btnHover = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH

    love.graphics.setColor(btnHover and {0.4, 0.5, 0.4} or {0.3, 0.4, 0.3})
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(13))
    love.graphics.printf("Continue", btnX, btnY + 12, btnW, "center")
    state.burglaryButtons.continue = {x = btnX, y = btnY, w = btnW, h = btnH}

    love.graphics.setColor(0.6, 0.5, 0.4)
    love.graphics.setFont(getFont(9))
    love.graphics.printf("The building will remain accessible until you leave town.", x, y + h - 35, w, "center")
end

-- ============================================================================
-- PROPERTY DRAWS
-- ============================================================================

M.drawPropertyPurchase = function(x, y, w, h, mx, my)
    if not state.player then return end
    local PropertySystem = require("propertysystem")
    local building = state.propertyBuilding or {name = "Unknown", id = "unknown"}
    local townId = state.propertyTownId or "havenbrook"

    local propertyType = building.propertyType or "business"
    local propertyDef
    if propertyType == "business" then
        propertyDef = PropertySystem.BUSINESS_PROPERTIES[building.id]
    else
        propertyDef = PropertySystem.HOME_PROPERTIES[building.id]
    end

    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(20))
    love.graphics.printf(building.name .. " For Sale", x, y + 15, w, "center")

    love.graphics.setColor(propertyType == "business" and {0.4, 0.6, 0.8} or {0.6, 0.5, 0.7})
    love.graphics.setFont(getFont(12))
    love.graphics.printf(propertyType == "business" and "Business Property" or "Residential Property", x, y + 45, w, "center")

    state.propertyButtons = {}

    if propertyDef then
        local price = propertyDef.basePrice or 1000
        local dailyTax = propertyDef.dailyTax or 0
        local canAfford = state.player.gold >= price

        love.graphics.setColor(0.7, 0.7, 0.8)
        love.graphics.setFont(getFont(14))
        love.graphics.printf("Purchase Price:", x, y + 85, w, "center")

        love.graphics.setColor(canAfford and {0.5, 0.8, 0.5} or {0.8, 0.5, 0.5})
        love.graphics.setFont(getFont(18))
        love.graphics.printf(price .. "g", x, y + 105, w, "center")

        love.graphics.setColor(0.6, 0.6, 0.7)
        love.graphics.setFont(getFont(11))
        love.graphics.printf("Daily Tax: " .. dailyTax .. "g", x, y + 130, w, "center")

        local benefitY = y + 160
        love.graphics.setColor(0.8, 0.8, 0.9)
        love.graphics.setFont(getFont(12))
        love.graphics.printf("Benefits:", x, benefitY, w, "center")

        benefitY = benefitY + 20
        love.graphics.setColor(0.6, 0.7, 0.6)
        love.graphics.setFont(getFont(11))

        if propertyType == "business" then
            love.graphics.printf("* Hire employees for passive income", x, benefitY, w, "center")
            benefitY = benefitY + 16
            love.graphics.printf("* Keep all profits from operations", x, benefitY, w, "center")
            benefitY = benefitY + 16
            love.graphics.printf("* Upgrade facility for better results", x, benefitY, w, "center")
        else
            local storage = propertyDef.storageSlots or 0
            love.graphics.printf("* Storage: " .. storage .. " slots", x, benefitY, w, "center")
            benefitY = benefitY + 16
            love.graphics.printf("* Rest point (free restoration)", x, benefitY, w, "center")
            benefitY = benefitY + 16
            love.graphics.printf("* Can upgrade to settlement", x, benefitY, w, "center")
        end

        local btnW = 180
        local btnH = 45
        local buyX = x + w/2 - btnW - 10
        local buyY = y + h - 90
        local buyHover = mx >= buyX and mx <= buyX + btnW and my >= buyY and my <= buyY + btnH

        if canAfford then
            love.graphics.setColor(buyHover and {0.4, 0.6, 0.4} or {0.3, 0.5, 0.3})
        else
            love.graphics.setColor(0.3, 0.3, 0.3)
        end
        love.graphics.rectangle("fill", buyX, buyY, btnW, btnH, 6, 6)
        love.graphics.setColor(canAfford and {1, 1, 1} or {0.5, 0.5, 0.5})
        love.graphics.setFont(getFont(14))
        love.graphics.printf("\xF0\x9F\x92\xB0 Purchase", buyX, buyY + 14, btnW, "center")
        state.propertyButtons.buy = {x = buyX, y = buyY, w = btnW, h = btnH, enabled = canAfford}

        local cancelX = x + w/2 + 10
        local cancelHover = mx >= cancelX and mx <= cancelX + btnW and my >= buyY and my <= buyY + btnH
        love.graphics.setColor(cancelHover and {0.5, 0.4, 0.4} or {0.35, 0.3, 0.3})
        love.graphics.rectangle("fill", cancelX, buyY, btnW, btnH, 6, 6)
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.printf("Cancel", cancelX, buyY + 14, btnW, "center")
        state.propertyButtons.cancel = {x = cancelX, y = buyY, w = btnW, h = btnH}

        love.graphics.setColor(0.6, 0.6, 0.5)
        love.graphics.setFont(getFont(10))
        love.graphics.printf("Your Gold: " .. (state.player.gold or 0) .. "g", x, y + h - 35, w, "center")
    else
        love.graphics.setColor(0.7, 0.5, 0.5)
        love.graphics.setFont(getFont(14))
        love.graphics.printf("This property is not currently available for purchase.", x, y + 100, w, "center")

        local btnW = 120
        local btnH = 40
        local backX = x + (w - btnW) / 2
        local backY = y + h - 80
        local backHover = mx >= backX and mx <= backX + btnW and my >= backY and my <= backY + btnH
        love.graphics.setColor(backHover and {0.4, 0.4, 0.5} or {0.3, 0.3, 0.35})
        love.graphics.rectangle("fill", backX, backY, btnW, btnH, 6, 6)
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.setFont(getFont(13))
        love.graphics.printf("Back", backX, backY + 12, btnW, "center")
        state.propertyButtons.cancel = {x = backX, y = backY, w = btnW, h = btnH}
    end
end

M.drawPropertyManage = function(x, y, w, h, mx, my)
    if not state.player then return end
    local PropertySystem = require("propertysystem")
    local building = state.propertyBuilding or {name = "Unknown", id = "unknown"}
    local townId = state.propertyTownId or "havenbrook"
    local propertyType = building.propertyType or "business"

    local propertyKey = townId .. "_" .. building.id
    local propertyData = state.player.properties.townProperties[propertyKey]

    love.graphics.setColor(0.5, 0.8, 0.5)
    love.graphics.setFont(getFont(20))
    love.graphics.printf("Your " .. building.name, x, y + 15, w, "center")

    state.propertyButtons = {}

    if propertyData then
        love.graphics.setColor(0.7, 0.7, 0.8)
        love.graphics.setFont(getFont(12))
        love.graphics.printf("Owned since day " .. (propertyData.purchaseDay or 1), x, y + 45, w, "center")

        if propertyType == "business" then
            local income = propertyData.dailyIncome or 0
            local employees = propertyData.employees or {}

            love.graphics.setColor(0.5, 0.7, 0.5)
            love.graphics.setFont(getFont(14))
            love.graphics.printf("Daily Income: " .. income .. "g", x, y + 75, w, "center")

            love.graphics.setColor(0.6, 0.6, 0.7)
            love.graphics.setFont(getFont(11))
            love.graphics.printf("Employees: " .. #employees .. "/5", x, y + 95, w, "center")

            local btnW = 200
            local btnH = 45
            local enterX = x + (w - btnW) / 2
            local enterY = y + 130
            local enterHover = mx >= enterX and mx <= enterX + btnW and my >= enterY and my <= enterY + btnH
            love.graphics.setColor(enterHover and {0.4, 0.5, 0.6} or {0.3, 0.4, 0.5})
            love.graphics.rectangle("fill", enterX, enterY, btnW, btnH, 6, 6)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(getFont(14))
            love.graphics.printf("Enter " .. building.name, enterX, enterY + 14, btnW, "center")
            state.propertyButtons.enter = {x = enterX, y = enterY, w = btnW, h = btnH, action = building.originalAction or building.id}

            local manageY = enterY + 55
            local manageHover = mx >= enterX and mx <= enterX + btnW and my >= manageY and my <= manageY + btnH
            love.graphics.setColor(manageHover and {0.5, 0.5, 0.4} or {0.4, 0.4, 0.3})
            love.graphics.rectangle("fill", enterX, manageY, btnW, btnH, 6, 6)
            love.graphics.setColor(0.9, 0.9, 0.8)
            love.graphics.printf("\xF0\x9F\x91\xA5 Manage Employees", enterX, manageY + 14, btnW, "center")
            state.propertyButtons.employees = {x = enterX, y = manageY, w = btnW, h = btnH}

        else
            local propertyDef = PropertySystem.HOME_PROPERTIES[building.id]
            local storage = propertyDef and propertyDef.storageSlots or 20

            love.graphics.setColor(0.6, 0.6, 0.7)
            love.graphics.setFont(getFont(12))
            love.graphics.printf("Storage Capacity: " .. storage .. " slots", x, y + 75, w, "center")

            local btnW = 180
            local btnH = 40
            local restX = x + (w - btnW) / 2
            local restY = y + 120
            local restHover = mx >= restX and mx <= restX + btnW and my >= restY and my <= restY + btnH
            love.graphics.setColor(restHover and {0.4, 0.5, 0.4} or {0.3, 0.4, 0.3})
            love.graphics.rectangle("fill", restX, restY, btnW, btnH, 6, 6)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(getFont(13))
            love.graphics.printf("\xF0\x9F\x9B\x8F\xEF\xB8\x8F Rest (Free)", restX, restY + 12, btnW, "center")
            state.propertyButtons.rest = {x = restX, y = restY, w = btnW, h = btnH}

            local storageY = restY + 50
            local storageHover = mx >= restX and mx <= restX + btnW and my >= storageY and my <= storageY + btnH
            love.graphics.setColor(storageHover and {0.5, 0.4, 0.4} or {0.4, 0.3, 0.3})
            love.graphics.rectangle("fill", restX, storageY, btnW, btnH, 6, 6)
            love.graphics.setColor(0.9, 0.9, 0.8)
            love.graphics.printf("\xF0\x9F\x93\xA6 Access Storage", restX, storageY + 12, btnW, "center")
            state.propertyButtons.storage = {x = restX, y = storageY, w = btnW, h = btnH}

            if not state.player.properties.settlements[propertyKey] then
                local upgradeY = storageY + 50
                local upgradeHover = mx >= restX and mx <= restX + btnW and my >= upgradeY and my <= upgradeY + btnH
                love.graphics.setColor(upgradeHover and {0.5, 0.5, 0.6} or {0.35, 0.35, 0.45})
                love.graphics.rectangle("fill", restX, upgradeY, btnW, btnH, 6, 6)
                love.graphics.setColor(0.8, 0.8, 0.9)
                love.graphics.printf("\xF0\x9F\x8F\x98\xEF\xB8\x8F Create Settlement", restX, upgradeY + 12, btnW, "center")
                state.propertyButtons.settlement = {x = restX, y = upgradeY, w = btnW, h = btnH}
            end
        end

        local sellW = 150
        local sellH = 35
        local sellX = x + w - sellW - 20
        local sellY = y + h - 80
        local sellHover = mx >= sellX and mx <= sellX + sellW and my >= sellY and my <= sellY + sellH
        love.graphics.setColor(sellHover and {0.6, 0.4, 0.4} or {0.4, 0.3, 0.3})
        love.graphics.rectangle("fill", sellX, sellY, sellW, sellH, 5, 5)
        love.graphics.setColor(0.9, 0.7, 0.7)
        love.graphics.setFont(getFont(11))
        love.graphics.printf("Sell Property", sellX, sellY + 10, sellW, "center")
        state.propertyButtons.sell = {x = sellX, y = sellY, w = sellW, h = sellH}
    else
        love.graphics.setColor(0.7, 0.5, 0.5)
        love.graphics.setFont(getFont(14))
        love.graphics.printf("Property data not found.", x, y + 100, w, "center")
    end

    local backW = 120
    local backH = 35
    local backX = x + 20
    local backY = y + h - 80
    local backHover = mx >= backX and mx <= backX + backW and my >= backY and my <= backY + backH
    love.graphics.setColor(backHover and {0.4, 0.4, 0.5} or {0.3, 0.3, 0.35})
    love.graphics.rectangle("fill", backX, backY, backW, backH, 5, 5)
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.setFont(getFont(11))
    love.graphics.printf("Back", backX, backY + 10, backW, "center")
    state.propertyButtons.back = {x = backX, y = backY, w = backW, h = backH}
end

-- ============================================================================
-- LAND OFFICE / CLAIM / MANAGE
-- ============================================================================

M.drawLandOffice = function(x, y, w, h, mx, my)
    if not state.player then return end
    local PropertySystem = require("propertysystem")

    -- Ensure state fields exist
    state.landOfficeButtons = {}

    -- Header
    love.graphics.setColor(0.55, 0.5, 0.35)
    love.graphics.setFont(getFont(20))
    love.graphics.printf("Land Office", x, y + 10, w, "center")

    love.graphics.setColor(0.7, 0.6, 0.45)
    love.graphics.setFont(getFont(11))
    love.graphics.printf("The Land Commissioner manages expansion permits for land owners.", x, y + 38, w, "center")

    local info = PropertySystem.getExpansionInfo()
    local currentY = y + 70

    -- Status Panel
    love.graphics.setColor(0.12, 0.14, 0.18, 0.95)
    love.graphics.rectangle("fill", x + 20, currentY, w - 40, 90, 6, 6)
    love.graphics.setColor(0.5, 0.45, 0.35)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x + 20, currentY, w - 40, 90, 6, 6)

    love.graphics.setColor(0.9, 0.85, 0.7)
    love.graphics.setFont(getFont(13))
    love.graphics.print("Land Holdings Summary", x + 35, currentY + 8)

    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.setFont(getFont(11))
    love.graphics.print("Total plots owned: " .. info.plotCount, x + 35, currentY + 30)
    love.graphics.print("Settlements: " .. #info.settlementsInfo, x + 35, currentY + 46)
    love.graphics.print("Unused permits: " .. info.permits, x + 35, currentY + 62)

    -- Right side of status panel
    local rightCol = x + w/2 + 20
    love.graphics.setColor(0.8, 0.75, 0.6)
    love.graphics.setFont(getFont(11))
    if info.plotCount > 0 then
        love.graphics.print("Your gold: " .. state.player.gold .. "g", rightCol, currentY + 30)
        local expandCount = 0
        for _ in pairs(info.expandableTiles) do expandCount = expandCount + 1 end
        love.graphics.print("Adjacent tiles available: " .. expandCount, rightCol, currentY + 46)
        love.graphics.setColor(0.5, 0.8, 0.5)
        love.graphics.print("New settlements can be started anywhere!", rightCol, currentY + 62)
    else
        love.graphics.print("Claim your first plot from the world map.", rightCol, currentY + 30)
        love.graphics.print("No permit needed for initial claim.", rightCol, currentY + 46)
        love.graphics.print("Your gold: " .. state.player.gold .. "g", rightCol, currentY + 62)
    end

    currentY = currentY + 105

    -- Buttons
    local btnW, btnH = w - 80, 40
    local btnX = x + 40

    -- Purchase Permit Button
    local minPermitCost = info.permitCost or 0
    local canBuyPermit = info.plotCount >= 1 and minPermitCost > 0 and state.player.gold >= minPermitCost
    local permitBtnHover = mx >= btnX and mx <= btnX + btnW and my >= currentY and my <= currentY + btnH
    love.graphics.setColor(canBuyPermit and (permitBtnHover and {0.4, 0.45, 0.3} or {0.3, 0.35, 0.25}) or {0.22, 0.22, 0.22})
    love.graphics.rectangle("fill", btnX, currentY, btnW, btnH, 5, 5)
    love.graphics.setColor(canBuyPermit and {0.95, 0.9, 0.7} or {0.5, 0.5, 0.5})
    love.graphics.setFont(getFont(13))
    local permitText = "Purchase Expansion Permit"
    if minPermitCost > 0 then
        permitText = permitText .. " (" .. minPermitCost .. "g)"
    elseif info.plotCount >= 1 then
        permitText = "No Permit Needed (First Expansions Free)"
    end
    love.graphics.printf(permitText, btnX, currentY + 11, btnW, "center")
    state.landOfficeButtons.buyPermit = {x = btnX, y = currentY, w = btnW, h = btnH, enabled = canBuyPermit}

    currentY = currentY + btnH + 10

    -- View Expansion Rules Button
    local rulesBtnHover = mx >= btnX and mx <= btnX + btnW and my >= currentY and my <= currentY + btnH
    love.graphics.setColor(rulesBtnHover and {0.35, 0.35, 0.42} or {0.25, 0.25, 0.3})
    love.graphics.rectangle("fill", btnX, currentY, btnW, btnH, 5, 5)
    love.graphics.setColor(0.8, 0.8, 0.9)
    love.graphics.setFont(getFont(13))
    love.graphics.printf("View Expansion Rules", btnX, currentY + 11, btnW, "center")
    state.landOfficeButtons.viewRules = {x = btnX, y = currentY, w = btnW, h = btnH, enabled = true}

    currentY = currentY + btnH + 10

    -- Check Status / Settlements Button
    local statusBtnHover = mx >= btnX and mx <= btnX + btnW and my >= currentY and my <= currentY + btnH
    love.graphics.setColor(statusBtnHover and {0.35, 0.38, 0.42} or {0.25, 0.28, 0.3})
    love.graphics.rectangle("fill", btnX, currentY, btnW, btnH, 5, 5)
    love.graphics.setColor(0.8, 0.85, 0.9)
    love.graphics.setFont(getFont(13))
    love.graphics.printf("View Your Settlements", btnX, currentY + 11, btnW, "center")
    state.landOfficeButtons.checkStatus = {x = btnX, y = currentY, w = btnW, h = btnH, enabled = true}

    currentY = currentY + btnH + 15

    -- Info Panel (shows rules/status based on landOfficeTab)
    if state.landOfficeTab == "rules" then
        love.graphics.setColor(0.12, 0.14, 0.18, 0.95)
        love.graphics.rectangle("fill", x + 20, currentY, w - 40, 180, 6, 6)
        love.graphics.setColor(0.45, 0.4, 0.35)
        love.graphics.rectangle("line", x + 20, currentY, w - 40, 180, 6, 6)

        love.graphics.setColor(0.9, 0.85, 0.7)
        love.graphics.setFont(getFont(13))
        love.graphics.print("Land Expansion Rules", x + 35, currentY + 8)

        love.graphics.setColor(0.75, 0.75, 0.85)
        love.graphics.setFont(getFont(10))
        local rules = {
            "1. You can claim land anywhere on the world map.",
            "2. Adjacent claims expand your existing settlement.",
            "3. Non-adjacent claims start a NEW independent settlement.",
            "4. The FIRST expansion of each settlement is FREE (no permit).",
            "5. After that, permits are needed. Cost per settlement:",
            "     3rd plot: 1,000g  |  4th plot: 2,000g  |  5th plot: 4,000g",
            "     Formula: 500 x 2^(settlement plots - 2)",
            "6. Adjacent plots merge into a larger settlement grid.",
            "7. Max settlement size: " .. (PropertySystem.MAX_SETTLEMENT_WIDTH or 100) .. "x" .. (PropertySystem.MAX_SETTLEMENT_HEIGHT or 100) .. " tiles (" .. (PropertySystem.MAX_PLOTS_PER_SETTLEMENT or 16) .. " plots).",
            "8. Each settlement tracks its own expansion costs independently.",
            "9. You can name your settlements from the settlement view.",
        }
        for i, rule in ipairs(rules) do
            love.graphics.print(rule, x + 35, currentY + 24 + (i - 1) * 13)
        end

    elseif state.landOfficeTab == "status" then
        local settCount = #info.settlementsInfo
        local panelBaseH = 40
        local perSettH = 55
        local panelH = math.max(130, panelBaseH + settCount * perSettH + 20)

        love.graphics.setColor(0.12, 0.14, 0.18, 0.95)
        love.graphics.rectangle("fill", x + 20, currentY, w - 40, panelH, 6, 6)
        love.graphics.setColor(0.45, 0.4, 0.35)
        love.graphics.rectangle("line", x + 20, currentY, w - 40, panelH, 6, 6)

        love.graphics.setColor(0.9, 0.85, 0.7)
        love.graphics.setFont(getFont(13))
        love.graphics.print("YOUR SETTLEMENTS", x + 35, currentY + 8)

        if settCount == 0 then
            love.graphics.setColor(0.7, 0.7, 0.8)
            love.graphics.setFont(getFont(11))
            love.graphics.print("You have no settlements yet.", x + 35, currentY + 30)
            love.graphics.print("Claim land from the world map, build a cabin and walls,", x + 35, currentY + 46)
            love.graphics.print("then found a settlement from the land management screen.", x + 35, currentY + 62)

            if info.plotCount > 0 then
                love.graphics.setColor(0.6, 0.6, 0.7)
                love.graphics.setFont(getFont(10))
                love.graphics.print("Unorganized land plots: " .. info.plotCount, x + 35, currentY + 82)
            end
        else
            love.graphics.setColor(0.4, 0.35, 0.3)
            love.graphics.line(x + 35, currentY + 25, x + w - 55, currentY + 25)

            local settY = currentY + 32
            for i, sett in ipairs(info.settlementsInfo) do
                love.graphics.setColor(0.9, 0.85, 0.6)
                love.graphics.setFont(getFont(12))
                love.graphics.print(i .. ". " .. sett.name .. " (" .. sett.id .. ")", x + 35, settY)

                love.graphics.setColor(0.7, 0.7, 0.8)
                love.graphics.setFont(getFont(10))
                love.graphics.print("   Plots: " .. sett.plotCount .. " (" .. sett.gridWidth .. "x" .. sett.gridHeight .. " grid)", x + 35, settY + 15)

                if sett.isFirstExpansionFree then
                    love.graphics.setColor(0.4, 0.9, 0.4)
                    love.graphics.print("   Next expansion: FREE! (first expansion)", x + 35, settY + 28)
                elseif sett.nextPermitCost > 0 then
                    love.graphics.setColor(0.9, 0.8, 0.5)
                    love.graphics.print("   Next expansion: " .. sett.nextPermitCost .. "g permit", x + 35, settY + 28)
                else
                    love.graphics.setColor(0.5, 0.8, 0.5)
                    love.graphics.print("   Next expansion: FREE", x + 35, settY + 28)
                end

                local rightInfoX = x + w/2 + 10
                love.graphics.setColor(0.6, 0.7, 0.6)
                love.graphics.setFont(getFont(10))
                love.graphics.print("Level: " .. sett.level .. " (" .. sett.levelName .. ")", rightInfoX, settY + 15)
                love.graphics.print("Pop: " .. sett.population .. "/" .. sett.maxPopulation, rightInfoX, settY + 28)

                settY = settY + perSettH
            end

            love.graphics.setColor(0.7, 0.7, 0.8)
            love.graphics.setFont(getFont(10))
            if info.permits > 0 then
                love.graphics.setColor(0.5, 0.9, 0.5)
                love.graphics.print("Unused permits: " .. info.permits, x + 35, settY)
            else
                love.graphics.setColor(0.6, 0.6, 0.7)
                love.graphics.print("No unused permits. Purchase above to expand beyond first expansion.", x + 35, settY)
            end
        end
    end

    -- Back Button
    local backW, backH = 120, 35
    local backX = x + w/2 - backW/2
    local backY = y + h - 55
    local backHover = mx >= backX and mx <= backX + backW and my >= backY and my <= backY + backH
    love.graphics.setColor(backHover and {0.4, 0.35, 0.35} or {0.3, 0.25, 0.25})
    love.graphics.rectangle("fill", backX, backY, backW, backH, 5, 5)
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Leave", backX, backY + 10, backW, "center")
    state.landOfficeButtons.back = {x = backX, y = backY, w = backW, h = backH, enabled = true}
end

M.drawLandClaim = function(x, y, w, h, mx, my)
    if not state.player then return end
    local PropertySystem = require("propertysystem")
    local WorldGen = require("worldgen")
    local claimX, claimY = state.landClaimX or 0, state.landClaimY or 0
    local tile
    if state.world.useWorldGen then
        tile = WorldGen.getTile(claimX, claimY)
    else
        tile = state.world.mapData[claimY] and state.world.mapData[claimY][claimX]
    end
    local region = tile and tile.region or "Unknown"
    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(20))
    love.graphics.printf("Claim Land", x, y + 15, w, "center")
    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Location: " .. claimX .. ", " .. claimY .. " (" .. region .. ")", x, y + 45, w, "center")
    state.landClaimButtons = {}
    local claimCost = PropertySystem.getClaimCost and PropertySystem.getClaimCost(claimX, claimY) or 100

    local expansionDetails = PropertySystem.getExpansionDetailsForTile(claimX, claimY)
    local isAdj = expansionDetails.isAdjacent
    local hasPermit = PropertySystem.hasExpansionPermit()
    local canAfford = state.player.gold >= claimCost
    local canClaim = canAfford

    if isAdj then
        love.graphics.setColor(0.5, 0.7, 0.9)
        love.graphics.setFont(getFont(12))
        love.graphics.printf("EXPANSION: This plot will merge with " .. (expansionDetails.settlementName or "your land") .. ".", x, y + 65, w, "center")

        if expansionDetails.isFirstExpansionFree then
            love.graphics.setColor(0.4, 0.95, 0.4)
            love.graphics.setFont(getFont(12))
            love.graphics.printf("First expansion FREE! No permit needed.", x, y + 80, w, "center")
            love.graphics.setColor(0.6, 0.8, 0.6)
            love.graphics.setFont(getFont(10))
            love.graphics.printf("(Settlement plot " .. ((expansionDetails.settlementPlotCount or 1) + 1) .. " - first expansion bonus)", x, y + 95, w, "center")
        elseif hasPermit then
            love.graphics.setColor(0.5, 0.9, 0.5)
            love.graphics.setFont(getFont(11))
            love.graphics.printf("You have an expansion permit. This plot will merge with your settlement.", x, y + 80, w, "center")
        else
            canClaim = false
            love.graphics.setColor(0.9, 0.5, 0.3)
            love.graphics.setFont(getFont(11))
            local neededCost = expansionDetails.permitCost or 0
            love.graphics.printf("Expansion permit required! (" .. neededCost .. "g at the Land Office)", x, y + 80, w, "center")
        end
    else
        local hasExistingClaims = PropertySystem.getOwnedPlotCount() > 0
        if hasExistingClaims then
            love.graphics.setColor(0.5, 0.7, 0.9)
            love.graphics.setFont(getFont(12))
            love.graphics.printf("NEW SETTLEMENT: This will start an independent settlement.", x, y + 65, w, "center")
            love.graphics.setColor(0.6, 0.8, 0.6)
            love.graphics.setFont(getFont(10))
            love.graphics.printf("(No permit needed for new settlement claims. First expansion will be free!)", x, y + 80, w, "center")
        end
    end

    love.graphics.setColor(canAfford and {0.5, 0.8, 0.5} or {0.8, 0.5, 0.5})
    love.graphics.setFont(getFont(18))
    love.graphics.printf("Cost: " .. claimCost .. "g", x, y + 110, w, "center")
    local btnW, btnH = 180, 45
    local claimBtnX = x + w/2 - btnW - 10
    local claimBtnY = y + h - 90
    local claimBtnHover = mx >= claimBtnX and mx <= claimBtnX + btnW and my >= claimBtnY and my <= claimBtnY + btnH
    love.graphics.setColor(canClaim and (claimBtnHover and {0.4, 0.5, 0.4} or {0.3, 0.4, 0.3}) or {0.3, 0.3, 0.3})
    love.graphics.rectangle("fill", claimBtnX, claimBtnY, btnW, btnH, 6, 6)
    love.graphics.setColor(canClaim and {1,1,1} or {0.5,0.5,0.5})
    love.graphics.setFont(getFont(14))
    local claimBtnText = "Claim Land"
    if isAdj then
        claimBtnText = "Expand Settlement"
    elseif PropertySystem.getOwnedPlotCount() > 0 then
        claimBtnText = "Start New Settlement"
    end
    love.graphics.printf(claimBtnText, claimBtnX, claimBtnY + 14, btnW, "center")
    state.landClaimButtons.claim = {x = claimBtnX, y = claimBtnY, w = btnW, h = btnH, enabled = canClaim}
    local cancelX = x + w/2 + 10
    local cancelHover = mx >= cancelX and mx <= cancelX + btnW and my >= claimBtnY and my <= claimBtnY + btnH
    love.graphics.setColor(cancelHover and {0.5, 0.4, 0.4} or {0.35, 0.3, 0.3})
    love.graphics.rectangle("fill", cancelX, claimBtnY, btnW, btnH, 6, 6)
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.printf("Cancel", cancelX, claimBtnY + 14, btnW, "center")
    state.landClaimButtons.cancel = {x = cancelX, y = claimBtnY, w = btnW, h = btnH}
end

M.drawLandManage = function(x, y, w, h, mx, my)
    if not state.player then return end
    local PropertySystem = require("propertysystem")
    local Backpack = require("backpack")

    if not state.landClaimX or not state.landClaimY then
        love.graphics.setColor(0.8, 0.5, 0.5)
        love.graphics.setFont(getFont(14))
        love.graphics.printf("Error: No land claim coordinates", x, y + 50, w, "center")
        return
    end

    local claimX, claimY = state.landClaimX, state.landClaimY
    local claimKey = claimX .. "_" .. claimY
    local claim = state.player.properties.landClaims[claimKey]
    local settlement = state.player.properties.settlements and state.player.properties.settlements[claimKey]

    state.landManageButtons = {}

    love.graphics.setColor(0.5, 0.8, 0.5)
    love.graphics.setFont(getFont(20))
    love.graphics.printf("Your Land", x, y + 10, w, "center")

    if not claim then
        love.graphics.setColor(0.8, 0.5, 0.5)
        love.graphics.setFont(getFont(14))
        love.graphics.printf("No claim found at this location", x, y + 50, w, "center")
        return
    end

    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(getFont(10))
    love.graphics.printf("Location: " .. claimX .. ", " .. claimY .. " | Region: " .. (claim.region or "Unknown"), x, y + 35, w, "center")

    local leftX = x + 20
    local rightX = x + w/2 + 10
    local colW = w/2 - 30
    local currentY = y + 55

    -- LEFT COLUMN: Structure & Defense
    love.graphics.setColor(0.15, 0.18, 0.2, 0.9)
    love.graphics.rectangle("fill", leftX, currentY, colW, 200, 5, 5)

    local structureDef = claim.structure and PropertySystem.WILD_STRUCTURES[claim.structure]
    local structureName = structureDef and structureDef.name or "Empty Land"
    local structureIcon = "F"
    if claim.structure == "tent" then structureIcon = "T"
    elseif claim.structure == "cabin" then structureIcon = "C"
    elseif claim.structure == "wild_house" then structureIcon = "H"
    elseif claim.structure == "wild_manor" then structureIcon = "M"
    end

    love.graphics.setColor(0.9, 0.8, 0.5)
    love.graphics.setFont(getFont(14))
    love.graphics.print(structureIcon .. " " .. structureName, leftX + 10, currentY + 8)

    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.setFont(getFont(10))
    love.graphics.print("Defense: " .. (claim.defenseRating or 0), leftX + 10, currentY + 30)
    love.graphics.print("Residents: " .. #(claim.residents or {}) .. "/" .. (claim.maxResidents or 0), leftX + 10, currentY + 44)

    local damageLevel = claim.damageLevel or 0
    if damageLevel > 0 then
        love.graphics.setColor(0.9, 0.3, 0.3)
        love.graphics.print("Damage: " .. damageLevel .. "%", leftX + 10, currentY + 58)
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.rectangle("fill", leftX + 100, currentY + 58, 80, 12, 2, 2)
        love.graphics.setColor(0.9, 0.3, 0.3)
        love.graphics.rectangle("fill", leftX + 100, currentY + 58, 80 * (damageLevel / 100), 12, 2, 2)
    end

    if claim.building then
        love.graphics.setColor(0.5, 0.8, 0.5)
        love.graphics.setFont(getFont(9))
        local buildDef = PropertySystem.WILD_STRUCTURES[claim.building.structureId]
        love.graphics.print("Building: " .. (buildDef and buildDef.name or "..."), leftX + 10, currentY + 75)
        love.graphics.print(math.ceil(claim.building.hoursRemaining) .. " hours left", leftX + 10, currentY + 87)
    end

    local btnY = currentY + 105
    local btnW, btnH = colW - 20, 28

    if not claim.building then
        local nextStructure = nil
        local nextStructureDef = nil
        if not claim.structure then
            nextStructure = "tent"
            nextStructureDef = PropertySystem.WILD_STRUCTURES.tent
        elseif structureDef and structureDef.upgradesTo then
            nextStructure = structureDef.upgradesTo
            nextStructureDef = PropertySystem.WILD_STRUCTURES[nextStructure]
        end

        if nextStructureDef then
            local canBuild, reason = PropertySystem.canBuildStructure(claimKey, nextStructure)
            local btnHover = mx >= leftX + 10 and mx <= leftX + 10 + btnW and my >= btnY and my <= btnY + btnH
            love.graphics.setColor(canBuild and (btnHover and {0.4, 0.5, 0.4} or {0.3, 0.4, 0.3}) or {0.25, 0.25, 0.25})
            love.graphics.rectangle("fill", leftX + 10, btnY, btnW, btnH, 4, 4)
            love.graphics.setColor(canBuild and {0.9, 1, 0.9} or {0.5, 0.5, 0.5})
            love.graphics.setFont(getFont(10))
            local buildText = (claim.structure and "Upgrade to " or "Build ") .. nextStructureDef.name .. " (" .. nextStructureDef.cost.gold .. "g)"
            love.graphics.printf(buildText, leftX + 10, btnY + 8, btnW, "center")
            state.landManageButtons.buildStructure = {x = leftX + 10, y = btnY, w = btnW, h = btnH, structureId = nextStructure, enabled = canBuild}
        else
            love.graphics.setColor(0.4, 0.4, 0.5)
            love.graphics.setFont(getFont(10))
            love.graphics.printf("Max structure level reached", leftX + 10, btnY + 8, btnW, "center")
        end
    end

    btnY = btnY + btnH + 5
    if damageLevel > 0 then
        local repairCost = PropertySystem.getRepairCost(claimKey)
        local canRepair = state.player.gold >= repairCost
        local btnHover = mx >= leftX + 10 and mx <= leftX + 10 + btnW and my >= btnY and my <= btnY + btnH
        love.graphics.setColor(canRepair and (btnHover and {0.5, 0.4, 0.3} or {0.4, 0.3, 0.25}) or {0.25, 0.25, 0.25})
        love.graphics.rectangle("fill", leftX + 10, btnY, btnW, btnH, 4, 4)
        love.graphics.setColor(canRepair and {1, 0.9, 0.8} or {0.5, 0.5, 0.5})
        love.graphics.setFont(getFont(10))
        love.graphics.printf("Repair (" .. repairCost .. "g)", leftX + 10, btnY + 8, btnW, "center")
        state.landManageButtons.repair = {x = leftX + 10, y = btnY, w = btnW, h = btnH, enabled = canRepair}
        btnY = btnY + btnH + 5
    end

    -- RIGHT COLUMN: Walls & Settlement
    love.graphics.setColor(0.15, 0.18, 0.2, 0.9)
    love.graphics.rectangle("fill", rightX, currentY, colW, 200, 5, 5)

    local wallName = "No Walls"
    local wallIcon = "!"
    if claim.wallLevel == 1 then wallName = "Wooden Fence"; wallIcon = "W"
    elseif claim.wallLevel == 2 then wallName = "Stone Wall"; wallIcon = "S"
    elseif claim.wallLevel >= 3 then wallName = "Fortified Wall"; wallIcon = "F"
    end

    love.graphics.setColor(0.7, 0.7, 0.9)
    love.graphics.setFont(getFont(14))
    love.graphics.print(wallIcon .. " " .. wallName, rightX + 10, currentY + 8)

    if not claim.hasWalls then
        love.graphics.setColor(0.9, 0.5, 0.3)
        love.graphics.setFont(getFont(9))
        love.graphics.print("WARNING: Unprotected from attacks!", rightX + 10, currentY + 28)
    else
        love.graphics.setColor(0.5, 0.8, 0.5)
        love.graphics.setFont(getFont(9))
        love.graphics.print("Defense Bonus: +" .. ((claim.wallLevel or 0) * 20), rightX + 10, currentY + 28)
    end

    if claim.wallBuilding then
        love.graphics.setColor(0.5, 0.8, 0.5)
        love.graphics.setFont(getFont(9))
        local wallDef = PropertySystem.WALL_STRUCTURES[claim.wallBuilding.wallId]
        love.graphics.print("Building: " .. (wallDef and wallDef.name or "..."), rightX + 10, currentY + 45)
        love.graphics.print(math.ceil(claim.wallBuilding.hoursRemaining) .. " hours left", rightX + 10, currentY + 57)
    end

    local wallBtnY = currentY + 75
    if not claim.wallBuilding and claim.structure then
        local nextWall = nil
        local nextWallDef = nil
        if not claim.hasWalls or claim.wallLevel == 0 then
            nextWall = "wooden_fence"
            nextWallDef = PropertySystem.WALL_STRUCTURES.wooden_fence
        elseif claim.wallLevel == 1 then
            nextWall = "stone_wall"
            nextWallDef = PropertySystem.WALL_STRUCTURES.stone_wall
        elseif claim.wallLevel == 2 then
            nextWall = "fortified_wall"
            nextWallDef = PropertySystem.WALL_STRUCTURES.fortified_wall
        end

        if nextWallDef then
            local canBuild, reason = PropertySystem.canBuildWall(claimKey, nextWall)
            local btnHover = mx >= rightX + 10 and mx <= rightX + 10 + btnW and my >= wallBtnY and my <= wallBtnY + btnH
            love.graphics.setColor(canBuild and (btnHover and {0.4, 0.4, 0.5} or {0.3, 0.35, 0.4}) or {0.25, 0.25, 0.25})
            love.graphics.rectangle("fill", rightX + 10, wallBtnY, btnW, btnH, 4, 4)
            love.graphics.setColor(canBuild and {0.9, 0.9, 1} or {0.5, 0.5, 0.5})
            love.graphics.setFont(getFont(10))
            local wallText = "Build " .. nextWallDef.name .. " (" .. nextWallDef.cost.gold .. "g)"
            love.graphics.printf(wallText, rightX + 10, wallBtnY + 8, btnW, "center")
            state.landManageButtons.buildWall = {x = rightX + 10, y = wallBtnY, w = btnW, h = btnH, wallId = nextWall, enabled = canBuild}
        elseif claim.wallLevel >= 3 then
            love.graphics.setColor(0.4, 0.5, 0.4)
            love.graphics.setFont(getFont(10))
            love.graphics.printf("Maximum fortification", rightX + 10, wallBtnY + 8, btnW, "center")
        end
    elseif not claim.structure then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.setFont(getFont(9))
        love.graphics.printf("Build a structure first", rightX + 10, wallBtnY + 8, btnW, "center")
    end

    wallBtnY = wallBtnY + btnH + 15
    love.graphics.setColor(0.8, 0.8, 0.5)
    love.graphics.setFont(getFont(12))
    if settlement then
        love.graphics.print("Settlement: " .. settlement.name, rightX + 10, wallBtnY)
        love.graphics.setColor(0.6, 0.7, 0.6)
        love.graphics.setFont(getFont(9))
        love.graphics.print("Level " .. settlement.level .. " " .. settlement.levelName, rightX + 10, wallBtnY + 15)
        love.graphics.print("Pop: " .. settlement.population .. "/" .. settlement.maxPopulation, rightX + 10, wallBtnY + 28)

        if settlement.level < 5 then
            local settleBtnY = wallBtnY + 45
            local canUpgrade, reason = PropertySystem.canUpgradeSettlement(claimKey)
            local nextLevel = PropertySystem.SETTLEMENT_LEVELS[settlement.level + 1]
            local btnHover = mx >= rightX + 10 and mx <= rightX + 10 + btnW and my >= settleBtnY and my <= settleBtnY + btnH
            love.graphics.setColor(canUpgrade and (btnHover and {0.5, 0.5, 0.4} or {0.4, 0.4, 0.35}) or {0.25, 0.25, 0.25})
            love.graphics.rectangle("fill", rightX + 10, settleBtnY, btnW, btnH, 4, 4)
            love.graphics.setColor(canUpgrade and {1, 1, 0.9} or {0.5, 0.5, 0.5})
            love.graphics.setFont(getFont(10))
            love.graphics.printf("Upgrade to " .. nextLevel.name .. " (" .. nextLevel.cost.gold .. "g)", rightX + 10, settleBtnY + 8, btnW, "center")
            state.landManageButtons.upgradeSettlement = {x = rightX + 10, y = settleBtnY, w = btnW, h = btnH, enabled = canUpgrade}
        end
    else
        love.graphics.print("No Settlement", rightX + 10, wallBtnY)
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.setFont(getFont(9))
        love.graphics.print("Requires cabin + walls", rightX + 10, wallBtnY + 15)

        local canCreate, reason = PropertySystem.canCreateSettlement(claimKey)
        if canCreate or (claim.structure and claim.structure ~= "tent" and claim.hasWalls) then
            local settleBtnY = wallBtnY + 35
            local btnHover = mx >= rightX + 10 and mx <= rightX + 10 + btnW and my >= settleBtnY and my <= settleBtnY + btnH
            love.graphics.setColor(canCreate and (btnHover and {0.5, 0.5, 0.4} or {0.4, 0.4, 0.35}) or {0.25, 0.25, 0.25})
            love.graphics.rectangle("fill", rightX + 10, settleBtnY, btnW, btnH, 4, 4)
            love.graphics.setColor(canCreate and {1, 1, 0.9} or {0.5, 0.5, 0.5})
            love.graphics.setFont(getFont(10))
            love.graphics.printf("Found Settlement", rightX + 10, settleBtnY + 8, btnW, "center")
            state.landManageButtons.foundSettlement = {x = rightX + 10, y = settleBtnY, w = btnW, h = btnH, enabled = canCreate}
        end
    end

    -- Bottom Section: Improvements & Attack Log
    local bottomY = currentY + 210

    local impPanelW = (w - 50) / 2
    love.graphics.setColor(0.12, 0.15, 0.12, 0.9)
    love.graphics.rectangle("fill", leftX, bottomY, impPanelW, 90, 5, 5)

    love.graphics.setColor(0.5, 0.8, 0.5)
    love.graphics.setFont(getFont(11))
    love.graphics.print("Improvements", leftX + 10, bottomY + 5)

    claim.improvements = claim.improvements or {}
    local builtCount = 0
    for _ in pairs(claim.improvements) do builtCount = builtCount + 1 end

    if builtCount > 0 then
        love.graphics.setColor(0.6, 0.7, 0.6)
        love.graphics.setFont(getFont(8))
        local impY = bottomY + 20
        for impId, _ in pairs(claim.improvements) do
            local impDef = PropertySystem.IMPROVEMENTS[impId]
            if impDef then
                love.graphics.print("+ " .. impDef.name, leftX + 10, impY)
                impY = impY + 11
                if impY > bottomY + 55 then break end
            end
        end
    end

    if claim.improvementBuilding then
        love.graphics.setColor(0.8, 0.8, 0.5)
        love.graphics.setFont(getFont(8))
        local impDef = PropertySystem.IMPROVEMENTS[claim.improvementBuilding.improvementId]
        love.graphics.print("Building: " .. (impDef and impDef.name or "...") .. " (" .. math.ceil(claim.improvementBuilding.hoursRemaining) .. "h)", leftX + 10, bottomY + 60)
    elseif claim.structure then
        local nextImp = nil
        local nextImpDef = nil
        for impId, impDef in pairs(PropertySystem.IMPROVEMENTS) do
            if not claim.improvements[impId] then
                local canBuild = PropertySystem.canBuildImprovement(claimKey, impId)
                if canBuild then
                    nextImp = impId
                    nextImpDef = impDef
                    break
                end
            end
        end

        if nextImpDef then
            local impBtnY = bottomY + 62
            local impBtnW = impPanelW - 20
            local impBtnH = 22
            local btnHover = mx >= leftX + 10 and mx <= leftX + 10 + impBtnW and my >= impBtnY and my <= impBtnY + impBtnH
            love.graphics.setColor(btnHover and {0.4, 0.5, 0.4} or {0.3, 0.4, 0.3})
            love.graphics.rectangle("fill", leftX + 10, impBtnY, impBtnW, impBtnH, 3, 3)
            love.graphics.setColor(0.9, 1, 0.9)
            love.graphics.setFont(getFont(9))
            love.graphics.printf("+ " .. nextImpDef.name .. " (" .. nextImpDef.cost.gold .. "g)", leftX + 10, impBtnY + 5, impBtnW, "center")
            state.landManageButtons.buildImprovement = {x = leftX + 10, y = impBtnY, w = impBtnW, h = impBtnH, improvementId = nextImp, enabled = true}
        elseif builtCount == 0 then
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.setFont(getFont(8))
            love.graphics.print("Build structure first", leftX + 10, bottomY + 65)
        end
    end

    local attackX = leftX + impPanelW + 10
    love.graphics.setColor(0.15, 0.12, 0.12, 0.9)
    love.graphics.rectangle("fill", attackX, bottomY, impPanelW, 90, 5, 5)

    love.graphics.setColor(0.8, 0.5, 0.5)
    love.graphics.setFont(getFont(11))
    love.graphics.print("Recent Attacks", attackX + 10, bottomY + 5)

    if claim.attackLog and #claim.attackLog > 0 then
        love.graphics.setColor(0.7, 0.6, 0.6)
        love.graphics.setFont(getFont(8))
        local logY = bottomY + 20
        local shown = 0
        for i = #claim.attackLog, math.max(1, #claim.attackLog - 2), -1 do
            local attack = claim.attackLog[i]
            love.graphics.print("Day " .. attack.day .. ": " .. attack.attacker .. " (" .. attack.damage .. " dmg)", attackX + 10, logY)
            logY = logY + 12
            shown = shown + 1
            if shown >= 4 then break end
        end
    else
        love.graphics.setColor(0.5, 0.6, 0.5)
        love.graphics.setFont(getFont(8))
        love.graphics.print("No recent attacks", attackX + 10, bottomY + 25)
    end

    local bottomBtnY = bottomY + 100
    local smallBtnW = 130

    local abandonHover = mx >= leftX and mx <= leftX + smallBtnW and my >= bottomBtnY and my <= bottomBtnY + 30
    love.graphics.setColor(abandonHover and {0.5, 0.3, 0.3} or {0.35, 0.25, 0.25})
    love.graphics.rectangle("fill", leftX, bottomBtnY, smallBtnW, 30, 4, 4)
    love.graphics.setColor(0.9, 0.7, 0.7)
    love.graphics.setFont(getFont(10))
    love.graphics.printf("Abandon Claim", leftX, bottomBtnY + 9, smallBtnW, "center")
    state.landManageButtons.abandon = {x = leftX, y = bottomBtnY, w = smallBtnW, h = 30}

    local backX = x + w - smallBtnW - 20
    local backHover = mx >= backX and mx <= backX + smallBtnW and my >= bottomBtnY and my <= bottomBtnY + 30
    love.graphics.setColor(backHover and {0.4, 0.4, 0.5} or {0.3, 0.3, 0.35})
    love.graphics.rectangle("fill", backX, bottomBtnY, smallBtnW, 30, 4, 4)
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.setFont(getFont(10))
    love.graphics.printf("Back to Map", backX, bottomBtnY + 9, smallBtnW, "center")
    state.landManageButtons.back = {x = backX, y = bottomBtnY, w = smallBtnW, h = 30}

    love.graphics.setColor(0.9, 0.8, 0.3)
    love.graphics.setFont(getFont(11))
    love.graphics.printf("Gold: " .. (state.player.gold or 0) .. "g", x, bottomBtnY + 40, w, "center")
end

-- ============================================================================
-- PARTY / CAMP
-- ============================================================================

M.drawParty = function(x, y, w, h, mx, my)
    if not state.player then return end
    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(20))
    love.graphics.printf("Your Party", x, y + 5, w, "center")

    local party = state.player.party or {}
    local partySize = #party
    local maxSize = state.player.maxPartySize or 99

    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(getFont(11))
    love.graphics.printf("Manage your companions (" .. partySize .. "/" .. maxSize .. ")", x, y + 30, w, "center")

    if partySize == 0 then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.setFont(getFont(14))
        love.graphics.printf("You have no companions.\nVisit the Guild Hall to recruit adventurers!", x, y + 100, w, "center")
    else
        local startY = y + 60
        local cardW = w - 40
        local cardH = 80
        local spacing = 10

        state.partyButtons = {}

        local getPortraitImage = F.getPortraitImage or function() return nil end

        for i, companion in ipairs(party) do
            local cy = startY + (i - 1) * (cardH + spacing)
            local cx = x + 20

            local hover = mx >= cx and mx <= cx + cardW and my >= cy and my <= cy + cardH

            love.graphics.setColor(hover and {0.2, 0.25, 0.3} or {0.12, 0.15, 0.2})
            love.graphics.rectangle("fill", cx, cy, cardW, cardH, 6, 6)

            local portraitImg = getPortraitImage(companion.portrait)
            if portraitImg then
                love.graphics.setColor(1, 1, 1)
                local imgW, imgH = portraitImg:getDimensions()
                local scale = math.min(60 / imgW, 60 / imgH)
                love.graphics.draw(portraitImg, cx + 10, cy + 10, 0, scale, scale)
            else
                love.graphics.setColor(companion.color or {0.7, 0.7, 0.7})
                love.graphics.setFont(getFont(32))
                love.graphics.print((companion.class and companion.class.id or "w"):sub(1, 1):upper(), cx + 20, cy + 15)
            end

            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(getFont(14))
            love.graphics.print(companion.name .. " the " .. (companion.class and companion.class.name or "Unknown"), cx + 80, cy + 10)

            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.setFont(getFont(11))
            love.graphics.print("Level " .. companion.level, cx + 80, cy + 30)

            local hpPct = companion.hp / companion.maxHP
            local hpBarW = 150
            love.graphics.setColor(0.3, 0.3, 0.3)
            love.graphics.rectangle("fill", cx + 180, cy + 30, hpBarW, 12, 3, 3)
            love.graphics.setColor(hpPct > 0.5 and {0.3, 0.8, 0.3} or (hpPct > 0.25 and {0.8, 0.8, 0.3} or {0.8, 0.3, 0.3}))
            love.graphics.rectangle("fill", cx + 180, cy + 30, hpBarW * hpPct, 12, 3, 3)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(getFont(9))
            love.graphics.printf(companion.hp .. "/" .. companion.maxHP, cx + 180, cy + 31, hpBarW, "center")

            love.graphics.setColor(0.6, 0.6, 0.6)
            love.graphics.setFont(getFont(10))
            love.graphics.print("ATK: " .. companion.attack .. "  DEF: " .. companion.defense .. "  Wage: " .. companion.dailyWage .. "g/day", cx + 80, cy + 50)

            love.graphics.setColor(companion.morale > 50 and {0.5, 0.8, 0.5} or {0.8, 0.5, 0.5})
            love.graphics.print("Morale: " .. companion.morale .. "%", cx + 350, cy + 50)

            local dismissX = cx + cardW - 80
            local dismissY = cy + 10
            local dismissHover = mx >= dismissX and mx <= dismissX + 70 and my >= dismissY and my <= dismissY + 25
            love.graphics.setColor(dismissHover and {0.6, 0.3, 0.3} or {0.4, 0.2, 0.2})
            love.graphics.rectangle("fill", dismissX, dismissY, 70, 25, 4, 4)
            love.graphics.setColor(1, 0.8, 0.8)
            love.graphics.setFont(getFont(10))
            love.graphics.printf("Dismiss", dismissX, dismissY + 6, 70, "center")

            state.partyButtons[i] = {
                x = cx, y = cy, w = cardW, h = cardH,
                dismissBtn = {x = dismissX, y = dismissY, w = 70, h = 25}
            }
        end
    end

    local totalWage = 0
    for _, c in ipairs(state.player.party or {}) do
        totalWage = totalWage + (c.dailyWage or 0)
    end
    if totalWage > 0 then
        love.graphics.setColor(0.8, 0.7, 0.3)
        love.graphics.setFont(getFont(11))
        love.graphics.printf("Total daily wages: " .. totalWage .. " gold", x, y + h - 60, w, "center")
    end

    local backY = y + h - 35
    local backW = 120
    local backX = x + (w - backW) / 2
    local backHover = mx >= backX and mx <= backX + backW and my >= backY and my <= backY + 30
    love.graphics.setColor(backHover and {0.4, 0.3, 0.3} or {0.25, 0.2, 0.2})
    love.graphics.rectangle("fill", backX, backY, backW, 30, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Back to Town", backX, backY + 8, backW, "center")
    state.partyBackButton = {x = backX, y = backY, w = backW, h = 30}
end

M.drawCamping = function(x, y, w, h, mx, my)
    local getCurrentWeather = F.getCurrentWeather or function() return "pleasant" end
    local WEATHER_EFFECTS = F.WEATHER_EFFECTS or {}
    local SHELTER_TYPES = F.SHELTER_TYPES or {}
    local getTQInventory = F.getTQInventory

    local weather = getCurrentWeather()
    local weatherFx = WEATHER_EFFECTS[weather] or WEATHER_EFFECTS.pleasant or {color = {0.7,0.7,0.7}, icon = "?", name = "Unknown", desc = ""}

    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(20))
    love.graphics.printf("Set Up Camp", x, y + 5, w, "center")

    love.graphics.setColor(weatherFx.color)
    love.graphics.setFont(getFont(16))
    love.graphics.printf((weatherFx.icon or "") .. " " .. (weatherFx.name or ""), x, y + 35, w, "center")

    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.setFont(getFont(11))
    love.graphics.printf(weatherFx.desc or "", x, y + 55, w, "center")

    local menuX = x + w / 2 - 150
    local menuY = y + 80
    local optH = 45
    local optIdx = 0

    for i, shelter in ipairs(SHELTER_TYPES) do
        if not shelter.townOnly then
            local optY = menuY + optIdx * (optH + 8)
            local hover = mx >= menuX and mx <= menuX + 300 and my >= optY and my <= optY + optH

            local available = true
            local unavailableReason = nil
            if shelter.requiresItem then
                local hasItem = false
                local inventory = getTQInventory and getTQInventory() or {}
                for _, item in ipairs(inventory) do
                    if item.id == shelter.requiresItem then hasItem = true break end
                end
                if not hasItem then
                    available = false
                    unavailableReason = "Requires: " .. shelter.requiresItem
                end
            end

            if available then
                love.graphics.setColor(hover and {0.25, 0.35, 0.3} or {0.15, 0.2, 0.18})
            else
                love.graphics.setColor(0.15, 0.15, 0.15, 0.7)
            end
            love.graphics.rectangle("fill", menuX, optY, 300, optH, 5, 5)

            love.graphics.setColor(available and {0.9, 0.9, 0.9} or {0.5, 0.5, 0.5})
            love.graphics.setFont(getFont(13))
            love.graphics.print(shelter.name, menuX + 10, optY + 5)

            love.graphics.setFont(getFont(10))
            love.graphics.setColor(available and {0.6, 0.6, 0.7} or {0.4, 0.4, 0.4})
            love.graphics.print(shelter.desc, menuX + 10, optY + 22)

            local qualityColor = shelter.quality >= 0.8 and {0.3, 0.8, 0.3} or shelter.quality >= 0.5 and {0.8, 0.8, 0.3} or {0.8, 0.5, 0.3}
            if not available then qualityColor = {0.4, 0.4, 0.4} end
            love.graphics.setColor(qualityColor)
            love.graphics.printf("Quality: " .. math.floor(shelter.quality * 100) .. "%", menuX, optY + 5, 290, "right")

            love.graphics.setFont(getFont(9))
            love.graphics.setColor(0.5, 0.5, 0.6)
            if shelter.chanceToFind then
                love.graphics.printf(math.floor(shelter.chanceToFind * 100) .. "% chance", menuX, optY + 32, 290, "right")
            elseif shelter.time then
                love.graphics.printf(shelter.time .. "h setup", menuX, optY + 32, 290, "right")
            end

            if unavailableReason then
                love.graphics.setColor(0.8, 0.4, 0.3)
                love.graphics.setFont(getFont(9))
                love.graphics.printf(unavailableReason, menuX + 10, optY + 35, 200, "left")
            end

            optIdx = optIdx + 1
        end
    end

    local backY = menuY + 200
    local backX = menuX + 100
    local backHover = mx >= backX and mx <= backX + 100 and my >= backY and my <= backY + 35
    love.graphics.setColor(backHover and {0.4, 0.3, 0.3} or {0.25, 0.2, 0.2})
    love.graphics.rectangle("fill", backX, backY, 100, 35, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Back", backX, backY + 10, 100, "center")
end

-- ============================================================================
-- CAMP DRAWS
-- ============================================================================

M.drawCamp = function(x, y, w, h, mx, my)
    if not state.player then return end
    local getCurrentWeather = F.getCurrentWeather or function() return "pleasant" end
    local WEATHER_EFFECTS = F.WEATHER_EFFECTS or {}
    local getAmbushChance = F.getAmbushChance or function() return 0 end

    local weather = getCurrentWeather()
    local weatherFx = WEATHER_EFFECTS[weather] or WEATHER_EFFECTS.pleasant or {color = {0.7,0.7,0.7}, icon = "?", name = "Unknown"}
    local shelter = state.camping.type or {name = "Camp", quality = 0.5}
    local party = state.player.party or {}
    local activity = state.camping.activity or "main"

    -- Header with campfire visual
    love.graphics.setColor(0.12, 0.1, 0.08)
    love.graphics.rectangle("fill", x, y, w, 60, 5, 5)

    -- Campfire icon
    local fireIcon = state.camping.campfireLit and "🔥" or "⚫"
    love.graphics.setFont(getFont(28))
    love.graphics.setColor(state.camping.campfireLit and {1, 0.6, 0.2} or {0.3, 0.3, 0.3})
    love.graphics.print(fireIcon, x + 15, y + 12)

    -- Title
    love.graphics.setColor(0.95, 0.8, 0.4)
    love.graphics.setFont(getFont(22))
    love.graphics.printf("Camp", x + 50, y + 8, w - 60, "left")

    -- Weather and time
    love.graphics.setColor(weatherFx.color)
    love.graphics.setFont(getFont(11))
    local timeStr = string.format("%02d:00", state.timeOfDay or 12)
    love.graphics.printf(weatherFx.icon .. " " .. weatherFx.name .. "  |  " .. timeStr, x, y + 38, w - 20, "right")

    -- Morale bar
    local morale = state.camping.morale or 50
    local moraleW = 120
    local moraleX = x + 55
    local moraleY = y + 38
    love.graphics.setColor(0.2, 0.2, 0.25)
    love.graphics.rectangle("fill", moraleX, moraleY, moraleW, 12, 3, 3)
    local moraleColor = morale > 70 and {0.3, 0.8, 0.3} or (morale > 40 and {0.8, 0.8, 0.3} or {0.8, 0.3, 0.3})
    love.graphics.setColor(moraleColor)
    love.graphics.rectangle("fill", moraleX, moraleY, moraleW * (morale / 100), 12, 3, 3)
    love.graphics.setFont(getFont(8))
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Morale: " .. morale, moraleX, moraleY + 1, moraleW, "center")

    -- Guard status display
    local guardY = y + 65
    love.graphics.setColor(0.1, 0.12, 0.15, 0.9)
    love.graphics.rectangle("fill", x, guardY, w, 30, 0, 0)
    love.graphics.setFont(getFont(11))
    if state.camping.guard then
        love.graphics.setColor(0.4, 0.9, 0.4)
        local guardName = state.camping.guard == "player" and (state.player.name or "You") or state.camping.guard
        love.graphics.printf("Guard: " .. guardName .. " is keeping watch", x + 10, guardY + 8, w - 20, "left")
    else
        love.graphics.setColor(0.9, 0.5, 0.3)
        love.graphics.printf("NO GUARD - Risk of ambush while sleeping!", x + 10, guardY + 8, w - 20, "left")
    end

    -- Calculate ambush chance for display
    local ambushChance = getAmbushChance(4) * 100
    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(getFont(9))
    love.graphics.printf("Ambush risk: " .. math.floor(ambushChance) .. "%", x, guardY + 8, w - 15, "right")

    -- Main content area
    local contentY = guardY + 40
    local contentH = h - 150

    if activity == "main" then
        M.drawCampMain(x, contentY, w, contentH, mx, my, party)
    elseif activity == "cooking" then
        M.drawCampCooking(x, contentY, w, contentH, mx, my)
    elseif activity == "chat" then
        M.drawCampChat(x, contentY, w, contentH, mx, my, party)
    elseif activity == "rest" then
        M.drawCampRest(x, contentY, w, contentH, mx, my)
    elseif activity == "guard" then
        M.drawCampGuard(x, contentY, w, contentH, mx, my, party)
    end

    -- Bottom action bar
    local barY = y + h - 45
    love.graphics.setColor(0.08, 0.08, 0.1)
    love.graphics.rectangle("fill", x, barY, w, 45, 0, 5)

    -- Break Camp button
    local breakX = x + w - 140
    local breakHover = mx >= breakX and mx <= breakX + 130 and my >= barY + 8 and my <= barY + 38
    love.graphics.setColor(breakHover and {0.5, 0.35, 0.25} or {0.35, 0.25, 0.2})
    love.graphics.rectangle("fill", breakX, barY + 8, 130, 30, 5, 5)
    love.graphics.setColor(1, 0.9, 0.8)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Break Camp", breakX, barY + 16, 130, "center")
end

M.drawCampMain = function(x, y, w, h, mx, my, party)
    if not state.player then return end
    local btnW = 180
    local btnH = 55
    local btnSpacing = 15
    local cols = 2
    local startX = x + (w - (cols * btnW + (cols - 1) * btnSpacing)) / 2
    local startY = y + 20

    local buttons = {
        {name = "Rest", icon = "💤", desc = "Sleep to recover HP/Mana", action = "rest"},
        {name = "Cook Food", icon = "🍳", desc = "Prepare meals from ingredients", action = "cooking"},
        {name = "Set Guard", icon = "👁", desc = "Assign someone to watch", action = "guard"},
        {name = "Chat", icon = "💬", desc = "Talk with party members", action = "chat"},
    }

    -- Toggle campfire button
    local fireX = startX
    local fireY = startY + 2 * (btnH + btnSpacing)
    local fireHover = mx >= fireX and mx <= fireX + btnW * 2 + btnSpacing and my >= fireY and my <= fireY + 40
    love.graphics.setColor(fireHover and {0.4, 0.3, 0.2} or {0.25, 0.2, 0.15})
    love.graphics.rectangle("fill", fireX, fireY, btnW * 2 + btnSpacing, 40, 5, 5)
    love.graphics.setColor(state.camping.campfireLit and {1, 0.7, 0.3} or {0.6, 0.6, 0.6})
    love.graphics.setFont(getFont(14))
    local fireText = state.camping.campfireLit and "🔥 Extinguish Fire" or "🪵 Light Campfire"
    love.graphics.printf(fireText, fireX, fireY + 12, btnW * 2 + btnSpacing, "center")

    -- Process Lumber button (if player has raw lumber)
    local Backpack = require("backpack")
    local rawLumber = Backpack.getItemCount("raw_lumber") or 0
    if rawLumber >= 2 then
        local lumberY = fireY + 50
        local lumberHover = mx >= fireX and mx <= fireX + btnW * 2 + btnSpacing and my >= lumberY and my <= lumberY + 40
        love.graphics.setColor(lumberHover and {0.35, 0.3, 0.2} or {0.2, 0.18, 0.12})
        love.graphics.rectangle("fill", fireX, lumberY, btnW * 2 + btnSpacing, 40, 5, 5)
        love.graphics.setColor(0.8, 0.7, 0.5)
        love.graphics.setFont(getFont(14))
        local planksCanMake = math.floor(rawLumber / 2)
        love.graphics.printf("🪵 Process Lumber (" .. rawLumber .. " -> " .. planksCanMake .. " planks)", fireX, lumberY + 12, btnW * 2 + btnSpacing, "center")
        state.campLumberBtn = {x = fireX, y = lumberY, w = btnW * 2 + btnSpacing, h = 40}
    else
        state.campLumberBtn = nil
    end

    -- Main action buttons
    for i, btn in ipairs(buttons) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local bx = startX + col * (btnW + btnSpacing)
        local by = startY + row * (btnH + btnSpacing)
        local hover = mx >= bx and mx <= bx + btnW and my >= by and my <= by + btnH

        love.graphics.setColor(hover and {0.25, 0.32, 0.38} or {0.15, 0.18, 0.22})
        love.graphics.rectangle("fill", bx, by, btnW, btnH, 6, 6)

        -- Icon
        love.graphics.setFont(getFont(20))
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(btn.icon, bx + 12, by + 8)

        -- Name
        love.graphics.setFont(getFont(14))
        love.graphics.setColor(0.95, 0.95, 0.95)
        love.graphics.print(btn.name, bx + 45, by + 8)

        -- Description
        love.graphics.setFont(getFont(9))
        love.graphics.setColor(0.6, 0.65, 0.7)
        love.graphics.printf(btn.desc, bx + 45, by + 30, btnW - 55, "left")
    end

    -- Party status sidebar
    local sideX = x + w - 160
    local sideY = y + 10
    love.graphics.setColor(0.1, 0.1, 0.12, 0.9)
    love.graphics.rectangle("fill", sideX, sideY, 150, 20 + #party * 45 + 50, 5, 5)

    love.graphics.setColor(0.8, 0.8, 0.9)
    love.graphics.setFont(getFont(10))
    love.graphics.printf("Party Status", sideX, sideY + 5, 150, "center")

    -- Player
    local py = sideY + 25
    love.graphics.setColor(0.3, 0.9, 0.4)
    love.graphics.setFont(getFont(10))
    love.graphics.print("You", sideX + 10, py)
    local hpPct = state.player.hp / state.player.maxHP
    love.graphics.setColor(0.2, 0.2, 0.25)
    love.graphics.rectangle("fill", sideX + 10, py + 14, 130, 8, 2, 2)
    love.graphics.setColor(hpPct > 0.5 and {0.3, 0.8, 0.3} or (hpPct > 0.25 and {0.8, 0.8, 0.3} or {0.8, 0.3, 0.3}))
    love.graphics.rectangle("fill", sideX + 10, py + 14, 130 * hpPct, 8, 2, 2)
    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(getFont(7))
    love.graphics.print((state.player.hp or 0) .. "/" .. (state.player.maxHP or 1), sideX + 12, py + 24)

    -- Party members
    for i, comp in ipairs(party) do
        local cy = py + 40 + (i - 1) * 45
        local isDead = comp.hp <= 0
        love.graphics.setColor(isDead and {0.5, 0.5, 0.5} or {0.6, 0.8, 1})
        love.graphics.setFont(getFont(10))
        love.graphics.print(comp.name, sideX + 10, cy)

        local compHpPct = math.max(0, comp.hp / comp.maxHP)
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", sideX + 10, cy + 14, 130, 8, 2, 2)
        if not isDead then
            love.graphics.setColor(compHpPct > 0.5 and {0.3, 0.8, 0.3} or (compHpPct > 0.25 and {0.8, 0.8, 0.3} or {0.8, 0.3, 0.3}))
            love.graphics.rectangle("fill", sideX + 10, cy + 14, 130 * compHpPct, 8, 2, 2)
        end
        love.graphics.setColor(0.6, 0.6, 0.7)
        love.graphics.setFont(getFont(7))
        love.graphics.print(comp.hp .. "/" .. comp.maxHP, sideX + 12, cy + 24)
    end
end

M.drawCampCooking = function(x, y, w, h, mx, my)
    local CAMP_FOODS = F.CAMP_FOODS or {}
    local canCookRecipe = F.canCookRecipe or function() return false, {} end
    local getTQInventory = F.getTQInventory

    love.graphics.setColor(0.9, 0.75, 0.3)
    love.graphics.setFont(getFont(18))
    love.graphics.printf("🍳 Camp Cooking", x, y + 5, w, "center")

    if not state.camping.campfireLit then
        love.graphics.setColor(0.9, 0.5, 0.3)
        love.graphics.setFont(getFont(14))
        love.graphics.printf("Light the campfire first to cook!", x, y + 60, w, "center")

        -- Back button
        local backX = x + w / 2 - 60
        local backY = y + 100
        local backHover = mx >= backX and mx <= backX + 120 and my >= backY and my <= backY + 35
        love.graphics.setColor(backHover and {0.3, 0.35, 0.4} or {0.2, 0.22, 0.28})
        love.graphics.rectangle("fill", backX, backY, 120, 35, 5, 5)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(12))
        love.graphics.printf("Back", backX, backY + 10, 120, "center")
        return
    end

    -- Recipe list
    local recipeY = y + 40
    local recipeH = 55
    local inventory = getTQInventory and getTQInventory() or {}

    for i, recipe in ipairs(CAMP_FOODS) do
        local ry = recipeY + (i - 1) * (recipeH + 8)
        if ry + recipeH > y + h - 50 then break end

        local canCook, missingIng = canCookRecipe(recipe)
        local hover = mx >= x + 20 and mx <= x + w - 40 and my >= ry and my <= ry + recipeH

        -- Background
        if canCook then
            love.graphics.setColor(hover and {0.25, 0.35, 0.3} or {0.15, 0.22, 0.18})
        else
            love.graphics.setColor(0.15, 0.15, 0.15, 0.7)
        end
        love.graphics.rectangle("fill", x + 20, ry, w - 60, recipeH, 5, 5)

        -- Name and description
        love.graphics.setColor(canCook and {1, 0.95, 0.8} or {0.5, 0.5, 0.5})
        love.graphics.setFont(getFont(13))
        love.graphics.print(recipe.name, x + 30, ry + 6)

        love.graphics.setColor(canCook and {0.7, 0.7, 0.75} or {0.4, 0.4, 0.4})
        love.graphics.setFont(getFont(9))
        love.graphics.printf(recipe.desc, x + 30, ry + 24, w - 120, "left")

        -- Ingredients
        local ingStr = "Needs: "
        for j, ing in ipairs(recipe.ingredients) do
            if j > 1 then ingStr = ingStr .. ", " end
            ingStr = ingStr .. ing.id .. " x" .. ing.qty
        end
        love.graphics.setColor(canCook and {0.5, 0.8, 0.5} or {0.8, 0.5, 0.5})
        love.graphics.setFont(getFont(8))
        love.graphics.printf(ingStr, x + 30, ry + 40, w - 80, "left")

        -- Cook button
        if canCook then
            local cookX = x + w - 100
            local cookHover = mx >= cookX and mx <= cookX + 50 and my >= ry + 10 and my <= ry + 40
            love.graphics.setColor(cookHover and {0.4, 0.5, 0.35} or {0.3, 0.38, 0.28})
            love.graphics.rectangle("fill", cookX, ry + 10, 50, 30, 4, 4)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(getFont(10))
            love.graphics.printf("Cook", cookX, ry + 18, 50, "center")
        end
    end

    -- Back button
    local backX = x + 20
    local backY = y + h - 45
    local backHover = mx >= backX and mx <= backX + 100 and my >= backY and my <= backY + 35
    love.graphics.setColor(backHover and {0.35, 0.3, 0.4} or {0.22, 0.2, 0.28})
    love.graphics.rectangle("fill", backX, backY, 100, 35, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Back", backX, backY + 10, 100, "center")
end

M.drawCampChat = function(x, y, w, h, mx, my, party)
    local CAMP_CHAT_TOPICS = F.CAMP_CHAT_TOPICS or {}

    love.graphics.setColor(0.7, 0.85, 0.95)
    love.graphics.setFont(getFont(18))
    love.graphics.printf("💬 Campfire Chat", x, y + 5, w, "center")

    if #party == 0 then
        love.graphics.setColor(0.6, 0.6, 0.7)
        love.graphics.setFont(getFont(12))
        love.graphics.printf("You sit alone by the fire, lost in thought...", x, y + 60, w, "center")
    else
        -- Topic buttons
        local topicY = y + 40
        local topicW = 160
        local topicH = 45

        for i, topic in ipairs(CAMP_CHAT_TOPICS) do
            local col = (i - 1) % 2
            local row = math.floor((i - 1) / 2)
            local tx = x + 30 + col * (topicW + 15)
            local ty = topicY + row * (topicH + 10)
            local hover = mx >= tx and mx <= tx + topicW and my >= ty and my <= ty + topicH

            love.graphics.setColor(hover and {0.25, 0.32, 0.4} or {0.15, 0.2, 0.28})
            love.graphics.rectangle("fill", tx, ty, topicW, topicH, 5, 5)

            love.graphics.setFont(getFont(16))
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(topic.icon, tx + 10, ty + 8)

            love.graphics.setFont(getFont(11))
            love.graphics.setColor(0.9, 0.9, 0.95)
            love.graphics.print(topic.name, tx + 35, ty + 14)
        end

        -- Chat history
        local histY = topicY + 120
        love.graphics.setColor(0.1, 0.1, 0.12, 0.8)
        love.graphics.rectangle("fill", x + 20, histY, w - 60, h - 200, 5, 5)

        love.graphics.setColor(0.6, 0.6, 0.7)
        love.graphics.setFont(getFont(9))
        love.graphics.print("Recent conversations:", x + 30, histY + 5)

        local chatLog = state.camping.chatHistory or {}
        local logStart = math.max(1, #chatLog - 4)
        for i = logStart, #chatLog do
            local entry = chatLog[i]
            local ly = histY + 20 + (i - logStart) * 22
            love.graphics.setColor(0.5, 0.7, 0.9)
            love.graphics.setFont(getFont(9))
            love.graphics.print(entry.speaker .. ":", x + 30, ly)
            love.graphics.setColor(0.8, 0.8, 0.85)
            love.graphics.printf("\"" .. entry.line .. "\"", x + 100, ly, w - 140, "left")
        end
    end

    -- Back button
    local backX = x + 20
    local backY = y + h - 45
    local backHover = mx >= backX and mx <= backX + 100 and my >= backY and my <= backY + 35
    love.graphics.setColor(backHover and {0.35, 0.3, 0.4} or {0.22, 0.2, 0.28})
    love.graphics.rectangle("fill", backX, backY, 100, 35, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Back", backX, backY + 10, 100, "center")
end

M.drawCampRest = function(x, y, w, h, mx, my)
    local getAmbushChance = F.getAmbushChance or function() return 0 end

    love.graphics.setColor(0.7, 0.8, 0.95)
    love.graphics.setFont(getFont(18))
    love.graphics.printf("💤 Rest", x, y + 5, w, "center")

    local shelter = state.camping.type or {name = "Camp", quality = 0.5}
    local qualityPct = math.floor(shelter.quality * 100)

    -- Shelter info
    love.graphics.setColor(0.6, 0.8, 0.6)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Shelter: " .. shelter.name .. " (Quality: " .. qualityPct .. "%)", x, y + 35, w, "center")

    -- Guard warning
    local hasGuard = state.camping.guard ~= nil
    local guardIsPlayer = state.camping.guard == "player"

    if guardIsPlayer then
        love.graphics.setColor(0.9, 0.6, 0.3)
        love.graphics.setFont(getFont(11))
        love.graphics.printf("You can't rest while keeping watch! Assign another guard first.", x + 20, y + 60, w - 40, "center")
    elseif not hasGuard then
        local ambushChance = getAmbushChance(4) * 100
        love.graphics.setColor(0.95, 0.4, 0.3)
        love.graphics.setFont(getFont(11))
        love.graphics.printf("WARNING: No guard! " .. math.floor(ambushChance) .. "% chance of ambush during sleep!", x + 20, y + 60, w - 40, "center")
    else
        love.graphics.setColor(0.4, 0.9, 0.4)
        love.graphics.setFont(getFont(11))
        love.graphics.printf(state.camping.guard .. " is keeping watch. Safe to rest.", x + 20, y + 60, w - 40, "center")
    end

    -- Rest options
    local restY = y + 95
    local restOptions = {
        {hours = 2, label = "Short Rest (2 hours)"},
        {hours = 4, label = "Rest (4 hours)"},
        {hours = 8, label = "Full Rest (8 hours)"},
    }

    for i, opt in ipairs(restOptions) do
        local ry = restY + (i - 1) * 50
        local canRest = not guardIsPlayer
        local hover = canRest and mx >= x + 60 and mx <= x + w - 80 and my >= ry and my <= ry + 42

        -- Background
        if canRest then
            love.graphics.setColor(hover and {0.25, 0.35, 0.32} or {0.15, 0.22, 0.2})
        else
            love.graphics.setColor(0.15, 0.15, 0.15, 0.6)
        end
        love.graphics.rectangle("fill", x + 60, ry, w - 140, 42, 5, 5)

        -- Label
        love.graphics.setColor(canRest and {0.95, 0.95, 0.95} or {0.5, 0.5, 0.5})
        love.graphics.setFont(getFont(13))
        love.graphics.print(opt.label, x + 75, ry + 6)

        -- Healing estimate
        local healEst = math.floor(opt.hours * 3 * shelter.quality)
        local manaEst = math.floor(opt.hours * 2 * shelter.quality)
        love.graphics.setColor(canRest and {0.5, 0.85, 0.5} or {0.4, 0.4, 0.4})
        love.graphics.setFont(getFont(10))
        love.graphics.print("+" .. healEst .. " HP, +" .. manaEst .. " Mana", x + 75, ry + 25)

        -- Ambush chance for this duration
        if not hasGuard and canRest then
            local chance = getAmbushChance(opt.hours) * 100
            love.graphics.setColor(0.9, 0.5, 0.4)
            love.graphics.setFont(getFont(9))
            love.graphics.printf("Risk: " .. math.floor(chance) .. "%", x + 60, ry + 14, w - 160, "right")
        end
    end

    -- Back button
    local backX = x + 20
    local backY = y + h - 45
    local backHover = mx >= backX and mx <= backX + 100 and my >= backY and my <= backY + 35
    love.graphics.setColor(backHover and {0.35, 0.3, 0.4} or {0.22, 0.2, 0.28})
    love.graphics.rectangle("fill", backX, backY, 100, 35, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Back", backX, backY + 10, 100, "center")
end

M.drawCampGuard = function(x, y, w, h, mx, my, party)
    love.graphics.setColor(0.8, 0.75, 0.9)
    love.graphics.setFont(getFont(18))
    love.graphics.printf("👁 Set Guard", x, y + 5, w, "center")

    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(getFont(10))
    love.graphics.printf("A guard prevents ambushes but cannot rest.", x, y + 32, w, "center")

    local guardY = y + 60
    local guardH = 50
    local currentGuard = state.camping.guard

    -- Player option
    local pHover = mx >= x + 40 and mx <= x + w - 60 and my >= guardY and my <= guardY + guardH
    local isPlayerGuard = currentGuard == "player"
    love.graphics.setColor(isPlayerGuard and {0.25, 0.4, 0.35} or (pHover and {0.25, 0.32, 0.38} or {0.15, 0.2, 0.25}))
    love.graphics.rectangle("fill", x + 40, guardY, w - 100, guardH, 5, 5)

    love.graphics.setFont(getFont(14))
    love.graphics.setColor(isPlayerGuard and {0.4, 1, 0.5} or {0.9, 0.9, 0.9})
    love.graphics.print("You", x + 60, guardY + 8)

    love.graphics.setFont(getFont(9))
    love.graphics.setColor(0.6, 0.65, 0.7)
    love.graphics.print("Take watch yourself (can't rest)", x + 60, guardY + 28)

    if isPlayerGuard then
        love.graphics.setColor(0.4, 0.9, 0.4)
        love.graphics.setFont(getFont(10))
        love.graphics.printf("ON DUTY", x + 40, guardY + 18, w - 120, "right")
    end

    -- Party members
    for i, comp in ipairs(party) do
        local cy = guardY + guardH + 10 + (i - 1) * (guardH + 8)
        local isDead = comp.hp <= 0
        local isGuard = currentGuard == comp.name
        local cHover = not isDead and mx >= x + 40 and mx <= x + w - 60 and my >= cy and my <= cy + guardH

        if isDead then
            love.graphics.setColor(0.12, 0.12, 0.12, 0.6)
        elseif isGuard then
            love.graphics.setColor(0.25, 0.4, 0.35)
        else
            love.graphics.setColor(cHover and {0.25, 0.32, 0.38} or {0.15, 0.2, 0.25})
        end
        love.graphics.rectangle("fill", x + 40, cy, w - 100, guardH, 5, 5)

        love.graphics.setFont(getFont(14))
        love.graphics.setColor(isDead and {0.4, 0.4, 0.4} or (isGuard and {0.4, 1, 0.5} or {0.7, 0.85, 1}))
        love.graphics.print(comp.name, x + 60, cy + 8)

        love.graphics.setFont(getFont(9))
        love.graphics.setColor(0.6, 0.65, 0.7)
        if isDead then
            love.graphics.print("Incapacitated - cannot keep watch", x + 60, cy + 28)
        else
            love.graphics.print("HP: " .. comp.hp .. "/" .. comp.maxHP, x + 60, cy + 28)
        end

        if isGuard then
            love.graphics.setColor(0.4, 0.9, 0.4)
            love.graphics.setFont(getFont(10))
            love.graphics.printf("ON DUTY", x + 40, cy + 18, w - 120, "right")
        end
    end

    -- Remove guard option (if guard is set)
    if currentGuard then
        local removeY = guardY + guardH + 10 + #party * (guardH + 8) + 15
        local removeHover = mx >= x + 40 and mx <= x + w - 60 and my >= removeY and my <= removeY + 40
        love.graphics.setColor(removeHover and {0.45, 0.3, 0.25} or {0.3, 0.22, 0.18})
        love.graphics.rectangle("fill", x + 40, removeY, w - 100, 40, 5, 5)
        love.graphics.setColor(1, 0.8, 0.7)
        love.graphics.setFont(getFont(12))
        love.graphics.printf("Remove Guard (risky!)", x + 40, removeY + 12, w - 100, "center")
    end

    -- Back button
    local backX = x + 20
    local backY = y + h - 45
    local backHover = mx >= backX and mx <= backX + 100 and my >= backY and my <= backY + 35
    love.graphics.setColor(backHover and {0.35, 0.3, 0.4} or {0.22, 0.2, 0.28})
    love.graphics.rectangle("fill", backX, backY, 100, 35, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Back", backX, backY + 10, 100, "center")
end

M.drawResting = function(x, y, w, h, mx, my)
    local getCurrentWeather = F.getCurrentWeather or function() return "pleasant" end
    local WEATHER_EFFECTS = F.WEATHER_EFFECTS or {}

    local weather = getCurrentWeather()
    local weatherFx = WEATHER_EFFECTS[weather] or WEATHER_EFFECTS.pleasant or {color = {0.7,0.7,0.7}, icon = "?", name = "Unknown"}
    local shelter = state.camping.type or {name = "Shelter", quality = 0.5}

    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(20))
    love.graphics.printf("Resting at Camp", x, y + 5, w, "center")

    -- Current shelter
    love.graphics.setColor(0.6, 0.8, 0.6)
    love.graphics.setFont(getFont(14))
    love.graphics.printf("Shelter: " .. shelter.name, x, y + 35, w, "center")

    -- Weather
    love.graphics.setColor(weatherFx.color)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Outside: " .. weatherFx.icon .. " " .. weatherFx.name, x, y + 55, w, "center")

    -- Shelter quality
    local qualityPct = math.floor(shelter.quality * 100)
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.setFont(getFont(11))
    love.graphics.printf("Rest quality: " .. qualityPct .. "% (affects HP/Mana recovery)", x, y + 75, w, "center")

    -- Status info
    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(getFont(10))
    if state.camping.hoursRested and state.camping.hoursRested > 0 then
        love.graphics.printf("Rested: " .. state.camping.hoursRested .. " hours", x, y + 95, w, "center")
    end

    -- Rest options
    local menuX = x + w / 2 - 120
    local menuY = y + 120

    local restOptions = {
        {hours = 2, label = "Short Rest (2 hours)", desc = "Quick recovery"},
        {hours = 4, label = "Rest (4 hours)", desc = "Good recovery"},
        {hours = 8, label = "Full Rest (8 hours)", desc = "Full recovery"},
    }

    for i, opt in ipairs(restOptions) do
        local optY = menuY + (i - 1) * 45
        local hover = mx >= menuX and mx <= menuX + 240 and my >= optY and my <= optY + 38

        love.graphics.setColor(hover and {0.25, 0.35, 0.3} or {0.15, 0.2, 0.18})
        love.graphics.rectangle("fill", menuX, optY, 240, 38, 5, 5)

        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.setFont(getFont(12))
        love.graphics.print(opt.label, menuX + 10, optY + 5)

        -- Healing estimate
        local healEst = math.floor(opt.hours * 3 * shelter.quality)
        local manaEst = math.floor(opt.hours * 2 * shelter.quality)
        love.graphics.setColor(0.5, 0.8, 0.5)
        love.graphics.setFont(getFont(9))
        love.graphics.print("+" .. healEst .. " HP, +" .. manaEst .. " Mana", menuX + 10, optY + 22)
    end

    -- Break camp button
    local breakY = menuY + 160
    local breakHover = mx >= menuX and mx <= menuX + 240 and my >= breakY and my <= breakY + 38
    love.graphics.setColor(breakHover and {0.5, 0.35, 0.25} or {0.35, 0.25, 0.2})
    love.graphics.rectangle("fill", menuX, breakY, 240, 38, 5, 5)
    love.graphics.setColor(1, 0.9, 0.8)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Break Camp & Continue", menuX, breakY + 12, 240, "center")
end

-- ============================================================================
-- TRAVEL DRAWS
-- ============================================================================

M.drawTravelingHome = function(x, y, w, h, mx, my)
    local home = state.world.homeTown
    if not home then return end

    -- Title
    love.graphics.setColor(0.9, 0.8, 0.3)
    love.graphics.setFont(getFont(20))
    love.graphics.printf("Traveling Home...", x, y + 10, w, "center")

    -- Destination
    love.graphics.setColor(0.7, 0.9, 0.7)
    love.graphics.setFont(getFont(14))
    love.graphics.printf("Destination: " .. home.town.name, x, y + 40, w, "center")

    -- Progress bar
    local travel = state.travelingHome
    local progress = travel.totalSteps > 0 and (travel.currentStep / travel.totalSteps) or 0
    local barW = w - 100
    local barH = 25
    local barX = x + 50
    local barY = y + 80

    love.graphics.setColor(0.15, 0.15, 0.2)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 5, 5)
    love.graphics.setColor(0.3, 0.6, 0.4)
    love.graphics.rectangle("fill", barX, barY, barW * progress, barH, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(12))
    love.graphics.printf(travel.currentStep .. " / " .. travel.totalSteps .. " tiles", barX, barY + 5, barW, "center")

    -- Draw mini map showing path
    local mapSize = math.min(w - 40, h - 180)
    local mapX = x + (w - mapSize) / 2
    local mapY = y + 130

    love.graphics.setColor(0.08, 0.1, 0.12)
    love.graphics.rectangle("fill", mapX, mapY, mapSize, mapSize, 8, 8)

    local minPX, maxPX, minPY, maxPY = state.world.playerX, state.world.playerX, state.world.playerY, state.world.playerY
    if home then
        minPX, maxPX = math.min(minPX, home.x), math.max(maxPX, home.x)
        minPY, maxPY = math.min(minPY, home.y), math.max(maxPY, home.y)
    end
    for _, pos in ipairs(state.world.pathHistory) do
        minPX, maxPX = math.min(minPX, pos.x), math.max(maxPX, pos.x)
        minPY, maxPY = math.min(minPY, pos.y), math.max(maxPY, pos.y)
    end

    local rangeX = math.max(maxPX - minPX + 1, 5)
    local rangeY = math.max(maxPY - minPY + 1, 5)
    local cellSize = math.min((mapSize - 20) / rangeX, (mapSize - 20) / rangeY)
    local offsetX = mapX + (mapSize - rangeX * cellSize) / 2
    local offsetY = mapY + (mapSize - rangeY * cellSize) / 2

    love.graphics.setColor(0.3, 0.3, 0.4)
    for _, pos in ipairs(state.world.pathHistory) do
        local px = offsetX + (pos.x - minPX) * cellSize
        local py = offsetY + (pos.y - minPY) * cellSize
        love.graphics.rectangle("fill", px + 2, py + 2, cellSize - 4, cellSize - 4, 3, 3)
    end

    love.graphics.setColor(0.3, 0.8, 0.4)
    local homeDrawX = offsetX + (home.x - minPX) * cellSize
    local homeDrawY = offsetY + (home.y - minPY) * cellSize
    love.graphics.rectangle("fill", homeDrawX + 1, homeDrawY + 1, cellSize - 2, cellSize - 2, 3, 3)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(math.max(8, cellSize * 0.6)))
    love.graphics.printf("H", homeDrawX, homeDrawY + cellSize * 0.15, cellSize, "center")

    local pulse = 0.7 + 0.3 * math.sin(love.timer.getTime() * 5)
    love.graphics.setColor(0.2 * pulse, 0.9 * pulse, 0.3 * pulse)
    local playerDrawX = offsetX + (state.world.playerX - minPX) * cellSize
    local playerDrawY = offsetY + (state.world.playerY - minPY) * cellSize
    love.graphics.rectangle("fill", playerDrawX, playerDrawY, cellSize, cellSize, 3, 3)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("@", playerDrawX, playerDrawY + cellSize * 0.1, cellSize, "center")

    local cancelX = x + w / 2 - 80
    local cancelY = y + h - 50
    local cancelHover = mx >= cancelX and mx <= cancelX + 160 and my >= cancelY and my <= cancelY + 35
    love.graphics.setColor(cancelHover and {0.5, 0.3, 0.3} or {0.35, 0.2, 0.2})
    love.graphics.rectangle("fill", cancelX, cancelY, 160, 35, 5, 5)
    love.graphics.setColor(1, 0.9, 0.8)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Stop & Explore", cancelX, cancelY + 10, 160, "center")
end

M.drawPaidTravel = function(x, y, w, h, mx, my)
    local travel = state.paidTravel
    if not travel or not travel.destination then return end

    love.graphics.setColor(0.5, 0.7, 0.9)
    love.graphics.setFont(getFont(20))
    love.graphics.printf("Carriage Travel", x, y + 10, w, "center")

    love.graphics.setColor(0.9, 0.9, 0.7)
    love.graphics.setFont(getFont(14))
    love.graphics.printf("Destination: " .. travel.destination.name, x, y + 40, w, "center")

    local regionName = travel.destination.region and travel.destination.region:gsub("_", " "):gsub("(%a)([%w_']*)", function(a, b) return string.upper(a) .. b end) or "Unknown"
    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(getFont(11))
    love.graphics.printf(regionName, x, y + 58, w, "center")

    local progress = travel.totalSteps > 0 and (travel.currentStep / travel.totalSteps) or 0
    local barW = w - 100
    local barH = 25
    local barX = x + 50
    local barY = y + 90

    love.graphics.setColor(0.15, 0.15, 0.2)
    love.graphics.rectangle("fill", barX, barY, barW, barH, 5, 5)
    love.graphics.setColor(0.3, 0.5, 0.7)
    love.graphics.rectangle("fill", barX, barY, barW * progress, barH, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(12))
    love.graphics.printf(travel.currentStep .. " / " .. travel.totalSteps .. " tiles", barX, barY + 5, barW, "center")

    local mapSize = math.min(w - 40, h - 200)
    local mapX = x + (w - mapSize) / 2
    local mapY = y + 140

    love.graphics.setColor(0.08, 0.1, 0.12)
    love.graphics.rectangle("fill", mapX, mapY, mapSize, mapSize, 8, 8)

    local minPX = math.min(travel.startX, travel.destX)
    local maxPX = math.max(travel.startX, travel.destX)
    local minPY = math.min(travel.startY, travel.destY)
    local maxPY = math.max(travel.startY, travel.destY)

    local rangeX = math.max(maxPX - minPX + 1, 5)
    local rangeY = math.max(maxPY - minPY + 1, 5)
    local cellSize = math.min((mapSize - 20) / rangeX, (mapSize - 20) / rangeY)
    local offsetX = mapX + (mapSize - rangeX * cellSize) / 2
    local offsetY = mapY + (mapSize - rangeY * cellSize) / 2

    love.graphics.setColor(0.4, 0.35, 0.3)
    local startDrawX = offsetX + (travel.startX - minPX) * cellSize + cellSize / 2
    local startDrawY = offsetY + (travel.startY - minPY) * cellSize + cellSize / 2
    local destDrawX = offsetX + (travel.destX - minPX) * cellSize + cellSize / 2
    local destDrawY = offsetY + (travel.destY - minPY) * cellSize + cellSize / 2
    love.graphics.setLineWidth(3)
    love.graphics.line(startDrawX, startDrawY, destDrawX, destDrawY)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(0.6, 0.6, 0.5)
    local startPosX = offsetX + (travel.startX - minPX) * cellSize
    local startPosY = offsetY + (travel.startY - minPY) * cellSize
    love.graphics.rectangle("fill", startPosX + 2, startPosY + 2, cellSize - 4, cellSize - 4, 3, 3)

    love.graphics.setColor(0.4, 0.7, 0.9)
    local destPosX = offsetX + (travel.destX - minPX) * cellSize
    local destPosY = offsetY + (travel.destY - minPY) * cellSize
    love.graphics.rectangle("fill", destPosX + 1, destPosY + 1, cellSize - 2, cellSize - 2, 3, 3)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(math.max(8, cellSize * 0.5)))
    love.graphics.printf("D", destPosX, destPosY + cellSize * 0.2, cellSize, "center")

    local pulse = 0.7 + 0.3 * math.sin(love.timer.getTime() * 5)
    love.graphics.setColor(0.9 * pulse, 0.8 * pulse, 0.3 * pulse)
    local playerDrawX = offsetX + (state.world.playerX - minPX) * cellSize
    local playerDrawY = offsetY + (state.world.playerY - minPY) * cellSize
    love.graphics.rectangle("fill", playerDrawX, playerDrawY, cellSize, cellSize, 3, 3)
    love.graphics.setColor(0.3, 0.2, 0.1)
    love.graphics.setFont(getFont(math.max(8, cellSize * 0.6)))
    love.graphics.printf("C", playerDrawX, playerDrawY + cellSize * 0.15, cellSize, "center")

    love.graphics.setColor(0.4, 0.6, 0.4)
    love.graphics.setFont(getFont(10))
    love.graphics.printf("Protected carriage - 90% safer than walking!", x, y + h - 80, w, "center")

    local cancelX = x + w / 2 - 80
    local cancelY = y + h - 50
    local cancelHover = mx >= cancelX and mx <= cancelX + 160 and my >= cancelY and my <= cancelY + 35
    love.graphics.setColor(cancelHover and {0.5, 0.35, 0.3} or {0.35, 0.25, 0.2})
    love.graphics.rectangle("fill", cancelX, cancelY, 160, 35, 5, 5)
    love.graphics.setColor(1, 0.9, 0.8)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Leave Carriage", cancelX, cancelY + 10, 160, "center")

    state.paidTravelCancelBtn = {x = cancelX, y = cancelY, w = 160, h = 35}
end

-- ============================================================================
-- DISTRICT / COMPASS DRAWS
-- ============================================================================

M.drawDistrict = function(x, y, w, h, mx, my)
    if not state.currentDistrict or not state.currentDistrict.def then
        state.phase = "town"
        return
    end
    local district = state.currentDistrict.def

    love.graphics.setColor(0.9, 0.8, 0.3)
    love.graphics.setFont(getFont(20))
    love.graphics.printf(district.name, x, y + 10, w, "center")

    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.setFont(getFont(11))
    love.graphics.printf(district.description, x + 20, y + 40, w - 40, "center")

    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(getFont(10))
    local dangerColors = {{0.3,0.8,0.3}, {0.5,0.8,0.3}, {0.8,0.8,0.3}, {0.8,0.5,0.3}, {0.8,0.3,0.3}}
    local dColor = dangerColors[math.min(5, (district.dangerLevel or 0) + 1)]
    love.graphics.printf("Atmosphere: " .. (district.atmosphere or "unknown"), x + 20, y + 75, w/2 - 20, "left")
    love.graphics.setColor(dColor)
    love.graphics.printf("Danger: " .. string.rep("|", math.max(1, district.dangerLevel or 0)), x + w/2, y + 75, w/2 - 20, "right")

    local getDistrictOptions = F.getDistrictOptions or function() return {} end
    local opts = getDistrictOptions()
    local optY = y + 110
    love.graphics.setFont(getFont(13))
    for i, opt in ipairs(opts) do
        local optH = 30
        local hover = mx >= x + 30 and mx <= x + w - 30 and my >= optY and my <= optY + optH
        love.graphics.setColor(hover and {0.25, 0.28, 0.35} or {0.15, 0.17, 0.22})
        love.graphics.rectangle("fill", x + 30, optY, w - 60, optH, 4, 4)
        love.graphics.setColor(hover and {1, 0.9, 0.6} or {0.8, 0.8, 0.9})
        love.graphics.printf(opt.text, x + 40, optY + 7, w - 80, "left")
        state.districtButtons = state.districtButtons or {}
        state.districtButtons[i] = {x = x + 30, y = optY, w = w - 60, h = optH, action = opt.action}
        optY = optY + optH + 5
    end
end

M.drawGuildHall = function(x, y, w, h, mx, my)
    if not state.currentGuildHall or not state.currentGuildHall.data then
        state.phase = "town"
        return
    end
    local guild = state.currentGuildHall.data

    love.graphics.setColor(guild.color or {0.7, 0.7, 0.8})
    love.graphics.setFont(getFont(20))
    love.graphics.printf(guild.name, x, y + 10, w, "center")

    love.graphics.setColor(0.6, 0.6, 0.5)
    love.graphics.setFont(getFont(11))
    love.graphics.printf("\"" .. guild.motto .. "\"", x + 20, y + 38, w - 40, "center")

    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.setFont(getFont(10))
    love.graphics.printf(guild.description, x + 20, y + 58, w - 40, "center")

    local getGuildHallOptions = F.getGuildHallOptions or function() return {} end
    local opts = getGuildHallOptions()
    local optY = y + 100
    love.graphics.setFont(getFont(13))
    state.guildButtons = {}
    for i, opt in ipairs(opts) do
        local optH = 30
        local hover = mx >= x + 30 and mx <= x + w - 30 and my >= optY and my <= optY + optH
        love.graphics.setColor(hover and {0.25, 0.28, 0.35} or {0.15, 0.17, 0.22})
        love.graphics.rectangle("fill", x + 30, optY, w - 60, optH, 4, 4)
        local textColor = opt.color or (hover and {1, 0.9, 0.6} or {0.8, 0.8, 0.9})
        love.graphics.setColor(textColor)
        love.graphics.printf(opt.text, x + 40, optY + 7, w - 80, "left")
        state.guildButtons[i] = {x = x + 30, y = optY, w = w - 60, h = optH, action = opt.action}
        optY = optY + optH + 5
    end
end

M.drawUnderbelly = function(x, y, w, h, mx, my)
    if not state.currentUnderbelly or not state.currentUnderbelly.def then
        state.phase = "town"
        return
    end
    local ub = state.currentUnderbelly
    local def = ub.def

    local dangerColors = {{0.5,0.7,0.5}, {0.6,0.7,0.4}, {0.7,0.7,0.3}, {0.8,0.6,0.3}, {0.9,0.4,0.3}}
    local dColor = dangerColors[math.min(5, (def.dangerLevel or 0) + 1)]
    love.graphics.setColor(dColor)
    love.graphics.setFont(getFont(20))
    love.graphics.printf(def.name, x, y + 10, w, "center")

    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Floor " .. ub.floor .. " / " .. ub.maxFloors, x, y + 36, w, "center")

    love.graphics.setFont(getFont(10))
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.printf("Enemies defeated: " .. ub.enemiesDefeated .. "  |  Items found: " .. #ub.lootFound .. "  |  Boss: " .. (ub.bossDefeated and "DEFEATED" or "ALIVE"), x + 20, y + 55, w - 40, "center")

    local hpPct = (state.player.hp or 1) / (state.player.maxHp or state.player.maxHP or 1)
    love.graphics.setColor(0.2, 0.2, 0.25)
    love.graphics.rectangle("fill", x + 40, y + 75, w - 80, 12, 3, 3)
    love.graphics.setColor(hpPct > 0.5 and {0.3, 0.7, 0.3} or (hpPct > 0.25 and {0.7, 0.7, 0.3} or {0.7, 0.3, 0.3}))
    love.graphics.rectangle("fill", x + 40, y + 75, (w - 80) * hpPct, 12, 3, 3)
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.setFont(getFont(9))
    love.graphics.printf("HP: " .. state.player.hp .. "/" .. (state.player.maxHp or state.player.maxHP), x + 40, y + 76, w - 80, "center")

    local getUnderbellyOptions = F.getUnderbellyOptions or function() return {} end
    local opts = getUnderbellyOptions()
    local optY = y + 100
    love.graphics.setFont(getFont(13))
    state.underbellyButtons = {}
    for i, opt in ipairs(opts) do
        local optH = 30
        local hover = mx >= x + 30 and mx <= x + w - 30 and my >= optY and my <= optY + optH
        love.graphics.setColor(hover and {0.25, 0.28, 0.35} or {0.15, 0.17, 0.22})
        love.graphics.rectangle("fill", x + 30, optY, w - 60, optH, 4, 4)
        local textColor = opt.color or (hover and {1, 0.9, 0.6} or {0.8, 0.8, 0.9})
        love.graphics.setColor(textColor)
        love.graphics.printf(opt.text, x + 40, optY + 7, w - 80, "left")
        state.underbellyButtons[i] = {x = x + 30, y = optY, w = w - 60, h = optH, action = opt.action}
        optY = optY + optH + 5
    end
end

M.drawBountyBoard = function(x, y, w, h, mx, my)
    local town = state.world and state.world.currentTown
    if not town or not town.bountyBoard then
        state.phase = "town"
        return
    end

    love.graphics.setColor(0.9, 0.6, 0.3)
    love.graphics.setFont(getFont(20))
    love.graphics.printf("BOUNTY BOARD", x, y + 10, w, "center")

    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(getFont(10))
    love.graphics.printf("Wanted criminals. Capture alive for full reward, proof of death for half.", x + 20, y + 38, w - 40, "center")

    local bountyY = y + 65
    love.graphics.setFont(getFont(12))
    state.bountyButtons = {}
    for i, bounty in ipairs(town.bountyBoard) do
        local bH = 55
        local hover = mx >= x + 20 and mx <= x + w - 20 and my >= bountyY and my <= bountyY + bH
        love.graphics.setColor(hover and {0.25, 0.18, 0.15} or {0.15, 0.12, 0.10})
        love.graphics.rectangle("fill", x + 20, bountyY, w - 40, bH, 4, 4)
        love.graphics.setColor(0.5, 0.35, 0.2)
        love.graphics.rectangle("line", x + 20, bountyY, w - 40, bH, 4, 4)

        love.graphics.setColor(0.9, 0.5, 0.3)
        love.graphics.setFont(getFont(13))
        love.graphics.printf(bounty.name or "Unknown", x + 30, bountyY + 5, w - 60, "left")

        love.graphics.setColor(0.9, 0.8, 0.3)
        love.graphics.setFont(getFont(11))
        love.graphics.printf("Alive: " .. (bounty.bountyReward or 0) .. "g  |  Dead: " .. (bounty.bountyRewardDead or 0) .. "g", x + 30, bountyY + 22, w - 60, "left")

        love.graphics.setColor(0.6, 0.5, 0.5)
        love.graphics.setFont(getFont(9))
        love.graphics.printf("Crime: " .. (bounty.crime or "unknown") .. "  |  Danger: Level " .. (bounty.criminalLevel or "?"), x + 30, bountyY + 38, w - 60, "left")

        state.bountyButtons[i] = {x = x + 20, y = bountyY, w = w - 40, h = bH, bounty = bounty}
        bountyY = bountyY + bH + 5
    end

    local backY = bountyY + 10
    local backHover = mx >= x + 30 and mx <= x + w - 30 and my >= backY and my <= backY + 30
    love.graphics.setColor(backHover and {0.3, 0.3, 0.35} or {0.2, 0.2, 0.25})
    love.graphics.rectangle("fill", x + 30, backY, w - 60, 30, 4, 4)
    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Leave Bounty Board", x + 30, backY + 8, w - 60, "center")
    state.bountyBackBtn = {x = x + 30, y = backY, w = w - 60, h = 30}
end

M.drawCourierOffice = function(x, y, w, h, mx, my)
    local town = state.world and state.world.currentTown
    if not town or not town.courierBoard then
        state.phase = "town"
        return
    end

    love.graphics.setColor(0.4, 0.7, 0.8)
    love.graphics.setFont(getFont(20))
    love.graphics.printf("COURIER OFFICE", x, y + 10, w, "center")

    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(getFont(10))
    love.graphics.printf("Available delivery contracts. Complete them to earn gold and reputation.", x + 20, y + 38, w - 40, "center")

    local courierY = y + 65
    love.graphics.setFont(getFont(12))
    state.courierButtons = {}
    for i, courier in ipairs(town.courierBoard) do
        local cH = 50
        local hover = mx >= x + 20 and mx <= x + w - 20 and my >= courierY and my <= courierY + cH
        love.graphics.setColor(hover and {0.15, 0.22, 0.28} or {0.10, 0.15, 0.18})
        love.graphics.rectangle("fill", x + 20, courierY, w - 40, cH, 4, 4)
        love.graphics.setColor(0.3, 0.5, 0.6)
        love.graphics.rectangle("line", x + 20, courierY, w - 40, cH, 4, 4)

        love.graphics.setColor(0.5, 0.8, 0.9)
        love.graphics.setFont(getFont(12))
        love.graphics.printf(courier.name or "Delivery", x + 30, courierY + 5, w - 60, "left")

        love.graphics.setColor(0.7, 0.7, 0.8)
        love.graphics.setFont(getFont(10))
        love.graphics.printf("To: " .. (courier.targetName or "Unknown") .. " in " .. (courier.location or "Unknown"), x + 30, courierY + 22, w/2 - 40, "left")

        local urgencyColors = {Standard = {0.5,0.7,0.5}, Urgent = {0.8,0.7,0.3}, Critical = {0.9,0.4,0.3}}
        love.graphics.setColor(urgencyColors[courier.urgency or "Standard"] or {0.5,0.7,0.5})
        love.graphics.printf((courier.urgency or "Standard") .. " - " .. (courier.rewardGold or 0) .. "g", x + w/2, courierY + 22, w/2 - 40, "right")

        if courier.timeLimit then
            love.graphics.setColor(0.6, 0.5, 0.5)
            love.graphics.setFont(getFont(9))
            love.graphics.printf("Time limit: " .. courier.timeLimit .. " hours", x + 30, courierY + 36, w - 60, "left")
        end

        state.courierButtons[i] = {x = x + 20, y = courierY, w = w - 40, h = cH, courier = courier}
        courierY = courierY + cH + 5
    end

    local backY = courierY + 10
    local backHover = mx >= x + 30 and mx <= x + w - 30 and my >= backY and my <= backY + 30
    love.graphics.setColor(backHover and {0.3, 0.3, 0.35} or {0.2, 0.2, 0.25})
    love.graphics.rectangle("fill", x + 30, backY, w - 60, 30, 4, 4)
    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Leave Courier Office", x + 30, backY + 8, w - 60, "center")
    state.courierBackBtn = {x = x + 30, y = backY, w = w - 60, h = 30}
end

M.drawCompass = function(cx, cy, cw, ch)
    if not state or not state.world or not state.world.playerX then return end

    local playerX = state.world.playerX
    local playerY = state.world.playerY

    love.graphics.setColor(0.08, 0.10, 0.12, 0.92)
    love.graphics.rectangle("fill", cx, cy, cw, ch, 4, 4)
    love.graphics.setColor(0.3, 0.3, 0.4, 0.8)
    love.graphics.rectangle("line", cx, cy, cw, ch, 4, 4)

    local centerX = cx + cw / 2
    love.graphics.setColor(0.9, 0.8, 0.3, 0.6)
    love.graphics.line(centerX, cy + 2, centerX, cy + ch - 2)

    local directions = {
        {label = "N",  angle = 0,   color = {0.9, 0.8, 0.3}},
        {label = "NE", angle = 45,  color = {0.6, 0.6, 0.7}},
        {label = "E",  angle = 90,  color = {0.7, 0.7, 0.8}},
        {label = "SE", angle = 135, color = {0.6, 0.6, 0.7}},
        {label = "S",  angle = 180, color = {0.7, 0.7, 0.8}},
        {label = "SW", angle = 225, color = {0.6, 0.6, 0.7}},
        {label = "W",  angle = 270, color = {0.7, 0.7, 0.8}},
        {label = "NW", angle = 315, color = {0.6, 0.6, 0.7}},
    }

    local compassWidth = cw - 20
    love.graphics.setFont(getFont(10))
    for _, dir in ipairs(directions) do
        local normalizedPos = dir.angle / 360.0
        local dirX = cx + 10 + normalizedPos * compassWidth
        if dirX >= cx and dirX <= cx + cw then
            love.graphics.setColor(dir.color)
            love.graphics.printf(dir.label, dirX - 10, cy + 3, 20, "center")
        end
    end

    local markers = {}

    if state.player and state.player.quests then
        for _, quest in ipairs(state.player.quests) do
            if quest.accepted and not quest.completed then
                local targetX, targetY = nil, nil
                if quest.questType == "bounty" then
                    if not quest.targetX then
                        quest.targetX = playerX + math.random(-12, 12)
                        quest.targetY = playerY + math.random(-12, 12)
                    end
                    targetX, targetY = quest.targetX, quest.targetY
                elseif quest.questType == "courier" then
                    if not quest.targetX and state.world.towns then
                        for _, town in ipairs(state.world.towns) do
                            if town.name and quest.location and town.name:find(quest.location) then
                                targetX = town.x or playerX
                                targetY = town.y or playerY
                                quest.targetX = targetX
                                quest.targetY = targetY
                                break
                            end
                        end
                        if not quest.targetX and state.world.towns and #state.world.towns > 0 then
                            local t = state.world.towns[math.random(#state.world.towns)]
                            quest.targetX = t.x or (playerX + math.random(-15, 15))
                            quest.targetY = t.y or (playerY + math.random(-15, 15))
                        end
                    end
                    targetX = quest.targetX
                    targetY = quest.targetY
                end

                if targetX and targetY then
                    local dx = targetX - playerX
                    local dy = targetY - playerY
                    local dist = math.sqrt(dx * dx + dy * dy)
                    local angle = math.deg(math.atan2(dx, -dy)) % 360

                    local markerColor = {0.9, 0.4, 0.2}
                    local markerIcon = "!"
                    if quest.questType == "courier" then
                        markerColor = {0.3, 0.7, 0.9}
                        markerIcon = ">"
                    elseif quest.questType == "bounty" then
                        markerColor = {0.9, 0.3, 0.3}
                        markerIcon = "X"
                    end

                    table.insert(markers, {
                        angle = angle,
                        dist = dist,
                        color = markerColor,
                        icon = markerIcon,
                        name = quest.name,
                        isActive = (state.activeQuestIndex and state.player.quests[state.activeQuestIndex] == quest),
                    })
                end
            end
        end
    end

    if state.world.useWorldGen then
        local WorldGen = require("worldgen")
        for dx = -15, 15 do
            for dy = -15, 15 do
                local tile = WorldGen.getTile(playerX + dx, playerY + dy)
                if tile and tile.town then
                    local tdx = dx
                    local tdy = dy
                    local tdist = math.sqrt(tdx * tdx + tdy * tdy)
                    if tdist > 0 and tdist <= 15 then
                        local tangle = math.deg(math.atan2(tdx, -tdy)) % 360
                        table.insert(markers, {
                            angle = tangle,
                            dist = tdist,
                            color = {0.5, 0.8, 0.5},
                            icon = "T",
                            name = tile.town.name or "Town",
                            isActive = false,
                        })
                    end
                end
            end
        end
    end

    love.graphics.setFont(getFont(12))
    for _, marker in ipairs(markers) do
        local normalizedPos = marker.angle / 360.0
        local markerX = cx + 10 + normalizedPos * compassWidth
        if markerX >= cx + 5 and markerX <= cx + cw - 5 then
            local alpha = math.max(0.3, 1.0 - (marker.dist / 20.0))
            love.graphics.setColor(marker.color[1], marker.color[2], marker.color[3], alpha)
            love.graphics.printf(marker.icon, markerX - 6, cy + 14, 12, "center")

            if marker.isActive then
                love.graphics.setColor(1, 1, 1, 0.9)
                love.graphics.setFont(getFont(8))
                local distStr = string.format("%.0f tiles", marker.dist)
                love.graphics.printf(distStr, markerX - 20, cy + ch - 10, 40, "center")
                love.graphics.setFont(getFont(12))
            end
        end
    end

    if state.activeQuestIndex and state.player and state.player.quests then
        local activeQuest = state.player.quests[state.activeQuestIndex]
        if activeQuest and activeQuest.accepted and not activeQuest.completed and activeQuest.targetX then
            local dx = activeQuest.targetX - playerX
            local dy = activeQuest.targetY - playerY
            local dist = math.sqrt(dx * dx + dy * dy)
            local distKm = dist * 5

            love.graphics.setColor(0.9, 0.85, 0.6, 0.9)
            love.graphics.setFont(getFont(9))
            local questInfo = activeQuest.name .. " - " .. string.format("%.0f km (%.0f tiles)", distKm, dist)
            love.graphics.printf(questInfo, cx + 10, cy + ch - 12, cw - 20, "center")
        end
    end
end

M.drawMap = function(x, y, w, h, mx, my)
    local WorldGen = require("worldgen")
    local getCurrentWeather = F.getCurrentWeather or function() return "pleasant" end
    local WEATHER_EFFECTS = F.WEATHER_EFFECTS or {}
    local getTileType = F.getTileType or function(t) return {color={0.5,0.5,0.5}, icon="?", passable=true} end
    local drawPlayerSprite = F.drawPlayerSprite or function(px, py, fallback) fallback() end
    local MapEnemies = F.MapEnemies or {draw = function() end}
    local LuminaryPatrols = F.LuminaryPatrols or {getActivePatrols = function() return {} end}

    -- Draw compass at top of map area
    local compassH = 30
    M.drawCompass(x + 10, y + 2, w - 20, compassH)

    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(18))
    love.graphics.printf("World Map", x, y + compassH + 5, w, "center")

    -- Weather display (top right)
    local weather = getCurrentWeather()
    local weatherFx = WEATHER_EFFECTS[weather] or WEATHER_EFFECTS.pleasant or {color={0.7,0.7,0.7}, icon="?", name="Unknown", desc=""}
    local weatherX = x + w - 480
    local weatherY = y + 5

    love.graphics.setColor(0.1, 0.12, 0.15, 0.9)
    love.graphics.rectangle("fill", weatherX, weatherY, 150, 55, 5, 5)

    love.graphics.setColor(weatherFx.color)
    love.graphics.setFont(getFont(20))
    love.graphics.print(weatherFx.icon, weatherX + 8, weatherY + 5)
    love.graphics.setFont(getFont(12))
    love.graphics.print(weatherFx.name, weatherX + 35, weatherY + 8)

    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(getFont(9))
    love.graphics.printf(weatherFx.desc, weatherX + 5, weatherY + 28, 140, "left")

    if weatherFx.dangerous then
        love.graphics.setColor(0.9, 0.3, 0.3)
        love.graphics.setFont(getFont(10))
        love.graphics.printf("DANGER!", weatherX + 5, weatherY + 42, 140, "center")
    elseif weatherFx.needsShelter then
        love.graphics.setColor(0.9, 0.7, 0.3)
        love.graphics.setFont(getFont(9))
        love.graphics.printf("Shelter advised", weatherX + 5, weatherY + 42, 140, "center")
    end

    -- Camp button (when not in town)
    local tile
    if state.world.useWorldGen then
        tile = WorldGen.getTile(state.world.playerX, state.world.playerY)
    else
        tile = state.world.mapData[state.world.playerY] and state.world.mapData[state.world.playerY][state.world.playerX]
    end
    if tile and tile.type ~= "town" then
        local campBtnX = weatherX
        local campBtnY = weatherY + 405
        local campHover = mx >= campBtnX and mx <= campBtnX + 150 and my >= campBtnY and my <= campBtnY + 28

        if state.camping and state.camping.active then
            love.graphics.setColor(campHover and {0.4, 0.5, 0.4} or {0.28, 0.38, 0.28})
            love.graphics.rectangle("fill", campBtnX, campBtnY, 150, 28, 4, 4)
            love.graphics.setColor(0.8, 1, 0.8)
            love.graphics.setFont(getFont(11))
            love.graphics.printf("Enter Camp", campBtnX, campBtnY + 7, 150, "center")
        else
            love.graphics.setColor(campHover and {0.3, 0.4, 0.35} or {0.2, 0.3, 0.25})
            love.graphics.rectangle("fill", campBtnX, campBtnY, 150, 28, 4, 4)
            love.graphics.setColor(0.7, 0.9, 0.7)
            love.graphics.setFont(getFont(11))
            love.graphics.printf("Build Camp", campBtnX, campBtnY + 7, 150, "center")
        end

        if state.world.homeTown then
            local homeBtnX = campBtnX
            local homeBtnY = campBtnY + 35
            local homeHover = mx >= homeBtnX and mx <= homeBtnX + 150 and my >= homeBtnY and my <= homeBtnY + 28
            local hasPath = state.world.pathHistory and #state.world.pathHistory > 0

            love.graphics.setColor(homeHover and {0.4, 0.35, 0.5} or {0.25, 0.22, 0.35})
            love.graphics.rectangle("fill", homeBtnX, homeBtnY, 150, 28, 4, 4)
            love.graphics.setColor(hasPath and {0.8, 0.8, 1} or {0.5, 0.5, 0.6})
            love.graphics.setFont(getFont(11))
            love.graphics.printf("Head Home", homeBtnX, homeBtnY + 7, 150, "center")

            love.graphics.setColor(0.5, 0.5, 0.6)
            love.graphics.setFont(getFont(8))
            if hasPath then
                love.graphics.printf("(" .. #state.world.pathHistory .. " tiles)", homeBtnX, homeBtnY + 20, 150, "center")
            else
                love.graphics.printf("(" .. (state.world.homeTown.town and state.world.homeTown.town.name or "Home") .. ")", homeBtnX, homeBtnY + 20, 150, "center")
            end
        end

        local PropertySystem = require("propertysystem")
        local playerX = state.world.playerX
        local playerY = state.world.playerY

        if playerX and playerY then
            local claimKey = playerX .. "_" .. playerY
            local existingClaim = state.player and state.player.properties and state.player.properties.landClaims[claimKey]

            if existingClaim then
                local claimBtnX = campBtnX
                local claimBtnY = campBtnY + (state.world.homeTown and 75 or 40)
                local claimHover = mx >= claimBtnX and mx <= claimBtnX + 150 and my >= claimBtnY and my <= claimBtnY + 28

                love.graphics.setColor(claimHover and {0.5, 0.5, 0.4} or {0.35, 0.35, 0.3})
                love.graphics.rectangle("fill", claimBtnX, claimBtnY, 150, 28, 4, 4)
                love.graphics.setColor(0.9, 0.9, 0.7)
                love.graphics.setFont(getFont(11))
                love.graphics.printf("🏠 Your Land", claimBtnX, claimBtnY + 7, 150, "center")
                state.mapClaimBtn = {x = claimBtnX, y = claimBtnY, w = 150, h = 28, mode = "manage"}
            elseif PropertySystem.canClaimTile and PropertySystem.canClaimTile(playerX, playerY) then
                local claimBtnX = campBtnX
                local claimBtnY = campBtnY + (state.world.homeTown and 75 or 40)
                local claimHover = mx >= claimBtnX and mx <= claimBtnX + 150 and my >= claimBtnY and my <= claimBtnY + 28

                love.graphics.setColor(claimHover and {0.4, 0.45, 0.5} or {0.28, 0.32, 0.38})
                love.graphics.rectangle("fill", claimBtnX, claimBtnY, 150, 28, 4, 4)
                love.graphics.setColor(0.7, 0.8, 0.9)
                love.graphics.setFont(getFont(11))
                love.graphics.printf("🏴 Claim Land", claimBtnX, claimBtnY + 7, 150, "center")
                state.mapClaimBtn = {x = claimBtnX, y = claimBtnY, w = 150, h = 28, mode = "claim"}
            else
                state.mapClaimBtn = nil
            end
        else
            state.mapClaimBtn = nil
        end

        local hasTool = PropertySystem.hasLumberTool and PropertySystem.hasLumberTool()
        if hasTool and tile and tile.type == "forest" then
            local chopBtnX = campBtnX
            local chopBtnY = campBtnY + (state.world.homeTown and 110 or 75)
            if state.mapClaimBtn then
                chopBtnY = chopBtnY + 35
            end
            local chopHover = mx >= chopBtnX and mx <= chopBtnX + 150 and my >= chopBtnY and my <= chopBtnY + 28

            local lumberLevel = tile.lumber or PropertySystem.FOREST_MAX_LUMBER
            local lumberPct = lumberLevel / PropertySystem.FOREST_MAX_LUMBER

            love.graphics.setColor(chopHover and {0.5, 0.4, 0.3} or {0.35, 0.28, 0.2})
            love.graphics.rectangle("fill", chopBtnX, chopBtnY, 150, 28, 4, 4)
            love.graphics.setColor(0.9, 0.8, 0.6)
            love.graphics.setFont(getFont(11))
            love.graphics.printf("🪓 Chop Wood", chopBtnX, chopBtnY + 7, 150, "center")
            state.mapChopBtn = {x = chopBtnX, y = chopBtnY, w = 150, h = 28}

            local barY = chopBtnY + 30
            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.rectangle("fill", chopBtnX, barY, 150, 8, 2, 2)
            local barColor = lumberPct > 0.5 and {0.3, 0.6, 0.3} or (lumberPct > 0.2 and {0.6, 0.5, 0.2} or {0.6, 0.3, 0.2})
            love.graphics.setColor(barColor)
            love.graphics.rectangle("fill", chopBtnX, barY, 150 * lumberPct, 8, 2, 2)
            love.graphics.setColor(0.6, 0.6, 0.5)
            love.graphics.setFont(getFont(7))
            love.graphics.printf("Trees: " .. math.floor(lumberPct * 100) .. "%", chopBtnX, barY + 1, 150, "center")
        else
            state.mapChopBtn = nil
        end
    else
        state.mapChopBtn = nil
    end

    -- Get actual map boundaries with offsets
    local wOff = state.world.westOffset or 0
    local eOff = state.world.eastOffset or 0
    local nOff = state.world.northOffset or 0
    local sOff = state.world.southOffset or 0
    local baseW = state.world.mapWidth
    local baseH = state.world.mapHeight

    local px, py = state.world.playerX, state.world.playerY
    local viewRange = 8
    local minViewX = px - viewRange
    local maxViewX = px + viewRange
    local minViewY = py - viewRange
    local maxViewY = py + viewRange

    local visibleW = maxViewX - minViewX + 1
    local visibleH = maxViewY - minViewY + 1

    local cellSize = math.min(52, math.floor((w - 150) / visibleW), math.floor((h - 120) / visibleH))
    local mapStartX = x + (w - visibleW * cellSize - 100) / 2
    local mapStartY = y + 88

    -- Sprite mode: map tile type names to terrain quad names (verified atlas positions)
    local tileTypeToQuad = {
        forest = "grass",            -- green grass
        plains = "short_grass",      -- short grass
        grassland = "grass",         -- green grass
        desert = "sand",             -- verified sand (col 2, row 12)
        mountain = "stone_solid",    -- verified grey stone (col 27, row 8)
        water = "water",             -- verified deep blue (col 22, row 14)
        ocean = "water",             -- deep blue water
        deep_ocean = "water",        -- deep blue water
        snow = "snow",               -- snow tile
        ice = "ice",                 -- ice tile
        swamp = "dark_grass",        -- dark grass
        volcanic = "lava",           -- lava tile
        tundra = "snow",             -- snow tile
        jungle = "long_grass",       -- long grass
        savanna = "wheat",           -- wheat/golden
        coast = "sand",              -- verified sand
        river = "water",             -- deep blue water
        lake = "water",              -- deep blue water
        hills = "wood",              -- brown wood (earth -> wood mapping)
        road = "cobblestone",        -- verified cobblestone (col 4, row 15)
        ruins = "dark_stone",        -- verified dark stone (col 19, row 13)
    }
    local spriteMode = Renderer2D.isSprite()
    local terrainAtlas = spriteMode and Renderer2D.getAtlas("terrain") or nil

    for cy = minViewY, maxViewY do
        for cx = minViewX, maxViewX do
            local tile
            if state.world.useWorldGen then
                tile = WorldGen.getTile(cx, cy)
            else
                tile = state.world.mapData[cy] and state.world.mapData[cy][cx]
            end

            local screenCol = cx - minViewX
            local screenRow = cy - minViewY
            local cellX = mapStartX + screenCol * cellSize
            local cellY = mapStartY + screenRow * cellSize

            if tile and tile.explored then
                local tileType = getTileType(tile.type)
                local r, g, b = tileType.color[1] * 0.6, tileType.color[2] * 0.6, tileType.color[3] * 0.6

                if terrainAtlas then
                    local quadName = tileTypeToQuad[tile.type] or "grass"
                    local quad = TileQuadMaps.terrain[quadName]
                    if quad then
                        local scale = (cellSize - 1) / 32
                        -- Use a bright tint so atlas sprites show natural colors
                        love.graphics.setColor(0.9, 0.9, 0.88)
                        love.graphics.draw(terrainAtlas, quad, cellX, cellY, 0, scale, scale)
                    else
                        love.graphics.setColor(r, g, b)
                        love.graphics.rectangle("fill", cellX, cellY, cellSize - 1, cellSize - 1)
                    end
                else
                    love.graphics.setColor(r, g, b)
                    love.graphics.rectangle("fill", cellX, cellY, cellSize - 1, cellSize - 1)
                end

                love.graphics.setColor(1, 1, 1, 0.7)
                love.graphics.setFont(getFont(math.floor(cellSize * 0.7)))
                love.graphics.printf(tileType.icon, cellX, cellY + 2, cellSize - 1, "center")

                if state.world.useWorldGen and tile.region then
                    local region = WorldGen.getRegions()[tile.region]
                    if region and region.mapColor then
                        love.graphics.setColor(region.mapColor[1], region.mapColor[2], region.mapColor[3], 0.15)
                        love.graphics.rectangle("fill", cellX, cellY, cellSize - 1, cellSize - 1)
                    end
                end

                if state.player and state.player.properties and state.player.properties.landClaims then
                    local claimKey = cx .. "_" .. cy
                    local claim = state.player.properties.landClaims[claimKey]
                    if claim then
                        love.graphics.setColor(0.2, 0.8, 0.3, 0.8)
                        love.graphics.setLineWidth(2)
                        love.graphics.rectangle("line", cellX + 1, cellY + 1, cellSize - 3, cellSize - 3)
                        love.graphics.setLineWidth(1)

                        local propSymbol = "F"
                        local symbolColor = {0.8, 0.8, 0.5}

                        if claim.structure == "tent" then
                            propSymbol = "T"
                            symbolColor = {0.9, 0.8, 0.6}
                        elseif claim.structure == "cabin" then
                            propSymbol = "C"
                            symbolColor = {0.7, 0.5, 0.3}
                        elseif claim.structure == "wild_house" then
                            propSymbol = "H"
                            symbolColor = {0.8, 0.7, 0.5}
                        elseif claim.structure == "wild_manor" then
                            propSymbol = "M"
                            symbolColor = {0.9, 0.8, 0.4}
                        end

                        local settlement = state.player.properties.settlements and state.player.properties.settlements[claimKey]
                        if settlement then
                            if settlement.level >= 4 then
                                propSymbol = "T"
                                symbolColor = {1, 0.9, 0.3}
                            elseif settlement.level >= 3 then
                                propSymbol = "V"
                                symbolColor = {0.9, 0.8, 0.3}
                            else
                                propSymbol = "S"
                                symbolColor = {0.7, 0.9, 0.5}
                            end
                        end

                        if claim.hasWalls then
                            local wallColor = {0.5, 0.5, 0.5}
                            if claim.wallLevel == 2 then
                                wallColor = {0.6, 0.6, 0.7}
                            elseif claim.wallLevel >= 3 then
                                wallColor = {0.7, 0.7, 0.8}
                            end
                            love.graphics.setColor(wallColor[1], wallColor[2], wallColor[3], 0.7)
                            love.graphics.setLineWidth(3)
                            love.graphics.rectangle("line", cellX, cellY, cellSize - 1, cellSize - 1)
                            love.graphics.setLineWidth(1)
                        end

                        love.graphics.setColor(symbolColor)
                        love.graphics.setFont(getFont(math.floor(cellSize * 0.35)))
                        love.graphics.print(propSymbol, cellX + 2, cellY + 1)

                        if claim.damageLevel and claim.damageLevel > 0 then
                            local damageAlpha = claim.damageLevel / 200
                            love.graphics.setColor(0.9, 0.2, 0.2, damageAlpha)
                            love.graphics.rectangle("fill", cellX, cellY, cellSize - 1, cellSize - 1)
                        end
                    end
                end
            else
                love.graphics.setColor(0.08, 0.08, 0.1)
                love.graphics.rectangle("fill", cellX, cellY, cellSize - 1, cellSize - 1)
                love.graphics.setColor(0.2, 0.2, 0.25)
                love.graphics.setFont(getFont(math.floor(cellSize * 0.5)))
                love.graphics.printf("?", cellX, cellY + 4, cellSize - 1, "center")
            end

            -- Luminary Patrol overlays
            local activePatrols = LuminaryPatrols.getActivePatrols()
            for patrolId, patrol in pairs(activePatrols) do
                local patrolMinX = patrol.centerX - patrol.radius
                local patrolMaxX = patrol.centerX + patrol.radius
                local patrolMinY = patrol.centerY - patrol.radius
                local patrolMaxY = patrol.centerY + patrol.radius

                if cx >= patrolMinX and cx <= patrolMaxX and
                   cy >= patrolMinY and cy <= patrolMaxY then
                    local distFromCenter = math.abs(cx - patrol.centerX) +
                                          math.abs(cy - patrol.centerY)
                    local maxDist = patrol.radius * 2
                    local opacity = 0.3 * (1 - (distFromCenter / maxDist))

                    love.graphics.setColor(0.9, 0.9, 0.3, opacity)
                    love.graphics.rectangle("fill", cellX, cellY,
                                          cellSize - 1, cellSize - 1)

                    if cx == patrol.centerX and cy == patrol.centerY then
                        love.graphics.setColor(0.9, 0.8, 0.2, 0.9)
                        love.graphics.setLineWidth(2)
                        love.graphics.rectangle("line", cellX + 1, cellY + 1,
                                              cellSize - 3, cellSize - 3)
                        love.graphics.setLineWidth(1)

                        love.graphics.setColor(1, 0.95, 0.3)
                        love.graphics.setFont(getFont(math.floor(cellSize * 0.4)))
                        love.graphics.print("⚔", cellX + 2, cellY + 2)
                    end
                end
            end

            -- Highlight clickable adjacent tiles
            local dist = math.abs(cx - px) + math.abs(cy - py)
            if dist == 1 and tile and tile.explored then
                local tileType = getTileType(tile.type)
                if tileType.passable then
                    local hovered = mx >= cellX and mx < cellX + cellSize and my >= cellY and my < cellY + cellSize
                    love.graphics.setColor(hovered and {0.9, 0.9, 0.3, 0.5} or {0.5, 0.5, 0.3, 0.3})
                    love.graphics.setLineWidth(2)
                    love.graphics.rectangle("line", cellX, cellY, cellSize - 1, cellSize - 1)
                    love.graphics.setLineWidth(1)
                end
            end

            -- Player position
            if cx == px and cy == py then
                love.graphics.setColor(0.2, 0.9, 0.3)
                love.graphics.setLineWidth(3)
                love.graphics.rectangle("line", cellX, cellY, cellSize - 1, cellSize - 1)
                love.graphics.setLineWidth(1)

                drawPlayerSprite(cellX + cellSize/2, cellY + cellSize/2, function()
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.setFont(getFont(math.floor(cellSize * 0.6)))
                    love.graphics.printf("@", cellX, cellY + cellSize * 0.15, cellSize, "center")
                end)
            end
        end
    end

    -- Draw visible map enemies
    MapEnemies.draw(mapStartX, mapStartY, cellSize, minViewX, minViewY, maxViewX, maxViewY)

    -- Navigation arrows
    local arrowSize = 45
    local arrowX = x + w - 85
    local arrowY = y + 50

    local upHover = mx >= arrowX and mx <= arrowX + arrowSize and my >= arrowY and my <= arrowY + arrowSize
    love.graphics.setColor(upHover and {0.4, 0.5, 0.6} or {0.25, 0.3, 0.35})
    love.graphics.rectangle("fill", arrowX, arrowY, arrowSize, arrowSize, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(20))
    love.graphics.printf("N", arrowX, arrowY + 12, arrowSize, "center")

    local downY = arrowY + arrowSize * 2 + 10
    local downHover = mx >= arrowX and mx <= arrowX + arrowSize and my >= downY and my <= downY + arrowSize
    love.graphics.setColor(downHover and {0.4, 0.5, 0.6} or {0.25, 0.3, 0.35})
    love.graphics.rectangle("fill", arrowX, downY, arrowSize, arrowSize, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("S", arrowX, downY + 12, arrowSize, "center")

    local leftX = arrowX - arrowSize - 5
    local leftY = arrowY + arrowSize + 5
    local leftHover = mx >= leftX and mx <= leftX + arrowSize and my >= leftY and my <= leftY + arrowSize
    love.graphics.setColor(leftHover and {0.4, 0.5, 0.6} or {0.25, 0.3, 0.35})
    love.graphics.rectangle("fill", leftX, leftY, arrowSize, arrowSize, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("W", leftX, leftY + 12, arrowSize, "center")

    local rightX = arrowX + arrowSize + 5
    local rightHover = mx >= rightX and mx <= rightX + arrowSize and my >= leftY and my <= leftY + arrowSize
    love.graphics.setColor(rightHover and {0.4, 0.5, 0.6} or {0.25, 0.3, 0.35})
    love.graphics.rectangle("fill", rightX, leftY, arrowSize, arrowSize, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("E", rightX, leftY + 12, arrowSize, "center")

    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.setFont(getFont(9))
    love.graphics.printf("Click arrows or", arrowX - 30, downY + arrowSize + 8, arrowSize + 60, "center")
    love.graphics.printf("WASD/Arrows to move", arrowX - 30, downY + arrowSize + 20, arrowSize + 60, "center")
    love.graphics.printf("Map expands as you explore!", arrowX - 30, downY + arrowSize + 35, arrowSize + 60, "center")

    -- Town button (if in a town)
    local tile
    if state.world.useWorldGen then
        tile = WorldGen.getTile(px, py)
    else
        tile = state.world.mapData[py] and state.world.mapData[py][px]
    end
    if tile and tile.type == "town" then
        local townBtnY = downY + arrowSize + 55
        local townHover = mx >= arrowX - 25 and mx <= arrowX + arrowSize + 25 and my >= townBtnY and my <= townBtnY + 35
        love.graphics.setColor(townHover and {0.4, 0.5, 0.4} or {0.25, 0.35, 0.3})
        love.graphics.rectangle("fill", arrowX - 25, townBtnY, arrowSize + 50, 35, 6, 6)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(12))
        love.graphics.printf("Enter Town", arrowX - 25, townBtnY + 10, arrowSize + 50, "center")
    end

    if tile and tile.type == "dungeon" then
        local dungeonBtnY = downY + arrowSize + 55
        local dungeonHover = mx >= arrowX - 25 and mx <= arrowX + arrowSize + 25 and my >= dungeonBtnY and my <= dungeonBtnY + 35
        love.graphics.setColor(dungeonHover and {0.5, 0.3, 0.4} or {0.3, 0.2, 0.25})
        love.graphics.rectangle("fill", arrowX - 25, dungeonBtnY, arrowSize + 50, 35, 6, 6)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(12))
        love.graphics.printf("Enter Dungeon", arrowX - 25, dungeonBtnY + 10, arrowSize + 50, "center")
    end

    -- Legend
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.setFont(getFont(13))
    love.graphics.print("# Town  T Forest  ^ Mountain  ~ Water  % Swamp  D Dungeon", x + 15, y + h - 50)
    love.graphics.setColor(0.5, 0.8, 0.5)
    love.graphics.print("Property: F=Flag  T=Tent  C=Cabin  H=House  M=Manor  S=Settlement", x + 15, y + h - 33)

    -- Nearby enemies warning
    if state.world.mapEnemies and #state.world.mapEnemies > 0 then
        local nearbyCount = 0
        local chasingCount = 0
        for _, e in ipairs(state.world.mapEnemies) do
            local edist = math.abs(e.x - px) + math.abs(e.y - py)
            if edist <= 8 and e.state ~= "combat" then
                nearbyCount = nearbyCount + 1
                if e.state == "chase" then
                    chasingCount = chasingCount + 1
                end
            end
        end
        if nearbyCount > 0 then
            local warnY = y + h - 98
            love.graphics.setFont(getFont(14))
            if chasingCount > 0 then
                local flash = math.sin(love.timer.getTime() * 5) > 0
                love.graphics.setColor(flash and {0.9, 0.2, 0.2} or {0.7, 0.15, 0.15})
                love.graphics.print("!! " .. chasingCount .. " CHASING  |  " .. nearbyCount .. " enemies nearby", x + 15, warnY)
            else
                love.graphics.setColor(0.7, 0.6, 0.3)
                love.graphics.print(nearbyCount .. " enemies nearby", x + 15, warnY)
            end
        end
    end

    -- WorldGen debug info
    if state.world.useWorldGen then
        local debug = WorldGen.getDebugInfo()
        local region = WorldGen.getRegionAt(px, py)
        local regionName = region and region.name or "unknown"
        love.graphics.setColor(0.4, 0.5, 0.4)
        love.graphics.setFont(getFont(12))
        love.graphics.print("WorldGen: " .. debug.loadedChunks .. " chunks loaded, " .. debug.visitedChunks .. " visited", x + 15, y + h - 82)
        love.graphics.print("Memory: ~" .. debug.estimatedMemoryKB .. "KB | Region: " .. regionName .. " | Pos: " .. px .. "," .. py, x + 15, y + h - 67)
    end
end

M.drawDungeon = function(x, y, w, h, mx, my)
    if not state.player then return end
    if not state.dungeon then return end
    local getDungeonTileType = F.getDungeonTileType or function(t) return {color={0.5,0.5,0.5}, icon="?", name="unknown", passable=true} end
    local DungeonEnemies = F.DungeonEnemies or {initFloorEnemies = function() end, draw = function() end, getAliveCount = function() return 0 end}

    local dungeon = state.dungeon
    local floor = dungeon.floors[dungeon.currentFloor]
    if not floor then return end

    DungeonEnemies.initFloorEnemies(floor)

    local headerColor = dungeon.dungeonColor or {0.7, 0.4, 0.5}
    love.graphics.setColor(headerColor[1], headerColor[2], headerColor[3])
    love.graphics.setFont(getFont(18))
    love.graphics.printf(dungeon.name, x, y + 5, w, "center")

    love.graphics.setColor(0.6, 0.5, 0.6)
    love.graphics.setFont(getFont(12))
    local floorInfo = "Floor " .. dungeon.currentFloor .. " of " .. dungeon.totalFloors
    if dungeon.isPrison and dungeon.prisonData and dungeon.prisonData.floors then
        local prisonFloor = dungeon.prisonData.floors[dungeon.currentFloor]
        if prisonFloor and prisonFloor.template and prisonFloor.template.name then
            floorInfo = prisonFloor.template.name .. " (" .. dungeon.currentFloor .. "/" .. dungeon.totalFloors .. ")"
        end
    elseif dungeon.dungeonTypeName then
        floorInfo = floorInfo .. " - " .. dungeon.dungeonTypeName
    end
    love.graphics.printf(floorInfo, x, y + 28, w, "center")

    local statsX = x + w - 160
    local statsY = y + 5
    local statsHeight = 70
    if dungeon.currentFloor >= 15 then
        statsHeight = 90
    end

    love.graphics.setColor(0.12, 0.1, 0.15, 0.9)
    love.graphics.rectangle("fill", statsX, statsY, 150, statsHeight, 5, 5)

    love.graphics.setFont(getFont(10))
    love.graphics.setColor(0.9, 0.3, 0.3)
    love.graphics.print("HP: " .. (state.player.hp or 0) .. "/" .. (state.player.maxHP or 1), statsX + 10, statsY + 8)
    love.graphics.setColor(0.4, 0.5, 0.9)
    love.graphics.print("MP: " .. (state.player.mana or 0) .. "/" .. (state.player.maxMana or 1), statsX + 10, statsY + 22)
    love.graphics.setColor(0.9, 0.8, 0.2)
    love.graphics.print("Gold: " .. (state.player.gold or 0), statsX + 10, statsY + 36)
    love.graphics.setColor(0.6, 0.6, 0.7)
    local aliveEnemyCount = DungeonEnemies.getAliveCount()
    love.graphics.print("Enemies: " .. aliveEnemyCount, statsX + 10, statsY + 50)

    if state.player and state.player.prisonCuffs then
        love.graphics.setColor(0.9, 0.4, 0.2)
        love.graphics.setFont(getFont(9))
        love.graphics.print("CUFFS: Stats reduced!", statsX + 10, statsY + 62)
        statsHeight = math.max(statsHeight, 80)
    end

    if state.inPrisonEscape and state.prisonEscape then
        local alertLevel = state.prisonEscape.alertLevel or 0
        if alertLevel > 0 then
            local alertColors = {
                {0.9, 0.9, 0.3},
                {0.9, 0.6, 0.2},
                {0.9, 0.2, 0.2},
            }
            local alertNames = {"SUSPICIOUS", "SEARCH", "LOCKDOWN"}
            local color = alertColors[alertLevel] or {0.9, 0.2, 0.2}
            love.graphics.setColor(color)
            love.graphics.setFont(getFont(9))
            love.graphics.print("ALERT: " .. (alertNames[alertLevel] or "HIGH"), statsX + 10, statsY + 74)
        end
    end

    if state.inPrisonEscape and state.prisonEscape and state.prisonEscape.party and #state.prisonEscape.party > 0 then
        local partyY = statsY + statsHeight + 5
        love.graphics.setColor(0.12, 0.1, 0.15, 0.9)
        local partyPanelH = 18 + #state.prisonEscape.party * 14
        love.graphics.rectangle("fill", statsX, partyY, 150, partyPanelH, 5, 5)
        love.graphics.setColor(0.3, 0.9, 0.9)
        love.graphics.setFont(getFont(10))
        love.graphics.print("Escape Party:", statsX + 10, partyY + 3)
        for i, ally in ipairs(state.prisonEscape.party) do
            love.graphics.setColor(0.7, 0.9, 0.7)
            love.graphics.setFont(getFont(9))
            local allyStr = ally.name .. " (" .. (ally.class or "?") .. ")"
            love.graphics.print(allyStr, statsX + 15, partyY + 4 + i * 14)
        end
    end

    if dungeon.currentFloor >= 15 then
        love.graphics.setFont(getFont(9))
        if dungeon.hasBreached then
            love.graphics.setColor(0.6, 0.9, 1.0)
            love.graphics.print("BREACH DETECTED", statsX + 10, statsY + 64)
        elseif dungeon.currentFloor >= 20 then
            local flash = 0.7 + 0.3 * math.sin(love.timer.getTime() * 4)
            love.graphics.setColor(0.9 * flash, 0.7 * flash, 0.3 * flash)
            love.graphics.print("DEEP - UNSTABLE", statsX + 10, statsY + 64)
        else
            love.graphics.setColor(0.8, 0.8, 0.6)
            love.graphics.print("Depth: EXTREME", statsX + 10, statsY + 64)
        end
    end

    local px, py = dungeon.playerX, dungeon.playerY
    local viewRange = 5
    local minViewX = math.max(1, px - viewRange)
    local maxViewX = math.min(floor.width, px + viewRange)
    local minViewY = math.max(1, py - viewRange)
    local maxViewY = math.min(floor.height, py + viewRange)

    -- Use fixed grid dimensions based on viewRange so cellSize stays constant
    -- regardless of player position relative to dungeon boundaries
    local fixedW = viewRange * 2 + 1
    local fixedH = viewRange * 2 + 1

    local cellSize = math.min(96, math.floor((w - 180) / fixedW), math.floor((h - 140) / fixedH))
    local mapStartX = x + (w - fixedW * cellSize - 100) / 2
    local mapStartY = y + 55

    local spriteMode = Renderer2D.isSprite()
    local terrainAtlas = spriteMode and Renderer2D.getAtlas("terrain") or nil

    -- Map dungeon tile types to terrain quad names (verified atlas positions)
    -- Uses stone/cobblestone textures from verified terrain_atlas.png positions.
    local dungeonTileQuadMap = {
        floor = "stone_solid",           -- grey stone with cracks (col 24, row 11)
        wall = "black_solid",            -- pure black (col 28, row 5)
        door = "dark_stone",             -- dark stone base; procedural door overlay drawn on top
        stairs_down = "cobblestone_v2",  -- cobblestone (col 2, row 16, fully opaque)
        stairs_up = "cobblestone_v3",    -- cobblestone variant (col 3, row 16, fully opaque)
        entrance = "cobblestone",        -- cobblestone (col 1, row 16, fully opaque)
        exit = "cobblestone",            -- cobblestone
        water = "water",                 -- deep blue (col 22, row 14)
        grass = "grass",                 -- grass tile
        corridor = "cobblestone",        -- cobblestone (fully opaque)
        room = "stone_varied",           -- varied stone (col 25, row 11)
        secret_passage = "dark_stone",   -- dark stone blocks (col 14, row 15)
        trap = "stone_solid",            -- grey stone (same as floor)
        hollow_portal = "ice",           -- ice for portal
        lava = "lava",                   -- lava tile
        chest = "stone_solid",           -- grey stone (same as floor)
        prison_cell_start = "dark_stone", -- dark stone for prison
        escape_exit = "cobblestone",     -- cobblestone
    }

    -- Prison dungeons use darker stone terrain for gritty prison feel
    if state.inPrisonEscape or (dungeon and dungeon.isPrison) then
        dungeonTileQuadMap.floor = "cobblestone"
        dungeonTileQuadMap.corridor = "cobblestone"
        dungeonTileQuadMap.room = "cobblestone"
        dungeonTileQuadMap.wall = "black_solid"
        dungeonTileQuadMap.door = "dark_stone"
    end

    -- Use unclamped origin so tiles are always positioned consistently in the fixed grid
    local gridOriginX = px - viewRange
    local gridOriginY = py - viewRange

    for cy = minViewY, maxViewY do
        for cx = minViewX, maxViewX do
            local tile = floor.grid[cy] and floor.grid[cy][cx]
            local screenCol = cx - gridOriginX
            local screenRow = cy - gridOriginY
            local cellX = mapStartX + screenCol * cellSize
            local cellY = mapStartY + screenRow * cellSize

            if tile then
                if tile.explored then
                    local tileType = getDungeonTileType(tile.type)
                    local r, g, b = tileType.color[1] * 0.9, tileType.color[2] * 0.9, tileType.color[3] * 0.9

                    if dungeon.currentFloor >= 15 then
                        local glowIntensity = math.min((dungeon.currentFloor - 14) / 16, 1.0)
                        g = g + (0.3 * glowIntensity)
                        b = b + (0.4 * glowIntensity)
                        r = r * (1 - glowIntensity * 0.3)
                    end

                    if tile.type == "hollow_portal" then
                        r, g, b = 0.6, 0.8, 1.0
                        local pulse = 0.8 + 0.2 * math.sin(love.timer.getTime() * 3)
                        r, g, b = r * pulse, g * pulse, b * pulse
                    end

                    local tileQuadDrawn = false

                    -- Try atlas-based rendering first (verified positions)
                    if spriteMode and terrainAtlas then
                        local quadName = dungeonTileQuadMap[tile.type] or "stone_solid"
                        local quad = TileQuadMaps.terrain[quadName]
                        if quad then
                            local scale = (cellSize - 1) / 32
                            -- Use bright tint so atlas art shows naturally
                            love.graphics.setColor(0.95, 0.93, 0.9)
                            love.graphics.draw(terrainAtlas, quad, cellX, cellY, 0, scale, scale)
                            tileQuadDrawn = true
                        end
                    end

                    -- Fallback: procedural colored rectangle if no atlas quad drawn
                    if not tileQuadDrawn then
                        love.graphics.setColor(r, g, b)
                        love.graphics.rectangle("fill", cellX, cellY, cellSize - 1, cellSize - 1)
                        tileQuadDrawn = spriteMode  -- suppress text icons in sprite mode
                    end

                    -- Procedural overlays ON TOP of atlas sprites (sprite mode only)
                    if spriteMode then
                        love.graphics.setLineWidth(1)
                        local ttype = tile.type

                        if ttype == "wall" then
                            -- Overlay for walls on top of black atlas tile
                            love.graphics.setColor(0.15, 0.12, 0.18, 0.5)
                            love.graphics.rectangle("fill", cellX, cellY, cellSize - 1, cellSize - 1)
                            -- Brick mortar lines for wall texture
                            love.graphics.setColor(0.25, 0.22, 0.2, 0.4)
                            local third = math.floor((cellSize - 1) / 3)
                            love.graphics.line(cellX, cellY + third, cellX + cellSize - 1, cellY + third)
                            love.graphics.line(cellX, cellY + third * 2, cellX + cellSize - 1, cellY + third * 2)
                            love.graphics.line(cellX + math.floor((cellSize - 1) / 2), cellY, cellX + math.floor((cellSize - 1) / 2), cellY + third)
                            love.graphics.line(cellX + math.floor((cellSize - 1) / 4), cellY + third, cellX + math.floor((cellSize - 1) / 4), cellY + third * 2)
                            love.graphics.line(cellX + math.floor((cellSize - 1) * 3 / 4), cellY + third * 2, cellX + math.floor((cellSize - 1) * 3 / 4), cellY + cellSize - 1)

                        elseif ttype == "door" then
                            -- Wooden door visual overlay on top of dark stone base tile
                            local doorPad = math.floor(cellSize * 0.1)
                            love.graphics.setColor(0.55, 0.35, 0.15, 0.9)
                            love.graphics.rectangle("fill", cellX + doorPad, cellY + doorPad, cellSize - 1 - doorPad * 2, cellSize - 1 - doorPad * 2, 2, 2)
                            -- Wood grain horizontal lines
                            love.graphics.setColor(0.45, 0.28, 0.1, 0.5)
                            local grainStep = math.max(3, math.floor(cellSize * 0.15))
                            for gy = cellY + doorPad + grainStep, cellY + cellSize - 1 - doorPad, grainStep do
                                love.graphics.line(cellX + doorPad + 1, gy, cellX + cellSize - 1 - doorPad - 1, gy)
                            end
                            love.graphics.setColor(0.7, 0.5, 0.2, 0.95)
                            love.graphics.setLineWidth(2)
                            love.graphics.rectangle("line", cellX + doorPad, cellY + doorPad, cellSize - 1 - doorPad * 2, cellSize - 1 - doorPad * 2, 2, 2)
                            -- Door handle
                            love.graphics.setColor(0.9, 0.8, 0.3, 0.95)
                            love.graphics.circle("fill", cellX + cellSize * 0.7, cellY + cellSize * 0.5, math.max(2, cellSize * 0.08))
                            love.graphics.setLineWidth(1)

                        elseif ttype == "stairs_down" or ttype == "stairs_up" then
                            -- Stepped pattern overlay for stairs
                            local stairColor = ttype == "stairs_down" and {0.4, 0.6, 0.9} or {0.6, 0.9, 0.4}
                            love.graphics.setColor(stairColor[1], stairColor[2], stairColor[3], 0.7)
                            local stairPad = math.floor(cellSize * 0.2)
                            for si = 0, 2 do
                                local sy = cellY + stairPad + si * math.floor((cellSize - stairPad * 2) / 3)
                                local sw = cellSize - 1 - stairPad * 2 - si * math.floor(cellSize * 0.12)
                                love.graphics.rectangle("fill", cellX + stairPad + si * math.floor(cellSize * 0.06), sy, sw, math.floor((cellSize - stairPad * 2) / 3) - 1)
                            end
                            -- Arrow indicator
                            love.graphics.setColor(1, 1, 1, 0.9)
                            love.graphics.setFont(getFont(math.floor(cellSize * 0.4)))
                            local arrow = ttype == "stairs_down" and "v" or "^"
                            love.graphics.printf(arrow, cellX, cellY + cellSize * 0.3, cellSize - 1, "center")

                        elseif ttype == "entrance" or ttype == "exit" or ttype == "escape_exit" then
                            -- Portal glow overlay for entrance/exit
                            local portalPulse = 0.6 + 0.4 * math.sin(love.timer.getTime() * 2.5)
                            local ec = ttype == "entrance" and {0.3, 0.8, 0.3} or {0.9, 0.8, 0.2}
                            love.graphics.setColor(ec[1] * portalPulse, ec[2] * portalPulse, ec[3] * portalPulse, 0.6)
                            love.graphics.circle("fill", cellX + cellSize / 2, cellY + cellSize / 2, cellSize * 0.35)
                            love.graphics.setColor(ec[1], ec[2], ec[3], 0.9)
                            love.graphics.setLineWidth(2)
                            love.graphics.circle("line", cellX + cellSize / 2, cellY + cellSize / 2, cellSize * 0.35)
                            love.graphics.setLineWidth(1)

                        elseif ttype == "water" then
                            -- Subtle wave animation overlay for water
                            local wavePhase = love.timer.getTime() * 2
                            love.graphics.setColor(0.3, 0.5, 0.7, 0.35)
                            for wi = 0, 2 do
                                local wy = cellY + cellSize * (0.25 + wi * 0.25) + math.sin(wavePhase + wi) * 2
                                love.graphics.line(cellX + 1, wy, cellX + cellSize - 2, wy)
                            end

                        elseif ttype == "lava" then
                            -- Subtle glow overlay for lava
                            local lavaPulse = 0.7 + 0.3 * math.sin(love.timer.getTime() * 1.5)
                            love.graphics.setColor(1, 0.4 * lavaPulse, 0.1 * lavaPulse, 0.3)
                            love.graphics.rectangle("fill", cellX + 1, cellY + 1, cellSize - 3, cellSize - 3)
                        end
                    end

                    -- Draw content icons and tile type icons
                    -- In sprite mode with a drawn quad, suppress base tile icons
                    -- but still draw content markers (enemies, chests, NPCs, etc.)
                    local icon = tileType.icon
                    local hasContent = false
                    local drawIcon = true
                    if tile.content then
                        if tile.content.type == "enemy" and tile.content.data and tile.content.data.alive then
                            icon = tile.content.data.isBoss and "B" or "E"
                            hasContent = true
                            if spriteMode then
                                Renderer2D.drawShadow(cellX + cellSize/2, cellY + cellSize - 3, cellSize * 0.6, cellSize * 0.2)
                                -- Draw enemy indicator circle instead of letter
                                local enemyColor = tile.content.data.isBoss and {0.9, 0.2, 0.6} or {0.9, 0.3, 0.3}
                                love.graphics.setColor(enemyColor[1], enemyColor[2], enemyColor[3], 0.5)
                                love.graphics.circle("fill", cellX + cellSize/2, cellY + cellSize/2, cellSize * 0.3)
                                love.graphics.setColor(enemyColor[1], enemyColor[2], enemyColor[3], 0.9)
                                love.graphics.setLineWidth(2)
                                love.graphics.circle("line", cellX + cellSize/2, cellY + cellSize/2, cellSize * 0.3)
                                love.graphics.setLineWidth(1)
                                -- Still draw the letter for clarity
                                love.graphics.setColor(1, 1, 1, 0.95)
                                love.graphics.setFont(getFont(math.floor(cellSize * 0.45)))
                                love.graphics.printf(icon, cellX, cellY + cellSize * 0.2, cellSize - 1, "center")
                                drawIcon = false
                            else
                                love.graphics.setColor(0.9, 0.3, 0.3)
                            end
                        elseif tile.content.type == "ally" and tile.content.data and not tile.content.data.recruited then
                            icon = "A"
                            hasContent = true
                            if spriteMode then
                                Renderer2D.drawShadow(cellX + cellSize/2, cellY + cellSize - 3, cellSize * 0.5, cellSize * 0.15)
                                love.graphics.setColor(0.2, 0.7, 0.7, 0.5)
                                love.graphics.circle("fill", cellX + cellSize/2, cellY + cellSize/2, cellSize * 0.3)
                                love.graphics.setColor(0.3, 0.9, 0.9, 0.9)
                                love.graphics.setLineWidth(2)
                                love.graphics.circle("line", cellX + cellSize/2, cellY + cellSize/2, cellSize * 0.3)
                                love.graphics.setLineWidth(1)
                                love.graphics.setColor(1, 1, 1, 0.95)
                                love.graphics.setFont(getFont(math.floor(cellSize * 0.45)))
                                love.graphics.printf("A", cellX, cellY + cellSize * 0.2, cellSize - 1, "center")
                                drawIcon = false
                            else
                                love.graphics.setColor(0.3, 0.9, 0.9)
                            end
                        elseif tile.content.type == "chest" and not tile.content.opened then
                            icon = "$"
                            hasContent = true
                            if spriteMode then
                                -- Draw chest box indicator
                                local chestPad = math.floor(cellSize * 0.2)
                                love.graphics.setColor(0.65, 0.5, 0.15, 0.85)
                                love.graphics.rectangle("fill", cellX + chestPad, cellY + chestPad + cellSize * 0.1, cellSize - 1 - chestPad * 2, cellSize * 0.55, 2, 2)
                                love.graphics.setColor(0.9, 0.75, 0.2, 0.95)
                                love.graphics.setLineWidth(2)
                                love.graphics.rectangle("line", cellX + chestPad, cellY + chestPad + cellSize * 0.1, cellSize - 1 - chestPad * 2, cellSize * 0.55, 2, 2)
                                -- Chest clasp
                                love.graphics.setColor(0.95, 0.9, 0.3)
                                love.graphics.circle("fill", cellX + cellSize / 2, cellY + cellSize * 0.38, math.max(2, cellSize * 0.06))
                                love.graphics.setLineWidth(1)
                                drawIcon = false
                            else
                                love.graphics.setColor(0.9, 0.8, 0.2)
                            end
                        elseif tile.content.type == "npc" and tile.content.data and not tile.content.data.rescued then
                            icon = "?"
                            hasContent = true
                            if spriteMode then
                                Renderer2D.drawShadow(cellX + cellSize/2, cellY + cellSize - 3, cellSize * 0.5, cellSize * 0.15)
                                love.graphics.setColor(0.3, 0.7, 0.3, 0.5)
                                love.graphics.circle("fill", cellX + cellSize/2, cellY + cellSize/2, cellSize * 0.3)
                                love.graphics.setColor(0.5, 0.9, 0.5, 0.9)
                                love.graphics.setLineWidth(2)
                                love.graphics.circle("line", cellX + cellSize/2, cellY + cellSize/2, cellSize * 0.3)
                                love.graphics.setLineWidth(1)
                                love.graphics.setColor(1, 1, 1, 0.95)
                                love.graphics.setFont(getFont(math.floor(cellSize * 0.45)))
                                love.graphics.printf("?", cellX, cellY + cellSize * 0.2, cellSize - 1, "center")
                                drawIcon = false
                            else
                                love.graphics.setColor(0.5, 0.9, 0.5)
                            end
                        elseif tile.content.type == "scavenge" and not tile.content.searched then
                            icon = "."
                            hasContent = true
                            if spriteMode then
                                -- Small sparkle indicator for scavenge spots
                                love.graphics.setColor(0.6, 0.5, 0.3, 0.7)
                                love.graphics.circle("fill", cellX + cellSize * 0.5, cellY + cellSize * 0.5, cellSize * 0.12)
                                love.graphics.setColor(0.8, 0.7, 0.4, 0.9)
                                love.graphics.circle("fill", cellX + cellSize * 0.35, cellY + cellSize * 0.35, cellSize * 0.06)
                                love.graphics.circle("fill", cellX + cellSize * 0.65, cellY + cellSize * 0.4, cellSize * 0.06)
                                drawIcon = false
                            else
                                love.graphics.setColor(0.6, 0.5, 0.3)
                            end
                        else
                            if not (spriteMode and tileQuadDrawn) then
                                love.graphics.setColor(1, 1, 1, 0.8)
                            else
                                drawIcon = false
                            end
                        end
                    else
                        -- No content: suppress base tile icon in sprite mode
                        if spriteMode and tileQuadDrawn then
                            drawIcon = false
                        else
                            love.graphics.setColor(1, 1, 1, 0.7)
                        end
                    end
                    -- Only draw the text icon when needed (classic mode or no quad drawn)
                    if drawIcon then
                        love.graphics.setFont(getFont(math.floor(cellSize * 0.7)))
                        love.graphics.printf(icon, cellX, cellY + 2, cellSize - 1, "center")
                    end
                else
                    love.graphics.setColor(0.12, 0.11, 0.15)
                    love.graphics.rectangle("fill", cellX, cellY, cellSize - 1, cellSize - 1)
                end

                local dist = math.abs(cx - px) + math.abs(cy - py)
                if dist == 1 and tile.explored then
                    local tileType = getDungeonTileType(tile.type)
                    if tileType.passable then
                        local hovered = mx >= cellX and mx < cellX + cellSize and my >= cellY and my < cellY + cellSize
                        love.graphics.setColor(hovered and {0.6, 0.5, 0.8, 0.5} or {0.4, 0.35, 0.5, 0.3})
                        love.graphics.setLineWidth(2)
                        love.graphics.rectangle("line", cellX, cellY, cellSize - 1, cellSize - 1)
                        love.graphics.setLineWidth(1)
                    end
                end

                if cx == px and cy == py then
                    if spriteMode then
                        -- Sprite mode: draw a character indicator with shadow and glow
                        Renderer2D.drawShadow(cellX + cellSize/2, cellY + cellSize - 3, cellSize * 0.6, cellSize * 0.2)
                        -- Pulsing glow ring
                        local playerPulse = 0.7 + 0.3 * math.sin(love.timer.getTime() * 3)
                        love.graphics.setColor(0.2, 0.7, 0.3, 0.25 * playerPulse)
                        love.graphics.circle("fill", cellX + cellSize/2, cellY + cellSize/2, cellSize * 0.45)
                        -- Body circle
                        love.graphics.setColor(0.15, 0.55, 0.25, 0.7)
                        love.graphics.circle("fill", cellX + cellSize/2, cellY + cellSize/2, cellSize * 0.32)
                        love.graphics.setColor(0.3, 0.9, 0.4, 0.95)
                        love.graphics.setLineWidth(2)
                        love.graphics.circle("line", cellX + cellSize/2, cellY + cellSize/2, cellSize * 0.32)
                        -- Head circle (smaller, upper portion)
                        love.graphics.setColor(0.4, 0.95, 0.5, 0.9)
                        love.graphics.circle("fill", cellX + cellSize/2, cellY + cellSize * 0.3, cellSize * 0.15)
                        love.graphics.setColor(0.3, 0.9, 0.4)
                        love.graphics.circle("line", cellX + cellSize/2, cellY + cellSize * 0.3, cellSize * 0.15)
                        love.graphics.setLineWidth(1)
                        -- Highlight border
                        love.graphics.setColor(0.3, 0.9, 0.4, 0.6)
                        love.graphics.setLineWidth(2)
                        love.graphics.rectangle("line", cellX, cellY, cellSize - 1, cellSize - 1)
                        love.graphics.setLineWidth(1)
                    else
                        -- Classic mode: text "@" character
                        love.graphics.setColor(0.3, 0.9, 0.4)
                        love.graphics.setFont(getFont(math.floor(cellSize * 0.75)))
                        love.graphics.printf("@", cellX, cellY + 1, cellSize - 1, "center")
                        love.graphics.setColor(0.3, 0.9, 0.4)
                        love.graphics.setLineWidth(2)
                        love.graphics.rectangle("line", cellX, cellY, cellSize - 1, cellSize - 1)
                        love.graphics.setLineWidth(1)
                    end
                end
            end
        end
    end

    if state.inPrisonEscape and floor.guardPatrols then
        for _, guard in ipairs(floor.guardPatrols) do
            if guard.alive and guard.x >= minViewX and guard.x <= maxViewX and guard.y >= minViewY and guard.y <= maxViewY then
                local gCol = guard.x - gridOriginX
                local gRow = guard.y - gridOriginY
                local gX = mapStartX + gCol * cellSize
                local gY = mapStartY + gRow * cellSize

                local radius = guard.alertRange or 3
                for vy = math.max(minViewY, guard.y - radius), math.min(maxViewY, guard.y + radius) do
                    for vx = math.max(minViewX, guard.x - radius), math.min(maxViewX, guard.x + radius) do
                        local dist = math.abs(vx - guard.x) + math.abs(vy - guard.y)
                        if dist <= radius and not (vx == guard.x and vy == guard.y) then
                            local vCol = vx - gridOriginX
                            local vRow = vy - gridOriginY
                            local vCellX = mapStartX + vCol * cellSize
                            local vCellY = mapStartY + vRow * cellSize
                            local alpha = 0.15 * (1 - dist / (radius + 1))
                            love.graphics.setColor(0.9, 0.2, 0.2, alpha)
                            love.graphics.rectangle("fill", vCellX, vCellY, cellSize - 1, cellSize - 1)
                        end
                    end
                end

                if spriteMode then
                    -- Sprite mode: draw guard as armored circle indicator
                    Renderer2D.drawShadow(gX + cellSize/2, gY + cellSize - 3, cellSize * 0.6, cellSize * 0.2)
                    love.graphics.setColor(0.7, 0.15, 0.15, 0.5)
                    love.graphics.circle("fill", gX + cellSize/2, gY + cellSize/2, cellSize * 0.35)
                    love.graphics.setColor(0.9, 0.2, 0.2, 0.95)
                    love.graphics.setLineWidth(2)
                    love.graphics.circle("line", gX + cellSize/2, gY + cellSize/2, cellSize * 0.35)
                    -- Head
                    love.graphics.setColor(0.9, 0.3, 0.3, 0.9)
                    love.graphics.circle("fill", gX + cellSize/2, gY + cellSize * 0.3, cellSize * 0.13)
                    love.graphics.setLineWidth(1)
                    -- "G" label for clarity
                    love.graphics.setColor(1, 1, 1, 0.9)
                    love.graphics.setFont(getFont(math.floor(cellSize * 0.35)))
                    love.graphics.printf("G", gX, gY + cellSize * 0.55, cellSize - 1, "center")
                else
                    love.graphics.setColor(0.9, 0.2, 0.2)
                    love.graphics.setFont(getFont(math.floor(cellSize * 0.75)))
                    love.graphics.printf("G", gX, gY + 1, cellSize - 1, "center")
                    love.graphics.setLineWidth(2)
                    love.graphics.rectangle("line", gX, gY, cellSize - 1, cellSize - 1)
                    love.graphics.setLineWidth(1)
                end
            end
        end
    end

    DungeonEnemies.draw(mapStartX, mapStartY, cellSize, gridOriginX, gridOriginY, maxViewX, maxViewY)

    if floor.visibleEnemies and #floor.visibleEnemies > 0 then
        local nearbyCount = 0
        local chasingCount = 0
        for _, ve in ipairs(floor.visibleEnemies) do
            if ve.enemyData.alive then
                local edist = math.abs(ve.x - px) + math.abs(ve.y - py)
                if edist <= 6 then
                    nearbyCount = nearbyCount + 1
                    if ve.state == "chase" then
                        chasingCount = chasingCount + 1
                    end
                end
            end
        end
        if chasingCount > 0 then
            local flash = math.sin(love.timer.getTime() * 5) > 0
            love.graphics.setColor(flash and {0.9, 0.2, 0.2} or {0.7, 0.15, 0.15})
            love.graphics.setFont(getFont(10))
            love.graphics.print("!! " .. chasingCount .. " CHASING", x + 15, y + 42)
        elseif nearbyCount > 0 then
            love.graphics.setColor(0.7, 0.6, 0.3)
            love.graphics.setFont(getFont(9))
            love.graphics.print(nearbyCount .. " enemies nearby", x + 15, y + 42)
        end
    end

    local currentTile = floor.grid[py] and floor.grid[py][px]
    if currentTile then
        local tileType = getDungeonTileType(currentTile.type)
        local infoY = y + h - 85

        love.graphics.setColor(0.1, 0.1, 0.12, 0.9)
        love.graphics.rectangle("fill", x + 10, infoY, w - 20, 75, 5, 5)

        love.graphics.setFont(getFont(12))
        love.graphics.setColor(0.7, 0.7, 0.8)
        love.graphics.print("Standing on: " .. tileType.name, x + 20, infoY + 8)

        love.graphics.setFont(getFont(10))
        love.graphics.setColor(0.6, 0.6, 0.7)
        local actionY = infoY + 25

        if currentTile.type == "entrance" and dungeon.currentFloor == 1 then
            love.graphics.setColor(0.5, 0.9, 0.5)
            love.graphics.print("[ESC] Leave Dungeon", x + 20, actionY)
            actionY = actionY + 14
        elseif currentTile.type == "stairs_down" then
            love.graphics.setColor(0.5, 0.7, 0.9)
            love.graphics.print("[SPACE] Descend to next floor", x + 20, actionY)
            actionY = actionY + 14
        elseif currentTile.type == "stairs_up" then
            love.graphics.setColor(0.7, 0.9, 0.5)
            love.graphics.print("[SPACE] Ascend to previous floor", x + 20, actionY)
            actionY = actionY + 14
        end

        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.print("[Arrow Keys / WASD] Move  [I] Inventory", x + 20, actionY)
    end

    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.setFont(getFont(9))
    if spriteMode then
        love.graphics.print("[Arrow Keys / WASD] Move  [I] Inventory  [SPACE] Interact", x + 15, y + h - 18)
    else
        love.graphics.print("# Wall  . Floor  + Door  < Up  > Down", x + 15, y + h - 18)
        love.graphics.print("$ Chest  E Enemy  B Boss  ? NPC  ^ Entrance", x + w/2, y + h - 18)
    end
end

M.drawCombat = function(x, y, w, h, mx, my)
    if not state.player then return end
    local Backpack = require("backpack")
    local getPortraitImage = F.getPortraitImage or function() return nil end
    local getAvailableSkills = F.getAvailableSkills or function() return {} end
    local SKILLS = F.SKILLS or {}
    local turnOrderW = F.turnOrderW or 80
    local actionZoneH = F.actionZoneH or 90

    local enemies = state.combat.enemies or {}
    local numEnemies = #enemies
    if numEnemies == 0 then return end

    local combatAreaH = h - 80
    local enemyZoneH = combatAreaH * 0.45
    local playerZoneH = combatAreaH * 0.35
    local middleZoneH = combatAreaH * 0.20

    -- ENEMIES (TOP)
    -- Multi-row layout when enemies exceed 8
    local maxPerRow = math.min(numEnemies, 8)
    local numEnemyRows = math.ceil(numEnemies / maxPerRow)
    local enemyCardW = math.min(180, (w - 100) / maxPerRow - 12)
    local enemyCardH = numEnemyRows > 1 and 120 or 160
    local enemyPortraitSize = numEnemyRows > 1 and 60 or 80
    local totalEnemyWidth = maxPerRow * (enemyCardW + 10) - 10
    local enemyStartX = x + (w - totalEnemyWidth - 90) / 2
    local enemyY = y + 10

    -- Check if this is a manually-controlled companion turn
    -- Per-companion autoBattle overrides manual control for that companion
    local currentCompAutoBattle = false
    if state.combat.isCompanionTurn and state.combat.currentCompanionIndex then
        local comp = state.player and state.player.party and state.player.party[state.combat.currentCompanionIndex]
        if comp and comp.autoBattle then currentCompAutoBattle = true end
    end
    local isManualCompTurn = state.combat.isCompanionTurn
        and state.player and state.player.manualPartyControl ~= false
        and not currentCompAutoBattle
    local canSelectTarget = state.combat.isPlayerTurn or isManualCompTurn

    state.combat.enemyButtons = {}
    for i, enemy in ipairs(enemies) do
        local row = math.floor((i - 1) / maxPerRow)
        local col = (i - 1) % maxPerRow
        -- Center partial last row
        local enemiesInThisRow = (row < numEnemyRows - 1) and maxPerRow or (numEnemies - row * maxPerRow)
        local rowWidth = enemiesInThisRow * (enemyCardW + 10) - 10
        local rowStartX = x + (w - rowWidth - 90) / 2
        local cardX = rowStartX + col * (enemyCardW + 10)
        local cardY = enemyY + row * (enemyCardH + 8)
        local isSelected = (i == state.combat.selectedTarget)
        local isDead = enemy.hp <= 0
        local isActing = (state.combat.currentActorIndex == i and not state.combat.isPlayerTurn)

        if isDead then
            love.graphics.setColor(0.1, 0.1, 0.1, 0.6)
        elseif isActing then
            love.graphics.setColor(0.35, 0.15, 0.15)
        elseif isSelected and canSelectTarget then
            love.graphics.setColor(0.2, 0.28, 0.38)
        else
            love.graphics.setColor(0.18, 0.14, 0.14)
        end
        love.graphics.rectangle("fill", cardX, cardY, enemyCardW, enemyCardH, 8, 8)

        if isSelected and canSelectTarget and not isDead then
            love.graphics.setColor(isManualCompTurn and {0.3, 0.7, 0.95} or {0.3, 0.95, 0.3})
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", cardX, cardY, enemyCardW, enemyCardH, 8, 8)
            love.graphics.setLineWidth(1)
        elseif isActing then
            love.graphics.setColor(1, 0.4, 0.3)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", cardX, cardY, enemyCardW, enemyCardH, 8, 8)
            love.graphics.setLineWidth(1)
        end

        local enemyPortrait = getPortraitImage(enemy.id)
        if enemyPortrait then
            love.graphics.setColor(isDead and {0.4, 0.4, 0.4} or {1, 1, 1})
            local imgW, imgH = enemyPortrait:getDimensions()
            local scale = enemyPortraitSize / math.max(imgW, imgH)
            local px = cardX + (enemyCardW - imgW * scale) / 2
            local py = cardY + 8
            love.graphics.draw(enemyPortrait, px, py, 0, scale, scale)
        else
            love.graphics.setFont(getFont(numEnemyRows > 1 and 28 or 40))
            love.graphics.setColor(isDead and {0.4, 0.4, 0.4} or {0.9, 0.3, 0.3})
            love.graphics.printf(enemy.portrait or "?", cardX, cardY + (numEnemyRows > 1 and 10 or 20), enemyCardW, "center")
        end

        love.graphics.setFont(getFont(numEnemyRows > 1 and 10 or 12))
        love.graphics.setColor(isDead and {0.5, 0.5, 0.5} or {1, 1, 1})
        love.graphics.printf(enemy.name, cardX + 4, cardY + enemyPortraitSize + (numEnemyRows > 1 and 4 or 12), enemyCardW - 8, "center")

        local hpBarW = enemyCardW - 20
        local barH = numEnemyRows > 1 and 10 or 14
        local barX = cardX + 10
        local barY = cardY + enemyCardH - (numEnemyRows > 1 and 18 or 28)
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", barX, barY, hpBarW, barH, 3, 3)
        if not isDead then
            love.graphics.setColor(0.85, 0.2, 0.2)
            love.graphics.rectangle("fill", barX, barY, hpBarW * math.max(0, enemy.hp / enemy.maxHP), barH, 3, 3)
        end
        love.graphics.setFont(getFont(10))
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(math.max(0, enemy.hp) .. "/" .. enemy.maxHP, barX, barY + 1, hpBarW, "center")

        if isDead then
            local deadH = numEnemyRows > 1 and 20 or 28
            love.graphics.setColor(0.5, 0.15, 0.15, 0.85)
            love.graphics.rectangle("fill", cardX + 10, cardY + enemyCardH/2 - deadH/2, enemyCardW - 20, deadH, 5, 5)
            love.graphics.setColor(0.95, 0.3, 0.3)
            love.graphics.setFont(getFont(numEnemyRows > 1 and 12 or 16))
            love.graphics.printf("DEAD", cardX, cardY + enemyCardH/2 - (numEnemyRows > 1 and 6 or 10), enemyCardW, "center")
        end

        state.combat.enemyButtons[i] = {x = cardX, y = cardY, w = enemyCardW, h = enemyCardH, dead = isDead}
    end

    -- PLAYER & PARTY (BOTTOM)
    local playerZoneY = y + enemyZoneH + middleZoneH + 20
    local party = state.player.party or {}
    local totalChars = 1 + #party
    local compactParty = totalChars > 6  -- Switch to compact layout when > 5 companions + player

    local playerCardW = compactParty and 110 or 140
    local playerCardH = compactParty and 90 or 120
    local playerPortraitSize = compactParty and 40 or 60

    -- Multi-row for party: up to 6 per row in compact, otherwise all in one row
    local maxPartyPerRow = compactParty and 6 or totalChars
    local numPartyRows = math.ceil(totalChars / maxPartyPerRow)
    local charsInFirstRow = math.min(totalChars, maxPartyPerRow)
    local totalPlayerWidth = charsInFirstRow * (playerCardW + 10) - 10
    local playerStartX = x + (w - totalPlayerWidth - 90) / 2

    -- Draw all characters (player + party) with row/col layout
    for charIdx = 0, totalChars - 1 do
        local pRow = math.floor(charIdx / maxPartyPerRow)
        local pCol = charIdx % maxPartyPerRow
        local charsInThisRow = (pRow < numPartyRows - 1) and maxPartyPerRow or (totalChars - pRow * maxPartyPerRow)
        local thisRowWidth = charsInThisRow * (playerCardW + 10) - 10
        local thisRowStartX = x + (w - thisRowWidth - 90) / 2
        local cx = thisRowStartX + pCol * (playerCardW + 10)
        local cy = playerZoneY + pRow * (playerCardH + 6)

        local isPlayer = (charIdx == 0)
        local charData = isPlayer and state.player or party[charIdx]
        local isDead = not isPlayer and ((charData.hp or 0) <= 0)
        local isActing
        if isPlayer then
            isActing = state.combat.isPlayerTurn
        else
            isActing = state.combat.isCompanionTurn and state.combat.currentCompanionIndex == charIdx
        end

        -- Card background
        if isPlayer then
            love.graphics.setColor(isActing and {0.15, 0.3, 0.2} or {0.12, 0.18, 0.15})
        else
            if isDead then
                love.graphics.setColor(0.12, 0.1, 0.1)
            elseif isActing then
                love.graphics.setColor(0.15, 0.22, 0.32)
            else
                love.graphics.setColor(0.1, 0.14, 0.2)
            end
        end
        love.graphics.rectangle("fill", cx, cy, playerCardW, playerCardH, 8, 8)

        -- Acting border
        if isActing then
            love.graphics.setColor(isPlayer and {0.3, 1, 0.4} or {0.4, 0.8, 1})
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", cx, cy, playerCardW, playerCardH, 8, 8)
            love.graphics.setLineWidth(1)
        end

        -- Portrait
        local portraitId
        if isPlayer then
            portraitId = state.player.class and state.player.class.id or "warrior"
        else
            local compClassId = charData.class and charData.class.id or "warrior"
            portraitId = charData.portrait or compClassId
        end
        local portrait = getPortraitImage(portraitId)
        if portrait then
            love.graphics.setColor(isDead and {0.4, 0.4, 0.4} or {1, 1, 1})
            local imgW, imgH = portrait:getDimensions()
            local scale = playerPortraitSize / math.max(imgW, imgH)
            local px = cx + (playerCardW - imgW * scale) / 2
            local py = cy + (compactParty and 4 or 6)
            love.graphics.draw(portrait, px, py, 0, scale, scale)
        else
            local fallbackSize = compactParty and 20 or 28
            love.graphics.setFont(getFont(fallbackSize))
            if isPlayer then
                local combatClassColor = state.player.class and state.player.class.color or {0.7, 0.7, 0.7}
                love.graphics.setColor(combatClassColor)
                love.graphics.printf((state.player.class and state.player.class.id or "warrior"):sub(1,1):upper(), cx, cy + (compactParty and 8 or 15), playerCardW, "center")
            else
                local compClassId = charData.class and charData.class.id or "warrior"
                love.graphics.setColor(isDead and {0.4, 0.4, 0.4} or (charData.color or {0.7, 0.7, 0.7}))
                love.graphics.printf(compClassId:sub(1,1):upper(), cx, cy + (compactParty and 8 or 15), playerCardW, "center")
            end
        end

        -- Name
        love.graphics.setFont(getFont(compactParty and 9 or (isPlayer and 11 or 10)))
        love.graphics.setColor(isPlayer and {0.3, 1, 0.4} or (isDead and {0.5, 0.5, 0.5} or {0.7, 0.85, 1}))
        local nameStr = isPlayer and (state.player.name or "YOU") or charData.name
        love.graphics.printf(nameStr, cx + 4, cy + playerPortraitSize + (compactParty and 2 or 8), playerCardW - 8, "center")

        -- HP bar
        local barW = playerCardW - 16
        local barH = compactParty and 10 or 12
        local barX = cx + 8
        local barY = cy + playerCardH - (compactParty and 22 or 38)
        local hp, maxHP
        if isPlayer then
            hp = state.player.hp or 0
            maxHP = state.player.maxHP or 1
        else
            hp = charData.hp or 0
            maxHP = charData.maxHP or 1
        end
        local hpPct = math.max(0, hp / math.max(1, maxHP))
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", barX, barY, barW, barH, 3, 3)
        if not isDead then
            love.graphics.setColor(hpPct > 0.5 and {0.3, 0.85, 0.3} or (hpPct > 0.25 and {0.85, 0.85, 0.3} or {0.85, 0.3, 0.3}))
            love.graphics.rectangle("fill", barX, barY, barW * hpPct, barH, 3, 3)
        end
        love.graphics.setFont(getFont(compactParty and 8 or 9))
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(math.max(0, hp) .. "/" .. maxHP, barX, barY + 1, barW, "center")

        -- Mana bar (player only, skip in compact mode to save space)
        if isPlayer and not compactParty then
            local manaBarY = barY + 16
            local manaPct = math.max(0, (state.player.mana or 0) / math.max(1, state.player.maxMana or 1))
            love.graphics.setColor(0.2, 0.2, 0.25)
            love.graphics.rectangle("fill", barX, manaBarY, barW, barH - 2, 3, 3)
            love.graphics.setColor(0.3, 0.4, 0.9)
            love.graphics.rectangle("fill", barX, manaBarY, barW * manaPct, barH - 2, 3, 3)
            love.graphics.setFont(getFont(8))
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf((state.player.mana or 0) .. "/" .. (state.player.maxMana or 1), barX, manaBarY, barW, "center")
        end

        -- Dead indicator (companions only)
        if isDead and not isPlayer then
            local deadH = compactParty and 16 or 24
            love.graphics.setColor(0.6, 0.15, 0.15, 0.85)
            love.graphics.rectangle("fill", cx + 10, cy + playerCardH/2 - deadH/2, playerCardW - 20, deadH, 4, 4)
            love.graphics.setColor(0.95, 0.35, 0.35)
            love.graphics.setFont(getFont(compactParty and 10 or 12))
            love.graphics.printf("DOWN", cx, cy + playerCardH/2 - (compactParty and 5 or 8), playerCardW, "center")
        end
    end

    -- TURN ORDER (Right side)
    local initX = x + w - turnOrderW + 5
    local initY = y + 15
    local totalTurns = #state.combat.turnOrder
    local maxTurns = math.min(totalTurns, 12)
    local extraTurns = totalTurns - maxTurns
    local initH = 28 + maxTurns * 18 + (extraTurns > 0 and 18 or 0)

    love.graphics.setColor(0.05, 0.05, 0.08, 0.5)
    love.graphics.rectangle("fill", initX + 2, initY + 2, 75, initH, 5, 5)
    love.graphics.setColor(0.12, 0.14, 0.18, 0.95)
    love.graphics.rectangle("fill", initX, initY, 75, initH, 5, 5)
    love.graphics.setColor(0.35, 0.4, 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", initX, initY, 75, initH, 5, 5)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(0.7, 0.75, 0.85)
    love.graphics.setFont(getFont(9))
    love.graphics.printf("TURN ORDER", initX, initY + 5, 75, "center")

    for i = 1, maxTurns do
        local turn = state.combat.turnOrder[i]
        if turn then
            local iy = initY + 22 + (i - 1) * 18
            local isCurrent = (i == state.combat.currentTurnIndex)

            if isCurrent then
                love.graphics.setColor(0.3, 0.45, 0.35, 0.8)
                love.graphics.rectangle("fill", initX + 4, iy - 1, 67, 16, 3, 3)
            end

            love.graphics.setFont(getFont(8))
            if turn.type == "player" then
                love.graphics.setColor(isCurrent and {0.5, 1, 0.5} or {0.5, 0.8, 0.5})
                love.graphics.print(isCurrent and "> YOU" or "  YOU", initX + 6, iy + 2)
            elseif turn.type == "companion" then
                local companion = state.player.party[turn.index]
                if companion then
                    local isDead = companion.hp <= 0
                    love.graphics.setColor(isDead and {0.4, 0.4, 0.4} or (isCurrent and {0.5, 0.9, 1} or {0.5, 0.7, 0.9}))
                    local name = string.sub(companion.name, 1, 7)
                    love.graphics.print(isCurrent and ("> " .. name) or ("  " .. name), initX + 6, iy + 2)
                end
            else
                local enemy = enemies[turn.index]
                if enemy then
                    local isDead = enemy.hp <= 0
                    love.graphics.setColor(isDead and {0.4, 0.4, 0.4} or (isCurrent and {1, 0.6, 0.4} or {0.85, 0.55, 0.5}))
                    local name = string.sub(enemy.name, 1, 7)
                    love.graphics.print(isCurrent and ("> " .. name) or ("  " .. name), initX + 6, iy + 2)
                end
            end
        end
    end

    -- "+X more" indicator when turn order overflows
    if extraTurns > 0 then
        local moreY = initY + 22 + maxTurns * 18
        love.graphics.setFont(getFont(8))
        love.graphics.setColor(0.5, 0.5, 0.65)
        love.graphics.printf("+" .. extraTurns .. " more", initX, moreY + 2, 75, "center")
    end

    -- ACTION MENU (BOTTOM)
    local actionY = y + h - actionZoneH + 10

    if state.combat.isPlayerTurn then
        love.graphics.setFont(getFont(12))
        love.graphics.setColor(1, 1, 1)
        local actorName = (state.player.name or "YOU"):upper()
        love.graphics.print("What will " .. actorName .. " do?", x + 15, actionY)

        local actions = {
            {name = "FIGHT", key = "Z", color = {0.9, 0.35, 0.35}},
            {name = "SKILLS", key = "X", color = {0.45, 0.5, 0.95}},
            {name = "ITEMS", key = "C", color = {0.3, 0.85, 0.4}},
            {name = "SWAP", key = "B", color = {0.75, 0.4, 0.85}},
            {name = "RUN", key = "V", color = {0.85, 0.85, 0.3}}
        }
        local btnW, btnH = 115, 45
        local btnSpacing = 12
        local totalBtnW = #actions * btnW + (#actions - 1) * btnSpacing
        local btnStartX = x + (w - turnOrderW - totalBtnW) / 2
        local btnY = actionY + 24

        for i, act in ipairs(actions) do
            local bx = btnStartX + (i - 1) * (btnW + btnSpacing)
            local hover = mx >= bx and mx <= bx + btnW and my >= btnY and my <= btnY + btnH

            love.graphics.setColor(0.05, 0.05, 0.08, 0.6)
            love.graphics.rectangle("fill", bx + 3, btnY + 3, btnW, btnH, 6, 6)

            if hover then
                love.graphics.setColor(act.color[1] * 0.8, act.color[2] * 0.8, act.color[3] * 0.8)
            else
                love.graphics.setColor(act.color[1] * 0.5, act.color[2] * 0.5, act.color[3] * 0.5)
            end
            love.graphics.rectangle("fill", bx, btnY, btnW, btnH, 6, 6)

            love.graphics.setColor(1, 1, 1, hover and 0.25 or 0.15)
            love.graphics.rectangle("fill", bx + 3, btnY + 3, btnW - 6, btnH * 0.4, 4, 4)

            love.graphics.setColor(act.color)
            love.graphics.setLineWidth(hover and 3 or 2)
            love.graphics.rectangle("line", bx, btnY, btnW, btnH, 6, 6)
            love.graphics.setLineWidth(1)

            love.graphics.setFont(getFont(13))
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(act.name, bx, btnY + 14, btnW, "center")
        end

        if state.combat.showSkills then
            local skillMenuX = x + 20
            local skillMenuY = actionY - 30
            local skillMenuW = w - turnOrderW - 50
            local availableSkills = getAvailableSkills()
            local skillMenuH = math.min(200, #availableSkills * 32 + 15)

            love.graphics.setColor(0.05, 0.05, 0.08, 0.6)
            love.graphics.rectangle("fill", skillMenuX + 3, skillMenuY + 3, skillMenuW, skillMenuH, 6, 6)
            love.graphics.setColor(0.12, 0.14, 0.18, 0.98)
            love.graphics.rectangle("fill", skillMenuX, skillMenuY, skillMenuW, skillMenuH, 6, 6)
            love.graphics.setColor(0.45, 0.5, 0.95)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", skillMenuX, skillMenuY, skillMenuW, skillMenuH, 6, 6)
            love.graphics.setLineWidth(1)

            love.graphics.setFont(getFont(11))
            love.graphics.setColor(0.7, 0.75, 0.85)
            love.graphics.print("Select a Skill:", skillMenuX + 10, skillMenuY + 6)

            for i, skillName in ipairs(availableSkills) do
                local skill = SKILLS[skillName]
                if skill then
                    local sy = skillMenuY + 25 + (i - 1) * 32
                    local skillHover = mx >= skillMenuX + 8 and mx <= skillMenuX + skillMenuW - 8
                                       and my >= sy and my <= sy + 28
                    local canAfford = state.player.mana >= skill.manaCost

                    if skillHover and canAfford then
                        love.graphics.setColor(0.35, 0.4, 0.6)
                    else
                        love.graphics.setColor(0.18, 0.2, 0.28)
                    end
                    love.graphics.rectangle("fill", skillMenuX + 8, sy, skillMenuW - 16, 28, 4, 4)

                    love.graphics.setColor(canAfford and {0.5, 0.6, 0.8} or {0.4, 0.4, 0.45})
                    love.graphics.setLineWidth(1)
                    love.graphics.rectangle("line", skillMenuX + 8, sy, skillMenuW - 16, 28, 4, 4)

                    love.graphics.setFont(getFont(11))
                    love.graphics.setColor(canAfford and {1, 1, 1} or {0.5, 0.5, 0.5})
                    love.graphics.print(skillName, skillMenuX + 16, sy + 7)

                    love.graphics.setFont(getFont(9))
                    love.graphics.setColor(canAfford and {0.4, 0.7, 1} or {0.4, 0.4, 0.45})
                    love.graphics.print(skill.manaCost .. " MP", skillMenuX + skillMenuW - 55, sy + 9)
                end
            end
        end

        if state.combat.showWeaponSwap then
            local swapMenuX = x + 20
            local swapMenuY = actionY - 30
            local swapMenuW = w - turnOrderW - 50

            local weaponItems = {}
            local allItems = Backpack.getAllItems()
            for _, item in ipairs(allItems) do
                if item.def.category == "tq_weapon" or item.def.category == "weapon" then
                    table.insert(weaponItems, item)
                end
            end

            local swapMenuH = math.min(200, #weaponItems * 32 + 15)

            love.graphics.setColor(0.05, 0.05, 0.08, 0.6)
            love.graphics.rectangle("fill", swapMenuX + 3, swapMenuY + 3, swapMenuW, swapMenuH, 6, 6)
            love.graphics.setColor(0.12, 0.14, 0.18, 0.98)
            love.graphics.rectangle("fill", swapMenuX, swapMenuY, swapMenuW, swapMenuH, 6, 6)
            love.graphics.setColor(0.75, 0.4, 0.85)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", swapMenuX, swapMenuY, swapMenuW, swapMenuH, 6, 6)
            love.graphics.setLineWidth(1)

            love.graphics.setFont(getFont(11))
            love.graphics.setColor(0.85, 0.7, 0.9)
            love.graphics.print("Swap Weapon (uses turn):", swapMenuX + 10, swapMenuY + 6)

            for i, item in ipairs(weaponItems) do
                local sy = swapMenuY + 25 + (i - 1) * 32
                local weaponHover = mx >= swapMenuX + 8 and mx <= swapMenuX + swapMenuW - 8
                                   and my >= sy and my <= sy + 28
                local def = item.def
                local currentlyEquipped = state.player.equipment.weapon and state.player.equipment.weapon.backpackId == item.id

                if weaponHover and not currentlyEquipped then
                    love.graphics.setColor(0.4, 0.35, 0.5)
                elseif currentlyEquipped then
                    love.graphics.setColor(0.25, 0.3, 0.25)
                else
                    love.graphics.setColor(0.18, 0.2, 0.28)
                end
                love.graphics.rectangle("fill", swapMenuX + 8, sy, swapMenuW - 16, 28, 4, 4)

                love.graphics.setColor(currentlyEquipped and {0.3, 0.8, 0.3} or {0.65, 0.5, 0.75})
                love.graphics.setLineWidth(1)
                love.graphics.rectangle("line", swapMenuX + 8, sy, swapMenuW - 16, 28, 4, 4)

                love.graphics.setFont(getFont(11))
                if currentlyEquipped then
                    love.graphics.setColor(0.5, 1, 0.5)
                    love.graphics.print(def.name .. " (Equipped)", swapMenuX + 16, sy + 7)
                else
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.print(def.name, swapMenuX + 16, sy + 7)
                end

                love.graphics.setFont(getFont(9))
                love.graphics.setColor(0.7, 0.7, 0.8)
                local weaponType = def.weaponType or "melee"
                local attack = def.baseStats and def.baseStats.attack or 0
                love.graphics.print(weaponType .. " | ATK:" .. attack, swapMenuX + swapMenuW - 120, sy + 9)
            end
        end
    elseif isManualCompTurn then
        -- Manual companion turn: show action buttons the player can click
        local companion = state.player.party[state.combat.currentCompanionIndex]
        if companion then
            love.graphics.setFont(getFont(12))
            love.graphics.setColor(0.5, 0.95, 1)
            love.graphics.print("What will " .. companion.name .. " do?", x + 15, actionY)

            local compActions = {
                {name = "ATTACK", key = "1", color = {0.9, 0.35, 0.35}},
                {name = companion.canHeal and "HEAL" or "DEFEND", key = "2", color = {0.3, 0.7, 0.85}},
                {name = "AUTO", key = "3", color = {0.3, 0.75, 0.3}},
                {name = "AUTO ALL", key = "4", color = {0.2, 0.6, 0.2}},
            }
            local btnW, btnH = 110, 45
            local btnSpacing = 10
            local totalBtnW = #compActions * btnW + (#compActions - 1) * btnSpacing
            local btnStartX = x + (w - turnOrderW - totalBtnW) / 2
            local btnY = actionY + 24

            for i, act in ipairs(compActions) do
                local bx = btnStartX + (i - 1) * (btnW + btnSpacing)
                local hover = mx >= bx and mx <= bx + btnW and my >= btnY and my <= btnY + btnH

                love.graphics.setColor(0.05, 0.05, 0.08, 0.6)
                love.graphics.rectangle("fill", bx + 3, btnY + 3, btnW, btnH, 6, 6)

                if hover then
                    love.graphics.setColor(act.color[1] * 0.8, act.color[2] * 0.8, act.color[3] * 0.8)
                else
                    love.graphics.setColor(act.color[1] * 0.5, act.color[2] * 0.5, act.color[3] * 0.5)
                end
                love.graphics.rectangle("fill", bx, btnY, btnW, btnH, 6, 6)

                love.graphics.setColor(1, 1, 1, hover and 0.25 or 0.15)
                love.graphics.rectangle("fill", bx + 3, btnY + 3, btnW - 6, btnH * 0.4, 4, 4)

                love.graphics.setColor(act.color)
                love.graphics.setLineWidth(hover and 3 or 2)
                love.graphics.rectangle("line", bx, btnY, btnW, btnH, 6, 6)
                love.graphics.setLineWidth(1)

                love.graphics.setFont(getFont(13))
                love.graphics.setColor(1, 1, 1)
                love.graphics.printf(act.name, bx, btnY + 14, btnW, "center")
            end
        end
    elseif state.combat.isCompanionTurn then
        local companion = state.player.party[state.combat.currentCompanionIndex]
        if companion then
            love.graphics.setFont(getFont(12))
            love.graphics.setColor(0.5, 0.85, 1)
            love.graphics.printf(companion.name .. " is taking their turn...", x + 15, actionY + 35, w - turnOrderW - 30, "center")
        end
    else
        local actor = enemies[state.combat.currentActorIndex]
        if actor then
            love.graphics.setFont(getFont(12))
            love.graphics.setColor(1, 0.6, 0.4)
            love.graphics.printf("Enemy " .. actor.name .. " is attacking!", x + 15, actionY + 35, w - turnOrderW - 30, "center")
        end
    end

    -- Persistent Auto-Party toggle (visible during all combat phases when party exists)
    if state.player.party and #state.player.party > 0 then
        local allAuto = true
        for _, c in ipairs(state.player.party) do
            if not c.autoBattle then allAuto = false; break end
        end
        local toggleW, toggleH = 120, 26
        local toggleX = x + w - turnOrderW - toggleW - 10
        local toggleY = y + 4
        local toggleHover = mx >= toggleX and mx <= toggleX + toggleW and my >= toggleY and my <= toggleY + toggleH
        state.combat.autoPartyToggle = {x = toggleX, y = toggleY, w = toggleW, h = toggleH}

        love.graphics.setColor(toggleHover and (allAuto and {0.35, 0.5, 0.25} or {0.25, 0.35, 0.25}) or (allAuto and {0.25, 0.4, 0.18} or {0.18, 0.25, 0.18}))
        love.graphics.rectangle("fill", toggleX, toggleY, toggleW, toggleH, 4, 4)
        love.graphics.setColor(allAuto and {0.5, 1, 0.5} or {0.4, 0.6, 0.4})
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", toggleX, toggleY, toggleW, toggleH, 4, 4)
        love.graphics.setFont(getFont(11))
        love.graphics.setColor(allAuto and {0.7, 1, 0.7} or {0.5, 0.7, 0.5})
        love.graphics.printf("Auto Party: " .. (allAuto and "ON" or "OFF"), toggleX, toggleY + 6, toggleW, "center")
    end
end

-- ============================================================================
-- DIALOGUE / NPC / TAVERN / GUILD DRAWS
-- ============================================================================

M.drawDialogue = function(x, y, w, h, mx, my)
    local getPortraitImage = F.getPortraitImage or function() return nil end
    local npc = state.dialogue.npc

    love.graphics.setColor(0.12, 0.15, 0.2)
    love.graphics.rectangle("fill", x + 20, y + 20, 100, 120, 8, 8)

    local portraitImg = getPortraitImage(npc.profession.id)
    if portraitImg then
        love.graphics.setColor(1, 1, 1)
        local imgW, imgH = portraitImg:getDimensions()
        local scale = math.min(90 / imgW, 80 / imgH)
        local drawX = x + 25 + (90 - imgW * scale) / 2
        local drawY = y + 25 + (80 - imgH * scale) / 2
        love.graphics.draw(portraitImg, drawX, drawY, 0, scale, scale)
    else
        love.graphics.setColor(npc.profession.color)
        love.graphics.setFont(getFont(48))
        love.graphics.printf(npc.profession.icon, x + 20, y + 35, 100, "center")
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(11))
    love.graphics.printf(npc.name, x + 20, y + 105, 100, "center")
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.setFont(getFont(9))
    love.graphics.printf(npc.profession.title, x + 20, y + 120, 100, "center")

    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(16))
    love.graphics.print(npc.name .. " the " .. npc.profession.title, x + 140, y + 25)

    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.setFont(getFont(13))
    love.graphics.printf('"' .. state.dialogue.text .. '"', x + 140, y + 55, w - 170, "left")

    local optY = y + 150
    for i, opt in ipairs(state.dialogue.options) do
        local oy = optY + (i - 1) * 40
        local hover = mx >= x + 40 and mx <= x + w - 40 and my >= oy and my <= oy + 35

        love.graphics.setColor(hover and {0.3, 0.35, 0.45} or {0.18, 0.2, 0.28})
        love.graphics.rectangle("fill", x + 40, oy, w - 80, 35, 5, 5)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(12))
        love.graphics.printf(opt.text, x + 40, oy + 10, w - 80, "center")
    end
end

M.drawNPCList = function(x, y, w, h, mx, my)
    local getPortraitImage = F.getPortraitImage or function() return nil end
    local generateNPCState = F.generateNPCState or function() end
    local town = state.world.currentTown
    if not town then return end

    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(18))
    love.graphics.printf("Townsfolk of " .. town.name, x, y + 10, w, "center")

    local npcY = y + 50
    for i, npc in ipairs(town.npcs) do
        if not npc.dialogueState then
            generateNPCState(npc)
        end
        local ny = npcY + (i - 1) * 55
        local hover = mx >= x + 20 and mx <= x + w - 20 and my >= ny and my <= ny + 50

        love.graphics.setColor(hover and {0.2, 0.25, 0.35} or {0.12, 0.15, 0.2})
        love.graphics.rectangle("fill", x + 20, ny, w - 40, 50, 6, 6)

        local portraitImg = getPortraitImage(npc.profession.id)
        if portraitImg then
            love.graphics.setColor(1, 1, 1)
            local imgW, imgH = portraitImg:getDimensions()
            local scale = math.min(40 / imgW, 40 / imgH)
            local drawX = x + 28 + (40 - imgW * scale) / 2
            local drawY = ny + 5 + (40 - imgH * scale) / 2
            love.graphics.draw(portraitImg, drawX, drawY, 0, scale, scale)
        else
            love.graphics.setColor(npc.profession.color)
            love.graphics.setFont(getFont(24))
            love.graphics.print(npc.profession.icon, x + 35, ny + 10)
        end

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(13))
        love.graphics.print(npc.name, x + 80, ny + 8)

        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.setFont(getFont(11))
        love.graphics.print(npc.profession.title, x + 80, ny + 26)

        local indicatorX = x + w - 150
        if npc.hasQuest then
            love.graphics.setColor(0.9, 0.7, 0.2)
            love.graphics.setFont(getFont(12))
            love.graphics.print("[Quest]", indicatorX, ny + 8)
            indicatorX = indicatorX + 55
        end
        if npc.dialogueState and npc.dialogueState.isSick and not npc.dialogueState.healQuestGiven then
            love.graphics.setColor(0.7, 0.3, 0.3)
            love.graphics.setFont(getFont(12))
            love.graphics.print("[Sick]", indicatorX, ny + 8)
        end
        if npc.dialogueState and npc.dialogueState.mood then
            love.graphics.setColor(0.5, 0.5, 0.6)
            love.graphics.setFont(getFont(9))
            love.graphics.print("(" .. npc.dialogueState.mood .. ")", x + 80, ny + 38)
        end
    end

    local backY = y + h - 45
    local backHover = mx >= x + w/2 - 50 and mx <= x + w/2 + 50 and my >= backY and my <= backY + 35
    love.graphics.setColor(backHover and {0.4, 0.35, 0.3} or {0.25, 0.22, 0.2})
    love.graphics.rectangle("fill", x + w/2 - 50, backY, 100, 35, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Back", x + w/2 - 50, backY + 10, 100, "center")
end

M.drawTavernInterior = function(x, y, w, h, mx, my)
    local town = state.world.currentTown
    if not town then return end

    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(20))
    love.graphics.printf("The Tavern", x, y + 10, w, "center")

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("The tavern is warm and inviting. Patrons chat over ale and hearty meals.", x + 40, y + 50, w - 80, "center")

    local buttonW = 220
    local buttonH = 80
    local spacing = 20
    local startY = y + 120
    local centerX = x + w/2

    local buttons = {
        {id = "work", label = "Work Shift", icon = "☕", desc = "Serve customers at the cafe", gridX = 0, gridY = 0},
        {id = "talk", label = "Talk to NPCs", icon = "💬", desc = "Chat with townsfolk", gridX = 1, gridY = 0},
        {id = "rest", label = "Rent Room", icon = "🛏️", desc = "Rest & recover (20g)", gridX = 0, gridY = 1},
        {id = "poker", label = "Play Poker", icon = "🃏", desc = "Play cards against NPCs", gridX = 0, gridY = 2},
        {id = "collection", label = "Collection", icon = "📚", desc = "View your card collection", gridX = 1, gridY = 2},
        {id = "lootboxes", label = "Loot Boxes", icon = "🎁", desc = "Open card packs", gridX = 0, gridY = 3},
        {id = "deckeditor", label = "Deck Editor", icon = "✏️", desc = "Build & edit your decks", gridX = 1, gridY = 3},
    }

    for _, btn in ipairs(buttons) do
        local bx = centerX - buttonW - spacing/2 + btn.gridX * (buttonW + spacing)
        local by = startY + btn.gridY * (buttonH + spacing)
        local hover = mx >= bx and mx <= bx + buttonW and my >= by and my <= by + buttonH and not btn.disabled

        if btn.disabled then
            love.graphics.setColor(0.15, 0.15, 0.15)
        else
            love.graphics.setColor(hover and {0.3, 0.3, 0.4} or {0.2, 0.2, 0.3})
        end
        love.graphics.rectangle("fill", bx, by, buttonW, buttonH, 8, 8)

        if hover then love.graphics.setColor(0.6, 0.6, 0.7) else love.graphics.setColor(0.3, 0.3, 0.4) end
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", bx, by, buttonW, buttonH, 8, 8)

        love.graphics.setColor(btn.disabled and {0.3, 0.3, 0.3} or {0.9, 0.8, 0.6})
        love.graphics.setFont(getFont(32))
        love.graphics.printf(btn.icon, bx, by + 8, buttonW, "center")

        love.graphics.setColor(btn.disabled and {0.4, 0.4, 0.4} or {1, 1, 1})
        love.graphics.setFont(getFont(14))
        love.graphics.printf(btn.label, bx, by + 48, buttonW, "center")

        love.graphics.setColor(btn.disabled and {0.3, 0.3, 0.3} or {0.6, 0.6, 0.6})
        love.graphics.setFont(getFont(10))
        love.graphics.printf(btn.desc, bx, by + 66, buttonW, "center")

        btn.x = bx; btn.y = by; btn.w = buttonW; btn.h = buttonH
    end

    state.tavernButtons = buttons

    local leaveY = y + h - 60
    local leaveHover = mx >= centerX - 80 and mx <= centerX + 80 and my >= leaveY and my <= leaveY + 40
    love.graphics.setColor(leaveHover and {0.4, 0.35, 0.3} or {0.25, 0.22, 0.2})
    love.graphics.rectangle("fill", centerX - 80, leaveY, 160, 40, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(14))
    love.graphics.printf("Leave", centerX - 80, leaveY + 12, 160, "center")
    state.tavernLeaveButton = {x = centerX - 80, y = leaveY, w = 160, h = 40}
end

M.drawJobBoard = function(x, y, w, h, mx, my)
    local town = state.world.currentTown
    if not town then return end

    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(18))
    love.graphics.printf("[J] Job Board - " .. town.name, x, y + 10, w, "center")

    if #town.jobBoard == 0 then
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.setFont(getFont(13))
        love.graphics.printf("No jobs available. Check back later!", x, y + 100, w, "center")
    else
        local questY = y + 50
        for i, quest in ipairs(town.jobBoard) do
            if i <= 5 then
                local qy = questY + (i - 1) * 70
                local hover = mx >= x + 20 and mx <= x + w - 20 and my >= qy and my <= qy + 65

                love.graphics.setColor(hover and {0.2, 0.25, 0.35} or {0.12, 0.15, 0.2})
                love.graphics.rectangle("fill", x + 20, qy, w - 40, 65, 6, 6)

                love.graphics.setColor(0.9, 0.7, 0.2)
                love.graphics.setFont(getFont(13))
                love.graphics.print(quest.name .. " (Lv." .. quest.level .. ")", x + 35, qy + 8)

                love.graphics.setColor(0.7, 0.7, 0.7)
                love.graphics.setFont(getFont(10))
                love.graphics.printf(quest.desc, x + 35, qy + 28, w - 80, "left")

                love.graphics.setColor(1, 0.9, 0.3)
                love.graphics.printf(quest.rewardGold .. "g  " .. quest.rewardXP .. "xp", x + 20, qy + 45, w - 60, "right")
            end
        end
    end

    local backY = y + h - 45
    local backHover = mx >= x + w/2 - 50 and mx <= x + w/2 + 50 and my >= backY and my <= backY + 35
    love.graphics.setColor(backHover and {0.4, 0.35, 0.3} or {0.25, 0.22, 0.2})
    love.graphics.rectangle("fill", x + w/2 - 50, backY, 100, 35, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Back", x + w/2 - 50, backY + 10, 100, "center")
end

M.drawGuildInterior = function(x, y, w, h, mx, my)
    local town = state.world.currentTown
    if not town then return end
    local PlayerData = F.PlayerData or (require("main") and _G.PlayerData) or {}

    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(20))
    love.graphics.printf("The Adventurer's Guild", x, y + 10, w, "center")

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("The guild hall bustles with activity. Adventurers gather around the quest board and recruitment desk.", x + 40, y + 50, w - 80, "center")

    local buttonW = 220
    local buttonH = 80
    local spacing = 20
    local startY = y + 150
    local centerX = x + w/2

    local hasStash = PlayerData.deathStash and ((PlayerData.deathStash.gold or 0) > 0 or (PlayerData.deathStash.items and #PlayerData.deathStash.items > 0))
    local hasGraveyard = PlayerData.textRPGGraveyard and #PlayerData.textRPGGraveyard > 0

    local buttons = {
        {id = "questboard", label = "Quest Board", icon = "📋", desc = "Check available quests", gridX = 0, gridY = 0},
        {id = "recruitment", label = "Recruitment", icon = "⚔️", desc = "Hire companions", gridX = 1, gridY = 0},
    }

    if hasStash then
        local stashGold = PlayerData.deathStash.gold or 0
        local stashCount = PlayerData.deathStash.items and #PlayerData.deathStash.items or 0
        table.insert(buttons, {id = "retrieve_stash", label = "Retrieve Belongings", icon = "💰", desc = stashGold .. "g + " .. stashCount .. " items stored", gridX = 0, gridY = 1})
    end

    if hasGraveyard then
        table.insert(buttons, {id = "revive_hero", label = "Revive Fallen Hero", icon = "🪦", desc = #PlayerData.textRPGGraveyard .. " heroes in graveyard", gridX = 1, gridY = 1})
    end

    for _, btn in ipairs(buttons) do
        local bx = centerX - buttonW - spacing/2 + btn.gridX * (buttonW + spacing)
        local by = startY + (btn.gridY or 0) * (buttonH + spacing)
        local hover = mx >= bx and mx <= bx + buttonW and my >= by and my <= by + buttonH and not btn.disabled

        love.graphics.setColor(btn.disabled and {0.15, 0.15, 0.15} or (hover and {0.3, 0.3, 0.4} or {0.2, 0.2, 0.3}))
        love.graphics.rectangle("fill", bx, by, buttonW, buttonH, 8, 8)

        love.graphics.setColor(hover and {0.6, 0.6, 0.7} or {0.3, 0.3, 0.4})
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", bx, by, buttonW, buttonH, 8, 8)

        love.graphics.setColor(btn.disabled and {0.3, 0.3, 0.3} or {0.9, 0.8, 0.6})
        love.graphics.setFont(getFont(32))
        love.graphics.printf(btn.icon, bx, by + 8, buttonW, "center")

        love.graphics.setColor(btn.disabled and {0.4, 0.4, 0.4} or {1, 1, 1})
        love.graphics.setFont(getFont(14))
        love.graphics.printf(btn.label, bx, by + 48, buttonW, "center")

        love.graphics.setColor(btn.disabled and {0.3, 0.3, 0.3} or {0.6, 0.6, 0.6})
        love.graphics.setFont(getFont(10))
        love.graphics.printf(btn.desc, bx, by + 66, buttonW, "center")

        btn.x = bx; btn.y = by; btn.w = buttonW; btn.h = buttonH
    end

    state.guildButtons = buttons

    local leaveY = y + h - 60
    local leaveHover = mx >= centerX - 80 and mx <= centerX + 80 and my >= leaveY and my <= leaveY + 40
    love.graphics.setColor(leaveHover and {0.4, 0.35, 0.3} or {0.25, 0.22, 0.2})
    love.graphics.rectangle("fill", centerX - 80, leaveY, 160, 40, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(14))
    love.graphics.printf("Leave", centerX - 80, leaveY + 12, 160, "center")
    state.guildLeaveButton = {x = centerX - 80, y = leaveY, w = 160, h = 40}
end

M.drawReviveHero = function(x, y, w, h, mx, my)
    if not state.player then return end
    local PlayerData = F.PlayerData or (require("main") and _G.PlayerData) or {}
    local graveyard = PlayerData.textRPGGraveyard or {}

    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(20))
    love.graphics.printf("Revive Fallen Heroes", x, y + 10, w, "center")

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("The guild's clerics can resurrect fallen heroes as companions. Cost scales with their level.", x + 40, y + 40, w - 80, "center")

    if #graveyard == 0 then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.setFont(getFont(14))
        love.graphics.printf("No fallen heroes to revive.", x, y + 120, w, "center")
        local backY = y + h - 60
        local centerX = x + w/2
        local backHover = mx >= centerX - 80 and mx <= centerX + 80 and my >= backY and my <= backY + 40
        love.graphics.setColor(backHover and {0.4, 0.35, 0.3} or {0.25, 0.22, 0.2})
        love.graphics.rectangle("fill", centerX - 80, backY, 160, 40, 5, 5)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(14))
        love.graphics.printf("Back", centerX - 80, backY + 12, 160, "center")
        state.reviveBackButton = {x = centerX - 80, y = backY, w = 160, h = 40}
        state.reviveButtons = {}
        return
    end

    love.graphics.setColor(1, 0.85, 0.2)
    love.graphics.setFont(getFont(14))
    love.graphics.printf("Your Gold: " .. (state.player.gold or 0) .. "g", x, y + 70, w - 20, "right")

    local partySize = state.player.party and #state.player.party or 0
    local maxParty = state.player.maxPartySize or 99
    local partyFull = partySize >= maxParty

    if partyFull then
        love.graphics.setColor(0.9, 0.4, 0.3)
        love.graphics.setFont(getFont(12))
        love.graphics.printf("Party is full! (" .. partySize .. "/" .. maxParty .. ") - Dismiss a companion first.", x + 20, y + 70, w - 40, "left")
    end

    local listY = y + 95
    local cardH = 75
    local cardSpacing = 8
    local maxVisible = math.floor((h - 170) / (cardH + cardSpacing))
    local scroll = state.reviveScroll or 0

    state.reviveButtons = {}

    for i = 1, math.min(maxVisible, #graveyard - scroll) do
        local idx = #graveyard - scroll - i + 1
        if idx < 1 then break end
        local hero = graveyard[idx]
        local cy = listY + (i - 1) * (cardH + cardSpacing)

        local reviveCost = 50 + (hero.level or 1) * 25
        local canAfford = (state.player.gold or 0) >= reviveCost
        local canRevive = canAfford and not partyFull

        local cardHover = mx >= x + 20 and mx <= x + w - 20 and my >= cy and my <= cy + cardH
        if canRevive and cardHover then love.graphics.setColor(0.25, 0.3, 0.2)
        elseif canRevive then love.graphics.setColor(0.18, 0.18, 0.25)
        else love.graphics.setColor(0.12, 0.12, 0.15) end
        love.graphics.rectangle("fill", x + 20, cy, w - 40, cardH, 6, 6)

        if canRevive and cardHover then love.graphics.setColor(0.5, 0.8, 0.4)
        else love.graphics.setColor(0.3, 0.3, 0.35) end
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x + 20, cy, w - 40, cardH, 6, 6)

        love.graphics.setColor(canRevive and {1, 1, 1} or {0.5, 0.5, 0.5})
        love.graphics.setFont(getFont(14))
        love.graphics.printf(hero.name .. " the " .. (hero.class or "Unknown"), x + 30, cy + 8, w - 200, "left")

        love.graphics.setColor(canRevive and {0.7, 0.7, 0.9} or {0.4, 0.4, 0.5})
        love.graphics.setFont(getFont(12))
        love.graphics.printf("Level " .. (hero.level or 1), x + 30, cy + 28, 100, "left")

        love.graphics.setColor(0.5, 0.4, 0.4)
        love.graphics.setFont(getFont(10))
        love.graphics.printf("Slain by " .. (hero.killedBy or "Unknown") .. " in " .. (hero.location or "unknown"), x + 30, cy + 46, w - 200, "left")

        love.graphics.setColor(0.4, 0.4, 0.5)
        love.graphics.printf((hero.enemiesDefeated or 0) .. " kills | " .. (hero.questsCompleted or 0) .. " quests | " .. (hero.daysSurvived or 0) .. " days", x + 30, cy + 58, w - 200, "left")

        local btnX = x + w - 150
        local btnY = cy + 15
        local btnW = 120
        local btnH = 45
        local btnHover = canRevive and mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH

        love.graphics.setColor(canRevive and (btnHover and {0.3, 0.6, 0.3} or {0.2, 0.45, 0.2}) or {0.15, 0.15, 0.15})
        love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 5, 5)

        love.graphics.setColor(canRevive and {1, 1, 1} or {0.4, 0.4, 0.4})
        love.graphics.setFont(getFont(12))
        love.graphics.printf("Revive", btnX, btnY + 5, btnW, "center")

        love.graphics.setColor(canAfford and {1, 0.85, 0.2} or {0.6, 0.3, 0.3})
        love.graphics.setFont(getFont(11))
        love.graphics.printf(reviveCost .. "g", btnX, btnY + 24, btnW, "center")

        table.insert(state.reviveButtons, {x = btnX, y = btnY, w = btnW, h = btnH, graveyardIdx = idx, cost = reviveCost, canRevive = canRevive})
    end

    if scroll > 0 then
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.setFont(getFont(12))
        love.graphics.printf("^ Scroll up for more ^", x, listY - 15, w, "center")
    end
    if #graveyard - scroll > maxVisible then
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.setFont(getFont(12))
        love.graphics.printf("v Scroll down for more v", x, listY + maxVisible * (cardH + cardSpacing), w, "center")
    end

    local backY = y + h - 60
    local centerX = x + w/2
    local backHover = mx >= centerX - 80 and mx <= centerX + 80 and my >= backY and my <= backY + 40
    love.graphics.setColor(backHover and {0.4, 0.35, 0.3} or {0.25, 0.22, 0.2})
    love.graphics.rectangle("fill", centerX - 80, backY, 160, 40, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(14))
    love.graphics.printf("Back", centerX - 80, backY + 12, 160, "center")
    state.reviveBackButton = {x = centerX - 80, y = backY, w = 160, h = 40}
end

-- ============================================================================
-- BUILDING INTERIOR / NPC DIALOGUE / DEATH / GRAVEYARD
-- ============================================================================

M.drawBuildingInterior = function(x, y, w, h, mx, my)
    local town = state.world.currentTown
    if not town or not state.buildingInterior then return end

    local building = state.buildingInterior.building
    local npcs = state.buildingInterior.npcs or {}
    local map = state.buildingInterior.map
    if not map then return end

    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(20))
    love.graphics.printf(building.name, x, y + 10, w, "center")

    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.setFont(getFont(11))
    love.graphics.printf("WASD/Arrows to move | E to talk | Esc to leave", x, y + 35, w, "center")

    local mapStartY = y + 60
    local mapHeight = h - 120
    local tileSize = math.min(60, math.floor(mapHeight / map.height))
    local mapWidth = tileSize * map.width
    local mapStartX = x + w/2 - mapWidth/2

    for gy = 1, map.height do
        for gx = 1, map.width do
            local tx = mapStartX + (gx - 1) * tileSize
            local ty = mapStartY + (gy - 1) * tileSize
            if (gx + gy) % 2 == 0 then love.graphics.setColor(0.25, 0.20, 0.15) else love.graphics.setColor(0.22, 0.18, 0.13) end
            love.graphics.rectangle("fill", tx, ty, tileSize, tileSize)
            love.graphics.setColor(0.3, 0.25, 0.2, 0.3)
            love.graphics.setLineWidth(1)
            love.graphics.rectangle("line", tx, ty, tileSize, tileSize)
        end
    end

    love.graphics.setColor(0.4, 0.35, 0.3)
    love.graphics.setLineWidth(4)
    love.graphics.line(mapStartX, mapStartY, mapStartX + mapWidth, mapStartY)
    love.graphics.line(mapStartX, mapStartY + map.height * tileSize, mapStartX + mapWidth, mapStartY + map.height * tileSize)
    love.graphics.line(mapStartX, mapStartY, mapStartX, mapStartY + map.height * tileSize)
    love.graphics.line(mapStartX + mapWidth, mapStartY, mapStartX + mapWidth, mapStartY + map.height * tileSize)
    love.graphics.setLineWidth(1)

    if map.furniture then
        for _, furn in ipairs(map.furniture) do
            local tx = mapStartX + (furn.x - 1) * tileSize
            local ty = mapStartY + (furn.y - 1) * tileSize
            love.graphics.setColor(0.3, 0.25, 0.2, 0.5)
            love.graphics.rectangle("fill", tx + 2, ty + 2, tileSize - 4, tileSize - 4, 3, 3)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(getFont(math.floor(tileSize * 0.6)))
            local spriteW = love.graphics.getFont():getWidth(furn.sprite)
            love.graphics.print(furn.sprite, tx + tileSize/2 - spriteW/2, ty + tileSize/2 - love.graphics.getFont():getHeight()/2)
        end
    end

    local chests = state.buildingInterior.chests or {}
    for _, chest in ipairs(chests) do
        local tx = mapStartX + (chest.x - 1) * tileSize
        local ty = mapStartY + (chest.y - 1) * tileSize
        if not chest.looted then
            love.graphics.setColor(0.8, 0.7, 0.3, 0.3)
            love.graphics.circle("fill", tx + tileSize/2, ty + tileSize/2, tileSize * 0.5)
        end
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(math.floor(tileSize * 0.7)))
        local chestSprite = chest.looted and "📭" or "📦"
        local spriteW = love.graphics.getFont():getWidth(chestSprite)
        love.graphics.print(chestSprite, tx + tileSize/2 - spriteW/2, ty + tileSize/2 - love.graphics.getFont():getHeight()/2)
    end

    for _, npc in ipairs(npcs) do
        if npc.interiorX and npc.interiorY then
            local tx = mapStartX + (npc.interiorX - 1) * tileSize
            local ty = mapStartY + (npc.interiorY - 1) * tileSize
            love.graphics.setColor(0.6, 0.6, 0.8, 0.3)
            love.graphics.circle("fill", tx + tileSize/2, ty + tileSize/2, tileSize * 0.4)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(getFont(math.floor(tileSize * 0.7)))
            local spriteW = love.graphics.getFont():getWidth(npc.sprite)
            love.graphics.print(npc.sprite, tx + tileSize/2 - spriteW/2, ty + tileSize/2 - love.graphics.getFont():getHeight()/2)
            love.graphics.setColor(0.9, 0.9, 1, 0.9)
            love.graphics.setFont(getFont(8))
            love.graphics.printf(npc.name, tx - 10, ty - 12, tileSize + 20, "center")
        end
    end

    local playerX = state.buildingInterior.playerX
    local playerY = state.buildingInterior.playerY
    local tx = mapStartX + (playerX - 1) * tileSize
    local ty = mapStartY + (playerY - 1) * tileSize

    local pulse = 0.7 + 0.3 * math.sin(love.timer.getTime() * 5)
    love.graphics.setColor(0.2 * pulse, 0.8 * pulse, 0.3 * pulse, 0.5)
    love.graphics.circle("fill", tx + tileSize/2, ty + tileSize/2, tileSize * 0.45)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(math.floor(tileSize * 0.8)))
    local playerSprite = "🧍"
    local spriteW = love.graphics.getFont():getWidth(playerSprite)
    love.graphics.print(playerSprite, tx + tileSize/2 - spriteW/2, ty + tileSize/2 - love.graphics.getFont():getHeight()/2)

    local nearNPC = nil
    for _, npc in ipairs(npcs) do
        if npc.interiorX and npc.interiorY then
            local dx = math.abs(npc.interiorX - playerX)
            local dy = math.abs(npc.interiorY - playerY)
            if dx <= 1 and dy <= 1 and (dx + dy) > 0 then nearNPC = npc; break end
        end
    end

    local nearChest = nil
    for _, chest in ipairs(chests) do
        local dx = math.abs(chest.x - playerX)
        local dy = math.abs(chest.y - playerY)
        if dx <= 1 and dy <= 1 and (dx + dy) > 0 and not chest.looted then nearChest = chest; break end
    end

    if nearNPC then
        love.graphics.setColor(0.2, 0.25, 0.3, 0.95)
        local promptW = 250; local promptH = 50
        local promptX = x + w/2 - promptW/2
        local promptY = mapStartY + map.height * tileSize + 10
        love.graphics.rectangle("fill", promptX, promptY, promptW, promptH, 5, 5)
        love.graphics.setColor(0.6, 0.7, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", promptX, promptY, promptW, promptH, 5, 5)
        love.graphics.setColor(0.9, 0.9, 1)
        love.graphics.setFont(getFont(14))
        love.graphics.printf("Press E to talk to " .. nearNPC.name, promptX, promptY + 17, promptW, "center")
        love.graphics.setLineWidth(1)
    elseif nearChest then
        love.graphics.setColor(0.25, 0.2, 0.15, 0.95)
        local promptW = 250; local promptH = 50
        local promptX = x + w/2 - promptW/2
        local promptY = mapStartY + map.height * tileSize + 10
        love.graphics.rectangle("fill", promptX, promptY, promptW, promptH, 5, 5)
        love.graphics.setColor(0.8, 0.7, 0.3)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", promptX, promptY, promptW, promptH, 5, 5)
        love.graphics.setColor(1, 0.9, 0.5)
        love.graphics.setFont(getFont(14))
        love.graphics.printf("Press E to loot chest", promptX, promptY + 17, promptW, "center")
        love.graphics.setLineWidth(1)
    end

    state.buildingInteriorNearNPC = nearNPC
    state.buildingInteriorNearChest = nearChest

    local centerX = x + w/2
    local leaveY = y + h - 50
    local leaveHover = mx >= centerX - 80 and mx <= centerX + 80 and my >= leaveY and my <= leaveY + 40
    love.graphics.setColor(leaveHover and {0.4, 0.35, 0.3} or {0.25, 0.22, 0.2})
    love.graphics.rectangle("fill", centerX - 80, leaveY, 160, 40, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(14))
    love.graphics.printf("Leave", centerX - 80, leaveY + 12, 160, "center")
    state.buildingLeaveButton = {x = centerX - 80, y = leaveY, w = 160, h = 40}
end

M.drawNPCDialogue = function(x, y, w, h, mx, my)
    if not state.selectedNPC then return end
    local npc = state.selectedNPC
    local dialogue = npc.dialogue

    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(20))
    love.graphics.printf(npc.name, x, y + 10, w, "center")

    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.setFont(getFont(12))
    love.graphics.printf(npc.profession:gsub("^%l", string.upper), x, y + 35, w, "center")

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(64))
    love.graphics.printf(npc.sprite or "🧑", x, y + 60, w, "center")

    love.graphics.setColor(0.8, 0.8, 0.9)
    love.graphics.setFont(getFont(14))
    love.graphics.printf(dialogue.greeting, x + 40, y + 150, w - 80, "center")

    local optionsY = y + 200
    state.npcDialogueButtons = {}

    for i, option in ipairs(dialogue.options) do
        local buttonW = w - 100
        local buttonH = 70
        local bx = x + 50
        local by = optionsY + (i - 1) * 80
        local hover = mx >= bx and mx <= bx + buttonW and my >= by and my <= by + buttonH

        love.graphics.setColor(hover and {0.3, 0.4, 0.5} or {0.2, 0.3, 0.4})
        love.graphics.rectangle("fill", bx, by, buttonW, buttonH, 8, 8)
        love.graphics.setColor(hover and {0.6, 0.7, 0.8} or {0.4, 0.5, 0.6})
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", bx, by, buttonW, buttonH, 8, 8)
        love.graphics.setLineWidth(1)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(14))
        love.graphics.printf(option.text, bx + 10, by + 25, buttonW - 20, "center")

        table.insert(state.npcDialogueButtons, {x = bx, y = by, w = buttonW, h = buttonH, option = option})
    end

    local centerX = x + w/2
    local backY = y + h - 60
    local backHover = mx >= centerX - 80 and mx <= centerX + 80 and my >= backY and my <= backY + 40
    love.graphics.setColor(backHover and {0.4, 0.35, 0.3} or {0.25, 0.22, 0.2})
    love.graphics.rectangle("fill", centerX - 80, backY, 160, 40, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(14))
    love.graphics.printf("Back", centerX - 80, backY + 12, 160, "center")
    state.npcDialogueBackButton = {x = centerX - 80, y = backY, w = 160, h = 40}
end

M.drawDeathScreen = function(x, y, w, h, mx, my)
    local PlayerData = F.PlayerData or (require("main") and _G.PlayerData) or {}
    local graveyard = PlayerData.textRPGGraveyard or {}

    love.graphics.setColor(0.15, 0.05, 0.05)
    love.graphics.rectangle("fill", x, y, w, h)

    love.graphics.setColor(0.3, 0.1, 0.1)
    love.graphics.rectangle("fill", x + w/2 - 60, y + 20, 120, 80, 10, 10)
    love.graphics.setColor(0.8, 0.2, 0.2)
    love.graphics.setFont(getFont(48))
    love.graphics.printf("☠", x + w/2 - 60, y + 30, 120, "center")

    love.graphics.setColor(0.9, 0.15, 0.15)
    love.graphics.setFont(getFont(32))
    love.graphics.printf("YOU DIED", x, y + 110, w, "center")

    if state.player then
        love.graphics.setColor(0.8, 0.6, 0.6)
        love.graphics.setFont(getFont(14))
        love.graphics.printf((state.player.class and state.player.class.name or "Unknown") .. " - Level " .. (state.player.level or 1), x, y + 155, w, "center")

        love.graphics.setColor(0.7, 0.5, 0.5)
        love.graphics.setFont(getFont(12))
        if state.deathInfo and state.deathInfo.killedBy then
            love.graphics.printf("Slain by " .. state.deathInfo.killedBy .. " (Lv." .. (state.deathInfo.killedByLevel or "?") .. ")", x, y + 180, w, "center")
            love.graphics.printf("in " .. (state.deathInfo.location or "the wilderness"), x, y + 198, w, "center")
        end

        love.graphics.setColor(0.6, 0.6, 0.7)
        love.graphics.setFont(getFont(11))
        local statsY = y + 230
        love.graphics.printf("― Final Record ―", x, statsY, w, "center")

        love.graphics.setColor(0.7, 0.7, 0.8)
        statsY = statsY + 20
        love.graphics.printf("Enemies Defeated: " .. (state.stats.enemiesDefeated or 0), x, statsY, w, "center")
        statsY = statsY + 16
        love.graphics.printf("Quests Completed: " .. (state.stats.questsCompleted or 0), x, statsY, w, "center")
        statsY = statsY + 16
        love.graphics.printf("Days Survived: " .. (state.daysPassed or 0), x, statsY, w, "center")
    end

    local stash = PlayerData.deathStash
    if stash and (stash.gold > 0 or (stash.items and #stash.items > 0)) then
        love.graphics.setColor(1, 0.85, 0.2)
        love.graphics.setFont(getFont(12))
        local stashY = y + 320
        love.graphics.printf("― Belongings Dropped ―", x, stashY, w, "center")
        love.graphics.setColor(0.9, 0.8, 0.4)
        love.graphics.setFont(getFont(11))
        stashY = stashY + 18
        love.graphics.printf(string.format("%d gold dropped at nearest guild hall", stash.gold), x, stashY, w, "center")
        if stash.items and #stash.items > 0 then
            stashY = stashY + 15
            love.graphics.printf(string.format("%d items stored for retrieval", #stash.items), x, stashY, w, "center")
        end
        love.graphics.setColor(0.6, 0.6, 0.5)
        love.graphics.setFont(getFont(10))
        stashY = stashY + 15
        love.graphics.printf("Retrieve at any guild hall with a new character", x, stashY, w, "center")
    end

    local btnW = 200
    local btnH = 42
    local newBtnX = x + w/2 - btnW/2
    local btnY = y + h - 140

    local newHover = mx >= newBtnX and mx <= newBtnX + btnW and my >= btnY and my <= btnY + btnH
    love.graphics.setColor(newHover and {0.4, 0.25, 0.2} or {0.25, 0.15, 0.12})
    love.graphics.rectangle("fill", newBtnX, btnY, btnW, btnH, 8, 8)
    love.graphics.setColor(newHover and {0.9, 0.5, 0.3} or {0.7, 0.4, 0.3})
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", newBtnX, btnY, btnW, btnH, 8, 8)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 0.9, 0.8)
    love.graphics.setFont(getFont(14))
    love.graphics.printf("New Adventure", newBtnX, btnY + 12, btnW, "center")

    if #graveyard > 0 then
        local graveY = btnY + btnH + 10
        local graveHover = mx >= newBtnX and mx <= newBtnX + btnW and my >= graveY and my <= graveY + 35
        love.graphics.setColor(graveHover and {0.25, 0.25, 0.3} or {0.15, 0.15, 0.2})
        love.graphics.rectangle("fill", newBtnX, graveY, btnW, 35, 6, 6)
        love.graphics.setColor(graveHover and {0.7, 0.7, 0.8} or {0.5, 0.5, 0.6})
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", newBtnX, graveY, btnW, 35, 6, 6)
        love.graphics.setColor(0.7, 0.7, 0.8)
        love.graphics.setFont(getFont(11))
        love.graphics.printf("View Graveyard (" .. #graveyard .. " fallen)", newBtnX, graveY + 10, btnW, "center")
    end

    love.graphics.setColor(0.5, 0.4, 0.4)
    love.graphics.setFont(getFont(10))
    love.graphics.printf("\"Death is not the end, but merely a new beginning...\"", x + 20, y + h - 25, w - 40, "center")
end

M.drawGraveyard = function(x, y, w, h, mx, my)
    local PlayerData = F.PlayerData or (require("main") and _G.PlayerData) or {}
    local graveyard = PlayerData.textRPGGraveyard or {}

    love.graphics.setColor(0.1, 0.08, 0.12)
    love.graphics.rectangle("fill", x, y, w, h)

    love.graphics.setColor(0.6, 0.5, 0.7)
    love.graphics.setFont(getFont(24))
    love.graphics.printf("⚰ Graveyard ⚰", x, y + 15, w, "center")

    love.graphics.setColor(0.5, 0.4, 0.5)
    love.graphics.setFont(getFont(11))
    love.graphics.printf("Fallen Heroes Rest Here", x, y + 50, w, "center")

    local stoneY = y + 85
    local stoneH = 70
    local maxDisplay = math.min(#graveyard, 5)

    for i = 1, maxDisplay do
        local grave = graveyard[#graveyard - i + 1]
        local sy = stoneY + (i - 1) * (stoneH + 5)

        love.graphics.setColor(0.15, 0.12, 0.18)
        love.graphics.rectangle("fill", x + 30, sy, w - 60, stoneH, 6, 6)
        love.graphics.setColor(0.3, 0.25, 0.35)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x + 30, sy, w - 60, stoneH, 6, 6)
        love.graphics.setLineWidth(1)

        love.graphics.setColor(0.5, 0.4, 0.5)
        love.graphics.setFont(getFont(24))
        love.graphics.print("†", x + 45, sy + 18)

        love.graphics.setColor(0.8, 0.7, 0.9)
        love.graphics.setFont(getFont(13))
        love.graphics.print(grave.name .. " - Level " .. grave.level .. " " .. grave.class, x + 80, sy + 8)

        love.graphics.setColor(0.6, 0.5, 0.6)
        love.graphics.setFont(getFont(10))
        love.graphics.print("Slain by " .. grave.killedBy .. " in " .. grave.location, x + 80, sy + 28)

        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.setFont(getFont(9))
        love.graphics.print("Enemies: " .. grave.enemiesDefeated .. " | Quests: " .. grave.questsCompleted .. " | Days: " .. grave.daysSurvived, x + 80, sy + 45)
    end

    if #graveyard > maxDisplay then
        love.graphics.setColor(0.4, 0.4, 0.5)
        love.graphics.setFont(getFont(10))
        love.graphics.printf("...and " .. (#graveyard - maxDisplay) .. " more fallen heroes", x, stoneY + maxDisplay * (stoneH + 5) + 5, w, "center")
    end

    local newY = y + h - 90
    local newHover = mx >= x + w/2 - 100 and mx <= x + w/2 + 100 and my >= newY and my <= newY + 38
    love.graphics.setColor(newHover and {0.3, 0.25, 0.35} or {0.2, 0.15, 0.25})
    love.graphics.rectangle("fill", x + w/2 - 100, newY, 200, 38, 6, 6)
    love.graphics.setColor(newHover and {0.7, 0.6, 0.8} or {0.5, 0.4, 0.6})
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x + w/2 - 100, newY, 200, 38, 6, 6)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(0.9, 0.85, 1)
    love.graphics.setFont(getFont(13))
    love.graphics.printf("Start New Adventure", x + w/2 - 100, newY + 10, 200, "center")

    local backY = y + h - 45
    local backHover = mx >= x + w/2 - 80 and mx <= x + w/2 + 80 and my >= backY and my <= backY + 35
    love.graphics.setColor(backHover and {0.25, 0.2, 0.28} or {0.15, 0.12, 0.18})
    love.graphics.rectangle("fill", x + w/2 - 80, backY, 160, 35, 5, 5)
    love.graphics.setColor(0.6, 0.5, 0.65)
    love.graphics.setFont(getFont(11))
    love.graphics.printf("← Back to Death Screen", x + w/2 - 80, backY + 10, 160, "center")
end

-- ============================================================================
-- INVENTORY / QUEST LOG / SHOP / MARKET
-- ============================================================================

M.drawInventory = function(x, y, w, h, mx, my)
    if not state.player then return end
    local Backpack = require("backpack")
    local UIAssets = require("uiassets")
    local getTQInventory = F.getTQInventory or function() return {} end

    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(18))
    love.graphics.printf("[I] Inventory", x, y + 10, w, "center")

    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(getFont(12))
    love.graphics.print("Equipment:", x + 20, y + 45)

    local slots = {"weapon", "armor"}
    local slotNames = {weapon = "Weapon", armor = "Armor"}

    for i, slot in ipairs(slots) do
        local sy = y + 65 + (i - 1) * 30
        local item = state.player.equipment[slot]

        love.graphics.setColor(0.15, 0.18, 0.25)
        love.graphics.rectangle("fill", x + 20, sy, 220, 26, 4, 4)

        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.setFont(getFont(11))
        love.graphics.print(slotNames[slot] .. ":", x + 30, sy + 6)

        if item then
            local iconDrawn = false
            if item.icon then
                local iconImg = nil
                if UIAssets.iconRegistry and UIAssets.iconRegistry[item.icon] then
                    iconImg = UIAssets.getIconByName(item.icon)
                else
                    local folder = item.type == "weapon" and "weapons" or "armor"
                    iconImg = UIAssets.getIcon(folder, item.icon .. ".PNG")
                end
                if iconImg then
                    love.graphics.setColor(1, 1, 1)
                    local imgW, imgH = iconImg:getDimensions()
                    local iconSize = 20
                    local scale = iconSize / math.max(imgW, imgH)
                    love.graphics.draw(iconImg, x + 98, sy + 3, 0, scale, scale)
                    iconDrawn = true
                end
            end
            love.graphics.setColor(0.3, 0.8, 0.5)
            love.graphics.print(item.name, x + (iconDrawn and 122 or 100), sy + 6)
        else
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.print("Empty", x + 100, sy + 6)
        end
    end

    local inventory = getTQInventory()
    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(getFont(12))
    love.graphics.print("Backpack Items (" .. #inventory .. "):", x + 20, y + 140)

    local itemY = y + 162
    for i, item in ipairs(inventory) do
        if i <= 8 then
            local iy = itemY + (i - 1) * 28
            local hover = mx >= x + 20 and mx <= x + 240 and my >= iy and my <= iy + 25

            love.graphics.setColor(hover and {0.25, 0.3, 0.4} or {0.15, 0.18, 0.25})
            love.graphics.rectangle("fill", x + 20, iy, 220, 25, 4, 4)

            local iconDrawn = false
            local textOffset = 30
            local def = item.def
            if def and def.icon then
                local iconImg = Backpack.getItemImage(item.id)
                if iconImg then
                    love.graphics.setColor(1, 1, 1)
                    local imgW, imgH = iconImg:getDimensions()
                    local iconSize = 20
                    local scale = iconSize / math.max(imgW, imgH)
                    love.graphics.draw(iconImg, x + 28, iy + 2, 0, scale, scale)
                    iconDrawn = true
                    textOffset = 52
                end
            end

            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(getFont(11))
            local displayName = def and def.name or item.id
            local quantityStr = item.quantity > 1 and (" x" .. item.quantity) or ""
            love.graphics.print(displayName .. quantityStr, x + textOffset, iy + 5)

            if hover then
                love.graphics.setColor(0.3, 0.8, 0.5)
                love.graphics.print("[Use]", x + 180, iy + 5)
            end
        end
    end

    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(getFont(12))
    love.graphics.print("Stats:", x + 270, y + 45)

    love.graphics.setFont(getFont(11))
    love.graphics.setColor(0.9, 0.5, 0.3)
    love.graphics.print("ATK: " .. (state.player.attack or 0), x + 270, y + 70)
    love.graphics.setColor(0.3, 0.6, 0.9)
    love.graphics.print("DEF: " .. (state.player.defense or 0), x + 270, y + 90)

    local bpY = y + h - 90
    local bpHover = mx >= x + w/2 - 75 and mx <= x + w/2 + 75 and my >= bpY and my <= bpY + 35
    love.graphics.setColor(bpHover and {0.3, 0.45, 0.5} or {0.2, 0.35, 0.4})
    love.graphics.rectangle("fill", x + w/2 - 75, bpY, 150, 35, 5, 5)
    love.graphics.setColor(0.6, 0.9, 1)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Open Full Backpack", x + w/2 - 75, bpY + 10, 150, "center")

    local backY = y + h - 45
    local backHover = mx >= x + w/2 - 50 and mx <= x + w/2 + 50 and my >= backY and my <= backY + 35
    love.graphics.setColor(backHover and {0.4, 0.35, 0.3} or {0.25, 0.22, 0.2})
    love.graphics.rectangle("fill", x + w/2 - 50, backY, 100, 35, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Back", x + w/2 - 50, backY + 10, 100, "center")
end

M.drawQuestLog = function(x, y, w, h, mx, my)
    if not state.player then return end
    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(18))
    love.graphics.printf("[Q] Quest Log", x, y + 10, w, "center")

    local playerQuests = state.player.activeQuests or {}
    if #playerQuests == 0 then
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.setFont(getFont(13))
        love.graphics.printf("No active quests.\nVisit the Job Board or talk to townsfolk!", x, y + 80, w, "center")

        local btnY = y + 150
        local btnHover = mx >= x + w/2 - 80 and mx <= x + w/2 + 80 and my >= btnY and my <= btnY + 40
        love.graphics.setColor(btnHover and {0.35, 0.4, 0.3} or {0.25, 0.3, 0.25})
        love.graphics.rectangle("fill", x + w/2 - 80, btnY, 160, 40, 6, 6)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(13))
        love.graphics.printf("Visit Town Elders", x + w/2 - 80, btnY + 12, 160, "center")
    else
        local questY = y + 50
        for i, quest in ipairs(playerQuests) do
            local qy = questY + (i - 1) * 70
            local hover = quest.completed and mx >= x + 20 and mx <= x + w - 20 and my >= qy and my <= qy + 65

            love.graphics.setColor(quest.completed and {0.2, 0.3, 0.25} or {0.12, 0.15, 0.2})
            love.graphics.rectangle("fill", x + 20, qy, w - 40, 65, 6, 6)

            love.graphics.setColor(quest.completed and {0.3, 0.9, 0.4} or {0.9, 0.7, 0.2})
            love.graphics.setFont(getFont(13))
            love.graphics.print(quest.name, x + 35, qy + 8)

            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.setFont(getFont(10))
            love.graphics.printf(quest.desc, x + 35, qy + 28, w - 80, "left")

            if quest.type == "kill" or quest.type == "fetch" then
                love.graphics.setColor(0.5, 0.7, 0.9)
                love.graphics.print("Progress: " .. quest.progress .. "/" .. quest.target, x + 35, qy + 45)
            end

            love.graphics.setColor(1, 0.9, 0.3)
            love.graphics.printf(quest.rewardGold .. "g  " .. quest.rewardXP .. "xp", x + 20, qy + 45, w - 60, "right")

            if quest.completed then
                love.graphics.setColor(0.3, 0.9, 0.4)
                love.graphics.setFont(getFont(11))
                love.graphics.print(hover and "[CLAIM REWARD]" or "COMPLETE!", x + w - 150, qy + 8)
            end
        end
    end

    local backY = y + h - 45
    local backHover = mx >= x + w/2 - 50 and mx <= x + w/2 + 50 and my >= backY and my <= backY + 35
    love.graphics.setColor(backHover and {0.4, 0.35, 0.3} or {0.25, 0.22, 0.2})
    love.graphics.rectangle("fill", x + w/2 - 50, backY, 100, 35, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Back", x + w/2 - 50, backY + 10, 100, "center")
end

M.drawShop = function(x, y, w, h, mx, my)
    if not state.player then return end
    local Backpack = require("backpack")
    local town = state.world.currentTown
    if not town then return end

    local shopType = state.shopType or "general"
    local shopTitle = state.shopTitle or "General Store"
    local shopInventory = (town.shops and town.shops[shopType]) or town.shop or {}

    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(18))
    love.graphics.printf(shopTitle .. " - " .. town.name, x, y + 10, w, "center")

    love.graphics.setColor(0.5, 0.7, 0.5)
    love.graphics.setFont(getFont(10))
    love.graphics.printf("(Items go to shared Backpack)", x, y + 32, w, "center")

    love.graphics.setColor(1, 0.9, 0.3)
    love.graphics.setFont(getFont(13))
    love.graphics.printf("Your Gold: " .. state.player.gold, x, y + 48, w, "center")

    local itemY = y + 65
    local iconSize = 24

    for i, item in ipairs(shopInventory) do
        if i <= 8 then
            local iy = itemY + (i - 1) * 38
            local hover = mx >= x + 30 and mx <= x + w - 30 and my >= iy and my <= iy + 34
            local canAfford = state.player.gold >= item.value

            love.graphics.setColor(hover and {0.25, 0.3, 0.4} or {0.15, 0.18, 0.25})
            love.graphics.rectangle("fill", x + 30, iy, w - 60, 34, 5, 5)

            local textOffsetX = 45
            if item.icon then
                local img = Backpack.getItemImage(item.backpackId)
                if img then
                    love.graphics.setColor(1, 1, 1)
                    local scale = iconSize / math.max(img:getWidth(), img:getHeight())
                    love.graphics.draw(img, x + 35, iy + 5, 0, scale, scale)
                    textOffsetX = 65
                end
            end

            love.graphics.setColor(canAfford and {1, 1, 1} or {0.5, 0.5, 0.5})
            love.graphics.setFont(getFont(12))
            love.graphics.print(item.name, x + textOffsetX, iy + 5)

            love.graphics.setFont(getFont(10))
            love.graphics.setColor(0.6, 0.6, 0.7)
            local statText = ""
            if item.attack then statText = statText .. "ATK+" .. item.attack .. " " end
            if item.defense then statText = statText .. "DEF+" .. item.defense .. " " end
            if item.heal then statText = statText .. "Heal " .. item.heal .. " " end
            if item.mana then statText = statText .. "Mana+" .. item.mana end
            love.graphics.print(statText, x + textOffsetX, iy + 20)

            love.graphics.setColor(canAfford and {1, 0.9, 0.3} or {0.6, 0.4, 0.4})
            love.graphics.setFont(getFont(11))
            love.graphics.printf(item.value .. "g", x + 30, iy + 10, w - 80, "right")
        end
    end

    if #shopInventory == 0 then
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.setFont(getFont(12))
        love.graphics.printf("No items in stock.", x + 30, itemY + 50, w - 60, "center")
    end

    local backY = y + h - 45
    local backHover = mx >= x + w/2 - 50 and mx <= x + w/2 + 50 and my >= backY and my <= backY + 35
    love.graphics.setColor(backHover and {0.4, 0.35, 0.3} or {0.25, 0.22, 0.2})
    love.graphics.rectangle("fill", x + w/2 - 50, backY, 100, 35, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Back", x + w/2 - 50, backY + 10, 100, "center")
end

M.drawMarket = function(x, y, w, h, mx, my)
    if not state.player then return end
    local Backpack = require("backpack")
    local getMarketIcon = F.getMarketIcon or function() return nil end
    local town = state.world.currentTown
    if not town or not town.market then return end

    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(18))
    love.graphics.printf("Market - " .. town.name, x, y + 5, w, "center")

    love.graphics.setColor(0.6, 0.7, 0.5)
    love.graphics.setFont(getFont(10))
    love.graphics.printf(town.specialization, x, y + 28, w, "center")

    love.graphics.setColor(1, 0.9, 0.3)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Gold: " .. (state.player.gold or 0), x, y + 45, w, "center")

    local tabs = {"buy", "sell", "routes"}
    local tabNames = {buy = "Buy Goods", sell = "Sell Goods", routes = "Trade Routes"}
    local tabW = 100
    local tabStartX = x + (w - #tabs * (tabW + 5)) / 2
    local tabY = y + 65

    for i, tab in ipairs(tabs) do
        local tx = tabStartX + (i - 1) * (tabW + 5)
        local isActive = state.marketTab == tab
        local hover = mx >= tx and mx <= tx + tabW and my >= tabY and my <= tabY + 28

        love.graphics.setColor(isActive and {0.3, 0.4, 0.5} or (hover and {0.25, 0.3, 0.35} or {0.15, 0.2, 0.25}))
        love.graphics.rectangle("fill", tx, tabY, tabW, 28, 5, 5)
        love.graphics.setColor(isActive and {1, 1, 1} or {0.7, 0.7, 0.7})
        love.graphics.setFont(getFont(11))
        love.graphics.printf(tabNames[tab], tx, tabY + 7, tabW, "center")
    end

    local contentY = tabY + 40
    local contentH = h - 160

    if state.marketTab == "buy" then
        love.graphics.setColor(0.5, 0.6, 0.5)
        love.graphics.setFont(getFont(10))
        love.graphics.print("Click to buy (prices vary by town specialization)", x + 20, contentY)

        local itemY = contentY + 20
        local iconSize = 20
        for i, good in ipairs(town.market) do
            if i <= 10 then
                local iy = itemY + (i - 1) * 28
                local hover = mx >= x + 20 and mx <= x + w - 20 and my >= iy and my <= iy + 25
                local displayPrice = good.buyPrice
                local cBonus = state.player and state.player.characterBonuses
                if cBonus and cBonus.shopDiscountBonus > 0 then
                    displayPrice = math.max(1, math.floor(displayPrice * (1 - cBonus.shopDiscountBonus / 100)))
                end
                local canAfford = state.player.gold >= displayPrice

                love.graphics.setColor(hover and {0.2, 0.25, 0.3} or {0.12, 0.15, 0.18})
                love.graphics.rectangle("fill", x + 20, iy, w - 40, 25, 4, 4)

                local textOffsetX = 30
                local icon = getMarketIcon(good.icon)
                if icon then
                    love.graphics.setColor(1, 1, 1)
                    local scale = iconSize / math.max(icon:getWidth(), icon:getHeight())
                    love.graphics.draw(icon, x + 25, iy + 2, 0, scale, scale)
                    textOffsetX = 50
                end

                love.graphics.setColor(canAfford and {1, 1, 1} or {0.5, 0.5, 0.5})
                love.graphics.setFont(getFont(11))
                love.graphics.print(good.name, x + textOffsetX, iy + 5)

                love.graphics.setColor(0.5, 0.5, 0.6)
                love.graphics.setFont(getFont(9))
                love.graphics.print("Stock: " .. good.stock, x + 200, iy + 7)

                love.graphics.setColor(canAfford and {1, 0.9, 0.3} or {0.5, 0.4, 0.3})
                love.graphics.setFont(getFont(10))
                love.graphics.printf(displayPrice .. "g", x + 20, iy + 5, w - 60, "right")
            end
        end

    elseif state.marketTab == "sell" then
        local playerStock = state.playerGoods[town.name] or {}
        love.graphics.setColor(0.5, 0.6, 0.5)
        love.graphics.setFont(getFont(10))
        love.graphics.print("Your goods in " .. town.name .. ":", x + 20, contentY)

        local itemY = contentY + 20
        local itemCount = 0
        for goodId, quantity in pairs(playerStock) do
            if quantity > 0 and itemCount < 10 then
                local iy = itemY + itemCount * 28
                local hover = mx >= x + 20 and mx <= x + w - 20 and my >= iy and my <= iy + 25

                local good = nil
                for _, g in ipairs(town.market) do
                    if g.id == goodId then good = g break end
                end

                if good then
                    love.graphics.setColor(hover and {0.2, 0.25, 0.3} or {0.12, 0.15, 0.18})
                    love.graphics.rectangle("fill", x + 20, iy, w - 40, 25, 4, 4)

                    local textOffsetX = 30
                    local iconSize = 20
                    local icon = getMarketIcon(good.icon)
                    if icon then
                        love.graphics.setColor(1, 1, 1)
                        local scale = iconSize / math.max(icon:getWidth(), icon:getHeight())
                        love.graphics.draw(icon, x + 25, iy + 2, 0, scale, scale)
                        textOffsetX = 50
                    end

                    love.graphics.setColor(1, 1, 1)
                    love.graphics.setFont(getFont(11))
                    love.graphics.print(good.name .. " x" .. quantity, x + textOffsetX, iy + 5)

                    love.graphics.setColor(0.3, 0.8, 0.3)
                    love.graphics.setFont(getFont(10))
                    local displaySellPrice = good.sellPrice
                    local cBonus = state.player and state.player.characterBonuses
                    if cBonus and cBonus.sellPriceMult > 1 then
                        displaySellPrice = math.floor(displaySellPrice * cBonus.sellPriceMult)
                    end
                    love.graphics.printf("Sell: " .. displaySellPrice .. "g each", x + 20, iy + 5, w - 60, "right")

                    itemCount = itemCount + 1
                end
            end
        end

        if itemCount == 0 then
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.setFont(getFont(11))
            love.graphics.printf("No goods stored here.\nBuy goods and send them via trade routes!", x + 20, contentY + 50, w - 40, "center")
        end

    elseif state.marketTab == "routes" then
        love.graphics.setColor(0.5, 0.6, 0.5)
        love.graphics.setFont(getFont(10))
        love.graphics.print("Active Caravans:", x + 20, contentY)

        local routeY = contentY + 20
        if #state.tradeRoutes == 0 then
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.setFont(getFont(11))
            love.graphics.printf("No active trade routes.\nBuy goods first, then send them to other towns!", x + 20, routeY + 20, w - 40, "center")
        else
            for i, route in ipairs(state.tradeRoutes) do
                if i <= 5 then
                    local ry = routeY + (i - 1) * 35
                    local daysLeft = route.arrivalDay - state.daysPassed

                    love.graphics.setColor(0.15, 0.18, 0.22)
                    love.graphics.rectangle("fill", x + 20, ry, w - 40, 32, 4, 4)

                    love.graphics.setColor(0.8, 0.8, 0.8)
                    love.graphics.setFont(getFont(10))
                    love.graphics.print(route.goodName .. " x" .. route.quantity, x + 30, ry + 3)
                    love.graphics.setColor(0.6, 0.6, 0.7)
                    love.graphics.print(route.origin .. " -> " .. route.destination, x + 30, ry + 16)

                    love.graphics.setColor(daysLeft <= 1 and {0.3, 0.9, 0.3} or {0.7, 0.7, 0.4})
                    love.graphics.printf(daysLeft <= 0 and "Arriving!" or (daysLeft .. " days"), x + 20, ry + 8, w - 60, "right")
                end
            end
        end

        local sendY = routeY + 180
        love.graphics.setColor(0.6, 0.6, 0.7)
        love.graphics.setFont(getFont(11))
        love.graphics.print("Send Goods to Other Towns:", x + 20, sendY)

        local btnY = sendY + 25
        for _, t in ipairs(state.world.towns) do
            if t.name ~= town.name then
                local hover = mx >= x + 30 and mx <= x + w - 30 and my >= btnY and my <= btnY + 25
                love.graphics.setColor(hover and {0.25, 0.3, 0.35} or {0.15, 0.2, 0.25})
                love.graphics.rectangle("fill", x + 30, btnY, w - 60, 25, 4, 4)
                love.graphics.setColor(0.8, 0.8, 0.8)
                love.graphics.setFont(getFont(10))
                local dist = math.abs(t.x - town.x) + math.abs(t.y - town.y)
                love.graphics.print(t.name .. " (" .. dist .. " days)", x + 40, btnY + 5)
                btnY = btnY + 28
                if btnY > y + h - 80 then break end
            end
        end
    end

    local backY = y + h - 45
    local backHover = mx >= x + w/2 - 50 and mx <= x + w/2 + 50 and my >= backY and my <= backY + 35
    love.graphics.setColor(backHover and {0.4, 0.35, 0.3} or {0.25, 0.22, 0.2})
    love.graphics.rectangle("fill", x + w/2 - 50, backY, 100, 35, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Back", x + w/2 - 50, backY + 10, 100, "center")
end

return M
