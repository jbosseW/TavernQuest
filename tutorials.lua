-- Tutorials System - Reusable tutorial data for all game modes
-- Easy to update and expand tutorials for each mode

local Tutorials = {}

-- Font cache for performance
local FontCache = require("fontcache")
local function getFont(size)
    return FontCache.get(size)
end

-- Tutorial structure:
-- Each mode has a list of tutorial steps
-- Each step has: title, text, highlight (optional UI area), action (optional required action)
--
-- NEW interactive fields (all optional, backwards compatible):
--   stepType       - "info" (default), "action" (waits for player action), "freeform" (player explores)
--   spotlightQuery - string key passed to getUIRegion() for spotlight targeting
--   arrowDirection - "up", "down", "left", "right" (direction arrow points)
--   waitForAction  - action ID string that InteractiveTutorial.signalAction() listens for
--   kcLink         - Knowledge Center entry ID for "Learn More" button
--   panelSide      - "auto" (default), "top", "bottom", "left", "right"

Tutorials.data = {
    -- ==================== FISHING TUTORIAL ====================
    fishing = {
        id = "fishing",
        name = "Fishing Basics",
        steps = {
            {
                title = "Welcome to Fishing!",
                text = "Relax and catch fish to earn coins.\nDifferent locations have different fish!",
                highlight = nil,
                action = nil,
                -- Interactive fields
                stepType = "info",
                kcLink = "fishing_overview",
            },
            {
                title = "Casting Your Line",
                text = "Hold [SPACE] to charge your cast power.\nRelease to cast - longer charge = deeper cast!",
                highlight = "cast_meter",
                action = "cast",
                -- Interactive fields
                stepType = "action",
                spotlightQuery = "cast_meter",
                arrowDirection = "down",
                waitForAction = "cast",
                panelSide = "top",
            },
            {
                title = "Waiting for a Bite",
                text = "Watch your line and wait for a fish to bite.\nDeeper water has rarer (and more valuable) fish!",
                highlight = "depth_display",
                action = nil,
                -- Interactive fields
                stepType = "info",
                spotlightQuery = "depth_display",
                arrowDirection = "left",
            },
            {
                title = "Fish On!",
                text = "When a fish bites, watch for indicators!\nYou'll need to manage tension AND direction.",
                highlight = "tension_meter",
                action = "hook_fish",
                -- Interactive fields
                stepType = "info",
                spotlightQuery = "tension_meter",
                arrowDirection = "right",
                kcLink = "tension_system",
            },
            {
                title = "Direction Matching",
                text = "Fish pull LEFT or RIGHT as they fight!\nPress [←] or [→] arrows to match their direction.\nMatching reduces tension and tires the fish!",
                highlight = "direction_indicator",
                action = nil,
                -- Interactive fields
                stepType = "info",
                spotlightQuery = "direction_indicator",
                arrowDirection = "down",
                kcLink = "direction_matching",
            },
            {
                title = "Fish Stamina",
                text = "Watch the fish's stamina bar (cyan).\nDrain stamina by reeling and matching direction.\nLow stamina = easier to catch!",
                highlight = "stamina_bar",
                action = nil,
                -- Interactive fields
                stepType = "info",
                spotlightQuery = "stamina_bar",
                arrowDirection = "right",
                kcLink = "fish_stamina",
            },
            {
                title = "Perfect Reel Windows",
                text = "Watch for green 'SPACE NOW!' prompts!\nHit [SPACE] during the window for bonus damage.\nBuilds your combo counter!",
                highlight = "perfect_window",
                action = nil,
                -- Interactive fields
                stepType = "info",
                spotlightQuery = "perfect_window",
                arrowDirection = "down",
                kcLink = "perfect_windows",
            },
            {
                title = "Combo System",
                text = "Chain perfect reels to build combos!\nHigher combos deal more stamina damage.\nMissing a window resets your combo.",
                highlight = "combo_display",
                action = nil,
                -- Interactive fields
                stepType = "info",
                spotlightQuery = "combo_display",
                arrowDirection = "down",
                kcLink = "combo_system",
            },
            {
                title = "Managing Tension",
                text = "Don't let tension get too high or your line breaks!\nMatch fish direction to reduce tension.\nReel steadily - the fish will fight back.",
                highlight = "tension_meter",
                action = nil,
                -- Interactive fields
                stepType = "info",
                spotlightQuery = "tension_meter",
                arrowDirection = "right",
            },
            {
                title = "Fish Tiers & Trophies",
                text = "Fish come in tiers: Common to Mythic!\nRarer fish are worth more coins.\n5% chance for Trophy variants (2x value)!",
                highlight = nil,
                action = nil,
                -- Interactive fields
                stepType = "info",
                kcLink = "quality_tiers",
            },
            {
                title = "Bait & Equipment",
                text = "Press [TAB] to open the shop.\n• Better rods handle more tension\n• Better bait attracts rarer fish\n• Unlock new fishing locations!",
                highlight = "shop_button",
                action = nil,
                -- Interactive fields
                stepType = "info",
                spotlightQuery = "shop_button",
                arrowDirection = "up",
                kcLink = "fishing_gear",
            },
            {
                title = "Material Drops",
                text = "Fish drop crafting materials!\nScales, bones, fins, and rare items.\nUse them for alchemy and forging.",
                highlight = nil,
                action = nil,
                -- Interactive fields
                stepType = "info",
                kcLink = "materials_overview",
            },
            {
                title = "Employees & Upgrades",
                text = "Press [E] to hire fishing assistants.\nEmployees generate passive income!\nUpgrades improve your fishing efficiency.",
                highlight = nil,
                action = nil,
                -- Interactive fields
                stepType = "info",
                kcLink = "employee_system",
            },
            {
                title = "You're Ready!",
                text = "Good luck fishing!\n• Match direction to tire fish faster\n• Hit perfect windows for combos\n• Hunt for legendary Sea Dragons!",
                highlight = nil,
                action = nil,
                -- Interactive fields
                stepType = "info",
            },
        },
    },

    -- ==================== FORGE TUTORIAL ====================
    forge = {
        id = "forge",
        name = "Blacksmith Basics",
        steps = {
            {
                title = "Welcome to the Forge!",
                text = "Craft weapons, armor, and traps here.\nYou'll need materials and gold.",
                highlight = nil,
                action = nil,
                stepType = "info",
                kcLink = "forge_overview",
            },
            {
                title = "Selecting a Recipe",
                text = "Browse recipes on the left panel.\nGreen means you have the materials!",
                highlight = "recipe_list",
                action = nil,
                stepType = "info",
                spotlightQuery = "recipe_list",
                arrowDirection = "right",
            },
            {
                title = "Checking Materials",
                text = "The center panel shows what you need.\nGather materials from hunting, fishing, or buy them.",
                highlight = "recipe_details",
                action = nil,
                stepType = "info",
                spotlightQuery = "recipe_details",
                arrowDirection = "left",
                kcLink = "materials_overview",
            },
            {
                title = "Heating the Forge",
                text = "Press [SPACE] to pump the bellows.\nKeep the forge HOT (orange/red) while crafting!",
                highlight = "heat_meter",
                action = "pump_bellows",
                stepType = "action",
                spotlightQuery = "heat_meter",
                arrowDirection = "down",
                waitForAction = "pump_bellows",
            },
            {
                title = "Crafting Quality",
                text = "Higher heat = better quality items!\nMasterwork items have +25% stats.",
                highlight = "heat_meter",
                action = nil,
                stepType = "info",
                spotlightQuery = "heat_meter",
                kcLink = "crafting_quality",
            },
            {
                title = "Item Rarity",
                text = "Each craft has a chance for rare items.\nLegendary items have 3x stats!",
                highlight = nil,
                action = nil,
                stepType = "info",
                kcLink = "quality_tiers",
            },
            {
                title = "After Crafting",
                text = "Choose what to do with your item:\n- Sell Now for instant gold\n- Keep in your backpack\n- List on the Market",
                highlight = "output_options",
                action = nil,
                stepType = "info",
                spotlightQuery = "output_options",
                arrowDirection = "up",
            },
            {
                title = "Skill Levels",
                text = "Crafting earns XP and unlocks better recipes.\nKeep forging to become a master smith!",
                highlight = nil,
                action = nil,
                stepType = "info",
                kcLink = "xp_leveling",
            },
        },
    },

    -- ==================== WIZARD TOWER TUTORIAL ====================
    wizardtower = {
        id = "wizardtower",
        name = "Spell Crafting Basics",
        steps = {
            {
                title = "Welcome to the Wizard Tower!",
                text = "Create magical spells, scrolls, and tomes.\nYou'll need magical reagents.",
                highlight = nil,
                action = nil,
                stepType = "info",
            },
            {
                title = "Magical Materials",
                text = "Mana Crystals, Essences, and Scrolls are key.\nFind them while adventuring or buy them.",
                highlight = "materials_display",
                action = nil,
                stepType = "info",
                spotlightQuery = "materials_display",
                arrowDirection = "down",
            },
            {
                title = "Channeling Mana",
                text = "Press [SPACE] to channel magical energy.\nKeep the mana bar charged while inscribing!",
                highlight = "mana_meter",
                action = "channel_mana",
                stepType = "action",
                spotlightQuery = "mana_meter",
                arrowDirection = "down",
                waitForAction = "channel_mana",
            },
            {
                title = "Spell Types",
                text = "Attack spells deal damage.\nSupport spells heal or buff.\nTomes give permanent bonuses!",
                highlight = "recipe_list",
                action = nil,
                stepType = "info",
                spotlightQuery = "recipe_list",
                arrowDirection = "right",
            },
            {
                title = "Spell Quality",
                text = "High mana charge = better quality.\nMasterwork spells are much more powerful!",
                highlight = nil,
                action = nil,
                stepType = "info",
                kcLink = "crafting_quality",
            },
            {
                title = "Using Spells",
                text = "Crafted spells go to your backpack.\nUse them in the Tavern Quest adventure!",
                highlight = nil,
                action = nil,
                stepType = "info",
            },
        },
    },

    -- ==================== ALCHEMIST TUTORIAL ====================
    alchemist = {
        id = "alchemist",
        name = "Alchemy Basics",
        steps = {
            {
                title = "Welcome to the Alchemist Table!",
                text = "Brew potions and poisons through interactive crafting.\nEach brew has 4 phases you must complete!",
                highlight = nil,
                action = nil,
                stepType = "info",
                kcLink = "alchemy_overview",
            },
            {
                title = "Gathering Ingredients",
                text = "Herbs, Moonflowers, and Venom Sacs are common.\nPhoenix Feathers are extremely rare!",
                highlight = "materials_display",
                action = nil,
                stepType = "info",
                spotlightQuery = "materials_display",
                arrowDirection = "down",
                kcLink = "alchemy_ingredients",
            },
            {
                title = "Phase 1: Prep",
                text = "First, chop your ingredients!\nPress [SPACE] repeatedly to chop.\nFaster chopping = better quality start!",
                highlight = "prep_area",
                action = nil,
                stepType = "info",
                spotlightQuery = "prep_area",
                arrowDirection = "down",
            },
            {
                title = "Phase 2: Pour",
                text = "Hold [SPACE] to pour liquid into the cauldron.\nFill to 70-80% for PERFECT quality!\nPress [ENTER] when done pouring.",
                highlight = "pour_meter",
                action = nil,
                stepType = "info",
                spotlightQuery = "pour_meter",
                arrowDirection = "right",
            },
            {
                title = "Phase 3: Heat",
                text = "Hold [SPACE] to pump the bellows.\nKeep the heat in the GREEN zone (60-70)!\nMaintain ideal heat until progress completes.",
                highlight = "heat_meter",
                action = nil,
                stepType = "info",
                spotlightQuery = "heat_meter",
                arrowDirection = "down",
            },
            {
                title = "Phase 4: Distill",
                text = "Press [SPACE] repeatedly to turn the crank.\nKeep cranking until distillation is complete!\nFaster cranking = better final quality.",
                highlight = "crank_wheel",
                action = nil,
                stepType = "info",
                spotlightQuery = "crank_wheel",
                arrowDirection = "left",
            },
            {
                title = "Potions vs Poisons",
                text = "Potions heal and buff you in combat.\nPoisons can be applied to weapons for damage over time!",
                highlight = "recipe_list",
                action = nil,
                stepType = "info",
                spotlightQuery = "recipe_list",
                arrowDirection = "right",
            },
            {
                title = "Quality System",
                text = "Each phase affects final quality.\nPerfect in all phases = Masterwork potion!\nMasterwork items are 25% more effective.",
                highlight = nil,
                action = nil,
                stepType = "info",
                kcLink = "crafting_quality",
            },
            {
                title = "Employees & Upgrades",
                text = "Press [E] to hire alchemist assistants.\nEmployees generate passive income!\nUpgrades improve your brewing efficiency.",
                highlight = nil,
                action = nil,
                stepType = "info",
                kcLink = "employee_system",
            },
        },
    },

    -- ==================== MARKET TUTORIAL ====================
    market = {
        id = "market",
        name = "Market Basics",
        steps = {
            {
                title = "Welcome to the Market!",
                text = "Sell your crafted items here.\nItems sell automatically over time!",
                highlight = nil,
                action = nil,
            },
            {
                title = "Listing Items",
                text = "When crafting, choose 'List on Market'.\nYour items appear here for sale.",
                highlight = "listings_panel",
                action = nil,
            },
            {
                title = "Pricing",
                text = "Fair prices sell faster.\nOverpriced items may take a long time to sell.",
                highlight = nil,
                action = nil,
            },
            {
                title = "Removing Listings",
                text = "Click 'Remove' to take an item back.\nIt returns to your backpack.",
                highlight = "remove_button",
                action = nil,
            },
        },
    },

    -- ==================== HUNTING TUTORIAL ====================
    hunting = {
        id = "hunting",
        name = "Hunting Basics",
        steps = {
            {
                title = "Welcome to the Hunt!",
                text = "Track and hunt wild game for valuable materials.\nClick to shoot arrows at moving targets!",
                highlight = nil,
                action = nil,
                stepType = "info",
                kcLink = "hunting_overview",
            },
            {
                title = "Taking Your Shot",
                text = "Click anywhere to fire an arrow at that location.\nArrows have physics - account for distance!\nMake sure you have arrows in your inventory.",
                highlight = "crosshair",
                action = nil,
                stepType = "info",
                spotlightQuery = "crosshair",
                arrowDirection = "down",
            },
            {
                title = "Wind Effects",
                text = "Watch the wind indicator at the top!\nWind pushes your arrows off course.\nAdjust your aim to compensate.",
                highlight = "wind_display",
                action = nil,
                stepType = "info",
                spotlightQuery = "wind_display",
                arrowDirection = "down",
            },
            {
                title = "Noise & Stealth",
                text = "The noise meter shows how alert animals are.\nMissed shots increase noise!\nToo much noise and animals flee faster.",
                highlight = "noise_meter",
                action = nil,
                stepType = "info",
                spotlightQuery = "noise_meter",
                arrowDirection = "down",
            },
            {
                title = "Animal Difficulty",
                text = "Different animals have different difficulty.\nSmall game (rabbits, pheasants) are easier.\nLegendary creatures are extremely rare!",
                highlight = nil,
                action = nil,
                stepType = "info",
            },
            {
                title = "Hunting Regions",
                text = "Different regions have different animals.\nUnlock new regions as you level up!\nMountains and Tundra have the best prey.",
                highlight = "region_select",
                action = nil,
                stepType = "info",
                spotlightQuery = "region_select",
                arrowDirection = "left",
            },
            {
                title = "Loot & Materials",
                text = "Successful hunts drop meat, hides, and more.\nRare animals drop valuable materials!\nUse materials for crafting or sell them.",
                highlight = nil,
                action = nil,
                stepType = "info",
                kcLink = "materials_overview",
            },
            {
                title = "Trophy Hunting",
                text = "Some animals are trophy-worthy!\nTrophies are displayed and give bonuses.\nHunt legendary creatures for the best trophies.",
                highlight = nil,
                action = nil,
                stepType = "info",
                kcLink = "trophy_variants",
            },
            {
                title = "Shop & Supplies",
                text = "Press [S] to open the shop.\nBuy arrows and bait to attract animals.\nPress [E] for employees, [U] for upgrades.",
                highlight = "shop_button",
                action = nil,
                stepType = "info",
                spotlightQuery = "shop_button",
                arrowDirection = "up",
            },
        },
    },

    -- ==================== TEXTRPG TUTORIAL ====================
    textrpg = {
        id = "textrpg",
        name = "Tavern Quest Adventure",
        steps = {
            {
                title = "Welcome to Tavern Quest!",
                text = "Embark on a fantasy text adventure!\nExplore dungeons, fight monsters, and complete quests.",
                highlight = nil,
                action = nil,
                stepType = "info",
                kcLink = "textrpg_overview",
            },
            {
                title = "Character Classes",
                text = "Choose your class wisely:\n• Warrior - High HP, strong attacks\n• Mage - Powerful spells, low HP\n• Rogue - Fast, critical hits\n• Cleric - Healing and buffs",
                highlight = "class_select",
                action = nil,
                stepType = "info",
                spotlightQuery = "class_select",
                arrowDirection = "down",
            },
            {
                title = "Stats System",
                text = "Your character has 7 stats:\nMight (damage), Agility (crit/dodge), Vigor (HP)\nMind (spell power), Spirit (healing), Presence (prices), Faith (holy)",
                highlight = nil,
                action = nil,
                stepType = "info",
                kcLink = "combat_stats",
            },
            {
                title = "Combat Basics",
                text = "In combat, choose your actions:\n• Attack - Basic weapon strike\n• Skills - Special class abilities\n• Items - Use potions and scrolls\n• Flee - Attempt to escape",
                highlight = "combat_menu",
                action = nil,
                stepType = "info",
                spotlightQuery = "combat_menu",
                arrowDirection = "up",
            },
            {
                title = "Skills & Talents",
                text = "Earn skill points as you level up.\nUnlock powerful skills in your class tree!\nGain talents at levels 3, 6, 9, 12...",
                highlight = nil,
                action = nil,
                stepType = "info",
            },
            {
                title = "Equipment",
                text = "Find and equip weapons and armor.\nBetter gear improves your stats!\nSome equipment has class requirements.",
                highlight = "inventory",
                action = nil,
                stepType = "info",
                spotlightQuery = "inventory",
                arrowDirection = "right",
                kcLink = "equipment_overview",
            },
            {
                title = "Town & Shops",
                text = "Visit towns to:\n• Rest and heal at the inn\n• Buy supplies at shops\n• Accept quests from NPCs\n• Sell your loot",
                highlight = nil,
                action = nil,
                stepType = "info",
            },
            {
                title = "Dungeon Exploration",
                text = "Explore dangerous dungeons!\nFight enemies, find treasure, defeat bosses.\nDeeper floors have better rewards.",
                highlight = nil,
                action = nil,
                stepType = "info",
            },
            {
                title = "Death & Revival",
                text = "If you fall in battle:\n• You lose some gold\n• Return to last town\n• Keep your equipment\nBe careful in tough fights!",
                highlight = nil,
                action = nil,
                stepType = "info",
            },
        },
    },

    -- ==================== PET SIMULATOR TUTORIAL ====================
    petsim = {
        id = "petsim",
        name = "Wilds Rancher Basics",
        steps = {
            {
                title = "Welcome to Wilds Rancher!",
                text = "Adopt, breed, and train wild creatures!\nYour pets can become companions or mounts.",
                highlight = nil,
                action = nil,
                stepType = "info",
                kcLink = "petsim_overview",
            },
            {
                title = "Adopting Pets",
                text = "Visit the adoption center to get pets.\nEach species has unique traits!\nRarer pets cost more but are stronger.",
                highlight = "adoption_panel",
                action = nil,
                stepType = "info",
                spotlightQuery = "adoption_panel",
                arrowDirection = "right",
            },
            {
                title = "Pet Care",
                text = "Keep your pets happy and healthy!\n• Feed them when hungry\n• Play to increase happiness\n• Rest to restore energy",
                highlight = "pet_stats",
                action = nil,
                stepType = "info",
                spotlightQuery = "pet_stats",
                arrowDirection = "left",
            },
            {
                title = "Elements",
                text = "Pets have elemental types:\nFlame, Aqua, Terra, Volt, Shadow, Light...\nElements affect combat strengths!",
                highlight = nil,
                action = nil,
                stepType = "info",
                kcLink = "elemental_system",
            },
            {
                title = "Training",
                text = "Train your pets to increase stats.\nHigher stats = better battle performance!\nWell-trained pets evolve faster.",
                highlight = "training_area",
                action = nil,
                stepType = "info",
                spotlightQuery = "training_area",
                arrowDirection = "down",
            },
            {
                title = "Evolution",
                text = "Happy, healthy pets can evolve!\nEvolved pets are much stronger.\nSome evolutions unlock mount ability.",
                highlight = nil,
                action = nil,
                stepType = "info",
            },
            {
                title = "Mounts",
                text = "Evolved pets can become mounts!\n• Land mounts traverse normal terrain\n• Flying mounts are 4x faster!\nDragons and phoenixes can fly.",
                highlight = nil,
                action = nil,
                stepType = "info",
                kcLink = "mount_system",
            },
            {
                title = "Breeding",
                text = "Breed two compatible pets together.\nOffspring inherit traits from parents!\nRare combinations create unique pets.",
                highlight = nil,
                action = nil,
                stepType = "info",
            },
        },
    },

    -- ==================== CAFE GAME TUTORIAL ====================
    cafegame = {
        id = "cafegame",
        name = "Tavern Work Basics",
        steps = {
            {
                title = "Welcome to the Tavern!",
                text = "Work at the local tavern serving adventurers!\nTake orders, prepare food, and earn tips.",
                highlight = nil,
                action = nil,
                stepType = "info",
                kcLink = "cafegame_overview",
            },
            {
                title = "Taking Orders",
                text = "Customers arrive and show what they want.\nClick on a customer to see their order.\nWatch their patience meter!",
                highlight = "customer_area",
                action = nil,
                stepType = "info",
                spotlightQuery = "customer_area",
                arrowDirection = "down",
            },
            {
                title = "Preparing Food",
                text = "Click on menu items to prepare them.\nDifferent items take different times.\nYou can prepare multiple items at once!",
                highlight = "menu_panel",
                action = nil,
                stepType = "info",
                spotlightQuery = "menu_panel",
                arrowDirection = "left",
            },
            {
                title = "Serving Customers",
                text = "When food is ready, it goes on your tray.\nClick a customer to serve their order.\nFast service = better tips!",
                highlight = "tray_area",
                action = nil,
                stepType = "info",
                spotlightQuery = "tray_area",
                arrowDirection = "up",
            },
            {
                title = "Customer Patience",
                text = "Different customer types have different patience:\n• Nobles are impatient but tip well\n• Dwarves wait longer but tip less\nDon't let customers leave angry!",
                highlight = nil,
                action = nil,
                stepType = "info",
            },
            {
                title = "Day Cycle",
                text = "Each day is a work shift.\nServe as many customers as possible!\nEnd of day shows your earnings summary.",
                highlight = "time_display",
                action = nil,
                stepType = "info",
                spotlightQuery = "time_display",
                arrowDirection = "down",
            },
            {
                title = "Upgrades",
                text = "Spend earnings on upgrades:\n• Bigger tray capacity\n• Faster preparation\n• Auto-chef helper\n• Better tips & patience",
                highlight = nil,
                action = nil,
                stepType = "info",
            },
        },
    },


    -- ==================== STOCK MARKET TUTORIAL ====================
    stockmarket = {
        id = "stockmarket",
        name = "Trading Basics",
        steps = {
            {
                title = "Welcome to the Exchange!",
                text = "Buy and sell stocks to make profit!\nPrices change based on market conditions.",
                highlight = nil,
                action = nil,
                stepType = "info",
                kcLink = "stockmarket_overview",
            },
            {
                title = "Reading Stock Prices",
                text = "Each stock shows:\n• Current price\n• Price change (up green, down red)\n• Historical chart\nBuy low, sell high!",
                highlight = "stock_list",
                action = nil,
                stepType = "info",
                spotlightQuery = "stock_list",
                arrowDirection = "right",
            },
            {
                title = "Buying Stocks",
                text = "Click a stock to select it.\nEnter quantity and click BUY.\nStocks are added to your portfolio.",
                highlight = "buy_panel",
                action = nil,
                stepType = "info",
                spotlightQuery = "buy_panel",
                arrowDirection = "left",
            },
            {
                title = "Selling Stocks",
                text = "Select owned stocks to sell.\nSell when price is higher than you paid!\nProfit = (sell price - buy price) x quantity",
                highlight = "portfolio",
                action = nil,
                stepType = "info",
                spotlightQuery = "portfolio",
                arrowDirection = "right",
            },
            {
                title = "Market Events",
                text = "Random events affect stock prices:\n• Company news\n• Economic changes\n• Industry trends\nWatch for opportunities!",
                highlight = nil,
                action = nil,
                stepType = "info",
            },
            {
                title = "Trading Strategy",
                text = "Tips for success:\n• Diversify your portfolio\n• Don't panic sell on dips\n• Watch for market patterns\n• Buy rumors, sell news!",
                highlight = nil,
                action = nil,
                stepType = "info",
            },
        },
    },

    -- ==================== TRADING CARDS TUTORIAL ====================
    tradingcards = {
        id = "tradingcards",
        name = "Card Collecting Basics",
        steps = {
            {
                title = "Welcome to Card Collecting!",
                text = "Collect trading cards of creatures and heroes!\nBuild your collection and trade with others.",
                highlight = nil,
                action = nil,
            },
            {
                title = "Getting Cards",
                text = "Obtain cards by:\n• Opening card packs\n• Rewards from activities\n• Trading with NPCs\nRarer cards are harder to find!",
                highlight = nil,
                action = nil,
            },
            {
                title = "Card Rarities",
                text = "Cards come in rarities:\n• Common (gray)\n• Uncommon (green)\n• Rare (blue)\n• Epic (purple)\n• Legendary (gold)",
                highlight = nil,
                action = nil,
            },
            {
                title = "Your Collection",
                text = "View all your cards in the collection.\nSee which cards you're missing.\nComplete sets for bonuses!",
                highlight = "collection_grid",
                action = nil,
            },
            {
                title = "Card Values",
                text = "Rarer cards are worth more gold.\nFoil/holographic variants are special!\nSome cards are limited edition.",
                highlight = nil,
                action = nil,
            },
            {
                title = "Trading",
                text = "Trade duplicate cards with NPCs.\nOffer cards to receive different ones.\nLook for good deals!",
                highlight = nil,
                action = nil,
            },
        },
    },

    -- ==================== DECK BUILDER TUTORIAL ====================
    deckbuilder = {
        id = "deckbuilder",
        name = "Deck Building Basics",
        steps = {
            {
                title = "Welcome to Deck Building!",
                text = "Construct powerful decks for card battles!\nCombine cards strategically to win.",
                highlight = nil,
                action = nil,
            },
            {
                title = "Deck Rules",
                text = "Decks must follow rules:\n• Minimum/maximum card count\n• Limited copies per card\n• May have theme restrictions",
                highlight = "deck_info",
                action = nil,
            },
            {
                title = "Card Types",
                text = "Different card types:\n• Creatures - fight for you\n• Spells - one-time effects\n• Items - equipment/buffs\nBalance your deck!",
                highlight = nil,
                action = nil,
            },
            {
                title = "Building Strategy",
                text = "Good decks have:\n• Clear win condition\n• Card synergies\n• Resource balance\n• Answer to threats",
                highlight = nil,
                action = nil,
            },
            {
                title = "Adding Cards",
                text = "Click cards to add to deck.\nDrag to remove cards.\nWatch your deck's card count!",
                highlight = "card_pool",
                action = nil,
            },
            {
                title = "Saving Decks",
                text = "Save your deck when finished.\nYou can have multiple saved decks.\nSwitch decks before battles!",
                highlight = "save_button",
                action = nil,
            },
        },
    },

    -- ==================== LOOT BOX TUTORIAL ====================
    lootbox = {
        id = "lootbox",
        name = "Loot Box Basics",
        steps = {
            {
                title = "Welcome to Loot Boxes!",
                text = "Open boxes to discover rare items!\nEvery box contains random rewards.",
                highlight = nil,
                action = nil,
            },
            {
                title = "Box Types",
                text = "Different boxes have different contents:\n• Common boxes - basic items\n• Rare boxes - better odds\n• Premium boxes - guaranteed rares",
                highlight = "box_selection",
                action = nil,
            },
            {
                title = "Opening Boxes",
                text = "Click a box to open it.\nWatch the opening animation!\nYour rewards are revealed one by one.",
                highlight = "open_button",
                action = nil,
            },
            {
                title = "Rarity Chances",
                text = "Each item has a drop chance:\n• Common - very likely\n• Rare - less common\n• Legendary - extremely rare\nLuck plays a role!",
                highlight = nil,
                action = nil,
            },
            {
                title = "Rewards",
                text = "Rewards go to your inventory.\nYou might get:\n• Equipment\n• Cards\n• Materials\n• Cosmetics",
                highlight = nil,
                action = nil,
            },
            {
                title = "Earning Boxes",
                text = "Get boxes from:\n• Completing quests\n• Daily rewards\n• Special events\n• Purchasing with gold",
                highlight = nil,
                action = nil,
            },
        },
    },

    -- ==================== LUMINARY PATROLS TUTORIAL ====================
    luminarypatrols = {
        id = "luminarypatrols",
        name = "Patrol Basics",
        steps = {
            {
                title = "Welcome to Luminary Patrols!",
                text = "Join the city watch on patrol duty.\nProtect citizens and earn rewards!",
                highlight = nil,
                action = nil,
            },
            {
                title = "Choosing Patrol Routes",
                text = "Different districts have different dangers:\n• Market - pickpockets, thieves\n• Docks - smugglers, pirates\n• Slums - gangs, assassins",
                highlight = "route_select",
                action = nil,
            },
            {
                title = "Encounters",
                text = "While patrolling you may encounter:\n• Criminals to arrest\n• Citizens to help\n• Suspicious activity\n• Random events",
                highlight = nil,
                action = nil,
            },
            {
                title = "Combat",
                text = "Some encounters lead to combat!\nUse your patrol gear and abilities.\nCall for backup if overwhelmed.",
                highlight = nil,
                action = nil,
            },
            {
                title = "Patrol Rewards",
                text = "Successful patrols earn:\n• Gold bounties\n• Reputation points\n• Confiscated goods\n• Patrol experience",
                highlight = nil,
                action = nil,
            },
            {
                title = "Rank & Upgrades",
                text = "Gain experience to rank up!\nHigher ranks unlock:\n• Better patrol routes\n• Superior equipment\n• Special abilities",
                highlight = nil,
                action = nil,
            },
        },
    },

    -- ==================== STORY MODE TUTORIAL ====================
    storymode = {
        id = "storymode",
        name = "Story Mode Basics",
        steps = {
            {
                title = "Welcome to Story Mode!",
                text = "Experience the main narrative of Tavern Quest!\nYour choices shape the story.",
                highlight = nil,
                action = nil,
            },
            {
                title = "Chapter Structure",
                text = "The story is divided into chapters.\nEach chapter has unique locations and challenges.\nComplete objectives to progress!",
                highlight = nil,
                action = nil,
            },
            {
                title = "Choices Matter",
                text = "Make important decisions throughout.\nYour choices affect:\n• Story outcomes\n• Character relationships\n• Available rewards",
                highlight = nil,
                action = nil,
            },
            {
                title = "Character Relationships",
                text = "Build bonds with NPCs you meet.\nHelp them and earn their loyalty.\nAllies may aid you later!",
                highlight = nil,
                action = nil,
            },
            {
                title = "Story Rewards",
                text = "Story completion rewards:\n• Unique equipment\n• Exclusive abilities\n• Lore unlocks\n• Achievement points",
                highlight = nil,
                action = nil,
            },
            {
                title = "Replaying Chapters",
                text = "Completed chapters can be replayed!\nTry different choices for new outcomes.\nSome rewards are choice-dependent.",
                highlight = nil,
                action = nil,
            },
        },
    },

    -- ==================== ENDLESS MODE TUTORIAL ====================
    endlessmode = {
        id = "endlessmode",
        name = "Endless Mode Basics",
        steps = {
            {
                title = "Welcome to Endless Mode!",
                text = "Survive as long as possible!\nWaves of enemies never stop coming.",
                highlight = nil,
                action = nil,
            },
            {
                title = "Wave System",
                text = "Enemies attack in waves.\nEach wave is harder than the last.\nBreak between waves to prepare!",
                highlight = "wave_counter",
                action = nil,
            },
            {
                title = "Scoring",
                text = "Earn points for:\n• Defeating enemies\n• Surviving waves\n• Speed bonuses\n• Combo kills",
                highlight = "score_display",
                action = nil,
            },
            {
                title = "Power-Ups",
                text = "Collect power-ups during waves:\n• Health restore\n• Damage boost\n• Speed increase\n• Special abilities",
                highlight = nil,
                action = nil,
            },
            {
                title = "Scaling Difficulty",
                text = "Enemies get stronger each wave:\n• More health\n• Higher damage\n• New abilities\n• Boss waves every 5 waves",
                highlight = nil,
                action = nil,
            },
            {
                title = "Leaderboards",
                text = "Compare your high scores!\nCompete for the top spot.\nHow many waves can you survive?",
                highlight = nil,
                action = nil,
            },
        },
    },
}

