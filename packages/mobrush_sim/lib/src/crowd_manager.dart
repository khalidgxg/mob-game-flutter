import 'dart:math' as math;

import 'combat_limits.dart';
import 'mob.dart';

/// Builds a spatial hash of grounded, living mobs each frame and computes, per
/// mob: separation (lateral push so the crowd flows like a fluid) and clash
/// (a player + enemy mob touching lock into melee).
///
/// Port of `Assets/Scripts/Gameplay/CrowdManager.cs`. The published result is a
/// *direction influence* with magnitude 0..1 — never units per second.
///
/// The one structural change from the C# is the grid key: `Vector2Int` becomes
/// a packed `int`. Dart has no value-type structs, so a class key would
/// allocate on every lookup and force a hashCode/== call per probe; packing the
/// cell coordinates into a single int makes the key free and lets the Map use
/// identity-cheap integer hashing. Same cells, same neighbours, no garbage.
class CrowdManager {
  CrowdManager();

  /// Distance at which mobs push away from each other to prevent overcrowding.
  double separationRadius = 0.72;

  /// Strength of the lateral push force between friendly mobs.
  double separationStrength = 7.0;

  /// Melee engagement distance where opposite team mobs clash.
  double clashRadius = 0.40;

  /// How completely a mob commits to an enemy inside its seek range.
  double seekWeight = 0.85;

  /// Steering total that counts as full authority.
  double maxSteerForce = 6.0;

  /// How much closer a rival target must be before a mob drops the one it is
  /// already walking to. Zero re-picks every frame, which in a dense crowd
  /// means never actually reaching any of them.
  double targetStickiness = 0.25;

  /// How far off its line of march a target may sit and still be worth walking
  /// to. Zero was too generous: a target at a right angle passed, then owned
  /// almost all of the unit's steering while contributing nothing forward.
  static const double minForwardSeek = 0.25;

  static const double cell = 0.85;

  final Map<int, List<Mob>> _grid = {};
  final List<List<Mob>> _pool = [];
  double _largestPersonalSpace = 0;

  /// Cell coordinates are packed into one int. Dart ints are 64-bit on native,
  /// so 21 bits per axis (±1M cells ≈ ±890 km of lane) is far beyond anything
  /// the game can produce, and the pack stays exact.
  static int _key(int cx, int cz) => ((cx + 0x100000) << 21) | (cz + 0x100000);

  /// Diagnostic counter: how many neighbour pairs the last [update] examined.
  /// This is the number that actually decides whether the crowd scales, so it
  /// is measured rather than assumed.
  int lastPairChecks = 0;

