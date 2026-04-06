import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/map/data/repositories/mock_location_repository.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';

void main() {
  group('MockLocationRepository', () {
    late MockLocationRepository repo;

    setUp(() {
      repo = MockLocationRepository();
    });

    tearDown(() {
      repo.dispose();
    });

    test('requestPermission returns true by default', () async {
      final result = await repo.requestPermission();
      expect(result, isTrue);
    });

    test('requestPermission returns false when configured', () async {
      repo.setPermissionGranted(false);
      final result = await repo.requestPermission();
      expect(result, isFalse);
    });

    test('getCurrentPosition returns default position', () async {
      final position = await repo.getCurrentPosition();
      expect(position, isA<LocationState>());
      expect(position.lat, 0.0);
      expect(position.lng, 0.0);
    });

    test('getCurrentPosition returns emitted position', () async {
      final emitted = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      repo.emitPosition(emitted);
      final position = await repo.getCurrentPosition();
      expect(position.lat, 37.7749);
      expect(position.lng, -122.4194);
    });

    test('positionStream emits positions', () async {
      final positions = <LocationState>[];
      final sub = repo.positionStream.listen(positions.add);

      final pos1 = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      final pos2 = LocationState(
        lat: 37.7750,
        lng: -122.4195,
        accuracy: 3.0,
        timestamp: DateTime(2026, 1, 1, 0, 0, 1),
        isConfident: true,
      );

      repo.emitPosition(pos1);
      repo.emitPosition(pos2);
      await Future<void>.delayed(Duration.zero);

      expect(positions.length, 2);
      expect(positions[0].lat, 37.7749);
      expect(positions[1].lat, 37.7750);

      await sub.cancel();
    });

    test('emitError causes positionStream to emit error', () async {
      final errors = <Object>[];
      final sub = repo.positionStream.listen(
        (_) {},
        onError: errors.add,
      );

      repo.emitError(Exception('GPS error'));
      await Future<void>.delayed(Duration.zero);

      expect(errors.length, 1);
      await sub.cancel();
    });

    test('positionStream is broadcast', () async {
      final sub1 = repo.positionStream.listen((_) {});
      final sub2 = repo.positionStream.listen((_) {});
      await sub1.cancel();
      await sub2.cancel();
    });
  });
}
