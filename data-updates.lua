--=========================
--          PATH
--=========================
local modpath     = "__DMV_Directional_Movement_Vehicles__/"
local icons_path  = modpath .. "graphics/icons/"
local entity_path = modpath .. "graphics/entity/"
local sounds_path = modpath .. "sound/"


--=========================
--        VARIABLES
--=========================
local spidertron = data.raw["spider-vehicle"].spidertron

local function create_leg_collision(vehicle, leg)
	-- This is the way to get collision. It makes the vehicle bounce off everything
	-- collision size is based on torso (vehicle), but slightly smaller
	leg.collision_box = table.deepcopy(vehicle.collision_box)
	leg.collision_box[1][1] = leg.collision_box[1][1] - 0.2
	leg.collision_box[1][2] = leg.collision_box[1][2] - 0.2
	leg.collision_box[2][1] = leg.collision_box[2][1] - 0.2
	leg.collision_box[2][2] = leg.collision_box[2][2] - 0.2
end

--=========================
--          VFX
--=========================

-- Sand dust is below ground vehicles
data.raw["optimized-particle"]["sand-1-dust-vehicle-particle"].render_layer = "lower-object"

-- Sand dust lasts a little longer
data.raw["optimized-particle"]["sand-1-dust-vehicle-particle"].life_time = 40 --2x

-- New tire dust
local dust = table.deepcopy(data.raw["trivial-smoke"]["smoke-building"])
dust.name = "tire-dust"
dust.affected_by_wind = true
dust.duration = 120
dust.fade_away_duration = 100
dust.render_layer = "lower-object"
dust.color = { a = 0.30, b = 0.00, g = 0.05, r = 0.06 }
data:extend { dust }

-- Dust particle trails
local track_particles = table.deepcopy(data.raw.car.car.track_particle_triggers[3].actions) -- sand dust
local tire_dust = table.deepcopy(spidertron.spider_engine.legs[1].leg_hit_the_ground_trigger[1])

tire_dust.smoke_name = "tire-dust"
table.insert(track_particles, tire_dust)

-- Fix alien biomes rocks not having any dying explosion like vanilla ones
for _, simple_entity in pairs(data.raw["simple-entity"]) do
	if string.match(simple_entity.name, "rock%-big%-") then
		simple_entity.dying_trigger_effect = data.raw["simple-entity"]["rock-big"].dying_trigger_effect
	elseif string.match(simple_entity.name, "rock%-huge%-") then
		simple_entity.dying_trigger_effect = data.raw["simple-entity"]["rock-huge"].dying_trigger_effect
	elseif string.match(simple_entity.name, "sand%-rock%-big%-") then
		simple_entity.dying_trigger_effect = data.raw["simple-entity"]["sand-rock-big"].dying_trigger_effect
	end
end

--=========================
--          SFX
--=========================
-- Sound effects imported from Boombastique Immersive Sound Pack by Fooltaurus
-- To support alien biomes tree and rock vehicle collision sounds
-- DMV is compatible with and recommends Boombastique Immersive Sound Pack
local car_impact_stone_sound =
{
	{
		filename = sounds_path .. "impact/car-stone-impact.ogg",
		volume = 0.65
	},
	{
		filename = sounds_path .. "impact/car-stone-impact-2.ogg",
		volume = 0.65
	},
	{
		filename = sounds_path .. "impact/car-stone-impact-3.ogg",
		volume = 0.65
	},
	{
		filename = sounds_path .. "impact/car-stone-impact-4.ogg",
		volume = 0.65
	},
	{
		filename = sounds_path .. "impact/car-stone-impact-5.ogg",
		volume = 0.65
	},
	{
		filename = sounds_path .. "impact/car-stone-impact-6.ogg",
		volume   = 0.65
	}
}
for _, simple_entity in pairs(data.raw["simple-entity"]) do
	if string.match(simple_entity.name, "rock%-") then
		simple_entity.vehicle_impact_sound = car_impact_stone_sound
	end
