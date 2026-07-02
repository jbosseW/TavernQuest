# TACTICAL COMBAT IMPLEMENTATION ROADMAP
## Step-by-Step Development Plan

**Date:** 2026-01-30
**Project:** Tavern Quest Tactical Combat Conversion
**Recommended Approach:** Hybrid Zone System (Incremental)
**Related Documents:**
- TACTICAL_COMBAT_FEASIBILITY_REPORT.md
- TACTICAL_COMBAT_UI_MOCKUPS.md

---

## EXECUTIVE DECISION REQUIRED

Before starting, the Manager must choose ONE of these paths:

### PATH A: Hybrid Zone System (RECOMMENDED)
- **Time Investment:** 20-30 hours
- **Risk Level:** MEDIUM
- **Reward:** Tactical combat without overwhelming complexity
- **Upgrade Path:** Can expand to full grid later

### PATH B: Full FFT-Style Grid
- **Time Investment:** 60-80 hours
- **Risk Level:** HIGH
- **Reward:** Maximum tactical depth
- **Downside:** Large time sink, higher chance of bugs

### PATH C: Enhanced Current System
- **Time Investment:** 8-12 hours
- **Risk Level:** LOW
- **Reward:** Minor tactical improvements
- **Downside:** No real positioning mechanics

**This roadmap focuses on PATH A (Hybrid Zones) as the optimal choice.**

---

## PHASE 0: PREPARATION (2-3 hours)

### 0.1 Backup & Branch
```bash
# Create backup of textrpg.lua
cp textrpg.lua textrpg_backup_before_tactical.lua

# Create save state backup
cp -r saves/ saves_backup/

# CRITICAL: Test that backups work
# Load backup file, verify game runs
```

### 0.2 Create Test Environment
```lua
-- Add to textrpg.lua (top of file)
local TACTICAL_MODE = false  -- Feature flag

-- Add debug toggle (press F9 to switch modes)
function love.keypressed(key)
    if key == "f9" then
        TACTICAL_MODE = not TACTICAL_MODE
        log("Tactical Mode: " .. tostring(TACTICAL_MODE), {0.9, 0.9, 0.3})
    end
    -- ... rest of keypressed
end
```

### 0.3 Study Current Combat Code
**Read these sections carefully:**
- Lines 11294-11961: Combat logic
- Lines 21534-22100+: Combat UI
- Lines 3524-3545: SKILLS table
- Lines 3722-3856: Companion system

**Document all dependencies:**
- Where is `state.combat` accessed?
- What functions call `startCombat()`?
- What systems depend on combat results?

### 0.4 Set Up Testing Framework
```lua
-- Add quick combat test function
F.testTacticalCombat = function()
    -- Spawn test encounter
    local testEnemies = {
        createEnemyInstance(ENEMIES[2], 3),  -- Goblin
        createEnemyInstance(ENEMIES[2], 3),  -- Goblin
        createEnemyInstance(ENEMIES[10], 5), -- Orc
    }

    -- Give player test party
    if not state.player.party then
        state.player.party = {}
    end
    if #state.player.party < 2 then
        table.insert(state.player.party, createCompanion("warrior"))
        table.insert(state.player.party, createCompanion("cleric"))
    end

    -- Start combat
    if TACTICAL_MODE then
        startZoneCombat(testEnemies)
    else
        startCombat(testEnemies)
    end
end

-- Bind to F10 key
-- Press F10 to instantly start test combat
```

---

## PHASE 1: ZONE DATA STRUCTURE (4-6 hours)

### 1.1 Define Zone System Data
**File:** `textrpg.lua` (add near line 6550 where combat state is defined)

```lua
-- Zone-based tactical combat state
function initZoneCombat()
    return {
        zones = {
            back = {
                allies = {},
                enemies = {},
                defensiveBonus = 0.3,  -- -30% damage from ranged
                meleeDebuff = 0.3,     -- -30% melee damage dealt
            },
            mid = {
                allies = {},
                enemies = {},
                defensiveBonus = 0,
                meleeDebuff = 0,
            },
            front = {
                allies = {},
                enemies = {},
                offensiveBonus = 0.2,  -- +20% melee damage dealt
                damageVulnerability = 0.1,  -- +10% damage taken
            },
        },

        -- Track which zone each combatant is in
        unitZones = {
            -- [unit_id] = "back"|"mid"|"front"
        },

        -- Movement tracking
        unitsMovedThisTurn = {},  -- Units that already moved this turn
        currentPhase = "move",    -- "move" or "action"

        -- Keep existing combat state
        turnOrder = {},
        currentTurnIndex = 0,
        log = {},
        -- ... (all existing fields)
    }
end
```

### 1.2 Helper Functions
```lua
-- Get which zone a unit is in
function getUnitZone(unit)
    local combat = state.combat
    if not combat or not combat.zones then return nil end

    for zoneName, zone in pairs(combat.zones) do
        -- Check allies
        for _, ally in ipairs(zone.allies) do
            if ally == unit then
                return zoneName
            end
        end
        -- Check enemies
        for _, enemy in ipairs(zone.enemies) do
            if enemy == unit then
                return zoneName
            end
        end
    end

    return nil  -- Not found
end

-- Get all units in a zone
function getUnitsInZone(zoneName, faction)
    local zone = state.combat.zones[zoneName]
    if not zone then return {} end

    if faction == "allies" then
        return zone.allies
    elseif faction == "enemies" then
        return zone.enemies
    else
        -- Return both
        local all = {}
        for _, u in ipairs(zone.allies) do table.insert(all, u) end
        for _, u in ipairs(zone.enemies) do table.insert(all, u) end
        return all
    end
end

-- Move unit between zones
function moveUnitToZone(unit, fromZone, toZone)
    local combat = state.combat
    if not combat or not combat.zones then return false end

    local faction = (unit == state.player or isCompanion(unit)) and "allies" or "enemies"

    -- Remove from old zone
    if fromZone and combat.zones[fromZone] then
        local fromList = combat.zones[fromZone][faction]
        for i, u in ipairs(fromList) do
            if u == unit then
                table.remove(fromList, i)
                break
            end
        end
    end

    -- Add to new zone
    if combat.zones[toZone] then
        table.insert(combat.zones[toZone][faction], unit)
        log(unit.name .. " moves to " .. toZone .. " line", {0.7, 0.7, 0.9})
        return true
    end

    return false
end

-- Check if companion
function isCompanion(unit)
    if not state.player or not state.player.party then return false end
    for _, comp in ipairs(state.player.party) do
        if comp == unit then return true end
    end
    return false
end
```

