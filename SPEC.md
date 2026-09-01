# SPEC.md

## 1. Project

**Mod name:** Interplanetary Artillery
**Game:** Factorio 2.0 / Space Age
**Primary weapon:** Monolith-class Interplanetary Cannon
**Japanese name:** モノリス級惑星間砲

Interplanetary Artillery adds extremely large strategic artillery installations intended for very long-range and, eventually, interplanetary bombardment.

The mod is inspired by fictional super-artillery concepts such as Stonehenge, but all entities, naming, mechanics, graphics, and implementation should be treated as original designs for the Factorio universe.

The primary design principle is:

> A single artillery piece should feel like a major industrial project rather than an ordinary turret.

The weapon is not intended to be a direct replacement or simple upgrade for vanilla artillery.

---

# 2. Current Development Stage

The current goal is **prototype validation only**.

Do not implement the complete interplanetary artillery system yet.

The first implementation should establish and validate the basic entity architecture required for the final design.

The initial prototype must focus on:

1. dedicated foundation tiles;
2. a large Monolith foundation entity;
3. a separate cannon entity placed on the foundation;
4. placement validation between these components;
5. basic recipe/prototype structure;
6. save/load-safe runtime state if runtime state is required.

Interplanetary targeting, projectile simulation, firing effects, charging mechanics, ammunition production, custom GUI, and advanced animation are outside the initial implementation scope unless explicitly requested.

---

# 3. Final Gameplay Concept

The final Monolith-class Interplanetary Cannon is composed of three physical layers:

1. **Monolith Foundation Tile**
2. **Monolith Foundation**
3. **Monolith Cannon**

The player does not place a complete cannon as a single item.

Construction proceeds in stages:

```text
Prepare construction site
        ↓
Place Monolith Foundation Tiles
        ↓
Build Monolith Foundation
        ↓
Install Monolith Cannon
        ↓
Supply materials and power
        ↓
Produce / load ammunition
        ↓
Charge weapon
        ↓
Fire
```

This staged construction is a core part of the mod design and should not be replaced with a single-placeable artillery entity.

---

# 4. Monolith Foundation Tile

## 4.1 Purpose

The Monolith Foundation Tile represents the specially reinforced ground required to support the cannon.

The Monolith Foundation may only be constructed on a valid area covered by this tile.

The tile exists primarily to:

* make site preparation part of construction;
* impose an additional resource cost;
* visually distinguish artillery installations;
* prevent the cannon from being casually placed anywhere;
* provide a foundation for future environmental and planetary restrictions.

## 4.2 Initial Requirements

For the prototype:

* Add a dedicated placeable tile.
* It must have its own item and recipe.
* The Monolith Foundation must verify that its required footprint is covered by the correct tile.
* Placement must fail cleanly if the required foundation tiles are missing.

The exact production cost is not final and may use temporary development values.

## 4.3 Future Requirements

Future versions may restrict placement based on:

* planet;
* surface;
* terrain type;
* artificial platforms;
* environmental conditions.

These restrictions are not part of the initial prototype.

---

# 5. Monolith Foundation

## 5.1 Role

The Monolith Foundation is the primary infrastructure entity of the weapon.

It represents:

* structural support;
* rotation machinery;
* ammunition handling;
* ammunition assembly;
* energy storage;
* cooling systems;
* fire-control equipment.

The final design should treat the foundation as a machine, not merely decorative scenery.

## 5.2 Size

Target footprint:

**15 × 15 tiles**

This value is the current intended design size.

If Factorio prototype limitations make an exact 15 × 15 entity impractical, do not silently change the size.

Report the limitation before changing the specification.

## 5.3 Placement

The Monolith Foundation:

* must require Monolith Foundation Tiles beneath its required footprint;
* must not be placeable when that requirement is not satisfied;
* must use normal Factorio ghost/build workflows where practical;
* should remain compatible with construction robots.

The exact tile coverage rule should initially be:

> Every tile inside the required structural footprint must be a valid Monolith Foundation Tile.

