-- ==========================================================================
-- NPC Editor for Tavern Quest Editor Suite
-- Sub-tabs: General, Dialogue, Schedule, Stats, Shop
-- ==========================================================================

local Theme = require("core.theme")
local FontCache = require("core.fontcache")
local UI = require("core.ui")
local Undo = require("core.undo")
local Schema = require("core.data_schema")
local Search = require("core.search")
local IdGen = require("core.id_generator")
local AssetLoader = require("core.asset_loader")

-- =========================================================================
-- Helpers (local to this module)
-- =========================================================================

local function pointInRect(px, py, x, y, w, h)
    return px >= x and px < x + w and py >= y and py < y + h
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function setColor(c)
    if c and type(c) == "table" then
        love.graphics.setColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
    end
end

local function drawRoundedRect(mode, x, y, w, h, r)
    r = r or 0
    if w <= 0 or h <= 0 then return end
    if r <= 0 then
        love.graphics.rectangle(mode, x, y, w, h)
    else
        love.graphics.rectangle(mode, x, y, w, h, r, r)
    end
end

local function deepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[deepCopy(k)] = deepCopy(v)
    end
    return copy
end

-- =========================================================================
-- Profession list (same as data_schema / category_defs)
-- =========================================================================

local NPC_PROFESSIONS = {
    "shopkeeper", "blacksmith", "priest", "tavernkeep", "stablemaster",
    "alchemist", "wizard", "fisher", "hunter", "merchant", "butcher",
    "baker", "tailor", "jeweler", "wellkeeper", "land_commissioner",
}

local QUEST_TYPES = {
    "collect", "kill", "delivery", "donation", "escort", "puzzle", "boss",
}

local DIALOGUE_ACTIONS = {
    "shop", "chat", "quest", "trade", "train", "heal", "stable", "brew",
}

local LOCATION_TYPES = {
    {id = "work",   label = "Work",   color = {0.30, 0.50, 0.80}},
    {id = "tavern", label = "Tavern", color = {0.90, 0.65, 0.20}},
    {id = "home",   label = "Home",   color = {0.30, 0.80, 0.40}},
    {id = "market", label = "Market", color = {0.80, 0.40, 0.80}},
    {id = "church", label = "Church", color = {0.90, 0.90, 0.50}},
    {id = "patrol", label = "Patrol", color = {0.60, 0.30, 0.30}},
}

local DAY_NAMES = {"Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"}

-- =========================================================================
-- Default NPC Template
-- =========================================================================

local function createDefaultNPC()
    return {
        profession = "shopkeeper",
        names = {"Harold"},
        sprite = "S",
        portrait = "Human/Men_Human/Merchant",
        dialogue = {
            greeting = "Welcome to my shop!",
            options = {
                {text = "Browse wares", action = "shop", responses = {}},
                {text = "Chat", action = "chat", responses = {
                    "Business has been good.",
                    "Let me know if you need anything!",
                }},
            },
        },
        schedule = {
            workDays = {1, 2, 3, 4, 5, 6},
            schedule = {
                {startHour = 8,  endHour = 18, location = {type = "building", id = "work"}},
                {startHour = 18, endHour = 22, location = {type = "building", id = "tavern"}},
                {startHour = 22, endHour = 8,  location = {type = "building", id = "home"}},
            },
            dayOffSchedule = {
                {startHour = 8,  endHour = 20, location = {type = "building", id = "tavern"}},
                {startHour = 20, endHour = 8,  location = {type = "building", id = "home"}},
            },
        },
        stats = {hp = 50, atk = 5, def = 3, mana = 20},
        shopItems = {},
    }
end

-- =========================================================================
-- Editor Constructor
-- =========================================================================

local Editor = {}

function Editor.new(project)
    local self = setmetatable({}, {__index = Editor})

    self.project = project or {npcs = {}}
    if not self.project.npcs then
        self.project.npcs = {}
    end

    -- Undo system
    self.undoStack = Undo.new(80)

    -- Selected NPC index in filtered list
    self.selectedIndex = nil
    -- Currently selected NPC data reference (points into project.npcs)
    self.selectedNPC = nil

    -- Search / filter state
    self.searchText = ""
    self.filterProfession = nil -- nil = "All"
    self.filteredList = {}

    -- Sub-tab state
    self.subTab = "general"
    self.subTabs = {
        {id = "general",   label = "General"},
        {id = "dialogue",  label = "Dialogue"},
        {id = "schedule",  label = "Schedule"},
        {id = "stats",     label = "Stats"},
        {id = "shop",      label = "Shop"},
    }

    -- Scroll state for each panel
    self.leftScroll = UI.ScrollContainer.new({contentHeight = 0})
    self.centerScroll = UI.ScrollContainer.new({contentHeight = 0})
    self.rightScroll = UI.ScrollContainer.new({contentHeight = 0})

    -- Widget instances
    self.searchInput = UI.TextInput.new({
        placeholder = "Search NPCs...",
        onChange = function(text)
            self.searchText = text
            self:_rebuildFilteredList()
        end,
    })

    -- Profession filter dropdown state
    self.profFilterOpen = false
    self.profFilterRect = {x = 0, y = 0, w = 0, h = 0}
    self.profFilterDropdownRects = {}

    -- Buttons
    self.addBtn = UI.Button.new({
        text = "+ Add", variant = "primary", fontSize = 12,
        onClick = function() self:_addNPC() end,
    })
    self.deleteBtn = UI.Button.new({
        text = "Delete", variant = "danger", fontSize = 12,
        onClick = function() self:_deleteNPC() end,
    })
    self.dupBtn = UI.Button.new({
        text = "Duplicate", variant = "secondary", fontSize = 12,
        onClick = function() self:_duplicateNPC() end,
    })

    -- NPC list widget
    self.npcList = UI.List.new({
        items = {},
        onSelect = function(idx, item)
            self:_selectNPC(idx)
        end,
    })

    -- Sub-tab bar widget
    self.subTabBar = UI.TabBar.new({
        tabs = self.subTabs,
        activeTab = "general",
        onTabChange = function(id)
            self.subTab = id
            self.centerScroll:scrollToTop()
        end,
    })

    -- General tab inputs
    self.professionDropdownOpen = false
    self.professionDropdownRect = {x = 0, y = 0, w = 0, h = 0}
    self.professionDropdownRects = {}
    self.spriteInput = UI.TextInput.new({
        placeholder = "Sprite character...",
        maxLength = 4,
        onChange = function(text)
            if self.selectedNPC then self.selectedNPC.sprite = text end
        end,
    })
    self.portraitInput = UI.TextInput.new({
        placeholder = "Portrait path...",
        onChange = function(text)
            if self.selectedNPC then self.selectedNPC.portrait = text end
        end,
    })
    self.nameTagInput = UI.TextInput.new({
        placeholder = "Type name, press Enter to add...",
        onSubmit = function(text)
            if self.selectedNPC and text ~= "" then
                table.insert(self.selectedNPC.names, text)
                self.nameTagInput:setText("")
            end
        end,
    })

    -- Dialogue tab state
    self.dialogueGreetingInput = UI.TextInput.new({
        placeholder = "Greeting text...",
        onChange = function(text)
            if self.selectedNPC and self.selectedNPC.dialogue then
                self.selectedNPC.dialogue.greeting = text
            end
        end,
    })
    self.selectedDialogueOption = nil
    self.selectedDialogueResponse = nil
    self.dialogueOptionTextInput = UI.TextInput.new({
        placeholder = "Option text...",
        onChange = function(text)
            if self.selectedNPC and self.selectedDialogueOption then
                local opt = self.selectedNPC.dialogue.options[self.selectedDialogueOption]
                if opt then opt.text = text end
            end
        end,
    })
    self.dialogueResponseInput = UI.TextInput.new({
        placeholder = "Type response, press Enter...",
        onSubmit = function(text)
            if self.selectedNPC and self.selectedDialogueOption and text ~= "" then
                local opt = self.selectedNPC.dialogue.options[self.selectedDialogueOption]
                if opt then
                    if not opt.responses then opt.responses = {} end
                    table.insert(opt.responses, text)
                    self.dialogueResponseInput:setText("")
                end
            end
        end,
    })
    self.dialogueActionDropdownOpen = false
    self.dialogueActionDropdownRect = {x = 0, y = 0, w = 0, h = 0}
    self.dialogueActionDropdownRects = {}

    -- Stats tab sliders
    self.statSliders = {
        hp   = UI.Slider.new({label = "HP",   min = 1, max = 500, step = 1, value = 50}),
        atk  = UI.Slider.new({label = "ATK",  min = 0, max = 100, step = 1, value = 5}),
        def  = UI.Slider.new({label = "DEF",  min = 0, max = 100, step = 1, value = 3}),
        mana = UI.Slider.new({label = "Mana", min = 0, max = 500, step = 1, value = 20}),
    }
    -- Wire up slider callbacks
    self.statSliders.hp.onChange   = function(v) if self.selectedNPC then self.selectedNPC.stats.hp   = math.floor(v) end end
    self.statSliders.atk.onChange  = function(v) if self.selectedNPC then self.selectedNPC.stats.atk  = math.floor(v) end end
    self.statSliders.def.onChange  = function(v) if self.selectedNPC then self.selectedNPC.stats.def  = math.floor(v) end end
    self.statSliders.mana.onChange = function(v) if self.selectedNPC then self.selectedNPC.stats.mana = math.floor(v) end end

    -- Schedule tab state
    self.scheduleEditMode = "workday" -- "workday" or "dayoff"
    self.scheduleSelectedLocation = 1 -- index into LOCATION_TYPES

    -- Shop tab state
    self.shopItemInput = UI.TextInput.new({
        placeholder = "Item ID to add...",
        onSubmit = function(text)
            if self.selectedNPC and text ~= "" then
                table.insert(self.selectedNPC.shopItems, {id = text, stock = -1})
                self.shopItemInput:setText("")
            end
        end,
    })

    -- Cache for layout rects (avoids re-creation each frame)
    self._layoutCache = {}

    -- Build filtered list
    self:_rebuildFilteredList()

    return self
