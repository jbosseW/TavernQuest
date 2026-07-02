-- Minimal JSON encoder/decoder for LOVE2D
-- Handles: strings, numbers, booleans, null, arrays, objects
-- Returns module table with json.encode(value) and json.decode(str)

local json = {}

-- ============================================================================
-- ENCODER
-- ============================================================================

local encode_value  -- forward declaration

local escape_char_map = {
    ["\\"] = "\\\\",
    ["\""] = "\\\"",
    ["\b"] = "\\b",
    ["\f"] = "\\f",
    ["\n"] = "\\n",
    ["\r"] = "\\r",
    ["\t"] = "\\t",
}

local function escape_char(c)
    return escape_char_map[c] or string.format("\\u%04x", c:byte())
end

local function encode_string(val)
    return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end

local function encode_number(val)
    if val ~= val then
        return "null"  -- NaN
    elseif val == math.huge then
        return "1e999"
    elseif val == -math.huge then
        return "-1e999"
    end
    return string.format("%.14g", val)
end

-- Determine if a table is an array (sequential integer keys starting at 1)
local function is_array(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    if count == 0 then
        return true  -- empty table treated as array
    end
    for i = 1, count do
        if t[i] == nil then
            return false
        end
    end
    return true
end

local function encode_array(val)
    local parts = {}
    for i = 1, #val do
        parts[i] = encode_value(val[i])
    end
    return "[" .. table.concat(parts, ",") .. "]"
end

local function encode_object(val)
    local parts = {}
    for k, v in pairs(val) do
        if type(k) == "string" then
            parts[#parts + 1] = encode_string(k) .. ":" .. encode_value(v)
        elseif type(k) == "number" then
            parts[#parts + 1] = encode_string(tostring(k)) .. ":" .. encode_value(v)
        end
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

encode_value = function(val)
    local t = type(val)
    if val == nil then
        return "null"
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "number" then
        return encode_number(val)
    elseif t == "string" then
        return encode_string(val)
    elseif t == "table" then
        if is_array(val) then
            return encode_array(val)
        else
            return encode_object(val)
        end
    else
        return "null"
    end
end

function json.encode(value)
    local ok, result = pcall(encode_value, value)
    if ok then
        return result
    else
        return nil, "encode error: " .. tostring(result)
    end
end

-- ============================================================================
-- DECODER
-- ============================================================================

local decode_value  -- forward declaration

local function create_decoder(str)
    return { str = str, pos = 1 }
end

local function skip_ws(d)
    while d.pos <= #d.str do
        local c = d.str:byte(d.pos)
        if c == 32 or c == 9 or c == 10 or c == 13 then
            d.pos = d.pos + 1
        else
            break
        end
    end
end

local function expect(d, ch)
    skip_ws(d)
    if d.pos > #d.str then
        error("unexpected end of input, expected '" .. ch .. "'")
    end
    local c = d.str:sub(d.pos, d.pos)
    if c ~= ch then
        error("expected '" .. ch .. "' at position " .. d.pos .. ", got '" .. c .. "'")
    end
    d.pos = d.pos + 1
    return c
end

local function decode_string(d)
    expect(d, '"')
    local parts = {}
    while d.pos <= #d.str do
        local c = d.str:sub(d.pos, d.pos)
        d.pos = d.pos + 1

        if c == '"' then
            return table.concat(parts)
        elseif c == '\\' then
            if d.pos > #d.str then
                error("unexpected end of string escape at position " .. d.pos)
            end
            local esc = d.str:sub(d.pos, d.pos)
            d.pos = d.pos + 1
            if esc == 'u' then
                local hex = d.str:sub(d.pos, d.pos + 3)
                if #hex < 4 then
                    error("invalid unicode escape at position " .. d.pos)
                end
                d.pos = d.pos + 4
                local code = tonumber(hex, 16)
                -- Handle surrogate pairs
                if code and code >= 0xD800 and code <= 0xDBFF then
                    if d.str:sub(d.pos, d.pos + 1) == "\\u" then
                        d.pos = d.pos + 2
                        local hex2 = d.str:sub(d.pos, d.pos + 3)
                        d.pos = d.pos + 4
                        local code2 = tonumber(hex2, 16)
                        if code2 and code2 >= 0xDC00 and code2 <= 0xDFFF then
                            code = 0x10000 + (code - 0xD800) * 0x400 + (code2 - 0xDC00)
                        end
                    end
                end
                -- Encode to UTF-8
                if code then
                    if code < 0x80 then
                        parts[#parts + 1] = string.char(code)
                    elseif code < 0x800 then
                        parts[#parts + 1] = string.char(
                            0xC0 + math.floor(code / 64),
                            0x80 + (code % 64)
                        )
                    elseif code < 0x10000 then
                        parts[#parts + 1] = string.char(
                            0xE0 + math.floor(code / 4096),
                            0x80 + math.floor((code % 4096) / 64),
                            0x80 + (code % 64)
                        )
                    else
                        parts[#parts + 1] = string.char(
                            0xF0 + math.floor(code / 262144),
                            0x80 + math.floor((code % 262144) / 4096),
                            0x80 + math.floor((code % 4096) / 64),
                            0x80 + (code % 64)
                        )
                    end
                end
            elseif esc == '"' then
                parts[#parts + 1] = '"'
            elseif esc == '\\' then
                parts[#parts + 1] = '\\'
            elseif esc == '/' then
                parts[#parts + 1] = '/'
            elseif esc == 'b' then
                parts[#parts + 1] = '\b'
            elseif esc == 'f' then
                parts[#parts + 1] = '\f'
            elseif esc == 'n' then
                parts[#parts + 1] = '\n'
            elseif esc == 'r' then
                parts[#parts + 1] = '\r'
            elseif esc == 't' then
                parts[#parts + 1] = '\t'
            else
                parts[#parts + 1] = esc
            end
        else
            parts[#parts + 1] = c
        end
    end
    error("unterminated string at position " .. d.pos)
end

local function decode_number(d)
    skip_ws(d)
    local start = d.pos
    if d.str:sub(d.pos, d.pos) == '-' then
        d.pos = d.pos + 1
    end
    if d.str:sub(d.pos, d.pos) == '0' then
        d.pos = d.pos + 1
    else
        if not d.str:sub(d.pos, d.pos):match("[1-9]") then
            error("invalid number at position " .. start)
        end
        while d.pos <= #d.str and d.str:sub(d.pos, d.pos):match("[0-9]") do
            d.pos = d.pos + 1
        end
    end
    if d.pos <= #d.str and d.str:sub(d.pos, d.pos) == '.' then
        d.pos = d.pos + 1
        if d.pos > #d.str or not d.str:sub(d.pos, d.pos):match("[0-9]") then
            error("invalid number at position " .. start)
        end
        while d.pos <= #d.str and d.str:sub(d.pos, d.pos):match("[0-9]") do
            d.pos = d.pos + 1
        end
    end
    if d.pos <= #d.str and d.str:sub(d.pos, d.pos):lower() == 'e' then
        d.pos = d.pos + 1
        if d.pos <= #d.str and (d.str:sub(d.pos, d.pos) == '+' or d.str:sub(d.pos, d.pos) == '-') then
            d.pos = d.pos + 1
        end
        if d.pos > #d.str or not d.str:sub(d.pos, d.pos):match("[0-9]") then
            error("invalid number exponent at position " .. start)
        end
        while d.pos <= #d.str and d.str:sub(d.pos, d.pos):match("[0-9]") do
            d.pos = d.pos + 1
        end
    end
    local numstr = d.str:sub(start, d.pos - 1)
    local val = tonumber(numstr)
    if not val then
        error("invalid number: " .. numstr)
    end
    return val
end

local function decode_literal(d, literal, value)
    skip_ws(d)
    if d.str:sub(d.pos, d.pos + #literal - 1) == literal then
        d.pos = d.pos + #literal
        return value
    end
    error("expected '" .. literal .. "' at position " .. d.pos)
end

local function decode_array(d)
    expect(d, '[')
    local arr = {}
    skip_ws(d)
    if d.pos <= #d.str and d.str:sub(d.pos, d.pos) == ']' then
        d.pos = d.pos + 1
        return arr
    end
    while true do
        arr[#arr + 1] = decode_value(d)
        skip_ws(d)
        if d.pos > #d.str then
            error("unterminated array at position " .. d.pos)
        end
        local c = d.str:sub(d.pos, d.pos)
        if c == ']' then
            d.pos = d.pos + 1
            return arr
        elseif c == ',' then
            d.pos = d.pos + 1
        else
            error("expected ',' or ']' in array at position " .. d.pos)
        end
    end
end

local function decode_object(d)
    expect(d, '{')
    local obj = {}
    skip_ws(d)
    if d.pos <= #d.str and d.str:sub(d.pos, d.pos) == '}' then
        d.pos = d.pos + 1
        return obj
    end
    while true do
        skip_ws(d)
        if d.pos > #d.str or d.str:sub(d.pos, d.pos) ~= '"' then
            error("expected string key in object at position " .. d.pos)
        end
        local key = decode_string(d)
        skip_ws(d)
        expect(d, ':')
        obj[key] = decode_value(d)
        skip_ws(d)
        if d.pos > #d.str then
            error("unterminated object at position " .. d.pos)
        end
        local c = d.str:sub(d.pos, d.pos)
        if c == '}' then
            d.pos = d.pos + 1
            return obj
        elseif c == ',' then
            d.pos = d.pos + 1
        else
            error("expected ',' or '}' in object at position " .. d.pos)
        end
    end
end

decode_value = function(d)
    skip_ws(d)
    if d.pos > #d.str then
        error("unexpected end of input")
    end
    local c = d.str:sub(d.pos, d.pos)
    if c == '"' then
        return decode_string(d)
    elseif c == '{' then
        return decode_object(d)
    elseif c == '[' then
        return decode_array(d)
    elseif c == 't' then
        return decode_literal(d, "true", true)
    elseif c == 'f' then
        return decode_literal(d, "false", false)
    elseif c == 'n' then
        return decode_literal(d, "null", nil)
    elseif c == '-' or (c >= '0' and c <= '9') then
        return decode_number(d)
    else
        error("unexpected character '" .. c .. "' at position " .. d.pos)
    end
end

function json.decode(str)
    if type(str) ~= "string" then
        return nil, "decode expects a string argument"
    end
    if str == "" then
        return nil, "empty string"
    end
    local d = create_decoder(str)
    local ok, result = pcall(decode_value, d)
    if ok then
        return result
    else
        return nil, "decode error: " .. tostring(result)
    end
end

-- Convenience: json.null sentinel for explicit null values
json.null = setmetatable({}, { __tostring = function() return "null" end })

return json
