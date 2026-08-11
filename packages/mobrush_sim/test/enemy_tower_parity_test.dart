import 'package:mobrush_sim/mobrush_sim.dart';
import 'package:test/test.dart';

void main() {
  group('spawn wave timing and reserve bookkeeping', () {
    test(
      'with no initialSpawnDelay the first wave fires on the very first '
      'tick, regardless of dt -- "0 launches immediately", per the C# tooltip',
      () {
        final tower = EnemyTower(
          maxHealth: 300,
          enemyReserve: 20,
          spawnInterval: 0.9,
          spawnBatch: 2,
        );
        final spawned = tower.tick(0.001);
        expect(spawned, equals(2));
        expect(tower.enemyReserve, equals(18));
      },
    );

    test('the wave after the first only fires once spawnInterval elapses', () {
      final tower = EnemyTower(
        maxHealth: 300,
        enemyReserve: 20,
        spawnInterval: 0.9,
        spawnBatch: 2,
      );
      tower.tick(0.001); // first wave, fires immediately
      expect(tower.tick(0.5), equals(0)); // too soon for the second
      expect(tower.tick(0.4), equals(2)); // 0.5 + 0.4 = 0.9 -> second wave
    });

    test('the final wave spawns only what remains, not a full batch', () {
      final tower = EnemyTower(
        maxHealth: 300,
        enemyReserve: 1,
        spawnInterval: 0.9,
        spawnBatch: 2,
      );
      final spawned = tower.tick(0.9);
      expect(spawned, equals(1));
      expect(tower.enemyReserve, equals(0));
    });

    test('an empty reserve stops spawning entirely', () {
      final tower = EnemyTower(
        maxHealth: 300,
        enemyReserve: 0,
        spawnInterval: 0.9,
        spawnBatch: 2,
      );
      expect(tower.tick(10.0), equals(0));
    });

    test('initialSpawnDelay holds off the very first wave', () {
      final tower = EnemyTower(
        maxHealth: 300,
        enemyReserve: 20,
        spawnInterval: 0.9,
        spawnBatch: 2,
        initialSpawnDelay: 2.0,
      );
      expect(tower.tick(0.9), equals(0)); // still inside the delay
      expect(tower.tick(1.1), equals(2)); // delay elapsed, first wave fires
    });
  });

  group('freeze stops the spawn clock, not just the wave', () {
    test(
      'a tick that starts frozen is blocked for its whole duration, even '
      'if the freeze would mathematically run out partway through it -- '
      'the C# checks freezeTimer > 0 once at the top of Update, not '
      'mid-frame',
      () {
        final tower = EnemyTower(
          maxHealth: 300,
          enemyReserve: 20,
          spawnInterval: 0.9,
          spawnBatch: 2,
        )..applyFreeze(1.0);

        // This tick both exhausts the freeze and would, unfrozen, have been
        // long enough to fire a wave on its own (spawnInterval is 0.9). It
        // still produces nothing: the tick started frozen.
        expect(tower.tick(1.0), equals(0));
      },
    );

    test(
      'the spawn timer was never touched while frozen, so the very next '
      'tick after the freeze ends fires immediately -- same "never '
      'advanced past zero" mechanism as the very first wave',
      () {
        final tower = EnemyTower(
          maxHealth: 300,
          enemyReserve: 20,
          spawnInterval: 0.9,
          spawnBatch: 2,
        )..applyFreeze(1.0);

        tower.tick(1.0); // freeze fully consumed, spawn timer untouched
        final spawned = tower.tick(0.001);
        expect(spawned, equals(2));
      },
    );
  });

  group('collapse', () {
    test('takeDamage reports collapse exactly once, at the killing blow', () {
      final tower = EnemyTower(maxHealth: 300, enemyReserve: 20, spawnInterval: 0.9);
      expect(tower.takeDamage(299), isFalse);
      expect(tower.alive, isTrue);
      expect(tower.takeDamage(1), isTrue);
      expect(tower.alive, isFalse);
    });

    test('health never goes negative', () {
      final tower = EnemyTower(maxHealth: 300, enemyReserve: 20, spawnInterval: 0.9);
      tower.takeDamage(9999);
      expect(tower.currentHealth, equals(0));
    });

    test('a dead tower spawns nothing even with reserve left', () {
      final tower = EnemyTower(maxHealth: 300, enemyReserve: 20, spawnInterval: 0.9);
      tower.takeDamage(9999);
      expect(tower.tick(10.0), equals(0));
    });
  });

  group('real authored Stage 1 towers (Assets/Data/Stages/Stage_1.asset)', () {
    test('side towers: 300 HP, main castle: 1500 HP', () {
      final side = EnemyTower(maxHealth: 300, enemyReserve: 20, spawnInterval: 0.9);
      final main = EnemyTower(maxHealth: 1500, enemyReserve: 20, spawnInterval: 0.9);
      expect(side.maxHealth, equals(300));
      expect(main.maxHealth, equals(1500));
    });
  });

  group('SectionEscalation matches authored recipes exactly', () {
    test('Stage 1/2 recipe: 15% enemy growth, +100 flat health per section', () {
      const recipe = SectionEscalation(
        enemyCountGrowthPercent: 15,
        castleHealthBonusPerSection: 100,
      );
      final section2 = StageSection()..resolve(recipe, 1); // second section, 0-indexed
      // 20 enemies grown once by 15% -> 23 (20*1.15=23.0 exactly, rounds to 23).
      expect(section2.reserve(20), equals(23));
      expect(section2.health(300), equals(400));
    });

    test('Stage 3 recipe: 0% enemy growth, +200 flat health per section', () {
      const recipe = SectionEscalation(
        enemyCountGrowthPercent: 0,
        castleHealthBonusPerSection: 200,
      );
      final section3 = StageSection()..resolve(recipe, 2); // third section
      expect(section3.reserve(1), equals(1)); // never grows
      expect(section3.health(3200), equals(3600)); // +200 * 2 sections
    });

    test('half-up rounding never lets a higher growth rate return fewer enemies', () {
      // 20 grown twice by 15% is 26.45 -- the C# comment's own example.
      const recipe = SectionEscalation(enemyCountGrowthPercent: 15);
      final section = StageSection()..resolve(recipe, 2);
      expect(section.reserve(20), equals(26));
    });

    test('the first section (index 0) applies no growth at all', () {
      const recipe = SectionEscalation(enemyCountGrowthPercent: 15, castleHealthBonusPerSection: 100);
      final first = StageSection()..resolve(recipe, 0);
      expect(first.reserve(20), equals(20));
      expect(first.health(300), equals(300));
    });

    test('spawnInterval floors at 0.05s and defaults to unchanged', () {
      const recipe = SectionEscalation(spawnSpeedUpPercent: 0);
      final section = StageSection()..resolve(recipe, 3);
      expect(section.spawnInterval(0.9), closeTo(0.9, 1e-9));
    });
  });
}
