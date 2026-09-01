local FOUNDATION_NAME = "interplanetary-artillery-foundation"
local CANNON_NAME = "interplanetary-artillery-cannon"

local function ensure_storage()
  storage.foundations = storage.foundations or {}
  storage.cannons = storage.cannons or {}
  storage.object_registrations = storage.object_registrations or {}
end

local function position_key(surface_index, position)
  return surface_index .. ":" .. position.x .. ":" .. position.y
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

  storage.foundations[entity.unit_number] = {
    entity = entity,
    position_key = position_key(entity.surface.index, entity.position),
    cannon_unit_number = nil,
    object_registration = register_object(entity, "foundation"),
  }
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
  storage.foundations = {}
  storage.cannons = {}
  storage.object_registrations = {}

  for _, surface in pairs(game.surfaces) do
    for _, foundation in pairs(surface.find_entities_filtered{name = FOUNDATION_NAME}) do
      register_foundation(foundation)
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
