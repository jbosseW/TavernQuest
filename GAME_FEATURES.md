# Tavern Quest -- Comprehensive Game Features Documentation

**Last Updated:** January 30, 2026
**Engine:** LOVE2D (Lua)
**Genre:** Fantasy Text RPG with Tactical Combat, Property Management, and Open World Exploration

---

## Table of Contents

1. [Recent Changes (January 30, 2026)](#1-recent-changes-january-30-2026)
2. [Character Creation System](#2-character-creation-system)
3. [Combat Systems](#3-combat-systems)
4. [Skills and Abilities](#4-skills-and-abilities)
5. [Prison Escape -- Starting Scenario](#5-prison-escape----starting-scenario)
6. [Property and Settlement System](#6-property-and-settlement-system)
7. [Farming and Processing](#7-farming-and-processing)
8. [Inventory and Equipment](#8-inventory-and-equipment)
9. [World Generation and Exploration](#9-world-generation-and-exploration)
10. [Dungeon System](#10-dungeon-system)
11. [Faction and Guild System](#11-faction-and-guild-system)
12. [Weather and Calendar System](#12-weather-and-calendar-system)
13. [Vampire System](#13-vampire-system)
14. [Stealth and Detection System](#14-stealth-and-detection-system)
15. [Companion and Mount System](#15-companion-and-mount-system)
16. [NPC and Dialogue System](#16-npc-and-dialogue-system)
17. [Town Buildings and Services](#17-town-buildings-and-services)
18. [Business and Employee Management](#18-business-and-employee-management)
19. [Economy and Trading](#19-economy-and-trading)
20. [Save System and UI](#20-save-system-and-ui)
21. [Numerical Summary](#21-numerical-summary)

---

## 1. Recent Changes (January 30, 2026)

### Tactical Combat System -- Equipment and Visual Fixes
- **Equipment Integration:** Equipment stats (attack, defense, bonuses) now properly apply to tactical combat units. Previously, equipped weapons and armor were ignored during grid-based combat.
- **Flash Animation Fix:** Damage flash animations on units now display correctly. Fixed a rendering bug where hit units did not flash red on receiving damage.
- **Combat Balance Pass:** Ensured attack multiplier (1.2x), defense multiplier (0.8x), minimum damage floor (1), and damage variance (+/-3) constants apply consistently.

### Property System Integration
- **Farming System:** Full crop lifecycle integrated -- planting seeds, watering, fertilizing, harvesting, and seasonal restrictions.
- **Settlement Grid:** 25x25 tile settlement building system with tiered structures, walls, and population growth.
- **Processing Chains:** Crops can be processed into preserved foods (pickles, jams, wine, bread, juice) at dedicated processing stations.

### Prison Escape Integration
- **Starting Scenario:** "The Sunken Ledger" 6-floor prison dungeon now serves as the game's opening sequence.
- **Inventory Transfer:** Items crafted and scavenged during prison escape properly transfer to the main backpack system upon completion.

---

## 2. Character Creation System

### Classes (6)

| Class | HP | ATK | DEF | Mana | Starting Skills |
|-------|-----|-----|-----|------|-----------------|
| **Warrior** | 100 | 15 | 10 | 30 | Power Strike, Shield Bash, Battle Cry |
| **Mage** | 60 | 8 | 5 | 100 | Fireball, Ice Shard, Lightning Bolt |
| **Rogue** | 70 | 12 | 6 | 50 | Backstab, Poison Blade, Vanish |
| **Cleric** | 80 | 10 | 8 | 80 | Heal, Smite, Divine Shield |
| **Ranger** | 75 | 14 | 7 | 60 | Precise Shot, Hunter's Mark, Volley |
| **Monk** | 80 | 13 | 10 | 65 | Flurry of Blows, Claw Strike, Inner Focus |

### Base Races (8)

| Race | Stat Bonuses | Key Traits |
|------|-------------|------------|
| **Human** | +1 to any 2 stats (player choice) | Adaptable (+1 skill point at 1/5/10/15/20, +10% XP), Ambitious (+15% quest/combat gold) |
| **Elf** | AGI +2, MIND +1 | Keen Senses (+2 tile detection, immune surprise), Ancient Wisdom (-20% mana cost) |
| **Dwarf** | VIG +2, MIGHT +1 | Stoneborn Resilience (+20% max HP, +15% resist), Master Craftsmen (+25% materials) |
| **Orc** | MIGHT +2, VIG +1 | Savage Fury (+15% melee, +25% at low HP), Tribal Warrior (intimidation) |
| **Goblin** | AGI +2, MIND +1 | Cunning Trickster (+15% dodge, +30% ambush), Scavenger (15% extra loot) |
| **Gnome** | MIND +2, AGI +1 | Inventive Genius (+25% mana regen, 15% free spells), Small and Nimble (+10% dodge) |
| **Catfolk** | AGI +2, PRES +1 | Feline Grace (+25% crit, no fall damage), Nine Lives (survive killing blow 1/day) |
| **Lizardfolk** | VIG +2, SPIRIT +1 | Cold Blood (+30% poison resist, breathe underwater, 2% regen), Primal Hunter (+15% vs beasts) |

### Unlockable Races (12)

Each unlockable race requires specific gameplay achievements:

| Race | Stats | Unlock Condition |
|------|-------|-----------------|
| **Revenant** | MIGHT +2, VIG +1 | Defeat 100 enemies |
| **Half-Elf** | PRES +2, MIND +1 | Complete 25 quests |
| **Halfling** | AGI +1, PRES +1, SPIRIT +1 | Earn 10,000 gold total |
| **Voidborn** | MIND +2, SPIRIT +1 | Visit the Void Sanctum |
| **Celestial** | FAITH +2, SPIRIT +1 | Heal 5,000 total HP |
| **Wraith** | AGI +2, MIND +1 | Metric-based unlock |
| **Sandwalker** | -- | Achievement-based unlock |
| **Automaton** | VIG +1, MIND +1, MIGHT +1 | Craft 50 items |
| **Dark Elf** | AGI +2, PRES +1 | Perform 30 stealth kills |
| **Merfolk** | SPIRIT +2, AGI +1 | Catch 100 fish |
| **Dragonkin** | MIGHT +2, FAITH +1 | Defeat a dragon boss |
| **Nephilim** | MIGHT +1, VIG +1, SPIRIT +1 | Reach level 50 |

**Total playable races: 20** (8 base + 12 unlockable)

### Character Stats (7)

- **MIGHT** -- Physical strength, melee damage, carry weight (+5 lbs per point)
- **AGILITY** -- Speed, dodge, critical chance
- **VIGOR** -- Health, endurance, stamina
- **MIND** -- Intelligence, magic damage, mana pool
- **SPIRIT** -- Willpower, resistance, mana regeneration
- **PRESENCE** -- Charisma, social interactions, shop prices
- **FAITH** -- Divine power, holy magic, healing potency

### Backgrounds (12)

Each background provides unique starting items, stat bonuses, passive abilities, and gameplay tags:

1. **Gambling Addict** -- +30% gambling winnings, start in debt (-500g), PRES +2
2. **Vampire Hunter** -- +40% damage vs vampires/undead, FAITH +2/VIG +1, starts with wooden stake, silver dagger, holy water
3. **Cafe Veteran** -- +30% cafe tips, auto-perfect pour, PRES +1/AGI +1
4. **Deep Sea Angler** -- +25% fishing success, +50% trophy fish, SPIRIT +1
5. **Card Shark** -- +40% card game win rate, MIND +2/PRES +1
6. **Corruption Survivor** -- +50% corruption resist, detect lich lairs, SPIRIT +2
7. **Luminary Defector** -- See patrol routes, start with bounty (100g), FAITH +1
8. **Bounty Hunter** -- +40% bounty gold, tracking bonuses, AGI +1/SPIRIT +1
9. **Tavern Brawler** -- +50% unarmed damage, improvised weapons, VIG +2, banned from 3 random taverns
10. **Snake Oil Peddler** -- +35% sell prices, can scam NPCs, PRES +2/MIND +1
11. **Beast Tamer** -- Start with wolf companion, speak to beasts, SPIRIT +2
12. **Dungeon Delver** -- +30% dungeon loot, trap detection, AGI +1/MIND +1

---

## 3. Combat Systems

### Turn-Based Text Combat
- Standard RPG combat with attack, skills, items, and flee options
- Initiative-based turn order (d20 + bonus roll)
- Stamina system: All classes start with 100 stamina, regenerate 20 per turn
- Mana-based skills, stamina-based physical skills, and HP-cost blood magic skills
- Damage types: **Physical, Fire, Ice, Lightning, Holy, Dark, Poison, Arcane** (8 types)

### Tactical Grid Combat (FFT-Style)

Full Final Fantasy Tactics-inspired grid combat system:

- **Grid Size:** 12x8 tiles (96 total positions)
- **Tile Size:** 56 pixels
- **Height Levels:** 3 (affects damage bonuses/penalties)
- **Pathfinding:** A* algorithm with height-aware movement
- **Line of Sight:** Bresenham's line algorithm for ranged attacks

#### Tile Types (10)
Floor, Wall, Obstacle, Door, Pit, Water, Grass, Sand, Snow, Cobblestone

#### Environmental Hazards (4)
| Hazard | Damage | Effect |
|--------|--------|--------|
| Fire | 8 per turn | Burning DOT |
| Poison | 5 per turn | Poison DOT |
| Trap | 12 (one-time) | Triggered on step |
| Ice | -- | Slip chance, movement disruption |

#### Status Effects (12)
Slow, Stun, Root, Poison, Burn, Bleed, Blessed, Shield, Weaken, Marked, Dodge, Regen

#### Height Bonuses
| Position | Damage Modifier |
|----------|----------------|
| 2 levels above target | +25% |
| 1 level above target | +10% |
| 1 level below target | -10% |
| 2 levels below target | -20% |

#### Flanking Bonuses
- **1 ally flanking:** +15% damage
- **2+ allies flanking:** +30% damage

#### Movement and Attack Ranges by Archetype

| Archetype | Move Range | Attack Range |
|-----------|-----------|--------------|
| Warrior | 3 | 1 (melee) |
| Mage | 2 | 4 (ranged) |
| Rogue | 4 | 1 (melee) |
| Cleric | 2 | 3 (ranged) |
| Ranger | 3 | 5 (ranged) |
| Monk | 4 | 1 (melee) |

#### Battlefield Map Types (14)
Open, Dungeon, Forest, Ruins, Bridge, Swamp, Desert, Arctic, Mountain, Plains, Town, City, Ship, Building Interior

#### Interactive Objects (4)
Barrel, Crate, Lever, Explosive Barrel

#### Combat Constants
- Attack Multiplier: 1.2x
- Defense Multiplier: 0.8x
- Minimum Damage: 1
- Damage Variance: +/- 3
- Initiative: d20 + speed bonus

#### Animation and Audio
- Floating damage text with color coding
- Screen shake on critical hits
- Particle effects for spells and environmental hazards
- Movement animation along calculated paths
- Sound event hooks for all combat actions

---

## 4. Skills and Abilities

### Total Skills: 53+

#### Class Skills (18)
- **Warrior:** Power Strike (25 phys), Shield Bash (15 phys + stun), Battle Cry (+5 ATK buff)
- **Mage:** Fireball (35 fire), Ice Shard (25 ice + slow), Lightning Bolt (50 lightning)
- **Rogue:** Backstab (30 phys + 30% crit), Poison Blade (10 + 5 DOT x3), Vanish (dodge 3 turns)
- **Cleric:** Heal (30 HP), Smite (25 holy), Divine Shield (block 20 dmg x2 turns)
- **Ranger:** Precise Shot (28 phys + 15% crit), Hunter's Mark (+25% dmg taken debuff x3), Volley (20 phys AOE)
- **Monk:** Flurry of Blows (12 phys x3 hits), Claw Strike (30 phys + 20% crit), Inner Focus (heal 20 + 3 DEF x2)

#### Weapon-Type Skills (15)
**Bow (4):** Quick Shot, Aimed Shot, Multishot (3 arrows), Piercing Arrow (50% armor pen)
**Crossbow (3):** Bolt Shot, Explosive Bolt (fire AOE), Sniper Shot
**Thrown (2):** Fan of Blades (3 hits), Precision Throw
**Wand (3):** Magic Missile, Arcane Barrage (4 hits), Spell Burst
**Melee (3):** Cleave, Whirlwind (AOE), Execute (bonus vs <30% HP)

#### Elemental Skills (6)
Flame Strike (35 fire), Frost Nova (28 ice AOE + slow), Chain Lightning (30 lightning x3 bounces), Shadow Strike (32 dark + 20% crit), Holy Wrath (40 holy vs undead), Venom Spit (12 poison + 8 DOT x4)

#### Stamina Skills (4)
Heroic Strike (35 phys, 20 stamina), Charge (28 phys + stun, 25 stamina), Rapid Fire (20 phys x4, 30 stamina), Power Shot (40 phys, 15 stamina)

#### Blood Magic Skills (4) -- HP Cost
Blood Sacrifice (50 dark, costs 20 HP), Life Drain (30 dark + 100% lifesteal, costs 15 HP), Blood Boil (35 fire AOE, costs 25 HP), Ritual of Pain (+10 ATK buff, costs 30 HP)

---

## 5. Prison Escape -- Starting Scenario

### "The Sunken Ledger"

A 6-floor prison dungeon serving as the game's tutorial and opening act.

#### Floor Layout (Bottom to Top)
1. **Cell Block D** (Deepest) -- Starting location, locked cells, first allies
2. **General Population** -- Common areas, social hub, more allies
3. **Guard Quarters** -- Increased danger, patrols, equipment cache
4. **Beast Containment** (Hidden Floor) -- Monsters, The Broodmother boss
5. **Warden's Level** -- Administrative area, final boss
6. **Surface/Docks** -- Escape point, Warden Blackthorn fight

#### Floor Dimensions
30x25 tiles per floor, procedurally generated with room-corridor layout

#### Cuffs Debuff (Starting Condition)
Players begin shackled with severe penalties:
- MIGHT -4, AGILITY -6, VIGOR -2, MIND -1, SPIRIT -2, PRESENCE -3
- Attack -5, Defense -3
- 50% movement speed penalty
- No spellcasting allowed

#### Guard System
- **4-hour patrol rotation cycles** with 2-minute shift change vulnerability windows
- **Alert Levels:** 0 = None, 1 = Suspicious, 2 = Search, 3 = Lockdown
- **Guard Types:**
  - Prison Guard (35 HP)
  - Sergeant (55 HP)
  - Warden Enforcer (80 HP, mini-boss)

#### Beast Types (4)
- Cave Rat Swarm (20 HP)
- Chained Hound (40 HP)
- Tunnel Spider (30 HP)
- Deep Horror (100 HP, mini-boss)

#### Bosses (2)
- **The Broodmother** (180 HP) -- Floor 4
- **Warden Blackthorn** (250 HP) -- Floor 6

#### Recruitable Allies (4)
| Ally | Race | Class | Found |
|------|------|-------|-------|
| Grimjaw | Orc | Warrior | Floor 1 |
| Sera Voss | Human | Rogue | Floor 2 |
| Brother Aldric | Human | Cleric | Floor 2 |
| Nyx | Goblin | Mage | Floor 3 |

#### Crafting Recipes (9)
Bone Shank, Prison Shiv, Makeshift Club, Magic Focus, Sling, Guard Sword, Lockpick, Crude Bandage, Makeshift Armor

#### Scavengeable Items (12 types)
Found through searching cells, common areas, and corpses

#### Objectives
- **Required:** 6 main objectives
- **Optional:** 7 side objectives
- **Cutscene Triggers:** 8
- **Prisoner Lore Notes:** 6 collectible documents

---

## 6. Property and Settlement System

### Town Properties

#### Business Properties (6)
| Property | Cost | Function |
|----------|------|----------|
| Forge | 5,000g | Weapon/armor crafting |
| Wizard Tower | 8,000g | Spell research |
| Alchemist | 6,000g | Potion brewing |
| Fishing Dock | 3,000g | Fishing income |
| Hunter's Lodge | 4,000g | Hunting income |
| Trading Post | 8,000g | Trade route income |

#### Home Properties (7)
| Home | Cost | Storage Slots |
|------|------|---------------|
| Shack | 500g | 10 |
| Cottage | 1,500g | 20 |
| House | 5,000g | 35 |
| Large House | 10,000g | 50 |
| Manor | 20,000g | 70 |
| Mansion | 35,000g | 85 |
| Noble Estate | 50,000g | 100 |

### Wild Land Properties

#### Structure Tiers (4-tier upgrade chain)
Tent -> Cabin -> House -> Manor

#### Wall Tiers (3)
Wooden Fence -> Stone Wall -> Fortified Wall

#### Improvements (18+)
Well, Storage Cellar, Watchtower, Trade Post, Shrine, Blacksmith, Farm (3x3), Expanded Farm (5x5), Large Farm (7x7), Irrigation, Greenhouse, Preserving Station, Kitchen, Jam Maker, Brewery, Juicer, Stables, and more

### Settlement Building System

#### Grid
25x25 tile settlement grid

#### Building Categories
- **Residential:** Cottage, House, Manor
- **Workshop:** Forge, Kitchen, Alchemy Lab
- **Storage:** Warehouse, Barn
- **Defense:** Barracks, Watchtower
- **Economy:** Market, Trade Post
- **Agriculture:** Farm Building, Greenhouse
- **Infrastructure:** Road, Well, Fountain

#### Wall Segments
Wooden Palisade -> Stone Wall -> Fortified Wall -> Gate

#### Settlement Levels
| Level | Name | Population |
|-------|------|-----------|
| 1 | Homestead | 5 |
| 2 | Hamlet | 15 |
| 3 | Village | 50 |
| 4 | Town | 200 |
| 5 | City | 500 |

#### Daily Simulation
- Construction progress tracking
- Attack simulation (region danger level affects chance)
- Income, wages, and tax calculations
- Lumber gathering with deforestation and regrowth mechanics

---

## 7. Farming and Processing

### Farming System
- **Plot Sizes:** 3x3, 5x5, 7x7 (small, expanded, large farm)
- **Actions:** Plant seeds, water plots, fertilize, harvest
- **Seasonal Restrictions:** Crops have specific growing seasons
- **Growth Stages:** Seed -> Sprout -> Mature -> Harvestable

### Seeds (18+ types)
Full variety of plantable seeds for vegetables, herbs, fruits, and grains

### Harvested Crops (12+ types)
Raw agricultural products from farming

### Processing Chains

| Station | Input | Output |
|---------|-------|--------|
| Preserving Station | Vegetables | Pickles (4+ types) |
| Jam Maker | Fruits | Jams (3+ types) |
| Brewery | Grains/Fruits | Wine (4+ types) |
| Kitchen | Grains | Bread, Baked Goods (3+ types) |
| Juicer | Fruits | Juice (2+ types) |

All processing is time-based with real progression timers.

---

## 8. Inventory and Equipment

### Weight and Encumbrance System

- **Base Carry Capacity:** 50 lbs + 5 per MIGHT point
- **Encumbrance Thresholds:**

| Level | Weight % | Penalty |
|-------|----------|---------|
| Light | 0-50% | None |
| Medium | 50-75% | -25% speed |
| Heavy | 75-100% | -50% speed |
| Overencumbered | 100-125% | -75% speed |
| Immobile | 125%+ | Cannot move |

### Transport (Carts)
| Cart | Bonus Capacity |
|------|---------------|
| Handcart | +50 lbs |
| Small Wagon | +150 lbs |
| Large Wagon | +400 lbs |
| Merchant Caravan | +800 lbs |

### Beasts of Burden (6)
| Beast | Bonus Capacity |
|-------|---------------|
| Donkey | +80 lbs |
| Mule | +120 lbs |
| Pack Horse | +150 lbs |
| Camel | +180 lbs |
| Ox | +200 lbs |
| Elephant | +500 lbs |

Beasts of burden have needs systems (hunger 0-100%, stamina 0-100%) that must be managed through feeding and resting.

### Equipment Slots
- Weapon (melee, bows, crossbows, throwing, wands)
- Armor (light, medium, heavy, robes)
- Shield (7 types)
- Accessories (9+ types)
- Clothing (7 types)

### Item Categories (200+ total items)
- **Consumables:** Potions, food, bandages
- **Materials:** Crafting components, ores, wood
- **Weapons:** Swords, axes, maces, bows, crossbows, throwing weapons, wands
- **Armor:** Light, medium, heavy, robes, shields
- **Spells:** Scrolls and spell components
- **Potions:** Health, mana, buff potions
- **Treasures:** Gems, artifacts, valuables
- **Seeds:** 18+ plantable crop seeds
- **Tools:** Farming, fishing, crafting tools
- **Food:** Raw ingredients, cooked meals, preserved foods
- **Transport:** Carts, wagons
- **Special Items:** Quest items, keys, unique artifacts

### Specialty Item Sets

#### Prison Escape Items
12 scavengeable materials, 6 craftable weapons, makeshift armor, lockpicks, bandages

#### Hollow Earth Items
Core Crystal, Bioluminescent Fungi, Dinosaur Scale, Voidsteel Ore, Saurian Bone Blade, Void Essence

#### Stealth System Items
Cloak, Hood, Boots, Shadow Dye, Smoke Bomb, Disguise Kit, Lockpicks

#### Vampire System Items
Coffin, Black Cloth, Holy Water, Vampire Fang, Dark Essence

#### Tavern/Shop Items
Butcher products, bakery goods, quality ales, cooking ingredients

---

## 9. World Generation and Exploration

### Chunk-Based World System

- **Chunk Size:** 16x16 tiles (80x80 km at 5 km/tile)
- **Load Radius:** 2 chunks around player
- **Max Loaded Chunks:** 25 (5x5 grid)
- **World Scale:** 5 km per tile, 25 sq km per tile, 3.1 miles per tile

### Layer System
- **Surface Layer** (Y=0): Normal overworld
- **Hollow Earth Layer** (Y offset -1000): Underground mega-biome

### Surface Regions

#### Main Continent -- "The Realm" (64x64 tiles, ~100,000 sq km)

| Subregion | Terrain | Description |
|-----------|---------|-------------|
| **Dwarven Mountains** | Mountain (65%) | Northern mountains, mine-heavy |
| **Orcish Steppes** | Grass/Desert | West-central, war camps and strongholds |
| **The Holy Dominion** | Grass/Forest | Central-south, civilized heartland |
| **Shadowfen** | Swamp (60%) | Southwest, dangerous magical refuge |
| **Eastern Forests** | Forest (60%) | Eastern coast, ancient woodlands |

#### Gnomish Isles (30x30 tiles, ~22,000 sq km)
Island nation 280 km offshore with Mechspire Region (capital) and Clockwork Coast

#### Great Endless Desert (150x50 tiles, ~187,500 sq km)
Massive desert continent north of the Realm. Beast folk origins, Lizard folk hidden river empires beneath the sands. 97% empty, 3% points of interest. Imperial maps label it "endless" -- it is crossable.

#### Scorched Sands
Western continental barrier desert extending beyond imperial maps

#### Frostbound Reach (50x50 tiles, ~62,500 sq km)
Frozen island far north with volcanic mountain ranges, geothermal valleys, ice cliffs, glacier caves, and steam vents. Brief summer navigability window. Estimated 100-500 inhabitants near volcanic vents.

#### Northern Tundra Continent (250x230 tiles)
Continent-sized frozen landmass forming part of the world's circumnavigation route. Beyond all imperial knowledge. Possible unknown adapted civilizations.

#### Wastes of Calidar (30x15 tiles, ~11,250 sq km)
Glass desert, former elven homeland of Calidar destroyed 500 years ago by Heaven's Atlas. Vitrified forests, memory echoes, psychological horror.

#### Ashen Archipelago
Chain of volcanic islands in the Western Ocean including The Great Western Isle (40x30 tiles, ~30,000 sq km). Contains THE VOLCANIC DESCENT -- the only guaranteed passage to the Hollow Earth. Independent tribal settlements of 1,000-3,000 population. Empire denies its existence.

#### Ocean Regions
- **Shimmering Sea** (between continent and Gnomish Isles) -- sea features, reefs, shipwrecks
- **Western Ocean / Outer Waters** -- beyond the Scorched Sands
- **Northern Frozen Seas** -- ice-choked waters surrounding Frostbound Reach

### Hollow Earth Regions (7)

| Region | Terrain | Special Features |
|--------|---------|-----------------|
| **Fungal Forests** | Bioluminescent fungi | Giant mushroom trees (50m high), spore clouds, phosphorescent slime rivers |
| **Hollow Jungle** | Prehistoric jungle | Ancient ruins, abandoned temples |
| **Subterranean Seas** | Underground ocean | Sea caves, sunken tombs |
| **Crystal Caverns** | Crystalline caves | Crystal mining, prismatic light |
| **Bone Wastes** | Necropolis | Highest lich concentration in entire game |
| **Storm Caverns** | Lightning caves | Electrical storms underground |
| **Deep Dwarven Realm** | Ancient dwarf halls | Deep mines, ruined strongholds |

---

## 10. Dungeon System

### Dungeon Types by Biome (45+ total)

#### Grassland Dungeons (9 types)
Dungeon, Cave, Mine, Vampire Den, Crypt, Bandit Fort, Mercenary Keep (boss-tier), Dark Castle (very rare), Lich Lair (legendary rare)

#### Desert Dungeons (7 types)
Desert Tomb, Desert Temple, Sandstone Crypt, Bandit Citadel, Scorpion Temple (boss-tier), Sand Wyrm Den (very rare), Pharaoh's Tomb (legendary rare)

#### Water Dungeons (8 types)
Sea Cave, Sunken Ship, Underwater Ruins, Sea Fortress, Pirate Stronghold, Merfolk Palace (boss-tier), Leviathan Trench (very rare), Kraken's Lair (legendary rare)

#### Forest Dungeons (7 types)
Overgrown Ruins, Corrupted Grove, Ancient Hollow, Dark Barrow, Bandit Camp, Outlaw Fortress (boss-tier), Wild Hunt Lodge (very rare)

#### Swamp Dungeons (7 types)
Bog Ruins, Witch's Hovel, Troll Den, Poison Grotto, Witch Coven, Hag Fortress (boss-tier), Necromancer's Marsh (very rare)

#### Mountain Dungeons (7 types)
Mountain Cave, Abandoned Mine, Frost Cavern, Dragon's Roost (boss-tier), Giant's Keep (boss-tier), Ruined Stronghold (very rare), Wyvern Nest (very rare)

### Lich Lair System (World Threat)
- 8-12 floors (massive dungeons)
- 5-tile corruption radius around the lair
- 0.3% base spawn chance per dungeon tile
- Must be 8+ tiles from any town
- 3-tile undead patrol radius
- 10% daily blight spread chance
- Region-specific spawn weights (highest in Hollow Earth Bone Wastes at 1.5x)

### Region-Specific Dungeon Weighting (19 regions)
Each of the 19 world regions has custom dungeon spawn weights. Examples:
- **Shadowfen:** 3.0x Vampire Den, 0.8x Lich Lair (dark magic thrives)
- **Dwarven Mountains:** 3.0x Mine, 0.1x Lich Lair (dwarves mine, no tolerance for necromancy)
- **Hollow Bone Wastes:** 5.0x Crypt, 1.5x Lich Lair (highest lich concentration in game)
- **Holy Dominion:** 2.0x Crypt, 0.3x Lich Lair (holy burial sites, fallen clergy)
- **Gnomish Isles:** 2.5x Mine, 0.05x Lich Lair (gnomes eliminate dark magic)
- **Shimmering Sea:** 0x Lich Lair (corruption cannot cross water)

### Sea Dungeon Enemies (by depth)

| Tier | Example Enemies | HP Range |
|------|----------------|----------|
| Shallow | Drowned Sailor, Giant Crab, Merfolk Guard | 20-35 |
| Mid | Bull Shark, Merfolk Warrior, Giant Octopus | 42-55 |
| Deep | Sea Serpent, Deep Aboleth, Megalodon | 65-120 |
| Boss | Kraken (250 HP), Leviathan (300 HP), Sea Dragon (220 HP) | 220-300 |

---

## 11. Faction and Guild System

### Nations (5)

| Nation | Capital | Description |
|--------|---------|-------------|
| **The Holy Dominion** | Solara | Human empire ruled by the High Priest. Helios worship. Enemies: Shadowfen witches. Allies: Blacksmith Guild, Merchants Guild. |
| **Free Holds of Stone** | Ironhold | Dwarven collectivist labor federation. No kings, no hierarchy. Guild councils govern through collective deliberation. Allies: Blacksmith Guild, Miners Union. |
| **Orcish Clans** | Kragmor | Nomadic steppe warriors, once history's most effective military civilization. Merit-based, disciplined. Currently fragmented but dormant -- the laws still exist, the routes remembered. Imperial fear: "They only need to unite again." |
| **Shadow Fen Commune** | Murkmire | Magically concealed refuge in the southwestern swamps. Former refugees, fugitive mages, and outlaws who fled imperial control. Allies: Thieves Guild. |
| **The Gnomish Collective** | Mechspire | Collectivist island nation with no private ownership. Ruled by production councils, not elected representatives. No religion. Efficiency and function define prestige. |

### Lawful Guilds (5)

| Guild | Join Requirements | Benefits |
|-------|------------------|----------|
| **Blacksmith's Guild** | Karma >= 0 | +15% crafting, -10% shop prices |
| **Merchant's Guild** | Karma >= 10, 500g | -20% shop prices, +15% sell bonus |
| **Adventurer's Guild** | Karma >= 0, 10 enemies defeated | +25% quest rewards, +10% combat XP |
| **Sanctioned Arcanum** (Mages) | Karma >= 5 | +15% spell damage, +2 mana regen |
| **Steel Brotherhood** (Fighters) | Level 3+, Karma >= -20 | +15% combat XP, +5% crit |

### Crime Organizations (3)

| Organization | Join Requirements | Benefits |
|-------------|------------------|----------|
| **Thieves' Guild** | Karma <= -10 | +30% lockpick, +20% stealth |
| **Assassin's Guild** | Karma <= -25, 5 murders | +30% crit damage, +50% poison |
| **Smuggler's Ring** | Karma <= -5 | -50% travel costs |

---

## 12. Weather and Calendar System

### Calendar

#### Months (12)
| Month | Days | Season |
|-------|------|--------|
| Deepmere | 31 | Frosthollow |
| Ironveil | 28 | Frosthollow |
| Thawmist | 31 | Brightbloom |
| Greenward | 30 | Brightbloom |
| Starbloom | 31 | Brightbloom |
| Solaren | 30 | Sunreign |
| Highsun | 31 | Sunreign |
| Forgefire | 31 | Sunreign |
| Harvestmere | 30 | Ashwane |
| Glassfall | 31 | Ashwane |
| Shadowmere | 30 | Ashwane |
| Voidwatch | 31 | Frosthollow |

**Days per year:** 365

### Seasons (4)

| Season | Months | Theme |
|--------|--------|-------|
| **Frosthollow** | Voidwatch, Deepmere, Ironveil | Deep winter, cold, vigil against the void |
| **Brightbloom** | Thawmist, Greenward, Starbloom | Spring thaw, green returns, stars and blooming |
| **Sunreign** | Solaren, Highsun, Forgefire | Summer peak, Helios honored, dwarven forging |
| **Ashwane** | Harvestmere, Glassfall, Shadowmere | Autumn harvest, leaves fall, shadows lengthen |

### Weather States (8)

| Weather | Icon | Speed | Stamina Drain | Combat Mod | Special |
|---------|------|-------|---------------|------------|---------|
| Sunny | Sun | 1.0x | 1.0x | 0 | -- |
| Pleasant | Part-sun | 1.1x | 0.8x | 0 | Best travel weather |
| Cloudy | Cloud | 1.0x | 0.9x | 0 | -- |
| Rainy | Rain | 0.8x | 1.3x | -5 | Needs shelter |
| Stormy | Storm | 0.5x | 2.0x | -15 | Dangerous, 5 dmg/hr |
| Foggy | Fog | 0.7x | 1.0x | -10 | Reduced visibility |
| Snowy | Snow | 0.6x | 1.5x | -5 | Needs shelter |
| Windy | Wind | 0.9x | 1.2x | -5 | -- |

### Weather Dialogue System
NPCs react dynamically to weather with positive, neutral, and negative dialogue lines for each of the 8 weather states (48+ unique weather dialogue lines total). Weather affects NPC mood and conversation topics.

---

## 13. Vampire System

### Vampire Transformation
Players can become vampires through gameplay events. Vampires gain access to a tiered skill tree funded by vampire skill points (gained every 2 levels after transformation).

### Vampire Skill Tree (9 skills, 3 tiers)

#### Tier 1 -- Basic Powers (Cost: 1 point each)
- **Blood Drain** -- Heals 25% of damage dealt
- **Night Vision** -- +20% damage and accuracy at night
- **Mist Form** -- 50% damage reduction for 3 turns

#### Tier 2 -- Advanced Powers (Cost: 2 points each)
- **Bat Swarm** -- Attack all enemies (requires Mist Form)
- **Hypnotic Gaze** -- 50% less detection by NPCs (requires Blood Drain)
- **Enhanced Regeneration** -- 5% max HP per turn in combat (requires Blood Drain)

#### Tier 3 -- Master Powers (Cost: 3 points each)
- **Shadow Step** -- Teleport, instant combat escape (requires Bat Swarm)
- **Vampiric Lord** -- +50% all stats transformation (requires Enhanced Regeneration)
- **Blood Plague** -- 100% vampirism spread with no detection (requires Hypnotic Gaze)

### Vampire Epidemic System
- NPC vampires can spread vampirism to other NPCs in their location
- Location-based tracking of vampire populations per settlement
- Luminary Inquest roving patrols hunt vampires (dedicated `luminarypatrols.lua` module)
- Sunlight damage to NPC vampires caught outdoors during daytime
- Distance-based NPC dormancy optimization (32-tile activity radius around player)
- Vampire NPC cache for performance optimization (O(1) lookup via indexed locations)
- Epidemic/purge thresholds tracked per location

### Vampire Den Infiltration
Dedicated infiltration module (`vampireinfiltration.lua`) for raiding vampire dens with stealth mechanics.

---

## 14. Stealth and Detection System

### Stealth Mode Toggle
Players can toggle stealth mode on/off via a UI slide toggle, affecting movement speed and detection chance.

### Time-Based Modifiers
Detection chance varies across a full 24-hour cycle, with nighttime hours providing significant stealth bonuses and daytime increasing detection risk.

### Location Modifiers
| Location | Detection Level |
|----------|----------------|
| Town (Day) | Higher detection |
| Town (Night) | Moderate detection |
| Alley | Reduced detection |
| Wilderness | Low detection |

### Stealth Equipment
Cloak, Hood, Boots, Shadow Dye, Smoke Bomb, Disguise Kit -- all contribute to stealth rating calculations.

### Stealth Integration
- Affects combat encounter initiation (ambush bonuses)
- Modifies NPC interaction outcomes
- Interacts with vampire detection system
- Visual indicator on HUD when stealth mode is active

---

## 15. Companion and Mount System

### Hireable Companion Classes (6)

| Class | HP | ATK | DEF | Hire Cost | Daily Wage | Special |
|-------|-----|-----|-----|-----------|-----------|---------|
| **Soldier** | 80 | 12 | 10 | 100g | 10g | Taunt, Guard Ally |
| **Archer** | 50 | 14 | 5 | 120g | 12g | Mark Target, Evasion |
| **Battle Mage** | 45 | 16 | 4 | 200g | 20g | Spell Shield, Mana Burn |
| **Healer** | 55 | 6 | 6 | 180g | 18g | Heal Ally, Purify (heals 15/turn) |
| **Thief** | 40 | 13 | 4 | 90g | 8g | Steal, Smoke Bomb (+20% crit) |
| **Berserker** | 90 | 18 | 2 | 150g | 15g | Rage, Reckless Attack |

- Companions scale with player level (level = player level - 1, with +/- 1 random variance)
- Stats scale: HP = base + (levelBonus * 8), ATK = base + (levelBonus * 2), DEF = base + levelBonus
- Randomly generated names from a pool of 30 first names
- Each has 3 attack abilities and 2 special skills

### Pet Companions
Battle-assisting pet system (separate from hired companions). Beast Tamer background starts with a wolf companion.

### Mount System

| Mount Type | Speed Modifier |
|------------|---------------|
| Land Mount | 2.0x |
| Flying Mount | 4.0x |
| Aquatic Mount | 2.0x |
| Boat | 2.5x |
| Cart | 1.5x |

---

## 16. NPC and Dialogue System

### Weather-Reactive Dialogue
NPCs have contextual dialogue based on current weather conditions. Each weather state (8 total) has positive, neutral, and negative response pools, creating dynamic conversation that reflects the game world's current state. Examples:
- Sunny: "Beautiful day, isn't it?" / "Too hot for my liking."
- Stormy: "Exciting weather!" / "Terrible storm outside!"
- Snowy: "A true Frosthollow wonderland!" / "This cold bites to the bone!"

### Luminary Inquest Patrols
Roving NPC patrol system for the Holy Dominion's vampire hunters (`luminarypatrols.lua`). Patrols actively seek vampire NPCs using cached position data.

### Daily World Events
- Lich blight spread once per day
- Vampire population spreading
- NPC activity cycles
- World state changes

---

## 17. Town Buildings and Services

### Essential Services
- **Town Hall:** Visit elders, access quests
- **Chapel:** Blessings for HP/MP restoration
- **Guild Hall:** Recruit companions
- **Inn:** Rest and recover (20g)
- **Tavern:** Talk to NPCs, ambient dialogue
- **General Store:** Buy supplies
- **Stable:** Mount management and fast travel
- **Job Board:** Find work opportunities

### Shopping
- **Market:** Trade goods
- **Butcher:** Meat and provisions
- **Bakery:** Bread and pastries
- **Tailor:** Clothing
- **Jeweler:** Rings and trinkets

### Entertainment
- **Race Track:** Horse racing and betting
- **Casino:** Slot machines and gambling
- **Cafe:** Wage work and management mini-game

### Town Navigation
- 6x12 grid layout with horizontal streets between building rows
- Vertical main street down center
- Cursor-based movement (WASD)
- Mouse support for clicking buildings

---

## 18. Business and Employee Management

### Employee System
- Must own property to hire employees
- Different employee types per business (kitchen staff, bartenders, servers, hunters, fishermen, etc.)
- Hire cost (one-time) plus daily wages (recurring)
- Gender-matched names and portraits
- Experience and efficiency levels
- Automatic production (crafting, gathering, brewing)

### Business Activities (6 Total)

| Business | Activity Type | Features |
|----------|-----------|----------|
| **Forge** | Crafting | Weapon/armor creation, quality system, skill progression |
| **Alchemist** | Brewing | Potion creation, recipe unlocking, alchemy skill |
| **Wizard Tower** | Spell Creation | Scrolls, magic research, apprentice system |
| **Fishing Dock** | Fishing | Cast and catch, fish varieties, skill improvement |
| **Hunter's Lodge** | Hunting | Track and hunt, different game animals, skill development |
| **Trading Post** | Stock Trading | Market trading, stock prices, investment system |

**Not Implemented:** Casino/Slot Machines, Race Track/Horse Betting, Cafe/Restaurant Management
**Locked (Coming Soon):** Theater

---

## 19. Economy and Trading

### Currency
- **Gold:** Primary currency earned from quests, jobs, combat, businesses
- **Crystals:** Premium currency used for fusion upgrades

### Income Sources
- Quest rewards
- Job board payments
- Business passive income
- Crafting sales
- Combat loot
- Property/settlement income
- Gambling winnings

### Expenses
- Property taxes (daily on owned businesses)
- Employee wages (daily recurring)
- Inn costs (20g per rest)
- Shop purchases
- Chapel blessings (10g)
- Travel costs

### Card Collection and Fusion System
- Collect various cards throughout the world
- Deck building for card game challenges
- Fusion upgrades purchased with Crystals:
  - Splinter Chance (+2%/level), Mirror Chance (+1%/level), Bonus Chips (+5/level)
  - Bonus Mult (+1/level), Catalyst Chance (+1%/level), Prismatic Chance (+1%/level)
  - Echo Chance (+1%/level), Fortify Chance (+2%/level)

---

## 20. Save System and UI

### Save System
- 3 save slots available
- View save info (wins, losses, coins, last played)
- Delete saves (full or soft delete)
- Auto-save progress
- Backwards compatibility with save migration

### Navigation Controls
- **WASD:** Movement in town and world
- **I:** Inventory
- **Q:** Quest Log
- **T:** Party
- **E:** Employees (in businesses)
- **U:** Upgrades (in businesses)
- **B:** Backpack (in crafting)
- **SPACE:** Context actions
- **ESC:** Back/Exit
- **Mouse:** Click buttons, UI elements, buildings

### Visual Features
- Town layout grid with building icons
- Player cursor with pulsing indicator
- Weather visual effects
- Portrait system for characters and employees
- Tooltips on hover/selection
- Stealth mode HUD indicator

### Audio System
- Music system with area-specific tracks
- Sound effects for combat, UI, and world events
- Volume controls for music and SFX
- Mute toggle

---

## 21. Numerical Summary

| Category | Count |
|----------|-------|
| Player Classes | 6 |
| Base Races | 8 |
| Unlockable Races | 12 |
| **Total Playable Races** | **20** |
| Character Backgrounds | 12 |
| Character Stats | 7 |
| Damage Types | 8 |
| Combat Skills (mana) | 39 |
| Stamina Skills | 4 |
| Blood Magic Skills (HP cost) | 4 |
| Vampire Skills | 9 |
| **Total Skills** | **56+** |
| Status Effects | 12 |
| Total Items | 200+ |
| Dungeon Types (all biomes) | 45+ |
| Biomes with Unique Dungeons | 6 |
| Battlefield Map Types | 14 |
| Tactical Grid Tile Types | 10 |
| Environmental Hazards | 4 |
| Interactive Combat Objects | 4 |
| Weather States | 8 |
| Seasons | 4 |
| Calendar Months | 12 |
| Days Per Year | 365 |
| Nations | 5 |
| Lawful Guilds | 5 |
| Crime Organizations | 3 |
| **Total Factions** | **13** |
| Hireable Companion Classes | 6 |
| Mount Types | 5 |
| Beasts of Burden | 6 |
| Cart Types | 4 |
| Prison Floors | 6 |
| Prison Allies | 4 |
| Prison Bosses | 2 |
| Prison Craft Recipes | 9 |
| Prison Enemy Types | 7 |
| Business Properties | 6 |
| Home Properties | 7 |
| Wild Structure Tiers | 4 |
| Wall Tiers | 3 |
| Property Improvements | 18+ |
| Settlement Building Categories | 7 |
| Settlement Levels | 5 |
| Surface Regions | 12+ |
| Hollow Earth Regions | 7 |
| Dungeon Weight Regions | 19 |
| Farm Plot Sizes | 3 |
| Processing Station Types | 5 |
| Business Activities | 6 |
| Sea Dungeon Enemy Tiers | 4 |
| Sea Dungeon Bosses | 3 |

---

## Appendix: File Reference

| File | Approx. Lines | System |
|------|--------------|--------|
| `textrpg.lua` | 30,000+ | Core engine: classes, races, skills, factions, weather, calendar, combat, quests, NPCs, stealth, vampires |
| `tactical_combat.lua` | 2,893 | FFT-style grid combat: A* pathfinding, battlefields, hazards, status effects, animations |
| `propertysystem.lua` | 3,000+ | Property ownership, settlement building, farming, processing, lumber, daily simulation |
| `backpack.lua` | 1,200+ | Inventory management: 200+ items, encumbrance, carts, beasts, mounts, equipment |
| `prison_escape.lua` | 1,317 | Starting scenario: 6-floor dungeon, guards, allies, crafting, bosses |
| `worldgen.lua` | 900+ | Chunk-based world generation: regions, layers, dungeon placement, terrain |
| `vampireinfiltration.lua` | -- | Vampire den infiltration module |
| `luminarypatrols.lua` | -- | Holy Dominion patrol system |
| `mathutil.lua` | -- | Shared math utilities (direction calculations) |

---

*This document was generated from comprehensive source code analysis of the Tavern Quest game files on January 30, 2026.*