  void update(List<Mob> mobs) {
    // Reset grid, recycling the inner lists.
    for (final list in _grid.values) {
      list.clear();
      _pool.add(list);
    }
    _grid.clear();
    _largestPersonalSpace = separationRadius;
    lastPairChecks = 0;

    // Populate the hash with grounded, living mobs.
    for (var i = 0; i < mobs.length; i++) {
      final m = mobs[i];
      if (m.dead || m.phase != MobPhase.grounded) continue;
      if (m.crowdSeparationRadius > _largestPersonalSpace) {
        _largestPersonalSpace = m.crowdSeparationRadius;
      }
      final key = _key((m.x / cell).floor(), (m.z / cell).floor());
      var list = _grid[key];
      if (list == null) {
        list = _pool.isNotEmpty ? _pool.removeLast() : <Mob>[];
        _grid[key] = list;
      }
      list.add(m);
    }

    // Separation + clash.
    for (var i = 0; i < mobs.length; i++) {
      final m = mobs[i];
      if (m.dead || m.phase != MobPhase.grounded) continue;

      final px = m.x, pz = m.z;
      final cx = (px / cell).floor();
      final cz = (pz / cell).floor();
      final seekRadius =
          m.seekRange.clamp(clashRadius, CombatLimits.maxSeekRange);
      final queryRadius = math.max(seekRadius, _largestPersonalSpace);
      final seekCells = (queryRadius / cell).ceil();

      double sepX = 0, sepZ = 0;
      double seekX = 0, seekZ = 0;
      Mob? seekTarget;
      var nearestEnemyDist = double.maxFinite;
      var clashed = false;
      final advanceZ = m.advanceDirZ;

      for (var ox = -seekCells; ox <= seekCells && !clashed; ox++) {
        for (var oz = -seekCells; oz <= seekCells && !clashed; oz++) {
          final cellList = _grid[_key(cx + ox, cz + oz)];
          if (cellList == null) continue;
          for (var k = 0; k < cellList.length; k++) {
            final other = cellList[k];
            if (identical(other, m) || other.dead) continue;
            lastPairChecks++;

            final diffX = px - other.x;
            final diffZ = pz - other.z;
            final d = math.sqrt(diffX * diffX + diffZ * diffZ);

            // Size-aware, not flat: separation pushes opponents apart from
            // 0.72, so a fixed 0.40 fighting sphere around a large unit's
            // centre can never be reached. That is why crowds slid around Max.
            final clash = CombatLimits.clashDistance(
              clashRadius,
              m.bodySurplus,
              other.bodySurplus,
            );
            if (m.team != other.team && d < clash) {
              m.fight(other);
              other.fight(m);
              clashed = true;
              break;
            }

            if (d < 0.0001) {
              // Same-team units on one point need a stable sideways
              // tie-breaker. Never inject Z here: that is what made large
              // units turn back up the lane.
              if (m.team == other.team) {
                sepX += m.index < other.index ? -1.0 : 1.0;
              }
              continue;
            }

            if (m.team != other.team && d < seekRadius) {
              final towardX = -diffX / d;
              final towardZ = -diffZ / d;

              // A target that has slipped behind is never worth turning around
              // for. Two crowds walk through each other constantly, so the
              // nearest enemy flips from front to back every few frames, and a
              // mob that obeys the flip rocks on the spot instead of
              // advancing. Contact still starts a fight either way.
              if (towardZ * advanceZ >= minForwardSeek) {
                // Hysteresis, so the choice survives a rival a few centimetres
                // closer this frame.
                final ranked = identical(other, m.seekTarget)
                    ? d * (1.0 - targetStickiness)
                    : d;
                if (ranked < nearestEnemyDist) {
                  nearestEnemyDist = ranked;
                  seekX = towardX;
                  seekZ = towardZ;
                  seekTarget = other;
                }
              }
            }

            // A character's large personal space is only for allies. Opponents
            // keep the shared close-range spacing so a giant approaches and
            // fights them instead of detouring around.
            final pairSeparationRadius = m.team == other.team
                ? math.max(
                    separationRadius,
                    math.max(
                      m.crowdSeparationRadius,
                      other.crowdSeparationRadius,
                    ),
                  )
                : separationRadius;
            if (d < pairSeparationRadius) {
              // Separation is intentionally lateral. The lane axis is owned by
              // marching and seeking; pushing it here makes large mobs loop,
              // retreat, or bypass a fight.
              final side = diffX.abs() > 0.0001
                  ? (diffX > 0 ? 1.0 : -1.0)
                  : (m.index < other.index ? -1.0 : 1.0);
              sepX += side * (1.0 - d / pairSeparationRadius);
            }
          }
        }
      }

      // A mob that just locked into melee holds its ground. Skipping the write
      // instead left it carrying the steer from the frame *before* contact — a
      // frozen vector re-applied for the whole duel, which walked duellists out
      // of the disengage band and read as a unit fleeing a fight it started.
      if (clashed) {
        m.steerX = 0;
        m.steerZ = 0;
        m.seekDirX = 0;
        m.seekDirZ = 0;
        m.seekTarget = null;
        continue;
      }

      // Separation and seeking are published separately because they are
      // different kinds of instruction. Separation shares the lane out between
      // neighbours; seeking is a decision to go and fight something, and
      // folding them together let a crowd walk past an enemy it had spotted.
      sepX *= separationStrength;
      sepZ *= separationStrength;
      final force = math.sqrt(sepX * sepX + sepZ * sepZ);
      if (force <= 0.0001) {
        m.steerX = 0;
        m.steerZ = 0;
      } else if (force >= maxSteerForce) {
        m.steerX = sepX / force;
        m.steerZ = sepZ / force;
      } else {
        m.steerX = sepX / maxSteerForce;
        m.steerZ = sepZ / maxSteerForce;
      }

      m.seekDirX = seekX * seekWeight;
      m.seekDirZ = seekZ * seekWeight;
      m.seekTarget = seekTarget;
    }
  }
}
