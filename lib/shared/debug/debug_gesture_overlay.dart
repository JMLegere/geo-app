import 'package:flutter/material.dart';
import 'package:earth_nova/shared/debug/gesture_injector.dart';

abstract interface class GestureInjectorInterface {
  Future<void> swipeUp(Offset center, double distance);
  Future<void> swipeDown(Offset center, double distance);
  Future<void> swipeLeft(Offset center, double distance);
  Future<void> swipeRight(Offset center, double distance);
  Future<void> pinch(Offset center, double distance);
  Future<void> spread(Offset center, double distance);
  Future<void> doubleTap(Offset center);
}

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

  @override
  Future<void> doubleTap(Offset center) => GestureInjector.doubleTap(center);
}

class DebugGestureOverlay extends StatelessWidget {
  const DebugGestureOverlay({
    super.key,
    GestureInjectorInterface? injector,
  }) : _injector = injector ?? const _DefaultInjector();

  final GestureInjectorInterface _injector;

  static const double _bottomNavHeight = 80;
  static const double _defaultWidth = 375;
  static const double _defaultHeight = 812;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.maybeSizeOf(context) ??
        const Size(_defaultWidth, _defaultHeight);

    final center = Offset(
      size.width / 2,
      (size.height - _bottomNavHeight) / 2,
    );
    final swipeDistance = size.height * 0.25;
    final pinchDistance = size.width * 0.4;

    return Positioned(
      top: 100,
      right: 0,
      child: Container(
        width: 56,
        decoration: const BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(8),
            bottomLeft: Radius.circular(8),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _btn(
              icon: Icons.zoom_out,
              tooltip: 'Pinch',
              onPressed: () => _injector.pinch(center, pinchDistance),
            ),
            _btn(
              icon: Icons.zoom_in,
              tooltip: 'Spread',
              onPressed: () => _injector.spread(center, pinchDistance),
            ),
            _btn(
              icon: Icons.arrow_upward,
              tooltip: 'Up',
              onPressed: () => _injector.swipeUp(center, swipeDistance),
            ),
            _btn(
              icon: Icons.arrow_downward,
              tooltip: 'Down',
              onPressed: () => _injector.swipeDown(center, swipeDistance),
            ),
            _btn(
              icon: Icons.arrow_back,
              tooltip: 'Left',
              onPressed: () => _injector.swipeLeft(center, swipeDistance),
            ),
            _btn(
              icon: Icons.arrow_forward,
              tooltip: 'Right',
              onPressed: () => _injector.swipeRight(center, swipeDistance),
            ),
            _btn(
              icon: Icons.touch_app,
              tooltip: 'DblTap',
              onPressed: () => _injector.doubleTap(center),
            ),
          ],
        ),
      ),
    );
  }

  Widget _btn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
    );
  }
}
