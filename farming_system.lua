-- Farming System Module
-- Extracted from propertysystem.lua
-- Handles: crop planting, harvesting, watering, farm plot management, seasonal growth

local FarmingSystem = {}

local Backpack = require("backpack")

-- ============================================================================
--                      FARMING SYSTEM FUNCTIONS
-- ============================================================================

-- Initialize farm plots when farm improvement is built
function FarmingSystem.initializeFarm(state, claimKey, gridSize)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim then return false end

    gridSize = gridSize or 3
    local plotCount = gridSize * gridSize

    claim.farmPlots = {
        gridSize = gridSize,
        plots = {},
        lastChecked = state.daysPassed or 0,
        waterSource = "manual"
    }

    -- Initialize all plots as empty
    for i = 1, plotCount do
        claim.farmPlots.plots[i] = {
            state = "empty",
            cropId = nil,
            plantedDay = nil,
            lastWateredDay = nil,
            growthStage = 0,
            fertilized = false
        }
    end

    return true
end

-- Expand farm size (when improvement is built)
function FarmingSystem.expandFarm(state, claimKey, newSize)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim or not claim.farmPlots then
        -- No farm exists, initialize new one
        return FarmingSystem.initializeFarm(state, claimKey, newSize)
    end

    local farm = claim.farmPlots
    local oldSize = farm.gridSize
    local oldPlotCount = oldSize * oldSize
    local newPlotCount = newSize * newSize

    farm.gridSize = newSize

    -- Add new empty plots
    for i = oldPlotCount + 1, newPlotCount do
        farm.plots[i] = {
            state = "empty",
            cropId = nil,
            plantedDay = nil,
            lastWateredDay = nil,
            growthStage = 0,
            fertilized = false
        }
    end

    return true
end

-- Plant a seed in a plot
function FarmingSystem.plantSeed(state, claimKey, plotIndex, seedId)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim or not claim.farmPlots then
        return false, "No farm found"
    end

    local plot = claim.farmPlots.plots[plotIndex]
    if not plot then
        return false, "Invalid plot"
    end

    if plot.state ~= "empty" then
        return false, "Plot is not empty"
    end

    -- Check if player has seed
    if not Backpack.hasItem(seedId, 1) then
        return false, "No seeds in inventory"
    end

    local seedDef = Backpack.getItemDef(seedId)
    if not seedDef or seedDef.category ~= "seed" then
        return false, "Invalid seed"
    end

    -- Check season (unless greenhouse exists)
    if not (claim.improvements and claim.improvements.greenhouse) then
        if seedDef.seasons and #seedDef.seasons > 0 then
            local currentSeason = state.season or "brightbloom"
            local validSeason = false
            for _, season in ipairs(seedDef.seasons) do
                if season == currentSeason then
                    validSeason = true
                    break
                end
            end
            if not validSeason then
                return false, "Wrong season for this crop (needs " .. table.concat(seedDef.seasons, " or ") .. ")"
            end
        end
    end

    -- Consume seed
    Backpack.removeItem(seedId, 1)

    -- Plant crop
    plot.state = "planted"
    plot.cropId = seedId
    plot.plantedDay = state.daysPassed or 0
    plot.lastWateredDay = nil
    plot.growthStage = 0

    return true, "Planted " .. seedDef.name
end

-- Water a single plot
function FarmingSystem.waterPlot(state, claimKey, plotIndex)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim or not claim.farmPlots then
        return false, "No farm found"
    end

    local plot = claim.farmPlots.plots[plotIndex]
    if not plot then
        return false, "Invalid plot"
    end

    if plot.state == "empty" or plot.state == "withered" then
        return false, "Nothing to water"
    end

    plot.lastWateredDay = state.daysPassed or 0
    return true, "Plot watered"
end

-- Water all plots
function FarmingSystem.waterAllPlots(state, claimKey)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim or not claim.farmPlots then
        return false, "No farm found"
    end

    local count = 0
    for i, plot in ipairs(claim.farmPlots.plots) do
        if plot.state == "planted" or plot.state == "growing" then
            plot.lastWateredDay = state.daysPassed or 0
            count = count + 1
        end
    end

    return true, "Watered " .. count .. " plots"
