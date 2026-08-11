import 'dart:convert';

import 'package:mobrush_save/mobrush_save.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Port of `LocalJsonSaveStore.cs`. That version writes a JSON file under
/// `Application.persistentDataPath`; `SharedPreferences` is the closest
/// equivalent that works identically on Android and web (where there is no
/// writable filesystem to put a JSON file in), so this keeps the same
/// load/save contract — missing or corrupt data falls back to a fresh
/// profile rather than throwing, exactly like the C# try/catch does.
class ProfileService {
  static const _key = 'mobrush_profile_v1';

  Future<PlayerProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return PlayerProfile()..normalize();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final profile = PlayerProfile.fromJson(json);
      profile.normalize();
      return profile;
    } catch (_) {
      return PlayerProfile()..normalize();
    }
  }

  Future<void> save(PlayerProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(profile.toJson()));
  }
}
