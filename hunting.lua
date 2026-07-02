-- Hunting Game Mode - Track and hunt wild game!
-- A hunting minigame with moving animals, arrow physics, and loot

local Hunting = {}
local UI = require("ui")
local UIAssets = require("uiassets")
local Progression = require("progression")
local Backpack = require("backpack")
local Employees = require("employees")
local EmployeeUI = require("employee_ui")
local UpgradeSystem = require("upgradesystem")
local Tutorials = require("tutorials")
local InteractiveTutorial = require("interactivetutorial")

-- Game state
local state = {
    active = false,
    currentRegion = "forest",
    windSpeed = 0,
    windDirection = 0,
    noiseLevel = 0,
    trophies = {},
    huntingLevel = 1,
    experience = 0,

    -- Active animals on screen
    animals = {},
    maxAnimals = 3,
    spawnTimer = 0,
    spawnInterval = 3,

    -- OPTIMIZATION: Entity pooling for animals (reduce GC pressure)
    animalPool = {
        active = {},      -- Currently spawned animals (same as state.animals)
        inactive = {},    -- Recycled animals ready for reuse
    },

    -- Arrow/projectile state
    arrow = nil,  -- {x, y, vx, vy, rotation, active}
    shootCooldown = 0,

    -- UI state
    currentBgIndex = 1,
    showShop = false,
    showEmployeePanel = false,
    showUpgradePanel = false,
    notification = nil,
    notificationTimer = 0,

    -- UI components
    shopPanel = nil,
    shopButtons = {},
    employeePanel = nil,
    employeeButtons = {},
    upgradePanel = nil,
    navButtons = {},

    -- Employee and upgrade tracking
    employees = {},
    hiringPool = {},
    upgrades = {},
    currentBuild = nil,
    employeeProduction = 0,

    -- Time tracking
    lastSaveTime = 0,
    daysPassed = 0,
    season = "frosthollow",
}

-- Background images for hunting mode
local huntBackgrounds = {"camp", "hunt1", "hunt2", "hunt3"}
local huntBgNames = {"Camp", "Forest Hunt", "Mountain Hunt", "Night Hunt"}

-- Cached images
local animalImages = {}
local arrowImage = nil
local lootImages = {}

-- Animal types with sprites and loot
local ANIMALS = {
    -- Small game (forest)
    {id = "rabbit", name = "Rabbit", value = 20, difficulty = 1, speed = 80, awareness = 3,
     regions = {"forest", "plains"}, sprite = "assets/characters/Animals/Monsters_22.PNG",
     trophy = false, loot = {{id = "raw_meat", chance = 0.9}, {id = "small_hide", chance = 0.7}}},
    {id = "pheasant", name = "Pheasant", value = 30, difficulty = 2, speed = 100, awareness = 4,
     regions = {"forest", "plains"}, sprite = "assets/characters/Animals/Bird_animal.PNG",
     trophy = false, loot = {{id = "raw_meat", chance = 0.8}, {id = "feathers", chance = 0.9}}},
    {id = "fox", name = "Fox", value = 50, difficulty = 3, speed = 90, awareness = 6,
     regions = {"forest"}, sprite = "assets/characters/Animals/Wolf_animal.PNG",
     trophy = false, loot = {{id = "raw_meat", chance = 0.7}, {id = "fine_fur", chance = 0.8}}},

    -- Medium game
    {id = "deer", name = "Deer", value = 100, difficulty = 4, speed = 85, awareness = 7,
     regions = {"forest", "mountains"}, sprite = "assets/characters/Animals/Horse_animal.PNG",
     trophy = true, loot = {{id = "raw_meat", chance = 1.0, qty = 3}, {id = "deer_hide", chance = 0.9}, {id = "antlers", chance = 0.4}}},
    {id = "boar", name = "Wild Boar", value = 120, difficulty = 5, speed = 70, awareness = 5,
     regions = {"forest"}, sprite = "assets/characters/Animals/Boar_animal.PNG",
     trophy = true, loot = {{id = "raw_meat", chance = 1.0, qty = 4}, {id = "boar_hide", chance = 0.85}, {id = "tusks", chance = 0.5}}},
    {id = "wolf", name = "Wolf", value = 150, difficulty = 6, speed = 95, awareness = 8,
     regions = {"forest", "mountains"}, sprite = "assets/characters/Animals/Wolf_animal.PNG",
     trophy = true, loot = {{id = "raw_meat", chance = 0.8, qty = 2}, {id = "wolf_pelt", chance = 0.9}, {id = "claws", chance = 0.6}}},

    -- Large game
    {id = "elk", name = "Elk", value = 200, difficulty = 6, speed = 75, awareness = 6,
     regions = {"mountains", "tundra"}, sprite = "assets/characters/Animals/Creatures_10_warhorse.PNG",
     trophy = true, loot = {{id = "raw_meat", chance = 1.0, qty = 5}, {id = "elk_hide", chance = 0.95}, {id = "antlers", chance = 0.7}}},
    {id = "bear", name = "Bear", value = 300, difficulty = 8, speed = 60, awareness = 7,
     regions = {"forest", "mountains"}, sprite = "assets/characters/Animals/Bear_animal.PNG",
     trophy = true, loot = {{id = "raw_meat", chance = 1.0, qty = 6}, {id = "bear_pelt", chance = 0.95}, {id = "claws", chance = 0.8}, {id = "bear_fat", chance = 0.6}}},

    -- Legendary
    {id = "white_stag", name = "White Stag", value = 1000, difficulty = 10, speed = 110, awareness = 10,
     regions = {"forest"}, sprite = "assets/characters/Animals/Creatures_10_warhorse.PNG",
     trophy = true, legendary = true, loot = {{id = "raw_meat", chance = 1.0, qty = 4}, {id = "legendary_hide", chance = 1.0}, {id = "mystical_antlers", chance = 1.0}}},
    {id = "great_bear", name = "Great Bear", value = 1500, difficulty = 10, speed = 55, awareness = 9,
     regions = {"mountains"}, sprite = "assets/characters/Animals/Bear_animal.PNG",
     trophy = true, legendary = true, loot = {{id = "raw_meat", chance = 1.0, qty = 10}, {id = "legendary_pelt", chance = 1.0}, {id = "great_claws", chance = 1.0}}},
}

