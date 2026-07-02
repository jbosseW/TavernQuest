-- RPG Data Tables - All static game data for TextRPG
-- Extracted from textrpg.lua for maintainability
local Data = {}

Data.WORLD_SCALE = {
    kmPerTile = 5,           -- Kilometers per map tile
    milesPerTile = 3.1,      -- Miles per map tile
    baseWalkHours = 1,       -- Hours to cross 1 tile on foot
    baseHorseHours = 0.33,   -- Hours to cross 1 tile on horseback (~20 min)
    viewDistanceKm = 85,     -- How far player can see (17 tiles * 5 km)

    -- Helper functions
    tilesToKm = function(tiles) return tiles * 5 end,
    tilesToMiles = function(tiles) return tiles * 3.1 end,
    kmToTiles = function(km) return math.floor(km / 5) end,
}

-- Character portrait mappings to art assets
-- Using new folder structure: Animals, Monsters for creatures; Human/Men_Human, etc. for NPCs
Data.portraitMappings = {
    -- Player classes (Human folder)
    warrior = "Human/Men_Human/Knight_Man",
    mage = "Human/Men_Human/Human_27_alchemyst",
    rogue = "Human/Women_Human/Assassin",
    cleric = "Human/Men_Human/Human_06_Priest",
    ranger = "ELF/Men_ELF/Elf_01_1",
    monk = "BeastFolk/Catfolk/Men_Catfolk/Catfolk_01",

    -- === PLAYABLE RACES (for character creation) ===
    human = "Human/Men_Human/Human_04_knight",
    elf = "ELF/Men_ELF/Elf_01_1",
    dwarf = "Dwarves/Dwarf",
    orc = "ORC/Men_ORC/Orc_01_warrior",
    goblin = "Goblin/Goblin Males/goblin_01",
    gnome = "Gnomes/Male Gnomes/Gnome_02",
    catfolk = "BeastFolk/Catfolk/Men_Catfolk/Catfolk_01",
    lizardfolk = "BeastFolk/Lizardfolk/Lizardfolk_01",

    -- === ANIMALS ===
    rat = "Animals/Monsters_16",
    wolf = "Animals/Wolf_animal",
    bear = "Animals/Bear_animal",
    boar = "Animals/Boar_animal",
    bat = "Animals/Bat",
    spider = "Monsters/Monster_Spider",
    cave_spider = "Monsters/Creatures_08_spider",
    scorpion = "Monsters/Monster_Scorpion",
    hawk = "Animals/Hawk_animal",
    warhorse = "Animals/Creatures_10_warhorse",
    dog = "Animals/Creatures_12_Dog",

    -- === GOBLINS ===
    goblin = "Goblin/Goblin Males/goblin_01",
    goblin_scout = "Goblin/Goblin Males/goblin_02",
    goblin_shaman = "Goblin/Goblin Males/goblin_03",
    goblin_warrior = "Goblin/Goblin Males/goblin_04",
    goblin_chief = "Goblin/Goblin Males/goblin_05",

    -- === ORCS ===
    orc = "ORC/Men_ORC/Orc_01_warrior",
    orc_warrior = "ORC/Men_ORC/Orc_01_warrior",
    orc_warlord = "ORC/Men_ORC/Orc_02_warlord",
    orc_shaman = "ORC/Men_ORC/Orc_03_shaman",
    orc_warlock = "ORC/Men_ORC/Orc_04_warlock",
    orc_hunter = "ORC/Men_ORC/Orc_6_Hunter",
    orc_rider = "ORC/Men_ORC/Orc_7_Rider",
    orc_oracle = "ORC/Men_ORC/Orc_8_oracle",

    -- === UNDEAD ===
    skeleton = "Monsters/Undead/Undead_04_warrior",
    skeleton_archer = "Monsters/Undead/Undead_01_archer",
    skeleton_knight = "Monsters/Undead/Undead_02_knight",
    skeleton_mage = "Monster_SkeletonMage",
    skeleton_king = "Monsters/Undead/Monster_SkeletonKing",
    zombie = "Monsters/Undead/Undead_06_zombie",
    zombie_brute = "Monsters/Undead/Monster_Zombie",
    ghost = "Monsters/Undead/Monster_Ghost",
    ghost_knight = "Monsters/Undead/Monster_GhostKnight",
    wraith = "Monsters/Undead/Undead_09_ghost",
    lich = "Undead_11",
    lich_king = "Monsters/Demon_12_skeleton_king",
    necromancer = "Undead_11",
    undead_dragon = "Monsters/Undead/Undead_10_dragon",
    bone_snake = "Monsters/Undead/Monster_SkeletonSnake",
    frost_skeleton = "Monster_FrostSkeleton",
    -- Lich Lair specific enemies
    death_knight = "Monsters/Undead/Undead_02_knight",
    bone_colossus = "Monsters/Undead/Monster_SkeletonKing",
    dracolich = "Monsters/Undead/Undead_10_dragon",
    lich_overlord = "Undead_11",
    archlich = "Undead_11",
    skeletal_horror = "Monsters/Undead/Monster_SkeletonKing",
    corpse_giant = "Monsters/Undead/Monster_Zombie",
    death_knight_champion = "Monsters/Undead/Undead_02_knight",
    death_knight_squire = "Monsters/Undead/Undead_04_warrior",
    -- Additional lich lair enemies
    shambling_corpse = "Monsters/Undead/Undead_06_zombie",
    skeletal_warrior = "Monsters/Undead/Undead_04_warrior",
    rotting_zombie = "Monsters/Undead/Monster_Zombie",
    ghoul = "Monsters/Undead/Undead_06_zombie",
    corrupted_peasant = "Monsters/Undead/Undead_06_zombie",
    soul_wisp = "Monsters/Undead/Monster_Ghost",
    skeleton_mage = "Monster_SkeletonMage",
    wight_captain = "Monsters/Undead/Undead_02_knight",
    bone_golem = "Monsters/Undead/Monster_SkeletonKing",
    specter = "Monsters/Undead/Undead_09_ghost",
    plague_bearer = "Monsters/Undead/Monster_Zombie",
    banshee = "Monsters/Undead/Monster_Ghost",
    lich_acolyte = "Undead_11",
    wraith_lord = "Monsters/Undead/Undead_09_ghost",
    abomination = "Monsters/Undead/Monster_Zombie",
    soul_reaver = "Monsters/Undead/Monster_Ghost",
    lich_apprentice = "Undead_11",
    dread_wraith = "Monsters/Undead/Monster_GhostKnight",
    undead_general = "Monsters/Undead/Undead_02_knight",
    lich_emperor = "Undead_11",

    -- === VAMPIRES ===
    vampire = "Monsters/Vampires/Female Vampire/Monster_Vampire",
    vampire_lord = "Monsters/Vampires/Male Vampire/Monster_VoraciousVampire",
    vampire_spawn = "Monsters/Vampires/Male Vampire/Monsters_33",
    vampire_bride = "Monsters/Vampires/Female Vampire/Monsters_41",

    -- === DEMONS ===
    demon = "Demons/Male Demon/Demon_03_Devil",
    imp = "Demons/Male Demon/Demon_02_imp",
    devil = "Demons/Male Demon/Demon_03_Devil",
    ice_demon = "Demons/Male Demon/Demon_06_ice",
    fire_demon = "Demons/Male Demon/Demon_07_fire",
    death_demon = "Demons/Male Demon/Demon_09_death",
    demon_guard = "Demons/Male Demon/Demon_13_guard",
    hell_guard = "Demons/Male Demon/Creatures_06_Hell_guard",
    demon_lord = "Demons/Male Demon/Demon_09_death",
    succubus = "Monsters/Demon_04_succubus",
    gargoyle = "Demon_11_gargoyle",

    -- === GIANTS & BEASTS ===
    troll = "Creatures_16_troll",
    ogre = "Gigant_04_ogre",
    ogre_warrior = "Gigant_06_ogre_warrior",
    ogre_mage = "Gigant_07_ogre_mage",
    cyclops = "Gigant_01_cyclope",
    titan = "Gigant_02_old_titan",
    yeti = "Gigant_03_yeti",
    minotaur = "Monsters/Gigant_08_minotaur",
    manticore = "Monsters/Creatures_01_Manticore",
    griffin = "Monsters/Creatures_03_griffin",
    werewolf = "Monsters/Creatures_05_werewolf",
    ratman = "Monsters/Creatures_14_ratman",

    -- === DRAGONS ===
    dragon = "Monsters/Creatures_11_Dragon",
    dragon_boss = "Monsters/Creatures_11_Dragon",
    dragon_warrior = "Monsters/Monster_DragonWarrior",
    war_dragon = "Monsters/Undead/Monster_WarDragon",

    -- === SLIMES & ELEMENTALS ===
    slime = "Monsters/Monster_Slime",
    fire_elemental = "Monster_FireElemental",
    elemental = "Monsters/Monster_Elemental",
    stone_golem = "Giant_StoneGolem",
    stone_guard = "StoneGuard",

    -- === DWARVES & GNOMES ===
    dwarf = "Dwarves/Dwarf",
    mad_dwarf = "Dwarves/MadDwarf",
    gnome = "Gnomes/Male Gnomes/Gnome_02",
    gnome_engineer = "Gnomes/Male Gnomes/Gnome_05",
    gnome_sage = "Gnomes/Male Gnomes/Gnome_06",

    -- === MISC CREATURES ===
    bandit = "Human/Men_Human/Robber",
    dark_rider = "Monster_DarkRider",
    drowner = "Monster_drowner",
    scarecrow = "Monster_Scarecrow",
    treant = "Monster_TreeMan",
    swamp_thing = "Monsters/Monster_Swamp",
    demonic_eye = "Monsters/Monster_DemonicEye",
    demonic_dog = "Monsters/Monster_DemonicDog",
    worm = "Monsters/Monster_Worm",
    wasp = "Monsters/Monster_Wasp",
    fly = "Monsters/Monster_Fly",
    phoenix = "Monsters/Creatures_07_phoenix",
    gorgon = "Creatures_04_gorgon",
    homunculus = "homunculus",

    -- === NPCs ===
    blacksmith = "Dwarves/Dwarf",
    innkeeper = "Human/Men_Human/Merchant",
    elder = "Human/Men_Human/Sage",
    merchant = "Human/Men_Human/Trader",
    guard = "Human/Men_Human/Guard",
    healer = "Human/Men_Human/Human_06_Priest",
    farmer = "Human/Men_Human/Human_01",
    miner = "Gnomes/Male Gnomes/Gnome_02",
    scholar = "Human/Men_Human/Human_27_alchemyst",
    hunter = "Human/Men_Human/Crossbowman",
    archangel = "Creatures_02_Archangel",
    holy_knight = "Creatures_13_Holy_Knight",
    golden_guard = "Creatures_09_golden_guard",
}

Data.CLASS_PORTRAIT_OPTIONS = {
    warrior = {
        male = {"Knight_Man", "BoldWarrior", "Human_04_knight", "Footman", "Guard"},
        female = {"Human_05_woman_knight", "Human_08_warrior", "BlindWoman"}
    },
    mage = {
        male = {"Human_27_alchemyst", "Duke", "DarkLord"},
        female = {"FrostMage", "Cultist"}
    },
    rogue = {
        male = {"Human_01_archer", "Crossbowman"},
        female = {"Assassin", "Archer_woman", "Human_02_archer"}
    },
    cleric = {
        male = {"Human_06_Priest", "Human_09_tamplier"},
        female = {"Human_06"}
    }
}

-- Character Classes (6 Universal Classes - Available to All Races)
Data.CLASSES = {
    {
        id = "warrior",
        name = "Warrior",
        desc = "Strong melee fighter with high HP and heavy armor",
        baseHP = 100,
        baseAtk = 15,
        baseDef = 10,
        baseMana = 30,
        portrait = "[]",
        color = {0.8, 0.3, 0.3},
        skills = {"Power Strike", "Shield Bash", "Battle Cry"}
    },
    {
        id = "mage",
        name = "Mage",
        desc = "Master of arcane magic wielding elemental destruction",
        baseHP = 60,
        baseAtk = 8,
        baseDef = 5,
        baseMana = 100,
        portrait = "[]",
        color = {0.3, 0.4, 0.9},
        skills = {"Fireball", "Ice Shard", "Lightning Bolt"}
    },
    {
        id = "rogue",
        name = "Rogue",
        desc = "Agile striker specializing in stealth and critical hits",
        baseHP = 70,
        baseAtk = 12,
        baseDef = 6,
        baseMana = 50,
        portrait = "[]",
        color = {0.5, 0.5, 0.5},
        skills = {"Backstab", "Poison Blade", "Vanish"}
    },
    {
        id = "cleric",
        name = "Cleric",
        desc = "Divine healer who channels holy power to aid and smite",
        baseHP = 80,
        baseAtk = 10,
        baseDef = 8,
        baseMana = 80,
        portrait = "[]",
        color = {0.9, 0.8, 0.3},
        skills = {"Heal", "Smite", "Divine Shield"}
    },
    {
        id = "ranger",
        name = "Ranger",
        desc = "Expert archer who strikes from range with deadly precision",
        baseHP = 75,
        baseAtk = 14,
        baseDef = 7,
        baseMana = 60,
        portrait = "[]",
        color = {0.3, 0.8, 0.4},
        skills = {"Precise Shot", "Hunter's Mark", "Volley"}
    },
    {
        id = "monk",
        name = "Monk",
        desc = "Unarmed combatant combining speed, discipline, and martial arts",
        baseHP = 80,
        baseAtk = 13,
        baseDef = 10,
        baseMana = 65,
        portrait = "[]",
        color = {0.8, 0.7, 0.4},
        skills = {"Flurry of Blows", "Claw Strike", "Inner Focus"}
    },
}

Data.RACES = {
    {
        id = "human",
        name = "Human",
        desc = "Adaptable generalists who excel through versatility",
        statMods = {choice1 = 1, choice2 = 1}, -- Player chooses +1 to any 2 stats
        bonuses = {
            {name = "Adaptable", desc = "+1 skill point at levels 1/5/10/15/20, +10% XP gain"},
            {name = "Ambitious", desc = "+15% gold from quests/combat, +5% shop prices, +25 starting gold"},
        },
        color = {0.9, 0.9, 0.9},
    },
    {
        id = "elf",
        name = "Elf",
        desc = "Graceful archers and mages with keen senses",
        statMods = {AGILITY = 2, MIND = 1},
        bonuses = {
            {name = "Keen Senses", desc = "+2 tiles detection, +20% find secrets, immune surprise attacks"},
            {name = "Ancient Wisdom", desc = "+50% XP at level 1, -20% mana cost, +1 SPIRIT per 5 levels"},
        },
        color = {0.3, 0.9, 0.5},
    },
    {
        id = "dwarf",
        name = "Dwarf",
        desc = "Tough mountain warriors and master craftsmen",
        statMods = {VIGOR = 2, MIGHT = 1},
        bonuses = {
            {name = "Stoneborn Resilience", desc = "+20% max HP, +15% resist poison/disease/corruption"},
            {name = "Master Craftsmen", desc = "+25% find materials, -20% equipment cost, identify items"},
        },
        color = {0.7, 0.5, 0.3},
    },
    {
        id = "orc",
        name = "Orc",
        desc = "Savage warriors who turn rage into power",
        statMods = {MIGHT = 2, VIGOR = 1},
        bonuses = {
            {name = "Savage Fury", desc = "+15% melee damage, +25% attack when low HP, heal 15% on kill"},
            {name = "Tribal Warrior", desc = "+10% damage with party, intimidate weaker enemies"},
        },
        color = {0.5, 0.7, 0.3},
    },
    {
        id = "goblin",
        name = "Goblin",
        desc = "Cunning tricksters who survive through guile",
        statMods = {AGILITY = 1, MIND = 1, PRESENCE = 1}, -- Was AGI+2/MIND+1 (identical to Elf); now unique 3-way split
        bonuses = {
            {name = "Cunning Trickster", desc = "+15% dodge, +25% flee chance, +30% ambush damage"},
            {name = "Scavenger", desc = "15% extra loot, auto-loot 5g per kill, -30% consumable prices"},
        },
        color = {0.6, 0.8, 0.3},
    },
    {
        id = "gnome",
        name = "Gnome",
        desc = "Inventive arcanists with technological brilliance",
        statMods = {MIND = 2, AGILITY = 1},
        bonuses = {
            {name = "Inventive Genius", desc = "+25% mana regen, 15% chance spells cost no mana"},
            {name = "Small and Nimble", desc = "+10% dodge, +15% map speed, access hidden passages"},
        },
        color = {0.8, 0.6, 0.8},
    },
    {
        id = "catfolk",
        name = "Catfolk",
        desc = "Agile rogues with feline grace and nine lives",
        statMods = {AGILITY = 2, PRESENCE = 1},
        bonuses = {
            {name = "Feline Grace", desc = "+25% crit chance, no fall damage, night vision"},
            {name = "Nine Lives", desc = "Survive killing blow 1/day, -20% death penalty"},
        },
        color = {0.9, 0.7, 0.4},
    },
    {
        id = "lizardfolk",
        name = "Lizardfolk",
        desc = "Primal hunters adapted to hostile swamps",
        statMods = {VIGOR = 2, SPIRIT = 1},
        bonuses = {
            {name = "Cold Blood", desc = "+30% poison resist, breathe underwater, 2% HP regen/turn"},
            {name = "Primal Hunter", desc = "+15% damage vs beasts, +20% fishing rewards, track enemies"},
        },
        color = {0.5, 0.7, 0.6},
    },
}

-- Unlockable Races (12 total - must be earned through gameplay)
-- Unlock types: "metric" (stat threshold), "location" (visit area), "achievement" (specific action)
Data.UNLOCKABLE_RACES = {
    {
        id = "revenant",
        name = "Revenant",
        desc = "Fallen warriors who refused death's embrace, bound by unfinished purpose",
        statMods = {MIGHT = 2, SPIRIT = 1}, -- Was MIGHT+2/VIG+1 (identical to Orc); SPIRIT reflects undying willpower
        bonuses = {
            {name = "Undying Will", desc = "Survive fatal blow once per day with 1 HP, +20% damage when below 30% HP"},
            {name = "Death's Memory", desc = "+10% XP from combat, immune to fear effects, -15% healing received"},
        },
        color = {0.6, 0.2, 0.2},
        unlockType = "metric",
        unlockCondition = {stat = "enemiesDefeated", value = 100},
        unlockHint = "Defeat 100 enemies to unlock",
    },
    {
        id = "half_elf",
        name = "Half-Elf",
        desc = "Children of two worlds, bearing the adaptability of humans and wisdom of elves",
        statMods = {PRESENCE = 2, MIND = 1},
        bonuses = {
            {name = "Dual Heritage", desc = "+10% XP gain, +10% shop prices, +1 skill point at levels 5/15"},
            {name = "Diplomat's Grace", desc = "+25% persuasion, +15% quest rewards, NPCs start at higher disposition"},
        },
        color = {0.5, 0.8, 0.6},
        unlockType = "metric",
        unlockCondition = {stat = "questsCompleted", value = 25},
        unlockHint = "Complete 25 quests to unlock",
    },
    {
        id = "halfling",
        name = "Halfling",
        desc = "Small-statured folk with outsized luck and an eye for opportunity",
        statMods = {AGILITY = 1, PRESENCE = 1, SPIRIT = 1},
        bonuses = {
            {name = "Fortune's Favor", desc = "+20% gold from all sources, +10% crit chance, find 15% more loot"},
            {name = "Nimble Escape", desc = "+25% dodge chance, +20% stealth, can flee combat without penalty"},
        },
        color = {0.8, 0.7, 0.4},
        unlockType = "metric",
        unlockCondition = {stat = "goldEarned", value = 10000},
        unlockHint = "Earn 10,000 gold total to unlock",
    },
    {
        id = "voidborn",
        name = "Voidborn",
        desc = "Mortals touched by the space between worlds, channeling emptiness as power",
        statMods = {MIND = 2, SPIRIT = 1},
        bonuses = {
            {name = "Hollow Resonance", desc = "-25% mana cost, +15% magic damage, spells ignore 10% resistance"},
            {name = "Void Gaze", desc = "+3 tile detection range, see hidden enemies, immune to blind/illusion effects"},
        },
        color = {0.3, 0.1, 0.5},
        unlockType = "location",
        unlockCondition = {location = "void_sanctum"},
        unlockHint = "Visit the Void Sanctum to unlock",
    },
    {
        id = "celestial",
        name = "Celestial",
        desc = "Descendants of beings blessed by Helios, radiant healers and protectors",
        statMods = {FAITH = 2, SPIRIT = 1},
        bonuses = {
            {name = "Radiant Soul", desc = "+30% healing done, healing spells restore 10% mana, +2 FAITH per 10 levels"},
            {name = "Helios's Light", desc = "+15% damage vs undead/void, immune to corruption, glow reveals nearby secrets"},
        },
        color = {1.0, 0.9, 0.5},
        unlockType = "metric",
        unlockCondition = {stat = "healingDone", value = 5000},
        unlockHint = "Heal 5,000 total HP to unlock",
    },
    {
        id = "wraith",
        name = "Wraith",
        desc = "Spirits who have crossed death's threshold so often that the boundary no longer holds",
        statMods = {SPIRIT = 2, MIND = 1}, -- Was AGI+2/MIND+1 (identical to Elf); spectral nature fits SPIRIT
        bonuses = {
            {name = "Ethereal Form", desc = "+30% dodge, phase through first attack each combat, -20% max HP"},
            {name = "Death Walker", desc = "Revive with 25% HP once per adventure, +15% damage vs living, immune to poison"},
        },
        color = {0.5, 0.5, 0.7},
        unlockType = "achievement",
        unlockCondition = {achievement = "died_5_times"},
        unlockHint = "Die 5 times to unlock",
    },
    {
        id = "nomad",
        name = "Sandwalker",
        desc = "Desert wanderers of the Great Endless, hardened by sun and sand",
        statMods = {VIGOR = 2, AGILITY = 1},
        bonuses = {
            {name = "Wayfinder", desc = "+20% movement speed, -30% travel time, +2 tiles vision range on map"},
            {name = "Desert Endurance", desc = "+15% max HP, immune to exhaustion weather effects, +10% find rare resources"},
        },
        color = {0.85, 0.65, 0.3},
        unlockType = "metric",
        unlockCondition = {stat = "tilesExplored", value = 500},
        unlockHint = "Explore 500 map tiles to unlock",
    },
    {
        id = "automaton",
        name = "Automaton",
        desc = "Gnomish clockwork constructs that achieved self-awareness through arcane engineering",
        statMods = {VIGOR = 1, MIND = 1, MIGHT = 1},
        bonuses = {
            {name = "Mechanical Body", desc = "Immune to poison/disease/bleed, +15% armor, cannot be healed by potions (repair only)"},
            {name = "Precision Gears", desc = "+20% crafting quality, +10% crit damage, never miss attacks below 5% miss chance"},
        },
        color = {0.6, 0.7, 0.8},
        unlockType = "metric",
        unlockCondition = {stat = "itemsCrafted", value = 50},
        unlockHint = "Craft 50 items to unlock",
    },
    {
        id = "dark_elf",
        name = "Dark Elf",
        desc = "Shadow Fen exiles who traded sunlight for power beneath the Veil",
        statMods = {AGILITY = 2, MIGHT = 1}, -- Was AGI+2/PRES+1 (identical to Catfolk); MIGHT reflects combat exile training
        bonuses = {
            {name = "Shadow Meld", desc = "+30% stealth, +25% backstab damage, +15% crit from stealth"},
            {name = "Darkvision", desc = "No penalties at night, +20% damage at night, immune to surprise attacks"},
        },
        color = {0.4, 0.3, 0.6},
        unlockType = "metric",
        unlockCondition = {stat = "stealthKills", value = 30},
        unlockHint = "Perform 30 stealth kills to unlock",
    },
    {
        id = "merfolk",
        name = "Merfolk",
        desc = "Amphibious people of the deep waters, surfacing to walk among land-dwellers",
        statMods = {SPIRIT = 2, AGILITY = 1},
        bonuses = {
            {name = "Tidal Grace", desc = "+50% water movement, +25% fishing success, breathe underwater, +20% water magic"},
            {name = "Ocean's Bounty", desc = "+15% all loot in water areas, +10% mana regen, immune to drowning/whirlpools"},
        },
        color = {0.2, 0.6, 0.8},
        unlockType = "metric",
        unlockCondition = {stat = "fishCaught", value = 100},
        unlockHint = "Catch 100 fish to unlock",
    },
    {
        id = "dragonkin",
        name = "Dragonkin",
        desc = "Those who absorbed draconic essence, their blood forever changed by the encounter",
        statMods = {MIGHT = 2, FAITH = 1},
        bonuses = {
            {name = "Dragon Blood", desc = "+20% fire/frost resistance, +15% melee damage, intimidate weaker enemies into fleeing"},
            {name = "Scaled Hide", desc = "+10% natural armor, +5% to all resistances, breath attack usable once per combat"},
        },
        color = {0.8, 0.3, 0.1},
        unlockType = "achievement",
        unlockCondition = {achievement = "defeat_dragon"},
        unlockHint = "Defeat a dragon boss to unlock",
    },
    {
        id = "nephilim",
        name = "Nephilim",
        desc = "Ancient giant-blooded warriors whose lineage predates the Holy Dominion itself",
        statMods = {MIGHT = 1, VIGOR = 1, SPIRIT = 1},
        bonuses = {
            {name = "Titan's Legacy", desc = "+20% max HP, +15% melee damage, +10% all resistances, imposing presence"},
            {name = "Ancient Blood", desc = "+1 to all stats per 10 levels, immune to level drain, +10% XP from all sources"},
        },
        color = {0.7, 0.6, 0.9},
        unlockType = "metric",
        unlockCondition = {stat = "level", value = 50},
        unlockHint = "Reach level 50 to unlock",
    },
}

