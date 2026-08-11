import 'dart:math' as math;

import 'package:mobrush_sim/mobrush_sim.dart';
import 'package:test/test.dart';

void main() {
  group('the Standard Cannon\'s authored defaults (CannonLibrary row 0)', () {
    test('construction matches the base row exactly', () {
      final cannon = Cannon(
        fireRate: 0.045,
        launchSpeed: 6.0,
        launchLift: 2.2,
        spread: 0.09,
        ammoCapacity: 130,
      );
      expect(cannon.reserve, equals(130));
      expect(cannon.ammoRemaining, equals(130));
      expect(cannon.ammoSpent, equals(0));
    });
  });

  group('aim clamps so the cannon can never fire back up the lane', () {
    test(
      'aiming dead backward with no sideways component collapses to '
      'straight forward -- the second normalize has nothing but z to '
      'rescale, so it does not stop at -0.35',
      () {
        final cannon = Cannon()..setAim(0, 1);
        expect(cannon.aimX, closeTo(0.0, 1e-9));
        expect(cannon.aimZ, closeTo(-1.0, 1e-6));
      },
    );

    test(
      'aiming backward with a sideways component clamps partway, not to '
      'exactly -0.35 -- matches the double-normalize in UpdateAim exactly',
      () {
        final cannon = Cannon()..setAim(1, 1);
        // Unclamped normalize of (1,1) is (0.707, 0.707); clamping z to
        // -0.35 gives (0.707, -0.35); the second normalize (mag ~0.789)
        // yields these values.
        expect(cannon.aimX, closeTo(0.8963, 1e-3));
        expect(cannon.aimZ, closeTo(-0.4436, 1e-3));
      },
    );

    test('aiming forward is unaffected by the clamp', () {
      final cannon = Cannon()..setAim(0, -1);
      expect(cannon.aimZ, closeTo(-1.0, 1e-6));
    });

    test('a zero-length aim vector is ignored, keeping the previous aim', () {
      final cannon = Cannon()..setAim(0, -1);
      cannon.setAim(0, 0);
      expect(cannon.aimZ, closeTo(-1.0, 1e-6));
    });
  });

  group('fire rate cooldown', () {
    test('a second shot within fireRate seconds is refused', () {
      final cannon = Cannon(fireRate: 0.045);
      final first = cannon.fire(canAffordLaunch: () => true, consumeLaunchCost: () {});
      expect(first, isNotEmpty);
      final second = cannon.fire(canAffordLaunch: () => true, consumeLaunchCost: () {});
      expect(second, isEmpty);
    });

    test('a shot becomes available again once the cooldown elapses', () {
      final cannon = Cannon(fireRate: 0.045);
      cannon.fire(canAffordLaunch: () => true, consumeLaunchCost: () {});
      cannon.tick(0.05);
      final shots = cannon.fire(canAffordLaunch: () => true, consumeLaunchCost: () {});
      expect(shots, isNotEmpty);
    });
  });

  group('ammo bookkeeping', () {
    test('reserve depletes by exactly one shot for mobsPerShot=1', () {
      final cannon = Cannon(ammoCapacity: 130, mobsPerShot: 1);
      cannon.fire(canAffordLaunch: () => true, consumeLaunchCost: () {});
      expect(cannon.reserve, equals(129));
    });

    test('an empty reserve refuses to fire', () {
      final cannon = Cannon(ammoCapacity: 1, mobsPerShot: 1);
      cannon.fire(canAffordLaunch: () => true, consumeLaunchCost: () {});
      expect(cannon.reserve, equals(0));
      final shots = cannon.fire(canAffordLaunch: () => true, consumeLaunchCost: () {});
      expect(shots, isEmpty);
    });

    test('unlimited mode never depletes reserve', () {
      final cannon = Cannon(ammoCapacity: 1, unlimited: true, mobsPerShot: 3);
      cannon.fire(canAffordLaunch: () => true, consumeLaunchCost: () {});
      expect(cannon.reserve, equals(1));
      expect(cannon.ammoRemaining, equals(1));
    });

    test('an unaffordable shot (no energy) is refused without spending ammo', () {
      final cannon = Cannon(ammoCapacity: 130);
      final shots = cannon.fire(canAffordLaunch: () => false, consumeLaunchCost: () {});
      expect(shots, isEmpty);
      expect(cannon.reserve, equals(130));
    });
  });

  group('multi-shot spread fan (mobsPerShot > 1)', () {
    test('produces exactly mobsPerShot launches when fully affordable', () {
      final cannon = Cannon(mobsPerShot: 3, spread: 0.0)..setAim(0, -1);
      var consumed = 0;
      final shots = cannon.fire(
        canAffordLaunch: () => true,
        consumeLaunchCost: () => consumed++,
      );
      expect(shots, hasLength(3));
      expect(consumed, equals(3));
    });

    test('the fan is centred on the aim direction, spreading symmetrically', () {
      final cannon = Cannon(mobsPerShot: 3, spread: 0.0, launchSpeed: 6.0)
        ..setAim(0, -1);
      final shots = cannon.fire(canAffordLaunch: () => true, consumeLaunchCost: () {});
      // Middle shot should point almost straight down -Z; the outer two
      // should be mirrored left/right around it.
      expect(shots[1].dirX, closeTo(0, 1e-6));
      expect(shots[0].dirX, closeTo(-shots[2].dirX, 1e-6));
    });

    test('running out of affordability mid-fan returns fewer shots than requested', () {
      final cannon = Cannon(mobsPerShot: 5, spread: 0.0)..setAim(0, -1);
      var calls = 0;
      final shots = cannon.fire(
        canAffordLaunch: () {
          calls++;
          return calls <= 2; // affordable for the first shot, then the
          // second (i=1) canAffordLaunch check fails.
        },
        consumeLaunchCost: () {},
      );
      expect(shots.length, lessThan(5));
      expect(shots, isNotEmpty);
    });
  });

  group('launch velocity', () {
    test('direction is a unit vector scaled by launchSpeed', () {
      final cannon = Cannon(mobsPerShot: 1, spread: 0.0, launchSpeed: 6.0)
        ..setAim(0, -1);
      final shots = cannon.fire(canAffordLaunch: () => true, consumeLaunchCost: () {});
      final s = shots.single;
      final mag = math.sqrt(s.dirX * s.dirX + s.dirZ * s.dirZ);
      expect(mag, closeTo(6.0, 1e-9));
    });

    test('launchY centres on launchLift', () {
      final cannon = Cannon(mobsPerShot: 1, launchLift: 2.2)..setAim(0, -1);
      final shots = cannon.fire(canAffordLaunch: () => true, consumeLaunchCost: () {});
      expect(shots.single.launchY, closeTo(2.2, 0.31));
    });
  });
}
