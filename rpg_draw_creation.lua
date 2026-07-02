-- RPG Draw: Character Creation & Character Sheet
-- Extracted from textrpg.lua
-- Contains: drawCharacterSheet, drawDevModePrompt, drawSkillTree,
-- drawTalentSelection, drawAscensionTree, drawSpecializationSelection,
-- drawClassSelect, drawRaceSelection, drawStatAllocation, drawClassSelection,
-- drawBackgroundSelection, drawGenderSelection, drawPortraitAndName,
-- drawCharacterReview, drawPartyUI

local Data = require("rpg_data")
local M = {}

-- Upvalues set by register()
local state
local F

-- Data references not available through rpg_data (passed via deps)
local SKILL_TREES

-- Convenience aliases resolved after register()
local getFont
local getPortraitImage
local getCreationPortrait
local getStatModifier
local getPlayerSpecialization
local getSpecializationOptions

-- List every function name that will be installed onto F
M.F_FUNCTIONS = {
    "drawCharacterSheet",
    "drawDevModePrompt",
    "drawSkillTree",
    "drawTalentSelection",
    "drawAscensionTree",
    "drawSpecializationSelection",
    "drawClassSelect",
    "drawRaceSelection",
    "drawStatAllocation",
    "drawClassSelection",
    "drawBackgroundSelection",
    "drawGenderSelection",
    "drawPortraitAndName",
    "drawCharacterReview",
    "drawPartyUI",
    "drawCompanionSkillTree",
    "drawCompanionTalentSelection",
}

function M.register(s, f, deps)
    state = s
    F = f

    -- Data tables not in rpg_data
    SKILL_TREES = deps and deps.SKILL_TREES or nil

    -- Install every listed function onto F
    for _, name in ipairs(M.F_FUNCTIONS) do
        if M[name] then
            F[name] = M[name]
        end
    end

    -- Bind convenience aliases so internal calls work without F. prefix
    getFont                = F.getFont
    getPortraitImage       = F.getPortraitImage
    getCreationPortrait    = F.getCreationPortrait
    getStatModifier        = F.getStatModifier
    getPlayerSpecialization = F.getPlayerSpecialization
    getSpecializationOptions = F.getSpecializationOptions
end

local function log(text, color)
    if F and F.log then F.log(text, color)
    elseif state and state.textLog then
        table.insert(state.textLog, {text = text, color = color or {0.8,0.8,0.8}, time = love.timer.getTime()})
        if #state.textLog > 100 then table.remove(state.textLog, 1) end
    end
end

-- Forward declaration for party UI helper
local drawPartyMemberCard

-- ============================================================================
-- SHARED SKILL TREE RENDERING
-- ============================================================================

-- Internal helper: draws a skill tree panel for any entity (player or companion).
-- @param entity        table with .skillPoints, .unlockedSkills, .level fields
-- @param tree          the SKILL_TREES.universal table
-- @param selectedIndex current cursor index (integer)
-- @param opts          {title, showAuto, autoAllocate, footer}
-- @return nothing
-- Region colors for node-graph skill tree
local REGION_COLORS = {
    warfare  = {0.9, 0.35, 0.3},
    sorcery  = {0.55, 0.35, 0.9},
    shadow   = {0.7, 0.3, 0.8},
    survival = {0.3, 0.8, 0.4},
    center   = {0.8, 0.8, 0.8},
}

-- Node radius by type
local NODE_RADII = {
    start    = 18,
    minor    = 10,
    skill    = 14,
    keystone = 20,
}

local function drawSkillTreePanel(entity, tree, selectedIndex, opts)
    local screenW, screenH = love.graphics.getDimensions()

    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Main panel
    local panelW = math.min(820, screenW - 20)
    local panelH = math.min(620, screenH - 20)
    local panelX = math.floor(screenW / 2 - panelW / 2)
    local panelY = math.floor(screenH / 2 - panelH / 2)

    love.graphics.setColor(0.08, 0.08, 0.12)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)
    love.graphics.setColor(0.3, 0.5, 0.7)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 10, 10)
    love.graphics.setLineWidth(1)

    if not tree or not tree.nodes then
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("No skill tree available", panelX, panelY + panelH / 2, panelW, "center")
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.setFont(getFont(12))
        love.graphics.printf("[Escape] Close", panelX, panelY + panelH - 25, panelW, "center")
        return
    end

    -- Title
    love.graphics.setColor(0.3, 0.7, 0.9)
    love.graphics.setFont(getFont(22))
    love.graphics.printf(opts.title or (tree.name .. " - Skill Tree"), panelX, panelY + 10, panelW, "center")

    -- Skill points (right-aligned)
    love.graphics.setColor(0.9, 0.8, 0.2)
    love.graphics.setFont(getFont(16))
    love.graphics.printf("Skill Points: " .. (entity.skillPoints or 0), panelX, panelY + 38, panelW - 20, "right")

    -- Auto-allocate toggle (companion only)
    if opts.showAuto then
        local autoStr = opts.autoAllocate and "Auto: ON" or "Auto: OFF"
        love.graphics.setColor(opts.autoAllocate and {0.3, 0.8, 0.4} or {0.8, 0.4, 0.3})
        love.graphics.setFont(getFont(13))
        love.graphics.print(autoStr, panelX + 20, panelY + 41)
    end

    -- Viewport area for the node graph (leave room for header, info panel, footer)
    local vpX = panelX + 10
    local vpY = panelY + 60
    local vpW = panelW - 20
    local vpH = panelH - 160  -- reserve space for info panel + footer at bottom

    -- Build node lookup by id for quick access
    local nodeById = {}
    for _, node in ipairs(tree.nodes) do
        nodeById[node.id] = node
    end

    -- Determine selected node and camera center
    local selIdx = selectedIndex or 1
    if selIdx < 1 then selIdx = 1 end
    if selIdx > #tree.nodes then selIdx = #tree.nodes end
    local selNode = tree.nodes[selIdx]

    local gridSize = 55  -- pixels per grid unit
    -- Camera centers on the selected node
    local camX = (selNode and selNode.x or 0) * gridSize
    local camY = (selNode and selNode.y or 0) * gridSize
    -- Offset so the selected node appears in the center of the viewport
    local offsetX = math.floor(vpX + vpW / 2 - camX)
    local offsetY = math.floor(vpY + vpH / 2 - camY)

    -- Begin scissor clipping for the viewport
    love.graphics.setScissor(vpX, vpY, vpW, vpH)

    -- Draw subtle region background glows
    for _, node in ipairs(tree.nodes) do
        local rc = REGION_COLORS[node.region] or REGION_COLORS.center
        local nx = node.x * gridSize + offsetX
        local ny = node.y * gridSize + offsetY
        local glowR = 40
        love.graphics.setColor(rc[1], rc[2], rc[3], 0.04)
        love.graphics.circle("fill", nx, ny, glowR)
    end

    -- Draw connection lines
    love.graphics.setLineWidth(2)
    for _, node in ipairs(tree.nodes) do
        if node.connections then
            for _, connId in ipairs(node.connections) do
                -- Only draw each connection once (avoid duplicates)
                if node.id < connId then
                    local other = nodeById[connId]
                    if other then
                        local x1 = node.x * gridSize + offsetX
                        local y1 = node.y * gridSize + offsetY
                        local x2 = other.x * gridSize + offsetX
                        local y2 = other.y * gridSize + offsetY

                        local nodeUnlocked = entity.unlockedSkills and entity.unlockedSkills[node.id]
                        local otherUnlocked = entity.unlockedSkills and entity.unlockedSkills[connId]

                        if nodeUnlocked and otherUnlocked then
                            -- Both unlocked: bright green
                            love.graphics.setColor(0.3, 0.85, 0.4, 0.9)
                        elseif nodeUnlocked or otherUnlocked then
                            -- One unlocked: dim gray
                            love.graphics.setColor(0.45, 0.45, 0.5, 0.6)
                        else
                            -- Neither unlocked: very dim
                            love.graphics.setColor(0.25, 0.25, 0.3, 0.35)
                        end
                        love.graphics.line(x1, y1, x2, y2)
                    end
                end
            end
        end
    end
    love.graphics.setLineWidth(1)

    -- Draw nodes
    for i, node in ipairs(tree.nodes) do
        local nx = node.x * gridSize + offsetX
        local ny = node.y * gridSize + offsetY
        local radius = NODE_RADII[node.nodeType] or 12
        local rc = REGION_COLORS[node.region] or REGION_COLORS.center

        local isUnlocked = entity.unlockedSkills and entity.unlockedSkills[node.id]

        -- Check if node is unlockable (at least one connected node is unlocked AND enough SP)
        local isUnlockable = false
        if not isUnlocked and node.connections then
            local hasConnectedUnlock = false
            for _, connId in ipairs(node.connections) do
                if entity.unlockedSkills and entity.unlockedSkills[connId] then
                    hasConnectedUnlock = true
                    break
                end
            end
            local cost = node.cost or 0
            if hasConnectedUnlock and (entity.skillPoints or 0) >= cost then
                isUnlockable = true
            end
        end

        local isSelected = (i == selIdx)

        -- Node fill color based on state
        if isUnlocked then
            -- Bright region color
            love.graphics.setColor(rc[1], rc[2], rc[3], 1.0)
        elseif isUnlockable then
            -- Dimmed region color
            love.graphics.setColor(rc[1] * 0.5, rc[2] * 0.5, rc[3] * 0.5, 0.8)
        else
            -- Very dark
            love.graphics.setColor(0.15, 0.15, 0.2, 0.7)
        end
        love.graphics.circle("fill", nx, ny, radius)

        -- Node border
        if isSelected then
            -- Gold border for selected node
            love.graphics.setColor(0.95, 0.85, 0.3, 1.0)
            love.graphics.setLineWidth(3)
            love.graphics.circle("line", nx, ny, radius + 2)
            love.graphics.setLineWidth(1)
        else
            if isUnlocked then
                love.graphics.setColor(1, 1, 1, 0.5)
            elseif isUnlockable then
                love.graphics.setColor(0.6, 0.6, 0.7, 0.4)
            else
                love.graphics.setColor(0.3, 0.3, 0.35, 0.3)
            end
            love.graphics.circle("line", nx, ny, radius)
        end

        -- Node name label (only for skill and keystone nodes to reduce clutter)
        if node.nodeType == "skill" or node.nodeType == "keystone" then
            love.graphics.setFont(getFont(9))
            if isUnlocked then
                love.graphics.setColor(1, 1, 1, 0.9)
            elseif isUnlockable then
                love.graphics.setColor(0.7, 0.7, 0.7, 0.7)
            else
                love.graphics.setColor(0.45, 0.45, 0.5, 0.5)
            end
            local labelW = getFont(9):getWidth(node.name)
            love.graphics.print(node.name, math.floor(nx - labelW / 2), ny + radius + 3)
        end
    end

    -- End scissor clipping
    love.graphics.setScissor()

    -- Region labels at edges of viewport
    love.graphics.setFont(getFont(12))
    love.graphics.setColor(REGION_COLORS.warfare[1], REGION_COLORS.warfare[2], REGION_COLORS.warfare[3], 0.6)
    love.graphics.printf("WARFARE", vpX, vpY + 2, vpW, "center")
    love.graphics.setColor(REGION_COLORS.sorcery[1], REGION_COLORS.sorcery[2], REGION_COLORS.sorcery[3], 0.6)
    love.graphics.printf("SORCERY", vpX, vpY + vpH / 2 - 8, vpW, "right")
    love.graphics.setColor(REGION_COLORS.shadow[1], REGION_COLORS.shadow[2], REGION_COLORS.shadow[3], 0.6)
    love.graphics.printf("SHADOW", vpX, vpY + vpH - 18, vpW, "center")
    love.graphics.setColor(REGION_COLORS.survival[1], REGION_COLORS.survival[2], REGION_COLORS.survival[3], 0.6)
    love.graphics.printf("SURVIVAL", vpX, vpY + vpH / 2 - 8, vpW, "left")

    -- Info panel at the bottom: selected node details
    local infoY = vpY + vpH + 6
    local infoH = panelH - (vpH + 60 + 30)  -- remaining space minus header and footer
    love.graphics.setColor(0.1, 0.1, 0.14)
    love.graphics.rectangle("fill", panelX + 10, infoY, panelW - 20, infoH, 6, 6)
    love.graphics.setColor(0.25, 0.25, 0.35)
    love.graphics.rectangle("line", panelX + 10, infoY, panelW - 20, infoH, 6, 6)

    if selNode then
        local isUnlocked = entity.unlockedSkills and entity.unlockedSkills[selNode.id]

        -- Node name
        local nameRC = REGION_COLORS[selNode.region] or REGION_COLORS.center
        love.graphics.setColor(nameRC[1], nameRC[2], nameRC[3])
        love.graphics.setFont(getFont(16))
        love.graphics.print(selNode.name, panelX + 22, infoY + 6)

        -- Node type badge
        love.graphics.setFont(getFont(11))
        love.graphics.setColor(0.55, 0.55, 0.65)
        local typeStr = (selNode.nodeType or "skill"):upper()
        love.graphics.print("[" .. typeStr .. "]", panelX + 22 + getFont(16):getWidth(selNode.name) + 10, infoY + 10)

        -- Status and cost (right side)
        love.graphics.setFont(getFont(14))
        if isUnlocked then
            love.graphics.setColor(0.3, 0.9, 0.4)
            love.graphics.printf("UNLOCKED", panelX + 10, infoY + 8, panelW - 40, "right")
        else
            love.graphics.setColor(0.9, 0.8, 0.3)
            love.graphics.printf("Cost: " .. (selNode.cost or 0) .. " SP", panelX + 10, infoY + 8, panelW - 40, "right")
        end

        -- Description
        love.graphics.setFont(getFont(12))
        love.graphics.setColor(0.8, 0.78, 0.7)
        love.graphics.printf(selNode.desc or "", panelX + 22, infoY + 30, panelW - 54, "left")
    end

    -- Footer
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.setFont(getFont(12))
    love.graphics.printf(opts.footer or "[Arrows] Navigate  |  [Enter] Unlock  |  [Escape] Close", panelX, panelY + panelH - 25, panelW, "center")

    love.graphics.setColor(1, 1, 1)
