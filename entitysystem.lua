-- Entity System - Shared aging, health, moods, diseases for all living entities
-- Used by pets, mounts, NPCs, employees across all game modes

local EntitySystem = {}

-- Font cache for performance
local FontCache = require("fontcache")
local function getFont(size)
    return FontCache.get(size)
end

-- Age categories
EntitySystem.AGE_CATEGORIES = {
    {id = "child", name = "Child", minAge = 0, maxAge = 12, workMult = 0},
    {id = "teen", name = "Teen", minAge = 13, maxAge = 17, workMult = 0.5},
    {id = "young_adult", name = "Young Adult", minAge = 18, maxAge = 30, workMult = 1.2},
    {id = "adult", name = "Adult", minAge = 31, maxAge = 50, workMult = 1.0},
    {id = "middle_aged", name = "Middle Aged", minAge = 51, maxAge = 65, workMult = 0.9},
    {id = "elder", name = "Elder", minAge = 66, maxAge = 80, workMult = 0.6},
    {id = "ancient", name = "Ancient", minAge = 81, maxAge = 999, workMult = 0.3},
}

-- Diseases that can affect entities
EntitySystem.DISEASES = {
    {id = "common_cold", name = "Common Cold", severity = 1, duration = 3, workPenalty = 0.2,
     symptoms = {"sneezing", "fatigue"}, treatmentCost = 10},
    {id = "flu", name = "Flu", severity = 2, duration = 7, workPenalty = 0.5,
     symptoms = {"fever", "fatigue", "aches"}, treatmentCost = 25},
    {id = "infection", name = "Infection", severity = 2, duration = 10, workPenalty = 0.4,
     symptoms = {"fever", "weakness"}, treatmentCost = 50},
    {id = "poison", name = "Poisoning", severity = 3, duration = 5, workPenalty = 0.7,
     symptoms = {"nausea", "weakness", "fever"}, treatmentCost = 75},
    {id = "plague", name = "Plague", severity = 4, duration = 14, workPenalty = 0.9,
     symptoms = {"fever", "lesions", "weakness", "delirium"}, treatmentCost = 200, fatal = true},
    {id = "curse", name = "Dark Curse", severity = 3, duration = 30, workPenalty = 0.5,
     symptoms = {"nightmares", "weakness", "pale"}, treatmentCost = 500, magical = true},
}

-- Injuries that can affect entities
EntitySystem.INJURIES = {
    {id = "bruise", name = "Bruise", severity = 1, healTime = 2, workPenalty = 0.05},
    {id = "sprain", name = "Sprain", severity = 2, healTime = 5, workPenalty = 0.2},
    {id = "cut", name = "Cut", severity = 1, healTime = 3, workPenalty = 0.1},
    {id = "fracture", name = "Fracture", severity = 3, healTime = 21, workPenalty = 0.6},
    {id = "broken_bone", name = "Broken Bone", severity = 4, healTime = 42, workPenalty = 0.8},
    {id = "burn", name = "Burn", severity = 2, healTime = 10, workPenalty = 0.3},
    {id = "concussion", name = "Concussion", severity = 3, healTime = 14, workPenalty = 0.5},
}

-- Moods that affect work performance
EntitySystem.MOODS = {
    {id = "ecstatic", name = "Ecstatic", workMult = 1.5, color = {0.9, 0.9, 0.3}},
    {id = "happy", name = "Happy", workMult = 1.2, color = {0.4, 0.8, 0.4}},
    {id = "content", name = "Content", workMult = 1.0, color = {0.6, 0.7, 0.6}},
    {id = "neutral", name = "Neutral", workMult = 0.9, color = {0.7, 0.7, 0.7}},
    {id = "unhappy", name = "Unhappy", workMult = 0.7, color = {0.8, 0.6, 0.4}},
    {id = "depressed", name = "Depressed", workMult = 0.4, color = {0.5, 0.4, 0.5}},
    {id = "angry", name = "Angry", workMult = 0.5, color = {0.9, 0.3, 0.3}},
}

-- Base stats for entities
EntitySystem.BASE_STATS = {
    health = 100,
    energy = 100,
    hunger = 100,
    happiness = 50,
    loyalty = 50,
    experience = 0,
}

-- Lifespan multipliers by entity type (in game days)
EntitySystem.LIFESPAN = {
    human = 80 * 365,      -- 80 years in days
    pet_small = 10 * 365,  -- Small pets live ~10 years
    pet_medium = 15 * 365, -- Medium pets ~15 years
    pet_large = 20 * 365,  -- Large pets ~20 years
    mount = 25 * 365,      -- Mounts ~25 years
    magical = 100 * 365,   -- Magical creatures ~100 years
    undead = 999999,       -- Undead don't age normally
}

