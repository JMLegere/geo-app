import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';

import 'package:earth_nova/features/map/controllers/camera_controller.dart';

void main() {
  group('CameraController', () {
    late CameraController controller;
    late List<Geographic> moves;

    setUp(() {
      moves = [];
      controller = CameraController(
        onMoveToPlayer: (center) => moves.add(center),
      );
    });

    tearDown(() => controller.dispose());

    test('every GPS update emits onMoveToPlayer', () {
      final pos = Geographic(lat: 48.42, lon: -123.36);
      controller.onPlayerPositionUpdate(pos);
      expect(moves, hasLength(1));
      expect(moves.first.lat, 48.42);
    });

    test('caches player position', () {
      expect(controller.playerPosition, isNull);
      final pos = Geographic(lat: 48.42, lon: -123.36);
      controller.onPlayerPositionUpdate(pos);
      expect(controller.playerPosition, pos);
    });

    test('multiple updates all emit moves', () {
      controller.onPlayerPositionUpdate(Geographic(lat: 1, lon: 1));
      controller.onPlayerPositionUpdate(Geographic(lat: 2, lon: 2));
      controller.onPlayerPositionUpdate(Geographic(lat: 3, lon: 3));
      expect(moves, hasLength(3));
    });
  });
}
