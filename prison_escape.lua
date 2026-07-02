-- Prison Escape Starting Sequence - The Sunken Ledger
-- A multi-floor dungeon prison where the player begins their adventure.
-- Players wake up in a cell, must lockpick cuffs, gather allies, navigate
-- guard patrols, fight beasts, defeat bosses, and escape to the surface.

local PrisonEscape = {}
local Backpack = require("backpack")
local RpgDungeon = require("rpg_dungeon")

-- ============================================================================
--                         PRISON CONFIGURATION
-- ============================================================================

-- Floor layout: The Sunken Ledger (condensed, 2 floors).
-- Floor 1: Cell Block & General Population - player starts here, all allies
-- Floor 2: Surface exit - docks, final boss (Warden Blackthorn)

PrisonEscape.NUM_FLOORS = 2
PrisonEscape.FLOOR_WIDTH = 18
PrisonEscape.FLOOR_HEIGHT = 14

-- Guard patrol schedule (in-game hours)
-- Guards rotate patrols every 4 hours. During shift change (every 4th hour),
-- there is a 2-minute window with reduced patrols.
PrisonEscape.GUARD_PATROL_INTERVAL = 4  -- hours between patrol rotations
PrisonEscape.SHIFT_CHANGE_WINDOW = 2    -- minutes of reduced coverage

-- Cuffs debuff: applied at start, removed via lockpicking
PrisonEscape.CUFFS_DEBUFF = {
    id = "prison_cuffs",
    name = "Iron Cuffs",
    description = "Heavy iron cuffs bind your wrists. All stats reduced until removed.",
    statPenalty = {
        MIGHT = -2,
        AGILITY = -3,
        VIGOR = -1,
        MIND = 0,
        SPIRIT = -1,
        PRESENCE = -1,
    },
    attackPenalty = -2,
    defensePenalty = -1,
    speedPenalty = 0.75,  -- 25% slower movement
    canCast = false,     -- Cannot cast spells with cuffs on (mages get basic magic after removal)
}

-- ============================================================================
--                         PRISON CRAFTING RECIPES
-- ============================================================================

PrisonEscape.CRAFTING_RECIPES = {
    -- Tier 1: Improvised weapons (craftable from scavenged prison materials)
    {
        id = "bone_shank",
        name = "Bone Shank",
        description = "A sharpened bone fragment. Crude but deadly in close quarters.",
        category = "weapon",
        type = "melee",
        materials = {
            {id = "bone_fragment", qty = 2},
        },
        baseStats = {attack = 3, speed = 1.2},
        skillRequired = 0,
        icon = "BONE",
    },
    {
        id = "prison_shiv",
        name = "Prison Shiv",
        description = "A thin metal spike wrapped in cloth. The weapon of choice for the desperate.",
        category = "weapon",
        type = "melee",
        materials = {
            {id = "scrap_metal", qty = 1},
            {id = "cloth_strip", qty = 1},
        },
        baseStats = {attack = 5, speed = 1.5, critChance = 0.15},
        skillRequired = 0,
        icon = "SHIV",
    },
    {
        id = "makeshift_club",
        name = "Makeshift Club",
        description = "A broken chair leg reinforced with wire. Slow but hits hard.",
        category = "weapon",
        type = "melee",
        materials = {
            {id = "wood_scrap", qty = 2},
            {id = "wire_coil", qty = 1},
        },
        baseStats = {attack = 7, speed = 0.8, stunChance = 0.10},
        skillRequired = 0,
        icon = "CLUB",
    },
    {
        id = "makeshift_magic_focus",
        name = "Makeshift Magic Focus",
        description = "A crude focus cobbled from crystal shards and copper wire. Allows basic spellcasting.",
        category = "weapon",
        type = "magic_focus",
        materials = {
            {id = "prison_crystal_shard", qty = 1},
            {id = "wire_coil", qty = 1},
        },
        baseStats = {magicPower = 4, manaCost = -1},
        skillRequired = 0,
        icon = "FOCUS",
    },
    {
        id = "sling_shot",
        name = "Improvised Sling",
        description = "A strip of leather and some pebbles. Ranged but weak.",
        category = "weapon",
        type = "ranged",
        materials = {
            {id = "cloth_strip", qty = 2},
            {id = "stone_chunk", qty = 3},
        },
        baseStats = {attack = 4, range = 3, speed = 1.0},
        skillRequired = 0,
        icon = "SLING",
    },
    -- Tier 2: Better gear from armory materials
    {
        id = "guard_sword",
        name = "Guard's Short Sword",
        description = "A standard-issue prison guard blade. Serviceable steel.",
        category = "weapon",
        type = "melee",
        materials = {
            {id = "guard_weapon_parts", qty = 1},
            {id = "cloth_strip", qty = 1},
        },
        baseStats = {attack = 12, speed = 1.1, defense = 1},
        skillRequired = 0,
        icon = "SWORD",
    },
    -- Utility items
    {
        id = "lockpick_set",
        name = "Improvised Lockpick",
        description = "Bent wire fashioned into a passable lockpick. One use only.",
        category = "special",
        type = "tool",
        materials = {
            {id = "wire_coil", qty = 2},
        },
        baseStats = {},
        skillRequired = 0,
        icon = "PICK",
        consumable = true,
    },
    {
        id = "bandage_crude",
        name = "Crude Bandage",
        description = "Torn cloth strips that can stanch a wound. Restores a small amount of HP.",
        category = "consumable",
        type = "healing",
        materials = {
            {id = "cloth_strip", qty = 3},
        },
        baseStats = {healAmount = 15},
        skillRequired = 0,
        icon = "HEAL",
        consumable = true,
    },
    {
        id = "makeshift_armor",
        name = "Makeshift Armor",
        description = "Scrap metal plates tied together with wire. Better than nothing.",
        category = "armor",
        type = "body",
        materials = {
            {id = "scrap_metal", qty = 3},
            {id = "wire_coil", qty = 2},
            {id = "cloth_strip", qty = 2},
        },
        baseStats = {defense = 6, speedPenalty = -0.1},
        skillRequired = 0,
        icon = "ARMOR",
    },
}

