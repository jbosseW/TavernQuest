local Glossary = {}

Glossary.terms = {
    -- COMBAT/RPG STATS & MECHANICS (12 terms)
    {
        id = "might",
        term = "Might",
        definition = "Primary combat stat governing physical damage, weapon effectiveness, and melee attacks. Higher Might allows you to defeat stronger enemies and unlock powerful warrior abilities.",
        category = "combat",
        seeAlso = {"agility", "vigor", "stats_overview"},
    },
    {
        id = "agility",
        term = "Agility",
        definition = "Determines dodge chance, critical hit rate, and turn order in combat. Agile characters strike first and evade incoming attacks more frequently.",
        category = "combat",
        seeAlso = {"might", "dodge", "critical_hit"},
    },
    {
        id = "vigor",
        term = "Vigor",
        definition = "Governs maximum health, stamina regeneration, and physical resistance. High Vigor keeps you alive during prolonged battles and expeditions.",
        category = "combat",
        seeAlso = {"might", "agility", "stats_overview"},
    },
    {
        id = "mind",
        term = "Mind",
        definition = "Intelligence stat that increases spell damage, magical defense, and mana pool size. Essential for wizards and alchemists seeking to master arcane arts.",
        category = "combat",
        seeAlso = {"spirit", "spell_card", "alchemy_phases"},
    },
    {
        id = "spirit",
        term = "Spirit",
        definition = "Spiritual energy governing healing effectiveness, mana regeneration, and resistance to curses. Spirit users excel at support roles and sustained magical combat.",
        category = "combat",
        seeAlso = {"mind", "faith", "presence"},
    },
    {
        id = "presence",
        term = "Presence",
        definition = "Charisma and force of personality that affects shop prices, quest rewards, employee morale, and companion loyalty. High Presence makes you a natural leader and shrewd negotiator.",
        category = "combat",
        seeAlso = {"reputation", "employees", "faith"},
    },
    {
        id = "faith",
        term = "Faith",
        definition = "Devotion stat that enhances holy magic, provides divine protection, and unlocks blessings from the deities. Faith empowers paladins and clerics with righteous power.",
        category = "combat",
        seeAlso = {"spirit", "presence", "stats_overview"},
    },
    {
        id = "stats_overview",
        term = "The Seven Stats",
        definition = "Core character attributes in Tavern Quest: Might, Agility, Vigor, Mind, Spirit, Presence, and Faith. Every character action, from combat to crafting to social interactions, is influenced by these fundamental stats.",
        category = "combat",
        seeAlso = {"might", "agility", "vigor", "mind", "spirit", "presence", "faith"},
    },
    {
        id = "critical_hit",
        term = "Critical Hit",
        definition = "A devastating strike that deals 150-200% normal damage, indicated by special visual effects and sound cues. Critical chance scales primarily with Agility and certain weapon enchantments.",
        category = "combat",
        seeAlso = {"agility", "combo", "enchanting"},
    },
    {
        id = "dodge",
        term = "Dodge",
        definition = "Successful evasion of an incoming attack, completely negating damage. Base dodge chance is determined by Agility, with bonuses from equipment and buff effects.",
        category = "combat",
        seeAlso = {"agility", "critical_hit"},
    },
    {
        id = "combo",
        term = "Combo",
        definition = "Chain of successful attacks or actions that multiply damage and rewards. Breaking combo typically occurs when taking damage, missing, or waiting too long between actions.",
        category = "combat",
        seeAlso = {"critical_hit", "combo_counter"},
    },
    {
        id = "talent",
        term = "Talent",
        definition = "Specialized ability unlocked through the Skill Tree system, providing passive bonuses or active powers. Talents define your character build and playstyle across combat, crafting, and commerce.",
        category = "combat",
        seeAlso = {"skill_tree", "level_up"},
    },
    {
        id = "skill_tree",
        term = "Skill Tree",
        definition = "Branching progression system where players spend points earned from leveling to unlock Talents. Multiple skill trees exist for different playstyles: warrior, mage, merchant, crafter, and explorer paths.",
        category = "combat",
        seeAlso = {"talent", "level_up", "xp"},
    },

    -- FISHING (10 terms)
    {
        id = "tension",
        term = "Tension",
        definition = "Fishing line stress meter that rises when reeling against strong fish. If Tension reaches maximum, the line snaps and the fish escapes. Manage Tension by releasing the reel at critical moments.",
        category = "fishing",
        seeAlso = {"direction_matching", "fish_stamina"},
    },
    {
        id = "direction_matching",
        term = "Direction Matching",
        definition = "Fishing mechanic requiring players to reel in the opposite direction of a fleeing fish. Correct directional input reduces Fish Stamina faster while incorrect direction increases Tension.",
        category = "fishing",
        seeAlso = {"tension", "fish_stamina", "perfect_reel"},
    },
    {
        id = "perfect_reel",
        term = "Perfect Reel Window",
        definition = "Brief timing window during fishing where proper input yields bonus progress and reduced Tension. Hitting Perfect Reels consistently is key to landing Trophy Fish and rare catches.",
        category = "fishing",
        seeAlso = {"tension", "direction_matching", "trophy_fish"},
    },
    {
        id = "fish_stamina",
        term = "Fish Stamina",
        definition = "Energy meter representing how much fight remains in a hooked fish. Deplete Fish Stamina to zero through successful reeling and direction matching to secure your catch.",
        category = "fishing",
        seeAlso = {"tension", "direction_matching", "trophy_fish"},
    },
    {
        id = "cast_power",
        term = "Cast Power",
        definition = "Distance and accuracy of your fishing line cast, determined by holding and releasing the cast button. Greater Cast Power reaches deeper waters where rarer fish spawn, but requires better timing control.",
        category = "fishing",
        seeAlso = {"depth", "rod_tier", "bait"},
    },
    {
        id = "trophy_fish",
        term = "Trophy Fish",
        definition = "Exceptionally rare and large fish variants with approximately 5% spawn chance in appropriate waters. Trophy Fish sell for premium prices, grant bonus XP, and can be mounted as tavern decorations.",
        category = "fishing",
        seeAlso = {"fish_stamina", "perfect_reel", "rarity_tiers"},
    },
    {
        id = "depth",
        term = "Depth",
        definition = "Water depth level determining which fish species spawn. Shallow waters contain common fish, while deep ocean trenches hide legendary catches. Depth is controlled by Cast Power and fishing location.",
        category = "fishing",
        seeAlso = {"cast_power", "trophy_fish", "bait"},
    },
    {
        id = "bait",
        term = "Bait",
        definition = "Consumable lure attached to fishing hooks that attracts specific fish types and increases catch rates. Premium baits like Glowworms and Enchanted Corn dramatically improve rare fish spawn chances.",
        category = "fishing",
        seeAlso = {"depth", "trophy_fish", "rod_tier"},
    },
    {
        id = "rod_tier",
        term = "Rod Tier",
        definition = "Quality classification of fishing rods from Basic (Tier 1) to Legendary (Tier 5). Higher tier rods increase Cast Power, reduce Tension buildup, and unlock access to advanced fishing zones.",
        category = "fishing",
        seeAlso = {"cast_power", "tension", "quality_tiers"},
    },
    {
        id = "combo_counter",
        term = "Combo Counter",
        definition = "Consecutive successful catches or Perfect Reels that multiply fishing XP and loot quality. Missing a catch or breaking your line resets the Combo Counter to zero.",
        category = "fishing",
        seeAlso = {"combo", "perfect_reel", "xp"},
    },

    -- CRAFTING (8 terms)
    {
        id = "masterwork",
        term = "Masterwork",
        definition = "Highest quality tier for crafted items, achieved through perfect execution of crafting minigames. Masterwork items have superior stats, bonus enchantment slots, and significantly higher market value.",
        category = "crafting",
        seeAlso = {"quality_tiers", "enchanting", "forge"},
    },
    {
        id = "quality_tiers",
        term = "Quality Tiers",
        definition = "Crafted item grades: Poor, Standard, Fine, Superior, and Masterwork. Quality affects item stats, durability, sell price, and enchantment potential, determined by crafting performance.",
        category = "crafting",
        seeAlso = {"masterwork", "recipe", "materials"},
    },
    {
        id = "bellows",
        term = "Bellows & Heat",
        definition = "Forge temperature management system where players pump bellows to maintain optimal heat levels. Too cold and metal won't shape properly; too hot and materials burn, reducing quality.",
        category = "crafting",
        seeAlso = {"forge", "masterwork", "recipe"},
    },
    {
        id = "recipe",
        term = "Recipe",
        definition = "Blueprint required to craft items, found through exploration, purchased from merchants, or unlocked via the Knowledge Center. Recipes specify required materials, tools, and crafting station type.",
        category = "crafting",
        seeAlso = {"materials", "knowledge_center", "quality_tiers"},
    },
    {
        id = "materials",
        term = "Materials",
        definition = "Raw resources gathered from fishing, hunting, mining, and foraging used in crafting recipes. Material rarity directly impacts the potential quality and power of crafted items.",
        category = "crafting",
        seeAlso = {"recipe", "quality_tiers", "rarity_tiers"},
    },
    {
        id = "forge",
        term = "Forge",
        definition = "Blacksmithing station for crafting weapons, armor, and metal tools. Forge gameplay involves heating metal with Bellows, hammering at proper timing, and quenching to lock in quality.",
        category = "crafting",
        seeAlso = {"bellows", "masterwork", "recipe"},
    },
    {
        id = "alchemy_phases",
        term = "Alchemy Phases",
        definition = "Three-stage potion brewing process: Preparation (ingredient selection), Infusion (heat and timing control), and Distillation (purity refinement). Each phase affects final potion potency and side effects.",
        category = "crafting",
        seeAlso = {"mind", "recipe", "materials"},
    },
    {
        id = "enchanting",
        term = "Enchanting",
        definition = "Magical enhancement process that imbues equipment with special properties like elemental damage, stat boosts, or unique effects. Enchanting requires spell components and a wizard tower.",
        category = "crafting",
        seeAlso = {"masterwork", "spell_card", "materials"},
    },

    -- ECONOMY (8 terms)
    {
        id = "passive_income",
        term = "Passive Income",
        definition = "Automatic revenue generated by your tavern, market investments, and employed workers while you adventure. Upgrading facilities and hiring skilled employees increases passive income rates.",
        category = "economy",
        seeAlso = {"employees", "investment", "dividend"},
    },
    {
        id = "employees",
        term = "Employees",
        definition = "Hired NPCs who manage tavern operations, serve customers, and generate passive income. Employee effectiveness scales with their skills, happiness, and your Presence stat.",
        category = "economy",
        seeAlso = {"passive_income", "presence", "reputation"},
    },
    {
        id = "market_listing",
        term = "Market Listing",
        definition = "Player-created auction house posting where crafted items, fish, materials, and cards can be sold to other players or NPCs. Listing fees apply, but successful sales earn significantly more than vendor prices.",
        category = "economy",
        seeAlso = {"coins", "investment", "portfolio"},
    },
    {
        id = "coins",
        term = "Coins",
        definition = "Primary currency earned through completing quests, selling items, serving tavern customers, and market trading. Coins purchase materials, recipes, equipment, and tavern upgrades.",
        category = "economy",
        seeAlso = {"crystals", "market_listing", "passive_income"},
    },
    {
        id = "crystals",
        term = "Crystals",
        definition = "Premium currency obtained from achievements, daily bonuses, and rare loot. Crystals unlock exclusive cosmetics, accelerate timers, purchase premium card packs, and expand storage capacity.",
        category = "economy",
        seeAlso = {"coins", "card_pack", "loot_box"},
    },
    {
        id = "investment",
        term = "Investment",
        definition = "Stock market purchase of shares in merchant guilds, trading companies, and kingdom enterprises. Investments generate dividend payouts and can be sold when share prices rise.",
        category = "economy",
        seeAlso = {"dividend", "portfolio", "passive_income"},
    },
    {
        id = "dividend",
        term = "Dividend",
        definition = "Periodic payment received from investment holdings, typically distributed weekly based on company performance. Diversified portfolios with high-performing stocks yield substantial passive income.",
        category = "economy",
        seeAlso = {"investment", "portfolio", "passive_income"},
    },
    {
        id = "portfolio",
        term = "Portfolio",
        definition = "Collection of all your active investments and their current market values. Smart portfolio management through buying low and selling high is essential for economic mastery.",
        category = "economy",
        seeAlso = {"investment", "dividend", "market_listing"},
    },

    -- EXPLORATION & GENERAL (10 terms)
    {
        id = "rarity_tiers",
        term = "Rarity Tiers",
        definition = "Item classification system in ascending order: Common (white), Uncommon (green), Rare (blue), Epic (purple), Legendary (orange), and Mythic (red). Rarity determines power, value, and drop chance.",
        category = "general",
        seeAlso = {"trophy_fish", "loot_box", "materials"},
    },
    {
        id = "xp",
        term = "XP (Experience Points)",
        definition = "Progression currency earned from combat, crafting, fishing, quests, and tavern management. Accumulating XP leads to Level Ups, which grant skill points for Talent tree advancement.",
        category = "general",
        seeAlso = {"level_up", "talent", "skill_tree"},
    },
    {
        id = "level_up",
        term = "Level Up",
        definition = "Character advancement achieved by earning sufficient XP. Each Level Up increases base stats, grants skill points for Talent trees, and unlocks access to new content zones and recipes.",
        category = "general",
        seeAlso = {"xp", "talent", "skill_tree"},
    },
    {
        id = "backpack",
        term = "Backpack",
        definition = "Inventory storage system with limited slots for carrying items, materials, and equipment. Backpack capacity can be expanded through upgrades purchased with Coins or Crystals.",
        category = "general",
        seeAlso = {"coins", "crystals", "materials"},
    },
    {
        id = "knowledge_center",
        term = "Knowledge Center",
        definition = "In-game encyclopedia and tutorial hub containing monster information, recipe databases, lore entries, and gameplay guides. The Knowledge Center fills automatically as you discover new content.",
        category = "general",
        seeAlso = {"recipe", "lore_entry", "quest"},
    },
    {
        id = "reputation",
        term = "Reputation",
        definition = "Standing with various factions, towns, and guilds earned through quests and interactions. High Reputation unlocks exclusive shops, special quests, faction-specific recipes, and price discounts.",
        category = "general",
        seeAlso = {"quest", "presence", "employees"},
    },
    {
        id = "quest",
        term = "Quest",
        definition = "Story-driven or procedural task offering XP, Coins, items, and Reputation rewards. Quests range from simple delivery missions to multi-stage adventures with branching outcomes.",
        category = "general",
        seeAlso = {"xp", "reputation", "dungeon"},
    },
    {
        id = "dungeon",
        term = "Dungeon",
        definition = "Instanced adventure location filled with monsters, traps, puzzles, and treasure. Dungeons culminate in Boss encounters and offer the best loot in their respective level ranges.",
        category = "exploration",
        seeAlso = {"boss", "quest", "loot_box"},
    },
    {
        id = "boss",
        term = "Boss",
        definition = "Powerful elite enemy encountered at dungeon conclusions and major quest milestones. Bosses have unique mechanics, high health pools, and drop Epic or Legendary quality rewards.",
        category = "exploration",
        seeAlso = {"dungeon", "rarity_tiers", "combo"},
    },
    {
        id = "loot_box",
        term = "Loot Box",
        definition = "Randomized reward container obtained from quests, dungeons, and daily login bonuses. Loot Boxes contain tiered rewards including crafting materials, equipment, card packs, and currency.",
        category = "general",
        seeAlso = {"rarity_tiers", "card_pack", "crystals"},
    },

    -- PETS (8 terms)
    {
        id = "evolution",
        term = "Evolution",
        definition = "Pet advancement system where creatures transform into stronger forms after reaching level thresholds. Evolution changes appearance, stats, abilities, and sometimes elemental type.",
        category = "pets",
        seeAlso = {"elemental_type", "training", "wild_creatures"},
    },
    {
        id = "elemental_type",
        term = "Elemental Type",
        definition = "Pet classification (Fire, Water, Earth, Air, Lightning, Nature, Shadow, Holy) that determines strengths, weaknesses, and special abilities. Type advantages grant 50% bonus damage in combat.",
        category = "pets",
        seeAlso = {"evolution", "breeding", "wild_creatures"},
    },
    {
        id = "breeding",
        term = "Breeding",
        definition = "System for combining two compatible pets to produce eggs with inherited traits, stats, and abilities. Careful breeding selection can produce superior offspring with rare color variations.",
        category = "pets",
        seeAlso = {"elemental_type", "evolution", "happiness"},
    },
    {
        id = "mount",
        term = "Mount",
        definition = "Rideable pet that increases overworld movement speed and grants travel abilities like water-walking or flight. Mounts are unlocked by evolving certain pet species to their final forms.",
        category = "pets",
        seeAlso = {"evolution", "wild_creatures", "adoption"},
    },
    {
        id = "happiness",
        term = "Happiness",
        definition = "Pet mood stat affected by feeding, playing, and training frequency. Happy pets gain XP faster, perform better in combat, and are more likely to produce quality offspring when breeding.",
        category = "pets",
        seeAlso = {"breeding", "training", "evolution"},
    },
    {
        id = "training",
        term = "Training",
        definition = "Daily pet activity that increases stats, teaches new abilities, and builds Happiness. Training minigames vary by pet type and include agility courses, combat sparring, and trick learning.",
        category = "pets",
        seeAlso = {"happiness", "evolution", "wild_creatures"},
    },
    {
        id = "adoption",
        term = "Adoption",
        definition = "Acquiring pre-raised pets from shelters or other players instead of catching Wild Creatures. Adopted pets come with randomized levels, stats, and personalities at reduced costs.",
        category = "pets",
        seeAlso = {"wild_creatures", "breeding", "happiness"},
    },
    {
        id = "wild_creatures",
        term = "Wild Creatures",
        definition = "Untamed pets found throughout exploration zones that can be captured during combat encounters. Wild Creatures have random stats and abilities, with rarer variants spawning in dangerous areas.",
        category = "pets",
        seeAlso = {"adoption", "elemental_type", "evolution"},
    },

    -- CARDS (8 terms)
    {
        id = "deck",
        term = "Deck",
        definition = "Player-constructed set of 30-40 cards used in deck-building card battles. Effective decks balance Creature Cards, Spell Cards, and synergistic effects around a cohesive strategy.",
        category = "cards",
        seeAlso = {"creature_card", "spell_card", "synergy"},
    },
    {
        id = "card_pack",
        term = "Card Pack",
        definition = "Randomized bundle of 5-10 trading cards purchased with Coins or Crystals. Packs guarantee at least one Rare+ card, with premium packs offering better odds for Epic and Legendary pulls.",
        category = "cards",
        seeAlso = {"crystals", "card_rarity", "foil", "collection_set"},
    },
    {
        id = "foil",
        term = "Foil/Holographic",
        definition = "Special visual variant of trading cards featuring shimmering, animated artwork. Foil cards are purely cosmetic but highly collectible, appearing in roughly 1 in 20 pack openings.",
        category = "cards",
        seeAlso = {"card_pack", "card_rarity", "collection_set"},
    },
    {
        id = "collection_set",
        term = "Collection Set",
        definition = "Themed group of related cards sharing artwork, lore, or mechanical synergies. Completing entire Collection Sets unlocks bonus rewards, exclusive card backs, and achievement titles.",
        category = "cards",
        seeAlso = {"card_pack", "foil", "synergy"},
    },
    {
        id = "creature_card",
        term = "Creature Card",
        definition = "Summonable unit card with attack, defense, and health values used to control the battlefield. Creature Cards form the foundation of most deck strategies and can have special abilities or tribal synergies.",
        category = "cards",
        seeAlso = {"deck", "spell_card", "synergy"},
    },
    {
        id = "spell_card",
        term = "Spell Card",
        definition = "Instant or ongoing effect card that manipulates combat, buffs creatures, or disrupts opponents. Spell Cards provide tactical flexibility and combo potential when paired with creature strategies.",
        category = "cards",
        seeAlso = {"creature_card", "deck", "synergy"},
    },
    {
        id = "synergy",
        term = "Synergy",
        definition = "Powerful interaction between cards that share types, keywords, or mechanical themes. Building decks around synergistic combos creates exponentially stronger strategies than individual card value.",
        category = "cards",
        seeAlso = {"deck", "creature_card", "spell_card"},
    },
    {
        id = "card_rarity",
        term = "Card Rarity",
        definition = "Trading card quality following standard Rarity Tiers: Common, Uncommon, Rare, Epic, Legendary, and Mythic. Higher rarity cards have more powerful effects but appear less frequently in packs.",
        category = "cards",
        seeAlso = {"rarity_tiers", "card_pack", "foil"},
    },

    -- LORE (6 terms)
    {
        id = "heavens_atlas",
        term = "Heaven's Atlas",
        definition = "Ancient magical empire that controlled the known world before its catastrophic collapse triggered the Age of War. Heaven's Atlas ruins still dot the landscape, filled with dangerous magic and lost treasures.",
        category = "lore",
        seeAlso = {"age_after_war", "the_frontier", "lore_entry"},
    },
    {
        id = "age_after_war",
        term = "Age After War",
        definition = "Current historical era following the devastating wars that destroyed Heaven's Atlas and fractured civilization. The Age After War is characterized by slow rebuilding, frontier expansion, and rediscovery of lost knowledge.",
        category = "lore",
        seeAlso = {"heavens_atlas", "the_kingdom", "the_frontier"},
    },
    {
        id = "the_frontier",
        term = "The Frontier",
        definition = "Untamed wilderness territories beyond kingdom borders where adventure, danger, and opportunity await. The Frontier contains unexplored dungeons, wild creatures, and remnants of the old world.",
        category = "lore",
        seeAlso = {"age_after_war", "wild_creatures", "dungeon"},
    },
    {
        id = "tavern_times",
        term = "Tavern Times",
        definition = "Popular broadsheet newspaper distributed throughout settlements, featuring quest postings, market reports, gossip columns, and advertisements. Reading Tavern Times unlocks side quests and investment opportunities.",
        category = "lore",
        seeAlso = {"quest", "the_kingdom", "lore_entry"},
    },
    {
        id = "the_kingdom",
        term = "The Kingdom",
        definition = "Primary civilized nation-state governing most settled territories in the Age After War. The Kingdom maintains order through military patrols, trade regulation, and adventurer guilds.",
        category = "lore",
        seeAlso = {"luminary_patrols", "age_after_war", "reputation"},
    },
    {
        id = "luminary_patrols",
        term = "Luminary Patrols",
        definition = "Elite Kingdom military units that guard roads, clear dungeons of monsters, and protect settlements from frontier threats. Assisting Luminary Patrols builds Kingdom reputation and unlocks military-grade equipment.",
        category = "lore",
        seeAlso = {"the_kingdom", "reputation", "quest"},
    },
    {
        id = "lore_entry",
        term = "Lore Entry",
        definition = "Collectible piece of world history, character backstory, or cultural information discovered through exploration and quests. Lore Entries are archived in the Knowledge Center and reveal the deeper Tavern Quest narrative.",
        category = "lore",
        seeAlso = {"knowledge_center", "heavens_atlas", "tavern_times"},
    },
}

