import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/features/map/domain/entities/player_marker_state.dart';
import 'package:earth_nova/features/map/presentation/providers/player_marker_provider.dart';

class PlayerMarker extends ConsumerStatefulWidget {
  const PlayerMarker({super.key});

  @override
  ConsumerState<PlayerMarker> createState() => _PlayerMarkerState();
}

class _PlayerMarkerState extends ConsumerState<PlayerMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _dissolveAnimation;

  static const _animDuration = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _animDuration);
    _dissolveAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onStateChanged(PlayerMarkerState? previous, PlayerMarkerState next) {
    if (previous?.isRing == next.isRing) return;
    if (next.isRing) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final markerState = ref.watch(playerMarkerProvider);

    ref.listen<PlayerMarkerState>(playerMarkerProvider, _onStateChanged);

    return AnimatedBuilder(
      animation: _dissolveAnimation,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(48, 48),
          painter: _PlayerMarkerPainter(
            dissolve: _dissolveAnimation.value,
            gapDistance: markerState.gapDistance,
          ),
        );
      },
    );
  }
}

class _PlayerMarkerPainter extends CustomPainter {
  const _PlayerMarkerPainter({
    required this.dissolve,
    required this.gapDistance,
  });

  final double dissolve;
  final double gapDistance;

  static const _iconColor = Color(0xFF4CAF50);
  static const _ringColor = Color(0x884CAF50);
  static const _iconRadius = 10.0;
  static const _maxRingRadius = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    if (dissolve < 1.0) {
      _drawIcon(canvas, center, opacity: 1.0 - dissolve);
    }

    if (dissolve > 0.0) {
      _drawRing(canvas, center, opacity: dissolve);
    }
  }

  void _drawIcon(Canvas canvas, Offset center, {required double opacity}) {
    final paint = Paint()
      ..color = _iconColor.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawCircle(center, _iconRadius, paint);
    canvas.drawCircle(center, _iconRadius, borderPaint);

    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3.0, dotPaint);
  }

  void _drawRing(Canvas canvas, Offset center, {required double opacity}) {
    final ringRadius = _iconRadius + (_maxRingRadius - _iconRadius) * dissolve;

    final ringPaint = Paint()
      ..color = _ringColor.withValues(alpha: opacity * 0.5)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = _iconColor.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(center, ringRadius, ringPaint);
    canvas.drawCircle(center, ringRadius, borderPaint);
  }

  @override
  bool shouldRepaint(_PlayerMarkerPainter oldDelegate) =>
      oldDelegate.dissolve != dissolve ||
      oldDelegate.gapDistance != gapDistance;
}
