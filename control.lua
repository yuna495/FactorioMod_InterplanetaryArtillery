local FOUNDATION_NAME = "interplanetary-artillery-foundation"
local CANNON_NAME = "interplanetary-artillery-cannon"
local FOUNDATION_TILE_NAME = "interplanetary-artillery-foundation-tile"
local TEST_SHELL_NAME = "interplanetary-artillery-test-shell"
local MAX_LOADED_SHOTS = 2
local MONITOR_INTERVAL_TICKS = 60
local firing = require("scripts.firing")

local function ensure_storage()
  storage.foundations = storage.foundations or {}
  storage.cannons = storage.cannons or {}
  storage.object_registrations = storage.object_registrations or {}
  storage.active_foundations = storage.active_foundations or {}
  storage.protected_tiles = storage.protected_tiles or {}
  storage.player_foundation_targets = storage.player_foundation_targets or {}
  firing.init()
end

local function position_key(surface_index, position)
  return surface_index .. ":" .. position.x .. ":" .. position.y
end

local function tile_key(surface_index, position)
  return surface_index .. ":" .. position.x .. ":" .. position.y
end

local function foundation_tile_positions(entity)
  local positions = {}
  local center_x = math.floor(entity.position.x + 0.5)
  local center_y = math.floor(entity.position.y + 0.5)

  for x = center_x - 7, center_x + 7 do
    for y = center_y - 7, center_y + 7 do
      positions[#positions + 1] = {x = x, y = y}
    end
  end

  return positions
end

local function valid(entity)
  return entity and entity.valid
end

local function register_object(entity, kind)
  if not valid(entity) or not entity.unit_number then return nil end

  local registration_number = script.register_on_object_destroyed(entity)
  storage.object_registrations[registration_number] = {
    kind = kind,
    unit_number = entity.unit_number,
  }
  return registration_number
end

local function get_foundation(unit_number)
  local record = storage.foundations[unit_number]
  if record and valid(record.entity) then
    return record
  end
  storage.foundations[unit_number] = nil
  return nil
end

local function get_cannon(unit_number)
  local record = storage.cannons[unit_number]
  if record and valid(record.entity) then
    return record
  end
  storage.cannons[unit_number] = nil
  return nil
end

local function spill_item_counts(entity, items)
  if not valid(entity) or not items then return end

  for _, item in pairs(items) do
    if item.name and item.count and item.count > 0 then
      local stack = {name = item.name, count = item.count}
      if item.quality then
        stack.quality = item.quality
      end

      entity.surface.spill_item_stack{
        position = entity.position,
        stack = stack,
        force = entity.force,
        allow_belts = false,
      }
    end
  end
end

local function set_foundation_recipe(record)
  if not record or not valid(record.entity) then return end

  if (record.loaded_shots or 0) >= MAX_LOADED_SHOTS then
    local recipe = record.entity.get_recipe()
    if recipe then
      local removed_items = record.entity.set_recipe(nil)
      spill_item_counts(record.entity, removed_items)
    end
    record.entity.crafting_progress = 0
    storage.active_foundations[record.entity.unit_number] = nil
    return
  end

  local recipe = record.entity.get_recipe()
  if not recipe or recipe.name ~= TEST_SHELL_NAME then
    record.entity.set_recipe(TEST_SHELL_NAME)
  end

  storage.active_foundations[record.entity.unit_number] = true
end

local function protect_foundation_tiles(entity)
  if not valid(entity) then return end

  for _, position in pairs(foundation_tile_positions(entity)) do
    storage.protected_tiles[tile_key(entity.surface.index, position)] = entity.unit_number
  end
end

local function unprotect_foundation_tiles(record)
  if not record or not valid(record.entity) then return end

  for _, position in pairs(foundation_tile_positions(record.entity)) do
    local key = tile_key(record.entity.surface.index, position)
    if storage.protected_tiles[key] == record.entity.unit_number then
      storage.protected_tiles[key] = nil
    end
  end
end

local function find_foundation_at_mount(entity)
  local surface = entity.surface
  local position = entity.position
  local candidates = surface.find_entities_filtered{
    name = FOUNDATION_NAME,
    position = position,
    radius = 0.05,
    force = entity.force,
  }

  for _, foundation in pairs(candidates) do
    if foundation.position.x == position.x and foundation.position.y == position.y then
      return foundation
    end
  end
end

local function reject_built_entity(entity, item_name, player_index)
  local surface = entity.surface
  local position = entity.position
  local force = entity.force

  entity.destroy{raise_destroy = true}

  if player_index and game.players[player_index] and game.players[player_index].valid then
    local player = game.players[player_index]
    local inserted = player.insert{name = item_name, count = 1}
    if inserted == 1 then return end
  end

  surface.spill_item_stack{
    position = position,
    stack = {name = item_name, count = 1},
    force = force,
    allow_belts = false,
  }
end

local function cleanup_cannon(cannon_unit_number)
  local cannon = storage.cannons[cannon_unit_number]
  if not cannon then return end

  local foundation = get_foundation(cannon.foundation_unit_number)
  if foundation and foundation.cannon_unit_number == cannon_unit_number then
    foundation.cannon_unit_number = nil
  end

  storage.cannons[cannon_unit_number] = nil
end

local function give_or_spill_stack(stack, player, surface, position, force)
  if not stack.valid_for_read then return end

  local count = stack.count
  local inserted = 0

  if player and player.valid then
    inserted = player.insert{name = stack.name, count = count}
  end

  local remaining = count - inserted
  if remaining > 0 then
    surface.spill_item_stack{
      position = position,
      stack = {name = stack.name, count = remaining},
      force = force,
      allow_belts = false,
    }
  end
end

local function mine_cannon_for_player(cannon, player)
  local surface = cannon.entity.surface
  local position = cannon.entity.position
  local force = cannon.entity.force
  local mined_items = game.create_inventory(10)

  cannon.entity.mine{inventory = mined_items, force = true, raise_destroyed = true}

  for i = 1, #mined_items do
    give_or_spill_stack(mined_items[i], player, surface, position, force)
  end

  mined_items.destroy()
end

local function mine_or_destroy_attached_cannon(cannon, options)
  options = options or {}

  if options.mine_cannon then
    if options.player_index and game.players[options.player_index] and game.players[options.player_index].valid then
      mine_cannon_for_player(cannon, game.players[options.player_index])
      return
    elseif valid(options.robot) then
      local inventory = options.robot.get_inventory(defines.inventory.robot_cargo)
      if inventory and inventory.valid then
        cannon.entity.mine{inventory = inventory, force = true, raise_destroyed = true}
        return
      end
    end
  end

  cannon.entity.destroy{raise_destroy = true}
end

local function cleanup_foundation(foundation_unit_number, options)
  local foundation = storage.foundations[foundation_unit_number]
  if not foundation then return end

  storage.active_foundations[foundation_unit_number] = nil
  unprotect_foundation_tiles(foundation)

  if foundation.cannon_unit_number then
    local cannon = get_cannon(foundation.cannon_unit_number)
    if cannon then
      storage.cannons[cannon.entity.unit_number] = nil
      mine_or_destroy_attached_cannon(cannon, options)
    end
  end

  storage.foundations[foundation_unit_number] = nil
end

local function register_foundation(entity)
  if not valid(entity) or entity.name ~= FOUNDATION_NAME or not entity.unit_number then return end

  local existing_record = storage.foundations[entity.unit_number]
  storage.foundations[entity.unit_number] = {
    entity = entity,
    position_key = position_key(entity.surface.index, entity.position),
    loaded_shots = existing_record and existing_record.loaded_shots or 0,
    cannon_unit_number = existing_record and existing_record.cannon_unit_number or nil,
    object_registration = existing_record and existing_record.object_registration or register_object(entity, "foundation"),
  }
  protect_foundation_tiles(entity)
  set_foundation_recipe(storage.foundations[entity.unit_number])
end

local function register_cannon(entity, player_index)
  if not valid(entity) or entity.name ~= CANNON_NAME or not entity.unit_number then return end

  local foundation = find_foundation_at_mount(entity)
  if not foundation or not foundation.unit_number then
    reject_built_entity(entity, CANNON_NAME, player_index)
    return
  end

  local foundation_record = get_foundation(foundation.unit_number)
  if not foundation_record then
    register_foundation(foundation)
    foundation_record = get_foundation(foundation.unit_number)
  end

  if foundation_record.cannon_unit_number and get_cannon(foundation_record.cannon_unit_number) then
    reject_built_entity(entity, CANNON_NAME, player_index)
    return
  end

  foundation_record.cannon_unit_number = entity.unit_number
  storage.cannons[entity.unit_number] = {
    entity = entity,
    foundation_unit_number = foundation.unit_number,
    object_registration = register_object(entity, "cannon"),
  }
end

local function rebuild_storage()
  local previous_loaded_shots = {}
  for unit_number, record in pairs(storage.foundations or {}) do
    previous_loaded_shots[unit_number] = record.loaded_shots or 0
  end

  storage.foundations = {}
  storage.cannons = {}
  storage.object_registrations = {}
  storage.active_foundations = {}
  storage.protected_tiles = {}

  for _, surface in pairs(game.surfaces) do
    for _, foundation in pairs(surface.find_entities_filtered{name = FOUNDATION_NAME}) do
      register_foundation(foundation)
      local record = storage.foundations[foundation.unit_number]
      if record then
        record.loaded_shots = previous_loaded_shots[foundation.unit_number] or 0
        set_foundation_recipe(record)
      end
    end
  end

  for _, surface in pairs(game.surfaces) do
    for _, cannon in pairs(surface.find_entities_filtered{name = CANNON_NAME}) do
      register_cannon(cannon)
    end
  end
end

script.on_init(ensure_storage)
script.on_configuration_changed(function()
  ensure_storage()
  rebuild_storage()
end)

local function remove_test_shells_from_output(record)
  local output = record.entity.get_output_inventory()
  if not output or not output.valid then return 0 end

  local free_slots = MAX_LOADED_SHOTS - (record.loaded_shots or 0)
  if free_slots <= 0 then return 0 end

  local available = output.get_item_count(TEST_SHELL_NAME)
  local consumed = math.min(available, free_slots)
  if consumed > 0 then
    output.remove{name = TEST_SHELL_NAME, count = consumed}
    record.loaded_shots = (record.loaded_shots or 0) + consumed
  end

  return consumed
end

local function monitor_foundation_outputs()
  ensure_storage()

  for unit_number in pairs(storage.active_foundations) do
    local record = get_foundation(unit_number)
    if record then
      remove_test_shells_from_output(record)
      set_foundation_recipe(record)
    else
      storage.active_foundations[unit_number] = nil
    end
  end
end

script.on_nth_tick(MONITOR_INTERVAL_TICKS, monitor_foundation_outputs)

local function foundation_record_from_selected_entity(entity)
  if not valid(entity) then return nil end

  if entity.name == FOUNDATION_NAME then
    return get_foundation(entity.unit_number)
  end

  if entity.name == CANNON_NAME then
    local cannon = get_cannon(entity.unit_number)
    if cannon then
      return get_foundation(cannon.foundation_unit_number)
    end
  end
end

local function remember_player_foundation_target(player, record)
  if not player or not player.valid or not record or not valid(record.entity) then return end

  storage.player_foundation_targets[player.index] = record.entity.unit_number
end

local function foundation_record_from_player_memory(player)
  if not player or not player.valid then return nil end

  local unit_number = storage.player_foundation_targets[player.index]
  if not unit_number then return nil end

  return get_foundation(unit_number)
end

local function nearest_foundation_record(player)
  if not player or not player.valid then return nil end

  local candidates = player.surface.find_entities_filtered{
    name = FOUNDATION_NAME,
    position = player.position,
    radius = 20,
    force = player.force,
  }

  local nearest
  local nearest_distance
  for _, entity in pairs(candidates) do
    if valid(entity) and entity.unit_number then
      local dx = entity.position.x - player.position.x
      local dy = entity.position.y - player.position.y
      local distance = dx * dx + dy * dy
      if not nearest_distance or distance < nearest_distance then
        nearest = entity
        nearest_distance = distance
      end
    end
  end

  if nearest then
    return get_foundation(nearest.unit_number)
  end
end

local function foundation_record_for_player_command(player)
  local record = foundation_record_from_selected_entity(player.selected)
  if record then
    remember_player_foundation_target(player, record)
    return record
  end

  record = foundation_record_from_player_memory(player)
  if record then return record end

  record = nearest_foundation_record(player)
  if record then
    remember_player_foundation_target(player, record)
    return record
  end
end

local function selected_foundation_status(player)
  local record = foundation_record_for_player_command(player)
  if not record then
    player.print({"interplanetary-artillery.no-selected-foundation"})
    return
  end

  local recipe = record.entity.get_recipe()
  player.print({"interplanetary-artillery.loaded-shots-status", record.loaded_shots or 0, MAX_LOADED_SHOTS, recipe and recipe.name or "-"})
end

commands.add_command("monolith-status", {"interplanetary-artillery.monolith-status-command"}, function(command)
  if not command.player_index then return end

  local player = game.players[command.player_index]
  if player then
    selected_foundation_status(player)
  end
end)

commands.add_command("monolith-consume-test-shot", {"interplanetary-artillery.consume-test-shot-command"}, function(command)
  if not command.player_index then return end

  local player = game.players[command.player_index]
  if not player then return end

  local record = foundation_record_from_selected_entity(player.selected)
  if not record then
    record = foundation_record_for_player_command(player)
  end
  if not record then
    player.print({"interplanetary-artillery.no-selected-foundation"})
    return
  end

  if (record.loaded_shots or 0) <= 0 then
    player.print({"interplanetary-artillery.no-loaded-shots"})
    return
  end

  record.loaded_shots = record.loaded_shots - 1
  set_foundation_recipe(record)
  player.print({"interplanetary-artillery.consumed-test-shot", record.loaded_shots, MAX_LOADED_SHOTS})
end)

local function on_gui_opened(event)
  local player = game.players[event.player_index]
  if not player then return end

  local record = foundation_record_from_selected_entity(event.entity)
  if record then
    remember_player_foundation_target(player, record)
    player.print({"interplanetary-artillery.loaded-shots-debug", record.loaded_shots or 0, MAX_LOADED_SHOTS})
  end
end

local function on_selected_entity_changed(event)
  local player = game.players[event.player_index]
  if not player then return end

  local record = foundation_record_from_selected_entity(player.selected)
  if record then
    remember_player_foundation_target(player, record)
  end
end

local function on_entity_built(event)
  ensure_storage()

  local entity = event.entity or event.created_entity
  if not valid(entity) then return end

  if entity.name == FOUNDATION_NAME then
    register_foundation(entity)
  elseif entity.name == CANNON_NAME then
    register_cannon(entity, event.player_index)
  end
end

local function on_entity_removed(event)
  ensure_storage()

  local entity = event.entity
  if not valid(entity) then return end

  if entity.name == FOUNDATION_NAME and entity.unit_number then
    cleanup_foundation(entity.unit_number, {
      mine_cannon = event.mine_attached_cannon,
      player_index = event.player_index,
      robot = event.robot,
    })
  elseif entity.name == CANNON_NAME and entity.unit_number then
    cleanup_cannon(entity.unit_number)
  end
end

local function on_player_mining_entity(event)
  event.mine_attached_cannon = true
  on_entity_removed(event)
end

local function on_robot_mining_entity(event)
  event.mine_attached_cannon = true
  on_entity_removed(event)
end

local function on_object_destroyed(event)
  ensure_storage()

  local registered = storage.object_registrations[event.registration_number]
  if not registered then return end
  storage.object_registrations[event.registration_number] = nil

  if registered.kind == "foundation" then
    cleanup_foundation(registered.unit_number)
  elseif registered.kind == "cannon" then
    cleanup_cannon(registered.unit_number)
  end
end

local function restore_protected_tiles(event, actor)
  ensure_storage()

  local surface = game.surfaces[event.surface_index]
  if not surface then return end

  local restore_tiles = {}
  local restored_count = 0

  for _, old_tile in pairs(event.tiles or {}) do
    local position = old_tile.position
    local old_tile_value = old_tile.old_tile or old_tile.name
    local old_tile_name = type(old_tile_value) == "table" and old_tile_value.name or old_tile_value

    if old_tile_name == FOUNDATION_TILE_NAME and storage.protected_tiles[tile_key(event.surface_index, position)] then
      restored_count = restored_count + 1
      restore_tiles[restored_count] = {name = FOUNDATION_TILE_NAME, position = position}
    end
  end

  if restored_count == 0 then return end

  surface.set_tiles(restore_tiles, true)

  if actor and actor.valid then
    local removed = 0

    if actor.object_name == "LuaPlayer" then
      removed = actor.remove_item{name = FOUNDATION_TILE_NAME, count = restored_count}
      actor.print({"interplanetary-artillery.foundation-tile-protected", restored_count})
    else
      local inventory = actor.get_inventory(defines.inventory.robot_cargo)
      if inventory and inventory.valid then
        removed = inventory.remove{name = FOUNDATION_TILE_NAME, count = restored_count}
      end
    end
  end
end

local function on_player_mined_tile(event)
  restore_protected_tiles(event, game.players[event.player_index])
end

local function on_robot_mined_tile(event)
  restore_protected_tiles(event, event.robot)
end

local function register_event(event_id, handler, filters)
  if event_id then
    script.on_event(event_id, handler, filters)
  end
end

local built_filters = {{filter = "name", name = FOUNDATION_NAME}, {filter = "name", name = CANNON_NAME}}
local removed_filters = {{filter = "name", name = FOUNDATION_NAME}, {filter = "name", name = CANNON_NAME}}

register_event(defines.events.on_built_entity, on_entity_built, built_filters)
register_event(defines.events.on_robot_built_entity, on_entity_built, built_filters)
register_event(defines.events.script_raised_built, on_entity_built, built_filters)
register_event(defines.events.script_raised_revive, on_entity_built, built_filters)
register_event(defines.events.on_space_platform_built_entity, on_entity_built, built_filters)
register_event(defines.events.on_entity_cloned, function(event)
  on_entity_built{entity = event.destination}
end)

register_event(defines.events.on_pre_player_mined_item, on_player_mining_entity, removed_filters)
register_event(defines.events.on_robot_pre_mined, on_robot_mining_entity, removed_filters)
register_event(defines.events.on_entity_died, on_entity_removed, removed_filters)
register_event(defines.events.script_raised_destroy, on_entity_removed, removed_filters)
register_event(defines.events.on_object_destroyed, on_object_destroyed)
register_event(defines.events.on_gui_opened, on_gui_opened)
register_event(defines.events.on_selected_entity_changed, on_selected_entity_changed)
register_event(defines.events.on_player_mined_tile, on_player_mined_tile)
register_event(defines.events.on_robot_mined_tile, on_robot_mined_tile)

firing.register(set_foundation_recipe)
