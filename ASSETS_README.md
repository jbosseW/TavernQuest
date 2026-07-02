# 2D Visual RPG - Asset Pack Documentation

This document describes the three asset packs integrated into the game and how to use them.

---

## **Downloaded Asset Packs**

### **1. Dungeon Crawl Stone Soup 32x32 Tiles**
- **Location:** `assets/dungeon_crawl/Dungeon Crawl Stone Soup Full/`
- **Size:** 5.7 MB
- **License:** CC0 (Public Domain) - No attribution required
- **Content:** 3,000+ tiles organized into:
  - `dungeon/` - Floors, walls, doors, traps, altars, trees
  - `monster/` - Hundreds of enemy sprites
  - `item/` - Weapons, armor, potions, scrolls, gold, food
  - `player/` - Character body parts (mix & match customization)
  - `effect/` - Spell effects, explosions, particles
  - `gui/` - UI elements

### **2. RPG GUI Construction Kit v1.0**
- **Location:** `assets/rpg_gui_kit/`
- **Size:** 2.9 MB
- **License:** CC-BY 3.0 (Attribution: Matjaž Lamut)
- **Content:**
  - `RPG_GUI_v1.png` - Complete sprite sheet with all UI elements
  - `wood background.png` - Medieval wood texture (525 KB)
  - `paper background.png` - Parchment texture (413 KB)
  - `RPG_GUI_v1_source.xcf` - GIMP source file for customization

### **3. Moderna Graphical Interface**
- **Location:** `assets/moderna/`
- **Size:** 5.3 MB
- **License:** CC-BY 3.0 (Attribution: Jorge Avila)
- **Content:**
  - `moderna_interface.psd` - Photoshop file with layers:
    - HP/Mana bars
    - Inventory window
    - Quest log window
    - Spell quick bar
    - System icons
    - Custom cursor

---

## **Asset Organization**

```
assets/
├── dungeon_crawl/
│   └── Dungeon Crawl Stone Soup Full/
│       ├── dungeon/
│       │   ├── floor/          (Stone, grass, ice, sand tiles)
│       │   ├── wall/           (Brick, catacombs, vault walls)
│       │   ├── doors/          (Closed, open, gates)
│       │   ├── gateways/       (Portals, stairs)
│       │   ├── trees/          (Forest decoration)
│       │   └── water/          (Water tiles, rivers)
│       ├── monster/
│       │   ├── animals/        (Rats, bats, wolves, bears)
│       │   ├── undead/         (Skeletons, zombies, ghosts)
│       │   ├── demons/         (Imps, devils, succubi)
│       │   └── [200+ monster sprites]
│       ├── item/
│       │   ├── weapon/         (Swords, axes, bows, staves)
│       │   ├── armor/          (Helmets, chest, boots)
│       │   ├── potion/         (Health, mana, buffs)
│       │   ├── scroll/         (Spell scrolls)
│       │   ├── gold/           (Coin piles)
│       │   └── misc/           (Keys, gems, books)
│       ├── player/
│       │   ├── base/           (Human, elf, dwarf, orc bodies)
│       │   ├── hair/           (Hair styles)
│       │   ├── body/           (Clothing layers)
│       │   ├── hand_left/      (Left hand equipment)
│       │   └── hand_right/     (Right hand equipment)
│       └── effect/
│           ├── (Spell particles, explosions, magic)
│
├── rpg_gui_kit/
│   ├── RPG_GUI_v1.png          (Sprite sheet: buttons, panels, frames)
│   ├── wood background.png     (Wood texture for panels)
│   ├── paper background.png    (Parchment for dialogue)
│   └── RPG_GUI_v1_source.xcf   (GIMP source for editing)
│
└── moderna/
    └── moderna_interface.psd   (Layers for HP bars, windows, icons)
```

---

## **Using the Assets**

### **Loading Assets**

Use the `assetloader.lua` module:

```lua
local AssetLoader = require("assetloader")

function love.load()
    AssetLoader.init()  -- Load all assets
end
```

### **Accessing Dungeon Crawl Assets**

```lua
-- Get a floor tile
local stoneTile = AssetLoader.getFloorTile("stone_2_brown")
love.graphics.draw(stoneTile, x, y)

-- Get a wall tile
local brickWall = AssetLoader.getWallTile("brick_dark")
love.graphics.draw(brickWall, x, y)

-- Get a door
local closedDoor = AssetLoader.getDoor("closed_door")
love.graphics.draw(closedDoor, x, y)

-- Get a monster sprite
local ratSprite = AssetLoader.getMonster("rat")
love.graphics.draw(ratSprite, x, y)
```

