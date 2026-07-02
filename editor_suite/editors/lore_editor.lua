-- ==========================================================================
-- Lore / Book Editor for Tavern Quest Editor Suite
-- Full text editor for in-game books, journals, and lore fragments.
-- ==========================================================================

local Theme     = require("core.theme")
local FontCache = require("core.fontcache")
local UI        = require("core.ui")
local UndoStack = require("core.undo")

local Editor = {}

-- =========================================================================
-- Constants
-- =========================================================================

local LEFT_PANEL_W   = 260
local RIGHT_PANEL_W  = 200
local METADATA_H     = 200

local CATEGORIES = {
    "covenant", "racial_elf", "racial_dwarf", "racial_orc", "racial_goblin",
    "racial_gnome", "dominion", "historical", "personal", "religious",
    "mythology", "culture", "theory",
}

local RARITIES = { "common", "uncommon", "rare", "epic", "legendary" }

local RARITY_COLORS = {
    common    = {0.65, 0.65, 0.65},
    uncommon  = {0.30, 0.80, 0.40},
    rare      = {0.30, 0.50, 0.90},
    epic      = {0.70, 0.40, 0.90},
    legendary = {0.95, 0.70, 0.15},
}

local CATEGORY_COLORS = {
    covenant    = {0.80, 0.60, 0.20},
    racial_elf  = {0.40, 0.80, 0.50},
    racial_dwarf = {0.70, 0.50, 0.30},
    racial_orc  = {0.70, 0.35, 0.30},
    racial_goblin = {0.50, 0.70, 0.30},
    racial_gnome = {0.60, 0.60, 0.80},
    dominion    = {0.80, 0.30, 0.30},
    historical  = {0.60, 0.55, 0.45},
    personal    = {0.50, 0.65, 0.80},
    religious   = {0.80, 0.75, 0.40},
    mythology   = {0.65, 0.50, 0.80},
    culture     = {0.55, 0.70, 0.60},
    theory      = {0.50, 0.60, 0.75},
}

-- =========================================================================
-- Helpers
-- =========================================================================

local function pointInRect(px, py, x, y, w, h)
    return px >= x and px < x + w and py >= y and py < y + h
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function deepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[deepCopy(k)] = deepCopy(v)
    end
    return copy
end

local function setColorSafe(c)
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

local function getRarityColor(rarity)
    return RARITY_COLORS[rarity] or RARITY_COLORS.common
end

local function getCategoryColor(category)
    return CATEGORY_COLORS[category] or Theme.colors.textDim
end

-- =========================================================================
-- Multiline text editor state
-- =========================================================================

local function createTextEditorState()
    return {
        lines = { "" },       -- array of line strings
        cursorLine = 1,
        cursorCol = 0,        -- byte offset within line (0 = before first char)
        scrollY = 0,
        scrollX = 0,
        selStartLine = nil,
        selStartCol = nil,
        selEndLine = nil,
        selEndCol = nil,
        focused = false,
        cursorBlink = 0,
        -- Layout cache
        _lastX = 0,
        _lastY = 0,
        _lastW = 0,
        _lastH = 0,
    }
end

local function textFromLines(lines)
    return table.concat(lines, "\n")
end

