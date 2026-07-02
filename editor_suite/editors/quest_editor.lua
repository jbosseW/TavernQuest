-- ==========================================================================
-- Quest Editor for Tavern Quest Editor Suite
-- Sections: Basic Info, Objectives, Requirements, Rewards, Repeat
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
-- Shared data definitions
-- =========================================================================

local QUEST_TYPES = {
    "collect", "kill", "delivery", "donation", "escort", "puzzle", "boss",
}

local NPC_PROFESSIONS = {
    "shopkeeper", "blacksmith", "priest", "tavernkeep", "stablemaster",
    "alchemist", "wizard", "fisher", "hunter", "merchant", "butcher",
    "baker", "tailor", "jeweler", "wellkeeper", "land_commissioner",
}

local OBJECTIVE_TYPES = {
    "collect", "kill", "deliver", "talk", "explore", "escort", "use_item",
}

-- =========================================================================
-- Default Quest Template
-- =========================================================================

local function createDefaultQuest()
    return {
        id = "new_quest",
        name = "New Quest",
        description = "Describe the quest here.",
        type = "collect",
        profession = "shopkeeper",
        objectives = {
            {type = "collect", item = "item_id", amount = 5, current = 0},
        },
        requirements = {
            minLevel = 1,
            minReputation = 0,
            completedQuests = {},
        },
        rewards = {
            gold = 50,
            experience = 100,
            reputation = 10,
            items = {},
        },
        repeatable = false,
        cooldown = 0,
    }
end

-- =========================================================================
-- Editor Constructor
-- =========================================================================

local Editor = {}

function Editor.new(project)
    local self = setmetatable({}, {__index = Editor})

    self.project = project or {quests = {}}
    if not self.project.quests then
        self.project.quests = {}
    end

    -- Undo system
    self.undoStack = Undo.new(80)

    -- Selection state
    self.selectedIndex = nil
    self.selectedQuest = nil

    -- Search / filter state
    self.searchText = ""
    self.filterProfession = nil
    self.filterType = nil
    self.filteredList = {}

    -- Scroll containers
    self.leftScroll = UI.ScrollContainer.new({contentHeight = 0})
    self.centerScroll = UI.ScrollContainer.new({contentHeight = 0})
    self.rightScroll = UI.ScrollContainer.new({contentHeight = 0})

    -- Search input
    self.searchInput = UI.TextInput.new({
        placeholder = "Search quests...",
        onChange = function(text)
            self.searchText = text
            self:_rebuildFilteredList()
        end,
    })

    -- Filter dropdowns state
    self.profFilterOpen = false
    self.profFilterRect = {x = 0, y = 0, w = 0, h = 0}
    self.profFilterDropdownRects = {}

    self.typeFilterOpen = false
    self.typeFilterRect = {x = 0, y = 0, w = 0, h = 0}
    self.typeFilterDropdownRects = {}

    -- Buttons
    self.addBtn = UI.Button.new({
        text = "+ Add", variant = "primary", fontSize = 12,
        onClick = function() self:_addQuest() end,
    })
    self.deleteBtn = UI.Button.new({
        text = "Delete", variant = "danger", fontSize = 12,
        onClick = function() self:_deleteQuest() end,
    })
    self.dupBtn = UI.Button.new({
        text = "Duplicate", variant = "secondary", fontSize = 12,
        onClick = function() self:_duplicateQuest() end,
    })

    -- Quest list widget
    self.questList = UI.List.new({
        items = {},
        onSelect = function(idx, item)
            self:_selectQuest(idx)
        end,
    })

    -- Center panel input widgets -- Basic Info section
    self.idInput = UI.TextInput.new({
        placeholder = "quest_id",
        onChange = function(text)
            if self.selectedQuest then self.selectedQuest.id = text end
        end,
    })
    self.nameInput = UI.TextInput.new({
        placeholder = "Quest Name",
        onChange = function(text)
            if self.selectedQuest then
                self.selectedQuest.name = text
                self:_rebuildFilteredList()
            end
        end,
    })
    self.descInput = UI.TextInput.new({
        placeholder = "Quest description...",
        onChange = function(text)
            if self.selectedQuest then self.selectedQuest.description = text end
        end,
    })

    -- Type dropdown state
    self.questTypeDropdownOpen = false
    self.questTypeDropdownRect = {x = 0, y = 0, w = 0, h = 0}
    self.questTypeDropdownRects = {}

    -- Profession dropdown state
    self.questProfDropdownOpen = false
    self.questProfDropdownRect = {x = 0, y = 0, w = 0, h = 0}
    self.questProfDropdownRects = {}

    -- Objective type dropdown state (for the currently open objective)
    self.objTypeDropdownOpen = false
    self.objTypeDropdownIdx = nil
    self.objTypeDropdownRect = {x = 0, y = 0, w = 0, h = 0}
    self.objTypeDropdownRects = {}

    -- Objective text inputs (we create/cache these dynamically)
    self.objInputs = {}

    -- Requirements inputs
    self.minLevelInput = UI.TextInput.new({
        placeholder = "1",
        onChange = function(text)
            if self.selectedQuest then
                self.selectedQuest.requirements.minLevel = tonumber(text) or 1
            end
        end,
    })
    self.minRepInput = UI.TextInput.new({
        placeholder = "0",
        onChange = function(text)
            if self.selectedQuest then
                self.selectedQuest.requirements.minReputation = tonumber(text) or 0
            end
        end,
    })
    self.prereqInput = UI.TextInput.new({
        placeholder = "Quest ID, press Enter to add...",
        onSubmit = function(text)
            if self.selectedQuest and text ~= "" then
                if not self.selectedQuest.requirements.completedQuests then
                    self.selectedQuest.requirements.completedQuests = {}
                end
                table.insert(self.selectedQuest.requirements.completedQuests, text)
                self.prereqInput:setText("")
            end
        end,
    })

    -- Rewards inputs
    self.goldInput = UI.TextInput.new({
        placeholder = "0",
        onChange = function(text)
            if self.selectedQuest then
                self.selectedQuest.rewards.gold = tonumber(text) or 0
            end
        end,
    })
    self.xpInput = UI.TextInput.new({
        placeholder = "0",
        onChange = function(text)
            if self.selectedQuest then
                self.selectedQuest.rewards.experience = tonumber(text) or 0
            end
        end,
    })
    self.repInput = UI.TextInput.new({
        placeholder = "0",
        onChange = function(text)
            if self.selectedQuest then
                self.selectedQuest.rewards.reputation = tonumber(text) or 0
            end
        end,
    })
    self.rewardItemIdInput = UI.TextInput.new({
        placeholder = "Item ID",
    })
    self.rewardItemAmtInput = UI.TextInput.new({
        placeholder = "Amt",
    })

    -- Repeat controls
    self.repeatToggle = UI.Toggle.new({
        label = "Repeatable",
        value = false,
        onChange = function(val)
            if self.selectedQuest then
                self.selectedQuest.repeatable = val
            end
        end,
    })
    self.cooldownInput = UI.TextInput.new({
        placeholder = "0",
        onChange = function(text)
            if self.selectedQuest then
                self.selectedQuest.cooldown = tonumber(text) or 0
            end
        end,
    })

    -- Layout cache for click rects
    self._layoutCache = {}

    -- Build filtered list
    self:_rebuildFilteredList()

    return self
