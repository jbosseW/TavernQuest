-- RPG Stats System
-- Extracted from textrpg.lua
-- Contains: stat modifiers, derived stats, character bonuses (racial + background),
-- ascension system, specialization queries, reputation, race unlocks,
-- character creation, stat calculation, and XP/leveling.

local Backpack = require("backpack")
local Data = require("rpg_data")

local M = {}

-- Upvalues set by register()
local state
local F

-- Data references (set during register from textrpg locals)
local CLASSES
local RACES
local UNLOCKABLE_RACES
local BACKGROUNDS
local CLASS_BASE_STATS
local STAT_DEFINITIONS
local ASCENSION_CONFIG
local ASCENSION_TREE
local SPECIALIZATIONS
local TALENT_LOOKUP
local REPUTATION_LEVELS
local MAX_LEVEL

-- Forward-declared locals within this module
local log
local getStatModifier
local getPlayerSpecialization
local calculateStats
local addJournalEvent

-- List every function name that will be installed onto F
M.F_FUNCTIONS = {
    "getStatModifier", "getDerivedStats",
    "getCharacterBonuses",
    "calculateAscensionPoints", "canAscend", "performAscension",
    "getAscensionSkillRank", "getAscensionSkillCost",
    "canRankUpAscensionSkill", "rankUpAscensionSkill",
    "canUnlockAscensionSkill", "unlockAscensionSkill",
    "getAscensionBonuses", "getAscensionTreeData", "getTotalAPSpent",
    "getSpecializationOptions", "getPlayerSpecialization",
    "getReputationLevel",
    "initUnlockedRaces", "isRaceUnlocked", "unlockRace",
    "checkRaceUnlockCondition", "checkAllRaceUnlocks", "getRaceUnlockProgress",
    "createPlayer", "calculateStats", "gainXP",
    "companionGainXP", "autoAllocateCompanion",
}

function M.register(s, f, deps)
    state = s
    F = f

    CLASSES              = deps.CLASSES
    RACES                = deps.RACES
    UNLOCKABLE_RACES     = deps.UNLOCKABLE_RACES
    BACKGROUNDS          = deps.BACKGROUNDS
    CLASS_BASE_STATS     = deps.CLASS_BASE_STATS
    STAT_DEFINITIONS     = deps.STAT_DEFINITIONS
    ASCENSION_CONFIG     = deps.ASCENSION_CONFIG
    ASCENSION_TREE       = deps.ASCENSION_TREE
    SPECIALIZATIONS      = deps.SPECIALIZATIONS
    TALENT_LOOKUP        = deps.TALENT_LOOKUP
    REPUTATION_LEVELS    = deps.REPUTATION_LEVELS
    MAX_LEVEL            = deps.MAX_LEVEL

    log = deps.log

    -- Install every listed function onto F
    for _, name in ipairs(M.F_FUNCTIONS) do
        if M[name] then
            F[name] = M[name]
        end
    end

    -- Bind module-local forward references so internal calls work
    getStatModifier        = M.getStatModifier
    getPlayerSpecialization = M.getPlayerSpecialization
    calculateStats         = M.calculateStats
    addJournalEvent        = F.addJournalEvent  -- defined elsewhere, already on F
end

-- ============================================================================
-- REPUTATION
-- ============================================================================

M.getReputationLevel = function(rep)
    for _, level in ipairs(REPUTATION_LEVELS) do
        if rep >= level.min and rep <= level.max then
            return level
        end
    end
    return REPUTATION_LEVELS[4] -- Default to Neutral
end

-- ============================================================================
-- RACE UNLOCK SYSTEM
-- ============================================================================

M.initUnlockedRaces = function()
    if not PlayerData.unlockedRaces then
        PlayerData.unlockedRaces = {}
    end
end

M.isRaceUnlocked = function(raceId)
    M.initUnlockedRaces()
    return PlayerData.unlockedRaces[raceId] == true
end

M.unlockRace = function(raceId)
    M.initUnlockedRaces()
    if not PlayerData.unlockedRaces[raceId] then
        PlayerData.unlockedRaces[raceId] = true
        -- Find race name for notification
        for _, race in ipairs(UNLOCKABLE_RACES) do
            if race.id == raceId then
                log("NEW RACE UNLOCKED: " .. race.name .. "!", {1, 0.8, 0.2})
                return true
            end
        end
    end
    return false
end

M.checkRaceUnlockCondition = function(race)
    if not race.unlockType or not race.unlockCondition then
        return false
    end

    -- Get stats from PlayerData.rpgStats (persistent across saves)
    local rpgStats = PlayerData.rpgStats or {}

    if race.unlockType == "metric" then
        local stat = race.unlockCondition.stat
        local required = race.unlockCondition.value
        local current = rpgStats[stat] or 0

        -- Check if stat exists and meets requirement
        return current >= required

    elseif race.unlockType == "location" then
        local location = race.unlockCondition.location
        -- Check PlayerData for visited locations
        local visited = PlayerData.visitedLocations or {}
        return visited[location] == true

    elseif race.unlockType == "achievement" then
        local achievement = race.unlockCondition.achievement
        -- Check PlayerData for achievements
        local achievements = PlayerData.achievements or {}
        return achievements[achievement] == true
    end

    return false
end

M.checkAllRaceUnlocks = function()
    for _, race in ipairs(UNLOCKABLE_RACES) do
        if not M.isRaceUnlocked(race.id) then
            if M.checkRaceUnlockCondition(race) then
                M.unlockRace(race.id)
            end
        end
    end
end

M.getRaceUnlockProgress = function(race)
    if not race.unlockType or not race.unlockCondition then
        return 0, 1, 0
    end

    local rpgStats = PlayerData.rpgStats or {}

    if race.unlockType == "metric" then
        local stat = race.unlockCondition.stat
        local required = race.unlockCondition.value
        local current = rpgStats[stat] or 0
        local percent = math.min(100, math.floor((current / required) * 100))
        return current, required, percent

    elseif race.unlockType == "location" then
        local visited = PlayerData.visitedLocations or {}
        local location = race.unlockCondition.location
        if visited[location] then
            return 1, 1, 100
        end
        return 0, 1, 0

    elseif race.unlockType == "achievement" then
        local achievements = PlayerData.achievements or {}
        local achievement = race.unlockCondition.achievement
        if achievements[achievement] then
            return 1, 1, 100
        end
        return 0, 1, 0
    end

    return 0, 1, 0
end

-- ============================================================================
-- STAT MODIFIERS & DERIVED STATS
-- ============================================================================

-- Calculate stat modifier: (stat - 10) / 2, rounded down
M.getStatModifier = function(statValue)
    statValue = statValue or 10  -- Default to 10 if nil (modifier = 0)
    return math.floor((statValue - 10) / 2)
end

-- Get derived combat stats from attributes
M.getDerivedStats = function(stats, level)
    level = level or 1
    local derived = {
        -- From MIGHT
        meleeDamageBonus = getStatModifier(stats.MIGHT or 10) * 2,
        carryCapacity = 100 + getStatModifier(stats.MIGHT or 10) * 20,

        -- From AGILITY
        critChance = 5 + getStatModifier(stats.AGILITY or 10) * 2,  -- Base 5% + 2% per mod
        dodgeChance = getStatModifier(stats.AGILITY or 10) * 2,     -- 2% per mod

        -- From VIGOR
        hpPerLevel = 2 + getStatModifier(stats.VIGOR or 10) * 2,  -- Extra HP per level
        poisonResist = getStatModifier(stats.VIGOR or 10) * 5,    -- 5% per mod

        -- From MIND
        spellDamageBonus = getStatModifier(stats.MIND or 10) * 3,
        bonusMana = getStatModifier(stats.MIND or 10) * 5,

        -- From SPIRIT
        healingBonus = getStatModifier(stats.SPIRIT or 10) * 2,
        manaRegen = math.max(0, getStatModifier(stats.SPIRIT or 10)),  -- Mana per turn in combat

        -- From PRESENCE
        shopDiscount = getStatModifier(stats.PRESENCE or 10) * 3,  -- 3% per mod
        companionMorale = getStatModifier(stats.PRESENCE or 10) * 5,

        -- From FAITH
        holyDamageBonus = getStatModifier(stats.FAITH or 10) * 2,
        corruptionResist = getStatModifier(stats.FAITH or 10) * 5,
        vampireResist = getStatModifier(stats.FAITH or 10) * 3,
    }
    return derived
