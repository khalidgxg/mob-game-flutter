# Rebuilding MobRush in Flutter — migration plan

Status: **proposed, pending approval.** Nothing in `mobGame` has been changed.

---

## 1. Verdict

A faithful *port* of the Unity project is not possible. Flutter has no
production 3D engine, and the candidates that exist (`flutter_scene`,
`flutter_gpu`, `three_dart`) are either experimental or CPU-bound. Skinned
crowd animation at 350 units is not something any of them has demonstrated.

A *rebuild* is possible, and the game is unusually well-suited to it. Three
findings drive this plan:

**The game is already 2.5D.** `BattleCamera.cs` frames the battle with an
orthographic camera at a fixed 45° pitch that never orbits. The scene is
modelled in 3D but only ever observed from one fixed angle under a projection
with no perspective. That is a linear world→screen map — two lines of Dart
(`apps/poc_battle/lib/iso.dart`). It also means sprites baked from that same
camera are pixel-identical to what Unity renders today.

**The rules are already engine-independent in substance.** `CrowdManager`,
`Mob`'s movement, `CombatLimits`, `RewardRules`, `ContentValidation` and
`PlayerProfile` are arithmetic and plain data. `PlayerProfile` is already a
serializable POCO at schema version 7 with no Unity asset references. The
coupling to Unity is syntactic — `Vector3`, `MonoBehaviour.Update`,
`transform.position` — not structural.

**The UI layer is where Flutter wins outright.** `Presentation/` is 7,790
lines, all of it hand-built uGUI: `UiKit.cs` alone spends 674 lines
constructing `RectTransform`s, anchors and sizeDeltas in code. Flutter's
layout system removes that category of work rather than translating it.

## 2. What the proof of concept established, and what it did not

Built and committed in this repository. See `README.md` for how to reproduce.

**Established:**

- The crowd solve costs **1.10 ms per fixed step at 350 units** under native
  AOT — 6.6% of a 60 Hz frame. Cost is dominated by neighbour pair checks
  (36,623 per step at 350), and scales as documented, not pathologically.
- The port is behaviourally faithful. Ten tests each assert a specific
  regression the C# source records having already found and fixed, so a
  rewrite cannot silently reintroduce it.
- The entire crowd renders in **one batched draw call** (`drawRawAtlas`) from
  **one texture**, into buffers allocated once and reused. A full crowd frame
  allocates nothing. Team tint is a per-sprite colour in the same call.
- The isometric projection, depth ordering, per-unit animation phase and team
  colour all work together correctly on screen.

**Not established — and this is the gate for everything below:**

- **Frame rate on real hardware.** This environment has no GPU and no device.
  The web figures in the README come from a CPU rasteriser running dart2js and
  are a floor, not a forecast.
- **That baked sprites look as good as the live 3D.** The PoC uses procedural
  placeholder figures. Whether real bakes hold up at gameplay scale is a
  judgement only you can make, from real output.

Phase 0 exists to close both before any migration work starts.

## 3. Target architecture

```
packages/
  mobrush_sim/       Pure Dart. Rules, crowd solve, combat, progression.
                     No Flutter, no Flame. Fully unit-testable.
  mobrush_data/      Content models + JSON loaders. Generated from the
                     ScriptableObjects exported out of Unity.
  mobrush_save/      PlayerProfile, schema versioning, migrations, store.
  mobrush_ui/        Design system: VISUAL_IDENTITY.md as ThemeData, tokens,
                     shared widgets. One place shapes and colours live.
apps/
  mobrush/           The game. Flame surface for battle, Flutter for the rest.
tools/
  unity_export/      Editor scripts that run inside mobGame and emit JSON+PNG.
```

The rule that keeps this honest: **`mobrush_sim` never imports Flutter.** If a
rule cannot be tested headlessly, it is in the wrong package.

## 4. Phases

Each phase has an explicit exit gate. A phase is not done until its gate is
demonstrated, not until its code is written.

### Phase 0 — Device validation (gate for the whole project)

The one measurement that cannot be inferred.

1. Run the committed PoC on a real mid-range Android phone
   (`flutter run --release`). Sweep 350 / 700 / 1500 units.
2. Bake **one** real character (`base`) from Unity through the pipeline in
   §5 and drop it into the PoC beside the placeholder.
3. Look at it. Compare against a screenshot of the same crowd in Unity.