-- Character Backgrounds (7 consolidated, each +4 stat points)
-- Slimmed from 12 to 7: merged overlapping archetypes, bumped bonuses.
-- Removed dead fields (startingBounty, bannedTaverns, startingCompanion) that were never read.
-- Passives are implemented: each passive applies bonuses via getCharacterBonuses() and runtime hooks.
Data.BACKGROUNDS = {
    {
        id = "vampire_hunter",
        name = "Vampire Hunter",
        desc = "Dedicated to hunting the undead. +40% damage vs vampires/undead",
        startingGold = 50,
        statMods = {FAITH = 2, VIGOR = 1, MIGHT = 1},
        startingItems = {"tq_wooden_stake", "tq_silver_dagger", "tq_holy_water"},
        passives = {"undead_slayer", "vampire_sense", "stake_mastery"},
        tags = {"[Hunter]", "[Zealous]", "[Vengeful]"},
    },
    {
        id = "tavern_brawler",
        name = "Pit Fighter",
        desc = "Street-tough fighter who settled debts with fists. +50% unarmed damage, tracking bonuses",
        startingGold = 50,
        statMods = {VIGOR = 2, AGILITY = 1, SPIRIT = 1},
        startingItems = {"tq_brass_knuckles", "tq_bounty_license", "tq_rope"},
        passives = {"brawler", "thick_skinned", "tracker"},
        tags = {"[Brawler]", "[Mercenary]", "[Ruthless]"},
    },
    {
        id = "card_shark",
        name = "Card Shark",
        desc = "Professional gambler who lives by the cards. +40% card game win rate, +30% gambling rewards",
        startingGold = 0, -- Gambled it all away
        statMods = {MIND = 2, PRESENCE = 2},
        startingItems = {"tq_marked_deck", "tq_lucky_dice", "tq_poker_deck"},
        passives = {"card_master", "card_counter", "desperate_luck"},
        tags = {"[Gambler]", "[Cunning]", "[Risk Taker]"},
    },
    {
        id = "snake_oil_peddler",
        name = "Snake Oil Peddler",
        desc = "Traveling con artist. +35% sell prices, can scam NPCs",
        startingGold = 100,
        statMods = {PRESENCE = 2, MIND = 1, AGILITY = 1},
        startingItems = {"tq_fake_potions", "tq_merchants_disguise"},
        passives = {"silver_tongue", "scam_artist", "fast_talker"},
        tags = {"[Con Artist]", "[Charismatic]", "[Untrustworthy]"},
    },
    {
        id = "corruption_survivor",
        name = "Corruption Survivor",
        desc = "Survived lich corruption and bonded with wild spirits. +50% corruption resist, beast affinity",
        startingGold = 50,
        statMods = {SPIRIT = 2, VIGOR = 1, FAITH = 1},
        startingItems = {"tq_corruption_scar", "tq_purification_herbs", "tq_beast_whistle"},
        passives = {"corruption_resistant", "survivors_will", "animal_bond"},
        tags = {"[Survivor]", "[Haunted]", "[Feral]"},
    },
    {
        id = "dungeon_delver",
        name = "Ruin Scavenger",
        desc = "Seasoned explorer of ruins, depths, and waterways. +30% dungeon loot, +25% fishing success",
        startingGold = 50,
        statMods = {AGILITY = 2, MIND = 1, SPIRIT = 1},
        startingItems = {"tq_lockpicks", "tq_dungeon_map", "tq_master_fishing_rod"},
        passives = {"treasure_hunter", "trap_sense", "master_angler"},
        tags = {"[Explorer]", "[Resourceful]", "[Cautious]"},
    },
    {
        id = "cafe_veteran",
        name = "Flesh Broker",
        desc = "Procurer of corpses, secrets, and forbidden wares. +5% crit chance, +15% gold from all sources",
        startingGold = 35,
        statMods = {PRESENCE = 2, MIND = 1, AGILITY = 1},
        startingItems = {"tq_shadowed_cloak", "tq_bone_ledger", "tq_coin_purse"},
        passives = {"night_dealer", "corpse_sense", "black_market_access"},
        tags = {"[Underworld]", "[Cunning]", "[Profane]"},
    },
}

Data.PASSIVE_DESCRIPTIONS = {
    -- Vampire Hunter
    undead_slayer    = "+25% crit chance vs undead",
    vampire_sense    = "+15 defense vs undead enemies",
    stake_mastery    = "2.5x crit damage vs undead",
    -- Pit Fighter
    brawler          = "+50% melee damage when unarmed",
    thick_skinned    = "-3 flat damage reduction on hits",
    tracker          = "+15% melee damage",
    -- Card Shark
    card_master      = "+10% crit chance",
    card_counter     = "+5% dodge chance",
    desperate_luck   = "+25% crit chance when below 25% HP",
    -- Snake Oil Peddler
    silver_tongue    = "+20% sell prices",
    scam_artist      = "15% chance for double gold on kill",
    fast_talker      = "+25% flee success rate",
    -- Corruption Survivor
    corruption_resistant = "+20 corruption resistance",
    survivors_will   = "+3% HP regen/turn when below 25% HP",
    animal_bond      = "+25% companion damage",
    -- Ruin Scavenger
    treasure_hunter  = "+10% extra loot chance",
    trap_sense       = "+15% dodge on first attack per combat",
    master_angler    = "+5% XP bonus",
    -- Flesh Broker
    night_dealer     = "+5 gold per kill",
    corpse_sense     = "+10% extra loot chance",
    black_market_access = "+10% shop discount",
}

function Data.hasPassive(player, passiveId)
    if not player or not player.background or not player.background.passives then return false end
    for _, pid in ipairs(player.background.passives) do
        if pid == passiveId then return true end
    end
    return false
end

-- === KARMA/CRIME SYSTEM ===

-- Karma levels and their effects
Data.KARMA_LEVELS = {
    {min = 75, max = 100, name = "Saint", color = {1, 1, 0.3}, desc = "Revered by all lawful citizens"},
    {min = 25, max = 74, name = "Good", color = {0.5, 1, 0.5}, desc = "Respected member of society"},
    {min = 0, max = 24, name = "Neutral", color = {0.7, 0.7, 0.7}, desc = "Average citizen"},
    {min = -24, max = -1, name = "Chaotic", color = {0.9, 0.7, 0.3}, desc = "Known troublemaker"},
    {min = -74, max = -25, name = "Criminal", color = {0.9, 0.4, 0.2}, desc = "Wanted for crimes"},
    {min = -100, max = -75, name = "Villain", color = {0.9, 0.2, 0.2}, desc = "Kill on sight"},
}

-- Crime definitions
Data.CRIME_TYPES = {
    assault_civilian = {karma = -10, bounty = 50, name = "Assault", jailTime = 24},
    murder_civilian = {karma = -30, bounty = 500, name = "Murder", jailTime = 168},
    theft = {karma = -5, bounty = 25, name = "Theft", jailTime = 12},
    assault_guard = {karma = -20, bounty = 200, name = "Assaulting a Guard", jailTime = 72},
    murder_guard = {karma = -50, bounty = 1000, name = "Murdering a Guard", jailTime = 336},
    trespassing = {karma = -2, bounty = 10, name = "Trespassing", jailTime = 6},
    vampire_attack = {karma = -50, bounty = 1000, name = "Vampiric Attack", jailTime = 336},
}

-- === FACTION SYSTEM ===

-- Nation factions and guilds
Data.FACTIONS = {
    -- Nations
    holy_dominion = {
        id = "holy_dominion",
        name = "The Holy Dominion",
        type = "nation",
        description = "Human empire ruled by the High Priest",
        capital = "Solara",
        enemies = {"shadowfen_witches"},
        allies = {"blacksmith_guild", "merchants_guild"},
    },
    free_holds = {
        id = "free_holds",
        name = "The Free Holds of Stone",
        alternateName = "Dwarven Holds",
        type = "nation",
        description = "Collectivist labor federation in the northern mountains. No kings, no hierarchy--labor defines all. Guild councils govern through collective deliberation.",
        capital = "Ironhold",
        allies = {"blacksmith_guild", "miners_union"},
        traits = {"collectivist", "guild_councils", "no_hierarchy", "stone_born"},
    },
    orcish_clans = {
        id = "orcish_clans",
        name = "Orcish Clans",
        alternateName = "The Khanate (historical)",
        type = "nation",
        description = "Nomadic steppe warriors who once formed history's most effective military civilization. Currently fragmented but dormant--the laws still exist, the routes remembered.",
        capital = "Kragmor",
        traits = {"nomadic", "merit-based", "disciplined", "historically_unified"},
        warfare = "Speed, intelligence, psychological collapse. Wars of collapse, not attrition.",
        imperialFear = "They do not need to grow stronger. They only need to unite again.",
    },
    shadowfen_commune = {
        id = "shadowfen_commune",
        name = "Shadow Fen Commune",
        alternateName = "The Veiled Refuge",
        type = "commune",
        description = "Magically concealed refuge in the southwestern swamps. Former refugees, fugitive mages, and outlaws who fled imperial control. Governed by collective necessity, not ideology.",
        capital = "Murkmire",
        allies = {"thieves_guild"},
        traits = {"concealed", "magical_refuge", "anarchist", "multi_racial"},
    },
    gnomish_collective = {
        id = "gnomish_collective",
        name = "The Gnomish Collective",
        type = "nation",
        description = "Collectivist island nation with no private ownership. Ruled by production councils, not elected representatives. Efficiency and function define prestige.",
        capital = "Mechspire",
        traits = {"collectivist", "industrial", "secretive", "no_religion", "production_councils"},
        philosophy = "Function, not ownership. Prestige from contribution, not accumulation.",
    },

    -- Lawful Guilds
    blacksmith_guild = {
        id = "blacksmith_guild",
        name = "Blacksmith's Guild",
        type = "guild",
        description = "Elite craftsmen forging finest weapons",
        joinRequirements = {minKarma = 0},
        benefits = {craftingBonus = 0.15, shopDiscount = 0.1},
    },
    merchants_guild = {
        id = "merchants_guild",
        name = "Merchant's Guild",
        type = "guild",
        description = "Trading consortium",
        joinRequirements = {minKarma = 10, gold = 500},
        benefits = {shopDiscount = 0.2, sellBonus = 0.15},
    },
    adventurers_guild = {
        id = "adventurers_guild",
        name = "Adventurer's Guild",
        type = "guild",
        description = "Monster hunters and quest takers",
        joinRequirements = {minKarma = 0, enemiesDefeated = 10},
        benefits = {questRewardBonus = 0.25, combatXPBonus = 0.1},
    },
    mages_guild = {
        id = "mages_guild",
        name = "The Sanctioned Arcanum",
        type = "guild",
        description = "State-authorized magic practitioners under Dominion oversight. Imperial sanction required.",
        joinRequirements = {minKarma = 5},
        benefits = {spellDamageBonus = 0.15, manaRegenBonus = 2},
    },

    -- Crime Organizations
    thieves_guild = {
        id = "thieves_guild",
        name = "Thieves' Guild",
        type = "crime",
        description = "Shadow network of thieves",
        joinRequirements = {maxKarma = -10},
        benefits = {lockpickBonus = 0.3, stealthBonus = 0.2},
    },
    assassins_guild = {
        id = "assassins_guild",
        name = "Assassin's Guild",
        type = "crime",
        description = "Elite killers for hire",
        joinRequirements = {maxKarma = -25, murders = 5},
        benefits = {critDamageBonus = 0.3, poisonBonus = 0.5},
    },
    smugglers_ring = {
        id = "smugglers_ring",
        name = "Smuggler's Ring",
        type = "crime",
        description = "Underground contraband network",
        joinRequirements = {maxKarma = -5},
        benefits = {travelCostReduction = 0.5},
    },

    -- Fighters Guild (expanded from adventurers_guild)
    fighters_guild = {
        id = "fighters_guild",
        name = "The Steel Brotherhood",
        type = "guild",
        description = "Warriors, mercenaries, and monster hunters united under a common banner",
        joinRequirements = {minLevel = 3, minKarma = -20},
        benefits = {combatXPBonus = 0.15, critBonus = 0.05},
    },

    -- Unions
    miners_union = {
        id = "miners_union",
        name = "Miner's Union",
        type = "union",
        description = "Brotherhood of miners",
        joinRequirements = {minKarma = 0},
        benefits = {miningYieldBonus = 0.2},
    },
    craftsmen_union = {
        id = "craftsmen_union",
        name = "Craftsmen's Union",
        type = "union",
        description = "Alliance of artisans",
        joinRequirements = {minKarma = 5},
        benefits = {craftingSpeedBonus = 0.15},
    },
}

-- Reputation levels
Data.REPUTATION_LEVELS = {
    {min = 90, max = 100, name = "Exalted", color = {1, 0.85, 0}},
    {min = 60, max = 89, name = "Honored", color = {0.3, 1, 0.3}},
    {min = 30, max = 59, name = "Friendly", color = {0.5, 0.9, 0.5}},
    {min = 0, max = 29, name = "Neutral", color = {0.7, 0.7, 0.7}},
    {min = -29, max = -1, name = "Unfriendly", color = {0.9, 0.7, 0.3}},
    {min = -59, max = -30, name = "Hostile", color = {0.9, 0.5, 0.2}},
    {min = -89, max = -60, name = "Hated", color = {0.9, 0.3, 0.2}},
    {min = -100, max = -90, name = "Kill on Sight", color = {1, 0.2, 0.2}},
}

-- Get reputation level info
function Data.getReputationLevel(rep)
    for _, level in ipairs(Data.REPUTATION_LEVELS) do
        if rep >= level.min and rep <= level.max then
            return level
        end
    end
    return Data.REPUTATION_LEVELS[4] -- Default to Neutral
end

-- === ATTRIBUTE SYSTEM ===

-- Stat definitions with descriptions of what each stat does
Data.STAT_DEFINITIONS = {
    MIGHT = {
        name = "Might",
        abbrev = "MIG",
        desc = "+2 melee damage per modifier, carry capacity",
        color = {0.9, 0.3, 0.3},
    },
    AGILITY = {
        name = "Agility",
        abbrev = "AGI",
        desc = "+2% crit/dodge per modifier",
        color = {0.3, 0.9, 0.5},
    },
    VIGOR = {
        name = "Vigor",
        abbrev = "VIG",
        desc = "+2 HP per level per modifier, poison resist",
        color = {0.9, 0.5, 0.3},
    },
    MIND = {
        name = "Mind",
        abbrev = "MIN",
        desc = "+3 spell damage per modifier, +5 mana per modifier",
        color = {0.4, 0.5, 0.9},
    },
    SPIRIT = {
        name = "Spirit",
        abbrev = "SPI",
        desc = "+2 healing per modifier, mana regen",
        color = {0.8, 0.7, 0.9},
    },
    PRESENCE = {
        name = "Presence",
        abbrev = "PRE",
        desc = "Shop discount %, companion morale",
        color = {0.9, 0.8, 0.4},
    },
    FAITH = {
        name = "Faith",
        abbrev = "FAI",
        desc = "Holy damage, vampire resist, corruption resist",
        color = {1.0, 1.0, 0.8},
    },
}

-- Base stats for each class (all normalized to 80 total stat points)
Data.CLASS_BASE_STATS = {
    warrior = {MIGHT = 16, AGILITY = 12, VIGOR = 14, MIND = 8,  SPIRIT = 10, PRESENCE = 10, FAITH = 10}, -- 80
    mage    = {MIGHT = 8,  AGILITY = 10, VIGOR = 10, MIND = 16, SPIRIT = 14, PRESENCE = 12, FAITH = 10}, -- 80
    rogue   = {MIGHT = 10, AGILITY = 16, VIGOR = 14, MIND = 12, SPIRIT = 10, PRESENCE = 10, FAITH = 8},  -- 80 (was 78: +2 VIG)
    cleric  = {MIGHT = 10, AGILITY = 10, VIGOR = 12, MIND = 10, SPIRIT = 16, PRESENCE = 8,  FAITH = 14}, -- 80 (was 86: -2 MIGHT, -2 PRES, -2 FAITH)
    ranger  = {MIGHT = 12, AGILITY = 16, VIGOR = 12, MIND = 10, SPIRIT = 12, PRESENCE = 8,  FAITH = 10}, -- 80
    monk    = {MIGHT = 14, AGILITY = 14, VIGOR = 12, MIND = 10, SPIRIT = 12, PRESENCE = 8,  FAITH = 10}, -- 80
}

-- === ASCENSION SYSTEM ===
-- IMPORTANT: Ascension progress is ACCOUNT-WIDE (stored in PlayerData)
-- This means AP, unlocked skills, and ascension count persist across:
-- - Different characters (new race, class, etc.)
-- - Different save files
-- - Death and restart
-- Players keep their ascension progress forever!

-- Ascension configuration
Data.ASCENSION_CONFIG = {
    requiredLevel = 100,              -- Must be max level to ascend
    baseAPReward = 10,                -- Base AP earned per ascension
    levelBonusAP = 0.1,               -- +0.1 AP per level (10 AP at L100)
    questBonusAP = 0.5,               -- +0.5 AP per quest completed
    killBonusAP = 0.01,               -- +0.01 AP per enemy defeated
    goldBonusAP = 0.001,              -- +0.001 AP per 1000 gold earned
    -- Permanent stat bonus uses diminishing returns: 2% * sqrt(ascensionCount)
    -- Asc 1: 2%, Asc 4: 4%, Asc 9: 6%, Asc 16: 8%, Asc 25: 10%, Asc 100: 20%
    permanentStatBonusBase = 0.02,    -- Base multiplier for permanent bonus
    -- NO CAP on ascensions - infinite progression!
}

-- Ascension Tree: Universal skills that persist across resets
-- STACKABLE SYSTEM: Each skill can be ranked up multiple times!
-- Each skill has TWO paths (A and B) - choose one, then rank it up infinitely
-- Effects scale with rank (rank 5 = 5x the base effect)
-- Cost increases per rank: baseCost + (currentRank * costPerRank)
Data.ASCENSION_TREE = {
    -- =========================================================================
    -- TIER 1: Fundamentals (no prerequisites)
    -- =========================================================================
    {
        id = "vitality",
        tier = 1,
        baseCost = 2,
        costPerRank = 1,        -- Rank 1: 2 AP, Rank 2: 3 AP, Rank 3: 4 AP...
        maxRank = nil,          -- No cap!
        requires = nil,
        pathA = {
            name = "Greater Vitality",
            desc = "+5% max HP per rank",
            effectPerRank = {hpMultiplierAdd = 0.05},  -- Rank 5 = +25% HP
        },
        pathB = {
            name = "Rapid Recovery",
            desc = "+0.5% HP regen per turn per rank",
            effectPerRank = {hpRegenPercent = 0.005},  -- Rank 10 = 5% regen
        },
    },
    {
        id = "arcana",
        tier = 1,
        baseCost = 2,
        costPerRank = 1,
        maxRank = nil,
        requires = nil,
        pathA = {
            name = "Deep Reserves",
            desc = "+6% max mana per rank",
            effectPerRank = {manaMultiplierAdd = 0.06},
        },
        pathB = {
            name = "Mana Siphon",
            desc = "+1% mana restored on kill per rank",
            effectPerRank = {manaOnKill = 0.01},
        },
    },
    {
        id = "fortune",
        tier = 1,
        baseCost = 1,
        costPerRank = 1,
        maxRank = nil,
        requires = nil,
        pathA = {
            name = "Golden Touch",
            desc = "+5% gold from all sources per rank",
            effectPerRank = {goldMultiplierAdd = 0.05},
        },
        pathB = {
            name = "Lucky Finds",
            desc = "+3% item drop rate per rank",
            effectPerRank = {dropRateBonus = 0.03},
        },
    },
    {
        id = "swiftness",
        tier = 1,
        baseCost = 2,
        costPerRank = 1,
        maxRank = nil,
        requires = nil,
        pathA = {
            name = "Fleet Foot",
            desc = "+2% dodge chance per rank",
            effectPerRank = {dodgeBonus = 2},
        },
        pathB = {
            name = "First Strike",
            desc = "+3% chance to act first in combat per rank",
            effectPerRank = {initiativeBonus = 3},
        },
    },

    -- =========================================================================
    -- TIER 2: Combat Enhancement (requires any Tier 1 at rank 3+)
    -- =========================================================================
    {
        id = "precision",
        tier = 2,
        baseCost = 3,
        costPerRank = 2,
        maxRank = nil,
        requires = {"vitality:3"},  -- Requires vitality at rank 3
        pathA = {
            name = "Deadly Precision",
            desc = "+2% critical hit chance per rank",
            effectPerRank = {critBonus = 2},
        },
        pathB = {
            name = "Brutal Crits",
            desc = "+10% critical hit damage per rank",
            effectPerRank = {critDamageBonus = 0.10},
        },
    },
    {
        id = "resilience",
        tier = 2,
        baseCost = 3,
        costPerRank = 2,
        maxRank = nil,
        requires = {"vitality:3"},
        pathA = {
            name = "Iron Skin",
            desc = "+3% damage reduction per rank",
            effectPerRank = {damageReduction = 0.03},
        },
        pathB = {
            name = "Thorns",
            desc = "Reflect 2% damage taken per rank",
            effectPerRank = {thornsDamage = 0.02},
        },
    },
    {
        id = "spellweaving",
        tier = 2,
        baseCost = 3,
        costPerRank = 2,
        maxRank = nil,
        requires = {"arcana:3"},
        pathA = {
            name = "Spell Amplification",
            desc = "+5% spell damage per rank",
            effectPerRank = {spellDamageAdd = 0.05},
        },
        pathB = {
            name = "Efficiency",
            desc = "-3% mana cost per rank (max -50%)",
            effectPerRank = {manaCostReduction = 0.03},
            effectCap = {manaCostReduction = 0.50},
        },
    },
    {
        id = "warfare",
        tier = 2,
        baseCost = 3,
        costPerRank = 2,
        maxRank = nil,
        requires = {"swiftness:3"},
        pathA = {
            name = "Brutality",
            desc = "+3% physical damage per rank",
            effectPerRank = {physicalDamageAdd = 0.03},
        },
        pathB = {
            name = "Battle Hardened",
            desc = "+2 flat defense per rank",
            effectPerRank = {flatDefense = 2},
        },
    },
    {
        id = "accumulation",
        tier = 2,
        baseCost = 2,
        costPerRank = 2,
        maxRank = nil,
        requires = {"fortune:3"},
        pathA = {
            name = "Hoarder",
            desc = "+2% shop sell prices per rank",
            effectPerRank = {sellBonus = 0.02},
        },
        pathB = {
            name = "Bargainer",
            desc = "-2% shop buy prices per rank",
            effectPerRank = {buyDiscount = 0.02},
        },
    },

    -- =========================================================================
    -- TIER 3: Advanced Powers (requires 2 different Tier 2 skills at rank 5+)
    -- =========================================================================
    {
        id = "vampirism",
        tier = 3,
        baseCost = 5,
        costPerRank = 3,
        maxRank = nil,
        requires = {"precision:5", "resilience:5"},
        pathA = {
            name = "Life Steal",
            desc = "+2% life steal per rank",
            effectPerRank = {lifeSteal = 0.02},
        },
        pathB = {
            name = "Blood Frenzy",
            desc = "+1% attack per enemy killed this combat per rank",
            effectPerRank = {bloodFrenzyBonus = 0.01},
        },
    },
    {
        id = "sorcery",
        tier = 3,
        baseCost = 5,
        costPerRank = 3,
        maxRank = nil,
        requires = {"spellweaving:5"},
        pathA = {
            name = "Elemental Mastery",
            desc = "+4% elemental damage per rank",
            effectPerRank = {elementalDamageAdd = 0.04},
        },
        pathB = {
            name = "Spell Echo",
            desc = "+2% chance to cast spells twice per rank",
            effectPerRank = {spellEchoChance = 0.02},
        },
    },
    {
        id = "prosperity",
        tier = 3,
        baseCost = 4,
        costPerRank = 2,
        maxRank = nil,
        requires = {"accumulation:5", "fortune:5"},
        pathA = {
            name = "Treasure Hunter",
            desc = "+3% rare item drop chance per rank",
            effectPerRank = {rareDropBonus = 0.03},
        },
        pathB = {
            name = "XP Boost",
            desc = "+4% XP gain per rank",
            effectPerRank = {xpMultiplierAdd = 0.04},
        },
    },
    {
        id = "commander",
        tier = 3,
        baseCost = 5,
        costPerRank = 3,
        maxRank = nil,
        requires = {"warfare:5"},
        pathA = {
            name = "Warlord",
            desc = "+2% party damage per rank",
            effectPerRank = {partyDamageBonus = 0.02},
        },
        pathB = {
            name = "Tactician",
            desc = "+2% party defense per rank",
            effectPerRank = {partyDefenseBonus = 0.02},
        },
    },

    -- =========================================================================
    -- TIER 4: Ultimate Powers (requires Ascension 3+ and Tier 3 at rank 10+)
    -- =========================================================================
    {
        id = "immortality",
        tier = 4,
        baseCost = 10,
        costPerRank = 5,
        maxRank = 10,  -- Capped at rank 10
        requires = {"vampirism:10"},
        minAscension = 3,
        pathA = {
            name = "Undying",
            desc = "+5% revive HP per rank (revive once per combat)",
            effectPerRank = {reviveHP = 0.05},
            effectBase = {autoRevive = true},  -- Base effect at rank 1
        },
        pathB = {
            name = "Transcendence",
            desc = "+3% HP shield at combat start per rank",
            effectPerRank = {combatShield = 0.03},
        },
    },
    {
        id = "annihilation",
        tier = 4,
        baseCost = 10,
        costPerRank = 5,
        maxRank = nil,
        requires = {"sorcery:10"},
        minAscension = 3,
        pathA = {
            name = "Godslayer",
            desc = "+10% damage to bosses per rank",
            effectPerRank = {bossDamageAdd = 0.10},
        },
        pathB = {
            name = "Executioner",
            desc = "+5% damage to enemies below 30% HP per rank",
            effectPerRank = {executeBonus = 0.05},
        },
    },
    {
        id = "ascendancy",
        tier = 4,
        baseCost = 8,
        costPerRank = 4,
        maxRank = nil,
        requires = {"prosperity:10"},
        minAscension = 3,
        pathA = {
            name = "Avatar",
            desc = "+1% to ALL stats per rank",
            effectPerRank = {allStatsAdd = 0.01},
        },
        pathB = {
            name = "Paragon",
            desc = "+5% XP and +3% gold per rank",
            effectPerRank = {xpMultiplierAdd = 0.05, goldMultiplierAdd = 0.03},
        },
    },

    -- =========================================================================
    -- TIER 5: Legendary Powers (requires Ascension 7+ and Tier 4 at rank 10+)
    -- =========================================================================
    {
        id = "eternal",
        tier = 5,
        baseCost = 20,
        costPerRank = 10,
        maxRank = nil,
        requires = {"immortality:10", "annihilation:10"},
        minAscension = 7,
        pathA = {
            name = "Deathless",
            desc = "+1 extra revive per combat per 5 ranks",
            effectPerRank = {extraRevives = 0.2},  -- Rank 5 = 1 extra, Rank 10 = 2 extra
        },
        pathB = {
            name = "Phoenix Soul",
            desc = "+2% HP regen when below 25% HP per rank",
            effectPerRank = {lowHpRegen = 0.02},
        },
    },
    {
        id = "omnipotence",
        tier = 5,
        baseCost = 25,
        costPerRank = 12,
        maxRank = nil,
        requires = {"ascendancy:10"},
        minAscension = 7,
        pathA = {
            name = "Infinite Power",
            desc = "+2% to ALL damage per rank",
            effectPerRank = {allDamageAdd = 0.02},
        },
        pathB = {
            name = "Boundless",
            desc = "+1% to ALL resistances per rank",
            effectPerRank = {allResistAdd = 0.01},
        },
    },
    {
        id = "genesis",
        tier = 5,
        baseCost = 30,
        costPerRank = 15,
        maxRank = nil,
        requires = {"omnipotence:5"},
        minAscension = 10,
        pathA = {
            name = "Creator",
            desc = "+1% chance for double loot per rank",
            effectPerRank = {doubleLootChance = 0.01},
        },
        pathB = {
            name = "Destroyer",
            desc = "+1% chance for instant kill (non-boss) per rank (max 25%)",
            effectPerRank = {instantKillChance = 0.01},
            effectCap = {instantKillChance = 0.25},
        },
    },
}

