import 'package:mobrush_data/mobrush_data.dart';

/// Stand-in Stage 1 content, matching the same real authored values used in
/// `mobrush_sim`'s `battle_round_integration_test.dart` (Recruit/base_enemy
/// stats, tower healths, opening formation counts). Not loaded from a real
/// `content.json` export yet — see the migration plan's Phase 1 notes on
/// `LevelBuilder` for wiring an actual stage JSON through instead of this
/// hardcoded stand-in.
const stage1Recruit = CharacterDefinition(
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

const stage1BaseEnemy = CharacterDefinition(
  id: 'base_enemy',
  displayName: 'Base Enemy',
  role: CharacterRole.stageEnemy,
  visualScale: 0.5,
  crowdSeparationRadius: 0,
  baseStats: MobStats(hp: 12, atk: 4, def: 1, speed: 1.4, attackSpeed: 1.2, seekRange: 3.0),
  launchEnergyCost: 0,
  levels: [],
  unlockCost: 0,
  unlockRequiredStage: -1,
  unlockAfterStageId: '',
  maxDeploymentsPerRound: 0,
  spawnInStartingFormation: false,
);

const stage1Content = ContentCatalog(
  characters: [stage1Recruit, stage1BaseEnemy],
  cannons: [],
  abilities: [],
  rewardRules: RewardRules(),
);
