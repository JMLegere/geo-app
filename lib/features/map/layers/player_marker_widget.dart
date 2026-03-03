import 'package:flutter/widgets.dart';

/// Animated pulsing player location dot for the map.
///
/// Renders a pulsing outer ring in light-blue (#4FC3F7) that scales
/// from 1.0→2.0 while fading out, plus a white inner circle with a
/// blue border and drop shadow. The pulse cycles every 2 seconds.
///
/// ## Usage
///
/// ```dart
/// WidgetLayer(markers: [
///   Marker(
///     point: Position(lon, lat),
///     size: const Size(44, 44),
///     child: const PlayerMarkerWidget(size: 20),
///   ),
/// ])
/// ```
class PlayerMarkerWidget extends StatefulWidget {
  /// Diameter of the inner filled dot in logical pixels.
  final double size;

  const PlayerMarkerWidget({super.key, this.size = 20});

  @override
  State<PlayerMarkerWidget> createState() => _PlayerMarkerWidgetState();
}

class _PlayerMarkerWidgetState extends State<PlayerMarkerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.7, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Total widget area = 2.2× dot size to give the pulse ring room to expand.
    final totalSize = widget.size * 2.2;
    final innerSize = widget.size * 0.7;

    return SizedBox(
      width: totalSize,
      height: totalSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulsing ring
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF4FC3F7),
                    ),
                  ),
                ),
              );
            },
          ),
          // Inner filled dot — white with blue border and depth shadow
          Container(
            width: innerSize,
            height: innerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFFFFF),
              border: Border.all(
                color: const Color(0xFF1A73E8),
                width: 2.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x661A73E8),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
