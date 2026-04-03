import 'dart:async';

import 'location_simulator.dart';

import 'keyboard_location_stub.dart'
    if (dart.library.html) 'keyboard_location_web.dart';

abstract class KeyboardLocationService {
  Stream<SimulatedLocation> get locationStream;

  void start();
  void stop();
  void dispose();

  /// Moves position by one step in the given direction.
  /// [dLat] and [dLon] are in degrees.
  void moveStep(double dLat, double dLon);

  /// Sets the current position directly (e.g. restoring from saved state).
  /// Does NOT emit a location event — call [start] to begin streaming.
  void setPosition(double lat, double lon);

  factory KeyboardLocationService() => createKeyboardLocationService();
}