Data.UNIVERSAL_TALENTS = {
    -- Level 3 talents
    {id = "tough", name = "Tough", level = 3,
     desc = "+15% max HP",
     effect = {hpMultiplier = 1.15}},
    {id = "quick", name = "Quick", level = 3,
     desc = "+10% dodge chance",
     effect = {dodgeBonus = 10}},
    {id = "focused", name = "Focused", level = 3,
     desc = "+20% max mana",
     effect = {manaMultiplier = 1.2}},
    {id = "lucky", name = "Lucky", level = 3,
     desc = "+5% crit chance",
     effect = {critBonus = 5}},
    -- Level 6 talents
    {id = "enduring", name = "Enduring", level = 6,
     desc = "+25% DoT resistance",
     effect = {dotResist = 0.25}},
    {id = "deadly", name = "Deadly", level = 6,
     desc = "+25% critical hit damage",
     effect = {critDamageBonus = 0.25}},
    {id = "sentinel", name = "Sentinel", level = 6,
     desc = "+5 defense",
     effect = {defenseBonus = 5}},
    -- Level 9 talents
    {id = "athlete", name = "Athlete", level = 9,
     desc = "+50 carry capacity",
     effect = {carryBonus = 50}},
    {id = "merchant", name = "Merchant", level = 9,
     desc = "+15% better shop prices",
     effect = {shopBonus = 15}},
    -- Level 12 talents
    {id = "leader", name = "Leader", level = 12,
     desc = "+1 party slot",
     effect = {partySlotBonus = 1}},
}

-- Class-specific talents
Data.CLASS_TALENTS = {
    warrior = {
        {id = "weapon_master", name = "Weapon Master", level = 3,
         desc = "+20% weapon damage",
         effect = {weaponDamageMult = 1.2}},
        {id = "armor_expert", name = "Armor Expert", level = 6,
         desc = "+30% armor effectiveness",
         effect = {armorMult = 1.3}},
        {id = "second_wind", name = "Second Wind", level = 9,
         desc = "Once per combat, heal 25% HP when below 20%",
         effect = {secondWind = true, healPercent = 0.25, triggerPercent = 0.2}},
        {id = "warlord", name = "Warlord", level = 12,
         desc = "Party members gain +10% damage",
         effect = {partyDamageBonus = 0.1}},
    },
    mage = {
        {id = "spell_power", name = "Spell Power", level = 3,
         desc = "+25% spell damage",
         effect = {spellDamageMult = 1.25}},
        {id = "mana_flow", name = "Mana Flow", level = 6,
         desc = "Regenerate 5% max mana per turn",
         effect = {manaRegenPercent = 0.05}},
        {id = "arcane_shield", name = "Arcane Shield", level = 9,
         desc = "10% of damage absorbed by mana instead",
         effect = {manaShield = 0.1}},
        {id = "archmage", name = "Archmage", level = 12,
         desc = "Spells have 20% chance to cost no mana",
         effect = {freeCastChance = 0.2}},
    },
    rogue = {
        {id = "precision", name = "Precision", level = 3,
         desc = "+15% crit chance",
         effect = {critBonus = 15}},
        {id = "evasion", name = "Evasion", level = 6,
         desc = "+20% dodge chance",
         effect = {dodgeBonus = 20}},
        {id = "opportunist", name = "Opportunist", level = 9,
         desc = "+50% damage to stunned/slowed enemies",
         effect = {ccDamageBonus = 0.5}},
        {id = "shadow_master", name = "Shadow Master", level = 12,
         desc = "Start combat in stealth, +30% backstab damage",
         effect = {startStealthed = true, backstabBonus = 0.3}},
    },
    cleric = {
        {id = "blessed", name = "Blessed", level = 3,
         desc = "+30% healing done",
         effect = {healingMult = 1.3}},
        {id = "holy_aura", name = "Holy Aura", level = 6,
         desc = "Party takes 10% less damage from undead/demons",
         effect = {undeadResist = 0.1, demonResist = 0.1}},
        {id = "martyr", name = "Martyr", level = 9,
         desc = "Can sacrifice HP to heal allies 1:1",
         effect = {martyrHeal = true}},
        {id = "divine_favor", name = "Divine Favor", level = 12,
         desc = "20% chance for heals to heal double",
         effect = {doubleHealChance = 0.2}},
    },
}

-- === SPECIALIZATION SYSTEM (Level 10) ===
Data.SPECIALIZATIONS = {
    warrior = {
        {id = "berserker", name = "Berserker", desc = "Fury-driven warrior trading defense for offense", color = {0.9, 0.2, 0.2},
         bonuses = {attackMult = 1.25, critBonus = 10, defenseMult = 0.85, hpPerLevelBonus = 3},
         passives = {"Bloodlust: +5% attack per kill", "Reckless Strike: +50% damage, +25% taken"},
         newSkills = {"Rampage", "Blood Frenzy"}},
        {id = "guardian", name = "Guardian", desc = "Unbreakable defender protecting allies", color = {0.3, 0.5, 0.8},
         bonuses = {defenseMult = 1.30, hpMult = 1.20, attackMult = 0.90},
         passives = {"Stalwart: -20% damage below 50% HP", "Protector: Allies take -15% damage"},
         newSkills = {"Shield Wall", "Righteous Stand"}},
    },
    mage = {
        {id = "archmage", name = "Archmage", desc = "Master of devastating elemental magic", color = {0.6, 0.3, 0.9},
         bonuses = {spellDamageMult = 1.40, manaMult = 1.25, defenseMult = 0.80, manaRegen = 3},
         passives = {"Arcane Surge: Spell crits restore 10% mana", "Elemental Mastery: Ignore 25% resistance"},
         newSkills = {"Arcane Barrage", "Prismatic Ray"}},
        {id = "battlemage", name = "Battlemage", desc = "Warrior-mage weaving spells into combat", color = {0.5, 0.4, 0.7},
         bonuses = {attackMult = 1.15, spellDamageMult = 1.15, defenseMult = 1.10, hpMult = 1.10},
         passives = {"Spellblade: +20% INT as magic melee damage", "Arcane Armor: 15% damage to mana"},
         newSkills = {"Arcane Strike", "Mana Shield"}},
    },
    rogue = {
        {id = "assassin", name = "Assassin", desc = "Deadly killer striking from shadows", color = {0.2, 0.2, 0.3},
         bonuses = {critBonus = 20, critDamageMult = 1.50, attackMult = 1.10, hpMult = 0.90},
         passives = {"Death Mark: +5% damage per hit on same target", "Execute: 2x damage below 20% HP"},
         newSkills = {"Marked for Death", "Shadow Strike"}},
        {id = "shadowdancer", name = "Shadowdancer", desc = "Elusive trickster bending shadows", color = {0.4, 0.3, 0.5},
         bonuses = {dodgeBonus = 25, speedMult = 1.20, attackMult = 1.05},
         passives = {"Shadowmeld: 30% invisible after dodge", "Mirror Image: 20% attacks hit illusion"},
         newSkills = {"Shadow Step", "Phantom Dance"}},
    },
    cleric = {
        {id = "paladin", name = "Paladin", desc = "Holy warrior smiting evil", color = {0.9, 0.8, 0.3},
         bonuses = {attackMult = 1.20, defenseMult = 1.15, healingMult = 0.85, holyDamageMult = 1.30},
         passives = {"Divine Smite: Bonus holy vs undead/demons", "Aura of Courage: Party immune to fear"},
         newSkills = {"Crusader Strike", "Lay on Hands"}},
        {id = "high_priest", name = "High Priest", desc = "Devoted healer with miraculous power", color = {1.0, 0.95, 0.8},
         bonuses = {healingMult = 1.50, manaMult = 1.30, attackMult = 0.75, shieldMult = 1.25},
         passives = {"Divine Grace: 25% cleanse on heal", "Sanctuary: Prevent one killing blow"},
         newSkills = {"Mass Heal", "Guardian Angel"}},
    },
    ranger = {
        {id = "sharpshooter", name = "Sharpshooter", desc = "Deadly marksman who never misses", color = {0.2, 0.7, 0.3},
         bonuses = {critBonus = 15, attackMult = 1.25, critDamageMult = 1.40, defenseMult = 0.90},
         passives = {"Steady Aim: +10% crit after standing still", "Headshot: 2x damage below 25% HP"},
         newSkills = {"Sniper Shot", "Rain of Arrows"}},
        {id = "beastmaster", name = "Beastmaster", desc = "Wild companion who fights alongside nature", color = {0.5, 0.7, 0.3},
         bonuses = {hpMult = 1.15, attackMult = 1.10, defenseMult = 1.10},
         passives = {"Animal Bond: Summon beast companion in combat", "Wild Instinct: +15% dodge in forests"},
         newSkills = {"Call Beast", "Primal Roar"}},
    },
    monk = {
        {id = "grandmaster", name = "Grandmaster", desc = "Perfected martial artist with devastating techniques", color = {0.9, 0.7, 0.2},
         bonuses = {attackMult = 1.30, critBonus = 15, speedMult = 1.20, defenseMult = 0.90},
         passives = {"Flowing Strikes: +5% damage per consecutive hit", "Perfect Form: Dodge first attack each combat"},
         newSkills = {"Thousand Fists", "Dragon Kick"}},
        {id = "zen_master", name = "Zen Master", desc = "Enlightened warrior channeling inner peace into power", color = {0.7, 0.8, 0.9},
         bonuses = {defenseMult = 1.25, hpMult = 1.15, healingMult = 1.20, manaMult = 1.20},
         passives = {"Inner Peace: Regenerate 3% HP per turn", "Enlightenment: +25% mana efficiency"},
         newSkills = {"Tranquil Palm", "Spirit Wave"}},
    },
}

function Data.getSpecializationOptions(classId)
    return Data.SPECIALIZATIONS[classId] or {}
end

-- Damage types for skills and resistances
Data.DAMAGE_TYPES = {
    physical = {name = "Physical", color = {0.8, 0.6, 0.4}},
    fire = {name = "Fire", color = {1, 0.4, 0.2}},
    ice = {name = "Ice", color = {0.4, 0.8, 1}},
    lightning = {name = "Lightning", color = {0.9, 0.9, 0.3}},
    holy = {name = "Holy", color = {1, 1, 0.6}},
    dark = {name = "Dark", color = {0.5, 0.3, 0.6}},
    poison = {name = "Poison", color = {0.4, 0.8, 0.4}},
    arcane = {name = "Arcane", color = {0.7, 0.5, 0.9}},
}

Data.SKILLS = {
    ["Power Strike"] = {manaCost = 10, damage = 25, damageType = "physical", desc = "A powerful melee attack"},
    ["Shield Bash"] = {manaCost = 15, damage = 15, damageType = "physical", stun = true, desc = "Stun the enemy"},
    ["Battle Cry"] = {manaCost = 20, buff = "attack", buffAmount = 5, duration = 3, desc = "+5 ATK for 3 turns"},
    ["Fireball"] = {manaCost = 20, damage = 35, damageType = "fire", desc = "Blast of fire"},
    ["Ice Shard"] = {manaCost = 15, damage = 25, damageType = "ice", slow = true, desc = "Freezing ice shard"},
    ["Lightning Bolt"] = {manaCost = 30, damage = 50, damageType = "lightning", desc = "Devastating lightning"},
    ["Backstab"] = {manaCost = 15, damage = 30, damageType = "physical", critBonus = 30, desc = "High crit chance"},
    ["Poison Blade"] = {manaCost = 20, damage = 10, damageType = "poison", dot = 5, dotDuration = 3, desc = "Poison over time"},
    ["Vanish"] = {manaCost = 25, dodge = 3, desc = "Dodge attacks for 3 turns"},
    ["Heal"] = {manaCost = 15, heal = 30, desc = "Restore 30 HP"},
    ["Smite"] = {manaCost = 20, damage = 25, damageType = "holy", desc = "Holy damage"},
    ["Divine Shield"] = {manaCost = 30, shield = 20, duration = 2, desc = "Block 20 damage for 2 turns"},
    -- Ranger skills
    ["Precise Shot"] = {manaCost = 12, damage = 28, damageType = "physical", critBonus = 15, desc = "A carefully aimed shot"},
    ["Hunter's Mark"] = {manaCost = 15, debuff = "marked", duration = 3, desc = "Mark target, +25% damage taken"},
    ["Volley"] = {manaCost = 25, damage = 20, damageType = "physical", aoe = true, desc = "Rain arrows on all enemies"},
    -- Monk skills
    ["Flurry of Blows"] = {manaCost = 10, damage = 12, damageType = "physical", hits = 3, desc = "Rapid 3-hit combo"},
    ["Claw Strike"] = {manaCost = 15, damage = 30, damageType = "physical", critBonus = 20, desc = "Vicious strike with high crit"},
    ["Inner Focus"] = {manaCost = 5, heal = 20, buff = "defense", buffAmount = 3, duration = 2, desc = "Heal 20 HP, +3 DEF"},
    -- Bow skills (require bow equipped)
    ["Quick Shot"] = {manaCost = 8, damage = 20, damageType = "physical", weaponType = "bow", desc = "Swift arrow attack"},
    ["Aimed Shot"] = {manaCost = 15, damage = 35, damageType = "physical", critBonus = 20, weaponType = "bow", desc = "Carefully aimed shot with high crit"},
    ["Multishot"] = {manaCost = 20, damage = 15, damageType = "physical", hits = 3, weaponType = "bow", desc = "Fire 3 arrows rapidly"},
    ["Piercing Arrow"] = {manaCost = 25, damage = 40, damageType = "physical", armorPen = 50, weaponType = "bow", desc = "Arrow ignores 50% armor"},
    -- Crossbow skills (require crossbow equipped)
    ["Bolt Shot"] = {manaCost = 10, damage = 28, damageType = "physical", weaponType = "crossbow", desc = "Heavy crossbow bolt"},
    ["Explosive Bolt"] = {manaCost = 20, damage = 35, damageType = "fire", aoe = true, weaponType = "crossbow", desc = "Explosive fire bolt hits all enemies"},
    ["Sniper Shot"] = {manaCost = 18, damage = 45, damageType = "physical", critBonus = 15, weaponType = "crossbow", desc = "Devastating long-range shot"},
    -- Throwing weapon skills (require thrown equipped)
    ["Fan of Blades"] = {manaCost = 12, damage = 18, damageType = "physical", hits = 3, weaponType = "thrown", desc = "Throw 3 weapons rapidly"},
    ["Precision Throw"] = {manaCost = 15, damage = 32, damageType = "physical", critBonus = 25, weaponType = "thrown", desc = "Deadly accurate throw"},
    -- Wand skills (require wand equipped)
    ["Magic Missile"] = {manaCost = 10, damage = 22, damageType = "arcane", weaponType = "wand", desc = "Focused arcane bolt"},
    ["Arcane Barrage"] = {manaCost = 18, damage = 16, damageType = "arcane", hits = 4, weaponType = "wand", desc = "Rapid arcane strikes"},
    ["Spell Burst"] = {manaCost = 25, damage = 45, damageType = "arcane", weaponType = "wand", desc = "Powerful arcane explosion"},
    -- Melee weapon skills (require sword/axe/mace - NOT ranged)
    ["Cleave"] = {manaCost = 12, damage = 28, damageType = "physical", weaponType = "melee", desc = "Powerful melee strike"},
    ["Whirlwind"] = {manaCost = 20, damage = 22, damageType = "physical", aoe = true, weaponType = "melee", desc = "Spin and strike all enemies"},
    ["Execute"] = {manaCost = 15, damage = 40, damageType = "physical", executeThreshold = 30, weaponType = "melee", desc = "Massive damage to enemies below 30% HP"},
    -- New elemental skills
    ["Flame Strike"] = {manaCost = 18, damage = 35, damageType = "fire", desc = "Fiery melee attack"},
    ["Frost Nova"] = {manaCost = 22, damage = 28, damageType = "ice", aoe = true, slow = true, desc = "Freeze all enemies"},
    ["Chain Lightning"] = {manaCost = 25, damage = 30, damageType = "lightning", hits = 3, desc = "Lightning bounces to 3 enemies"},
    ["Shadow Strike"] = {manaCost = 16, damage = 32, damageType = "dark", critBonus = 20, desc = "Dark energy strike"},
    ["Holy Wrath"] = {manaCost = 24, damage = 40, damageType = "holy", desc = "Holy power against undead/demons"},
    ["Venom Spit"] = {manaCost = 14, damage = 12, damageType = "poison", dot = 8, dotDuration = 4, desc = "Toxic spit with strong DoT"},
    -- Stamina-based skills (physical abilities)
    ["Heroic Strike"] = {staminaCost = 20, damage = 35, damageType = "physical", weaponType = "melee", desc = "Powerful strike using stamina"},
    ["Charge"] = {staminaCost = 25, damage = 28, damageType = "physical", stun = true, desc = "Rush enemy and stun"},
    ["Rapid Fire"] = {staminaCost = 30, damage = 20, damageType = "physical", hits = 4, weaponType = "bow", desc = "Fire 4 arrows rapidly"},
    ["Power Shot"] = {staminaCost = 15, damage = 40, damageType = "physical", weaponType = "crossbow", desc = "Heavy crossbow shot"},
    -- HP-based skills (blood magic)
    ["Blood Sacrifice"] = {hpCost = 20, damage = 50, damageType = "dark", desc = "Sacrifice HP for devastating dark damage"},
    ["Life Drain"] = {hpCost = 15, damage = 30, damageType = "dark", lifesteal = 100, desc = "Drain life, heal for damage dealt"},
    ["Blood Boil"] = {hpCost = 25, damage = 35, damageType = "fire", aoe = true, desc = "Boil blood of all enemies, costs HP"},
    ["Ritual of Pain"] = {hpCost = 30, buff = "attack", buffAmount = 10, duration = 3, desc = "Sacrifice HP for +10 ATK"},
}

