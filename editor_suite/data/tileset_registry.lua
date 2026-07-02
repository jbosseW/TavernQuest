-- Tileset registry - Atlas definitions matching game's renderer2d ATLAS_CONFIG
-- Populated at runtime by AssetLoader.scanTilesets()
return {
    paths = {},
    atlases = {
        -- Format matches game's tile rendering:
        -- { name = "terrain", path = "game/assets/lpc/...", tileWidth = 32, tileHeight = 32, cols = 16, rows = 16 }
    },
    tileSize = 32,
    count = 0,
}
