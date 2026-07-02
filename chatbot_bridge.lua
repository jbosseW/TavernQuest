-- Chatbot Bridge - Connects NPC dialogue to external Python chatbot via file-based IPC
-- Uses JSON files in a shared directory for communication
-- Falls back to pure Lua chatbot engine when Python backend is not running

local json = require("json")
local chatbotFallback = require("chatbot_fallback")
local M = {}

local state
local F
local fallbackInitialized = false
local useFallback = false  -- set true after first IPC timeout

-- ============================================================================
-- IPC DIRECTORY
-- ============================================================================

local ipcDir = nil  -- Cached IPC directory path

local function getIPCDir()
    if ipcDir then return ipcDir end

    -- Use love.filesystem.getSource() to get the game directory
    local sourceDir = love.filesystem.getSource()
    -- Normalize path separators for Windows compatibility
    sourceDir = sourceDir:gsub("\\", "/")
    -- Remove trailing slash if present
    if sourceDir:sub(-1) == "/" then
        sourceDir = sourceDir:sub(1, -2)
    end

    ipcDir = sourceDir .. "/chatbot/ipc/"

    -- Ensure directory exists (create via os.execute for Windows + Unix)
    local dirPath = ipcDir:gsub("/", "\\")
    if love.system.getOS() == "Windows" then
        os.execute('if not exist "' .. dirPath .. '" mkdir "' .. dirPath .. '"')
    else
        os.execute('mkdir -p "' .. ipcDir .. '"')
    end

    return ipcDir
end

-- ============================================================================
-- FREE TALK STATE
-- ============================================================================

local freeTalkState = {
    active = false,
    inputText = "",
    cursorPos = 0,
    cursorBlink = 0,
    waitingForResponse = false,
    waitTimer = 0,
    conversationLog = {},     -- list of {speaker="player"/"npc", text="..."}
    currentNPC = nil,
    suggestedOptions = {},    -- clickable suggestions from chatbot
    maxWaitTime = 5.0,
    scrollOffset = 0,
    maxScrollOffset = 0,
    lastSentMessage = "",     -- for recall with Up arrow
    pollInterval = 0.1,       -- check for response every 100ms
    pollTimer = 0,
    connectionWarning = false, -- true if chatbot appears not running
    connectionCheckTimer = 0,
}

-- ============================================================================
-- F-TABLE FUNCTION LIST
-- ============================================================================

M.F_FUNCTIONS = {
    "startFreeTalk", "updateFreeTalk", "drawFreeTalk",
    "freeTalkKeypressed", "freeTalkTextinput", "freeTalkMousepressed",
    "isFreeTalkActive", "freeTalkMousewheel",
}

-- ============================================================================
-- REGISTRATION
-- ============================================================================

function M.register(s, f)
    state = s
    F = f
    for _, name in ipairs(M.F_FUNCTIONS) do
        if M[name] then F[name] = M[name] end
    end

    -- Initialize the Lua fallback engine
    if not fallbackInitialized then
        local ok, err = pcall(function()
            chatbotFallback.init()
        end)
        if ok and chatbotFallback.isInitialized() then
            fallbackInitialized = true
            print("[ChatbotBridge] Lua fallback engine initialized ("
                  .. chatbotFallback.getProfileCount() .. " profiles)")
        else
            print("[ChatbotBridge] Lua fallback init failed: " .. tostring(err))
        end
    end
end

-- ============================================================================
-- HELPER: Word-wrap text to fit a given pixel width
-- ============================================================================