end

-- ============================================================================
-- CHARACTER SHEET
-- ============================================================================

M.drawCharacterSheet = function()
    local screenW, screenH = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()
    local p = state.player
    if not p then return end

    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Main panel
    local panelW = math.min(600, screenW - 60)
    local panelH = math.min(640, screenH - 60)
    local panelX = screenW/2 - panelW/2
    local panelY = screenH/2 - panelH/2

    love.graphics.setColor(0.12, 0.12, 0.18)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)
    love.graphics.setColor(0.4, 0.35, 0.5)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 10, 10)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(0.9, 0.75, 0.3)
    love.graphics.setFont(getFont(24))
    love.graphics.printf("CHARACTER SHEET", panelX, panelY + 15, panelW, "center")

    -- Close button
    local closeX, closeY, closeW, closeH = panelX + panelW - 35, panelY + 10, 25, 25
    local closeHover = mx >= closeX and mx <= closeX + closeW and my >= closeY and my <= closeY + closeH
    love.graphics.setColor(closeHover and {0.8, 0.3, 0.3} or {0.5, 0.2, 0.2})
    love.graphics.rectangle("fill", closeX, closeY, closeW, closeH, 4, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(16))
    love.graphics.printf("X", closeX, closeY + 4, closeW, "center")

    local y = panelY + 55

    -- Character info
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(18))
    love.graphics.print(p.name, panelX + 20, y)

    -- Race display (with vampire sub-race if applicable)
    local raceName = p.race and p.race.name or "Human"
    if p.isVampire then
        love.graphics.setColor(0.8, 0.2, 0.3)
        love.graphics.setFont(getFont(13))
        love.graphics.print(raceName .. " (Vampire)", panelX + 200, y + 4)
    else
        love.graphics.setColor(p.race and p.race.color or {0.7, 0.7, 0.7})
        love.graphics.setFont(getFont(13))
        love.graphics.print(raceName, panelX + 200, y + 4)
    end

    -- Show class and specialization
    local spec = getPlayerSpecialization()
    if spec then
        love.graphics.setColor(spec.color)
        love.graphics.print(spec.name .. " - Level " .. p.level, panelX + 20, y + 22)
        love.graphics.setColor(0.6, 0.6, 0.7)
        love.graphics.setFont(getFont(12))
        love.graphics.print("(" .. p.class.name .. " specialization)", panelX + 20, y + 42)
    else
        love.graphics.setColor(p.class.color)
        love.graphics.print(p.class.name .. " - Level " .. p.level, panelX + 20, y + 22)
    end

    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(getFont(14))
    love.graphics.print("XP: " .. p.xp .. "/" .. p.xpToLevel, panelX + 20, y + 56)

    y = y + 85

    -- === PRIMARY STATS ===
    love.graphics.setColor(0.9, 0.75, 0.3)
    love.graphics.setFont(getFont(16))
    love.graphics.print("=== PRIMARY STATS ===", panelX + 20, y)
    y = y + 25

    if p.stats then
        love.graphics.setFont(getFont(14))
        local statOrder = {"MIGHT", "AGILITY", "VIGOR", "MIND", "SPIRIT", "PRESENCE", "FAITH"}
        local col = 0
        for i, statId in ipairs(statOrder) do
            local statDef = Data.STAT_DEFINITIONS[statId]
            if not statDef then goto continue_stat end
            local value = p.stats[statId] or 10
            local mod = getStatModifier(value)
            local modStr = mod >= 0 and ("+" .. mod) or tostring(mod)

            local sx = panelX + 20 + col * 180
            local sy = y + (math.floor((i-1) / 3)) * 22

            love.graphics.setColor(statDef.color)
            love.graphics.print(statDef.name .. ": " .. value .. " (" .. modStr .. ")", sx, sy)

            col = col + 1
            if col >= 3 then col = 0 end
            ::continue_stat::
        end
    end

    y = y + 75

    -- === COMBAT STATS ===
    love.graphics.setColor(0.9, 0.75, 0.3)
    love.graphics.setFont(getFont(16))
    love.graphics.print("=== COMBAT STATS ===", panelX + 20, y)
    y = y + 25

    love.graphics.setFont(getFont(14))
    love.graphics.setColor(0.9, 0.3, 0.3)
    love.graphics.print("HP: " .. p.hp .. "/" .. p.maxHP, panelX + 20, y)
    love.graphics.setColor(0.3, 0.5, 0.9)
    love.graphics.print("Mana: " .. p.mana .. "/" .. p.maxMana, panelX + 200, y)
    love.graphics.setColor(1, 0.9, 0.3)
    love.graphics.print("Gold: " .. p.gold, panelX + 380, y)
    y = y + 22

    love.graphics.setColor(0.9, 0.6, 0.3)
    love.graphics.print("Attack: " .. p.attack, panelX + 20, y)
    love.graphics.setColor(0.3, 0.6, 0.9)
    love.graphics.print("Defense: " .. p.defense, panelX + 140, y)
    love.graphics.setColor(0.9, 0.9, 0.3)
    love.graphics.print("Crit: " .. (p.critChance or 5) .. "%", panelX + 260, y)
    love.graphics.setColor(0.3, 0.9, 0.5)
    love.graphics.print("Dodge: " .. (p.dodgeChance or 0) .. "%", panelX + 380, y)

    y = y + 40

    -- === SKILLS (from skill tree) ===
    love.graphics.setColor(0.9, 0.75, 0.3)
    love.graphics.setFont(getFont(16))
    love.graphics.print("=== SKILLS ===", panelX + 20, y)

    -- Skill points available
    love.graphics.setColor(0.3, 0.8, 0.9)
    love.graphics.print("Skill Points: " .. (p.skillPoints or 0), panelX + 350, y)
    y = y + 25

    love.graphics.setFont(getFont(14))
    love.graphics.setColor(0.7, 0.7, 0.8)
    -- Count unlocked skills (dict format, skip "start")
    local skillNames = {}
    local skillTree = SKILL_TREES and SKILL_TREES.universal
    if p.unlockedSkills and skillTree and skillTree.nodes then
        for _, node in ipairs(skillTree.nodes) do
            if p.unlockedSkills[node.id] and node.id ~= "start" then
                table.insert(skillNames, node.name)
            end
        end
    end
    if #skillNames > 0 then
        love.graphics.print(table.concat(skillNames, ", "), panelX + 20, y)
    else
        love.graphics.print("No skills unlocked yet. Press [S] for Skill Tree.", panelX + 20, y)
    end

    y = y + 35

    -- === TALENTS ===
    love.graphics.setColor(0.9, 0.75, 0.3)
    love.graphics.setFont(getFont(16))
    love.graphics.print("=== TALENTS ===", panelX + 20, y)

    -- Pending talent indicator
    if p.pendingTalentSelection then
        love.graphics.setColor(0.9, 0.7, 0.2)
        love.graphics.print("NEW TALENT AVAILABLE! Press [T]", panelX + 300, y)
    end
    y = y + 25

    love.graphics.setFont(getFont(14))
    love.graphics.setColor(0.7, 0.7, 0.8)
    if p.talents then
        local talentNames = {}
        for talentId, _ in pairs(p.talents) do
            -- Use O(1) lookup instead of nested loops
            local talentDef = Data.TALENT_LOOKUP[talentId]
            if talentDef then
                table.insert(talentNames, talentDef.name)
            end
        end
        if #talentNames > 0 then
            love.graphics.print(table.concat(talentNames, ", "), panelX + 20, y)
        else
            love.graphics.print("No talents selected yet.", panelX + 20, y)
        end
    else
        love.graphics.print("No talents selected yet.", panelX + 20, y)
    end

    y = y + 35

    -- === BACKGROUND PASSIVES ===
    if p.background and p.background.passives and #p.background.passives > 0 then
        love.graphics.setColor(0.9, 0.75, 0.3)
        love.graphics.setFont(getFont(16))
        love.graphics.print("=== " .. (p.background.name or "BACKGROUND") .. " ===", panelX + 20, y)
        y = y + 22
        love.graphics.setFont(getFont(13))
        love.graphics.setColor(0.85, 0.85, 0.95)
        for _, pid in ipairs(p.background.passives) do
            local desc = Data.PASSIVE_DESCRIPTIONS[pid] or pid
            love.graphics.print("* " .. desc, panelX + 25, y)
            y = y + 17
        end
        y = y + 15
    end

    -- === EQUIPMENT ===
    love.graphics.setColor(0.9, 0.75, 0.3)
    love.graphics.setFont(getFont(16))
    love.graphics.print("=== EQUIPMENT ===", panelX + 20, y)
    y = y + 25

    love.graphics.setFont(getFont(14))
    love.graphics.setColor(0.8, 0.5, 0.3)
    local weaponName = p.equipment.weapon and p.equipment.weapon.name or "None"
    love.graphics.print("Weapon: " .. weaponName, panelX + 20, y)

    love.graphics.setColor(0.3, 0.6, 0.8)
    local armorName = p.equipment.armor and p.equipment.armor.name or "None"
    love.graphics.print("Armor: " .. armorName, panelX + 300, y)

    y = y + 22

    love.graphics.setColor(0.5, 0.7, 0.9)
    local shieldName = p.equipment.shield and p.equipment.shield.name or "None"
    love.graphics.print("Shield: " .. shieldName, panelX + 20, y)

    love.graphics.setColor(0.75, 0.6, 0.85)
    local accessoryName = p.equipment.accessory and p.equipment.accessory.name or "None"
    love.graphics.print("Accessory: " .. accessoryName, panelX + 300, y)

    -- Dev Mode button (bottom right of panel)
    local devBtnW, devBtnH = 80, 22
    local devBtnX = panelX + panelW - devBtnW - 15
    local devBtnY = panelY + panelH - 55
    local devBtnHover = mx >= devBtnX and mx <= devBtnX + devBtnW and my >= devBtnY and my <= devBtnY + devBtnH

    if state.devModeEnabled then
        love.graphics.setColor(0.2, 0.5, 0.2)
        love.graphics.rectangle("fill", devBtnX, devBtnY, devBtnW, devBtnH, 4, 4)
        love.graphics.setColor(0.5, 0.8, 0.5)
        love.graphics.setFont(getFont(11))
        love.graphics.printf("DEV ON", devBtnX, devBtnY + 5, devBtnW, "center")
    else
        love.graphics.setColor(devBtnHover and {0.4, 0.25, 0.25} or {0.3, 0.15, 0.15})
        love.graphics.rectangle("fill", devBtnX, devBtnY, devBtnW, devBtnH, 4, 4)
        love.graphics.setColor(devBtnHover and {0.9, 0.5, 0.5} or {0.6, 0.3, 0.3})
        love.graphics.setFont(getFont(11))
        love.graphics.printf("Dev Mode", devBtnX, devBtnY + 5, devBtnW, "center")
    end

    -- Store button bounds for click detection
    state.devModeButton = {x = devBtnX, y = devBtnY, w = devBtnW, h = devBtnH}

    -- Footer instructions
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("[C] Close  |  [S] Skills  |  [T] Talents  |  [P] Ascension", panelX, panelY + panelH - 30, panelW, "center")

    love.graphics.setColor(1, 1, 1)
end

-- ============================================================================
-- DEV MODE PASSWORD PROMPT
-- ============================================================================

