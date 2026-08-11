import 'package:flutter/material.dart';
import 'package:mobrush_save/mobrush_save.dart';

import 'main.dart' show Stage1Screen;

/// Port of `HomeMenu.cs` (708 lines of hand-anchored `RectTransform` code) —
/// same five bands top to bottom (header, title, campaign hero, BATTLE CTA,
/// bottom nav), same vertical rhythm, but as ordinary Flutter layout instead
/// of normalized-rect math. `SafeArea` replaces `SafeAreaFitter`; `Column` +
/// `Expanded` flex weights replace `SetNormalizedRect`'s five hand-tuned
/// bands (kept proportional to the same numbers: header 55, title 62, hero
/// 572, play 97, nav 118, out of ~1000 — see `HomeMenu`'s `NavTop`/`PlayTop`/
/// `HeroTop`/`TitleTop`/`HeaderTop` constants this mirrors).
///
/// Not yet done: no real persistence — the profile here is a fresh
/// in-memory `PlayerProfile`, not loaded from device storage the way
/// `ProfileService` does in the live game. Settings modal, secret-code
/// panel, and How To Play are also not ported yet; SHOP and MAP tabs are
/// stubs. Home's own generated art (castle hero, wordmark, icon set) isn't
/// baked yet either — this reuses Stage 1's real castle PNG and Material
/// icons as the honest placeholder, the same "geometric fallback" spirit
/// `HomeMenu.BuildCastleArt` uses when `Resources/Home/CastleHero` is
/// missing.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PlayerProfile _profile = PlayerProfile();

  static const _bgNavy = Color(0xFF000B20);
  static const _titleBlue = Color(0xFF73C7FF);
  static const _gold = Color(0xFFFFD133);
  static const _diamond = Color(0xFF59C7FF);
  static const _playGold = Color(0xFFFFA815);
  static const _chipDark = Color(0xF0061229);
  static const _cardDark = Color(0xF2051129);
  static const _headerBorder = Color(0xFF112F5E);
  static const _navActive = Color(0xFF0859E6);
  static const _navBorder = Color(0xFF0B2450);

  int get _totalStages => 3; // Stage 1-3 content authored so far.
  int get _completedStages =>
      _profile.stageStars.where((e) => e.stars > 0).length;

  @override
  Widget build(BuildContext context) {
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
                _squareIcon(Icons.shield, const Color(0xFF33AAFF), const Color(0xFF0B2B64)),
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
                  child: Text('LV ${_profile.playerLevel}',
                      style: const TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(flex: 20, child: _currencyChip(_profile.currency.toString(), _gold, Icons.circle)),
        const SizedBox(width: 6),
        Expanded(flex: 20, child: _currencyChip(_profile.gems.toString(), _diamond, Icons.diamond)),
        const SizedBox(width: 6),
        Expanded(
          flex: 14,
          child: _framedPanel(
            color: const Color(0xFF091933),
            border: _headerBorder,
            onTap: _showSettings,
            child: const Center(child: Icon(Icons.settings, color: Colors.white, size: 22)),
          ),
        ),
      ],
    );
  }

  Widget _currencyChip(String value, Color accent, IconData icon) {
    return _framedPanel(
      color: _chipDark,
      border: _headerBorder,
      child: Row(
        children: [
          const SizedBox(width: 8),
          Icon(icon, color: accent, size: 18),
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
    return const Center(
      child: Text.rich(
        TextSpan(children: [
          TextSpan(text: 'MOB ', style: TextStyle(color: Colors.white)),
          TextSpan(text: 'RUSH', style: TextStyle(color: _titleBlue)),
        ]),
        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 1),
      ),
    );
  }

  // --- Campaign hero: castle art + progression -----------------------------

  Widget _buildCampaignHero() {
    final currentStage = (_completedStages + 1).clamp(1, _totalStages);
    final currentStageStars = _profile.getStageStars('stage_$currentStage');
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
                'assets/structures/stage1/castle_main.png',
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
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.gps_fixed, color: Colors.white, size: 28),
            SizedBox(width: 10),
            Text('BATTLE',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  // --- Bottom nav -------------------------------------------------------------

  Widget _buildBottomNav() {
    final items = [
      (_NavTab.home, Icons.home, 'HOME'),
      (_NavTab.battle, Icons.gps_fixed, 'BATTLE'),
      (_NavTab.shop, Icons.storefront, 'SHOP'),
      (_NavTab.map, Icons.map, 'MAP'),
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
                    Icon(item.$2, color: active ? Colors.white : const Color(0xFF8CA3CC), size: 24),
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
      case _NavTab.shop:
      case _NavTab.map:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not built yet — Phase 5 follow-up.')),
        );
    }
  }

  void _startBattle() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const Stage1Screen()),
    );
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

  Widget _squareIcon(IconData icon, Color fg, Color bg) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, color: fg, size: 20),
    );
  }
}

enum _NavTab { home, battle, shop, map }
