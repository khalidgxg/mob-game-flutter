import 'package:mobrush_data/mobrush_data.dart';
import 'package:mobrush_sim/mobrush_sim.dart';
import 'package:test/test.dart';

/// `tryRush` is a second, energy-gated way to add units to the crowd —
/// distinct from the cannon's per-shot cost — port of
/// `BattleAbilityController.TryRush`. Real Recruit `launchEnergyCost` (14)
/// from the exported `content.json` is used so the cost math matches the
/// live game, not an invented number.
const _recruit = CharacterDefinition(
  id: 'base',
  displayName: 'Recruit',
  role: CharacterRole.playerRoster,
  visualScale: 0.5,
  crowdSeparationRadius: 0,
  baseStats: MobStats(hp: 20, atk: 6, def: 2, speed: 1.5, attackSpeed: 1.6, seekRange: 4.5),
  launchEnergyCost: 14,
  // Real level-1 row from the exported content.json, so the levelled-stats
  // group below asserts against authored numbers rather than invented ones.
  levels: [
    CharacterLevelDefinition(
      stats: MobStats(hp: 23, atk: 7, def: 2, speed: 1.5, attackSpeed: 1.6, seekRange: 4.5),
      unlockCost: 100,
      requiredStageIndex: -1,
    ),
  ],
  unlockCost: 0,
  unlockRequiredStage: -1,
  unlockAfterStageId: '',
  maxDeploymentsPerRound: 0,
  spawnInStartingFormation: true,
);

const _freeUnit = CharacterDefinition(
  id: 'free',
  displayName: 'Free Unit',
  role: CharacterRole.playerRoster,
  visualScale: 0.5,
  crowdSeparationRadius: 0,
  baseStats: MobStats(hp: 20, atk: 6, def: 2, speed: 1.5, attackSpeed: 1.6, seekRange: 4.5),
  launchEnergyCost: 0,
  levels: [],
  unlockCost: 0,
  unlockRequiredStage: -1,
  unlockAfterStageId: '',
  maxDeploymentsPerRound: 0,
  spawnInStartingFormation: true,
);

const _content = ContentCatalog(
  characters: [_recruit, _freeUnit],
  cannons: [],
  abilities: [],
  rewardRules: RewardRules(),
);

BattleRound _round({
  double startingEnergy = 100,
  String selectedCharacterId = 'base',
  Map<String, int>? characterLevels,
}) {
  return BattleRound(
    content: _content,
    towers: [
      EnemyTower(maxHealth: 300, enemyReserve: 20, spawnInterval: 0.9,
          spawnedCharacterId: 'base', x: 0, z: -12),
    ],
    base: PlayerBase(baseHealth: 25, cannonHealthBonus: 30, defenceLineZ: 12.8, defenceLineX: 0),
    cannon: Cannon(),
    abilities: BattleAbilities(
      freeze: const AbilityTuning(),
      fireball: const AbilityTuning(),
      lightning: const AbilityTuning(),
      maxEnergy: 100,
      startingEnergy: startingEnergy,
      selectedCharacterId: selectedCharacterId,
    ),
    maxMobs: 350,
    characterLevels: characterLevels,
  );
}

void main() {
  _levelledStatsGroup();

  group('tryRush', () {
    test('spends rushUnitCount x launchEnergyCost and spawns that many player mobs', () {
      final round = _round();
      final ok = round.tryRush(rushUnitCount: 3, formationZ: 5.6);
      expect(ok, isTrue);
      expect(round.abilities.energy, closeTo(100 - 3 * 14, 1e-9));
      expect(round.livePlayerMobCount, 3);
    });

    test('refuses (and spends nothing) when energy is short', () {
      final round = _round(startingEnergy: 10);
      final ok = round.tryRush(rushUnitCount: 3, formationZ: 5.6);
      expect(ok, isFalse);
      expect(round.abilities.energy, 10);
      expect(round.livePlayerMobCount, 0);
    });

    test('refuses when the mob cap has no room for the full deployment', () {
      final round = _round();
      for (var i = 0; i < 349; i++) {
        round.spawnMob(0, 'base', x: 0, y: 0.5, z: 0);
      }
      final ok = round.tryRush(rushUnitCount: 3, formationZ: 5.6);
      expect(ok, isFalse);
      expect(round.abilities.energy, 100);
    });

    test('a zero-cost character can rush for free', () {
      final round = _round(startingEnergy: 0, selectedCharacterId: 'free');
      final ok = round.tryRush(rushUnitCount: 2, formationZ: 5.6);
      expect(ok, isTrue);
      expect(round.abilities.energy, 0);
      expect(round.livePlayerMobCount, 2);
    });
  });
}

/// A purchased character level has to change what actually walks onto the
/// lane, or the shop is cosmetic. `Recruit` level 1 is authored at hp 23 /
/// atk 7 in the real `content.json`, against base hp 20 / atk 6.
void _levelledStatsGroup() {
  group('characterLevels', () {
    test('level 0 (or absent) spawns the authored base row', () {
      final round = _round();
      final mob = round.spawnMob(0, 'base', x: 0, y: 0.5, z: 0)!;
      expect(mob.maxHp, 20);
      expect(mob.atk, 6);
    });

    test('a purchased level spawns that level row instead', () {
      final round = _round(characterLevels: {'base': 1});
      final mob = round.spawnMob(0, 'base', x: 0, y: 0.5, z: 0)!;
      expect(mob.maxHp, 23);
      expect(mob.atk, 7);
    });

    test('the level applies to rush deployments too, not just the cannon', () {
      final round = _round(characterLevels: {'base': 1});
      expect(round.tryRush(rushUnitCount: 2, formationZ: 5.6), isTrue);
      expect(round.mobs.every((m) => m.maxHp == 23), isTrue);
    });
  });
}