end

-- =========================================================================
-- Filtered list management
-- =========================================================================

function Editor:_rebuildFilteredList()
    local quests = self.project.quests
    local results = {}

    for i, quest in ipairs(quests) do
        local passSearch = true
        local passProfFilter = true
        local passTypeFilter = true

        -- Text search
        if self.searchText ~= "" then
            local lower = string.lower(self.searchText)
            local match = false
            if quest.name and string.find(string.lower(quest.name), lower, 1, true) then
                match = true
            end
            if not match and quest.id and string.find(string.lower(quest.id), lower, 1, true) then
                match = true
            end
            if not match and quest.description and string.find(string.lower(quest.description), lower, 1, true) then
                match = true
            end
            passSearch = match
        end

        -- Profession filter
        if self.filterProfession then
            passProfFilter = (quest.profession == self.filterProfession)
        end

        -- Type filter
        if self.filterType then
            passTypeFilter = (quest.type == self.filterType)
        end

        if passSearch and passProfFilter and passTypeFilter then
            table.insert(results, {
                index = i,
                quest = quest,
                text = (quest.name or "Unnamed") .. " [" .. (quest.type or "?") .. "]",
                id = i,
            })
        end
    end

    self.filteredList = results
    self.questList:setItems(results)

    -- Preserve selection
    if self.selectedQuest then
        local found = false
        for fi, entry in ipairs(results) do
            if entry.quest == self.selectedQuest then
                self.questList:setSelectedIndex(fi)
                self.selectedIndex = fi
                found = true
                break
            end
        end
        if not found then
            self.selectedIndex = nil
            self.selectedQuest = nil
        end
    end
end

function Editor:_selectQuest(filteredIdx)
    if filteredIdx and self.filteredList[filteredIdx] then
        self.selectedIndex = filteredIdx
        self.selectedQuest = self.filteredList[filteredIdx].quest
        self:_syncWidgetsToQuest()
    else
        self.selectedIndex = nil
        self.selectedQuest = nil
    end
end

function Editor:_syncWidgetsToQuest()
    local q = self.selectedQuest
    if not q then return end

    self.idInput:setText(q.id or "")
    self.nameInput:setText(q.name or "")
    self.descInput:setText(q.description or "")

    local req = q.requirements or {}
    self.minLevelInput:setText(tostring(req.minLevel or 1))
    self.minRepInput:setText(tostring(req.minReputation or 0))

    local rew = q.rewards or {}
    self.goldInput:setText(tostring(rew.gold or 0))
    self.xpInput:setText(tostring(rew.experience or 0))
    self.repInput:setText(tostring(rew.reputation or 0))

    self.repeatToggle:setValue(q.repeatable or false)
    self.cooldownInput:setText(tostring(q.cooldown or 0))

    -- Reset dynamic objective inputs
    self.objInputs = {}

    self.centerScroll:scrollToTop()
end

-- =========================================================================
-- Add / Delete / Duplicate
-- =========================================================================

function Editor:_addQuest()
    local quest = createDefaultQuest()
    -- Generate unique id
    local existingIds = {}
    for _, q in ipairs(self.project.quests) do
        if q.id then existingIds[q.id] = true end
    end
    quest.id = IdGen.ensureUnique("new_quest", existingIds)

    table.insert(self.project.quests, quest)
    self:_rebuildFilteredList()
    for fi, entry in ipairs(self.filteredList) do
        if entry.quest == quest then
            self.questList:setSelectedIndex(fi)
            self:_selectQuest(fi)
            break
        end
    end
end

function Editor:_deleteQuest()
    if not self.selectedQuest then return end
    for i, q in ipairs(self.project.quests) do
        if q == self.selectedQuest then
            table.remove(self.project.quests, i)
            break
        end
    end
    self.selectedQuest = nil
    self.selectedIndex = nil
    self:_rebuildFilteredList()
end

function Editor:_duplicateQuest()
    if not self.selectedQuest then return end
    local copy = deepCopy(self.selectedQuest)
    -- Generate unique id
    local existingIds = {}
    for _, q in ipairs(self.project.quests) do
        if q.id then existingIds[q.id] = true end
    end
    copy.id = IdGen.ensureUnique(copy.id or "quest", existingIds)
    copy.name = (copy.name or "Quest") .. " (Copy)"

    table.insert(self.project.quests, copy)
    self:_rebuildFilteredList()
    for fi, entry in ipairs(self.filteredList) do
        if entry.quest == copy then
            self.questList:setSelectedIndex(fi)
            self:_selectQuest(fi)
            break
        end
    end
end

-- =========================================================================
-- Update
-- =========================================================================

function Editor:update(dt)
    self.searchInput:update(dt)
    self.idInput:update(dt)
    self.nameInput:update(dt)
    self.descInput:update(dt)
    self.minLevelInput:update(dt)
    self.minRepInput:update(dt)
    self.prereqInput:update(dt)
    self.goldInput:update(dt)
    self.xpInput:update(dt)
    self.repInput:update(dt)
    self.rewardItemIdInput:update(dt)
    self.rewardItemAmtInput:update(dt)
    self.cooldownInput:update(dt)
    self.repeatToggle:update(dt)

    for _, inp in pairs(self.objInputs) do
        if inp.item then inp.item:update(dt) end
        if inp.amount then inp.amount:update(dt) end
    end
end

-- =========================================================================
-- Drawing
-- =========================================================================