-- Enemy types with Challenge Rating (CR) for encounter scaling
-- CR determines difficulty: lower CR = weaker, can appear in groups; higher CR = stronger, appear solo or few
Data.ENEMIES = {
    -- CR 0.25 (Very weak - can appear in large groups)
    {id = "rat", name = "Giant Rat", cr = 0.25, portrait = "R", hpMult = 0.4, atkMult = 0.5, defMult = 0.3, xpMult = 0.5, goldMult = 0.3, attacks = {"Bite", "Scratch"}},
    {id = "slime", name = "Slime", cr = 0.25, portrait = "S", hpMult = 0.5, atkMult = 0.4, defMult = 0.2, xpMult = 0.5, goldMult = 0.3, attacks = {"Bounce", "Absorb"}},
    {id = "bat", name = "Giant Bat", cr = 0.25, portrait = "B", hpMult = 0.3, atkMult = 0.5, defMult = 0.2, xpMult = 0.4, goldMult = 0.2, attacks = {"Bite", "Screech"}},

    -- CR 0.5 (Weak - appear in medium groups)
    {id = "goblin", name = "Goblin", cr = 0.5, portrait = "G", hpMult = 0.6, atkMult = 0.6, defMult = 0.4, xpMult = 0.7, goldMult = 0.5, attacks = {"Stab", "Throw Rock"},
     resistances = {}, attackType = "melee", attackRange = 1},
    {id = "skeleton", name = "Skeleton", cr = 0.5, portrait = "K", hpMult = 0.7, atkMult = 0.8, defMult = 0.5, xpMult = 1.0, goldMult = 0.7, attacks = {"Bone Strike", "Rattle"},
     resistances = {dark = 0.5, poison = 0.75, holy = -0.5}, attackType = "melee", attackRange = 1, damageType = "physical"},
    {id = "imp", name = "Imp", cr = 0.5, portrait = "I", hpMult = 0.5, atkMult = 0.7, defMult = 0.3, xpMult = 0.8, goldMult = 0.6, attacks = {"Claw", "Fire Spark", "Flee"},
     resistances = {fire = 0.5, holy = -0.5}, attackType = "magic", attackRange = 3, damageType = "fire"},

    -- CR 1 (Standard - small groups or solo)
    {id = "wolf", name = "Dire Wolf", cr = 1, portrait = "W", hpMult = 0.7, atkMult = 0.9, defMult = 0.4, xpMult = 0.9, goldMult = 0.6, attacks = {"Bite", "Pounce", "Howl"},
     resistances = {}, attackType = "melee", attackRange = 1, damageType = "physical"},
    {id = "spider", name = "Giant Spider", cr = 1, portrait = "X", hpMult = 0.6, atkMult = 0.7, defMult = 0.4, xpMult = 0.8, goldMult = 0.5, attacks = {"Bite", "Web Trap", "Poison"},
     resistances = {poison = 0.9}, attackType = "melee", attackRange = 1, damageType = "poison"},
    {id = "zombie", name = "Zombie", cr = 1, portrait = "Z", hpMult = 1.4, atkMult = 0.8, defMult = 0.6, xpMult = 1.2, goldMult = 0.8, attacks = {"Grab", "Bite", "Infect"},
     resistances = {dark = 0.6, poison = 0.8, holy = -0.6, fire = -0.3}, attackType = "melee", attackRange = 1, damageType = "physical"},
    {id = "boar", name = "Wild Boar", cr = 1, portrait = "B", hpMult = 0.8, atkMult = 0.8, defMult = 0.5, xpMult = 0.8, goldMult = 0.4, attacks = {"Gore", "Charge", "Trample"}},
    {id = "goblin_warrior", name = "Goblin Warrior", cr = 1, portrait = "G", hpMult = 0.7, atkMult = 0.75, defMult = 0.5, xpMult = 0.9, goldMult = 0.7, attacks = {"Slash", "Shield Bash", "Taunt"}},

    -- CR 2 (Moderate threat)
    {id = "bandit", name = "Bandit", cr = 2, portrait = "B", hpMult = 0.9, atkMult = 0.9, defMult = 0.7, xpMult = 1.2, goldMult = 1.5, attacks = {"Slash", "Ambush"}},
    {id = "orc", name = "Orc Warrior", cr = 2, portrait = "O", hpMult = 1.2, atkMult = 1.1, defMult = 0.9, xpMult = 1.5, goldMult = 1.2, attacks = {"Cleave", "Rage", "War Cry"}},
    {id = "ghost", name = "Wraith", cr = 2, portrait = "H", hpMult = 0.8, atkMult = 1.0, defMult = 0.3, xpMult = 1.4, goldMult = 1.0, attacks = {"Life Drain", "Haunt", "Phase"}},
    {id = "werewolf", name = "Werewolf", cr = 2, portrait = "W", hpMult = 1.1, atkMult = 1.0, defMult = 0.6, xpMult = 1.5, goldMult = 1.1, attacks = {"Claw", "Bite", "Howl", "Frenzy"}},
    {id = "skeleton_knight", name = "Skeleton Knight", cr = 2, portrait = "K", hpMult = 1.0, atkMult = 0.95, defMult = 0.8, xpMult = 1.3, goldMult = 1.0, attacks = {"Sword Strike", "Shield Block", "Charge"}},
    {id = "bear", name = "Cave Bear", cr = 2, portrait = "B", hpMult = 1.3, atkMult = 1.0, defMult = 0.7, xpMult = 1.3, goldMult = 0.8, attacks = {"Claw Swipe", "Bite", "Bear Hug"}},

    -- CR 3 (Dangerous)
    {id = "troll", name = "Troll", cr = 3, portrait = "T", hpMult = 1.8, atkMult = 1.2, defMult = 1.0, xpMult = 2.0, goldMult = 1.5, attacks = {"Smash", "Regenerate", "Throw Boulder"}},
    {id = "ogre", name = "Ogre", cr = 3, portrait = "O", hpMult = 2.0, atkMult = 1.3, defMult = 0.8, xpMult = 2.2, goldMult = 1.8, attacks = {"Club Smash", "Grab", "Throw"}},
    {id = "orc_warlord", name = "Orc Warlord", cr = 3, portrait = "O", hpMult = 1.4, atkMult = 1.25, defMult = 1.0, xpMult = 2.0, goldMult = 1.7, attacks = {"Battle Axe", "War Cry", "Rallying Shout"}},
    {id = "gargoyle", name = "Gargoyle", cr = 3, portrait = "G", hpMult = 1.5, atkMult = 1.1, defMult = 1.2, xpMult = 2.1, goldMult = 1.4, attacks = {"Stone Claw", "Dive", "Petrifying Gaze"}},
    {id = "minotaur", name = "Minotaur", cr = 3, portrait = "M", hpMult = 1.6, atkMult = 1.3, defMult = 0.9, xpMult = 2.3, goldMult = 1.6, attacks = {"Gore", "Charge", "Maze"}},

    -- CR 4 (Very dangerous)
    {id = "vampire", name = "Vampire", cr = 4, portrait = "V", hpMult = 1.3, atkMult = 1.4, defMult = 0.9, xpMult = 2.8, goldMult = 2.5, attacks = {"Blood Drain", "Charm", "Bat Swarm"},
     resistances = {dark = 0.75, physical = 0.3, holy = -0.8, fire = -0.4}, attackType = "melee", attackRange = 1, damageType = "dark"},
    {id = "demon", name = "Demon", cr = 4, portrait = "D", hpMult = 1.5, atkMult = 1.3, defMult = 1.0, xpMult = 2.5, goldMult = 2.0, attacks = {"Hellfire", "Dark Slash", "Terror"},
     resistances = {fire = 0.8, dark = 0.6, holy = -0.7, ice = -0.5}, attackType = "magic", attackRange = 4, damageType = "fire"},
    {id = "necromancer", name = "Necromancer", cr = 4, portrait = "N", hpMult = 1.0, atkMult = 1.5, defMult = 0.7, xpMult = 3.0, goldMult = 2.3, attacks = {"Death Bolt", "Raise Dead", "Life Drain"},
     resistances = {dark = 0.7, poison = 0.5, holy = -0.6}, attackType = "magic", attackRange = 5, damageType = "dark"},
    {id = "succubus", name = "Succubus", cr = 4, portrait = "S", hpMult = 1.1, atkMult = 1.35, defMult = 0.8, xpMult = 2.7, goldMult = 2.4, attacks = {"Kiss of Death", "Charm", "Shadow Strike"}},

    -- CR 5 (Elite)
    {id = "lich", name = "Lich", cr = 5, portrait = "L", hpMult = 1.4, atkMult = 1.6, defMult = 1.2, xpMult = 4.0, goldMult = 4.0, attacks = {"Death Bolt", "Summon Undead", "Soul Siphon"}},
    {id = "vampire_lord", name = "Vampire Lord", cr = 5, portrait = "V", hpMult = 1.6, atkMult = 1.55, defMult = 1.1, xpMult = 4.2, goldMult = 4.5, attacks = {"Blood Feast", "Dominate", "Nightfall", "Bat Swarm"}},
    {id = "ogre_mage", name = "Ogre Mage", cr = 5, portrait = "O", hpMult = 1.7, atkMult = 1.5, defMult = 1.0, xpMult = 3.8, goldMult = 3.5, attacks = {"Arcane Smash", "Fireball", "Invisibility"}},
    {id = "death_knight", name = "Death Knight", cr = 5, portrait = "K", hpMult = 1.8, atkMult = 1.5, defMult = 1.4, xpMult = 4.5, goldMult = 4.2, attacks = {"Unholy Strike", "Death Grip", "Necrotic Aura", "Raise Fallen"}},
    {id = "bone_colossus", name = "Bone Colossus", cr = 5, portrait = "B", hpMult = 2.2, atkMult = 1.4, defMult = 1.3, xpMult = 4.3, goldMult = 3.8, attacks = {"Bone Crush", "Skeletal Rain", "Reassemble"}},

    -- CR 6+ (Boss-tier)
    {id = "dragon", name = "Dragon", cr = 6, portrait = "D", hpMult = 2.5, atkMult = 1.8, defMult = 1.5, xpMult = 5.0, goldMult = 5.0, attacks = {"Fire Breath", "Tail Swipe", "Wing Gust", "Devour"},
     resistances = {fire = 0.95, physical = 0.4, ice = -0.5}, attackType = "magic", attackRange = 6, damageType = "fire"},
    {id = "demon_lord", name = "Demon Lord", cr = 7, portrait = "D", hpMult = 3.0, atkMult = 2.0, defMult = 1.6, xpMult = 6.0, goldMult = 6.0, attacks = {"Inferno", "Soul Rend", "Dominate", "Hellstorm"}},
    {id = "lich_king", name = "Lich King", cr = 8, portrait = "L", hpMult = 2.8, atkMult = 2.2, defMult = 1.8, xpMult = 7.0, goldMult = 7.0, attacks = {"Death Wave", "Army of Dead", "Soul Prison", "Apocalypse"}},
    {id = "dracolich", name = "Dracolich", cr = 8, portrait = "D", hpMult = 3.2, atkMult = 2.1, defMult = 1.9, xpMult = 7.5, goldMult = 7.5, attacks = {"Death Breath", "Soul Devour", "Bone Storm", "Undeath Aura"}},

    -- CR 9+ (World Threats - Lich Overlords)
    {id = "lich_overlord", name = "Lich Overlord", cr = 9, portrait = "L", hpMult = 3.5, atkMult = 2.5, defMult = 2.0, xpMult = 9.0, goldMult = 9.0, attacks = {"Annihilation", "Mass Resurrection", "Soul Harvest", "Blight Wave", "Command Undead"}},
    {id = "archlich", name = "Archlich", cr = 10, portrait = "L", hpMult = 4.0, atkMult = 2.8, defMult = 2.2, xpMult = 12.0, goldMult = 12.0, attacks = {"Finger of Death", "Legion of Doom", "Time Stop", "Reality Tear", "Eternal Darkness"}},

    -- VOID-TOUCHED ENEMIES (Found only in Calidar Wastes dungeons)
    -- These creatures were corrupted by the brief opening of the gate 500 years ago
    {id = "memory_echo", name = "Memory Echo", cr = 2, portrait = "?", hpMult = 0.6, atkMult = 0.8, defMult = 0.2, xpMult = 1.5, goldMult = 0.5,
        attacks = {"Forgotten Touch", "Memory Drain", "Fade"},
        description = "The psychic imprint of an elf who died during the ritual. It does not attack - it simply makes you forget.",
        calidarOnly = true},
    {id = "dust_wraith", name = "Dust Wraith", cr = 3, portrait = ".", hpMult = 0.5, atkMult = 1.2, defMult = 0.1, xpMult = 2.0, goldMult = 0.3,
        attacks = {"Choking Dust", "Sand Blind", "Withering Touch"},
        description = "The restless dead of the glass desert, endlessly wandering the vitrified wastes.",
        calidarOnly = true},
    {id = "glass_walker", name = "Glass Walker", cr = 3, portrait = "G", hpMult = 1.0, atkMult = 0.9, defMult = 1.4, xpMult = 2.2, goldMult = 1.0,
        attacks = {"Crystalline Strike", "Shard Burst", "Vitrifying Touch"},
        description = "An elf fused with the vitrified landscape. Part flesh, part glass, frozen in eternal pain.",
        calidarOnly = true},
    {id = "hollow_cultist", name = "Hollow Cultist", cr = 4, portrait = "C", hpMult = 0.9, atkMult = 1.3, defMult = 0.7, xpMult = 2.8, goldMult = 1.5,
        attacks = {"Dark Bolt", "Emptiness Prayer", "Hollow Chant", "Unmaking Word"},
        description = "A Vel'sharath cultist who survived the cataclysm. Something else looks out through their eyes now.",
        calidarOnly = true},
    {id = "scorched_specter", name = "Scorched Specter", cr = 5, portrait = " ", hpMult = 1.2, atkMult = 1.5, defMult = 0.3, xpMult = 4.0, goldMult = 0.0,
        attacks = {"Burning Grasp", "Ash Cloud", "Heat Mirage", "Cinder Scream"},
        description = "The ghost of an elf burned alive when the desert was born. Its rage has not cooled in five centuries.",
        calidarOnly = true},
    {id = "warden_shade", name = "Shade of the Last Warden", cr = 5, portrait = "W", hpMult = 1.5, atkMult = 1.4, defMult = 1.0, xpMult = 4.5, goldMult = 2.0,
        attacks = {"Spectral Blade", "Guardian's Sacrifice", "Memory of Valor", "Final Stand"},
        description = "One of the Last Wardens who charged into the rift to buy time. Their sacrifice echoes eternally.",
        calidarOnly = true},
    {id = "the_unfinished", name = "The Unfinished", cr = 7, portrait = "X", hpMult = 2.5, atkMult = 2.0, defMult = 1.5, xpMult = 7.0, goldMult = 5.0,
        attacks = {"Incomplete Form", "Half-Existence", "Paradox Strike", "Unmake Reality", "The Question"},
        description = "Something that was being summoned when Heaven's Atlas closed the gate. Neither here nor not-here. It hurts to look at.",
        calidarOnly = true, boss = true},
}

-- Encounter table: Number of monsters by Player Level vs Monster CR
-- Based on encounter scaling - format: {minCount, maxCount} or nil if too strong
Data.ENCOUNTER_TABLE = {
    -- PC Level 1
    [1] = {[0.25] = {3, 7}, [0.5] = {2, 4}, [1] = {1, 1}},
    -- PC Level 2
    [2] = {[0.25] = {4, 10}, [0.5] = {2, 4}, [1] = {1, 2}, [2] = {1, 1}},
    -- PC Level 3
    [3] = {[0.25] = {5, 12}, [0.5] = {3, 6}, [1] = {2, 4}, [2] = {1, 2}, [3] = {1, 1}},
    -- PC Level 4
    [4] = {[0.25] = {6, 14}, [0.5] = {4, 8}, [1] = {2, 5}, [2] = {1, 2}, [3] = {1, 1}},
    -- PC Level 5
    [5] = {[0.25] = {7, 16}, [0.5] = {5, 10}, [1] = {3, 6}, [2] = {2, 4}, [3] = {1, 2}, [4] = {1, 1}},
    -- PC Level 6
    [6] = {[0.25] = {8, 18}, [0.5] = {6, 12}, [1] = {3, 7}, [2] = {2, 5}, [3] = {1, 3}, [4] = {1, 2}, [5] = {1, 1}},
    -- PC Level 7
    [7] = {[0.25] = {9, 20}, [0.5] = {6, 14}, [1] = {4, 8}, [2] = {2, 5}, [3] = {2, 4}, [4] = {1, 2}, [5] = {1, 1}},
    -- PC Level 8
    [8] = {[0.25] = {10, 20}, [0.5] = {7, 15}, [1] = {4, 9}, [2] = {3, 6}, [3] = {2, 4}, [4] = {1, 3}, [5] = {1, 2}, [6] = {1, 1}},
    -- PC Level 9
    [9] = {[0.25] = {10, 20}, [0.5] = {8, 17}, [1] = {5, 10}, [2] = {3, 7}, [3] = {2, 5}, [4] = {2, 4}, [5] = {1, 2}, [6] = {1, 1}},
    -- PC Level 10
    [10] = {[0.25] = {10, 20}, [0.5] = {8, 18}, [1] = {5, 11}, [2] = {4, 8}, [3] = {3, 6}, [4] = {2, 4}, [5] = {1, 3}, [6] = {1, 2}, [7] = {1, 1}},
    -- PC Level 11-12
    [11] = {[0.25] = {10, 20}, [0.5] = {9, 20}, [1] = {6, 12}, [2] = {4, 9}, [3] = {3, 7}, [4] = {2, 5}, [5] = {2, 4}, [6] = {1, 2}, [7] = {1, 1}},
    [12] = {[0.25] = {10, 20}, [0.5] = {10, 20}, [1] = {6, 14}, [2] = {5, 10}, [3] = {4, 8}, [4] = {3, 6}, [5] = {2, 4}, [6] = {1, 3}, [7] = {1, 2}, [8] = {1, 1}},
    -- PC Level 13-15
    [13] = {[0.25] = {10, 20}, [0.5] = {10, 20}, [1] = {7, 15}, [2] = {5, 11}, [3] = {4, 9}, [4] = {3, 7}, [5] = {2, 5}, [6] = {2, 4}, [7] = {1, 2}, [8] = {1, 1}},
    [14] = {[0.25] = {10, 20}, [0.5] = {10, 20}, [1] = {7, 16}, [2] = {6, 12}, [3] = {5, 10}, [4] = {4, 8}, [5] = {3, 6}, [6] = {2, 4}, [7] = {1, 3}, [8] = {1, 2}},
    [15] = {[0.25] = {10, 20}, [0.5] = {10, 20}, [1] = {8, 18}, [2] = {6, 13}, [3] = {5, 11}, [4] = {4, 9}, [5] = {3, 7}, [6] = {2, 5}, [7] = {2, 4}, [8] = {1, 2}},
    -- PC Level 16-20
    [16] = {[0.25] = {10, 20}, [0.5] = {10, 20}, [1] = {8, 19}, [2] = {7, 14}, [3] = {6, 12}, [4] = {5, 10}, [5] = {4, 8}, [6] = {3, 6}, [7] = {2, 4}, [8] = {1, 3}},
    [17] = {[0.25] = {10, 20}, [0.5] = {10, 20}, [1] = {9, 20}, [2] = {7, 15}, [3] = {6, 13}, [4] = {5, 11}, [5] = {4, 9}, [6] = {3, 7}, [7] = {2, 5}, [8] = {2, 4}},
    [18] = {[0.25] = {10, 20}, [0.5] = {10, 20}, [1] = {9, 20}, [2] = {8, 16}, [3] = {7, 14}, [4] = {6, 12}, [5] = {5, 10}, [6] = {4, 8}, [7] = {3, 6}, [8] = {2, 4}},
    [19] = {[0.25] = {10, 20}, [0.5] = {10, 20}, [1] = {10, 20}, [2] = {8, 17}, [3] = {7, 15}, [4] = {6, 13}, [5] = {5, 11}, [6] = {4, 9}, [7] = {3, 7}, [8] = {2, 5}},
    [20] = {[0.25] = {10, 20}, [0.5] = {10, 20}, [1] = {10, 20}, [2] = {9, 18}, [3] = {8, 16}, [4] = {7, 14}, [5] = {6, 12}, [6] = {5, 10}, [7] = {4, 8}, [8] = {3, 6}},
}

-- Legacy tier lookup for backwards compatibility
Data.ENEMY_TIERS = {
    {minLevel = 1, maxLevel = 3, enemies = {}},
    {minLevel = 4, maxLevel = 7, enemies = {}},
    {minLevel = 8, maxLevel = 12, enemies = {}},
    {minLevel = 13, maxLevel = 99, enemies = {}},
}

-- Populate tiers from ENEMIES list
for _, enemy in ipairs(Data.ENEMIES) do
    if enemy.cr <= 0.5 then
        table.insert(Data.ENEMY_TIERS[1].enemies, enemy)
    elseif enemy.cr <= 2 then
        table.insert(Data.ENEMY_TIERS[2].enemies, enemy)
    elseif enemy.cr <= 4 then
        table.insert(Data.ENEMY_TIERS[3].enemies, enemy)
    else
        table.insert(Data.ENEMY_TIERS[4].enemies, enemy)
    end
end

-- === PARTY/COMPANION SYSTEM ===
-- Recruitable companions that fight alongside the player

Data.COMPANION_CLASSES = {
    {
        id = "soldier",
        name = "Soldier",
        desc = "Sturdy frontline fighter",
        baseHP = 80,
        baseAtk = 12,
        baseDef = 10,
        hireCost = 100,
        dailyWage = 10,
        portrait = "guard",
        color = {0.7, 0.5, 0.3},
        attacks = {"Sword Slash", "Shield Bash", "Defensive Stance"},
        skills = {"Taunt", "Guard Ally"},
    },
    {
        id = "archer",
        name = "Archer",
        desc = "Ranged damage dealer",
        baseHP = 50,
        baseAtk = 14,
        baseDef = 5,
        hireCost = 120,
        dailyWage = 12,
        portrait = "hunter",
        color = {0.5, 0.7, 0.4},
        attacks = {"Arrow Shot", "Power Shot", "Multi-Shot"},
        skills = {"Mark Target", "Evasion"},
    },
    {
        id = "battlemage",
        name = "Battle Mage",
        desc = "Combat spellcaster",
        baseHP = 45,
        baseAtk = 16,
        baseDef = 4,
        hireCost = 200,
        dailyWage = 20,
        portrait = "mage",
        color = {0.4, 0.4, 0.9},
        attacks = {"Fire Bolt", "Ice Lance", "Arcane Blast"},
        skills = {"Spell Shield", "Mana Burn"},
    },
    {
        id = "healer",
        name = "Healer",
        desc = "Keeps party alive",
        baseHP = 55,
        baseAtk = 6,
        baseDef = 6,
        hireCost = 180,
        dailyWage = 18,
        portrait = "healer",
        color = {0.3, 0.9, 0.5},
        attacks = {"Holy Smite", "Mend Wounds"},
        skills = {"Heal Ally", "Purify"},
        canHeal = true,
        healAmount = 15,  -- Base heal; scales with level in createCompanion() and calculateStats()
    },
    {
        id = "thief",
        name = "Thief",
        desc = "Quick striker with crits",
        baseHP = 40,
        baseAtk = 13,
        baseDef = 4,
        hireCost = 90,
        dailyWage = 8,
        portrait = "rogue",
        color = {0.5, 0.5, 0.5},
        attacks = {"Backstab", "Poison Dagger", "Quick Strike"},
        skills = {"Steal", "Smoke Bomb"},
        critBonus = 20,
    },
    {
        id = "berserker",
        name = "Berserker",
        desc = "High damage, low defense",
        baseHP = 90,
        baseAtk = 18,
        baseDef = 2,
        hireCost = 150,
        dailyWage = 15,
        portrait = "warrior",
        color = {0.9, 0.3, 0.2},
        attacks = {"Raging Strike", "Cleave", "Fury"},
        skills = {"Rage", "Reckless Attack"},
    },
}

-- Map companion class IDs to player class IDs so companions can reuse
-- existing skill trees and class talents.
Data.COMPANION_CLASS_MAP = {
    soldier   = "warrior",
    archer    = "ranger",
    battlemage = "mage",
    healer    = "cleric",
    thief     = "rogue",
    berserker = "warrior",
}

-- NPC first names
Data.NPC_FIRST_NAMES = {"Alaric", "Brynn", "Cedric", "Diana", "Eldric", "Fiona", "Gareth", "Helena", "Ivor", "Jasmine",
    "Kellan", "Luna", "Marcus", "Nadia", "Oswin", "Petra", "Quinn", "Rosa", "Stefan", "Thea",
    "Ulric", "Vera", "Willem", "Xena", "Yorick", "Zara", "Brom", "Cora", "Dax", "Elara"}

-- NPC professions with dialogue and quest potential
Data.NPC_PROFESSIONS = {
    {id = "blacksmith", title = "Blacksmith", icon = "[B]", color = {0.7, 0.4, 0.2},
        greetings = {"Need some steel work?", "My forge is always hot!", "Best weapons in the land!"},
        quests = true, questTypes = {"fetch", "deliver"}},
    {id = "innkeeper", title = "Innkeeper", icon = "[I]", color = {0.6, 0.5, 0.3},
        greetings = {"Welcome, weary traveler!", "The ale's fresh today!", "Need a room?"},
        quests = true, questTypes = {"kill", "talk"}},
    {id = "merchant", title = "Merchant", icon = "[M]", color = {0.8, 0.7, 0.2},
        greetings = {"Looking to trade?", "I have rare goods!", "Everything has a price..."},
        quests = true, questTypes = {"fetch", "deliver"}},
    {id = "healer", title = "Healer", icon = "[H]", color = {0.3, 0.8, 0.4},
        greetings = {"Blessings upon you.", "Let me tend your wounds.", "Health is true wealth."},
        quests = true, questTypes = {"fetch", "kill"}},
    {id = "guard", title = "Guard", icon = "[G]", color = {0.5, 0.5, 0.6},
        greetings = {"Keep the peace.", "No trouble, adventurer.", "Stay vigilant."},
        quests = true, questTypes = {"kill", "talk"}},
    {id = "farmer", title = "Farmer", icon = "[F]", color = {0.4, 0.6, 0.3},
        greetings = {"Hard day's work ahead.", "The crops need tending.", "Simple life, honest work."},
        quests = true, questTypes = {"kill", "fetch"}},
    {id = "miner", title = "Miner", icon = "[N]", color = {0.5, 0.4, 0.4},
        greetings = {"The mines run deep.", "Found some ore today.", "Watch out for cave-ins."},
        quests = true, questTypes = {"fetch", "kill"}},
    {id = "scholar", title = "Scholar", icon = "[S]", color = {0.4, 0.4, 0.7},
        greetings = {"Knowledge is power.", "I've been researching...", "Fascinating discoveries await!"},
        quests = true, questTypes = {"fetch", "talk"}},
    {id = "hunter", title = "Hunter", icon = "[U]", color = {0.5, 0.6, 0.4},
        greetings = {"The wild calls.", "Tracked a beast today.", "Nature provides."},
        quests = true, questTypes = {"kill", "fetch"}},
    {id = "elder", title = "Elder", icon = "[E]", color = {0.7, 0.6, 0.5},
        greetings = {"Ah, an adventurer!", "The old ways guide us.", "I have much wisdom to share."},
        quests = true, questTypes = {"kill", "talk", "fetch", "deliver"}, isElder = true},
}

-- Weather states and descriptions
Data.WEATHER_STATES = {"sunny", "cloudy", "rainy", "stormy", "foggy", "snowy", "windy", "pleasant"}

-- Weather effects - defines how each weather impacts gameplay
Data.WEATHER_EFFECTS = {
    sunny = {
        icon = "SUN", color = {1, 0.9, 0.3}, name = "Sunny",
        travelSpeed = 1.0, staminaDrain = 1.0, combatMod = 0,
        dangerous = false, needsShelter = false,
        desc = "Clear skies and warm sun.",
    },
    pleasant = {
        icon = "FAIR", color = {0.8, 0.9, 1}, name = "Pleasant",
        travelSpeed = 1.1, staminaDrain = 0.8, combatMod = 0,
        dangerous = false, needsShelter = false,
        desc = "Perfect weather for travel.",
    },
    cloudy = {
        icon = "CLD", color = {0.6, 0.6, 0.7}, name = "Cloudy",
        travelSpeed = 1.0, staminaDrain = 0.9, combatMod = 0,
        dangerous = false, needsShelter = false,
        desc = "Overcast but mild.",
    },
    rainy = {
        icon = "RAIN", color = {0.4, 0.5, 0.7}, name = "Rainy",
        travelSpeed = 0.8, staminaDrain = 1.3, combatMod = -5,
        dangerous = false, needsShelter = true,
        desc = "Steady rain. Consider shelter.",
    },
    stormy = {
        icon = "STRM", color = {0.3, 0.3, 0.5}, name = "Stormy",
        travelSpeed = 0.5, staminaDrain = 2.0, combatMod = -15,
        dangerous = true, needsShelter = true, damagePerHour = 5,
        desc = "Dangerous storm! Seek shelter!",
    },
    foggy = {
        icon = "FOG", color = {0.7, 0.7, 0.75}, name = "Foggy",
        travelSpeed = 0.7, staminaDrain = 1.0, combatMod = -10,
        dangerous = false, needsShelter = false, ambushChance = 0.3,
        desc = "Limited visibility. Careful of ambushes.",
    },
    snowy = {
        icon = "SNOW", color = {0.85, 0.9, 1}, name = "Snowy",
        travelSpeed = 0.6, staminaDrain = 1.5, combatMod = -5,
        dangerous = false, needsShelter = true,
        desc = "Snow is falling. Warmth advised.",
    },
    windy = {
        icon = "WIND", color = {0.6, 0.7, 0.8}, name = "Windy",
        travelSpeed = 0.9, staminaDrain = 1.2, combatMod = -5,
        dangerous = false, needsShelter = false,
        desc = "Strong winds slow travel.",
    },
}

-- Shelter types
Data.SHELTER_TYPES = {
    {id = "tent", name = "Set up Tent", cost = 0, quality = 0.6, time = 2,
        desc = "Basic shelter from the elements.", requiresItem = "tent"},
    {id = "makeshift", name = "Build Makeshift Shelter", cost = 0, quality = 0.4, time = 3,
        desc = "Gather branches and leaves for basic cover."},
    {id = "cave", name = "Find a Cave", cost = 0, quality = 0.8, time = 1,
        desc = "Search for natural shelter nearby.", chanceToFind = 0.4},
    {id = "inn", name = "Stay at Inn", cost = 15, quality = 1.0, time = 0,
        desc = "Comfortable rest with food and warmth.", townOnly = true},
}

-- Camp cooking recipes
Data.CAMP_FOODS = {
    {id = "simple_stew", name = "Simple Stew",
        ingredients = {{id = "meat", qty = 1}},
        effect = "heal", amount = 20, duration = 0,
        desc = "A hearty stew that restores 20 HP."},
    {id = "fish_dinner", name = "Grilled Fish",
        ingredients = {{id = "fish", qty = 1}},
        effect = "heal", amount = 15, duration = 0,
        desc = "Fresh grilled fish restores 15 HP."},
    {id = "travelers_bread", name = "Traveler's Bread",
        ingredients = {{id = "wheat", qty = 2}},
        effect = "stamina", amount = 10, duration = 0,
        desc = "Filling bread that reduces fatigue."},
    {id = "strength_meal", name = "Hunter's Feast",
        ingredients = {{id = "meat", qty = 2}, {id = "wheat", qty = 1}},
        effect = "buff_attack", amount = 3, duration = 5,
        desc = "+3 ATK for next 5 combats."},
    {id = "vitality_soup", name = "Vitality Soup",
        ingredients = {{id = "meat", qty = 1}, {id = "fish", qty = 1}},
        effect = "buff_maxhp", amount = 15, duration = 3,
        desc = "+15 Max HP for next 3 combats."},
    {id = "ale_boost", name = "Warming Ale",
        ingredients = {{id = "ale", qty = 1}},
        effect = "morale", amount = 20, duration = 0,
        desc = "Boosts party morale and conversation."},
}

