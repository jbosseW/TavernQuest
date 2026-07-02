-- Shared font cache module
-- Replaces 21 duplicate fontCache implementations across the codebase
local FontCache = {}
local cache = {}

function FontCache.get(size)
    size = size or 14
    if not cache[size] then
        cache[size] = love.graphics.newFont(size)
    end
    return cache[size]
end

-- Allow clearing cache (e.g., on window resize)
function FontCache.clear()
    cache = {}
end

return FontCache
