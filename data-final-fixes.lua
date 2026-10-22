-- Change the collision box on Vehicle dock (Spider Patrols)
-- Undone in version 1.0.6
--[[
for _, container in pairs(data.raw.container) do
	if string.match(container.name, "sp%-spidertron%-dock") then
		container.collision_box = { { -1.55, -0.65 }, { 1.55, 1.25 } }
	end
end
]]

-- Warden flying item pick-up: reduce light size, intensity
for _, projectile in pairs(data.raw.projectile) do
	if string.match(projectile.name, "%-_%-projectile") then
		projectile.light = nil --{ intensity = 0.2, size = 0.5 }
	end
end

-- What's the purpose of all this collision_mask business?
-- Well, we need vehicles to not collide with the player,
-- but still collide with all the things the player usually collides with.

-- We don't want DMV vehicles to collide with the player,
-- because when you exit a vehicle,
-- there is excessive vehicle bouncing if the player is in the collision box.
-- So, the following fixes that:

local collision_mask_util = require("__core__/lualib/collision-mask-util.lua")

-- DMV Hovercraft layer: needs to exclude player to avoid excessive bouncing when leaving the vehicle.
local hovercraft_layer = collision_mask_util.get_first_unused_layer()
if data.raw["spider-leg"]["acraft-entity-leg"] then
	data.raw["spider-leg"]["hcraft-entity-leg"].collision_mask = { hovercraft_layer }
	data.raw["spider-leg"]["acraft-entity-leg"].collision_mask = { hovercraft_layer }
end

-- DMV Ground-based Vehicles layer
local vehicles_layer = collision_mask_util.get_first_unused_layer()
for _, name in ipairs({
	"car-leg",
	"tank-leg",
	"vehicle-warden-leg",
	"vehicle-flame-tank-leg",
	"vehicle-laser-tank-leg"
}) do
	if data.raw["spider-leg"][name] then
		data.raw["spider-leg"][name].collision_mask = { vehicles_layer, hovercraft_layer }
	end
end

-- get merged set of all prototypes with player-layer OR train-layer
local proto_to_add = {}
local n = 0
for _, proto in pairs(collision_mask_util.collect_prototypes_with_layer("train-layer")) do
	n = n + 1
	proto_to_add[n] = proto
end

for _, proto in pairs(collision_mask_util.collect_prototypes_with_layer("player-layer")) do
	n = n + 1
	proto_to_add[n] = proto
end


local function add_layer_mask_to(proto, layer_mask)
	if proto then -- check to see if exists
		-- set collision_mask incase it hasn't been set yet
		proto.collision_mask = collision_mask_util.get_mask(proto)

		--if not (collision_mask_util.mask_contains_layer(proto.collision_mask, layer_mask)) then -- ensure we aren't creating a duplicate entry

		table.insert(proto.collision_mask, layer_mask)
		--end
	end
end

local function remove_layer_mask_from(proto, layer_mask)
	if proto then -- check to see if the given prototype exists
		-- Now, if the prototype has a collision_mask defined, it may have the mask we want to remove
		if proto.collision_mask then
			for i, proto_mask in ipairs(proto.collision_mask) do
				if proto_mask == layer_mask then
					table.remove(proto.collision_mask, i)
				end
			end
		end
	end
end

-- for each prototype, add vehicles_layer
for i, proto in pairs(proto_to_add) do
	-- Add exceptions here
	if not (proto.type == "character") and
		not (proto.type == "spider-leg") then

		-- So, occasionally we get a proto here with no type or name...
		if proto.name then
			add_layer_mask_to(proto, vehicles_layer)
			add_layer_mask_to(proto, hovercraft_layer)
		else
			log("DMV: Skipping collision mask layer for prototype")

		end
	end
end

-- Add to trees
for _, tree in pairs(data.raw.tree) do
	add_layer_mask_to(tree, vehicles_layer)
	add_layer_mask_to(tree, hovercraft_layer)
end

-- Add waters to the Ground vehicles_layer
for _, tile in pairs(data.raw.tile) do
	if tile.draw_in_water_layer == true then
		log("DMV: about to add layer " .. hovercraft_layer .. " to water tile mask: " .. tile.name)
		remove_layer_mask_from(tile, hovercraft_layer)
		add_layer_mask_to(tile, vehicles_layer)
	end
end
