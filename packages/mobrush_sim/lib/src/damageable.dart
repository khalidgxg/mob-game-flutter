/// Common shape shared by [EnemyTower] and [PlayerBase] — the two things a
/// `Mob` can lock into structure melee against. Port of the `IDamageable`
/// interface `Assets/Scripts/Gameplay/Mob.cs` targets via `structTarget`,
/// so `Mob` can hold one reference without knowing which concrete type it
/// points at.
abstract class Damageable {
  bool get alive;
  double get x;
  double get z;

  /// Returns true the instant this call brings the object down.
  bool takeDamage(int amount);
}
