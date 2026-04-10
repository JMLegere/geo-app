import 'package:flutter/material.dart';
import 'package:earth_nova/shared/debug/gesture_injector.dart';

// ─── Colour palette ───────────────────────────────────────────────────────────
// Hardcoded to decouple debug tooling from AppTheme.
// Mirrors: surfaceContainerHighest · tertiary · onSurfaceVariant · outline · primary
const Color _kPanelBg = Color(0xFF243A50);
const Color _kIconColor = Color(0xFF83C5BE);
const Color _kLabelColor = Color(0xFFADB5BD);
const Color _kBorder = Color(0xFF3D5060);
const Color _kSplash = Color(0x66006D77); // primary @ ~40 %
const Color _kHighlight = Color(0x33006D77); // primary @ ~20 %

// ─── Interface ────────────────────────────────────────────────────────────────
abstract interface class GestureInjectorInterface {
  Future<void> swipeUp(Offset center, double distance);
  Future<void> swipeDown(Offset center, double distance);
  Future<void> swipeLeft(Offset center, double distance);
  Future<void> swipeRight(Offset center, double distance);
  Future<void> pinch(Offset center, double distance);
  Future<void> spread(Offset center, double distance);
}

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
  }) : _injector = injector ?? const _DefaultInjector();

  final GestureInjectorInterface _injector;

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

  static const BoxDecoration _panelDecoration = BoxDecoration(
    color: _kPanelBg,
    border: Border(
      left: BorderSide(color: _kBorder),
      top: BorderSide(color: _kBorder),
      bottom: BorderSide(color: _kBorder),
    ),
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(8),
      bottomLeft: Radius.circular(8),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.maybeSizeOf(context) ??
        const Size(_defaultWidth, _defaultHeight);

    final center = Offset(
      size.width / 2,
      (size.height - _bottomNavHeight) / 2,
    );
    final gestureCenter = Offset(size.width / 2, _kGestureTargetY);
    final swipeDistance = size.height * 0.25;
    final pinchDistance = size.width * 0.4;

    // Always use pointer injection — works on all Flutter widget trees.
    final injector = widget._injector;

    return Positioned(
      top: 100,
      right: 0,
      child: Container(
        width: _expanded ? _panelWidth : _handleWidth,
        clipBehavior: Clip.antiAlias,
        decoration: _panelDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToggleHandle(
              expanded: _expanded,
              onTap: () => setState(() => _expanded = !_expanded),
            ),
            if (_expanded) ...[
              const SizedBox(height: 8),
              _btn('Pinch', Icons.zoom_out, 'Pinch',
                  () => injector.pinch(gestureCenter, pinchDistance)),
              const SizedBox(height: 4),
              _btn('Spread', Icons.zoom_in, 'Spread',
                  () => injector.spread(gestureCenter, pinchDistance)),
              const SizedBox(height: 4),
              _btn('↑ Up', Icons.arrow_upward, 'Up',
                  () => injector.swipeUp(center, swipeDistance)),
              const SizedBox(height: 4),
              _btn('↓ Dn', Icons.arrow_downward, 'Down',
                  () => injector.swipeDown(center, swipeDistance)),
              const SizedBox(height: 4),
              _btn('← L', Icons.arrow_back, 'Left',
                  () => injector.swipeLeft(center, swipeDistance)),
              const SizedBox(height: 4),
              _btn('→ R', Icons.arrow_forward, 'Right',
                  () => injector.swipeRight(center, swipeDistance)),
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
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          splashColor: _kSplash,
          highlightColor: _kHighlight,
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: _kIconColor, size: 18),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      color: _kLabelColor,
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
  const _ToggleHandle({
    required this.expanded,
    required this.onTap,
  });

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('debug_overlay_toggle'),
        onTap: onTap,
        splashColor: _kSplash,
        highlightColor: _kHighlight,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(8)),
        child: SizedBox(
          height: 32,
          width: double.infinity,
          child: Center(
            child: Icon(
              expanded ? Icons.chevron_right : Icons.chevron_left,
              color: _kIconColor,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}
