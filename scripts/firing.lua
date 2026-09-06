local firing = {}
local TOOL = "interplanetary-artillery-targeting-remote"
local LEGACY_TOOL = "interplanetary-artillery-target"
local CANNON = "interplanetary-artillery-cannon"
local SAME_SURFACE_FLIGHT_TICKS = 300
local INTER_SURFACE_FLIGHT_TICKS = 900
local IMPACT_RADIUS = 6
local IMPACT_DAMAGE = 250
local MAP_LIMIT = 1000000
local resume_production

local function flight_ticks(source_surface_index, target_surface_index)
  if source_surface_index == target_surface_index then return SAME_SURFACE_FLIGHT_TICKS end
  return INTER_SURFACE_FLIGHT_TICKS
end

function firing.init()
  storage.in_flight_shots = storage.in_flight_shots or {}
  storage.shots_by_tick = storage.shots_by_tick or {}
  storage.next_shot_id = storage.next_shot_id or 1
  storage.player_cannon_targets = storage.player_cannon_targets or {}
end

local function message(player, key, ...)
  if player and player.valid then
    player.print({"interplanetary-artillery." .. key, ...})
  end
end

local function source(player, cannon_id)
  local cannon = cannon_id and storage.cannons[cannon_id]
  if not cannon or not cannon.entity.valid then return nil, "invalid-cannon" end
  local foundation = storage.foundations[cannon.foundation_unit_number]
  if not foundation or not foundation.entity.valid then return nil, "invalid-attachment" end
  local c, f = cannon.entity, foundation.entity
  if foundation.cannon_unit_number ~= cannon_id or c.surface.index ~= f.surface.index
    or c.force.index ~= f.force.index or c.position.x ~= f.position.x or c.position.y ~= f.position.y then
    return nil, "invalid-attachment"
  end
  if c.force.index ~= player.force.index then return nil, "wrong-force" end
  return foundation, cannon
end

local function valid_position(surface, position)
  if not position or type(position.x) ~= "number" or type(position.y) ~= "number" then return false end
  local settings = surface.map_gen_settings
  local half_width = settings.width and settings.width > 0 and settings.width / 2 or MAP_LIMIT
  local half_height = settings.height and settings.height > 0 and settings.height / 2 or MAP_LIMIT
  -- Comparisons also reject NaN and infinity before any engine position API.
  return math.abs(position.x) + IMPACT_RADIUS < math.min(MAP_LIMIT, half_width)
    and math.abs(position.y) + IMPACT_RADIUS < math.min(MAP_LIMIT, half_height)
end

local function impact_chunks_generated(surface, position)
  for x = math.floor((position.x - IMPACT_RADIUS) / 32), math.floor((position.x + IMPACT_RADIUS) / 32) do
    for y = math.floor((position.y - IMPACT_RADIUS) / 32), math.floor((position.y + IMPACT_RADIUS) / 32) do
      if not surface.is_chunk_generated({x, y}) then return false end
    end
  end
  return true
end

