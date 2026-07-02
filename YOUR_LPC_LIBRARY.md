# Your Complete LPC Sprite Library

Congratulations! You now have a **professional-grade sprite library** with over 22,000 assets.

---

## 📊 **What You Have**

### **By the Numbers:**
- 🖼️ **22,498 PNG sprite files**
- 👥 **1,000+ character variations** (revised basics pack)
- 🐉 **6 creature types** (dragons, birds, horses, pigs, chickens)
- 🏰 **11 environment tilesets** (interiors, desert, farm, beach, winter, etc.)
- ⚔️ **10+ weapon types** with full animations
- 📦 **Containers, boats, and objects**

### **Asset Categories:**

#### **1. Characters** (`lpc/characters/`)
- **Revised Basics** - THE definitive character pack
  - 11 skin tones
  - 18 hairstyles in 44 colors each
  - 17 clothing types in 44 colors each
  - Massive customization possibilities
- **Dark Elves** - Fantasy character variants
- **Folk Heads** - 11 unique species (goblin, troll, vampire, etc.)
- **Werewolf** - 4 werewolf variants

#### **2. Creatures** (`lpc/creatures/`)
- Red Dragon (4 variants with attacks)
- Flying Dragons (single and twin-headed)
- Birds (5 species: bluejay, eagle, cardinal, robin, sparrow)
- Horses (with riding animations)
- Pigs (pig, boar, piglet)
- Chickens (idle and walk cycles)

#### **3. Tilesets** (`lpc/tilesets/`)
- **Interiors:** Stone houses, furniture, rugs, columns
- **Desert:** Sand, cacti, ruins, dry vegetation
- **Beach:** Shells, palm trees, sand dunes
- **Farm:** Barns, silos, windmills, crops
- **Winter:** Snow tiles, pine trees, ice
- **Walls:** 300+ wall variations
- **Terrain:** Complete terrain atlas

#### **4. Objects** (`lpc/objects/`)
- Containers (boxes, barrels, crates, sacks)
- Boats (wooden vessels)
- Alchemy equipment
- Glassware and pottery

#### **5. Animations** (`lpc/animations/`)
- Extended weapon animations (7+ weapon types)
- Medieval weapons (flail, halberd, war axe)
- Push/carry animations
- Horse riding system

---

## 🎮 **How to Use**

### **Test Your Library (Right Now!)**

1. **Launch your game**
2. **Press F5** - Scans your asset library
3. **Press V** - Enables sprite mode
4. **Press F3** - Quick sprite test
5. **Press F4** - Full diagnostic

### **Create Your First Character**

The **revised basics pack** is your powerhouse. It contains:

**Location:** `assets/sprites/lpc/characters/revised_basics/`

**Structure:**
```
revised_basics/
├── body/           - 11 skin tones × 2 genders
├── hair/           - 18 styles × 44 colors
├── torso/          - 17 types × 44 colors
├── legs/           - Pants, skirts, robes
├── feet/           - Boots, shoes
└── accessories/    - Hats, capes, etc.
```

**Example Character Creation:**
```lua
local CharacterCustomizer = require("charactercustomizer")

-- Create a warrior
local warrior = CharacterCustomizer.createTemplate("human", "male", {
    hairStyle = "plain",
    hairColor = {0.3, 0.2, 0.1},  -- Brown
    torso = "chainmail",
    legs = "chainmail_legs",
    weapon = "sword",
    shield = "shield_metal"
})
```

---

## 🌟 **Asset Highlights**

### **Most Versatile Pack:**
**Revised Basics** - Start here!
- Path: `lpc/characters/revised_basics/`
- Contains: Complete character creation system
- Use for: Player characters, NPCs, customization

### **Best for Combat:**
**Extended Weapon Animations** - Full attack sequences
- Path: `lpc/animations/weapons_extended/`
- Contains: 7+ weapon types with slash/thrust/walk
- Use for: Combat system, weapon variety

### **Best for Environments:**
**Terrain Atlas** - Complete world building
- Path: `lpc/tilesets/terrain/`
- Contains: Grass, dirt, water, rocks, paths
- Use for: Building your game world

### **Best for NPCs:**
**Folk Heads** - Unique character variety
- Path: `lpc/characters/folk/`
- Contains: 11 species heads (goblin, troll, vampire, etc.)
- Use for: Creating diverse NPCs

### **Best for Boss Fights:**
**Red Dragon** - Epic enemy sprites
- Path: `lpc/creatures/dragons/`
- Contains: 4 dragon variants with attack animations
- Use for: Boss encounters, flying enemies

---

## 📚 **Documentation Files**

All documentation is in: `assets/sprites/lpc/`

### **MANIFEST.md** (24 KB)
**What:** Complete asset catalog
**Contains:**
- Detailed descriptions of every pack
- File locations and contents
- LÖVE2D integration examples
- Animation layouts and specifications
- Usage tips and common issues

### **CREDITS.txt** (14 KB)
**What:** Attribution for all artists
**Contains:**
- All 26 asset pack authors
- License information
- Usage requirements
- Original URLs

**IMPORTANT:** You MUST include this file with your game or provide equivalent attribution.

### **README.md** (7 KB)
**What:** Quick start guide
**Contains:**
- Directory overview
- What's included summary
- Quick integration tips
- Getting started checklist

---

## 🎨 **Integration Examples**

### **Example 1: Load a Character Sprite**

