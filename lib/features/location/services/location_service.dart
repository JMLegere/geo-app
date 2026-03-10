import 'dart:async';

import 'package:flutter/foundation.dart';

import 'gps_filter.dart';
import 'keyboard_location_service.dart';
import 'location_simulator.dart';
import 'real_gps_service.dart';

enum LocationMode { simulation, realGps, keyboard }

class LocationService {
  final LocationMode mode;
  final LocationSimulator? simulator;
  final KeyboardLocationService? keyboardService;
  final RealGpsService? gpsService;
  final GpsFilter filter;

  /// Tracks the currently active location mode at runtime.
  ///
  /// On web, this starts as [LocationMode.keyboard] and may switch to
  /// [LocationMode.realGps] if the browser grants GPS permission.
  /// UI (e.g. DPad visibility) should listen to this notifier.
  final ValueNotifier<LocationMode> activeModeNotifier;

  /// Web GPS service — created lazily when web attempts GPS fallback.
  RealGpsService? _webGpsService;

  LocationService({
    LocationMode? mode,
    LocationSimulator? simulator,
    KeyboardLocationService? keyboardService,
    RealGpsService? gpsService,
    GpsFilter? filter,
  })  : mode = mode ?? _defaultMode(),
        simulator = simulator ??
            (_resolvedMode(mode) == LocationMode.simulation
                ? LocationSimulator()
                : null),
        keyboardService = keyboardService ??
            (_resolvedMode(mode) == LocationMode.keyboard
                ? KeyboardLocationService()
                : null),
        gpsService = gpsService ??
            (_resolvedMode(mode) == LocationMode.realGps
                ? RealGpsService()
                : null),
        filter = filter ?? GpsFilter(),
        activeModeNotifier = ValueNotifier(mode ?? _defaultMode());

  static LocationMode _defaultMode() =>
      kIsWeb ? LocationMode.keyboard : LocationMode.realGps;

  static LocationMode _resolvedMode(LocationMode? mode) =>
      mode ?? _defaultMode();

  StreamSubscription<SimulatedLocation>? _subscription;
  late final StreamController<SimulatedLocation> _outputController =
      StreamController<SimulatedLocation>.broadcast(
    onCancel: () {},
  );

  bool _isTracking = false;

  Stream<SimulatedLocation> get filteredLocationStream =>
      _outputController.stream;

  bool get isTracking => _isTracking;

  /// Sets the initial position before [start] is called.
  ///
  /// Used to restore the player's last known position from the database.
  /// Only affects keyboard mode (web) — GPS modes use real position.
  void setInitialPosition(double lat, double lon) {
    keyboardService?.setPosition(lat, lon);
  }

  void dispose() {
    stop();
    _outputController.close();
    activeModeNotifier.dispose();
    _webGpsService?.dispose();
  }

  void start() {
    if (_isTracking) return;
    _isTracking = true;

    switch (mode) {
      case LocationMode.simulation:
        final sim = simulator;
        if (sim != null) {
          // Subscribe BEFORE start() — start() may emit an initial position
          // synchronously on a broadcast stream. Subscribing after would lose it.
          _subscription = sim.locationStream
              .map((loc) => filter.filter(loc))
              .where((loc) => loc != null)
              .cast<SimulatedLocation>()
              .listen(_outputController.add);
          sim.start();
        }
      case LocationMode.keyboard:
        final kb = keyboardService;
        if (kb != null) {
          // Subscribe BEFORE start() — start() emits an initial position
          // synchronously on a broadcast stream. Subscribing after would lose it.
          _subscription = kb.locationStream
              .map((loc) => filter.filter(loc))
              .where((loc) => loc != null)
              .cast<SimulatedLocation>()
              .listen(_outputController.add);
          kb.start();

          // On web, attempt real GPS in the background. If granted,
          // switch from keyboard to GPS stream seamlessly.
          if (kIsWeb) {
            _attemptWebGpsFallback();
          }
        }
      case LocationMode.realGps:
        final gps = gpsService;
        if (gps != null) {
          _subscription = gps.locationStream
              .map((loc) => filter.filter(loc))
              .where((loc) => loc != null)
              .cast<SimulatedLocation>()
              .listen(_outputController.add);
          // Fire-and-forget: GPS starts emitting after permission is granted.
          gps.start();
        }
    }
  }

  /// Attempts to use real browser GPS on web.
  ///
  /// Runs async — keyboard keeps working in the meantime.
  /// If GPS permission is granted, cancels keyboard subscription and
  /// switches to GPS stream. If denied, keyboard continues as-is.
  void _attemptWebGpsFallback() {
    _webGpsService = RealGpsService();
    final webGps = _webGpsService!;

    webGps.ensurePermission().then((status) {
      if (status != GpsPermissionStatus.granted) {
        debugPrint('[LocationService] web GPS denied ($status) — '
            'keeping keyboard mode');
        webGps.dispose();
        _webGpsService = null;
        return;
      }

      // GPS granted — switch over.
      debugPrint('[LocationService] web GPS granted — switching from '
          'keyboard to GPS');

      // Stop keyboard.
      _subscription?.cancel();
      _subscription = null;
      keyboardService?.stop();

      // Subscribe to GPS stream.
      _subscription = webGps.locationStream
          .map((loc) => filter.filter(loc))
          .where((loc) => loc != null)
          .cast<SimulatedLocation>()
          .listen(_outputController.add);
      webGps.start();

      activeModeNotifier.value = LocationMode.realGps;
    }).catchError((Object e) {
      debugPrint('[LocationService] web GPS attempt failed: $e — '
          'keeping keyboard mode');
      webGps.dispose();
      _webGpsService = null;
    });
  }

  void stop() {
    if (!_isTracking) return;
    _isTracking = false;

    _subscription?.cancel();
    _subscription = null;

    switch (mode) {
      case LocationMode.simulation:
        simulator?.stop();
      case LocationMode.keyboard:
        keyboardService?.stop();
        _webGpsService?.stop();
      case LocationMode.realGps:
        gpsService?.stop();
    }
  }

  /// Checks GPS permission status without starting the service.
  ///
  /// Returns null for non-GPS modes (simulation, keyboard).
  /// Returns a [GpsPermissionStatus] for real GPS mode.
  Future<GpsPermissionStatus?> checkPermission() async {
    if (mode != LocationMode.realGps) return null;
    return gpsService?.ensurePermission();
  }
}
