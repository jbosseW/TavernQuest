-- Lore Manager - World of Tavern Times
-- Contains all world lore, history, races, factions, and cultural data

local LoreManager = {}

-- ============================================================================
--                         WORLD HISTORY
-- ============================================================================

LoreManager.HISTORY = {
    currentAge = "The Age After War",
    yearsSinceWar = 500,
    currentYear = 500,  -- Imperial Calendar: Year 1 = End of Last World War

    ages = {
        {
            id = "last_world_war",
            name = "The Last World War",
            yearsAgo = 500,
            description = "The conflict that reshaped borders, annihilated populations, and proved that unrestrained power, especially magic, could erase civilization itself.",
            outcome = "The war did not end cleanly. It collapsed under exhaustion, famine, plague, and fear.",
            keyEvent = {
                name = "The Destruction of Calidar",
                artifact = "Heaven's Atlas",
                description = "The Holy Empire deployed Heaven's Atlas, a magical artifact of apocalyptic power. In a single cataclysmic event, the elven homeland of Calidar was destroyed. Forests vitrified. Rivers boiled. Stone melted to glass. Millions died. Elven sovereignty ended.",
                consequences = {
                    "Elven integration into Holy Empire (survival, not choice)",
                    "Magic ban declared (state-sanctioned or divinely ordained only)",
                    "Unsanctioned magic became capital crime (execution + soul destruction)",
                    "Wastes of Calidar serve as permanent warning against uncontrolled power",
                },
            },
            artifact = {
                name = "Heaven's Atlas",
                description = "Forbidden magical artifact of apocalyptic power. Destroyed Calidar in a single use.",
                currentLocation = "Unknown. Empire claims it was destroyed after the war. Some believe it's hidden in the Grand Cathedral's deepest vaults. Others think it was shattered, pieces scattered.",
                legacy = "Justification for magic ban. Proof that magic can erase civilization. Monument to why control is necessary.",
            },
        },
        {
            id = "age_after_war",
            name = "The Age After War",
            duration = "500 years to present",
            description = "What followed was not peace, but order. The surviving powers rebuilt society around control, regulation, and survival.",
            characteristics = {
                "Faith hardened into law",
                "Law hardened into doctrine",
                "Doctrine hardened into violence when necessary",
                "The world did not become quieter; it became more careful",
            },
            keyFeatures = {
                "Holy Empire rose as dominant power",
                "Elves integrated as bureaucratic caste",
                "Magic strictly regulated through Luminary Inquest",
                "Independent powers maintain fragile autonomy (dwarves, gnomes, orcs)",
                "Resistance persists in margins (goblins, shadowfen)",
            },
        },
    },

    timeline = {
        year_negative_500 = "Last World War rages. Multiple factions wield magic as weapon of mass destruction.",
        year_500BA = "Heaven's Atlas activated. Calidar destroyed. Elven sovereignty ends.",
        year_1 = "War ends. Holy Empire declares magic ban. Imperial calendar begins. Elves integrate.",
        year_500 = "Present day. Age After War continues. Memory endures. Resistance persists.",
    },
}

-- ============================================================================
--                         GEOGRAPHY
-- ============================================================================

LoreManager.GEOGRAPHY = {
    mainContinent = {
        name = "The Main Continent",
        areaSqMiles = 38690,
        areaSqKm = 100000,
        description = "Home to humans, elves, orcs, dwarves, and the scattered beast folk diaspora. Nearly all recorded history, war, trade, and faith occur here.",
        inhabitants = {"human", "elf", "orc", "dwarf", "beast_folk"},
    },

    easternIsland = {
        name = "The Eastern Island Continent",
        alternateName = "Gnomish Isles",
        areaSqMiles = 8470,
        areaSqKm = 22000,
        oceanDistance = "280 kilometers from mainland across the Silver Seas (Shimmering Sea)",
        description = "Lies far across the Silver Seas, separated from the main continent by nearly 280 kilometers of open ocean. The sole homeland of the gnomes, geographically isolated from the rest of the world. This vast ocean barrier has protected gnomish independence for 500 years. No imperial fleet has ever successfully crossed to invade. The journey takes 5-7 days by ship, exposing vessels to storms, sea serpents, and gnomish defenses.",
        inhabitants = {"gnome"},
        secrets = {"airship_technology", "aerial_infrastructure", "advanced_automatons"},
        defensiveAdvantages = "Ocean crossing difficulty, gnomish airship superiority, coastal defenses, storm-prone waters, extended naval exposure",
    },

    -- Key Regions on Main Continent
    wastesOfCalidar = {
        name = "Wastes of Calidar",
        alternateName = "The Glass Desert",
        type = "devastated_region",
        location = "Southern continent",
        description = "Former elven homeland destroyed 500 years ago during the Last World War. The Holy Empire used Heaven's Atlas to vitrify the forests, boil the rivers, and melt the stone into glass. Now an endless waste of crystallized sand and blackened ruins.",
        history = {
            before = "Thriving elven forest realm for thousands of years. Canopy cities, river archives, magical scholarship.",
            destruction = "Heaven's Atlas activation turned forests to glass, rivers to vapor, and stone to sand in a single cataclysmic event.",
            after = "Sealed and uninhabitable. Return forbidden. Serves as monument to war's horror and justification for magic ban.",
        },
        currentStatus = "Lifeless. Nothing grows. Strange lights and whispers reported by travelers.",
        significance = "The empire points to Calidar whenever justifying magic control: 'This is what happens when power goes unchecked.'",
        elvishMemory = "Every elf knows the names of the lost cities. Return is forbidden. Memorialization permitted only through approved channels.",
    },

    shadowfen = {
        name = "Shadowfen",
        type = "contested_frontier",
        location = "Southwestern swamplands",
        description = "Dense swamps, dark forests, and marshlands where imperial authority weakens. Too dangerous to fully control, too marginal to invest heavily in pacification.",
        inhabitants = {"human", "orc", "beast_folk", "outcasts"},
        characteristics = {
            "Perpetual mist and dark waters",
            "Outcast communities fleeing imperial law",
            "Rumored vampire dens and forbidden practitioners",
            "Smuggling routes and black markets",
            "Imperial fortified outposts on borders only",
        },
        imperialPresence = "Weak. Luminary Inquest conducts periodic purges but the swamp swallows their efforts.",
        note = "Where the empire's grip loosens. Dangerous and valuable to those who need to disappear.",
    },

    forbiddenLands = {
        deserts = {
            name = "The Forbidden Deserts",
            alternateName = "The Great Endless Desert",
            location = "North beyond the Dwarven Mountains",
            description = "Vast deserts surrounding the known lands. Origin homeland of beast folk. Hidden beneath the sands lie lizard folk river civilizations, ancient empires that withdrew from the surface world. Extends far to the north, farther than imperial records acknowledge. Eventually gives way to ice.",
            geographicRole = "Continental barrier. Separates the known continent from northern ice lands (Frostbound Reach).",
        },
        scorchedSands = {
            name = "The Scorched Sands",
            location = "West of Orcish Steppes",
            description = "Barren desert serving as natural boundary between settled lands and the unknown west. Extends much farther than imperial maps acknowledge. Eventually reaches the Western Ocean.",
            geographicRole = "Continental barrier. Separates the known continent from the Western Ocean and lands beyond.",
        },
        frostboundReach = {
            name = "The Frostbound Reach",
            alternateName = "Northern Ice Lands",
            location = "Far north beyond the Great Endless Desert",
            description = "Frozen wastes where desert heat gives way to tundra and ice. Dwarves know the ice exists, and their deepest holds extend into permafrost, but even dwarves do not venture to the surface there. Theoretical northern pole, potentially mirroring southern ice beyond Calidar.",
            imperialKnowledge = "Not acknowledged. Undermines narrative of total dominion.",
            knownBy = {"dwarves (underground)", "lizard folk astronomers (theoretical maps)"},
        },
        oceans = {
            name = "The Deep Oceans",
            description = "As far as recorded knowledge extends, nothing habitable exists beyond them, or nothing that wishes to be found.",
        },
    },

    beyondTheEmpire = {
        note = "The Holy Empire controls the central continent. What lies beyond is treated as irrelevant, or worse, nonexistent. This is strategic ignorance. Long-lived races know the world does not end where imperial maps do.",

        westernOcean = {
            name = "The Western Ocean",
            alternateName = "The Outer Waters",
            location = "Beyond the Scorched Sands to the west",
            description = "If one travels far enough west across the Scorched Sands, the desert gives way to coastline. The Western Ocean stretches beyond, darker, colder, and far more dangerous than the Silver Seas. Called 'Outer Waters' by those who know it: water beyond the empire's light.",
            imperialKnowledge = "Not acknowledged. Official maps claim the Scorched Sands extend infinitely westward.",
            knownBy = {"lizard folk (ancient charts)", "cat folk (coastal trade routes)", "gnomes (airship observation)"},
            accessibility = "Beyond imperial reach. Requires crossing desert or airship flight.",
        },

        ashenArchipelago = {
            name = "The Ashen Archipelago",
            location = "Volcanic islands in the Western Ocean",
            description = "Scattered volcanic islands rising from the Outer Waters. Active peaks support life through volcanic soil, coral reefs, and sheltered harbors. Settlements exist, independent, uncontacted, and unmapped by imperial cartographers.",
            population = "Unknown. Estimated small coastal communities.",
            imperialKnowledge = "None. Gap in official geography.",
            knownBy = {"lizard folk astronomers (star charts and ocean currents)", "gnomes (airship mapping, not shared)"},
            accessibility = "Too far for imperial ships, too marginal to justify conquest. Deliberately ignored.",
        },

        greatWesternIsle = {
            name = "The Great Western Isle",
            location = "Large landmass west of Ashen Archipelago",
            description = "A continent-sized landmass separated from the known world by desert, ocean, and deliberate ignorance. Only the longest-lived lizard folk speak of it, individuals 700+ years old who studied pre-war charts. They mention it rarely, and never to humans.",
            population = "Unknown. Possibly independent civilization.",
            imperialKnowledge = "None. Or classified if elven sealed archives contain references.",
            knownBy = {"oldest lizard folk (pre-war charts)", "elven sealed archives (possibly)", "gnomes (possibly, unconfirmed)"},
            significance = "Ultimate challenge to imperial doctrine: proof that the world extends beyond their control, and always has.",
        },

        cyclicalGeography = {
            concept = "Long-lived observers recognize a pattern: Land → Sand → Water → Land → Ice",
            examples = {
                north = "Mountains → Desert → Ice (Frostbound Reach) → Unknown",
                south = "Forests → Wastes → (Theoretical: Ocean → Ice → Unknown)",
                east = "Continent → Ocean (Silver Seas) → Islands (Gnomish) → Ocean (Shimmering Sea) → Unknown",
                west = "Steppes → Desert (Scorched Sands) → Ocean (Outer Waters) → Islands (Ashen) → Land (Great Western Isle) → Unknown",
            },
            principle = "The world is cyclical. Barriers separate landmasses, but barriers are crossable for those with means: ships, airships, desert navigation, cold resistance.",
            politicalTruth = "The Holy Empire controls one continent. Calling it 'the world' is political fiction, not geographical fact.",
        },

        whyIgnored = {
            reason = "The empire's power is based on documentation, enforcement, and narrative control. Acknowledging distant civilizations would undermine all three pillars:",
            consequences = {
                "Populations outside census control",
                "Lands beyond enforcement reach",
                "Proof that imperial authority has limits",
            },
            solution = "The empire simply doesn't acknowledge them. Maps end where authority ends. What lies beyond is labeled 'wasteland' or 'impassable barrier' or omitted entirely.",
            effectiveness = "Works because most humans never leave imperial territory. They trust official maps. They assume the world is as documented.",
            counterKnowledge = "Long-lived races know better. They remember when maps were different. They keep their own records. They understand that empires rise and fall, but geography endures.",
        },
    },

    seas = {
        silverSeas = {
            name = "The Silver Seas",
            alternateName = "The Shimmering Sea",
            description = "The vast ocean separating the Main Continent from the Gnomish Isles. Nearly 280 kilometers (174 miles) of open water, roughly the distance between Japan and Korea. This immense separation has protected gnomish independence for centuries. Naval crossing requires 5-7 days by ship in good weather, exposing invading fleets to storms, sea creatures, and gnomish coastal defenses. No imperial invasion has ever succeeded. Trade occurs through designated routes to Clockwork Harbor, but the ocean itself is a formidable barrier.",
            distance = "280 kilometers (56 tiles × 5km/tile)",
            crossingTime = "5-7 days by sailing ship, 1-2 days by gnomish airship (not available to outsiders)",
            dangers = "Storms, sea creatures, gnomish defenses, extended exposure",
            strategicImportance = "Primary defense of Gnomish Collective. Makes naval invasion nearly impossible.",
        },
    },
}