Do not accept partial coverage.

## 5.4 Entity Type

The exact prototype type is not permanently fixed yet.

The preferred architecture should support the foundation eventually acting as a specialized ammunition manufacturing machine.

A `rocket-silo`-based implementation is currently a candidate because the final design requires:

* visible production progress;
* resource consumption;
* production of extremely large ammunition;
* staged readiness;
* a machine-like GUI.

However:

> Do not commit the final architecture to `rocket-silo` until its suitability has been validated.

If `rocket-silo` introduces undesirable hard-coded behavior or prevents required mechanics, an alternative architecture such as an assembling-machine-based entity plus runtime logic/custom GUI may be used.

The prototype test should help determine which architecture is appropriate.

---

# 6. Monolith Cannon

## 6.1 Role

The Monolith Cannon is the actual weapon assembly installed on top of a completed Monolith Foundation.

It represents:

* barrel;
* elevation mechanism;
* firing mechanism;
* recoil assembly;
* high-energy launch hardware.

The Foundation and Cannon are intentionally separate entities.

## 6.2 Placement Restriction

The Monolith Cannon may only be placed:

* on a valid Monolith Foundation;
* at the designated mounting position;
* with the required positional alignment.

It must not be placeable independently on ordinary terrain.

## 6.3 Relationship to Foundation

A Cannon belongs to exactly one Foundation.

A Foundation may support at most one Cannon.

The pair should be treated logically as one artillery installation even though they are separate Factorio entities.

The runtime implementation must prevent:

* multiple Cannons attaching to one Foundation;
* one Cannon attaching to multiple Foundations;
* orphaned entity references after mining or destruction.

## 6.4 Destruction and Removal

The long-term intended behavior is:

* Cannon destruction does not automatically destroy the Foundation.
* The Cannon may be rebuilt on an intact Foundation.
* Foundation destruction invalidates the attached Cannon.

For the prototype, safe and deterministic cleanup is more important than final visual behavior.

No invisible or orphaned entities may remain after mining, destruction, script removal, or entity replacement.

For the prototype, mining a Foundation that has an attached Cannon should also
mine the Cannon and return its item to the mining player or robot where
possible. Destructive removal such as damage death or script destruction may
delete the attached Cannon instead of refunding it.

---

# 7. Ammunition Concept

## 7.1 Final Design

The Monolith does not primarily consume completed artillery shells delivered by inserters.

Instead, the Foundation receives raw or intermediate materials and internally assembles its dedicated ammunition.

This is intended to turn ammunition supply into a logistics problem.

Example material categories may eventually include:

* tungsten products;
* explosives;
* uranium;
* superconductors;
* rocket fuel;
* advanced structural materials.

Exact ingredients and quantities are not yet specified.

## 7.2 Internal Ammunition Capacity

Current intended maximum:

**2 completed shots per artillery installation**

Conceptually:

```text
[ READY ][ READY ]
```

After firing:

```text
[ READY ][ EMPTY ]
```

and subsequently:

```text
[ PRODUCING ][ EMPTY ]
```

or equivalent.

The player should eventually be able to see the progress of the next round being assembled.

## 7.3 Ammunition Representation

The final design should preferably avoid ordinary inventory behavior where the player can casually carry large numbers of completed interplanetary shells.

Possible implementations include:

* internal silo-style production state;
* hidden ammunition products;
* runtime-maintained loaded-shot count.

This decision is not final.

For the initial prototype, do not implement the complete ammunition system unless explicitly requested.

---

# 8. Energy System

The Monolith is intended to require extreme amounts of electrical energy.

Two energy demands are conceptually separate:

### Ammunition production

Power consumed while manufacturing the next shot.

### Weapon charging

Large amounts of energy accumulated before firing.

The final weapon may require energy storage measured in tens of gigajoules or more.

Exact values are not yet fixed.

The energy requirement should be large enough that firing multiple Monolith Cannons has noticeable consequences for the player's power infrastructure.

