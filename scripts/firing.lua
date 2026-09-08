local firing = {}
local flight = require("scripts.flight")
local countdown = require("scripts.countdown")
local visuals = require("scripts.shot-visuals")
local cannon_visuals = require("scripts.cannon-visuals")
local aiming = require("scripts.aiming")
local TOOL = "interplanetary-artillery-targeting-remote"
local LEGACY_TOOL = "interplanetary-artillery-target"
local CANNON = "interplanetary-artillery-cannon"
local IMPACT_RADIUS = 6
local IMPACT_DAMAGE = 250
local MAP_LIMIT = 1000000
local resume_production

function firing.init()
  aiming.init()
  storage.in_flight_shots = storage.in_flight_shots or {}
  storage.shots_by_tick = storage.shots_by_tick or {}
  storage.next_shot_id = storage.next_shot_id or 1
  storage.player_cannon_targets = storage.player_cannon_targets or {}
  storage.firing_round_robin = storage.firing_round_robin or {}
  storage.countdown_by_tick = storage.countdown_by_tick or {}
  storage.visual_cleanup_by_tick = storage.visual_cleanup_by_tick or {}
end

local function message(player, key, ...)
  if player and player.valid then
    player.print({"interplanetary-artillery." .. key, ...})
  end
end

local function source(player, cannon_id)
  local cannon = cannon_id and storage.cannons[cannon_id]
  if not cannon or not cannon.entity or not cannon.entity.valid then return nil, "invalid-cannon" end
  local foundation = storage.foundations[cannon.foundation_unit_number]
  if not foundation or not foundation.entity or not foundation.entity.valid then return nil, "invalid-attachment" end
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