-- ============================================================================
--                         POPULATION DATA
-- ============================================================================

LoreManager.POPULATION = {
    totalWorld = 2330000,  -- 2.33 million

    races = {
        human = {
            population = 1000000,
            percentage = 42.9,
            primaryRegion = "holy_dominion",
            description = "Dominate the political center of the world through institutions, not numbers alone.",
        },
        elf = {
            population = 500000,
            percentage = 21.5,
            primaryRegion = "southern_holy_dominion",
            formerHomeland = "Calidar (destroyed 500 years ago, now Wastes of Calidar)",
            description = "Survivors of Calidar's destruction, integrated into the Holy Empire as bureaucratic caste. Serve as administrators, archivists, and legal scholars. The empire's right hand, necessary but resented.",
            integration = "Survival, not choice. 80-90% of pre-war population killed. Survivors fled north under imperial escort.",
        },
        gnome = {
            population = 340000,
            percentage = 14.6,
            primaryRegion = "gnomish_isles",
            description = "A collectivist society with no private ownership. All assets belong to the people. Automatons serve as population multipliers.",
        },
        orc = {
            population = 240000,
            percentage = 10.3,
            primaryRegion = "orcish_steppes",
            description = "Nomadic steppe warriors who once formed history's most effective military civilization. Currently fragmented but dormant, not defeated.",
        },
        dwarf = {
            population = 185000,
            percentage = 7.9,
            primaryRegion = "dwarven_mountains",
            description = "The Deep Kin who dwell in northern mountain ranges, living almost entirely underground.",
        },
        beast_folk = {
            population = 45200,
            percentage = 1.9,
            primaryRegion = "diaspora",
            description = "A diasporic people from the great deserts, displaced over generations by war, drought, and expanding empires. They travel in family groups along established routes, valuing portability over possession. Primarily cat folk in the modern era.",
            subtypes = {
                cat_folk = {population = 30000, traits = {"gambling", "performance", "fortune telling", "pattern recognition"}},
                other = {population = 15200, traits = {"various desert-born peoples"}},
            },
            note = "Few in number but culturally visible. Most cities host small, semi-permanent communities.",
        },
        lizard_folk = {
            population = 15000,
            percentage = 0.6,
            primaryRegion = "hidden_rivers",
            description = "Heirs to an ancient hidden river civilization. Organized into secretive sects that control specific knowledge domains. Rarely seen outside desert lands except when purpose demands it.",
            note = "Population estimates are unreliable. The lizard folk do not share census data with outsiders.",
        },
        goblin = {
            population = "unknown",
            percentage = "uncounted",
            primaryRegion = "scattered",
            description = "Decentralized resistance fighters living in warrens, tunnels, and ruins across the continent. The empire does not count 'vermin.'",
            note = "Goblins do not take censuses. Imperial estimates vary wildly based on political convenience.",
        },
    },

    -- Population notes
    notes = {
        "Civilization is not sparse, but compressed",
        "Cities and major towns are crowded, loud, and alive",
        "Large stretches of countryside are lightly settled, patrolled, or abandoned",
        "Most citizens may live their entire lives without seeing more than one or two beast folk",
    },
}

-- ============================================================================
--                         RACES AND FACTIONS
-- ============================================================================

