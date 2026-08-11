import 'package:mobrush_data/mobrush_data.dart';
import 'package:mobrush_sim/mobrush_sim.dart';
import 'package:test/test.dart';

/// Real authored tuning read off the actual Shop screen (user-provided
/// screenshot, Skills tab): Freeze at 0/5 shows USES 2.0, TIME 4.0 (+12%),
/// AREA 12. Fireball at 5/5 (maxed) shows DAMAGE 90, AREA 4.6, SIEGE 240.
/// Lightning's tuning was not visible in the screenshot (locked), so its
/// tests use `AbilityTuning`'s documented defaults instead — noted per test.
const _realFreeze = AbilityTuning(charges: 2, duration: 4.0, radius: 12.0);
const _realFireballMaxed = AbilityTuning(
  charges: 5,
  radius: 4.6,
  mobDamage: 90,
  castleDamage: 240,
  minimumDamage: 5.0,
);

BattleAbilities _newAbilities({
  AbilityTuning freeze = _realFreeze,
  AbilityTuning fireball = _realFireballMaxed,
  AbilityTuning lightning = const AbilityTuning(charges: 1),
}) =>
    BattleAbilities(
      freeze: freeze,
      fireball: fireball,
      lightning: lightning,
      maxEnergy: 100,
      startingEnergy: 100,
    );

Mob _enemyMob({required double x, required double z, double hp = 20, double def = 2}) =>
    Mob(team: 1, index: 0)
      ..x = x
      ..z = z
      ..hp = hp
      ..maxHp = hp
      ..def = def
      ..phase = MobPhase.grounded;

