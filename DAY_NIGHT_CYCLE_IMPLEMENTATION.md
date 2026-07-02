# Day/Night Cycle & NPC Routine System - Complete Implementation

## ✅ COMPLETED (Already Added to Code)

### 1. Race System with Sleep Schedules
Added comprehensive race definitions with sleep mechanics:

**Living Races (CAN SLEEP):**
- **Human**: Sleep 22:00-06:00 (8 hours)
- **Dwarf**: Sleep 23:00-07:00 (8 hours)
- **Orc**: Sleep 21:00-05:00 (8 hours)
- **Gnome**: Sleep 22:00-06:00 (8 hours)
- **Elf**: Sleep 01:00-05:00 (4 hours - half the time!)

**Undead Races (NEVER SLEEP):**
- **Vampire**: No sleep, active at night
- **Zombie**: No sleep
- **Werewolf**: No sleep, active at night
- **Lich**: No sleep
- **Skeleton**: No sleep
- **Ghoul**: No sleep, active at night

### 2. Core Functions Implemented
- `isNPCAsleep(npc)` - Check if NPC is sleeping based on race and time
- `getNPCSchedule(profession, race)` - Generate hourly schedule for NPC
- `getNPCCurrentLocation(npc)` - Get where NPC is right now
- `updateNPCStates()` - Update all NPCs based on time of day
- `getTimeOfDayPeriod()` - Get period (dawn, morning, afternoon, evening, dusk, night)
- `getTimeOfDayLighting()` - Get lighting colors for rendering
- `getTimeIcon()` - Get emoji icon for current time

### 3. NPC Daily Schedules

**Default Schedule for Living Races:**
```
00:00-05:00: Sleeping (home)
05:00-06:00: Waking up (home)  [Elves wake here]
06:00-08:00: Morning routine (home/wandering)
08:00-12:00: Working (work location)
12:00-13:00: Lunch break (tavern)
13:00-18:00: Working (work location)
18:00-20:00: Dinner/socializing (tavern)
20:00-22:00: Relaxing (home)
22:00-24:00: Sleeping (home)
```

**Undead Schedule:**
```
00:00-06:00: Active/patrolling (night creatures)
06:00-18:00: Resting/avoiding daylight (home)
18:00-24:00: Active/patrolling
```

---

## 🔧 STILL NEEDS IMPLEMENTATION

### 1. Update NPC Professions (Line ~1153)

**Find NPC_PROFESSIONS and add race info + sleep greetings:**

