-- Enemy AI Shared Module
-- Provides core AI algorithms used by both MapEnemies and DungeonEnemies.
-- All functions are stateless and accept passability/blocking functions as
-- parameters so they remain decoupled from any specific tile system.

local EnemyAI = {}
local TileUtils = require("tileutils")

-- ============================================================================
--                          DISTANCE FUNCTIONS
-- ============================================================================

function EnemyAI.manhattanDist(x1, y1, x2, y2)
    return math.abs(x1 - x2) + math.abs(y1 - y2)
end

function EnemyAI.euclideanDist(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    return math.sqrt(dx * dx + dy * dy)
end

-- ============================================================================
--                        LINE OF SIGHT (Bresenham)
-- ============================================================================

-- Check line of sight between two tile positions.
-- blocksVision(cx, cy) should return true if the tile at (cx, cy) blocks LOS.
-- The start tile is never checked; the end tile is the target.
function EnemyAI.hasLineOfSight(x1, y1, x2, y2, blocksVision)
    local dx = math.abs(x2 - x1)
    local dy = math.abs(y2 - y1)
    local sx = x1 < x2 and 1 or -1
    local sy = y1 < y2 and 1 or -1
    local err = dx - dy

    local cx, cy = x1, y1
    local maxSteps = dx + dy + 2  -- Safety limit

    for step = 1, maxSteps do
        -- Skip starting point
        if not (cx == x1 and cy == y1) then
            if blocksVision(cx, cy) then
                return false
            end
        end

        -- Reached target
        if cx == x2 and cy == y2 then
            return true
        end

        local e2 = 2 * err
        if e2 > -dy then
            err = err - dy
            cx = cx + sx
        end
        if e2 < dx then
            err = err + dx
            cy = cy + sy
        end
    end

    -- Did not reach target within maxSteps: assume no LOS
    return false
end

-- ============================================================================
--                          MOVEMENT
-- ============================================================================

-- Move an enemy one step toward (targetX, targetY).
-- isPassable(x, y) returns true if the tile can be entered.
-- isOccupied(x, y, enemy) is optional; returns true if another enemy is there.
-- Returns true if the enemy moved.
function EnemyAI.moveToward(enemy, targetX, targetY, isPassable, isOccupied)
    local dx = targetX - enemy.x
    local dy = targetY - enemy.y

    -- Prefer the axis with greater distance
    local moveX, moveY = 0, 0
    if math.abs(dx) >= math.abs(dy) then
        moveX = dx > 0 and 1 or (dx < 0 and -1 or 0)
    else
        moveY = dy > 0 and 1 or (dy < 0 and -1 or 0)
    end

    -- Try primary direction
    local newX, newY = enemy.x + moveX, enemy.y + moveY
    if isPassable(newX, newY) then
        if not isOccupied or not isOccupied(newX, newY, enemy) then
            enemy.x = newX
            enemy.y = newY
            return true
        end
    end

    -- Try secondary direction
    if moveX ~= 0 then
        moveY = dy > 0 and 1 or (dy < 0 and -1 or 0)
        moveX = 0
    else
        moveX = dx > 0 and 1 or (dx < 0 and -1 or 0)
        moveY = 0
    end

    if moveX == 0 and moveY == 0 then return false end

    newX, newY = enemy.x + moveX, enemy.y + moveY
    if isPassable(newX, newY) then
        if not isOccupied or not isOccupied(newX, newY, enemy) then
            enemy.x = newX
            enemy.y = newY
            return true
        end
    end

    return false
end

-- ============================================================================
--                       PATROL - ROUTE BASED
-- ============================================================================

-- Patrol along a predefined route (used by MapEnemies).
-- enemy must have: patrolRoute, patrolIndex, patrolForward
-- isPassable(x, y) for movement validation.
function EnemyAI.updateRoutePatrol(enemy, isPassable, isOccupied)
    if not enemy.patrolRoute or #enemy.patrolRoute == 0 then
        enemy.state = "idle"
        return
    end

    local target = enemy.patrolRoute[enemy.patrolIndex]
    if not target then
        enemy.patrolIndex = 1
        target = enemy.patrolRoute[1]
        if not target then return end
    end

    -- Are we at the current waypoint?
    if enemy.x == target.x and enemy.y == target.y then
        -- Advance to next waypoint
        if enemy.patrolForward then
            enemy.patrolIndex = enemy.patrolIndex + 1
            if enemy.patrolIndex > #enemy.patrolRoute then
                enemy.patrolForward = false
                enemy.patrolIndex = #enemy.patrolRoute - 1
                if enemy.patrolIndex < 1 then
                    enemy.patrolIndex = 1
                    enemy.patrolForward = true
                end
            end
        else
            enemy.patrolIndex = enemy.patrolIndex - 1
            if enemy.patrolIndex < 1 then
                enemy.patrolForward = true
                enemy.patrolIndex = 2
                if enemy.patrolIndex > #enemy.patrolRoute then
                    enemy.patrolIndex = 1
                end
            end
        end
    else
        -- Move toward current waypoint
        EnemyAI.moveToward(enemy, target.x, target.y, isPassable, isOccupied)
    end
end

-- ============================================================================
--                     PATROL - RADIUS BASED (wander)
-- ============================================================================

-- Patrol by wandering randomly near a spawn origin (used by DungeonEnemies).
-- enemy must have: patrolOriginX, patrolOriginY, patrolRadius,
--                  patrolTargetX, patrolTargetY
-- isPassable(x, y) for movement validation.
function EnemyAI.updateRadiusPatrol(enemy, isPassable, isOccupied)
    if enemy.x == enemy.patrolTargetX and enemy.y == enemy.patrolTargetY then
        -- Pick new random target near origin
        local attempts = 0
        while attempts < 10 do
            attempts = attempts + 1
            local nx = enemy.patrolOriginX + math.random(-enemy.patrolRadius, enemy.patrolRadius)
            local ny = enemy.patrolOriginY + math.random(-enemy.patrolRadius, enemy.patrolRadius)
            if isPassable(nx, ny) then
                enemy.patrolTargetX = nx
                enemy.patrolTargetY = ny
                -- Sometimes idle briefly at waypoint
                if math.random() < 0.4 then
                    enemy.state = "idle"
                    enemy.idleTimer = 0
                end
                break
            end
        end
    else
        EnemyAI.moveToward(enemy, enemy.patrolTargetX, enemy.patrolTargetY, isPassable, isOccupied)
    end
end

-- ============================================================================
--                              CHASE
-- ============================================================================

-- Chase a target position, giving up if too far.
-- Returns true if the enemy gave up the chase.
-- isPassable(x, y) for movement validation.
function EnemyAI.updateChase(enemy, targetX, targetY, returnDist, isPassable, isOccupied)
    local dist = EnemyAI.manhattanDist(enemy.x, enemy.y, targetX, targetY)

    -- Give up chase if target is too far
    if dist > returnDist then
        enemy.state = "patrol"
        enemy.alertTimer = 0
        enemy.lastKnownPlayerX = nil
        enemy.lastKnownPlayerY = nil
        return true
    end

    -- Move toward target
    EnemyAI.moveToward(enemy, targetX, targetY, isPassable, isOccupied)

    -- Update last known position
    enemy.lastKnownPlayerX = targetX
    enemy.lastKnownPlayerY = targetY
    return false
end

-- ============================================================================
--                           DETECTION
-- ============================================================================

-- Check if a target is within detection radius and has line of sight.
-- blocksVision(cx, cy) should return true if the tile blocks LOS.
-- Returns true if the target is detected.
function EnemyAI.canDetect(enemy, targetX, targetY, detectionRadius, blocksVision)
    local dist = EnemyAI.euclideanDist(enemy.x, enemy.y, targetX, targetY)
    if dist > detectionRadius then return false end
    return EnemyAI.hasLineOfSight(enemy.x, enemy.y, targetX, targetY, blocksVision)
end

-- ============================================================================
--                    DETECTION STATE TRANSITIONS
-- ============================================================================

-- Process detection-based state transitions for an enemy.
-- detected: boolean, whether the target was detected this frame.
-- loseInterestTime: seconds after losing sight before returning to patrol.
-- dt: delta time.
-- States: "patrol" -> "chase" -> "search" -> "patrol"
--   chase:  actively pursuing a visible target
--   search: lost sight, moving to last known position and searching nearby
--   patrol: normal wander behavior
--   idle:   brief pause between patrol waypoints
-- useSearchState: if true, enemies transition chase -> search -> patrol
--                 if false/nil, enemies transition chase -> patrol (legacy behavior)
function EnemyAI.updateDetectionState(enemy, detected, dt, loseInterestTime, useSearchState)
    local searchDuration = (loseInterestTime or 4) * 2  -- search lasts twice as long as chase timeout

    if detected then
        -- Target spotted: enter or stay in chase
        if enemy.state ~= "chase" then
            enemy.state = "chase"
            enemy.alertTimer = 0
        end
        enemy.alertTimer = enemy.alertTimer + dt
    elseif enemy.state == "chase" then
        if useSearchState then
            -- Transition to search: move to last known position and look around
            enemy.state = "search"
            enemy.searchTimer = 0
            enemy.searchTurns = 0
            -- lastKnownPlayerX/Y are already set by chase logic
        else
            -- Legacy behavior: lose interest over time
            enemy.alertTimer = enemy.alertTimer + dt
            if enemy.alertTimer > (loseInterestTime or 4) then
                enemy.state = "patrol"
                enemy.alertTimer = 0
                enemy.lastKnownPlayerX = nil
                enemy.lastKnownPlayerY = nil
            end
        end
    elseif enemy.state == "search" then
        enemy.searchTimer = (enemy.searchTimer or 0) + dt
        if enemy.searchTimer > searchDuration then
            -- Give up searching, return to patrol
            enemy.state = "patrol"
            enemy.alertTimer = 0
            enemy.searchTimer = 0
            enemy.searchTurns = 0
            enemy.lastKnownPlayerX = nil
            enemy.lastKnownPlayerY = nil
        end
    end
end

-- ============================================================================
--                          SEARCH BEHAVIOR
-- ============================================================================

-- Search near last known position: move to last known pos, then wander nearby.
-- enemy must have: lastKnownPlayerX, lastKnownPlayerY, searchTurns
-- isPassable(x, y) for movement validation.
-- Returns true if the enemy reached the last known position (searching area).
function EnemyAI.updateSearch(enemy, isPassable, isOccupied)
    local lkx = enemy.lastKnownPlayerX
    local lky = enemy.lastKnownPlayerY
    if not lkx or not lky then
        -- No last known position; wander randomly
        enemy.state = "patrol"
        return false
    end

    local dist = EnemyAI.manhattanDist(enemy.x, enemy.y, lkx, lky)

    if dist > 1 then
        -- Move toward last known position
        EnemyAI.moveToward(enemy, lkx, lky, isPassable, isOccupied)
        return false
    else
        -- At or adjacent to last known position: search randomly nearby
        enemy.searchTurns = (enemy.searchTurns or 0) + 1
        local searchRadius = 3
        local attempts = 0
        while attempts < 8 do
            attempts = attempts + 1
            local nx = lkx + math.random(-searchRadius, searchRadius)
            local ny = lky + math.random(-searchRadius, searchRadius)
            if isPassable(nx, ny) then
                if not isOccupied or not isOccupied(nx, ny, enemy) then
                    EnemyAI.moveToward(enemy, nx, ny, isPassable, isOccupied)
                    break
                end
            end
        end
        return true
    end
end

-- ============================================================================
--              STEALTH-AWARE DETECTION (proximity check)
-- ============================================================================

-- Check if an enemy detects a stealthed target based on distance.
-- Returns true if the stealthed player is detected this check.
-- detectionRadius: enemy's normal detection radius.
-- distance: current distance between enemy and target.
-- playerStealthStat: player's stealth stat (0-100, higher = stealthier).
-- isMoving: whether the player moved this turn (moving is easier to detect).
function EnemyAI.rollStealthDetection(detectionRadius, distance, playerStealthStat, isMoving)
    -- Base detection chances by distance
    local baseChance
    if distance <= 1.0 then
        baseChance = 0.70   -- Adjacent: 70% base
    elseif distance <= 2.0 then
        baseChance = 0.40   -- 2 tiles: 40% base
    elseif distance <= 3.0 then
        baseChance = 0.20   -- 3 tiles: 20% base
    else
        baseChance = 0.08   -- 4+ tiles: 8% base
    end

    -- Beyond detection radius: no chance
    if distance > detectionRadius then
        return false
    end

    -- Stealth stat reduces detection (0-100 mapped to 0-0.40 reduction)
    local stealthReduction = (playerStealthStat or 0) / 250
    baseChance = baseChance - stealthReduction

    -- Moving increases detection chance by 50%
    if isMoving then
        baseChance = baseChance * 1.5
    end

    -- Clamp
    baseChance = math.max(0.02, math.min(0.95, baseChance))

    return math.random() < baseChance
end

-- ============================================================================
--                     PATROL ROUTE GENERATION
-- ============================================================================

-- Generate a random patrol route starting from (x, y).
-- isPassable(x, y) for movement validation.
-- length: optional route length (default random 3-6).
function EnemyAI.generatePatrolRoute(x, y, isPassable, length)
    local route = {{x = x, y = y}}
    local cx, cy = x, y
    local directions = TileUtils.DIRS4
    local routeLength = length or math.random(3, 6)

    for i = 2, routeLength do
        -- Shuffle directions
        local shuffled = {}
        for _, d in ipairs(directions) do
            table.insert(shuffled, math.random(1, #shuffled + 1), d)
        end

        local placed = false
        for _, d in ipairs(shuffled) do
            local nx, ny = cx + d[1], cy + d[2]
            if isPassable(nx, ny) then
                -- Avoid duplicates in route
                local isDuplicate = false
                for _, pos in ipairs(route) do
                    if pos.x == nx and pos.y == ny then
                        isDuplicate = true
                        break
                    end
                end
                if not isDuplicate then
                    table.insert(route, {x = nx, y = ny})
                    cx, cy = nx, ny
                    placed = true
                    break
                end
            end
        end
        if not placed then break end
    end

    return route
end

-- ============================================================================
--                       VISION CONE DRAWING
-- ============================================================================

-- Draw the detection area around an enemy as a semi-transparent overlay.
-- isTileVisible(tileX, tileY): optional function returning true if the tile
--   should have its vision cone drawn (e.g. explored check, passable check).
--   If nil, all tiles in range are drawn.
-- config: table with { visionConeAlpha = number }
function EnemyAI.drawVisionCone(enemy, radius, aiState, mapStartX, mapStartY, cellSize, minViewX, minViewY, maxViewX, maxViewY, time, config, isTileVisible)
    local vr, vg, vb
    if aiState == "chase" then
        vr, vg, vb = 0.9, 0.15, 0.15
    elseif aiState == "search" then
        vr, vg, vb = 0.9, 0.6, 0.15       -- Orange for searching
    elseif aiState == "idle" then
        vr, vg, vb = 0.8, 0.8, 0.2
    else
        vr, vg, vb = 0.2, 0.55, 0.2
    end

    local baseAlpha = config and config.visionConeAlpha or 0.15

    for dy = -radius, radius do
        for dx = -radius, radius do
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist <= radius and (dx ~= 0 or dy ~= 0) then
                local tileX = enemy.x + dx
                local tileY = enemy.y + dy

                if tileX >= minViewX and tileX <= maxViewX and
                   tileY >= minViewY and tileY <= maxViewY then

                    -- Optional visibility filter
                    local visible = true
                    if isTileVisible then
                        visible = isTileVisible(tileX, tileY)
                    end

                    if visible then
                        local screenCol = tileX - minViewX
                        local screenRow = tileY - minViewY
                        local cellPosX = mapStartX + screenCol * cellSize
                        local cellPosY = mapStartY + screenRow * cellSize

                        local alphaFalloff = 1 - (dist / radius)
                        local alpha = baseAlpha * alphaFalloff

                        if aiState == "chase" then
                            alpha = alpha * (1.5 + 0.5 * math.sin(time * 4))
                        elseif aiState == "search" then
                            alpha = alpha * (1.2 + 0.3 * math.sin(time * 2.5))
                        end

                        love.graphics.setColor(vr, vg, vb, alpha)
                        love.graphics.rectangle("fill", cellPosX, cellPosY, cellSize - 1, cellSize - 1)
                    end
                end
            end
        end
    end
end

-- ============================================================================
--                      PUSH ENEMY AWAY FROM POINT
-- ============================================================================

-- Move enemy 2 tiles away from a point, ensuring it lands on a passable tile.
-- isPassable(x, y) for tile validation.
function EnemyAI.pushAwayFrom(enemy, fromX, fromY, isPassable)
    local dx = enemy.x - fromX
    local dy = enemy.y - fromY
    if dx == 0 and dy == 0 then
        dx = math.random(-1, 1)
        dy = math.random(-1, 1)
        if dx == 0 and dy == 0 then dx = 1 end
    end
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0 then
        local newX = enemy.x + math.floor(dx / len * 2 + 0.5)
        local newY = enemy.y + math.floor(dy / len * 2 + 0.5)
        if isPassable(newX, newY) then
            enemy.x = newX
            enemy.y = newY
            return true
        end
    end

    -- Fallback: try adjacent tiles
    for _, offset in ipairs(TileUtils.DIRS8) do
        local nx, ny = enemy.x + offset[1], enemy.y + offset[2]
        if isPassable(nx, ny) then
            enemy.x = nx
            enemy.y = ny
            return true
        end
    end

    return false
end

return EnemyAI
