# Journal System Design

## Overview
Comprehensive journal/log system accessible via toggle switch, displaying event logs, quests, actions, factions, party status, player stats, diseases, and infections.

---

## 1. Journal Toggle Switch

### Location
**Position**: Left panel, below stealth toggle (y=235)
**Size**: 120x35 pixels
**States**:
- **OFF**: 📕 Closed (gray theme)
- **ON**: 📖 Open (blue theme)

### Visual Design
```
JOURNAL CLOSED:
┌──────────────────────┐
│ 📕 Journal     ⚪️    │
└──────────────────────┘

JOURNAL OPEN:
┌──────────────────────┐
│ 📖 Journal        🔵 │
└──────────────────────┘
```

---

## 2. Journal Window Layout

### Window Dimensions
- **Width**: 700px
- **Height**: 500px
- **Position**: Center screen
- **Style**: Dark overlay with tabs

### Tab Structure
```
┌─────────────────────────────────────────────┐
│  📖 JOURNAL                         [X]      │
├─────────────────────────────────────────────┤
│ [Events] [Quests] [Actions] [Factions]      │
│ [Party] [Stats] [Status]                    │
├─────────────────────────────────────────────┤
│                                              │
│              Tab Content Area                │
│                                              │
│                                              │
│                                              │
│                                              │
│                                              │
└─────────────────────────────────────────────┘
```

---

## 3. Tab Definitions

### Tab 1: Event Logs 📜
**Purpose**: Complete history of game events

**Content**:
- Timestamped events (day/hour)
- Color-coded by type:
  - Combat (red)
  - Quest (yellow)
  - Crime (orange)
  - Trade (green)
  - Level up (gold)
  - Discovery (blue)
- Search/filter options
- Auto-scroll to latest

**Data Structure**:
```lua
eventLog = {
    {
        day = 5,
        hour = 14,
        type = "combat",
        message = "Defeated Goblin",
        color = {0.9, 0.3, 0.3}
    },
    {
        day = 5,
        hour = 15,
        type = "quest",
        message = "Completed: Fetch Iron Ore",
        color = {0.9, 0.7, 0.2}
    }
}
```

**Display**:
```
Day 5, 14:00 - [COMBAT] Defeated Goblin
Day 5, 15:00 - [QUEST] Completed: Fetch Iron Ore
Day 5, 16:00 - [CRIME] Attacked civilian (Detection: 45%)
Day 5, 22:00 - [STEALTH] Lockpicked merchant shop
```

### Tab 2: Quests 📋
**Purpose**: Active and completed quests

**Sections**:
1. **Active Quests** (top)
   - Quest name
   - Objective
   - Progress bar
   - Reward
   - Time remaining (if timed)

2. **Completed Quests** (bottom)
   - Quest name
   - Completion date
   - Rewards received

**Display**:
```
=== ACTIVE QUESTS (3) ===
[⚔️] Slay the Lich Lord
└─ Objective: Defeat the Lich in his lair
└─ Progress: Lair discovered, not entered
└─ Reward: 500 XP, 1000g, Legendary Item

[📦] Fetch Iron Ore
└─ Objective: Collect 10 Iron Ore
└─ Progress: [████████░░] 8/10
└─ Reward: 50 XP, 100g

=== COMPLETED QUESTS (12) ===
✓ Day 3 - Help the Blacksmith (100g, 50 XP)
✓ Day 2 - Deliver Message (50g, 25 XP)
```

### Tab 3: Actions Performed 📊
**Purpose**: Statistics on player actions

**Categories**:
- **Combat**:
  - Enemies defeated by type
  - Total damage dealt
  - Deaths/respawns
  - Perfect combats (no damage taken)

- **Crimes**:
  - Crimes committed by type
  - Times arrested
  - Bounty paid (total)
  - Successful stealth crimes

- **Exploration**:
  - Tiles explored
  - Towns discovered
  - Dungeons cleared
  - Distance traveled

- **Economy**:
  - Gold earned (total)
  - Gold spent
  - Items crafted
  - Items sold

