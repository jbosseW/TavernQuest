-- Town Visible NPCs System
-- Draws visible NPCs on the town grid that the player can walk up to and interact with.
-- NPCs appear on buildings and streets, showing names/professions and interaction prompts.
-- Uses the existing NPC data from textrpg.lua's initializeTownNPCs system.

local TownNPCsVisible = {}

-- Reference to game state (set via init)
local state = nil
local log = function(text, color)
    if _G.log then _G.log(text, color) end
end

-- ============================================================================
--                              CONFIGURATION
-- ============================================================================

local CONFIG = {
    -- Visual
    pulseSpeed = 2.0,               -- NPC icon pulse speed (slower than enemies)
    hoverShowRadius = 1.5,          -- Grid distance to show NPC name/title
    interactRadius = 1,             -- Grid distance for interaction prompt

    -- Colors by profession category
    professionColors = {
        shopkeeper = {0.8, 0.7, 0.3},
        blacksmith = {0.7, 0.5, 0.3},
        priest = {0.9, 0.9, 0.6},
        tavernkeep = {0.7, 0.5, 0.2},
        stablemaster = {0.5, 0.6, 0.3},
        alchemist = {0.3, 0.7, 0.5},
        wizard = {0.5, 0.4, 0.8},
        fisher = {0.3, 0.5, 0.7},
        hunter = {0.5, 0.4, 0.3},
        merchant = {0.8, 0.6, 0.2},
        butcher = {0.7, 0.3, 0.3},
        baker = {0.7, 0.6, 0.4},
        tailor = {0.6, 0.5, 0.7},
        jeweler = {0.7, 0.7, 0.9},
        wellkeeper = {0.4, 0.6, 0.7},
    },

    -- Sprites by profession (single character icons for grid display)
    professionIcons = {
        shopkeeper = "S",
        blacksmith = "B",
        priest = "P",
        tavernkeep = "T",
        stablemaster = "H",
        alchemist = "A",
        wizard = "W",
        fisher = "F",
        hunter = "R",
        merchant = "M",
        butcher = "U",
        baker = "K",
        tailor = "L",
        jeweler = "J",
        wellkeeper = "Q",
    },

    -- Default color for unknown professions
    defaultColor = {0.6, 0.7, 0.8},
    defaultIcon = "N",

    -- Wandering NPC colors
    wanderingColors = {
        guard = {0.7, 0.7, 0.5},
        child = {0.5, 0.7, 0.9},
        cat = {0.7, 0.6, 0.4},
        bard = {0.7, 0.5, 0.7},
        beggar = {0.5, 0.5, 0.5},
        noble = {0.8, 0.7, 0.3},
        citizen = {0.6, 0.6, 0.7},
    },
    wanderingIcons = {
        guard = "G",
        child = "c",
        cat = "~",
        bard = "b",
        beggar = "p",
        noble = "N",
        citizen = "n",
    },
}

-- ============================================================================
--                              INITIALIZATION
-- ============================================================================

function TownNPCsVisible.init(gameState)
    state = gameState
end

function TownNPCsVisible.setLogFunction(logFunc)
    log = logFunc
end

-- ============================================================================
--                          HELPER FUNCTIONS
-- ============================================================================

