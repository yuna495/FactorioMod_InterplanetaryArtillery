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

## 2. Current Development Stage

The current goal is **Automatic firing, route-based flight and impact countdown**.

Do not implement the complete interplanetary artillery system yet.

Preserve the validated basic entity architecture required for the final design.

The established prototype consists of:

1. dedicated foundation tiles;
2. a large Monolith foundation entity;
3. a separate cannon entity placed on the foundation;
4. placement validation between these components;
5. basic recipe/prototype structure;
6. save/load-safe runtime state;
7. Foundation-based ammunition production and a two-shot internal magazine.

Stages 1 and 2 have validated the 15x15 Foundation, dedicated tile requirement,
separate Cannon, runtime attachment, assembling-machine production, hidden test
shell, and persistent two-shot magazine with stop/resume behavior.
Stage 3 validated manual same-surface targeting, shot creation and consumption,
scheduled delayed impacts, save/load, source-independent shots and generated
but uncharted targets. These are the current validated architecture.
Stage 4 has validated the same architecture across different target surfaces
in Factorio 2.0.77, including Nauvis to Vulcanus and Gleba, concurrent shots,
source removal and an actual in-flight save/reload. See STAGE4-VALIDATION.md.
Final planet targeting UX, charging and advanced animation remain future scope.

Stage 5 investigates a dedicated shortcut-spawned targeting remote. The Stage 4
mouse UX was reported to lose its cursor when entering map/remote view; the
inter-surface shot architecture itself remains validated. The first candidate
was a vanilla-derived artillery-remote capsule with a dedicated flare/category.
The decision below replaces that candidate without duplicating firing.
Control + Shift + F registers a source for explicit debug commands only.
Normal shortcut targeting automatically selects a ready Cannon; it ignores
manual registration. Q and view changes do not affect automatic selection.
All clicks must use the existing firing validation and shot architecture.

Stage 5 decision: user testing confirmed the native no-artillery-in-range
refusal. The capsule candidate is rejected. The dedicated remote is a spawnable
selection-tool equipped by a spawn-item shortcut. Its selected-area event
supplies target surface and rectangle center to the existing firing path.
No dedicated flare, ammo category, native artillery action or tick scan is used.
The old hidden tool remains a save-compatible alias, not a second UX.
Actual remote-view mouse operation and automatic cursor carryover remain
unverified; reacquiring the tool through the shortcut needs no manual source.

---

## 3. Final Gameplay Concept

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

## 4. Monolith Foundation Tile

### 4.1 Purpose

The Monolith Foundation Tile represents the specially reinforced ground required to support the cannon.

The Monolith Foundation may only be constructed on a valid area covered by this tile.

The tile exists primarily to:

* make site preparation part of construction;
* impose an additional resource cost;
* visually distinguish artillery installations;
* prevent the cannon from being casually placed anywhere;
* provide a foundation for future environmental and planetary restrictions.

### 4.2 Initial Requirements

For the prototype:

* Add a dedicated placeable tile.
* It must have its own item and recipe.
* The Monolith Foundation must verify that its required footprint is covered by the correct tile.
* Placement must fail cleanly if the required foundation tiles are missing.
* The preferred validated implementation is a dedicated tile collision layer used by `tile_buildability_rules` on the Foundation prototype.

The exact production cost is not final and may use temporary development values.

### 4.3 Occupied Tile Removal

While a Monolith Foundation exists, removing or replacing the required
Foundation Tiles beneath it should not leave the installation in an invalid
state.

The prototype may restore mined Foundation Tiles after tile mining events when
the engine does not provide a true pre-mine rejection point for tiles.

### 4.4 Future Requirements

Future versions may restrict placement based on:

* planet;
* surface;
* terrain type;
* artificial platforms;
* environmental conditions.

These restrictions are not part of the initial prototype.

---

## 5. Monolith Foundation

### 5.1 Role

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

### 5.2 Size

Target footprint:

**15 × 15 tiles**

This value is the current intended design size.

If Factorio prototype limitations make an exact 15 × 15 entity impractical, do not silently change the size.

Report the limitation before changing the specification.

### 5.3 Placement

The Monolith Foundation:

* must require Monolith Foundation Tiles beneath its required footprint;
* must not be placeable when that requirement is not satisfied;
* must use normal Factorio ghost/build workflows where practical;
* should remain compatible with construction robots.

The exact tile coverage rule should initially be:

