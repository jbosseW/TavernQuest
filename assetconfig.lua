-- DEPRECATED: Merged into assetpipeline.lua
-- This redirect exists for backward compatibility with any cached require("assetconfig") calls.
-- assetpipeline.lua sets package.loaded["assetconfig"] = AssetPipeline.config on load.
if not package.loaded["assetconfig"] then
    require("assetpipeline")
end
return package.loaded["assetconfig"]
