# How to Generate Character Sprites

Since I can't create actual PNG files, you'll need to generate the sprite sheets yourself using the Universal LPC Character Generator. Here's how:

## 🎨 Step-by-Step: Generate Sprites

### **Method 1: Use the Web Generator (Easiest)**

1. **Visit the Generator:**
   - https://sanderfrenken.github.io/Universal-LPC-Spritesheet-Character-Generator/

2. **Customize Character:**
   - Click through categories on the left (Body, Hair, Torso, etc.)
   - Select race, gender, clothing, weapons
   - See preview update in real-time

3. **Download Sprite Sheet:**
   - Click "Download" button
   - Saves as `spritesheet.png` (64x64 animations)

4. **Get Credits File:**
   - Click "Get CREDITS.txt" button
   - Save this - you need it for attribution!

5. **Rename & Organize:**
   - Rename `spritesheet.png` to match your naming convention
   - Example: `human_male_body.png`, `hair_ponytail.png`, etc.

6. **Place in Game:**
   - Copy to: `LOVEGAME_work/assets/sprites/lpc/`

---

## 📦 Required Sprites for Your Game

Based on your character presets, you'll need these sprite categories:

### **Base Bodies (Required)**
Generate these first - they're the foundation:

- `human_male_body.png` - Human male base
- `human_female_body.png` - Human female base
- `elf_male_body.png` - Elf male base
- `elf_female_body.png` - Elf female base
- `dwarf_male_body.png` - Dwarf male base
- `dwarf_female_body.png` - Dwarf female base
- `orc_male_body.png` - Orc male base
- `orc_female_body.png` - Orc female base
- `skeleton_universal_body.png` - Skeleton (gender neutral)

### **Hair Styles**
- `hair_plain.png`
- `hair_ponytail.png`
- `hair_messy.png`
- `hair_mohawk.png`
- `hair_long.png`
- `hair_bangs.png`
- `hair_shoulder.png`
- `hair_pixie.png`
- `hair_princess.png`

### **Facial Hair (Males)**
- `beard_full.png`
- `beard_goatee.png`
- `mustache.png`

### **Armor/Clothing - Torso**
- `cloth_shirt.png`
- `leather_armor.png`
- `chainmail.png`
- `plate_armor.png`
- `robe_blue.png`
- `robe_red.png`
- `robe_white.png`
- `robe_green.png`
- `robe_black.png`

### **Armor/Clothing - Legs**
- `cloth_pants.png`
- `leather_pants.png`
- `chainmail_legs.png`
- `plate_legs.png`
- `robe_skirt.png`

### **Footwear**
- `boots_brown.png`
- `boots_black.png`
- `boots_metal.png`

### **Weapons**
- `sword.png`
- `axe.png`
- `dagger.png`
- `staff.png`
- `bow.png`
- `spear.png`
- `mace.png`

### **Shields**
- `shield_metal.png`
- `shield_wood.png`
- `shield_tower.png`

### **Head Gear**
- `wizard_hat.png`
- `helmet_plate.png`
- `helmet_chain.png`

### **Accessories**
- `cape_green.png`
- `cape_black.png`
- `quiver.png`

---

## 🚀 Quick Start Batch Generation

To get started quickly, generate these **5 essential sprite sets** first:

### **Set 1: Human Male Warrior**
```
Body: Human Male (light skin)
Hair: Plain (brown)
Torso: Chainmail
Legs: Chainmail Legs
Weapon: Sword
Shield: Metal Shield
```
→ Save as multiple files:
- Select ONLY body → Download → Rename to `human_male_body.png`
- Select ONLY hair → Download → Rename to `hair_plain.png`
- Select ONLY chainmail → Download → Rename to `chainmail.png`
- Select ONLY sword → Download → Rename to `sword.png`
- etc.

### **Set 2: Elf Female Mage**
```
Body: Elf Female (pale skin)
Hair: Long (silver)
Ears: Elf Ears
Torso: Blue Robe
Legs: Robe Skirt
Weapon: Staff
Head: Wizard Hat
```

### **Set 3: Dwarf Male Cleric**
```
Body: Dwarf Male (tan skin)
Hair: Shoulder Length (red-brown)
Facial: Full Beard
Torso: White Robe
Legs: Robe Skirt
Weapon: Mace
Shield: Wooden Shield
```

### **Set 4: Human Merchant**
```
Body: Human Male (medium skin)
Hair: Plain (brown)
Torso: Cloth Shirt
Legs: Cloth Pants
```

### **Set 5: Town Guard**
```
Body: Human Male (medium skin)
Hair: Plain (dark brown)
Torso: Chainmail
Legs: Chainmail Legs
Weapon: Spear
Shield: Wooden Shield
Head: Chain Helmet
```

---

## 🎯 Naming Convention

**CRITICAL:** File names must match what's in your code!

### **Format:**
```
{category}_{variant}.png
```

### **Examples:**
- Bodies: `human_male_body.png`, `elf_female_body.png`
- Hair: `hair_plain.png`, `hair_ponytail.png`
- Equipment: `chainmail.png`, `leather_armor.png`
- Weapons: `sword.png`, `bow.png`, `staff.png`

