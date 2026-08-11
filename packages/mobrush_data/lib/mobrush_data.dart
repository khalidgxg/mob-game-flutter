/// Content models for MobRush, loaded from the JSON `ContentExporter.cs`
/// exports out of Unity's ScriptableObject catalogs.
///
/// Scope note: this currently covers characters, cannons, and reward rules —
/// the slice `ContentExporter` exports today. `StageDefinition` and
/// `AbilityDefinition` are not yet exported or modeled here; see the
/// migration plan's Phase 1 section for what remains.
library;

export 'src/cannon_definition.dart';
export 'src/character_definition.dart';
export 'src/content_catalog.dart';
export 'src/mob_stats.dart';
export 'src/reward_rules.dart';