> Every tile inside the required structural footprint must be a valid Monolith Foundation Tile.

Do not accept partial coverage.

### 5.4 Entity Type

The exact prototype type is not permanently fixed yet.

The preferred architecture should support the foundation eventually acting as a specialized ammunition manufacturing machine.

The current validated first-choice architecture is an `assembling-machine`-based
Foundation plus minimal runtime state, because the final design requires:

* visible production progress;
* resource consumption;
* production of extremely large ammunition;
* staged readiness;
* a machine-like GUI.

`rocket-silo` is no longer the first candidate for the Foundation architecture
until a separate, isolated validation proves that its rocket-part and launch
behavior can be reused without fighting hard-coded silo assumptions.

If the vanilla assembling-machine GUI is not sufficient for the final user
experience, prefer adding a small custom GUI layer over adopting `rocket-silo`
only for its progress presentation.

`rocket-silo` remains a possible future reference for isolated experiments only.

---

## 6. Monolith Cannon

### 6.1 Role

The Monolith Cannon is the actual weapon assembly installed on top of a completed Monolith Foundation.

It represents:

* barrel;
* elevation mechanism;
* firing mechanism;
* recoil assembly;
* high-energy launch hardware.

The Foundation and Cannon are intentionally separate entities.

### 6.2 Placement Restriction

The Monolith Cannon may only be placed:

* on a valid Monolith Foundation;
* at the designated mounting position;
* with the required positional alignment.

It must not be placeable independently on ordinary terrain.

### 6.3 Relationship to Foundation

A Cannon belongs to exactly one Foundation.

A Foundation may support at most one Cannon.

The pair should be treated logically as one artillery installation even though they are separate Factorio entities.

The runtime implementation must prevent:

* multiple Cannons attaching to one Foundation;
* one Cannon attaching to multiple Foundations;
* orphaned entity references after mining or destruction.

### 6.4 Destruction and Removal

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

## 7. Ammunition Concept

### 7.1 Final Design

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

### 7.2 Internal Ammunition Capacity

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

### 7.3 Ammunition Representation

The final design should preferably avoid ordinary inventory behavior where the player can casually carry large numbers of completed interplanetary shells.

The current validated architecture combines:

* hidden ammunition products;
* runtime-maintained loaded-shot count.

This is the current architecture; final ammunition ingredients and balance
remain undecided.

The implemented Stage 2 test loop is retained:

* the Foundation has a dedicated recipe category;
* a hidden test recipe produces `interplanetary-artillery-test-shell`;
* the output item is converted into a `storage`-backed `loaded_shots` count;
* `loaded_shots` is capped at 2;
* the dedicated recipe is fixed and always retained, including at capacity;
* at capacity, set disabled_by_script=true, preserving input inventory and
  in-progress crafting. No recipe removal, progress reset or ingredient spill;
* after consuming a shot, restore the pre-pause script-disabled value and
  resume production monitoring. Other causes of inactivity remain respected;
* persist production_paused and previous_disabled_by_script on each Foundation
  record. A one-time migration reapplies the policy to existing full Foundations;
* the existing 60-tick monitor converts completed products and pauses production.
  A partially started next craft may be retained, but no further craft completes
  while full. The fixed test recipe takes far longer than the monitor interval;
* `/monolith-consume-test-shot` consumes one loaded test shot and allows
  production to resume.

Stage 3 firing consumes the same loaded-shot count and resumes production.
Charging, balancing and final ammunition logistics remain out of scope.

---

## 8. Energy System

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

## 9. Firing Model

### 9.1 General Role

The Monolith is a strategic weapon.

It should not behave like a rapidly firing defensive turret.

Expected characteristics:

* extremely long range;
* very slow reload;
* very high per-shot cost;
* very high power consumption;
* large impact area;
* deliberate target selection.

### 9.2 Same-Surface Fire

Stage 3 supports manual long-range bombardment on the same surface.

The expected range should greatly exceed vanilla artillery.

Exact range is not yet specified.

#### Validated Firing Architecture (Stages 3 and 4)

* Normal targeting requires no source registration. Scan registered Cannons
  only on firing requests, validating entities, reciprocal attachment, same
  force and loaded_shots >= 1. Prefer ready Cannons on the target surface.
  Only when none exist, consider other surfaces with valid planetary routes.