LoreManager.RACES = {
    human = {
        id = "human",
        name = "Human",
        namePlural = "Humans",
        faction = "holy_dominion",
        lifespan = {min = 60, max = 90},
        traits = {"institutional power", "religious zeal", "law-focused"},

        religion = {
            pantheon = true,
            primaryGod = "helios",
            doctrine = "Magic is not a right. It is a weapon.",
        },

        magicPolicy = {
            legal = "state_sanctioned_only",
            punishment = "execution and ritual soul destruction",
            note = "Wizards, mages, and warlocks are legal only as agents of the state",
        },

        enforcement = {
            body = "The Luminary Inquest",
            role = "Roving enforcement body tasked with regulation of existence itself",
            authority = "Supersedes local law, city guards, and regional governance",
            reputation = "Feared for brutality and immediate enforcement",
            reach = "Operates across all imperial territory with divine mandate from Helios",
        },

        appearance = {
            skinTones = {"pale", "fair", "tan", "olive", "brown", "dark"},
            hairColors = {"black", "brown", "blonde", "red", "grey", "white"},
            eyeColors = {"brown", "blue", "green", "grey", "hazel"},
        },
    },

    elf = {
        id = "elf",
        name = "Elf",
        namePlural = "Elves",
        faction = "elven_administration",
        lifespan = {min = 10000, max = 10000},  -- 10,000 years
        traits = {"bureaucratic", "archivists", "diplomats", "legal scholars", "long memory", "administered remnant"},

        role = "The bureaucratic backbone of civilization",
        relationship = "Tense partner with humans, described as the empire's right hand",

        -- Historical Tragedy
        homeland = {
            name = "Calidar",
            status = "Destroyed 500 years ago",
            current = "Wastes of Calidar (glass desert, uninhabitable)",
            description = "Thriving elven forest realm for thousands of years. Canopy cities, river archives, magical scholarship.",
            destruction = {
                method = "Heaven's Atlas activation by Holy Empire",
                result = "Forests vitrified, rivers boiled, stone melted to glass",
                casualties = "Estimated 80-90% of elven population (millions dead)",
                survivors = "Fled north under imperial escort. Refugee columns recorded in exhaustive detail.",
            },
            memory = "Every elf knows the names of the lost cities. Return is forbidden. Memorialization permitted only through approved channels.",
        },

        -- Integration (Survival, Not Choice)
        integration = {
            when = "500 years ago, after Calidar's destruction",
            nature = "Survival, not choice. Elven resistance ended quickly after total military defeat.",
            terms = {
                "Official status as 'equal partners' in imperial administration",
                "Territory south of capital for settlement (not Calidar, a constant reminder)",
                "Protection under imperial law",
                "Employment in bureaucracy, trade regulation, record-keeping",
            },
            exchange = {
                "Abandon claims to Calidar",
                "Accept human political supremacy",
                "Publicly support magic ban",
                "Serve the empire that destroyed them",
            },
            reality = "Integration was containment. Elves became indispensable to imperial bureaucracy. Empire needed them. Elves needed survival. Neither trusts the other.",
        },

        -- Magic Policy
        magicPolicy = {
            official = "Reject magic entirely, laws mirror human doctrine",
            unofficial = "Magic survives in sealed archives, forgotten bloodlines, and buried knowledge",
            truth = "Elves did not destroy magic. They hid it.",
            risk = "Discovery means execution and soul destruction. Most elves choose silence.",
        },

        -- Cultural Preservation
        culture = {
            preservation = {
                "Archives - meticulous records of everything, including Calidar",
                "Oral tradition - songs and stories in Old Elvish (not written, so they can't be confiscated)",
                "Gardens - cultivating Calidar-native plants from saved seeds (technically illegal)",
                "Names - every elven child knows the forest names of Calidar",
                "Memory - obligation to remember what was taken",
            },
            languages = {
                "Common (required by law for official business)",
                "High Elvish (scholarly language, tolerated)",
                "Old Elvish (pre-war dialect, oral tradition, monitored)",
                "Forest Tongue (Calidar dialect, illegal if documented, implies separatism)",
            },
            holidays = {
                official = {"Imperial holidays", "Integration Day"},
                unofficial = {"Day of Glass (Calidar's destruction)", "Night of Names (lost forests)", "Planting Day (Calidar plants)"},
            },
            calendar = {
                official = "Imperial calendar (Year 1 = end of war)",
                unofficial = "BA/AA calendar (Before Atlas / After Atlas) - kept privately, treason if discovered",
            },
        },

        -- Generational Memory (10,000 year lifespan creates unique dynamics)
        generations = {
            ancientOnes = {
                age = "5000+ years",
                experience = "Remember empires that existed before the Holy Dominion was founded",
                outlook = "Timeless perspective. See patterns across ages. Silent witnesses to cycles of power.",
            },
            oldOnes = {
                age = "500-5000 years",
                experience = "Personally witnessed Calidar's destruction",
                outlook = "Silent. Patient. Waiting. Remember everything. Reveal nothing. Document imperial mistakes.",
            },
            middle = {
                age = "100-500 years",
                experience = "Raised by trauma survivors",
                outlook = "Subtle activists. Navigate empire carefully. Quiet aid to persecuted.",
            },
            young = {
                age = "<100 years",
                experience = "Never knew pre-war Calidar",
                outlook = "Integrated but taught to remember. Question what was lost.",
            },
        },

        -- The Silent Question
        silentQuestion = {
            question = "If we could recover Heaven's Atlas, what would we do with it?",
            possibleAnswers = {
                "Destroy it (prevent another genocide)",
                "Hide it (keep it from imperial hands)",
                "Use it (turn the imperial capital to glass)",
            },
            truth = "No elf answers aloud. The empire watches. Elves document the watching. History will judge.",
        },

        -- Settlement
        settlement = {
            primary = "Southern Holy Dominion (south of capital)",
            pattern = "Planned districts, reconstructed cities, managed forests, administrative centers",
            note = "Not Calidar. Every settlement is a reminder of what was lost and will never return.",
        },

        -- Quiet Leverage
        leverage = {
            institutionalKnowledge = "Elves know where records are kept, what they say, which are fake",
            longMemory = "Humans rotate every 30-50 years. Elves remember 10,000 years.",
            preparation = "Preparing for the next empire. When the Dominion falls, elves will still be here, with complete records.",
        },

        appearance = {
            skinTones = {"pale", "fair", "golden", "bronze"},
            hairColors = {"silver", "gold", "black", "white", "auburn"},
            eyeColors = {"blue", "silver", "gold", "green", "violet"},
            features = {"pointed ears", "angular features", "tall and slender"},
        },
    },

    orc = {
        id = "orc",
        name = "Orc",
        namePlural = "Orcs",
        faction = "orc_clans",
        lifespan = {min = 300, max = 500},  -- 300-500 years (CRITICAL: Khan died 45 years ago, veterans still alive)
        traits = {"nomadic", "steppe warriors", "merit-based", "disciplined", "historically unified"},

        -- Historical Legacy
        history = {
            peak = "At their height, the orcish clans formed the most effective military civilization the world has ever known.",
            unification = "Under a Great Khan, rival clans were bound together into a single war machine.",
            achievements = {
                "Reshaped borders and shattered kingdoms",
                "Conducted rapid continent-spanning campaigns",
                "Sustained armies without fixed supply lines",
                "Coordinated forces across vast distances",
                "Absorbed conquered peoples rather than annihilating them",
            },
            legacy = "Even in the present age, the memory of orcish unification governs imperial policy.",
        },

        -- Nomadic Society
        society = {
            structure = "Nomadic steppe civilization bound not to land, but to movement",
            movement = "Clans follow seasonal routes across western grasslands, steppes, and badlands",
            settlements = "Permanent cities are rare and intentionally temporary",
            imperialView = "Labeled as barbarians and savages",
            truth = "This propaganda justifies constant military readiness against a perceived existential threat",
        },

        -- Training & Warfare
        warfare = {
            training = "Every orc is raised to ride, fight, and obey command",
            doctrine = "Warfare built on speed, intelligence, and psychological collapse, not brute force",
            tactics = {
                "Constant mobility",
                "Decentralized command backed by absolute obedience",
                "Sophisticated signaling through riders, banners, and horns",
                "Feigned retreats and encirclement",
            },
            philosophy = "They do not fight wars of attrition. They fight wars of collapse.",
            principle = "An enemy that loses cohesion is already defeated.",
            method = "Strike with speed, gather what is needed, and move on. Resistance punished ruthlessly. Submission rewarded with protection and integration.",
        },

        -- Law & Order
        law = {
            code = "Strict and universal legal code",
            principles = {
                "Theft within the clan is punished severely",
                "Disobedience during war is unforgivable",
                "Rank determined by merit, not blood",
                "Loyalty to the Khan overrides all other bonds",
                "The law applies equally to all, including leaders",
            },
            outsiderView = "Appears brutal",
            orcView = "The reason their society survives",
        },

        -- Religion & Beliefs
        religion = {
            gods = false,
            reverence = {"the open sky", "the eternal road", "ancestral memory", "fate proven through victory"},
            philosophy = "Power is not granted by divine favor. It is demonstrated through action.",
            magicPolicy = "Tolerated only when it serves survival or war",
            forbidden = {"Necromancy", "Demons", "Undeath"},
            forbiddenReason = "Rejected as dishonorable distortions of strength",
        },

        -- Current State
        modernEra = {
            status = "Fewer in number and divided into fragmented clans",
            orcPerspective = "Fragmentation is not defeat, but dormancy",
            preserved = {"The laws still exist", "The routes are remembered", "The old commands are taught"},
            imperialFear = "The orcs do not need to grow stronger. They only need to unite again.",
        },

        -- How Others View Orcs
        outsiderViews = {
            human = "Fear as existential military threat. Study their past campaigns obsessively. Propaganda exaggerates savagery to justify readiness.",
            elf = "Respect their wartime administration but consider them dangerously unrestrained.",
            gnome = "Classify as high-mobility destabilizing forces. Quietly plan around them.",
            dwarf = "Remember fighting them underground. Sealed tunnels forever afterward.",
        },

        appearance = {
            skinTones = {"green", "grey", "brown", "olive-green"},
            hairColors = {"black", "dark brown", "grey"},
            eyeColors = {"red", "yellow", "orange", "brown"},
            features = {"tusks", "muscular build", "broad features", "riders' physique"},
        },
    },

    dwarf = {
        id = "dwarf",
        name = "Dwarf",
        namePlural = "Dwarves",
        faction = "dwarven_holds",
        lifespan = {min = 300, max = 500},  -- 300-500 years
        traits = {"collectivist", "guild-based", "craft-focused", "asexual", "isolationist"},

        -- Core Philosophy
        philosophy = {
            motto = "The mountains stand because the dwarves stand together.",
            belief = "All value is created through labor. Stone, metal, and craft hold no meaning until shaped by collective effort.",
            principle = "No one stands above another. No labor is taken without return.",
            ownership = "No individual may claim ownership over mines, forges, or halls. All productive spaces belong to the hold itself.",
        },

        -- Society Structure
        society = {
            structure = "Free Holds - vast interconnected underground cities",
            origin = "Emerged from generations of shared labor under extreme conditions where survival depended on collective effort",
            governance = {
                type = "Guild councils",
                leaders = "No kings, nobles, or permanent leaders",
                councils = "Formed from working guilds representing essential forms of labor",
                purpose = "Coordinate production, resolve disputes, maintain safety, not to rule",
                authority = "Temporary, revocable, bound to responsibility rather than power",
            },
            labor = {
                principle = "Every dwarf contributes according to ability and receives according to need",
                voluntary = "Voluntary in name, compulsory through social expectation",
                hoarding = "Viewed as violation of communal trust",
                accumulation = "Treated as theft from the collective",
                prestige = "Comes from mastery of craft and willingness to share knowledge, not possession",
            },
        },

        -- Biology
        biology = {
            reproduction = "Asexual - stone born offspring",
            growth = "Numbers grow slowly",
            significance = "Each dwarf represents generations of labor invested by the hold itself",
            consequence = "Scarcity reinforces emphasis on preservation, education, and interdependence",
            loss = "Loss is communal. Survival is shared.",
        },

        -- Conflict Resolution
        conflict = {
            method = "Resolved internally through mediation and collective judgment",
            punishment = "Favors restitution and reintegration over exile or execution",
            refusalToContribute = "Results in isolation from communal resources until participation resumes",
            violence = "Rare between dwarves, regarded as failure of the collective rather than individual crime",
        },

        -- Religion
        religion = {
            gods = false,
            role = "Faith plays little role in dwarven life",
            fundamentalTruths = {"Stone", "Time", "Labor"},
            history = "Preserved through carved record halls where deeds of the collective are inscribed",
            glorification = "Names fade while work remains. No individual glorification.",
        },

        -- Surface Relations
        surfaceRelations = {
            contact = "Limited and transactional",
            trade = {"Finished goods", "Raw materials", "Engineering expertise"},
            rejection = "Reject surface political structures",
            empiresView = "Viewed as unstable systems built on extraction without reciprocity",
            religionView = "Religious authority treated with skepticism",
            hierarchyAttempts = "Attempts to impose hierarchy upon dwarven holds have failed repeatedly",
        },

        -- Modern Era
        modernEra = {
            status = "Holds remain active, densely populated, and internally stable",
            misperception = "Outsiders often mistake isolation for stagnation",
            reality = "Continue refining systems of production, safety, and distribution beyond reach of surface politics",
        },

        -- How Others View Dwarves
        outsiderViews = {
            human = "Useful trading partners but frustratingly uninterested in surface politics or religion",
            elf = "Respect their record-keeping and craftsmanship. Find their rejection of hierarchy puzzling.",
            orc = "Respect their defensive capabilities. Remember sealed tunnels from past conflicts.",
            gnome = "Recognize kindred collectivists, though with different methods. Occasional cooperation.",
            beastFolk = "Rarely interact. Mutual indifference.",
        },

        appearance = {
            skinTones = {"pale", "grey", "stone-like"},
            hairColors = {"brown", "black", "red", "grey", "white"},
            eyeColors = {"grey", "brown", "amber", "deep blue"},
            features = {"short and stocky", "dense beards", "broad shoulders"},
        },
    },

    gnome = {
        id = "gnome",
        name = "Gnome",
        namePlural = "Gnomes",
        faction = "gnomish_collective",
        lifespan = {min = 200, max = 350},
        traits = {"collectivist", "industrialist", "secretive", "technologically advanced", "isolationist"},

        -- Core Philosophy
        philosophy = {
            belief = "Gnomes do not believe in ownership. They believe in function.",
            system = "Rigidly structured collectivist society",
            principle = "Prestige comes from contribution, not accumulation",
        },

        -- Collectivist Society
        society = {
            structure = "Absolute collective ownership",
            collectiveAssets = {
                "Factories",
                "Mines",
                "Workshops",
                "Farms",
                "Energy engines",
                "Airship docks",
                "Automaton foundries",
            },
            prohibitions = {
                "No gnome owns land, industry, or infrastructure",
                "No private companies",
                "No noble houses",
                "No inherited wealth",
            },
            guaranteedRights = {
                "Housing",
                "Education",
                "Healthcare",
                "Sustenance",
            },
        },

        -- Labor System
        labor = {
            requirement = "Every gnome works",
            assignmentBasis = {"Aptitude", "Training", "Societal need"},
            education = "Children educated broadly, then directed into useful fields",
            careerMobility = "Changing professions possible but regulated to avoid inefficiency",
            ambition = "No concept of 'career ambition' in the human sense",
            refusal = "Those who refuse work are reassigned, retrained, or quietly isolated until compliant",
        },

        -- Governance
        governance = {
            rulers = "Production councils, not kings or priests",
            councilComposition = {"Engineers", "Logisticians", "Planners", "Statisticians"},
            decisionBasis = "Efficiency models and resource projections, not ideology or faith",
            religion = "No religion in gnomish society. Faith is a personal curiosity, not a social foundation.",
        },

        -- Technology
        technology = {
            level = "Far exceeding other races",
            known = {"advanced machinery", "automatons", "precision industry"},
            secret = {"airships", "aerial infrastructure", "air travel"},
            secrecyReason = "Exposure would invite human invasion, religious domination, forced 'liberation' from Helios' doctrine, and private ownership imposition",
        },

        -- Automatons
        automatons = {
            gnomeView = "Tools that free people from drudgery. Population multipliers.",
            purpose = {
                "Maintain industrial output",
                "Eliminate exploitative labor",
                "Reduce physical risk to citizens",
                "Ensure consistent production",
            },
            outsiderView = "Reviled as abominations or metal-bound liches",
            gnomeResponse = "Dismissed as superstition, and quietly tolerated, because fear keeps borders intact",
            necessity = "With only 340,000 gnomes, automation allows the collective to function",
        },

        -- Air Travel
        airTravel = {
            purpose = {
                "Rapid internal logistics",
                "Resource redistribution",
                "Defense without mass armies",
            },
            secrecyReason = {
                "Human invasion",
                "Religious domination",
                "Forced 'liberation' from Helios' doctrine",
                "Private ownership and class stratification",
            },
            philosophy = "Secrecy is not paranoia. It is class defense.",
        },

        -- View of Others
        outsiderView = {
            humanEmpire = "Represents everything gnomes rejected: hierarchy, faith-based law, ownership-driven inequality",
        },

        appearance = {
            skinTones = {"pale", "tan", "rosy"},
            hairColors = {"white", "silver", "blonde", "auburn", "wild colors"},
            eyeColors = {"blue", "green", "amber", "violet"},
            features = {"small stature", "large eyes", "pointed ears", "nimble hands"},
        },
    },

    beast_folk = {
        id = "beast_folk",
        name = "Beast Folk",
        namePlural = "Beast Folk",
        faction = "none",
        lifespan = {min = 50, max = 80},
        traits = {"diasporic", "desert-born", "mobile", "culturally resilient", "family-bound"},

        -- Core Philosophy
        philosophy = {
            truth = "Beast folk do not originate from a single kingdom, nor do they recognize borders as permanent truths.",
            survival = "Survival comes not from claiming land, but from knowing how to exist within other peoples' lands without belonging to them.",
            values = "Portability over possession. Skills over property. Relationships over wealth.",
        },

        -- History
        history = {
            origin = "The great deserts beyond the known lands",
            diaspora = "A diasporic people displaced over generations by war, drought, and expanding empires",
            displacement = {
                "Some fled ahead of conquest",
                "Others were pushed aside by borders that did not recognize their way of life",
                "Over time, they learned that survival did not come from claiming land",
            },
            lesson = "They learned to exist within other peoples' lands without belonging to them.",
        },

        -- Society Structure
        society = {
            structure = "Extended family groups bound by kinship, tradition, and shared memory",
            movement = "Travel along long-established routes between cities, towns, and trade hubs",
            settlement = {
                "Rarely own land",
                "Rent, camp, or settle temporarily where tolerance allows",
                "Permanent settlement is possible but uncommon",
            },
            culture = {
                "Values portability over possession",
                "Skills passed orally",
                "Crafts are lightweight",
                "Wealth measured in relationships, reputation, and adaptability, not property",
            },
        },

        -- Life Without a Homeland
        lifeWithoutHomeland = {
            principle = "Life without a homeland shapes everything",
            mobility = "Movement born from caution and experience. Outsiders call it secrecy or refusal to integrate, but they weren't there.",
            misunderstanding = "Outsiders see secrecy or refusal. Beast folk understand survival.",
        },

        -- Perception and Prejudice
        perception = {
            status = "Tolerated, distrusted, romanticized, and scapegoated, often at the same time",
            humanView = "Classified as foreigners regardless of how long they have lived within imperial borders",
            elfView = "Documented meticulously while rarely granting full recognition",
            orcView = "Respected for their mobility",
            gnomeView = "Culturally resilient but economically inefficient",
            dwarfView = "Largely ignored",
            scapegoating = "When economies tighten or unrest grows, beast folk are often blamed first",
            welcome = "When entertainment or novelty is desired, they are welcomed briefly",
            memory = "Beast folk remember this contradiction well.",
        },

        -- Culture and Memory
        culture = {
            preservation = "Culture preserved through story, song, craft, and ritual, not written record",
            history = "Carried by elders and performers",
            names = "Names matter. Lineage is remembered even when land is not.",
            loyalty = "Family loyalty is paramount",
            outsiders = "Outsiders may be welcomed warmly, but betrayal is remembered across generations",
            memory = "This long memory is not vengeance-driven. It is protective.",
            goals = "They do not seek power over others. They seek the ability to move, trade, live, and raise children without persecution.",
        },

        -- Relationship to Law
        law = {
            approach = "Obey local laws when possible, but rarely trust them",
            reason = "Legal systems have historically shifted against them without warning",
            solution = "Rely more on internal mediation and communal judgment than imperial courts",
            misinterpretation = "Often misinterpreted as lawlessness",
            truth = "In truth, it is a parallel system built because the dominant one rarely protected them.",
        },

        -- Modern Era
        modernEra = {
            status = "Few in number but culturally visible",
            presence = "Most cities host small, semi-permanent communities",
            gatheringPlaces = "A handful of towns become known gathering places",
            startingCity = "Fortune's Rest in the desert is the most famous gathering place, though even humble crossroads villages like Havenbrook welcome travelers of all kinds",
            perception = {
                citizens = "To most citizens, beast folk are a curiosity",
                authorities = "To authorities, they are a variable",
                themselves = "To themselves, they are survivors continuing a story that never fully found a home",
            },
        },

        -- Cat Folk Specifics (beast_folk now refers primarily to cat folk)
        catFolk = {
            name = "Cat Folk",
            traits = {"gambling", "performance", "fortune telling", "pattern recognition"},

            -- Culture of Chance
            cultureOfChance = {
                association = "Especially associated with games of chance, performance, and fortune telling",
                why = "Gambling halls, card tables, and betting circuits offer opportunity without requiring land, titles, or citizenship",
                evolution = "Over time, this association became cultural identity",
            },

            -- Philosophy of Luck
            luck = {
                belief = "Cat folk do not believe chance is random",
                truth = "They believe it reflects attention, timing, and respect for risk",
                reputation = "Their reputation for luck is less superstition than pattern recognition refined over generations",
            },

            -- Where They Gather
            gathering = {
                reason = "Places built on chance feel familiar",
                benefit = "They allow cat folk to exist openly without explaining themselves",
                startingCity = "This is why certain towns, especially the starting city, attract cat folk consistently",
            },
        },

        -- Note: Lizard folk are now a separate race entry with distinct origins
        relatedRaces = {"lizard_folk"},

        appearance = {
            features = {"feline features", "fur patterns", "cat ears", "tails", "slit pupils"},
            skinTones = {"varies with fur color"},
            eyeColors = {"gold", "green", "amber", "blue"},
        },
    },

    lizard_folk = {
        id = "lizard_folk",
        name = "Lizard Folk",
        namePlural = "Lizard Folk",
        faction = "lizard_folk_sects",
        lifespan = {min = 600, max = 800},
        traits = {"secretive", "sect-bound", "knowledge-keepers", "ancient heritage", "selective presence"},

        -- Core Philosophy
        philosophy = {
            motto = "The lizard folk endure through secrecy, continuity, and control of what others overlook.",
            survival = "Knowledge, not territory, defined their survival.",
            principle = "What is hidden endures. What is revealed can be taken.",
        },

        -- History
        history = {
            origin = "An ancient desert civilization that once ruled fertile river corridors hidden deep within the sands",
            cities = "Cities rose along rivers that outsiders rarely found and vanished just as quietly when conditions changed",
            withdrawal = "Over generations, the lizard folk withdrew from open empire and turned inward",
            legacy = "What remains today is a culture shaped by secrecy, preservation, and selective presence in the wider world",
            outsiderKnowledge = "Other races know the lizard folk as heirs to a forgotten river empire. Few understand how much of that empire still exists, hidden beneath sand, stone, and silence.",
        },

        -- The Hidden River Empire
        hiddenEmpire = {
            name = "The Hidden River Civilization",
            nature = "Fertile river corridors hidden deep within the desert sands",
            visibility = "Rivers that outsiders rarely found",
            currentState = "Much of the empire still exists, hidden beneath sand, stone, and silence",
            secret = "Few outsiders understand how much remains",
        },

        -- Society Structure
        society = {
            structure = "Divided into sects bound by ritual, lineage, and guarded knowledge",
            governance = "No single authority governs all sects",
            unity = "Maintained through shared memory and mutual dependence rather than centralized rule",
            secrecy = "Sects rarely reveal themselves fully to outsiders",
            information = "Information is shared deliberately and often incompletely",
        },

        -- The Sects
        sects = {
            description = "Each sect maintains control over specific traditions",
            domains = {
                "River engineering",
                "Burial rites",
                "Trade routes",
                "Astronomy",
                "Martial discipline",
            },
            secrecy = "Outsiders may encounter a caravan leader, scholar, or mercenary officer without ever realizing which sect they serve or what deeper obligations bind them",
        },

        -- Modern Era
        modernEra = {
            presence = "Rarely seen beyond desert lands except when purpose demands it",
            roles = {"guides", "traders", "engineers", "silent observers"},
            settlement = "Permanent settlement outside ancestral regions is uncommon",
            response = "When threats arise, the sects respond quietly and decisively, often without drawing attention",
        },

        -- How Others View Lizard Folk
        outsiderViews = {
            general = "Known as heirs to a forgotten river empire",
            human = "Mysterious desert dwellers with valuable knowledge. Useful but not fully trusted.",
            elf = "Respect their record-keeping and ancient traditions. Recognize kindred archivists.",
            orc = "Admire their discipline and martial sects. Wary of their secrets.",
            gnome = "Fascinated by their engineering knowledge. Frustrated by their secrecy.",
            dwarf = "Recognize fellow keepers of hidden places. Rare contact, mutual respect.",
            catFolk = "Distant cousins from the same deserts. Different paths, occasional cooperation.",
        },

        appearance = {
            features = {"scaled skin", "reptilian features", "tail", "forked tongue", "heat-sensing pits"},
            skinTones = {"green", "brown", "tan", "grey", "sand-colored", "river-mud brown"},
            eyeColors = {"yellow", "orange", "red", "black", "gold"},
            build = "Lean and enduring, adapted to desert heat and hidden waterways",
        },
    },

    goblin = {
        id = "goblin",
        name = "Goblin",
        namePlural = "Goblins",
        faction = "goblin_resistance",
        lifespan = {min = 30, max = 60},
        traits = {"fiercely anti-empire", "guerrilla fighters", "decentralized", "memory-keepers", "survivors", "ideologically committed"},

        -- Core Philosophy
        philosophy = {
            motto = "The empire is illegitimate. The occupation ends when we say it ends.",
            belief = "Goblins do not seek conquest. They seek LIBERATION from imperial occupation.",
            principle = "What was stolen will be reclaimed. What was burned will be avenged. The empire built its roads on goblin graves.",
            ideology = "Active, principled anti-imperialism. The empire has no right to exist on stolen land.",
        },

        -- History
        history = {
            origin = "Once held territories across the continent before imperial invasion",
            invasion = "The empire systematically exterminated goblin communities during 'consolidation.' Entire warrens massacred, elders burned alive, children killed.",
            theft = "Imperial settlers moved into cleared goblin lands. Imperial law declared ancestral goblin territory 'uninhabited wilderness.'",
            occupation = "The empire now criminalizes goblin presence on their own ancestral lands, calling it 'illegal trespassing.'",
            resistance = "Goblins refuse to die, refuse to submit, refuse to recognize imperial legitimacy.",
            legacy = "Every goblin knows the names of stolen homelands, the methods of imperial massacres, and the debt owed. Every goblin teaches them to their children.",
        },

        -- Society Structure
        society = {
            structure = "Cell-based resistance network",
            leadership = "No central command, no capitals, no kings",
            organization = {
                "Small, autonomous cells of 5-20 goblins",
                "Cells coordinate through coded signals and dead drops",
                "No single leader whose death would end the resistance",
                "Each cell self-sufficient and capable of independent action",
            },
            bonds = "United by shared grievance, not hierarchy",
            principle = "If you capture one cell, you learn nothing about the others.",
        },

        -- Warfare Doctrine
        warfare = {
            doctrine = "Anti-imperial insurgency: ambush, sabotage, assassination, economic warfare",
            philosophy = "A goblin does not fight wars. A goblin wages LIBERATION.",
            tactics = {
                "Strike supply lines to starve the occupation",
                "Sabotage imperial infrastructure built on stolen land",
                "Ambush imperial patrols and kill occupation forces",
                "Assassinate imperial governors and garrison commanders",
                "Vanish into tunnels the empire doesn't know exist",
                "Make occupation prohibitively expensive and bloody",
                "Target collaborators as traitors to their species",
            },
            goal = "Make the occupation so costly, so bloody, so endless that the empire abandons goblin lands or collapses trying to hold them",
            principle = "The empire must guard everything. We need only strike once. They need an army to hold what one goblin can destroy.",
            legitimacy = "Goblins do not recognize imperial courts, imperial law, or imperial borders on stolen land. The empire's 'legal authority' is the logic of thieves.",
        },

        -- Culture
        culture = {
            core = "Memory is the foundation of goblin identity",
            traditions = {
                "Names of martyrs passed down through generations",
                "Maps of lost homelands memorized, never written",
                "Songs of resistance sung in hidden places",
                "Every injustice catalogued and remembered",
            },
            values = {"patience", "cunning", "collective memory", "survival"},
            motto = "They can burn our warrens. They cannot burn what we remember.",
            sayings = {
                "No one is illegal on stolen land.",
                "The quiet resistance endures.",
                "Strike once. Let them guard everything.",
                "Teach the names. The names are homeland.",
            },
        },

        -- How Others View Goblins
        outsiderViews = {
            human_imperial = "'Terrorists.' 'Vermin.' Imperial propaganda portrays goblins as mindless raiders to justify extermination campaigns. Colonial settlers deny goblin claims to ancestral land.",
            human_dissident = "Some recognize goblin resistance as justified. Desert communes and Shadow Fen dissidents sometimes find common cause with goblin cells. The enemy of my enemy...",
            elf = "View goblins as 'destabilizing elements.' Elves acknowledge goblin land claims are valid but say 'escalation is unproductive.' Translation: submit quietly.",
            orc = "Respect goblin effectiveness. Orcish clans understand fighting empires from weakness. Some orc bands coordinate with goblin cells against imperial targets.",
            gnome = "Study goblin resistance with academic detachment. Classify as 'successful asymmetric resistance model.' Knowledge without action.",
            dwarf = "Officially neutral. Seal tunnels when goblin activity is detected near holds. Dwarves won't fight goblins' war, but won't fight FOR the empire either.",
            lizardfolk = "Recognize goblins as fellow victims of imperial aggression. Shadow Fen provides intelligence support to some goblin cells. Shared enemy creates shared purpose.",
            beastfolk = "Sympathize with goblin displacement, as Beast Folk were also scattered by empire. Some caravan networks provide safe passage for goblin couriers.",
        },

        -- Current State
        modernEra = {
            status = "Scattered cells operating across the continent",
            population = "Unknown. Goblins do not take censuses, and the empire does not count 'vermin'.",
            locations = {"abandoned mines", "sewer systems", "forest warrens", "ruins", "mountain caves"},
            threat = "Low individually, persistent collectively. No imperial campaign has ever fully eradicated them.",
        },

        -- Imperial Response
        imperialResponse = {
            official = "Pest control. Goblin extermination is a civic duty. They are criminals trespassing on imperial land.",
            reality = "Goblin resistance costs the empire millions annually. The resistance is self-sustaining. Goblins predate the empire by millennia.",
            frustration = "Every warren cleared spawns two more. Every cell destroyed is replaced within months. Imperial governors rotate out within two years from stress.",
            unwinnable = "The empire cannot eradicate goblins without depopulating entire regions. Goblins have nothing left to lose, multi-generational commitment, and home terrain advantage. This is an unwinnable war. The empire knows it. The killing continues anyway.",
        },

        appearance = {
            skinTones = {"green", "grey-green", "olive", "brown-green"},
            hairColors = {"black", "dark brown", "none"},
            eyeColors = {"yellow", "orange", "red", "amber"},
            features = {"small stature", "pointed ears", "sharp teeth", "wiry build", "excellent night vision"},
        },
    },
}