M.drawDevModePrompt = function()
    local screenW, screenH = love.graphics.getDimensions()

    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Prompt panel
    local panelW, panelH = 350, 180
    local panelX = screenW/2 - panelW/2
    local panelY = screenH/2 - panelH/2

    love.graphics.setColor(0.15, 0.1, 0.1)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 8, 8)
    love.graphics.setColor(0.6, 0.3, 0.3)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 8, 8)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(0.9, 0.4, 0.4)
    love.graphics.setFont(getFont(18))
    love.graphics.printf("DEV MODE ACCESS", panelX, panelY + 20, panelW, "center")

    -- Instruction
    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.setFont(getFont(14))
    love.graphics.printf("Enter password:", panelX, panelY + 55, panelW, "center")

    -- Password input box
    local inputW, inputH = 200, 30
    local inputX = panelX + panelW/2 - inputW/2
    local inputY = panelY + 80

    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle("fill", inputX, inputY, inputW, inputH, 4, 4)
    love.graphics.setColor(0.5, 0.4, 0.4)
    love.graphics.rectangle("line", inputX, inputY, inputW, inputH, 4, 4)

    -- Password text (shown as asterisks)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(16))
    local displayText = string.rep("*", #state.devModePassword)
    love.graphics.printf(displayText, inputX + 5, inputY + 6, inputW - 10, "center")

    -- Instructions
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("[Enter] Submit  |  [Escape] Cancel", panelX, panelY + 125, panelW, "center")

    -- Error message if wrong password
    if state.devModePasswordError then
        love.graphics.setColor(0.9, 0.3, 0.3)
        love.graphics.printf("Incorrect password", panelX, panelY + 145, panelW, "center")
    end

    love.graphics.setColor(1, 1, 1)
end

-- ============================================================================
-- SKILL TREE
-- ============================================================================

M.drawSkillTree = function()
    local p = state.player
    if not p then return end
    local tree = SKILL_TREES and SKILL_TREES.universal
    drawSkillTreePanel(p, tree, state.selectedSkillIndex or 1, {
        title = tree and (tree.name .. " - Skill Tree") or nil,
        footer = "[Arrows] Navigate  |  [Enter] Unlock  |  [Escape] Close",
    })
end

-- ============================================================================
-- TALENT SELECTION
-- ============================================================================

M.drawTalentSelection = function()
    local screenW, screenH = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()
    local p = state.player
    if not p then return end

    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Main panel
    local panelW = math.min(650, screenW - 40)
    local panelH = math.min(480, screenH - 40)
    local panelX = screenW/2 - panelW/2
    local panelY = screenH/2 - panelH/2

    love.graphics.setColor(0.12, 0.1, 0.15)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)
    love.graphics.setColor(0.7, 0.5, 0.2)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 10, 10)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(22))
    love.graphics.printf("SELECT A TALENT", panelX, panelY + 15, panelW, "center")

    love.graphics.setColor(0.7, 0.6, 0.5)
    love.graphics.setFont(getFont(14))
    love.graphics.printf("Level " .. p.level .. " - Choose your specialization", panelX, panelY + 45, panelW, "center")

    -- Build available talents list
    local availableTalents = {}

    -- Universal talents for this level
    for _, t in ipairs(Data.UNIVERSAL_TALENTS) do
        if t.level <= p.level then
            local owned = p.talents and p.talents[t.id]
            if not owned then
                table.insert(availableTalents, {talent = t, type = "universal"})
            end
        end
    end

    -- Class talents for this level
    if Data.CLASS_TALENTS[p.class.id] then
        for _, t in ipairs(Data.CLASS_TALENTS[p.class.id]) do
            if t.level <= p.level then
                local owned = p.talents and p.talents[t.id]
                if not owned then
                    table.insert(availableTalents, {talent = t, type = "class"})
                end
            end
        end
    end

    local y = panelY + 80
    local talentH = 60
    local talentW = panelW - 60

    for i, entry in ipairs(availableTalents) do
        local t = entry.talent
        local isSelected = state.selectedTalentIndex == i

        -- Background
        local bgColor = entry.type == "class" and {0.2, 0.15, 0.25} or {0.15, 0.18, 0.22}
        if isSelected then
            bgColor[1] = bgColor[1] + 0.15
            bgColor[2] = bgColor[2] + 0.15
            bgColor[3] = bgColor[3] + 0.15
        end
        love.graphics.setColor(bgColor)
        love.graphics.rectangle("fill", panelX + 30, y, talentW, talentH, 6, 6)

        local borderColor = isSelected and {0.9, 0.7, 0.2} or {0.4, 0.35, 0.3}
        love.graphics.setColor(borderColor)
        love.graphics.setLineWidth(isSelected and 2 or 1)
        love.graphics.rectangle("line", panelX + 30, y, talentW, talentH, 6, 6)
        love.graphics.setLineWidth(1)

        -- Talent name
        love.graphics.setColor(entry.type == "class" and {0.9, 0.6, 0.9} or {0.8, 0.9, 1})
        love.graphics.setFont(getFont(16))
        love.graphics.print(t.name, panelX + 45, y + 8)

        -- Type badge
        love.graphics.setColor(entry.type == "class" and {0.6, 0.4, 0.6} or {0.4, 0.5, 0.6})
        love.graphics.setFont(getFont(11))
        love.graphics.print(entry.type == "class" and "[CLASS]" or "[UNIVERSAL]", panelX + talentW - 40, y + 10)

        -- Description
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.setFont(getFont(13))
        love.graphics.print(t.desc, panelX + 45, y + 32)

        y = y + talentH + 8

        if i >= 5 then break end  -- Max 5 visible
    end

    -- Footer
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("[Up/Down] Navigate  |  [Enter] Select  |  [Escape] Close", panelX, panelY + panelH - 25, panelW, "center")

    love.graphics.setColor(1, 1, 1)
end

-- ============================================================================
-- ASCENSION TREE UI
-- Account-wide prestige skill tree that persists across all characters
-- ============================================================================

M.drawAscensionTree = function()
    local screenW, screenH = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()

    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Main panel (larger to fit the tree)
    local panelW = math.min(800, screenW - 40)
    local panelH = math.min(600, screenH - 40)
    local panelX = screenW/2 - panelW/2
    local panelY = screenH/2 - panelH/2

    -- Dark purple/cosmic background for the ascension theme
    love.graphics.setColor(0.08, 0.05, 0.15)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 12, 12)

    -- Golden/purple gradient border
    love.graphics.setColor(0.6, 0.4, 0.9)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 12, 12)
    love.graphics.setLineWidth(1)

    -- Title with glow effect
    love.graphics.setColor(0.9, 0.7, 1)
    love.graphics.setFont(getFont(24))
    love.graphics.printf("ASCENSION TREE", panelX, panelY + 15, panelW, "center")

    -- Ascension info bar
    local ascensionCount = PlayerData.ascensionCount or 0
    local currentAP = PlayerData.ascensionPoints or 0
    local totalAP = PlayerData.totalAPEarned or 0

    love.graphics.setColor(0.7, 0.6, 0.8)
    love.graphics.setFont(getFont(14))
    love.graphics.printf(
        "Ascensions: " .. ascensionCount .. "  |  Available AP: " .. currentAP .. "  |  Total Earned: " .. totalAP,
        panelX, panelY + 48, panelW, "center"
    )

    -- Close button
    local closeX, closeY, closeW, closeH = panelX + panelW - 35, panelY + 10, 25, 25
    local closeHover = mx >= closeX and mx <= closeX + closeW and my >= closeY and my <= closeY + closeH
    love.graphics.setColor(closeHover and {0.8, 0.3, 0.3} or {0.5, 0.2, 0.2})
    love.graphics.rectangle("fill", closeX, closeY, closeW, closeH, 4, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(16))
    love.graphics.printf("X", closeX, closeY + 4, closeW, "center")

    -- Organize skills by tier
    local tiers = {}
    for _, skill in ipairs(Data.ASCENSION_TREE) do
        if not tiers[skill.tier] then
            tiers[skill.tier] = {}
        end
        table.insert(tiers[skill.tier], skill)
    end

    -- Draw skills by tier
    local contentY = panelY + 75
    local contentH = panelH - 110
    local skillH = 55
    local skillMargin = 8
    local scrollOffset = state.ascensionScrollOffset or 0

    -- Scissor for scrolling
    love.graphics.setScissor(panelX + 10, contentY, panelW - 20, contentH)

    local drawY = contentY - scrollOffset
    local skillIndex = 0

    for tier = 1, 5 do
        if tiers[tier] and #tiers[tier] > 0 then
            -- Tier header
            local tierColors = {
                {0.5, 0.7, 0.5},   -- Tier 1: Green
                {0.5, 0.6, 0.8},   -- Tier 2: Blue
                {0.7, 0.5, 0.7},   -- Tier 3: Purple
                {0.8, 0.6, 0.3},   -- Tier 4: Orange
                {0.9, 0.4, 0.4},   -- Tier 5: Red
            }

            love.graphics.setColor(tierColors[tier] or {0.7, 0.7, 0.7})
            love.graphics.setFont(getFont(16))
            love.graphics.print("=== TIER " .. tier .. " ===", panelX + 20, drawY)
            drawY = drawY + 25

            -- Skills in this tier (2 columns)
            local col = 0
            local skillW = (panelW - 60) / 2
            local rowStartY = drawY

            for _, skill in ipairs(tiers[tier]) do
                skillIndex = skillIndex + 1
                local isSelected = state.selectedAscensionIndex == skillIndex

                local skillX = panelX + 20 + col * (skillW + 10)
                local skillY = drawY

                -- Get current rank and path
                local currentRank = F.getAscensionSkillRank(skill.id)
                local tree = PlayerData.ascensionTree or {}
                local currentPath = tree.skillPaths and tree.skillPaths[skill.id]
                local cost = F.getAscensionSkillCost(skill.id)
                local canAfford = (PlayerData.ascensionPoints or 0) >= cost

                -- Check if locked
                local isLocked = false
                local lockReason = ""
                if skill.minAscension and ascensionCount < skill.minAscension then
                    isLocked = true
                    lockReason = "Req: Ascension " .. skill.minAscension
                elseif skill.requires then
                    for _, req in ipairs(skill.requires) do
                        local reqId, reqRank = req:match("([^:]+):?(%d*)")
                        reqRank = tonumber(reqRank) or 1
                        local hasRank = F.getAscensionSkillRank(reqId)
                        if hasRank < reqRank then
                            isLocked = true
                            lockReason = "Req: " .. reqId .. " Rank " .. reqRank
                            break
                        end
                    end
                end

                -- Background color
                local bgColor
                if isLocked then
                    bgColor = {0.15, 0.12, 0.12}
                elseif currentRank > 0 then
                    bgColor = {0.15, 0.2, 0.25}
                else
                    bgColor = {0.12, 0.1, 0.18}
                end

                if isSelected and not isLocked then
                    bgColor[1] = bgColor[1] + 0.1
                    bgColor[2] = bgColor[2] + 0.1
                    bgColor[3] = bgColor[3] + 0.1
                end

                love.graphics.setColor(bgColor)
                love.graphics.rectangle("fill", skillX, skillY, skillW, skillH, 6, 6)

                -- Border
                local borderColor
                if isSelected then
                    borderColor = {0.9, 0.7, 1}
                elseif isLocked then
                    borderColor = {0.3, 0.2, 0.2}
                elseif currentRank > 0 then
                    borderColor = {0.4, 0.6, 0.8}
                else
                    borderColor = {0.4, 0.3, 0.5}
                end
                love.graphics.setColor(borderColor)
                love.graphics.setLineWidth(isSelected and 2 or 1)
                love.graphics.rectangle("line", skillX, skillY, skillW, skillH, 6, 6)
                love.graphics.setLineWidth(1)

                if isLocked then
                    -- Locked skill display
                    love.graphics.setColor(0.4, 0.3, 0.3)
                    love.graphics.setFont(getFont(14))
                    love.graphics.print("LOCKED", skillX + 10, skillY + 8)
                    love.graphics.setColor(0.5, 0.4, 0.4)
                    love.graphics.setFont(getFont(11))
                    love.graphics.print(lockReason, skillX + 10, skillY + 28)
                else
                    -- Path A info (left side)
                    local pathAColor = (currentPath == nil or currentPath == "A") and {0.6, 0.9, 0.6} or {0.4, 0.4, 0.4}
                    love.graphics.setColor(pathAColor)
                    love.graphics.setFont(getFont(12))
                    love.graphics.print("[A] " .. skill.pathA.name, skillX + 8, skillY + 5)

                    love.graphics.setColor(0.6, 0.6, 0.6)
                    love.graphics.setFont(getFont(10))
                    local descA = skill.pathA.desc
                    if #descA > 35 then descA = descA:sub(1, 32) .. "..." end
                    love.graphics.print(descA, skillX + 8, skillY + 20)

                    -- Path B info (right side) - only if not already committed to A
                    local pathBColor = (currentPath == nil or currentPath == "B") and {0.6, 0.7, 0.9} or {0.4, 0.4, 0.4}
                    love.graphics.setColor(pathBColor)
                    love.graphics.setFont(getFont(12))
                    love.graphics.print("[B] " .. skill.pathB.name, skillX + 8, skillY + 33)

                    -- Rank and cost display
                    local rankText = "Rank " .. currentRank
                    if skill.maxRank then
                        rankText = rankText .. "/" .. skill.maxRank
                    end
                    local costColor = canAfford and {0.5, 0.8, 0.5} or {0.8, 0.4, 0.4}
                    love.graphics.setColor(costColor)
                    love.graphics.setFont(getFont(11))
                    love.graphics.printf(rankText .. " | Next: " .. cost .. " AP", skillX, skillY + skillH - 15, skillW - 8, "right")

                    -- Show current path indicator
                    if currentPath then
                        love.graphics.setColor(0.9, 0.8, 0.3)
                        love.graphics.setFont(getFont(10))
                        love.graphics.print("Path " .. currentPath, skillX + skillW - 50, skillY + 5)
                    end
                end

                col = col + 1
                if col >= 2 then
                    col = 0
                    drawY = drawY + skillH + skillMargin
                end
            end

            -- If odd number of skills, move to next row
            if col ~= 0 then
                drawY = drawY + skillH + skillMargin
            end

            drawY = drawY + 10  -- Extra space between tiers
        end
    end

    love.graphics.setScissor()

    -- Calculate max scroll
    local totalContentHeight = drawY - contentY + scrollOffset
    local maxScroll = math.max(0, totalContentHeight - contentH)
    state.maxAscensionScroll = maxScroll

    -- Scroll indicators
    if scrollOffset > 0 then
        love.graphics.setColor(0.7, 0.6, 0.9)
        love.graphics.setFont(getFont(14))
        love.graphics.printf("^ Scroll Up ^", panelX, contentY - 5, panelW, "center")
    end
    if scrollOffset < maxScroll then
        love.graphics.setColor(0.7, 0.6, 0.9)
        love.graphics.setFont(getFont(14))
        love.graphics.printf("v Scroll Down v", panelX, panelY + panelH - 55, panelW, "center")
    end

    -- Footer instructions
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.setFont(getFont(12))
    love.graphics.printf(
        "[Arrow Keys] Navigate  |  [A/B] Choose Path & Rank Up  |  [Scroll] Page Up/Down  |  [Escape] Close",
        panelX, panelY + panelH - 25, panelW, "center"
    )

    love.graphics.setColor(1, 1, 1)
end

-- ============================================================================
-- SPECIALIZATION SELECTION
-- ============================================================================

