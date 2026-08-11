/// Enemy spawner castle/tower: has HP, pumps out defenders, collapses at 0.
///
/// Port of the simulation core of `Assets/Scripts/Gameplay/EnemyTower.cs`.
/// Everything about the visual footprint — the auto-fit engage box, the HP
/// bar, the collapse animation, the reference castle artwork — is left out;
/// this models exactly what `Update()`/`SpawnWave()`/`TakeDamage()` decide,
/// which is the part a headless battle needs.
class EnemyTower {
  EnemyTower({
    required this.maxHealth,
    required this.enemyReserve,
    required this.spawnInterval,
    this.initialSpawnDelay = 0.0,
    this.spawnBatch = 2,
    this.spawnedCharacterId = 'base_enemy',
  })  : currentHealth = maxHealth,
        _spawnTimer = initialSpawnDelay > 0 ? initialSpawnDelay : 0.0;

  final int maxHealth;
  int enemyReserve;
  final double spawnInterval;
  final double initialSpawnDelay;
  final int spawnBatch;
  final String spawnedCharacterId;

  int currentHealth;
  bool alive = true;
  double _spawnTimer;
  double _freezeTimer = 0.0;

  /// One wave's worth of spawn requests, produced by [tick] when its timer
  /// elapses. The caller (the battle orchestrator) turns each into an actual
  /// `Mob` — this class only decides *when* and *how many*, matching
  /// `EnemyTower.SpawnWave()`'s reserve bookkeeping exactly, without knowing
  /// anything about how a mob is placed in the world.
  int lastWaveSpawnCount = 0;

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
