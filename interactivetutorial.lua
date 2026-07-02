local InteractiveTutorial = {}
local Tutorials = require("tutorials")

-- Font cache
local FontCache = require("fontcache")
local function getFont(size)
    return FontCache.get(size)
end

-- Colors (consistent with game theme)
local colors = {
    overlay = {0, 0, 0, 0.65},
    panelBg = {0.08, 0.10, 0.16, 0.95},
    panelBorder = {0.90, 0.70, 0.25},
    title = {1.0, 0.85, 0.30},
    text = {0.92, 0.92, 0.92},
    textDim = {0.55, 0.55, 0.60},
    buttonBg = {0.20, 0.28, 0.42},
    buttonHover = {0.30, 0.40, 0.55},
    buttonGreen = {0.25, 0.50, 0.30},
    buttonGreenHover = {0.35, 0.60, 0.40},
    buttonRed = {0.45, 0.22, 0.22},
    buttonRedHover = {0.55, 0.30, 0.30},
    buttonBlue = {0.20, 0.35, 0.55},
    buttonBlueHover = {0.30, 0.45, 0.65},
    spotlight = {1.0, 0.85, 0.30},
    arrow = {1.0, 0.85, 0.30},
    dotFilled = {0.90, 0.70, 0.25},
    dotEmpty = {0.30, 0.30, 0.35},
    dotCurrent = {1.0, 0.85, 0.30},
}

-- State
local state = {
    active = false,
    paused = false,
    modeId = nil,
    currentStep = 1,
    animTimer = 0,
    fadeIn = 0,

    -- Spotlight
    spotlightRegion = nil,
    spotlightPadding = 12,
    spotlightPulse = 0,

    -- Arrow
    arrowBounce = 0,
    arrowDirection = "down",

    -- Panel
    panelSide = "auto",
    panelX = 0,
    panelY = 0,
    panelW = 420,
    panelH = 200,

    -- Action waiting
    waitingForAction = nil,
    actionCompleted = false,
    actionCompletedTimer = 0,

    -- Progress
    totalSteps = 0,

    -- UI region resolvers
    regionResolvers = {},

    -- Current step data cache
    stepData = nil,
}

-- Helper: Linear interpolation
local function lerp(a, b, t)
    return a + (b - a) * t
end

-- Helper: Check if point is in rectangle
local function pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

-- Helper: Word wrap text
local function wrapText(text, font, maxWidth)
    local wrappedText = {}
    local line = ""

    for word in text:gmatch("%S+") do
        local testLine = line == "" and word or (line .. " " .. word)
        local width = font:getWidth(testLine)

        if width > maxWidth then
            if line ~= "" then
                table.insert(wrappedText, line)
                line = word
            else
                table.insert(wrappedText, word)
                line = ""
            end
        else
            line = testLine
        end
    end

    if line ~= "" then
        table.insert(wrappedText, line)
    end

    return wrappedText
end

-- Resolve spotlight region for current step
local function resolveSpotlightRegion(stepData)
    if not stepData or not stepData.spotlightQuery then
        return nil
    end

    local currentGameState = GameState and GameState.current or "unknown"
    local resolver = state.regionResolvers[currentGameState]

    if not resolver then
        return nil
    end

    return resolver(stepData.spotlightQuery)
end