### 1.3 Initial Placement Logic
```lua
-- Place units in zones at start of combat
function placeUnitsInZones(enemies)
    local combat = state.combat

    -- Place player based on class
    local playerClass = state.player.class and state.player.class.id or "warrior"
    if playerClass == "warrior" or playerClass == "monk" then
        table.insert(combat.zones.front.allies, state.player)
    elseif playerClass == "mage" or playerClass == "cleric" then
        table.insert(combat.zones.back.allies, state.player)
    else
        table.insert(combat.zones.mid.allies, state.player)
    end

    -- Place companions
    if state.player.party then
        for _, companion in ipairs(state.player.party) do
            if companion.hp > 0 then
                local compClass = companion.class and companion.class.id or "warrior"
                if compClass == "warrior" or compClass == "monk" then
                    table.insert(combat.zones.front.allies, companion)
                elseif compClass == "mage" or compClass == "cleric" then
                    table.insert(combat.zones.back.allies, companion)
                else
                    table.insert(combat.zones.mid.allies, companion)
                end
            end
        end
    end

    -- Place enemies
    for _, enemy in ipairs(enemies) do
        -- High CR enemies go to front (tanks/bosses)
        if enemy.cr >= 3 then
            table.insert(combat.zones.front.enemies, enemy)
        -- Ranged enemies (archers, mages) go to back
        elseif enemy.id:match("archer") or enemy.id:match("mage") or enemy.id:match("shaman") then
            table.insert(combat.zones.back.enemies, enemy)
        -- Default to mid
        else
            table.insert(combat.zones.mid.enemies, enemy)
        end
    end
end
```

### 1.4 Modify startCombat()
**File:** `textrpg.lua` line ~11302

```lua
startCombat = function(enemies)
    -- Convert single enemy to array (legacy compatibility)
    local enemyList = enemies
    if enemies.name then
        enemyList = {enemies}
    end

    state.phase = "combat"

    -- NEW: Check if using tactical zones
    if TACTICAL_MODE then
        state.combat = initZoneCombat()  -- NEW zone structure
    else
        state.combat = {
            -- Old structure (keep as-is)
            enemies = enemyList,
            selectedTarget = 1,
            turnOrder = {},
            -- ... rest of old fields
        }
    end

    -- Keep all existing code (initiative, logging, etc.)
    state.combat.enemies = enemyList  -- Still track enemy list
    state.combat.selectedTarget = 1
    state.combat.turnOrder = {}
    state.combat.currentTurnIndex = 0
    -- ... (all existing initialization)

    -- NEW: Place units in zones (only if tactical)
    if TACTICAL_MODE then
        placeUnitsInZones(enemyList)
    end

    -- Keep all existing initiative rolling code
    -- ... (unchanged)

    -- Start first turn (unchanged)
    advanceTurn()
end
```

**Test Checkpoint:**
- Press F9 to enable tactical mode
- Press F10 to start test combat
- Verify zones are created
- Verify units are placed in zones
- Check console for zone placement logs

---

## PHASE 2: ZONE-BASED TARGETING (4-5 hours)

### 2.1 Range Calculation
```lua
-- Check if attacker can hit target based on zones
function canAttackAcrossZones(attackerZone, targetZone, attackRange)
    -- Melee attacks (range 1)
    if attackRange == "melee" or attackRange == 1 then
        -- Can only hit same zone or adjacent
        if attackerZone == targetZone then
            return true
        end
        if attackerZone == "front" and targetZone == "mid" then
            return true
        end
        if attackerZone == "mid" and (targetZone == "front" or targetZone == "back") then
            return true
        end
        if attackerZone == "back" and targetZone == "mid" then
            return true
        end
        return false
    end

    -- Ranged attacks (range 2+)
    if attackRange == "ranged" or attackRange >= 2 then
        -- Can hit any zone
        return true
    end

    return false
end

-- Get valid targets for current unit
function getValidTargets(attacker)
    local attackerZone = getUnitZone(attacker)
    if not attackerZone then return {} end

    local attackRange = attacker.attackRange or "melee"
    local targets = {}

    -- Check all enemy zones
    for zoneName, zone in pairs(state.combat.zones) do
        if canAttackAcrossZones(attackerZone, zoneName, attackRange) then
            for _, enemy in ipairs(zone.enemies) do
                if enemy.hp > 0 then
                    table.insert(targets, {unit = enemy, zone = zoneName})
                end
            end
        end
    end

    return targets
end
```

### 2.2 Modify Attack Functions
**Update F.playerAttack() around line 11457:**

