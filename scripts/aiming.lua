local visuals = require("scripts.cannon-visuals")
local aiming = {
  TRAVERSE_STEP_TICKS = 12,
  ELEVATION_STEP_TICKS = 30,
  AIM_SETTLE_TICKS = 60,
}

function aiming.init()
  storage.aiming_cannons = storage.aiming_cannons or {}
  storage.aim_actions_by_tick = storage.aim_actions_by_tick or {}
end

function aiming.is_ready(id)
  return not (storage.aiming_cannons and storage.aiming_cannons[id])
end

local function schedule(aim, tick, delay)
  aim.next_aim_tick = tick + delay
  local bucket = storage.aim_actions_by_tick[aim.next_aim_tick] or {}
  bucket[aim.cannon_unit_number] = aim
  storage.aim_actions_by_tick[aim.next_aim_tick] = bucket
end

function aiming.cancel(id)
  local aim = storage.aiming_cannons and storage.aiming_cannons[id]
  if not aim then return end
  storage.aiming_cannons[id] = nil
  local bucket = storage.aim_actions_by_tick[aim.next_aim_tick]
  if bucket then
    bucket[id] = nil
    if not next(bucket) then storage.aim_actions_by_tick[aim.next_aim_tick] = nil end
  end
  return aim
end

local function next_phase(aim, record, tick)
  local pose = record.visual
  if pose.direction_index ~= aim.target_direction_index then
    aim.aim_state = "TRAVERSING"
    schedule(aim, tick, aiming.TRAVERSE_STEP_TICKS)
  elseif pose.elevation_index ~= aim.target_elevation_index then
    aim.aim_state = "ELEVATING"
    schedule(aim, tick, aiming.ELEVATION_STEP_TICKS)
  else
    aim.aim_state = "SETTLING"
    schedule(aim, tick, aiming.AIM_SETTLE_TICKS)
  end
end

function aiming.start(id, record, reservation, tick)
  aiming.init()
  if not aiming.is_ready(id) then return nil end
  reservation.cannon_unit_number = id
  storage.aiming_cannons[id] = reservation
  next_phase(reservation, record, tick)
  return id -- Reservation receipt, not a shot ID.
end

function aiming.on_tick(tick, validate, fire, cancelled)
  local bucket = storage.aim_actions_by_tick and storage.aim_actions_by_tick[tick]
  if not bucket then return end
  storage.aim_actions_by_tick[tick] = nil
  local ids = {}
  for id in pairs(bucket) do ids[#ids + 1] = id end
  table.sort(ids)
  for _, id in ipairs(ids) do
    local aim = bucket[id]
    -- Identity check also protects against cancellation/re-reservation in a callback.
    if storage.aiming_cannons[id] == aim and aim.next_aim_tick == tick then
      local record = validate(aim)
      if not record then
        aiming.cancel(id)
        cancelled(aim)
      elseif aim.aim_state == "SETTLING" then
        -- Keep the Cannon busy during final validation and ammunition consumption.
        local shot_id = fire(aim)
        aiming.cancel(id)
        if not shot_id then cancelled(aim) end
      else
        local pose = record.visual
        if aim.aim_state == "TRAVERSING" then
          local distance = (aim.target_direction_index - pose.direction_index) % 24
          -- A 180-degree tie deterministically takes the increasing-index path.
          pose.direction_index = (pose.direction_index + (distance <= 12 and 1 or -1)) % 24
        elseif aim.aim_state == "ELEVATING" then
          pose.elevation_index = pose.elevation_index + (aim.target_elevation_index > pose.elevation_index and 1 or -1)
        end
        visuals.ensure(record)
        next_phase(aim, record, tick)
      end
    end
  end
end

return aiming
