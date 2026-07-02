# NEW RACIAL CITIES ADDED
## BoneTrap (Goblin) & Fortune's Rest (Catfolk)
### Date: January 28, 2026

---

# EXECUTIVE SUMMARY

**Mission**: Add missing racial starting cities for goblins and catfolk
**Status**: ✅ **COMPLETE**

**Cities Added**:
1. ✅ **BoneTrap** - Goblin tribal warren village
2. ✅ **Fortune's Rest** - Catfolk desert oasis harbor

**Files Modified**:
- worldgen.lua (ANCHOR_TOWNS expanded)
- textrpg.lua (racial starting positions updated)

**Result**: All 8 playable races now have unique, lore-appropriate starting cities

---

# CITY #1: BONETRAP (GOBLIN TRIBAL VILLAGE)

## Lore Foundation

Based on GOBLIN_LORE.md:
- Goblins are decentralized resistance fighters
- Cell-based organization (5-20 goblins per cell)
- No central command, no capitals
- Scattered in mines, sewers, tunnels, ruins
- "Every goblin knows the names of lost homelands"
- Survive through cunning, memory, and persistence

**BoneTrap Concept**:
A rare semi-permanent goblin settlement—a tribal warren built into rocky crevices and abandoned ruins on the western borderlands. Not a capital (goblins don't have capitals), but a scrappy survivor community.

## Implementation Details

**Location**: worldgen.lua lines 437-454

```lua
{
    id = "bonetrap",
    name = "BoneTrap",
    region = "orcish_steppes",  -- Western borderlands
    position = {x = 10, y = 38},
    level = 4,
    type = "tribal_warren",
    population = 120,  -- Smallest settlement (tribal nature)
    isAnchor = true,
    fixedNPCs = {"boss_skrag", "tinkerer_grix", "shaman_zeek"},
    mainQuests = {"goblin_troubles", "warren_wars"},
    landmarks = {"scrap_heap", "boom_corner", "bosss_shack"},
    description = "A scrappy goblin warren built into rocky crevices and abandoned ruins. Paranoid survivors with no formal government—the 'boss' changes frequently through challenge and betrayal. Outsiders usually robbed, occasionally eaten.",
    culture = "Take what you can, trust no one. Goblins remember lost homelands and survive through cunning.",
    demographics = {goblin = 0.95, human = 0.03, orc = 0.02},  -- 95% goblin
    specialFeatures = {"black_market", "illegal_goods", "smuggling_hub"},
}
```

### Location Analysis

**Coordinates**: [10, 38]
- **Region**: Western edge of main continent (near Orcish Steppes border)
- **Strategic**: Hidden in rocky borderlands between civilization and wilderness
- **Accessible**: Still on main continent (not too remote)
- **Dangerous**: Level 4, population 120 (small, scrappy)

**Why This Location**:
- Near Orcish Steppes (goblins and orcs have history)
- Far from Holy Dominion center (imperial control weak here)
- Borderland location fits goblin "margins" lore
- Rocky terrain good for warrens and hiding
- Close to Shadowfen (could trade with commune)

### Cultural Details

**Government**: No formal government
- "Boss" changes frequently through challenge/betrayal
- Reflects goblin distrust of hierarchy
- Paranoid survivors (not organized civilization)

**Attitude to Outsiders**: "Usually robbed, occasionally eaten"
- Darkly humorous
- Shows goblin desperation and cynicism
- Fits "survival above all" philosophy

**Landmarks**:
- **Scrap Heap**: Where goblins salvage materials
- **Boom Corner**: Explosives/sabotage area (goblin tactics)
- **Boss's Shack**: Current leader's dwelling (crude)

**Demographics**: 95% goblin (isolated community)

**Special Features**:
- Black market (illegal goods)
- Smuggling hub (resistance network)
- Connections to goblin cells elsewhere

---

# CITY #2: FORTUNE'S REST (CATFOLK DESERT HARBOR)

## Lore Foundation

Based on BEAST_FOLK_LORE.md:
- Catfolk are diasporic people from desert origins
- Associated with gambling, fortune-telling, pattern recognition
- Gather in places built on chance
- "Pattern recognition refined over generations"
- 60% of beast folk live in Forbidden Deserts (origin lands)
- Significant populations in gambling cities

**Fortune's Rest Concept**:
A stunning desert oasis harbor where catfolk culture thrives—elegant gambling, fortune-telling, acrobatics, and desert trade. Where Havenbrook is rough vice, Fortune's Rest is refined art.

## Implementation Details

**Location**: worldgen.lua lines 456-476

```lua
{
    id = "fortunes_rest",
    name = "Fortune's Rest",
    region = "great_endless_desert",  -- IN THE DESERT (Y < 0)
    position = {x = 35, y = -8},  -- North of continent, desert territory
    level = 9,
    type = "desert_harbor",
    population = 300,
    isAnchor = true,
    fixedNPCs = {"matriarch_whisperwind", "casino_master_lucky", "harbormaster_sandclaw"},
    mainQuests = {"desert_mysteries", "nine_lives_pact"},
    landmarks = {"cats_eye_casino", "golden_docks", "arena_of_acrobats", "silk_bazaar"},
    description = "Where sands meet sea—a stunning desert oasis harbor built by catfolk traders. Sandstone architecture with billowing silk awnings. Unlike Havenbrook's rough vice, Fortune's Rest maintains an elegant atmosphere where gambling is art, not desperation.",
    culture = "Balance of luck and skill. Catfolk philosophy: chance reflects attention, timing, and respect for risk. Pattern recognition refined over generations.",
    demographics = {beast_folk = 0.70, human = 0.15, lizard_folk = 0.10, elf = 0.05},  -- 70% catfolk
    specialFeatures = {"luxury_gambling", "acrobat_performances", "desert_trade", "fortune_telling"},
    climate = "Desert oasis—hot days, cool nights, rare storms",
}
```

### Location Analysis

**Coordinates**: [35, -8]
- **Region**: Great Endless Desert (Y < 0 = infinite desert north)
- **Strategic**: "Where sands meet sea" (edge of desert, near coast)
- **Unique**: ONLY anchor city in the infinite desert region
- **Accessible**: 8 tiles north of continent edge (short journey)
- **Desert**: Clearly in desert territory (not just desert-themed)

**Why This Location**:
- Matches lore: "60% of beast folk in Forbidden Deserts"
- Desert oasis makes sense geographically
- Close enough to be playable (not 100 tiles into desert)
- Far enough to feel exotic and remote
- Harbor implies coast/water access (desert-sea trade route)

### Cultural Details

**Atmosphere**: "Elegant gambling as art, not desperation"
- Contrasts with Havenbrook (rough vice vs refined culture)
- Shows catfolk sophistication
- Gambling is cultural identity, not addiction

**Architecture**: "Sandstone with silk awnings"
- Visual: Tan/gold buildings, colorful fabrics
- Desert-appropriate materials
- Luxury aesthetic (silk = wealth)

**Landmarks**:
- **Cat's Eye Casino**: Main gambling hall (pattern recognition)
- **Golden Docks**: Harbor/trade (desert-sea connection)
- **Arena of Acrobats**: Catfolk agility performances
- **Silk Bazaar**: Luxury goods market

**Demographics**: 70% catfolk (majority but not exclusive)
- 15% humans (traders, gamblers)
- 10% lizard folk (desert neighbors)
- 5% elves (documenting everything)

**Special Features**:
- Luxury gambling (elegant, not seedy)
- Acrobat performances (catfolk agility)
- Desert trade (unique goods)
- Fortune-telling (catfolk specialty)

**Climate**: "Hot days, cool nights, rare storms"
- True desert conditions
- Oasis provides water
- Storms add danger/variety

---

# RACIAL SPAWNING - COMPLETE MATRIX

## All 8 Races Now Have Unique Cities

| Race | Starting City | Coordinates | Region | Population | Level | Theme |
|------|---------------|-------------|--------|------------|-------|-------|
| **Human** | Havenbrook | (35, 42) | Holy Dominion | 250 | 1 | Gambling |
| **Elf** | Sylvaris | (45, 55) | South Dominion | 350 | 8 | Administrative |
| **Dwarf** | Ironhold | (32, 8) | Mountains | 400 | 12 | Stronghold |
| **Orc** | Kragmor | (18, 25) | Steppes | 300 | 8 | Fortress |
| **Goblin** | BoneTrap | (10, 38) | West Borderlands | 120 | 4 | Tribal Warren |
| **Gnome** | Mechspire | (95, 38) | Gnomish Isles | 450 | 15 | Industrial |
| **Catfolk** | Fortune's Rest | (35, -8) | Desert | 300 | 9 | Oasis Harbor |
| **Lizardfolk** | Murkmire | (15, 52) | Shadowfen | 100 | 6 | Swamp Citadel |

## Geographic Distribution

**Main Continent** (Y = 0-64):
- Havenbrook (35, 42) - Center
- Sylvaris (45, 55) - South
- Ironhold (32, 8) - North mountains
- Kragmor (18, 25) - West steppes
- BoneTrap (10, 38) - West borderlands
- Murkmire (15, 52) - Southwest swamps

**Gnomish Isles** (X = 120-149):
- Mechspire (95, 38) - Industrial capital

**Great Endless Desert** (Y < 0):
- Fortune's Rest (35, -8) - **NEW! Only desert city**

**Map Visualization**:
```
              Y=-8: Fortune's Rest (Desert Oasis) 🏜️
                    ↓
    ═══════════════════════════════════════
    │              [DESERT]               │
    ═══════════════════════════════════════
    Y=0 ─────────────────────────────────── (Continent Edge)
    │                                     │
    │  Ironhold (32,8) ⛰️                │
    │     ↓                               │
    │  BoneTrap (10,38) 🏚️  Kragmor (18,25) ⛺│
    │                                     │
    │        Havenbrook (35,42) 🏛️       │
    │                                     │
    │  Murkmire (15,52) 🌲                │
    │              Sylvaris (45,55) 🌿   │
    │                                     │
    └─────────────────────────────────────┘
```

---

# LORE ACCURACY

## BoneTrap Matches Goblin Lore ✅

**From GOBLIN_LORE.md**:
- ✅ "Scattered in ruins and forgotten places" → Built into ruins
- ✅ "Cell-based, no central command" → No formal government
- ✅ "Paranoid survivors" → Description matches
- ✅ "Small autonomous cells" → 120 population (small)
- ✅ "Take what you can" → Motto incorporated
- ✅ "Memory of lost homelands" → Culture references this

**Unique Features**:
- Boss changes frequently (fits chaotic goblin society)
- Black market (resistance network)
- Crude landmarks (Scrap Heap, not Grand Palace)
- Hostile to outsiders (survival mentality)

## Fortune's Rest Matches Catfolk Lore ✅

**From BEAST_FOLK_LORE.md**:
- ✅ "60% of beast folk in Forbidden Deserts" → Located IN desert
- ✅ "Gambling and fortune-telling" → Cat's Eye Casino, fortune-telling feature
- ✅ "Pattern recognition" → "Balance of luck and skill" culture
- ✅ "Gathering places built on chance" → Luxury gambling city
- ✅ "Desert origin" → Desert oasis location
- ✅ "Allow catfolk to exist openly" → 70% catfolk population

**Contrast with Havenbrook**:
- Havenbrook: Rough vice, desperation, human-dominated
- Fortune's Rest: Elegant art, sophistication, catfolk-dominated
- Shows catfolk culture when they have autonomy

**Desert Harbor**:
- "Where sands meet sea" → Oasis near coast/continent edge
- Trade hub between desert and settled lands
- Lizard folk presence (10%) makes sense (desert neighbors)

---

# GAMEPLAY IMPACT

## Starting Experience by Race

**Human (Havenbrook)**:
- Familiar gambling city
- Tutorial-friendly (level 1)
- Central location (easy access to all regions)
- Mixed population

**Elf (Sylvaris)**:
- Bureaucratic city (archives, records)
- Southern location (distinct from capital)
- Elven culture dominant
- Access to sealed knowledge

**Dwarf (Ironhold)**:
- Mountain stronghold (hardest starting location)
- Level 12 (high-level challenges)
- Collectivist culture visible
- Deep mines, great forge

**Orc (Kragmor)**:
- Fortress on steppes (nomadic hub)
- Level 8 (moderate challenge)
- Martial culture
- Blood arena, war totems

**Goblin (BoneTrap)** ✨ NEW:
- Borderlands warren (isolated, dangerous)
- Level 4 (moderate challenge)
- Chaotic, distrustful culture
- Black market access (unique)
- Starts with paranoid allies

**Gnome (Mechspire)**:
- Industrial capital (most advanced)
- Level 15 (high-level start)
- Across ocean (280km journey to mainland)
- Collective ownership culture
- Clockwork technology visible

**Catfolk (Fortune's Rest)** ✨ NEW:
- Desert oasis (exotic, remote)
- Level 9 (moderate-high challenge)
- Elegant gambling culture
- Desert trade opportunities
- Starts in homeland (diaspora returns)

**Lizardfolk (Murkmire)**:
- Swamp citadel (hostile environment)
- Level 6 (moderate challenge)
- Primal, secretive culture
- Hidden knowledge
- Shadowfen concealment nearby

---

# CITY DETAILS

## BONETRAP - Full Specification

### Basic Information
- **ID**: bonetrap
- **Name**: BoneTrap
- **Region**: orcish_steppes (western borderlands)
- **Position**: X=10, Y=38 (far west of continent)
- **Level**: 4
- **Type**: tribal_warren
- **Population**: 120 (smallest anchor city)

### NPCs (Fixed)
1. **Boss Skrag**: Current tribal boss (changes frequently)
2. **Tinkerer Grix**: Saboteur/explosives expert
3. **Shaman Zeek**: Goblin spiritual leader

### Quests
- "Goblin Troubles": Deal with internal tribal conflicts
- "Warren Wars": Defend against imperial incursion or rival clans

### Landmarks
1. **Scrap Heap**: Salvage yard where goblins scrounge materials
2. **Boom Corner**: Explosives workshop (sabotage training)
3. **Boss's Shack**: Current leader's crude dwelling

### Culture & Atmosphere
**Motto**: "Take what you can, trust no one"

**Government**: No formal structure
- Boss selected through challenge/betrayal
- Changes frequently (instability)
- Reflects goblin resistance to hierarchy

**Attitude**: Paranoid survivors
- Outsiders usually robbed
- Occasionally eaten (dark humor)
- Trust is earned, rarely given

**Memory**: Remembers lost homelands
- Goblins teach children resistance songs
- Maps of ancestral lands (memorized, never written)
- Every injustice catalogued

### Demographics
- **95% Goblin**: Isolated tribal community
- **3% Human**: Outcasts, criminals, deserters
- **2% Orc**: Occasional orc visitors/traders

### Special Features
1. **Black Market**: Illegal goods unavailable elsewhere
2. **Smuggling Hub**: Connected to resistance network
3. **Illegal Goods**: Stolen imperial supplies, forbidden items
4. **Chaos**: Unpredictable, dangerous, opportunistic

### Gameplay Implications
- **Unique Start**: Only city with active black market from beginning
- **Chaotic**: NPCs may attack/rob you (goblin nature)
- **Resistance Ties**: Can join goblin resistance cells
- **Stealth**: High crime tolerance (no imperial patrols)
- **Trade**: Cheap goods (stolen), expensive food (scarcity)

---

## FORTUNE'S REST - Full Specification

### Basic Information
- **ID**: fortunes_rest
- **Name**: Fortune's Rest
- **Region**: great_endless_desert (infinite desert region)
- **Position**: X=35, Y=-8 (IN THE DESERT, north of continent)
- **Level**: 9
- **Type**: desert_harbor
- **Population**: 300

### NPCs (Fixed)
1. **Matriarch Whisperwind**: Catfolk leader (Council of Nine Lives?)
2. **Casino Master Lucky**: Runs Cat's Eye Casino
3. **Harbormaster Sandclaw**: Manages desert-sea trade

### Quests
- "Desert Mysteries": Explore hidden desert secrets
- "Nine Lives Pact": Catfolk cultural quest (luck philosophy)

### Landmarks
1. **Cat's Eye Casino**: Luxury gambling hall (pattern recognition games)
2. **Golden Docks**: Harbor where desert meets sea
3. **Arena of Acrobats**: Catfolk agility performances/competitions
4. **Silk Bazaar**: Market for luxury desert goods

### Culture & Atmosphere
**Philosophy**: "Balance of luck and skill"

**Gambling as Art**: Not desperation
- Elegant atmosphere (not seedy)
- Luck = pattern recognition (skill)
- Timing and attention matter
- Cultural identity, not addiction

**Architecture**: Sandstone with silk awnings
- Visual: Tan/gold buildings, colorful fabrics
- Desert-appropriate materials
- Flowing silk provides shade
- Oasis vegetation (palms, water features)

**Contrast with Havenbrook**:
- Havenbrook: Rough vice, human-dominated, desperation
- Fortune's Rest: Refined art, catfolk-dominated, sophistication

### Demographics
- **70% Beast Folk** (catfolk): Majority population
- **15% Human**: Traders, wealthy gamblers
- **10% Lizard Folk**: Desert neighbors (hidden rivers nearby)
- **5% Elf**: Imperial documentation (always watching)

### Special Features
1. **Luxury Gambling**: High-stakes, elegant games
2. **Acrobat Performances**: Entertainment unique to catfolk
3. **Desert Trade**: Rare goods (spices, silk, gems)
4. **Fortune-Telling**: Catfolk specialty (pattern reading)

### Climate
**Desert Oasis**:
- Hot days (scorching sun)
- Cool nights (temperature drop)
- Rare storms (sandstorms, dangerous)
- Oasis provides water (life in desert)

### Gameplay Implications
- **Desert Access**: Only starting city with direct desert access
- **Unique Gambling**: Different games than Havenbrook
- **Trade Opportunities**: Desert-exclusive goods
- **Catfolk Culture**: Experience diaspora homeland
- **Isolation**: 8 tiles from continent (journey required to reach civilization)
- **Challenge**: Desert survival mechanics?

---

# STARTING POSITIONS UPDATED

## textrpg.lua Changes (lines 6905-6915)

**Before**:
```lua
goblin = {x = 35, y = 42, town = "havenbrook"},     -- Defaulted to Havenbrook
catfolk = {x = 35, y = 42, town = "havenbrook"},    -- Defaulted to Havenbrook
```

**After**:
```lua
goblin = {x = 10, y = 38, town = "bonetrap"},       -- BoneTrap (tribal warren)
catfolk = {x = 35, y = -8, town = "fortunes_rest"}, -- Fortune's Rest (desert oasis)
```

**Result**: Goblins and catfolk now spawn in their racial cities, not Havenbrook

---

# WORLD MAP UPDATE

## Anchor Cities - Complete List (10 Total)

### Main Continent (7 cities)
1. **Havenbrook** (35, 42) - Human gambling city
2. **Solara** (40, 38) - Holy Dominion capital
3. **Sylvaris** (45, 55) - Elven administrative city
4. **Ironhold** (32, 8) - Dwarven mountain stronghold
5. **Kragmor** (18, 25) - Orcish steppe fortress
6. **BoneTrap** (10, 38) - Goblin tribal warren ✨ NEW
7. **Murkmire** (15, 52) - Lizardfolk swamp citadel

### Gnomish Isles (2 cities)
8. **Mechspire** (95, 38) - Gnomish capital
9. **Clockwork Harbor** (92, 50) - Gnomish port

### Great Endless Desert (1 city)
10. **Fortune's Rest** (35, -8) - Catfolk desert oasis ✨ NEW

**Total**: 10 anchor cities covering all major regions and all playable races

---

# TECHNICAL DETAILS

## Files Modified

### worldgen.lua
**Lines**: 437-476 (40 lines added)
- Added BoneTrap anchor city definition
- Added Fortune's Rest anchor city definition
- Both include full NPC, quest, landmark, culture data

### textrpg.lua
**Lines**: 6911, 6913 (2 lines modified)
- Updated goblin starting position: (35, 42) → (10, 38)
- Updated catfolk starting position: (35, 42) → (35, -8)

**Total Changes**: 42 lines added/modified

---

# VERIFICATION & TESTING

## Lore Accuracy Checks

### BoneTrap
- ✅ Located in margins (borderlands, not center)
- ✅ Small population (120 = tribal scale)
- ✅ No hierarchy (boss changes, not dynasty)
- ✅ Paranoid/hostile (reflects survival mentality)
- ✅ Black market (resistance network)
- ✅ Crude landmarks (scrap, not grandeur)

### Fortune's Rest
- ✅ Located IN desert (Y < 0 = desert region)
- ✅ Catfolk-dominated (70% population)
- ✅ Gambling culture (Cat's Eye Casino)
- ✅ Elegant atmosphere (contrasts Havenbrook)
- ✅ Desert-sea trade (harbor + oasis)
- ✅ Pattern recognition theme (cultural identity)

## Gameplay Testing Checklist

### BoneTrap Testing
- [ ] Create goblin character
- [ ] Verify spawns at BoneTrap (10, 38)
- [ ] Check NPCs load (Boss Skrag, etc.)
- [ ] Verify landmarks appear
- [ ] Test black market access
- [ ] Confirm western borderlands location

### Fortune's Rest Testing
- [ ] Create catfolk character
- [ ] Verify spawns at Fortune's Rest (35, -8)
- [ ] Confirm IN DESERT (Y < 0, sparse surroundings)
- [ ] Check NPCs load (Matriarch Whisperwind, etc.)
- [ ] Verify landmarks (Cat's Eye Casino, etc.)
- [ ] Test desert atmosphere
- [ ] Confirm 8-tile journey north to continent

### General Testing
- [ ] All 8 races spawn in correct cities
- [ ] No races default to Havenbrook anymore (except humans)
- [ ] City levels appropriate for new players
- [ ] Lore descriptions appear correctly

---

# FUTURE ENHANCEMENTS (Optional)

## BoneTrap Additions
- Goblin-specific quests (resistance missions)
- Warren defense mechanics (imperial raids)
- Boss challenge system (become new boss?)
- Scavenging gameplay (unique to goblins)
- Coded graffiti (resistance communication)

## Fortune's Rest Additions
- Desert survival mechanics (water, heat)
- Acrobat arena minigame
- Fortune-telling gameplay (pattern reading)
- Nine Lives lore (catfolk death/resurrection?)
- Desert caravan trading
- Sandstorm events

## Both Cities
- Racial exclusive NPCs/dialogue
- Cultural festivals/events
- Racial skill trainers
- Unique architecture/visuals
- Ambient atmosphere (sounds, effects)

---

# CONCLUSION

## Status: ✅ COMPLETE

**Added**:
- ✅ BoneTrap (goblin tribal warren) at (10, 38)
- ✅ Fortune's Rest (catfolk desert oasis) at (35, -8)

**Updated**:
- ✅ Racial spawn points use new cities
- ✅ All lore-accurate (goblin chaos, catfolk elegance)
- ✅ Geographic distribution improved (desert region now has city)

**Result**:
- 8/8 races have unique starting cities
- All cities are lore-appropriate
- Geographic diversity enhanced
- Cultural identity strengthened

**Fortune's Rest is in the actual desert** (Y < 0), as requested, making it the only anchor city in the infinite desert region—exotic, remote, and true to catfolk origins.

---

*Report Complete - January 28, 2026*
*Cities Added: 2 | Files Modified: 2 | Lines Changed: 42*
*Status: ✅ ALL RACES HAVE UNIQUE, LORE-ACCURATE STARTING CITIES*