* Within the selected group, sort unit numbers and choose the first greater
  than the last successful selection, wrapping at the end. Persist the last ID
  per force, target surface and local/remote group in storage.firing_round_robin.
  Rejections do not advance rotation; invalid/empty Cannons are skipped.
  Force merges reset rotation; surface removal clears its target-group state.
* A cursor-only selection tool selects a ground point (or the center of a
  dragged rectangle). Each completed selection requests one shot.
* Manual source registration is retained per player solely for debug commands
  and focused explicit-source tests, never for shortcut target selection.
* `/monolith-fire-test x y` targets coordinates using that explicitly selected
  Cannon; `/monolith-shot-status` reports its identity and owned in-flight shots.
* Validate live Cannon and Foundation, reciprocal attachment, matching position,
  force and surface, player ownership, at least one loaded shot, and finite
  target coordinates on the chosen target surface before consuming ammunition.
  The Cannon and Foundation must share a surface; the target need not share it.
* No weapon range limit is imposed. The impact footprint must remain within
  the engine's +/-1,000,000 tile bounds and configured finite map dimensions.
* Generated but uncharted terrain is allowed. The tool does not reveal terrain;
  coordinate commands support blind targeting independently of map UI limits.
* All chunks touched by the radius-6 impact footprint must already be generated.
  Ungenerated targets are rejected without ammunition loss. Stage 4 does not
  request chunk generation, avoiding map-generation stalls and distant expansion.
* Classify every new shot as same-surface or interplanetary. Same-surface shots
  need no planet and use Euclidean distance at 300 tiles/s, rounded upward to
  whole ticks with a minimum of 6 ticks. Interplanetary shots require both
  surfaces to belong to valid planets and a finite shortest connection path.
  Use the bidirectional space-connection graph (including intermediate space
  locations), with positive finite lengths in km, computed on request by
  Dijkstra. No unlock/visit requirement is added. Missing routes or non-planet
  endpoints reject without ammunition consumption. Speed is 500 km/s, rounding
  upward to ticks (minimum 1); surface tile distance is not added.
* Consume one shot, resume production and persist flight_type, flight_ticks,
  distance_tiles or route_distance_km alongside existing source/target state.
  Notify firing type and ETA to one decimal place.
* Persist source Cannon/Foundation IDs, source force index, source/target surface
  indices and copied positions, player index, fire_tick and impact_tick in
  `storage.in_flight_shots[id]`. No live source entity is needed for impact.
* `storage.shots_by_tick[impact_tick]` contains shot IDs. Every tick looks up
  only the current bucket; no Foundation or in-flight list scan is performed.
* Impact creates base `big-explosion` and deals 250 explosion damage in radius 6
  to other non-neutral forces that are neither friends nor cease-fire partners
  of the source force at impact time. Self/allied/neutral entities are excluded.
  Ordinary damage resistances apply. No terrain destruction. Only interplanetary
  impacts additionally chart the local area as specified below.
* Fired shots survive source mining/destruction and save/load with original
  deadlines. Target surface deletion/clearing or loss of generated impact chunks
  cancels the shot with notification and no refund. Force merging transfers
  attribution to the destination force. Missing source force cancels safely.

Speeds above are the current specified values; radius and damage remain test values.

Each shot owns a localized rendering text at its target, visible to its source
force in game and map render modes, with zoom-independent screen size. Update
every 60 ticks while remaining time is at least 600 ticks, every 6 ticks below
that boundary (schedule the boundary transition precisely). Store render objects
and a countdown_by_tick schedule; each tick only looks up the due buckets.
Destroy text on impact/cancellation/invalid destination and remove its scheduled
update. Multiple shots have independent objects, even at identical coordinates;
overlapping labels are acceptable for this placeholder, not a final GUI.
Save/load preserves objects and buckets. One-time state migration adds displays
to legacy shots, classifies them and preserves their original impact deadlines;
legacy missing route distances remain unknown rather than fabricated. Already
fired legacy non-planet shots are grandfathered. Force merges retarget visibility.

#### Visual Projectiles and Impact Observation