-- Calculate panel position based on spotlight and panelSide
local function calculatePanelPosition(spotlightRegion, panelSide)
    local screenW, screenH = love.graphics.getDimensions()
    local pw = state.panelW
    local ph = state.panelH
    local padding = 20

    -- No spotlight - center on screen
    if not spotlightRegion then
        return math.floor((screenW - pw) / 2), math.floor((screenH - ph) / 2)
    end

    local sx, sy, sw, sh = spotlightRegion.x, spotlightRegion.y, spotlightRegion.w, spotlightRegion.h
    local px, py

    -- Auto-positioning logic
    if panelSide == "auto" then
        -- Try below first
        if sy + sh + state.spotlightPadding + ph + padding <= screenH then
            px = math.floor(sx + sw / 2 - pw / 2)
            py = sy + sh + state.spotlightPadding + padding
        -- Try above
        elseif sy - state.spotlightPadding - ph - padding >= 0 then
            px = math.floor(sx + sw / 2 - pw / 2)
            py = sy - state.spotlightPadding - ph - padding
        -- Try right
        elseif sx + sw + state.spotlightPadding + pw + padding <= screenW then
            px = sx + sw + state.spotlightPadding + padding
            py = math.floor(sy + sh / 2 - ph / 2)
        -- Try left
        elseif sx - state.spotlightPadding - pw - padding >= 0 then
            px = sx - state.spotlightPadding - pw - padding
            py = math.floor(sy + sh / 2 - ph / 2)
        else
            -- Fallback to bottom center
            px = math.floor((screenW - pw) / 2)
            py = screenH - ph - padding
        end
    elseif panelSide == "bottom" then
        px = math.floor(sx + sw / 2 - pw / 2)
        py = sy + sh + state.spotlightPadding + padding
    elseif panelSide == "top" then
        px = math.floor(sx + sw / 2 - pw / 2)
        py = sy - state.spotlightPadding - ph - padding
    elseif panelSide == "left" then
        px = sx - state.spotlightPadding - pw - padding
        py = math.floor(sy + sh / 2 - ph / 2)
    elseif panelSide == "right" then
        px = sx + sw + state.spotlightPadding + padding
        py = math.floor(sy + sh / 2 - ph / 2)
    else
        px = math.floor((screenW - pw) / 2)
        py = math.floor((screenH - ph) / 2)
    end

    -- Clamp to screen bounds
    px = math.max(padding, math.min(px, screenW - pw - padding))
    py = math.max(padding, math.min(py, screenH - ph - padding))

    return px, py
end

-- Setup step data and UI
function InteractiveTutorial.setupStep(stepNum)
    if not state.modeId then return end

    local tutorialData = Tutorials.data[state.modeId]
    if not tutorialData or not tutorialData.steps then return end

    local step = tutorialData.steps[stepNum]
    if not step then return end

    state.currentStep = stepNum
    state.stepData = step
    state.actionCompleted = false
    state.actionCompletedTimer = 0

    -- Read step fields with defaults
    local stepType = step.stepType or "info"
    local panelSide = step.panelSide or "auto"
    local arrowDirection = step.arrowDirection or "down"

    state.panelSide = panelSide
    state.arrowDirection = arrowDirection

    -- Resolve spotlight region
    state.spotlightRegion = resolveSpotlightRegion(step)

    -- Calculate panel position
    state.panelX, state.panelY = calculatePanelPosition(state.spotlightRegion, panelSide)

    -- Set waiting for action if needed
    if stepType == "action" and step.waitForAction then
        state.waitingForAction = step.waitForAction
    else
        state.waitingForAction = nil
    end

    -- Reset animations
    state.fadeIn = 0
    state.animTimer = 0
end

-- Start tutorial
function InteractiveTutorial.start(modeId)
    local tutorialData = Tutorials.data[modeId]
    if not tutorialData or not tutorialData.steps or #tutorialData.steps == 0 then
        return false
    end

    state.active = true
    state.paused = false
    state.modeId = modeId
    state.totalSteps = #tutorialData.steps
    state.currentStep = 1
    state.fadeIn = 0
    state.animTimer = 0
    state.spotlightPulse = 0
    state.arrowBounce = 0

    InteractiveTutorial.setupStep(1)

    return true
end

-- Stop tutorial
function InteractiveTutorial.stop()
    if state.modeId then
        Tutorials.markCompleted(state.modeId)
    end

    state.active = false
    state.paused = false
    state.modeId = nil
    state.currentStep = 1
    state.spotlightRegion = nil
    state.waitingForAction = nil
    state.actionCompleted = false
    state.stepData = nil
end

-- Skip tutorial
function InteractiveTutorial.skip()
    InteractiveTutorial.stop()
end

-- Check if active
function InteractiveTutorial.isActive()
    return state.active and not state.paused
end

-- Signal action completed
function InteractiveTutorial.signalAction(actionId)
    if state.active and state.waitingForAction == actionId then
        state.actionCompleted = true
    end
end

-- Register region resolver
function InteractiveTutorial.registerRegionResolver(gameState, resolverFn)
    state.regionResolvers[gameState] = resolverFn
end

-- Advance to next step
local function advanceStep()
    if state.currentStep < state.totalSteps then
        InteractiveTutorial.setupStep(state.currentStep + 1)
    else
        InteractiveTutorial.stop()
    end
end

-- Go to previous step
local function previousStep()
    if state.currentStep > 1 then
        InteractiveTutorial.setupStep(state.currentStep - 1)
    end
