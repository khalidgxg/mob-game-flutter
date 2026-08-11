import 'package:mobrush_save/mobrush_save.dart';
import 'package:test/test.dart';

void main() {
  test('schema version stays a named constant, never inlined', () {
    // The C# comment is explicit: nothing else may hardcode this number,
    // because a test that spells it out goes stale on the next bump. This
    // test checks the constant exists and normalize() stamps it — it does
    // not itself hardcode 7 anywhere but here, once.
    final p = PlayerProfile();
    p.schemaVersion = 3;
    p.normalize();
    expect(p.schemaVersion, equals(PlayerProfile.currentSchemaVersion));
  });

  group('stage stars only ever improve', () {
    test('a lower star count on replay does not overwrite the best result', () {
      final p = PlayerProfile()..setStageStars('stage_1', 3);
      p.setStageStars('stage_1', 1);
      expect(p.getStageStars('stage_1'), equals(3));
    });

    test('a higher star count does overwrite', () {
      final p = PlayerProfile()..setStageStars('stage_1', 1);
      p.setStageStars('stage_1', 3);
      expect(p.getStageStars('stage_1'), equals(3));
    });

    test('an unknown stage reports zero stars, not an error', () {
      final p = PlayerProfile();
      expect(p.getStageStars('never-played'), equals(0));
    });
  });

  group('section clearing is idempotent and stage-scoped', () {
    test('the same section key is not duplicated on repeat clears', () {
      final p = PlayerProfile()
        ..markSectionCleared('stage_1', 2)
        ..markSectionCleared('stage_1', 2);
      expect(p.clearedSections, equals(['stage_1/2']));
    });

    test('section 2 of stage_1 is distinct from section 2 of stage_2', () {
      final p = PlayerProfile()
        ..markSectionCleared('stage_1', 2)
        ..markSectionCleared('stage_2', 2);
      expect(p.isSectionCleared('stage_1', 2), isTrue);
      expect(p.isSectionCleared('stage_2', 2), isTrue);
      expect(p.isSectionCleared('stage_1', 3), isFalse);
    });

    test('a negative section index clamps to 0 rather than producing a bad key', () {
      expect(PlayerProfile.sectionKey('stage_1', -5), equals('stage_1/0'));
    });
  });

  group('character unlock announcement is a presentation flag, not ownership', () {
    test('announcing a character does not unlock it', () {
      final p = PlayerProfile()..markCharacterUnlockAnnounced('monkey');
      expect(p.hasAnnouncedCharacterUnlock('monkey'), isTrue);
      expect(p.isCharacterUnlocked('monkey'), isFalse);
    });

    test('unlocking a character does not mark it announced', () {
      final p = PlayerProfile()..unlockedCharacterIds.add('monkey');
      expect(p.isCharacterUnlocked('monkey'), isTrue);
      expect(p.hasAnnouncedCharacterUnlock('monkey'), isFalse);
    });
  });

  group('per-id progress accessors behave like a dictionary', () {
    test('an id with no purchased levels reports level 0, not an error', () {
      final p = PlayerProfile();
      expect(p.getCharacterLevel('base'), equals(0));
      expect(p.getCannonLevel('cannon'), equals(0));
      expect(p.getAbilityLevel('freeze'), equals(0));
    });

    test('setting a level twice updates in place rather than duplicating', () {
      final p = PlayerProfile()
        ..setCharacterLevel('base', 1)
        ..setCharacterLevel('base', 2);
      expect(p.characterProgress, hasLength(1));
      expect(p.getCharacterLevel('base'), equals(2));
    });
  });

  group('normalize clamps negative values rather than trusting stored state', () {
    test('a corrupted negative highestStageUnlocked is clamped to 0', () {
      final p = PlayerProfile()..highestStageUnlocked = -3;
      p.normalize();
      expect(p.highestStageUnlocked, equals(0));
    });

    test('a corrupted playerLevel below 1 is clamped to 1', () {
      final p = PlayerProfile()..playerLevel = 0;
      p.normalize();
      expect(p.playerLevel, equals(1));
    });
  });

  group('JSON round-trip', () {
    test('toJson then fromJson reproduces the same profile', () {
      final p = PlayerProfile()
        ..currency = 999
        ..characterRoster.addAll(['base', 'monkey'])
        ..setCharacterLevel('base', 3)
        ..setStageStars('stage_1', 2)
        ..markSectionCleared('stage_1', 0);

      final restored = PlayerProfile.fromJson(p.toJson());

      expect(restored.currency, equals(999));
      expect(restored.characterRoster, equals(['base', 'monkey']));
      expect(restored.getCharacterLevel('base'), equals(3));
      expect(restored.getStageStars('stage_1'), equals(2));
      expect(restored.isSectionCleared('stage_1', 0), isTrue);
    });

    test('a fresh profile\'s defaults survive the round-trip', () {
      final restored = PlayerProfile.fromJson(PlayerProfile().toJson());
      expect(restored.currency, equals(550));
      expect(restored.gems, equals(120));
      expect(restored.playerLevel, equals(1));
    });
  });
}
