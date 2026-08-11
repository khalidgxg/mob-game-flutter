/// Additive stat bonuses granted by one purchased cannon level. Field names
/// carry the `Bonus` suffix the exported JSON uses (`CannonStats` in the C#
/// is reused for both the base stat block and the per-level delta; the export
/// format keeps them apart instead so this side never has to know which is
/// which from context).
class CannonLevelDefinition {
  const CannonLevelDefinition({
    required this.unlockCost,
    required this.requiredStageIndex,
    required this.fireRateBonus,
    required this.launchSpeedBonus,
    required this.launchLiftBonus,
    required this.spreadBonus,
    required this.ammoCapacityBonus,
    required this.mobsPerShotBonus,
    required this.mobScaleBonus,
    required this.rushUnitCountBonus,
    required this.energyCapacityBonus,
    required this.energyRegenPerSecondBonus,
    required this.playerHealthBonusBonus,
  });

  final int unlockCost;
  final int requiredStageIndex;
  final double fireRateBonus;
  final double launchSpeedBonus;
  final double launchLiftBonus;
  final double spreadBonus;
  final int ammoCapacityBonus;
  final int mobsPerShotBonus;
  final double mobScaleBonus;
  final int rushUnitCountBonus;
  final double energyCapacityBonus;
  final double energyRegenPerSecondBonus;
  final int playerHealthBonusBonus;

  factory CannonLevelDefinition.fromJson(Map<String, dynamic> json) =>
      CannonLevelDefinition(
        unlockCost: (json['unlockCost'] as num).toInt(),
        requiredStageIndex: (json['requiredStageIndex'] as num).toInt(),
        fireRateBonus: (json['fireRateBonus'] as num).toDouble(),
        launchSpeedBonus: (json['launchSpeedBonus'] as num).toDouble(),
        launchLiftBonus: (json['launchLiftBonus'] as num).toDouble(),
        spreadBonus: (json['spreadBonus'] as num).toDouble(),
        ammoCapacityBonus: (json['ammoCapacityBonus'] as num).toInt(),
        mobsPerShotBonus: (json['mobsPerShotBonus'] as num).toInt(),
        mobScaleBonus: (json['mobScaleBonus'] as num).toDouble(),
        rushUnitCountBonus: (json['rushUnitCountBonus'] as num).toInt(),
        energyCapacityBonus: (json['energyCapacityBonus'] as num).toDouble(),
        energyRegenPerSecondBonus:
            (json['energyRegenPerSecondBonus'] as num).toDouble(),
        playerHealthBonusBonus: (json['playerHealthBonusBonus'] as num).toInt(),
      );
}

/// The resolved stat block at a given purchased level — the Dart mirror of
/// `CannonStats` in `Assets/Scripts/Data/CannonDefinition.cs`, produced by
/// [CannonDefinition.statsAtLevel] rather than authored directly.
class CannonStats {
  const CannonStats({
    required this.fireRate,
    required this.launchSpeed,
    required this.launchLift,
    required this.spread,
    required this.ammoCapacity,
    required this.mobsPerShot,
    required this.mobScale,
    required this.rushUnitCount,
    required this.energyCapacity,
    required this.energyRegenPerSecond,
    required this.playerHealthBonus,
  });

  final double fireRate;
  final double launchSpeed;
  final double launchLift;
  final double spread;
  final int ammoCapacity;
  final int mobsPerShot;
  final double mobScale;
  final int rushUnitCount;
  final double energyCapacity;
  final double energyRegenPerSecond;
  final int playerHealthBonus;
}

/// Port of `CannonDefinition.cs`. Visual fields (`visualPrefabPath`,
/// `prefab`, colours) are left out for the same reason as on
/// `CharacterDefinition` — they resolve to baked sprite/atlas lookups on the
/// Flutter side, not Unity asset references.
class CannonDefinition {
  const CannonDefinition({
    required this.id,
    required this.displayName,
    required this.unlockCost,
    required this.fireRate,
    required this.launchSpeed,
    required this.launchLift,
    required this.spread,
    required this.ammoCapacity,
    required this.mobsPerShot,
    required this.mobScale,
    required this.energyCapacity,
    required this.energyRegenPerSecond,
    required this.rushUnitCount,
    required this.playerHealthBonus,
    required this.levels,
  });