end

-- Update
function InteractiveTutorial.update(dt)
    if not state.active then return end

    -- Check pause state
    if PauseMenu and PauseMenu.isActive() then
        state.paused = true
        return
    else
        state.paused = false
    end

    -- Update animations
    state.animTimer = state.animTimer + dt
    state.fadeIn = math.min(1, state.fadeIn + dt * 3)
    state.spotlightPulse = state.animTimer * 2
    state.arrowBounce = state.animTimer * 4

    -- Auto-advance on action completion
    if state.actionCompleted then
        state.actionCompletedTimer = state.actionCompletedTimer + dt
        if state.actionCompletedTimer >= 0.5 then
            advanceStep()
        end
    end

    -- Check freeform conditions (if step has condition function)
    if state.stepData and state.stepData.stepType == "freeform" and state.stepData.condition then
        if state.stepData.condition() then
            advanceStep()
        end
    end
end

-- Draw spotlight with stencil
local function drawSpotlight()
    local region = state.spotlightRegion
    local screenW, screenH = love.graphics.getDimensions()

    if region then
        -- Draw spotlight glow border first (behind stencil)
        local pulse = math.sin(state.spotlightPulse) * 0.3 + 0.7
        local pad = state.spotlightPadding

        love.graphics.setColor(colors.spotlight[1], colors.spotlight[2], colors.spotlight[3], 0.4 * pulse * state.fadeIn)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line",
            region.x - pad,
            region.y - pad,
            region.w + pad * 2,
            region.h + pad * 2,
            8, 8)

        -- Setup stencil for cutout
        love.graphics.stencil(function()
            love.graphics.rectangle("fill",
                region.x - pad,
                region.y - pad,
                region.w + pad * 2,
                region.h + pad * 2,
                8, 8)
        end, "replace", 1)
        love.graphics.setStencilTest("notequal", 1)
    end

    -- Draw dark overlay (everywhere except spotlight)
    love.graphics.setColor(colors.overlay[1], colors.overlay[2], colors.overlay[3], colors.overlay[4] * state.fadeIn)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    if region then
        love.graphics.setStencilTest()
    end
end

-- Draw arrow pointing to spotlight
local function drawArrow()
    if not state.spotlightRegion then return end

    local region = state.spotlightRegion
    local bounce = math.sin(state.arrowBounce) * 10
    local arrowSize = 20
    local pad = state.spotlightPadding + 10

    love.graphics.setColor(colors.arrow[1], colors.arrow[2], colors.arrow[3], state.fadeIn)

    local cx = region.x + region.w / 2
    local cy = region.y + region.h / 2

    if state.arrowDirection == "down" then
        local x = cx
        local y = region.y - pad - arrowSize + bounce
        love.graphics.polygon("fill",
            x, y + arrowSize,
            x - arrowSize / 2, y,
            x + arrowSize / 2, y)
    elseif state.arrowDirection == "up" then
        local x = cx
        local y = region.y + region.h + pad + arrowSize - bounce
        love.graphics.polygon("fill",
            x, y - arrowSize,
            x - arrowSize / 2, y,
            x + arrowSize / 2, y)
    elseif state.arrowDirection == "left" then
        local x = region.x + region.w + pad + arrowSize - bounce
        local y = cy
        love.graphics.polygon("fill",
            x - arrowSize, y,
            x, y - arrowSize / 2,
            x, y + arrowSize / 2)
    elseif state.arrowDirection == "right" then
        local x = region.x - pad - arrowSize + bounce
        local y = cy
        love.graphics.polygon("fill",
            x + arrowSize, y,
            x, y - arrowSize / 2,
            x, y + arrowSize / 2)
    end
end