```lua
F.playerAttack = function()
    local targetIdx = state.combat.selectedTarget
    local target = state.combat.enemies[targetIdx]

    if not target or target.hp <= 0 then
        log("Invalid target!", {0.8, 0.3, 0.3})
        return
    end

    -- NEW: Check zone range (only in tactical mode)
    if TACTICAL_MODE then
        local playerZone = getUnitZone(state.player)
        local targetZone = getUnitZone(target)
        local playerRange = state.player.attackRange or "melee"

        if not canAttackAcrossZones(playerZone, targetZone, playerRange) then
            log("Target out of range! Move closer or use ranged attack.", {0.9, 0.5, 0.3})
            return
        end
    end

    -- Rest of function unchanged (damage calculation, etc.)
    local p = state.player
    local petBonus = Backpack.getPetBattleBonus()
    local baseDamage = p.attack + petBonus - target.defense + math.random(-3, 3)

    -- NEW: Apply zone bonuses
    if TACTICAL_MODE then
        local attackerZone = getUnitZone(state.player)
        local zone = state.combat.zones[attackerZone]

        -- Offensive bonus (front line)
        if zone and zone.offensiveBonus then
            baseDamage = math.floor(baseDamage * (1 + zone.offensiveBonus))
        end

        -- Melee debuff (back line)
        if zone and zone.meleeDebuff and playerRange == "melee" then
            baseDamage = math.floor(baseDamage * (1 - zone.meleeDebuff))
        end
    end

    -- Continue with existing code...
    local critChance = p.critChance or 5
    local isCrit = math.random(100) <= critChance
    -- ... (rest unchanged)
end
```

### 2.3 Update Companion AI
**Modify F.companionTurn() around line 11662:**

```lua
F.companionTurn = function()
    local compIdx = state.combat.currentCompanionIndex
    if not compIdx then
        advanceTurn()
        return
    end

    local companion = state.player.party[compIdx]
    if not companion or companion.hp <= 0 then
        advanceTurn()
        return
    end

    -- NEW: Tactical AI - position before attacking
    if TACTICAL_MODE then
        -- Healers prefer back line
        if companion.canHeal then
            local currentZone = getUnitZone(companion)
            if currentZone ~= "back" then
                moveUnitToZone(companion, currentZone, "back")
            end
        end
        -- Warriors prefer front line
        if companion.class.id == "warrior" or companion.class.id == "monk" then
            local currentZone = getUnitZone(companion)
            if currentZone ~= "front" then
                moveUnitToZone(companion, currentZone, "front")
            end
        end
    end

    -- Rest of AI logic (healing, attacking) unchanged but with range checks
    -- ... (keep existing code, add range validation)
end
```

**Test Checkpoint:**
- Start tactical combat
- Verify player can only attack enemies in range
- Try attacking back-line enemy from front (should fail)
- Give player ranged weapon, verify can hit any zone
- Check companion AI positions correctly

---

## PHASE 3: MOVEMENT SYSTEM (3-4 hours)

### 3.1 Movement Action
```lua
-- Player chooses to move to a zone
F.playerMoveZone = function(toZone)
    if not TACTICAL_MODE then return end
    if not state.combat or not state.combat.isPlayerTurn then return end

    local player = state.player
    local fromZone = getUnitZone(player)

    if fromZone == toZone then
        log("Already in " .. toZone .. " line.", {0.7, 0.7, 0.7})
        return
    end

    -- Check if already moved this turn
    if state.combat.unitsMovedThisTurn[player] then
        log("Already moved this turn!", {0.9, 0.5, 0.3})
        return
    end

    -- Move
    if moveUnitToZone(player, fromZone, toZone) then
        state.combat.unitsMovedThisTurn[player] = true
        -- Don't end turn yet, player can still attack/use skill
    end
end
```

### 3.2 Turn Phase Tracking
```lua
-- Modify advanceTurn() to reset movement tracking
advanceTurn = function()
    -- Existing code...

    -- NEW: Reset movement tracking for new turn
    if TACTICAL_MODE then
        state.combat.unitsMovedThisTurn = {}
    end

    -- Continue with existing code...
    for i = 1, orderLen do
        local idx = ((startIndex - 1 + i - 1) % orderLen) + 1
        local turn = state.combat.turnOrder[idx]
        -- ... (existing turn logic)
    end
end
```

### 3.3 Enemy Tactical AI
```lua
-- Smart enemy positioning
function enemyZoneTurn(enemy)
    if not TACTICAL_MODE then return end

    local currentZone = getUnitZone(enemy)
    local enemyRange = enemy.attackRange or "melee"

    -- Find closest player/companion
    local targets = {}
    for zoneName, zone in pairs(state.combat.zones) do
        for _, ally in ipairs(zone.allies) do
            if ally.hp > 0 then
                table.insert(targets, {unit = ally, zone = zoneName})
            end
        end
    end

    if #targets == 0 then return end

    -- Simple AI: Move to zone with most allies if can't attack
    local validTargets = getValidTargets(enemy)
    if #validTargets == 0 then
        -- No valid targets, need to move
        local targetZone = findBestZoneForEnemy(enemy, targets)
        if targetZone and targetZone ~= currentZone then
            moveUnitToZone(enemy, currentZone, targetZone)
        end
    end
end

function findBestZoneForEnemy(enemy, allyTargets)
    -- Count allies in each zone
    local zoneScores = {back = 0, mid = 0, front = 0}
    for _, target in ipairs(allyTargets) do
        zoneScores[target.zone] = zoneScores[target.zone] + 1
    end

    -- Melee enemies prefer front/mid
    if (enemy.attackRange or "melee") == "melee" then
        if zoneScores.front > 0 then return "front" end
        if zoneScores.mid > 0 then return "mid" end
        return "back"
    else
        -- Ranged enemies prefer back
        return "back"
    end
end
```

