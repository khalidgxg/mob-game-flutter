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

/// Flutter-native reconstruction of the approved MobRush Home composition.
///
/// The screen uses normal widgets for every interactive element and
/// [CustomPainter] for the scalable theatrical backdrop, side banners,
/// torches, stone dais, CTA frame, and navigation chrome. The only raster
/// assets are the approved logo, castle, and icon artwork.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _designWidth = 388.0;
  static const _designHeight = 689.0;
  static const _designAspect = _designWidth / _designHeight;

  final ProfileService _service = ProfileService();
  PlayerProfile? _profile;

  PlayerProfile get profile => _profile!;

  @override
  void initState() {
    super.initState();
    _service.load().then((loaded) {
      if (mounted) setState(() => _profile = loaded);
    });
    Sfx.instance.init().then((_) => Sfx.instance.setMenuMusic());
  }

  @override
  Widget build(BuildContext context) {
    if (_profile == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: MobRushTheme.blueLight),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min(
            constraints.maxWidth,
            constraints.maxHeight * _designAspect,
          );
          final height = width / _designAspect;
          return Center(
            child: SizedBox(
              width: width,
              height: height,
              child: FittedBox(
                fit: BoxFit.fill,
                child: SizedBox(
                  width: _designWidth,
                  height: _designHeight,
                  child: _buildBoard(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBoard() {
    return ClipRect(
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _HomeBackdropPainter()),
          ),
          const Positioned.fill(
            child: CustomPaint(painter: _HeroStagePainter()),
          ),
          Positioned.fromRect(
            rect: const Rect.fromLTWH(8, 12, 146, 58),
            child: _playerPanel(),
          ),
          Positioned.fromRect(
            rect: const Rect.fromLTWH(161, 16, 93, 50),
            child: _currencyPanel(
              profile.currency.toString(),
              'assets/home/icons/icon_coin.png',
            ),
          ),
          Positioned.fromRect(
            rect: const Rect.fromLTWH(258, 16, 79, 50),
            child: _currencyPanel(
              profile.gems.toString(),
              'assets/home/icons/icon_gem.png',
            ),
          ),
          Positioned.fromRect(
            rect: const Rect.fromLTWH(341, 16, 39, 50),
            child: _gearPanel(),
          ),
          Positioned.fromRect(
            rect: const Rect.fromLTWH(34, 68, 320, 96),
            child: Transform.scale(
              scaleX: 1.08,
              child: Image.asset(
                'assets/home/LogoWordmark.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          Positioned.fromRect(
            rect: const Rect.fromLTWH(52, 150, 284, 378),
            child: Transform.scale(
              scaleX: 1.08,
              alignment: Alignment.bottomCenter,
              child: Image.asset(
                'assets/home/CastleHero.png',
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          Positioned.fromRect(
            rect: const Rect.fromLTWH(42, 514, 304, 84),
            child: _BattleButton(onTap: _startBattle),
          ),
          Positioned.fromRect(
            rect: const Rect.fromLTWH(8, 600, 372, 81),
            child: _BottomNav(
              onHome: () => Sfx.instance.play('click'),
              onBattle: _startBattle,
              onShop: _openShop,
              onMap: _openMap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerPanel() {
    return _HudPanel(
      child: Row(
        children: [
          const SizedBox(width: 5),
          Container(
            width: 47,
            height: 47,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFF1C67D5), Color(0xFF06163B)],
              ),
              border: Border.all(color: const Color(0xFFFFC438), width: 2.2),
              boxShadow: const [
                BoxShadow(color: Color(0xAA008CFF), blurRadius: 7),
              ],
            ),
            padding: const EdgeInsets.all(5),
            child: Image.asset('assets/home/icons/icon_helmet.png'),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'COMMANDER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.35,
                      shadows: [Shadow(color: Colors.black, blurRadius: 3)],
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  height: 15,
                  constraints: const BoxConstraints(minWidth: 39),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF20A5FF), Color(0xFF075AE2)],
                    ),
                    borderRadius: BorderRadius.circular(2),
                    border:
                        Border.all(color: const Color(0xFF63D6FF), width: 0.8),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'LV ${profile.playerLevel}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _currencyPanel(String value, String iconAsset) {
    return _HudPanel(
      radius: 8,
      child: Row(
        children: [
          const SizedBox(width: 5),
          SizedBox(width: 27, height: 27, child: Image.asset(iconAsset)),
          const SizedBox(width: 3),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Colors.black, blurRadius: 3)],
                ),
              ),
            ),
          ),
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF68E784), Color(0xFF13A83F)],
              ),
              border: Border.all(color: const Color(0xFF93FFAA), width: 0.8),
            ),
            child: const Icon(Icons.add, size: 12, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _gearPanel() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _showSettings,
      child: _HudPanel(
        radius: 8,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Image.asset('assets/home/icons/icon_gear.png'),
        ),
      ),
    );
  }

  Future<void> _openShop() async {
    Sfx.instance.play('click');
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ShopScreen()),
    );
    final result = await _service.load();
    if (mounted) setState(() => _profile = result);
  }

  Future<void> _openMap() async {
    Sfx.instance.play('click');
    final result = await Navigator.of(context).push<PlayerProfile>(
      MaterialPageRoute(
        builder: (_) => CampaignMapScreen(
          profile: profile,
          profileService: _service,
        ),
      ),
    );
    if (result != null && mounted) setState(() => _profile = result);
  }

  Future<void> _startBattle() async {
    Sfx.instance.play('click');
    final result = await Navigator.of(context).push<PlayerProfile>(
      MaterialPageRoute(
        builder: (_) => Stage1Screen(
          profile: profile,
          profileService: _service,
        ),
      ),
    );
    if (result != null && mounted) setState(() => _profile = result);
    Sfx.instance.setMenuMusic();
  }

  void _showSettings() {
    Sfx.instance.play('click');
    showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF07152F),
          title: const Text(
            'SETTINGS',
            style: TextStyle(
              color: MobRushTheme.blueLight,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                'How to Play and secret code entry are not ported yet.',
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

class _HudPanel extends StatelessWidget {
  const _HudPanel({required this.child, this.radius = 10});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0D4A97), Color(0xFF061D4E), Color(0xFF020D28)],
          stops: [0.0, 0.16, 1.0],
        ),
        border: Border.all(color: const Color(0xFF168CFF), width: 1.4),
        boxShadow: const [
          BoxShadow(color: Color(0x99006CFF), blurRadius: 8, spreadRadius: 0.5),
          BoxShadow(color: Colors.black87, blurRadius: 5, offset: Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius - 2),
          border: Border.all(color: const Color(0xFFD89D27), width: 0.9),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xE6123977), Color(0xF2051539)],
          ),
        ),
        child: child,
      ),
    );
  }
}

