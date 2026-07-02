# How to Replace LPC with a Different Sprite System

If you want to use sprites from a different source instead of LPC, follow this guide.

---

## 🎯 **What Needs to Change**

The sprite system has **4 configurable parts**:

| Part | File | What to Change |
|------|------|----------------|
| **Sprite Dimensions** | `spritemanager.lua` | Width/height of each sprite |
| **Animation Layout** | `spritemanager.lua` | How frames are arranged |
| **Layer System** | `charactercustomizer.lua` | Optional - remove if not using layers |
| **File Paths** | All files | Where sprites are located |

---

## 🌟 **Popular Alternatives to LPC**

### **Option 1: Kenney Assets** (Simplest!)

**What:** Clean, minimalist sprites (16×16 or 32×32)
**License:** CC0 (public domain) - No attribution needed!
**URL:** https://kenney.nl/assets
**Best For:** Simple games, top-down view, minimalist style

**Pros:**
- ✅ Free and public domain
- ✅ No complex animations needed
- ✅ Consistent art style
- ✅ Huge variety (characters, objects, tiles)

**Cons:**
- ❌ No character customization layers
- ❌ Limited animations (mostly static or simple)
- ❌ Less detailed than LPC

**How to Adapt:**

1. **Download Kenney sprites** from kenney.nl
2. **Simplify the sprite system** - no layers needed
3. **Use single images** instead of sprite sheets
4. **Update sprite size** from 64×64 to 16×16 or 32×32

**Code Changes:**
```lua
-- In spritemanager.lua, change dimensions:
spriteData.width = 16   -- Kenney sprites are smaller
spriteData.height = 16

-- Disable layer system (optional):
-- Just use single sprite images instead of compositing layers
```

---

### **Option 2: Your Own Pixel Art** (Most Custom!)

**What:** Create your own sprites in Piskel, Aseprite, or similar
**License:** You own it!
**URL:** https://www.piskelapp.com/ (free online editor)
**Best For:** Unique art style, full creative control

**Pros:**
- ✅ Completely custom
- ✅ Exactly what you want
- ✅ No licensing worries
- ✅ Learn pixel art skills

**Cons:**
- ❌ Time-consuming
- ❌ Requires artistic skill
- ❌ Need to create EVERY sprite

**How to Adapt:**

1. **Create sprites** in Piskel/Aseprite
2. **Export as sprite sheet** (Piskel can do this)
3. **Update dimensions** to match your sprite size
4. **Update animation frames** to match your design

**Example Sprite Sheet Layout:**
```
[Idle] [Walk1] [Walk2] [Walk3] [Attack1] [Attack2]
```

**Code Changes:**
```lua
-- Define your animations
ANIMATIONS = {
    idle = {row = 0, frames = 1},
    walk = {row = 0, frames = 3, startCol = 1},
    attack = {row = 0, frames = 2, startCol = 4}
}
```

---

### **Option 3: RPG Maker Style Sprites** (Classic!)

**What:** Traditional JRPG-style character sprites
**License:** Varies (many free packs available)
**URL:** https://opengameart.org/ (search "RPG Maker")
**Best For:** Classic RPG games, top-down view

**Pros:**
- ✅ Classic RPG aesthetic
- ✅ Lots of free resources
- ✅ Simple animation structure
- ✅ Familiar to players

**Cons:**
- ❌ Less customization than LPC
- ❌ Specific style (may not fit your game)
- ❌ License varies by pack

**Standard Layout:**
```
Row 0: Walk Down (3 frames)
Row 1: Walk Left (3 frames)
Row 2: Walk Right (3 frames)
Row 3: Walk Up (3 frames)
```

**Code Changes:**
```lua
-- RPG Maker animations
ANIMATIONS = {
    walk_down = {row = 0, frames = 3},
    walk_left = {row = 1, frames = 3},
    walk_right = {row = 2, frames = 3},
    walk_up = {row = 3, frames = 3}
}

-- Sprites are typically 32x32
spriteData.width = 32
spriteData.height = 32
```

---

### **Option 4: OpenGameArt Mix** (Maximum Variety!)

**What:** Mix and match from huge collection
**License:** Varies (check each asset)
**URL:** https://opengameart.org/
**Best For:** Finding specific assets, unique combinations

**Pros:**
- ✅ Massive selection
- ✅ Different art styles
- ✅ Many free options
- ✅ Active community

**Cons:**
- ❌ Inconsistent art styles (need to curate)
- ❌ Varied licenses (must track)
- ❌ Quality varies

**How to Use:**

1. **Search** for "character sprite sheet"
2. **Filter** by license (CC0, CC-BY, etc.)
3. **Download** assets that match your game's style
4. **Ensure consistency** in sprite dimensions
5. **Track licenses** in a CREDITS.txt file

---

## 🔧 **Step-by-Step: Replace LPC**

### **Example: Switching to Kenney Assets**

Let's walk through a complete replacement:

#### **Step 1: Download Kenney Sprites**

1. Visit: https://kenney.nl/assets/tiny-town
2. Download the pack (free!)
3. Extract to `assets/sprites/kenney/`