For example, an eight-gun installation should require deliberate power-generation planning.

The initial prototype does not need to implement the complete charging system.

---

# 9. Firing Model

## 9.1 General Role

The Monolith is a strategic weapon.

It should not behave like a rapidly firing defensive turret.

Expected characteristics:

* extremely long range;
* very slow reload;
* very high per-shot cost;
* very high power consumption;
* large impact area;
* deliberate target selection.

## 9.2 Same-Surface Fire

A future version should support extremely long-range bombardment on the same surface.

The expected range should greatly exceed vanilla artillery.

Exact range is not yet specified.

## 9.3 Interplanetary Fire

The defining late-game feature is firing from one planetary surface to another.

Example:

```text
Nauvis
   ↓
Monolith Cannon
   ↓
Interplanetary shot
   ↓
travel / delay
   ↓
Gleba
   ↓
impact
```

The projectile does not necessarily need to physically exist as a Factorio projectile during the entire interplanetary journey.

A runtime event/state representation is acceptable.

Possible eventual sequence:

1. select destination planet;
2. select target coordinates;
3. validate ammunition;
4. validate charge;
5. fire;
6. record shot in flight;
7. calculate travel time;
8. resolve impact on destination surface.

## 9.4 Unexplored Areas

Interplanetary fire may eventually permit bombardment of areas that have not been charted by the player.

This is intentional.

Exact targeting and information rules are not yet defined.

Potential future systems include:

* blind bombardment;
* coordinate targeting;
* reconnaissance;
* target uncertainty;
* temporary impact observation.

Do not implement any of these until their rules are explicitly specified.

---

# 10. Multiple Cannons

Each Monolith Cannon is independent.

The mod must not require an eight-cannon formation.

One Cannon is a complete usable weapon.

Players may construct:

* one cannon;
* several cannons;
* an eight-cannon circular installation inspired by super-artillery complexes;
* any other layout allowed by terrain and logistics.

An eight-gun arrangement is an emergent player-created installation, not a special hard-coded entity.

This is important.

Do not implement an "eight cannon set bonus" or mandatory Stonehenge layout unless explicitly added to this specification later.

---

# 11. Graphics Architecture

Final graphics are not available yet.

Development graphics may use placeholders.

The implementation must therefore avoid relying on final sprite dimensions or animation frame counts.

## 11.1 Intended Visual Structure

The completed weapon should visually consist of several layers:

```text
Foundation / reinforced site
        +
Rotating cannon structure
        +
Elevating barrel
        +
Charging effects
        +
Muzzle flash
        +
Recoil
        +
Smoke / dust / shock effects
```

The foundation should remain largely static.

The Cannon should eventually support:

* rotation;
* barrel elevation;
* recoil;
* firing effects.

## 11.2 Scale

Although the structural footprint is approximately 15 × 15 tiles, visual elements such as the barrel may extend significantly outside that footprint.

The final cannon may visually reach approximately 30–40 tiles or more in overall length.

Collision size and sprite size do not need to match.

## 11.3 Prototype Graphics

For early testing:

* use simple placeholder graphics;
* prioritize readable entity boundaries;
* clearly distinguish Foundation and Cannon;
* do not spend development effort on polished animation.

Gameplay architecture must be validated before final graphical production begins.

---

# 12. Naming

Current canonical naming:

### Mod

**Interplanetary Artillery**

### Weapon class

**Monolith-class Interplanetary Cannon**

Japanese:

**モノリス級惑星間砲**

### Current provisional entity names

Internal prototype names should use the `interplanetary-artillery-` prefix.

Recommended prototype names:

```text
interplanetary-artillery-foundation-tile
interplanetary-artillery-foundation
interplanetary-artillery-cannon
```

Associated item and recipe names should use the same names where practical.

Do not use `stonehenge` as an internal canonical identifier.

Stonehenge is an inspiration, not the identity of this mod.

---

# 13. Prototype Test Scope

The first Codex implementation should create only the minimum system necessary to answer the following questions:

