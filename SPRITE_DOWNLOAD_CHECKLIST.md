# LPC Sprite Download Checklist

Follow this checklist to download the MINIMUM sprites needed to get started.

---

## 🎯 Phase 1: Essential Sprites (30 minutes)

These are the BARE MINIMUM to make the system work:

### **1. Human Male Body** ✅
**Steps:**
1. Visit: https://sanderfrenken.github.io/Universal-LPC-Spritesheet-Character-Generator/
2. Click "Body" category
3. Select: "Human" → "Male" → "Light" skin tone
4. **Deselect everything else** (no hair, no clothes, nothing!)
5. Click "Download"
6. Save as: `human_male_body.png`
7. Move to: `C:\Users\<you>\LOVEGAME_work\assets\sprites\lpc\`

**Verification:**
- File size should be ~20-100KB
- Image should be 832×1344 pixels (64×64 tiles in grid)
- Should show naked male body in multiple poses

---

### **2. Human Female Body** ✅
**Steps:**
1. Same website (refresh if needed)
2. Click "Body" → "Human" → "Female" → "Light" skin
3. **Deselect everything else**
4. Click "Download"
5. Save as: `human_female_body.png`
6. Move to: `C:\Users\<you>\LOVEGAME_work\assets\sprites\lpc\`

---

### **3. Plain Hair (Male)** ✅
**Steps:**
1. Refresh the generator
2. Select "Body" → "Human" → "Male" → "Light"
3. Select "Hair" → "Plain" → "Brown"
4. **Only body + hair should be selected**
5. Click "Download"
6. Open in image editor (Paint, GIMP, etc.)
7. **Delete the body layer** (or re-download with ONLY hair selected)
8. Save as: `hair_plain.png`
9. Move to sprite folder

**Alternative:** Download the full character, then generate again with ONLY hair selected

---

### **4. Cloth Shirt (Torso)** ✅
**Steps:**
1. Refresh generator
2. Select body (any)
3. Select "Torso" → "Shirts" → "Longsleeve" → "White"
4. Download with ONLY torso selected (no body, no hair)
5. Save as: `cloth_shirt.png`
6. Move to folder

---

### **5. Cloth Pants (Legs)** ✅
**Steps:**
1. Select "Legs" → "Pants" → "White"
2. Download with ONLY pants selected
3. Save as: `cloth_pants.png`
4. Move to folder

---

### **6. Sword (Weapon)** ✅
**Steps:**
1. Select "Weapons" → "Sword" (basic iron sword)
2. Download with ONLY weapon selected
3. Save as: `sword.png`
4. Move to folder

---

## ✅ Phase 1 Complete!

You should now have these files:
```
assets/sprites/lpc/
├── human_male_body.png
├── human_female_body.png
├── hair_plain.png
├── cloth_shirt.png
├── cloth_pants.png
└── sword.png
```

**Test it:**
1. Launch your game
2. Press **V** to enable sprite mode
3. You should see a basic human character!

---

## 🎯 Phase 2: Expand Your Collection (1 hour)

Once Phase 1 works, add these for more variety:

### **Additional Races**
- [ ] elf_male_body.png
- [ ] elf_female_body.png
- [ ] dwarf_male_body.png
- [ ] orc_male_body.png

### **More Hair Styles**
- [ ] hair_ponytail.png
- [ ] hair_messy.png
- [ ] hair_long.png
- [ ] hair_mohawk.png
- [ ] hair_bald.png (or just use body with no hair)

### **More Equipment**
- [ ] leather_armor.png (torso)
- [ ] chainmail.png (torso)
- [ ] leather_pants.png (legs)
- [ ] boots_brown.png (feet)
- [ ] axe.png (weapon)
- [ ] bow.png (weapon)
- [ ] staff.png (weapon)

### **Accessories**
- [ ] beard_full.png (facial hair)
- [ ] shield_wood.png
- [ ] cape_green.png

---

## 🎯 Phase 3: Complete Collection (2-3 hours)

For the full experience:

### **All Player Classes**
Download equipment for each:
- [ ] Warrior set (chainmail, helmet, sword, shield)
- [ ] Mage set (robe, wizard hat, staff)
- [ ] Rogue set (leather armor, dagger)
- [ ] Ranger set (bow, quiver, leather)

### **NPC Variety**
- [ ] Merchant clothes
- [ ] Guard armor
- [ ] Priest robes
- [ ] Noble fancy dress

---

## 🔧 Troubleshooting

### **Problem: Downloaded sprite is a full character, not just one layer**

**Solution:**
1. In the generator, click the **"eye" icon** next to each category
2. This hides/shows layers
3. Hide everything except the part you want
4. Then download

### **Problem: Can't separate layers**

**Solution:**
Use the "Layer Mode" in the generator:
1. Look for "Download" dropdown
2. Select "Download Selected Layer Only"
3. This downloads JUST the active layer

### **Problem: File names don't match**

**Solution:**
The exact file names MUST match what's in the code:
- ✅ `human_male_body.png` - Correct
- ❌ `Human_Male.png` - Wrong (capitalization)
- ❌ `body_human_male.png` - Wrong (order)

---

## 📋 Quick Reference

**Generator URL:**
https://sanderfrenken.github.io/Universal-LPC-Spritesheet-Character-Generator/

**Folder Location:**
`C:\Users\<you>\LOVEGAME_work\assets\sprites\lpc\`

**File Format:**
- Type: PNG with transparency
- Size: 832×1344 pixels (standard LPC)
- Color: RGBA (not RGB)

**Attribution:**
Don't forget to download CREDITS.txt from the generator!

---

## ✨ Pro Tips

**Tip 1: Batch Download**
Instead of downloading one at a time:
1. Enable multiple layers
2. Download once
3. Use image editing software to separate layers
4. Save each layer as separate file

**Tip 2: Test Early**
After downloading the 6 essential files, TEST immediately:
- Press V in game
- See if character appears
- If it works, continue downloading more

**Tip 3: Organize as You Go**
Create subfolders if you have many sprites:
```
lpc/
├── bodies/
├── hair/
├── equipment/
└── weapons/
```

Then update the sprite loading paths in code.

---

## ✅ Completion Checklist

- [ ] Phase 1 complete (6 essential files)
- [ ] Tested in game (Press V, see sprite)
- [ ] Phase 2 complete (variety pack)
- [ ] Phase 3 complete (full collection)
- [ ] CREDITS.txt downloaded
- [ ] All files named correctly
- [ ] Game runs without sprite errors

---

**Time Estimate:**
- Phase 1: 30 minutes
- Phase 2: 1 hour
- Phase 3: 2-3 hours

**Total:** 3-4 hours for complete setup

Good luck! 🎮
