-- Character Creator - Visual character customization screen
-- Allows players to customize their character appearance

local CharacterCreator = {}
local ok1, CharacterCustomizer = pcall(require, "charactercustomizer")
if not ok1 then CharacterCustomizer = nil end
local ok2, SpriteManager = pcall(require, "spritemanager")
if not ok2 then SpriteManager = nil end

-- Font cache to avoid per-frame allocation
local FontCache = require("fontcache")
local function getFont(size)
    return FontCache.get(size)
end

-- Category names in display order
local CATEGORIES = {"race", "gender", "hair", "torso", "legs", "weapon"}

-- Creator state
local creatorState = {
    template = nil,
    previewSprite = nil,

    -- Current selections
    selectedRace = "human",
    selectedGender = "male",
    selectedHairStyle = 1,
    selectedTorso = 1,
    selectedLegs = 1,
    selectedWeapon = 1,

    -- Currently highlighted category (1-based index into CATEGORIES)
    selectedCategory = 1,

    -- Options
    races = {"human", "elf", "dwarf", "orc", "gnome", "goblin", "catfolk", "lizardfolk"},
    genders = {"male", "female"},
    hairStyles = {"none", "plain", "ponytail", "messy", "mohawk", "long", "bangs", "shoulder", "pixie", "princess", "bald"},
    torsos = {"cloth_shirt", "leather_armor", "chainmail", "plate_armor", "robe_blue", "robe_red"},
    legs = {"cloth_pants", "leather_pants", "chainmail_legs", "plate_legs", "robe_skirt"},
    weapons = {"none", "sword", "axe", "dagger", "staff", "bow", "spear"},

    -- UI
    previewX = 400,
    previewY = 300,
    animationTimer = 0
}

-- Initialize character creator
function CharacterCreator.init()
    -- Create initial template
    CharacterCreator.updateTemplate()
end

-- Update template based on current selections
function CharacterCreator.updateTemplate()
    if not CharacterCustomizer then return end

    local cs = creatorState

    local weapon = cs.weapons[cs.selectedWeapon]
    if weapon == "none" then weapon = nil end

    local hairStyle = cs.hairStyles[cs.selectedHairStyle]

    cs.template = CharacterCustomizer.createTemplate(
        cs.selectedRace,
        cs.selectedGender,
        {
            hairStyle = hairStyle,
            hairColor = {0.3, 0.2, 0.1},  -- Default brown
            torso = cs.torsos[cs.selectedTorso],
            legs = cs.legs[cs.selectedLegs],
            weapon = weapon
        }
    )

    -- Create preview sprite
    cs.previewSprite = CharacterCustomizer.createCharacterFromTemplate(
        cs.template,
        cs.previewX,
        cs.previewY
    )

    -- Set to idle walk animation
    if cs.previewSprite then
        cs.previewSprite.animation = "walk"
        cs.previewSprite.direction = "down"
        cs.previewSprite.playing = true
    end
end

-- Update
function CharacterCreator.update(dt)
    local cs = creatorState

    -- Update preview sprite animation
    if cs.previewSprite and SpriteManager then
        SpriteManager.updateCharacter(cs.previewSprite, dt)

        -- Rotate through directions for preview
        cs.animationTimer = cs.animationTimer + dt
        if cs.animationTimer > 2 then
            cs.animationTimer = 0
            local dirs = {"down", "left", "up", "right"}
            local currentIndex = 1
            for i, dir in ipairs(dirs) do
                if cs.previewSprite.direction == dir then
                    currentIndex = i
                    break
                end
            end
            local nextIndex = (currentIndex % #dirs) + 1
            cs.previewSprite.direction = dirs[nextIndex]
        end
    end
end

-- Draw
function CharacterCreator.draw()
    local cs = creatorState
    local w, h = love.graphics.getDimensions()

    -- Background
    love.graphics.setColor(0.1, 0.12, 0.15)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- Title
    love.graphics.setColor(0.9, 0.8, 0.5)
    love.graphics.setFont(getFont(24))
    love.graphics.printf("Character Creator", 0, 20, w, "center")

    -- Preview sprite
    if cs.previewSprite then
        -- Preview background
        love.graphics.setColor(0.15, 0.17, 0.2)
        love.graphics.rectangle("fill", cs.previewX - 80, cs.previewY - 80, 160, 160, 8, 8)

        -- Draw sprite (scaled up for preview)
        if SpriteManager then
            cs.previewSprite.scale = 2
            SpriteManager.drawCharacter(cs.previewSprite)
            cs.previewSprite.scale = 1
        end

        -- Direction indicator
        love.graphics.setColor(0.6, 0.6, 0.7)
        love.graphics.setFont(getFont(12))
        love.graphics.printf("Facing: " .. cs.previewSprite.direction, cs.previewX - 80, cs.previewY + 90, 160, "center")
    end

    -- Customization options (left side)
    local optionX = 50
    local optionY = 150
    local optionSpacing = 60

    love.graphics.setFont(getFont(14))

    -- Build display data for each category
    local categoryDisplay = {
        {label = "Race:",   value = cs.selectedRace:upper()},
        {label = "Gender:", value = cs.selectedGender:upper()},
        {label = "Hair:",   value = cs.hairStyles[cs.selectedHairStyle]:upper()},
        {label = "Torso:",  value = cs.torsos[cs.selectedTorso]:upper()},
        {label = "Legs:",   value = cs.legs[cs.selectedLegs]:upper()},
        {label = "Weapon:", value = cs.weapons[cs.selectedWeapon]:upper()},
    }

    for i, cat in ipairs(categoryDisplay) do
        local isSelected = (i == cs.selectedCategory)

        -- Draw selection highlight
        if isSelected then
            love.graphics.setColor(0.25, 0.25, 0.35)
            love.graphics.rectangle("fill", optionX - 8, optionY - 4, 320, 28, 4, 4)
            love.graphics.setColor(0.9, 0.8, 0.3)
            love.graphics.print(">", optionX - 8, optionY)
        end

        -- Label
        if isSelected then
            love.graphics.setColor(1.0, 1.0, 1.0)
        else
            love.graphics.setColor(0.8, 0.8, 0.9)
        end
        love.graphics.print(cat.label, optionX + 6, optionY)

        -- Value with arrows
        if isSelected then
            love.graphics.setColor(1.0, 0.85, 0.4)
        else
            love.graphics.setColor(0.9, 0.7, 0.4)
        end
        love.graphics.print("< " .. cat.value .. " >", optionX + 100, optionY)

        optionY = optionY + optionSpacing
    end

    -- Instructions (bottom)
    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Use ARROW KEYS or WASD to navigate | LEFT/RIGHT to change | ENTER to confirm | ESC to cancel", 0, h - 40, w, "center")

    -- Confirm button
    local btnW, btnH = 200, 40
    local btnX, btnY = w/2 - btnW/2, h - 100
    love.graphics.setColor(0.3, 0.6, 0.3)
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(16))
    love.graphics.printf("Create Character", btnX, btnY + 10, btnW, "center")
