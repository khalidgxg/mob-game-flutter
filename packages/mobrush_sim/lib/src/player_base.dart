/// The player's home line. Port of the simulation core of
/// `Assets/Scripts/Gameplay/PlayerBase.cs` — health, the cannon's additive
/// bonus, and the engage-line test. The hit-flash material and the gizmo
/// preview are presentation and left out.
class PlayerBase {
  PlayerBase({
    required this.baseHealth,
    int cannonHealthBonus = 0,
    this.engageHalfWidth = 5.0,
    this.engageHalfDepth = 0.4,
    this.solidHalfDepth = 0.0,
    this.priorityRange = 6.0,
    required this.defenceLineZ,
    required this.defenceLineX,
  })  : maxHealth = baseHealth + (cannonHealthBonus < 0 ? 0 : cannonHealthBonus),
        currentHealth = baseHealth + (cannonHealthBonus < 0 ? 0 : cannonHealthBonus);

  final int baseHealth;
  final int maxHealth;
  int currentHealth;
  bool alive = true;

  final double engageHalfWidth;
  final double engageHalfDepth;

  /// Half-extent of the defended object's impassable body along the lane —
  /// the cannon's carriage depth in the live game, resolved externally.
  final double solidHalfDepth;

  /// How close in front of the defended object an enemy must get before the
  /// cannon outranks every mob near it — the distance that breaks the
  /// fire-distract-return stalemate the C# comment describes.
  final double priorityRange;

  final double defenceLineZ;
  final double defenceLineX;

  double get priorityLineZ =>
      defenceLineZ - solidHalfDepth - (priorityRange < 0 ? 0 : priorityRange);

  /// Port of `IsWithinDefenceLine`. The line sits in front of the defended
  /// object's own body, not on its centre — `bodyRadius` keeps a large unit's
  /// edge (not just its pivot) out of the carriage, the same fix the C#
  /// comment describes for a character as large as Max.
  bool isWithinDefenceLine(double x, double z, {double bodyRadius = 0.0}) {
    final radius = bodyRadius < 0 ? 0.0 : bodyRadius;
    return (x - defenceLineX).abs() < engageHalfWidth &&
        z >= defenceLineZ - solidHalfDepth - radius - engageHalfDepth;
  }

  /// Port of `TakeDamage`. Returns true the instant this call brings the base
  /// down, mirroring `OnBaseDestroyed()` firing exactly once.
  bool takeDamage(int amount) {
    if (!alive) return false;
    currentHealth -= amount;
    if (currentHealth < 0) currentHealth = 0;
    if (currentHealth <= 0) {
      alive = false;
      return true;
    }
    return false;
  }

  double get healthFraction => maxHealth > 0 ? currentHealth / maxHealth : 1.0;
}
