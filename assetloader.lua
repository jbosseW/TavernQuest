-- DEPRECATED: Merged into assetpipeline.lua
-- This redirect exists for backward compatibility with any cached require("assetloader") calls.
-- assetpipeline.lua sets package.loaded["assetloader"] = AssetPipeline.loader on load.
if not package.loaded["assetloader"] then
    require("assetpipeline")
end
return package.loaded["assetloader"]
