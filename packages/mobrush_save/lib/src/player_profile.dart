/// Persistent, account-linkable save state. Port of
/// `Assets/Scripts/Save/PlayerProfile.cs` — a plain POCO there with no
/// MonoBehaviour or Unity asset references, which is why this port is close
/// to a transliteration rather than a redesign.
///
/// The C# comment block explains why dictionaries are avoided: Unity's
/// `JsonUtility` cannot serialize them, so per-key data is lists of entries
/// with dictionary-like accessors instead. Dart's `dart:convert` has no such
/// restriction, but the shape is kept identical anyway — field-for-field —
/// so a real save exported from the live game can be read here without a
/// translation step, and so this stays the same data model the C# code
/// reviews against.
class PlayerProfile {
  PlayerProfile();

  /// Bump this and add the migration to a future `normalize()` step on any
  /// structural change. Nothing else may hardcode the number.
  static const int currentSchemaVersion = 7;

  int schemaVersion = currentSchemaVersion;
  String accountId = ''; // empty = local-only; set on cloud login

  // Account meta — independent of any character's level.
  int playerLevel = 1;
  int playerStars = 0;
  int currency = 550;
  int gems = 120;

  // Stage progress.
  int highestStageUnlocked = 0; // ordered index, not an id string
  List<StageStarEntry> stageStars = [];

  /// Days since 1970-01-01 UTC of the last won round, so the first win of a
  /// day can pay a bonus. A day number rather than a timestamp: it is the
  /// only granularity the rule needs and it cannot drift by hours.
  int lastWinDayUtc = 0;

  /// Section reached inside [highestStageUnlocked]. Kept separate from it on
  /// purpose: folding section into that field would silently reinterpret
  /// every saved profile and every authored requiredStageIndex.
  int highestSectionUnlocked = 0;

  /// "stage_1/2" keys of sections already beaten, so a replay can be told
  /// from a first clear — what stops farming the easiest section forever.
  List<String> clearedSections = [];

  /// Exact stage ids whose authored rounds are all cleared. Separate from the
  /// frontier index: the final authored stage has no "next" stage but can
  /// still unlock a player character.
  List<String> completedStageIds = [];

  /// One-time presentation marker for the post-victory unit card. Ownership
  /// stays in [unlockedCharacterIds]; seeing the card never grants a unit.
  List<String> announcedCharacterUnlockIds = [];

  // Per-character purchased level — the real source of truth for a
  // character's combat stats.
  List<CharacterProgressEntry> characterProgress = [];
  List<CannonProgressEntry> cannonProgress = [];
  List<AbilityProgressEntry> abilityProgress = [];

  // Ownership + current loadout.
  List<String> unlockedCharacterIds = [];
  List<String> unlockedCannonIds = [];
  List<String> unlockedAbilityIds = [];

  /// Ordered battle roster. The first entry is the primary character used by
  /// the opening formation; the player can equip one to four unlocked
  /// characters here.
  List<String> characterRoster = [];

  /// Kept only so old profile JSON migrates without losing the former
  /// single-character selection. New code reads [characterRoster] instead.
  String selectedCharacterId = '';
  String selectedCannonId = '';

  int getCharacterLevel(String id) {
    for (final e in characterProgress) {
      if (e.id == id) return e.level;
    }
    return 0; // 0 = base (no purchased levels yet)
  }

  void setCharacterLevel(String id, int level) {
    for (var i = 0; i < characterProgress.length; i++) {
      if (characterProgress[i].id == id) {
        characterProgress[i] = CharacterProgressEntry(id: id, level: level);
        return;
      }
    }
    characterProgress.add(CharacterProgressEntry(id: id, level: level));
  }

  int getAbilityLevel(String id) {
    for (final e in abilityProgress) {
      if (e.id == id) return e.level;
    }
    return 0;
  }

  void setAbilityLevel(String id, int level) {
    for (var i = 0; i < abilityProgress.length; i++) {
      if (abilityProgress[i].id == id) {
        abilityProgress[i] = AbilityProgressEntry(id: id, level: level);
        return;
      }
    }
    abilityProgress.add(AbilityProgressEntry(id: id, level: level));
  }