class _BattleButton extends StatelessWidget {
  const _BattleButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Battle',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const CustomPaint(painter: _BattleButtonPainter()),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 42,
                  height: 42,
                  child: Image.asset('assets/home/icons/icon_battle_cta.png'),
                ),
                const SizedBox(width: 8),
                const Text(
                  'BATTLE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 31,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    shadows: [
                      Shadow(
                          color: Color(0xFF6D2D00),
                          blurRadius: 1,
                          offset: Offset(0, 2)),
                      Shadow(
                          color: Colors.black54,
                          blurRadius: 5,
                          offset: Offset(0, 3)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.onHome,
    required this.onBattle,
    required this.onShop,
    required this.onMap,
  });

  final VoidCallback onHome;
  final VoidCallback onBattle;
  final VoidCallback onShop;
  final VoidCallback onMap;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _BottomNavPainter(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 5),
        child: Row(
          children: [
            _NavItem(
              active: true,
              icon: 'assets/home/icons/icon_home.png',
              label: 'HOME',
              onTap: onHome,
            ),
            _NavItem(
              icon: 'assets/home/icons/icon_battle.png',
              label: 'BATTLE',
              onTap: onBattle,
            ),
            _NavItem(
              icon: 'assets/home/icons/icon_shop.png',
              label: 'SHOP',
              onTap: onShop,
            ),
            _NavItem(
              icon: 'assets/home/icons/icon_map.png',
              label: 'MAP',
              onTap: onMap,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: active
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF159FFF),
                        Color(0xFF075FF0),
                        Color(0xFF013599)
                      ],
                    ),
                    border:
                        Border.all(color: const Color(0xFF6CD8FF), width: 1.4),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0xCC007DFF),
                          blurRadius: 9,
                          spreadRadius: 1),
                    ],
                  )
                : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: active ? 36 : 32,
                  height: active ? 36 : 32,
                  child: Image.asset(icon),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  style: TextStyle(
                    color: active ? Colors.white : const Color(0xFFCBD9F7),
                    fontSize: 8.5,
                    height: 1,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.35,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeBackdropPainter extends CustomPainter {
  const _HomeBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width / 2, 0),
          Offset(size.width / 2, size.height),
          const [Color(0xFF06132E), Color(0xFF05275D), Color(0xFF010817)],
          const [0.0, 0.48, 1.0],
        ),
    );

    final origin = Offset(size.width / 2, size.height * 0.22);
    for (var i = 0; i < 16; i++) {
      final angle = -math.pi * 0.96 + i * (math.pi * 1.92 / 15);
      final spread = i.isEven ? 0.055 : 0.032;
      final length = size.height * 0.92;
      final ray = Path()
        ..moveTo(origin.dx, origin.dy)
        ..lineTo(
          origin.dx + math.cos(angle - spread) * length,
          origin.dy + math.sin(angle - spread) * length,
        )
        ..lineTo(
          origin.dx + math.cos(angle + spread) * length,
          origin.dy + math.sin(angle + spread) * length,
        )
        ..close();
      canvas.drawPath(
        ray,
        Paint()
          ..shader = ui.Gradient.radial(
            origin,
            length,
            const [Color(0x2449A9FF), Color(0x0D2E83D3), Color(0x00001133)],
            const [0.0, 0.45, 1.0],
          ),
      );
    }

    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width / 2, size.height * 0.47),
          size.width * 0.78,
          const [Color(0x001B66C2), Color(0x15000A1C), Color(0xB800020A)],
          const [0.0, 0.63, 1.0],
        ),
    );

    const sparks = <Offset>[
      Offset(28, 181),
      Offset(48, 224),
      Offset(360, 188),
      Offset(344, 238),
      Offset(21, 496),
      Offset(371, 505),
      Offset(61, 329),
      Offset(326, 314),
      Offset(92, 189),
      Offset(302, 206),
      Offset(44, 547),
      Offset(350, 554),
    ];
    for (var i = 0; i < sparks.length; i++) {
      final radius = i.isEven ? 1.3 : 0.8;
      canvas.drawCircle(
        sparks[i],
        radius,
        Paint()
          ..color =
              i.isEven ? const Color(0xFFFFB52C) : const Color(0xFF4BA8FF),
      );
    }

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF071A38),
    );
  }

  @override
  bool shouldRepaint(covariant _HomeBackdropPainter oldDelegate) => false;
}

