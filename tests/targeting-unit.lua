-- Handler routing tests only: these do not simulate the Factorio remote UI.
local handlers, command_handlers = {}, {}
defines = {events = setmetatable({}, {__index = function(_, key) return key end})}
script = {on_event = function(key, handler) handlers[key] = handler end}
commands = {add_command = function(name, _, handler) command_handlers[name] = handler end}
storage = {foundations = {}, cannons = {}}
local source_surface, target_surface = {index = 1}, {index = 2}
local force = {index = 1}
local players = {}
for index = 1, 2 do
  local cannon = {valid = true, name = "interplanetary-artillery-cannon", unit_number = index,
    surface = source_surface, position = {x = index, y = 0}, force = force}
  storage.cannons[index] = {entity = cannon, foundation_unit_number = index}
  storage.foundations[index] = {entity = cannon, cannon_unit_number = index, loaded_shots = 2}
  players[index] = {valid = true, index = index, selected = cannon, force = force,
    surface = source_surface, physical_surface = source_surface, print = function() end,
    clear_cursor = function() return true end, cursor_stack = {set_stack = function() return true end}}
end
game = {get_player = function(index) return players[index] end,
  get_surface = function(id)
    if id == "vulcanus" or id == "test world" or id == 2 then return target_surface end
  end}
local firing = require("scripts.firing")
firing.register(function() end)
handlers["interplanetary-artillery-aim"]{player_index = 1}
handlers["interplanetary-artillery-aim"]{player_index = 2}
assert(storage.player_cannon_targets[1] == 1 and storage.player_cannon_targets[2] == 2)
players[1].selected = nil
players[1].surface = target_surface
handlers["interplanetary-artillery-aim"]{player_index = 1}
assert(storage.player_cannon_targets[1] == 1)
assert(not handlers.on_player_cursor_stack_changed)
local calls = {}
local real_fire = firing.fire
firing.fire = function(player, id, surface, position)
  calls[#calls+1] = {player = player.index, id = id, surface = surface, position = position}
end
players[1].surface = source_surface
handlers.on_player_selected_area{player_index = 1, item = "interplanetary-artillery-targeting-remote",
  surface = target_surface, area = {left_top = {x = 10, y = 20}, right_bottom = {x = 12, y = 22}}}
assert(calls[1].id == 1 and calls[1].surface == target_surface and calls[1].position.x == 11)
local command = command_handlers["monolith-fire-surface-test"]
for _, parameter in ipairs({'vulcanus 30 40', '2 30 40', '"test world" 30 40', 'test world 30 40'}) do
  command{player_index = 1, parameter = parameter}
  local call = calls[#calls]
  assert(call.id == 1 and call.surface == target_surface and call.position.y == 40)
end
assert(#calls == 5)
command{player_index = 1, parameter = "vulcanus invalid 40"}
assert(#calls == 5)
command{player_index = 1, parameter = "missing 30 40"}
assert(#calls == 6 and calls[6].surface == nil)
assert(not handlers["interplanetary-artillery-cancel-aim"])
assert(storage.player_cannon_targets[1] == 1 and storage.player_cannon_targets[2] == 2)
-- Exercise the real validation, ammunition and scheduling path from the event.
firing.fire = real_fire
game.tick = 100
target_surface.valid = true
target_surface.name = "test target"
target_surface.map_gen_settings = {}
target_surface.is_chunk_generated = function() return true end
local target_event = {player_index = 1, item = "interplanetary-artillery-targeting-remote",
  surface = target_surface, area = {left_top = {x = 10, y = 20}, right_bottom = {x = 12, y = 22}}}
handlers.on_player_selected_area(target_event)
local shot = storage.in_flight_shots[1]
assert(shot.source_surface_index == 1 and shot.target_surface_index == 2)
assert(shot.target_position.x == 11 and shot.target_position.y == 21)
assert(shot.impact_tick == 1000 and storage.foundations[1].loaded_shots == 1)
handlers.on_player_alt_selected_area(target_event)
assert(storage.foundations[1].loaded_shots == 0 and storage.next_shot_id == 3)
handlers.on_player_selected_area(target_event)
assert(storage.next_shot_id == 3)
storage.foundations[1].loaded_shots = 1
players[1].force = {index = 9}
handlers.on_player_selected_area(target_event)
assert(storage.foundations[1].loaded_shots == 1 and storage.next_shot_id == 3)
players[1].force = force
storage.cannons[1].entity.valid = false
handlers.on_player_selected_area(target_event)
assert(storage.foundations[1].loaded_shots == 1 and storage.next_shot_id == 3)
target_event.item = "artillery-targeting-remote"
handlers.on_player_selected_area(target_event)
assert(storage.next_shot_id == 3)
-- Explicit registration also rejects wrong-force and destroyed Cannons.
storage.player_cannon_targets[2] = nil
players[2].force = {index = 9}
players[2].clear_cursor = function() error("wrong-force source was accepted") end
handlers["interplanetary-artillery-aim"]{player_index = 2}
assert(storage.player_cannon_targets[2] == nil)
storage.cannons[2].entity.valid = false
handlers["interplanetary-artillery-aim"]{player_index = 2}
assert(storage.player_cannon_targets[2] == nil)
print("TARGETING UNIT ALL PASSED")