void main() {
  group('charges gate every ability the same way', () {
    test('an ability at 0 charges refuses to fire, matching TryUse', () {
      final abilities = _newAbilities(freeze: const AbilityTuning(charges: 0));
      final result = abilities.tryUse(Ability.freeze, mobs: [_enemyMob(x: 0, z: 0)], towers: []);
      expect(result.applied, isFalse);
      expect(abilities.freezeCharges, equals(0));
    });

    test('a charge is spent only when a target is actually found', () {
      final abilities = _newAbilities();
      // No enemy mobs, no towers -- Freeze has nothing to hit.
      final result = abilities.tryUse(Ability.freeze, mobs: [], towers: []);
      expect(result.applied, isFalse);
      expect(abilities.freezeCharges, equals(2)); // unspent
    });
  });

  group('Freeze (real tuning: 2 charges, 4.0s, area 12)', () {
    test('freezes every living enemy mob and every alive tower', () {
      final abilities = _newAbilities();
      final enemy1 = _enemyMob(x: 0, z: 0);
      final enemy2 = _enemyMob(x: 1, z: 1);
      final ally = Mob(team: 0, index: 1)..phase = MobPhase.grounded; // must not freeze
      final tower = EnemyTower(maxHealth: 300, enemyReserve: 20, spawnInterval: 0.9);

      final result = abilities.tryUse(
        Ability.freeze,
        mobs: [enemy1, enemy2, ally],
        towers: [tower],
      );

      expect(result.applied, isTrue);
      expect(enemy1.isFrozen, isTrue);
      expect(enemy2.isFrozen, isTrue);
      expect(ally.isFrozen, isFalse); // team 0 is immune, per Mob.ApplyFreeze
      expect(tower.isFrozen, isTrue);
      expect(abilities.freezeCharges, equals(1));
    });

    test('a dead mob is not counted or frozen', () {
      final abilities = _newAbilities();
      final dead = _enemyMob(x: 0, z: 0)..dead = true;
      final result = abilities.tryUse(Ability.freeze, mobs: [dead], towers: []);
      expect(result.applied, isFalse);
    });
  });

  group('Fireball (real maxed tuning: 90 dmg, area 4.6, siege 240)', () {
    test(
      'targets the densest enemy cluster, dealing exactly the authored '
      'damage regardless of defence',
      () {
        final abilities = _newAbilities();
        // A cluster of 3 within 4.6, plus one lone enemy far away.
        final cluster = [
          _enemyMob(x: 0, z: 0, hp: 200, def: 10),
          _enemyMob(x: 1, z: 0, hp: 200, def: 10),
          _enemyMob(x: 2, z: 0, hp: 200, def: 10),
        ];
        final lone = _enemyMob(x: 50, z: 50, hp: 200, def: 10);

        final result = abilities.tryUse(
          Ability.fireball,
          mobs: [...cluster, lone],
          towers: [],
        );

        expect(result.applied, isTrue);
        expect(result.mobsHit, equals(3));
        // Fireball pre-compensates defence: intended damage 90, def 10 ->
        // TakeDamage(90+10) then subtracts 10 back out, netting exactly 90.
        for (final m in cluster) {
          expect(m.hp, closeTo(200 - 90, 1e-9));
        }
        expect(lone.hp, equals(200)); // untouched, outside the blast
      },
    );

    test('deals exactly 240 siege damage to a tower within the blast', () {
      final abilities = _newAbilities();
      final tower = EnemyTower(maxHealth: 1500, enemyReserve: 20, spawnInterval: 0.9, x: 0, z: 0);
      final result = abilities.tryUse(Ability.fireball, mobs: [], towers: [tower]);
      expect(result.applied, isTrue);
      expect(tower.currentHealth, equals(1500 - 240));
    });

    test('falls back to any alive tower when no enemy mob exists', () {
      final abilities = _newAbilities();
      final tower = EnemyTower(maxHealth: 1500, enemyReserve: 20, spawnInterval: 0.9, x: 5, z: 5);
      final result = abilities.tryUse(Ability.fireball, mobs: [], towers: [tower]);
      expect(result.applied, isTrue);
      expect(result.centerX, equals(5.0));
      expect(result.centerZ, equals(5.0));
    });

    test('refuses when nothing enemy exists at all', () {
      final abilities = _newAbilities();
      final ally = Mob(team: 0, index: 1)..phase = MobPhase.grounded;
      final result = abilities.tryUse(Ability.fireball, mobs: [ally], towers: []);
      expect(result.applied, isFalse);
    });
  });

  group('Lightning', () {
    test('targets the tower with the lowest health ratio, not the lowest health', () {
      final abilities = _newAbilities();
      // Tower A: 100/1000 = 10% -- lower ratio despite higher absolute HP.
      final towerA = EnemyTower(maxHealth: 1000, enemyReserve: 1, spawnInterval: 1)
        ..currentHealth = 100;
      // Tower B: 50/300 = 16.7%.
      final towerB = EnemyTower(maxHealth: 300, enemyReserve: 1, spawnInterval: 1)
        ..currentHealth = 50;

      final result = abilities.tryUse(Ability.lightning, mobs: [], towers: [towerA, towerB]);
      expect(result.applied, isTrue);
      expect(towerA.currentHealth, lessThan(100)); // A was hit
      expect(towerB.currentHealth, equals(50)); // B untouched by the direct hit
    });

    test('falls back to the furthest-advanced enemy mob when no tower is alive', () {
      final abilities = _newAbilities();
      final closer = _enemyMob(x: 0, z: 1, hp: 1000, def: 5);
      final furthestAdvanced = _enemyMob(x: 0, z: 5, hp: 1000, def: 5); // largest z
      final result = abilities.tryUse(
        Ability.lightning,
        mobs: [closer, furthestAdvanced],
        towers: [],
      );
      expect(result.applied, isTrue);
      expect(furthestAdvanced.dead, isTrue); // guaranteed-kill direct hit
      expect(closer.dead, isFalse);
    });

    test('a direct mob kill is guaranteed regardless of HP or defence', () {
      final abilities = _newAbilities();
      final tanky = _enemyMob(x: 0, z: 0, hp: 999999, def: 500);
      abilities.tryUse(Ability.lightning, mobs: [tanky], towers: []);
      expect(tanky.dead, isTrue);
    });
  });
}
