-- ==========================================================================
-- Data Schema Definitions for the LOVE2D RPG Editor Suite
-- ==========================================================================
-- Field definitions for every editable entity type. Each schema is a list of
-- field descriptors consumed by the PropertyGrid, validation helpers, and
-- serialization layer.
--
-- Field descriptor format:
--   key       (string)   Lua table key on the entity
--   label     (string)   Human-readable label for the UI
--   type      (string)   One of: string, number, boolean, text, select,
--                         multiselect, color, table, array, tags
--   default   (any)      Default value for new entities
--   required  (boolean)  Marks the field as mandatory
--   min/max   (number)   Range constraints for number fields
--   step      (number)   Slider increment for number fields
--   options   (table)    Allowed values for select / multiselect fields
--   condition (function) entity -> boolean; field shown only when true
--   category  (string)   Used to group fields in the PropertyGrid
--   tooltip   (string)   Help text displayed on hover
-- ==========================================================================

local Schema = {}

-- =========================================================================
-- Shared option lists (kept in one place so schemas stay DRY)
-- =========================================================================

local ITEM_CATEGORIES = {
    "consumable", "food", "material", "ore", "weapon", "armor", "spell",
    "potion", "poison", "treasure", "special", "tool", "trap", "tome",
    "ammo", "throwable", "trophy", "transport", "seed",
}

local TOOL_TYPES = { "lumber", "mining" }

local SEASONS = { "brightbloom", "sunreign", "ashwane", "frosthollow" }

local SEED_RARITIES = { "common", "uncommon", "rare", "epic", "legendary" }

local DAMAGE_TYPES = {
    "physical", "fire", "ice", "lightning", "holy", "poison", "dark", "arcane",
}

local ATTACK_TYPES = { "melee", "magic" }

local ELEMENT_TYPES = {
    "physical", "fire", "ice", "lightning", "holy", "poison", "dark", "arcane",
}

local QUEST_TYPES = {
    "collect", "kill", "delivery", "donation", "escort", "puzzle", "boss",
}

local NPC_PROFESSIONS = {
    "shopkeeper", "blacksmith", "priest", "tavernkeep", "stablemaster",
    "alchemist", "wizard", "fisher", "hunter", "merchant", "butcher",
    "baker", "tailor", "jeweler", "wellkeeper", "land_commissioner",
}

local LORE_CATEGORIES = {
    "covenant", "racial_elf", "racial_dwarf", "racial_orc", "racial_goblin",
    "dominion", "historical", "personal", "religious", "mythology", "culture",
    "theory",
}

local LORE_RARITIES = { "common", "uncommon", "rare", "epic", "legendary" }

local MAP_MODES = { "dungeon", "town", "world" }

local STAT_NAMES = {
    "MIGHT", "VIGOR", "AGILITY", "MIND", "PRESENCE", "SPIRIT", "FAITH",
}

local UNLOCK_TYPES = { "none", "metric", "location", "achievement" }

-- =========================================================================
-- 1. ItemSchema  (matches Backpack.ITEMS)
-- =========================================================================

