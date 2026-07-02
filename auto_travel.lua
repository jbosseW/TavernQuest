-- Auto-Travel System
-- Allows players to discover and auto-travel to locations with step-by-step movement

local AutoTravel = {}

-- Dependencies
local Backpack = require("backpack")
local MathUtil = require("mathutil")
local WorldGen = nil
local TextRPG = nil
local F = nil

-- Lazy-load dependencies to avoid circular requires
local function ensureDependencies()
    if not WorldGen then
        WorldGen = require("worldgen")
    end
    if not TextRPG then
        TextRPG = require("textrpg")
    end
    if not F then
        F = (TextRPG and TextRPG.F) or {}  -- Fixed: Check TextRPG is not nil before accessing .F
    end
end

-- Layer constants (matches worldgen.lua)
local LAYERS = {
    SURFACE = 0,
    HOLLOW = -1000,
}

-- Location type icons
local LOCATION_ICONS = {
    town = "🏰",
    dungeon = "⚔️",
    landmark = "📍",
    quest_site = "❓",
    cave = "🕳️",
    mine = "⛏️",
    vampire_den = "🦇",
    crypt = "💀",
    lich_lair = "☠️",
}

-- UI state
AutoTravel.menuOpen = false
AutoTravel.viewMode = "list"  -- "list" or "map"
AutoTravel.scrollOffset = 0
AutoTravel.selectedIndex = 1
AutoTravel.filters = {
    type = "all",  -- "all", "town", "dungeon", "landmark", "quest_site"
    region = "all",
    status = "all",  -- "all", "visited", "unvisited"
}
AutoTravel.sortMode = "distance"  -- "distance", "name", "region"

-- Cache for filtered locations (to avoid recalculating every frame)
AutoTravel._cachedFilteredLocations = nil
AutoTravel._cacheInvalidated = true

-- Get travel state from PlayerData (or create default)
local function getTravelState()
    if PlayerData and PlayerData.autoTravelState then
        return PlayerData.autoTravelState
    end

    -- Default state
    local defaultState = {
        active = false,
        targetLocation = nil,
        path = {},
        currentStep = 1,
        travelMethod = nil,  -- "walk", "mount", "flying"
        timer = 0,
        moveDelay = 0.3,  -- Seconds between tile moves
        paused = false,
        pauseReason = nil,
        totalDistance = 0,
        distanceTraveled = 0,
    }

    -- Initialize in PlayerData if it exists
    if PlayerData then
        PlayerData.autoTravelState = defaultState
    end

    return defaultState
end

-- ============================================================================
--                         LOCATION DATA MANAGEMENT
-- ============================================================================

-- Discover a new location
function AutoTravel.discoverLocation(locationData)
    ensureDependencies()
    if not PlayerData then return false end

    -- Validate required fields
    if not locationData.id or not locationData.name or not locationData.x or not locationData.y then
        if TextRPG and TextRPG.addLog then
            TextRPG.addLog("❌ Cannot discover location: missing required fields (id, name, x, y)")
        end
        return false
    end

    -- Default layer to SURFACE if not provided
    if locationData.layer == nil then
        locationData.layer = LAYERS.SURFACE
    end

    -- Default type if not provided
    if not locationData.type then
        locationData.type = "landmark"
    end

    -- Initialize discoveredLocations if needed
    if not PlayerData.discoveredLocations then
        PlayerData.discoveredLocations = {}
    end

    -- Check if already discovered
    if PlayerData.discoveredLocations[locationData.id] then
        return false  -- Already discovered
    end

    -- Add discovery metadata
    locationData.discoveredDate = PlayerData.textRPG and PlayerData.textRPG.dayNum or 0
    locationData.visited = false
    locationData.visitCount = 0
    locationData.lastVisited = nil

    -- Set default icon if not provided
    if not locationData.icon then
        locationData.icon = LOCATION_ICONS[locationData.type] or "📍"
    end

    -- Store location
    PlayerData.discoveredLocations[locationData.id] = locationData

    -- Show discovery notification
    if TextRPG and TextRPG.addLog then
        TextRPG.addLog(string.format("📍 Discovered: %s (%s)", locationData.name, locationData.type))
    end

    return true