-- Camp chat topics and dialogue
Data.CAMP_CHAT_TOPICS = {
    {id = "journey", name = "The Journey", icon = "MAP",
        lines = {
            player = {"How are you holding up?", "What do you think of our travels?", "Any thoughts on where we're headed?"},
            responses = {
                "The road has been long, but I'm glad for the company.",
                "I've seen worse conditions. We'll manage.",
                "Each step brings us closer to our goal.",
                "I miss a warm bed, but adventure calls.",
                "The wilderness has its own beauty, doesn't it?",
            }
        }
    },
    {id = "stories", name = "Share Stories", icon = "BOOK",
        lines = {
            player = {"Tell me about yourself.", "Got any good stories?", "What brings you to adventuring?"},
            responses = {
                "I once fought a dragon... well, a large lizard. But it felt like a dragon!",
                "My village was peaceful until bandits came. That's when I learned to fight.",
                "I've traveled many roads. Each one taught me something new.",
                "Before this? I was a farmer's kid dreaming of adventure.",
                "Some say I'm running from my past. Maybe they're right.",
            }
        }
    },
    {id = "tactics", name = "Discuss Tactics", icon = "SWORD",
        lines = {
            player = {"Any combat tips?", "How should we approach our next fight?", "What's your fighting style?"},
            responses = {
                "Always watch your enemy's footwork. It reveals their next move.",
                "A good defense is worth two attacks.",
                "Protect the weak, strike the strong. That's my motto.",
                "Patience wins more battles than raw strength.",
                "Know when to retreat. There's no shame in living to fight again.",
            }
        }
    },
    {id = "dreams", name = "Talk Dreams", icon = "DREAM",
        lines = {
            player = {"What are your hopes for the future?", "Any dreams you're chasing?", "What will you do when this is over?"},
            responses = {
                "I dream of a small cottage by a stream. Simple, peaceful.",
                "Fame and fortune! What else is there?",
                "I want to find my family. They're out there somewhere.",
                "Maybe I'll write about our adventures. Future generations should know!",
                "Honestly? I haven't thought that far ahead.",
            }
        }
    },
}

-- Ambush encounter data
Data.CAMP_AMBUSH_CHANCE = {
    base = 0.25,           -- 25% base chance without guard
    perHour = 0.05,        -- +5% per hour of sleep
    guardReduction = 1.0,  -- Guard removes all chance
    weatherMod = {
        stormy = -0.15,    -- Storms drive creatures away
        rainy = -0.05,     -- Rain reduces movement
        foggy = 0.10,      -- Fog lets enemies approach
        clear = 0.05,      -- Clear nights are dangerous
    },
    shelterMod = {
        tent = -0.05,
        makeshift = 0.05,
        cave = -0.10,
    }
}

Data.AMBUSH_ENEMIES = {
    {name = "Wolves", enemies = {"wolf", "wolf"}, minLevel = 1, maxLevel = 5,
        announce = "Wolves circle your camp, eyes gleaming in the darkness!"},
    {name = "Bandits", enemies = {"bandit", "bandit"}, minLevel = 2, maxLevel = 8,
        announce = "Bandits emerge from the shadows, weapons drawn!"},
    {name = "Goblins", enemies = {"goblin", "goblin", "goblin"}, minLevel = 1, maxLevel = 6,
        announce = "Goblins emerge from the tunnels--a resistance cell attacks! 'No one is illegal on stolen land!'"},
    {name = "Night Stalker", enemies = {"ghost"}, minLevel = 5, maxLevel = 12,
        announce = "A spectral creature materializes in your camp!"},
    {name = "Orc Scouts", enemies = {"orc", "orc"}, minLevel = 6, maxLevel = 15,
        announce = "Orc scouts stumble upon your camp and attack!"},
}

-- Lockpicking and Crime System
Data.LOCKPICK_CONFIG = {
    -- Minigame settings (timing-based: hit the sweet spot)
    sweetSpotSize = 0.12,     -- 12% of the bar is the sweet spot
    cursorSpeed = 2.5,        -- Speed of the moving cursor (cycles per second)
    maxAttempts = 3,          -- Max attempts before lock jams

    -- Detection chances (lower = safer)
    baseDetectionChance = 0.4,  -- 40% base chance to be noticed
    nightBonus = -0.25,         -- -25% at night (22:00 - 06:00)
    stealthBonus = -0.05,       -- -5% per stealth/dex point (future skill)

    -- Lock difficulties by building type
    difficulties = {
        noble_home1 = {name = "Complex Lock", sweetSpot = 0.08, attempts = 4, fine = 150},
        noble_home2 = {name = "Complex Lock", sweetSpot = 0.08, attempts = 4, fine = 150},
        home1 = {name = "Simple Lock", sweetSpot = 0.15, attempts = 3, fine = 50},
        home2 = {name = "Simple Lock", sweetSpot = 0.15, attempts = 3, fine = 50},
        home3 = {name = "Rusty Lock", sweetSpot = 0.18, attempts = 2, fine = 30},
        home4 = {name = "Simple Lock", sweetSpot = 0.15, attempts = 3, fine = 40},
        warehouse = {name = "Heavy Lock", sweetSpot = 0.10, attempts = 4, fine = 100},
        theater = {name = "Ornate Lock", sweetSpot = 0.12, attempts = 3, fine = 75},

        -- Town buildings
        butcher = {name = "Shop Lock", sweetSpot = 0.12, attempts = 3, fine = 60},
        bakery = {name = "Shop Lock", sweetSpot = 0.12, attempts = 3, fine = 55},
        tailor = {name = "Shop Lock", sweetSpot = 0.12, attempts = 3, fine = 65},
        jeweler = {name = "Jeweler's Lock", sweetSpot = 0.08, attempts = 4, fine = 120},
        shop = {name = "General Store Lock", sweetSpot = 0.10, attempts = 3, fine = 80},
        chapel = {name = "Sacred Lock", sweetSpot = 0.10, attempts = 3, fine = 40},
        stable = {name = "Barn Lock", sweetSpot = 0.15, attempts = 2, fine = 35},
        well = {name = "Rusty Lock", sweetSpot = 0.18, attempts = 2, fine = 15},
        shack = {name = "Broken Lock", sweetSpot = 0.20, attempts = 2, fine = 10},
        farmhouse = {name = "Simple Lock", sweetSpot = 0.15, attempts = 3, fine = 30},
    },
    defaultDifficulty = {name = "Standard Lock", sweetSpot = 0.12, attempts = 3, fine = 50},
}

Data.JAIL_CONFIG = {
    baseSentence = 8,           -- 8 hours base jail time
    fineMultiplier = 1.5,       -- Fine is 1.5x the building's base fine
    escapeChance = 0.15,        -- 15% base escape chance
    escapeConsequence = 24,     -- 24 hours added if caught escaping

    -- Loot tables for successfully breaking in
    lootTables = {
        noble_home1 = {gold = {80, 200}, items = {"gold_ring", "silver_necklace", "fine_wine"}, notes = {"noble_letter", "land_deed"}, chests = 2},
        noble_home2 = {gold = {60, 150}, items = {"gold_ring", "silk_cloth", "rare_book"}, notes = {"family_portrait", "old_journal"}, chests = 2},
        home1 = {gold = {10, 40}, items = {"bread", "cheese", "candle"}, notes = {"grocery_list"}, chests = 1},
        home2 = {gold = {15, 50}, items = {"meat", "ale", "rope"}, notes = {"work_schedule"}, chests = 1},
        home3 = {gold = {5, 20}, items = {"bread", "old_boots"}, notes = {"torn_page"}, chests = 1},
        home4 = {gold = {20, 60}, items = {"wheat", "eggs", "milk", "wool"}, notes = {"farmers_almanac"}, chests = 1},
        warehouse = {gold = {30, 100}, items = {"crate_goods", "rope", "lantern", "tools"}, notes = {"shipping_manifest", "inventory_list"}, chests = 3},
        theater = {gold = {25, 80}, items = {"costume", "mask", "script", "perfume"}, notes = {"playbill", "love_letter"}, chests = 2},

        -- Town buildings
        butcher = {gold = {25, 70}, items = {"raw_meat", "cleaver", "salt", "leather_scraps"}, notes = {"recipe_smoked_meat", "butcher_ledger"}, chests = 2},
        bakery = {gold = {20, 60}, items = {"flour", "sugar", "yeast", "rolling_pin"}, notes = {"recipe_bread", "recipe_pastry", "baker_notes"}, chests = 2},
        tailor = {gold = {30, 80}, items = {"silk_cloth", "thread", "needle", "dye"}, notes = {"pattern_robe", "pattern_cloak", "customer_orders"}, chests = 2},
        jeweler = {gold = {100, 300}, items = {"ruby", "sapphire", "silver_ore", "gold_ore"}, notes = {"gem_appraisal", "wealthy_client_list", "jeweler_secrets"}, chests = 3},
        shop = {gold = {40, 120}, items = {"rope", "torch", "rations", "waterskin", "lantern"}, notes = {"shopkeeper_ledger", "supplier_contact"}, chests = 2},
        chapel = {gold = {15, 50}, items = {"holy_water", "blessed_candle", "prayer_beads"}, notes = {"scripture_fragment", "sermon_notes", "confession_record"}, chests = 1},
        stable = {gold = {20, 50}, items = {"horseshoe", "saddle", "hay", "grooming_brush"}, notes = {"horse_care_guide", "breeding_records"}, chests = 1},
        well = {gold = {5, 15}, items = {"bucket", "rope"}, notes = {"warning_note"}, chests = 0},
        shack = {gold = {3, 12}, items = {"old_tools", "scrap_metal"}, notes = {"mysterious_map_fragment"}, chests = 1},
        farmhouse = {gold = {15, 45}, items = {"wheat", "vegetables", "milk", "eggs"}, notes = {"planting_calendar", "harvest_log"}, chests = 1},
    },
    defaultLoot = {gold = {10, 30}, items = {"bread", "candle"}, notes = {"torn_page"}, chests = 1},
}

Data.TILE_TYPES = {
    {id = "grass", name = "Grassland", icon = ".", color = {0.3, 0.5, 0.3}, passable = true, encounterRate = 0.2},
    {id = "forest", name = "Forest", icon = "T", color = {0.2, 0.4, 0.2}, passable = true, encounterRate = 0.35},
    {id = "mountain", name = "Mountain", icon = "^", color = {0.5, 0.5, 0.5}, passable = true, encounterRate = 0.3},
    {id = "water", name = "Water", icon = "~", color = {0.2, 0.4, 0.7}, passable = false, encounterRate = 0, isWater = true},
    {id = "ice", name = "Frozen Wasteland", icon = "*", color = {0.7, 0.85, 0.95}, passable = true, encounterRate = 0.15, isFrozen = true},
    {id = "swamp", name = "Swamp", icon = "%", color = {0.3, 0.4, 0.3}, passable = true, encounterRate = 0.4},
    {id = "desert", name = "Desert", icon = ":", color = {0.8, 0.7, 0.4}, passable = true, encounterRate = 0.25},
    {id = "town", name = "Town", icon = "#", color = {0.6, 0.5, 0.4}, passable = true, encounterRate = 0},
    {id = "dungeon", name = "Dungeon", icon = "D", color = {0.4, 0.2, 0.2}, passable = true, encounterRate = 0.5},
    {id = "ruins", name = "Ruins", icon = "R", color = {0.5, 0.4, 0.3}, passable = true, encounterRate = 0.4},
    {id = "corrupted", name = "Corrupted Land", icon = "X", color = {0.3, 0.15, 0.3}, passable = true, encounterRate = 0.35, undeadOnly = true},

    -- EXPANDED DESERT BIOMES & GEOLOGICAL FEATURES
    {id = "sand_dunes", name = "Sand Dunes", icon = "=", color = {0.85, 0.75, 0.45}, passable = true, encounterRate = 0.20},
    {id = "glass_desert", name = "Glass Wastes", icon = "o", color = {0.7, 0.85, 0.9}, passable = true, encounterRate = 0.15, isGlassDesert = true},
    {id = "salt_flats", name = "Salt Flats", icon = "-", color = {0.95, 0.95, 0.95}, passable = true, encounterRate = 0.10},
    {id = "desert_canyon", name = "Desert Canyon", icon = "=", color = {0.7, 0.5, 0.3}, passable = true, encounterRate = 0.35},
    {id = "desert_oasis", name = "Oasis", icon = "O", color = {0.3, 0.6, 0.5}, passable = true, encounterRate = 0.05, isOasis = true},
    {id = "desert_cave", name = "Desert Cave", icon = "c", color = {0.6, 0.5, 0.3}, passable = true, encounterRate = 0.30},
    {id = "obsidian_field", name = "Obsidian Field", icon = "#", color = {0.2, 0.15, 0.25}, passable = true, encounterRate = 0.25, isObsidian = true},
    {id = "crystal_formations", name = "Crystal Formations", icon = "*", color = {0.8, 0.5, 0.9}, passable = true, encounterRate = 0.20, hasCrystals = true},
    {id = "badlands", name = "Badlands", icon = "~", color = {0.6, 0.4, 0.25}, passable = true, encounterRate = 0.30},
    {id = "stone_pillars", name = "Stone Pillars", icon = "|", color = {0.65, 0.55, 0.45}, passable = true, encounterRate = 0.25},
    {id = "desert_settlement", name = "Desert Settlement", icon = "S", color = {0.7, 0.6, 0.4}, passable = true, encounterRate = 0, isDesertSettlement = true},

    -- EXPANDED WATER BIOMES
    {id = "shallow_water", name = "Shallow Water", icon = "~", color = {0.3, 0.5, 0.8}, passable = false, encounterRate = 0.15, isWater = true, seaOnly = true},
    {id = "deep_ocean", name = "Deep Ocean", icon = "=", color = {0.1, 0.2, 0.5}, passable = false, encounterRate = 0.30, isWater = true, seaOnly = true},
    {id = "coastal", name = "Coastal Waters", icon = "~", color = {0.3, 0.6, 0.8}, passable = false, encounterRate = 0.10, isWater = true, seaOnly = true},
    {id = "reef", name = "Coral Reef", icon = "8", color = {0.4, 0.7, 0.6}, passable = false, encounterRate = 0.20, isWater = true, seaOnly = true, isReef = true},
    {id = "river", name = "River", icon = "~", color = {0.25, 0.45, 0.75}, passable = false, encounterRate = 0.10, isWater = true, isRiver = true},
    {id = "lake", name = "Lake", icon = "~", color = {0.2, 0.45, 0.7}, passable = false, encounterRate = 0.10, isWater = true, isLake = true},
    {id = "whirlpool", name = "Whirlpool", icon = "@", color = {0.15, 0.3, 0.6}, passable = false, encounterRate = 0.50, isWater = true, seaOnly = true, isWhirlpool = true},
    {id = "shipwreck", name = "Shipwreck", icon = "W", color = {0.4, 0.35, 0.3}, passable = false, encounterRate = 0.40, isWater = true, seaOnly = true, isShipwreck = true},
    {id = "ocean_cave", name = "Sea Cave", icon = "O", color = {0.2, 0.35, 0.5}, passable = false, encounterRate = 0, isWater = true, seaOnly = true, isOceanCave = true},
}

-- Dungeon tile types for procedural dungeon generation
Data.DUNGEON_TILE_TYPES = {
    {id = "wall", name = "Wall", icon = "#", color = {0.25, 0.2, 0.25}, passable = false},
    {id = "floor", name = "Floor", icon = ".", color = {0.35, 0.3, 0.35}, passable = true},
    {id = "corridor", name = "Corridor", icon = ".", color = {0.3, 0.28, 0.32}, passable = true},
    {id = "door", name = "Door", icon = "+", color = {0.6, 0.45, 0.25}, passable = true},
    {id = "stairs_down", name = "Stairs Down", icon = ">", color = {0.5, 0.7, 0.9}, passable = true},
    {id = "stairs_up", name = "Stairs Up", icon = "<", color = {0.7, 0.9, 0.5}, passable = true},
    {id = "entrance", name = "Entrance", icon = "^", color = {0.4, 0.8, 0.4}, passable = true},
    {id = "exit", name = "Exit", icon = "E", color = {0.9, 0.8, 0.3}, passable = true},
    {id = "chest", name = "Treasure", icon = "$", color = {0.9, 0.7, 0.2}, passable = true},
    {id = "trap", name = "Trap", icon = "x", color = {0.6, 0.3, 0.3}, passable = true, hidden = true},
    {id = "hollow_portal", name = "Hollow Earth Portal", icon = "@", color = {0.6, 0.8, 1.0}, passable = true},
    -- Prison escape tile types
    {id = "prison_cell_start", name = "Your Cell", icon = "P", color = {0.5, 0.3, 0.3}, passable = true},
    {id = "escape_exit", name = "Escape Route", icon = "!", color = {0.2, 0.9, 0.2}, passable = true},
}

-- Dungeon types with different themes
Data.DUNGEON_TYPES = {
    -- GENERIC DUNGEONS (appear in grasslands/plains)
    {id = "dungeon", name = "Dungeon", weight = 25, color = {0.4, 0.3, 0.35}, biomes = {"grass"}},
    {id = "cave", name = "Cave", weight = 22, color = {0.35, 0.35, 0.4}, biomes = {"grass"}},
    {id = "mine", name = "Mine", weight = 18, color = {0.4, 0.35, 0.3}, biomes = {"grass"}},
    {id = "vampire_den", name = "Vampire Den", weight = 12, color = {0.5, 0.15, 0.2}, biomes = {"grass"}},
    {id = "crypt", name = "Crypt", weight = 10, color = {0.3, 0.3, 0.35}, biomes = {"grass"}},
    {id = "bandit_fort", name = "Bandit Fort", weight = 10, color = {0.45, 0.4, 0.35}, biomes = {"grass"}},
    {id = "mercenary_stronghold", name = "Mercenary Keep", weight = 7, color = {0.5, 0.45, 0.4}, biomes = {"grass"}},  -- Boss-tier
    {id = "dark_castle", name = "Dark Castle", weight = 5, color = {0.3, 0.25, 0.3}, biomes = {"grass"}},  -- Very rare
    {id = "lich_lair", name = "Lich Lair", weight = 1, color = {0.25, 0.1, 0.35}, biomes = {"grass"}},  -- Legendary rare world threat

    -- DESERT-SPECIFIC DUNGEONS
    {id = "desert_tomb", name = "Desert Tomb", weight = 28, color = {0.7, 0.6, 0.3}, biomes = {"desert"}},
    {id = "desert_temple", name = "Desert Temple", weight = 22, color = {0.6, 0.65, 0.75}, biomes = {"desert"}},
    {id = "sandstone_crypt", name = "Sandstone Crypt", weight = 18, color = {0.75, 0.65, 0.4}, biomes = {"desert"}},
    {id = "bandit_citadel", name = "Bandit Citadel", weight = 12, color = {0.65, 0.55, 0.35}, biomes = {"desert"}},
    {id = "scorpion_temple", name = "Scorpion Temple", weight = 10, color = {0.6, 0.5, 0.25}, biomes = {"desert"}},  -- Boss-tier
    {id = "sand_wyrm_den", name = "Sand Wyrm Den", weight = 6, color = {0.7, 0.65, 0.45}, biomes = {"desert"}},  -- Very rare
    {id = "pharaoh_tomb", name = "Pharaoh's Tomb", weight = 4, color = {0.8, 0.7, 0.3}, biomes = {"desert"}},  -- Legendary rare

    -- WATER-SPECIFIC DUNGEONS
    {id = "ocean_cave", name = "Sea Cave", weight = 25, color = {0.2, 0.4, 0.5}, biomes = {"water"}},
    {id = "sunken_ship", name = "Sunken Ship", weight = 22, color = {0.35, 0.3, 0.25}, biomes = {"water"}},
    {id = "underwater_ruins", name = "Underwater Ruins", weight = 18, color = {0.3, 0.5, 0.45}, biomes = {"water"}},
    {id = "sea_fortress", name = "Sea Fortress", weight = 12, color = {0.4, 0.4, 0.5}, biomes = {"water"}},
    {id = "pirate_stronghold", name = "Pirate Stronghold", weight = 10, color = {0.4, 0.35, 0.3}, biomes = {"water"}},
    {id = "merfolk_palace", name = "Merfolk Palace", weight = 8, color = {0.3, 0.55, 0.6}, biomes = {"water"}},  -- Boss-tier
    {id = "leviathan_trench", name = "Leviathan Trench", weight = 5, color = {0.15, 0.25, 0.35}, biomes = {"water"}},  -- Very rare
    {id = "kraken_lair", name = "Kraken's Lair", weight = 2, color = {0.15, 0.2, 0.4}, biomes = {"water"}},  -- Legendary rare

    -- FOREST-SPECIFIC DUNGEONS
    {id = "overgrown_ruins", name = "Overgrown Ruins", weight = 25, color = {0.3, 0.5, 0.3}, biomes = {"forest"}},
    {id = "druid_grove", name = "Corrupted Grove", weight = 20, color = {0.4, 0.45, 0.25}, biomes = {"forest"}},
    {id = "treant_hollow", name = "Ancient Hollow", weight = 18, color = {0.35, 0.4, 0.25}, biomes = {"forest"}},
    {id = "fairy_barrow", name = "Dark Barrow", weight = 15, color = {0.45, 0.35, 0.5}, biomes = {"forest"}},
    {id = "bandit_camp", name = "Bandit Camp", weight = 12, color = {0.5, 0.4, 0.3}, biomes = {"forest"}},
    {id = "outlaw_fort", name = "Outlaw Fortress", weight = 8, color = {0.45, 0.35, 0.25}, biomes = {"forest"}},  -- Boss-tier
    {id = "wild_hunt_lodge", name = "Wild Hunt Lodge", weight = 5, color = {0.4, 0.5, 0.35}, biomes = {"forest"}},  -- Very rare

    -- SWAMP-SPECIFIC DUNGEONS
    {id = "bog_ruins", name = "Bog Ruins", weight = 25, color = {0.35, 0.4, 0.3}, biomes = {"swamp"}},
    {id = "witch_hut", name = "Witch's Hovel", weight = 20, color = {0.4, 0.35, 0.45}, biomes = {"swamp"}},
    {id = "troll_den", name = "Troll Den", weight = 18, color = {0.4, 0.45, 0.35}, biomes = {"swamp"}},
    {id = "poison_grotto", name = "Poison Grotto", weight = 15, color = {0.3, 0.5, 0.35}, biomes = {"swamp"}},
    {id = "witch_coven", name = "Witch Coven", weight = 12, color = {0.45, 0.25, 0.5}, biomes = {"swamp"}},  -- Multi-witch stronghold
    {id = "hag_fortress", name = "Hag Fortress", weight = 8, color = {0.35, 0.3, 0.4}, biomes = {"swamp"}},  -- Rare, boss-tier
    {id = "necro_swamp", name = "Necromancer's Marsh", weight = 5, color = {0.3, 0.35, 0.25}, biomes = {"swamp"}},  -- Very rare

    -- MOUNTAIN-SPECIFIC DUNGEONS
    {id = "mountain_cave", name = "Mountain Cave", weight = 25, color = {0.4, 0.4, 0.45}, biomes = {"mountain"}},
    {id = "dwarven_mine", name = "Abandoned Mine", weight = 20, color = {0.45, 0.4, 0.35}, biomes = {"mountain"}},
    {id = "frost_cavern", name = "Frost Cavern", weight = 18, color = {0.6, 0.7, 0.8}, biomes = {"mountain"}},
    {id = "dragon_lair", name = "Dragon's Roost", weight = 10, color = {0.5, 0.3, 0.25}, biomes = {"mountain"}},  -- Boss-tier
    {id = "giant_keep", name = "Giant's Keep", weight = 8, color = {0.5, 0.5, 0.55}, biomes = {"mountain"}},  -- Boss-tier
    {id = "dwarf_fortress", name = "Ruined Stronghold", weight = 6, color = {0.4, 0.35, 0.3}, biomes = {"mountain"}},  -- Very rare
    {id = "wyvern_nest", name = "Wyvern Nest", weight = 5, color = {0.55, 0.45, 0.35}, biomes = {"mountain"}},  -- Very rare
}

-- Dungeon enemy types by floor depth
Data.DUNGEON_ENEMIES = {
    shallow = { -- Floors 1-2
        {id = "rat", name = "Dungeon Rat", hp = 15, atk = 4, def = 1, xp = 8, gold = 3},
        {id = "cave_spider", name = "Cave Spider", hp = 20, atk = 6, def = 2, xp = 12, gold = 5},
        {id = "goblin", name = "Goblin Scout", hp = 25, atk = 8, def = 3, xp = 15, gold = 8},
        {id = "bat", name = "Giant Bat", hp = 12, atk = 5, def = 1, xp = 6, gold = 2},
        {id = "slime", name = "Dungeon Slime", hp = 18, atk = 3, def = 2, xp = 10, gold = 4},
    },
    mid = { -- Floors 3-4
        {id = "skeleton", name = "Skeleton Warrior", hp = 40, atk = 12, def = 6, xp = 25, gold = 15},
        {id = "orc_warrior", name = "Orc Brute", hp = 55, atk = 15, def = 8, xp = 35, gold = 20},
        {id = "zombie", name = "Shambling Corpse", hp = 45, atk = 10, def = 4, xp = 20, gold = 12},
        {id = "goblin_warrior", name = "Goblin Warrior", hp = 35, atk = 11, def = 5, xp = 22, gold = 14},
        {id = "scorpion", name = "Giant Scorpion", hp = 38, atk = 14, def = 7, xp = 28, gold = 16},
    },
    deep = { -- Floors 5+
        {id = "troll", name = "Cave Troll", hp = 80, atk = 20, def = 12, xp = 60, gold = 40},
        {id = "wraith", name = "Wraith", hp = 50, atk = 18, def = 5, xp = 45, gold = 30},
        {id = "ogre", name = "Dungeon Ogre", hp = 100, atk = 25, def = 15, xp = 80, gold = 50},
        {id = "orc_warlord", name = "Orc Warlord", hp = 75, atk = 22, def = 10, xp = 55, gold = 35},
        {id = "minotaur", name = "Minotaur", hp = 90, atk = 24, def = 14, xp = 70, gold = 45},
    },
    boss = { -- Final floor guardians
        {id = "dragon", name = "Dungeon Drake", hp = 150, atk = 30, def = 18, xp = 150, gold = 100},
        {id = "lich_king", name = "Lich Lord", hp = 120, atk = 35, def = 12, xp = 180, gold = 120},
        {id = "demon", name = "Pit Fiend", hp = 140, atk = 32, def = 16, xp = 160, gold = 110},
        {id = "ogre_mage", name = "Ogre Mage", hp = 110, atk = 28, def = 14, xp = 140, gold = 95},
    }
}

