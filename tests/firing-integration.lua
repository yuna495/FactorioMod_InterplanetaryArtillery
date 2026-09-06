local firing = require("scripts.firing")
local flight = require("scripts.flight")
local production_tick = script.get_event_handler(defines.events.on_tick)
local first_tick = true
local function check(v,label) assert(v,label); log("STAGE6 PASS: "..label) end
local function caller() return {valid=true,index=1,force=game.forces.player,print=function() end} end
local function generate(s,p)
  s.request_to_generate_chunks(p,1)
  s.force_generate_chunk_requests()
end
local function pair(s,x)
  generate(s,{x,0})
  local tiles={}
  for a=x-8,x+8 do for b=-8,8 do tiles[#tiles+1]={name="interplanetary-artillery-foundation-tile",position={a,b}} end end
  s.set_tiles(tiles)
  local f=s.create_entity{name="interplanetary-artillery-foundation",position={x+0.5,0.5},force="player",raise_built=true}
  local c=s.create_entity{name="interplanetary-artillery-cannon",position=f.position,force="player",raise_built=true}
  f.insert{name="iron-plate",count=200}
  return {foundation=f,cannon=c,id=c.unit_number,record_id=f.unit_number}
end
script.on_event(defines.events.on_tick,function(event)
  production_tick(event)
  local t=storage.firing_test
  if not t then
    local s=game.surfaces.nauvis
    local target={x=6000.5,y=0.5}
    generate(s,target)
    local enemy=s.create_entity{name="steel-chest",position=target,force="enemy"}
    t={a=pair(s,0),b=pair(s,32),target=target,surface=s,phase="produce"}
    t.enemy=enemy; t.enemy_health=enemy.health
    storage.firing_test=t
    game.speed=10
    t.editor=game.create_surface("firing-non-planet")
    generate(t.editor,{0,0})
    if game.planets.vulcanus then
      t.planet=game.planets.vulcanus.create_surface()
      generate(t.planet,target)
      check(flight.route_distance("nauvis","aquilo")==45000,"real multi-hop connection distance")
    end
  elseif first_tick and t.phase=="flight" then
    check(storage.in_flight_shots[t.shot].countdown.valid and storage.in_flight_shots[t.shot].countdown_map.valid,"render objects survive reload")
    check(storage.in_flight_shots[t.shot].impact_tick==t.due,"deadline survives reload")
    log("STAGE6 RELOAD CONFIRMED")
  end
  first_tick=false
  for _,p in ipairs({t.a,t.b}) do p.foundation.energy=1000000 end
  local a,b=storage.foundations[t.a.record_id],storage.foundations[t.b.record_id]
  if t.phase=="produce" and a.loaded_shots==2 and b.loaded_shots==2 then
    check(not firing.fire(caller(),t.a.id,t.editor,{x=0,y=0}),"non-planet cross-surface refused")
    local id=firing.fire_auto(caller(),t.surface,t.target)
    local shot=storage.in_flight_shots[id]
    check(shot.cannon_unit_number==t.a.id and shot.flight_ticks==1200,"auto source and 300 tiles/s")
    check(shot.countdown.valid and shot.countdown_map.valid,"game and chart rendering created")
    check(shot.countdown_tick==game.tick+60,"long countdown schedule")
    local second=firing.fire_auto(caller(),t.surface,t.target)
    check(storage.in_flight_shots[second].cannon_unit_number==t.b.id,"round robin")
    local cancel=storage.in_flight_shots[second]
    local object=cancel.countdown
    firing.cancel(second)
    check(not object.valid and not cancel.countdown_tick,"cancel rendering cleanup")
    if t.planet then
      local inter=firing.fire_auto(caller(),t.planet,t.target)
      local p=storage.in_flight_shots[inter]
      check(p.flight_type=="interplanetary" and p.route_distance_km==15000 and p.flight_ticks==1800,"real 500 km/s planetary shot")
      t.inter=inter
    end
    check(t.a.foundation.insert{name="iron-plate",count=200}==200,"resumed recipe accepts materials A")
    check(t.b.foundation.insert{name="iron-plate",count=200}==200,"resumed recipe accepts materials B")
    t.a.cannon.destroy{raise_destroy=true}
    t.shot=id; t.due=shot.impact_tick; t.render=shot.countdown; t.phase="flight"
    game.server_save("stage6-flight.zip")
  elseif t.phase=="flight" then
    local shot=storage.in_flight_shots[t.shot]
    if shot and game.tick==t.due-594 then
      check(shot.countdown.text[2]=="9.9" and shot.countdown_tick==game.tick+6,"short countdown update")
    end
    if game.tick>=t.due and (not t.inter or not storage.in_flight_shots[t.inter]) then
      check(not storage.in_flight_shots[t.shot] and not t.render.valid,"impact and render cleanup")
      check(not t.enemy.valid or t.enemy.health<t.enemy_health,"target damaged after source removal")
      check(a.loaded_shots>=1 and b.loaded_shots==2,"production resumed")
      check(not next(storage.countdown_by_tick),"countdown schedule drained")
      log("STAGE6 ALL PASSED")
      t.phase="done"
    end
  end
end)
