-- DEPRECATED: Merged into textrpg.lua
-- This redirect exists for backward compatibility with any cached require("vampireinfiltration") calls
-- textrpg.lua sets package.loaded["vampireinfiltration"] = VampireInfiltration on load
-- If textrpg has already been loaded, package.loaded will return the correct table.
-- If not, load textrpg first to ensure VampireInfiltration is available.
if not package.loaded["vampireinfiltration"] then
    require("textrpg")
end
return package.loaded["vampireinfiltration"]
