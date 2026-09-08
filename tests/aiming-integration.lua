local firing=require('scripts.firing')
local visuals=require('scripts.cannon-visuals')
local old_tick=script.get_event_handler(defines.events.on_tick)
local first=true
local function check(v,label) assert(v,label);log('STAGE9 PASS: '..label) end
local function generate(s,pos)
  s.request_to_generate_chunks(pos,1);s.force_generate_chunk_requests()
end
local function point(c,d,r)
  return {x=c.entity.position.x-math.sin(d*math.pi/12)*r,y=c.entity.position.y-math.cos(d*math.pi/12)*r}
end
local function player() return {index=1,valid=true,force=game.forces.player,print=function() end} end
local function setup()
  local s=game.surfaces.nauvis
  local t={ids={},foundation_ids={}}
  for i=1,4 do
    local pos={x=(i-1)*80+.5,y=.5};generate(s,pos)
    local tiles={}
    for x=math.floor(pos.x)-7,math.floor(pos.x)+7 do for y=-7,7 do
      tiles[#tiles+1]={name='interplanetary-artillery-foundation-tile',position={x,y}}
    end end
    s.set_tiles(tiles)
    local f=s.create_entity{name='interplanetary-artillery-foundation',position=pos,force='player',raise_built=true}
    local c=s.create_entity{name='interplanetary-artillery-cannon',position=pos,force='player',raise_built=true}
    t.ids[i]=c.unit_number;t.foundation_ids[i]=f.unit_number
    storage.foundations[f.unit_number].loaded_shots=i==1 and 2 or 1
  end
  local a=storage.cannons[t.ids[1]];a.visual.direction_index=1;visuals.ensure(a)
  for i,params in ipairs({{19,6010},{0,3000},{0,100}}) do
    local record=storage.cannons[t.ids[i]];local target=point(record,params[1],params[2]);generate(s,target)
    check(firing.fire_auto(player(),s,target)==t.ids[i],'automatic ready selection '..i)
  end
  local c4=storage.cannons[t.ids[4]];local p=point(c4,0,6010);generate(s,p)
  firing.fire(player(),t.ids[4],s,p)
  check(not firing.fire_auto(player(),s,p),'all busy Cannons excluded')
  check(storage.next_shot_id==1 and not next(storage.in_flight_shots),'no shot or ammo consumption on reservation')
  if game.planets.vulcanus then
    t.planet=game.planets.vulcanus.create_surface()
    t.remote_target=point(a,19,6010);generate(t.planet,t.remote_target)
  end
  storage.aiming_test=t;game.speed=20
end
script.on_event(defines.events.on_tick,function(event)
  old_tick(event)
  if first then
    first=false
    if not storage.aiming_test then setup() else
      local t=storage.aiming_test;t.reloaded=true
      for i,phase in ipairs({'TRAVERSING','ELEVATING','SETTLING'}) do
        local aim=storage.aiming_cannons[t.ids[i]]
        check(aim and aim.aim_state==phase,'reload phase '..phase)
        check(storage.aim_actions_by_tick[aim.next_aim_tick][t.ids[i]]==aim,'reload bucket identity '..phase)
        check(storage.cannons[t.ids[i]].visual.render.valid,'reload render '..phase)
      end
      log('STAGE9 RELOAD CONFIRMED')
    end
  end
  local t=storage.aiming_test;local tick=event.tick
  local a=storage.cannons[t.ids[1]];local b=storage.cannons[t.ids[2]]
  if tick==12 then check(a.visual.direction_index==0,'shortest path first step 01 to 00') end
  if tick==24 then check(a.visual.direction_index==23,'wrap 00 to 23') end
  if tick==30 then check(b.visual.elevation_index==1,'elevation single step') end
  if tick==45 and not t.reloaded then
    check(not next(storage.in_flight_shots) and storage.foundations[t.foundation_ids[1]].loaded_shots==2,'no pre-fire flight or ammo loss')
    game.server_save('stage9-flight.zip')
  end
  if tick==50 then
    local record=storage.cannons[t.ids[4]];record.entity.destroy{raise_destroy=true}
    check(not storage.aiming_cannons[t.ids[4]],'destroyed Cannon aim removed immediately')
  end
  if tick==55 and not t.reloaded then log('STAGE9 ALL PASSED') end
  if not t.reloaded then return end
  if tick==59 then check(not next(storage.in_flight_shots),'settling still blocks fire') end
  if tick==60 then
    local shot=storage.in_flight_shots[1]
    check(shot and shot.cannon_unit_number==t.ids[3] and shot.fire_tick==60,'same-pose Cannon fires after settling')
    check(shot.countdown.valid and storage.foundations[t.foundation_ids[3]].loaded_shots==0,'countdown and consumption start at fire')
    t.near_impact=shot.impact_tick
  end
  if tick==t.near_impact then check(not storage.in_flight_shots[1],'existing impact resolves on deadline') end
  if tick==100 then
    local id=t.ids[3];local record=storage.cannons[id]
    local foundation=storage.foundations[t.foundation_ids[3]]
    foundation.loaded_shots=1
    check(firing.fire(player(),id,record.entity.surface,point(record,0,100)),'reserve before Foundation destruction')
    foundation.entity.destroy{raise_destroy=true}
    check(not storage.aiming_cannons[id] and foundation.loaded_shots==1,'Foundation loss cancels without consuming ammo')
  end
  if tick==120 then check(storage.in_flight_shots[2].fire_tick==120,'elevation plus settling deadline') end
  if tick==150 and game.planets.gleba then
    local target_surface=game.planets.gleba.create_surface()
    local pos=point(b,0,100);generate(target_surface,pos)
    local foundation=storage.foundations[t.foundation_ids[2]];foundation.loaded_shots=1
    check(firing.fire(player(),t.ids[2],target_surface,pos),'reserve before target surface deletion')
    check(game.delete_surface(target_surface),'target surface deleted')
  end
  if tick==152 and game.planets.gleba then
    -- delete_surface queues deletion; the pre-delete event runs after this tick's handler.
    check(not storage.aiming_cannons[t.ids[2]] and storage.foundations[t.foundation_ids[2]].loaded_shots==1,
      'target deletion cancels without consuming ammo')
  end
  if tick==251 then check(storage.foundations[t.foundation_ids[1]].loaded_shots==2,'long aim keeps magazine until fire') end
  if tick==252 then
    local shot=storage.in_flight_shots[3]
    check(shot and shot.fire_tick==252 and shot.countdown.valid,'traverse elevate settle then fire')
    check(a.visual.direction_index==19 and a.visual.elevation_index==4,'last firing pose retained')
    if t.planet then
      check(firing.fire(player(),t.ids[1],t.planet,t.remote_target),'interplanetary reservation')
      check(storage.aiming_cannons[t.ids[1]].aim_state=='SETTLING','same planetary pose skips motion only')
    end
  end
  if tick==312 and t.planet then
    local shot=storage.in_flight_shots[4]
    check(shot and shot.fire_tick==312 and shot.flight_type=='interplanetary','actual planetary fire after settle')
    check(shot.flight_ticks==1800 and shot.impact_tick==2112,'planetary flight excludes aiming time')
  end
  if tick==2113 then
    check(not next(storage.in_flight_shots) and not next(storage.aiming_cannons),'all flights and aims completed')
    check(not next(storage.aim_actions_by_tick),'no stale aim buckets')
    log('STAGE9 ALL PASSED')
  end
end)
