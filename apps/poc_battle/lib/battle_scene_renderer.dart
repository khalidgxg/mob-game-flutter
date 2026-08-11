import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:mobrush_sim/mobrush_sim.dart';

import 'iso.dart';
import 'sprite_atlas.dart';
import 'structure_artwork.dart';
import 'structure_renderer.dart';

/// One static structure (castle or gate) placed at a fixed lane position.
class StructurePlacement {
  const StructurePlacement.castle({
    required this.castleSpec,
    required this.image,
    required this.worldX,
    required this.worldZ,
    this.groundY = 0.5,
  })  : gateSpec = null;

  const StructurePlacement.gate({
    required this.gateSpec,
    required this.image,
    required this.worldX,
    required this.worldZ,
    this.groundY = 0.429,
  })  : castleSpec = null;

  final CastleArtworkSpec? castleSpec;
  final GateArtworkSpec? gateSpec;
  final StructureImage image;
  final double worldX;
  final double worldZ;
  final double groundY;

  double get depthKey =>
      worldZ + (castleSpec?.forwardOffsetZ ?? 0.0);
}

/// Draws the crowd and every static structure in one correctly depth-sorted
/// pass — the piece Phase 3 named and deferred ("extend it to structures and
/// props"). `CrowdRenderer` alone only ever draws mobs; this class is what a
/// real playable battle needs, where a mob must be able to walk in front of
/// or behind a castle depending on which is actually nearer the camera.
///
/// The mob sprites still go out through as few batched `drawRawAtlas` calls
/// as the interleaving requires — one call per contiguous run of mobs
/// between two structures, not one call per mob. With a handful of
/// structures per stage (2-4 towers, 2-3 gates) that is a handful of extra
/// draw calls next to the single call `CrowdRenderer` used, not a
/// per-sprite cost.
///
/// Shadows are drawn as ground decals (Phase 3's decision), one flat ellipse
/// per live mob, in the same pass immediately before that mob's sprite so
/// depth order still holds for the shadow too.
class BattleSceneRenderer extends Component {
  BattleSceneRenderer({
    required this.round,
    required this.atlas,
    required this.projection,
    required this.origin,
    List<StructurePlacement>? structures,
  }) : structures = List.of(structures ?? const [])
          ..sort((a, b) => a.depthKey.compareTo(b.depthKey));

  final BattleRound round;
  final CharacterAtlas atlas;
  final IsoProjection projection;
  final ui.Offset origin;
  final List<StructurePlacement> structures;

  static const int _capacity = 2048;
  final Float32List _transforms = Float32List(_capacity * 4);
  final Float32List _rects = Float32List(_capacity * 4);
  final Int32List _colors = Int32List(_capacity);
  final ui.Paint _spritePaint = ui.Paint();
  final ui.Paint _shadowPaint = ui.Paint()..color = const ui.Color(0x552A2A1A);

  final List<int> _order = [];

  static const int _teamBlue = 0xFF4FA3FF;
  static const int _teamRed = 0xFFFF5A4F;

  double _clock = 0;
  void advanceClock(double dt) => _clock += dt;

  int lastDrawnMobs = 0;
  int lastBatchCount = 0;

  @override
  void render(ui.Canvas canvas) {
    final mobs = round.mobs;
    _order
      ..clear()
      ..addAll(Iterable<int>.generate(mobs.length).where((i) => !mobs[i].dead));
    _order.sort((a, b) => mobs[a].z.compareTo(mobs[b].z));

    var structIdx = 0;
    var n = 0;
    var batches = 0;
    var drawn = 0;

    void flush() {
      if (n == 0) return;
      canvas.drawRawAtlas(
        atlas.image,
        Float32List.sublistView(_transforms, 0, n * 4),
        Float32List.sublistView(_rects, 0, n * 4),
        Int32List.sublistView(_colors, 0, n),
        ui.BlendMode.modulate,
        null,
        _spritePaint,
      );
      batches++;
      n = 0;
    }

    for (final i in _order) {
      final m = mobs[i];

      while (structIdx < structures.length && structures[structIdx].depthKey <= m.z) {
        flush();
        _drawStructure(canvas, structures[structIdx]);
        structIdx++;
      }

      if (n >= _capacity) flush();

      final sx = origin.dx + projection.screenX(m.x);
      final syGround = origin.dy + projection.screenY(0, m.z);
      final sy = origin.dy + projection.screenY(m.y, m.z);

      // Shadow decal: a flat ellipse at ground height under the sprite,
      // scaled with the character rather than baked into any frame, so it
      // stays correct regardless of how units overlap.
      canvas.drawOval(
        ui.Rect.fromCenter(
          center: ui.Offset(sx, syGround),
          width: atlas.frameWidth * 0.42,
          height: atlas.frameWidth * 0.20,
        ),
        _shadowPaint,
      );

      final character = m.index % atlas.characterIds.length;
      final fighting = m.combatTarget != null || m.structTarget != null;
      final phase = _clock * (fighting ? 10.0 : 12.0) + m.index * 0.37;
      final frameIndex = fighting
          ? atlas.attackFrame(character, phase.floor())
          : atlas.runFrame(character, phase.floor());
      final src = atlas.frames[frameIndex];

      const scale = 0.55;
      final o = n * 4;
      _transforms[o] = scale;
      _transforms[o + 1] = 0.0;
      _transforms[o + 2] = sx - atlas.frameWidth * scale / 2;
      _transforms[o + 3] = sy - atlas.frameHeight * scale;

      _rects[o] = src.left;
      _rects[o + 1] = src.top;
      _rects[o + 2] = src.right;
      _rects[o + 3] = src.bottom;

      _colors[n] = m.team == 0 ? _teamBlue : _teamRed;
      n++;
      drawn++;
    }

    flush();
    while (structIdx < structures.length) {
      _drawStructure(canvas, structures[structIdx]);
      structIdx++;
    }

    lastDrawnMobs = drawn;
    lastBatchCount = batches;
  }

  void _drawStructure(ui.Canvas canvas, StructurePlacement s) {
    final castle = s.castleSpec;
    if (castle != null) {
      final anchorX = origin.dx + projection.screenX(s.worldX);
      final anchorY = origin.dy +
          projection.screenY(s.groundY, s.worldZ + castle.forwardOffsetZ);
      final scale = castle.worldWidth * projection.pixelsPerUnit / castle.pixelWidth;
      final w = castle.pixelWidth * scale;
      final h = castle.pixelHeight * scale;
      canvas.drawImageRect(
        s.image.image,
        ui.Rect.fromLTWH(0, 0, castle.pixelWidth.toDouble(), castle.pixelHeight.toDouble()),
        ui.Rect.fromLTWH(anchorX - w / 2, anchorY - h * castle.groundAnchorFraction, w, h),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      return;
    }
    final gate = s.gateSpec!;
    final anchorX = origin.dx + projection.screenX(s.worldX);
    final anchorY = origin.dy + projection.screenY(s.groundY, s.worldZ);
    final w = gate.worldWidth * projection.pixelsPerUnit;
    final h = gate.worldHeight * projection.pixelsPerUnit;
    canvas.drawImageRect(
      s.image.image,
      ui.Rect.fromLTWH(0, 0, gate.pixelWidth.toDouble(), gate.pixelHeight.toDouble()),
      ui.Rect.fromLTWH(anchorX - w / 2, anchorY - h * gate.groundAnchorFraction, w, h),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
  }
}