**Gate:** ≥55 FPS at 350 units on the target device, *and* your judgement that
the baked look is acceptable. If frame rate passes but the look does not, the
decision moves to the hybrid option (Flutter shell + embedded Unity) and this
plan is void. Better to learn that in week one than in month three.

### Phase 1 — Content out of Unity, into Dart

The catalogs are ScriptableObjects; they need to become data the Dart side can
read without Unity present.

1. Editor script in `mobGame` exporting `GameConfig`, `CharacterCatalog`,
   `CannonCatalog`, `StageCatalog`, `AbilityCatalog` to JSON.
2. Dart models in `mobrush_data` mirroring `CharacterDefinition`,
   `CannonDefinition`, `StageDefinition`, `AbilityDefinition`,
   `CharacterProgression`, `RewardRules`, `StagePresentationProfile`.
3. Port `ContentValidation` (664 lines) as Dart tests over the exported JSON.
4. Port `PlayerProfile` (schema 7) and its migrations into `mobrush_save`.

**Gate:** the exported catalogs load in Dart and pass the ported validator with
the same verdicts Unity's `ContentValidatorMenu` gives today.

**Progress:** `ContentExporter.cs`, `mobrush_data` (characters, cannons,
`RewardRules`/`RewardCalculator`/`StarRating`) and `mobrush_save`
(`PlayerProfile`, full accessor surface) are committed with 46 passing tests
across the two packages (56 including `mobrush_sim` from Phase 0).
The round-trip is confirmed against **real exported content**, characters and
cannons both: `MobRush ▸ Export Content for Flutter` was run in the live
Editor, its `content.json` was committed as a second test fixture, and
`real_export_smoke_test.dart` parses it and resolves `statsAtLevel` for every
authored level of every character and every cannon.

The cannon side took two passes. The first export produced zero cannons —
not a bug in the project, but in the exporter: this game builds its cannons
entirely in code (`CannonLibrary.BuildSpecs()`), as runtime-only
`ScriptableObject` instances (`HideFlags.HideAndDontSave`) that never touch
`GameConfig.cannonCatalog`, which is all the exporter originally read.
Fixed by also reading `CannonLibrary.All`, mirroring
`Game.GetAllCannons()`'s exact precedence (library wins on a colliding id,
catalog fills in anything the library doesn't define). A re-export after the
fix carries both authored cannons ("cannon", "heavy") with their full level
tables, and the smoke test checks the level-1 stat delta against
`CannonLibrary.BuildSpecs()`'s own rows to confirm the export's
absolute-row-to-delta encoding round-trips correctly.

**Not yet done:** `StageDefinition`, `AbilityDefinition`,
`CharacterProgression`, `StagePresentationProfile`, and the 664-line
`ContentValidation` port.

### Phase 2 — Complete the simulation

The PoC covers the crowd solve and mob movement. The rest of the battle:

- `Cannon` (901 lines) — aim, ballistic launch, ammo, spread fire behaviour.
- `Gate` (330) — multiplier/additive gates, pass-through tracking.
- `EnemyTower` (547) and `PlayerBase` (186) — structures, HP, melee targeting.
- `BattleAbilityController` (703) — charges, cooldowns, ability effects.
- `StageManager`, `LoadoutManager`, `CharacterProgression`, `RewardRules`.
- `LevelBuilder` (283) → a stage loader producing simulation state from JSON.

Every one of these is arithmetic plus state. None needs a renderer.

**Gate:** a full authored stage plays start to finish headlessly — spawn,
gates, towers, castle, win/lose, rewards — driven by a scripted input trace,
with the result asserted in a test. No screen involved.

**Progress:** five of the systems above are committed to `mobrush_sim`, each
against real authored numbers where they exist — `Cannon` (aim clamp,
fire-rate cooldown, ammo, multi-shot spread fan — matching
`CannonLibrary.BuildSpecs()` row 0 exactly: fireRate 0.045, ammoCapacity
130), `Gate` (×N/+N/÷N semantics, the once-per-round additive spend),
`EnemyTower` + `StageSection`/`SectionEscalation` (spawn timer/reserve/
freeze/collapse, and the difficulty curve — tested against Stage 1-3's real
tower healths and escalation recipes), `PlayerBase` (health, the cannon's
additive HP bonus, the engage-line test), and `BattleAbilities` (energy,
charges, and Freeze/Fireball/Lightning's exact targeting and damage —
Fireball's test uses the real maxed tuning read off a user-provided Shop
screenshot: 90 damage, 4.6 radius, 240 siege). `AbilityTuning` was added to
`mobrush_data` alongside `CharacterDefinition`/`CannonDefinition`, since it's
authored content, not simulation state; `ContentExporter.cs` now exports the
ability catalog too. 117 tests pass across `mobrush_sim` (71), `mobrush_data`
(31), and `mobrush_save` (15).

