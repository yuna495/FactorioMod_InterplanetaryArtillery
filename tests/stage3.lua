local firing = require("scripts.firing")
local tick_handler = script.get_event_handler(defines.events.on_tick)
local first_tick = true
local F = "interplanetary-artillery-foundation"
local C = "interplanetary-artillery-cannon"
local T = "interplanetary-artillery-foundation-tile"
local target = {x = 10016, y = 10016}

-- Headless servers have no connected LuaPlayer. Only the caller adapter is
-- synthetic; all entities, recipes, surfaces, ticks, damage and saves are real.
local function test_player()
  return {valid = true, index = 1, force = game.forces.player, print = function() end}
end

local function check(condition, label)
  assert(condition, "STAGE3 FAIL: " .. label)
  log("STAGE3 PASS: " .. label)
end

local function pair(surface, x)
  local tiles = {}
  for tx = x - 8, x + 8 do
    for ty = -8, 8 do tiles[#tiles + 1] = {name = T, position = {tx, ty}} end
  end
  surface.set_tiles(tiles)
  check(surface.can_place_entity{name = F, position = {x + 0.5, 0.5}, force = "player"}, "tile placement allowed")
  local f = surface.create_entity{name = F, position = {x + 0.5, 0.5}, force = "player", raise_built = true}
  local c = surface.create_entity{name = C, position = f.position, force = "player", raise_built = true}
  check(storage.foundations[f.unit_number].cannon_unit_number == c.unit_number, "reciprocal attachment")
  f.insert{name = "iron-plate", count = 200}
  return {foundation = f, cannon = c, foundation_id = f.unit_number, cannon_id = c.unit_number}
end

local function setup()
  local s = game.create_surface("stage3-test", {autoplace_controls = {}, autoplace_settings = {
    entity = {treat_missing_as_default = false}, decorative = {treat_missing_as_default = false},
  }})
  s.generate_with_lab_tiles = true
  s.request_to_generate_chunks({0, 0}, 3)
  s.request_to_generate_chunks(target, 0)
  s.force_generate_chunk_requests()
  local player = test_player()
  local test = {surface = s, phase = "production", start_tick = game.tick}
  storage.stage3_test = test
  check(not s.can_place_entity{name = F, position = {64.5, 0.5}, force = "player"}, "missing foundation tile rejected")
  test.a = pair(s, 0)
  test.b = pair(s, 32)
  test.c = pair(s, 64)
  check(not firing.fire(player, test.a.cannon_id, s, target), "empty magazine rejected")
  local ally = game.create_force("stage3-ally")
  player.force.set_friend(ally, true)
  local cease = game.create_force("stage3-cease")
  player.force.set_cease_fire(cease, true)
  test.protected = {}
  for i, force in ipairs({player.force, game.forces.neutral, ally, cease}) do
    local entity = s.create_entity{name = "steel-chest", position = {target.x + i - 2, target.y + 2}, force = force}
    test.protected[#test.protected + 1] = {entity = entity, health = entity.health}
  end
  test.enemy = s.create_entity{name = "steel-chest", position = target, force = "enemy"}
  test.enemy_health = test.enemy.health
  check(not player.force.is_chunk_charted(s, {313, 313}), "distant target generated but uncharted")
  game.speed = 10
end

local function launch(test)
  local player, s, a, b = test_player(), test.surface, test.a, test.b
  local record = storage.foundations[a.foundation_id]
  check(record.loaded_shots == 2 and not a.foundation.get_recipe(), "actual production capped and stopped at two")
  check(not firing.fire(player, a.cannon_id, game.surfaces.nauvis, target), "cross-surface rejected")
  check(not firing.fire(player, a.cannon_id, s, {x = 500016, y = 500016}), "ungenerated target rejected")
  check(not firing.fire(player, a.cannon_id, s, {x = 0/0, y = 0}), "NaN rejected")
  check(not firing.fire(player, a.cannon_id, s, {x = math.huge, y = 0}), "infinity rejected")
  check(not firing.fire(player, a.cannon_id, s, {x = 1000000, y = 0}), "map boundary rejected")
  check(not firing.fire(player, b.cannon_id + 100000, s, target), "missing cannon rejected")
  local previous_force = b.cannon.force
  b.cannon.force = "enemy"
  check(not firing.fire(player, b.cannon_id, s, target), "force mismatch rejected")
  b.cannon.force = previous_force
  check(record.loaded_shots == 2, "invalid requests do not consume ammunition")

  local first = firing.fire(player, a.cannon_id, s, target)
  check(first and record.loaded_shots == 1, "accepted fire consumes exactly one shot")
  local second = firing.fire(player, a.cannon_id, s, target)
  check(second and record.loaded_shots == 0, "second shot accepted")
  check(not firing.fire(player, a.cannon_id, s, target), "third shot refused")
  check(a.foundation.get_recipe() and storage.active_foundations[a.foundation_id], "production resumed")
  a.foundation.insert{name = "iron-plate", count = 100}
  local third = firing.fire(player, b.cannon_id, s, target)
  check(third ~= nil, "second installation fires independently")
  a.cannon.destroy{raise_destroy = true}
  b.foundation.destroy{raise_destroy = true}
  check(a.foundation.valid and not b.cannon.valid, "cannon-only and foundation cleanup preserved")
  check(storage.in_flight_shots[first] and storage.in_flight_shots[third], "shots survive both source removal paths")
  test.ids = {first, second, third}
  test.impact_tick = game.tick + 300
  test.phase = "flight"
  test.saved = false
end

script.on_event(defines.events.on_tick, function(event)
  if not storage.stage3_test then setup() end
  local test = storage.stage3_test
  if first_tick and test.phase == "flight" then
    for _, id in ipairs(test.ids) do
      check(storage.in_flight_shots[id].impact_tick == test.impact_tick, "reloaded shot preserves deadline " .. id)
    end
    check(storage.foundations[test.c.foundation_id].cannon_unit_number == test.c.cannon_id
      and storage.cannons[test.c.cannon_id].foundation_unit_number == test.c.foundation_id,
      "live attachment survives reload")
    log("STAGE3 RELOAD CONFIRMED")
  end
  first_tick = false
  tick_handler(event)
  for _, installation in ipairs({test.a, test.b}) do
    if installation.foundation.valid then installation.foundation.energy = 1000000 end
  end
  if test.phase == "production" then
    if storage.foundations[test.a.foundation_id].loaded_shots == 2
      and storage.foundations[test.b.foundation_id].loaded_shots == 2 then launch(test) end
    assert(event.tick - test.start_tick < 2500, "Production timed out")
  elseif test.phase == "flight" then
    if not test.saved and event.tick == test.impact_tick - 200 then
      test.saved = true
      game.server_save("stage3-flight.zip")
      log("STAGE3 IN-FLIGHT SAVE REQUESTED")
    end
    if event.tick < test.impact_tick then
      assert(test.enemy.valid and test.enemy.health == test.enemy_health, "Impact occurred early")
    elseif event.tick == test.impact_tick then
      check(not test.enemy.valid, "enemy receives scheduled area damage")
      for _, protected in ipairs(test.protected) do
        check(protected.entity.valid and protected.entity.health == protected.health, "friendly/neutral/cease-fire protected")
      end
      for _, id in ipairs(test.ids) do check(not storage.in_flight_shots[id], "resolved shot removed " .. id) end
      check(test.surface.count_entities_filtered{name = "big-explosion", position = target, radius = 1} > 0, "explosion created at target")
      check(not game.forces.player.is_chunk_charted(test.surface, {313, 313}), "impact does not chart target")
      test.phase = "resume"
    end
  elseif test.phase == "resume" then
    if storage.foundations[test.a.foundation_id].loaded_shots >= 1 then
      check(true, "actual ammunition production after firing")
      log("STAGE3 ALL PASSED")
      test.phase = "done"
    end
  end
end)
