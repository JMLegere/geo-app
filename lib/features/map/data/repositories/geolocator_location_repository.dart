import 'package:geolocator/geolocator.dart';

import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/repositories/location_repository.dart';

const double _kConfidenceAccuracyThresholdMeters = 20.0;
const int _kDistanceFilterMeters = 5;

class GeolocatorLocationRepository implements LocationRepository {
  @override
  Stream<LocationState> get positionStream {
    // No timeLimit: with distanceFilter the stream is intentionally silent
    // when the user isn't moving. timeLimit caused a TimeoutException whenever
    // no position arrived within the window, which permanently killed the
    // stream — even for someone standing still.
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: _kDistanceFilterMeters,
    );
    return Geolocator.getPositionStream(locationSettings: settings)
        .map(_positionToState);
  }

  @override
  Future<LocationState> getCurrentPosition() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    return _positionToState(position);
  }

  @override
  Future<bool> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  LocationState _positionToState(Position position) {
    return LocationState(
      lat: position.latitude,
      lng: position.longitude,
      accuracy: position.accuracy,
      timestamp: position.timestamp,
      isConfident: position.accuracy <= _kConfidenceAccuracyThresholdMeters,
    );
  }
}