end

-- =========================================================================
-- Filtered list management
-- =========================================================================

function Editor:_rebuildFilteredList()
    local npcs = self.project.npcs
    local results = {}

    for i, npc in ipairs(npcs) do
        local passSearch = true
        local passFilter = true

        -- Text search
        if self.searchText ~= "" then
            local lower = string.lower(self.searchText)
            local match = false
            if npc.profession and string.find(string.lower(npc.profession), lower, 1, true) then
                match = true
            end
            if not match and npc.names then
                for _, name in ipairs(npc.names) do
                    if string.find(string.lower(name), lower, 1, true) then
                        match = true
                        break
                    end
                end
            end
            passSearch = match
        end

        -- Profession filter
        if self.filterProfession then
            passFilter = (npc.profession == self.filterProfession)
        end

        if passSearch and passFilter then
            table.insert(results, {
                index = i,
                npc = npc,
                text = (npc.names and npc.names[1] or "Unnamed") .. " (" .. (npc.profession or "?") .. ")",
                id = i,
            })
        end
    end

    self.filteredList = results

    -- Update list widget
    self.npcList:setItems(results)

    -- Try to preserve selection
    if self.selectedNPC then
        local found = false
        for fi, entry in ipairs(results) do
            if entry.npc == self.selectedNPC then
                self.npcList:setSelectedIndex(fi)
                self.selectedIndex = fi
                found = true
                break
            end
        end
        if not found then
            self.selectedIndex = nil
            self.selectedNPC = nil
        end
    end
end

function Editor:_selectNPC(filteredIdx)
    if filteredIdx and self.filteredList[filteredIdx] then
        self.selectedIndex = filteredIdx
        self.selectedNPC = self.filteredList[filteredIdx].npc
        self:_syncWidgetsToNPC()
    else
        self.selectedIndex = nil
        self.selectedNPC = nil
    end
end

function Editor:_syncWidgetsToNPC()
    local npc = self.selectedNPC
    if not npc then return end

    self.spriteInput:setText(npc.sprite or "")
    self.portraitInput:setText(npc.portrait or "")

    if npc.dialogue then
        self.dialogueGreetingInput:setText(npc.dialogue.greeting or "")
    end

    if npc.stats then
        self.statSliders.hp:setValue(npc.stats.hp or 50)
        self.statSliders.atk:setValue(npc.stats.atk or 5)
        self.statSliders.def:setValue(npc.stats.def or 3)
        self.statSliders.mana:setValue(npc.stats.mana or 20)
    end

    self.selectedDialogueOption = nil
    self.selectedDialogueResponse = nil
    self.centerScroll:scrollToTop()
end

-- =========================================================================
-- Add / Delete / Duplicate
-- =========================================================================

function Editor:_addNPC()
    local npc = createDefaultNPC()
    table.insert(self.project.npcs, npc)
    self:_rebuildFilteredList()
    -- Select the new NPC
    for fi, entry in ipairs(self.filteredList) do
        if entry.npc == npc then
            self.npcList:setSelectedIndex(fi)
            self:_selectNPC(fi)
            break
        end
    end
end

function Editor:_deleteNPC()
    if not self.selectedNPC then return end
    for i, npc in ipairs(self.project.npcs) do
        if npc == self.selectedNPC then
            table.remove(self.project.npcs, i)
            break
        end
    end
    self.selectedNPC = nil
    self.selectedIndex = nil
    self:_rebuildFilteredList()
end

function Editor:_duplicateNPC()
    if not self.selectedNPC then return end
    local copy = deepCopy(self.selectedNPC)
    if copy.names and #copy.names > 0 then
        copy.names[1] = copy.names[1] .. " (Copy)"
    end
    table.insert(self.project.npcs, copy)
    self:_rebuildFilteredList()
    for fi, entry in ipairs(self.filteredList) do
        if entry.npc == copy then
            self.npcList:setSelectedIndex(fi)
            self:_selectNPC(fi)
            break
        end
    end
end

-- =========================================================================
-- Update
-- =========================================================================

function Editor:update(dt)
    self.searchInput:update(dt)
    self.spriteInput:update(dt)
    self.portraitInput:update(dt)
    self.nameTagInput:update(dt)
    self.dialogueGreetingInput:update(dt)
    self.dialogueOptionTextInput:update(dt)
    self.dialogueResponseInput:update(dt)
    self.shopItemInput:update(dt)

    for _, slider in pairs(self.statSliders) do
        slider:update(dt)
    end
end

-- =========================================================================
-- Drawing
-- =========================================================================

