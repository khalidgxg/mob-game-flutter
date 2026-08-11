import 'package:mobrush_sim/mobrush_sim.dart';
import 'package:test/test.dart';

void main() {
  group('the cannon\'s health bonus is additive on top of baseHealth', () {
    test('zero bonus leaves maxHealth at the authored base (25)', () {
      final base = PlayerBase(
        baseHealth: 25,
        defenceLineZ: 12.8,
        defenceLineX: 0,
      );
      expect(base.maxHealth, equals(25));
      expect(base.currentHealth, equals(25));
    });

    test('Standard Cannon level 0 grants +30 hp, matching CannonLibrary row 0', () {
      final base = PlayerBase(
        baseHealth: 25,
        cannonHealthBonus: 30,
        defenceLineZ: 12.8,
        defenceLineX: 0,
      );
      expect(base.maxHealth, equals(55));
    });
  });

  group('takeDamage', () {
    test('reports destruction exactly once, at the killing blow', () {
      final base = PlayerBase(baseHealth: 25, defenceLineZ: 0, defenceLineX: 0);
      expect(base.takeDamage(24), isFalse);
      expect(base.alive, isTrue);
      expect(base.takeDamage(1), isTrue);
      expect(base.alive, isFalse);
    });

    test('a destroyed base ignores further damage', () {
      final base = PlayerBase(baseHealth: 25, defenceLineZ: 0, defenceLineX: 0);
      base.takeDamage(999);
      expect(base.takeDamage(1), isFalse);
    });
  });

  group('the defence line sits in front of the cannon body, not on its centre', () {
    test(
      'the engage ring starts solidHalfDepth + engageHalfDepth out from the '
      'defence line -- short of that ring, nothing has engaged',
      () {
        // The C# comment: 0.4m engageHalfDepth measured from the centre put
        // an enemy inside a ~2.7m-deep carriage. solidHalfDepth pushes the
        // resolved line out in front of the body first: threshold =
        // 12.8 - 1.35 - 0.4 = 11.05.
        final base = PlayerBase(
          baseHealth: 25,
          defenceLineZ: 12.8,
          defenceLineX: 0,
          solidHalfDepth: 1.35,
          engageHalfDepth: 0.4,
        );
        // Still approaching, short of the ring.
        expect(base.isWithinDefenceLine(0, 10.9), isFalse);
        // Inside the ring (past 11.05, still short of the solid body at
        // 11.45) -- this is exactly where an enemy is meant to stop and
        // fight, outside the body it cannot walk into.
        expect(base.isWithinDefenceLine(0, 11.2), isTrue);
      },
    );

    test(
      'bodyRadius extends the engage ring outward, letting a large unit '
      'engage while its centre is still farther from the line',
      () {
        // threshold = 10.0 - 0 - bodyRadius - 0.4.
        final base = PlayerBase(
          baseHealth: 25,
          defenceLineZ: 10.0,
          defenceLineX: 0,
          solidHalfDepth: 0,
          engageHalfDepth: 0.4,
        );
        // Ordinary unit (bodyRadius 0): threshold 9.6, not yet reached.
        expect(base.isWithinDefenceLine(0, 9.0), isFalse);
        // A giant's edge (bodyRadius 1.0) reaches the ring from farther
        // back: threshold drops to 8.6, so the same centre point at 9.0
        // now counts as engaged -- this is what stops a giant from
        // "walking clean through and swinging from the far side", per the
        // C# comment on IsWithinDefenceLine.
        expect(base.isWithinDefenceLine(0, 9.0, bodyRadius: 1.0), isTrue);
      },
    );

    test('sideways range is bounded by engageHalfWidth', () {
      final base = PlayerBase(
        baseHealth: 25,
        defenceLineZ: 0,
        defenceLineX: 0,
        engageHalfWidth: 5.0,
      );
      expect(base.isWithinDefenceLine(4.9, 0), isTrue);
      expect(base.isWithinDefenceLine(5.1, 0), isFalse);
    });
  });

  group('priorityLineZ breaks the fire-distract-return stalemate', () {
    test('sits priorityRange further out than the defence line', () {
      final base = PlayerBase(
        baseHealth: 25,
        defenceLineZ: 12.8,
        defenceLineX: 0,
        solidHalfDepth: 1.0,
        priorityRange: 6.0,
      );
      expect(base.priorityLineZ, closeTo(12.8 - 1.0 - 6.0, 1e-9));
    });
  });

  test('healthFraction drives the star-rating threshold check', () {
    final base = PlayerBase(baseHealth: 100, defenceLineZ: 0, defenceLineX: 0);
    base.takeDamage(51);
    expect(base.healthFraction, closeTo(0.49, 1e-9));
  });
}
