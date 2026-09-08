-- Shared by data and control stages. Alignment comes from the export manifest.
local graphics = {
  directions = 24,
  elevations = {"low", "low-mid", "mid", "high-mid", "high"},
  size = 768,
  scale = 65.94560241699219 * 32 / 768,
  anchor = {384, 491.27840423584},
}
local root = "__InterplanetaryArtillery__/graphics/entity/monolith/"
function graphics.upper_name(direction, elevation)
  return string.format("interplanetary-artillery-upper-%s-%02d", graphics.elevations[elevation + 1], direction)
end
function graphics.upper_path(direction, elevation)
  direction = direction > 12 and 24 - direction or direction
  local label = graphics.elevations[elevation + 1]
  return root .. string.format("upper/%s/monolith-upper-%s-%02d.png", label, label, direction)
end
function graphics.upper_x_scale(direction)
  return direction > 12 and -1 or 1
end
-- Native placement pictures cannot use LuaRendering's negative x_scale.
function graphics.east_placement()
  return graphics.sprite(root .. "upper/low/monolith-upper-low-18.png")
end
function graphics.sprite(filename)
  return {filename = filename, width = graphics.size, height = graphics.size,
    scale = graphics.scale, priority = "extra-high",
    shift = {(graphics.size / 2 - graphics.anchor[1]) * graphics.scale / 32,
             (graphics.size / 2 - graphics.anchor[2]) * graphics.scale / 32}}
end
function graphics.foundation()
  local sprite = graphics.sprite(root .. "foundation/monolith-foundation.png")
  sprite.shift[2] = (graphics.size / 2 - 491.5) * graphics.scale / 32
  return sprite
end
return graphics
