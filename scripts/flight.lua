local flight = {}

function flight.route_distance(from, to)
  if from == to then return 0 end
  local graph = {}
  for _, connection in pairs(prototypes.space_connection) do
    local length = connection.length
    if type(length) == "number" and length > 0 and length < math.huge then
      local a, b = connection.from.name, connection.to.name
      graph[a], graph[b] = graph[a] or {}, graph[b] or {}
      graph[a][b] = math.min(graph[a][b] or math.huge, length)
      graph[b][a] = math.min(graph[b][a] or math.huge, length)
    end
  end
  local distances, visited = {[from] = 0}, {}
  while true do
    local next_node, best
    for name, distance in pairs(distances) do
      if not visited[name] and (not best or distance < best
        or (distance == best and name < next_node)) then
        next_node, best = name, distance
      end
    end
    if not next_node then return nil end
    if next_node == to then return best end
    visited[next_node] = true
    for name, length in pairs(graph[next_node] or {}) do
      local distance = best + length
      if distance < (distances[name] or math.huge) then distances[name] = distance end
    end
  end
end

function flight.calculate(surface, position, target_surface, target)
  if surface.index == target_surface.index then
    local dx, dy = target.x - position.x, target.y - position.y
    local distance = math.sqrt(dx * dx + dy * dy)
    return {flight_type = "same-surface", distance_tiles = distance,
      flight_ticks = math.max(6, math.ceil(distance * 60 / 300))}
  end
  local a, b = surface.planet, target_surface.planet
  if not a or not b or not a.valid or not b.valid then return nil end
  local distance = flight.route_distance(a.name, b.name)
  if not distance or distance >= math.huge then return nil end
  return {flight_type = "interplanetary", route_distance_km = distance,
    flight_ticks = math.max(1, math.ceil(distance * 60 / 500))}
end

return flight
