-- Knowledge Center - Expanded in-game glossary and help system
-- Migrated to use UI component library from ui.lua

local KnowledgeCenter = {}
local UI = require("ui")
local UIAssets = require("uiassets")
local Glossary = require("glossary")
local KCData = require("kcdata")
local Tutorials = require("tutorials")

-- Section definitions
local SECTIONS = {
    {id = "tutorials", name = "Tutorials", icon = "T"},
    {id = "glossary", name = "Glossary", icon = "G"},
    {id = "mechanics", name = "Mechanics", icon = "M"},
    {id = "bestiary", name = "Bestiary", icon = "B"},
    {id = "minigames", name = "Minigames", icon = "P"},
    {id = "items", name = "Items", icon = "I"},
    {id = "controls", name = "Controls", icon = "C"},
    {id = "lore", name = "Lore", icon = "L"},
}

-- Custom colors that extend the UI theme
local colors = {
    gold = {1.0, 0.85, 0.30},
    link = {1.0, 0.80, 0.25},
    newBadge = {0.30, 0.80, 0.40},
    locked = {0.35, 0.35, 0.40},
    listSelected = {0.18, 0.25, 0.40},
    listHover = {0.14, 0.18, 0.28},
    listAltRow = {0.11, 0.12, 0.18},
}

-- State
local state = {
    active = false,
    currentSection = "tutorials",
    currentEntry = nil,
    selectedLetterFilter = nil,
    linkHitAreas = {},

    -- UI components
    mainPanel = nil,
    searchInput = nil,
    entryListScroll = nil,
    detailScroll = nil,
    sectionButtons = {},
    letterButtons = {},
    replayButton = nil,
}

-- Initialize PlayerData tracking
local function ensurePlayerDataTables()
    if not PlayerData then return end
    PlayerData.discoveredBestiary = PlayerData.discoveredBestiary or {}
    PlayerData.kcReadEntries = PlayerData.kcReadEntries or {}
end

-- Helper: Check if entry is unread
local function isEntryUnread(entryId)
    if not PlayerData or not PlayerData.kcReadEntries then return false end
    return not PlayerData.kcReadEntries[entryId]
end

-- Helper: Mark entry as read
local function markEntryAsRead(entryId)
    if not PlayerData or not PlayerData.kcReadEntries then return end
    PlayerData.kcReadEntries[entryId] = true
    if savePlayerData then
        savePlayerData()
    end
end

-- Helper: Check if bestiary entry is discovered
local function isBestiaryDiscovered(entryId)
    if not PlayerData or not PlayerData.discoveredBestiary then return false end
    return PlayerData.discoveredBestiary[entryId] == true
end

-- Helper: Find which section contains an entry ID
local function findSectionForEntry(entryId)
    -- Check tutorials
    if Tutorials and Tutorials.data and Tutorials.data[entryId] then
        return "tutorials"
    end

    -- Check glossary
    if Glossary and Glossary.getTerm then
        local term = Glossary.getTerm(entryId)
        if term then return "glossary" end
    end

    -- Check KCData sections
    for _, section in ipairs(SECTIONS) do
        if section.id ~= "tutorials" and section.id ~= "glossary" then
            if KCData and KCData.entries and KCData.entries[section.id] then
                for _, entry in ipairs(KCData.entries[section.id]) do
                    if entry.id == entryId then
                        return section.id
                    end
                end
            end
        end
    end

    return nil
end

-- Get entries for current section
local function getEntriesForSection(sectionId)
    if sectionId == "tutorials" then
        -- Build tutorial entries from Tutorials module
        local entries = {}
        if Tutorials and Tutorials.data then
            for modeId, tutData in pairs(Tutorials.data) do
                table.insert(entries, {
                    id = modeId,
                    title = tutData.title or modeId,
                    category = tutData.category or "General",
                    content = tutData.description or "No description available.",
                    tags = tutData.tags or {},
                    modeId = modeId,
                })
            end
            -- Sort by category then title
            table.sort(entries, function(a, b)
                if a.category ~= b.category then
                    return a.category < b.category
                end
                return a.title < b.title
            end)
        end
        return entries
    elseif sectionId == "glossary" then
        -- Build glossary entries from Glossary module
        local entries = {}
        if Glossary and Glossary.terms then
            for _, term in pairs(Glossary.terms) do
                table.insert(entries, {
                    id = term.id,
                    title = term.term or term.id,
                    content = term.definition or "",
                    tags = term.tags or {},
                    seeAlso = term.seeAlso or {},
                })
            end
            -- Sort alphabetically
            table.sort(entries, function(a, b)
                return a.title < b.title
            end)
        end
        return entries
    else
        -- Load from KCData
        if KCData and KCData.entries and KCData.entries[sectionId] then
            return KCData.entries[sectionId]
        end
    end

    return {}
