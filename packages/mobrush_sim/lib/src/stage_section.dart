import 'dart:math' as math;

/// How a stage gets harder from one section to the next. Port of
/// `SectionEscalation` in `Assets/Scripts/Data/StageDefinition.cs`.
///
/// One recipe per stage, applied by section position — the C# comment
/// explains this replaced three hand-written copies of the same curve that
/// had already drifted apart across stages.
class SectionEscalation {
  const SectionEscalation({
    this.enemyCountGrowthPercent = 15.0,
    this.castleHealthBonusPerSection = 100,
    this.spawnSpeedUpPercent = 0.0,
  });

  /// Compounds: at 15, a castle holding 100 defenders fields 100, then 115,
  /// then 132.
  final double enemyCountGrowthPercent;

  /// Flat, not a factor — the same multiplier adds 6% to a 1500 keep and 33%
  /// to a 300 outpost, so it cannot express "a little tougher" for both.
  final int castleHealthBonusPerSection;

  /// 0 keeps the authored cadence, which makes a harder section longer
  /// rather than denser: the extra defenders arrive at the same rate over
  /// more time.
  final double spawnSpeedUpPercent;

  double enemyMultiplier(int sectionIndex) =>
      math.pow(1.0 + enemyCountGrowthPercent * 0.01, math.max(0, sectionIndex))
          .toDouble();

  int healthBonus(int sectionIndex) =>
      castleHealthBonusPerSection * math.max(0, sectionIndex);

  double spawnIntervalMultiplier(int sectionIndex) =>
      math.pow(1.0 - spawnSpeedUpPercent * 0.01, math.max(0, sectionIndex))
          .toDouble();
}

/// One playable step inside a stage, resolved against a [SectionEscalation]
/// recipe. Port of `StageSection` — the resolve/apply split is preserved
/// exactly: [resolve] stamps the section with the numbers its position
/// earns, and [health]/[reserve]/[spawnInterval] apply them to an authored
/// base value, matching the two-tower paths (level-builder and hand-placed)
/// the C# comment describes asking the same three questions.
class StageSection {
  StageSection({this.enemyCharacterId = ''});

  final String enemyCharacterId;

  double _enemyMultiplier = 1.0;
  int _healthBonus = 0;
  double _spawnIntervalMultiplier = 1.0;
  String _stageEnemyCharacterId = '';

  String get resolvedEnemyCharacterId =>
      enemyCharacterId.isNotEmpty ? enemyCharacterId : _stageEnemyCharacterId;

  void resolve(
    SectionEscalation recipe,
    int sectionIndex, {
    String stageEnemyCharacterId = '',
  }) {
    _enemyMultiplier = recipe.enemyMultiplier(sectionIndex);
    _healthBonus = recipe.healthBonus(sectionIndex);
    _spawnIntervalMultiplier = recipe.spawnIntervalMultiplier(sectionIndex);
    _stageEnemyCharacterId = stageEnemyCharacterId;
  }

  int health(int authored) {
    final h = authored + _healthBonus;
    return h < 1 ? 1 : h;
  }

  /// Rounded half-up rather than to-nearest-even, matching the C# comment's
  /// reasoning exactly: `Mathf.RoundToInt`'s banker's rounding turns 22.5
  /// into 22 but 23.5 into 24, so raising the growth percentage could
  /// silently hand back fewer enemies. `(x + 0.5).floor()` never does that.
  int reserve(int authored) {
    final r = (authored * _enemyMultiplier + 0.5).floor();
    return r < 0 ? 0 : r;
  }

  double spawnInterval(double authored) {
    final s = authored * _spawnIntervalMultiplier;
    return s < 0.05 ? 0.05 : s;
  }
}
