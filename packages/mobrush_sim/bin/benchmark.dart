import 'dart:math' as math;

import 'package:mobrush_sim/mobrush_sim.dart';

/// Headless cost measurement for the crowd simulation.
///
/// The question this answers is narrow and deliberately so: how long does one
/// fixed step of the ported crowd solve take at battle scale? At 60 Hz a frame
/// has a 16.67 ms budget that the simulation *shares* with rendering, so the
/// simulation alone needs to fit in a small fraction of it.
///
/// This is a desktop number, not a phone number. A mid-range phone core runs
/// roughly 2-4x slower than this machine, so the headroom ratio matters far
/// more than the absolute milliseconds.
void main() {
  print('MobRush crowd simulation — headless step cost');
  print('Dart ${_dartVersion()}');
  print('');

  for (final count in [100, 200, 350, 500, 1000]) {
    _run(count);
  }

  print('');
  print('Budget at 60 Hz: 16.67 ms per frame, shared with rendering.');
}

void _run(int count) {
  final sim = BattleSim(maxMobs: count);
  final rng = math.Random(1234);

  // Two crowds facing each other down the lane, in the density the real game
  // produces after a x5 gate: packed shoulder to shoulder across the lane
  // width, marching into contact. The measurement is taken while the two sides
  // are interpenetrating, which is the worst case for the spatial hash.
  for (var i = 0; i < count; i++) {
    final team = i.isEven ? 0 : 1;
    sim.spawn(
      team: team,
      x: (rng.nextDouble() * 2 - 1) * Mob.laneHalf,
      y: Mob.groundY,
      z: team == 0
          ? 4.0 + rng.nextDouble() * 6.0
          : -4.0 - rng.nextDouble() * 6.0,
      speed: 1.76,
      seekRange: 2.6,
    )?.phase = MobPhase.grounded;
  }

  // Warm up so the JIT has optimised the hot loop before anything is timed.
  for (var i = 0; i < 300; i++) {
    sim.step(BattleSim.fixedStep);
  }

  const steps = 1000;
  final sw = Stopwatch()..start();
  for (var i = 0; i < steps; i++) {
    sim.step(BattleSim.fixedStep);
  }
  sw.stop();

  final msPerStep = sw.elapsedMicroseconds / steps / 1000.0;
  final budgetPct = msPerStep / 16.67 * 100;
  final pairs = sim.crowd.lastPairChecks;

  print(
    '${count.toString().padLeft(4)} mobs  '
    '${msPerStep.toStringAsFixed(3).padLeft(7)} ms/step  '
    '${budgetPct.toStringAsFixed(1).padLeft(5)}% of a 60 Hz frame  '
    '${pairs.toString().padLeft(7)} pair checks  '
    '(${(pairs / count).toStringAsFixed(1)} per mob)',
  );
}

String _dartVersion() {
  final v = const String.fromEnvironment('dart.version');
  if (v.isNotEmpty) return v;
  return 'runtime';
}
