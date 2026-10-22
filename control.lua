-------------------------------------------------------------------------------
--[[AAI Warden by Earendel]] --
-- Altered to support spider-vehicles from DMV Directional Movement Vehicles
-------------------------------------------------------------------------------
require("stdlib/table")
require("stdlib/string")
local util = require("util")

local high_fuel_item = "rocket-fuel"
local fuel = defines.inventory.fuel
local trunk = defines.inventory.spider_trunk
local ammo = defines.inventory.spider_ammo
local inv_nums = { fuel, trunk }

-- run mining 2 times per second
local passive_search_interval = 120
local active_search_interval = 30
local instant_search_interval = 15

-------------------------------------------------------------------------------
--[[HELPERS]] --
-------------------------------------------------------------------------------

local get_fuel = {
  --Build a table of fuel items, index as fuel name, value as table with name, fuel_value
  build = function()
    return table.map(game.item_prototypes,
      function(item, name)
        local fuel_item = {}
        if item.fuel_value and item.fuel_value > 0 then
          fuel_item.fuel_value = item.fuel_value
          fuel_item.name = name
        end
        --Return: index as item_name, value as fuel_value
        return fuel_item.name and fuel_item or nil
      end
    )
  end,

  --Return a fuel item table if a fuel item is in the contents.
  item = function(contents)
    local fuel_items = global.fuel_items

    local contains_coal = false
    local contains_wood = false

    -- First, find all fuels in inventory
    for content_name in pairs(contents) do
      -- If we found good fuel, return it
      if fuel_items[content_name]
          and not (content_name == "coal")
          and not (content_name == "wood") then
        return fuel_items[content_name]
        -- If we find coal or wood, take note
      elseif content_name == "coal" then contains_coal = true
      elseif content_name == "wood" then contains_wood = true
      end
    end

    -- Now that we've looked for good fuel, return crappy fuel if exists
    if contains_coal then return fuel_items["coal"] end
    if contains_wood then return fuel_items["wood"] end
  end
}

local DMVs = {
  --global refrence to all saved DMVs, set in on_load and on_init
  DMVs = {},

  --variant types of wardens, TODO in future move to sub-objects
  variants = {
    ["DMV-car"] = {
      vehicle_name = "DMV-car",
      search_radius = 0, -- repair + items
      destroys_trees = false,
      destroys_rocks_biters = false
    },
    ["DMV-ironclad"] = {
      vehicle_name = "DMV-ironclad",
      search_radius = 0, -- repair + items
      destroys_trees = false,
      destroys_rocks_biters = false
    },
    ["DMV-tank"] = {
      vehicle_name = "DMV-tank",
      search_radius = 0, -- repair + items
      destroys_trees = true,
      destroys_rocks_biters = true
    },
    ["DMV-vehicle-flame-tank"] = {
      vehicle_name = "DMV-vehicle-flame-tank",
      search_radius = 0, -- repair + items
      destroys_trees = true,
      destroys_rocks_biters = true
    },
    ["DMV-vehicle-laser-tank"] = {
      vehicle_name = "DMV-vehicle-laser-tank",
      search_radius = 0, -- repair + items
      destroys_trees = true,
      destroys_rocks_biters = true
    },
    ["DMV-hcraft-entity"] = {
      vehicle_name = "DMV-hcraft-entity",
      search_radius = 0, -- repair + items
      destroys_trees = false,
      destroys_rocks_biters = false
    },
    ["DMV-acraft-entity"] = {
      vehicle_name = "DMV-acraft-entity",
      search_radius = 0, -- repair + items
      destroys_trees = false,
      destroys_rocks_biters = false
    },
    ["DMV-vehicle-warden"] = {
      vehicle_name = "DMV-vehicle-warden",
      search_radius = 25, -- repair + items
      destroys_trees = true,
      destroys_rocks_biters = false
    }
  },

  --metamethods for DMVs.DMVs
  mt = {
    --DMVs[number] will return DMVs.DMVs[number]
    __index = function(tab, key)
      return type(key) == "number" and tab.DMVs[key]
    end,
    --__newindex: DMVs[number] = value store in DMVs.DMVs[number]
    __newindex = function(tab, key, value)
      if type(key) == "number" then
        tab.DMVs[key] = value
      else
        rawset(tab, key, value)
      end
    end
  }
}
setmetatable(DMVs, DMVs.mt)