local function launch(cannon_id, foundation, cannon, surface, position, trajectory, player_index)
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
    player_index = player_index,
    fire_tick = game.tick,
    impact_tick = game.tick + trajectory.flight_ticks,
  }
  for key, value in pairs(trajectory) do shot[key] = value end
  foundation.loaded_shots = foundation.loaded_shots - 1
  resume_production(foundation)
  storage.next_shot_id = id + 1
  storage.in_flight_shots[id] = shot
  local bucket = storage.shots_by_tick[shot.impact_tick] or {}
  bucket[#bucket + 1] = id
  storage.shots_by_tick[shot.impact_tick] = bucket
  countdown.update(shot, game.tick)
  visuals.launch(shot)
  message(game.get_player(player_index), "shot-fired-eta", {"interplanetary-artillery." .. shot.flight_type},
    string.format("%.1f", shot.flight_ticks / 60))
  return id
end

local function aim_cancelled(aim)
  message(game.get_player(aim.player_index), "aim-cancelled", aim.cannon_unit_number)
end

function firing.cancel_aim(id)
  local aim = aiming.cancel(id)
  if aim then aim_cancelled(aim) end
end

local function validate_aim(aim)
  local force = game.forces[aim.source_force_index]
  local surface = game.surfaces[aim.target_surface_index]
  if not force or not surface or not surface.valid then return end
  local foundation, cannon = source({force = force}, aim.cannon_unit_number)
  if not foundation or cannon.foundation_unit_number ~= aim.foundation_unit_number then return end
  local entity = cannon.entity
  if entity.surface.index ~= aim.source_surface_index
    or entity.position.x ~= aim.source_position.x or entity.position.y ~= aim.source_position.y then return end
  return cannon, foundation, surface
end

local function fire_aim(aim)
  local cannon, foundation, surface = validate_aim(aim)
  if not cannon or (foundation.loaded_shots or 0) < 1 then return end
  local position = aim.target_position
  if not valid_position(surface, position) or not impact_chunks_generated(surface, position) then return end
  local trajectory = flight.calculate(cannon.entity.surface, cannon.entity.position, surface, position)
  if not trajectory or trajectory.flight_type ~= aim.flight_type then return end
  return launch(aim.cannon_unit_number, foundation, cannon, surface, position, trajectory, aim.player_index)
end

-- Target requests reserve one Cannon. Only fire_aim creates an in-flight shot.
function firing.fire(player, cannon_id, surface, position)
  firing.init()
  local foundation, cannon = source(player, cannon_id)
  if not foundation then message(player, cannon); return nil end
  if not aiming.is_ready(cannon_id) then message(player, "cannon-busy"); return nil end
  if not surface or not surface.valid then message(player, "invalid-surface"); return nil end
  if not valid_position(surface, position) then message(player, "invalid-target"); return nil end
  if not impact_chunks_generated(surface, position) then message(player, "ungenerated-target"); return nil end
  if (foundation.loaded_shots or 0) < 1 then message(player, "no-loaded-shots"); return nil end
  local trajectory = flight.calculate(cannon.entity.surface, cannon.entity.position, surface, position)
  if not trajectory then message(player, "no-route"); return nil end
  cannon_visuals.ensure(cannon)
  local source_position = cannon.entity.position
  local reservation = {
    foundation_unit_number = cannon.foundation_unit_number,
    source_force_index = cannon.entity.force.index,
    source_surface_index = cannon.entity.surface.index,
    source_position = {x = source_position.x, y = source_position.y},
    target_surface_index = surface.index,
    target_position = {x = position.x, y = position.y},
    target_direction_index = cannon_visuals.target_direction(source_position, position, cannon.visual.direction_index),
    target_elevation_index = cannon_visuals.elevation(trajectory),
    flight_type = trajectory.flight_type,
    player_index = player.index,
  }
  local receipt = aiming.start(cannon_id, cannon, reservation, game.tick)
  if receipt then message(player, "aim-started", cannon_id) end
  return receipt
end

function firing.fire_auto(player, surface, position)
  firing.init()
  if not surface or not surface.valid then message(player, "invalid-surface"); return nil end
  if not valid_position(surface, position) then message(player, "invalid-target"); return nil end
  if not impact_chunks_generated(surface, position) then message(player, "ungenerated-target"); return nil end
  local local_ids, remote_ids = {}, {}
  local ready_without_route = false
  for id in pairs(storage.cannons) do
    local foundation, cannon = source(player, id)
    if foundation and aiming.is_ready(id) and (foundation.loaded_shots or 0) >= 1 then
      if cannon.entity.surface.index == surface.index then
        local_ids[#local_ids + 1] = id
      elseif flight.calculate(cannon.entity.surface, cannon.entity.position, surface, position) then
        remote_ids[#remote_ids + 1] = id
      else
        ready_without_route = true
      end
    end
  end
  local ids = #local_ids > 0 and local_ids or remote_ids
  if #ids == 0 then
    message(player, ready_without_route and "no-route" or "no-ready-cannon")
    return nil
  end
  table.sort(ids)
  local key = surface.index .. (#local_ids > 0 and ":local" or ":remote")
  local rotations = storage.firing_round_robin[player.force.index] or {}
  local last, selected = rotations[key] or 0, ids[1]
  for _, id in ipairs(ids) do if id > last then selected = id; break end end
  local receipt = firing.fire(player, selected, surface, position)
  if receipt then
    rotations[key] = selected
    storage.firing_round_robin[player.force.index] = rotations
  end
  return receipt
end

function firing.cancel(id)
  local shot = storage.in_flight_shots[id]
  if not shot then return end
  countdown.remove(shot)
  visuals.remove(shot)
  storage.in_flight_shots[id] = nil
  message(game.get_player(shot.player_index), "shot-cancelled", id)
end

local function migrate_shots()
  firing.init()
  for _, shot in pairs(storage.in_flight_shots) do
    shot.flight_type = shot.flight_type or (shot.source_surface_index == shot.target_surface_index
      and "same-surface" or "interplanetary")
    shot.flight_ticks = shot.flight_ticks or shot.impact_tick - shot.fire_tick
    countdown.remove(shot)
    if shot.impact_tick ~= game.tick and not countdown.update(shot, game.tick) then firing.cancel(shot.id) end
  end
  storage.firing_schema = 1
end

local function impact(shot)
  local surface = game.surfaces[shot.target_surface_index]
  local force = game.forces[shot.source_force_index]
  local player = game.get_player(shot.player_index)
  if not surface or not force or not impact_chunks_generated(surface, shot.target_position) then
    message(player, "shot-cancelled", shot.id)
    return
  end
  visuals.impact(shot, surface, force)
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
  cannon_visuals.migrate()
  storage.visual_cleanup_by_tick = storage.visual_cleanup_by_tick or {}
  visuals.on_tick(event.tick)
  if storage.firing_schema ~= 1 then migrate_shots() end
  aiming.on_tick(event.tick, validate_aim, fire_aim, aim_cancelled)
  local bucket = storage.shots_by_tick and storage.shots_by_tick[event.tick]
  storage.shots_by_tick[event.tick] = nil
  for _, id in ipairs(bucket or {}) do
    local shot = storage.in_flight_shots[id]
    -- Remove before damage can raise other mods' handlers and cause reentry.
    storage.in_flight_shots[id] = nil
    if shot then countdown.remove(shot); visuals.remove(shot); impact(shot) end
  end
  local updates = storage.countdown_by_tick[event.tick]
  storage.countdown_by_tick[event.tick] = nil
  for id in pairs(updates or {}) do
    local shot = storage.in_flight_shots[id]
    if shot then
      shot.countdown_tick = nil
      if not countdown.update(shot, event.tick) then firing.cancel(id) end
    end
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
  firing.fire_auto(player, event.surface, {
    x = (area.left_top.x + area.right_bottom.x) / 2,
    y = (area.left_top.y + area.right_bottom.y) / 2,
  })
end

local function cancel_surface(event)
  for id, aim in pairs(storage.aiming_cannons or {}) do
    if aim.target_surface_index == event.surface_index or aim.source_surface_index == event.surface_index then
      firing.cancel_aim(id)
    end
  end
  visuals.clear_surface(event.surface_index)
  for id, shot in pairs(storage.in_flight_shots or {}) do
    if shot.target_surface_index == event.surface_index then
      firing.cancel(id)
    end
  end
  for _, rotations in pairs(storage.firing_round_robin or {}) do
    rotations[event.surface_index .. ":local"] = nil
    rotations[event.surface_index .. ":remote"] = nil
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
    storage.firing_round_robin = {}
    for _, aim in pairs(storage.aiming_cannons or {}) do
      if aim.source_force_index == event.source.index then aim.source_force_index = event.destination.index end
    end
    for _, shot in pairs(storage.in_flight_shots or {}) do
      if shot.source_force_index == event.source.index then
        shot.source_force_index = event.destination.index
        if shot.countdown and shot.countdown.valid then shot.countdown.forces = {event.destination} end
        if shot.countdown_map and shot.countdown_map.valid then shot.countdown_map.forces = {event.destination} end
      end
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