end

-- Harvest a plot
function FarmingSystem.harvestPlot(state, claimKey, plotIndex)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim or not claim.farmPlots then
        return false, "No farm found"
    end

    local plot = claim.farmPlots.plots[plotIndex]
    if not plot then
        return false, "Invalid plot"
    end

    if plot.state ~= "harvestable" then
        return false, "Crop is not ready to harvest"
    end

    local seedDef = Backpack.getItemDef(plot.cropId)
    if not seedDef or not seedDef.harvestItem then
        return false, "Invalid crop"
    end

    -- Roll harvest quantity
    local quantity = math.random(seedDef.harvestMin or 1, seedDef.harvestMax or 1)

    -- Add items to backpack
    for i = 1, quantity do
        Backpack.addItem(seedDef.harvestItem, 1)
    end

    -- Reset plot
    plot.state = "empty"
    plot.cropId = nil
    plot.plantedDay = nil
    plot.lastWateredDay = nil
    plot.growthStage = 0
    plot.fertilized = false

    return true, "Harvested " .. quantity .. "x " .. seedDef.harvestItem
end

-- Clear a withered crop
function FarmingSystem.clearPlot(state, claimKey, plotIndex)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim or not claim.farmPlots then
        return false, "No farm found"
    end

    local plot = claim.farmPlots.plots[plotIndex]
    if not plot then
        return false, "Invalid plot"
    end

    plot.state = "empty"
    plot.cropId = nil
    plot.plantedDay = nil
    plot.lastWateredDay = nil
    plot.growthStage = 0
    plot.fertilized = false

    return true, "Plot cleared"
end

-- Apply fertilizer to a plot
function FarmingSystem.fertilizePlot(state, claimKey, plotIndex)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim or not claim.farmPlots then
        return false, "No farm found"
    end

    local plot = claim.farmPlots.plots[plotIndex]
    if not plot then
        return false, "Invalid plot"
    end

    if plot.state ~= "empty" then
        return false, "Can only fertilize empty plots"
    end

    if not Backpack.hasItem("fertilizer", 1) then
        return false, "No fertilizer in inventory"
    end

    Backpack.removeItem("fertilizer", 1)
    plot.fertilized = true

    return true, "Plot fertilized"
end

-- Update farm plots daily
function FarmingSystem.updateFarmPlots(state, claimKey, hoursElapsed)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim or not claim.farmPlots then return end

    local farm = claim.farmPlots
    local currentDay = state.daysPassed or 0

    -- Skip if already updated today
    if farm.lastChecked >= currentDay then
        return
    end

    -- Check for rain (auto-water feature)
    local isRaining = false
    if state.weather then
        local weather = state.weather.current or ""
        isRaining = (weather == "rainy" or weather == "stormy")
    end

    -- Auto-water if irrigation OR rain
    if (claim.improvements and claim.improvements.irrigation) or isRaining then
        for i, plot in ipairs(farm.plots) do
            if plot.state == "planted" or plot.state == "growing" then
                plot.lastWateredDay = currentDay
            end
        end
    end

    -- Update each plot
    for i, plot in ipairs(farm.plots) do
        if plot.state == "planted" or plot.state == "growing" then
            -- Check if watered
            if plot.lastWateredDay == currentDay then
                -- Grow the crop
                plot.growthStage = plot.growthStage + 1

                -- Get seed definition
                local seedDef = Backpack.getItemDef(plot.cropId)
                if seedDef and seedDef.growthDays then
                    if plot.growthStage >= seedDef.growthDays then
                        plot.state = "harvestable"
                    else
                        plot.state = "growing"
                    end
                end
            elseif (currentDay - (plot.lastWateredDay or 0)) >= 2 then
                -- Not watered for 2+ days, crop withers
                plot.state = "withered"
            end
            -- else: Not watered today, but not withered yet (no growth)
        end
    end

    farm.lastChecked = currentDay
end

return FarmingSystem