-- ============================================================================
--                         FACTIONS
-- ============================================================================

LoreManager.FACTIONS = {
    holy_dominion = {
        id = "holy_dominion",
        name = "The Holy Dominion",
        alternateName = "The Holy Empire",
        type = "theocratic_empire",
        primaryRace = "human",

        description = "Rose after the Last World War. Declared that magic, left unchecked, was the root cause of the world's near-destruction.",

        doctrine = {
            magicControl = "All magic users must be state sanctioned",
            punishment = "Unsanctioned magic is treason, punishable by death and ritual soul destruction",
            purges = {"illegal magic", "necromancy", "demons", "heresy"},
        },

        divineMandate = "Claims divine mandate from Helios to purge corruption in all forms",

        -- THE LUMINARY INQUEST - Enforcement Body
        luminaryInquest = {
            officialName = "The Luminary Inquest",
            commonNames = {"The Inquest", "Luminaries", "Sun Enforcers"},
            unofficialNames = "Names spoken quietly and rarely written",

            authority = {
                source = "Answers directly to the highest imperial authority",
                mandate = "Claims divine mandate from Helios, the Sun God",
                purpose = "Regulation of existence itself",
                frame = "Officially framed as protection of civilization",
            },

            jurisdiction = {
                scope = "Moves freely across imperial territory",
                supersedes = {"Local law", "City guards", "Regional governance"},
                effect = "When the Inquest arrives, jurisdiction collapses inward",
                principle = "What matters is what can be proven, recorded, and sanctioned under their interpretation of doctrine",
            },

            methods = {
                reputation = "Widely known for brutality",
                investigation = "Sudden, without warning",
                accusations = "Made publicly",
                enforcement = "Immediate",
                process = "Suspects isolated, restrained, and judged on the spot",
                verification = {"Documentation review", "Magical verification", "Doctrinal authority"},
                executions = {
                    visibility = "Conducted openly and efficiently",
                    philosophy = "Visibility reinforces order",
                    collateralDamage = "Recorded as acceptable loss in service of security",
                },
            },

            publicPerception = {
                citizens = "Deep resentment and quiet hatred",
                disruption = "Presence disrupts daily life, commerce, and community trust",
                fear = {
                    "Taverns fall silent when Inquest insignia appear",
                    "Markets empty",
                    "Neighbors avoid eye contact",
                },
                compliance = "Fear sustains compliance",
                justification = "Framed as necessary defense against remembered horrors",
                rememberedHorrors = {"Vampires", "Demons", "Necromancers", "War-born atrocities"},
                belief = "Most citizens tolerate brutality as the price of safety",
                resistance = "Rare. Few dare to say they disagree openly.",
            },

            dangerOfInnocence = {
                truth = "Innocence does not guarantee safety",
                triggers = {"Missing paper", "Mismatched record", "Clerical inconsistency"},
                escalation = "Can escalate into fatal suspicion",
                appeals = "Rare",
                reversals = "Almost nonexistent",
            },

            enforcementOfExistence = {
                beyond = "Beyond extermination of forbidden beings",
                scope = "Enforces identity itself",
                verification = {
                    subject = "Allied and tolerated races",
                    frequency = "Constant",
                    demanded = {"Travel papers", "Residency permits", "Lineage records", "Magical certifications"},
                    timing = "Without warning",
                },
                failure = {
                    interpretation = "Treated as intent to deceive",
                    consequence = "Detention often follows",
                    disappearances = "Explained as administrative resolution",
                },
                scrutinyTargets = {
                    "Beast folk (heaviest scrutiny)",
                    "Migrant laborers",
                    "Border populations",
                    "Anyone living near vice districts",
                },
                assumption = "Mixed communities viewed as inherently unstable",
            },

            composition = {
                structure = "Small, mobile detachments",
                selection = {"Loyalty", "Doctrinal compliance"},
                training = "Trained to suppress personal hesitation",
                culture = {
                    "Emotional detachment encouraged",
                    "Individual identity discouraged",
                },
                uniforms = "Immaculate",
                records = "Meticulous",
                mercy = "Not documented",
            },

            belief = {
                truebelievers = "Many operatives believe fully in their mandate",
                pragmatists = "Others continue service because departure is not simple",
                silence = "Silence ensures survival",
            },

            relationshipsWithPower = {
                localOfficials = {
                    outward = "Cooperate outwardly",
                    inward = "Resent inwardly",
                },
                elves = "Comply through bureaucracy while attempting to limit access",
                gnomes = "Deny entry entirely",
                orcs = "Avoid through mobility",
                dwarves = "Restrict contact to fortified gates",
                beastFolk = "Inspected relentlessly",
                empire = {
                    public = "Praised publicly",
                    private = "Few leaders wish to see them too often",
                    distance = "Maintains plausible distance",
                },
            },
        },
    },

    elven_administration = {
        id = "elven_administration",
        name = "The Elven Administration",
        type = "bureaucratic_partner",
        primaryRace = "elf",

        description = "Serves as the bureaucratic backbone of civilization alongside humans.",
        roles = {"administrators", "archivists", "diplomats", "trade regulators", "legal scholars"},

        relationship = {
            withHumans = "Necessary but tense partner",
            nickname = "The Empire's right hand",
        },
    },

    orc_clans = {
        id = "orc_clans",
        name = "The Orc Clans",
        alternateName = "The Khanate (historical)",
        type = "nomadic_military_confederation",
        primaryRace = "orc",

        description = "Nomadic steppe civilization that once formed the most effective military force the world has ever known. Currently fragmented but not defeated, merely dormant.",

        history = {
            peak = "Under a Great Khan, unified clans reshaped borders and shattered kingdoms",
            legacy = "Their past campaigns are still studied obsessively by imperial strategists",
            imperialFear = "They do not need to grow stronger. They only need to unite again.",
        },

        society = {
            structure = "Clans following seasonal routes across steppes and badlands",
            law = "Strict universal code: merit over blood, loyalty to Khan, equality under law",
            training = "Every orc raised to ride, fight, and obey command",
        },

        warfare = {
            doctrine = "Speed, intelligence, and psychological collapse, not brute force",
            tactics = {"Constant mobility", "Decentralized command", "Feigned retreats", "Encirclement"},
            principle = "Wars of collapse, not attrition",
        },

        religion = {
            type = "Ancestral reverence",
            reverence = {"Open sky", "Eternal road", "Ancestral memory", "Victory as proof of fate"},
            magicPolicy = "Tolerated only for survival or war. Necromancy and demons rejected as dishonorable.",
        },

        currentStatus = "Fragmented clans preserving laws, routes, and commands for potential reunification",

        values = {"discipline", "merit", "mobility", "obedience", "honor in strength"},
        stance = "Dormant, not defeated. The laws still exist. The routes are remembered.",
    },

    dwarven_holds = {
        id = "dwarven_holds",
        name = "The Free Holds of Stone",
        alternateName = "The Dwarven Holds",
        type = "collectivist_labor_federation",
        primaryRace = "dwarf",

        description = "The dwarves govern themselves through guild councils, labor rotation, and collective ownership. No kings. No lords. No inherited rank. Only the work you contribute and the stone you serve.",

        philosophy = {
            motto = "Labor belongs to those who give it. Stone belongs to those who work it.",
            corePrinciple = "A hold is not owned by anyone. It is maintained by everyone.",
            rejection = "Hierarchy and inherited privilege create weakness and entitlement",
        },

        governance = {
            type = "Guild Councils",
            composition = {"Miners", "Smiths", "Engineers", "Brewers", "Stonecutters", "Wardens"},
            rotation = "Leadership positions rotate by schedule, not election",
            decisions = "Collective deliberation, not inherited authority",
            note = "No dwarf rules another. Tasks are assigned by necessity and rotated to ensure fairness.",
        },

        economy = {
            type = "Collective ownership",
            principle = "Every dwarf who works the stone shares its bounty",
            distribution = "Resources allocated by council consensus based on need",
            prohibitions = {"No private ownership of holds", "No inherited wealth", "No accumulation beyond contribution"},
            trade = "Surface trade conducted through designated guilds, not individuals",
        },

        labor = {
            centrality = "Labor is the foundation of dwarven identity and ethics",
            value = "A dwarf's value is their contribution, measured not in wealth but in work",
            rotation = "All dwarves participate in labor rotation across guilds",
            specialization = "Mastery in a craft earns respect, not privilege",
        },

        reproduction = {
            method = "Stone-born (asexual budding from living rock)",
            process = "New dwarves emerge from sacred stone chambers when conditions align",
            note = "No biological parents, no family lines, no inheritance disputes",
            implication = "Every dwarf is equally a child of the stone",
        },

        conflictResolution = {
            method = "Council mediation",
            principle = "Disputes are resolved through labor arbitration",
            punishment = "Restitution through work, not violence or exile",
            philosophy = "Conflict weakens the hold. Resolution strengthens it.",
        },

        religion = {
            stance = "Dwarves do not worship gods",
            beliefs = {"Stone is truth", "Time is law", "Labor is meaning"},
            philosophy = "What is built matters. What is believed does not.",
        },

        surfaceRelations = {
            frequency = "Limited and transactional",
            attitude = "Surface peoples are customers, not partners",
            trade = {"Metal goods", "Stonework", "Engineering consultation"},
            caution = "Surface hierarchies are seen as inefficient and morally suspect",
        },

        currentStatus = "Self-sufficient and deliberately isolated. The holds endure as they always have: through labor, stone, and collective will.",
        stance = "The surface can fight over crowns. Dwarves build.",
    },

    gnomish_collective = {
        id = "gnomish_collective",
        name = "The Gnomish Collective",
        alternateName = "The Gnomish Republic",
        type = "collectivist_industrial_state",
        primaryRace = "gnome",

        description = "A rigidly structured collectivist society built on absolute collective ownership and industrial automation.",

        governance = {
            type = "Production Councils",
            composition = {"Engineers", "Logisticians", "Planners", "Statisticians"},
            basis = "Efficiency models and resource projections",
            note = "No kings, no priests, no ideology or faith",
        },

        economy = {
            type = "Collective ownership",
            assets = "All factories, mines, workshops, farms, energy engines, airship docks, and automaton foundries belong to the people",
            prohibitions = {"No private companies", "No noble houses", "No inherited wealth"},
            guarantees = {"Housing", "Education", "Healthcare", "Sustenance"},
        },

        labor = {
            requirement = "Every gnome works",
            assignment = "Based on aptitude, training, and societal need",
            mobility = "Regulated to avoid inefficiency",
        },

        technology = {
            automatons = "Population multipliers that free gnomes from drudgery",
            airships = "Enable rapid logistics, resource redistribution, and defense without mass armies",
        },

        policy = {
            secrecy = "Secrecy is not paranoia. It is class defense.",
            reason = "Exposure would invite human invasion and forced imposition of hierarchy, faith-based law, and ownership-driven inequality",
        },

        religion = "None. Faith is considered a personal curiosity, not a social foundation.",
    },

    goblin_resistance = {
        id = "goblin_resistance",
        name = "The Goblin Resistance",
        alternateName = "The Warrens",
        type = "anti_imperial_insurgency_network",
        primaryRace = "goblin",

        description = "A fiercely anti-imperial resistance movement of goblin cells operating independently across the continent. No central command, no kings, no capitals. Only shared memory, collective rage, and principled opposition to imperial occupation.",

        philosophy = {
            motto = "The empire is illegitimate. The occupation ends when we say it ends.",
            ideology = "Active, principled anti-imperialism. The empire has no right to exist on stolen land.",
            goal = "LIBERATION, not survival. Reclamation, not remembrance. The empire must withdraw or collapse.",
            method = "Make occupation so costly, so bloody, so endless that the empire abandons goblin lands or bleeds trying to hold them.",
        },

        organization = {
            structure = "Autonomous anti-imperial cells of 5-20 goblins",
            leadership = "No single leader. Each cell operates independently but shares anti-empire ideology.",
            coordination = "Coded signals, dead drops, oral tradition, anti-imperial networks",
            resilience = "Capture one cell, learn nothing about the others. Kill one cell, two more rise in its place.",
            collaborators = "Goblins who cooperate with the empire are considered traitors to their species. Shunned or eliminated.",
        },

        warfare = {
            doctrine = "Anti-imperial insurgency",
            tactics = {"Ambush imperial patrols", "Sabotage imperial infrastructure", "Assassinate imperial officials", "Supply line raids", "Economic warfare", "Propaganda of the deed"},
            principle = "The empire must guard everything. We need only strike once. They need an army to hold what one goblin can destroy.",
            goal = "Not compromise. Not coexistence. Imperial withdrawal or imperial collapse.",
            legitimacy = "Goblins do not recognize imperial courts, imperial law, or imperial borders on stolen land.",
        },

        culture = {
            foundation = "Memory",
            preserved = {"Names of martyrs", "Maps of lost homelands", "Songs of resistance", "Catalogue of injustices"},
            transmission = "Oral tradition. Nothing written that can be captured.",
        },

        currentStatus = "Active cells in mines, sewers, forests, ruins, and mountain caves across the continent",
        imperialView = "Pest control problem, not military threat",
        reality = "Every warren cleared spawns two more. The resistance is self-sustaining.",
    },

    lizard_folk_sects = {
        id = "lizard_folk_sects",
        name = "The Lizard Folk Sects",
        alternateName = "Keepers of the Hidden River",
        type = "secretive_knowledge_confederation",
        primaryRace = "lizard_folk",

        description = "A confederation of secretive sects that preserve the knowledge and traditions of the ancient hidden river civilization. No single authority governs all sects; unity is maintained through shared memory and mutual dependence.",

        history = {
            origin = "An ancient desert civilization that ruled fertile river corridors hidden deep within the sands",
            cities = "Cities rose along rivers that outsiders rarely found",
            withdrawal = "Over generations, the lizard folk withdrew from open empire and turned inward",
            legacy = "Much of the empire still exists, hidden beneath sand, stone, and silence",
        },

        organization = {
            structure = "Sects bound by ritual, lineage, and guarded knowledge",
            governance = "No single authority governs all sects",
            unity = "Maintained through shared memory and mutual dependence",
            secrecy = "Information shared deliberately and often incompletely",
        },

        sectDomains = {
            "River engineering - control of hidden waterways and irrigation",
            "Burial rites - preservation of the dead and ancestral memory",
            "Trade routes - knowledge of desert paths and safe passages",
            "Astronomy - celestial navigation and calendar keeping",
            "Martial discipline - protection of sect interests and hidden places",
        },

        policy = {
            outsiders = "Sects rarely reveal themselves fully. Outsiders may encounter a caravan leader, scholar, or mercenary officer without ever realizing which sect they serve.",
            threats = "When threats arise, the sects respond quietly and decisively, often without drawing attention.",
            presence = "Rarely seen beyond desert lands except when purpose demands it.",
        },

        currentStatus = "Hidden empire that endures through secrecy, continuity, and control of what others overlook",

        -- Sub-Organization: The Veiled Hand
        veiledHand = {
            founded = "500 years ago, immediately after witnessing Calidar's destruction",
            foundingSect = "Astronomical observation sect (long-range observation and celestial record-keeping)",
            motivation = "Witnessed Heaven's Atlas activation from afar. Concluded that absolute power must be constrained through precision removal of key individuals.",
            note = "See veiled_hand faction for complete details",
        },
    },

    shadowfen_commune = {
        id = "shadowfen_commune",
        name = "The Shadow Fen Commune",
        alternateName = "The Veiled Refuge",
        type = "magically_concealed_commune",
        primaryRace = "mixed",

        description = "A hidden refuge in southwestern swamplands, protected by pervasive magical concealment and infernal pacts. Founded by refugees fleeing imperial control in the decades after the Last World War.",

        location = {
            region = "Southwestern swamplands",
            terrain = "Dense swamps, dark forests, marshlands, perpetual mist",
            mapStatus = "Marked as uninhabitable on imperial maps",
            reality = "Thriving commune of 8,000-12,000 residents",
        },

        -- The Veil
        magicalConcealment = {
            name = "The Veil",
            nature = "Pervasive magical field woven into water, fog, and root",
            effect = "Redirects perception of the unaware. Paths loop endlessly, landmarks dissolve, settlements vanish.",
            reveal = "Only to those with intent to flee imperial control or guided by residents",
            maintenance = "Self-sustaining through resident mages, infernal reinforcement, magically aware swamp",
        },

        -- Origins
        origins = {
            timeline = "Decades following the Last World War (Years 1-100)",
            firstRefugees = {
                "Calidar survivors who refused integration",
                "Displaced villages erased by imperial consolidation",
                "Laborers whose papers failed Luminary Inquest inspection",
                "Families fleeing after Inquest visits",
                "Unsanctioned mages, hedge witches, warlocks",
            },
            development = "Survival turned into organization. Camps became villages. Scarcity created communal labor.",
            nature = "Commune born of exclusion rather than ideology",
        },

        -- Infernal Pacts
        infernalPacts = {
            formed = "After imperial patrols repeatedly attempted entry and failed",
            entities = "Devils and lesser demons bound to swamp's deeper layers",
            exchange = {
                communeOffers = {"Regular offerings (blood, materials, souls of condemned)", "Access to mortal agents", "Knowledge sharing", "Recognition of infernal presence"},
                infernalProvides = {"Hardened borders through wards", "Devouring mists", "Path collapse behind intruders", "Enhanced concealment", "Warning systems"},
            },
            consequences = {
                "Some residents bear infernal marks",
                "Children born in fen occasionally manifest demonic traits",
                "Swamp itself subtly changed",
                "Souls bound to infernal contracts",
            },
            result = "Hardened the fen's borders. Luminary Inquest classifies as corrupted exclusion zone and avoids it.",
        },

        -- Governance
        governance = {
            type = "Secret Council",
            membership = "Never publicly confirmed (rumored 7-12 members)",
            decisionMaking = "Communicated through trusted intermediaries",
            authority = "Flows through consensus, not command",
            enforcement = "Mediation (public), disappearance (private)",
            infernalHybridRumor = {
                claim = "An infernal hybrid guides or controls the council",
                evidence = "None. Those who ask too openly tend to disappear.",
                truth = "Unknown. Decisions favor preservation of refuge above all else.",
                speculation = "Council likely works WITH infernal powers as partners, not servants or masters.",
            },
        },

        -- Life Within
        dailyLife = {
            work = "Communal labor organized by necessity",
            food = "Shared equally through communal distribution",
            shelter = "Temporary by design (paths shift, names change)",
            education = "Children taught survival: quiet movement, fog reading, imperial symbol recognition",
            magic = "Practiced openly but cautiously. Excess endangers commune. Balance enforced socially.",
            identity = "Papers burned upon entry. Past lives don't matter. Names optional.",
        },

        -- Population
        population = {
            total = "8,000-12,000 (empire estimates 'hundreds')",
            composition = {
                fugitiveHumans = "35%",
                elves = "20% (Old Ones who refused integration)",
                unsanctionedMages = "15%",
                beastFolk = "15%",
                orcs = "8%",
                goblins = "5%",
                infernalTouched = "2%",
            },
        },

        -- Settlements
        settlements = {
            murkmire = {
                name = "Murkmire",
                size = "~4,000 people (largest)",
                structure = "Built on massive stilts above water",
                role = "Neutral ground, taverns, markets, communal halls",
                rule = "No violence within boundaries (enforced through exile or worse)",
            },
            drownedVillages = {
                count = "7-12 settlements",
                size = "200-800 each",
                structure = "Artificial islands",
                specialization = "Fishing, hunting, foraging",
                infernalPacts = "Each has relationship with specific local entities",
            },
            deepSanctuaries = {
                count = "Unknown number",
                visibility = "Hidden",
                purpose = "Mage enclaves, archive chambers, ritual sites for pact maintenance",
                access = "Council members and high initiates only",
            },
        },

        -- Imperial Relations
        imperialRelations = {
            official = "Denied legitimacy. 'Nest of corruption and heresy.' Abandoned to infernal forces.",
            practical = "Tolerated as containment zone. Absorbs malcontents. Prevents urban rebellion.",
            enforcement = "Patrol routes adjusted to avoid. Maps grow vague. Records contradict themselves.",
            truth = "Empire remembers Calidar. Knows the fen is protected by powers they cannot easily counter. Tolerates existence as long as it remains contained.",
        },

        currentStatus = "Thriving hidden commune. Protected by Veil and infernal pacts. Governed by secret council. Serves as refuge for empire's unwanted.",
    },

    veiled_hand = {
        id = "veiled_hand",
        name = "The Veiled Hand",
        alternateName = "The Assassins of Memory",
        type = "secretive_assassination_network",
        primaryRace = "lizard_folk",  -- Founders, but mixed membership

        description = "Assassin organization founded 500 years ago by lizard folk sect that witnessed Calidar's destruction. Exists to prevent escalation to mass atrocity through precision removal of key individuals.",

        -- Origins
        origins = {
            when = "500 years ago (Year 1 of current age)",
            founders = "Lizard folk sect tasked with astronomical observation and celestial record-keeping",
            catalystEvent = "Witnessed Heaven's Atlas activation and Calidar's destruction from afar",
            measurement = "Rivers vanished from charts. Star alignments shifted. Magical currents collapsed. Entire civilization ended in single recorded event.",
            conclusion = "Power had escaped all restraint. Empires with absolute force can only be constrained through precision, patience, and removal of key individuals before catastrophe.",
        },

        -- Philosophy
        philosophy = {
            motto = "Preventing a single decision can save countless lives.",
            purpose = "Limit escalation. Act where law, protest, and war fail.",
            principle = "History is shaped by those who authorize atrocity. Remove them before authorization.",
            lesson = "If Heaven's Atlas required authorization, removing the authorizer would have saved Calidar.",
            mission = "Ensure such a decision is never made again without consequence.",
        },

        -- Structure
        structure = {
            organization = "Compartmentalized cells",
            levels = {"Initiates (highest - lizard folk founders)", "Operatives (trained assassins)", "Informants (intelligence only)", "Support Network (shelter, documents, resources)"},
            knowledgeLimits = "No member understands full scope. Capture reveals minimal information.",
            leadership = "Exists but never visible. Decisions communicated indirectly through symbols and intermediaries.",
        },

        -- Membership
        membership = {
            races = {"Lizard Folk (founders, highest positions)", "Shadow Fen commune members", "Beast Folk (mobility, diaspora networks)", "Elves (Old Ones, institutional knowledge)", "Goblins (resistance tactical support)", "Humans (rarely, exceptional cases)"},
            selectionCriteria = {"Patience (observe for years without acting)", "Restraint (distinguish target from collateral)", "Silence (success means no recognition)", "Commitment (mission over survival)"},
            training = {"Disappearance", "Natural death simulation", "Long-term observation", "Escape artistry"},
        },

        -- Targeting
        targeting = {
            targets = {
                "Imperial officials authorizing mass purges",
                "Inquest commanders expanding beyond containment",
                "Military officers planning invasions of independent territories",
                "Those developing weapons of mass magical destruction",
                "Betrayers who would guide patrols into Shadow Fen",
            },
            notTargeted = {
                "Low-level enforcers (following orders, not authorizing)",
                "Corrupt officials (petty evil is not existential threat)",
                "Political rivals (not a contract-killing service)",
                "Random citizens (exists to prevent mass death, not cause it)",
            },
            selectionProcess = "Observation → Deliberation → Judgment → Authorization → Execution (if threshold met)",
            deterrence = "Many observed targets never struck. Knowing they're watched changes behavior.",
        },

        -- Methods
        methods = {
            intelligence = "Months to years of observation",
            preferredExecution = "Staged accidents (falls, drowning, fire)",
            acceptableExecution = "Poison (slow-acting, appears as natural illness)",
            rareExecution = "Direct assassination (only when other methods impossible)",
            neverUsed = "Public spectacle (defeats the purpose)",
            aftermath = "Operative vanishes immediately. No credit taken. Appears as natural death.",
        },

        -- Relationship with Shadow Fen
        shadowFenRelations = {
            fenProvides = {"Operational base", "Recruitment pool", "Intelligence network", "Sanctuary between missions"},
            handProvides = {"External protection (eliminate threats before arrival)", "Strategic removals (Inquest commanders)", "Information leverage", "Deterrence"},
            arrangement = "Never spoken of openly. Most commune members know Hand exists. Few know who belongs. Fewer ask.",
        },

        -- Imperial Relations
        imperialRelations = {
            official = "Denies existence. 'Organized assassin guilds are paranoid fantasy.'",
            internal = "Patterns too consistent to ignore. Standing orders to investigate. No unit has returned with intelligence.",
            unableToprove = "Deaths appear natural. No captured operatives. No clear pattern. Divination fails in Shadow Fen.",
            strategicStalemate = "Empire cannot prove Hand exists. Hand cannot eliminate empire. Deaths occur at rate empire can absorb.",
        },

        -- Legacy
        legacy = {
            lizardFolkSects = "Necessary deviation from secrecy. Knowledge alone was insufficient. Action became required.",
            shadowFenResidents = "Wary gratitude. Protection comes at cost. Few wish to know details.",
            thoseInPower = "Quiet dread. Not feared for frequency, but for selectivity. Every death becomes suspicious.",
        },

        currentStatus = "Active. Operates from Shadow Fen. Highest initiates tied to founding lizard folk sect. Membership unknown. Mission ongoing: prevent another Calidar.",
    },
}