local function gridDist(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    return math.sqrt(dx * dx + dy * dy)
end

-- Get NPC color by profession
local function getNPCColor(profession)
    return CONFIG.professionColors[profession] or CONFIG.defaultColor
end

-- Get NPC icon by profession
local function getNPCIcon(profession)
    return CONFIG.professionIcons[profession] or CONFIG.defaultIcon
end

-- ============================================================================
--                  NPC INTERACTION CHECK
-- ============================================================================

-- Check if the player is adjacent to an NPC at the given position.
-- Returns the NPC data if found, nil otherwise.
function TownNPCsVisible.getNPCAtPlayerPosition(playerX, playerY)
    if not state then return nil end
    local town = state.world and state.world.currentTown
    if not town then return nil end

    -- Check building NPCs
    if town.npcs then
        for _, npc in ipairs(town.npcs) do
            if npc.currentLocation and npc.currentLocation.gridX and npc.currentLocation.gridY then
                if npc.currentLocation.gridX == playerX and npc.currentLocation.gridY == playerY then
                    return npc, "building"
                end
            end
        end
    end

    -- Check wandering NPCs
    if town.wanderingNPCs then
        for _, wnpc in ipairs(town.wanderingNPCs) do
            if wnpc.gridX == playerX and wnpc.gridY == playerY then
                return wnpc, "wandering"
            end
        end
    end

    return nil
end

-- Check if player is adjacent to any NPC (for interaction prompt)
function TownNPCsVisible.getAdjacentNPC(playerX, playerY)
    if not state then return nil end
    local town = state.world and state.world.currentTown
    if not town then return nil end

    local directions = {{0, 0}, {0, -1}, {0, 1}, {-1, 0}, {1, 0}}

    for _, dir in ipairs(directions) do
        local checkX = playerX + dir[1]
        local checkY = playerY + dir[2]

        -- Check building NPCs
        if town.npcs then
            for _, npc in ipairs(town.npcs) do
                if npc.currentLocation and npc.currentLocation.gridX and npc.currentLocation.gridY then
                    if npc.currentLocation.gridX == checkX and npc.currentLocation.gridY == checkY then
                        return npc, "building", checkX, checkY
                    end
                end
            end
        end

        -- Check wandering NPCs
        if town.wanderingNPCs then
            for _, wnpc in ipairs(town.wanderingNPCs) do
                if wnpc.gridX == checkX and wnpc.gridY == checkY then
                    return wnpc, "wandering", checkX, checkY
                end
            end
        end
    end

    return nil
end

-- Handle NPC interaction (called when player walks into or presses E near NPC)
function TownNPCsVisible.interactWithNPC(npc, npcType)
    if not npc then return false end

    if npcType == "building" then
        -- Building NPC - show dialogue / profession interaction
        local profession = npc.profession or "citizen"
        local name = npc.name or "Stranger"

        log(name .. " (" .. profession .. ")", {0.9, 0.8, 0.4})

        -- Show dialogue if available
        if npc.dialogue then
            local dialogueOptions
            if type(npc.dialogue) == "table" then
                dialogueOptions = npc.dialogue
            else
                dialogueOptions = {npc.dialogue}
            end
            local dialogue = dialogueOptions[math.random(#dialogueOptions)]
            log('"' .. dialogue .. '"', {0.8, 0.8, 0.9})
        else
            -- Default greeting by profession
            local greetings = {
                shopkeeper = "Welcome to my shop! Browse my wares.",
                blacksmith = "Need something forged? I'm your smith.",
                priest = "Blessings upon you, traveler.",
                tavernkeep = "Pull up a chair! What'll you have?",
                stablemaster = "Fine beasts for sale. Take a look.",
                alchemist = "Potions, elixirs, remedies... I have it all.",
                wizard = "Knowledge is power. How may I assist?",
                fisher = "The catch is good today!",
                hunter = "The wilds hold many secrets.",
                merchant = "I deal in the finest goods. Interested?",
                butcher = "Fresh cuts! Best in town.",
                baker = "Fresh bread, hot from the oven!",
                tailor = "I can outfit you for any occasion.",
                jeweler = "Gems and finery for the discerning buyer.",
                wellkeeper = "The water runs clear today.",
            }
            local greeting = greetings[profession] or "Hello, traveler."
            log('"' .. greeting .. '"', {0.8, 0.8, 0.9})
        end

        return true

    elseif npcType == "wandering" then
        -- Wandering NPC - brief interaction
        local name = npc.name or "Stranger"
        local npcTypeId = npc.type or "citizen"

        log(name, {0.9, 0.8, 0.4})

        local dialogues = {
            guard = {
                "Stay out of trouble, citizen.",
                "The town is safe under our watch.",
                "Report anything suspicious.",
                "Move along.",
            },
            child = {
                "Tag! You're it!",
                "Have you seen my cat?",
                "Are you an adventurer? So cool!",
                "My mom says strangers are dangerous...",
            },
            cat = {
                "*purrs*",
                "*meow*",
                "*stares at you judgmentally*",
                "*rubs against your leg*",
            },
            bard = {
                "Care to hear a tale of adventure?",
                "The songs of heroes echo through time!",
                "Every journey makes a great story.",
                "A coin for a song, good traveler?",
            },
            beggar = {
                "Spare a coin for the poor?",
                "Blessings on you, kind soul.",
                "I've seen better days...",
                "Any work for honest hands?",
            },
            noble = {
                "Mind your manners around here.",
                "This town could use better governance.",
                "A fine day for business.",
                "I have connections, you know.",
            },
        }

        local pool = dialogues[npcTypeId] or {"Hello there.", "Nice day.", "Hmm.", "Good day to you."}
        local dialogue = pool[math.random(#pool)]
        log('"' .. dialogue .. '"', {0.8, 0.8, 0.9})

        return true
    end

    return false
end

-- ============================================================================
--                              DRAWING
-- ============================================================================

-- Draw all visible NPCs on the town grid.
-- Called from drawTown after buildings but before player.
-- Parameters:
--   mapX, mapY: pixel position of the town map area top-left
--   buildingW, buildingH: pixel size of each grid cell
--   buildingPadX, buildingPadY: padding offsets
--   playerGridX, playerGridY: current player position
--   mx, my: mouse position for hover detection
function TownNPCsVisible.draw(mapX, mapY, buildingW, buildingH, buildingPadX, buildingPadY, playerGridX, playerGridY, mx, my)
    if not state then return end
    local town = state.world and state.world.currentTown
    if not town then return end

    local time = love.timer.getTime()
    local getFont = _G.getFont

    -- Draw building NPCs (stationary, at their assigned building positions)
    if town.npcs then
        for _, npc in ipairs(town.npcs) do
            if npc.currentLocation and npc.currentLocation.gridX and npc.currentLocation.gridY then
                local gx = npc.currentLocation.gridX
                local gy = npc.currentLocation.gridY

                -- Calculate screen position (center of cell)
                local npcScreenX = mapX + buildingPadX + (gx - 1) * buildingW + buildingW / 2
                local npcScreenY = mapY + buildingPadY + (gy - 1) * buildingH + buildingH / 2

                local profession = npc.profession or "citizen"
                local npcColor = getNPCColor(profession)
                local npcIcon = getNPCIcon(profession)
                local pulse = 0.85 + 0.15 * math.sin(time * CONFIG.pulseSpeed + gx * 0.5 + gy * 0.8)

                -- Distance from player
                local dist = gridDist(gx, gy, playerGridX or 0, playerGridY or 0)

                -- Friendly glow circle (green tint to differentiate from enemies)
                love.graphics.setColor(npcColor[1] * 0.3, npcColor[2] * 0.3, npcColor[3] * 0.3, 0.4 * pulse)
                love.graphics.circle("fill", npcScreenX, npcScreenY, 14)

                -- NPC icon circle
                love.graphics.setColor(npcColor[1] * 0.7, npcColor[2] * 0.7, npcColor[3] * 0.7, 0.9 * pulse)
                love.graphics.circle("fill", npcScreenX, npcScreenY, 10)

                -- Friendly border (blue-green to differentiate from enemies' red)
                love.graphics.setColor(0.3, 0.7, 0.5, 0.7)
                love.graphics.setLineWidth(1)
                love.graphics.circle("line", npcScreenX, npcScreenY, 10)

                -- Icon letter
                love.graphics.setColor(1, 1, 1, 0.95 * pulse)
                if getFont then
                    love.graphics.setFont(getFont(10))
                end
                love.graphics.printf(npcIcon, npcScreenX - 10, npcScreenY - 6, 20, "center")

                -- Show name/profession when player is close
                if dist <= CONFIG.hoverShowRadius then
                    -- Name above NPC
                    love.graphics.setColor(0.9, 0.9, 1.0, 0.9)
                    if getFont then
                        love.graphics.setFont(getFont(8))
                    end
                    love.graphics.printf(npc.name or "NPC", npcScreenX - 40, npcScreenY - 24, 80, "center")

                    -- Profession below
                    love.graphics.setColor(npcColor[1], npcColor[2], npcColor[3], 0.8)
                    if getFont then
                        love.graphics.setFont(getFont(7))
                    end
                    love.graphics.printf(profession, npcScreenX - 40, npcScreenY + 12, 80, "center")

                    -- Interaction prompt when adjacent
                    if dist <= CONFIG.interactRadius then
                        local promptPulse = 0.7 + 0.3 * math.sin(time * 3)
                        love.graphics.setColor(0.4, 0.9, 0.5, promptPulse)
                        if getFont then
                            love.graphics.setFont(getFont(8))
                        end
                        love.graphics.printf("[E] Talk", npcScreenX - 30, npcScreenY + 22, 60, "center")
                    end
                end

                -- Mouse hover check for tooltip
                local mouseInRange = mx and my and
                    mx >= npcScreenX - 14 and mx <= npcScreenX + 14 and
                    my >= npcScreenY - 14 and my <= npcScreenY + 14
                if mouseInRange then
                    -- Tooltip on hover
                    love.graphics.setColor(0.1, 0.1, 0.15, 0.95)
                    love.graphics.rectangle("fill", mx + 10, my - 30, 130, 38, 4, 4)
                    love.graphics.setColor(0.9, 0.8, 0.4)
                    if getFont then
                        love.graphics.setFont(getFont(10))
                    end
                    love.graphics.print(npc.name or "NPC", mx + 15, my - 26)
                    love.graphics.setColor(npcColor[1], npcColor[2], npcColor[3])
                    if getFont then
                        love.graphics.setFont(getFont(9))
                    end
                    love.graphics.print(profession, mx + 15, my - 12)
                end
            end
        end
    end

    -- Draw wandering NPCs
    if town.wanderingNPCs then
        for _, wnpc in ipairs(town.wanderingNPCs) do
            if wnpc.visible ~= false and wnpc.gridX and wnpc.gridY then
                local gx = wnpc.gridX
                local gy = wnpc.gridY

                local npcScreenX = mapX + buildingPadX + (gx - 1) * buildingW + buildingW / 2
                local npcScreenY = mapY + buildingPadY + (gy - 1) * buildingH + buildingH / 2

                local npcTypeId = wnpc.type or "citizen"
                local npcColor = CONFIG.wanderingColors[npcTypeId] or CONFIG.defaultColor
                local npcIcon = CONFIG.wanderingIcons[npcTypeId] or CONFIG.defaultIcon
                local pulse = 0.85 + 0.15 * math.sin(time * CONFIG.pulseSpeed + gx * 1.1 + gy * 0.6)

                local dist = gridDist(gx, gy, playerGridX or 0, playerGridY or 0)

                -- Wandering NPC glow (softer, smaller)
                love.graphics.setColor(npcColor[1] * 0.2, npcColor[2] * 0.2, npcColor[3] * 0.2, 0.3 * pulse)
                love.graphics.circle("fill", npcScreenX, npcScreenY, 10)

                -- NPC dot
                love.graphics.setColor(npcColor[1] * 0.6, npcColor[2] * 0.6, npcColor[3] * 0.6, 0.85 * pulse)
                love.graphics.circle("fill", npcScreenX, npcScreenY, 7)

                -- Friendly border
                love.graphics.setColor(0.3, 0.6, 0.4, 0.5)
                love.graphics.circle("line", npcScreenX, npcScreenY, 7)

                -- Icon
                love.graphics.setColor(1, 1, 1, 0.9 * pulse)
                if getFont then
                    love.graphics.setFont(getFont(8))
                end
                love.graphics.printf(npcIcon, npcScreenX - 8, npcScreenY - 5, 16, "center")

                -- Name when close
                if dist <= CONFIG.hoverShowRadius then
                    love.graphics.setColor(0.8, 0.8, 0.9, 0.85)
                    if getFont then
                        love.graphics.setFont(getFont(7))
                    end
                    love.graphics.printf(wnpc.name or npcTypeId, npcScreenX - 35, npcScreenY - 18, 70, "center")

                    -- Interaction prompt
                    if dist <= CONFIG.interactRadius then
                        local promptPulse = 0.7 + 0.3 * math.sin(time * 3)
                        love.graphics.setColor(0.4, 0.9, 0.5, promptPulse)
                        if getFont then
                            love.graphics.setFont(getFont(7))
                        end
                        love.graphics.printf("[E] Talk", npcScreenX - 25, npcScreenY + 16, 50, "center")
                    end
                end
            end
        end
    end
end

-- Draw an interaction prompt at the bottom of the town view when adjacent to NPC
function TownNPCsVisible.drawInteractionPrompt(x, y, w, h, playerGridX, playerGridY)
    if not state then return end

    local npc, npcType = TownNPCsVisible.getAdjacentNPC(playerGridX, playerGridY)
    if not npc then return end

    local time = love.timer.getTime()
    local promptPulse = 0.8 + 0.2 * math.sin(time * 3)
    local getFont = _G.getFont

    -- Draw prompt box
    local promptW = 220
    local promptH = 32
    local promptX = x + (w - promptW) / 2
    local promptY = y + h - 100

    love.graphics.setColor(0.1, 0.15, 0.1, 0.9 * promptPulse)
    love.graphics.rectangle("fill", promptX, promptY, promptW, promptH, 5, 5)
    love.graphics.setColor(0.3, 0.7, 0.4, 0.8)
    love.graphics.rectangle("line", promptX, promptY, promptW, promptH, 5, 5)

    -- Prompt text
    local name = npc.name or "NPC"
    local profession = ""
    if npcType == "building" then
        profession = npc.profession or ""
    elseif npcType == "wandering" then
        profession = npc.type or ""
    end

    love.graphics.setColor(0.9, 0.9, 1.0, promptPulse)
    if getFont then
        love.graphics.setFont(getFont(11))
    end
    local promptText = "[E] Talk to " .. name
    if profession ~= "" then
        promptText = promptText .. " (" .. profession .. ")"
    end
    love.graphics.printf(promptText, promptX, promptY + 9, promptW, "center")
end

return TownNPCsVisible