function firing.fire(player, cannon_id, surface, position)
  firing.init()
  local foundation, cannon = source(player, cannon_id)
  if not foundation then message(player, cannon); return nil end
  if not surface or not surface.valid then
    message(player, "invalid-surface"); return nil
  end
  if not valid_position(surface, position) then message(player, "invalid-target"); return nil end
  if not impact_chunks_generated(surface, position) then message(player, "ungenerated-target"); return nil end
  if (foundation.loaded_shots or 0) < 1 then message(player, "no-loaded-shots"); return nil end

  local id = storage.next_shot_id
  local shot = {
    id = id,
    cannon_unit_number = cannon_id,
    foundation_unit_number = cannon.foundation_unit_number,
    source_force_index = cannon.entity.force.index,
    source_surface_index = cannon.entity.surface.index,
    source_position = {x = cannon.entity.position.x, y = cannon.entity.position.y},
    target_surface_index = surface.index,
    target_position = {x = position.x, y = position.y},
    player_index = player.index,
    fire_tick = game.tick,
    impact_tick = game.tick + flight_ticks(cannon.entity.surface.index, surface.index),
  }
  foundation.loaded_shots = foundation.loaded_shots - 1
  resume_production(foundation)
  storage.next_shot_id = id + 1
  storage.in_flight_shots[id] = shot
  local bucket = storage.shots_by_tick[shot.impact_tick] or {}
  bucket[#bucket + 1] = id
  storage.shots_by_tick[shot.impact_tick] = bucket
  message(player, "shot-fired", id, cannon_id, position.x, position.y, foundation.loaded_shots,
    surface.name, (shot.impact_tick - shot.fire_tick) / 60)
  return id
end

local function impact(shot)
  local surface = game.surfaces[shot.target_surface_index]
  local force = game.forces[shot.source_force_index]
  local player = game.get_player(shot.player_index)
  if not surface or not force or not impact_chunks_generated(surface, shot.target_position) then
    message(player, "shot-cancelled", shot.id)
    return
  end
  surface.create_entity{name = "big-explosion", position = shot.target_position}
  for _, entity in pairs(surface.find_entities_filtered{position = shot.target_position, radius = IMPACT_RADIUS}) do
    if entity.valid and entity.health and entity.destructible then
      local other = entity.force
      if other.index ~= force.index and other.name ~= "neutral"
        and not force.get_friend(other) and not force.get_cease_fire(other) then
        entity.damage(IMPACT_DAMAGE, force, "explosion")
      end
    end
  end
  message(player, "shot-impact", shot.id, shot.target_position.x, shot.target_position.y, surface.name)
end

local function on_tick(event)
  local bucket = storage.shots_by_tick and storage.shots_by_tick[event.tick]
  if not bucket then return end
  storage.shots_by_tick[event.tick] = nil
  for _, id in ipairs(bucket) do
    local shot = storage.in_flight_shots[id]
    -- Remove before damage can raise other mods' handlers and cause reentry.
    storage.in_flight_shots[id] = nil
    if shot then impact(shot) end
  end
end

local function aim(event)
  firing.init()
  local player = game.get_player(event.player_index)
  local entity = player.selected
  if not entity or not entity.valid or entity.name ~= CANNON then
    message(player, "select-cannon"); return
  end
  local id = entity.unit_number
  local foundation, reason = source(player, id)
  if not foundation then message(player, reason); return end
  storage.player_cannon_targets[player.index] = id
  message(player, "aim-ready", id, foundation.loaded_shots or 0)
end

local function selected_area(event)
  if event.item ~= TOOL and event.item ~= LEGACY_TOOL then return end
  firing.init()
  local player = game.get_player(event.player_index)
  local area = event.area
  firing.fire(player, storage.player_cannon_targets[player.index], event.surface, {
    x = (area.left_top.x + area.right_bottom.x) / 2,
    y = (area.left_top.y + area.right_bottom.y) / 2,
  })
end

local function cancel_surface(event)
  for id, shot in pairs(storage.in_flight_shots or {}) do
    if shot.target_surface_index == event.surface_index then
      storage.in_flight_shots[id] = nil
      message(game.get_player(shot.player_index), "shot-cancelled", id)
    end
  end
end

function firing.register(resume)
  resume_production = resume
  script.on_event(defines.events.on_tick, on_tick)
  script.on_event("interplanetary-artillery-aim", aim)
  script.on_event(defines.events.on_player_selected_area, selected_area)
  script.on_event(defines.events.on_player_alt_selected_area, selected_area)
  script.on_event(defines.events.on_player_removed, function(event)
    if storage.player_cannon_targets then storage.player_cannon_targets[event.player_index] = nil end
  end)
  script.on_event(defines.events.on_pre_surface_deleted, cancel_surface)
  script.on_event(defines.events.on_pre_surface_cleared, cancel_surface)
  script.on_event(defines.events.on_forces_merging, function(event)
    for _, shot in pairs(storage.in_flight_shots or {}) do
      if shot.source_force_index == event.source.index then shot.source_force_index = event.destination.index end
    end
  end)
  commands.add_command("monolith-fire-test", {"interplanetary-artillery.fire-command"}, function(command)
    local player = command.player_index and game.get_player(command.player_index)
    if not player then return end
    firing.init()
    local x, y = (command.parameter or ""):match("^%s*(%S+)%s+(%S+)%s*$")
    x, y = tonumber(x), tonumber(y)
    if not x or not y then message(player, "fire-command"); return end
    firing.fire(player, storage.player_cannon_targets[player.index], player.surface, {x = x, y = y})
  end)
  commands.add_command("monolith-shot-status", {"interplanetary-artillery.shot-status-command"}, function(command)
    local player = command.player_index and game.get_player(command.player_index)
    if not player then return end
    firing.init()
    local count = 0
    for _, shot in pairs(storage.in_flight_shots) do
      if shot.source_force_index == player.force.index then
        count = count + 1
        message(player, "shot-status-entry", shot.id, shot.cannon_unit_number, shot.target_position.x,
          shot.target_position.y, shot.impact_tick - game.tick, shot.target_surface_index)
      end
    end
    message(player, "shot-status", storage.player_cannon_targets[player.index] or "-", count)
  end)
  commands.add_command("monolith-fire-surface-test", {"interplanetary-artillery.fire-surface-command"}, function(command)
    local player = command.player_index and game.get_player(command.player_index)
    if not player then return end
    firing.init()
    local name, x, y = (command.parameter or ""):match("^%s*(.-)%s+(%S+)%s+(%S+)%s*$")
    x, y = tonumber(x), tonumber(y)
    if not name or name == "" or not x or not y then message(player, "fire-surface-command"); return end
    name = name:match('^"(.*)"$') or name
    local surface = game.get_surface(name)
    local index = tonumber(name)
    if not surface and index and index >= 1 and index <= 4294967295 and index % 1 == 0 then
      surface = game.get_surface(index)
    end
    firing.fire(player, storage.player_cannon_targets[player.index], surface, {x = x, y = y})
  end)
end

return firing
