# Tavern Quest

**A sprawling single-player fantasy RPG in Love2D that blends a text-adventure layer with 2D sprite exploration and FFT-style tactical grid combat.**

## What it does

Tavern Quest is a content-dense solo RPG. Create a character (6 classes, 20 races, 12 backgrounds) and play through a hybrid of narrative text-RPG scenes and a tile-based 2D overworld. It has two combat systems (turn-based text combat and a tactical grid with height, flanking, status effects, and 14 battlefield types), plus a huge surface of side systems: fishing (50 fish across 6 tiers), farming, hunting, alchemy/forging/crafting, a trading card game with fusion, poker, a stock market, property and settlement management with employees, a tavern/cafe minigame, pet sim, stealth, karma, vampire infiltration, a wizard tower, endless mode, procedural world generation (desert dungeons, hollow earth), and day/night + weather. NPCs run on a keyword/synonym chatbot engine with 51 dialogue profiles.

## Status

**Enormous and playable, but under-polished.** All 147 Lua modules are syntax-clean and the game boots cleanly to the main menu (9 sprite atlases, all subsystems initialize). No automated test suite yet. Biggest rough edges:

- **Almost no audio** — 10 music tracks, zero sound effects across the entire game
- No autosave (manual save slots only), no key rebinding, gamepad support disabled
- Romance/relationships exist only in lore text, not as a mechanic
- Day/night is a color tint (no lighting/shaders)

## How to run

Requires [LÖVE 11.4](https://love2d.org/).

```
love .              # from this directory
# or with a console build for logs:
lovec .
```

The NPC chatbot has an optional Python backend (`chatbot/`) that the game auto-detects via file IPC; without it, the bundled Lua fallback engine runs. See `SETUP_INSTRUCTIONS.md` and the 60+ design/lore docs at the repo root (`GAME_FEATURES.md` and `FEATURE_AUDIT.md` are the best maps).

## Screenshots

_TODO — add captures (character creation, tactical combat, the tavern, world map)._

## Known issues / roadmap

See [`docs/GAP_ANALYSIS.md`](docs/GAP_ANALYSIS.md). Priority: audio SFX pass + convert music WAV→OGG (saves ~400 MB) → autosave + wire the existing `autoplay.lua` AI into a soak-test harness → key rebinding/gamepad → tavern relationship mechanic (leans on the chatbot engine) → lighting → Steam packaging.

## AI development note

Built primarily through AI-assisted "vibe coding" with **Anthropic Claude** (Claude Code) and **OpenAI Codex** for review. Human direction owned the design, the extensive worldbuilding/lore corpus, and priorities; the AI agents did most of the implementation across the 147 modules. The NPC "chatbot" is a hand-rolled **keyword/synonym matcher, not an LLM** — it runs fully offline with no model or API. Given the size and the lack of tests, expect rough edges; the boot path and syntax are verified, deeper systems are lightly playtested.

## License

MIT for the original code — see [LICENSE](LICENSE). **Art/audio assets under `assets/` are third-party** (LPC sprite sets, tilesets, music packs) and retain their own licenses — several are CC-BY/GPL and require attribution; see the `CREDITS.txt`, `Attribution.txt`, and `LICENSE-*.txt` files bundled alongside each asset pack before redistributing.