- **Social**:
  - NPCs talked to
  - Quests completed
  - Party members recruited
  - Vampires created

**Display**:
```
=== COMBAT STATISTICS ===
Total Enemies Defeated: 247
├─ Goblins: 89
├─ Skeletons: 45
├─ Wolves: 32
├─ Vampires: 12
└─ Bosses: 3

Damage Dealt: 12,450
Deaths: 2
Perfect Combats: 34

=== CRIME STATISTICS ===
Crimes Committed: 23
├─ Theft: 15
├─ Assault: 5
├─ Vampire Attacks: 3
Times Arrested: 4
Bounty Paid: 2,500g
Stealth Success Rate: 78%
```

### Tab 4: Factions 🏛️
**Purpose**: Faction reputation and benefits

**Content**:
- List all factions
- Current reputation level
- Reputation bar
- Faction benefits (active)
- Requirements to join
- Joined status

**Display**:
```
=== LAWFUL FACTIONS ===
[Holy Dominion] ⭐⭐⭐☆☆ Friendly (65/100)
├─ Status: Member since Day 5
├─ Benefits: +10% healing, Shop discount 5%
└─ Next Rank: Honored (100 rep)

[Dwarven Kingdom] ⭐⭐☆☆☆ Neutral (30/100)
├─ Status: Not a member
├─ Requirements: Complete quest "Help the Dwarves"
└─ Benefits: Crafting bonus 10%, Mining speed +25%

=== CRIMINAL FACTIONS ===
[Thieves' Guild] ⭐⭐⭐⭐☆ Honored (85/100)
├─ Status: Member since Day 3
├─ Benefits: Lockpick speed +25%, Fence prices 15% better
└─ Next Rank: Exalted (100 rep)

[Assassins' Guild] ⭐☆☆☆☆ Unfriendly (-20/100)
├─ Status: Not a member
└─ Requirements: Karma < -25, Complete assassination contract
```

### Tab 5: Party 👥
**Purpose**: Party member status and details

**Content**:
- List all party members
- Health/Mana bars
- Level and class
- Equipment
- Status effects
- Loyalty/morale

**Display**:
```
=== ACTIVE PARTY (2/3) ===

[Warrior] Thorin Ironbeard - Lvl 8
HP: [████████████░░] 145/160
Mana: [███████░░░░░░░] 45/80
Equipment: Steel Sword, Chain Mail
Status: Healthy
Loyalty: High (85%)

[Rogue] Lyra Shadowstep - Lvl 6
HP: [██████████████] 90/90
Mana: [████████░░░░░░] 50/100
Equipment: Poisoned Blade, Studded Leather
Status: Poisoned (-2 HP/turn)
Loyalty: Moderate (60%)

=== AVAILABLE SLOTS: 1 ===
Recruit more companions at taverns!
```

### Tab 6: Stats 📈
**Purpose**: Player character statistics

**Content**:
- **Primary Stats**: STR, DEX, CON, INT, WIS, CHA with modifiers
- **Combat Stats**: HP, Mana, Attack, Defense, Crit, Dodge
- **Secondary Stats**: Carry capacity, Movement speed
- **Skills Unlocked**: List of skill tree skills
- **Talents**: List of talents
- **Bonuses**: Active bonuses from equipment/factions

**Display**:
```
=== CHARACTER: Hero ===
Class: Rogue (Assassin) - Level 12
XP: 2,450/3,000

=== PRIMARY STATS ===
STR: 12 (+1)    CON: 14 (+2)    WIS: 10 (+0)
DEX: 18 (+4)    INT: 10 (+0)    CHA: 12 (+1)

=== COMBAT STATS ===
HP: 145/145          Attack: 32
Mana: 80/80          Defense: 18
Crit Chance: 22%     Dodge: 18%
Crit Damage: 175%    Block: 0%

=== SKILLS UNLOCKED ===
✓ Backstab, Shadow Blend, Silent Movement
✓ Master of Disguise, Quick Escape

=== TALENTS ===
✓ Tough (+15% HP)
✓ Sneaky (-10% detection)
✓ Night Owl (-20% detection at night)

=== ACTIVE BONUSES ===
+ Stealth Cloak: -20% detection
+ Thieves' Guild: Lockpick +25%
+ Night time: -60% detection
```