Same-surface shots create an independent artillery-projectile visual using base
shell, shadow and chart-picture assets. It has no action/final_action, but uses
native reveal_map=true for vanilla-style flight-path observation. Native chart
requests were verified in 2.0.77 headless tests; actual Map/Remote View appearance
still needs client confirmation. No Lua flight-path polling or generation calls
are added. This is distinct from interplanetary impact-only reveal.
Speed is distance_tiles/flight_ticks (at most 5 tiles/tick), matching
the rounded 300 tiles/s flight with the minimum flight-time rule.
Native position quantization may cause small visual timing differences
(within 3 ticks in the 6000-tile test). Zero-distance
visuals may disappear immediately. The shot state, not projectile arrival, owns
all damage, explosion and impact timing. Save/load retains the entity reference;
losing a visual never cancels a shot. Impact/cancel removes any surviving visual.
Legacy in-flight shots need not gain a reconstructed flying visual.

Interplanetary shots have no travelling source-side entity. At accepted impact,
spawn a dedicated harmless impact visual (reveal_map=false) one tile north of the target, moving toward it
over approximately 3 ticks. This is a brief near-vertical visual cue, not a 3D
descent simulation. Store its entity and surface in visual_cleanup_by_tick and
remove it after 3 ticks or earlier on target surface delete/clear. Queues and
entities persist through saves; only the current cleanup bucket is checked.

Interplanetary impact charts only generated chunks whose offsets from the target
chunk satisfy dx^2+dy^2 <= 2^2 (13 chunks maximum). Radius 2 chunks is provisional.
Chart each included chunk explicitly for the source force, producing a coarse
circular footprint with no flight-path reveal, no generation requests and no
continuous radar observation. Missing surrounding chunks stay ungenerated.
Short-lived native reveal_map probes at the target did not demonstrate completed
charting in headless 2.0.77. Explicit chart requests make the impact footprint
independent of native reveal radius and projectile lifetime. Chart requests may
remain pending in headless tests; requested footprint and completed chart are
distinct verification results.

### 9.3 Interplanetary Fire

#### Stage 4 Prototype

Same-surface and inter-surface shots use the same `firing.fire()` validation,
ammunition consumption and `storage.in_flight_shots` / `storage.shots_by_tick`
architecture. No separate planetary shot table is introduced.

The targeting tool uses `on_player_selected_area.surface` and `.area` as the
destination, never the Cannon surface or the character's physical surface.
The intended operation is to equip the shortcut remote, enter remote view, switch
surface, and select ground. Native remote-view cursor carryover and mouse input
remain explicit in-game verification items; re-equipping through the shortcut
does not require a source. The mod does not unlock or open remote surfaces itself.

`/monolith-fire-surface-test <surface-name-or-index> <x> <y>` uses the explicitly
selected Cannon and the ordinary firing path. The surface must already exist.
Names containing spaces may be supplied as the entire prefix before x and y,
optionally surrounded by double quotes. Exact names take precedence over indices.
The existing `/monolith-fire-test x y` uses the current controller's surface.
Notifications identify destination surface and actual test flight time.

Deleting or clearing only the source surface does not cancel an accepted shot
to another surface. Deleting/clearing the target cancels it without refund;
if source and target coincide, the target cancellation rule applies. Source
force attribution and impact-time diplomacy rules remain unchanged.

An existing planet surface, force unlock state, physical visitation, charting,
chunk generation and remote-view accessibility are separate conditions. Runtime
firing currently requires an existing generated target, not a visit, unlock or
chart check. This is a test policy, not the final progression/access policy.
The mod does not create missing planet surfaces or generate their chunks.
Final unvisited-planet eligibility and asynchronous generation policy remain open.

An isolated 2.0.77 test also validated request-only chunk generation with later
`on_chunk_generated` notification. This is not enabled in the weapon: readiness
deadlines, outstanding-request limits and missing-at-impact behavior need a
future specification. API event routing is covered by mocked handler tests;
native remote-view mouse selection and cursor carryover are not yet validated.

#### Future Design

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

### 9.4 Unexplored Areas

Interplanetary fire may eventually permit bombardment of areas that have not been charted by the player.

This is intentional.

Exact targeting and information rules are not yet defined.

Potential future systems include:

* blind bombardment;
* coordinate targeting;
* reconnaissance;
* target uncertainty;
* temporary impact observation.

Beyond the current generated-but-uncharted coordinate targeting, these systems
remain future scope.

---

## 10. Multiple Cannons

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

## 11. Graphics Architecture

Final graphics are not available yet.

Development graphics may use placeholders.

The implementation must therefore avoid relying on final sprite dimensions or animation frame counts.

### 11.1 Intended Visual Structure

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

### 11.2 Scale

Although the structural footprint is approximately 15 × 15 tiles, visual elements such as the barrel may extend significantly outside that footprint.