Schema.ItemSchema = {
    -- Identity
    {
        key = "id",
        label = "ID",
        type = "string",
        default = "",
        required = true,
        category = "identity",
        tooltip = "Unique item identifier (auto-generated from name if blank)",
    },
    {
        key = "name",
        label = "Name",
        type = "string",
        default = "",
        required = true,
        category = "identity",
        tooltip = "Display name of the item",
    },
    {
        key = "category",
        label = "Category",
        type = "select",
        options = ITEM_CATEGORIES,
        default = "consumable",
        required = true,
        category = "identity",
        tooltip = "Item type category",
    },
    {
        key = "icon",
        label = "Icon",
        type = "string",
        default = "",
        category = "identity",
        tooltip = "Path to icon asset (e.g. assets/icons/...)",
    },
    {
        key = "desc",
        label = "Description",
        type = "text",
        default = "",
        category = "identity",
        tooltip = "In-game description of the item",
    },

    -- Stacking
    {
        key = "stackable",
        label = "Stackable",
        type = "boolean",
        default = true,
        category = "stacking",
        tooltip = "Whether multiple items occupy one inventory slot",
    },
    {
        key = "maxStack",
        label = "Max Stack",
        type = "number",
        default = 99,
        min = 1,
        max = 999,
        step = 1,
        category = "stacking",
        tooltip = "Maximum number of items per stack",
        condition = function(entity) return entity.stackable == true end,
    },

    -- Economics / weight
    {
        key = "sellValue",
        label = "Sell Value",
        type = "number",
        default = 0,
        min = 0,
        step = 1,
        category = "economics",
        tooltip = "Gold received when selling to a shop",
    },
    {
        key = "weight",
        label = "Weight",
        type = "number",
        default = 1.0,
        min = 0,
        step = 0.1,
        category = "economics",
        tooltip = "Item weight in pounds (affects encumbrance)",
    },

    -- Base stats (combat / consumable effects)
    {
        key = "baseStats.damage",
        label = "Damage",
        type = "number",
        default = 0,
        min = 0,
        step = 1,
        category = "baseStats",
        tooltip = "Base weapon damage",
    },
    {
        key = "baseStats.defense",
        label = "Defense",
        type = "number",
        default = 0,
        min = 0,
        step = 1,
        category = "baseStats",
        tooltip = "Base armor defense",
    },
    {
        key = "baseStats.healing",
        label = "Healing",
        type = "number",
        default = 0,
        min = 0,
        step = 1,
        category = "baseStats",
        tooltip = "HP restored on use",
    },
    {
        key = "baseStats.manaCost",
        label = "Mana Cost",
        type = "number",
        default = 0,
        min = 0,
        step = 1,
        category = "baseStats",
        tooltip = "Mana required to use this item",
    },
    {
        key = "baseStats.bonusDamage",
        label = "Bonus Damage",
        type = "number",
        default = 0,
        min = 0,
        step = 1,
        category = "baseStats",
        tooltip = "Additional damage bonus",
    },
    {
        key = "baseStats.bonusDefense",
        label = "Bonus Defense",
        type = "number",
        default = 0,
        min = 0,
        step = 1,
        category = "baseStats",
        tooltip = "Additional defense bonus",
    },
    {
        key = "baseStats.duration",
        label = "Duration",
        type = "number",
        default = 0,
        min = 0,
        step = 1,
        category = "baseStats",
        tooltip = "Effect duration in seconds",
    },
    {
        key = "baseStats.dotDamage",
        label = "DoT Damage",
        type = "number",
        default = 0,
        min = 0,
        step = 1,
        category = "baseStats",
        tooltip = "Damage over time per tick",
    },
    {
        key = "baseStats.stunChance",
        label = "Stun Chance",
        type = "number",
        default = 0,
        min = 0,
        max = 100,
        step = 1,
        category = "baseStats",
        tooltip = "Percent chance to stun target",
    },
    {
        key = "baseStats.slowEffect",
        label = "Slow Effect",
        type = "number",
        default = 0,
        min = 0,
        max = 100,
        step = 1,
        category = "baseStats",
        tooltip = "Percent movement speed reduction",
    },

    -- Tool fields
    {
        key = "toolType",
        label = "Tool Type",
        type = "select",
        options = TOOL_TYPES,
        default = "lumber",
        category = "tool",
        tooltip = "What kind of gathering this tool performs",
        condition = function(entity) return entity.category == "tool" end,
    },
    {
        key = "efficiency",
        label = "Efficiency",
        type = "number",
        default = 1.0,
        min = 0.1,
        max = 5.0,
        step = 0.1,
        category = "tool",
        tooltip = "Tool effectiveness multiplier (1.0 = baseline)",
        condition = function(entity) return entity.category == "tool" end,
    },

    -- Seed fields
    {
        key = "growthDays",
        label = "Growth Days",
        type = "number",
        default = 3,
        min = 1,
        max = 30,
        step = 1,
        category = "seed",
        tooltip = "Number of in-game days to mature",
        condition = function(entity) return entity.category == "seed" end,
    },
    {
        key = "seasons",
        label = "Seasons",
        type = "multiselect",
        options = SEASONS,
        default = {},
        category = "seed",
        tooltip = "Seasons in which this seed can be planted",
        condition = function(entity) return entity.category == "seed" end,
    },
    {
        key = "harvestItem",
        label = "Harvest Item",
        type = "string",
        default = "",
        category = "seed",
        tooltip = "Item ID produced at harvest",
        condition = function(entity) return entity.category == "seed" end,
    },
    {
        key = "harvestMin",
        label = "Harvest Min",
        type = "number",
        default = 1,
        min = 0,
        max = 99,
        step = 1,
        category = "seed",
        tooltip = "Minimum items per harvest",
        condition = function(entity) return entity.category == "seed" end,
    },
    {
        key = "harvestMax",
        label = "Harvest Max",
        type = "number",
        default = 3,
        min = 1,
        max = 99,
        step = 1,
        category = "seed",
        tooltip = "Maximum items per harvest",
        condition = function(entity) return entity.category == "seed" end,
    },
    {
        key = "baseRarity",
        label = "Base Rarity",
        type = "select",
        options = SEED_RARITIES,
        default = "common",
        category = "seed",
        tooltip = "Base rarity tier of the crop",
        condition = function(entity) return entity.category == "seed" end,
    },
}

