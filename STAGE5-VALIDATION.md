# Stage 5 - Targeting Remote UX Validation

## Conclusion

Native artillery-remote capsule: **alternative recommended**. The user tested
the unfinished candidate and reported the native no-artillery-in-range refusal
on another surface. This is not a Monolith range validation failure. The native
action requires eligible native artillery; Monolith deliberately has none.

Implemented alternative: dedicated **selection-tool + spawn-item shortcut**.
Input routing and the existing firing architecture are tested. The complete
shortcut/map/planet/mouse workflow is **not yet validated**. Stage 5 UX acceptance
therefore remains open, rather than treating headless firing as mouse evidence.

## Vanilla artillery remote investigation

Inspected installed Factorio 2.0.77 data:

- `base/prototypes/item.lua`: `artillery-targeting-remote` is a capsule with
  `capsule_action.type = "artillery-remote"`, flare `artillery-flare`, and
  `only-in-cursor`, `not-stackable`, `spawnable` flags.
- `base/prototypes/entity/entities.lua`: `artillery-flare` is an artillery-flare
  entity, with 3600-tick life and one shot per flare. It does not declare a
  custom shot category or an arbitrary runtime event callback.
- `base/prototypes/shortcuts.lua`: `give-artillery-targeting-remote` uses
  `spawn-item`, gated by artillery technology in vanilla.
- The capsule action exposes the flare and failure sound, not an arbitrary
  script target callback. A dedicated category cannot bypass native eligibility.
- `on_trigger_created_entity` is opt-in on create-entity trigger effects; it is
  not a universal entity-created event. Native flare interception was not proven.
- `on_player_used_capsule` has position/player/item but no surface field. It is
  not adopted as a workaround for a native action that has already been refused.

References (online pages may describe newer versions; installed data and actual
2.0.77 load tests are the version-specific evidence):

- https://lua-api.factorio.com/latest/types/ArtilleryRemoteCapsuleAction.html
- https://lua-api.factorio.com/latest/prototypes/ArtilleryFlarePrototype.html
- https://lua-api.factorio.com/latest/types/CreateEntityTriggerEffectItem.html
- https://lua-api.factorio.com/latest/events.html#on_player_used_capsule
- https://lua-api.factorio.com/latest/events.html#on_player_selected_area
- https://forums.factorio.com/viewtopic.php?t=119278

## Shortcut and Targeting Remote

`interplanetary-artillery-targeting` clones the native spawn-item shortcut,
without its technology gate. It spawns the dedicated
`interplanetary-artillery-targeting-remote` selection-tool. It is spawnable and
cursor-only; no native artillery action is invoked. Base graphics are referenced
in place, not redistributed. The old hidden tool remains a save-compatible alias.

Ctrl+Shift+F registers the hovered Cannon only. Q and cursor/controller changes
do not clear the registered source. Registration is per player; a new explicit
registration replaces only that player's source. The shortcut can reacquire the
tool after switching surfaces without requiring another hover over the Cannon.

## Runtime target detection

Normal and alternate selected-area events supply `event.surface`, `event.area`
and `event.player_index`. The rectangle center goes to the existing `firing.fire`.
The player's current/physical surface is not substituted. Each completed
selection requests one shot; use a short drag if a plain click does not complete
a selection. Invalid source/attachment/force, empty magazine and ungenerated
impact footprint still reject without consuming ammunition.

## Remote View

Automatic cursor retention, planet switching and actual mouse events in map or
remote view remain untested with this final implementation. The Windows capture
tool failed with unsupported-interface `SetIsBorderRequired` (0x80004002).
An earlier graphical probe also failed before target testing due to a nil cursor
stack during player setup; that unfinished probe was removed, not counted as a
pass. Earlier fixture-ready markers are not Stage 5 acceptance results.

Required manual sequence after restarting Factorio:

1. Hover the Cannon and press Ctrl+Shift+F; verify source-registration notice.
2. Equip Monolith Targeting from the shortcut bar.
3. Open map/remote view and change to an accessible planet surface.
4. If the cursor disappears, press the same shortcut on the destination surface.
5. Select generated ground, using a short drag if necessary.
6. Verify firing notice, one loaded shot consumed and impact after 15 seconds.
7. Repeat on Nauvis (5 seconds), with no ammunition, after source destruction,
   and after Q. Verify no native artillery-range message.

Uncharted mouse targeting and multiple connected clients remain unverified.
The mod neither unlocks planets nor reveals or generates target terrain.

## Vanilla artillery isolation

The final remote creates no artillery flare and has no artillery-remote action.
No Monolith ammo category is needed. Vanilla remote events do not enter the
Monolith selected-area handler. This removes the native artillery AI connection
by construction; simultaneous real-client vanilla artillery use is not tested.

## Regression

- `lua tests/targeting-unit.lua`: passed. New remote routes event surface and
  coordinates to real firing validation, consumes ammunition, creates a
  900-tick inter-surface shot, rejects empty/invalid/wrong-force sources, and
  preserves independent player registrations. Player surface differs from target.
- Factorio 2.0.77 Stage 4 headless: base and Space Age passed initial and actual
  in-flight reload. Covers production, same/inter-surface shots, concurrent
  destinations, source independence, target delete/clear, uncharted targets and
  ungenerated rejection. Space Age destinations include Vulcanus and Gleba.
- Loading these fixtures also validates the new remote and shortcut prototypes.
- Stage 3 headless also passed on base and Space Age, including actual reload,
  Foundation tile restrictions, reciprocal attachment, two-shot production
  stop/resume, damage policy and source-independent impacts.
- Headless callers are adapters, not mouse-driven LuaPlayers; these tests do
  not prove cursor retention or shortcut input.

## Performance and save compatibility

No new tick scan or persistent table. Existing shot buckets, source indices,
target indices, ammunition and source-independent impact logic are unchanged.
The experimental capsule changes prototype type under the same item name; an
existing experimental cursor may need clearing and reacquiring after reload.
The experimental flare/category are removed. Existing installations and in-flight
shots do not depend on them. Upgrade from an actual user save remains a manual test.

## Files and limitations

- `data.lua`: dedicated remote/shortcut, removal of native capsule candidate and
  Q-linked source cancellation input.
- `scripts/firing.lua`: source-only registration and new/legacy event routing.
- `locale/en`, `locale/ja`: source-registration and shortcut labels.
- `tests/targeting-unit.lua`: routing, source retention and real firing checks.
- The existing Stage 3/4 runner is unchanged; the unfinished UI probe was removed.
- `SPEC.md`: Stage 5 and provisional fallback UX; no final targeting GUI decision.

Final cursor UX, unvisited planet access, ungenerated targeting, final flight
times/damage/friendly fire remain unresolved. Shared knowledge records only the
reusable native remote restriction and event-driven alternative.
