import 'dart:math' as math;

import 'package:mobrush_data/mobrush_data.dart';

import 'battle_abilities.dart';
import 'cannon.dart';
import 'crowd_manager.dart';
import 'enemy_tower.dart';
import 'gate.dart';
import 'mob.dart';
import 'player_base.dart';

enum RoundOutcome { ongoing, win, lose }

/// One playable round, assembled from the five systems Phase 2 ported
/// separately and driven start-to-finish by a scripted caller — the
/// orchestrator §4's Phase 2 gate asks for. It owns exactly the ordering
/// decisions `Game.cs`/`Mob.cs`/`EnemyTower.cs` make about how those systems
/// talk to each other each step; it does not re-derive any of their own
/// rules, which stay in their own files.
///
/// What this class does *not* do, matching the plan's stated scope: no
/// `Obstacle`/`BarrierPush` (no obstacles are modeled), no footprint-ejection
/// physics (`StructurePush`'s positional nudge — cosmetic, not
/// outcome-affecting), no `HasCannonPriority` crowd-vs-cannon targeting
/// nuance in `CrowdManager`, and no `StageManager`/`LoadoutManager`
/// (profile-facing progression is a caller concern, not this class's).
class BattleRound {
  BattleRound({
    required this.content,
    required this.towers,
    required this.base,
    required this.cannon,
    required this.abilities,
    List<Gate>? gates,
    int maxMobs = 350,
  })  : gates = gates ?? [],
        _maxMobs = maxMobs;

  final ContentCatalog content;
  final List<EnemyTower> towers;
  final PlayerBase base;
  final Cannon cannon;
  final BattleAbilities abilities;
  final List<Gate> gates;
  final int _maxMobs;

  final List<Mob> mobs = [];
  final CrowdManager crowd = CrowdManager();

  static const double fixedStep = 1.0 / 60.0;
  double _accumulator = 0;

  /// Port of `Game._graceT`/`_outOfAmmo` — the 1.5s window after the cannon
  /// runs dry before an empty-handed loss is declared.
  static const double _ammoGraceSeconds = 1.5;
  double _graceTimer = -1;
  bool _outOfAmmo = false;

  RoundOutcome outcome = RoundOutcome.ongoing;
  double elapsedSeconds = 0;

  int _nextMobIndex = 0;

  bool get liveMobCount {
    var n = 0;
    for (final m in mobs) {
      if (!m.dead) n++;
    }
    return n > 0;
  }

  int get livePlayerMobCount {
    var n = 0;
    for (final m in mobs) {
      if (!m.dead && m.team == 0) n++;
    }
    return n;
  }

  bool get _anyTowerAlive {
    for (final t in towers) {
      if (t.alive) return true;
    }
    return false;
  }

  /// Places a new mob using [characterId]'s authored stats. Returns null
  /// when the global mob cap is reached, matching `Game.SpawnMob`.
  Mob? spawnMob(
    int team,
    String characterId, {
    required double x,
    required double y,
    required double z,
    double velX = 0,
    double velY = 0,
    double velZ = 0,
    MobPhase phase = MobPhase.flying,
  }) {
    if (mobs.length - _deadCount() >= _maxMobs) return null;
    final def = content.character(characterId);
    final stats = def?.baseStats ?? const MobStats(hp: 5, atk: 1, def: 0.5, speed: 1.76, seekRange: 2.6);
    final crowdSeparation = def?.crowdSeparationRadius ?? 0.0;

    final mob = Mob(
      team: team,
      index: _nextMobIndex++,
      speed: stats.speed,
      seekRange: stats.seekRange,
      crowdSeparationRadius: crowdSeparation,
    )
      ..x = x
      ..y = y
      ..z = z
      ..velX = velX
      ..velY = velY
      ..velZ = velZ
      ..hp = stats.hp
      ..maxHp = stats.hp
      ..atk = stats.atk
      ..def = stats.def
      ..attackCooldown = stats.attackSpeed > 0 ? math.max(0.12, 1.0 / stats.attackSpeed) : 0.2
      ..phase = phase;
    mobs.add(mob);
    return mob;
  }

  int _deadCount() {
    var n = 0;
    for (final m in mobs) {
      if (m.dead) n++;
    }
    return n;
  }

