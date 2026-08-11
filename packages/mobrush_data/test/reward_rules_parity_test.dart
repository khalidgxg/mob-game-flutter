import 'package:mobrush_data/mobrush_data.dart';
import 'package:test/test.dart';

/// Same style as `mobrush_sim`'s parity tests: each case names the specific
/// behaviour the C# source's comments record as the reason the rule exists,
/// not just "does it run".
void main() {
  group('farming the easiest stage is never optimal', () {
    test('a first clear pays more than any replay of the same stars', () {
      const rules = RewardRules();
      final first = RewardCalculator.compute(
        baseCoins: 100,
        stars: 2,
        previousStars: 0,
        firstWinOfDay: false,
        rules: rules,
      );
      final replay = RewardCalculator.compute(
        baseCoins: 100,
        stars: 2,
        previousStars: 2,
        firstWinOfDay: false,
        rules: rules,
      );
      expect(replay.coins, lessThan(first.coins));
      expect(first.firstClear, isTrue);
      expect(replay.firstClear, isFalse);
    });
  });

  group('beating your own star count pays the difference once', () {
    test('improving from 1 to 3 stars on replay pays more than repeating at 1', () {
      const rules = RewardRules();
      final repeat = RewardCalculator.compute(
        baseCoins: 100,
        stars: 1,
        previousStars: 1,
        firstWinOfDay: false,
        rules: rules,
      );
      final improved = RewardCalculator.compute(
        baseCoins: 100,
        stars: 3,
        previousStars: 1,
        firstWinOfDay: false,
        rules: rules,
      );
      expect(improved.improvedStars, equals(2));
      expect(improved.coins, greaterThan(repeat.coins));
    });

    test('replaying at the same rating improves nothing', () {
      final r = RewardCalculator.compute(
        baseCoins: 100,
        stars: 2,
        previousStars: 2,
        firstWinOfDay: false,
      );
      expect(r.improvedStars, equals(0));
    });
  });

  group('the ceiling is a promise, not a suggestion', () {
    test('maxCoinsPerRound caps stacked bonuses', () {
      const rules = RewardRules(
        starBonusRate: 5.0,
        firstWinOfDayBonus: 5.0,
        maxCoinsPerRound: 200,
      );
      final r = RewardCalculator.compute(
        baseCoins: 1000,
        stars: 3,
        previousStars: 0,
        firstWinOfDay: true,
        rules: rules,
      );
      expect(r.coins, equals(200));
    });

    test('zero disables the ceiling', () {
      const rules = RewardRules(maxCoinsPerRound: 0, starBonusRate: 1.0);
      final r = RewardCalculator.compute(
        baseCoins: 1000,
        stars: 3,
        previousStars: 0,
        firstWinOfDay: false,
        rules: rules,
      );
      expect(r.coins, greaterThan(1000));
    });
  });

  group('star rating', () {
    test('a bare win is always at least one star', () {
      final s = StarRating.evaluate(
        baseHealthFraction: 0.1,
        elapsedSeconds: 999,
        parSeconds: 10,
      );
      expect(s, equals(1));
    });

    test('keeping the base line above half earns a second star', () {
      final s = StarRating.evaluate(
        baseHealthFraction: 0.6,
        elapsedSeconds: 999,
        parSeconds: 10,
      );
      expect(s, equals(2));
    });

    test('beating par time on top of a healthy base earns all three', () {
      final s = StarRating.evaluate(
        baseHealthFraction: 0.9,
        elapsedSeconds: 5,
        parSeconds: 10,
      );
      expect(s, equals(3));
    });

    test('a disabled par (0) never contributes the third star', () {
      final s = StarRating.evaluate(
        baseHealthFraction: 0.9,
        elapsedSeconds: 1,
        parSeconds: 0,
      );
      expect(s, equals(2));
    });
  });
}
