import 'package:flutter/material.dart';
import 'package:mobrush_data/mobrush_data.dart';
import 'package:mobrush_save/mobrush_save.dart';

import 'game_content.dart';
import 'profile_service.dart';

/// Port of `ShopScreen` + its Characters/Abilities/Cannons partials
/// (1,478 lines total in `Assets/Scripts/Presentation/`) — three tabbed
/// lists instead of three separate hand-built scroll rects, reading real
/// stats from the exported `content.json` (see `game_content.dart`)
/// instead of fabricated numbers.
///
/// Not yet done: no roster/loadout picker ("BATTLE TEAM" in the reference
/// screenshots), no character portrait art (Unity's are 3D renders, not
/// yet baked the way the crowd sprite atlas was in Phase 0/3), and
/// purchases don't affect the live battle yet — `Stage1Screen` still
/// spawns the base-tier "base"/"cannon" stats regardless of what's bought
/// here. Wiring a purchased loadout into `BattleRound` is separate
/// follow-up work.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

enum _ShopTab { heroes, cannons, abilities }

class _ShopScreenState extends State<ShopScreen> {
  final ProfileService _service = ProfileService();
  PlayerProfile? _profile;
  ContentCatalog? _content;
  _ShopTab _tab = _ShopTab.heroes;

  static const _bgNavy = Color(0xFF000B20);
  static const _cardDark = Color(0xF2051129);
  static const _gold = Color(0xFFFFD133);
  static const _green = Color(0xFF29B85F);
  static const _slate = Color(0xFF2C3A5C);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([_service.load(), loadGameContent()]);
    if (!mounted) return;
    setState(() {
      _profile = results[0] as PlayerProfile;
      _content = results[1] as ContentCatalog;
    });
  }

  Future<void> _persist() async {
    if (_profile != null) await _service.save(_profile!);
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final content = _content;
    if (profile == null || content == null) {
      return const Scaffold(
        backgroundColor: _bgNavy,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: _bgNavy,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(profile),
            _buildTabs(),
            Expanded(
              child: switch (_tab) {
                _ShopTab.heroes => _buildHeroes(profile, content),
                _ShopTab.cannons => _buildCannons(profile, content),
                _ShopTab.abilities => _buildAbilities(profile, content),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(PlayerProfile profile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('< BACK'),
          ),
          const Spacer(),
          const Text('SHOP',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _cardDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _slate),
            ),
            child: Row(
              children: [
                Image.asset('assets/home/icons/icon_coin.png', width: 18, height: 18),
                const SizedBox(width: 6),
                Text('${profile.currency}',
                    style: const TextStyle(color: _gold, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    Widget tab(_ShopTab t, String label) {
      final active = _tab == t;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _tab = t),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF0D59D1) : _cardDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: active ? Colors.white : const Color(0xFF8CA3CC),
                  fontWeight: FontWeight.bold,
                )),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(_ShopTab.heroes, 'HEROES'),
        tab(_ShopTab.cannons, 'CANNONS'),
        tab(_ShopTab.abilities, 'SKILLS'),
      ],
    );
  }

  // --- Heroes ----------------------------------------------------------------

  Widget _buildHeroes(PlayerProfile profile, ContentCatalog content) {
    final roster = content.characters
        .where((c) => c.role == CharacterRole.playerRoster)
        .toList();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: roster.length,
      itemBuilder: (context, i) {
        final def = roster[i];
        final unlocked = profile.isCharacterUnlocked(def.id) || def.unlockCost == 0;
        final level = profile.getCharacterLevel(def.id);
        final stats = level == 0 || def.levels.isEmpty
            ? def.baseStats
            : def.levels[(level - 1).clamp(0, def.levels.length - 1)].stats;
        final nextLevel = def.levels.length > level ? def.levels[level] : null;

        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(def.displayName,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  Text('LV ${level + 1}/${def.levels.length + 1}',
                      style: const TextStyle(color: _gold, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              _statRow('HP', stats.hp.toStringAsFixed(0)),
              _statRow('ATK', stats.atk.toStringAsFixed(1)),
              _statRow('DEF', stats.def.toStringAsFixed(1)),
              _statRow('SPD', stats.speed.toStringAsFixed(1)),
              const SizedBox(height: 10),
              if (!unlocked)
                _actionButton(
                  label: 'BUY  ${def.unlockCost}',
                  color: _green,
                  enabled: profile.currency >= def.unlockCost,
                  onTap: () => setState(() {
                    profile.currency -= def.unlockCost;
                    profile.unlockedCharacterIds.add(def.id);
                    _persist();
                  }),
                )
              else if (nextLevel != null)
                _actionButton(
                  label: 'UPGRADE  ${nextLevel.unlockCost}',
                  color: _green,
                  enabled: profile.currency >= nextLevel.unlockCost,
                  onTap: () => setState(() {
                    profile.currency -= nextLevel.unlockCost;
                    profile.setCharacterLevel(def.id, level + 1);
                    _persist();
                  }),
                )
              else
                const Text('MAX LEVEL', style: TextStyle(color: Colors.white38)),
            ],
          ),
        );
      },
    );
  }

  // --- Cannons ---------------------------------------------------------------

  Widget _buildCannons(PlayerProfile profile, ContentCatalog content) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: content.cannons.length,
      itemBuilder: (context, i) {
        final def = content.cannons[i];
        final unlocked = profile.isCannonUnlocked(def.id) || def.unlockCost == 0;
        final level = profile.getCannonLevel(def.id);
        final stats = def.statsAtLevel(level);
        final nextLevel = def.levels.length > level ? def.levels[level] : null;

        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(def.displayName,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  Text('LV ${level + 1}/${def.levels.length + 1}',
                      style: const TextStyle(color: _gold, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              _statRow('AMMO', '${stats.ammoCapacity}'),
              _statRow('FIRE RATE', stats.fireRate.toStringAsFixed(3)),
              _statRow('MOBS/SHOT', '${stats.mobsPerShot}'),
              _statRow('BASE HP BONUS', '+${stats.playerHealthBonus}'),
              const SizedBox(height: 10),
              if (!unlocked)
                _actionButton(
                  label: 'BUY  ${def.unlockCost}',
                  color: _green,
                  enabled: profile.currency >= def.unlockCost,
                  onTap: () => setState(() {
                    profile.currency -= def.unlockCost;
                    profile.unlockedCannonIds.add(def.id);
                    _persist();
                  }),
                )
              else if (nextLevel != null)
                _actionButton(
                  label: 'UPGRADE  ${nextLevel.unlockCost}',
                  color: _green,
                  enabled: profile.currency >= nextLevel.unlockCost,
                  onTap: () => setState(() {
                    profile.currency -= nextLevel.unlockCost;
                    profile.setCannonLevel(def.id, level + 1);
                    _persist();
                  }),
                )
              else
                const Text('MAX LEVEL', style: TextStyle(color: Colors.white38)),
            ],
          ),
        );
      },
    );
  }

  // --- Abilities ---------------------------------------------------------------

  Widget _buildAbilities(PlayerProfile profile, ContentCatalog content) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: content.abilities.length,
      itemBuilder: (context, i) {
        final def = content.abilities[i];
        final unlocked = profile.isAbilityUnlocked(def.id) || def.unlockCost == 0;
        final level = profile.getAbilityLevel(def.id);
        final tuning = def.tuningAtLevel(level);
        final nextLevel = def.levels.length > level ? def.levels[level] : null;

        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(def.displayName,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  Text('LV ${level + 1}/${def.levels.length + 1}',
                      style: const TextStyle(color: _gold, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              _statRow('CHARGES', '${tuning.charges}'),
              _statRow('RADIUS', tuning.radius.toStringAsFixed(1)),
              if (tuning.mobDamage > 0) _statRow('MOB DAMAGE', tuning.mobDamage.toStringAsFixed(0)),
              if (tuning.castleDamage > 0) _statRow('CASTLE DAMAGE', '${tuning.castleDamage}'),
              const SizedBox(height: 10),
              if (!unlocked)
                _actionButton(
                  label: 'BUY  ${def.unlockCost}',
                  color: _green,
                  enabled: profile.currency >= def.unlockCost,
                  onTap: () => setState(() {
                    profile.currency -= def.unlockCost;
                    profile.unlockedAbilityIds.add(def.id);
                    _persist();
                  }),
                )
              else if (nextLevel != null)
                _actionButton(
                  label: 'UPGRADE  ${nextLevel.unlockCost}',
                  color: _green,
                  enabled: profile.currency >= nextLevel.unlockCost,
                  onTap: () => setState(() {
                    profile.currency -= nextLevel.unlockCost;
                    profile.setAbilityLevel(def.id, level + 1);
                    _persist();
                  }),
                )
              else
                const Text('MAX LEVEL', style: TextStyle(color: Colors.white38)),
            ],
          ),
        );
      },
    );
  }

  // --- Shared helpers ----------------------------------------------------------

  Widget _card({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _slate),
      ),
      child: child,
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF8CA3CC), fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
