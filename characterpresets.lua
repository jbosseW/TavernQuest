-- Character Presets - Pre-configured character templates
-- Use these as starting points or for NPC generation

local CharacterPresets = {}

-- ============================================================================
-- PLAYER CHARACTER PRESETS (by Class)
-- ============================================================================

CharacterPresets.playerClasses = {
    warrior = {
        race = "human",
        bodyType = "male",
        hairStyle = "plain",
        hairColor = {0.3, 0.2, 0.1},  -- Brown
        torso = "chainmail",
        legs = "chainmail_legs",
        feet = "boots_metal",
        weapon = "sword",
        shield = "shield_metal",
        description = "A battle-hardened warrior clad in chainmail"
    },

    mage = {
        race = "elf",
        bodyType = "female",
        hairStyle = "long",
        hairColor = {0.9, 0.9, 0.9},  -- Silver
        torso = "robe_blue",
        legs = "robe_skirt",
        feet = "boots_brown",
        weapon = "staff",
        head = "wizard_hat",
        description = "An elven mage wielding arcane power"
    },

    rogue = {
        race = "human",
        bodyType = "male",
        hairStyle = "messy",
        hairColor = {0.1, 0.1, 0.1},  -- Black
        torso = "leather_armor",
        legs = "leather_pants",
        feet = "boots_black",
        weapon = "dagger",
        description = "A stealthy rogue dressed in leather"
    },

    cleric = {
        race = "dwarf",
        bodyType = "male",
        hairStyle = "shoulder",
        hairColor = {0.6, 0.3, 0.1},  -- Reddish brown
        facial = "beard_full",
        torso = "robe_white",
        legs = "robe_skirt",
        feet = "boots_brown",
        weapon = "mace",
        shield = "shield_wood",
        description = "A dwarven cleric with a mighty beard"
    },

    ranger = {
        race = "elf",
        bodyType = "female",
        hairStyle = "ponytail",
        hairColor = {0.4, 0.3, 0.1},  -- Auburn
        torso = "leather_armor",
        legs = "leather_pants",
        feet = "boots_brown",
        weapon = "bow",
        back = "quiver",
        description = "An elven ranger, master of the bow"
    },

    paladin = {
        race = "human",
        bodyType = "male",
        hairStyle = "plain",
        hairColor = {0.7, 0.6, 0.3},  -- Blonde
        torso = "plate_armor",
        legs = "plate_legs",
        feet = "boots_metal",
        head = "helmet_plate",
        weapon = "sword",
        shield = "shield_tower",
        description = "A righteous paladin in shining armor"
    },

    barbarian = {
        race = "orc",
        bodyType = "male",
        hairStyle = "mohawk",
        hairColor = {0.1, 0.1, 0.1},  -- Black
        torso = "leather_armor",
        legs = "leather_pants",
        feet = "boots_brown",
        weapon = "axe",
        description = "A fierce orcish barbarian"
    },

    druid = {
        race = "human",
        bodyType = "female",
        hairStyle = "long",
        hairColor = {0.3, 0.5, 0.2},  -- Green-brown
        torso = "robe_green",
        legs = "robe_skirt",
        feet = "boots_brown",
        weapon = "staff",
        back = "cape_green",
        description = "A nature-loving druid"
    },

    engineer = {
        race = "gnome",
        bodyType = "male",
        hairStyle = "messy",
        hairColor = {0.9, 0.9, 0.9},  -- White/silver
        torso = "leather_apron",
        legs = "cloth_pants",
        feet = "boots_brown",
        weapon = "wrench",
        back = "toolbelt",
        description = "A gnomish engineer with wild hair and clever eyes"
    },

    gambler = {
        race = "catfolk",
        bodyType = "female",
        hairStyle = "none",  -- Fur instead
        hairColor = {0.8, 0.6, 0.3},  -- Tawny
        ears = "cat",
        tail = true,
        torso = "traveler_clothes",
        legs = "cloth_pants",
        feet = "boots_soft",
        weapon = "dagger",
        description = "A cat folk fortune teller and gambler"
    }
}

