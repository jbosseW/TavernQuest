-- Character Customizer - LPC Character Layer System
-- Manages character appearance with multiple sprite layers

local ok, SpriteManager = pcall(require, "spritemanager")
if not ok then SpriteManager = nil end

local CharacterCustomizer = {}

-- Local helper: check if table contains value
local function tableContains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then return true end
    end
    return false
end

-- Race definitions with base body sprites
CharacterCustomizer.RACES = {
    human = {
        name = "Human",
        bodyTypes = {"male", "female"},
        spritePrefix = "human"
    },
    elf = {
        name = "Elf",
        bodyTypes = {"male", "female"},
        spritePrefix = "elf",
        features = {"pointed_ears"}
    },
    dwarf = {
        name = "Dwarf",
        bodyTypes = {"male", "female"},
        spritePrefix = "dwarf"
    },
    orc = {
        name = "Orc",
        bodyTypes = {"male", "female"},
        spritePrefix = "orc",
        features = {"tusks"}
    },
    gnome = {
        name = "Gnome",
        bodyTypes = {"male", "female"},
        spritePrefix = "gnome",
        features = {"big_ears", "pointed_hat"}
    },
    goblin = {
        name = "Goblin",
        bodyTypes = {"male", "female"},
        spritePrefix = "goblin",
        features = {"pointed_ears", "sharp_teeth"}
    },
    catfolk = {
        name = "Catfolk",
        bodyTypes = {"male", "female"},
        spritePrefix = "catfolk",
        features = {"cat_ears", "tail"}
    },
    lizardfolk = {
        name = "Lizardfolk",
        bodyTypes = {"male", "female"},
        spritePrefix = "lizard"
    },
    skeleton = {
        name = "Skeleton",
        bodyTypes = {"universal"},
        spritePrefix = "skeleton"
    }
}

-- Hair styles (maps to sprite files)
CharacterCustomizer.HAIR_STYLES = {
    "none",
    "plain",
    "ponytail",
    "messy",
    "mohawk",
    "long",
    "bangs",
    "shoulder",
    "pixie",
    "princess",
    "bald"
}

-- Equipment slots
CharacterCustomizer.EQUIPMENT_SLOTS = {
    weapon = {name = "Weapon", layer = "weapon"},
    shield = {name = "Shield", layer = "shield"},
    helmet = {name = "Helmet", layer = "head"},
    torso = {name = "Body Armor", layer = "torso"},
    legs = {name = "Leg Armor", layer = "legs"},
    feet = {name = "Boots", layer = "feet"},
    hands = {name = "Gloves", layer = "hands"},
    back = {name = "Cape/Wings", layer = "back"}
}

-- Initialize customizer
function CharacterCustomizer.init()
    CharacterCustomizer.templates = {}
    CharacterCustomizer.loadedAssets = {}
end

-- Create a character template (appearance data)
-- @param race: Race ID (human, elf, dwarf, etc.)
-- @param bodyType: "male" or "female"
-- @param options: Table with customization options
-- @return: Character appearance template
function CharacterCustomizer.createTemplate(race, bodyType, options)
    options = options or {}

    local raceData = CharacterCustomizer.RACES[race]
    if not raceData then
        race = "human"
        raceData = CharacterCustomizer.RACES.human
    end

    local template = {
        race = race,
        bodyType = bodyType or "male",

        -- Appearance
        skinTone = options.skinTone or 1,  -- 1-6 for different skin colors
        hairStyle = options.hairStyle or "plain",
        hairColor = options.hairColor or {0.3, 0.2, 0.1},  -- RGB
        eyeColor = options.eyeColor or {0.4, 0.6, 1.0},

        -- Equipment (sprite layer names)
        equipment = {
            weapon = options.weapon or nil,
            shield = options.shield or nil,
            helmet = options.helmet or nil,
            torso = options.torso or "cloth_shirt",
            legs = options.legs or "cloth_pants",
            feet = options.feet or "boots_brown",
            hands = options.hands or nil,
            back = options.back or nil
        },

        -- Facial features
        facial = options.facial or nil,  -- beard, mustache, etc.

        -- Special features
        features = raceData.features or {}
    }

    return template
end

