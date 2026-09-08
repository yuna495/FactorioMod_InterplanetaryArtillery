local handlers, commands_by_name = {}, {}
defines={events=setmetatable({},{__index=function(_,k) return k end})}
script={on_event=function(k,v) handlers[k]=v end}
commands={add_command=function(k,_,v) commands_by_name[k]=v end}
rendering={}
local function render(args)
  args.valid=true; args.destroy=function() args.valid=false end; return args
end
rendering.draw_text=render; rendering.draw_sprite=render
local firing=require('scripts.firing')
local aiming=require('scripts.aiming')
local force={index=1,chart=function() end}
local player={index=1,valid=true,force=force,print=function() end}
local function surface(id,planet)
  return {index=id,valid=true,name=tostring(id),map_gen_settings={},
    planet={valid=true,name=planet},is_chunk_generated=function() return true end,
    create_entity=function() end,find_entities_filtered=function() return {} end}
end
local local_surface,remote_surface=surface(1,'a'),surface(2,'b')
prototypes={space_connection={{from={name='a'},to={name='b'},length=15000}}}
local resumes
local function reset()
  storage={cannons={},foundations={}}
  game={tick=0,forces={[1]=force},surfaces={local_surface,remote_surface},get_player=function() return player end}
  local_surface.valid=true;remote_surface.valid=true
  local_surface.is_chunk_generated=function() return true end
  resumes=0
  firing.init(); firing.register(function() resumes=resumes+1 end)
end
local function cannon(id,d,e,s)
  local entity={valid=true,surface=s or local_surface,position={x=0,y=0},force=force}
  local record={entity=entity,foundation_unit_number=id,visual={direction_index=d or 0,elevation_index=e or 0}}
  storage.cannons[id]=record
  storage.foundations[id]={entity=entity,cannon_unit_number=id,loaded_shots=2}
  return record,storage.foundations[id]
end
local function until_tick(t)
  for tick=game.tick+1,t do game.tick=tick;handlers.on_tick{tick=tick} end
end
local function target(d,r)
  return {x=-math.sin(d*math.pi/12)*r,y=-math.cos(d*math.pi/12)*r}
end
reset()
local c,f=cannon(1,1,0)
assert(firing.fire(player,1,local_surface,target(23,3000))==1)
assert(storage.next_shot_id==1 and not next(storage.in_flight_shots) and f.loaded_shots==2)
assert(storage.aiming_cannons[1].aim_state=='TRAVERSING')
assert(not firing.fire(player,1,local_surface,target(6,300)))
until_tick(11);assert(c.visual.direction_index==1)
until_tick(12);assert(c.visual.direction_index==0)
until_tick(24);assert(c.visual.direction_index==23 and storage.aiming_cannons[1].aim_state=='ELEVATING')
until_tick(53);assert(c.visual.elevation_index==0)
until_tick(54);assert(c.visual.elevation_index==1)
until_tick(84);assert(c.visual.elevation_index==2 and storage.aiming_cannons[1].aim_state=='SETTLING')
until_tick(143);assert(f.loaded_shots==2 and not next(storage.in_flight_shots))
until_tick(144)
local shot=storage.in_flight_shots[1]
assert(shot and shot.fire_tick==144 and shot.impact_tick==144+shot.flight_ticks)
assert(shot.countdown.valid and f.loaded_shots==1 and resumes==1 and aiming.is_ready(1))
assert(c.visual.direction_index==23 and c.visual.elevation_index==2)
local last_pose={c.visual.direction_index,c.visual.elevation_index}
assert(firing.fire(player,1,local_surface,target(23,3000)))
assert(storage.aiming_cannons[1].aim_state=='SETTLING')
until_tick(203);assert(storage.next_shot_id==2 and f.loaded_shots==1)
until_tick(204);assert(storage.in_flight_shots[2].fire_tick==204 and f.loaded_shots==0)
assert(c.visual.direction_index==last_pose[1] and c.visual.elevation_index==last_pose[2])
until_tick(804);assert(not next(storage.in_flight_shots) and not next(storage.countdown_by_tick))

-- Busy filtering, same-surface priority, and shared round-robin advance at reservation.
reset();cannon(1);cannon(2);cannon(3,0,0,remote_surface)
assert(firing.fire_auto(player,local_surface,target(0,100))==1)
assert(firing.fire_auto(player,local_surface,target(0,100))==2)
assert(firing.fire_auto(player,local_surface,target(0,100))==3)
assert(not firing.fire_auto(player,local_surface,target(0,100)))
assert(storage.aiming_cannons[3].target_elevation_index==4)
until_tick(60)
assert(firing.fire_auto(player,local_surface,target(0,100))==1)
until_tick(180)
assert(storage.in_flight_shots[4].flight_type=='interplanetary')
assert(storage.in_flight_shots[4].fire_tick==180 and storage.in_flight_shots[4].flight_ticks==1800)
assert(storage.cannons[3].visual.elevation_index==4)

-- 180-degree tie, reverse elevation, and target coordinates copied on request.
reset();c,f=cannon(1,0,4)
local pos=target(12,100)
firing.fire(player,1,local_surface,pos);pos.x=9000
until_tick(12);assert(c.visual.direction_index==1)
until_tick(144);assert(c.visual.direction_index==12)
until_tick(174);assert(c.visual.elevation_index==3)
until_tick(264);assert(c.visual.elevation_index==0)
until_tick(324);assert(math.abs(storage.in_flight_shots[1].target_position.x)<1e-8)

-- Cancelled reservations leave no future jobs or ammunition loss.
for _,failure in ipairs({'cannon','foundation','target','ammo','terrain','force','moved','explicit','route'}) do
  reset();c,f=cannon(1)
  local dest=failure=='route' and remote_surface or local_surface
  firing.fire(player,1,dest,target(0,100))
  if failure=='cannon' then c.entity.valid=false
  elseif failure=='foundation' then storage.foundations[1]=nil
  elseif failure=='target' then handlers.on_pre_surface_deleted{surface_index=dest.index}
  elseif failure=='ammo' then f.loaded_shots=0
  elseif failure=='terrain' then local_surface.is_chunk_generated=function() return false end
  elseif failure=='force' then game.forces[1]=nil
  elseif failure=='moved' then c.entity.position={x=5,y=0}
  elseif failure=='explicit' then firing.cancel_aim(1)
  elseif failure=='route' then prototypes.space_connection={} end
  until_tick(400)
  assert(not next(storage.aiming_cannons) and not next(storage.aim_actions_by_tick),failure)
  assert(not next(storage.in_flight_shots) and storage.next_shot_id==1 and resumes==0,failure)
  assert(f.loaded_shots==(failure=='ammo' and 0 or 2),failure)
end
prototypes.space_connection={{from={name='a'},to={name='b'},length=15000}}
reset();c,f=cannon(1)
firing.fire(player,1,local_surface,target(0,100))
handlers.on_pre_surface_cleared{surface_index=1}
assert(aiming.is_ready(1) and not next(storage.aim_actions_by_tick))
-- An old cancelled bucket must not advance a newer reservation.
firing.fire(player,1,local_surface,target(0,100));until_tick(60)
assert(storage.next_shot_id==2 and f.loaded_shots==1)
print('AIMING UNIT ALL PASSED')
