import 'dart:async';

import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/repositories/location_repository.dart';
import 'package:earth_nova/features/map/domain/use_cases/get_location_stream.dart';
import 'package:flutter_test/flutter_test.dart';

class TestObservabilityService extends ObservabilityService {
  TestObservabilityService() : super(sessionId: 'test-session');

  final logs = <Map<String, Object?>>[];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    logs.add({'event': event, 'category': category, 'data': data});
  }
}

class FakeLocationRepository implements LocationRepository {
  FakeLocationRepository(
      {this.throwOnAccess = false, Stream<LocationState>? stream})
      : _stream = stream ?? const Stream.empty();

  final bool throwOnAccess;
  final Stream<LocationState> _stream;

  @override
  Stream<LocationState> get positionStream {
    if (throwOnAccess) throw Exception('Fake stream getter error');
    return _stream;
  }

  @override
  Future<LocationState> getCurrentPosition() async {
    return LocationState(
      lat: 0,
      lng: 0,
      accuracy: 1,
      timestamp: DateTime(2026),
      isConfident: true,
    );
  }

  @override
  Future<bool> requestPermission() async => true;
}

void main() {
  group('GetLocationStream', () {
    test('returns repository stream and logs operation lifecycle', () async {
      final controller = StreamController<LocationState>();
      final expected = LocationState(
        lat: 1.2,
        lng: 3.4,
        accuracy: 5,
        timestamp: DateTime(2026, 4, 8),
        isConfident: true,
      );
      final obs = TestObservabilityService();
      final useCase = GetLocationStream(
        FakeLocationRepository(stream: controller.stream),
        obs,
      );

      final stream = useCase.call((includeMetadata: false));
      controller.add(expected);

      await expectLater(stream, emits(expected));
      await controller.close();

      expect(obs.logs[0]['event'], 'operation.started');
      expect(obs.logs[1]['event'], 'operation.completed');
    });

    test('logs failure and rethrows when repository getter throws', () {
      final obs = TestObservabilityService();
      final useCase = GetLocationStream(
        FakeLocationRepository(throwOnAccess: true),
        obs,
      );

      expect(
        () => useCase.call((includeMetadata: false)),
        throwsException,
      );
      expect(obs.logs[0]['event'], 'operation.started');
      expect(obs.logs[1]['event'], 'operation.failed');
    });
  });
}
