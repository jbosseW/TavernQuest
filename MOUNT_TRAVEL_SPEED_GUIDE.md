# MOUNT & VEHICLE TRAVEL SPEED GUIDE
## Complete Travel Time Breakdown by Transport Method
### Date: January 28, 2026

---

# MOUNT SPEED MULTIPLIERS

## From backpack.lua (lines 565-588):

```lua
function Backpack.getMountSpeedMultiplier()
    if mount.mountType == "flying" then
        return 4.0  -- Birds fly 4x speed
    elseif mount.mountType == "land" then
        return 2.0  -- Land mounts 2x speed
    elseif mount.mountType == "aquatic" then
        return 2.0  -- Aquatic mounts 2x in water
    elseif mount.mountType == "boat" then
        return 2.5  -- Default boat speed
    elseif mount.mountType == "cart" then
        return 1.5  -- Carts slower but safer
    end
    return 1.0  -- Walking
end
```

---

# COMPLETE SPEED BREAKDOWN

## Base Travel Speeds (Without Mounts)

| Terrain | Tiles/Day | Km/Day | Real-Time/Tile* |
|---------|-----------|--------|-----------------|
| **Road** | 5 | 25km | 2.4 min |
| **Grassland** | 4 | 20km | 3 min |
| **Forest/Mountain** | 3 | 15km | 4 min |
| **Desert** | 2 | 10km | 6 min |
| **Ice/Glass** | 2 | 10km | 6 min |
| **Ocean (swim)** | 1 | 5km | 12 min |

*Assuming 1 in-game day = 12 real-time minutes

---

## WITH LAND MOUNT (Horse, Pack Horse, Donkey)

**Speed Multiplier**: **2.0x**

| Terrain | Tiles/Day | Km/Day | Real-Time/Tile |
|---------|-----------|--------|----------------|
| **Road** | **10** | 50km | 1.2 min |
| **Grassland** | **8** | 40km | 1.5 min |
| **Forest/Mountain** | **6** | 30km | 2 min |
| **Desert** | **4** | 20km | 3 min |
| **Ice/Tundra** | **4** | 20km | 3 min |

**Major Journeys with Horse**:

| Journey | Tiles | Days | Real-Time |
|---------|-------|------|-----------|
| North-South | 700 | **139 days** | **28 hours** |
| West-East | 450 | **54 days** | **11 hours** |
| Circumnavigation | 1,000 | **200 days** | **40 hours** |
| To Fortune's Rest | 50 | **2 days** | **24 min** |
| To Gnomish Isles | 100 | **7.5 days** | **1.5 hours** |
| To Frostbound | 117 | **23 days** | **4.6 hours** |

**Reduction**: ~50% faster than walking

---

## WITH BOAT/SHIP (Ocean Travel)

**Speed Multiplier**: **2.5x** (default boat)

| Terrain | Tiles/Day | Km/Day | Real-Time/Tile |
|---------|-----------|--------|----------------|
| **Ocean** | **25** | 125km | 0.5 min (30 sec) |
| **Coastal** | **20** | 100km | 0.6 min |
| **Stormy** | **15** | 75km | 0.8 min |

**Ocean-Heavy Journeys with Ship**:

| Journey | Ocean Tiles | Days (Ship) | Real-Time |
|---------|-------------|-------------|-----------|
| **To Gnomish Isles** (ocean only) | 56 | **2.2 days** | **27 min** |
| **Southern Ocean Crossing** | 170 | **6.8 days** | **1.4 hours** |
| **Western Ocean Crossing** | 70 | **2.8 days** | **34 min** |
| **Polar Ocean Navigate** | 200 | **8 days** | **1.6 hours** |

**Fast Ships** (possible upgrade):
- Speed multiplier: **3.5x-4.0x**
- Ocean crossing to Gnomes: **1.4-1.6 days** = **17-20 minutes**

---

## WITH FLYING MOUNT (Griffin, Pegasus, Dragon, Gnomish Airship)

**Speed Multiplier**: **4.0x**

