import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:mobrush_sim/mobrush_sim.dart';

import 'iso.dart';
import 'sprite_atlas.dart';

/// Draws the entire crowd in a single batched call.
///
/// This is the load-bearing decision of the whole renderer, so it is worth
/// being explicit about the alternative that was rejected. The obvious Flame
/// approach is one `SpriteAnimationComponent` per mob: 350 components, each
/// with its own transform, its own animation ticker, and its own draw call.
/// That works, and it is what most Flame samples do — but it puts 350 objects
/// through the component tree every frame and issues 350 separate draws.
///
/// `Canvas.drawRawAtlas` instead takes flat `Float32List`s describing every
/// sprite's transform and source rect and submits them as one operation. The
/// GPU sees one texture and one batch. Cost stops scaling with the number of
/// units in any way the player would notice, and the buffers are allocated
/// once and overwritten in place, so a full crowd frame allocates nothing.
///
/// The comment in `MobAnim.cs` asks for exactly this: "One graph per mob (fine
/// for a first pass; swap to a shared/GPU solution if the crowd gets huge)."
class CrowdRenderer extends Component {
  CrowdRenderer({
    required this.sim,
    required this.atlas,
    required this.projection,
    required this.origin,
  });

  final BattleSim sim;
  final CharacterAtlas atlas;
  final IsoProjection projection;

  /// Where world (0,0,0) lands on the canvas.
  final ui.Offset origin;

  static const int _capacity = 2048;

  // Four floats per sprite: [scaledCos, scaledSin, translateX, translateY].
  final Float32List _transforms = Float32List(_capacity * 4);

  // Four floats per sprite: the source rect [l, t, r, b].
  final Float32List _rects = Float32List(_capacity * 4);

  // One packed ARGB per sprite — this is how team colour is applied without a
  // second texture, replacing `MobAnim.applyTint`.
  final Int32List _colors = Int32List(_capacity);

  final ui.Paint _paint = ui.Paint();

  /// Reusable draw order. Sorting indices rather than the mob list keeps the
  /// simulation's own ordering stable, which matters because `Mob.index` is
  /// the tie-breaker the crowd solve uses.
  final List<int> _order = [];

  static const int _teamBlue = 0xFF4FA3FF;
  static const int _teamRed = 0xFFFF5A4F;

  int lastDrawn = 0;

  /// Animation clock. One shared timeline with a per-mob phase offset gives
  /// every unit an independent-looking stride without per-mob state.
  double _clock = 0;

  void advanceClock(double dt) => _clock += dt;

  @override
  void render(ui.Canvas canvas) {
    final mobs = sim.mobs;

    _order
      ..clear()
      ..addAll(Iterable<int>.generate(mobs.length));
    // Painter's algorithm: back to front. One sort of an int list per frame is
    // cheap next to what a depth buffer would cost to emulate.
    _order.sort((a, b) => mobs[a].z.compareTo(mobs[b].z));

    var n = 0;
    for (final i in _order) {
      if (n >= _capacity) break;
      final m = mobs[i];
      if (m.dead) continue;

      final character = m.index % CharacterAtlas.characters.length;
      final fighting = m.combatTarget != null;

      // A per-mob phase offset derived from its stable index — no random
      // state to store, and identical across runs, which keeps the render
      // deterministic alongside the simulation.
      final phase = _clock * (fighting ? 10.0 : 12.0) + m.index * 0.37;
      final frameIndex = fighting
          ? atlas.attackFrame(character, phase.floor())
          : atlas.runFrame(character, phase.floor());
      final src = atlas.frames[frameIndex];

      final sx = origin.dx + projection.screenX(m.x);
      final sy = origin.dy + projection.screenY(m.y, m.z);

      // Sprites are billboards: no rotation, uniform scale. That makes the
      // RSTransform a scale and a translation, which is why it can be written
      // straight into the buffer without building an object.
      const scale = 0.55;
      final o = n * 4;
      _transforms[o] = scale; // scaledCos
      _transforms[o + 1] = 0.0; // scaledSin
      _transforms[o + 2] = sx - atlas.frameWidth * scale / 2;
      _transforms[o + 3] = sy - atlas.frameHeight * scale;

      _rects[o] = src.left;
      _rects[o + 1] = src.top;
      _rects[o + 2] = src.right;
      _rects[o + 3] = src.bottom;

      _colors[n] = m.team == 0 ? _teamBlue : _teamRed;
      n++;
    }

    lastDrawn = n;
    if (n == 0) return;

    canvas.drawRawAtlas(
      atlas.image,
      Float32List.sublistView(_transforms, 0, n * 4),
      Float32List.sublistView(_rects, 0, n * 4),
      Int32List.sublistView(_colors, 0, n),
      ui.BlendMode.modulate,
      null,
      _paint,
    );
  }
}