-- =========================================================================
-- 2. EnemySchema  (matches Data.ENEMIES)
-- =========================================================================

Schema.EnemySchema = {
    -- Identity
    {
        key = "id",
        label = "ID",
        type = "string",
        default = "",
        required = true,
        category = "identity",
        tooltip = "Unique enemy identifier",
    },
    {
        key = "name",
        label = "Name",
        type = "string",
        default = "",
        required = true,
        category = "identity",
        tooltip = "Display name shown in combat",
    },
    {
        key = "cr",
        label = "Challenge Rating",
        type = "number",
        default = 1,
        min = 0.25,
        max = 20,
        step = 0.25,
        required = true,
        category = "identity",
        tooltip = "Difficulty rating (0.25 = very weak, 10+ = world threat)",
    },
    {
        key = "portrait",
        label = "Portrait",
        type = "string",
        default = "",
        category = "identity",
        tooltip = "Portrait key or single-character fallback glyph",
    },
    {
        key = "description",
        label = "Description",
        type = "text",
        default = "",
        category = "identity",
        tooltip = "Lore / flavour text for this enemy",
    },

    -- Stat multipliers
    {
        key = "hpMult",
        label = "HP Multiplier",
        type = "number",
        default = 1.0,
        min = 0.1,
        max = 10.0,
        step = 0.1,
        category = "statMultipliers",
        tooltip = "Multiplier applied to base HP for this CR",
    },
    {
        key = "atkMult",
        label = "ATK Multiplier",
        type = "number",
        default = 1.0,
        min = 0.1,
        max = 10.0,
        step = 0.1,
        category = "statMultipliers",
        tooltip = "Multiplier applied to base attack",
    },
    {
        key = "defMult",
        label = "DEF Multiplier",
        type = "number",
        default = 1.0,
        min = 0.1,
        max = 10.0,
        step = 0.1,
        category = "statMultipliers",
        tooltip = "Multiplier applied to base defense",
    },
    {
        key = "xpMult",
        label = "XP Multiplier",
        type = "number",
        default = 1.0,
        min = 0.1,
        max = 10.0,
        step = 0.1,
        category = "statMultipliers",
        tooltip = "XP reward multiplier",
    },
    {
        key = "goldMult",
        label = "Gold Multiplier",
        type = "number",
        default = 1.0,
        min = 0.1,
        max = 10.0,
        step = 0.1,
        category = "statMultipliers",
        tooltip = "Gold drop multiplier",
    },

    -- Combat
    {
        key = "attacks",
        label = "Attacks",
        type = "tags",
        default = {},
        category = "combat",
        tooltip = "List of attack names this enemy can use",
    },
    {
        key = "resistances",
        label = "Resistances",
        type = "table",
        default = {},
        category = "combat",
        tooltip = "Element -> multiplier pairs (positive = resist, negative = weakness)",
    },
    {
        key = "attackType",
        label = "Attack Type",
        type = "select",
        options = ATTACK_TYPES,
        default = "melee",
        category = "combat",
        tooltip = "Primary damage delivery method",
    },
    {
        key = "attackRange",
        label = "Attack Range",
        type = "number",
        default = 1,
        min = 1,
        max = 6,
        step = 1,
        category = "combat",
        tooltip = "Range in tiles (1 = adjacent)",
    },
    {
        key = "damageType",
        label = "Damage Type",
        type = "select",
        options = DAMAGE_TYPES,
        default = "physical",
        category = "combat",
        tooltip = "Element of the enemy's primary damage",
    },

    -- Flags
    {
        key = "boss",
        label = "Boss",
        type = "boolean",
        default = false,
        category = "flags",
        tooltip = "Mark as a boss encounter (special UI, music, no flee)",
    },
    {
        key = "calidarOnly",
        label = "Calidar Only",
        type = "boolean",
        default = false,
        category = "flags",
        tooltip = "Appears only in the Calidar Wastes region",
    },
}

-- =========================================================================
-- 3. NPCSchema  (matches NPC_TEMPLATES)
-- =========================================================================