-- ============================================================================
--                         RELIGION
-- ============================================================================

LoreManager.RELIGION = {
    humanPantheon = {
        name = "The Divine Pantheon",
        primaryFollowers = "human",

        gods = {
            helios = {
                id = "helios",
                name = "Helios",
                title = "The Sun God",
                domains = {"law", "order", "judgment", "civilization"},
                rank = "Supreme deity of the Holy Dominion",
                description = "Revered as the god of law, order, judgment, and civilization. The Holy Empire claims divine mandate from Helios.",
            },
            -- Other gods can be added as needed
        },
    },

    dwarvenBeliefs = {
        name = "The Stone Faith",
        primaryFollowers = "dwarf",
        type = "animistic",

        reverence = {"stone", "pressure", "time"},
        note = "Dwarves do not worship gods as others do",
    },
}

-- ============================================================================
--                         FORBIDDEN EXISTENCES
-- ============================================================================

LoreManager.FORBIDDEN = {
    vampires = {
        id = "vampire",
        name = "Vampires",
        status = "unperson",
        policy = "Kill on sight by all civilized powers",

        rules = {
            "No negotiations",
            "No trials",
            "No mercy",
        },

        locations = {"deep dungeons", "ruins", "corrupted dens", "forgotten places"},

        note = "Not counted as populations. Treated as infestations and existential threats.",
    },

    demons = {
        id = "demon",
        name = "Demons",
        status = "unperson",
        policy = "Kill on sight by all civilized powers",

        rules = {
            "No negotiations",
            "No trials",
            "No mercy",
        },

        locations = {"deep dungeons", "ruins", "corrupted dens", "forgotten places"},

        note = "Not counted as populations. Treated as existential threats.",
    },

    necromancy = {
        id = "necromancy",
        name = "Necromancy",
        status = "ultimate_sin",

        punishment = {
            "Execution",
            "Ritual soul annihilation",
            "Complete erasure from existence",
        },

        note = "Even the study of such magic is considered dangerous.",
    },
}