Two of the port's own edge cases surfaced bugs in the *tests*, not the ported
code, once traced back to the C# line by line: `EnemyTower`'s spawn timer
starts at 0 and is never pre-advanced, so with the default
`initialSpawnDelay` of 0 the first wave fires on the very first tick
regardless of `dt` — matching the C# tooltip "0 launches immediately"
literally rather than intuitively. And `Cannon`'s aim clamp renormalizes a
*second* time after clamping z to -0.35, so a purely sideways/backward aim
(x near 0) collapses all the way to straight forward instead of stopping at
-0.35 — reproduced by hand-deriving Unity's exact double-`Vector3.Normalize()`
sequence rather than assuming what the clamp "should" do.

**Gate met.** `BattleRound` (`lib/src/battle_round.dart`) is the orchestrator
this phase's gate asked for. It wires all five systems into one playable
round: `Mob`'s structure-attack path (`structTarget`, engaging a tower's or
the base's box, dealing damage on `attackCooldown`), gate-crossing detection
(`Gate.wasCrossed`'s swept-segment test, now with real position/box fields),
tower wave-spawning with real launch ballistics, cannon fire spawning mobs,
ability effects reading/damaging the live mob and tower lists, and win/lose
evaluation matching `Game.cs` exactly (all towers destroyed → win; base
destroyed, or ammo empties and the 1.5s grace period elapses with towers
still standing and no live player mobs → lose).
`test/battle_round_integration_test.dart` plays a full Stage 1 round
headlessly with real numbers (300/300/1500 tower health, Stage 1's authored
32-player/20-enemy opening formation, `CannonLibrary`'s Standard Cannon row
0) and asserts the win — this is the "a full authored stage plays start to
finish" proof the gate names.

Getting there surfaced a real gap, not just a test bug: **mob-vs-mob melee
combat was never ported.** Two mobs would clash (`Mob.fight`, from Phase 0's
`CrowdManager`) and lock into `combatTarget`, but nothing dealt damage or
ever released the lock — found by tracing a headless run where a lone player
mob froze in place forever instead of fighting and dying. Fixed by porting
`Mob.Update()`'s `combatTarget` block (attack-timer damage on
`attackCooldown`, disengage past the clash-distance-times-1.6 band) into
`Mob.updateCombatState`, called from inside `Mob.tick` *before* the
movement branch — matching the C#'s own ordering, where a mob's movement
this frame depends on whether it is still fighting as of this frame's
combat resolution, not last frame's. `BattleSim.step` (Phase 0) had been
calling this as a separate pass after every mob's movement, which is the
wrong order; that call site was fixed too.

**Not yet done:** `StageManager`/`LoadoutManager` (profile-facing progression
orchestration — save-facing, not battle-facing) and `LevelBuilder`'s
JSON-driven stage assembly (turning an authored `StageDefinition` into the
tower/gate/base placements `BattleRound` takes as constructor arguments
today). Also not modeled, stated in `BattleRound`'s own class doc: no
`Obstacle`/`BarrierPush`, no footprint-ejection physics (cosmetic, doesn't
affect outcome), and no `HasCannonPriority` crowd-vs-cannon targeting
nuance. 124 tests now pass across `mobrush_sim` (78), `mobrush_data` (31),
and `mobrush_save` (15).

### Phase 3 — Asset bake pipeline

An editor script in `mobGame` that, for each character and each of its two
clips, poses the FBX in front of an orthographic camera at `BattleCamera.pitch`
and captures N frames on transparent background, then packs to an atlas + JSON.

Scope, from the authored roster: 6 characters × 2 clips (run, attack) × 16
frames ≈ **192 frames**, one 2048² sheet. Same treatment for castles, gates,
towers and scenery props — those are single frames, not clips.

**Gate:** all six characters baked, dropped into the PoC, and visually approved
by you against Unity screenshots.

**Progress — characters:** `CrowdSpriteBaker.cs` (added during Phase 0's
device-validation push) produced a real bake — 208 frames across 8 catalog
entries, 2560×2080 — verified running on a real Android device in the PoC.
The three decisions this phase asks for are settled by what was actually
baked and shipped: **16 run frames / 10 attack frames per character**,
**160px tiles**, and **shadows as ground decals** (decided, not yet drawn —
see below).

