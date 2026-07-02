local AssetLoader = {}

---------------------------------------------------------------------------
-- Internal state
---------------------------------------------------------------------------

local imageCache = {}
local placeholderImage = nil
local mounted = false
local MOUNT_POINT = "game"

---------------------------------------------------------------------------
-- Logging
---------------------------------------------------------------------------

local function logWarning(msg)
    print("[AssetLoader WARNING] " .. tostring(msg))
end

local function logInfo(msg)
    print("[AssetLoader] " .. tostring(msg))
end

---------------------------------------------------------------------------
-- Placeholder generation
---------------------------------------------------------------------------

--- Create a small colored rectangle to use when an asset is missing.
-- The placeholder is a 32x32 magenta/black checkerboard so it is clearly
-- visible as a missing-asset indicator.
local function createPlaceholder()
    if placeholderImage then
        return placeholderImage
    end

    local size = 32
    local half = size / 2
    local data = love.image.newImageData(size, size)

    for y = 0, size - 1 do
        for x = 0, size - 1 do
            -- Checkerboard pattern: magenta and dark grey
            local inTopLeft = (x < half and y < half)
            local inBotRight = (x >= half and y >= half)
            if inTopLeft or inBotRight then
                data:setPixel(x, y, 0.9, 0.1, 0.9, 1.0) -- magenta
            else
                data:setPixel(x, y, 0.15, 0.15, 0.15, 1.0) -- dark grey
            end
        end
    end

    placeholderImage = love.graphics.newImage(data)
    placeholderImage:setFilter("nearest", "nearest")
    return placeholderImage
end

---------------------------------------------------------------------------
-- Recursive directory scanning
---------------------------------------------------------------------------

