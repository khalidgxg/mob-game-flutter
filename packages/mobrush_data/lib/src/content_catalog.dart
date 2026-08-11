import 'dart:convert';

import 'cannon_definition.dart';
import 'character_definition.dart';
import 'reward_rules.dart';

/// The parsed output of `ContentExporter.cs`'s `content.json`.
///
/// This is the Phase 1 exit gate in miniature: if this class can parse the
/// exported file and every id resolves, the content pipeline round-trips
/// between Unity and Dart without a human touching the numbers twice.
class ContentCatalog {
  const ContentCatalog({
    required this.characters,
    required this.cannons,
    required this.rewardRules,
  });

  final List<CharacterDefinition> characters;
  final List<CannonDefinition> cannons;
  final RewardRules rewardRules;

  CharacterDefinition? character(String id) {
    for (final c in characters) {
      if (c.id == id) return c;
    }
    return null;
  }

  CannonDefinition? cannon(String id) {
    for (final c in cannons) {
      if (c.id == id) return c;
    }
    return null;
  }

  factory ContentCatalog.fromJsonString(String source) =>
      ContentCatalog.fromJson(jsonDecode(source) as Map<String, dynamic>);

  factory ContentCatalog.fromJson(Map<String, dynamic> json) {
    final formatVersion = (json['formatVersion'] as num).toInt();
    if (formatVersion != 1) {
      throw FormatException(
        'ContentCatalog: unsupported formatVersion $formatVersion '
        '(this loader understands 1). Re-export from ContentExporter or '
        'update this loader.',
      );
    }
    return ContentCatalog(
      characters: (json['characters'] as List)
          .cast<Map<String, dynamic>>()
          .map(CharacterDefinition.fromJson)
          .toList(),
      cannons: (json['cannons'] as List)
          .cast<Map<String, dynamic>>()
          .map(CannonDefinition.fromJson)
          .toList(),
      rewardRules:
          RewardRules.fromJson(json['rewardRules'] as Map<String, dynamic>),
    );
  }
}
