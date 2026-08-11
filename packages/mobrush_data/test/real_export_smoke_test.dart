import 'dart:io';

import 'package:mobrush_data/mobrush_data.dart';
import 'package:test/test.dart';

/// This is the file that actually matters for the Phase 1 gate: real output
/// from `MobRush ▸ Export Content for Flutter`, run in the live Unity
/// project and copied in unmodified — not the hand-authored fixture the rest
/// of this package's tests use for math coverage.
///
/// A parse failure here means the exporter and this loader have drifted;
/// that is a contract break the hand-authored fixture cannot catch, because
/// it is written by hand to agree with the loader.
void main() {
  late ContentCatalog catalog;

  setUpAll(() {
    final json =
        File('test/fixtures/real_export_content.json').readAsStringSync();
    catalog = ContentCatalog.fromJsonString(json);
  });

  test('the real export parses without error', () {
    expect(catalog.characters, isNotEmpty);
  });

  test('every character has a non-empty id and display name', () {
    for (final c in catalog.characters) {
      expect(c.id, isNotEmpty);
      expect(c.displayName, isNotEmpty);
    }
  });

  test('character ids are unique', () {
    final ids = catalog.characters.map((c) => c.id).toList();
    expect(ids.toSet().length, equals(ids.length));
  });

  test('statsAtLevel resolves for every authored level of every character', () {
    for (final c in catalog.characters) {
      for (var lvl = 0; lvl <= c.levels.length; lvl++) {
        final s = c.statsAtLevel(lvl);
        expect(s.hp, greaterThan(0), reason: '${c.id} at level $lvl');
      }
    }
  });

  group('the CannonLibrary export fix is confirmed against a re-export', () {
    test('both code-authored cannons are present', () {
      expect(catalog.cannons.map((c) => c.id), containsAll(['cannon', 'heavy']));
    });

    test('standard cannon base stats match CannonLibrary.BuildSpecs() row 0', () {
      final cannon = catalog.cannon('cannon')!;
      expect(cannon.ammoCapacity, equals(130));
      expect(cannon.rushUnitCount, equals(3));
      expect(cannon.fireRate, closeTo(0.045, 1e-6));
    });

    test('purchasing level 1 applies the exact delta between rows 0 and 1', () {
      final cannon = catalog.cannon('cannon')!;
      final s = cannon.statsAtLevel(1);
      // BuildSpecs() row 1 is absolute (ammo 138, energy 110); the exporter
      // stores the delta from row 0, and statsAtLevel adds it back on -- so
      // this also checks the export's delta encoding round-trips correctly.
      expect(s.ammoCapacity, equals(138));
      expect(s.energyCapacity, closeTo(110.0, 1e-6));
      expect(s.playerHealthBonus, equals(35));
    });

    test('statsAtLevel resolves for every authored level of every cannon', () {
      for (final c in catalog.cannons) {
        for (var lvl = 0; lvl <= c.levels.length; lvl++) {
          final s = c.statsAtLevel(lvl);
          expect(s.ammoCapacity, greaterThan(0), reason: '${c.id} at level $lvl');
        }
      }
    });
  });

  test('reward rules load with the live authored values', () {
    // Live values differ from this package's defaults (starBonusRate: 0,
    // maxCoinsPerRound: 10) -- confirms the export carries real authored
    // numbers, not just the RewardRules() default constructor.
    expect(catalog.rewardRules.starBonusRate, equals(0.0));
    expect(catalog.rewardRules.maxCoinsPerRound, equals(10));
  });
}