end

-- Count unread entries in a section
local function countUnreadInSection(sectionId)
    local entries = getEntriesForSection(sectionId)
    local count = 0
    for _, entry in ipairs(entries) do
        if isEntryUnread(entry.id) then
            count = count + 1
        end
    end
    return count
end

-- Search functionality
local function performSearch(query)
    if not query or query == "" then
        return nil
    end

    query = query:lower()
    local results = {}

    for _, section in ipairs(SECTIONS) do
        local entries = getEntriesForSection(section.id)
        for _, entry in ipairs(entries) do
            local score = 0
            local title = entry.title and entry.title:lower() or ""
            local content = entry.content and entry.content:lower() or ""

            -- Title match (highest priority)
            if title:find(query, 1, true) then
                score = score + 100
            end

            -- Tag match (medium priority)
            if entry.tags then
                for _, tag in ipairs(entry.tags) do
                    if tag:lower():find(query, 1, true) then
                        score = score + 50
                        break
                    end
                end
            end

            -- Content match (lowest priority)
            if content:find(query, 1, true) then
                score = score + 10
            end

            if score > 0 then
                table.insert(results, {
                    entry = entry,
                    section = section.id,
                    score = score,
                })
            end
        end
    end

    -- Sort by score descending
    table.sort(results, function(a, b) return a.score > b.score end)

    return results
end

-- Get filtered entries based on current state
local function getFilteredEntries()
    local searchText = state.searchInput and state.searchInput.text or ""

    -- If searching, return search results
    if searchText ~= "" then
        return performSearch(searchText)
    end

    -- Otherwise return section entries
    local entries = getEntriesForSection(state.currentSection)

    -- Apply letter filter for glossary
    if state.currentSection == "glossary" and state.selectedLetterFilter then
        local filtered = {}
        for _, entry in ipairs(entries) do
            local firstChar = entry.title:sub(1, 1):upper()
            if firstChar == state.selectedLetterFilter then
                table.insert(filtered, entry)
            end
        end
        return filtered
    end

    return entries
end

-- Parse and render content with cross-links
local function renderContent(content, x, y, w, maxH)
    if not content then return 0 end

    state.linkHitAreas = {}

    local font = UI.fonts.get(12)
    love.graphics.setFont(font)

    local lineHeight = font:getHeight() + 4
    local currentY = y
    local lines = {}

    -- Split content into lines
    for line in content:gmatch("[^\n]+") do
        table.insert(lines, line)
    end

    -- Render each line
    for _, line in ipairs(lines) do
        if currentY - y + lineHeight > maxH then
            break  -- Stop if we exceed max height
        end

        local currentX = x
        local segments = {}

        -- More robust parsing
        local pos = 1
        while pos <= #line do
            local linkStart, linkEnd, linkId, linkText = line:find("%[%[link:([^|]+)|([^%]]+)%]%]", pos)

            if linkStart then
                -- Add text before link
                if linkStart > pos then
                    local beforeText = line:sub(pos, linkStart - 1)
                    table.insert(segments, {type = "text", text = beforeText})
                end

                -- Add link
                table.insert(segments, {type = "link", text = linkText, id = linkId})
                pos = linkEnd + 1
            else
                -- Add remaining text
                local remainingText = line:sub(pos)
                if #remainingText > 0 then
                    table.insert(segments, {type = "text", text = remainingText})
                end
                break
            end
        end

        -- If no segments were created, treat entire line as text
        if #segments == 0 then
            table.insert(segments, {type = "text", text = line})
        end

        -- Render segments
        for _, segment in ipairs(segments) do
            if segment.type == "text" then
                love.graphics.setColor(UI.theme.colors.text)
                love.graphics.print(segment.text, currentX, currentY)
                currentX = currentX + font:getWidth(segment.text)
            elseif segment.type == "link" then
                love.graphics.setColor(colors.link)
                local textWidth = font:getWidth(segment.text)
                love.graphics.print(segment.text, currentX, currentY)

                -- Draw underline
                love.graphics.setLineWidth(1)
                love.graphics.line(currentX, currentY + lineHeight - 2, currentX + textWidth, currentY + lineHeight - 2)

                -- Store hit area
                table.insert(state.linkHitAreas, {
                    x = currentX,
                    y = currentY,
                    w = textWidth,
                    h = lineHeight,
                    id = segment.id,
                })

                currentX = currentX + textWidth
            end
        end

        currentY = currentY + lineHeight
    end

    return currentY - y
