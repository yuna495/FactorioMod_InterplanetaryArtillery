local firing = require("scripts.firing")
local probe = require("tests.reveal-probe")
local old_tick = script.get_event_handler(defines.events.on_tick)
local first_tick = true
local F = "interplanetary-artillery-foundation"
local C = "interplanetary-artillery-cannon"
local P = "interplanetary-artillery-impact-projectile"
local function check(v, text)
  assert(v, text)
  log("STAGE7 PASS: " .. text)
end
local function player() return {index=1,valid=true,force=game.forces.player,print=function() end} end
local function charted_or_requested(surface, chunk)
  local force=player().force
  return force.is_chunk_charted(surface,chunk) or force.is_chunk_requested_for_charting(surface,chunk)
end
local function generate(s,p,r)
  s.request_to_generate_chunks(p,r)
  s.force_generate_chunk_requests() -- Fixture preparation only.
end
local function target(s,p)
  generate(s,p,3)
  return s.create_entity{name="steel-chest",position=p,force="enemy"}
end
local function setup()
  local s=game.surfaces.nauvis
  generate(s,{0,0},1)
  local tiles={}
  for x=-8,8 do for y=-8,8 do tiles[#tiles+1]={name="interplanetary-artillery-foundation-tile",position={x,y}} end end
  s.set_tiles(tiles)
  local f=s.create_entity{name=F,position={0.5,0.5},force="player",raise_built=true}
  local c=s.create_entity{name=C,position=f.position,force="player",raise_built=true}
  local t={foundation=f,cannon=c,record_id=f.unit_number,surface=s,target={x=6000.5,y=0.5},phase="produce"}
  t.supplied=f.insert{name="iron-plate",count=500}
  check(t.supplied>=200,"input materials preloaded: "..t.supplied)
  t.enemy=target(s,t.target)
  generate(s,{3000,0},3) -- Generated but uncharted observation checkpoint.
  t.lost_target={x=6064.5,y=0.5}
  t.lost_enemy=target(s,t.lost_target)
  if game.planets.vulcanus then
    t.planet=game.planets.vulcanus.create_surface()
    t.planet_enemy=target(t.planet,t.target)
    t.planet.delete_chunk({189,0}) -- Outer reveal footprint, not impact footprint.
  end
  storage.visual_test=t
  game.speed=10
  return t
end
script.on_event(defines.events.on_tick,function(event)
  old_tick(event)
  if not storage.visual_probe or game.tick-storage.visual_probe.start<=60 then probe.tick(event) end
  local t=storage.visual_test or setup()
  local record=storage.foundations[t.record_id]
  local f=t.foundation
  f.energy=1000000
  if first_tick and t.phase=="flight" then
    local shot=storage.in_flight_shots[t.local_id]
    check(shot and shot.visual_projectile.valid and shot.countdown.valid,"flight visual and countdown survive reload")
    check(shot.impact_tick==t.local_due,"original impact deadline survives reload")
    log("STAGE7 RELOAD CONFIRMED")
  end
  first_tick=false
  if t.phase=="produce" then
    if t.supplied<500 then t.supplied=t.supplied+f.insert{name="iron-plate",count=500-t.supplied} end
    if record.loaded_shots==1 and not t.first_product then
      check(f.get_recipe().name=="interplanetary-artillery-test-shell","first shot produced with recipe retained")
      t.first_product=true
    end
    if record.loaded_shots==2 then
      check(f.get_recipe().name=="interplanetary-artillery-test-shell" and f.disabled_by_script,"full magazine pauses without recipe removal")
      t.full_tick=game.tick
      t.input=f.get_inventory(defines.inventory.assembling_machine_input).get_item_count("iron-plate")
      t.progress=f.crafting_progress
      t.products=f.products_finished
      t.phase="hold"
    end
  elseif t.phase=="hold" and game.tick>=t.full_tick+1200 then
    check(record.loaded_shots==2 and f.products_finished==t.products,"no third product during full pause")
    check(f.get_inventory(defines.inventory.assembling_machine_input).get_item_count("iron-plate")==t.input and f.crafting_progress==t.progress,"input and crafting progress retained")
    check(t.surface.count_entities_filtered{type="item-entity",area={{-20,-20},{20,20}}}==0,"no spilled input materials")
    t.local_id=firing.fire_auto(player(),t.surface,t.target)
    local shot=storage.in_flight_shots[t.local_id]
    check(shot.visual_projectile and shot.visual_projectile.valid,"same-surface visual created")
    check(not f.disabled_by_script and f.get_recipe(),"consumption resumes production with recipe")
    t.local_due=shot.impact_tick
    t.local_visual=shot.visual_projectile
    t.fire_tick=game.tick
    t.phase="flight"
    if t.planet then
      t.inter_id=firing.fire_auto(player(),t.planet,t.target)
      local inter=storage.in_flight_shots[t.inter_id]
      check(not inter.visual_projectile,"no source-side interplanetary projectile")
      t.inter_due=inter.impact_tick
      check(not player().force.is_chunk_charted(t.planet,{187,0}),"planet target initially uncharted")
    end
  elseif t.phase=="flight" then
    local elapsed=game.tick-t.fire_tick
    if elapsed==660 then
      log("CHART CHECK generated="..tostring(t.surface.is_chunk_generated({93,0})).." requested="..tostring(player().force.is_chunk_requested_for_charting(t.surface,{93,0})).." charted="..tostring(player().force.is_chunk_charted(t.surface,{93,0})))
    end
    if elapsed==10 then
      local p=t.local_visual.position
      log("PROJECTILE at tick 10: "..serpent.line(p))
      check(p.x>40 and p.x<61,"visual travels approximately 5 tiles per tick")
      check(t.enemy.health==350,"visual flight has no early damage")
    elseif elapsed==30 and not t.saved then
      t.saved=true
      game.server_save("stage7-flight.zip")
    end
    if not t.lost_id and elapsed>=960 and record.loaded_shots>=1 then
      check(f.get_inventory(defines.inventory.assembling_machine_input).get_item_count("iron-plate")<t.input,"retained surplus used for next shot")
      t.lost_id=firing.fire_auto(player(),t.surface,t.lost_target)
      local lost=storage.in_flight_shots[t.lost_id]
      t.lost_due=lost.impact_tick
      lost.visual_projectile.destroy()
      check(storage.in_flight_shots[t.lost_id]~=nil,"visual loss does not cancel shot")
    end
    if game.tick==t.local_due-1 then
      if t.local_visual.valid then
        local p=t.local_visual.position
        log("PROJECTILE before impact: "..serpent.line(p).." remaining="..(t.local_due-game.tick))
        -- Native projectile position/speed quantization can accumulate a small offset.
        check(math.abs(p.x-t.target.x)<=15,"visual reaches target within three ticks of authoritative impact")
      end
      check(t.enemy.health==350,"no projectile damage before impact")
    end
    if game.tick==t.local_due then
      check(not t.local_visual.valid and not storage.in_flight_shots[t.local_id],"same-surface visual and countdown cleaned")
      check(math.abs(t.enemy.health-100)<0.01,"same-surface damage applied exactly once")
      check(charted_or_requested(t.surface,{93,0}),"same-surface flight-path chart requested")
    end
    if t.inter_due and game.tick==t.inter_due then
      check(math.abs(t.planet_enemy.health-100)<0.01,"interplanetary damage applied exactly once")
      local entities=t.planet.find_entities_filtered{name=P,position=t.target,radius=2}
      check(#entities==1,"brief target-side visual created at impact")
      t.impact_visual=entities[1]
    end
    if t.inter_due and game.tick==t.inter_due+60 then
      check(not t.impact_visual.valid,"brief impact visual does not remain")
      local count=0
      for dx=-3,3 do for dy=-3,3 do
        local charted=charted_or_requested(t.planet,{187+dx,dy})
        local expected=dx*dx+dy*dy<=4 and not (dx==2 and dy==0)
        check(charted==expected,"local reveal cell "..dx..","..dy)
        if charted then count=count+1 end
      end end
      check(count==12 and not t.planet.is_chunk_generated({189,0}),"circular reveal skips ungenerated chunk")
      check(math.abs(t.planet_enemy.health-100)<0.01,"short projectile adds no extra damage")
    end
    if t.lost_due and game.tick>math.max(t.lost_due,(t.inter_due or 0)+60) then
      check(math.abs(t.lost_enemy.health-100)<0.01,"shot impacts despite missing visual")
      check(not next(storage.visual_cleanup_by_tick),"visual cleanup queue drained")
      check(not next(storage.in_flight_shots) and not next(storage.countdown_by_tick),"all shot state cleaned")
      log("STAGE7 ALL PASSED")
      t.phase="done"
    end
  end
end)
