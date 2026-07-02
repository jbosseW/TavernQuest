local Clipboard = {}

---------------------------------------------------------------------------
-- Internal state
---------------------------------------------------------------------------

local stored = nil  -- { data = <deep copy>, dataType = <string> }

---------------------------------------------------------------------------
-- Deep copy helper
---------------------------------------------------------------------------

--- Recursively deep-copy a value. Handles nested tables, preserves
--- metatables on the top-level table only (shallow metatable copy).
--- Does not handle userdata, coroutines, or circular references by
--- default; a seen-set guards against infinite recursion on cycles.
--- @param value  any value to copy
--- @param seen   (internal) table of already-visited tables
--- @return deep copy of the value
local function deepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}

    -- Guard against circular references
    if seen[value] then
        return seen[value]
    end

    local copy = {}
    seen[value] = copy

    for k, v in pairs(value) do
        local keyCopy = deepCopy(k, seen)
        copy[keyCopy] = deepCopy(v, seen)
    end

    local mt = getmetatable(value)
    if mt then
        setmetatable(copy, mt)
    end

    return copy
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

--- Store data in the clipboard. The data is deep-copied so the caller
--- can safely mutate the original after copying.
---
--- If dataType is "text" and the data is a string, it will also be
--- pushed to the system clipboard via love.system.setClipboardText.
---
--- @param data      The data to copy (any Lua value; tables are deep-copied)
--- @param dataType  A string tag identifying the kind of data
---                  (e.g. "item", "enemy", "npc", "quest", "tile_selection", "text")
function Clipboard.copy(data, dataType)
    assert(data ~= nil, "Clipboard.copy() requires data")
    assert(type(dataType) == "string", "Clipboard.copy() requires a string dataType")

    stored = {
        data = deepCopy(data),
        dataType = dataType,
    }

    -- Mirror plain text to the OS clipboard when available
    if dataType == "text" and type(data) == "string" then
        if love and love.system and love.system.setClipboardText then
            love.system.setClipboardText(data)
        end
    end
end

--- Retrieve the current clipboard contents.
---
--- If the internal clipboard is empty but the system clipboard contains
--- text, a text entry is synthesised automatically so cross-application
--- paste works seamlessly.
---
--- @return table {data=..., dataType=...} or nil if empty
function Clipboard.paste()
    -- If we have internally stored data, return a deep copy so the
    -- consumer cannot mutate the clipboard contents.
    if stored then
        return {
            data = deepCopy(stored.data),
            dataType = stored.dataType,
        }
    end

    -- Fall back to the OS clipboard for text
    if love and love.system and love.system.getClipboardText then
        local sysText = love.system.getClipboardText()
        if sysText and sysText ~= "" then
            return {
                data = sysText,
                dataType = "text",
            }
        end
    end

    return nil
end

--- Check whether the clipboard holds data of a specific type.
---
--- @param dataType  string type tag to check for (optional; if nil, returns
---                  true when *any* data is present)
--- @return boolean
function Clipboard.hasData(dataType)
    if dataType == nil then
        if stored then
            return true
        end
        -- Check system clipboard as fallback
        if love and love.system and love.system.getClipboardText then
            local sysText = love.system.getClipboardText()
            return sysText ~= nil and sysText ~= ""
        end
        return false
    end

    if stored and stored.dataType == dataType then
        return true
    end

    -- "text" type can also come from the system clipboard
    if dataType == "text" and not stored then
        if love and love.system and love.system.getClipboardText then
            local sysText = love.system.getClipboardText()
            return sysText ~= nil and sysText ~= ""
        end
    end

    return false
end

--- Clear all clipboard data.
function Clipboard.clear()
    stored = nil
end

--- Expose the deep-copy utility for external use (e.g. undo snapshots).
--- @param value  any Lua value
--- @return deep copy of the value
function Clipboard.deepCopy(value)
    return deepCopy(value)
end

return Clipboard