Schema.NPCSchema = {
    {
        key = "profession",
        label = "Profession",
        type = "select",
        options = NPC_PROFESSIONS,
        default = "shopkeeper",
        required = true,
        category = "identity",
        tooltip = "NPC role that determines available interactions",
    },
    {
        key = "names",
        label = "Names",
        type = "tags",
        default = {},
        required = true,
        category = "identity",
        tooltip = "Pool of possible display names (one chosen at spawn)",
    },
    {
        key = "sprite",
        label = "Sprite",
        type = "string",
        default = "",
        category = "identity",
        tooltip = "Emoji or sprite key used in text mode",
    },
    {
        key = "dialogue",
        label = "Dialogue",
        type = "table",
        default = {
            greeting = "",
            options = {},
        },
        category = "dialogue",
        tooltip = "Dialogue tree (greeting + options with actions/responses)",
    },
    {
        key = "schedule",
        label = "Schedule",
        type = "table",
        default = {},
        category = "behaviour",
        tooltip = "Daily schedule mapping hours to locations/activities",
    },
}

-- =========================================================================
-- 4. QuestSchema  (matches QUEST_TEMPLATES)
-- =========================================================================

Schema.QuestSchema = {
    -- Identity
    {
        key = "id",
        label = "ID",
        type = "string",
        default = "",
        required = true,
        category = "identity",
        tooltip = "Unique quest identifier",
    },
    {
        key = "name",
        label = "Name",
        type = "string",
        default = "",
        required = true,
        category = "identity",
        tooltip = "Quest title shown in the journal",
    },
    {
        key = "description",
        label = "Description",
        type = "text",
        default = "",
        category = "identity",
        tooltip = "Quest giver's description of the task",
    },
    {
        key = "type",
        label = "Type",
        type = "select",
        options = QUEST_TYPES,
        default = "collect",
        required = true,
        category = "identity",
        tooltip = "Primary quest mechanic",
    },

    -- Objectives
    {
        key = "objectives",
        label = "Objectives",
        type = "array",
        default = {},
        category = "objectives",
        tooltip = "List of objectives ({type, item/enemy, amount})",
    },

    -- Requirements
    {
        key = "requirements.minLevel",
        label = "Min Level",
        type = "number",
        default = 1,
        min = 1,
        max = 100,
        step = 1,
        category = "requirements",
        tooltip = "Minimum player level to accept this quest",
    },
    {
        key = "requirements.minReputation",
        label = "Min Reputation",
        type = "number",
        default = 0,
        min = -100,
        max = 100,
        step = 1,
        category = "requirements",
        tooltip = "Minimum reputation with the quest giver's faction",
    },
    {
        key = "requirements.completedQuests",
        label = "Prerequisite Quests",
        type = "tags",
        default = {},
        category = "requirements",
        tooltip = "Quest IDs that must be completed first",
    },

    -- Rewards
    {
        key = "rewards.gold",
        label = "Gold Reward",
        type = "number",
        default = 0,
        min = 0,
        step = 5,
        category = "rewards",
        tooltip = "Gold awarded on completion",
    },
    {
        key = "rewards.experience",
        label = "XP Reward",
        type = "number",
        default = 0,
        min = 0,
        step = 10,
        category = "rewards",
        tooltip = "Experience awarded on completion",
    },
    {
        key = "rewards.reputation",
        label = "Reputation Reward",
        type = "number",
        default = 0,
        min = 0,
        max = 100,
        step = 1,
        category = "rewards",
        tooltip = "Reputation gained with the quest giver's faction",
    },
    {
        key = "rewards.items",
        label = "Item Rewards",
        type = "array",
        default = {},
        category = "rewards",
        tooltip = "List of items awarded ({id, amount})",
    },

    -- Repeat
    {
        key = "repeatable",
        label = "Repeatable",
        type = "boolean",
        default = false,
        category = "repeat",
        tooltip = "Whether the quest can be accepted again after completion",
    },
    {
        key = "cooldown",
        label = "Cooldown (days)",
        type = "number",
        default = 0,
        min = 0,
        max = 365,
        step = 1,
        category = "repeat",
        tooltip = "In-game days before the quest reappears",
        condition = function(entity)
            return entity.repeatable == true
        end,
    },
}

-- =========================================================================
-- 5. ClassSchema  (matches Data.CLASSES)
-- =========================================================================

