import 'dart:async';
import 'dart:js_interop';
import 'dart:math';

import 'package:geobase/geobase.dart';
import 'package:web/web.dart';

import 'keyboard_location_service.dart';
import 'location_simulator.dart';

KeyboardLocationService createKeyboardLocationService() =>
    _KeyboardLocationWebService();

class _KeyboardLocationWebService implements KeyboardLocationService {
  static const _stepMeters = 10.0;
  static const _earthRadius = 6371000.0;
  static const _tickInterval = Duration(milliseconds: 100);

  Geographic _position = const Geographic(lat: 45.9636, lon: -66.6431);

  final _controller = StreamController<SimulatedLocation>.broadcast();
  final _keysHeld = <String>{};

  JSFunction? _keyDownHandler;
  JSFunction? _keyUpHandler;
  Timer? _ticker;

  @override
  Stream<SimulatedLocation> get locationStream => _controller.stream;

  @override
  void start() {
    _keyDownHandler = _onKeyDown.toJS;
    _keyUpHandler = _onKeyUp.toJS;
    window.addEventListener('keydown', _keyDownHandler);
    window.addEventListener('keyup', _keyUpHandler);
    _ticker = Timer.periodic(_tickInterval, (_) => _tick());

    // Emit initial position immediately so fog overlay renders before any
    // keypress. Without this, the map appears "broken" until the user moves.
    _controller.add(
      SimulatedLocation(position: _position, timestamp: DateTime.now()),
    );
  }

  @override
  void stop() {
    window.removeEventListener('keydown', _keyDownHandler);
    window.removeEventListener('keyup', _keyUpHandler);
    _keyDownHandler = null;
    _keyUpHandler = null;
    _ticker?.cancel();
    _ticker = null;
    _keysHeld.clear();
  }

  @override
  void dispose() {
    stop();
    _controller.close();
  }

  @override
  void moveStep(double dLat, double dLon) {
    _position = Geographic(
      lat: _position.lat + dLat,
      lon: _position.lon + dLon,
    );
    _controller.add(
      SimulatedLocation(position: _position, timestamp: DateTime.now()),
    );
  }

  /// Keys we intercept — movement keys should not reach MapLibre's native
  /// keyboard handler (which pans the map independently and fights our
  /// rubber-band camera system).
  static const _movementKeys = {
    'ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight',
    'w', 'W', 'a', 'A', 's', 'S', 'd', 'D',
  };

  void _onKeyDown(Event e) {
    final key = (e as KeyboardEvent).key;
    if (_movementKeys.contains(key)) {
      e.preventDefault();
    }
    _keysHeld.add(key);
    // ignore: avoid_print
    print('[KEY] ↓ $key  held=${_keysHeld.toList()}');
  }

  void _onKeyUp(Event e) {
    final key = (e as KeyboardEvent).key;
    if (_movementKeys.contains(key)) {
      e.preventDefault();
    }
    _keysHeld.remove(key);
    // ignore: avoid_print
    print('[KEY] ↑ $key  held=${_keysHeld.toList()}');
  }

  void _tick() {
    double dLat = 0;
    double dLon = 0;
    final metersPerDegLat = _earthRadius * (pi / 180.0);
    final metersPerDegLon = metersPerDegLat * cos(_position.lat * pi / 180.0);

    if (_keysHeld.contains('w') || _keysHeld.contains('W') || _keysHeld.contains('ArrowUp')) {
      dLat += _stepMeters / metersPerDegLat;
    }
    if (_keysHeld.contains('s') || _keysHeld.contains('S') || _keysHeld.contains('ArrowDown')) {
      dLat -= _stepMeters / metersPerDegLat;
    }
    if (_keysHeld.contains('a') || _keysHeld.contains('A') || _keysHeld.contains('ArrowLeft')) {
      dLon -= _stepMeters / metersPerDegLon;
    }
    if (_keysHeld.contains('d') || _keysHeld.contains('D') || _keysHeld.contains('ArrowRight')) {
      dLon += _stepMeters / metersPerDegLon;
    }

    if (dLat == 0 && dLon == 0) return;

    _position = Geographic(
      lat: _position.lat + dLat,
      lon: _position.lon + dLon,
    );

    _controller.add(
      SimulatedLocation(position: _position, timestamp: DateTime.now()),
    );
  }
}