-- Create a new entity with aging and stats
function EntitySystem.createEntity(entityType, name, age, species)
    local lifespan = EntitySystem.LIFESPAN[entityType] or EntitySystem.LIFESPAN.human

    return {
        id = math.random(100000, 999999),
        name = name or "Unknown",
        entityType = entityType or "human",
        species = species,

        -- Age system (age in days, converted to years for display)
        birthDay = 0,
        age = age or 0, -- Age in years (for display/logic)
        ageDays = (age or 0) * 365, -- Actual age in game days
        lifespan = lifespan,
        isDead = false,
        deathCause = nil,

        -- Health stats
        health = EntitySystem.BASE_STATS.health,
        maxHealth = EntitySystem.BASE_STATS.health,
        energy = EntitySystem.BASE_STATS.energy,
        maxEnergy = EntitySystem.BASE_STATS.energy,
        hunger = EntitySystem.BASE_STATS.hunger,

        -- Mood and happiness
        happiness = EntitySystem.BASE_STATS.happiness,
        mood = "content",
        loyalty = EntitySystem.BASE_STATS.loyalty,

        -- Conditions
        diseases = {},    -- Active diseases
        injuries = {},    -- Active injuries
        buffs = {},       -- Temporary positive effects
        debuffs = {},     -- Temporary negative effects

        -- Experience and skills
        experience = 0,
        level = 1,
        skills = {},

        -- Work tracking
        daysWorked = 0,
        totalEarned = 0,
        lastPaid = 0,

        -- Timestamps
        createdAt = os.time(),
        lastUpdate = os.time(),
    }
end

