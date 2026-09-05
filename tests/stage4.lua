local firing = require("scripts.firing")
local tick_handler = script.get_event_handler(defines.events.on_tick)
local first_tick = true
local target = {x = 10032, y = 10032}
local F = "interplanetary-artillery-foundation"
local C = "interplanetary-artillery-cannon"

local function check(value, label)
  assert(value, "STAGE4 FAIL: " .. label)
  log("STAGE4 PASS: " .. label)
end

local function player()
  -- No connected LuaPlayer in headless. The production firing entry is used
  -- with a caller adapter; entity/planet/generation/tick/save APIs are real.
  return {index = 1, valid = true, force = game.forces.player, print = function(value) log(serpent.line(value)) end}
end

local function generate(surface, position, radius)
  surface.request_to_generate_chunks(position, radius or 0)
  surface.force_generate_chunk_requests() -- Test fixture only, never firing.
end

local function installation(surface, x)
  generate(surface, {x, 0}, 1)
  local area = {{x - 9, -9}, {x + 9, 9}}
  for _, entity in pairs(surface.find_entities_filtered{area = area}) do entity.destroy() end
  local tiles = {}
  for tx = x - 8, x + 8 do
    for ty = -8, 8 do
      tiles[#tiles + 1] = {name = "interplanetary-artillery-foundation-tile", position = {tx, ty}}
    end
  end
  surface.set_tiles(tiles)
  local f = surface.create_entity{name = F, position = {x + 0.5, 0.5}, force = "player", raise_built = true}
  local c = surface.create_entity{name = C, position = f.position, force = "player", raise_built = true}
  f.insert{name = "iron-plate", count = 200}
  return {foundation = f, cannon = c, foundation_id = f.unit_number, cannon_id = c.unit_number}
end

local function destination(surface)
  generate(surface, target)
  for _, e in pairs(surface.find_entities_filtered{area = {{target.x-8, target.y-8}, {target.x+8, target.y+8}}}) do
    e.destroy()
  end
  local tiles = {}
  for x = target.x-7, target.x+7 do
    for y = target.y-7, target.y+7 do tiles[#tiles+1] = {name = "refined-concrete", position = {x,y}} end
  end
  surface.set_tiles(tiles)
  local enemy = surface.create_entity{name = "steel-chest", position = target, force = "enemy"}
  local friendly = surface.create_entity{name = "steel-chest", position = {target.x+2, target.y}, force = "player"}
  check(not game.forces.player.is_chunk_charted(surface, {313,313}), "uncharted target " .. surface.name)
  return {surface = surface, enemy = enemy, health = enemy.health, friendly = friendly,
    friendly_health = friendly.health, expected_hits = 0}
end

local function setup()
  local t = {phase = "production", shots = {}, started = game.tick}
  storage.stage4_test = t
  local a, b
  if script.active_mods["space-age"] then
    local planet = game.planets.vulcanus
    check(planet.surface == nil, "unvisited Vulcanus initially has no surface")
    a = planet.create_surface()
    b = game.planets.gleba.create_surface()
    check(a.planet.name == "vulcanus" and b.planet.name == "gleba", "actual Space Age planet association")
    check(not game.forces.player.is_space_location_unlocked("vulcanus"), "surface creation does not unlock planet")
  else
    a = game.create_surface("stage4-target-a")
    b = game.create_surface("stage4-target-b")
  end
  t.targets = {destination(a), destination(b), destination(game.surfaces.nauvis)}
  t.delete_target = destination(game.create_surface("stage4-delete-target"))
  t.clear_target = destination(game.create_surface("stage4-clear-target"))
  t.source_to_delete = game.create_surface("stage4-source-to-delete")
  t.installations = {installation(game.surfaces.nauvis, 0), installation(game.surfaces.nauvis, 32),
    installation(t.source_to_delete, 0)}
  t.async_surface = game.create_surface("stage4-async-generation")
  t.async_surface.request_to_generate_chunks(target, 0)
  game.speed = 10
end

script.on_event(defines.events.on_chunk_generated, function(event)
  local t = storage.stage4_test
  if t and t.async_surface and event.surface.index == t.async_surface.index
    and event.position.x == 313 and event.position.y == 313 then
    t.async_ready_tick = event.tick
  end
end)

local function launch(t)
  local a, b, c = table.unpack(t.installations)
  local caller = player()
  local function fire(installation, dest)
    local record = storage.foundations[installation.foundation_id]
    local before = record.loaded_shots
    local source_surface = installation.cannon.surface.index
    local id = firing.fire(caller, installation.cannon_id, dest.surface, target)
    check(id and record.loaded_shots == before-1, "normal shot consumption " .. tostring(id))
    local shot = storage.in_flight_shots[id]
    local delay = source_surface == dest.surface.index and 300 or 900
    check(shot.target_surface_index == dest.surface.index and shot.source_surface_index == source_surface,
      "separate source and destination " .. id)
    check(shot.impact_tick == game.tick+delay and shot.source_force_index == caller.force.index,
      "deadline and attribution " .. id)
    return id, shot
  end
  local function keep(installation, dest)
    local id, shot = fire(installation, dest)
    t.shots[#t.shots+1] = {id = id, due = shot.impact_tick, surface_index = dest.surface.index}
    dest.expected_hits = dest.expected_hits+1
    dest.due = shot.impact_tick
  end
  local record = storage.foundations[a.foundation_id]
  check(not firing.fire(caller, a.cannon_id, nil, target), "missing target surface rejected")
  check(not firing.fire(caller, a.cannon_id, t.targets[1].surface, {x = 500016, y = 500016}), "ungenerated inter-surface rejected")
  check(record.loaded_shots == 2, "rejections leave ammunition intact")
  keep(a, t.targets[1])
  keep(a, t.targets[2])
  keep(b, t.targets[3])
  t.cancel_delete = fire(b, t.delete_target)
  keep(c, t.targets[1])
  t.cancel_clear = fire(c, t.clear_target)
  check(not firing.fire(caller, a.cannon_id, t.targets[2].surface, target), "third shot refused")
  a.foundation.insert{name = "iron-plate", count = 100}
  a.cannon.destroy{raise_destroy = true}
  b.foundation.destroy{raise_destroy = true}
  game.delete_surface(t.source_to_delete)
  game.delete_surface(t.delete_target.surface)
  t.clear_target.surface.clear()
  t.phase, t.fire_tick = "flight", game.tick
end

script.on_event(defines.events.on_tick, function(event)
  if not storage.stage4_test then setup() end
  local t = storage.stage4_test
  if first_tick and t.phase == "flight" then
    for _, expected in ipairs(t.shots) do
      local shot = storage.in_flight_shots[expected.id]
      check(shot and shot.target_surface_index == expected.surface_index and shot.impact_tick == expected.due
        and shot.target_position.x == target.x and shot.target_position.y == target.y,
        "reloaded destination/position/deadline " .. expected.id)
    end
    log("STAGE4 RELOAD CONFIRMED")
  end
  first_tick = false
  tick_handler(event)
  for _, i in ipairs(t.installations) do
    if i.foundation.valid then i.foundation.energy = 1000000 end
  end
  if t.phase == "production" then
    local ready = true
    for _, i in ipairs(t.installations) do
      ready = ready and storage.foundations[i.foundation_id].loaded_shots == 2
    end
    if ready then launch(t) end
    assert(event.tick-t.started < 2500, "Stage4 production timeout")
  elseif t.phase == "flight" then
    if event.tick == t.fire_tick+20 then
      check(not storage.in_flight_shots[t.cancel_delete], "target deletion cancels")
      check(not storage.in_flight_shots[t.cancel_clear], "target clear cancels")
      check(not t.source_to_delete.valid, "source surface deleted")
      for _, expected in ipairs(t.shots) do check(storage.in_flight_shots[expected.id], "shot independent of source " .. expected.id) end
    end
    if event.tick == t.fire_tick+100 then
      game.server_save("stage4-flight.zip")
      log("STAGE4 IN-FLIGHT SAVE REQUESTED")
    end
    for _, dest in ipairs(t.targets) do
      if event.tick < dest.due then
        assert(dest.enemy.valid and dest.enemy.health == dest.health, "Early or wrong-surface damage")
      elseif event.tick == dest.due then
        local expected_health = dest.health - 250*dest.expected_hits
        check(expected_health <= 0 and not dest.enemy.valid or
          dest.enemy.valid and math.abs(dest.enemy.health - expected_health) < 0.01,
          "exact impact damage on " .. dest.surface.name .. " actual=" .. tostring(dest.enemy.valid and dest.enemy.health))
        check(dest.friendly.valid and dest.friendly.health == dest.friendly_health, "friendly protected on " .. dest.surface.name)
        check(dest.surface.count_entities_filtered{name = "big-explosion", position = target, radius = 1} > 0,
          "explosion at correct surface and position " .. dest.surface.name)
        check(not game.forces.player.is_chunk_charted(dest.surface, {313,313}), "impact does not reveal " .. dest.surface.name)
      end
    end
    if event.tick >= t.fire_tick+1000 then
      check(t.async_ready_tick and t.async_surface.is_chunk_generated({313,313}),
        "request-only chunk generation completed at tick " .. tostring(t.async_ready_tick))
      check(next(storage.in_flight_shots) == nil and next(storage.shots_by_tick) == nil, "all shots and buckets cleaned")
      check(storage.foundations[t.installations[1].foundation_id].loaded_shots >= 1, "production resumes after inter-surface fire")
      log("STAGE4 ALL PASSED")
      t.phase = "done"
    end
  end
end)
