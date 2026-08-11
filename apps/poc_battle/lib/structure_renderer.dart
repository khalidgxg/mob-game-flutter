import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'iso.dart';
import 'structure_artwork.dart';

/// Loads a real (not baked) artwork PNG once and keeps its decoded image.
class StructureImage {
  const StructureImage._(this.image);

  final ui.Image image;

  static Future<StructureImage> load(String assetPath) async {
    final bytes = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return StructureImage._(frame.image);
  }
}

/// Draws one castle/tower artwork quad exactly the way
/// `ReferenceCastleVisual.BuildArtwork` places it: a camera-facing billboard
/// at `(towerX, groundY, towerZ + forwardOffsetZ)`, sized to [spec]'s
/// authored world width with height following the image's own pixel aspect,
/// vertically anchored at [CastleArtworkSpec.groundAnchorFraction] rather
/// than the image's bottom edge — the padding baked into these PNGs is real,
/// not a bug to crop around.
///
/// Because the artwork always faces this scene's one fixed-angle camera, it
/// draws as an undistorted flat rectangle — no perspective warp, no
/// projected quad corners. That is Phase 3's actual finding: this asset
/// needed no bake step at all, only its placement math ported.
class CastleSprite extends Component {
  CastleSprite({
    required this.spec,
    required this.image,
    required this.projection,
    required this.origin,
    required this.worldX,
    required this.worldZ,
    this.groundY = 0.5,
  });

  final CastleArtworkSpec spec;
  final StructureImage image;
  final IsoProjection projection;
  final ui.Offset origin;
  final double worldX;
  final double worldZ;
  final double groundY;

  double get depthKey => projection.depthKey(worldZ + spec.forwardOffsetZ);

  @override
  void render(ui.Canvas canvas) {
    final anchorX = origin.dx + projection.screenX(worldX);
    final anchorY =
        origin.dy + projection.screenY(groundY, worldZ + spec.forwardOffsetZ);

    final scale = spec.worldWidth * projection.pixelsPerUnit / spec.pixelWidth;
    final drawWidth = spec.pixelWidth * scale;
    final drawHeight = spec.pixelHeight * scale;

    final left = anchorX - drawWidth / 2;
    final top = anchorY - drawHeight * spec.groundAnchorFraction;

    canvas.drawImageRect(
      image.image,
      ui.Rect.fromLTWH(0, 0, spec.pixelWidth.toDouble(), spec.pixelHeight.toDouble()),
      ui.Rect.fromLTWH(left, top, drawWidth, drawHeight),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
  }
}

/// Same idea as [CastleSprite] but for the gate artwork, whose world size is
/// authored directly ([GateArtworkSpec.worldWidth]/`worldHeight`) rather than
/// derived from the image's pixel aspect — port of `RuntimeGateVisual`'s
/// `GateWidth`/`GateHeight` constants, which are close to but not identical
/// to the PNG's own aspect ratio.
class GateSprite extends Component {
  GateSprite({
    required this.spec,
    required this.image,
    required this.projection,
    required this.origin,
    required this.worldX,
    required this.worldZ,
    this.groundY = 0.429,
  });

  final GateArtworkSpec spec;
  final StructureImage image;
  final IsoProjection projection;
  final ui.Offset origin;
  final double worldX;
  final double worldZ;
  final double groundY;

  double get depthKey => projection.depthKey(worldZ);

  @override
  void render(ui.Canvas canvas) {
    final anchorX = origin.dx + projection.screenX(worldX);
    final anchorY = origin.dy + projection.screenY(groundY, worldZ);

    final drawWidth = spec.worldWidth * projection.pixelsPerUnit;
    final drawHeight = spec.worldHeight * projection.pixelsPerUnit;

    final left = anchorX - drawWidth / 2;
    final top = anchorY - drawHeight * spec.groundAnchorFraction;

    canvas.drawImageRect(
      image.image,
      ui.Rect.fromLTWH(0, 0, spec.pixelWidth.toDouble(), spec.pixelHeight.toDouble()),
      ui.Rect.fromLTWH(left, top, drawWidth, drawHeight),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
  }
}