end

-- ============================================================================
-- CHARACTER BONUSES (Racial + Background)
-- ============================================================================

M.getCharacterBonuses = function(player)
    if not player then return nil end

    -- Initialize bonuses table with neutral defaults
    local bonuses = {
        -- Multiplicative modifiers (1.0 = no change)
        maxHPMult = 1.0,
        maxManaMult = 1.0,
        meleeDamageMult = 1.0,
        magicDamageMult = 1.0,
        healingDoneMult = 1.0,
        healingReceivedMult = 1.0,
        xpMult = 1.0,
        goldMult = 1.0,
        manaCostMult = 1.0,
        manaRegenMult = 1.0,
        critDamageMult = 1.0,
        defenseMult = 1.0,
        undeadDamageMult = 1.0,
        lowHPDamageMult = 1.0,
        -- Flat additive modifiers
        critChanceBonus = 0,
        dodgeChanceBonus = 0,
        poisonResistBonus = 0,
        corruptionResistBonus = 0,
        fireResistBonus = 0,
        frostResistBonus = 0,
        allResistBonus = 0,
        extraGoldPerKill = 0,
        shopDiscountBonus = 0,
        fleeBonusPercent = 0,
        -- Per-turn effects
        hpRegenPercent = 0,
        -- Special flags
        healOnKillPercent = 0,
        surviveKillingBlow = false,
        phaseFirstAttack = false,
        freeSpellChance = 0,
        immunePoison = false,
        immuneFear = false,
        extraLootChance = 0,
        -- Passive-specific fields
        undeadCritBonus = 0,          -- Extra crit chance vs undead (undead_slayer)
        undeadDefenseBonus = 0,       -- Extra defense vs undead (vampire_sense)
        undeadCritMultOverride = 0,   -- Override crit mult vs undead (stake_mastery)
        unarmedDamageMult = 1.0,      -- Damage mult when no weapon equipped (brawler)
        flatDamageReduction = 0,      -- Flat damage subtracted from incoming hits (thick_skinned)
        lowHPCritBonus = 0,           -- Extra crit when below 25% HP (desperate_luck)
        sellPriceMult = 1.0,          -- Sell price multiplier (silver_tongue)
        doubleGoldChance = 0,         -- % chance for double gold on kill (scam_artist)
        lowHPRegenPercent = 0,        -- HP regen % when below 25% HP (survivors_will)
        companionDamageMult = 1.0,    -- Companion damage multiplier (animal_bond)
        firstAttackDodgeBonus = 0,    -- Extra dodge on first enemy attack per combat (trap_sense)
    }

    -- Apply racial bonuses
    local raceId = player.race and player.race.id or "human"

    if raceId == "human" then
        bonuses.xpMult = bonuses.xpMult + 0.10
        bonuses.goldMult = bonuses.goldMult + 0.15
    elseif raceId == "elf" then
        bonuses.manaCostMult = bonuses.manaCostMult - 0.20
        bonuses.manaRegenMult = bonuses.manaRegenMult + 0.25
    elseif raceId == "dwarf" then
        bonuses.maxHPMult = bonuses.maxHPMult + 0.20
        bonuses.poisonResistBonus = bonuses.poisonResistBonus + 15
        bonuses.corruptionResistBonus = bonuses.corruptionResistBonus + 15
    elseif raceId == "orc" then
        bonuses.meleeDamageMult = bonuses.meleeDamageMult + 0.15
        bonuses.lowHPDamageMult = bonuses.lowHPDamageMult + 0.25
        bonuses.healOnKillPercent = 15
    elseif raceId == "goblin" then
        bonuses.dodgeChanceBonus = bonuses.dodgeChanceBonus + 15
        bonuses.fleeBonusPercent = bonuses.fleeBonusPercent + 25
        bonuses.extraGoldPerKill = bonuses.extraGoldPerKill + 5
    elseif raceId == "gnome" then
        bonuses.manaRegenMult = bonuses.manaRegenMult + 0.25
        bonuses.freeSpellChance = 15
    elseif raceId == "catfolk" then
        bonuses.critChanceBonus = bonuses.critChanceBonus + 25
        bonuses.surviveKillingBlow = true
    elseif raceId == "lizardfolk" then
        bonuses.poisonResistBonus = bonuses.poisonResistBonus + 30
        bonuses.hpRegenPercent = 2
    elseif raceId == "revenant" then
        bonuses.surviveKillingBlow = true
        bonuses.lowHPDamageMult = bonuses.lowHPDamageMult + 0.20
        bonuses.healingReceivedMult = bonuses.healingReceivedMult - 0.15
        bonuses.immuneFear = true
    elseif raceId == "half_elf" then
        bonuses.xpMult = bonuses.xpMult + 0.10
        bonuses.goldMult = bonuses.goldMult + 0.15
    elseif raceId == "halfling" then
        bonuses.goldMult = bonuses.goldMult + 0.20
        bonuses.critChanceBonus = bonuses.critChanceBonus + 10
        bonuses.dodgeChanceBonus = bonuses.dodgeChanceBonus + 25
        bonuses.extraLootChance = 15
    elseif raceId == "voidborn" then
        bonuses.manaCostMult = bonuses.manaCostMult - 0.25
        bonuses.magicDamageMult = bonuses.magicDamageMult + 0.15
    elseif raceId == "celestial" then
        bonuses.healingDoneMult = bonuses.healingDoneMult + 0.30
        bonuses.undeadDamageMult = bonuses.undeadDamageMult + 0.15
    elseif raceId == "wraith" then
        bonuses.dodgeChanceBonus = bonuses.dodgeChanceBonus + 30
        bonuses.phaseFirstAttack = true
        bonuses.maxHPMult = bonuses.maxHPMult - 0.20
        bonuses.immunePoison = true
    elseif raceId == "nomad" then
        bonuses.maxHPMult = bonuses.maxHPMult + 0.15
    elseif raceId == "automaton" then
        bonuses.immunePoison = true
        bonuses.defenseMult = bonuses.defenseMult + 0.15
        bonuses.critDamageMult = bonuses.critDamageMult + 0.10
    elseif raceId == "dark_elf" then
        bonuses.dodgeChanceBonus = bonuses.dodgeChanceBonus + 15
        bonuses.critDamageMult = bonuses.critDamageMult + 0.25
    elseif raceId == "merfolk" then
        bonuses.manaRegenMult = bonuses.manaRegenMult + 0.25
    elseif raceId == "dragonkin" then
        bonuses.fireResistBonus = bonuses.fireResistBonus + 20
        bonuses.frostResistBonus = bonuses.frostResistBonus + 20
        bonuses.meleeDamageMult = bonuses.meleeDamageMult + 0.15
    elseif raceId == "nephilim" then
        bonuses.maxHPMult = bonuses.maxHPMult + 0.20
        bonuses.meleeDamageMult = bonuses.meleeDamageMult + 0.15
        bonuses.allResistBonus = bonuses.allResistBonus + 10
    end

    -- Apply background bonuses
    local bgId = player.background and player.background.id or nil

    if bgId == "vampire_hunter" then
        bonuses.undeadDamageMult = bonuses.undeadDamageMult + 0.40
    elseif bgId == "tavern_brawler" then
        bonuses.meleeDamageMult = bonuses.meleeDamageMult + 0.15
        bonuses.maxHPMult = bonuses.maxHPMult + 0.10
    elseif bgId == "card_shark" then
        bonuses.critChanceBonus = bonuses.critChanceBonus + 5
        bonuses.goldMult = bonuses.goldMult + 0.10
    elseif bgId == "snake_oil_peddler" then
        bonuses.shopDiscountBonus = bonuses.shopDiscountBonus + 15
        bonuses.goldMult = bonuses.goldMult + 0.10
    elseif bgId == "corruption_survivor" then
        bonuses.corruptionResistBonus = bonuses.corruptionResistBonus + 30
        bonuses.healingReceivedMult = bonuses.healingReceivedMult + 0.10
    elseif bgId == "dungeon_delver" then
        bonuses.extraLootChance = bonuses.extraLootChance + 20
        bonuses.dodgeChanceBonus = bonuses.dodgeChanceBonus + 5
    elseif bgId == "cafe_veteran" then
        bonuses.critChanceBonus = bonuses.critChanceBonus + 5
        bonuses.goldMult = bonuses.goldMult + 0.15
    end

    -- Apply individual passive bonuses (stacks with background base bonuses above)
    if player.background and player.background.passives then
        for _, pid in ipairs(player.background.passives) do
            -- Vampire Hunter passives
            if pid == "undead_slayer" then
                bonuses.undeadCritBonus = bonuses.undeadCritBonus + 25
            elseif pid == "vampire_sense" then
                bonuses.undeadDefenseBonus = bonuses.undeadDefenseBonus + 15
            elseif pid == "stake_mastery" then
                bonuses.undeadCritMultOverride = 2.5
            -- Pit Fighter passives
            elseif pid == "brawler" then
                bonuses.unarmedDamageMult = bonuses.unarmedDamageMult + 0.50
            elseif pid == "thick_skinned" then
                bonuses.flatDamageReduction = bonuses.flatDamageReduction + 3
            elseif pid == "tracker" then
                bonuses.meleeDamageMult = bonuses.meleeDamageMult + 0.15
            -- Card Shark passives
            elseif pid == "card_master" then
                bonuses.critChanceBonus = bonuses.critChanceBonus + 10
            elseif pid == "card_counter" then
                bonuses.dodgeChanceBonus = bonuses.dodgeChanceBonus + 5
            elseif pid == "desperate_luck" then
                bonuses.lowHPCritBonus = bonuses.lowHPCritBonus + 25
            -- Snake Oil Peddler passives
            elseif pid == "silver_tongue" then
                bonuses.sellPriceMult = bonuses.sellPriceMult + 0.20
            elseif pid == "scam_artist" then
                bonuses.doubleGoldChance = bonuses.doubleGoldChance + 15
            elseif pid == "fast_talker" then
                bonuses.fleeBonusPercent = bonuses.fleeBonusPercent + 25
            -- Corruption Survivor passives
            elseif pid == "corruption_resistant" then
                bonuses.corruptionResistBonus = bonuses.corruptionResistBonus + 20
            elseif pid == "survivors_will" then
                bonuses.lowHPRegenPercent = bonuses.lowHPRegenPercent + 3
            elseif pid == "animal_bond" then
                bonuses.companionDamageMult = bonuses.companionDamageMult + 0.25
            -- Ruin Scavenger passives
            elseif pid == "treasure_hunter" then
                bonuses.extraLootChance = bonuses.extraLootChance + 10
            elseif pid == "trap_sense" then
                bonuses.firstAttackDodgeBonus = bonuses.firstAttackDodgeBonus + 15
            elseif pid == "master_angler" then
                bonuses.xpMult = bonuses.xpMult + 0.05
            -- Flesh Broker passives
            elseif pid == "night_dealer" then
                bonuses.extraGoldPerKill = bonuses.extraGoldPerKill + 5
            elseif pid == "corpse_sense" then
                bonuses.extraLootChance = bonuses.extraLootChance + 10
            elseif pid == "black_market_access" then
                bonuses.shopDiscountBonus = bonuses.shopDiscountBonus + 10
            end
        end
    end

    -- Clamp mana cost multiplier to minimum 0.25
    bonuses.manaCostMult = math.max(0.25, bonuses.manaCostMult)

    return bonuses