-- ============================================================================
--                         MAGIC SYSTEM
-- ============================================================================

LoreManager.MAGIC = {
    status = "heavily_regulated",

    doctrine = "Magic is not a right. It is a weapon.",

    legal = {
        requirement = "State sanctioned only",
        legalUsers = {"state agents", "licensed wizards", "imperial mages"},
    },

    illegal = {
        types = {"unsanctioned magic", "necromancy", "demon summoning", "blood magic"},
        punishment = "Treason - death followed by ritual destruction of the soul",
    },

    history = "The Last World War proved that unrestrained magic could erase civilization itself.",

    -- Technology
    magicDust = {
        name = "Refined Magic Dust",
        uses = {"minor enchantments", "lighting", "powering arcane devices"},
        note = "Controlled substance, requires license to sell",
    },
}

-- ============================================================================
--                         STARTING LOCATION
-- ============================================================================

LoreManager.STARTING_CITY = {
    name = "Havenbrook",  -- Can be renamed
    type = "village",
    controller = "human",

    description = "A humble crossroads village in the Holy Dominion. Quiet, cozy, and unremarkable on the surface, yet travelers are drawn here by some unseen pull. The Lucky Coin tavern serves as the social heart of this small community.",

    reputation = {
        "Quiet crossroads village",
        "Known for The Lucky Coin tavern",
        "Friendly to travelers and outsiders",
    },

    culture = {
        "A simple farming village where everyone knows each other",
        "Travelers pass through on their way to the capital city of Helios' Gate",
        "The tavern keeper Mira keeps the village connected to the wider world",
        "Elder Brom remembers when the village was even smaller",
    },

    beastFolkPresence = {
        reason = "Small villages sometimes welcome outsiders more readily than suspicious cities",
        population = "A handful of non-human residents, mostly passing travelers",
        integration = "Those who stay are accepted as neighbors",
        memory = "The village has always been a place where the road-weary can rest.",
    },

    playerStart = {
        location = "A cozy tavern at the heart of the village",
        role = "Tavern worker",
    },
}