M.drawSpecializationSelection = function()
    local screenW, screenH = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()
    local p = state.player
    if not p then return end

    -- Full overlay - this is an important choice!
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Main panel
    local panelW = math.min(700, screenW - 40)
    local panelH = math.min(520, screenH - 40)
    local panelX = screenW/2 - panelW/2
    local panelY = screenH/2 - panelH/2

    -- Gradient-style background
    love.graphics.setColor(0.1, 0.08, 0.15)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 12, 12)

    -- Golden border for importance
    love.graphics.setColor(0.8, 0.6, 0.2)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 12, 12)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(1, 0.85, 0.3)
    love.graphics.setFont(getFont(26))
    love.graphics.printf("CHOOSE YOUR PATH", panelX, panelY + 20, panelW, "center")

    love.graphics.setColor(0.8, 0.7, 0.5)
    love.graphics.setFont(getFont(14))
    love.graphics.printf("Level 10 - " .. p.class.name .. " Specialization", panelX, panelY + 55, panelW, "center")

    -- Get specialization options
    local specs = getSpecializationOptions(p.class.id)
    if #specs == 0 then return end

    local y = panelY + 95
    local specH = 180
    local specW = (panelW - 80) / 2

    for i, spec in ipairs(specs) do
        local specX = panelX + 30 + (i - 1) * (specW + 20)
        local isSelected = state.selectedSpecIndex == i

        -- Card background
        local bgColor = {spec.color[1] * 0.3, spec.color[2] * 0.3, spec.color[3] * 0.3}
        if isSelected then
            bgColor = {spec.color[1] * 0.5, spec.color[2] * 0.5, spec.color[3] * 0.5}
        end
        love.graphics.setColor(bgColor)
        love.graphics.rectangle("fill", specX, y, specW, specH, 8, 8)

        -- Border
        local borderColor = isSelected and {1, 0.85, 0.3} or {spec.color[1], spec.color[2], spec.color[3]}
        love.graphics.setColor(borderColor)
        love.graphics.setLineWidth(isSelected and 3 or 2)
        love.graphics.rectangle("line", specX, y, specW, specH, 8, 8)
        love.graphics.setLineWidth(1)

        -- Class name
        love.graphics.setColor(spec.color)
        love.graphics.setFont(getFont(20))
        love.graphics.printf(spec.name, specX, y + 12, specW, "center")

        -- Description
        love.graphics.setColor(0.85, 0.85, 0.9)
        love.graphics.setFont(getFont(12))
        local _, descLines = love.graphics.getFont():getWrap(spec.desc, specW - 20)
        local descY = y + 42
        for _, line in ipairs(descLines) do
            love.graphics.printf(line, specX + 10, descY, specW - 20, "center")
            descY = descY + 14
        end

        -- Bonuses
        local bonusY = y + 85
        love.graphics.setColor(0.6, 0.8, 0.6)
        love.graphics.setFont(getFont(11))
        local bonusText = ""
        if spec.bonuses.attackMult then
            local pct = math.floor((spec.bonuses.attackMult - 1) * 100)
            bonusText = bonusText .. (pct >= 0 and "+" or "") .. pct .. "% ATK  "
        end
        if spec.bonuses.defenseMult then
            local pct = math.floor((spec.bonuses.defenseMult - 1) * 100)
            bonusText = bonusText .. (pct >= 0 and "+" or "") .. pct .. "% DEF  "
        end
        if spec.bonuses.critBonus then
            bonusText = bonusText .. "+" .. spec.bonuses.critBonus .. "% Crit  "
        end
        if spec.bonuses.dodgeBonus then
            bonusText = bonusText .. "+" .. spec.bonuses.dodgeBonus .. "% Dodge  "
        end
        love.graphics.printf(bonusText, specX, bonusY, specW, "center")

        -- Passives
        love.graphics.setColor(0.7, 0.7, 0.8)
        love.graphics.setFont(getFont(10))
        local passiveY = bonusY + 20
        for j, passive in ipairs(spec.passives or {}) do
            if j <= 2 then
                local shortPassive = passive:sub(1, 45) .. (passive:len() > 45 and "..." or "")
                love.graphics.printf(shortPassive, specX + 5, passiveY, specW - 10, "center")
                passiveY = passiveY + 14
            end
        end

        -- New skills
        love.graphics.setColor(0.9, 0.8, 0.5)
        love.graphics.setFont(getFont(11))
        local skillsText = "New Skills: " .. table.concat(spec.newSkills or {}, ", ")
        love.graphics.printf(skillsText, specX, y + specH - 25, specW, "center")
    end

    -- Warning text
    love.graphics.setColor(0.9, 0.6, 0.3)
    love.graphics.setFont(getFont(13))
    love.graphics.printf("This choice is permanent and will shape your character's abilities!", panelX, panelY + panelH - 70, panelW, "center")

    -- Footer
    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("[Left/Right] Select  |  [Enter] Confirm Choice", panelX, panelY + panelH - 30, panelW, "center")

    love.graphics.setColor(1, 1, 1)
end

-- ============================================================================
-- CHARACTER CREATION DRAWS
-- ============================================================================

-- Main character creation dispatcher
M.drawClassSelect = function(x, y, w, h, mx, my)
    local cc = state.characterCreation

    -- Progress indicator at top
    love.graphics.setColor(0.3, 0.3, 0.4)
    love.graphics.setFont(getFont(11))
    local stepNames = {"Race", "Class", "Background", "Gender", "Portrait & Name", "Review"}
    local displayStep = cc.step
    local displayTotal = 6
    if cc.step == "stat_alloc" then
        displayStep = 1
        love.graphics.printf("Step 1/6: Race - Stat Allocation", x, y + 5, w, "center")
    else
        local stepText = "Step " .. displayStep .. "/" .. displayTotal .. ": " .. (stepNames[displayStep] or "")
        love.graphics.printf(stepText, x, y + 5, w, "center")
    end

    -- Draw appropriate step
    if cc.step == 1 then
        M.drawRaceSelection(x, y + 30, w, h - 30, mx, my)
    elseif cc.step == "stat_alloc" then
        M.drawStatAllocation(x, y + 30, w, h - 30, mx, my)
    elseif cc.step == 2 then
        M.drawClassSelection(x, y + 30, w, h - 30, mx, my)
    elseif cc.step == 3 then
        M.drawBackgroundSelection(x, y + 30, w, h - 30, mx, my)
    elseif cc.step == 4 then
        M.drawGenderSelection(x, y + 30, w, h - 30, mx, my)
    elseif cc.step == 5 then
        M.drawPortraitAndName(x, y + 30, w, h - 30, mx, my)
    elseif cc.step == 6 then
        M.drawCharacterReview(x, y + 30, w, h - 30, mx, my)
    end
end

-- Step 1: Race Selection (Carousel Style)
M.drawRaceSelection = function(x, y, w, h, mx, my)
    -- Check for newly unlocked races
    F.checkAllRaceUnlocks()

    -- Build combined race list (standard + unlocked)
    local allRaces = {}
    for _, race in ipairs(Data.RACES) do
        table.insert(allRaces, race)
    end
    for _, race in ipairs(Data.UNLOCKABLE_RACES) do
        if F.isRaceUnlocked(race.id) then
            table.insert(allRaces, race)
        end
    end

    -- Initialize carousel index
    state.characterCreation.raceIndex = state.characterCreation.raceIndex or 1
    if state.characterCreation.raceIndex > #allRaces then
        state.characterCreation.raceIndex = 1
    end

    local currentRace = allRaces[state.characterCreation.raceIndex]

    -- Title
    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(32))
    love.graphics.printf("Choose Your Race", x, y, w, "center")

    -- Race counter
    love.graphics.setFont(getFont(16))
    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.printf(state.characterCreation.raceIndex .. " / " .. #allRaces, x, y + 45, w, "center")

    -- Main card in center
    local cardW = 600
    local cardH = 450
    local cardX = x + (w - cardW) / 2
    local cardY = y + 80

    -- Card background
    love.graphics.setColor(0.12, 0.12, 0.18, 0.95)
    love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 12, 12)

    -- Border with race color
    love.graphics.setColor(currentRace.color)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", cardX, cardY, cardW, cardH, 12, 12)
    love.graphics.setLineWidth(1)

    -- Portrait area (left side)
    local portraitX = cardX + 20
    local portraitY = cardY + 20
    local portraitW = 250
    local portraitH = 410

    love.graphics.setColor(0.08, 0.08, 0.12)
    love.graphics.rectangle("fill", portraitX, portraitY, portraitW, portraitH, 8, 8)
    love.graphics.setColor(currentRace.color[1] * 0.5, currentRace.color[2] * 0.5, currentRace.color[3] * 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", portraitX, portraitY, portraitW, portraitH, 8, 8)
    love.graphics.setLineWidth(1)

    -- Portrait image (if available)
    local racePortrait = getPortraitImage(currentRace.id)
    if racePortrait then
        love.graphics.setColor(1, 1, 1)
        local imgW, imgH = racePortrait:getDimensions()
        local scale = math.min(portraitW / imgW, portraitH / imgH) * 0.9
        local imgX = portraitX + (portraitW - imgW * scale) / 2
        local imgY = portraitY + (portraitH - imgH * scale) / 2
        love.graphics.draw(racePortrait, imgX, imgY, 0, scale, scale)
    else
        -- Placeholder
        love.graphics.setColor(currentRace.color[1] * 0.3, currentRace.color[2] * 0.3, currentRace.color[3] * 0.3)
        love.graphics.setFont(getFont(80))
        love.graphics.printf("?", portraitX, portraitY + portraitH / 2 - 40, portraitW, "center")
    end

    -- Info area (right side)
    local infoX = portraitX + portraitW + 20
    local infoY = cardY + 20
    local infoW = cardW - portraitW - 60

    -- Race name (large)
    love.graphics.setFont(getFont(36))
    love.graphics.setColor(currentRace.color)
    love.graphics.printf(currentRace.name, infoX, infoY, infoW, "center")

    -- Description
    love.graphics.setFont(getFont(14))
    love.graphics.setColor(0.9, 0.9, 1)
    love.graphics.printf(currentRace.desc, infoX, infoY + 50, infoW, "center")

    -- Stat mods
    love.graphics.setFont(getFont(16))
    love.graphics.setColor(0.7, 1, 0.7)
    local statY = infoY + 110
    love.graphics.print("Stats:", infoX, statY)
    statY = statY + 25

    love.graphics.setFont(getFont(14))
    for stat, bonus in pairs(currentRace.statMods) do
        if stat ~= "choice1" and stat ~= "choice2" then
            love.graphics.setColor(0.8, 0.95, 0.8)
            love.graphics.print("  +" .. bonus .. " " .. stat, infoX + 10, statY)
            statY = statY + 22
        end
    end
    if currentRace.statMods.choice1 then
        love.graphics.setColor(0.8, 0.95, 0.8)
        love.graphics.printf("Choose +1 to any 2 stats", infoX, statY, infoW, "left")
        statY = statY + 22
    end

    -- Racial bonuses
    love.graphics.setFont(getFont(16))
    love.graphics.setColor(0.95, 0.85, 0.6)
    statY = statY + 15
    love.graphics.print("Racial Traits:", infoX, statY)
    statY = statY + 25

    love.graphics.setFont(getFont(13))
    for i, bonus in ipairs(currentRace.bonuses) do
        love.graphics.setColor(0.95, 0.85, 0.6)
        love.graphics.print("• " .. bonus.name, infoX + 10, statY)
        statY = statY + 20
        love.graphics.setFont(getFont(11))
        love.graphics.setColor(0.75, 0.75, 0.85)
        love.graphics.printf(bonus.desc, infoX + 20, statY, infoW - 20, "left")
        statY = statY + 35
        love.graphics.setFont(getFont(13))
    end

    -- LEFT ARROW
    local arrowSize = 60
    local leftArrowX = cardX - arrowSize - 30
    local leftArrowY = cardY + cardH / 2 - arrowSize / 2
    local leftHover = mx >= leftArrowX and mx <= leftArrowX + arrowSize and
                      my >= leftArrowY and my <= leftArrowY + arrowSize

    love.graphics.setColor(leftHover and {0.4, 0.4, 0.6} or {0.2, 0.2, 0.3})
    love.graphics.rectangle("fill", leftArrowX, leftArrowY, arrowSize, arrowSize, 8, 8)
    love.graphics.setColor(leftHover and {0.9, 0.9, 1} or {0.6, 0.6, 0.7})
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", leftArrowX, leftArrowY, arrowSize, arrowSize, 8, 8)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(getFont(40))
    love.graphics.printf("<", leftArrowX, leftArrowY + 8, arrowSize, "center")

    -- Store bounds for clicking
    state.characterCreation.leftArrowBounds = {x = leftArrowX, y = leftArrowY, w = arrowSize, h = arrowSize}

    -- RIGHT ARROW
    local rightArrowX = cardX + cardW + 30
    local rightArrowY = cardY + cardH / 2 - arrowSize / 2
    local rightHover = mx >= rightArrowX and mx <= rightArrowX + arrowSize and
                       my >= rightArrowY and my <= rightArrowY + arrowSize

    love.graphics.setColor(rightHover and {0.4, 0.4, 0.6} or {0.2, 0.2, 0.3})
    love.graphics.rectangle("fill", rightArrowX, rightArrowY, arrowSize, arrowSize, 8, 8)
    love.graphics.setColor(rightHover and {0.9, 0.9, 1} or {0.6, 0.6, 0.7})
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", rightArrowX, rightArrowY, arrowSize, arrowSize, 8, 8)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(getFont(40))
    love.graphics.printf(">", rightArrowX, rightArrowY + 8, arrowSize, "center")

    -- Store bounds for clicking
    state.characterCreation.rightArrowBounds = {x = rightArrowX, y = rightArrowY, w = arrowSize, h = arrowSize}

    -- SELECT button (centered below card)
    local btnW, btnH = 200, 50
    local btnX = cardX + (cardW - btnW) / 2
    local btnY = cardY + cardH + 20
    local btnHover = mx >= btnX and mx <= btnX + btnW and my >= btnY and my <= btnY + btnH

    love.graphics.setColor(btnHover and {0.3, 0.7, 0.3} or {0.2, 0.5, 0.2})
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH, 8, 8)
    love.graphics.setColor(0.9, 1, 0.9)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", btnX, btnY, btnW, btnH, 8, 8)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(getFont(20))

    local btnText = (state.characterCreation.selectedRace == currentRace.id) and "SELECTED \226\156\147" or "SELECT RACE"
    love.graphics.printf(btnText, btnX, btnY + 12, btnW, "center")

    -- Store select button bounds
    state.characterCreation.raceSelectBounds = {x = btnX, y = btnY, w = btnW, h = btnH}
