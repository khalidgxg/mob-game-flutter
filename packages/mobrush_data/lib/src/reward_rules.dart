/// How a finished round turns into coins. Port of
/// `Assets/Scripts/Data/RewardRules.cs`.
class RewardRules {
  const RewardRules({
    this.repeatRewardRate = 0.25,
    this.starBonusRate = 0.25,
    this.firstWinOfDayBonus = 1.0,
    this.maxCoinsPerRound = 0,
  });

  /// Fraction of the first-clear reward paid for replaying an already-cleared
  /// stage. Low enough that farming an easy stage is never better than
  /// moving forward.
  final double repeatRewardRate;

  /// Extra fraction of the base reward per star above the first.
  final double starBonusRate;

  /// Extra fraction paid on the first won round of each day.
  final double firstWinOfDayBonus;

  /// Hard ceiling on one round's payout. 0 disables it.
  final int maxCoinsPerRound;

  factory RewardRules.fromJson(Map<String, dynamic> json) => RewardRules(
        repeatRewardRate: (json['repeatRewardRate'] as num).toDouble(),
        starBonusRate: (json['starBonusRate'] as num).toDouble(),
        firstWinOfDayBonus: (json['firstWinOfDayBonus'] as num).toDouble(),
        maxCoinsPerRound: (json['maxCoinsPerRound'] as num).toInt(),
      );
}

/// What a finished round paid out, and why. Port of `RoundReward`.
class RoundReward {
  const RoundReward({
    required this.coins,
    required this.stars,
    required this.firstClear,
    required this.firstWinOfDay,
    required this.improvedStars,
  });

  final int coins;
  final int stars;
  final bool firstClear;
  final bool firstWinOfDay;

  /// Stars beaten on a replay, which pay their difference once.
  final int improvedStars;
}

/// Port of `RewardCalculator`. The rule that matters most is the first one:
/// before it existed, a completed stage paid the full authored reward every
/// time, so the optimal play was to farm the easiest stage forever and no
/// reward curve could mean anything.
class RewardCalculator {
  static RoundReward compute({
    required int baseCoins,
    required int stars,
    required int previousStars,
    required bool firstWinOfDay,
    RewardRules rules = const RewardRules(),
  }) {
    final clampedStars = stars.clamp(1, 3);
    final clampedPrevious = previousStars.clamp(0, 3);
    final firstClear = clampedPrevious <= 0;

    double multiplier;
    var improved = 0;

    if (firstClear) {
      multiplier = 1.0 + rules.starBonusRate * (clampedStars - 1);
    } else {
      multiplier = rules.repeatRewardRate;
      // Beating your own star count pays the difference you never collected,
      // once. Replaying at the same rating does not.
      improved = (clampedStars - clampedPrevious) > 0
          ? clampedStars - clampedPrevious
          : 0;
      multiplier += rules.starBonusRate * improved;
    }

    if (firstWinOfDay) multiplier += rules.firstWinOfDayBonus;

    var coins = (baseCoins * multiplier).round();
    if (coins < 0) coins = 0;
    if (rules.maxCoinsPerRound > 0 && coins > rules.maxCoinsPerRound) {
      coins = rules.maxCoinsPerRound;
    }
    return RoundReward(
      coins: coins,
      stars: clampedStars,
      firstClear: firstClear,
      firstWinOfDay: firstWinOfDay,
      improvedStars: improved,
    );
  }
}

/// Port of `StarRating`. Before this existed, every stage authored a flat
/// 3-star reward unconditionally — no partial result, no reason to replay,
/// no skill-based lever for the economy.
class StarRating {
  static const double healthStarThreshold = 0.5;

  static int evaluate({
    required double baseHealthFraction,
    required double elapsedSeconds,
    required double parSeconds,
  }) {
    var stars = 1; // winning at all
    if (baseHealthFraction > healthStarThreshold) stars++; // kept the line
    if (parSeconds > 0 && elapsedSeconds <= parSeconds) stars++; // beat the clock
    return stars.clamp(1, 3);
  }
}
