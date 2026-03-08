import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/map/controllers/camera_controller.dart';

void main() {
  group('CameraController', () {
    late CameraController controller;
    final calls = <(double, double)>[];

    setUp(() {
      controller = CameraController();
      calls.clear();
      controller.onCameraMove = (lat, lon) => calls.add((lat, lon));
    });

    // -------------------------------------------------------------------------
    // Initial state
    // -------------------------------------------------------------------------

    test('starts in following mode', () {
      expect(controller.mode, equals(CameraMode.following));
    });

    test('onCameraMove is initially null', () {
      final c = CameraController();
      expect(c.onCameraMove, isNull);
    });

    // -------------------------------------------------------------------------
    // onLocationUpdate in following mode
    // -------------------------------------------------------------------------

    test('onLocationUpdate calls onCameraMove when in following mode', () {
      controller.onLocationUpdate(37.7749, -122.4194);

      expect(calls.length, equals(1));
      expect(calls[0].$1, closeTo(37.7749, 0.0001));
      expect(calls[0].$2, closeTo(-122.4194, 0.0001));
    });

    test('onLocationUpdate passes exact lat/lon to callback', () {
      controller.onLocationUpdate(51.5074, -0.1278);

      expect(calls.length, equals(1));
      expect(calls[0].$1, equals(51.5074));
      expect(calls[0].$2, equals(-0.1278));
    });

    test('onLocationUpdate is a no-op when onCameraMove is null', () {
      controller.onCameraMove = null;
      expect(() => controller.onLocationUpdate(0.0, 0.0), returnsNormally);
    });

    test('multiple onLocationUpdate calls each trigger the callback', () {
      controller.onLocationUpdate(10.0, 20.0);
      controller.onLocationUpdate(11.0, 21.0);
      controller.onLocationUpdate(12.0, 22.0);

      expect(calls.length, equals(3));
    });

    // -------------------------------------------------------------------------
    // onUserGesture — switch to free mode
    // -------------------------------------------------------------------------

    test('onUserGesture switches mode to free', () {
      controller.onUserGesture();
      expect(controller.mode, equals(CameraMode.free));
    });

    test('onLocationUpdate does NOT call onCameraMove when in free mode', () {
      controller.onUserGesture();
      controller.onLocationUpdate(37.7749, -122.4194);

      expect(calls, isEmpty);
    });

    test('subsequent location updates after gesture are all suppressed', () {
      controller.onUserGesture();

      controller.onLocationUpdate(1.0, 1.0);
      controller.onLocationUpdate(2.0, 2.0);
      controller.onLocationUpdate(3.0, 3.0);

      expect(calls, isEmpty);
    });

    test('can switch to free mode multiple times without error', () {
      controller.onUserGesture();
      controller.onUserGesture();
      expect(controller.mode, equals(CameraMode.free));
    });

    // -------------------------------------------------------------------------
    // recenter — resume following
    // -------------------------------------------------------------------------

    test('recenter switches back to following mode', () {
      controller.onUserGesture();
      expect(controller.mode, equals(CameraMode.free));

      controller.recenter(40.0, -74.0);
      expect(controller.mode, equals(CameraMode.following));
    });

    test('recenter calls onCameraMove with provided coordinates', () {
      controller.onUserGesture();
      controller.recenter(48.8566, 2.3522);

      expect(calls.length, equals(1));
      expect(calls[0].$1, equals(48.8566));
      expect(calls[0].$2, equals(2.3522));
    });

    test('after recenter, location updates resume triggering callback', () {
      controller.onUserGesture();
      calls.clear(); // Ignore the recenter call

      controller.recenter(40.0, -74.0);
      calls.clear(); // Ignore the recenter call itself

      controller.onLocationUpdate(40.1, -74.1);
      expect(calls.length, equals(1));
    });

    test('recenter is a no-op for onCameraMove when callback is null', () {
      controller.onCameraMove = null;
      expect(() => controller.recenter(0.0, 0.0), returnsNormally);
      expect(controller.mode, equals(CameraMode.following));
    });

    // -------------------------------------------------------------------------
    // Mode transitions
    // -------------------------------------------------------------------------

    test('full cycle: following → free → following', () {
      expect(controller.mode, equals(CameraMode.following));

      controller.onUserGesture();
      expect(controller.mode, equals(CameraMode.free));

      controller.recenter(0.0, 0.0);
      expect(controller.mode, equals(CameraMode.following));
    });

    test('calling recenter from following mode is valid and moves camera', () {
      // Should work even if already in following mode.
      controller.recenter(55.7558, 37.6173);

      expect(controller.mode, equals(CameraMode.following));
      expect(calls.length, equals(1));
    });
  });
}
