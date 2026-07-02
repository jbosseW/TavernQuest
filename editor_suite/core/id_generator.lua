local IdGenerator = {}

--- Convert a human-readable name into a snake_case identifier.
-- "Health Potion" -> "health_potion"
-- "  Fire   Ball!! " -> "fire_ball"
-- Handles unicode-safe by only keeping ASCII alphanumerics and underscores.
-- @param name  The display name to convert
-- @return string  A valid snake_case id, or "unnamed" if input is empty/nil
function IdGenerator.generateId(name)
    if type(name) ~= "string" or name == "" then
        return "unnamed"
    end

    -- Lowercase the entire string
    local id = string.lower(name)

    -- Replace spaces with underscores
    id = string.gsub(id, "%s", "_")

    -- Strip everything that is not alphanumeric or underscore
    id = string.gsub(id, "[^%a%d_]", "")

    -- Collapse multiple consecutive underscores into one
    id = string.gsub(id, "_+", "_")

    -- Strip leading and trailing underscores
    id = string.gsub(id, "^_+", "")
    id = string.gsub(id, "_+$", "")

    -- If nothing remains after sanitization, return a fallback
    if id == "" then
        return "unnamed"
    end

    return id
end

--- Ensure an id is unique within a set of existing ids.
-- If the id already exists, appends _2, _3, etc. until a unique variant is found.
-- @param id          The base snake_case id to check
-- @param existingIds A table used as a set (keys are existing ids, values are truthy)
--                    OR an array of id strings
-- @return string     A unique id
function IdGenerator.ensureUnique(id, existingIds)
    if type(id) ~= "string" or id == "" then
        id = "unnamed"
    end
    if type(existingIds) ~= "table" then
        return id
    end

    -- Build a lookup set from the existing ids.
    -- Support both set-style { health_potion = true } and array-style { "health_potion" }.
    local lookup = {}
    for k, v in pairs(existingIds) do
        if type(k) == "number" and type(v) == "string" then
            -- Array entry
            lookup[v] = true
        elseif type(k) == "string" and v then
            -- Set entry
            lookup[k] = true
        end
    end

    if not lookup[id] then
        return id
    end

    -- Find the next available suffix
    local counter = 2
    while true do
        local candidate = id .. "_" .. counter
        if not lookup[candidate] then
            return candidate
        end
        counter = counter + 1

        -- Safety valve to avoid infinite loops on pathological input
        if counter > 10000 then
            return id .. "_" .. os.time()
        end
    end
end

--- Validate whether a string is a proper snake_case identifier.
-- Rules:
--   - Must be a non-empty string
--   - Only lowercase letters, digits, and underscores
--   - Must start with a lowercase letter
--   - Must not end with an underscore
--   - No consecutive underscores
-- @param id  The string to validate
-- @return boolean  true if valid, false otherwise
-- @return string|nil  Error message if invalid, nil if valid
function IdGenerator.validateId(id)
    if type(id) ~= "string" then
        return false, "id must be a string"
    end

    if id == "" then
        return false, "id must not be empty"
    end

    -- Only lowercase letters, digits, underscores
    if string.find(id, "[^%l%d_]") then
        return false, "id must contain only lowercase letters, digits, and underscores"
    end

    -- Must start with a lowercase letter
    if not string.find(id, "^%l") then
        return false, "id must start with a lowercase letter"
    end

    -- Must not end with underscore
    if string.find(id, "_$") then
        return false, "id must not end with an underscore"
    end

    -- No consecutive underscores
    if string.find(id, "__") then
        return false, "id must not contain consecutive underscores"
    end

    return true, nil
end

return IdGenerator
