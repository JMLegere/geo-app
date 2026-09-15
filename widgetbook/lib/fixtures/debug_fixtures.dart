import 'package:earth_nova/ui/product_surfaces/debug/debug_gesture_overlay.dart';
import 'package:flutter/material.dart';

final class StoryGestureInjector implements GestureInjectorInterface {
  @override
  Future<void> pinch(Offset center, double distance) async {}

  @override
  Future<void> spread(Offset center, double distance) async {}

  @override
  Future<void> swipeDown(Offset center, double distance) async {}

  @override
  Future<void> swipeLeft(Offset center, double distance) async {}

  @override
  Future<void> swipeRight(Offset center, double distance) async {}

  @override
  Future<void> swipeUp(Offset center, double distance) async {}
}
