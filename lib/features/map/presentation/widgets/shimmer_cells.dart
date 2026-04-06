import 'package:flutter/material.dart';

class ShimmerCells extends StatefulWidget {
  const ShimmerCells({
    super.key,
    required this.cameraPosition,
    required this.zoom,
  });

  final ({double lat, double lng}) cameraPosition;
  final double zoom;

  @override
  State<ShimmerCells> createState() => _ShimmerCellsState();
}

class _ShimmerCellsState extends State<ShimmerCells>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: _ShimmerCellsPainter(
            cameraPosition: widget.cameraPosition,
            zoom: widget.zoom,
            progress: _animation.value,
          ),
        );
      },
    );
  }
}

class _ShimmerCellsPainter extends CustomPainter {
  _ShimmerCellsPainter({
    required this.cameraPosition,
    required this.zoom,
    required this.progress,
  });

  final ({double lat, double lng}) cameraPosition;
  final double zoom;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    final cellSize = _calculateCellSize(zoom);
    final gridSize = 5;
    final offset = (progress * cellSize * 2) % (cellSize * gridSize);

    for (var i = 0; i < gridSize * 2 + 1; i++) {
      for (var j = 0; j < gridSize * 2 + 1; j++) {
        final x = centerX + (i - gridSize) * cellSize + offset - cellSize;
        final y = centerY + (j - gridSize) * cellSize + offset - cellSize;

        if (x < -cellSize || x > size.width + cellSize) continue;
        if (y < -cellSize || y > size.height + cellSize) continue;

        final shimmerAlpha = _calculateShimmerAlpha(
          x + cellSize / 2 - centerX,
          y + cellSize / 2 - centerY,
          cellSize,
          progress,
        );

        if (shimmerAlpha > 0.05) {
          final rect = RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, cellSize * 0.85, cellSize * 0.85),
            const Radius.circular(4),
          );
          canvas.drawRRect(
            rect,
            Paint()
              ..color = Colors.white.withValues(alpha: shimmerAlpha * 0.15)
              ..style = PaintingStyle.fill,
          );
        }
      }
    }
  }

  double _calculateCellSize(double zoom) {
    final metersPerPixel = 156543.03392 * _cos(0) / _pow(2, zoom);
    return (100 / metersPerPixel).clamp(20.0, 100.0);
  }

  double _cos(double deg) => _cosine(deg * 3.14159265359 / 180);
  double _cosine(double rad) {
    var result = 1.0;
    var term = 1.0;
    for (var i = 1; i <= 10; i++) {
      term *= -rad * rad / ((2 * i - 1) * (2 * i));
      result += term;
    }
    return result;
  }

  double _pow(double base, double exp) {
    var result = 1.0;
    for (var i = 0; i < exp.toInt(); i++) {
      result *= base;
    }
    return result;
  }

  double _calculateShimmerAlpha(
    double dx,
    double dy,
    double cellSize,
    double progress,
  ) {
    final centerDist = (dx * dx + dy * dy);
    final diagonal = cellSize * 5;
    final normalizedDist = centerDist / (diagonal * diagonal);
    final wavePos = progress * 2;
    final wave1 = _smoothStep(wavePos - normalizedDist);
    final wave2 = _smoothStep(wavePos - 1 - normalizedDist);
    return (wave1 - wave2).abs();
  }

  double _smoothStep(double x) {
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    return x * x * (3 - 2 * x);
  }

  @override
  bool shouldRepaint(covariant _ShimmerCellsPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.cameraPosition != cameraPosition;
  }
}
