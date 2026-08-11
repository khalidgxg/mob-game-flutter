import 'dart:math' as math;

import 'package:mobrush_data/mobrush_data.dart';

import 'enemy_tower.dart';
import 'mob.dart';

enum Ability { freeze, fireball, lightning }

/// One resolved attempt at using an ability: whether it found a target and
/// what it hit, for a caller that wants to drive VFX/SFX off the outcome
/// without this class knowing anything about presentation.
class AbilityResult {
  const AbilityResult({
    required this.applied,
    this.centerX = 0.0,
    this.centerZ = 0.0,
    this.mobsHit = 0,
    this.towersHit = 0,
  });

  final bool applied;
  final double centerX;
  final double centerZ;
  final int mobsHit;
  final int towersHit;
}

/// The battle-only tactical layer: deploy energy and the three limited-use
/// abilities. Port of the simulation core of
/// `Assets/Scripts/Gameplay/BattleAbilityController.cs` — HUD state
/// (`StateChanged`), character-card selection, RUSH, and the opening
/// formation spawn are the presentation/deployment half and are not modeled
/// here; this covers exactly what §13 of the flow document describes:
/// Freeze, Fireball, and Lightning's targeting and damage.
class BattleAbilities {
  BattleAbilities({
    required AbilityTuning freeze,
    required AbilityTuning fireball,
    required AbilityTuning lightning,
    required this.maxEnergy,
    double startingEnergy = 100.0,
    this.energyRegenPerSecond = 8.0,
  })  : _freeze = freeze,
        _fireball = fireball,
        _lightning = lightning,
        freezeCharges = freeze.charges,
        fireballCharges = fireball.charges,
        lightningCharges = lightning.charges,
        energy = startingEnergy.clamp(0.0, maxEnergy);

  final AbilityTuning _freeze;
  final AbilityTuning _fireball;
  final AbilityTuning _lightning;

  final double maxEnergy;
  final double energyRegenPerSecond;
  double energy;

  int freezeCharges;
  int fireballCharges;
  int lightningCharges;

  int chargesFor(Ability ability) {
    switch (ability) {
      case Ability.freeze:
        return freezeCharges;
      case Ability.fireball:
        return fireballCharges;
      case Ability.lightning:
        return lightningCharges;
    }
  }

  void regenEnergy(double dt) {
    if (energy >= maxEnergy) return;
    energy = math.min(maxEnergy, energy + energyRegenPerSecond * dt);
  }

  /// Port of `TryConsumeEnergy` — used by the cannon for per-launch costs.
  bool tryConsumeEnergy(double amount) {
    if (amount <= 0) return true;
    if (energy < amount) return false;
    energy -= amount;
    return true;
  }

  /// Port of `TryUse` — dispatches to the ability's targeting/damage
  /// function and spends a charge only if it actually found a target,
  /// exactly like the C#'s `if (!applied) return false;` before decrementing.
  AbilityResult tryUse(
    Ability ability, {
    required List<Mob> mobs,
    required List<EnemyTower> towers,
  }) {
    if (chargesFor(ability) <= 0) {
      return const AbilityResult(applied: false);
    }

    final result = switch (ability) {
      Ability.freeze => _applyFreeze(mobs, towers),
      Ability.fireball => _applyFireball(mobs, towers),
      Ability.lightning => _applyLightning(mobs, towers),
    };

    if (!result.applied) return result;

    switch (ability) {
      case Ability.freeze:
        freezeCharges--;
      case Ability.fireball:
        fireballCharges--;
      case Ability.lightning:
        lightningCharges--;
    }
    return result;
  }

  /// Port of `ApplyFreeze`. Freezes every living enemy mob and every alive
  /// tower — team/alive filtering matches `Mob.ApplyFreeze`'s own team==1
  /// restriction, so this does not need to filter mobs by team itself.
  AbilityResult _applyFreeze(List<Mob> mobs, List<EnemyTower> towers) {
    final duration = math.max(0.1, _freeze.duration);
    var centerX = 0.0, centerZ = 0.0;
    var count = 0;
    var mobsHit = 0, towersHit = 0;

    for (final m in mobs) {
      if (m.dead || m.team != 1) continue;
      m.applyFreeze(duration);
      centerX += m.x;
      centerZ += m.z;
      count++;
      mobsHit++;
    }
    for (final t in towers) {
      if (!t.alive) continue;
      t.applyFreeze(duration);
      centerX += t.x;
      centerZ += t.z;
      count++;
      towersHit++;
    }

    if (count == 0) return const AbilityResult(applied: false);
    return AbilityResult(
      applied: true,
      centerX: centerX / count,
      centerZ: centerZ / count,
      mobsHit: mobsHit,
      towersHit: towersHit,
    );
  }