  final String id;
  final String displayName;
  final int unlockCost;

  final double fireRate;
  final double launchSpeed;
  final double launchLift;
  final double spread;
  final int ammoCapacity;
  final int mobsPerShot;
  final double mobScale;
  final double energyCapacity;
  final double energyRegenPerSecond;
  final int rushUnitCount;
  final int playerHealthBonus;

  final List<CannonLevelDefinition> levels;

  /// Port of `CannonDefinition.StatsAtLevel`. Bonuses accumulate additively
  /// per purchased level, with the same floors the C# applies at the end —
  /// `mobsPerShot`/`rushUnitCount` never drop below 1, `mobScale` never below
  /// 0.1 — so a mis-authored negative bonus can shrink a stat but never break it.
  CannonStats statsAtLevel(int purchasedLevels) {
    var fireRate = this.fireRate;
    var launchSpeed = this.launchSpeed;
    var launchLift = this.launchLift;
    var spread = this.spread;
    var ammoCapacity = this.ammoCapacity;
    var mobsPerShot = this.mobsPerShot;
    var mobScale = this.mobScale;
    var rushUnitCount = this.rushUnitCount;
    var energyCapacity = this.energyCapacity;
    var energyRegenPerSecond = this.energyRegenPerSecond;
    var playerHealthBonus = this.playerHealthBonus;

    for (var i = 0; i < levels.length && i < purchasedLevels; i++) {
      final b = levels[i];
      fireRate = _maxD(0.01, fireRate + b.fireRateBonus);
      launchSpeed += b.launchSpeedBonus;
      launchLift += b.launchLiftBonus;
      spread = _maxD(0, spread + b.spreadBonus);
      ammoCapacity += b.ammoCapacityBonus;
      mobsPerShot += b.mobsPerShotBonus;
      mobScale += b.mobScaleBonus;
      rushUnitCount = _maxI(1, rushUnitCount + b.rushUnitCountBonus);
      energyCapacity = _maxD(0, energyCapacity + b.energyCapacityBonus);
      energyRegenPerSecond =
          _maxD(0, energyRegenPerSecond + b.energyRegenPerSecondBonus);
      playerHealthBonus = _maxI(0, playerHealthBonus + b.playerHealthBonusBonus);
    }

    return CannonStats(
      fireRate: fireRate,
      launchSpeed: launchSpeed,
      launchLift: launchLift,
      spread: spread,
      ammoCapacity: ammoCapacity,
      mobsPerShot: _maxI(1, mobsPerShot),
      mobScale: _maxD(0.1, mobScale),
      rushUnitCount: _maxI(1, rushUnitCount),
      energyCapacity: energyCapacity,
      energyRegenPerSecond: energyRegenPerSecond,
      playerHealthBonus: playerHealthBonus,
    );
  }

  static double _maxD(double a, double b) => a > b ? a : b;
  static int _maxI(int a, int b) => a > b ? a : b;

  factory CannonDefinition.fromJson(Map<String, dynamic> json) =>
      CannonDefinition(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        unlockCost: (json['unlockCost'] as num).toInt(),
        fireRate: (json['fireRate'] as num).toDouble(),
        launchSpeed: (json['launchSpeed'] as num).toDouble(),
        launchLift: (json['launchLift'] as num).toDouble(),
        spread: (json['spread'] as num).toDouble(),
        ammoCapacity: (json['ammoCapacity'] as num).toInt(),
        mobsPerShot: (json['mobsPerShot'] as num).toInt(),
        mobScale: (json['mobScale'] as num).toDouble(),
        energyCapacity: (json['energyCapacity'] as num).toDouble(),
        energyRegenPerSecond: (json['energyRegenPerSecond'] as num).toDouble(),
        rushUnitCount: (json['rushUnitCount'] as num).toInt(),
        playerHealthBonus: (json['playerHealthBonus'] as num).toInt(),
        levels: (json['levels'] as List)
            .cast<Map<String, dynamic>>()
            .map(CannonLevelDefinition.fromJson)
            .toList(),
      );
}