### Test A — Foundation tile

Can a custom reinforced tile be created, placed, mined/replaced, blueprinted, and handled correctly by construction robots?

### Test B — Large Foundation

Can a roughly 15 × 15 Foundation entity be reliably created and placed?

### Test C — Tile validation

Can Foundation placement reliably require the entire specified area to consist of Monolith Foundation Tiles?

### Test D — Cannon attachment

Can a separate Cannon entity be placed only at the correct location on an existing Foundation?

### Test E — Entity relationship

Can Foundation ↔ Cannon relationships remain valid through:

* building;
* mining;
* destruction;
* robot construction;
* robot deconstruction;
* save/load.

### Test F — Future production architecture

Determine whether a `rocket-silo`-derived Foundation is technically suitable for later ammunition production and visible production progress.

Do not implement the full ammunition system merely to complete Test F.

A minimal experimental implementation is acceptable if necessary to evaluate silo behavior.

---

# 14. Explicitly Out of Scope for Initial Prototype

Do not implement these systems unless separately requested:

* interplanetary targeting;
* inter-surface projectile travel;
* same-surface artillery targeting;
* enemy auto-targeting;
* custom target-selection GUI;
* ammunition balance;
* final ammunition recipes;
* two-shot magazine logic;
* capacitor charging;
* cooling;
* firing;
* damage;
* crater generation;
* map reveal;
* reconnaissance;
* custom firing effects;
* recoil animation;
* elevation animation;
* final graphics;
* sound design;
* eight-gun coordination;
* technology progression;
* final production costs;
* compatibility with other mods.

Stub code for these systems should also be avoided unless required by the prototype architecture.

---

# 15. Implementation Principles

## 15.1 Specification

This file is the source of truth for intended project behavior.

Do not introduce gameplay behavior that contradicts this specification.

If implementation requires a behavior that is not defined here, report the ambiguity rather than inventing a permanent rule.

## 15.2 Factorio API

Prefer standard Factorio prototype and runtime APIs.

Do not depend on unsupported engine behavior.

Do not assume arbitrary control over Factorio internals such as rendering, collision, placement, GUI, or artillery behavior.

If an intended feature cannot be implemented using supported Factorio 2.0 mod APIs, document the limitation and propose alternatives.

## 15.3 Performance

Runtime processing must be event-driven wherever practical.

Avoid:

* scanning all Monolith entities every tick;
* scanning large map regions repeatedly;
* per-tick surface searches;
* unnecessary `find_entities_filtered` loops;
* persistent rendering updates when nothing has changed.

The final system may involve very large structures and multiple planets, so architecture should remain UPS-conscious from the beginning.

## 15.4 State

Runtime state must use supported persistent mod storage.

Entity references and identifiers must be validated before use.

State cleanup must occur when entities are:

* mined;
* destroyed;
* script-destroyed;
* replaced;
* invalidated.

Save/load behavior must be deterministic.

## 15.5 Multiplayer

Architecture must not depend on a single player.

Any runtime behavior should be deterministic and compatible with multiplayer unless a feature is explicitly documented otherwise.

---

# 16. Development Priority

Current priority order:

```text
1. Entity architecture
2. Construction workflow
3. Foundation tile requirement
4. Foundation / Cannon relationship
5. Evaluate rocket-silo production architecture
6. Placeholder graphics
------------------------------
Future development
------------------------------
7. Ammunition manufacturing
8. Energy / charging
9. Same-surface firing
10. Interplanetary targeting
11. Interplanetary firing
12. Damage and impact system
13. Visual effects and animation
14. Balancing
15. Final graphics and audio
```

Do not skip directly to later systems before the basic construction architecture is proven stable.

---

# 17. Core Design Rule

When choosing between two implementations, prefer the one that preserves this experience:

> Building and firing a Monolith-class Interplanetary Cannon should feel like operating a massive industrial installation, not placing a larger artillery turret.

The logistics, infrastructure, preparation, and scale are part of the weapon.