-- ============================================================================
-- NPC PRESETS (Town Folk)
-- ============================================================================

CharacterPresets.townFolk = {
    merchant = {
        race = "human",
        bodyType = "male",
        hairStyle = "plain",
        hairColor = {0.4, 0.3, 0.2},
        torso = "cloth_shirt",
        legs = "cloth_pants",
        feet = "boots_brown",
        description = "A friendly merchant"
    },

    blacksmith = {
        race = "dwarf",
        bodyType = "male",
        hairStyle = "bald",
        facial = "beard_full",
        hairColor = {0.2, 0.2, 0.2},
        torso = "leather_apron",
        legs = "cloth_pants",
        feet = "boots_brown",
        description = "A skilled blacksmith"
    },

    innkeeper = {
        race = "human",
        bodyType = "female",
        hairStyle = "shoulder",
        hairColor = {0.5, 0.4, 0.3},
        torso = "cloth_dress",
        legs = "cloth_skirt",
        feet = "boots_brown",
        description = "A welcoming innkeeper"
    },

    guard = {
        race = "human",
        bodyType = "male",
        hairStyle = "plain",
        hairColor = {0.3, 0.2, 0.1},
        torso = "chainmail",
        legs = "chainmail_legs",
        feet = "boots_metal",
        weapon = "spear",
        shield = "shield_wood",
        head = "helmet_chain",
        description = "A town guard on duty"
    },

    priest = {
        race = "human",
        bodyType = "male",
        hairStyle = "bald",
        torso = "robe_white",
        legs = "robe_skirt",
        feet = "boots_brown",
        description = "A devoted priest"
    },

    beggar = {
        race = "human",
        bodyType = "male",
        hairStyle = "messy",
        hairColor = {0.3, 0.3, 0.3},
        torso = "cloth_torn",
        legs = "cloth_pants_torn",
        feet = "boots_worn",
        description = "A poor beggar"
    },

    noble = {
        race = "human",
        bodyType = "female",
        hairStyle = "princess",
        hairColor = {0.7, 0.6, 0.3},
        torso = "dress_fancy",
        legs = "dress_skirt",
        feet = "boots_fancy",
        head = "circlet",
        description = "A wealthy noble"
    },

    farmer = {
        race = "human",
        bodyType = "male",
        hairStyle = "plain",
        hairColor = {0.4, 0.3, 0.2},
        torso = "cloth_shirt",
        legs = "cloth_pants",
        feet = "boots_worn",
        description = "A hardworking farmer"
    }
}

-- ============================================================================
-- MONSTER/ENEMY PRESETS
-- ============================================================================

CharacterPresets.enemies = {
    skeleton_warrior = {
        race = "skeleton",
        bodyType = "universal",
        weapon = "sword",
        shield = "shield_bone",
        description = "An undead skeleton warrior"
    },

    orc_raider = {
        race = "orc",
        bodyType = "male",
        hairStyle = "mohawk",
        hairColor = {0.1, 0.1, 0.1},
        torso = "leather_armor",
        legs = "leather_pants",
        weapon = "axe",
        description = "A brutal orc raider"
    },

    goblin_thief = {
        race = "goblin",
        bodyType = "male",
        hairStyle = "messy",
        torso = "cloth_torn",
        legs = "cloth_pants_torn",
        weapon = "dagger",
        description = "A sneaky goblin thief"
    },

    dark_mage = {
        race = "human",
        bodyType = "male",
        hairStyle = "long",
        hairColor = {0.1, 0.1, 0.1},
        torso = "robe_black",
        legs = "robe_skirt",
        weapon = "staff_dark",
        description = "A sinister dark mage"
    },

    bandit = {
        race = "human",
        bodyType = "male",
        hairStyle = "messy",
        hairColor = {0.3, 0.2, 0.1},
        torso = "leather_armor",
        legs = "leather_pants",
        weapon = "sword",
        description = "A ruthless bandit"
    }
}