end

-- Get all discovered locations
function AutoTravel.getDiscoveredLocations()
    if not PlayerData or not PlayerData.discoveredLocations then
        return {}
    end

    local locations = {}
    for id, loc in pairs(PlayerData.discoveredLocations) do
        table.insert(locations, loc)
    end

    return locations
end

-- Get a specific location by ID
function AutoTravel.getLocation(id)
    if not PlayerData or not PlayerData.discoveredLocations then
        return nil
    end

    return PlayerData.discoveredLocations[id]
end

-- Mark location as visited
function AutoTravel.markVisited(id)
    ensureDependencies()
    local loc = AutoTravel.getLocation(id)
    if loc then
        loc.visited = true
        loc.visitCount = (loc.visitCount or 0) + 1
        loc.lastVisited = PlayerData.textRPG and PlayerData.textRPG.dayNum or 0
    end
end

-- ============================================================================
--                         DISTANCE AND TIME CALCULATIONS
-- ============================================================================

-- Calculate Manhattan distance between two points (delegates to shared MathUtil)
function AutoTravel.calculateDistance(x1, y1, x2, y2)
    return MathUtil.getDistance(x1, y1, x2, y2)
end

-- Get travel time estimate in hours
function AutoTravel.getTravelTime(distance, travelMethod)
    local baseSpeed = 1.0  -- Tiles per hour on foot
    local speedMultiplier = 1.0

    if travelMethod == "mount" then
        speedMultiplier = Backpack.getMountSpeedMultiplier() or 2.0
    elseif travelMethod == "flying" then
        speedMultiplier = 4.0
    end

    local travelSpeed = baseSpeed * speedMultiplier
    if travelSpeed <= 0 then travelSpeed = 1 end
    local hours = distance / travelSpeed

    return hours
end

-- Get available travel methods for a location
function AutoTravel.getAvailableMethods(targetX, targetY, targetLayer)
    if not PlayerData or not PlayerData.textRPG then
        return {}
    end

    local world = PlayerData.textRPG.world
    local currentX = world and world.playerX or 0
    local currentY = world and world.playerY or 0
    local currentLayer = (world and world.currentLayer) or LAYERS.SURFACE

    -- Cannot travel between layers
    if currentLayer ~= targetLayer then
        return {}
    end

    local methods = {}
    local distance = AutoTravel.calculateDistance(currentX, currentY, targetX, targetY)

    -- Walking is always available
    table.insert(methods, {
        id = "walk",
        name = "Walk",
        icon = "🚶",
        available = true,
        time = AutoTravel.getTravelTime(distance, "walk"),
        reason = nil,
    })

    -- Check for mount
    local mount = Backpack.getEquippedMount()
    if mount then
        if mount.mountType == "flying" then
            table.insert(methods, {
                id = "flying",
                name = "Flying",
                icon = "🦅",
                available = true,
                time = AutoTravel.getTravelTime(distance, "flying"),
                reason = nil,
            })
        else
            table.insert(methods, {
                id = "mount",
                name = "Mounted",
                icon = "🐴",
                available = true,
                time = AutoTravel.getTravelTime(distance, "mount"),
                reason = nil,
            })
        end
    else
        table.insert(methods, {
            id = "mount",
            name = "Mounted",
            icon = "🐴",
            available = false,
            time = 0,
            reason = "No mount equipped",
        })
    end

    return methods
end

-- ============================================================================
--                         PATHFINDING
-- ============================================================================

