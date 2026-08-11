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
  levels: [],
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

BattleRound _round({double startingEnergy = 100, String selectedCharacterId = 'base'}) {
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
  );
}

void main() {
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
