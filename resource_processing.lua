-- Resource Processing Module
-- Extracted from propertysystem.lua
-- Handles: lumber gathering, forest management, crop/goods processing

local ResourceProcessing = {}

local Backpack = require("backpack")

-- ============================================================================
--                      LUMBER GATHERING SYSTEM
-- ============================================================================

-- Forest tile lumber constants
ResourceProcessing.FOREST_MAX_LUMBER = 100  -- Max lumber a forest tile can have
ResourceProcessing.LUMBER_REGEN_RATE = 2     -- Lumber regenerated per day
ResourceProcessing.DEFORESTATION_THRESHOLD = 10  -- Below this, tile becomes deforested

-- Check if player has a lumber gathering tool
function ResourceProcessing.hasLumberTool()
    local tools = {
        {id = "woodcutter_axe", efficiency = 1.0},
        {id = "iron_saw", efficiency = 0.8},
        {id = "steel_lumber_axe", efficiency = 1.5},
        {id = "steel_axe", efficiency = 0.7},  -- Battle axe can work but less efficient
    }

    for _, tool in ipairs(tools) do
        if Backpack.hasItem(tool.id) then
            return true, tool.id, tool.efficiency
        end
    end
    return false, nil, 0
end

-- Get the best lumber tool the player has
function ResourceProcessing.getBestLumberTool()
    local tools = {
        {id = "steel_lumber_axe", efficiency = 1.5, minYield = 3, maxYield = 6},
        {id = "woodcutter_axe", efficiency = 1.0, minYield = 2, maxYield = 4},
        {id = "iron_saw", efficiency = 0.8, minYield = 1, maxYield = 3},
        {id = "steel_axe", efficiency = 0.7, minYield = 1, maxYield = 3},
    }

    for _, tool in ipairs(tools) do
        if Backpack.hasItem(tool.id) then
            return tool
        end
    end
    return nil
end

-- Get forest lumber level for a tile (stored in WorldGen)
function ResourceProcessing.getForestLumber(state, tileX, tileY)
    local WorldGen = require("worldgen")
    local tile = WorldGen.getTile(tileX, tileY)

    if not tile or tile.type ~= "forest" then
        return 0, false
    end

    -- Initialize lumber if not set
    if tile.lumber == nil then
        tile.lumber = ResourceProcessing.FOREST_MAX_LUMBER
    end

    return tile.lumber, true
end