-- Hunting regions
local REGIONS = {
    {id = "forest", name = "Whispering Woods", unlockLevel = 1, animalBonus = 1.0},
    {id = "plains", name = "Golden Plains", unlockLevel = 3, animalBonus = 1.1},
    {id = "mountains", name = "Frostpeak Mountains", unlockLevel = 5, animalBonus = 1.3},
    {id = "tundra", name = "Frozen Tundra", unlockLevel = 8, animalBonus = 1.5},
}

-- Loot item definitions (for backpack integration)
local LOOT_ITEMS = {
    {id = "raw_meat", name = "Raw Meat", icon = "assets/icons/resourcesandfood/FriedChickenLeg.PNG", sellValue = 8},
    {id = "small_hide", name = "Small Hide", icon = "assets/icons/resources/Res_68_cloth.PNG", sellValue = 10},
    {id = "fine_fur", name = "Fine Fur", icon = "assets/icons/resources/Res_68_cloth.PNG", sellValue = 30},
    {id = "feathers", name = "Feathers", icon = "assets/icons/loot/Feather.png", sellValue = 5},
    {id = "deer_hide", name = "Deer Hide", icon = "assets/icons/resources/Res_68_cloth.PNG", sellValue = 25},
    {id = "boar_hide", name = "Boar Hide", icon = "assets/icons/resources/Res_68_cloth.PNG", sellValue = 28},
    {id = "wolf_pelt", name = "Wolf Pelt", icon = "assets/icons/resources/Res_68_cloth.PNG", sellValue = 40},
    {id = "elk_hide", name = "Elk Hide", icon = "assets/icons/resources/Res_68_cloth.PNG", sellValue = 50},
    {id = "bear_pelt", name = "Bear Pelt", icon = "assets/icons/resources/Res_68_cloth.PNG", sellValue = 80},
    {id = "antlers", name = "Antlers", icon = "assets/icons/loot/Bone.png", sellValue = 50},
    {id = "tusks", name = "Tusks", icon = "assets/icons/loot/Bone.png", sellValue = 35},
    {id = "claws", name = "Claws", icon = "assets/icons/loot/Bone.png", sellValue = 25},
    {id = "bear_fat", name = "Bear Fat", icon = "assets/icons/loot/Bottle.png", sellValue = 30},
    {id = "legendary_hide", name = "Legendary Hide", icon = "assets/icons/resources/Res_69_scale.PNG", sellValue = 200},
    {id = "legendary_pelt", name = "Legendary Pelt", icon = "assets/icons/resources/Res_69_scale.PNG", sellValue = 300},
    {id = "mystical_antlers", name = "Mystical Antlers", icon = "assets/icons/loot/Bone.png", sellValue = 500},
    {id = "great_claws", name = "Great Claws", icon = "assets/icons/loot/Bone.png", sellValue = 400},
    {id = "arrows", name = "Arrows", icon = "assets/icons/weapons/Arrow_01.PNG", sellValue = 2},
}

-- Shop items
local SHOP_ITEMS = {
    {id = "arrows", name = "Arrows (10)", cost = 20, qty = 10, desc = "Basic hunting arrows"},
    {id = "arrows_steel", name = "Steel Arrows (10)", cost = 50, qty = 10, desc = "Stronger arrows, +10% damage"},
    {id = "bait", name = "Animal Bait", cost = 30, qty = 1, desc = "Attracts animals faster"},
}

-- Load images
local function loadImages()
    -- Load arrow image
    local success
    success, arrowImage = pcall(function()
        return love.graphics.newImage("assets/icons/weapons/Arrow_01.PNG")
    end)
    if not success then arrowImage = nil end

    -- Load animal images
    for _, animal in ipairs(ANIMALS) do
        if animal.sprite and not animalImages[animal.id] then
            success, animalImages[animal.id] = pcall(function()
                return love.graphics.newImage(animal.sprite)
            end)
            if not success then animalImages[animal.id] = nil end
        end
    end

    -- Load loot images
    for _, loot in ipairs(LOOT_ITEMS) do
        if loot.icon and not lootImages[loot.id] then
            success, lootImages[loot.id] = pcall(function()
                return love.graphics.newImage(loot.icon)
            end)
            if not success then lootImages[loot.id] = nil end
        end
    end
end

-- Get ammo count from backpack
local function getAmmoCount()
    return Backpack.getItemCount("arrows") or 0
end

-- Use ammo from backpack
local function useAmmo(qty)
    qty = qty or 1
    return Backpack.removeItem("arrows", qty)
end

-- Add loot to backpack
local function addLoot(lootId, qty)
    qty = qty or 1
    Backpack.addItem(lootId, qty)
end

-- Initialize UI components
local function initUIComponents()
    local screenW, screenH = love.graphics.getDimensions()

    -- Navigation buttons (bottom area navigation)
    local btnW, btnH = 80, 40
    local btnY = screenH - 80

    state.navButtons.prevArea = UI.Button.new({
        x = 20,
        y = btnY,
        w = btnW,
        h = btnH,
        text = "< PREV",
        variant = "ghost",
        onClick = function()
            state.currentBgIndex = state.currentBgIndex - 1
            if state.currentBgIndex < 1 then state.currentBgIndex = #huntBackgrounds end
        end
    })

    state.navButtons.nextArea = UI.Button.new({
        x = screenW - btnW - 20,
        y = btnY,
        w = btnW,
        h = btnH,
        text = "NEXT >",
        variant = "ghost",
        onClick = function()
            state.currentBgIndex = state.currentBgIndex + 1
            if state.currentBgIndex > #huntBackgrounds then state.currentBgIndex = 1 end
        end
    })
end

-- Initialize hunting game
function Hunting.init()
    state.active = true
    state.noiseLevel = 0
    state.animals = {}
    state.arrow = nil
    state.spawnTimer = 0
    state.shootCooldown = 0
    state.showShop = false
    state.showEmployeePanel = false
    state.showUpgradePanel = false
    state.employeeProduction = 0

    Backpack.init()
    loadImages()
    initUIComponents()

    -- Give starting arrows if none
    if getAmmoCount() < 5 then
        Backpack.addItem("arrows", 10)
    end

    -- Load saved data
    Hunting.loadSaveData()

    -- Generate initial hiring pool if empty
    if #state.hiringPool == 0 then
        state.hiringPool = Employees.generateHiringPool("hunting", 3, Hunting.getSkillLevel())
    end

    -- Calculate initial passive income rate
    Hunting.updatePassiveIncomeRate()

    -- Register UI region resolver for interactive tutorials
    InteractiveTutorial.registerRegionResolver("hunting", Hunting.getUIRegion)

    -- Start tutorial if not completed
    if not Tutorials.hasCompleted("hunting") then
        Tutorials.startTutorial("hunting")
    end
