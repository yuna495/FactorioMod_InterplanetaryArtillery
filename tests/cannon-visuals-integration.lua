local firing = require("scripts.firing")
local visuals = require("scripts.cannon-visuals")
local graphics = require("scripts.monolith-graphics")
local old_tick = script.get_event_handler(defines.events.on_tick)
local first = true
local function check(value, label)
  assert(value,label)
  log('STAGE8 PASS: '..label)
end
local function generate(surface, position)
  surface.request_to_generate_chunks(position,1)
  surface.force_generate_chunk_requests()
end
local function setup()
  local s = game.surfaces.nauvis
  local state = {ids={}, foundation_ids={},phase='reload'}
  for i,direction in ipairs({0,12,8,4}) do
    local pos = {x=(i-1)*80+.5,y=.5}
    generate(s,pos)
    local tiles={}
    for x=math.floor(pos.x)-7,math.floor(pos.x)+7 do
      for y=-7,7 do tiles[#tiles+1]={name='interplanetary-artillery-foundation-tile',position={x,y}} end
    end
    s.set_tiles(tiles)
    local f=s.create_entity{name='interplanetary-artillery-foundation',position=pos,force='player',direction=direction,raise_built=true}
    local proxy=s.create_entity{name='interplanetary-artillery-cannon-placement',position=pos,force='player',direction=direction}
    check(proxy.direction==direction,'placement direction retained '..direction)
    check(proxy.rotate(),'placement entity supports native rotation')
    proxy.direction=direction
    script.raise_script_built{entity=proxy}
    local c=s.find_entity('interplanetary-artillery-cannon',pos)
    local record=c and storage.cannons[c.unit_number]
    check(record and record.visual.render.valid and not proxy.valid,'placement replaced with rendered container')
    check(record.visual.direction_index==(i-1)*6 and record.visual.elevation_index==0,'cardinal placement '..(i-1)*6)
    check(c.type=='container' and c.get_inventory(defines.inventory.chest).valid,'original Cannon inventory retained')
    state.ids[i]=c.unit_number; state.foundation_ids[i]=f.unit_number
    local obj=record.visual.render
    check(obj.sprite==graphics.upper_name((i-1)*6,0),'registered sprite selected')
    check(obj.target.entity==c,'render anchor targets Cannon')
  end
  for e=0,4 do for d=0,23 do
    check(helpers.is_valid_sprite_path(graphics.upper_name(d,e)),'sprite '..e..'/'..d)
  end end
  local player={index=1,valid=true,force=game.forces.player,print=function() end}
  -- Actual automatic selection: only cannon 1 is ready.
  local c=storage.cannons[state.ids[1]]
  local foundation=storage.foundations[state.foundation_ids[1]]
  for _,test in ipairs({{0,-300,0,0},{-1500,0,6,1},{0,3000,12,2},{4500,0,18,3},{-6000,0,6,4}}) do
    local target={x=c.entity.position.x+test[1],y=c.entity.position.y+test[2]}
    generate(s,target)
    foundation.loaded_shots=1
    local id=firing.fire_auto(player,s,target)
    local shot=id and storage.in_flight_shots[id]
    check(shot and shot.cannon_unit_number==state.ids[1],'automatic selection preserved')
    check(c.visual.direction_index==test[3] and c.visual.elevation_index==test[4],'local pose '..test[3]..'/'..test[4])
    check(foundation.loaded_shots==0 and shot.flight_ticks==math.max(6,math.ceil(shot.distance_tiles/5)),'ammo and flight timing unchanged')
    firing.cancel(id)
  end
  local last=c.visual.render.sprite
  check(not firing.fire_auto(player,s,c.entity.position) and c.visual.render.sprite==last,'rejected shot leaves pose unchanged')
  if game.planets.vulcanus then
    local target_surface=game.planets.vulcanus.create_surface()
    local target={x=c.entity.position.x+200,y=c.entity.position.y}
    generate(target_surface,target)
    foundation.loaded_shots=1
    local id=firing.fire_auto(player,target_surface,target)
    check(id and c.visual.direction_index==18 and c.visual.elevation_index==4,'interplanetary heading and high elevation')
    check(storage.in_flight_shots[id].flight_type=='interplanetary','planetary flight unchanged')
    firing.cancel(id)
  end
  state.expected_direction=c.visual.direction_index
  state.expected_elevation=c.visual.elevation_index
  state.render_id=c.visual.render.id
  state.save_tick=game.tick
  storage.cannon_visual_test=state
  game.server_save('stage8-flight.zip')
end
script.on_event(defines.events.on_tick,function(event)
  old_tick(event)
  if not first then
    local saved=storage.cannon_visual_test
    if saved and event.tick==saved.save_tick+60 then log('STAGE8 ALL PASSED') end
    return
  end
  first=false
  if not storage.cannon_visual_test then setup(); return end
  local state=storage.cannon_visual_test
  local c=storage.cannons[state.ids[1]]
  check(c.visual.direction_index==state.expected_direction and c.visual.elevation_index==state.expected_elevation,'pose survives reload')
  check(c.visual.render.valid and c.visual.render.id==state.render_id,'same render object survives reload')
  log('STAGE8 RELOAD CONFIRMED')
  -- Recovery of an invalid rendering is event-driven when the Cannon is used.
  c.visual.render.destroy()
  visuals.ensure(c)
  check(c.visual.render.valid and c.visual.direction_index==state.expected_direction,'invalid visual can be recreated')
  local object=storage.cannons[state.ids[4]].visual.render
  storage.cannons[state.ids[4]].entity.destroy{raise_destroy=true}
  check(not object.valid and not storage.cannons[state.ids[4]],'Cannon removal cleans rendering')
  log('STAGE8 ALL PASSED')
end)
