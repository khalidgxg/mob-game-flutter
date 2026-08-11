# MobRush — Flutter rebuild

A rebuild of the Unity game in [`khalidgxg/mobGame`](https://github.com/khalidgxg/mobGame)
as a Flutter application.

This repository currently contains a **proof of concept**, not the game. Its
only purpose is to answer one question with measurements instead of opinion:
*can the MobRush battle — 350 animated units at once — run at frame rate in
Flutter?*

## Layout

```
packages/mobrush_sim/   Pure Dart. Battle simulation: crowd, Cannon, Gate,
                        EnemyTower, PlayerBase, BattleAbilities. Unit-testable,
                        no Flutter, no Flame, no rendering.
packages/mobrush_data/  Pure Dart. Content models (characters, cannons,
                        abilities, reward rules), loaded from ContentExporter's
                        JSON.
packages/mobrush_save/  Pure Dart. PlayerProfile, ported field-for-field.
apps/poc_battle/        Flutter + Flame. Renders the simulation.
docs/MIGRATION_PLAN.md  The full plan this PoC was built to justify.
```

`packages/mobrush_data` and `packages/mobrush_save` are Phase 1 of the plan —
content and save state moved out of Unity's ScriptableObjects into
engine-independent Dart, mirroring `mobrush_sim`'s shape. Phase 1's content
round-trip is confirmed against a real export from the live Editor, not just
a hand-authored fixture (see `mobrush_data/test/real_export_smoke_test.dart`).

Phase 2's gate is met: `Cannon`, `Gate`, `EnemyTower` + `StageSection`,
`PlayerBase`, and `BattleAbilities` (Freeze/Fireball/Lightning) are ported
and tested against real authored numbers — `CannonLibrary.BuildSpecs()`'s
stats, Stage 1-3's tower healths and escalation recipes, Fireball's maxed
tuning read off a real Shop screenshot — and `BattleRound` wires all five
into one playable round. `test/battle_round_integration_test.dart` plays a
full Stage 1 round headlessly, opening formation through cannon fire
through all three towers falling, and asserts the win. Getting there
surfaced a real gap: mob-vs-mob melee combat had never been ported, so two
clashed mobs locked together forever without ever fighting — found by a
headless run where a mob froze in place instead of dying, fixed by porting
`Mob.Update()`'s combat-timer block into the right place in `Mob.tick`. See
Phase 2's progress note in the migration plan for what's still not modeled
(`StageManager`/`LoadoutManager`, `LevelBuilder`'s JSON stage assembly).

Phase 3's actual finding: castles, towers and gates aren't 3D models in the
live game at all — they're transparent PNGs on a camera-facing billboard,
which needs no bake step, only its placement math ported (see
`apps/poc_battle/lib/structure_artwork.dart`, sourced directly from
`ReferenceCastleVisual.cs`/`RuntimeGateVisual.cs` and the real
`Stage_{1,2,3}_Presentation.asset` files). The real artwork is wired into a
`?preview=structures` scene for visual approval. Characters were already
baked and approved on-device during Phase 0; Phase 3 formalizes those
numbers (16 run / 10 attack frames, 160px tiles, shadows as ground decals —
the decal drawing itself is Phase 4 scope, since it touches
`CrowdRenderer`).

Phase 4 wires it all into an actual playable scene: `apps/poc_battle/lib/stage1_game.dart`
drives a real `BattleRound` (real Stage 1 towers, base, cannon, ability
tuning, opening formation, gate) with real tap/drag input, drawn through
`BattleSceneRenderer` — the batched crowd draw calls and the real castle/gate
artwork, correctly depth-sorted, with ground shadow decals. It's the first
screen in the rebuild where the simulation you can fight is the object the
picture is drawn from, reachable at `?preview=stage1`. Two real bugs were
found and fixed getting here: missing mob-vs-mob attack damage (see Phase 2's
note above) and a "concurrent modification during iteration" crash in
`BattleRound.step()` from a gate-spawned clone being appended to the list
being iterated. Confirmed working on a real Android device: an arm64
release APK was built and tested, and the HUD (FPS/sim/outcome/ammo/energy/
base HP/towers) renders correctly — the earlier "HUD doesn't render" finding
was specific to this environment's headless screenshot pipeline, not a real
bug. What the device did confirm as real: the lane doesn't fill the
viewport, since `GroundRenderer` draws only the lane quad with no
background art behind it — expected for a PoC proving the simulation and
renderer agree, not a finished frame. See the migration plan's Phase 4
progress note for detail.

Phase 5 covers the meta screens: Home, Map, and Shop all read real data now.
`home_screen.dart` ports `HomeMenu.cs`'s five bands onto plain Flutter
`Column`/`Expanded` layout, using the real approved art (`CastleHero.png`,
`LogoWordmark.png`, icon set) copied from `Assets/Resources/Home/` instead
of placeholders. `shop_screen.dart` is a real three-tab Heroes/Cannons/
Skills shop reading `content.json` — the actual export from
`ContentExporter.cs`, run for real and copied into `assets/content/` — with
working buy/upgrade against a `PlayerProfile` persisted through
`SharedPreferences` (`profile_service.dart`, the Flutter equivalent of
`LocalJsonSaveStore.cs`). `campaign_map_screen.dart` is a simplified stand-in
for the real illustrated campaign atlas, which isn't in the repo yet. It's
all the app's default screen now (`?preview=picker` still reaches the raw
scene picker for debugging). See the migration plan's Phase 5 progress note
for the full list of what's still a stub (settings, loadout picker, wiring
a purchase into the live battle).