end

-- Stat Allocation step (for races with choice stats like Human)
M.drawStatAllocation = function(x, y, w, h, mx, my)
    local cc = state.characterCreation
    local allStats = {"MIGHT", "VIGOR", "AGILITY", "MIND", "SPIRIT", "PRESENCE", "FAITH"}
    local statDescs = {
        MIGHT = "Physical power, melee damage",
        VIGOR = "Health, endurance, stamina",
        AGILITY = "Speed, dodge, ranged accuracy",
        MIND = "Magic power, mana pool",
        SPIRIT = "Resistance, willpower, mana regen",
        PRESENCE = "Charisma, persuasion, prices",
        FAITH = "Divine power, healing strength",
    }

    cc.chosenBonusStats = cc.chosenBonusStats or {}
    cc.statAllocBounds = cc.statAllocBounds or {}

    -- Get race info
    local raceName = "Human"
    for _, race in ipairs(Data.RACES) do
        if race.id == cc.selectedRace then raceName = race.name break end
    end
    for _, race in ipairs(Data.UNLOCKABLE_RACES) do
        if race.id == cc.selectedRace then raceName = race.name break end
    end

    -- Title
    love.graphics.setFont(getFont(22))
    love.graphics.setColor(0.9, 0.85, 0.6)
    love.graphics.printf(raceName .. " - Stat Allocation", x, y + 10, w, "center")

    -- Subtitle
    love.graphics.setFont(getFont(13))
    love.graphics.setColor(0.7, 0.8, 0.7)
    love.graphics.printf("Choose 2 stats to receive +1 bonus", x, y + 42, w, "center")

    local selectedCount = #cc.chosenBonusStats
    love.graphics.setColor(0.5, 0.6, 0.7)
    love.graphics.printf(selectedCount .. "/2 selected", x, y + 60, w, "center")

    -- Draw stat buttons in a centered grid
    local gridW = 280
    local gridX = x + (w - gridW) / 2
    local gridY = y + 90
    local btnH = 44
    local spacing = 6

    cc.statAllocBounds = {}

    for i, stat in ipairs(allStats) do
        local by = gridY + (i - 1) * (btnH + spacing)
        local isSelected = false
        for _, s in ipairs(cc.chosenBonusStats) do
            if s == stat then isSelected = true break end
        end

        local isHovered = mx >= gridX and mx <= gridX + gridW and my >= by and my <= by + btnH

        -- Background
        if isSelected then
            love.graphics.setColor(0.2, 0.45, 0.3, 0.95)
        elseif isHovered and selectedCount < 2 then
            love.graphics.setColor(0.2, 0.25, 0.35, 0.9)
        else
            love.graphics.setColor(0.12, 0.14, 0.2, 0.9)
        end
        love.graphics.rectangle("fill", gridX, by, gridW, btnH, 6, 6)

        -- Border
        if isSelected then
            love.graphics.setColor(0.3, 0.9, 0.4)
        else
            love.graphics.setColor(0.3, 0.35, 0.45)
        end
        love.graphics.rectangle("line", gridX, by, gridW, btnH, 6, 6)

        -- Stat name
        love.graphics.setFont(getFont(14))
        if isSelected then
            love.graphics.setColor(0.4, 1.0, 0.5)
        else
            love.graphics.setColor(0.85, 0.85, 0.85)
        end
        love.graphics.print(stat, gridX + 12, by + 5)

        -- +1 indicator
        if isSelected then
            love.graphics.setColor(0.3, 1.0, 0.4)
            love.graphics.printf("+1", gridX, by + 5, gridW - 12, "right")
        end

        -- Description
        love.graphics.setFont(getFont(10))
        love.graphics.setColor(0.55, 0.6, 0.7)
        love.graphics.print(statDescs[stat] or "", gridX + 12, by + 25)

        cc.statAllocBounds[i] = {x = gridX, y = by, w = gridW, h = btnH, stat = stat}
    end

    -- BACK button
    local backW, backH = 120, 40
    local backX = x + w / 2 - backW - 10
    local backY = gridY + #allStats * (btnH + spacing) + 15
    local backHover = mx >= backX and mx <= backX + backW and my >= backY and my <= backY + backH
    love.graphics.setColor(backHover and {0.4, 0.3, 0.3} or {0.25, 0.2, 0.2})
    love.graphics.rectangle("fill", backX, backY, backW, backH, 8, 8)
    love.graphics.setColor(0.6, 0.5, 0.5)
    love.graphics.rectangle("line", backX, backY, backW, backH, 8, 8)
    love.graphics.setFont(getFont(14))
    love.graphics.setColor(0.9, 0.8, 0.8)
    love.graphics.printf("BACK", backX, backY + 11, backW, "center")
    cc.statAllocBackBounds = {x = backX, y = backY, w = backW, h = backH}

    -- CONFIRM button (only active when 2 stats selected)
    local confW, confH = 120, 40
    local confX = x + w / 2 + 10
    local confY = backY
    local canConfirm = selectedCount == 2
    local confHover = canConfirm and mx >= confX and mx <= confX + confW and my >= confY and my <= confY + confH
    if canConfirm then
        love.graphics.setColor(confHover and {0.2, 0.5, 0.3} or {0.15, 0.35, 0.2})
    else
        love.graphics.setColor(0.15, 0.15, 0.18)
    end
    love.graphics.rectangle("fill", confX, confY, confW, confH, 8, 8)
    love.graphics.setColor(canConfirm and {0.3, 0.8, 0.4} or {0.3, 0.3, 0.35})
    love.graphics.rectangle("line", confX, confY, confW, confH, 8, 8)
    love.graphics.setFont(getFont(14))
    love.graphics.setColor(canConfirm and {0.5, 1.0, 0.6} or {0.4, 0.4, 0.45})
    love.graphics.printf("CONFIRM", confX, confY + 11, confW, "center")
    cc.statAllocConfirmBounds = {x = confX, y = confY, w = confW, h = confH}
end