class _HeroStagePainter extends CustomPainter {
  const _HeroStagePainter();

  @override
  void paint(Canvas canvas, Size size) {
    _drawCastleGlow(canvas);
    _drawPlatform(canvas);
    _drawBanner(canvas, 31);
    _drawBanner(canvas, size.width - 31, mirrored: true);
    _drawTorch(canvas, 35);
    _drawTorch(canvas, size.width - 35);
  }

  void _drawCastleGlow(Canvas canvas) {
    const center = Offset(194, 403);
    canvas.drawCircle(
      center,
      164,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          164,
          const [Color(0x4D168DFF), Color(0x1C0965D8), Color(0x00051A46)],
          const [0.0, 0.56, 1.0],
        ),
    );
  }

  void _drawPlatform(Canvas canvas) {
    const glowRect = Rect.fromLTWH(22, 451, 344, 103);
    canvas.drawOval(
      glowRect.inflate(10),
      Paint()
        ..shader = ui.Gradient.radial(
          glowRect.center,
          190,
          const [Color(0x66007FFF), Color(0x22004A9E), Color(0x00001635)],
          const [0.0, 0.62, 1.0],
        ),
    );
    canvas.drawOval(
      glowRect,
      Paint()
        ..shader = ui.Gradient.linear(
          glowRect.topCenter,
          glowRect.bottomCenter,
          const [Color(0xFF31558A), Color(0xFF0B1B38), Color(0xFF020817)],
          const [0.0, 0.42, 1.0],
        ),
    );
    canvas.drawOval(
      glowRect.deflate(7),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF152B4E),
    );
    canvas.drawArc(
      glowRect.deflate(3),
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0xFF4A77A9),
    );
    for (var i = 0; i < 11; i++) {
      final angle = math.pi + (i / 10) * math.pi;
      final outer = Offset(
        glowRect.center.dx + math.cos(angle) * glowRect.width / 2,
        glowRect.center.dy + math.sin(angle) * glowRect.height / 2,
      );
      final inner = Offset(
        glowRect.center.dx + math.cos(angle) * (glowRect.width / 2 - 20),
        glowRect.center.dy + math.sin(angle) * (glowRect.height / 2 - 7),
      );
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..strokeWidth = 1.2
          ..color = const Color(0xFF07101F),
      );
    }
  }

  void _drawBanner(Canvas canvas, double poleX, {bool mirrored = false}) {
    const top = 238.0;
    const bottom = 425.0;
    final polePaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(poleX - 2, 0),
        Offset(poleX + 2, 0),
        const [Color(0xFF6D3500), Color(0xFFFFD34A), Color(0xFF8B4700)],
        const [0.0, 0.5, 1.0],
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(poleX - 2.2, top, 4.4, bottom - top),
        const Radius.circular(2),
      ),
      polePaint,
    );
    canvas.drawCircle(Offset(poleX, top - 5), 5, polePaint);
    final crossStart = mirrored ? poleX - 30 : poleX - 4;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(crossStart, top + 7, 34, 4),
        const Radius.circular(2),
      ),
      polePaint,
    );
    canvas.drawCircle(
        Offset(mirrored ? poleX - 31 : poleX + 31, top + 9), 3.2, polePaint);

    final left = mirrored ? poleX - 29 : poleX + 4;
    final right = mirrored ? poleX - 4 : poleX + 29;
    final cloth = Path()
      ..moveTo(left, top + 13)
      ..lineTo(right, top + 13)
      ..lineTo(right, bottom - 18)
      ..lineTo((left + right) / 2, bottom)
      ..lineTo(left, bottom - 18)
      ..close();
    final clothRect = Rect.fromLTRB(
      math.min(left, right),
      top + 13,
      math.max(left, right),
      bottom,
    );
    canvas.drawPath(
      cloth,
      Paint()
        ..shader = ui.Gradient.linear(
          clothRect.topLeft,
          clothRect.topRight,
          const [Color(0xFF031742), Color(0xFF0C58BE), Color(0xFF031239)],
          const [0.0, 0.5, 1.0],
        ),
    );
    canvas.drawPath(
      cloth,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFD58C14),
    );
    canvas.drawLine(
      Offset(left + 3, top + 18),
      Offset(left + 3, bottom - 20),
      Paint()
        ..strokeWidth = 1
        ..color = const Color(0xFFFFC23B),
    );
    canvas.drawLine(
      Offset(right - 3, top + 18),
      Offset(right - 3, bottom - 20),
      Paint()
        ..strokeWidth = 1
        ..color = const Color(0xFFFFC23B),
    );

    const crownY = top + 83;
    final crown = Path()
      ..moveTo(clothRect.center.dx - 8, crownY + 7)
      ..lineTo(clothRect.center.dx - 9, crownY - 3)
      ..lineTo(clothRect.center.dx - 3, crownY + 1)
      ..lineTo(clothRect.center.dx, crownY - 7)
      ..lineTo(clothRect.center.dx + 3, crownY + 1)
      ..lineTo(clothRect.center.dx + 9, crownY - 3)
      ..lineTo(clothRect.center.dx + 8, crownY + 7)
      ..close();
    canvas.drawPath(crown, Paint()..color = const Color(0xFFFFB718));
  }

  void _drawTorch(Canvas canvas, double x) {
    const bowlY = 447.0;
    final glowCenter = Offset(x, bowlY - 13);
    canvas.drawCircle(
      glowCenter,
      34,
      Paint()
        ..shader = ui.Gradient.radial(
          glowCenter,
          34,
          const [Color(0xAAFFB000), Color(0x44FF6500), Color(0x00FF3B00)],
          const [0.0, 0.55, 1.0],
        ),
    );
    final stone = Paint()
      ..shader = ui.Gradient.linear(
        Offset(x - 16, 0),
        Offset(x + 16, 0),
        const [Color(0xFF030813), Color(0xFF31496B), Color(0xFF071020)],
        const [0.0, 0.48, 1.0],
      );
    final stoneEdge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF536B89);
    final foot = Path()
      ..moveTo(x - 17, 499)
      ..lineTo(x + 17, 499)
      ..lineTo(x + 14, 489)
      ..lineTo(x - 14, 489)
      ..close();
    canvas.drawPath(foot, stone);
    canvas.drawPath(foot, stoneEdge);
    final column = RRect.fromRectAndRadius(
      Rect.fromLTWH(x - 9, 459, 18, 31),
      const Radius.circular(2),
    );
    canvas.drawRRect(column, stone);
    canvas.drawRRect(column, stoneEdge);
    canvas.drawRect(Rect.fromLTWH(x - 13, 454, 26, 7), stone);
    canvas.drawRect(
      Rect.fromLTWH(x - 13, 454, 26, 7),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = const Color(0xFF6A7E98),
    );
    canvas.drawRect(
      Rect.fromLTWH(x - 8, 467, 16, 3),
      Paint()..color = const Color(0xFF0B1A31),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, bowlY + 4), width: 29, height: 10),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(x - 15, 0),
          Offset(x + 15, 0),
          const [Color(0xFF6E3100), Color(0xFFFFC02C), Color(0xFF6D2A00)],
          const [0.0, 0.5, 1.0],
        ),
    );
    final flame = Path()
      ..moveTo(x, bowlY)
      ..cubicTo(x - 15, bowlY - 9, x - 7, bowlY - 25, x + 1, bowlY - 34)
      ..cubicTo(x + 2, bowlY - 21, x + 14, bowlY - 20, x + 10, bowlY - 8)
      ..cubicTo(x + 7, bowlY - 2, x + 3, bowlY, x, bowlY)
      ..close();
    canvas.drawPath(flame, Paint()..color = const Color(0xFFFF7A00));
    final core = Path()
      ..moveTo(x, bowlY - 2)
      ..cubicTo(x - 7, bowlY - 10, x - 2, bowlY - 21, x + 2, bowlY - 26)
      ..cubicTo(x + 3, bowlY - 17, x + 8, bowlY - 12, x + 4, bowlY - 5)
      ..close();
    canvas.drawPath(core, Paint()..color = const Color(0xFFFFF2A1));
  }

  @override
  bool shouldRepaint(covariant _HeroStagePainter oldDelegate) => false;
}

