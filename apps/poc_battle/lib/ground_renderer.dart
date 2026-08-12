import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';

import 'iso.dart';
import 'structure_renderer.dart';

/// The lane floor, drawn with the same projection the crowd uses.
///
/// [groundImage] is the real battlefield texture (`Battlefield_Ground_Tall`
/// for Stage 1, per-stage equivalents for 2/3 — the same textures
/// `Stage{1,2,3}GroundFull.mat` apply in Unity, found by tracing the
/// material's `guid` back to its source PNG). At world `y=0` — the ground
/// plane — `IsoProjection.screenY` has no `y` term left, so world→screen
/// reduces to `sx = x·ppu`, `sy = z·sin(pitch)·ppu`: a pure anisotropic
/// scale, no shear. That means the texture can be blitted with a plain
/// `canvas.scale` instead of a projected/warped quad — same reasoning
/// Phase 3 used for the billboard castle art, just on the other axis.
///
/// If [groundImage] is null (not yet loaded, or this call site predates
/// real ground art), falls back to the flat colour + depth grid this PoC
/// started with, so nothing regresses if art loading fails.
class GroundRenderer extends Component {
  GroundRenderer({
    required this.projection,
    required this.origin,
    required this.laneHalf,
    this.groundImage,
    this.viewportSize,
    this.fullBleed = false,
  });

  final IsoProjection projection;
  final ui.Offset origin;
  final double laneHalf;
  final StructureImage? groundImage;
  final Vector2? viewportSize;
  final bool fullBleed;

  static const double _nearZ = 24.0;
  static const double _farZ = -24.0;

  @override
  void render(ui.Canvas canvas) {
    final image = groundImage?.image;
    if (image != null) {
      _renderTexture(canvas, image);
    } else {
      _renderFlatFallback(canvas);
    }
  }

  void _renderTexture(ui.Canvas canvas, ui.Image image) {
    if (fullBleed && viewportSize != null) {
      final viewport = viewportSize!;
      final viewportAspect = viewport.x / viewport.y;
      final imageAspect = image.width / image.height;
      double srcWidth = image.width.toDouble();
      double srcHeight = image.height.toDouble();
      if (imageAspect > viewportAspect) {
        srcWidth = srcHeight * viewportAspect;
      } else {
        srcHeight = srcWidth / viewportAspect;
      }
      final src = ui.Rect.fromCenter(
        center: ui.Offset(image.width / 2, image.height / 2),
        width: srcWidth,
        height: srcHeight,
      );
      canvas.drawImageRect(
        image,
        src,
        ui.Rect.fromLTWH(0, 0, viewport.x, viewport.y),
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      return;
    }

    final pitch = projection.pitchDegrees * math.pi / 180.0;
    final scaleX = projection.pixelsPerUnit;
    final scaleY = projection.pixelsPerUnit * math.sin(pitch);

    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(scaleX, scaleY);

    // Cover the lane's world-space rect with the image, preserving its own
    // aspect ratio (matching Unity's tiled/fit material) rather than
    // stretching it to the rect.
    final rectWidth = laneHalf * 2;
    const rectHeight = _nearZ - _farZ;
    final imageAspect = image.width / image.height;
    final rectAspect = rectWidth / rectHeight;
    double srcW = image.width.toDouble();
    double srcH = image.height.toDouble();
    if (imageAspect > rectAspect) {
      srcW = srcH * rectAspect;
    } else {
      srcH = srcW / rectAspect;
    }
    final srcRect = ui.Rect.fromCenter(
      center: ui.Offset(image.width / 2, image.height / 2),
      width: srcW,
      height: srcH,
    );
    final dstRect = ui.Rect.fromLTWH(-laneHalf, _farZ, rectWidth, rectHeight);
    canvas.drawImageRect(image, srcRect, dstRect, ui.Paint());
    canvas.restore();
  }

  void _renderFlatFallback(ui.Canvas canvas) {
    ui.Offset p(double x, double z) => ui.Offset(
          origin.dx + projection.screenX(x),
          origin.dy + projection.screenY(0, z),
        );

    final path = ui.Path()
      ..moveTo(p(-laneHalf, _farZ).dx, p(-laneHalf, _farZ).dy)
      ..lineTo(p(laneHalf, _farZ).dx, p(laneHalf, _farZ).dy)
      ..lineTo(p(laneHalf, _nearZ).dx, p(laneHalf, _nearZ).dy)
      ..lineTo(p(-laneHalf, _nearZ).dx, p(-laneHalf, _nearZ).dy)
      ..close();

    canvas.drawPath(path, ui.Paint()..color = const ui.Color(0xFF3E4A2E));

    final line = ui.Paint()
      ..color = const ui.Color(0x223FFFFF)
      ..strokeWidth = 1.0;
    for (var z = _farZ; z <= _nearZ; z += 4.0) {
      canvas.drawLine(p(-laneHalf, z), p(laneHalf, z), line);
    }
    for (var x = -laneHalf; x <= laneHalf + 0.01; x += laneHalf / 3) {
      canvas.drawLine(p(x, _farZ), p(x, _nearZ), line);
    }
  }
}
