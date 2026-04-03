import 'package:flutter/widgets.dart';

/// Animated circular marker representing the player on the map.
///
/// Renders a pulsing ring and a solid centre dot. Designed to be placed
/// inside a [WidgetLayer] marker via [PlayerMarkerLayer].
class PlayerMarkerWidget extends StatelessWidget {
  /// Outer diameter of the marker in logical pixels.
  final double size;

  const PlayerMarkerWidget({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 2.2,
      height: size * 2.2,
      child: CustomPaint(painter: _MarkerPainter(size: size)),
    );
  }
}

class _MarkerPainter extends CustomPainter {
  final double size;
  _MarkerPainter({required this.size});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final cx = canvasSize.width / 2;
    final cy = canvasSize.height / 2;

    // Outer glow ring
    final ringPaint = Paint()
      ..color = const Color(0x40448AFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(cx, cy), size * 0.9, ringPaint);

    // White border
    final borderPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), size * 0.55, borderPaint);

    // Solid blue centre
    final dotPaint = Paint()
      ..color = const Color(0xFF448AFF)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), size * 0.4, dotPaint);
  }

  @override
  bool shouldRepaint(_MarkerPainter old) => old.size != size;
}