function DMVs:new(entity)
  if entity and entity.valid and entity.type == "spider-vehicle" then
    if self.variants[entity.name] then
      local DMV = {
        unit_number = entity.unit_number,
        entity = entity,
        name = entity.name,
        mode = "active"
      }
      --metatables are not saved to global. Iterate and re-assign in on_load
      setmetatable(DMV, { __index = DMVs })
      self[entity.unit_number] = DMV
      return DMV
    end
  end
end

--Replace and rekey the DMV entity
function DMVs.replace(event)
  if DMVs[event.old_entity_unit_number] then
    local DMV = table.deepcopy(DMVs[event.old_entity_unit_number])
    DMV.entity = event.new_entity
    DMV.unit_number = event.new_entity_unit_number
    DMVs[event.new_entity_unit_number] = DMV
    DMVs[event.old_entity_unit_number] = nil
  end
end

--destroy DMV record
function DMVs:die()
  ---@diagnostic disable-next-line: need-check-nil
  if not self.entity.valid then
    self.DMVs[self.unit_number] = nil
    self = nil
  end
  return not self
end

--Consume fuel from a list of fuels generated on init and changed

local function consume_fuel_or_equipment(DMV)
  if DMV.entity.grid and DMV.entity.grid.available_in_batteries > 10000 then
    --Added by Undarl; basic battery fueling logic courtesy of Sirenfal
    ---Modified by the Nexela
    DMV.entity.burner.currently_burning = high_fuel_item
    local energy_deficit = game.item_prototypes[high_fuel_item].fuel_value - DMV.entity.burner.remaining_burning_fuel --use initial energy value as baseline
    local batteries = table.filter(DMV.entity.grid.equipment, function(v) return v.type == "battery-equipment" end)
    local num_batteries = #batteries
    while num_batteries > 0 and energy_deficit > 0 do
      local battery = batteries[num_batteries]
      local energy_used = energy_deficit - math.max(battery.energy, energy_deficit)
      battery.energy = battery.energy - energy_used
      DMV.entity.burner.remaining_burning_fuel = DMV.entity.burner.remaining_burning_fuel + energy_used
      energy_deficit = energy_deficit - energy_used
      num_batteries = num_batteries - 1
    end
  else
    for _, inv_num in pairs(inv_nums) do
      local inventory = DMV.entity.get_inventory(inv_num)
      if inventory then
        local fuel_item = get_fuel.item(inventory.get_contents())
        if fuel_item then
          DMV.entity.burner.currently_burning = fuel_item.name
          DMV.entity.burner.remaining_burning_fuel = DMV.entity.burner.remaining_burning_fuel + fuel_item.fuel_value
          inventory.remove({ name = fuel_item.name })
          return true
        end
      end
    end
  end
end

local function end_beam(warden)
  if warden.beam and warden.beam.valid then
    warden.beam.destroy()
    warden.beam = nil
  end
end

local function search_floor_items(warden)
  local range = warden.variants[warden.name].search_radius
  local area = {
    { warden.entity.position.x - range, warden.entity.position.y - range },
    { warden.entity.position.x + range, warden.entity.position.y + range }
  }
  for _, entity in pairs(warden.entity.surface.find_entities_filtered { area = area, type = "item-entity" }) do
    local inserted = warden.entity.insert({ name = entity.stack.name, count = entity.stack.count })
    if inserted > 0 then
      warden.mode = "active"
      if game.entity_prototypes[entity.stack.name .. "-_-" .. "projectile"] then -- aai vehicles transfer particles
        warden.entity.surface.create_entity {
          name = entity.stack.name .. "-_-" .. "projectile",
          position = entity.position,
          target = warden.entity,
          speed = math.random() * 0.2
        }
      end
      entity.stack.count = entity.stack.count - inserted
    else
      return -- full
    end
  end
end

local function get_repair_items()
  if not global.repair_items then
    global.repair_items = {}
    for _, item in pairs(game.item_prototypes) do
      if item.type == "repair-tool" then
        global.repair_items[item.name] = item.speed
      end
    end
  end
  return global.repair_items
end

