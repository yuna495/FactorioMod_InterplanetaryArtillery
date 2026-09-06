local hit_effects = require("__base__.prototypes.entity.hit-effects")
local sounds = require("__base__.prototypes.entity.sounds")
local item_sounds = require("__base__.prototypes.item_sounds")
local tile_sounds = require("__base__.prototypes.tile.tile-sounds")
local tile_trigger_effects = require("__base__.prototypes.tile.tile-trigger-effects")
local tile_graphics = require("__base__.prototypes.tile.tile-graphics")
local tile_collision_masks = require("__base__.prototypes.tile.tile-collision-masks")

local foundation_tile_layer = "interplanetary_artillery_foundation_tile"
local cannon_collision_layer = "interplanetary_artillery_cannon"
local foundation_recipe_category = "interplanetary-artillery-foundation"
local test_shell_name = "interplanetary-artillery-test-shell"

local projectile = table.deepcopy(data.raw["artillery-projectile"]["artillery-projectile"])
projectile.name = "interplanetary-artillery-projectile"
projectile.action = nil
projectile.final_action = nil
projectile.reveal_map = true
local impact_projectile = table.deepcopy(projectile)
impact_projectile.name = "interplanetary-artillery-impact-projectile"
impact_projectile.reveal_map = false
data:extend({projectile, impact_projectile})

-- Native artillery-remote actions require an eligible artillery weapon.
local remote = {
  type = "selection-tool",
  name = "interplanetary-artillery-targeting-remote",
  icon = "__base__/graphics/icons/artillery-targeting-remote.png",
  flags = {"only-in-cursor", "not-stackable", "spawnable"},
  stack_size = 1,
  subgroup = "spawnables",
  select = {border_color = {1, 0.25, 0.1}, mode = {"nothing"}, cursor_box_type = "entity"},
  alt_select = {border_color = {1, 0.25, 0.1}, mode = {"nothing"}, cursor_box_type = "entity"},
}
local shortcut = table.deepcopy(data.raw.shortcut["give-artillery-targeting-remote"])
shortcut.name = "interplanetary-artillery-targeting"
shortcut.localised_name = {"shortcut-name.interplanetary-artillery-targeting"}
shortcut.item_to_spawn = remote.name
shortcut.associated_control_input = nil
shortcut.technology_to_unlock = nil
shortcut.unavailable_until_unlocked = false
data:extend({remote, shortcut})

data:extend({
  {
    type = "custom-input",
    name = "interplanetary-artillery-aim",
    key_sequence = "CONTROL + SHIFT + F",
    consuming = "none",
    action = "lua",
  },
  {
    type = "selection-tool",
    name = "interplanetary-artillery-target",
    icon = "__base__/graphics/icons/artillery-targeting-remote.png",
    flags = {"only-in-cursor", "not-stackable", "spawnable"},
    hidden = true,
    stack_size = 1,
    subgroup = "other",
    select = {border_color = {1, 0.25, 0.1}, mode = {"nothing"}, cursor_box_type = "entity"},
    alt_select = {border_color = {1, 0.25, 0.1}, mode = {"nothing"}, cursor_box_type = "entity"},
  },
})

data:extend({
  {
    type = "collision-layer",
    name = foundation_tile_layer,
  },
  {
    type = "collision-layer",
    name = cannon_collision_layer,
  },
  {
    type = "recipe-category",
    name = foundation_recipe_category,
  },
})

local foundation_tile_collision_mask = tile_collision_masks.ground()
foundation_tile_collision_mask.layers[foundation_tile_layer] = true

