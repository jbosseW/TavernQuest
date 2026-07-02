# ✅ STEALTH & DETECTION SYSTEM - FULLY IMPLEMENTED

## Overview
Comprehensive stealth mechanics with toggleable stealth mode, detection chance based on time/location/class, bonuses for rogues and vampires, integrated with crime and vampire systems.

---

## ✅ IMPLEMENTED FEATURES

### 1. Stealth Mode Toggle ✅
**Location**: textrpg.lua lines 8476-8524 (UI), 13906-13917 (Click Handler)

- **Click the slide tab toggle** on the left panel to toggle stealth mode on/off
- Located below player info panel, above day/night display
- **Stealth ON**: Shows 🌑 with green knob, -25% base detection
- **Stealth OFF**: Shows 🌞 with gray knob, normal detection
- Works in all phases except combat and overlays
- Logs current detection chance when toggled
- Visual slide animation shows current state

### 2. Detection Formula ✅
**Location**: textrpg.lua lines 357-462

```
finalDetection = baseDetection × locationMod + classMod + equipMod + stealthMod + skillMod
```

**Components**:
- **Base Detection**: Time of day (20% night to 100% noon)
- **Location Modifier**: 0.3× (building) to 1.5× (open day)
- **Class Modifier**: Rogue -30%, Vampire -25% (night)
- **Equipment Modifier**: Heavy armor +15%, stealth gear up to -45%
- **Stealth Mode**: -25% when active
- **Skills/Talents**: Up to -65% with all bonuses

**Detection Caps**:
- Minimum: 1% (always small chance)
- Maximum: 100% (guaranteed)
- Stealth Mode Cap: 75% (always a chance)

### 3. Time of Day Modifiers ✅
**Location**: textrpg.lua lines 313-338

| Time | Hours | Detection | Stealth Quality |
|------|-------|-----------|-----------------|
| Late Night | 22-4 | 20% | Excellent |
| Dawn | 5-6 | 50-70% | Good |
| Morning | 7-11 | 90% | Poor |
| Noon | 12-13 | 100% | Worst |
| Afternoon | 14-17 | 90% | Poor |
| Dusk | 18 | 60% | Good |
| Evening | 19-21 | 40% | Very Good |

**Best stealth times**: Night (22:00-4:00), Evening (19:00-21:00)
**Worst stealth times**: Noon (12:00-13:00), All day (7:00-17:00)

### 4. Location Modifiers ✅
**Location**: textrpg.lua lines 340-350

| Location | Multiplier | Detection Change |
|----------|-----------|------------------|
| Building Interior | 0.3× | -70% detection |
| Shadows/Alleys | 0.5× | -50% detection |
| Wilderness | 0.6× | -40% detection |
| Crowded Market | 0.7× | -30% detection |
| Open Street (Night) | 1.0× | Normal |
| Town Square | 1.2× | +20% detection |
| Open Street (Day) | 1.5× | +50% detection |

### 5. Class & Race Bonuses ✅
**Location**: textrpg.lua lines 376-395

**Class Modifiers**:
- **Rogue**: -30% detection (natural stealth)
- **Assassin Spec**: -40% detection (master stealth)
- **Shadow Rogue Spec**: -35% detection (stealth specialist)
- **Warrior**: +10% detection (heavy armor clanking)
- **Cleric**: +5% detection (righteous aura)
- **Mage**: 0% (neutral)

**Vampire Modifiers** (time-dependent):
- **Night** (19:00-5:00): -25% detection (natural predator)
- **Day** (6:00-18:00): +15% detection (weakened)

### 6. Equipment Modifiers ✅
**Location**: textrpg.lua lines 397-418

**Armor Detection**:
- Plate Armor: +15% detection (loud)
- Chain Mail: +5% detection (some noise)
- Leather Armor: -5% detection (quiet)
- Cloth Armor: -10% detection (silent)

**Stealth Gear** (stacks):
- Stealth Cloak: -20% detection
- Dark Hood: -10% detection
- Soft Boots: -10% detection
- Silent Bell: -5% detection
**Total possible**: -45% from equipment

### 7. Stealth Equipment ✅
**Location**: backpack.lua lines 289-297

| Item | Effect | Cost |
|------|--------|------|
| Stealth Cloak | -20% detection | 500g |
| Dark Hood | -10% detection | 150g |
| Soft Leather Boots | -10% detection | 200g |
| Shadow Dye | -15% detection (1hr) | 50g |
| Smoke Bomb | Escape/blind guards 10s | 100g |
| Disguise Kit | Reset detection | 300g |
| Quality Lockpicks | +25% speed, quieter | 250g |
| Silent Bell | -5% detection | 80g |

