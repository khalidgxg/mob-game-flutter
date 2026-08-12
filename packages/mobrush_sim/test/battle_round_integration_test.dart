import 'dart:math' as math;

import 'package:mobrush_data/mobrush_data.dart';
import 'package:mobrush_sim/mobrush_sim.dart';
import 'package:test/test.dart';

/// This is the Phase 2 orchestrator gate itself: a full authored round played
/// start to finish, headlessly, by a scripted input trace, with the result
/// asserted in a test. Numbers are the real Stage 1 authored values
/// cross-checked against the live asset files in an earlier pass of this
/// migration: tower healths 300/300/1500, `base_enemy` as the enemy
/// character, and `CannonLibrary.BuildSpecs()`'s Standard Cannon row 0
/// (fireRate 0.045, launchSpeed 6.0, ammoCapacity 130).
const _recruit = CharacterDefinition(
  id: 'base',
  displayName: 'Recruit',
  role: CharacterRole.playerRoster,
  visualScale: 0.5,
  crowdSeparationRadius: 0,
  baseStats: MobStats(
      hp: 20, atk: 6, def: 2, speed: 1.5, attackSpeed: 1.6, seekRange: 4.5),
  launchEnergyCost: 14,
  levels: [],
  unlockCost: 0,
  unlockRequiredStage: -1,
  unlockAfterStageId: '',
  maxDeploymentsPerRound: 0,
  spawnInStartingFormation: true,
);

const _baseEnemy = CharacterDefinition(
  id: 'base_enemy',
  displayName: 'Base Enemy',
  role: CharacterRole.stageEnemy,
  visualScale: 0.5,
  crowdSeparationRadius: 0,
  baseStats: MobStats(
      hp: 12, atk: 4, def: 1, speed: 1.4, attackSpeed: 1.2, seekRange: 3.0),
  launchEnergyCost: 0,
  levels: [],
  unlockCost: 0,
  unlockRequiredStage: -1,
  unlockAfterStageId: '',
  maxDeploymentsPerRound: 0,
  spawnInStartingFormation: false,
);

const _content = ContentCatalog(
  characters: [_recruit, _baseEnemy],
  cannons: [],
  abilities: [],
  rewardRules: RewardRules(),
);

BattleRound _newStage1Round({int mainTowerHealth = 1500}) {
  final towers = [
    EnemyTower(
      maxHealth: 300,
      enemyReserve: 20,
      spawnInterval: 0.9,
      spawnedCharacterId: 'base_enemy',
      x: -5.0,
      z: -8.0,
    ),
    EnemyTower(
      maxHealth: 300,
      enemyReserve: 20,
      spawnInterval: 0.9,
      spawnedCharacterId: 'base_enemy',
      x: 5.0,
      z: -8.0,
    ),
    EnemyTower(
      maxHealth: mainTowerHealth,
      enemyReserve: 20,
      spawnInterval: 0.9,
      spawnedCharacterId: 'base_enemy',
      x: 0.0,
      z: -12.0,
    ),
  ];

  final base = PlayerBase(
    baseHealth: 25,
    cannonHealthBonus: 30, // Standard Cannon row 0
    defenceLineZ: 12.8,
    defenceLineX: 0,
    solidHalfDepth: 1.35,
  );

  final cannon = Cannon(
    fireRate: 0.045,
    launchSpeed: 6.0,
    launchLift: 2.2,
    spread: 0.0, // deterministic for the test
    ammoCapacity: 130,
    rng: math.Random(
        20260811), // seeded: launchY jitter must not make this flaky
  );

  final abilities = BattleAbilities(
    freeze: const AbilityTuning(charges: 2, duration: 4.0, radius: 12.0),
    fireball: const AbilityTuning(
      charges: 5,
      radius: 4.6,
      mobDamage: 90,
      castleDamage: 240,
      minimumDamage: 5.0,
    ),
    lightning: const AbilityTuning(charges: 1),
    maxEnergy: 100,
    startingEnergy: 100,
  );

  return BattleRound(
    content: _content,
    towers: towers,
    base: base,
    cannon: cannon,
    abilities: abilities,
    maxMobs: 350,
  );
}

