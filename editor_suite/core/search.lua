local Search = {}

---------------------------------------------------------------------------
-- Internal helpers
---------------------------------------------------------------------------

--- Convert a value to a lowercase string for case-insensitive comparison.
--- Returns "" for nil so callers never have to nil-check.
--- @param v  any value
--- @return string
local function toLowerStr(v)
    if v == nil then
        return ""
    end
    return string.lower(tostring(v))
end

--- Safely read a (possibly nested) field from a table.
--- Supports dot-separated paths like "stats.hp" for nested access.
--- @param item   table to read from
--- @param field  string field name or dot-path
--- @return the value, or nil if any part of the path is missing
local function getField(item, field)
    if type(item) ~= "table" then
        return nil
    end

    -- Fast path: no dot means a direct key lookup
    if not string.find(field, ".", 1, true) then
        return item[field]
    end

    -- Walk the dot-separated path
    local current = item
    for segment in string.gmatch(field, "[^%.]+") do
        if type(current) ~= "table" then
            return nil
        end
        current = current[segment]
    end
    return current
end

--- Shallow-copy an array (numerically-indexed portion only).
--- @param t  source array
--- @return new array containing the same elements
local function copyArray(t)
    local out = {}
    for i = 1, #t do
        out[i] = t[i]
    end
    return out
end

---------------------------------------------------------------------------
-- Text filtering
---------------------------------------------------------------------------

