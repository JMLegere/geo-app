import 'dart:async';

import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/repositories/location_repository.dart';
import 'package:earth_nova/features/map/data/repositories/mock_location_repository.dart';

class FallbackLocationRepository implements LocationRepository {
  FallbackLocationRepository({
    required LocationRepository real,
    LocationRepository? mock,
  })  : _real = real,
        _mock = mock ?? _defaultMock();

  final LocationRepository _real;
  final LocationRepository _mock;

  static MockLocationRepository _defaultMock() {
    final repo = MockLocationRepository();
    repo.emitPosition(LocationState(
      lat: 37.7749,
      lng: -122.4194,
      accuracy: 5.0,
      timestamp: DateTime.now(),
      isConfident: true,
    ));
    return repo;
  }

  @override
  Future<bool> requestPermission({String? traceId}) async {
    final granted = await _real.requestPermission(traceId: traceId);
    if (!granted) return true;
    return granted;
  }

  @override
  Future<LocationState> getCurrentPosition({String? traceId}) async {
    try {
      return await _real.getCurrentPosition(traceId: traceId);
    } catch (_) {
      return _mock.getCurrentPosition(traceId: traceId);
    }
  }

  @override
  Stream<LocationState> get positionStream {
    final controller = StreamController<LocationState>.broadcast();
    StreamSubscription<LocationState>? realSub;
    StreamSubscription<LocationState>? mockSub;

    realSub = _real.positionStream.listen(
      controller.add,
      onError: (_) {
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
}