end

-- Load saved hunting data
function Hunting.loadSaveData()
    if PlayerData.huntingData then
        state.employees = Employees.load(PlayerData.huntingData.employees)
        state.upgrades = UpgradeSystem.load(PlayerData.huntingData.upgrades)
        state.currentBuild = PlayerData.huntingData.currentBuild
        state.daysPassed = PlayerData.huntingData.daysPassed or 0
        state.season = PlayerData.huntingData.season or "frosthollow"
        state.trophies = PlayerData.huntingData.trophies or {}
        state.huntingLevel = PlayerData.huntingData.huntingLevel or 1
        state.experience = PlayerData.huntingData.experience or 0
    else
        state.employees = {}
        state.upgrades = {}
        state.currentBuild = nil
        state.daysPassed = 0
        state.season = "frosthollow"
        state.trophies = {}
        state.huntingLevel = 1
        state.experience = 0
    end
end

-- Save hunting data
function Hunting.saveData()
    PlayerData.huntingData = {
        employees = Employees.save(state.employees),
        upgrades = UpgradeSystem.save(state.upgrades),
        currentBuild = state.currentBuild,
        daysPassed = state.daysPassed,
        season = state.season,
        trophies = state.trophies,
        huntingLevel = state.huntingLevel,
        experience = state.experience,
    }
    savePlayerData()
end

-- Calculate and update passive income from hunting employees
function Hunting.updatePassiveIncomeRate()
    local effects = UpgradeSystem.getCombinedEffects("hunting", state.upgrades)
    local totalRate = 0

    -- Calculate income from all hired employees
    for _, emp in ipairs(state.employees) do
        if emp.isHired and not emp.isDead then
            local efficiency = Employees.getEfficiency(emp)
            -- Base rate: efficiency * 0.05 gold per second (hunting base rate)
            local empRate = efficiency * 0.05
            -- Apply rare chance bonus (better catches = more value)
            empRate = empRate * (1 + (effects.rareChanceBonus or 0))
            totalRate = totalRate + empRate
        end
    end

    -- Use global helper to update passive income
    updatePassiveIncomeSource("hunting", totalRate)
end

-- Get current skill level
function Hunting.getSkillLevel()
    return state.huntingLevel
end

-- OPTIMIZATION: Entity pooling functions
-- Reduces garbage collection pressure by reusing animal objects
local function getAnimalFromPool()
    if #state.animalPool.inactive > 0 then
        return table.remove(state.animalPool.inactive)
    end
    -- Pool empty, return new empty table
    return {}
end

local function returnAnimalToPool(animal)
    -- Clear references (prevent memory leaks)
    animal.def = nil
    animal.detected = nil
    animal.fleeing = nil
    -- Recycle to pool
    table.insert(state.animalPool.inactive, animal)
end

