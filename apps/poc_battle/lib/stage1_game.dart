import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:mobrush_data/mobrush_data.dart';
import 'package:mobrush_sim/mobrush_sim.dart';

import 'background_renderer.dart';
import 'battle_scene_renderer.dart';
import 'game_content.dart';
import 'ground_renderer.dart';
import 'iso.dart';
import 'sprite_atlas.dart';
import 'structure_artwork.dart';
import 'structure_renderer.dart';

/// Phase 4's actual gate scene: `BattleRound` (Phase 2's orchestrator) driven
/// by real tap input, drawn through `BattleSceneRenderer` (crowd + real
/// castle/gate artwork, correctly depth-sorted) at a real device's aspect
/// ratio. This is the first screen in the whole rebuild where the simulation
/// a player can actually fight is the same object the picture is drawn from
/// — every earlier screen either measured performance with a synthetic
/// crowd or proved a static picture in isolation.
class Stage1Game extends FlameGame with TapCallbacks, DragCallbacks {
  late final BattleRound round;
  late final CharacterAtlas atlas;
  late final BattleSceneRenderer scene;
  late final IsoProjection projection;
  late final ui.Offset origin;

  /// `onLoad` is async and every `late final` field above stays unset until
  /// it completes; a HUD widget polling this game on a timer can easily
  /// tick before that happens. Read this first, not the fields themselves.
  bool simReady = false;

  double simMs = 0;
  double frameMs = 0;
  double fps = 0;
  final List<double> _frameSamples = [];
  final Stopwatch _frameWatch = Stopwatch();

  double _aimX = 0, _aimZ = -1;
  bool _firing = false;

  double elapsedSeconds = 0;

  /// Fires exactly once, the first time `round.outcome` leaves `ongoing` —
  /// the trigger `GameOverScreen.Show` responds to in the live game.
  void Function(RoundOutcome outcome)? onOutcome;
  bool _outcomeReported = false;

  @override
  Future<void> onLoad() async {
    atlas = await CharacterAtlas.load();
    final content = await loadGameContent();

    projection = IsoProjection.fit(screenWidth: size.x, screenHeight: size.y);
    origin = ui.Offset(size.x / 2, size.y * 0.72);

    final towers = [
      EnemyTower(
        maxHealth: 300, enemyReserve: 20, spawnInterval: 0.9,
        spawnedCharacterId: 'base_enemy', x: -5.25, z: -8.0,
      ),
      EnemyTower(
        maxHealth: 300, enemyReserve: 20, spawnInterval: 0.9,
        spawnedCharacterId: 'base_enemy', x: 5.25, z: -8.0,
      ),
      EnemyTower(
        maxHealth: 1500, enemyReserve: 20, spawnInterval: 0.9,
        spawnedCharacterId: 'base_enemy', x: 0.0, z: -12.0,
      ),
    ];

    // Real Standard Cannon (id "cannon") stats at level 0 — the exported
    // content.json, not a hand-typed stand-in.
    final cannonDef = content.cannons.firstWhere((c) => c.id == 'cannon');
    final cannonStats = cannonDef.statsAtLevel(0);

    final base = PlayerBase(
      baseHealth: 25,
      cannonHealthBonus: cannonStats.playerHealthBonus,
      defenceLineZ: 12.8,
      defenceLineX: 0,
      solidHalfDepth: 1.35,
    );

    final cannon = Cannon(
      fireRate: cannonStats.fireRate,
      launchSpeed: cannonStats.launchSpeed,
      launchLift: cannonStats.launchLift,
      spread: cannonStats.spread,
      ammoCapacity: cannonStats.ammoCapacity,
      mobsPerShot: cannonStats.mobsPerShot,
    );

    AbilityTuning tuningOf(String id) =>
        content.abilities.firstWhere((a) => a.id == id).tuningAtLevel(0);

    final abilities = BattleAbilities(
      freeze: tuningOf('freeze'),
      fireball: tuningOf('fireball'),
      lightning: tuningOf('lightning'),
      maxEnergy: cannonStats.energyCapacity,
      startingEnergy: cannonStats.energyCapacity,
      energyRegenPerSecond: cannonStats.energyRegenPerSecond,
    );

    round = BattleRound(
      content: content,
      towers: towers,
      base: base,
      cannon: cannon,
      abilities: abilities,
      gates: [
        Gate(multiplier: 2, x: 0, z: 1.5),
      ],
      maxMobs: 350,
    );

    _spawnStartingFormation();

    final structures = <StructurePlacement>[];
    final mainImg = await StructureImage.load(stage1Castles.main.assetPath);
    structures.add(
      StructurePlacement.castle(
        castleSpec: stage1Castles.main, image: mainImg, worldX: 0, worldZ: -12.0,
      ),
    );
    final sideSpec = stage1Castles.side!;
    final sideImg = await StructureImage.load(sideSpec.assetPath);
    structures.add(
      StructurePlacement.castle(
        castleSpec: sideSpec, image: sideImg, worldX: -5.25, worldZ: -8.0,
      ),
    );
    structures.add(
      StructurePlacement.castle(
        castleSpec: sideSpec, image: sideImg, worldX: 5.25, worldZ: -8.0,
      ),
    );
    final gateImg = await StructureImage.load(gateArtwork.assetPath);
    structures.add(
      StructurePlacement.gate(
        gateSpec: gateArtwork, image: gateImg, worldX: 0, worldZ: 1.5,
      ),
    );

    add(BackgroundRenderer(size: size));
    add(GroundRenderer(projection: projection, origin: origin, laneHalf: Mob.laneHalf));
    scene = BattleSceneRenderer(
      round: round,
      atlas: atlas,
      projection: projection,
      origin: origin,
      structures: structures,
    );
    add(scene);

    _frameWatch.start();
    simReady = true;
  }

