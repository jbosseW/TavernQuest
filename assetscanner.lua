-- DEPRECATED: Merged into assetpipeline.lua
-- This redirect exists for backward compatibility with any cached require("assetscanner") calls.
-- assetpipeline.lua sets package.loaded["assetscanner"] = AssetPipeline.scanner on load.
if not package.loaded["assetscanner"] then
    require("assetpipeline")
end
return package.loaded["assetscanner"]
