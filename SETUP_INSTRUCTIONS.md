# Quick Setup Instructions - LPC Sprites

Follow these steps in order. Total time: **30-60 minutes** for basic setup.

---

## 📋 **Before You Start**

Make sure you have:
- ✅ Your game working (can launch and play)
- ✅ Internet connection (to download sprites)
- ✅ Web browser

---

## 🚀 **STEP 1: Create Folder** (Already Done!)

The folder `assets/sprites/lpc/` has been created for you.

**Verify:** Check that this folder exists:
```
C:\Users\<you>\LOVEGAME_work\assets\sprites\lpc\
```

---

## 🎨 **STEP 2: Download Your First Sprite** (10 minutes)

Let's start with just ONE sprite to verify everything works:

### **Download Human Male Body:**

1. **Open your browser** and go to:
   ```
   https://sanderfrenken.github.io/Universal-LPC-Spritesheet-Character-Generator/
   ```

2. **Clear everything:**
   - Look at the left sidebar
   - You'll see categories like "Body", "Hair", "Torso", etc.
   - Each has an "eye" icon 👁️
   - Click all the eye icons to HIDE everything

3. **Select only the body:**
   - Click "Body" category
   - Select "Human"
   - Select "Male"
   - Select "Light" skin tone
   - Make sure ONLY the body is visible (no hair, no clothes)

4. **Download:**
   - Click the big "Download" button at the top
   - Your browser will download `spritesheet.png`