-- Convert a template into sprite layer array
-- @param template: Character template
-- @return: Array of sprite layer names
function CharacterCustomizer.buildLayerArray(template)
    local layers = {}

    -- 1. Base body
    local bodySprite = string.format("%s_%s_body", template.race, template.bodyType)
    table.insert(layers, bodySprite)

    -- 2. Eyes (if customizable)
    -- table.insert(layers, "eyes_default")

    -- 3. Ears and racial features
    if tableContains(template.features, "pointed_ears") then
        table.insert(layers, "ears_elf")
    end
    if tableContains(template.features, "big_ears") then
        table.insert(layers, "ears_gnome")
    end
    if tableContains(template.features, "cat_ears") then
        table.insert(layers, "ears_cat")
    end
    if tableContains(template.features, "tail") then
        table.insert(layers, "tail_cat")
    end
    if tableContains(template.features, "tusks") then
        table.insert(layers, "tusks_orc")
    end
    if tableContains(template.features, "sharp_teeth") then
        table.insert(layers, "teeth_goblin")
    end
    if tableContains(template.features, "pointed_hat") then
        table.insert(layers, "hat_gnome")
    end

    -- 4. Facial features (beard, mustache)
    if template.facial then
        table.insert(layers, template.facial)
    end

    -- 5. Hair
    if template.hairStyle and template.hairStyle ~= "none" and template.hairStyle ~= "bald" then
        table.insert(layers, "hair_" .. template.hairStyle)
    end

    -- 6. Equipment layers (in order)
    local equipmentOrder = {"feet", "legs", "hands", "torso", "back", "helmet", "weapon", "shield"}

    for _, slot in ipairs(equipmentOrder) do
        local equipSprite = template.equipment[slot]
        if equipSprite then
            table.insert(layers, equipSprite)
        end
    end

    return layers
end

-- Create a sprite character from a template
-- @param template: Character template
-- @param x, y: Starting position
-- @return: SpriteManager character instance
function CharacterCustomizer.createCharacterFromTemplate(template, x, y)
    local layers = CharacterCustomizer.buildLayerArray(template)

    -- Ensure all layers are loaded
    for _, layerName in ipairs(layers) do
        CharacterCustomizer.ensureLayerLoaded(layerName)
    end

    if not SpriteManager then
        return {layers = layers, x = x, y = y, template = template}
    end
    local character = SpriteManager.createCharacter(layers, x, y)
    character.template = template  -- Store template for later modification

    return character
end

-- Ensure a sprite layer is loaded
-- @param layerName: Name of the sprite layer
function CharacterCustomizer.ensureLayerLoaded(layerName)
    if not SpriteManager then return false end
    -- Check if already loaded
    if SpriteManager.getSpriteInfo(layerName) then
        return true
    end

    -- Try to load from assets directory
    local spritePath = string.format("assets/sprites/lpc/%s.png", layerName)

    local spriteData = SpriteManager.loadSpriteSheet(layerName, spritePath)

    if spriteData then
        CharacterCustomizer.loadedAssets[layerName] = true
        return true
    else
        -- Fallback: try alternate paths
        local alternatePath = string.format("sprites/%s.png", layerName)
        spriteData = SpriteManager.loadSpriteSheet(layerName, alternatePath)

        if spriteData then
            CharacterCustomizer.loadedAssets[layerName] = true
            return true
        end
    end

    print("Warning: Could not load sprite layer: " .. layerName)
    return false
end

-- Update equipment on a character
-- @param character: SpriteManager character instance
-- @param slot: Equipment slot ("weapon", "helmet", etc.)
-- @param spriteName: New sprite name (or nil to remove)
function CharacterCustomizer.setEquipment(character, slot, spriteName)
    if not character.template then
        print("Warning: Character has no template")
        return
    end

    -- Update template
    character.template.equipment[slot] = spriteName

    -- Rebuild layer array
    local newLayers = CharacterCustomizer.buildLayerArray(character.template)

    -- Ensure new layers are loaded
    for _, layerName in ipairs(newLayers) do
        CharacterCustomizer.ensureLayerLoaded(layerName)
    end

    -- Update character layers
    character.layers = newLayers
end

-- Change hair style
function CharacterCustomizer.setHairStyle(character, hairStyle)
    if not character.template then
        return
    end

    character.template.hairStyle = hairStyle

    -- Rebuild layers
    local newLayers = CharacterCustomizer.buildLayerArray(character.template)
    character.layers = newLayers
