import 'dart:async';

import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/repositories/location_repository.dart';

class MockLocationRepository implements LocationRepository {
  final _controller = StreamController<LocationState>.broadcast();
  bool _permissionGranted = true;
  LocationState? _lastPosition;

  @override
  Stream<LocationState> get positionStream => _controller.stream;

  @override
  Future<LocationState> getCurrentPosition() async {
    if (_lastPosition != null) return _lastPosition!;
    return LocationState(
      lat: 0.0,
      lng: 0.0,
      accuracy: 10.0,
      timestamp: DateTime.now(),
      isConfident: true,
    );
  }

  @override
  Future<bool> requestPermission() async => _permissionGranted;

  void emitPosition(LocationState position) {
    _lastPosition = position;
    _controller.add(position);
  }

  void emitError(Object error) {
    _controller.addError(error);
  }

  void setPermissionGranted(bool granted) => _permissionGranted = granted;

  void dispose() => _controller.close();
}