-- ============================================================================
--                      SCAVENGEABLE PRISON MATERIALS
-- ============================================================================

PrisonEscape.SCAVENGE_ITEMS = {
    {id = "bone_fragment",    name = "Bone Fragment",    desc = "A sharpened piece of bone.", category = "material", weight = 0.3, icon = "BONE"},
    {id = "scrap_metal",      name = "Scrap Metal",      desc = "A bent piece of rusted metal.", category = "material", weight = 1.0, icon = "METAL"},
    {id = "cloth_strip",      name = "Cloth Strip",      desc = "A torn strip of prison uniform.", category = "material", weight = 0.1, icon = "CLOTH"},
    {id = "wire_coil",        name = "Wire Coil",        desc = "A short coil of copper wire.", category = "material", weight = 0.2, icon = "WIRE"},
    {id = "wood_scrap",       name = "Wood Scrap",       desc = "A piece of broken furniture.", category = "material", weight = 0.5, icon = "WOOD"},
    {id = "prison_crystal_shard",    name = "Crystal Shard",    desc = "A faintly glowing crystal fragment.", category = "material", weight = 0.2, icon = "CRYSTAL"},
    {id = "stone_chunk",      name = "Stone Chunk",      desc = "A small piece of hewn stone.", category = "material", weight = 0.8, icon = "STONE"},
    {id = "guard_weapon_parts", name = "Guard Weapon Parts", desc = "Salvaged from a guard's equipment.", category = "material", weight = 2.0, icon = "PARTS"},
    {id = "stale_bread",      name = "Stale Bread",      desc = "Rock-hard prison bread. Barely edible.", category = "consumable", weight = 0.3, icon = "BREAD", healAmount = 5},
    {id = "dirty_water",      name = "Dirty Water",      desc = "Murky water from a dripping pipe.", category = "consumable", weight = 0.5, icon = "WATER", healAmount = 3},
    {id = "rusty_key",        name = "Rusty Key",        desc = "An old key. Might fit something.", category = "special", weight = 0.1, icon = "KEY"},
    {id = "prisoner_note",    name = "Prisoner's Note",  desc = "A scrawled note left by a previous inmate.", category = "special", weight = 0.0, icon = "NOTE"},
}

-- ============================================================================
--                         PRISON GUARD DEFINITIONS
-- ============================================================================

PrisonEscape.GUARD_TYPES = {
    {
        id = "prison_guard",
        name = "Prison Guard",
        hp = 22, maxHp = 22,
        atk = 5, def = 3,
        xp = 15, gold = 5,
        drops = {"scrap_metal", "cloth_strip", "stale_bread"},
        patrolSpeed = 0.8,
        alertRange = 2,      -- tiles within which guard spots player
        description = "A rank-and-file prison guard armed with a short sword and baton.",
    },
    {
        id = "prison_sergeant",
        name = "Prison Sergeant",
        hp = 35, maxHp = 35,
        atk = 8, def = 5,
        xp = 30, gold = 10,
        drops = {"guard_weapon_parts", "scrap_metal", "rusty_key"},
        patrolSpeed = 0.7,
        alertRange = 3,
        description = "A veteran guard sergeant. Tougher and more alert than regular guards.",
    },
    {
        id = "warden_enforcer",
        name = "Warden's Enforcer",
        hp = 50, maxHp = 50,
        atk = 10, def = 7,
        xp = 50, gold = 20,
        drops = {"guard_weapon_parts", "guard_weapon_parts", "rusty_key"},
        patrolSpeed = 0.6,
        alertRange = 3,
        description = "An elite enforcer loyal only to the Warden. Heavily armed.",
        isMini = true,
    },
}

-- ============================================================================
--                         PRISON BEAST DEFINITIONS
-- ============================================================================

PrisonEscape.BEAST_TYPES = {
    -- Beast types (kept for reference, beast floor removed in condensed prison)
    {
        id = "cave_rat_swarm",
        name = "Cave Rat Swarm",
        hp = 12, maxHp = 12,
        atk = 3, def = 1,
        xp = 8, gold = 0,
        drops = {"bone_fragment"},
        description = "A writhing mass of starving rats. They attack anything that moves.",
    },
    {
        id = "chained_hound",
        name = "Chained Hound",
        hp = 25, maxHp = 25,
        atk = 6, def = 2,
        xp = 20, gold = 0,
        drops = {"bone_fragment", "cloth_strip"},
        description = "A feral hound once used by guards. Its chain has rusted through.",
    },
    {
        id = "tunnel_spider",
        name = "Tunnel Spider",
        hp = 18, maxHp = 18,
        atk = 5, def = 2,
        xp = 15, gold = 0,
        drops = {"cloth_strip", "cloth_strip"},
        description = "A large spider nesting in the prison's forgotten tunnels.",
    },
}

-- ============================================================================
--                           BOSS DEFINITIONS
-- ============================================================================

