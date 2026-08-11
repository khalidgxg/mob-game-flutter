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
  /// world unit occupies. The real camera derives this from the live aspect so
  /// the same lane width is always framed; this PoC takes it as a constant.
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
}