Schema.ClassSchema = {
    {
        key = "id",
        label = "ID",
        type = "string",
        default = "",
        required = true,
        category = "identity",
        tooltip = "Unique class identifier",
    },
    {
        key = "name",
        label = "Name",
        type = "string",
        default = "",
        required = true,
        category = "identity",
        tooltip = "Display name of the class",
    },
    {
        key = "desc",
        label = "Description",
        type = "text",
        default = "",
        category = "identity",
        tooltip = "Short description of the class playstyle",
    },
    {
        key = "baseHP",
        label = "Base HP",
        type = "number",
        default = 80,
        min = 1,
        max = 500,
        step = 5,
        category = "baseStats",
        tooltip = "Starting hit points",
    },
    {
        key = "baseAtk",
        label = "Base ATK",
        type = "number",
        default = 10,
        min = 1,
        max = 100,
        step = 1,
        category = "baseStats",
        tooltip = "Starting attack power",
    },
    {
        key = "baseDef",
        label = "Base DEF",
        type = "number",
        default = 8,
        min = 1,
        max = 100,
        step = 1,
        category = "baseStats",
        tooltip = "Starting defense",
    },
    {
        key = "baseMana",
        label = "Base Mana",
        type = "number",
        default = 50,
        min = 0,
        max = 500,
        step = 5,
        category = "baseStats",
        tooltip = "Starting mana pool",
    },
    {
        key = "color",
        label = "Class Color",
        type = "color",
        default = {0.5, 0.5, 0.5},
        category = "display",
        tooltip = "UI accent color for this class (RGB 0-1)",
    },
    {
        key = "skills",
        label = "Skills",
        type = "tags",
        default = {},
        category = "abilities",
        tooltip = "List of starting skill names",
    },
}

-- =========================================================================
-- 6. RaceSchema  (matches Data.RACES / Data.UNLOCKABLE_RACES)
-- =========================================================================

Schema.RaceSchema = {
    {
        key = "id",
        label = "ID",
        type = "string",
        default = "",
        required = true,
        category = "identity",
        tooltip = "Unique race identifier",
    },
    {
        key = "name",
        label = "Name",
        type = "string",
        default = "",
        required = true,
        category = "identity",
        tooltip = "Display name of the race",
    },
    {
        key = "desc",
        label = "Description",
        type = "text",
        default = "",
        category = "identity",
        tooltip = "Lore description and gameplay summary",
    },

    -- Stat modifiers (one entry per core stat)
    {
        key = "statMods.MIGHT",
        label = "MIGHT Mod",
        type = "number",
        default = 0,
        min = -5,
        max = 5,
        step = 1,
        category = "statMods",
        tooltip = "Racial modifier to MIGHT",
    },
    {
        key = "statMods.VIGOR",
        label = "VIGOR Mod",
        type = "number",
        default = 0,
        min = -5,
        max = 5,
        step = 1,
        category = "statMods",
        tooltip = "Racial modifier to VIGOR",
    },
    {
        key = "statMods.AGILITY",
        label = "AGILITY Mod",
        type = "number",
        default = 0,
        min = -5,
        max = 5,
        step = 1,
        category = "statMods",
        tooltip = "Racial modifier to AGILITY",
    },
    {
        key = "statMods.MIND",
        label = "MIND Mod",
        type = "number",
        default = 0,
        min = -5,
        max = 5,
        step = 1,
        category = "statMods",
        tooltip = "Racial modifier to MIND",
    },
    {
        key = "statMods.PRESENCE",
        label = "PRESENCE Mod",
        type = "number",
        default = 0,
        min = -5,
        max = 5,
        step = 1,
        category = "statMods",
        tooltip = "Racial modifier to PRESENCE",
    },
    {
        key = "statMods.SPIRIT",
        label = "SPIRIT Mod",
        type = "number",
        default = 0,
        min = -5,
        max = 5,
        step = 1,
        category = "statMods",
        tooltip = "Racial modifier to SPIRIT",
    },
    {
        key = "statMods.FAITH",
        label = "FAITH Mod",
        type = "number",
        default = 0,
        min = -5,
        max = 5,
        step = 1,
        category = "statMods",
        tooltip = "Racial modifier to FAITH",
    },

    -- Bonuses
    {
        key = "bonuses",
        label = "Bonuses",
        type = "array",
        default = {},
        category = "bonuses",
        tooltip = "Racial bonus list ({name, desc} entries)",
    },

    -- Display
    {
        key = "color",
        label = "Race Color",
        type = "color",
        default = {0.5, 0.5, 0.5},
        category = "display",
        tooltip = "UI accent color for this race (RGB 0-1)",
    },

    -- Unlock
    {
        key = "unlockType",
        label = "Unlock Type",
        type = "select",
        options = UNLOCK_TYPES,
        default = "none",
        category = "unlock",
        tooltip = "How this race is unlocked (none = always available)",
    },
    {
        key = "unlockCondition",
        label = "Unlock Condition",
        type = "table",
        default = {},
        category = "unlock",
        tooltip = "Condition details (stat+value, location, or achievement key)",
        condition = function(entity)
            return entity.unlockType and entity.unlockType ~= "none"
        end,
    },
    {
        key = "unlockHint",
        label = "Unlock Hint",
        type = "text",
        default = "",
        category = "unlock",
        tooltip = "Player-facing hint about how to unlock this race",
        condition = function(entity)
            return entity.unlockType and entity.unlockType ~= "none"
        end,
    },
}