PrisonEscape.BOSSES = {
    -- Floor 2 Boss: Surface Exit
    {
        id = "warden_blackthorn",
        name = "Warden Blackthorn",
        hp = 120, maxHp = 120,
        atk = 14, def = 8,
        xp = 200, gold = 50,
        drops = {"guard_weapon_parts", "guard_weapon_parts", "rusty_key"},
        description = "The ruthless Warden of The Sunken Ledger. He will not let you leave alive.",
        isBoss = true,
        floorPlacement = 2,
        abilities = {"power_strike", "intimidate"},
    },
}

-- ============================================================================
--                          ALLY DEFINITIONS
-- ============================================================================

PrisonEscape.ALLIES = {
    {
        id = "grimjaw",
        name = "Grimjaw",
        race = "orc",
        class = "warrior",
        description = "A scarred orc warrior imprisoned for refusing to betray his clan. Despite his fearsome appearance, he has a code of honor.",
        hp = 50, maxHp = 50,
        atk = 12, def = 8,
        floorFound = 1,  -- Same cell block as player
        recruitDialogue = {
            "You there. You have that look. The look of someone who does not plan to die here.",
            "I am Grimjaw. They took my clan's honor-blade when they threw me in here.",
            "Get these cuffs off me and I will fight beside you. I would rather die free than rot in chains.",
        },
        recruitQuest = "free_grimjaw",  -- Lockpick his cell
    },
    {
        id = "sera_voss",
        name = "Sera Voss",
        race = "human",
        class = "rogue",
        description = "A former spy for the Dominion, imprisoned when she uncovered secrets the crown wanted buried. Quick with a blade and quicker with her tongue.",
        hp = 35, maxHp = 35,
        atk = 10, def = 5,
        floorFound = 1,  -- General population area
        recruitDialogue = {
            "Psst. Over here. You are not just another prisoner, are you?",
            "I am Sera. I used to work for the crown. Now I know too much.",
            "I know every guard rotation in this place. Get me out and I will guide us to the exit.",
        },
        recruitQuest = "find_sera",  -- Find her hidden cell
    },
    {
        id = "brother_aldric",
        name = "Brother Aldric",
        race = "human",
        class = "cleric",
        description = "A disgraced priest of Helios imprisoned for heresy. He preached that the Dominion had strayed from the sun god's true teachings. His faith remains unbroken.",
        hp = 40, maxHp = 40,
        atk = 6, def = 6,
        floorFound = 1,  -- Near chapel area
        recruitDialogue = {
            "Blessings of Helios upon you, stranger. Even in this darkness, the light endures.",
            "They call me heretic because I spoke truth to power. The Dominion fears what I know.",
            "I can heal wounds and shield against the darkness below. Let me join your exodus.",
        },
        recruitQuest = "aid_aldric",  -- Bring him a crystal shard for his focus
    },
    {
        id = "nyx",
        name = "Nyx",
        race = "goblin",
        class = "mage",
        description = "A goblin artificer imprisoned for 'dangerous experimentation.' In reality, she was building devices that democratize magic and threaten the Dominion's monopoly on power. Brilliant, unhinged, and fiercely anti-imperial.",
        hp = 25, maxHp = 25,
        atk = 14, def = 3,
        floorFound = 1,  -- Isolated in a special cell
        recruitDialogue = {
            "Oh! OH! You're breaking out? TAKE ME WITH YOU! I have PLANS! So many plans!",
            "They locked me up for making a device that lets ANYONE cast cantrips. Democratizing magic is apparently TREASON!",
            "The empire hoards magic like they hoarded our land. Monopoly on power. Monopoly on violence. I'm going to BREAK their monopoly!",
            "I can make things. Weapons, tools, distractions, BOMBS. All I need is parts and freedom! And maybe some imperial property to test them on!",
            "Get me out of here and I'll build you devices that make imperial mages CRY. The empire wants magic for the elite? I'll give it to the PEOPLE!",
        },
        recruitQuest = "rescue_nyx",  -- Open her reinforced cell (harder lockpick)
    },
}

-- ============================================================================
--                       PRISON FLOOR TEMPLATES
-- ============================================================================

PrisonEscape.FLOOR_TEMPLATES = {
    -- Floor 1: Cell Block & General Population (combined)
    {
        floorNum = 1,
        name = "Cell Block - The Depths",
        description = "The forgotten depths of The Sunken Ledger. Cells, a mess hall, and workshops crowd together. Water seeps through the walls.",
        roomTypes = {"cell", "cell", "mess_hall", "workshop", "corridor", "storage"},
        guardCount = 2,
        guardType = "prison_guard",
        scavengeChance = 0.50,  -- Generous scavenging
        lightLevel = 0.7,       -- Well-lit by torches
        specialRooms = {
            {type = "player_cell", required = true},       -- Player starts here
            {type = "ally_cell_grimjaw", required = true}, -- Grimjaw's cell
            {type = "ally_cell_sera", required = true},
            {type = "ally_cell_aldric", required = true},
            {type = "ally_cell_nyx", required = true},
        },
        ambientSounds = {"dripping_water", "distant_chains", "murmuring_prisoners"},
    },
    -- Floor 2: Surface / Escape
    {
        floorNum = 2,
        name = "The Docks - Surface Level",
        description = "The uppermost level: loading docks, the main gate, and the warden's escape route. Freedom lies beyond.",
        roomTypes = {"loading_dock", "gate_room", "supply_room", "corridor"},
        guardCount = 2,
        guardType = "prison_sergeant",
        scavengeChance = 0.40,
        lightLevel = 1.0,  -- Daylight
        specialRooms = {
            {type = "final_boss_room", required = true},   -- Warden Blackthorn
            {type = "escape_exit", required = true},       -- The way out
        },
        ambientSounds = {"seagulls", "waves", "wind", "creaking_wood"},
    },
}