**Test Checkpoint:**
- Player can move between zones
- Movement uses up move action
- Enemies reposition intelligently
- Melee enemies close distance
- Ranged enemies stay at range

---

## PHASE 4: ZONE UI (6-8 hours)

### 4.1 Zone Panel Rendering
**Add new function around line 21534 (combat UI section):**

```lua
function drawZoneCombat(x, y, w, h, mx, my)
    if not state.combat or not state.combat.zones then
        drawCombat(x, y, w, h, mx, my)  -- Fallback to old UI
        return
    end

    local zones = state.combat.zones
    local zoneHeight = 160
    local zoneSpacing = 15
    local zoneY = y + 60

    -- Draw each zone (back, mid, front)
    local zoneOrder = {"back", "mid", "front"}
    for i, zoneName in ipairs(zoneOrder) do
        local zone = zones[zoneName]
        local zy = zoneY + (i - 1) * (zoneHeight + zoneSpacing)

        -- Zone panel background
        local bgColor = {0.12, 0.14, 0.18}
        if zoneName == "back" then
            bgColor = {0.10, 0.12, 0.16}  -- Darker
        elseif zoneName == "front" then
            bgColor = {0.18, 0.14, 0.14}  -- Reddish tint
        end

        love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3], 0.95)
        love.graphics.rectangle("fill", x + 10, zy, w - 140, zoneHeight, 8, 8)

        -- Border
        love.graphics.setColor(0.4, 0.45, 0.5)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", x + 10, zy, w - 140, zoneHeight, 8, 8)
        love.graphics.setLineWidth(1)

        -- Zone label
        love.graphics.setColor(0.7, 0.75, 0.8)
        love.graphics.setFont(getFont(14))
        love.graphics.print(zoneName:upper() .. " LINE", x + 20, zy + 8)

        -- Draw enemies in zone
        local enemyX = x + 20
        local enemyY = zy + 35
        for ei, enemy in ipairs(zone.enemies) do
            drawZoneUnitCard(enemy, enemyX + (ei - 1) * 160, enemyY, 150, 110, "enemy")
        end

        -- Draw allies in zone
        local allyX = x + 20
        local allyY = zy + 35 + 60  -- Below enemies
        for ai, ally in ipairs(zone.allies) do
            drawZoneUnitCard(ally, allyX + (ai - 1) * 160, allyY, 150, 50, "ally")
        end
    end

    -- Turn order panel (right side) - reuse existing
    drawTurnOrder(x + w - 120, y + 20, 110, 300)

    -- Action buttons (bottom)
    drawZoneActionButtons(x, y + h - 100, w - 130, 90, mx, my)
end

function drawZoneUnitCard(unit, x, y, w, h, faction)
    -- Card background
    local bgColor = faction == "enemy" and {0.18, 0.12, 0.12} or {0.10, 0.14, 0.18}
    love.graphics.setColor(bgColor[1], bgColor[2], bgColor[3])
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)

    -- Name
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(11))
    love.graphics.print(unit.name, x + 8, y + 6)

    -- HP bar
    local barW = w - 16
    local barH = 12
    local barY = y + h - barH - 6
    local hpPct = math.max(0, unit.hp / unit.maxHP)

    love.graphics.setColor(0.2, 0.2, 0.25)
    love.graphics.rectangle("fill", x + 8, barY, barW, barH, 3, 3)

    local barColor = hpPct > 0.5 and {0.3, 0.85, 0.3} or
                     (hpPct > 0.25 and {0.85, 0.85, 0.3} or {0.85, 0.3, 0.3})
    love.graphics.setColor(barColor)
    love.graphics.rectangle("fill", x + 8, barY, barW * hpPct, barH, 3, 3)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(9))
    love.graphics.printf(unit.hp .. "/" .. unit.maxHP, x + 8, barY + 1, barW, "center")
end
```

