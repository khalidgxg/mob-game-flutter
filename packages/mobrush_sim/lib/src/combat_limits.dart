/// Hard limits the combat simulation imposes on authored stats.
///
/// Direct port of `Assets/Scripts/Data/CombatLimits.cs`. The values are the
/// contract between authored content and the engine, so they are reproduced
/// exactly rather than re-derived — a limit that drifts between the two
/// implementations is a stat the shop advertises and the battle ignores.
class CombatLimits {
  CombatLimits._();

  /// The furthest a mob can notice an enemy, in world units.
  ///
  /// Also the per-mob search budget: the scanned neighbourhood grows with the
  /// square of the range, so raising it is a performance decision.
  static const double maxSeekRange = 6.0;

  /// Centre-to-centre distance at which two opposing units of ordinary size
  /// lock into melee.
  static const double baseClashRadius = 0.40;

  /// How much further apart than the clash distance two units must drift
  /// before the duel is released.
  static const double disengageFactor = 1.6;

  /// Melee distance for one specific pair, widened by however much larger than
  /// an ordinary unit each of them is. A flat radius is a hidden size limit.
  static double clashDistance(
    double baseRadius,
    double bodySurplusA,
    double bodySurplusB,
  ) {
    final surplus =
        (bodySurplusA > 0 ? bodySurplusA : 0.0) +
        (bodySurplusB > 0 ? bodySurplusB : 0.0);
    return (baseRadius > 0 ? baseRadius : baseClashRadius) + surplus;
  }
}