-- Get age category for an entity
function EntitySystem.getAgeCategory(age)
    for _, cat in ipairs(EntitySystem.AGE_CATEGORIES) do
        if age >= cat.minAge and age <= cat.maxAge then
            return cat
        end
    end
    return EntitySystem.AGE_CATEGORIES[#EntitySystem.AGE_CATEGORIES]
end

-- Get mood info
function EntitySystem.getMood(moodId)
    for _, mood in ipairs(EntitySystem.MOODS) do
        if mood.id == moodId then
            return mood
        end
    end
    return EntitySystem.MOODS[4] -- Default to neutral
end

-- Calculate work efficiency based on age, mood, health, diseases, injuries
function EntitySystem.calculateWorkEfficiency(entity)
    local efficiency = 1.0

    -- Age modifier
    local ageCategory = EntitySystem.getAgeCategory(entity.age)
    efficiency = efficiency * ageCategory.workMult

    -- Mood modifier
    local mood = EntitySystem.getMood(entity.mood)
    efficiency = efficiency * mood.workMult

    -- Health modifier (below 50% health reduces efficiency)
    if entity.health < entity.maxHealth * 0.5 then
        efficiency = efficiency * (entity.health / entity.maxHealth)
    end

    -- Energy modifier
    if entity.energy < entity.maxEnergy * 0.3 then
        efficiency = efficiency * 0.5
    end

    -- Disease penalties
    for _, disease in ipairs(entity.diseases or {}) do
        local diseaseInfo = EntitySystem.getDisease(disease.id)
        if diseaseInfo then
            efficiency = efficiency * (1 - diseaseInfo.workPenalty)
        end
    end

    -- Injury penalties
    for _, injury in ipairs(entity.injuries or {}) do
        local injuryInfo = EntitySystem.getInjury(injury.id)
        if injuryInfo then
            efficiency = efficiency * (1 - injuryInfo.workPenalty)
        end
    end

    return math.max(0, math.min(2, efficiency))
end

-- Get disease info by ID
function EntitySystem.getDisease(diseaseId)
    for _, disease in ipairs(EntitySystem.DISEASES) do
        if disease.id == diseaseId then
            return disease
        end
    end
    return nil
end

-- Get injury info by ID
function EntitySystem.getInjury(injuryId)
    for _, injury in ipairs(EntitySystem.INJURIES) do
        if injury.id == injuryId then
            return injury
        end
    end
    return nil
end

-- Add a disease to an entity
function EntitySystem.addDisease(entity, diseaseId)
    -- Check if already has this disease
    for _, d in ipairs(entity.diseases or {}) do
        if d.id == diseaseId then return false end
    end

    local disease = EntitySystem.getDisease(diseaseId)
    if disease then
        table.insert(entity.diseases, {
            id = diseaseId,
            startDay = entity.ageDays,
            daysRemaining = disease.duration,
        })
        entity.happiness = math.max(0, entity.happiness - 10)
        return true
    end
    return false
end

-- Add an injury to an entity
function EntitySystem.addInjury(entity, injuryId)
    local injury = EntitySystem.getInjury(injuryId)
    if injury then
        table.insert(entity.injuries, {
            id = injuryId,
            startDay = entity.ageDays,
            daysRemaining = injury.healTime,
        })
        entity.happiness = math.max(0, entity.happiness - 5)
        entity.health = math.max(1, entity.health - injury.severity * 5)
        return true
    end
    return false
end

-- Treat a disease (requires gold)
function EntitySystem.treatDisease(entity, diseaseId, playerCoins)
    local disease = EntitySystem.getDisease(diseaseId)
    if not disease then return false, "Unknown disease" end
    if playerCoins < disease.treatmentCost then return false, "Not enough gold" end

    -- Remove the disease
    for i, d in ipairs(entity.diseases or {}) do
        if d.id == diseaseId then
            table.remove(entity.diseases, i)
            entity.happiness = math.min(100, entity.happiness + 5)
            return true, disease.treatmentCost
        end
    end
    return false, "Disease not found"
end

-- Update entity for one game day
function EntitySystem.updateDaily(entity, currentSeason)
    if entity.isDead then return end

    -- Age one day
    entity.ageDays = entity.ageDays + 1
    entity.age = math.floor(entity.ageDays / 365)

    -- Check for natural death (old age)
    if entity.ageDays >= entity.lifespan then
        local deathChance = (entity.ageDays - entity.lifespan) / (entity.lifespan * 0.2)
        if math.random() < deathChance then
            entity.isDead = true
            entity.deathCause = "old_age"
            return
        end
    end

    -- Update diseases
    for i = #entity.diseases, 1, -1 do
        local d = entity.diseases[i]
        d.daysRemaining = d.daysRemaining - 1

        -- Check for death from fatal disease
        local disease = EntitySystem.getDisease(d.id)
        if disease and disease.fatal and entity.health < 20 then
            if math.random() < 0.1 then
                entity.isDead = true
                entity.deathCause = disease.name
                return
            end
        end

        -- Disease cured naturally
        if d.daysRemaining <= 0 then
            table.remove(entity.diseases, i)
            entity.happiness = math.min(100, entity.happiness + 5)
        else
            -- Ongoing disease damage
            entity.health = math.max(1, entity.health - disease.severity)
        end
    end

    -- Update injuries
    for i = #entity.injuries, 1, -1 do
        local inj = entity.injuries[i]
        inj.daysRemaining = inj.daysRemaining - 1

        if inj.daysRemaining <= 0 then
            table.remove(entity.injuries, i)
            entity.happiness = math.min(100, entity.happiness + 3)
        end
    end

    -- Random disease chance (higher in winter)
    local diseaseChance = 0.001
    if currentSeason == "frosthollow" then
        diseaseChance = 0.003
    elseif currentSeason == "ashwane" then
        diseaseChance = 0.002
    end

    if math.random() < diseaseChance then
        local randomDisease = EntitySystem.DISEASES[math.random(1, 3)] -- Only common diseases randomly
        EntitySystem.addDisease(entity, randomDisease.id)
    end

    -- Random injury chance (very low)
    if math.random() < 0.0005 then
        local randomInjury = EntitySystem.INJURIES[math.random(1, 4)]
        EntitySystem.addInjury(entity, randomInjury.id)
    end

    -- Hunger decreases daily
    entity.hunger = math.max(0, entity.hunger - 10)
    if entity.hunger <= 0 then
        entity.health = math.max(1, entity.health - 5)
        entity.happiness = math.max(0, entity.happiness - 5)
    end

    -- Energy regenerates
    entity.energy = math.min(entity.maxEnergy, entity.energy + 30)

    -- Health regenerates slowly if well-fed
    if entity.hunger > 50 and #entity.diseases == 0 then
        entity.health = math.min(entity.maxHealth, entity.health + 2)
    end

    -- Update mood based on conditions
    EntitySystem.updateMood(entity)

    entity.lastUpdate = os.time()
end

-- Update entity mood based on conditions
function EntitySystem.updateMood(entity)
    local happyScore = entity.happiness

    -- Modify by health
    if entity.health < 30 then
        happyScore = happyScore - 20
    elseif entity.health < 60 then
        happyScore = happyScore - 10
    end

    -- Modify by hunger
    if entity.hunger < 20 then
        happyScore = happyScore - 25
    elseif entity.hunger < 50 then
        happyScore = happyScore - 10
    end

    -- Modify by diseases/injuries
    happyScore = happyScore - #entity.diseases * 10
    happyScore = happyScore - #entity.injuries * 5

    -- Determine mood from score
    if happyScore >= 90 then
        entity.mood = "ecstatic"
    elseif happyScore >= 70 then
        entity.mood = "happy"
    elseif happyScore >= 50 then
        entity.mood = "content"
    elseif happyScore >= 35 then
        entity.mood = "neutral"
    elseif happyScore >= 20 then
        entity.mood = "unhappy"
    elseif happyScore >= 10 then
        entity.mood = "depressed"
    else
        entity.mood = "angry"
    end
end

-- Feed an entity
function EntitySystem.feed(entity, foodValue)
    entity.hunger = math.min(100, entity.hunger + (foodValue or 30))
    entity.happiness = math.min(100, entity.happiness + 5)
    return true
end

-- Rest an entity
function EntitySystem.rest(entity, hours)
    entity.energy = math.min(entity.maxEnergy, entity.energy + (hours or 8) * 10)
    return true
end

-- Get entity status summary
function EntitySystem.getStatusSummary(entity)
    local status = {}

    -- Age category
    local ageCat = EntitySystem.getAgeCategory(entity.age)
    table.insert(status, ageCat.name .. " (" .. entity.age .. " years)")

    -- Health status
    if entity.health < 30 then
        table.insert(status, "Critical Health")
    elseif entity.health < 60 then
        table.insert(status, "Wounded")
    end

    -- Diseases
    for _, d in ipairs(entity.diseases or {}) do
        local disease = EntitySystem.getDisease(d.id)
        if disease then
            table.insert(status, disease.name .. " (" .. d.daysRemaining .. " days)")
        end
    end

    -- Injuries
    for _, i in ipairs(entity.injuries or {}) do
        local injury = EntitySystem.getInjury(i.id)
        if injury then
            table.insert(status, injury.name .. " (healing)")
        end
    end

    -- Mood
    local mood = EntitySystem.getMood(entity.mood)
    table.insert(status, "Mood: " .. mood.name)

    return status
end

-- Draw entity health/status bars
function EntitySystem.drawStatusBars(entity, x, y, width)
    local barHeight = 8
    local spacing = 4

    -- Health bar
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", x, y, width, barHeight, 2, 2)
    local healthPercent = entity.health / entity.maxHealth
    local healthColor = {0.2, 0.8, 0.2}
    if healthPercent < 0.3 then
        healthColor = {0.9, 0.2, 0.2}
    elseif healthPercent < 0.6 then
        healthColor = {0.9, 0.7, 0.2}
    end
    love.graphics.setColor(healthColor)
    love.graphics.rectangle("fill", x, y, width * healthPercent, barHeight, 2, 2)

    -- Energy bar
    y = y + barHeight + spacing
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", x, y, width, barHeight, 2, 2)
    love.graphics.setColor(0.2, 0.5, 0.9)
    love.graphics.rectangle("fill", x, y, width * (entity.energy / entity.maxEnergy), barHeight, 2, 2)

    -- Hunger bar
    y = y + barHeight + spacing
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.rectangle("fill", x, y, width, barHeight, 2, 2)
    love.graphics.setColor(0.8, 0.6, 0.2)
    love.graphics.rectangle("fill", x, y, width * (entity.hunger / 100), barHeight, 2, 2)

    -- Mood indicator
    y = y + barHeight + spacing
    local mood = EntitySystem.getMood(entity.mood)
    love.graphics.setColor(mood.color)
    love.graphics.setFont(getFont(10))
    love.graphics.print(mood.name, x, y)

    -- Disease/injury indicators
    y = y + 14
    for _, d in ipairs(entity.diseases or {}) do
        love.graphics.setColor(0.8, 0.3, 0.3)
        love.graphics.circle("fill", x + 5, y + 5, 4)
        x = x + 12
    end
    for _, i in ipairs(entity.injuries or {}) do
        love.graphics.setColor(0.9, 0.6, 0.2)
        love.graphics.circle("fill", x + 5, y + 5, 4)
        x = x + 12
    end
end

return EntitySystem