-- ============================================================================
-- SPECIAL/UNIQUE CHARACTERS
-- ============================================================================

CharacterPresets.unique = {
    vampire_lord = {
        race = "human",
        bodyType = "male",
        hairStyle = "long",
        hairColor = {0.1, 0.1, 0.1},
        torso = "robe_black",
        legs = "robe_skirt",
        back = "cape_black",
        description = "An ancient vampire lord"
    },

    dragon_knight = {
        race = "human",
        bodyType = "male",
        hairStyle = "plain",
        hairColor = {0.5, 0.1, 0.1},
        torso = "plate_armor_dragon",
        legs = "plate_legs_dragon",
        head = "helmet_dragon",
        weapon = "sword_dragon",
        shield = "shield_dragon",
        description = "A legendary dragon knight"
    },

    high_elf_queen = {
        race = "elf",
        bodyType = "female",
        hairStyle = "princess",
        hairColor = {0.9, 0.9, 0.3},
        torso = "dress_royal",
        legs = "dress_skirt",
        head = "crown",
        back = "cape_royal",
        description = "The High Elf Queen"
    },

    necromancer = {
        race = "human",
        bodyType = "male",
        hairStyle = "long",
        hairColor = {0.7, 0.7, 0.7},
        torso = "robe_dark_purple",
        legs = "robe_skirt",
        weapon = "staff_skull",
        description = "A death-dealing necromancer"
    }
}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Get a preset by category and ID
function CharacterPresets.get(category, id)
    local categories = {
        playerClasses = CharacterPresets.playerClasses,
        townFolk = CharacterPresets.townFolk,
        enemies = CharacterPresets.enemies,
        unique = CharacterPresets.unique
    }

    local cat = categories[category]
    if cat and cat[id] then
        return cat[id]
    end

    return nil
end

-- Create a character from a preset
function CharacterPresets.createCharacter(category, id, x, y)
    local CharacterCustomizer = require("charactercustomizer")

    local preset = CharacterPresets.get(category, id)
    if not preset then
        print("Warning: Preset not found: " .. category .. "." .. id)
        return nil
    end

    local template = CharacterCustomizer.createTemplate(
        preset.race or "human",
        preset.bodyType or "male",
        {
            hairStyle = preset.hairStyle,
            hairColor = preset.hairColor,
            eyeColor = preset.eyeColor,
            torso = preset.torso,
            legs = preset.legs,
            feet = preset.feet,
            hands = preset.hands,
            head = preset.head,
            back = preset.back,
            weapon = preset.weapon,
            shield = preset.shield,
            facial = preset.facial
        }
    )

    return CharacterCustomizer.createCharacterFromTemplate(template, x or 0, y or 0)
end

-- Get all preset IDs in a category
function CharacterPresets.listCategory(category)
    local categories = {
        playerClasses = CharacterPresets.playerClasses,
        townFolk = CharacterPresets.townFolk,
        enemies = CharacterPresets.enemies,
        unique = CharacterPresets.unique
    }

    local cat = categories[category]
    if not cat then
        return {}
    end

    local list = {}
    for id, _ in pairs(cat) do
        table.insert(list, id)
    end

    return list
end

-- Get random preset from category
function CharacterPresets.getRandom(category)
    local list = CharacterPresets.listCategory(category)
    if #list == 0 then
        return nil
    end

    local randomId = list[love.math.random(#list)]
    return CharacterPresets.get(category, randomId)
end

-- Assign preset to NPC based on their role
function CharacterPresets.assignToNPC(npc)
    -- Map NPC types to preset categories
    local npcTypeMap = {
        merchant = "merchant",
        blacksmith = "blacksmith",
        innkeeper = "innkeeper",
        guard = "guard",
        priest = "priest",
        noble = "noble",
        farmer = "farmer",
        beggar = "beggar"
    }

    local presetId = npcTypeMap[npc.type] or "merchant"
    return CharacterPresets.createCharacter("townFolk", presetId, 0, 0)
end

return CharacterPresets