**Progress — structures, and the actual finding of this phase:** castles,
towers and gates in the live game are not 3D models rendered every frame.
`ReferenceCastleVisual.cs`/`RuntimeGateVisual.cs` present them as
transparent 2D PNGs on a quad rotated to exactly match `BattleCamera`'s
fixed 45° pitch — a billboard that always faces a fixed-angle camera renders
as an undistorted flat image, so **these assets needed no bake step at
all**. `apps/poc_battle/lib/structure_artwork.dart` ports the placement math
directly from the C# and the real `Stage_{1,2,3}_Presentation.asset` files
(world width, forward offset, and the `visibleBottom` ground-anchor fraction
— confirmed per-stage, including that Stage 3 authors no side-tower artwork
at all, matching the flow document), and the real PNGs were copied in
unmodified. `structure_preview_game.dart` (reachable at
`?preview=structures`) renders Stage 1's real castle and gate artwork at
their real lane positions; a screenshot was sent for visual approval.

**Not yet done:** shadow decals are a decision, not yet an implementation —
drawing them means touching `CrowdRenderer`'s batched draw call, which is
Phase 4 scope ("extend it to structures and props"), so it stays there
rather than being half-built here. Gate/tower artwork for Stage 2 and 3 is
copied and modeled in `structure_artwork.dart` but not yet exercised in the
preview scene (only Stage 1 was rendered for approval). Scenery props
(trees, rocks, the well) are not addressed at all yet.

### Phase 4 — Battle presentation

- Wire the real atlas into `CrowdRenderer`; extend it to structures and props.
- Ground, lane, gates, towers, castle — same projection, same depth sort.
- HUD in Flutter widgets over the Flame surface, replacing `Hud.cs` (914 +
  317 lines).
- VFX: `Vfx`, `AbilityVfx`, `FloatingText`, `WorldHpBar`, `GateLabelEffect`.
  Flame's particle system covers most; the rest is Canvas drawing.
- Camera fit: port `BattleCamera`'s aspect-driven sizing to
  `camera.viewfinder.zoom`, including the tall-portrait guard.

**Gate:** a full stage is playable on device at target frame rate, and reads
correctly against a Unity screenshot of the same stage.

**Progress:** `IsoProjection.fit()` ports `BattleCamera.Apply()`'s
aspect-driven `orthographicSize` resolution into a `pixelsPerUnit` factory.
`BattleSceneRenderer` (`apps/poc_battle/lib/battle_scene_renderer.dart`) is
the unified renderer: it merges the batched crowd draw calls with individual
structure draws (`StructurePlacement`), sorted by world Z, so castles/gate
and mobs occlude each other correctly, and draws a ground shadow ellipse
under every mob (the decal deferred from Phase 3). `stage1_game.dart` wires
a real `BattleRound` — real Stage 1 tower healths (300/300/1500), real base
(25 + 30 cannon bonus), real Standard Cannon and Freeze/Fireball tuning, the
real 32/20 opening formation, and the real ×2 gate — into a `FlameGame`
driven by actual tap/drag input (`TapCallbacks`/`DragCallbacks`, Flame
1.35.1's current event API), with the aim direction solved algebraically as
the inverse of the world→screen projection. This is the first screen in the
rebuild where the simulation a player can fight is the same object the
picture is drawn from. A real bug was found and fixed here: `BattleRound`
lacked mob-vs-mob melee combat — a mob would clash with an enemy and freeze
forever without ever dealing damage, because the C# `Update()`'s
attack-timer block had never been ported to `Mob.updateCombatState()`; it's
been added and moved to run before movement each tick, matching the C#
order. A second real bug — "concurrent modification during iteration" in
`BattleRound.step()`, from a gate-crossing mob's clone being appended to the
same list being iterated — is also fixed (indexed loop over a captured
length). 78/78 `mobrush_sim` tests pass, `dart analyze` is clean, and
screenshots over both 8s and 20s confirm the battle progresses correctly:
crowds engage, cross the gate, and assault the castle with correct
depth-sorted rendering.

**Confirmed on a real device:** an arm64 release APK was built
(`flutter build apk --release --split-per-abi`) and tested on the user's own
Android phone. The HUD renders correctly — FPS, sim time, outcome, ammo,
energy, base HP, and towers standing were all visible and updating live.
The earlier report of missing HUD text was specific to this project's
headless Chromium/CanvasKit/SwiftShader screenshot pipeline, not a real
bug. What the device confirmed as real: the lane doesn't fill the
viewport — `GroundRenderer` only draws the lane quad itself with no
sky/background art behind it, so the screen letterboxes to black above,
below, and beside the lane. That's in scope for this PoC (it proves the
simulation and the depth-sorted renderer agree with each other, not a
finished frame) — filling the rest of the screen with background art is
later polish, not a Phase 4 gate item. Since an installed APK has no URL
bar for `?preview=...`, `main.dart` now opens on an in-app scene picker
(Stage 1 battle / crowd benchmark / castle-gate artwork) instead of
defaulting straight to the crowd benchmark.

