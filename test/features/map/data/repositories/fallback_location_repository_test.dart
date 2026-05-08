import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/map/data/repositories/fallback_location_repository.dart';
import 'package:earth_nova/features/map/data/repositories/mock_location_repository.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/repositories/location_repository.dart';

typedef _LoggedEvent = ({
  String event,
  String category,
  Map<String, dynamic>? data
});

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
    late List<_LoggedEvent> events;

    final sfPosition = LocationState(
      lat: 37.7749,
      lng: -122.4194,
      accuracy: 5.0,
      timestamp: DateTime(2026),
      isConfident: true,
    );

    void logEvent(String event, String category, {Map<String, dynamic>? data}) {
      events.add((event: event, category: category, data: data));
    }

    setUp(() {
      realRepo = MockLocationRepository();
      mockRepo = MockLocationRepository();
      mockRepo.emitPosition(sfPosition);
      events = [];
      fallback = FallbackLocationRepository(
        real: realRepo,
        mock: mockRepo,
        logEvent: logEvent,
      );
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

    test('requestPermission logs fallback enable when real denies', () async {
      realRepo.setPermissionGranted(false);

      final result = await fallback.requestPermission();

      expect(result, isTrue);
      final permissionEvent = events.singleWhere(
        (event) => event.event == 'map.gps_permission_fallback_enabled',
      );
      expect(permissionEvent.category, 'map');
      expect(permissionEvent.data?['source'], 'fallback_mock');
      expect(permissionEvent.data?['flow'], 'map.bootstrap');
      expect(permissionEvent.data?['phase'], 'state_changed');
      expect(permissionEvent.data?['dependency'], 'gps');
    });

    test('getCurrentPosition returns SF position when real throws', () async {
      final repo = FallbackLocationRepository(
        real: _ThrowingLocationRepository(),
        mock: mockRepo,
        logEvent: logEvent,
      );

      final position = await repo.getCurrentPosition();
      expect(position.lat, 37.7749);
      expect(position.lng, -122.4194);
      expect(position.accuracy, 5.0);
      expect(position.isConfident, isTrue);

      final sourceEvent = events.singleWhere(
        (event) => event.event == 'map.gps_source_selected',
      );
      expect(sourceEvent.category, 'map');
      expect(sourceEvent.data?['source'], 'fallback_current_position');
      expect(sourceEvent.data?['flow'], 'map.bootstrap');
      expect(sourceEvent.data?['phase'], 'state_changed');
      expect(sourceEvent.data?['dependency'], 'gps');
    });

    test('default fallback position is inside beta Fredericton coverage',
        () async {
      final repo = FallbackLocationRepository(
        real: _ThrowingLocationRepository(),
        logEvent: logEvent,
      );

      final position = await repo.getCurrentPosition();

      expect(position.lat, 45.9636);
      expect(position.lng, -66.6431);
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

      final sourceEvent = events.singleWhere(
        (event) => event.event == 'map.gps_source_selected',
      );
      expect(sourceEvent.data?['source'], 'real_current_position');
      expect(sourceEvent.data?['flow'], 'map.bootstrap');
      expect(sourceEvent.data?['phase'], 'state_changed');
      expect(sourceEvent.data?['dependency'], 'gps');
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

    test('positionStream logs when it falls back to mock stream', () async {
      final sub = fallback.positionStream.listen((_) {});

      realRepo.emitError(Exception('GPS error'));
      await Future<void>.delayed(Duration.zero);

      final sourceEvent = events.singleWhere(
        (event) => event.event == 'map.gps_source_selected',
      );
      expect(sourceEvent.data?['source'], 'fallback_stream');
      expect(sourceEvent.data?['flow'], 'map.bootstrap');
      expect(sourceEvent.data?['phase'], 'state_changed');
      expect(sourceEvent.data?['dependency'], 'gps');

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
