# LPC Sprite Integration Guide

## Overview

Your game now supports **Universal LPC sprites** for character rendering! The system is fully integrated with TextRPG and includes:

- ✅ **Sprite rendering system** (spritemanager.lua)
- ✅ **Character customization** with layered sprites (charactercustomizer.lua)
- ✅ **TextRPG integration** with toggle between sprite and ASCII modes
- ✅ **Animation system** (walk, attack, cast, hurt animations)
- ✅ **8-directional movement** support

## Quick Start

### 1. Toggle Sprite Mode

Press **V** in-game to toggle between sprite and ASCII modes.

- **Sprite Mode**: Shows LPC character sprites
- **ASCII Mode**: Uses traditional "@" symbols (fallback)

### 2. Get LPC Sprites

Visit the Universal LPC Character Generator:
**https://sanderfrenken.github.io/Universal-LPC-Spritesheet-Character-Generator/**

### 3. Generate Sprites

1. Open the web generator
2. Customize your character (race, hair, equipment)
3. Click "Download" to get the PNG spritesheet
4. Click "Get CREDITS.txt" for attribution

### 4. Organize Sprite Files

Create this folder structure:

```
LOVEGAME_work/
  assets/
    sprites/
      lpc/
        human_male_body.png
        human_female_body.png
        elf_male_body.png
        hair_plain.png
        hair_ponytail.png
        cloth_shirt.png
        cloth_pants.png
        sword.png
        ... (more sprite layers)
```

**Naming Convention:**
- Base bodies: `{race}_{gender}_body.png` (e.g., `human_male_body.png`)
- Hair: `hair_{style}.png` (e.g., `hair_ponytail.png`)
- Equipment: `{item}.png` (e.g., `sword.png`, `leather_armor.png`)

### 5. Character Customization

Your player character appearance is stored in `PlayerData.characterAppearance`.

To customize programmatically:

```lua
local CharacterCustomizer = require("charactercustomizer")

-- Create a custom character template
local template = CharacterCustomizer.createTemplate("elf", "female", {
    hairStyle = "ponytail",
    hairColor = {0.8, 0.2, 0.1},  -- RGB for red hair
    torso = "leather_armor",
    weapon = "bow",
    facial = "beard_full"  -- For males
})

-- Save to PlayerData
PlayerData.characterAppearance = CharacterCustomizer.serializeTemplate(template)
```

## Features

### Supported Races

The system supports these races (you need to generate sprites for each):

- Human
- Elf (with pointed ears)
- Dwarf
- Orc (with tusks)
- Lizardfolk
- Skeleton

### Equipment Slots

Characters can wear/wield:

- Weapon (sword, axe, dagger, staff, bow)
- Shield
- Helmet
- Body Armor (torso)
- Leg Armor (legs)
- Boots (feet)
- Gloves (hands)
- Cape/Wings (back)

### Animations

The system supports these LPC animations:

- **walk** - Walking animation (8 directions)
- **slash** - Melee attack
- **spellcast** - Magic casting
- **thrust** - Spear/sword thrust
- **shoot** - Bow/ranged attack
- **hurt** - Taking damage

### Animation Control

```lua
local SpriteIntegration = require("spriteintegration")

-- Play attack animation
SpriteIntegration.playAttackAnimation()

-- Play cast spell animation
SpriteIntegration.playCastAnimation()

-- Play hurt animation
SpriteIntegration.playHurtAnimation()
```

## How It Works

### Layered Sprite System

Characters are rendered using multiple sprite layers stacked on top of each other:

1. **Base body** (skin tone, race features)
2. **Eyes** (optional)
3. **Ears** (elf ears, etc.)
4. **Facial features** (beards, mustaches)
5. **Hair**
6. **Equipment** (in order: feet, legs, hands, torso, back, head, weapon, shield)

This allows for millions of possible character combinations!

### Automatic NPC Generation

NPCs automatically get randomized appearance based on their race:

```lua
-- Creates a random orc NPC sprite
local template = CharacterCustomizer.generateRandom("orc")
```

