import 'package:mobrush_sim/mobrush_sim.dart';
import 'package:test/test.dart';

/// Real authored gates in every shipped stage: a ×2 multiplier and a +5
/// additive squad (per the flow document cross-checked against
/// Assets/Scripts/Gameplay/Gate.cs).
void main() {
  group('×N multiplier gate', () {
    test('×2 creates exactly one clone, matching multiplier-1', () {
      final gate = Gate(multiplier: 2);
      final r = gate.apply(canGenerate: true, capacityRemaining: 100);
      expect(r.spawned, equals(1));
      expect(r.label, equals('×2'));
    });

    test('a gate with no cap room clamps below its authored promise', () {
      final gate = Gate(multiplier: 2);
      final r = gate.apply(canGenerate: true, capacityRemaining: 0);
      expect(r.spawned, equals(0));
      expect(r.requested, equals(1));
      expect(r.hitCapacity, isTrue);
      // No clone created -> no label, matching "displays nothing at all".
      expect(r.label, equals(''));
    });

    test(
      'a x3 gate that can only make one clone honestly displays x2, not x3',
      () {
        final gate = Gate(multiplier: 3);
        final r = gate.apply(canGenerate: true, capacityRemaining: 1);
        expect(r.spawned, equals(1));
        expect(r.label, equals('×2'));
      },
    );

    test('a character the gate cannot generate refuses the gate entirely', () {
      final gate = Gate(multiplier: 2);
      final r = gate.apply(canGenerate: false, capacityRemaining: 100);
      expect(r.spawned, equals(0));
      expect(r.changedCrowd, isFalse);
    });
  });

  group('+N additive gate', () {
    test('+5 grants exactly 5 units once', () {
      final gate = Gate(isAdditive: true, addAmount: 5);
      final r = gate.apply(canGenerate: true, capacityRemaining: 100);
      expect(r.spawned, equals(5));
      expect(r.label, equals('+5'));
    });

    test('a second crossing in the same round grants nothing', () {
      // This is the regression the C# comment names directly: firing per
      // crossing mob turned a "+5" into a hundred-plus unit cascade capped
      // only by the global mob limit.
      final gate = Gate(isAdditive: true, addAmount: 5);
      gate.apply(canGenerate: true, capacityRemaining: 100);
      final second = gate.apply(canGenerate: true, capacityRemaining: 100);
      expect(second.spawned, equals(0));
    });

    test('resetForRound re-arms the once-per-round spend', () {
      final gate = Gate(isAdditive: true, addAmount: 5);
      gate.apply(canGenerate: true, capacityRemaining: 100);
      gate.resetForRound();
      final r = gate.apply(canGenerate: true, capacityRemaining: 100);
      expect(r.spawned, equals(5));
    });

    test('additive is never negative even if constructed with isNegative', () {
      final gate = Gate(isAdditive: true, isNegative: true);
      expect(gate.isNegative, isFalse);
    });
  });

  group('÷N negative (thinning) gate', () {
    test('every Nth mob survives, the rest die', () {
      final gate = Gate(multiplier: 3, isNegative: true);
      final results = List.generate(
        6,
        (_) => gate.apply(canGenerate: true, capacityRemaining: 100),
      );
      // Crossings 1,2 die; 3 survives; 4,5 die; 6 survives.
      expect(results.map((r) => r.mobDied).toList(), [
        true, true, false, true, true, false,
      ]);
    });
  });
}
