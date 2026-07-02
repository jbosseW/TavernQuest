-- lua_parser.lua - Lua Source Code Parser for Table Extraction
-- Extracts table blocks from Lua source code without executing the full file.
-- Handles nested tables, string literals, comments, and long strings.

local LuaParser = {}

-- ============================================================================
-- INTERNAL HELPERS
-- ============================================================================

-- Determine the level of a long string/comment opening bracket.
-- pos should point to the first '[' in the source.
-- Returns the level (number of '=' signs) or nil if not a valid long bracket.
local function longBracketLevel(source, pos)
    if source:sub(pos, pos) ~= "[" then return nil end
    local i = pos + 1
    while i <= #source and source:sub(i, i) == "=" do
        i = i + 1
    end
    if i <= #source and source:sub(i, i) == "[" then
        return i - pos - 1 -- number of '=' signs
    end
    return nil
end

-- Find the closing long bracket at a given level starting from pos.
-- Returns the position AFTER the closing bracket, or nil if not found.
local function findLongBracketClose(source, pos, level)
    local closer = "]" .. string.rep("=", level) .. "]"
    local idx = source:find(closer, pos, true) -- plain search
    if idx then
        return idx + #closer
    end
    return nil
end

-- Skip whitespace and comments starting at pos.
-- Returns the next non-whitespace, non-comment position.
local function skipWhitespaceAndComments(source, pos)
    local len = #source
    while pos <= len do
        local ch = source:sub(pos, pos)

        -- Skip whitespace
        if ch == " " or ch == "\t" or ch == "\n" or ch == "\r" then
            pos = pos + 1

        -- Check for comments
        elseif ch == "-" and source:sub(pos + 1, pos + 1) == "-" then
            -- Comment found
            pos = pos + 2
            -- Check for long comment --[[ ... ]]
            local level = longBracketLevel(source, pos)
            if level then
                local closePos = findLongBracketClose(source, pos + level + 2, level)
                if closePos then
                    pos = closePos
                else
                    -- Unterminated long comment; skip to end
                    pos = len + 1
                end
            else
                -- Single-line comment: skip to end of line
                local eol = source:find("\n", pos)
                if eol then
                    pos = eol + 1
                else
                    pos = len + 1
                end
            end
        else
            break
        end
    end
    return pos
end

-- ============================================================================
-- CORE: Find matching closing brace
-- ============================================================================

--- Find the position of the closing '}' that matches an opening '{'.
--- startPos should be the position AFTER the opening '{'.
--- Returns the position of the matching '}', or nil if not found.
function LuaParser.findMatchingBrace(source, startPos)
    local len = #source
    local depth = 1
    local pos = startPos

    while pos <= len and depth > 0 do
        local ch = source:sub(pos, pos)

        if ch == "{" then
            depth = depth + 1
            pos = pos + 1

        elseif ch == "}" then
            depth = depth - 1
            if depth == 0 then
                return pos
            end
            pos = pos + 1

        elseif ch == '"' then
            -- Double-quoted string: skip to closing quote, handling escapes
            pos = pos + 1
            while pos <= len do
                local sc = source:sub(pos, pos)
                if sc == "\\" then
                    pos = pos + 2 -- skip escaped character
                elseif sc == '"' then
                    pos = pos + 1
                    break
                elseif sc == "\n" then
                    -- Unterminated string (newline before closing quote)
                    pos = pos + 1
                    break
                else
                    pos = pos + 1
                end
            end

        elseif ch == "'" then
            -- Single-quoted string: skip to closing quote, handling escapes
            pos = pos + 1
            while pos <= len do
                local sc = source:sub(pos, pos)
                if sc == "\\" then
                    pos = pos + 2
                elseif sc == "'" then
                    pos = pos + 1
                    break
                elseif sc == "\n" then
                    pos = pos + 1
                    break
                else
                    pos = pos + 1
                end
            end

        elseif ch == "[" then
            -- Check for long string [[ ... ]] or [=[ ... ]=]
            local level = longBracketLevel(source, pos)
            if level then
                local closePos = findLongBracketClose(source, pos + level + 2, level)
                if closePos then
                    pos = closePos
                else
                    pos = len + 1
                end
            else
                pos = pos + 1
            end

        elseif ch == "-" and pos + 1 <= len and source:sub(pos + 1, pos + 1) == "-" then
            -- Comment
            pos = pos + 2
            local level = longBracketLevel(source, pos)
            if level then
                -- Block comment --[[ ... ]]
                local closePos = findLongBracketClose(source, pos + level + 2, level)
                if closePos then
                    pos = closePos
                else
                    pos = len + 1
                end
            else
                -- Line comment: skip to end of line
                local eol = source:find("\n", pos)
                if eol then
                    pos = eol + 1
                else
                    pos = len + 1
                end
            end
        else
            pos = pos + 1
        end
    end

    if depth == 0 then
        -- Should not reach here; the return inside the loop handles it
        return pos
    end
    return nil -- unmatched brace