end

-- ============================================================================
-- ASCENSION SYSTEM
-- ============================================================================

-- Calculate Ascension Points earned from current run
M.calculateAscensionPoints = function()
    local cfg = ASCENSION_CONFIG
    local stats = state.stats or {}
    local p = state.player

    if not p then return 0 end

    local ap = cfg.baseAPReward
    ap = ap + (p.level * cfg.levelBonusAP)
    ap = ap + ((stats.questsCompleted or 0) * cfg.questBonusAP)
    ap = ap + ((stats.enemiesDefeated or 0) * cfg.killBonusAP)
    ap = ap + (((stats.goldEarned or 0) / 1000) * cfg.goldBonusAP)

    -- Bonus AP for first few ascensions to help new prestigers
    local ascensionCount = PlayerData.ascensionCount or 0
    if ascensionCount == 0 then
        ap = ap * 1.5  -- 50% bonus on first ascension
    elseif ascensionCount == 1 then
        ap = ap * 1.25 -- 25% bonus on second ascension
    end

    return math.floor(ap)
end

-- Check if player can ascend
M.canAscend = function()
    if not state.player then return false, "No active character" end
    if state.player.level < ASCENSION_CONFIG.requiredLevel then
        return false, "Must reach level " .. ASCENSION_CONFIG.requiredLevel .. " to ascend"
    end
    -- No cap on ascensions - infinite progression!
    return true, nil
end

-- Perform ascension (prestige reset)
M.performAscension = function()
    local canDo, reason = M.canAscend()
    if not canDo then
        log(reason, {0.9, 0.3, 0.3})
        return false
    end

    -- Calculate AP earned
    local apEarned = M.calculateAscensionPoints()

    -- Initialize PlayerData ascension fields if needed
    PlayerData.ascensionCount = (PlayerData.ascensionCount or 0) + 1
    PlayerData.ascensionPoints = (PlayerData.ascensionPoints or 0) + apEarned
    PlayerData.totalAPEarned = (PlayerData.totalAPEarned or 0) + apEarned

    -- Initialize ascension tree data if needed
    if not PlayerData.ascensionTree then
        PlayerData.ascensionTree = {
            skillRanks = {},   -- {skillId = rank}
            skillPaths = {},   -- {skillId = "A" or "B"}
        }
    end

    -- Store achievement for records
    local ascensionRecord = {
        ascensionNumber = PlayerData.ascensionCount,
        apEarned = apEarned,
        level = state.player.level or 1,
        class = state.player.class and state.player.class.name or "Unknown",
        questsCompleted = state.stats.questsCompleted or 0,
        enemiesDefeated = state.stats.enemiesDefeated or 0,
        timestamp = os.time(),
    }
    PlayerData.ascensionHistory = PlayerData.ascensionHistory or {}
    table.insert(PlayerData.ascensionHistory, ascensionRecord)

    -- Log the ascension
    log("", {1, 1, 1})
    log("=== ASCENSION " .. PlayerData.ascensionCount .. " COMPLETE ===", {1, 0.8, 0.2})
    log("Earned " .. apEarned .. " Ascension Points!", {0.8, 0.6, 1})
    log("Total AP: " .. PlayerData.ascensionPoints, {0.7, 0.5, 0.9})
    -- Diminishing returns formula: 2% * sqrt(ascensionCount)
    local permBonusPercent = math.floor(ASCENSION_CONFIG.permanentStatBonusBase * math.sqrt(PlayerData.ascensionCount) * 100)
    log("Permanent bonus: +" .. permBonusPercent .. "% all stats", {0.5, 0.9, 0.5})

    -- Reset character (ascension progress is preserved in PlayerData)
    F.resetGame()

    -- Save immediately to preserve ascension progress
    savePlayerData()

    return true
end

-- Get current rank of an ascension skill (0 if not unlocked)
M.getAscensionSkillRank = function(skillId)
    local tree = PlayerData.ascensionTree or {}
    local ranks = tree.skillRanks or {}
    return ranks[skillId] or 0
end

-- Calculate cost for the next rank of a skill
M.getAscensionSkillCost = function(skillId)
    local skill = nil
    for _, s in ipairs(ASCENSION_TREE) do
        if s.id == skillId then
            skill = s
            break
        end
    end
    if not skill then return 999999 end

    local currentRank = M.getAscensionSkillRank(skillId)
    return skill.baseCost + (currentRank * skill.costPerRank)
end