### Tab 7: Status 🩺
**Purpose**: Health conditions, buffs, debuffs

**Content**:
- **Vampire Status**: If vampire, show details
- **Diseases**: Active diseases with duration
- **Poisons**: Active poisons with tick damage
- **Infections**: Wounds, infections, severity
- **Buffs**: Temporary positive effects
- **Debuffs**: Temporary negative effects
- **Curses**: Long-term penalties
- **Addictions**: Dependencies (if system exists)

**Display**:
```
=== VAMPIRE STATUS ===
🦇 Vampiric Curse - Active
├─ Transformed: Day 8 (4 days ago)
├─ Stats: 2x multiplier active
├─ Weakness: Sunlight (5-30 HP/sec)
├─ Protection: Vampire Coffin (equipped)
└─ Skills: Blood Drain, Night Vision, Hypnotic Gaze

=== DISEASES & INFECTIONS ===
None

=== ACTIVE POISONS ===
⚠️ Weak Poison
├─ Damage: 3 HP/turn
├─ Duration: 5 turns remaining
└─ Source: Spider bite

=== ACTIVE BUFFS ===
✓ Well Fed (+10% HP regen, 2 hours)
✓ Mage's Blessing (+20% mana, 1 hour)

=== ACTIVE DEBUFFS ===
⚠️ Cursed Ground (-5 Defense, 30 minutes)
⚠️ Exhausted (-10% stamina, until rest)

=== CURSES ===
None

=== OVERALL STATUS ===
Health: Good
Morale: High
Hunger: Satisfied
Fatigue: Well Rested
```

---

## 4. Journal Data Structures

### Player Journal State
```lua
player.journal = {
    isOpen = false,
    currentTab = "events",  -- Default tab
    eventLog = {},
    actionStats = {
        combat = {
            enemiesDefeated = 0,
            defeatedByType = {},
            damageDealt = 0,
            deaths = 0,
            perfectCombats = 0,
        },
        crimes = {
            crimesCommitted = 0,
            crimesByType = {},
            timesArrested = 0,
            bountyPaid = 0,
            stealthSuccesses = 0,
            stealthFailures = 0,
        },
        exploration = {
            tilesExplored = 0,
            townsDiscovered = 0,
            dungeonsCleared = 0,
            distanceTraveled = 0,
        },
        economy = {
            goldEarned = 0,
            goldSpent = 0,
            itemsCrafted = 0,
            itemsSold = 0,
        },
        social = {
            npcsTalkedTo = 0,
            questsCompleted = 0,
            partyMembers = 0,
            vampiresCreated = 0,
        },
    },
    scrollOffset = 0,  -- For scrolling content
}
```

### Event Log Entry
```lua
local function addJournalEvent(type, message, color)
    if not state.player.journal then return end

    table.insert(state.player.journal.eventLog, {
        day = state.daysPassed or 0,
        hour = math.floor(state.timeOfDay or 12),
        type = type,
        message = message,
        color = color or {1, 1, 1}
    })

    -- Keep only last 200 events to prevent memory bloat
    if #state.player.journal.eventLog > 200 then
        table.remove(state.player.journal.eventLog, 1)
    end
end
```

---

## 5. UI Implementation

### Toggle Button Position
```lua
-- Journal toggle (below stealth toggle)
local journalToggleX = 10
local journalToggleY = 235
local journalToggleW = 120
local journalToggleH = 35
```