function Editor:draw(x, y, w, h)
    local leftW = 260
    local rightW = 200
    local centerW = w - leftW - rightW - 8

    -- Left panel bg
    setColor(Theme.colors.panel)
    love.graphics.rectangle("fill", x, y, leftW, h)
    setColor(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", x + leftW, y, 1, h)

    -- Right panel bg
    setColor(Theme.colors.panel)
    love.graphics.rectangle("fill", x + w - rightW, y, rightW, h)
    setColor(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", x + w - rightW - 1, y, 1, h)

    -- Center bg
    setColor(Theme.colors.bg)
    love.graphics.rectangle("fill", x + leftW + 4, y, centerW, h)

    self:_drawLeftPanel(x, y, leftW, h)
    self:_drawCenterPanel(x + leftW + 4, y, centerW, h)
    self:_drawRightPanel(x + w - rightW, y, rightW, h)

    -- Draw dropdown overlays last
    self:_drawDropdowns()
end

-- =========================================================================
-- Left Panel
-- =========================================================================

function Editor:_drawLeftPanel(x, y, w, h)
    local pad = Theme.spacing.md
    local cy = y + pad
    local mx, my = love.mouse.getPosition()

    -- Title
    local titleFont = FontCache.get(15)
    love.graphics.setFont(titleFont)
    setColor(Theme.colors.textAccent)
    love.graphics.print("Quests", x + pad, cy)
    cy = cy + titleFont:getHeight() + pad

    -- Search bar
    self.searchInput:draw(x + pad, cy, w - pad * 2, Theme.sizes.inputHeight)
    cy = cy + Theme.sizes.inputHeight + pad

    -- Profession filter dropdown
    local filterH = Theme.sizes.inputHeight
    local halfW = math.floor((w - pad * 3) / 2)
    local profLabel = self.filterProfession or "All NPC Types"
    self.profFilterRect = {x = x + pad, y = cy, w = halfW, h = filterH}

    local profHovered = pointInRect(mx, my, x + pad, cy, halfW, filterH)
    setColor(profHovered and Theme.colors.listItemHover or Theme.colors.input)
    drawRoundedRect("fill", x + pad, cy, halfW, filterH, Theme.radius.sm)
    setColor(self.profFilterOpen and Theme.colors.inputFocus or Theme.colors.inputBorder)
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", x + pad + 0.5, cy + 0.5, halfW - 1, filterH - 1, Theme.radius.sm)

    local filterFont = FontCache.get(11)
    love.graphics.setFont(filterFont)
    setColor(Theme.colors.text)
    local ftY = cy + math.floor((filterH - filterFont:getHeight()) / 2)
    love.graphics.print(profLabel, x + pad + 6, ftY)
    setColor(Theme.colors.textDim)
    love.graphics.print("v", x + pad + halfW - 14, ftY)

    -- Type filter dropdown
    local typeLabel = self.filterType or "All Types"
    local typeX = x + pad + halfW + pad
    self.typeFilterRect = {x = typeX, y = cy, w = halfW, h = filterH}

    local typeHovered = pointInRect(mx, my, typeX, cy, halfW, filterH)
    setColor(typeHovered and Theme.colors.listItemHover or Theme.colors.input)
    drawRoundedRect("fill", typeX, cy, halfW, filterH, Theme.radius.sm)
    setColor(self.typeFilterOpen and Theme.colors.inputFocus or Theme.colors.inputBorder)
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", typeX + 0.5, cy + 0.5, halfW - 1, filterH - 1, Theme.radius.sm)

    setColor(Theme.colors.text)
    love.graphics.print(typeLabel, typeX + 6, ftY)
    setColor(Theme.colors.textDim)
    love.graphics.print("v", typeX + halfW - 14, ftY)

    cy = cy + filterH + pad

    -- Quest list
    local btnAreaH = Theme.sizes.buttonHeight + pad
    local listH = h - (cy - y) - btnAreaH - pad
    if listH < 20 then listH = 20 end

    self.questList:draw(x + pad, cy, w - pad * 2, listH)
    cy = cy + listH + pad

    -- Buttons row
    local btnW = math.floor((w - pad * 4) / 3)
    local btnH = Theme.sizes.buttonHeight
    self.addBtn:draw(x + pad, cy, btnW, btnH)
    self.dupBtn:draw(x + pad + btnW + pad, cy, btnW, btnH)
    self.deleteBtn:draw(x + pad + (btnW + pad) * 2, cy, btnW, btnH)
end

-- =========================================================================
-- Center Panel
-- =========================================================================

function Editor:_drawCenterPanel(x, y, w, h)
    if w < 10 or h < 10 then return end

    love.graphics.setScissor(x, y, w, h)

    if not self.selectedQuest then
        local font = FontCache.get(14)
        love.graphics.setFont(font)
        setColor(Theme.colors.textDim)
        love.graphics.printf("Select or create a quest", x, y + 40, w, "center")
        love.graphics.setScissor()
        return
    end

    local pad = Theme.spacing.lg
    local font = FontCache.get(13)
    love.graphics.setFont(font)
    local textH = font:getHeight()
    local labelW = 120
    local inputW = w - pad * 2 - labelW - pad
    if inputW < 80 then inputW = 80 end
    local rowH = Theme.sizes.inputHeight + Theme.spacing.md
    local cy = y + pad
    local q = self.selectedQuest
    local mx, my = love.mouse.getPosition()

    -- =========== Section header helper ===========
    local function sectionHeader(title)
        local hFont = FontCache.get(14)
        love.graphics.setFont(hFont)
        setColor(Theme.colors.textAccent)
        love.graphics.print(title, x + pad, cy)
        cy = cy + hFont:getHeight() + Theme.spacing.sm
        setColor(Theme.colors.panelBorder)
        love.graphics.rectangle("fill", x + pad, cy, w - pad * 2, 1)
        cy = cy + Theme.spacing.md
        love.graphics.setFont(font)
    end

    local function labelRow(label)
        setColor(Theme.colors.text)
        love.graphics.print(label, x + pad, cy + math.floor((Theme.sizes.inputHeight - textH) / 2))
    end

    -- =========== Basic Info ===========
    sectionHeader("Basic Info")

    labelRow("ID")
    self.idInput:draw(x + pad + labelW + pad, cy, inputW, Theme.sizes.inputHeight)
    cy = cy + rowH

    labelRow("Name")
    self.nameInput:draw(x + pad + labelW + pad, cy, inputW, Theme.sizes.inputHeight)
    cy = cy + rowH

    labelRow("Description")
    self.descInput:draw(x + pad + labelW + pad, cy, inputW, Theme.sizes.inputHeight)
    cy = cy + rowH

    -- Type dropdown
    labelRow("Type")
    local typeFieldX = x + pad + labelW + pad
    local typeFieldW = inputW
    local typeFieldH = Theme.sizes.inputHeight
    self.questTypeDropdownRect = {x = typeFieldX, y = cy, w = typeFieldW, h = typeFieldH}

    local typeHover = pointInRect(mx, my, typeFieldX, cy, typeFieldW, typeFieldH)
    setColor(typeHover and Theme.colors.listItemHover or Theme.colors.input)
    drawRoundedRect("fill", typeFieldX, cy, typeFieldW, typeFieldH, Theme.radius.sm)
    setColor(self.questTypeDropdownOpen and Theme.colors.inputFocus or Theme.colors.inputBorder)
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", typeFieldX + 0.5, cy + 0.5, typeFieldW - 1, typeFieldH - 1, Theme.radius.sm)
    setColor(Theme.colors.text)
    love.graphics.print(q.type or "select...", typeFieldX + Theme.spacing.md, cy + math.floor((typeFieldH - textH) / 2))
    setColor(Theme.colors.textDim)
    love.graphics.print("v", typeFieldX + typeFieldW - 16, cy + math.floor((typeFieldH - textH) / 2))
    cy = cy + rowH

    -- Profession dropdown
    labelRow("NPC Profession")
    local profFieldX = x + pad + labelW + pad
    local profFieldW = inputW
    local profFieldH = Theme.sizes.inputHeight
    self.questProfDropdownRect = {x = profFieldX, y = cy, w = profFieldW, h = profFieldH}

    local profHover = pointInRect(mx, my, profFieldX, cy, profFieldW, profFieldH)
    setColor(profHover and Theme.colors.listItemHover or Theme.colors.input)
    drawRoundedRect("fill", profFieldX, cy, profFieldW, profFieldH, Theme.radius.sm)
    setColor(self.questProfDropdownOpen and Theme.colors.inputFocus or Theme.colors.inputBorder)
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", profFieldX + 0.5, cy + 0.5, profFieldW - 1, profFieldH - 1, Theme.radius.sm)
    setColor(Theme.colors.text)
    love.graphics.print(q.profession or "select...", profFieldX + Theme.spacing.md, cy + math.floor((profFieldH - textH) / 2))
    setColor(Theme.colors.textDim)
    love.graphics.print("v", profFieldX + profFieldW - 16, cy + math.floor((profFieldH - textH) / 2))
    cy = cy + rowH + Theme.spacing.md

    -- =========== Objectives ===========
    sectionHeader("Objectives")

    local objectives = q.objectives or {}

    -- Add objective button
    local addObjRect = {x = x + w - pad - 110, y = cy - Theme.spacing.md - 20, w = 100, h = 22}
    self._layoutCache["addObj"] = addObjRect
    local addObjHover = pointInRect(mx, my, addObjRect.x, addObjRect.y, addObjRect.w, addObjRect.h)
    setColor(addObjHover and Theme.colors.primaryHover or Theme.colors.primary)
    drawRoundedRect("fill", addObjRect.x, addObjRect.y, addObjRect.w, addObjRect.h, Theme.radius.sm)
    local smallFont = FontCache.get(11)
    love.graphics.setFont(smallFont)
    setColor(Theme.colors.bg)
    love.graphics.printf("+ Add Objective", addObjRect.x, addObjRect.y + 3, addObjRect.w, "center")
    love.graphics.setFont(font)

    for oi, obj in ipairs(objectives) do
        local objBgH = 74
        local objX = x + pad
        local objW = w - pad * 2

        -- Alternating background
        if oi % 2 == 0 then
            setColor(Theme.colors.listItemAlt)
        else
            setColor(Theme.colors.listItem)
        end
        drawRoundedRect("fill", objX, cy, objW, objBgH, 2)

        -- Objective number
        setColor(Theme.colors.textDim)
        love.graphics.print("#" .. oi, objX + 6, cy + 6)

        -- Remove objective button
        setColor(Theme.colors.danger)
        love.graphics.print("x", objX + objW - 16, cy + 6)
        self._layoutCache["delObj_" .. oi] = {x = objX + objW - 22, y = cy + 2, w = 20, h = 20, idx = oi}

        -- Objective type dropdown trigger
        local otX = objX + 30
        local otW = 100
        local otH = 22
        local otY = cy + 4

        local objTypeDropRect = {x = otX, y = otY, w = otW, h = otH}
        self._layoutCache["objTypeDrop_" .. oi] = objTypeDropRect
        local otHover = pointInRect(mx, my, otX, otY, otW, otH)

        setColor(otHover and Theme.colors.listItemHover or Theme.colors.input)
        drawRoundedRect("fill", otX, otY, otW, otH, 2)
        setColor(Theme.colors.inputBorder)
        love.graphics.setLineWidth(1)
        drawRoundedRect("line", otX + 0.5, otY + 0.5, otW - 1, otH - 1, 2)
        setColor(Theme.colors.text)
        love.graphics.print(obj.type or "?", otX + 4, otY + 3)
        setColor(Theme.colors.textDim)
        love.graphics.print("v", otX + otW - 14, otY + 3)

        -- Create/cache objective input widgets
        if not self.objInputs[oi] then
            self.objInputs[oi] = {
                item = UI.TextInput.new({
                    placeholder = "item/enemy...",
                    text = obj.item or obj.enemy or "",
                    onChange = function(text)
                        if self.selectedQuest and self.selectedQuest.objectives[oi] then
                            local o = self.selectedQuest.objectives[oi]
                            if o.type == "kill" then
                                o.enemy = text
                                o.item = nil
                            else
                                o.item = text
                                o.enemy = nil
                            end
                        end
                    end,
                }),
                amount = UI.TextInput.new({
                    placeholder = "0",
                    text = tostring(obj.amount or 0),
                    onChange = function(text)
                        if self.selectedQuest and self.selectedQuest.objectives[oi] then
                            self.selectedQuest.objectives[oi].amount = tonumber(text) or 0
                        end
                    end,
                }),
            }
        end

        -- Item/Enemy input
        local itemLabelStr = (obj.type == "kill") and "Enemy:" or "Item:"
        setColor(Theme.colors.textDim)
        love.graphics.print(itemLabelStr, objX + 30, cy + 30)
        self.objInputs[oi].item:draw(objX + 80, cy + 28, objW - 230, Theme.sizes.inputHeight)

        -- Amount input
        setColor(Theme.colors.textDim)
        love.graphics.print("Amount:", objX + objW - 140, cy + 30)
        self.objInputs[oi].amount:draw(objX + objW - 80, cy + 28, 60, Theme.sizes.inputHeight)

        -- Progress bar visualization
        local current = obj.current or 0
        local amount = obj.amount or 1
        if amount < 1 then amount = 1 end
        local progressW = objW - 60
        local progressH = 6
        local progressY = cy + 56

        setColor(Theme.colors.scrollbar)
        drawRoundedRect("fill", objX + 30, progressY, progressW, progressH, 3)
        local fillRatio = clamp(current / amount, 0, 1)
        if fillRatio > 0 then
            setColor(Theme.colors.primary)
            drawRoundedRect("fill", objX + 30, progressY, progressW * fillRatio, progressH, 3)
        end
        setColor(Theme.colors.textDim)
        local progFont = FontCache.get(10)
        love.graphics.setFont(progFont)
        love.graphics.print(current .. "/" .. amount, objX + 30 + progressW + 4, progressY - 2)
        love.graphics.setFont(font)

        cy = cy + objBgH + 4
    end

    if #objectives == 0 then
        setColor(Theme.colors.textDim)
        love.graphics.print("  No objectives. Click '+ Add Objective' above.", x + pad, cy)
        cy = cy + 24
    end

    cy = cy + Theme.spacing.lg

    -- =========== Requirements ===========
    sectionHeader("Requirements")

    labelRow("Min Level")
    self.minLevelInput:draw(x + pad + labelW + pad, cy, 80, Theme.sizes.inputHeight)
    cy = cy + rowH

    labelRow("Min Reputation")
    self.minRepInput:draw(x + pad + labelW + pad, cy, 80, Theme.sizes.inputHeight)
    cy = cy + rowH

    -- Prerequisite quests tags
    labelRow("Prereq Quests")
    local preqs = (q.requirements and q.requirements.completedQuests) or {}
    local tagFont = FontCache.get(11)
    love.graphics.setFont(tagFont)
    local tagX = x + pad + labelW + pad
    local tagY = cy
    local tagH = 20
    local tagPad = 4

    for pi, pq in ipairs(preqs) do
        local tw = tagFont:getWidth(pq) + tagPad * 2 + 14
        if tagX + tw > x + w - pad then
            tagX = x + pad + labelW + pad
            tagY = tagY + tagH + 2
        end

        setColor(Theme.colors.listItemSelected)
        drawRoundedRect("fill", tagX, tagY, tw, tagH, 2)
        setColor(Theme.colors.text)
        love.graphics.print(pq, tagX + tagPad, tagY + 2)
        setColor(Theme.colors.textDim)
        love.graphics.print("x", tagX + tw - 12, tagY + 2)

        self._layoutCache["delPrereq_" .. pi] = {x = tagX + tw - 14, y = tagY, w = 14, h = tagH, idx = pi}
        tagX = tagX + tw + 4
    end

    if #preqs > 0 then
        cy = tagY + tagH + Theme.spacing.sm
    else
        cy = cy + 4
    end

    love.graphics.setFont(font)
    self.prereqInput:draw(x + pad + labelW + pad, cy, inputW, Theme.sizes.inputHeight)
    cy = cy + rowH + Theme.spacing.md

    -- =========== Rewards ===========
    sectionHeader("Rewards")

    labelRow("Gold")
    self.goldInput:draw(x + pad + labelW + pad, cy, 100, Theme.sizes.inputHeight)
    cy = cy + rowH

    labelRow("Experience")
    self.xpInput:draw(x + pad + labelW + pad, cy, 100, Theme.sizes.inputHeight)
    cy = cy + rowH

    labelRow("Reputation")
    self.repInput:draw(x + pad + labelW + pad, cy, 100, Theme.sizes.inputHeight)
    cy = cy + rowH

    -- Reward items list
    setColor(Theme.colors.textDim)
    love.graphics.print("Reward Items:", x + pad, cy)

    local addRewRect = {x = x + pad + 100, y = cy - 2, w = 80, h = 20}
    self._layoutCache["addRewardItem"] = addRewRect
    local addRewHover = pointInRect(mx, my, addRewRect.x, addRewRect.y, addRewRect.w, addRewRect.h)
    setColor(addRewHover and Theme.colors.primaryHover or Theme.colors.primary)
    drawRoundedRect("fill", addRewRect.x, addRewRect.y, addRewRect.w, addRewRect.h, 2)
    love.graphics.setFont(smallFont)
    setColor(Theme.colors.bg)
    love.graphics.printf("+ Add Item", addRewRect.x, addRewRect.y + 3, addRewRect.w, "center")
    love.graphics.setFont(font)
    cy = cy + 24

    local rewardItems = (q.rewards and q.rewards.items) or {}
    for ri, ritem in ipairs(rewardItems) do
        local riH = 26
        if ri % 2 == 0 then
            setColor(Theme.colors.listItemAlt)
        else
            setColor(Theme.colors.listItem)
        end
        drawRoundedRect("fill", x + pad, cy, w - pad * 2, riH, 2)

        setColor(Theme.colors.text)
        love.graphics.print(ritem.id or "?", x + pad + 8, cy + 5)
        setColor(Theme.colors.textDim)
        love.graphics.print("x" .. (ritem.amount or 0), x + pad + 200, cy + 5)

        -- Remove reward
        setColor(Theme.colors.danger)
        love.graphics.print("x", x + w - pad - 16, cy + 5)
        self._layoutCache["delReward_" .. ri] = {x = x + w - pad - 22, y = cy, w = 20, h = riH, idx = ri}

        cy = cy + riH + 2
    end

    -- Reward item add row
    setColor(Theme.colors.textDim)
    love.graphics.print("ID:", x + pad, cy + 3)
    self.rewardItemIdInput:draw(x + pad + 24, cy, 160, Theme.sizes.inputHeight)
    setColor(Theme.colors.textDim)
    love.graphics.print("Amt:", x + pad + 194, cy + 3)
    self.rewardItemAmtInput:draw(x + pad + 224, cy, 60, Theme.sizes.inputHeight)
    cy = cy + rowH + Theme.spacing.md

    -- =========== Repeat ===========
    sectionHeader("Repeat Settings")

    self.repeatToggle:draw(x + pad, cy, w - pad * 2, Theme.sizes.buttonHeight)
    cy = cy + Theme.sizes.buttonHeight + Theme.spacing.md

    if q.repeatable then
        labelRow("Cooldown (days)")
        self.cooldownInput:draw(x + pad + labelW + pad, cy, 80, Theme.sizes.inputHeight)
        cy = cy + rowH
    end

    self.centerScroll:setContentHeight(cy - y + pad * 2)
    love.graphics.setScissor()
end

-- =========================================================================
-- Right Panel: Quest Flow Visualization
-- =========================================================================

function Editor:_drawRightPanel(x, y, w, h)
    local pad = Theme.spacing.md
    local cy = y + pad
    local font = FontCache.get(12)
    love.graphics.setFont(font)
    local textH = font:getHeight()

    -- Title
    local titleFont = FontCache.get(13)
    love.graphics.setFont(titleFont)
    setColor(Theme.colors.textAccent)
    love.graphics.print("Quest Flow", x + pad, cy)
    cy = cy + titleFont:getHeight() + pad
    love.graphics.setFont(font)

    local q = self.selectedQuest
    if not q then
        setColor(Theme.colors.textDim)
        love.graphics.printf("No quest selected", x + pad, cy + 20, w - pad * 2, "center")
        return
    end

    local boxW = w - pad * 2
    local boxH = 60
    local arrowH = 24
    local centerX = x + math.floor(w / 2)

    -- Box drawing helper
    local function drawFlowBox(bx, by, title, lines, color)
        setColor(color or Theme.colors.bgLight)
        drawRoundedRect("fill", bx, by, boxW, boxH, Theme.radius.md)
        setColor(Theme.colors.panelBorder)
        love.graphics.setLineWidth(1)
        drawRoundedRect("line", bx + 0.5, by + 0.5, boxW - 1, boxH - 1, Theme.radius.md)

        setColor(Theme.colors.text)
        local tFont = FontCache.get(12)
        love.graphics.setFont(tFont)
        love.graphics.printf(title, bx + 4, by + 4, boxW - 8, "center")

        setColor(Theme.colors.textDim)
        local dFont = FontCache.get(10)
        love.graphics.setFont(dFont)
        local ly = by + 20
        for _, line in ipairs(lines) do
            love.graphics.printf(line, bx + 4, ly, boxW - 8, "center")
            ly = ly + dFont:getHeight() + 1
        end
        love.graphics.setFont(font)
    end

    -- Arrow drawing helper
    local function drawArrow(fromY, toY)
        setColor(Theme.colors.textDim)
        love.graphics.setLineWidth(2)
        love.graphics.line(centerX, fromY, centerX, toY - 4)
        -- Arrowhead
        love.graphics.polygon("fill",
            centerX, toY,
            centerX - 4, toY - 6,
            centerX + 4, toY - 6
        )
        love.graphics.setLineWidth(1)
    end

    -- 1. Requirements box
    local reqLines = {}
    local req = q.requirements or {}
    table.insert(reqLines, "Level >= " .. (req.minLevel or 1))
    if (req.minReputation or 0) > 0 then
        table.insert(reqLines, "Rep >= " .. req.minReputation)
    end
    local prereqs = req.completedQuests or {}
    if #prereqs > 0 then
        table.insert(reqLines, "Prereqs: " .. #prereqs .. " quest(s)")
    end

    drawFlowBox(x + pad, cy, "Requirements", reqLines, {0.15, 0.18, 0.30})
    cy = cy + boxH

    -- Arrow
    drawArrow(cy, cy + arrowH)
    cy = cy + arrowH

    -- 2. Objectives box
    local objLines = {}
    local objectives = q.objectives or {}
    for _, obj in ipairs(objectives) do
        local target = obj.item or obj.enemy or "?"
        table.insert(objLines, (obj.type or "?") .. ": " .. target .. " x" .. (obj.amount or 0))
    end
    if #objLines == 0 then
        table.insert(objLines, "(no objectives)")
    end
    -- Dynamic box height for objectives
    local objBoxH = math.max(boxH, 24 + #objLines * 14)

    setColor({0.15, 0.25, 0.18})
    drawRoundedRect("fill", x + pad, cy, boxW, objBoxH, Theme.radius.md)
    setColor(Theme.colors.panelBorder)
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", x + pad + 0.5, cy + 0.5, boxW - 1, objBoxH - 1, Theme.radius.md)

    setColor(Theme.colors.text)
    local tFont = FontCache.get(12)
    love.graphics.setFont(tFont)
    love.graphics.printf("Objectives", x + pad + 4, cy + 4, boxW - 8, "center")

    setColor(Theme.colors.textDim)
    local dFont = FontCache.get(10)
    love.graphics.setFont(dFont)
    local oly = cy + 20
    for _, line in ipairs(objLines) do
        love.graphics.printf(line, x + pad + 4, oly, boxW - 8, "center")
        oly = oly + dFont:getHeight() + 1
    end
    love.graphics.setFont(font)

    cy = cy + objBoxH

    -- Arrow
    drawArrow(cy, cy + arrowH)
    cy = cy + arrowH

    -- 3. Rewards box
    local rewLines = {}
    local rew = q.rewards or {}
    if (rew.gold or 0) > 0 then
        table.insert(rewLines, "Gold: " .. rew.gold)
    end
    if (rew.experience or 0) > 0 then
        table.insert(rewLines, "XP: " .. rew.experience)
    end
    if (rew.reputation or 0) > 0 then
        table.insert(rewLines, "Rep: +" .. rew.reputation)
    end
    local rewardItems = rew.items or {}
    if #rewardItems > 0 then
        table.insert(rewLines, "Items: " .. #rewardItems)
    end

    drawFlowBox(x + pad, cy, "Rewards", rewLines, {0.25, 0.18, 0.12})
    cy = cy + boxH

    -- Repeat indicator
    if q.repeatable then
        cy = cy + Theme.spacing.md
        setColor(Theme.colors.primary)
        drawRoundedRect("fill", x + pad, cy, boxW, 24, Theme.radius.sm)
        setColor(Theme.colors.bg)
        love.graphics.setFont(FontCache.get(11))
        local cooldownStr = q.cooldown and q.cooldown > 0 and (" (" .. q.cooldown .. " day cooldown)") or ""
        love.graphics.printf("Repeatable" .. cooldownStr, x + pad, cy + 4, boxW, "center")
        love.graphics.setFont(font)
        cy = cy + 28
    end

    -- Quest summary at bottom
    cy = cy + Theme.spacing.xl
    setColor(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", x + pad, cy, w - pad * 2, 1)
    cy = cy + Theme.spacing.md

    setColor(Theme.colors.textDim)
    love.graphics.print("ID: " .. (q.id or "?"), x + pad, cy)
    cy = cy + textH + 2
    love.graphics.print("Type: " .. (q.type or "?"), x + pad, cy)
    cy = cy + textH + 2
    love.graphics.print("NPC: " .. (q.profession or "?"), x + pad, cy)
end

-- =========================================================================
-- Dropdown Overlays
-- =========================================================================

function Editor:_drawDropdowns()
    local font = FontCache.get(12)
    love.graphics.setFont(font)
    local textH = font:getHeight()
    local mx, my = love.mouse.getPosition()

    -- Left panel: Profession filter dropdown
    if self.profFilterOpen then
        local r = self.profFilterRect
        local items = {"All NPC Types"}
        for _, p in ipairs(NPC_PROFESSIONS) do
            table.insert(items, p)
        end
        local dropH = math.min(#items * 22, 300)
        local dropY = r.y + r.h

        setColor(Theme.colors.panel)
        drawRoundedRect("fill", r.x, dropY, r.w, dropH, Theme.radius.sm)
        setColor(Theme.colors.panelBorder)
        love.graphics.setLineWidth(1)
        drawRoundedRect("line", r.x + 0.5, dropY + 0.5, r.w - 1, dropH - 1, Theme.radius.sm)

        self.profFilterDropdownRects = {}
        local maxVisible = math.floor(dropH / 22)
        for i = 1, math.min(#items, maxVisible) do
            local iy = dropY + (i - 1) * 22
            local hovered = pointInRect(mx, my, r.x, iy, r.w, 22)
            if hovered then
                setColor(Theme.colors.listItemHover)
                love.graphics.rectangle("fill", r.x + 1, iy, r.w - 2, 22)
            end
            setColor(Theme.colors.text)
            love.graphics.print(items[i], r.x + 6, iy + 3)
            self.profFilterDropdownRects[i] = {x = r.x, y = iy, w = r.w, h = 22, value = (i == 1) and nil or items[i]}
        end
    end

    -- Left panel: Type filter dropdown
    if self.typeFilterOpen then
        local r = self.typeFilterRect
        local items = {"All Types"}
        for _, t in ipairs(QUEST_TYPES) do
            table.insert(items, t)
        end
        local dropH = #items * 22
        local dropY = r.y + r.h

        setColor(Theme.colors.panel)
        drawRoundedRect("fill", r.x, dropY, r.w, dropH, Theme.radius.sm)
        setColor(Theme.colors.panelBorder)
        love.graphics.setLineWidth(1)
        drawRoundedRect("line", r.x + 0.5, dropY + 0.5, r.w - 1, dropH - 1, Theme.radius.sm)

        self.typeFilterDropdownRects = {}
        for i, item in ipairs(items) do
            local iy = dropY + (i - 1) * 22
            local hovered = pointInRect(mx, my, r.x, iy, r.w, 22)
            if hovered then
                setColor(Theme.colors.listItemHover)
                love.graphics.rectangle("fill", r.x + 1, iy, r.w - 2, 22)
            end
            setColor(Theme.colors.text)
            love.graphics.print(item, r.x + 6, iy + 3)
            self.typeFilterDropdownRects[i] = {x = r.x, y = iy, w = r.w, h = 22, value = (i == 1) and nil or item}
        end
    end

    -- Center panel: Quest type dropdown
    if self.questTypeDropdownOpen then
        local r = self.questTypeDropdownRect
        local dropH = #QUEST_TYPES * 22
        local dropY = r.y + r.h

        setColor(Theme.colors.panel)
        drawRoundedRect("fill", r.x, dropY, r.w, dropH, Theme.radius.sm)
        setColor(Theme.colors.panelBorder)
        love.graphics.setLineWidth(1)
        drawRoundedRect("line", r.x + 0.5, dropY + 0.5, r.w - 1, dropH - 1, Theme.radius.sm)

        self.questTypeDropdownRects = {}
        for i, qtype in ipairs(QUEST_TYPES) do
            local iy = dropY + (i - 1) * 22
            local hovered = pointInRect(mx, my, r.x, iy, r.w, 22)
            if hovered then
                setColor(Theme.colors.listItemHover)
                love.graphics.rectangle("fill", r.x + 1, iy, r.w - 2, 22)
            end
            setColor(Theme.colors.text)
            love.graphics.print(qtype, r.x + 6, iy + 3)
            self.questTypeDropdownRects[i] = {x = r.x, y = iy, w = r.w, h = 22, value = qtype}
        end
    end

    -- Center panel: Quest profession dropdown
    if self.questProfDropdownOpen then
        local r = self.questProfDropdownRect
        local dropH = #NPC_PROFESSIONS * 22
        local dropY = r.y + r.h

        setColor(Theme.colors.panel)
        drawRoundedRect("fill", r.x, dropY, r.w, dropH, Theme.radius.sm)
        setColor(Theme.colors.panelBorder)
        love.graphics.setLineWidth(1)
        drawRoundedRect("line", r.x + 0.5, dropY + 0.5, r.w - 1, dropH - 1, Theme.radius.sm)

        self.questProfDropdownRects = {}
        for i, prof in ipairs(NPC_PROFESSIONS) do
            local iy = dropY + (i - 1) * 22
            local hovered = pointInRect(mx, my, r.x, iy, r.w, 22)
            if hovered then
                setColor(Theme.colors.listItemHover)
                love.graphics.rectangle("fill", r.x + 1, iy, r.w - 2, 22)
            end
            setColor(Theme.colors.text)
            love.graphics.print(prof, r.x + 6, iy + 3)
            self.questProfDropdownRects[i] = {x = r.x, y = iy, w = r.w, h = 22, value = prof}
        end
    end

    -- Objective type dropdown
    if self.objTypeDropdownOpen and self.objTypeDropdownIdx then
        local r = self.objTypeDropdownRect
        local dropH = #OBJECTIVE_TYPES * 22
        local dropY = r.y + r.h

        setColor(Theme.colors.panel)
        drawRoundedRect("fill", r.x, dropY, r.w, dropH, Theme.radius.sm)
        setColor(Theme.colors.panelBorder)
        love.graphics.setLineWidth(1)
        drawRoundedRect("line", r.x + 0.5, dropY + 0.5, r.w - 1, dropH - 1, Theme.radius.sm)

        self.objTypeDropdownRects = {}
        for i, otype in ipairs(OBJECTIVE_TYPES) do
            local iy = dropY + (i - 1) * 22
            local hovered = pointInRect(mx, my, r.x, iy, r.w, 22)
            if hovered then
                setColor(Theme.colors.listItemHover)
                love.graphics.rectangle("fill", r.x + 1, iy, r.w - 2, 22)
            end
            setColor(Theme.colors.text)
            love.graphics.print(otype, r.x + 6, iy + 3)
            self.objTypeDropdownRects[i] = {x = r.x, y = iy, w = r.w, h = 22, value = otype}
        end
    end
end

-- =========================================================================
-- Mouse Input
-- =========================================================================

function Editor:mousepressed(mx, my, button)
    if button ~= 1 then return false end

    -- Handle open dropdowns first (they overlay everything)
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

    if self.typeFilterOpen then
        for _, rect in ipairs(self.typeFilterDropdownRects) do
            if pointInRect(mx, my, rect.x, rect.y, rect.w, rect.h) then
                self.filterType = rect.value
                self.typeFilterOpen = false
                self:_rebuildFilteredList()
                return true
            end
        end
        self.typeFilterOpen = false
        return true
    end

    if self.questTypeDropdownOpen then
        for _, rect in ipairs(self.questTypeDropdownRects) do
            if pointInRect(mx, my, rect.x, rect.y, rect.w, rect.h) then
                if self.selectedQuest then
                    self.selectedQuest.type = rect.value
                    self:_rebuildFilteredList()
                end
                self.questTypeDropdownOpen = false
                return true
            end
        end
        self.questTypeDropdownOpen = false
        return true
    end

    if self.questProfDropdownOpen then
        for _, rect in ipairs(self.questProfDropdownRects) do
            if pointInRect(mx, my, rect.x, rect.y, rect.w, rect.h) then
                if self.selectedQuest then
                    self.selectedQuest.profession = rect.value
                    self:_rebuildFilteredList()
                end
                self.questProfDropdownOpen = false
                return true
            end
        end
        self.questProfDropdownOpen = false
        return true
    end

    if self.objTypeDropdownOpen then
        for _, rect in ipairs(self.objTypeDropdownRects) do
            if pointInRect(mx, my, rect.x, rect.y, rect.w, rect.h) then
                if self.selectedQuest and self.objTypeDropdownIdx then
                    local obj = self.selectedQuest.objectives[self.objTypeDropdownIdx]
                    if obj then obj.type = rect.value end
                end
                self.objTypeDropdownOpen = false
                self.objTypeDropdownIdx = nil
                return true
            end
        end
        self.objTypeDropdownOpen = false
        self.objTypeDropdownIdx = nil
        return true
    end

    -- Left panel filter triggers
    local pfr = self.profFilterRect
    if pointInRect(mx, my, pfr.x, pfr.y, pfr.w, pfr.h) then
        self.profFilterOpen = not self.profFilterOpen
        self.typeFilterOpen = false
        return true
    end

    local tfr = self.typeFilterRect
    if pointInRect(mx, my, tfr.x, tfr.y, tfr.w, tfr.h) then
        self.typeFilterOpen = not self.typeFilterOpen
        self.profFilterOpen = false
        return true
    end

    -- Search input
    if self.searchInput:mousepressed(mx, my, button) then return true end

    -- Quest list
    if self.questList:mousepressed(mx, my, button) then return true end

    -- Buttons
    if self.addBtn:mousepressed(mx, my, button) then return true end
    if self.deleteBtn:mousepressed(mx, my, button) then return true end
    if self.dupBtn:mousepressed(mx, my, button) then return true end

    -- Center panel interactions
    if self.selectedQuest then
        -- Basic info inputs
        if self.idInput:mousepressed(mx, my, button) then return true end
        if self.nameInput:mousepressed(mx, my, button) then return true end
        if self.descInput:mousepressed(mx, my, button) then return true end

        -- Quest type dropdown trigger
        local qtdr = self.questTypeDropdownRect
        if pointInRect(mx, my, qtdr.x, qtdr.y, qtdr.w, qtdr.h) then
            self.questTypeDropdownOpen = not self.questTypeDropdownOpen
            self.questProfDropdownOpen = false
            self.objTypeDropdownOpen = false
            return true
        end

        -- Quest profession dropdown trigger
        local qpdr = self.questProfDropdownRect
        if pointInRect(mx, my, qpdr.x, qpdr.y, qpdr.w, qpdr.h) then
            self.questProfDropdownOpen = not self.questProfDropdownOpen
            self.questTypeDropdownOpen = false
            self.objTypeDropdownOpen = false
            return true
        end

        -- Add objective button
        local addObjR = self._layoutCache["addObj"]
        if addObjR and pointInRect(mx, my, addObjR.x, addObjR.y, addObjR.w, addObjR.h) then
            if not self.selectedQuest.objectives then
                self.selectedQuest.objectives = {}
            end
            table.insert(self.selectedQuest.objectives, {
                type = "collect",
                item = "item_id",
                amount = 1,
                current = 0,
            })
            self.objInputs = {} -- reset cached inputs
            return true
        end

        -- Delete objective buttons
        for key, rect in pairs(self._layoutCache) do
            if type(key) == "string" and key:match("^delObj_") and rect.idx then
                if pointInRect(mx, my, rect.x, rect.y, rect.w, rect.h) then
                    if self.selectedQuest.objectives then
                        table.remove(self.selectedQuest.objectives, rect.idx)
                        self.objInputs = {} -- reset cached inputs
                    end
                    return true
                end
            end
        end

        -- Objective type dropdown triggers
        for key, rect in pairs(self._layoutCache) do
            if type(key) == "string" and key:match("^objTypeDrop_") then
                if pointInRect(mx, my, rect.x, rect.y, rect.w, rect.h) then
                    local idx = tonumber(key:match("objTypeDrop_(%d+)"))
                    if idx then
                        self.objTypeDropdownOpen = true
                        self.objTypeDropdownIdx = idx
                        self.objTypeDropdownRect = rect
                        self.questTypeDropdownOpen = false
                        self.questProfDropdownOpen = false
                    end
                    return true
                end
            end
        end

        -- Objective text inputs
        for _, inp in pairs(self.objInputs) do
            if inp.item and inp.item:mousepressed(mx, my, button) then return true end
            if inp.amount and inp.amount:mousepressed(mx, my, button) then return true end
        end

        -- Requirements inputs
        if self.minLevelInput:mousepressed(mx, my, button) then return true end
        if self.minRepInput:mousepressed(mx, my, button) then return true end
        if self.prereqInput:mousepressed(mx, my, button) then return true end

        -- Delete prereq tags
        for key, rect in pairs(self._layoutCache) do
            if type(key) == "string" and key:match("^delPrereq_") and rect.idx then
                if pointInRect(mx, my, rect.x, rect.y, rect.w, rect.h) then
                    local preqs = self.selectedQuest.requirements and self.selectedQuest.requirements.completedQuests
                    if preqs then
                        table.remove(preqs, rect.idx)
                    end
                    return true
                end
            end
        end

        -- Rewards inputs
        if self.goldInput:mousepressed(mx, my, button) then return true end
        if self.xpInput:mousepressed(mx, my, button) then return true end
        if self.repInput:mousepressed(mx, my, button) then return true end
        if self.rewardItemIdInput:mousepressed(mx, my, button) then return true end
        if self.rewardItemAmtInput:mousepressed(mx, my, button) then return true end

        -- Add reward item button
        local addRewR = self._layoutCache["addRewardItem"]
        if addRewR and pointInRect(mx, my, addRewR.x, addRewR.y, addRewR.w, addRewR.h) then
            local itemId = self.rewardItemIdInput:getText()
            local itemAmt = tonumber(self.rewardItemAmtInput:getText()) or 1
            if itemId ~= "" then
                if not self.selectedQuest.rewards then
                    self.selectedQuest.rewards = {gold = 0, experience = 0, reputation = 0, items = {}}
                end
                if not self.selectedQuest.rewards.items then
                    self.selectedQuest.rewards.items = {}
                end
                table.insert(self.selectedQuest.rewards.items, {id = itemId, amount = itemAmt})
                self.rewardItemIdInput:setText("")
                self.rewardItemAmtInput:setText("")
            end
            return true
        end

        -- Delete reward item buttons
        for key, rect in pairs(self._layoutCache) do
            if type(key) == "string" and key:match("^delReward_") and rect.idx then
                if pointInRect(mx, my, rect.x, rect.y, rect.w, rect.h) then
                    local items = self.selectedQuest.rewards and self.selectedQuest.rewards.items
                    if items then
                        table.remove(items, rect.idx)
                    end
                    return true
                end
            end
        end

        -- Repeat controls
        if self.repeatToggle:mousepressed(mx, my, button) then return true end
        if self.cooldownInput:mousepressed(mx, my, button) then return true end
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
    self.questList:mousereleased(mx, my, button)

    self.leftScroll:mousereleased(mx, my, button)
    self.centerScroll:mousereleased(mx, my, button)
    self.rightScroll:mousereleased(mx, my, button)

    return false
end

function Editor:wheelmoved(wx, wy)
    if self.questList:wheelmoved(wx, wy) then return true end
    if self.leftScroll:wheelmoved(wx, wy) then return true end
    if self.centerScroll:wheelmoved(wx, wy) then return true end
    if self.rightScroll:wheelmoved(wx, wy) then return true end
    return false
end

function Editor:keypressed(key)
    -- Delegate to focused inputs
    if self.searchInput:keypressed(key) then return true end
    if self.idInput:keypressed(key) then return true end
    if self.nameInput:keypressed(key) then return true end
    if self.descInput:keypressed(key) then return true end
    if self.minLevelInput:keypressed(key) then return true end
    if self.minRepInput:keypressed(key) then return true end
    if self.prereqInput:keypressed(key) then return true end
    if self.goldInput:keypressed(key) then return true end
    if self.xpInput:keypressed(key) then return true end
    if self.repInput:keypressed(key) then return true end
    if self.rewardItemIdInput:keypressed(key) then return true end
    if self.rewardItemAmtInput:keypressed(key) then return true end
    if self.cooldownInput:keypressed(key) then return true end

    for _, inp in pairs(self.objInputs) do
        if inp.item and inp.item:keypressed(key) then return true end
        if inp.amount and inp.amount:keypressed(key) then return true end
    end

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

    -- Delete selected quest
    if key == "delete" and self.selectedQuest then
        self:_deleteQuest()
        return true
    end

    return false
end

function Editor:textinput(t)
    if self.searchInput:textinput(t) then return true end
    if self.idInput:textinput(t) then return true end
    if self.nameInput:textinput(t) then return true end
    if self.descInput:textinput(t) then return true end
    if self.minLevelInput:textinput(t) then return true end
    if self.minRepInput:textinput(t) then return true end
    if self.prereqInput:textinput(t) then return true end
    if self.goldInput:textinput(t) then return true end
    if self.xpInput:textinput(t) then return true end
    if self.repInput:textinput(t) then return true end
    if self.rewardItemIdInput:textinput(t) then return true end
    if self.rewardItemAmtInput:textinput(t) then return true end
    if self.cooldownInput:textinput(t) then return true end

    for _, inp in pairs(self.objInputs) do
        if inp.item and inp.item:textinput(t) then return true end
        if inp.amount and inp.amount:textinput(t) then return true end
    end

    return false
end

return Editor