  /// Fires the cannon along [aimX]/[aimZ] and spawns whatever
  /// `Cannon.fire` allows. Port of `Cannon.Update`'s aim + `Fire()` path,
  /// minus the touch/mouse/camera resolution that produces the aim vector
  /// in the first place.
  void aimAndFire(double aimX, double aimZ) {
    cannon.setAim(aimX, aimZ);
    if (outcome != RoundOutcome.ongoing) return;

    final characterId = abilities.selectedCharacterId;
    final shots = cannon.fire(
      canAffordLaunch: () {
        final cost = _launchEnergyCost(characterId);
        return cost <= 0 || abilities.energy >= cost;
      },
      consumeLaunchCost: () {
        final cost = _launchEnergyCost(characterId);
        if (cost > 0) abilities.tryConsumeEnergy(cost.toDouble());
      },
    );
    for (final shot in shots) {
      spawnMob(
        0,
        characterId,
        x: 0,
        y: 0.5,
        z: 12.8,
        velX: shot.dirX,
        velY: shot.launchY,
        velZ: shot.dirZ,
      );
    }
  }

  int _launchEnergyCost(String characterId) =>
      content.character(characterId)?.launchEnergyCost ?? 0;

  /// Advances the round by [dt] of wall-clock time, running as many fixed
  /// steps as that time covers — mirrors `BattleSim.advance`.
  void advance(double dt) {
    _accumulator += math.min(dt, 0.25);
    while (_accumulator >= fixedStep) {
      _accumulator -= fixedStep;
      step(fixedStep);
    }
  }

  /// One fixed simulation step: crowd solve, every mob, every tower's spawn
  /// clock, energy regen, and win/lose evaluation — in that order, matching
  /// `[DefaultExecutionOrder]`'s intent in the C# (crowd before mobs) plus
  /// `Game.Update`'s own win/lose checks running after everything else has
  /// moved.
  void step(double dt) {
    if (outcome != RoundOutcome.ongoing) return;
    elapsedSeconds += dt;

    crowd.update(mobs);

    // Indexed, not `for (final m in mobs)`: stepping a mob can spawn new
    // ones mid-loop (a gate clone, an ejected-by-cap-reached deferral does
    // not apply here since spawnMob is what enforces the cap) by appending
    // to this same `mobs` list, which a `for-in`'s iterator treats as
    // concurrent modification and throws on. Capturing the length once
    // means anything spawned this step is simply left to start moving next
    // step, matching ordinary spawn-then-next-frame semantics.
    final stepCount = mobs.length;
    for (var i = 0; i < stepCount; i++) {
      _stepMob(mobs[i], dt);
    }

    for (final t in towers) {
      final count = t.tick(dt);
      for (var i = 0; i < count; i++) {
        _spawnTowerDefender(t, i, count);
      }
    }

    cannon.tick(dt);
    abilities.regenEnergy(dt);

    _evaluateAmmoLoss(dt);
    _evaluateWinLoss();
  }

  void _spawnTowerDefender(EnemyTower tower, int i, int count) {
    final t = count > 1 ? (i / (count - 1) - 0.5) : 0.0;
    final offsetX = t * tower.spreadWidth;
    final velX = t * (tower.spreadWidth * 0.8);
    final forwardZ = tower.launchSpeed.abs();
    spawnMob(
      1,
      tower.spawnedCharacterId,
      x: tower.x + offsetX,
      y: 0.5,
      z: tower.z,
      velX: velX,
      velY: tower.launchUpwardForce,
      velZ: forwardZ,
    );
  }

  /// Per-mob step. Order mirrors `Mob.Update()`: dead mobs are skipped
  /// entirely, a frozen mob only ticks its freeze timer down, a mob already
  /// locked in structure melee attacks (or releases/dies) instead of
  /// moving, and only then does an unlocked mob move and get checked
  /// against gates/towers/the base for a new engagement.
  void _stepMob(Mob m, double dt) {
    if (m.dead) return;

    if (m.isFrozen) {
      m.tick(dt); // ApplyFreeze's own early-return path: no movement.
      return;
    }

    if (m.structTarget != null) {
      _stepStructAttack(m, dt);
      return;
    }

    final beforeX = m.x, beforeY = m.y, beforeZ = m.z;
    m.tick(dt);
    _zoneChecks(m, beforeX, beforeY, beforeZ);
  }