data:extend({
  {
    type = "tile",
    name = "interplanetary-artillery-foundation-tile",
    order = "a[artificial]-z[interplanetary-artillery-foundation-tile]",
    subgroup = "artificial-tiles",
    needs_correction = false,
    minable = {mining_time = 0.1, result = "interplanetary-artillery-foundation-tile"},
    mined_sound = sounds.deconstruct_bricks(0.8),
    collision_mask = foundation_tile_collision_mask,
    walking_speed_modifier = 1.3,
    layer = 80,
    layer_group = "ground-artificial",
    decorative_removal_probability = 0.25,
    variants = {
      transition = tile_graphics.generic_texture_on_concrete_transition,
      material_background = {
        picture = "__base__/graphics/terrain/concrete/refined-concrete.png",
        count = 8,
        scale = 0.5,
      },
    },
    walking_sound = tile_sounds.walking.concrete,
    driving_sound = tile_sounds.driving.concrete,
    build_sound = tile_sounds.building.concrete,
    map_color = {80, 92, 112},
    vehicle_friction_modifier = 0.8,
    trigger_effect = tile_trigger_effects.concrete_trigger_effect(),
  },
  {
    type = "item",
    name = "interplanetary-artillery-foundation-tile",
    icon = "__base__/graphics/icons/refined-concrete.png",
    subgroup = "terrain",
    order = "b[concrete]-z[interplanetary-artillery-foundation-tile]",
    inventory_move_sound = item_sounds.concrete_inventory_move,
    pick_sound = item_sounds.concrete_inventory_pickup,
    drop_sound = item_sounds.concrete_inventory_move,
    stack_size = 100,
    weight = 10 * kg,
    place_as_tile = {
      result = "interplanetary-artillery-foundation-tile",
      condition_size = 1,
      condition = {layers = {water_tile = true}},
    },
    random_tint_color = {0.45, 0.52, 0.68, 1},
  },
  {
    type = "recipe",
    name = test_shell_name,
    category = foundation_recipe_category,
    enabled = true,
    hidden = true,
    hide_from_signal_gui = true,
    allow_as_intermediate = false,
    allow_decomposition = false,
    energy_required = 15,
    ingredients = {
      {type = "item", name = "iron-plate", amount = 100},
    },
    results = {
      {type = "item", name = test_shell_name, amount = 1},
    },
  },
  {
    type = "item",
    name = test_shell_name,
    icon = "__base__/graphics/icons/artillery-shell.png",
    hidden = true,
    subgroup = "ammo",
    order = "z[interplanetary-artillery]-a[test-shell]",
    inventory_move_sound = item_sounds.ammo_large_inventory_move,
    pick_sound = item_sounds.ammo_large_inventory_pickup,
    drop_sound = item_sounds.ammo_large_inventory_move,
    stack_size = 1,
    weight = 100 * kg,
  },
  {
    type = "recipe",
    name = "interplanetary-artillery-foundation-tile",
    enabled = true,
    energy_required = 0.25,
    ingredients = {
      {type = "item", name = "stone-brick", amount = 1},
      {type = "item", name = "iron-plate", amount = 1},
    },
    results = {
      {type = "item", name = "interplanetary-artillery-foundation-tile", amount = 1},
    },
  },
  {
    type = "item",
    name = "interplanetary-artillery-foundation",
    icon = "__base__/graphics/icons/rocket-silo.png",
    subgroup = "production-machine",
    order = "z[interplanetary-artillery]-a[foundation]",
    inventory_move_sound = item_sounds.mechanical_large_inventory_move,
    pick_sound = item_sounds.mechanical_large_inventory_pickup,
    drop_sound = item_sounds.mechanical_large_inventory_move,
    stack_size = 5,
    place_result = "interplanetary-artillery-foundation",
  },
  {
    type = "recipe",
    name = "interplanetary-artillery-foundation",
    enabled = true,
    energy_required = 2,
    ingredients = {
      {type = "item", name = "steel-plate", amount = 20},
      {type = "item", name = "concrete", amount = 50},
    },
    results = {
      {type = "item", name = "interplanetary-artillery-foundation", amount = 1},
    },
  },
  {
    type = "assembling-machine",
    name = "interplanetary-artillery-foundation",
    icon = "__base__/graphics/icons/rocket-silo.png",
    flags = {"placeable-player", "player-creation"},
    order = "z[interplanetary-artillery]-a[foundation]",
    minable = {mining_time = 1, result = "interplanetary-artillery-foundation"},
    max_health = 5000,
    corpse = "rocket-silo-remnants",
    dying_explosion = "rocket-silo-explosion",
    collision_box = {{-7.49, -7.49}, {7.49, 7.49}},
    selection_box = {{-7.5, -7.5}, {7.5, 7.5}},
    tile_width = 15,
    tile_height = 15,
    tile_buildability_rules = {
      {
        area = {{-7.49, -7.49}, {7.49, 7.49}},
        required_tiles = {layers = {[foundation_tile_layer] = true}},
        remove_on_collision = false,
      },
    },
    damaged_trigger_effect = hit_effects.entity(),
    impact_category = "metal-large",
    crafting_categories = {foundation_recipe_category},
    fixed_recipe = test_shell_name,
    crafting_speed = 1,
    energy_source = {
      type = "electric",
      usage_priority = "secondary-input",
      drain = "0W",
    },
    energy_usage = "1kW",
    open_sound = sounds.machine_open,
    close_sound = sounds.machine_close,
    allowed_effects = {},
    graphics_set = {
      animation = {
        layers = {
          {
            filename = "__base__/graphics/entity/rocket-silo/06-rocket-silo.png",
            priority = "extra-high",
            width = 608,
            height = 596,
            shift = util.by_pixel(3, -1),
            scale = 0.9,
          },
          {
            filename = "__base__/graphics/entity/rocket-silo/00-rocket-silo-shadow.png",
            priority = "medium",
            width = 612,
            height = 578,
            draw_as_shadow = true,
            shift = util.by_pixel(7, 2),
            scale = 0.9,
          },
        },
      },
    },
  },
  {
    type = "item",
    name = "interplanetary-artillery-cannon",
    icon = "__base__/graphics/icons/artillery-turret.png",
    subgroup = "defensive-structure",
    order = "z[interplanetary-artillery]-b[cannon]",
    inventory_move_sound = item_sounds.turret_inventory_move,
    pick_sound = item_sounds.turret_inventory_pickup,
    drop_sound = item_sounds.turret_inventory_move,
    stack_size = 5,
    place_result = "interplanetary-artillery-cannon",
  },
  {
    type = "recipe",
    name = "interplanetary-artillery-cannon",
    enabled = true,
    energy_required = 2,
    ingredients = {
      {type = "item", name = "steel-plate", amount = 20},
      {type = "item", name = "iron-gear-wheel", amount = 20},
    },
    results = {
      {type = "item", name = "interplanetary-artillery-cannon", amount = 1},
    },
  },
  {
    type = "container",
    name = "interplanetary-artillery-cannon",
    icon = "__base__/graphics/icons/artillery-turret.png",
    flags = {"placeable-player", "player-creation"},
    order = "z[interplanetary-artillery]-b[cannon]",
    minable = {mining_time = 0.5, result = "interplanetary-artillery-cannon"},
    max_health = 2000,
    corpse = "big-remnants",
    dying_explosion = "medium-explosion",
    collision_box = {{-1.2, -1.2}, {1.2, 1.2}},
    selection_box = {{-1.5, -1.5}, {1.5, 1.5}},
    selection_priority = 60,
    collision_mask = {layers = {[cannon_collision_layer] = true}},
    tile_width = 3,
    tile_height = 3,
    inventory_size = 1,
    open_sound = sounds.metallic_chest_open,
    close_sound = sounds.metallic_chest_close,
    damaged_trigger_effect = hit_effects.entity(),
    impact_category = "metal-large",
    picture = {
      filename = "__base__/graphics/entity/artillery-turret/artillery-turret-base.png",
      priority = "extra-high",
      width = 207,
      height = 199,
      shift = util.by_pixel(0, 3),
      scale = 0.5,
    },
  },
})