class _BattleButtonPainter extends CustomPainter {
  const _BattleButtonPainter();

  Path _beveled(Rect rect, double cut) {
    return Path()
      ..moveTo(rect.left + cut, rect.top)
      ..lineTo(rect.right - cut, rect.top)
      ..lineTo(rect.right, rect.top + cut)
      ..lineTo(rect.right - cut * 0.45, rect.bottom - cut)
      ..lineTo(rect.right - cut * 1.35, rect.bottom)
      ..lineTo(rect.left + cut * 1.35, rect.bottom)
      ..lineTo(rect.left + cut * 0.45, rect.bottom - cut)
      ..lineTo(rect.left, rect.top + cut)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outer = _beveled(Offset.zero & size, 13);
    canvas.drawPath(
      outer,
      Paint()
        ..color = const Color(0x990074FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawPath(
      outer,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(0, size.height),
          const [Color(0xFF153F78), Color(0xFF031229), Color(0xFF071A3B)],
          const [0.0, 0.52, 1.0],
        ),
    );
    canvas.drawPath(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = const Color(0xFF0F75DE),
    );

    final middle =
        _beveled(Rect.fromLTWH(5, 4, size.width - 10, size.height - 8), 11);
    canvas.drawPath(middle, Paint()..color = const Color(0xFFFFB51E));
    canvas.drawPath(
      middle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = const Color(0xFFFFE16D),
    );

    final face =
        _beveled(Rect.fromLTWH(11, 10, size.width - 22, size.height - 20), 8);
    canvas.drawPath(
      face,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 10),
          Offset(0, size.height - 10),
          const [Color(0xFFFFD238), Color(0xFFFF9E00), Color(0xFFD95700)],
          const [0.0, 0.48, 1.0],
        ),
    );
    canvas.drawPath(
      face,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFFFFF2A7),
    );
    canvas.drawLine(
      const Offset(27, 13),
      Offset(size.width - 27, 13),
      Paint()
        ..strokeWidth = 1.3
        ..color = const Color(0xFFFFEE96),
    );
  }

  @override
  bool shouldRepaint(covariant _BattleButtonPainter oldDelegate) => false;
}

class _BottomNavPainter extends CustomPainter {
  const _BottomNavPainter();

  Path _frame(Size size) {
    return Path()
      ..moveTo(10, 0)
      ..lineTo(size.width - 10, 0)
      ..lineTo(size.width, 10)
      ..lineTo(size.width, size.height - 10)
      ..lineTo(size.width - 10, size.height)
      ..lineTo(10, size.height)
      ..lineTo(0, size.height - 10)
      ..lineTo(0, 10)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _frame(size);
    canvas.drawPath(
      path,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(size.width / 2, 0),
          Offset(size.width / 2, size.height),
          const [Color(0xFF103A72), Color(0xFF061933), Color(0xFF020A1B)],
          const [0.0, 0.28, 1.0],
        ),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF126DCA),
    );
    canvas.drawPath(
      _frame(Size(size.width - 4, size.height - 4)).shift(const Offset(2, 2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = const Color(0xFFB17B1D),
    );
    for (var i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(
        Offset(x, 8),
        Offset(x, size.height - 7),
        Paint()
          ..strokeWidth = 1
          ..color = const Color(0xFF123667),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BottomNavPainter oldDelegate) => false;
}
