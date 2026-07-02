# Complete Karma/Crime/Faction System Implementation Guide

## Summary of What's Been Implemented

### ✅ Core Systems (COMPLETE)
1. **Karma/Crime data structures** added (lines 277-458)
2. **Faction data structures** added (15 factions with requirements)
3. **Player data extended** with karma, bounty, crimes, factionRep
4. **Core functions implemented**:
   - commitCrime()
   - arrestPlayer()
   - payBounty()
   - serveJailTime()
   - attemptJailEscape()
   - changeFactionRep()
   - joinFaction()
   - getFactionBenefits()
5. **Save/load migration** added for old saves

### 🔧 Still Needs UI Integration

## Changes Needed in textrpg.lua

### 1. Add Attack Option to NPC Dialogue (Line ~2620)

**Location:** In `buildDialogueOptions()` function

**Before (around line 2620):**
```lua
    -- Always have goodbye
    table.insert(opts, {text = "Goodbye", action = "leave"})

    return opts
end
```

**After:**
```lua
    -- Always have goodbye
    table.insert(opts, {text = "Goodbye", action = "leave"})

    -- CRIME: Attack civilian option (red color)
    table.insert(opts, {text = "[⚔️ Attack]", action = "attack_civilian", color = {0.9, 0.2, 0.2}})

    return opts
end
```

---

### 2. Handle Attack Civilian Action (Line ~13857)

**Location:** In dialogue click handler, after `accept_heal_quest` action

**Add this after the `accept_heal_quest` handler (around line 13863):**
```lua
                elseif opt.action == "attack_civilian" then
                    -- Generate civilian enemy based on NPC
                    local civilianEnemy = {
                        name = npc.name,
                        level = math.max(1, math.random(1, state.player.level - 2)),
                        hp = 20 + math.random(10, 30),
                        maxHP = 20 + math.random(10, 30),
                        attack = 5 + math.random(0, 5),
                        defense = 2 + math.random(0, 3),
                        goldReward = math.random(10, 30),
                        xpReward = math.random(5, 15),
                        isCivilian = true,
                        profession = npc.profession.title,
                    }
                    civilianEnemy.hp = civilianEnemy.maxHP

                    -- Commit assault crime
                    commitCrime("assault_civilian")

                    -- Start combat
                    state.combat.enemy = civilianEnemy
                    state.combat.playerTurn = true
                    state.combat.returnTo = "town"
                    state.combat.isCriminalCombat = true
                    state.phase = "combat"
                    log("You attacked " .. npc.name .. "!", {0.9, 0.2, 0.2})
```

---

### 3. Add Murder Crime on Civilian Kill

**Location:** In combat enemy defeat section (find where enemy.hp <= 0)

**Find the section that handles enemy defeat and add:**
```lua
-- After enemy is defeated, check if it was a civilian
if state.combat.enemy and state.combat.enemy.isCivilian then
    commitCrime("murder_civilian")
    log("You murdered a civilian! Karma greatly decreased.", {0.9, 0.2, 0.2})
end
```

---

### 4. Add Lockpicking Occupant System

**Location:** In `drawLockpickPrompt()` function (line ~8705)

**Modify to detect occupants and add attack/assassinate options:**