### Journal Window Rendering
```lua
local function drawJournal()
    if not state.player.journal or not state.player.journal.isOpen then
        return
    end

    local screenW, screenH = love.graphics.getDimensions()
    local w = 700
    local h = 500
    local x = screenW/2 - w/2
    local y = screenH/2 - h/2

    -- Dark overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Journal window
    love.graphics.setColor(0.1, 0.1, 0.15)
    love.graphics.rectangle("fill", x, y, w, h, 10, 10)
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x, y, w, h, 10, 10)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(0.9, 0.8, 0.6)
    love.graphics.setFont(getFont(18))
    love.graphics.print("📖 JOURNAL", x + 20, y + 15)

    -- Close button
    love.graphics.setColor(0.8, 0.3, 0.3)
    love.graphics.rectangle("fill", x + w - 35, y + 10, 25, 25, 4, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(16))
    love.graphics.printf("X", x + w - 35, y + 12, 25, "center")

    -- Tabs
    drawJournalTabs(x, y + 50, w)

    -- Content area
    drawJournalContent(x + 20, y + 100, w - 40, h - 120)
end
```

### Tab Buttons
```lua
local JOURNAL_TABS = {
    {id = "events", name = "Events", icon = "📜"},
    {id = "quests", name = "Quests", icon = "📋"},
    {id = "actions", name = "Actions", icon = "📊"},
    {id = "factions", name = "Factions", icon = "🏛️"},
    {id = "party", name = "Party", icon = "👥"},
    {id = "stats", name = "Stats", icon = "📈"},
    {id = "status", name = "Status", icon = "🩺"},
}

local function drawJournalTabs(x, y, w)
    local tabW = 95
    local tabH = 35
    local currentTab = state.player.journal.currentTab

    for i, tab in ipairs(JOURNAL_TABS) do
        local tabX = x + 10 + (i-1) * (tabW + 5)
        local tabY = y

        -- Wrap to second row after 4 tabs
        if i > 4 then
            tabX = x + 10 + (i-5) * (tabW + 5)
            tabY = y + tabH + 5
        end

        local isActive = currentTab == tab.id

        -- Tab background
        if isActive then
            love.graphics.setColor(0.3, 0.3, 0.4)
        else
            love.graphics.setColor(0.15, 0.15, 0.2)
        end
        love.graphics.rectangle("fill", tabX, tabY, tabW, tabH, 5, 5)

        -- Tab border
        if isActive then
            love.graphics.setColor(0.6, 0.6, 0.7)
            love.graphics.setLineWidth(2)
        else
            love.graphics.setColor(0.3, 0.3, 0.35)
            love.graphics.setLineWidth(1)
        end
        love.graphics.rectangle("line", tabX, tabY, tabW, tabH, 5, 5)
        love.graphics.setLineWidth(1)

        -- Tab text
        love.graphics.setColor(isActive and {1, 1, 1} or {0.6, 0.6, 0.6})
        love.graphics.setFont(getFont(10))
        love.graphics.printf(tab.icon .. " " .. tab.name, tabX, tabY + 10, tabW, "center")

        -- Store bounds for clicking
        state.journalTabBounds = state.journalTabBounds or {}
        state.journalTabBounds[tab.id] = {x = tabX, y = tabY, w = tabW, h = tabH}
    end
end
```

---

## 6. Integration Points

### Hook into Existing Systems

**Combat Victory**:
```lua
-- In endCombat() function
addJournalEvent("combat", "Defeated " .. enemy.name, {0.9, 0.3, 0.3})
state.player.journal.actionStats.combat.enemiesDefeated =
    state.player.journal.actionStats.combat.enemiesDefeated + 1
```

**Quest Completion**:
```lua
-- In quest complete function
addJournalEvent("quest", "Completed: " .. quest.name, {0.9, 0.7, 0.2})
state.player.journal.actionStats.social.questsCompleted =
    state.player.journal.actionStats.social.questsCompleted + 1
```

**Crime Committed**:
```lua
-- In commitCrime() function
addJournalEvent("crime", "Committed: " .. crime.name, {0.9, 0.4, 0.2})
state.player.journal.actionStats.crimes.crimesCommitted =
    state.player.journal.actionStats.crimes.crimesCommitted + 1
```

**Level Up**:
```lua
-- In gainXP() function
addJournalEvent("levelup", "Reached Level " .. newLevel .. "!", {1, 0.9, 0.3})
```

---

## 7. Performance Considerations