-- =========================================================================
-- 7. BackgroundSchema  (matches Data.BACKGROUNDS)
-- =========================================================================

Schema.BackgroundSchema = {
    {
        key = "id",
        label = "ID",
        type = "string",
        default = "",
        required = true,
        category = "identity",
        tooltip = "Unique background identifier",
    },
    {
        key = "name",
        label = "Name",
        type = "string",
        default = "",
        required = true,
        category = "identity",
        tooltip = "Display name of the background",
    },
    {
        key = "desc",
        label = "Description",
        type = "text",
        default = "",
        category = "identity",
        tooltip = "Narrative description and gameplay bonuses summary",
    },
    {
        key = "startingGold",
        label = "Starting Gold",
        type = "number",
        default = 50,
        min = 0,
        max = 1000,
        step = 5,
        category = "economics",
        tooltip = "Gold the player begins with",
    },
    {
        key = "statMods",
        label = "Stat Modifiers",
        type = "table",
        default = {},
        category = "statMods",
        tooltip = "Table of stat name -> modifier value pairs",
    },
    {
        key = "startingItems",
        label = "Starting Items",
        type = "tags",
        default = {},
        category = "equipment",
        tooltip = "Item IDs granted at character creation",
    },
    {
        key = "passives",
        label = "Passives",
        type = "tags",
        default = {},
        category = "abilities",
        tooltip = "Passive ability IDs (defined in PASSIVE_DESCRIPTIONS)",
    },
    {
        key = "tags",
        label = "Tags",
        type = "tags",
        default = {},
        category = "display",
        tooltip = "Flavour tags shown in character sheet (e.g. [Hunter])",
    },
}

-- =========================================================================
-- 8. LoreBookSchema  (matches LoreBooks.BOOKS)
-- =========================================================================

Schema.LoreBookSchema = {
    {
        key = "id",
        label = "ID",
        type = "string",
        default = "",
        required = true,
        category = "identity",
        tooltip = "Unique book identifier",
    },
    {
        key = "title",
        label = "Title",
        type = "string",
        default = "",
        required = true,
        category = "identity",
        tooltip = "Book title as it appears in the lore journal",
    },
    {
        key = "author",
        label = "Author",
        type = "string",
        default = "",
        category = "identity",
        tooltip = "In-world author attribution",
    },
    {
        key = "category",
        label = "Category",
        type = "select",
        options = LORE_CATEGORIES,
        default = "historical",
        required = true,
        category = "identity",
        tooltip = "Lore category for filtering and journal organisation",
    },
    {
        key = "rarity",
        label = "Rarity",
        type = "select",
        options = LORE_RARITIES,
        default = "common",
        category = "identity",
        tooltip = "How difficult the book is to find",
    },
    {
        key = "condition",
        label = "Condition",
        type = "text",
        default = "",
        category = "discovery",
        tooltip = "Physical state of the book (e.g. water-damaged, singed)",
    },
    {
        key = "findLocation",
        label = "Find Location",
        type = "string",
        default = "",
        category = "discovery",
        tooltip = "Location key where this book can be discovered",
    },
    {
        key = "dungeonFloor",
        label = "Dungeon Floor",
        type = "number",
        default = 0,
        min = 0,
        max = 50,
        step = 1,
        category = "discovery",
        tooltip = "Floor number within the dungeon (0 = surface / not in dungeon)",
    },
    {
        key = "content",
        label = "Content",
        type = "text",
        default = "",
        category = "content",
        tooltip = "Full text of the book (can be very long)",
    },
    {
        key = "discoveredText",
        label = "Discovered Text",
        type = "text",
        default = "",
        category = "content",
        tooltip = "Short teaser shown before the player reads the full text",
    },
    {
        key = "partOfCodex",
        label = "Part of Codex",
        type = "boolean",
        default = false,
        category = "codex",
        tooltip = "Whether this book is a fragment of a larger assembled codex",
    },
    {
        key = "codexOrder",
        label = "Codex Order",
        type = "number",
        default = 0,
        min = 0,
        max = 100,
        step = 1,
        category = "codex",
        tooltip = "Position within the assembled codex sequence",
        condition = function(entity) return entity.partOfCodex == true end,
    },
}