--- Recursively collect all files under a directory that match an extension.
-- @param dir        The directory path inside the LOVE virtual filesystem
-- @param extension  File extension to match (e.g. ".png"), case-insensitive
-- @param results    Accumulator table (internal)
-- @return table     Array of file paths relative to the virtual filesystem root
local function scanDirectory(dir, extension, results)
    results = results or {}

    local items = love.filesystem.getDirectoryItems(dir)
    if not items then
        return results
    end

    for _, item in ipairs(items) do
        local path = dir .. "/" .. item
        local info = love.filesystem.getInfo(path)

        if info then
            if info.type == "directory" then
                scanDirectory(path, extension, results)
            elseif info.type == "file" then
                -- Case-insensitive extension check
                local lowerItem = string.lower(item)
                local lowerExt = string.lower(extension)
                if string.sub(lowerItem, -#lowerExt) == lowerExt then
                    results[#results + 1] = path
                end
            end
        end
    end

    return results
end

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------

--- Mount the parent game directory so its assets are accessible.
-- Uses love.filesystem.getSource() to find the editor's directory, then
-- navigates one level up to reach the main game directory.
-- After mounting, assets are available at "game/assets/...".
-- @return boolean  true if mount succeeded, false otherwise
function AssetLoader.init()
    if mounted then
        return true
    end

    local source = love.filesystem.getSource()
    if not source or source == "" then
        logWarning("Could not determine source directory")
        return false
    end

    -- Go up one directory level from the editor_suite folder.
    -- love.filesystem.getSource() returns the path to the running project
    -- (e.g. "F:/LOVE/LOVEGAME_work/editor_suite").
    -- We need the parent: "F:/LOVE/LOVEGAME_work".
    -- Handle both forward and backslash separators.
    local parentDir = string.match(source, "^(.+)[/\\][^/\\]+$")
    if not parentDir then
        logWarning("Could not resolve parent directory from source: " .. source)
        return false
    end

    logInfo("Source directory: " .. source)
    logInfo("Mounting parent directory: " .. parentDir .. " as '" .. MOUNT_POINT .. "'")

    local ok = love.filesystem.mount(parentDir, MOUNT_POINT)
    if not ok then
        logWarning("Failed to mount " .. parentDir .. " as '" .. MOUNT_POINT .. "'")
        return false
    end

    -- Verify the mount worked by checking for the assets directory
    local assetsInfo = love.filesystem.getInfo(MOUNT_POINT .. "/assets")
    if assetsInfo then
        logInfo("Mount verified: " .. MOUNT_POINT .. "/assets exists (" .. assetsInfo.type .. ")")
    else
        logWarning("Mount succeeded but " .. MOUNT_POINT .. "/assets not found")
    end

    mounted = true
    return true
end

--- Check whether the parent directory has been mounted.
-- @return boolean
function AssetLoader.isMounted()
    return mounted
end

---------------------------------------------------------------------------
-- Image loading
---------------------------------------------------------------------------

--- Load an image from the virtual filesystem with caching.
-- @param path  Path relative to the virtual filesystem root (e.g. "game/assets/icons/armor/BasicHelm.PNG")
-- @return Image|nil  LOVE2D Image object, or nil on failure
function AssetLoader.loadImage(path)
    if type(path) ~= "string" or path == "" then
        logWarning("loadImage called with invalid path")
        return nil
    end

    -- Return cached version if available
    if imageCache[path] then
        return imageCache[path]
    end

    -- Check that the file exists before attempting to load
    local info = love.filesystem.getInfo(path)
    if not info then
        logWarning("File not found: " .. path)
        return nil
    end

    local ok, img = pcall(love.graphics.newImage, path)
    if not ok or not img then
        logWarning("Failed to load image: " .. path .. " (" .. tostring(img) .. ")")
        return nil
    end

    img:setFilter("nearest", "nearest")
    imageCache[path] = img
    return img
end

--- Load an icon image from the game assets.
-- Icons live under game/assets/icons/.
-- @param iconPath  Path relative to the icons directory (e.g. "armor/BasicHelm.PNG")
-- @return Image|nil
function AssetLoader.loadIcon(iconPath)
    if type(iconPath) ~= "string" or iconPath == "" then
        logWarning("loadIcon called with invalid path")
        return nil
    end

    local fullPath = MOUNT_POINT .. "/assets/icons/" .. iconPath
    return AssetLoader.loadImage(fullPath)
end

--- Load a character portrait from the game assets.
-- Portraits live under game/assets/characters/.
-- Automatically appends ".PNG" if the path does not already end with an extension.
-- @param portraitPath  Path relative to the characters directory
--                      (e.g. "Human/Men_Human/BoldWarrior" or "Animals/Bear_animal")
-- @return Image|nil
function AssetLoader.loadPortrait(portraitPath)
    if type(portraitPath) ~= "string" or portraitPath == "" then
        logWarning("loadPortrait called with invalid path")
        return nil
    end

    -- Append .PNG if no extension is present
    local lower = string.lower(portraitPath)
    if not string.find(lower, "%.png$") and not string.find(lower, "%.jpg$") and not string.find(lower, "%.jpeg$") then
        portraitPath = portraitPath .. ".PNG"
    end

    local fullPath = MOUNT_POINT .. "/assets/characters/" .. portraitPath
    return AssetLoader.loadImage(fullPath)
end

---------------------------------------------------------------------------
-- Scanning
---------------------------------------------------------------------------

--- Recursively scan the icons directory and return all .PNG file paths.
-- Paths are returned relative to the virtual filesystem root
-- (e.g. "game/assets/icons/armor/BasicHelm.PNG").
-- @return table  Array of path strings
function AssetLoader.scanIcons()
    local dir = MOUNT_POINT .. "/assets/icons"
    local info = love.filesystem.getInfo(dir)
    if not info then
        logWarning("Icons directory not found: " .. dir)
        return {}
    end
    return scanDirectory(dir, ".png", {})
end

--- Recursively scan the characters directory and return all .PNG file paths.
-- @return table  Array of path strings
function AssetLoader.scanPortraits()
    local dir = MOUNT_POINT .. "/assets/characters"
    local info = love.filesystem.getInfo(dir)
    if not info then
        logWarning("Characters directory not found: " .. dir)
        return {}
    end
    return scanDirectory(dir, ".png", {})
end

--- Scan the LPC assets directory for tileset images (.png files).
-- @return table  Array of path strings
function AssetLoader.scanTilesets()
    local dir = MOUNT_POINT .. "/assets/lpc"
    local info = love.filesystem.getInfo(dir)
    if not info then
        logWarning("LPC directory not found: " .. dir)
        return {}
    end
    return scanDirectory(dir, ".png", {})
end

---------------------------------------------------------------------------
-- Safe access
---------------------------------------------------------------------------

--- Get a cached image, or return a placeholder if not loaded.
-- This never returns nil -- it always provides something drawable.
-- @param path  Path relative to the virtual filesystem root
-- @return Image  Cached image or a magenta checkerboard placeholder
function AssetLoader.getImageSafe(path)
    if type(path) == "string" and path ~= "" and imageCache[path] then
        return imageCache[path]
    end

    -- Try to load it on demand
    if type(path) == "string" and path ~= "" then
        local img = AssetLoader.loadImage(path)
        if img then
            return img
        end
    end

    return createPlaceholder()
end

---------------------------------------------------------------------------
-- Cache management
---------------------------------------------------------------------------

--- Free all cached images and release their GPU memory.
-- Call this when switching contexts or when memory is tight.
function AssetLoader.clearCache()
    local count = 0
    for path, img in pairs(imageCache) do
        -- Releasing references; LOVE2D will garbage-collect the Image objects
        count = count + 1
    end
    imageCache = {}

    -- Also clear the placeholder so it gets regenerated if needed
    placeholderImage = nil

    logInfo("Cache cleared (" .. count .. " images released)")
end

--- Return the number of currently cached images.
-- @return number
function AssetLoader.getCacheSize()
    local count = 0
    for _ in pairs(imageCache) do
        count = count + 1
    end
    return count
end

--- Return the mount point string used to access game files.
-- @return string  e.g. "game"
function AssetLoader.getMountPoint()
    return MOUNT_POINT
end

return AssetLoader
