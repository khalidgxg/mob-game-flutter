import 'dart:ui' as ui;

import 'package:flame/components.dart';

import 'iso.dart';

/// The lane floor, drawn with the same projection the crowd uses.
///
/// Its only job in this PoC is to prove the projection is coherent: if the
/// ground quad and the units disagree about where the world is, units drift
/// off the floor as they walk. It is four corners through the same two
/// functions, which is the point — the entire "3D" of the scene is those two
/// functions.
class GroundRenderer extends Component {
  GroundRenderer({
    required this.projection,
    required this.origin,
    required this.laneHalf,
  });

  final IsoProjection projection;
  final ui.Offset origin;
  final double laneHalf;

  static const double _nearZ = 24.0;
  static const double _farZ = -24.0;

  @override
  void render(ui.Canvas canvas) {
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

    // Depth grid — makes it obvious at a glance whether units are tracking the
    // floor or sliding across it.
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