end

-- Create UI components
local function createUIComponents()
    local screenW, screenH = love.graphics.getDimensions()
    local panelW = 900
    local panelH = 650
    local panelX = (screenW - panelW) / 2
    local panelY = (screenH - panelH) / 2

    -- Main panel (we'll draw this manually for custom layout)
    state.mainPanel = {
        x = panelX,
        y = panelY,
        w = panelW,
        h = panelH,
    }

    -- Content area measurements
    local contentX = panelX + 60
    local contentY = panelY + 50
    local listW = 220
    local detailX = contentX + listW + 10
    local detailW = panelW - listW - 75
    local contentH = panelH - 65

    -- Search input
    local searchBarY = contentY + 5
    local searchBarX = contentX + 5
    local searchBarW = listW - 10

    state.searchInput = UI.TextInput.new({
        x = searchBarX,
        y = searchBarY,
        w = searchBarW,
        h = 30,
        placeholder = "Search...",
        text = "",
        onChange = function(text)
            -- Search happens automatically in getFilteredEntries
        end
    })

    -- Create letter filter buttons for glossary (A-Z)
    state.letterButtons = {}
    local letterW = 15
    local letterH = 18
    local letterFilterY = searchBarY + 35
    local letterX = contentX + 5
    local lettersPerRow = 13

    for i = 1, 26 do
        local letter = string.char(64 + i)  -- A-Z
        local col = (i - 1) % lettersPerRow
        local row = math.floor((i - 1) / lettersPerRow)

        local lx = letterX + col * (letterW + 2)
        local ly = letterFilterY + row * (letterH + 2)

        state.letterButtons[i] = {
            x = lx,
            y = ly,
            w = letterW,
            h = letterH,
            letter = letter,
        }
    end

    -- Create section tab buttons (vertical left side)
    state.sectionButtons = {}
    local tabX = panelX + 5
    local tabY = panelY + 50
    local tabW = 50
    local tabH = 65

    for i, section in ipairs(SECTIONS) do
        state.sectionButtons[i] = {
            section = section,
            x = tabX,
            y = tabY + (i - 1) * (tabH + 5),
            w = tabW,
            h = tabH,
        }
    end

    -- Entry list scroll container (we'll use custom rendering for the list items)
    local listStartY = searchBarY + 35
    local letterFilterVisible = (state.currentSection == "glossary" and state.searchInput.text == "")
    if letterFilterVisible then
        listStartY = listStartY + 42
    end
    local listHeight = contentY + contentH - listStartY - 5

    state.entryListScroll = UI.ScrollContainer.new({
        x = contentX,
        y = listStartY,
        w = listW,
        h = listHeight,
        contentHeight = 0,  -- Will be updated dynamically
    })

    -- Detail scroll container
    local contentStartY = contentY + 55
    local contentAreaH = contentH - 65

    state.detailScroll = UI.ScrollContainer.new({
        x = detailX,
        y = contentStartY,
        w = detailW,
        h = contentAreaH,
        contentHeight = 800,  -- Will be updated based on content
    })

    -- Replay button for tutorials (created on demand)
    state.replayButton = nil
end

-- Initialize
function KnowledgeCenter.init()
    ensurePlayerDataTables()
    state.active = true
    state.currentSection = "tutorials"
    state.currentEntry = nil
    state.selectedLetterFilter = nil
    state.linkHitAreas = {}

    createUIComponents()
end

-- Close
function KnowledgeCenter.close()
    state.active = false
    if state.searchInput then
        state.searchInput.focused = false
    end
end

-- Toggle
function KnowledgeCenter.toggle()
    if state.active then
        KnowledgeCenter.close()
    else
        KnowledgeCenter.init()
    end
end

function KnowledgeCenter.isActive()
    return state.active
end

-- Open to specific entry
function KnowledgeCenter.openToEntry(entryId)
    ensurePlayerDataTables()

    local section = findSectionForEntry(entryId)
    if not section then return end

    state.active = true
    state.currentSection = section
    state.selectedLetterFilter = nil

    createUIComponents()

    -- Find and select the entry
    local entries = getEntriesForSection(section)
    for _, entry in ipairs(entries) do
        if entry.id == entryId then
            state.currentEntry = entry
            state.detailScroll:scrollTo(0)
            markEntryAsRead(entryId)
            break
        end
    end
end

-- Mark entry as read (public API)
function KnowledgeCenter.markEntryRead(entryId)
    markEntryAsRead(entryId)
end

-- Update
function KnowledgeCenter.update(dt)
    if not state.active then return end

    -- Update UI components
    if state.searchInput then
        state.searchInput:update(dt)
    end

    if state.entryListScroll then
        -- Update content height based on filtered entries
        local entries = getFilteredEntries()
        local entryH = 35
        local totalEntries = 0

        -- Count visible entries (accounting for letter filter)
        for _, entryData in ipairs(entries) do
            local entry = (type(entryData.entry) == "table") and entryData.entry or entryData

            -- Filter by letter for glossary
            if state.currentSection == "glossary" and state.selectedLetterFilter then
                local firstChar = entry.title:sub(1, 1):upper()
                if firstChar == state.selectedLetterFilter then
                    totalEntries = totalEntries + 1
                end
            else
                totalEntries = totalEntries + 1
            end
        end

        state.entryListScroll.contentHeight = totalEntries * entryH
        state.entryListScroll:update(dt)
    end

    if state.detailScroll then
        state.detailScroll:update(dt)
    end

    if state.replayButton then
        state.replayButton:update(dt)
    end
end

-- Draw
function KnowledgeCenter.draw()
    if not state.active then return end

    local screenW, screenH = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()

    -- Full screen overlay
    love.graphics.setColor(0.06, 0.07, 0.10, 0.97)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    local panelX = state.mainPanel.x
    local panelY = state.mainPanel.y
    local panelW = state.mainPanel.w
    local panelH = state.mainPanel.h

    -- Panel background with border
    love.graphics.setColor(0.70, 0.55, 0.20)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", panelX - 2, panelY - 2, panelW + 4, panelH + 4, 12, 12)

    love.graphics.setColor(UI.theme.colors.panel)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 12, 12)

    -- Header bar
    love.graphics.setColor(0.12, 0.14, 0.22)
    love.graphics.rectangle("fill", panelX, panelY, panelW, 45, 12, 12)
    love.graphics.rectangle("fill", panelX, panelY + 30, panelW, 15)

    -- Title
    love.graphics.setColor(colors.gold)
    love.graphics.setFont(UI.fonts.get(22))
    love.graphics.print("Knowledge Center", panelX + 20, panelY + 10)

    -- Close button
    local closeBtnX = panelX + panelW - 50
    local closeBtnY = panelY + 8
    local closeBtnW = 35
    local closeBtnH = 30
    local closeHover = mx >= closeBtnX and mx <= closeBtnX + closeBtnW and my >= closeBtnY and my <= closeBtnY + closeBtnH

    love.graphics.setColor(closeHover and {0.8, 0.3, 0.3} or {0.5, 0.3, 0.3})
    love.graphics.rectangle("fill", closeBtnX, closeBtnY, closeBtnW, closeBtnH, 4, 4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.fonts.get(18))
    love.graphics.print("X", closeBtnX + 11, closeBtnY + 3)

    -- Draw vertical section tabs
    for i, btn in ipairs(state.sectionButtons) do
        local section = btn.section
        local isActive = state.currentSection == section.id
        local tabHover = mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h

        -- Tab background
        local bgColor
        if isActive then
            bgColor = {0.20, 0.25, 0.38}
        elseif tabHover then
            bgColor = {0.14, 0.16, 0.24}
        else
            bgColor = {0.08, 0.10, 0.15}
        end
        love.graphics.setColor(bgColor)
        love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 6, 6)

        -- Active tab highlight border
        if isActive then
            love.graphics.setColor(colors.gold)
            love.graphics.setLineWidth(2)
            love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 6, 6)
        end

        -- Icon letter
        love.graphics.setColor(isActive and colors.gold or UI.theme.colors.text)
        love.graphics.setFont(UI.fonts.get(20))
        local iconText = section.icon
        local iconW = UI.fonts.get(20):getWidth(iconText)
        love.graphics.print(iconText, btn.x + (btn.w - iconW) / 2, btn.y + 8)

        -- Section name
        love.graphics.setFont(UI.fonts.get(9))
        love.graphics.printf(section.name, btn.x, btn.y + 35, btn.w, "center")

        -- Unread badge
        local unreadCount = countUnreadInSection(section.id)
        if unreadCount > 0 then
            local badgeX = btn.x + btn.w - 16
            local badgeY = btn.y + 2
            love.graphics.setColor(colors.newBadge)
            love.graphics.circle("fill", badgeX, badgeY, 8)
            love.graphics.setColor(0, 0, 0)
            love.graphics.setFont(UI.fonts.get(10))
            local countText = tostring(unreadCount)
            if unreadCount > 9 then countText = "9+" end
            local countW = UI.fonts.get(10):getWidth(countText)
            love.graphics.print(countText, badgeX - countW / 2, badgeY - 6)
        end
    end

    -- Content area
    local contentX = panelX + 60
    local contentY = panelY + 50
    local listW = 220
    local detailX = contentX + listW + 10
    local detailW = panelW - listW - 75
    local contentH = panelH - 65

    -- Entry list panel background
    love.graphics.setColor(0.09, 0.10, 0.15)
    love.graphics.rectangle("fill", contentX, contentY, listW, contentH, 6, 6)

    -- Draw search input
    if state.searchInput then
        state.searchInput:draw()
    end

    -- Draw letter filter for glossary
    local letterFilterVisible = (state.currentSection == "glossary" and state.searchInput.text == "")
    if letterFilterVisible then
        for i, btn in ipairs(state.letterButtons) do
            local isSelected = state.selectedLetterFilter == btn.letter
            local letterHover = mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h

            local bgColor
            if isSelected then
                bgColor = colors.gold
            elseif letterHover then
                bgColor = {0.14, 0.16, 0.24}
            else
                bgColor = {0.08, 0.10, 0.15}
            end
            love.graphics.setColor(bgColor)
            love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 2, 2)

            love.graphics.setColor(isSelected and {0, 0, 0} or UI.theme.colors.text)
            love.graphics.setFont(UI.fonts.get(10))
            love.graphics.print(btn.letter, btn.x + 4, btn.y + 3)
        end
    end

    -- Draw entry list (with scrolling)
    local listStartY = state.searchInput.y + state.searchInput.h + 5
    if letterFilterVisible then
        listStartY = listStartY + 42
    end
    local listHeight = contentY + contentH - listStartY - 5

    -- Update scroll container position if needed
    state.entryListScroll.y = listStartY
    state.entryListScroll.h = listHeight

    love.graphics.setScissor(contentX, listStartY, listW, listHeight)

    local entries = getFilteredEntries()
    local entryY = listStartY - state.entryListScroll:getScroll()
    local entryH = 35

    for i, entryData in ipairs(entries) do
        local entry = (type(entryData.entry) == "table") and entryData.entry or entryData
        local sectionLabel = entryData.section or nil

        -- Filter by letter for glossary
        if state.currentSection == "glossary" and state.selectedLetterFilter then
            local firstChar = entry.title:sub(1, 1):upper()
            if firstChar ~= state.selectedLetterFilter then
                goto continue
            end
        end

        -- Check if entry is locked (bestiary discovery)
        local isLocked = false
        if state.currentSection == "bestiary" then
            if entry.discoverable and not isBestiaryDiscovered(entry.id) then
                isLocked = true
            end
        end

        if entryY + entryH >= listStartY and entryY < listStartY + listHeight then
            local isSelected = state.currentEntry and state.currentEntry.id == entry.id
            local entryHover = mx >= contentX and mx <= contentX + listW and my >= entryY and my <= entryY + entryH

            -- Alternating row shading
            local rowBg
            if isSelected then
                rowBg = colors.listSelected
            elseif entryHover then
                rowBg = colors.listHover
            elseif i % 2 == 0 then
                rowBg = colors.listAltRow
            else
                rowBg = {0.09, 0.10, 0.15}
            end

            love.graphics.setColor(rowBg)
            love.graphics.rectangle("fill", contentX + 2, entryY, listW - 4, entryH, 3, 3)

            -- Entry title
            local titleColor = isLocked and colors.locked or (isSelected and colors.gold or UI.theme.colors.text)
            love.graphics.setColor(titleColor)
            love.graphics.setFont(UI.fonts.get(12))
            local displayTitle = isLocked and "???" or entry.title
            love.graphics.print(displayTitle, contentX + 10, entryY + 8)

            -- Section label for search results
            if sectionLabel then
                love.graphics.setColor(UI.theme.colors.textDim)
                love.graphics.setFont(UI.fonts.get(9))
                love.graphics.print("[" .. sectionLabel .. "]", contentX + 10, entryY + 21)
            end

            -- NEW badge
            if isEntryUnread(entry.id) and not isLocked then
                local badgeX = contentX + listW - 45
                local badgeY = entryY + 8
                love.graphics.setColor(colors.newBadge)
                love.graphics.rectangle("fill", badgeX, badgeY, 35, 16, 3, 3)
                love.graphics.setColor(0, 0, 0)
                love.graphics.setFont(UI.fonts.get(10))
                love.graphics.print("NEW", badgeX + 4, badgeY + 2)
            end
        end

        entryY = entryY + entryH
        ::continue::
    end

    love.graphics.setScissor()

    -- Draw list scrollbar
    state.entryListScroll:draw()

    -- Detail panel background
    love.graphics.setColor(0.09, 0.10, 0.15)
    love.graphics.rectangle("fill", detailX, contentY, detailW, contentH, 6, 6)

    if state.currentEntry then
        local entry = state.currentEntry
        local isLocked = false

        -- Check if locked
        if state.currentSection == "bestiary" then
            if entry.discoverable and not isBestiaryDiscovered(entry.id) then
                isLocked = true
            end
        end

        if isLocked then
            -- Locked entry display
            love.graphics.setColor(colors.locked)
            love.graphics.setFont(UI.fonts.get(24))
            love.graphics.printf("???", detailX, contentY + 100, detailW, "center")
            love.graphics.setFont(UI.fonts.get(14))
            love.graphics.setColor(UI.theme.colors.textDim)
            love.graphics.printf("This entry has not been discovered yet.", detailX + 20, contentY + 150, detailW - 40, "center")
        else
            -- Entry title
            love.graphics.setColor(colors.gold)
            love.graphics.setFont(UI.fonts.get(20))
            love.graphics.print(entry.title, detailX + 15, contentY + 10)

            -- Tags
            if entry.tags and #entry.tags > 0 then
                love.graphics.setColor(UI.theme.colors.textDim)
                love.graphics.setFont(UI.fonts.get(10))
                love.graphics.print("Tags: " .. table.concat(entry.tags, ", "), detailX + 15, contentY + 38)
            end

            -- Completion status for tutorials
            if state.currentSection == "tutorials" and entry.modeId then
                local completed = Tutorials.hasCompleted and Tutorials.hasCompleted(entry.modeId)
                local statusX = detailX + detailW - 120
                local statusY = contentY + 10

                if completed then
                    love.graphics.setColor(UI.theme.colors.success)
                    love.graphics.setFont(UI.fonts.get(14))
                    love.graphics.print("✓ Completed", statusX, statusY)
                else
                    love.graphics.setColor(UI.theme.colors.textDim)
                    love.graphics.setFont(UI.fonts.get(14))
                    love.graphics.print("- Not Started", statusX, statusY)
                end

                -- Replay button
                if not state.replayButton then
                    state.replayButton = UI.Button.new({
                        x = 0,
                        y = 0,
                        w = 100,
                        h = 32,
                        text = "Replay",
                        variant = "primary",
                        onClick = function()
                            local modeId = state.currentEntry and state.currentEntry.modeId
                            if modeId and Tutorials.resetTutorial then
                                Tutorials.resetTutorial(modeId)
                            end
                            KnowledgeCenter.close()
                            if modeId and changeState then
                                changeState(modeId)
                            end
                        end
                    })
                end

                state.replayButton.x = detailX + detailW - 110
                state.replayButton.y = contentY + contentH - 45
                state.replayButton:draw()
            end

            -- Content with cross-links (scrollable)
            local contentStartY = contentY + 55
            local contentAreaH = contentH - 65

            if state.currentSection == "tutorials" then
                contentAreaH = contentAreaH - 45  -- Make room for replay button
            end

            -- Update detail scroll position
            state.detailScroll.y = contentStartY
            state.detailScroll.h = contentAreaH

            love.graphics.setScissor(detailX, contentStartY, detailW, contentAreaH)

            local renderedContentY = contentStartY - state.detailScroll:getScroll()
            renderContent(entry.content, detailX + 15, renderedContentY, detailW - 30, contentAreaH + state.detailScroll:getScroll())

            -- See also links (for glossary)
            if entry.seeAlso and #entry.seeAlso > 0 then
                -- Calculate content height based on rendered lines
                local contentLines = 0
                for _ in entry.content:gmatch("[^\n]+") do
                    contentLines = contentLines + 1
                end
                local lineHeight = UI.fonts.get(12):getHeight() + 4
                renderedContentY = contentStartY - state.detailScroll:getScroll() + contentLines * lineHeight + 20

                love.graphics.setColor(UI.theme.colors.textDim)
                love.graphics.setFont(UI.fonts.get(11))
                love.graphics.print("See also:", detailX + 15, renderedContentY)

                renderedContentY = renderedContentY + 18
                for _, seeAlsoId in ipairs(entry.seeAlso) do
                    love.graphics.setColor(colors.link)
                    love.graphics.print("• " .. seeAlsoId, detailX + 25, renderedContentY)

                    -- Store as clickable link
                    local linkW = UI.fonts.get(11):getWidth("• " .. seeAlsoId)
                    table.insert(state.linkHitAreas, {
                        x = detailX + 25,
                        y = renderedContentY,
                        w = linkW,
                        h = 15,
                        id = seeAlsoId,
                    })

                    renderedContentY = renderedContentY + 18
                end
            end

            love.graphics.setScissor()

            -- Draw detail scrollbar
            state.detailScroll:draw()
        end
    else
        -- No entry selected
        love.graphics.setColor(UI.theme.colors.textDim)
        love.graphics.setFont(UI.fonts.get(14))
        love.graphics.printf("Select an entry from the list to view details.", detailX + 20, contentY + 100, detailW - 40, "center")
    end

    -- Bottom hint bar
    love.graphics.setColor(0.12, 0.14, 0.22)
    love.graphics.rectangle("fill", panelX, panelY + panelH - 25, panelW, 25, 0, 0, 12, 12)

    love.graphics.setColor(UI.theme.colors.textDim)
    love.graphics.setFont(UI.fonts.get(10))
    love.graphics.print("Press [ESC] or [?] to close  •  Click entries to view  •  Click gold text for cross-links", panelX + 15, panelY + panelH - 18)

    love.graphics.setColor(1, 1, 1)
