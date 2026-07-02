-- rumorsystem.lua
-- Dynamic rumor generation and spreading system
-- Rumors can be true (based on world events) or false (random gossip)
-- They spread between towns via merchants and get distorted over time

local RumorSystem = {}

local state = nil
local _initialized = false  -- Optimization flag to skip redundant init work

-- Rumor accuracy levels
RumorSystem.ACCURACY = {
    TRUE = 1.0,        -- Completely accurate
    MOSTLY_TRUE = 0.75, -- Some details wrong
    HALF_TRUE = 0.5,   -- Major details wrong
    MOSTLY_FALSE = 0.25, -- Kernel of truth buried in fiction
    FALSE = 0.0,       -- Complete fabrication
}

-- Rumor types
RumorSystem.TYPES = {
    LICH_ACTIVITY = "lich_activity",
    MONSTER_SIGHTING = "monster_sighting",
    SERIAL_KILLER = "serial_killer",
    GHOST_SIGHTING = "ghost_sighting",
    WEREWOLF = "werewolf",
    VAMPIRE = "vampire",
    VAMPIRE_ATTACK = "vampire_attack",      -- Someone was bitten
    VAMPIRE_EPIDEMIC = "vampire_epidemic",  -- Multiple vampires in city
    VAMPIRE_PURGE = "vampire_purge",        -- Holy City purge event
    VAMPIRE_PLAYER = "vampire_player",      -- Player is a known vampire
    VAMPIRE_LAIR_IN_TOWN = "vampire_lair_in_town",  -- Suspected vampire lair within town
    VAMPIRE_INFILTRATION = "vampire_infiltration",  -- Vampires infiltrating from nearby den
    LUMINARY_PATROL = "luminary_patrol",  -- Luminary Inquest patrols on the roads
    VILLAGE_DESTROYED = "village_destroyed",
    BATTLE = "battle",
    MERCHANT_NEWS = "merchant_news",
    TREASURE = "treasure",
    CURSE = "curse",
    PLAGUE = "plague",
    BANDIT = "bandit",
    HERO = "hero",
    PROPHECY = "prophecy",
    -- NEW LORE-BASED RUMORS
    CALIDAR_MEMORY = "calidar_memory",          -- Elves remembering destroyed homeland
    HEAVENS_ATLAS = "heavens_atlas",            -- Artifact location speculation
    SHADOWFEN_REFUGE = "shadowfen_refuge",      -- People fleeing to Shadow Fen
    VEILED_HAND = "veiled_hand",                -- Mysterious deaths of officials
    INFERNAL_PACTS = "infernal_pacts",          -- Shadow Fen devil bargains
    ELVEN_RESISTANCE = "elven_resistance",      -- Elves quietly helping fugitives
    ORC_REUNIFICATION = "orc_reunification",    -- Fear of new Khan
    DOCUMENTATION_TERROR = "documentation_terror", -- Inquest paper checks
    MAGIC_BAN = "magic_ban",                    -- Imperial magic regulation
    DWARF_ISOLATION = "dwarf_isolation",        -- Dwarven closed borders
    GNOME_TECHNOLOGY = "gnome_technology",      -- Gnomish secrets
    GOBLIN_RAID = "goblin_raid",                -- Resistance activity

    -- VOID COVENANT SUBPLOT (found only in Calidar-related areas)
    VOID_COVENANT = "void_covenant",              -- Ancient elven cult whispers
    CALIDAR_TRUTH = "calidar_truth",              -- True reason for Calidar's destruction
    SEALED_ARCHIVES = "sealed_archives",          -- Forbidden knowledge in elven archives
    GLASSED_WASTES = "glassed_wastes",            -- Strange happenings in the wastes
    VOID_TOUCHED = "void_touched",                -- Creatures corrupted by the Void

    -- EXPANDED WORLD GEOGRAPHY (beyond empire's reach)
    OUTER_WATERS = "outer_waters",                -- Western Ocean beyond the desert
    ASHEN_ARCHIPELAGO = "ashen_archipelago",      -- Volcanic islands in distant ocean
    GREAT_WESTERN_ISLE = "great_western_isle",    -- Distant continent to the west
    FROSTBOUND_REACH = "frostbound_reach",        -- Northern ice lands beyond mountains
    BEYOND_EMPIRE = "beyond_empire",              -- Knowledge that world is bigger than empire admits
    HIDDEN_CHARTS = "hidden_charts",              -- Lizard folk/elven maps of distant lands
    CYCLICAL_WORLD = "cyclical_world",            -- Geography follows patterns: land-sand-water-land

    -- HOLLOW EARTH DINOSAUR RUMORS
    HOLLOW_EARTH_DINOSAURS = "hollow_earth_dinosaurs",        -- General dinosaur sightings/mentions
    INTELLIGENT_SAURIANS = "intelligent_saurians",            -- RARE: intelligent dinosaur people
    DEEP_JUNGLE_RACES = "deep_jungle_races",                  -- Civilizations in underground jungles
    HOLLOW_EARTH_WHISPERS = "hollow_earth_whispers",          -- General hollow earth existence rumors
}

-- Template rumors that can be generated (with variations)
local RUMOR_TEMPLATES = {
    -- Lich-related rumors
    [RumorSystem.TYPES.LICH_ACTIVITY] = {
        true_templates = {
            "A lich has awakened in {location}. The dead walk the earth!",
            "Dark magic radiates from {location}. A lich controls the corruption.",
            "The corruption spreading from {location} is the work of a powerful lich.",
            "{count} tiles around {location} have been corrupted by undead magic.",
            "The dead cannot cross the living waters. The corruption stops at coastlines.",
        },
        distorted_templates = {
            "I heard a necromancer is practicing dark arts somewhere to the {direction}.",
            "They say the dead don't stay dead near {vague_location}.",
            "A powerful wizard went mad and now raises corpses. Or so I've heard.",
            "Strange lights and sounds come from {direction} at night. Must be dark magic.",
            "My cousin's friend saw skeletons marching. Could be anywhere though.",
        },
        false_templates = {
            "The old hermit in the hills is secretly a lich. I'm almost certain.",
            "I heard the king himself dabbles in necromancy!",
            "Every cemetery is cursed now. It's the end times!",
            "A child told me they saw a skeleton buying bread at the market.",
        },
    },

    -- Monster sightings
    [RumorSystem.TYPES.MONSTER_SIGHTING] = {
        true_templates = {
            "A {monster} has been spotted near {location}. Travelers beware!",
            "Hunters report {monster} activity in the {region} region.",
            "The road to {location} is dangerous - {monster}s prowl there.",
        },
        distorted_templates = {
            "Something big and dangerous lurks to the {direction}.",
            "A beast of some kind attacked a cart near {vague_location}.",
            "There's a monster somewhere. Can't remember where exactly.",
            "My brother saw something with glowing eyes in the {terrain}.",
        },
        false_templates = {
            "A dragon was seen flying over the capital! We're all doomed!",
            "The baker's cat is actually a shapeshifted demon.",
            "Giants have returned to the mountains! Run for your lives!",
            "I saw a monster but it turned out to be my mother-in-law.",
        },
    },

    -- Serial killer rumors
    [RumorSystem.TYPES.SERIAL_KILLER] = {
        true_templates = {
            "A killer stalks {location}. {count} bodies found so far.",
            "The '{killer_name}' has claimed another victim in {location}.",
            "Guards in {location} are hunting a murderer. Stay vigilant.",
        },
        distorted_templates = {
            "Someone's been killing folk around {vague_location}. Or was it {other_location}?",
            "A murderer is loose! They say he has {false_detail}.",
            "Bodies found somewhere to the {direction}. Could be anything though.",
            "I heard there's a killer, but they only target {wrong_target}.",
        },
        false_templates = {
            "The butcher is the killer! I've always suspected him!",
            "It's not a killer, it's a curse! The town is hexed!",
            "There are actually THREE killers working together!",
            "The killer is a noble's son. They're covering it up!",
        },
    },

    -- Ghost sightings
    [RumorSystem.TYPES.GHOST_SIGHTING] = {
        true_templates = {
            "Spirits haunt the graveyard near {location}. Don't go there at night.",
            "The ruins of {location} are haunted by restless dead.",
            "Travelers report ghostly figures on the road to {location}.",
        },
        distorted_templates = {
            "Something spooky was seen somewhere to the {direction}.",
            "Ghosts or maybe just fog? Hard to say. Near {vague_location}.",
            "An old woman's spirit wanders... somewhere around here.",
            "I heard moaning at night. Could be ghosts. Could be the wind.",
        },
        false_templates = {
            "My dead grandmother visited me! She says hello!",
            "The whole town is actually ghosts! We're the only living ones!",
            "Ghosts are planning an invasion! I heard them plotting!",
            "That merchant? Definitely a ghost in disguise.",
        },
    },

    -- Werewolf rumors
    [RumorSystem.TYPES.WEREWOLF] = {
        true_templates = {
            "A werewolf prowls near {location}. Lock your doors on full moons.",
            "Livestock torn apart near {location}. Classic werewolf attack.",
            "Someone in {location} is a werewolf. The signs are unmistakable.",
        },
        distorted_templates = {
            "Wolf attacks to the {direction}. Might be werewolves. Might be wolves.",
            "I heard howling last night. Probably nothing. Probably.",
            "A hairy man was seen running through {vague_location}. Suspicious!",
            "The blacksmith's son is unusually hairy. Just saying.",
        },
        false_templates = {
            "Everyone bitten by a dog becomes a werewolf! It's spreading!",
            "The moon itself is cursed! That's why there are werewolves!",
            "Werewolves are actually friendly! It's propaganda from the silver merchants!",
            "I'm a werewolf but only on Tuesdays.",
        },
    },

    -- Vampire rumors
    [RumorSystem.TYPES.VAMPIRE] = {
        true_templates = {
            "A vampire den was discovered near {location}. Stay away!",
            "People in {location} have gone pale and weak. Vampire feeding.",
            "The old castle near {location} houses vampires. It's confirmed.",
        },
        distorted_templates = {
            "Someone with pointy teeth was seen to the {direction}.",
            "Blood was found somewhere. Vampires, probably. Or butchers.",
            "A noble who only comes out at night? Suspicious, but maybe just eccentric.",
            "Garlic sales are up in {vague_location}. Must be a reason.",
        },
        false_templates = {
            "The tax collector is a vampire! He drains us of our gold AND blood!",
            "Vampires control the government! Wake up, people!",
            "I drink blood too sometimes. Doesn't make ME a vampire!",
            "Vampires are romantic and misunderstood, actually.",
        },
    },

    -- Vampire attack (someone was bitten)
    [RumorSystem.TYPES.VAMPIRE_ATTACK] = {
        true_templates = {
            "Someone was attacked by a vampire in {location}! They found bite marks!",
            "A citizen of {location} was bitten in the night. They're changing...",
            "{victim_name} was found with puncture wounds on their neck in {location}.",
            "The guards in {location} are hunting a vampire who attacked {victim_name}!",
        },
        distorted_templates = {
            "Someone got bitten by something in {vague_location}. Animal attack, probably.",
            "There was an attack to the {direction}. Might have been a vampire. Or a dog.",
            "I heard someone woke up with strange marks. Could be bedbugs.",
            "A person was attacked at night somewhere. Details are fuzzy.",
        },
        false_templates = {
            "Everyone who stays out past midnight gets bitten! It's a fact!",
            "The innkeeper bites people in their sleep! I saw his teeth!",
            "Bite marks are actually a new fashion trend. Very edgy.",
            "I bite myself sometimes. Does that count as a vampire attack?",
        },
    },

    -- Vampire epidemic (multiple vampires in city)
    [RumorSystem.TYPES.VAMPIRE_EPIDEMIC] = {
        true_templates = {
            "A vampire plague spreads through {location}! {count} people infected!",
            "{location} is overrun with vampires! The night belongs to them now!",
            "The vampire infestation in {location} grows worse. {count} turned this week!",
            "Don't go to {location} after dark! The vampires have taken over!",
        },
        distorted_templates = {
            "There's some kind of sickness in {vague_location}. People acting strange.",
            "I heard a whole town to the {direction} has gone nocturnal. Weird.",
            "Something's wrong with the people in {vague_location}. They're... different.",
            "Pale folk everywhere these days. Must be the lack of sun.",
        },
        false_templates = {
            "EVERYONE is a vampire now! Trust no one! Not even yourself!",
            "The entire kingdom has been secretly vampires for centuries!",
            "Vampirism isn't real. It's just a dietary choice.",
            "I'm starting a vampire support group. Refreshments will be served.",
        },
    },

    -- Holy City purge (vampire hunters active)
    [RumorSystem.TYPES.VAMPIRE_PURGE] = {
        true_templates = {
            "The Holy City has sent vampire hunters to {location}! {count} vampires slain!",
            "Paladins purged {location} of vampires! The streets ran red with unholy blood!",
            "Holy warriors cleansed {location}! The vampire menace has been destroyed!",
            "The Luminary Inquest has arrived in {location}. No vampire shall escape justice!",
            "The Inquest executed {count} vampires in {location}. Public executions, as usual.",
            "The Luminaries swept through {location}. Papers were checked, vampires were found.",
        },
        distorted_templates = {
            "Religious folk doing something violent to the {direction}. As usual.",
            "I heard holy warriors killed some people. Vampires, they claim.",
            "There was a purge somewhere. Lots of fire and screaming.",
            "The church is hunting something. Best stay out of their way.",
            "The Inquest came through town. People disappeared. They say it was vampires.",
            "Sun Enforcers were here yesterday. Markets emptied. Taverns went silent.",
        },
        false_templates = {
            "The Holy City is secretly run by vampires! The hunters are just for show!",
            "They're not hunting vampires, they're recruiting them!",
            "I'm a vampire hunter too! I hunt them for their fashion advice!",
            "The purge is fake! It's all staged for political reasons!",
        },
    },

    -- Luminary Inquest patrols
    [RumorSystem.TYPES.LUMINARY_PATROL] = {
        true_templates = {
            "The Luminary Inquest has been spotted near {location}!",
            "Sun Enforcers are patrolling the roads near {location}. Travel carefully.",
            "I saw golden banners on the road to {location}. The Inquest is here.",
            "Luminary patrols are active in the region around {location}.",
            "The Inquest is checking documents on all roads near {location}.",
            "Enforcers in golden armor march near {location}. They seek vampires.",
        },
        distorted_templates = {
            "They say patrols are everywhere to the {direction}. Stay indoors.",
            "The Inquest is hunting someone. Keep your head down.",
            "Religious soldiers are on the roads. Checking papers.",
            "I heard the Luminaries are near. Or maybe it was somewhere else.",
            "Patrols near {vague_location}. Looking for something dark.",
        },
        false_templates = {
            "The Inquest can smell vampires from a mile away!",
            "Patrols are hunting dragons now, not vampires!",
            "The enforcers have magical detection orbs!",
            "If you're not a vampire, you have nothing to fear! They're perfect!",
        },
    },

    -- Player vampire (player is known to be vampire)
    [RumorSystem.TYPES.VAMPIRE_PLAYER] = {
        true_templates = {
            "A vampire adventurer stalks the land! They were seen near {location}!",
            "Beware the {player_name}! They say they're a creature of the night now!",
            "That adventurer {player_name} has turned! I saw their fangs!",
            "The one called {player_name} only travels at night now. Vampire, surely!",
        },
        distorted_templates = {
            "There's an adventurer who only works nights. Suspicious.",
            "Someone important got turned into a vampire. Can't remember who.",
            "A hero fell to darkness. Or maybe they just got a tan. Hard to tell.",
            "I heard a famous person is a vampire now. Very dramatic.",
        },
        false_templates = {
            "All adventurers are vampires! It's how they get so powerful!",
            "That nice traveler? A vampire? No, they're just pale and avoid garlic.",
            "Being a vampire adventurer is actually very responsible. Think of the savings on food!",
            "I knew a vampire once. Nice fellow. Terrible at parties though.",
        },
    },

    -- Vampire lair hidden within town
    [RumorSystem.TYPES.VAMPIRE_LAIR_IN_TOWN] = {
        true_templates = {
            "There's a vampire nest hidden somewhere in {location}! Check the abandoned buildings!",
            "Vampires have built a lair beneath {location}! An old cellar leads to their den!",
            "The vampire plague in {location} has a source - a hidden lair within the town itself!",
            "Don't trust the abandoned cellar in {location}. It leads to a vampire nest!",
        },
        distorted_templates = {
            "Something's wrong in {location}. Secret passages, disappearances...",
            "I heard there's a hidden dungeon somewhere in {vague_location}. Vampires, maybe?",
            "Strange noises from underground in {vague_location}. Best not investigate.",
            "An abandoned building in a town to the {direction} hides something sinister.",
        },
        false_templates = {
            "Every cellar is a vampire lair! Never go underground!",
            "The town itself is built on vampire bones! We're all doomed!",
            "Secret vampire tunnels connect every building! Trust no basement!",
            "I found a vampire lair in my own house! It was just rats though.",
        },
    },

    -- Vampires infiltrating from nearby den
    [RumorSystem.TYPES.VAMPIRE_INFILTRATION] = {
        true_templates = {
            "Vampires from the nearby den are infiltrating {location}! Lock your doors!",
            "The vampire den to the {direction} has sent scouts into {location}!",
            "Night attacks in {location} trace back to a vampire lair nearby!",
            "Vampires are slipping into {location} from their lair outside town!",
        },
        distorted_templates = {
            "Something from outside is getting into {vague_location} at night.",
            "Strangers have been seen sneaking into town after dark.",
            "I heard creatures from a nearby cave are visiting the town.",
            "Night visitors with pale skin. Travelers? Or something else?",
        },
        false_templates = {
            "All visitors are vampires! Close the gates permanently!",
            "The night itself spawns vampires! They come from nowhere!",
            "Vampires can teleport into any building! Walls mean nothing!",
            "Every stranger after sunset is definitely a vampire scout.",
        },
    },

    -- Village destroyed
    [RumorSystem.TYPES.VILLAGE_DESTROYED] = {
        true_templates = {
            "{location} has fallen! The undead overwhelmed them!",
            "The village of {location} is nothing but ruins now. {count} dead.",
            "Refugees from {location} say the lich's army destroyed everything.",
        },
        distorted_templates = {
            "A village was destroyed somewhere. Terrible business.",
            "Something bad happened to the {direction}. A town fell, I think.",
            "I heard {wrong_location} was attacked. Or was it {other_location}?",
            "The dead rose and attacked a village. Don't know which one.",
        },
        false_templates = {
            "Every village east of here is gone! Complete devastation!",
            "The capital itself was destroyed! Wait, no, that can't be right.",
            "Villages are disappearing into thin air! Magic!",
            "It was actually a flood. No wait, a fire. No wait, dragons.",
        },
    },

    -- Treasure rumors
    [RumorSystem.TYPES.TREASURE] = {
        true_templates = {
            "The dungeon near {location} holds great treasure. But also great danger.",
            "Adventurers found gold in {location}. Might be more where that came from.",
        },
        distorted_templates = {
            "There's treasure somewhere to the {direction}. Everyone knows it.",
            "A map to riches was found! Or lost. Can't remember.",
            "Gold in the {terrain}! Definitely! Probably! Maybe!",
        },
        false_templates = {
            "The king buried his fortune under the tavern! Start digging!",
            "Every third stone in the road is actually solid gold!",
            "Ancient dwarves left treasure everywhere! It's common knowledge!",
            "I know where treasure is but I'm keeping it secret. Very secret.",
        },
    },

    -- Bandit activity
    [RumorSystem.TYPES.BANDIT] = {
        true_templates = {
            "Bandits ambush travelers on the road to {location}. Hire guards.",
            "A bandit camp was spotted near {location}. The roads aren't safe.",
        },
        distorted_templates = {
            "Robbers somewhere to the {direction}. Be careful out there.",
            "Someone got mugged near {vague_location}. Or maybe {other_location}.",
            "There might be bandits. Or just aggressive tax collectors.",
        },
        false_templates = {
            "The guards ARE the bandits! It's a conspiracy!",
            "Bandits stole my invisible gold! Nobody believes me!",
            "Robin Hood lives! He steals from the rich! And also the poor!",
        },
    },

    -- Hero/adventurer news
    [RumorSystem.TYPES.HERO] = {
        true_templates = {
            "A brave adventurer cleared the dungeon near {location}!",
            "Heroes are gathering to fight the lich threatening {location}.",
        },
        distorted_templates = {
            "Someone heroic did something somewhere. Inspiring!",
            "An adventurer passed through. Seemed competent. Maybe.",
            "Heroes exist! I've heard of them! Never seen one though.",
        },
        false_templates = {
            "A chosen one has been born! Prophecy says so! Maybe!",
            "I'm actually a retired hero. These aren't beer muscles!",
            "All adventurers are secretly working for the monsters!",
        },
    },

    -- Plague/sickness
    [RumorSystem.TYPES.PLAGUE] = {
        true_templates = {
            "A sickness spreads through {location}. Avoid contact.",
            "The water in {location} is tainted. People are falling ill.",
        },
        distorted_templates = {
            "Coughing sickness somewhere to the {direction}.",
            "People are sick. Could be plague. Could be bad ale.",
            "Something's going around. Wash your hands, probably.",
        },
        false_templates = {
            "The plague is actually a government population control!",
            "Breathing causes illness! Hold your breath to live forever!",
            "Sick people are faking it for attention!",
        },
    },

    -- Curse rumors
    [RumorSystem.TYPES.CURSE] = {
        true_templates = {
            "The corruption from the lich has cursed the land near {location}.",
            "{location} is under a dark curse. Crops wither and animals flee.",
        },
        distorted_templates = {
            "Something's cursed somewhere. Bad luck is spreading.",
            "A witch hexed something. A town? A person? A goat?",
            "Misfortune to the {direction}. Must be a curse.",
        },
        false_templates = {
            "I'm cursed to always stub my toe! It's horrible!",
            "The whole world is cursed! That's why bad things happen!",
            "Breaking a mirror causes seven years of lich attacks!",
        },
    },

    -- Prophecy/omen
    [RumorSystem.TYPES.PROPHECY] = {
        true_templates = {
            "The lich's rise was foretold. Dark times are upon us.",
            "Ancient texts predicted the corruption spreading from {location}.",
        },
        distorted_templates = {
            "A prophecy says something will happen. Eventually.",
            "The stars foretell... something. Good? Bad? Who knows?",
            "An old crone predicted doom. She predicts that a lot though.",
        },
        false_templates = {
            "The world ends next Tuesday! A goat told me!",
            "I can see the future! I predict... uncertainty!",
            "The prophecy says YOU specifically will trip today!",
            "Ancient texts predict my lunch will be delicious!",
        },
    },

    -- NEW LORE RUMORS --

    -- Elves remembering Calidar
    [RumorSystem.TYPES.CALIDAR_MEMORY] = {
        true_templates = {
            "An old elf was planting trees from Calidar seeds. Said it's remembrance. Technically illegal, but no one stopped them.",
            "Overheard elves speaking in Forest Tongue. The old language. They went silent when they saw me listening.",
            "An elven archivist mentioned Calidar in passing, then immediately changed the subject. Their eyes looked... haunted.",
            "I saw an elf over 500 years old. They were there when Calidar burned. They don't talk about it, but their hands shake when you mention glass deserts.",
            "Elves write everything down. Everything. Someone said they're documenting imperial abuses for 'historical record.' Future judgment, maybe?",
        },
        distorted_templates = {
            "Elves seem sad about something. A forest? A city? Can't remember.",
            "I heard elves keep a separate calendar. Counting from some old event.",
            "An elf helped someone with 'lost' paperwork. Very convenient errors.",
            "Elves plant strange trees. From before the war, they say. Whose war?",
        },
        false_templates = {
            "Elves are planning to rebuild Calidar! Revolution incoming!",
            "All elves are secretly mages! The empire just doesn't know!",
            "Elves control the empire from behind the scenes!",
            "Calidar was never real. Elves made it up for sympathy!",
        },
    },

    -- Heaven's Atlas location speculation
    [RumorSystem.TYPES.HEAVENS_ATLAS] = {
        true_templates = {
            "The Grand Cathedral has vaults that go down for miles. Some say Heaven's Atlas is hidden in the deepest level.",
            "I heard the empire claimed they destroyed Heaven's Atlas after the war. Convenient claim for the only ones who would know.",
            "An archivist mentioned that records about Heaven's Atlas are sealed. 'Security reasons,' they said. Security from what?",
        },
        distorted_templates = {
            "There's a powerful weapon somewhere. The one that ended the war, I think?",
            "Some artifact destroyed a whole kingdom once. Can't remember which one.",
            "The empire has a secret weapon. Or had. Or claims to have destroyed. Hard to say.",
        },
        false_templates = {
            "Heaven's Atlas is actually in MY basement! Come see!",
            "The weapon was a myth. The elves destroyed themselves!",
            "I know where it is but I'm not telling! Very secret!",
            "Every government building has a piece of Heaven's Atlas!",
        },
    },

    -- People fleeing to Shadow Fen
    [RumorSystem.TYPES.SHADOWFEN_REFUGE] = {
        true_templates = {
            "Someone from {location} fled to Shadow Fen. Haven't seen them since. Probably dead. Or free. Hard to say which.",
            "The Inquest raided a house in {location}. Family disappeared before they arrived. Locals whisper: 'Shadowfen.'",
            "A mage was discovered in {location}. Vanished before arrest. Rumor is they fled southwest to the swamps.",
            "Papers went missing for a whole family. Week later, so did the family. 'Shadowfen commune,' people whisper.",
        },
        distorted_templates = {
            "Some people disappeared. Fled to some swamp somewhere.",
            "I heard there's a place where fugitives go. Southwest? Southeast?",
            "The Inquest can't reach everywhere. Certain places are... protected.",
        },
        false_templates = {
            "Everyone who flees to Shadowfen becomes a demon! It's true!",
            "The swamp is actually paradise! Beautiful resort town!",
            "Shadowfen doesn't exist. It's just a story to give people false hope.",
        },
    },

    -- Veiled Hand assassinations
    [RumorSystem.TYPES.VEILED_HAND] = {
        true_templates = {
            "Inquisitor Commander Seris died. Fell into a pond and drowned. Shallow pond. Very suspicious.",
            "That hardline official who wanted to expand the purges? Dead. 'Heart failure' at age 47. Convenient.",
            "Three officials in positions to authorize new weapons development died this year. All natural causes. All investigated. No evidence.",
            "High Inquisitor's cousin died. They were planning a scorched-earth assault on some refuge. Now they're not planning anything.",
        },
        distorted_templates = {
            "Important people keep dying in accidents. Probably coincidence.",
            "Someone in power died suspiciously. Or maybe it was natural. Who knows?",
            "I heard officials who go too hard against certain groups... don't live long.",
        },
        false_templates = {
            "There's a secret assassin guild killing everyone!",
            "All accidents are actually murders! Every single one!",
            "The Veiled Hand is everywhere! They're unstoppable!",
            "I'm in the Veiled Hand! But I can't tell you which one!",
        },
    },

    -- Infernal pacts in Shadow Fen
    [RumorSystem.TYPES.INFERNAL_PACTS] = {
        true_templates = {
            "A deserter returned from Shadow Fen. Wouldn't speak of what he saw, but his hands shook when he mentioned 'things in the mist.'",
            "The Inquest patrol that entered Shadow Fen last month? Half didn't return. Others won't say what happened.",
            "They say the swamp is protected by devils. Actual devils. The empire denies it, but their patrols avoid the fen.",
            "A child was born in Shadow Fen with eyes that glow faintly. Mother said it's normal there. Normal. Let that sink in.",
        },
        distorted_templates = {
            "Something unnatural in the southern swamps. Demons? Spirits? Swamp gas?",
            "I heard the Shadow Fen is cursed. Or blessed. Depends who you ask.",
            "Patrols don't return from certain places. Bad terrain, they claim.",
        },
        false_templates = {
            "Shadow Fen is ruled by the devil himself!",
            "Everyone in the swamp is a demon in disguise!",
            "The empire made a pact with Shadow Fen to control the population!",
        },
    },

    -- Elves quietly helping fugitives
    [RumorSystem.TYPES.ELVEN_RESISTANCE] = {
        true_templates = {
            "An elven clerk's 'clerical error' gave someone three extra months before their papers needed renewal. Saved their life.",
            "I know an elf who warned someone the Inquest was coming. Quietly. Never admitted it.",
            "Census data has gaps. Always has. Elves maintain the census. Probably coincidence. Probably.",
            "An elf told me my 'request was delayed.' It's been three years. Still delayed. My request was for investigation of someone.",
        },
        distorted_templates = {
            "Elves help people sometimes. Not officially. Not openly. But... sometimes.",
            "Records go missing. Elves are in charge of records. Interesting pattern.",
            "I heard elves remember when it was them being hunted. Makes them sympathetic, maybe.",
        },
        false_templates = {
            "All elves are secret resistance fighters!",
            "The elven administration is undermining the empire!",
            "Elves are plotting revolution! I have no evidence!",
        },
    },

    -- Fear of orc reunification
    [RumorSystem.TYPES.ORC_REUNIFICATION] = {
        true_templates = {
            "The orc clans are restless. Clan leaders keep meeting in secret. Imperial scouts are nervous.",
            "Someone among the orcs is trying to claim the Khan title. Empire sent assassins. Third attempt this year.",
            "Old orcs who remember the Great Khan are teaching the young ones. The routes. The laws. The commands.",
            "Imperial generals tripled patrols on the orcish border. When asked why, they said: 'Preventative.' Preventing what?",
        },
        distorted_templates = {
            "Orcs are doing something on the steppes. Gathering? Training? Hard to say.",
            "I heard the empire fears the orcs might unite. Seems paranoid, but maybe not?",
            "Someone mentioned orcs used to be really dangerous. Before they split up.",
        },
        false_templates = {
            "The orcs are invading tomorrow! Everyone panic!",
            "A new Khan has already been crowned! We're doomed!",
            "Orcs are actually gentle farmers! The empire lies about them!",
        },
    },

    -- Luminary Inquest documentation terror
    [RumorSystem.TYPES.DOCUMENTATION_TERROR] = {
        true_templates = {
            "The Inquest checked papers at {location}. Three people's documents had 'discrepancies.' Haven't seen them since.",
            "Keep your papers current, friend. The Luminaries don't forgive administrative errors. Or they call them 'intent to deceive.'",
            "A family in {location} had outdated residency permits. The Inquest took them. 'Administrative resolution,' they called it.",
            "The Inquest arrived in {location} at dawn. Markets emptied. Shutters closed. Seven people didn't have proper papers. They're gone now.",
        },
        distorted_templates = {
            "Officials were checking papers somewhere. Some people disappeared.",
            "I heard you need the right documents or they take you. But which documents?",
            "The Inquest is strict about something. Paperwork? Identity? Hard to say.",
        },
        false_templates = {
            "If you're innocent, you have nothing to fear from the Inquest!",
            "Papers are optional! The Inquest is actually very understanding!",
            "I don't have papers and I'm fine! Therefore they don't matter!",
        },
    },

    -- Magic ban enforcement
    [RumorSystem.TYPES.MAGIC_BAN] = {
        true_templates = {
            "An unsanctioned mage was discovered in {location}. Public execution yesterday. Soul destruction ritual afterward.",
            "The Inquest found someone with latent magical ability. Unregistered. They executed them even though they'd never cast a spell.",
            "State-sanctioned mage had their license revoked for 'excessive use.' Executed three days later. The line is very thin.",
        },
        distorted_templates = {
            "Someone was arrested for magic. Or suspicion of magic. Same result either way.",
            "I heard practicing magic without permission is death. But who decides permission?",
            "The empire controls who gets to use magic. Everyone else... doesn't get to.",
        },
        false_templates = {
            "Magic doesn't exist anymore! The empire eliminated it completely!",
            "Everyone can use magic! The ban is just for show!",
            "I'm a licensed mage! My license is... invisible! Very exclusive!",
        },
    },

    -- Goblin resistance activity
    [RumorSystem.TYPES.GOBLIN_RAID] = {
        true_templates = {
            "Goblin raid hit supply carts near {location}. Guards doubled, but goblins will just wait them out. They're patient. We're not.",
            "The garrison cleared a goblin warren in the old mines. Week later, two new warrens opened nearby. The commander's losing his mind.",
            "Goblins sabotaged the bridge to {location}. Third time this year. Empire rebuilds. Goblins destroy. Cycle continues. We're bleeding gold.",
            "Supply officer said goblin raids cost more to prevent than they steal. Asked why we're even here. Got reassigned for 'defeatist talk.'",
            "Caught a goblin during the raid. Asked why they 'trespass' on imperial land. They said: 'No one is illegal on stolen land.' Then vanished through a tunnel we didn't know existed.",
            "Imperial patrol tried to arrest goblins for 'illegal occupation' of the old mine. Goblins just laughed. Said the mine was theirs before the empire existed. Hard to argue with that.",
            "A goblin left graffiti on the garrison wall: 'No one is illegal on stolen land.' Commander ordered it scrubbed. It reappeared the next night.",
            "Goblins killed three imperial tax collectors near {location}. Left the bodies on the road with a sign: 'No taxation without representation. Also, get out.'",
            "The garrison commander tried negotiating with a goblin cell. They told him: 'We don't negotiate with thieves. Leave our land or die on it.' Talks ended quickly.",
            "A goblin raid freed prisoners from the imperial stockade. Didn't steal anything else. Just opened the cells and vanished. The propaganda corps doesn't know how to spin that.",
            "Imperial governor offered compensation for goblin lands. Goblin response? They burned his manor down. Found a note in the ashes: 'We don't want your blood money. We want our land back.'",
            "Goblins ambushed a 'pacification squad' in the tunnels. Took their weapons, left their bodies. Message carved into the wall: 'The empire is illegitimate. The occupation ends when we say it ends.'",
            "A merchant asked a goblin why they keep fighting when the empire is so much stronger. Goblin said: 'The empire is temporary. We are eternal. Time is on our side.' Hard to argue with that perspective.",
            "Garrison posted bounties on goblin ears. Next week, they found their commander's ears nailed to the bounty board. He's still alive, but the message was clear.",
            "The empire calls them terrorists. The goblins call the empire genocidal occupiers. Depends on your perspective, I guess.",
            "Overheard a goblin tell an imperial soldier: 'Your grandfather killed my grandfather. Your father burned my father's warren. You wonder why I fight? I wonder why you're still here.' The soldier deserted the next day.",
            "Goblins don't raid for greed. They raid for survival. Every cart they hit feeds a resistance cell for weeks. It's logistics, not banditry.",
            "The old mining overseer said goblins built these shafts centuries ago. Empire 'claimed' them fifty years back. Now we arrest goblins for trespassing in mines their ancestors dug. Makes you think.",
        },
        distorted_templates = {
            "Some kind of raid happened. Goblins, probably. Or bandits. Hard to tell.",
            "Activity in the tunnels near {vague_location}. Best avoided.",
            "I heard goblins are persistent. No matter how many you kill, more appear.",
            "Goblins said something about stolen land? Didn't quite catch it.",
            "The garrison's on edge. Something about goblin activity. Don't know the details.",
        },
        false_templates = {
            "Goblins are actually friendly! The empire lies about them!",
            "All goblins are dead! The empire eliminated them!",
            "Goblins don't exist. It's imperial propaganda!",
            "Goblins are planning to surrender any day now!",
        },
    },

    -- Dwarf isolationism
    [RumorSystem.TYPES.DWARF_ISOLATION] = {
        true_templates = {
            "The dwarves closed another trade gate. Said the empire 'attempted hierarchy imposition.' Whatever that means.",
            "Dwarven holds won't let imperial officials past the outer gates. Trade only. No inspections. No exceptions.",
            "The empire tried to impose mining regulations on the dwarves. Dwarves said no. Empire backed down. Shocking, really.",
        },
        distorted_templates = {
            "Dwarves keep to themselves. Never really understood why.",
            "The holds are closed. Have been for a while. Trade still happens though.",
        },
        false_templates = {
            "Dwarves are planning to invade the surface!",
            "The holds are actually empty! It's all a bluff!",
            "Dwarves worship the empire secretly! That's why they isolate!",
        },
    },

    -- Gnomish technology secrets
    [RumorSystem.TYPES.GNOME_TECHNOLOGY] = {
        true_templates = {
            "A gnomish trader let slip something about 'airship schedules.' Then refused to elaborate. Airships?",
            "They say the gnomes have metal men that walk and work. Automatons. The empire calls them abominations. Gnomes call them tools.",
            "No invasion of the Gnomish Isles has ever succeeded. Ever. You'd think the empire would wonder why.",
        },
        distorted_templates = {
            "Gnomes have advanced technology. More than we know. That's the rumor anyway.",
            "I heard gnomes can fly. Or their machines can. Something about the sky.",
        },
        false_templates = {
            "Gnomes have flying cities! Invisible sky kingdoms!",
            "The automatons are going to rebel and kill everyone!",
            "Gnomes don't actually exist. They're a collective hallucination!",
        },
    },

    --===========================================
    -- VOID COVENANT SUBPLOT RUMORS
    -- Dark lore about the ancient elven cult
    -- These should be rare and only spread near Calidar
    --===========================================

    -- Whispers about the ancient cult
    [RumorSystem.TYPES.VOID_COVENANT] = {
        true_templates = {
            "My grandfather was a scholar. Before he died, he spoke of something called the Vel'sharath. An elven cult that existed before the Burning. He said they worshipped... nothing. Literally nothing.",
            "I met an old elf once, drunk out of his mind. He kept muttering 'In emptiness, completion' over and over. When I asked what it meant, he just laughed and cried at the same time.",
            "There are texts in the sealed archives that predate the empire. Texts about a group who believed the kindest act was ending all existence. The archivists call them 'the hollow ones.'",
        },
        distorted_templates = {
            "Something about old elves and forbidden magic. The Inquest gets nervous when you ask.",
            "I heard there was a cult, before the war. They wanted to summon something. Or maybe unsummon everything?",
            "My cousin heard from a trader that some elves used to worship the void between stars. Sounds like nonsense to me.",
        },
        false_templates = {
            "Elves secretly worship demons! That's why Calidar was destroyed!",
            "There's an elf cult in every city, waiting to destroy the world!",
            "The void is a hoax invented by the empire to justify the magic ban!",
        },
    },

    -- The truth about Calidar's destruction
    [RumorSystem.TYPES.CALIDAR_TRUTH] = {
        true_templates = {
            "The official history says Calidar was destroyed for 'unrestrained magic.' But I've seen documents... there's more to it. Something they opened. Something that had to be closed.",
            "An old soldier, dying in his cups, told me: 'We didn't destroy Calidar because they used magic. We destroyed it because something was coming through, and fire was the only way to close the door.'",
            "Why do you think the Wastes are still forbidden? It's not the glass. It's not the radiation. It's what they're afraid we'll find there.",
        },
        distorted_templates = {
            "Calidar wasn't destroyed for magic. It was destroyed for something worse. Nobody will say what.",
            "There's a reason the empire sealed the records about the war's end. Something happened that scared even them.",
            "I heard the elves did something terrible. Something that made Heaven's Atlas seem like mercy.",
        },
        false_templates = {
            "Calidar destroyed itself! The elves blew themselves up by accident!",
            "The empire was actually trying to save the elves. It was a healing spell that went wrong!",
            "There was no war. Calidar never existed. The whole thing is imperial propaganda!",
        },
    },

    -- Sealed archives and forbidden knowledge
    [RumorSystem.TYPES.SEALED_ARCHIVES] = {
        true_templates = {
            "An archivist in the elven quarter was arrested last month. They say she found something in the sealed records. Something about pre-war religious practices. She's 'no longer employed.'",
            "The Inquest sealed an entire wing of the library. 'Corrupted texts,' they said. But a scholar I know saw them carrying out stone tablets. Pre-war stone tablets.",
            "Some elves keep private archives. Family records going back centuries. The Inquest doesn't know about all of them. And some of those records mention the Hollow Circle.",
        },
        distorted_templates = {
            "Archives are being searched. The Inquest is looking for... old books? Something dangerous?",
            "A scholar got in trouble for reading the wrong thing. Something about ancient elves.",
            "There are forbidden texts. Things the empire doesn't want us to know. What's in them? Nobody will say.",
        },
        false_templates = {
            "The archives contain proof the emperor is a lich!",
            "Every library has a secret basement full of demon-summoning books!",
            "The Inquest burns books that prove the gods are fake!",
        },
    },

    -- Strange happenings in the Glassed Wastes
    [RumorSystem.TYPES.GLASSED_WASTES] = {
        true_templates = {
            "Expedition teams to the Wastes keep losing members. Not to monsters. People just... aren't there anymore. One moment walking alongside you, the next... gone. No body. No tracks. Just gone.",
            "The glass formations in Calidar aren't natural. Look closely and you'll see faces in them. Thousands of faces, frozen in the moment of their unmaking. They don't look afraid. They look... peaceful. That's what scares me.",
            "There's a place in the Wastes the locals call the Memory Well. Stay too close and you dream of things that never happened. Or things that almost happened. The difference is harder to tell than you'd think.",
        },
        distorted_templates = {
            "Strange things happen in the Calidar Wastes. People see things. Hear things. Forget things.",
            "Don't go to the Wastes. Something's wrong there. Something that doesn't follow normal rules.",
            "Explorers come back from the Wastes... different. Quieter. Like they've seen something they can't explain.",
        },
        false_templates = {
            "The Wastes are haunted by a thousand vengeful elf ghosts!",
            "Anyone who enters the Wastes turns to glass instantly!",
            "The Wastes are actually paradise but the empire doesn't want us to know!",
        },
    },

    -- Void-touched creatures
    [RumorSystem.TYPES.VOID_TOUCHED] = {
        true_templates = {
            "Deep in the Wastes, there are things that aren't quite... real. Creatures made of absence. Where they step, the ground forgets it exists. The Inquest calls them 'void remnants.' They don't talk about what made them.",
            "A hunter came out of the Calidar borderlands raving about creatures with no shadows. Not invisible shadows. No shadows. Like the light refused to acknowledge they existed.",
            "The dungeon beneath the old ruins... something lives there that shouldn't. It doesn't attack. It just watches. And everyone who sees it forgets their mother's name.",
        },
        distorted_templates = {
            "There are monsters in the Wastes that aren't like normal monsters. Something wrong with them. Something missing.",
            "Creatures in the forbidden zones don't behave right. They don't eat, don't sleep. Just... wait.",
            "I heard about things in the Calidar ruins. Things that make you forget. Forget yourself, even.",
        },
        false_templates = {
            "The void creatures are friendly! They just want to hug you into nothingness!",
            "There are no monsters in the Wastes! It's perfectly safe! The empire lies!",
            "The void creatures are actually displaced gnomes! It's all a misunderstanding!",
        },
    },

    --===========================================
    -- EXPANDED WORLD GEOGRAPHY RUMORS
    -- Knowledge that the world extends beyond empire
    -- Spread by long-lived races with memory
    --===========================================

    -- Western Ocean (Outer Waters)
    [RumorSystem.TYPES.OUTER_WATERS] = {
        true_templates = {
            "They say there's another ocean beyond the desert. Darker and colder than ours. Cat folk traders mention it sometimes, then go quiet when you ask more.",
            "A lizard folk engineer let slip something about 'western coastal routes.' Then corrected himself: 'Not that the empire acknowledges.' Interesting.",
            "My grandfather crossed the Scorched Sands once. Said the desert ends at a coastline. Black water stretching west forever. Empire maps don't show it.",
            "If the desert goes on forever like the empire claims, why do cat folk caravans return from the west with salt-water trade goods?",
        },
        distorted_templates = {
            "I heard there's water beyond the western desert. Or maybe it was the southern wastes? Hard to remember.",
            "Someone mentioned an ocean that isn't the Silver Seas. Somewhere distant. West? North?",
            "Cat folk talk about crossing something to reach trade partners. Maybe it's just more desert.",
            "There are rumors of coastline far from here. Probably just travelers' tales.",
        },
        false_templates = {
            "The Western Ocean is made of liquid fire! That's why no one goes there!",
            "Beyond the desert is a waterfall that falls off the edge of the world!",
            "There's no ocean to the west. The empire has mapped everything. This is all there is.",
            "I found the Western Ocean! It's actually just a big lake! Very disappointing!",
        },
    },

    -- Ashen Archipelago (volcanic islands)
    [RumorSystem.TYPES.ASHEN_ARCHIPELAGO] = {
        true_templates = {
            "A sailor claimed he saw volcanic islands far west. Smoke rising from peaks surrounded by black water. No one believed him. He had cat folk navigation charts.",
            "Lizard folk astronomers have mapped islands in the western ocean using star positions. They don't share the charts. 'Not relevant to imperial concerns,' they say.",
            "I met a gnome who'd 'never been west.' Very specific denial. Why mention it unless they had been?",
            "There are islands in the Outer Waters. Active volcanoes. Someone lives there—settlements unmapped by any imperial cartographer.",
        },
        distorted_templates = {
            "I heard about islands somewhere distant. Volcanic? Or maybe just mountainous? Details are fuzzy.",
            "Someone mentioned smoke on the horizon far to the west. Could be islands. Could be mirages.",
            "There might be land in the distant ocean. Or it might just be fog and wishful thinking.",
            "Volcanic activity somewhere beyond the empire's reach. That's what a trader said. Might be exaggeration.",
        },
        false_templates = {
            "The volcanic islands are actually dragons sleeping! Don't wake them!",
            "There are no islands. The ocean is infinite and empty. Geography is simple.",
            "I've been to the archipelago! It's a resort destination! Very luxurious!",
            "The islands are a government conspiracy! They're hiding something!",
        },
    },

    -- Great Western Isle (distant continent)
    [RumorSystem.TYPES.GREAT_WESTERN_ISLE] = {
        true_templates = {
            "An old lizard folk—700 years at least—mentioned 'the western continent' in passing. Then refused to elaborate. 'Pre-war knowledge. Irrelevant now.'",
            "Elven sealed archives contain maps from before Calidar burned. One showed landmass west of volcanic islands. The Inquest classified it. Why classify geography?",
            "A drunk gnome let slip: 'Airship routes could reach that far, theoretically.' Reach where? 'Nowhere. I said nothing.'",
            "There's a whole other continent out there. Separated by desert and ocean. The empire doesn't acknowledge it because they can't control it.",
        },
        distorted_templates = {
            "I heard there's land far to the west. Maybe a continent? Maybe just big islands? No one's sure.",
            "Some old maps show things the empire's maps don't. Distant lands. Possibly inhabited.",
            "A scholar mentioned 'western territories' then immediately changed the subject. Suspicious.",
            "Long-lived races know geography the empire doesn't teach. Something about distant lands.",
        },
        false_templates = {
            "The western continent is where the gods live! Mortals can't reach it!",
            "There is no western land. The world is flat and we're at the edge!",
            "I rule the Great Western Isle! I commute here daily via magic carpet!",
            "The western continent is actually underwater! Atlantis-style!",
        },
    },

    -- Frostbound Reach (northern ice)
    [RumorSystem.TYPES.FROSTBOUND_REACH] = {
        true_templates = {
            "Dwarven holds extend into permafrost. The deep miners report ice above the stone. They don't talk about it openly—empire doesn't like contradictions.",
            "Travel far enough north through the desert and the heat gives way. First it cools. Then it freezes. The sand becomes ice. Lizard folk know this. Humans don't.",
            "A dwarf told me their northernmost chambers touch frozen ground on all sides. 'We don't go to the surface there. It's ice. Forever ice.'",
            "The empire claims the desert extends infinitely north. The dwarves know it turns to tundra, then ice. They're not interested in correcting imperial geography.",
        },
        distorted_templates = {
            "I heard the northern desert gets cold eventually. Or maybe that's just at night? Hard to say.",
            "There might be ice to the far north. A dwarf mentioned frozen tunnels once. Might have misheard.",
            "The desert can't go on forever, right? Eventually it must become something else. Mountains? Ice?",
            "Someone said the world has a northern pole. Like a theoretical endpoint. Not sure if it's real.",
        },
        false_templates = {
            "The northern ice is guarded by frost giants! That's why no one goes there!",
            "There is no ice. The desert is infinite and hot. Forever and ever.",
            "I've been to the Frostbound Reach! It's tropical! Very confusing!",
            "The ice is actually solid clouds! You can walk on the sky there!",
        },
    },

    -- Beyond Empire (general knowledge that world is bigger)
    [RumorSystem.TYPES.BEYOND_EMPIRE] = {
        true_templates = {
            "The empire controls the central continent. That's not the same as controlling 'the world.' Long-lived races know the difference. They just don't say it.",
            "Official maps end where imperial authority ends. Everything beyond is labeled 'impassable' or omitted. Convenient way to avoid uncomfortable questions.",
            "Elves remember when borders were different. Gnomes maintain their own cartography. Lizard folk preserve ancient charts. None of it matches imperial records.",
            "The world doesn't end where the empire says it does. It's political fiction, not geographical fact. Most humans just don't realize it.",
        },
        distorted_templates = {
            "I heard the empire doesn't map everything. Some places are left blank. Deliberately? Accidentally?",
            "There's more to the world than official geography admits. Maybe. People whisper about it.",
            "Long-lived races seem to know things about distant places. They don't share. Why not?",
            "The maps we're taught might be incomplete. Or politically edited. Hard to confirm.",
        },
        false_templates = {
            "The empire controls literally everything! The maps are perfect and complete!",
            "There is no 'beyond the empire.' This is the entire world. Geography is settled.",
            "Secret lands are fantasy! Everything is documented! Trust the system!",
            "I know what's beyond the empire: nothing! Absolute void! The maps prove it!",
        },
    },

    -- Hidden Charts (lizard folk/elven maps)
    [RumorSystem.TYPES.HIDDEN_CHARTS] = {
        true_templates = {
            "Lizard folk have charts going back thousands of years. Pre-empire geography. They don't share them—'not relevant to current politics,' they claim.",
            "Elven sealed archives contain pre-war maps. Different coastlines. Distant lands. The Inquest keeps them classified. 'Security reasons.'",
            "A cat folk trader showed me a navigation chart. It had coastlines I didn't recognize. 'Family heirloom,' she said. 'Very old routes.'",
            "The oldest maps don't match the new ones. Borders have changed. Some lands have vanished from official record. Others were never recorded at all.",
        },
        distorted_templates = {
            "I heard old races keep secret maps. Different from what we're taught. Might be outdated. Might be truth.",
            "There are charts that show places official maps don't. Kept by who? Why? Unclear.",
            "Someone mentioned 'pre-imperial cartography.' Maps from before the current order. Where are they now?",
            "Ancient navigation records exist. The empire doesn't reference them. Interesting oversight.",
        },
        false_templates = {
            "The secret charts lead to treasure! Infinite treasure! I'm sure of it!",
            "Old maps are fiction! Modern maps are perfect! No need for alternatives!",
            "I have the hidden charts! They're invisible! Very exclusive!",
            "The lizard folk charts are actually recipes! Culinary secrets, not geography!",
        },
    },

    -- Cyclical World (geographic patterns)
    [RumorSystem.TYPES.CYCLICAL_WORLD] = {
        true_templates = {
            "A lizard folk astronomer mentioned something: 'Geography follows patterns. Land gives way to sand. Sand to water. Water to land. Cycles repeat.' Then walked away.",
            "Look at a map—really look. North: land, desert, ice. West: land, desert, ocean. East: land, ocean, islands. The pattern repeats. The world is cyclical.",
            "An elf showed me old charts. 'The world is larger than one continent,' she said. 'Barriers separate landmasses, but barriers are crossable. Always have been.'",
            "Dwarves understand stone. Gnomes understand engineering. Lizard folk understand cycles. They all know: the empire's continent is one among many. They just don't say it.",
        },
        distorted_templates = {
            "I heard geography follows some kind of pattern. Repetition across distances. Not sure what it means.",
            "The world might be cyclical. Or symmetrical. Someone smart said that once. Can't remember details.",
            "There's a theory about landmasses and oceans alternating. Academic speculation, probably.",
            "Long-lived races talk about 'geographic cycles.' Sounds complicated. I didn't follow.",
        },
        false_templates = {
            "The world is a perfect cube! Cycles are just corners! It's geometric!",
            "Geography doesn't follow patterns! It's random! Chaos theory proves it!",
            "I discovered the cyclical world theory! I'm a genius! No one else knows!",
            "The cycle means the world will reset! Geography will shuffle! Panic now!",
        },
    },

    -- HOLLOW EARTH DINOSAURS - General sightings/mentions
    [RumorSystem.TYPES.HOLLOW_EARTH_DINOSAURS] = {
        true_templates = {
            "A miner swears he heard something massive moving in a deep shaft. Breathing. Scales scraping stone.",
            "They found claw marks in the deepest mine. Ten feet long. Three-toed. Nothing on surface makes marks like that.",
            "My grandfather's journal mentioned 'thunder lizards' in a cave. Thought he was mad. Now I'm not sure.",
            "Goblins have a word: 'Sauros.' They say it means 'the scaled ones who walk below.'",
            "A dwarf refused to talk about floor 20. Just said: 'Some things from the deep should stay there. Big things. Old things.'",
            "Found massive bones in a collapsed tunnel. Not human. Not any known creature. Ribcage you could walk through.",
            "Expedition to floor 25 came back shaken. Wouldn't say what they saw. Just: 'Lizards. Bigger than houses. Moving.'",
            "A lizard folk trader looked uncomfortable when asked about deep caves. Said: 'Cousins we don't speak of. Very old cousins.'",
        },
        distorted_templates = {
            "Something big lives in the deep caves. Miners hear roaring sometimes. Could be anything, really.",
            "I heard there are giant lizards underground. Or maybe big snakes? Some kind of reptile.",
            "Old stories mention 'thunder beasts' in the depths. Probably exaggeration. Echoes sound scary down there.",
            "A friend said his uncle saw huge claw marks in a mine. Probably just tool marks. Right?",
            "Deep dungeons have strange sounds. Roars, or maybe just wind. Hard to tell.",
        },
        false_templates = {
            "Dragons live in every cave! I saw one myself! It talked to me!",
            "The emperor keeps pet dinosaurs in the palace basement!",
            "Lizard folk are secretly dinosaurs in disguise! Wake up!",
            "I found a dinosaur egg at the market! It's going to hatch any day!",
        },
    },

    -- INTELLIGENT SAURIANS - RARE rumors of intelligent dinosaur people
    [RumorSystem.TYPES.INTELLIGENT_SAURIANS] = {
        true_templates = {
            "A dwarf who delved too deep came back changed. Kept drawing lizard men with tools. With CITIES. Then he vanished into the mines again.",
            "Lizard folk elder slipped once: 'Cousins in the deep who never left.' When asked, claimed mistranslation. But their eyes said otherwise.",
            "Found carved stone in a deep ruin. Shows lizards standing upright, building structures. Empire calls it 'primitive art.' The craftsmanship suggests otherwise.",
            "An old gnome engineer whispered: 'Floor 30 breach showed cities. Not dwarven. Not human. Scaled architects. We sealed it and never spoke of it again.'",
            "Goblin bone-seeker mentioned 'scaled kings who built before the bones.' Said it casually, like everyone knows. Nobody else does.",
            "Expedition report—classified—mentioned 'bipedal reptilian entities demonstrating tool use and social structure' in hollow jungle breach. Then the report vanished.",
        },
        distorted_templates = {
            "I heard there are smart lizards in the deep. Or maybe it's a cult? Something about underground cities.",
            "Someone said lizard folk have 'deep cousins' but wouldn't explain. Probably family drama.",
            "A dwarf mentioned seeing structures in hollow earth that weren't dwarf-made. Didn't say what made them.",
            "Old carvings show lizards with tools. Could be symbolic. Or could be historical record. Hard to say.",
        },
        false_templates = {
            "Dinosaurs built the pyramids! The empire doesn't want you to know!",
            "I met a talking dinosaur in the tavern! He bought me a drink!",
            "Lizard folk are actually dinosaurs who learned to shapeshift!",
            "The emperor is secretly a dinosaur in a human suit!",
        },
    },

    -- DEEP JUNGLE RACES - Rumors of civilizations in underground jungles
    [RumorSystem.TYPES.DEEP_JUNGLE_RACES] = {
        true_templates = {
            "They say there are jungles underground. Impossible, but sailors who crossed to western isles swear they heard jungle sounds from volcanic tubes.",
            "A goblin mentioned 'the green dark.' When pressed, said old tales speak of forests that grow without sun, deep below.",
            "Rare fungi from deep caves have JUNGLE spores in them. Analysis confirmed. Jungle spores. Underground. How?",
            "Lizard folk won't talk about it directly, but they have a phrase: 'the ancestral green.' Not the desert. Somewhere else. Somewhere below.",
            "Found tropical plants growing in a floor 22 breach. Botanist said they need heat and humidity. We're miles underground. Where did they come from?",
            "A dwarf mentioned 'warm wet places deep below where green things grow in the dark.' Refused to elaborate. Just sealed the tunnel.",
        },
        distorted_templates = {
            "I heard there are plants underground. Mushrooms, probably. Maybe glowing ones.",
            "Someone mentioned underground forests. Probably meant the fungal zones. Those do exist.",
            "Deep caves have weird ecosystems. Heat from below, I think. Creates microclimates.",
            "A trader talked about 'jungle sounds from underground.' Probably just echoes.",
        },
        false_templates = {
            "The entire underground is actually one giant tree!",
            "Underground jungles are filled with gold! Everyone who goes there gets rich!",
            "I grew tomatoes in my basement! Proof of underground agriculture!",
            "The empire is hiding underground paradise from us! Revolution now!",
        },
    },

    -- HOLLOW EARTH WHISPERS - General hollow earth existence rumors
    [RumorSystem.TYPES.HOLLOW_EARTH_WHISPERS] = {
        true_templates = {
            "Dwarves don't talk about it, but they know. Something exists below their deepest holds. They sealed the passages for a reason.",
            "Empire calls it geological impossibility. Dwarves call it 'the deep truth we don't share.' Lizard folk just smile and change the subject.",
            "A geomancer examined deep breach data. Privately concluded: 'There's space down there. Vast space. The official position is... politically necessary.'",
            "Goblin legends, lizard folk hints, dwarf silences—they all point the same direction. Down. To something the empire won't acknowledge.",
            "Floor 30 breaches don't hit rock. They hit AIR. Open caverns extending beyond sight. The empire classifies these reports as 'instrumentation error.'",
            "Every deep-delving culture knows. Every one. They just don't tell humans. Because humans control the maps, and the maps say it doesn't exist.",
        },
        distorted_templates = {
            "I heard there are big caves underground. Really big. Like, miles big.",
            "Someone said the world is hollow. Probably just cave systems. Really extensive ones.",
            "Deep mines hit spaces that don't make sense geologically. At least, that's the rumor.",
            "There's talk about realms beneath the surface. Probably exaggeration. Probably.",
        },
        false_templates = {
            "The world is completely hollow! We live on the INSIDE of a sphere!",
            "Hollow earth is where the gods live! I have proof!",
            "Every cave connects to the hollow center! It's all one space!",
            "The empire is hollow earth! We're already there! Wake up!",
        },
    },
}

-- Direction names for vague references
local DIRECTIONS = {"north", "south", "east", "west", "northeast", "northwest", "southeast", "southwest"}

-- Terrain types for vague references
local TERRAINS = {"forest", "mountains", "swamp", "plains", "hills", "wilderness"}

-- Vague location names
local VAGUE_LOCATIONS = {
    "that village", "the old place", "somewhere nearby", "a town I forget",
    "over yonder", "past the hills", "beyond the forest", "the next town over",
}

-- False details for distorted rumors
local FALSE_DETAILS = {
    "glowing red eyes", "three arms", "speaks in riddles", "wears a purple cloak",
    "only attacks on Wednesdays", "leaves flowers at the scene", "is actually quite polite",
    "smells of lavender", "whistles while they work", "has a distinctive limp",
}

-- Wrong targets for distorted killer rumors
local WRONG_TARGETS = {
    "left-handed people", "redheads", "bakers", "people named Gerald",
    "those who wear hats", "early risers", "night owls", "cheese enthusiasts",
}

-- Killer nicknames for true rumors
local KILLER_NAMES = {
    "Shadow Blade", "The Nightwalker", "Crimson Hand", "The Silent One",
    "Gravedigger", "The Weeping Killer", "Bloodmoon", "The Phantom",
}

-- Monster types for sightings
local MONSTER_TYPES = {
    "troll", "ogre", "giant spider", "dire wolf", "wyvern", "basilisk",
    "manticore", "chimera", "cockatrice", "harpy",
}

-- Initialize the rumor system
-- OPTIMIZED: Uses flag to skip redundant work on repeated calls
function RumorSystem.init(gameState)
    -- Always update state reference (in case it changed)
    state = gameState

    -- Quick return if already initialized and rumors exist
    if _initialized and state.rumors then
        return RumorSystem
    end

    -- Initialize rumor storage if not present
    if not state.rumors then
        state.rumors = {
            active = {},           -- Currently circulating rumors
            archived = {},         -- Old rumors no longer spreading
            townKnowledge = {},    -- What each town "knows"
            lastUpdate = 0,        -- Last day rumors were updated
            serialKillers = {},    -- Active serial killer events
            merchantRoutes = {},   -- Merchant travel patterns for spreading
        }
    end

    _initialized = true
    return RumorSystem
end

-- Reset the initialization flag so the system re-initializes on next init() call.
-- Must be called when switching save slots to ensure the new slot's data is loaded.
function RumorSystem.reset()
    _initialized = false
    state = nil
end

-- Get a random element from a table
local function randomElement(tbl)
    if not tbl or #tbl == 0 then return nil end
    return tbl[math.random(#tbl)]
end

-- Use shared MathUtil module for direction/distance calculations
local MathUtil = require("mathutil")
local getDirection = MathUtil.getDirection
local getDistance = MathUtil.getDistance

-- Fill in template placeholders
local function fillTemplate(template, data)
    local result = template

    for key, value in pairs(data) do
        result = result:gsub("{" .. key .. "}", tostring(value))
    end

    -- Fill any remaining placeholders with defaults
    result = result:gsub("{location}", data.location or data.locationName or "a distant place")
    result = result:gsub("{vague_location}", randomElement(VAGUE_LOCATIONS) or "somewhere")
    result = result:gsub("{other_location}", randomElement(VAGUE_LOCATIONS) or "another place")
    result = result:gsub("{wrong_location}", randomElement(VAGUE_LOCATIONS) or "that town")
    result = result:gsub("{direction}", randomElement(DIRECTIONS) or "somewhere")
    result = result:gsub("{terrain}", randomElement(TERRAINS) or "wilderness")
    result = result:gsub("{false_detail}", randomElement(FALSE_DETAILS) or "unusual features")
    result = result:gsub("{wrong_target}", randomElement(WRONG_TARGETS) or "random people")
    result = result:gsub("{killer_name}", randomElement(KILLER_NAMES) or "The Killer")
    result = result:gsub("{monster}", randomElement(MONSTER_TYPES) or "beast")
    result = result:gsub("{count}", tostring(data.count or math.random(3, 12)))
    result = result:gsub("{region}", data.region or "the region")
    result = result:gsub("{player_name}", data.player_name or "an adventurer")
    result = result:gsub("{victim_name}", data.victim_name or "someone")

    return result
end

-- Create a new rumor from a world event
function RumorSystem.createRumorFromEvent(eventType, eventData)
    if not state or not state.rumors then return nil end

    local templates = RUMOR_TEMPLATES[eventType]
    if not templates then return nil end

    local rumor = {
        id = #state.rumors.active + 1,
        type = eventType,
        createdDay = state.daysPassed or 0,
        sourceX = eventData.x,
        sourceY = eventData.y,
        sourceLocation = eventData.locationName,
        isTrue = true,
        accuracy = RumorSystem.ACCURACY.TRUE,
        originalText = fillTemplate(randomElement(templates.true_templates), eventData),
        currentText = nil,  -- Set below
        spreadCount = 0,
        knownInTowns = {},  -- Towns that have heard this rumor
        eventData = eventData,  -- Original event data for verification
    }

    rumor.currentText = rumor.originalText

    -- Add to origin town's knowledge if applicable
    if eventData.townId then
        rumor.knownInTowns[eventData.townId] = {
            accuracy = RumorSystem.ACCURACY.TRUE,
            text = rumor.originalText,
            heardDay = state.daysPassed or 0,
        }
    end

    table.insert(state.rumors.active, rumor)

    return rumor
end

-- Create a completely false rumor (random gossip)
function RumorSystem.createFalseRumor(rumorType, nearTownId)
    if not state or not state.rumors then return nil end

    rumorType = rumorType or randomElement({
        RumorSystem.TYPES.MONSTER_SIGHTING,
        RumorSystem.TYPES.TREASURE,
        RumorSystem.TYPES.GHOST_SIGHTING,
        RumorSystem.TYPES.CURSE,
        RumorSystem.TYPES.PROPHECY,
    })

    local templates = RUMOR_TEMPLATES[rumorType]
    if not templates then return nil end

    local rumor = {
        id = #state.rumors.active + 1,
        type = rumorType,
        createdDay = state.daysPassed or 0,
        sourceX = nil,
        sourceY = nil,
        sourceLocation = nil,
        isTrue = false,
        accuracy = RumorSystem.ACCURACY.FALSE,
        originalText = fillTemplate(randomElement(templates.false_templates), {}),
        currentText = nil,
        spreadCount = 0,
        knownInTowns = {},
    }

    rumor.currentText = rumor.originalText

    -- Add to starting town if specified
    if nearTownId then
        rumor.knownInTowns[nearTownId] = {
            accuracy = RumorSystem.ACCURACY.FALSE,
            text = rumor.originalText,
            heardDay = state.daysPassed or 0,
        }
    end

    table.insert(state.rumors.active, rumor)

    return rumor
end

--[[
    VOID COVENANT RUMORS
    Special handling for the dark subplot rumors
    These only spawn in/near Calidar wasteland regions
]]

-- Covenant rumor types (for easy checking)
local COVENANT_RUMOR_TYPES = {
    [RumorSystem.TYPES.VOID_COVENANT] = true,
    [RumorSystem.TYPES.CALIDAR_TRUTH] = true,
    [RumorSystem.TYPES.SEALED_ARCHIVES] = true,
    [RumorSystem.TYPES.GLASSED_WASTES] = true,
    [RumorSystem.TYPES.VOID_TOUCHED] = true,
}

-- Check if a rumor type is covenant-related
function RumorSystem.isCovenantRumor(rumorType)
    return COVENANT_RUMOR_TYPES[rumorType] == true
end

-- Check if a location is in/near Calidar wastelands
function RumorSystem.isNearCalidar(townId, townData)
    if not townData then return false end

    -- Check region name
    local calidarRegions = {
        "calidar", "glassed", "wastes", "vitrified", "scorched",
        "desert", "ruins", "forbidden", "wasteland"
    }

    local regionName = (townData.region or ""):lower()
    local townName = (townData.name or ""):lower()

    for _, keyword in ipairs(calidarRegions) do
        if regionName:find(keyword) or townName:find(keyword) then
            return true
        end
    end

    -- Check if town has calidar-related tags
    if townData.tags then
        for _, tag in ipairs(townData.tags) do
            local tagLower = tag:lower()
            for _, keyword in ipairs(calidarRegions) do
                if tagLower:find(keyword) then
                    return true
                end
            end
        end
    end

    return false
end

-- Create a Covenant rumor (only in appropriate regions)
function RumorSystem.createCovenantRumor(townId, townData, rumorType)
    if not state or not state.rumors then return nil end

    -- Only spawn in Calidar-adjacent regions
    if not RumorSystem.isNearCalidar(townId, townData) then
        return nil
    end

    -- Pick a random covenant rumor type if not specified
    rumorType = rumorType or randomElement({
        RumorSystem.TYPES.VOID_COVENANT,
        RumorSystem.TYPES.CALIDAR_TRUTH,
        RumorSystem.TYPES.SEALED_ARCHIVES,
        RumorSystem.TYPES.GLASSED_WASTES,
        RumorSystem.TYPES.VOID_TOUCHED,
    })

    local templates = RUMOR_TEMPLATES[rumorType]
    if not templates then return nil end

    -- These rumors have a chance to be true (based on proximity to actual events)
    local isTrue = math.random() < 0.6  -- 60% chance true near Calidar
    local accuracy = isTrue and RumorSystem.ACCURACY.MOSTLY_TRUE or RumorSystem.ACCURACY.HALF_TRUE

    local templateList = isTrue and templates.true_templates or templates.distorted_templates
    local text = fillTemplate(randomElement(templateList), {
        location = townData and townData.name or "the wastes",
    })

    local rumor = {
        id = #state.rumors.active + 1,
        type = rumorType,
        createdDay = state.daysPassed or 0,
        sourceX = townData and townData.x,
        sourceY = townData and townData.y,
        sourceLocation = townData and townData.name,
        isTrue = isTrue,
        accuracy = accuracy,
        originalText = text,
        currentText = text,
        spreadCount = 0,
        knownInTowns = {},
        isCovenantLore = true,  -- Flag for special handling
    }

    -- Add to starting town
    if townId then
        rumor.knownInTowns[townId] = {
            accuracy = accuracy,
            text = text,
            heardDay = state.daysPassed or 0,
        }
    end

    table.insert(state.rumors.active, rumor)

    return rumor
end

-- Get all covenant rumors the player has heard
function RumorSystem.getDiscoveredCovenantRumors()
    if not state or not state.rumors then return {} end

    local covenantRumors = {}
    for _, rumor in ipairs(state.rumors.active) do
        if rumor.isCovenantLore or COVENANT_RUMOR_TYPES[rumor.type] then
            table.insert(covenantRumors, rumor)
        end
    end

    return covenantRumors
end

-- Distort a rumor as it spreads
function RumorSystem.distortRumor(rumor, fromTownId, toTownId)
    if not rumor then return nil end

    local templates = RUMOR_TEMPLATES[rumor.type]
    if not templates then return rumor.currentText end

    -- Determine new accuracy (degrades with each spread)
    local newAccuracy = rumor.accuracy
    local distortionChance = 0.4  -- 40% chance to distort each spread

    if math.random() < distortionChance then
        if newAccuracy >= RumorSystem.ACCURACY.TRUE then
            newAccuracy = RumorSystem.ACCURACY.MOSTLY_TRUE
        elseif newAccuracy >= RumorSystem.ACCURACY.MOSTLY_TRUE then
            newAccuracy = RumorSystem.ACCURACY.HALF_TRUE
        elseif newAccuracy >= RumorSystem.ACCURACY.HALF_TRUE then
            newAccuracy = RumorSystem.ACCURACY.MOSTLY_FALSE
        else
            newAccuracy = RumorSystem.ACCURACY.FALSE
        end
    end

    -- Generate appropriate text based on accuracy
    local newText
    local eventData = rumor.eventData or {}

    if newAccuracy >= RumorSystem.ACCURACY.MOSTLY_TRUE then
        -- Still mostly accurate
        newText = rumor.originalText
    elseif newAccuracy >= RumorSystem.ACCURACY.HALF_TRUE then
        -- Use distorted template
        newText = fillTemplate(randomElement(templates.distorted_templates), eventData)
    else
        -- Use false template or heavily distorted
        if math.random() < 0.5 then
            newText = fillTemplate(randomElement(templates.false_templates), eventData)
        else
            newText = fillTemplate(randomElement(templates.distorted_templates), eventData)
        end
    end

    return newText, newAccuracy
end

-- Spread rumors between towns (called during day advance)
function RumorSystem.spreadRumors(WorldGen)
    if not state or not state.rumors then return end

    local currentDay = state.daysPassed or 0

    -- Don't spread more than once per day
    if currentDay <= state.rumors.lastUpdate then return end
    state.rumors.lastUpdate = currentDay

    -- Get all towns for spreading
    local towns = {}
    if WorldGen and WorldGen.getAnchorTowns then
        for _, town in ipairs(WorldGen.getAnchorTowns()) do
            local townX = (town.position and town.position.x) or town.x
            local townY = (town.position and town.position.y) or town.y
            table.insert(towns, {
                id = town.id,
                name = town.name,
                x = townX,
                y = townY,
            })
        end
    end

    -- Each rumor has a chance to spread to nearby towns
    for _, rumor in ipairs(state.rumors.active) do
        -- Rumors older than 30 days fade away
        if currentDay - rumor.createdDay > 30 then
            rumor.fading = true
        end

        if not rumor.fading then
            -- Try to spread to new towns
            for _, town in ipairs(towns) do
                if not rumor.knownInTowns[town.id] then
                    -- Check if any known town is close enough to spread
                    local canSpread = false
                    local closestKnownTown = nil
                    local closestDistance = 999

                    for knownTownId, _ in pairs(rumor.knownInTowns) do
                        -- Find this town's position
                        for _, t in ipairs(towns) do
                            if t.id == knownTownId then
                                local dist = getDistance(t.x, t.y, town.x, town.y)
                                if dist < closestDistance then
                                    closestDistance = dist
                                    closestKnownTown = knownTownId
                                end
                                break
                            end
                        end
                    end

                    -- Spread chance based on distance (closer = more likely)
                    if closestDistance < 20 then
                        local spreadChance = 0.3 - (closestDistance * 0.01)
                        if math.random() < spreadChance then
                            local newText, newAccuracy = RumorSystem.distortRumor(rumor, closestKnownTown, town.id)
                            rumor.knownInTowns[town.id] = {
                                accuracy = newAccuracy,
                                text = newText,
                                heardDay = currentDay,
                                heardFrom = closestKnownTown,
                            }
                            rumor.spreadCount = rumor.spreadCount + 1
                        end
                    end
                end
            end
        end
    end

    -- Archive fading rumors
    local stillActive = {}
    for _, rumor in ipairs(state.rumors.active) do
        if rumor.fading and currentDay - rumor.createdDay > 45 then
            table.insert(state.rumors.archived, rumor)
        else
            table.insert(stillActive, rumor)
        end
    end
    state.rumors.active = stillActive

    -- Cleanup old archived rumors to prevent memory leak
    -- Keep only the most recent 100 archived rumors
    if #state.rumors.archived > 100 then
        local toKeep = {}
        local startIdx = #state.rumors.archived - 50  -- Keep last 50
        for i = startIdx, #state.rumors.archived do
            table.insert(toKeep, state.rumors.archived[i])
        end
        state.rumors.archived = toKeep
    end

    -- Occasionally generate random false rumors
    if math.random() < 0.1 then  -- 10% chance per day
        local randomTown = randomElement(towns)
        if randomTown then
            RumorSystem.createFalseRumor(nil, randomTown.id)
        end
    end
end

-- Get rumors known in a specific town
function RumorSystem.getRumorsInTown(townId)
    if not state or not state.rumors then return {} end

    local townRumors = {}

    for _, rumor in ipairs(state.rumors.active) do
        local knowledge = rumor.knownInTowns[townId]
        if knowledge then
            table.insert(townRumors, {
                type = rumor.type,
                text = knowledge.text,
                accuracy = knowledge.accuracy,
                isTrue = rumor.isTrue,
                heardDay = knowledge.heardDay,
                isFresh = (state.daysPassed or 0) - knowledge.heardDay < 3,
            })
        end
    end

    return townRumors
end

-- Get a random rumor for NPC dialogue in a town
function RumorSystem.getRandomRumorForNPC(townId)
    local rumors = RumorSystem.getRumorsInTown(townId)

    if #rumors == 0 then
        -- No rumors in this town, return generic gossip
        return {
            text = randomElement({
                "Nothing much happening around here lately.",
                "It's been quiet. Too quiet, some might say.",
                "I haven't heard any interesting news lately.",
                "The weather's been strange, don't you think?",
                "Times are peaceful. For now, at least.",
            }),
            accuracy = RumorSystem.ACCURACY.TRUE,
            isTrue = true,
            type = "small_talk",
        }
    end

    -- Prefer fresh rumors
    local freshRumors = {}
    for _, r in ipairs(rumors) do
        if r.isFresh then
            table.insert(freshRumors, r)
        end
    end

    if #freshRumors > 0 then
        return randomElement(freshRumors)
    end

    return randomElement(rumors)
end

-- Generate rumors from lich battle events
function RumorSystem.onLichBattle(battleRecord, WorldGen)
    if not state or not battleRecord then return end

    RumorSystem.init(state)

    if battleRecord.defenderWins then
        -- Victory rumor
        RumorSystem.createRumorFromEvent(RumorSystem.TYPES.BATTLE, {
            x = battleRecord.tileX,
            y = battleRecord.tileY,
            locationName = battleRecord.townName,
            count = battleRecord.attackerCasualties,
            townId = battleRecord.townId,
        })
    else
        -- Village destroyed rumor
        RumorSystem.createRumorFromEvent(RumorSystem.TYPES.VILLAGE_DESTROYED, {
            x = battleRecord.tileX,
            y = battleRecord.tileY,
            locationName = battleRecord.townName,
            count = battleRecord.villagePopulation,
        })
    end
end

-- Generate rumors from lich activity
function RumorSystem.onLichActivity(lichLair, WorldGen)
    if not state or not lichLair then return end

    RumorSystem.init(state)

    -- Find nearest town to attribute the rumor source
    local nearestTownId = nil
    if WorldGen and WorldGen.getAnchorTowns then
        local minDist = 999
        for _, town in ipairs(WorldGen.getAnchorTowns()) do
            local townX = (town.position and town.position.x) or town.x
            local townY = (town.position and town.position.y) or town.y
            local dist = getDistance(lichLair.x, lichLair.y, townX, townY)
            if dist < minDist then
                minDist = dist
                nearestTownId = town.id
            end
        end
    end

    RumorSystem.createRumorFromEvent(RumorSystem.TYPES.LICH_ACTIVITY, {
        x = lichLair.x,
        y = lichLair.y,
        locationName = "the corrupted lands",
        townId = nearestTownId,
        count = lichLair.corruptedTiles or 0,
    })
end

-- Generate serial killer event and rumor
function RumorSystem.spawnSerialKiller(townId, townName, townX, townY)
    if not state then return nil end

    RumorSystem.init(state)

    local killer = {
        id = #state.rumors.serialKillers + 1,
        townId = townId,
        townName = townName,
        x = townX,
        y = townY,
        killCount = 0,
        active = true,
        name = randomElement(KILLER_NAMES),
        createdDay = state.daysPassed or 0,
    }

    table.insert(state.rumors.serialKillers, killer)

    return killer
end

-- Update serial killer (called during day advance)
function RumorSystem.updateSerialKillers()
    if not state or not state.rumors or not state.rumors.serialKillers then return end

    for _, killer in ipairs(state.rumors.serialKillers) do
        if killer.active then
            -- 30% chance to kill per day
            if math.random() < 0.3 then
                killer.killCount = killer.killCount + 1

                -- Generate rumor about the killing
                if killer.killCount == 1 or killer.killCount == 3 or killer.killCount == 5 then
                    RumorSystem.createRumorFromEvent(RumorSystem.TYPES.SERIAL_KILLER, {
                        x = killer.x,
                        y = killer.y,
                        locationName = killer.townName,
                        townId = killer.townId,
                        count = killer.killCount,
                        killer_name = killer.name,
                    })
                end

                -- Killer might move after many kills
                if killer.killCount >= 7 then
                    killer.active = false  -- Caught or fled
                end
            end
        end
    end
end

-- Generate werewolf sighting rumor
function RumorSystem.onWerewolfSighting(x, y, locationName, nearTownId)
    if not state then return end

    RumorSystem.init(state)

    RumorSystem.createRumorFromEvent(RumorSystem.TYPES.WEREWOLF, {
        x = x,
        y = y,
        locationName = locationName,
        townId = nearTownId,
    })
end

-- Generate vampire sighting rumor
function RumorSystem.onVampireSighting(x, y, locationName, nearTownId)
    if not state then return end

    RumorSystem.init(state)

    RumorSystem.createRumorFromEvent(RumorSystem.TYPES.VAMPIRE, {
        x = x,
        y = y,
        locationName = locationName,
        townId = nearTownId,
    })
end

-- Generate vampire attack rumor (someone was bitten)
function RumorSystem.onVampireAttack(townId, townName, victimName, wasDetected)
    if not state then return end

    RumorSystem.init(state)

    -- Detected attacks always generate true rumors
    -- Undetected attacks have a chance to still generate distorted rumors (witnesses)
    if wasDetected or math.random() < 0.3 then
        local rumor = RumorSystem.createRumorFromEvent(RumorSystem.TYPES.VAMPIRE_ATTACK, {
            locationName = townName,
            townId = townId,
            victim_name = victimName or "a citizen",
        })

        -- If not detected, the rumor starts already distorted
        if not wasDetected and rumor then
            rumor.accuracy = RumorSystem.ACCURACY.HALF_TRUE
            local templates = RUMOR_TEMPLATES[RumorSystem.TYPES.VAMPIRE_ATTACK]
            if templates and templates.distorted_templates then
                rumor.currentText = rumor.originalText  -- Keep original for true version
            end
        end
    end
end

-- Generate vampire epidemic rumor (multiple vampires in city)
function RumorSystem.onVampireEpidemic(townId, townName, vampireCount)
    if not state then return end

    RumorSystem.init(state)

    -- Epidemics are always noticeable
    RumorSystem.createRumorFromEvent(RumorSystem.TYPES.VAMPIRE_EPIDEMIC, {
        locationName = townName,
        townId = townId,
        count = vampireCount,
    })
end

-- Generate Holy City purge rumor
function RumorSystem.onVampirePurge(townId, townName, vampiresSlain)
    if not state then return end

    RumorSystem.init(state)

    -- Purges are very public events
    local rumor = RumorSystem.createRumorFromEvent(RumorSystem.TYPES.VAMPIRE_PURGE, {
        locationName = townName,
        townId = townId,
        count = vampiresSlain,
    })

    -- Purge rumors spread faster (add to multiple nearby towns immediately)
    if rumor then
        rumor.spreadCount = 3  -- Starts with higher spread count
    end
end

-- Generate player vampire rumor (player is known to be vampire)
function RumorSystem.onPlayerVampireRevealed(townId, townName, playerName)
    if not state then return end

    RumorSystem.init(state)

    RumorSystem.createRumorFromEvent(RumorSystem.TYPES.VAMPIRE_PLAYER, {
        locationName = townName,
        townId = townId,
        player_name = playerName or "the adventurer",
    })
end

-- Generate player transformation rumor (player became vampire)
function RumorSystem.onPlayerBecameVampire(playerName, locationName)
    if not state then return end

    RumorSystem.init(state)

    -- This starts as a vague rumor that spreads and becomes clearer
    local rumor = RumorSystem.createRumorFromEvent(RumorSystem.TYPES.VAMPIRE_PLAYER, {
        locationName = locationName or "the wilderness",
        player_name = playerName or "an adventurer",
    })

    -- Transformation rumors start vague
    if rumor then
        rumor.accuracy = RumorSystem.ACCURACY.MOSTLY_FALSE
        rumor.currentText = "I heard an adventurer fell to darkness somewhere. Turned into something unholy..."
    end
end

-- Generate Luminary patrol rumor (patrol spotted in area)
function RumorSystem.onLuminaryPatrol(x, y, nearbyTownName)
    if not state then return end

    RumorSystem.init(state)

    -- Create rumor about patrol sighting
    local rumor = RumorSystem.createRumorFromEvent(RumorSystem.TYPES.LUMINARY_PATROL, {
        locationName = nearbyTownName or "the wilderness",
        x = x,
        y = y,
    })

    -- Patrol rumors spread quickly (people notice armed patrols)
    if rumor then
        rumor.spreadCount = 2
    end
end

-- Check for vampire-related events in a town and generate appropriate rumors
function RumorSystem.checkTownVampireStatus(townId, townName, vampireCount, totalPopulation)
    if not state then return end

    RumorSystem.init(state)

    -- Generate epidemic rumor if vampire count is significant
    if vampireCount >= 3 then
        -- Check if we already have an epidemic rumor for this town
        local hasEpidemicRumor = false
        for _, rumor in ipairs(state.rumors.active) do
            if rumor.type == RumorSystem.TYPES.VAMPIRE_EPIDEMIC and
               rumor.knownInTowns[townId] then
                hasEpidemicRumor = true
                break
            end
        end

        if not hasEpidemicRumor then
            RumorSystem.onVampireEpidemic(townId, townName, vampireCount)
        end
    end

    -- Generate general unease rumors if any vampires present
    if vampireCount >= 1 and math.random() < 0.2 then
        RumorSystem.createFalseRumor(RumorSystem.TYPES.VAMPIRE, townId)
    end
end

-- Generate vampire lair in town rumor (hidden vampire nest within the settlement)
function RumorSystem.onVampireLairInTown(townId, townName)
    if not state then return end

    RumorSystem.init(state)

    -- Check if we already have a lair rumor for this town
    for _, rumor in ipairs(state.rumors.active) do
        if rumor.type == RumorSystem.TYPES.VAMPIRE_LAIR_IN_TOWN and
           rumor.knownInTowns and rumor.knownInTowns[townId] then
            return  -- Already have this rumor
        end
    end

    local rumor = RumorSystem.createRumorFromEvent(RumorSystem.TYPES.VAMPIRE_LAIR_IN_TOWN, {
        locationName = townName,
        townId = townId,
    })

    -- This is a serious warning - starts somewhat accurate
    if rumor then
        rumor.accuracy = RumorSystem.ACCURACY.MOSTLY_TRUE
    end
end

-- Generate vampire infiltration rumor (vampires entering town from nearby den)
function RumorSystem.onVampireInfiltration(townId, townName, denDirection)
    if not state then return end

    RumorSystem.init(state)

    local rumor = RumorSystem.createRumorFromEvent(RumorSystem.TYPES.VAMPIRE_INFILTRATION, {
        locationName = townName,
        townId = townId,
        direction = denDirection or "nearby",
    })

    -- Infiltration rumors are somewhat vague initially
    if rumor then
        rumor.accuracy = RumorSystem.ACCURACY.HALF_TRUE
    end
end

-- Generate ghost sighting rumor
function RumorSystem.onGhostSighting(x, y, locationName, nearTownId)
    if not state then return end

    RumorSystem.init(state)

    RumorSystem.createRumorFromEvent(RumorSystem.TYPES.GHOST_SIGHTING, {
        x = x,
        y = y,
        locationName = locationName,
        townId = nearTownId,
    })
end

-- Check if a rumor is true based on world state
function RumorSystem.verifyRumor(rumor, WorldGen)
    if not rumor or not WorldGen then return nil end

    -- For true rumors with source coordinates, check if the event still exists
    if rumor.isTrue and rumor.sourceX and rumor.sourceY then
        local tile = WorldGen.getTile(rumor.sourceX, rumor.sourceY)
        if not tile then return nil end

        if rumor.type == RumorSystem.TYPES.LICH_ACTIVITY then
            return tile.type == "corrupted" or tile.corruptedBy ~= nil
        elseif rumor.type == RumorSystem.TYPES.VILLAGE_DESTROYED then
            return tile.type == "ruins" and tile.wasVillage
        end
    end

    return rumor.isTrue
end

-- Get accuracy description for UI
function RumorSystem.getAccuracyDescription(accuracy)
    if accuracy >= RumorSystem.ACCURACY.TRUE then
        return "Reliable", {0.5, 0.8, 0.5}
    elseif accuracy >= RumorSystem.ACCURACY.MOSTLY_TRUE then
        return "Mostly Accurate", {0.6, 0.8, 0.4}
    elseif accuracy >= RumorSystem.ACCURACY.HALF_TRUE then
        return "Questionable", {0.8, 0.8, 0.4}
    elseif accuracy >= RumorSystem.ACCURACY.MOSTLY_FALSE then
        return "Dubious", {0.8, 0.6, 0.4}
    else
        return "Gossip", {0.7, 0.5, 0.5}
    end
end

-- NPC dialogue wrapper - returns formatted rumor for dialogue
function RumorSystem.getNPCRumorDialogue(townId)
    local rumor = RumorSystem.getRandomRumorForNPC(townId)

    local prefixes = {
        "Have you heard? ",
        "Word is that ",
        "People are saying ",
        "I heard a rumor that ",
        "Between you and me, ",
        "Don't tell anyone, but ",
        "A traveler told me ",
        "The merchants say ",
    }

    local suffixes = {
        "",
        " But who knows if it's true.",
        " Take it with a grain of salt.",
        " At least that's what I heard.",
        " Scary times, friend.",
        " Best to be careful.",
        " Make of that what you will.",
    }

    local prefix = randomElement(prefixes)
    local suffix = randomElement(suffixes)

    -- Lowercase the first letter of the rumor text if adding prefix
    local text = rumor.text
    if #text > 0 then
        text = text:sub(1, 1):lower() .. text:sub(2)
    end

    return prefix .. text .. suffix, rumor
end

return RumorSystem