end
local car_impact_wood_sound =
{
	{
		filename = sounds_path .. "impact/car-tree-wood-impact-01.ogg",
		volume = 0.6
	},
	{
		filename = sounds_path .. "impact/car-tree-wood-impact-02.ogg",
		volume = 0.6
	},
	{
		filename = sounds_path .. "impact/car-tree-wood-impact-03.ogg",
		volume = 0.6
	},
	{
		filename = sounds_path .. "impact/car-tree-wood-impact-04.ogg",
		volume = 0.6
	},
	{
		filename = sounds_path .. "impact/car-wood-impact-04.ogg",
		volume = 0.8
	},
	{
		filename = sounds_path .. "impact/car-wood-impact-05.ogg",
		volume = 0.8
	}
}
for _, tree in pairs(data.raw.tree) do
	tree.vehicle_impact_sound = car_impact_wood_sound
end

--=========================
--      BEFORE-FIXES
--=========================
-- Assault Hovercraft needs to copy its burner from the car
if data.raw.car["acraft-entity"] then
	data.raw.car["acraft-entity"].burner = table.deepcopy(data.raw.car.car.burner)
end

-- Update spidertron's minimap icon to fit with land and sea vehicles.
spidertron.minimap_representation.filename = icons_path .. "minimap/spidertron.png"
-- All minimap icons will copy this scale:
spidertron.minimap_representation.scale = 0.3

-- Update Spider Patrols Spiderling minimap icon to fit with this mod:
if data.raw["spider-vehicle"]["sp-spiderling"] then
	data.raw["spider-vehicle"]["sp-spiderling"].minimap_representation = table.deepcopy(spidertron.minimap_representation)
	data.raw["spider-vehicle"]["sp-spiderling"].minimap_representation.scale = 0.2
end

-- Improve spidertron enhancements remnant inventory
if data.raw["character-corpse"]["spidertron-enhancements-corpse"] then
	local c = data.raw["character-corpse"]["spidertron-enhancements-corpse"]
	c.selection_box = { { -1.8, -1.8 }, { 1.8, 1.8 } }
	c.open_sound = table.deepcopy(data.raw.car.tank.open_sound)
	c.close_sound = table.deepcopy(data.raw.car.tank.close_sound)
	c.picture = table.deepcopy(data.raw.corpse["iron-chest-remnants"].animation)
	c.render_layer = "ground-patch-higher2" -- just below remnants
	c.drawing_box = { { -0.5, -0.5 }, { 0.5, 0.5 } }
	c.time_to_live = 60 * 60 * 15 -- 15 minutes, matches corpses
end