```lua
-- In your game code
love.graphics.setDefaultFilter("nearest", "nearest")  -- Pixel-perfect rendering

-- Load human male body
local body = love.graphics.newImage("assets/sprites/lpc/characters/revised_basics/body/male/light.png")

-- Create character quad (64x64 pixels)
local quad = love.graphics.newQuad(0, 128, 64, 64, body:getWidth(), body:getHeight())
-- This gets the first frame of the walk animation (row 2, Y=128)

-- Draw it
love.graphics.draw(body, quad, 100, 100, 0, 2, 2)  -- Scaled 2x for visibility
```

### **Example 2: Create a Walking Animation**

```lua
-- LPC walk animation is on row 2 (Y = 128)
-- Has 9 frames walking south

local walkFrames = {}
for i = 0, 8 do  -- 9 frames (0-8)
    local x = i * 64
    local y = 128  -- Row 2
    walkFrames[i+1] = love.graphics.newQuad(x, y, 64, 64, body:getWidth(), body:getHeight())
end

-- In your update loop:
currentFrame = (currentFrame % 9) + 1
love.graphics.draw(body, walkFrames[currentFrame], x, y, 0, 2, 2)
```

### **Example 3: Layer Multiple Sprites**

```lua
-- Build a complete character
local layers = {
    love.graphics.newImage("assets/sprites/lpc/characters/revised_basics/body/male/light.png"),
    love.graphics.newImage("assets/sprites/lpc/characters/revised_basics/hair/plain/male/brown.png"),
    love.graphics.newImage("assets/sprites/lpc/characters/revised_basics/torso/shirts/longsleeve/male/white.png"),
    love.graphics.newImage("assets/sprites/lpc/characters/revised_basics/legs/pants/male/white.png")
}

-- Draw all layers at same position
for _, layer in ipairs(layers) do
    love.graphics.draw(layer, quad, x, y, 0, 2, 2)
end
```

---

## ⌨️ **Keyboard Shortcuts**

**Testing:**
- **F3** - Quick sprite check (6 essential files)
- **F4** - Full diagnostic (sprite system)
- **F5** - Asset library scan (NEW! Shows what you have)

**In-Game:**
- **V** - Toggle sprite/ASCII mode

---

## 🚀 **Quick Start Guide**

### **Day 1: Test & Explore**
1. ✅ Press **F5** to see your assets
2. ✅ Read `MANIFEST.md` to understand what you have
3. ✅ Press **V** to enable sprites
4. ✅ Look through `lpc/characters/revised_basics/` folder

### **Day 2: Basic Integration**
1. ✅ Use existing character customization system
2. ✅ Update sprite paths to point to revised_basics
3. ✅ Test creating a character
4. ✅ Verify animations work

### **Day 3: Expand**
1. ✅ Add creatures (dragons, horses, etc.)
2. ✅ Add environment tiles
3. ✅ Add weapon animations
4. ✅ Test full game with sprites

---

## 📋 **File Paths Reference**

**Character Bodies:**
```
assets/sprites/lpc/characters/revised_basics/body/{gender}/{skin_tone}.png
```

**Hairstyles:**
```
assets/sprites/lpc/characters/revised_basics/hair/{style}/{gender}/{color}.png
```

**Clothing:**
```
assets/sprites/lpc/characters/revised_basics/torso/{type}/{gender}/{color}.png
```

**Weapons:**
```
assets/sprites/lpc/animations/weapons_extended/{weapon}/{animation}.png
```

**Tilesets:**
```
assets/sprites/lpc/tilesets/{environment}/{tile}.png
```

**Creatures:**
```
assets/sprites/lpc/creatures/{type}/{variant}.png
```

---

## 💡 **Pro Tips**

### **Tip 1: Start with Revised Basics**
This pack alone has everything you need for character creation. Master it first before exploring other packs.

### **Tip 2: Use Standard LPC Layout**
All LPC sprites follow the same animation layout:
- Row 0 (Y=0): Spellcast
- Row 1 (Y=64): Thrust
- Row 2 (Y=128): Walk
- Row 3 (Y=192): Slash
- Row 4 (Y=256): Shoot
- Row 5 (Y=320): Hurt

### **Tip 3: Layer Order Matters**
When stacking sprites:
1. Body (bottom)
2. Eyes
3. Facial hair
4. Hair
5. Clothing (feet → legs → torso → hands)
6. Accessories (head, back)
7. Weapons (top)

### **Tip 4: Test Individual Sprites First**
Before building complex characters, test loading individual sprites to ensure paths are correct.

### **Tip 5: Read the MANIFEST**
The MANIFEST.md file has detailed info about every pack, including:
- What's inside
- How to use it
- Special notes
- Integration examples

---

## ✅ **Next Steps**

1. **Explore your library:**
   - Browse `lpc/characters/revised_basics/`
   - Look at creature sprites
   - Check out tilesets

2. **Update your sprite system:**
   - Point character customizer to revised_basics
   - Test character creation
   - Verify animations work

3. **Build your first scene:**
   - Use tileset for environment
   - Add character sprites
   - Add creature sprites
   - See it all work together!

4. **Remember attribution:**
   - Include CREDITS.txt in your game
   - Add credits screen
   - Thank the artists!

---

## 🎉 **You're All Set!**

You now have:
- ✅ **22,498 sprites** ready to use
- ✅ **Complete documentation**
- ✅ **Organized file structure**
- ✅ **Integration examples**
- ✅ **Test utilities** (F3, F4, F5)

**No more downloading needed!** You have enough assets to:
- Create thousands of unique characters
- Build complete game environments
- Add varied creatures and enemies
- Implement full combat animations
- Make a complete RPG

**Start building your game!** 🚀

Press **F5** to see your new asset library in action!