### 4.2 Movement UI
```lua
function drawZoneActionButtons(x, y, w, h, mx, my)
    if not state.combat.isPlayerTurn then
        -- Show waiting message
        love.graphics.setColor(0.7, 0.7, 0.8)
        love.graphics.setFont(getFont(13))
        love.graphics.printf("Waiting for turn...", x + 20, y + 30, w, "left")
        return
    end

    local actions = {
        {name = "ATTACK", key = "Z", color = {0.9, 0.35, 0.35}},
        {name = "SKILL", key = "X", color = {0.45, 0.5, 0.95}},
        {name = "MOVE", key = "C", color = {0.3, 0.85, 0.4}},
        {name = "ITEM", key = "V", color = {0.85, 0.7, 0.3}},
    }

    local btnW, btnH = 100, 40
    local btnSpacing = 10
    local btnY = y + 20

    for i, act in ipairs(actions) do
        local bx = x + 20 + (i - 1) * (btnW + btnSpacing)
        local hover = mx >= bx and mx <= bx + btnW and my >= btnY and my <= btnY + btnH

        -- Shadow
        love.graphics.setColor(0.05, 0.05, 0.08, 0.5)
        love.graphics.rectangle("fill", bx + 2, btnY + 2, btnW, btnH, 5, 5)

        -- Button
        if hover then
            love.graphics.setColor(act.color[1] * 0.8, act.color[2] * 0.8, act.color[3] * 0.8)
        else
            love.graphics.setColor(act.color[1] * 0.5, act.color[2] * 0.5, act.color[3] * 0.5)
        end
        love.graphics.rectangle("fill", bx, btnY, btnW, btnH, 5, 5)

        -- Border
        love.graphics.setColor(act.color)
        love.graphics.setLineWidth(hover and 3 or 2)
        love.graphics.rectangle("line", bx, btnY, btnW, btnH, 5, 5)
        love.graphics.setLineWidth(1)

        -- Text
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(12))
        love.graphics.printf(act.name, bx, btnY + 13, btnW, "center")
    end

    -- Show zone movement submenu if active
    if state.combat.showMoveMenu then
        drawZoneMoveMenu(x + 20, y - 180, 300, 160, mx, my)
    end
end

function drawZoneMoveMenu(x, y, w, h, mx, my)
    -- Background
    love.graphics.setColor(0.12, 0.14, 0.18, 0.98)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    love.graphics.setColor(0.3, 0.85, 0.4)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x, y, w, h, 6, 6)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(0.7, 0.75, 0.85)
    love.graphics.setFont(getFont(12))
    love.graphics.print("Select Zone to Move To:", x + 10, y + 10)

    local currentZone = getUnitZone(state.player)
    local zoneOptions = {
        {name = "BACK LINE", zone = "back", desc = "Safe, ranged position"},
        {name = "MID LINE", zone = "mid", desc = "Balanced position"},
        {name = "FRONT LINE", zone = "front", desc = "Melee combat zone"},
    }

    local optionH = 35
    local optionY = y + 35
    for i, opt in ipairs(zoneOptions) do
        local oy = optionY + (i - 1) * (optionH + 5)
        local hover = mx >= x + 10 and mx <= x + w - 10 and my >= oy and my <= oy + optionH
        local isCurrent = (opt.zone == currentZone)

        -- Background
        if isCurrent then
            love.graphics.setColor(0.2, 0.3, 0.25)  -- Green tint (current)
        elseif hover then
            love.graphics.setColor(0.3, 0.35, 0.4)
        else
            love.graphics.setColor(0.18, 0.2, 0.24)
        end
        love.graphics.rectangle("fill", x + 10, oy, w - 20, optionH, 4, 4)

        -- Text
        if isCurrent then
            love.graphics.setColor(0.5, 0.9, 0.5)
            love.graphics.setFont(getFont(11))
            love.graphics.print("• " .. opt.name .. " (Current)", x + 18, oy + 6)
        else
            love.graphics.setColor(hover and {1, 1, 1} or {0.8, 0.8, 0.85})
            love.graphics.setFont(getFont(11))
            love.graphics.print("↑ " .. opt.name, x + 18, oy + 6)
        end

        love.graphics.setFont(getFont(9))
        love.graphics.setColor(0.6, 0.6, 0.65)
        love.graphics.print(opt.desc, x + 18, oy + 20)

        -- Store clickable area
        state.combat.zoneMoveButtons = state.combat.zoneMoveButtons or {}
        state.combat.zoneMoveButtons[i] = {
            x = x + 10, y = oy, w = w - 20, h = optionH,
            zone = opt.zone, isCurrent = isCurrent
        }
    end
end
```

### 4.3 Input Handling
**Modify mousepressed handler (around line 25700+):**

```lua
-- In mousepressed function
if state.phase == "combat" then
    if TACTICAL_MODE then
        -- Zone movement menu clicks
        if state.combat.showMoveMenu and state.combat.zoneMoveButtons then
            for i, btn in ipairs(state.combat.zoneMoveButtons) do
                if mx >= btn.x and mx <= btn.x + btn.w and
                   my >= btn.y and my <= btn.y + btn.h and
                   not btn.isCurrent then
                    F.playerMoveZone(btn.zone)
                    state.combat.showMoveMenu = false
                    return
                end
            end
        end

        -- Action button clicks
        -- ... (implement button click detection)
    else
        -- Old combat input handling
    end
end
```

**Add keyboard shortcuts:**
```lua
function love.keypressed(key)
    -- ... existing code

    if state.phase == "combat" and TACTICAL_MODE then
        if state.combat.isPlayerTurn then
            if key == "c" then
                -- Toggle move menu
                state.combat.showMoveMenu = not state.combat.showMoveMenu
            elseif key == "z" then
                -- Attack
                state.combat.showMoveMenu = false
                -- ... attack logic
            elseif key == "x" then
                -- Skills
                state.combat.showMoveMenu = false
                state.combat.showSkills = not state.combat.showSkills
            end
        end
    end
end
```

**Test Checkpoint:**
- Zone UI renders correctly
- Unit cards show in correct zones
- Movement menu opens/closes
- Clicking zone moves player
- Keyboard shortcuts work (Z/X/C/V)

---

## PHASE 5: SKILLS & ITEMS INTEGRATION (3-4 hours)

### 5.1 Update SKILLS Table
**Add range properties to skills around line 3524:**

```lua
local SKILLS = {
    ["Power Strike"] = {
        manaCost = 10,
        damage = 25,
        type = "physical",
        desc = "A powerful melee attack",
        range = "melee",  -- NEW
    },
    ["Shield Bash"] = {
        manaCost = 15,
        damage = 15,
        type = "physical",
        stun = true,
        desc = "Stun the enemy",
        range = "melee",  -- NEW
    },
    ["Fireball"] = {
        manaCost = 20,
        damage = 35,
        type = "magic",
        desc = "Blast of fire",
        range = "ranged",  -- NEW - can hit any zone
    },
    ["Heal"] = {
        manaCost = 15,
        heal = 30,
        desc = "Restore 30 HP",
        range = "ranged",  -- NEW - can heal any ally
        targetAlly = true,  -- NEW
    },
    -- ... update all skills
}
```