end

-- ============================================================================
-- TABLE EXTRACTION
-- ============================================================================

--- Find a pattern like `tableName = {` or `tableName={` in source.
--- tableName can be dotted like "Backpack.ITEMS" or "Data.ENEMIES".
--- Returns the raw string of the table including outer braces, or nil + error.
function LuaParser.extractTable(source, tableName)
    -- Escape dots in tableName for pattern matching
    local escaped = tableName:gsub("%.", "%%.")
    -- Pattern: tableName followed by optional whitespace, '=', optional whitespace, '{'
    local pattern = escaped .. "%s*=%s*{"
    local matchStart, matchEnd = source:find(pattern)
    if not matchStart then
        return nil, "Table '" .. tableName .. "' not found in source"
    end

    -- Find the position of the '{' in the match
    local bracePos = source:find("{", matchStart)
    if not bracePos then
        return nil, "Opening brace not found for '" .. tableName .. "'"
    end

    -- Find the matching '}'
    local closePos = LuaParser.findMatchingBrace(source, bracePos + 1)
    if not closePos then
        return nil, "No matching closing brace for '" .. tableName .. "'"
    end

    return source:sub(bracePos, closePos)
end

--- Extract a local variable table: `local NAME = {`
--- Returns the raw string of the table including outer braces, or nil + error.
function LuaParser.extractLocalTable(source, varName)
    local escaped = varName:gsub("%.", "%%.")
    -- Pattern: local <optional whitespace> varName <optional ws> = <optional ws> {
    local pattern = "local%s+" .. escaped .. "%s*=%s*{"
    local matchStart, matchEnd = source:find(pattern)
    if not matchStart then
        return nil, "Local table '" .. varName .. "' not found in source"
    end

    local bracePos = source:find("{", matchStart)
    if not bracePos then
        return nil, "Opening brace not found for local '" .. varName .. "'"
    end

    local closePos = LuaParser.findMatchingBrace(source, bracePos + 1)
    if not closePos then
        return nil, "No matching closing brace for local '" .. varName .. "'"
    end

    return source:sub(bracePos, closePos)
end

-- ============================================================================
-- SAFE TABLE EVALUATION
-- ============================================================================

--- Strip function definitions from a table string so it can be safely evaluated.
--- Replaces `function(...) ... end` with `nil`.
--- This is conservative and handles nested function/end pairs.
local function stripFunctions(str)
    -- We need to handle nested function...end blocks.
    -- Strategy: scan for "function" keyword (not inside a string) and find matching "end".
    local result = {}
    local pos = 1
    local len = #str

    while pos <= len do
        local ch = str:sub(pos, pos)

        -- Skip strings
        if ch == '"' or ch == "'" then
            local quote = ch
            local start = pos
            pos = pos + 1
            while pos <= len do
                local sc = str:sub(pos, pos)
                if sc == "\\" then
                    pos = pos + 2
                elseif sc == quote then
                    pos = pos + 1
                    break
                else
                    pos = pos + 1
                end
            end
            table.insert(result, str:sub(start, pos - 1))

        elseif ch == "[" then
            local level = longBracketLevel(str, pos)
            if level then
                local closePos = findLongBracketClose(str, pos + level + 2, level)
                if closePos then
                    table.insert(result, str:sub(pos, closePos - 1))
                    pos = closePos
                else
                    table.insert(result, str:sub(pos))
                    pos = len + 1
                end
            else
                table.insert(result, ch)
                pos = pos + 1
            end

        elseif ch == "-" and pos + 1 <= len and str:sub(pos + 1, pos + 1) == "-" then
            -- Comment: preserve it (it's harmless in eval)
            local level = longBracketLevel(str, pos + 2)
            if level then
                local closePos = findLongBracketClose(str, pos + 2 + level + 2, level)
                if closePos then
                    table.insert(result, str:sub(pos, closePos - 1))
                    pos = closePos
                else
                    table.insert(result, str:sub(pos))
                    pos = len + 1
                end
            else
                local eol = str:find("\n", pos)
                if eol then
                    table.insert(result, str:sub(pos, eol))
                    pos = eol + 1
                else
                    table.insert(result, str:sub(pos))
                    pos = len + 1
                end
            end

        -- Check for "function" keyword
        elseif str:sub(pos, pos + 7) == "function" then
            -- Make sure it is a word boundary (not part of another identifier)
            local before = pos > 1 and str:sub(pos - 1, pos - 1) or " "
            local after = pos + 8 <= len and str:sub(pos + 8, pos + 8) or " "
            local isWord = not before:match("[%w_]") and not after:match("[%w_]")

            if isWord then
                -- Find the matching "end" accounting for nested function/if/do/for/while/repeat blocks
                local depth = 1
                local scanPos = pos + 8
                while scanPos <= len and depth > 0 do
                    local sch = str:sub(scanPos, scanPos)

                    -- Skip strings inside functions
                    if sch == '"' or sch == "'" then
                        local q = sch
                        scanPos = scanPos + 1
                        while scanPos <= len do
                            local sc2 = str:sub(scanPos, scanPos)
                            if sc2 == "\\" then
                                scanPos = scanPos + 2
                            elseif sc2 == q then
                                scanPos = scanPos + 1
                                break
                            else
                                scanPos = scanPos + 1
                            end
                        end
                    elseif sch == "[" then
                        local lv = longBracketLevel(str, scanPos)
                        if lv then
                            local cp = findLongBracketClose(str, scanPos + lv + 2, lv)
                            scanPos = cp or (len + 1)
                        else
                            scanPos = scanPos + 1
                        end
                    elseif sch == "-" and scanPos + 1 <= len and str:sub(scanPos + 1, scanPos + 1) == "-" then
                        local lv = longBracketLevel(str, scanPos + 2)
                        if lv then
                            local cp = findLongBracketClose(str, scanPos + 2 + lv + 2, lv)
                            scanPos = cp or (len + 1)
                        else
                            local eol = str:find("\n", scanPos)
                            scanPos = eol and (eol + 1) or (len + 1)
                        end
                    else
                        -- Check for block-opening keywords
                        for _, kw in ipairs({"function", "if", "do", "for", "while", "repeat"}) do
                            if str:sub(scanPos, scanPos + #kw - 1) == kw then
                                local bef = scanPos > 1 and str:sub(scanPos - 1, scanPos - 1) or " "
                                local aft = scanPos + #kw <= len and str:sub(scanPos + #kw, scanPos + #kw) or " "
                                if not bef:match("[%w_]") and not aft:match("[%w_]") then
                                    if kw == "repeat" then
                                        depth = depth + 1
                                    else
                                        depth = depth + 1
                                    end
                                    scanPos = scanPos + #kw
                                    goto continue_scan
                                end
                            end
                        end
                        -- Check for "end" and "until" (closers)
                        if str:sub(scanPos, scanPos + 2) == "end" then
                            local bef = scanPos > 1 and str:sub(scanPos - 1, scanPos - 1) or " "
                            local aft = scanPos + 3 <= len and str:sub(scanPos + 3, scanPos + 3) or " "
                            if not bef:match("[%w_]") and not aft:match("[%w_]") then
                                depth = depth - 1
                                if depth == 0 then
                                    -- Replace function...end with nil
                                    table.insert(result, "nil")
                                    pos = scanPos + 3
                                    goto continue_outer
                                end
                                scanPos = scanPos + 3
                                goto continue_scan
                            end
                        end
                        if str:sub(scanPos, scanPos + 4) == "until" then
                            local bef = scanPos > 1 and str:sub(scanPos - 1, scanPos - 1) or " "
                            local aft = scanPos + 5 <= len and str:sub(scanPos + 5, scanPos + 5) or " "
                            if not bef:match("[%w_]") and not aft:match("[%w_]") then
                                depth = depth - 1
                                if depth == 0 then
                                    table.insert(result, "nil")
                                    pos = scanPos + 5
                                    goto continue_outer
                                end
                                scanPos = scanPos + 5
                                goto continue_scan
                            end
                        end
                        scanPos = scanPos + 1
                    end
                    ::continue_scan::
                end
                -- If we exhausted the string without matching, just insert "nil"
                if depth > 0 then
                    table.insert(result, "nil")
                    pos = len + 1
                end
            else
                table.insert(result, ch)
                pos = pos + 1
            end
        else
            table.insert(result, ch)
            pos = pos + 1
        end
        ::continue_outer::
    end

    return table.concat(result)
end

--- Replace references like `SomeModule.TABLE.KEY` with string placeholders.
--- This allows evaluation of tables that contain cross-references
--- (e.g., `findLocation = LoreBooks.LOCATIONS.BURIED_ARCHIVE`).
--- Returns the modified string and a reverse-lookup table.
local function stubExternalReferences(str)
    -- Replace patterns like: Identifier.Identifier.Identifier (dotted chains)
    -- that appear as VALUES (after = sign, or as array entries)
    -- but NOT inside strings.
    local result = {}
    local pos = 1
    local len = #str

    while pos <= len do
        local ch = str:sub(pos, pos)

        -- Skip strings
        if ch == '"' or ch == "'" then
            local quote = ch
            local start = pos
            pos = pos + 1
            while pos <= len do
                local sc = str:sub(pos, pos)
                if sc == "\\" then
                    pos = pos + 2
                elseif sc == quote then
                    pos = pos + 1
                    break
                else
                    pos = pos + 1
                end
            end
            table.insert(result, str:sub(start, pos - 1))

        elseif ch == "[" then
            local level = longBracketLevel(str, pos)
            if level then
                local closePos = findLongBracketClose(str, pos + level + 2, level)
                if closePos then
                    table.insert(result, str:sub(pos, closePos - 1))
                    pos = closePos
                else
                    table.insert(result, str:sub(pos))
                    pos = len + 1
                end
            else
                table.insert(result, ch)
                pos = pos + 1
            end

        elseif ch == "-" and pos + 1 <= len and str:sub(pos + 1, pos + 1) == "-" then
            -- Comment: copy through
            local level = longBracketLevel(str, pos + 2)
            if level then
                local closePos = findLongBracketClose(str, pos + 2 + level + 2, level)
                if closePos then
                    table.insert(result, str:sub(pos, closePos - 1))
                    pos = closePos
                else
                    table.insert(result, str:sub(pos))
                    pos = len + 1
                end
            else
                local eol = str:find("\n", pos)
                if eol then
                    table.insert(result, str:sub(pos, eol))
                    pos = eol + 1
                else
                    table.insert(result, str:sub(pos))
                    pos = len + 1
                end
            end

        elseif ch:match("[A-Za-z_]") then
            -- Potential identifier or dotted reference
            local idStart = pos
            -- Consume identifier
            while pos <= len and str:sub(pos, pos):match("[%w_]") do
                pos = pos + 1
            end
            local ident = str:sub(idStart, pos - 1)

            -- Check for dotted chain (e.g., LoreBooks.LOCATIONS.BURIED_ARCHIVE)
            -- Must have at least one dot to be treated as an external reference
            local hasDot = false
            local fullRef = ident
            while pos <= len and str:sub(pos, pos) == "." do
                local dotPos = pos
                pos = pos + 1
                -- Consume next identifier
                local nextStart = pos
                while pos <= len and str:sub(pos, pos):match("[%w_]") do
                    pos = pos + 1
                end
                if pos > nextStart then
                    fullRef = fullRef .. "." .. str:sub(nextStart, pos - 1)
                    hasDot = true
                else
                    -- Dot not followed by identifier; put the dot back
                    pos = dotPos
                    break
                end
            end

            -- Lua keywords and literals should pass through unchanged
            local LUA_LITERALS = {
                ["true"] = true, ["false"] = true, ["nil"] = true,
                ["and"] = true, ["or"] = true, ["not"] = true,
                ["local"] = true, ["return"] = true, ["end"] = true,
                ["if"] = true, ["then"] = true, ["else"] = true,
                ["elseif"] = true, ["do"] = true, ["for"] = true,
                ["while"] = true, ["repeat"] = true, ["until"] = true,
                ["in"] = true, ["break"] = true, ["goto"] = true,
                ["function"] = true,
            }

            -- Sandbox-available modules that should NOT be stringified
            local SANDBOX_NAMES = {
                ["math"] = true, ["string"] = true, ["table"] = true,
                ["tonumber"] = true, ["tostring"] = true, ["type"] = true,
                ["pairs"] = true, ["ipairs"] = true, ["next"] = true,
                ["select"] = true, ["unpack"] = true,
            }

            if hasDot and SANDBOX_NAMES[ident] then
                -- Keep sandbox-available dotted references like math.floor as-is
                table.insert(result, fullRef)
            elseif hasDot then
                -- Replace external reference with its string value
                table.insert(result, '"' .. fullRef .. '"')
            elseif LUA_LITERALS[ident] then
                table.insert(result, ident)
            else
                table.insert(result, ident)
            end
        else
            table.insert(result, ch)
            pos = pos + 1
        end
    end

    return table.concat(result)
end

--- Evaluate a Lua table string safely using sandboxed load().
--- The tableStr should be the raw table including outer braces, e.g., "{ ... }".
--- Strips function definitions and stubs external references before eval.
--- Returns the Lua table, or nil + error message.
function LuaParser.evalTable(tableStr)
    if not tableStr or tableStr == "" then
        return nil, "Empty table string"
    end

    -- Step 1: Strip function definitions (replace with nil)
    local cleaned = stripFunctions(tableStr)

    -- Step 2: Replace external module references with string placeholders
    cleaned = stubExternalReferences(cleaned)

    -- Step 3: Wrap in "return" for load()
    local code = "return " .. cleaned

    -- Step 4: Create a minimal sandbox environment
    local sandbox = {
        math = math,
        string = string,
        table = table,
        tonumber = tonumber,
        tostring = tostring,
        type = type,
        pairs = pairs,
        ipairs = ipairs,
        next = next,
        select = select,
        unpack = unpack or table.unpack,
    }

    -- Step 5: Load and execute in sandbox
    local fn, loadErr = load(code, "table_eval", "t", sandbox)
    if not fn then
        return nil, "Load error: " .. tostring(loadErr)
    end

    local ok, result = pcall(fn)
    if not ok then
        return nil, "Eval error: " .. tostring(result)
    end

    return result
end

-- ============================================================================
-- TABLE ENTRY SPLITTING
-- ============================================================================

--- Split the contents of an array-style table string into individual entry strings.
--- The input should be the INNER content (without outer braces) of a table like:
---   {id="a", ...}, {id="b", ...}, ...
--- Returns an array of entry strings (each including their braces).
function LuaParser.splitTableEntries(tableStr)
    if not tableStr or tableStr == "" then
        return {}
    end

    -- If the string starts/ends with { }, strip the outer braces
    local inner = tableStr
    local trimmed = tableStr:match("^%s*{(.*)}")
    if trimmed then
        -- We need to be careful: only strip if these are the OUTER braces
        local firstBrace = tableStr:find("{")
        if firstBrace then
            local matchPos = LuaParser.findMatchingBrace(tableStr, firstBrace + 1)
            -- If the matching brace is at or near the end, these are outer braces
            if matchPos and matchPos >= #tableStr - 1 then
                inner = tableStr:sub(firstBrace + 1, matchPos - 1)
            end
        end
    end

    local entries = {}
    local pos = 1
    local len = #inner

    while pos <= len do
        -- Skip whitespace and commas between entries
        pos = skipWhitespaceAndComments(inner, pos)
        if pos > len then break end

        local ch = inner:sub(pos, pos)

        -- Skip commas and semicolons (separators)
        if ch == "," or ch == ";" then
            pos = pos + 1

        elseif ch == "{" then
            -- This is a table entry; find the matching close brace
            local closePos = LuaParser.findMatchingBrace(inner, pos + 1)
            if closePos then
                local entry = inner:sub(pos, closePos)
                table.insert(entries, entry)
                pos = closePos + 1
            else
                -- Malformed; take rest of string
                table.insert(entries, inner:sub(pos))
                break
            end

        elseif ch == "[" then
            -- Could be a keyed entry like [key] = { ... }
            -- or a long string
            local level = longBracketLevel(inner, pos)
            if level then
                -- Long string as entry value (unusual but possible)
                local closePos = findLongBracketClose(inner, pos + level + 2, level)
                if closePos then
                    table.insert(entries, inner:sub(pos, closePos - 1))
                    pos = closePos
                else
                    table.insert(entries, inner:sub(pos))
                    break
                end
            else
                -- Keyed entry: [key] = value -- find the end
                -- Skip to the '=' then find the value
                local eqPos = inner:find("=", pos)
                if eqPos then
                    local valStart = skipWhitespaceAndComments(inner, eqPos + 1)
                    if valStart <= len and inner:sub(valStart, valStart) == "{" then
                        local closePos = LuaParser.findMatchingBrace(inner, valStart + 1)
                        if closePos then
                            table.insert(entries, inner:sub(pos, closePos))
                            pos = closePos + 1
                        else
                            table.insert(entries, inner:sub(pos))
                            break
                        end
                    else
                        -- Non-table value; scan to next comma
                        local commaPos = inner:find("[,;]", valStart)
                        if commaPos then
                            table.insert(entries, inner:sub(pos, commaPos - 1))
                            pos = commaPos + 1
                        else
                            table.insert(entries, inner:sub(pos))
                            break
                        end
                    end
                else
                    pos = pos + 1
                end
            end

        elseif ch:match("[%w_]") then
            -- Named key entry: key = { ... } or key = value
            -- Or a string/keyword as an array element
            local idStart = pos
            while pos <= len and inner:sub(pos, pos):match("[%w_.]") do
                pos = pos + 1
            end
            local afterId = skipWhitespaceAndComments(inner, pos)
            if afterId <= len and inner:sub(afterId, afterId) == "=" then
                -- Key-value pair
                local valStart = skipWhitespaceAndComments(inner, afterId + 1)
                if valStart <= len and inner:sub(valStart, valStart) == "{" then
                    local closePos = LuaParser.findMatchingBrace(inner, valStart + 1)
                    if closePos then
                        table.insert(entries, inner:sub(idStart, closePos))
                        pos = closePos + 1
                    else
                        table.insert(entries, inner:sub(idStart))
                        break
                    end
                else
                    -- Scalar value; scan to next comma at depth 0
                    local scanPos = valStart
                    while scanPos <= len do
                        local sc = inner:sub(scanPos, scanPos)
                        if sc == "," or sc == ";" then
                            break
                        elseif sc == "{" then
                            local cp = LuaParser.findMatchingBrace(inner, scanPos + 1)
                            scanPos = cp and (cp + 1) or (len + 1)
                        elseif sc == '"' or sc == "'" then
                            local q = sc
                            scanPos = scanPos + 1
                            while scanPos <= len do
                                local sc2 = inner:sub(scanPos, scanPos)
                                if sc2 == "\\" then
                                    scanPos = scanPos + 2
                                elseif sc2 == q then
                                    scanPos = scanPos + 1
                                    break
                                else
                                    scanPos = scanPos + 1
                                end
                            end
                        else
                            scanPos = scanPos + 1
                        end
                    end
                    table.insert(entries, inner:sub(idStart, scanPos - 1))
                    pos = scanPos
                end
            else
                -- Bare identifier or literal as array element (e.g., `true`, `nil`, `"string"`)
                table.insert(entries, inner:sub(idStart, pos - 1))
            end

        elseif ch == '"' or ch == "'" then
            -- String literal as array element
            local quote = ch
            local start = pos
            pos = pos + 1
            while pos <= len do
                local sc = inner:sub(pos, pos)
                if sc == "\\" then
                    pos = pos + 2
                elseif sc == quote then
                    pos = pos + 1
                    break
                else
                    pos = pos + 1
                end
            end
            table.insert(entries, inner:sub(start, pos - 1))

        elseif ch:match("[%d%.%-]") then
            -- Number literal
            local start = pos
            -- Handle negative sign
            if ch == "-" then pos = pos + 1 end
            -- Consume digits, dots, hex, exponents
            while pos <= len and inner:sub(pos, pos):match("[%w%.xXeE%+%-]") do
                pos = pos + 1
            end
            table.insert(entries, inner:sub(start, pos - 1))
        else
            -- Unknown character; skip
            pos = pos + 1
        end
    end

    return entries
end

-- ============================================================================
-- UTILITY: Read a Lua source file
-- ============================================================================

--- Read a file from the filesystem.
--- Tries love.filesystem.read first (works with mounted dirs), then io.open.
--- Returns the contents as a string, or nil + error.
function LuaParser.readFile(filePath)
    -- Try love.filesystem first (handles mounted directories like "game/...")
    if love and love.filesystem and love.filesystem.read then
        local content, err = love.filesystem.read(filePath)
        if content then
            return content
        end
    end

    -- Fallback to io.open for absolute paths
    local f, err = io.open(filePath, "r")
    if not f then
        return nil, "Cannot open file: " .. tostring(err)
    end
    local content = f:read("*a")
    f:close()
    return content
end

return LuaParser
