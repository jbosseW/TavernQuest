-- Shared Seeded Random Number Generator
-- Provides both a stateful LCG class and stateless hash-based utilities
-- for deterministic procedural generation.

-- ============================================================================
--                     STATEFUL LCG CLASS (SeededRandom)
-- ============================================================================
-- A lightweight deterministic RNG so that the same seed always produces
-- the same sequence, independent of Lua's global math.random state.
-- Used by: towngen.lua

local SeededRandom = {}
SeededRandom.__index = SeededRandom

function SeededRandom.new(seed)
    local self = setmetatable({}, SeededRandom)
    -- Ensure seed fits within our modular arithmetic range
    self.state = math.abs((seed or os.time()) % 2147483648)
    if self.state == 0 then self.state = 1 end
    -- Warm up the generator
    for _ = 1, 10 do self:next() end
    return self
end

function SeededRandom:next()
    -- Simple LCG (Linear Congruential Generator)
    self.state = (self.state * 1103515245 + 12345) % 2147483648
    return self.state
end

function SeededRandom:random(a, b)
    local r = self:next() / 2147483648
    if a and b then
        return math.floor(r * (b - a + 1)) + a
    elseif a then
        return math.floor(r * a) + 1
    end
    return r
end

function SeededRandom:chance(probability)
    return self:random() < probability
end

-- ============================================================================
--                 STATELESS HASH UTILITIES (seededRandom)
-- ============================================================================
-- Simple seed-to-float hash function for one-shot random values.
-- Used by: worldgen.lua, npcmanager.lua

function SeededRandom.hash(seed)
    local x = math.sin(seed) * 43758.5453
    return x - math.floor(x)
end

function SeededRandom.hashInt(seed, min, max)
    return min + math.floor(SeededRandom.hash(seed) * (max - min + 1))
end

function SeededRandom.hashChoice(seed, list)
    local index = SeededRandom.hashInt(seed, 1, #list)
    return list[index]
end

-- Combine seeds for deterministic generation
-- Uses modulo to prevent numeric overflow with large seeds
function SeededRandom.combineSeed(seed1, seed2, seed3)
    local MOD = 2147483647  -- 2^31 - 1 (Mersenne prime, fits in double precision)
    local result = 0
    result = (result + ((seed1 or 0) % MOD) * 374761393) % MOD
    result = (result + ((seed2 or 0) % MOD) * 668265263) % MOD
    result = (result + ((seed3 or 0) % MOD) * 1013904223) % MOD
    return result
end

return SeededRandom
