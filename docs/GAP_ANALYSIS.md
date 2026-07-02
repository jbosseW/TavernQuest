# Tavern Quest — Gap Analysis vs. RPG / Life-Sim Genre Staples

_Date: 2026-07-02. Basis: 147/147 Lua files syntax-clean, clean boot to main
game via lovec (9 atlases, chatbot fallback, all subsystems initialize), module
inventory + keyword verification per claim, asset census (26,848 PNGs, 10 audio
files)._

## What Tavern Quest already has (do not rebuild)

6 classes / 20 races / 12 backgrounds, turn-based text combat AND FFT-style
tactical grid combat (height, flanking, 14 map types, 12 status effects),
prison-escape opening scenario, fishing (50 fish, 6 tiers, trophy variants),
farming, hunting, alchemy/forge/crafting, TCG with fusion + deckbuilder + AI,
poker, stock market, property system + settlements + employees/tavern (cafe)
management, pet sim, stealth, karma, vampire infiltration + luminary patrols,
wizard tower, endless mode, world gen (desert dungeons, hollow earth), day/night,
weather, auto-travel + fast travel, autoplay AI, quest journal, achievements,
interactive tutorials + knowledge center, glossary + lore books (61 doc corpus),
chatbot NPCs with 51-profile Lua fallback, LPC sprite pipeline, map editor +
full editor suite, save system with slots.

---

## A. The one glaring content gap: AUDIO

**10 music WAVs. Zero sound effects.** A game with tactical combat, fishing
reels, forges, taverns, and card packs plays completely silent apart from
looped exploration music. This is the single highest-impact polish item and it
is pure content work:

- **SFX pass:** UI click/hover, combat hits/blocks/spells, fishing cast/splash/
  reel, forge hammer, coin/shop, card flip/pack rip, footsteps by terrain,
  ambient tavern chatter. Freesound/Kenney packs cover 90% of this for free.
- **Format:** music ships as WAV (one track is 46 MB). Convert to OGG (~10:1
  smaller, native Love2D support, streaming source) — faster loads, 400+ MB off
  the repo.
- **Hooks:** 26 modules already reference sound/music code paths, so the play
  sites largely exist; this is asset acquisition + wiring, not architecture.

## B. Gameplay/UX gaps (verified absent)

### B1. Autosave — HIGH, cheap
savesystem.lua has slots, but nothing saves automatically (zero autosave hits).
A crash or force-quit eats the session. Add interval + on-scene-transition
saves to a dedicated rotating slot.

### B2. Input: key rebinding + gamepad — MEDIUM
Zero rebinding code, and `t.modules.joystick = false` in conf.lua — controller
support is switched off entirely. For a Steam-viable RPG, gamepad + remap UI is
table stakes. (Options menu already exists to host it.)

### B3. NPC relationship mechanics — MEDIUM, fits the identity
Romance/relationship appears only in lore text (characterpresets, rumors) — no
favor/friendship mechanic exists. For a game literally named Tavern Quest,
Stardew-style regulars (favor levels, gifts, unlockable dialogue via the
chatbot profiles, eventually marriage) is the thematic centerpiece gap. The
51-profile chatbot engine is a unique asset here no competitor has — favor
tiers could gate its dialogue depth.

### B4. Lighting/shader polish — LOW-MEDIUM
Day/night cycle exists but zero shaders — night is presumably a color tint.
One canvas + multiply-blend light layer (torches, forge glow, tavern windows)
would transform night scenes for ~a day of work.

### B5. Steam packaging — LATER
4 stray mentions, no integration. MMOLite already solved Steam libs +
steamcloud.lua for Love2D — port that pattern when content is ready.

## C. Engineering gaps

### C1. No test suite — but a free harness is already built
Zero tests. The cheapest path is unusual: **autoplay.lua is an AI that plays
the game toward goals** — wire it to a headless/windowed soak runner (load
game, run autoplay N minutes, assert no errors + invariants like HP bounds,
gold >= 0, inventory weight) and Tavern Quest gets integration coverage most
indies never have. Add luac -p sweep + data-module load tests (cards, races,
fish tables) as the fast tier. Pattern to copy: FROSTHOLD's tests/run_all.lua
with mock_love.

### C2. No agent conventions file
61 markdown docs but no CLAUDE.md/TASKS.md. Given multi-agent work on sibling
projects, add one (architecture map, "read FEATURE_AUDIT.md first", test
commands, the no-regressions bar).

### C3. Repo hygiene
Now on GitHub (private). The two LPC source .zips are gitignored; after OGG
conversion (A), consider `git lfs` or re-init to shed the 400 MB of WAV
history if clone times hurt.

## Suggested sequencing

1. **A audio SFX + OGG conversion** — biggest felt improvement per hour
2. **B1 autosave + C1 autoplay soak harness** — protect players and the codebase
3. **B2 rebinding + gamepad** — Steam prerequisite
4. **B3 tavern relationships** — the identity feature, leans on chatbot engine
5. **B4 lighting → B5 Steam packaging**