-- Check if an ascension skill can be ranked up
M.canRankUpAscensionSkill = function(skillId, path)
    local skill = nil
    for _, s in ipairs(ASCENSION_TREE) do
        if s.id == skillId then
            skill = s
            break
        end
    end

    if not skill then return false, "Skill not found" end

    local tree = PlayerData.ascensionTree or {}
    local currentRank = M.getAscensionSkillRank(skillId)
    local currentPath = tree.skillPaths and tree.skillPaths[skillId]

    -- If already has ranks, must use same path
    if currentRank > 0 and currentPath and currentPath ~= path then
        return false, "Already invested in path " .. currentPath .. " - cannot switch"
    end

    -- Check max rank
    if skill.maxRank and currentRank >= skill.maxRank then
        return false, "Already at max rank (" .. skill.maxRank .. ")"
    end

    -- Check AP cost
    local cost = M.getAscensionSkillCost(skillId)
    local currentAP = PlayerData.ascensionPoints or 0
    if currentAP < cost then
        return false, "Need " .. cost .. " AP (have " .. currentAP .. ")"
    end

    -- Check ascension requirement
    local ascensionCount = PlayerData.ascensionCount or 0
    if skill.minAscension and ascensionCount < skill.minAscension then
        return false, "Requires Ascension " .. skill.minAscension
    end

    -- Check prerequisites (format: "skillId:rank" e.g. "vitality:3")
    if skill.requires then
        for _, req in ipairs(skill.requires) do
            local reqId, reqRank = req:match("([^:]+):?(%d*)")
            reqRank = tonumber(reqRank) or 1
            local hasRank = M.getAscensionSkillRank(reqId)
            if hasRank < reqRank then
                return false, "Requires " .. reqId .. " at rank " .. reqRank .. " (have rank " .. hasRank .. ")"
            end
        end
    end

    return true, nil
end

-- Rank up an ascension skill
M.rankUpAscensionSkill = function(skillId, path)
    local canDo, reason = M.canRankUpAscensionSkill(skillId, path)
    if not canDo then
        log(reason, {0.9, 0.3, 0.3})
        return false
    end

    -- Find skill
    local skill = nil
    for _, s in ipairs(ASCENSION_TREE) do
        if s.id == skillId then
            skill = s
            break
        end
    end

    -- Calculate and deduct cost
    local cost = M.getAscensionSkillCost(skillId)
    PlayerData.ascensionPoints = PlayerData.ascensionPoints - cost

    -- Initialize tree if needed
    if not PlayerData.ascensionTree then
        PlayerData.ascensionTree = {}
    end
    if not PlayerData.ascensionTree.skillRanks then
        PlayerData.ascensionTree.skillRanks = {}
    end
    if not PlayerData.ascensionTree.skillPaths then
        PlayerData.ascensionTree.skillPaths = {}
    end

    -- Increase rank and set path
    local newRank = (PlayerData.ascensionTree.skillRanks[skillId] or 0) + 1
    PlayerData.ascensionTree.skillRanks[skillId] = newRank
    PlayerData.ascensionTree.skillPaths[skillId] = path

    local pathData = path == "A" and skill.pathA or skill.pathB
    log("ASCENSION: " .. pathData.name .. " -> Rank " .. newRank .. "!", {0.8, 0.6, 1})
    log("(-" .. cost .. " AP, " .. (PlayerData.ascensionPoints or 0) .. " remaining)", {0.6, 0.5, 0.7})

    return true
end

-- Legacy function name for compatibility
M.canUnlockAscensionSkill = M.canRankUpAscensionSkill
M.unlockAscensionSkill = M.rankUpAscensionSkill

-- Get all active ascension bonuses (for stat calculation)
-- Now calculates based on RANK of each skill!
M.getAscensionBonuses = function()
    local bonuses = {
        -- Multiplicative bonuses (start at 1)
        hpMultiplier = 1,
        manaMultiplier = 1,
        goldMultiplier = 1,
        spellDamageMultiplier = 1,
        allStatsMultiplier = 1,
        xpMultiplier = 1,
        bossDamageMultiplier = 1,
        -- Additive bonuses (start at 0)
        critBonus = 0,
        critDamageBonus = 0,
        dodgeBonus = 0,
        damageReduction = 0,
        manaCostReduction = 0,
        lifeSteal = 0,
        dropRateBonus = 0,
        hpRegenPercent = 0,
        manaOnKill = 0,
        spellEchoChance = 0,
        combatShield = 0,
        flatDefense = 0,
        initiativeBonus = 0,
        thornsDamage = 0,
        physicalDamageAdd = 0,
        elementalDamageAdd = 0,
        sellBonus = 0,
        buyDiscount = 0,
        rareDropBonus = 0,
        partyDamageBonus = 0,
        partyDefenseBonus = 0,
        bloodFrenzyBonus = 0,
        executeBonus = 0,
        allDamageAdd = 0,
        allResistAdd = 0,
        doubleLootChance = 0,
        instantKillChance = 0,
        lowHpRegen = 0,
        extraRevives = 0,
        reviveHP = 0,
        -- Special flags
        autoRevive = false,
    }

    -- Add permanent bonus from ascension count (diminishing returns)
    local ascensionCount = PlayerData.ascensionCount or 0
    local permBonus = 1 + (ASCENSION_CONFIG.permanentStatBonusBase * math.sqrt(ascensionCount))
    bonuses.allStatsMultiplier = bonuses.allStatsMultiplier * permBonus

    -- Add bonuses from ranked ascension skills
    local tree = PlayerData.ascensionTree
    if tree and tree.skillRanks then
        for skillId, rank in pairs(tree.skillRanks) do
            if rank > 0 then
                local path = tree.skillPaths and tree.skillPaths[skillId] or "A"

                -- Find the skill definition
                for _, skill in ipairs(ASCENSION_TREE) do
                    if skill.id == skillId then
                        local pathData = path == "A" and skill.pathA or skill.pathB
                        local effectPerRank = pathData.effectPerRank or {}
                        local effectBase = pathData.effectBase or {}
                        local effectCap = pathData.effectCap or {}

                        -- Apply base effects (only once, not scaled by rank)
                        if effectBase.autoRevive then bonuses.autoRevive = true end

                        -- Apply per-rank effects (multiplied by rank)
                        for stat, valuePerRank in pairs(effectPerRank) do
                            local totalValue = valuePerRank * rank

                            -- Apply caps if defined
                            if effectCap[stat] then
                                totalValue = math.min(totalValue, effectCap[stat])
                            end

                            -- Apply to the appropriate bonus
                            -- Additive stats ending in "Add" or specific additive stats
                            if stat == "hpMultiplierAdd" then
                                bonuses.hpMultiplier = bonuses.hpMultiplier + totalValue
                            elseif stat == "manaMultiplierAdd" then
                                bonuses.manaMultiplier = bonuses.manaMultiplier + totalValue
                            elseif stat == "goldMultiplierAdd" then
                                bonuses.goldMultiplier = bonuses.goldMultiplier + totalValue
                            elseif stat == "xpMultiplierAdd" then
                                bonuses.xpMultiplier = bonuses.xpMultiplier + totalValue
                            elseif stat == "spellDamageAdd" then
                                bonuses.spellDamageMultiplier = bonuses.spellDamageMultiplier + totalValue
                            elseif stat == "allStatsAdd" then
                                bonuses.allStatsMultiplier = bonuses.allStatsMultiplier + totalValue
                            elseif stat == "bossDamageAdd" then
                                bonuses.bossDamageMultiplier = bonuses.bossDamageMultiplier + totalValue
                            elseif stat == "reviveHP" then
                                bonuses.reviveHP = bonuses.reviveHP + totalValue
                                bonuses.autoRevive = true  -- Enable revive when we have reviveHP
                            elseif bonuses[stat] ~= nil then
                                -- Direct stat match
                                bonuses[stat] = bonuses[stat] + totalValue
                            end
                        end
                        break
                    end
                end
            end
        end
    end

    -- Cap certain stats
    bonuses.manaCostReduction = math.min(bonuses.manaCostReduction, 0.75)  -- Max 75% mana reduction
    bonuses.damageReduction = math.min(bonuses.damageReduction, 0.75)      -- Max 75% damage reduction
    bonuses.instantKillChance = math.min(bonuses.instantKillChance, 0.25) -- Max 25% instant kill

    return bonuses