end

-- Mouse pressed
function KnowledgeCenter.mousepressed(x, y, button)
    if not state.active or button ~= 1 then return false end

    local panelX = state.mainPanel.x
    local panelY = state.mainPanel.y
    local panelW = state.mainPanel.w
    local panelH = state.mainPanel.h

    -- Close button
    local closeBtnX = panelX + panelW - 50
    local closeBtnY = panelY + 8
    local closeBtnW = 35
    local closeBtnH = 30
    if x >= closeBtnX and x <= closeBtnX + closeBtnW and y >= closeBtnY and y <= closeBtnY + closeBtnH then
        KnowledgeCenter.close()
        return true
    end

    -- Section tabs
    for _, btn in ipairs(state.sectionButtons) do
        if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
            state.currentSection = btn.section.id
            state.currentEntry = nil
            state.selectedLetterFilter = nil
            state.entryListScroll:scrollTo(0)
            state.detailScroll:scrollTo(0)
            return true
        end
    end

    -- Search input
    if state.searchInput and state.searchInput:mousepressed(x, y, button) then
        return true
    end

    -- Letter filter (glossary)
    local letterFilterVisible = (state.currentSection == "glossary" and state.searchInput.text == "")
    if letterFilterVisible then
        for _, btn in ipairs(state.letterButtons) do
            if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
                if state.selectedLetterFilter == btn.letter then
                    state.selectedLetterFilter = nil  -- Toggle off
                else
                    state.selectedLetterFilter = btn.letter
                end
                return true
            end
        end
    end

    -- Entry list clicks
    local contentX = panelX + 60
    local contentY = panelY + 50
    local listW = 220
    local listStartY = state.entryListScroll.y
    local listHeight = state.entryListScroll.h

    if x >= contentX and x <= contentX + listW and y >= listStartY and y <= listStartY + listHeight then
        -- Check scrollbar first
        if state.entryListScroll:mousepressed(x, y, button) then
            return true
        end

        local entries = getFilteredEntries()
        local entryY = listStartY - state.entryListScroll:getScroll()
        local entryH = 35

        for i, entryData in ipairs(entries) do
            local entry = (type(entryData.entry) == "table") and entryData.entry or entryData

            -- Filter by letter for glossary
            if state.currentSection == "glossary" and state.selectedLetterFilter then
                local firstChar = entry.title:sub(1, 1):upper()
                if firstChar ~= state.selectedLetterFilter then
                    goto continueClick
                end
            end

            if y >= entryY and y <= entryY + entryH then
                -- Check if locked
                local isLocked = false
                if state.currentSection == "bestiary" then
                    if entry.discoverable and not isBestiaryDiscovered(entry.id) then
                        isLocked = true
                    end
                end

                if not isLocked then
                    state.currentEntry = entry
                    state.detailScroll:scrollTo(0)
                    markEntryAsRead(entry.id)
                end
                return true
            end
            entryY = entryY + entryH
            ::continueClick::
        end
    end

    -- Detail scroll container
    if state.detailScroll:mousepressed(x, y, button) then
        return true
    end

    -- Cross-link clicks in detail panel
    for _, linkArea in ipairs(state.linkHitAreas) do
        if x >= linkArea.x and x <= linkArea.x + linkArea.w and y >= linkArea.y and y <= linkArea.y + linkArea.h then
            KnowledgeCenter.openToEntry(linkArea.id)
            return true
        end
    end

    -- Replay button for tutorials
    if state.replayButton and state.currentSection == "tutorials" and state.currentEntry then
        if state.replayButton:mousepressed(x, y, button) then
            return true
        end
    end

    return true  -- Capture all clicks while active
