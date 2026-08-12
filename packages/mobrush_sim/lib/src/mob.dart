import 'dart:math' as math;

import 'combat_limits.dart';
import 'damageable.dart';
import 'gate.dart';

enum MobPhase { flying, grounded }

/// One crowd unit — the simulation half of `Assets/Scripts/Gameplay/Mob.cs`.
///
/// Everything Unity-specific has been stripped: there is no Transform, no
/// Renderer, no Animator. Position is three doubles and the mob knows nothing
/// about how it is drawn. That separation is the whole point of the port — the
/// same class drives a Flame scene, a headless benchmark, and a unit test.
///
/// Fields are plain doubles rather than a Vector3 object on purpose. Dart has
/// no value structs, so a vector type in this hot loop would allocate a fresh
/// object per neighbour per frame and hand the collector hundreds of thousands
/// of short-lived objects a second. The C# original gets that for free from
/// struct semantics; here it has to be spelled out.
class Mob {
  Mob({
    required this.team,
    required this.index,
    this.characterId = '',
    this.speed = 1.76,
    this.seekRange = 2.6,
    this.crowdSeparationRadius = 0.0,
  });

  /// 0 = player (blue), 1 = enemy (red).
  final int team;

  /// Stable creation order. Replaces `transform.GetSiblingIndex()`, which the
  /// C# version uses as the tie-breaker when two units occupy one point.
  final int index;

  /// Authored character definition used to create this unit.
  final String characterId;

  double x = 0, y = 0, z = 0;
  double velX = 0, velY = 0, velZ = 0;

  double speed;
  double seekRange;
  double crowdSeparationRadius;

  MobPhase phase = MobPhase.flying;
  bool dead = false;

  /// Direction influence with magnitude 0..1 — never units per second.
  double steerX = 0, steerZ = 0;

  /// Direction of the chosen enemy, already scaled by `seekWeight`.
  double seekDirX = 0, seekDirZ = 0;
  Mob? seekTarget;
  Mob? combatTarget;

  double hp = 5, maxHp = 5, atk = 1, def = 0.5;

  /// Seconds between structure-attack strikes. Port of `attackCooldown`,
  /// set by a spawner from `max(0.12, 1 / attackSpeed)` — this class does
  /// not compute that itself, matching the C# where it's assigned once in
  /// `Setup`, not derived on every use.
  double attackCooldown = 0.5;

  /// The tower or player base this mob is locked in melee against. Port of
  /// `structTarget` — set externally by a battle orchestrator's engage
  /// check (`ZoneChecks`'s tower/base branch), not by `Mob` itself, since
  /// deciding *which* structure is in range needs the tower/base list this
  /// class does not hold.
  Damageable? structTarget;
  double structAttackTimer = 0.0;

  /// Gates already applied to this mob this round. Port of `passedGates` —
  /// a gate checks membership here before calling `Gate.apply` again, and a
  /// spawned clone inherits its source's set so it cannot immediately
  /// retrigger the gate that just created it.
  final Set<Gate> passedGates = {};

  /// Lane direction this mob advances in. Player mobs walk toward -Z.
  double get advanceDirZ => team == 0 ? -1.0 : 1.0;

  static const double minBodyRadius = 0.30;
  static const double gravity = 24.0;
  static const double laneHalf = 4.8;
  static const double groundY = 0.499;

  /// How far a full-strength steer can pull a mob off its lane direction.
  static const double steerAuthority = 1.4;

  /// A mob locked in melee holds its ground but is still jostled apart.
  static const double jostleFraction = 0.12;

  double get bodyRadius => math.max(minBodyRadius, crowdSeparationRadius * 0.5);

  double get bodySurplus => bodyRadius - minBodyRadius;

  void fight(Mob other) {
    combatTarget = other;
  }

  /// Port of `Mob.TakeDamage`. Defence always reduces the hit, but never
  /// below a 0.5 floor — the C# comment calls this out explicitly so a
  /// heavily-defended unit is never literally unkillable.
  ///
  /// The C# also has being hit start a fight against an unengaged attacker
  /// (`combatTarget == null && structTarget == null`), which is what stops a
  /// mob from taking damage the whole way in and never striking back. Only
  /// the `combatTarget` half of that guard is modeled here — `structTarget`
  /// (a mob mid-melee against a tower or the player base) does not exist in
  /// this port yet, since the structure-attack path itself is not ported.
  void takeDamage(double amount, {Mob? attacker}) {
    if (dead) return;

    if (attacker != null &&
        !attacker.dead &&
        attacker.team != team &&
        combatTarget == null) {
      fight(attacker);
    }

    final finalDamage = math.max(0.5, amount - def);
    hp = math.max(hp - finalDamage, 0.0);
    if (hp <= 0) dead = true;
  }

