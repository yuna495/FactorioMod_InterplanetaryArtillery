local visuals = require("scripts.cannon-visuals")
local origin = {x = 0, y = 0}
for _, case in ipairs({{0,-1,0},{-1,0,6},{0,1,12},{1,0,18},{-1,-1,3},{1,-1,21}}) do
  assert(visuals.target_direction(origin,{x=case[1],y=case[2]}) == case[3])
end
for i=0,23 do
  local theta=i*math.pi/12
  assert(visuals.target_direction(origin,{x=-math.sin(theta),y=-math.cos(theta)})==i)
end
assert(visuals.target_direction(origin,origin,7)==7)
for _, c in ipairs({{0,0},{4,18},{8,12},{12,6},{15,0},{3,18}}) do
  assert(visuals.initial_direction(c[1])==c[2])
end
for _,c in ipairs({{6,0},{299,0},{300,1},{599,1},{600,2},{899,2},{900,3},{1199,3},{1200,4},{99999,4}}) do
  assert(visuals.elevation{flight_type="same-surface",flight_ticks=c[1]}==c[2])
end
assert(visuals.elevation{flight_type="interplanetary",flight_ticks=1}==4)
print('CANNON VISUAL MATH PASSED')
