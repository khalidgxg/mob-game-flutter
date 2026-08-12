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

/// Port of `HomeMenu.cs`, redone against the approved Claude Design mock
/// `MobRush Home.dc.html` (project bde0666b-61ed-49bc-8857-571e1b7271ca).
/// That file is a 540×960 absolute-position canvas; every `Positioned`
/// below is that canvas's own px numbers converted to a fraction of the
/// real screen, so the composition matches at any aspect ratio instead of
/// only at 540×960. Colours, gradients, and border widths are copied
/// verbatim from the mock's inline styles.
///
/// Art (`avatar/castle-scene/coin/gear/gem/logo/nav-*.png`) is the mock's
/// own asset set, extracted from its project bundle — real approved art,
/// not placeholders. `castle-scene.png` was re-encoded PNG→JPEG (opaque,
/// no alpha channel) to cut it from 1.7MB to ~220KB; nothing else was
/// altered.
///
/// Real persistence: `profile` loads from `SharedPreferences` through
/// `ProfileService` on first build and saves back after every round.
/// Chrome (`_goldFrame`) still comes from `ui_theme.dart`, shared with Shop
/// and the battle HUD.
///
/// Not ported from the mock: the BATTLE-tab mode list, the SHOP-tab pack
/// grid, and the matchmaking search modal are demo-data prototypes with no
/// real game system behind them yet — this app's own `ShopScreen` and
/// `Stage1Screen` (real content, real currency, a real battle) stay the
/// nav targets instead of being replaced by non-functional mockups. The
/// settings sheet is ported as a single placeholder row (see
/// `_showSettings`) — Sound already works for real via `Sfx`.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ProfileService _service = ProfileService();
  PlayerProfile? _profile;

  /// Non-null accessor for the widgets below, which only ever get built
  /// once `build()` has confirmed `_profile` finished loading.
  PlayerProfile get profile => _profile!;

  late final AnimationController _floatCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _sweepCtrl;
  late final AnimationController _sparkCtrl;

  @override
  void initState() {
    super.initState();
    _service.load().then((p) {
      if (mounted) setState(() => _profile = p);
    });
    Sfx.instance.init().then((_) => Sfx.instance.setMenuMusic());

    // Mirrors the mock's mrFloat/mrGlow/mrSweep/mrPulse/mrSpark keyframes.
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();
    _sweepCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 4500))..repeat();
    _sparkCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 5000))..repeat();
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    _pulseCtrl.dispose();
    _sweepCtrl.dispose();
    _sparkCtrl.dispose();
    super.dispose();
  }

  static const _bgDeep = Color(0xFF010A1E);
  static const _gold = MobRushTheme.gold;
  static const _titleBlue = MobRushTheme.blueLight;
  static const _plusGreen = Color(0xFF12A437);
  static const _chipBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0E2E63), Color(0xFF071B40)],
  );
  static const _chipBorder = Color(0xFF17458D);

  int get _totalStages => 3; // Stage 1-3 content authored so far.
  int get _completedStages =>
      profile.stageStars.where((e) => e.stars > 0).length;

  @override
  Widget build(BuildContext context) {
    if (_profile == null) {
      return const Scaffold(
        backgroundColor: _bgDeep,
        body: Center(child: CircularProgressIndicator(color: _titleBlue)),
      );
    }
    return Scaffold(
      backgroundColor: _bgDeep,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          // Fractions of the mock's own 540×960 canvas.
          double px(double v) => v / 540 * w;
          double py(double v) => v / 960 * h;

          return Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 1.15,
                colors: [Color(0xFF15498F), Color(0xFF0A2B64), Color(0xFF04163A), Color(0xFF010A1E)],
                stops: [0.0, 0.32, 0.62, 1.0],
              ),
            ),
            child: Stack(
              children: [
                const Positioned.fill(child: CustomPaint(painter: _RayPainter(center: 0.44))),
                ..._sparks(w, h),

                // Castle scene, top-and-bottom feathered like the mock's mask.
                Positioned(
                  left: 0,
                  right: 0,
                  top: py(196),
                  height: py(552),
                  child: ShaderMask(
                    shaderCallback: (rect) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent, Colors.white, Colors.white, Colors.transparent,
                      ],
                      stops: [0.0, 0.07, 0.88, 1.0],
                    ).createShader(rect),
                    blendMode: BlendMode.dstIn,
                    child: Image.asset('assets/home/design/castle-scene.jpg', fit: BoxFit.cover),
                  ),
                ),

                // Floating, glowing logo — over the castle, per the mock's
                // z-order (drawn after the castle image).
                Positioned(
                  left: w / 2,
                  top: py(88),
                  width: px(412),
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, 0),
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_floatCtrl]),
                      builder: (context, child) {
                        final t = _floatCtrl.value * 2 * math.pi;
                        final dy = -math.sin(t) * 7;
                        final glow = 0.5 + 0.5 * math.sin(t * (4.5 / 6));
                        return Transform.translate(
                          offset: Offset(0, dy),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Color.lerp(
                                    const Color(0x40709BFF),
                                    const Color(0x7378BEFF),
                                    glow,
                                  )!,
                                  blurRadius: 18 + glow * 16,
                                ),
                              ],
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: Image.asset('assets/home/design/logo.png'),
                    ),
                  ),
                ),

                // HUD row: player card, coins, gems, settings.
                Positioned(
                  left: px(14),
                  right: px(14),
                  top: py(16),
                  height: py(60),
                  child: _hudRow(px),
                ),

                // BATTLE CTA.
                Positioned(
                  left: w / 2,
                  bottom: py(150),
                  width: px(376),
                  height: py(94),
                  child: FractionalTranslation(
                    translation: const Offset(-0.5, 0),
                    child: _battleButton(),
                  ),
                ),

                // Tab bar.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: py(118),
                  child: _tabBar(px, py),
                ),

                // Stage/star readout, tucked between the castle and the CTA
                // — the mock has no progression readout on Home (it lives
                // on the Map tab there), but this app's stars/stage state
                // is real save data with nowhere else on Home to surface.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: py(150) + py(94) + py(10),
                  child: _stageReadout(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _sparks(double w, double h) {
    const specs = [
      (64 / 540, 300 / 960, Color(0xFFFFD88A), 4.2, 0.0),
      (452 / 540, 392 / 960, Color(0xFF8FD0FF), 5.6, 0.8),
      (498 / 540, 640 / 960, Color(0xFFFFD88A), 6.4, 1.6),
    ];
    return [
      for (final s in specs)
        Positioned(
          left: s.$1 * w,
          top: s.$2 * h,
          child: AnimatedBuilder(
            animation: _sparkCtrl,
            builder: (context, _) {
              final period = s.$4;
              final phase = s.$5;
              final t = ((_sparkCtrl.value * 5.0 + phase) % period) / period;
              final wave = math.sin(t * math.pi);
              return Opacity(
                opacity: 0.15 + 0.75 * wave.clamp(0, 1),
                child: Transform.translate(
                  offset: Offset(0, -14 * wave),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(color: s.$3, shape: BoxShape.circle),
                  ),
                ),
              );
            },
          ),
        ),
    ];
  }

  Widget _hudRow(double Function(double) px) {
    return Row(
      children: [
        SizedBox(width: px(196), child: _playerCard()),
        SizedBox(width: px(9)),
        Expanded(child: _currencyChip(profile.currency.toString(), 'assets/home/design/coin.png')),
        SizedBox(width: px(9)),
        Expanded(child: _currencyChip(profile.gems.toString(), 'assets/home/design/gem.png')),
        SizedBox(width: px(9)),
        SizedBox(width: px(60), child: _gearButton()),
      ],
    );
  }

  Widget _chipShell({required Widget child, VoidCallback? onTap}) {
    final panel = Container(
      decoration: BoxDecoration(
        gradient: _chipBg,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _chipBorder, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x00000000), blurRadius: 0), // placeholder for inset (below)
          BoxShadow(color: Color(0x73000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Stack(
        children: [
          // Inset top highlight, matching the mock's `inset 0 2px 0`.
          Positioned(
            left: 0, right: 0, top: 0,
            child: Container(height: 2, color: const Color(0x47829BFF)),
          ),
          child,
        ],
      ),
    );
    return onTap == null ? panel : GestureDetector(onTap: onTap, child: panel);
  }

  Widget _playerCard() {
    return _chipShell(
      child: Row(
        children: [
          const SizedBox(width: 5),
          Container(
            width: 50,
            height: 50,
            margin: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _gold, width: 2),
              boxShadow: const [BoxShadow(color: Color(0x73FFBE3C), blurRadius: 14)],
              image: const DecorationImage(
                image: AssetImage('assets/home/design/avatar.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'COMMANDER',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFFEAF3FF),
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.5,
                    shadows: [Shadow(blurRadius: 0, offset: Offset(0, 2), color: Color(0x80000000))],
                  ),
                ),
                const SizedBox(height: 4),
                // Blue fill bar with "LV n" centred over it — the mock's
                // progress-bar-shaped level readout, not a flat pill.
                Container(
                  height: 19,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFF04122F),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: const Color(0xFF1B4C99), width: 1),
                  ),
                  child: Stack(
                    children: [
                      FractionallySizedBox(
                        widthFactor: 0.38,
                        heightFactor: 1,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF2F8BFF), Color(0xFF0E46C9)],
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          'LV ${profile.playerLevel}',
                          style: const TextStyle(
                            color: Color(0xFFFFD863),
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _currencyChip(String value, String iconAsset) {
    return _chipShell(
      onTap: _openShop,
      child: Row(
        children: [
          const SizedBox(width: 6),
          SizedBox(width: 30, height: 30, child: Image.asset(iconAsset)),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ),
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF4FE06E), _plusGreen],
              ),
              border: Border.all(color: const Color(0xFF0A7A2A), width: 1.5),
            ),
            child: const Icon(Icons.add, size: 14, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _gearButton() {
    return _chipShell(
      onTap: _showSettings,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Image.asset('assets/home/design/gear.png'),
        ),
      ),
    );
  }

  Widget _stageReadout() {
    final currentStage = (_completedStages + 1).clamp(1, _totalStages);
    final stars = profile.getStageStars('stage_$currentStage');
    return Column(
      children: [
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
            (i) => Icon(Icons.star, size: 16, color: i < stars ? _gold : Colors.white24),
          ),
        ),
      ],
    );
  }

  /// Beveled gold slab in a navy glass frame, octagon-cut corners, a
  /// diagonal light sweep, and a pulsing amber glow — the mock's
  /// `mrPulse`/`mrSweep` keyframes on its BATTLE button.
  Widget _battleButton() {
    return GestureDetector(
      onTap: _startBattle,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, child) {
          final glow = 0.5 + 0.5 * math.sin(_pulseCtrl.value * 2 * math.pi);
          return Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF12356F), Color(0xFF050F2A)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: const Color(0xFF000000).withValues(alpha: 0.55), blurRadius: 28),
                BoxShadow(
                  color: Color.lerp(
                    const Color(0x4DFFB020),
                    const Color(0x8CFFB020),
                    glow,
                  )!,
                  blurRadius: 34 + glow * 24,
                ),
              ],
            ),
            child: child,
          );
        },
        // `LayoutBuilder` has to wrap the `Stack` itself, not sit between
        // the `Stack` and a `Positioned` child — `Positioned` requires a
        // direct `Stack` parent, and `LayoutBuilder` is a real render
        // object, so nesting it *inside* the `Stack`'s children breaks
        // that and silently drops the subtree in release mode.
        child: LayoutBuilder(
          builder: (context, c) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFE873), Color(0xFFFFC62F), Color(0xFFF39A0D), Color(0xFFD97B04),
                        ],
                        stops: [0.0, 0.4, 0.64, 1.0],
                      ),
                    ),
                  ),
                  // Diagonal sweep.
                  AnimatedBuilder(
                    animation: _sweepCtrl,
                    builder: (context, _) {
                      final x = -c.maxWidth * 1.6 + _sweepCtrl.value * c.maxWidth * 4.8;
                      return Positioned(
                        top: 0, bottom: 0, left: x, width: c.maxWidth * 0.22,
                        child: Transform(
                          transform: Matrix4.skewX(-0.32),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0),
                                  Colors.white.withValues(alpha: 0.55),
                                  Colors.white.withValues(alpha: 0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 44, height: 52, child: Image.asset('assets/home/design/bolt.png')),
                      const SizedBox(width: 14),
                      const Text(
                        'BATTLE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          shadows: [
                            Shadow(blurRadius: 0, offset: Offset(0, 3), color: Color(0x8C7E3C00)),
                            Shadow(blurRadius: 16, color: Color(0x59000000)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _tabBar(double Function(double) px, double Function(double) py) {
    final items = [
      (_NavTab.home, 'assets/home/design/nav-home.png', 'HOME'),
      (_NavTab.battle, 'assets/home/design/nav-battle.png', 'BATTLE'),
      (_NavTab.shop, 'assets/home/design/nav-shop.png', 'SHOP'),
      (_NavTab.map, 'assets/home/design/nav-map.png', 'MAP'),
    ];
    return Container(
      padding: EdgeInsets.fromLTRB(px(12), py(8), px(12), py(22)),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF07193A), Color(0xFF020C22)],
        ),
        border: Border(top: BorderSide(color: Color(0xFF0E3269), width: 2)),
      ),
      child: Row(
        children: items.map((item) {
          final active = item.$1 == _NavTab.home;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: px(4)),
              child: GestureDetector(
                onTap: () => _onNavTap(item.$1),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: active
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF3D97FF), Color(0xFF0B47D8)],
                          )
                        : null,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: active ? const Color(0xFF8ECBFF) : Colors.transparent, width: 2),
                    boxShadow: active
                        ? const [BoxShadow(color: Color(0x8C3C8CFF), blurRadius: 22)]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 34, height: 34, child: Image.asset(item.$2)),
                      const SizedBox(height: 4),
                      Text(
                        item.$3,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: active ? Colors.white : const Color(0xFF7F9DD0),
                          shadows: const [Shadow(blurRadius: 0, offset: Offset(0, 2), color: Color(0x80000000))],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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
    Sfx.instance.play('click');
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
    Sfx.instance.play('battleClick');
    Sfx.instance.setBattleMusic();
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

/// Conic light rays fanning out behind the castle, masked to a radial
/// falloff — the mock's `repeating-conic-gradient` + mask-image backdrop.
class _RayPainter extends CustomPainter {
  const _RayPainter({required this.center});

  /// Vertical centre of the ray origin, as a fraction of the canvas height
  /// (the mock's radial-gradient centre is `50% 44%`).
  final double center;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * center);
    final radius = size.longestSide * 0.85;

    canvas.saveLayer(Offset.zero & size, Paint());

    const rayCount = 82; // 360° / 2.2° pitch from the mock's conic-gradient
    const rayWidthDeg = 2.2 * math.pi / 180;
    const gapDeg = 10 * math.pi / 180 - rayWidthDeg;
    final paint = Paint()..color = const Color(0x13A0CDFF);
    for (var i = 0; i < rayCount; i++) {
      final start = i * (rayWidthDeg + gapDeg);
      final path = Path()
        ..moveTo(origin.dx, origin.dy)
        ..arcTo(Rect.fromCircle(center: origin, radius: radius), start, rayWidthDeg, false)
        ..close();
      canvas.drawPath(path, paint);
    }

    // Radial falloff mask (closest-side, 18%→52%→82% per the mock).
    final maskPaint = Paint()
      ..blendMode = BlendMode.dstIn
      ..shader = ui.Gradient.radial(
        origin,
        size.shortestSide * 0.6,
        const [Colors.black, Color(0x73000000), Color(0x00000000)],
        const [0.18, 0.52, 0.82],
      );
    canvas.drawRect(Offset.zero & size, maskPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RayPainter oldDelegate) => false;
}
