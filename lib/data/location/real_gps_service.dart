import 'dart:async';

import 'package:geobase/geobase.dart' show Geographic;
import 'package:geolocator/geolocator.dart';

import 'location_simulator.dart';

enum GpsPermissionStatus { granted, denied, deniedForever, serviceDisabled }

class RealGpsService {
  final double distanceFilter;

  RealGpsService({this.distanceFilter = 5.0});

  final StreamController<SimulatedLocation> _controller =
      StreamController<SimulatedLocation>.broadcast();
  StreamSubscription<Position>? _geolocatorSubscription;

  Stream<SimulatedLocation> get locationStream => _controller.stream;

  Future<GpsPermissionStatus> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return GpsPermissionStatus.serviceDisabled;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return GpsPermissionStatus.denied;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return GpsPermissionStatus.deniedForever;
    }

    return GpsPermissionStatus.granted;
  }

  Future<void> start() async {
    final status = await ensurePermission();
    if (status != GpsPermissionStatus.granted) return;

    _geolocatorSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter.toInt(),
      ),
    ).listen(
      (Position position) {
        _controller.add(SimulatedLocation(
          position: Geographic(lat: position.latitude, lon: position.longitude),
          accuracy: position.accuracy,
          timestamp: position.timestamp,
        ));
      },
      onError: (Object error) {
        // GPS errors are non-fatal — stream stops emitting, app falls back
        // to last known position. Error handling UI is #10.
      },
    );
  }

  void stop() {
    _geolocatorSubscription?.cancel();
    _geolocatorSubscription = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
