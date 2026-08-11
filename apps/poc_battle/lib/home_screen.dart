import 'package:flutter/material.dart';
import 'package:mobrush_save/mobrush_save.dart';

import 'campaign_map_screen.dart';
import 'main.dart' show Stage1Screen;
import 'profile_service.dart';

/// Port of `HomeMenu.cs` (708 lines of hand-anchored `RectTransform` code) —
/// same five bands top to bottom (header, title, campaign hero, BATTLE CTA,
/// bottom nav), same vertical rhythm, but as ordinary Flutter layout instead
/// of normalized-rect math. `SafeArea` replaces `SafeAreaFitter`; `Column` +
/// `Expanded` flex weights replace `SetNormalizedRect`'s five hand-tuned
/// bands (kept proportional to the same numbers: header 55, title 62, hero
/// 572, play 97, nav 118, out of ~1000 — see `HomeMenu`'s `NavTop`/`PlayTop`/
/// `HeroTop`/`TitleTop`/`HeaderTop` constants this mirrors).
///
/// Real persistence: `profile` is loaded from `SharedPreferences` through
/// `ProfileService` (the Flutter equivalent of `LocalJsonSaveStore.cs`) on
/// first build, and saved back after every round (see `Stage1Screen`'s
/// `_handleOutcome`, which computes the reward with the same
/// `RewardCalculator`/`StarRating` the live game uses).
///
/// Real art: `CastleHero.png`, `LogoWordmark.png`, and the header/nav icon
/// set are copied straight from `Assets/Resources/Home/` — the same
/// approved assets `HomeMenu.BuildCastleArt`/`BuildTitle` load in the live
/// game, not placeholders. Reusing an already-approved project asset is
/// the fal.ai policy's first priority, ahead of generating anything new.
///
/// Not yet done: Settings modal, secret-code panel, and How To Play are a
/// single placeholder dialog, not ported from `HomeMenu.cs`. SHOP tab is a
/// stub — it needs a real character/cannon/ability catalog exported from
/// Unity (`ContentExporter.cs`'s `content.json`) before it can show
/// anything but fabricated numbers.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ProfileService _service = ProfileService();
  PlayerProfile? _profile;

  /// Non-null accessor for the widgets below, which only ever get built
  /// once `build()` has confirmed `_profile` finished loading.
  PlayerProfile get profile => _profile!;

  @override
  void initState() {
    super.initState();
    _service.load().then((p) {
      if (mounted) setState(() => _profile = p);
    });
  }

  static const _bgNavy = Color(0xFF000B20);
  static const _titleBlue = Color(0xFF73C7FF);
  static const _gold = Color(0xFFFFD133);
  static const _playGold = Color(0xFFFFA815);
  static const _chipDark = Color(0xF0061229);
  static const _cardDark = Color(0xF2051129);
  static const _headerBorder = Color(0xFF112F5E);
  static const _navActive = Color(0xFF0859E6);
  static const _navBorder = Color(0xFF0B2450);

  int get _totalStages => 3; // Stage 1-3 content authored so far.
  int get _completedStages =>
      profile.stageStars.where((e) => e.stars > 0).length;

  @override
  Widget build(BuildContext context) {
    if (_profile == null) {
      return const Scaffold(
        backgroundColor: _bgNavy,
        body: Center(child: CircularProgressIndicator(color: _titleBlue)),
      );
    }
    return Scaffold(
      backgroundColor: _bgNavy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Expanded(flex: 55, child: _buildHeader()),
              const SizedBox(height: 6),
              Expanded(flex: 62, child: _buildTitle()),
              Expanded(flex: 572, child: _buildCampaignHero()),
              Expanded(flex: 97, child: _buildPlayButton()),
              const SizedBox(height: 8),
              Expanded(flex: 118, child: _buildBottomNav()),
            ],
          ),
        ),
      ),
    );
  }

  // --- Header: player card, currency chips, settings ----------------------

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          flex: 50,
          child: _framedPanel(
            color: _chipDark,
            border: _headerBorder,
            child: Row(
              children: [
                const SizedBox(width: 6),
                _assetIcon('assets/home/icons/icon_helmet.png'),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'COMMANDER',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D59D1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _headerBorder),
                  ),
                  child: Text('LV ${profile.playerLevel}',
                      style: const TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(flex: 20, child: _currencyChip(profile.currency.toString(), 'assets/home/icons/icon_coin.png')),
        const SizedBox(width: 6),
        Expanded(flex: 20, child: _currencyChip(profile.gems.toString(), 'assets/home/icons/icon_gem.png')),
        const SizedBox(width: 6),
        Expanded(
          flex: 14,
          child: _framedPanel(
            color: const Color(0xFF091933),
            border: _headerBorder,
            onTap: _showSettings,
            child: Center(child: Image.asset('assets/home/icons/icon_gear.png', width: 26, height: 26)),
          ),
        ),
      ],
    );
  }

  Widget _currencyChip(String value, String iconAsset) {
    return _framedPanel(
      color: _chipDark,
      border: _headerBorder,
      child: Row(
        children: [
          const SizedBox(width: 8),
          Image.asset(iconAsset, width: 20, height: 20),
          const SizedBox(width: 6),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  // --- Title ----------------------------------------------------------------

  Widget _buildTitle() {
    return Center(
      child: Image.asset('assets/home/LogoWordmark.png', fit: BoxFit.contain),
    );
  }

  // --- Campaign hero: castle art + progression -----------------------------

  Widget _buildCampaignHero() {
    final currentStage = (_completedStages + 1).clamp(1, _totalStages);
    final currentStageStars = profile.getStageStars('stage_$currentStage');
    return Container(
      decoration: BoxDecoration(
        color: _cardDark,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/home/CastleHero.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('STAGE $currentStage / $_totalStages',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              3,
              (i) => Icon(
                Icons.star,
                size: 18,
                color: i < currentStageStars ? _gold : Colors.white24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Primary CTA ------------------------------------------------------------

  Widget _buildPlayButton() {
    return SizedBox.expand(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _playGold,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _startBattle,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/home/icons/icon_battle_cta.png', width: 30, height: 30),
            const SizedBox(width: 10),
            const Text('BATTLE',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  // --- Bottom nav -------------------------------------------------------------

  Widget _buildBottomNav() {
    final items = [
      (_NavTab.home, 'assets/home/icons/icon_home.png', 'HOME'),
      (_NavTab.battle, 'assets/home/icons/icon_battle.png', 'BATTLE'),
      (_NavTab.shop, 'assets/home/icons/icon_shop.png', 'SHOP'),
      (_NavTab.map, 'assets/home/icons/icon_map.png', 'MAP'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFC03080D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _navBorder, width: 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Row(
        children: items.map((item) {
          final active = item.$1 == _NavTab.home;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onNavTap(item.$1),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: active ? _navActive : const Color(0xFB061430),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: active ? const Color(0xFF1A73F2) : _navBorder,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(item.$2, width: 26, height: 26),
                    const SizedBox(height: 2),
                    Text(item.$3,
                        style: TextStyle(
                          fontSize: 10,
                          color: active ? Colors.white : const Color(0xFF8CA3CC),
                        )),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _onNavTap(_NavTab tab) {
    switch (tab) {
      case _NavTab.home:
        break;
      case _NavTab.battle:
        _startBattle();
      case _NavTab.map:
        _openMap();
      case _NavTab.shop:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shop not built yet — Phase 5 follow-up.')),
        );
    }
  }

  Future<void> _openMap() async {
    final result = await Navigator.of(context).push<PlayerProfile>(
      MaterialPageRoute(
        builder: (_) => CampaignMapScreen(profile: profile, profileService: _service),
      ),
    );
    if (result != null && mounted) setState(() => _profile = result);
  }

  Future<void> _startBattle() async {
    final result = await Navigator.of(context).push<PlayerProfile>(
      MaterialPageRoute(
        builder: (_) => Stage1Screen(profile: profile, profileService: _service),
      ),
    );
    if (result != null && mounted) setState(() => _profile = result);
  }

  void _showSettings() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1523),
        title: const Text('SETTINGS', style: TextStyle(color: _titleBlue)),
        content: const Text(
          'Sound toggle, How to Play, and secret code entry are not ported '
          'from HomeMenu.cs yet.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _framedPanel({
    required Color color,
    required Color border,
    required Widget child,
    VoidCallback? onTap,
  }) {
    final panel = Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 2),
      ),
      child: child,
    );
    if (onTap == null) return panel;
    return GestureDetector(onTap: onTap, child: panel);
  }

  Widget _assetIcon(String asset) {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(color: Color(0xFF0B2B64), shape: BoxShape.circle),
      padding: const EdgeInsets.all(6),
      child: Image.asset(asset),
    );
  }
}

enum _NavTab { home, battle, shop, map }