-- Draw instruction panel
local function drawPanel()
    if not state.stepData then return end

    local px = state.panelX
    local py = state.panelY
    local pw = state.panelW
    local ph = state.panelH
    local mx, my = love.mouse.getPosition()

    -- Panel background
    love.graphics.setColor(colors.panelBg)
    love.graphics.rectangle("fill", px, py, pw, ph, 8, 8)

    -- Panel border
    love.graphics.setColor(colors.panelBorder)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", px, py, pw, ph, 8, 8)

    local titleFont = getFont(18)
    local textFont = getFont(14)
    local smallFont = getFont(12)

    local yOffset = py + 15
    local xPadding = 20

    -- Title
    love.graphics.setFont(titleFont)
    love.graphics.setColor(colors.title)
    love.graphics.printf(state.stepData.title or "Tutorial", px + xPadding, yOffset, pw - xPadding * 2, "left")
    yOffset = yOffset + 30

    -- Step counter
    love.graphics.setFont(smallFont)
    love.graphics.setColor(colors.textDim)
    local stepText = string.format("Step %d of %d", state.currentStep, state.totalSteps)
    love.graphics.printf(stepText, px + xPadding, yOffset, pw - xPadding * 2, "right")
    yOffset = yOffset + 25

    -- Body text
    love.graphics.setFont(textFont)
    love.graphics.setColor(colors.text)
    local text = state.stepData.text or ""
    local wrappedLines = wrapText(text, textFont, pw - xPadding * 2)
    for i, line in ipairs(wrappedLines) do
        love.graphics.print(line, px + xPadding, yOffset)
        yOffset = yOffset + 20
    end

    -- Action waiting indicator
    if state.stepData.stepType == "action" and state.waitingForAction and not state.actionCompleted then
        yOffset = yOffset + 10
        love.graphics.setColor(colors.textDim)
        local dots = string.rep(".", math.floor(state.animTimer * 3) % 4)
        love.graphics.print("Waiting for action" .. dots, px + xPadding, yOffset)
    end

    -- Freeform indicator
    if state.stepData.stepType == "freeform" then
        yOffset = yOffset + 10
        love.graphics.setColor(colors.textDim)
        love.graphics.print("Explore freely!", px + xPadding, yOffset)
    end

    -- Progress dots
    local dotY = py + ph - 60
    local dotSize = 8
    local dotSpacing = 16
    local totalWidth = state.totalSteps * dotSpacing - (dotSpacing - dotSize)
    local startX = px + (pw - totalWidth) / 2

    for i = 1, state.totalSteps do
        if i < state.currentStep then
            love.graphics.setColor(colors.dotFilled)
            love.graphics.circle("fill", startX + (i - 1) * dotSpacing, dotY, dotSize / 2)
        elseif i == state.currentStep then
            love.graphics.setColor(colors.dotCurrent)
            love.graphics.circle("fill", startX + (i - 1) * dotSpacing, dotY, dotSize / 2)
        else
            love.graphics.setColor(colors.dotEmpty)
            love.graphics.circle("line", startX + (i - 1) * dotSpacing, dotY, dotSize / 2)
        end
    end

    -- Buttons
    local buttonY = py + ph - 35
    local buttonH = 28
    local buttonSpacing = 10
    local buttonFont = getFont(13)
    love.graphics.setFont(buttonFont)

    local buttons = {}

    -- Back button
    if state.currentStep > 1 then
        local backW = 80
        local backX = px + 20
        local isHover = pointInRect(mx, my, backX, buttonY, backW, buttonH)

        love.graphics.setColor(isHover and colors.buttonHover or colors.buttonBg)
        love.graphics.rectangle("fill", backX, buttonY, backW, buttonH, 4, 4)
        love.graphics.setColor(colors.text)
        love.graphics.printf("< Back", backX, buttonY + 6, backW, "center")

        table.insert(buttons, {x = backX, y = buttonY, w = backW, h = buttonH, action = "back"})
    end

    -- Next/Done button
    local nextW = 80
    local nextX = px + pw - 20 - nextW
    local isLastStep = state.currentStep >= state.totalSteps
    local nextText = isLastStep and "Done" or "Next >"
    local nextDisabled = state.waitingForAction and not state.actionCompleted
    local nextHover = pointInRect(mx, my, nextX, buttonY, nextW, buttonH) and not nextDisabled

    if nextDisabled then
        love.graphics.setColor(0.15, 0.15, 0.18)
    else
        love.graphics.setColor(nextHover and colors.buttonGreenHover or colors.buttonGreen)
    end
    love.graphics.rectangle("fill", nextX, buttonY, nextW, buttonH, 4, 4)
    love.graphics.setColor(nextDisabled and colors.textDim or colors.text)
    love.graphics.printf(nextText, nextX, buttonY + 6, nextW, "center")

    if not nextDisabled then
        table.insert(buttons, {x = nextX, y = buttonY, w = nextW, h = buttonH, action = isLastStep and "done" or "next"})
    end

    -- Skip button (center)
    local skipW = 70
    local skipX = px + (pw - skipW) / 2
    local skipHover = pointInRect(mx, my, skipX, buttonY, skipW, buttonH)

    love.graphics.setColor(skipHover and colors.buttonRedHover or colors.buttonRed)
    love.graphics.rectangle("fill", skipX, buttonY, skipW, buttonH, 4, 4)
    love.graphics.setColor(colors.text)
    love.graphics.printf("Skip", skipX, buttonY + 6, skipW, "center")

    table.insert(buttons, {x = skipX, y = buttonY, w = skipW, h = buttonH, action = "skip"})

    -- KC Link button
    if state.stepData.kcLink then
        local kcY = buttonY - buttonH - 8
        local kcW = 120
        local kcX = px + (pw - kcW) / 2
        local kcHover = pointInRect(mx, my, kcX, kcY, kcW, buttonH)

        love.graphics.setColor(kcHover and colors.buttonBlueHover or colors.buttonBlue)
        love.graphics.rectangle("fill", kcX, kcY, kcW, buttonH, 4, 4)
        love.graphics.setColor(colors.text)
        love.graphics.printf("Learn More", kcX, kcY + 6, kcW, "center")

        table.insert(buttons, {x = kcX, y = kcY, w = kcW, h = buttonH, action = "kclink"})
    end

    -- Store buttons for click handling
    state.currentButtons = buttons
