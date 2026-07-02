-- Math Utility Module
-- Shared mathematical functions used across the game

local MathUtil = {}

-- Get 8-way direction from one point to another
-- Returns: "north", "south", "east", "west", "northeast", "northwest", "southeast", "southwest"
function MathUtil.getDirection(fromX, fromY, toX, toY)
    local dx = toX - fromX
    local dy = toY - fromY

    if math.abs(dx) > math.abs(dy) then
        if dx > 0 then
            return dy > 0 and "southeast" or (dy < 0 and "northeast" or "east")
        else
            return dy > 0 and "southwest" or (dy < 0 and "northwest" or "west")
        end
    else
        if dy > 0 then
            return dx > 0 and "southeast" or (dx < 0 and "southwest" or "south")
        else
            return dx > 0 and "northeast" or (dx < 0 and "northwest" or "north")
        end
    end
end

-- Get Manhattan distance between two points
function MathUtil.getDistance(x1, y1, x2, y2)
    return math.abs(x1 - x2) + math.abs(y1 - y2)
end

-- Get simplified 4-way cardinal direction (N, S, E, W only)
-- Returns: "north", "south", "east", "west"
function MathUtil.getCardinalDirection(fromX, fromY, toX, toY)
    local dx = toX - fromX
    local dy = toY - fromY

    if math.abs(dx) > math.abs(dy) then
        return dx > 0 and "east" or "west"
    else
        return dy > 0 and "south" or "north"
    end
end

-- Clamp a value between min and max
function MathUtil.clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

-- Linear interpolation between a and b by factor t (0-1)
function MathUtil.lerp(a, b, t)
    return a + (b - a) * MathUtil.clamp(t, 0, 1)
end

-- Get Euclidean distance (more accurate than Manhattan for true distance)
function MathUtil.getEuclideanDistance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- Check if a point is within a rectangular bounds
function MathUtil.inBounds(x, y, minX, minY, maxX, maxY)
    return x >= minX and x <= maxX and y >= minY and y <= maxY
end

-- Get angle in radians between two points
function MathUtil.getAngle(fromX, fromY, toX, toY)
    return math.atan2(toY - fromY, toX - fromX)
end

return MathUtil