function Editor:draw(x, y, w, h)
    local leftW = 260
    local rightW = 200
    local centerW = w - leftW - rightW - 8  -- 4px divider each side

    -- Left panel background
    setColor(Theme.colors.panel)
    love.graphics.rectangle("fill", x, y, leftW, h)
    setColor(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", x + leftW, y, 1, h)

    -- Right panel background
    setColor(Theme.colors.panel)
    love.graphics.rectangle("fill", x + w - rightW, y, rightW, h)
    setColor(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", x + w - rightW - 1, y, 1, h)

    -- Center background
    setColor(Theme.colors.bg)
    love.graphics.rectangle("fill", x + leftW + 4, y, centerW, h)

    self:_drawLeftPanel(x, y, leftW, h)
    self:_drawCenterPanel(x + leftW + 4, y, centerW, h)
    self:_drawRightPanel(x + w - rightW, y, rightW, h)

    -- Draw dropdown overlays last (on top of everything)
    self:_drawDropdowns()
end

-- =========================================================================
-- Left Panel: Search, Filter, NPC List, Buttons
-- =========================================================================

function Editor:_drawLeftPanel(x, y, w, h)
    local pad = Theme.spacing.md
    local cy = y + pad

    -- Title
    local titleFont = FontCache.get(15)
    love.graphics.setFont(titleFont)
    setColor(Theme.colors.textAccent)
    love.graphics.print("NPC Templates", x + pad, cy)
    cy = cy + titleFont:getHeight() + pad

    -- Search bar
    self.searchInput:draw(x + pad, cy, w - pad * 2, Theme.sizes.inputHeight)
    cy = cy + Theme.sizes.inputHeight + pad

    -- Profession filter dropdown trigger
    local filterH = Theme.sizes.inputHeight
    local filterLabel = self.filterProfession or "All Professions"
    self.profFilterRect = {x = x + pad, y = cy, w = w - pad * 2, h = filterH}

    local mx, my = love.mouse.getPosition()
    local filterHovered = pointInRect(mx, my, x + pad, cy, w - pad * 2, filterH)

    setColor(filterHovered and Theme.colors.listItemHover or Theme.colors.input)
    drawRoundedRect("fill", x + pad, cy, w - pad * 2, filterH, Theme.radius.sm)
    setColor(self.profFilterOpen and Theme.colors.inputFocus or Theme.colors.inputBorder)
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", x + pad + 0.5, cy + 0.5, w - pad * 2 - 1, filterH - 1, Theme.radius.sm)

    local filterFont = FontCache.get(12)
    love.graphics.setFont(filterFont)
    setColor(Theme.colors.text)
    local ftY = cy + math.floor((filterH - filterFont:getHeight()) / 2)
    love.graphics.print(filterLabel, x + pad + Theme.spacing.md, ftY)
    -- Dropdown arrow
    setColor(Theme.colors.textDim)
    love.graphics.print("v", x + w - pad - 16, ftY)

    cy = cy + filterH + pad

    -- NPC list
    local btnAreaH = Theme.sizes.buttonHeight + pad
    local listH = h - (cy - y) - btnAreaH - pad
    if listH < 20 then listH = 20 end

    self.npcList:draw(x + pad, cy, w - pad * 2, listH)
    cy = cy + listH + pad

    -- Buttons row
    local btnW = math.floor((w - pad * 4) / 3)
    local btnH = Theme.sizes.buttonHeight
    self.addBtn:draw(x + pad, cy, btnW, btnH)
    self.dupBtn:draw(x + pad + btnW + pad, cy, btnW, btnH)
    self.deleteBtn:draw(x + pad + (btnW + pad) * 2, cy, btnW, btnH)
end

-- =========================================================================
-- Center Panel: Sub-tab bar + content
-- =========================================================================

function Editor:_drawCenterPanel(x, y, w, h)
    if w < 10 or h < 10 then return end

    -- Sub-tab bar
    local tabH = Theme.sizes.tabBarHeight
    self.subTabBar:draw(x, y, w, tabH)

    local contentY = y + tabH
    local contentH = h - tabH
    if contentH < 10 then return end

    -- Clip and draw sub-tab content
    love.graphics.setScissor(x, contentY, w, contentH)

    if not self.selectedNPC then
        local font = FontCache.get(14)
        love.graphics.setFont(font)
        setColor(Theme.colors.textDim)
        love.graphics.printf("Select or create an NPC template", x, contentY + 40, w, "center")
    elseif self.subTab == "general" then
        self:_drawGeneralTab(x, contentY, w, contentH)
    elseif self.subTab == "dialogue" then
        self:_drawDialogueTab(x, contentY, w, contentH)
    elseif self.subTab == "schedule" then
        self:_drawScheduleTab(x, contentY, w, contentH)
    elseif self.subTab == "stats" then
        self:_drawStatsTab(x, contentY, w, contentH)
    elseif self.subTab == "shop" then
        self:_drawShopTab(x, contentY, w, contentH)
    end

    love.graphics.setScissor()
end

-- =========================================================================
-- General Sub-Tab
-- =========================================================================

function Editor:_drawGeneralTab(x, y, w, h)
    local pad = Theme.spacing.lg
    local labelW = 120
    local inputW = w - pad * 2 - labelW - pad
    if inputW < 80 then inputW = 80 end
    local rowH = Theme.sizes.inputHeight + Theme.spacing.md
    local cy = y + pad
    local font = FontCache.get(13)
    love.graphics.setFont(font)
    local textH = font:getHeight()

    -- Section header helper
    local function sectionHeader(text)
        setColor(Theme.colors.textAccent)
        local hFont = FontCache.get(14)
        love.graphics.setFont(hFont)
        love.graphics.print(text, x + pad, cy)
        cy = cy + hFont:getHeight() + Theme.spacing.sm
        setColor(Theme.colors.panelBorder)
        love.graphics.rectangle("fill", x + pad, cy, w - pad * 2, 1)
        cy = cy + Theme.spacing.md
        love.graphics.setFont(font)
    end

    -- Row helper
    local function labelRow(label)
        setColor(Theme.colors.text)
        love.graphics.print(label, x + pad, cy + math.floor((Theme.sizes.inputHeight - textH) / 2))
    end

    local npc = self.selectedNPC

    sectionHeader("Identity")

    -- Profession dropdown
    labelRow("Profession")
    local profFieldX = x + pad + labelW + pad
    local profFieldW = inputW
    local profFieldH = Theme.sizes.inputHeight

    self.professionDropdownRect = {x = profFieldX, y = cy, w = profFieldW, h = profFieldH}
    local mx, my = love.mouse.getPosition()
    local profHover = pointInRect(mx, my, profFieldX, cy, profFieldW, profFieldH)

    setColor(profHover and Theme.colors.listItemHover or Theme.colors.input)
    drawRoundedRect("fill", profFieldX, cy, profFieldW, profFieldH, Theme.radius.sm)
    setColor(self.professionDropdownOpen and Theme.colors.inputFocus or Theme.colors.inputBorder)
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", profFieldX + 0.5, cy + 0.5, profFieldW - 1, profFieldH - 1, Theme.radius.sm)
    setColor(Theme.colors.text)
    love.graphics.print(npc.profession or "select...", profFieldX + Theme.spacing.md, cy + math.floor((profFieldH - textH) / 2))
    setColor(Theme.colors.textDim)
    love.graphics.print("v", profFieldX + profFieldW - 16, cy + math.floor((profFieldH - textH) / 2))
    cy = cy + rowH

    -- Sprite
    labelRow("Sprite")
    self.spriteInput:draw(x + pad + labelW + pad, cy, inputW, Theme.sizes.inputHeight)
    cy = cy + rowH

    -- Portrait
    labelRow("Portrait")
    self.portraitInput:draw(x + pad + labelW + pad, cy, inputW, Theme.sizes.inputHeight)
    cy = cy + rowH

    sectionHeader("Names")

    -- Name tags display
    if npc.names then
        local tagX = x + pad
        local tagY = cy
        local tagFont = FontCache.get(12)
        love.graphics.setFont(tagFont)
        local tagH = 22
        local tagPad = 6

        for i, name in ipairs(npc.names) do
            local tw = tagFont:getWidth(name) + tagPad * 2 + 16 -- extra for X button
            if tagX + tw > x + w - pad then
                tagX = x + pad
                tagY = tagY + tagH + 4
            end

            -- Tag background
            setColor(Theme.colors.listItemSelected)
            drawRoundedRect("fill", tagX, tagY, tw, tagH, Theme.radius.sm)

            -- Tag text
            setColor(Theme.colors.text)
            love.graphics.print(name, tagX + tagPad, tagY + math.floor((tagH - tagFont:getHeight()) / 2))

            -- X button
            setColor(Theme.colors.textDim)
            love.graphics.print("x", tagX + tw - 14, tagY + math.floor((tagH - tagFont:getHeight()) / 2))

            -- Store rect for click removal
            self._layoutCache["nametag_" .. i] = {x = tagX + tw - 16, y = tagY, w = 16, h = tagH, idx = i}

            tagX = tagX + tw + 4
        end

        cy = tagY + tagH + Theme.spacing.md
    end

    love.graphics.setFont(font)

    -- Name input
    self.nameTagInput:draw(x + pad, cy, w - pad * 2, Theme.sizes.inputHeight)
    cy = cy + rowH

    self.centerScroll:setContentHeight(cy - y + pad)
end

-- =========================================================================
-- Dialogue Sub-Tab
-- =========================================================================

function Editor:_drawDialogueTab(x, y, w, h)
    local pad = Theme.spacing.lg
    local font = FontCache.get(13)
    love.graphics.setFont(font)
    local textH = font:getHeight()
    local cy = y + pad
    local npc = self.selectedNPC
    if not npc or not npc.dialogue then return end

    -- Section: Greeting
    setColor(Theme.colors.textAccent)
    local hFont = FontCache.get(14)
    love.graphics.setFont(hFont)
    love.graphics.print("Greeting", x + pad, cy)
    cy = cy + hFont:getHeight() + Theme.spacing.sm
    love.graphics.setFont(font)

    self.dialogueGreetingInput:draw(x + pad, cy, w - pad * 2, Theme.sizes.inputHeight)
    cy = cy + Theme.sizes.inputHeight + Theme.spacing.lg

    -- Section: Dialogue Options Tree
    setColor(Theme.colors.textAccent)
    love.graphics.setFont(hFont)
    love.graphics.print("Dialogue Options", x + pad, cy)
    cy = cy + hFont:getHeight() + Theme.spacing.sm

    -- Add option button
    local addOptBtnW = 90
    local addOptBtnH = 22
    local addOptRect = {x = x + w - pad - addOptBtnW, y = cy - hFont:getHeight() - Theme.spacing.sm, w = addOptBtnW, h = addOptBtnH}
    self._layoutCache["addDialogueOpt"] = addOptRect
    local mx, my = love.mouse.getPosition()
    local addOptHover = pointInRect(mx, my, addOptRect.x, addOptRect.y, addOptRect.w, addOptRect.h)
    setColor(addOptHover and Theme.colors.primaryHover or Theme.colors.primary)
    drawRoundedRect("fill", addOptRect.x, addOptRect.y, addOptRect.w, addOptRect.h, Theme.radius.sm)
    local addOptFont = FontCache.get(11)
    love.graphics.setFont(addOptFont)
    setColor(Theme.colors.bg)
    love.graphics.printf("+ Add Option", addOptRect.x, addOptRect.y + 3, addOptRect.w, "center")
    love.graphics.setFont(font)

    setColor(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", x + pad, cy, w - pad * 2, 1)
    cy = cy + Theme.spacing.sm

    -- Draw each option
    local options = npc.dialogue.options or {}
    for i, opt in ipairs(options) do
        local isSelected = (i == self.selectedDialogueOption)
        local optH = 30
        local optX = x + pad
        local optW = w - pad * 2

        -- Option row background
        if isSelected then
            setColor(Theme.colors.listItemSelected)
        else
            local optHover = pointInRect(mx, my, optX, cy, optW, optH)
            if optHover then
                setColor(Theme.colors.listItemHover)
            else
                setColor(i % 2 == 0 and Theme.colors.listItemAlt or Theme.colors.listItem)
            end
        end
        drawRoundedRect("fill", optX, cy, optW, optH, 2)

        -- Option text
        setColor(Theme.colors.text)
        love.graphics.print((opt.text or ""), optX + 8, cy + math.floor((optH - textH) / 2))

        -- Action badge
        local actionStr = "[" .. (opt.action or "?") .. "]"
        setColor(Theme.colors.secondary)
        love.graphics.print(actionStr, optX + optW - font:getWidth(actionStr) - 30, cy + math.floor((optH - textH) / 2))

        -- Delete X
        setColor(Theme.colors.danger)
        love.graphics.print("x", optX + optW - 14, cy + math.floor((optH - textH) / 2))
        self._layoutCache["delDialogueOpt_" .. i] = {x = optX + optW - 20, y = cy, w = 20, h = optH, idx = i}

        -- Store option row rect for click selection
        self._layoutCache["dialogueOpt_" .. i] = {x = optX, y = cy, w = optW - 20, h = optH, idx = i}

        cy = cy + optH + 2

        -- If selected, show edit fields below
        if isSelected then
            local editBg = {Theme.colors.bgLight[1], Theme.colors.bgLight[2], Theme.colors.bgLight[3], 0.6}
            setColor(editBg)
            local editH = 120
            if opt.responses and #opt.responses > 0 then
                editH = editH + #opt.responses * 24 + 8
            end
            drawRoundedRect("fill", optX + 16, cy, optW - 32, editH, Theme.radius.sm)

            local ecy = cy + Theme.spacing.sm
            local ePad = 24

            -- Option text edit
            setColor(Theme.colors.textDim)
            love.graphics.print("Text:", optX + ePad, ecy + 3)
            self.dialogueOptionTextInput:setText(opt.text or "")
            self.dialogueOptionTextInput:draw(optX + ePad + 50, ecy, optW - 80 - ePad, Theme.sizes.inputHeight)
            ecy = ecy + Theme.sizes.inputHeight + Theme.spacing.sm

            -- Action select
            setColor(Theme.colors.textDim)
            love.graphics.print("Action:", optX + ePad, ecy + 3)
            local actFieldX = optX + ePad + 50
            local actFieldW = optW - 80 - ePad
            local actFieldH = Theme.sizes.inputHeight

            self.dialogueActionDropdownRect = {x = actFieldX, y = ecy, w = actFieldW, h = actFieldH}
            local actHover = pointInRect(mx, my, actFieldX, ecy, actFieldW, actFieldH)
            setColor(actHover and Theme.colors.listItemHover or Theme.colors.input)
            drawRoundedRect("fill", actFieldX, ecy, actFieldW, actFieldH, Theme.radius.sm)
            setColor(Theme.colors.inputBorder)
            love.graphics.setLineWidth(1)
            drawRoundedRect("line", actFieldX + 0.5, ecy + 0.5, actFieldW - 1, actFieldH - 1, Theme.radius.sm)
            setColor(Theme.colors.text)
            love.graphics.print(opt.action or "select...", actFieldX + 6, ecy + 3)
            ecy = ecy + actFieldH + Theme.spacing.sm

            -- Responses list
            if opt.action == "chat" or (opt.responses and #opt.responses > 0) then
                setColor(Theme.colors.textDim)
                love.graphics.print("Responses:", optX + ePad, ecy + 2)
                ecy = ecy + textH + 4

                local respFont = FontCache.get(12)
                love.graphics.setFont(respFont)
                if opt.responses then
                    for ri, resp in ipairs(opt.responses) do
                        setColor(Theme.colors.text)
                        local respText = "  " .. ri .. ". " .. resp
                        love.graphics.print(respText, optX + ePad, ecy)

                        -- Delete response X
                        setColor(Theme.colors.danger)
                        love.graphics.print("x", optX + optW - 48, ecy)
                        self._layoutCache["delResp_" .. i .. "_" .. ri] = {
                            x = optX + optW - 52, y = ecy - 2, w = 20, h = 18,
                            optIdx = i, respIdx = ri,
                        }
                        ecy = ecy + 20
                    end
                end
                love.graphics.setFont(font)

                -- Add response input
                self.dialogueResponseInput:draw(optX + ePad, ecy, optW - 80 - ePad, Theme.sizes.inputHeight)
                ecy = ecy + Theme.sizes.inputHeight + Theme.spacing.sm
            end

            cy = cy + editH + 4
        end
    end

    self.centerScroll:setContentHeight(cy - y + pad * 2)
end

-- =========================================================================
-- Schedule Sub-Tab
-- =========================================================================

function Editor:_drawScheduleTab(x, y, w, h)
    local pad = Theme.spacing.lg
    local font = FontCache.get(12)
    love.graphics.setFont(font)
    local textH = font:getHeight()
    local cy = y + pad
    local npc = self.selectedNPC
    if not npc or not npc.schedule then return end

    local mx, my = love.mouse.getPosition()

    -- Mode toggle: Work Days vs Day Off
    local modeFont = FontCache.get(13)
    love.graphics.setFont(modeFont)

    local modes = {{id = "workday", label = "Work Day Schedule"}, {id = "dayoff", label = "Day Off Schedule"}}
    local modeX = x + pad
    for _, mode in ipairs(modes) do
        local modeW = modeFont:getWidth(mode.label) + 24
        local modeH = 26
        local isActive = (self.scheduleEditMode == mode.id)
        local modeHover = pointInRect(mx, my, modeX, cy, modeW, modeH)

        if isActive then
            setColor(Theme.colors.primary)
        elseif modeHover then
            setColor(Theme.colors.tabHover)
        else
            setColor(Theme.colors.tabInactive)
        end
        drawRoundedRect("fill", modeX, cy, modeW, modeH, Theme.radius.sm)

        setColor(isActive and Theme.colors.bg or Theme.colors.text)
        love.graphics.print(mode.label, modeX + 12, cy + math.floor((modeH - modeFont:getHeight()) / 2))

        self._layoutCache["schedMode_" .. mode.id] = {x = modeX, y = cy, w = modeW, h = modeH}
        modeX = modeX + modeW + 8
    end
    cy = cy + 30 + pad

    love.graphics.setFont(font)

    -- Get the relevant schedule
    local scheduleEntries
    if self.scheduleEditMode == "workday" then
        scheduleEntries = npc.schedule.schedule or {}
    else
        scheduleEntries = npc.schedule.dayOffSchedule or {}
    end

    -- Work days indicator (only for workday mode)
    if self.scheduleEditMode == "workday" then
        setColor(Theme.colors.textDim)
        love.graphics.print("Work Days:", x + pad, cy)
        local wdX = x + pad + font:getWidth("Work Days:") + 8
        local workDays = npc.schedule.workDays or {}
        local wdSet = {}
        for _, d in ipairs(workDays) do wdSet[d] = true end

        for d = 1, 7 do
            local dayW = 30
            local dayH = 20
            local dayActive = wdSet[d]
            local dayHover = pointInRect(mx, my, wdX, cy, dayW, dayH)

            if dayActive then
                setColor(Theme.colors.primary)
            elseif dayHover then
                setColor(Theme.colors.tabHover)
            else
                setColor(Theme.colors.tabInactive)
            end
            drawRoundedRect("fill", wdX, cy, dayW, dayH, 2)

            setColor(dayActive and Theme.colors.bg or Theme.colors.textDim)
            local dayLabel = DAY_NAMES[d] or tostring(d)
            love.graphics.printf(dayLabel, wdX, cy + 3, dayW, "center")

            self._layoutCache["workDay_" .. d] = {x = wdX, y = cy, w = dayW, h = dayH, day = d}
            wdX = wdX + dayW + 4
        end
        cy = cy + 28 + pad
    end

    -- Visual 24-hour grid
    setColor(Theme.colors.textAccent)
    local hFont = FontCache.get(13)
    love.graphics.setFont(hFont)
    love.graphics.print("24-Hour Schedule Grid", x + pad, cy)
    cy = cy + hFont:getHeight() + Theme.spacing.sm
    love.graphics.setFont(font)

    local gridX = x + pad + 40  -- leave room for hour labels
    local gridW = w - pad * 2 - 40
    local cellH = 18
    local gridH = 24 * cellH

    -- Hour labels
    for hour = 0, 23 do
        setColor(Theme.colors.textDim)
        love.graphics.printf(string.format("%02d:00", hour), x + pad, cy + hour * cellH + 2, 38, "right")
    end

    -- Draw grid cells
    for hour = 0, 23 do
        local cellY = cy + hour * cellH
        local cellW = gridW

        -- Determine location at this hour
        local locId = nil
        for _, entry in ipairs(scheduleEntries) do
            local sH = entry.startHour or 0
            local eH = entry.endHour or 0
            if sH < eH then
                -- Normal range (e.g. 8-18)
                if hour >= sH and hour < eH then
                    locId = entry.location and entry.location.id
                    break
                end
            else
                -- Wrapping range (e.g. 22-8)
                if hour >= sH or hour < eH then
                    locId = entry.location and entry.location.id
                    break
                end
            end
        end

        -- Find location color
        local cellColor = Theme.colors.bgLight
        for _, loc in ipairs(LOCATION_TYPES) do
            if loc.id == locId then
                cellColor = loc.color
                break
            end
        end

        setColor(cellColor)
        love.graphics.rectangle("fill", gridX, cellY, cellW, cellH - 1)

        -- Grid line
        setColor(Theme.colors.panelBorder)
        love.graphics.rectangle("fill", gridX, cellY + cellH - 1, cellW, 1)

        -- Location label in cell
        if locId then
            setColor({0, 0, 0, 0.7})
            love.graphics.printf(locId, gridX + 4, cellY + 2, cellW - 8, "left")
        end

        self._layoutCache["schedCell_" .. hour] = {x = gridX, y = cellY, w = cellW, h = cellH, hour = hour}
    end

    -- Border around grid
    setColor(Theme.colors.panelBorder)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", gridX, cy, gridW, gridH)

    cy = cy + gridH + pad

    -- Legend
    setColor(Theme.colors.textDim)
    love.graphics.print("Location Colors:", x + pad, cy)
    cy = cy + textH + 4

    local legendX = x + pad
    for _, loc in ipairs(LOCATION_TYPES) do
        setColor(loc.color)
        love.graphics.rectangle("fill", legendX, cy, 14, 14)
        setColor(Theme.colors.text)
        love.graphics.print(loc.label, legendX + 18, cy)
        legendX = legendX + font:getWidth(loc.label) + 36
        if legendX > x + w - 60 then
            legendX = x + pad
            cy = cy + 20
        end
    end
    cy = cy + 24 + pad

    -- Location picker for painting
    setColor(Theme.colors.textDim)
    love.graphics.print("Paint location (click grid cells):", x + pad, cy)
    cy = cy + textH + 6

    for li, loc in ipairs(LOCATION_TYPES) do
        local locBtnW = font:getWidth(loc.label) + 20
        local locBtnH = 22
        local isSelLoc = (li == self.scheduleSelectedLocation)
        local locBtnHover = pointInRect(mx, my, x + pad, cy, locBtnW, locBtnH)

        if isSelLoc then
            setColor(loc.color)
        elseif locBtnHover then
            setColor(Theme.colors.tabHover)
        else
            setColor(Theme.colors.tabInactive)
        end
        drawRoundedRect("fill", x + pad, cy, locBtnW, locBtnH, 2)

        setColor(isSelLoc and {0, 0, 0} or Theme.colors.text)
        love.graphics.print(loc.label, x + pad + 10, cy + 3)

        self._layoutCache["locBtn_" .. li] = {x = x + pad, y = cy, w = locBtnW, h = locBtnH, idx = li}
        cy = cy + locBtnH + 4
    end

    self.centerScroll:setContentHeight(cy - y + pad * 2)
end

-- =========================================================================
-- Stats Sub-Tab
-- =========================================================================

function Editor:_drawStatsTab(x, y, w, h)
    local pad = Theme.spacing.xl
    local cy = y + pad
    local npc = self.selectedNPC
    if not npc or not npc.stats then return end

    local hFont = FontCache.get(14)
    love.graphics.setFont(hFont)
    setColor(Theme.colors.textAccent)
    love.graphics.print("NPC Statistics", x + pad, cy)
    cy = cy + hFont:getHeight() + Theme.spacing.md

    setColor(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", x + pad, cy, w - pad * 2, 1)
    cy = cy + Theme.spacing.lg

    local sliderW = math.min(w - pad * 2, 400)
    local sliderH = 48

    -- Sync sliders to current NPC values before drawing
    self.statSliders.hp:setValue(npc.stats.hp or 50)
    self.statSliders.atk:setValue(npc.stats.atk or 5)
    self.statSliders.def:setValue(npc.stats.def or 3)
    self.statSliders.mana:setValue(npc.stats.mana or 20)

    local sliderOrder = {"hp", "atk", "def", "mana"}
    for _, key in ipairs(sliderOrder) do
        self.statSliders[key]:draw(x + pad, cy, sliderW, sliderH)
        cy = cy + sliderH + Theme.spacing.lg
    end

    -- Stat summary box
    cy = cy + Theme.spacing.lg
    setColor(Theme.colors.bgLight)
    drawRoundedRect("fill", x + pad, cy, sliderW, 80, Theme.radius.md)
    setColor(Theme.colors.panelBorder)
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", x + pad + 0.5, cy + 0.5, sliderW - 1, 79, Theme.radius.md)

    local font = FontCache.get(13)
    love.graphics.setFont(font)
    setColor(Theme.colors.textDim)
    love.graphics.print("Stat Summary", x + pad + 10, cy + 8)
    setColor(Theme.colors.text)
    local sumY = cy + 28
    love.graphics.print(string.format("HP: %d   ATK: %d   DEF: %d   Mana: %d",
        npc.stats.hp or 0, npc.stats.atk or 0, npc.stats.def or 0, npc.stats.mana or 0),
        x + pad + 10, sumY)
    local effectiveStr = string.format("Effective Health: ~%d (with DEF)",
        math.floor((npc.stats.hp or 0) * (1 + (npc.stats.def or 0) * 0.05)))
    setColor(Theme.colors.textDim)
    love.graphics.print(effectiveStr, x + pad + 10, sumY + 20)

    cy = cy + 100
    self.centerScroll:setContentHeight(cy - y + pad)
end

-- =========================================================================
-- Shop Sub-Tab
-- =========================================================================

function Editor:_drawShopTab(x, y, w, h)
    local pad = Theme.spacing.lg
    local font = FontCache.get(13)
    love.graphics.setFont(font)
    local textH = font:getHeight()
    local cy = y + pad
    local npc = self.selectedNPC
    if not npc then return end
    if not npc.shopItems then npc.shopItems = {} end

    local mx, my = love.mouse.getPosition()

    local hFont = FontCache.get(14)
    love.graphics.setFont(hFont)
    setColor(Theme.colors.textAccent)
    love.graphics.print("Shop Inventory", x + pad, cy)
    cy = cy + hFont:getHeight() + Theme.spacing.md
    love.graphics.setFont(font)

    -- Add item input
    setColor(Theme.colors.textDim)
    love.graphics.print("Add item ID:", x + pad, cy + 3)
    self.shopItemInput:draw(x + pad + 90, cy, w - pad * 2 - 90, Theme.sizes.inputHeight)
    cy = cy + Theme.sizes.inputHeight + Theme.spacing.lg

    setColor(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", x + pad, cy, w - pad * 2, 1)
    cy = cy + Theme.spacing.md

    -- Column headers
    setColor(Theme.colors.textDim)
    love.graphics.print("#", x + pad, cy)
    love.graphics.print("Item ID", x + pad + 30, cy)
    love.graphics.print("Stock", x + pad + 250, cy)
    love.graphics.print("Remove", x + w - pad - 50, cy)
    cy = cy + textH + 4

    setColor(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", x + pad, cy, w - pad * 2, 1)
    cy = cy + 4

    -- Items list
    for i, item in ipairs(npc.shopItems) do
        local rowH = 28
        local rowHover = pointInRect(mx, my, x + pad, cy, w - pad * 2, rowH)

        if rowHover then
            setColor(Theme.colors.listItemHover)
        elseif i % 2 == 0 then
            setColor(Theme.colors.listItemAlt)
        else
            setColor(Theme.colors.listItem)
        end
        drawRoundedRect("fill", x + pad, cy, w - pad * 2, rowH, 2)

        setColor(Theme.colors.textDim)
        love.graphics.print(tostring(i), x + pad + 4, cy + math.floor((rowH - textH) / 2))

        setColor(Theme.colors.text)
        love.graphics.print(item.id or "?", x + pad + 30, cy + math.floor((rowH - textH) / 2))

        local stockStr = item.stock == -1 and "Unlimited" or tostring(item.stock or 0)
        setColor(Theme.colors.textDim)
        love.graphics.print(stockStr, x + pad + 250, cy + math.floor((rowH - textH) / 2))

        -- Remove button
        setColor(Theme.colors.danger)
        love.graphics.print("x", x + w - pad - 36, cy + math.floor((rowH - textH) / 2))
        self._layoutCache["shopDel_" .. i] = {x = x + w - pad - 44, y = cy, w = 24, h = rowH, idx = i}

        cy = cy + rowH + 2
    end

    if #npc.shopItems == 0 then
        setColor(Theme.colors.textDim)
        love.graphics.printf("No items in shop. Type an item ID above and press Enter.",
            x + pad, cy + 20, w - pad * 2, "center")
        cy = cy + 60
    end

    self.centerScroll:setContentHeight(cy - y + pad * 2)
end

-- =========================================================================
-- Right Panel: Portrait preview, profession info
-- =========================================================================

function Editor:_drawRightPanel(x, y, w, h)
    local pad = Theme.spacing.md
    local cy = y + pad
    local font = FontCache.get(12)
    love.graphics.setFont(font)
    local npc = self.selectedNPC

    -- Title
    local titleFont = FontCache.get(13)
    love.graphics.setFont(titleFont)
    setColor(Theme.colors.textAccent)
    love.graphics.print("Preview", x + pad, cy)
    cy = cy + titleFont:getHeight() + pad
    love.graphics.setFont(font)

    if not npc then
        setColor(Theme.colors.textDim)
        love.graphics.printf("No NPC selected", x + pad, cy + 20, w - pad * 2, "center")
        return
    end

    -- Portrait preview
    local portraitSize = math.min(w - pad * 2, 160)
    local portraitX = x + math.floor((w - portraitSize) / 2)

    setColor(Theme.colors.bgLight)
    drawRoundedRect("fill", portraitX, cy, portraitSize, portraitSize, Theme.radius.md)
    setColor(Theme.colors.panelBorder)
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", portraitX + 0.5, cy + 0.5, portraitSize - 1, portraitSize - 1, Theme.radius.md)

    -- Try to load and draw portrait
    if npc.portrait and npc.portrait ~= "" then
        local img = AssetLoader.loadPortrait(npc.portrait)
        if img then
            local iw, ih = img:getDimensions()
            local scale = math.min((portraitSize - 8) / iw, (portraitSize - 8) / ih)
            local drawX = portraitX + math.floor((portraitSize - iw * scale) / 2)
            local drawY = cy + math.floor((portraitSize - ih * scale) / 2)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(img, drawX, drawY, 0, scale, scale)
        else
            setColor(Theme.colors.textDim)
            love.graphics.printf("No portrait", portraitX, cy + portraitSize / 2 - 6, portraitSize, "center")
        end
    else
        -- Draw sprite character large
        if npc.sprite and npc.sprite ~= "" then
            local bigFont = FontCache.get(48)
            love.graphics.setFont(bigFont)
            setColor(Theme.colors.text)
            love.graphics.printf(npc.sprite, portraitX, cy + math.floor((portraitSize - bigFont:getHeight()) / 2), portraitSize, "center")
            love.graphics.setFont(font)
        else
            setColor(Theme.colors.textDim)
            love.graphics.printf("No portrait", portraitX, cy + portraitSize / 2 - 6, portraitSize, "center")
        end
    end

    cy = cy + portraitSize + pad

    -- Profession info
    setColor(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", x + pad, cy, w - pad * 2, 1)
    cy = cy + Theme.spacing.md

    setColor(Theme.colors.textDim)
    love.graphics.print("Profession:", x + pad, cy)
    cy = cy + font:getHeight() + 2
    setColor(Theme.colors.text)
    love.graphics.print(npc.profession or "none", x + pad, cy)
    cy = cy + font:getHeight() + Theme.spacing.md

    setColor(Theme.colors.textDim)
    love.graphics.print("Names:", x + pad, cy)
    cy = cy + font:getHeight() + 2
    if npc.names then
        for _, name in ipairs(npc.names) do
            setColor(Theme.colors.text)
            love.graphics.print("  " .. name, x + pad, cy)
            cy = cy + font:getHeight() + 1
        end
    end
    cy = cy + Theme.spacing.md

    setColor(Theme.colors.textDim)
    love.graphics.print("Sprite:", x + pad, cy)
    setColor(Theme.colors.text)
    love.graphics.print(npc.sprite or "none", x + pad + 50, cy)
    cy = cy + font:getHeight() + Theme.spacing.md

    -- Stats summary
    if npc.stats then
        setColor(Theme.colors.panelBorder)
        love.graphics.rectangle("fill", x + pad, cy, w - pad * 2, 1)
        cy = cy + Theme.spacing.md

        setColor(Theme.colors.textDim)
        love.graphics.print("Stats:", x + pad, cy)
        cy = cy + font:getHeight() + 2

        local statLabels = {
            {key = "hp",   label = "HP",   color = Theme.colors.success},
            {key = "atk",  label = "ATK",  color = Theme.colors.danger},
            {key = "def",  label = "DEF",  color = Theme.colors.secondary},
            {key = "mana", label = "Mana", color = Theme.colors.info},
        }
        for _, s in ipairs(statLabels) do
            setColor(s.color)
            love.graphics.print(s.label .. ":", x + pad + 4, cy)
            setColor(Theme.colors.text)
            love.graphics.print(tostring(npc.stats[s.key] or 0), x + pad + 50, cy)
            cy = cy + font:getHeight() + 1
        end
    end

    cy = cy + Theme.spacing.md

    -- Shop count
    if npc.shopItems then
        setColor(Theme.colors.textDim)
        love.graphics.print("Shop Items: " .. #npc.shopItems, x + pad, cy)
    end
end

-- =========================================================================
-- Dropdown Overlays (drawn on top of everything)
-- =========================================================================

function Editor:_drawDropdowns()
    local font = FontCache.get(12)
    love.graphics.setFont(font)
    local textH = font:getHeight()
    local mx, my = love.mouse.getPosition()

    -- Profession filter dropdown
    if self.profFilterOpen then
        local r = self.profFilterRect
        local items = {"All Professions"}
        for _, p in ipairs(NPC_PROFESSIONS) do
            table.insert(items, p)
        end
        local dropH = #items * 24
        local dropY = r.y + r.h

        setColor(Theme.colors.panel)
        drawRoundedRect("fill", r.x, dropY, r.w, dropH, Theme.radius.sm)
        setColor(Theme.colors.panelBorder)
        love.graphics.setLineWidth(1)
        drawRoundedRect("line", r.x + 0.5, dropY + 0.5, r.w - 1, dropH - 1, Theme.radius.sm)

        self.profFilterDropdownRects = {}
        for i, item in ipairs(items) do
            local iy = dropY + (i - 1) * 24
            local hovered = pointInRect(mx, my, r.x, iy, r.w, 24)
            if hovered then
                setColor(Theme.colors.listItemHover)
                love.graphics.rectangle("fill", r.x + 1, iy, r.w - 2, 24)
            end
            setColor(Theme.colors.text)
            love.graphics.print(item, r.x + 8, iy + math.floor((24 - textH) / 2))
            self.profFilterDropdownRects[i] = {x = r.x, y = iy, w = r.w, h = 24, value = (i == 1) and nil or item}
        end
    end

    -- Profession dropdown (General tab)
    if self.professionDropdownOpen then
        local r = self.professionDropdownRect
        local dropH = #NPC_PROFESSIONS * 24
        local dropY = r.y + r.h

        setColor(Theme.colors.panel)
        drawRoundedRect("fill", r.x, dropY, r.w, dropH, Theme.radius.sm)
        setColor(Theme.colors.panelBorder)
        love.graphics.setLineWidth(1)
        drawRoundedRect("line", r.x + 0.5, dropY + 0.5, r.w - 1, dropH - 1, Theme.radius.sm)

        self.professionDropdownRects = {}
        for i, prof in ipairs(NPC_PROFESSIONS) do
            local iy = dropY + (i - 1) * 24
            local hovered = pointInRect(mx, my, r.x, iy, r.w, 24)
            if hovered then
                setColor(Theme.colors.listItemHover)
                love.graphics.rectangle("fill", r.x + 1, iy, r.w - 2, 24)
            end
            setColor(Theme.colors.text)
            love.graphics.print(prof, r.x + 8, iy + math.floor((24 - textH) / 2))
            self.professionDropdownRects[i] = {x = r.x, y = iy, w = r.w, h = 24, value = prof}
        end
    end

    -- Dialogue action dropdown
    if self.dialogueActionDropdownOpen and self.selectedDialogueOption then
        local r = self.dialogueActionDropdownRect
        local dropH = #DIALOGUE_ACTIONS * 24
        local dropY = r.y + r.h

        setColor(Theme.colors.panel)
        drawRoundedRect("fill", r.x, dropY, r.w, dropH, Theme.radius.sm)
        setColor(Theme.colors.panelBorder)
        love.graphics.setLineWidth(1)
        drawRoundedRect("line", r.x + 0.5, dropY + 0.5, r.w - 1, dropH - 1, Theme.radius.sm)

        self.dialogueActionDropdownRects = {}
        for i, action in ipairs(DIALOGUE_ACTIONS) do
            local iy = dropY + (i - 1) * 24
            local hovered = pointInRect(mx, my, r.x, iy, r.w, 24)
            if hovered then
                setColor(Theme.colors.listItemHover)
                love.graphics.rectangle("fill", r.x + 1, iy, r.w - 2, 24)
            end
            setColor(Theme.colors.text)
            love.graphics.print(action, r.x + 8, iy + math.floor((24 - textH) / 2))
            self.dialogueActionDropdownRects[i] = {x = r.x, y = iy, w = r.w, h = 24, value = action}
        end
    end
end

-- =========================================================================
-- Mouse Input
-- =========================================================================

function Editor:mousepressed(mx, my, button)
    if button ~= 1 then return false end

    -- Check dropdowns first (they overlay everything)
    if self.profFilterOpen then
        for _, rect in ipairs(self.profFilterDropdownRects) do
            if pointInRect(mx, my, rect.x, rect.y, rect.w, rect.h) then
                self.filterProfession = rect.value
                self.profFilterOpen = false
                self:_rebuildFilteredList()
                return true
            end
        end
        self.profFilterOpen = false
        return true
    end

    if self.professionDropdownOpen then
        for _, rect in ipairs(self.professionDropdownRects) do
            if pointInRect(mx, my, rect.x, rect.y, rect.w, rect.h) then
                if self.selectedNPC then
                    self.selectedNPC.profession = rect.value
                    self:_rebuildFilteredList()
                end
                self.professionDropdownOpen = false
                return true
            end
        end
        self.professionDropdownOpen = false
        return true
    end

    if self.dialogueActionDropdownOpen then
        for _, rect in ipairs(self.dialogueActionDropdownRects) do
            if pointInRect(mx, my, rect.x, rect.y, rect.w, rect.h) then
                if self.selectedNPC and self.selectedDialogueOption then
                    local opt = self.selectedNPC.dialogue.options[self.selectedDialogueOption]
                    if opt then opt.action = rect.value end
                end
                self.dialogueActionDropdownOpen = false
                return true
            end
        end
        self.dialogueActionDropdownOpen = false
        return true
    end

    -- Profession filter trigger
    local pfr = self.profFilterRect
    if pointInRect(mx, my, pfr.x, pfr.y, pfr.w, pfr.h) then
        self.profFilterOpen = not self.profFilterOpen
        return true
    end

    -- Search input
    if self.searchInput:mousepressed(mx, my, button) then return true end

    -- NPC list
    if self.npcList:mousepressed(mx, my, button) then return true end

    -- Buttons
    if self.addBtn:mousepressed(mx, my, button) then return true end
    if self.deleteBtn:mousepressed(mx, my, button) then return true end
    if self.dupBtn:mousepressed(mx, my, button) then return true end

    -- Sub-tab bar
    if self.subTabBar:mousepressed(mx, my, button) then return true end

    -- Center panel interactions (depends on sub-tab)
    if self.selectedNPC then
        if self.subTab == "general" then
            -- Profession dropdown trigger
            local pdr = self.professionDropdownRect
            if pointInRect(mx, my, pdr.x, pdr.y, pdr.w, pdr.h) then
                self.professionDropdownOpen = not self.professionDropdownOpen
                return true
            end

            if self.spriteInput:mousepressed(mx, my, button) then return true end
            if self.portraitInput:mousepressed(mx, my, button) then return true end
            if self.nameTagInput:mousepressed(mx, my, button) then return true end

            -- Name tag removal
            for key, rect in pairs(self._layoutCache) do
                if type(key) == "string" and key:match("^nametag_") and rect.idx then
                    if pointInRect(mx, my, rect.x, rect.y, rect.w, rect.h) then
                        if self.selectedNPC and self.selectedNPC.names then
                            table.remove(self.selectedNPC.names, rect.idx)
                        end
                        return true
                    end
                end
            end

        elseif self.subTab == "dialogue" then
            if self.dialogueGreetingInput:mousepressed(mx, my, button) then return true end
            if self.dialogueOptionTextInput:mousepressed(mx, my, button) then return true end
            if self.dialogueResponseInput:mousepressed(mx, my, button) then return true end

            -- Action dropdown trigger
            local adr = self.dialogueActionDropdownRect
            if self.selectedDialogueOption and pointInRect(mx, my, adr.x, adr.y, adr.w, adr.h) then
                self.dialogueActionDropdownOpen = not self.dialogueActionDropdownOpen
                return true
            end

            -- Add dialogue option button
            local addOptR = self._layoutCache["addDialogueOpt"]
            if addOptR and pointInRect(mx, my, addOptR.x, addOptR.y, addOptR.w, addOptR.h) then
                if self.selectedNPC and self.selectedNPC.dialogue then
                    table.insert(self.selectedNPC.dialogue.options, {
                        text = "New Option",
                        action = "chat",
                        responses = {},
                    })
                end
                return true
            end

            -- Dialogue option selection and deletion
            for key, rect in pairs(self._layoutCache) do
                if type(key) == "string" then
                    if key:match("^delDialogueOpt_") and rect.idx then
                        if pointInRect(mx, my, rect.x, rect.y, rect.w, rect.h) then
                            if self.selectedNPC and self.selectedNPC.dialogue and self.selectedNPC.dialogue.options then
                                table.remove(self.selectedNPC.dialogue.options, rect.idx)
                                if self.selectedDialogueOption == rect.idx then
                                    self.selectedDialogueOption = nil
                                end
                            end
                            return true
                        end
                    elseif key:match("^dialogueOpt_") and rect.idx then
                        if pointInRect(mx, my, rect.x, rect.y, rect.w, rect.h) then
                            if self.selectedDialogueOption == rect.idx then
                                self.selectedDialogueOption = nil
                            else
                                self.selectedDialogueOption = rect.idx
                            end
                            return true
                        end
                    elseif key:match("^delResp_") and rect.optIdx and rect.respIdx then
                        if pointInRect(mx, my, rect.x, rect.y, rect.w, rect.h) then
                            if self.selectedNPC and self.selectedNPC.dialogue then
                                local opt = self.selectedNPC.dialogue.options[rect.optIdx]
                                if opt and opt.responses then
                                    table.remove(opt.responses, rect.respIdx)
                                end
                            end
                            return true
                        end
                    end
                end
            end

        elseif self.subTab == "schedule" then
            -- Schedule mode toggle
            for _, modeId in ipairs({"workday", "dayoff"}) do
                local rect = self._layoutCache["schedMode_" .. modeId]
                if rect and pointInRect(mx, my, rect.x, rect.y, rect.w, rect.h) then
                    self.scheduleEditMode = modeId
                    return true
                end
            end

            -- Work day toggles
            for d = 1, 7 do
                local rect = self._layoutCache["workDay_" .. d]
                if rect and pointInRect(mx, my, rect.x, rect.y, rect.w, rect.h) then
                    local workDays = self.selectedNPC.schedule.workDays or {}
                    local found = false
                    for i, wd in ipairs(workDays) do
                        if wd == d then
                            table.remove(workDays, i)
                            found = true
                            break
                        end
                    end
                    if not found then
                        table.insert(workDays, d)
                        table.sort(workDays)
                    end
                    self.selectedNPC.schedule.workDays = workDays
                    return true
                end
            end

            -- Location picker buttons
            for li = 1, #LOCATION_TYPES do
                local rect = self._layoutCache["locBtn_" .. li]
                if rect and pointInRect(mx, my, rect.x, rect.y, rect.w, rect.h) then
                    self.scheduleSelectedLocation = li
                    return true
                end
            end

            -- Schedule grid cells - paint location
            for hour = 0, 23 do
                local rect = self._layoutCache["schedCell_" .. hour]
                if rect and pointInRect(mx, my, rect.x, rect.y, rect.w, rect.h) then
                    self:_paintScheduleHour(hour)
                    return true
                end
            end

        elseif self.subTab == "stats" then
            for _, slider in pairs(self.statSliders) do
                if slider:mousepressed(mx, my, button) then return true end
            end

        elseif self.subTab == "shop" then
            if self.shopItemInput:mousepressed(mx, my, button) then return true end

            -- Shop item deletion
            for key, rect in pairs(self._layoutCache) do
                if type(key) == "string" and key:match("^shopDel_") and rect.idx then
                    if pointInRect(mx, my, rect.x, rect.y, rect.w, rect.h) then
                        if self.selectedNPC and self.selectedNPC.shopItems then
                            table.remove(self.selectedNPC.shopItems, rect.idx)
                        end
                        return true
                    end
                end
            end
        end
    end

    -- Scroll containers
    if self.leftScroll:mousepressed(mx, my, button) then return true end
    if self.centerScroll:mousepressed(mx, my, button) then return true end
    if self.rightScroll:mousepressed(mx, my, button) then return true end

    return false
end

function Editor:mousereleased(mx, my, button)
    if button ~= 1 then return false end

    self.addBtn:mousereleased(mx, my, button)
    self.deleteBtn:mousereleased(mx, my, button)
    self.dupBtn:mousereleased(mx, my, button)
    self.npcList:mousereleased(mx, my, button)

    for _, slider in pairs(self.statSliders) do
        slider:mousereleased(mx, my, button)
    end

    self.leftScroll:mousereleased(mx, my, button)
    self.centerScroll:mousereleased(mx, my, button)
    self.rightScroll:mousereleased(mx, my, button)

    return false
end

function Editor:wheelmoved(wx, wy)
    if self.npcList:wheelmoved(wx, wy) then return true end
    if self.leftScroll:wheelmoved(wx, wy) then return true end
    if self.centerScroll:wheelmoved(wx, wy) then return true end
    if self.rightScroll:wheelmoved(wx, wy) then return true end
    return false
end

function Editor:keypressed(key)
    -- Delegate to focused input
    if self.searchInput:keypressed(key) then return true end
    if self.spriteInput:keypressed(key) then return true end
    if self.portraitInput:keypressed(key) then return true end
    if self.nameTagInput:keypressed(key) then return true end
    if self.dialogueGreetingInput:keypressed(key) then return true end
    if self.dialogueOptionTextInput:keypressed(key) then return true end
    if self.dialogueResponseInput:keypressed(key) then return true end
    if self.shopItemInput:keypressed(key) then return true end

    -- Undo/Redo
    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
    if ctrl and key == "z" then
        self.undoStack:undo()
        self:_rebuildFilteredList()
        return true
    end
    if ctrl and key == "y" then
        self.undoStack:redo()
        self:_rebuildFilteredList()
        return true
    end

    -- Delete selected NPC
    if key == "delete" and self.selectedNPC then
        self:_deleteNPC()
        return true
    end

    return false
end

function Editor:textinput(t)
    if self.searchInput:textinput(t) then return true end
    if self.spriteInput:textinput(t) then return true end
    if self.portraitInput:textinput(t) then return true end
    if self.nameTagInput:textinput(t) then return true end
    if self.dialogueGreetingInput:textinput(t) then return true end
    if self.dialogueOptionTextInput:textinput(t) then return true end
    if self.dialogueResponseInput:textinput(t) then return true end
    if self.shopItemInput:textinput(t) then return true end
    return false
end

-- =========================================================================
-- Schedule painting helper
-- =========================================================================

function Editor:_paintScheduleHour(hour)
    local npc = self.selectedNPC
    if not npc or not npc.schedule then return end

    local locType = LOCATION_TYPES[self.scheduleSelectedLocation]
    if not locType then return end

    local entries
    if self.scheduleEditMode == "workday" then
        entries = npc.schedule.schedule
        if not entries then
            entries = {}
            npc.schedule.schedule = entries
        end
    else
        entries = npc.schedule.dayOffSchedule
        if not entries then
            entries = {}
            npc.schedule.dayOffSchedule = entries
        end
    end

    -- Remove existing entries that contain this hour
    local newEntries = {}
    for _, entry in ipairs(entries) do
        local sH = entry.startHour or 0
        local eH = entry.endHour or 0
        local containsHour = false
        if sH < eH then
            containsHour = (hour >= sH and hour < eH)
        else
            containsHour = (hour >= sH or hour < eH)
        end

        if containsHour then
            -- Split entry around this hour
            if sH < eH then
                if sH < hour then
                    table.insert(newEntries, {startHour = sH, endHour = hour, location = deepCopy(entry.location)})
                end
                if hour + 1 < eH then
                    table.insert(newEntries, {startHour = hour + 1, endHour = eH, location = deepCopy(entry.location)})
                end
            else
                -- Wrap-around case: split more carefully
                if hour >= sH then
                    if sH < hour then
                        table.insert(newEntries, {startHour = sH, endHour = hour, location = deepCopy(entry.location)})
                    end
                    if hour + 1 <= 23 then
                        -- second segment wraps from hour+1 through eH
                        table.insert(newEntries, {startHour = hour + 1, endHour = eH, location = deepCopy(entry.location)})
                    elseif eH > 0 then
                        table.insert(newEntries, {startHour = 0, endHour = eH, location = deepCopy(entry.location)})
                    end
                else
                    -- hour < eH part
                    if sH <= 23 then
                        table.insert(newEntries, {startHour = sH, endHour = 24, location = deepCopy(entry.location)})
                    end
                    if hour > 0 then
                        table.insert(newEntries, {startHour = 0, endHour = hour, location = deepCopy(entry.location)})
                    end
                    if hour + 1 < eH then
                        table.insert(newEntries, {startHour = hour + 1, endHour = eH, location = deepCopy(entry.location)})
                    end
                end
            end
        else
            table.insert(newEntries, entry)
        end
    end

    -- Add the new single-hour entry
    table.insert(newEntries, {
        startHour = hour,
        endHour = (hour + 1) % 24,
        location = {type = "building", id = locType.id},
    })

    if self.scheduleEditMode == "workday" then
        npc.schedule.schedule = newEntries
    else
        npc.schedule.dayOffSchedule = newEntries
    end
end

return Editor