```lua
function drawLockpickPrompt(x, y, w, h, mx, my)
    local building = state.lockpickTarget or {name = "Unknown", id = "home1"}
    local difficulty = LOCKPICK_CONFIG.difficulties[building.id] or LOCKPICK_CONFIG.defaultDifficulty

    -- Check for occupants (random chance based on time of day)
    local hour = state.timeOfDay or 12
    local isNight = hour >= 22 or hour < 6
    local occupantChance = isNight and 0.7 or 0.3  -- Higher chance at night (people home)

    if not state.lockpickOccupant then
        if math.random() < occupantChance then
            -- Generate occupant
            state.lockpickOccupant = {
                name = "Occupant",
                isAsleep = isNight and math.random() < 0.6,  -- 60% asleep at night
                level = math.random(1, 3),
                hp = 25,
                maxHP = 25,
                attack = 6,
                defense = 3,
            }
        end
    end

    -- Title
    love.graphics.setColor(0.9, 0.6, 0.2)
    love.graphics.setFont(getFont(20))
    love.graphics.printf("Locked: " .. building.name, x, y + 20, w, "center")

    -- Occupant warning
    if state.lockpickOccupant then
        love.graphics.setColor(0.9, 0.5, 0.3)
        love.graphics.setFont(getFont(14))
        if state.lockpickOccupant.isAsleep then
            love.graphics.printf("⚠️ Someone is sleeping inside...", x, y + 55, w, "center")
        else
            love.graphics.printf("⚠️ Someone is home!", x, y + 55, w, "center")
        end
    end

    -- ... rest of existing code ...

    -- Modify buttons section to add attack/assassinate options
    state.lockpickButtons = {}
    local btnW = 150
    local btnH = 40
    local btnY = y + 200
    local btnSpacing = 15

    if state.lockpickOccupant then
        -- Show attack/assassinate options instead of pick lock
        if state.lockpickOccupant.isAsleep then
            -- Assassinate option (instant kill, more karma loss)
            local assassX = x + w/2 - btnW*1.5 - btnSpacing
            local assassHover = mx >= assassX and mx <= assassX + btnW and my >= btnY and my <= btnY + btnH
            love.graphics.setColor(assassHover and {0.6, 0.1, 0.1} or {0.4, 0.1, 0.1})
            love.graphics.rectangle("fill", assassX, btnY, btnW, btnH, 6, 6)
            love.graphics.setColor(0.9, 0.3, 0.3)
            love.graphics.setFont(getFont(12))
            love.graphics.printf("🗡️ Assassinate", assassX, btnY + 12, btnW, "center")
            state.lockpickButtons.assassinate = {x = assassX, y = btnY, w = btnW, h = btnH}
        end

        -- Attack option
        local attackX = x + w/2 - btnW/2
        local attackHover = mx >= attackX and mx <= attackX + btnW and my >= btnY and my <= btnY + btnH
        love.graphics.setColor(attackHover and {0.7, 0.3, 0.2} or {0.5, 0.2, 0.15})
        love.graphics.rectangle("fill", attackX, btnY, btnW, btnH, 6, 6)
        love.graphics.setColor(0.9, 0.5, 0.3)
        love.graphics.setFont(getFont(12))
        love.graphics.printf("⚔️ Attack", attackX, btnY + 12, btnW, "center")
        state.lockpickButtons.attack = {x = attackX, y = btnY, w = btnW, h = btnH}

        -- Wait option (occupant might leave)
        local waitX = x + w/2 + btnW/2 + btnSpacing
        local waitHover = mx >= waitX and mx <= waitX + btnW and my >= btnY and my <= btnY + btnH
        love.graphics.setColor(waitHover and {0.4, 0.4, 0.5} or {0.25, 0.25, 0.35})
        love.graphics.rectangle("fill", waitX, btnY, btnW, btnH, 6, 6)
        love.graphics.setColor(0.8, 0.8, 0.9)
        love.graphics.setFont(getFont(12))
        love.graphics.printf("⏰ Wait 1h", waitX, btnY + 12, btnW, "center")
        state.lockpickButtons.wait = {x = waitX, y = btnY, w = btnW, h = btnH}
    else
        -- Original pick lock button
        local pickX = x + w/2 - btnW - btnSpacing/2
        local pickHover = mx >= pickX and mx <= pickX + btnW and my >= btnY and my <= btnY + btnH
        love.graphics.setColor(pickHover and {0.5, 0.4, 0.3} or {0.35, 0.3, 0.25})
        love.graphics.rectangle("fill", pickX, btnY, btnW, btnH, 6, 6)
        love.graphics.setColor(0.9, 0.8, 0.6)
        love.graphics.setFont(getFont(13))
        love.graphics.printf("🔓 Pick Lock", pickX, btnY + 12, btnW, "center")
        state.lockpickButtons.attempt = {x = pickX, y = btnY, w = btnW, h = btnH}
    end

    -- Leave button (always available)
    local leaveX = x + w/2 - btnW/2
    local leaveY = btnY + btnH + 15
    local leaveHover = mx >= leaveX and mx <= leaveX + btnW and my >= leaveY and my <= leaveY + btnH
    love.graphics.setColor(leaveHover and {0.4, 0.4, 0.5} or {0.25, 0.25, 0.35})
    love.graphics.rectangle("fill", leaveX, leaveY, btnW, btnH, 6, 6)
    love.graphics.setColor(0.8, 0.8, 0.9)
    love.graphics.printf("Leave", leaveX, leaveY + 12, btnW, "center")
    state.lockpickButtons.leave = {x = leaveX, y = leaveY, w = btnW, h = btnH}
end
```

---

### 5. Handle Lockpick Buttons (Line ~12310)

**Location:** Find lockpick button handling in mousepressed