local function repair_area(warden, repair_item_name, speed)
  local range = warden.variants[warden.name].search_radius

  local area = {
    { warden.entity.position.x - range, warden.entity.position.y - range },
    { warden.entity.position.x + range, warden.entity.position.y + range }
  }
  local best_repair_target = nil
  local best_health_percent = 1

  for _, entity in pairs(warden.entity.surface.find_entities_filtered { area = area, force = warden.entity.force }) do
    if entity.health and entity.health < entity.prototype.max_health then
      local health_percent = entity.health / entity.prototype.max_health
      if health_percent < 1
          and (best_repair_target == nil or health_percent < best_health_percent)
          and not entity.prototype.has_flag("not-repairable") then
        best_repair_target = entity
        best_health_percent = health_percent
      end
    end
  end

  if best_repair_target and best_repair_target.valid then
    warden.mode = "active"
    --best_repair_target.prototype.repair_speed_modifier is unit???
    local to_repair = math.min(best_repair_target.prototype.max_health - best_repair_target.health,
      active_search_interval * best_repair_target.prototype.repair_speed_modifier * speed)
    best_repair_target.health = best_repair_target.health + to_repair

    warden.entity.get_inventory(trunk).find_item_stack(repair_item_name).drain_durability(to_repair /
      best_repair_target.prototype.repair_speed_modifier * speed)

    -- play sound and FX
    end_beam(warden)
    warden.beam = warden.entity.surface.create_entity {
      name = "repair-beam",
      position = warden.entity.position,
      source = warden.entity,
      target = best_repair_target
    }
  elseif warden.beam and warden.beam.valid then
    end_beam(warden)
  end

end

local function refuel_on_tick(DMV)
  -- High priority: refuel
  if (game.tick + DMV.unit_number) % active_search_interval == 0 then

    if (not DMV.entity.burner.currently_burning)
        or (DMV.entity.burner.remaining_burning_fuel < DMV.entity.burner.currently_burning.fuel_value * 0.05 + 1) then -- was 0.02
      consume_fuel_or_equipment(DMV)
    end
  end
end

local function request_to_open_gates_on_tick(DMV)
  if (game.tick + DMV.unit_number) % instant_search_interval == 0 then
    local gates = DMV.entity.surface.find_entities_filtered {
      position = DMV.entity.position,
      radius = DMV.entity.prototype.collision_box.right_bottom.x + 4.5,
      type = "gate"
    }

    for _, gate in pairs(gates) do
      gate.request_to_open(DMV.entity.force, 16)
    end
  end
end

-- [[The warden can repair other vehicles]] --
local function repair_on_tick(DMV)
  -- Runs twice per second, on a different tick for each DMV
  if (game.tick + DMV.unit_number) % active_search_interval == 0
      -- Runs once every 2 seconds for non-active DMVs
      or (game.tick + DMV.unit_number) % passive_search_interval == 0 then

    local can_repair = false

    for name, speed in pairs(get_repair_items()) do
      if DMV.entity.get_inventory(trunk).get_item_count(name) > 0
          and DMV.variants[DMV.name].search_radius > 0 then
        repair_area(DMV, name, speed)
        can_repair = true
        break
      end
    end

    if not can_repair then
      DMV.mode = "passive"
      end_beam(DMV)
    end
  end
end

local function collect_items_on_tick(DMV)
  if (game.tick + DMV.unit_number) % (passive_search_interval * 2) == 0 then
    -- Uses "rocket part" because it has a stack size of one
    if DMV.entity.can_insert("rocket-part") then search_floor_items(DMV) end
    DMV.entity.burner.remaining_burning_fuel = DMV.entity.burner.remaining_burning_fuel - 2000
    local chart_range = 128
    DMV.entity.force.chart(DMV.entity.surface,
      { { x = DMV.entity.position.x - chart_range, y = DMV.entity.position.y - chart_range },
        { x = DMV.entity.position.x + chart_range, y = DMV.entity.position.y + chart_range } })
  end
end

-- [[Some vehicles can destroy trees, rocks, and biters]] --
local function check_for_tree(found_entity, vehicle_entity)
  -- If It's a tree
  if (string.match(found_entity.name, "tree")
      or string.match(found_entity.name, "%-trunk"))
      and not (string.match(found_entity.name, "stump")) then
    --Spawn wood on the ground
    for i = 1, math.random(3), 1 do -- 1 to 3 wood
      local loc = {
        found_entity.bounding_box.left_top.x - math.random(3) + 2,
        found_entity.bounding_box.left_top.y - math.random(3) + 2
      }

      found_entity.surface.create_entity {
        name = "item-on-ground",
        position = loc,
        stack = { name = "wood" }
      }
    end
    -- destructible might not have vehicle impact sound defined
    if game.is_valid_sound_path("entity-vehicle_impact/" .. found_entity.name) then
      found_entity.surface.play_sound { path = "entity-vehicle_impact/" .. found_entity.name,
        position = found_entity.position }
    end

    --Destroy!
    found_entity.damage(50, "player")
  end
end