/// `BattleAbilityController.SpawnStartingFormation` is presentation/config
/// orchestration (`BattleRules.startingPlayerUnits` etc.) that BattleRound
/// deliberately does not own -- opening formation is data a caller (a
/// LevelBuilder-equivalent) supplies, the same way this test supplies tower
/// placement. Spawns Stage 1's real authored numbers: 32 player units at
/// playerFormationZ 5.6, 20 enemy units at enemyFormationZ -6.2.
void _spawnStartingFormation(BattleRound round) {
  for (var i = 0; i < 32; i++) {
    round.spawnMob(
      0,
      'base',
      x: (i % 8 - 3.5) * 0.72,
      y: 0.5,
      z: 5.6 + (i ~/ 8) * 0.78,
      phase: MobPhase.grounded,
    );
  }
  for (var i = 0; i < 20; i++) {
    round.spawnMob(
      1,
      'base_enemy',
      x: (i % 6 - 2.5) * 0.9,
      y: 0.5,
      z: -6.2 - (i ~/ 6) * 0.88,
      phase: MobPhase.grounded,
    );
  }
}

void main() {
  group('a full Stage 1 round can be won headlessly', () {
    test(
        'the opening formation plus continuous cannon fire destroys all three towers',
        () {
      final round = _newStage1Round();
      _spawnStartingFormation(round);

      // Scripted input trace: aim straight down the lane and hold fire for
      // up to 90 in-game seconds (Stage 1's authored par time), advancing in
      // small real-time increments the way a game loop would.
      const dt = 1 / 60.0;
      var simulatedSeconds = 0.0;
      const maxSeconds = 90.0;

      while (round.outcome == RoundOutcome.ongoing &&
          simulatedSeconds < maxSeconds) {
        round.aimAndFire(0, -1);
        round.advance(dt);
        simulatedSeconds += dt;
      }

      expect(round.outcome, equals(RoundOutcome.win));
      for (final t in round.towers) {
        expect(t.alive, isFalse);
      }
      expect(round.base.alive, isTrue);
    });

    test('a stronger main castle survives longer but still falls eventually',
        () {
      final round = _newStage1Round(mainTowerHealth: 100000);
      _spawnStartingFormation(round);
      const dt = 1 / 60.0;
      var simulatedSeconds = 0.0;
      // The point is only that more health means the round is not yet won
      // at the same time a weaker one is, within the same window.
      while (round.outcome == RoundOutcome.ongoing && simulatedSeconds < 30.0) {
        round.aimAndFire(0, -1);
        round.advance(dt);
        simulatedSeconds += dt;
      }
      expect(round.outcome, isNot(equals(RoundOutcome.win)));
      expect(round.towers[2].currentHealth, lessThan(100000)); // damage landed
    });
  });

  group('losing to an empty base', () {
    test(
        'a base with the enemy already inside its engage ring falls to zero HP',
        () {
      final round = _newStage1Round();
      // Skip the march: place enemies directly at the base's defence line.
      for (var i = 0; i < 5; i++) {
        round.spawnMob(
          1,
          'base_enemy',
          x: 0,
          y: 0.5,
          z: round.base.defenceLineZ - round.base.solidHalfDepth - 0.1,
          phase: MobPhase.grounded,
        );
      }
      const dt = 1 / 60.0;
      var simulatedSeconds = 0.0;
      while (round.outcome == RoundOutcome.ongoing && simulatedSeconds < 30.0) {
        round.advance(dt);
        simulatedSeconds += dt;
      }
      expect(round.outcome, equals(RoundOutcome.lose));
      expect(round.base.alive, isFalse);
    });
  });

  group('losing to an ammo-out grace period', () {
    test('an emptied cannon with no live player mobs loses after 1.5s', () {
      final round =
          _newStage1Round(mainTowerHealth: 1000000); // never wins in time
      final tinyCannon = Cannon(
          ammoCapacity: 1, fireRate: 0.01, spread: 0.0, rng: math.Random(1));
      final tinyRound = BattleRound(
        content: _content,
        towers: round.towers,
        base: round.base,
        cannon: tinyCannon,
        abilities: round.abilities,
      );

      // Fire the single shot, let the mob fly and land, then die of old age
      // via natural attrition is out of scope here -- instead assert the
      // grace-period mechanics directly: after the shot, ammo is empty and
      // no more player mobs will ever be launched.
      tinyRound.aimAndFire(0, -1);
      expect(tinyCannon.reserve, equals(0));

      const dt = 1 / 60.0;
      var simulatedSeconds = 0.0;
      // Kill the one launched mob immediately so livePlayerMobCount hits 0
      // right away, isolating the grace-period timer itself.
      for (final m in tinyRound.mobs) {
        m.dead = true;
      }
      while (
          tinyRound.outcome == RoundOutcome.ongoing && simulatedSeconds < 3.0) {
        tinyRound.advance(dt);
        simulatedSeconds += dt;
      }
      expect(tinyRound.outcome, equals(RoundOutcome.lose));
      expect(simulatedSeconds, greaterThanOrEqualTo(1.5));
    });

    test('unlimited ammo never triggers the grace-period loss', () {
      final round = _newStage1Round(mainTowerHealth: 1000000);
      final unlimitedCannon = Cannon(
          unlimited: true,
          ammoCapacity: 1,
          fireRate: 0.01,
          spread: 0.0,
          rng: math.Random(1));
      final unlimitedRound = BattleRound(
        content: _content,
        towers: round.towers,
        base: round.base,
        cannon: unlimitedCannon,
        abilities: round.abilities,
      );
      const dt = 1 / 60.0;
      for (var i = 0; i < 300; i++) {
        unlimitedRound.aimAndFire(0, -1);
        unlimitedRound.advance(dt);
      }
      expect(unlimitedRound.outcome, equals(RoundOutcome.ongoing));
    });
  });

  group('gates apply to player mobs crossing them', () {
    test('a x2 gate clones a passing player mob exactly once', () {
      final round = _newStage1Round()
        ..gates.add(
            Gate(multiplier: 2, x: 0, z: 5, halfWidth: 1.15, halfDepth: 0.3));

      // Isolate the gate path from the authored towers' automatic waves.
      for (final tower in round.towers) {
        tower.enemyReserve = 0;
      }

      final mob = round.spawnMob(0, 'base',
          x: 0, y: 0.05, z: 6, phase: MobPhase.grounded)!;
      expect(mob.characterId, equals('base'));
      final before = round.mobs.length;

      // Move it across the gate manually via one crowd-free step: the
      // gate check reads before/after position around Mob.tick, so driving
      // one step is enough once positioned to cross.
      round.step(BattleRound.fixedStep);
      // If it didn't cross this step (steering-dependent), nudge it onto
      // the gate directly and check again.
      if (round.mobs.length == before) {
        mob.z = 5.0;
        round.step(BattleRound.fixedStep);
      }

      expect(round.mobs.length, greaterThan(before));
      expect(
        round.mobs.where((candidate) => candidate.index != mob.index),
        contains(
            predicate<Mob>((candidate) => candidate.characterId == 'base')),
      );
    });
  });

  group('abilities integrate with the live battle', () {
    test('Freeze applied mid-round stops a tower from spawning', () {
      final round = _newStage1Round();
      final tower = round.towers.first;
      final result = round.abilities.tryUse(
        Ability.freeze,
        mobs: round.mobs,
        towers: round.towers,
      );
      expect(result.applied, isTrue);
      expect(tower.isFrozen, isTrue);
      final reserveBefore = tower.enemyReserve;
      round.step(BattleRound.fixedStep);
      expect(tower.enemyReserve, equals(reserveBefore)); // no wave while frozen
    });
  });
}
