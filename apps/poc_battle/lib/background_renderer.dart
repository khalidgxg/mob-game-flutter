import 'dart:ui' as ui;

import 'package:flame/components.dart';

/// Fills the whole canvas behind the lane with a simple sky-to-ground
/// gradient wash, so the area outside `GroundRenderer`'s lane quad reads as
/// an unfinished horizon instead of dead black letterboxing. No new art:
/// this is a two-stop gradient using the same ground tone `GroundRenderer`
/// already paints the lane with, which is the honest placeholder until Home
/// gets real background art.
class BackgroundRenderer extends Component {
  BackgroundRenderer({required this.size});

  final Vector2 size;

  @override
  int get priority => -10;

  @override
  void render(ui.Canvas canvas) {
    final rect = ui.Rect.fromLTWH(0, 0, size.x, size.y);
    final gradient = ui.Gradient.linear(
      const ui.Offset(0, 0),
      ui.Offset(0, size.y),
      const [
        ui.Color(0xFF0B1A2E), // dusk sky
        ui.Color(0xFF1E2E1E), // fades toward the ground tone
        ui.Color(0xFF3E4A2E), // matches GroundRenderer's lane fill
      ],
      const [0.0, 0.55, 1.0],
    );
    canvas.drawRect(rect, ui.Paint()..shader = gradient);
  }
}