```lua
local NPC_PROFESSIONS = {
    {id = "blacksmith", title = "Blacksmith", icon = "[B]", color = {0.7, 0.4, 0.2},
        greetings = {"Need some steel work?", "My forge is always hot!", "Best weapons in the land!"},
        sleepGreetings = {"*yawns* Come back tomorrow...", "*snores*", "Zzz..."},
        quests = true, questTypes = {"fetch", "deliver"},
        possibleRaces = {"dwarf", "human", "orc"}},  -- ADD THIS

    {id = "innkeeper", title = "Innkeeper", icon = "[I]", color = {0.6, 0.5, 0.3},
        greetings = {"Welcome, weary traveler!", "The ale's fresh today!", "Need a room?"},
        sleepGreetings = {"*asleep in a chair*", "The inn is closed...", "*snoring loudly*"},
        quests = true, questTypes = {"kill", "talk"},
        possibleRaces = {"human", "gnome", "dwarf"}},

    {id = "merchant", title = "Merchant", icon = "[M]", color = {0.8, 0.7, 0.2},
        greetings = {"Looking to trade?", "I have rare goods!", "Everything has a price..."},
        sleepGreetings = {"Shop's closed!", "*asleep at the counter*", "Come back in the morning!"},
        quests = true, questTypes = {"fetch", "deliver"},
        possibleRaces = {"human", "elf", "gnome"}},

    {id = "healer", title = "Healer", icon = "[H]", color = {0.3, 0.8, 0.4},
        greetings = {"Blessings upon you.", "Let me tend your wounds.", "Health is true wealth."},
        sleepGreetings = {"*meditating*", "The temple is quiet now...", "*resting*"},
        quests = true, questTypes = {"fetch", "kill"},
        possibleRaces = {"human", "elf"}},

    {id = "guard", title = "Guard", icon = "[G]", color = {0.5, 0.5, 0.6},
        greetings = {"Keep the peace.", "No trouble, adventurer.", "Stay vigilant."},
        sleepGreetings = {"Off duty.", "*yawns* Night shift soon...", "Guard post is closed."},
        quests = true, questTypes = {"kill", "talk"},
        possibleRaces = {"human", "orc", "dwarf"}},

    {id = "farmer", title = "Farmer", icon = "[F]", color = {0.4, 0.6, 0.3},
        greetings = {"Hard day's work ahead.", "The crops need tending.", "Simple life, honest work."},
        sleepGreetings = {"*sleeping soundly*", "Up at dawn...", "Too tired to talk..."},
        quests = true, questTypes = {"kill", "fetch"},
        possibleRaces = {"human", "gnome"}},

    {id = "miner", title = "Miner", icon = "[N]", color = {0.5, 0.4, 0.4},
        greetings = {"The mines run deep.", "Found some ore today.", "Watch out for cave-ins."},
        sleepGreetings = {"*exhausted from mining*", "Back to work tomorrow...", "*snoring*"},
        quests = true, questTypes = {"fetch", "kill"},
        possibleRaces = {"dwarf", "human"}},

    {id = "scholar", title = "Scholar", icon = "[S]", color = {0.4, 0.4, 0.7},
        greetings = {"Knowledge is power.", "I've been researching...", "Fascinating discoveries await!"},
        sleepGreetings = {"*reading late into the night*", "The library is closed...", "*dozing off*"},
        quests = true, questTypes = {"fetch", "talk"},
        possibleRaces = {"elf", "human", "gnome"}},

    {id = "hunter", title = "Hunter", icon = "[U]", color = {0.5, 0.6, 0.4},
        greetings = {"The wild calls.", "Tracked a beast today.", "Nature provides."},
        sleepGreetings = {"*resting from the hunt*", "Tomorrow's another hunt...", "*sleeping lightly*"},
        quests = true, questTypes = {"kill", "fetch"},
        possibleRaces = {"human", "elf", "orc"}},

    {id = "elder", title = "Elder", icon = "[E]", color = {0.7, 0.6, 0.5},
        greetings = {"Ah, an adventurer!", "The old ways guide us.", "I have much wisdom to share."},
        sleepGreetings = {"*dozing peacefully*", "Even elders need rest...", "*napping*"},
        quests = true, questTypes = {"kill", "talk", "fetch", "deliver"}, isElder = true,
        possibleRaces = {"human", "elf"}},
}
```

---

### 2. Assign Race on NPC Generation (Line ~3900)

**Find where NPCs are created in generateMap() or town generation:**

```lua
-- Find existing NPC creation code and ADD:
for _, npc in ipairs(town.npcs) do
    -- Assign race based on profession
    if npc.profession.possibleRaces then
        npc.race = npc.profession.possibleRaces[math.random(#npc.profession.possibleRaces)]
    else
        -- Default fallback
        npc.race = "human"
    end

    -- Initialize schedule
    npc.schedule = getNPCSchedule(npc.profession.id, npc.race)
    npc.currentLocation = "work"
    npc.currentActivity = "working"
    npc.isAsleep = false
end
```

---

### 3. Call updateNPCStates() in Update Loop (Line ~6400)

**Find `function TextRPG.update(dt)` and add after time advancement:**

```lua
function TextRPG.update(dt)
    -- ... existing update code ...

    -- Update day/night cycle (1 game hour = 30 seconds real time)
    state.timeOfDay = state.timeOfDay + (dt / 30) * 1
    if state.timeOfDay >= 24 then
        state.timeOfDay = state.timeOfDay - 24
        state.daysPassed = state.daysPassed + 1

        -- Handle daily world events (lich blight spreading, etc.)
        onNewDay(state.daysPassed)

        -- ... existing daily events ...
    end

    -- *** ADD THIS: Update NPC states based on time of day ***
    updateNPCStates()

    -- ... rest of update function ...
end
```

---

### 4. Modify Dialogue to Check for Sleep (Line ~13833)

**In the dialogue handler where NPC dialogue is started:**

