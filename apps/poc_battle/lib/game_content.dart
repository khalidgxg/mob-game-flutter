import 'package:flutter/services.dart' show rootBundle;
import 'package:mobrush_data/mobrush_data.dart';

/// Loads the real content catalog exported from Unity by
/// `ContentExporter.cs` (`Assets/Resources/ContentExport/content.json`,
/// copied verbatim into `assets/content/content.json`) — 8 characters, 2
/// cannons (Standard/Heavy), 3 abilities (Freeze/Fireball/Lightning), and
/// the reward rules. Replaces the hand-authored `stage1_content.dart`
/// stand-in everywhere except the two places that still need one:
/// `Stage1Screen`'s hardcoded `EnemyTower`/`PlayerBase`/`Gate` placement
/// (not exported — that's `LevelBuilder`'s stage-assembly JSON, separate
/// content the export doesn't cover yet) and the opening formation counts.
///
/// Cached after first load since the JSON never changes at runtime.
Future<ContentCatalog>? _cached;

Future<ContentCatalog> loadGameContent() {
  return _cached ??= rootBundle
      .loadString('assets/content/content.json')
      .then(ContentCatalog.fromJsonString);
}