### 5.2 Skill Targeting
```lua
F.useSkill = function(skillName)
    local skill = SKILLS[skillName]
    if not skill then return end

    if state.player.mana < skill.manaCost then
        log("Not enough mana!", {0.8, 0.3, 0.3})
        return
    end

    -- NEW: Zone range check
    if TACTICAL_MODE and skill.damage then
        local targetIdx = state.combat.selectedTarget
        local target = state.combat.enemies[targetIdx]

        if target and target.hp > 0 then
            local playerZone = getUnitZone(state.player)
            local targetZone = getUnitZone(target)
            local skillRange = skill.range or "melee"

            if not canAttackAcrossZones(playerZone, targetZone, skillRange) then
                log("Target out of skill range!", {0.9, 0.5, 0.3})
                return
            end
        end
    end

    -- Existing skill logic (damage/heal/etc.)
    state.player.mana = state.player.mana - skill.manaCost
    -- ... (rest unchanged)
end
```

### 5.3 Item Usage
Items mostly work as-is, just add range checks for targeting items:

```lua
-- Healing potions can target anyone in party (any zone)
-- Bombs/throwables use "ranged" targeting rules
```

**Test Checkpoint:**
- Melee skills only hit adjacent zones
- Ranged skills hit any zone
- Healing works across zones
- Mana costs still apply

---

## PHASE 6: FLANKING & TACTICAL BONUSES (2-3 hours)

### 6.1 Flanking Detection
```lua
-- Check if enemy is flanked (multiple allies in same zone)
function isEnemyFlanked(enemy)
    if not TACTICAL_MODE then return false end

    local enemyZone = getUnitZone(enemy)
    if not enemyZone then return false end

    local zone = state.combat.zones[enemyZone]
    if not zone then return false end

    -- Count living allies in same zone
    local allyCount = 0
    for _, ally in ipairs(zone.allies) do
        if ally.hp > 0 then
            allyCount = allyCount + 1
        end
    end

    -- Flanked if 2+ allies in zone
    return allyCount >= 2
end

-- Apply flanking bonus to damage
function applyFlankingBonus(damage, target)
    if isEnemyFlanked(target) then
        local bonus = math.floor(damage * 0.25)  -- +25%
        log("FLANKED! +" .. bonus .. " damage", {0.9, 0.7, 0.3})
        return damage + bonus
    end
    return damage
end
```

### 6.2 Update Damage Calculations
**In F.playerAttack() and F.companionTurn():**

```lua
-- After calculating base damage
damage = math.max(1, baseDamage)
if isCrit then
    damage = math.floor(damage * critMult)
end

-- NEW: Apply flanking
if TACTICAL_MODE then
    damage = applyFlankingBonus(damage, target)
end

target.hp = target.hp - damage
```

### 6.3 Visual Indicators
**In drawZoneUnitCard():**

```lua
-- Add flanking icon
if faction == "enemy" and isEnemyFlanked(unit) then
    love.graphics.setColor(0.9, 0.7, 0.3)
    love.graphics.setFont(getFont(10))
    love.graphics.print("⚠️ FLANKED", x + 8, y + 25)
end

-- Add zone bonus indicators
local zone = getUnitZone(unit)
if zone and state.combat.zones[zone] then
    local zoneData = state.combat.zones[zone]
    if zoneData.offensiveBonus and zoneData.offensiveBonus > 0 then
        love.graphics.setColor(0.9, 0.5, 0.3)
        love.graphics.setFont(getFont(9))
        love.graphics.print("+" .. (zoneData.offensiveBonus * 100) .. "% ATK", x + 8, y + 40)
    end
end
```

**Test Checkpoint:**
- Flanking triggers with 2+ allies in zone
- Damage bonus applies correctly
- Visual indicator shows on enemy cards
- Zone bonuses display properly

---

## PHASE 7: TESTING & BALANCE (6-10 hours)

### 7.1 Unit Testing
Create comprehensive test suite:

```lua
-- Test file: test_zones.lua
local tests = {}

function tests.testZonePlacement()
    -- Reset game state
    initPlayer("Tester", "warrior")

    -- Create test enemies
    local enemies = {
        createEnemyInstance(ENEMIES[2], 3),  -- Goblin
    }

    -- Start combat
    TACTICAL_MODE = true
    startCombat(enemies)

    -- Verify zones created
    assert(state.combat.zones ~= nil, "Zones not created")
    assert(state.combat.zones.back ~= nil, "Back zone missing")

    -- Verify player placed
    local playerZone = getUnitZone(state.player)
    assert(playerZone ~= nil, "Player not in any zone")

    print("✓ Zone placement test passed")
end

function tests.testMovement()
    -- Place player in mid
    -- Move to front
    -- Verify moved
    -- Try to move again (should fail)
end

function tests.testRangeAttacks()
    -- Place player in back
    -- Place enemy in front
    -- Verify melee attack fails
    -- Give ranged weapon
    -- Verify ranged attack works
end

function tests.testFlanking()
    -- Place 2 allies + 1 enemy in front
    -- Attack enemy
    -- Verify flanking bonus applied
end

-- Run all tests
function runAllTests()
    for name, testFunc in pairs(tests) do
        print("Running: " .. name)
        local success, err = pcall(testFunc)
        if not success then
            print("✗ FAILED: " .. err)
        end
    end
end

-- Bind to F11: Press to run tests
```

### 7.2 Balance Testing
**Create test scenarios:**

1. **Solo Player vs 3 Weak Enemies**
   - Player should win with tactical positioning
   - Test melee vs ranged advantage

2. **Party of 3 vs 5 Enemies**
   - Test companion AI positioning
   - Verify healer stays in back

3. **Boss Fight (CR 5+ enemy)**
   - Test high-damage enemy AI
   - Verify tactical retreat works

**Track metrics:**
- Average combat duration
- Player win rate
- Most effective zones
- Damage distribution