-- Track which tutorials have been completed
-- Stored in PlayerData.completedTutorials = {fishing = true, forge = true, ...}

function Tutorials.hasCompleted(modeId)
    if not PlayerData.completedTutorials then
        return false
    end
    return PlayerData.completedTutorials[modeId] == true
end

function Tutorials.markCompleted(modeId)
    if not PlayerData.completedTutorials then
        PlayerData.completedTutorials = {}
    end
    PlayerData.completedTutorials[modeId] = true
    savePlayerData()
end

function Tutorials.resetTutorial(modeId)
    if PlayerData.completedTutorials then
        PlayerData.completedTutorials[modeId] = nil
        savePlayerData()
    end
end

function Tutorials.getTutorial(modeId)
    return Tutorials.data[modeId]
end

function Tutorials.getStepCount(modeId)
    local tut = Tutorials.data[modeId]
    if tut then
        return #tut.steps
    end
    return 0
end

-- ==================== TUTORIAL UI HELPER ====================
-- This can be used by any mode to display tutorial popups

local tutorialUI = {
    active = false,
    modeId = nil,
    currentStep = 1,
    animTimer = 0,
}

function Tutorials.startTutorial(modeId)
    local tut = Tutorials.data[modeId]
    if tut then
        tutorialUI.active = true
        tutorialUI.modeId = modeId
        tutorialUI.currentStep = 1
        tutorialUI.animTimer = 0
        return true
    end
    return false