end

-- Mouse released
function KnowledgeCenter.mousereleased(x, y, button)
    if not state.active then return end

    if state.entryListScroll then
        state.entryListScroll:mousereleased(x, y, button)
    end

    if state.detailScroll then
        state.detailScroll:mousereleased(x, y, button)
    end

    if state.replayButton then
        state.replayButton:mousereleased(x, y, button)
    end
end

-- Mouse moved
function KnowledgeCenter.mousemoved(x, y, dx, dy)
    if not state.active then return end

    if state.entryListScroll and state.entryListScroll.mousemoved then
        state.entryListScroll:mousemoved(x, y, dx, dy)
    end

    if state.detailScroll and state.detailScroll.mousemoved then
        state.detailScroll:mousemoved(x, y, dx, dy)
    end
end

-- Key pressed
function KnowledgeCenter.keypressed(key)
    if not state.active then return false end

    if key == "escape" or key == "/" or key == "?" or key == "k" then
        KnowledgeCenter.close()
        return true
    end

    -- Pass to search input
    if state.searchInput and state.searchInput:keypressed(key) then
        return true
    end

    return true  -- Block input while active
end

-- Text input for search
function KnowledgeCenter.textinput(text)
    if not state.active then return false end

    if state.searchInput and state.searchInput:textinput(text) then
        return true
    end

    return false
end

-- Mouse wheel for scrolling
function KnowledgeCenter.wheelmoved(x, y)
    if not state.active then return false end

    local mx, my = love.mouse.getPosition()

    local contentX = state.mainPanel.x + 60
    local listW = 220
    local detailX = contentX + listW + 10
    local detailW = state.mainPanel.w - listW - 75

    -- Scroll entry list
    if mx >= contentX and mx <= contentX + listW then
        if state.entryListScroll then
            state.entryListScroll:wheelmoved(x, y)
        end
        return true
    end

    -- Scroll detail panel
    if mx >= detailX and mx <= detailX + detailW then
        if state.detailScroll then
            state.detailScroll:wheelmoved(x, y)
        end
        return true
    end

    return true
end

return KnowledgeCenter
