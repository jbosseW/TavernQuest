-- Wilds Rancher and Tamer - Creature breeding and taming game
-- Adopt, breed, train wild creatures! Equip them as companions or mounts.

local PetSim = {}
local UI = require("ui")
local UIAssets = require("uiassets")
local Progression = require("progression")
local InteractiveTutorial = require("interactivetutorial")

-- Use UI component library font cache
local function getFont(size)
    return UI.fonts.get(size)
end

-- Element types (tied to creature card game)
local ELEMENTS = {
    {id = "flame", name = "Flame", color = {0.9, 0.3, 0.2}, icon = "🔥"},
    {id = "aqua", name = "Aqua", color = {0.2, 0.5, 0.9}, icon = "💧"},
    {id = "terra", name = "Terra", color = {0.5, 0.7, 0.3}, icon = "🌿"},
    {id = "volt", name = "Volt", color = {0.9, 0.8, 0.2}, icon = "⚡"},
    {id = "shadow", name = "Shadow", color = {0.4, 0.2, 0.5}, icon = "🌙"},
    {id = "light", name = "Light", color = {0.9, 0.9, 0.6}, icon = "✨"},
    {id = "frost", name = "Frost", color = {0.6, 0.8, 0.95}, icon = "❄️"},
    {id = "metal", name = "Metal", color = {0.6, 0.6, 0.7}, icon = "⚙️"},
}

-- Mount types for terrain traversal
local MOUNT_TYPES = {
    {id = "land", name = "Land", terrains = {"plains", "forest", "wasteland"}, speedMult = 1.0},
    {id = "aquatic", name = "Aquatic", terrains = {"ocean", "river", "lake"}, speedMult = 1.0},
    {id = "flying", name = "Flying", terrains = {"mountain", "plains", "forest", "wasteland"}, speedMult = 4.0},
}

-- Helper to get element by id
local function getElement(id)
    for _, elem in ipairs(ELEMENTS) do
        if elem.id == id then return elem end
    end
    return ELEMENTS[1]
end

-- Pet species definitions with character portraits, elements, and mount types
local PET_SPECIES = {
    {
        id = "slime",
        name = "Blobby",
        emoji = "🟢",
        portrait = "Monsters/Monster_Slime",
        desc = "A friendly slime that's easy to care for",
        basePrice = 50,
        hungerRate = 0.5,
        happinessRate = 0.3,
        energyRate = 0.2,
        maxAge = 30,
        evolutions = {"green_slime", "crystal_slime"},
        evolutionPortraits = {"Monsters/Monster_Slime", "Monsters/Monster_Elemental"},
        color = {0.3, 0.8, 0.3},
        element = "terra",
        mountType = nil,  -- Not mountable
        battlePower = 10,
    },
    {
        id = "chick",
        name = "Chirpy",
        emoji = "🐤",
        portrait = "Animals/Bird_animal",
        desc = "A cute chick that loves attention",
        basePrice = 6000,  -- Flying mount potential (4x speed when evolved) - 10x premium
        hungerRate = 0.8,
        happinessRate = 0.6,
        energyRate = 0.3,
        maxAge = 25,
        evolutions = {"chicken", "golden_chicken"},
        evolutionPortraits = {"Animals/Bird_animal", "Monsters/Creatures_07_phoenix"},
        color = {1, 0.9, 0.3},
        element = "light",
        mountType = "flying",  -- Can fly when evolved
        battlePower = 15,
    },
    {
        id = "kitten",
        name = "Whiskers",
        emoji = "🐱",
        portrait = "Animals/Cat_animal",
        desc = "A playful kitten that needs lots of play",
        basePrice = 200,
        hungerRate = 0.7,
        happinessRate = 0.8,
        energyRate = 0.4,
        maxAge = 40,
        evolutions = {"cat", "royal_cat"},
        evolutionPortraits = {"Animals/Cat_animal", "Animals/Creatures_12_Dog"},
        color = {0.9, 0.7, 0.5},
        element = "shadow",
        mountType = nil,  -- Not mountable
        battlePower = 20,
    },
    {
        id = "puppy",
        name = "Buddy",
        emoji = "🐶",
        portrait = "Animals/Creatures_12_Dog",
        desc = "A loyal puppy that loves walks",
        basePrice = 200,
        hungerRate = 0.9,
        happinessRate = 0.7,
        energyRate = 0.5,
        maxAge = 45,
        evolutions = {"dog", "champion_dog"},
        evolutionPortraits = {"Animals/Creatures_12_Dog", "Monsters/Creatures_05_werewolf"},
        color = {0.7, 0.5, 0.3},
        element = "terra",
        mountType = nil,  -- Not mountable
        battlePower = 25,
    },
    {
        id = "dragon_egg",
        name = "Mystery Egg",
        emoji = "🥚",
        portrait = "Animals/Monsters_09",
        desc = "A mysterious egg... what could hatch?",
        basePrice = 50000,  -- Rare dragon - powerful flying mount (4x speed) - 10x premium
        hungerRate = 0.3,
        happinessRate = 0.2,
        energyRate = 0.1,
        maxAge = 100,
        evolutions = {"baby_dragon", "dragon"},
        evolutionPortraits = {"Animals/Monsters_09", "Monsters/Creatures_11_Dragon"},
        color = {0.6, 0.4, 0.8},
        element = "flame",
        mountType = "flying",  -- Can fly when evolved
        battlePower = 50,
    },
    {
        id = "bunny",
        name = "Hoppy",
        emoji = "🐰",
        portrait = "Animals/Monsters_16",
        desc = "A bouncy bunny that loves carrots",
        basePrice = 150,
        hungerRate = 0.6,
        happinessRate = 0.5,
        energyRate = 0.3,
        maxAge = 35,
        evolutions = {"rabbit", "magic_bunny"},
        evolutionPortraits = {"Animals/Monsters_16", "Animals/Monsters_22"},
        color = {1, 0.8, 0.9},
        element = "light",
        mountType = nil,  -- Not mountable
        battlePower = 15,
    },
    {
        id = "fish",
        name = "Bubbles",
        emoji = "🐠",
        portrait = "Monsters/Monster_fish",
        desc = "A colorful fish that's relaxing to watch",
        basePrice = 750,  -- Aquatic mount potential - 10x premium
        hungerRate = 0.4,
        happinessRate = 0.2,
        energyRate = 0.1,
        maxAge = 20,
        evolutions = {"tropical_fish", "koi"},
        evolutionPortraits = {"Monsters/Monster_fish", "Monsters/Monster_DemonicFish"},
        color = {0.3, 0.6, 0.9},
        element = "aqua",
        mountType = "aquatic",  -- Water travel when evolved
        battlePower = 12,
    },
    {
        id = "hamster",
        name = "Nibbles",
        emoji = "🐹",
        portrait = "Animals/Monsters_11",
        desc = "A tiny hamster that loves its wheel",
        basePrice = 80,
        hungerRate = 0.5,
        happinessRate = 0.4,
        energyRate = 0.6,
        maxAge = 15,
        evolutions = {"chubby_hamster", "hamster_king"},
        evolutionPortraits = {"Animals/Monsters_11", "Animals/Monsters_12"},
        color = {0.9, 0.7, 0.5},
        element = "terra",
        mountType = nil,  -- Not mountable
        battlePower = 8,
    },
    {
        id = "wolf",
        name = "Shadow",
        emoji = "🐺",
        portrait = "Animals/Wolf_animal",
        desc = "A majestic wolf with piercing eyes",
        basePrice = 800,  -- Land mount (2x speed)
        hungerRate = 0.8,
        happinessRate = 0.5,
        energyRate = 0.6,
        maxAge = 50,
        evolutions = {"dire_wolf", "alpha_wolf"},
        evolutionPortraits = {"Animals/Wolf_animal", "Monsters/Creatures_05_werewolf"},
        color = {0.5, 0.5, 0.6},
        element = "shadow",
        mountType = "land",  -- Rideable wolf mount
        battlePower = 35,
    },
    {
        id = "bear",
        name = "Grumble",
        emoji = "🐻",
        portrait = "Animals/Bear_animal",
        desc = "A cuddly bear that loves honey",
        basePrice = 1000,  -- Land mount (2x speed)
        hungerRate = 0.9,
        happinessRate = 0.4,
        energyRate = 0.3,
        maxAge = 60,
        evolutions = {"grizzly", "spirit_bear"},
        evolutionPortraits = {"Animals/Bear_animal", "Monsters/Gigant_05_pangolin"},
        color = {0.6, 0.4, 0.2},
        element = "terra",
        mountType = "land",  -- Rideable bear mount
        battlePower = 40,
    },
    {
        id = "hawk",
        name = "Talon",
        emoji = "🦅",
        portrait = "Animals/Hawk_animal",
        desc = "A swift hawk with keen eyes",
        basePrice = 20000,  -- Flying mount (4x speed) - 10x premium
        hungerRate = 0.6,
        happinessRate = 0.6,
        energyRate = 0.7,
        maxAge = 35,
        evolutions = {"eagle", "thunderbird"},
        evolutionPortraits = {"Animals/Hawk_animal", "Monsters/Creatures_07_phoenix"},
        color = {0.7, 0.5, 0.3},
        element = "volt",
        mountType = "flying",  -- Flying mount
        battlePower = 30,
    },
    {
        id = "bat",
        name = "Midnight",
        emoji = "🦇",
        portrait = "Animals/Bat",
        desc = "A nocturnal bat that sleeps during the day",
        basePrice = 8000,  -- Flying mount potential (4x speed when evolved) - 10x premium
        hungerRate = 0.4,
        happinessRate = 0.3,
        energyRate = 0.5,
        maxAge = 25,
        evolutions = {"vampire_bat", "shadow_bat"},
        evolutionPortraits = {"Animals/Bat", "Monsters/Monster_Eye"},
        color = {0.3, 0.2, 0.4},
        element = "shadow",
        mountType = "flying",  -- Flying mount when evolved
        battlePower = 18,
    },
    -- New mountable creatures
    {
        id = "horse",
        name = "Storm",
        emoji = "🐴",
        portrait = "Animals/Creatures_10_warhorse",
        desc = "A noble steed for land travel",
        basePrice = 1200,  -- Classic land mount (2x speed)
        hungerRate = 0.7,
        happinessRate = 0.4,
        energyRate = 0.5,
        maxAge = 55,
        evolutions = {"stallion", "warhorse"},
        evolutionPortraits = {"Animals/Horse_animal", "Animals/Creatures_10_warhorse"},
        color = {0.5, 0.4, 0.3},
        element = "terra",
        mountType = "land",  -- Land mount
        battlePower = 25,
    },
    {
        id = "dolphin",
        name = "Splash",
        emoji = "🐬",
        portrait = "Animals/Dolphin_animal",
        desc = "A playful dolphin for ocean travel",
        basePrice = 9000,  -- Aquatic mount (2x speed in water) - 10x premium
        hungerRate = 0.6,
        happinessRate = 0.8,
        energyRate = 0.5,
        maxAge = 45,
        evolutions = {"ocean_dolphin", "sea_king"},
        evolutionPortraits = {"Animals/Dolphin_animal", "Monsters/Monster_waterm"},
        color = {0.3, 0.5, 0.8},
        element = "aqua",
        mountType = "aquatic",  -- Water mount
        battlePower = 22,
    },
    {
        id = "phoenix",
        name = "Blaze",
        emoji = "🔥",
        portrait = "Monsters/Creatures_07_phoenix",
        desc = "A legendary firebird for sky travel",
        basePrice = 100000,  -- Legendary flying mount (4x speed) - extremely rare - 10x premium
        hungerRate = 0.4,
        happinessRate = 0.5,
        energyRate = 0.3,
        maxAge = 100,
        evolutions = {"firebird", "eternal_phoenix"},
        evolutionPortraits = {"Monsters/Creatures_07_phoenix", "Monsters/Creatures_07_phoenix"},
        color = {1, 0.5, 0.2},
        element = "flame",
        mountType = "flying",  -- Flying mount - 4x speed
        battlePower = 60,
    },
}