-- The human capital (referenced by lore systems)
LoreManager.HUMAN_CAPITAL = {
    name = "Helios' Gate",
    type = "capital",
    controller = "human",

    description = "The grand capital of human civilization in the Holy Dominion. Towering walls of pale stone encircle sprawling districts. At its heart rises the Crown Keep, seat of King Aldren III.",

    reputation = {
        "Seat of the human king",
        "Center of law, commerce, and military power",
        "The War Academy trains the finest soldiers in the Dominion",
    },

    culture = {
        "A city of laws, ambition, and tradition",
        "Humans come from across the realm to seek fortune or serve the crown",
        "The Great Library holds centuries of accumulated knowledge",
        "Noble families vie for influence in the King's Court",
    },
}

-- ============================================================================
--                         TOWN RACIAL DISTRIBUTIONS
-- ============================================================================

-- Default racial distribution for towns by region
LoreManager.TOWN_DEMOGRAPHICS = {
    holy_dominion = {
        human = 0.70,
        elf = 0.15,
        beast_folk = 0.05,
        dwarf = 0.05,
        orc = 0.03,
        gnome = 0.02,
    },

    holy_dominion_gambling = {  -- For gambling cities like starting town
        human = 0.55,
        elf = 0.12,
        beast_folk = 0.20,  -- Cat folk drawn to gambling
        dwarf = 0.05,
        orc = 0.05,
        gnome = 0.03,
    },

    southern_reaches = {  -- Elven lands
        elf = 0.65,
        human = 0.25,
        beast_folk = 0.05,
        dwarf = 0.03,
        gnome = 0.02,
        orc = 0.00,
    },

    dwarven_mountains = {
        dwarf = 0.85,
        human = 0.08,
        gnome = 0.04,
        elf = 0.02,
        orc = 0.01,
        beast_folk = 0.00,
    },

    orcish_steppes = {
        orc = 0.75,
        human = 0.10,
        beast_folk = 0.08,
        elf = 0.04,
        dwarf = 0.02,
        gnome = 0.01,
    },

    gnomish_isles = {
        gnome = 0.92,
        human = 0.04,
        elf = 0.02,
        dwarf = 0.02,
        orc = 0.00,
        beast_folk = 0.00,
    },

    shadowfen = {
        human = 0.40,
        elf = 0.20,
        beast_folk = 0.15,  -- Lizard folk like swamps
        orc = 0.15,
        dwarf = 0.05,
        gnome = 0.05,
    },

    frontier = {  -- Wilderness areas
        human = 0.45,
        orc = 0.20,
        beast_folk = 0.15,
        elf = 0.10,
        dwarf = 0.08,
        gnome = 0.02,
    },

    desert = {  -- Desert oases
        beast_folk = 0.60,
        human = 0.25,
        orc = 0.10,
        elf = 0.03,
        dwarf = 0.02,
        gnome = 0.00,
    },
}

-- ============================================================================
--                         HELPER FUNCTIONS
-- ============================================================================

-- Get race data by ID
function LoreManager.getRace(raceId)
    return LoreManager.RACES[raceId]
end

-- Get faction data by ID
function LoreManager.getFaction(factionId)
    return LoreManager.FACTIONS[factionId]
end

-- Get population percentage for a race
function LoreManager.getRacePopulationPercent(raceId)
    local race = LoreManager.POPULATION.races[raceId]
    return race and race.percentage or 0
end

-- Get town demographics for a region
function LoreManager.getTownDemographics(regionId)
    return LoreManager.TOWN_DEMOGRAPHICS[regionId] or LoreManager.TOWN_DEMOGRAPHICS.frontier