local function linesToText(text)
    local lines = {}
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        lines[#lines + 1] = line
    end
    if #lines == 0 then lines[1] = "" end
    return lines
end

-- =========================================================================
-- Book data helpers
-- =========================================================================

local function createBlankBook(title)
    return {
        id = "",
        title = title or "New Book",
        author = "",
        category = "historical",
        rarity = "common",
        condition = "",
        findLocation = "",
        dungeonFloor = 0,
        content = "",
        discoveredText = "",
        partOfCodex = false,
        codexOrder = 0,
    }
end

-- =========================================================================
-- Dropdown state helper
-- =========================================================================

local function createDropdown(options, defaultValue)
    return {
        options = options,
        value = defaultValue or (options[1] or ""),
        open = false,
        _lastX = 0,
        _lastY = 0,
        _lastW = 0,
        _lastH = 0,
    }
end

-- =========================================================================
-- Editor constructor
-- =========================================================================

function Editor.new(project)
    local self = setmetatable({}, { __index = Editor })

    self.project = project
    -- Support both project.lore as array or project.lore.books
    if type(project.lore) == "table" and project.lore.books then
        self.books = project.lore.books
    elseif type(project.lore) == "table" then
        -- Check if lore is itself an array
        if #project.lore > 0 or next(project.lore) == nil then
            self.books = project.lore
        else
            -- Has sub-tables but no books key, create it
            project.lore.books = {}
            self.books = project.lore.books
        end
    else
        project.lore = { books = {} }
        self.books = project.lore.books
    end

    self.undoStack = UndoStack.new(100)

    -- Selection
    self.selectedIndex = nil
    self.selectedBook = nil

    -- Filters
    self.searchText = ""
    self.filterCategory = nil   -- nil = all
    self.filterRarity = nil     -- nil = all

    -- Left panel widgets
    self.searchInput = UI.TextInput.new({
        placeholder = "Search title, author, content...",
        fontSize = 12,
        onChange = function(text)
            self.searchText = text
        end,
    })

    self.categoryDropdown = createDropdown(CATEGORIES, nil)
    self.rarityDropdown = createDropdown(RARITIES, nil)
    self.bookListScroll = UI.ScrollContainer.new({ contentHeight = 0 })

    self.addBtn = UI.Button.new({
        text = "+Add", variant = "primary", fontSize = 11,
        onClick = function() self:_addBook() end,
    })
    self.deleteBtn = UI.Button.new({
        text = "Delete", variant = "danger", fontSize = 11,
        onClick = function() self:_deleteBook() end,
    })
    self.dupBtn = UI.Button.new({
        text = "Dup", variant = "secondary", fontSize = 11,
        onClick = function() self:_duplicateBook() end,
    })

    -- Metadata field inputs (center top)
    self.idInput = UI.TextInput.new({
        placeholder = "Book ID", fontSize = 12,
        onChange = function(t) self:_setField("id", t) end,
    })
    self.titleInput = UI.TextInput.new({
        placeholder = "Title", fontSize = 12,
        onChange = function(t) self:_setField("title", t) end,
    })
    self.authorInput = UI.TextInput.new({
        placeholder = "Author", fontSize = 12,
        onChange = function(t) self:_setField("author", t) end,
    })
    self.conditionInput = UI.TextInput.new({
        placeholder = "Condition", fontSize = 12,
        onChange = function(t) self:_setField("condition", t) end,
    })
    self.findLocationInput = UI.TextInput.new({
        placeholder = "Find location", fontSize = 12,
        onChange = function(t) self:_setField("findLocation", t) end,
    })
    self.discoveredTextInput = UI.TextInput.new({
        placeholder = "Discovered text...", fontSize = 12,
        onChange = function(t) self:_setField("discoveredText", t) end,
    })

    -- Dropdowns for metadata
    self.metaCategoryDropdown = createDropdown(CATEGORIES, "historical")
    self.metaRarityDropdown = createDropdown(RARITIES, "common")

    -- DungeonFloor buttons
    self.floorDownBtn = UI.Button.new({
        text = "-", variant = "secondary", fontSize = 11,
        onClick = function() self:_adjustFloor(-1) end,
    })
    self.floorUpBtn = UI.Button.new({
        text = "+", variant = "secondary", fontSize = 11,
        onClick = function() self:_adjustFloor(1) end,
    })

    -- Codex toggle
    self.codexToggle = UI.Toggle.new({
        value = false, label = "Part of Codex", fontSize = 11,
        onChange = function(v) self:_setField("partOfCodex", v) end,
    })

    -- Codex order buttons
    self.codexOrderDownBtn = UI.Button.new({
        text = "-", variant = "secondary", fontSize = 11,
        onClick = function() self:_adjustCodexOrder(-1) end,
    })
    self.codexOrderUpBtn = UI.Button.new({
        text = "+", variant = "secondary", fontSize = 11,
        onClick = function() self:_adjustCodexOrder(1) end,
    })

    -- Content text editor
    self.textEditor = createTextEditorState()

    -- Right panel preview scroll
    self.previewScroll = UI.ScrollContainer.new({ contentHeight = 0 })

    -- Undo/redo buttons
    self.undoBtn = UI.Button.new({
        text = "Undo", variant = "ghost", fontSize = 11,
        onClick = function() self.undoStack:undo() end,
    })
    self.redoBtn = UI.Button.new({
        text = "Redo", variant = "ghost", fontSize = 11,
        onClick = function() self.undoStack:redo() end,
    })

    -- Layout caches
    self._lastX = 0
    self._lastY = 0
    self._lastW = 0
    self._lastH = 0
    self._activeDropdown = nil  -- reference to any open dropdown

    -- All text inputs for easy iteration
    self._textInputs = {
        self.searchInput,
        self.idInput, self.titleInput, self.authorInput,
        self.conditionInput, self.findLocationInput, self.discoveredTextInput,
    }

    return self
end

-- =========================================================================
-- Field setters with undo
-- =========================================================================

function Editor:_setField(key, newVal)
    if not self.selectedBook then return end
    local book = self.selectedBook
    local oldVal = book[key]
    if oldVal == newVal then return end
    -- The caller (onChange) has not yet set the value -- we set it here
    book[key] = newVal
    -- Push without execute since we already set it
    local cmd = {
        description = "Change " .. key,
        execute = function() book[key] = newVal end,
        undo = function()
            book[key] = oldVal
            self:_syncInputsToBook()
        end,
    }
    self.undoStack._undoStack[#self.undoStack._undoStack + 1] = cmd
    self.undoStack._redoStack = {}
end

function Editor:_adjustFloor(delta)
    if not self.selectedBook then return end
    local book = self.selectedBook
    local oldVal = book.dungeonFloor or 0
    local newVal = clamp(oldVal + delta, 0, 50)
    if oldVal == newVal then return end
    book.dungeonFloor = newVal
    local cmd = {
        description = "Change dungeon floor",
        execute = function() book.dungeonFloor = newVal end,
        undo = function() book.dungeonFloor = oldVal end,
    }
    self.undoStack._undoStack[#self.undoStack._undoStack + 1] = cmd
    self.undoStack._redoStack = {}
end

function Editor:_adjustCodexOrder(delta)
    if not self.selectedBook then return end
    local book = self.selectedBook
    local oldVal = book.codexOrder or 0
    local newVal = clamp(oldVal + delta, 0, 100)
    if oldVal == newVal then return end
    book.codexOrder = newVal
    local cmd = {
        description = "Change codex order",
        execute = function() book.codexOrder = newVal end,
        undo = function() book.codexOrder = oldVal end,
    }
    self.undoStack._undoStack[#self.undoStack._undoStack + 1] = cmd
    self.undoStack._redoStack = {}
end

function Editor:_setContent(newContent)
    if not self.selectedBook then return end
    local book = self.selectedBook
    local oldContent = book.content
    if oldContent == newContent then return end
    book.content = newContent
    local cmd = {
        description = "Edit content",
        execute = function() book.content = newContent end,
        undo = function()
            book.content = oldContent
            self.textEditor.lines = linesToText(oldContent)
        end,
    }
    self.undoStack:coalesce(cmd, "content_edit")
end

-- =========================================================================
-- Book list operations
-- =========================================================================

function Editor:_getFilteredBooks()
    local results = {}
    local search = self.searchText:lower()

    for i, book in ipairs(self.books) do
        local matchSearch = true
        local matchCategory = true
        local matchRarity = true

        -- Text search
        if search ~= "" then
            local titleMatch = (book.title or ""):lower():find(search, 1, true)
            local authorMatch = (book.author or ""):lower():find(search, 1, true)
            local contentMatch = (book.content or ""):lower():find(search, 1, true)
            matchSearch = titleMatch or authorMatch or contentMatch
        end

        -- Category filter
        if self.filterCategory then
            matchCategory = (book.category == self.filterCategory)
        end

        -- Rarity filter
        if self.filterRarity then
            matchRarity = (book.rarity == self.filterRarity)
        end

        if matchSearch and matchCategory and matchRarity then
            results[#results + 1] = { index = i, book = book }
        end
    end

    return results
end

function Editor:_selectBook(index)
    if index and index >= 1 and index <= #self.books then
        self.selectedIndex = index
        self.selectedBook = self.books[index]
        self:_syncInputsToBook()
        self.undoStack:clear()
    else
        self.selectedIndex = nil
        self.selectedBook = nil
        self:_clearInputs()
    end
end

function Editor:_syncInputsToBook()
    local book = self.selectedBook
    if not book then
        self:_clearInputs()
        return
    end
    self.idInput:setText(book.id or "")
    self.titleInput:setText(book.title or "")
    self.authorInput:setText(book.author or "")
    self.conditionInput:setText(book.condition or "")
    self.findLocationInput:setText(book.findLocation or "")
    self.discoveredTextInput:setText(book.discoveredText or "")
    self.metaCategoryDropdown.value = book.category or "historical"
    self.metaRarityDropdown.value = book.rarity or "common"
    self.codexToggle.value = book.partOfCodex or false
    -- Load content into text editor
    self.textEditor.lines = linesToText(book.content or "")
    self.textEditor.cursorLine = 1
    self.textEditor.cursorCol = 0
    self.textEditor.scrollY = 0
    self.textEditor.selStartLine = nil
    self.textEditor.selStartCol = nil
    self.textEditor.selEndLine = nil
    self.textEditor.selEndCol = nil
end

function Editor:_clearInputs()
    self.idInput:setText("")
    self.titleInput:setText("")
    self.authorInput:setText("")
    self.conditionInput:setText("")
    self.findLocationInput:setText("")
    self.discoveredTextInput:setText("")
    self.textEditor.lines = { "" }
    self.textEditor.cursorLine = 1
    self.textEditor.cursorCol = 0
    self.textEditor.scrollY = 0
end

function Editor:_addBook()
    local book = createBlankBook("Book " .. (#self.books + 1))
    self.books[#self.books + 1] = book
    self:_selectBook(#self.books)
end

function Editor:_deleteBook()
    if not self.selectedIndex then return end
    table.remove(self.books, self.selectedIndex)
    if #self.books == 0 then
        self:_selectBook(nil)
    elseif self.selectedIndex > #self.books then
        self:_selectBook(#self.books)
    else
        self:_selectBook(self.selectedIndex)
    end
end

function Editor:_duplicateBook()
    if not self.selectedBook then return end
    local copy = deepCopy(self.selectedBook)
    copy.title = copy.title .. " (copy)"
    copy.id = copy.id ~= "" and (copy.id .. "_copy") or ""
    self.books[#self.books + 1] = copy
    self:_selectBook(#self.books)
end

-- =========================================================================
-- Update
-- =========================================================================

function Editor:update(dt)
    for _, inp in ipairs(self._textInputs) do
        inp:update(dt)
    end
    self.codexToggle:update(dt)

    if self.textEditor.focused then
        self.textEditor.cursorBlink = self.textEditor.cursorBlink + dt
        if self.textEditor.cursorBlink > 1.0 then
            self.textEditor.cursorBlink = self.textEditor.cursorBlink - 1.0
        end
    end

    -- Button states
    local hasSel = self.selectedBook ~= nil
    self.deleteBtn:setDisabled(not hasSel)
    self.dupBtn:setDisabled(not hasSel)
    self.undoBtn:setDisabled(not self.undoStack:canUndo())
    self.redoBtn:setDisabled(not self.undoStack:canRedo())
end

-- =========================================================================
-- Draw
-- =========================================================================

function Editor:draw(x, y, w, h)
    self._lastX = x
    self._lastY = y
    self._lastW = w
    self._lastH = h

    local leftX = x
    local leftW = LEFT_PANEL_W
    local rightX = x + w - RIGHT_PANEL_W
    local rightW = RIGHT_PANEL_W
    local centerX = leftX + leftW + 1
    local centerW = rightX - centerX - 1
    if centerW < 10 then centerW = 10 end

    self:_drawLeftPanel(leftX, y, leftW, h)
    self:_drawCenter(centerX, y, centerW, h)
    self:_drawRightPanel(rightX, y, rightW, h)

    -- Dividers
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", leftX + leftW, y, 1, h)
    love.graphics.rectangle("fill", rightX - 1, y, 1, h)

    -- Draw any open dropdown overlay on top
    if self._activeDropdown then
        self:_drawDropdownOverlay(self._activeDropdown)
    end
end

-- =========================================================================
-- Left Panel
-- =========================================================================

function Editor:_drawLeftPanel(px, py, pw, ph)
    setColorSafe(Theme.colors.panel)
    love.graphics.rectangle("fill", px, py, pw, ph)

    local pad = Theme.spacing.md
    local cy = py + pad
    local innerW = pw - pad * 2

    -- Header
    local headerFont = FontCache.get(14)
    love.graphics.setFont(headerFont)
    setColorSafe(Theme.colors.textAccent)
    love.graphics.print("Lore Books", px + pad, cy)

    -- Count
    local countFont = FontCache.get(11)
    love.graphics.setFont(countFont)
    setColorSafe(Theme.colors.textDim)
    local countStr = "(" .. #self.books .. ")"
    love.graphics.print(countStr, px + pad + headerFont:getWidth("Lore Books") + 6, cy + 2)
    cy = cy + headerFont:getHeight() + pad

    -- Search
    self.searchInput:draw(px + pad, cy, innerW, Theme.sizes.inputHeight)
    cy = cy + Theme.sizes.inputHeight + pad

    -- Category filter
    local labelFont = FontCache.get(11)
    love.graphics.setFont(labelFont)
    setColorSafe(Theme.colors.textDim)
    love.graphics.print("Category:", px + pad, cy + 2)
    local filterW = innerW - 68
    self:_drawDropdownButton(self.categoryDropdown, px + pad + 68, cy, filterW, 22, "All")
    cy = cy + 26

    -- Rarity filter
    setColorSafe(Theme.colors.textDim)
    love.graphics.print("Rarity:", px + pad, cy + 2)
    self:_drawDropdownButton(self.rarityDropdown, px + pad + 68, cy, filterW, 22, "All")
    cy = cy + 26 + pad

    -- Buttons
    local btnW = math.floor((innerW - pad * 2) / 3)
    local btnH = Theme.sizes.buttonHeight
    self.addBtn:draw(px + pad, cy, btnW, btnH)
    self.dupBtn:draw(px + pad + btnW + pad, cy, btnW, btnH)
    self.deleteBtn:draw(px + pad + (btnW + pad) * 2, cy, btnW, btnH)
    cy = cy + btnH + pad

    -- Book list
    local listH = py + ph - cy - pad
    if listH < 40 then listH = 40 end
    self:_drawBookList(px + pad, cy, innerW, listH)
end

function Editor:_drawDropdownButton(dropdown, dx, dy, dw, dh, allLabel)
    dropdown._lastX = dx
    dropdown._lastY = dy
    dropdown._lastW = dw
    dropdown._lastH = dh

    local r = Theme.radius.sm
    local font = FontCache.get(11)
    love.graphics.setFont(font)

    -- Background
    setColorSafe(Theme.colors.input)
    drawRoundedRect("fill", dx, dy, dw, dh, r)
    setColorSafe(Theme.colors.inputBorder)
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", dx + 0.5, dy + 0.5, dw - 1, dh - 1, r)

    -- Value text
    local displayVal = dropdown.value or allLabel or "All"
    if dropdown.value == nil then displayVal = allLabel or "All" end
    setColorSafe(Theme.colors.text)
    love.graphics.print(displayVal, dx + 4, dy + math.floor((dh - font:getHeight()) / 2))

    -- Arrow
    setColorSafe(Theme.colors.textDim)
    love.graphics.print("v", dx + dw - 14, dy + math.floor((dh - font:getHeight()) / 2))
end

function Editor:_drawDropdownOverlay(dropdown)
    if not dropdown.open then return end

    local dx = dropdown._lastX
    local dy = dropdown._lastY + dropdown._lastH
    local dw = dropdown._lastW
    local options = dropdown.options
    local itemH = 22
    local listH = math.min(#options * itemH + itemH, 300)  -- +itemH for "All" option

    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.3)
    drawRoundedRect("fill", dx + 2, dy + 2, dw, listH, Theme.radius.sm)

    -- Background
    setColorSafe(Theme.colors.panel)
    drawRoundedRect("fill", dx, dy, dw, listH, Theme.radius.sm)
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", dx + 0.5, dy + 0.5, dw - 1, listH - 1, Theme.radius.sm)

    local font = FontCache.get(11)
    love.graphics.setFont(font)
    local mx, my = love.mouse.getPosition()

    -- "All" option
    local allY = dy
    local allHovered = pointInRect(mx, my, dx, allY, dw, itemH)
    if allHovered then
        setColorSafe(Theme.colors.listItemHover)
        love.graphics.rectangle("fill", dx + 1, allY, dw - 2, itemH)
    end
    if dropdown.value == nil then
        setColorSafe(Theme.colors.primary)
    else
        setColorSafe(Theme.colors.text)
    end
    love.graphics.print("All", dx + 6, allY + 3)

    -- Options
    for i, opt in ipairs(options) do
        local oy = dy + i * itemH
        local hovered = pointInRect(mx, my, dx, oy, dw, itemH)
        if hovered then
            setColorSafe(Theme.colors.listItemHover)
            love.graphics.rectangle("fill", dx + 1, oy, dw - 2, itemH)
        end

        local isSelected = (dropdown.value == opt)
        if isSelected then
            setColorSafe(Theme.colors.primary)
        else
            setColorSafe(Theme.colors.text)
        end
        love.graphics.print(opt, dx + 6, oy + 3)
    end

    dropdown._overlayRect = { x = dx, y = dy, w = dw, h = listH }
end

function Editor:_drawBookList(lx, ly, lw, lh)
    local filtered = self:_getFilteredBooks()
    local itemH = 36
    local totalH = #filtered * itemH
    self.bookListScroll:setContentHeight(totalH)

    -- Border
    setColorSafe(Theme.colors.inputBorder)
    love.graphics.rectangle("line", lx - 1, ly - 1, lw + 2, lh + 2)

    self.bookListScroll:beginDraw(lx, ly, lw, lh)

    local titleFont = FontCache.get(12)
    local subFont = FontCache.get(10)
    local mx, my = love.mouse.getPosition()

    for i, entry in ipairs(filtered) do
        local iy = (i - 1) * itemH
        local screenY = ly + iy - self.bookListScroll.scrollY
        local isSelected = (entry.index == self.selectedIndex)
        local isHovered = pointInRect(mx, my, lx, screenY, lw, itemH)

        if isSelected then
            setColorSafe(Theme.colors.listItemSelected)
            love.graphics.rectangle("fill", 0, iy, lw, itemH)
        elseif isHovered then
            setColorSafe(Theme.colors.listItemHover)
            love.graphics.rectangle("fill", 0, iy, lw, itemH)
        elseif i % 2 == 0 then
            setColorSafe(Theme.colors.listItemAlt)
            love.graphics.rectangle("fill", 0, iy, lw, itemH)
        end

        -- Rarity indicator bar
        local rarCol = getRarityColor(entry.book.rarity)
        setColorSafe(rarCol)
        love.graphics.rectangle("fill", 0, iy, 3, itemH)

        -- Title
        love.graphics.setFont(titleFont)
        setColorSafe(Theme.colors.text)
        local titleStr = entry.book.title or "Untitled"
        if #titleStr > 28 then titleStr = titleStr:sub(1, 28) .. ".." end
        love.graphics.print(titleStr, 8, iy + 2)

        -- Author + category badge
        love.graphics.setFont(subFont)
        local authorStr = entry.book.author or ""
        if #authorStr > 20 then authorStr = authorStr:sub(1, 20) .. ".." end
        setColorSafe(Theme.colors.textDim)
        love.graphics.print(authorStr, 8, iy + 18)

        -- Category badge
        local catStr = entry.book.category or ""
        if #catStr > 10 then catStr = catStr:sub(1, 10) end
        local catCol = getCategoryColor(entry.book.category)
        local badgeW = subFont:getWidth(catStr) + 6
        local badgeX = lw - badgeW - 6
        setColorSafe(catCol)
        love.graphics.setColor(catCol[1], catCol[2], catCol[3], 0.3)
        drawRoundedRect("fill", badgeX, iy + 19, badgeW, 14, 3)
        setColorSafe(catCol)
        love.graphics.print(catStr, badgeX + 3, iy + 19)
    end

    self.bookListScroll:endDraw()

    self._bookListRect = { x = lx, y = ly, w = lw, h = lh }
    self._filteredBooks = filtered
end

-- =========================================================================
-- Center Panel
-- =========================================================================

function Editor:_drawCenter(cx, cy, cw, ch)
    setColorSafe(Theme.colors.bgDark)
    love.graphics.rectangle("fill", cx, cy, cw, ch)

    if not self.selectedBook then
        local font = FontCache.get(16)
        love.graphics.setFont(font)
        setColorSafe(Theme.colors.textDim)
        local msg = "Select or create a book"
        love.graphics.print(msg, cx + (cw - font:getWidth(msg)) / 2, cy + ch / 2 - 10)
        return
    end

    -- Toolbar
    local toolbarH = 30
    self:_drawCenterToolbar(cx, cy, cw, toolbarH)

    -- Metadata section
    local metaY = cy + toolbarH
    local metaH = METADATA_H
    self:_drawMetadata(cx, metaY, cw, metaH)

    -- Separator
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", cx, metaY + metaH, cw, 1)

    -- Content editor
    local contentY = metaY + metaH + 1
    local contentH = ch - toolbarH - metaH - 1
    if contentH < 40 then contentH = 40 end
    self:_drawContentEditor(cx, contentY, cw, contentH)
end

function Editor:_drawCenterToolbar(tx, ty, tw, th)
    setColorSafe(Theme.colors.panelHeader)
    love.graphics.rectangle("fill", tx, ty, tw, th)
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", tx, ty + th - 1, tw, 1)

    local pad = Theme.spacing.sm
    local btnH = th - 4
    local bx = tx + pad

    self.undoBtn:draw(bx, ty + 2, 50, btnH)
    bx = bx + 54
    self.redoBtn:draw(bx, ty + 2, 50, btnH)

    self._centerToolbarRect = { x = tx, y = ty, w = tw, h = th }
end

function Editor:_drawMetadata(mx, my, mw, mh)
    setColorSafe(Theme.colors.panel)
    love.graphics.rectangle("fill", mx, my, mw, mh)

    local pad = Theme.spacing.md
    local labelFont = FontCache.get(11)
    local colW = math.floor((mw - pad * 3) / 2)
    local inputH = Theme.sizes.inputHeight
    local rowH = inputH + 18

    -- Left column
    local lx = mx + pad
    local cy = my + pad

    love.graphics.setFont(labelFont)
    setColorSafe(Theme.colors.textDim)
    love.graphics.print("ID", lx, cy)
    self.idInput:draw(lx, cy + 14, colW, inputH)
    cy = cy + rowH

    setColorSafe(Theme.colors.textDim)
    love.graphics.print("Title", lx, cy)
    self.titleInput:draw(lx, cy + 14, colW, inputH)
    cy = cy + rowH

    setColorSafe(Theme.colors.textDim)
    love.graphics.print("Author", lx, cy)
    self.authorInput:draw(lx, cy + 14, colW, inputH)
    cy = cy + rowH

    setColorSafe(Theme.colors.textDim)
    love.graphics.print("Category", lx, cy)
    self:_drawDropdownButton(self.metaCategoryDropdown, lx, cy + 14, math.floor(colW * 0.48), 22, nil)
    setColorSafe(Theme.colors.textDim)
    love.graphics.print("Rarity", lx + math.floor(colW * 0.52), cy)
    self:_drawDropdownButton(self.metaRarityDropdown, lx + math.floor(colW * 0.52), cy + 14, math.floor(colW * 0.48), 22, nil)

    -- Right column
    local rx = mx + pad * 2 + colW
    cy = my + pad

    setColorSafe(Theme.colors.textDim)
    love.graphics.setFont(labelFont)
    love.graphics.print("Condition", rx, cy)
    self.conditionInput:draw(rx, cy + 14, colW, inputH)
    cy = cy + rowH

    setColorSafe(Theme.colors.textDim)
    love.graphics.print("Find Location", rx, cy)
    self.findLocationInput:draw(rx, cy + 14, colW, inputH)
    cy = cy + rowH

    -- Dungeon floor + codex row
    setColorSafe(Theme.colors.textDim)
    love.graphics.print("Floor: " .. (self.selectedBook and self.selectedBook.dungeonFloor or 0), rx, cy + 2)
    local dimBtnW = 22
    local dimBtnH = 20
    self.floorDownBtn:draw(rx + 60, cy, dimBtnW, dimBtnH)
    self.floorUpBtn:draw(rx + 60 + dimBtnW + 2, cy, dimBtnW, dimBtnH)

    -- Codex toggle + order
    local codexX = rx + 140
    self.codexToggle:draw(codexX, cy - 2, colW - 140, dimBtnH + 4)
    cy = cy + rowH

    if self.selectedBook and self.selectedBook.partOfCodex then
        setColorSafe(Theme.colors.textDim)
        love.graphics.print("Codex Order: " .. (self.selectedBook.codexOrder or 0), rx, cy + 2)
        self.codexOrderDownBtn:draw(rx + 90, cy, dimBtnW, dimBtnH)
        self.codexOrderUpBtn:draw(rx + 90 + dimBtnW + 2, cy, dimBtnW, dimBtnH)
    end

    -- Discovered text (full width, below columns)
    local discY = my + mh - inputH - pad - 14
    setColorSafe(Theme.colors.textDim)
    love.graphics.setFont(labelFont)
    love.graphics.print("Discovered Text", mx + pad, discY)
    self.discoveredTextInput:draw(mx + pad, discY + 14, mw - pad * 2, inputH)

    self._metadataRect = { x = mx, y = my, w = mw, h = mh }
end

-- =========================================================================
-- Multiline Content Editor
-- =========================================================================

function Editor:_drawContentEditor(cx, cy, cw, ch)
    local te = self.textEditor
    te._lastX = cx
    te._lastY = cy
    te._lastW = cw
    te._lastH = ch

    -- Background
    setColorSafe(Theme.colors.input)
    love.graphics.rectangle("fill", cx, cy, cw, ch)

    -- Border
    if te.focused then
        setColorSafe(Theme.colors.inputFocus)
    else
        setColorSafe(Theme.colors.inputBorder)
    end
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", cx + 0.5, cy + 0.5, cw - 1, ch - 1)

    local pad = Theme.spacing.md
    local lineNumW = 40
    local textX = cx + lineNumW + pad
    local textW = cw - lineNumW - pad * 2
    if textW < 10 then textW = 10 end

    -- Use monospace-style font
    local font = FontCache.get(13)
    love.graphics.setFont(font)
    local lineH = font:getHeight() + 2
    local totalContentH = #te.lines * lineH
    local visibleLines = math.floor(ch / lineH) + 1

    -- Clamp scroll
    local maxScroll = math.max(0, totalContentH - ch + pad)
    te.scrollY = clamp(te.scrollY, 0, maxScroll)

    -- Scissor for content area
    love.graphics.setScissor(cx, cy, cw, ch)

    -- Draw visible lines
    local startLine = math.floor(te.scrollY / lineH) + 1
    local endLine = math.min(startLine + visibleLines, #te.lines)

    for i = startLine, endLine do
        local lineY = cy + (i - 1) * lineH - te.scrollY

        -- Line number gutter
        setColorSafe(Theme.colors.bgLight)
        love.graphics.rectangle("fill", cx, lineY, lineNumW, lineH)
        setColorSafe(Theme.colors.textDark)
        local numStr = tostring(i)
        love.graphics.print(numStr, cx + lineNumW - font:getWidth(numStr) - 4, lineY + 1)

        -- Line text
        local lineText = te.lines[i] or ""
        setColorSafe(Theme.colors.text)
        love.graphics.print(lineText, textX, lineY + 1)
    end

    -- Gutter separator
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", cx + lineNumW, cy, 1, ch)

    -- Cursor
    if te.focused and te.cursorBlink < 0.5 then
        local curLine = te.cursorLine
        if curLine >= 1 and curLine <= #te.lines then
            local cursorY = cy + (curLine - 1) * lineH - te.scrollY
            local lineText = te.lines[curLine] or ""
            local cursorPx = font:getWidth(lineText:sub(1, te.cursorCol))
            local cursorX = textX + cursorPx

            setColorSafe(Theme.colors.text)
            love.graphics.rectangle("fill", cursorX, cursorY + 1, 1, lineH - 2)
        end
    end

    -- Scrollbar
    if totalContentH > ch then
        local sbW = Theme.sizes.scrollbarWidth
        local sbX = cx + cw - sbW
        local ratio = ch / totalContentH
        local thumbH = math.max(20, ratio * ch)
        local scrollRatio = maxScroll > 0 and (te.scrollY / maxScroll) or 0
        local thumbY = cy + scrollRatio * (ch - thumbH)

        setColorSafe(Theme.colors.scrollbar)
        love.graphics.rectangle("fill", sbX, cy, sbW, ch)
        setColorSafe(Theme.colors.scrollbarThumb)
        drawRoundedRect("fill", sbX + 1, thumbY, sbW - 2, thumbH, (sbW - 2) / 2)
    end

    love.graphics.setScissor()

    self._contentEditorRect = { x = cx, y = cy, w = cw, h = ch,
        textX = textX, textW = textW, lineH = lineH, lineNumW = lineNumW }
end

-- =========================================================================
-- Text editor input handling
-- =========================================================================

function Editor:_teEnsureCursorVisible()
    local te = self.textEditor
    local cer = self._contentEditorRect
    if not cer then return end
    local lineH = cer.lineH
    local cursorY = (te.cursorLine - 1) * lineH
    if cursorY < te.scrollY then
        te.scrollY = cursorY
    end
    if cursorY + lineH > te.scrollY + cer.h then
        te.scrollY = cursorY + lineH - cer.h
    end
end

function Editor:_teSyncContent()
    if self.selectedBook then
        local newContent = textFromLines(self.textEditor.lines)
        self:_setContent(newContent)
    end
end

function Editor:_teHandleKeypressed(key)
    local te = self.textEditor
    if not te.focused then return false end

    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
    local lines = te.lines
    local cl = te.cursorLine
    local cc = te.cursorCol

    if key == "return" or key == "kpenter" then
        -- Split line at cursor
        local line = lines[cl] or ""
        local before = line:sub(1, cc)
        local after = line:sub(cc + 1)
        lines[cl] = before
        table.insert(lines, cl + 1, after)
        te.cursorLine = cl + 1
        te.cursorCol = 0
        te.cursorBlink = 0
        self:_teEnsureCursorVisible()
        self:_teSyncContent()
        return true

    elseif key == "backspace" then
        if cc > 0 then
            local line = lines[cl] or ""
            lines[cl] = line:sub(1, cc - 1) .. line:sub(cc + 1)
            te.cursorCol = cc - 1
        elseif cl > 1 then
            -- Merge with previous line
            local prevLine = lines[cl - 1] or ""
            local curLine = lines[cl] or ""
            te.cursorCol = #prevLine
            lines[cl - 1] = prevLine .. curLine
            table.remove(lines, cl)
            te.cursorLine = cl - 1
        end
        te.cursorBlink = 0
        self:_teEnsureCursorVisible()
        self:_teSyncContent()
        return true

    elseif key == "delete" then
        local line = lines[cl] or ""
        if cc < #line then
            lines[cl] = line:sub(1, cc) .. line:sub(cc + 2)
        elseif cl < #lines then
            -- Merge with next line
            lines[cl] = line .. (lines[cl + 1] or "")
            table.remove(lines, cl + 1)
        end
        te.cursorBlink = 0
        self:_teSyncContent()
        return true

    elseif key == "left" then
        if cc > 0 then
            te.cursorCol = cc - 1
        elseif cl > 1 then
            te.cursorLine = cl - 1
            te.cursorCol = #(lines[cl - 1] or "")
        end
        te.cursorBlink = 0
        self:_teEnsureCursorVisible()
        return true

    elseif key == "right" then
        local line = lines[cl] or ""
        if cc < #line then
            te.cursorCol = cc + 1
        elseif cl < #lines then
            te.cursorLine = cl + 1
            te.cursorCol = 0
        end
        te.cursorBlink = 0
        self:_teEnsureCursorVisible()
        return true

    elseif key == "up" then
        if cl > 1 then
            te.cursorLine = cl - 1
            te.cursorCol = math.min(cc, #(lines[cl - 1] or ""))
        end
        te.cursorBlink = 0
        self:_teEnsureCursorVisible()
        return true

    elseif key == "down" then
        if cl < #lines then
            te.cursorLine = cl + 1
            te.cursorCol = math.min(cc, #(lines[cl + 1] or ""))
        end
        te.cursorBlink = 0
        self:_teEnsureCursorVisible()
        return true

    elseif key == "home" then
        te.cursorCol = 0
        te.cursorBlink = 0
        self:_teEnsureCursorVisible()
        return true

    elseif key == "end" then
        te.cursorCol = #(lines[cl] or "")
        te.cursorBlink = 0
        self:_teEnsureCursorVisible()
        return true

    elseif key == "pageup" then
        local cer = self._contentEditorRect
        local jump = cer and math.floor(cer.h / (cer.lineH or 16)) or 10
        te.cursorLine = math.max(1, cl - jump)
        te.cursorCol = math.min(cc, #(lines[te.cursorLine] or ""))
        te.cursorBlink = 0
        self:_teEnsureCursorVisible()
        return true

    elseif key == "pagedown" then
        local cer = self._contentEditorRect
        local jump = cer and math.floor(cer.h / (cer.lineH or 16)) or 10
        te.cursorLine = math.min(#lines, cl + jump)
        te.cursorCol = math.min(cc, #(lines[te.cursorLine] or ""))
        te.cursorBlink = 0
        self:_teEnsureCursorVisible()
        return true

    elseif ctrl and key == "a" then
        -- Select all: move cursor to end
        te.cursorLine = #lines
        te.cursorCol = #(lines[#lines] or "")
        te.cursorBlink = 0
        return true

    elseif ctrl and key == "c" then
        -- Copy all content to clipboard
        local content = textFromLines(lines)
        if #content > 0 then
            love.system.setClipboardText(content)
        end
        return true

    elseif ctrl and key == "v" then
        local clip = love.system.getClipboardText() or ""
        if #clip > 0 then
            -- Insert pasted text at cursor
            local clipLines = linesToText(clip)
            local line = lines[cl] or ""
            local before = line:sub(1, cc)
            local after = line:sub(cc + 1)

            if #clipLines == 1 then
                lines[cl] = before .. clipLines[1] .. after
                te.cursorCol = #before + #clipLines[1]
            else
                lines[cl] = before .. clipLines[1]
                for j = 2, #clipLines - 1 do
                    table.insert(lines, cl + j - 1, clipLines[j])
                end
                table.insert(lines, cl + #clipLines - 1, clipLines[#clipLines] .. after)
                te.cursorLine = cl + #clipLines - 1
                te.cursorCol = #clipLines[#clipLines]
            end
            te.cursorBlink = 0
            self:_teEnsureCursorVisible()
            self:_teSyncContent()
        end
        return true
    end

    return false
end

function Editor:_teHandleTextinput(t)
    local te = self.textEditor
    if not te.focused then return false end

    local lines = te.lines
    local cl = te.cursorLine
    local cc = te.cursorCol
    local line = lines[cl] or ""

    lines[cl] = line:sub(1, cc) .. t .. line:sub(cc + 1)
    te.cursorCol = cc + #t
    te.cursorBlink = 0
    self:_teSyncContent()
    return true
end

function Editor:_teHandleMousepressed(mx, my, button)
    local cer = self._contentEditorRect
    if not cer then return false end
    if not pointInRect(mx, my, cer.x, cer.y, cer.w, cer.h) then
        if self.textEditor.focused then
            self.textEditor.focused = false
            if UI.getFocus() == self.textEditor then
                UI.clearFocus()
            end
        end
        return false
    end

    if button ~= 1 then return false end

    local te = self.textEditor
    te.focused = true
    te.cursorBlink = 0

    -- Calculate clicked line and column
    local lineH = cer.lineH
    local relY = my - cer.y + te.scrollY
    local clickLine = math.floor(relY / lineH) + 1
    clickLine = clamp(clickLine, 1, #te.lines)

    local font = FontCache.get(13)
    local line = te.lines[clickLine] or ""
    local relX = mx - cer.textX
    if relX < 0 then relX = 0 end

    -- Find closest column
    local bestCol = 0
    for c = 0, #line do
        local pw = font:getWidth(line:sub(1, c))
        if pw <= relX then
            bestCol = c
        else
            -- Check if this column is closer
            local prevW = font:getWidth(line:sub(1, c - 1))
            if (relX - prevW) > (pw - relX) then
                bestCol = c
            end
            break
        end
        if c == #line then bestCol = c end
    end

    te.cursorLine = clickLine
    te.cursorCol = bestCol
    return true
end

-- =========================================================================
-- Right Panel (Preview)
-- =========================================================================

function Editor:_drawRightPanel(rx, ry, rw, rh)
    setColorSafe(Theme.colors.panel)
    love.graphics.rectangle("fill", rx, ry, rw, rh)

    local pad = Theme.spacing.md
    local cy = ry + pad
    local innerW = rw - pad * 2

    -- Header
    local headerFont = FontCache.get(13)
    love.graphics.setFont(headerFont)
    setColorSafe(Theme.colors.textAccent)
    love.graphics.print("Book Preview", rx + pad, cy)
    cy = cy + headerFont:getHeight() + pad

    if not self.selectedBook then
        local font = FontCache.get(11)
        love.graphics.setFont(font)
        setColorSafe(Theme.colors.textDim)
        love.graphics.printf("No book selected", rx + pad, cy, innerW, "center")
        return
    end

    local book = self.selectedBook

    -- Preview area with scroll
    local previewH = ry + rh - cy - pad
    if previewH < 40 then previewH = 40 end

    -- Calculate preview content height
    local titleFont = FontCache.get(14)
    local authorFont = FontCache.get(11)
    local contentFont = FontCache.get(11)
    local badgeH = 20
    local previewPad = 8

    local contentH = previewPad
    -- Title
    local titleWrapped = self:_wrapText(titleFont, book.title or "", innerW - previewPad * 2)
    contentH = contentH + #titleWrapped * titleFont:getHeight() + 4
    -- Author
    contentH = contentH + authorFont:getHeight() + 6
    -- Badges
    contentH = contentH + badgeH + 8
    -- Separator
    contentH = contentH + pad
    -- Content text
    local contentWrapped = self:_wrapText(contentFont, book.content or "", innerW - previewPad * 2)
    contentH = contentH + #contentWrapped * contentFont:getHeight() + previewPad

    self.previewScroll:setContentHeight(contentH)

    -- Book page background
    setColorSafe(Theme.colors.bgLight)
    drawRoundedRect("fill", rx + pad, cy, innerW, previewH, Theme.radius.sm)
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.setLineWidth(1)
    drawRoundedRect("line", rx + pad + 0.5, cy + 0.5, innerW - 1, previewH - 1, Theme.radius.sm)

    self.previewScroll:beginDraw(rx + pad, cy, innerW, previewH)

    local drawY = previewPad

    -- Title in gold/accent
    love.graphics.setFont(titleFont)
    setColorSafe(Theme.colors.textAccent)
    for _, line in ipairs(titleWrapped) do
        love.graphics.print(line, previewPad, drawY)
        drawY = drawY + titleFont:getHeight()
    end
    drawY = drawY + 4

    -- Author in dim
    love.graphics.setFont(authorFont)
    setColorSafe(Theme.colors.textDim)
    local authorStr = book.author and book.author ~= "" and ("by " .. book.author) or ""
    love.graphics.print(authorStr, previewPad, drawY)
    drawY = drawY + authorFont:getHeight() + 6

    -- Badges
    local badgeFont = FontCache.get(10)
    love.graphics.setFont(badgeFont)
    local bx = previewPad

    -- Category badge
    local catCol = getCategoryColor(book.category)
    local catStr = book.category or ""
    local catBadgeW = badgeFont:getWidth(catStr) + 8
    love.graphics.setColor(catCol[1], catCol[2], catCol[3], 0.3)
    drawRoundedRect("fill", bx, drawY, catBadgeW, badgeH - 4, 3)
    setColorSafe(catCol)
    love.graphics.print(catStr, bx + 4, drawY + 2)
    bx = bx + catBadgeW + 4

    -- Rarity badge
    local rarCol = getRarityColor(book.rarity)
    local rarStr = book.rarity or ""
    local rarBadgeW = badgeFont:getWidth(rarStr) + 8
    love.graphics.setColor(rarCol[1], rarCol[2], rarCol[3], 0.3)
    drawRoundedRect("fill", bx, drawY, rarBadgeW, badgeH - 4, 3)
    setColorSafe(rarCol)
    love.graphics.print(rarStr, bx + 4, drawY + 2)
    drawY = drawY + badgeH + 4

    -- Separator line
    setColorSafe(Theme.colors.panelBorder)
    love.graphics.rectangle("fill", previewPad, drawY, innerW - previewPad * 2, 1)
    drawY = drawY + pad

    -- Content text
    love.graphics.setFont(contentFont)
    setColorSafe(Theme.colors.text)
    for _, line in ipairs(contentWrapped) do
        love.graphics.print(line, previewPad, drawY)
        drawY = drawY + contentFont:getHeight()
    end

    self.previewScroll:endDraw()

    self._previewRect = { x = rx + pad, y = cy, w = innerW, h = previewH }
end

function Editor:_wrapText(font, text, maxW)
    if maxW < 10 then maxW = 10 end
    local wrapped = {}
    -- Split by newlines first
    for rawLine in (text .. "\n"):gmatch("([^\n]*)\n") do
        if rawLine == "" then
            wrapped[#wrapped + 1] = ""
        else
            -- Wrap long lines
            local remaining = rawLine
            while #remaining > 0 do
                if font:getWidth(remaining) <= maxW then
                    wrapped[#wrapped + 1] = remaining
                    remaining = ""
                else
                    -- Find a break point
                    local breakPos = #remaining
                    for j = 1, #remaining do
                        if font:getWidth(remaining:sub(1, j)) > maxW then
                            breakPos = j - 1
                            -- Try to break at a space
                            local spacePos = remaining:sub(1, breakPos):match(".*()%s")
                            if spacePos and spacePos > 1 then
                                breakPos = spacePos
                            end
                            break
                        end
                    end
                    if breakPos < 1 then breakPos = 1 end
                    wrapped[#wrapped + 1] = remaining:sub(1, breakPos)
                    remaining = remaining:sub(breakPos + 1)
                    -- Trim leading space
                    if remaining:sub(1, 1) == " " then
                        remaining = remaining:sub(2)
                    end
                end
            end
        end
    end
    if #wrapped == 0 then wrapped[1] = "" end
    return wrapped
end

-- =========================================================================
-- Input: mousepressed
-- =========================================================================

function Editor:mousepressed(mx, my, button)
    if button ~= 1 then return false end

    -- Close dropdown if clicking outside it
    if self._activeDropdown and self._activeDropdown.open then
        local dd = self._activeDropdown
        if dd._overlayRect and pointInRect(mx, my, dd._overlayRect.x, dd._overlayRect.y,
                dd._overlayRect.w, dd._overlayRect.h) then
            -- Click inside overlay - handle selection
            local itemH = 22
            local relY = my - dd._overlayRect.y
            local idx = math.floor(relY / itemH)  -- 0 = "All", 1+ = options

            if idx == 0 then
                dd.value = nil
            elseif idx >= 1 and idx <= #dd.options then
                dd.value = dd.options[idx]
            end

            -- Apply filter
            if dd == self.categoryDropdown then
                self.filterCategory = dd.value
            elseif dd == self.rarityDropdown then
                self.filterRarity = dd.value
            elseif dd == self.metaCategoryDropdown and self.selectedBook then
                self:_setField("category", dd.value or "historical")
            elseif dd == self.metaRarityDropdown and self.selectedBook then
                self:_setField("rarity", dd.value or "common")
            end

            dd.open = false
            self._activeDropdown = nil
            return true
        else
            -- Click outside -- close
            dd.open = false
            self._activeDropdown = nil
            -- Fall through to handle other clicks
        end
    end

    -- Text inputs
    for _, inp in ipairs(self._textInputs) do
        if inp:mousepressed(mx, my, button) then return true end
    end

    -- Buttons
    if self.addBtn:mousepressed(mx, my, button) then return true end
    if self.deleteBtn:mousepressed(mx, my, button) then return true end
    if self.dupBtn:mousepressed(mx, my, button) then return true end
    if self.undoBtn:mousepressed(mx, my, button) then return true end
    if self.redoBtn:mousepressed(mx, my, button) then return true end
    if self.floorDownBtn:mousepressed(mx, my, button) then return true end
    if self.floorUpBtn:mousepressed(mx, my, button) then return true end
    if self.codexOrderDownBtn:mousepressed(mx, my, button) then return true end
    if self.codexOrderUpBtn:mousepressed(mx, my, button) then return true end

    -- Codex toggle
    if self.codexToggle:mousepressed(mx, my, button) then return true end

    -- Dropdown buttons
    local function tryDropdown(dd)
        if pointInRect(mx, my, dd._lastX, dd._lastY, dd._lastW, dd._lastH) then
            dd.open = not dd.open
            if dd.open then
                self._activeDropdown = dd
            else
                self._activeDropdown = nil
            end
            return true
        end
        return false
    end
    if tryDropdown(self.categoryDropdown) then return true end
    if tryDropdown(self.rarityDropdown) then return true end
    if tryDropdown(self.metaCategoryDropdown) then return true end
    if tryDropdown(self.metaRarityDropdown) then return true end

    -- Book list
    if self._bookListRect and self._filteredBooks then
        local blr = self._bookListRect
        if pointInRect(mx, my, blr.x, blr.y, blr.w, blr.h) then
            if self.bookListScroll:mousepressed(mx, my, button) then return true end
            local relY = my - blr.y + self.bookListScroll.scrollY
            local itemH = 36
            local idx = math.floor(relY / itemH) + 1
            if idx >= 1 and idx <= #self._filteredBooks then
                self:_selectBook(self._filteredBooks[idx].index)
            end
            return true
        end
    end

    -- Content editor
    if self:_teHandleMousepressed(mx, my, button) then return true end

    -- Preview scroll
    if self._previewRect then
        if pointInRect(mx, my, self._previewRect.x, self._previewRect.y,
                self._previewRect.w, self._previewRect.h) then
            if self.previewScroll:mousepressed(mx, my, button) then return true end
        end
    end

    return false
end

-- =========================================================================
-- Input: mousereleased
-- =========================================================================

function Editor:mousereleased(mx, my, button)
    if button ~= 1 then return false end

    self.addBtn:mousereleased(mx, my, button)
    self.deleteBtn:mousereleased(mx, my, button)
    self.dupBtn:mousereleased(mx, my, button)
    self.undoBtn:mousereleased(mx, my, button)
    self.redoBtn:mousereleased(mx, my, button)
    self.floorDownBtn:mousereleased(mx, my, button)
    self.floorUpBtn:mousereleased(mx, my, button)
    self.codexOrderDownBtn:mousereleased(mx, my, button)
    self.codexOrderUpBtn:mousereleased(mx, my, button)

    self.bookListScroll:mousereleased(mx, my, button)
    self.previewScroll:mousereleased(mx, my, button)

    return false
end

-- =========================================================================
-- Input: wheelmoved
-- =========================================================================

function Editor:wheelmoved(wx, wy)
    local mx, my = love.mouse.getPosition()

    -- Book list scroll
    if self._bookListRect and pointInRect(mx, my,
            self._bookListRect.x, self._bookListRect.y,
            self._bookListRect.w, self._bookListRect.h) then
        self.bookListScroll:wheelmoved(wx, wy)
        return true
    end

    -- Content editor scroll
    local cer = self._contentEditorRect
    if cer and pointInRect(mx, my, cer.x, cer.y, cer.w, cer.h) then
        local te = self.textEditor
        local lineH = cer.lineH or 16
        te.scrollY = te.scrollY - wy * lineH * 3
        local totalH = #te.lines * lineH
        local maxScroll = math.max(0, totalH - cer.h + Theme.spacing.md)
        te.scrollY = clamp(te.scrollY, 0, maxScroll)
        return true
    end

    -- Preview scroll
    if self._previewRect and pointInRect(mx, my,
            self._previewRect.x, self._previewRect.y,
            self._previewRect.w, self._previewRect.h) then
        self.previewScroll:wheelmoved(wx, wy)
        return true
    end

    return false
end

-- =========================================================================
-- Input: keypressed
-- =========================================================================

function Editor:keypressed(key)
    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")

    -- Global undo/redo
    if ctrl and key == "z" then
        self.undoStack:undo()
        return true
    end
    if ctrl and key == "y" then
        self.undoStack:redo()
        return true
    end

    -- Content editor keys
    if self.textEditor.focused then
        if self:_teHandleKeypressed(key) then return true end
    end

    -- Text input fields
    for _, inp in ipairs(self._textInputs) do
        if inp:keypressed(key) then return true end
    end

    return false
end

-- =========================================================================
-- Input: textinput
-- =========================================================================

function Editor:textinput(t)
    -- Content editor
    if self.textEditor.focused then
        if self:_teHandleTextinput(t) then return true end
    end

    -- Text input fields
    for _, inp in ipairs(self._textInputs) do
        if inp:textinput(t) then return true end
    end

    return false
end

return Editor
