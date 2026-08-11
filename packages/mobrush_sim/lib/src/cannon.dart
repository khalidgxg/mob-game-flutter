import 'dart:math' as math;

/// One launch request the cannon wants to spawn — direction and vertical
/// launch speed for a `Mob.Launch(velocity)`-equivalent call. The battle
/// orchestrator turns this into an actual mob; `Cannon` only decides the
/// ballistics and whether ammo/energy allow it.
class CannonShot {
  const CannonShot({
    required this.dirX,
    required this.dirZ,
    required this.launchY,
  });

  final double dirX;
  final double dirZ;
  final double launchY;
}

/// The player's cannon: aim, ammo, fire-rate cooldown, and the multi-shot
/// spread formula. Port of the simulation core of
/// `Assets/Scripts/Gameplay/Cannon.cs` — touch/mouse/pen input handling,
/// camera raycasting, and every visual (recoil, muzzle flash) are left out.
/// [aimX]/[aimZ] stand in for what `UpdateAim` computes from a screen
/// touch; a Flutter front end resolves the touch-to-world ray itself and
/// hands this class a direction.
class Cannon {
  Cannon({
    this.fireRate = 0.045,
    this.mobsPerShot = 1,
    this.launchSpeed = 6.0,
    this.launchLift = 2.2,
    this.spread = 0.09,
    this.ammoCapacity = 130,
    this.unlimited = false,
    math.Random? rng,
  })  : reserve = ammoCapacity,
        _rng = rng ?? math.Random();

  final double fireRate;
  final int mobsPerShot;
  final double launchSpeed;
  final double launchLift;
  final double spread;
  final int ammoCapacity;
  final bool unlimited;

  int reserve;
  double _cooldown = 0.0;
  final math.Random _rng;

  /// Current aim direction, already clamped the way `UpdateAim` clamps it:
  /// the cannon can never point back up the lane at the player.
  double aimX = 0.0;
  double aimZ = -1.0;

  int get ammoRemaining => unlimited ? ammoCapacity : reserve.clamp(0, ammoCapacity);
  int get ammoSpent => (ammoCapacity - ammoRemaining) < 0 ? 0 : ammoCapacity - ammoRemaining;

  bool get canFireNow => _cooldown <= 0 && (unlimited || reserve > 0);

  /// Sets the aim direction from a world-space vector, clamping the forward
  /// component the same way `UpdateAim` does: "Always fire down the lane
  /// (toward -Z); clamp the sweep" — the sign matches the live game because
  /// player mobs advance toward -Z too (`Mob.advanceDirZ` for team 0).
  ///
  /// Faithfully reproduces a quirk of the C#, not just its intent: the input
  /// is normalized, the z component is clamped to -0.35 if it isn't already
  /// past it, and the result is normalized a *second* time. That second
  /// normalize rescales x along with the now-fixed z — so for a purely
  /// sideways/backward input (x near 0), the result collapses all the way to
  /// (0, -1) instead of stopping at (0, -0.35). `-0.35` is a floor on the
  /// intermediate value the second normalize starts from, not a floor on the
  /// final z you get out.
  void setAim(double x, double z) {
    var nx = x, nz = z;
    final mag = math.sqrt(nx * nx + nz * nz);
    if (mag < 0.0001) return;
    nx /= mag;
    nz /= mag;
    if (nz > -0.35) {
      nz = -0.35;
      final renorm = math.sqrt(nx * nx + nz * nz);
      nx /= renorm;
      nz /= renorm;
    }
    aimX = nx;
    aimZ = nz;
  }

  void tick(double dt) {
    if (_cooldown > 0) _cooldown -= dt;
  }

  /// Fires one shot if the cooldown and ammo allow it, spreading
  /// [mobsPerShot] launches across a fan the same way `Fire()` does: an 8°
  /// step per shot, centred on the aim direction.
  ///
  /// Each shot in the fan is independently checked against
  /// [canAffordLaunch] and stops the fan early exactly like the C#'s
  /// `if (!SpawnAndLaunchMob(velocity)) break;` — a fan that starts
  /// affordable but runs out of energy mid-fan returns fewer shots than
  /// requested rather than none.
  List<CannonShot> fire({
    required bool Function() canAffordLaunch,
    required void Function() consumeLaunchCost,
  }) {
    if ((!unlimited && reserve <= 0) || _cooldown > 0 || !canAffordLaunch()) {
      return const [];
    }

    const angleStepDeg = 8.0;
    final shotCount = mobsPerShot < 1 ? 1 : mobsPerShot;
    final baseAngle = math.atan2(aimX, aimZ) * 180.0 / math.pi;
    final startAngle = baseAngle - (shotCount - 1) * angleStepDeg * 0.5;

    final shots = <CannonShot>[];
    for (var i = 0; i < shotCount; i++) {
      if (!unlimited && reserve <= 0) break;
      if (i > 0 && !canAffordLaunch()) break;

      final angle = (startAngle + i * angleStepDeg) * math.pi / 180.0;
      var dx = math.sin(angle);
      var dz = math.cos(angle);
      dx += (_rng.nextDouble() * 2 - 1) * spread;
      final mag = math.sqrt(dx * dx + dz * dz);
      dx /= mag;
      dz /= mag;

      shots.add(
        CannonShot(
          dirX: dx * launchSpeed,
          dirZ: dz * launchSpeed,
          launchY: launchLift + (_rng.nextDouble() * 2 - 1) * 0.3,
        ),
      );
      consumeLaunchCost();
      if (!unlimited) reserve--;
    }

    if (shots.isNotEmpty) _cooldown = fireRate;
    return shots;
  }
}
