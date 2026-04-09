import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/map/data/repositories/fallback_location_repository.dart';
import 'package:earth_nova/features/map/data/repositories/mock_location_repository.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/repositories/location_repository.dart';

class _ThrowingLocationRepository implements LocationRepository {
  @override
  Stream<LocationState> get positionStream => const Stream.empty();

  @override
  Future<LocationState> getCurrentPosition({String? traceId}) =>
      Future.error(Exception('GPS unavailable'));

  @override
  Future<bool> requestPermission({String? traceId}) async => false;
}

void main() {
  group('FallbackLocationRepository', () {
    late MockLocationRepository realRepo;
    late MockLocationRepository mockRepo;
    late FallbackLocationRepository fallback;

    final sfPosition = LocationState(
      lat: 37.7749,
      lng: -122.4194,
      accuracy: 5.0,
      timestamp: DateTime(2026),
      isConfident: true,
    );

    setUp(() {
      realRepo = MockLocationRepository();
      mockRepo = MockLocationRepository();
      mockRepo.emitPosition(sfPosition);
      fallback = FallbackLocationRepository(real: realRepo, mock: mockRepo);
    });

    tearDown(() {
      realRepo.dispose();
      mockRepo.dispose();
    });

    test('requestPermission returns true when real returns false', () async {
      realRepo.setPermissionGranted(false);
      final result = await fallback.requestPermission();
      expect(result, isTrue);
    });

    test('requestPermission returns true when real returns true', () async {
      realRepo.setPermissionGranted(true);
      final result = await fallback.requestPermission();
      expect(result, isTrue);
    });

    test('getCurrentPosition returns SF position when real throws', () async {
      final throwingReal = _ThrowingLocationRepository();
      final repo =
          FallbackLocationRepository(real: throwingReal, mock: mockRepo);

      final position = await repo.getCurrentPosition();
      expect(position.lat, 37.7749);
      expect(position.lng, -122.4194);
      expect(position.accuracy, 5.0);
      expect(position.isConfident, isTrue);
    });

    test('getCurrentPosition returns real position when real succeeds',
        () async {
      final realPos = LocationState(
        lat: 10.0,
        lng: 20.0,
        accuracy: 3.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      realRepo.emitPosition(realPos);

      final position = await fallback.getCurrentPosition();
      expect(position.lat, 10.0);
      expect(position.lng, 20.0);
    });

    test('positionStream switches to mock after real stream emits error',
        () async {
      final received = <LocationState>[];
      final sub = fallback.positionStream.listen(received.add);

      realRepo.emitError(Exception('GPS error'));
      await Future<void>.delayed(Duration.zero);

      mockRepo.emitPosition(sfPosition);
      await Future<void>.delayed(Duration.zero);

      expect(received, contains(sfPosition));

      await sub.cancel();
    });

    test('positionStream uses real stream when real works', () async {
      final received = <LocationState>[];
      final sub = fallback.positionStream.listen(received.add);

      final realPos = LocationState(
        lat: 51.5074,
        lng: -0.1278,
        accuracy: 8.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      realRepo.emitPosition(realPos);
      await Future<void>.delayed(Duration.zero);

      expect(received, contains(realPos));

      await sub.cancel();
    });
  });
}
