import 'dart:math' as math;

/// The projection that replaces Unity's render pipeline.
///
/// `BattleCamera.cs` frames the lane with an **orthographic** camera at a
/// **fixed 45° pitch** that never orbits. That is the entire reason this port
/// is viable: an orthographic projection with a fixed angle is a linear map
/// from world space to screen space, so it can be written out in two lines
/// instead of being computed by a GPU pipeline.
///
/// Derivation, for a camera pitched down by θ looking along +Z:
///   screen right  = world +X
///   screen up     = y·cos θ − z·sin θ
/// Sanity checks: at θ=90° (straight down) screen-up becomes −z, a top-down
/// map; at θ=0° (horizontal) it becomes y, pure elevation. Both correct.
class IsoProjection {
  const IsoProjection({this.pitchDegrees = 45.0, this.pixelsPerUnit = 26.0});

  /// Mirrors `BattleCamera.pitch`. Changing it here changes the whole look,
  /// which is exactly why the sprite bake must be shot at the same value.
  final double pitchDegrees;

  /// Mirrors what `orthographicSize` resolves to — how many screen pixels one
  /// world unit occupies. [fit] derives this the same way the live camera
  /// does; a bare constant here is only for call sites (mostly tests) that
  /// don't care about matching a real screen size.
  final double pixelsPerUnit;

  double get _pitch => pitchDegrees * math.pi / 180.0;

  double screenX(double worldX) => worldX * pixelsPerUnit;

  /// Canvas Y grows downward, so this is the negation of screen-up.
  double screenY(double worldY, double worldZ) =>
      (worldZ * math.sin(_pitch) - worldY * math.cos(_pitch)) * pixelsPerUnit;

  /// Painter's-algorithm key. Larger Z sits lower on screen and therefore
  /// nearer the camera, so ascending Z is back-to-front draw order.
  ///
  /// This single number does the job Unity's depth buffer did. It is cheaper
  /// and, for a crowd of upright billboards on flat ground, exactly as
  /// correct — there is no geometry here that can interpenetrate.
  double depthKey(double worldZ) => worldZ;

  /// Port of `BattleCamera.Apply()`'s `orthographicSize` resolution — the
  /// same fit-to-aspect logic, producing the same `pixelsPerUnit` a device
  /// with this screen size and the live game would agree on.
  ///
  /// One candidate keeps the lane width in frame; the other keeps its depth,
  /// which is foreshortened by `sin(pitch)` on the way to the screen. The
  /// larger of the two wins so neither axis is ever cropped, then a "tall
  /// portrait guard" caps how far a very tall/narrow screen is allowed to
  /// zoom out, without ever cropping the gameplay-critical width.
  factory IsoProjection.fit({
    required double screenWidth,
    required double screenHeight,
    double pitchDegrees = 45.0,
    double laneHalfWidth = 9.15,
    double minLaneDepth = 40.0,
    double criticalGameplayHalfWidth = 6.6,
    double maxPortraitOrthographicSize = 18.0,
  }) {
    final aspect = screenWidth > 0 ? screenWidth / screenHeight : 1.0;
    final rad = pitchDegrees * math.pi / 180.0;
    final sin = math.max(0.05, math.sin(rad));

    final sizeForWidth = laneHalfWidth / aspect;
    final sizeForDepth = minLaneDepth * sin * 0.5;
    final requestedSize = math.max(sizeForWidth, sizeForDepth);

    final criticalSize = math.max(1.0, criticalGameplayHalfWidth) / aspect;
    final cappedSize =
        math.min(requestedSize, math.max(1.0, maxPortraitOrthographicSize));

    final orthographicSize = math.max(criticalSize, cappedSize);

    // orthographicSize is the half-height in world units; screenHeight
    // pixels span twice that.
    final pixelsPerUnit = screenHeight / (orthographicSize * 2.0);

    return IsoProjection(pitchDegrees: pitchDegrees, pixelsPerUnit: pixelsPerUnit);
  }
}