### **Accessing RPG GUI Kit**

```lua
-- Get the main UI sprite sheet
local guiSheet = AssetLoader.getGUISheet()

-- Use quads to extract specific buttons/panels
local buttonQuad = love.graphics.newQuad(0, 0, 100, 40, guiSheet)
love.graphics.draw(guiSheet, buttonQuad, x, y)

-- Get wood background for panels
local woodBG = AssetLoader.getBackground("wood")
love.graphics.draw(woodBG, 0, 0)
```

### **Accessing Moderna (After Export)**

**NOTE:** The Moderna PSD needs to be exported to PNG layers first!

**Steps to export Moderna assets:**
1. Open `assets/moderna/moderna_interface.psd` in GIMP or Photoshop
2. Export each layer as PNG:
   - `moderna_hp_bar.png`
   - `moderna_mana_bar.png`
   - `moderna_inventory.png`
   - `moderna_quest.png`
   - `moderna_spell_bar.png`
   - `moderna_icons.png`
3. Save to `assets/moderna/` folder
4. Update `assetloader.lua` to load these PNGs

---

## **Sprite Mapping: TextRPG → Visual Assets**

### **Enemy Mapping**

Your TextRPG enemies map to Dungeon Crawl sprites:

| TextRPG Enemy | Dungeon Crawl Sprite | File Path |
|---------------|---------------------|-----------|
| Rat | `rat.png` | `monster/animals/rat.png` |
| Goblin | `goblin.png` | `monster/goblin.png` |
| Skeleton | `skeleton.png` | `monster/undead/skeleton.png` |
| Zombie | `zombie.png` | `monster/undead/zombie.png` |
| Wolf | `wolf.png` | `monster/animals/wolf.png` |
| Spider | `spider.png` | `monster/animals/spider.png` |
| Orc | `orc.png` | `monster/orc.png` |
| Bandit | `centaur.png` (placeholder) | `monster/centaur.png` |
| Troll | `troll.png` | `monster/troll.png` |
| Vampire | `vampire.png` | `monster/undead/vampire.png` |
| Dragon | `dragon.png` | `monster/dragon.png` |

### **Item Mapping**

TextRPG items map to Dungeon Crawl item sprites:

| Item Type | Sprite Sheet |
|-----------|-------------|
| Weapons | `item/weapon.png` (32x32 grid) |
| Armor | `item/armor.png` (32x32 grid) |
| Potions | `item/potion.png` (32x32 grid) |
| Scrolls | `item/scroll.png` (32x32 grid) |
| Gold | `item/gold.png` (coin stacks) |
| Food | `item/food.png` |

### **Tile Mapping**

WorldGen grid tiles map to Dungeon Crawl terrain:

| Grid Value | Tile Type | Dungeon Crawl Sprite |
|------------|-----------|---------------------|
| 0 | Floor | `dungeon/floor/stone_2_brown.png` |
| 1 | Wall | `dungeon/wall/brick_dark.png` |
| 10 | Closed Door | `dungeon/doors/closed_door.png` |
| 11 | Open Door | `dungeon/doors/open_door.png` |
| 20 | Stairs Up | `dungeon/gateways/stairs_up.png` |
| 21 | Stairs Down | `dungeon/gateways/stairs_down.png` |

---

## **UI Layout Plan**

### **Exploration Mode**

```
┌────────────────────────────────────────────────┐
│ HP: [████████░░] 45/50  Mana: [██████░░░░] 60/100│  ← Moderna bars
│ Gold: 1,234    Level: 5                       │
├────────────────────────────────────────────────┤
│                                                 │
│         [Tile Map - Dungeon Crawl]             │  ← Top-down world
│                                                 │
│   Player sprite walks around                   │
│   Enemies visible on map                       │
│   NPCs walking on schedules                    │
│                                                 │
├────────────────────────────────────────────────┤
│ [1][2][3][4][5] Spell Quick Bar                │  ← Moderna quick bar
└────────────────────────────────────────────────┘
```

### **Combat Mode**