end

-- Draw skip button in corner
local function drawSkipButton()
    local screenW, screenH = love.graphics.getDimensions()
    local skipW = 120
    local skipH = 30
    local skipX = screenW - skipW - 15
    local skipY = 15
    local mx, my = love.mouse.getPosition()
    local isHover = pointInRect(mx, my, skipX, skipY, skipW, skipH)

    love.graphics.setColor(colors.panelBg[1], colors.panelBg[2], colors.panelBg[3], 0.8)
    love.graphics.rectangle("fill", skipX, skipY, skipW, skipH, 4, 4)

    love.graphics.setColor(colors.panelBorder)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", skipX, skipY, skipW, skipH, 4, 4)

    local font = getFont(13)
    love.graphics.setFont(font)
    love.graphics.setColor(isHover and colors.title or colors.text)
    love.graphics.printf("X Skip Tutorial", skipX, skipY + 7, skipW, "center")

    state.skipButtonRegion = {x = skipX, y = skipY, w = skipW, h = skipH}
end

-- Draw
function InteractiveTutorial.draw()
    if not state.active or state.paused then return end

    love.graphics.push()

    -- Draw in order
    drawSpotlight()
    drawArrow()
    drawPanel()
    drawSkipButton()

    love.graphics.pop()

    -- Reset graphics state
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
end

-- Keypressed
function InteractiveTutorial.keypressed(key)
    if not state.active or state.paused then return false end

    if key == "return" or key == "space" or key == "right" then
        if not state.waitingForAction or state.actionCompleted then
            advanceStep()
        end
        return true
    elseif key == "left" then
        previousStep()
        return true
    elseif key == "escape" then
        InteractiveTutorial.skip()
        return true
    end

    return true
end

-- Mousepressed
function InteractiveTutorial.mousepressed(x, y, button)
    if not state.active or state.paused then return false end
    if button ~= 1 then return false end

    -- Check skip button in corner
    if state.skipButtonRegion then
        local r = state.skipButtonRegion
        if pointInRect(x, y, r.x, r.y, r.w, r.h) then
            InteractiveTutorial.skip()
            return true
        end
    end

    -- Check panel buttons
    if state.currentButtons then
        for _, btn in ipairs(state.currentButtons) do
            if pointInRect(x, y, btn.x, btn.y, btn.w, btn.h) then
                if btn.action == "back" then
                    previousStep()
                elseif btn.action == "next" then
                    advanceStep()
                elseif btn.action == "done" then
                    InteractiveTutorial.stop()
                elseif btn.action == "skip" then
                    InteractiveTutorial.skip()
                elseif btn.action == "kclink" then
                    if state.stepData.kcLink then
                        -- Open Knowledge Center to entry
                        if KnowledgeCenter and KnowledgeCenter.openToEntry then
                            KnowledgeCenter.openToEntry(state.stepData.kcLink)
                        end
                    end
                end
                return true
            end
        end
    end

    return true
end

return InteractiveTutorial
