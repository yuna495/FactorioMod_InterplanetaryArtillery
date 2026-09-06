local visuals = {}
local PROJECTILE = "interplanetary-artillery-projectile"
local IMPACT_PROJECTILE = "interplanetary-artillery-impact-projectile"
local IMPACT_VISUAL_TICKS = 3
local REVEAL_RADIUS_CHUNKS = 2 -- Provisional observation radius, not final balance.

function visuals.remove(shot)
  if shot.visual_projectile and shot.visual_projectile.valid then shot.visual_projectile.destroy() end
  shot.visual_projectile = nil
end

function visuals.launch(shot)
  if shot.flight_type ~= "same-surface" then return end
  local surface = game.surfaces[shot.source_surface_index]
  shot.visual_projectile = surface.create_entity{name = PROJECTILE,
    position = shot.source_position, target = shot.target_position,
    force = shot.source_force_index,
    speed = shot.distance_tiles > 0 and shot.distance_tiles / shot.flight_ticks or 5}
end

function visuals.impact(shot, surface, force)
  if shot.flight_type ~= "interplanetary" then return end
  local target = shot.target_position
  local entity = surface.create_entity{name = IMPACT_PROJECTILE,
    position = {x = target.x, y = target.y - 1}, target = target,
    force = force, speed = 1 / IMPACT_VISUAL_TICKS}
  if entity then
    local due = game.tick + IMPACT_VISUAL_TICKS
    local buckets = storage.visual_cleanup_by_tick
    buckets[due] = buckets[due] or {}
    buckets[due][#buckets[due] + 1] = {entity = entity, surface_index = surface.index}
  end
  local cx, cy = math.floor(target.x / 32), math.floor(target.y / 32)
  for dx = -REVEAL_RADIUS_CHUNKS, REVEAL_RADIUS_CHUNKS do
    for dy = -REVEAL_RADIUS_CHUNKS, REVEAL_RADIUS_CHUNKS do
      local x, y = cx + dx, cy + dy
      if dx * dx + dy * dy <= REVEAL_RADIUS_CHUNKS ^ 2 and surface.is_chunk_generated({x, y}) then
        force.chart(surface, {{x * 32, y * 32}, {x * 32 + 31, y * 32 + 31}})
      end
    end
  end
end

function visuals.on_tick(tick)
  local buckets = storage.visual_cleanup_by_tick
  local bucket = buckets[tick]
  buckets[tick] = nil
  for _, record in ipairs(bucket or {}) do
    if record.entity.valid then record.entity.destroy() end
  end
end

function visuals.clear_surface(index)
  for tick, bucket in pairs(storage.visual_cleanup_by_tick or {}) do
    for i = #bucket, 1, -1 do
      local record = bucket[i]
      if record.surface_index == index then
        if record.entity.valid then record.entity.destroy() end
        table.remove(bucket, i)
      end
    end
    if #bucket == 0 then storage.visual_cleanup_by_tick[tick] = nil end
  end
end

return visuals