end

-- Get Ascension Tree data for UI
M.getAscensionTreeData = function()
    return ASCENSION_TREE
end

-- Get total AP spent on ascension skills
M.getTotalAPSpent = function()
    local total = 0
    local tree = PlayerData.ascensionTree
    if tree and tree.skillRanks then
        for skillId, rank in pairs(tree.skillRanks) do
            -- Find skill to calculate cost
            for _, skill in ipairs(ASCENSION_TREE) do
                if skill.id == skillId then
                    -- Sum cost for all ranks
                    for r = 0, rank - 1 do
                        total = total + skill.baseCost + (r * skill.costPerRank)
                    end
                    break
                end
            end
        end
    end
    return total
end

-- ============================================================================
-- SPECIALIZATION
-- ============================================================================

M.getSpecializationOptions = function(classId)
    return SPECIALIZATIONS[classId] or {}
end

M.getPlayerSpecialization = function()
    if state.player and state.player.specialization and state.player.class then
        local specs = SPECIALIZATIONS[state.player.class.id]
        if specs then
            for _, spec in ipairs(specs) do
                if spec.id == state.player.specialization then return spec end
            end
        end
    end
    return nil
end

-- ============================================================================
-- CHARACTER CREATION
-- ============================================================================

M.createPlayer = function(classId, playerName, raceId, gender, backgroundId)
    -- Find selected class
    local class = nil
    for _, c in ipairs(CLASSES) do
        if c.id == classId then
            class = c
            break
        end
    end

    -- Find selected race (check base and unlockable races)
    local race = nil
    for _, r in ipairs(RACES) do
        if r.id == (raceId or "human") then race = r break end
    end
    if not race then
        for _, r in ipairs(UNLOCKABLE_RACES) do
            if r.id == (raceId or "human") then race = r break end
        end
    end
    race = race or RACES[1] -- Default to human

    -- Find selected background
    local background = nil
    if backgroundId then
        for _, bg in ipairs(BACKGROUNDS) do
            if bg.id == backgroundId then
                background = bg
                break
            end
        end
    end

    -- Give starter items to backpack
    Backpack.addItem("tq_health_potion", 3)
    Backpack.addItem("tq_rusty_sword", 1)
    Backpack.addItem("tq_cloth_armor", 1)

    -- Add background starting items
    if background and background.startingItems then
        for _, itemId in ipairs(background.startingItems) do
            Backpack.addItem(itemId, 1)
        end
    end

    -- Get base stats for the class (using new stat system)
    local baseStats = CLASS_BASE_STATS[classId] or CLASS_BASE_STATS.warrior
    local stats = {
        MIGHT = baseStats.MIGHT or 10,
        AGILITY = baseStats.AGILITY or 10,
        VIGOR = baseStats.VIGOR or 10,
        MIND = baseStats.MIND or 10,
        SPIRIT = baseStats.SPIRIT or 10,
        PRESENCE = baseStats.PRESENCE or 10,
        FAITH = baseStats.FAITH or 10,
    }

    -- Apply racial stat modifiers
    if race.statMods then
        for stat, bonus in pairs(race.statMods) do
            if stat ~= "choice1" and stat ~= "choice2" then
                stats[stat] = (stats[stat] or 10) + bonus
            end
        end
    end

    -- Apply player-chosen bonus stats (e.g. Human's "Choose +1 to any 2 stats")
    local cc = state.characterCreation
    if cc and cc.chosenBonusStats then
        for _, stat in ipairs(cc.chosenBonusStats) do
            if stats[stat] then
                stats[stat] = stats[stat] + 1
            end
        end
    end

    -- Apply background stat modifiers
    if background and background.statMods then
        for stat, bonus in pairs(background.statMods) do
            stats[stat] = (stats[stat] or 10) + bonus
        end
    end

    -- Calculate initial HP/Mana with stat bonuses
    local vigMod = getStatModifier(stats.VIGOR)
    local mindMod = getStatModifier(stats.MIND)
    local initialMaxHP = class.baseHP + (vigMod * 2)  -- +2 HP per VIGOR mod
    local initialMaxMana = class.baseMana + (mindMod * 5)  -- +5 mana per MIND mod

    -- Sync gold with main game (use PlayerData.coins - the main currency)
    PlayerData.coins = PlayerData.coins or 50  -- Initialize if nil
    local startingGold = background and background.startingGold or PlayerData.coins
    local startingBounty = 0
    if startingGold < 0 then
        -- Negative starting gold means debt (e.g., Gambling Addict)
        startingBounty = math.abs(startingGold) -- Convert debt to bounty
        startingGold = 0 -- Start with 0 gold
    end

    local player = {
        name = playerName or "Adventurer",
        class = class,
        race = race,  -- NEW: Race data
        gender = gender or "Other",  -- NEW: Gender selection
        background = background,  -- NEW: Background data
        level = 1,
        xp = 0,
        xpToLevel = 100,
        maxHP = initialMaxHP,
        hp = initialMaxHP,
        maxMana = initialMaxMana,
        mana = initialMaxMana,
        maxStamina = 100,  -- All classes start with 100 stamina
        stamina = 100,
        baseAttack = class.baseAtk,
        baseDefense = class.baseDef,
        attack = class.baseAtk,
        defense = class.baseDef,
        gold = startingGold,  -- Synced with PlayerData.coins
        -- Attribute block (new system)
        stats = stats,
        -- Skill tree system
        skillPoints = 0,  -- Earned on level up (starting at level 2)
        unlockedSkills = {start = true},  -- Dictionary of unlocked node IDs
        -- Talent system (feat-like bonuses every 3 levels)
        talents = {},  -- List of talent IDs
        pendingTalentSelection = false,  -- True when player needs to pick a talent
        -- Combat bonuses (calculated from stats + talents + equipment)
        critChance = 5 + getStatModifier(stats.AGILITY) * 2,
        dodgeChance = getStatModifier(stats.AGILITY) * 2,
        critDamage = 1.5,  -- 150% damage on crit
        -- Inventory now uses shared Backpack system
        equipment = {weapon = nil, armor = nil, accessory = nil},
        -- Skill system - players equip skills to slots
        availableSkills = class.skills or {},  -- All skills player has learned
        equippedSkills = {},  -- Skills equipped to combat slots (max 6)
        maxSkillSlots = 4,  -- Start with 4 slots, can increase to 6
        skills = class.skills,  -- Legacy compatibility
        activeQuests = {},
        -- Party system
        party = {},  -- Recruited companions
        maxPartySize = 99,  -- Uncapped - limited by recruitment availability
        -- Karma/Crime system
        karma = 0,  -- Karma score (-100 to 100)
        bounty = startingBounty,  -- Active bounty on player's head (debt from background)
        crimes = {},  -- List of crimes committed
        isJailed = false,  -- Currently in jail
        jailTimeRemaining = 0,  -- Hours remaining in jail
        -- Faction system
        factionRep = {},  -- Reputation with each faction {factionId = repValue}
        joinedFactions = {},  -- List of faction IDs player has joined
        -- Vampire system
        isVampire = false,
        vampireTransformDate = nil,
        vampireTransformLevel = nil,
        vampireSkillTree = {},
        originalStats = nil,
        hasVampireCoffin = false,
        vampireClothWrapped = false,
        sunlightDamageTimer = 0,
        -- Stealth system
        stealthMode = false,
        lastDetectionCheck = 0,
        stealthXPBonus = 0,
        stealth = 10,  -- Base stealth stat
        equipmentStealthMod = 0,
        classStealthBonus = 0,
        skillStealthMod = 0,
        stealthPerks = {
            silent_step = false,
            shadow_blend = false,
            assassinate = false,
            vanish = false,
            scouts_sight = false,
        },
        stealthKills = 0,
        stealthKnockouts = 0,
        -- Journal system
        journal = {
            isOpen = false,
            currentTab = "events",
            eventLog = {},
            actionStats = {
                combat = {
                    enemiesDefeated = 0,
                    defeatedByType = {},
                    damageDealt = 0,
                    deaths = 0,
                    perfectCombats = 0,
                },
                crimes = {
                    crimesCommitted = 0,
                    crimesByType = {},
                    timesArrested = 0,
                    bountyPaid = 0,
                    stealthSuccesses = 0,
                    stealthFailures = 0,
                },
                exploration = {
                    tilesExplored = 0,
                    townsDiscovered = 0,
                    dungeonsCleared = 0,
                    distanceTraveled = 0,
                },
                economy = {
                    goldEarned = 0,
                    goldSpent = 0,
                    itemsCrafted = 0,
                    itemsSold = 0,
                },
                social = {
                    npcsTalkedTo = 0,
                    questsCompleted = 0,
                    partyMembers = 0,
                    vampiresCreated = 0,
                },
            },
            scrollOffset = 0,
        },
        -- Property system (CRITICAL: Initialize for new characters)
        properties = {
            townProperties = {},
            landClaims = {},
            settlements = {},
        },
    }

    -- Auto-equip starting skills (first 4 from available skills)
    if player.availableSkills and #player.availableSkills > 0 then
        player.equippedSkills = {}
        for i = 1, math.min(player.maxSkillSlots, #player.availableSkills) do
            table.insert(player.equippedSkills, player.availableSkills[i])
        end
    end

    return player
end

-- ============================================================================
-- STAT CALCULATION
-- ============================================================================

M.calculateStats = function()
    if not state.player then return end
    local p = state.player

    -- Initialize skill slots for old saves
    if not p.equippedSkills then
        p.equippedSkills = {}
        p.availableSkills = p.skills or {}
        p.maxSkillSlots = 4
        -- Auto-equip first 4 skills
        for i = 1, math.min(4, #p.availableSkills) do
            table.insert(p.equippedSkills, p.availableSkills[i])
        end
    end

    -- Initialize resistances for damage type system
    if not p.resistances then
        p.resistances = {}
    end

    -- Initialize stats if not present (for old saves)
    if not p.stats then
        local baseStats = CLASS_BASE_STATS[p.class.id] or CLASS_BASE_STATS.warrior
        p.stats = {
            MIGHT = baseStats.MIGHT or 10,
            AGILITY = baseStats.AGILITY or 10,
            VIGOR = baseStats.VIGOR or 10,
            MIND = baseStats.MIND or 10,
            SPIRIT = baseStats.SPIRIT or 10,
            PRESENCE = baseStats.PRESENCE or 10,
            FAITH = baseStats.FAITH or 10,
        }
    end

    -- Convert old stat system to new (for backward compatibility with old saves)
    if p.stats.STR and not p.stats.MIGHT then
        p.stats.MIGHT = p.stats.STR
        p.stats.AGILITY = p.stats.DEX
        p.stats.VIGOR = p.stats.CON
        p.stats.MIND = p.stats.INT
        p.stats.SPIRIT = p.stats.WIS
        p.stats.PRESENCE = p.stats.CHA
        p.stats.FAITH = 10
        -- Delete old keys after migration
        p.stats.STR = nil
        p.stats.DEX = nil
        p.stats.CON = nil
        p.stats.INT = nil
        p.stats.WIS = nil
        p.stats.CHA = nil
    end

    -- Calculate effective stats (base + equipment bonuses) WITHOUT modifying base stats
    -- This prevents the stat inflation bug where equipment bonuses accumulated on each call
    local effectiveMight = p.stats.MIGHT or 10
    local effectiveAgility = p.stats.AGILITY or 10
    local effectiveVigor = p.stats.VIGOR or 10
    local effectiveMind = p.stats.MIND or 10
    local effectiveSpirit = p.stats.SPIRIT or 10
    local effectivePresence = p.stats.PRESENCE or 10

    -- Add equipment stat bonuses to EFFECTIVE stats (not base stats!)
    if p.equipment.weapon then
        if p.equipment.weapon.MIGHT then effectiveMight = effectiveMight + p.equipment.weapon.MIGHT end
        if p.equipment.weapon.AGILITY then effectiveAgility = effectiveAgility + p.equipment.weapon.AGILITY end
        if p.equipment.weapon.MIND then effectiveMind = effectiveMind + p.equipment.weapon.MIND end
    end
    if p.equipment.armor then
        if p.equipment.armor.VIGOR then effectiveVigor = effectiveVigor + p.equipment.armor.VIGOR end
        if p.equipment.armor.AGILITY then effectiveAgility = effectiveAgility + p.equipment.armor.AGILITY end
        if p.equipment.armor.SPIRIT then effectiveSpirit = effectiveSpirit + p.equipment.armor.SPIRIT end
    end
    if p.equipment.accessory then
        if p.equipment.accessory.MIGHT then effectiveMight = effectiveMight + p.equipment.accessory.MIGHT end
        if p.equipment.accessory.AGILITY then effectiveAgility = effectiveAgility + p.equipment.accessory.AGILITY end
        if p.equipment.accessory.VIGOR then effectiveVigor = effectiveVigor + p.equipment.accessory.VIGOR end
        if p.equipment.accessory.MIND then effectiveMind = effectiveMind + p.equipment.accessory.MIND end
        if p.equipment.accessory.SPIRIT then effectiveSpirit = effectiveSpirit + p.equipment.accessory.SPIRIT end
        if p.equipment.accessory.PRESENCE then effectivePresence = effectivePresence + p.equipment.accessory.PRESENCE end
    end
    if p.equipment.shield then
        if p.equipment.shield.MIGHT then effectiveMight = effectiveMight + p.equipment.shield.MIGHT end
        if p.equipment.shield.AGILITY then effectiveAgility = effectiveAgility + p.equipment.shield.AGILITY end
        if p.equipment.shield.VIGOR then effectiveVigor = effectiveVigor + p.equipment.shield.VIGOR end
        if p.equipment.shield.MIND then effectiveMind = effectiveMind + p.equipment.shield.MIND end
        if p.equipment.shield.SPIRIT then effectiveSpirit = effectiveSpirit + p.equipment.shield.SPIRIT end
        if p.equipment.shield.PRESENCE then effectivePresence = effectivePresence + p.equipment.shield.PRESENCE end
    end

    -- Store effective stats for use elsewhere (e.g., tooltips, character sheet)
    p.effectiveStats = {
        MIGHT = effectiveMight,
        AGILITY = effectiveAgility,
        VIGOR = effectiveVigor,
        MIND = effectiveMind,
        SPIRIT = effectiveSpirit,
        PRESENCE = effectivePresence,
    }

    -- Get stat modifiers from EFFECTIVE stats
    local mightMod = getStatModifier(effectiveMight)
    local agilityMod = getStatModifier(effectiveAgility)
    local vigorMod = getStatModifier(effectiveVigor)
    local mindMod = getStatModifier(effectiveMind)
    local spiritMod = getStatModifier(effectiveSpirit)
    local presenceMod = getStatModifier(effectivePresence)

    -- Base attack includes Might modifier bonus
    p.attack = p.baseAttack + (mightMod * 2)  -- +2 damage per Might mod
    p.defense = p.baseDefense

    -- Equipment bonuses (attack/defense values)
    if p.equipment.weapon then
        local weaponAtk = p.equipment.weapon.attack or 0
        -- Check for weapon master talent
        if p.talents and p.talents.weapon_master then
            weaponAtk = math.floor(weaponAtk * 1.2)
        end
        p.attack = p.attack + weaponAtk
    end

    if p.equipment.armor then
        local armorDef = p.equipment.armor.defense or 0
        -- Check for armor expert talent
        if p.talents and p.talents.armor_expert then
            armorDef = math.floor(armorDef * 1.3)
        end
        p.defense = p.defense + armorDef
    end

    if p.equipment.shield then
        local shieldDef = p.equipment.shield.defense or 0
        p.defense = p.defense + shieldDef
    end

    -- Recalculate combat bonuses from Agility (using effective Agility)
    p.critChance = 5 + (agilityMod * 2)  -- Base 5% + 2% per Agility mod
    p.dodgeChance = math.max(0, agilityMod * 2)  -- 2% per Agility mod, min 0

    -- Add equipment crit bonus separately (after base calculation)
    if p.equipment.weapon and p.equipment.weapon.critBonus then
        p.critChance = p.critChance + p.equipment.weapon.critBonus
    end

    -- Apply talent bonuses using O(1) TALENT_LOOKUP table instead of O(n^2) loops
    if p.talents then
        for talentId, _ in pairs(p.talents) do
            local talentDef = TALENT_LOOKUP[talentId]  -- O(1) lookup!

            if talentDef and talentDef.effect then
                local e = talentDef.effect
                if e.critBonus then p.critChance = p.critChance + e.critBonus end
                if e.dodgeBonus then p.dodgeChance = p.dodgeChance + e.dodgeBonus end
                if e.defenseBonus then p.defense = p.defense + e.defenseBonus end
                if e.critDamageBonus then p.critDamage = (p.critDamage or 1.5) + e.critDamageBonus end
                if e.partySlotBonus then p.maxPartySize = (p.maxPartySize or 99) + e.partySlotBonus end
            end
        end

        -- HP multiplier from "tough" talent
        if p.talents.tough then
            -- This is applied during level up, not here
        end
    end

    -- Apply specialization bonuses
    if p.specialization then
        local spec = getPlayerSpecialization()
        if spec and spec.bonuses then
            local b = spec.bonuses
            if b.attackMult then p.attack = math.floor(p.attack * b.attackMult) end
            if b.defenseMult then p.defense = math.floor(p.defense * b.defenseMult) end
            if b.critBonus then p.critChance = p.critChance + b.critBonus end
            if b.dodgeBonus then p.dodgeChance = p.dodgeChance + b.dodgeBonus end
            if b.critDamageMult then p.critDamage = (p.critDamage or 1.5) * b.critDamageMult end
        end
    end

    -- Apply Ascension bonuses (prestige system)
    local ascBonus = M.getAscensionBonuses()
    if ascBonus then
        -- Apply all stats multiplier (from ascension count + Avatar skill)
        p.attack = math.floor(p.attack * ascBonus.allStatsMultiplier)
        p.defense = math.floor(p.defense * ascBonus.allStatsMultiplier)
        p.maxHP = math.floor(p.maxHP * ascBonus.allStatsMultiplier * ascBonus.hpMultiplier)
        p.maxMana = math.floor(p.maxMana * ascBonus.allStatsMultiplier * ascBonus.manaMultiplier)

        -- Apply combat bonuses
        p.critChance = p.critChance + ascBonus.critBonus
        p.critDamage = (p.critDamage or 1.5) + ascBonus.critDamageBonus
        p.dodgeChance = p.dodgeChance + ascBonus.dodgeBonus

        -- Store special ascension effects on player for combat system
        p.ascensionBonuses = {
            damageReduction = ascBonus.damageReduction,
            lifeSteal = ascBonus.lifeSteal,
            hpRegenPercent = ascBonus.hpRegenPercent,
            manaOnKill = ascBonus.manaOnKill,
            spellEchoChance = ascBonus.spellEchoChance,
            autoRevive = ascBonus.autoRevive,
            reviveHP = ascBonus.reviveHP,
            combatShield = ascBonus.combatShield,
            bossDamageMultiplier = ascBonus.bossDamageMultiplier,
            spellDamageMultiplier = ascBonus.spellDamageMultiplier,
            manaCostReduction = ascBonus.manaCostReduction,
            goldMultiplier = ascBonus.goldMultiplier,
            dropRateBonus = ascBonus.dropRateBonus,
            xpMultiplier = ascBonus.xpMultiplier,
        }
    end

    -- Apply racial + background bonuses
    local charBonus = M.getCharacterBonuses(p)
    if charBonus then
        p.maxHP = math.floor(p.maxHP * charBonus.maxHPMult)
        p.maxMana = math.floor(p.maxMana * charBonus.maxManaMult)
        p.defense = math.floor(p.defense * charBonus.defenseMult)
        p.critChance = (p.critChance or 5) + charBonus.critChanceBonus
        p.dodgeChance = (p.dodgeChance or 0) + charBonus.dodgeChanceBonus
        p.critDamage = (p.critDamage or 1.5) * charBonus.critDamageMult

        -- Store character bonuses on player for combat system
        p.characterBonuses = charBonus
    end

    -- Rescale companion stats so they grow with the player's level.
    -- Companions keep pace with enemy scaling (target ~65% of enemy stats).
    -- Enemy formulas: HP = 25 + level*12, ATK = 4 + level*3, DEF = 2 + level*2.
    -- Companion formulas: HP = baseHP + level*6.5, ATK = baseAtk + level*1.8, DEF = baseDef + level*1.1.
    if p.party then
        for _, companion in ipairs(p.party) do
            -- Level up companion to track player level (companion stays 0-1 levels behind)
            local targetLevel = math.max(1, p.level - 1)
            if companion.level < targetLevel then
                companion.level = targetLevel
            end
            -- Recalculate stats from class base + level scaling
            local cls = companion.class
            if cls then
                local oldMaxHP = companion.maxHP or 1
                companion.maxHP = math.floor(cls.baseHP + companion.level * 6.5)
                companion.attack = math.floor(cls.baseAtk + companion.level * 1.8)
                companion.defense = math.floor(cls.baseDef + companion.level * 1.1)
                -- Apply companion talent bonuses to base stats
                if companion.talents then
                    if companion.talents.tough then
                        companion.maxHP = math.floor(companion.maxHP * 1.15)
                    end
                    if companion.talents.sentinel then
                        companion.defense = companion.defense + 5
                    end
                end
                -- Scale current HP proportionally so companions don't get free full heals
                if oldMaxHP > 0 and companion.hp > 0 then
                    companion.hp = math.max(1, math.floor(companion.hp * companion.maxHP / oldMaxHP))
                end
                -- Rescale healer heal amount
                if cls.healAmount then
                    companion.healAmount = math.floor(10 + companion.level * 0.8)
                    if companion.talents and companion.talents.blessed then
                        companion.healAmount = math.floor(companion.healAmount * 1.3)
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- XP & LEVELING
-- ============================================================================

M.gainXP = function(amount)
    -- Check if already at max level
    if state.player.level >= MAX_LEVEL then
        return
    end

    -- Apply XP multiplier from ascension bonuses
    local ascBonus = M.getAscensionBonuses()
    if ascBonus and ascBonus.xpMultiplier and ascBonus.xpMultiplier > 1 then
        amount = math.floor(amount * ascBonus.xpMultiplier)
    end

    -- Apply racial/background XP bonus
    local charBonus = state.player.characterBonuses
    if charBonus and charBonus.xpMult > 1 then
        amount = math.floor(amount * charBonus.xpMult)
    end

    state.player.xp = state.player.xp + amount
    log("Gained " .. amount .. " XP!", {0.5, 0.8, 1})

    while state.player.xp >= state.player.xpToLevel and state.player.level < MAX_LEVEL do
        state.player.xp = state.player.xp - state.player.xpToLevel
        state.player.level = state.player.level + 1
        state.player.xpToLevel = math.floor(state.player.xpToLevel * 1.5)

        -- Check if reached max level - show ascension prompt
        if state.player.level >= MAX_LEVEL then
            state.player.xp = 0
            log("MAXIMUM LEVEL REACHED!", {1, 0.8, 0.2})

            -- Show ascension prompt if eligible
            local canAscend, _ = M.canAscend()
            if canAscend then
                local apPreview = M.calculateAscensionPoints()
                log("", {1, 1, 1})
                log("=== ASCENSION AVAILABLE ===", {0.8, 0.6, 1})
                log("You can now Ascend to reset your character and unlock", {0.7, 0.5, 0.9})
                log("the Ascension Tree - powerful abilities that persist forever!", {0.7, 0.5, 0.9})
                log("Projected AP reward: " .. apPreview, {0.9, 0.7, 0.3})
                log("Visit the Character Sheet to Ascend.", {0.6, 0.6, 0.7})
                state.player.canAscend = true
            end
        end

        local p = state.player
        local class = p.class

        -- Initialize stats if not present (for old saves)
        if not p.stats then
            local baseStats = CLASS_BASE_STATS[class.id] or CLASS_BASE_STATS.warrior
            p.stats = {
                MIGHT = baseStats.MIGHT or 10, AGILITY = baseStats.AGILITY or 10, VIGOR = baseStats.VIGOR or 10,
                MIND = baseStats.MIND or 10, SPIRIT = baseStats.SPIRIT or 10, PRESENCE = baseStats.PRESENCE or 10,
                FAITH = baseStats.FAITH or 10,
            }
        end

        -- Get VIGOR modifier for HP bonus, MIND modifier for mana bonus
        local vigorMod = getStatModifier(p.stats.VIGOR or 10)
        local mindMod = getStatModifier(p.stats.MIND or 10)

        -- HP gain: base + Vigor modifier bonus
        local hpGain = math.floor(class.baseHP * 0.1) + (vigorMod * 2)
        -- Apply "tough" talent multiplier
        if p.talents and p.talents.tough then
            hpGain = math.floor(hpGain * 1.15)
        end
        p.maxHP = p.maxHP + hpGain
        p.hp = p.maxHP

        -- Mana gain: base + Mind modifier bonus
        local manaGain = math.floor(class.baseMana * 0.1) + (mindMod * 2)
        -- Apply "focused" talent multiplier
        if p.talents and p.talents.focused then
            manaGain = math.floor(manaGain * 1.2)
        end
        p.maxMana = p.maxMana + manaGain
        p.mana = p.maxMana

        p.baseAttack = p.baseAttack + 2
        p.baseDefense = p.baseDefense + 1

        -- Award skill point (starting at level 2)
        p.skillPoints = (p.skillPoints or 0) + 1
        log("Gained 1 skill point! (Total: " .. p.skillPoints .. ")", {0.3, 0.8, 0.9})

        -- Check for talent unlock (every 3 levels: 3, 6, 9, 12, etc.)
        if p.level % 3 == 0 then
            p.pendingTalentSelection = true
            log("NEW TALENT available! Open character sheet to select.", {0.9, 0.7, 0.2})
        end

        -- Check for specialization at level 10
        if p.level == 10 and not p.specialization then
            p.pendingSpecialization = true
            state.showSpecializationSelection = true
            log("", {1, 1, 1})
            log("=== SPECIALIZATION UNLOCKED ===", {1, 0.8, 0.2})
            log("Choose your advanced class path!", {0.9, 0.7, 0.3})
        end

        calculateStats()
        log("LEVEL UP! Now level " .. p.level, {1, 0.8, 0.2})
        addJournalEvent("levelup", "Reached Level " .. p.level .. "!", {1, 0.8, 0.2})
    end

    -- Share XP with living companions
    if state.player.party then
        for _, comp in ipairs(state.player.party) do
            if comp.hp > 0 then
                M.companionGainXP(comp, amount)
            end
        end
    end
end

-- ============================================================================
-- COMPANION PROGRESSION
-- ============================================================================

--- Auto-allocate skill points and talents for a companion.
-- Called automatically on level-up when companion.autoAllocate is true.
M.autoAllocateCompanion = function(companion)
    local classId = companion.class and companion.class.id
    if not classId then return end

    -- Auto-spend skill points (prefer region matching companion role)
    if companion.skillPoints > 0 then
        local tree = Data.SKILL_TREES.universal
        if tree and tree.nodes then
            if not companion.unlockedSkills then companion.unlockedSkills = {start = true} end

            -- Determine preferred region by class
            local preferredRegion
            if classId == "soldier" or classId == "berserker" then
                preferredRegion = "warfare"
            elseif classId == "archer" or classId == "thief" then
                preferredRegion = "shadow"
            elseif classId == "battlemage" then
                preferredRegion = "sorcery"
            elseif classId == "healer" then
                preferredRegion = "survival"
            end

            local function canUnlockNode(node)
                if companion.unlockedSkills[node.id] then return false end
                if node.cost > companion.skillPoints then return false end
                if node.cost == 0 then return false end  -- start node
                for _, connId in ipairs(node.connections or {}) do
                    if companion.unlockedSkills[connId] then return true end
                end
                return false
            end

            -- Try preferred region first, then any
            for _, tryPreferred in ipairs({true, false}) do
                -- Sort by cost (prefer cheaper nodes first)
                for _, cost in ipairs({1, 2, 3}) do
                    for _, node in ipairs(tree.nodes) do
                        if node.cost == cost then
                            local regionMatch = (not tryPreferred) or (node.region == preferredRegion)
                            if regionMatch and canUnlockNode(node) then
                                companion.skillPoints = companion.skillPoints - node.cost
                                companion.unlockedSkills[node.id] = true
                                log(companion.name .. " learned " .. node.name .. "!", {0.3, 0.9, 0.5})
                                return  -- One skill per auto-allocate
                            end
                        end
                    end
                end
            end
        end
    end

    -- Auto-pick talent if pending
    if companion.pendingTalentSelection then
        local available = {}

        -- Universal talents
        for _, t in ipairs(Data.UNIVERSAL_TALENTS) do
            if t.level <= companion.level and not (companion.talents and companion.talents[t.id]) then
                table.insert(available, t)
            end
        end

        -- Class talents via mapping
        local mappedClass = Data.COMPANION_CLASS_MAP[classId]
        if mappedClass and Data.CLASS_TALENTS[mappedClass] then
            for _, t in ipairs(Data.CLASS_TALENTS[mappedClass]) do
                if t.level <= companion.level and not (companion.talents and companion.talents[t.id]) then
                    table.insert(available, t)
                end
            end
        end

        if #available > 0 then
            -- Priority preferences by role
            local preferred
            if classId == "soldier" or classId == "berserker" then
                preferred = {tough = true, sentinel = true, weapon_master = true, armor_expert = true}
            elseif classId == "archer" or classId == "thief" or classId == "battlemage" then
                preferred = {lucky = true, deadly = true, precision = true, spell_power = true}
            elseif classId == "healer" then
                preferred = {focused = true, blessed = true, quick = true}
            end

            -- Try preferred first
            local chosen = nil
            if preferred then
                for _, t in ipairs(available) do
                    if preferred[t.id] then
                        chosen = t
                        break
                    end
                end
            end
            -- Fall back to first available
            if not chosen then
                chosen = available[1]
            end

            companion.talents[chosen.id] = true
            companion.pendingTalentSelection = false
            log(companion.name .. " gained talent: " .. chosen.name .. "!", {0.9, 0.7, 0.2})
        end
    end
end

--- Grant XP to a companion and handle level-ups.
-- Mirrors player gainXP but simplified (no ascension, no specialization, no mana).
M.companionGainXP = function(companion, amount)
    if not companion or not companion.class then return end
    if (companion.level or 1) >= MAX_LEVEL then return end

    companion.xp = (companion.xp or 0) + amount
    companion.xpToLevel = companion.xpToLevel or 100

    while companion.xp >= companion.xpToLevel and companion.level < MAX_LEVEL do
        companion.xp = companion.xp - companion.xpToLevel
        companion.level = companion.level + 1
        companion.xpToLevel = math.floor(companion.xpToLevel * 1.5)

        local cls = companion.class

        -- Stat increases
        local hpGain = math.floor(cls.baseHP * 0.08)
        if companion.talents and companion.talents.tough then
            hpGain = math.floor(hpGain * 1.15)
        end
        companion.maxHP = companion.maxHP + hpGain
        companion.hp = companion.maxHP  -- Heal to full on level-up
        companion.attack = companion.attack + 2
        companion.defense = companion.defense + 1

        -- Rescale healer heal amount
        if cls.healAmount then
            companion.healAmount = math.floor(10 + companion.level * 0.8)
        end

        -- Award skill point
        companion.skillPoints = (companion.skillPoints or 0) + 1

        -- Check for talent unlock (every 3 levels)
        if companion.level % 3 == 0 then
            companion.pendingTalentSelection = true
        end

        -- Auto-allocate if enabled
        if companion.autoAllocate then
            M.autoAllocateCompanion(companion)
        end

        log(companion.name .. " reached level " .. companion.level .. "!", {0.8, 0.7, 0.3})
    end
end

return M
