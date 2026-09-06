local probe = {}
function probe.tick(event)
  if not storage.visual_probe then
    local s = game.create_surface("visual-probe")
    s.request_to_generate_chunks({10016,10016},4)
    s.force_generate_chunk_requests()
    local machine = s.create_entity{name="assembling-machine-1",position={10000,10000},force="player"}
    local ok, result = pcall(function() machine.disabled_by_script = true; return machine.disabled_by_script end)
    log("STOP API disabled_by_script: " .. tostring(ok) .. " " .. tostring(result))
    local t={start=game.tick,surface=s,probes={}}
    storage.visual_probe=t
    local moving_force=game.create_force("reveal-probe-moving")
    t.moving_force=moving_force
    s.create_entity{name="monolith-reveal-probe",position={9900,10016},target={10140,10016},speed=5,force=moving_force}
    for _,delay in ipairs({0,1,3}) do
      local force=game.create_force("reveal-probe-"..delay)
      local entity=s.create_entity{name="monolith-reveal-probe",position={10016,10016},target={10016,10016},speed=5,force=force}
      log("REVEAL created delay="..delay.." valid="..tostring(entity and entity.valid))
      t.probes[#t.probes+1]={entity=entity,force=force,delay=delay}
      if delay==0 and entity and entity.valid then entity.destroy() end
    end
  end
  local t=storage.visual_probe
  local elapsed=game.tick-t.start
  if elapsed==60 then
    log("NATIVE MOVING requested="..tostring(t.moving_force.is_chunk_requested_for_charting(t.surface,{313,313})).." charted="..tostring(t.moving_force.is_chunk_charted(t.surface,{313,313})))
  end
  for _,probe in ipairs(t.probes) do
    if elapsed==probe.delay and probe.entity and probe.entity.valid then probe.entity.destroy() end
    if elapsed==60 then
      local count=0
      for x=308,317 do for y=308,317 do
        if probe.force.is_chunk_charted(t.surface,{x,y}) then count=count+1 end
      end end
      log("REVEAL delay="..probe.delay.." charted="..count)
    end
  end
end
return probe