-- ============================================================================
--                      CUTSCENE TRIGGER POINTS
-- ============================================================================

PrisonEscape.CUTSCENE_TRIGGERS = {
    {
        id = "intro_wake_up",
        trigger = "game_start",
        floorNum = 1,
        description = "Player wakes up in their cell. Establishes setting and situation.",
    },
    {
        id = "meet_grimjaw",
        trigger = "approach_ally",
        allyId = "grimjaw",
        floorNum = 1,
        description = "Player meets Grimjaw in the adjacent cell.",
    },
    {
        id = "meet_sera",
        trigger = "approach_ally",
        allyId = "sera_voss",
        floorNum = 1,
        description = "Sera reveals herself from hiding and offers her knowledge.",
    },
    {
        id = "meet_aldric",
        trigger = "approach_ally",
        allyId = "brother_aldric",
        floorNum = 1,
        description = "Brother Aldric prays in the ruined chapel.",
    },
    {
        id = "meet_nyx",
        trigger = "approach_ally",
        allyId = "nyx",
        floorNum = 1,
        description = "Nyx is found in an isolated cell, tinkering with scraps.",
    },
    {
        id = "warden_confrontation",
        trigger = "enter_room",
        roomType = "final_boss_room",
        floorNum = 2,
        description = "Warden Blackthorn blocks the exit and reveals the truth.",
    },
    {
        id = "escape_surface",
        trigger = "defeat_boss",
        bossId = "warden_blackthorn",
        floorNum = 2,
        description = "The party escapes to the surface and sees daylight.",
    },
    {
        id = "meet_thieves_guild",
        trigger = "post_escape",
        description = "A thieves guild contact meets the party on the shore.",
    },
}

-- ============================================================================
--                     GUARD PATROL SYSTEM
-- ============================================================================