### Optimization Strategies
1. **Event Log Cap**: Max 200 events to prevent memory bloat
2. **Lazy Rendering**: Only render active tab content
3. **Cached Calculations**: Cache faction rep displays
4. **Efficient Scrolling**: Viewport culling for long lists
5. **Deferred Updates**: Update stats on journal open, not every frame

### Memory Management
```lua
-- Prune old events
local function pruneEventLog()
    if #state.player.journal.eventLog > 200 then
        -- Keep only last 200 events
        local newLog = {}
        for i = #state.player.journal.eventLog - 199, #state.player.journal.eventLog do
            table.insert(newLog, state.player.journal.eventLog[i])
        end
        state.player.journal.eventLog = newLog
    end
end
```

---

## 8. Save/Load Integration

### Migration for Old Saves
```lua
-- In load() function
if state.player and not state.player.journal then
    state.player.journal = {
        isOpen = false,
        currentTab = "events",
        eventLog = {},
        actionStats = {
            combat = {enemiesDefeated = 0, defeatedByType = {}, damageDealt = 0, deaths = 0, perfectCombats = 0},
            crimes = {crimesCommitted = 0, crimesByType = {}, timesArrested = 0, bountyPaid = 0, stealthSuccesses = 0, stealthFailures = 0},
            exploration = {tilesExplored = 0, townsDiscovered = 0, dungeonsCleared = 0, distanceTraveled = 0},
            economy = {goldEarned = 0, goldSpent = 0, itemsCrafted = 0, itemsSold = 0},
            social = {npcsTalkedTo = 0, questsCompleted = 0, partyMembers = 0, vampiresCreated = 0},
        },
        scrollOffset = 0,
    }
end
```

---

## 9. Keyboard Shortcuts

### Optional Hotkeys
- `J` - Toggle journal (if not used elsewhere)
- `Tab` - Cycle through tabs when journal open
- `Escape` - Close journal
- `Up/Down` - Scroll content
- `Page Up/Down` - Fast scroll

---

## 10. Implementation Checklist

### Phase 1: Toggle & Basic UI (30 min)
- [ ] Add journal toggle button (below stealth)
- [ ] Create journal window overlay
- [ ] Implement close button
- [ ] Add tab bar
- [ ] Store toggle state in player data

### Phase 2: Event Log Tab (30 min)
- [ ] Create event log data structure
- [ ] Implement addJournalEvent function
- [ ] Render event log with colors
- [ ] Add scrolling
- [ ] Hook into existing systems

### Phase 3: Quests Tab (20 min)
- [ ] Display active quests
- [ ] Show completed quests
- [ ] Format quest details
- [ ] Add progress bars

### Phase 4: Actions Tab (30 min)
- [ ] Create actionStats structure
- [ ] Track combat stats
- [ ] Track crime stats
- [ ] Track exploration stats
- [ ] Track economy stats
- [ ] Display formatted statistics

### Phase 5: Factions Tab (20 min)
- [ ] Display all factions
- [ ] Show reputation bars
- [ ] List benefits
- [ ] Show requirements

### Phase 6: Party Tab (20 min)
- [ ] Display party members
- [ ] Show health/mana bars
- [ ] List equipment
- [ ] Show status effects

### Phase 7: Stats Tab (20 min)
- [ ] Display primary stats
- [ ] Display combat stats
- [ ] List skills and talents
- [ ] Show active bonuses

### Phase 8: Status Tab (20 min)
- [ ] Show vampire status
- [ ] Display diseases/poisons
- [ ] List buffs/debuffs
- [ ] Show overall condition

### Phase 9: Integration (30 min)
- [ ] Hook into combat system
- [ ] Hook into quest system
- [ ] Hook into crime system
- [ ] Hook into faction system
- [ ] Hook into level up

### Phase 10: Polish (20 min)
- [ ] Add scrolling
- [ ] Add animations
- [ ] Test all tabs
- [ ] Save/load migration

---

## READY FOR IMPLEMENTATION

All journal mechanics are designed and ready to be coded into textrpg.lua.
