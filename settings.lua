-- How to remove other mod options:
--[[
if data.raw["bool-setting"]["spidertron-enhancements-enable-corpse"] then
	log("DMV: Found Spidertron Enhancements bool setting for corpse.")
	setting = data.raw["bool-setting"]["spidertron-enhancements-enable-corpse"]
	setting.hidden = true
	setting.forced_value = false
end
]]

-- How to create a startup option:
--[[
data:extend({
	{
        type = "bool-setting",
        name = "DMV-enable-corpse",
        setting_type = "startup",
        default_value = true,
        order = "a"
    }
})
]]