The final cannon may visually reach approximately 30–40 tiles or more in overall length.

Collision size and sprite size do not need to match.

### 11.3 Prototype Graphics

For early testing:

* use simple placeholder graphics;
* prioritize readable entity boundaries;
* clearly distinguish Foundation and Cannon;
* do not spend development effort on polished animation.

Gameplay architecture must be validated before final graphical production begins.

---

## 12. Naming

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

## 13. Prototype Test Scope

Stages 1 through 3 establish the following foundation; preserve these behaviors:

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

### Test F — Validated production architecture

Retain the validated `assembling-machine` Foundation, visible production
progress and the two-shot stop/consume/resume runtime loop.

Do not implement the full ammunition system merely to complete Test F.

### Test G - Same-surface firing

Validate source selection, zero-ammo refusal, two successive shots, exact
distance-based impacts, damage filtering, production resumption, save/load in flight,
source removal in flight, and generated uncharted distant targets.

---

### Test H - Inter-surface firing

Validate planetary destination surfaces, route-based impact, simultaneous local
and remote shots, persistence of surface/position/deadline through save/load,
source removal, source surface removal, target deletion/clearing, unchanged
production resumption, uncharted targets and ungenerated rejection. Test a real
Space Age planet when available; with base only, test local fire and rejection
of non-planet inter-surface fire.

Current focused tests cover automatic priority/rotation, route eligibility and
distance, countdown cadence/cleanup, save/load and production resumption.
Native mouse/view appearance must be distinguished from automated validation.

## 14. Explicitly Out of Scope

Do not implement these systems unless separately requested:

* final planet targeting UX and GUI;
* visible inter-surface projectile travel;
* final speed balancing and orbital mechanics (current speeds are specified above);
* enemy auto-targeting;
* custom target-selection GUI;
* ammunition balance;
* final ammunition recipes;
* capacitor charging;
* cooling;
* crater generation;
* additional map reveal beyond native same-surface projectile observation and
  the local interplanetary impact footprint;
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

## 15. Implementation Principles

### 15.1 Specification

This file is the source of truth for intended project behavior.

Do not introduce gameplay behavior that contradicts this specification.

If implementation requires a behavior that is not defined here, report the ambiguity rather than inventing a permanent rule.

### 15.2 Factorio API

Prefer standard Factorio prototype and runtime APIs.

Do not depend on unsupported engine behavior.

Do not assume arbitrary control over Factorio internals such as rendering, collision, placement, GUI, or artillery behavior.

If an intended feature cannot be implemented using supported Factorio 2.0 mod APIs, document the limitation and propose alternatives.

### 15.3 Performance

Runtime processing must be event-driven wherever practical.

Avoid:

* scanning all Monolith entities every tick;
* scanning large map regions repeatedly;
* per-tick surface searches;
* unnecessary `find_entities_filtered` loops;
* persistent rendering updates when nothing has changed.

The final system may involve very large structures and multiple planets, so architecture should remain UPS-conscious from the beginning.

### 15.4 State

Runtime state must use supported persistent mod storage.

Entity references and identifiers must be validated before use.

State cleanup must occur when entities are:

* mined;
* destroyed;
* script-destroyed;
* replaced;
* invalidated.

Save/load behavior must be deterministic.

### 15.5 Multiplayer

Architecture must not depend on a single player.

Any runtime behavior should be deterministic and compatible with multiplayer unless a feature is explicitly documented otherwise.

---

## 16. Development Priority

Current priority order:

```text
1. Entity architecture
2. Construction workflow
3. Foundation tile requirement
4. Foundation / Cannon relationship
5. Assembling-machine production and two-shot runtime magazine (validated)
6. Placeholder graphics
7. Same-surface firing and delayed test impacts (validated)
8. Inter-surface firing with the same shot state (validated, Stage 4)
------------------------------
Future development
------------------------------
9. Final ammunition manufacturing
10. Energy / charging
11. Final interplanetary targeting UX and distance rules
12. Final damage and impact system
13. Visual effects and animation
14. Balancing
15. Final graphics and audio
```

Do not skip directly to later systems before the basic construction architecture is proven stable.

---

## 17. Core Design Rule

When choosing between two implementations, prefer the one that preserves this experience:

> Building and firing a Monolith-class Interplanetary Cannon should feel like operating a massive industrial installation, not placing a larger artillery turret.

The logistics, infrastructure, preparation, and scale are part of the weapon.
