import 'package:flutter/material.dart';

/// The one place the approved reference's visual language is written down.
///
/// Home, Shop and the battle HUD all draw the same chrome, and before this
/// existed each screen re-declared its own near-miss copy of these colours
/// and gradients — which is exactly how a UI drifts into looking like three
/// different apps. Anything that frames content should come from here.
class MobRushTheme {
  const MobRushTheme._();

  // Backdrop.
  static const bgCore = Color(0xFF17407E);
  static const bgNavy = Color(0xFF0A2251);
  static const bgDeep = Color(0xFF04102C);

  static const pageGradient = RadialGradient(
    center: Alignment(0, -0.05),
    radius: 1.0,
    colors: [bgCore, bgNavy, bgDeep],
    stops: [0.0, 0.5, 1.0],
  );

  // Accents.
  static const gold = Color(0xFFFFC53D);
  static const goldBright = Color(0xFFFFE071);
  static const goldDeep = Color(0xFFE08A00);
  static const goldEdge = Color(0xFFD9A22B);
  static const blueLight = Color(0xFF73C7FF);
  static const navActive = Color(0xFF2E86F5);
  static const navActiveDeep = Color(0xFF1560D0);
  static const green = Color(0xFF2FBF4A);
  static const greenDeep = Color(0xFF1E8C34);
  static const red = Color(0xFFFA3D38);
  static const textDim = Color(0xFF8FA8D4);

  /// Translucent blue glass, brighter at the top. The fill every framed
  /// panel in the reference uses — a solid fill is what makes a mockup read
  /// as a wireframe.
  static const glassFill = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x59FFFFFF), Color(0x4D3D82D6), Color(0x59071B3F), Color(0x73030D24)],
    stops: [0.0, 0.035, 0.55, 1.0],
  );

  /// The same glass, lit from within — for a selected/active element.
  static const glassActive = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x8CFFFFFF), Color(0xFF4E9BFF), navActive, navActiveDeep],
    stops: [0.0, 0.05, 0.5, 1.0],
  );

  static const goldFill = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [goldBright, gold, goldDeep],
    stops: [0.0, 0.42, 1.0],
  );

  static const greenFill = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF6FE08A), green, greenDeep],
    stops: [0.0, 0.42, 1.0],
  );

  static const dropShadow = BoxShadow(
    color: Color(0x59000814),
    blurRadius: 10,
    offset: Offset(0, 3),
  );

  static const selectionGlow = BoxShadow(
    color: Color(0x8C2E86F5),
    blurRadius: 16,
    spreadRadius: 1,
  );
}

/// A glass panel with a gold rim — the reference's universal container.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.onTap,
    this.radius = 12,
    this.active = false,
    this.padding,
    this.rimColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double radius;

  /// Lights the panel from within and gives it a halo, for "this one is
  /// selected/equipped".
  final bool active;
  final EdgeInsets? padding;
  final Color? rimColor;

  @override
  Widget build(BuildContext context) {
    final panel = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: active ? MobRushTheme.glassActive : MobRushTheme.glassFill,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: rimColor ?? (active ? MobRushTheme.gold : MobRushTheme.goldEdge),
          width: 2,
        ),
        boxShadow: [
          MobRushTheme.dropShadow,
          if (active) MobRushTheme.selectionGlow,
        ],
      ),
      child: child,
    );
    return onTap == null ? panel : GestureDetector(onTap: onTap, child: panel);
  }
}

/// A chunky game button: a coloured slab inset inside a glass rail, the way
/// the reference frames its BATTLE CTA. [enabled] false greys it out rather
/// than hiding it, so a player can still see what the action would cost.
class GameButton extends StatelessWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onTap,
    this.gradient = MobRushTheme.goldFill,
    this.icon,
    this.iconAsset,
    this.enabled = true,
    this.fontSize = 16,
    this.glowColor = const Color(0x59FFA415),
  });

  final String label;
  final VoidCallback onTap;
  final Gradient gradient;
  final IconData? icon;
  final String? iconAsset;
  final bool enabled;
  final double fontSize;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(3.5),
          decoration: BoxDecoration(
            gradient: MobRushTheme.glassFill,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: MobRushTheme.goldEdge, width: 2),
            boxShadow: [
              if (enabled) BoxShadow(color: glowColor, blurRadius: 20, spreadRadius: 1),
              MobRushTheme.dropShadow,
            ],
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0x99FFFFFF), width: 1.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (iconAsset != null) ...[
                  SizedBox(width: fontSize + 6, height: fontSize + 6, child: Image.asset(iconAsset!)),
                  const SizedBox(width: 8),
                ] else if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: fontSize + 4),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    shadows: const [
                      Shadow(blurRadius: 3, offset: Offset(0, 1.5), color: Color(0xB3002044)),
                    ],
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
