import 'keyboard_location_service.dart';

/// Stub for non-web platforms — construction is not supported.
KeyboardLocationService createKeyboardLocationService() {
  throw UnsupportedError('KeyboardLocationService is only available on web.');
}

/// No-op stub used by [LocationService.setInitialPosition] on non-web
/// platforms. This class is never directly instantiated — it exists so
/// the conditional import has a concrete type for the native target.
class KeyboardLocationStub implements KeyboardLocationService {
  @override
  Never get locationStream => throw UnsupportedError('Stub');
  @override
  void start() => throw UnsupportedError('Stub');
  @override
  void stop() => throw UnsupportedError('Stub');
  @override
  void dispose() => throw UnsupportedError('Stub');
  @override
  void moveStep(double dLat, double dLon) => throw UnsupportedError('Stub');
  @override
  void setPosition(double lat, double lon) => throw UnsupportedError('Stub');
}