**Not yet done:** the HUD strip is deliberately minimal (energy, ammo,
outcome, base/tower health as text) — no ability buttons or wave tracker
yet, full parity with `Hud.cs` (914 + 317 lines) is separate work. No VFX
(`Vfx`, `AbilityVfx`, `FloatingText`, `WorldHpBar`, `GateLabelEffect`).
Stage 2/3 structure artwork is modeled in `structure_artwork.dart` but not
wired into a playable scene, only Stage 1. Content is still the hardcoded
`stage1_content.dart` stand-in, not loaded from a real `content.json`
export — `LevelBuilder`'s JSON-driven stage assembly remains Phase 1/5
follow-up work. No on-device or real-browser frame-rate measurement yet.

### Phase 5 — Meta screens

The largest line count, the lowest risk, the biggest simplification.

- Home (`HomeMenu.cs`, 708) — Flutter layout, no more manual anchoring.
- Shop (`ShopScreen` + Characters/Abilities/Cannons partials, 1,478) —
  `ListView`/`GridView` replace hand-built scroll rects.
- Campaign map (`CampaignMapScreen.cs`, 1,087) — the atlas artwork with
  normalized anchors from `CampaignAtlasDefinition` maps directly onto
  `Stack` + `Align(FractionalOffset)`. This one gets dramatically shorter.
- Game over (`GameOverScreen.cs`, 188), settings, safe-area handling.
- `VISUAL_IDENTITY.md` encoded as `ThemeData` + design tokens in `mobrush_ui`,
  replacing colours currently spread across the presentation code.

**Gate:** every screen navigable, progression persisting across restarts, and
each screen reviewed against its current Unity screenshot.

**Progress:** `apps/poc_battle/lib/home_screen.dart` ports `HomeMenu.cs`'s
five bands (header, title, campaign hero, BATTLE CTA, bottom nav) as
ordinary `Column`/`Expanded` flex layout instead of hand-tuned
`SetNormalizedRect` calls — the flex weights (55/62/572/97/118) are kept
proportional to the C#'s own `HeaderTop`/`TitleTop`/`HeroTop`/`PlayTop`/
`NavTop` constants, so the vertical rhythm is the same, just expressed in
Flutter's own layout system instead of being reimplemented by hand.
`SafeArea` replaces `SafeAreaFitter`. It reads real `PlayerProfile` fields
(level, currency, gems, stage stars) from `mobrush_save`, and the BATTLE
button and nav's BATTLE tab both push the real Stage 1 playable scene
(`Stage1Screen`) built in Phase 4. `main.dart`'s default route (with no
query string) is now this Home screen — `?preview=picker` still reaches
the raw scene picker if needed for debugging.

Real persistence followed: `profile_service.dart` ports
`LocalJsonSaveStore.cs` onto `SharedPreferences` (the closest cross-platform
equivalent to a persistent-data-path JSON file, since web has no
filesystem) — same missing/corrupt-data fallback to a fresh profile the C#
`try`/`catch` gives. Home's own art (`CastleHero.png`, `LogoWordmark.png`,
the header/nav icon set) and the three campaign node-state badges are the
real approved PNGs copied straight from `Assets/Resources/Home/` and
`Assets/Resources/UI/Campaign/` — reusing an already-approved project
asset, the fal.ai policy's own first priority, rather than placeholder
Material icons.

