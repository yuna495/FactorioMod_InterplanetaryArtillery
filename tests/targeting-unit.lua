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
firing.fire = function(player, id, surface, position)
  calls[#calls+1] = {player = player.index, id = id, surface = surface, position = position}
end
handlers.on_player_selected_area{player_index = 1, item = "interplanetary-artillery-target",
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
handlers["interplanetary-artillery-cancel-aim"]{player_index = 1}
assert(storage.player_cannon_targets[1] == nil and storage.player_cannon_targets[2] == 2)
-- Retained sources are revalidated before rearming, including force changes.
players[2].selected = nil
players[2].force = {index = 9}
players[2].clear_cursor = function() error("wrong-force source was accepted") end
handlers["interplanetary-artillery-aim"]{player_index = 2}
storage.cannons[2].entity.valid = false
handlers["interplanetary-artillery-aim"]{player_index = 2}
print("TARGETING UNIT ALL PASSED")
