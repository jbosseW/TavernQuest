-- json_codec.lua - Simple JSON Encoder/Decoder
-- Handles: strings, numbers, booleans, null (nil), arrays, objects
-- Features: proper string escaping, pretty-print option, error handling

local json = {}

-- ============================================================================
-- ENCODER
-- ============================================================================

-- Characters that must be escaped in JSON strings (RFC 8259)
local ENCODE_ESCAPE_MAP = {
    ['"']  = '\\"',
    ['\\'] = '\\\\',
    ['/']  = '\\/',
    ['\b'] = '\\b',
    ['\f'] = '\\f',
    ['\n'] = '\\n',
    ['\r'] = '\\r',
    ['\t'] = '\\t',
}

--- Escape a Lua string for JSON output.
local function encodeString(s)
    -- Escape required characters
    local escaped = s:gsub('[%z\1-\31\\"/]', function(c)
        if ENCODE_ESCAPE_MAP[c] then
            return ENCODE_ESCAPE_MAP[c]
        end
        -- Control characters as \u00XX
        return string.format("\\u%04x", string.byte(c))
    end)
    return '"' .. escaped .. '"'
end

--- Determine if a Lua table is an array (sequential integer keys starting at 1).
local function isArray(t)
    if type(t) ~= "table" then return false end
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    if count == 0 then return true end -- empty table treated as array
    for i = 1, count do
        if t[i] == nil then return false end
    end
    return count == #t
end

--- Sort table keys for deterministic output.
local function sortedKeys(t)
    local keys = {}
    for k in pairs(t) do
        keys[#keys + 1] = k
    end
    table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta == tb then
            if ta == "number" or ta == "string" then
                return a < b
            end
            return tostring(a) < tostring(b)
        end
        -- Numbers before strings
        if ta == "number" then return true end
        if tb == "number" then return false end
        return tostring(a) < tostring(b)
    end)
    return keys
end

