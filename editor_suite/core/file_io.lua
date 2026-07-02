-- file_io.lua - Lua Table Serializer and Project Save/Load System
-- Provides serialization, project management, and export functions
-- for the Tavern Quest Editor Suite.

local FileIO = {}

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

-- Characters that must be escaped inside a double-quoted Lua string.
local ESCAPE_MAP = {
    ["\\"] = "\\\\",
    ["\""] = "\\\"",
    ["\n"] = "\\n",
    ["\r"] = "\\r",
    ["\t"] = "\\t",
    ["\a"] = "\\a",
    ["\b"] = "\\b",
    ["\f"] = "\\f",
    ["\0"] = "\\0",
}

--- Escape a string so it is a valid Lua double-quoted literal.
local function escapeString(s)
    return (s:gsub("[%z\\\"\n\r\t\a\b\f]", ESCAPE_MAP)
             :gsub("[%c]", function(c)
                return string.format("\\%03d", string.byte(c))
             end))
end

--- Return true if the string is a valid Lua identifier and not a reserved word.
local LUA_KEYWORDS = {
    ["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true,
    ["elseif"] = true, ["end"] = true, ["false"] = true, ["for"] = true,
    ["function"] = true, ["goto"] = true, ["if"] = true, ["in"] = true,
    ["local"] = true, ["nil"] = true, ["not"] = true, ["or"] = true,
    ["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true,
    ["until"] = true, ["while"] = true,
}

local function isIdentifier(s)
    if type(s) ~= "string" then return false end
    if LUA_KEYWORDS[s] then return false end
    return s:match("^[A-Za-z_][A-Za-z0-9_]*$") ~= nil
end

--- Determine whether a table should be treated as a sequential array.
--- A table is an array when all keys are consecutive integers starting at 1.
local function isArray(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    if count == 0 then return true end -- empty table is an array
    for i = 1, count do
        if t[i] == nil then return false end
    end
    return count == #t
end

-- ---------------------------------------------------------------------------
-- Serializer
-- ---------------------------------------------------------------------------

--- Serialize an arbitrary Lua value into a string of valid Lua source code.
--- The output can be loaded back with `load()` (when prefixed with "return ").
---
--- Supported types: string, number, boolean, nil, table (nested).
--- Tables may contain array parts, dictionary parts, or a mix.
--- Functions, userdata, coroutines, and circular references are skipped.
---
--- @param value   any       The value to serialize.
--- @param indent  string|nil  Current indentation prefix (default "").
--- @param visited table|nil  Set of already-visited tables (internal).
--- @return string
function FileIO.serialize(value, indent, visited)
    indent = indent or ""
    visited = visited or {}

    local vtype = type(value)

    if vtype == "nil" then
        return "nil"

    elseif vtype == "boolean" then
        return tostring(value)

    elseif vtype == "number" then
        -- Guard against NaN and infinity which are not valid Lua literals.
        if value ~= value then
            return "0" -- NaN
        elseif value == math.huge then
            return "math.huge"
        elseif value == -math.huge then
            return "-math.huge"
        elseif value == math.floor(value) and math.abs(value) < 1e15 then
            return string.format("%d", value)
        else
            return string.format("%.17g", value)
        end

    elseif vtype == "string" then
        return "\"" .. escapeString(value) .. "\""

    elseif vtype == "table" then
        -- Circular reference detection.
        if visited[value] then
            return "nil --[[ circular reference ]]"
        end
        visited[value] = true

        local nextIndent = indent .. "    "
        local parts = {}
        local arrayLen = 0

        -- Determine the contiguous array portion length.
        -- We consider the array portion as indices 1..n where every value
        -- is non-nil and serializable.
        while value[arrayLen + 1] ~= nil do
            local elemType = type(value[arrayLen + 1])
            if elemType == "function" or elemType == "userdata" or elemType == "thread" then
                break
            end
            arrayLen = arrayLen + 1
        end

        -- Serialize array portion.
        for i = 1, arrayLen do
            local elem = FileIO.serialize(value[i], nextIndent, visited)
            parts[#parts + 1] = nextIndent .. elem .. ","
        end

        -- Collect and sort dictionary keys for deterministic output.
        local dictKeys = {}
        for k, v in pairs(value) do
            local ktype = type(k)
            local vtype2 = type(v)
            -- Skip integer keys already covered by the array portion.
            if ktype == "number" and k == math.floor(k) and k >= 1 and k <= arrayLen then
                -- already serialized above
            elseif (ktype == "string" or ktype == "number") and
                   vtype2 ~= "function" and vtype2 ~= "userdata" and vtype2 ~= "thread" then
                dictKeys[#dictKeys + 1] = k
            end
            -- Skip keys / values of unsupported types silently.
        end

        -- Sort: strings first (alphabetically), then numbers.
        table.sort(dictKeys, function(a, b)
            local aIsStr = type(a) == "string"
            local bIsStr = type(b) == "string"
            if aIsStr and bIsStr then return a < b end
            if aIsStr then return true end
            if bIsStr then return false end
            return a < b
        end)

        -- Serialize dictionary portion.
        for _, k in ipairs(dictKeys) do
            local v = value[k]
            local keyStr
            if isIdentifier(k) then
                keyStr = k
            elseif type(k) == "string" then
                keyStr = "[\"" .. escapeString(k) .. "\"]"
            else
                keyStr = "[" .. tostring(k) .. "]"
            end
            local valStr = FileIO.serialize(v, nextIndent, visited)
            parts[#parts + 1] = nextIndent .. keyStr .. " = " .. valStr .. ","
        end

        -- Remove from visited so the same table can appear in different
        -- branches (DAG is allowed, only cycles are not).
        visited[value] = nil

        if #parts == 0 then
            return "{}"
        end

        return "{\n" .. table.concat(parts, "\n") .. "\n" .. indent .. "}"

    else
        -- function, userdata, thread -- skip
        return "nil --[[ unsupported type: " .. vtype .. " ]]"
    end
end

-- ---------------------------------------------------------------------------
-- Directory helpers (love.filesystem)
-- ---------------------------------------------------------------------------

local PROJECTS_DIR = "projects"
local EXPORTS_DIR  = "exports"

--- Ensure a directory exists inside the love.filesystem save directory.
--- Creates the full path of directories if needed.
local function ensureDir(dir)
    if not love.filesystem.getInfo(dir) then
        love.filesystem.createDirectory(dir)
    end
end

-- ---------------------------------------------------------------------------
-- Project Save / Load
-- ---------------------------------------------------------------------------

--- Return a blank project template with all expected top-level keys.
function FileIO.newProjectTemplate()
    return {
        metadata = {
            name = "Untitled Project",
            author = "",
            version = "1.0",
            description = "",
            created = os.time(),
            modified = os.time(),
        },
        items = {},
        enemies = {},
        npcs = {},
        quests = {},
        maps = {},
        prefabs = {},
        lore = {},
        classes = {},
        races = {},
        backgrounds = {},
    }
end

--- Save a project table to the save directory under projects/<filename>.
--- The file is written as valid Lua: `return { ... }`.
---
--- Uses an atomic write pattern (write to .tmp, then move) to protect
--- against partial writes.
---
--- @param project  table   The project data table.
--- @param filename string  File name (e.g. "myproject.lua"). Extension added if missing.
--- @return boolean success
--- @return string|nil error message
function FileIO.saveProject(project, filename)
    if type(project) ~= "table" then
        return false, "project must be a table"
    end
    if type(filename) ~= "string" or filename == "" then
        return false, "filename must be a non-empty string"
    end

    -- Ensure .lua extension.
    if not filename:match("%.lua$") then
        filename = filename .. ".lua"
    end

    ensureDir(PROJECTS_DIR)

    -- Update modification timestamp.
    if type(project.metadata) == "table" then
        project.metadata.modified = os.time()
    end

    local content = "return " .. FileIO.serialize(project) .. "\n"

    local filepath = PROJECTS_DIR .. "/" .. filename
    local tmppath  = filepath .. ".tmp"

    -- Write to temp file first.
    local ok, err = love.filesystem.write(tmppath, content)
    if not ok then
        return false, "failed to write temp file: " .. tostring(err)
    end

    -- Read back and write to final path (LOVE has no rename).
    local tmpContent = love.filesystem.read(tmppath)
    if not tmpContent then
        return false, "failed to read back temp file"
    end

    local ok2, err2 = love.filesystem.write(filepath, tmpContent)
    if not ok2 then
        return false, "failed to write final file: " .. tostring(err2)
    end

    love.filesystem.remove(tmppath)
    return true
end

--- Load a project from the save directory at projects/<filename>.
---
--- @param filename string  File name (e.g. "myproject.lua").
--- @return table|nil project  The loaded project table, or nil on error.
--- @return string|nil error   Error message if load failed.
function FileIO.loadProject(filename)
    if type(filename) ~= "string" or filename == "" then
        return nil, "filename must be a non-empty string"
    end

    if not filename:match("%.lua$") then
        filename = filename .. ".lua"
    end

    local filepath = PROJECTS_DIR .. "/" .. filename

    local info = love.filesystem.getInfo(filepath)
    if not info then
        return nil, "file not found: " .. filepath
    end

    -- Load as a Lua chunk in a sandboxed environment.
    local loadOk, chunk = pcall(love.filesystem.load, filepath)
    if not loadOk or not chunk then
        return nil, "failed to parse file: " .. tostring(chunk)
    end

    -- Sandbox the chunk so it cannot call any functions or access globals.
    local sandbox = {}
    setfenv(chunk, sandbox)

    local execOk, data = pcall(chunk)
    if not execOk then
        return nil, "failed to execute file: " .. tostring(data)
    end

    if type(data) ~= "table" then
        return nil, "file did not return a table"
    end

    return data
end

-- ---------------------------------------------------------------------------
-- Export Functions
-- ---------------------------------------------------------------------------

--- Export a data table as a game-ready Lua file: `return { ... }`.
--- Written to exports/<filename> inside the love.filesystem save directory.
---
--- @param data     table   The data to export.
--- @param filename string  Target file name.
--- @return boolean success
--- @return string|nil error
function FileIO.exportLua(data, filename)
    if type(data) ~= "table" then
        return false, "data must be a table"
    end
    if type(filename) ~= "string" or filename == "" then
        return false, "filename must be a non-empty string"
    end

    if not filename:match("%.lua$") then
        filename = filename .. ".lua"
    end

    ensureDir(EXPORTS_DIR)

    local content = "return " .. FileIO.serialize(data) .. "\n"
    local filepath = EXPORTS_DIR .. "/" .. filename

    local ok, err = love.filesystem.write(filepath, content)
    if not ok then
        return false, "failed to write export: " .. tostring(err)
    end
    return true
end

--- Minimal JSON encoder (handles strings, numbers, booleans, nil, tables).
--- This is intentionally simple; a full json_codec module can replace it later.
local function toJSON(value, indent, currentIndent)
    indent = indent or "    "
    currentIndent = currentIndent or ""
    local nextIndent = currentIndent .. indent
    local vtype = type(value)

    if value == nil then
        return "null"
    elseif vtype == "boolean" then
        return tostring(value)
    elseif vtype == "number" then
        if value ~= value then return "0" end
        if value == math.huge or value == -math.huge then return "999999999" end
        if value == math.floor(value) and math.abs(value) < 1e15 then
            return string.format("%d", value)
        end
        return string.format("%.17g", value)
    elseif vtype == "string" then
        -- JSON string escaping.
        local escaped = value
            :gsub("\\", "\\\\")
            :gsub("\"", "\\\"")
            :gsub("\n", "\\n")
            :gsub("\r", "\\r")
            :gsub("\t", "\\t")
            :gsub("[%c]", function(c)
                return string.format("\\u%04x", string.byte(c))
            end)
        return "\"" .. escaped .. "\""
    elseif vtype == "table" then
        -- Detect array vs object.
        local arr = isArray(value)
        local parts = {}

        if arr then
            for i = 1, #value do
                parts[#parts + 1] = nextIndent .. toJSON(value[i], indent, nextIndent)
            end
            if #parts == 0 then
                return "[]"
            end
            return "[\n" .. table.concat(parts, ",\n") .. "\n" .. currentIndent .. "]"
        else
            -- Collect all serializable keys paired with their JSON key name.
            -- JSON requires string keys, so numeric keys are converted.
            local entries = {} -- { {jsonKey, originalKey}, ... }
            for k in pairs(value) do
                if type(k) == "string" then
                    entries[#entries + 1] = {k, k}
                elseif type(k) == "number" then
                    entries[#entries + 1] = {tostring(k), k}
                end
            end
            table.sort(entries, function(a, b) return a[1] < b[1] end)

            for _, entry in ipairs(entries) do
                local jsonKeyName, origKey = entry[1], entry[2]
                local v = value[origKey]
                if v ~= nil and type(v) ~= "function" and type(v) ~= "userdata" and type(v) ~= "thread" then
                    local jsonKey = toJSON(jsonKeyName, indent, nextIndent)
                    local jsonVal = toJSON(v, indent, nextIndent)
                    parts[#parts + 1] = nextIndent .. jsonKey .. ": " .. jsonVal
                end
            end
            if #parts == 0 then
                return "{}"
            end
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. currentIndent .. "}"
        end
    else
        return "null"
    end
end

--- Export a data table as JSON.
--- Written to exports/<filename> inside the love.filesystem save directory.
---
--- @param data     table   The data to export.
--- @param filename string  Target file name.
--- @return boolean success
--- @return string|nil error
function FileIO.exportJSON(data, filename)
    if type(data) ~= "table" then
        return false, "data must be a table"
    end
    if type(filename) ~= "string" or filename == "" then
        return false, "filename must be a non-empty string"
    end

    if not filename:match("%.json$") then
        filename = filename .. ".json"
    end

    ensureDir(EXPORTS_DIR)

    local content = toJSON(data) .. "\n"
    local filepath = EXPORTS_DIR .. "/" .. filename

    local ok, err = love.filesystem.write(filepath, content)
    if not ok then
        return false, "failed to write JSON export: " .. tostring(err)
    end
    return true
end

--- Export all content types from a project into separate Lua files inside
--- exports/<projectName>/.
---
--- @param project table  The full project table.
--- @param dirName string Directory name to create under exports/.
--- @return boolean success
--- @return string|nil error
function FileIO.exportToDirectory(project, dirName)
    if type(project) ~= "table" then
        return false, "project must be a table"
    end
    if type(dirName) ~= "string" or dirName == "" then
        return false, "dirName must be a non-empty string"
    end

    ensureDir(EXPORTS_DIR)
    local baseDir = EXPORTS_DIR .. "/" .. dirName
    ensureDir(baseDir)

    -- Content categories that get their own file.
    local categories = {
        "items", "enemies", "npcs", "quests", "maps",
        "prefabs", "lore", "classes", "races", "backgrounds",
    }

    -- Write metadata.
    if type(project.metadata) == "table" then
        local content = "return " .. FileIO.serialize(project.metadata) .. "\n"
        local ok, err = love.filesystem.write(baseDir .. "/metadata.lua", content)
        if not ok then
            return false, "failed to write metadata: " .. tostring(err)
        end
    end

    -- Write each category.
    for _, cat in ipairs(categories) do
        local data = project[cat]
        if type(data) == "table" then
            local content = "return " .. FileIO.serialize(data) .. "\n"
            local ok, err = love.filesystem.write(baseDir .. "/" .. cat .. ".lua", content)
            if not ok then
                return false, "failed to write " .. cat .. ": " .. tostring(err)
            end
        end
    end

    return true
end

-- ---------------------------------------------------------------------------
-- File Reading
-- ---------------------------------------------------------------------------

--- Read the entire contents of a file as a string.
--- First tries love.filesystem (save directory + game source), then falls
--- back to io.open for absolute / relative OS paths.
---
--- @param path string  File path.
--- @return string|nil  contents
--- @return string|nil  error message
function FileIO.readFile(path)
    if type(path) ~= "string" or path == "" then
        return nil, "path must be a non-empty string"
    end

    -- Try love.filesystem first (covers save dir and mounted paths).
    local info = love.filesystem.getInfo(path)
    if info and info.type == "file" then
        local content, err = love.filesystem.read(path)
        if content then
            return content
        end
        return nil, "love.filesystem.read failed: " .. tostring(err)
    end

    -- Fall back to native io.open for OS paths.
    local fh, err = io.open(path, "r")
    if not fh then
        return nil, "io.open failed: " .. tostring(err)
    end
    local content = fh:read("*a")
    fh:close()
    return content
end

--- List files in a directory, optionally filtered by extension.
--- Uses love.filesystem.getDirectoryItems for the save/game directory.
---
--- @param directory string       Directory path inside love.filesystem.
--- @param extension string|nil   Extension filter (e.g. ".lua") -- include the dot.
--- @return table  Array of file names that matched.
function FileIO.listFiles(directory, extension)
    if type(directory) ~= "string" then return {} end

    local info = love.filesystem.getInfo(directory)
    if not info or info.type ~= "directory" then
        return {}
    end

    local all = love.filesystem.getDirectoryItems(directory)
    if not extension then
        return all
    end

    -- Normalise extension to start with a dot.
    if extension:sub(1, 1) ~= "." then
        extension = "." .. extension
    end

    local filtered = {}
    for _, name in ipairs(all) do
        if name:sub(-#extension) == extension then
            -- Only include actual files, not subdirectories.
            local childInfo = love.filesystem.getInfo(directory .. "/" .. name)
            if childInfo and childInfo.type == "file" then
                filtered[#filtered + 1] = name
            end
        end
    end
    return filtered
end

--- Check whether a file exists.
--- Checks love.filesystem first, then falls back to io.open for OS paths.
---
--- @param path string
--- @return boolean
function FileIO.fileExists(path)
    if type(path) ~= "string" or path == "" then return false end

    -- love.filesystem check.
    local info = love.filesystem.getInfo(path)
    if info then return true end

    -- Native OS check.
    local fh = io.open(path, "r")
    if fh then
        fh:close()
        return true
    end
    return false
end

-- ---------------------------------------------------------------------------
-- File Browser Support
-- ---------------------------------------------------------------------------

--- Return a list of saved project files (names only, without path prefix).
--- Each entry is a table: { name = "foo.lua", modified = <timestamp|0> }.
---
--- @return table  Array of project info tables.
function FileIO.getProjectList()
    ensureDir(PROJECTS_DIR)
    local files = FileIO.listFiles(PROJECTS_DIR, ".lua")
    local result = {}
    for _, name in ipairs(files) do
        local info = love.filesystem.getInfo(PROJECTS_DIR .. "/" .. name)
        result[#result + 1] = {
            name = name,
            modified = info and info.modtime or 0,
        }
    end
    -- Sort by most recently modified first.
    table.sort(result, function(a, b)
        return a.modified > b.modified
    end)
    return result
end

--- Return a list of exported files (names only, without path prefix).
--- Each entry is a table: { name = "foo.lua", modified = <timestamp|0> }.
---
--- @return table  Array of export info tables.
function FileIO.getExportList()
    ensureDir(EXPORTS_DIR)
    local items = love.filesystem.getDirectoryItems(EXPORTS_DIR)
    local result = {}
    for _, name in ipairs(items) do
        local info = love.filesystem.getInfo(EXPORTS_DIR .. "/" .. name)
        result[#result + 1] = {
            name = name,
            type = info and info.type or "file",
            modified = info and info.modtime or 0,
        }
    end
    table.sort(result, function(a, b)
        return a.modified > b.modified
    end)
    return result
end

-- ---------------------------------------------------------------------------
-- Convenience: delete helpers
-- ---------------------------------------------------------------------------

--- Delete a project file from the save directory.
---
--- @param filename string
--- @return boolean
function FileIO.deleteProject(filename)
    if type(filename) ~= "string" or filename == "" then return false end
    if not filename:match("%.lua$") then
        filename = filename .. ".lua"
    end
    local filepath = PROJECTS_DIR .. "/" .. filename
    if love.filesystem.getInfo(filepath) then
        return love.filesystem.remove(filepath)
    end
    return false
end

--- Delete an exported file from the save directory.
---
--- @param filename string
--- @return boolean
function FileIO.deleteExport(filename)
    if type(filename) ~= "string" or filename == "" then return false end
    local filepath = EXPORTS_DIR .. "/" .. filename
    if love.filesystem.getInfo(filepath) then
        return love.filesystem.remove(filepath)
    end
    return false
end

return FileIO
