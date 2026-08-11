import 'package:flutter/material.dart';
import 'package:mobrush_data/mobrush_data.dart';
import 'package:mobrush_save/mobrush_save.dart';

import 'game_content.dart';
import 'profile_service.dart';
import 'sfx.dart';
import 'ui_theme.dart';

/// Port of `ShopScreen` + its Characters/Abilities/Cannons partials
/// (1,478 lines total in `Assets/Scripts/Presentation/`) — three tabbed
/// lists instead of three separate hand-built scroll rects, reading real
/// stats from the exported `content.json` (see `game_content.dart`).
///
/// Buying is only half of a shop: what is *equipped* is what the battle
/// reads. `EQUIP` writes `characterRoster`/`selectedCannonId` on the
/// profile, which `Stage1Game` resolves into the round's cannon stats,
/// deployed character, and per-character purchased levels. Upgrades bought
/// here therefore change what actually walks onto the lane.
///
/// Not ported: character portrait art (Unity's are 3D renders, not baked to
/// sprites the way the crowd atlas was) and the 1-to-4 multi-slot roster —
/// this equips one primary character, which is what `Stage1Game` reads.
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

  void _mutate(void Function(PlayerProfile p) change) {
    Sfx.instance.play('battleClick');
    setState(() => change(_profile!));
    _service.save(_profile!);
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final content = _content;
    return Scaffold(
      backgroundColor: MobRushTheme.bgDeep,
      body: Container(
        decoration: const BoxDecoration(gradient: MobRushTheme.pageGradient),
        child: SafeArea(
          child: profile == null || content == null
              ? const Center(child: CircularProgressIndicator(color: MobRushTheme.blueLight))
              : Column(
                  children: [
                    _topBar(profile),
                    _tabs(),
                    Expanded(
                      child: switch (_tab) {
                        _ShopTab.heroes => _heroes(profile, content),
                        _ShopTab.cannons => _cannons(profile, content),
                        _ShopTab.abilities => _abilities(profile, content),
                      },
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _topBar(PlayerProfile profile) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Row(
        children: [
          GlassPanel(
            onTap: () => Navigator.of(context).pop(),
            radius: 10,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: const Text('< BACK',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
          ),
          const Expanded(
            child: Text(
              'SHOP',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: 1.2,
                shadows: [Shadow(blurRadius: 6, color: Color(0xAA00214D))],
              ),
            ),
          ),
          GlassPanel(
            radius: 10,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/home/icons/icon_coin.png', width: 18, height: 18),
                const SizedBox(width: 6),
                Text('${profile.currency}',
                    style: const TextStyle(
                        color: MobRushTheme.gold, fontWeight: FontWeight.w900, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabs() {
    Widget tab(_ShopTab t, String label) {
      final active = _tab == t;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: GlassPanel(
            onTap: () {
              Sfx.instance.play('click');
              setState(() => _tab = t);
            },
            active: active,
            radius: 20,
            rimColor: active ? MobRushTheme.gold : const Color(0x33FFFFFF),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? Colors.white : MobRushTheme.textDim,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(7, 8, 7, 10),
      child: Row(
        children: [
          tab(_ShopTab.heroes, 'HEROES'),
          tab(_ShopTab.cannons, 'CANNONS'),
          tab(_ShopTab.abilities, 'SKILLS'),
        ],
      ),
    );
  }

  // --- Heroes ---------------------------------------------------------------

  Widget _heroes(PlayerProfile profile, ContentCatalog content) {
    final roster = content.characters
        .where((c) => c.role == CharacterRole.playerRoster)
        .toList();
    final equippedId =
        profile.characterRoster.isNotEmpty ? profile.characterRoster.first : 'base';

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
      itemCount: roster.length,
      itemBuilder: (context, i) {
        final def = roster[i];
        final owned = def.unlockCost == 0 || profile.isCharacterUnlocked(def.id);
        final level = profile.getCharacterLevel(def.id);
        final stats = def.statsAtLevel(level);
        final next = def.levels.length > level ? def.levels[level] : null;
        final equipped = owned && def.id == equippedId;

        return _card(
          equipped: equipped,
          title: def.displayName,
          level: level,
          maxLevel: def.levels.length,
          badge: equipped ? 'IN TEAM' : null,
          stats: [
            ('HP', stats.hp.toStringAsFixed(0)),
            ('ATK', stats.atk.toStringAsFixed(1)),
            ('DEF', stats.def.toStringAsFixed(1)),
            ('SPD', stats.speed.toStringAsFixed(1)),
          ],
          actions: [
            if (!owned)
              _buy(def.unlockCost, profile, () {
                profile.currency -= def.unlockCost;
                profile.unlockedCharacterIds.add(def.id);
              })
            else if (!equipped)
              GameButton(
                label: 'EQUIP',
                gradient: MobRushTheme.glassActive,
                glowColor: const Color(0x662E86F5),
                fontSize: 13,
                onTap: () => _mutate((p) => p.characterRoster
                  ..clear()
                  ..add(def.id)),
              ),
            if (owned && next != null)
              _upgrade(next.unlockCost, profile, () {
                profile.currency -= next.unlockCost;
                profile.setCharacterLevel(def.id, level + 1);
              })
            else if (owned)
              const _MaxLabel(),
          ],
        );
      },
    );
  }

  // --- Cannons --------------------------------------------------------------

  Widget _cannons(PlayerProfile profile, ContentCatalog content) {
    // An empty selectedCannonId means "the default Standard Cannon", the
    // same fallback Stage1Game applies when resolving the loadout.
    final equippedId =
        profile.selectedCannonId.isEmpty ? 'cannon' : profile.selectedCannonId;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
      itemCount: content.cannons.length,
      itemBuilder: (context, i) {
        final def = content.cannons[i];
        final owned = def.unlockCost == 0 || profile.isCannonUnlocked(def.id);
        final level = profile.getCannonLevel(def.id);
        final stats = def.statsAtLevel(level);
        final next = def.levels.length > level ? def.levels[level] : null;
        final equipped = owned && def.id == equippedId;

        return _card(
          equipped: equipped,
          title: def.displayName,
          level: level,
          maxLevel: def.levels.length,
          badge: equipped ? 'EQUIPPED' : null,
          stats: [
            ('AMMO', '${stats.ammoCapacity}'),
            ('FIRE RATE', stats.fireRate.toStringAsFixed(3)),
            ('MOBS/SHOT', '${stats.mobsPerShot}'),
            ('RUSH', '${stats.rushUnitCount}'),
            ('BASE HP', '+${stats.playerHealthBonus}'),
          ],
          actions: [
            if (!owned)
              _buy(def.unlockCost, profile, () {
                profile.currency -= def.unlockCost;
                profile.unlockedCannonIds.add(def.id);
              })
            else if (!equipped)
              GameButton(
                label: 'EQUIP',
                gradient: MobRushTheme.glassActive,
                glowColor: const Color(0x662E86F5),
                fontSize: 13,
                onTap: () => _mutate((p) => p.selectedCannonId = def.id),
              ),
            if (owned && next != null)
              _upgrade(next.unlockCost, profile, () {
                profile.currency -= next.unlockCost;
                profile.setCannonLevel(def.id, level + 1);
              })
            else if (owned)
              const _MaxLabel(),
          ],
        );
      },
    );
  }

  // --- Abilities ------------------------------------------------------------

  Widget _abilities(PlayerProfile profile, ContentCatalog content) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
      itemCount: content.abilities.length,
      itemBuilder: (context, i) {
        final def = content.abilities[i];
        final owned = def.unlockCost == 0 || profile.isAbilityUnlocked(def.id);
        final level = profile.getAbilityLevel(def.id);
        final t = def.tuningAtLevel(level);
        final next = def.levels.length > level ? def.levels[level] : null;

        return _card(
          equipped: false,
          title: def.displayName,
          level: level,
          maxLevel: def.levels.length,
          stats: [
            ('CHARGES', '${t.charges}'),
            ('RADIUS', t.radius.toStringAsFixed(1)),
            if (t.duration > 0) ('DURATION', '${t.duration.toStringAsFixed(1)}s'),
            if (t.mobDamage > 0) ('MOB DMG', t.mobDamage.toStringAsFixed(0)),
            if (t.castleDamage > 0) ('CASTLE DMG', '${t.castleDamage}'),
          ],
          actions: [
            if (!owned)
              _buy(def.unlockCost, profile, () {
                profile.currency -= def.unlockCost;
                profile.unlockedAbilityIds.add(def.id);
              })
            else if (next != null)
              _upgrade(next.unlockCost, profile, () {
                profile.currency -= next.unlockCost;
                profile.setAbilityLevel(def.id, level + 1);
              })
            else
              const _MaxLabel(),
          ],
        );
      },
    );
  }

  // --- Shared ---------------------------------------------------------------

  Widget _buy(int cost, PlayerProfile profile, void Function() apply) {
    return GameButton(
      label: 'BUY  $cost',
      gradient: MobRushTheme.greenFill,
      glowColor: const Color(0x5929B85F),
      iconAsset: 'assets/home/icons/icon_coin.png',
      fontSize: 13,
      enabled: profile.currency >= cost,
      onTap: () => _mutate((_) => apply()),
    );
  }

  Widget _upgrade(int cost, PlayerProfile profile, void Function() apply) {
    return GameButton(
      label: 'UPGRADE  $cost',
      gradient: MobRushTheme.goldFill,
      iconAsset: 'assets/home/icons/icon_coin.png',
      fontSize: 13,
      enabled: profile.currency >= cost,
      onTap: () => _mutate((_) => apply()),
    );
  }

  Widget _card({
    required bool equipped,
    required String title,
    required int level,
    required int maxLevel,
    required List<(String, String)> stats,
    required List<Widget> actions,
    String? badge,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassPanel(
        active: equipped,
        radius: 14,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(blurRadius: 4, color: Color(0xAA00214D))],
                    ),
                  ),
                ),
                if (badge != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: MobRushTheme.goldFill,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(badge,
                        style: const TextStyle(
                            color: Color(0xFF2A1800), fontSize: 9, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 8),
                ],
                Text('LV ${level + 1}/${maxLevel + 1}',
                    style: const TextStyle(
                        color: MobRushTheme.gold, fontWeight: FontWeight.w900, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 10),
            ...stats.map((s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                  child: Row(
                    children: [
                      Text(s.$1,
                          style: const TextStyle(color: MobRushTheme.textDim, fontSize: 12)),
                      const Spacer(),
                      Text(s.$2,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                )),
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: actions[i]),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MaxLabel extends StatelessWidget {
  const _MaxLabel();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Text('MAX LEVEL',
            style: TextStyle(color: MobRushTheme.textDim, fontWeight: FontWeight.w900, fontSize: 12)),
      ),
    );
  }
}