end

function Tutorials.isActive()
    return tutorialUI.active
end

function Tutorials.getCurrentStep()
    if not tutorialUI.active then return nil end
    local tut = Tutorials.data[tutorialUI.modeId]
    if tut then
        return tut.steps[tutorialUI.currentStep]
    end
    return nil
end

function Tutorials.getStepNumber()
    return tutorialUI.currentStep
end

function Tutorials.getTotalSteps()
    if not tutorialUI.active then return 0 end
    local tut = Tutorials.data[tutorialUI.modeId]
    return tut and #tut.steps or 0
end

function Tutorials.nextStep()
    if not tutorialUI.active then return end
    local tut = Tutorials.data[tutorialUI.modeId]
    if tut then
        tutorialUI.currentStep = tutorialUI.currentStep + 1
        tutorialUI.animTimer = 0
        if tutorialUI.currentStep > #tut.steps then
            Tutorials.endTutorial()
        end
    end
end

function Tutorials.prevStep()
    if not tutorialUI.active then return end
    tutorialUI.currentStep = math.max(1, tutorialUI.currentStep - 1)
    tutorialUI.animTimer = 0
end

function Tutorials.endTutorial()
    if tutorialUI.active then
        Tutorials.markCompleted(tutorialUI.modeId)
        tutorialUI.active = false
        tutorialUI.modeId = nil
        tutorialUI.currentStep = 1
    end
