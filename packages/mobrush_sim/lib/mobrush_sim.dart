/// Engine-independent battle simulation for MobRush.
///
/// Nothing in this library imports Flutter or Flame. That is deliberate: the
/// simulation is the part of the game that must be identical whether it is
/// running inside a rendered scene, a headless benchmark, or a unit test.
library;

export 'src/battle_sim.dart';
export 'src/cannon.dart';
export 'src/combat_limits.dart';
export 'src/crowd_manager.dart';
export 'src/enemy_tower.dart';
export 'src/gate.dart';
export 'src/mob.dart';
export 'src/player_base.dart';
export 'src/stage_section.dart';
