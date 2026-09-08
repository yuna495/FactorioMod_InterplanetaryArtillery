local graphics = require("scripts.monolith-graphics")
local visuals = {}

function visuals.initial_direction(direction)
  -- Factorio 2.0 directions are clockwise in a 16-value space.
  return (-math.floor(((direction or 0) % 16 + 2) / 4) * 6) % 24
end

function visuals.target_direction(source, target, fallback)
  local dx, dy = target.x - source.x, target.y - source.y
  if dx == 0 and dy == 0 then return fallback or 0 end
  local angle = (math.atan2 or math.atan)(-dx, -dy)
  return math.floor(angle * 24 / (2 * math.pi) + 0.5) % 24
end

function visuals.elevation(shot)
  if shot.flight_type == "interplanetary" then return 4 end
  -- Five-second bands of the existing 300 tiles/s flight-time calculation.
  return math.min(4, math.floor(shot.flight_ticks / 300))
end

function visuals.remove(record)
  local state = record and record.visual
  if state and state.render and state.render.valid then state.render.destroy() end
  if state then state.render = nil end
end

function visuals.ensure(record, direction)
  if not record.entity or not record.entity.valid then return end
  local state = record.visual or {direction_index = visuals.initial_direction(direction or record.entity.direction), elevation_index = 0}
  record.visual = state
  local sprite = graphics.upper_name(state.direction_index, state.elevation_index)
  local x_scale = graphics.upper_x_scale(state.direction_index)
  if state.render and state.render.valid then
    state.render.sprite = sprite
    state.render.x_scale = x_scale
  else
    state.render = rendering.draw_sprite{sprite = sprite, target = {entity = record.entity},
      x_scale = x_scale,
      surface = record.entity.surface, render_layer = "higher-object-above", render_mode = "game"}
  end
end

function visuals.aim(record, shot)
  visuals.ensure(record)
  local state = record.visual
  state.direction_index = visuals.target_direction(shot.source_position, shot.target_position, state.direction_index)
  state.elevation_index = visuals.elevation(shot)
  visuals.ensure(record)
end

function visuals.migrate()
  if storage.cannon_visual_schema == 2 then return end
  for _, record in pairs(storage.cannons or {}) do visuals.ensure(record) end
  storage.cannon_visual_schema = 2
end

return visuals