-- ============================================================================
-- VEHICLES (Non-living transport - NOT pets, don't need feeding/happiness)
-- ============================================================================
local VEHICLES = {
    -- Water Vehicles
    {
        id = "rowboat",
        name = "Rowboat",
        emoji = "🚣",
        portrait = "Items/boat_small",
        desc = "A simple rowboat for river and coastal travel",
        basePrice = 5000,  -- Water transport - premium pricing
        color = {0.6, 0.4, 0.2},
        vehicleType = "boat",
        mountType = "boat",  -- For compatibility
        speedMultiplier = 2.0,  -- 2x speed in water
        terrain = {"water", "river", "lake", "coast"},
        maintenance = 50,  -- Gold per 10 trips for repairs
    },
    {
        id = "sailboat",
        name = "Sailboat",
        emoji = "⛵",
        portrait = "Items/boat_sail",
        desc = "A swift sailboat for ocean voyages",
        basePrice = 25000,  -- Fast water transport - premium pricing
        color = {0.8, 0.8, 0.9},
        vehicleType = "boat",
        mountType = "boat",
        speedMultiplier = 3.0,  -- 3x speed in water
        terrain = {"water", "ocean", "river", "lake", "coast"},
        maintenance = 150,
    },
    {
        id = "ship",
        name = "Trading Ship",
        emoji = "🚢",
        portrait = "Items/ship_trade",
        desc = "A large trading vessel for ocean commerce",
        basePrice = 75000,  -- Major investment
        color = {0.5, 0.4, 0.3},
        vehicleType = "ship",
        mountType = "boat",
        speedMultiplier = 2.5,  -- Slower than sailboat but more cargo
        terrain = {"water", "ocean"},
        maintenance = 300,
        cargoBonus = 500,  -- Massive cargo capacity
    },
    -- Land Vehicles
    {
        id = "horse_cart",
        name = "Horse Cart",
        emoji = "🛒",
        portrait = "Items/cart_horse",
        desc = "A sturdy cart pulled by horses - safer travel",
        basePrice = 2500,  -- Land vehicle
        color = {0.5, 0.35, 0.2},
        vehicleType = "cart",
        mountType = "cart",
        speedMultiplier = 1.5,
        terrain = {"grass", "road", "plains", "forest"},
        maintenance = 30,
        encounterReduction = 0.5,  -- 50% less encounters
        cargoBonus = 50,
    },
    {
        id = "merchant_wagon",
        name = "Merchant Wagon",
        emoji = "🚚",
        portrait = "Items/wagon_merchant",
        desc = "A large covered wagon for trade caravans",
        basePrice = 6000,  -- Trade vehicle
        color = {0.4, 0.3, 0.2},
        vehicleType = "wagon",
        mountType = "cart",
        speedMultiplier = 1.2,  -- Slower but huge cargo
        terrain = {"grass", "road", "plains"},
        maintenance = 75,
        encounterReduction = 0.3,  -- Guards
        cargoBonus = 150,
    },
    -- Air Vehicles (future content - gnomish technology)
    {
        id = "air_balloon",
        name = "Hot Air Balloon",
        emoji = "🎈",
        portrait = "Items/balloon",
        desc = "A gnomish hot air balloon for slow aerial travel",
        basePrice = 50000,  -- Rare gnomish tech
        color = {0.9, 0.3, 0.3},
        vehicleType = "airship",
        mountType = "flying",
        speedMultiplier = 2.0,  -- Slower than flying mounts
        terrain = {"any"},  -- Can fly over anything
        maintenance = 200,
        encounterReduction = 0.1,  -- Very safe (90% reduction)
        requiresRegion = "gnomish_isles",  -- Only purchasable in Gnomish Isles
    },
    {
        id = "airship",
        name = "Gnomish Airship",
        emoji = "🚁",
        portrait = "Items/airship",
        desc = "A mechanical marvel - fast aerial transport",
        basePrice = 150000,  -- Extremely expensive gnomish tech
        color = {0.6, 0.5, 0.4},
        vehicleType = "airship",
        mountType = "flying",
        speedMultiplier = 4.0,  -- As fast as flying mounts
        terrain = {"any"},
        maintenance = 500,
        encounterReduction = 0.05,  -- Almost no encounters (95% reduction)
        cargoBonus = 100,
        requiresRegion = "gnomish_isles",
    },
}

-- Food items
local FOODS = {
    {id = "basic_food", name = "Basic Food", icon = "bread", color = {0.8, 0.5, 0.3}, hunger = 20, price = 5},
    {id = "premium_food", name = "Premium Food", icon = "steak", color = {0.9, 0.3, 0.3}, hunger = 40, price = 15},
    {id = "treat", name = "Tasty Treat", icon = "pet_treat", color = {0.9, 0.6, 0.8}, hunger = 10, happiness = 15, price = 10},
    {id = "carrot", name = "Carrot", icon = "carrot", color = {1, 0.6, 0.2}, hunger = 15, price = 3},
    {id = "fish_food", name = "Fish Flakes", icon = "fish", color = {0.4, 0.7, 0.9}, hunger = 25, price = 8},
    {id = "gourmet", name = "Gourmet Meal", icon = "chicken_leg", color = {0.9, 0.8, 0.3}, hunger = 60, happiness = 20, price = 30},
}

-- Toys/activities
local TOYS = {
    {id = "ball", name = "Play Ball", icon = "potion_generic_2", color = {0.3, 0.8, 0.3}, happiness = 20, energy = -15, price = 20},
    {id = "puzzle", name = "Puzzle Toy", icon = "book", color = {0.6, 0.4, 0.8}, happiness = 25, energy = -10, price = 35},
    {id = "wheel", name = "Running Wheel", icon = "compass", color = {0.7, 0.7, 0.7}, happiness = 15, energy = -25, price = 25},
    {id = "plush", name = "Plush Friend", icon = "bag_brown", color = {0.9, 0.7, 0.5}, happiness = 30, energy = -5, price = 40},
    {id = "laser", name = "Laser Pointer", icon = "torch_lit", color = {1, 0.2, 0.2}, happiness = 35, energy = -20, price = 30},
}

-- Pet activity animations
local PET_ACTIVITIES = {
    idle = {duration = 2, text_label = nil},
    walking = {duration = 3, text_label = "~"},
    eating = {duration = 2, text_label = "Eating"},
    playing = {duration = 2.5, text_label = "Playing"},
    sleeping = {duration = 5, text_label = "Sleeping"},
    happy = {duration = 1.5, text_label = "Happy!"},
}

-- Game state
local state = {
    pets = {},  -- Player's pets
    eggs = {},  -- Eggs waiting to hatch
    selectedPet = nil,
    selectedPetAction = nil,  -- Pet ID for action panel
    viewMode = "habitat",  -- habitat, pets, shop, details, eggs
    shopTab = "pets",  -- pets, food, toys
    inventory = {
        food = {},
        toys = {},
    },
    lastUpdateTime = 0,
    notifications = {},
    shopScroll = 0,
    petScroll = 0,
    -- Habitat area bounds (set in init)
    habitatX = 50,
    habitatY = 120,
    habitatW = 0,
    habitatH = 0,
    -- Day/night cycle and seasons
    timeOfDay = 12,  -- 0-24 hours
    daysPassed = 0,
    season = "frosthollow",  -- Deepmere = Frosthollow
    seasonIndex = 4,
    -- Breeding cooldown per species
    breedingCooldowns = {},
    -- UI Components
    ui = {
        shopTabBar = nil,
        habitatButtons = {},
        petCardButtons = {},  -- Deprecated: pet card buttons now drawn manually
        shopCards = {},
        progressBars = {},
    },
}

-- Helper to get species by id
local function getSpecies(id)
    for _, species in ipairs(PET_SPECIES) do
        if species.id == id then return species end
    end
    return PET_SPECIES[1]
end

-- Helper to get vehicle by id
local function getVehicle(id)
    for _, vehicle in ipairs(VEHICLES) do
        if vehicle.id == id then return vehicle end
    end
    return nil
end

-- Get all vehicles
local function getAllVehicles()
    return VEHICLES
end

-- Get vehicles by type (boat, cart, airship)
local function getVehiclesByType(vehicleType)
    local result = {}
    for _, vehicle in ipairs(VEHICLES) do
        if vehicle.vehicleType == vehicleType then
            table.insert(result, vehicle)
        end
    end
    return result
end

-- Create a new pet
local function createPet(speciesId, name, gender)
    local species = getSpecies(speciesId)
    -- Random gender if not specified
    if not gender then
        gender = math.random() < 0.5 and "male" or "female"
    end
    return {
        id = math.random(100000, 999999),
        speciesId = speciesId,
        name = name or species.name,
        gender = gender,
        element = species.element or "terra",
        hunger = 100,
        happiness = 100,
        energy = 100,
        health = 100,
        age = 0,  -- In real minutes
        evolutionStage = 1,
        lastChecked = os.time(),
        lastFed = os.time(),
        lastPlayed = os.time(),
        lastSlept = os.time(),
        birthTime = os.time(),
        isSleeping = false,
        traits = {},
        battlePower = species.battlePower or 10,
        mountType = species.mountType,
        -- Visual/animation properties
        x = math.random(100, 500),
        y = math.random(200, 400),
        targetX = nil,
        targetY = nil,
        activity = "idle",
        activityTimer = 0,
        direction = 1,  -- 1 = right, -1 = left
        bobOffset = 0,
        bobTimer = 0,
        showEmote = nil,
        emoteTimer = 0,
    }
end

-- Create an egg
local function createEgg(speciesId, parentMale, parentFemale)
    local species = getSpecies(speciesId)
    return {
        id = math.random(100000, 999999),
        speciesId = speciesId,
        parentMale = parentMale,
        parentFemale = parentFemale,
        element = species.element or "terra",
        layTime = os.time(),
        hatchTime = os.time() + (species.maxAge * 60),  -- Hatch after maxAge minutes (scaled)
        progress = 0,  -- 0-100%
    }
end

-- Check for breeding pairs and create eggs
local function checkBreeding()
    -- Group pets by species
    local speciesGroups = {}
    for _, pet in ipairs(state.pets) do
        if pet.evolutionStage >= 2 and pet.health > 50 and pet.happiness > 60 then
            if not speciesGroups[pet.speciesId] then
                speciesGroups[pet.speciesId] = {males = {}, females = {}}
            end
            if pet.gender == "male" then
                table.insert(speciesGroups[pet.speciesId].males, pet)
            else
                table.insert(speciesGroups[pet.speciesId].females, pet)
            end
        end
    end

    -- Check each species for breeding pairs
    for speciesId, group in pairs(speciesGroups) do
        if #group.males > 0 and #group.females > 0 then
            -- Check cooldown (one egg per species every 5 real minutes)
            local cooldown = state.breedingCooldowns[speciesId] or 0
            if os.time() > cooldown then
                -- Random chance to lay egg (20% per check)
                if math.random() < 0.2 then
                    local male = group.males[math.random(#group.males)]
                    local female = group.females[math.random(#group.females)]
                    local egg = createEgg(speciesId, male.name, female.name)
                    table.insert(state.eggs, egg)
                    state.breedingCooldowns[speciesId] = os.time() + 300  -- 5 minute cooldown

                    table.insert(state.notifications, {
                        text = female.name .. " laid an egg!",
                        color = {0.9, 0.7, 0.3},
                        time = love.timer.getTime()
                    })
                end
            end
        end
    end
end

-- Update eggs and check for hatching
local function updateEggs(dt)
    for i = #state.eggs, 1, -1 do
        local egg = state.eggs[i]
        local elapsed = os.time() - egg.layTime
        local totalTime = egg.hatchTime - egg.layTime
        egg.progress = math.min(100, (elapsed / totalTime) * 100)

        if os.time() >= egg.hatchTime then
            -- Hatch the egg!
            local newPet = createPet(egg.speciesId, nil, nil)
            table.insert(state.pets, newPet)
            table.remove(state.eggs, i)

            table.insert(state.notifications, {
                text = "An egg hatched into " .. newPet.name .. "!",
                color = {0.3, 0.9, 0.5},
                time = love.timer.getTime()
            })

            -- Award XP for hatching
            Progression.addXP(Progression.XP_REWARDS.evolve_pet, "petsim")
        end
    end
end

-- Initialize visual properties for existing pets (migration)
local function initPetVisuals(pet)
    if not pet.x then
        pet.x = math.random(100, 500)
        pet.y = math.random(200, 400)
        pet.targetX = nil
        pet.targetY = nil
        pet.activity = "idle"
        pet.activityTimer = 0
        pet.direction = 1
        pet.bobOffset = 0
        pet.bobTimer = 0
        pet.showEmote = nil
        pet.emoteTimer = 0
    end
    -- Migration for gender and element
    if not pet.gender then
        pet.gender = math.random() < 0.5 and "male" or "female"
    end
    if not pet.element then
        local species = getSpecies(pet.speciesId)
        pet.element = species.element or "terra"
    end
    if not pet.battlePower then
        local species = getSpecies(pet.speciesId)
        pet.battlePower = species.battlePower or 10
    end
    if not pet.mountType then
        local species = getSpecies(pet.speciesId)
        pet.mountType = species.mountType
    end
end

-- Update pet visual movement and animations
local function updatePetVisuals(pet, dt)
    local species = getSpecies(pet.speciesId)

    -- Initialize if needed
    if not pet.x then initPetVisuals(pet) end

    -- Bob animation (breathing/bouncing)
    pet.bobTimer = (pet.bobTimer or 0) + dt * 3
    pet.bobOffset = math.sin(pet.bobTimer) * 3

    -- Emote timer
    if pet.showEmote then
        pet.emoteTimer = (pet.emoteTimer or 0) + dt
        if pet.emoteTimer > 2 then
            pet.showEmote = nil
            pet.emoteTimer = 0
        end
    end

    -- Activity timer
    pet.activityTimer = (pet.activityTimer or 0) + dt
    local activityInfo = PET_ACTIVITIES[pet.activity] or PET_ACTIVITIES.idle

    -- Handle sleeping pets
    if pet.isSleeping then
        pet.activity = "sleeping"
        pet.targetX = nil
        pet.targetY = nil
        return
    end

    -- Choose new activity when current one ends
    if pet.activityTimer > activityInfo.duration then
        pet.activityTimer = 0

        -- Determine next activity based on stats
        local roll = math.random(100)

        if pet.energy < 30 then
            -- Tired - mostly idle or sleep
            if roll < 60 then
                pet.activity = "idle"
            else
                pet.activity = "walking"
                pet.targetX = pet.x + math.random(-100, 100)
                pet.targetY = pet.y + math.random(-50, 50)
            end
        elseif pet.happiness > 70 then
            -- Happy - more active
            if roll < 20 then
                pet.activity = "idle"
            elseif roll < 60 then
                pet.activity = "walking"
                pet.targetX = pet.x + math.random(-150, 150)
                pet.targetY = pet.y + math.random(-80, 80)
            elseif roll < 80 then
                pet.activity = "playing"
            else
                pet.activity = "happy"
                pet.showEmote = "💕"
                pet.emoteTimer = 0
            end
        else
            -- Normal activity
            if roll < 40 then
                pet.activity = "idle"
            elseif roll < 80 then
                pet.activity = "walking"
                pet.targetX = pet.x + math.random(-120, 120)
                pet.targetY = pet.y + math.random(-60, 60)
            else
                pet.activity = "playing"
            end
        end
    end

    -- Move towards target if walking
    if pet.activity == "walking" and pet.targetX and pet.targetY then
        local dx = pet.targetX - pet.x
        local dy = pet.targetY - pet.y
        local dist = math.sqrt(dx * dx + dy * dy)

        if dist > 5 then
            local speed = 50 * dt
            pet.x = pet.x + (dx / dist) * speed
            pet.y = pet.y + (dy / dist) * speed

            -- Update direction
            if dx > 0 then
                pet.direction = 1
            elseif dx < 0 then
                pet.direction = -1
            end
        else
            pet.targetX = nil
            pet.targetY = nil
            pet.activity = "idle"
            pet.activityTimer = 0
        end
    end

    -- Clamp to habitat bounds
    if state.habitatW > 0 then
        local margin = 40
        pet.x = math.max(state.habitatX + margin, math.min(state.habitatX + state.habitatW - margin, pet.x))
        pet.y = math.max(state.habitatY + margin, math.min(state.habitatY + state.habitatH - margin, pet.y))

        -- Also clamp targets
        if pet.targetX then
            pet.targetX = math.max(state.habitatX + margin, math.min(state.habitatX + state.habitatW - margin, pet.targetX))
            pet.targetY = math.max(state.habitatY + margin, math.min(state.habitatY + state.habitatH - margin, pet.targetY))
        end
    end
end

-- Update pet stats based on real time
local function updatePetStats(pet, dt)
    local species = getSpecies(pet.speciesId)

    -- Calculate time passed since last check (in minutes)
    local now = os.time()
    local minutesPassed = (now - (pet.lastChecked or now)) / 60
    pet.lastChecked = now

    if pet.isSleeping then
        -- Sleeping pets recover energy but get hungry faster
        pet.energy = math.min(100, pet.energy + minutesPassed * 2)
        pet.hunger = math.max(0, pet.hunger - minutesPassed * species.hungerRate * 0.5)

        -- Wake up when fully rested
        if pet.energy >= 100 then
            pet.isSleeping = false
        end
    else
        -- Decrease stats over time
        pet.hunger = math.max(0, pet.hunger - minutesPassed * species.hungerRate)
        pet.happiness = math.max(0, pet.happiness - minutesPassed * species.happinessRate)
        pet.energy = math.max(0, pet.energy - minutesPassed * species.energyRate)

        -- Age increases (1 age unit per real minute)
        pet.age = pet.age + minutesPassed
    end

    -- Health affected by other stats
    if pet.hunger < 20 or pet.happiness < 20 then
        pet.health = math.max(0, pet.health - minutesPassed * 0.5)
    elseif pet.hunger > 80 and pet.happiness > 80 then
        pet.health = math.min(100, pet.health + minutesPassed * 0.2)
    end

    -- Check for evolution
    local evoThreshold = species.maxAge / 3
    if pet.age >= evoThreshold and pet.evolutionStage == 1 then
        pet.evolutionStage = 2
        table.insert(state.notifications, {
            text = pet.name .. " evolved!",
            color = {0.9, 0.7, 0.2},
            time = love.timer.getTime()
        })
        -- Award XP for evolution
        Progression.addXP(Progression.XP_REWARDS.evolve_pet, "petsim")
    elseif pet.age >= evoThreshold * 2 and pet.evolutionStage == 2 then
        pet.evolutionStage = 3
        table.insert(state.notifications, {
            text = pet.name .. " reached final form!",
            color = {0.9, 0.3, 0.9},
            time = love.timer.getTime()
        })
        -- Award XP for final evolution
        Progression.addXP(Progression.XP_REWARDS.evolve_pet, "petsim")
        -- Evolving to final form counts towards global wins for unlocks
        PlayerData.wins = PlayerData.wins + 1
        savePlayerData()
    end
end

-- Feed a pet
local function feedPet(pet, food)
    pet.hunger = math.min(100, pet.hunger + food.hunger)
    if food.happiness then
        pet.happiness = math.min(100, pet.happiness + food.happiness)
    end
    pet.lastFed = os.time()
    -- Award XP for feeding
    Progression.addXP(Progression.XP_REWARDS.feed_pet, "petsim")
    return true
end

-- Play with a pet
local function playWithPet(pet, toy)
    if pet.energy < math.abs(toy.energy or 0) then
        return false, "Pet is too tired!"
    end

    pet.happiness = math.min(100, pet.happiness + toy.happiness)
    pet.energy = math.max(0, pet.energy + (toy.energy or 0))
    pet.lastPlayed = os.time()
    -- Award XP for playing
    Progression.addXP(Progression.XP_REWARDS.play_pet, "petsim")
    return true
end

-- Put pet to sleep
local function putToSleep(pet)
    if pet.isSleeping then return false end
    pet.isSleeping = true
    pet.lastSlept = os.time()
    return true
end

-- Get pet mood
local function getPetMood(pet)
    local avgStat = (pet.hunger + pet.happiness + pet.energy) / 3

    if avgStat >= 80 then
        return "Excellent!", {0.3, 0.9, 0.3}, "Excellent"
    elseif avgStat >= 60 then
        return "Good", {0.5, 0.8, 0.3}, "Good"
    elseif avgStat >= 40 then
        return "Okay", {0.9, 0.8, 0.2}, "Okay"
    elseif avgStat >= 20 then
        return "Poor", {0.9, 0.5, 0.2}, "Poor"
    else
        return "Critical!", {0.9, 0.2, 0.2}, "Critical"
    end
end

-- Get evolution emoji
local function getEvolutionEmoji(pet)
    local species = getSpecies(pet.speciesId)

    if pet.evolutionStage == 1 then
        return species.emoji
    elseif pet.evolutionStage == 2 then
        -- Slightly different emoji for stage 2
        local stage2Emojis = {
            slime = "💚",
            chick = "🐔",
            kitten = "😺",
            puppy = "🐕",
            dragon_egg = "🐲",
            bunny = "🐇",
            fish = "🐡",
            hamster = "🐿️",
        }
        return stage2Emojis[species.id] or species.emoji
    else
        -- Final evolution
        local stage3Emojis = {
            slime = "💎",
            chick = "🦅",
            kitten = "🦁",
            puppy = "🐺",
            dragon_egg = "🐉",
            bunny = "✨",
            fish = "🐋",
            hamster = "👑",
        }
        return stage3Emojis[species.id] or species.emoji
    end
end

-- Initialize UI components
local function initUIComponents()
    local screenW, screenH = love.graphics.getDimensions()
    local contentY = 110

    -- Shop tab bar
    state.ui.shopTabBar = UI.TabBar.new({
        x = 30,
        y = contentY,
        w = 330,
        tabs = {
            {id = "pets", label = "Adopt Pet"},
            {id = "food", label = "Food"},
            {id = "toys", label = "Toys"},
        },
        activeTab = state.shopTab,
        onChange = function(newTab)
            state.shopTab = newTab
        end
    })

    -- Habitat quick action buttons will be created dynamically in draw
    -- Pet card buttons will be created dynamically in draw
    -- Progress bars will be created dynamically in draw
end

function PetSim.init()
    -- Initialize UI assets for pet portraits
    UIAssets.init()

    -- Play town music
    if AudioSystem and AudioSystem.playTownMusic then
        AudioSystem.playTownMusic()
    end

    -- Load saved pets, eggs, and time data
    if PlayerData.petSim then
        state.pets = PlayerData.petSim.pets or {}
        state.eggs = PlayerData.petSim.eggs or {}
        state.inventory = PlayerData.petSim.inventory or {food = {}, toys = {}}
        state.lastUpdateTime = PlayerData.petSim.lastUpdateTime or os.time()
        state.timeOfDay = PlayerData.petSim.timeOfDay or 12
        state.daysPassed = PlayerData.petSim.daysPassed or 0
        state.season = PlayerData.petSim.season or "frosthollow"
        state.seasonIndex = PlayerData.petSim.seasonIndex or 1
        state.breedingCooldowns = PlayerData.petSim.breedingCooldowns or {}
    else
        state.pets = {}
        state.eggs = {}
        state.inventory = {food = {}, toys = {}}
        state.lastUpdateTime = os.time()
        state.timeOfDay = 12
        state.daysPassed = 0
        state.season = "frosthollow"  -- Deepmere = Frosthollow
        state.seasonIndex = 1
        state.breedingCooldowns = {}
    end

    -- Give starter food if none
    if #state.inventory.food == 0 then
        table.insert(state.inventory.food, {id = "basic_food", count = 5})
    end

    state.viewMode = "habitat"  -- Start in habitat view
    state.selectedPet = nil
    state.notifications = {}
    state.shopScroll = 0
    state.petScroll = 0

    -- Set habitat bounds
    local screenW, screenH = love.graphics.getDimensions()
    state.habitatX = 50
    state.habitatY = 120
    state.habitatW = screenW - 100
    state.habitatH = screenH - 200

    -- Update all pets for time passed while away
    for _, pet in ipairs(state.pets) do
        updatePetStats(pet, 0)
        initPetVisuals(pet)
    end

    -- Initialize UI components
    initUIComponents()

    -- Register UI region resolver for interactive tutorials
    InteractiveTutorial.registerRegionResolver("petsim", PetSim.getUIRegion)
end

function PetSim.save()
    PlayerData.petSim = {
        pets = state.pets,
        eggs = state.eggs,
        inventory = state.inventory,
        lastUpdateTime = os.time(),
        timeOfDay = state.timeOfDay,
        daysPassed = state.daysPassed,
        season = state.season,
        seasonIndex = state.seasonIndex,
        breedingCooldowns = state.breedingCooldowns,
    }
    savePlayerData()
end

-- Seasons table
local SEASONS = {"frosthollow", "brightbloom", "sunreign", "ashwane"}
local SEASON_DISPLAY = {
    frosthollow = "Frosthollow",
    brightbloom = "Brightbloom",
    sunreign    = "Sunreign",
    ashwane     = "Ashwane",
}

-- Calendar system - lore-based months
local PET_MONTHS = {
    {name = "Deepmere",    days = 31},
    {name = "Ironveil",    days = 28},
    {name = "Thawmist",    days = 31},
    {name = "Greenward",   days = 30},
    {name = "Starbloom",   days = 31},
    {name = "Solaren",     days = 30},
    {name = "Highsun",     days = 31},
    {name = "Forgefire",   days = 31},
    {name = "Harvestmere", days = 30},
    {name = "Glassfall",   days = 31},
    {name = "Shadowmere",  days = 30},
    {name = "Voidwatch",   days = 31},
}

local function getPetSeasonFromMonth(month)
    if month >= 3 and month <= 5 then return "brightbloom"
    elseif month >= 6 and month <= 8 then return "sunreign"
    elseif month >= 9 and month <= 11 then return "ashwane"
    else return "frosthollow" end
end

local function getPetCalendarMonth(daysPassed)
    local totalDays = daysPassed % 365
    for i = 1, 12 do
        if totalDays < PET_MONTHS[i].days then return i end
        totalDays = totalDays - PET_MONTHS[i].days
    end
    return 1
end

function PetSim.update(dt)
    -- Update habitat bounds on resize
    local screenW, screenH = love.graphics.getDimensions()
    state.habitatW = screenW - 100
    state.habitatH = screenH - 200

    -- Update day/night cycle (1 game hour = 1 real minute)
    state.timeOfDay = state.timeOfDay + (dt / 60) * 1  -- 1 hour per real minute
    if state.timeOfDay >= 24 then
        state.timeOfDay = state.timeOfDay - 24
        state.daysPassed = state.daysPassed + 1

        -- Update season based on calendar month
        local month = getPetCalendarMonth(state.daysPassed)
        local newSeason = getPetSeasonFromMonth(month)
        if newSeason ~= state.season then
            state.seasonIndex = ({frosthollow=1, brightbloom=2, sunreign=3, ashwane=4})[newSeason] or 1
            state.season = newSeason
            table.insert(state.notifications, {
                text = "Season changed to " .. (SEASON_DISPLAY[state.season] or state.season) .. "!",
                color = {0.7, 0.8, 0.9},
                time = love.timer.getTime()
            })
        end
    end

    -- Update all pets (stats and visuals)
    for _, pet in ipairs(state.pets) do
        updatePetStats(pet, dt)
        updatePetVisuals(pet, dt)
    end

    -- Update eggs
    updateEggs(dt)

    -- Check for breeding (every few seconds)
    if not state.lastBreedCheck then state.lastBreedCheck = love.timer.getTime() end
    if love.timer.getTime() - state.lastBreedCheck > 10 then
        checkBreeding()
        state.lastBreedCheck = love.timer.getTime()
    end

    -- Update notifications (remove old ones)
    for i = #state.notifications, 1, -1 do
        if love.timer.getTime() - state.notifications[i].time > 3 then
            table.remove(state.notifications, i)
        end
    end

    -- Update UI components
    UI.anim.update(dt)
    if state.ui.shopTabBar then
        state.ui.shopTabBar:update(dt)
    end
    for _, btn in ipairs(state.ui.habitatButtons) do
        if btn.update then btn:update(dt) end
    end
    -- Pet card buttons now drawn manually (no longer UI components)
    for _, card in ipairs(state.ui.shopCards) do
        if card.update then card:update(dt) end
    end
    for _, bar in ipairs(state.ui.progressBars) do
        if bar.update then bar:update(dt) end
    end

    -- Auto-save every 30 seconds
    if not state.lastAutoSave then state.lastAutoSave = love.timer.getTime() end
    if love.timer.getTime() - state.lastAutoSave > 30 then
        PetSim.save()
        state.lastAutoSave = love.timer.getTime()
    end
end

function PetSim.draw()
    local screenW, screenH = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()

    -- Clear tooltip state
    UIAssets.clearTooltip()

    -- Background image
    if not UIAssets.drawGameBackground("petsim", 1) then
        -- Fallback to solid color
        love.graphics.setColor(0.08, 0.1, 0.12)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    end

    -- Dark overlay for UI readability
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Apply day/night tint
    local dayProgress = state.timeOfDay / 24
    local nightAlpha = 0
    if state.timeOfDay < 6 or state.timeOfDay > 20 then
        -- Night time (8pm - 6am)
        nightAlpha = 0.3
    elseif state.timeOfDay < 8 or state.timeOfDay > 18 then
        -- Dawn/dusk
        nightAlpha = 0.15
    end
    if nightAlpha > 0 then
        love.graphics.setColor(0.1, 0.1, 0.2, nightAlpha)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    end

    -- Header bar
    love.graphics.setColor(0.12, 0.14, 0.18, 0.9)
    love.graphics.rectangle("fill", 0, 0, screenW, 60)

    love.graphics.setColor(0.9, 0.6, 0.8)
    love.graphics.setFont(getFont(24))
    love.graphics.print("Wilds Rancher and Tamer", 20, 15)

    -- Day/Night and Season display
    love.graphics.setFont(getFont(12))
    local timeIcon = state.timeOfDay >= 6 and state.timeOfDay < 20 and "☀️" or "🌙"
    local seasonIcons = {frosthollow = "❄️", brightbloom = "🌸", sunreign = "☀️", ashwane = "🍂"}
    local seasonIcon = seasonIcons[state.season] or "🌿"
    local hour = math.floor(state.timeOfDay)
    local timeStr = string.format("%02d:00", hour)
    local petMonth = getPetCalendarMonth(state.daysPassed)
    local petMonthName = PET_MONTHS[petMonth].name
    local petTotalDays = state.daysPassed % 365
    for i = 1, petMonth - 1 do petTotalDays = petTotalDays - PET_MONTHS[i].days end
    local petDayOfMonth = petTotalDays + 1
    local petYear = math.floor(state.daysPassed / 365) + 1
    love.graphics.setColor(0.8, 0.8, 0.6)
    love.graphics.print(timeIcon .. " " .. timeStr .. "  " .. seasonIcon .. " " .. petMonthName .. " " .. petDayOfMonth .. ", Year " .. petYear, 20, 40)

    -- Coins with tooltip
    love.graphics.setFont(getFont(16))
    UIAssets.drawCurrencyWithTooltip("coins", PlayerData.coins, screenW - 150, 20, 20)

    -- Eggs indicator
    if #state.eggs > 0 then
        love.graphics.setColor(0.9, 0.8, 0.5)
        love.graphics.print("🥚 " .. #state.eggs .. " eggs", screenW - 280, 20)
    end

    -- Tab buttons
    local tabs = {
        {id = "habitat", name = "Habitat", icon = "[H]"},
        {id = "pets", name = "My Pets", icon = "[P]"},
        {id = "eggs", name = "Nest", icon = "[E]"},
        {id = "shop", name = "Shop", icon = "[S]"},
    }
    local tabW = 100
    local tabStartX = screenW / 2 - (#tabs * (tabW + 10)) / 2

    for i, tab in ipairs(tabs) do
        local tabX = tabStartX + (i - 1) * (tabW + 10)
        local isActive = state.viewMode == tab.id
        local hover = mx >= tabX and mx <= tabX + tabW and my >= 65 and my <= 95

        if isActive then
            love.graphics.setColor(0.4, 0.5, 0.6)
        elseif hover then
            love.graphics.setColor(0.25, 0.3, 0.4)
        else
            love.graphics.setColor(0.15, 0.18, 0.25)
        end
        love.graphics.rectangle("fill", tabX, 65, tabW, 30, 5, 5)

        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(13))
        love.graphics.printf(tab.icon .. " " .. tab.name, tabX, 72, tabW, "center")
    end

    -- Content area
    local contentY = 110
    local contentH = screenH - contentY - 60

    if state.viewMode == "habitat" then
        drawHabitatView(screenW, screenH, contentY, contentH, mx, my)
    elseif state.viewMode == "pets" then
        drawPetsView(screenW, screenH, contentY, contentH, mx, my)
    elseif state.viewMode == "eggs" then
        drawEggsView(screenW, screenH, contentY, contentH, mx, my)
    elseif state.viewMode == "shop" then
        drawShopView(screenW, screenH, contentY, contentH, mx, my)
    elseif state.viewMode == "details" then
        drawPetDetails(screenW, screenH, contentY, contentH, mx, my)
    end

    -- Notifications
    for i, notif in ipairs(state.notifications) do
        local notifY = screenH - 100 - (i - 1) * 40
        local alpha = 1 - (love.timer.getTime() - notif.time) / 3

        love.graphics.setColor(0.1, 0.1, 0.15, alpha * 0.9)
        love.graphics.rectangle("fill", screenW / 2 - 150, notifY, 300, 35, 8, 8)

        love.graphics.setColor(notif.color[1], notif.color[2], notif.color[3], alpha)
        love.graphics.setFont(getFont(14))
        love.graphics.printf(notif.text, screenW / 2 - 150, notifY + 10, 300, "center")
    end

    -- Back button
    local backHover = mx >= 20 and mx <= 100 and my >= screenH - 50 and my <= screenH - 15
    love.graphics.setColor(backHover and {0.5, 0.3, 0.3} or {0.3, 0.2, 0.2})
    love.graphics.rectangle("fill", 20, screenH - 50, 80, 35, 6, 6)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(13))
    love.graphics.printf("Back", 20, screenH - 42, 80, "center")

    -- Draw currency tooltips
    UIAssets.drawTooltip()
end

-- Draw the habitat view with animated pets
function drawHabitatView(screenW, screenH, contentY, contentH, mx, my)
    -- Habitat bounds (no green box - background image shows through)
    local hx, hy = state.habitatX, state.habitatY
    local hw, hh = state.habitatW, state.habitatH

    -- Draw decorations (food bowls, toys)
    -- Food bowl
    love.graphics.setColor(0.5, 0.35, 0.2)
    love.graphics.ellipse("fill", hx + 80, hy + hh - 50, 30, 15)
    love.graphics.setColor(0.6, 0.45, 0.3)
    love.graphics.ellipse("fill", hx + 80, hy + hh - 55, 25, 10)
    love.graphics.setFont(getFont(10))
    love.graphics.setColor(1, 0.9, 0.7)
    love.graphics.print("Food", hx + 64, hy + hh - 62)

    -- Water bowl
    love.graphics.setColor(0.3, 0.4, 0.5)
    love.graphics.ellipse("fill", hx + 160, hy + hh - 50, 25, 12)
    love.graphics.setColor(0.4, 0.6, 0.9)
    love.graphics.ellipse("fill", hx + 160, hy + hh - 53, 20, 8)
    love.graphics.setColor(0.7, 0.9, 1)
    love.graphics.print("Water", hx + 143, hy + hh - 62)

    -- Toy area
    love.graphics.setFont(getFont(10))
    love.graphics.setColor(0.9, 0.8, 0.3)
    love.graphics.print("Toys", hx + hw - 95, hy + hh - 55)
    love.graphics.setColor(0.6, 0.5, 0.7)
    love.graphics.rectangle("fill", hx + hw - 80, hy + hh - 50, 20, 15, 3, 3)

    -- Bed/sleeping area
    love.graphics.setColor(0.4, 0.3, 0.5, 0.6)
    love.graphics.ellipse("fill", hx + hw - 80, hy + 60, 50, 30)
    love.graphics.setColor(0.5, 0.4, 0.6, 0.8)
    love.graphics.ellipse("fill", hx + hw - 80, hy + 55, 40, 20)
    love.graphics.setFont(getFont(10))
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Bed", hx + hw - 92, hy + 45)

    -- No pets message
    if #state.pets == 0 then
        love.graphics.setColor(0.6, 0.6, 0.7)
        love.graphics.setFont(getFont(18))
        love.graphics.printf("Your habitat is empty!\nVisit the shop to adopt a pet.", hx, hy + hh / 2 - 30, hw, "center")

        -- Quick shop button (manual draw - click handled at line ~2448)
        local shopBtnW = 150
        local shopBtnX = hx + hw / 2 - shopBtnW / 2
        local shopBtnY = hy + hh / 2 + 40

        -- Draw button manually
        love.graphics.setColor(0.90, 0.65, 0.20, 1)
        love.graphics.rectangle("fill", shopBtnX, shopBtnY, shopBtnW, 45, 8, 8)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(getFont(16))
        love.graphics.printf("Visit Shop", shopBtnX, shopBtnY + 12, shopBtnW, "center")
        return
    end

    -- Draw each pet
    for _, pet in ipairs(state.pets) do
        local species = getSpecies(pet.speciesId)
        local mood, moodColor, moodText = getPetMood(pet)

        -- Make sure pet has visual properties
        if not pet.x then initPetVisuals(pet) end

        local px, py = pet.x, pet.y + (pet.bobOffset or 0)

        -- Shadow
        love.graphics.setColor(0, 0, 0, 0.2)
        love.graphics.ellipse("fill", px, py + 40, 30, 10)

        -- Try to draw pet portrait
        local portrait = nil
        if species then
            -- Get portrait based on evolution stage
            local stage = pet.evolutionStage or 1
            if species.evolutionPortraits and species.evolutionPortraits[stage] then
                portrait = UIAssets.getCharacter(species.evolutionPortraits[stage])
            elseif species.portrait then
                portrait = UIAssets.getCharacter(species.portrait)
            end
        end

        if portrait then
            love.graphics.setColor(1, 1, 1)
            local imgW, imgH = portrait:getDimensions()
            local maxSize = 70
            local scale = maxSize / math.max(imgW, imgH)
            local drawX = px - (imgW * scale) / 2
            local drawY = py - (imgH * scale) / 2 - 10
            love.graphics.draw(portrait, drawX, drawY, 0, scale, scale)
        else
            -- Fallback to colored circle with pet name
            local species = getSpecies(pet.speciesId)
            love.graphics.setColor(species.color[1], species.color[2], species.color[3])
            love.graphics.circle("fill", px, py, 25)
            love.graphics.setColor(0, 0, 0, 0.3)
            love.graphics.circle("line", px, py, 25)
            love.graphics.setFont(getFont(10))
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(pet.name:sub(1, 1), px - 15, py - 5, 30, "center")
        end

        -- Activity indicator
        local activityInfo = PET_ACTIVITIES[pet.activity]
        if activityInfo and activityInfo.text_label then
            love.graphics.setFont(getFont(9))
            love.graphics.setColor(0.9, 0.9, 0.3)
            love.graphics.print(activityInfo.text_label, px + 25, py - 30)
        end

        -- Emote bubble (mood indicator)
        if pet.showEmote then
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.setFont(getFont(10))
            local emoteY = py - 50 - math.sin(love.timer.getTime() * 5) * 3
            -- Convert emote to text
            local emoteText = pet.showEmote == "❤️" and "Happy" or pet.showEmote == "😴" and "Sleepy" or pet.showEmote == "😋" and "Hungry" or pet.showEmote == "😢" and "Sad" or "..."
            love.graphics.print(emoteText, px - 10, emoteY)
        end

        -- Sleeping Zzz
        if pet.isSleeping then
            love.graphics.setFont(getFont(12))
            love.graphics.setColor(0.6, 0.7, 1)
            local zzY = py - 45 - math.sin(love.timer.getTime() * 2) * 5
            love.graphics.print("zzz", px + 25, zzY)
        end

        -- Name tag (show on hover)
        local petHover = math.abs(mx - px) < 35 and math.abs(my - py) < 35
        if petHover then
            -- Name background
            local nameW = #pet.name * 8 + 20
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.rectangle("fill", px - nameW / 2, py + 30, nameW, 22, 5, 5)

            -- Name text
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(getFont(12))
            love.graphics.printf(pet.name, px - nameW / 2, py + 35, nameW, "center")

            -- Stats mini-bars using UI components
            local barY = py + 55
            local barW = 40
            local barH = 4

            -- Hunger bar
            local hungerBar = UI.ProgressBar.new({
                x = px - barW / 2,
                y = barY,
                w = barW,
                h = barH,
                value = pet.hunger / 100,
                colorOverride = {0.9, 0.6, 0.2}
            })
            hungerBar:draw()

            -- Happiness bar
            local happyBar = UI.ProgressBar.new({
                x = px - barW / 2,
                y = barY + 6,
                w = barW,
                h = barH,
                value = pet.happiness / 100,
                colorOverride = {0.9, 0.3, 0.6}
            })
            happyBar:draw()

            -- Energy bar
            local energyBar = UI.ProgressBar.new({
                x = px - barW / 2,
                y = barY + 12,
                w = barW,
                h = barH,
                value = pet.energy / 100,
                colorOverride = {0.3, 0.7, 0.9}
            })
            energyBar:draw()
        end
    end

    -- Quick action buttons at bottom using UI components
    local btnY = screenH - 90
    local btnW = 80
    local btnH = 35
    local btnSpacing = 15
    local totalBtnW = 3 * btnW + 2 * btnSpacing
    local btnStartX = screenW / 2 - totalBtnW / 2

    -- Create/update habitat buttons
    state.ui.habitatButtons = {}

    local feedBtn = UI.Button.new({
        x = btnStartX,
        y = btnY,
        w = btnW,
        h = btnH,
        text = "Feed All",
        variant = "primary",
        onClick = function()
            feedAllPets()
        end
    })
    feedBtn:update(0)
    feedBtn:draw()
    table.insert(state.ui.habitatButtons, feedBtn)

    local playBtn = UI.Button.new({
        x = btnStartX + btnW + btnSpacing,
        y = btnY,
        w = btnW,
        h = btnH,
        text = "Play All",
        variant = "success",
        onClick = function()
            playWithAllPets()
        end
    })
    playBtn:update(0)
    playBtn:draw()
    table.insert(state.ui.habitatButtons, playBtn)

    local sleepBtn = UI.Button.new({
        x = btnStartX + 2 * (btnW + btnSpacing),
        y = btnY,
        w = btnW,
        h = btnH,
        text = "Rest All",
        variant = "ghost",
        onClick = function()
            sleepAllPets()
        end
    })
    sleepBtn:update(0)
    sleepBtn:draw()
    table.insert(state.ui.habitatButtons, sleepBtn)
end

function drawPetsView(screenW, screenH, contentY, contentH, mx, my)
    if #state.pets == 0 then
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.setFont(getFont(18))
        love.graphics.printf("No pets yet!\nVisit the shop to adopt one.", 0, contentY + 100, screenW, "center")

        -- Quick shop button (manual draw - click handled at line ~2494)
        local shopBtnW = 150
        local shopBtnX = screenW / 2 - shopBtnW / 2
        local shopBtnY = contentY + 200

        -- Draw button manually
        love.graphics.setColor(0.90, 0.65, 0.20, 1)
        love.graphics.rectangle("fill", shopBtnX, shopBtnY, shopBtnW, 45, 8, 8)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setFont(getFont(16))
        love.graphics.printf("Visit Shop", shopBtnX, shopBtnY + 12, shopBtnW, "center")
        return
    end

    -- Pet cards
    local cardW = 220
    local cardH = 280
    local cols = math.floor((screenW - 40) / (cardW + 20))
    local startX = (screenW - cols * (cardW + 20) + 20) / 2

    for i, pet in ipairs(state.pets) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local cardX = startX + col * (cardW + 20)
        local cardY = contentY + 10 + row * (cardH + 15) - state.petScroll

        if cardY + cardH >= contentY and cardY <= contentY + contentH then
            local species = getSpecies(pet.speciesId)
            local hover = mx >= cardX and mx <= cardX + cardW and my >= cardY and my <= cardY + cardH
            local mood, moodColor, moodText = getPetMood(pet)

            -- Card background
            if hover then
                love.graphics.setColor(species.color[1] * 0.4, species.color[2] * 0.4, species.color[3] * 0.4)
            else
                love.graphics.setColor(species.color[1] * 0.2, species.color[2] * 0.2, species.color[3] * 0.2)
            end
            love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 12, 12)

            -- Border
            love.graphics.setColor(species.color)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", cardX, cardY, cardW, cardH, 12, 12)
            love.graphics.setLineWidth(1)

            -- Pet portrait (or emoji fallback)
            local portrait = nil
            local stage = pet.evolutionStage or 1
            if species.evolutionPortraits and species.evolutionPortraits[stage] then
                portrait = UIAssets.getCharacter(species.evolutionPortraits[stage])
            elseif species.portrait then
                portrait = UIAssets.getCharacter(species.portrait)
            end

            if portrait then
                love.graphics.setColor(1, 1, 1)
                local imgW, imgH = portrait:getDimensions()
                local maxSize = 65
                local scale = maxSize / math.max(imgW, imgH)
                local drawX = cardX + (cardW - imgW * scale) / 2
                love.graphics.draw(portrait, drawX, cardY + 10, 0, scale, scale)
            else
                -- Colored circle fallback
                love.graphics.setColor(species.color[1], species.color[2], species.color[3])
                love.graphics.circle("fill", cardX + cardW/2, cardY + 40, 30)
                love.graphics.setColor(0, 0, 0, 0.3)
                love.graphics.circle("line", cardX + cardW/2, cardY + 40, 30)
            end

            -- Sleeping indicator
            if pet.isSleeping then
                love.graphics.setFont(getFont(12))
                love.graphics.setColor(0.6, 0.7, 1)
                love.graphics.printf("zzz", cardX + cardW - 45, cardY + 10, 35, "center")
            end

            -- Gender symbol
            local genderSymbol = pet.gender == "male" and "♂" or "♀"
            local genderColor = pet.gender == "male" and {0.4, 0.6, 0.9} or {0.9, 0.5, 0.6}
            love.graphics.setFont(getFont(14))
            love.graphics.setColor(genderColor)
            love.graphics.print(genderSymbol, cardX + 10, cardY + 10)

            -- Element icon
            local element = getElement(pet.element or species.element)
            if element then
                love.graphics.setColor(element.color)
                love.graphics.setFont(getFont(12))
                love.graphics.print(element.icon or "?", cardX + cardW - 25, cardY + 10)
            end

            -- Name
            love.graphics.setFont(getFont(16))
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf(pet.name, cardX, cardY + 80, cardW, "center")

            -- Species type
            love.graphics.setFont(getFont(10))
            love.graphics.setColor(0.7, 0.7, 0.8)
            love.graphics.printf(species.name .. " (" .. (element and element.name or "???") .. ")", cardX, cardY + 98, cardW, "center")

            -- Mood
            love.graphics.setFont(getFont(11))
            love.graphics.setColor(moodColor)
            love.graphics.printf(mood, cardX, cardY + 113, cardW, "center")

            -- Stats bars using UI components
            local barW = cardW - 50
            local barH = 12
            local barX = cardX + 35
            local barY = cardY + 130

            -- Hunger bar with label
            love.graphics.setColor(0.9, 0.6, 0.2)
            love.graphics.setFont(getFont(8))
            love.graphics.print("Food", barX - 28, barY + 1)
            local hungerBar = UI.ProgressBar.new({
                x = barX,
                y = barY,
                w = barW,
                h = barH,
                value = pet.hunger / 100,
                colorOverride = {0.9, 0.6, 0.2}
            })
            hungerBar:draw()

            -- Happiness bar with label
            love.graphics.setColor(0.9, 0.3, 0.6)
            love.graphics.print("Joy", barX - 22, barY + 21)
            local happyBar = UI.ProgressBar.new({
                x = barX,
                y = barY + 20,
                w = barW,
                h = barH,
                value = pet.happiness / 100,
                colorOverride = {0.9, 0.3, 0.6}
            })
            happyBar:draw()

            -- Energy bar with label
            love.graphics.setColor(0.3, 0.7, 0.9)
            love.graphics.print("Enrg", barX - 26, barY + 41)
            local energyBar = UI.ProgressBar.new({
                x = barX,
                y = barY + 40,
                w = barW,
                h = barH,
                value = pet.energy / 100,
                colorOverride = {0.3, 0.7, 0.9}
            })
            energyBar:draw()

            -- Age
            love.graphics.setColor(0.6, 0.6, 0.7)
            love.graphics.setFont(getFont(10))
            love.graphics.printf("Age: " .. math.floor(pet.age) .. " days", cardX, cardY + 200, cardW, "center")

            -- Evolution stage
            love.graphics.setColor(0.8, 0.7, 0.9)
            love.graphics.printf("Stage " .. pet.evolutionStage .. "/3", cardX, cardY + 215, cardW, "center")

            -- Quick action buttons (manual draw - clicks handled in mousepressed)
            local btnW = 60
            local btnH = 30
            local btnY = cardY + cardH - 45

            -- Feed button (primary color)
            local feedBtnX = cardX + 20
            love.graphics.setColor(0.90, 0.65, 0.20, 1)
            love.graphics.rectangle("fill", feedBtnX, btnY, btnW, btnH, 8, 8)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.setFont(getFont(14))
            love.graphics.printf("Feed", feedBtnX, btnY + 8, btnW, "center")

            -- Play button (success color)
            local playBtnX = cardX + cardW / 2 - btnW / 2
            love.graphics.setColor(0.30, 0.80, 0.40, 1)
            love.graphics.rectangle("fill", playBtnX, btnY, btnW, btnH, 8, 8)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf("Play", playBtnX, btnY + 8, btnW, "center")

            -- Rest button (ghost color - border only)
            local restBtnX = cardX + cardW - btnW - 20
            love.graphics.setColor(0.25, 0.30, 0.40, 1)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", restBtnX, btnY, btnW, btnH, 8, 8)
            love.graphics.setLineWidth(1)
            love.graphics.setColor(0.92, 0.92, 0.92, 1)
            love.graphics.printf("Rest", restBtnX, btnY + 8, btnW, "center")
        end
    end

    -- Draw action panel at bottom for selected pet
    if state.selectedPetAction then
        local pet = nil
        for _, p in ipairs(state.pets) do
            if p.id == state.selectedPetAction then
                pet = p
                break
            end
        end

        if pet then
            local actionY = screenH - 70
            love.graphics.setColor(0.1, 0.12, 0.15, 0.95)
            love.graphics.rectangle("fill", 20, actionY, screenW - 40, 60, 8, 8)

            local species = getSpecies(pet.speciesId)

            -- Pet name
            love.graphics.setColor(0.9, 0.9, 0.8)
            love.graphics.setFont(getFont(14))
            love.graphics.print(pet.name .. " - " .. species.name, 40, actionY + 8)

            -- Action buttons
            local btnX = 200
            local btnW = 100

            -- Equip as Pet button
            local equipPetHover = mx >= btnX and mx <= btnX + btnW and my >= actionY + 10 and my <= actionY + 45
            love.graphics.setColor(equipPetHover and {0.4, 0.5, 0.6} or {0.25, 0.35, 0.45})
            love.graphics.rectangle("fill", btnX, actionY + 10, btnW, 35, 5, 5)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(getFont(11))
            love.graphics.printf("Equip Pet", btnX, actionY + 20, btnW, "center")

            btnX = btnX + btnW + 15

            -- Equip as Mount button (only if mountable)
            if species.mountType and pet.evolutionStage >= 2 then
                local equipMountHover = mx >= btnX and mx <= btnX + btnW and my >= actionY + 10 and my <= actionY + 45
                love.graphics.setColor(equipMountHover and {0.5, 0.4, 0.3} or {0.4, 0.3, 0.2})
                love.graphics.rectangle("fill", btnX, actionY + 10, btnW, 35, 5, 5)
                love.graphics.setColor(1, 1, 1)
                love.graphics.printf("Equip Mount", btnX, actionY + 20, btnW, "center")
                btnX = btnX + btnW + 15
            end

            -- Sell button
            local sellValue = math.floor(species.basePrice * (0.3 + pet.evolutionStage * 0.2))
            local sellHover = mx >= btnX and mx <= btnX + btnW and my >= actionY + 10 and my <= actionY + 45
            love.graphics.setColor(sellHover and {0.6, 0.4, 0.3} or {0.5, 0.3, 0.2})
            love.graphics.rectangle("fill", btnX, actionY + 10, btnW, 35, 5, 5)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf("Sell $" .. sellValue, btnX, actionY + 20, btnW, "center")

            -- Close action panel button
            local closeX = screenW - 100
            local closeHover = mx >= closeX and mx <= closeX + 60 and my >= actionY + 10 and my <= actionY + 45
            love.graphics.setColor(closeHover and {0.6, 0.3, 0.3} or {0.4, 0.2, 0.2})
            love.graphics.rectangle("fill", closeX, actionY + 10, 60, 35, 5, 5)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf("Close", closeX, actionY + 20, 60, "center")
        else
            state.selectedPetAction = nil
        end
    end

    -- Scrollbar for pets list
    local rows = math.ceil(#state.pets / cols)
    local totalPetHeight = rows * (cardH + 15)
    local maxPetScroll = math.max(0, totalPetHeight - contentH)
    if maxPetScroll > 0 then
        local scrollbarX = screenW - 20
        local scrollbarH = contentH
        local thumbH = math.max(30, scrollbarH * (contentH / totalPetHeight))
        local thumbY = contentY + (state.petScroll / maxPetScroll) * (scrollbarH - thumbH)
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", scrollbarX, contentY, 8, scrollbarH, 4, 4)
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.rectangle("fill", scrollbarX, thumbY, 8, thumbH, 4, 4)
    end
end

-- Draw eggs/nest view
function drawEggsView(screenW, screenH, contentY, contentH, mx, my)
    -- Nest background
    love.graphics.setColor(0.15, 0.12, 0.1, 0.9)
    love.graphics.rectangle("fill", 30, contentY, screenW - 60, contentH, 10, 10)

    -- Title
    love.graphics.setColor(0.9, 0.8, 0.5)
    love.graphics.setFont(getFont(20))
    love.graphics.print("🪹 Nesting Area", 50, contentY + 15)

    love.graphics.setFont(getFont(12))
    love.graphics.setColor(0.7, 0.7, 0.6)
    love.graphics.print("Eggs from breeding pairs will appear here. Wait for them to hatch!", 50, contentY + 45)

    if #state.eggs == 0 then
        -- No eggs message
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.setFont(getFont(16))
        love.graphics.printf("No eggs yet...\n\nHave adult pets (evolution stage 2+) of the same species\nwith different genders to start breeding!", 50, contentY + 100, screenW - 100, "center")
    else
        -- Draw eggs
        local eggW = 120
        local eggH = 150
        local eggsPerRow = math.floor((screenW - 100) / (eggW + 20))
        local startX = 50
        local startY = contentY + 80

        for i, egg in ipairs(state.eggs) do
            local col = (i - 1) % eggsPerRow
            local row = math.floor((i - 1) / eggsPerRow)
            local x = startX + col * (eggW + 20)
            local y = startY + row * (eggH + 20)

            local species = getSpecies(egg.speciesId)
            local element = getElement(egg.element)
            local hover = mx >= x and mx <= x + eggW and my >= y and my <= y + eggH

            -- Egg background
            love.graphics.setColor(hover and {0.25, 0.22, 0.2} or {0.2, 0.18, 0.15})
            love.graphics.rectangle("fill", x, y, eggW, eggH, 8, 8)

            -- Egg shape
            local eggCenterX = x + eggW / 2
            local eggCenterY = y + 50
            local eggRX = 30
            local eggRY = 40

            -- Egg color based on element
            love.graphics.setColor(element.color[1], element.color[2], element.color[3], 0.8)
            love.graphics.ellipse("fill", eggCenterX, eggCenterY, eggRX, eggRY)
            love.graphics.setColor(1, 1, 1, 0.3)
            love.graphics.ellipse("fill", eggCenterX - 8, eggCenterY - 15, 8, 12)

            -- Species name
            love.graphics.setColor(0.9, 0.9, 0.8)
            love.graphics.setFont(getFont(11))
            love.graphics.printf(species.name .. " Egg", x, y + 95, eggW, "center")

            -- Progress bar using UI component
            local barX = x + 10
            local barY = y + 115
            local barW = eggW - 20
            local barH = 12
            local progressBar = UI.ProgressBar.new({
                x = barX,
                y = barY,
                w = barW,
                h = barH,
                value = egg.progress / 100,
                label = math.floor(egg.progress) .. "%",
                colorOverride = {0.4, 0.7, 0.4}
            })
            progressBar:draw()

            -- Parents
            love.graphics.setColor(0.6, 0.6, 0.5)
            love.graphics.setFont(getFont(9))
            love.graphics.printf("♂" .. (egg.parentMale or "?") .. " + ♀" .. (egg.parentFemale or "?"), x, y + 132, eggW, "center")
        end
    end
end

function drawShopView(screenW, screenH, contentY, contentH, mx, my)
    -- Shop tabs using UI component
    if state.ui.shopTabBar then
        state.ui.shopTabBar.activeTab = state.shopTab
        state.ui.shopTabBar:draw()
    end

    local shopY = contentY + 50

    if state.shopTab == "pets" then
        -- Pet shop
        local cardW = 180
        local cardH = 200
        local cols = math.floor((screenW - 40) / (cardW + 15))
        local startX = (screenW - cols * (cardW + 15) + 15) / 2

        for i, species in ipairs(PET_SPECIES) do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            local cardX = startX + col * (cardW + 15)
            local cardY = shopY + row * (cardH + 10)

            local hover = mx >= cardX and mx <= cardX + cardW and my >= cardY and my <= cardY + cardH
            local canAfford = PlayerData.coins >= species.basePrice

            -- Card
            if canAfford then
                love.graphics.setColor(hover and {0.25, 0.3, 0.4} or {0.15, 0.18, 0.25})
            else
                love.graphics.setColor(0.12, 0.12, 0.15)
            end
            love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 10, 10)

            -- Border
            love.graphics.setColor(species.color[1], species.color[2], species.color[3], canAfford and 1 or 0.3)
            love.graphics.rectangle("line", cardX, cardY, cardW, cardH, 10, 10)

            -- Pet portrait (or emoji fallback)
            local portrait = nil
            if species.portrait then
                portrait = UIAssets.getCharacter(species.portrait)
            end

            if portrait then
                love.graphics.setColor(1, 1, 1, canAfford and 1 or 0.4)
                local imgW, imgH = portrait:getDimensions()
                local maxSize = 55
                local scale = maxSize / math.max(imgW, imgH)
                local drawX = cardX + (cardW - imgW * scale) / 2
                love.graphics.draw(portrait, drawX, cardY + 10, 0, scale, scale)
            else
                -- Colored circle fallback for species without portrait
                love.graphics.setColor(species.color[1], species.color[2], species.color[3], canAfford and 1 or 0.4)
                love.graphics.circle("fill", cardX + cardW/2, cardY + 35, 25)
                love.graphics.setColor(0, 0, 0, 0.3)
                love.graphics.circle("line", cardX + cardW/2, cardY + 35, 25)
            end

            -- Name
            love.graphics.setFont(getFont(14))
            love.graphics.setColor(1, 1, 1, canAfford and 1 or 0.5)
            love.graphics.printf(species.name, cardX, cardY + 70, cardW, "center")

            -- Description
            love.graphics.setFont(getFont(10))
            love.graphics.setColor(0.6, 0.6, 0.7)
            love.graphics.printf(species.desc, cardX + 10, cardY + 95, cardW - 20, "center")

            -- Price
            love.graphics.setColor(canAfford and {1, 0.9, 0.3} or {0.6, 0.4, 0.4})
            love.graphics.setFont(getFont(14))
            love.graphics.printf(species.basePrice .. " coins", cardX, cardY + 150, cardW, "center")

            -- Adopt button
            if hover and canAfford then
                love.graphics.setColor(0.3, 0.5, 0.3)
                love.graphics.rectangle("fill", cardX + 30, cardY + cardH - 35, cardW - 60, 28, 5, 5)
                love.graphics.setColor(1, 1, 1)
                love.graphics.setFont(getFont(12))
                love.graphics.printf("Adopt!", cardX + 30, cardY + cardH - 28, cardW - 60, "center")
            end
        end

    elseif state.shopTab == "food" then
        -- Food shop
        local itemW = 250
        local itemH = 60

        for i, food in ipairs(FOODS) do
            local itemY = shopY + (i - 1) * (itemH + 10)
            local hover = mx >= 30 and mx <= 30 + itemW and my >= itemY and my <= itemY + itemH
            local canAfford = PlayerData.coins >= food.price

            love.graphics.setColor(canAfford and (hover and {0.25, 0.3, 0.4} or {0.15, 0.18, 0.25}) or {0.12, 0.12, 0.15})
            love.graphics.rectangle("fill", 30, itemY, itemW, itemH, 8, 8)

            -- Food icon or fallback to colored square
            local iconDrawn = false
            if food.icon then
                local foodIcon = UIAssets.getIconByName(food.icon)
                if foodIcon then
                    love.graphics.setColor(1, 1, 1, canAfford and 1 or 0.4)
                    local imgW, imgH = foodIcon:getDimensions()
                    local iconSize = 28
                    local scale = iconSize / math.max(imgW, imgH)
                    love.graphics.draw(foodIcon, 45, itemY + 13, 0, scale, scale)
                    iconDrawn = true
                end
            end
            if not iconDrawn then
                love.graphics.setColor(food.color[1], food.color[2], food.color[3], canAfford and 1 or 0.4)
                love.graphics.rectangle("fill", 45, itemY + 15, 25, 25, 5, 5)
            end

            love.graphics.setFont(getFont(14))
            love.graphics.setColor(1, 1, 1, canAfford and 1 or 0.4)
            love.graphics.print(food.name, 85, itemY + 12)

            love.graphics.setFont(getFont(10))
            love.graphics.setColor(0.6, 0.6, 0.7)
            love.graphics.print("Hunger +" .. food.hunger .. (food.happiness and ", Happy +" .. food.happiness or ""), 85, itemY + 32)

            -- Price
            love.graphics.setColor(canAfford and {1, 0.9, 0.3} or {0.6, 0.4, 0.4})
            love.graphics.setFont(getFont(12))
            love.graphics.printf(food.price .. "g", 30, itemY + 22, itemW - 15, "right")

            -- Inventory count
            local owned = 0
            for _, inv in ipairs(state.inventory.food) do
                if inv.id == food.id then owned = inv.count break end
            end
            if owned > 0 then
                love.graphics.setColor(0.5, 0.8, 0.5)
                love.graphics.setFont(getFont(10))
                love.graphics.print("Owned: " .. owned, 30 + itemW + 15, itemY + 22)
            end
        end

    elseif state.shopTab == "toys" then
        -- Toys shop
        local itemW = 250
        local itemH = 60

        for i, toy in ipairs(TOYS) do
            local itemY = shopY + (i - 1) * (itemH + 10)
            local hover = mx >= 30 and mx <= 30 + itemW and my >= itemY and my <= itemY + itemH
            local canAfford = PlayerData.coins >= toy.price

            love.graphics.setColor(canAfford and (hover and {0.25, 0.3, 0.4} or {0.15, 0.18, 0.25}) or {0.12, 0.12, 0.15})
            love.graphics.rectangle("fill", 30, itemY, itemW, itemH, 8, 8)

            -- Toy icon or fallback to colored circle
            local iconDrawn = false
            if toy.icon then
                local toyIcon = UIAssets.getIconByName(toy.icon)
                if toyIcon then
                    love.graphics.setColor(1, 1, 1, canAfford and 1 or 0.4)
                    local imgW, imgH = toyIcon:getDimensions()
                    local iconSize = 24
                    local scale = iconSize / math.max(imgW, imgH)
                    love.graphics.draw(toyIcon, 45, itemY + 15, 0, scale, scale)
                    iconDrawn = true
                end
            end
            if not iconDrawn then
                love.graphics.setColor(toy.color[1], toy.color[2], toy.color[3], canAfford and 1 or 0.4)
                love.graphics.circle("fill", 57, itemY + 27, 12)
            end

            love.graphics.setFont(getFont(14))
            love.graphics.setColor(1, 1, 1, canAfford and 1 or 0.4)
            love.graphics.print(toy.name, 85, itemY + 12)

            love.graphics.setFont(getFont(10))
            love.graphics.setColor(0.6, 0.6, 0.7)
            love.graphics.print("Happy +" .. toy.happiness .. ", Energy " .. toy.energy, 85, itemY + 32)

            -- Price
            love.graphics.setColor(canAfford and {1, 0.9, 0.3} or {0.6, 0.4, 0.4})
            love.graphics.setFont(getFont(12))
            love.graphics.printf(toy.price .. "g", 30, itemY + 22, itemW - 15, "right")

            -- Inventory count
            local owned = 0
            for _, inv in ipairs(state.inventory.toys) do
                if inv.id == toy.id then owned = inv.count break end
            end
            if owned > 0 then
                love.graphics.setColor(0.5, 0.8, 0.5)
                love.graphics.setFont(getFont(10))
                love.graphics.print("Owned: " .. owned, 30 + itemW + 15, itemY + 22)
            end
        end
    end
end

function drawPetDetails(screenW, screenH, contentY, contentH, mx, my)
    -- Detailed pet view (for future expansion)
end

-- Helper functions for UI button callbacks
local function feedAllPets()
    local fedAny = false
    for _, pet in ipairs(state.pets) do
        for j, inv in ipairs(state.inventory.food) do
            if inv.count > 0 then
                for _, food in ipairs(FOODS) do
                    if food.id == inv.id then
                        feedPet(pet, food)
                        inv.count = inv.count - 1
                        if inv.count <= 0 then
                            table.remove(state.inventory.food, j)
                        end
                        pet.activity = "eating"
                        pet.activityTimer = 0
                        pet.showEmote = "😋"
                        pet.emoteTimer = 0
                        fedAny = true
                        break
                    end
                end
                if fedAny then break end
            end
        end
    end
    if fedAny then
        table.insert(state.notifications, {
            text = "Fed all pets!",
            color = {0.9, 0.7, 0.3},
            time = love.timer.getTime()
        })
    else
        table.insert(state.notifications, {
            text = "No food in inventory!",
            color = {0.9, 0.3, 0.3},
            time = love.timer.getTime()
        })
    end
end

local function playWithAllPets()
    for _, pet in ipairs(state.pets) do
        if not pet.isSleeping then
            pet.happiness = math.min(100, pet.happiness + 15)
            pet.energy = math.max(0, pet.energy - 10)
            pet.activity = "playing"
            pet.activityTimer = 0
            pet.showEmote = "🎉"
            pet.emoteTimer = 0
        end
    end
    table.insert(state.notifications, {
        text = "Playtime for everyone!",
        color = {0.9, 0.5, 0.8},
        time = love.timer.getTime()
    })
end

local function sleepAllPets()
    for _, pet in ipairs(state.pets) do
        if not pet.isSleeping then
            putToSleep(pet)
            pet.activity = "sleeping"
            pet.activityTimer = 0
        end
    end
    table.insert(state.notifications, {
        text = "All pets are resting...",
        color = {0.5, 0.5, 0.8},
        time = love.timer.getTime()
    })
end

local function feedPetById(petId)
    for _, pet in ipairs(state.pets) do
        if pet.id == petId then
            -- Find food in inventory
            for j, inv in ipairs(state.inventory.food) do
                if inv.count > 0 then
                    for _, food in ipairs(FOODS) do
                        if food.id == inv.id then
                            feedPet(pet, food)
                            inv.count = inv.count - 1
                            if inv.count <= 0 then
                                table.remove(state.inventory.food, j)
                            end
                            table.insert(state.notifications, {
                                text = pet.name .. " enjoyed the food!",
                                color = {0.9, 0.7, 0.3},
                                time = love.timer.getTime()
                            })
                            return
                        end
                    end
                end
            end
            table.insert(state.notifications, {
                text = "No food in inventory!",
                color = {0.9, 0.3, 0.3},
                time = love.timer.getTime()
            })
            return
        end
    end
end

local function playWithPetById(petId)
    for _, pet in ipairs(state.pets) do
        if pet.id == petId then
            -- Find toy in inventory
            for j, inv in ipairs(state.inventory.toys) do
                if inv.count > 0 then
                    for _, toy in ipairs(TOYS) do
                        if toy.id == inv.id then
                            local success, msg = playWithPet(pet, toy)
                            if success then
                                table.insert(state.notifications, {
                                    text = pet.name .. " had fun playing!",
                                    color = {0.9, 0.5, 0.8},
                                    time = love.timer.getTime()
                                })
                            else
                                table.insert(state.notifications, {
                                    text = msg,
                                    color = {0.9, 0.3, 0.3},
                                    time = love.timer.getTime()
                                })
                            end
                            return
                        end
                    end
                end
            end
            -- Play without toy (less effective)
            pet.happiness = math.min(100, pet.happiness + 10)
            pet.energy = math.max(0, pet.energy - 10)
            table.insert(state.notifications, {
                text = pet.name .. " played a little!",
                color = {0.7, 0.5, 0.8},
                time = love.timer.getTime()
            })
            return
        end
    end
end

local function toggleSleepById(petId)
    for _, pet in ipairs(state.pets) do
        if pet.id == petId then
            if pet.isSleeping then
                pet.isSleeping = false
                pet.activity = "idle"
                pet.activityTimer = 0
                table.insert(state.notifications, {
                    text = pet.name .. " woke up!",
                    color = {0.7, 0.7, 0.9},
                    time = love.timer.getTime()
                })
            else
                putToSleep(pet)
                pet.activity = "sleeping"
                pet.activityTimer = 0
                table.insert(state.notifications, {
                    text = pet.name .. " is now resting...",
                    color = {0.5, 0.5, 0.8},
                    time = love.timer.getTime()
                })
            end
            return
        end
    end
end

function PetSim.mousepressed(x, y, button)
    if button ~= 1 then return end

    local screenW, screenH = love.graphics.getDimensions()
    local contentY = 110
    local contentH = screenH - contentY - 60

    -- Handle UI component clicks
    if state.ui.shopTabBar and state.ui.shopTabBar:mousepressed(x, y, button) then
        return
    end
    for _, btn in ipairs(state.ui.habitatButtons) do
        if btn.mousepressed and btn:mousepressed(x, y, button) then
            return
        end
    end

    -- Back button
    if x >= 20 and x <= 100 and y >= screenH - 50 and y <= screenH - 15 then
        PetSim.save()
        local TextRPG = require("textrpg"); TextRPG.init(); GameState.current = "textrpg"
        return
    end

    -- Tab buttons
    local tabs = {"habitat", "pets", "eggs", "shop"}
    local tabW = 100
    local tabStartX = screenW / 2 - (#tabs * (tabW + 10)) / 2

    for i, tabId in ipairs(tabs) do
        local tabX = tabStartX + (i - 1) * (tabW + 10)
        if x >= tabX and x <= tabX + tabW and y >= 65 and y <= 95 then
            state.viewMode = tabId
            state.selectedPetAction = nil  -- Clear action panel when changing tabs
            return
        end
    end

    -- Handle action panel (at bottom when a pet is selected)
    if state.selectedPetAction and state.viewMode == "pets" then
        local actionY = screenH - 70
        local pet = nil
        local petIndex = nil
        for i, p in ipairs(state.pets) do
            if p.id == state.selectedPetAction then
                pet = p
                petIndex = i
                break
            end
        end

        if pet then
            local Backpack = require("backpack")
            local species = getSpecies(pet.speciesId)
            local btnX = 200
            local btnW = 100

            -- Equip as Pet button
            if x >= btnX and x <= btnX + btnW and y >= actionY + 10 and y <= actionY + 45 then
                Backpack.equipPet(pet)
                table.insert(state.notifications, {
                    text = pet.name .. " is now your companion!",
                    color = {0.5, 0.8, 0.9},
                    time = love.timer.getTime()
                })
                state.selectedPetAction = nil
                return
            end
            btnX = btnX + btnW + 15

            -- Equip as Mount button (only if mountable)
            if species.mountType and pet.evolutionStage >= 2 then
                if x >= btnX and x <= btnX + btnW and y >= actionY + 10 and y <= actionY + 45 then
                    local success, msg = Backpack.equipMount(pet)
                    if success then
                        table.insert(state.notifications, {
                            text = pet.name .. " is now your mount!",
                            color = {0.7, 0.6, 0.5},
                            time = love.timer.getTime()
                        })
                    else
                        table.insert(state.notifications, {
                            text = msg or "Cannot mount this creature",
                            color = {0.9, 0.5, 0.3},
                            time = love.timer.getTime()
                        })
                    end
                    state.selectedPetAction = nil
                    return
                end
                btnX = btnX + btnW + 15
            end

            -- Sell button
            local sellValue = math.floor(species.basePrice * (0.3 + pet.evolutionStage * 0.2))
            if x >= btnX and x <= btnX + btnW and y >= actionY + 10 and y <= actionY + 45 then
                PlayerData.coins = PlayerData.coins + sellValue
                table.remove(state.pets, petIndex)
                table.insert(state.notifications, {
                    text = "Sold " .. pet.name .. " for $" .. sellValue,
                    color = {0.9, 0.8, 0.3},
                    time = love.timer.getTime()
                })
                state.selectedPetAction = nil
                PetSim.save()
                return
            end

            -- Close button
            local closeX = screenW - 100
            if x >= closeX and x <= closeX + 60 and y >= actionY + 10 and y <= actionY + 45 then
                state.selectedPetAction = nil
                return
            end
        end
    end

    -- Habitat view interactions
    if state.viewMode == "habitat" then
        local hx, hy = state.habitatX, state.habitatY
        local hw, hh = state.habitatW, state.habitatH

        -- Shop button when no pets
        if #state.pets == 0 then
            local shopBtnW = 150
            local shopBtnX = hx + hw / 2 - shopBtnW / 2
            local shopBtnY = hy + hh / 2 + 40
            if x >= shopBtnX and x <= shopBtnX + shopBtnW and y >= shopBtnY and y <= shopBtnY + 45 then
                state.viewMode = "shop"
                return
            end
        end

        -- Quick action buttons handled by UI components now

        -- Click on individual pets
        for _, pet in ipairs(state.pets) do
            if pet.x and math.abs(x - pet.x) < 35 and math.abs(y - pet.y) < 35 then
                -- Pet the pet!
                pet.happiness = math.min(100, pet.happiness + 5)
                pet.showEmote = "💕"
                pet.emoteTimer = 0

                -- Wake up sleeping pets
                if pet.isSleeping then
                    pet.isSleeping = false
                    pet.activity = "happy"
                    pet.activityTimer = 0
                    table.insert(state.notifications, {
                        text = pet.name .. " woke up!",
                        color = {0.7, 0.7, 0.9},
                        time = love.timer.getTime()
                    })
                else
                    table.insert(state.notifications, {
                        text = "Petted " .. pet.name .. "!",
                        color = {0.9, 0.6, 0.8},
                        time = love.timer.getTime()
                    })
                end
                return
            end
        end
        return
    end

    -- Pets view interactions
    if state.viewMode == "pets" then
        if #state.pets == 0 then
            -- Shop button when no pets
            local shopBtnW = 150
            local shopBtnX = screenW / 2 - shopBtnW / 2
            local shopBtnY = contentY + 200
            if x >= shopBtnX and x <= shopBtnX + shopBtnW and y >= shopBtnY and y <= shopBtnY + 45 then
                state.viewMode = "shop"
                return
            end
        else
            -- Pet card actions
            local cardW = 220
            local cardH = 280
            local cols = math.floor((screenW - 40) / (cardW + 20))
            local startX = (screenW - cols * (cardW + 20) + 20) / 2

            -- Pet card button clicks and card selection
            for i, pet in ipairs(state.pets) do
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)
                local cardX = startX + col * (cardW + 20)
                local cardY = contentY + 10 + row * (cardH + 15) - state.petScroll

                -- Check if clicking within card bounds
                if x >= cardX and x <= cardX + cardW and y >= cardY and y <= cardY + cardH then
                    -- Button dimensions (must match drawPetsView)
                    local btnW = 60
                    local btnH = 30
                    local btnY = cardY + cardH - 45

                    -- Feed button
                    local feedBtnX = cardX + 20
                    if x >= feedBtnX and x <= feedBtnX + btnW and y >= btnY and y <= btnY + btnH then
                        feedPetById(pet.id)
                        return
                    end

                    -- Play button
                    local playBtnX = cardX + cardW / 2 - btnW / 2
                    if x >= playBtnX and x <= playBtnX + btnW and y >= btnY and y <= btnY + btnH then
                        playWithPetById(pet.id)
                        return
                    end

                    -- Rest button
                    local restBtnX = cardX + cardW - btnW - 20
                    if x >= restBtnX and x <= restBtnX + btnW and y >= btnY and y <= btnY + btnH then
                        toggleSleepById(pet.id)
                        return
                    end

                    -- Click on card (not buttons) to select for action panel
                    if state.selectedPetAction == pet.id then
                        state.selectedPetAction = nil  -- Deselect
                    else
                        state.selectedPetAction = pet.id  -- Select
                    end
                    return
                end
            end
        end

    elseif state.viewMode == "shop" then
        -- Shop tabs handled by UI.TabBar component

        local shopY = contentY + 50

        if state.shopTab == "pets" then
            -- Buy pet
            local cardW = 180
            local cardH = 200
            local cols = math.floor((screenW - 40) / (cardW + 15))
            local startX = (screenW - cols * (cardW + 15) + 15) / 2

            for i, species in ipairs(PET_SPECIES) do
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)
                local cardX = startX + col * (cardW + 15)
                local cardY = shopY + row * (cardH + 10)

                if x >= cardX and x <= cardX + cardW and y >= cardY and y <= cardY + cardH then
                    if PlayerData.coins >= species.basePrice then
                        PlayerData.coins = PlayerData.coins - species.basePrice
                        local newPet = createPet(species.id)
                        table.insert(state.pets, newPet)
                        table.insert(state.notifications, {
                            text = "Welcome " .. newPet.name .. "!",
                            color = {0.3, 0.9, 0.5},
                            time = love.timer.getTime()
                        })
                        PetSim.save()
                    end
                    return
                end
            end

        elseif state.shopTab == "food" then
            local itemW = 250
            local itemH = 60

            for i, food in ipairs(FOODS) do
                local itemY = shopY + (i - 1) * (itemH + 10)
                if x >= 30 and x <= 30 + itemW and y >= itemY and y <= itemY + itemH then
                    if PlayerData.coins >= food.price then
                        PlayerData.coins = PlayerData.coins - food.price
                        -- Add to inventory
                        local found = false
                        for _, inv in ipairs(state.inventory.food) do
                            if inv.id == food.id then
                                inv.count = inv.count + 1
                                found = true
                                break
                            end
                        end
                        if not found then
                            table.insert(state.inventory.food, {id = food.id, count = 1})
                        end
                        table.insert(state.notifications, {
                            text = "Bought " .. food.name,
                            color = {0.3, 0.8, 0.5},
                            time = love.timer.getTime()
                        })
                        PetSim.save()
                    end
                    return
                end
            end

        elseif state.shopTab == "toys" then
            local itemW = 250
            local itemH = 60

            for i, toy in ipairs(TOYS) do
                local itemY = shopY + (i - 1) * (itemH + 10)
                if x >= 30 and x <= 30 + itemW and y >= itemY and y <= itemY + itemH then
                    if PlayerData.coins >= toy.price then
                        PlayerData.coins = PlayerData.coins - toy.price
                        -- Add to inventory
                        local found = false
                        for _, inv in ipairs(state.inventory.toys) do
                            if inv.id == toy.id then
                                inv.count = inv.count + 1
                                found = true
                                break
                            end
                        end
                        if not found then
                            table.insert(state.inventory.toys, {id = toy.id, count = 1})
                        end
                        table.insert(state.notifications, {
                            text = "Bought " .. toy.name,
                            color = {0.3, 0.8, 0.5},
                            time = love.timer.getTime()
                        })
                        PetSim.save()
                    end
                    return
                end
            end
        end
    end
end

function PetSim.wheelmoved(wx, wy)
    if state.viewMode == "pets" then
        state.petScroll = math.max(0, state.petScroll - wy * 40)
    elseif state.viewMode == "shop" then
        state.shopScroll = math.max(0, state.shopScroll - wy * 40)
    end
end

function PetSim.mousereleased(x, y, button)
    if button ~= 1 then return end

    -- Handle UI component releases
    if state.ui.shopTabBar and state.ui.shopTabBar.mousereleased then
        state.ui.shopTabBar:mousereleased(x, y, button)
    end
    for _, btn in ipairs(state.ui.habitatButtons) do
        if btn.mousereleased then
            btn:mousereleased(x, y, button)
        end
    end
end

function PetSim.keypressed(key)
    if key == "escape" then
        PetSim.save()
        local TextRPG = require("textrpg"); TextRPG.init(); GameState.current = "textrpg"
    end
end

-- UI region resolver for interactive tutorials
function PetSim.getUIRegion(regionId)
    local screenW, screenH = love.graphics.getDimensions()
    local contentY = 110

    -- Calculate shop pet card positions (adoption panel)
    local cardW = 180
    local cardH = 200
    local cols = math.floor((screenW - 40) / (cardW + 15))
    local shopStartX = (screenW - cols * (cardW + 15) + 15) / 2
    local shopY = contentY + 40

    -- Calculate pet list card positions (pet stats)
    local petCardW = 220
    local petCardH = 280
    local petCols = math.floor((screenW - 40) / (petCardW + 20))
    local petStartX = (screenW - petCols * (petCardW + 20) + 20) / 2

    -- Calculate training/action button positions
    local btnY = screenH - 90
    local btnW = 80
    local btnH = 35
    local btnSpacing = 15
    local totalBtnW = 3 * btnW + 2 * btnSpacing
    local btnStartX = screenW / 2 - totalBtnW / 2

    local regions = {
        -- Pet shop adoption panel (first pet card position)
        adoption_panel = {x = shopStartX, y = shopY, w = cardW, h = cardH},

        -- Pet stats display (first pet card in pet list)
        pet_stats = {x = petStartX, y = contentY + 10, w = petCardW, h = petCardH},

        -- Training/action area (quick action buttons at bottom of habitat)
        training_area = {x = btnStartX, y = btnY, w = totalBtnW, h = btnH},
    }

    return regions[regionId]
end

-- Export vehicle functions
PetSim.getVehicle = getVehicle
PetSim.getAllVehicles = getAllVehicles
PetSim.getVehiclesByType = getVehiclesByType
PetSim.VEHICLES = VEHICLES

return PetSim