-- Vampire Den enemies - mostly undead with vampires
Data.VAMPIRE_DEN_ENEMIES = {
    shallow = {
        {id = "bat", name = "Blood Bat", hp = 14, atk = 5, def = 1, xp = 8, gold = 3},
        {id = "zombie", name = "Risen Thrall", hp = 22, atk = 7, def = 2, xp = 12, gold = 5},
        {id = "skeleton", name = "Skeletal Guard", hp = 28, atk = 9, def = 4, xp = 15, gold = 8},
        {id = "rat", name = "Plague Rat", hp = 10, atk = 4, def = 1, xp = 6, gold = 2},
        {id = "ghost", name = "Lost Soul", hp = 18, atk = 8, def = 2, xp = 14, gold = 6},
    },
    mid = {
        {id = "skeleton_knight", name = "Death Knight", hp = 50, atk = 16, def = 10, xp = 35, gold = 22},
        {id = "zombie_brute", name = "Ghoul", hp = 55, atk = 14, def = 6, xp = 30, gold = 18},
        {id = "vampire_spawn", name = "Vampire Spawn", hp = 45, atk = 18, def = 8, xp = 40, gold = 25},
        {id = "ghost_knight", name = "Spectral Knight", hp = 42, atk = 15, def = 5, xp = 32, gold = 20},
        {id = "skeleton_mage", name = "Bone Mage", hp = 35, atk = 20, def = 4, xp = 38, gold = 24},
    },
    deep = {
        {id = "vampire", name = "Vampire", hp = 70, atk = 24, def = 12, xp = 65, gold = 45},
        {id = "wraith", name = "Banshee", hp = 55, atk = 22, def = 6, xp = 55, gold = 35},
        {id = "skeleton_king", name = "Skeleton King", hp = 85, atk = 26, def = 14, xp = 75, gold = 50},
        {id = "undead_dragon", name = "Bone Dragon", hp = 100, atk = 28, def = 16, xp = 90, gold = 60},
        {id = "necromancer", name = "Necromancer", hp = 60, atk = 25, def = 8, xp = 70, gold = 55},
    },
    boss = {
        {id = "vampire_lord", name = "Vampire Lord", hp = 180, atk = 38, def = 20, xp = 200, gold = 150},
        {id = "lich_king", name = "Ancient Lich", hp = 150, atk = 42, def = 15, xp = 220, gold = 160},
        {id = "death_demon", name = "Death Knight Champion", hp = 160, atk = 35, def = 22, xp = 190, gold = 140},
    }
}

-- Cave enemies - more beasts and natural creatures
Data.CAVE_ENEMIES = {
    shallow = {
        {id = "bat", name = "Cave Bat", hp = 12, atk = 4, def = 1, xp = 6, gold = 2},
        {id = "cave_spider", name = "Cave Spider", hp = 18, atk = 6, def = 2, xp = 10, gold = 4},
        {id = "rat", name = "Giant Rat", hp = 14, atk = 5, def = 1, xp = 8, gold = 3},
        {id = "slime", name = "Cave Slime", hp = 20, atk = 3, def = 3, xp = 9, gold = 5},
    },
    mid = {
        {id = "bear", name = "Cave Bear", hp = 60, atk = 14, def = 8, xp = 30, gold = 18},
        {id = "werewolf", name = "Werewolf", hp = 50, atk = 16, def = 6, xp = 35, gold = 22},
        {id = "scorpion", name = "Giant Scorpion", hp = 40, atk = 15, def = 10, xp = 28, gold = 16},
        {id = "ratman", name = "Ratman", hp = 35, atk = 12, def = 5, xp = 25, gold = 14},
    },
    deep = {
        {id = "troll", name = "Cave Troll", hp = 85, atk = 22, def = 14, xp = 65, gold = 42},
        {id = "yeti", name = "Yeti", hp = 95, atk = 24, def = 16, xp = 75, gold = 48},
        {id = "minotaur", name = "Minotaur", hp = 90, atk = 26, def = 12, xp = 70, gold = 45},
        {id = "gorgon", name = "Gorgon", hp = 70, atk = 28, def = 10, xp = 80, gold = 55},
    },
    boss = {
        {id = "dragon", name = "Cave Dragon", hp = 160, atk = 32, def = 20, xp = 160, gold = 110},
        {id = "manticore", name = "Manticore", hp = 130, atk = 35, def = 16, xp = 140, gold = 100},
        {id = "cyclops", name = "Cyclops", hp = 180, atk = 30, def = 22, xp = 170, gold = 120},
    }
}

-- Mine enemies - goblin resistance cells, dwarves gone mad, and underground creatures
Data.MINE_ENEMIES = {
    shallow = {
        {id = "goblin", name = "Goblin Miner", hp = 20, atk = 6, def = 2, xp = 10, gold = 8},
        {id = "rat", name = "Mine Rat", hp = 12, atk = 4, def = 1, xp = 6, gold = 3},
        {id = "cave_spider", name = "Tunnel Spider", hp = 18, atk = 7, def = 2, xp = 11, gold = 5},
        {id = "bat", name = "Mine Bat", hp = 10, atk = 3, def = 1, xp = 5, gold = 2},
    },
    mid = {
        {id = "goblin_warrior", name = "Goblin Foreman", hp = 38, atk = 13, def = 6, xp = 28, gold = 18},
        {id = "mad_dwarf", name = "Crazed Miner", hp = 45, atk = 15, def = 8, xp = 32, gold = 20},
        {id = "stone_golem", name = "Stone Golem", hp = 65, atk = 12, def = 15, xp = 35, gold = 22},
        {id = "gnome", name = "Tunnel Gnome", hp = 30, atk = 14, def = 5, xp = 26, gold = 16},
    },
    deep = {
        {id = "goblin_chief", name = "Goblin Chief", hp = 60, atk = 20, def = 10, xp = 55, gold = 38},
        {id = "fire_elemental", name = "Magma Elemental", hp = 70, atk = 25, def = 8, xp = 65, gold = 45},
        {id = "troll", name = "Deep Troll", hp = 90, atk = 22, def = 14, xp = 70, gold = 48},
        {id = "ogre", name = "Tunnel Ogre", hp = 100, atk = 24, def = 16, xp = 75, gold = 52},
    },
    boss = {
        {id = "stone_golem", name = "Golem Overlord", hp = 200, atk = 28, def = 25, xp = 180, gold = 130},
        {id = "goblin_chief", name = "Goblin King", hp = 120, atk = 32, def = 18, xp = 160, gold = 140},
        {id = "titan", name = "Earth Titan", hp = 220, atk = 35, def = 22, xp = 200, gold = 150},
    }
}

-- Crypt enemies - mostly undead
Data.CRYPT_ENEMIES = {
    shallow = {
        {id = "skeleton", name = "Crypt Skeleton", hp = 22, atk = 8, def = 3, xp = 12, gold = 6},
        {id = "zombie", name = "Shambling Dead", hp = 28, atk = 6, def = 4, xp = 14, gold = 7},
        {id = "ghost", name = "Restless Spirit", hp = 16, atk = 9, def = 2, xp = 15, gold = 8},
        {id = "rat", name = "Corpse Rat", hp = 10, atk = 4, def = 1, xp = 6, gold = 3},
    },
    mid = {
        {id = "skeleton_knight", name = "Tomb Guardian", hp = 48, atk = 15, def = 10, xp = 32, gold = 20},
        {id = "zombie_brute", name = "Wight", hp = 52, atk = 14, def = 7, xp = 30, gold = 18},
        {id = "skeleton_mage", name = "Lich Acolyte", hp = 38, atk = 18, def = 5, xp = 35, gold = 24},
        {id = "ghost_knight", name = "Phantom Warrior", hp = 40, atk = 16, def = 4, xp = 33, gold = 22},
    },
    deep = {
        {id = "wraith", name = "Greater Wraith", hp = 58, atk = 24, def = 6, xp = 60, gold = 40},
        {id = "necromancer", name = "Necromancer", hp = 55, atk = 26, def = 7, xp = 65, gold = 48},
        {id = "skeleton_king", name = "Crypt Lord", hp = 80, atk = 22, def = 14, xp = 70, gold = 50},
        {id = "bone_snake", name = "Bone Serpent", hp = 65, atk = 20, def = 10, xp = 55, gold = 38},
    },
    boss = {
        {id = "lich_king", name = "Lich King", hp = 140, atk = 40, def = 14, xp = 200, gold = 150},
        {id = "undead_dragon", name = "Dracolich", hp = 180, atk = 36, def = 20, xp = 220, gold = 170},
        {id = "death_demon", name = "Dread Lord", hp = 150, atk = 38, def = 18, xp = 190, gold = 145},
    }
}

-- Lich Lair enemies - massive undead army, corrupted beings
Data.LICH_LAIR_ENEMIES = {
    shallow = {
        {id = "shambling_corpse", name = "Shambling Corpse", hp = 18, atk = 5, def = 2, xp = 8, gold = 3},
        {id = "skeletal_warrior", name = "Skeletal Warrior", hp = 24, atk = 8, def = 4, xp = 12, gold = 6},
        {id = "rotting_zombie", name = "Rotting Zombie", hp = 30, atk = 7, def = 3, xp = 11, gold = 5},
        {id = "ghoul", name = "Ghoul", hp = 26, atk = 10, def = 3, xp = 14, gold = 8},
        {id = "corrupted_peasant", name = "Corrupted Peasant", hp = 20, atk = 6, def = 2, xp = 9, gold = 4},
        {id = "soul_wisp", name = "Soul Wisp", hp = 12, atk = 12, def = 1, xp = 13, gold = 7},
    },
    mid = {
        {id = "death_knight_squire", name = "Death Knight Squire", hp = 55, atk = 18, def = 12, xp = 38, gold = 25},
        {id = "skeleton_mage", name = "Skeleton Mage", hp = 40, atk = 22, def = 6, xp = 42, gold = 30},
        {id = "wight_captain", name = "Wight Captain", hp = 60, atk = 16, def = 10, xp = 36, gold = 22},
        {id = "bone_golem", name = "Bone Golem", hp = 75, atk = 14, def = 14, xp = 40, gold = 28},
        {id = "specter", name = "Specter", hp = 45, atk = 20, def = 4, xp = 44, gold = 32},
        {id = "plague_bearer", name = "Plague Bearer", hp = 50, atk = 15, def = 8, xp = 35, gold = 20},
        {id = "banshee", name = "Banshee", hp = 42, atk = 24, def = 5, xp = 48, gold = 35},
    },
    deep = {
        {id = "death_knight", name = "Death Knight", hp = 95, atk = 28, def = 18, xp = 75, gold = 55},
        {id = "lich_acolyte", name = "Lich Acolyte", hp = 70, atk = 32, def = 10, xp = 80, gold = 60},
        {id = "bone_colossus", name = "Bone Colossus", hp = 120, atk = 24, def = 20, xp = 85, gold = 65},
        {id = "wraith_lord", name = "Wraith Lord", hp = 80, atk = 30, def = 8, xp = 78, gold = 58},
        {id = "abomination", name = "Flesh Abomination", hp = 140, atk = 26, def = 16, xp = 90, gold = 70},
        {id = "soul_reaver", name = "Soul Reaver", hp = 85, atk = 34, def = 12, xp = 95, gold = 75},
    },
    elite = {
        {id = "death_knight_champion", name = "Death Knight Champion", hp = 160, atk = 38, def = 22, xp = 140, gold = 110},
        {id = "lich_apprentice", name = "Lich Apprentice", hp = 120, atk = 44, def = 14, xp = 160, gold = 130},
        {id = "dread_wraith", name = "Dread Wraith", hp = 130, atk = 40, def = 10, xp = 150, gold = 120},
        {id = "undead_general", name = "Undead General", hp = 180, atk = 36, def = 24, xp = 155, gold = 125},
    },
    boss = {
        {id = "lich_overlord", name = "Lich Overlord", hp = 280, atk = 55, def = 25, xp = 400, gold = 350},
        {id = "archlich", name = "Archlich", hp = 350, atk = 65, def = 30, xp = 600, gold = 500},
        {id = "lich_emperor", name = "Lich Emperor", hp = 450, atk = 75, def = 35, xp = 800, gold = 700},
    }
}

-- Desert Tomb enemies
Data.DESERT_TOMB_ENEMIES = {
    shallow = {
        {id = "sand_zombie", name = "Desiccated Corpse", hp = 20, atk = 6, def = 3, xp = 12, gold = 8},
        {id = "scorpion", name = "Tomb Scorpion", hp = 18, atk = 8, def = 5, xp = 14, gold = 6},
        {id = "skeleton", name = "Sand-Bleached Skeleton", hp = 22, atk = 7, def = 4, xp = 13, gold = 7},
        {id = "scarab_swarm", name = "Scarab Swarm", hp = 15, atk = 10, def = 2, xp = 15, gold = 9},
        {id = "tomb_rat", name = "Desert Rat", hp = 12, atk = 5, def = 1, xp = 8, gold = 4},
    },
    mid = {
        {id = "mummy", name = "Mummified Sorcerer", hp = 50, atk = 14, def = 8, xp = 35, gold = 25},
        {id = "scorpion_giant", name = "Giant Scorpion", hp = 45, atk = 18, def = 10, xp = 38, gold = 22},
        {id = "tomb_guardian", name = "Death-Bound Guardian", hp = 55, atk = 16, def = 12, xp = 40, gold = 28},
        {id = "sand_wraith", name = "Sand Wraith", hp = 42, atk = 20, def = 6, xp = 36, gold = 24},
        {id = "undead_warrior", name = "Entombed Warrior", hp = 48, atk = 17, def = 9, xp = 42, gold = 30},
    },
    deep = {
        {id = "mummy_priest", name = "Mummy Archpriest", hp = 70, atk = 24, def = 10, xp = 65, gold = 48},
        {id = "greater_scorpion", name = "Obsidian Scorpion", hp = 75, atk = 26, def = 14, xp = 70, gold = 52},
        {id = "sand_golem", name = "Sand Golem", hp = 90, atk = 22, def = 18, xp = 75, gold = 55},
        {id = "curse_bearer", name = "Curse Bearer", hp = 65, atk = 28, def = 8, xp = 68, gold = 50},
        {id = "proto_lich_acolyte", name = "Proto-Lich Acolyte", hp = 80, atk = 25, def = 16, xp = 72, gold = 58},
    },
    boss = {
        {id = "proto_lich", name = "Ancient Proto-Lich", hp = 200, atk = 42, def = 20, xp = 250, gold = 200},
        {id = "sand_titan", name = "Sand Titan", hp = 220, atk = 38, def = 25, xp = 240, gold = 180},
        {id = "ancient_curse", name = "Ancient Curse Incarnate", hp = 180, atk = 45, def = 18, xp = 260, gold = 190},
    }
}

-- Desert Temple enemies
Data.DESERT_TEMPLE_ENEMIES = {
    shallow = {
        {id = "moon_cultist", name = "Moon Cultist", hp = 25, atk = 8, def = 3, xp = 14, gold = 10},
        {id = "temple_guard", name = "Temple Guard", hp = 30, atk = 10, def = 5, xp = 16, gold = 12},
        {id = "sand_snake", name = "Desert Viper", hp = 18, atk = 12, def = 2, xp = 15, gold = 8},
        {id = "moon_sprite", name = "Lunar Sprite", hp = 20, atk = 11, def = 3, xp = 17, gold = 11},
        {id = "scorpion", name = "Temple Scorpion", hp = 22, atk = 9, def = 6, xp = 14, gold = 9},
    },
    mid = {
        {id = "moon_priest", name = "Moon Priest", hp = 48, atk = 18, def = 7, xp = 38, gold = 28},
        {id = "shadow_elemental", name = "Shadow Elemental", hp = 52, atk = 22, def = 8, xp = 42, gold = 32},
        {id = "temple_champion", name = "Temple Champion", hp = 58, atk = 20, def = 12, xp = 45, gold = 35},
        {id = "night_stalker", name = "Night Stalker", hp = 45, atk = 24, def = 6, xp = 40, gold = 30},
        {id = "glass_guardian", name = "Moonstone Guardian", hp = 55, atk = 19, def = 14, xp = 43, gold = 33},
    },
    deep = {
        {id = "high_priest", name = "High Priest of the Moon", hp = 75, atk = 28, def = 10, xp = 70, gold = 55},
        {id = "greater_shadow", name = "Greater Shadow Elemental", hp = 80, atk = 30, def = 12, xp = 75, gold = 60},
        {id = "lunar_titan", name = "Lunar Titan", hp = 95, atk = 26, def = 20, xp = 80, gold = 65},
        {id = "void_specter", name = "Void Specter", hp = 85, atk = 32, def = 14, xp = 78, gold = 62},
        {id = "moonblade_warrior", name = "Moonblade Warrior", hp = 88, atk = 29, def = 16, xp = 77, gold = 58},
    },
    boss = {
        {id = "lunar_avatar", name = "Avatar of the Moon", hp = 220, atk = 45, def = 22, xp = 280, gold = 220},
        {id = "void_sovereign", name = "Void Sovereign", hp = 200, atk = 48, def = 18, xp = 270, gold = 210},
        {id = "eclipse_champion", name = "Champion of the Eclipse", hp = 240, atk = 42, def = 25, xp = 290, gold = 230},
    }
}

-- Calidar Wastes dungeon enemies
Data.CALIDAR_WASTES_ENEMIES = {
    shallow = {
        {id = "glass_shard", name = "Animate Glass Shard", hp = 15, atk = 12, def = 1, xp = 14, gold = 5},
        {id = "memory_echo", name = "Memory Echo", hp = 18, atk = 8, def = 2, xp = 16, gold = 3},
        {id = "vitrified_rat", name = "Vitrified Rat", hp = 12, atk = 6, def = 8, xp = 10, gold = 4},
        {id = "sand_phantom", name = "Sand Phantom", hp = 20, atk = 10, def = 3, xp = 15, gold = 6},
        {id = "calidar_skeleton", name = "Calidar Skeleton", hp = 22, atk = 9, def = 5, xp = 14, gold = 8},
    },
    mid = {
        {id = "glass_walker", name = "Glass Walker", hp = 45, atk = 14, def = 18, xp = 38, gold = 22},
        {id = "dust_wraith", name = "Dust Wraith", hp = 30, atk = 24, def = 2, xp = 42, gold = 8},
        {id = "hollow_scholar", name = "Hollow Scholar", hp = 40, atk = 20, def = 8, xp = 36, gold = 28},
        {id = "scorched_guardian", name = "Scorched Guardian", hp = 55, atk = 18, def = 14, xp = 44, gold = 32},
        {id = "memory_thief", name = "Memory Thief", hp = 35, atk = 22, def = 6, xp = 40, gold = 18},
    },
    deep = {
        {id = "hollow_cultist", name = "Hollow Cultist", hp = 65, atk = 26, def = 12, xp = 65, gold = 45},
        {id = "scorched_specter", name = "Scorched Specter", hp = 70, atk = 30, def = 5, xp = 75, gold = 15},
        {id = "warden_shade", name = "Shade of the Last Warden", hp = 80, atk = 28, def = 16, xp = 78, gold = 55},
        {id = "glass_colossus", name = "Vitrified Colossus", hp = 95, atk = 24, def = 22, xp = 82, gold = 60},
        {id = "covenant_seeker", name = "Covenant Seeker", hp = 72, atk = 32, def = 10, xp = 80, gold = 50},
    },
    boss = {
        {id = "the_unfinished", name = "The Unfinished", hp = 250, atk = 45, def = 20, xp = 350, gold = 150},
        {id = "first_hollow", name = "The First Hollow", hp = 220, atk = 50, def = 18, xp = 320, gold = 180},
        {id = "gate_fragment", name = "Fragment of the Gate", hp = 280, atk = 40, def = 25, xp = 380, gold = 120},
    }
}

-- Water dungeon enemies
Data.WATER_DUNGEON_ENEMIES = {
    shallow = {
        {id = "sea_crab", name = "Giant Crab", hp = 25, atk = 8, def = 6, xp = 12, gold = 8},
        {id = "drowned_sailor", name = "Drowned Sailor", hp = 28, atk = 9, def = 3, xp = 14, gold = 10},
        {id = "jellyfish_swarm", name = "Jellyfish Swarm", hp = 18, atk = 10, def = 1, xp = 10, gold = 5},
        {id = "pirate_scout", name = "Pirate Lookout", hp = 30, atk = 10, def = 4, xp = 16, gold = 12},
        {id = "sea_snake", name = "Sea Snake", hp = 15, atk = 11, def = 2, xp = 9, gold = 4},
    },
    mid = {
        {id = "shark", name = "Bull Shark", hp = 50, atk = 18, def = 6, xp = 35, gold = 22},
        {id = "merfolk_warrior", name = "Merfolk Warrior", hp = 45, atk = 15, def = 9, xp = 30, gold = 20},
        {id = "sahuagin", name = "Sahuagin Hunter", hp = 42, atk = 16, def = 8, xp = 32, gold = 18},
        {id = "giant_octopus", name = "Giant Octopus", hp = 55, atk = 14, def = 7, xp = 38, gold = 25},
        {id = "water_elemental", name = "Water Elemental", hp = 48, atk = 17, def = 10, xp = 34, gold = 22},
    },
    deep = {
        {id = "sea_serpent", name = "Sea Serpent", hp = 95, atk = 26, def = 14, xp = 75, gold = 55},
        {id = "aboleth", name = "Deep Aboleth", hp = 110, atk = 28, def = 16, xp = 90, gold = 65},
        {id = "drowned_knight", name = "Drowned Knight", hp = 75, atk = 24, def = 12, xp = 65, gold = 45},
        {id = "sea_hag", name = "Sea Hag", hp = 65, atk = 30, def = 8, xp = 70, gold = 50},
        {id = "megalodon", name = "Megalodon", hp = 120, atk = 32, def = 12, xp = 95, gold = 60},
    },
    boss = {
        {id = "kraken", name = "Kraken", hp = 250, atk = 40, def = 20, xp = 300, gold = 200},
        {id = "leviathan", name = "Leviathan", hp = 300, atk = 45, def = 25, xp = 400, gold = 250},
        {id = "sea_dragon", name = "Sea Dragon", hp = 220, atk = 38, def = 22, xp = 350, gold = 220},
        {id = "pirate_king", name = "Pirate King", hp = 180, atk = 35, def = 18, xp = 250, gold = 300},
    }
}

-- Dungeon loot tables
Data.DUNGEON_LOOT = {
    common = {
        {name = "Gold Coins", type = "gold", minAmount = 10, maxAmount = 30},
        {name = "Health Potion", type = "item", id = "health_potion", amount = 1},
        {name = "Mana Potion", type = "item", id = "mana_potion", amount = 1},
    },
    uncommon = {
        {name = "Gold Pile", type = "gold", minAmount = 30, maxAmount = 60},
        {name = "Greater Health Potion", type = "item", id = "greater_health_potion", amount = 1},
        {name = "Antidote", type = "item", id = "antidote", amount = 1},
    },
    rare = {
        {name = "Treasure Hoard", type = "gold", minAmount = 60, maxAmount = 120},
        {name = "Elixir", type = "item", id = "elixir", amount = 1},
        {name = "Ancient Map", type = "item", id = "ancient_map", amount = 1},
    }
}

-- Dungeon NPC types (prisoners, lost adventurers, etc.)
Data.DUNGEON_NPCS = {
    {id = "prisoner", name = "Imprisoned Villager", dialogue = "Thank the gods! I've been trapped here for days!", reward = "gold", rewardAmount = 25},
    {id = "lost_merchant", name = "Lost Merchant", dialogue = "I got separated from my caravan. Here, take this for saving me!", reward = "item", rewardId = "health_potion", rewardAmount = 3},
    {id = "wounded_knight", name = "Wounded Knight", dialogue = "I underestimated these creatures... Take my shield, you'll need it.", reward = "gold", rewardAmount = 50},
    {id = "trapped_mage", name = "Trapped Mage", dialogue = "The magic here is strong. I can enchant one of your items as thanks.", reward = "mana", rewardAmount = 30},
    {id = "escaped_prisoner", name = "Former Prisoner", dialogue = "I found a secret passage! Let me show you...", reward = "reveal_exit", rewardAmount = 0},
}

-- CALIDAR-SPECIFIC NPCs (appear only in Calidar Wastes dungeons)
Data.CALIDAR_DUNGEON_NPCS = {
    {id = "lost_scholar", name = "Lost Scholar",
        dialogue = "You shouldn't be here. No one should. I came looking for answers about the Vel'sharath... I found more questions. Take my notes. Maybe you'll understand them better than I did.",
        reward = "lore", rewardId = "covenant_fragment_7", rewardAmount = 1},
    {id = "dying_warden", name = "Shade of a Warden",
        dialogue = "We held the line... for three seconds, we held it. Was it enough? I cannot remember anymore. Take this. Remember us, if nothing else.",
        reward = "gold", rewardAmount = 100},
    {id = "hollow_survivor", name = "Hollow Survivor",
        dialogue = "*The elf stares through you, not at you* In emptiness... no. No, that's not right. That was never right. Run. Run while you still remember how.",
        reward = "warning", rewardAmount = 0},
    {id = "glass_elf", name = "Vitrified Elf",
        dialogue = "*The figure is half-fused with the crystallized ground. Their lips move but no sound emerges. You feel their words directly in your mind* ...the light came, and we became forever...",
        reward = "xp", rewardAmount = 50},
    {id = "professor_vaelith", name = "Professor Vaelith",
        dialogue = "Another seeker of truth! I've spent decades piecing together what really happened here. The official history is a lie, but the real truth... I'm not sure anyone should know it. Here - my research notes. Make of them what you will.",
        reward = "lore", rewardId = "covenant_fragment_1", rewardAmount = 1,
        questGiver = true, questId = "covenant_truth"},
}

