# Modding Support Implementation Plan
## Tavern Quest: A Tale of Tavern Times

**Document Version**: 1.0
**Date**: 2026-02-02
**Engine**: LOVE2D v11.4, Lua 5.1 (LuaJIT)
**Save Identity**: `taverntimes` (conf.lua `t.identity`)

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [File Structure](#2-file-structure)
3. [Mod Loader Foundation](#3-mod-loader-foundation)
4. [Registry Pattern](#4-registry-pattern)
5. [Event Hook System](#5-event-hook-system)
6. [Sandboxing](#6-sandboxing)
7. [Mod-Specific Save Data](#7-mod-specific-save-data)
8. [Mod Manager UI](#8-mod-manager-ui)
9. [Editor Integration](#9-editor-integration)
10. [Asset Modding](#10-asset-modding)
11. [Migration Strategy](#11-migration-strategy)
12. [API Reference Outline](#12-api-reference-outline)
13. [Implementation Phases](#13-implementation-phases)
14. [Testing Checklist](#14-testing-checklist)

---

## 1. Architecture Overview

### Current Architecture

The game uses a state-machine dispatch pattern in `main.lua`:

```lua
-- main.lua lines 46-70
local stateModules = {
    menu = Menu,
    game = Game,
    textrpg = TextRPG,
    fishing = Fishing,
    forge = Forge,
    -- ... 20+ state modules
}

-- Dispatch in love.update / love.draw / love.keypressed:
local module = stateModules[GameState.current]
if module and module.update then module.update(dt) end
```

Content is defined as local Lua tables inside each module:

- `cards.lua` -- Card definitions (suits, ranks, rarities, secret cards)
- `rpg_data.lua` -- CLASSES, RACES, ENEMIES, SKILLS, ENCOUNTER_TABLE, DUNGEON_TYPES, etc. (3200+ lines of data)
- `forge.lua` -- local RECIPES table (weapons, armor, traps)
- `wizardtower.lua` -- local RECIPES table (spells, tomes, scrolls)
- `alchemist.lua` -- local RECIPES table (potions, poisons, powders)
- `fishing.lua` -- local FISH_TYPES, LOOT_ITEMS, TREASURE_ITEMS, JUNK_ITEMS, RARITY_TIERS
- `hunting.lua` -- local ANIMALS table
- `backpack.lua` -- Backpack.ITEMS (200+ item definitions), CATEGORIES, CARTS, BEASTS_OF_BURDEN
- `mapenemies.lua` -- local MAP_ENEMY_TYPES
- `dungeonenemies.lua` -- local DUNGEON_ENEMY_VISUALS
- `entitysystem.lua` -- AGE_CATEGORIES, DISEASES, INJURIES, MOODS
- `craftingcore.lua` -- CraftingCore.RARITIES, CraftingCore.QUALITIES
- `progression.lua` -- local MODES, MODE_RANKS, OVERALL_RANKS
- `upgradesystem.lua` -- UpgradeSystem.UPGRADES (per-mode upgrade trees)
- `worldgen.lua` -- DUNGEON_TYPES, REGION_DUNGEON_WEIGHTS, chunk-based generation
- `theme.lua` / `ui.lua` -- UI theme colors and component library

### Modding Architecture Goal

```
[Base Game ("Mod Zero")] --> [Registry Layer] --> [Mod Loader] --> [Mod A, Mod B, ...]
                                    ^                   |
                                    |                   v
                              [Event System] <-- [Sandboxed Mod Code]
                                    |
                                    v
                              [Save System] --> [Per-Mod Save Data]
```

The base game registers all its content through the same API that mods use. Mods cannot directly mutate base game tables; they go through the registry.

---

## 2. File Structure

### New Files to Create

```
F:\LOVE\LOVEGAME_work\
  modding\
    modloader.lua          -- Discovery, dependency resolution, load ordering
    registry.lua           -- Central content registry (items, enemies, recipes, etc.)
    events.lua             -- Event hook system with priorities
    sandbox.lua            -- Sandboxed environment for mod code execution
    modsave.lua            -- Per-mod persistent data storage
    modapi.lua             -- Public API exposed to mods (the "ModAPI" table)
    modmanager_ui.lua      -- In-game mod manager UI
    modutils.lua           -- Utility functions for mod authors
    compatibility.lua      -- Version checking and compatibility layer
```

### Mod Directory Structure (inside love.filesystem save dir)

```
%APPDATA%/LOVE/taverntimes/
  mods/
    my_cool_mod/
      mod.lua              -- Manifest and entry point (required)
      init.lua             -- Main mod code (optional, loaded by mod.lua)
      data/
        items.lua          -- Item definitions
        enemies.lua        -- Enemy definitions
        recipes.lua        -- Recipe definitions
      assets/
        sprites/           -- Sprite sheets
        music/             -- Music tracks
        icons/             -- Item/ability icons
      locale/
        en.lua             -- English strings
    another_mod/
      mod.lua
      init.lua
```

Mods can also be placed in the game source directory for development:

```
F:\LOVE\LOVEGAME_work\
  mods/
    dev_test_mod/
      mod.lua
      init.lua
```

---

## 3. Mod Loader Foundation

### 3.1 Mod Discovery

LOVE2D's `love.filesystem` merges the game source directory with the save directory. We use `love.filesystem.mount()` to add mod directories.

```lua
-- modding/modloader.lua

local ModLoader = {}

ModLoader.MODS_DIR = "mods"           -- Relative to love.filesystem paths
ModLoader.MOD_MANIFEST = "mod.lua"    -- Required file in each mod folder
ModLoader.loadedMods = {}             -- {modId = modInstance}
ModLoader.loadOrder = {}              -- Ordered list of mod IDs
ModLoader.errors = {}                 -- {modId = errorMessage}

-- Scan for available mods
function ModLoader.discover()
    local mods = {}
    local modsDir = ModLoader.MODS_DIR

    -- Check both source dir and save dir
    local items = love.filesystem.getDirectoryItems(modsDir)
    for _, folder in ipairs(items) do
        local manifestPath = modsDir .. "/" .. folder .. "/" .. ModLoader.MOD_MANIFEST
        local info = love.filesystem.getInfo(manifestPath)
        if info and info.type == "file" then
            local manifest, err = ModLoader.loadManifest(manifestPath, folder)
            if manifest then
                mods[manifest.id] = manifest
            else
                ModLoader.errors[folder] = err
                print("[ModLoader] Failed to load manifest for " .. folder .. ": " .. tostring(err))
            end
        end
    end

    return mods
end
```

### 3.2 Manifest Format (mod.lua)

Every mod must have a `mod.lua` at its root. This file returns a table describing the mod.

```lua
-- Example: mods/epic_swords/mod.lua
return {
    -- REQUIRED fields
    id = "epic_swords",                     -- Unique identifier (lowercase, underscores)
    name = "Epic Swords Pack",              -- Display name
    version = "1.0.0",                      -- Semantic version
    api_version = 1,                        -- Mod API version this mod targets
    author = "ModderName",

    -- OPTIONAL fields
    description = "Adds 20 new legendary swords to the forge",
    url = "https://example.com/epic_swords",
    icon = "assets/icon.png",               -- 64x64 mod icon

    -- Dependencies: {modId = "version_requirement"}
    dependencies = {},                       -- e.g. {"base_expansion" = ">=1.0.0"}
    optional_dependencies = {},
    incompatible = {},                       -- Mods that conflict

    -- Load priority (lower = earlier, default 100)
    priority = 100,

    -- Entry point (path relative to mod root)
    main = "init.lua",

    -- What this mod provides (for dependency resolution)
    provides = {"content_swords"},

    -- Hooks this mod wants (for documentation)
    hooks = {"on_forge_craft", "on_item_created"},
}
```

### 3.3 Manifest Loading and Validation

```lua
-- modding/modloader.lua (continued)

function ModLoader.loadManifest(path, folderName)
    -- Load manifest in a restricted environment
    local chunk, loadErr = love.filesystem.load(path)
    if not chunk then
        return nil, "Parse error: " .. tostring(loadErr)
    end

    -- Run in empty sandbox (manifest is pure data, no function calls needed)
    local env = {}
    setfenv(chunk, env)
    local ok, result = pcall(chunk)
    if not ok then
        return nil, "Execution error: " .. tostring(result)
    end

    if type(result) ~= "table" then
        return nil, "mod.lua must return a table"
    end

    -- Validate required fields
    local required = {"id", "name", "version", "api_version", "author"}
    for _, field in ipairs(required) do
        if not result[field] then
            return nil, "Missing required field: " .. field
        end
    end

    -- Validate ID format (lowercase alphanumeric + underscores)
    if not result.id:match("^[a-z][a-z0-9_]*$") then
        return nil, "Invalid mod ID format (must be lowercase alphanumeric with underscores)"
    end

    -- Check API version compatibility
    if result.api_version > ModLoader.CURRENT_API_VERSION then
        return nil, "Requires newer API version " .. result.api_version
            .. " (game has " .. ModLoader.CURRENT_API_VERSION .. ")"
    end

    -- Attach folder path for loading
    result._folder = folderName
    result._path = ModLoader.MODS_DIR .. "/" .. folderName

    -- Default optional fields
    result.dependencies = result.dependencies or {}
    result.optional_dependencies = result.optional_dependencies or {}
    result.incompatible = result.incompatible or {}
    result.priority = result.priority or 100
    result.main = result.main or "init.lua"
    result.provides = result.provides or {}

    return result
end

ModLoader.CURRENT_API_VERSION = 1
```

### 3.4 Dependency Resolution and Load Ordering

```lua
-- modding/modloader.lua (continued)

-- Topological sort for dependency resolution
function ModLoader.resolveLoadOrder(manifests, enabledMods)
    local sorted = {}
    local visited = {}
    local visiting = {}  -- For cycle detection
    local errors = {}

    local function visit(modId)
        if visited[modId] then return true end
        if visiting[modId] then
            table.insert(errors, "Circular dependency involving: " .. modId)
            return false
        end

        local manifest = manifests[modId]
        if not manifest then
            -- Missing dependency
            table.insert(errors, "Missing dependency: " .. modId)
            return false
        end

        if not enabledMods[modId] then
            return true  -- Skip disabled mods
        end

        visiting[modId] = true

        -- Visit hard dependencies first
        for depId, _ in pairs(manifest.dependencies) do
            if not visit(depId) then
                return false
            end
        end

        -- Visit optional dependencies if they exist and are enabled
        for depId, _ in pairs(manifest.optional_dependencies) do
            if manifests[depId] and enabledMods[depId] then
                visit(depId)
            end
        end

        visiting[modId] = nil
        visited[modId] = true
        table.insert(sorted, modId)
        return true
    end

    -- Collect all enabled mods and sort by priority first
    local prioritySorted = {}
    for modId, _ in pairs(enabledMods) do
        if manifests[modId] then
            table.insert(prioritySorted, modId)
        end
    end
    table.sort(prioritySorted, function(a, b)
        return (manifests[a].priority or 100) < (manifests[b].priority or 100)
    end)

    -- Topological sort respecting dependencies
    for _, modId in ipairs(prioritySorted) do
        visit(modId)
    end

    return sorted, errors
end
```

### 3.5 Mod Loading and Initialization

```lua
-- modding/modloader.lua (continued)

local Sandbox = require("modding.sandbox")
local Registry = require("modding.registry")
local Events = require("modding.events")
local ModAPI = require("modding.modapi")

function ModLoader.loadAll()
    -- 1. Discover available mods
    local manifests = ModLoader.discover()

    -- 2. Load enabled mod list from settings
    local enabledMods = ModLoader.getEnabledMods()

    -- 3. Check for incompatibilities
    local incompatErrors = ModLoader.checkIncompatibilities(manifests, enabledMods)
    for _, err in ipairs(incompatErrors) do
        print("[ModLoader] Incompatibility: " .. err)
    end

    -- 4. Resolve load order
    local loadOrder, depErrors = ModLoader.resolveLoadOrder(manifests, enabledMods)
    for _, err in ipairs(depErrors) do
        print("[ModLoader] Dependency error: " .. err)
    end

    -- 5. Load each mod in order
    for _, modId in ipairs(loadOrder) do
        local manifest = manifests[modId]
        local ok, err = ModLoader.loadMod(manifest)
        if ok then
            ModLoader.loadedMods[modId] = manifest
            table.insert(ModLoader.loadOrder, modId)
            print("[ModLoader] Loaded: " .. manifest.name .. " v" .. manifest.version)
        else
            ModLoader.errors[modId] = err
            print("[ModLoader] FAILED to load " .. modId .. ": " .. tostring(err))
        end
    end

    -- 6. Fire post-load event
    Events.fire("mods_loaded", {count = #ModLoader.loadOrder})
end

function ModLoader.loadMod(manifest)
    local mainPath = manifest._path .. "/" .. manifest.main

    if not love.filesystem.getInfo(mainPath) then
        return false, "Entry point not found: " .. mainPath
    end

    local chunk, loadErr = love.filesystem.load(mainPath)
    if not chunk then
        return false, "Parse error in " .. manifest.main .. ": " .. tostring(loadErr)
    end

    -- Create sandboxed environment for this mod
    local modEnv = Sandbox.createEnvironment(manifest)

    -- Inject ModAPI into the environment
    modEnv.ModAPI = ModAPI.createForMod(manifest)
    modEnv.require = Sandbox.createRequire(manifest)

    setfenv(chunk, modEnv)

    local ok, result = pcall(chunk)
    if not ok then
        return false, "Runtime error: " .. tostring(result)
    end

    -- Store the mod's return value (if it returns a table with lifecycle hooks)
    if type(result) == "table" then
        manifest._module = result
    end

    return true
end

-- Get enabled mods from player settings
function ModLoader.getEnabledMods()
    local enabled = {}

    -- Load from save directory
    if love.filesystem.getInfo("mod_settings.lua") then
        local chunk = love.filesystem.load("mod_settings.lua")
        if chunk then
            local env = {}
            setfenv(chunk, env)
            local ok, data = pcall(chunk)
            if ok and type(data) == "table" then
                for _, modId in ipairs(data.enabled or {}) do
                    enabled[modId] = true
                end
                return enabled
            end
        end
    end

    return enabled
end

-- Save enabled mods list
function ModLoader.saveEnabledMods(enabledList)
    local content = "return {\n  enabled = {\n"
    for _, modId in ipairs(enabledList) do
        content = content .. '    "' .. modId .. '",\n'
    end
    content = content .. "  },\n}\n"
    love.filesystem.write("mod_settings.lua", content)
end

function ModLoader.checkIncompatibilities(manifests, enabledMods)
    local errors = {}
    for modId, _ in pairs(enabledMods) do
        local m = manifests[modId]
        if m then
            for _, incompId in ipairs(m.incompatible) do
                if enabledMods[incompId] then
                    table.insert(errors, m.name .. " is incompatible with " .. incompId)
                end
            end
        end
    end
    return errors
end

return ModLoader
```

---

## 4. Registry Pattern

### 4.1 Central Registry

The registry holds all game content as named collections. The base game registers its content at startup, and mods register additional content afterward.

```lua
-- modding/registry.lua

local Registry = {}

-- All content collections: {contentType = {id = definition}}
Registry._collections = {}

-- Ordered lists for iteration: {contentType = {definition, definition, ...}}
Registry._ordered = {}

-- Track who registered what: {contentType = {id = modId}}
Registry._owners = {}

-- Override tracking: {contentType = {id = {original = def, overrider = modId}}}
Registry._overrides = {}

-- Frozen flag: prevents registration after init phase
Registry._frozen = false

-- Create or get a content collection
function Registry.collection(name)
    if not Registry._collections[name] then
        Registry._collections[name] = {}
        Registry._ordered[name] = {}
        Registry._owners[name] = {}
        Registry._overrides[name] = {}
    end
    return Registry._collections[name]
end

-- Register a single item into a collection
-- @param collectionName: string identifying the collection
-- @param id: unique string ID for this entry
-- @param definition: table with the entry data
-- @param modId: who is registering (nil = base game)
function Registry.register(collectionName, id, definition, modId)
    modId = modId or "_base"

    local coll = Registry.collection(collectionName)
    local owners = Registry._owners[collectionName]
    local ordered = Registry._ordered[collectionName]

    -- Check for ID collision
    if coll[id] then
        if modId ~= "_base" then
            -- Mod is overriding existing content -- track it
            Registry._overrides[collectionName][id] = {
                original = coll[id],
                overrider = modId,
            }
            print("[Registry] " .. modId .. " overrides " .. collectionName .. ":" .. id)
        else
            print("[Registry] Warning: base game re-registered " .. collectionName .. ":" .. id)
        end

        -- Remove old entry from ordered list
        for i, entry in ipairs(ordered) do
            if entry.id == id then
                table.remove(ordered, i)
                break
            end
        end
    end

    -- Store the definition with metadata
    definition._id = id
    definition._owner = modId
    coll[id] = definition
    owners[id] = modId
    table.insert(ordered, definition)
end

-- Register multiple items at once
function Registry.registerBatch(collectionName, entries, modId)
    for _, entry in ipairs(entries) do
        if entry.id then
            Registry.register(collectionName, entry.id, entry, modId)
        end
    end
end

-- Get a single entry by ID
function Registry.get(collectionName, id)
    local coll = Registry._collections[collectionName]
    if not coll then return nil end
    return coll[id]
end

-- Get all entries in a collection as an ordered list
function Registry.getAll(collectionName)
    return Registry._ordered[collectionName] or {}
end

-- Get all entries as a map {id = definition}
function Registry.getMap(collectionName)
    return Registry._collections[collectionName] or {}
end

-- Get entries matching a filter function
function Registry.filter(collectionName, filterFn)
    local results = {}
    for _, entry in ipairs(Registry.getAll(collectionName)) do
        if filterFn(entry) then
            table.insert(results, entry)
        end
    end
    return results
end

-- Remove an entry (only the owner or base game can remove)
function Registry.remove(collectionName, id, modId)
    modId = modId or "_base"
    local owners = Registry._owners[collectionName]
    if not owners then return false end

    -- Only owner or base can remove
    if owners[id] ~= modId and modId ~= "_base" then
        print("[Registry] " .. modId .. " cannot remove " .. id .. " (owned by " .. tostring(owners[id]) .. ")")
        return false
    end

    local coll = Registry._collections[collectionName]
    local ordered = Registry._ordered[collectionName]

    coll[id] = nil
    owners[id] = nil

    for i, entry in ipairs(ordered) do
        if entry.id == id or entry._id == id then
            table.remove(ordered, i)
            break
        end
    end

    -- Restore override if one exists
    local override = Registry._overrides[collectionName][id]
    if override then
        coll[id] = override.original
        owners[id] = "_base"
        table.insert(ordered, override.original)
        Registry._overrides[collectionName][id] = nil
    end

    return true
end

-- Unregister all content from a specific mod
function Registry.unregisterMod(modId)
    for collName, owners in pairs(Registry._owners) do
        local toRemove = {}
        for id, owner in pairs(owners) do
            if owner == modId then
                table.insert(toRemove, id)
            end
        end
        for _, id in ipairs(toRemove) do
            Registry.remove(collName, id, modId)
        end
    end
end

-- Get list of all collection names
function Registry.getCollectionNames()
    local names = {}
    for name, _ in pairs(Registry._collections) do
        table.insert(names, name)
    end
    table.sort(names)
    return names
end

-- Get count of entries in a collection
function Registry.count(collectionName)
    local ordered = Registry._ordered[collectionName]
    return ordered and #ordered or 0
end

return Registry
```

### 4.2 Collection Names (Standard)

These are all the registry collection names used by the base game:

| Collection Name | Source File(s) | Description |
|---|---|---|
| `items` | `backpack.lua` Backpack.ITEMS | All inventory items |
| `item_categories` | `backpack.lua` Backpack.CATEGORIES | Item category strings |
| `carts` | `backpack.lua` Backpack.CARTS | Cart definitions |
| `beasts_of_burden` | `backpack.lua` Backpack.BEASTS_OF_BURDEN | Pack animal definitions |
| `card_rarities` | `cards.lua` Cards.rarities | Card rarity tiers |
| `secret_cards` | `cards.lua` Cards.secretCards | Secret unlockable cards |
| `crafting_rarities` | `craftingcore.lua` CraftingCore.RARITIES | Crafting rarity system |
| `crafting_qualities` | `craftingcore.lua` CraftingCore.QUALITIES | Crafting quality tiers |
| `forge_recipes` | `forge.lua` RECIPES | Forge crafting recipes |
| `wizard_recipes` | `wizardtower.lua` RECIPES | Wizard tower recipes |
| `alchemy_recipes` | `alchemist.lua` RECIPES | Alchemy recipes |
| `fish_types` | `fishing.lua` FISH_TYPES | Fish definitions |
| `fish_loot` | `fishing.lua` LOOT_ITEMS | Fishing loot drops |
| `fish_treasure` | `fishing.lua` TREASURE_ITEMS | Fishing treasure |
| `fish_junk` | `fishing.lua` JUNK_ITEMS | Fishing junk items |
| `fish_rarity_tiers` | `fishing.lua` RARITY_TIERS | Fishing rarity system |
| `animals` | `hunting.lua` ANIMALS | Huntable animals |
| `rpg_classes` | `rpg_data.lua` Data.CLASSES | Character classes |
| `rpg_races` | `rpg_data.lua` Data.RACES | Playable races |
| `rpg_unlockable_races` | `rpg_data.lua` Data.UNLOCKABLE_RACES | Unlockable races |
| `rpg_backgrounds` | `rpg_data.lua` Data.BACKGROUNDS | Character backgrounds |
| `rpg_skills` | `rpg_data.lua` Data.SKILLS | Combat skills |
| `rpg_enemies` | `rpg_data.lua` Data.ENEMIES | Enemy definitions |
| `rpg_encounter_table` | `rpg_data.lua` Data.ENCOUNTER_TABLE | Encounter scaling |
| `rpg_damage_types` | `rpg_data.lua` Data.DAMAGE_TYPES | Damage type system |
| `rpg_companion_classes` | `rpg_data.lua` Data.COMPANION_CLASSES | Companion types |
| `rpg_dungeon_types` | `rpg_data.lua` Data.DUNGEON_TYPES | Dungeon type defs |
| `rpg_dungeon_enemies` | `rpg_data.lua` Data.DUNGEON_ENEMIES | Per-dungeon enemy lists |
| `rpg_tile_types` | `rpg_data.lua` Data.TILE_TYPES | World map tile types |
| `rpg_weather_states` | `rpg_data.lua` Data.WEATHER_STATES | Weather definitions |
| `rpg_camp_foods` | `rpg_data.lua` Data.CAMP_FOODS | Camp food items |
| `rpg_factions` | `rpg_data.lua` Data.FACTIONS | Faction definitions |
| `rpg_trade_goods` | `rpg_data.lua` Data.TRADE_GOODS | Trade good defs |
| `rpg_quest_items` | `rpg_data.lua` Data.QUEST_ITEMS | Quest item defs |
| `rpg_npc_templates` | `rpg_data.lua` Data.NPC_TEMPLATES | NPC templates |
| `rpg_ascension_tree` | `rpg_data.lua` Data.ASCENSION_TREE | Ascension skills |
| `rpg_skill_trees` | `rpg_data.lua` Data.SKILL_TREES | Skill tree defs |
| `rpg_specializations` | `rpg_data.lua` Data.SPECIALIZATIONS | Class specs |
| `map_enemy_types` | `mapenemies.lua` MAP_ENEMY_TYPES | Overworld enemy types |
| `dungeon_enemy_visuals` | `dungeonenemies.lua` DUNGEON_ENEMY_VISUALS | Dungeon enemy visuals |
| `entity_diseases` | `entitysystem.lua` EntitySystem.DISEASES | Disease definitions |
| `entity_injuries` | `entitysystem.lua` EntitySystem.INJURIES | Injury definitions |
| `entity_moods` | `entitysystem.lua` EntitySystem.MOODS | Mood states |
| `upgrades` | `upgradesystem.lua` UpgradeSystem.UPGRADES | Per-mode upgrades |
| `progression_modes` | `progression.lua` MODES | Game mode defs |
| `portraits` | `rpg_data.lua` Data.portraitMappings | Portrait path map |
| `state_modules` | `main.lua` stateModules | Game state modules |
| `audio_tracks` | `main.lua` AudioSystem | Music track lists |

### 4.3 Base Game Registration ("Mod Zero")

A new file `modding/base_registration.lua` registers all existing game content into the registry. This is called once during `love.load()` before any mods load.

```lua
-- modding/base_registration.lua

local Registry = require("modding.registry")

local BaseRegistration = {}

function BaseRegistration.registerAll()
    BaseRegistration.registerItems()
    BaseRegistration.registerCards()
    BaseRegistration.registerCrafting()
    BaseRegistration.registerForge()
    BaseRegistration.registerWizard()
    BaseRegistration.registerAlchemy()
    BaseRegistration.registerFishing()
    BaseRegistration.registerHunting()
    BaseRegistration.registerRPGData()
    BaseRegistration.registerEntities()
    BaseRegistration.registerUpgrades()
    BaseRegistration.registerProgression()
    BaseRegistration.registerMapEnemies()
    print("[BaseRegistration] All base game content registered")
end

function BaseRegistration.registerItems()
    local Backpack = require("backpack")

    -- Register all items from Backpack.ITEMS
    for _, item in ipairs(Backpack.ITEMS) do
        Registry.register("items", item.id, item)
    end

    -- Register categories
    for _, cat in ipairs(Backpack.CATEGORIES) do
        Registry.register("item_categories", cat, {id = cat, name = cat})
    end

    -- Register carts
    for _, cart in ipairs(Backpack.CARTS) do
        Registry.register("carts", cart.id, cart)
    end

    -- Register beasts of burden
    for _, beast in ipairs(Backpack.BEASTS_OF_BURDEN) do
        Registry.register("beasts_of_burden", beast.id, beast)
    end
end

function BaseRegistration.registerCards()
    local Cards = require("cards")

    -- Register card rarities
    for id, rarity in pairs(Cards.rarities) do
        rarity.id = id
        Registry.register("card_rarities", id, rarity)
    end

    -- Register secret cards
    for _, card in ipairs(Cards.secretCards) do
        Registry.register("secret_cards", card.id, card)
    end
end

function BaseRegistration.registerCrafting()
    local CraftingCore = require("craftingcore")

    for _, r in ipairs(CraftingCore.RARITIES) do
        Registry.register("crafting_rarities", r.id, r)
    end

    for _, q in ipairs(CraftingCore.QUALITIES) do
        Registry.register("crafting_qualities", q.id, q)
    end
end

-- For forge, wizard, alchemist: the RECIPES tables are local to each module.
-- We need each module to expose its recipes via a getter function.
-- See Section 11 (Migration Strategy) for how to refactor these modules.

function BaseRegistration.registerForge()
    -- After migration, Forge will expose its recipes:
    local Forge = require("forge")
    local recipes = Forge.getRecipes()  -- Added by migration
    for _, recipe in ipairs(recipes) do
        Registry.register("forge_recipes", recipe.id, recipe)
    end
end

function BaseRegistration.registerWizard()
    local WizardTower = require("wizardtower")
    local recipes = WizardTower.getRecipes()
    for _, recipe in ipairs(recipes) do
        Registry.register("wizard_recipes", recipe.id, recipe)
    end
end

function BaseRegistration.registerAlchemy()
    local Alchemist = require("alchemist")
    local recipes = Alchemist.getRecipes()
    for _, recipe in ipairs(recipes) do
        Registry.register("alchemy_recipes", recipe.id, recipe)
    end
end

function BaseRegistration.registerFishing()
    local Fishing = require("fishing")
    local fishTypes = Fishing.getFishTypes()
    for _, fish in ipairs(fishTypes) do
        Registry.register("fish_types", fish.id, fish)
    end

    local lootItems = Fishing.getLootItems()
    for _, loot in ipairs(lootItems) do
        Registry.register("fish_loot", loot.id, loot)
    end
end

function BaseRegistration.registerHunting()
    local Hunting = require("hunting")
    local animals = Hunting.getAnimals()
    for _, animal in ipairs(animals) do
        Registry.register("animals", animal.id, animal)
    end
end

function BaseRegistration.registerRPGData()
    local Data = require("rpg_data")

    -- Classes
    for _, cls in ipairs(Data.CLASSES) do
        Registry.register("rpg_classes", cls.id, cls)
    end

    -- Races
    for _, race in ipairs(Data.RACES) do
        Registry.register("rpg_races", race.id, race)
    end

    -- Unlockable Races
    for _, race in ipairs(Data.UNLOCKABLE_RACES) do
        Registry.register("rpg_unlockable_races", race.id, race)
    end

    -- Backgrounds
    for _, bg in ipairs(Data.BACKGROUNDS) do
        Registry.register("rpg_backgrounds", bg.id, bg)
    end

    -- Skills (keyed by name, not by .id)
    for name, skill in pairs(Data.SKILLS) do
        skill.id = name  -- Add ID field
        Registry.register("rpg_skills", name, skill)
    end

    -- Enemies
    for _, enemy in ipairs(Data.ENEMIES) do
        Registry.register("rpg_enemies", enemy.id, enemy)
    end

    -- Damage types
    for id, dmgType in pairs(Data.DAMAGE_TYPES) do
        dmgType.id = id
        Registry.register("rpg_damage_types", id, dmgType)
    end

    -- Companion classes
    for _, comp in ipairs(Data.COMPANION_CLASSES) do
        Registry.register("rpg_companion_classes", comp.id, comp)
    end

    -- Dungeon types
    for _, dt in ipairs(Data.DUNGEON_TYPES) do
        Registry.register("rpg_dungeon_types", dt.id, dt)
    end

    -- Factions
    for _, faction in ipairs(Data.FACTIONS) do
        Registry.register("rpg_factions", faction.id, faction)
    end

    -- Ascension tree
    for _, node in ipairs(Data.ASCENSION_TREE) do
        Registry.register("rpg_ascension_tree", node.id, node)
    end

    -- Specializations
    for _, spec in ipairs(Data.SPECIALIZATIONS) do
        Registry.register("rpg_specializations", spec.id, spec)
    end

    -- Portrait mappings
    for id, path in pairs(Data.portraitMappings) do
        Registry.register("portraits", id, {id = id, path = path})
    end
end

function BaseRegistration.registerEntities()
    local EntitySystem = require("entitysystem")

    for _, disease in ipairs(EntitySystem.DISEASES) do
        Registry.register("entity_diseases", disease.id, disease)
    end
    for _, injury in ipairs(EntitySystem.INJURIES) do
        Registry.register("entity_injuries", injury.id, injury)
    end
    for _, mood in ipairs(EntitySystem.MOODS) do
        Registry.register("entity_moods", mood.id, mood)
    end
end

function BaseRegistration.registerUpgrades()
    local UpgradeSystem = require("upgradesystem")

    for mode, upgrades in pairs(UpgradeSystem.UPGRADES) do
        for _, upgrade in ipairs(upgrades) do
            Registry.register("upgrades", mode .. ":" .. upgrade.id, upgrade)
        end
    end
end

function BaseRegistration.registerProgression()
    -- Progression MODES is local, needs getter (see migration)
    local Progression = require("progression")
    local modes = Progression.getModes()
    if modes then
        for id, mode in pairs(modes) do
            mode.id = id
            Registry.register("progression_modes", id, mode)
        end
    end
end

function BaseRegistration.registerMapEnemies()
    -- These are local tables, need getters (see migration)
    -- After migration:
    -- local MapEnemies = require("mapenemies")
    -- local types = MapEnemies.getEnemyTypes()
    -- for id, etype in pairs(types) do
    --     etype.id = id
    --     Registry.register("map_enemy_types", id, etype)
    -- end
end

return BaseRegistration
```

### 4.4 Runtime Registry Lookup

Game modules that currently iterate local tables must be updated to query the registry instead. Example for forge:

```lua
-- BEFORE (forge.lua, current code):
for i, recipe in ipairs(RECIPES) do
    -- draw recipe list
end

-- AFTER (forge.lua, with registry):
local Registry = require("modding.registry")

-- In any function that needs the recipe list:
local recipes = Registry.getAll("forge_recipes")
for i, recipe in ipairs(recipes) do
    -- draw recipe list (works identically, same table shape)
end

-- To find a specific recipe:
local ironSword = Registry.get("forge_recipes", "iron_sword")
```

---

## 5. Event Hook System

### 5.1 Event System Implementation

```lua
-- modding/events.lua

local Events = {}

-- {eventName = {{callback, priority, modId}, ...}}
Events._listeners = {}

-- Priority constants
Events.PRIORITY_FIRST = 0
Events.PRIORITY_HIGH = 25
Events.PRIORITY_NORMAL = 50
Events.PRIORITY_LOW = 75
Events.PRIORITY_LAST = 100

-- Register a listener for an event
-- @param eventName: string event identifier
-- @param callback: function(eventData) -> eventData or nil
-- @param priority: number (lower = earlier, default NORMAL)
-- @param modId: string mod identifier
function Events.on(eventName, callback, priority, modId)
    priority = priority or Events.PRIORITY_NORMAL
    modId = modId or "_base"

    if not Events._listeners[eventName] then
        Events._listeners[eventName] = {}
    end

    table.insert(Events._listeners[eventName], {
        callback = callback,
        priority = priority,
        modId = modId,
    })

    -- Keep sorted by priority
    table.sort(Events._listeners[eventName], function(a, b)
        return a.priority < b.priority
    end)
end

-- Remove all listeners for a specific mod
function Events.removeModListeners(modId)
    for eventName, listeners in pairs(Events._listeners) do
        local i = 1
        while i <= #listeners do
            if listeners[i].modId == modId then
                table.remove(listeners, i)
            else
                i = i + 1
            end
        end
    end
end

-- Fire an event, passing data through all listeners
-- Listeners can modify eventData. If a listener returns false, the chain stops.
-- @param eventName: string
-- @param eventData: table (will be passed to each listener)
-- @return eventData (potentially modified), cancelled (boolean)
function Events.fire(eventName, eventData)
    eventData = eventData or {}
    eventData._eventName = eventName
    eventData._cancelled = false

    local listeners = Events._listeners[eventName]
    if not listeners then return eventData, false end

    for _, listener in ipairs(listeners) do
        local ok, result = pcall(listener.callback, eventData)
        if not ok then
            print("[Events] Error in " .. listener.modId .. " handler for "
                .. eventName .. ": " .. tostring(result))
        elseif result == false then
            -- Event cancelled
            eventData._cancelled = true
            return eventData, true
        elseif type(result) == "table" then
            -- Listener returned modified data
            eventData = result
        end
    end

    return eventData, false
end

-- Fire a simple notification event (no data modification, no cancellation)
function Events.notify(eventName, eventData)
    eventData = eventData or {}
    local listeners = Events._listeners[eventName]
    if not listeners then return end

    for _, listener in ipairs(listeners) do
        local ok, err = pcall(listener.callback, eventData)
        if not ok then
            print("[Events] Error in " .. listener.modId .. " handler for "
                .. eventName .. ": " .. tostring(err))
        end
    end
end

-- Check if any listeners exist for an event
function Events.hasListeners(eventName)
    local listeners = Events._listeners[eventName]
    return listeners and #listeners > 0
end

return Events
```

### 5.2 Event Catalog

All game events that mods can hook into. Events with a `fire()` call can be cancelled or modified by returning `false` or a modified table. Events with `notify()` are informational only.

#### Combat Events (rpg_combat.lua)

| Event | Type | Data Fields | Description |
|---|---|---|---|
| `combat_start` | fire | `{player, enemies, location, dungeonType}` | Before combat begins. Cancel to prevent. |
| `combat_end` | notify | `{player, enemies, result, xpGained, goldGained}` | After combat ends. |
| `combat_player_attack` | fire | `{player, target, damage, damageType, skill}` | Before player deals damage. Modify damage. |
| `combat_player_damaged` | fire | `{player, attacker, damage, damageType}` | Before player takes damage. Modify damage. |
| `combat_enemy_defeated` | notify | `{player, enemy, loot}` | After an enemy is defeated. |
| `combat_skill_used` | fire | `{player, skill, target, manaCost}` | Before skill executes. Modify cost/effect. |
| `combat_loot_generated` | fire | `{player, enemy, loot}` | Before loot is awarded. Modify loot table. |

#### Crafting Events (forge.lua, wizardtower.lua, alchemist.lua)

| Event | Type | Data Fields | Description |
|---|---|---|---|
| `craft_start` | fire | `{recipe, mode, player}` | Before crafting begins. |
| `craft_complete` | fire | `{recipe, mode, item, rarity, quality}` | After craft, before item given. Modify item. |
| `craft_rarity_roll` | fire | `{recipe, mode, weights}` | Before rarity is rolled. Modify weights. |

#### Fishing Events (fishing.lua)

| Event | Type | Data Fields | Description |
|---|---|---|---|
| `fishing_cast` | fire | `{location, rod, bait, depth}` | Before line is cast. |
| `fishing_bite` | fire | `{fish, location, rod}` | When a fish bites. |
| `fishing_catch` | notify | `{fish, weight, location, isPerfect}` | After catching a fish. |
| `fishing_loot_drop` | fire | `{fish, loot}` | Before loot from fish is given. |

#### Hunting Events (hunting.lua)

| Event | Type | Data Fields | Description |
|---|---|---|---|
| `hunting_animal_spawned` | fire | `{animal, region}` | When animal appears. |
| `hunting_kill` | fire | `{animal, loot}` | After successful hunt. |

#### Travel / World Events (rpg_travel.lua, rpg_world.lua, worldgen.lua)

| Event | Type | Data Fields | Description |
|---|---|---|---|
| `travel_move` | fire | `{player, fromX, fromY, toX, toY, tileType}` | Before player moves. |
| `travel_encounter` | fire | `{player, encounterType, x, y}` | Random encounter triggered. |
| `travel_enter_town` | notify | `{player, town}` | Player enters a town. |
| `travel_leave_town` | notify | `{player, town}` | Player leaves a town. |
| `travel_enter_dungeon` | notify | `{player, dungeon}` | Player enters a dungeon. |
| `world_chunk_generated` | fire | `{chunkX, chunkY, tiles}` | After chunk generation. Modify tiles. |
| `world_town_generated` | fire | `{town, region}` | After a town is generated. |

#### Economy Events

| Event | Type | Data Fields | Description |
|---|---|---|---|
| `gold_gained` | fire | `{amount, source}` | Before gold is added. Modify amount. |
| `gold_spent` | fire | `{amount, source, item}` | Before gold is spent. Cancel to prevent. |
| `item_acquired` | notify | `{item, quantity, source}` | After item added to backpack. |
| `item_sold` | fire | `{item, value}` | Before item is sold. Modify value. |

#### Progression Events (progression.lua)

| Event | Type | Data Fields | Description |
|---|---|---|---|
| `xp_gained` | fire | `{amount, mode, source}` | Before XP is awarded. Modify amount. |
| `level_up` | notify | `{mode, newLevel, modeData}` | After level up. |

#### State / Lifecycle Events (main.lua)

| Event | Type | Data Fields | Description |
|---|---|---|---|
| `state_change` | fire | `{from, to}` | Before game state changes. |
| `game_save` | notify | `{slot, data}` | After game is saved. |
| `game_load` | notify | `{slot, data}` | After game is loaded. |
| `mods_loaded` | notify | `{count}` | All mods finished loading. |
| `game_tick` | notify | `{dt}` | Every frame update. |

#### Pet / Entity Events (petsim.lua, entitysystem.lua)

| Event | Type | Data Fields | Description |
|---|---|---|---|
| `entity_disease` | fire | `{entity, disease}` | Before disease is applied. Cancel to cure. |
| `entity_mood_change` | notify | `{entity, oldMood, newMood}` | After mood changes. |

#### Employee Events (employees.lua)

| Event | Type | Data Fields | Description |
|---|---|---|---|
| `employee_hired` | notify | `{employee, mode}` | After hiring. |
| `employee_production` | fire | `{employee, mode, output}` | Before production resolves. |

### 5.3 Integration Points in Existing Code

Here is exactly where event fire/notify calls need to be inserted in existing files:

**rpg_combat.lua** -- In `startCombat()` function (around line 80+):
```lua
-- At the beginning of startCombat:
local eventData = Events.fire("combat_start", {
    player = state.player,
    enemies = enemies,
    location = state.player.location,
})
if eventData._cancelled then return end
```

**forge.lua** -- In the crafting completion handler:
```lua
-- After CraftingCore.createCraftedItem():
local eventData = Events.fire("craft_complete", {
    recipe = recipe,
    mode = "forge",
    item = craftedItem,
    rarity = rarity,
    quality = quality,
})
craftedItem = eventData.item  -- Mods may have modified it
```

**progression.lua** -- In `Progression.addXP()`:
```lua
-- Before applying XP:
local eventData = Events.fire("xp_gained", {
    amount = amount,
    mode = modeId,
    source = "progression",
})
if eventData._cancelled then return end
amount = eventData.amount  -- Mods may have modified XP amount
```

---

## 6. Sandboxing

### 6.1 Sandboxed Environment

Mods execute in a restricted Lua environment that only exposes safe functions. This prevents mods from accessing the file system, executing OS commands, or corrupting game state directly.

```lua
-- modding/sandbox.lua

local Sandbox = {}

-- Whitelist of safe standard library functions
local SAFE_GLOBALS = {
    -- Basic
    "assert", "error", "ipairs", "next", "pairs", "pcall", "xpcall",
    "select", "tonumber", "tostring", "type", "unpack",
    "setmetatable", "getmetatable", "rawget", "rawset", "rawequal",

    -- Math
    "math",

    -- String
    "string",

    -- Table
    "table",

    -- Print (redirected to mod-specific log)
    -- "print" is handled separately below
}

-- Safe subset of math/string/table (full copies since they are read-only)
local SAFE_MATH = {}
for k, v in pairs(math) do SAFE_MATH[k] = v end

local SAFE_STRING = {}
for k, v in pairs(string) do SAFE_STRING[k] = v end

local SAFE_TABLE = {}
for k, v in pairs(table) do SAFE_TABLE[k] = v end

-- Create a sandboxed environment for a mod
function Sandbox.createEnvironment(manifest)
    local env = {}

    -- Copy safe globals
    for _, name in ipairs(SAFE_GLOBALS) do
        env[name] = _G[name]
    end

    -- Safe library copies
    env.math = SAFE_MATH
    env.string = SAFE_STRING
    env.table = SAFE_TABLE

    -- Redirected print
    env.print = function(...)
        local args = {...}
        local parts = {}
        for i, v in ipairs(args) do
            parts[i] = tostring(v)
        end
        print("[MOD:" .. manifest.id .. "] " .. table.concat(parts, "\t"))
    end

    -- BLOCKED: os, io, loadfile, dofile, load, loadstring, rawget on _G,
    --          love.filesystem (direct), require (replaced with safe version)
    env.os = {
        time = os.time,
        clock = os.clock,
        difftime = os.difftime,
        date = os.date,
        -- os.execute, os.remove, os.rename, os.exit: BLOCKED
    }

    -- No access to _G
    env._G = env

    return env
end

-- Create a safe require function for a mod
-- Only allows requiring the mod's own files and whitelisted game modules
function Sandbox.createRequire(manifest)
    local modPath = manifest._path

    -- Modules mods are allowed to require from the game
    local ALLOWED_GAME_MODULES = {
        ["modding.modapi"] = true,
        ["modding.registry"] = true,
        ["modding.events"] = true,
        ["modding.modutils"] = true,
    }

    return function(moduleName)
        -- Check if it is a whitelisted game module
        if ALLOWED_GAME_MODULES[moduleName] then
            return require(moduleName)
        end

        -- Try loading from the mod's own directory
        local modFilePath = modPath .. "/" .. moduleName:gsub("%.", "/") .. ".lua"
        if love.filesystem.getInfo(modFilePath) then
            -- Check cache
            local cacheKey = manifest.id .. ":" .. moduleName
            if package.loaded[cacheKey] then
                return package.loaded[cacheKey]
            end

            local chunk, err = love.filesystem.load(modFilePath)
            if not chunk then
                error("Mod require failed for '" .. moduleName .. "': " .. tostring(err))
            end

            -- Run in the mod's sandbox
            local env = Sandbox.createEnvironment(manifest)
            env.ModAPI = require("modding.modapi").createForMod(manifest)
            env.require = Sandbox.createRequire(manifest)
            setfenv(chunk, env)

            local ok, result = pcall(chunk)
            if not ok then
                error("Mod require runtime error in '" .. moduleName .. "': " .. tostring(result))
            end

            package.loaded[cacheKey] = result or true
            return result
        end

        error("Module '" .. moduleName .. "' not found (mod: " .. manifest.id .. ")")
    end
end

-- Wrap a mod callback so errors do not crash the game
function Sandbox.safeCall(modId, fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then
        print("[Sandbox] Error in mod '" .. modId .. "': " .. tostring(result))
        return nil
    end
    return result
end

return Sandbox
```

### 6.2 Error Isolation

If a mod throws an error, the game must not crash. All event callbacks are already wrapped in `pcall` in the Events system. For mod update/draw hooks, the mod loader wraps them too:

```lua
-- In main.lua love.update, after the base game update:
for _, modId in ipairs(ModLoader.loadOrder) do
    local manifest = ModLoader.loadedMods[modId]
    if manifest._module and manifest._module.update then
        local ok, err = pcall(manifest._module.update, dt)
        if not ok then
            print("[ModLoader] Error in " .. modId .. ".update: " .. tostring(err))
            -- Optionally disable the mod after N errors
            manifest._errorCount = (manifest._errorCount or 0) + 1
            if manifest._errorCount > 100 then
                print("[ModLoader] Disabling " .. modId .. " due to repeated errors")
                manifest._disabled = true
            end
        end
    end
end
```

---

## 7. Mod-Specific Save Data

### 7.1 Mod Save System

Each mod gets its own isolated save data that lives alongside the main save but does not contaminate it. If a mod is removed, its save data is simply ignored.

```lua
-- modding/modsave.lua

local ModSave = {}

-- Get the file path for a mod's save data in a specific slot
function ModSave.getFilePath(modId, slot)
    return string.format("mod_data/%s_slot_%d.lua", modId, slot)
end

-- Save mod data for current slot
function ModSave.save(modId, data)
    local slot = require("savesystem").activeSlot
    local path = ModSave.getFilePath(modId, slot)

    -- Ensure directory exists
    local dir = "mod_data"
    if not love.filesystem.getInfo(dir) then
        love.filesystem.createDirectory(dir)
    end

    -- Serialize using SaveSystem's serializer
    local SaveSystem = require("savesystem")
    local content = "return " .. SaveSystem.serializeTable(data)

    local ok, err = pcall(function()
        love.filesystem.write(path, content)
    end)

    if not ok then
        print("[ModSave] Failed to save data for " .. modId .. ": " .. tostring(err))
    end

    return ok
end

-- Load mod data for current slot
function ModSave.load(modId)
    local slot = require("savesystem").activeSlot
    local path = ModSave.getFilePath(modId, slot)

    if not love.filesystem.getInfo(path) then
        return {}  -- No saved data yet
    end

    local success, chunk = pcall(love.filesystem.load, path)
    if success and chunk then
        local env = {}
        setfenv(chunk, env)
        local ok, data = pcall(chunk)
        if ok and type(data) == "table" then
            return data
        end
    end

    print("[ModSave] Failed to load data for " .. modId .. ", returning empty")
    return {}
end

-- Delete mod data for a specific mod across all slots
function ModSave.deleteModData(modId)
    for slot = 1, 3 do
        local path = ModSave.getFilePath(modId, slot)
        if love.filesystem.getInfo(path) then
            love.filesystem.remove(path)
        end
    end
end

-- Get total size of mod save data
function ModSave.getModDataSize(modId)
    local total = 0
    for slot = 1, 3 do
        local path = ModSave.getFilePath(modId, slot)
        local info = love.filesystem.getInfo(path)
        if info then
            total = total + info.size
        end
    end
    return total
end

return ModSave
```

### 7.2 Integration with Main Save System

In `savesystem.lua`, after saving/loading base data, notify mods:

```lua
-- In SaveSystem.saveSlot(), after successful base save:
local Events = require("modding.events")
Events.notify("game_save", {slot = slot, data = data})

-- In SaveSystem.loadSlot(), after successful base load:
Events.notify("game_load", {slot = slot, data = data})
```

### 7.3 Save Data Safety

The base game save format remains unchanged. Mod save data is entirely separate:

```
%APPDATA%/LOVE/taverntimes/
  save_slot_1.lua           -- Base game save (unchanged format)
  save_slot_1.lua.bak       -- Backup
  save_slot_2.lua
  save_slot_3.lua
  mod_settings.lua          -- Which mods are enabled
  mod_data/
    epic_swords_slot_1.lua  -- Mod save data per slot
    epic_swords_slot_2.lua
    my_quest_mod_slot_1.lua
```

If a mod is uninstalled, its files under `mod_data/` remain harmless. The mod manager UI offers a "Clean Mod Data" button to remove orphaned save files.

---

## 8. Mod Manager UI

### 8.1 UI Design

The mod manager is accessible from the main menu as a new button. It uses the existing `UI` component library.

```lua
-- modding/modmanager_ui.lua

local ModManagerUI = {}
local UI = require("ui")
local ModLoader = require("modding.modloader")
local Registry = require("modding.registry")
local ModSave = require("modding.modsave")
local Theme = require("theme")

local state = {
    active = false,
    availableMods = {},      -- All discovered mods
    enabledMods = {},        -- Set of enabled mod IDs
    selectedMod = nil,       -- Currently selected mod for details
    scrollOffset = 0,
    tab = "installed",       -- "installed", "details", "load_order", "conflicts"
    pendingChanges = false,  -- True if enable/disable changed since last apply
    errors = {},

    -- UI components
    modList = nil,
    detailPanel = nil,
    buttons = {},
}

function ModManagerUI.init()
    state.active = true
    state.availableMods = ModLoader.discover()

    -- Load current enabled state
    local enabledList = ModLoader.getEnabledMods()
    state.enabledMods = enabledList

    -- Build UI
    local screenW, screenH = love.graphics.getDimensions()
    ModManagerUI.buildUI(screenW, screenH)
end

function ModManagerUI.isActive()
    return state.active
end

function ModManagerUI.buildUI(screenW, screenH)
    -- Left panel: Mod list (300px wide)
    -- Right panel: Selected mod details
    -- Bottom bar: Apply, Cancel, Refresh buttons

    state.modList = UI.List.new({
        x = 20, y = 80,
        w = 300, h = screenH - 160,
        itemHeight = 60,
    })

    -- Populate list
    local items = {}
    for modId, manifest in pairs(state.availableMods) do
        table.insert(items, {
            id = modId,
            label = manifest.name,
            sublabel = "v" .. manifest.version .. " by " .. manifest.author,
            enabled = state.enabledMods[modId] or false,
            manifest = manifest,
        })
    end
    table.sort(items, function(a, b)
        return a.label < b.label
    end)

    state.modListItems = items
end

function ModManagerUI.draw()
    if not state.active then return end

    local screenW, screenH = love.graphics.getDimensions()

    -- Background overlay
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(28))
    love.graphics.print("Mod Manager", 20, 20)

    -- Mod count
    love.graphics.setFont(UI.fonts.get(14))
    love.graphics.setColor(0.6, 0.6, 0.6)
    local enabledCount = 0
    for _ in pairs(state.enabledMods) do enabledCount = enabledCount + 1 end
    love.graphics.print(enabledCount .. " mods enabled, "
        .. Registry.count("items") .. " items registered", 20, 55)

    -- Left panel: mod list
    love.graphics.setColor(0.12, 0.14, 0.18)
    love.graphics.rectangle("fill", 10, 75, 310, screenH - 150, 8, 8)

    love.graphics.setFont(UI.fonts.get(16))
    local y = 80
    for i, item in ipairs(state.modListItems) do
        local itemY = y + (i - 1) * 64 - state.scrollOffset
        if itemY > 75 and itemY < screenH - 80 then
            -- Highlight selected
            if state.selectedMod == item.id then
                love.graphics.setColor(0.2, 0.3, 0.4)
            else
                love.graphics.setColor(0.15, 0.17, 0.22)
            end
            love.graphics.rectangle("fill", 15, itemY, 300, 58, 4, 4)

            -- Enabled indicator
            if item.enabled then
                love.graphics.setColor(0.3, 0.8, 0.4)
                love.graphics.circle("fill", 30, itemY + 29, 6)
            else
                love.graphics.setColor(0.4, 0.4, 0.4)
                love.graphics.circle("line", 30, itemY + 29, 6)
            end

            -- Mod name
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(item.label, 45, itemY + 8)

            -- Version/author
            love.graphics.setColor(0.5, 0.5, 0.5)
            love.graphics.setFont(UI.fonts.get(12))
            love.graphics.print(item.sublabel, 45, itemY + 30)
            love.graphics.setFont(UI.fonts.get(16))
        end
    end

    -- Right panel: selected mod details
    if state.selectedMod then
        local manifest = state.availableMods[state.selectedMod]
        if manifest then
            local detailX = 340
            love.graphics.setColor(0.12, 0.14, 0.18)
            love.graphics.rectangle("fill", detailX, 75, screenW - detailX - 10, screenH - 150, 8, 8)

            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(UI.fonts.get(22))
            love.graphics.print(manifest.name, detailX + 15, 85)

            love.graphics.setFont(UI.fonts.get(14))
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.print("Version: " .. manifest.version, detailX + 15, 115)
            love.graphics.print("Author: " .. manifest.author, detailX + 15, 135)

            if manifest.description then
                love.graphics.setColor(0.9, 0.9, 0.9)
                love.graphics.printf(manifest.description, detailX + 15, 165, screenW - detailX - 40)
            end

            -- Error display
            if ModLoader.errors[state.selectedMod] then
                love.graphics.setColor(0.9, 0.3, 0.3)
                love.graphics.printf("Error: " .. ModLoader.errors[state.selectedMod],
                    detailX + 15, 220, screenW - detailX - 40)
            end
        end
    end

    -- Bottom bar
    love.graphics.setColor(0.1, 0.1, 0.15)
    love.graphics.rectangle("fill", 0, screenH - 60, screenW, 60)

    -- Pending changes indicator
    if state.pendingChanges then
        love.graphics.setColor(0.9, 0.7, 0.2)
        love.graphics.setFont(UI.fonts.get(14))
        love.graphics.print("Changes pending - restart required to apply", 20, screenH - 40)
    end

    love.graphics.setColor(1, 1, 1)
end

function ModManagerUI.update(dt)
    -- UI animations, etc.
end

function ModManagerUI.keypressed(key)
    if key == "escape" then
        state.active = false
        return true
    end
end

function ModManagerUI.mousepressed(x, y, button)
    -- Handle mod list clicks
    local listY = 80
    for i, item in ipairs(state.modListItems) do
        local itemY = listY + (i - 1) * 64 - state.scrollOffset
        if x >= 15 and x <= 315 and y >= itemY and y <= itemY + 58 then
            if button == 1 then
                state.selectedMod = item.id
            end
            return true
        end
    end
end

function ModManagerUI.toggleMod(modId)
    if state.enabledMods[modId] then
        state.enabledMods[modId] = nil
    else
        state.enabledMods[modId] = true
    end
    state.pendingChanges = true

    -- Update item list
    for _, item in ipairs(state.modListItems) do
        if item.id == modId then
            item.enabled = state.enabledMods[modId] or false
        end
    end
end

function ModManagerUI.applyChanges()
    -- Save enabled list
    local enabledList = {}
    for modId, _ in pairs(state.enabledMods) do
        table.insert(enabledList, modId)
    end
    table.sort(enabledList)
    ModLoader.saveEnabledMods(enabledList)

    state.pendingChanges = false
    -- Changes take effect on next game restart
end

function ModManagerUI.close()
    state.active = false
end

return ModManagerUI
```

---

## 9. Editor Integration

The editor suite at `F:\LOVE\LOVEGAME_work\editor_suite\` is a separate LOVE2D application (its own `conf.lua` with `t.identity = "tavern_editor"`). It has editors for NPCs, prefabs, etc. under `editor_suite/editors/` and exports to `editor_suite/exports/`.

### 9.1 Export Format

The editor should export mod-compatible packages. Each export creates a folder structure matching the mod format:

```
editor_suite/exports/
  my_content_pack/
    mod.lua           -- Auto-generated manifest
    init.lua          -- Auto-generated registration code
    data/
      items.lua       -- Exported item definitions
      enemies.lua     -- Exported enemy definitions
      npcs.lua        -- Exported NPC definitions
    assets/
      icons/          -- Copied icon files
      sprites/        -- Copied sprite files
```

### 9.2 Editor Export Function

Add to the editor suite a new exporter module:

```lua
-- editor_suite/exports/mod_exporter.lua

local ModExporter = {}

-- Export project data as a mod package
function ModExporter.export(projectData, outputDir)
    -- 1. Generate mod.lua manifest
    local manifest = string.format([[return {
    id = "%s",
    name = "%s",
    version = "1.0.0",
    api_version = 1,
    author = "%s",
    description = "%s",
    main = "init.lua",
}
]], projectData.id, projectData.name, projectData.author or "Editor", projectData.description or "")

    -- 2. Generate init.lua with registrations
    local initCode = [[local ModAPI = ModAPI  -- Injected by mod loader

]]

    -- Register items
    if projectData.items and #projectData.items > 0 then
        initCode = initCode .. "-- Register items\n"
        initCode = initCode .. "local items = require('data.items')\n"
        initCode = initCode .. "for _, item in ipairs(items) do\n"
        initCode = initCode .. "    ModAPI.registerItem(item)\n"
        initCode = initCode .. "end\n\n"
    end

    -- Register enemies
    if projectData.enemies and #projectData.enemies > 0 then
        initCode = initCode .. "-- Register enemies\n"
        initCode = initCode .. "local enemies = require('data.enemies')\n"
        initCode = initCode .. "for _, enemy in ipairs(enemies) do\n"
        initCode = initCode .. "    ModAPI.registerEnemy(enemy)\n"
        initCode = initCode .. "end\n\n"
    end

    -- Register NPCs
    if projectData.npcs and #projectData.npcs > 0 then
        initCode = initCode .. "-- Register NPCs\n"
        initCode = initCode .. "local npcs = require('data.npcs')\n"
        initCode = initCode .. "for _, npc in ipairs(npcs) do\n"
        initCode = initCode .. "    ModAPI.registerNPCTemplate(npc)\n"
        initCode = initCode .. "end\n\n"
    end

    -- 3. Generate data files
    -- Each data file returns a Lua table array

    -- 4. Copy referenced assets into assets/ subfolder

    return {
        manifest = manifest,
        init = initCode,
        -- dataFiles, assetFiles...
    }
end

return ModExporter
```

### 9.3 One-Click Export Workflow

In the editor UI, add an "Export as Mod" button that:

1. Validates all content has required fields (id, name, etc.)
2. Calls `ModExporter.export()` to generate all files
3. Writes the mod folder to `editor_suite/exports/<mod_id>/`
4. Shows "Copy to mods folder?" prompt
5. If yes, copies to `mods/<mod_id>/` in the game's source directory

---

## 10. Asset Modding

### 10.1 How Mods Add Assets

Mods include assets in their `assets/` subdirectory. The ModAPI provides functions to load and register them.

```lua
-- In a mod's init.lua:

-- Load a sprite from the mod's assets folder
local swordIcon = ModAPI.loadImage("assets/icons/flame_sword.png")

-- Register an item that uses the mod's icon
ModAPI.registerItem({
    id = "flame_sword",
    name = "Flame Sword",
    category = "weapon",
    icon = "mods/epic_swords/assets/icons/flame_sword.png",  -- Full path
    stackable = false,
    desc = "A sword wreathed in eternal flame",
    sellValue = 500,
    weight = 3.5,
    baseStats = {damage = 45},
})
```

### 10.2 Asset Loading in ModAPI

```lua
-- modding/modapi.lua (asset section)

-- Load an image from the mod's directory
function modApi.loadImage(relativePath)
    local fullPath = manifest._path .. "/" .. relativePath
    if love.filesystem.getInfo(fullPath) then
        local ok, img = pcall(love.graphics.newImage, fullPath)
        if ok then return img end
    end
    print("[ModAPI:" .. manifest.id .. "] Failed to load image: " .. relativePath)
    return nil
end

-- Load audio from the mod's directory
function modApi.loadAudio(relativePath, sourceType)
    sourceType = sourceType or "static"
    local fullPath = manifest._path .. "/" .. relativePath
    if love.filesystem.getInfo(fullPath) then
        local ok, src = pcall(love.audio.newSource, fullPath, sourceType)
        if ok then return src end
    end
    print("[ModAPI:" .. manifest.id .. "] Failed to load audio: " .. relativePath)
    return nil
end

-- Register a new music track
function modApi.registerMusicTrack(category, relativePath)
    local fullPath = manifest._path .. "/" .. relativePath
    if not love.filesystem.getInfo(fullPath) then
        print("[ModAPI:" .. manifest.id .. "] Music file not found: " .. relativePath)
        return false
    end

    -- category: "menu", "combat", "exploration", "town"
    local trackLists = {
        menu = AudioSystem.menuTracks,
        combat = AudioSystem.combatTracks,
        exploration = AudioSystem.explorationTracks,
        town = AudioSystem.townTracks,
    }

    local list = trackLists[category]
    if list then
        table.insert(list, fullPath)
        return true
    end
    return false
end
```

### 10.3 Portrait and Sprite Registration

For LPC sprites and character portraits used by `rpg_data.lua` portrait mappings and `assetpipeline.lua`:

```lua
-- Register a new portrait mapping for a mod-added creature/NPC
ModAPI.registerPortrait("flame_golem", "mods/epic_swords/assets/sprites/flame_golem.png")

-- Register a new LPC tileset
ModAPI.registerTileset("volcanic_terrain", "mods/epic_swords/assets/tilesets/volcanic.png")
```

### 10.4 UI Theme Overrides

Mods can override the UI theme colors defined in `theme.lua` and `ui.lua`:

```lua
-- Override a specific theme color
ModAPI.setThemeColor("primary", {0.8, 0.2, 0.2})  -- Red theme
ModAPI.setThemeColor("bg", {0.05, 0.02, 0.02})     -- Dark red background

-- Or provide a full theme table
ModAPI.setTheme({
    colors = {
        primary = {0.8, 0.2, 0.2},
        -- ... only specify overrides, others keep defaults
    }
})
```

---

## 11. Migration Strategy

### 11.1 Phased Approach

The migration converts hardcoded local tables to registry-backed collections without breaking the game. Each phase is independently shippable.

### Phase 1: Add Getter Functions (Non-Breaking)

Add getter functions to every module that has local data tables, so the registration code can access them. **This changes no behavior.**

**Files to modify:**

**forge.lua** -- Expose RECIPES:
```lua
-- Add at the end of forge.lua, before "return Forge":
function Forge.getRecipes()
    return RECIPES
end
```

**wizardtower.lua** -- Expose RECIPES:
```lua
function WizardTower.getRecipes()
    return RECIPES
end
```

**alchemist.lua** -- Expose RECIPES:
```lua
function Alchemist.getRecipes()
    return RECIPES
end
```

**fishing.lua** -- Expose data tables:
```lua
function Fishing.getFishTypes()
    return FISH_TYPES
end
function Fishing.getLootItems()
    return LOOT_ITEMS
end
function Fishing.getTreasureItems()
    return TREASURE_ITEMS
end
function Fishing.getJunkItems()
    return JUNK_ITEMS
end
```

**hunting.lua** -- Expose ANIMALS:
```lua
function Hunting.getAnimals()
    return ANIMALS
end
```

**mapenemies.lua** -- Expose MAP_ENEMY_TYPES:
```lua
function MapEnemies.getEnemyTypes()
    return MAP_ENEMY_TYPES
end
```

**dungeonenemies.lua** -- Expose DUNGEON_ENEMY_VISUALS:
```lua
function DungeonEnemies.getEnemyVisuals()
    return DUNGEON_ENEMY_VISUALS
end
```

**progression.lua** -- Expose MODES:
```lua
function Progression.getModes()
    return MODES
end
```

### Phase 2: Add the Modding Infrastructure (Non-Breaking)

Create all new files under `modding/`:
- `modding/modloader.lua`
- `modding/registry.lua`
- `modding/events.lua`
- `modding/sandbox.lua`
- `modding/modsave.lua`
- `modding/modapi.lua`
- `modding/modutils.lua`
- `modding/compatibility.lua`
- `modding/base_registration.lua`
- `modding/modmanager_ui.lua`

None of these affect existing code. They are purely additive.

### Phase 3: Hook Into main.lua (Minimal Changes)

Modify `main.lua` to load the mod system:

```lua
-- Add after existing requires (around line 36):
local ModLoader = require("modding.modloader")
local BaseRegistration = require("modding.base_registration")
local Events = require("modding.events")
local ModManagerUI = require("modding.modmanager_ui")

-- In love.load(), after all module inits (around line 458):
-- Register base game content into registry
BaseRegistration.registerAll()

-- Load enabled mods
ModLoader.loadAll()
```

Add mod update/draw hooks:

```lua
-- In love.update(dt), after the state module update:
Events.notify("game_tick", {dt = dt})

-- In love.draw(), before FPSCounter:
-- (Mod draw hooks are handled by events, no changes needed)

-- Add mod manager to stateModules or as overlay:
-- In love.keypressed, add F10 for mod manager:
if key == "f10" then
    if ModManagerUI.isActive() then
        ModManagerUI.close()
    else
        ModManagerUI.init()
    end
    return
end
```

### Phase 4: Convert Modules to Read from Registry (Gradual)

This is done one module at a time. Each module's data-reading code is updated to query the registry instead of local tables. **The local tables remain as fallbacks.**

Example pattern (forge.lua):

```lua
-- BEFORE:
local function getRecipeList()
    return RECIPES
end

-- AFTER (backwards compatible):
local Registry = require("modding.registry")

local function getRecipeList()
    local registered = Registry.getAll("forge_recipes")
    if #registered > 0 then
        return registered
    end
    return RECIPES  -- Fallback to local table if registry is empty
end
```

### Order of Conversion

1. `backpack.lua` (Backpack.ITEMS) -- Highest impact, items used everywhere
2. `rpg_data.lua` (Data.ENEMIES, Data.SKILLS, Data.CLASSES, Data.RACES) -- Core RPG data
3. `forge.lua`, `wizardtower.lua`, `alchemist.lua` (RECIPES) -- Crafting modes
4. `fishing.lua` (FISH_TYPES, etc.) -- Fishing content
5. `hunting.lua` (ANIMALS) -- Hunting content
6. `cards.lua` (rarities, secrets) -- Card game content
7. `mapenemies.lua`, `dungeonenemies.lua` -- Enemy visuals
8. `worldgen.lua` (DUNGEON_TYPES) -- World generation
9. `progression.lua` (MODES) -- Mode definitions
10. `entitysystem.lua` (DISEASES, etc.) -- Entity data

### Phase 5: Add Event Hooks to Game Logic

Insert Events.fire() and Events.notify() calls at all the integration points listed in Section 5.3. This is done incrementally as each module is converted.

### Phase 6: Mod Manager UI in Menu

Add the "Mods" button to `menu.lua` alongside existing buttons like Options, Credits, etc.

---

## 12. API Reference Outline

### 12.1 ModAPI Table

This is the complete API exposed to mod code via the `ModAPI` global:

```lua
-- modding/modapi.lua

local Registry = require("modding.registry")
local Events = require("modding.events")
local ModSave = require("modding.modsave")

local ModAPI_base = {}

-- Create a mod-specific API instance
function ModAPI_base.createForMod(manifest)
    local modId = manifest.id
    local modPath = manifest._path
    local api = {}

    -- ================================================================
    -- CONTENT REGISTRATION
    -- ================================================================

    -- Items (backpack.lua items)
    function api.registerItem(def)
        assert(def.id, "Item must have an id")
        assert(def.name, "Item must have a name")
        def.category = def.category or "special"
        Registry.register("items", def.id, def, modId)
    end

    -- Card rarities
    function api.registerCardRarity(def)
        assert(def.id, "Rarity must have an id")
        Registry.register("card_rarities", def.id, def, modId)
    end

    -- Secret cards
    function api.registerSecretCard(def)
        assert(def.id, "Card must have an id")
        Registry.register("secret_cards", def.id, def, modId)
    end

    -- Crafting recipes (specify mode: "forge", "wizard", "alchemy")
    function api.registerRecipe(mode, def)
        assert(def.id, "Recipe must have an id")
        local collectionMap = {
            forge = "forge_recipes",
            wizard = "wizard_recipes",
            alchemy = "alchemy_recipes",
        }
        local collection = collectionMap[mode]
        assert(collection, "Unknown crafting mode: " .. tostring(mode))
        Registry.register(collection, def.id, def, modId)
    end

    -- Fish types
    function api.registerFish(def)
        assert(def.id, "Fish must have an id")
        Registry.register("fish_types", def.id, def, modId)
    end

    -- Huntable animals
    function api.registerAnimal(def)
        assert(def.id, "Animal must have an id")
        Registry.register("animals", def.id, def, modId)
    end

    -- RPG classes
    function api.registerClass(def)
        assert(def.id, "Class must have an id")
        Registry.register("rpg_classes", def.id, def, modId)
    end

    -- RPG races
    function api.registerRace(def)
        assert(def.id, "Race must have an id")
        Registry.register("rpg_races", def.id, def, modId)
    end

    -- RPG unlockable races
    function api.registerUnlockableRace(def)
        assert(def.id, "Race must have an id")
        Registry.register("rpg_unlockable_races", def.id, def, modId)
    end

    -- RPG backgrounds
    function api.registerBackground(def)
        assert(def.id, "Background must have an id")
        Registry.register("rpg_backgrounds", def.id, def, modId)
    end

    -- RPG skills
    function api.registerSkill(name, def)
        assert(name, "Skill must have a name")
        def.id = name
        Registry.register("rpg_skills", name, def, modId)
    end

    -- RPG enemies
    function api.registerEnemy(def)
        assert(def.id, "Enemy must have an id")
        Registry.register("rpg_enemies", def.id, def, modId)
    end

    -- Damage types
    function api.registerDamageType(def)
        assert(def.id, "Damage type must have an id")
        Registry.register("rpg_damage_types", def.id, def, modId)
    end

    -- Companion classes
    function api.registerCompanionClass(def)
        assert(def.id, "Companion class must have an id")
        Registry.register("rpg_companion_classes", def.id, def, modId)
    end

    -- Dungeon types
    function api.registerDungeonType(def)
        assert(def.id, "Dungeon type must have an id")
        Registry.register("rpg_dungeon_types", def.id, def, modId)
    end

    -- Factions
    function api.registerFaction(def)
        assert(def.id, "Faction must have an id")
        Registry.register("rpg_factions", def.id, def, modId)
    end

    -- NPC templates
    function api.registerNPCTemplate(def)
        assert(def.id, "NPC template must have an id")
        Registry.register("rpg_npc_templates", def.id, def, modId)
    end

    -- Ascension tree nodes
    function api.registerAscensionNode(def)
        assert(def.id, "Ascension node must have an id")
        Registry.register("rpg_ascension_tree", def.id, def, modId)
    end

    -- Entity diseases
    function api.registerDisease(def)
        assert(def.id, "Disease must have an id")
        Registry.register("entity_diseases", def.id, def, modId)
    end

    -- Entity injuries
    function api.registerInjury(def)
        assert(def.id, "Injury must have an id")
        Registry.register("entity_injuries", def.id, def, modId)
    end

    -- Portraits
    function api.registerPortrait(id, path)
        Registry.register("portraits", id, {id = id, path = path}, modId)
    end

    -- Map enemy types
    function api.registerMapEnemyType(id, def)
        def.id = id
        Registry.register("map_enemy_types", id, def, modId)
    end

    -- Dungeon enemy visuals
    function api.registerDungeonEnemyVisual(id, def)
        def.id = id
        Registry.register("dungeon_enemy_visuals", id, def, modId)
    end

    -- Mode upgrades
    function api.registerUpgrade(mode, def)
        assert(def.id, "Upgrade must have an id")
        Registry.register("upgrades", mode .. ":" .. def.id, def, modId)
    end

    -- Progression modes (add a new game mode to the progression system)
    function api.registerProgressionMode(id, def)
        def.id = id
        Registry.register("progression_modes", id, def, modId)
    end

    -- Tile types for world generation
    function api.registerTileType(def)
        assert(def.id, "Tile type must have an id")
        Registry.register("rpg_tile_types", def.id, def, modId)
    end

    -- Trade goods
    function api.registerTradeGood(def)
        assert(def.id, "Trade good must have an id")
        Registry.register("rpg_trade_goods", def.id, def, modId)
    end

    -- Generic registration for any collection
    function api.register(collectionName, id, def)
        Registry.register(collectionName, id, def, modId)
    end

    -- ================================================================
    -- CONTENT QUERIES
    -- ================================================================

    function api.getItem(id) return Registry.get("items", id) end
    function api.getAllItems() return Registry.getAll("items") end
    function api.getEnemy(id) return Registry.get("rpg_enemies", id) end
    function api.getAllEnemies() return Registry.getAll("rpg_enemies") end
    function api.getRecipe(mode, id)
        local collectionMap = {forge="forge_recipes", wizard="wizard_recipes", alchemy="alchemy_recipes"}
        return Registry.get(collectionMap[mode] or mode, id)
    end
    function api.getClass(id) return Registry.get("rpg_classes", id) end
    function api.getRace(id) return Registry.get("rpg_races", id) end
    function api.getSkill(name) return Registry.get("rpg_skills", name) end
    function api.get(collection, id) return Registry.get(collection, id) end
    function api.getAll(collection) return Registry.getAll(collection) end
    function api.filter(collection, fn) return Registry.filter(collection, fn) end

    -- ================================================================
    -- EVENT HOOKS
    -- ================================================================

    function api.on(eventName, callback, priority)
        Events.on(eventName, callback, priority, modId)
    end

    function api.once(eventName, callback, priority)
        local function wrapper(data)
            Events.removeModListeners(modId)  -- Remove after first call
            return callback(data)
        end
        Events.on(eventName, wrapper, priority, modId)
    end

    -- ================================================================
    -- SAVE DATA
    -- ================================================================

    function api.saveData(data)
        return ModSave.save(modId, data)
    end

    function api.loadData()
        return ModSave.load(modId)
    end

    -- ================================================================
    -- ASSETS
    -- ================================================================

    function api.loadImage(relativePath)
        local fullPath = modPath .. "/" .. relativePath
        if love.filesystem.getInfo(fullPath) then
            local ok, img = pcall(love.graphics.newImage, fullPath)
            if ok then return img end
        end
        return nil
    end

    function api.loadAudio(relativePath, sourceType)
        sourceType = sourceType or "static"
        local fullPath = modPath .. "/" .. relativePath
        if love.filesystem.getInfo(fullPath) then
            local ok, src = pcall(love.audio.newSource, fullPath, sourceType)
            if ok then return src end
        end
        return nil
    end

    function api.getAssetPath(relativePath)
        return modPath .. "/" .. relativePath
    end

    function api.registerMusicTrack(category, relativePath)
        local fullPath = modPath .. "/" .. relativePath
        local trackLists = {
            menu = _G.AudioSystem and _G.AudioSystem.menuTracks,
            combat = _G.AudioSystem and _G.AudioSystem.combatTracks,
            exploration = _G.AudioSystem and _G.AudioSystem.explorationTracks,
            town = _G.AudioSystem and _G.AudioSystem.townTracks,
        }
        local list = trackLists[category]
        if list then
            table.insert(list, fullPath)
            return true
        end
        return false
    end

    -- ================================================================
    -- UI THEMING
    -- ================================================================

    function api.setThemeColor(key, color)
        local Theme = require("theme")
        if Theme.colors[key] then
            Theme.colors[key] = color
        end
        local UI = require("ui")
        if UI.theme.colors[key] then
            UI.theme.colors[key] = color
        end
    end

    -- ================================================================
    -- GAME STATE INTERACTION (read-only)
    -- ================================================================

    function api.getPlayerData()
        -- Return a shallow copy to prevent direct mutation
        if not _G.PlayerData then return {} end
        local copy = {}
        for k, v in pairs(_G.PlayerData) do
            copy[k] = v
        end
        return copy
    end

    function api.getPlayerCoins()
        return _G.PlayerData and _G.PlayerData.coins or 0
    end

    function api.getCurrentState()
        return _G.GameState and _G.GameState.current or "unknown"
    end

    -- ================================================================
    -- UTILITIES
    -- ================================================================

    function api.log(msg)
        print("[MOD:" .. modId .. "] " .. tostring(msg))
    end

    function api.getModInfo()
        return {
            id = manifest.id,
            name = manifest.name,
            version = manifest.version,
            path = modPath,
        }
    end

    function api.isModLoaded(checkModId)
        local ModLoader = require("modding.modloader")
        return ModLoader.loadedMods[checkModId] ~= nil
    end

    return api
end

return ModAPI_base
```

---

## 13. Implementation Phases

### Phase 1: Foundation (Week 1-2)

**Goal**: Modding infrastructure exists, base game unchanged.

- [ ] Create `modding/` directory
- [ ] Implement `modding/registry.lua`
- [ ] Implement `modding/events.lua`
- [ ] Implement `modding/sandbox.lua`
- [ ] Implement `modding/modsave.lua`
- [ ] Implement `modding/modloader.lua`
- [ ] Implement `modding/modapi.lua`
- [ ] Implement `modding/modutils.lua`
- [ ] Implement `modding/compatibility.lua`
- [ ] Create `mods/` directory with a `_example/` mod
- [ ] Unit test: Registry add/get/remove/filter
- [ ] Unit test: Events fire/cancel/priority
- [ ] Unit test: Sandbox blocks unsafe operations
- [ ] Unit test: Mod manifest validation

### Phase 2: Getter Migration (Week 2-3)

**Goal**: All data tables accessible via getter functions.

- [ ] Add `getRecipes()` to `forge.lua`
- [ ] Add `getRecipes()` to `wizardtower.lua`
- [ ] Add `getRecipes()` to `alchemist.lua`
- [ ] Add `getFishTypes()`, `getLootItems()`, etc. to `fishing.lua`
- [ ] Add `getAnimals()` to `hunting.lua`
- [ ] Add `getEnemyTypes()` to `mapenemies.lua`
- [ ] Add `getEnemyVisuals()` to `dungeonenemies.lua`
- [ ] Add `getModes()` to `progression.lua`
- [ ] Verify all getters return the correct tables
- [ ] No behavior changes -- all existing code still works

### Phase 3: Base Registration (Week 3-4)

**Goal**: All base game content registered through the registry.

- [ ] Implement `modding/base_registration.lua`
- [ ] Hook `BaseRegistration.registerAll()` into `love.load()` in `main.lua`
- [ ] Hook `ModLoader.loadAll()` into `love.load()` in `main.lua`
- [ ] Verify Registry.count() returns correct numbers for all collections
- [ ] Verify no startup errors or performance regression

### Phase 4: Registry Consumers (Week 4-6)

**Goal**: Game modules read from registry instead of local tables.

- [ ] Convert `backpack.lua` item lookups to use Registry
- [ ] Convert `forge.lua` recipe list to use Registry
- [ ] Convert `wizardtower.lua` recipe list to use Registry
- [ ] Convert `alchemist.lua` recipe list to use Registry
- [ ] Convert `fishing.lua` fish/loot lookups to use Registry
- [ ] Convert `hunting.lua` animal list to use Registry
- [ ] Convert `rpg_combat.lua` enemy lookups to use Registry
- [ ] Convert `rpg_core.lua` class/race lookups to use Registry
- [ ] Convert `rpg_travel.lua` encounter table to use Registry
- [ ] Convert `worldgen.lua` dungeon types to use Registry
- [ ] Convert `mapenemies.lua` enemy types to use Registry
- [ ] Test each converted module thoroughly

### Phase 5: Event Hooks (Week 6-7)

**Goal**: All game events are hookable by mods.

- [ ] Add combat events to `rpg_combat.lua`
- [ ] Add crafting events to `forge.lua`, `wizardtower.lua`, `alchemist.lua`
- [ ] Add fishing events to `fishing.lua`
- [ ] Add hunting events to `hunting.lua`
- [ ] Add travel events to `rpg_travel.lua`
- [ ] Add economy events to `backpack.lua` (item acquire/sell)
- [ ] Add progression events to `progression.lua`
- [ ] Add state change events to `main.lua`
- [ ] Add save/load events to `savesystem.lua`
- [ ] Add entity events to `entitysystem.lua`
- [ ] Test event cancellation works correctly
- [ ] Test event data modification works correctly

### Phase 6: Mod Manager UI (Week 7-8)

**Goal**: Players can manage mods in-game.

- [ ] Implement `modding/modmanager_ui.lua`
- [ ] Add "Mods" button to `menu.lua`
- [ ] Add F10 hotkey to `main.lua` for mod manager toggle
- [ ] Implement enable/disable toggle
- [ ] Implement load order display
- [ ] Implement conflict detection display
- [ ] Implement "Clean Mod Data" for orphaned saves
- [ ] Implement mod details panel (description, version, author, errors)
- [ ] Test with 0 mods, 1 mod, 5+ mods

### Phase 7: Example Mods and Documentation (Week 8-9)

**Goal**: Modders have working examples to learn from.

- [ ] Create `mods/_example_items/` -- adds 3 items
- [ ] Create `mods/_example_enemy/` -- adds 1 enemy + 1 skill
- [ ] Create `mods/_example_hooks/` -- hooks combat for bonus XP
- [ ] Create `mods/_example_full/` -- complete mod with items, enemies, recipes, hooks, save data
- [ ] Write modder documentation (MODDING_GUIDE.md)
- [ ] Document all ModAPI functions with examples

### Phase 8: Editor Integration (Week 9-10)

**Goal**: Editor exports mod-compatible packages.

- [ ] Implement `editor_suite/exports/mod_exporter.lua`
- [ ] Add "Export as Mod" button to editor UI
- [ ] Test round-trip: create content in editor -> export -> load as mod -> play
- [ ] Validate exported mod.lua manifests

---

## 14. Testing Checklist

### Registry Tests

- [ ] Register 500+ items, verify O(1) lookup by ID
- [ ] Register duplicate ID from mod, verify override tracking
- [ ] Unregister a mod, verify its content removed and originals restored
- [ ] Filter collections by category, verify correct results
- [ ] getAll() returns stable ordering

### Event Tests

- [ ] Fire event with no listeners, no crash
- [ ] Fire event with 3 listeners, verify priority ordering
- [ ] Cancel event in first listener, verify subsequent listeners not called
- [ ] Modify event data in listener, verify next listener receives modified data
- [ ] Error in listener does not crash game or skip subsequent listeners
- [ ] Remove mod listeners, verify they no longer fire

### Sandbox Tests

- [ ] Mod cannot call `os.execute`
- [ ] Mod cannot call `io.open`
- [ ] Mod cannot call `love.filesystem.write` directly
- [ ] Mod cannot access `_G` to modify game globals
- [ ] Mod cannot call `require("savesystem")` (not whitelisted)
- [ ] Mod CAN call `require("modding.modapi")`
- [ ] Mod CAN use math, string, table libraries
- [ ] Mod CAN use `os.time()` and `os.clock()`
- [ ] Mod error produces log message but game continues running
- [ ] Mod infinite loop (simulated with long computation) does not freeze game permanently

### Save Data Tests

- [ ] Save mod data, load it back, verify identical
- [ ] Switch save slots, verify mod data is per-slot
- [ ] Delete a save slot, verify mod data for that slot is unaffected (orphaned but safe)
- [ ] Uninstall a mod, verify base save is unaffected
- [ ] Mod data file is corrupted, verify graceful fallback to empty table

### Integration Tests

- [ ] Load game with 0 mods -- identical behavior to pre-modding game
- [ ] Load game with a mod that adds 1 forge recipe -- recipe appears in forge
- [ ] Load game with a mod that adds 1 enemy -- enemy can appear in combat
- [ ] Load game with a mod that hooks combat_loot_generated -- loot is modified
- [ ] Load game with a mod that adds custom music -- track plays in rotation
- [ ] Load game with a broken mod (syntax error) -- error logged, game runs fine
- [ ] Enable a mod, save, quit, relaunch -- mod is still enabled
- [ ] Disable a mod that added items -- items no longer appear, no crash

### Performance Tests

- [ ] Registry with 1000 items: lookup under 0.1ms
- [ ] Events with 50 listeners: fire under 1ms
- [ ] Mod loading (10 mods): under 500ms total
- [ ] No measurable FPS drop with 5 mods loaded (baseline 60fps)

### Backwards Compatibility Tests

- [ ] Load a save from before modding system existed -- no crash, no data loss
- [ ] PlayerData fields are all preserved through mergeWithDefaults
- [ ] Mod manager shows "No mods installed" gracefully when mods/ dir is empty

---

## Appendix A: Complete Example Mod

Here is a full working mod that adds a new sword to the forge, a new enemy, hooks combat for bonus gold, and persists kill count data:

```lua
-- mods/dragon_slayer/mod.lua
return {
    id = "dragon_slayer",
    name = "Dragon Slayer Pack",
    version = "1.0.0",
    api_version = 1,
    author = "ExampleModder",
    description = "Adds the legendary Dragon Slayer sword and a Fire Drake enemy",
    main = "init.lua",
    priority = 100,
    dependencies = {},
}
```

```lua
-- mods/dragon_slayer/init.lua

-- ModAPI is injected by the mod loader
local api = ModAPI

-- Load our persistent data
local saveData = api.loadData()
saveData.totalDrakeKills = saveData.totalDrakeKills or 0

-- Register the Dragon Slayer sword as a backpack item
api.registerItem({
    id = "dragon_slayer_sword",
    name = "Dragon Slayer",
    category = "weapon",
    icon = api.getAssetPath("assets/icons/dragon_slayer.png"),
    stackable = false,
    desc = "A legendary blade forged to slay dragons. +50% damage vs dragons.",
    sellValue = 2000,
    weight = 5.0,
    baseStats = {damage = 60},
})

-- Register it as a forge recipe
api.registerRecipe("forge", {
    id = "dragon_slayer_sword",
    name = "Dragon Slayer",
    category = "weapon",
    materials = {
        {id = "mythril_shard", qty = 10},
        {id = "dragon_scale", qty = 5},
        {id = "phoenix_feather", qty = 2},
    },
    goldCost = 5000,
    craftTime = 30,
    skillRequired = 20,
    baseStats = {damage = 60},
    icon = api.getAssetPath("assets/icons/dragon_slayer.png"),
})

-- Register the Fire Drake enemy
api.registerEnemy({
    id = "fire_drake",
    name = "Fire Drake",
    cr = 5,
    portrait = "D",
    hpMult = 2.0,
    atkMult = 1.5,
    defMult = 1.2,
    xpMult = 4.0,
    goldMult = 3.0,
    attacks = {"Fire Breath", "Tail Swipe", "Wing Gust", "Inferno"},
    resistances = {fire = 0.9, ice = -0.5},
    attackType = "magic",
    attackRange = 4,
    damageType = "fire",
})

-- Register portrait for the Fire Drake
api.registerPortrait("fire_drake", api.getAssetPath("assets/sprites/fire_drake.png"))

-- Hook: Bonus gold when killing dragons
api.on("combat_enemy_defeated", function(data)
    if data.enemy and data.enemy.id == "fire_drake" then
        -- Track kills
        saveData.totalDrakeKills = saveData.totalDrakeKills + 1
        api.saveData(saveData)

        api.log("Fire Drake killed! Total: " .. saveData.totalDrakeKills)
    end
end)

-- Hook: Dragon Slayer does bonus damage vs drake enemies
api.on("combat_player_attack", function(data)
    -- Check if player has the dragon slayer equipped (simplified check)
    if data.target and data.target.id == "fire_drake" then
        -- Check player equipment for dragon_slayer_sword
        -- (In a real mod, you would check the player's equipped weapon)
        data.damage = math.floor(data.damage * 1.5)
        api.log("Dragon Slayer bonus! Damage boosted to " .. data.damage)
    end
    return data
end)

-- Return module table for lifecycle hooks
return {
    update = function(dt)
        -- Called every frame (optional)
    end,
    draw = function()
        -- Called every frame after game draw (optional)
    end,
}
```

---

## Appendix B: New Game Mode Registration (Advanced)

Mods can register entirely new game modes that appear in the game mode list. This is the most advanced form of modding.

```lua
-- In a mod's init.lua:

-- Define the game mode module
local MyMinigame = {}

function MyMinigame.init()
    -- Initialize the minigame state
end

function MyMinigame.update(dt)
    -- Update logic
end

function MyMinigame.draw()
    -- Draw the minigame
end

function MyMinigame.keypressed(key)
    if key == "escape" then
        -- Return to menu
    end
end

function MyMinigame.mousepressed(x, y, button)
    -- Handle clicks
end

-- Register as a game state
ModAPI.register("state_modules", "my_minigame", {
    id = "my_minigame",
    module = MyMinigame,
})

-- Register in progression system
ModAPI.registerProgressionMode("my_minigame", {
    name = "My Minigame",
    icon = "G",
})
```

The mod loader, when processing `state_modules` registrations, adds them to the `stateModules` table in `main.lua`:

```lua
-- In ModLoader.loadAll(), after all mods are loaded:
local stateModEntries = Registry.getAll("state_modules")
for _, entry in ipairs(stateModEntries) do
    if entry.module and entry._owner ~= "_base" then
        -- Add mod game modes to the state dispatch table
        stateModules[entry.id] = entry.module
    end
end
```

---

## Appendix C: Configuration Values

All tunable values that affect modding behavior:

| Constant | Location | Default | Description |
|---|---|---|---|
| `CURRENT_API_VERSION` | modloader.lua | `1` | Current mod API version |
| `MODS_DIR` | modloader.lua | `"mods"` | Directory to scan for mods |
| `MOD_MANIFEST` | modloader.lua | `"mod.lua"` | Required manifest filename |
| `MAX_MOD_ERRORS` | modloader.lua | `100` | Errors before auto-disable |
| `MOD_SAVE_DIR` | modsave.lua | `"mod_data"` | Directory for mod save files |

---

## Appendix D: Security Considerations

1. **No file system write access**: Mods cannot use `love.filesystem.write` directly. All persistence goes through `ModAPI.saveData()`.
2. **No OS execution**: `os.execute`, `io.popen`, `io.open` are blocked.
3. **No code loading**: `load`, `loadstring`, `loadfile`, `dofile` are blocked. Only the sandboxed `require` works.
4. **No global mutation**: Mods cannot modify `_G`, `GameState`, or `PlayerData` directly.
5. **Error containment**: All mod callbacks run inside `pcall`. A crashing mod does not crash the game.
6. **Save isolation**: Mod save data is separate from base saves. A broken mod cannot corrupt a player's save file.
7. **Manifest validation**: Mod IDs must match `[a-z][a-z0-9_]*`. No path traversal is possible through mod IDs.