end

-- Helper: cycle a string value within a list (forward or backward)
-- Returns the new value after cycling
local function cycleStringInList(list, currentValue, direction)
    local currentIndex = 1
    for i, v in ipairs(list) do
        if v == currentValue then
            currentIndex = i
            break
        end
    end
    currentIndex = currentIndex + direction
    if currentIndex < 1 then currentIndex = #list end
    if currentIndex > #list then currentIndex = 1 end
    return list[currentIndex]
end

-- Helper: cycle a numeric index within a list (forward or backward)
-- Returns the new index after cycling
local function cycleIndex(listLength, currentIndex, direction)
    local newIndex = currentIndex + direction
    if newIndex < 1 then newIndex = listLength end
    if newIndex > listLength then newIndex = 1 end
    return newIndex
end

-- Key pressed
function CharacterCreator.keypressed(key)
    local cs = creatorState

    if key == "escape" then
        -- Cancel character creation
        return "cancel"
    elseif key == "return" then
        -- Confirm and save
        if CharacterCustomizer then
            CharacterCustomizer.saveToPlayerData(cs.previewSprite)
        end
        return "confirm"
    end

    -- Up/Down: navigate between categories
    if key == "up" or key == "w" then
        cs.selectedCategory = cs.selectedCategory - 1
        if cs.selectedCategory < 1 then
            cs.selectedCategory = #CATEGORIES
        end
        return
    elseif key == "down" or key == "s" then
        cs.selectedCategory = cs.selectedCategory + 1
        if cs.selectedCategory > #CATEGORIES then
            cs.selectedCategory = 1
        end
        return
    end

    -- Left/Right: cycle the currently selected category
    local direction = 0
    if key == "left" or key == "a" then
        direction = -1
    elseif key == "right" or key == "d" then
        direction = 1
    end

    if direction ~= 0 then
        local category = CATEGORIES[cs.selectedCategory]

        if category == "race" then
            cs.selectedRace = cycleStringInList(cs.races, cs.selectedRace, direction)
        elseif category == "gender" then
            cs.selectedGender = cycleStringInList(cs.genders, cs.selectedGender, direction)
        elseif category == "hair" then
            cs.selectedHairStyle = cycleIndex(#cs.hairStyles, cs.selectedHairStyle, direction)
        elseif category == "torso" then
            cs.selectedTorso = cycleIndex(#cs.torsos, cs.selectedTorso, direction)
        elseif category == "legs" then
            cs.selectedLegs = cycleIndex(#cs.legs, cs.selectedLegs, direction)
        elseif category == "weapon" then
            cs.selectedWeapon = cycleIndex(#cs.weapons, cs.selectedWeapon, direction)
        end

        CharacterCreator.updateTemplate()
    end
end

-- Get final template
function CharacterCreator.getTemplate()
    return creatorState.template
end

-- Reset to defaults
function CharacterCreator.reset()
    creatorState.selectedRace = "human"
    creatorState.selectedGender = "male"
    creatorState.selectedHairStyle = 2  -- plain
    creatorState.selectedTorso = 1      -- cloth_shirt
    creatorState.selectedLegs = 1       -- cloth_pants
    creatorState.selectedWeapon = 1     -- none
    creatorState.selectedCategory = 1   -- race
    CharacterCreator.updateTemplate()
end

return CharacterCreator