-- Spawn a new animal
local function spawnAnimal()
    local screenW, screenH = love.graphics.getDimensions()

    -- Find eligible animals for current region
    local eligible = {}
    for _, animal in ipairs(ANIMALS) do
        for _, region in ipairs(animal.regions) do
            if region == state.currentRegion then
                -- Legendary animals are rare
                if animal.legendary then
                    if math.random() < 0.02 then
                        table.insert(eligible, animal)
                    end
                else
                    table.insert(eligible, animal)
                end
                break
            end
        end
    end

    if #eligible == 0 then return end

    local animalDef = eligible[math.random(#eligible)]

    -- Determine spawn side (left or right)
    local fromLeft = math.random() < 0.5
    local startX = fromLeft and -80 or (screenW + 80)
    local direction = fromLeft and 1 or -1

    -- Spawn in the lower portion of screen (ground level)
    local groundY = screenH * 0.55 + math.random() * (screenH * 0.25)

    -- OPTIMIZATION: Reuse pooled animal object
    local newAnimal = getAnimalFromPool()
    newAnimal.def = animalDef
    newAnimal.x = startX
    newAnimal.y = groundY
    newAnimal.direction = direction
    newAnimal.speed = animalDef.speed * (0.8 + math.random() * 0.4)  -- Some variance
    newAnimal.fleeing = false
    newAnimal.fleeSpeed = animalDef.speed * 2.5
    newAnimal.scale = 0.8 + math.random() * 0.4
    newAnimal.detected = false

    table.insert(state.animals, newAnimal)
end

-- Update hunting game
function Hunting.update(dt)
    if not state.active then return end

    -- Update tutorial
    Tutorials.update(dt)

    -- Update UI components
    if state.navButtons.prevArea then
        state.navButtons.prevArea:update(dt)
    end
    if state.navButtons.nextArea then
        state.navButtons.nextArea:update(dt)
    end

    -- Update shop UI components
    if state.showShop then
        for _, btn in ipairs(state.shopButtons) do
            if btn then btn:update(dt) end
        end
    end

    -- Employee panel uses shared EmployeeUI module, no per-frame button updates needed

    -- Update notification timer
    if state.notification then
        state.notificationTimer = state.notificationTimer - dt
        if state.notificationTimer <= 0 then
            state.notification = nil
        end
    end

    -- Update shoot cooldown
    if state.shootCooldown > 0 then
        state.shootCooldown = state.shootCooldown - dt
    end

    -- Wind changes slowly
    state.windSpeed = state.windSpeed + (math.random() - 0.5) * dt * 20
    state.windSpeed = math.max(-50, math.min(50, state.windSpeed))
    state.windDirection = state.windDirection + (math.random() - 0.5) * dt * 30
    if state.windDirection > 360 then state.windDirection = state.windDirection - 360 end
    if state.windDirection < 0 then state.windDirection = state.windDirection + 360 end

    -- Noise level decreases over time
    if state.noiseLevel > 0 then
        state.noiseLevel = state.noiseLevel - dt * 8
        if state.noiseLevel < 0 then state.noiseLevel = 0 end
    end

    local screenW, screenH = love.graphics.getDimensions()

    -- Spawn animals periodically
    state.spawnTimer = state.spawnTimer + dt
    if state.spawnTimer >= state.spawnInterval and #state.animals < state.maxAnimals then
        spawnAnimal()
        state.spawnTimer = 0
        state.spawnInterval = 2 + math.random() * 4  -- Random interval
    end

    -- Update animals
    for i = #state.animals, 1, -1 do
        local animal = state.animals[i]

        -- Check if noise alerts animal
        if state.noiseLevel > 50 and not animal.fleeing then
            local detectChance = (state.noiseLevel / 100) * (animal.def.awareness / 10)
            if math.random() < detectChance * dt * 2 then
                animal.fleeing = true
                animal.direction = -animal.direction  -- Run opposite direction
            end
        end

        -- Move animal
        local speed = animal.fleeing and animal.fleeSpeed or animal.speed
        animal.x = animal.x + animal.direction * speed * dt

        -- Remove if off screen
        if animal.x < -150 or animal.x > screenW + 150 then
            -- OPTIMIZATION: Return to pool instead of destroying
            returnAnimalToPool(animal)
            table.remove(state.animals, i)
        end
    end

    -- Update arrow physics
    if state.arrow and state.arrow.active then
        local arrow = state.arrow
        local gravity = 250  -- Reduced gravity for faster arrows

        -- Apply wind (reduced effect for faster arrows)
        local windEffect = state.windSpeed * 0.3
        arrow.vx = arrow.vx + windEffect * dt

        -- Apply gravity
        arrow.vy = arrow.vy + gravity * dt

        -- Update position (faster movement)
        arrow.x = arrow.x + arrow.vx * dt * 1.5
        arrow.y = arrow.y + arrow.vy * dt * 1.5

        -- Keep arrow pointing in direction of travel (no spinning)
        -- Only update rotation slightly for natural trajectory feel
        local targetRotation = math.atan2(arrow.vy, arrow.vx)
        arrow.rotation = arrow.rotation + (targetRotation - arrow.rotation) * 0.1 * dt

        -- Check collision with animals
        for i, animal in ipairs(state.animals) do
            local animalW = 64 * animal.scale
            local animalH = 64 * animal.scale
            local hitboxPadding = 10

            if arrow.x >= animal.x - animalW/2 - hitboxPadding and
               arrow.x <= animal.x + animalW/2 + hitboxPadding and
               arrow.y >= animal.y - animalH + hitboxPadding and
               arrow.y <= animal.y + hitboxPadding then
                -- Hit!
                Hunting.onAnimalHit(animal, i)
                state.arrow = nil
                break
            end
        end

        -- If arrow was consumed by a hit, skip miss-detection
        if not state.arrow then return end

        -- Check if arrow is off screen or hit ground
        if arrow and (arrow.y > screenH - 50 or arrow.x < 0 or arrow.x > screenW or arrow.y < -100) then
            -- Missed - alert nearby animals
            state.noiseLevel = math.min(100, state.noiseLevel + 40)
            for _, animal in ipairs(state.animals) do
                local dist = math.abs(animal.x - arrow.x)
                if dist < 200 and not animal.fleeing then
                    animal.fleeing = true
                    animal.direction = animal.x < arrow.x and -1 or 1
                end
            end
            state.arrow = nil
        end
    end

    -- Note: Employee passive income is now handled globally via PlayerData.passiveIncome
    -- This allows income to accumulate even when not in hunting mode
    -- The in-mode production below is for visual feedback and resource gathering
    for _, emp in ipairs(state.employees) do
        if emp.isHired and not emp.isDead then
            local efficiency = Employees.getEfficiency(emp)
            state.employeeProduction = state.employeeProduction + (efficiency * 0.05 * dt)

            -- When employees produce enough, auto-gather resources
            if state.employeeProduction >= 1.0 then
                state.employeeProduction = state.employeeProduction - 1.0
                -- Add random loot from employee hunting
                local possibleLoot = {"raw_meat", "small_hide", "feathers"}
                local lootId = possibleLoot[math.random(#possibleLoot)]
                addLoot(lootId, 1)
                emp.resourcesGathered = (emp.resourcesGathered or 0) + 1
            end
        end
    end

    -- Check upgrade completion
    if state.currentBuild and UpgradeSystem.isComplete(state.currentBuild) then
        state.upgrades[state.currentBuild.upgradeId] = state.currentBuild.targetLevel
        state.notification = "Upgrade complete: " .. state.currentBuild.upgradeId
        state.notificationTimer = 3
        state.currentBuild = nil
        Hunting.saveData()
    end

    -- Auto-save periodically
    state.lastSaveTime = state.lastSaveTime + dt
    if state.lastSaveTime >= 30 then
        Hunting.saveData()
        state.lastSaveTime = 0
    end
end

-- Handle animal being hit
function Hunting.onAnimalHit(animal, index)
    local region = nil
    for _, r in ipairs(REGIONS) do
        if r.id == state.currentRegion then
            region = r
            break
        end
    end

    -- Calculate value
    local value = math.floor(animal.def.value * (region and region.animalBonus or 1))
    PlayerData.coins = PlayerData.coins + value

    -- Award XP
    local xpReward = animal.def.legendary and Progression.XP_REWARDS.hunt_rare or Progression.XP_REWARDS.hunt_success
    Progression.addXP(xpReward, "hunting")
    state.experience = state.experience + animal.def.difficulty * 10

    -- Check for level up
    local levelThreshold = state.huntingLevel * 100
    if state.experience >= levelThreshold then
        state.huntingLevel = state.huntingLevel + 1
        state.experience = state.experience - levelThreshold
        state.notification = "Level Up! Now level " .. state.huntingLevel
        state.notificationTimer = 3
    end

    -- Drop loot
    local lootDropped = {}
    for _, loot in ipairs(animal.def.loot or {}) do
        if math.random() <= loot.chance then
            local qty = loot.qty or 1
            addLoot(loot.id, qty)
            table.insert(lootDropped, {id = loot.id, qty = qty})
        end
    end

    -- Build notification
    local lootStr = ""
    for _, l in ipairs(lootDropped) do
        local lootDef = nil
        for _, def in ipairs(LOOT_ITEMS) do
            if def.id == l.id then
                lootDef = def
                break
            end
        end
        lootStr = lootStr .. (lootDef and lootDef.name or l.id) .. " x" .. l.qty .. ", "
    end
    if #lootStr > 0 then
        lootStr = lootStr:sub(1, -3)  -- Remove trailing comma
    end

    state.notification = "Hunted " .. animal.def.name .. "! +" .. value .. " gold. Loot: " .. lootStr
    state.notificationTimer = 4

    -- Add trophy if applicable
    if animal.def.trophy then
        table.insert(state.trophies, {
            animal = animal.def,
            timestamp = os.time(),
            region = state.currentRegion,
        })
    end

    -- Remove animal
    -- OPTIMIZATION: Return to pool before removing from active list
    returnAnimalToPool(animal)
    table.remove(state.animals, index)
end

-- Shoot arrow at target position
function Hunting.shootArrow(targetX, targetY)
    if state.shootCooldown > 0 then return false, "Cooldown" end
    if getAmmoCount() < 1 then
        state.notification = "No arrows! Buy more from shop."
        state.notificationTimer = 2
        return false, "No ammo"
    end
    if state.arrow then return false, "Arrow in flight" end

    local screenW, screenH = love.graphics.getDimensions()

    -- Arrow starts from bottom left (player position)
    local startX = 100
    local startY = screenH - 120

    -- Calculate initial velocity to reach target with arc
    local dx = targetX - startX
    local dy = targetY - startY
    local distance = math.sqrt(dx * dx + dy * dy)

    -- Base speed scaled by distance (faster arrows)
    local speed = math.min(900, 400 + distance * 0.6)

    -- Calculate angle with arc (shoot higher than target)
    local angle = math.atan2(dy, dx)
    -- Add upward arc based on distance
    local arcAdjust = -math.min(0.5, distance / 1500)
    angle = angle + arcAdjust

    state.arrow = {
        x = startX,
        y = startY,
        vx = math.cos(angle) * speed,
        vy = math.sin(angle) * speed,
        rotation = angle,
        active = true,
    }

    -- Use ammo and add noise
    useAmmo(1)
    state.noiseLevel = math.min(100, state.noiseLevel + 30)
    state.shootCooldown = 0.5

    return true
end

-- Draw the hunting game
function Hunting.draw()
    local screenW, screenH = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()

    -- Clear tooltip state
    UIAssets.clearTooltip()

    -- Draw hunting background
    local bgMode = huntBackgrounds[state.currentBgIndex] or "camp"
    if not UIAssets.drawGameBackground(bgMode, 1) then
        -- Fallback background
        love.graphics.setColor(0.2, 0.35, 0.2)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
        love.graphics.setColor(0.15, 0.25, 0.15)
        love.graphics.rectangle("fill", 0, screenH * 0.7, screenW, screenH * 0.3)
    end

    -- Draw dark overlay for readability
    love.graphics.setColor(0, 0, 0, 0.2)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Draw animals
    for _, animal in ipairs(state.animals) do
        local img = animalImages[animal.def.id]
        if img then
            love.graphics.setColor(1, 1, 1)
            local imgW, imgH = img:getDimensions()
            local scale = animal.scale * 0.5
            local drawX = animal.x - (imgW * scale) / 2
            local drawY = animal.y - imgH * scale

            -- Flip based on direction
            if animal.direction < 0 then
                love.graphics.draw(img, animal.x + (imgW * scale) / 2, drawY, 0, -scale, scale)
            else
                love.graphics.draw(img, drawX, drawY, 0, scale, scale)
            end

            -- Draw name label if not fleeing
            if not animal.fleeing then
                love.graphics.setColor(1, 1, 1, 0.8)
                love.graphics.setFont(UI.fonts.get(10))
                love.graphics.printf(animal.def.name, animal.x - 40, animal.y - imgH * scale - 15, 80, "center")
            end
        else
            -- Placeholder
            love.graphics.setColor(0.6, 0.4, 0.2)
            love.graphics.circle("fill", animal.x, animal.y - 20, 20 * animal.scale)
        end

        -- Draw fleeing indicator
        if animal.fleeing then
            love.graphics.setColor(1, 0.3, 0.3, 0.8)
            love.graphics.setFont(UI.fonts.get(12))
            love.graphics.print("!", animal.x - 5, animal.y - 80)
        end
    end

    -- Draw arrow in flight
    if state.arrow and state.arrow.active then
        if arrowImage then
            love.graphics.setColor(1, 1, 1)
            local imgW, imgH = arrowImage:getDimensions()
            local scale = 0.4
            love.graphics.draw(arrowImage, state.arrow.x, state.arrow.y, state.arrow.rotation, scale, scale, imgW/2, imgH/2)
        else
            -- Fallback arrow drawing
            love.graphics.setColor(0.6, 0.4, 0.2)
            love.graphics.push()
            love.graphics.translate(state.arrow.x, state.arrow.y)
            love.graphics.rotate(state.arrow.rotation)
            love.graphics.rectangle("fill", -15, -2, 30, 4)
            love.graphics.polygon("fill", 15, 0, 10, -5, 10, 5)
            love.graphics.pop()
        end
    end

    -- Draw player/bow position indicator
    love.graphics.setColor(0.4, 0.6, 0.3, 0.7)
    love.graphics.circle("fill", 100, screenH - 120, 15)
    love.graphics.setColor(0.6, 0.4, 0.2)
    love.graphics.setLineWidth(3)
    love.graphics.arc("line", "open", 100, screenH - 120, 20, -math.pi * 0.7, -math.pi * 0.3)
    love.graphics.setLineWidth(1)

    -- Draw aiming line from player to mouse
    if not state.arrow then
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.setLineWidth(1)
        love.graphics.line(100, screenH - 120, mx, my)

        -- Draw predicted trajectory (simplified arc preview)
        local startX, startY = 100, screenH - 120
        local dx = mx - startX
        local dy = my - startY
        local distance = math.sqrt(dx * dx + dy * dy)
        local speed = math.min(600, 200 + distance * 0.5)
        local angle = math.atan2(dy, dx) - math.min(0.5, distance / 1500)

        love.graphics.setColor(1, 1, 0, 0.3)
        local prevX, prevY = startX, startY
        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed
        for t = 0.1, 2, 0.1 do
            local px = startX + vx * t + (state.windSpeed * 0.5) * t * t / 2
            local py = startY + vy * t + 150 * t * t  -- Gravity
            if py > screenH then break end
            love.graphics.circle("fill", px, py, 2)
            prevX, prevY = px, py
        end
    end

    -- Draw background cycling buttons with labels
    local btnW = 80
    local btnH = 40
    local btnY = screenH - 80

    -- Update button positions (in case screen size changed)
    if state.navButtons.prevArea then
        state.navButtons.prevArea.x = 20
        state.navButtons.prevArea.y = btnY
        state.navButtons.prevArea:draw()
    end

    if state.navButtons.nextArea then
        state.navButtons.nextArea.x = screenW - btnW - 20
        state.navButtons.nextArea.y = btnY
        state.navButtons.nextArea:draw()
    end

    -- Location name (center)
    love.graphics.setColor(0, 0, 0, 0.7)
    local locName = huntBgNames[state.currentBgIndex] or "Camp"
    love.graphics.setFont(UI.fonts.get(16))
    local locW = math.max(150, love.graphics.UI.fonts.get():getWidth(locName) + 30)
    love.graphics.rectangle("fill", screenW/2 - locW/2, btnY, locW, btnH, 6, 6)
    love.graphics.setColor(0.7, 0.9, 0.5)
    love.graphics.printf(locName, screenW/2 - locW/2, btnY + 10, locW, "center")

    -- Draw UI panel (left side)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 10, 10, 200, 150, 8, 8)

    love.graphics.setColor(0.6, 0.8, 0.4)
    love.graphics.setFont(UI.fonts.get(18))
    love.graphics.print("HUNTING", 20, 15)

    -- Stats
    love.graphics.setColor(1, 0.9, 0.3)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.print("Gold: " .. PlayerData.coins, 20, 45)

    love.graphics.setColor(0.8, 0.6, 0.4)
    love.graphics.print("Arrows: " .. getAmmoCount(), 120, 45)

    love.graphics.setColor(0.7, 0.8, 0.9)
    love.graphics.print("Level: " .. state.huntingLevel, 20, 65)
    love.graphics.print("XP: " .. state.experience .. "/" .. (state.huntingLevel * 100), 100, 65)

    love.graphics.setColor(0.6, 0.7, 0.6)
    love.graphics.print("Region: " .. state.currentRegion, 20, 85)
    love.graphics.print("Trophies: " .. #state.trophies, 20, 105)
    love.graphics.print("Employees: " .. #state.employees, 20, 125)

    -- Wind indicator (top right)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", screenW - 110, 10, 100, 60, 8, 8)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.print("Wind", screenW - 90, 15)

    -- Wind arrow
    local windArrowX = screenW - 60
    local windArrowY = 50
    local windLen = math.abs(state.windSpeed) * 0.3
    local windRad = state.windSpeed > 0 and 0 or math.pi
    love.graphics.setColor(0.7, 0.9, 1)
    love.graphics.setLineWidth(2)
    love.graphics.line(windArrowX - windLen, windArrowY, windArrowX + windLen, windArrowY)
    if state.windSpeed > 5 then
        love.graphics.polygon("fill", windArrowX + windLen, windArrowY, windArrowX + windLen - 8, windArrowY - 5, windArrowX + windLen - 8, windArrowY + 5)
    elseif state.windSpeed < -5 then
        love.graphics.polygon("fill", windArrowX - windLen, windArrowY, windArrowX - windLen + 8, windArrowY - 5, windArrowX - windLen + 8, windArrowY + 5)
    end
    love.graphics.setLineWidth(1)

    love.graphics.setColor(0.6, 0.8, 0.9)
    love.graphics.setFont(UI.fonts.get(10))
    love.graphics.printf(string.format("%.0f", math.abs(state.windSpeed)), screenW - 110, 55, 100, "center")

    -- Noise meter (moved up 20% - now at ~65% of screen height instead of bottom)
    local noiseY = screenH * 0.50
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", screenW/2 - 80, noiseY, 160, 35, 8, 8)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(11))
    love.graphics.print("Noise Level", screenW/2 - 35, noiseY + 2)

    local noiseColor = {0.2, 0.8, 0.2}
    if state.noiseLevel > 70 then
        noiseColor = {0.9, 0.2, 0.2}
    elseif state.noiseLevel > 40 then
        noiseColor = {0.9, 0.9, 0.2}
    end
    love.graphics.setColor(noiseColor)
    love.graphics.rectangle("fill", screenW/2 - 75, noiseY + 18, 150 * (state.noiseLevel / 100), 12, 3, 3)
    love.graphics.setColor(0.4, 0.4, 0.4)
    love.graphics.rectangle("line", screenW/2 - 75, noiseY + 18, 150, 12, 3, 3)

    -- Notification
    if state.notification then
        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.rectangle("fill", screenW / 2 - 200, 100, 400, 50, 8, 8)
        love.graphics.setColor(1, 1, 0.6)
        love.graphics.setFont(UI.fonts.get(13))
        love.graphics.printf(state.notification, screenW / 2 - 195, 115, 390, "center")
    end

    -- Instructions
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.setFont(UI.fonts.get(11))
    love.graphics.print("[Click] Shoot  [S] Shop  [E] Employees  [U] Upgrades  [B] Backpack  [ESC] Exit", screenW/2 - 250, screenH - 25)

    -- Draw shop panel if open
    if state.showShop then
        Hunting.drawShopPanel(screenW, screenH, mx, my)
    end

    -- Draw employee panel if open
    if state.showEmployeePanel then
        EmployeeUI.drawEmployeePanel(screenW, screenH, mx, my, "hunting", state.employees, state.hiringPool, state.upgrades)
    end

    -- Draw upgrade panel if open
    if state.showUpgradePanel then
        Hunting.drawUpgradePanel(screenW, screenH, mx, my)
    end

    -- Draw tutorial overlay
    Tutorials.draw()
end

-- Create shop UI components
local function createShopUI()
    local screenW, screenH = love.graphics.getDimensions()
    local panelW, panelH = 350, 300
    local panelX = screenW / 2 - panelW / 2
    local panelY = screenH / 2 - panelH / 2

    -- Create shop buttons
    state.shopButtons = {}
    local y = panelY + 55
    for i, item in ipairs(SHOP_ITEMS) do
        local btn = UI.Button.new({
            x = panelX + panelW - 90,
            y = y + 12,
            w = 60,
            h = 30,
            text = item.cost .. "g",
            variant = "success",
            disabled = PlayerData.coins < item.cost,
            onClick = function()
                if PlayerData.coins >= item.cost then
                    PlayerData.coins = PlayerData.coins - item.cost
                    Backpack.addItem(item.id, item.qty)
                    state.notification = "Bought " .. item.name .. "!"
                    state.notificationTimer = 2
                    -- Recreate shop UI to update button states
                    createShopUI()
                end
            end
        })
        table.insert(state.shopButtons, btn)
        y = y + 65
    end
end

-- Draw shop panel
function Hunting.drawShopPanel(screenW, screenH, mx, my)
    local panelW, panelH = 350, 300
    local panelX = screenW / 2 - panelW / 2
    local panelY = screenH / 2 - panelH / 2

    -- Draw overlay
    love.graphics.setColor(UI.theme.colors.overlay)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Draw panel background
    love.graphics.setColor(UI.theme.colors.panel)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, UI.theme.radius.lg, UI.theme.radius.lg)
    love.graphics.setColor(UI.theme.colors.panelBorder)
    love.graphics.setLineWidth(UI.theme.border.normal)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, UI.theme.radius.lg, UI.theme.radius.lg)
    love.graphics.setLineWidth(1)

    -- Draw title
    love.graphics.setColor(UI.theme.colors.textAccent)
    love.graphics.setFont(UI.fonts.get(18))
    love.graphics.print("HUNTING SHOP", panelX + 20, panelY + 15)

    -- Draw gold
    love.graphics.setColor(1, 0.9, 0.3)
    love.graphics.setFont(UI.fonts.get(12))
    love.graphics.print("Your Gold: " .. PlayerData.coins, panelX + panelW - 120, panelY + 18)

    -- Draw shop items
    local y = panelY + 55
    for i, item in ipairs(SHOP_ITEMS) do
        local isHovered = mx >= panelX + 20 and mx <= panelX + panelW - 20 and my >= y and my <= y + 55

        love.graphics.setColor(isHovered and UI.theme.colors.bgLight or UI.theme.colors.bg)
        love.graphics.rectangle("fill", panelX + 20, y, panelW - 40, 55, UI.theme.radius.md, UI.theme.radius.md)

        love.graphics.setColor(UI.theme.colors.text)
        love.graphics.setFont(UI.fonts.get(13))
        love.graphics.print(item.name, panelX + 30, y + 8)

        love.graphics.setColor(UI.theme.colors.textDim)
        love.graphics.setFont(UI.fonts.get(10))
        love.graphics.print(item.desc, panelX + 30, y + 28)

        -- Draw buy button
        if state.shopButtons[i] then
            state.shopButtons[i].disabled = PlayerData.coins < item.cost
            state.shopButtons[i]:draw()
        end

        y = y + 65
    end

    -- Draw close instruction
    love.graphics.setColor(UI.theme.colors.textDim)
    love.graphics.setFont(UI.fonts.get(11))
    love.graphics.printf("Press [S] or [ESC] to close", panelX, panelY + panelH - 28, panelW, "center")
end

-- Create employee panel UI components (no longer needed, handled by shared EmployeeUI)
local function createEmployeeUI()
    -- No-op: employee panel rendering and click handling now uses EmployeeUI module
end

-- Draw employee panel (delegated to shared EmployeeUI module)
function Hunting.drawEmployeePanel(screenW, screenH, mx, my)
    EmployeeUI.drawEmployeePanel(screenW, screenH, mx, my, "hunting", state.employees, state.hiringPool, state.upgrades)
end

-- Draw upgrade panel
function Hunting.drawUpgradePanel(screenW, screenH, mx, my)
    local panelW, panelH = 450, 400
    local panelX = screenW / 2 - panelW / 2
    local panelY = screenH / 2 - panelH / 2

    -- Draw overlay
    love.graphics.setColor(UI.theme.colors.overlay)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Draw panel background
    love.graphics.setColor(UI.theme.colors.panel)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, UI.theme.radius.lg, UI.theme.radius.lg)
    love.graphics.setColor(UI.theme.colors.panelBorder)
    love.graphics.setLineWidth(UI.theme.border.normal)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, UI.theme.radius.lg, UI.theme.radius.lg)
    love.graphics.setLineWidth(1)

    -- Draw title
    love.graphics.setColor(UI.theme.colors.textAccent)
    love.graphics.setFont(UI.fonts.get(18))
    love.graphics.print("HUNTING UPGRADES", panelX + 20, panelY + 15)

    local y = panelY + 50
    local upgrades = UpgradeSystem.getUpgrades("hunting")

    for i, upgrade in ipairs(upgrades) do
        local currentLevel = state.upgrades[upgrade.id] or 0
        local isHovered = mx >= panelX + 20 and mx <= panelX + panelW - 20 and my >= y and my <= y + 100
        local height = UpgradeSystem.drawUpgradeCard("hunting", upgrade.id, currentLevel, panelX + 20, y, panelW - 40, isHovered, state.currentBuild)
        y = y + height + 10
    end

    love.graphics.setColor(UI.theme.colors.textDim)
    love.graphics.setFont(UI.fonts.get(11))
    love.graphics.printf("Press [U] or [ESC] to close  |  Click upgrade to start", panelX, panelY + panelH - 28, panelW, "center")
end

-- Hire an employee
function Hunting.hireEmployee(index)
    -- Check if player owns this building
    if PlayerData.currentBuildingOwned ~= true then
        state.notification = "You must own this lodge to hire hunters!"
        state.notificationTimer = 2
        return false
    end

    local emp = state.hiringPool[index]
    if not emp then return false end

    local empType = Employees.getType(emp.employeeType)
    if not empType then return false end

    local effects = UpgradeSystem.getCombinedEffects("hunting", state.upgrades)
    local maxEmployees = effects.maxEmployees or 1

    if #state.employees >= maxEmployees then
        state.notification = "Max hunters reached! Upgrade lodge."
        state.notificationTimer = 2
        return false
    end

    if PlayerData.coins < empType.baseCost then
        state.notification = "Not enough gold!"
        state.notificationTimer = 2
        return false
    end

    PlayerData.coins = PlayerData.coins - empType.baseCost
    emp.isHired = true
    emp.hireDay = os.time()
    table.insert(state.employees, emp)
    table.remove(state.hiringPool, index)

    local newCandidates = Employees.generateHiringPool("hunting", 1, Hunting.getSkillLevel())
    if #newCandidates > 0 then
        table.insert(state.hiringPool, newCandidates[1])
    end

    state.notification = "Hired " .. emp.name .. "!"
    state.notificationTimer = 2
    -- Update global passive income rate
    Hunting.updatePassiveIncomeRate()
    Hunting.saveData()
    return true
end

-- Fire an employee
function Hunting.fireEmployee(index)
    local emp = state.employees[index]
    if emp then
        table.remove(state.employees, index)
        state.notification = "Fired " .. emp.name
        state.notificationTimer = 2
        -- Update global passive income rate
        Hunting.updatePassiveIncomeRate()
        Hunting.saveData()
        return true
    end
    return false
end

-- Start an upgrade
function Hunting.startUpgrade(upgradeId)
    if state.currentBuild then
        state.notification = "Already building an upgrade!"
        state.notificationTimer = 2
        return false
    end

    local currentLevel = state.upgrades[upgradeId] or 0
    local canAfford, reason = UpgradeSystem.canAfford("hunting", upgradeId, currentLevel, PlayerData.coins)

    if not canAfford then
        state.notification = reason
        state.notificationTimer = 2
        return false
    end

    local buildInfo, err = UpgradeSystem.startUpgrade("hunting", upgradeId, currentLevel, PlayerData.coins)
    if not buildInfo then
        state.notification = err
        state.notificationTimer = 2
        return false
    end

    -- Deduct gold (skip if already deducted by startUpgrade)
    if not buildInfo.goldDeducted then
        PlayerData.coins = PlayerData.coins - buildInfo.goldCost
    end
    state.currentBuild = buildInfo

    state.notification = "Started upgrade: " .. upgradeId
    state.notificationTimer = 2
    Hunting.saveData()
    return true
end

-- Handle key press
function Hunting.keypressed(key)
    -- Handle tutorial keypresses first
    if Tutorials.isActive() then
        Tutorials.keypressed(key)
        return
    end

    if key == "s" then
        state.showShop = not state.showShop
        state.showEmployeePanel = false
        state.showUpgradePanel = false
        if state.showShop then
            createShopUI()
        end
    elseif key == "e" then
        state.showEmployeePanel = not state.showEmployeePanel
        state.showShop = false
        state.showUpgradePanel = false
        if state.showEmployeePanel then
            createEmployeeUI()
        end
    elseif key == "u" then
        state.showUpgradePanel = not state.showUpgradePanel
        state.showShop = false
        state.showEmployeePanel = false
    elseif key == "b" then
        Backpack.toggle()
    elseif key == "left" then
        state.currentBgIndex = state.currentBgIndex - 1
        if state.currentBgIndex < 1 then state.currentBgIndex = #huntBackgrounds end
    elseif key == "right" then
        state.currentBgIndex = state.currentBgIndex + 1
        if state.currentBgIndex > #huntBackgrounds then state.currentBgIndex = 1 end
    elseif key == "escape" then
        if state.showShop then
            state.showShop = false
        elseif state.showEmployeePanel then
            state.showEmployeePanel = false
        elseif state.showUpgradePanel then
            state.showUpgradePanel = false
        else
            Hunting.saveData()
            state.active = false
            return "menu"
        end
    end
end

-- Handle mouse press
function Hunting.mousepressed(x, y, button)
    if button ~= 1 then return end

    -- Handle tutorial clicks first
    if Tutorials.isActive() then
        Tutorials.mousepressed(x, y, button)
        return
    end

    local screenW, screenH = love.graphics.getDimensions()

    -- Handle backpack clicks
    if Backpack.isOpen() then
        Backpack.mousepressed(x, y, button)
        return
    end

    -- Handle shop panel clicks
    if state.showShop then
        for _, btn in ipairs(state.shopButtons) do
            if btn and btn:mousepressed(x, y, button) then
                return
            end
        end
        return
    end

    -- Handle employee panel clicks
    if state.showEmployeePanel then
        local action, idx = EmployeeUI.handleEmployeePanelClick(x, y, "hunting", state.employees, state.hiringPool, state.upgrades)
        if action == "fire" then
            Hunting.fireEmployee(idx)
        elseif action == "hire" then
            Hunting.hireEmployee(idx)
        end
        return
    end

    -- Handle upgrade panel clicks
    if state.showUpgradePanel then
        local panelW, panelH = 450, 400
        local panelX = screenW / 2 - panelW / 2
        local panelY = screenH / 2 - panelH / 2

        local upgY = panelY + 50
        local upgrades = UpgradeSystem.getUpgrades("hunting")

        for i, upgrade in ipairs(upgrades) do
            if x >= panelX + 20 and x <= panelX + panelW - 20 and y >= upgY and y <= upgY + 100 then
                Hunting.startUpgrade(upgrade.id)
                return
            end
            upgY = upgY + 110
        end
        return
    end

    -- Handle navigation button clicks
    if state.navButtons.prevArea and state.navButtons.prevArea:mousepressed(x, y, button) then
        return
    end
    if state.navButtons.nextArea and state.navButtons.nextArea:mousepressed(x, y, button) then
        return
    end

    -- Shoot arrow at clicked position
    Hunting.shootArrow(x, y)
end

-- Handle mouse release
function Hunting.mousereleased(x, y, button)
    if button ~= 1 then return end

    -- Forward to backpack if open
    if Backpack.isOpen() and Backpack.mousereleased then
        Backpack.mousereleased(x, y, button)
        return
    end

    -- Handle UI button releases
    if state.navButtons.prevArea then
        state.navButtons.prevArea:mousereleased(x, y, button)
    end
    if state.navButtons.nextArea then
        state.navButtons.nextArea:mousereleased(x, y, button)
    end

    if state.showShop then
        for _, btn in ipairs(state.shopButtons) do
            if btn then btn:mousereleased(x, y, button) end
        end
    end

    -- Employee panel uses coordinate-based click handling via EmployeeUI, no mousereleased needed
end

-- Handle scroll
function Hunting.wheelmoved(wx, wy)
    if Backpack.isOpen() then
        Backpack.wheelmoved(wx, wy)
    end
end

-- Check if hunting is active
function Hunting.isActive()
    return state.active
end

-- Exit hunting mode
function Hunting.exit()
    Hunting.saveData()
    state.active = false
end

-- Get UI region for tutorial spotlights
function Hunting.getUIRegion(regionId)
    local screenW, screenH = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()

    local regions = {
        -- Crosshair/aiming cursor
        crosshair = {
            x = mx - 30,
            y = my - 30,
            w = 60,
            h = 60,
        },

        -- Wind display (top right)
        wind_display = {
            x = screenW - 110,
            y = 10,
            w = 100,
            h = 60,
        },

        -- Noise meter (middle of screen, moved up from bottom)
        noise_meter = {
            x = screenW/2 - 80,
            y = screenH * 0.50,
            w = 160,
            h = 35,
        },

        -- Region selection buttons (bottom center with both nav buttons)
        region_select = {
            x = screenW/2 - 150,
            y = screenH - 80,
            w = 300,
            h = 40,
        },
    }

    return regions[regionId]
end

return Hunting