**Add handlers for new buttons:**
```lua
    elseif state.phase == "lockpick_prompt" then
        if state.lockpickButtons then
            -- Attack occupant
            if state.lockpickButtons.attack then
                local btn = state.lockpickButtons.attack
                if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                    local occupant = state.lockpickOccupant
                    occupant.name = "Home Owner"
                    occupant.isCivilian = true

                    commitCrime("assault_civilian")
                    commitCrime("trespassing")

                    state.combat.enemy = occupant
                    state.combat.playerTurn = true
                    state.combat.returnTo = "town"
                    state.combat.isCriminalCombat = true
                    state.phase = "combat"
                    state.lockpickOccupant = nil
                    log("You attacked the occupant!", {0.9, 0.2, 0.2})
                    return
                end
            end

            -- Assassinate sleeping occupant
            if state.lockpickButtons.assassinate then
                local btn = state.lockpickButtons.assassinate
                if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                    -- Instant kill, but severe karma penalty
                    commitCrime("murder_civilian")
                    commitCrime("trespassing")
                    state.player.karma = math.max(-100, state.player.karma - 20)  -- Extra penalty for assassination

                    -- Generate loot from house
                    local goldFound = math.random(30, 100)
                    state.player.gold = state.player.gold + goldFound

                    state.lockpickOccupant = nil
                    state.phase = "burglary_success"
                    state.burglaryLoot = {gold = goldFound}
                    log("You assassinated the sleeping occupant... (-20 karma)", {0.6, 0.1, 0.1})
                    return
                end
            end

            -- Wait for occupant to leave
            if state.lockpickButtons.wait then
                local btn = state.lockpickButtons.wait
                if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                    -- Advance time by 1 hour
                    state.timeOfDay = (state.timeOfDay + 1) % 24

                    -- 30% chance occupant leaves
                    if math.random() < 0.3 then
                        state.lockpickOccupant = nil
                        log("The occupant left! House is empty now.", {0.5, 0.8, 0.5})
                    else
                        log("You wait an hour, but they're still home...", {0.7, 0.7, 0.5})
                    end
                    return
                end
            end

            -- Original buttons (attempt, leave) handler remains...
        end
```

---

### 6. Add Jail Phase UI

**Location:** Add new draw function and phase handler

**Add draw function for jail screen:**
```lua
-- Jail Phase Screen
function drawJailScreen(x, y, w, h, mx, my)
    local p = state.player
    if not p then return end

    -- Dark prison background
    love.graphics.setColor(0.1, 0.1, 0.15)
    love.graphics.rectangle("fill", x, y, w, h)

    -- Prison bars
    love.graphics.setColor(0.3, 0.3, 0.35)
    for i = 0, 10 do
        local barX = x + i * (w / 10)
        love.graphics.rectangle("fill", barX, y, 8, h)
    end

    -- Title
    love.graphics.setColor(0.7, 0.3, 0.3)
    love.graphics.setFont(getFont(24))
    love.graphics.printf("🔒 IMPRISONED", x, y + 30, w, "center")

    -- Crime list
    love.graphics.setColor(0.9, 0.7, 0.5)
    love.graphics.setFont(getFont(16))
    love.graphics.printf("Crimes Committed:", x, y + 80, w, "center")

    love.graphics.setColor(0.8, 0.6, 0.6)
    love.graphics.setFont(getFont(12))
    local crimeY = y + 110
    for i, crime in ipairs(p.crimes) do
        if i <= 5 then
            love.graphics.printf("• " .. crime.name, x + 50, crimeY, w - 100, "left")
            crimeY = crimeY + 20
        end
    end

    -- Bounty and jail time
    love.graphics.setColor(0.9, 0.5, 0.3)
    love.graphics.setFont(getFont(14))
    love.graphics.printf("Total Bounty: " .. p.bounty .. " gold", x, y + 220, w, "center")
    love.graphics.printf("Jail Time: " .. p.jailTimeRemaining .. " hours (" .. math.floor(p.jailTimeRemaining / 24) .. " days)", x, y + 245, w, "center")

    -- Options
    state.jailButtons = {}
    local btnW = 200
    local btnH = 45
    local btnY = y + 300
    local btnSpacing = 20

    -- Pay Bounty
    local payX = x + w/2 - btnW*1.5 - btnSpacing
    local payCost = math.floor(p.bounty * 1.5)
    local canPay = p.gold >= payCost
    local payHover = canPay and mx >= payX and mx <= payX + btnW and my >= btnY and my <= btnY + btnH
    love.graphics.setColor(payHover and {0.5, 0.6, 0.3} or (canPay and {0.35, 0.4, 0.2} or {0.25, 0.25, 0.25}))
    love.graphics.rectangle("fill", payX, btnY, btnW, btnH, 6, 6)
    love.graphics.setColor(canPay and {0.9, 1, 0.6} or {0.5, 0.5, 0.5})
    love.graphics.setFont(getFont(13))
    love.graphics.printf("💰 Pay Bounty", payX, btnY + 5, btnW, "center")
    love.graphics.setFont(getFont(11))
    love.graphics.printf("(" .. payCost .. " gold)", payX, btnY + 25, btnW, "center")
    if canPay then
        state.jailButtons.pay = {x = payX, y = btnY, w = btnW, h = btnH}
    end

    -- Serve Time
    local serveX = x + w/2 - btnW/2
    local serveHover = mx >= serveX and mx <= serveX + btnW and my >= btnY and my <= btnY + btnH
    love.graphics.setColor(serveHover and {0.4, 0.4, 0.5} or {0.3, 0.3, 0.35})
    love.graphics.rectangle("fill", serveX, btnY, btnW, btnH, 6, 6)
    love.graphics.setColor(0.8, 0.8, 0.9)
    love.graphics.setFont(getFont(13))
    love.graphics.printf("⏰ Serve Time", serveX, btnY + 5, btnW, "center")
    love.graphics.setFont(getFont(11))
    love.graphics.printf("(" .. math.floor(p.jailTimeRemaining / 24) .. " days)", serveX, btnY + 25, btnW, "center")
    state.jailButtons.serve = {x = serveX, y = btnY, w = btnW, h = btnH}

    -- Escape
    local escapeX = x + w/2 + btnW/2 + btnSpacing
    local dexMod = getStatModifier(p.stats.DEX)
    local escapeChance = math.floor((0.3 + dexMod * 0.05) * 100)
    if p.class.id == "rogue" then
        escapeChance = escapeChance + 20
    end
    local escapeHover = mx >= escapeX and mx <= escapeX + btnW and my >= btnY and my <= btnY + btnH
    love.graphics.setColor(escapeHover and {0.5, 0.3, 0.3} or {0.35, 0.2, 0.2})
    love.graphics.rectangle("fill", escapeX, btnY, btnW, btnH, 6, 6)
    love.graphics.setColor(0.9, 0.5, 0.5)
    love.graphics.setFont(getFont(13))
    love.graphics.printf("🏃 Attempt Escape", escapeX, btnY + 5, btnW, "center")
    love.graphics.setFont(getFont(11))
    love.graphics.printf("(" .. escapeChance .. "% chance)", escapeX, btnY + 25, btnW, "center")
    state.jailButtons.escape = {x = escapeX, y = btnY, w = btnW, h = btnH}

    -- Warning
    love.graphics.setColor(0.6, 0.5, 0.5)
    love.graphics.setFont(getFont(10))
    love.graphics.printf("Escaping doubles your bounty if caught!", x, y + h - 40, w, "center")
end
```