  /// Port of `ApplyFireball` + `TryFindFireballTarget` + `DamageFireball`.
  /// Targets the enemy mob with the most same-team neighbours within
  /// radius (ties broken toward the mob furthest down the lane), falling
  /// back to any alive tower, matching "it bombs the densest crowd, or the
  /// castle if there is no crowd yet".
  AbilityResult _applyFireball(List<Mob> mobs, List<EnemyTower> towers) {
    final radius = math.max(1.0, _fireball.radius);
    final radiusSq = radius * radius;

    Mob? best;
    var bestNeighbors = -1;
    var bestForward = double.negativeInfinity;

    for (final candidate in mobs) {
      if (candidate.dead || candidate.team != 1) continue;
      var neighbors = 0;
      for (final other in mobs) {
        if (other.dead || other.team != 1) continue;
        final dx = other.x - candidate.x;
        final dz = other.z - candidate.z;
        if (dx * dx + dz * dz <= radiusSq) neighbors++;
      }
      final forward = candidate.z;
      if (neighbors < bestNeighbors ||
          (neighbors == bestNeighbors && forward <= bestForward)) {
        continue;
      }
      best = candidate;
      bestNeighbors = neighbors;
      bestForward = forward;
    }

    double centerX, centerZ;
    if (best != null) {
      centerX = best.x;
      centerZ = best.z;
    } else {
      EnemyTower? targetTower;
      for (final t in towers) {
        if (t.alive) {
          targetTower = t;
          break;
        }
      }
      if (targetTower == null) return const AbilityResult(applied: false);
      centerX = targetTower.x;
      centerZ = targetTower.z;
    }

    var mobsHit = 0, towersHit = 0;
    for (final m in mobs) {
      if (m.dead || m.team != 1) continue;
      final dx = m.x - centerX, dz = m.z - centerZ;
      if (dx * dx + dz * dz > radiusSq) continue;
      // Fireball is deliberately a fixed hit: its authored amount is the
      // damage the player sees after defence, so a high-HP enemy cannot
      // turn a crowd-control spell into an automatic execution.
      var intendedDamage =
          _fireball.mobDamage > 0 ? _fireball.mobDamage : m.maxHp * _fireball.mobDamageFraction;
      intendedDamage = math.max(_fireball.minimumDamage, intendedDamage);
      m.takeDamage(intendedDamage + m.def);
      mobsHit++;
    }
    for (final t in towers) {
      if (!t.alive) continue;
      final dx = t.x - centerX, dz = t.z - centerZ;
      if (dx * dx + dz * dz > radiusSq) continue;
      t.takeDamage(math.max(_fireball.minimumDamage.ceil(), _fireball.castleDamage));
      towersHit++;
    }

    if (mobsHit == 0 && towersHit == 0) return const AbilityResult(applied: false);
    return AbilityResult(
      applied: true,
      centerX: centerX,
      centerZ: centerZ,
      mobsHit: mobsHit,
      towersHit: towersHit,
    );
  }

  /// Port of `ApplyLightning`. Targets the tower with the lowest health
  /// ratio (a near-dead castle takes priority over a full one so the last
  /// hit finishes what's already started), falling back to the enemy mob
  /// furthest down the lane when no tower is alive.
  AbilityResult _applyLightning(List<Mob> mobs, List<EnemyTower> towers) {
    EnemyTower? targetTower;
    var bestRatio = double.maxFinite;
    for (final t in towers) {
      if (!t.alive) continue;
      final ratio = t.currentHealth / math.max(1, t.maxHealth);
      if (ratio >= bestRatio) continue;
      bestRatio = ratio;
      targetTower = t;
    }

    double centerX, centerZ;
    var towersHit = 0;
    var directMobsHit = 0;

    if (targetTower != null) {
      centerX = targetTower.x;
      centerZ = targetTower.z;
      targetTower.takeDamage(math.max(_lightning.minimumDamage.ceil(), _lightning.castleDamage));
      towersHit = 1;
    } else {
      Mob? nearestThreat;
      var bestZ = double.negativeInfinity;
      for (final m in mobs) {
        if (m.dead || m.team != 1) continue;
        if (m.z <= bestZ) continue;
        nearestThreat = m;
        bestZ = m.z;
      }
      if (nearestThreat == null) return const AbilityResult(applied: false);
      centerX = nearestThreat.x;
      centerZ = nearestThreat.z;
      // A direct mob hit is a guaranteed kill: maxHp + def, so TakeDamage's
      // own defence subtraction still leaves at least maxHp of damage.
      nearestThreat.takeDamage(
        math.max(_lightning.minimumDamage, nearestThreat.maxHp + nearestThreat.def),
      );
      directMobsHit = 1;
    }

    final radius = math.max(0.5, _lightning.radius);
    final radiusSq = radius * radius;
    var splashMobsHit = 0;
    for (final m in mobs) {
      if (m.dead || m.team != 1) continue;
      final dx = m.x - centerX, dz = m.z - centerZ;
      if (dx * dx + dz * dz > radiusSq) continue;
      m.takeDamage(
        math.max(_lightning.minimumDamage * 0.35, m.maxHp * _lightning.mobDamageFraction + m.def),
      );
      splashMobsHit++;
    }

    return AbilityResult(
      applied: true,
      centerX: centerX,
      centerZ: centerZ,
      mobsHit: directMobsHit + splashMobsHit,
      towersHit: towersHit,
    );
  }
}
