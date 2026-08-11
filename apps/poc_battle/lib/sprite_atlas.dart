import 'dart:math' as math;
import 'dart:ui' as ui;

/// A single texture holding every animation frame for every character.
///
/// In the real pipeline this PNG comes out of Unity: a batch script poses each
/// authored FBX in front of an orthographic 45° camera — the same angle as
/// `BattleCamera` — and captures its run and attack clips frame by frame. Six
/// characters x 2 clips x 16 frames is under 200 frames, which fits one
/// 2048x2048 sheet with room to spare.
///
/// This PoC generates a stand-in sheet procedurally instead, for one honest
/// reason: Unity cannot run in this environment, and a placeholder that is the
/// *same shape and size* as the real bake measures the same thing. What is
/// being proven here is the renderer's throughput — how many sprites can be
/// pushed from one texture per frame — and that number depends on the frame
/// count and atlas size, not on what the pixels depict.
class CharacterAtlas {
  CharacterAtlas._(this.image, this.frames, this.frameWidth, this.frameHeight);

  final ui.Image image;

  /// Source rect of every frame, flattened as [l, t, r, b] quads in the layout
  /// `drawRawAtlas` consumes directly — no per-frame Rect objects, no
  /// allocation in the render loop.
  final List<ui.Rect> frames;

  final int frameWidth;
  final int frameHeight;

  static const int runFrames = 16;
  static const int attackFrames = 8;
  static const int framesPerCharacter = runFrames + attackFrames;

  /// Matches the six authored characters in `Assets/Resources/Characters`.
  static const List<String> characters = [
    'base',
    'base_enemy',
    'monkey',
    'robot',
    'reno',
    'max',
  ];

  int runFrame(int character, int frame) =>
      character * framesPerCharacter + (frame % runFrames);

  int attackFrame(int character, int frame) =>
      character * framesPerCharacter + runFrames + (frame % attackFrames);

  /// Builds the stand-in sheet at the dimensions the real bake will use.
  static Future<CharacterAtlas> generate({
    int frameWidth = 96,
    int frameHeight = 96,
  }) async {
    final total = characters.length * framesPerCharacter;
    const columns = 16;
    final rows = (total / columns).ceil();
    final width = columns * frameWidth;
    final height = rows * frameHeight;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );

    final rects = <ui.Rect>[];
    for (var c = 0; c < characters.length; c++) {
      for (var f = 0; f < framesPerCharacter; f++) {
        final i = c * framesPerCharacter + f;
        final col = i % columns;
        final row = i ~/ columns;
        final ox = (col * frameWidth).toDouble();
        final oy = (row * frameHeight).toDouble();

        final isAttack = f >= runFrames;
        final phase = isAttack
            ? (f - runFrames) / attackFrames
            : f / runFrames;

        canvas.save();
        canvas.translate(ox, oy);
        canvas.clipRect(
          ui.Rect.fromLTWH(0, 0, frameWidth.toDouble(), frameHeight.toDouble()),
        );
        _drawFigure(
          canvas,
          frameWidth.toDouble(),
          frameHeight.toDouble(),
          phase,
          isAttack,
          c,
        );
        canvas.restore();

        rects.add(
          ui.Rect.fromLTWH(
            ox,
            oy,
            frameWidth.toDouble(),
            frameHeight.toDouble(),
          ),
        );
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    picture.dispose();
    return CharacterAtlas._(image, rects, frameWidth, frameHeight);
  }

  /// A crude articulated figure. Deliberately drawn in flat white so the
  /// renderer can tint it per team at draw time — the same trick that replaces
  /// `MobAnim.applyTint`, and the reason team colour costs zero extra texture.
  static void _drawFigure(
    ui.Canvas canvas,
    double w,
    double h,
    double phase,
    bool attack,
    int character,
  ) {
    final paint = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
    final dark = ui.Paint()..color = const ui.Color(0xFFBFBFBF);

    // Slight per-character size variation, standing in for the roster's real
    // silhouettes (Max is a giant, Monkey is small).
    final scale = [1.0, 1.0, 0.85, 1.05, 1.0, 1.35][character];
    final cx = w / 2;
    final groundY = h * 0.92;
    final bodyH = h * 0.42 * scale;
    final headR = h * 0.11 * scale;

    final swing = math.sin(phase * math.pi * 2);
    final bob = attack ? 0.0 : math.sin(phase * math.pi * 4).abs() * h * 0.02;

    final hipY = groundY - bodyH - bob;
    final shoulderY = hipY - bodyH * 0.55;

    // Legs — a two-frame stride is enough to read as running at crowd scale.
    final legSpread = w * 0.11 * scale * swing;
    for (final s in [1.0, -1.0]) {
      canvas.drawLine(
        ui.Offset(cx, hipY),
        ui.Offset(cx + legSpread * s, groundY - bob * 0.5),
        ui.Paint()
          ..color = const ui.Color(0xFFD8D8D8)
          ..strokeWidth = w * 0.075 * scale
          ..strokeCap = ui.StrokeCap.round,
      );
    }

    // Torso.
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        ui.Rect.fromLTRB(
          cx - w * 0.10 * scale,
          shoulderY,
          cx + w * 0.10 * scale,
          hipY,
        ),
        ui.Radius.circular(w * 0.05 * scale),
      ),
      paint,
    );

    // Arms — the attack clip throws one arm forward instead of swinging.
    final armSwing = attack
        ? w * 0.28 * scale * math.sin(phase * math.pi)
        : w * 0.10 * scale * -swing;
    canvas.drawLine(
      ui.Offset(cx, shoulderY + h * 0.02),
      ui.Offset(cx + armSwing, shoulderY + h * 0.12 * scale),
      ui.Paint()
        ..color = const ui.Color(0xFFE8E8E8)
        ..strokeWidth = w * 0.06 * scale
        ..strokeCap = ui.StrokeCap.round,
    );

    // Head.
    canvas.drawCircle(ui.Offset(cx, shoulderY - headR * 0.8), headR, paint);
    canvas.drawCircle(
      ui.Offset(cx, shoulderY - headR * 0.8),
      headR * 0.55,
      dark,
    );
  }
}
