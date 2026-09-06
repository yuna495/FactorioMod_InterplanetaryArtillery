local handlers, command_handlers = {}, {}
defines = {events = setmetatable({}, {__index = function(_, k) return k end})}
script = {on_event = function(k, v) handlers[k] = v end}
commands = {add_command = function(name, _, handler) command_handlers[name] = handler end}
storage = {foundations = {}, cannons = {}}
local notices = {}
rendering = {draw_text = function(args)
  args.valid = true
  args.destroy = function() args.valid = false end
  return args
end}
local function surface(index, planet)
  return {index = index, name = tostring(index), valid = true,
    planet = planet and {name = planet, valid = true}, map_gen_settings = {},
    is_chunk_generated = function() return true end,
    create_entity = function() end, find_entities_filtered = function() return {} end}
end
local a,b,c,editor = surface(1,"a"),surface(2,"b"),surface(3,"c"),surface(4)
local force = {index = 1, chart = function() end}
local player = {valid = true, index = 1, force = force, surface = editor,
  print = function(v) notices[#notices + 1] = v end}
game = {tick = 0, surfaces = {a,b,c,editor}, forces = {force}, get_player = function() return player end}
local function edge(a,b,n) return {from={name=a},to={name=b},length=n} end
prototypes = {space_connection={edge("a","b",15000),edge("b","c",30000),edge("a","c",90000)}}
local flight = require("scripts.flight")
assert(flight.route_distance("a","c")==45000 and flight.route_distance("c","a")==45000)
assert(not flight.route_distance("a","missing"))
assert(flight.calculate(a,{x=0,y=0},c,{x=0,y=0}).flight_ticks==5400)
assert(not flight.calculate(a,{x=0,y=0},editor,{x=0,y=0}))
assert(flight.calculate(editor,{x=0,y=0},editor,{x=300,y=400}).flight_ticks==100)
assert(flight.calculate(a,{x=0,y=0},a,{x=1,y=0}).flight_ticks==6)
local resumes = 0
local firing = require("scripts.firing")
firing.register(function() resumes = resumes + 1 end)
firing.init()
handlers.on_tick{tick=0}
local function cannon(id,s)
  local e={valid=true,name="interplanetary-artillery-cannon",surface=s,position={x=0,y=0},force=force}
  storage.cannons[id]={entity=e,foundation_unit_number=id}
  storage.foundations[id]={entity=e,cannon_unit_number=id,loaded_shots=2}
end
cannon(1,a); cannon(2,a); cannon(3,a); cannon(4,b)
local event={item="interplanetary-artillery-targeting-remote",player_index=1,surface=a,
  area={left_top={x=6000,y=0},right_bottom={x=6000,y=0}}}
for i,expected in ipairs({1,2,3,1,2,3,4,4}) do
  player.index=i%2+1 -- Players on the same force share deterministic rotation.
  handlers.on_player_selected_area(event)
  local shot=storage.in_flight_shots[i]
  assert(shot.cannon_unit_number==expected)
  assert(shot.flight_type==(expected==4 and "interplanetary" or "same-surface"))
  assert(shot.flight_ticks==(expected==4 and 1800 or 1200))
  assert(shot.countdown.valid and shot.countdown_map.valid)
end
assert(resumes==8 and not next(storage.player_cannon_targets))
handlers.on_player_selected_area(event)
assert(storage.next_shot_id==9 and notices[#notices][1]=="interplanetary-artillery.no-ready-cannon")
storage.foundations[2].loaded_shots=1
handlers.on_player_selected_area(event)
assert(storage.in_flight_shots[9].cannon_unit_number==2)
storage.foundations[1].loaded_shots=1
storage.cannons[1].entity.valid=false
assert(not firing.fire_auto(player,a,{x=6000,y=0}))
storage.cannons[1].entity.valid=true
assert(not firing.fire_auto(player,editor,{x=0,y=0}))
assert(storage.foundations[1].loaded_shots==1)
local connections=prototypes.space_connection
prototypes.space_connection={}
assert(not firing.fire_auto(player,c,{x=0,y=0}))
assert(storage.foundations[1].loaded_shots==1)
prototypes.space_connection=connections
player.force={index=2}
assert(not firing.fire_auto(player,a,{x=6000,y=0}))
player.force=force
local entity=storage.foundations[1].entity
storage.foundations[1].entity={valid=false}
assert(not firing.fire_auto(player,a,{x=6000,y=0}))
storage.foundations[1].entity=entity
assert(notices[1][1]=="interplanetary-artillery.shot-fired-eta")
local shot=storage.in_flight_shots[1]
assert(shot.countdown_tick==60)
for tick=1,600 do game.tick=tick; handlers.on_tick{tick=tick} end
assert(shot.countdown.text[2]=="10" and shot.countdown_tick==606)
for tick=601,606 do game.tick=tick; handlers.on_tick{tick=tick} end
assert(shot.countdown.text[2]=="9.9" and shot.countdown_tick==612)
local obj=shot.countdown
firing.cancel(1)
assert(not obj.valid and not storage.in_flight_shots[1])
local other=storage.in_flight_shots[2].countdown
for tick=607,1800 do game.tick=tick; handlers.on_tick{tick=tick} end
assert(not other.valid and not next(storage.in_flight_shots) and not next(storage.countdown_by_tick))
storage.foundations[1].loaded_shots=2
local deleted=firing.fire_auto(player,a,{x=6000,y=0})
local deleted_render=storage.in_flight_shots[deleted].countdown
handlers.on_pre_surface_deleted{surface_index=1}
assert(not deleted_render.valid and not next(storage.countdown_by_tick))
local cleared=firing.fire_auto(player,a,{x=6000,y=0})
local cleared_render=storage.in_flight_shots[cleared].countdown_map
handlers.on_pre_surface_cleared{surface_index=1}
assert(not cleared_render.valid and not next(storage.countdown_by_tick))
-- Upgrade a legacy shot without changing its accepted deadline or requiring its source.
storage.in_flight_shots[99]={id=99,source_surface_index=4,target_surface_index=1,
  source_force_index=1,target_position={x=6000,y=0},fire_tick=1700,impact_tick=1900,player_index=1}
storage.shots_by_tick[1900]={99}
storage.firing_schema=nil
game.tick=1801; handlers.on_tick{tick=1801}
assert(storage.in_flight_shots[99].flight_type=="interplanetary")
assert(storage.in_flight_shots[99].flight_ticks==200 and storage.in_flight_shots[99].countdown.valid)
for tick=1802,1900 do game.tick=tick; handlers.on_tick{tick=tick} end
assert(not next(storage.in_flight_shots) and not next(storage.countdown_by_tick))
-- Explicit debug commands retain the same parser and source isolation.
local real_fire=firing.fire
local calls={}
firing.fire=function(p,id,s,pos) calls[#calls+1]={id=id,surface=s,position=pos} end
player.index=1
storage.player_cannon_targets[1]=42
game.get_surface=function(name)
  if name=="test world" or name==2 then return b end
end
for _,parameter in ipairs({'"test world" 30 40','test world 30 40','2 30 40'}) do
  command_handlers["monolith-fire-surface-test"]{player_index=1,parameter=parameter}
  local call=calls[#calls]
  assert(call.id==42 and call.surface==b and call.position.y==40)
end
command_handlers["monolith-fire-surface-test"]{player_index=1,parameter="test world invalid 40"}
assert(#calls==3)
firing.fire=real_fire
print("AUTO FIRING UNIT ALL PASSED")
