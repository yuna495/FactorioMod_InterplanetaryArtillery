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

local graphics = require('scripts.monolith-graphics')
rendering = {draw_sprite = function(args)
  args.valid=true; args.destroy=function() args.valid=false end; return args
end}
local record={entity={valid=true,surface={},direction=0},visual={direction_index=18,elevation_index=2}}
storage={cannons={[1]=record},cannon_visual_schema=1}
record.visual.render=rendering.draw_sprite{sprite=graphics.upper_name(18,2),x_scale=1}
local old=record.visual.render
visuals.migrate()
assert(storage.cannon_visual_schema==2 and old==record.visual.render and old.x_scale==-1)
for e=0,4 do for d=0,23 do
  record.visual.direction_index=d;record.visual.elevation_index=e
  visuals.ensure(record)
  assert(old.sprite==graphics.upper_name(d,e))
  assert(old.x_scale==(d>12 and -1 or 1))
  local source=d>12 and 24-d or d
  assert(graphics.upper_path(d,e)==graphics.upper_path(source,e))
  local path=graphics.upper_path(d,e):gsub('__InterplanetaryArtillery__/','')
  local file=assert(io.open(path,'rb'),path);file:close()
end end
assert(graphics.east_placement().filename:match('low%-18.png$'))
assert(graphics.foundation().shift[2]==(384-491.5)*graphics.scale/32)
print('MIRROR MAPPING, ASSET REFERENCES AND SAVED VISUAL MIGRATION PASSED')
