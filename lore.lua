-- Lore System for Tavern Quest
-- A comprehensive world-building module with Places, People, and Factions

local Lore = {}

-- Font cache for performance
local FontCache = require("fontcache")
local function getFont(size)
    return FontCache.get(size)
end

-- UI State
local currentTab = "overview"
local scrollOffset = 0
local selectedEntry = nil
local searchText = ""

-- Colors
local colors = {
    bg = {0.08, 0.08, 0.12},
    panel = {0.12, 0.12, 0.18},
    panelBorder = {0.9, 0.7, 0.3},
    tabActive = {0.9, 0.7, 0.3},
    tabInactive = {0.3, 0.3, 0.35},
    text = {1, 1, 1},
    textDim = {0.6, 0.6, 0.65},
    textGold = {0.95, 0.8, 0.4},
    textRed = {0.9, 0.4, 0.4},
    textBlue = {0.4, 0.6, 0.9},
    textGreen = {0.4, 0.8, 0.5},
    textPurple = {0.7, 0.5, 0.9},
    accent = {0.9, 0.6, 0.2},
    scrollbar = {0.3, 0.3, 0.4},
    scrollbarThumb = {0.6, 0.5, 0.3}
}

-- Tab definitions
local tabs = {
    {id = "overview", name = "Overview", icon = ""},
    {id = "places", name = "Places", icon = ""},
    {id = "people", name = "People", icon = ""},
    {id = "factions", name = "Factions", icon = ""},
    {id = "history", name = "History", icon = ""},
    {id = "magic", name = "Magic", icon = ""}
}

--==============================================================================
-- WORLD LORE DATA
--==============================================================================

Lore.worldName = "The Known World"
Lore.motto = "The Age After War"

Lore.overview = {
    title = "The World - Year 500",
    subtitle = "The Age After War",
    description = [[
Five hundred years ago, the Last World War nearly erased civilization. Magic wielded without restraint shattered kingdoms, annihilated populations, and proved that uncontrolled power could destroy everything.

The Holy Dominion rose from the ashes, claiming divine mandate from Helios the Sun God. Using Heaven's Atlas, a weapon of apocalyptic power, they destroyed the elven homeland of Calidar, turning thriving forests into endless glass desert. The war ended not through victory, but exhaustion.

What followed was not peace, but order. Magic became illegal unless state-sanctioned or divinely ordained. The Luminary Inquest now enforces existence itself through documentation, purges, and terror. Independent powers like dwarven holds, orcish clans, and the gnomish collective maintain fragile autonomy through isolation or mobility. Hidden refuges like the Shadow Fen offer escape for those fleeing imperial law.

Memory endures. Resistance persists. The glass desert of Calidar reminds everyone what happens when power escapes restraint, or when it is wielded without mercy.]],

    currentEvents = {
        "The Luminary Inquest expands enforcement of documentation requirements",
        "Elves document imperial abuses while publicly complying",
        "The Shadow Fen Commune thrives behind magical concealment and infernal pacts",
        "Orc clans remain fragmented while imperial strategists watch nervously for signs of reunification",
        "The Veiled Hand eliminates officials who authorize escalating atrocities",
        "Goblin resistance cells continue multi-generational insurgency",
        "The Wastes of Calidar stand as monument to Heaven's Atlas and warning against uncontrolled power"
    }
}

--==============================================================================
-- PLACES
--==============================================================================