  void _spawnStartingFormation() {
    for (var i = 0; i < 32; i++) {
      round.spawnMob(
        0, 'base',
        x: (i % 8 - 3.5) * 0.72, y: 0.5, z: 5.6 + (i ~/ 8) * 0.78,
        phase: MobPhase.grounded,
      );
    }
    for (var i = 0; i < 20; i++) {
      round.spawnMob(
        1, 'base_enemy',
        x: (i % 6 - 2.5) * 0.9, y: 0.5, z: -6.2 - (i ~/ 6) * 0.88,
        phase: MobPhase.grounded,
      );
    }
  }

  @override
  void onTapDown(TapDownEvent event) => _aimAt(event.canvasPosition);

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    _firing = true;
    _aimAt(event.canvasPosition);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) => _aimAt(event.canvasEndPosition);

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    _firing = false;
  }

  /// Inverse of `IsoProjection.screenY`: solve world `(x, z)` for a screen
  /// point, holding `y` at the cannon's own height (0.5) — the same
  /// ground-plane simplification `Cannon.UpdateAim`'s raycast makes, just
  /// solved algebraically instead of by casting a ray through a 3D scene.
  ///
  /// From `screenY = (z·sinθ − y·cosθ)·ppu`:  z = (screenY/ppu + y·cosθ) / sinθ.
  void _aimAt(Vector2 screenPos) {
    final dx = screenPos.x - origin.dx;
    final dy = screenPos.y - origin.dy;
    final rad = projection.pitchDegrees * math.pi / 180.0;
    final sinP = math.sin(rad), cosP = math.cos(rad);
    final ppu = projection.pixelsPerUnit;

    final worldX = dx / ppu;
    final worldZ = (dy / ppu + 0.5 * cosP) / sinP;

    // Cannon.aimAndFire expects a direction relative to the cannon, which
    // this scene places at the base's own z (12.8) — same anchoring
    // PlayerBase.ResolveDefenceLine uses in the live game.
    _aimX = worldX;
    _aimZ = worldZ - 12.8;
    _firing = true;
  }

  @override
  void update(double dt) {
    final total = _frameWatch.elapsedMicroseconds / 1000.0;
    _frameWatch
      ..reset()
      ..start();

    if (_firing) round.aimAndFire(_aimX, _aimZ);

    final sw = Stopwatch()..start();
    round.advance(dt);
    sw.stop();
    simMs = sw.elapsedMicroseconds / 1000.0;
    scene.advanceClock(dt);
    elapsedSeconds += dt;

    if (!_outcomeReported && round.outcome != RoundOutcome.ongoing) {
      _outcomeReported = true;
      onOutcome?.call(round.outcome);
    }

    _frameSamples.add(total);
    if (_frameSamples.length > 90) _frameSamples.removeAt(0);
    if (_frameSamples.isNotEmpty) {
      final avg = _frameSamples.reduce((a, b) => a + b) / _frameSamples.length;
      frameMs = avg;
      fps = avg > 0 ? 1000.0 / avg : 0;
    }

    super.update(dt);
  }
}
