/// Combat stat block shared by base stats and per-level bonuses.
///
/// Port of `MobStats` in `Assets/Scripts/Data/CharacterDefinition.cs`. Kept as
/// an immutable value type with a `+` via [add] rather than a struct with
/// mutable fields — Dart has no operator structs, so the C# `operator +` on
/// this exact type becomes a named method instead of a symbol.
class MobStats {
  const MobStats({
    this.hp = 0,
    this.atk = 0,
    this.def = 0,
    this.speed = 0,
    this.attackSpeed = 0,
    this.seekRange = 0,
  });

  final double hp;
  final double atk;
  final double def;
  final double speed;

  /// Attacks per second.
  final double attackSpeed;

  /// How far this mob can detect and chase an opposing mob, world units.
  final double seekRange;

  MobStats add(MobStats other) => MobStats(
        hp: hp + other.hp,
        atk: atk + other.atk,
        def: def + other.def,
        speed: speed + other.speed,
        attackSpeed: attackSpeed + other.attackSpeed,
        seekRange: seekRange + other.seekRange,
      );

  factory MobStats.fromJson(Map<String, dynamic> json) => MobStats(
        hp: (json['hp'] as num?)?.toDouble() ?? 0,
        atk: (json['atk'] as num?)?.toDouble() ?? 0,
        def: (json['def'] as num?)?.toDouble() ?? 0,
        speed: (json['speed'] as num?)?.toDouble() ?? 0,
        attackSpeed: (json['attackSpeed'] as num?)?.toDouble() ?? 0,
        seekRange: (json['seekRange'] as num?)?.toDouble() ?? 0,
      );

  @override
  String toString() =>
      'MobStats(hp: $hp, atk: $atk, def: $def, speed: $speed, '
      'attackSpeed: $attackSpeed, seekRange: $seekRange)';
}