--- Internal recursive encoder.
--- pretty: boolean, enable indentation
--- indent: string, current indentation prefix
--- indentStep: string, one level of indentation (e.g., "  ")
local function encodeValue(value, pretty, indent, indentStep, seen)
    local vtype = type(value)

    if value == nil then
        return "null"

    elseif vtype == "boolean" then
        return value and "true" or "false"

    elseif vtype == "number" then
        -- Handle special float values
        if value ~= value then
            return "null" -- NaN -> null (JSON has no NaN)
        elseif value == math.huge then
            return "1e999" -- Approximate infinity
        elseif value == -math.huge then
            return "-1e999"
        end
        -- Use integer format when possible for cleaner output
        if value == math.floor(value) and math.abs(value) < 1e15 then
            return string.format("%d", value)
        end
        return string.format("%.17g", value)

    elseif vtype == "string" then
        return encodeString(value)

    elseif vtype == "table" then
        -- Circular reference detection
        if seen[value] then
            return "null"
        end
        seen[value] = true

        local newIndent = pretty and (indent .. indentStep) or ""
        local sep = pretty and ",\n" or ","
        local startSep = pretty and "\n" or ""
        local endSep = pretty and ("\n" .. indent) or ""
        local kvSep = pretty and ": " or ":"

        if isArray(value) then
            -- Encode as JSON array
            if #value == 0 then
                seen[value] = nil
                return "[]"
            end
            local parts = {}
            for i = 1, #value do
                local encoded = encodeValue(value[i], pretty, newIndent, indentStep, seen)
                parts[#parts + 1] = (pretty and newIndent or "") .. encoded
            end
            seen[value] = nil
            return "[" .. startSep .. table.concat(parts, sep) .. endSep .. "]"
        else
            -- Encode as JSON object
            local keys = sortedKeys(value)
            if #keys == 0 then
                seen[value] = nil
                return "{}"
            end
            local parts = {}
            for _, k in ipairs(keys) do
                local keyStr
                if type(k) == "string" then
                    keyStr = encodeString(k)
                elseif type(k) == "number" then
                    -- JSON object keys must be strings
                    keyStr = encodeString(tostring(k))
                else
                    keyStr = encodeString(tostring(k))
                end
                local valEncoded = encodeValue(value[k], pretty, newIndent, indentStep, seen)
                parts[#parts + 1] = (pretty and newIndent or "") .. keyStr .. kvSep .. valEncoded
            end
            seen[value] = nil
            return "{" .. startSep .. table.concat(parts, sep) .. endSep .. "}"
        end
    else
        -- Functions, userdata, threads -> null
        return "null"
    end
end

--- Encode a Lua value to a JSON string.
--- Options table (optional):
---   pretty  = true/false (default false) - enable pretty printing
---   indent  = string (default "  ") - indentation string per level
--- Returns the JSON string.
function json.encode(value, options)
    options = options or {}
    local pretty = options.pretty or false
    local indentStep = options.indent or "  "
    local seen = {}
    return encodeValue(value, pretty, "", indentStep, seen)
end

-- ============================================================================
-- DECODER
-- ============================================================================

-- Decoder state: holds the string and current position
local Decoder = {}
Decoder.__index = Decoder

function Decoder.new(str)
    return setmetatable({
        str = str,
        pos = 1,
        len = #str,
    }, Decoder)
end

--- Skip whitespace characters.
function Decoder:skipWhitespace()
    while self.pos <= self.len do
        local ch = self.str:sub(self.pos, self.pos)
        if ch == " " or ch == "\t" or ch == "\n" or ch == "\r" then
            self.pos = self.pos + 1
        else
            break
        end
    end
end

--- Peek at the current character without advancing.
function Decoder:peek()
    self:skipWhitespace()
    if self.pos > self.len then return nil end
    return self.str:sub(self.pos, self.pos)
end

--- Advance position by n characters.
function Decoder:advance(n)
    self.pos = self.pos + (n or 1)
end

--- Raise a decode error with context.
function Decoder:error(msg)
    -- Show a snippet of context around the current position
    local start = math.max(1, self.pos - 20)
    local stop = math.min(self.len, self.pos + 20)
    local context = self.str:sub(start, stop)
    local pointer = string.rep(" ", self.pos - start) .. "^"
    error(string.format("JSON decode error at position %d: %s\n  %s\n  %s",
        self.pos, msg, context, pointer), 0)
end

--- Expect a specific character and advance past it.
function Decoder:expect(ch)
    self:skipWhitespace()
    if self.pos > self.len then
        self:error("Unexpected end of input, expected '" .. ch .. "'")
    end
    local actual = self.str:sub(self.pos, self.pos)
    if actual ~= ch then
        self:error("Expected '" .. ch .. "', got '" .. actual .. "'")
    end
    self.pos = self.pos + 1
end

--- Unicode escape: decode \uXXXX (and surrogate pairs).
local function unicodeToUtf8(codepoint)
    if codepoint < 0x80 then
        return string.char(codepoint)
    elseif codepoint < 0x800 then
        return string.char(
            0xC0 + math.floor(codepoint / 64),
            0x80 + (codepoint % 64)
        )
    elseif codepoint < 0x10000 then
        return string.char(
            0xE0 + math.floor(codepoint / 4096),
            0x80 + math.floor((codepoint % 4096) / 64),
            0x80 + (codepoint % 64)
        )
    elseif codepoint < 0x110000 then
        return string.char(
            0xF0 + math.floor(codepoint / 262144),
            0x80 + math.floor((codepoint % 262144) / 4096),
            0x80 + math.floor((codepoint % 4096) / 64),
            0x80 + (codepoint % 64)
        )
    end
    return "?" -- Invalid codepoint
end

-- JSON string escape map for decoding
local DECODE_ESCAPE_MAP = {
    ['"']  = '"',
    ['\\'] = '\\',
    ['/']  = '/',
    ['b']  = '\b',
    ['f']  = '\f',
    ['n']  = '\n',
    ['r']  = '\r',
    ['t']  = '\t',
}

--- Decode a JSON string value.
function Decoder:decodeString()
    self:expect('"')
    local parts = {}
    while self.pos <= self.len do
        local ch = self.str:sub(self.pos, self.pos)
        if ch == '"' then
            self.pos = self.pos + 1
            return table.concat(parts)
        elseif ch == '\\' then
            self.pos = self.pos + 1
            if self.pos > self.len then
                self:error("Unexpected end of string escape")
            end
            local esc = self.str:sub(self.pos, self.pos)
            if DECODE_ESCAPE_MAP[esc] then
                parts[#parts + 1] = DECODE_ESCAPE_MAP[esc]
                self.pos = self.pos + 1
            elseif esc == 'u' then
                -- Unicode escape \uXXXX
                self.pos = self.pos + 1
                if self.pos + 3 > self.len then
                    self:error("Incomplete unicode escape")
                end
                local hex = self.str:sub(self.pos, self.pos + 3)
                local codepoint = tonumber(hex, 16)
                if not codepoint then
                    self:error("Invalid unicode escape: \\u" .. hex)
                end
                self.pos = self.pos + 4

                -- Handle surrogate pairs
                if codepoint >= 0xD800 and codepoint <= 0xDBFF then
                    -- High surrogate; expect \uXXXX low surrogate
                    if self.pos + 5 <= self.len and
                       self.str:sub(self.pos, self.pos + 1) == "\\u" then
                        self.pos = self.pos + 2
                        local hex2 = self.str:sub(self.pos, self.pos + 3)
                        local low = tonumber(hex2, 16)
                        if low and low >= 0xDC00 and low <= 0xDFFF then
                            codepoint = 0x10000 + (codepoint - 0xD800) * 0x400 + (low - 0xDC00)
                            self.pos = self.pos + 4
                        else
                            self:error("Invalid low surrogate")
                        end
                    else
                        self:error("Expected low surrogate after high surrogate")
                    end
                end

                parts[#parts + 1] = unicodeToUtf8(codepoint)
            else
                self:error("Invalid escape character: \\" .. esc)
            end
        else
            parts[#parts + 1] = ch
            self.pos = self.pos + 1
        end
    end
    self:error("Unterminated string")
end

--- Decode a JSON number.
function Decoder:decodeNumber()
    local start = self.pos
    -- Optional negative sign
    if self.str:sub(self.pos, self.pos) == '-' then
        self.pos = self.pos + 1
    end
    -- Integer part
    if self.pos <= self.len and self.str:sub(self.pos, self.pos) == '0' then
        self.pos = self.pos + 1
    elseif self.pos <= self.len and self.str:sub(self.pos, self.pos):match("[1-9]") then
        self.pos = self.pos + 1
        while self.pos <= self.len and self.str:sub(self.pos, self.pos):match("%d") do
            self.pos = self.pos + 1
        end
    else
        self:error("Invalid number")
    end
    -- Fractional part
    if self.pos <= self.len and self.str:sub(self.pos, self.pos) == '.' then
        self.pos = self.pos + 1
        if self.pos > self.len or not self.str:sub(self.pos, self.pos):match("%d") then
            self:error("Invalid number: expected digit after decimal point")
        end
        while self.pos <= self.len and self.str:sub(self.pos, self.pos):match("%d") do
            self.pos = self.pos + 1
        end
    end
    -- Exponent part
    if self.pos <= self.len and self.str:sub(self.pos, self.pos):match("[eE]") then
        self.pos = self.pos + 1
        if self.pos <= self.len and self.str:sub(self.pos, self.pos):match("[%+%-]") then
            self.pos = self.pos + 1
        end
        if self.pos > self.len or not self.str:sub(self.pos, self.pos):match("%d") then
            self:error("Invalid number: expected digit in exponent")
        end
        while self.pos <= self.len and self.str:sub(self.pos, self.pos):match("%d") do
            self.pos = self.pos + 1
        end
    end
    local numStr = self.str:sub(start, self.pos - 1)
    local num = tonumber(numStr)
    if not num then
        self:error("Failed to parse number: " .. numStr)
    end
    return num
end

--- Decode a JSON array.
function Decoder:decodeArray()
    self:expect('[')
    local arr = {}
    self:skipWhitespace()
    if self:peek() == ']' then
        self:advance()
        return arr
    end
    while true do
        arr[#arr + 1] = self:decodeValue()
        self:skipWhitespace()
        local ch = self:peek()
        if ch == ',' then
            self:advance()
        elseif ch == ']' then
            self:advance()
            return arr
        else
            self:error("Expected ',' or ']' in array")
        end
    end
end

--- Decode a JSON object.
function Decoder:decodeObject()
    self:expect('{')
    local obj = {}
    self:skipWhitespace()
    if self:peek() == '}' then
        self:advance()
        return obj
    end
    while true do
        self:skipWhitespace()
        if self:peek() ~= '"' then
            self:error("Expected string key in object")
        end
        local key = self:decodeString()
        self:skipWhitespace()
        self:expect(':')
        local value = self:decodeValue()
        obj[key] = value
        self:skipWhitespace()
        local ch = self:peek()
        if ch == ',' then
            self:advance()
        elseif ch == '}' then
            self:advance()
            return obj
        else
            self:error("Expected ',' or '}' in object")
        end
    end
end

--- Decode any JSON value.
function Decoder:decodeValue()
    self:skipWhitespace()
    if self.pos > self.len then
        self:error("Unexpected end of input")
    end
    local ch = self.str:sub(self.pos, self.pos)

    if ch == '"' then
        return self:decodeString()
    elseif ch == '{' then
        return self:decodeObject()
    elseif ch == '[' then
        return self:decodeArray()
    elseif ch == 't' then
        -- true
        if self.str:sub(self.pos, self.pos + 3) == "true" then
            self.pos = self.pos + 4
            return true
        end
        self:error("Invalid value")
    elseif ch == 'f' then
        -- false
        if self.str:sub(self.pos, self.pos + 4) == "false" then
            self.pos = self.pos + 5
            return false
        end
        self:error("Invalid value")
    elseif ch == 'n' then
        -- null
        if self.str:sub(self.pos, self.pos + 3) == "null" then
            self.pos = self.pos + 4
            return nil
        end
        self:error("Invalid value")
    elseif ch == '-' or ch:match("%d") then
        return self:decodeNumber()
    else
        self:error("Unexpected character: '" .. ch .. "'")
    end
end

--- Decode a JSON string into a Lua value.
--- Returns the decoded value, or nil + error message on failure.
--- Note: JSON null decodes to a special json.null sentinel value for
--- disambiguation, unless the caller prefers plain nil.
function json.decode(str)
    if type(str) ~= "string" then
        return nil, "Expected string input, got " .. type(str)
    end
    if str == "" then
        return nil, "Empty input string"
    end

    local decoder = Decoder.new(str)
    local ok, result = pcall(function()
        return decoder:decodeValue()
    end)

    if not ok then
        return nil, tostring(result)
    end

    -- Check for trailing content (but allow whitespace)
    decoder:skipWhitespace()
    if decoder.pos <= decoder.len then
        return nil, string.format(
            "Unexpected content after JSON value at position %d",
            decoder.pos
        )
    end

    return result
end

-- ============================================================================
-- NULL SENTINEL
-- ============================================================================

--- A sentinel value representing JSON null.
--- Since Lua's nil cannot be stored in tables, use json.null as a placeholder
--- when you need to distinguish between "key is absent" and "key is null".
json.null = setmetatable({}, {
    __tostring = function() return "null" end,
    __eq = function(a, b) return rawequal(a, b) end,
})

-- ============================================================================
-- CONVENIENCE
-- ============================================================================

--- Encode a value to a pretty-printed JSON string.
function json.pretty(value, indentStr)
    return json.encode(value, {pretty = true, indent = indentStr or "  "})
end

--- Check if a value is a valid JSON type (can be encoded without data loss).
function json.isEncodable(value)
    local vtype = type(value)
    if vtype == "nil" or vtype == "boolean" or vtype == "number" or vtype == "string" then
        return true
    elseif vtype == "table" then
        for k, v in pairs(value) do
            if type(k) ~= "string" and type(k) ~= "number" then
                return false
            end
            if not json.isEncodable(v) then
                return false
            end
        end
        return true
    end
    return false
end

return json