-- Step 2: Class Selection (Carousel Style)
M.drawClassSelection = function(x, y, w, h, mx, my)
    -- All 6 universal classes are available to every race
    local availableClasses = Data.CLASSES

    -- Initialize carousel index
    state.characterCreation.classIndex = state.characterCreation.classIndex or 1
    if state.characterCreation.classIndex > #availableClasses then
        state.characterCreation.classIndex = 1
    end

    local currentClass = availableClasses[state.characterCreation.classIndex]

    -- Title
    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(32))
    love.graphics.printf("Choose Your Class", x, y, w, "center")

    -- Class counter
    love.graphics.setFont(getFont(16))
    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.printf(state.characterCreation.classIndex .. " / " .. #availableClasses, x, y + 45, w, "center")

    -- Main card
    local cardW = 600
    local cardH = 450
    local cardX = x + (w - cardW) / 2
    local cardY = y + 80

    love.graphics.setColor(0.12, 0.12, 0.18, 0.95)
    love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 12, 12)
    love.graphics.setColor(currentClass.color)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", cardX, cardY, cardW, cardH, 12, 12)
    love.graphics.setLineWidth(1)

    -- Portrait area
    local portraitX = cardX + 20
    local portraitY = cardY + 20
    local portraitW = 250
    local portraitH = 410

    love.graphics.setColor(0.08, 0.08, 0.12)
    love.graphics.rectangle("fill", portraitX, portraitY, portraitW, portraitH, 8, 8)
    love.graphics.setColor(currentClass.color[1] * 0.5, currentClass.color[2] * 0.5, currentClass.color[3] * 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", portraitX, portraitY, portraitW, portraitH, 8, 8)
    love.graphics.setLineWidth(1)

    local classPortrait = getPortraitImage(currentClass.id)
    if classPortrait then
        love.graphics.setColor(1, 1, 1)
        local imgW, imgH = classPortrait:getDimensions()
        local scale = math.min(portraitW / imgW, portraitH / imgH) * 0.9
        local imgX = portraitX + (portraitW - imgW * scale) / 2
        local imgY = portraitY + (portraitH - imgH * scale) / 2
        love.graphics.draw(classPortrait, imgX, imgY, 0, scale, scale)
    else
        love.graphics.setColor(currentClass.color[1] * 0.3, currentClass.color[2] * 0.3, currentClass.color[3] * 0.3)
        love.graphics.setFont(getFont(80))
        love.graphics.printf("?", portraitX, portraitY + portraitH / 2 - 40, portraitW, "center")
    end

    -- Info area
    local infoX = portraitX + portraitW + 20
    local infoY = cardY + 20
    local infoW = cardW - portraitW - 60

    love.graphics.setFont(getFont(36))
    love.graphics.setColor(currentClass.color)
    love.graphics.printf(currentClass.name, infoX, infoY, infoW, "center")

    love.graphics.setFont(getFont(13))
    love.graphics.setColor(0.9, 0.9, 1)
    love.graphics.printf(currentClass.desc, infoX, infoY + 50, infoW, "center")

    -- Stats
    love.graphics.setFont(getFont(18))
    local statY = infoY + 140
    love.graphics.setColor(0.9, 0.5, 0.5)
    love.graphics.print("HP: " .. currentClass.baseHP, infoX, statY)
    love.graphics.setColor(0.95, 0.7, 0.4)
    love.graphics.print("ATK: " .. currentClass.baseAtk, infoX, statY + 30)
    love.graphics.setColor(0.5, 0.8, 0.95)
    love.graphics.print("DEF: " .. currentClass.baseDef, infoX + 150, statY)
    love.graphics.setColor(0.7, 0.5, 0.95)
    love.graphics.print("MP: " .. currentClass.baseMana, infoX + 150, statY + 30)

    -- Skills
    love.graphics.setFont(getFont(16))
    love.graphics.setColor(0.8, 0.95, 0.8)
    statY = statY + 75
    love.graphics.print("Skills:", infoX, statY)
    statY = statY + 25

    love.graphics.setFont(getFont(13))
    if currentClass.skills and #currentClass.skills > 0 then
        for i, skill in ipairs(currentClass.skills) do
            if i <= 5 then
                love.graphics.setColor(0.75, 0.85, 0.75)
                love.graphics.print("\226\128\162 " .. skill, infoX + 10, statY)
                statY = statY + 22
            end
        end
    end

    -- Arrows
    local arrowSize = 60
    local leftArrowX = cardX - arrowSize - 30
    local leftArrowY = cardY + cardH / 2 - arrowSize / 2
    local leftHover = mx >= leftArrowX and mx <= leftArrowX + arrowSize and
                      my >= leftArrowY and my <= leftArrowY + arrowSize

    love.graphics.setColor(leftHover and {0.4, 0.4, 0.6} or {0.2, 0.2, 0.3})
    love.graphics.rectangle("fill", leftArrowX, leftArrowY, arrowSize, arrowSize, 8, 8)
    love.graphics.setColor(leftHover and {0.9, 0.9, 1} or {0.6, 0.6, 0.7})
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", leftArrowX, leftArrowY, arrowSize, arrowSize, 8, 8)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(getFont(40))
    love.graphics.printf("<", leftArrowX, leftArrowY + 8, arrowSize, "center")

    state.characterCreation.leftArrowBoundsClass = {x = leftArrowX, y = leftArrowY, w = arrowSize, h = arrowSize}

    local rightArrowX = cardX + cardW + 30
    local rightArrowY = cardY + cardH / 2 - arrowSize / 2
    local rightHover = mx >= rightArrowX and mx <= rightArrowX + arrowSize and
                       my >= rightArrowY and my <= rightArrowY + arrowSize

    love.graphics.setColor(rightHover and {0.4, 0.4, 0.6} or {0.2, 0.2, 0.3})
    love.graphics.rectangle("fill", rightArrowX, rightArrowY, arrowSize, arrowSize, 8, 8)
    love.graphics.setColor(rightHover and {0.9, 0.9, 1} or {0.6, 0.6, 0.7})
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", rightArrowX, rightArrowY, arrowSize, arrowSize, 8, 8)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(getFont(40))
    love.graphics.printf(">", rightArrowX, rightArrowY + 8, arrowSize, "center")

    state.characterCreation.rightArrowBoundsClass = {x = rightArrowX, y = rightArrowY, w = arrowSize, h = arrowSize}

    -- Buttons
    local btnW, btnH = 150, 50
    local backX = cardX + 50
    local selectX = cardX + cardW - btnW - 50
    local btnY = cardY + cardH + 20

    local backHover = mx >= backX and mx <= backX + btnW and my >= btnY and my <= btnY + btnH
    love.graphics.setColor(backHover and {0.6, 0.3, 0.3} or {0.4, 0.2, 0.2})
    love.graphics.rectangle("fill", backX, btnY, btnW, btnH, 8, 8)
    love.graphics.setColor(1, 0.8, 0.8)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", backX, btnY, btnW, btnH, 8, 8)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(getFont(20))
    love.graphics.printf("BACK", backX, btnY + 12, btnW, "center")
    state.characterCreation.backButtonBounds = {x = backX, y = btnY, w = btnW, h = btnH}

    local selectHover = mx >= selectX and mx <= selectX + btnW and my >= btnY and my <= btnY + btnH
    love.graphics.setColor(selectHover and {0.3, 0.7, 0.3} or {0.2, 0.5, 0.2})
    love.graphics.rectangle("fill", selectX, btnY, btnW, btnH, 8, 8)
    love.graphics.setColor(0.9, 1, 0.9)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", selectX, btnY, btnW, btnH, 8, 8)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(getFont(20))
    local btnText = (state.characterCreation.selectedClass == currentClass.id) and "SELECTED \226\156\147" or "SELECT"
    love.graphics.printf(btnText, selectX, btnY + 12, btnW, "center")
    state.characterCreation.classSelectBounds = {x = selectX, y = btnY, w = btnW, h = btnH}

    -- Store available classes for click handler
    state.characterCreation.availableClasses = availableClasses
end

-- Step 3: Background Selection (Carousel Style)
M.drawBackgroundSelection = function(x, y, w, h, mx, my)
    -- Initialize carousel index
    state.characterCreation.backgroundIndex = state.characterCreation.backgroundIndex or 1
    if state.characterCreation.backgroundIndex > #Data.BACKGROUNDS then
        state.characterCreation.backgroundIndex = 1
    end

    local currentBg = Data.BACKGROUNDS[state.characterCreation.backgroundIndex]

    -- Title
    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(32))
    love.graphics.printf("Choose Your Background", x, y, w, "center")

    -- Counter
    love.graphics.setFont(getFont(16))
    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.printf(state.characterCreation.backgroundIndex .. " / " .. #Data.BACKGROUNDS, x, y + 45, w, "center")

    -- Main card
    local cardW = 700
    local cardH = 480
    local cardX = x + (w - cardW) / 2
    local cardY = y + 90

    -- Background-specific colors (7 consolidated backgrounds)
    local bgColors = {
        vampire_hunter = {0.9, 0.3, 0.3},
        tavern_brawler = {0.8, 0.4, 0.3},
        card_shark = {0.4, 0.8, 0.4},
        snake_oil_peddler = {0.5, 0.9, 0.7},
        corruption_survivor = {0.6, 0.4, 0.7},
        dungeon_delver = {0.6, 0.6, 0.8},
        cafe_veteran = {0.5, 0.3, 0.4},
    }
    local themeColor = bgColors[currentBg.id] or {0.7, 0.7, 0.8}

    -- Card background
    love.graphics.setColor(0.12, 0.12, 0.18, 0.95)
    love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 12, 12)
    love.graphics.setColor(themeColor)
    love.graphics.setLineWidth(4)
    love.graphics.rectangle("line", cardX, cardY, cardW, cardH, 12, 12)
    love.graphics.setLineWidth(1)

    -- Content area
    local contentX = cardX + 30
    local contentY = cardY + 30
    local contentW = cardW - 60

    -- Background name
    love.graphics.setFont(getFont(40))
    love.graphics.setColor(themeColor)
    love.graphics.printf(currentBg.name, contentX, contentY, contentW, "center")

    -- Description
    love.graphics.setFont(getFont(16))
    love.graphics.setColor(0.9, 0.9, 1)
    love.graphics.printf(currentBg.desc, contentX, contentY + 55, contentW, "center")

    -- Starting gold
    love.graphics.setFont(getFont(22))
    local goldY = contentY + 145
    if currentBg.startingGold and currentBg.startingGold ~= 0 then
        if currentBg.startingGold < 0 then
            love.graphics.setColor(1, 0.4, 0.4)
            love.graphics.printf("Starting Debt: " .. math.abs(currentBg.startingGold) .. " gold", contentX, goldY, contentW, "center")
        else
            love.graphics.setColor(0.95, 0.95, 0.4)
            love.graphics.printf("Starting Gold: +" .. currentBg.startingGold .. " gold", contentX, goldY, contentW, "center")
        end
    else
        love.graphics.setColor(0.7, 0.7, 0.8)
        love.graphics.printf("Starting Gold: Normal", contentX, goldY, contentW, "center")
    end

    -- Stat modifiers (if any)
    love.graphics.setFont(getFont(16))
    love.graphics.setColor(0.8, 0.95, 0.8)
    local statY = goldY + 40
    if currentBg.statMods and next(currentBg.statMods) then
        love.graphics.print("Stat Bonuses:", contentX + 20, statY)
        statY = statY + 25
        love.graphics.setFont(getFont(14))
        for stat, bonus in pairs(currentBg.statMods) do
            love.graphics.print("  +" .. bonus .. " " .. stat, contentX + 30, statY)
            statY = statY + 22
        end
    end

    -- Passive abilities
    if currentBg.passives and #currentBg.passives > 0 then
        statY = statY + 10
        love.graphics.setFont(getFont(16))
        love.graphics.setColor(0.9, 0.7, 0.5)
        love.graphics.print("Passives:", contentX + 20, statY)
        statY = statY + 22
        love.graphics.setFont(getFont(13))
        love.graphics.setColor(0.85, 0.85, 0.95)
        for _, pid in ipairs(currentBg.passives) do
            local desc = Data.PASSIVE_DESCRIPTIONS[pid] or pid
            love.graphics.print("  * " .. desc, contentX + 30, statY)
            statY = statY + 18
        end
    end

    -- Tags
    love.graphics.setFont(getFont(14))
    love.graphics.setColor(0.7, 0.75, 0.85)
    local tagY = contentY + cardH - 60
    if currentBg.tags then
        love.graphics.printf(table.concat(currentBg.tags, " \226\128\162 "), contentX, tagY, contentW, "center")
    end

    -- Arrows
    local arrowSize = 60
    local leftArrowX = cardX - arrowSize - 30
    local leftArrowY = cardY + cardH / 2 - arrowSize / 2
    local leftHover = mx >= leftArrowX and mx <= leftArrowX + arrowSize and
                      my >= leftArrowY and my <= leftArrowY + arrowSize

    love.graphics.setColor(leftHover and {0.4, 0.4, 0.6} or {0.2, 0.2, 0.3})
    love.graphics.rectangle("fill", leftArrowX, leftArrowY, arrowSize, arrowSize, 8, 8)
    love.graphics.setColor(leftHover and {0.9, 0.9, 1} or {0.6, 0.6, 0.7})
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", leftArrowX, leftArrowY, arrowSize, arrowSize, 8, 8)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(getFont(40))
    love.graphics.printf("<", leftArrowX, leftArrowY + 8, arrowSize, "center")

    state.characterCreation.leftArrowBoundsBackground = {x = leftArrowX, y = leftArrowY, w = arrowSize, h = arrowSize}

    local rightArrowX = cardX + cardW + 30
    local rightArrowY = cardY + cardH / 2 - arrowSize / 2
    local rightHover = mx >= rightArrowX and mx <= rightArrowX + arrowSize and
                       my >= rightArrowY and my <= rightArrowY + arrowSize

    love.graphics.setColor(rightHover and {0.4, 0.4, 0.6} or {0.2, 0.2, 0.3})
    love.graphics.rectangle("fill", rightArrowX, rightArrowY, arrowSize, arrowSize, 8, 8)
    love.graphics.setColor(rightHover and {0.9, 0.9, 1} or {0.6, 0.6, 0.7})
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", rightArrowX, rightArrowY, arrowSize, arrowSize, 8, 8)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(getFont(40))
    love.graphics.printf(">", rightArrowX, rightArrowY + 8, arrowSize, "center")

    state.characterCreation.rightArrowBoundsBackground = {x = rightArrowX, y = rightArrowY, w = arrowSize, h = arrowSize}

    -- Buttons
    local btnW, btnH = 150, 50
    local backX = cardX + 50
    local selectX = cardX + cardW - btnW - 50
    local btnY = cardY + cardH + 20

    local backHover = mx >= backX and mx <= backX + btnW and my >= btnY and my <= btnY + btnH
    love.graphics.setColor(backHover and {0.6, 0.3, 0.3} or {0.4, 0.2, 0.2})
    love.graphics.rectangle("fill", backX, btnY, btnW, btnH, 8, 8)
    love.graphics.setColor(1, 0.8, 0.8)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", backX, btnY, btnW, btnH, 8, 8)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(getFont(20))
    love.graphics.printf("BACK", backX, btnY + 12, btnW, "center")
    state.characterCreation.backgroundBackBounds = {x = backX, y = btnY, w = btnW, h = btnH}

    local selectHover = mx >= selectX and mx <= selectX + btnW and my >= btnY and my <= btnY + btnH
    love.graphics.setColor(selectHover and {0.3, 0.7, 0.3} or {0.2, 0.5, 0.2})
    love.graphics.rectangle("fill", selectX, btnY, btnW, btnH, 8, 8)
    love.graphics.setColor(0.9, 1, 0.9)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", selectX, btnY, btnW, btnH, 8, 8)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(getFont(20))
    local btnText = (state.characterCreation.selectedBackground == currentBg.id) and "SELECTED \226\156\147" or "SELECT"
    love.graphics.printf(btnText, selectX, btnY + 12, btnW, "center")
    state.characterCreation.backgroundSelectBounds = {x = selectX, y = btnY, w = btnW, h = btnH}
end

