import 'dart:async';

import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/repositories/location_repository.dart';
import 'package:earth_nova/features/map/data/repositories/mock_location_repository.dart';

typedef LocationRepositoryLogEvent = void Function(
  String event,
  String category, {
  Map<String, dynamic>? data,
});

class FallbackLocationRepository implements LocationRepository {
  FallbackLocationRepository({
    required LocationRepository real,
    LocationRepository? mock,
    LocationRepositoryLogEvent? logEvent,
  })  : _real = real,
        _mock = mock ?? _defaultMock(),
        _logEvent = logEvent;

  final LocationRepository _real;
  final LocationRepository _mock;
  final LocationRepositoryLogEvent? _logEvent;

  static MockLocationRepository _defaultMock() {
    final repo = MockLocationRepository();
    repo.emitPosition(LocationState(
      lat: 45.9636,
      lng: -66.6431,
      accuracy: 5.0,
      timestamp: DateTime.now(),
      isConfident: true,
    ));
    return repo;
  }

  @override
  Future<bool> requestPermission({String? traceId}) async {
    final granted = await _real.requestPermission(traceId: traceId);
    if (!granted) {
      _logSourceEvent(
        'map.gps_permission_fallback_enabled',
        source: 'fallback_mock',
        traceId: traceId,
      );
      return true;
    }
    return granted;
  }

  @override
  Future<LocationState> getCurrentPosition({String? traceId}) async {
    try {
      final position = await _real.getCurrentPosition(traceId: traceId);
      _logSourceEvent(
        'map.gps_source_selected',
        source: 'real_current_position',
        traceId: traceId,
      );
      return position;
    } catch (error) {
      _logSourceEvent(
        'map.gps_source_selected',
        source: 'fallback_current_position',
        traceId: traceId,
        error: error.toString(),
      );
      return _mock.getCurrentPosition(traceId: traceId);
    }
  }

  @override
  Stream<LocationState> get positionStream {
    final controller = StreamController<LocationState>.broadcast();
    StreamSubscription<LocationState>? realSub;
    StreamSubscription<LocationState>? mockSub;
    var realSourceLogged = false;

    realSub = _real.positionStream.listen(
      (position) {
        if (!realSourceLogged) {
          realSourceLogged = true;
          _logSourceEvent(
            'map.gps_source_selected',
            source: 'real_stream',
          );
        }
        controller.add(position);
      },
      onError: (error) {
        _logSourceEvent(
          'map.gps_source_selected',
          source: 'fallback_stream',
          error: error.toString(),
        );
        realSub?.cancel();
        mockSub = _mock.positionStream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onDone: controller.close,
    );

    controller.onCancel = () {
      realSub?.cancel();
      mockSub?.cancel();
    };

    return controller.stream;
  }

  void _logSourceEvent(
    String event, {
    required String source,
    String? traceId,
    String? error,
  }) {
    _logEvent?.call(
      event,
      'map',
      data: {
        'flow': 'map.bootstrap',
        'phase': 'state_changed',
        'dependency': 'gps',
        'source': source,
        if (traceId != null && traceId.isNotEmpty) 'trace_id': traceId,
        if (error != null && error.isNotEmpty) 'error': error,
      },
    );
  }
}
