import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:mobrush_sim/mobrush_sim.dart';

import 'ground_renderer.dart';
import 'iso.dart';
import 'structure_artwork.dart';
import 'structure_renderer.dart';

/// Phase 3's visual-approval scene: Stage 1's real castle and gate artwork,
/// placed at their real authored lane positions, with no baking involved —
/// see `structure_artwork.dart` for why none was needed. Separate from
/// `BattleGame` on purpose: that scene is tuned and already measured for the
/// crowd performance gate, and this one exists only to be looked at.
class StructurePreviewGame extends FlameGame {
  final IsoProjection projection = const IsoProjection(pitchDegrees: 45.0);

  @override
  Future<void> onLoad() async {
    final origin = ui.Offset(size.x / 2, size.y * 0.66);

    add(
      GroundRenderer(projection: projection, origin: origin, laneHalf: Mob.laneHalf),
    );

    // Real Stage 1 tower lane positions, per Assets/Data/Stages/Stage_1.asset
    // and the flow document: side towers flank the main castle, further down
    // the lane (more negative Z) than the gates a player mob would cross
    // first.
    final mainImage = await StructureImage.load(stage1Castles.main.assetPath);
    add(
      CastleSprite(
        spec: stage1Castles.main,
        image: mainImage,
        projection: projection,
        origin: origin,
        worldX: 0,
        worldZ: -12.0,
      ),
    );

    final sideSpec = stage1Castles.side;
    if (sideSpec != null) {
      final sideImage = await StructureImage.load(sideSpec.assetPath);
      add(
        CastleSprite(
          spec: sideSpec,
          image: sideImage,
          projection: projection,
          origin: origin,
          worldX: -5.25,
          worldZ: -8.0,
        ),
      );
      add(
        CastleSprite(
          spec: sideSpec,
          image: sideImage,
          projection: projection,
          origin: origin,
          worldX: 5.25,
          worldZ: -8.0,
        ),
      );
    }

    final gateImage = await StructureImage.load(gateArtwork.assetPath);
    add(
      GateSprite(
        spec: gateArtwork,
        image: gateImage,
        projection: projection,
        origin: origin,
        worldX: 0,
        worldZ: -2.5,
      ),
    );
  }
}