-- Helper function to get a term by its ID
function Glossary.getTerm(id)
    for _, term in ipairs(Glossary.terms) do
        if term.id == id then
            return term
        end
    end
    return nil
end

-- Get all terms for a specific category
function Glossary.getTermsByCategory(category)
    local results = {}
    for _, term in ipairs(Glossary.terms) do
        if term.category == category then
            table.insert(results, term)
        end
    end
    return results
end

-- Get all unique categories
function Glossary.getCategories()
    local categories = {}
    local seen = {}
    for _, term in ipairs(Glossary.terms) do
        if not seen[term.category] then
            table.insert(categories, term.category)
            seen[term.category] = true
        end
    end
    table.sort(categories)
    return categories
end

-- Search terms by query string (case-insensitive, partial matching on term and definition)
function Glossary.search(query)
    if not query or query == "" then
        return {}
    end

    local lowerQuery = string.lower(query)
    local results = {}

    for _, term in ipairs(Glossary.terms) do
        local lowerTerm = string.lower(term.term)
        local lowerDef = string.lower(term.definition)

        -- Check if query matches term name or appears in definition
        if string.find(lowerTerm, lowerQuery, 1, true) or
           string.find(lowerDef, lowerQuery, 1, true) then
            table.insert(results, term)
        end
    end

    return results
end

-- Get a random term (useful for "tip of the day" features)
function Glossary.getRandomTerm()
    if #Glossary.terms == 0 then
        return nil
    end
    local randomIndex = math.random(1, #Glossary.terms)
    return Glossary.terms[randomIndex]
end

-- Get all terms with cross-references to a specific term ID
function Glossary.getRelatedTerms(termId)
    local relatedTerms = {}
    local term = Glossary.getTerm(termId)

    if term and term.seeAlso then
        for _, relatedId in ipairs(term.seeAlso) do
            local relatedTerm = Glossary.getTerm(relatedId)
            if relatedTerm then
                table.insert(relatedTerms, relatedTerm)
            end
        end
    end

    return relatedTerms
end

return Glossary