```
┌────────────────────────────────────────────────┐
│ BATTLE: Goblin Ambush            Round 2      │
├────────────────────────────────────────────────┤
│  [Warrior]      [Forest BG]       [Goblin 1]  │  ← Dungeon Crawl sprites
│  HP: [████░] 45/50                HP: [██░] 12/20│  ← Moderna HP bars
│                                                 │
│  [Mage]                           [Goblin 2]  │
│  HP: [██████] 30/30               HP: [████] 18/20│
│                                                 │
│  [Cleric]                         [Shaman]    │
│  HP: [███░░] 25/40                HP: [█████] 35/35│
├────────────────────────────────────────────────┤
│ Warrior's Turn:                                │  ← RPG GUI buttons
│ [Attack] [Skills] [Item] [Flee]               │
├────────────────────────────────────────────────┤
│ > Mage cast Fireball! -12 damage!             │  ← Battle log
└────────────────────────────────────────────────┘
```

### **Dialogue (RPG GUI Kit)**

```
┌────────────────────────────────────────────────┐
│  [NPC Portrait]  Elder Marcus                  │
│                                                 │
│  "Greetings, traveler. I have a quest for     │
│   you. Goblins have been raiding our farms.   │
│   Will you help us?"                           │
│                                                 │
│  [Yes, I'll help]                              │
│  [Tell me more]                                │
│  [Not now]                                     │
└────────────────────────────────────────────────┘
```

### **Inventory (Moderna + Dungeon Crawl)**

```
┌────────────────────────────────────────────────┐
│               INVENTORY                        │
├────────────────────────────────────────────────┤
│ [⚔][🛡][🧪][🧪][📜][ ][ ][ ][ ][ ]             │  ← Item icons
│ [ ][ ][ ][ ][ ][ ][ ][ ][ ][ ]                 │   (Dungeon Crawl)
│ [ ][ ][ ][ ][ ][ ][ ][ ][ ][ ]                 │
│ [ ][ ][ ][ ][ ][ ][ ][ ][ ][ ]                 │
├────────────────────────────────────────────────┤
│ Equipment:          Stats:                     │
│ Weapon: [⚔]        ATK: 25                     │
│ Armor:  [🛡]        DEF: 18                     │
│ Ring:   [ ]         HP:  45/50                 │
└────────────────────────────────────────────────┘
```

---

## **Next Steps**

### **1. Export Moderna Layers**
- Open `moderna_interface.psd` in GIMP
- Export each layer as PNG
- Save to `assets/moderna/` folder

### **2. Create Sprite Atlases**
- Build quad systems for sprite sheets
- Map TextRPG entities to visual sprites
- Create animation frames

### **3. Build Rendering System**
- Tile map renderer (Dungeon Crawl terrain)
- Entity renderer (characters, enemies, items)
- HUD overlay (Moderna bars + icons)
- UI panels (RPG GUI Kit windows)

### **4. Integration**
- Convert TextRPG exploration to visual
- Add combat visualization
- Implement inventory UI
- Add dialogue system

---

## **Credits**

**Required Attribution:**

```
ART ASSETS:

Dungeon Crawl 32x32 Tiles
License: CC0 (Public Domain)
Source: OpenGameArt.org
No attribution required (but appreciated)

RPG GUI Construction Kit v1.0
By: Matjaž Lamut
License: CC-BY 3.0
Source: OpenGameArt.org

Moderna Graphical Interface
By: Jorge Avila
License: CC-BY 3.0
Source: OpenGameArt.org
```

Add this to your game's credits screen!

---

## **Asset Statistics**

- **Total Size:** ~14 MB
- **Sprites:** 3,000+ individual sprites
- **Tilesets:** 50+ terrain types
- **Monsters:** 200+ enemy sprites
- **Items:** 500+ item icons
- **UI Elements:** Complete UI kit with buttons, panels, bars
- **Resolution:** 32×32 pixels (perfect for retro look)

---

## **Useful Commands**

```bash
# List all monster sprites
ls "assets/dungeon_crawl/Dungeon Crawl Stone Soup Full/monster/" -la

# List all floor tiles
ls "assets/dungeon_crawl/Dungeon Crawl Stone Soup Full/dungeon/floor/" -la

# List all items
ls "assets/dungeon_crawl/Dungeon Crawl Stone Soup Full/item/" -la

# Count total PNG files
find assets/dungeon_crawl/ -name "*.png" | wc -l
```

---

**Ready to build your 2D visual RPG!**