  bool isAbilityUnlocked(String id) => unlockedAbilityIds.contains(id);

  int getCannonLevel(String id) {
    for (final e in cannonProgress) {
      if (e.id == id) return e.level;
    }
    return 0;
  }

  void setCannonLevel(String id, int level) {
    for (var i = 0; i < cannonProgress.length; i++) {
      if (cannonProgress[i].id == id) {
        cannonProgress[i] = CannonProgressEntry(id: id, level: level);
        return;
      }
    }
    cannonProgress.add(CannonProgressEntry(id: id, level: level));
  }

  /// Clamps and defaults every field to a valid state, and stamps the schema
  /// version. Port of `PlayerProfile.Normalize`.
  void normalize() {
    playerLevel = playerLevel < 1 ? 1 : playerLevel;
    highestStageUnlocked = highestStageUnlocked < 0 ? 0 : highestStageUnlocked;
    lastWinDayUtc = lastWinDayUtc < 0 ? 0 : lastWinDayUtc;
    highestSectionUnlocked =
        highestSectionUnlocked < 0 ? 0 : highestSectionUnlocked;
    schemaVersion = currentSchemaVersion;
  }

  /// Stable key for one section of one stage, e.g. "stage_1/2".
  static String sectionKey(String stageId, int sectionIndex) =>
      '$stageId/${sectionIndex < 0 ? 0 : sectionIndex}';

  bool isSectionCleared(String stageId, int sectionIndex) =>
      clearedSections.contains(sectionKey(stageId, sectionIndex));

  void markSectionCleared(String stageId, int sectionIndex) {
    final key = sectionKey(stageId, sectionIndex);
    if (!clearedSections.contains(key)) clearedSections.add(key);
  }

  bool isStageCompleted(String stageId) =>
      stageId.isNotEmpty && completedStageIds.contains(stageId);

  void markStageCompleted(String stageId) {
    if (stageId.isEmpty) return;
    if (!completedStageIds.contains(stageId)) completedStageIds.add(stageId);
  }

  bool hasAnnouncedCharacterUnlock(String characterId) =>
      characterId.isNotEmpty &&
      announcedCharacterUnlockIds.contains(characterId);

  void markCharacterUnlockAnnounced(String characterId) {
    if (characterId.isEmpty) return;
    if (!announcedCharacterUnlockIds.contains(characterId)) {
      announcedCharacterUnlockIds.add(characterId);
    }
  }

  /// Days since the Unix epoch, UTC — the granularity the daily bonus needs.
  static int todayUtc() {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    return today.difference(DateTime.utc(1970, 1, 1)).inDays;
  }

  int getStageStars(String stageId) {
    for (final e in stageStars) {
      if (e.stageId == stageId) return e.stars;
    }
    return 0;
  }

  void setStageStars(String stageId, int stars) {
    for (var i = 0; i < stageStars.length; i++) {
      if (stageStars[i].stageId == stageId) {
        if (stars <= stageStars[i].stars) return; // keep the best
        stageStars[i] = StageStarEntry(stageId: stageId, stars: stars);
        return;
      }
    }
    stageStars.add(StageStarEntry(stageId: stageId, stars: stars));
  }