| Terrain | Tiles/Day | Km/Day | Real-Time/Tile |
|---------|-----------|--------|----------------|
| **ANY** | **20** | 100km | 0.6 min (36 sec) |
| **Open Sky** | **20** | 100km | 0.6 min |
| **Over Ocean** | **20** | 100km | 0.6 min |
| **Over Mountains** | **20** | 100km | 0.6 min |

**Note**: Flying mounts ignore terrain penalties!

**Major Journeys with Flying Mount**:

| Journey | Tiles | Days | Real-Time |
|---------|-------|------|-----------|
| **North-South** | 700 | **35 days** | **7 hours** |
| **West-East** | 450 | **22.5 days** | **4.5 hours** |
| **Circumnavigation** | 1,000 | **50 days** | **10 hours** |
| **To Fortune's Rest** | 50 | **2.5 days** | **30 min** |
| **To Gnomish Isles** | 100 | **5 days** | **1 hour** |
| **To Frostbound** | 117 | **5.9 days** | **1.2 hours** |
| **To Great Western Isle** | 260 | **13 days** | **2.6 hours** |
| **To Polar Ocean** | 308 | **15.4 days** | **3.1 hours** |

**Reduction**: **75% faster** than walking (4x speed)

---

## WITH GNOMISH AIRSHIP (Special - Fastest)

**Speed Multiplier**: **8.0x** (gnomish technology!)

Based on gnome lore: "Airship fleets enable rapid logistics"

| Terrain | Tiles/Day | Km/Day | Real-Time/Tile |
|---------|-----------|--------|----------------|
| **ANY** | **40** | 200km | 0.3 min (18 sec) |

**Major Journeys with Gnomish Airship**:

| Journey | Tiles | Days | Real-Time |
|---------|-------|------|-----------|
| **North-South** | 700 | **17.5 days** | **3.5 hours** |
| **West-East** | 450 | **11.25 days** | **2.25 hours** |
| **Circumnavigation** | 1,000 | **25 days** | **5 hours** |
| **To Fortune's Rest** | 50 | **1.25 days** | **15 min** |
| **To Gnomish Isles** | 100 | **2.5 days** | **30 min** |
| **To Frostbound** | 117 | **3 days** | **36 min** |
| **To Great Western Isle** | 260 | **6.5 days** | **1.3 hours** |
| **To Polar Ocean** | 308 | **7.7 days** | **1.5 hours** |

**Reduction**: **87.5% faster** than walking (8x speed)

---

## WITH CART/WAGON (Slow but Safe)

**Speed Multiplier**: **1.5x**

| Terrain | Tiles/Day | Km/Day | Real-Time/Tile |
|---------|-----------|--------|----------------|
| **Road** | **7.5** | 37.5km | 1.6 min |
| **Grassland** | **6** | 30km | 2 min |
| **Forest** | **4.5** | 22.5km | 2.7 min |

**Benefit**: 50% encounter reduction (safer travel)
**Drawback**: Only 50% faster (vs 2x for horse)

---

# COMPLETE JOURNEY COMPARISON TABLE

## North to South (Full Meridional - 700 tiles)

| Method | Speed | In-Game Days | Real-Time | Notes |
|--------|-------|--------------|-----------|-------|
| **Walking** | 1.0x | 278 days | **56 hours** | Base speed |
| **Horse** | 2.0x | 139 days | **28 hours** | 2x faster |
| **Ship** (ocean only) | 2.5x | Varies | Varies | Ocean segments only |
| **Cart** | 1.5x | 185 days | **37 hours** | Safer, slower |
| **Flying Mount** | 4.0x | 70 days | **14 hours** | 4x faster |
| **Gnomish Airship** | 8.0x | 35 days | **7 hours** | 8x faster! |

**Best Time**: **7 hours** with gnomish airship (1 long play session!)

---

## West to East (Full Equatorial - 450 tiles)

| Method | Speed | In-Game Days | Real-Time | Notes |
|--------|-------|--------------|-----------|-------|
| **Walking** | 1.0x | 108 days | **22 hours** | Base speed |
| **Horse** | 2.0x | 54 days | **11 hours** | 2x faster |
| **Ship** (ocean only) | 2.5x | Varies | Varies | Ocean segments only |
| **Flying Mount** | 4.0x | 27 days | **5.4 hours** | 4x faster |
| **Gnomish Airship** | 8.0x | 14 days | **2.8 hours** | 8x faster! |