-- Generate guard patrol routes for a floor
function PrisonEscape.generateGuardPatrols(floor, guardCount, guardType)
    local patrols = {}
    if guardCount == 0 or not guardType then return patrols end

    local guardTemplate = nil
    for _, gt in ipairs(PrisonEscape.GUARD_TYPES) do
        if gt.id == guardType then
            guardTemplate = gt
            break
        end
    end
    if not guardTemplate then return patrols end

    for i = 1, guardCount do
        -- Pick a random room for the guard's patrol route
        local rooms = floor.rooms or {}
        if #rooms < 2 then break end

        local startRoom = rooms[math.random(1, #rooms)]
        local endRoom = rooms[math.random(1, #rooms)]
        -- Make sure start and end are different
        local attempts = 0
        while startRoom == endRoom and attempts < 10 do
            endRoom = rooms[math.random(1, #rooms)]
            attempts = attempts + 1
        end

        local guard = {
            id = guardTemplate.id .. "_" .. i,
            name = guardTemplate.name,
            hp = guardTemplate.hp,
            maxHp = guardTemplate.maxHp,
            atk = guardTemplate.atk,
            def = guardTemplate.def,
            xp = guardTemplate.xp,
            gold = guardTemplate.gold,
            drops = guardTemplate.drops,
            alertRange = guardTemplate.alertRange,
            patrolSpeed = guardTemplate.patrolSpeed,
            -- Patrol waypoints
            patrolStart = {x = startRoom.centerX, y = startRoom.centerY},
            patrolEnd = {x = endRoom.centerX, y = endRoom.centerY},
            x = startRoom.centerX,
            y = startRoom.centerY,
            -- Patrol state
            movingToEnd = true,
            patrolTimer = 0,
            stepDelay = 1.0 / guardTemplate.patrolSpeed,
            alive = true,
            alerted = false,
            -- Facing direction for stealth
            facingX = 0,
            facingY = 0,
        }
        table.insert(patrols, guard)
    end

    return patrols
end

-- Update guard positions (called each game tick)
function PrisonEscape.updateGuardPatrols(patrols, dt, floor)
    if not patrols then return end
    for _, guard in ipairs(patrols) do
        if guard.alive and not guard.alerted then
            guard.patrolTimer = guard.patrolTimer + dt
            if guard.patrolTimer >= guard.stepDelay then
                guard.patrolTimer = 0
                -- Move toward current target
                local target = guard.movingToEnd and guard.patrolEnd or guard.patrolStart
                local dx = target.x - guard.x
                local dy = target.y - guard.y

                if math.abs(dx) + math.abs(dy) <= 1 then
                    -- Reached target, reverse direction
                    guard.movingToEnd = not guard.movingToEnd
                else
                    -- Move one step toward target
                    if math.abs(dx) > math.abs(dy) then
                        local step = dx > 0 and 1 or -1
                        local newX = guard.x + step
                        -- Check if walkable
                        if floor and floor.grid and floor.grid[guard.y] and floor.grid[guard.y][newX] then
                            local tile = floor.grid[guard.y][newX]
                            if tile.type ~= "wall" then
                                guard.facingX = step
                                guard.facingY = 0
                                guard.x = newX
                            end
                        end
                    else
                        local step = dy > 0 and 1 or -1
                        local newY = guard.y + step
                        if floor and floor.grid and floor.grid[newY] and floor.grid[newY][guard.x] then
                            local tile = floor.grid[newY][guard.x]
                            if tile.type ~= "wall" then
                                guard.facingX = 0
                                guard.facingY = step
                                guard.y = newY
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Check if any guard can see the player
-- stealthMode: boolean, detectionChance: 0-1 from player's stealth calculation
function PrisonEscape.checkGuardDetection(patrols, playerX, playerY, stealthMode, detectionChance)
    if not patrols then return false, nil end
    for _, guard in ipairs(patrols) do
        if guard.alive and not guard.alerted and not guard.inCombat then
            local dist = math.abs(guard.x - playerX) + math.abs(guard.y - playerY)
            -- Stealth mode halves the guard's effective detection range
            local effectiveRange = guard.alertRange
            if stealthMode then
                effectiveRange = math.floor(effectiveRange / 2)
            end
            if dist <= effectiveRange then
                -- Apply detection probability - stealth gives a chance to avoid detection
                local chance = detectionChance or 1.0
                if stealthMode then
                    -- Even within range, stealth gives a probability-based evasion
                    if math.random() > chance then
                        -- Player evaded this guard's notice
                    else
                        return true, guard
                    end
                else
                    return true, guard
                end
            end
        end
    end
    return false, nil
end

-- ============================================================================
--                   PRISON DUNGEON GENERATION
-- ============================================================================

-- Create a prison-specific floor
function PrisonEscape.generatePrisonFloor(floorNum, template)
    local width = PrisonEscape.FLOOR_WIDTH
    local height = PrisonEscape.FLOOR_HEIGHT

    -- Create empty grid
    local grid = {}
    for y = 1, height do
        grid[y] = {}
        for x = 1, width do
            grid[y][x] = {type = "wall", explored = false, content = nil}
        end
    end

    local rooms = {}
    local numRooms = math.random(4, 6)
    local attempts = 0
    local maxAttempts = 150

    while #rooms < numRooms and attempts < maxAttempts do
        attempts = attempts + 1
        local roomW = math.random(3, 5)
        local roomH = math.random(3, 4)
        local roomX = math.random(2, width - roomW - 1)
        local roomY = math.random(2, height - roomH - 1)

        -- Check for overlap
        local overlaps = false
        for _, existing in ipairs(rooms) do
            if roomX < existing.x + existing.w + 2 and
               roomX + roomW + 2 > existing.x and
               roomY < existing.y + existing.h + 2 and
               roomY + roomH + 2 > existing.y then
                overlaps = true
                break
            end
        end

        if not overlaps then
            -- Carve room
            for y = roomY, roomY + roomH - 1 do
                for x = roomX, roomX + roomW - 1 do
                    if grid[y] and grid[y][x] then
                        grid[y][x].type = "floor"
                    end
                end
            end
            local room = {
                x = roomX, y = roomY, w = roomW, h = roomH,
                centerX = math.floor(roomX + roomW/2),
                centerY = math.floor(roomY + roomH/2),
                roomType = template.roomTypes[math.random(#template.roomTypes)],
            }
            table.insert(rooms, room)
        end
    end

    -- Connect rooms with corridors
    for i = 2, #rooms do
        local r1 = rooms[i-1]
        local r2 = rooms[i]
        -- Carve horizontal then vertical
        local x, y = r1.centerX, r1.centerY
        while x ~= r2.centerX do
            if grid[y] and grid[y][x] and grid[y][x].type == "wall" then
                grid[y][x].type = "corridor"
            end
            x = x + (r2.centerX > r1.centerX and 1 or -1)
        end
        while y ~= r2.centerY do
            if grid[y] and grid[y][x] and grid[y][x].type == "wall" then
                grid[y][x].type = "corridor"
            end
            y = y + (r2.centerY > r1.centerY and 1 or -1)
        end
    end

    -- Add extra connections
    if #rooms > 4 then
        for _ = 1, math.random(1, 3) do
            local r1 = rooms[math.random(#rooms)]
            local r2 = rooms[math.random(#rooms)]
            if r1 ~= r2 then
                local x, y = r1.centerX, r1.centerY
                while x ~= r2.centerX do
                    if grid[y] and grid[y][x] and grid[y][x].type == "wall" then
                        grid[y][x].type = "corridor"
                    end
                    x = x + (r2.centerX > r1.centerX and 1 or -1)
                end
                while y ~= r2.centerY do
                    if grid[y] and grid[y][x] and grid[y][x].type == "wall" then
                        grid[y][x].type = "corridor"
                    end
                    y = y + (r2.centerY > r1.centerY and 1 or -1)
                end
            end
        end
    end

    -- Add doors (reuse standard dungeon algorithm: max 2 per room, entrance-group based)
    RpgDungeon.addDoors(grid, rooms)

    -- Place stairs
    local entranceRoom = rooms[1]
    local exitRoom = rooms[#rooms]

    -- Entrance (from previous floor or player start)
    local entranceX = entranceRoom.centerX
    local entranceY = entranceRoom.centerY
    if floorNum == 1 then
        grid[entranceY][entranceX].type = "prison_cell_start"  -- Player's starting cell
    else
        grid[entranceY][entranceX].type = "stairs_up"  -- Came from lower floor number (deeper level)
    end

    -- Exit (to next floor or final escape)
    -- NOTE: The dungeon system uses "stairs_down" to advance to higher floor numbers.
    -- In the prison, higher floor numbers = closer to surface (ascending physically).
    -- So "stairs_down" is our progression path upward through the prison.
    local exitX = exitRoom.centerX
    local exitY = exitRoom.centerY
    if floorNum == PrisonEscape.NUM_FLOORS then
        grid[exitY][exitX].type = "escape_exit"
        grid[exitY][exitX].roomType = "escape_exit"
        grid[exitY][exitX].content = {type = "escape_exit", name = "Escape Route", description = "The way out of The Sunken Ledger."}
    else
        grid[exitY][exitX].type = "stairs_down"  -- Advances to next floor (closer to surface)
    end

    -- Place scavengeable items
    local scavengeSpots = {}
    for _, room in ipairs(rooms) do
        for _ = 1, math.random(1, 3) do
            if math.random() < template.scavengeChance then
                local sx = math.random(room.x, room.x + room.w - 1)
                local sy = math.random(room.y, room.y + room.h - 1)
                if grid[sy] and grid[sy][sx] and grid[sy][sx].type == "floor" and not grid[sy][sx].content then
                    local item = PrisonEscape.SCAVENGE_ITEMS[math.random(#PrisonEscape.SCAVENGE_ITEMS)]
                    grid[sy][sx].content = {type = "scavenge", item = item, searched = false}
                    table.insert(scavengeSpots, {x = sx, y = sy, item = item})
                end
            end
        end
    end

    -- Place enemies (guards or beasts)
    local enemies = {}
    if template.beasts then
        -- Beast floor
        local numBeasts = math.random(2, 4)
        for _ = 1, numBeasts do
            local roomIdx = math.random(2, math.max(2, #rooms - 1))
            local room = rooms[roomIdx]
            if room then
                local ex = math.random(room.x + 1, math.max(room.x + 1, room.x + room.w - 2))
                local ey = math.random(room.y + 1, math.max(room.y + 1, room.y + room.h - 2))
                if grid[ey] and grid[ey][ex] and grid[ey][ex].type == "floor" and not grid[ey][ex].content then
                    local beastTemplate = PrisonEscape.BEAST_TYPES[math.random(#PrisonEscape.BEAST_TYPES)]
                    if not beastTemplate.isMini then  -- Don't randomly place mini-bosses
                        local enemy = {
                            id = beastTemplate.id,
                            name = beastTemplate.name,
                            hp = beastTemplate.hp,
                            maxHp = beastTemplate.maxHp,
                            atk = beastTemplate.atk,
                            def = beastTemplate.def,
                            xp = beastTemplate.xp,
                            gold = beastTemplate.gold,
                            drops = beastTemplate.drops,
                            x = ex, y = ey,
                            alive = true,
                        }
                        table.insert(enemies, enemy)
                        grid[ey][ex].content = {type = "enemy", data = enemy}
                    end
                end
            end
        end
    end

    -- Place boss if this floor has one
    for _, boss in ipairs(PrisonEscape.BOSSES) do
        if boss.floorPlacement == floorNum then
            local bossRoom = rooms[math.max(1, #rooms - 1)]
            local bx = bossRoom.centerX
            local by = bossRoom.centerY
            if grid[by] and grid[by][bx] then
                local bossEnemy = {
                    id = boss.id,
                    name = boss.name,
                    hp = boss.hp,
                    maxHp = boss.maxHp,
                    atk = boss.atk,
                    def = boss.def,
                    xp = boss.xp,
                    gold = boss.gold,
                    drops = boss.drops,
                    abilities = boss.abilities,
                    x = bx, y = by,
                    alive = true,
                    isBoss = true,
                }
                table.insert(enemies, bossEnemy)
                grid[by][bx].content = {type = "enemy", data = bossEnemy}
            end
        end
    end

    -- Place allies if this floor has them
    local allies = {}
    for _, ally in ipairs(PrisonEscape.ALLIES) do
        if ally.floorFound == floorNum then
            -- Find a room for the ally (with retry logic)
            local allyRoom = rooms[math.random(2, math.max(2, #rooms - 1))]
            if allyRoom then
                for attempt = 1, 10 do
                    local ax = allyRoom.x + math.random(allyRoom.w) - 1
                    local ay = allyRoom.y + math.random(allyRoom.h) - 1
                    if grid[ay] and grid[ay][ax] and not grid[ay][ax].content then
                        local allyData = {
                            id = ally.id,
                            name = ally.name,
                            race = ally.race,
                            class = ally.class,
                            description = ally.description,
                            hp = ally.hp,
                            maxHp = ally.maxHp,
                            atk = ally.atk,
                            def = ally.def,
                            dialogue = ally.recruitDialogue,
                            recruitQuest = ally.recruitQuest,
                            x = ax, y = ay,
                            recruited = false,
                        }
                        table.insert(allies, allyData)
                        grid[ay][ax].content = {type = "ally", data = allyData}
                        break
                    end
                end
            end
        end
    end

    -- Generate guard patrols
    local guardPatrols = PrisonEscape.generateGuardPatrols(
        {rooms = rooms, grid = grid},
        template.guardCount,
        template.guardType
    )

    return {
        grid = grid,
        width = width,
        height = height,
        rooms = rooms,
        enemies = enemies,
        allies = allies,
        guardPatrols = guardPatrols,
        scavengeSpots = scavengeSpots,
        entranceX = entranceX,
        entranceY = entranceY,
        exitX = exitX,
        exitY = exitY,
        floorNum = floorNum,
        template = template,
    }
end

-- ============================================================================
--                 GENERATE COMPLETE PRISON DUNGEON
-- ============================================================================

function PrisonEscape.generatePrison()
    local prison = {
        name = "The Sunken Ledger",
        floors = {},
        currentFloor = 1,
        totalFloors = PrisonEscape.NUM_FLOORS,
        playerX = 0,
        playerY = 0,
        cleared = false,
        escaped = false,
        -- Prison-specific state
        cuffsRemoved = false,
        alliesRecruited = {},
        guardsAlerted = false,   -- Global alert state
        alertLevel = 0,          -- 0=none, 1=suspicious, 2=search, 3=lockdown
        alertTimer = 0,
        cutscenesSeen = {},
        objectivesCompleted = {},
        -- Crafting inventory (prison materials, separate from main backpack until escape)
        prisonInventory = {},
    }

    -- Generate all floors
    for i = 1, PrisonEscape.NUM_FLOORS do
        local template = PrisonEscape.FLOOR_TEMPLATES[i]
        prison.floors[i] = PrisonEscape.generatePrisonFloor(i, template)
    end

    -- Set player starting position on floor 1
    local firstFloor = prison.floors[1]
    prison.playerX = firstFloor.entranceX
    prison.playerY = firstFloor.entranceY

    -- Mark starting area as explored
    for dy = -2, 2 do
        for dx = -2, 2 do
            local ey = prison.playerY + dy
            local ex = prison.playerX + dx
            if firstFloor.grid[ey] and firstFloor.grid[ey][ex] then
                firstFloor.grid[ey][ex].explored = true
            end
        end
    end

    return prison
end

-- ============================================================================
--                    PRISON STATE MANAGEMENT
-- ============================================================================

-- Initialize prison escape sequence (called when starting new game with prison start)
function PrisonEscape.init()
    local prison = PrisonEscape.generatePrison()

    return {
        prison = prison,
        phase = "prison_intro",  -- prison_intro, prison_dungeon, prison_cutscene, prison_crafting, prison_combat
        cuffsEquipped = true,
        hasMagicFocus = false,
        prisonTutorialStep = 0,
        combatReturnPhase = "prison_dungeon",
        -- Starting stats adjustments
        startingGear = {},   -- Empty - player starts with nothing
        startingGold = 0,    -- No gold in prison
    }
end

-- Apply cuffs debuff to player stats
function PrisonEscape.applyCuffsDebuff(player)
    if not player then return end
    player.prisonCuffs = true
    local debuff = PrisonEscape.CUFFS_DEBUFF
    -- Store original stats for restoration
    if not player.preCuffsStats then
        player.preCuffsStats = {
            MIGHT = player.stats.MIGHT,
            AGILITY = player.stats.AGILITY,
            VIGOR = player.stats.VIGOR,
            MIND = player.stats.MIND,
            SPIRIT = player.stats.SPIRIT,
            PRESENCE = player.stats.PRESENCE,
            attack = player.attack,
            defense = player.defense,
        }
    end
    -- Apply penalties
    for stat, penalty in pairs(debuff.statPenalty) do
        if player.stats[stat] then
            player.stats[stat] = math.max(1, player.stats[stat] + penalty)
        end
    end
    player.attack = math.max(1, (player.attack or 0) + debuff.attackPenalty)
    player.defense = math.max(0, (player.defense or 0) + debuff.defensePenalty)
end

-- Remove cuffs debuff (after successful lockpick)
function PrisonEscape.removeCuffsDebuff(player)
    if not player then return end
    player.prisonCuffs = false
    -- Restore all original stats including attack/defense
    if player.preCuffsStats then
        for stat, value in pairs(player.preCuffsStats) do
            if player.stats and player.stats[stat] then
                player.stats[stat] = value
            end
        end
        player.attack = player.preCuffsStats.attack or player.attack
        player.defense = player.preCuffsStats.defense or player.defense
        player.preCuffsStats = nil
    end
end

-- Scavenge an item from a tile
function PrisonEscape.scavengeTile(prison, x, y)
    if not prison or not prison.floors then return nil end
    local floor = prison.floors[prison.currentFloor]
    if not floor or not floor.grid then return nil end
    local tile = floor.grid[y] and floor.grid[y][x]
    if not tile or not tile.content or tile.content.type ~= "scavenge" then return nil end
    if tile.content.searched then return nil end

    tile.content.searched = true
    local item = tile.content.item

    -- Add to prison inventory
    if not prison.prisonInventory then prison.prisonInventory = {} end
    local found = false
    for _, invItem in ipairs(prison.prisonInventory) do
        if invItem.id == item.id then
            invItem.qty = (invItem.qty or 1) + 1
            found = true
            break
        end
    end
    if not found then
        table.insert(prison.prisonInventory, {
            id = item.id,
            name = item.name,
            desc = item.desc,
            category = item.category,
            qty = 1,
            icon = item.icon,
            weight = item.weight,
            healAmount = item.healAmount,
        })
    end

    return item
end

-- Check if player can craft a prison recipe
function PrisonEscape.canCraftRecipe(prison, recipe)
    if not prison or not prison.prisonInventory then return false end
    for _, mat in ipairs(recipe.materials) do
        local have = 0
        for _, invItem in ipairs(prison.prisonInventory) do
            if invItem.id == mat.id then
                have = invItem.qty or 0
                break
            end
        end
        if have < mat.qty then
            return false
        end
    end
    return true
end

-- Craft a prison recipe
function PrisonEscape.craftRecipe(prison, recipe)
    if not PrisonEscape.canCraftRecipe(prison, recipe) then return false end

    -- Consume materials
    for _, mat in ipairs(recipe.materials) do
        for _, invItem in ipairs(prison.prisonInventory) do
            if invItem.id == mat.id then
                invItem.qty = invItem.qty - mat.qty
                break
            end
        end
    end

    -- Clean up zero-quantity items
    local cleanInv = {}
    for _, invItem in ipairs(prison.prisonInventory) do
        if invItem.qty and invItem.qty > 0 then
            table.insert(cleanInv, invItem)
        end
    end
    prison.prisonInventory = cleanInv

    -- Add crafted item
    table.insert(prison.prisonInventory, {
        id = recipe.id,
        name = recipe.name,
        desc = recipe.description,
        category = recipe.category,
        qty = 1,
        icon = recipe.icon,
        baseStats = recipe.baseStats,
        consumable = recipe.consumable,
    })

    return true
end

-- Handle guard encounter (caught by guard)
function PrisonEscape.onGuardCaught(prison)
    -- If player loses combat with guard, dragged back to cell
    prison.currentFloor = 1
    local firstFloor = prison.floors[1]
    prison.playerX = firstFloor.entranceX
    prison.playerY = firstFloor.entranceY
    prison.alertLevel = math.min(3, prison.alertLevel + 1)
    prison.alertTimer = 60  -- Alert lasts 60 seconds

    return "You are overwhelmed and dragged back to your cell. The guards tighten security."
end

-- Transfer prison inventory to main backpack (on escape)
function PrisonEscape.transferInventoryToBackpack(prison)
    if not prison or not prison.prisonInventory then return end
    for _, item in ipairs(prison.prisonInventory) do
        if item.qty and item.qty > 0 then
            Backpack.addItem(item.id, item.qty)
        end
    end
end

-- ============================================================================
--                    OBJECTIVE TRACKING
-- ============================================================================

PrisonEscape.OBJECTIVES = {
    {id = "remove_cuffs",       text = "Lockpick your cuffs",                 required = true},
    {id = "escape_cell",        text = "Escape your cell",                    required = true},
    {id = "recruit_grimjaw",    text = "Free Grimjaw (Orc Warrior)",          required = false},
    {id = "recruit_sera",       text = "Find Sera Voss (Human Rogue)",        required = false},
    {id = "recruit_aldric",     text = "Aid Brother Aldric (Human Cleric)",   required = false},
    {id = "rescue_nyx",         text = "Rescue Nyx (Goblin Mage)",            required = false},
    {id = "find_weapons",       text = "Find or craft weapons",               required = true},
    {id = "defeat_warden",      text = "Defeat Warden Blackthorn",            required = true},
    {id = "escape_prison",      text = "Escape The Sunken Ledger",            required = true},
    {id = "meet_thieves_guild", text = "Meet the Thieves Guild contact",      required = true},
}

function PrisonEscape.isObjectiveComplete(prison, objectiveId)
    return prison and prison.objectivesCompleted and prison.objectivesCompleted[objectiveId]
end

function PrisonEscape.completeObjective(prison, objectiveId)
    if not prison then return end
    if not prison.objectivesCompleted then prison.objectivesCompleted = {} end
    prison.objectivesCompleted[objectiveId] = true
end

function PrisonEscape.getActiveObjectives(prison)
    local active = {}
    for _, obj in ipairs(PrisonEscape.OBJECTIVES) do
        if not PrisonEscape.isObjectiveComplete(prison, obj.id) then
            table.insert(active, obj)
        end
    end
    return active
end

function PrisonEscape.getCompletedObjectives(prison)
    local completed = {}
    for _, obj in ipairs(PrisonEscape.OBJECTIVES) do
        if PrisonEscape.isObjectiveComplete(prison, obj.id) then
            table.insert(completed, obj)
        end
    end
    return completed
end

-- ============================================================================
--                     PRISON LORE & NOTES
-- ============================================================================

PrisonEscape.PRISONER_NOTES = {
    {
        id = "note_cell_scratches",
        title = "Scratched Wall Markings",
        text = "Day 347. They brought more prisoners today. Soldiers from the northern campaign. They say the war goes badly. The warden smiles when he hears bad news. More prisoners mean more labor for his 'special project' below. I hear digging at night. What is he building down there?",
    },
    {
        id = "note_guard_schedule",
        title = "Guard Rotation Notes",
        text = "Shift change happens every 4 hours. During the changeover there is a gap, maybe two minutes, when the corridor between blocks is unwatched. The new guards come from the east stairwell. The old shift leaves by the west. If you time it right...",
    },
    {
        id = "note_beast_warning",
        title = "Crumpled Warning",
        text = "DO NOT ENTER SUB-LEVEL X. By order of Warden Blackthorn. The containment breach has NOT been resolved. All personnel are to avoid the lower stairwell until further notice. Anyone found on Sub-Level X will be treated as an escapee. -Capt. Harlow",
    },
    {
        id = "note_smuggler_message",
        title = "Hidden Smuggler's Note",
        text = "Package received. The guild will have contacts waiting at the western cove. When you reach the surface, look for the sign of the crossed daggers. They will provide new identities and passage inland. Do NOT approach the main gate. -R.",
    },
    {
        id = "note_warden_journal",
        title = "Warden's Private Journal (Torn Page)",
        text = "The creatures below grow restless. I should never have allowed the excavation to continue. But the Crown demands results, and the crystal deposits are too valuable. If the prisoners knew what truly lies beneath their cells... No. The Ledger keeps its secrets. As do I.",
    },
    {
        id = "note_why_imprisoned",
        title = "Your Arrest Warrant",
        text = "By decree of the Holy Dominion, the bearer of this warrant is to be remanded to The Sunken Ledger for crimes against the Crown. Charges: Sedition, conspiracy, and possession of forbidden knowledge. Sentence: Indefinite. Note: Prisoner is to be held in Cell Block D. No visitors. No correspondence. This one is to be forgotten.",
    },
}

-- ============================================================================
--                     MODULE RETURN
-- ============================================================================

return PrisonEscape