-- Chop lumber from a forest tile
function ResourceProcessing.chopLumber(state, tileX, tileY)
    local WorldGen = require("worldgen")
    local tile = WorldGen.getTile(tileX, tileY)

    if not tile then
        return false, "Invalid tile", 0
    end

    if tile.type ~= "forest" then
        return false, "Not a forest tile", 0
    end

    -- Check for tool
    local tool = ResourceProcessing.getBestLumberTool()
    if not tool then
        return false, "Need an axe or saw to chop wood", 0
    end

    -- Initialize lumber if not set
    if tile.lumber == nil then
        tile.lumber = ResourceProcessing.FOREST_MAX_LUMBER
    end

    if tile.lumber <= 0 then
        return false, "This forest is depleted", 0
    end

    -- Calculate yield based on tool and party
    local baseYield = math.random(tool.minYield, tool.maxYield)

    -- Party bonus: each party member adds 50% yield
    local partyBonus = 1.0
    if state.player.party then
        partyBonus = partyBonus + (#state.player.party * 0.5)
    end

    local totalYield = math.floor(baseYield * partyBonus)

    -- Can't gather more than available
    totalYield = math.min(totalYield, tile.lumber)

    -- Deduct from tile
    tile.lumber = tile.lumber - totalYield

    -- Add to inventory
    Backpack.addItem("raw_lumber", totalYield)

    -- Check for deforestation
    local deforested = false
    if tile.lumber <= ResourceProcessing.DEFORESTATION_THRESHOLD then
        tile.type = "grass"
        tile.originalType = "forest"
        tile.deforestedDay = state.daysPassed or 0
        deforested = true
    end

    -- Mark tile as modified for save
    tile.modified = true

    local message = "Gathered " .. totalYield .. " lumber"
    if deforested then
        message = message .. " - Forest depleted!"
    elseif tile.lumber < 30 then
        message = message .. " - Trees running low (" .. tile.lumber .. " remaining)"
    end

    return true, message, totalYield, deforested
end

-- Convert raw lumber to wood planks (at a forge or with tools)
function ResourceProcessing.processLumber(amount)
    local rawCount = Backpack.getItemCount("raw_lumber") or 0
    if rawCount < amount then
        return false, "Not enough raw lumber (have " .. rawCount .. ")"
    end

    -- 2 raw lumber = 1 wood plank
    local planksProduced = math.floor(amount / 2)
    if planksProduced < 1 then
        return false, "Need at least 2 raw lumber to make planks"
    end

    local lumberUsed = planksProduced * 2
    Backpack.removeItem("raw_lumber", lumberUsed)
    Backpack.addItem("wood_planks", planksProduced)

    return true, "Processed " .. lumberUsed .. " lumber into " .. planksProduced .. " wood planks"
end

-- Regenerate forest lumber over time (called from onDayAdvance)
function ResourceProcessing.regenerateForests(state, WorldGen)
    -- This would be expensive to check all tiles, so we only regenerate
    -- tiles that are loaded and have been depleted
    local loadedChunks = WorldGen.getLoadedChunks and WorldGen.getLoadedChunks()
    if not loadedChunks then
        return
    end

    for chunkKey, chunk in pairs(loadedChunks) do
        if chunk.tiles then
            for y = 0, 15 do
                for x = 0, 15 do
                    local tile = chunk.tiles[y] and chunk.tiles[y][x]
                    if tile and tile.type == "forest" and tile.lumber and tile.lumber < ResourceProcessing.FOREST_MAX_LUMBER then
                        tile.lumber = math.min(ResourceProcessing.FOREST_MAX_LUMBER, tile.lumber + ResourceProcessing.LUMBER_REGEN_RATE)
                    end
                    -- Reforest deforested tiles very slowly
                    if tile and tile.originalType == "forest" and tile.type == "grass" then
                        local daysSince = (state.daysPassed or 0) - (tile.deforestedDay or 0)
                        if daysSince > 30 then  -- After 30 days, chance to regrow
                            if math.random() < 0.05 then  -- 5% daily chance
                                tile.type = "forest"
                                tile.lumber = 20  -- Starts with low lumber
                                tile.originalType = nil
                                tile.deforestedDay = nil
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Settlement lumber consumption (called from onDayAdvance)
function ResourceProcessing.settlementLumberConsumption(state, WorldGen)
    if not state.player.properties or not state.player.properties.settlements then
        return {}
    end

    local consumptionLog = {}

    for claimKey, settlement in pairs(state.player.properties.settlements) do
        -- Lumber consumption based on settlement level
        local dailyConsumption = settlement.level * 2  -- 2 lumber per level per day

        local claim = state.player.properties.landClaims[claimKey]
        if not claim then goto continue end

        local cx, cy = claim.x, claim.y
        local consumed = 0

        -- Check adjacent tiles for forest
        local adjacentOffsets = {
            {-1, -1}, {0, -1}, {1, -1},
            {-1, 0},          {1, 0},
            {-1, 1},  {0, 1},  {1, 1},
        }

        for _, offset in ipairs(adjacentOffsets) do
            if consumed >= dailyConsumption then break end

            local tx, ty = cx + offset[1], cy + offset[2]
            local tile = WorldGen.getTile(tx, ty)

            if tile and tile.type == "forest" then
                if tile.lumber == nil then
                    tile.lumber = ResourceProcessing.FOREST_MAX_LUMBER
                end

                local toConsume = math.min(dailyConsumption - consumed, tile.lumber)
                tile.lumber = tile.lumber - toConsume
                consumed = consumed + toConsume

                -- Check for deforestation
                if tile.lumber <= ResourceProcessing.DEFORESTATION_THRESHOLD then
                    tile.type = "grass"
                    tile.originalType = "forest"
                    tile.deforestedDay = state.daysPassed or 0

                    table.insert(consumptionLog, {
                        settlement = settlement.name,
                        x = tx, y = ty,
                        deforested = true
                    })
                end
            end
        end

        ::continue::
    end

    return consumptionLog
end

-- ============================================================================
--                      CROP PROCESSING FUNCTIONS
-- ============================================================================

-- Start processing a recipe
function ResourceProcessing.startProcessing(state, claimKey, improvementType, recipeId)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim then
        return false, "No land claim found"
    end

    if not claim.improvements or not claim.improvements[improvementType] then
        return false, "Processing improvement not found"
    end

    -- Get recipe from PROCESSING_RECIPES (in textrpg.lua)
    -- We need to pass the recipe data from textrpg
    -- For now, store processing data in claim
    claim.processing = claim.processing or {}

    -- Check if already processing at this improvement
    if claim.processing[improvementType] then
        return false, "Already processing at this station"
    end

    return true, "Processing started"
end

-- Process a recipe (called from textrpg with full recipe data)
function ResourceProcessing.processRecipe(state, claimKey, improvementType, recipe)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim then
        return false, "No land claim found"
    end

    if not claim.improvements or not claim.improvements[improvementType] then
        return false, "Processing improvement not built"
    end

    -- Check if already processing
    claim.processing = claim.processing or {}
    if claim.processing[improvementType] then
        return false, "Already processing. Wait for current batch to finish."
    end

    -- Validate and check ingredients
    for _, ingredient in ipairs(recipe.input) do
        local itemId = ingredient[1]
        local qty = ingredient[2]

        -- Validate quantity is positive
        if not qty or qty <= 0 then
            return false, "Invalid recipe: ingredient quantity must be positive"
        end

        if not Backpack.hasItem(itemId, qty) then
            local itemDef = Backpack.getItemDef(itemId)
            local itemName = itemDef and itemDef.name or itemId
            return false, "Need " .. qty .. "x " .. itemName
        end
    end

    -- Consume ingredients
    for _, ingredient in ipairs(recipe.input) do
        Backpack.removeItem(ingredient[1], ingredient[2])
    end

    -- Start processing
    claim.processing[improvementType] = {
        recipeId = recipe.id,
        recipeName = recipe.name,
        outputItem = recipe.output,
        outputQty = recipe.outputQty or 1,
        startDay = state.daysPassed or 0,
        startHour = state.timeOfDay or 0,
        hoursRemaining = recipe.time or 24,
    }

    return true, "Started processing " .. recipe.name .. " (" .. recipe.time .. " hours)"
end

-- Collect finished processed goods
function ResourceProcessing.collectProcessed(state, claimKey, improvementType)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim or not claim.processing or not claim.processing[improvementType] then
        return false, "Nothing to collect"
    end

    local process = claim.processing[improvementType]
    if process.hoursRemaining > 0 then
        return false, "Still processing (" .. math.ceil(process.hoursRemaining) .. " hours left)"
    end

    Backpack.addItem(process.outputItem, process.outputQty)

    local itemDef = Backpack.getItemDef(process.outputItem)
    local itemName = itemDef and itemDef.name or process.outputItem

    claim.processing[improvementType] = nil

    return true, "Collected " .. process.outputQty .. "x " .. itemName .. "!"
end

-- Update processing progress (called from onDayAdvance)
function ResourceProcessing.updateProcessing(state, claimKey, hoursElapsed)
    local claim = state.player.properties.landClaims[claimKey]
    if not claim or not claim.processing then return end

    for improvementType, process in pairs(claim.processing) do
        if process.hoursRemaining then
            process.hoursRemaining = process.hoursRemaining - hoursElapsed
            if process.hoursRemaining < 0 then
                process.hoursRemaining = 0
            end
        end
    end
end

return ResourceProcessing
