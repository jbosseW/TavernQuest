-- ============================================================================
-- TACTICAL COMBAT AI
-- Enemy and Companion AI for Grid-Based Tactical Combat
-- ============================================================================

local TacticalAI = {}
local TileUtils = require("tileutils")
local TC  -- Will be set via init (TacticalCombat reference)

function TacticalAI.init(tacticalCombat)
    TC = tacticalCombat
end

-- ============================================================================
-- ENEMY AI
-- ============================================================================

-- Execute a full enemy turn (move + attack)
-- Phase 7: Respects stun/root, hazard-aware movement
function TacticalAI.executeEnemyTurn(combatState, unit)
    local grid = combatState.grid
    local results = {moved = false, attacked = false, moveTarget = nil, attackResult = nil}

    -- Phase 7: If stunned, skip entire turn
    if not TC.canAct(unit) then
        results.stunned = true
        return results
    end

    -- Step 1: Find the best target
    local target = TacticalAI.findBestTarget(combatState, unit)
    if not target then
        -- No valid targets, wait
        return results
    end

    -- Step 2: Check if we can attack from current position
    local canAttack = TC.canAttackTarget(grid, unit, target)

    if canAttack and not unit.hasMoved then
        -- Can attack from current position - attack first, then consider moving
        local success, attackResult = TC.performAttack(combatState, unit, target)
        if success then
            results.attacked = true
            results.attackResult = attackResult
            results.target = target
        end
        return results
    end

    -- Step 3: Need to move closer (or reposition)
    -- Phase 7: Root prevents movement
    if not unit.hasMoved and TC.getEffectiveMoveRange(unit) > 0 then
        local moveResult = TacticalAI.findBestMovePosition(combatState, unit, target)
        if moveResult then
            local success, path = TC.moveUnit(combatState, unit, moveResult.x, moveResult.y)
            if success then
                results.moved = true
                results.moveTarget = moveResult
                results.movePath = path
            end
        end
    end

    -- Step 4: Attack after moving (if in range now)
    if not unit.hasActed then
        -- Re-evaluate target from new position
        target = TacticalAI.findBestTarget(combatState, unit)
        if target then
            canAttack = TC.canAttackTarget(grid, unit, target)
            if canAttack then
                local success, attackResult = TC.performAttack(combatState, unit, target)
                if success then
                    results.attacked = true
                    results.attackResult = attackResult
                    results.target = target
                end
            end
        end
    end

    return results
end

-- Find the best target for an enemy to attack
function TacticalAI.findBestTarget(combatState, unit)
    local allyUnits = TC.getLivingUnits(combatState, "ally")
    if #allyUnits == 0 then return nil end

    local bestTarget = nil
    local bestScore = -999

    for _, target in ipairs(allyUnits) do
        -- Skip hidden/untargetable units - enemies cannot see them
        if target.isHidden then goto skipTarget end
        if TC.hasStatus and TC.hasStatus(target, "hidden") then goto skipTarget end

        local score = TacticalAI.evaluateTarget(combatState, unit, target)
        if score > bestScore then
            bestScore = score
            bestTarget = target
        end

        ::skipTarget::
    end

    return bestTarget
end

-- Evaluate how desirable a target is (Phase 7: enhanced threat assessment)
function TacticalAI.evaluateTarget(combatState, attacker, target)
    local score = 0
    local dist = TC.getDistance(attacker.x, attacker.y, target.x, target.y)

    -- Prefer closer targets
    score = score - dist * 5

    -- Prefer low HP targets (can finish them off)
    local hpPct = target.hp / target.maxHP
    if hpPct < 0.3 then
        score = score + 40  -- Low HP: high priority kill
    elseif hpPct < 0.5 then
        score = score + 20  -- Moderate damage: good target
    end

    -- Phase 7: Can we actually kill this target this turn?
    local estDamage = math.max(1, attacker.attack - target.defense)
    if estDamage >= target.hp then
        score = score + 50  -- Kill shot: highest priority
    end

    -- Prefer squishier targets
    local defenseScore = target.defense or 0
    score = score - defenseScore

    -- Prefer the player (strategic value)
    if target.isPlayer then
        score = score + 15
    end

    -- Prefer healers (eliminate support)
    if target.canHeal then
        score = score + 25
    end

    -- Phase 7: Prefer targets with debuffs (marked, stunned, etc.)
    if TC.hasStatus(target, "marked") then
        score = score + 15  -- Marked targets take extra damage
    end
    if TC.hasStatus(target, "stun") or TC.hasStatus(target, "root") then
        score = score + 10  -- Incapacitated targets are easy prey
    end

    -- Prefer targets in range (can attack this turn)
    if TC.canAttackTarget(combatState.grid, attacker, target) then
        score = score + 30
    end

    -- Consider if we can reach attack range this turn
    local effectiveMove = TC.getEffectiveMoveRange(attacker)
    local reachable = TC.getMovementRange(combatState.grid, attacker.x, attacker.y, effectiveMove)
    for _, tile in ipairs(reachable) do
        local reachDist = TC.getDistance(tile.x, tile.y, target.x, target.y)
        if reachDist >= (attacker.minAttackRange or 1) and reachDist <= attacker.attackRange then
            score = score + 20  -- Can attack this turn after moving
            break
        end
    end

    return score