  void _stepStructAttack(Mob m, double dt) {
    final target = m.structTarget!;
    if (!target.alive) {
      m.structTarget = null;
      m.structAttackTimer = 0;
      // A castle falling is not the end of this mob's war -- it resumes
      // marching if anything is still standing to march on, matching
      // `AnyCastleStanding()`. Only team 0 (attacking towers) needs the
      // check; team 1 (attacking the single player base) has nothing left
      // to resume toward once the base is down, but that case already ends
      // the round via `_evaluateWinLoss` before this can run again.
      if (m.team == 0 && !_anyTowerAlive) {
        m.dead = true; // nothing left to march on to
      }
      return; // falls through to normal movement next step either way
    }

    m.structAttackTimer += dt;
    if (m.structAttackTimer >= m.attackCooldown) {
      m.structAttackTimer = 0;
      final dmg = math.max(1, m.atk.round());
      target.takeDamage(dmg);
    }
  }

  /// Port of `Mob.ZoneChecks`. Player mobs check gates then towers; enemy
  /// mobs check only the base. A mob that already has a live crowd target
  /// (`combatTarget`/`seekTarget`) skips the tower check entirely — `Mob`'s
  /// own comment: without that guard, reaching a castle's ring overwrote a
  /// target the crowd had already picked, and units walked past a living
  /// blocker to attack the castle behind it.
  void _zoneChecks(Mob m, double beforeX, double beforeY, double beforeZ) {
    if (m.team == 0) {
      for (final g in gates) {
        if (m.passedGates.contains(g)) continue;
        if (g.wasCrossed(beforeX, beforeY, beforeZ, m.x, m.y, m.z)) {
          _applyGate(g, m);
        }
      }

      final hasLiveMobTarget =
          (m.combatTarget != null && !m.combatTarget!.dead) ||
              (m.seekTarget != null && !m.seekTarget!.dead);
      if (hasLiveMobTarget) return;

      for (final t in towers) {
        if (!t.alive) continue;
        final reach = m.bodyRadius;
        if ((m.x - t.x).abs() < t.engageHalfWidth + reach &&
            (m.z - t.z).abs() < t.engageHalfDepth + reach) {
          m.structTarget = t;
          m.structAttackTimer = m.attackCooldown; // strike immediately
          return;
        }
      }
    } else {
      if (base.alive &&
          base.isWithinDefenceLine(m.x, m.z, bodyRadius: m.bodyRadius)) {
        m.structTarget = base;
        m.structAttackTimer = m.attackCooldown; // strike immediately
      }
    }
  }

  void _applyGate(Gate g, Mob m) {
    m.passedGates.add(g);
    final characterId = _characterIdFor(m);
    final canGenerate = _canGenerateCharacter(characterId);
    final capacityRemaining = _maxMobs - (mobs.length - _deadCount());
    final result = g.apply(canGenerate: canGenerate, capacityRemaining: capacityRemaining);

    for (var i = 0; i < result.spawned; i++) {
      final clone = spawnMob(
        0,
        characterId,
        x: m.x + (i - result.spawned / 2) * 0.3,
        y: 0.05,
        z: m.z,
        phase: MobPhase.grounded,
      );
      clone?.passedGates.addAll(m.passedGates);
    }
    if (result.mobDied) m.dead = true;
  }

  /// A spawned mob does not carry its authored character id — this
  /// orchestrator does, keyed by team/definition at spawn time. Until a
  /// caller wires a proper id-carrying spawn record, gates and clones reuse
  /// the currently-selected cannon character for player-side generation,
  /// matching `Gate.Apply`'s own fallback
  /// (`mob.definition?.id ?? Game.I.SelectedCharacterId`).
  String _characterIdFor(Mob m) => abilities.selectedCharacterId;

  bool _canGenerateCharacter(String characterId) {
    final def = content.character(characterId);
    return def == null || def.canBeGeneratedByGate;
  }

  void _evaluateAmmoLoss(double dt) {
    if (cannon.unlimited) return;
    if (cannon.reserve <= 0 && _graceTimer < 0 && !_outOfAmmo) {
      _graceTimer = _ammoGraceSeconds;
    }
    if (_graceTimer > 0) {
      _graceTimer -= dt;
      if (_graceTimer <= 0) _outOfAmmo = true;
    }
    if (_outOfAmmo && _anyTowerAlive && livePlayerMobCount == 0) {
      outcome = RoundOutcome.lose;
    }
  }

  void _evaluateWinLoss() {
    if (outcome != RoundOutcome.ongoing) return;
    if (!base.alive) {
      outcome = RoundOutcome.lose;
      return;
    }
    if (!_anyTowerAlive) {
      outcome = RoundOutcome.win;
    }
  }
}