-- =========================================================================
-- 9. MapSchema
-- =========================================================================

Schema.MapSchema = {
    {
        key = "name",
        label = "Name",
        type = "string",
        default = "Untitled Map",
        required = true,
        category = "identity",
        tooltip = "Map display name",
    },
    {
        key = "width",
        label = "Width",
        type = "number",
        default = 32,
        min = 4,
        max = 512,
        step = 1,
        required = true,
        category = "dimensions",
        tooltip = "Map width in tiles",
    },
    {
        key = "height",
        label = "Height",
        type = "number",
        default = 32,
        min = 4,
        max = 512,
        step = 1,
        required = true,
        category = "dimensions",
        tooltip = "Map height in tiles",
    },
    {
        key = "mode",
        label = "Mode",
        type = "select",
        options = MAP_MODES,
        default = "dungeon",
        required = true,
        category = "identity",
        tooltip = "Map type (affects generation rules and tile palette)",
    },
    {
        key = "tiles",
        label = "Tiles",
        type = "table",
        default = {},
        category = "data",
        tooltip = "2D array of tile IDs [y][x]",
    },
    {
        key = "entities",
        label = "Entities",
        type = "array",
        default = {},
        category = "data",
        tooltip = "List of placed entity instances on this map",
    },
}

-- =========================================================================
-- 10. PrefabSchema
-- =========================================================================

Schema.PrefabSchema = {
    {
        key = "name",
        label = "Name",
        type = "string",
        default = "Untitled Prefab",
        required = true,
        category = "identity",
        tooltip = "Prefab name for the asset library",
    },
    {
        key = "width",
        label = "Width",
        type = "number",
        default = 5,
        min = 1,
        max = 20,
        step = 1,
        required = true,
        category = "dimensions",
        tooltip = "Prefab width in tiles",
    },
    {
        key = "height",
        label = "Height",
        type = "number",
        default = 5,
        min = 1,
        max = 20,
        step = 1,
        required = true,
        category = "dimensions",
        tooltip = "Prefab height in tiles",
    },
    {
        key = "tiles",
        label = "Tiles",
        type = "table",
        default = {},
        category = "data",
        tooltip = "2D array of tile IDs [y][x]",
    },
    {
        key = "entities",
        label = "Entities",
        type = "array",
        default = {},
        category = "data",
        tooltip = "List of entities placed within the prefab",
    },
    {
        key = "tags",
        label = "Tags",
        type = "tags",
        default = {},
        category = "metadata",
        tooltip = "Searchable tags for the prefab library",
    },
}

-- =========================================================================
-- Helper: resolve a dot-path key ("baseStats.damage") on a table
-- =========================================================================

local function resolveKey(tbl, key)
    local current = tbl
    for segment in key:gmatch("[^%.]+") do
        if type(current) ~= "table" then
            return nil
        end
        current = current[segment]
    end
    return current
end

