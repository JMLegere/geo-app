import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';

import 'package:earth_nova/features/map/controllers/camera_controller.dart';
import 'package:earth_nova/shared/constants.dart';

void main() {
  group('CameraController', () {
    late CameraController controller;
    late List<Geographic> moves;
    late List<(Geographic, Duration)> animates;

    setUp(() {
      moves = [];
      animates = [];
      controller = CameraController(
        onMoveToPlayer: (center) {
          moves.add(center);
        },
        onAnimateToPlayer: (center, duration) {
          animates.add((center, duration));
        },
      );
    });

    tearDown(() => controller.dispose());

    test('starts in following mode', () {
      expect(controller.mode.value, CameraMode.following);
    });

    test('GPS update in following mode emits onMoveToPlayer (instant)', () {
      final pos = Geographic(lat: 48.42, lon: -123.36);
      controller.onPlayerPositionUpdate(pos);
      expect(moves, hasLength(1));
      expect(moves.first.lat, 48.42);
      expect(animates, isEmpty, reason: 'follow uses moveCamera, not animate');
    });

    test('GPS update in free mode does not emit', () {
      controller.onUserGesture(); // → free
      final pos = Geographic(lat: 48.42, lon: -123.36);
      controller.onPlayerPositionUpdate(pos);
      expect(moves, isEmpty);
    });

    test('GPS update in overview mode does not emit', () {
      controller.enterOverview(); // → overview
      final pos = Geographic(lat: 48.42, lon: -123.36);
      controller.onPlayerPositionUpdate(pos);
      expect(moves, isEmpty);
    });

    test('user gesture transitions to free mode', () {
      expect(controller.mode.value, CameraMode.following);
      controller.onUserGesture();
      expect(controller.mode.value, CameraMode.free);
    });

    test('multiple gestures in free mode are idempotent', () {
      controller.onUserGesture();
      controller.onUserGesture();
      controller.onUserGesture();
      expect(controller.mode.value, CameraMode.free);
    });

    test('recenter emits move and transitions to following', () async {
      final pos = Geographic(lat: 48.42, lon: -123.36);
      controller.onPlayerPositionUpdate(pos); // cache position
      moves.clear();

      controller.onUserGesture(); // → free
      controller.recenter();

      expect(animates, hasLength(1),
          reason: 'recenter uses animateCamera, not moveCamera');
      expect(animates.first.$2, kRecenterDuration);

      // Wait for delayed mode transition
      await Future.delayed(
          kRecenterDuration + const Duration(milliseconds: 50));
      expect(controller.mode.value, CameraMode.following);
    });

    test('recenter with null player is no-op', () {
      controller.onUserGesture(); // → free
      controller.recenter();
      expect(moves, isEmpty);
      expect(controller.mode.value, CameraMode.free);
    });

    test('enterOverview transitions to overview', () {
      controller.enterOverview();
      expect(controller.mode.value, CameraMode.overview);
    });

    test('exitOverview transitions to free', () {
      controller.enterOverview();
      controller.exitOverview();
      expect(controller.mode.value, CameraMode.free);
    });

    test('gesture during overview transitions to free', () {
      controller.enterOverview();
      controller.onUserGesture();
      expect(controller.mode.value, CameraMode.free);
    });

    test('playerPosition is cached for recenter', () {
      final pos = Geographic(lat: 48.42, lon: -123.36);
      controller.onPlayerPositionUpdate(pos);
      expect(controller.playerPosition, pos);
    });
  });
}