`ContentExporter.cs` was run for real and its `content.json` (8 characters,
2 cannons, 3 abilities, reward rules) copied into
`assets/content/content.json`; `game_content.dart` loads and caches it at
runtime, verified to parse cleanly against `mobrush_data`'s existing
`ContentCatalog.fromJson`. `shop_screen.dart` is a real three-tab
(Heroes/Cannons/Skills) Shop reading those real stats, with working
buy/upgrade against the real `PlayerProfile` currency and persisted through
`ProfileService` — port of `ShopScreen` + its Characters/Abilities/Cannons
partials (1,478 lines). `Stage1Screen`'s Standard Cannon and ability tuning
now come from this same real catalog (`statsAtLevel(0)`/`tuningAtLevel(0)`)
instead of hand-typed numbers, closing the gap `stage1_content.dart`
(now deleted) stood in for.

**Not yet done:** `HomeMenu.cs`'s settings modal only shows a placeholder
dialog — sound toggle, How To Play, and the secret-code panel aren't
ported. Map is a stub list, not the real illustrated atlas — see
`campaign_map_screen.dart`'s own note on the missing background art. Shop
has no roster/loadout picker ("BATTLE TEAM") and no character portrait art
yet (Unity's are 3D renders, not baked to sprites the way the crowd atlas
was), and a purchase doesn't yet affect the live battle — `Stage1Screen`
always spawns the base-tier stats regardless of what's bought, since
wiring a purchased loadout into `BattleRound` is separate follow-up work.
`VISUAL_IDENTITY.md` is not yet encoded as `ThemeData`/design tokens —
colours are still hardcoded per-screen the same way the Unity presentation
code was.

### Phase 6 — Audio, polish, release

- Port `Sfx.cs` (394 lines, 20 named cues) onto a Flutter audio package,
  following `AUDIO_IDENTIT.md`.
- Performance pass on device: frame pacing, atlas residency, GC pressure.
- Android and iOS release builds, icons, splash, store metadata.

**Gate:** signed release builds meeting the frame-rate target on the reference
device, with `release-build-check`'s equivalent audit passing.

## 5. What changes, honestly

Things that will not survive the rebuild, stated plainly so they are decisions
rather than surprises:

1. **Dynamic lighting and shadows bake in.** Sun direction becomes fixed. Unit
   shadows become ground decals.
2. **The camera angle is locked permanently.** `BattleCamera.pitch` becomes a
   bake-time constant. Changing it later means re-baking everything. The
   current camera does not orbit, so nothing is lost today — but the option is.
3. **Post-processing goes.** Anything URP's post stack contributes must be
   baked into the art or reproduced as Canvas effects.
4. **Character variety costs texture, not CPU.** Adding a character means new
   atlas frames rather than a new FBX. Cheaper at runtime, more work per
   character to author.
5. **The Unity project stays the art tool.** It remains the source of truth for
   models and animation and the host of the bake pipeline. This is a rebuild of
   the *game*, not a retirement of the *project*.

## 6. Risks

| Risk | Severity | Handling |
|---|---|---|
| Device frame rate misses target | project-ending | Phase 0 measures it first, before any migration work |
| Baked look judged unacceptable | project-ending | Phase 0 bakes one real character for your judgement |
| Simulation drifts from C# behaviour | high | Parity tests per fixed bug, extended each phase; both versions playable side by side |
| Atlas exceeds texture limits | medium | 192 frames fits 2048² with room; frame count and resolution are tunable knobs |
| Overdraw at crowd density | medium | Already one batched call; culling off-screen units is the next lever |
| Scope creep into redesigning screens | medium | Phase 5 reproduces current screens; redesign is separate work, after parity |

## 7. Effort

For one developer working steadily, and assuming Phase 0 passes:

| Phase | Estimate |
|---|---|
| 0 — Device validation | 1–2 days |
| 1 — Content + save | ~1 week |
| 2 — Simulation | ~2 weeks |
| 3 — Bake pipeline | ~1 week |
| 4 — Battle presentation | ~2 weeks |
| 5 — Meta screens | 2–3 weeks |
| 6 — Audio, polish, release | 1–2 weeks |
| **Total** | **~10–12 weeks** |

The estimate assumes content and art are reused, not re-authored, and that
Phase 5 reproduces the existing screens rather than redesigning them.

## 8. Decision requested

1. Approve or reject this plan.
2. Confirm the reference device for Phase 0's gate, and the frame-rate target.
3. Confirm that a permanently locked camera angle (§5.2) is acceptable.

Nothing in `mobGame` will be modified without that approval. Phase 0's bake
script is the first change it would need, and it is additive — a new editor
script under `Assets/Editor/`.
