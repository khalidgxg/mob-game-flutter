import 'mob_stats.dart';

enum CharacterRole { playerRoster, stageEnemy }

CharacterRole _roleFromString(String s) =>
    s == 'StageEnemy' ? CharacterRole.stageEnemy : CharacterRole.playerRoster;

/// One purchasable level on a character's own upgrade path. The row is the
/// absolute stat line at that level, not the gain over the previous one — see
/// `CharacterLevelDefinition` in the C# source for why absolute rows are the
/// ones worth authoring.
class CharacterLevelDefinition {
  const CharacterLevelDefinition({
    required this.stats,
    required this.unlockCost,
    required this.requiredStageIndex,
  });

  final MobStats stats;
  final int unlockCost;

  /// -1 = no stage gate.
  final int requiredStageIndex;

  factory CharacterLevelDefinition.fromJson(Map<String, dynamic> json) =>
      CharacterLevelDefinition(
        stats: MobStats.fromJson(json['stats'] as Map<String, dynamic>),
        unlockCost: (json['unlockCost'] as num).toInt(),
        requiredStageIndex: (json['requiredStageIndex'] as num).toInt(),
      );
}

/// Port of `CharacterDefinition.cs`. This is data plus the pure functions the
/// C# type computes over its own fields (`StatsAtLevel`,
/// `DeployableCountForRound`) — everything that touched a Unity asset
/// reference (`Sprite icon`, `AnimationClip`, `GameObject visualPrefab`) is
/// left out, because those become baked sprite-atlas lookups instead
/// (`CrowdSpriteBaker` / `CharacterAtlas`), not Dart fields.
class CharacterDefinition {
  const CharacterDefinition({
    required this.id,
    required this.displayName,
    required this.role,
    required this.visualScale,
    required this.crowdSeparationRadius,
    required this.baseStats,
    required this.launchEnergyCost,
    required this.levels,
    required this.unlockCost,
    required this.unlockRequiredStage,
    required this.unlockAfterStageId,
    required this.maxDeploymentsPerRound,
    required this.spawnInStartingFormation,
  });

  final String id;
  final String displayName;
  final CharacterRole role;
  final double visualScale;

  /// World-space personal-space radius for crowd steering. 0 uses the shared
  /// CrowdManager default.
  final double crowdSeparationRadius;

  final MobStats baseStats;
  final int launchEnergyCost;
  final List<CharacterLevelDefinition> levels;

  final int unlockCost;
  final int unlockRequiredStage;
  final String unlockAfterStageId;

  /// 0 = unlimited.
  final int maxDeploymentsPerRound;
  final bool spawnInStartingFormation;

  bool get isPlayerRosterCharacter => role == CharacterRole.playerRoster;

  /// Gates may freely create ordinary player units but must not create a unit
  /// whose round limit is reserved for an explicit cannon/Rush launch — this
  /// is what keeps a limited unit like Max at its authored one-per-round cap.
  bool get canBeGeneratedByGate =>
      !isPlayerRosterCharacter || maxDeploymentsPerRound <= 0;

  int deployableCountForRound(int deploymentsAlreadyUsed, int requestedCount) {
    final requested = requestedCount < 0 ? 0 : requestedCount;
    if (maxDeploymentsPerRound <= 0) return requested;
    final used = deploymentsAlreadyUsed < 0 ? 0 : deploymentsAlreadyUsed;
    final remaining = maxDeploymentsPerRound - used;
    if (remaining < 0) return 0;
    return remaining < requested ? remaining : requested;
  }

  /// The character's stat line after buying [purchasedLevel] levels. Level 0
  /// is the base row. All exported content is already schema-3 absolute rows
  /// — the C# schema-0 delta fallback has nothing left to migrate here.
  MobStats statsAtLevel(int purchasedLevel) {
    final index = purchasedLevel.clamp(0, levels.length);
    return index == 0 ? baseStats : levels[index - 1].stats;
  }

  factory CharacterDefinition.fromJson(Map<String, dynamic> json) =>
      CharacterDefinition(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        role: _roleFromString(json['role'] as String),
        visualScale: (json['visualScale'] as num).toDouble(),
        crowdSeparationRadius:
            (json['crowdSeparationRadius'] as num).toDouble(),
        baseStats: MobStats.fromJson(json['baseStats'] as Map<String, dynamic>),
        launchEnergyCost: (json['launchEnergyCost'] as num).toInt(),
        levels: (json['levels'] as List)
            .cast<Map<String, dynamic>>()
            .map(CharacterLevelDefinition.fromJson)
            .toList(),
        unlockCost: (json['unlockCost'] as num).toInt(),
        unlockRequiredStage: (json['unlockRequiredStage'] as num).toInt(),
        unlockAfterStageId: json['unlockAfterStageId'] as String? ?? '',
        maxDeploymentsPerRound: (json['maxDeploymentsPerRound'] as num).toInt(),
        spawnInStartingFormation: json['spawnInStartingFormation'] as bool,
      );
}