```lua
-- Find where state.dialogue.text is set, and modify:
elseif state.phase == "npc_list" then
    local town = state.world.currentTown
    local npcY = contentY + 50

    for i, npc in ipairs(town.npcs) do
        local ny = npcY + (i - 1) * 55

        if mx >= contentX + 20 and mx <= contentX + contentW - 20 and my >= ny and my <= ny + 50 then
            -- Generate quest if needed
            if npc.hasQuest and not npc.quest then
                npc.quest = generateQuest(npc.name, npc.profession, state.player.level)
            end

            state.dialogue.npc = npc

            -- *** ADD SLEEP CHECK ***
            if isNPCAsleep(npc) then
                -- NPC is asleep - show sleep greeting
                local sleepGreetings = npc.profession.sleepGreetings or {"*sleeping*", "Zzz...", "*snoring*"}
                state.dialogue.text = sleepGreetings[math.random(#sleepGreetings)]

                -- Limited options when asleep
                state.dialogue.options = {
                    {text = "Let them sleep", action = "leave"},
                    {text = "[⚔️ Attack]", action = "attack_civilian", color = {0.9, 0.2, 0.2}},
                }
            else
                -- NPC is awake - normal dialogue
                state.dialogue.text = npc.profession.greetings[math.random(#npc.profession.greetings)]
                state.dialogue.options = buildDialogueOptions(npc)
            end

            state.phase = "dialogue"
            return
        end
    end
```

---

### 5. Update Lockpicking to Use Sleep System (Line ~8704)

**In `drawLockpickPrompt()` function, replace occupant check:**

```lua
function drawLockpickPrompt(x, y, w, h, mx, my)
    local building = state.lockpickTarget or {name = "Unknown", id = "home1"}
    local difficulty = LOCKPICK_CONFIG.difficulties[building.id] or LOCKPICK_CONFIG.defaultDifficulty

    -- *** REPLACE occupant generation with race-based sleep check ***
    if not state.lockpickOccupant then
        local hour = state.timeOfDay or 12
        local occupantChance = 0.6  -- 60% chance someone lives here

        if math.random() < occupantChance then
            -- Generate occupant with race
            local races = {"human", "dwarf", "elf", "gnome", "orc"}
            local occupantRace = races[math.random(#races)]

            state.lockpickOccupant = {
                name = "Home Owner",
                race = occupantRace,
                level = math.random(1, 3),
                hp = 25,
                maxHP = 25,
                attack = 6,
                defense = 3,
            }

            -- Check if they're asleep using race system
            state.lockpickOccupant.isAsleep = isNPCAsleep(state.lockpickOccupant)
        end
    end

    -- ... rest of function uses state.lockpickOccupant.isAsleep ...
```

---

### 6. Display Time of Day in UI (Line ~7000)

**Find where game state UI is drawn and add time display:**

```lua
-- In drawTown() or main UI drawing function, add:
local function drawTimeOfDay(x, y)
    local hour = math.floor(state.timeOfDay or 12)
    local minute = math.floor((state.timeOfDay % 1) * 60)
    local timeStr = string.format("%02d:%02d", hour, minute)

    local icon = getTimeIcon()
    local period = getTimeOfDayPeriod()
    local lighting = getTimeOfDayLighting()

    -- Background
    love.graphics.setColor(0.1, 0.1, 0.15, 0.8)
    love.graphics.rectangle("fill", x, y, 150, 45, 5, 5)

    -- Icon
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(20))
    love.graphics.print(icon, x + 10, y + 12)

    -- Time
    love.graphics.setColor(lighting.r, lighting.g, lighting.b)
    love.graphics.setFont(getFont(16))
    love.graphics.print(timeStr, x + 45, y + 8)

    -- Period name
    love.graphics.setFont(getFont(10))
    love.graphics.print(period:upper(), x + 45, y + 28)

    -- Day counter
    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.setFont(getFont(9))
    love.graphics.printf("Day " .. (state.daysPassed + 1), x, y + 30, 150, "right")
end

-- Call this in your main draw function:
drawTimeOfDay(screenW - 170, 20)  -- Top right corner
```

---

### 7. Apply Lighting to World Rendering

**In town/map rendering code, apply time-based tint:**