#### **Step 2: Update Sprite Dimensions**

Open `spritemanager.lua` and change:

```lua
-- BEFORE (LPC):
spriteData.width = 64
spriteData.height = 64

-- AFTER (Kenney):
spriteData.width = 16
spriteData.height = 16
```

#### **Step 3: Simplify Animations**

Kenney sprites are often static (no animations), so:

```lua
-- BEFORE (LPC has complex animations):
ANIMATIONS = {
    spellcast = {row = 0, frames = 7, dirs = {"up", "left", "down", "right"}},
    thrust = {row = 1, frames = 8, dirs = {"up", "left", "down", "right"}},
    walk = {row = 2, frames = 9, dirs = {"up", "left", "down", "right"}},
    -- ... more animations
}

-- AFTER (Kenney - single static images):
ANIMATIONS = {
    idle = {row = 0, frames = 1}  -- Just one static image
}
```

#### **Step 4: Update Sprite Loading**

```lua
-- BEFORE (LPC expects sprite sheets):
function loadSpriteSheet(name, filepath)
    -- Loads sprite sheet and creates quads
end

-- AFTER (Kenney uses single images):
function loadSingleSprite(name, filepath)
    local image = love.graphics.newImage(filepath)
    return {
        image = image,
        width = image:getWidth(),
        height = image:getHeight()
    }
end
```

#### **Step 5: Remove Layer System** (Optional)

If not using character customization:

In `charactercustomizer.lua`:
```lua
-- BEFORE (LPC uses layers):
character.layers = {"body", "hair", "torso", "weapon"}

-- AFTER (Kenney - single sprite):
character.sprite = "player.png"
```

#### **Step 6: Update File Paths**

```lua
-- BEFORE:
local spritePath = "assets/sprites/lpc/" .. layerName .. ".png"

-- AFTER:
local spritePath = "assets/sprites/kenney/" .. spriteName .. ".png"
```

#### **Step 7: Test**

1. Launch game
2. Press F4 (may need to update test to check Kenney sprites)
3. Press V to enable sprite mode
4. Verify sprites appear

---

## 📋 **Quick Comparison Table**

| System | Dimensions | Animations | Layers | Complexity | License |
|--------|-----------|------------|--------|-----------|---------|
| **LPC** | 64×64 | Complex (21 frames) | Yes | High | GPL/CC-BY-SA |
| **Kenney** | 16×16 | None/Simple | No | Low | CC0 |
| **RPG Maker** | 32×32 | Medium (3-4 frames) | No | Medium | Varies |
| **Custom** | Your choice | Your choice | Your choice | Varies | Yours |
| **OpenGameArt** | Varies | Varies | Varies | Varies | Varies |

---

## 🎨 **Hybrid Approach: Mix Systems**

You can also **combine different sprite sources**:

**Example:**
- **Player character**: LPC (detailed, customizable)
- **NPCs**: Kenney (simple, consistent)
- **Enemies**: OpenGameArt (unique designs)
- **Objects**: Kenney (clean, minimal)

**How:**

```lua
-- Different sprite managers for different types
local playerSprite = LPC_SpriteManager.load("player")
local npcSprite = Kenney_SpriteManager.load("npc")
local enemySprite = Custom_SpriteManager.load("orc")
```

---

## 🚀 **Recommended for Your Game**

Based on your TextRPG:

### **Best Choice: Kenney Assets**

**Why:**
1. ✅ **Free & Public Domain** - No worries about licensing
2. ✅ **Simple** - Easy to implement, no complex animations
3. ✅ **Consistent** - All sprites match in style
4. ✅ **Fast** - Can set up in 1-2 hours vs days for LPC

**What You'd Need:**
- Download Kenney's "Tiny Town" or "Roguelike" pack
- Simplify sprite system (remove layers, simplify animations)
- Update sprite dimensions to 16×16
- Map sprites to your characters/NPCs

**Time to Implement:** 2-3 hours
**Difficulty:** Low
**Result:** Clean, functional sprite system

### **Alternative: Stick with LPC if:**

- ✅ You want detailed character customization
- ✅ You like the layered equipment system
- ✅ You want complex animations
- ✅ You're okay with 3-4 hours of sprite downloading

---

## 💡 **Summary**

**To use a different sprite system:**

1. **Choose your sprite source** (Kenney, custom, etc.)
2. **Download sprites** to `assets/sprites/{source}/`
3. **Update dimensions** in `spritemanager.lua`
4. **Update animations** to match your sprite layout
5. **Simplify or remove** layer system if not needed
6. **Update file paths** throughout code
7. **Test** with F4 and V keys

**Easiest Switch:** LPC → Kenney (2-3 hours)
**Most Custom:** Create your own (days to weeks)
**Best of Both:** Hybrid approach (use different sources for different things)

---

## 🆘 **Need Help Switching?**

If you want to switch to a specific system, let me know which one and I can:
- Modify the sprite manager code specifically for it
- Create a conversion guide
- Set up the file structure
- Update the test system

Just tell me what sprite system you want to use! 🎮