end

-- Serialize template to save data
function CharacterCustomizer.serializeTemplate(template)
    return {
        race = template.race,
        bodyType = template.bodyType,
        skinTone = template.skinTone,
        hairStyle = template.hairStyle,
        hairColor = template.hairColor,
        eyeColor = template.eyeColor,
        equipment = template.equipment,
        facial = template.facial
    }
end

-- Deserialize template from save data
function CharacterCustomizer.deserializeTemplate(data)
    local opts = {
        skinTone = data.skinTone,
        hairStyle = data.hairStyle,
        hairColor = data.hairColor,
        eyeColor = data.eyeColor,
        facial = data.facial,
    }
    -- Unpack saved equipment into individual slot options
    if data.equipment then
        for slot, value in pairs(data.equipment) do
            opts[slot] = value
        end
    end
    return CharacterCustomizer.createTemplate(data.race, data.bodyType, opts)
end

-- Get default template for a race
function CharacterCustomizer.getDefaultTemplate(race, bodyType)
    return CharacterCustomizer.createTemplate(race, bodyType, {})
end

-- Preload sprite assets for a race
function CharacterCustomizer.preloadRace(race, bodyType)
    local template = CharacterCustomizer.getDefaultTemplate(race, bodyType)
    local layers = CharacterCustomizer.buildLayerArray(template)

    for _, layerName in ipairs(layers) do
        CharacterCustomizer.ensureLayerLoaded(layerName)
    end
end

-- Random character generator (for NPCs)
function CharacterCustomizer.generateRandom(race)
    race = race or "human"

    local raceData = CharacterCustomizer.RACES[race]
    local bodyTypes = raceData.bodyTypes

    local bodyType = bodyTypes[love.math.random(#bodyTypes)]

    local torsoChoices = {"cloth_shirt", "leather_armor", "chainmail"}
    local legsChoices = {"cloth_pants", "leather_pants"}
    local weaponChoices = {"sword", "axe", "dagger", "staff"}
    local facialChoices = {"beard_full", "beard_goatee", "mustache"}

    local options = {
        skinTone = love.math.random(1, 6),
        hairStyle = CharacterCustomizer.HAIR_STYLES[love.math.random(#CharacterCustomizer.HAIR_STYLES)],
        hairColor = {
            love.math.random() * 0.5,
            love.math.random() * 0.3,
            love.math.random() * 0.2
        },
        torso = torsoChoices[love.math.random(#torsoChoices)],
        legs = legsChoices[love.math.random(#legsChoices)]
    }

    -- Random weapon (50% chance)
    if love.math.random() > 0.5 then
        options.weapon = weaponChoices[love.math.random(#weaponChoices)]
    end

    -- Random facial hair (male only, 30% chance)
    if bodyType == "male" and love.math.random() > 0.7 then
        options.facial = facialChoices[love.math.random(#facialChoices)]
    end

    return CharacterCustomizer.createTemplate(race, bodyType, options)
end

-- Helper: Check if table contains value (kept for backwards compatibility)
if not table.contains then
    table.contains = function(tbl, value)
        for _, v in ipairs(tbl) do
            if v == value then
                return true
            end
        end
        return false
    end
end

-- Create player character from PlayerData
function CharacterCustomizer.createPlayerCharacter(x, y)
    -- Check if PlayerData has a saved character template
    if PlayerData and PlayerData.characterAppearance then
        local template = CharacterCustomizer.deserializeTemplate(PlayerData.characterAppearance)
        return CharacterCustomizer.createCharacterFromTemplate(template, x, y)
    else
        -- Create default character
        local defaultTemplate = CharacterCustomizer.createTemplate("human", "male", {})

        -- Save to PlayerData
        if PlayerData then
            PlayerData.characterAppearance = CharacterCustomizer.serializeTemplate(defaultTemplate)
        end

        return CharacterCustomizer.createCharacterFromTemplate(defaultTemplate, x, y)
    end
end

-- Save character appearance to PlayerData
function CharacterCustomizer.saveToPlayerData(character)
    if not character.template then
        return
    end

    if PlayerData then
        PlayerData.characterAppearance = CharacterCustomizer.serializeTemplate(character.template)
    end
end

return CharacterCustomizer