  bool isCharacterUnlocked(String id) => unlockedCharacterIds.contains(id);
  bool isCannonUnlocked(String id) => unlockedCannonIds.contains(id);

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'accountId': accountId,
        'playerLevel': playerLevel,
        'playerStars': playerStars,
        'currency': currency,
        'gems': gems,
        'highestStageUnlocked': highestStageUnlocked,
        'stageStars': stageStars.map((e) => e.toJson()).toList(),
        'lastWinDayUtc': lastWinDayUtc,
        'highestSectionUnlocked': highestSectionUnlocked,
        'clearedSections': clearedSections,
        'completedStageIds': completedStageIds,
        'announcedCharacterUnlockIds': announcedCharacterUnlockIds,
        'characterProgress': characterProgress.map((e) => e.toJson()).toList(),
        'cannonProgress': cannonProgress.map((e) => e.toJson()).toList(),
        'abilityProgress': abilityProgress.map((e) => e.toJson()).toList(),
        'unlockedCharacterIds': unlockedCharacterIds,
        'unlockedCannonIds': unlockedCannonIds,
        'unlockedAbilityIds': unlockedAbilityIds,
        'characterRoster': characterRoster,
        'selectedCharacterId': selectedCharacterId,
        'selectedCannonId': selectedCannonId,
      };

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    final p = PlayerProfile()
      ..schemaVersion = (json['schemaVersion'] as num?)?.toInt() ?? currentSchemaVersion
      ..accountId = json['accountId'] as String? ?? ''
      ..playerLevel = (json['playerLevel'] as num?)?.toInt() ?? 1
      ..playerStars = (json['playerStars'] as num?)?.toInt() ?? 0
      ..currency = (json['currency'] as num?)?.toInt() ?? 550
      ..gems = (json['gems'] as num?)?.toInt() ?? 120
      ..highestStageUnlocked = (json['highestStageUnlocked'] as num?)?.toInt() ?? 0
      ..lastWinDayUtc = (json['lastWinDayUtc'] as num?)?.toInt() ?? 0
      ..highestSectionUnlocked =
          (json['highestSectionUnlocked'] as num?)?.toInt() ?? 0
      ..clearedSections =
          (json['clearedSections'] as List?)?.cast<String>() ?? []
      ..completedStageIds =
          (json['completedStageIds'] as List?)?.cast<String>() ?? []
      ..announcedCharacterUnlockIds =
          (json['announcedCharacterUnlockIds'] as List?)?.cast<String>() ?? []
      ..unlockedCharacterIds =
          (json['unlockedCharacterIds'] as List?)?.cast<String>() ?? []
      ..unlockedCannonIds =
          (json['unlockedCannonIds'] as List?)?.cast<String>() ?? []
      ..unlockedAbilityIds =
          (json['unlockedAbilityIds'] as List?)?.cast<String>() ?? []
      ..characterRoster =
          (json['characterRoster'] as List?)?.cast<String>() ?? []
      ..selectedCharacterId = json['selectedCharacterId'] as String? ?? ''
      ..selectedCannonId = json['selectedCannonId'] as String? ?? '';

    p.stageStars = (json['stageStars'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(StageStarEntry.fromJson)
        .toList();
    p.characterProgress = (json['characterProgress'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(CharacterProgressEntry.fromJson)
        .toList();
    p.cannonProgress = (json['cannonProgress'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(CannonProgressEntry.fromJson)
        .toList();
    p.abilityProgress = (json['abilityProgress'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .map(AbilityProgressEntry.fromJson)
        .toList();
    return p;
  }
}

class CharacterProgressEntry {
  const CharacterProgressEntry({required this.id, required this.level});
  final String id;
  final int level;
  Map<String, dynamic> toJson() => {'id': id, 'level': level};
  factory CharacterProgressEntry.fromJson(Map<String, dynamic> j) =>
      CharacterProgressEntry(
        id: j['id'] as String,
        level: (j['level'] as num).toInt(),
      );
}

class CannonProgressEntry {
  const CannonProgressEntry({required this.id, required this.level});
  final String id;
  final int level;
  Map<String, dynamic> toJson() => {'id': id, 'level': level};
  factory CannonProgressEntry.fromJson(Map<String, dynamic> j) =>
      CannonProgressEntry(
        id: j['id'] as String,
        level: (j['level'] as num).toInt(),
      );
}

class AbilityProgressEntry {
  const AbilityProgressEntry({required this.id, required this.level});
  final String id;
  final int level;
  Map<String, dynamic> toJson() => {'id': id, 'level': level};
  factory AbilityProgressEntry.fromJson(Map<String, dynamic> j) =>
      AbilityProgressEntry(
        id: j['id'] as String,
        level: (j['level'] as num).toInt(),
      );
}

class StageStarEntry {
  const StageStarEntry({required this.stageId, required this.stars});
  final String stageId;
  final int stars;
  Map<String, dynamic> toJson() => {'stageId': stageId, 'stars': stars};
  factory StageStarEntry.fromJson(Map<String, dynamic> j) => StageStarEntry(
        stageId: j['stageId'] as String,
        stars: (j['stars'] as num).toInt(),
      );
}