-- Check if a tile is traversable based on travel method
function AutoTravel.isTileTraversable(x, y, travelMethod)
    ensureDependencies()
    if not WorldGen or not WorldGen.getTile then
        return false
    end

    local tile = WorldGen.getTile(x, y)
    if not tile or not tile.type then
        return false
    end

    -- Flying can go anywhere
    if travelMethod == "flying" then
        return true
    end

    -- Define impassable tile types for walking/mounted travel
    local impassableTiles = {
        ocean = true,
        deep_ocean = true,
        water = true,
        shallow_water = true,
        mountain = true,
        reef = true,
    }

    -- Check if tile type is impassable
    if impassableTiles[tile.type] then
        -- Water tiles - need aquatic mount or boat for mounted travel
        if tile.type == "ocean" or tile.type == "deep_ocean" or tile.type == "water" or tile.type == "shallow_water" or tile.type == "reef" then
            -- Check if current equipped mount matches the travel method being evaluated
            if travelMethod == "mount" then
                local mount = Backpack.getEquippedMount()
                if mount and (mount.mountType == "aquatic" or mount.mountType == "boat") then
                    return true
                end
            end
            return false  -- Walking cannot cross water
        end

        -- Mountains are impassable for walking and normal mounts
        return false
    end

    return true
end

-- Calculate path from current position to target
function AutoTravel.calculatePath(targetX, targetY, travelMethod)
    if not PlayerData or not PlayerData.textRPG then
        return nil, "Player data not available"
    end

    local world = PlayerData.textRPG.world
    local startX = world and world.playerX or 0
    local startY = world and world.playerY or 0

    -- Simple greedy pathfinding (matches autoplay system)
    local path = {}
    local currentX = startX
    local currentY = startY
    local maxSteps = 1000  -- Safety limit
    local steps = 0

    while (currentX ~= targetX or currentY ~= targetY) and steps < maxSteps do
        local dx, dy = 0, 0

        -- Calculate direction
        if currentX < targetX then
            dx = 1
        elseif currentX > targetX then
            dx = -1
        end

        if currentY < targetY then
            dy = 1
        elseif currentY > targetY then
            dy = -1
        end

        -- Try diagonal move first
        local nextX = currentX + dx
        local nextY = currentY + dy

        if AutoTravel.isTileTraversable(nextX, nextY, travelMethod) then
            table.insert(path, {x = nextX, y = nextY})
            currentX = nextX
            currentY = nextY
        else
            -- Try horizontal only
            nextX = currentX + dx
            nextY = currentY
            if dx ~= 0 and AutoTravel.isTileTraversable(nextX, nextY, travelMethod) then
                table.insert(path, {x = nextX, y = nextY})
                currentX = nextX
                currentY = nextY
            else
                -- Try vertical only
                nextX = currentX
                nextY = currentY + dy
                if dy ~= 0 and AutoTravel.isTileTraversable(nextX, nextY, travelMethod) then
                    table.insert(path, {x = nextX, y = nextY})
                    currentX = nextX
                    currentY = nextY
                else
                    -- Path blocked
                    return nil, "Path blocked - cannot reach destination"
                end
            end
        end

        steps = steps + 1
    end

    if steps >= maxSteps then
        return nil, "Path too long - destination unreachable"
    end

    return path, nil
end

-- ============================================================================
--                         TRAVEL MENU UI
-- ============================================================================

-- Open the travel menu
function AutoTravel.openTravelMenu()
    AutoTravel.menuOpen = true
    AutoTravel.scrollOffset = 0
    AutoTravel.selectedIndex = 1
    AutoTravel.viewMode = "list"
    AutoTravel._cacheInvalidated = true  -- Invalidate cache when opening menu
end

-- Close the travel menu
function AutoTravel.closeTravelMenu()
    AutoTravel.menuOpen = false
end