-- Dungeon names for generation by type
Data.DUNGEON_NAMES = {
    dungeon = {
        prefixes = {"Ancient", "Dark", "Forsaken", "Cursed", "Shadow", "Deep", "Lost", "Forgotten", "Ruined", "Grim"},
        suffixes = {"Dungeon", "Depths", "Prison", "Stronghold", "Fortress", "Keep", "Hold", "Pit", "Halls", "Bastille"}
    },
    cave = {
        prefixes = {"Crystal", "Dark", "Deep", "Echo", "Shadow", "Twisted", "Hollow", "Damp", "Hidden", "Mossy"},
        suffixes = {"Caverns", "Caves", "Grotto", "Hollow", "Tunnels", "Chasm", "Abyss", "Passages", "Depths", "Lair"}
    },
    mine = {
        prefixes = {"Abandoned", "Collapsed", "Deep", "Cursed", "Lost", "Haunted", "Old", "Forgotten", "Flooded", "Dark"},
        suffixes = {"Mines", "Shafts", "Tunnels", "Dig", "Excavation", "Quarry", "Works", "Pit", "Delve", "Galleries"}
    },
    vampire_den = {
        prefixes = {"Blood", "Crimson", "Dark", "Eternal", "Midnight", "Shadow", "Dread", "Forsaken", "Unholy", "Bleeding"},
        suffixes = {"Manor", "Crypt", "Sanctum", "Lair", "Catacombs", "Citadel", "Mansion", "Vault", "Den", "Throne"}
    },
    crypt = {
        prefixes = {"Ancient", "Forgotten", "Cursed", "Haunted", "Defiled", "Lost", "Unholy", "Silent", "Eternal", "Grim"},
        suffixes = {"Crypt", "Tomb", "Mausoleum", "Sepulcher", "Catacomb", "Ossuary", "Necropolis", "Barrow", "Grave", "Burial"}
    },
    desert_tomb = {
        prefixes = {"Ancient", "Sunken", "Buried", "Forgotten", "Cursed", "Sealed", "Scorched", "Sand-Swept", "Primordial", "Withered", "Eternal"},
        suffixes = {"Tomb", "Necropolis", "Sepulcher", "Mausoleum", "Crypt", "Burial Chamber", "Vault", "Monument", "Catacomb", "Ossuary"}
    },
    desert_temple = {
        prefixes = {"Lunar", "Moonlit", "Twilight", "Ancient", "Lost", "Shadowed", "Silver", "Eternal", "Veiled", "Sacred", "Starless"},
        suffixes = {"Temple", "Sanctuary", "Shrine", "Altar", "Sanctum", "Cathedral", "Ziggurat", "Obelisk", "Monument", "Basilica"}
    },
    ocean_cave = {
        prefixes = {"Coral", "Tidal", "Deep", "Brine", "Sunken", "Drowned", "Abyssal", "Murky", "Hidden", "Flooded"},
        suffixes = {"Grotto", "Cavern", "Hollow", "Den", "Depths", "Lair", "Cave", "Chamber", "Tunnels", "Abyss"}
    },
    sunken_ship = {
        prefixes = {"The Wrecked", "The Lost", "The Doomed", "The Cursed", "The Sunken", "The Ghostly", "The Drowned", "The Shattered", "The Barnacled", "The Forgotten"},
        suffixes = {"Galleon", "Frigate", "Vessel", "Ship", "Carrack", "Brigantine", "Corsair", "Merchantman", "Warship", "Flagship"}
    },
    underwater_ruins = {
        prefixes = {"Sunken", "Ancient", "Coral-Covered", "Lost", "Drowned", "Forgotten", "Submerged", "Tidal", "Abyssal", "Deep"},
        suffixes = {"Ruins", "City", "Temple", "Sanctuary", "Palace", "Citadel", "Spire", "Colosseum", "Library", "Archives"}
    },
    sea_fortress = {
        prefixes = {"Iron", "Storm", "Coral", "Tidal", "Pirate", "Reef", "Wave", "Salt", "Barnacle", "Thunder"},
        suffixes = {"Fortress", "Stronghold", "Bastion", "Citadel", "Keep", "Tower", "Redoubt", "Battery", "Hold", "Garrison"}
    },
    kraken_lair = {
        prefixes = {"Abyssal", "Nightmare", "Crushing", "Inky", "Monstrous", "Tentacled", "Primordial", "Elder", "Ancient", "Dread"},
        suffixes = {"Lair", "Abyss", "Depths", "Trench", "Chasm", "Domain", "Maw", "Pit", "Throne", "Sanctum"}
    }
}

-- Seasons table (lore names for display, internal keys for logic)
Data.SEASONS = {"frosthollow", "brightbloom", "sunreign", "ashwane"}
Data.SEASON_DISPLAY = {
    frosthollow = "Frosthollow",
    brightbloom = "Brightbloom",
    sunreign    = "Sunreign",
    ashwane     = "Ashwane",
}

-- Calendar system - lore-based months
Data.MONTHS = {
    {name = "Deepmere",    days = 31},  -- deep cold, still waters
    {name = "Ironveil",    days = 28},  -- iron cold, veiled world
    {name = "Thawmist",    days = 31},  -- thawing, mists rise
    {name = "Greenward",   days = 30},  -- green returns
    {name = "Starbloom",   days = 31},  -- stars and blooming
    {name = "Solaren",     days = 30},  -- sun ascends, Helios honored
    {name = "Highsun",     days = 31},  -- peak of Helios's light
    {name = "Forgefire",   days = 31},  -- dwarven forging season
    {name = "Harvestmere", days = 30},  -- harvest, waning warmth
    {name = "Glassfall",   days = 31},  -- glass desert of Calidar, leaves fall
    {name = "Shadowmere",  days = 30},  -- shadows lengthen
    {name = "Voidwatch",   days = 31},  -- darkest month, vigil against the void
}
Data.DAYS_PER_YEAR = 365

-- ============================================================================
-- HELPER FUNCTIONS & LOOKUP TABLES
-- ============================================================================

-- Build TALENT_LOOKUP for O(1) talent access
Data.TALENT_LOOKUP = {}
for _, t in ipairs(Data.UNIVERSAL_TALENTS) do
    Data.TALENT_LOOKUP[t.id] = t
end
for _, talents in pairs(Data.CLASS_TALENTS) do
    for _, t in ipairs(talents) do
        Data.TALENT_LOOKUP[t.id] = t
    end
end

-- Get dungeon tile type by id
function Data.getDungeonTileType(id)
    for _, t in ipairs(Data.DUNGEON_TILE_TYPES) do
        if t.id == id then return t end
    end
    return Data.DUNGEON_TILE_TYPES[1] -- Default to wall
end

-- Get enemies for dungeon type
function Data.getDungeonEnemiesForType(dungeonType)
    if dungeonType == "vampire_den" then
        return Data.VAMPIRE_DEN_ENEMIES
    elseif dungeonType == "cave" then
        return Data.CAVE_ENEMIES
    elseif dungeonType == "mine" then
        return Data.MINE_ENEMIES
    elseif dungeonType == "crypt" then
        return Data.CRYPT_ENEMIES
    elseif dungeonType == "lich_lair" then
        return Data.LICH_LAIR_ENEMIES
    elseif dungeonType == "desert_tomb" then
        return Data.DESERT_TOMB_ENEMIES
    elseif dungeonType == "desert_temple" then
        return Data.DESERT_TEMPLE_ENEMIES
    elseif dungeonType == "calidar_wastes" or dungeonType == "covenant_sanctum" or dungeonType == "glassed_ruins" then
        return Data.CALIDAR_WASTES_ENEMIES
    elseif dungeonType == "ocean_cave" or dungeonType == "sunken_ship" or dungeonType == "underwater_ruins" or dungeonType == "sea_fortress" or dungeonType == "kraken_lair" then
        return Data.WATER_DUNGEON_ENEMIES
    else
        return Data.DUNGEON_ENEMIES
    end
end

-- ============================================================================
-- STEALTH TIME MODIFIERS - Time-based detection modifiers
-- ============================================================================
Data.STEALTH_TIME_MODIFIERS = {
    [0] = {name = "Late Night", detection = 0.20, desc = "Excellent stealth"},
    [1] = {name = "Late Night", detection = 0.20, desc = "Excellent stealth"},
    [2] = {name = "Late Night", detection = 0.20, desc = "Excellent stealth"},
    [3] = {name = "Late Night", detection = 0.20, desc = "Excellent stealth"},
    [4] = {name = "Late Night", detection = 0.20, desc = "Excellent stealth"},
    [5] = {name = "Dawn", detection = 0.50, desc = "Good stealth"},
    [6] = {name = "Dawn", detection = 0.70, desc = "Fair stealth"},
    [7] = {name = "Morning", detection = 0.90, desc = "Poor stealth"},
    [8] = {name = "Morning", detection = 0.90, desc = "Poor stealth"},
    [9] = {name = "Morning", detection = 0.90, desc = "Poor stealth"},
    [10] = {name = "Morning", detection = 0.90, desc = "Poor stealth"},
    [11] = {name = "Morning", detection = 0.90, desc = "Poor stealth"},
    [12] = {name = "Noon", detection = 1.00, desc = "Worst stealth"},
    [13] = {name = "Noon", detection = 1.00, desc = "Worst stealth"},
    [14] = {name = "Afternoon", detection = 0.90, desc = "Poor stealth"},
    [15] = {name = "Afternoon", detection = 0.90, desc = "Poor stealth"},
    [16] = {name = "Afternoon", detection = 0.90, desc = "Poor stealth"},
    [17] = {name = "Afternoon", detection = 0.90, desc = "Poor stealth"},
    [18] = {name = "Dusk", detection = 0.60, desc = "Good stealth"},
    [19] = {name = "Evening", detection = 0.40, desc = "Very good stealth"},
    [20] = {name = "Evening", detection = 0.40, desc = "Very good stealth"},
    [21] = {name = "Evening", detection = 0.40, desc = "Very good stealth"},
    [22] = {name = "Night", detection = 0.20, desc = "Excellent stealth"},
    [23] = {name = "Night", detection = 0.20, desc = "Excellent stealth"},
}

-- ============================================================================
-- JOURNAL TABS - Journal tab definitions
-- ============================================================================
Data.JOURNAL_TABS = {
    {id = "events", name = "Events", icon = "📜"},
    {id = "quests", name = "Quests", icon = "📋"},
    {id = "actions", name = "Actions", icon = "📊"},
    {id = "factions", name = "Factions", icon = "🏛️"},
    {id = "party", name = "Party", icon = "👥"},
    {id = "stats", name = "Stats", icon = "📈"},
    {id = "status", name = "Status", icon = "🩺"},
}

-- ============================================================================
-- VAMPIRE ENEMY IDS - List of vampire enemy IDs
-- ============================================================================
Data.VAMPIRE_ENEMY_IDS = {
    vampire = true,
    vampire_lord = true,
    vampire_spawn = true,
}

-- ============================================================================
-- REGIONAL NPC POOLS - NPC pools by region
-- ============================================================================
Data.REGIONAL_NPC_POOLS = {
    holy_dominion = {"human","human","human","human","elf","dwarf","gnome"},
    dwarven_mountains = {"dwarf","dwarf","dwarf","dwarf","human","gnome"},
    orcish_steppes = {"orc","orc","orc","goblin","goblin","human"},
    shadowfen = {"human","human","lizardfolk","lizardfolk","goblin"},
    gnomish_isles = {"gnome","gnome","gnome","gnome","human","dwarf"},
    great_endless_desert = {"catfolk","catfolk","catfolk","human","lizardfolk"},
}

-- ============================================================================
-- SKILL TREE - Node-graph tree inspired by PoE / Fear & Hunger 2
-- Interconnected web of nodes radiating from a central start node.
-- 4 regions: Warfare (north), Sorcery (east), Shadow (south), Survival (west)
-- 4 bridge nodes connect adjacent regions. Any character can reach any node.
-- Node types: start (free), minor (1 SP), skill (2 SP), keystone (3 SP)
-- Unlock rule: a node can be unlocked if at least one connected node is already unlocked.
-- ============================================================================
Data.SKILL_TREES = {
    universal = {
        name = "Path of the Adventurer",
        nodes = {
            -- ============================
            -- CENTER
            -- ============================
            {id = "start", name = "Inner Potential", x = 0, y = 0,
             nodeType = "start", region = "center", cost = 0,
             desc = "The center of your potential. All paths begin here.",
             effect = {type = "passive"},
             connections = {"might_path", "arcane_path", "shadow_path", "nature_path"}},

            -- ============================
            -- PATH NODES (connect center to each region)
            -- ============================
            {id = "might_path", name = "Path of Might", x = 0, y = -2,
             nodeType = "minor", region = "warfare", cost = 1,
             desc = "+3 Attack",
             effect = {type = "passive", attack = 3},
             connections = {"start", "strength_1", "strength_2", "paladin_bridge", "battlemage_bridge"}},

            {id = "arcane_path", name = "Path of the Arcane", x = 2, y = 0,
             nodeType = "minor", region = "sorcery", cost = 1,
             desc = "+10% spell damage",
             effect = {type = "passive", spellDamage = 0.10},
             connections = {"start", "arcana_1", "arcana_2", "battlemage_bridge", "trickster_bridge"}},

            {id = "shadow_path", name = "Path of Shadows", x = 0, y = 2,
             nodeType = "minor", region = "shadow", cost = 1,
             desc = "+3% critical hit chance",
             effect = {type = "passive", critChance = 3},
             connections = {"start", "cunning_1", "cunning_2", "trickster_bridge", "ranger_bridge"}},

            {id = "nature_path", name = "Path of Nature", x = -2, y = 0,
             nodeType = "minor", region = "survival", cost = 1,
             desc = "+15 max HP",
             effect = {type = "passive", maxHP = 15},
             connections = {"start", "fortitude_1", "fortitude_2", "ranger_bridge", "paladin_bridge"}},

            -- ============================
            -- BRIDGE NODES (connect adjacent regions)
            -- ============================
            {id = "paladin_bridge", name = "Paladin's Resolve", x = -2, y = -2,
             nodeType = "skill", region = "center", cost = 2,
             desc = "+3 Defense, regenerate 5% HP per turn",
             effect = {type = "passive", defense = 3, regenPercent = 0.05},
             connections = {"might_path", "nature_path", "shield_wall", "hunters_mark"}},

            {id = "battlemage_bridge", name = "Battle Mage Stance", x = 2, y = -2,
             nodeType = "skill", region = "center", cost = 2,
             desc = "+2 Attack, +5% spell damage",
             effect = {type = "passive", attack = 2, spellDamage = 0.05},
             connections = {"might_path", "arcane_path", "cleave", "chain_lightning"}},

            {id = "trickster_bridge", name = "Trickster's Guile", x = 2, y = 2,
             nodeType = "skill", region = "center", cost = 2,
             desc = "+2% critical chance, +5% dodge",
             effect = {type = "passive", critChance = 2, dodge = 5},
             connections = {"arcane_path", "shadow_path", "frost_nova", "shadowstep"}},

            {id = "ranger_bridge", name = "Ranger's Instinct", x = -2, y = 2,
             nodeType = "skill", region = "center", cost = 2,
             desc = "+2 Attack, +10 max HP",
             effect = {type = "passive", attack = 2, maxHP = 10},
             connections = {"shadow_path", "nature_path", "poison_blade", "group_heal"}},

            -- ============================
            -- WARFARE REGION (north) - Melee offense and defense
            -- ============================
            {id = "strength_1", name = "Brute Force", x = -1, y = -3,
             nodeType = "minor", region = "warfare", cost = 1,
             desc = "+2 Attack",
             effect = {type = "passive", attack = 2},
             connections = {"might_path", "power_strike", "shield_wall"}},

            {id = "strength_2", name = "Combat Training", x = 1, y = -3,
             nodeType = "minor", region = "warfare", cost = 1,
             desc = "+2 Attack, +1 Defense",
             effect = {type = "passive", attack = 2, defense = 1},
             connections = {"might_path", "power_strike", "cleave"}},

            {id = "power_strike", name = "Power Strike", x = 0, y = -4,
             nodeType = "skill", region = "warfare", cost = 2,
             desc = "A powerful melee attack dealing 150% weapon damage",
             effect = {type = "attack", damageMultiplier = 1.5},
             connections = {"strength_1", "strength_2", "iron_wall", "berserker_rage"}},

            {id = "shield_wall", name = "Shield Wall", x = -2, y = -4,
             nodeType = "skill", region = "warfare", cost = 2,
             desc = "Brace for impact: +5 defense and taunt enemies for 2 turns",
             effect = {type = "buff", stat = "defense", amount = 5, taunt = true, duration = 2},
             connections = {"strength_1", "paladin_bridge", "iron_wall"}},

            {id = "cleave", name = "Cleave", x = 2, y = -4,
             nodeType = "skill", region = "warfare", cost = 2,
             desc = "Wide swing hitting all enemies for 120% damage",
             effect = {type = "aoe", damageMultiplier = 1.2},
             connections = {"strength_2", "battlemage_bridge", "berserker_rage"}},

            {id = "iron_wall", name = "Iron Wall", x = -1, y = -5,
             nodeType = "skill", region = "warfare", cost = 2,
             desc = "Block 50% of all incoming damage for 2 turns",
             effect = {type = "buff", damageReduction = 0.5, duration = 2},
             connections = {"power_strike", "shield_wall", "warlord"}},

            {id = "berserker_rage", name = "Berserker Rage", x = 1, y = -5,
             nodeType = "skill", region = "warfare", cost = 2,
             desc = "+50% damage but -25% defense for 3 turns",
             effect = {type = "buff", attackMult = 1.5, defenseMult = 0.75, duration = 3},
             connections = {"power_strike", "cleave", "warlord"}},

            {id = "warlord", name = "Warlord", x = 0, y = -6,
             nodeType = "keystone", region = "warfare", cost = 3,
             desc = "Passive: +20% damage dealt, +15% damage reduction permanently",
             effect = {type = "passive", damageMult = 1.2, damageReduction = 0.15},
             connections = {"iron_wall", "berserker_rage"}},

            -- ============================
            -- SORCERY REGION (east) - Spells and arcane power
            -- ============================
            {id = "arcana_1", name = "Arcane Focus", x = 3, y = -1,
             nodeType = "minor", region = "sorcery", cost = 1,
             desc = "+8% spell damage",
             effect = {type = "passive", spellDamage = 0.08},
             connections = {"arcane_path", "fireball", "chain_lightning"}},

            {id = "arcana_2", name = "Elemental Attunement", x = 3, y = 1,
             nodeType = "minor", region = "sorcery", cost = 1,
             desc = "+5% spell damage, 10% chance to apply elemental effect",
             effect = {type = "passive", spellDamage = 0.05, elementalProc = 0.10},
             connections = {"arcane_path", "fireball", "frost_nova"}},

            {id = "fireball", name = "Fireball", x = 4, y = 0,
             nodeType = "skill", region = "sorcery", cost = 2,
             desc = "Launch a fireball dealing magic damage + burn over time",
             effect = {type = "spell", damage = 35, dot = 5, dotDuration = 2, element = "fire"},
             connections = {"arcana_1", "arcana_2", "meteor_strike", "time_warp"}},

            {id = "chain_lightning", name = "Chain Lightning", x = 4, y = -2,
             nodeType = "skill", region = "sorcery", cost = 2,
             desc = "Lightning that jumps between up to 3 enemies",
             effect = {type = "spell", damage = 30, chain = 3, element = "lightning"},
             connections = {"arcana_1", "battlemage_bridge", "meteor_strike"}},

            {id = "frost_nova", name = "Frost Nova", x = 4, y = 2,
             nodeType = "skill", region = "sorcery", cost = 2,
             desc = "Freeze all enemies for 1 turn",
             effect = {type = "aoe_cc", freeze = 1, element = "ice"},
             connections = {"arcana_2", "trickster_bridge", "time_warp"}},

            {id = "meteor_strike", name = "Meteor Strike", x = 5, y = -1,
             nodeType = "skill", region = "sorcery", cost = 2,
             desc = "Call down a meteor for massive AoE fire damage",
             effect = {type = "aoe", damage = 60, element = "fire"},
             connections = {"fireball", "chain_lightning", "arcane_mastery"}},

            {id = "time_warp", name = "Time Warp", x = 5, y = 1,
             nodeType = "skill", region = "sorcery", cost = 2,
             desc = "Bend time to gain an extra action this turn",
             effect = {type = "extra_action"},
             connections = {"fireball", "frost_nova", "arcane_mastery"}},

            {id = "arcane_mastery", name = "Arcane Mastery", x = 6, y = 0,
             nodeType = "keystone", region = "sorcery", cost = 3,
             desc = "Passive: +25% spell damage, -20% mana cost permanently",
             effect = {type = "passive", spellDamageMult = 1.25, manaCostMult = 0.8},
             connections = {"meteor_strike", "time_warp"}},

            -- ============================
            -- SHADOW REGION (south) - Crits, stealth, assassination
            -- ============================
            {id = "cunning_1", name = "Keen Eye", x = -1, y = 3,
             nodeType = "minor", region = "shadow", cost = 1,
             desc = "+3% critical hit chance",
             effect = {type = "passive", critChance = 3},
             connections = {"shadow_path", "backstab", "poison_blade"}},

            {id = "cunning_2", name = "Fleet Foot", x = 1, y = 3,
             nodeType = "minor", region = "shadow", cost = 1,
             desc = "+5% dodge chance",
             effect = {type = "passive", dodge = 5},
             connections = {"shadow_path", "backstab", "shadowstep"}},

            {id = "backstab", name = "Backstab", x = 0, y = 4,
             nodeType = "skill", region = "shadow", cost = 2,
             desc = "Strike from behind for 200% damage if attacking first",
             effect = {type = "attack", damageMultiplier = 2.0, requiresFirst = true},
             connections = {"cunning_1", "cunning_2", "assassinate", "vanish"}},

            {id = "poison_blade", name = "Poison Blade", x = -2, y = 4,
             nodeType = "skill", region = "shadow", cost = 2,
             desc = "Coat weapon in poison, dealing damage over 3 turns",
             effect = {type = "dot", damage = 8, duration = 3, element = "poison"},
             connections = {"cunning_1", "ranger_bridge", "assassinate"}},

            {id = "shadowstep", name = "Shadowstep", x = 2, y = 4,
             nodeType = "skill", region = "shadow", cost = 2,
             desc = "Teleport behind enemy; next attack is a guaranteed critical",
             effect = {type = "movement", guaranteedCrit = true},
             connections = {"cunning_2", "trickster_bridge", "vanish"}},

            {id = "assassinate", name = "Assassinate", x = -1, y = 5,
             nodeType = "skill", region = "shadow", cost = 2,
             desc = "Execute: 300% damage on targets below 30% HP",
             effect = {type = "attack", damageMultiplier = 3.0, hpThreshold = 0.3},
             connections = {"backstab", "poison_blade", "death_mark"}},

            {id = "vanish", name = "Vanish", x = 1, y = 5,
             nodeType = "skill", region = "shadow", cost = 2,
             desc = "Become invisible for 2 turns; next attack deals 250% damage",
             effect = {type = "stealth", duration = 2, damageMultiplier = 2.5},
             connections = {"backstab", "shadowstep", "death_mark"}},

            {id = "death_mark", name = "Death Mark", x = 0, y = 6,
             nodeType = "keystone", region = "shadow", cost = 3,
             desc = "Passive: enemies below 20% HP take 50% more damage from you",
             effect = {type = "passive", executeThreshold = 0.2, executeDamageMult = 1.5},
             connections = {"assassinate", "vanish"}},

            -- ============================
            -- SURVIVAL REGION (west) - Healing, defense, utility
            -- ============================
            {id = "fortitude_1", name = "Tough Skin", x = -3, y = -1,
             nodeType = "minor", region = "survival", cost = 1,
             desc = "+3 Defense",
             effect = {type = "passive", defense = 3},
             connections = {"nature_path", "heal", "hunters_mark"}},

            {id = "fortitude_2", name = "Vitality", x = -3, y = 1,
             nodeType = "minor", region = "survival", cost = 1,
             desc = "+20 max HP",
             effect = {type = "passive", maxHP = 20},
             connections = {"nature_path", "heal", "group_heal"}},

            {id = "heal", name = "Heal", x = -4, y = 0,
             nodeType = "skill", region = "survival", cost = 2,
             desc = "Restore HP to self or an ally",
             effect = {type = "heal", baseHeal = 30, wisScaling = 2},
             connections = {"fortitude_1", "fortitude_2", "resurrection", "evasive_maneuver"}},

            {id = "group_heal", name = "Group Heal", x = -4, y = 2,
             nodeType = "skill", region = "survival", cost = 2,
             desc = "Heal entire party for a moderate amount",
             effect = {type = "aoe_heal", baseHeal = 20, wisScaling = 1.5},
             connections = {"fortitude_2", "ranger_bridge", "resurrection"}},

            {id = "hunters_mark", name = "Hunter's Mark", x = -4, y = -2,
             nodeType = "skill", region = "survival", cost = 2,
             desc = "Mark a target: it takes 25% more damage for 3 turns",
             effect = {type = "debuff", damageTakenMult = 1.25, duration = 3},
             connections = {"fortitude_1", "paladin_bridge", "evasive_maneuver"}},

            {id = "resurrection", name = "Resurrection", x = -5, y = 1,
             nodeType = "skill", region = "survival", cost = 2,
             desc = "Revive a fallen party member at 50% HP",
             effect = {type = "revive", hpPercent = 0.5},
             connections = {"heal", "group_heal", "undying"}},

            {id = "evasive_maneuver", name = "Evasive Maneuver", x = -5, y = -1,
             nodeType = "skill", region = "survival", cost = 2,
             desc = "Dodge the next attack and gain +30% crit for 1 turn",
             effect = {type = "buff", dodge = 1, critBonus = 30, duration = 1},
             connections = {"heal", "hunters_mark", "undying"}},

            {id = "undying", name = "Undying", x = -6, y = 0,
             nodeType = "keystone", region = "survival", cost = 3,
             desc = "Once per combat: cheat death and revive at 50% HP",
             effect = {type = "passive", autoRevive = true, reviveHP = 0.5},
             connections = {"resurrection", "evasive_maneuver"}},
        },
    },
}

-- ============================================================================
-- RACIAL ATTITUDES - Race-to-race attitude matrix
-- ============================================================================
Data.RACIAL_ATTITUDES = {
    human = {
        human = "friendly", elf = "neutral", dwarf = "friendly", orc = "cautious",
        goblin = "cautious", gnome = "neutral", catfolk = "curious", lizardfolk = "cautious",
    },
    elf = {
        human = "neutral", elf = "welcoming", dwarf = "neutral", orc = "hostile",
        goblin = "cautious", gnome = "neutral", catfolk = "neutral", lizardfolk = "cautious",
    },
    dwarf = {
        human = "friendly", elf = "neutral", dwarf = "welcoming", orc = "hostile",
        goblin = "hostile", gnome = "friendly", catfolk = "neutral", lizardfolk = "cautious",
    },
    orc = {
        human = "cautious", elf = "hostile", dwarf = "hostile", orc = "welcoming",
        goblin = "friendly", gnome = "cautious", catfolk = "neutral", lizardfolk = "neutral",
    },
    gnome = {
        human = "neutral", elf = "neutral", dwarf = "friendly", orc = "cautious",
        goblin = "cautious", gnome = "welcoming", catfolk = "curious", lizardfolk = "neutral",
    },
    goblin = {
        human = "cautious", elf = "cautious", dwarf = "hostile", orc = "friendly",
        goblin = "welcoming", gnome = "cautious", catfolk = "cautious", lizardfolk = "neutral",
    },
    catfolk = {
        human = "neutral", elf = "neutral", dwarf = "neutral", orc = "cautious",
        goblin = "cautious", gnome = "curious", catfolk = "welcoming", lizardfolk = "neutral",
    },
    lizardfolk = {
        human = "cautious", elf = "cautious", dwarf = "neutral", orc = "neutral",
        goblin = "neutral", gnome = "neutral", catfolk = "neutral", lizardfolk = "welcoming",
    },
}