```lua
-- In drawTown() or wherever the world is rendered:
local function applyTimeOfDayLighting()
    local lighting = getTimeOfDayLighting()
    love.graphics.setColor(lighting.r * lighting.brightness,
                           lighting.g * lighting.brightness,
                           lighting.b * lighting.brightness)
end

-- Before drawing map/town tiles:
applyTimeOfDayLighting()
-- ... draw tiles ...
love.graphics.setColor(1, 1, 1)  -- Reset
```

---

### 8. Show NPC Status in NPC List (Line ~11670)

**In `drawNPCList()` function, show if NPC is asleep:**

```lua
-- In the NPC listing loop, add status indicator:
for i, npc in ipairs(town.npcs) do
    -- ... existing drawing code ...

    -- *** ADD: Show current state ***
    local indicatorX = x + w - 200
    if npc.isAsleep then
        love.graphics.setColor(0.5, 0.5, 0.7)
        love.graphics.setFont(getFont(11))
        love.graphics.print("💤 Sleeping", indicatorX, ny + 8)
    elseif npc.currentActivity then
        love.graphics.setColor(0.6, 0.7, 0.8)
        love.graphics.setFont(getFont(10))
        love.graphics.print(npc.currentActivity, indicatorX, ny + 8)
    end

    -- Show race
    if npc.race then
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.setFont(getFont(9))
        love.graphics.print(RACES[npc.race].name, x + 80, ny + 42)
    end

    -- ... rest of NPC card drawing ...
end
```

---

## 🎮 GAMEPLAY FEATURES

### How It Works:

1. **Time Advances**: 1 game hour = 30 seconds real time
2. **NPCs Follow Schedules**: Based on profession and race
3. **Sleep Varies by Race**:
   - Humans/Dwarves/Orcs/Gnomes: Sleep 8 hours
   - Elves: Sleep 4 hours (nocturnal tendency)
   - Undead: NEVER sleep
4. **NPC Locations Change**: Work → Tavern → Home throughout day
5. **Dialogue Changes**: Sleep greetings when asleep
6. **Lockpicking**: Sleeping occupants can be assassinated
7. **Lighting Changes**: Dawn = orange, Day = bright, Night = blue tint
8. **Visual Feedback**: Time icon changes (☀️ → 🌆 → 🌙)

### Testing Checklist:

- [ ] Time advances continuously (watch clock)
- [ ] Day transitions at 24:00 to next day
- [ ] NPCs show as sleeping at night
- [ ] Can't talk to sleeping NPCs (limited options)
- [ ] Elves sleep 1 AM - 5 AM (4 hours)
- [ ] Undead NPCs never sleep
- [ ] Lockpicking finds sleeping occupants at night
- [ ] Lighting tint changes throughout day
- [ ] NPC list shows sleep status
- [ ] Time icon changes (sun/moon/etc)

---

## 📊 NPC SCHEDULE EXAMPLES

### Human Blacksmith (Sleeps 22:00-06:00)
```
00:00 - Sleeping at home
06:00 - Wakes up, morning routine
08:00 - Opens forge, starts work
12:00 - Lunch at tavern
13:00 - Back to forge
18:00 - Dinner at tavern
20:00 - Home, relaxing
22:00 - Sleeps
```

### Elf Scholar (Sleeps 01:00-05:00 - 4 hours!)
```
00:00 - Reading/researching (still awake!)
01:00 - Trance/meditation
05:00 - Awake again
08:00 - Teaching at library
12:00 - Lunch
13:00 - Research
18:00 - Evening studies
20:00 - Library work
23:00 - Late night reading
```

### Vampire Merchant (NEVER SLEEPS)
```
00:00 - Patrolling/wandering
06:00 - Avoiding daylight, resting
12:00 - Resting
18:00 - Emerges at dusk
20:00 - Opens shop
24:00 - Active all night
```

---

## 🚀 OPTIONAL ENHANCEMENTS (Future)

1. **NPC Movement**: NPCs physically walk to different locations
2. **Business Hours**: Shops closed when owner is sleeping/away
3. **Special Events**: Festivals at specific times
4. **Curfew System**: Guards patrol more at night
5. **Werewolf Transformation**: Werewolf NPCs transform at night
6. **Vampire Weaknesses**: Vampires take damage in daylight
7. **Time-Based Quests**: "Meet me at midnight" quests
8. **Dream System**: Player dreams when sleeping
9. **Seasonal Time Changes**: Longer days in summer
10. **Work Schedules**: Different schedules for different professions
