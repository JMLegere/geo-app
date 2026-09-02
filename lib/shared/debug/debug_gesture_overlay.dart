import 'package:flutter/material.dart';
import 'package:earth_nova/shared/debug/gesture_injector.dart';

// ─── Interface ────────────────────────────────────────────────────────────────
abstract interface class GestureInjectorInterface {
  Future<void> swipeUp(Offset center, double distance);
  Future<void> swipeDown(Offset center, double distance);
  Future<void> swipeLeft(Offset center, double distance);
  Future<void> swipeRight(Offset center, double distance);
  Future<void> pinch(Offset center, double distance);
  Future<void> spread(Offset center, double distance);
}

enum DebugPlayerMoveDirection { north, south, west, east }

// ─── Default injector ─────────────────────────────────────────────────────────
// Uses Flutter pointer injection — works on all Flutter widget trees.
// Swipe events do not reach the MapLibre WebGL canvas on the map screen;
// they work correctly on all other screens (Pack, Sanctuary, Settings).
class _DefaultInjector implements GestureInjectorInterface {
  const _DefaultInjector();

  @override
  Future<void> swipeUp(Offset center, double distance) =>
      GestureInjector.swipe(center, Offset(center.dx, center.dy - distance));
  @override
  Future<void> swipeDown(Offset center, double distance) =>
      GestureInjector.swipe(center, Offset(center.dx, center.dy + distance));
  @override
  Future<void> swipeLeft(Offset center, double distance) =>
      GestureInjector.swipe(center, Offset(center.dx - distance, center.dy));
  @override
  Future<void> swipeRight(Offset center, double distance) =>
      GestureInjector.swipe(center, Offset(center.dx + distance, center.dy));
  @override
  Future<void> pinch(Offset center, double distance) =>
      GestureInjector.pinch(center, distance);
  @override
  Future<void> spread(Offset center, double distance) =>
      GestureInjector.spread(center, distance);
}

// ─── Widget ───────────────────────────────────────────────────────────────────
class DebugGestureOverlay extends StatefulWidget {
  const DebugGestureOverlay({
    super.key,
    GestureInjectorInterface? injector,
    this.onMovePlayer,
    this.onResumeGps,
    this.onMovePlayerToUnvisited,
  }) : _injector = injector ?? const _DefaultInjector();

  final GestureInjectorInterface _injector;
  final void Function(DebugPlayerMoveDirection direction)? onMovePlayer;
  final VoidCallback? onResumeGps;
  final VoidCallback? onMovePlayerToUnvisited;
  @override
  State<DebugGestureOverlay> createState() => _DebugGestureOverlayState();
}

class _DebugGestureOverlayState extends State<DebugGestureOverlay> {
  bool _expanded = true;

  static const double _bottomNavHeight = 80;
  static const double _defaultWidth = 375;
  static const double _defaultHeight = 812;
  static const double _panelWidth = 64;
  static const double _handleWidth = 24;
  static const double _kGestureTargetY = 80.0;

