local countdown = {}

function countdown.remove(shot)
  if shot.countdown and shot.countdown.valid then shot.countdown.destroy() end
  if shot.countdown_map and shot.countdown_map.valid then shot.countdown_map.destroy() end
  shot.countdown = nil
  shot.countdown_map = nil
  local tick = shot.countdown_tick
  local bucket = tick and storage.countdown_by_tick[tick]
  if bucket then
    bucket[shot.id] = nil
    if not next(bucket) then storage.countdown_by_tick[tick] = nil end
  end
  shot.countdown_tick = nil
end

function countdown.update(shot, tick)
  local remaining = shot.impact_tick - tick
  local surface = game.surfaces[shot.target_surface_index]
  local force = game.forces[shot.source_force_index]
  if remaining <= 0 or not surface or not surface.valid or not force then
    countdown.remove(shot)
    return false
  end
  local seconds = remaining >= 600 and tostring(math.ceil(remaining / 60))
    or string.format("%.1f", math.ceil(remaining / 6) / 10)
  local text = {"interplanetary-artillery.countdown", seconds}
  for _, entry in ipairs({{"countdown", "game"}, {"countdown_map", "chart"}}) do
    local object = shot[entry[1]]
    if object and object.valid then
      object.text = text
    else
      shot[entry[1]] = rendering.draw_text{text = text, surface = surface,
        target = shot.target_position, color = {1, 0.8, 0.2}, alignment = "center",
        scale_with_zoom = true, render_mode = entry[2], forces = {force}}
    end
  end
  local delay = remaining > 600 and math.min(60, remaining - 600) or 6
  if delay < remaining then
    local due = tick + delay
    storage.countdown_by_tick[due] = storage.countdown_by_tick[due] or {}
    storage.countdown_by_tick[due][shot.id] = true
    shot.countdown_tick = due
  end
  return true
end

return countdown