--- Filter items where any of the specified fields contain the search text
--- (case-insensitive, partial match).
---
--- @param items   array of tables to search
--- @param text    string to search for
--- @param fields  array of field name strings to inspect
--- @return new filtered array (original is not modified)
function Search.filterByText(items, text, fields)
    assert(type(items) == "table", "Search.filterByText: items must be a table")
    assert(type(fields) == "table", "Search.filterByText: fields must be a table")

    if text == nil or text == "" then
        return copyArray(items)
    end

    local lowerText = string.lower(text)
    local result = {}

    for i = 1, #items do
        local item = items[i]
        for f = 1, #fields do
            local value = getField(item, fields[f])
            if value ~= nil then
                local lowerValue = toLowerStr(value)
                if string.find(lowerValue, lowerText, 1, true) then
                    result[#result + 1] = item
                    break -- matched on this item, move to the next
                end
            end
        end
    end

    return result
end

---------------------------------------------------------------------------
-- Category filtering
---------------------------------------------------------------------------

--- Filter items by exact match on a single field.
---
--- @param items          array of tables
--- @param categoryField  string field name to compare
--- @param categoryValue  expected value (compared with ==)
--- @return new filtered array
function Search.filterByCategory(items, categoryField, categoryValue)
    assert(type(items) == "table", "Search.filterByCategory: items must be a table")
    assert(type(categoryField) == "string", "Search.filterByCategory: categoryField must be a string")

    if categoryValue == nil then
        return copyArray(items)
    end

    local result = {}
    for i = 1, #items do
        local item = items[i]
        local value = getField(item, categoryField)
        if value == categoryValue then
            result[#result + 1] = item
        end
    end
    return result
end

---------------------------------------------------------------------------
-- Range filtering
---------------------------------------------------------------------------

--- Filter items where a numeric field falls within [minVal, maxVal].
--- Either bound may be nil to leave that side unbounded.
---
--- @param items   array of tables
--- @param field   string field name containing a number
--- @param minVal  minimum value (inclusive), or nil for no lower bound
--- @param maxVal  maximum value (inclusive), or nil for no upper bound
--- @return new filtered array
function Search.filterByRange(items, field, minVal, maxVal)
    assert(type(items) == "table", "Search.filterByRange: items must be a table")
    assert(type(field) == "string", "Search.filterByRange: field must be a string")

    if minVal == nil and maxVal == nil then
        return copyArray(items)
    end

    local result = {}
    for i = 1, #items do
        local item = items[i]
        local value = getField(item, field)
        if type(value) == "number" then
            local aboveMin = (minVal == nil) or (value >= minVal)
            local belowMax = (maxVal == nil) or (value <= maxVal)
            if aboveMin and belowMax then
                result[#result + 1] = item
            end
        end
    end
    return result
end

---------------------------------------------------------------------------
-- Combined filter application
---------------------------------------------------------------------------

--- Apply multiple filter criteria at once.
---
--- The filters table may contain any combination of:
---   text     = { value = "sword", fields = {"name", "desc"} }
---   category = { field = "category", value = "weapon" }
---             -- OR an array of category filters:
---             { {field="category", value="weapon"}, {field="rarity", value="rare"} }
---   ranges   = { {field="level", min=1, max=10}, {field="hp", min=100} }
---
--- Filters are ANDed together -- an item must pass every filter.
---
--- @param items    array of tables
--- @param filters  filter specification table
--- @return new filtered array
function Search.applyFilters(items, filters)
    assert(type(items) == "table", "Search.applyFilters: items must be a table")

    if not filters or next(filters) == nil then
        return copyArray(items)
    end

    local result = copyArray(items)

    -- Text filter
    if filters.text and filters.text.value and filters.text.value ~= "" then
        result = Search.filterByText(result, filters.text.value, filters.text.fields or {})
    end

    -- Category filter (single or array of filters)
    if filters.category then
        local cat = filters.category
        if cat.field then
            -- Single category filter
            result = Search.filterByCategory(result, cat.field, cat.value)
        else
            -- Array of category filters
            for c = 1, #cat do
                local entry = cat[c]
                if entry.field then
                    result = Search.filterByCategory(result, entry.field, entry.value)
                end
            end
        end
    end

    -- Range filters
    if filters.ranges then
        for r = 1, #filters.ranges do
            local range = filters.ranges[r]
            if range.field then
                result = Search.filterByRange(result, range.field, range.min, range.max)
            end
        end
    end

    return result
end

---------------------------------------------------------------------------
-- Sorting
---------------------------------------------------------------------------

--- Sort items by a field value. Returns a new sorted array.
---
--- Handles mixed types gracefully: numbers sort numerically, strings sort
--- lexicographically (case-insensitive), and nils sort to the end.
---
--- @param items      array of tables
--- @param field      string field name to sort by
--- @param ascending  boolean (default true); false for descending order
--- @return new sorted array
function Search.sortBy(items, field, ascending)
    assert(type(items) == "table", "Search.sortBy: items must be a table")
    assert(type(field) == "string", "Search.sortBy: field must be a string")

    if ascending == nil then
        ascending = true
    end

    local sorted = copyArray(items)

    table.sort(sorted, function(a, b)
        local va = getField(a, field)
        local vb = getField(b, field)

        -- Push nils to the end regardless of sort direction
        if va == nil and vb == nil then return false end
        if va == nil then return false end
        if vb == nil then return true end

        -- Both numbers: numeric compare
        if type(va) == "number" and type(vb) == "number" then
            if ascending then
                return va < vb
            else
                return va > vb
            end
        end

        -- Both strings (or mixed): case-insensitive string compare
        local sa = toLowerStr(va)
        local sb = toLowerStr(vb)
        if ascending then
            return sa < sb
        else
            return sa > sb
        end
    end)

    return sorted
end

---------------------------------------------------------------------------
-- Search index for faster text lookups
---------------------------------------------------------------------------

--- Create a pre-computed search index that maps each item to its
--- concatenated, lowercased field text. Use with Search.queryIndex()
--- for repeated searches against the same data set.
---
--- @param items   array of tables to index
--- @param fields  array of field name strings to include in the index
--- @return index table (pass to Search.queryIndex)
function Search.createIndex(items, fields)
    assert(type(items) == "table", "Search.createIndex: items must be a table")
    assert(type(fields) == "table", "Search.createIndex: fields must be a table")

    local index = {
        items = items,
        entries = {},
    }

    for i = 1, #items do
        local item = items[i]
        local parts = {}
        for f = 1, #fields do
            local value = getField(item, fields[f])
            if value ~= nil then
                parts[#parts + 1] = toLowerStr(value)
            end
        end
        -- Join all field values with a null separator so partial matches
        -- cannot accidentally span across fields in a misleading way.
        index.entries[i] = table.concat(parts, "\0")
    end

    return index
end

--- Query a pre-built search index for items matching a text string
--- (case-insensitive, partial match).
---
--- @param index  index table created by Search.createIndex
--- @param text   search string
--- @return new filtered array of matching items
function Search.queryIndex(index, text)
    assert(type(index) == "table" and index.entries,
        "Search.queryIndex: invalid index (use Search.createIndex)")

    if text == nil or text == "" then
        return copyArray(index.items)
    end

    local lowerText = string.lower(text)
    local result = {}

    for i = 1, #index.entries do
        if string.find(index.entries[i], lowerText, 1, true) then
            result[#result + 1] = index.items[i]
        end
    end

    return result
end

return Search