-- ============================================================================
-- REGION ATTITUDE SHIFTS - Regional attitude shifts
-- ============================================================================
Data.REGION_ATTITUDE_SHIFTS = {
    holy_dominion = {
        human = 1, elf = 0, dwarf = 0,
        orc = -1, goblin = -1, lizardfolk = -1,
    },
    dwarven_mountains = {
        dwarf = 1, gnome = 1, human = 0,
        orc = -1, goblin = -2, elf = 0,
    },
    orcish_steppes = {
        orc = 1, goblin = 1,
        human = -1, elf = -1, dwarf = -1,
    },
    shadowfen = {
        lizardfolk = 1, goblin = 0,
        human = -1, elf = -1,
    },
    gnomish_isles = {
        gnome = 1, dwarf = 1,
        orc = -1, goblin = -1,
    },
    great_endless_desert = {
        catfolk = 1,
        human = 0, lizardfolk = 0,
    },
}

-- ============================================================================
-- QUEST ITEMS - Quest item definitions
-- ============================================================================
Data.QUEST_ITEMS = {
    "Iron Ore", "Healing Herbs", "Wolf Pelts", "Spider Silk", "Ancient Tome", "Magic Crystal",
    "Rare Mushrooms", "Dragon Scale", "Phoenix Feather", "Enchanted Gem", "Sacred Water",
    "Demon Horn", "Ghost Essence", "Troll Blood", "Goblin Ears", "Skeleton Bone"
}

-- ============================================================================
-- LOCATION NAMES - Location name lists
-- ============================================================================
Data.LOCATION_NAMES = {
    "The Old Mill", "Crystal Cave", "Dark Forest", "Mountain Pass", "Abandoned Mine",
    "Haunted Ruins", "River Crossing", "Ancient Temple", "Merchant Camp", "Hidden Valley"
}

-- ============================================================================
-- TOWN PREFIXES - Town name prefixes
-- ============================================================================
Data.TOWN_PREFIXES = {"Green", "Silver", "Dark", "Crystal", "Iron", "Golden", "Shadow", "Storm", "Frost", "Sun", "Moon", "Star", "Red", "Blue", "White"}

-- ============================================================================
-- TOWN SUFFIXES - Town name suffixes
-- ============================================================================
Data.TOWN_SUFFIXES = {"haven", "ford", "vale", "holm", "burg", "ton", "dale", "keep", "port", "wood", "cliff", "hollow", "reach", "gate", "bridge"}

-- ============================================================================
-- TRADE GOODS - Trade good definitions
-- ============================================================================
Data.TRADE_GOODS = {
    -- Food & Provisions
    {id = "wheat", name = "Wheat", category = "food", basePrice = 10, icon = "assets/icons/resourcesandfood/Bread.PNG"},
    {id = "meat", name = "Salted Meat", category = "food", basePrice = 25, icon = "assets/icons/resourcesandfood/FriedChickenLeg.PNG"},
    {id = "fish", name = "Dried Fish", category = "food", basePrice = 20, icon = "assets/icons/resourcesandfood/Res_140_fish.PNG"},
    {id = "ale", name = "Ale Barrel", category = "food", basePrice = 35, icon = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_19_little_flask.PNG"},
    {id = "wine", name = "Fine Wine", category = "food", basePrice = 80, icon = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_17_blue_potion.PNG"},
    -- Raw Materials
    {id = "iron_ore", name = "Iron Ore", category = "material", basePrice = 30, icon = "assets/icons/resources/Res_62_iron_ore.PNG"},
    {id = "timber", name = "Timber", category = "material", basePrice = 15, icon = "assets/icons/resources/Res_67_coal.PNG"},
    {id = "cloth", name = "Cloth Bolts", category = "material", basePrice = 40, icon = "assets/icons/resources/Res_68_cloth.PNG"},
    {id = "leather", name = "Leather", category = "material", basePrice = 45, icon = "assets/icons/loot/Loot_112_leather.PNG"},
    {id = "stone", name = "Cut Stone", category = "material", basePrice = 20, icon = "assets/icons/resources/Res_71_iron_bar.PNG"},
    -- Precious Goods
    {id = "gems", name = "Gemstones", category = "precious", basePrice = 150, icon = "assets/icons/resourcesandfood/Res_25_crystal.PNG"},
    {id = "gold_bars", name = "Gold Bars", category = "precious", basePrice = 200, icon = "assets/icons/loot/Loot_01_coins.PNG"},
    {id = "silk", name = "Silk", category = "precious", basePrice = 120, icon = "assets/icons/loot/Loot_157_ribbon.PNG"},
    {id = "spices", name = "Exotic Spices", category = "precious", basePrice = 100, icon = "assets/icons/professions/ProfessionAndCraftIcons/Herbalism/Herbalism_01_herbs.PNG"},
    -- Magic Items
    {id = "mana_crystals", name = "Mana Crystals", category = "magic", basePrice = 80, icon = "assets/icons/resourcesandfood/Res_167_MageCrystal.PNG"},
    {id = "enchanted_dust", name = "Enchanted Dust", category = "magic", basePrice = 60, icon = "assets/icons/resourcesandfood/Res_75_crystalS.PNG"},
    {id = "potions", name = "Potion Crates", category = "magic", basePrice = 90, icon = "assets/icons/professions/ProfessionAndCraftIcons/Alchemy/Alchemy_12_magic_potion.PNG"},
}

-- ============================================================================
-- TOWN SPECIALIZATIONS - Town specialization types
-- ============================================================================
Data.TOWN_SPECIALIZATIONS = {
    {name = "Mining Town", produces = {"iron_ore", "stone", "gems"}, consumes = {"food", "timber", "cloth"}},
    {name = "Farming Village", produces = {"wheat", "meat", "leather"}, consumes = {"iron_ore", "cloth", "potions"}},
    {name = "Port City", produces = {"fish", "silk", "spices"}, consumes = {"timber", "wheat", "iron_ore"}},
    {name = "Forest Settlement", produces = {"timber", "leather", "meat"}, consumes = {"iron_ore", "gems", "spices"}},
    {name = "Magic Academy", produces = {"mana_crystals", "enchanted_dust", "potions"}, consumes = {"food", "gems", "silk"}},
    {name = "Trade Hub", produces = {}, consumes = {}},  -- Average prices
    {name = "Noble Estate", produces = {"wine", "silk"}, consumes = {"food", "iron_ore", "gems"}},
    {name = "Mountain Hold", produces = {"iron_ore", "gems", "stone"}, consumes = {"wheat", "fish", "timber"}},
}

-- ============================================================================
-- UNDEAD ENEMY IDS - List of undead enemy IDs
-- ============================================================================
Data.UNDEAD_ENEMY_IDS = {
    "skeleton", "skeleton_archer", "skeleton_knight", "skeleton_mage", "skeleton_king",
    "zombie", "zombie_brute", "ghost", "ghost_knight", "wraith", "lich", "lich_king",
    "necromancer", "undead_dragon", "bone_snake", "frost_skeleton",
    "death_knight", "bone_colossus", "dracolich", "lich_overlord", "archlich"
}

-- ============================================================================
-- SEA ENEMIES - Sea combat enemy data
-- ============================================================================
Data.SEA_ENEMIES = {
    coastal = {
        {id = "sea_crab", name = "Giant Crab", hp = 25, atk = 8, def = 6, xp = 12, gold = 8, cr = 0.5,
         attacks = {{name = "Pinch", damage = {6, 10}, type = "physical"}, {name = "Shell Slam", damage = {8, 14}, type = "physical"}}},
        {id = "pirate_scout", name = "Pirate Scout", hp = 30, atk = 10, def = 4, xp = 18, gold = 15, cr = 1,
         attacks = {{name = "Cutlass Slash", damage = {8, 14}, type = "physical"}, {name = "Pistol Shot", damage = {10, 16}, type = "ranged"}}},
        {id = "sea_gull_swarm", name = "Razorbeak Flock", hp = 18, atk = 12, def = 2, xp = 10, gold = 5, cr = 0.5,
         attacks = {{name = "Peck Frenzy", damage = {6, 12}, type = "physical"}, {name = "Dive Bomb", damage = {10, 16}, type = "physical"}}},
        {id = "merfolk_guard", name = "Merfolk Guard", hp = 35, atk = 11, def = 7, xp = 20, gold = 12, cr = 1,
         attacks = {{name = "Trident Thrust", damage = {8, 14}, type = "physical"}, {name = "Tidal Splash", damage = {6, 12}, type = "magic"}}},
        {id = "jellyfish_swarm", name = "Jellyfish Swarm", hp = 20, atk = 9, def = 1, xp = 8, gold = 4, cr = 0.25,
         attacks = {{name = "Sting", damage = {6, 10}, type = "poison"}, {name = "Envelop", damage = {8, 12}, type = "poison"}}},
    },
    shallow = {
        {id = "shark", name = "Reef Shark", hp = 45, atk = 16, def = 6, xp = 30, gold = 20, cr = 2,
         attacks = {{name = "Bite", damage = {12, 20}, type = "physical"}, {name = "Thrash", damage = {14, 22}, type = "physical"}}},
        {id = "pirate_crew", name = "Pirate Crew", hp = 40, atk = 14, def = 8, xp = 35, gold = 30, cr = 2,
         attacks = {{name = "Broadside", damage = {12, 18}, type = "physical"}, {name = "Boarding Action", damage = {14, 22}, type = "physical"}}},
        {id = "sea_serpent_young", name = "Young Sea Serpent", hp = 55, atk = 18, def = 8, xp = 40, gold = 25, cr = 3,
         attacks = {{name = "Coil Crush", damage = {14, 22}, type = "physical"}, {name = "Venomous Bite", damage = {12, 20}, type = "poison"}}},
        {id = "sahuagin", name = "Sahuagin Raider", hp = 38, atk = 13, def = 7, xp = 28, gold = 18, cr = 2,
         attacks = {{name = "Coral Blade", damage = {10, 16}, type = "physical"}, {name = "Blood Frenzy", damage = {14, 22}, type = "physical"}}},
        {id = "water_elemental", name = "Water Elemental", hp = 50, atk = 15, def = 10, xp = 35, gold = 22, cr = 2.5,
         attacks = {{name = "Tidal Wave", damage = {12, 20}, type = "magic"}, {name = "Drown", damage = {16, 24}, type = "magic"}}},
    },
    deep = {
        {id = "sea_serpent", name = "Sea Serpent", hp = 100, atk = 28, def = 14, xp = 80, gold = 60, cr = 5,
         attacks = {{name = "Constrict", damage = {22, 34}, type = "physical"}, {name = "Tidal Roar", damage = {18, 28}, type = "magic"}, {name = "Swallow", damage = {28, 40}, type = "physical"}}},
        {id = "pirate_captain", name = "Pirate Captain", hp = 85, atk = 24, def = 12, xp = 70, gold = 80, cr = 4,
         attacks = {{name = "Captain's Strike", damage = {18, 28}, type = "physical"}, {name = "Cannon Volley", damage = {22, 34}, type = "ranged"}, {name = "Rally Crew", damage = {0, 0}, type = "buff"}}},
        {id = "aboleth", name = "Aboleth", hp = 110, atk = 26, def = 16, xp = 90, gold = 70, cr = 5,
         attacks = {{name = "Tentacle Slam", damage = {20, 30}, type = "physical"}, {name = "Psychic Blast", damage = {24, 36}, type = "magic"}, {name = "Enslave Mind", damage = {16, 24}, type = "magic"}}},
        {id = "ghost_ship_crew", name = "Spectral Sailors", hp = 60, atk = 22, def = 5, xp = 55, gold = 40, cr = 4,
         attacks = {{name = "Phantom Blade", damage = {18, 26}, type = "magic"}, {name = "Ghostly Wail", damage = {14, 22}, type = "magic"}}},
        {id = "megalodon", name = "Megalodon", hp = 130, atk = 32, def = 12, xp = 100, gold = 50, cr = 6,
         attacks = {{name = "Crushing Bite", damage = {26, 40}, type = "physical"}, {name = "Tail Whip", damage = {20, 30}, type = "physical"}, {name = "Devour", damage = {30, 46}, type = "physical"}}},
    },
    boss = {
        {id = "kraken", name = "Kraken", hp = 250, atk = 40, def = 20, xp = 300, gold = 200, cr = 8,
         attacks = {{name = "Tentacle Crush", damage = {30, 48}, type = "physical"}, {name = "Ink Cloud", damage = {20, 32}, type = "magic"}, {name = "Maelstrom", damage = {35, 55}, type = "magic"}}},
        {id = "leviathan", name = "Leviathan", hp = 300, atk = 45, def = 25, xp = 400, gold = 250, cr = 10,
         attacks = {{name = "World Ender", damage = {40, 60}, type = "physical"}, {name = "Tidal Annihilation", damage = {35, 55}, type = "magic"}, {name = "Deep Pressure", damage = {30, 50}, type = "magic"}}},
        {id = "pirate_king", name = "Pirate King", hp = 180, atk = 35, def = 18, xp = 250, gold = 300, cr = 7,
         attacks = {{name = "King's Authority", damage = {28, 42}, type = "physical"}, {name = "Fleet Bombardment", damage = {32, 50}, type = "ranged"}, {name = "Plunder", damage = {24, 38}, type = "physical"}}},
        {id = "sea_dragon", name = "Sea Dragon", hp = 220, atk = 38, def = 22, xp = 350, gold = 220, cr = 9,
         attacks = {{name = "Steam Breath", damage = {35, 55}, type = "magic"}, {name = "Claw Rend", damage = {30, 46}, type = "physical"}, {name = "Whirlpool Dive", damage = {32, 50}, type = "magic"}}},
    }
}

-- ============================================================================
-- WATER EVENTS - Water tile event definitions
-- ============================================================================
Data.WATER_EVENTS = {
    -- Positive events
    {id = "merchant_ship", name = "Merchant Ship", chance = 0.08, type = "trade",
     message = "A merchant vessel hails you from across the waves!", color = {0.5, 0.8, 0.5}},
    {id = "floating_debris", name = "Floating Debris", chance = 0.06, type = "loot",
     message = "You spot debris floating in the water...", color = {0.6, 0.6, 0.4}},
    {id = "dolphin_pod", name = "Dolphin Pod", chance = 0.05, type = "buff",
     message = "A pod of dolphins guides your way! Navigation feels easier.", color = {0.4, 0.7, 0.9}},
    -- Dangerous events
    {id = "storm", name = "Sea Storm", chance = 0.07, type = "damage",
     message = "A violent storm strikes without warning!", color = {0.5, 0.5, 0.7}},
    {id = "whirlpool_event", name = "Sudden Whirlpool", chance = 0.04, type = "teleport",
     message = "A whirlpool opens beneath you!", color = {0.3, 0.4, 0.7}},
    {id = "siren_song", name = "Siren Song", chance = 0.03, type = "charm",
     message = "An enchanting melody drifts across the waves...", color = {0.7, 0.4, 0.7}},
    {id = "ghost_ship", name = "Ghost Ship", chance = 0.02, type = "combat",
     message = "A spectral ship materializes from the fog!", color = {0.6, 0.6, 0.8}},
    -- Rare events
    {id = "sea_treasure", name = "Sunken Treasure", chance = 0.02, type = "treasure",
     message = "You spot something glinting beneath the waves!", color = {0.9, 0.8, 0.3}},
    {id = "message_bottle", name = "Message in a Bottle", chance = 0.03, type = "quest",
     message = "A sealed bottle bobs on the surface...", color = {0.6, 0.7, 0.5}},
}

-- ============================================================================
-- SEA MERCHANT GOODS - Sea merchant inventory
-- ============================================================================
Data.SEA_MERCHANT_GOODS = {
    {id = "nautical_chart", name = "Nautical Chart", price = 50, desc = "Reveals nearby ocean features"},
    {id = "diving_gear", name = "Diving Gear", price = 120, desc = "Reduces damage from water events"},
    {id = "ship_repair_kit", name = "Ship Repair Kit", price = 80, desc = "Restores 50 HP"},
    {id = "coral_charm", name = "Coral Charm", price = 200, desc = "Reduces sea encounter rate"},
    {id = "salt_rations", name = "Salt Rations", price = 30, desc = "Preserved food for long voyages"},
    {id = "kraken_repellent", name = "Kraken Repellent", price = 500, desc = "Prevents boss encounters at sea"},
    {id = "mermaid_scale", name = "Mermaid Scale", price = 350, desc = "Increases fishing luck at sea"},
    {id = "storm_lantern", name = "Storm Lantern", price = 150, desc = "Reduces storm damage by half"},
}

-- ============================================================================
-- DEBRIS LOOT - Debris loot table
-- ============================================================================
Data.DEBRIS_LOOT = {
    {name = "Waterlogged Chest", gold = {20, 80}, chance = 0.3},
    {name = "Barnacle-Covered Sword", gold = {10, 30}, xp = 15, chance = 0.2},
    {name = "Driftwood Bundle", gold = {5, 15}, chance = 0.25},
    {name = "Sealed Barrel of Provisions", heal = {10, 30}, chance = 0.15},
    {name = "Navigator's Lost Compass", gold = {40, 100}, chance = 0.08},
    {name = "Pearl Oyster", gold = {60, 150}, chance = 0.02},
}

-- ============================================================================
-- MAX LEVEL
-- ============================================================================
Data.MAX_LEVEL = 100

-- ============================================================================
-- NPC TEMPLATES - NPC profession templates
-- ============================================================================
Data.NPC_TEMPLATES = {
    shopkeeper = {
        profession = "shopkeeper",
        names = {"Harold", "Margaret", "Thomas", "Eleanor", "William", "Catherine"},
        sprite = "🧑‍💼",
        dialogue = {
            greeting = "Welcome to my shop! How can I help you?",
            options = {
                {text = "Browse wares", action = "shop"},
                {text = "Chat", action = "chat", responses = {
                    "Business has been good lately.",
                    "I get my supplies from traveling merchants.",
                    "Let me know if you need anything!",
                }},
            }
        }
    },
    blacksmith = {
        profession = "blacksmith",
        names = {"Gareth", "Brunhilda", "Thorgrim", "Astrid", "Marcus"},
        sprite = "🔨",
        dialogue = {
            greeting = "Welcome to the forge. Need some work done?",
            options = {
                {text = "Work at forge", action = "forge"},
                {text = "Chat", action = "chat", responses = {
                    "The fire must stay hot to work the metal.",
                    "I learned this trade from my father.",
                    "A good blade can save your life.",
                }},
            }
        }
    },
    priest = {
        profession = "priest",
        names = {"Father Benedict", "Sister Miriam", "Father Aldric", "Sister Elara"},
        sprite = "⛪",
        dialogue = {
            greeting = "May the light guide you, child.",
            options = {
                {text = "Request blessing", action = "blessing"},
                {text = "Pray", action = "chat", responses = {
                    "The divine watches over us all.",
                    "Faith is the shield against darkness.",
                    "I pray for the safety of this town.",
                }},
            }
        }
    },
    tavernkeep = {
        profession = "tavernkeep",
        names = {"Barley", "Rosie", "Finn", "Mabel", "Duncan"},
        sprite = "🍺",
        dialogue = {
            greeting = "Welcome, friend! Pull up a chair!",
            options = {
                {text = "Chat", action = "chat", responses = {
                    "I hear all the best gossip in here.",
                    "Fresh ale every day!",
                    "Travelers come through with interesting stories.",
                }},
            }
        }
    },
    stablemaster = {
        profession = "stablemaster",
        names = {"Roland", "Beatrice", "Garrett", "Hilda"},
        sprite = "🐴",
        dialogue = {
            greeting = "Looking for a mount or transport?",
            options = {
                {text = "View mounts", action = "stable"},
                {text = "Chat", action = "chat", responses = {
                    "I raise the finest horses in the region.",
                    "A good mount can make all the difference.",
                    "These animals are well cared for.",
                }},
            }
        }
    },
    alchemist = {
        profession = "alchemist",
        names = {"Paracelsus", "Morgana", "Albertus", "Rowena"},
        sprite = "⚗️",
        dialogue = {
            greeting = "Ah, interested in the alchemical arts?",
            options = {
                {text = "Work at lab", action = "alchemist"},
                {text = "Chat", action = "chat", responses = {
                    "The transmutation of base metals... fascinating.",
                    "Each reagent has unique properties.",
                    "Precision is key in this craft.",
                }},
            }
        }
    },
    wizard = {
        profession = "wizard",
        names = {"Merlin", "Morgause", "Gandor", "Thessaly", "Aramis"},
        sprite = "🧙",
        dialogue = {
            greeting = "Welcome to my tower. Seek arcane knowledge?",
            options = {
                {text = "Work on spells", action = "wizardtower"},
                {text = "Chat", action = "chat", responses = {
                    "Magic flows through all things.",
                    "The ancient texts hold great secrets.",
                    "Be careful what powers you invoke.",
                }},
            }
        }
    },
    fisher = {
        profession = "fisher",
        names = {"Jonah", "Marina", "Fisher", "Pearl"},
        sprite = "🎣",
        dialogue = {
            greeting = "The fish are biting today!",
            options = {
                {text = "Go fishing", action = "fishing"},
                {text = "Chat", action = "chat", responses = {
                    "Patience is the fisherman's virtue.",
                    "The river provides for those who wait.",
                    "Best spot is just past the old pier.",
                }},
            }
        }
    },
    hunter = {
        profession = "hunter",
        names = {"Ranger", "Diana", "Orion", "Artemis"},
        sprite = "🏹",
        dialogue = {
            greeting = "Hunter's lodge - best game in the land!",
            options = {
                {text = "Go hunting", action = "hunting"},
                {text = "Chat", action = "chat", responses = {
                    "Track your prey, move silently.",
                    "The forest is full of game.",
                    "I've hunted these woods for years.",
                }},
            }
        }
    },
    merchant = {
        profession = "merchant",
        names = {"Cosimo", "Venetia", "Lorenzo", "Medici"},
        sprite = "💰",
        dialogue = {
            greeting = "Looking to trade goods or stocks?",
            options = {
                {text = "Trading post", action = "stockmarket"},
                {text = "Chat", action = "chat", responses = {
                    "Buy low, sell high - that's the secret!",
                    "Markets fluctuate based on supply and demand.",
                    "I deal in commodities from across the land.",
                }},
            }
        }
    },
    butcher = {
        profession = "butcher",
        names = {"Butch", "Helga", "Cleaver", "Bertha"},
        sprite = "🔪",
        dialogue = {
            greeting = "Fresh cuts today! What'll it be?",
            options = {
                {text = "Browse meats", action = "shop", shopType = "butcher"},
                {text = "Chat", action = "chat", responses = {
                    "Only the finest cuts here.",
                    "Fresh delivery every morning.",
                    "A good steak can lift anyone's spirits.",
                }},
            }
        }
    },
    baker = {
        profession = "baker",
        names = {"Baker", "Flour", "Crust", "Yeastly"},
        sprite = "🥖",
        dialogue = {
            greeting = "Fresh from the oven! Care for some bread?",
            options = {
                {text = "Browse goods", action = "shop", shopType = "bakery"},
                {text = "Chat", action = "chat", responses = {
                    "The secret is in the kneading.",
                    "Been baking since before dawn!",
                    "Nothing beats fresh bread.",
                }},
            }
        }
    },
    tailor = {
        profession = "tailor",
        names = {"Stitch", "Fabric", "Seam", "Velvet"},
        sprite = "🧵",
        dialogue = {
            greeting = "Looking for fine clothing?",
            options = {
                {text = "Browse clothes", action = "shop", shopType = "tailor"},
                {text = "Chat", action = "chat", responses = {
                    "Every garment is made with care.",
                    "Fashion is my passion!",
                    "I can tailor anything to fit.",
                }},
            }
        }
    },
    jeweler = {
        profession = "jeweler",
        names = {"Ruby", "Sapphire", "Diamond", "Emerald"},
        sprite = "💎",
        dialogue = {
            greeting = "Exquisite gems and jewelry here!",
            options = {
                {text = "Browse jewelry", action = "shop", shopType = "jeweler"},
                {text = "Chat", action = "chat", responses = {
                    "Each gem is carefully selected.",
                    "Jewelry is an investment.",
                    "The craftsmanship speaks for itself.",
                }},
            }
        }
    },
    wellkeeper = {
        profession = "wellkeeper",
        names = {"Wells", "Bucket", "Aqua", "Spring"},
        sprite = "🪣",
        dialogue = {
            greeting = "Fresh water from the town well!",
            options = {
                {text = "Draw water", action = "water"},
                {text = "Chat", action = "chat", responses = {
                    "The well has never run dry.",
                    "Cleanest water in the region!",
                    "Been maintaining this well for years.",
                }},
            }
        }
    },
    land_commissioner = {
        profession = "land_commissioner",
        names = {"Commissioner Harland", "Commissioner Thane", "Commissioner Aldara", "Commissioner Brennan"},
        sprite = "📜",
        dialogue = {
            greeting = "Welcome to the Land Office. I oversee all land expansion permits in this region.",
            options = {
                {text = "Purchase expansion permit", action = "land_office_permit"},
                {text = "View expansion rules", action = "land_office_rules"},
                {text = "Check permit status", action = "land_office_status"},
                {text = "Chat", action = "chat", responses = {
                    "Every plot of land must be properly documented.",
                    "Expansion requires permits - it keeps the realm orderly.",
                    "The Crown demands proper records of all land holdings.",
                    "I have overseen hundreds of land expansions in my career.",
                }},
            }
        }
    },
}

return Data
