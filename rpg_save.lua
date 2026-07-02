-- RPG Save/Load System
-- Extracted from textrpg.lua
-- Contains: save(), load(), getSharedStats(), exit(), hasOverlayOpen(), handleEscape()

local M = {}

-- External modules (loaded once via require)
local MapEnemies = require("mapenemies")
local LuminaryPatrols = require("luminarypatrols")
local WorldGen = require("worldgen")
local PropertySystem = require("propertysystem")

-- Upvalues set by register()
local state           -- module-level state table from textrpg
local F               -- helper function table from textrpg (contains countExploredTiles, getStatModifier, calculateStats, checkAllRaceUnlocks, exitDungeon, cancelTravelingHome, cancelPaidTravel)
local TextRPG         -- reference to main TextRPG table
local graveyard       -- graveyard table from textrpg
local CLASS_BASE_STATS -- class base stats table from textrpg
local log             -- log function from textrpg (local log = function(text, color) ...)

--- Register upvalues from textrpg.lua.
-- Must be called before any other function in this module.
-- @param s           state table (textrpg module-level local)
-- @param f           F function table (textrpg helper functions)
-- @param rpg         TextRPG module table
-- @param gy          graveyard table
-- @param cbs         CLASS_BASE_STATS table
-- @param logFn       log function
function M.register(s, f, rpg, gy, cbs, logFn)
    state = s
    F = f
    TextRPG = rpg
    graveyard = gy
    CLASS_BASE_STATS = cbs
    log = logFn
end

--- Save RPG state to PlayerData.
-- Copied verbatim from textrpg.lua lines 13718-13835.
function M.save()
    -- === SYNC GOLD WITH MAIN GAME ===
    -- Update PlayerData.coins to match current RPG gold (main game currency)
    if state.player then
        PlayerData.coins = state.player.gold or 0
    end

    -- Save Map Enemies state BEFORE modifying state.world
    -- (getSaveData reads state.world.mapEnemies)
    local mapEnemiesSaveData = MapEnemies.getSaveData()

    -- Clean transient map enemy state before save (avoid circular references and data duplication)
    -- Map enemies are saved separately in PlayerData.textRPGMapEnemies
    local savedMapEnemies = nil
    local savedMapEnemiesDefeated = nil
    if state.world then
        state.world.currentMapEnemy = nil
        savedMapEnemies = state.world.mapEnemies
        savedMapEnemiesDefeated = state.world.mapEnemiesDefeated
        state.world.mapEnemies = nil  -- Excluded from world save (saved separately)
        state.world.mapEnemiesDefeated = nil
    end

    -- Clean transient dungeon visible enemy state before save
    -- (visibleEnemies contain object references that would cause duplication;
    --  they are regenerated from floor.enemies on load via initFloorEnemies)
    local savedDungeonVisibleEnemies = {}
    local savedPrisonGuard = nil
    if state.dungeon and state.dungeon.floors then
        state.dungeon.currentVisibleEnemy = nil
        -- Strip transient prison guard reference (restored after save)
        savedPrisonGuard = state.dungeon.currentPrisonGuard
        state.dungeon.currentPrisonGuard = nil
        for i, floor in ipairs(state.dungeon.floors) do
            savedDungeonVisibleEnemies[i] = floor.visibleEnemies
            floor.visibleEnemies = nil  -- Strip before save; rebuilt on load
        end
    end

    PlayerData.textRPG = {
        player = state.player,
        world = state.world,
        stats = state.stats,
        phase = state.phase,
        dungeon = state.dungeon,
        inDungeon = state.inDungeon,
        townPlayerX = state.townPlayerX,
        townPlayerY = state.townPlayerY,
        camping = state.camping,
        townVampireLairs = state.townVampireLairs,
        vampireSpreadTimer = state.vampireSpreadTimer,
        -- New NPC expansion systems
        npcRelationships = state.npcRelationships,
        townReputation = state.townReputation,
        factionReputation = state.factionReputation,
        quests = state.quests,
        townEvents = state.townEvents,
        timeOfDay = state.timeOfDay,
        daysPassed = state.daysPassed,
        -- Prison escape system
        prisonEscape = state.prisonEscape,
        inPrisonEscape = state.inPrisonEscape,
    }

    -- Save WorldGen state (for lich lairs, corruption, visited chunks)
    PlayerData.textRPGWorldGen = WorldGen.getSaveData()
    PlayerData.textRPGLichLairs = WorldGen.getLichLairSaveData and WorldGen.getLichLairSaveData() or nil

    -- Save Luminary Patrols state
    PlayerData.textRPGLuminaryPatrols = LuminaryPatrols.getSaveData()

    -- Save Map Enemies state (pre-computed above before world was modified)
    PlayerData.textRPGMapEnemies = mapEnemiesSaveData

    -- Restore map enemies in state.world after save (so game continues normally)
    if state.world then
        state.world.mapEnemies = savedMapEnemies or {}
        state.world.mapEnemiesDefeated = savedMapEnemiesDefeated or 0
    end

    -- Restore dungeon visible enemies after save (so game continues normally)
    if state.dungeon and state.dungeon.floors then
        for i, floor in ipairs(state.dungeon.floors) do
            floor.visibleEnemies = savedDungeonVisibleEnemies[i]
        end
        -- Restore transient prison guard reference
        state.dungeon.currentPrisonGuard = savedPrisonGuard
    end

    -- Share stats with other game modes (including race unlock tracking)
    if state.player then
        PlayerData.rpgStats = {
            level = state.player.level,
            class = state.player.class and state.player.class.name or "Unknown",
            gold = state.player.gold,
            enemiesDefeated = state.stats.enemiesDefeated or 0,
            questsCompleted = state.stats.questsCompleted or 0,
            itemsFound = state.stats.itemsFound or 0,
            townsVisited = state.world.towns and #state.world.towns or 0,
            tilesExplored = F.countExploredTiles(),
            mapExpansions = state.world.expansionCount or 0,
            -- Additional stats for race unlocks
            goldEarned = state.stats.goldEarned or 0,
            healingDone = state.stats.healingDone or 0,
            itemsCrafted = state.stats.itemsCrafted or 0,
            stealthKills = state.stats.stealthKills or 0,
            fishCaught = state.stats.fishCaught or 0,
            deaths = state.stats.deaths or 0,
            mapEnemiesDefeated = state.world.mapEnemiesDefeated or 0,
        }

        -- Check for race unlocks after saving
        F.checkAllRaceUnlocks()
    end

    savePlayerData()
