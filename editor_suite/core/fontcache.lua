local FontCache = {}

local cache = {}
local defaultFont = nil

function FontCache.get(size)
    size = size or 14
    if not cache[size] then
        local ok, font = pcall(love.graphics.newFont, size)
        if ok then
            cache[size] = font
        else
            if not defaultFont then
                defaultFont = love.graphics.newFont(14)
            end
            cache[size] = defaultFont
        end
    end
    return cache[size]
end

function FontCache.getBold(size)
    local key = "bold_" .. (size or 14)
    if not cache[key] then
        cache[key] = FontCache.get(size)
    end
    return cache[key]
end

function FontCache.clear()
    cache = {}
    defaultFont = nil
end

return FontCache
