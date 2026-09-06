-- Isolated test mod only: compare native reveal without native damage/actions.
local projectile = table.deepcopy(data.raw["artillery-projectile"]["artillery-projectile"])
projectile.name = "monolith-reveal-probe"
projectile.action = nil
projectile.final_action = nil
data:extend({projectile})