5. **Rename and move:**
   - Find the downloaded file (probably in Downloads folder)
   - Rename it to: `human_male_body.png`
   - Move it to: `C:\Users\<you>\LOVEGAME_work\assets\sprites\lpc\`

6. **Verify:**
   - Open the PNG file in an image viewer
   - You should see a naked human male in multiple poses (walking, attacking, etc.)
   - File size should be around 20-100 KB

---

## ✅ **STEP 3: Test It!** (5 minutes)

Let's verify the sprite system is working:

1. **Launch your game**

2. **Press F3** (this runs a quick sprite test)
   - You should see output in console
   - It will tell you what sprites are found/missing

3. **OR press F4** (this runs a full diagnostic test)
   - More detailed output
   - Shows exactly what's working and what's not

4. **Expected Output:**
   ```
   === QUICK SPRITE TEST ===
   Essential sprites: 1/6
   ❌ Missing sprites. Download more.
   ```

5. **That's OK!** You only have 1 sprite so far. Let's get the rest...

---

## 📦 **STEP 4: Download Essential Sprites** (20 minutes)

Now download the remaining 5 essential sprites the same way:

### **Checklist:**

**Body Sprites:**
- [x] `human_male_body.png` (you just did this!)
- [ ] `human_female_body.png`
  - Body → Human → Female → Light
  - Download, rename, move to lpc folder

**Hair:**
- [ ] `hair_plain.png`
  - Hide body
  - Hair → Plain → Brown
  - Download ONLY hair layer
  - Rename to `hair_plain.png`

**Clothing:**
- [ ] `cloth_shirt.png`
  - Torso → Shirts → Longsleeve → White
  - Download ONLY torso layer

- [ ] `cloth_pants.png`
  - Legs → Pants → White
  - Download ONLY legs layer

**Weapons:**
- [ ] `sword.png`
  - Weapons → Melee → Sword
  - Download ONLY weapon layer

**Tip:** For each sprite, make sure to HIDE all other layers before downloading!

---

## 🎮 **STEP 5: Test Again!** (5 minutes)

1. **Launch game**

2. **Press F4** (full test)
   - Should now show: `Essential sprites: 6/6`
   - All tests should pass ✅

3. **Press V** (toggle sprite mode)
   - You should see: "🎨 Sprite mode enabled"

4. **Play the game**
   - Your character should now appear as a sprite!
   - Move around - the sprite should animate (walking)

5. **If it works:**
   ```
   🎉 SUCCESS! Your sprite system is working!
   ```

6. **If it doesn't work:**
   - Check console for errors
   - Make sure file names match exactly
   - Make sure files are in the right folder
   - Run test again (F4)

---

## 🌟 **STEP 6: Expand Collection** (Optional, 1-2 hours)

Once the basics work, add more variety:

### **Quick Downloads:**

**More Races:**
- `elf_male_body.png` - Body → Elf → Male → Light
- `dwarf_male_body.png` - Body → Dwarf → Male → Tan
- `orc_male_body.png` - Body → Orc → Male → Green

**More Hair:**
- `hair_ponytail.png` - Hair → Ponytail
- `hair_long.png` - Hair → Long
- `hair_mohawk.png` - Hair → Mohawk

**More Equipment:**
- `leather_armor.png` - Torso → Leather Armor
- `chainmail.png` - Torso → Chainmail
- `axe.png` - Weapons → Axe
- `bow.png` - Weapons → Bow
- `staff.png` - Weapons → Staff

---

## 🔧 **Troubleshooting**

### **Problem: "Could not load sprite layer" warning**

**Fix:**
- Check file name spelling (exact match required!)
- Check file is actually in `assets/sprites/lpc/` folder
- Check file is a valid PNG image

### **Problem: Character appears as "@" symbol instead of sprite**

**Fix:**
- Press V to enable sprite mode
- Make sure sprites are downloaded
- Check console for error messages

### **Problem: Sprite looks corrupted or wrong**

**Fix:**
- Re-download the sprite from LPC generator
- Make sure it's 832×1344 pixels
- Don't use random images from Google - must be LPC format

### **Problem: Downloaded sprite has multiple layers merged**

**Fix:**
- In the generator, use the "eye" icons to hide unwanted layers
- Only the visible layers will be in the download
- Or download full character and use image editor to separate layers

---

## ⌨️ **Keyboard Shortcuts**

Once everything is set up:

- **V** - Toggle sprite mode on/off
- **F3** - Quick sprite test
- **F4** - Full diagnostic test

---

## 📚 **Next Steps**

Once you have the essential sprites working:

1. **Read:** `SPRITE_DOWNLOAD_CHECKLIST.md` - Full sprite list
2. **Explore:** Add more races, equipment, hair styles
3. **Customize:** Use character presets to create NPCs
4. **Integrate:** Follow `INTEGRATION_TEXTRPG.md` to add to character creation

---

## ✅ **Success Checklist**

- [ ] Folder created: `assets/sprites/lpc/`
- [ ] Downloaded 6 essential sprites
- [ ] All files named correctly
- [ ] Ran test (F4) - all tests pass
- [ ] Pressed V - sprite mode enabled
- [ ] Character appears as sprite (not "@")
- [ ] Character animates when moving

**When all checked:** 🎉 You're done! The sprite system is working!

---

## 🆘 **Need Help?**

If you get stuck:

1. Run the diagnostic test (F4)
2. Read the error messages carefully
3. Check file names match exactly
4. Verify files are in correct folder
5. Make sure sprites are LPC format (832×1344)

---

## 📊 **File Structure Check**

Your folder should look like this:

```
LOVEGAME_work/
├── assets/
│   └── sprites/
│       └── lpc/
│           ├── human_male_body.png      ← 20-100 KB
│           ├── human_female_body.png    ← 20-100 KB
│           ├── hair_plain.png           ← 15-50 KB
│           ├── cloth_shirt.png          ← 10-40 KB
│           ├── cloth_pants.png          ← 10-40 KB
│           └── sword.png                ← 5-20 KB
```

**Total size:** ~100-300 KB for 6 essential files

---

**Estimated Time:**
- Step 1-2: 10 minutes (first sprite)
- Step 3: 5 minutes (test)
- Step 4: 20 minutes (remaining 5 sprites)
- Step 5: 5 minutes (final test)

**Total: 40 minutes** ⏱️

Good luck! 🎮✨