end

-- Find the best position to move to (for attacking or positioning)
-- Phase 7: Enhanced with hazard awareness and status-aware movement
function TacticalAI.findBestMovePosition(combatState, unit, target)
    local grid = combatState.grid
    -- Phase 7: use effective move range (accounts for root/slow status)
    local effectiveMove = TC.getEffectiveMoveRange(unit)
    local reachable = TC.getMovementRange(grid, unit.x, unit.y, effectiveMove)

    local bestTile = nil
    local bestScore = -999

    for _, tile in ipairs(reachable) do
        -- Skip current position
        if tile.x == unit.x and tile.y == unit.y then goto continue end

        local score = 0
        local dist = TC.getDistance(tile.x, tile.y, target.x, target.y)

        -- Phase 10: use effective attack range (elevation bonus)
        local effectiveRange = TC.getEffectiveAttackRange(grid, unit)

        -- Primary: Get into attack range
        if dist >= (unit.minAttackRange or 1) and dist <= effectiveRange then
            -- In attack range: big bonus
            score = score + 100

            -- Check LOS from this position
            if TC.hasLineOfSight(grid, tile.x, tile.y, target.x, target.y) then
                score = score + 50
            end
        else
            -- Not in range: move closer
            score = score - dist * 10
        end

        -- Terrain bonus: prefer high ground
        local moveTile = grid.tiles[tile.y][tile.x]
        if moveTile.height > TC.HEIGHT_NORMAL then
            score = score + 15
        end

        -- Terrain defense bonus
        local terrain = TC.TERRAIN[moveTile.type]
        if terrain and terrain.defBonus > 0 then
            score = score + 10
        end

        -- Phase 7: AVOID hazard tiles (fire, poison, trap)
        if terrain and terrain.hazardDmg then
            score = score - terrain.hazardDmg * 3  -- heavily penalize hazard tiles
        end
        if moveTile.type == "ice" then
            score = score - 5  -- mild penalty for ice (slip risk)
        end

        -- Avoid clustering with other enemies (spread out)
        local adjacentAllies = 0
        local neighbors = TileUtils.DIRS4
        for _, n in ipairs(neighbors) do
            local adj = TC.getUnitAt(grid, tile.x + n[1], tile.y + n[2])
            if adj and adj.faction == unit.faction then
                adjacentAllies = adjacentAllies + 1
            end
        end
        score = score - adjacentAllies * 5

        -- Flanking: prefer positions where allies are on opposite side of target
        if dist <= effectiveRange then
            local flankScore = TacticalAI.evaluateFlankingPosition(grid, tile, target, unit)
            score = score + flankScore
        end

        -- Phase 7: Low HP enemies prefer defensive positions (behind cover)
        local hpPct = unit.hp / unit.maxHP
        if hpPct < 0.3 then
            -- Prefer tiles farther from enemies when low
            score = score + dist * 2
            -- Prefer cover
            if terrain and terrain.defBonus > 0 then
                score = score + 20
            end
        end

        if score > bestScore then
            bestScore = score
            bestTile = tile
        end

        ::continue::
    end

    return bestTile
end

-- Evaluate a position for flanking advantage
function TacticalAI.evaluateFlankingPosition(grid, position, target, unit)
    local neighbors = TileUtils.DIRS4
    local allyOnOppositeSide = false

    -- Check if there's a friendly unit on the opposite side of the target
    local dx = position.x - target.x
    local dy = position.y - target.y

    -- Opposite side
    local oppositeX = target.x - dx
    local oppositeY = target.y - dy

    local oppUnit = TC.getUnitAt(grid, oppositeX, oppositeY)
    if oppUnit and oppUnit.faction == unit.faction and oppUnit ~= unit and oppUnit.hp > 0 then
        return 20  -- Flanking bonus
    end

    -- Adjacent allies near target
    for _, n in ipairs(neighbors) do
        local adj = TC.getUnitAt(grid, target.x + n[1], target.y + n[2])
        if adj and adj.faction == unit.faction and adj ~= unit and adj.hp > 0 then
            return 10  -- Nearby ally bonus
        end
    end

    return 0
end

-- ============================================================================
-- COMPANION AI
-- ============================================================================