-- Step 4: Gender Selection
M.drawGenderSelection = function(x, y, w, h, mx, my)
    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(28))
    love.graphics.printf("Choose Your Gender", x, y, w, "center")

    local genders = {"Male", "Female"}  -- Removed "Other"
    local cardW = 220
    local cardH = 120
    local spacing = 60
    local startX = x + (w - (#genders * cardW + (#genders - 1) * spacing)) / 2

    for i, gender in ipairs(genders) do
        local cx = startX + (i - 1) * (cardW + spacing)
        local cy = y + 120
        local hover = mx >= cx and mx <= cx + cardW and my >= cy and my <= cy + cardH
        local selected = state.characterCreation.selectedGender == gender

        -- Pulsing glow for selected
        local pulseTime = love.timer.getTime() * 2
        local pulse = (math.sin(pulseTime) + 1) / 2
        local glowAlpha = selected and (0.3 + pulse * 0.3) or 0

        -- Outer glow
        if selected or hover then
            local glowColor = gender == "Male" and {0.4, 0.6, 1} or {1, 0.5, 0.7}
            love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], glowAlpha + (hover and 0.2 or 0))
            love.graphics.rectangle("fill", cx - 4, cy - 4, cardW + 8, cardH + 8, 10, 10)
        end

        -- Card background with gender-specific colors
        if selected then
            local selColor = gender == "Male" and {0.3, 0.4, 0.55} or {0.5, 0.3, 0.45}
            love.graphics.setColor(selColor)
        else
            local bgColor = gender == "Male" and {0.18, 0.22, 0.3} or {0.3, 0.18, 0.25}
            love.graphics.setColor(hover and {bgColor[1] * 1.3, bgColor[2] * 1.3, bgColor[3] * 1.3} or bgColor)
        end
        love.graphics.rectangle("fill", cx, cy, cardW, cardH, 8, 8)

        -- Border
        local borderColor = gender == "Male" and {0.5, 0.7, 1} or {1, 0.6, 0.8}
        love.graphics.setColor(selected and borderColor or {borderColor[1] * 0.7, borderColor[2] * 0.7, borderColor[3] * 0.7})
        love.graphics.setLineWidth(selected and 4 or (hover and 3 or 2))
        love.graphics.rectangle("line", cx, cy, cardW, cardH, 8, 8)
        love.graphics.setLineWidth(1)

        -- Gender name (LARGER FONT - was 18, now 24)
        love.graphics.setFont(getFont(24))
        love.graphics.setColor(selected and {1, 1, 1} or {0.9, 0.9, 0.95})
        love.graphics.printf(gender, cx, cy + 42, cardW, "center")
    end

    -- Back and Next buttons
    local btnW, btnH = 100, 40
    local backX, backY = x + 20, y + h - btnH - 10
    local backHover = mx >= backX and mx <= backX + btnW and my >= backY and my <= backY + btnH
    love.graphics.setColor(backHover and {0.6, 0.3, 0.3} or {0.4, 0.2, 0.2})
    love.graphics.rectangle("fill", backX, backY, btnW, btnH, 6, 6)
    love.graphics.setColor(1, 0.8, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", backX, backY, btnW, btnH, 6, 6)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(getFont(14))
    love.graphics.printf("Back", backX, backY + 12, btnW, "center")

    local nextX = x + w - btnW - 20
    local nextY = y + h - btnH - 10
    local nextHover = mx >= nextX and mx <= nextX + btnW and my >= nextY and my <= nextY + btnH
    love.graphics.setColor(nextHover and {0.3, 0.7, 0.3} or {0.2, 0.5, 0.2})
    love.graphics.rectangle("fill", nextX, nextY, btnW, btnH, 6, 6)
    love.graphics.setColor(0.9, 1, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", nextX, nextY, btnW, btnH, 6, 6)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(getFont(14))
    love.graphics.printf("Next", nextX, nextY + 12, btnW, "center")
end

-- Step 5: Portrait and Name
M.drawPortraitAndName = function(x, y, w, h, mx, my)
    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(20))
    love.graphics.printf("Portrait & Name", x, y, w, "center")

    -- Name input field
    local inputW = 300
    local inputH = 40
    local inputX = x + (w - inputW) / 2
    local inputY = y + 50

    love.graphics.setColor(0.1, 0.12, 0.15)
    love.graphics.rectangle("fill", inputX, inputY, inputW, inputH, 6, 6)
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", inputX, inputY, inputW, inputH, 6, 6)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(0.7, 0.7, 0.8)
    love.graphics.setFont(getFont(11))
    love.graphics.print("Character Name:", inputX, inputY - 20)

    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(16))
    local displayName = state.playerNameInput or "Adventurer"
    local cursorBlink = math.floor(love.timer.getTime() * 2) % 2 == 0
    local textWithCursor = displayName .. (cursorBlink and "|" or "")
    love.graphics.printf(textWithCursor, inputX + 10, inputY + 10, inputW - 20, "center")

    -- Portrait preview
    local portraitSize = 120
    local portraitX = x + (w - portraitSize) / 2
    local portraitY = y + 120

    -- Get portrait based on selected class, gender, and portrait index
    local classId = state.characterCreation.selectedClass or "warrior"
    local gender = state.characterCreation.selectedGender or "Male"
    local portraitIndex = state.characterCreation.portraitIndex or 1

    local portrait, actualIndex, totalPortraits = getCreationPortrait(classId, gender, portraitIndex)

    if portrait then
        love.graphics.setColor(1, 1, 1)
        local imgW, imgH = portrait:getDimensions()
        local scale = portraitSize / math.max(imgW, imgH)
        love.graphics.draw(portrait, portraitX + (portraitSize - imgW * scale) / 2, portraitY, 0, scale, scale)

        -- Show portrait counter below the portrait
        if totalPortraits and totalPortraits > 1 then
            love.graphics.setColor(0.7, 0.7, 0.8)
            love.graphics.setFont(getFont(11))
            local counterText = "Portrait " .. (actualIndex or portraitIndex) .. " / " .. totalPortraits
            love.graphics.printf(counterText, portraitX, portraitY + portraitSize + 8, portraitSize, "center")
        end
    else
        love.graphics.setColor(0.3, 0.3, 0.4)
        love.graphics.rectangle("fill", portraitX, portraitY, portraitSize, portraitSize, 8, 8)
        love.graphics.setColor(0.6, 0.6, 0.7)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", portraitX, portraitY, portraitSize, portraitSize, 8, 8)
        love.graphics.setLineWidth(1)
    end

    -- Portrait cycling arrows (left/right)
    local arrowSize = 30
    local leftArrowX = portraitX - arrowSize - 20
    local rightArrowX = portraitX + portraitSize + 20
    local arrowY = portraitY + (portraitSize - arrowSize) / 2

    local leftHover = mx >= leftArrowX and mx <= leftArrowX + arrowSize and my >= arrowY and my <= arrowY + arrowSize
    local rightHover = mx >= rightArrowX and mx <= rightArrowX + arrowSize and my >= arrowY and my <= arrowY + arrowSize

    -- Left arrow
    love.graphics.setColor(leftHover and {0.5, 0.5, 0.6} or {0.3, 0.3, 0.4})
    love.graphics.rectangle("fill", leftArrowX, arrowY, arrowSize, arrowSize, 4, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(20))
    love.graphics.printf("<", leftArrowX, arrowY + 5, arrowSize, "center")

    -- Right arrow
    love.graphics.setColor(rightHover and {0.5, 0.5, 0.6} or {0.3, 0.3, 0.4})
    love.graphics.rectangle("fill", rightArrowX, arrowY, arrowSize, arrowSize, 4, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(20))
    love.graphics.printf(">", rightArrowX, arrowY + 5, arrowSize, "center")

    -- Back and Next buttons
    local btnW, btnH = 100, 40
    local backX, backY = x + 20, y + h - btnH - 10
    local backHover = mx >= backX and mx <= backX + btnW and my >= backY and my <= backY + btnH
    love.graphics.setColor(backHover and {0.6, 0.3, 0.3} or {0.4, 0.2, 0.2})
    love.graphics.rectangle("fill", backX, backY, btnW, btnH, 6, 6)
    love.graphics.setColor(1, 0.8, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", backX, backY, btnW, btnH, 6, 6)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(getFont(14))
    love.graphics.printf("Back", backX, backY + 12, btnW, "center")

    local nextX = x + w - btnW - 20
    local nextY = y + h - btnH - 10
    local nextHover = mx >= nextX and mx <= nextX + btnW and my >= nextY and my <= nextY + btnH
    love.graphics.setColor(nextHover and {0.3, 0.7, 0.3} or {0.2, 0.5, 0.2})
    love.graphics.rectangle("fill", nextX, nextY, btnW, btnH, 6, 6)
    love.graphics.setColor(0.9, 1, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", nextX, nextY, btnW, btnH, 6, 6)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(getFont(14))
    love.graphics.printf("Next", nextX, nextY + 12, btnW, "center")
end

-- Step 6: Character Review
M.drawCharacterReview = function(x, y, w, h, mx, my)
    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(20))
    love.graphics.printf("Review Your Character", x, y, w, "center")

    local cc = state.characterCreation

    -- Find race, class, background data
    local race, class, background
    for _, r in ipairs(Data.RACES) do
        if r.id == cc.selectedRace then race = r break end
    end
    if not race then
        for _, r in ipairs(Data.UNLOCKABLE_RACES) do
            if r.id == cc.selectedRace then race = r break end
        end
    end
    for _, c in ipairs(Data.CLASSES) do
        if c.id == cc.selectedClass then class = c break end
    end
    for _, bg in ipairs(Data.BACKGROUNDS) do
        if bg.id == cc.selectedBackground then background = bg break end
    end

    local infoX = x + 50
    local infoY = y + 50

    love.graphics.setFont(getFont(14))
    love.graphics.setColor(0.9, 0.9, 1)
    love.graphics.print("Name: " .. (state.playerNameInput or "Adventurer"), infoX, infoY)
    love.graphics.print("Race: " .. (race and race.name or "Human"), infoX, infoY + 25)
    love.graphics.print("Class: " .. (class and class.name or "Warrior"), infoX, infoY + 50)
    love.graphics.print("Background: " .. (background and background.name or "None"), infoX, infoY + 75)
    love.graphics.print("Gender: " .. (cc.selectedGender or "Other"), infoX, infoY + 100)

    -- Show chosen bonus stats (for races with choice stats)
    if cc.chosenBonusStats and #cc.chosenBonusStats > 0 then
        love.graphics.print("Bonus Stats: +" .. table.concat(cc.chosenBonusStats, ", +"), infoX, infoY + 125)
    end

    -- Show racial bonuses
    if race and race.bonuses and #race.bonuses > 0 then
        local bonusY = infoY + 140
        if cc.chosenBonusStats and #cc.chosenBonusStats > 0 then bonusY = bonusY + 20 end
        love.graphics.setFont(getFont(12))
        love.graphics.setColor(0.8, 0.9, 0.8)
        love.graphics.print("Racial Bonuses:", infoX, bonusY)
        love.graphics.setFont(getFont(10))
        love.graphics.setColor(0.7, 0.8, 0.7)
        for i, bonus in ipairs(race.bonuses) do
            love.graphics.print("\226\128\162 " .. bonus.name, infoX + 10, bonusY + i * 20)
        end
    end

    -- Back and Create buttons
    local btnW, btnH = 120, 50
    local backX, backY = x + 20, y + h - btnH - 10
    local backHover = mx >= backX and mx <= backX + btnW and my >= backY and my <= backY + btnH
    love.graphics.setColor(backHover and {0.6, 0.3, 0.3} or {0.4, 0.2, 0.2})
    love.graphics.rectangle("fill", backX, backY, btnW, btnH, 6, 6)
    love.graphics.setColor(1, 0.8, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", backX, backY, btnW, btnH, 6, 6)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(getFont(14))
    love.graphics.printf("Back", backX, backY + 15, btnW, "center")

    -- Skip Tutorial button (centered between Back and Create)
    local skipW = 150
    local skipX = x + (w - skipW) / 2
    local skipY = y + h - btnH - 10
    local skipHover = mx >= skipX and mx <= skipX + skipW and my >= skipY and my <= skipY + btnH
    love.graphics.setColor(skipHover and {0.9, 0.7, 0.2} or {0.7, 0.5, 0.1})
    love.graphics.rectangle("fill", skipX, skipY, skipW, btnH, 6, 6)
    love.graphics.setColor(1, 0.9, 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", skipX, skipY, skipW, btnH, 6, 6)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(getFont(13))
    love.graphics.printf("SKIP TUTORIAL", skipX, skipY + 16, skipW, "center")

    local createX = x + w - btnW - 20
    local createY = y + h - btnH - 10
    local createHover = mx >= createX and mx <= createX + btnW and my >= createY and my <= createY + btnH
    love.graphics.setColor(createHover and {0.3, 0.8, 0.3} or {0.2, 0.6, 0.2})
    love.graphics.rectangle("fill", createX, createY, btnW, btnH, 6, 6)
    love.graphics.setColor(0.9, 1, 0.9)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", createX, createY, btnW, btnH, 6, 6)
    love.graphics.setLineWidth(1)
    love.graphics.setFont(getFont(16))
    love.graphics.printf("CREATE", createX, createY + 15, btnW, "center")
end

-- ============================================================================
-- PARTY STATUS OVERLAY
-- ============================================================================

M.drawPartyUI = function()
    local screenW, screenH = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()
    local p = state.player
    if not p then return end

    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Main panel - wider than character sheet to fit party info
    local panelW = math.min(720, screenW - 40)
    local panelH = math.min(700, screenH - 40)
    local panelX = screenW / 2 - panelW / 2
    local panelY = screenH / 2 - panelH / 2

    love.graphics.setColor(0.10, 0.10, 0.16)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)
    love.graphics.setColor(0.35, 0.4, 0.55)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 10, 10)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(0.9, 0.75, 0.3)
    love.graphics.setFont(getFont(24))
    love.graphics.printf("PARTY STATUS", panelX, panelY + 12, panelW, "center")

    -- Party count indicator
    local party = p.party or {}
    local maxSize = p.maxPartySize or 99
    love.graphics.setColor(0.6, 0.6, 0.7)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("Members: " .. (#party + 1) .. " / " .. (maxSize + 1) .. " (including you)", panelX, panelY + 40, panelW, "center")

    -- Close button (top-right X)
    local closeX, closeY, closeW, closeH = panelX + panelW - 35, panelY + 10, 25, 25
    local closeHover = mx >= closeX and mx <= closeX + closeW and my >= closeY and my <= closeY + closeH
    love.graphics.setColor(closeHover and {0.8, 0.3, 0.3} or {0.5, 0.2, 0.2})
    love.graphics.rectangle("fill", closeX, closeY, closeW, closeH, 4, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(16))
    love.graphics.printf("X", closeX, closeY + 4, closeW, "center")

    -- Store close button bounds for click detection
    state.partyUICloseBtn = {x = closeX, y = closeY, w = closeW, h = closeH}

    -- Scrollable content area
    local contentX = panelX + 15
    local contentY = panelY + 60
    local contentW = panelW - 30
    local contentH = panelH - 100

    -- Set up scissor for scrolling
    love.graphics.setScissor(contentX, contentY, contentW, contentH)

    local scrollOffset = state.partyUIScroll or 0
    local drawY = contentY - scrollOffset

    -- ========================================
    -- PLAYER CHARACTER (always first)
    -- ========================================
    local cardH = 130
    local cardPad = 8

    drawY = drawPartyMemberCard(p, drawY, contentX, contentW, cardH, mx, my, true)
    drawY = drawY + cardPad

    -- Separator
    love.graphics.setColor(0.3, 0.3, 0.4)
    love.graphics.setLineWidth(1)
    love.graphics.line(contentX + 20, drawY, contentX + contentW - 20, drawY)
    drawY = drawY + cardPad

    -- ========================================
    -- COMPANIONS
    -- ========================================
    if #party == 0 then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.setFont(getFont(14))
        love.graphics.printf("No companions recruited yet.\nVisit the Guild Hall to recruit adventurers!", contentX, drawY + 20, contentW, "center")
        drawY = drawY + 70
    else
        for i, companion in ipairs(party) do
            drawY = drawPartyMemberCard(companion, drawY, contentX, contentW, cardH, mx, my, false)
            drawY = drawY + cardPad
        end
    end

    -- Calculate total scroll height
    local totalContentH = drawY + scrollOffset - contentY
    state.partyUIMaxScroll = math.max(0, totalContentH - contentH)

    love.graphics.setScissor()

    -- Scroll indicator (if content overflows)
    if (state.partyUIMaxScroll or 0) > 0 then
        local scrollbarH = contentH * (contentH / math.max(1, totalContentH))
        scrollbarH = math.max(20, scrollbarH)
        local scrollbarY = contentY + (scrollOffset / math.max(1, state.partyUIMaxScroll)) * (contentH - scrollbarH)

        love.graphics.setColor(0.3, 0.3, 0.4, 0.6)
        love.graphics.rectangle("fill", panelX + panelW - 12, contentY, 6, contentH, 3, 3)
        love.graphics.setColor(0.6, 0.6, 0.8, 0.8)
        love.graphics.rectangle("fill", panelX + panelW - 12, scrollbarY, 6, scrollbarH, 3, 3)
    end

    -- Total wages display at bottom
    local totalWage = 0
    for _, c in ipairs(party) do
        totalWage = totalWage + (c.dailyWage or 0)
    end

    love.graphics.setColor(0.08, 0.08, 0.12)
    love.graphics.rectangle("fill", panelX, panelY + panelH - 35, panelW, 35, 0, 0, 10, 10)

    if totalWage > 0 then
        love.graphics.setColor(0.8, 0.7, 0.3)
        love.graphics.setFont(getFont(11))
        love.graphics.printf("Daily Wages: " .. totalWage .. " gold  |  Your Gold: " .. (p.gold or 0), panelX, panelY + panelH - 28, panelW / 2, "center")
    else
        love.graphics.setColor(0.5, 0.5, 0.6)
        love.graphics.setFont(getFont(11))
        love.graphics.printf("Your Gold: " .. (p.gold or 0), panelX, panelY + panelH - 28, panelW / 2, "center")
    end

    -- Footer instructions
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.setFont(getFont(11))
    love.graphics.printf("[1-4] Select  [S] Skills  [T] Talents  [A] Auto  [P] Close", panelX + panelW / 2, panelY + panelH - 28, panelW / 2, "center")

    love.graphics.setColor(1, 1, 1)
end

-- Helper: Draw a single party member card (player or companion)
drawPartyMemberCard = function(member, startY, x, w, cardH, mx, my, isPlayer)
    local cardX = x + 5
    local cardW = w - 10

    -- Card background
    local hover = mx >= cardX and mx <= cardX + cardW and my >= startY and my <= startY + cardH
    if isPlayer then
        love.graphics.setColor(hover and {0.15, 0.17, 0.25} or {0.12, 0.14, 0.22})
    else
        love.graphics.setColor(hover and {0.14, 0.16, 0.22} or {0.11, 0.13, 0.19})
    end
    love.graphics.rectangle("fill", cardX, startY, cardW, cardH, 6, 6)

    -- Subtle border
    local borderColor = isPlayer and {0.4, 0.45, 0.6} or {0.25, 0.3, 0.4}
    love.graphics.setColor(borderColor)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", cardX, startY, cardW, cardH, 6, 6)

    local innerX = cardX + 10
    local innerY = startY + 8
    local rightCol = cardX + cardW / 2 + 20

    -- === Row 1: Name, Class, Level ===
    if isPlayer then
        -- Player name with golden highlight
        love.graphics.setColor(0.95, 0.85, 0.4)
        love.graphics.setFont(getFont(16))
        love.graphics.print(member.name or "Adventurer", innerX, innerY)

        -- Class and level
        local className = member.class and member.class.name or "Unknown"
        local raceName = member.race and member.race.name or "Human"
        love.graphics.setColor(member.class and member.class.color or {0.7, 0.7, 0.7})
        love.graphics.setFont(getFont(12))
        love.graphics.print(className .. "  |  " .. raceName .. "  |  Level " .. (member.level or 1), innerX, innerY + 20)

        -- Player tag
        love.graphics.setColor(0.3, 0.6, 0.9)
        love.graphics.setFont(getFont(10))
        love.graphics.print("[LEADER]", cardX + cardW - 65, innerY + 2)
    else
        -- Companion name
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(16))
        love.graphics.print(member.name or "Unknown", innerX, innerY)

        -- Class letter icon
        local classLetter = member.class and member.class.id and member.class.id:sub(1, 1):upper() or "?"
        love.graphics.setColor(member.color or {0.7, 0.7, 0.7})
        love.graphics.setFont(getFont(14))
        love.graphics.print("[" .. classLetter .. "]", cardX + cardW - 40, innerY + 2)

        -- Class and level
        local className = member.class and member.class.name or "Unknown"
        love.graphics.setColor(member.class and member.class.color or member.color or {0.7, 0.7, 0.7})
        love.graphics.setFont(getFont(12))
        local levelStr = className .. "  |  Level " .. (member.level or 1)
        -- Skill points indicator
        if (member.skillPoints or 0) > 0 then
            levelStr = levelStr .. "  |  SP: " .. member.skillPoints
        end
        love.graphics.print(levelStr, innerX, innerY + 20)

        -- Talent pending badge
        if member.pendingTalentSelection then
            love.graphics.setColor(0.9, 0.7, 0.2)
            love.graphics.setFont(getFont(10))
            love.graphics.print("TALENT!", cardX + cardW - 100, innerY + 2)
        end
    end

    -- === Row 2: HP Bar ===
    local barY = innerY + 38
    local barW = 200
    local barH = 14

    local currentHP = member.hp or 0
    local maxHP = member.maxHP or 1
    local hpPct = math.max(0, math.min(1, currentHP / math.max(1, maxHP)))

    -- HP bar background
    love.graphics.setColor(0.2, 0.2, 0.25)
    love.graphics.rectangle("fill", innerX, barY, barW, barH, 3, 3)

    -- HP bar fill (green > yellow > red)
    if hpPct > 0.5 then
        love.graphics.setColor(0.3, 0.75, 0.3)
    elseif hpPct > 0.25 then
        love.graphics.setColor(0.8, 0.75, 0.2)
    else
        love.graphics.setColor(0.8, 0.25, 0.25)
    end
    love.graphics.rectangle("fill", innerX, barY, barW * hpPct, barH, 3, 3)

    -- HP text
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(getFont(10))
    love.graphics.printf(currentHP .. " / " .. maxHP .. " HP", innerX, barY + 1, barW, "center")

    -- Mana bar (player only) / XP bar (companion only)
    if isPlayer and member.mana then
        local manaBarX = innerX + barW + 15
        local manaBarW = 140
        local manaPct = math.max(0, math.min(1, (member.mana or 0) / math.max(1, member.maxMana or 1)))
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", manaBarX, barY, manaBarW, barH, 3, 3)
        love.graphics.setColor(0.3, 0.4, 0.85)
        love.graphics.rectangle("fill", manaBarX, barY, manaBarW * manaPct, barH, 3, 3)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(10))
        love.graphics.printf((member.mana or 0) .. " / " .. (member.maxMana or 0) .. " MP", manaBarX, barY + 1, manaBarW, "center")
    elseif not isPlayer then
        -- XP progress bar for companions
        local xpBarX = innerX + barW + 15
        local xpBarW = 140
        local compXP = member.xp or 0
        local compXPToLevel = member.xpToLevel or 100
        local xpPct = math.max(0, math.min(1, compXP / math.max(1, compXPToLevel)))
        love.graphics.setColor(0.2, 0.2, 0.25)
        love.graphics.rectangle("fill", xpBarX, barY, xpBarW, barH, 3, 3)
        love.graphics.setColor(0.4, 0.6, 0.9)
        love.graphics.rectangle("fill", xpBarX, barY, xpBarW * xpPct, barH, 3, 3)
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(getFont(10))
        love.graphics.printf(compXP .. " / " .. compXPToLevel .. " XP", xpBarX, barY + 1, xpBarW, "center")
    end

    -- === Row 3: Stats ===
    local statsY = barY + barH + 6

    love.graphics.setFont(getFont(11))

    if isPlayer then
        -- Player: Show primary stats
        love.graphics.setColor(0.9, 0.6, 0.3)
        love.graphics.print("ATK: " .. (member.attack or 0), innerX, statsY)
        love.graphics.setColor(0.3, 0.6, 0.9)
        love.graphics.print("DEF: " .. (member.defense or 0), innerX + 75, statsY)
        love.graphics.setColor(0.9, 0.85, 0.3)
        love.graphics.print("Crit: " .. (member.critChance or 5) .. "%", innerX + 150, statsY)
        love.graphics.setColor(0.4, 0.8, 0.4)
        love.graphics.print("Dodge: " .. (member.dodgeChance or 0) .. "%", innerX + 235, statsY)

        -- XP
        love.graphics.setColor(0.5, 0.8, 1)
        love.graphics.print("XP: " .. (member.xp or 0) .. "/" .. (member.xpToLevel or 100), innerX + 340, statsY)

        -- Equipment row
        local eqY = statsY + 18
        love.graphics.setFont(getFont(10))
        love.graphics.setColor(0.7, 0.5, 0.3)
        local wep = member.equipment and member.equipment.weapon and member.equipment.weapon.name or "None"
        love.graphics.print("Weapon: " .. wep, innerX, eqY)

        love.graphics.setColor(0.4, 0.55, 0.8)
        local arm = member.equipment and member.equipment.armor and member.equipment.armor.name or "None"
        love.graphics.print("Armor: " .. arm, innerX + 200, eqY)

        love.graphics.setColor(0.65, 0.55, 0.8)
        local acc = member.equipment and member.equipment.accessory and member.equipment.accessory.name or "None"
        love.graphics.print("Accessory: " .. acc, innerX + 380, eqY)

        -- Gold display
        love.graphics.setColor(1, 0.9, 0.3)
        love.graphics.setFont(getFont(12))
        love.graphics.print("Gold: " .. (member.gold or 0), rightCol + 200, innerY + 20)
    else
        -- Companion: Show combat stats + morale + wage
        love.graphics.setColor(0.9, 0.6, 0.3)
        love.graphics.print("ATK: " .. (member.attack or 0), innerX, statsY)
        love.graphics.setColor(0.3, 0.6, 0.9)
        love.graphics.print("DEF: " .. (member.defense or 0), innerX + 75, statsY)

        if member.critBonus and member.critBonus > 0 then
            love.graphics.setColor(0.9, 0.85, 0.3)
            love.graphics.print("Crit+: " .. member.critBonus .. "%", innerX + 150, statsY)
        end

        -- Abilities
        if member.attacks and #member.attacks > 0 then
            love.graphics.setColor(0.6, 0.7, 0.8)
            love.graphics.setFont(getFont(10))
            local atkStr = table.concat(member.attacks, ", ")
            love.graphics.print("Skills: " .. atkStr, innerX, statsY + 17)
        end

        -- Morale (right side)
        local morale = member.morale or 100
        local moraleColor
        if morale >= 70 then
            moraleColor = {0.4, 0.8, 0.4}
        elseif morale >= 40 then
            moraleColor = {0.8, 0.75, 0.3}
        else
            moraleColor = {0.8, 0.35, 0.35}
        end
        love.graphics.setColor(moraleColor)
        love.graphics.setFont(getFont(11))
        love.graphics.print("Morale: " .. morale .. "%", rightCol + 180, statsY)

        -- Daily wage
        love.graphics.setColor(0.7, 0.65, 0.4)
        love.graphics.print("Wage: " .. (member.dailyWage or 0) .. "g/day", rightCol + 180, statsY + 17)

        -- Healer indicator
        if member.canHeal then
            love.graphics.setColor(0.3, 0.9, 0.5)
            love.graphics.setFont(getFont(10))
            love.graphics.print("[Healer +" .. (member.healAmount or 0) .. "]", rightCol + 180, innerY + 2)
        end
    end

    return startY + cardH
end

-- ============================================================================
-- COMPANION SKILL TREE
-- ============================================================================

M.drawCompanionSkillTree = function()
    local compIdx = state.companionSkillTreeIndex
    if not compIdx then return end
    local party = state.player and state.player.party
    if not party or not party[compIdx] then return end
    local companion = party[compIdx]

    local tree = SKILL_TREES and SKILL_TREES.universal

    drawSkillTreePanel(companion, tree, state.selectedCompanionSkillIndex or 1, {
        title = tree and (companion.name .. " - " .. tree.name) or nil,
        showAuto = true,
        autoAllocate = companion.autoAllocate,
        footer = "[Arrows] Navigate  |  [Enter] Unlock  |  [Tab] Auto-Allocate  |  [Escape] Close",
    })
end

-- ============================================================================
-- COMPANION TALENT SELECTION
-- ============================================================================

M.drawCompanionTalentSelection = function()
    local screenW, screenH = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()

    local compIdx = state.companionTalentIndex
    if not compIdx then return end
    local party = state.player and state.player.party
    if not party or not party[compIdx] then return end
    local companion = party[compIdx]

    local mappedClass = Data.COMPANION_CLASS_MAP[companion.class and companion.class.id or ""]

    -- Semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Main panel
    local panelW = math.min(650, screenW - 40)
    local panelH = math.min(480, screenH - 40)
    local panelX = screenW/2 - panelW/2
    local panelY = screenH/2 - panelH/2

    love.graphics.setColor(0.12, 0.1, 0.15)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)
    love.graphics.setColor(0.7, 0.5, 0.2)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 10, 10)
    love.graphics.setLineWidth(1)

    -- Title
    love.graphics.setColor(0.9, 0.7, 0.2)
    love.graphics.setFont(getFont(22))
    love.graphics.printf(companion.name .. " - SELECT A TALENT", panelX, panelY + 15, panelW, "center")

    love.graphics.setColor(0.7, 0.6, 0.5)
    love.graphics.setFont(getFont(14))
    love.graphics.printf("Level " .. (companion.level or 1), panelX, panelY + 45, panelW, "center")

    -- Build available talents list
    local availableTalents = {}

    for _, t in ipairs(Data.UNIVERSAL_TALENTS) do
        if t.level <= (companion.level or 1) then
            local owned = companion.talents and companion.talents[t.id]
            if not owned then
                table.insert(availableTalents, {talent = t, type = "universal"})
            end
        end
    end

    if mappedClass and Data.CLASS_TALENTS[mappedClass] then
        for _, t in ipairs(Data.CLASS_TALENTS[mappedClass]) do
            if t.level <= (companion.level or 1) then
                local owned = companion.talents and companion.talents[t.id]
                if not owned then
                    table.insert(availableTalents, {talent = t, type = "class"})
                end
            end
        end
    end

    local y = panelY + 80
    local talentH = 60
    local talentW = panelW - 60

    for i, entry in ipairs(availableTalents) do
        local t = entry.talent
        local isSelected = (state.selectedCompanionTalentIndex or 1) == i

        local bgColor = entry.type == "class" and {0.2, 0.15, 0.25} or {0.15, 0.18, 0.22}
        if isSelected then
            bgColor[1] = bgColor[1] + 0.15
            bgColor[2] = bgColor[2] + 0.15
            bgColor[3] = bgColor[3] + 0.15
        end
        love.graphics.setColor(bgColor)
        love.graphics.rectangle("fill", panelX + 30, y, talentW, talentH, 6, 6)

        local borderColor = isSelected and {0.9, 0.7, 0.2} or {0.4, 0.35, 0.3}
        love.graphics.setColor(borderColor)
        love.graphics.setLineWidth(isSelected and 2 or 1)
        love.graphics.rectangle("line", panelX + 30, y, talentW, talentH, 6, 6)
        love.graphics.setLineWidth(1)

        love.graphics.setColor(entry.type == "class" and {0.9, 0.6, 0.9} or {0.8, 0.9, 1})
        love.graphics.setFont(getFont(16))
        love.graphics.print(t.name, panelX + 45, y + 8)

        love.graphics.setColor(entry.type == "class" and {0.6, 0.4, 0.6} or {0.4, 0.5, 0.6})
        love.graphics.setFont(getFont(11))
        love.graphics.print(entry.type == "class" and "[CLASS]" or "[UNIVERSAL]", panelX + talentW - 40, y + 10)

        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.setFont(getFont(13))
        love.graphics.print(t.desc, panelX + 45, y + 32)

        y = y + talentH + 8

        if i >= 5 then break end
    end

    -- Footer
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.setFont(getFont(12))
    love.graphics.printf("[Up/Down] Navigate  |  [Enter] Select  |  [Escape] Close", panelX, panelY + panelH - 25, panelW, "center")

    love.graphics.setColor(1, 1, 1)
end

return M
