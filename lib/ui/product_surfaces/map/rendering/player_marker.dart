import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/features/map/domain/entities/player_marker_state.dart';
import 'package:earth_nova/features/map/presentation/providers/player_marker_provider.dart';

enum PlayerMarkerTrust { trusted, lowConfidence, paused }

bool playerMarkerShowsRing(PlayerMarkerState state, PlayerMarkerTrust trust) =>
    state.isRing || trust != PlayerMarkerTrust.trusted;

class PlayerMarker extends ConsumerStatefulWidget {
  const PlayerMarker({super.key, required this.trust});

  final PlayerMarkerTrust trust;

  @override
  ConsumerState<PlayerMarker> createState() => _PlayerMarkerState();
}

class _PlayerMarkerState extends ConsumerState<PlayerMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _ringAnimation;
  bool _initialized = false;

  static const _animDuration = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _animDuration);
    _ringAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized && MediaQuery.disableAnimationsOf(context)) {
      _controller.value = _showRing(ref.read(playerMarkerProvider)) ? 1 : 0;
    }
  }

  @override
  void didUpdateWidget(PlayerMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trust != widget.trust) {
      _setRingVisibility(_showRing(ref.read(playerMarkerProvider)));
    }
  }

  bool _showRing(PlayerMarkerState state) =>
      playerMarkerShowsRing(state, widget.trust);

  void _setRingVisibility(bool visible) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = visible ? 1 : 0;
    } else if (visible) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _onStateChanged(PlayerMarkerState? previous, PlayerMarkerState next) {
    if (previous != null && _showRing(previous) == _showRing(next)) return;
    _setRingVisibility(_showRing(next));
  }

  @override
  Widget build(BuildContext context) {
    final markerState = ref.watch(playerMarkerProvider);
    final showRing = _showRing(markerState);
    if (!_initialized) {
      _controller.value = showRing ? 1 : 0;
      _initialized = true;
    }

    ref.listen<PlayerMarkerState>(playerMarkerProvider, _onStateChanged);

    final colorScheme = Theme.of(context).colorScheme;
    final semanticLabel = switch (widget.trust) {
      PlayerMarkerTrust.trusted => 'Player location trusted',
      PlayerMarkerTrust.lowConfidence => 'Player location low confidence',
      PlayerMarkerTrust.paused => 'Player location paused',
    };
    return Semantics(
      container: true,
      label: semanticLabel,
      child: AnimatedBuilder(
        animation: _ringAnimation,
        builder: (context, _) {
          return CustomPaint(
            size: const Size(48, 48),
            painter: _PlayerMarkerPainter(
              ringTransition: _ringAnimation.value,
              gapDistance: markerState.gapDistance,
              strongColor: colorScheme.onSurface,
              mutedColor: colorScheme.onSurfaceVariant,
              contrastColor: colorScheme.surface,
            ),
          );
        },
      ),
    );
  }
}

class _PlayerMarkerPainter extends CustomPainter {
  const _PlayerMarkerPainter({
    required this.ringTransition,
    required this.gapDistance,
    required this.strongColor,
    required this.mutedColor,
    required this.contrastColor,
  });

  final double ringTransition;
  final double gapDistance;
  final Color strongColor;
  final Color mutedColor;
  final Color contrastColor;

  static const _iconRadius = 10.0;
  static const _maxRingRadius = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    if (ringTransition > 0) {
      _drawRing(canvas, center);
    }
    _drawCenterMarker(canvas, center);
  }

  void _drawCenterMarker(Canvas canvas, Offset center) {
    final fill = Paint()
      ..color = Color.lerp(strongColor, mutedColor, ringTransition)!
      ..style = PaintingStyle.fill;
    final border = Paint()
      ..color = contrastColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    final dot = Paint()
      ..color = contrastColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, _iconRadius, fill);
    canvas.drawCircle(center, _iconRadius, border);
    canvas.drawCircle(center, 3, dot);
  }

  void _drawRing(Canvas canvas, Offset center) {
    final ringRadius =
        _iconRadius + (_maxRingRadius - _iconRadius) * ringTransition;
    final fill = Paint()
      ..color = mutedColor.withValues(alpha: 0.18 * ringTransition)
      ..style = PaintingStyle.fill;
    final halo = Paint()
      ..color = contrastColor.withValues(alpha: 0.92 * ringTransition)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    final border = Paint()
      ..color = mutedColor.withValues(alpha: 0.86 * ringTransition)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, ringRadius, fill);
    canvas.drawCircle(center, ringRadius, halo);
    canvas.drawCircle(center, ringRadius, border);
  }

  @override
  bool shouldRepaint(_PlayerMarkerPainter oldDelegate) =>
      oldDelegate.ringTransition != ringTransition ||
      oldDelegate.gapDistance != gapDistance ||
      oldDelegate.strongColor != strongColor ||
      oldDelegate.mutedColor != mutedColor ||
      oldDelegate.contrastColor != contrastColor;
}