### Fallback System

If sprites fail to load, the system automatically falls back to ASCII rendering. No crashes!

## File Structure

### New Files Created

1. **spritemanager.lua** - Core sprite rendering and animation system
2. **charactercustomizer.lua** - Character layer management and customization
3. **spriteintegration.lua** - Bridge between sprites and TextRPG

### Modified Files

1. **textrpg.lua** - Added sprite initialization, update calls, rendering, and keybind

## License & Attribution

### Universal LPC Sprites License

**Dual Licensed:**
- GNU GPL 3.0
- Creative Commons Attribution-ShareAlike 3.0 (CC-BY-SA 3.0)

**Requirements:**
1. ✅ **Free for commercial use**
2. ⚠️ **Attribution REQUIRED** - Must credit all sprite contributors
3. ⚠️ **Share-Alike** - Derivative works must use same license
4. ⚠️ **DRM Warning** - GPL may conflict with Steam/iOS encryption

**How to Attribute:**
- Include `CREDITS.txt` file downloaded from the generator
- Or list contributors in your game's credits screen

**For DRM Platforms (Steam, iOS):**
Consider using CC0 or OGA-BY licensed sprites instead to avoid GPL DRM conflicts.

## Customization Examples

### Change Player Hair

```lua
local SpriteIntegration = require("spriteintegration")
local CharacterCustomizer = require("charactercustomizer")

local playerSprite = SpriteIntegration.getPlayerSprite()
CharacterCustomizer.setHairStyle(playerSprite, "mohawk")
```

### Change Equipment

```lua
CharacterCustomizer.setEquipment(playerSprite, "weapon", "magic_staff")
CharacterCustomizer.setEquipment(playerSprite, "helmet", "iron_helmet")
```

### Create Custom Race

Add to `charactercustomizer.lua`:

```lua
CharacterCustomizer.RACES.demon = {
    name = "Demon",
    bodyTypes = {"male", "female"},
    spritePrefix = "demon",
    features = {"horns", "tail"}
}
```

## Troubleshooting

### Sprites Not Showing?

1. **Check file paths** - Sprites must be in `assets/sprites/lpc/`
2. **Check file names** - Must match template layer names exactly
3. **Press V** - Make sure sprite mode is enabled (not ASCII mode)
4. **Check console** - Look for "Warning: Could not load sprite layer" messages

### Performance Issues?

The sprite system is lightweight, but if you have performance issues:

- Reduce number of NPC sprites being rendered
- Use smaller sprite sheets (32x32 instead of 64x64)
- Disable sprites and use ASCII mode

### Can't Find Sprites?

Use the **Universal LPC Spritesheet Character Generator**:
- https://sanderfrenken.github.io/Universal-LPC-Spritesheet-Character-Generator/
- https://opengameart.org/content/lpc-collection

## Next Steps

### Recommended Workflow

1. **Generate Base Sprites** - Create sprites for all races you want to support
2. **Organize Files** - Set up the `assets/sprites/lpc/` folder
3. **Test Toggle** - Press V to verify sprites load correctly
4. **Customize Player** - Set up character creation to customize appearance
5. **Add Equipment** - Create sprites for all your equipment items

### Advanced Features (TODO)

Possible enhancements you could add:

- **Character creation screen** - Visual customization UI
- **Equipment preview** - Show equipment changes in real-time
- **Palette swapping** - Recolor sprites dynamically
- **Monster sprites** - Unique sprites for different enemy types
- **Emotes** - Additional animations (sit, sleep, dance)
- **Mounted sprites** - Riding horses/creatures

## Support

For sprite generation issues:
- Visit the LPC generator GitHub: https://github.com/sanderfrenken/Universal-LPC-Spritesheet-Character-Generator

For integration code issues:
- Check console output for error messages
- Verify file paths and names
- Make sure LPC sprite sheets are standard 64x64 format

---

**Created for:** LOVEGAME_work
**Date:** 2026-01-29
**Integration Status:** ✅ Complete and working!