local function destroy_on_tick(DMV)
  if (game.tick + DMV.unit_number) % (instant_search_interval - math.random(2)) == 0 then

    -- Destroy trees
    if DMV.variants[DMV.name].destroys_trees then

      -- collect trees in collision with this warden
      local colliding_entities = DMV.entity.surface.find_entities_filtered {
        area = DMV.entity.bounding_box,
        force = "neutral"
      }

      for i, found in pairs(colliding_entities) do
        check_for_tree(found, DMV.entity)
      end

    end

    if DMV.variants[DMV.name].destroys_rocks_biters then

      -- collect rocks in collision with this warden
      local colliding_entities = DMV.entity.surface.find_entities_filtered {
        area = DMV.entity.bounding_box,
        force = "neutral"
      }

      for i, found_entity in pairs(colliding_entities) do
        if string.match(found_entity.name, "rock%-") then

          -- destructible might not have vehicle impact sound defined
          if game.is_valid_sound_path("entity-vehicle_impact/" .. found_entity.name) then
            found_entity.surface.play_sound { path = "entity-vehicle_impact/" .. found_entity.name,
              position = found_entity.position }
          end

          found_entity.damage(2000, "player")
        end
      end

      local colliding_enemies = DMV.entity.surface.find_enemy_units(DMV.entity.position,
        DMV.entity.prototype.collision_box.right_bottom.x + 0.45) -- use bounding box for search radius

      for i, found in pairs(colliding_enemies) do
        if found.valid then
          found.damage(75, "player")
        end
      end

    end
  end
end

local function restock_ammo_on_tick(DMV)
  if (game.tick + DMV.unit_number) % passive_search_interval == 0 then
    local ammo_inventory = DMV.entity.get_inventory(ammo)
    local contents = DMV.entity.get_inventory(trunk).get_contents()
    if contents then
      for item_name, quantity in pairs(contents) do
        local num_inserted = DMV.entity.get_inventory(ammo).insert({ name = item_name, count = quantity })
        if num_inserted > 0 then
          DMV.entity.get_inventory(trunk).remove({ name = item_name, count = num_inserted })
        end
      end
    end

  end
end

-------------------------------------------------------------------------------
--[[EVENTS]] --
-------------------------------------------------------------------------------
script.on_event(defines.events.on_tick, function(event)
  for _, DMV in pairs(DMVs.DMVs) do
    if DMV.entity.valid then
      refuel_on_tick(DMV)
      restock_ammo_on_tick(DMV)
      request_to_open_gates_on_tick(DMV)

      -- DMV must have fuel to do work
      if DMV.entity.burner.remaining_burning_fuel > 0 then

        -- the "active" tag is used for repairing and collecting items
        if DMV.mode == "active" then
          repair_on_tick(DMV)
          collect_items_on_tick(DMV)
        end
        destroy_on_tick(DMV)
      else
        DMV.mode = "passive"
        end_beam(DMV)
      end

    else -- not DMV.entity.valid
      DMV:die()
    end
  end
end)

script.on_event(defines.events.on_built_entity, function(event)
  DMVs:new(event.created_entity)
end)

script.on_event(defines.events.on_pre_player_mined_item, function(event)
  if DMVs[event.entity.unit_number] then
    DMVs[event.entity.unit_number]:die()
  end
end)


-------------------------------------------------------------------------------
--[[Rotate vehicle remnants upon destruction]] --
-------------------------------------------------------------------------------
script.on_event(defines.events.on_entity_died, function(event)
  global.orientation = event.entity.torso_orientation -- save orientation
end, { { filter = "type", type = "spider-vehicle" } })

script.on_event(defines.events.on_post_entity_died, function(event)
  for _, corpse in pairs(event.corpses) do
    corpse.orientation = global.orientation
  end
end, { { filter = "type", type = "spider-vehicle" } })



-------------------------------------------------------------------------------
--[[INIT]] --
-------------------------------------------------------------------------------
local function on_load()
  DMVs.DMVs = global.DMVs
  for _, DMV in pairs(DMVs.DMVs) do
    setmetatable(DMV, { __index = DMVs })
  end
end

script.on_load(on_load)

local function on_configuration_changed()
  --update fuel items every change
  global.fuel_items = get_fuel.build()
  global.repair_items = nil
end

script.on_configuration_changed(on_configuration_changed)

local function on_init()
  global.DMVs = global.DMVs or {}
  DMVs.DMVs = global.DMVs
  global.fuel_items = get_fuel.build()
  global.repair_items = nil
end

script.on_init(on_init)

script.on_event(defines.events.on_built_entity, function(event)
  DMVs:new(event.created_entity)
end)