-- Get filtered and sorted locations for display
function AutoTravel.getFilteredLocations()
    -- Return cached results if valid
    if not AutoTravel._cacheInvalidated and AutoTravel._cachedFilteredLocations then
        return AutoTravel._cachedFilteredLocations
    end

    local locations = AutoTravel.getDiscoveredLocations()
    local filtered = {}

    if not PlayerData or not PlayerData.textRPG then
        AutoTravel._cachedFilteredLocations = filtered
        AutoTravel._cacheInvalidated = false
        return filtered
    end

    local world = PlayerData.textRPG.world
    local currentX = world and world.playerX or 0
    local currentY = world and world.playerY or 0
    local currentLayer = (world and world.currentLayer) or LAYERS.SURFACE

    -- Apply filters
    for _, loc in ipairs(locations) do
        local include = true

        -- Type filter
        if AutoTravel.filters.type ~= "all" and loc.type ~= AutoTravel.filters.type then
            include = false
        end

        -- Region filter
        if AutoTravel.filters.region ~= "all" and loc.region ~= AutoTravel.filters.region then
            include = false
        end

        -- Status filter
        if AutoTravel.filters.status == "visited" and not loc.visited then
            include = false
        elseif AutoTravel.filters.status == "unvisited" and loc.visited then
            include = false
        end

        if include then
            -- Create a shallow copy with temp fields to avoid polluting save data
            local locCopy = {
                id = loc.id,
                name = loc.name,
                type = loc.type,
                x = loc.x,
                y = loc.y,
                layer = loc.layer,
                discoveredBy = loc.discoveredBy,
                discoveredDate = loc.discoveredDate,
                region = loc.region,
                icon = loc.icon,
                description = loc.description,
                visited = loc.visited,
                visitCount = loc.visitCount,
                lastVisited = loc.lastVisited,
                -- Temp fields for sorting/display (not saved)
                _distance = AutoTravel.calculateDistance(currentX, currentY, loc.x, loc.y),
                _sameLayer = (loc.layer == currentLayer),
            }
            table.insert(filtered, locCopy)
        end
    end

    -- Sort locations
    if AutoTravel.sortMode == "distance" then
        table.sort(filtered, function(a, b)
            if not a._sameLayer and b._sameLayer then return false end
            if a._sameLayer and not b._sameLayer then return true end
            return a._distance < b._distance
        end)
    elseif AutoTravel.sortMode == "name" then
        table.sort(filtered, function(a, b) return a.name < b.name end)
    elseif AutoTravel.sortMode == "region" then
        table.sort(filtered, function(a, b)
            if a.region == b.region then
                return a.name < b.name
            end
            return (a.region or "") < (b.region or "")
        end)
    end

    -- Cache results and mark as valid
    AutoTravel._cachedFilteredLocations = filtered
    AutoTravel._cacheInvalidated = false

    return filtered
end

-- Invalidate the cached filtered locations (call when filters/sort changes)
function AutoTravel.invalidateCache()
    AutoTravel._cacheInvalidated = true
    -- Reset scroll position when filters change
    AutoTravel.scrollOffset = 0
    AutoTravel.selectedIndex = 1
end