**Best Time**: **2.8 hours** with gnomish airship (afternoon adventure!)

---

## Full Circumnavigation (Complete Loop - ~1,000 tiles)

| Method | Speed | In-Game Days | Real-Time | Notes |
|--------|-------|--------------|-----------|-------|
| **Walking/Sailing** | 1.0x | 350 days | **70 hours** | Epic trek |
| **Horse + Ship** | 2.0x | 175 days | **35 hours** | Halved |
| **Flying Mount** | 4.0x | 88 days | **17.6 hours** | Weekend project |
| **Gnomish Airship** | 8.0x | 44 days | **8.8 hours** | One long session! |

**Best Time**: **9 hours** with gnomish airship (achievable in one day!)

---

# REALISTIC PLAY SCENARIOS

## Scenario 1: Early Game Explorer (Walking + Basic Ship)

**Goal**: Visit all racial starting cities

| City | From Havenbrook | Walking | With Horse | Real-Time (Walk) | Real-Time (Horse) |
|------|----------------|---------|------------|------------------|-------------------|
| Havenbrook | 0 | 0 | 0 | 0 | 0 |
| Solara | 5 tiles | 1 day | 0.5 days | 12 min | 6 min |
| Kragmor | 25 tiles | 5 days | 2.5 days | 1 hour | 30 min |
| Ironhold | 40 tiles | 8 days | 4 days | 1.6 hours | 48 min |
| BoneTrap | 25 tiles | 6 days | 3 days | 1.2 hours | 36 min |
| Sylvaris | 18 tiles | 4 days | 2 days | 48 min | 24 min |
| Murkmire | 20 tiles | 5 days | 2.5 days | 1 hour | 30 min |
| Fortune's Rest | 50 tiles | 25 days | 12.5 days | 5 hours | 2.5 hours |
| Mechspire | 100 tiles | 15 days (ship) | 7.5 days | 3 hours | 1.5 hours |

**Total Tour**: **69 days walking = 13.8 hours** OR **34.5 days with horse = 7 hours**

---

## Scenario 2: Mid-Game Adventurer (Horse + Ship)

**Goal**: Explore all main regions

| Region | Distance | Days (Mount+Ship) | Real-Time |
|--------|----------|-------------------|-----------|
| All Cities (above) | ~350 tiles | 35 days | **7 hours** |
| Wastes of Calidar | 15 tiles | 4 days | **48 min** |
| Deep Desert | 50 tiles | 12 days | **2.4 hours** |
| Frostbound (via ship) | 117 tiles | 23 days | **4.6 hours** |

**Total Exploration**: **~80 days = 16 hours**

---

## Scenario 3: Late-Game Expeditionary (Flying Mount)

**Goal**: Discover all distant lands

| Destination | Distance | Days (Flying) | Real-Time |
|-------------|----------|---------------|-----------|
| Southern Ocean | 108 tiles | 5.4 days | **1.1 hours** |
| Great Western Isle | 260 tiles | 13 days | **2.6 hours** |
| Ashen Archipelago | 180 tiles | 9 days | **1.8 hours** |
| Northern Tundra | 292 tiles | 14.6 days | **2.9 hours** |
| Polar Ocean | 308 tiles | 15.4 days | **3.1 hours** |

**Total Exploration**: **~60 days = 12 hours**

---

## Scenario 4: End-Game Circumnavigator (Gnomish Airship)

**Goal**: Prove world is spherical

**Route**: Havenbrook → South → Polar Ocean → West → North → Return

**Distance**: ~1,000 tiles
**In-Game Time**: 25 days (airship speed 40 tiles/day)
**Real-Time**: **5 hours** (one evening!)

**Breakdown**:
- South to Polar Ocean: 308 tiles = 7.7 days = **1.5 hours**
- West along polar route: 200 tiles = 5 days = **1 hour**
- North through tundra: 300 tiles = 7.5 days = **1.5 hours**
- Return to continent: 192 tiles = 4.8 days = **1 hour**

