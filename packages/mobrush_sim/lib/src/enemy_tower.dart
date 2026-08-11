import 'damageable.dart';

/// Enemy spawner castle/tower: has HP, pumps out defenders, collapses at 0.
///
/// Port of the simulation core of `Assets/Scripts/Gameplay/EnemyTower.cs`.
/// The auto-fit-to-renderer engage box, the HP bar, the collapse animation,
/// and the reference castle artwork are left out; this models exactly what
/// `Update()`/`SpawnWave()`/`TakeDamage()`/`ZoneChecks()`'s tower branch
/// decide, which is what a headless battle needs. [engageHalfWidth]/
/// [engageHalfDepth] stand in for `EngageHalfWidth`/`EngageHalfDepth` at
/// their resolved runtime defaults (`_engageHalfWidth = 1.3f`,
/// `_engageHalfDepth = 1.1f` in the C#) rather than the renderer-fit values,
/// since there is no renderer here to fit to.
class EnemyTower implements Damageable {
  EnemyTower({
    required this.maxHealth,
    required this.enemyReserve,
    required this.spawnInterval,
    this.initialSpawnDelay = 0.0,
    this.spawnBatch = 2,
    this.spawnedCharacterId = 'base_enemy',
    this.x = 0.0,
    this.z = 0.0,
    this.engageHalfWidth = 1.3,
    this.engageHalfDepth = 1.1,
    this.launchSpeed = 3.8,
    this.launchUpwardForce = 3.4,
    this.spreadWidth = 2.0,
  })  : currentHealth = maxHealth,
        _spawnTimer = initialSpawnDelay > 0 ? initialSpawnDelay : 0.0;

  final int maxHealth;
  int enemyReserve;
  final double spawnInterval;
  final double initialSpawnDelay;
  final int spawnBatch;
  final String spawnedCharacterId;

  /// Ground position. Read by ability radius checks
  /// (`BattleAbilityController`'s Freeze/Fireball/Lightning) and by a
  /// battle orchestrator's engage/attack and wave-launch placement.
  @override
  final double x;
  @override
  final double z;

  /// Half-extents of the attack-trigger box around [x]/[z], in world
  /// metres. A player mob within this box locks onto the tower as its
  /// `structTarget`. Port of the *resolved* `EngageHalfWidth`/
  /// `EngageHalfDepth` — see the class doc for why these are fixed
  /// constants here rather than fit to a renderer.
  final double engageHalfWidth;
  final double engageHalfDepth;

  /// Forward launch speed and upward arc for defenders this tower spawns.
  /// Port of `EnemyTower.launchSpeed`/`launchUpwardForce`/`spreadWidth`.
  final double launchSpeed;
  final double launchUpwardForce;
  final double spreadWidth;

  int currentHealth;
  @override
  bool alive = true;
  double _spawnTimer;
  double _freezeTimer = 0.0;

  /// One wave's worth of spawn requests, produced by [tick] when its timer
  /// elapses. The caller (the battle orchestrator) turns each into an actual
  /// `Mob` — this class only decides *when* and *how many*, matching
  /// `EnemyTower.SpawnWave()`'s reserve bookkeeping exactly, without knowing
  /// anything about how a mob is placed in the world.
  int lastWaveSpawnCount = 0;

  bool get isFrozen => _freezeTimer > 0;

  /// Stops defender spawning while Freeze is active. Port of `ApplyFreeze`.
  void applyFreeze(double duration) {
    if (!alive) return;
    if (duration > _freezeTimer) _freezeTimer = duration;
  }

  /// Advances the spawn timer by [dt] and returns the number of defenders to
  /// spawn this step (0 most steps). Mirrors `EnemyTower.Update()`'s ordering:
  /// frozen towers do not count down their spawn timer at all, and a wave
  /// only fires once the timer crosses zero, spending exactly
  /// `min(spawnBatch, enemyReserve)` from the reserve.
  int tick(double dt) {
    lastWaveSpawnCount = 0;
    if (!alive || enemyReserve <= 0) return 0;

    if (_freezeTimer > 0) {
      _freezeTimer -= dt;
      if (_freezeTimer < 0) _freezeTimer = 0;
      return 0;
    }

    _spawnTimer -= dt;
    if (_spawnTimer > 0) return 0;

    _spawnTimer = spawnInterval;
    final count = spawnBatch < enemyReserve ? spawnBatch : enemyReserve;
    if (count <= 0) return 0;
    enemyReserve -= count;
    lastWaveSpawnCount = count;
    return count;
  }

  /// Port of `TakeDamage`. Returns true the instant this call collapses the
  /// tower, so a caller can fire `OnTowerDestroyed()`-equivalent logic
  /// exactly once.
  @override
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
}