-- Draw travel menu list view
function AutoTravel.drawListView()
    local locations = AutoTravel.getFilteredLocations()
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()

    -- Background
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", 50, 50, screenWidth - 100, screenHeight - 100)

    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", 50, 50, screenWidth - 100, screenHeight - 100)

    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("🗺️ TRAVEL MENU (Press ESC to close, TAB for map view)", 70, 70, 0, 1.5)

    -- Filters and sort
    love.graphics.print(string.format("Filter: %s | Sort: %s", AutoTravel.filters.type, AutoTravel.sortMode), 70, 100)

    -- Location list
    local startY = 140
    local lineHeight = 80
    local visibleCount = math.floor((screenHeight - 200) / lineHeight)

    if #locations == 0 then
        love.graphics.print("No locations discovered yet. Explore, complete quests, or read books!", 70, startY)
        return
    end

    for i = 1, math.min(visibleCount, #locations - AutoTravel.scrollOffset) do
        local idx = i + AutoTravel.scrollOffset
        local loc = locations[idx]
        local y = startY + (i - 1) * lineHeight

        -- Highlight selected
        if idx == AutoTravel.selectedIndex then
            love.graphics.setColor(0.3, 0.3, 0.5, 0.5)
            love.graphics.rectangle("fill", 60, y - 5, screenWidth - 120, lineHeight - 5)
        end

        -- Location info
        love.graphics.setColor(1, 1, 1)
        local visitedText = loc.visited and string.format("✓ Visited %dx", loc.visitCount) or "Unvisited"
        local layerText = loc._sameLayer and "" or " [Different Layer]"
        local header = string.format("%s %s (%d tiles)%s", loc.icon, loc.name, loc._distance, layerText)
        love.graphics.print(header, 70, y)

        local subtext = string.format("%s · %s · %s", loc.region or "Unknown", loc.type, visitedText)
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print(subtext, 90, y + 20)

        -- Travel methods
        if loc._sameLayer then
            local methods = AutoTravel.getAvailableMethods(loc.x, loc.y, loc.layer)
            for j, method in ipairs(methods) do
                local methodY = y + 35 + (j - 1) * 15
                if method.available then
                    love.graphics.setColor(0.5, 1, 0.5)
                    love.graphics.print(string.format("  [%d] %s %s: %.1f hours ✓", j, method.icon, method.name, method.time), 90, methodY)
                else
                    love.graphics.setColor(0.5, 0.5, 0.5)
                    love.graphics.print(string.format("  [%d] %s %s: %s ✗", j, method.icon, method.name, method.reason), 90, methodY)
                end
            end
        else
            love.graphics.setColor(0.8, 0.3, 0.3)
            love.graphics.print("  Cannot travel between layers", 90, y + 35)
        end
    end

    -- Instructions
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("↑↓: Select | 1-3: Choose travel method | ESC: Close", 70, screenHeight - 80)
end

-- Draw travel menu map view
function AutoTravel.drawMapView()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("🗺️ MAP VIEW - Coming soon! (Press TAB for list view)", 100, 100, 0, 1.5)
end

-- Draw travel menu
function AutoTravel.drawTravelMenu()
    if not AutoTravel.menuOpen then return end

    if AutoTravel.viewMode == "list" then
        AutoTravel.drawListView()
    else
        AutoTravel.drawMapView()
    end
end

-- Handle travel menu input
function AutoTravel.handleTravelMenuInput(key)
    if not AutoTravel.menuOpen then return false end

    if key == "escape" then
        AutoTravel.closeTravelMenu()
        return true
    end

    if key == "tab" then
        AutoTravel.viewMode = (AutoTravel.viewMode == "list") and "map" or "list"
        return true
    end

    local locations = AutoTravel.getFilteredLocations()

    if key == "up" then
        AutoTravel.selectedIndex = math.max(1, AutoTravel.selectedIndex - 1)
        if AutoTravel.selectedIndex <= AutoTravel.scrollOffset then
            AutoTravel.scrollOffset = math.max(0, AutoTravel.scrollOffset - 1)
        end
        return true
    elseif key == "down" then
        AutoTravel.selectedIndex = math.min(#locations, AutoTravel.selectedIndex + 1)
        local visibleCount = 6
        if AutoTravel.selectedIndex > AutoTravel.scrollOffset + visibleCount then
            AutoTravel.scrollOffset = AutoTravel.selectedIndex - visibleCount
        end
        return true
    end

    -- Number keys for travel method selection
    if key >= "1" and key <= "3" then
        local methodIndex = tonumber(key)
        -- Bounds check to prevent index out of range
        if AutoTravel.selectedIndex > 0 and AutoTravel.selectedIndex <= #locations then
            local selectedLoc = locations[AutoTravel.selectedIndex]
            if selectedLoc and selectedLoc._sameLayer then
                AutoTravel.startTravel(selectedLoc, methodIndex)
            end
        end
        return true
    end

    return false
end

-- ============================================================================
--                         TRAVEL EXECUTION
-- ============================================================================

-- Start auto-travel to a location
function AutoTravel.startTravel(location, methodIndex)
    ensureDependencies()
    if not location then return false end

    -- Check vampire daylight restriction
    if PlayerData and PlayerData.textRPG and PlayerData.textRPG.player and PlayerData.textRPG.player.isVampire then
        local hour = PlayerData.textRPG.timeOfDay or 12
        if hour >= 6 and hour < 19 then
            if TextRPG and TextRPG.addLog then
                TextRPG.addLog("❌ Vampires cannot travel during daylight (6 AM - 7 PM)")
            end
            return false
        end
    end

    local methods = AutoTravel.getAvailableMethods(location.x, location.y, location.layer)
    local method = methods[methodIndex]

    if not method or not method.available then
        if TextRPG and TextRPG.addLog then
            TextRPG.addLog("❌ Cannot use that travel method")
        end
        return false
    end

    -- Calculate path
    local path, error = AutoTravel.calculatePath(location.x, location.y, method.id)
    if not path then
        if TextRPG and TextRPG.addLog then
            TextRPG.addLog("❌ " .. (error or "Cannot reach destination"))
        end
        return false
    end

    -- Initialize travel state in PlayerData
    local travelState = getTravelState()
    travelState.active = true
    travelState.targetLocation = location
    travelState.path = path
    travelState.currentStep = 1
    travelState.travelMethod = method.id
    travelState.timer = 0
    travelState.paused = false
    travelState.pauseReason = nil
    travelState.totalDistance = #path
    travelState.distanceTraveled = 0

    -- Adjust move delay based on travel method
    local baseDelay = 0.3
    if method.id == "mount" then
        baseDelay = 0.15
    elseif method.id == "flying" then
        baseDelay = 0.1
    end
    travelState.moveDelay = baseDelay

    -- Close menu
    AutoTravel.closeTravelMenu()

    if TextRPG and TextRPG.addLog then
        TextRPG.addLog(string.format("🗺️ Traveling to %s via %s (%d tiles)", location.name, method.name, #path))
    end

    return true
end

-- Update auto-travel (called each frame)
function AutoTravel.update(dt, state)
    ensureDependencies()
    local travelState = getTravelState()
    if not travelState.active then return end
    if travelState.paused then return end

    -- Increment timer
    travelState.timer = travelState.timer + dt

    -- Check if it's time to move
    if travelState.timer >= travelState.moveDelay then
        travelState.timer = 0

        -- Get next step
        local step = travelState.path[travelState.currentStep]
        if not step then
            -- Arrived at destination
            AutoTravel.onArrival()
            return
        end

        -- Calculate movement direction
        local currentX = state.world and state.world.playerX or 0
        local currentY = state.world and state.world.playerY or 0
        local dx = step.x - currentX
        local dy = step.y - currentY

        -- Move player
        if F and F.movePlayer then
            local moved = F.movePlayer(dx, dy, state)
            if moved then
                travelState.currentStep = travelState.currentStep + 1
                travelState.distanceTraveled = travelState.distanceTraveled + 1

                -- Check for interrupts
                AutoTravel.checkInterrupts(state)
            else
                -- Movement blocked
                AutoTravel.cancelTravel("Path blocked")
            end
        end
    end
end

-- Check for travel interrupts
function AutoTravel.checkInterrupts(state)
    local travelState = getTravelState()

    -- Check combat
    if state.phase == "combat" or state.phase == "tactical_combat" then
        if not travelState.paused then
            AutoTravel.pauseTravel("Combat encounter")
        end
        return true
    end

    -- Check low HP
    if state.hp and state.maxhp and state.hp < state.maxhp * 0.3 then
        if not travelState.paused then
            AutoTravel.pauseTravel("Low health - rest recommended")
        end
        return true
    end

    -- Auto-resume if we were paused by combat and combat is over
    if travelState.paused and travelState.pauseReason == "Combat encounter" then
        if state.phase == "map" then
            AutoTravel.resumeTravel()
        end
    end

    return false
end

-- Pause travel
function AutoTravel.pauseTravel(reason)
    ensureDependencies()
    local travelState = getTravelState()
    travelState.paused = true
    travelState.pauseReason = reason

    if TextRPG and TextRPG.addLog then
        TextRPG.addLog(string.format("⏸️ Travel paused: %s", reason))
    end
end

-- Resume travel
function AutoTravel.resumeTravel()
    ensureDependencies()
    local travelState = getTravelState()
    if not travelState.active then return end

    travelState.paused = false
    travelState.pauseReason = nil

    if TextRPG and TextRPG.addLog then
        TextRPG.addLog("▶️ Travel resumed")
    end
end

-- Cancel travel
function AutoTravel.cancelTravel(reason)
    ensureDependencies()
    local travelState = getTravelState()
    travelState.active = false
    travelState.paused = false

    if TextRPG and TextRPG.addLog then
        TextRPG.addLog(string.format("❌ Travel cancelled: %s", reason or "Unknown reason"))
    end
end

-- Handle arrival at destination
function AutoTravel.onArrival()
    ensureDependencies()
    local travelState = getTravelState()
    local location = travelState.targetLocation
    if not location then
        travelState.active = false
        return
    end

    -- Mark as visited
    AutoTravel.markVisited(location.id)

    -- Clear travel state
    travelState.active = false

    if TextRPG and TextRPG.addLog then
        TextRPG.addLog(string.format("✅ Arrived at %s!", location.name))
    end

    -- Handle destination type
    if location.type == "town" then
        -- Town entry will be handled by normal game flow when player is on town tile
        if TextRPG and TextRPG.addLog then
            TextRPG.addLog("Press E to enter town")
        end
    elseif location.type == "dungeon" or location.type == "cave" or location.type == "mine" or
           location.type == "vampire_den" or location.type == "crypt" or location.type == "lich_lair" then
        -- Set pending dungeon for entry
        if PlayerData and PlayerData.textRPG then
            local state = PlayerData.textRPG
            state.pendingDungeon = {
                x = location.x,
                y = location.y,
                isWaterDungeon = false
            }
            if TextRPG and TextRPG.addLog then
                TextRPG.addLog("Press E to enter the dungeon")
            end
        end
    elseif location.type == "landmark" or location.type == "quest_site" then
        -- Award exploration XP (first visit only)
        if location.visitCount == 1 then  -- Fixed: Was <= 1, which gave XP on visitCount 0 AND 1
            if PlayerData and PlayerData.textRPG and PlayerData.textRPG.player then
                local xpReward = 10 + (PlayerData.textRPG.player.level or 1) * 5
                if F and F.gainXP then
                    F.gainXP(xpReward)
                end
                if TextRPG and TextRPG.addLog then
                    TextRPG.addLog(string.format("+%d XP for visiting %s", xpReward, location.name))
                end
            end
        end
    end
end

-- Draw travel progress indicator
function AutoTravel.drawTravelProgress()
    local travelState = getTravelState()
    if not travelState.active then return end

    local screenWidth = love.graphics.getWidth()
    local location = travelState.targetLocation

    if not location then return end

    -- Progress bar
    local barWidth = 300
    local barHeight = 30
    local x = (screenWidth - barWidth) / 2
    local y = 20

    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", x - 5, y - 5, barWidth + 10, barHeight + 10)

    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("fill", x, y, barWidth, barHeight)

    local progress = travelState.totalDistance > 0 and (travelState.distanceTraveled / travelState.totalDistance) or 0
    love.graphics.setColor(0.2, 0.6, 1.0)
    love.graphics.rectangle("fill", x, y, barWidth * progress, barHeight)

    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", x, y, barWidth, barHeight)

    -- Text
    local text = string.format("→ %s (%d/%d tiles)", location.name, travelState.distanceTraveled, travelState.totalDistance)
    love.graphics.print(text, x + 10, y + 5)

    -- Pause indicator
    if travelState.paused then
        love.graphics.setColor(1, 0.5, 0)
        love.graphics.print("⏸️ PAUSED: " .. (travelState.pauseReason or ""), x, y + 40)
    end
end

return AutoTravel