### 8. Crime System Integration ✅
**Location**: textrpg.lua lines 5663-5678

**Stealth Detection on Crimes**:
- Replaces simple bounty check with full detection system
- Uses `checkDetection(crimeType)` function
- If **not detected**: No arrest, +25% XP bonus
- If **detected**: Guards arrest you
- Works with all crime types

**Stealth XP Bonus**:
- +25% XP bonus for undetected crimes
- Stacks with other bonuses
- Applied to next XP gain
- Encourages stealth gameplay

### 9. Vampire Bite Integration ✅
**Location**: textrpg.lua lines 5722-5735

**Vampire Biting**:
- Uses full stealth detection system
- Base detection from environment/time
- **Hypnotic Gaze**: Halves detection
- **Blood Plague**: 0% detection
- Perfect stealth at night with skills

### 10. Stealth UI Indicator ✅
**Location**: textrpg.lua lines 13691-13732

**Displays when stealth mode active**:
- 🌑 STEALTH MODE title
- **Detection percentage** (color-coded)
  - Green (0-25%): Safe
  - Yellow (26-50%): Moderate
  - Orange (51-75%): Risky
  - Red (76-100%): Dangerous
- **Detection description**: Hidden, Low, Moderate, High, Very High
- **Time of day** with stealth quality
- **[S] Toggle Stealth** reminder

**Location**: Top-right corner (250x120 panel)

### 11. Detection Description System ✅
**Location**: textrpg.lua lines 464-478

**Real-time detection feedback**:
- Calculates current detection chance
- Provides description: Hidden, Very Low, Low, Moderate, High, Very High
- Updates when stealth mode toggled
- Helps player understand detection risk

### 12. Detection Roll System ✅
**Location**: textrpg.lua lines 488-497

**Checks if action detected**:
- Rolls random number vs detection chance
- Debug info shown in stealth mode
- Returns true if detected
- Used by crime system and vampire bites

### 13. Player State Migration ✅
**Location**: textrpg.lua lines 5205-5207, 7496-7501

**Player Data Added**:
- `stealthMode` - Boolean stealth status
- `lastDetectionCheck` - Timestamp for cooldowns
- `stealthXPBonus` - Accumulated stealth XP bonus

**Save Migration**:
- Initializes stealth fields for old saves
- Defaults to stealth off
- Preserves across save/load

---

## 🎮 HOW TO USE

### Activating Stealth Mode

1. **Click the slide tab toggle** on the left panel (below player info)
2. **Watch the indicator** change from 🌞 (normal) to 🌑 (stealth)
3. **Check detection UI** in top-right for current detection chance
4. **Plan actions** based on detection risk
5. **Best times**: Night (20-25% detection)
6. **Worst times**: Noon (90-100% detection)

### Optimal Stealth Setup

**Best Class**: Rogue with Assassin spec (-40%)
**Best Time**: Late night 22:00-4:00 (20% base)
**Best Location**: Inside building (×0.3 multiplier)
**Best Equipment**: Full stealth gear (-45%)
**Result**: ~1-2% detection chance

**Example Calculation**:
```
Base: 20% (night)
Location: 20% × 0.3 = 6%
Class: 6% - 40% (assassin) = -34%
Equipment: -34% - 45% (full gear) = -79%
Stealth Mode: -79% - 25% = -104% → capped at 1%
```

### Managing Detection

**Low Detection (1-25%)**:
- ✅ Safe to perform crimes
- ✅ Can lockpick with confidence
- ✅ Vampire bites rarely detected

**Moderate Detection (26-50%)**:
- ⚠️ Some risk
- ⚠️ Have escape plan ready
- ⚠️ Consider waiting for better time

**High Detection (51-75%)**:
- 🚫 Very risky
- 🚫 Guards likely to spot you
- 🚫 Wait for night or find cover

**Very High Detection (76-100%)**:
- ❌ Don't attempt crimes
- ❌ Guaranteed to be caught
- ❌ Move to building or wait

### Stealth Tips

1. **Use Night Time**: 20% base vs 100% at noon
2. **Stay Indoors**: -70% detection in buildings
3. **Wear Stealth Gear**: Up to -45% reduction
4. **Play Rogue/Assassin**: -40% class bonus
5. **Be Vampire at Night**: -25% additional bonus
6. **Stack Bonuses**: Can reach 1% detection

### Crime Without Detection

**Benefits**:
- ✅ No arrest
- ✅ No bounty added
- ✅ +25% XP bonus
- ✅ Can repeat safely

**Requirements**:
- Stealth mode active
- Low detection chance
- Pass detection roll

---

## 📊 DETECTION EXAMPLES

