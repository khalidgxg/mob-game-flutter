import 'dart:io';

import 'package:mobrush_data/mobrush_data.dart';
import 'package:test/test.dart';

/// This fixture is hand-authored to match `ContentExporter.cs`'s exact JSON
/// shape — it is NOT a real export, because no Unity installation was
/// available to run the exporter. It exercises the parser and the ported
/// math; it does not by itself prove the exporter's output round-trips.
/// A real `content.json` from Unity should replace it as soon as one exists.
void main() {
  late ContentCatalog catalog;

  setUpAll(() {
    final json = File('test/fixtures/sample_content.json').readAsStringSync();
    catalog = ContentCatalog.fromJsonString(json);
  });

  test('parses every character and cannon', () {
    expect(catalog.characters, hasLength(2));
    expect(catalog.cannons, hasLength(1));
  });

  test('character lookup by id resolves', () {
    final base = catalog.character('base');
    expect(base, isNotNull);
    expect(base!.displayName, equals('Recruit'));
    expect(catalog.character('does-not-exist'), isNull);
  });

  group('CharacterDefinition.statsAtLevel matches the C# absolute-row rule', () {
    test('level 0 is the base row', () {
      final base = catalog.character('base')!;
      expect(base.statsAtLevel(0).hp, equals(2.0));
    });

    test('level 1 is the authored absolute row, not base + bonus', () {
      final base = catalog.character('base')!;
      expect(base.statsAtLevel(1).hp, equals(3.0));
    });

    test('a level beyond what is authored clamps to the last row', () {
      final base = catalog.character('base')!;
      expect(base.statsAtLevel(99).hp, equals(3.0));
    });
  });

  group('deployableCountForRound mirrors the C# clamp', () {
    test('unlimited (0) never restricts', () {
      final base = catalog.character('base')!;
      expect(base.deployableCountForRound(1000, 50), equals(50));
    });

    test('a capped character stops once the cap is used up', () {
      final max = catalog.character('max')!;
      expect(max.maxDeploymentsPerRound, equals(1));
      expect(max.deployableCountForRound(0, 5), equals(1));
      expect(max.deployableCountForRound(1, 5), equals(0));
    });

    test('a capped, non-roster-limited character can still be gate-spawned', () {
      final base = catalog.character('base')!;
      expect(base.canBeGeneratedByGate, isTrue);
      final max = catalog.character('max')!;
      expect(max.canBeGeneratedByGate, isFalse);
    });
  });

  group('CannonDefinition.statsAtLevel matches the C# additive-bonus rule', () {
    test('level 0 is the base block', () {
      final cannon = catalog.cannon('cannon')!;
      final s = cannon.statsAtLevel(0);
      expect(s.ammoCapacity, equals(130));
      expect(s.rushUnitCount, equals(7));
    });

    test('one purchased level adds its bonus additively', () {
      final cannon = catalog.cannon('cannon')!;
      final s = cannon.statsAtLevel(1);
      expect(s.ammoCapacity, equals(140));
      expect(s.rushUnitCount, equals(8));
      expect(s.launchSpeed, closeTo(6.5, 1e-9));
    });

    test('fireRate is floored at 0.01, matching the C# clamp', () {
      // Only one level is authored in the fixture, so this also checks that
      // purchasedLevels beyond what exists does not read out of range.
      final cannon = catalog.cannon('cannon')!;
      final s = cannon.statsAtLevel(10);
      expect(s.fireRate, closeTo(0.043, 1e-9));
      expect(s.fireRate, greaterThanOrEqualTo(0.01));
    });
  });

  test('reward rules load from the same export', () {
    expect(catalog.rewardRules.repeatRewardRate, equals(0.25));
  });

  test('an unsupported formatVersion is rejected rather than silently misread', () {
    expect(
      () => ContentCatalog.fromJsonString('{"formatVersion": 2}'),
      throwsFormatException,
    );
  });
}