**Add jail phase to draw function (around line 7393):**
```lua
    elseif state.phase == "jailed" then
        drawJailScreen(contentX, contentY, contentW, contentH, mx, my)
```

**Add jail button handlers in mousepressed (find where other phases are handled):**
```lua
    elseif state.phase == "jailed" then
        if state.jailButtons then
            if state.jailButtons.pay then
                local btn = state.jailButtons.pay
                if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                    payBounty()
                    return
                end
            end
            if state.jailButtons.serve then
                local btn = state.jailButtons.serve
                if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                    serveJailTime()
                    return
                end
            end
            if state.jailButtons.escape then
                local btn = state.jailButtons.escape
                if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                    attemptJailEscape()
                    return
                end
            end
        end
```

---

## Testing Checklist

1. [ ] Talk to NPC, see Attack option in red
2. [ ] Attack NPC, verify combat starts and karma decreases
3. [ ] Kill civilian, verify murder crime committed
4. [ ] Try lockpicking at night, verify occupant can be detected
5. [ ] Assassinate sleeping occupant, verify instant kill and karma loss
6. [ ] Attack awake occupant, verify combat starts
7. [ ] Wait for occupant to leave, verify time advances
8. [ ] Get arrested, see jail screen with 3 options
9. [ ] Pay bounty, verify gold deducted and released
10. [ ] Serve jail time, verify days pass
11. [ ] Attempt escape, verify DEX-based success/failure
12. [ ] Save and load game, verify karma/crimes persist

---

## Optional Enhancements (Future)

1. **Faction UI**: Add menu to view/join factions
2. **Karma Display**: Show karma level in character sheet
3. **Guard Patrols**: NPCs that chase high-bounty players
4. **Faction Benefits**: Apply bonuses from joined factions
5. **Faction Quests**: Unique quests for each faction
6. **Crime Witnesses**: NPCs can witness crimes and report you
7. **Bribery System**: Pay guards to look the other way
8. **Reputation Decay**: Crimes slowly forgotten over time