end

--- Load RPG state from PlayerData.
-- Copied verbatim from textrpg.lua lines 13837-14143.
-- @return true if save data was found and loaded, false otherwise
function M.load()
    if PlayerData.textRPG then
        state.player = PlayerData.textRPG.player
        state.world = PlayerData.textRPG.world
        state.stats = PlayerData.textRPG.stats
        state.phase = PlayerData.textRPG.phase or "town"
        -- Restore prison escape state
        state.prisonEscape = PlayerData.textRPG.prisonEscape
        state.inPrisonEscape = PlayerData.textRPG.inPrisonEscape or false

        -- === SYNC GOLD WITH MAIN GAME ===
        -- Use PlayerData.coins as the source of truth (main game currency)
        if state.player then
            PlayerData.coins = PlayerData.coins or 0
            state.player.gold = PlayerData.coins  -- Sync from main game coins
        end

        -- Restore dungeon flags early so transient phase reset can check them
        state.dungeon = PlayerData.textRPG.dungeon or nil
        state.inDungeon = PlayerData.textRPG.inDungeon or false

        -- Reset transient phases that don't persist properly across saves
        -- These phases require runtime state that isn't saved/serializable
        local transientToTown = {
            burglary_success = true,
            lockpicking = true,
            lockpick_prompt = true,
            property_purchase = true,
            property_manage = true,
            jailed = true,           -- runtime jail state not serializable
            jail = true,             -- runtime jail state (from caught burglarizing)
            dialogue = true,         -- NPC dialogue state not serializable
            npc_dialogue = true,     -- NPC dialogue state not serializable
            tavern_interior = true,  -- interior state not serializable
            guild_interior = true,   -- interior state not serializable
            building_interior = true,-- interior state not serializable
            revive_hero = true,      -- transient UI
            district = true,         -- state.currentDistrict not serializable
            guild_hall = true,       -- state.currentGuildHall not serializable
            underbelly = true,       -- state.currentUnderbelly not serializable
            bounty_board = true,     -- town sub-phase, safer to reset to town
            courier_office = true,   -- town sub-phase, safer to reset to town
            land_claim = true,       -- state.landClaimX/Y not serializable
            land_manage = true,      -- state.landClaimX/Y not serializable
        }
        local transientToMap = {
            combat = true,           -- enemy instances not serializable
            tactical_combat = true,  -- tacticalState not serializable
            stealth_approach = true, -- stealthApproach state not serializable
            traveling_home = true,   -- travel state not serializable
            paid_travel = true,      -- travel state not serializable
        }
        if transientToTown[state.phase] then
            state.phase = "town"
            state.lockpickTarget = nil
            state.lockpickState = nil
            state.burglaryLoot = nil
            state.jailState = nil
            state.currentDistrict = nil
            state.currentGuildHall = nil
            state.currentUnderbelly = nil
            state.landClaimX = nil
            state.landClaimY = nil
        elseif transientToMap[state.phase] then
            -- Combat/travel phases reset to map (or dungeon if in dungeon)
            if state.inDungeon and state.dungeon then
                state.phase = "dungeon"
            else
                state.phase = "map"
            end
        end

        -- Initialize expansion tracking if not present
        state.world.expansionCount = state.world.expansionCount or 0
        state.world.westOffset = state.world.westOffset or 0
        state.world.eastOffset = state.world.eastOffset or 0
        state.world.northOffset = state.world.northOffset or 0
        state.world.southOffset = state.world.southOffset or 0
        -- Initialize map enemies for old saves
        state.world.mapEnemies = state.world.mapEnemies or {}
        state.world.mapEnemiesDefeated = state.world.mapEnemiesDefeated or 0
        -- Initialize party system if not present
        if state.player then
            state.player.party = state.player.party or {}
            state.player.maxPartySize = math.max(state.player.maxPartySize or 99, 99)

            -- === MIGRATE: Companion progression fields ===
            for _, comp in ipairs(state.player.party) do
                comp.xp = comp.xp or 0
                comp.xpToLevel = comp.xpToLevel or math.floor(100 * (1.5 ^ math.max(0, (comp.level or 1) - 1)))
                comp.skillPoints = comp.skillPoints or 0
                -- Migrate unlockedSkills from array to dictionary format
                if comp.unlockedSkills then
                    local first = next(comp.unlockedSkills)
                    if type(first) == "number" then
                        local dict = {start = true}
                        for _, skillId in ipairs(comp.unlockedSkills) do
                            dict[skillId] = true
                        end
                        comp.unlockedSkills = dict
                    else
                        comp.unlockedSkills.start = true
                    end
                else
                    comp.unlockedSkills = {start = true}
                end
                comp.talents = comp.talents or {}
                comp.pendingTalentSelection = comp.pendingTalentSelection or false
                comp.autoAllocate = (comp.autoAllocate == nil) and true or comp.autoAllocate
            end

            -- === MIGRATE OLD SAVES: Add stat system ===
            if not state.player.stats or not state.player.stats.MIGHT then
                local classId = state.player.class and state.player.class.id or "warrior"
                local baseStats = CLASS_BASE_STATS[classId] or CLASS_BASE_STATS.warrior
                local oldStats = state.player.stats or {}
                state.player.stats = {
                    MIGHT = oldStats.MIGHT or oldStats.STR or baseStats.MIGHT or 10,
                    AGILITY = oldStats.AGILITY or oldStats.DEX or baseStats.AGILITY or 10,
                    VIGOR = oldStats.VIGOR or oldStats.CON or baseStats.VIGOR or 10,
                    MIND = oldStats.MIND or oldStats.INT or baseStats.MIND or 10,
                    SPIRIT = oldStats.SPIRIT or oldStats.WIS or baseStats.SPIRIT or 10,
                    PRESENCE = oldStats.PRESENCE or oldStats.CHA or baseStats.PRESENCE or 10,
                    FAITH = oldStats.FAITH or baseStats.FAITH or 10,
                }
            end

            -- === MIGRATE OLD SAVES: Convert old equipment stat keys ===
            local oldToNew = {STR="MIGHT", DEX="AGILITY", CON="VIGOR", INT="MIND", WIS="SPIRIT", CHA="PRESENCE"}
            for _, slot in ipairs({"weapon", "armor", "accessory"}) do
                local equip = state.player.equipment and state.player.equipment[slot]
                if equip then
                    for oldKey, newKey in pairs(oldToNew) do
                        if equip[oldKey] and not equip[newKey] then
                            equip[newKey] = equip[oldKey]
                            equip[oldKey] = nil
                        end
                    end
                end
            end

            -- === MIGRATE OLD SAVES: Convert old originalStats keys (vampire) ===
            if state.player.originalStats then
                for oldKey, newKey in pairs(oldToNew) do
                    if state.player.originalStats[oldKey] and not state.player.originalStats[newKey] then
                        state.player.originalStats[newKey] = state.player.originalStats[oldKey]
                        state.player.originalStats[oldKey] = nil
                    end
                end
            end

            -- === MIGRATE OLD SAVES: Add karma/crime system ===
            if not state.player.karma then
                state.player.karma = 0
                state.player.bounty = 0
                state.player.crimes = {}
                state.player.isJailed = false
                state.player.jailTimeRemaining = 0
            end

            -- === MIGRATE OLD SAVES: Add faction system ===
            if not state.player.factionRep then
                state.player.factionRep = {}
                state.player.joinedFactions = {}
            end

            -- === MIGRATE OLD SAVES: Add vampire system ===
            if state.player.isVampire == nil then
                state.player.isVampire = false
                state.player.vampireTransformDate = nil
                state.player.vampireTransformLevel = nil
                state.player.vampireSkillTree = {}
                state.player.originalStats = nil
                state.player.hasVampireCoffin = false
                state.player.vampireClothWrapped = false
                state.player.sunlightDamageTimer = 0
            end

            -- Migrate NPCs for vampire system
            for _, npc in ipairs(state.npcs or {}) do
                if npc.isVampire == nil then
                    npc.isVampire = false
                end
            end

            state.cityVampireCount = state.cityVampireCount or {}
            state.vampireHuntersActive = state.vampireHuntersActive or false
            state.vampireSpreadTimer = 0
            state.townVampireLairs = state.townVampireLairs or {}  -- Hidden vampire lairs in towns

            -- === MIGRATE OLD SAVES: Add NPC expansion systems ===
            state.npcRelationships = state.npcRelationships or {}
            state.townReputation = state.townReputation or {}
            state.factionReputation = state.factionReputation or {
                merchants_guild = 0,
                church = 0,
                thieves_guild = 0,
                mages_guild = 0,
                guards = 0,
            }
            state.quests = state.quests or {
                available = {},
                active = {},
                completed = {},
                completedTimestamps = {},
            }
            state.townEvents = state.townEvents or {
                activeEvents = {},
                lastCheckedDay = 0,
            }
            state.timeOfDay = state.timeOfDay or 12
            state.daysPassed = state.daysPassed or 0

            -- === MIGRATE OLD SAVES: Add stealth system ===
            if state.player.stealthMode == nil then
                state.player.stealthMode = false
                state.player.lastDetectionCheck = 0
                state.player.stealthXPBonus = 0
            end
            -- === MIGRATE OLD SAVES: Add comprehensive stealth system ===
            if not state.player.stealthPerks then
                state.player.stealth = state.player.stealth or 10
                state.player.equipmentStealthMod = state.player.equipmentStealthMod or 0
                state.player.classStealthBonus = state.player.classStealthBonus or 0
                state.player.skillStealthMod = state.player.skillStealthMod or 0
                state.player.stealthPerks = {
                    silent_step = false,
                    shadow_blend = false,
                    assassinate = false,
                    vanish = false,
                    scouts_sight = false,
                }
                state.player.stealthKills = state.player.stealthKills or 0
                state.player.stealthKnockouts = state.player.stealthKnockouts or 0
            end

            -- === MIGRATE OLD SAVES: Add journal system ===
            if not state.player.journal then
                state.player.journal = {
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
                            regionsVisited = {},
                        },
                        economy = {
                            goldEarned = 0,
                            goldSpent = 0,
                            itemsSold = 0,
                            itemsBought = 0,
                        },
                        social = {
                            questsAccepted = 0,
                            questsCompleted = 0,
                            npcInteractions = 0,
                            factionMissions = 0,
                        },
                    },
                }
            end

            -- Initialize skill tree system
            if not state.player.skillPoints then
                -- Grant retroactive skill points (1 per level after level 1)
                state.player.skillPoints = math.max(0, state.player.level - 1)
            end
            -- Migrate unlockedSkills from array to dictionary format
            if state.player.unlockedSkills then
                local first = next(state.player.unlockedSkills)
                if type(first) == "number" then
                    local dict = {start = true}
                    for _, skillId in ipairs(state.player.unlockedSkills) do
                        dict[skillId] = true
                    end
                    state.player.unlockedSkills = dict
                else
                    state.player.unlockedSkills.start = true
                end
            else
                state.player.unlockedSkills = {start = true}
            end

            -- Initialize talent system
            state.player.talents = state.player.talents or {}
            if state.player.pendingTalentSelection == nil then
                -- Check if player should have pending talents from past level ups
                local talentMilestones = math.floor(state.player.level / 3)
                local talentsOwned = 0
                for _ in pairs(state.player.talents) do talentsOwned = talentsOwned + 1 end
                if talentsOwned < talentMilestones then
                    state.player.pendingTalentSelection = true
                else
                    state.player.pendingTalentSelection = false
                end
            end

            -- Initialize specialization for old saves
            if state.player.level >= 10 and not state.player.specialization then
                state.player.pendingSpecialization = true
                state.showSpecializationSelection = true
            end

            -- Initialize combat bonuses
            local agilityMod = F.getStatModifier(state.player.stats.AGILITY or 10)
            state.player.critChance = state.player.critChance or (5 + agilityMod * 2)
            state.player.dodgeChance = state.player.dodgeChance or (agilityMod * 2)
            state.player.critDamage = state.player.critDamage or 1.5

            -- Recalculate stats with new system
            F.calculateStats()

            -- Initialize property system
            state.player.properties = state.player.properties or {
                townProperties = {},
                landClaims = {},
                settlements = {},
            }
            PropertySystem.init(state)
        end
        -- Dungeon state already restored early (before transient phase reset).
        -- The phase correction below is a safety net in case ordering changes.
        if state.inDungeon and state.dungeon and state.phase == "map" then
            state.phase = "dungeon"
        end
        -- Restore town player position
        state.townPlayerX = PlayerData.textRPG.townPlayerX
        state.townPlayerY = PlayerData.textRPG.townPlayerY
        -- Restore camping state
        state.camping = PlayerData.textRPG.camping
        -- Restore vampire system state
        state.townVampireLairs = PlayerData.textRPG.townVampireLairs or {}
        state.vampireSpreadTimer = PlayerData.textRPG.vampireSpreadTimer or 0

        -- Restore WorldGen state (for lich lairs, corruption, visited chunks)
        if PlayerData.textRPGWorldGen then
            WorldGen.loadSaveData(PlayerData.textRPGWorldGen)
        end
        if PlayerData.textRPGLichLairs and WorldGen.loadLichLairSaveData then
            WorldGen.loadLichLairSaveData(PlayerData.textRPGLichLairs)
        end

        -- Restore Luminary Patrols state
        if PlayerData.textRPGLuminaryPatrols then
            LuminaryPatrols.loadSaveData(PlayerData.textRPGLuminaryPatrols)
        end

        -- If this is a WorldGen save, ensure chunks are loaded around player
        if state.world.useWorldGen then
            WorldGen.updateLoadedChunks(state.world.playerX, state.world.playerY)
        else
            -- Legacy save: ensure mapData structure is present
            -- These saves will continue using the legacy expansion system
            if not state.world.mapData then
                state.world.mapData = {}
            end
            state.world.mapWidth = state.world.mapWidth or 15
            state.world.mapHeight = state.world.mapHeight or 15
        end

        return true
    end
    return false
