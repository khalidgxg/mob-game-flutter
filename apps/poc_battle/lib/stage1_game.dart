import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:mobrush_data/mobrush_data.dart';
import 'package:mobrush_save/mobrush_save.dart';
import 'package:mobrush_sim/mobrush_sim.dart';

import 'background_renderer.dart';
import 'battle_scene_renderer.dart';
import 'game_content.dart';
import 'ground_renderer.dart';
import 'iso.dart';
import 'sfx.dart';
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
  Stage1Game({this.profile});

  /// The player's save, when the round was entered from Home. Everything
  /// bought in the shop is applied through this: which cannon is equipped
  /// and at what level, which character the cannon and RUSH deploy, and
  /// what level each of the three abilities is tuned to. Null for the raw
  /// scene-picker entry point, which falls back to the base loadout.
  final PlayerProfile? profile;

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

  /// Real Standard Cannon `rushUnitCount` at level 0, set once `onLoad`
  /// resolves — how many units one tap of RUSH deploys.
  int rushUnitCount = 1;

  /// Port of `BattleAbilityController.BattleStarted`: the cannon and RUSH
  /// stay inert (matching `TryBattleAction`'s first tap being "start", not
  /// "fire") until the HUD's BATTLE button is pressed.
  bool battleStarted = false;

  void startBattle() => battleStarted = true;

  /// Port of `Hud.TryBattleAction`'s RUSH branch. Returns a short hint
  /// string for the caller to show, mirroring the three C# outcomes:
  /// deployed, unit-limit reached, or not enough energy.
  String tryRush() {
    if (!battleStarted) return 'START THE BATTLE FIRST';
    final ok = round.tryRush(rushUnitCount: rushUnitCount, formationZ: 5.6);
    if (ok) return 'RUSH DEPLOYED';
    final def = round.content.character(round.abilities.selectedCharacterId);
    final cost = (def?.launchEnergyCost ?? 0) * rushUnitCount;
    return cost > round.abilities.energy
        ? 'RUSH NEEDS $cost ENERGY'
        : 'UNIT LIMIT REACHED';
  }

  /// Port of `Hud.TryAbility`. Returns a short hint string for the caller.
  String tryAbility(Ability ability) {
    if (!battleStarted) return 'START THE BATTLE FIRST';
    final result = round.abilities.tryUse(ability, mobs: round.mobs, towers: round.towers);
    if (!result.applied) return 'NO VALID TARGET';
    return switch (ability) {
      Ability.freeze => 'ENEMIES FROZEN',
      Ability.fireball => 'FIREBALL IMPACT',
      Ability.lightning => 'LIGHTNING STRIKE',
    };
  }

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

    // The equipped loadout, resolved from the save. A cannon the player
    // bought and upgraded has to actually shoot differently, or the shop is
    // decoration — same reasoning as `BattleRound.characterLevels`.
    final p = profile;
    final cannonDef = content.cannons.firstWhere(
      (c) => c.id == (p?.selectedCannonId ?? ''),
      orElse: () => content.cannons.firstWhere((c) => c.id == 'cannon'),
    );
    final cannonStats = cannonDef.statsAtLevel(p?.getCannonLevel(cannonDef.id) ?? 0);
    rushUnitCount = cannonStats.rushUnitCount;

    // The roster's first entry is the primary character, matching
    // `Hud.ResolveSquadCards`' own "first card is the selection" rule.
    final characterId = (p?.characterRoster.isNotEmpty ?? false)
        ? p!.characterRoster.first
        : 'base';
    final characterLevels = <String, int>{
      for (final c in content.characters) c.id: p?.getCharacterLevel(c.id) ?? 0,
    };

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

    AbilityTuning tuningOf(String id) => content.abilities
        .firstWhere((a) => a.id == id)
        .tuningAtLevel(p?.getAbilityLevel(id) ?? 0);

    final abilities = BattleAbilities(
      freeze: tuningOf('freeze'),
      fireball: tuningOf('fireball'),
      lightning: tuningOf('lightning'),
      maxEnergy: cannonStats.energyCapacity,
      startingEnergy: cannonStats.energyCapacity,
      energyRegenPerSecond: cannonStats.energyRegenPerSecond,
      selectedCharacterId: characterId,
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
      characterLevels: characterLevels,
    );

    round.onEvent = _onRoundEvent;
    _spawnStartingFormation(characterId);

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

    final groundImg = await StructureImage.load('assets/ground/stage1_ground.jpg');
    add(BackgroundRenderer(size: size));
    add(GroundRenderer(
      projection: projection,
      origin: origin,
      laneHalf: Mob.laneHalf,
      groundImage: groundImg,
    ));
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

  /// Maps the simulation's events onto `Sfx.cs`'s cue names. The gate
  /// pitches its chime up with the multiplier, which is the one place the
  /// live game varies a cue deliberately rather than randomly.
  void _onRoundEvent(RoundEvent event) {
    switch (event) {
      case RoundEvent.gateCrossed:
        Sfx.instance.play('gate',
            pitch: 1.0 + 0.06 * (round.lastGateMultiplier - 1).clamp(0, 6));
      case RoundEvent.towerHit:
        Sfx.instance.play('hit');
      case RoundEvent.towerDestroyed:
        Sfx.instance.play('destroy');
      case RoundEvent.baseHit:
        Sfx.instance.play('baseHit');
    }
  }

  void _spawnStartingFormation(String characterId) {
    for (var i = 0; i < 32; i++) {
      round.spawnMob(
        0, characterId,
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

    if (_firing && battleStarted) {
      final before = round.mobs.length;
      round.aimAndFire(_aimX, _aimZ);
      // Only cue the cannon when a shot actually left the barrel — ammo,
      // energy and the fire-rate cooldown can all refuse one, and a click
      // on every frame of a held drag would be unbearable.
      if (round.mobs.length > before) Sfx.instance.play('shoot');
    }

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
