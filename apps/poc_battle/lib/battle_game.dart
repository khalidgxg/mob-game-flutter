import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:mobrush_sim/mobrush_sim.dart';

import 'crowd_renderer.dart';
import 'ground_renderer.dart';
import 'iso.dart';
import 'sprite_atlas.dart';

/// The proof-of-concept battle: the ported simulation, rendered.
///
/// It deliberately keeps the two halves separate and visible. `BattleSim` runs
/// on a fixed 60 Hz step and knows nothing about the screen; `CrowdRenderer`
/// reads its state and knows nothing about the rules. Everything measured here
/// is measured on that split, because that split is what the migration plan
/// rests on.
class BattleGame extends FlameGame {
  BattleGame({this.targetMobs = 350, this.frozen = false});

  int targetMobs;

  /// Skips the simulation and animates nothing, leaving only the batched draw.
  /// Isolating the two halves is the only way to say which one a frame budget
  /// is actually being spent on — a combined number can hide either.
  final bool frozen;

  late final BattleSim sim;
  late final CharacterAtlas atlas;
  late final CrowdRenderer crowd;

  final IsoProjection projection = const IsoProjection(pitchDegrees: 45.0);

  // Rolling telemetry, surfaced in the overlay.
  double simMs = 0;
  double frameMs = 0;
  double p95Ms = 0;
  double fps = 0;

  final List<double> _frameSamples = [];
  final Stopwatch _frameWatch = Stopwatch();
  final math.Random _rng = math.Random(20260811);

  double _spawnTimer = 0;

  /// Seconds of warm-up ignored before telemetry is reported, so shader
  /// compilation and the first-frame cost do not contaminate the average.
  static const double _warmup = 3.0;

  double _elapsed = 0;
  double _reportTimer = 0;

  @override
  Future<void> onLoad() async {
    atlas = await CharacterAtlas.load();
    // ignore: avoid_print
    print(
      atlas.isRealBake
          ? 'CrowdSpriteBaker export loaded — showing real character bakes.'
          : 'No export found at assets/crowd_export/ — showing placeholder figures.',
    );
    sim = BattleSim(maxMobs: 4000);

    final origin = ui.Offset(size.x / 2, size.y * 0.62);
    add(
      GroundRenderer(
        projection: projection,
        origin: origin,
        laneHalf: Mob.laneHalf,
      ),
    );
    crowd = CrowdRenderer(
      sim: sim,
      atlas: atlas,
      projection: projection,
      origin: origin,
    );
    add(crowd);

    _fill();
    _frameWatch.start();
  }

  /// Keeps the live count at the requested target, replacing anything culled.
  void _fill() {
    while (sim.mobs.length < targetMobs) {
      final team = sim.mobs.length.isEven ? 0 : 1;
      sim.spawn(
        team: team,
        x: (_rng.nextDouble() * 2 - 1) * Mob.laneHalf,
        y: Mob.groundY,
        z: team == 0
            ? 6.0 + _rng.nextDouble() * 10.0
            : -6.0 - _rng.nextDouble() * 10.0,
        speed: 1.4 + _rng.nextDouble() * 0.7,
        seekRange: 2.6,
      )?.phase = MobPhase.grounded;
    }
    while (sim.mobs.length > targetMobs) {
      sim.mobs.removeLast();
    }
  }

  @override
  void update(double dt) {
    final total = _frameWatch.elapsedMicroseconds / 1000.0;
    _frameWatch
      ..reset()
      ..start();

    final sw = Stopwatch()..start();
    if (!frozen) sim.advance(dt);
    sw.stop();
    simMs = sw.elapsedMicroseconds / 1000.0;

    if (!frozen) crowd.advanceClock(dt);

    // Recycle the two crowds so the scene keeps producing the dense mid-lane
    // collision that is the actual worst case. A battle that resolves and goes
    // quiet would flatter the numbers.
    _spawnTimer += dt;
    if (!frozen && _spawnTimer > 2.0) {
      _spawnTimer = 0;
      _recycle();
    }
    _fill();

    _elapsed += dt;
    if (_elapsed > _warmup) {
      _frameSamples.add(total);
      if (_frameSamples.length > 120) _frameSamples.removeAt(0);
    }
    if (_frameSamples.isNotEmpty) {
      final sorted = [..._frameSamples]..sort();
      final avg = _frameSamples.reduce((a, b) => a + b) / _frameSamples.length;
      frameMs = avg;
      fps = avg > 0 ? 1000.0 / avg : 0;
      // The 95th percentile matters more than the mean for a game: a crowd
      // that averages 60 but stutters every second reads as broken.
      p95Ms = sorted[(sorted.length * 0.95).floor().clamp(0, sorted.length - 1)];
    }

    // Reported to the console as well as the overlay, so the numbers can be
    // collected from an automated run rather than read off a screenshot.
    _reportTimer += dt;
    if (_elapsed > _warmup && _reportTimer >= 1.0) {
      _reportTimer = 0;
      // ignore: avoid_print
      print(
        'TELEMETRY units=${sim.mobs.length} drawn=$drawn '
        'fps=${fps.toStringAsFixed(1)} '
        'frame=${frameMs.toStringAsFixed(2)}ms '
        'p95=${p95Ms.toStringAsFixed(2)}ms '
        'sim=${simMs.toStringAsFixed(2)}ms',
      );
    }

    super.update(dt);
  }

  /// Sends anyone who has walked out of the lane back to their own end.
  void _recycle() {
    for (final m in sim.mobs) {
      if (m.z.abs() > 20) {
        m
          ..z = m.team == 0 ? 16.0 : -16.0
          ..x = (_rng.nextDouble() * 2 - 1) * Mob.laneHalf
          ..combatTarget = null;
      }
    }
  }

  void setMobCount(int n) {
    targetMobs = n;
    _fill();
  }

  int get drawn => crowd.lastDrawn;
}