### **Special Cases:**
- Facial hair: `beard_full.png`, `mustache.png`
- Racial features: `ears_elf.png`
- Accessories: `cape_black.png`, `quiver.png`

---

## 📂 Folder Structure

Create this folder structure:

```
LOVEGAME_work/
├── assets/
│   └── sprites/
│       └── lpc/
│           ├── CREDITS.txt (REQUIRED for attribution!)
│           ├── human_male_body.png
│           ├── human_female_body.png
│           ├── elf_male_body.png
│           ├── hair_plain.png
│           ├── hair_ponytail.png
│           ├── chainmail.png
│           ├── cloth_shirt.png
│           ├── sword.png
│           ├── bow.png
│           └── ... (etc.)
```

---

## 💡 Pro Tips

### **Tip 1: Generate Layers Separately**

Instead of generating a full character and downloading once, generate EACH LAYER separately:

1. Select ONLY the body → Download → `human_male_body.png`
2. Select ONLY the hair → Download → `hair_ponytail.png`
3. Select ONLY the chainmail → Download → `chainmail.png`

This gives you maximum flexibility to mix and match!

### **Tip 2: Use Collections**

The LPC generator has "collections" - pre-made sprite bundles. Download these for quick setup:

- "Base Assets" collection - Basic bodies, hair, clothes
- "Armors" collection - All armor types
- "Weapons" collection - All weapons

### **Tip 3: Color Variations**

For items that come in multiple colors (robes, capes), generate each color separately:
- `robe_blue.png`
- `robe_red.png`
- `robe_black.png`

### **Tip 4: Batch Naming Script**

If you download many sprites, use this PowerShell script to batch rename:

```powershell
# Navigate to sprite folder
cd LOVEGAME_work\assets\sprites\lpc\

# Rename all spritesheets
Rename-Item "spritesheet.png" "human_male_body.png"
# (repeat for each file)
```

---

## 🧪 Testing Your Sprites

Once you've added sprite files, test them:

1. **Launch your game**
2. **Press V** to toggle sprite mode
3. **Look for errors** in console (missing sprites will show warnings)
4. **Move around** - character should animate
5. **Change equipment** - layers should update

### **Test Command (add to your game):**

```lua
-- In textrpg.lua or main.lua, add a test keybind:
if key == "f1" then
    -- Test all presets
    local CharacterPresets = require("characterpresets")

    for _, className in ipairs({"warrior", "mage", "rogue"}) do
        local preset = CharacterPresets.playerClasses[className]
        print("Testing preset: " .. className)
        local sprite = CharacterPresets.createCharacter("playerClasses", className, 400, 300)
        -- Will log warnings if sprites are missing
    end
end
```

---

## ❓ Troubleshooting

### **Problem: Sprites Not Showing**

1. Check file paths - should be `assets/sprites/lpc/{filename}.png`
2. Check file names - must match exactly (case-sensitive on some systems)
3. Press V to enable sprite mode
4. Check console for "Could not load sprite layer" warnings

### **Problem: Wrong Body Type Showing**

Make sure you generated the correct gender:
- `human_male_body.png` ≠ `human_female_body.png`

### **Problem: Sprite Looks Wrong/Corrupted**

- Make sure you downloaded from LPC generator (64x64 sprite sheets)
- Don't use random images - they must be LPC format
- Re-download from generator if needed

### **Problem: Missing Arms/Legs**

Body sprites MUST be complete - if you only downloaded equipment, you're missing the base!
Generate the base body first, THEN equipment layers.

---

## 📜 Attribution (REQUIRED!)

**Don't forget to include credits!**

1. Download CREDITS.txt from the LPC generator
2. Place in `assets/sprites/lpc/CREDITS.txt`
3. Add to your game's credits screen or README:

```
Character sprites use Universal LPC Spritesheet Character Generator
Licensed under CC-BY-SA 3.0 and GPL 3.0

See assets/sprites/lpc/CREDITS.txt for full attribution
```

---

## 🎁 Alternative: Download Pre-Made Collections

If you want to skip manual generation, download these pre-made LPC sprite packs:

1. **OpenGameArt LPC Collection:**
   - https://opengameart.org/content/lpc-collection

2. **LPC Base Assets:**
   - https://opengameart.org/content/liberated-pixel-cup-lpc-base-assets

3. **Community Sprite Packs:**
   - Search "LPC sprites" on OpenGameArt.org

These come with hundreds of pre-generated sprites, but you still need to rename and organize them!

---

## ✅ Checklist

- [ ] Visit LPC Character Generator website
- [ ] Generate base body sprites (human, elf, dwarf, orc, skeleton)
- [ ] Generate hair styles (at least 5 basic styles)
- [ ] Generate clothing (cloth, leather, chainmail, robes)
- [ ] Generate weapons (sword, bow, staff, dagger)
- [ ] Download CREDITS.txt
- [ ] Create `assets/sprites/lpc/` folder
- [ ] Place all PNG files in folder
- [ ] Rename files to match naming convention
- [ ] Test in-game (press V to toggle sprites)
- [ ] Check console for missing sprite warnings
- [ ] Add attribution to game credits

---

**Estimated Time:** 1-2 hours for a complete character set

**Estimated Files Needed:** 50-100 PNG files for full coverage

**File Size:** ~100KB per sprite sheet (total ~5-10 MB)