--=========================
--       ENTITY BASE
--=========================
for _, name in ipairs({
	"car",
	"hcraft-entity",
	"acraft-entity",
	"ironclad",
	"vehicle-warden",
	"tank",
	"vehicle-flame-tank",
	"vehicle-laser-tank"
}) do if data.raw["car"][name] then

		-- This mod works by creating a copy of a car...
		local vehicle = table.deepcopy(data.raw["car"][name])
		-- And turning it into a spider-vehicle! (does whatever a spider-vehicle does!)
		vehicle.type = "spider-vehicle"
		vehicle.name = "DMV-" .. name -- with a unique name
		vehicle.localised_name = { "entity-name." .. name } -- copy localisation
		vehicle.localised_description = { "entity-description." .. name }
		vehicle.minable.mining_time = 2 --seconds. reduced by mining-speed upgrades
		vehicle.minimap_representation = table.deepcopy(spidertron.minimap_representation)
		vehicle.minimap_representation.filename = icons_path .. "minimap/" .. name .. ".png"

		-- spider-vehicle properties
		vehicle.automatic_weapon_cycling = true
		vehicle.energy_source = nil
		vehicle.burner.fuel_inventory_size = 0 -- vehicles take fuel from trunk
		vehicle.burner.effectivity = vehicle.effectivity -- car -> spider-vehicle
		vehicle.burner.smoke[1].position = { 0, -1.3 } -- above vehicle
		vehicle.chain_shooting_cooldown_modifier = 1 -- 0 means no cooldown
		vehicle.chunk_exploration_radius = 2 -- spidertron is 3
		vehicle.height = 0 -- ground level, does not affect draw order with particles
		vehicle.movement_energy_consumption = vehicle.consumption -- vehicle is "150kW"
		vehicle.torso_rotation_speed = 0.011 -- carefully chosen
		vehicle.torso_bob_speed = 0 -- makes car not bob.

		-- sticker box is for spitter spit attached to vehicles
		-- this code begins with the collision box and cuts it into a square
		local square_begin = math.min(vehicle.collision_box[1][1], vehicle.collision_box[1][2])
		local square_end = math.min(vehicle.collision_box[2][1], vehicle.collision_box[2][2])
		square_begin = square_begin - 0.1
		square_end = square_end - 0.1
		vehicle.sticker_box = {{square_begin, square_begin}, {square_end, square_end}}

		-- graphics_set
		vehicle.graphics_set = table.deepcopy(spidertron.graphics_set) -- autopilot
		vehicle.graphics_set.base_animation = nil
		vehicle.graphics_set.shadow_base_animation = nil
		vehicle.graphics_set.eye_light = nil
		vehicle.graphics_set.light = vehicle.light
		vehicle.graphics_set.render_layer = "object"

		-- merge additional layers into vehicle.animations

		local function match_anim_frames_and_insert(target_layers, layer_to_insert)
			local max_advance = target_layers[1].max_advance
			local anim_frame_count = target_layers[1].frame_count or 1
			-- fix the frame_count:
			-- Vehicle's base animation frame_count is numerator
			-- turret animation frame_count is denominator
			-- quotient is how many times we must repeat turret animation
			local new_repeat_count = anim_frame_count / (layer_to_insert.frame_count or 1)
			layer_to_insert.repeat_count = new_repeat_count

			-- fix max_advance
			layer_to_insert.max_advance = max_advance

			-- and do it for the hr version if it exists
			if layer_to_insert.hr_version then
				layer_to_insert.hr_version.repeat_count = new_repeat_count
				layer_to_insert.hr_version.max_advance = max_advance
			end

			-- add the layer to vehicle's animations
			table.insert(target_layers, layer_to_insert)
		end

		-- Vehicle shadow, move from animation into shadow_animation
		vehicle.graphics_set.shadow_animation = {
			layers = {
				table.deepcopy(vehicle.animation.layers[#vehicle.animation.layers]) -- Last layer is always shadow
			}
		}
		table.remove(vehicle.animation.layers, #vehicle.animation.layers)

		-- Turret shadow , move from animation into shadow_animation
		if vehicle.turret_animation then
			if vehicle.turret_animation.layers[#vehicle.turret_animation.layers] then
				local turret_shadow = table.deepcopy(vehicle.turret_animation.layers[#vehicle.turret_animation.layers])
				match_anim_frames_and_insert(vehicle.graphics_set.shadow_animation.layers, turret_shadow) -- turret shadow
				table.remove(vehicle.turret_animation.layers, #vehicle.turret_animation.layers)
			end
		end

		-- headlights and hood-mounted turret, match animation frames
		for _, anim_type in ipairs({ "light_animation", "turret_animation" }) do
			if vehicle[anim_type] then -- If light_animation or turret_animation exists
				if vehicle[anim_type].layers then -- and the animation has layers
					for _, layer in pairs(vehicle[anim_type].layers) do
						match_anim_frames_and_insert(vehicle.animation.layers, layer)
					end
				else -- If the animation doesn't have layers
					match_anim_frames_and_insert(vehicle.animation.layers, vehicle[anim_type])
				end
			end
		end

		-- Apply merged vehicle animations to spider-vehicle graphics_set
		vehicle.graphics_set.animation = table.deepcopy(vehicle.animation)

		-- leg
		local vehicle_leg = table.deepcopy(data.raw["spider-leg"]["spidertron-leg-1"])
		vehicle_leg.name = name .. "-leg"
		vehicle_leg.graphics_set = {} -- invisible leg
		vehicle_leg.icon = vehicle.icon -- only shown in creative mode
		vehicle_leg.target_position_randomisation_distance = 0 -- not necessary

		-- exit vehicle plays door shutting sound
		vehicle.working_sound.deactivate_sound = table.deepcopy(vehicle.close_sound)
		--vehicle.working_sound.deactivate_sound.volume = 0.8 -- loud door

		-- leg sound
		vehicle_leg.walking_sound_volume_modifier = 0 -- this is a footstep sound
		vehicle_leg.working_sound = {
			fade_in_ticks = 48,
			fade_out_ticks = 120,
			sound = table.deepcopy(vehicle.working_sound.sound)
		}
		vehicle.working_sound.sound.volume = 0.35 -- idle while occupied
		vehicle_leg.working_sound.sound.volume = 0.52 -- moving, both occupied and un.

		-- leg speed
		vehicle_leg.minimal_step_size = 0.4 -- was 1, seems good to keep it low
		vehicle_leg.part_length = 0.3 -- higher and it'll be able to go thru objects
		vehicle_leg.movement_based_position_selection_distance = 0.7 -- speed
		vehicle_leg.initial_movement_speed = 0.01
		vehicle_leg.movement_acceleration = 0.25

		data:extend { vehicle_leg }

		-- engine
		vehicle.spider_engine = {
			military_target = "yes",
			legs = {}
		}

		for i = 1, 1, 1 do -- 1 leg
			table.insert(vehicle.spider_engine.legs, {
				leg = name .. "-leg",
				mount_position = { 0, 0 }, -- center
				ground_position = { 0, 0 }, -- center
				blocking_legs = {}
			})
		end


		data:extend { vehicle }

		-- Inventory item
		local item = data.raw["item-with-entity-data"][name]
		item.icon = icons_path .. name .. ".png" -- before placing, default color
		item.mipmaps = 0
		item.icon_tintable = icons_path .. name .. "-tintable.png" -- unpainted metal base
		item.icon_tintable_mask = icons_path .. name .. "-tintable-mask.png"
		item.place_result = "DMV-" .. name
	end
end


--=========================
--      CAR SPECIFICS
--=========================
local car = data.raw["spider-vehicle"]["DMV-car"]
local car_leg = data.raw["spider-leg"]["car-leg"]
car.inventory_size = 70 -- down from 80, gets rid of scrollbar
car.selection_box = { { -1.4, -1.4 }, { 1.4, 1.4 } } -- square highlight box
car.collision_box = { { -1.5, -1.5 }, { 1.5, 1.5 } } -- biters can attack
car.drawing_box = { { -1.7, -0.5 }, { 1.7, 0.5 } } -- zoomed preview models
create_leg_collision(car, car_leg)

-- Trying to make car faster for 1.05 as requested in discussion threads
car_leg.movement_based_position_selection_distance = 1.5 -- speed, up from 0.7
car_leg.initial_movement_speed = 0.04 -- up from 0.01, unsure what this does
car_leg.movement_acceleration = 0.55 -- up from 0.25, just to make it accelerate faster

-- Gun nerf: vanilla car is 4, sub-machine is 6, pistol is 15
data.raw.gun[car.guns[1]].attack_parameters.cooldown = 12

-- New Car engine sounds
car.working_sound.sound.volume = 0.65 -- idle while occupied
car.working_sound.activate_sound.filename = modpath .. "sound/car-engine-start.ogg"
car.working_sound.activate_sound.volume = 1 -- was 0.67
car.working_sound.sound.filename = modpath .. "sound/car-engine.ogg" -- idle w ocupnt
car_leg.working_sound.sound.filename = modpath .. "sound/car-engine.ogg"
car_leg.working_sound.sound.volume = 0.6
car_leg.working_sound.sound.speed = 1.8
car_leg.working_sound.fade_in_ticks = 50
car_leg.working_sound.fade_out_ticks = 50

-- Car track particles
for _, leg in pairs(car.spider_engine.legs) do
	leg.leg_hit_the_ground_trigger = track_particles
end


if data.raw["spider-vehicle"]["DMV-hcraft-entity"] then
	--=========================
	--   HOVERCRAFT SPECIFICS
	--=========================
	local hcraft = data.raw["spider-vehicle"]["DMV-hcraft-entity"]
	local hcraft_leg = data.raw["spider-leg"]["hcraft-entity-leg"]
	hcraft.torso_rotation_speed = 0.007 -- car is 0.011
	hcraft.inventory_size = car.inventory_size
	hcraft.selection_box = car.selection_box
	hcraft.collision_box = car.collision_box
	hcraft.drawing_box = car.drawing_box
	create_leg_collision(hcraft, hcraft_leg)

	-- New engine sounds
	hcraft.working_sound = car.working_sound
	hcraft_leg.working_sound = car_leg.working_sound

	-- Trailing particles
	for _, leg in pairs(hcraft.spider_engine.legs) do
		leg.leg_hit_the_ground_trigger = track_particles
	end

	-- Like the car, making hovercraft faster for 1.06
	hcraft_leg.movement_based_position_selection_distance = 1.2 -- speed, up from 0.7
	hcraft_leg.initial_movement_speed = 0.03 -- up from 0.01, unsure what this does
	hcraft_leg.movement_acceleration = 0.35 -- up from 0.25, just to make it accelerate faster
end

if data.raw["spider-vehicle"]["DMV-acraft-entity"] then
	--=================================
	--   ASSAULT HOVERCRAFT SPECIFICS
	--=================================
	local acraft = data.raw["spider-vehicle"]["DMV-acraft-entity"]
	local acraft_leg = data.raw["spider-leg"]["acraft-entity-leg"]
	acraft.torso_rotation_speed = 0.007 -- car is 0.011
	acraft.inventory_size = car.inventory_size
	acraft.selection_box = car.selection_box
	acraft.collision_box = car.collision_box
	acraft.drawing_box = car.drawing_box
	create_leg_collision(acraft, acraft_leg)

	-- New engine sounds
	acraft.working_sound = car.working_sound
	acraft_leg.working_sound = car_leg.working_sound

	-- Trailing particles
	for _, leg in pairs(acraft.spider_engine.legs) do
		leg.leg_hit_the_ground_trigger = track_particles
	end
	
	-- Like the car, making hovercraft faster for 1.06
	acraft_leg.movement_based_position_selection_distance = 1.2 -- speed, up from 0.7
	acraft_leg.initial_movement_speed = 0.03 -- up from 0.01, unsure what this does
	acraft_leg.movement_acceleration = 0.35 -- up from 0.25, just to make it accelerate faster

	-- Fix technology icon
	data.raw.technology["acraft-tech"].icon = modpath .. "graphics/acraft_tech.png"
end

if data.raw["spider-vehicle"]["DMV-ironclad"] then
	--=========================
	--    IRONCLAD SPECIFICS
	--=========================
	local ironclad = data.raw["spider-vehicle"]["DMV-ironclad"]
	local ironclad_leg = data.raw["spider-leg"]["ironclad-leg"]
	ironclad.minable.mining_time = 3 --seconds. reduced by mining-speed upgrades
	ironclad.selection_box = { { -2.6, -2.6 }, { 2.6, 2.6 } } -- square highlight box
	ironclad.collision_box = { { -2.4, -2.4 }, { 2.4, 2.4 } } -- biters can attack
	ironclad.drawing_box = { { -2.7, -2.5 }, { 2.7, 2.5 } } -- zoomed preview models
	ironclad.torso_bob_speed = 0.4
	ironclad_leg.collision_mask = { "ground-tile" }
	-- TODO: decide if ironclad should be deep only or shallow too
	create_leg_collision(ironclad, ironclad_leg)
	ironclad_leg.working_sound.sound.volume = 0.5

	-- Ironclad new remnant, already saturated in Oil-based Paint mod
	ironclad.corpse = { "flamethrower-turret-remnants", "locomotive-remnants" }

	ironclad.burner.effectivity = 0.99 -- was 1, car is 0.6, but this vehicle is guzzler
	ironclad.torso_rotation_speed = 0.005 -- DMV car is 0.011

	-- Ironclad speed
	ironclad_leg.minimal_step_size = 0.1
	ironclad_leg.part_length = 0.2
	ironclad_leg.movement_based_position_selection_distance = 0.2
end

if data.raw["spider-vehicle"]["DMV-vehicle-warden"] then
	--=========================
	--     WARDEN SPECIFICS
	--=========================
	local warden = data.raw["spider-vehicle"]["DMV-vehicle-warden"]
	local warden_leg = data.raw["spider-leg"]["vehicle-warden-leg"]

	warden.minable.mining_time = 3 --seconds. reduced by mining-speed upgrades
	warden.selection_box = { { -2.4, -2.4 }, { 2.4, 2.4 } } -- square highlight box
	warden.collision_box = { { -2.1, -2.1 }, { 2.1, 2.1 } } -- biters can attack
	warden.drawing_box = { { -2.1, -2.4 }, { 2.1, 2.4 } } -- zoomed preview models
	create_leg_collision(warden, warden_leg)

	-- Warden remnant, composite of locomotive and car
	warden.corpse = { "locomotive-remnants", "car-remnants" }

	-- burner effectivity
	warden.burner.effectivity = 0.99 -- was 2, car is 0.6, should be below 1
	warden.burner.smoke[1].position = { 0, -1.7 } -- car is -1.3
	warden.chunk_exploration_radius = 3 -- spidertron is 3, car is 2
	warden.movement_energy_consumption = "300kW" -- was too low, car is 150
	warden.torso_rotation_speed = 0.009 -- car is 0.011

	-- Warden engine switch to tank sounds
	local tank_working = data.raw.car.tank.working_sound -- tank
	warden.working_sound = table.deepcopy(tank_working) -- idle sound when occupied
	warden.working_sound.deactivate_sound = table.deepcopy(warden.close_sound)
	warden_leg.working_sound.sound.filename = tank_working.sound.filename
	warden_leg.working_sound.sound.volume = 0.3
	warden_leg.working_sound.sound.speed = 1.5

	-- Warden speed
	warden_leg.minimal_step_size = 0.1
	warden_leg.movement_based_position_selection_distance = 0.3

	-- Warden particle trails same as car
	for _, leg in pairs(warden.spider_engine.legs) do
		leg.leg_hit_the_ground_trigger = table.deepcopy(car.spider_engine.legs[1].leg_hit_the_ground_trigger)
	end
end


--=========================
--     TANK SPECIFICS
--=========================
local tank = data.raw["spider-vehicle"]["DMV-tank"]
local tank_leg = data.raw["spider-leg"]["tank-leg"]

-- Tank, remove flamethrower and machine-gun, because the way targetting works, it gets stuck if it has 2 weapons.
-- Still completely overpowered
tank.guns = {
	"tank-cannon"
}

tank.minable.mining_time = 3 --seconds. reduced by mining-speed upgrades
tank.inventory_size = 70 -- down from 80, gets rid of scrollbar
tank.selection_box = { { -1.4, -1.4 }, { 1.4, 1.4 } } -- square highlight box
tank.collision_box = { { -1.5, -1.5 }, { 1.5, 1.5 } } -- biters can attack
tank.drawing_box = { { -1.7, -0.5 }, { 1.7, 0.5 } } -- zoomed preview models
create_leg_collision(tank, tank_leg)

-- burner effectivity
tank.burner.smoke[1].position = { 0, -1.5 } -- car is -1.3
tank.torso_rotation_speed = 0.005 -- car is 0.011

-- New tank sounds
tank.working_sound.deactivate_sound = table.deepcopy(tank.close_sound)
tank_leg.working_sound.sound.filename = tank.working_sound.sound.filename
tank_leg.working_sound.sound.volume = 0.3
tank_leg.working_sound.sound.speed = 1.5

-- Tank is like Warden speed
tank_leg.minimal_step_size = 0.1
tank_leg.movement_based_position_selection_distance = 0.3

-- Tank particle trails same as car
for _, leg in pairs(tank.spider_engine.legs) do
	leg.leg_hit_the_ground_trigger = table.deepcopy(car.spider_engine.legs[1].leg_hit_the_ground_trigger)
end


if data.raw["spider-vehicle"]["DMV-vehicle-flame-tank"] then
	--=========================
	--   FLAME TANK SPECIFICS
	--=========================
	local flame_tank = data.raw["spider-vehicle"]["DMV-vehicle-flame-tank"]
	local flame_tank_leg = data.raw["spider-leg"]["vehicle-flame-tank-leg"]

	flame_tank.minable.mining_time = 3 --seconds. reduced by mining-speed upgrades
	--flame_tank.inventory_size = 30 -- was 30
	flame_tank.selection_box = { { -1.4, -1.4 }, { 1.4, 1.4 } } -- square highlight box
	flame_tank.collision_box = { { -1.5, -1.5 }, { 1.5, 1.5 } } -- biters can attack
	flame_tank.drawing_box = { { -1.7, -0.5 }, { 1.7, 0.5 } } -- zoomed preview models
	create_leg_collision(flame_tank, flame_tank_leg)

	-- burner effectivity
	flame_tank.burner.smoke[1].position = { 0, -1.5 } -- car is -1.3
	flame_tank.torso_rotation_speed = 0.005 -- car is 0.011

	-- New tank sounds
	flame_tank.working_sound.deactivate_sound = table.deepcopy(tank.close_sound)
	flame_tank_leg.working_sound.sound.filename = tank.working_sound.sound.filename
	flame_tank_leg.working_sound.sound.volume = 0.3
	flame_tank_leg.working_sound.sound.speed = 1.5

	-- Tank is like Warden speed
	flame_tank_leg.minimal_step_size = 0.1
	flame_tank_leg.movement_based_position_selection_distance = 0.3

	-- Tank particle trails same as car
	for _, leg in pairs(flame_tank.spider_engine.legs) do
		leg.leg_hit_the_ground_trigger = table.deepcopy(car.spider_engine.legs[1].leg_hit_the_ground_trigger)
	end
end

if data.raw["spider-vehicle"]["DMV-vehicle-laser-tank"] then
	--=========================
	--   LASER TANK SPECIFICS
	--=========================
	local laser_tank = data.raw["spider-vehicle"]["DMV-vehicle-laser-tank"]
	local laser_tank_leg = data.raw["spider-leg"]["vehicle-laser-tank-leg"]

	laser_tank.minable.mining_time = 3 --seconds. reduced by mining-speed upgrades
	--laser_tank.inventory_size = 40 -- was 40
	laser_tank.selection_box = { { -1.6, -1.6 }, { 1.6, 1.6 } } -- square highlight box
	laser_tank.collision_box = { { -1.6, -1.6 }, { 1.6, 1.6 } } -- biters can attack
	laser_tank.drawing_box = { { -1.7, -0.5 }, { 1.7, 0.5 } } -- zoomed preview models
	create_leg_collision(laser_tank, laser_tank_leg)

	-- burner effectivity
	laser_tank.burner.smoke[1].position = { 0, -1.6 } -- car is -1.3
	laser_tank.torso_rotation_speed = 0.005 -- car is 0.011

	-- New tank sounds
	laser_tank.working_sound.deactivate_sound = table.deepcopy(tank.close_sound)
	laser_tank_leg.working_sound.sound.filename = tank.working_sound.sound.filename
	laser_tank_leg.working_sound.sound.volume = 0.3
	laser_tank_leg.working_sound.sound.speed = 1.5

	-- lower gun volume, include variations
	data.raw.gun["laser-tank-cannon"].attack_parameters.sound = table.deepcopy(data.raw.gun["tank-cannon"].attack_parameters
		.sound)

	-- Tank is like Warden speed
	laser_tank_leg.minimal_step_size = 0.1
	laser_tank_leg.movement_based_position_selection_distance = 0.3

	-- Tank particle trails same as car
	for _, leg in pairs(laser_tank.spider_engine.legs) do
		leg.leg_hit_the_ground_trigger = table.deepcopy(car.spider_engine.legs[1].leg_hit_the_ground_trigger)
	end
end


--=========================
--          ITEM
--=========================
-- Retexture Spidertron remote inventory item
local spidertron_remote = data.raw["spidertron-remote"]["spidertron-remote"]
spidertron_remote.icon = icons_path .. "spidertron-remote.png"
spidertron_remote.icon_color_indicator_mask = icons_path .. "spidertron-remote-mask.png"
