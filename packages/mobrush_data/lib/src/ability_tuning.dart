/// One tunable number on an ability, addressable by name. Port of
/// `AbilityStat` in `Assets/Scripts/Data/AbilityDefinition.cs`.
enum AbilityStat { charges, radius, duration, mobDamage, castleDamage, minimumDamage }

/// The complete tuning for one ability at one purchased level. Port of
/// `AbilityTuning` in `Assets/Scripts/Data/StageDefinition.cs`. The row is
/// the ability's absolute tuning at that level, matching
/// `CharacterLevelDefinition`'s "absolute, not delta" convention on purpose
/// — the source comments both call this out as deliberate.
class AbilityTuning {
  const AbilityTuning({
    this.charges = 1,
    this.duration = 0.0,
    this.radius = 3.0,
    this.mobDamageFraction = 0.5,
    this.mobDamage = 0.0,
    this.castleDamage = 150,
    this.minimumDamage = 5.0,
  });

  final int charges;

  /// Effect duration in seconds. Used by Freeze and status effects.
  final double duration;

  /// World-space effect radius.
  final double radius;

  /// Fraction of a mob's maximum HP dealt as damage. Mobs are small and
  /// self-scaling, so a fraction here reads as "deletes a unit" at any tier.
  final double mobDamageFraction;

  /// Flat damage dealt to a mob after its defence is compensated. Fireball
  /// uses this so its power stays predictable against high-HP enemies; zero
  /// keeps the legacy fraction-based behaviour (Lightning).
  final double mobDamage;

  /// Flat damage dealt to a castle — deliberately not a fraction of its
  /// max health, or a tankier castle would make the ability's damage do
  /// nothing at all.
  final int castleDamage;

  /// Guaranteed minimum damage before defence is applied.
  final double minimumDamage;

  static double read(AbilityTuning tuning, AbilityStat stat) {
    switch (stat) {
      case AbilityStat.charges:
        return tuning.charges.toDouble();
      case AbilityStat.radius:
        return tuning.radius;
      case AbilityStat.duration:
        return tuning.duration;
      case AbilityStat.mobDamage:
        return tuning.mobDamage > 0 ? tuning.mobDamage : tuning.mobDamageFraction;
      case AbilityStat.castleDamage:
        return tuning.castleDamage.toDouble();
      case AbilityStat.minimumDamage:
        return tuning.minimumDamage;
    }
  }

  factory AbilityTuning.fromJson(Map<String, dynamic> json) => AbilityTuning(
        charges: (json['charges'] as num).toInt(),
        duration: (json['duration'] as num).toDouble(),
        radius: (json['radius'] as num).toDouble(),
        mobDamageFraction: (json['mobDamageFraction'] as num).toDouble(),
        mobDamage: (json['mobDamage'] as num).toDouble(),
        castleDamage: (json['castleDamage'] as num).toInt(),
        minimumDamage: (json['minimumDamage'] as num).toDouble(),
      );
}

/// One purchasable level of an ability.
class AbilityLevelDefinition {
  const AbilityLevelDefinition({
    required this.tuning,
    required this.unlockCost,
    required this.requiredStageIndex,
  });

  final AbilityTuning tuning;
  final int unlockCost;
  final int requiredStageIndex;

  factory AbilityLevelDefinition.fromJson(Map<String, dynamic> json) =>
      AbilityLevelDefinition(
        tuning: AbilityTuning.fromJson(json['tuning'] as Map<String, dynamic>),
        unlockCost: (json['unlockCost'] as num).toInt(),
        requiredStageIndex: (json['requiredStageIndex'] as num).toInt(),
      );
}

/// Authored definition of a battle ability. Port of `AbilityDefinition.cs` —
/// visual fields (icon, displayedStats — shop presentation) are left out for
/// the same reason as on `CharacterDefinition`/`CannonDefinition`.
class AbilityDefinition {
  const AbilityDefinition({
    required this.id,
    required this.displayName,
    required this.unlockCost,
    required this.unlockRequiredStage,
    required this.baseTuning,
    required this.levels,
  });

  final String id;
  final String displayName;
  final int unlockCost;
  final int unlockRequiredStage;
  final AbilityTuning baseTuning;
  final List<AbilityLevelDefinition> levels;

  /// The ability's tuning after buying [purchasedLevel] levels. Level 0 is
  /// the base row. Port of `AbilityDefinition.TuningAtLevel`.
  AbilityTuning tuningAtLevel(int purchasedLevel) {
    if (levels.isEmpty) return baseTuning;
    final index = purchasedLevel.clamp(0, levels.length);
    return index == 0 ? baseTuning : levels[index - 1].tuning;
  }

  factory AbilityDefinition.fromJson(Map<String, dynamic> json) => AbilityDefinition(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        unlockCost: (json['unlockCost'] as num).toInt(),
        unlockRequiredStage: (json['unlockRequiredStage'] as num).toInt(),
        baseTuning: AbilityTuning.fromJson(json['baseTuning'] as Map<String, dynamic>),
        levels: (json['levels'] as List)
            .cast<Map<String, dynamic>>()
            .map(AbilityLevelDefinition.fromJson)
            .toList(),
      );
}
