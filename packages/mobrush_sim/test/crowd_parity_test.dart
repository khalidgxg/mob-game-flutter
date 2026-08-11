import 'dart:math' as math;

import 'package:mobrush_sim/mobrush_sim.dart';
import 'package:test/test.dart';

/// These tests do not check "does it run". They check the specific behaviours
/// the C# source calls out in its comments as bugs that were found and fixed —
/// because those are exactly the behaviours a rewrite silently loses. Each one
/// names the regression it guards.
void main() {
  group('seekRange is a reach stat, not a sprint button', () {
    test('a mob hunting an enemy never exceeds its authored speed', () {
      final sim = BattleSim();
      final hunter = sim.spawn(
        team: 0,
        x: 0,
        y: Mob.groundY,
        z: 3.0,
        speed: 1.76,
        seekRange: 6.0,
      )!..phase = MobPhase.grounded;
      sim.spawn(
        team: 1,
        x: 2.0,
        y: Mob.groundY,
        z: 0.0,
        speed: 1.76,
      )!.phase = MobPhase.grounded;

      var maxObserved = 0.0;
      for (var i = 0; i < 120; i++) {
        final px = hunter.x, pz = hunter.z;
        sim.step(BattleSim.fixedStep);
        final moved = math.sqrt(
          math.pow(hunter.x - px, 2) + math.pow(hunter.z - pz, 2),
        );
        maxObserved = math.max(maxObserved, moved / BattleSim.fixedStep);
      }

      // The regression this guards: steering used to be *added* to velocity,
      // so a Recruit authored at 1.76 travelled at ~4.9 the moment an enemy
      // entered its seek range.
      expect(maxObserved, lessThanOrEqualTo(1.76 + 0.001));
    });
  });

  group('a giant is fightable', () {
    test('clash distance grows with body size so crowds cannot slide around',
        () {
      // Max-sized unit: a wide personal space, hence a real body radius.
      const giantSeparation = 2.0;
      final giantSurplus =
          math.max(Mob.minBodyRadius, giantSeparation * 0.5) -
              Mob.minBodyRadius;

      final flat = CombatLimits.clashDistance(0.40, 0, 0);
      final withGiant = CombatLimits.clashDistance(0.40, giantSurplus, 0);

      // Separation pushes opponents apart from 0.72. A flat 0.40 fighting
      // sphere sits *inside* that, so nothing could ever reach a giant's
      // centre — the crowd walked past Max as though he were not there.
      expect(flat, lessThan(0.72));
      expect(withGiant, greaterThan(0.72));
    });

    test('a giant actually locks into melee with an approaching crowd', () {
      final sim = BattleSim();
      final giant = sim.spawn(
        team: 1,
        x: 0,
        y: Mob.groundY,
        z: 0,
        speed: 0.9,
        crowdSeparationRadius: 2.0,
      )!..phase = MobPhase.grounded;
      for (var i = 0; i < 12; i++) {
        sim.spawn(
          team: 0,
          x: -1.5 + i * 0.25,
          y: Mob.groundY,
          z: 3.0,
        )!.phase = MobPhase.grounded;
      }

      for (var i = 0; i < 300; i++) {
        sim.step(BattleSim.fixedStep);
        if (giant.combatTarget != null) break;
      }
      expect(giant.combatTarget, isNotNull,
          reason: 'the crowd slid around the giant instead of fighting it');
    });
  });

  group('separation stays lateral', () {
    test('same-team crowding never pushes a mob back up its own lane', () {
      final sim = BattleSim();
      // A tight cluster of allies, all wanting the same spot.
      final probe = sim.spawn(team: 0, x: 0, y: Mob.groundY, z: 0)!
        ..phase = MobPhase.grounded;
      for (var i = 0; i < 8; i++) {
        final a = i / 8 * math.pi * 2;
        sim.spawn(
          team: 0,
          x: math.cos(a) * 0.25,
          y: Mob.groundY,
          z: math.sin(a) * 0.25,
        )!.phase = MobPhase.grounded;
      }

      sim.crowd.update(sim.mobs);

      // Injecting Z into separation is what made large units turn back up the
      // lane. The published steer must be purely sideways.
      expect(probe.steerZ, equals(0.0));
    });
  });

  group('targets behind are not chased', () {
    test('a mob ignores an enemy that has slipped behind it', () {
      final sim = BattleSim();
      final m = sim.spawn(
        team: 0,
        x: 0,
        y: Mob.groundY,
        z: 0,
        seekRange: 6.0,
      )!..phase = MobPhase.grounded;
      // Player mobs advance toward -Z, so +Z is behind this mob.
      sim.spawn(team: 1, x: 0, y: Mob.groundY, z: 2.0)!
          .phase = MobPhase.grounded;

      sim.crowd.update(sim.mobs);

      // Obeying the flip made units rock on the spot instead of advancing —
      // it read on screen as a lag spike snapping the unit backwards.
      expect(m.seekTarget, isNull);
      expect(m.seekDirZ, equals(0.0));
    });

    test('a mob in front is chased', () {
      final sim = BattleSim();
      final m = sim.spawn(
        team: 0,
        x: 0,
        y: Mob.groundY,
        z: 0,
        seekRange: 6.0,
      )!..phase = MobPhase.grounded;
      sim.spawn(team: 1, x: 0, y: Mob.groundY, z: -2.0)!
          .phase = MobPhase.grounded;

      sim.crowd.update(sim.mobs);
      expect(m.seekTarget, isNotNull);
      expect(m.seekDirZ, lessThan(0.0));
    });
  });

  group('published steering is an influence, not a velocity', () {
    test('steer magnitude never exceeds 1', () {
      final sim = BattleSim();
      final rng = math.Random(7);
      for (var i = 0; i < 200; i++) {
        sim.spawn(
          team: i.isEven ? 0 : 1,
          x: (rng.nextDouble() * 2 - 1) * 1.0,
          y: Mob.groundY,
          z: (rng.nextDouble() * 2 - 1) * 1.0,
        )!.phase = MobPhase.grounded;
      }
      sim.crowd.update(sim.mobs);

      for (final m in sim.mobs) {
        final mag = math.sqrt(m.steerX * m.steerX + m.steerZ * m.steerZ);
        expect(mag, lessThanOrEqualTo(1.0 + 1e-9));
      }
    });
  });

  group('melee holds ground', () {
    test('a clashed mob has its steering cleared, not frozen', () {
      final sim = BattleSim();
      final a = sim.spawn(team: 0, x: 0, y: Mob.groundY, z: 0.1)!
        ..phase = MobPhase.grounded;
      final b = sim.spawn(team: 1, x: 0, y: Mob.groundY, z: -0.1)!
        ..phase = MobPhase.grounded;

      sim.crowd.update(sim.mobs);

      // A carried-over steer was re-applied every frame for the whole duel,
      // walking duellists out of the disengage band — it read as a unit
      // fleeing a fight it had just started.
      expect(a.combatTarget, same(b));
      expect(a.steerX, equals(0.0));
      expect(a.steerZ, equals(0.0));
      expect(a.seekTarget, isNull);
    });
  });

  group('lane bounds', () {
    test('no mob ever leaves the lane', () {
      final sim = BattleSim();
      final rng = math.Random(3);
      for (var i = 0; i < 350; i++) {
        sim.spawn(
          team: i.isEven ? 0 : 1,
          x: (rng.nextDouble() * 2 - 1) * Mob.laneHalf,
          y: Mob.groundY,
          z: (rng.nextDouble() * 2 - 1) * 8,
        )!.phase = MobPhase.grounded;
      }
      for (var i = 0; i < 600; i++) {
        sim.step(BattleSim.fixedStep);
      }
      for (final m in sim.mobs) {
        expect(m.x.abs(), lessThanOrEqualTo(Mob.laneHalf + 1e-9));
      }
    });
  });

  group('determinism', () {
    test('two identical runs produce identical positions', () {
      List<double> run() {
        final sim = BattleSim();
        final rng = math.Random(99);
        for (var i = 0; i < 120; i++) {
          sim.spawn(
            team: i.isEven ? 0 : 1,
            x: (rng.nextDouble() * 2 - 1) * 3,
            y: Mob.groundY,
            z: (rng.nextDouble() * 2 - 1) * 6,
          )!.phase = MobPhase.grounded;
        }
        for (var i = 0; i < 200; i++) {
          sim.step(BattleSim.fixedStep);
        }
        return [for (final m in sim.mobs) ...[m.x, m.z]];
      }

      // A fixed step buys reproducibility: the same inputs must give the same
      // battle on a 60 Hz phone and a 120 Hz one.
      expect(run(), equals(run()));
    });
  });
}