### 7.3 Bug Fixing Checklist
- [ ] Player can't attack unreachable targets
- [ ] Companions don't get stuck in wrong zones
- [ ] Enemies don't skip turns
- [ ] Zone bonuses apply correctly
- [ ] UI doesn't overlap
- [ ] Keyboard shortcuts all work
- [ ] Mouse clicks register properly
- [ ] Initiative order displays correctly
- [ ] Turn doesn't end prematurely
- [ ] Victory/defeat triggers properly

### 7.4 Edge Cases
- Combat with 1 enemy (zones still work)
- Combat with 8+ enemies (UI handles overflow)
- Player at 1 HP (can still move/act)
- All enemies in one zone (targeting works)
- Player party of 1 (no companions)
- Enemy with CR 0.25 (weak enemies)

**Test Checkpoint:**
- All unit tests pass
- No crashes during combat
- Balance feels fair
- UI is responsive

---

## PHASE 8: POLISH & OPTIMIZATION (4-6 hours)

### 8.1 Visual Polish
```lua
-- Add zone transition animations
function animateZoneMove(unit, fromZone, toZone, duration)
    -- Smooth slide animation (optional)
    -- Particle effects (optional)
    -- Sound effects
end

-- Add damage number popups
function showDamagePopup(x, y, damage, isCrit)
    -- Floating text that fades out
    -- Different color for crits
end

-- Add zone highlights on hover
function highlightZoneOnHover(zoneName)
    -- Subtle glow effect
    -- Shows valid targets
end
```

### 8.2 Sound Effects
```lua
-- Add tactical combat sounds
sounds.zoneMove = love.audio.newSource("assets/sounds/move.wav", "static")
sounds.flankingHit = love.audio.newSource("assets/sounds/flanking.wav", "static")
sounds.zoneBonus = love.audio.newSource("assets/sounds/buff.wav", "static")

-- Play on actions
function playZoneMoveSound()
    if sounds.zoneMove then
        sounds.zoneMove:play()
    end
end
```

### 8.3 Tutorial System
```lua
-- First-time zone combat tutorial
function showZoneTutorial()
    if not PlayerData.hasSeenZoneTutorial then
        log("=== TACTICAL COMBAT ===", {0.9, 0.9, 0.3})
        log("Combat now uses positioning zones!", {0.7, 0.7, 0.9})
        log("- FRONT LINE: Melee combat (+20% damage, +10% damage taken)", {0.7, 0.7, 0.9})
        log("- MID LINE: Balanced position", {0.7, 0.7, 0.9})
        log("- BACK LINE: Ranged safety (-30% melee damage, +30% defense)", {0.7, 0.7, 0.9})
        log("Press [C] to move between zones!", {0.9, 0.9, 0.3})

        PlayerData.hasSeenZoneTutorial = true
        savePlayerData()
    end
end

-- Call in startZoneCombat()
```

### 8.4 Performance Optimization
```lua
-- Cache zone lookups
local zoneCache = {}
function getUnitZoneCached(unit)
    if zoneCache[unit] then
        return zoneCache[unit]
    end

    local zone = getUnitZone(unit)
    zoneCache[unit] = zone
    return zone
end

-- Clear cache on zone changes
function moveUnitToZone(unit, from, to)
    zoneCache[unit] = nil  -- Invalidate cache
    -- ... rest of function
end

-- Batch rendering (draw all zone cards at once)
-- Minimize love.graphics.setColor() calls
```

### 8.5 Save/Load Compatibility
```lua
-- Ensure old saves work with new system
function TextRPG.load()
    if PlayerData.textRPG then
        state.player = PlayerData.textRPG.player
        -- ... existing load code

        -- NEW: Detect old save files
        if state.phase == "combat" and not state.combat.zones then
            -- Old combat in progress - convert to zone combat
            if TACTICAL_MODE then
                convertOldCombatToZones()
            end
        end
    end
end

function convertOldCombatToZones()
    -- Take existing combat state
    -- Create zones
    -- Place units based on class/CR
    log("Converting combat to tactical zones...", {0.9, 0.9, 0.3})
end
```

**Test Checkpoint:**
- Animations smooth (if added)
- Sounds play correctly (if added)
- Tutorial shows for new players
- Performance is 60 FPS
- Old saves load correctly
- No memory leaks

---

## PHASE 9: FEATURE FLAG REMOVAL (1-2 hours)

### 9.1 Decision Point
**Once zone system is fully tested and working:**

**Option A: Make Zones Default**
```lua
-- Change feature flag default
local TACTICAL_MODE = true  -- Was false

-- Remove F9 toggle
-- Make zones the standard combat
```

**Option B: Keep Both Systems**
```lua
-- Add options menu toggle
PlayerData.useTacticalCombat = true  -- Default

-- In options menu:
"Tactical Combat: [ON/OFF]"
"Use positioning zones in combat"

-- Keep both code paths maintained
```

**Option C: Gradual Rollout**
```lua
-- Zones only for certain encounters
if enemy.isBoss or encounterType == "dungeon" then
    TACTICAL_MODE = true
else
    TACTICAL_MODE = false
end

-- Slowly expand zone usage based on feedback
```

### 9.2 Code Cleanup
```lua
-- If making zones permanent, remove old code paths:

-- DELETE: All "if TACTICAL_MODE then" branches
-- Keep only zone-based logic

-- REMOVE: Old drawCombat() function
-- Rename drawZoneCombat() to drawCombat()

-- SIMPLIFY: No more dual code paths
```

