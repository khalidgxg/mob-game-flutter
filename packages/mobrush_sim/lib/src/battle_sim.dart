import 'dart:math' as math;

import 'crowd_manager.dart';
import 'mob.dart';

/// A whole battle, one fixed-step update at a time.
///
/// The Unity original spreads this across `Game`, `CrowdManager` and each
/// `Mob.Update()`, held together by `[DefaultExecutionOrder]` attributes. Here
/// the order is written out plainly, because it is load-bearing: the crowd
/// solve must publish steering before any mob consumes it, or every unit acts
/// on a frame-old view of its neighbours.
///
/// The step is fixed rather than tied to the display refresh. A crowd solve is
/// sensitive to step size — separation is a per-frame impulse — so a simulation
/// driven by a variable `deltaTime` drifts in behaviour between a 60 Hz phone
/// and a 120 Hz one. Rendering interpolates; the simulation does not.
class BattleSim {
  BattleSim({this.maxMobs = 350});

  /// Hard cap on live mobs. Mirrors `GameConfig.maxMobs`.
  final int maxMobs;

  /// Fixed simulation step — 60 Hz, matching the cadence the C# was tuned at.
  static const double fixedStep = 1.0 / 60.0;

  final CrowdManager crowd = CrowdManager();
  final List<Mob> mobs = [];

  int _nextIndex = 0;
  double _accumulator = 0;

  int get liveCount {
    var n = 0;
    for (final m in mobs) {
      if (!m.dead) n++;
    }
    return n;
  }

  Mob? spawn({
    required int team,
    required double x,
    required double y,
    required double z,
    double speed = 1.76,
    double seekRange = 2.6,
    double crowdSeparationRadius = 0.0,
  }) {
    if (liveCount >= maxMobs) return null;
    final m = Mob(
      team: team,
      index: _nextIndex++,
      speed: speed,
      seekRange: seekRange,
      crowdSeparationRadius: crowdSeparationRadius,
    )
      ..x = x
      ..y = y
      ..z = z;
    mobs.add(m);
    return m;
  }

  /// Advances the battle by real elapsed time, running as many fixed steps as
  /// that time covers. Clamped so a stalled frame cannot trigger a spiral of
  /// catch-up steps that stalls the next frame in turn.
  void advance(double realDt) {
    _accumulator += math.min(realDt, 0.25);
    while (_accumulator >= fixedStep) {
      _accumulator -= fixedStep;
      step(fixedStep);
    }
  }

  /// One fixed simulation step.
  void step(double dt) {
    crowd.update(mobs);
    for (var i = 0; i < mobs.length; i++) {
      mobs[i].tick(dt);
    }
    for (var i = 0; i < mobs.length; i++) {
      mobs[i].updateCombatState();
    }
  }
}
