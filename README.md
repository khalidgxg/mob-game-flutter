# MobRush — Flutter rebuild

A rebuild of the Unity game in [`khalidgxg/mobGame`](https://github.com/khalidgxg/mobGame)
as a Flutter application.

This repository currently contains a **proof of concept**, not the game. Its
only purpose is to answer one question with measurements instead of opinion:
*can the MobRush battle — 350 animated units at once — run at frame rate in
Flutter?*

## Layout

```
packages/mobrush_sim/   Pure Dart. The battle simulation, ported from C#.
                        No Flutter, no Flame, no rendering. Unit-testable.
apps/poc_battle/        Flutter + Flame. Renders that simulation.
docs/MIGRATION_PLAN.md  The full plan this PoC was built to justify.
```

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