end

function Tutorials.skipTutorial()
    if tutorialUI.active then
        Tutorials.markCompleted(tutorialUI.modeId)
        tutorialUI.active = false
        tutorialUI.modeId = nil
        tutorialUI.currentStep = 1
    end
end

function Tutorials.update(dt)
    if tutorialUI.active then
        tutorialUI.animTimer = tutorialUI.animTimer + dt
    end
end

-- Draw the tutorial popup
function Tutorials.draw()
    if not tutorialUI.active then return end

    local screenW, screenH = love.graphics.getDimensions()
    local step = Tutorials.getCurrentStep()
    if not step then return end

    local mx, my = love.mouse.getPosition()

    -- Dim background slightly
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Tutorial panel (fixed position for reliable click detection)
    local panelW = 450
    local panelH = 220
    local panelX = screenW / 2 - panelW / 2
    local panelY = screenH - panelH - 80

    -- Panel background
    love.graphics.setColor(0.1, 0.12, 0.18, 0.95)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 12, 12)

    -- Panel border
    love.graphics.setColor(0.4, 0.5, 0.7)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 12, 12)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(0.9, 0.8, 0.3)
    love.graphics.setFont(getFont(20))
    love.graphics.print(step.title, panelX + 20, panelY + 15)

    -- Step indicator
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.setFont(getFont(12))
    love.graphics.print("Step " .. tutorialUI.currentStep .. " / " .. Tutorials.getTotalSteps(),
        panelX + panelW - 80, panelY + 18)

    -- Tutorial text
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.setFont(getFont(14))
    love.graphics.printf(step.text, panelX + 20, panelY + 50, panelW - 40, "left")

    -- Navigation buttons
    local btnY = panelY + panelH - 50
    local btnH = 35

    -- Previous button (if not first step)
    if tutorialUI.currentStep > 1 then
        local prevBtnX = panelX + 20
        local prevBtnW = 80
        local prevHover = mx >= prevBtnX and mx <= prevBtnX + prevBtnW and my >= btnY and my <= btnY + btnH

        love.graphics.setColor(prevHover and {0.35, 0.4, 0.5} or {0.25, 0.3, 0.4})
        love.graphics.rectangle("fill", prevBtnX, btnY, prevBtnW, btnH, 6, 6)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("< Back", prevBtnX, btnY + 10, prevBtnW, "center")
    end

    -- Skip button
    local skipBtnX = panelX + panelW / 2 - 40
    local skipBtnW = 80
    local skipHover = mx >= skipBtnX and mx <= skipBtnX + skipBtnW and my >= btnY and my <= btnY + btnH

    love.graphics.setColor(skipHover and {0.5, 0.35, 0.35} or {0.4, 0.28, 0.28})
    love.graphics.rectangle("fill", skipBtnX, btnY, skipBtnW, btnH, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Skip", skipBtnX, btnY + 10, skipBtnW, "center")

    -- Next/Done button
    local nextBtnX = panelX + panelW - 100
    local nextBtnW = 80
    local nextHover = mx >= nextBtnX and mx <= nextBtnX + nextBtnW and my >= btnY and my <= btnY + btnH
    local isLastStep = tutorialUI.currentStep >= Tutorials.getTotalSteps()

    love.graphics.setColor(nextHover and {0.4, 0.6, 0.4} or {0.3, 0.5, 0.3})
    love.graphics.rectangle("fill", nextBtnX, btnY, nextBtnW, btnH, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(isLastStep and "Done" or "Next >", nextBtnX, btnY + 10, nextBtnW, "center")

    love.graphics.setColor(1, 1, 1)
end

-- Handle tutorial mouse clicks
function Tutorials.mousepressed(x, y, button)
    if not tutorialUI.active or button ~= 1 then return false end

    local screenW, screenH = love.graphics.getDimensions()
    local panelW = 450
    local panelH = 220
    local panelX = screenW / 2 - panelW / 2
    -- Use final panel position (ignore animation) for reliable click detection
    local panelY = screenH - panelH - 80

    local btnY = panelY + panelH - 50
    local btnH = 35

    -- Expand click areas for better hit detection
    local clickPadding = 5

    -- Previous button
    if tutorialUI.currentStep > 1 then
        local prevBtnX = panelX + 20
        local prevBtnW = 80
        if x >= prevBtnX - clickPadding and x <= prevBtnX + prevBtnW + clickPadding and
           y >= btnY - clickPadding and y <= btnY + btnH + clickPadding then
            Tutorials.prevStep()
            return true
        end
    end

    -- Skip button
    local skipBtnX = panelX + panelW / 2 - 40
    local skipBtnW = 80
    if x >= skipBtnX - clickPadding and x <= skipBtnX + skipBtnW + clickPadding and
       y >= btnY - clickPadding and y <= btnY + btnH + clickPadding then
        Tutorials.skipTutorial()
        return true
    end

    -- Next/Done button
    local nextBtnX = panelX + panelW - 100
    local nextBtnW = 80
    if x >= nextBtnX - clickPadding and x <= nextBtnX + nextBtnW + clickPadding and
       y >= btnY - clickPadding and y <= btnY + btnH + clickPadding then
        Tutorials.nextStep()
        return true
    end

    return true  -- Block other clicks while tutorial is active
end

-- Handle tutorial keypresses
function Tutorials.keypressed(key)
    if not tutorialUI.active then return false end

    if key == "return" or key == "space" or key == "right" then
        Tutorials.nextStep()
        return true
    elseif key == "left" then
        Tutorials.prevStep()
        return true
    elseif key == "escape" then
        Tutorials.skipTutorial()
        return true
    end

    return true  -- Block other keys while tutorial active
end

return Tutorials