-- Execute a companion's turn (Phase 7: stun/root-aware)
function TacticalAI.executeCompanionTurn(combatState, unit)
    local grid = combatState.grid
    local results = {moved = false, attacked = false, healed = false}

    -- Phase 7: If stunned, skip entire turn
    if not TC.canAct(unit) then
        results.stunned = true
        return results
    end

    -- Step 1: Healers check if healing is needed first
    if unit.canHeal then
        local healTarget = TacticalAI.findHealTarget(combatState, unit)
        if healTarget then
            -- Move toward heal target if needed
            local dist = TC.getDistance(unit.x, unit.y, healTarget.x, healTarget.y)
            if dist > 3 and not unit.hasMoved then
                local moveResult = TacticalAI.findBestMoveToward(combatState, unit, healTarget)
                if moveResult then
                    TC.moveUnit(combatState, unit, moveResult.x, moveResult.y)
                    results.moved = true
                end
            end

            -- Heal (if in range)
            dist = TC.getDistance(unit.x, unit.y, healTarget.x, healTarget.y)
            if dist <= 3 then  -- Heal range of 3
                local healAmt = unit.healAmount or 15
                healTarget.hp = math.min(healTarget.maxHP, healTarget.hp + healAmt)
                if healTarget.data then healTarget.data.hp = healTarget.hp end
                unit.hasActed = true
                results.healed = true
                results.healTarget = healTarget
                results.healAmount = healAmt
                return results
            end
        end
    end

    -- Step 2: Find best enemy target
    local target = TacticalAI.findBestCompanionTarget(combatState, unit)
    if not target then return results end

    -- Step 3: Check if can attack from current position
    local canAttack = TC.canAttackTarget(grid, unit, target)

    if canAttack then
        -- Attack immediately
        local success, attackResult = TC.performAttack(combatState, unit, target)
        if success then
            results.attacked = true
            results.attackResult = attackResult
            results.target = target
        end
        return results
    end

    -- Step 4: Move toward target
    if not unit.hasMoved then
        local moveResult = TacticalAI.findBestMovePosition(combatState, unit, target)
        if moveResult then
            local success, path = TC.moveUnit(combatState, unit, moveResult.x, moveResult.y)
            if success then
                results.moved = true
                results.moveTarget = moveResult
                results.movePath = path
            end
        end
    end

    -- Step 5: Attack after moving
    if not unit.hasActed then
        target = TacticalAI.findBestCompanionTarget(combatState, unit)
        if target and TC.canAttackTarget(grid, unit, target) then
            local success, attackResult = TC.performAttack(combatState, unit, target)
            if success then
                results.attacked = true
                results.attackResult = attackResult
                results.target = target
            end
        end
    end

    return results
end

-- Find best target for companion (slightly different priorities than enemies)
function TacticalAI.findBestCompanionTarget(combatState, unit)
    local enemyUnits = TC.getLivingUnits(combatState, "enemy")
    if #enemyUnits == 0 then return nil end

    local bestTarget = nil
    local bestScore = -999

    for _, target in ipairs(enemyUnits) do
        local score = 0
        local dist = TC.getDistance(unit.x, unit.y, target.x, target.y)

        -- Prefer closer targets
        score = score - dist * 5

        -- Prefer low HP targets
        local hpPct = target.hp / target.maxHP
        if hpPct < 0.3 then score = score + 30 end
        if hpPct < 0.5 then score = score + 15 end

        -- Prefer targets already being attacked
        if TC.canAttackTarget(combatState.grid, unit, target) then
            score = score + 25
        end

        -- Prefer high CR targets (focus fire on big threats)
        score = score + (target.cr or 1) * 5

        if score > bestScore then
            bestScore = score
            bestTarget = target
        end
    end

    return bestTarget
end

-- Find ally that needs healing most
function TacticalAI.findHealTarget(combatState, healer)
    local allies = TC.getLivingUnits(combatState, "ally")
    local bestTarget = nil
    local lowestPct = 1.0

    for _, ally in ipairs(allies) do
        if ally ~= healer and ally.hp > 0 then
            local hpPct = ally.hp / ally.maxHP
            if hpPct < 0.5 and hpPct < lowestPct then
                lowestPct = hpPct
                bestTarget = ally
            end
        end
    end

    return bestTarget
end

-- Find best tile to move toward a target (for healing range, etc.)
function TacticalAI.findBestMoveToward(combatState, unit, target)
    local grid = combatState.grid
    local effectiveMove = TC.getEffectiveMoveRange(unit)
    if effectiveMove <= 0 then return nil end
    local reachable = TC.getMovementRange(grid, unit.x, unit.y, effectiveMove)

    local bestTile = nil
    local bestDist = 999

    for _, tile in ipairs(reachable) do
        local dist = TC.getDistance(tile.x, tile.y, target.x, target.y)
        if dist < bestDist then
            bestDist = dist
            bestTile = tile
        end
    end

    return bestTile
end

return TacticalAI
