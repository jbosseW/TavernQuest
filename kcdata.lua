-- Knowledge Center Data
-- Comprehensive encyclopedia for Tavern Quest: A Tale of Tavern Times
-- This file contains all knowledge entries organized by section

local KCData = {}

-- ==================== SECTION DEFINITIONS ====================
KCData.sections = {
    {id = "tutorials", name = "Tutorials", icon = "T"},
    {id = "glossary", name = "Glossary", icon = "G"},
    {id = "mechanics", name = "Mechanics", icon = "M"},
    {id = "bestiary", name = "Bestiary", icon = "B"},
    {id = "minigames", name = "Minigames", icon = "P"},
    {id = "items", name = "Items", icon = "I"},
    {id = "controls", name = "Controls", icon = "C"},
    {id = "lore", name = "Lore", icon = "L"},
}

-- ==================== ENTRY DATA ====================
KCData.entries = {

    -- ==================== MECHANICS SECTION ====================
    mechanics = {
        {
            id = "tension_system",
            title = "Tension System",
            tags = {"fishing", "combat"},
            content = [=[
The TENSION SYSTEM appears in fishing and represents line stress.

HOW IT WORKS:
• Tension builds when reeling with a fish on the line
• Tension decreases when matching fish direction
• Too much tension breaks your line!

WHAT AFFECTS TENSION:
• Reeling: +8 tension per second
• Wrong direction: +25 tension per second
• Matching direction: -12 tension per second
• Perfect reel hit: -15 tension instantly

TIPS:
• Watch the tension bar color (green→yellow→red)
• Better rods have higher max tension
• Don't panic-reel when tension is high

See [[link:direction_matching|Direction Matching]] for complementary mechanics.
            ]=],
            links = {"direction_matching", "perfect_windows"},
        },
        {
            id = "direction_matching",
            title = "Direction Matching",
            tags = {"fishing"},
            content = [=[
When a fish is hooked, it pulls LEFT or RIGHT.

HOW TO MATCH:
• Watch the direction indicator on screen
• Press [←] when fish pulls LEFT
• Press [→] when fish pulls RIGHT
• NEUTRAL means no direction bonus needed

BENEFITS OF MATCHING:
• Reduces tension by 12/second
• Drains fish stamina by (8 + combo×2)/second
• Prevents tension spikes

WRONG DIRECTION PENALTY:
• Tension increases 25/second × fish strength
• You'll see red warning indicators

Master this alongside the [[link:tension_system|Tension System]] for success.
            ]=],
            links = {"tension_system", "fish_stamina"},
        },
        {
            id = "perfect_windows",
            title = "Perfect Timing Windows",
            tags = {"fishing", "timing"},
            content = [=[
Perfect windows appear randomly while fishing with a hooked fish.

HOW IT WORKS:
• Green "✨ SPACE NOW! ✨" appears
• Window lasts only 0.6 seconds
• Press [SPACE] during window for bonus

REWARDS FOR HITTING:
• -15 tension instantly
• -18 fish stamina
• +1 to combo counter
• Screen shake and "PERFECT!" popup

MISSING THE WINDOW:
• Combo counter decreases by 1
• No penalty otherwise

SPAWN RATE:
• 15-35% chance per second
• Stronger fish = more frequent windows

Build your [[link:combo_system|Combo System]] through perfect hits!
            ]=],
            links = {"combo_system", "tension_system"},
        },
        {
            id = "combo_system",
            title = "Combo System",
            tags = {"fishing", "combat"},
            content = [=[
Build combos by chaining perfect reel hits!

HOW COMBOS WORK:
• Start at 0
• +1 for each perfect window hit
• -1 if window expires without hit
• Resets to 0 if fish escapes

COMBO BONUSES:
• Higher combo = bigger screen shake
• Stamina drain bonus: +2 per combo level
• Visual "COMBO x#" display grows

STRATEGY:
• Focus on hitting every perfect window
• High combos make big fish easier
• Don't sacrifice tension management for combos

Works with [[link:perfect_windows|Perfect Windows]] mechanic.
            ]=],
            links = {"perfect_windows"},
        },
        {
            id = "fish_stamina",
            title = "Fish Stamina",
            tags = {"fishing"},
            content = [=[
Fish have stamina that affects how hard they fight.

STAMINA BAR:
• Cyan bar shows remaining stamina
• Turns red when below 25%
• Fish with 0 stamina are easier to catch

HOW STAMINA DRAINS:
• Reeling with matched direction
• Perfect reel window hits (-18)
• Natural drain when direction matched

FISH STAMINA VALUES:
• Common fish: 60-80 stamina
• Rare fish: 80-120 stamina
• Legendary: 150+ stamina
• Fight strength affects drain resistance

See individual fish in the [[link:bestiary|Bestiary]] for specific values.
            ]=],
            links = {"direction_matching"},
        },
        {
            id = "quality_tiers",
            title = "Quality Tiers",
            tags = {"items", "crafting", "fishing"},
            content = [=[
Items and creatures come in quality tiers.

TIER PROGRESSION:
• Common (gray) - Base stats, 1x value
• Uncommon (green) - +20% stats, 1.5x value
• Rare (blue) - +50% stats, 2x value
• Epic (purple) - +100% stats, 3x value
• Legendary (gold) - +200% stats, 5x value
• Mythic (red) - +400% stats, 6x value

CRAFTING QUALITY:
• Affected by heat/mana charge
• Perfect execution = Masterwork (+25%)

FISHING TIERS:
• Determines fish value and XP reward
• Rarer tiers spawn at deeper depths

See [[link:crafting_quality|Crafting Quality]] for details on improving output.
            ]=],
            links = {"crafting_quality"},
        },
        {
            id = "trophy_variants",
            title = "Trophy Variants",
            tags = {"fishing", "hunting"},
            content = [=[
Trophy variants are special rare versions of catches.

FISHING TROPHIES:
• 5% chance on any fish bite
• "Trophy", "Lunker", "Giant" prefix
• 1.5x normal weight
• 2x value multiplier
• Special golden display

HUNTING TROPHIES:
• Certain animals are trophy-worthy
• Can be displayed for bonuses
• Legendary creatures always trophies

IDENTIFYING TROPHIES:
• ★ symbol in catch display
• Special notification on catch
• Recorded in journal with best weight

Trophy catches grant bonus [[link:xp_leveling|XP]].
            ]=],
            links = {"xp_leveling"},
        },
        {
            id = "xp_leveling",
            title = "XP and Leveling",
            tags = {"progression"},
            content = [=[
Gain experience points (XP) to level up!

XP SOURCES:
• Catching fish (10-100 based on tier)
• Crafting items
• Completing quests
• Winning battles

LEVEL UP REWARDS:
• +1 Skill point (for skill trees)
• Stat increases
• Unlock new content
• Talent selection at 3, 6, 9, 12...

XP BONUSES:
• Fishing Instructor employee: +XP%
• Trophy catches: +50% XP
• First-time catches: Bonus XP

Level up to unlock better [[link:employee_system|Employees]].
            ]=],
            links = {"employee_system"},
        },
        {
            id = "employee_system",
            title = "Employee System",
            tags = {"business", "passive"},
            content = [=[
Hire employees to help with your activities!

HOW IT WORKS:
• Press [E] in most minigames
• Employees generate passive income
• Different employee types for each activity

EMPLOYEE BONUSES:
• Fishing: Better catch rates, value bonus
• Crafting: Speed bonus, quality bonus
• General: Gold per second

EMPLOYEE STATS:
• Efficiency - Work output rate
• Cost - Hiring price
• Specialization - Bonus type

TIPS:
• Higher skill = better employee pool
• Employees work even when offline
• Check employee panels regularly

Employees boost [[link:passive_income|Passive Income]] generation.
            ]=],
            links = {"passive_income"},
        },
        {
            id = "passive_income",
            title = "Passive Income",
            tags = {"business", "gold"},
            content = [=[
Generate gold while you're away or doing other activities!

SOURCES:
• Employees working in background
• Tavern customers (when staffed)
• Fishing spots with employees
• Crafting stations with workers
• Pet ranching operations

MECHANICS:
• Income accumulates up to 12 hours offline
• Rate depends on employee efficiency
• Upgrades multiply base income
• Some sources require active setup

OPTIMIZATION:
• Hire high-efficiency employees
• Upgrade production stations
• Balance between active and passive play
• Check back regularly to collect

Hire through the [[link:employee_system|Employee System]].
            ]=],
            links = {"employee_system"},
        },
        {
            id = "crafting_quality",
            title = "Crafting Quality",
            tags = {"crafting", "items"},
            content = [=[
Every crafted item has a quality level based on execution.

QUALITY FACTORS:
• Phase performance (Alchemy: prep, pour, heat, distill)
• Heat management (Forge: temperature control)
• Timing precision (Perfect phases)
• Recipe difficulty modifier

QUALITY LEVELS:
• Poor - Below 30% performance
• Normal - 30-60% performance
• Fine - 60-85% performance
• Superior - 85-95% performance
• Masterwork - 95%+ performance (adds +25% stats)

BENEFITS:
• Higher quality = better stats
• Increased sale value
• Crafting XP bonus
• Unlock achievements

Related to [[link:quality_tiers|Quality Tiers]] system.
            ]=],
            links = {"quality_tiers"},
        },
        {
            id = "combat_stats",
            title = "Combat Stats",
            tags = {"combat", "stats"},
            content = [=[
Seven primary stats govern combat effectiveness.

PRIMARY STATS:
• Might - Physical damage, carry weight
• Agility - Dodge, critical chance, initiative
• Vigor - Health points, stamina
• Mind - Mana points, spell power
• Spirit - Mana regen, magic defense
• Presence - Leadership, intimidation
• Faith - Divine magic, healing power

DERIVED STATS:
• HP = Vigor × 10
• MP = Mind × 8
• Defense = (Vigor + Agility) / 2
• Critical = Agility / 5
• Spell Power = Mind + (Faith / 2)

STAT GROWTH:
• Base stats from race
• +Points per level
• Equipment bonuses
• Consumable buffs

See [[link:elemental_system|Elemental System]] for damage types.
            ]=],
            links = {"elemental_system"},
        },
        {
            id = "elemental_system",
            title = "Elemental System",
            tags = {"combat", "magic"},
            content = [=[
Six elements govern magical affinities and resistances.

ELEMENTS:
• Flame - High damage, burning DOT
• Aqua - Healing, water control
• Terra - Defense, stone barriers
• Volt - Speed, chain lightning
• Shadow - Stealth, life drain
• Light - Holy, undead damage

INTERACTIONS:
• Flame > Terra > Volt > Aqua > Flame
• Light <> Shadow (opposed)
• Resistances reduce damage by %
• Weaknesses increase damage taken

APPLICATIONS:
• Spell damage types
• Pet affinities (see [[link:petsim_overview|Wilds Rancher]])
• Equipment enchantments
• Crafting materials

STACKING:
• Multiple elements on one character possible
• Diminishing returns on same element
            ]=],
            links = {"petsim_overview"},
        },
        {
            id = "mount_system",
            title = "Mount System",
            tags = {"travel", "pets"},
            content = [=[
Tame creatures to ride across the world faster!

OBTAINING MOUNTS:
• Evolve pets in Wilds Rancher
• Tame wild creatures in hunting
• Quest rewards
• Special event mounts

MOUNT TYPES:
• Land Mounts - 2x movement speed
• Flying Mounts - 4x speed, can cross terrain
• Aquatic Mounts - Water travel
• Special Mounts - Unique bonuses

MOUNT ABILITIES:
• Some mounts grant combat bonuses
• Storage capacity increases
• Environmental resistances
• Passive stat buffs

CARE:
• Mounts don't need feeding
• Can be summoned/dismissed
• Cosmetic customization available

Train mounts through [[link:petsim_overview|Wilds Rancher]].
            ]=],
            links = {"petsim_overview"},
        },
        {
            id = "reputation_system",
            title = "Reputation System",
            tags = {"social", "progression"},
            content = [=[
Build reputation with various factions for rewards!

MAJOR FACTIONS:
• Tavern Keepers Guild - Business bonuses
• Hunters Lodge - Hunting rewards
• Mage Circle - Spell access
• Merchant Coalition - Trading discounts
• Local Towns - Quest unlocks

REPUTATION LEVELS:
• Hostile - Attacked on sight
• Unfriendly - Poor prices, no quests
• Neutral - Standard interaction
• Friendly - 10% discount, basic quests
• Honored - 20% discount, rare items
• Revered - 30% discount, unique rewards
• Exalted - Maximum benefits, special titles

GAINING REPUTATION:
• Complete faction quests
• Donate materials
• Perform faction activities
• Wear faction tabards

BENEFITS:
• Unlock unique merchants
• Access to faction-specific gear
• Special mounts and pets
• Exclusive crafting recipes
            ]=],
        },
    },

    -- ==================== BESTIARY SECTION ====================
    bestiary = {
        -- FISH CATEGORY
        {
            id = "fish_pond_trout",
            title = "Pond Trout",
            tags = {"fish", "common", "pond"},
            discoverable = true,
            content = [=[
A small, silvery fish common in still waters.

DESCRIPTION:
The pond trout is the most common catch for beginning
anglers. Its scales shimmer with pale blue-green hues,
and it puts up minimal resistance when hooked.

HABITAT: Pond, shallow lakes
RARITY: Common
STAMINA: 60-70
FIGHT STRENGTH: 1.0x (Weak)

LOOT:
• Fish Meat (100%)
• Fish Bones (60%)
• Scales (30%)

CATCH INFO:
Best caught with basic bait at shallow depths.
Perfect for learning the [[link:tension_system|Tension System]].
            ]=],
            links = {"tension_system"},
        },
        {
            id = "fish_river_salmon",
            title = "River Salmon",
            tags = {"fish", "uncommon", "river"},
            discoverable = true,
            content = [=[
A powerful swimmer with distinctive pink flesh.

DESCRIPTION:
River salmon migrate upstream to spawn, making them
strong fighters. Their orange-pink flesh is prized
for cooking. They require careful tension management.

HABITAT: Rivers, rapids
RARITY: Uncommon
STAMINA: 85-95
FIGHT STRENGTH: 1.3x (Moderate)

LOOT:
• Salmon Meat (100%) - Used in recipes
• Quality Scales (80%)
• Fish Oil (40%)

CATCH INFO:
Found in flowing water. Watch for direction changes!
Provides good [[link:xp_leveling|XP]] for mid-level anglers.
            ]=],
            links = {"xp_leveling"},
        },
        {
            id = "fish_lake_bass",
            title = "Lake Bass",
            tags = {"fish", "uncommon", "lake"},
            discoverable = true,
            content = [=[
A cunning predator with dark green scales.

DESCRIPTION:
Lake bass are intelligent hunters that test an
angler's skill. They're known for sudden direction
reversals and bursts of strength. Trophy specimens
can reach impressive sizes.

HABITAT: Deep lakes, coastal waters
RARITY: Uncommon
STAMINA: 90-100
FIGHT STRENGTH: 1.4x (Moderate)

LOOT:
• Bass Meat (100%)
• Sturdy Scales (70%)
• Sharp Fins (50%)

CATCH INFO:
Requires good [[link:direction_matching|Direction Matching]].
5% chance for Trophy variant (★).
            ]=],
            links = {"direction_matching", "trophy_variants"},
        },
        {
            id = "fish_ocean_tuna",
            title = "Ocean Tuna",
            tags = {"fish", "rare", "ocean"},
            discoverable = true,
            content = [=[
A massive, muscular fish of the open ocean.

DESCRIPTION:
Ocean tuna are apex swimmers capable of incredible
speed and endurance. Their battles can last minutes,
testing even experienced anglers. Their meat is highly
valued in tavern cooking.

HABITAT: Deep ocean waters
RARITY: Rare
STAMINA: 120-140
FIGHT STRENGTH: 1.8x (Strong)

LOOT:
• Premium Tuna Meat (100%)
• Iridescent Scales (60%)
• Fish Oil (80%)

CATCH INFO:
Requires upgraded rod and deep-sea bait.
High [[link:combo_system|Combo]] recommended for success.
            ]=],
            links = {"combo_system"},
        },
        {
            id = "fish_midnight_eel",
            title = "Midnight Eel",
            tags = {"fish", "rare", "nocturnal"},
            discoverable = true,
            content = [=[
A serpentine shadow that hunts in darkness.

DESCRIPTION:
These mysterious eels only appear at night, their
bodies crackling with faint bioelectricity. They're
incredibly slippery fighters that frequently change
direction unpredictably.

HABITAT: Ocean depths, only at night
RARITY: Rare
STAMINA: 110-130
FIGHT STRENGTH: 1.6x (Strong)

LOOT:
• Eel Meat (100%)
• Volt Essence (70%)
• Strange Mucus (50%) - Alchemy ingredient

CATCH INFO:
Night fishing only. Erratic patterns require focus.
            ]=],
        },
        {
            id = "fish_storm_leviathan",
            title = "Storm Leviathan",
            tags = {"fish", "legendary", "ocean"},
            discoverable = true,
            content = [=[
A legendary beast said to command storms.

DESCRIPTION:
This colossal fish appears only during ocean storms,
its massive form wreathed in lightning. Ancient
sailors' tales claim it can sink ships. Landing one
is the mark of a master angler.

HABITAT: Deep ocean during storms
RARITY: Legendary
STAMINA: 180-200
FIGHT STRENGTH: 2.5x (Extreme)

LOOT:
• Leviathan Steak (100%)
• Storm Scales (100%)
• Lightning Core (80%) - Valuable crafting material
• Titan's Tooth (30%)

CATCH INFO:
Requires master-tier rod and storm-proof line.
Grants massive [[link:xp_leveling|XP]] and achievement.
            ]=],
            links = {"xp_leveling"},
        },
        {
            id = "fish_sea_dragon",
            title = "Sea Dragon",
            tags = {"fish", "mythic", "dragon"},
            discoverable = true,
            content = [=[
A mythical aquatic dragon of incomprehensible power.

DESCRIPTION:
Scholars debate whether sea dragons are fish, reptiles,
or something beyond classification. Their scales shimmer
with all colors of the ocean. Only a handful have ever
been caught. Some claim they allow themselves to be
hooked to test worthy souls.

HABITAT: Abyssal trenches, legendary spawns
RARITY: Mythic
STAMINA: 250+
FIGHT STRENGTH: 3.5x (Legendary)

LOOT:
• Dragon Scale (100%) - Priceless crafting material
• Aqua Dragon Heart (100%)
• Ancient Treasure (60%)
• Mythic Trophy Mount (100%)

CATCH INFO:
Requires perfect execution of all mechanics.
Permanently recorded in Hall of Legends.
            ]=],
        },

        -- GAME ANIMALS CATEGORY
        {
            id = "animal_forest_rabbit",
            title = "Forest Rabbit",
            tags = {"animal", "common", "small_game"},
            discoverable = true,
            content = [=[
A quick, timid creature of the woods.

DESCRIPTION:
Forest rabbits are common prey for beginning hunters.
They're fast and alert, requiring careful aim. Their
soft fur is useful for crafting.

HABITAT: Forests, meadows
RARITY: Common
SPEED: Fast
DIFFICULTY: Easy

LOOT:
• Rabbit Meat (100%)
• Soft Fur (80%)
• Lucky Rabbit's Foot (5%)

HUNTING INFO:
Lead your shot to account for movement.
Good target for learning wind mechanics.
            ]=],
        },
        {
            id = "animal_wild_boar",
            title = "Wild Boar",
            tags = {"animal", "uncommon", "medium_game"},
            discoverable = true,
            content = [=[
An aggressive tusked beast of the forest.

DESCRIPTION:
Wild boars are dangerous prey that may charge if
wounded. Their thick hide requires precise shots,
and their meat is hearty and valuable. Approach
with caution.

HABITAT: Dense forests, hills
RARITY: Uncommon
SPEED: Moderate
DIFFICULTY: Moderate

LOOT:
• Boar Meat (100%)
• Thick Hide (90%)
• Boar Tusks (70%)
• Coarse Bristles (50%)

HUNTING INFO:
Aim for vital areas. Wounded boars become aggressive.
Can be [[link:trophy_variants|Trophy]] quality.
            ]=],
            links = {"trophy_variants"},
        },
        {
            id = "animal_mountain_elk",
            title = "Mountain Elk",
            tags = {"animal", "rare", "large_game"},
            discoverable = true,
            content = [=[
A majestic creature of highland regions.

DESCRIPTION:
Mountain elk are noble animals with impressive antlers.
Hunting them requires skill and respect. Their antlers
are valuable crafting materials, and their venison is
among the finest meat available.

HABITAT: Mountain ranges, high forests
RARITY: Rare
SPEED: Moderate
DIFFICULTY: Hard

LOOT:
• Elk Venison (100%)
• Quality Pelt (85%)
• Elk Antlers (90%)
• Sinew (60%)

HUNTING INFO:
High-altitude hunting. Clean kills grant bonus value.
Trophy elk have magnificent antler racks.
            ]=],
        },
        {
            id = "animal_timber_wolf",
            title = "Timber Wolf",
            tags = {"animal", "rare", "predator"},
            discoverable = true,
            content = [=[
A cunning pack hunter of northern forests.

DESCRIPTION:
Timber wolves are dangerous predators that hunt in
coordinated packs. They're incredibly perceptive and
will flee at the slightest noise. Their pelts are
highly valued.

HABITAT: Northern forests, taiga
RARITY: Rare
SPEED: Very Fast
DIFFICULTY: Hard

LOOT:
• Wolf Meat (100%)
• Wolf Pelt (95%)
• Sharp Claws (80%)
• Wolf Fang (70%)

HUNTING INFO:
Keep noise meter low. Packs may have alpha (stronger).
Pelt quality depends on clean shot placement.
            ]=],
        },
        {
            id = "animal_great_bear",
            title = "Great Bear",
            tags = {"animal", "legendary", "large_game"},
            discoverable = true,
            content = [=[
A massive apex predator of the wilderness.

DESCRIPTION:
Great bears are among the most dangerous animals in
the realm. Standing over 10 feet tall, they possess
incredible strength and resilience. Only master
hunters dare track them.

HABITAT: Deep wilderness, mountain caves
RARITY: Legendary
SPEED: Slow but powerful
DIFFICULTY: Extreme

LOOT:
• Bear Meat (100%)
• Legendary Bear Pelt (100%)
• Bear Claws (100%)
• Bear Heart (80%) - Powerful alchemy ingredient
• Bear Skull Trophy (100%)

HUNTING INFO:
Requires powerful bow and perfect shot placement.
Always spawns as Trophy quality. Highly dangerous.
            ]=],
        },
        {
            id = "animal_white_stag",
            title = "White Stag",
            tags = {"animal", "mythic", "legendary"},
            discoverable = true,
            content = [=[
A mystical creature of ancient legend.

DESCRIPTION:
The White Stag appears only to those fate has chosen.
Its pure white coat seems to glow with inner light,
and it moves with supernatural grace. Many hunters
spend entire lifetimes searching without a single
sighting. Some say harvesting it brings a curse;
others claim it grants blessings.

HABITAT: Sacred groves, moonlit clearings (random)
RARITY: Mythic
SPEED: Ethereal
DIFFICULTY: Legendary

LOOT:
• Blessed Venison (100%) - Legendary consumable
• White Stag Pelt (100%) - Legendary crafting
• Antlers of Light (100%)
• Tear of the Stag (50%) - Unique alchemy component

HUNTING INFO:
Appears randomly. One shot only—it vanishes if missed.
Grants permanent achievement and special title.
Some refuse to hunt it on principle.
            ]=],
        },

        -- MONSTERS CATEGORY
        {
            id = "monster_slime",
            title = "Slime",
            tags = {"monster", "common", "blob"},
            discoverable = true,
            content = [=[
A gelatinous creature that absorbs nutrients.

DESCRIPTION:
Slimes are simple monsters that ooze through dungeons
and damp areas. Despite their weak combat ability,
they're resistant to physical damage and can surprise
unwary adventurers by splitting when damaged.

HABITAT: Caves, sewers, dungeons
RARITY: Common
LEVEL: 1-5
DIFFICULTY: Easy

LOOT:
• Slime Gel (100%)
• Slime Core (25%)
• Absorbed Items (random)

COMBAT INFO:
Low health but physical resistance. Use magic or fire.
Good for beginner [[link:combat_stats|combat]] practice.
            ]=],
            links = {"combat_stats"},
        },
        {
            id = "monster_giant_spider",
            title = "Giant Spider",
            tags = {"monster", "uncommon", "arachnid"},
            discoverable = true,
            content = [=[
An oversized arachnid with venomous bite.

DESCRIPTION:
Giant spiders lurk in forests and caves, spinning
webs to trap prey. Their venom can paralyze victims,
and they attack with surprising speed. Their silk is
valuable for crafting.

HABITAT: Forests, caves, ruins
RARITY: Uncommon
LEVEL: 6-12
DIFFICULTY: Moderate

LOOT:
• Spider Silk (90%)
• Venom Sac (70%)
• Chitin (60%)
• Spider Eye (40%)

COMBAT INFO:
Fast attacks. Poison damage over time. High dodge.
Weak to fire [[link:elemental_system|element]].
            ]=],
            links = {"elemental_system"},
        },
        {
            id = "monster_skeleton_warrior",
            title = "Skeleton Warrior",
            tags = {"monster", "uncommon", "undead"},
            discoverable = true,
            content = [=[
An animated skeleton wielding ancient weapons.

DESCRIPTION:
These undead warriors guard forgotten tombs and
cursed battlefields. Though they lack flesh, they
fight with eerie precision, wielding rusted weapons
with deadly intent. Holy magic is especially
effective against them.

HABITAT: Crypts, battlefields, ruins
RARITY: Uncommon
LEVEL: 8-15
DIFFICULTY: Moderate

LOOT:
• Ancient Bones (100%)
• Rusted Equipment (70%)
• Cursed Essence (40%)
• Skull Fragment (30%)

COMBAT INFO:
Undead type—weak to Light element and holy magic.
No bleeding. Can reassemble if not fully destroyed.
            ]=],
        },
        {
            id = "monster_shadow_drake",
            title = "Shadow Drake",
            tags = {"monster", "rare", "dragon"},
            discoverable = true,
            content = [=[
A lesser dragon wreathed in darkness.

DESCRIPTION:
Shadow drakes are distant cousins of true dragons,
though far less powerful. They hunt from the shadows,
breathing clouds of darkness that sap strength. Their
scales are valuable for enchanting.

HABITAT: Dark caves, shadow-cursed areas
RARITY: Rare
LEVEL: 20-28
DIFFICULTY: Hard

LOOT:
• Shadow Scales (95%)
• Drake Fang (80%)
• Shadow Essence (75%)
• Small Dragon Heart (40%)

COMBAT INFO:
Shadow breath causes blindness and damage over time.
Resistant to Shadow, weak to Light [[link:elemental_system|element]].
Can become invisible briefly.
            ]=],
            links = {"elemental_system"},
        },
        {
            id = "monster_fire_elemental",
            title = "Fire Elemental",
            tags = {"monster", "rare", "elemental"},
            discoverable = true,
            content = [=[
A living manifestation of flame.

DESCRIPTION:
Fire elementals are sentient flames given form by
magical convergence. They radiate intense heat and
ignite everything nearby. Water magic is essential
for combating them safely.

HABITAT: Volcanic regions, fire temples, magical rifts
RARITY: Rare
LEVEL: 25-32
DIFFICULTY: Hard

LOOT:
• Flame Core (100%)
• Burning Ash (90%)
• Fire Essence (85%)
• Eternal Ember (35%)

COMBAT INFO:
Immune to fire, weak to Aqua [[link:elemental_system|element]].
Melee attacks cause burning. Explodes when defeated.
            ]=],
            links = {"elemental_system"},
        },
        {
            id = "monster_demon_lord",
            title = "Demon Lord",
            tags = {"monster", "legendary", "boss"},
            discoverable = true,
            content = [=[
A powerful fiend from beyond the mortal realm.

DESCRIPTION:
Demon Lords are commanders of infernal armies, beings
of immense power and malice. They can only enter the
mortal realm through powerful summoning or when reality
weakens. Defeating one requires a full party of heroes
and exceptional coordination.

HABITAT: Demonic portals, corrupted temples, endgame
RARITY: Legendary
LEVEL: 45-50
DIFFICULTY: Extreme

LOOT:
• Demon Heart (100%)
• Infernal Armor Piece (90%)
• Legendary Weapon (80%)
• Soul Crystal (70%)
• Demon Lord Crown (30%) - Trophy

COMBAT INFO:
Multiple phases. Fire and Shadow attacks. Can summon
minions. Requires strategy and full [[link:combat_stats|combat stats]].
Massive XP and achievement reward.
            ]=],
            links = {"combat_stats"},
        },

        -- PETS CATEGORY
        {
            id = "pet_flame_pup",
            title = "Flame Pup",
            tags = {"pet", "flame", "common"},
            discoverable = true,
            content = [=[
A playful puppy wreathed in friendly fire.

DESCRIPTION:
Flame pups are one of the starter pets available in
Wilds Rancher. Despite being on fire, they're warm
and affectionate. They love to play and can evolve
into powerful flame mounts.

ELEMENT: Flame
RARITY: Common
BASE STATS: HP 80, ATK 12, DEF 8

EVOLUTION:
Flame Hound (Lv 10) → Inferno Wolf (Lv 25)
Final evolution becomes a rideable mount!

CARE NEEDS:
• Feed: Loves spicy food
• Play: Enjoys fetch and fire games
• Environment: Warm areas

ABILITIES:
• Ember Bite - Basic flame attack
• Warm Presence - Passive cold resistance

Available in [[link:petsim_overview|Wilds Rancher]].
            ]=],
            links = {"petsim_overview", "elemental_system"},
        },
        {
            id = "pet_aqua_kit",
            title = "Aqua Kit",
            tags = {"pet", "aqua", "common"},
            discoverable = true,
            content = [=[
A fox-like creature that swims through air.

DESCRIPTION:
Aqua kits are graceful creatures that control water
with innate magic. They can float and create small
water bubbles. Very gentle and healing-focused pets.

ELEMENT: Aqua
RARITY: Common
BASE STATS: HP 100, ATK 8, DEF 10

EVOLUTION:
Stream Fox (Lv 10) → Tidal Sage (Lv 25)
Final form grants water-walking ability!

CARE NEEDS:
• Feed: Fresh fish, water plants
• Play: Swimming, bubble games
• Environment: Near water

ABILITIES:
• Water Splash - Aqua attack
• Healing Mist - Restore HP over time

See [[link:mount_system|Mount System]] for riding evolved forms.
            ]=],
            links = {"petsim_overview", "mount_system"},
        },
        {
            id = "pet_terra_cub",
            title = "Terra Cub",
            tags = {"pet", "terra", "common"},
            discoverable = true,
            content = [=[
A sturdy bear cub with stone-like fur.

DESCRIPTION:
Terra cubs are incredibly resilient and loyal. Their
connection to earth makes them excellent defenders.
They love digging and collecting shiny stones.

ELEMENT: Terra
RARITY: Common
BASE STATS: HP 120, ATK 10, DEF 15

EVOLUTION:
Stone Bear (Lv 10) → Mountain Titan (Lv 25)
Final form becomes a massive rideable mount!

CARE NEEDS:
• Feed: Berries, roots, minerals
• Play: Digging, rock collecting
• Environment: Mountains, caves

ABILITIES:
• Stone Slam - High damage, slow
• Rock Shield - Boost defense temporarily

Tank-type pet from [[link:petsim_overview|Wilds Rancher]].
            ]=],
            links = {"petsim_overview"},
        },
        {
            id = "pet_volt_hatchling",
            title = "Volt Hatchling",
            tags = {"pet", "volt", "common"},
            discoverable = true,
            content = [=[
A small dragon crackling with electricity.

DESCRIPTION:
Volt hatchlings are energetic and fast. They can't
sit still, constantly zipping around. Their scales
generate static electricity that shocks everything
they touch (gently).

ELEMENT: Volt
RARITY: Common
BASE STATS: HP 70, ATK 15, DEF 6

EVOLUTION:
Lightning Drake (Lv 10) → Storm Dragon (Lv 25)
Final form is a FLYING mount with 4x speed!

CARE NEEDS:
• Feed: Charged crystals, stormy weather
• Play: Racing, aerial games
• Environment: Storms, high places

ABILITIES:
• Shock Strike - Fast volt attack
• Static Field - Chance to paralyze

Fastest pet type in [[link:petsim_overview|Wilds Rancher]].
            ]=],
            links = {"petsim_overview", "mount_system"},
        },
    },

    -- ==================== MINIGAMES SECTION ====================
    minigames = {
        {
            id = "fishing_overview",
            title = "Fishing",
            tags = {"minigame"},
            content = [=[
Relax and catch fish at various locations!

GAMEPLAY:
• Cast with [SPACE] - hold longer for deeper
• Reel with [SPACE] when fish bites
• Match direction with [←][→] arrows
• Hit perfect windows for combos

KEY MECHANICS:
• Tension management (see [[link:tension_system|Tension System]])
• Direction matching
• Fish stamina drain
• Perfect reel windows

PROGRESSION:
• Unlock new locations
• Buy better rods and bait
• Hire fishing employees
• Collect all fish species

LOCATIONS:
• Pond (starter) → River → Lake → Ocean

Check [[link:fishing_controls|Fishing Controls]] for full input reference.
            ]=],
            links = {"tension_system", "fishing_controls"},
        },
        {
            id = "alchemy_overview",
            title = "Alchemy",
            tags = {"minigame", "crafting"},
            content = [=[
Brew potions and poisons through interactive phases!

4 BREWING PHASES:
1. PREP - Chop ingredients with [SPACE]
2. POUR - Hold [SPACE] to fill, stop at 70-80%
3. HEAT - Pump bellows, keep heat at 60-70
4. DISTILL - Crank wheel with [SPACE]

RECIPES:
• Health/Mana potions
• Buff potions (strength, speed, defense)
• Poisons for weapons
• Rare elixirs

QUALITY:
• Each phase affects final quality
• Perfect phases = Masterwork (+25%)

Related to [[link:crafting_quality|Crafting Quality]] system.
See [[link:alchemy_ingredients|Alchemy Ingredients]] for materials.
            ]=],
            links = {"crafting_quality", "alchemy_ingredients"},
        },
        {
            id = "forge_overview",
            title = "Forge",
            tags = {"minigame", "crafting"},
            content = [=[
Craft weapons, armor, and traps!

GAMEPLAY:
• Select recipe from left panel
• Pump bellows with [SPACE]
• Keep heat in orange/red zone
• Higher heat = better quality

RECIPES:
• Weapons (swords, axes, bows)
• Armor (helmets, chest, boots)
• Traps (hunting, defense)

OUTPUT OPTIONS:
• Keep in backpack
• Sell immediately
• List on market

QUALITY TIERS:
• Normal → Fine → Superior → Masterwork

Crafting quality determines [[link:equipment_overview|Equipment]] stats.
            ]=],
            links = {"equipment_overview", "crafting_quality"},
        },
        {
            id = "textrpg_overview",
            title = "Tavern Quest RPG",
            tags = {"minigame", "adventure"},
            content = [=[
Fantasy text adventure!

CLASSES:
• Warrior - Tank, high damage
• Mage - Spells, area damage
• Rogue - Crits, evasion
• Cleric - Healing, buffs

FEATURES:
• Turn-based combat
• Skill trees per class
• Talents every 3 levels
• Equipment system
• Dungeon exploration
• Town shops and quests

STATS:
Might, Agility, Vigor, Mind, Spirit, Presence, Faith

See [[link:combat_stats|Combat Stats]] and [[link:combat_controls|Combat Controls]].
            ]=],
            links = {"combat_stats", "combat_controls"},
        },
        {
            id = "hunting_overview",
            title = "Hunting",
            tags = {"minigame"},
            content = [=[
Track and hunt wild game!

GAMEPLAY:
• Click to shoot arrows
• Account for wind effects
• Watch noise meter
• Different regions have different prey

PREY TIERS:
• Small game (rabbit, pheasant)
• Medium game (deer, boar, wolf)
• Large game (elk, bear)
• Legendary (white stag, great bear)

LOOT:
• Meat, hides, furs
• Bones, claws, antlers
• Rare crafting materials

Check Bestiary for specific animals like [[link:animal_wild_boar|Wild Boar]].
See [[link:hunting_controls|Hunting Controls]].
            ]=],
            links = {"hunting_controls"},
        },
        {
            id = "petsim_overview",
            title = "Wilds Rancher",
            tags = {"minigame"},
            content = [=[
Adopt, breed, and train creatures!

FEATURES:
• Adopt pets from shelter
• Feed, play, rest to care
• Train to increase stats
• Breed for new species

ELEMENTS:
Flame, Aqua, Terra, Volt, Shadow, Light

MOUNTS:
• Evolved pets become mounts
• Flying mounts (dragon, phoenix): 4x speed
• Land mounts: Normal traversal

EVOLUTION:
• Happy + healthy + trained = evolves
• Evolved pets are stronger

See [[link:elemental_system|Elemental System]] for element interactions.
Mounts explained in [[link:mount_system|Mount System]].
            ]=],
            links = {"elemental_system", "mount_system"},
        },
        {
            id = "cafegame_overview",
            title = "Tavern Work",
            tags = {"minigame"},
            content = [=[
Serve customers at the tavern!

GAMEPLAY:
• Customers arrive with orders
• Click menu items to prepare
• Serve before patience runs out
• Earn tips for fast service

CUSTOMER TYPES:
• Peasants - Patient, low tips
• Merchants - Medium patience
• Knights/Nobles - Impatient, high tips
• Elves/Dwarves - Special bonuses

UPGRADES:
• Tray size, prep speed
• Auto-chef helper
• Better tips and patience

TIPS:
• Prioritize high-value customers
• Upgrade early for better flow
• Combo orders for bonus tips

Contributes to [[link:passive_income|Passive Income]].
            ]=],
            links = {"passive_income"},
        },
        {
            id = "stockmarket_overview",
            title = "Stock Market",
            tags = {"minigame", "trading"},
            content = [=[
Trade commodities and speculate on market trends!

GAMEPLAY:
• Buy and sell resource stocks
• Prices fluctuate based on supply/demand
• News events affect prices
• Historical charts help predict trends

COMMODITY TYPES:
• Raw Materials (ore, wood, stone)
• Food Goods (grain, meat, fish)
• Luxury Items (gems, silk, spices)
• Magical Reagents (mana crystals, essences)

MECHANICS:
• Buy low, sell high
• Events cause price spikes/crashes
• Seasonal trends affect certain goods
• Portfolio diversification recommended

STRATEGIES:
• Watch for event announcements
• Track seasonal patterns
• Don't invest everything in one stock
• Long-term holding can be profitable

RISKS:
• Market can crash unexpectedly
• Speculation is not guaranteed profit
• Balance with stable [[link:passive_income|Passive Income]].
            ]=],
            links = {"passive_income"},
        },
        {
            id = "deckbuilder_overview",
            title = "Card Battles",
            tags = {"minigame", "strategy"},
            content = [=[
Strategic card battling minigame!

GAMEPLAY:
• Build a deck of 30 cards
• Draw 5 cards each turn
• Play cards using mana
• Reduce opponent's HP to 0

CARD TYPES:
• Creatures - Attack and defend
• Spells - Instant effects
• Enchantments - Ongoing effects
• Artifacts - Powerful items

MECHANICS:
• Mana increases each turn
• Cards have costs and effects
• Synergies between cards
• Counter-play and strategy

DECK BUILDING:
• Mix creatures and spells
• Consider mana curve
• Build around strategies (aggro, control, combo)
• Collect rare cards through play

PROGRESSION:
• Earn new cards from victories
• Craft cards with dust
• Challenge AI or other players
• Climb ranked ladder

Similar strategic depth to [[link:combat_stats|Combat System]].
            ]=],
            links = {"combat_stats"},
        },
    },

    -- ==================== ITEMS SECTION ====================
    items = {
        {
            id = "materials_overview",
            title = "Crafting Materials",
            tags = {"items"},
            content = [=[
Materials are gathered from activities and used for crafting.

FROM FISHING:
• Fish bones, scales, fins
• Iridescent scales (rare)
• Dragon scales (legendary)

FROM HUNTING:
• Meat, hides, furs
• Bones, claws, antlers
• Legendary pelts

FROM GATHERING:
• Herbs, moonflowers
• Venom sacs, troll blood
• Phoenix feathers (very rare)

ORES & METALS:
• Iron, steel, silver
• Mithril, adamantine

See [[link:rare_materials|Rare Materials]] for special components.
            ]=],
            links = {"rare_materials"},
        },
        {
            id = "consumables_overview",
            title = "Consumables",
            tags = {"items"},
            content = [=[
Items that are used up when activated.

POTIONS:
• Health - Restore HP
• Mana - Restore MP
• Buff potions - Temporary stat boosts

POISONS:
• Apply to weapons
• Deal damage over time
• Various effects (stun, slow)

SCROLLS:
• One-time spell casts
• Various effects

FOOD:
• Restore health slowly
• Provide temporary buffs

Crafted in [[link:alchemy_overview|Alchemy]].
Quality affects potency (see [[link:crafting_quality|Crafting Quality]]).
            ]=],
            links = {"alchemy_overview", "crafting_quality"},
        },
        {
            id = "equipment_overview",
            title = "Equipment",
            tags = {"items"},
            content = [=[
Gear that improves your character.

WEAPONS:
• Swords, axes, maces (melee)
• Bows, crossbows (ranged)
• Staves, wands (magic)

ARMOR:
• Helmet, chest, legs, boots
• Provides defense
• May have stat bonuses

ACCESSORIES:
• Rings, amulets, cloaks
• Special effects
• Stat bonuses

QUALITY MATTERS:
• Higher quality = better stats
• Class restrictions may apply

Crafted in [[link:forge_overview|Forge]].
Stats explained in [[link:combat_stats|Combat Stats]].
            ]=],
            links = {"forge_overview", "combat_stats"},
        },
        {
            id = "fishing_gear",
            title = "Fishing Gear",
            tags = {"items", "fishing"},
            content = [=[
Specialized equipment for fishing success!

FISHING RODS:
• Basic Rod - 100 max tension, starter
• Quality Rod - 150 max tension, +10% value
• Expert Rod - 200 max tension, +20% value
• Master Rod - 300 max tension, +50% value
• Legendary Rod - 500 max tension, +100% value

BAIT TYPES:
• Worms - Attract common fish
• Grubs - Better bite rate
• Minnows - Attract predator fish
• Lures - Rare fish attraction
• Magic Bait - Legendary fish only

LINE & TACKLE:
• Stronger line = higher tension capacity
• Hooks affect catch rate
• Bobbers improve bite detection

UPGRADES:
Purchase from Fishing Shop ([TAB] while fishing).
Better gear enables deeper [[link:bestiary|fish]] catches.
            ]=],
            links = {"tension_system"},
        },
        {
            id = "alchemy_ingredients",
            title = "Alchemy Ingredients",
            tags = {"items", "alchemy"},
            content = [=[
Raw materials for potion brewing!

COMMON HERBS:
• Moonflower - Mana potions
• Redleaf - Health potions
• Swiftroot - Speed potions
• Ironbark - Defense potions

MONSTER PARTS:
• Slime Gel - Base for many potions
• Venom Sac - Poison brewing
• Dragon Scale - Powerful elixirs
• Demon Heart - Forbidden brews

ELEMENTAL ESSENCES:
• Flame Essence - Fire resistance
• Aqua Essence - Water breathing
• Terra Essence - Stone skin
• Volt Essence - Lightning reflexes

RARE COMPONENTS:
• Phoenix Feather - Resurrection potion
• Unicorn Horn - Cure-all elixir
• Void Crystal - Shadow potions

Gathered from [[link:bestiary|creatures]] and world exploration.
Used in [[link:alchemy_overview|Alchemy]].
            ]=],
            links = {"alchemy_overview"},
        },
        {
            id = "rare_materials",
            title = "Rare Materials",
            tags = {"items", "crafting"},
            content = [=[
Exceptionally valuable crafting components!

LEGENDARY METALS:
• Mithril - Lightweight, strong, magic-conductive
• Adamantine - Nearly indestructible
• Starmetal - Fallen from the sky, divine properties
• Voidsteel - Dark metal from shadow realm

DRAGON MATERIALS:
• Dragon Scale - Armor with elemental resistance
• Dragon Fang - Powerful weapon component
• Dragon Heart - Ultimate alchemy ingredient
• Dragon Bone - Lightweight frame material

MYSTICAL COMPONENTS:
• Phoenix Feather - Resurrection enchantments
• Unicorn Horn - Purification and healing
• Kraken Ink - Scroll and enchantment creation
• Celestial Dust - Divine enchantments

ACQUISITION:
• Legendary [[link:bestiary|creature]] drops
• High-level dungeon rewards
• Rare merchant stock
• Endgame quest rewards

Used to craft the most powerful [[link:equipment_overview|equipment]].
            ]=],
            links = {"equipment_overview"},
        },
    },

    -- ==================== CONTROLS SECTION ====================
    controls = {
        {
            id = "universal_controls",
            title = "Universal Controls",
            tags = {"controls"},
            content = [=[
Controls that work everywhere:

[ESC] - Back / Close menu / Exit activity
[B] - Open backpack
[TAB] - Open shop (in minigames)
[E] - Open employees panel
[?] or [K] - Open Knowledge Center

MOUSE:
• Left click - Select / Interact
• Scroll - Scroll lists

QUICK ACCESS:
• [M] - Map (in overworld)
• [J] - Journal/Quests
• [C] - Character sheet
• [I] - Inventory (same as [B])

SOCIAL:
• [G] - Guild panel
• [F] - Friends list
            ]=],
        },
        {
            id = "fishing_controls",
            title = "Fishing Controls",
            tags = {"controls", "fishing"},
            content = [=[
CASTING:
• Hold [SPACE] - Charge cast power
• Release [SPACE] - Cast line

REELING:
• Hold [SPACE] - Reel in line
• Also works: Hold [R] or click Reel button

FIGHTING FISH:
• [←] Arrow - Match left direction
• [→] Arrow - Match right direction
• [SPACE] - Hit perfect windows

MENUS:
• [TAB] - Shop
• [C] - Collection journal
• [E] - Employees
• [Q] - Change bait
• [T] - Restart tutorial

For mechanics details, see [[link:fishing_overview|Fishing Overview]].
            ]=],
            links = {"fishing_overview"},
        },
        {
            id = "alchemy_controls",
            title = "Alchemy Controls",
            tags = {"controls", "alchemy"},
            content = [=[
PREP PHASE:
• [SPACE] - Chop ingredient

POUR PHASE:
• Hold [SPACE] - Pour liquid
• [ENTER] - Done pouring

HEAT PHASE:
• Hold [SPACE] - Pump bellows

DISTILL PHASE:
• [SPACE] - Turn crank

MENUS:
• [B] - Backpack
• [E] - Employees
• [ESC] - Exit (saves progress)

TIPS:
• Watch phase meters carefully
• Timing is everything
• Each phase affects [[link:crafting_quality|quality]]

See [[link:alchemy_overview|Alchemy Overview]] for full guide.
            ]=],
            links = {"alchemy_overview", "crafting_quality"},
        },
        {
            id = "combat_controls",
            title = "Combat Controls",
            tags = {"controls", "textrpg"},
            content = [=[
TURN-BASED COMBAT:

Select actions with mouse or number keys:
• [1] - Attack
• [2] - Defend
• [3] - Use skill
• [4] - Use item
• [5] - Flee

TARGETING:
• Click enemy to target
• Some skills are AoE

ITEMS:
• Access from combat menu
• Potions heal instantly
• Scrolls cast spells

SKILL MENU:
• Tab through skill pages
• Check mana costs
• Cooldowns displayed

Used in [[link:textrpg_overview|Tavern Quest RPG]].
            ]=],
            links = {"textrpg_overview"},
        },
        {
            id = "hunting_controls",
            title = "Hunting Controls",
            tags = {"controls", "hunting"},
            content = [=[
SHOOTING:
• Click anywhere to shoot arrow
• Aim ahead of moving targets
• Account for wind!

MENUS:
• [S] - Shop
• [E] - Employees
• [U] - Upgrades
• [B] - Backpack

TIPS:
• Don't miss - increases noise
• Wait for clear shots
• Some prey is faster than others

AIMING:
• Crosshair shows aim point
• Wind indicator shows drift
• Distance affects accuracy

See [[link:hunting_overview|Hunting Overview]] for strategies.
            ]=],
            links = {"hunting_overview"},
        },
        {
            id = "general_shortcuts",
            title = "General Shortcuts",
            tags = {"controls", "shortcuts"},
            content = [=[
Additional keyboard shortcuts for efficiency!

INVENTORY MANAGEMENT:
• [SHIFT + Click] - Quick transfer item
• [CTRL + Click] - Split stack
• [ALT + Click] - Sell/destroy item
• [R] - Sort inventory

COMMUNICATION:
• [ENTER] - Open chat
• [/] - Command prefix
• [T] - Reply to whisper

INTERFACE:
• [F1] - Toggle UI
• [F2] - Screenshot
• [F3] - Performance stats
• [F11] - Fullscreen toggle

QUICK ACTIONS:
• [SPACE] - Confirm dialog
• [ESC] - Cancel/Back
• [1-9] - Hotbar slots
• [SHIFT + 1-9] - Second hotbar

ACCESSIBILITY:
• [+] / [-] - Adjust UI scale
• [CTRL + Scroll] - Zoom
            ]=],
        },
    },

    -- ==================== LORE SECTION ====================
    lore = {
        {
            id = "world_overview",
            title = "The World",
            tags = {"lore"},
            content = [=[
Welcome to the world of Tavern Quest!

A fantasy realm where many races coexist in an age
of recovery and rebuilding. The catastrophic destruction
of Calidar reshaped the world, leaving scars that
still define the current era.

MAJOR REGIONS:
• The Holy Empire - Human theocracy under Helios
• Elven Archives - Bureaucratic forest cities
• Dwarven Holds - Collective mountain strongholds
• The Frontier - Untamed lands of opportunity
• Shadow Fen - Lizard folk communes
• Orcish Sky Roads - Nomadic warrior culture

CURRENT ERA:
The Age After War - a time of cautious peace,
where old powers watch each other carefully and
new powers rise in the gaps.

The mysterious Heaven's Atlas casts a shadow over all.

Learn more: [[link:age_after_war|Age After War]], [[link:heavens_atlas|Heaven's Atlas]]
            ]=],
            links = {"age_after_war", "heavens_atlas", "races_overview"},
        },
        {
            id = "races_overview",
            title = "The Races",
            tags = {"lore"},
            content = [=[
Many races inhabit this world, each with unique culture:

HUMANS - Theocratic empire under Helios worship
ELVES - Archival bureaucrats regulating magic
DWARVES - Collective labor society, stone-born
GNOMES - Technical innovators, council-governed
ORCS - Nomadic warriors of the sky roads
GOBLINS - Survivors preserving memory through song

BEAST FOLK:
• Cat Folk - Oral tradition, family caravans
• Lizard Folk - Ancient observers, sect-based

Each race emerged from the aftermath of Calidar's
destruction with different lessons learned.

RELATIONS:
Complex web of trade, treaty, and tension.
The Frontier draws all races seeking fresh starts.

For faction details, see [[link:factions|Factions]].
            ]=],
            links = {"factions", "the_frontier"},
        },
        {
            id = "heavens_atlas",
            title = "Heaven's Atlas",
            tags = {"lore", "mystery"},
            content = [=[
The Heaven's Atlas... the weapon that destroyed Calidar.

Ancient texts speak of it in fragments. The Holy Empire
claims it was a divine instrument of judgment. The elves
say it was magic unregulated and unleashed. The lizard
folk say they measured its activation from afar.

THE CALIDAR EVENT:
Five hundred years ago, the great civilization of
Calidar vanished in a pulse of energy that defied
measurement. Rivers disappeared. The land turned to
glass. Nothing remained—no bodies, no ruins.

WHAT IS IT?
• A weapon? A map? A key to divine realms?
• Some say it shows the structure of heaven
• Others claim it rewrites reality itself
• All agree: it must never be used again

CURRENT STATUS:
Its location is unknown. The Holy Empire claims it's
secured. The elves monitor magical signatures. The
lizard folk watch and wait.

"Where stars align and shadows bend,
The Atlas reveals what truths transcend."

Related: [[link:age_after_war|Age After War]], [[link:the_veiled_hand|The Veiled Hand]]
            ]=],
            links = {"age_after_war"},
        },
        {
            id = "tavern_history",
            title = "Your Tavern's History",
            tags = {"lore", "tavern"},
            content = [=[
The tavern you've inherited has a storied past.

FOUNDING:
Built 200 years ago by a retired adventurer known
only as "The Wanderer." It began as a simple roadside
inn at a crossroads between major trade routes.

GOLDEN AGE:
For decades, it thrived as a hub for adventurers,
merchants, and travelers. Many famous heroes planned
their quests at these very tables. The walls still
bear their carved initials.

DECLINE:
As trade routes shifted and the original owner
passed, the tavern fell into disrepair. By the
time it came to you, it was barely functional.

YOUR INHERITANCE:
Why it was left to you remains mysterious. The
will simply stated: "For the one who will
remember what a tavern truly is."

YOUR MISSION:
Restore it to glory. Serve all who enter. Become
a hub of community once more. Some say the tavern
itself has a destiny intertwined with greater events...

RUMORED SECRETS:
• Hidden rooms in the basement?
• Connection to old adventuring guilds?
• The Wanderer's true identity?

Time may reveal more as you restore the tavern.
            ]=],
        },
        {
            id = "age_after_war",
            title = "The Age After War",
            tags = {"lore", "history"},
            content = [=[
The current era, defined by the aftermath of Calidar.

TIMELINE:
500 years ago - Calidar destroyed by Heaven's Atlas
450 years ago - Wars of succession and blame
400 years ago - Borders solidify, treaties signed
200 years ago - Current age begins, "The Recovery"

DEFINING CHARACTERISTICS:
• No major wars, but constant tension
• Economic competition replaces military conflict
• Magic heavily regulated by elven bureaucracy
• Religious consolidation under Helios (humans)
• Expansion into The Frontier

THE PEACE:
Not true peace, but exhaustion. All major powers
remember the cost of Calidar. None want to trigger
another such catastrophe. But none trust the others
to not be preparing exactly that.

THE WATCHERS:
Multiple groups monitor for signs of another Atlas:
• Elven archivists track magical anomalies
• Lizard folk sects observe from shadows
• Gnome councils classify potential threats
• Human inquisitors hunt heresy

THE FRONTIER:
For common folk, it's an age of opportunity. The
Frontier offers land, resources, and escape from
old feuds. Your tavern sits at this crossroads.

Related: [[link:heavens_atlas|Heaven's Atlas]], [[link:the_frontier|The Frontier]]
            ]=],
            links = {"heavens_atlas", "the_frontier"},
        },
        {
            id = "the_frontier",
            title = "The Frontier",
            tags = {"lore", "location"},
            content = [=[
The untamed lands beyond old civilization.

WHAT IS IT:
Vast territories opened for settlement after the
Age After War began. Previously wilderness, now
dotted with new towns, mines, and opportunities.

WHY PEOPLE COME:
• Escape old hierarchies and conflicts
• Claim land and resources
• Start fresh without family baggage
• Seek fortune in new discoveries

DANGERS:
• Wild monsters and beasts
• Harsh weather and terrain
• Claim disputes and conflicts
• Distance from civilization's protection

OPPORTUNITIES:
• Rich mineral deposits
• Untapped forests and fisheries
• Ancient ruins to explore
• Build something new

WHO'S HERE:
All races mix in the Frontier. Old feuds matter
less when everyone's struggling to survive.
Humans, elves, dwarves, orcs, goblins, beast folk—
all find common cause in frontier towns.

YOUR TAVERN:
Located at a Frontier crossroads, your tavern
serves as a meeting point for all these disparate
peoples. What you build here could shape the future.

RUMORS:
Some say ancient pre-Calidar ruins lie deep in
the Frontier. Others claim the Frontier itself
is being opened deliberately, as a pressure valve
for the old powers' tensions.

Related: [[link:age_after_war|Age After War]], [[link:factions|Factions]]
            ]=],
            links = {"age_after_war", "factions"},
        },
        {
            id = "factions",
            title = "Factions and Powers",
            tags = {"lore", "politics"},
            content = [=[
Major power groups shaping the world.

GOVERNMENTAL:
• Holy Empire (Humans) - Helios theocracy,
  hierarchical, expansionist
• Elven Archives - Bureaucratic magic regulators,
  obsessed with control and classification
• Dwarven Holds - Collective guilds, isolationist
  but economically powerful
• Gnome Councils - Technical oligarchy,
  numbered classifications for everything

CULTURAL:
• Orcish Clans - Sky road nomads, ancestral law,
  honor-based martial society
• Cat Folk Caravans - Oral tradition keepers,
  family-centered, luck and fortune focus
• Lizard Folk Sects - Ancient observers,
  knowledge-hoarders, cryptic

SHADOW POWERS:
• The Veiled Hand - Lizard folk assassins,
  prevent another Calidar through targeted removal
• Goblin Resistance - Memory preservers,
  scattered but connected through song

ECONOMIC:
• Merchant Coalition - Cross-racial trade network
• Hunters Lodge - Frontier resource guild
• Tavern Keepers Guild - Your professional org!

RELIGIOUS:
• Church of Helios - Dominant human faith
• Various ancestral/elemental faiths

Each faction has agenda, allies, and enemies.
Your [[link:reputation_system|Reputation]] affects interactions.

Related: [[link:races_overview|Races Overview]]
            ]=],
            links = {"reputation_system", "races_overview"},
        },
    },
}

-- Note: 'tutorials' and 'glossary' sections are handled by separate modules
-- and do not have entries defined here

return KCData