end

--- Get RPG stats for other modes to use.
-- Copied verbatim from textrpg.lua lines 14146-14158.
function M.getSharedStats()
    return PlayerData.rpgStats or {
        level = 0,
        class = "None",
        gold = 0,
        enemiesDefeated = 0,
        questsCompleted = 0,
        itemsFound = 0,
        townsVisited = 0,
        tilesExplored = 0,
        mapExpansions = 0,
    }
end

--- Exit function - saves progress automatically.
-- Copied verbatim from textrpg.lua lines 14161-14166.
function M.exit()
    if state.player then
        M.save()
        log("Progress saved!", {0.5, 0.9, 0.5})
    end
end

--- Check if an overlay or sub-menu is currently open (used by pause menu to decide behavior).
-- Copied verbatim from textrpg.lua lines 14169-14177.
function M.hasOverlayOpen()
    if not state then return false end
    return state.showCharacterSheet or state.showSkillTree or
           state.showTalentSelection or state.showAscensionTree or
           state.showSpecializationSelection or state.showDevModePrompt or
           state.showPartyUI or
           state.fullMapOpen or
           (state.player and state.player.journal and state.player.journal.isOpen) or
           false
end

--- Try to handle ESC internally (close overlays). Returns true if ESC was consumed.
-- Copied verbatim from textrpg.lua lines 14180-14265.
function M.handleEscape()
    if not state then return false end

    -- Close overlays in priority order (journal first since it draws on top)
    if state.player and state.player.journal and state.player.journal.isOpen then
        state.player.journal.isOpen = false
        return true
    end
    if state.showPartyUI then
        state.showPartyUI = false
        state.partyUIScroll = 0
        return true
    end
    if state.showDevModePrompt then
        state.showDevModePrompt = false
        state.devModePassword = ""
        state.devModePasswordError = false
        return true
    end
    if state.fullMapOpen then
        state.fullMapOpen = false
        return true
    end
    if state.showSpecializationSelection then
        state.showSpecializationSelection = false
        return true
    end
    if state.showAscensionTree then
        state.showAscensionTree = false
        return true
    end
    if state.showTalentSelection then
        state.showTalentSelection = false
        return true
    end
    if state.showSkillTree then
        state.showSkillTree = false
        return true
    end
    if state.showCharacterSheet then
        state.showCharacterSheet = false
        return true
    end

    -- Close sub-phases that should return to town
    if state.phase == "inventory" or state.phase == "shop" or state.phase == "quest_log" or
       state.phase == "npc_list" or state.phase == "job_board" or state.phase == "stable" or
       state.phase == "guild" or state.phase == "party" or state.phase == "market" or
       state.phase == "lockpick_prompt" or state.phase == "burglary_success" then
        state.lockpickTarget = nil
        state.lockpickState = nil
        state.burglaryLoot = nil
        state.phase = "town"
        return true
    end
    if state.phase == "traveling_home" then
        F.cancelTravelingHome()
        return true
    end
    if state.phase == "paid_travel" then
        F.cancelPaidTravel()
        return true
    end
    if state.phase == "dialogue" then
        state.phase = "town"
        return true
    end
    if state.phase == "dungeon" then
        -- Leave dungeon only if at entrance on floor 1
        if state.dungeon and state.dungeon.currentFloor == 1 then
            local floor = state.dungeon.floors[1]
            if floor then
                local tile = floor.grid[state.dungeon.playerY] and floor.grid[state.dungeon.playerY][state.dungeon.playerX]
                if tile and tile.type == "entrance" then
                    F.exitDungeon()
                    return true
                end
            end
        end
        -- If not at entrance, ESC does not exit dungeon -- open pause menu instead
        return false
    end

    -- For combat, class_select, death: do NOT consume ESC (let pause menu open)
    if state.phase == "combat" or state.phase == "class_select" or state.phase == "death" then
        return false
    end

    -- For any other phase (map, town, camp, etc.): do NOT consume ESC (let pause menu open)
    return false
end

return M