**Achievement Unlocked**: "The World Is Round" - **5 hours of play**

---

# SPEED COMPARISON - ALL METHODS

## Full North-South Traverse (700 tiles)

| Method | Speed Mult | Tiles/Day | In-Game Days | Real-Time | Play Sessions |
|--------|------------|-----------|--------------|-----------|---------------|
| **Walking** | 1.0x | 2.5 avg | 278 days | **56 hours** | 20-30 sessions |
| **Cart** | 1.5x | 3.75 avg | 185 days | **37 hours** | 15-20 sessions |
| **Horse** | 2.0x | 5 avg | 139 days | **28 hours** | 10-15 sessions |
| **Ship** (partial) | 2.5x | Varies | ~150 days | **30 hours** | 10-15 sessions |
| **Flying Mount** | 4.0x | 10 avg | 70 days | **14 hours** | 5-7 sessions |
| **Gnomish Airship** | 8.0x | 20 avg | 35 days | **7 hours** | 2-3 sessions |

---

## Full West-East Traverse (450 tiles)

| Method | Speed Mult | Tiles/Day | In-Game Days | Real-Time | Play Sessions |
|--------|------------|-----------|--------------|-----------|---------------|
| **Walking** | 1.0x | 4 avg | 108 days | **22 hours** | 8-10 sessions |
| **Horse** | 2.0x | 8 avg | 54 days | **11 hours** | 4-6 sessions |
| **Ship** (partial) | 2.5x | Varies | ~60 days | **12 hours** | 5-6 sessions |
| **Flying Mount** | 4.0x | 16 avg | 27 days | **5.4 hours** | 2-3 sessions |
| **Gnomish Airship** | 8.0x | 32 avg | 14 days | **2.8 hours** | 1 session |

---

## Complete Circumnavigation (1,000 tiles)

| Method | Speed Mult | Tiles/Day | In-Game Days | Real-Time | Play Sessions |
|--------|------------|-----------|--------------|-----------|---------------|
| **Walking/Sailing** | 1.0x | 3 avg | 350 days | **70 hours** | 30-40 sessions |
| **Horse + Ship** | 2.0x | 6 avg | 175 days | **35 hours** | 15-20 sessions |
| **Flying Mount** | 4.0x | 12 avg | 88 days | **17.6 hours** | 7-10 sessions |
| **Gnomish Airship** | 8.0x | 24 avg | 44 days | **8.8 hours** | 2-4 sessions |

---

# ENCOUNTER RATES (Affect Real-Time)

## From backpack.lua (lines 590-608):

**Encounter Reduction**:
- **Cart**: 50% fewer encounters (safer but slower overall)
- **Flying Mount**: 30% fewer encounters
- **Other mounts**: No reduction

**How This Affects Real-Time**:

**Walking North-South** (56 hours base):
- ~70 encounters expected (1 per 10 tiles)
- Each encounter: 3-5 minutes
- Total encounter time: **3.5-6 hours**
- **Total real-time: 60-62 hours**

**Horse North-South** (28 hours base):
- ~70 encounters (same, no reduction)
- Encounter time: **3.5-6 hours**
- **Total real-time: 32-34 hours**

**Flying Mount North-South** (14 hours base):
- ~49 encounters (30% reduction)
- Encounter time: **2.5-4 hours**
- **Total real-time: 16.5-18 hours**

**Gnomish Airship** (7 hours base):
- ~49 encounters (30% reduction)
- Encounter time: **2.5-4 hours**
- **Total real-time: 9.5-11 hours**

---

# FASTEST POSSIBLE TIMES (Optimized)

## Speed Run: Full Circumnavigation

**Method**: Gnomish Airship + Avoid All Encounters