Lore.places = {
    {
        id = "holy_dominion",
        name = "The Holy Dominion",
        type = "Imperial Heartland",
        region = "Central Continent",
        description = [[
The political and religious center of the known world. The Holy Dominion sprawls across fertile plains, river valleys, and forested regions, the most developed and populated territory in existence.

The capital city houses the Grand Cathedral of Helios, seat of religious authority. From here, the Luminary Inquest dispatches white-cloaked enforcers across all imperial territory to hunt vampires, demons, and unsanctioned magic users.

The Dominion is home to both humans and integrated elves. Elves serve as the bureaucratic backbone: administrators, archivists, legal scholars. They remember their destroyed homeland of Calidar but comply outwardly while documenting everything for future judgment.]],
        notableLocations = {
            "The Imperial Capital - Seat of imperial and religious authority",
            "Grand Cathedral of Helios - Headquarters of faith and enforcement",
            "Southern Elven Districts - Where Calidar survivors were resettled",
            "Trade Roads - Connecting all regions of the empire",
            "Luminary Garrison Posts - Enforcement network across territory"
        },
        currentStatus = "Dominant continental power. Controls most populated regions."
    },
    {
        id = "dwarven_mountains",
        name = "Dwarven Mountains",
        type = "Mountain Range",
        region = "Northern Peaks",
        description = [[
Towering northern mountains rich with minerals and gems. The Free Holds of Stone lie deep underground, vast cities carved from living rock, connected by ancient tunnel networks.

The dwarves govern through guild councils with rotating leadership. No kings, no private property, no hierarchy. Stone-born reproduction means no biological parents, so every dwarf is equally a child of the stone.

The empire attempted to impose authority and secure exclusive mining rights. All attempts failed. The dwarves trade finished goods for grain through fortified gates but refuse political subordination. Their holds have never been conquered.]],
        notableLocations = {
            "The Deep Holds - Vast underground cities",
            "Trade Gates - Fortified surface posts for commerce only",
            "Sacred Stone Chambers - Where new dwarves emerge",
            "Guild Halls - Centers of collective governance",
            "Sealed Tunnels - Ancient passages closed after orc conflicts"
        },
        currentStatus = "Independent and isolationist. Borders closed to imperial authority."
    },
    {
        id = "orcish_steppes",
        name = "Orcish Steppes",
        type = "Grassland Territory",
        region = "Western Plains",
        description = [[
Vast grasslands where orcish clans follow seasonal routes. Once united under a Great Khan, the orcs formed the most effective military civilization the world has ever known. They reshaped borders, shattered kingdoms, and perfected mobile warfare.

That unity ended generations ago. The clans fragmented after the Khan's death and have never reunified. But the laws still exist. The routes are remembered. The old commands are taught.

Imperial propaganda labels them barbarian savages to justify constant military readiness. The truth: Imperial strategists study orcish campaigns obsessively, knowing the orcs don't need to grow stronger. They only need to unite again.]],
        notableLocations = {
            "Seasonal Camps - Temporary settlements along migration routes",
            "Kragmor - Semi-permanent trading hub",
            "The Khan's Road - Ancient route spanning the steppes",
            "Clan Meeting Grounds - Where disputes are settled",
            "Imperial Border Forts - Empire watches nervously from here"
        },
        currentStatus = "Fragmented clans. Dormant superpower. Watched constantly by imperial forces."
    },
    {
        id = "shadowfen",
        name = "The Shadow Fen",
        type = "Contested Swamplands",
        region = "Southwestern Marshes",
        description = [[
A vast swamp where imperial authority weakens. To outsiders, the fen appears as lethal morass of rot, mist, and predators. Few who enter without guidance return. Fewer realize the swamp is inhabited.

The Shadow Fen is magically concealed. A pervasive Veil woven into water and fog redirects perception. Paths loop endlessly, settlements vanish. The fen reveals itself only to those fleeing imperial control.

Founded by refugees after the Last World War, the commune survives through communal labor and infernal pacts. Devils and demons harden the borders in exchange for offerings and access. The Luminary Inquest classifies it as a corrupted exclusion zone and quietly avoids it.]],
        notableLocations = {
            "Murkmire - Largest settlement, neutral trading hub",
            "Drowned Villages - Communities built on artificial islands",
            "Deep Sanctuaries - Hidden mage enclaves and ritual sites",
            "Goblin Warrens - Resistance cells integrated into commune",
            "The Veil's Edge - Where concealment begins"
        },
        currentStatus = "Magically hidden refuge. Protected by infernal pacts. Empire tolerates as containment zone."
    },
    {
        id = "wastes_calidar",
        name = "Wastes of Calidar",
        type = "Devastated Wasteland",
        region = "Southern Glass Desert",
        description = [[
Former elven homeland, destroyed 500 years ago during the Last World War. The Holy Empire used Heaven's Atlas, a weapon of apocalyptic power, to end resistance. Forests vitrified. Rivers boiled away. Stone melted into glass.

Millions of elves died in a single cataclysmic event. Survivors fled north under imperial escort. Return is forbidden. The wastes serve as monument and warning: "This is what happens when power goes unchecked."

Nothing grows here. Strange lights and whispers are reported by travelers. Some say the land remembers what was done to it. Elves remember too. Every lost city's name, every forest, every river. They document everything. History will judge.]],
        notableLocations = {
            "Glass Dunes - Vitrified forests, now crystallized sand",
            "Blackened Ruins - What remains of elven cities",
            "The Silent Rivers - Dry channels where water once flowed",
            "Imperial Warning Posts - Markers declaring region forbidden",
            "Echo Sites - Where magical devastation still resonates"
        },
        currentStatus = "Lifeless. Uninhabitable. Monument to war's horror. Return forbidden by imperial decree."
    },
    {
        id = "gnomish_isles",
        name = "The Gnomish Isles",
        type = "Island Nation",
        region = "Eastern Islands - 280km Across the Shimmering Sea",
        description = [[
An island collective far across the Shimmering Sea, separated from the mainland by nearly 280 kilometers (174 miles) of open ocean. Home to the Gnomish Collective, a rigidly structured industrial society with absolute collective ownership. No private property, no religion, no hierarchy.

The vast ocean distance has protected gnomish independence for 500 years. Naval crossing requires 5-7 days by ship, exposing fleets to storms, sea serpents, and gnomish coastal defenses. No imperial fleet has ever successfully reached gnomish shores.

Production councils of engineers and logisticians govern through efficiency models. Advanced automatons serve as population multipliers. Secret airship fleets enable rapid logistics and defense without mass armies, giving gnomes complete air superiority over any approaching naval force.

Gnomes maintain total isolation to prevent imperial invasion and forced imposition of hierarchy, faith-based law, and private ownership. Secrecy is class defense. Clockwork Harbor serves as the sole controlled port where permitted outsiders may conduct trade under strict gnomish supervision within designated commercial zones. Interior cities such as Mechspire remain absolutely closed to outsiders.]],
        notableLocations = {
            "Mechspire - Industrial city visible on coastline",
            "Clockwork Harbor - Trade port for controlled commerce",
            "Airship Docks - Secret aerial infrastructure",
            "Automaton Foundries - Where population multipliers are built",
            "Production Council Chambers - Centers of collective governance"
        },
        currentStatus = "Independent collectivist state. Technologically advanced. Completely isolated from empire."
    }
}

--==============================================================================
-- PEOPLE
--==============================================================================

Lore.people = {
    {
        id = "emperor",
        name = "The Emperor of the Holy Dominion",
        title = "Divine Mandate of Helios, Supreme Authority",
        affiliation = "The Holy Dominion",
        description = [[
The ruler of the Holy Empire, claiming divine mandate from Helios the Sun God. Identity closely guarded. The Emperor rarely appears in public, governs through edicts and delegated authority.

The Emperor's word is law throughout imperial territory. Commands the Luminary Inquest, authorizes purges, and maintains the magic ban established 500 years ago after Heaven's Atlas destroyed Calidar.

Elven archivists maintain exhaustive records of every imperial decree. Some believe the current Emperor is merely a figurehead for institutional power. Others claim direct divine authority flows through the position. The truth is concealed behind bureaucratic layers.]],
        status = "Ruling through divine mandate and institutional authority",
        traits = {"Authoritative", "Distant", "Absolute", "Mysterious"}
    },
    {
        id = "high_luminary",
        name = "High Luminary Solarius",
        title = "Voice of Helios, Commander of the Inquest",
        affiliation = "Luminary Inquest",
        description = [[
The commanding authority of the Luminary Inquest, answering directly to the Emperor and Helios himself. Solarius oversees all enforcement operations across imperial territory.

Under Solarius's leadership, the Inquest has expanded from hunting vampires and demons to regulating existence itself. Documentation checks, identity verification, and public executions maintain order through visibility and terror.

Some whisper Solarius is a true believer in Helios's divine order. Others suggest pragmatic calculation. Control requires fear, and the Inquest provides it. Most avoid speculation. Speaking against the Inquest tends to result in investigation.]],
        status = "Commanding the Luminary Inquest",
        traits = {"Zealous", "Efficient", "Feared", "Untouchable"}
    },
    {
        id = "elder_archivist",
        name = "Elder Archivist Tavellan",
        title = "Keeper of Records, Last Witness",
        affiliation = "Elven Administration",
        description = [[
An elven archivist over 600 years old. Witnessed Calidar's destruction personally. Now serves as senior bureaucrat managing imperial historical archives.

Tavellan writes everything down. Imperial decrees, census data, legal precedents, and, in sealed sections few know exist, the complete record of Calidar's fall, the names of those who authorized Heaven's Atlas, and documentation of every imperial abuse since.

Appears compliant. Processes requests efficiently. Never speaks of Calidar aloud. But elves know: Tavellan is preparing the historical record for the next empire. When the Dominion falls, the truth will remain. History will judge.]],
        status = "Senior elven archivist documenting everything for posterity",
        traits = {"Ancient", "Meticulous", "Silent", "Patient"}
    },
    {
        id = "council_figure",
        name = "The Veiled Councilor",
        title = "Unknown",
        affiliation = "Shadow Fen Commune",
        description = [[
One of the secret council members governing the Shadow Fen Commune. Identity unknown. Appears through intermediaries, never in person. Decisions communicated through trusted messengers.

Rumored to be an infernal hybrid or possessed refugee. No evidence either way. What is clear: decisions consistently favor preservation of the refuge above individual lives, moral purity, or ideological consistency.

Those who investigate the council's identity too openly tend to disappear from public life within the fen. Residents accept that survival depends on not knowing too much. The council protects the commune. That's sufficient.]],
        status = "Hidden governance of Shadow Fen",
        traits = {"Anonymous", "Pragmatic", "Mysterious", "Ruthless when necessary"}
    },
    {
        id = "khan_memory",
        name = "Khan Urzog the Last",
        title = "The Great Khan (Historical)",
        affiliation = "Orc Clans",
        description = [[
The last leader to unify all orcish clans under a single banner. Led continent-spanning campaigns that reshaped borders and shattered kingdoms. Under his command, the orcs became the most effective military force the world has ever known.

Died 45 years ago. Thousands of orcs (300-500 year lifespan) who personally served under him are still alive, many in their prime warrior years. They remember every route, every law, every command. The empire's nightmare: an entire generation of living veterans who know exactly how unity works.

Imperial strategists study his campaigns obsessively, knowing the truth: the orcs don't need to grow stronger. They only need another leader like him.]],
        status = "Deceased. Remembered. The unity he created waits to be reborn.",
        traits = {"Strategic Genius", "Unifier", "Legendary", "Historical"}
    },
    {
        id = "goblin_cell_leader",
        name = "Skragg Toothmark",
        title = "Cell Leader, The Ember Warren",
        affiliation = "Goblin Resistance",
        description = [[
A goblin of thirty years who carries the full weight of genetic memory, the ancestral flood that activates at birth and again at puberty, filling every goblin with lived experience of every atrocity committed against their people. Skragg did not learn about the massacres. He remembers them. The burning warrens, the imperial soldiers laughing, the children who did not escape. These are not stories to him. They are his memories, inherited through blood and bone, encoded in goblin DNA across generations.

By thirty, Skragg has had both activations and years to process the rage into something useful. He leads a resistance cell of fourteen goblins operating deep in imperial territory, striking supply convoys, sabotaging infrastructure built on goblin graves, and vanishing into tunnel networks the empire does not know exist. He views all non-goblins as occupiers on stolen land. There are no civilians in an occupation. There are only settlers and resistance.

Uncompromising, strategic, and burning with righteous fury that genetic memory makes impossible to extinguish. The empire calls him a terrorist. He calls himself a liberator. "No one is illegal on stolen land."]],
        status = "Active cell leader operating in imperial territory. Wanted by the Luminary Inquest.",
        traits = {"Ruthless", "Remembering", "Uncompromising", "Strategic"}
    },
    {
        id = "gnome_council_member",
        name = "Cogsworth Venn-Haldar",
        title = "Senior Production Councilor, Strategic Resources Division",
        affiliation = "Gnomish Collective",
        description = [[
A gnome of 280 years who has served on the Production Council for over a century, rising through the Strategic Resources Division by demonstrating that every decision can be reduced to mathematics, and that the mathematics of human contact are catastrophic.

Cogsworth has been the primary voice pushing for complete severance of trade relations with the Holy Dominion. His models are precise: imperial instability is accelerating. Religious extremism compounds with military overextension. The Luminary Inquest's expanding purges indicate a regime entering terminal paranoia. Contact with humans risks contaminating gnomish society with hierarchy, superstition, and ownership, the three diseases the Collective was built to cure.

Cold, analytical, and efficient in a way that makes even other gnomes uncomfortable. He does not hate humans. Hatred is inefficient. He simply recognizes them as a dangerously unstable powder keg, and he intends to ensure the Collective is nowhere near the blast radius when the fuse reaches its end. His presentations to the Council include projected timelines for imperial collapse and contingency models for post-imperial continental reorganization.]],
        status = "Active senior councilor. Architect of gnomish isolationist policy revision.",
        traits = {"Calculating", "Isolationist", "Pragmatic", "Visionary"}
    },
    {
        id = "dwarf_guild_elder",
        name = "Grundvik the Seam",
        title = "Guild Elder, Stonecutters' Council of the Deep Holds",
        affiliation = "The Free Holds of Stone",
        description = [[
A dwarf of over four hundred years, stone-born in the early decades of the current age, when the Last World War's ash still settled on mountain peaks. Grundvik emerged from the sacred chambers into a world that had just learned what weapons like Heaven's Atlas could do. He has spent every century since ensuring the holds need nothing from that world.

As elder of the Stonecutters' Guild, Grundvik oversees the architectural integrity of the Free Holds. His hands are calloused beyond sensation, and his knowledge of the mountain's bones is absolute. He embodies dwarven isolationism at its most immovable: surface politics are not dwarven problems, surface wars are not dwarven wars, and surface peoples who come asking for help are customers at best and liabilities at worst. "What is built matters. What is believed does not."

But Grundvik carries a secret that erodes his certainty. In sealed tunnels deep below the lowest active mines, he has heard the Deep Dwarves knocking. He has found artifacts, tools forged from metals that do not exist on the surface, left in passages sealed centuries ago during the Deep Schism. He retrieved them. He hid them. He told no one on the guild council. For a dwarf who believes the collective owns all knowledge, this private concealment is an act of profound personal crisis.]],
        status = "Active guild elder. Pillar of dwarven isolationist governance.",
        traits = {"Ancient", "Immovable", "Skilled", "Secretive"}
    },
    {
        id = "catfolk_matriarch",
        name = "Mirenna Silkfoot",
        title = "Caravan Matriarch, The Silkfoot Family",
        affiliation = "Beast Folk (Cat Folk)",
        description = [[
An elderly cat folk woman of sixty-three years, ancient by cat folk standards, who has traveled every road in the empire and been turned away from half of them. Mirenna leads one of the largest cat folk caravan families, a network of cousins, daughters, sons, and adopted strays spanning dozens of wagons and three generations of road-hardened travelers.

Her reputation as a fortune teller draws crowds at every market square. What the crowds do not understand is that her "fortune telling" is a sophisticated intelligence network disguised as superstition. She reads patterns, not in cards or stars, but in trade shipments, troop rotations, grain prices, and political appointments. When she tells a merchant his fortunes will turn south, she means imperial tax collectors are moving into his district. When she warns a traveler about dark roads ahead, she means Luminary Inquest patrols have been spotted on that route.

She sells information to anyone who can pay, including the Veiled Hand. Warm as hearthfire to her family, sharp as a blade to outsiders. She has survived six decades of imperial suspicion by being too useful to imprison and too mobile to pin down. Her caravan routes are arteries through which intelligence flows between factions who officially have no contact. "The roads belong to travelers, not empires."]],
        status = "Active caravan leader. Intelligence broker operating across imperial territory.",
        traits = {"Perceptive", "Nomadic", "Connected", "Cunning"}
    },
    {
        id = "lizardfolk_observer",
        name = "Sethaxis the Still",
        title = "Senior Observer, Astronomical Observation Sect",
        affiliation = "Lizard Folk Sects",
        description = [[
A lizard folk of over five hundred years who has been stationed in the Shadow Fen for decades, watching the political currents of the surface world with the patience of a species that measures time in centuries. Sethaxis speaks rarely and observes constantly. Those who encounter him in the fen's drowned villages often mistake him for a statue. He can remain motionless for hours, cataloguing every detail with reptilian precision.

His sect has noticed disturbing patterns in celestial movements. Star alignments that held stable for centuries have begun to drift. Anomalies suggest dimensional boundaries are thinning, particularly over the Wastes of Calidar, where Heaven's Atlas tore reality open five hundred years ago. The Void that was locked away is pressing against the wound.

He knows more about the hollow earth than he reveals. His sect maintains charts of underground river routes connecting the Shadow Fen to the Subterranean Seas, the ancestral waters from which all lizard folk originated. He has made the Descent twice and touched the bioluminescent waters below. He documents, he reports to his sect, and he waits. "What is hidden endures. What is revealed can be taken."]],
        status = "Active observer stationed in Shadow Fen. Monitoring celestial anomalies.",
        traits = {"Patient", "Observant", "Ancient", "Cryptic"}
    },
    {
        id = "orc_veteran",
        name = "Barak Ironsaddle",
        title = "Veteran of the Khan's Campaigns, Elder of the Scarred Tusk Clan",
        affiliation = "Orc Clans",
        description = [[
An orc warrior of three hundred and fifty years who personally served under Khan Urzog the Last. Barak rode in the Khan's vanguard for two decades, carried his banner across three campaigns, and was present the day the Great Khan died. He remembers every route, every formation, every command signal. He remembers what unity felt like: the thunder of ten thousand riders moving as one, the sky darkening with banners, the earth shaking beneath coordinated cavalry.

That was forty-five years ago. Barak is still in his prime. He has watched the empire systematically dismantle orc culture since. Imperial agents break up any settlement that grows too large. Gatherings of more than three clans trigger military observation. Communication between separated clans is monitored and suppressed. The empire fears reunification more than any standing army.

Barak burns with controlled fury. He commands enormous respect among scattered orc communities. He knows that any visible attempt to gather warriors would bring immediate imperial reprisal. So he does not gather warriors visibly. Instead, he has spent decades quietly establishing hidden communication networks between separated clans, using trading caravans, seasonal migrations, and trusted riders to carry coded messages. He is the most dangerous person the empire does not know about. The open sky watches. The eternal road remembers.]],
        status = "Active clan elder. Covertly establishing inter-clan communication networks.",
        traits = {"Veteran", "Disciplined", "Furious", "Patient"}
    }
}

--==============================================================================
-- FACTIONS
--==============================================================================

Lore.factions = {
    {
        id = "holy_dominion",
        name = "The Holy Dominion",
        type = "Theocratic Empire",
        leader = "The Emperor (divine mandate of Helios)",
        description = [[
The dominant power of the known world. Rose after the Last World War by deploying Heaven's Atlas to destroy the elven homeland of Calidar. Claims divine mandate from Helios, the Sun God, to regulate magic and maintain order across the known world.

Controls the central continent, integrates elves as bureaucratic caste, and enforces magic ban through the Luminary Inquest. Magic is legal only when state-sanctioned or divinely ordained. Unsanctioned magic is treason punishable by execution and soul destruction. Human supremacist ideology underpins all imperial policy. Other races are tolerated only when useful, controlled when manageable, and destroyed when convenient.

Actively prevents orc reunification by breaking up large settlements, monitoring clan gatherings, and disrupting inter-clan communication. Tolerates independent powers (dwarves, gnomes) when conquest is too costly. Maintains containment zones (Shadow Fen) for malcontents. Points to Wastes of Calidar as justification: "This is what happens when power goes unchecked."]],
        goals = {
            "Maintain control over magic through licensing and enforcement",
            "Prevent reunification of orcish clans: break up settlements, monitor gatherings, suppress communication",
            "Expand imperial territory where resistance is weak",
            "Locate and secure Heaven's Atlas (if it still exists)",
            "Maintain human supremacy over all other races within imperial borders"
        },
        resources = "Standing armies, Luminary Inquest enforcers, Elven bureaucracy, Divine authority, Documentation control, Anti-reunification intelligence apparatus",
        relations = {
            {faction = "Elven Administration", status = "Integrated (necessary partnership, resented by both sides)"},
            {faction = "Dwarven Holds", status = "Neutral trade only (dwarves refuse all political contact)"},
            {faction = "Orc Clans", status = "Active suppression of reunification; settlements broken up, gatherings monitored"},
            {faction = "Gnomish Collective", status = "Limited trade (gnomes actively distancing, reducing contact)"},
            {faction = "Shadow Fen", status = "Containment tolerated"},
            {faction = "Goblin Resistance", status = "Active suppression, classified as vermin"},
            {faction = "Beast Folk", status = "Tolerated as useful labor, distrusted as outsiders"}
        }
    },
    {
        id = "elven_administration",
        name = "The Elven Administration",
        type = "Integrated Bureaucratic Caste",
        leader = "None (integrated into empire)",
        description = [[
Survivors of Calidar's destruction 500 years ago. Integrated into the Holy Empire as junior partners, the bureaucratic backbone handling archives, census, legal systems, trade regulation, and documentation.

Officially compliant. Publicly support imperial policy. Privately, elves remember everything and document imperial abuses in sealed archives. Some quietly aid persecuted mages: "We remember when it was us."

Elves over 500 years old personally witnessed Calidar's fall. They prepare records for the next empire. When the Dominion collapses, elves will still be here, with complete documentation. History will judge. Orcs view elves with disdain, seeing cowards who submitted to the empire that destroyed them rather than fight. Elves view orcs as reckless and undisciplined. The mutual contempt runs deep.]],
        goals = {
            "Survival through compliance and institutional value",
            "Preserve sealed archives containing pre-war knowledge",
            "Document imperial abuses for historical record",
            "Quietly aid persecuted when possible (without discovery)"
        },
        resources = "Institutional knowledge, Long memory (10,000 years), Control of archives, Bureaucratic expertise",
        relations = {
            {faction = "Holy Dominion", status = "Integrated (resented)"},
            {faction = "Shadow Fen", status = "Some Old Ones refused integration and fled there"},
            {faction = "Dwarves", status = "Mutual respect between archivists"},
            {faction = "Beast Folk", status = "More sympathetic than humans to documentation struggles"},
            {faction = "Orc Clans", status = "Mutual disdain; orcs see elves as cowards who submitted"}
        }
    },
    {
        id = "dwarven_holds",
        name = "The Free Holds of Stone",
        type = "Collectivist Labor Federation",
        leader = "Guild Councils (rotating)",
        description = [[
Anarcho-syndicalist dwarven society operating through guild councils, collective ownership, and labor rotation. No kings, no private property, no hierarchy. Strict isolationists who view surface affairs as fundamentally irrelevant to dwarven existence.

Stone-born reproduction (no biological parents) makes family-based power structures biologically impossible. Every dwarf is equally a child of the stone. Labor is the foundation of value: "What is built matters. What is believed does not."

Rejected imperial integration entirely. Mountain holds have never been conquered. Trade with surface through fortified gates but refuse political subordination, and increasingly question whether even trade is worth the entanglement. Deep beneath the holds, sealed passages lead to the Deep Dwarven Realm, a truth guarded with absolute collective silence.]],
        goals = {
            "Maintain collective ownership and guild governance",
            "Preserve strict isolation from surface politics, religion, and conflict",
            "Continue refining systems of production and distribution",
            "Resist imperial attempts to impose hierarchy or extract concessions",
            "Guard the secret of the Deep Dwarves and sealed passages"
        },
        resources = "Impregnable mountain fortresses, Metalworking and stonecraft expertise, Self-sufficient economy, Centuries of institutional memory, Sealed passages to Deep Dwarven Realm",
        relations = {
            {faction = "Holy Dominion", status = "Neutral trade only; refuse all political engagement"},
            {faction = "Gnomes", status = "Kindred collectivists, mutual respect"},
            {faction = "Orcs", status = "Remembered past conflicts, sealed tunnels"},
            {faction = "Shadow Fen", status = "Smuggling trade for tools/metals"},
            {faction = "Goblins", status = "Seal tunnels when goblin activity detected; mutual avoidance"}
        }
    },
    {
        id = "orc_clans",
        name = "The Orc Clans",
        type = "Nomadic Military Confederation (Fragmented)",
        leader = "None (no current Khan)",
        description = [[
Once the most effective military force the world has ever known. Under a Great Khan, unified clans conquered half the world through speed, coordination, and psychological warfare. With 300-500 year lifespans, orcs who served in those campaigns are still alive and in their prime.

That unity ended when Khan Urzog died 45 years ago. The empire actively prevents reunification by breaking up any orc settlement that grows too large, monitoring gatherings of more than three clans, disrupting trade routes, and suppressing inter-clan communication. Imperial agents infiltrate clan structures and assassinate potential unifiers. The entire imperial border policy is built around one fear: the clans must never unite again.

Despite this, the laws still exist. The routes are remembered. The old commands are taught. Veterans who personally rode with the Khan carry living memory of exactly how unity worked. Orcs view their fragmentation as dormancy, not defeat. They hold elves in particular contempt, a people who chose submission over resistance, who serve the empire that would gladly do to the steppes what it did to Calidar.]],
        goals = {
            "Preserve laws, routes, and commands for potential reunification",
            "Maintain clan autonomy and seasonal migration patterns despite imperial interference",
            "Resist imperial expansion into steppe territories",
            "Survive imperial anti-reunification campaigns: settlements broken up, leaders monitored",
            "Establish covert inter-clan communication networks"
        },
        resources = "Sophisticated mobile warfare doctrine, Strict legal code, Nomadic advantage, Historical legacy of unification, Living veterans of the Khan's campaigns (300-500 year lifespans)",
        relations = {
            {faction = "Holy Dominion", status = "Active target of anti-reunification policy; settlements broken up, gatherings monitored"},
            {faction = "Dwarves", status = "Mutual respect for defensive capability"},
            {faction = "Elves", status = "Mutual disdain; orcs view elves as cowards who submitted to their destroyers"},
            {faction = "Shadow Fen", status = "Some clans base there, prefer swamp terrain"},
            {faction = "Goblins", status = "Respect guerrilla effectiveness"}
        }
    },
    {
        id = "gnomish_collective",
        name = "The Gnomish Collective",
        type = "Collectivist Industrial State",
        leader = "Production Councils",
        description = [[
Absolute collective ownership society on isolated eastern islands. No private property, no religion, no hierarchy. Governed by production councils (engineers, logisticians, planners) through efficiency models.

Advanced technology far exceeding other races: automatons as population multipliers, secret airship fleets, precision industry. Maintain total isolation to prevent imperial invasion and forced imposition of hierarchy, faith-based law, and private ownership.

Actively distancing from humans. Production councils have identified the Holy Dominion as a dangerously unstable regime. Religious extremism, military overextension, expanding purges, and human supremacist ideology mark a civilization entering terminal decline. Mathematical models project imperial collapse within generations. The Collective is reducing trade contacts, recalling gnomish observers, and preparing contingency plans for post-imperial reorganization. "Secrecy is not paranoia. It is class defense."]],
        goals = {
            "Maintain collective ownership and production council governance",
            "Preserve secrecy about full technological capabilities",
            "Actively distance from human empire: reduce trade, recall observers, prepare for collapse",
            "Continue development of automation and industrial systems",
            "Prevent imperial invasion and religious domination"
        },
        resources = "Advanced automatons, Secret airship fleets, Precision industry, Self-sufficient collective economy, Ocean isolation, Aerial surveillance capabilities",
        relations = {
            {faction = "Holy Dominion", status = "Actively distancing; reducing trade, view humans as dangerously unstable"},
            {faction = "Dwarves", status = "Kindred collectivists, different methods"},
            {faction = "Orcs", status = "Classify as high-mobility destabilizing force"},
            {faction = "Shadow Fen", status = "Observe with academic interest, avoid contact"}
        }
    },
    {
        id = "shadowfen_commune",
        name = "The Shadow Fen Commune",
        type = "Magically Concealed Refuge",
        leader = "Secret Council (membership unknown)",
        description = [[
Hidden commune in southwestern swamplands, founded by refugees fleeing imperial control after the Last World War. Protected by pervasive magical Veil that redirects perception and infernal pacts with devils and demons.

To outsiders, the fen appears impassable. To those fleeing persecution, paths open and guides appear. Communal labor born from scarcity. Identities burned upon entry. Past lives don't matter. Only present contribution.

The empire tolerates Shadow Fen as containment zone. Absorbs malcontents who might otherwise rebel in cities. Luminary Inquest classifies as corrupted exclusion zone and avoids it. Some patrols never returned.]],
        goals = {
            "Maintain magical concealment and infernal protection",
            "Preserve refuge for those fleeing imperial persecution",
            "Sustain communal distribution of food, shelter, and resources",
            "Avoid expansion that would trigger imperial response"
        },
        resources = "The Veil (magical concealment), Infernal pacts (devils/demons), Hidden sanctuary, Veiled Hand protection, Communal infrastructure",
        relations = {
            {faction = "Holy Dominion", status = "Tolerated as containment"},
            {faction = "Elves", status = "Many Old Ones refused integration, fled here"},
            {faction = "Goblins", status = "Cells operate from fen, intelligence sharing"},
            {faction = "Veiled Hand", status = "Houses assassin organization, mutual protection"},
            {faction = "Lizard Folk", status = "Significant lizard folk presence; observers and sect members stationed here"}
        }
    },
    {
        id = "goblin_resistance",
        name = "The Goblin Resistance",
        type = "Anti-Imperial Insurgency Network",
        leader = "None (cell-based structure)",
        description = [[
FIERCELY ANTI-EMPIRE. Driven from ancestral lands during imperial invasion and genocide. Scattered cells (5-20 goblins each) conducting armed anti-imperial resistance. No central command. Each cell is autonomous, ideologically committed, and self-sufficient.

Goblins possess the MindWeb, a genetic memory system encoded in their DNA. It activates three times: at birth (core ancestral memories flood the newborn), at puberty (the full weight of goblin history hits), and at death (the dying goblin's life is condensed and broadcast to every living goblin). Every death strengthens the collective. Every goblin killed by the empire becomes evidence transmitted to all survivors. They view all other races with disgust: occupiers, collaborators, or bystanders who built their civilizations on goblin graves.

"The empire is illegitimate. The occupation ends when we say it ends." Empire calls it "pest control." Reality: it's an unwinnable war. Every warren cleared spawns two more. Every cell destroyed is replaced within months. The resistance is self-sustaining and multi-generational. The empire cannot win. It can only bleed.]],
        goals = {
            "LIBERATE ancestral lands from imperial occupation",
            "Make imperial occupation so costly and bloody that the empire withdraws or collapses",
            "Strike imperial patrols, infrastructure, and officials",
            "Eliminate imperial collaborators as traitors to their species",
            "Preserve genetic memory and ancestral knowledge of stolen homelands",
            "Refuse to recognize imperial law, courts, or borders on stolen land"
        },
        resources = "Tunnel networks, Cell-based resilience, Genetic memory (ancestral DNA trait), Asymmetric warfare expertise, Shadow Fen safe havens",
        relations = {
            {faction = "Holy Dominion", status = "Classified as vermin, active suppression"},
            {faction = "Shadow Fen", status = "Integrated cells, mutual intelligence"},
            {faction = "Orcs", status = "Mutual respect for guerrilla effectiveness"},
            {faction = "Dwarves", status = "Dwarves seal tunnels when goblin activity suspected"}
        }
    },
    {
        id = "lizard_folk_sects",
        name = "The Lizard Folk Sects",
        type = "Secretive Knowledge Confederation",
        leader = "Sect Councils (multiple, no single authority)",
        description = [[
Heirs to ancient hidden river civilization beneath the northern deserts. Society divided into sects controlling specific knowledge: river engineering, burial rites, trade routes, astronomy, martial discipline. Lizard folk live in many places across the known world, with significant presence in Shadow Fen and scattered observation posts throughout imperial territory.

With 600-800 year lifespans, individual lizard folk personally remember events from before the Last World War. They play games measured in centuries. Witnessed Heaven's Atlas destroy Calidar from afar. They measured it, documented it, concluded action was required.

Founded the Veiled Hand assassin organization 500 years ago to prevent escalation to mass atrocity through precision removal of key individuals. "Knowledge over territory. What is hidden endures. What is revealed can be taken."]],
        goals = {
            "Preserve hidden river empire beneath desert sands",
            "Maintain compartmentalized sect structure for security",
            "Continue long-term observation of surface empires from stations across the world",
            "Support Veiled Hand mission to prevent another Calidar",
            "Monitor dimensional stability; celestial anomalies suggest weakening seals"
        },
        resources = "Hidden empire infrastructure, 600-800 year lifespans, Compartmentalized knowledge, Desert navigation expertise, Veiled Hand (founded and led by sects), Observation posts in Shadow Fen and beyond",
        relations = {
            {faction = "Shadow Fen", status = "Significant presence; Veiled Hand operates from fen, observers stationed throughout"},
            {faction = "Holy Dominion", status = "Minimal contact, selective presence"},
            {faction = "Elves", status = "Recognize kindred archivists"},
            {faction = "Dwarves", status = "Mutual respect between keepers of hidden places"}
        }
    },
    {
        id = "veiled_hand",
        name = "The Veiled Hand",
        type = "Secretive Assassination Network",
        leader = "Unknown (highest initiates are lizard folk)",
        description = [[
Founded 500 years ago by lizard folk sect that witnessed Calidar's destruction from afar. Exists to prevent escalation to mass atrocity through precision removal of key individuals before they can authorize catastrophic decisions.

"Preventing a single decision can save countless lives." Targets imperial officials authorizing mass purges, developing weapons of mass destruction, or planning invasions. Methods: staged accidents, poison, natural-appearing deaths.

Operates from Shadow Fen. Compartmentalized cells. No member knows the full scope. Empire suspects coordinated assassinations but cannot prove it. Public acknowledgment would imply vulnerability. Unacceptable.]],
        goals = {
            "Prevent another use of weapons like Heaven's Atlas",
            "Remove officials who authorize escalating atrocities before they act",
            "Protect Shadow Fen Commune from existential threats",
            "Operate through deterrence; many observed targets are never struck"
        },
        resources = "Compartmentalized cells, Shadow Fen sanctuary, Lizard folk long-term patience, Intelligence networks, Untraceable methods",
        relations = {
            {faction = "Shadow Fen", status = "Operates from fen, mutual protection"},
            {faction = "Lizard Folk Sects", status = "Founded by and led by sects"},
            {faction = "Holy Dominion", status = "Denied existence, covert operations against"},
            {faction = "Elves", status = "Some Old Ones provide intelligence"}
        }
    }
}

--==============================================================================
-- HISTORY
--==============================================================================

Lore.history = {
    {
        year = "500 Years Ago",
        era = "The Last World War",
        title = "The War That Nearly Ended Everything",
        description = [[
The apocalyptic conflict that reshaped the world. Multiple factions wielded magic as a weapon of mass destruction. Borders were redrawn through annihilation. Populations were erased. Reality itself bent under competing spells.

Cities burned. Armies vanished. The war did not end through victory. It collapsed under exhaustion, famine, plague, and fear. But not before proving that unrestrained magic could erase civilization itself.

The forces that would become the Holy Dominion prepared their final weapon: Heaven's Atlas.]]
    },
    {
        year = "500 Years Ago",
        era = "The Last World War",
        title = "The Destruction of Calidar",
        description = [[
The Holy Empire deployed Heaven's Atlas, a magical artifact of apocalyptic power, against the elven homeland of Calidar in the southern forests.

In a single cataclysmic event: Forests vitrified into glass. Rivers boiled away to vapor. Stone melted into crystallized sand. Elven cities were vaporized. Millions died instantly.

Surviving elves fled north under imperial escort. Calidar became the Wastes, an endless glass desert. Elven sovereignty ended in a single generation. Heaven's Atlas proved magic could destroy anything. The war ended shortly after. No faction wanted to be next.]]
    },
    {
        year = "Year 1",
        era = "The Age After War Begins",
        title = "The Magic Ban and Integration",
        description = [[
The victorious Holy Empire declared total arcane regulation: "Magic is not a right. It is a weapon." Mages, wizards, and warlocks became illegal unless state-sanctioned or divinely ordained.

Unsanctioned magic was classified as treason, punishable by execution and ritual soul destruction. This applied universally, including to elves whose culture had revolved around magical scholarship.

Elves integrated into imperial structure (survival, not choice). Refugees founded Shadow Fen in southwestern swamps. Lizard folk sect created the Veiled Hand after witnessing Calidar's destruction from afar.]]
    },
    {
        year = "Years 1-100",
        era = "Reconstruction",
        title = "Order Through Control",
        description = [[
The Holy Empire expanded across the central continent. Elves became bureaucratic caste managing imperial administration. The Luminary Inquest was established to enforce magic regulation and hunt forbidden beings.

Independent powers maintained fragile autonomy: Dwarven holds closed borders. Orcish clans remained on steppes. Gnomish collective isolated on islands. Goblin resistance cells formed in margins.

Shadow Fen grew from refugee camps into hidden commune protected by magical concealment and infernal pacts. The world stabilized around new order: control, documentation, and fear.]]
    },
    {
        year = "Years 100-500",
        era = "The Age After War",
        title = "Five Centuries of Imperial Order",
        description = [[
For 500 years, the Holy Dominion has maintained control through the Luminary Inquest, elven bureaucracy, and divine authority from Helios.

Magic remains strictly regulated. The Wastes of Calidar serve as permanent monument and warning. Independent powers endure through isolation. Resistance persists in shadows.

Elves over 500 years old still remember Calidar personally. They document everything. Goblins remember lost homelands and teach resistance. Lizard folk observe patterns across centuries. The empire forgets quickly and repeats mistakes.]]
    },
    {
        year = "Year 500",
        era = "Current Day",
        title = "The Age Continues",
        description = [[
Present day. The Holy Dominion controls most territory and population. The Luminary Inquest expands enforcement of documentation requirements. Elves comply outwardly while preparing for imperial fall.

The Shadow Fen thrives behind concealment. The Veiled Hand eliminates officials who authorize escalating atrocities. Goblins wage multi-generational resistance. Orcs remain fragmented, but the laws, routes, and commands are still taught.

Memory endures. Resistance persists. The glass desert reminds everyone what uncontrolled power can do, or what it can be used to justify. The Age After War continues.]]
    }
}

--==============================================================================
-- MAGIC SYSTEM
--==============================================================================

Lore.magic = {
    overview = {
        title = "Magic and The Law",
        description = [[
500 years ago, the Last World War proved that unrestrained magic could erase civilization. After witnessing Heaven's Atlas destroy Calidar in a single cataclysmic event, the victorious powers declared magic too dangerous for unrestricted use.

THE LAW: "Magic is not a right. It is a weapon. Unsanctioned magic is treason, punishable by death and ritual soul destruction."

Legal magic users: State-sanctioned mages (licensed, monitored, controlled) and divinely ordained practitioners (priests blessed by Helios).

Illegal magic users: Unsanctioned wizards, warlocks, hedge mages, anyone practicing without license or divine blessing.

The empire justifies this by pointing to the Wastes of Calidar: "This is what happens when power goes unchecked. Would you risk this again?"]]
    },
    categories = {
        {
            name = "State-Sanctioned Magic",
            description = "Licensed by imperial authority. Practitioners monitored constantly through documentation, regular inspections, and magical tracking. Used for imperial military, infrastructure projects, and approved commercial applications. Licenses can be revoked instantly. Unsanctioned use after revocation is execution.",
            status = "Legal - but heavily controlled and surveilled"
        },
        {
            name = "Divinely Ordained Magic",
            description = "Granted by Helios through his priests and clerics. Healing, blessing, purification, and holy combat. Considered pure because it flows from divine source rather than mortal will. Not subject to same restrictions as arcane practice.",
            status = "Legal - blessed by Helios, above regulation"
        },
        {
            name = "Unsanctioned Magic",
            description = "Any magical practice without state license or divine blessing. This includes: hedge witches, traditional folk magic, elven pre-war techniques, self-taught practitioners, and inherited abilities never registered. Discovery results in Luminary Inquest intervention.",
            status = "Illegal - execution and soul destruction"
        },
        {
            name = "Forbidden Magic (Automatic Death)",
            description = "Necromancy, demon summoning, blood magic, and reality manipulation. No exceptions. No trials. Practitioners executed immediately upon discovery. Souls ritually destroyed to prevent resurrection or afterlife.",
            status = "Ultimate sin - complete erasure from existence"
        }
    },
    artifacts = {
        {
            name = "Heaven's Atlas",
            description = "The weapon that ended the Last World War. Apocalyptic magical artifact used by the Holy Empire to destroy Calidar. Turned forests to glass, rivers to vapor, stone to sand. Killed millions in a single use. Current location unknown. The empire claims it was destroyed, but some believe it's hidden in the Grand Cathedral's deepest vaults or shattered into pieces.",
            location = "Unknown - possibly destroyed, possibly hidden, possibly scattered",
            significance = "Justification for eternal magic ban. Proof that magic can erase civilization."
        },
        {
            name = "Sealed Elven Archives",
            description = "Pre-war magical knowledge hidden by elves in restricted archive sections. Contains techniques, rituals, and scholarship from before Calidar's fall. Access limited to senior elven archivists. Empire aware these exist but cannot access without elven cooperation. Elves did not destroy magic. They hid it.",
            location = "Scattered across imperial archive vaults, concealed within general records",
            significance = "Preservation of pre-ban magical knowledge. Insurance against total loss."
        },
        {
            name = "The Veil (Shadow Fen)",
            description = "Pervasive magical field woven into water, fog, and root throughout Shadow Fen swamplands. Redirects perception of hostile intruders. Sustained by resident mages and infernal reinforcement. Not a single spell but environmental magic accumulated over 500 years.",
            location = "Covers entire Shadow Fen region",
            significance = "Protects commune from imperial discovery. Proof that collective magic can achieve what individuals cannot."
        }
    }
}

--==============================================================================
-- UI FUNCTIONS
--==============================================================================

function Lore.init()
    currentTab = "overview"
    scrollOffset = 0
    selectedEntry = nil
    searchText = ""
end

function Lore.update(dt)
    -- Smooth scrolling could be added here
end

function Lore.draw()
    local screenW, screenH = love.graphics.getDimensions()

    -- Background
    love.graphics.setColor(colors.bg)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Main panel
    local panelX, panelY = 40, 40
    local panelW, panelH = screenW - 80, screenH - 80

    love.graphics.setColor(colors.panel)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 12, 12)
    love.graphics.setColor(colors.panelBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 12, 12)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(colors.textGold)
    love.graphics.setFont(getFont(32))
    love.graphics.printf("THE WORLD LORE", panelX, panelY + 15, panelW, "center")

    love.graphics.setColor(colors.textDim)
    love.graphics.setFont(getFont(14))
    love.graphics.printf('"' .. Lore.motto .. '"', panelX, panelY + 52, panelW, "center")

    -- Draw tabs
    local tabY = panelY + 80
    local tabW = (panelW - 40) / #tabs
    local mx, my = love.mouse.getPosition()

    for i, tab in ipairs(tabs) do
        local tabX = panelX + 20 + (i-1) * tabW
        local hover = mx >= tabX and mx <= tabX + tabW - 5 and my >= tabY and my <= tabY + 35

        if currentTab == tab.id then
            love.graphics.setColor(colors.tabActive)
        elseif hover then
            love.graphics.setColor(0.5, 0.4, 0.3)
        else
            love.graphics.setColor(colors.tabInactive)
        end

        love.graphics.rectangle("fill", tabX, tabY, tabW - 5, 35, 6, 6)

        love.graphics.setColor(currentTab == tab.id and {0.1, 0.1, 0.1} or colors.text)
        love.graphics.setFont(getFont(14))
        love.graphics.printf(tab.name, tabX, tabY + 10, tabW - 5, "center")
    end

    -- Content area
    local contentX = panelX + 20
    local contentY = tabY + 50
    local contentW = panelW - 40
    local contentH = panelH - 160

    -- Draw content based on current tab
    love.graphics.setScissor(contentX, contentY, contentW, contentH)

    if currentTab == "overview" then
        drawOverview(contentX, contentY - scrollOffset, contentW, contentH)
    elseif currentTab == "places" then
        drawPlaces(contentX, contentY - scrollOffset, contentW, contentH)
    elseif currentTab == "people" then
        drawPeople(contentX, contentY - scrollOffset, contentW, contentH)
    elseif currentTab == "factions" then
        drawFactions(contentX, contentY - scrollOffset, contentW, contentH)
    elseif currentTab == "history" then
        drawHistory(contentX, contentY - scrollOffset, contentW, contentH)
    elseif currentTab == "magic" then
        drawMagic(contentX, contentY - scrollOffset, contentW, contentH)
    end

    love.graphics.setScissor()

    -- Scrollbar
    local totalHeight = getContentHeight()
    if totalHeight > contentH then
        local scrollbarH = math.max(30, (contentH / totalHeight) * contentH)
        local maxScroll = totalHeight - contentH
        local scrollbarY = contentY + (scrollOffset / maxScroll) * (contentH - scrollbarH)

        love.graphics.setColor(colors.scrollbar)
        love.graphics.rectangle("fill", contentX + contentW - 10, contentY, 8, contentH, 4, 4)
        love.graphics.setColor(colors.scrollbarThumb)
        love.graphics.rectangle("fill", contentX + contentW - 10, scrollbarY, 8, scrollbarH, 4, 4)
    end

    -- Back button
    local backW, backH = 120, 40
    local backX = panelX + panelW/2 - backW/2
    local backY = panelY + panelH - 50
    local backHover = mx >= backX and mx <= backX + backW and my >= backY and my <= backY + backH

    love.graphics.setColor(backHover and {0.4, 0.3, 0.2} or {0.3, 0.25, 0.2})
    love.graphics.rectangle("fill", backX, backY, backW, backH, 8, 8)
    love.graphics.setColor(colors.panelBorder)
    love.graphics.rectangle("line", backX, backY, backW, backH, 8, 8)
    love.graphics.setColor(colors.text)
    love.graphics.setFont(getFont(16))
    love.graphics.printf("Back", backX, backY + 11, backW, "center")
end

local function drawOverview(x, y, w, h)
    local lineY = y

    -- Title
    love.graphics.setColor(colors.textGold)
    love.graphics.setFont(getFont(24))
    love.graphics.print(Lore.overview.title, x, lineY)
    lineY = lineY + 35

    -- Subtitle
    love.graphics.setColor(colors.textDim)
    love.graphics.setFont(getFont(16))
    love.graphics.print(Lore.overview.subtitle, x, lineY)
    lineY = lineY + 40

    -- Description
    love.graphics.setColor(colors.text)
    love.graphics.setFont(getFont(14))
    local _, wrapped = love.graphics.getFont():getWrap(Lore.overview.description, w - 20)
    for _, line in ipairs(wrapped) do
        love.graphics.print(line, x, lineY)
        lineY = lineY + 20
    end

    lineY = lineY + 30

    -- Current Events
    love.graphics.setColor(colors.textRed)
    love.graphics.setFont(getFont(18))
    love.graphics.print("Current Events", x, lineY)
    lineY = lineY + 30

    love.graphics.setColor(colors.text)
    love.graphics.setFont(getFont(14))
    for _, event in ipairs(Lore.overview.currentEvents) do
        love.graphics.print("- " .. event, x + 10, lineY)
        lineY = lineY + 25
    end
end

local function drawPlaces(x, y, w, h)
    local lineY = y

    for _, place in ipairs(Lore.places) do
        -- Place name
        love.graphics.setColor(colors.textGold)
        love.graphics.setFont(getFont(20))
        love.graphics.print(place.name, x, lineY)
        lineY = lineY + 25

        -- Type and region
        love.graphics.setColor(colors.textBlue)
        love.graphics.setFont(getFont(12))
        love.graphics.print(place.type .. " - " .. place.region, x, lineY)
        lineY = lineY + 20

        -- Status
        love.graphics.setColor(colors.textRed)
        love.graphics.print("Status: " .. place.currentStatus, x, lineY)
        lineY = lineY + 25

        -- Description
        love.graphics.setColor(colors.text)
        love.graphics.setFont(getFont(13))
        local _, wrapped = love.graphics.getFont():getWrap(place.description, w - 20)
        for _, line in ipairs(wrapped) do
            love.graphics.print(line, x, lineY)
            lineY = lineY + 18
        end
        lineY = lineY + 10

        -- Notable locations
        love.graphics.setColor(colors.textGreen)
        love.graphics.setFont(getFont(12))
        love.graphics.print("Notable Locations:", x, lineY)
        lineY = lineY + 18

        love.graphics.setColor(colors.textDim)
        for _, loc in ipairs(place.notableLocations) do
            love.graphics.print("  - " .. loc, x, lineY)
            lineY = lineY + 16
        end

        lineY = lineY + 30

        -- Separator
        love.graphics.setColor(0.3, 0.3, 0.35)
        love.graphics.rectangle("fill", x, lineY, w - 20, 1)
        lineY = lineY + 20
    end
end

local function drawPeople(x, y, w, h)
    local lineY = y

    for _, person in ipairs(Lore.people) do
        -- Name
        love.graphics.setColor(colors.textGold)
        love.graphics.setFont(getFont(20))
        love.graphics.print(person.name, x, lineY)
        lineY = lineY + 25

        -- Title
        love.graphics.setColor(colors.textPurple)
        love.graphics.setFont(getFont(12))
        love.graphics.print(person.title, x, lineY)
        lineY = lineY + 18

        -- Affiliation
        love.graphics.setColor(colors.textBlue)
        love.graphics.print("Affiliation: " .. person.affiliation, x, lineY)
        lineY = lineY + 18

        -- Status
        love.graphics.setColor(colors.textRed)
        love.graphics.print("Status: " .. person.status, x, lineY)
        lineY = lineY + 25

        -- Description
        love.graphics.setColor(colors.text)
        love.graphics.setFont(getFont(13))
        local _, wrapped = love.graphics.getFont():getWrap(person.description, w - 20)
        for _, line in ipairs(wrapped) do
            love.graphics.print(line, x, lineY)
            lineY = lineY + 18
        end
        lineY = lineY + 10

        -- Traits
        love.graphics.setColor(colors.textGreen)
        love.graphics.setFont(getFont(12))
        love.graphics.print("Traits: " .. table.concat(person.traits, ", "), x, lineY)

        lineY = lineY + 30

        -- Separator
        love.graphics.setColor(0.3, 0.3, 0.35)
        love.graphics.rectangle("fill", x, lineY, w - 20, 1)
        lineY = lineY + 20
    end
end

local function drawFactions(x, y, w, h)
    local lineY = y

    for _, faction in ipairs(Lore.factions) do
        -- Name
        love.graphics.setColor(colors.textGold)
        love.graphics.setFont(getFont(20))
        love.graphics.print(faction.name, x, lineY)
        lineY = lineY + 25

        -- Type and leader
        love.graphics.setColor(colors.textPurple)
        love.graphics.setFont(getFont(12))
        love.graphics.print(faction.type .. " | Leader: " .. faction.leader, x, lineY)
        lineY = lineY + 25

        -- Description
        love.graphics.setColor(colors.text)
        love.graphics.setFont(getFont(13))
        local _, wrapped = love.graphics.getFont():getWrap(faction.description, w - 20)
        for _, line in ipairs(wrapped) do
            love.graphics.print(line, x, lineY)
            lineY = lineY + 18
        end
        lineY = lineY + 15

        -- Goals
        love.graphics.setColor(colors.textGreen)
        love.graphics.setFont(getFont(12))
        love.graphics.print("Goals:", x, lineY)
        lineY = lineY + 18

        love.graphics.setColor(colors.textDim)
        for _, goal in ipairs(faction.goals) do
            love.graphics.print("  - " .. goal, x, lineY)
            lineY = lineY + 16
        end
        lineY = lineY + 10

        -- Resources
        love.graphics.setColor(colors.textBlue)
        love.graphics.print("Resources: " .. faction.resources, x, lineY)
        lineY = lineY + 20

        -- Relations
        if faction.relations then
            love.graphics.setColor(colors.textRed)
            love.graphics.print("Relations:", x, lineY)
            lineY = lineY + 16

            love.graphics.setColor(colors.textDim)
            for _, rel in ipairs(faction.relations) do
                love.graphics.print("  " .. rel.faction .. ": " .. rel.status, x, lineY)
                lineY = lineY + 16
            end
        end

        lineY = lineY + 20

        -- Separator
        love.graphics.setColor(0.3, 0.3, 0.35)
        love.graphics.rectangle("fill", x, lineY, w - 20, 1)
        lineY = lineY + 20
    end
end

local function drawHistory(x, y, w, h)
    local lineY = y

    -- Timeline header
    love.graphics.setColor(colors.textGold)
    love.graphics.setFont(getFont(20))
    love.graphics.print("The History of the Known World", x, lineY)
    lineY = lineY + 40

    for _, event in ipairs(Lore.history) do
        -- Year and era
        love.graphics.setColor(colors.textBlue)
        love.graphics.setFont(getFont(14))
        love.graphics.print(event.year .. " - " .. event.era, x, lineY)
        lineY = lineY + 20

        -- Title
        love.graphics.setColor(colors.textGold)
        love.graphics.setFont(getFont(18))
        love.graphics.print(event.title, x, lineY)
        lineY = lineY + 25

        -- Description
        love.graphics.setColor(colors.text)
        love.graphics.setFont(getFont(13))
        local _, wrapped = love.graphics.getFont():getWrap(event.description, w - 20)
        for _, line in ipairs(wrapped) do
            love.graphics.print(line, x, lineY)
            lineY = lineY + 18
        end

        lineY = lineY + 25

        -- Timeline connector
        love.graphics.setColor(colors.panelBorder)
        love.graphics.circle("fill", x + 5, lineY - 10, 4)
        love.graphics.rectangle("fill", x + 4, lineY - 30, 2, 25)

        lineY = lineY + 10
    end
end

local function drawMagic(x, y, w, h)
    local lineY = y

    -- Overview
    love.graphics.setColor(colors.textGold)
    love.graphics.setFont(getFont(20))
    love.graphics.print(Lore.magic.overview.title, x, lineY)
    lineY = lineY + 30

    love.graphics.setColor(colors.text)
    love.graphics.setFont(getFont(13))
    local _, wrapped = love.graphics.getFont():getWrap(Lore.magic.overview.description, w - 20)
    for _, line in ipairs(wrapped) do
        love.graphics.print(line, x, lineY)
        lineY = lineY + 18
    end
    lineY = lineY + 30

    -- Schools of Magic
    love.graphics.setColor(colors.textPurple)
    love.graphics.setFont(getFont(18))
    love.graphics.print("Schools of Magic", x, lineY)
    lineY = lineY + 30

    for _, school in ipairs(Lore.magic.categories) do
        love.graphics.setColor(colors.textGold)
        love.graphics.setFont(getFont(16))
        love.graphics.print(school.name, x, lineY)
        lineY = lineY + 22

        love.graphics.setColor(colors.text)
        love.graphics.setFont(getFont(12))
        local _, schoolWrapped = love.graphics.getFont():getWrap(school.description, w - 30)
        for _, line in ipairs(schoolWrapped) do
            love.graphics.print(line, x + 10, lineY)
            lineY = lineY + 16
        end

        love.graphics.setColor(colors.textRed)
        love.graphics.print("Status: " .. school.status, x + 10, lineY)
        lineY = lineY + 25
    end

    lineY = lineY + 20

    -- Magical Artifacts
    love.graphics.setColor(colors.textBlue)
    love.graphics.setFont(getFont(18))
    love.graphics.print("Legendary Artifacts", x, lineY)
    lineY = lineY + 30

    for _, artifact in ipairs(Lore.magic.artifacts) do
        love.graphics.setColor(colors.textGold)
        love.graphics.setFont(getFont(16))
        love.graphics.print(artifact.name, x, lineY)
        lineY = lineY + 22

        love.graphics.setColor(colors.text)
        love.graphics.setFont(getFont(12))
        local _, artifactWrapped = love.graphics.getFont():getWrap(artifact.description, w - 30)
        for _, line in ipairs(artifactWrapped) do
            love.graphics.print(line, x + 10, lineY)
            lineY = lineY + 16
        end

        love.graphics.setColor(colors.textGreen)
        love.graphics.print("Location: " .. artifact.location, x + 10, lineY)
        lineY = lineY + 25
    end
end

local function getContentHeight()
    -- Estimate content height based on current tab
    if currentTab == "overview" then
        return 600
    elseif currentTab == "places" then
        return #Lore.places * 450
    elseif currentTab == "people" then
        return #Lore.people * 400
    elseif currentTab == "factions" then
        return #Lore.factions * 500
    elseif currentTab == "history" then
        return #Lore.history * 250
    elseif currentTab == "magic" then
        return 1200
    end
    return 800
end

function Lore.mousepressed(x, y, button)
    if button ~= 1 then return end

    local screenW, screenH = love.graphics.getDimensions()
    local panelX, panelY = 40, 40
    local panelW, panelH = screenW - 80, screenH - 80

    -- Check tab clicks
    local tabY = panelY + 80
    local tabW = (panelW - 40) / #tabs

    for i, tab in ipairs(tabs) do
        local tabX = panelX + 20 + (i-1) * tabW
        if x >= tabX and x <= tabX + tabW - 5 and y >= tabY and y <= tabY + 35 then
            currentTab = tab.id
            scrollOffset = 0
            return
        end
    end

    -- Check back button
    local backW, backH = 120, 40
    local backX = panelX + panelW/2 - backW/2
    local backY = panelY + panelH - 50

    if x >= backX and x <= backX + backW and y >= backY and y <= backY + backH then
        local TextRPG = require("textrpg"); TextRPG.init()
        if GameState then GameState.current = "textrpg" end
        return
    end
end

function Lore.wheelmoved(wx, wy)
    local screenH = love.graphics.getHeight()
    local contentH = screenH - 80 - 160
    local totalHeight = getContentHeight()
    local maxScroll = math.max(0, totalHeight - contentH)

    scrollOffset = scrollOffset - wy * 40
    scrollOffset = math.max(0, math.min(scrollOffset, maxScroll))
end

function Lore.keypressed(key)
    if key == "escape" then
        local TextRPG = require("textrpg"); TextRPG.init()
        if GameState then GameState.current = "textrpg" end
        return true
    end
    return false
end

return Lore
