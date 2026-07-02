-- DEPRECATED: Merged into progression.lua
-- This redirect exists for backward compatibility with any cached require("gamemodes") calls
-- progression.lua sets package.loaded["gamemodes"] = GameModes on load
-- If progression has already been loaded, package.loaded will return the correct table.
-- If not, load progression first to ensure GameModes is available.
if not package.loaded["gamemodes"] then
    require("progression")
end
return package.loaded["gamemodes"]