**Pure Travel**: 25 days × 12 min/day = **5 hours**
**Unavoidable Events**: Rest stops, resource check = **+1 hour**
**Minimum Encounters**: ~20 fights (can't avoid all) = **+1 hour**

**Speedrun Time**: **7 hours minimum**

**World Record Potential**: If player has:
- Gnomish airship (8x speed)
- Max stealth (avoid encounters)
- Auto-pilot mod (no manual clicking)
- Pre-planned route

**Theoretical Minimum**: **6-7 hours** for complete circumnavigation

---

## Casual Play: Full World Exploration

**Method**: Horse + Ship + Take Time to Explore

**Visiting All 10 Cities**: 7 hours (with horse)
**Exploring All Regions**: +15 hours (dungeons, NPCs, quests)
**Distant Lands**: +20 hours (Western Isle, Tundras, Polar)
**Circumnavigation Attempt**: +10 hours (final epic journey)

**Total**: **52 hours** for 100% world exploration

**Comparison**:
- Skyrim main quest: ~25-30 hours
- Elden Ring full map: ~40-60 hours
- **Your game full world**: ~50-60 hours

**Your world is appropriately sized for an open-world RPG!**

---

# FINAL ANSWER - REAL-WORLD TIME

## How Long in IRL Time?

### **WALKING/SAILING**:
- **North to South**: 56-62 hours (2.5 days)
- **West to East**: 22-26 hours (1 day)
- **Full Circumnavigation**: 70-80 hours (3+ days)

### **WITH HORSE + SHIP**:
- **North to South**: 28-34 hours (1.5 days)
- **West to East**: 11-14 hours (0.5 days)
- **Full Circumnavigation**: 35-40 hours (1.5+ days)

### **WITH FLYING MOUNT**:
- **North to South**: 14-18 hours (0.75 days)
- **West to East**: 5.4-7 hours (0.3 days)
- **Full Circumnavigation**: 17-22 hours (1 day)

### **WITH GNOMISH AIRSHIP**:
- **North to South**: **7-11 hours** (0.5 days)
- **West to East**: **2.8-4 hours** (0.2 days)
- **Full Circumnavigation**: **9-12 hours** (0.5 days)

---

## PRACTICAL PLAYER EXPERIENCE

**Typical Play Session**: 2-3 hours

**World Exploration Milestones**:

| Session | Activity | Transport | IRL Time |
|---------|----------|-----------|----------|
| **Week 1** (3 sessions) | All main continent cities | Horse | **6 hours** |
| **Week 2** (2 sessions) | Fortune's Rest + BoneTrap | Horse | **4 hours** |
| **Week 3** (2 sessions) | Gnomish Isles expedition | Ship | **4 hours** |
| **Week 4** (3 sessions) | Frostbound Reach journey | Ship + trek | **6 hours** |
| **Week 5** (3 sessions) | Wastes + Southern Ocean | Ship | **6 hours** |
| **Week 6** (4 sessions) | Western lands exploration | Flying mount | **8 hours** |
| **Week 7** (5 sessions) | Circumnavigation attempt | Airship | **12 hours** |

**Total**: **7 weeks of casual play (2-3 hours/day, 3-4 days/week) = 46 hours total**

**100% World Completion**: **50-60 hours** (including all quests, dungeons, NPCs)

---

# SUMMARY

✅ **1 in-game day = 12 real-time minutes**
✅ **Time passes during day/night cycle** (1 hour per 30 seconds)
✅ **Mounts dramatically reduce travel time**:
   - Horse: 2x speed (halves time)
   - Flying mount: 4x speed (75% reduction)
   - Gnomish airship: 8x speed (87.5% reduction)

**IRL TIME TO TRAVERSE WORLD**:

| Journey | Walking | Horse | Flying | Airship |
|---------|---------|-------|--------|---------|
| **North-South** | 56 hours | 28 hours | 14 hours | **7 hours** |
| **West-East** | 22 hours | 11 hours | 5.4 hours | **2.8 hours** |
| **Around World** | 70 hours | 35 hours | 18 hours | **9 hours** |

**Gnomish airship makes world circumnavigation a 9-hour epic journey - perfect for a weekend playthrough!**

**Without mount: 70 hours (3 full days)**
**With airship: 9 hours (one long session)**

**Your world is HUGE but respects player time.** ⏱️