124 tests currently pass across the three packages combined (`dart test` in
each).

The split between those two packages is the whole architecture in miniature.
`mobrush_sim` has no dependency on any engine, so the rules of the game can be
tested, benchmarked, and reasoned about without a screen attached.

## Why this shape is possible

`BattleCamera.cs` in the Unity project frames the battle with an
**orthographic** camera at a **fixed 45° pitch** that never orbits. The scene
is modelled in 3D but only ever observed from one angle under a projection
with no perspective — which is a linear map from world space to screen space,
and can therefore be written in two lines of Dart. See `lib/iso.dart`.

The simulation keeps full 3D positions. Only the drawing is flattened.

## Results

### Simulation cost — measured natively (AOT), this machine

`dart compile exe` , which is what a Flutter release build uses on device.

| Units | ms / step | Share of a 60 Hz frame | Pair checks |
|------:|----------:|-----------------------:|------------:|
|   100 |     0.157 |                   0.9% |       2,828 |
|   200 |     0.463 |                   2.8% |      11,927 |
|   **350** | **1.104** |               **6.6%** |  **36,623** |
|   500 |     2.093 |                  12.6% |      74,803 |
|  1000 |     6.733 |                  40.4% |     296,740 |

350 is `GameConfig.maxMobs` in the shipping Unity build. Reproduce with:

```sh
cd packages/mobrush_sim && dart run bin/benchmark.dart
```

### Correctness — 10/10 parity tests pass

`packages/mobrush_sim/test/crowd_parity_test.dart` does not test "does it
run". Each test names a specific bug the C# source documents having found and
fixed, and asserts the port did not reintroduce it: seekRange staying a reach
stat rather than becoming a sprint button, a giant remaining fightable instead
of being slid around, separation never pushing a unit back up its own lane,
targets behind not being chased, melee clearing steering rather than freezing
it. Plus determinism, which the fixed timestep buys.

```sh
cd packages/mobrush_sim && dart test
```

### Rendering — one batched draw call

`CrowdRenderer` draws the entire crowd with a single `Canvas.drawRawAtlas`,
writing into `Float32List`s that are allocated once and overwritten in place.
A full crowd frame allocates nothing and issues one draw. Team colour is a
per-sprite tint in the same call, replacing `MobAnim.applyTint` at no cost.

**Frame rate on a real device is the one thing not yet measured.** It could
not be: this environment has no GPU and no phone. The web numbers below come
from a headless Chromium falling back to SwiftShader — a *CPU* rasteriser —
running dart2js rather than native AOT. They are a floor, well below what any
real device produces, and are reported only to show the shape of the scaling.

| Units | FPS (render only, CPU raster) | p95 frame |
|------:|------------------------------:|----------:|
|   350 |                          39.5 |    32.3ms |
|   700 |                          26.3 |    44.2ms |
|  1500 |                          14.5 |    74.4ms |
|  2048 |                          11.0 |    98.8ms |

Closing that gap is the first task in the plan: run this same app on a real
mid-range Android phone.

## Running the PoC

```sh
cd apps/poc_battle
flutter pub get
flutter run                 # a device or emulator
```

Query parameters on web builds: `?units=700` sets the crowd size,
`?frozen=1` freezes the simulation to isolate rendering cost.
