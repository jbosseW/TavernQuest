-- Simplified combat UI (replacement for lines 21592-22234)
local UI = require("ui")

local CombatUI = {}

-- Note: state, getPortraitImage, and SKILLS are globals provided by textrpg.lua
function drawCombat(x, y, w, h, mx, my)
    if not state.player then return end
    local enemies = state.combat.enemies or {}
    local numEnemies = #enemies
    if numEnemies == 0 then return end

    -- Layout: Enemies at top, Player/Party at bottom
    local combatAreaH = h - 80
    local enemyZoneH = combatAreaH * 0.45
    local playerZoneH = combatAreaH * 0.35
    local middleZoneH = combatAreaH * 0.20

    -- ==================== ENEMIES (TOP) ====================
    -- Multi-row layout when enemies exceed 8
    local maxPerRow = math.min(numEnemies, 8)
    local numEnemyRows = math.ceil(numEnemies / maxPerRow)
    local enemyCardW = math.min(180, (w - 100) / maxPerRow - 12)
    local enemyCardH = numEnemyRows > 1 and 120 or 160
    local enemyPortraitSize = numEnemyRows > 1 and 60 or 80
    local totalEnemyWidth = maxPerRow * (enemyCardW + 10) - 10
    local enemyStartX = x + (w - totalEnemyWidth - 90) / 2
    local enemyY = y + 10

    -- Check if this is a manually-controlled companion turn
    -- Per-companion autoBattle overrides manual control for that companion
    local currentCompAutoBattle = false
    if state.combat.isCompanionTurn and state.combat.currentCompanionIndex then
        local comp = state.player and state.player.party and state.player.party[state.combat.currentCompanionIndex]
        if comp and comp.autoBattle then currentCompAutoBattle = true end
    end
    local isManualCompTurn = state.combat.isCompanionTurn
        and state.player and state.player.manualPartyControl ~= false
        and not currentCompAutoBattle

    -- Player can select targets during their own turn OR during manual companion turns
    local canSelectTarget = state.combat.isPlayerTurn or isManualCompTurn

    state.combat.enemyButtons = {}
    for i, enemy in ipairs(enemies) do
        local row = math.floor((i - 1) / maxPerRow)
        local col = (i - 1) % maxPerRow
        -- Center partial last row
        local enemiesInThisRow = (row < numEnemyRows - 1) and maxPerRow or (numEnemies - row * maxPerRow)
        local rowWidth = enemiesInThisRow * (enemyCardW + 10) - 10
        local rowStartX = x + (w - rowWidth - 90) / 2
        local cardX = rowStartX + col * (enemyCardW + 10)
        local cardY = enemyY + row * (enemyCardH + 8)
        local isSelected = (i == state.combat.selectedTarget)
        local isDead = enemy.hp <= 0
        local isActing = (state.combat.currentActorIndex == i and not state.combat.isPlayerTurn)

        -- Card background
        if isDead then
            love.graphics.setColor(0.1, 0.1, 0.1, 0.6)
        elseif isActing then
            love.graphics.setColor(0.35, 0.15, 0.15)
        elseif isSelected and canSelectTarget then
            love.graphics.setColor(0.2, 0.28, 0.38)
        else
            love.graphics.setColor(0.18, 0.14, 0.14)
        end
        love.graphics.rectangle("fill", cardX, cardY, enemyCardW, enemyCardH, 8, 8)

        -- Selection/acting border
        if isSelected and canSelectTarget and not isDead then
            love.graphics.setColor(isManualCompTurn and {0.3, 0.7, 0.95} or {0.3, 0.95, 0.3})
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", cardX, cardY, enemyCardW, enemyCardH, 8, 8)
            love.graphics.setLineWidth(1)
        elseif isActing then
            love.graphics.setColor(1, 0.4, 0.3)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", cardX, cardY, enemyCardW, enemyCardH, 8, 8)
            love.graphics.setLineWidth(1)
        end

        -- Enemy portrait
        local enemyPortrait = getPortraitImage(enemy.id)
        if enemyPortrait then
            love.graphics.setColor(isDead and {0.4, 0.4, 0.4} or {1, 1, 1})
            local imgW, imgH = enemyPortrait:getDimensions()
            local scale = enemyPortraitSize / math.max(imgW, imgH)
            local px = cardX + (enemyCardW - imgW * scale) / 2
            local py = cardY + 8
            love.graphics.draw(enemyPortrait, px, py, 0, scale, scale)
        else
            love.graphics.setFont(UI.fonts.get(numEnemyRows > 1 and 28 or 40))
            love.graphics.setColor(isDead and {0.4, 0.4, 0.4} or {0.9, 0.3, 0.3})
            love.graphics.printf(enemy.portrait or "?", cardX, cardY + (numEnemyRows > 1 and 10 or 20), enemyCardW, "center")
        end

        -- Enemy name
        love.graphics.setFont(UI.fonts.get(numEnemyRows > 1 and 10 or 12))
        love.graphics.setColor(isDead and {0.5, 0.5, 0.5} or {1, 1, 1})
        love.graphics.printf(enemy.name, cardX + 4, cardY + enemyPortraitSize + (numEnemyRows > 1 and 4 or 12), enemyCardW - 8, "center")

        -- HP bar
        local hpBarW = enemyCardW - 20
        local barH = numEnemyRows > 1 and 10 or 14
        local barX = cardX + 10
        local barY = cardY + enemyCardH - (numEnemyRows > 1 and 18 or 28)
        local hpBar = UI.ProgressBar.new({
            x = barX,
            y = barY,
            w = hpBarW,
            h = barH,
            value = math.max(0, enemy.hp / enemy.maxHP),
            label = math.max(0, enemy.hp) .. "/" .. enemy.maxHP,
            colorOverride = isDead and {0.2, 0.2, 0.25} or {0.85, 0.2, 0.2}
        })
        hpBar:draw()

        -- Dead indicator
        if isDead then
            local deadH = numEnemyRows > 1 and 20 or 28
            love.graphics.setColor(0.5, 0.15, 0.15, 0.85)
            love.graphics.rectangle("fill", cardX + 10, cardY + enemyCardH/2 - deadH/2, enemyCardW - 20, deadH, 5, 5)
            love.graphics.setColor(0.95, 0.3, 0.3)
            love.graphics.setFont(UI.fonts.get(numEnemyRows > 1 and 12 or 16))
            love.graphics.printf("DEAD", cardX, cardY + enemyCardH/2 - (numEnemyRows > 1 and 6 or 10), enemyCardW, "center")
        end

        state.combat.enemyButtons[i] = {x = cardX, y = cardY, w = enemyCardW, h = enemyCardH, dead = isDead}
    end

    -- ==================== PLAYER & PARTY (BOTTOM) ====================
    local playerZoneY = y + enemyZoneH + middleZoneH + 20
    local party = state.player.party or {}
    local totalChars = 1 + #party
    local compactParty = totalChars > 6  -- Switch to compact list when > 5 companions + player

    local playerCardW = compactParty and 110 or 140
    local playerCardH = compactParty and 90 or 120
    local playerPortraitSize = compactParty and 40 or 60

    -- Multi-row for party: up to 6 per row in compact, otherwise all in one row
    local maxPartyPerRow = compactParty and 6 or totalChars
    local numPartyRows = math.ceil(totalChars / maxPartyPerRow)
    local charsInFirstRow = math.min(totalChars, maxPartyPerRow)
    local totalPlayerWidth = charsInFirstRow * (playerCardW + 10) - 10
    local playerStartX = x + (w - totalPlayerWidth - 90) / 2

    -- Helper to draw a single character card (player or companion)
    local function drawCharCard(cardX, cardY, charData, isPlayer, isActing, cardW, cardH, portraitSz)
        local isDead = not isPlayer and ((charData.hp or 0) <= 0)

        -- Card background
        if isPlayer then
            love.graphics.setColor(isActing and {0.15, 0.3, 0.2} or {0.12, 0.18, 0.15})
        else
            if isDead then
                love.graphics.setColor(0.12, 0.1, 0.1)
            elseif isActing then
                love.graphics.setColor(0.15, 0.22, 0.32)
            else
                love.graphics.setColor(0.1, 0.14, 0.2)
            end
        end
        love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 8, 8)

        -- Acting border
        if isActing then
            love.graphics.setColor(isPlayer and {0.3, 1, 0.4} or {0.4, 0.8, 1})
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", cardX, cardY, cardW, cardH, 8, 8)
            love.graphics.setLineWidth(1)
        end

        -- Portrait
        local portraitId
        if isPlayer then
            portraitId = state.player.class and state.player.class.id or "warrior"
        else
            local compClassId = charData.class and charData.class.id or "warrior"
            portraitId = charData.portrait or compClassId
        end
        local portrait = getPortraitImage(portraitId)
        if portrait then
            love.graphics.setColor(isDead and {0.4, 0.4, 0.4} or {1, 1, 1})
            local imgW, imgH = portrait:getDimensions()
            local scale = portraitSz / math.max(imgW, imgH)
            local px = cardX + (cardW - imgW * scale) / 2
            local py = cardY + (compactParty and 4 or 6)
            love.graphics.draw(portrait, px, py, 0, scale, scale)
        else
            local fallbackSize = compactParty and 20 or 28
            love.graphics.setFont(UI.fonts.get(fallbackSize))
            if isPlayer then
                local combatClassColor = state.player.class and state.player.class.color or {0.7, 0.7, 0.7}
                love.graphics.setColor(combatClassColor)
                love.graphics.printf((state.player.class and state.player.class.id or "warrior"):sub(1,1):upper(), cardX, cardY + (compactParty and 8 or 15), cardW, "center")
            else
                local compClassId = charData.class and charData.class.id or "warrior"
                love.graphics.setColor(isDead and {0.4, 0.4, 0.4} or (charData.color or {0.7, 0.7, 0.7}))
                love.graphics.printf(compClassId:sub(1,1):upper(), cardX, cardY + (compactParty and 8 or 15), cardW, "center")
            end
        end

        -- Name
        love.graphics.setFont(UI.fonts.get(compactParty and 9 or (isPlayer and 11 or 10)))
        love.graphics.setColor(isPlayer and {0.3, 1, 0.4} or (isDead and {0.5, 0.5, 0.5} or {0.7, 0.85, 1}))
        local nameStr = isPlayer and (state.player.name or "YOU") or charData.name
        love.graphics.printf(nameStr, cardX + 4, cardY + portraitSz + (compactParty and 2 or 8), cardW - 8, "center")

        -- HP bar
        local barW = cardW - 16
        local barH = compactParty and 10 or 12
        local barX = cardX + 8
        local barY = cardY + cardH - (compactParty and 22 or 38)
        local hp, maxHP
        if isPlayer then
            hp = state.player.hp or 0
            maxHP = state.player.maxHP or 1
        else
            hp = charData.hp or 0
            maxHP = charData.maxHP or 1
        end
        local hpPct = math.max(0, hp / math.max(1, maxHP))
        local hpColor
        if isDead then
            hpColor = {0.2, 0.2, 0.25}
        elseif hpPct > 0.5 then
            hpColor = {0.3, 0.85, 0.3}
        elseif hpPct > 0.25 then
            hpColor = {0.85, 0.85, 0.3}
        else
            hpColor = {0.85, 0.3, 0.3}
        end
        local hpBar = UI.ProgressBar.new({
            x = barX, y = barY, w = barW, h = barH,
            value = hpPct,
            label = math.max(0, hp) .. "/" .. maxHP,
            colorOverride = hpColor
        })
        hpBar:draw()

        -- Mana bar (player only, skip in compact mode to save space)
        if isPlayer and not compactParty then
            local manaBarY = barY + 16
            local manaPct = math.max(0, (state.player.mana or 0) / math.max(1, state.player.maxMana or 1))
            local manaBar = UI.ProgressBar.new({
                x = barX, y = manaBarY, w = barW, h = barH - 2,
                value = manaPct,
                label = (state.player.mana or 0) .. "/" .. (state.player.maxMana or 1),
                colorOverride = {0.3, 0.4, 0.9}
            })
            manaBar:draw()
        end

        -- Dead indicator (companions only)
        if isDead and not isPlayer then
            local deadH = compactParty and 16 or 24
            love.graphics.setColor(0.6, 0.15, 0.15, 0.85)
            love.graphics.rectangle("fill", cardX + 10, cardY + cardH/2 - deadH/2, cardW - 20, deadH, 4, 4)
            love.graphics.setColor(0.95, 0.35, 0.35)
            love.graphics.setFont(UI.fonts.get(compactParty and 10 or 12))
            love.graphics.printf("DOWN", cardX, cardY + cardH/2 - (compactParty and 5 or 8), cardW, "center")
        end
    end

    -- Draw all characters (player + party) with row/col layout
    for charIdx = 0, totalChars - 1 do
        local pRow = math.floor(charIdx / maxPartyPerRow)
        local pCol = charIdx % maxPartyPerRow
        local charsInThisRow = (pRow < numPartyRows - 1) and maxPartyPerRow or (totalChars - pRow * maxPartyPerRow)
        local thisRowWidth = charsInThisRow * (playerCardW + 10) - 10
        local thisRowStartX = x + (w - thisRowWidth - 90) / 2
        local cx = thisRowStartX + pCol * (playerCardW + 10)
        local cy = playerZoneY + pRow * (playerCardH + 6)

        if charIdx == 0 then
            -- Player card
            local isPlayerActing = state.combat.isPlayerTurn
            drawCharCard(cx, cy, state.player, true, isPlayerActing, playerCardW, playerCardH, playerPortraitSize)
        else
            -- Companion card
            local companion = party[charIdx]
            local isActing = state.combat.isCompanionTurn and state.combat.currentCompanionIndex == charIdx
            drawCharCard(cx, cy, companion, false, isActing, playerCardW, playerCardH, playerPortraitSize)
        end
    end

    -- ==================== TURN ORDER (Right side) ====================
    local initX = x + w - 85
    local initY = y + 10
    local turnOrder = state.combat and state.combat.turnOrder or {}
    local totalTurns = #turnOrder
    local maxVisibleTurns = 12
    local visibleTurns = math.min(totalTurns, maxVisibleTurns)
    local extraTurns = totalTurns - visibleTurns
    local initH = 22 + visibleTurns * 16 + (extraTurns > 0 and 16 or 0)
    love.graphics.setColor(0.1, 0.1, 0.15, 0.92)
    love.graphics.rectangle("fill", initX, initY, 78, initH, 5, 5)
    love.graphics.setColor(0.7, 0.7, 0.9)
    love.graphics.setFont(UI.fonts.get(9))
    love.graphics.printf("Turn Order", initX, initY + 4, 78, "center")

    for i = 1, visibleTurns do
        local turn = turnOrder[i]
        if turn then
            local iy = initY + 18 + (i - 1) * 15
            local isCurrent = (i == state.combat.currentTurnIndex)
            if isCurrent then
                love.graphics.setColor(0.25, 0.4, 0.28)
                love.graphics.rectangle("fill", initX + 3, iy, 72, 13, 3, 3)
            end
            love.graphics.setFont(UI.fonts.get(8))
            if turn.type == "player" then
                love.graphics.setColor(isCurrent and {0.4, 1, 0.4} or {0.5, 0.8, 0.5})
                love.graphics.print("> YOU", initX + 6, iy + 2)
            elseif turn.type == "companion" then
                local companion = state.player.party[turn.index]
                if companion then
                    love.graphics.setColor(companion.hp <= 0 and {0.4, 0.4, 0.4} or (isCurrent and {0.4, 0.85, 1} or {0.45, 0.65, 0.85}))
                    love.graphics.print(string.sub(companion.name, 1, 8), initX + 6, iy + 2)
                end
            else
                local enemy = enemies[turn.index]
                if enemy then
                    love.graphics.setColor(enemy.hp <= 0 and {0.4, 0.4, 0.4} or (isCurrent and {1, 0.55, 0.35} or {0.8, 0.5, 0.5}))
                    love.graphics.print(string.sub(enemy.name, 1, 8), initX + 6, iy + 2)
                end
            end
        end
    end

    -- "+X more" indicator when turn order overflows
    if extraTurns > 0 then
        local moreY = initY + 18 + visibleTurns * 15
        love.graphics.setFont(UI.fonts.get(8))
        love.graphics.setColor(0.5, 0.5, 0.65)
        love.graphics.printf("+" .. extraTurns .. " more", initX, moreY + 2, 78, "center")
    end

    -- ==================== MIDDLE ZONE (Turn indicator & Actions) ====================
    local middleY = y + enemyZoneH + 5
    love.graphics.setFont(UI.fonts.get(13))
    if state.combat.isPlayerTurn then
        love.graphics.setColor(0.35, 0.95, 0.4)
        love.graphics.printf("YOUR TURN - Select a target and act!", x, middleY, w - 95, "center")
    elseif isManualCompTurn then
        local companion = state.player.party[state.combat.currentCompanionIndex]
        if companion then
            love.graphics.setColor(0.4, 0.85, 1)
            love.graphics.printf(companion.name .. "'s TURN - Select target and act!", x, middleY, w - 95, "center")
        end
    elseif state.combat.isCompanionTurn then
        local companion = state.player.party[state.combat.currentCompanionIndex]
        if companion then
            love.graphics.setColor(0.4, 0.75, 0.95)
            love.graphics.printf(companion.name .. " is acting...", x, middleY, w - 95, "center")
        end
    else
        local actor = enemies[state.combat.currentActorIndex]
        if actor then
            love.graphics.setColor(0.95, 0.55, 0.35)
            love.graphics.printf(actor.name .. " is attacking!", x, middleY, w - 95, "center")
        end
    end

    -- Combat actions (player turn or manual companion turn)
    local actY = middleY + 22
    if state.combat.isPlayerTurn then
        local actions = {{name = "Attack", icon = "X"}, {name = "Skills", icon = "*"}, {name = "Items", icon = "I"}, {name = "Run", icon = ">"}}
        local actW, actH = 100, 35
        local actionStartX = x + (w - 95 - #actions * (actW + 8)) / 2

        for i, act in ipairs(actions) do
            local ax = actionStartX + (i - 1) * (actW + 8)
            local hover = mx >= ax and mx <= ax + actW and my >= actY and my <= actY + actH
            love.graphics.setColor(hover and {0.32, 0.42, 0.52} or {0.22, 0.28, 0.38})
            love.graphics.rectangle("fill", ax, actY, actW, actH, 5, 5)
            love.graphics.setFont(UI.fonts.get(14))
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("[" .. act.icon .. "]", ax + 6, actY + 9)
            love.graphics.setFont(UI.fonts.get(11))
            love.graphics.print(act.name, ax + 32, actY + 11)
        end

        -- Skills submenu
        if state.combat.showSkills then
            local skillY = actY + 42
            for i, skillName in ipairs(state.player.skills) do
                local skill = SKILLS[skillName]
                if skill then
                    local sy = skillY + (i - 1) * 30
                    local hover = mx >= x + 30 and mx <= x + w - 120 and my >= sy and my <= sy + 26
                    love.graphics.setColor(hover and {0.28, 0.38, 0.52} or {0.18, 0.22, 0.32})
                    love.graphics.rectangle("fill", x + 30, sy, w - 160, 26, 4, 4)
                    love.graphics.setColor(state.player.mana >= skill.manaCost and {1, 1, 1} or {0.5, 0.5, 0.5})
                    love.graphics.setFont(UI.fonts.get(11))
                    love.graphics.print(skillName .. " (" .. skill.manaCost .. " MP)", x + 42, sy + 6)
                end
            end
        end
    elseif isManualCompTurn then
        -- Companion manual control actions: Attack + Defend/Heal + Auto + Auto All
        local companion = state.player.party[state.combat.currentCompanionIndex]
        local compActions = {
            {name = "Attack", icon = "X"},
            {name = companion and companion.canHeal and "Heal" or "Defend", icon = "D"},
            {name = "Auto", icon = "3", toggle = true},
            {name = "Auto All", icon = "4", toggle = true},
        }
        local actW, actH = 100, 35
        local actionStartX = x + (w - 95 - #compActions * (actW + 8)) / 2

        for i, act in ipairs(compActions) do
            local ax = actionStartX + (i - 1) * (actW + 8)
            local hover = mx >= ax and mx <= ax + actW and my >= actY and my <= actY + actH
            local isAutoBtn = (act.name == "Auto" or act.name == "Auto All")
            love.graphics.setColor(hover and (isAutoBtn and {0.28, 0.45, 0.28} or {0.22, 0.38, 0.52}) or (isAutoBtn and {0.15, 0.30, 0.15} or {0.15, 0.25, 0.38}))
            love.graphics.rectangle("fill", ax, actY, actW, actH, 5, 5)
            love.graphics.setFont(UI.fonts.get(14))
            love.graphics.setColor(isAutoBtn and {0.6, 1, 0.6} or {0.7, 0.9, 1})
            love.graphics.print("[" .. act.icon .. "]", ax + 6, actY + 9)
            love.graphics.setFont(UI.fonts.get(11))
            love.graphics.print(act.name, ax + 36, actY + 11)
        end
    end

    -- Persistent Auto-Party toggle (visible during all combat phases when party exists)
    if state.player.party and #state.player.party > 0 then
        local allAuto = true
        for _, c in ipairs(state.player.party) do
            if not c.autoBattle then allAuto = false; break end
        end
        local toggleW, toggleH = 110, 24
        local toggleX = x + w - 95 - toggleW - 5
        local toggleY = y + 4
        local toggleHover = mx >= toggleX and mx <= toggleX + toggleW and my >= toggleY and my <= toggleY + toggleH
        -- Store for click handling
        state.combat.autoPartyToggle = {x = toggleX, y = toggleY, w = toggleW, h = toggleH}

        love.graphics.setColor(toggleHover and (allAuto and {0.35, 0.5, 0.25} or {0.25, 0.35, 0.25}) or (allAuto and {0.25, 0.4, 0.18} or {0.18, 0.25, 0.18}))
        love.graphics.rectangle("fill", toggleX, toggleY, toggleW, toggleH, 4, 4)
        love.graphics.setColor(allAuto and {0.5, 1, 0.5} or {0.4, 0.6, 0.4})
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", toggleX, toggleY, toggleW, toggleH, 4, 4)
        love.graphics.setFont(UI.fonts.get(10))
        love.graphics.setColor(allAuto and {0.7, 1, 0.7} or {0.5, 0.7, 0.5})
        love.graphics.printf("Auto Party: " .. (allAuto and "ON" or "OFF"), toggleX, toggleY + 6, toggleW, "center")
    end
end

CombatUI.drawCombat = drawCombat

return CombatUI
