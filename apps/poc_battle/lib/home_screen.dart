import 'package:flutter/material.dart';
import 'package:mobrush_save/mobrush_save.dart';

import 'campaign_map_screen.dart';
import 'main.dart' show Stage1Screen;
import 'profile_service.dart';
import 'shop_screen.dart';

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

  // Palette read off the approved Home reference: a deep navy ground with a
  // cool radial glow behind the castle, gold-edged chrome on every frame,
  // and one saturated gold CTA. Gold borders are the reference's single
  // strongest signature -- the earlier version's flat blue-grey outlines are
  // what made it read as a wireframe rather than the finished screen.
  static const _bgNavy = Color(0xFF061638);
  static const _bgDeep = Color(0xFF020B1F);
  static const _glow = Color(0xFF12346E);
  static const _titleBlue = Color(0xFF73C7FF);
  static const _gold = Color(0xFFFFC53D);
  static const _goldBright = Color(0xFFFFE071);
  static const _goldDeep = Color(0xFFE08A00);
  static const _goldEdge = Color(0xFFC98A16);
  static const _chipDark = Color(0xFF0A1E45);
  static const _chipDarker = Color(0xFF06122C);
  static const _navActive = Color(0xFF1668DE);
  static const _navIdle = Color(0xFF0B1F44);
  static const _plusGreen = Color(0xFF2FBF4A);

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
      backgroundColor: _bgDeep,
      body: Container(
        // The reference's backdrop is a single cool glow centred behind the
        // castle, fading to near-black at the corners -- not a flat fill.
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.15),
            radius: 1.05,
            colors: [_glow, _bgNavy, _bgDeep],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              children: [
                const SizedBox(height: 6),
                Expanded(flex: 58, child: _buildHeader()),
                const SizedBox(height: 4),
                Expanded(flex: 96, child: _buildTitle()),
                Expanded(flex: 540, child: _buildCampaignHero()),
                Expanded(flex: 104, child: _buildPlayButton()),
                const SizedBox(height: 8),
                Expanded(flex: 116, child: _buildBottomNav()),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Header: player card, currency chips, settings ----------------------

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(flex: 44, child: _playerCard()),
        const SizedBox(width: 6),
        Expanded(
          flex: 23,
          child: _currencyChip(profile.currency.toString(), 'assets/home/icons/icon_coin.png'),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 23,
          child: _currencyChip(profile.gems.toString(), 'assets/home/icons/icon_gem.png'),
        ),
        const SizedBox(width: 6),
        Expanded(
          flex: 13,
          child: _goldFrame(
            onTap: _showSettings,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Image.asset('assets/home/icons/icon_gear.png'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Portrait in a gold ring, name stacked over a LV pill — the reference's
  /// layout, not the single flat row the first pass used.
  Widget _playerCard() {
    return _goldFrame(
      child: Row(
        children: [
          const SizedBox(width: 5),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _chipDarker,
              border: Border.all(color: _gold, width: 2),
            ),
            padding: const EdgeInsets.all(4),
            child: Image.asset('assets/home/icons/icon_helmet.png'),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'COMMANDER',
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                  decoration: BoxDecoration(
                    color: _chipDarker,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: _goldEdge, width: 1),
                  ),
                  child: Text(
                    'LV ${profile.playerLevel}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _currencyChip(String value, String iconAsset) {
    return _goldFrame(
      child: Row(
        children: [
          const SizedBox(width: 5),
          SizedBox(width: 22, height: 22, child: Image.asset(iconAsset)),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
          // The reference puts a green "+" affordance on every currency chip.
          Container(
            width: 18,
            height: 18,
            margin: const EdgeInsets.only(right: 5),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: _plusGreen),
            child: const Icon(Icons.add, size: 13, color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// The reference's signature chrome: a rounded navy panel with a gold
  /// outline and a subtle inner top-light, used by every header element and
  /// the nav bar.
  Widget _goldFrame({required Widget child, VoidCallback? onTap}) {
    final panel = Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_chipDark, _chipDarker],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _goldEdge, width: 1.6),
      ),
      child: child,
    );
    return onTap == null ? panel : GestureDetector(onTap: onTap, child: panel);
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
    // No card frame here: in the reference the castle sits directly on the
    // background glow, which is what gives the screen its depth. Boxing it
    // in a panel (the first pass) flattened the whole composition.
    return Column(
      children: [
        Expanded(
          child: Image.asset('assets/home/CastleHero.png', fit: BoxFit.contain),
        ),
        const SizedBox(height: 2),
        Text(
          'STAGE $currentStage / $_totalStages',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 0.6,
            shadows: [Shadow(blurRadius: 6, color: Colors.black87)],
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            3,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Icon(
                Icons.star,
                size: 17,
                color: i < currentStageStars ? _gold : Colors.white24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Primary CTA ------------------------------------------------------------

  /// The reference's BATTLE button is a beveled gold slab: bright top edge,
  /// deep amber bottom, a lighter inner face, and a warm glow beneath it.
  Widget _buildPlayButton() {
    return GestureDetector(
      onTap: _startBattle,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_goldBright, _gold, _goldDeep],
            stops: [0.0, 0.45, 1.0],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _goldBright, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x66FFA415), blurRadius: 18, spreadRadius: 1),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: Image.asset('assets/home/icons/icon_battle_cta.png'),
            ),
            const SizedBox(width: 12),
            const Text(
              'BATTLE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                shadows: [Shadow(blurRadius: 4, color: Color(0x997A4400))],
              ),
            ),
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
    return _goldFrame(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: items.map((item) {
            final active = item.$1 == _NavTab.home;
            return Expanded(
              child: GestureDetector(
                onTap: () => _onNavTap(item.$1),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    gradient: active
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF2E8CFF), _navActive],
                          )
                        : null,
                    color: active ? null : _navIdle,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: active ? _gold : Colors.transparent,
                      width: 1.6,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 30, height: 30, child: Image.asset(item.$2)),
                      const SizedBox(height: 2),
                      Text(
                        item.$3,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                          color: active ? Colors.white : const Color(0xFF7E96C4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
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
        _openShop();
    }
  }

  Future<void> _openShop() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ShopScreen()),
    );
    // Currency can change in the shop; reload so Home's chip stays honest.
    final result = await _service.load();
    if (mounted) setState(() => _profile = result);
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

}

enum _NavTab { home, battle, shop, map }
