-- Optional client-only fixture, loaded after production-control in the isolated test mod.
local visuals = require('scripts.cannon-visuals')
local old_tick=script.get_event_handler(defines.events.on_tick)
local started
local shots={{0,0},{6,0},{12,0},{18,0},{6,2},{6,4}}
script.on_event(defines.events.on_tick,function(event)
  old_tick(event)
  started=started or event.tick
  local step=event.tick-started
  if step%30~=0 then return end
  local index=step/30+1
  local pose=shots[index]
  if not pose then
    if index==#shots+1 then log('MONOLITH SCREENSHOTS COMPLETE') end
    return
  end
  local record=storage.cannons[storage.cannon_visual_test.ids[1]]
  if index==1 then
    assert(record.visual.direction_index==storage.cannon_visual_test.expected_direction)
    assert(record.visual.elevation_index==storage.cannon_visual_test.expected_elevation)
    assert(record.visual.render.valid)
    log('MONOLITH CONFIGURATION MIGRATION POSE PRESERVED')
  end
  record.visual.direction_index,record.visual.elevation_index=pose[1],pose[2]
  visuals.ensure(record)
  record.entity.surface.daytime=0
  record.entity.surface.freeze_daytime=true
  game.take_screenshot{surface=record.entity.surface,
    position={record.entity.position.x,record.entity.position.y-7},
    resolution={1280,1024},zoom=.55,show_gui=false,show_entity_info=false,
    path=string.format('monolith-review/direction-%02d-elevation-%d.png',pose[1],pose[2])}
end)
