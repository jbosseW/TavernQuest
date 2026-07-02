-- World Map Overlay Module
-- Full world map with fog of war for the TextRPG game
-- This module provides the drawFullMapOverlay function and related handlers.

local WorldMapOverlay = {}

local Renderer2D = require("renderer2d")
local TileQuadMaps = require("tile_quad_maps")

-- Draw the full world map overlay
-- Must be called from within textrpg.lua's draw function context with access to:
--   state, getFont, getTileType (from the F table)
function WorldMapOverlay.draw(state, getFont, getTileType)
    local screenW, screenH = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()
    local WorldGen = require("worldgen")

    love.graphics.setColor(0, 0, 0, 0.92)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    local panelPad = 30
    local panelW = screenW - panelPad * 2
    local panelH = screenH - panelPad * 2
    local panelX = panelPad
    local panelY = panelPad

    love.graphics.setColor(0.06, 0.06, 0.1)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)
    love.graphics.setColor(0.3, 0.35, 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 10, 10)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(0.9, 0.8, 0.4)
    love.graphics.setFont(getFont(20))
    love.graphics.printf("WORLD MAP", panelX, panelY + 8, panelW, "center")

    -- Close button (top-right)
    local cbS = 28
    local cbX = panelX + panelW - cbS - 10
    local cbY = panelY + 8
    local cbHov = mx >= cbX and mx <= cbX + cbS and my >= cbY and my <= cbY + cbS
    love.graphics.setColor(cbHov and {0.6, 0.2, 0.2} or {0.4, 0.15, 0.15})
    love.graphics.rectangle("fill", cbX, cbY, cbS, cbS, 4, 4)
    love.graphics.setColor(cbHov and {1, 0.6, 0.6} or {0.8, 0.5, 0.5})
    love.graphics.setFont(getFont(16))
    love.graphics.printf("X", cbX, cbY + 5, cbS, "center")
    state.fullMapCloseBounds = {x = cbX, y = cbY, w = cbS, h = cbS}

    -- Map content area
    local legendH = 70
    local mapAreaX = panelX + 10
    local mapAreaY = panelY + 38
    local mapAreaW = panelW - 20
    local mapAreaH = panelH - 38 - legendH - 10

    local px = state.world and state.world.playerX or 0
    local py = state.world and state.world.playerY or 0

    -- Zoom and pan
    local zoom = state.fullMapZoom or 1
    local baseVR = 30
    local viewRange = math.floor(baseVR / zoom)
    -- Clamp: min 8, max 50 tiles radius to prevent excessive chunk loading
    viewRange = math.max(8, math.min(50, viewRange))

    local panOX = state.fullMapPanX or 0
    local panOY = state.fullMapPanY or 0
    local ctrX = px - panOX
    local ctrY = py - panOY

    -- Calculate cell size
    local tentW = viewRange * 2 + 1
    local tentH = viewRange * 2 + 1
    local cW = math.floor(mapAreaW / tentW)
    local cH = math.floor(mapAreaH / tentH)
    local cellSize = math.max(2, math.min(cW, cH))

    -- Fit tiles to area
    local fitW = math.floor(mapAreaW / cellSize)
    local fitH = math.floor(mapAreaH / cellSize)
    local minVX = ctrX - math.floor(fitW / 2)
    local maxVX = minVX + fitW - 1
    local minVY = ctrY - math.floor(fitH / 2)
    local maxVY = minVY + fitH - 1
    local visW = maxVX - minVX + 1
    local visH = maxVY - minVY + 1

    -- Grid positioning
    local gridW = visW * cellSize
    local gridH = visH * cellSize
    local gridX = mapAreaX + math.floor((mapAreaW - gridW) / 2)
    local gridY = mapAreaY + math.floor((mapAreaH - gridH) / 2)

    -- Clip rendering to map area
    love.graphics.setScissor(mapAreaX, mapAreaY, mapAreaW, mapAreaH)

    local useWG = state.world and state.world.useWorldGen
    local hoverInfo = nil

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
        hills = "wood",              -- brown wood
        road = "cobblestone",        -- verified cobblestone (col 4, row 15)
        ruins = "dark_stone",        -- verified dark stone (col 19, row 13)
    }
    local spriteMode = Renderer2D.isSprite()
    local terrainAtlas = spriteMode and Renderer2D.getAtlas("terrain") or nil

    for cy = minVY, maxVY do
        for cx = minVX, maxVX do
            local sc = cx - minVX
            local sr = cy - minVY
            local cX = gridX + sc * cellSize
            local cY = gridY + sr * cellSize

            local tile = nil
            if useWG then
                tile = WorldGen.getTile(cx, cy)
            elseif state.world and state.world.mapData then
                tile = state.world.mapData[cy] and state.world.mapData[cy][cx]
            end

            if tile then
                local explored = tile.explored
                -- Brightness: explored tiles at 75%, unexplored at 28%
                local bright = explored and 0.75 or 0.28
                local tt = getTileType(tile.type)
                local r, g, b = tt.color[1] * bright, tt.color[2] * bright, tt.color[3] * bright

                if terrainAtlas then
                    local quadName = tileTypeToQuad[tile.type] or "grass"
                    local quad = TileQuadMaps.terrain[quadName]
                    if quad then
                        local scale = (cellSize - 1) / 32
                        -- Bright tint so atlas sprites show natural colors
                        -- explored=0.85 brightness, unexplored=0.35
                        local atlasBright = explored and 0.85 or 0.35
                        love.graphics.setColor(atlasBright, atlasBright, atlasBright * 0.97)
                        love.graphics.draw(terrainAtlas, quad, cX, cY, 0, scale, scale)
                    else
                        love.graphics.setColor(r, g, b)
                        love.graphics.rectangle("fill", cX, cY, cellSize - 1, cellSize - 1)
                    end
                else
                    love.graphics.setColor(r, g, b)
                    love.graphics.rectangle("fill", cX, cY, cellSize - 1, cellSize - 1)
                end

                if cellSize >= 10 then
                    -- Icon alpha: explored at 60%, unexplored at 20%
                    local iconAlpha = explored and 0.6 or 0.2
                    love.graphics.setColor(1, 1, 1, iconAlpha)
                    love.graphics.setFont(getFont(math.max(6, math.floor(cellSize * 0.65))))
                    love.graphics.printf(tt.icon, cX, cY + 1, cellSize - 1, "center")
                end

                -- The following overlays only apply to explored tiles
                if explored then
                    -- Town highlight (gold border)
                    if tile.type == "town" or tile.type == "desert_settlement" then
                        love.graphics.setColor(0.9, 0.8, 0.3, 0.8)
                        love.graphics.setLineWidth(math.max(1, math.floor(cellSize / 6)))
                        love.graphics.rectangle("line", cX, cY, cellSize - 1, cellSize - 1)
                        love.graphics.setLineWidth(1)
                    end

                    -- Dungeon highlight (red border)
                    if tile.type == "dungeon" then
                        love.graphics.setColor(0.7, 0.2, 0.2, 0.7)
                        love.graphics.setLineWidth(math.max(1, math.floor(cellSize / 6)))
                        love.graphics.rectangle("line", cX, cY, cellSize - 1, cellSize - 1)
                        love.graphics.setLineWidth(1)
                    end

                    -- Corrupted land (purple tint)
                    if tile.type == "corrupted" then
                        love.graphics.setColor(0.5, 0.1, 0.5, 0.3)
                        love.graphics.rectangle("fill", cX, cY, cellSize - 1, cellSize - 1)
                    end

                    -- Region tint
                    if useWG and tile.region then
                        local regions = WorldGen.getRegions()
                        local region = regions[tile.region]
                        if region and region.mapColor then
                            love.graphics.setColor(region.mapColor[1], region.mapColor[2], region.mapColor[3], 0.1)
                            love.graphics.rectangle("fill", cX, cY, cellSize - 1, cellSize - 1)
                        end
                    end

                    -- Property marker
                    if state.player and state.player.properties and state.player.properties.landClaims then
                        local claimKey = cx .. "_" .. cy
                        if state.player.properties.landClaims[claimKey] then
                            love.graphics.setColor(0.2, 0.8, 0.3, 0.6)
                            love.graphics.setLineWidth(math.max(1, math.floor(cellSize / 8)))
                            love.graphics.rectangle("line", cX + 1, cY + 1, cellSize - 3, cellSize - 3)
                            love.graphics.setLineWidth(1)
                        end
                    end
                end

                -- Hover detection (works for both explored and unexplored)
                if mx >= cX and mx < cX + cellSize and my >= cY and my < cY + cellSize then
                    hoverInfo = {tileType = tt, tile = tile, x = cx, y = cy, explored = explored}
                    love.graphics.setColor(1, 1, 1, explored and 0.25 or 0.12)
                    love.graphics.rectangle("fill", cX, cY, cellSize - 1, cellSize - 1)
                end
            else
                -- No tile data available (out of bounds or failed to load)
                love.graphics.setColor(0.03, 0.03, 0.05)
                love.graphics.rectangle("fill", cX, cY, cellSize - 1, cellSize - 1)
            end

            -- Player position marker
            if cx == px and cy == py then
                local pulse = 0.6 + 0.4 * math.sin(love.timer.getTime() * 4)
                local mS = math.max(4, cellSize - 2)
                love.graphics.setColor(0.2, 0.6, 1.0, 0.3 * pulse)
                love.graphics.rectangle("fill", cX - 1, cY - 1, mS + 2, mS + 2)
                love.graphics.setColor(0.3, 0.8, 1.0, pulse)
                love.graphics.rectangle("fill", cX, cY, mS, mS)
                if cellSize >= 6 then
                    local cs = math.max(2, math.floor(cellSize / 3))
                    local cx2 = cX + math.floor((mS - cs) / 2)
                    local cy2 = cY + math.floor((mS - cs) / 2)
                    love.graphics.setColor(1, 1, 1, pulse)
                    love.graphics.rectangle("fill", cx2, cy2, cs, cs)
                end
                if cellSize >= 16 then
                    love.graphics.setColor(1, 1, 1, 0.9)
                    love.graphics.setFont(getFont(math.max(7, math.floor(cellSize * 0.3))))
                    love.graphics.printf("YOU", cX - cellSize, cY - math.floor(cellSize * 0.4), cellSize * 3, "center")
                end
            end
        end
    end

    love.graphics.setScissor()

    -- Grid border
    love.graphics.setColor(0.2, 0.25, 0.35)
    love.graphics.rectangle("line", gridX - 1, gridY - 1, gridW + 2, gridH + 2)

    -- Hover tooltip
    if hoverInfo then
        local ht = hoverInfo
        local tw = 180
        local th = 58
        local tx = math.min(mx + 15, screenW - tw - 10)
        local ty = math.min(my + 15, screenH - th - 10)

        love.graphics.setColor(0.08, 0.08, 0.12, 0.95)
        love.graphics.rectangle("fill", tx, ty, tw, th, 5, 5)
        love.graphics.setColor(0.4, 0.45, 0.6)
        love.graphics.rectangle("line", tx, ty, tw, th, 5, 5)

        if ht.explored then
            love.graphics.setColor(ht.tileType.color)
            love.graphics.setFont(getFont(12))
            love.graphics.print(ht.tileType.icon .. " " .. ht.tileType.name, tx + 8, ty + 6)

            love.graphics.setColor(0.6, 0.6, 0.7)
            love.graphics.setFont(getFont(10))
            love.graphics.print("Position: (" .. ht.x .. ", " .. ht.y .. ")", tx + 8, ty + 24)

            if ht.tile.town then
                love.graphics.setColor(0.9, 0.8, 0.4)
                love.graphics.print(ht.tile.town.name or "Unknown Town", tx + 8, ty + 38)
            else
                local dist = math.abs(ht.x - px) + math.abs(ht.y - py)
                love.graphics.setColor(0.5, 0.6, 0.7)
                love.graphics.print("Distance: " .. dist .. " tiles (" .. (dist * 5) .. " km)", tx + 8, ty + 38)
            end
        else
            -- Unexplored tile: show terrain type but mark as unexplored
            local dimColor = {ht.tileType.color[1] * 0.5, ht.tileType.color[2] * 0.5, ht.tileType.color[3] * 0.5}
            love.graphics.setColor(dimColor)
            love.graphics.setFont(getFont(12))
            love.graphics.print(ht.tileType.icon .. " " .. ht.tileType.name, tx + 8, ty + 6)

            love.graphics.setColor(0.45, 0.4, 0.5)
            love.graphics.setFont(getFont(10))
            love.graphics.print("(Unexplored)", tx + 8, ty + 24)

            local dist = math.abs(ht.x - px) + math.abs(ht.y - py)
            love.graphics.setColor(0.4, 0.4, 0.5)
            love.graphics.print("Distance: " .. dist .. " tiles (" .. (dist * 5) .. " km)", tx + 8, ty + 38)
        end
    end

    -- Zoom controls (top-left of map area)
    local zbS = 24
    local zX = mapAreaX + 5
    local zY = mapAreaY + 5

    -- Zoom In (+)
    local ziHov = mx >= zX and mx <= zX + zbS and my >= zY and my <= zY + zbS
    love.graphics.setColor(ziHov and {0.3, 0.4, 0.5} or {0.18, 0.22, 0.3})
    love.graphics.rectangle("fill", zX, zY, zbS, zbS, 4, 4)
    love.graphics.setColor(0.8, 0.8, 0.9)
    love.graphics.setFont(getFont(16))
    love.graphics.printf("+", zX, zY + 3, zbS, "center")
    state.fullMapZoomInBounds = {x = zX, y = zY, w = zbS, h = zbS}

    -- Zoom Out (-)
    local zoY = zY + zbS + 4
    local zoHov = mx >= zX and mx <= zX + zbS and my >= zoY and my <= zoY + zbS
    love.graphics.setColor(zoHov and {0.3, 0.4, 0.5} or {0.18, 0.22, 0.3})
    love.graphics.rectangle("fill", zX, zoY, zbS, zbS, 4, 4)
    love.graphics.setColor(0.8, 0.8, 0.9)
    love.graphics.setFont(getFont(16))
    love.graphics.printf("-", zX, zoY + 3, zbS, "center")
    state.fullMapZoomOutBounds = {x = zX, y = zoY, w = zbS, h = zbS}

    -- Center on Player (@)
    local ctBY = zoY + zbS + 4
    local ctHov = mx >= zX and mx <= zX + zbS and my >= ctBY and my <= ctBY + zbS
    love.graphics.setColor(ctHov and {0.3, 0.45, 0.4} or {0.18, 0.28, 0.25})
    love.graphics.rectangle("fill", zX, ctBY, zbS, zbS, 4, 4)
    love.graphics.setColor(0.5, 0.9, 0.8)
    love.graphics.setFont(getFont(14))
    love.graphics.printf("@", zX, ctBY + 4, zbS, "center")
    state.fullMapCenterBounds = {x = zX, y = ctBY, w = zbS, h = zbS}

    -- Zoom level label
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.setFont(getFont(9))
    love.graphics.printf(string.format("%.1fx", zoom), zX - 2, ctBY + zbS + 4, zbS + 4, "center")

    -- Player coordinates (top-right)
    love.graphics.setColor(0.5, 0.6, 0.7)
    love.graphics.setFont(getFont(10))
    love.graphics.printf("Player: (" .. px .. ", " .. py .. ")", mapAreaX, mapAreaY + 5, mapAreaW - 10, "right")

    -- Legend bar (bottom)
    local legY = panelY + panelH - legendH
    love.graphics.setColor(0.08, 0.08, 0.12)
    love.graphics.rectangle("fill", panelX + 5, legY, panelW - 10, legendH - 5, 6, 6)
    love.graphics.setColor(0.25, 0.28, 0.38)
    love.graphics.rectangle("line", panelX + 5, legY, panelW - 10, legendH - 5, 6, 6)

    local legItems = {
        {name = "Grass", icon = ".", color = {0.3, 0.5, 0.3}},
        {name = "Forest", icon = "T", color = {0.2, 0.4, 0.2}},
        {name = "Mtn", icon = "^", color = {0.5, 0.5, 0.5}},
        {name = "Water", icon = "~", color = {0.2, 0.4, 0.7}},
        {name = "Desert", icon = ":", color = {0.8, 0.7, 0.4}},
        {name = "Swamp", icon = "%", color = {0.3, 0.4, 0.3}},
        {name = "Town", icon = "#", color = {0.6, 0.5, 0.4}},
        {name = "Dungeon", icon = "D", color = {0.4, 0.2, 0.2}},
        {name = "Ruins", icon = "R", color = {0.5, 0.4, 0.3}},
        {name = "Corrupt", icon = "X", color = {0.3, 0.15, 0.3}},
        {name = "Ice", icon = "*", color = {0.7, 0.85, 0.95}},
        {name = "You", icon = "@", color = {0.3, 0.8, 1.0}},
        {name = "Unexp.", icon = "?", color = {0.2, 0.25, 0.2}},
    }

    local legEW = math.floor((panelW - 30) / #legItems)
    local legSX = panelX + 15

    for i, item in ipairs(legItems) do
        local eX = legSX + (i - 1) * legEW
        love.graphics.setColor(item.color)
        love.graphics.rectangle("fill", eX, legY + 8, 12, 12, 2, 2)
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.setFont(getFont(9))
        love.graphics.print(item.icon, eX + 2, legY + 8)
        love.graphics.setColor(0.6, 0.6, 0.7)
        love.graphics.setFont(getFont(8))
        love.graphics.print(item.name, eX, legY + 24)
    end

    -- Controls hint
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.setFont(getFont(10))
    love.graphics.printf("[M] or [ESC] Close  |  [+/-] Zoom  |  [Arrow Keys] Pan  |  Hover for details",
        panelX, legY + 42, panelW, "center")

    state.fullMapPanelBounds = {x = panelX, y = panelY, w = panelW, h = panelH}
end

-- Handle mouse clicks on the full map overlay
-- Returns true if click was consumed by the overlay
function WorldMapOverlay.handleClick(state, mx, my)
    if not state.fullMapOpen then return false end

    -- Close button
    if state.fullMapCloseBounds then
        local b = state.fullMapCloseBounds
        if mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h then
            state.fullMapOpen = false
            return true
        end
    end

    -- Zoom In
    if state.fullMapZoomInBounds then
        local b = state.fullMapZoomInBounds
        if mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h then
            state.fullMapZoom = math.min(4.0, (state.fullMapZoom or 1) * 1.5)
            return true
        end
    end

    -- Zoom Out
    if state.fullMapZoomOutBounds then
        local b = state.fullMapZoomOutBounds
        if mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h then
            state.fullMapZoom = math.max(0.5, (state.fullMapZoom or 1) / 1.5)
            return true
        end
    end

    -- Center on Player
    if state.fullMapCenterBounds then
        local b = state.fullMapCenterBounds
        if mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h then
            state.fullMapPanX = 0
            state.fullMapPanY = 0
            return true
        end
    end

    -- Click outside panel to close
    if state.fullMapPanelBounds then
        local b = state.fullMapPanelBounds
        if mx < b.x or mx > b.x + b.w or my < b.y or my > b.y + b.h then
            state.fullMapOpen = false
            return true
        end
    end

    -- Click inside panel consumes the event (prevent passthrough)
    return true
end

-- Handle keyboard input for the full map overlay
-- Returns true if key was consumed
function WorldMapOverlay.handleKey(state, key)
    if not state.fullMapOpen then return false end

    -- Close on M or Escape
    if key == "m" or key == "escape" then
        state.fullMapOpen = false
        return true
    end

    -- Zoom controls
    if key == "=" or key == "+" or key == "kp+" then
        state.fullMapZoom = math.min(4.0, (state.fullMapZoom or 1) * 1.5)
        return true
    end
    if key == "-" or key == "kp-" then
        state.fullMapZoom = math.max(0.5, (state.fullMapZoom or 1) / 1.5)
        return true
    end

    -- Pan with arrow keys
    local panStep = math.max(1, math.floor(5 / (state.fullMapZoom or 1)))
    if key == "up" or key == "w" then
        state.fullMapPanY = (state.fullMapPanY or 0) + panStep
        return true
    end
    if key == "down" or key == "s" then
        state.fullMapPanY = (state.fullMapPanY or 0) - panStep
        return true
    end
    if key == "left" or key == "a" then
        state.fullMapPanX = (state.fullMapPanX or 0) + panStep
        return true
    end
    if key == "right" or key == "d" then
        state.fullMapPanX = (state.fullMapPanX or 0) - panStep
        return true
    end

    -- Home/center on player
    if key == "home" then
        state.fullMapPanX = 0
        state.fullMapPanY = 0
        return true
    end

    return true  -- Consume all keys while map is open
end

-- Toggle the world map open/closed
function WorldMapOverlay.toggle(state)
    state.fullMapOpen = not state.fullMapOpen
    if state.fullMapOpen then
        -- Reset view to player position on open
        state.fullMapZoom = state.fullMapZoom or 1
        state.fullMapPanX = 0
        state.fullMapPanY = 0
    end
end

return WorldMapOverlay
