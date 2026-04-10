import 'package:flutter/widgets.dart';

class GestureInjector {
  GestureInjector._();

  static Future<void> swipe(
    Offset start,
    Offset end, {
    Duration duration = const Duration(milliseconds: 300),
  }) async {
    final binding = WidgetsBinding.instance;
    const frames = 20;

    binding.handlePointerEvent(PointerDownEvent(
      pointer: 1,
      device: 1,
      position: start,
    ));

    for (var i = 0; i < frames; i++) {
      final t = (i + 1) / frames;
      final position = Offset.lerp(start, end, t)!;
      binding.handlePointerEvent(PointerMoveEvent(
        pointer: 1,
        device: 1,
        position: position,
      ));
    }

    binding.handlePointerEvent(PointerUpEvent(
      pointer: 1,
      device: 1,
      position: end,
    ));
  }

  static Future<void> pinch(Offset center, double distance) async {
    final binding = WidgetsBinding.instance;
    const frames = 20;

    final startLeft = Offset(center.dx - distance / 2, center.dy);
    final startRight = Offset(center.dx + distance / 2, center.dy);
    final endLeft = Offset(center.dx - distance * 0.3 / 2, center.dy);
    final endRight = Offset(center.dx + distance * 0.3 / 2, center.dy);

    binding.handlePointerEvent(PointerDownEvent(
      pointer: 1,
      device: 1,
      position: startLeft,
    ));
    binding.handlePointerEvent(PointerDownEvent(
      pointer: 2,
      device: 2,
      position: startRight,
    ));

    for (var i = 0; i < frames; i++) {
      final t = (i + 1) / frames;
      binding.handlePointerEvent(PointerMoveEvent(
        pointer: 1,
        device: 1,
        position: Offset.lerp(startLeft, endLeft, t)!,
      ));
      binding.handlePointerEvent(PointerMoveEvent(
        pointer: 2,
        device: 2,
        position: Offset.lerp(startRight, endRight, t)!,
      ));
    }

    binding.handlePointerEvent(PointerUpEvent(
      pointer: 1,
      device: 1,
      position: endLeft,
    ));
    binding.handlePointerEvent(PointerUpEvent(
      pointer: 2,
      device: 2,
      position: endRight,
    ));
  }

  static Future<void> spread(Offset center, double distance) async {
    final binding = WidgetsBinding.instance;
    const frames = 20;

    final startLeft = Offset(center.dx - distance * 0.3 / 2, center.dy);
    final startRight = Offset(center.dx + distance * 0.3 / 2, center.dy);
    final endLeft = Offset(center.dx - distance / 2, center.dy);
    final endRight = Offset(center.dx + distance / 2, center.dy);

    binding.handlePointerEvent(PointerDownEvent(
      pointer: 1,
      device: 1,
      position: startLeft,
    ));
    binding.handlePointerEvent(PointerDownEvent(
      pointer: 2,
      device: 2,
      position: startRight,
    ));

    for (var i = 0; i < frames; i++) {
      final t = (i + 1) / frames;
      binding.handlePointerEvent(PointerMoveEvent(
        pointer: 1,
        device: 1,
        position: Offset.lerp(startLeft, endLeft, t)!,
      ));
      binding.handlePointerEvent(PointerMoveEvent(
        pointer: 2,
        device: 2,
        position: Offset.lerp(startRight, endRight, t)!,
      ));
    }

    binding.handlePointerEvent(PointerUpEvent(
      pointer: 1,
      device: 1,
      position: endLeft,
    ));
    binding.handlePointerEvent(PointerUpEvent(
      pointer: 2,
      device: 2,
      position: endRight,
    ));
  }
}
