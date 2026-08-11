/// Metadata for the castle/tower/gate artwork, ported from
/// `Assets/Scripts/Presentation/ReferenceCastleVisual.cs` and
/// `RuntimeGateVisual.cs` rather than baked.
///
/// This is the discovery Phase 3 turned on: castles and gates in the live
/// game are **not** 3D models rendered every frame — `ReferenceCastleVisual`
/// presents them as a transparent 2D texture on a camera-facing quad,
/// rotated to exactly match `BattleCamera`'s fixed 45° pitch. A billboard
/// that always faces the same fixed-angle camera renders as an undistorted
/// flat image with no perspective foreshortening — which means the PNG
/// pixels can be used directly as a sprite in Flutter with no bake step at
/// all. Only the placement math needs porting, and every constant below
/// was read from the live source and the per-stage
/// `StagePresentationProfile` assets, not invented.
class CastleArtworkSpec {
  const CastleArtworkSpec({
    required this.assetPath,
    required this.worldWidth,
    required this.forwardOffsetZ,
    required this.visibleBottom,
    required this.pixelWidth,
    required this.pixelHeight,
  });

  /// Path under `assets/structures/...`.
  final String assetPath;

  /// World-space width in metres. Height follows the image's pixel aspect
  /// ratio — port of `BuildArtwork`'s `height = width * texture.height /
  /// texture.width`.
  final double worldWidth;

  /// Offset toward the player (+Z), on top of the tower's own authored
  /// position. Port of `mainCastleForwardOffset`/`sideCastleForwardOffset`.
  final double forwardOffsetZ;

  /// Normalized transparent padding below the opaque artwork, measured off
  /// the image's own alpha bounds. Port of `CastleVisibleBottom` — this is
  /// what keeps the castle's base planted on the ground plane instead of
  /// floating on the padding baked into the PNG.
  final double visibleBottom;

  final int pixelWidth;
  final int pixelHeight;

  double get worldHeight => worldWidth * pixelHeight / pixelWidth;

  /// Fraction of the image height, measured from the image's *top*, where
  /// the ground-contact point sits. `Image.paint`-style anchors are
  /// conventionally top-left origin, so this is `1 - visibleBottom`.
  double get groundAnchorFraction => 1.0 - visibleBottom;
}

class GateArtworkSpec {
  const GateArtworkSpec({
    required this.assetPath,
    required this.worldWidth,
    required this.worldHeight,
    required this.visibleBottom,
    required this.pixelWidth,
    required this.pixelHeight,
  });

  final String assetPath;

  /// Port of `RuntimeGateVisual.GateWidth`/`GateHeight` — authored directly,
  /// not derived from the PNG's pixel aspect (the two are close but not
  /// identical; the source authors them independently).
  final double worldWidth;
  final double worldHeight;

  /// Port of `ArtworkVisibleBottom` (0.884) — the polished gate artwork
  /// carries far more transparent padding below its posts than the castles
  /// do, which is why this constant is so much larger than the castles'
  /// ~0.01-0.23.
  final double visibleBottom;

  final int pixelWidth;
  final int pixelHeight;

  double get groundAnchorFraction => 1.0 - visibleBottom;
}

/// Which artwork a tower of [CastleRoleSpec.main]/[CastleRoleSpec.side] uses
/// for a given stage. Port of `StagePresentationProfile`'s per-stage
/// overrides, read directly from `Assets/Data/Presentation/
/// Stage_{1,2,3}_Presentation.asset` — Stage 1 has no override asset
/// entries for width/offset/visibleBottom, so it falls through to
/// `ReferenceCastleVisual`'s own script defaults (4.35/3.15, 1.25/0,
/// 0.014/0.014), exactly as the C# does.
class StageCastleArtwork {
  const StageCastleArtwork({required this.main, this.side});

  final CastleArtworkSpec main;

  /// Null for Stage 3, which authors no side-tower artwork at all
  /// (`sideCastleArtwork: {fileID: 0}`) — matching the flow document: Stage
  /// 3 has one main castle only, no side towers.
  final CastleArtworkSpec? side;
}

const stage1Castles = StageCastleArtwork(
  main: CastleArtworkSpec(
    assetPath: 'assets/structures/stage1/castle_main.png',
    worldWidth: 4.35,
    forwardOffsetZ: 1.25,
    visibleBottom: 0.014,
    pixelWidth: 507,
    pixelHeight: 640,
  ),
  side: CastleArtworkSpec(
    assetPath: 'assets/structures/stage1/castle_side.png',
    worldWidth: 3.15,
    forwardOffsetZ: 0,
    visibleBottom: 0.014,
    pixelWidth: 330,
    pixelHeight: 442,
  ),
);

const stage2Castles = StageCastleArtwork(
  main: CastleArtworkSpec(
    assetPath: 'assets/structures/stage2/castle_main.png',
    worldWidth: 5.0,
    forwardOffsetZ: 3.0,
    visibleBottom: 0.1973,
    pixelWidth: 1024,
    pixelHeight: 1536,
  ),
  side: CastleArtworkSpec(
    assetPath: 'assets/structures/stage2/castle_side.png',
    worldWidth: 4.0,
    forwardOffsetZ: 1.0,
    visibleBottom: 0.0614,
    pixelWidth: 1254,
    pixelHeight: 1254,
  ),
);

const stage3Castles = StageCastleArtwork(
  main: CastleArtworkSpec(
    assetPath: 'assets/structures/stage3/castle_main.png',
    worldWidth: 5.8,
    forwardOffsetZ: 3.0,
    visibleBottom: 0.23,
    pixelWidth: 1024,
    pixelHeight: 1536,
  ),
  side: null,
);

const gateArtwork = GateArtworkSpec(
  assetPath: 'assets/structures/gate/gate_plus20_polished.png',
  worldWidth: 6.04,
  worldHeight: 3.91,
  visibleBottom: 0.884,
  pixelWidth: 1337,
  pixelHeight: 793,
);