local function wordWrap(text, font, maxWidth)
    local lines = {}
    -- Split on existing newlines first
    for segment in text:gmatch("([^\n]*)\n?") do
        if segment == "" and #lines > 0 then
            lines[#lines + 1] = ""
        else
            local line = ""
            for word in segment:gmatch("%S+") do
                local testLine = line == "" and word or (line .. " " .. word)
                if font:getWidth(testLine) > maxWidth then
                    if line ~= "" then
                        lines[#lines + 1] = line
                    end
                    -- Handle very long single words
                    if font:getWidth(word) > maxWidth then
                        local partial = ""
                        for i = 1, #word do
                            local ch = word:sub(i, i)
                            if font:getWidth(partial .. ch) > maxWidth then
                                lines[#lines + 1] = partial
                                partial = ch
                            else
                                partial = partial .. ch
                            end
                        end
                        line = partial
                    else
                        line = word
                    end
                else
                    line = testLine
                end
            end
            if line ~= "" then
                lines[#lines + 1] = line
            end
        end
    end
    if #lines == 0 then
        lines[1] = ""
    end
    return lines
end

-- ============================================================================
-- INTERNAL: Build request table from current NPC and game state
-- ============================================================================

local function buildRequest(text)
    local npc = freeTalkState.currentNPC
    if not npc then return nil end

    local weather = "pleasant"
    if F.getCurrentWeather then
        weather = F.getCurrentWeather()
    end

    local townName = "Unknown"
    if state.world and state.world.currentTown and state.world.currentTown.name then
        townName = state.world.currentTown.name
    end

    local timeOfDay = "afternoon"
    local tod = state.timeOfDay or 12
    if type(tod) == "number" then
        if tod < 6 then
            timeOfDay = "night"
        elseif tod < 12 then
            timeOfDay = "morning"
        elseif tod < 18 then
            timeOfDay = "afternoon"
        else
            timeOfDay = "evening"
        end
    elseif type(tod) == "string" then
        timeOfDay = tod
    end

    local professionName = "commoner"
    if npc.profession then
        if type(npc.profession) == "string" then
            professionName = npc.profession
        elseif type(npc.profession) == "table" and npc.profession.name then
            professionName = npc.profession.name
        end
    end

    return {
        message = text,
        npc_id = npc.id or "unknown",
        npc_type = professionName,
        npc_name = npc.name or "Unknown NPC",
        player_name = state.player and state.player.name or "Adventurer",
        player_race = state.player and state.player.race or "human",
        player_karma = state.player and state.player.karma or 0,
        context = {
            town = townName,
            weather = weather,
            time_of_day = timeOfDay,
            player_level = state.player and state.player.level or 1,
        },
    }
end

-- ============================================================================
-- INTERNAL: Process message through Lua fallback engine (no IPC)
-- ============================================================================

local function processFallback(text, request)
    if not fallbackInitialized then return false end

    local ok, response = pcall(chatbotFallback.process, request)
    if not ok or not response then
        print("[ChatbotBridge] Fallback error: " .. tostring(response))
        return false
    end

    -- Add NPC reply to conversation log
    local npcName = freeTalkState.currentNPC and freeTalkState.currentNPC.name or "NPC"
    freeTalkState.conversationLog[#freeTalkState.conversationLog + 1] = {
        speaker = "npc",
        text = response.reply or "...",
    }

    -- Update suggested options
    freeTalkState.suggestedOptions = response.options or {}

    -- Check if conversation should end
    if response.end_conversation then
        freeTalkState.active = false
        freeTalkState.waitingForResponse = false
        freeTalkState.inputText = ""
        freeTalkState.cursorPos = 0
        freeTalkState.scrollOffset = 0
        freeTalkState.suggestedOptions = {}
        freeTalkState.connectionWarning = false
        local npc = freeTalkState.currentNPC
        if npc and F.buildDialogueOptions then
            state.dialogue.options = F.buildDialogueOptions(npc)
        end
        if npc then
            state.dialogue.text = npc.name .. " nods as you finish your conversation."
        end
    end

    return true
end

-- ============================================================================
-- INTERNAL: Send message to chatbot via IPC (or fallback)
-- ============================================================================

local function sendMessage(text)
    if not text or text == "" then return end

    local npc = freeTalkState.currentNPC
    if not npc then return end

    local request = buildRequest(text)
    if not request then return end

    -- Add player message to log
    freeTalkState.conversationLog[#freeTalkState.conversationLog + 1] = {
        speaker = "player",
        text = text,
    }

    -- Clear input
    freeTalkState.inputText = ""
    freeTalkState.cursorPos = 0
    freeTalkState.lastSentMessage = text

    -- If we already know IPC is down, go straight to Lua fallback
    if useFallback and fallbackInitialized then
        if processFallback(text, request) then
            return
        end
    end

    -- Try IPC: write request JSON file
    local dir = getIPCDir()
    local encoded, encErr = json.encode(request)
    if not encoded then
        print("[ChatbotBridge] JSON encode error: " .. tostring(encErr))
        -- Try fallback
        if fallbackInitialized then
            useFallback = true
            processFallback(text, request)
        end
        return
    end

    local filePath = dir .. "request.json"
    local osPath = filePath
    if love.system.getOS() == "Windows" then
        osPath = filePath:gsub("/", "\\")
    end

    local file, err = io.open(osPath, "w")
    if not file then
        print("[ChatbotBridge] Failed to write request: " .. tostring(err))
        -- Try fallback instead of just warning
        if fallbackInitialized then
            useFallback = true
            processFallback(text, request)
        else
            freeTalkState.connectionWarning = true
        end
        return
    end
    file:write(encoded)
    file:close()

    -- Store request for fallback use if IPC times out
    freeTalkState._pendingRequest = request

    -- Update state: wait for IPC response
    freeTalkState.waitingForResponse = true
    freeTalkState.waitTimer = 0
    freeTalkState.pollTimer = 0
    freeTalkState.connectionWarning = false
end

-- ============================================================================
-- INTERNAL: Exit free talk mode
-- ============================================================================

local function exitFreeTalk()
    freeTalkState.active = false
    freeTalkState.waitingForResponse = false
    freeTalkState.inputText = ""
    freeTalkState.cursorPos = 0
    freeTalkState.scrollOffset = 0
    freeTalkState.suggestedOptions = {}
    freeTalkState.connectionWarning = false

    -- Rebuild normal dialogue options
    local npc = freeTalkState.currentNPC
    if npc and F.buildDialogueOptions then
        state.dialogue.options = F.buildDialogueOptions(npc)
    end

    -- Restore dialogue text
    if npc then
        state.dialogue.text = npc.name .. " nods as you finish your conversation."
    end
end

-- ============================================================================
-- INTERNAL: Check for response from chatbot
-- ============================================================================

local function checkForResponse()
    local dir = getIPCDir()
    local filePath = dir .. "response.json"
    local osPath = filePath
    if love.system.getOS() == "Windows" then
        osPath = filePath:gsub("/", "\\")
    end

    local file = io.open(osPath, "r")
    if not file then
        return false  -- No response yet
    end

    local content = file:read("*a")
    file:close()

    -- Delete the response file
    os.remove(osPath)

    if not content or content == "" then
        return false
    end

    local response, decErr = json.decode(content)
    if not response then
        print("[ChatbotBridge] JSON decode error: " .. tostring(decErr))
        return false
    end

    -- Add NPC reply to conversation log
    local replyText = response.reply or response.message or "..."
    freeTalkState.conversationLog[#freeTalkState.conversationLog + 1] = {
        speaker = "npc",
        text = replyText,
    }

    -- Update suggested options
    freeTalkState.suggestedOptions = response.options or {}

    -- Stop waiting
    freeTalkState.waitingForResponse = false
    freeTalkState.waitTimer = 0
    freeTalkState.connectionWarning = false

    -- Check if chatbot wants to end conversation
    if response.end_conversation then
        exitFreeTalk()
    end

    return true
end

-- ============================================================================
-- F.startFreeTalk(npc)
-- ============================================================================

M.startFreeTalk = function(npc)
    if not npc then return end

    freeTalkState.active = true
    freeTalkState.currentNPC = npc
    freeTalkState.conversationLog = {}
    freeTalkState.inputText = ""
    freeTalkState.cursorPos = 0
    freeTalkState.cursorBlink = 0
    freeTalkState.waitingForResponse = false
    freeTalkState.waitTimer = 0
    freeTalkState.pollTimer = 0
    freeTalkState.scrollOffset = 0
    freeTalkState.maxScrollOffset = 0
    freeTalkState.suggestedOptions = {}
    freeTalkState.lastSentMessage = ""
    freeTalkState.connectionWarning = false
    freeTalkState.connectionCheckTimer = 0

    -- Reset fallback conversation state for this NPC
    if fallbackInitialized then
        chatbotFallback.resetState(npc.id or "unknown")
    end

    -- Send an initial greeting request to the chatbot
    sendMessage("hello")
end

-- ============================================================================
-- F.isFreeTalkActive()
-- ============================================================================

M.isFreeTalkActive = function()
    return freeTalkState.active
end

-- ============================================================================
-- F.updateFreeTalk(dt)
-- ============================================================================

M.updateFreeTalk = function(dt)
    if not freeTalkState.active then return end

    -- Update cursor blink timer
    freeTalkState.cursorBlink = freeTalkState.cursorBlink + dt
    if freeTalkState.cursorBlink > 1.0 then
        freeTalkState.cursorBlink = freeTalkState.cursorBlink - 1.0
    end

    -- Poll for response if waiting
    if freeTalkState.waitingForResponse then
        freeTalkState.waitTimer = freeTalkState.waitTimer + dt
        freeTalkState.pollTimer = freeTalkState.pollTimer + dt

        -- Poll at interval
        if freeTalkState.pollTimer >= freeTalkState.pollInterval then
            freeTalkState.pollTimer = 0
            checkForResponse()
        end

        -- Timeout: try Lua fallback before showing warning
        if freeTalkState.waitTimer > freeTalkState.maxWaitTime then
            freeTalkState.waitingForResponse = false

            -- Switch to Lua fallback for this and all future messages
            if fallbackInitialized and freeTalkState._pendingRequest then
                useFallback = true
                local handled = processFallback(
                    freeTalkState._pendingRequest.message,
                    freeTalkState._pendingRequest
                )
                freeTalkState._pendingRequest = nil
                if handled then
                    -- Fallback worked, no warning needed
                    print("[ChatbotBridge] Python backend not responding, using Lua fallback")
                    return
                end
            end

            -- Fallback also failed or not available
            freeTalkState.connectionWarning = true
            freeTalkState.conversationLog[#freeTalkState.conversationLog + 1] = {
                speaker = "system",
                text = "[No response - chatbot may not be running. Start with: python -m chatbot]",
            }
        end
    end
end

-- ============================================================================
-- F.drawFreeTalk()
-- ============================================================================

M.drawFreeTalk = function()
    if not freeTalkState.active then return end

    local screenW, screenH = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()

    -- Panel dimensions: 80% width, 70% height, centered
    local panelW = math.floor(screenW * 0.80)
    local panelH = math.floor(screenH * 0.70)
    local panelX = math.floor((screenW - panelW) / 2)
    local panelY = math.floor((screenH - panelH) / 2)

    -- Fonts (use default love font to avoid creating new fonts every frame)
    local defaultFont = love.graphics.getFont()
    local lineHeight = defaultFont:getHeight() + 4

    -- Layout zones
    local titleBarH = 36
    local inputAreaH = 44
    local hintBarH = 22
    local suggestH = 0
    local suggestBtnH = 30
    local suggestPad = 6

    -- Calculate suggestion area height
    if #freeTalkState.suggestedOptions > 0 then
        suggestH = suggestBtnH + suggestPad * 2
    end

    local chatAreaY = panelY + titleBarH
    local chatAreaH = panelH - titleBarH - inputAreaH - hintBarH - suggestH
    local chatAreaW = panelW - 20  -- 10px padding each side

    -- ================================================
    -- Background overlay (dim the game behind)
    -- ================================================
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- ================================================
    -- Panel background
    -- ================================================
    love.graphics.setColor(0.05, 0.05, 0.1, 0.92)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)

    -- Panel border
    love.graphics.setColor(0.3, 0.25, 0.5, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 10, 10)
    love.graphics.setLineWidth(1)

    -- ================================================
    -- Title bar
    -- ================================================
    love.graphics.setColor(0.15, 0.12, 0.25)
    love.graphics.rectangle("fill", panelX, panelY, panelW, titleBarH, 10, 10)
    -- Fill bottom corners of title bar
    love.graphics.rectangle("fill", panelX, panelY + titleBarH - 10, panelW, 10)

    local npcName = freeTalkState.currentNPC and freeTalkState.currentNPC.name or "NPC"
    love.graphics.setColor(0.9, 0.85, 1.0)
    love.graphics.print("Talking with " .. npcName, panelX + 14, panelY + 10)

    -- Close button (X) in top-right corner
    local closeBtnX = panelX + panelW - 32
    local closeBtnY = panelY + 6
    local closeBtnSize = 24
    local closeHover = mx >= closeBtnX and mx <= closeBtnX + closeBtnSize
        and my >= closeBtnY and my <= closeBtnY + closeBtnSize

    love.graphics.setColor(closeHover and {0.8, 0.3, 0.3} or {0.5, 0.3, 0.3})
    love.graphics.rectangle("fill", closeBtnX, closeBtnY, closeBtnSize, closeBtnSize, 4, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("X", closeBtnX + 7, closeBtnY + 4)

    -- ================================================
    -- Chat area (scrollable conversation log)
    -- ================================================
    love.graphics.setScissor(panelX + 10, chatAreaY, chatAreaW, chatAreaH)

    local textMaxW = chatAreaW - 20  -- padding inside chat area
    local drawY = chatAreaY + 6 - freeTalkState.scrollOffset
    local totalContentH = 0

    for _, entry in ipairs(freeTalkState.conversationLog) do
        local prefix, color
        if entry.speaker == "player" then
            prefix = "You: "
            color = {0.5, 0.8, 1.0}
        elseif entry.speaker == "npc" then
            prefix = npcName .. ": "
            color = {1.0, 0.9, 0.5}
        else
            prefix = ""
            color = {0.6, 0.6, 0.6}
        end

        local fullText = prefix .. entry.text
        local wrapped = wordWrap(fullText, defaultFont, textMaxW)

        for _, line in ipairs(wrapped) do
            love.graphics.setColor(color)
            love.graphics.print(line, panelX + 20, drawY)
            drawY = drawY + lineHeight
            totalContentH = totalContentH + lineHeight
        end

        -- Small gap between messages
        drawY = drawY + 4
        totalContentH = totalContentH + 4
    end

    -- Waiting indicator
    if freeTalkState.waitingForResponse then
        local dots = string.rep(".", math.floor(freeTalkState.waitTimer * 3) % 4)
        love.graphics.setColor(0.6, 0.6, 0.7)
        love.graphics.print(npcName .. " is thinking" .. dots, panelX + 20, drawY)
        drawY = drawY + lineHeight
        totalContentH = totalContentH + lineHeight
    end

    -- Update max scroll offset
    freeTalkState.maxScrollOffset = math.max(0, totalContentH - chatAreaH + 20)

    love.graphics.setScissor()

    -- Auto-scroll to bottom when new messages appear
    if totalContentH > chatAreaH then
        if freeTalkState.scrollOffset >= freeTalkState.maxScrollOffset - lineHeight * 3 or
           freeTalkState.scrollOffset == 0 then
            freeTalkState.scrollOffset = freeTalkState.maxScrollOffset
        end
    end

    -- ================================================
    -- Suggested options (clickable buttons)
    -- ================================================
    if #freeTalkState.suggestedOptions > 0 then
        local suggestY = panelY + panelH - inputAreaH - hintBarH - suggestH

        local btnX = panelX + 14
        for i, option in ipairs(freeTalkState.suggestedOptions) do
            local optText = type(option) == "string" and option or (option.text or tostring(option))
            local btnW = defaultFont:getWidth(optText) + 20
            local btnH = suggestBtnH

            if btnX + btnW > panelX + panelW - 14 then
                break  -- Skip options that don't fit
            end

            local hover = mx >= btnX and mx <= btnX + btnW
                and my >= suggestY + suggestPad and my <= suggestY + suggestPad + btnH

            love.graphics.setColor(hover and {0.25, 0.22, 0.4} or {0.15, 0.13, 0.28})
            love.graphics.rectangle("fill", btnX, suggestY + suggestPad, btnW, btnH, 6, 6)

            love.graphics.setColor(hover and {0.4, 0.35, 0.6} or {0.3, 0.25, 0.45})
            love.graphics.rectangle("line", btnX, suggestY + suggestPad, btnW, btnH, 6, 6)

            love.graphics.setColor(hover and {0.9, 0.85, 1.0} or {0.7, 0.65, 0.85})
            love.graphics.print(optText, btnX + 10, suggestY + suggestPad + 7)

            btnX = btnX + btnW + 8
        end
    end

    -- ================================================
    -- Input field
    -- ================================================
    local inputY = panelY + panelH - inputAreaH - hintBarH
    local inputX = panelX + 10
    local inputW = panelW - 20
    local inputH = inputAreaH - 6

    -- Input box background
    love.graphics.setColor(0.08, 0.08, 0.14)
    love.graphics.rectangle("fill", inputX, inputY, inputW, inputH, 6, 6)

    -- Input box border
    local inputFocusColor = freeTalkState.waitingForResponse and {0.3, 0.3, 0.4} or {0.4, 0.5, 0.7}
    love.graphics.setColor(inputFocusColor)
    love.graphics.rectangle("line", inputX, inputY, inputW, inputH, 6, 6)

    -- Input text
    love.graphics.setScissor(inputX + 8, inputY + 2, inputW - 16, inputH - 4)

    local displayText = freeTalkState.inputText
    if freeTalkState.waitingForResponse then
        love.graphics.setColor(0.4, 0.4, 0.5)
        love.graphics.print("Waiting for response...", inputX + 10, inputY + 10)
    elseif displayText == "" then
        love.graphics.setColor(0.35, 0.35, 0.45)
        love.graphics.print("Type your message...", inputX + 10, inputY + 10)
    else
        love.graphics.setColor(0.9, 0.9, 0.95)
        love.graphics.print(displayText, inputX + 10, inputY + 10)
    end

    -- Blinking cursor
    if not freeTalkState.waitingForResponse and freeTalkState.cursorBlink < 0.5 then
        local beforeCursor = displayText:sub(1, freeTalkState.cursorPos)
        local cursorX = inputX + 10 + defaultFont:getWidth(beforeCursor)
        love.graphics.setColor(0.8, 0.8, 1.0)
        love.graphics.rectangle("fill", cursorX, inputY + 8, 2, defaultFont:getHeight())
    end

    love.graphics.setScissor()

    -- ================================================
    -- Hint bar
    -- ================================================
    local hintY = panelY + panelH - hintBarH
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.print("Enter: Send  |  Esc: Exit  |  Up: Recall  |  Scroll: Mouse Wheel", panelX + 14, hintY + 4)

    -- Connection status
    if freeTalkState.connectionWarning then
        love.graphics.setColor(0.9, 0.6, 0.2)
        local warnText = "Chatbot not connected - start with: python -m chatbot"
        love.graphics.print(warnText, panelX + panelW - defaultFont:getWidth(warnText) - 14, hintY + 4)
    elseif useFallback then
        love.graphics.setColor(0.5, 0.7, 0.5)
        local fbText = "Offline mode"
        love.graphics.print(fbText, panelX + panelW - defaultFont:getWidth(fbText) - 14, hintY + 4)
    end
end

-- ============================================================================
-- F.freeTalkKeypressed(key)
-- ============================================================================

M.freeTalkKeypressed = function(key)
    if not freeTalkState.active then return end

    if key == "return" or key == "kpenter" then
        if freeTalkState.inputText ~= "" and not freeTalkState.waitingForResponse then
            sendMessage(freeTalkState.inputText)
        end

    elseif key == "escape" then
        exitFreeTalk()

    elseif key == "backspace" then
        if freeTalkState.cursorPos > 0 then
            local before = freeTalkState.inputText:sub(1, freeTalkState.cursorPos - 1)
            local after = freeTalkState.inputText:sub(freeTalkState.cursorPos + 1)
            freeTalkState.inputText = before .. after
            freeTalkState.cursorPos = freeTalkState.cursorPos - 1
        end

    elseif key == "delete" then
        if freeTalkState.cursorPos < #freeTalkState.inputText then
            local before = freeTalkState.inputText:sub(1, freeTalkState.cursorPos)
            local after = freeTalkState.inputText:sub(freeTalkState.cursorPos + 2)
            freeTalkState.inputText = before .. after
        end

    elseif key == "left" then
        freeTalkState.cursorPos = math.max(0, freeTalkState.cursorPos - 1)

    elseif key == "right" then
        freeTalkState.cursorPos = math.min(#freeTalkState.inputText, freeTalkState.cursorPos + 1)

    elseif key == "home" then
        freeTalkState.cursorPos = 0

    elseif key == "end" then
        freeTalkState.cursorPos = #freeTalkState.inputText

    elseif key == "up" then
        if freeTalkState.lastSentMessage ~= "" then
            freeTalkState.inputText = freeTalkState.lastSentMessage
            freeTalkState.cursorPos = #freeTalkState.inputText
        end

    elseif key == "a" and love.keyboard.isDown("lctrl", "rctrl") then
        if freeTalkState.lastSentMessage ~= "" then
            freeTalkState.inputText = freeTalkState.lastSentMessage
            freeTalkState.cursorPos = #freeTalkState.inputText
        end
    end

    -- Reset cursor blink on any key
    freeTalkState.cursorBlink = 0
end

-- ============================================================================
-- F.freeTalkTextinput(text)
-- ============================================================================

M.freeTalkTextinput = function(text)
    if not freeTalkState.active then return end
    if freeTalkState.waitingForResponse then return end

    local before = freeTalkState.inputText:sub(1, freeTalkState.cursorPos)
    local after = freeTalkState.inputText:sub(freeTalkState.cursorPos + 1)
    freeTalkState.inputText = before .. text .. after
    freeTalkState.cursorPos = freeTalkState.cursorPos + #text
    freeTalkState.cursorBlink = 0
end

-- ============================================================================
-- F.freeTalkMousepressed(x, y, button)
-- ============================================================================

M.freeTalkMousepressed = function(x, y, button)
    if not freeTalkState.active then return end
    if button ~= 1 then return end

    local screenW, screenH = love.graphics.getDimensions()
    local panelW = math.floor(screenW * 0.80)
    local panelH = math.floor(screenH * 0.70)
    local panelX = math.floor((screenW - panelW) / 2)
    local panelY = math.floor((screenH - panelH) / 2)

    -- Close button
    local closeBtnX = panelX + panelW - 32
    local closeBtnY = panelY + 6
    local closeBtnSize = 24
    if x >= closeBtnX and x <= closeBtnX + closeBtnSize
       and y >= closeBtnY and y <= closeBtnY + closeBtnSize then
        exitFreeTalk()
        return
    end

    -- Suggested options
    if #freeTalkState.suggestedOptions > 0 and not freeTalkState.waitingForResponse then
        local inputAreaH = 44
        local hintBarH = 22
        local suggestBtnH = 30
        local suggestPad = 6
        local suggestH = suggestBtnH + suggestPad * 2
        local suggestY = panelY + panelH - inputAreaH - hintBarH - suggestH

        local defaultFont = love.graphics.getFont()
        local btnX = panelX + 14
        for i, option in ipairs(freeTalkState.suggestedOptions) do
            local optText = type(option) == "string" and option or (option.text or tostring(option))
            local btnW = defaultFont:getWidth(optText) + 20

            if btnX + btnW > panelX + panelW - 14 then
                break
            end

            if x >= btnX and x <= btnX + btnW
               and y >= suggestY + suggestPad and y <= suggestY + suggestPad + suggestBtnH then
                sendMessage(optText)
                return
            end

            btnX = btnX + btnW + 8
        end
    end
end

-- ============================================================================
-- F.freeTalkMousewheel(x, y)
-- ============================================================================

M.freeTalkMousewheel = function(wx, wy)
    if not freeTalkState.active then return end

    local scrollStep = 30
    freeTalkState.scrollOffset = freeTalkState.scrollOffset - wy * scrollStep
    freeTalkState.scrollOffset = math.max(0, freeTalkState.scrollOffset)
    freeTalkState.scrollOffset = math.min(freeTalkState.maxScrollOffset, freeTalkState.scrollOffset)
end

return M