  double _freezeTimer = 0.0;
  bool get isFrozen => _freezeTimer > 0;

  /// Port of `Mob.ApplyFreeze` — team-restricted exactly like the C#: only
  /// team 1 (enemy) mobs can be frozen, which is why the freeze ability
  /// never needs to check team on its own end.
  void applyFreeze(double duration) {
    if (dead || team != 1) return;
    if (duration > _freezeTimer) _freezeTimer = duration;
    steerX = 0;
    steerZ = 0;
    seekDirX = 0;
    seekDirZ = 0;
  }

  /// Advances one mob by [dt]. Mirrors the movement branch of `Mob.Update()`;
  /// the ordering matters — steering composes a direction and `speed` alone
  /// decides the pace, so seekRange stays a reach stat instead of becoming a
  /// sprint button.
  void tick(double dt) {
    if (dead) return;

    if (_freezeTimer > 0) {
      _freezeTimer -= dt;
      if (_freezeTimer < 0) _freezeTimer = 0;
      steerX = 0;
      steerZ = 0;
      seekDirX = 0;
      seekDirZ = 0;
      return;
    }

    // Runs ahead of the movement branch below, matching `Mob.Update()`'s own
    // order exactly: the C# resolves the combatTarget disengage/attack block
    // before deciding how the mob moves this frame, because the movement
    // branch reads whether it is still `fighting` as of *this* frame's
    // outcome, not last frame's.
    updateCombatState(dt);

    if (phase == MobPhase.flying) {
      velY -= gravity * dt;
      x += velX * dt;
      y += velY * dt;
      z += velZ * dt;
      if (y <= groundY) {
        y = groundY;
        phase = MobPhase.grounded;
        velX = velY = velZ = 0;
      }
      return;
    }

    final fighting = combatTarget != null && !combatTarget!.dead;
    double horizX, horizZ;

    if (fighting) {
      horizX = steerX * (speed * jostleFraction);
      horizZ = steerZ * (speed * jostleFraction);
    } else {
      // A spotted enemy is a commitment, not a nudge: the lane direction is
      // blended toward the target rather than having a pull added to it. Added
      // as a pull it could bend the march by ~37° at most, so a crowd drifted
      // toward the enemy and then walked straight past it to the castle.
      final seekMag = math.sqrt(seekDirX * seekDirX + seekDirZ * seekDirZ);
      double laneX, laneZ;
      if (seekMag > 0.01) {
        final t = seekMag.clamp(0.0, 1.0);
        laneX = _lerp(0.0, seekDirX / seekMag, t);
        laneZ = _lerp(advanceDirZ, seekDirZ / seekMag, t);
      } else {
        laneX = 0.0;
        laneZ = advanceDirZ;
      }

      final desiredX = laneX + steerX * steerAuthority;
      final desiredZ = laneZ + steerZ * steerAuthority;
      final mag = math.sqrt(desiredX * desiredX + desiredZ * desiredZ);
      if (mag > 0.001) {
        horizX = desiredX / mag * speed;
        horizZ = desiredZ / mag * speed;
      } else {
        horizX = 0;
        horizZ = 0;
      }
    }

    x += horizX * dt;
    z += horizZ * dt;
    y = groundY;
    if (x < -laneHalf) x = -laneHalf;
    if (x > laneHalf) x = laneHalf;
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// Seconds into the current mob-vs-mob melee swing. Separate from
  /// [structAttackTimer] — a mob is never fighting both at once, but they
  /// are conceptually different clocks in the C# (`_attackTimer` vs
  /// `_structAttackTimer`) and kept separate here for the same reason.
  double attackTimer = 0.0;

  /// Releases a duel once the pair has drifted past the disengage band, and
  /// otherwise deals melee damage on `attackCooldown`. Port of the
  /// `combatTarget != null` block in `Mob.Update()` — the C# runs this
  /// ahead of the Flying/Grounded movement branch, which is why a
  /// battle orchestrator calls this before [tick], not after.
  void updateCombatState(double dt) {
    final t = combatTarget;
    if (t == null) return;
    if (t.dead) {
      combatTarget = null;
      attackTimer = 0;
      return;
    }

    final dx = x - t.x, dz = z - t.z;
    final d = math.sqrt(dx * dx + dz * dz);
    final release =
        CombatLimits.clashDistance(
          CombatLimits.baseClashRadius,
          bodySurplus,
          t.bodySurplus,
        ) *
        CombatLimits.disengageFactor;

    if (d > release) {
      combatTarget = null;
      attackTimer = 0;
      return;
    }

    attackTimer += dt;
    if (attackTimer >= attackCooldown) {
      attackTimer = 0;
      t.takeDamage(atk, attacker: this);
    }
  }
}