  BoxDecoration _panelDecoration(ColorScheme colorScheme) => BoxDecoration(
    color: colorScheme.surfaceContainerHighest,
    border: Border(
      left: BorderSide(color: colorScheme.outline),
      top: BorderSide(color: colorScheme.outline),
      bottom: BorderSide(color: colorScheme.outline),
    ),
    borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(8),
      bottomLeft: Radius.circular(8),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final size =
        MediaQuery.maybeSizeOf(context) ??
        const Size(_defaultWidth, _defaultHeight);
    final colorScheme = Theme.of(context).colorScheme;

    final center = Offset(size.width / 2, (size.height - _bottomNavHeight) / 2);
    final gestureCenter = Offset(size.width / 2, _kGestureTargetY);
    final swipeDistance = size.height * 0.25;
    final pinchDistance = size.width * 0.4;

    // Always use pointer injection — works on all Flutter widget trees.
    final injector = widget._injector;

    return Positioned(
      top: 72,
      right: 0,
      child: Container(
        width: _expanded ? _panelWidth : _handleWidth,
        clipBehavior: Clip.antiAlias,
        decoration: _panelDecoration(colorScheme),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToggleHandle(
              expanded: _expanded,
              onTap: () => setState(() => _expanded = !_expanded),
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              _btn(
                'Pinch',
                Icons.zoom_out,
                'Pinch',
                () => injector.pinch(gestureCenter, pinchDistance),
              ),
              const SizedBox(height: 4),
              _btn(
                'Spread',
                Icons.zoom_in,
                'Spread',
                () => injector.spread(gestureCenter, pinchDistance),
              ),
              const SizedBox(height: 4),
              _btn(
                '↑ Up',
                Icons.arrow_upward,
                'Up',
                () => injector.swipeUp(center, swipeDistance),
              ),
              const SizedBox(height: 4),
              _btn(
                '↓ Dn',
                Icons.arrow_downward,
                'Down',
                () => injector.swipeDown(center, swipeDistance),
              ),
              const SizedBox(height: 4),
              _btn(
                '← L',
                Icons.arrow_back,
                'Left',
                () => injector.swipeLeft(center, swipeDistance),
              ),
              const SizedBox(height: 4),
              _btn(
                '→ R',
                Icons.arrow_forward,
                'Right',
                () => injector.swipeRight(center, swipeDistance),
              ),
              if (widget.onMovePlayer != null) ...[
                const SizedBox(height: 8),
                _btn(
                  'P↑',
                  Icons.keyboard_arrow_up,
                  'Move player north',
                  () => widget.onMovePlayer!(DebugPlayerMoveDirection.north),
                ),
                const SizedBox(height: 4),
                _btn(
                  'P↓',
                  Icons.keyboard_arrow_down,
                  'Move player south',
                  () => widget.onMovePlayer!(DebugPlayerMoveDirection.south),
                ),
                const SizedBox(height: 4),
                _btn(
                  'P←',
                  Icons.keyboard_arrow_left,
                  'Move player west',
                  () => widget.onMovePlayer!(DebugPlayerMoveDirection.west),
                ),
                const SizedBox(height: 4),
                _btn(
                  'P→',
                  Icons.keyboard_arrow_right,
                  'Move player east',
                  () => widget.onMovePlayer!(DebugPlayerMoveDirection.east),
                ),
              ],
              if (widget.onMovePlayerToUnvisited != null) ...[
                const SizedBox(height: 4),
                _btn(
                  'P★',
                  Icons.explore,
                  'Move player to nearest unvisited cell',
                  widget.onMovePlayerToUnvisited!,
                ),
              ],
              if (widget.onResumeGps != null) ...[
                const SizedBox(height: 4),
                _btn(
                  'GPS',
                  Icons.my_location,
                  'Resume GPS',
                  widget.onResumeGps!,
                ),
              ],
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _btn(
    String label,
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        // eac-clickable-ignore: debug gesture controls are developer-only test chrome outside the product action catalog.
        child: InkWell(
          onTap: onPressed,
          splashColor: colorScheme.onSurface.withValues(alpha: 0.4),
          highlightColor: colorScheme.onSurface.withValues(alpha: 0.2),
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: colorScheme.onSurface, size: 18),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      height: 1.0,
                    ),
                    overflow: TextOverflow.clip,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Toggle handle ────────────────────────────────────────────────────────────
class _ToggleHandle extends StatelessWidget {
  const _ToggleHandle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      // eac-clickable-ignore: debug overlay collapse is developer-only test chrome outside the product action catalog.
      child: InkWell(
        key: const Key('debug_overlay_toggle'),
        onTap: onTap,
        splashColor: colorScheme.onSurface.withValues(alpha: 0.4),
        highlightColor: colorScheme.onSurface.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(8)),
        child: SizedBox(
          height: 32,
          width: double.infinity,
          child: Center(
            child: Icon(
              expanded ? Icons.chevron_right : Icons.chevron_left,
              color: colorScheme.onSurface,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}