### 9.3 Documentation
```lua
-- Add comments to code
-- Update design docs
-- Create player guide

-- Example:
"""
TACTICAL COMBAT SYSTEM

Zones:
- BACK: Safe for ranged units
- MID: Balanced positioning
- FRONT: Melee combat zone

Combat Flow:
1. Choose zone (optional)
2. Choose action (attack/skill/item)
3. End turn
"""
```

---

## PHASE 10: EXPANSION POSSIBILITIES (Future)

### 10.1 Advanced Tactics (Post-Launch)
Once zone system is stable, consider adding:

**Height Advantages:**
```lua
zones.back.height = "high"  -- +10% ranged damage
zones.front.height = "low"  -- -10% ranged defense
```

**Environmental Hazards:**
```lua
zones.mid.hazard = "fire"  -- 5 damage per turn
zones.front.hazard = "poison"  -- Status effect
```

**Zone-Specific Skills:**
```lua
SKILLS["Cavalry Charge"] = {
    desc = "Charge from back to front, dealing damage along the way",
    requiresZone = "back",
    movesToZone = "front",
    damageAllZones = true,
}
```

**Multi-Zone Attacks:**
```lua
SKILLS["Chain Lightning"] = {
    damage = 30,
    range = "ranged",
    hitsAllZones = true,  -- Hits one enemy per zone
}
```

### 10.2 Full Grid Conversion (Months Later)
**If players love zones and want more depth:**

1. Keep zone system as foundation
2. Add grid within each zone (3x3 mini-grids)
3. Gradually add pathfinding
4. Full grid becomes "expert mode"

**This incremental approach minimizes risk.**

---

## TIMELINE SUMMARY

| Phase | Description | Hours | Cumulative |
|-------|-------------|-------|------------|
| 0 | Preparation & Backup | 2-3 | 2-3 |
| 1 | Zone Data Structure | 4-6 | 6-9 |
| 2 | Zone-Based Targeting | 4-5 | 10-14 |
| 3 | Movement System | 3-4 | 13-18 |
| 4 | Zone UI | 6-8 | 19-26 |
| 5 | Skills & Items | 3-4 | 22-30 |
| 6 | Flanking & Bonuses | 2-3 | 24-33 |
| 7 | Testing & Balance | 6-10 | 30-43 |
| 8 | Polish & Optimization | 4-6 | 34-49 |
| 9 | Feature Flag Removal | 1-2 | 35-51 |
| **TOTAL** | **Full Zone System** | **35-51** | - |

**Realistic Estimate: 40-45 hours for experienced LÖVE developer**

---

## RISK MITIGATION

### Critical Safeguards

1. **Never Edit Core Files Directly**
   - Always work in branches or with backups
   - Test on separate save files

2. **Feature Flag Everything**
   - TACTICAL_MODE lets you switch back instantly
   - No need to delete old code until zone system proven

3. **Incremental Testing**
   - Test after each phase
   - Don't move to next phase until current works

4. **Rollback Plan**
   - Keep textrpg_backup_before_tactical.lua
   - Keep old combat functions commented out
   - Can revert in < 5 minutes if disaster strikes

5. **Player Feedback**
   - Release to small group first
   - Gather feedback before removing old system
   - Be willing to iterate based on response

---

## SUCCESS METRICS

**Minimum Viable Product (MVP):**
- [ ] Zones render correctly
- [ ] Units placed in zones automatically
- [ ] Player can move between zones
- [ ] Melee/ranged attacks respect zone ranges
- [ ] Combat completes without crashes
- [ ] Victory/defeat work correctly

**Full Release Quality:**
- [ ] All MVP criteria met
- [ ] Companion AI uses zones intelligently
- [ ] Enemy AI positions tactically
- [ ] Flanking bonus works
- [ ] Zone bonuses apply correctly
- [ ] UI is polished and clear
- [ ] Tutorial explains system
- [ ] Old saves still work
- [ ] 0 critical bugs
- [ ] 60 FPS performance

**Stretch Goals:**
- [ ] Animations for zone movement
- [ ] Sound effects for tactical actions
- [ ] Tooltips explain bonuses
- [ ] Advanced enemy AI (flanking, focusing healers)
- [ ] Zone-specific environmental effects

---

## NEXT STEPS FOR MANAGER

**Immediate Actions:**

1. **Review This Roadmap**
   - Approve/reject hybrid zone approach
   - Decide on time allocation (40 hours acceptable?)
   - Choose feature flag strategy

2. **Allocate Development Time**
   - Schedule focused work sessions
   - Avoid interruptions during implementation
   - Plan 2-3 hour blocks minimum

3. **Set Milestone Goals**
   - Week 1: Phases 0-3 (foundation)
   - Week 2: Phases 4-6 (UI + mechanics)
   - Week 3: Phases 7-9 (testing + polish)

4. **Prepare for Feedback**
   - Identify beta testers
   - Create feedback survey
   - Plan iteration based on response

---

## FINAL RECOMMENDATION

**START WITH PHASE 0-1 THIS WEEKEND**

- Backup files (30 min)
- Add feature flag (15 min)
- Create zone data structure (2-3 hours)
- Test that zones initialize (30 min)

**Total: ~4 hours for weekend prototype**

If you enjoy working on it and it shows promise, continue with phases 2-3 next week. If it feels wrong or too complex, you've only invested 4 hours and can easily roll back.

**This is the low-risk, high-reward approach.**

---

**Roadmap Compiled By:** UI Designer - Interface & UX Specialist
**Confidence Level:** Very High (based on deep codebase analysis)
**Estimated Accuracy:** ±15% time variance (35-51 hours realistic range)
**Recommendation Strength:** STRONG - Zone system is the optimal path forward

**Good luck! The future of Tavern Quest combat is in your hands.**
