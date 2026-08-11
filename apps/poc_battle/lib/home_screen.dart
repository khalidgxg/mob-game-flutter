import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:mobrush_save/mobrush_save.dart';

import 'campaign_map_screen.dart';
import 'main.dart' show Stage1Screen;
import 'profile_service.dart';
import 'sfx.dart';
import 'shop_screen.dart';
import 'ui_theme.dart';

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
/// Chrome comes from `ui_theme.dart`, shared with Shop and the battle HUD
/// so the three screens cannot drift into looking like three apps.
///
/// Not yet done: the settings modal is a single placeholder dialog —
/// `HomeMenu.cs`'s sound toggle, How To Play, and secret-code panel aren't
/// ported.
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
    Sfx.instance.init().then((_) => Sfx.instance.setMenuMusic());
  }

  // Local aliases onto the shared palette, kept so the layout code below
  // reads the same as it did before the theme was extracted.
  static const _bgCore = MobRushTheme.bgCore;
  static const _bgNavy = MobRushTheme.bgNavy;
  static const _bgDeep = MobRushTheme.bgDeep;
  static const _titleBlue = MobRushTheme.blueLight;
  static const _gold = MobRushTheme.gold;
  static const _goldBright = MobRushTheme.goldBright;
  static const _goldDeep = MobRushTheme.goldDeep;
  static const _goldEdge = MobRushTheme.goldEdge;
  static const _plusGreen = MobRushTheme.green;

  /// Translucent blue glass, brighter at the top — the fill every framed
  /// panel in the reference uses.
  static const _glassFill = MobRushTheme.glassFill;

  /// The same glass, lit from within — used by the active nav tab.
  static const _glassActive = MobRushTheme.glassActive;

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
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.05),
            radius: 1.0,
            colors: [_bgCore, _bgNavy, _bgDeep],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: CustomPaint(
          // Light rays fanning out from behind the castle — the reference's
          // backdrop is not a plain gradient, and without these the screen
          // reads flat no matter how good the chrome is.
          painter: _RayPainter(),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  Expanded(flex: 60, child: _buildHeader()),
                  const SizedBox(height: 6),
                  Expanded(flex: 118, child: _buildTitle()),
                  Expanded(flex: 520, child: _buildCampaignHero()),
                  Expanded(flex: 104, child: _buildPlayButton()),
                  const SizedBox(height: 10),
                  Expanded(flex: 118, child: _buildBottomNav()),
                  const SizedBox(height: 4),
                ],
              ),
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
              gradient: const RadialGradient(
                colors: [Color(0xFF14418C), Color(0xFF061431)],
              ),
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
                    color: const Color(0x66041028),
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

  /// The reference's signature chrome, and the thing whose absence made the
  /// first pass read as a wireframe: translucent blue glass over the
  /// backdrop, a bright hairline catching light along the top edge, a warm
  /// gold rim, and a soft drop shadow lifting it off the page.
  Widget _goldFrame({
    required Widget child,
    VoidCallback? onTap,
    double radius = 12,
    Gradient gradient = _glassFill,
    List<BoxShadow> glow = const [],
  }) {
    final panel = Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _goldEdge, width: 2),
        boxShadow: [
          const BoxShadow(color: Color(0x59000814), blurRadius: 10, offset: Offset(0, 3)),
          ...glow,
        ],
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
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.all(4),
        // Outer navy glass rail, exactly as the reference frames its CTA —
        // the gold slab is inset inside it, not floating bare on the page.
        decoration: BoxDecoration(
          gradient: _glassFill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _goldEdge, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x59FFA415), blurRadius: 24, spreadRadius: 1),
            BoxShadow(color: Color(0x59000814), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_goldBright, _gold, _goldDeep],
              stops: [0.0, 0.42, 1.0],
            ),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFFFF0B0), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: Image.asset('assets/home/icons/icon_battle_cta.png'),
              ),
              const SizedBox(width: 14),
              const Text(
                'BATTLE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                  shadows: [
                    Shadow(blurRadius: 3, offset: Offset(0, 1.5), color: Color(0xB38A4A00)),
                  ],
                ),
              ),
            ],
          ),
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
      radius: 14,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          children: items.map((item) {
            final active = item.$1 == _NavTab.home;
            return Expanded(
              child: GestureDetector(
                onTap: () => _onNavTap(item.$1),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    // The selected tab carries its own light: a lit glass
                    // gradient, a gold rim, and a blue halo spilling onto the
                    // bar around it. That halo is the single clearest "this is
                    // selected" cue in the reference.
                    gradient: active ? _glassActive : _glassFill,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active ? _gold : const Color(0x33FFFFFF),
                      width: active ? 2 : 1,
                    ),
                    boxShadow: active
                        ? const [
                            BoxShadow(color: Color(0x8C2E86F5), blurRadius: 16, spreadRadius: 1),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: Opacity(
                          opacity: active ? 1 : 0.72,
                          child: Image.asset(item.$2),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.$3,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                          color: active ? Colors.white : const Color(0xFF8FA8D4),
                          shadows: active
                              ? const [Shadow(blurRadius: 4, color: Color(0xAA00204D))]
                              : null,
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
    Sfx.instance.play('click');
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
    // Back on Home, the bed goes back to the menu theme — the C# does the
    // same through `Sfx.SetMenuMusic` on its own Home transition.
    Sfx.instance.setMenuMusic();
  }

  void _showSettings() {
    Sfx.instance.play('click');
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0D1523),
          title: const Text('SETTINGS',
              style: TextStyle(color: _titleBlue, fontWeight: FontWeight.w900)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Port of `HomeMenu.ToggleSound`. Muting stops the beds rather
              // than zeroing them, so a muted app isn't still decoding audio.
              GameButton(
                label: Sfx.instance.muted ? 'SOUND : OFF' : 'SOUND : ON',
                gradient: Sfx.instance.muted
                    ? MobRushTheme.glassFill
                    : MobRushTheme.greenFill,
                icon: Sfx.instance.muted ? Icons.volume_off : Icons.volume_up,
                fontSize: 14,
                onTap: () async {
                  await Sfx.instance.setMuted(!Sfx.instance.muted);
                  if (!Sfx.instance.muted) await Sfx.instance.setMenuMusic();
                  setDialogState(() {});
                },
              ),
              const SizedBox(height: 14),
              const Text(
                'How to Play and secret code entry are not ported from '
                'HomeMenu.cs yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('CLOSE'),
            ),
          ],
        ),
      ),
    );
  }

}

enum _NavTab { home, battle, shop, map }

/// Soft light rays fanning out from behind the castle, as in the reference
/// backdrop. Drawn rather than baked so they cost no texture memory and
/// scale to any screen: each ray is a thin triangle from a point above the
/// castle, faded out along its length.
class _RayPainter extends CustomPainter {
  static const _rayCount = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.30);
    final length = size.height * 0.75;

    for (var i = 0; i < _rayCount; i++) {
      final angle = (i / _rayCount) * 2 * math.pi + 0.12;
      // Alternating widths keep the fan from looking mechanical.
      final halfSpread = i.isEven ? 0.030 : 0.017;
      final path = Path()
        ..moveTo(origin.dx, origin.dy)
        ..lineTo(
          origin.dx + math.cos(angle - halfSpread) * length,
          origin.dy + math.sin(angle - halfSpread) * length,
        )
        ..lineTo(
          origin.dx + math.cos(angle + halfSpread) * length,
          origin.dy + math.sin(angle + halfSpread) * length,
        )
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.radial(
            origin,
            length,
            const [Color(0x009CC8FF), Color(0x1A8FC0FF), Color(0x00000000)],
            const [0.0, 0.28, 0.9],
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RayPainter oldDelegate) => false;
}