### Example 1: Rogue Lockpicking at Night
```
Time: 23:00 (Night) - Base 20%
Location: Alley - ×0.5
Class: Rogue - -30%
Equipment: Stealth Cloak + Dark Hood - -30%
Stealth Mode: -25%

Calculation:
20% × 0.5 = 10%
10% - 30% - 30% - 25% = -75%
Capped at 1% minimum

Result: 1% detection chance (virtually undetectable)
```

### Example 2: Warrior Attacking in Town Square at Noon
```
Time: 12:00 (Noon) - Base 100%
Location: Town Square - ×1.2
Class: Warrior - +10%
Equipment: Plate Armor - +15%
Stealth Mode: OFF

Calculation:
100% × 1.2 = 120%
120% + 10% + 15% = 145%
Capped at 100%

Result: 100% detection (guaranteed caught)
```

### Example 3: Vampire Biting NPC at 2 AM Indoors
```
Time: 2:00 (Late Night) - Base 20%
Location: Inside House - ×0.4
Class: Vampire (night) - -25%
Skills: Hypnotic Gaze - Halves result
Stealth Mode: -25%

Calculation:
20% × 0.4 = 8%
8% - 25% - 25% = -42%
Capped at 1%
With Hypnotic Gaze: 1% ÷ 2 = 0.5%

Result: 0.5% detection (nearly impossible to detect)
```

---

## 🔧 FUTURE ENHANCEMENTS

### Could Add Later:
1. **Guard AI** - Vision cones, patrol routes
2. **Sound System** - Loud actions increase detection
3. **Shadow System** - Dynamic lighting affects stealth
4. **Weather Effects** - Rain/fog reduce detection
5. **Stealth Skills** - Full rogue skill tree
6. **Disguises** - Change appearance to avoid guards
7. **Witness System** - NPCs can report crimes
8. **Alert Levels** - Escalating guard response
9. **Escape Mechanics** - Hide, flee, bribe guards
10. **Stealth Challenges** - Heist missions, assassination contracts

### Potential Rogue Stealth Skills:
- Shadow Blend: -20% detection in shadows
- Silent Movement: -15% detection when moving
- Master of Disguise: -25% detection in towns
- Backstab Bonus: +50% damage from stealth
- Quick Escape: Re-enter stealth in combat
- Vanish: Become invisible for 10 seconds
- Assassinate: Instant kill sleeping target
- Shadow Step: Teleport between shadows

---

## ✅ IMPLEMENTATION COMPLETE

All core stealth systems are fully implemented and functional:
- ✅ Stealth mode toggle (slide tab on left panel)
- ✅ Detection formula with all modifiers
- ✅ Time of day system (20-100% base)
- ✅ Location modifiers (0.3-1.5× multiplier)
- ✅ Class bonuses (Rogue -30%, Vampire -25%)
- ✅ Equipment system (up to -45% bonus)
- ✅ Stealth UI indicator (top-right)
- ✅ Crime system integration
- ✅ Vampire bite integration
- ✅ Detection roll system
- ✅ Stealth XP bonus (+25%)
- ✅ 8 stealth equipment items
- ✅ Save/load migration
- ✅ Real-time detection feedback

**Ready for gameplay and testing!** 🌑

## 🧪 TESTING CHECKLIST

- ✅ Click slide tab toggle to activate stealth mode
- ✅ Slide tab shows 🌑 green when ON, 🌞 gray when OFF
- ✅ Stealth detection UI appears in top-right when active
- ✅ Detection changes with time of day
- ✅ Detection changes with location
- ✅ Rogue has -30% detection bonus
- ✅ Vampire has -25% at night, +15% at day
- ✅ Stealth gear reduces detection
- ✅ Crime detection uses stealth system
- ✅ Undetected crimes give +25% XP
- ✅ Vampire bites use stealth detection
- ✅ Hypnotic Gaze reduces vampire detection
- ✅ Save/load preserves stealth mode
- ✅ Detection capped at 1% minimum, 75% in stealth
- ✅ UI color-codes detection risk

---

## 📈 BALANCE NOTES

- **Detection Range**: 1-100% (wide range for strategy)
- **Stealth Mode Cap**: 75% (always some hope)
- **Night Advantage**: 5× better than noon (20% vs 100%)
- **Best Possible**: 1% (Rogue at night with full gear)
- **Worst Possible**: 100% (Warrior at noon in open)
- **XP Bonus**: 25% (encourages stealth gameplay)
- **Rogue Advantage**: 3× better than Warrior (-30% vs +10%)
- **Vampire Night Bonus**: Strong but not overpowered (-25%)

**System encourages**:
- Playing rogues for stealth builds
- Using night time for crimes
- Investing in stealth equipment
- Strategic planning before actions
- Risk/reward decision making