end

-- Check if something is forbidden
function LoreManager.isForbidden(entityId)
    return LoreManager.FORBIDDEN[entityId] ~= nil
end

-- Get random lore fact
function LoreManager.getRandomFact()
    local facts = {
        "The Last World War proved that unrestrained magic could erase civilization.",
        "Magic is not a right. It is a weapon.",
        "Vampires and demons are treated as infestations, not populations.",
        "Elves did not destroy magic. They hid it.",
        "Gnomes have secretly mastered air travel.",
        "Dwarves are stone-born. They emerge from living rock, not biological reproduction.",
        "The Holy Empire claims divine mandate from Helios.",
        "Cat folk are drawn to gambling and probability.",
        "Necromancy is the ultimate sin.",
        "Most citizens may never see a beast folk in their lifetime.",
        -- Gnome facts
        "Gnomes do not believe in ownership. They believe in function.",
        "No gnome owns land, industry, or infrastructure. Everything belongs to the collective.",
        "Gnomish society has no religion. Faith is a personal curiosity, not law.",
        "Gnomes are ruled by production councils, not kings or priests.",
        "To gnomes, automatons are tools that free people from drudgery.",
        "Gnomish secrecy is not paranoia. It is class defense.",
        -- Orc facts
        "The orcs once formed the most effective military civilization the world has ever known.",
        "Under a Great Khan, the orc clans conquered half the known world.",
        "Orcish warfare is built on speed, intelligence, and psychological collapse, not brute force.",
        "The orcs do not fight wars of attrition. They fight wars of collapse.",
        "Orcish law applies equally to all, even to their Khan.",
        "Every orc is raised to ride, fight, and obey command.",
        "The orcs do not need to grow stronger. They only need to unite again.",
        "Imperial strategists still study orcish campaigns obsessively.",
        "Orcs reject necromancy and demons as dishonorable distortions of strength.",
        "Orc fragmentation is not defeat. It is dormancy.",
        -- Goblin facts
        "The empire is illegitimate. The occupation ends when we say it ends. This is the goblin way.",
        "No one is illegal on stolen land. This is the goblin answer to every imperial claim.",
        "Goblins are fiercely anti-empire. This is not passive resistance; it is active, ideological opposition to imperial occupation.",
        "Goblins view the empire as genocidal thieves who stole ancestral lands and massacred goblin populations.",
        "Goblins have no kings, no capitals, no central command to destroy.",
        "Every goblin knows the names of stolen homelands and the methods of imperial massacres.",
        "A goblin does not fight wars. A goblin wages LIBERATION.",
        "Capture one goblin cell, you learn nothing about the others. Kill one cell, two more rise in its place.",
        "The empire must guard everything. The resistance must only strike once.",
        "Goblins remember every injustice. Memory is their greatest weapon.",
        "Collaboration with the empire is considered species betrayal. Goblin collaborators are shunned or eliminated.",
        "Goblins do not recognize imperial courts, imperial law, or imperial borders on stolen land.",
        "Every imperial road is built on goblin graves. Goblins remember this. The empire forgets.",
        "Every warren cleared spawns two more. The resistance is self-sustaining.",
        "Imperial generals call it pest control. Imperial quartermasters call it a budget nightmare.",
        "They can burn goblin warrens. They cannot burn what goblins remember.",
        -- Beast folk / Cat folk facts
        "Beast folk do not recognize borders as permanent truths.",
        "Beast folk survival comes not from claiming land, but from knowing how to exist within other peoples' lands.",
        "Beast folk measure wealth in relationships, reputation, and adaptability, not property.",
        "Beast folk travel in extended family groups bound by kinship, tradition, and shared memory.",
        "Cat folk do not believe chance is random. They believe it reflects attention, timing, and respect for risk.",
        "Cat folk reputation for luck is less superstition than pattern recognition refined over generations.",
        "Beast folk obey local laws when possible, but rarely trust them. Legal systems have historically shifted against them without warning.",
        "Beast folk culture is preserved through story, song, craft, and ritual, not written record.",
        "Family loyalty is paramount among beast folk. Betrayal is remembered across generations.",
        "To beast folk, mobility is not secrecy. It is caution born from experience.",
        -- Lizard folk facts
        "The lizard folk endure through secrecy, continuity, and control of what others overlook.",
        "Lizard folk descend from an ancient civilization that ruled hidden river corridors deep within the desert sands.",
        "Knowledge, not territory, defines lizard folk survival.",
        "Lizard folk society is divided into sects bound by ritual, lineage, and guarded knowledge.",
        "No single authority governs all lizard folk sects. Unity is maintained through shared memory and mutual dependence.",
        "Lizard folk sects rarely reveal themselves fully to outsiders. Information is shared deliberately and often incompletely.",
        "Other races know lizard folk as heirs to a forgotten river empire. Few understand how much of that empire still exists.",
        "When threats arise, the lizard folk sects respond quietly and decisively, often without drawing attention.",
        "Lizard folk appear as guides, traders, engineers, or silent observers, but their true obligations remain hidden.",
        "Much of the ancient lizard folk empire still exists, hidden beneath sand, stone, and silence.",
        -- Dwarf facts
        "Dwarves do not believe in hierarchy. They believe in labor.",
        "No dwarf owns a hold. Every dwarf who works the stone shares its bounty.",
        "Dwarven society is governed by guild councils that rotate leadership by schedule, not election.",
        "A dwarf's value is their contribution, measured not in wealth, but in work.",
        "Dwarves are stone-born: new dwarves emerge from sacred stone chambers when conditions align.",
        "There are no family lines among dwarves. Every dwarf is equally a child of the stone.",
        "Dwarven disputes are resolved through council mediation and restitution through work.",
        "Dwarves do not worship gods. Stone is truth, time is law, labor is meaning.",
        "Surface peoples are customers to the dwarves, not partners. Trade is transactional.",
        "The Free Holds of Stone have endured for millennia through collective will and labor.",
        "Dwarves see surface hierarchies as inefficient and morally suspect.",
        "The surface can fight over crowns. Dwarves build.",
    }
    return facts[math.random(#facts)]
end

-- Get a random rumor based on region
function LoreManager.getRegionalRumor(regionId)
    local rumors = {
        holy_dominion = {
            "The Inquisitors have been more active lately...",
            "They say an unsanctioned mage was caught near the cathedral.",
            "Helios protects the faithful. The unfaithful... less so.",
            "I heard there's a vampire den somewhere in Shadowfen.",
        },
        dwarven_mountains = {
            "The dwarves have no kings. Just councils that rotate leadership by schedule.",
            "They say new dwarves emerge from the stone itself. No parents, no family lines.",
            "Dwarven holds don't belong to anyone. They're maintained by everyone who lives there.",
            "A dwarf's worth is measured in labor, not gold. Hoarding is looked down upon.",
            "The mines run deeper than anyone knows. The dwarves have been working them for millennia.",
            "Don't expect to buy land in a hold. They don't believe in private ownership.",
            "Dwarven guilds handle everything: mining, smithing, brewing, even settling disputes.",
            "The surface is just a marketplace to them. They do business and go home.",
            "They say dwarves live for centuries. The stone preserves them, they claim.",
            "Every dwarf works. There's no idle class, no nobility, no inheritance.",
        },
        orcish_steppes = {
            "The clans are restless. Something stirs in the badlands.",
            "Orcs don't want our cities. They want to be left alone.",
            "Cross an orc's honor and you cross the whole clan.",
            "They say a Khan once united all the clans. Conquered half the world.",
            "Imperial generals still study orcish tactics. They fear them that much.",
            "The orcs don't need to grow stronger. They just need to unite again.",
            "Orcish law applies even to their leaders. Even to their Khan.",
            "Every orc child learns to ride before they learn to walk.",
            "The old routes are still remembered. The old commands still taught.",
        },
        gnomish_isles = {
            "The gnomes know things they're not telling us.",
            "I've heard tales of metal men walking the gnome cities.",
            "No ship has ever returned from trying to invade the isles.",
            "They say no gnome owns anything. Everything belongs to everyone.",
            "Gnomes have no kings, no lords. Just... councils of engineers.",
            "The gnomes don't worship gods. They worship efficiency.",
            "I heard gnome children are assigned jobs before they can choose.",
        },
        shadowfen = {
            "Don't travel the fen at night. Things hunt there.",
            "They say Murkmire is haunted by more than ghosts.",
            "The vampires in Shadowfen are bolder than elsewhere.",
        },
        holy_dominion_gambling = {
            "The cat folk run half the card tables in this district. Don't play against them unless you're ready to lose.",
            "Beast folk don't own much land here, but they know everyone worth knowing.",
            "They say the cat folk can read luck like humans read words.",
            "That caravan? Beast folk. They've been running that route for generations.",
            "The elders remember when this town was less welcoming. They remember who helped and who didn't.",
            "Don't mistake their mobility for rootlessness. Their family connections span the continent.",
            "A cat folk fortune teller predicted the grain shortage last year. Coincidence? I wonder.",
            "Beast folk keep their own courts for disputes. Faster than imperial justice, and fairer too, some say.",
        },
        desert = {
            "The lizard folk know paths through the dunes that no map shows.",
            "Beast folk caravans have traveled these routes since before the empire existed.",
            "In the desert, the beast folk aren't visitors. We are.",
            "A lizard folk guide is worth ten maps and twenty scouts.",
            "They say the desert remembers. So do the beast folk who came from it.",
            "That trader? Lizard folk. You'll never know which sect he serves or what he's really watching for.",
            "The lizard folk had cities here once. Hidden rivers, they say. Most think it's legend.",
            "I hired a lizard folk engineer once. Fixed the well in half a day. Wouldn't explain how.",
            "The sects don't talk to each other openly, but when one moves, they all know.",
            "Don't ask a lizard folk about the old empire. They'll tell you exactly as much as they want you to know.",
        },
        hidden_rivers = {
            "There are rivers beneath the sand. The lizard folk have always known.",
            "The old cities still exist. You just can't find them unless they want you to.",
            "Each sect guards different knowledge. River paths, star charts, burial grounds.",
            "A lizard folk mercenary officer died here last year. Three sects sent representatives to the burial. In secret.",
            "They say the lizard folk astronomers can predict the rains. They just don't share when.",
        },
        frontier = {
            "Goblin raid hit the supply convoy again. Fifth time this month. Command calls it 'pest control.' Feels like a war.",
            "The garrison doubled patrols, but the goblins just wait them out. They're patient. We're not.",
            "Don't underestimate goblins. They've outlasted every empire that tried to eradicate them. They'll outlast this one too.",
            "A merchant said goblin raids cost more to prevent than they ever steal. Empire's bleeding gold just to hold this territory.",
            "Caught a goblin during the raid. Asked why they 'trespass' on imperial land. They said: 'No one is illegal on stolen land.' Then vanished through a tunnel we didn't know existed.",
            "Goblins killed an imperial tax collector near the mines. Left his body on the road with a sign: 'The empire is illegitimate.'",
            "Every imperial road is built on goblin graves. The goblins remember. We pretend to forget.",
            "The old tunnels connect. The goblins know paths we've forgotten.",
        },
        mines = {
            "Goblins in the deep tunnels. They know these mines better than we do.",
            "Every shaft we clear, they open two more. It's not worth the cost.",
            "The foreman says goblin sabotage is why production is down. Convenient excuse, if you ask me.",
            "They say goblins have lived in these mountains since before humans arrived.",
            "The resistance is patient. They'll outlast us.",
        },
    }

    local regionRumors = rumors[regionId] or rumors.holy_dominion
    return regionRumors[math.random(#regionRumors)]
end

return LoreManager