local function setNestedKey(tbl, key, value)
    local segments = {}
    for segment in key:gmatch("[^%.]+") do
        segments[#segments + 1] = segment
    end
    local current = tbl
    for i = 1, #segments - 1 do
        local seg = segments[i]
        if current[seg] == nil then
            current[seg] = {}
        end
        current = current[seg]
    end
    current[segments[#segments]] = value
end

-- =========================================================================
-- Deep-copy utility (used by getDefault to avoid shared references)
-- =========================================================================

local function deepCopy(orig)
    if type(orig) ~= "table" then
        return orig
    end
    local copy = {}
    for k, v in pairs(orig) do
        copy[deepCopy(k)] = deepCopy(v)
    end
    return copy
end

-- =========================================================================
-- Schema.getDefault(schema) -> new entity table with all defaults
-- =========================================================================

function Schema.getDefault(schema)
    local entity = {}
    for _, field in ipairs(schema) do
        local value = field.default
        if value ~= nil then
            -- Deep-copy tables/arrays so each entity gets its own instance
            if type(value) == "table" then
                value = deepCopy(value)
            end
            setNestedKey(entity, field.key, value)
        end
    end
    return entity
end

-- =========================================================================
-- Schema.validate(entity, schema) -> {errors}, isValid
--
-- Returns a list of {field, message} pairs describing every violation.
-- The second return value is a convenience boolean (true = no errors).
-- =========================================================================

function Schema.validate(entity, schema)
    local errors = {}

    local function addError(field, msg)
        errors[#errors + 1] = { field = field.key, label = field.label, message = msg }
    end

    for _, field in ipairs(schema) do
        -- Skip fields whose condition is not met
        if field.condition and not field.condition(entity) then
            -- Condition not met; field is invisible so skip validation
        else
            local value = resolveKey(entity, field.key)

            -- Required check
            if field.required then
                if value == nil then
                    addError(field, "Required field is missing")
                elseif field.type == "string" and value == "" then
                    addError(field, "Required field must not be empty")
                elseif field.type == "tags" and type(value) == "table" and #value == 0 then
                    addError(field, "At least one entry is required")
                end
            end

            -- Type-specific checks (only when value is present)
            if value ~= nil then
                if field.type == "string" or field.type == "text" then
                    if type(value) ~= "string" then
                        addError(field, "Expected a string value")
                    end

                elseif field.type == "number" then
                    if type(value) ~= "number" then
                        addError(field, "Expected a numeric value")
                    else
                        if field.min and value < field.min then
                            addError(field, "Value must be at least " .. tostring(field.min))
                        end
                        if field.max and value > field.max then
                            addError(field, "Value must be at most " .. tostring(field.max))
                        end
                    end

                elseif field.type == "boolean" then
                    if type(value) ~= "boolean" then
                        addError(field, "Expected a boolean value")
                    end

                elseif field.type == "select" then
                    if field.options then
                        local found = false
                        for _, opt in ipairs(field.options) do
                            if opt == value then
                                found = true
                                break
                            end
                        end
                        if not found then
                            addError(field, "Value '" .. tostring(value) .. "' is not a valid option")
                        end
                    end

                elseif field.type == "multiselect" then
                    if type(value) ~= "table" then
                        addError(field, "Expected a table of selected values")
                    elseif field.options then
                        local optionSet = {}
                        for _, opt in ipairs(field.options) do
                            optionSet[opt] = true
                        end
                        for _, v in ipairs(value) do
                            if not optionSet[v] then
                                addError(field, "Invalid selection: '" .. tostring(v) .. "'")
                            end
                        end
                    end

                elseif field.type == "color" then
                    if type(value) ~= "table" or #value < 3 then
                        addError(field, "Color must be a table with at least 3 components {r,g,b}")
                    else
                        for i = 1, math.min(#value, 4) do
                            if type(value[i]) ~= "number" then
                                addError(field, "Color component " .. i .. " must be a number")
                            elseif value[i] < 0 or value[i] > 1 then
                                addError(field, "Color component " .. i .. " must be in range 0-1")
                            end
                        end
                    end

                elseif field.type == "table" then
                    if type(value) ~= "table" then
                        addError(field, "Expected a table value")
                    end

                elseif field.type == "array" then
                    if type(value) ~= "table" then
                        addError(field, "Expected an array (table) value")
                    end

                elseif field.type == "tags" then
                    if type(value) ~= "table" then
                        addError(field, "Expected a tags list (table)")
                    else
                        for i, v in ipairs(value) do
                            if type(v) ~= "string" then
                                addError(field, "Tag at index " .. i .. " must be a string")
                            end
                        end
                    end
                end
            end
        end
    end

    return errors, #errors == 0
end

-- =========================================================================
-- Schema.getFieldsByCategory(schema) -> ordered list of {name, fields}
--
-- Groups fields into category buckets, preserving the original order within
-- each group. Returns a list (not a map) so the UI can render categories
-- in a stable, deterministic sequence.
-- =========================================================================

function Schema.getFieldsByCategory(schema)
    local categoryOrder = {}   -- list of unique category names in first-seen order
    local categoryMap = {}     -- name -> list of fields

    for _, field in ipairs(schema) do
        local cat = field.category or "general"
        if not categoryMap[cat] then
            categoryMap[cat] = {}
            categoryOrder[#categoryOrder + 1] = cat
        end
        local list = categoryMap[cat]
        list[#list + 1] = field
    end

    local result = {}
    for _, cat in ipairs(categoryOrder) do
        result[#result + 1] = { name = cat, fields = categoryMap[cat] }
    end
    return result
end

-- =========================================================================
-- Convenience: map of all schemas keyed by short name
-- =========================================================================

Schema.ALL = {
    item       = Schema.ItemSchema,
    enemy      = Schema.EnemySchema,
    npc        = Schema.NPCSchema,
    quest      = Schema.QuestSchema,
    class      = Schema.ClassSchema,
    race       = Schema.RaceSchema,
    background = Schema.BackgroundSchema,
    lorebook   = Schema.LoreBookSchema,
    map        = Schema.MapSchema,
    prefab     = Schema.PrefabSchema,
}

return Schema
