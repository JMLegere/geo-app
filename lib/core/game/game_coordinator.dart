import 'dart:async';

import 'package:geobase/geobase.dart';
import 'package:uuid/uuid.dart';

import 'package:fog_of_world/core/fog/fog_state_resolver.dart';
import 'package:fog_of_world/core/models/discovery_event.dart';
import 'package:fog_of_world/core/models/item_instance.dart';
import 'package:fog_of_world/core/species/stats_service.dart';
import 'package:fog_of_world/shared/constants.dart';

/// Describes GPS-related error states.
///
/// Mirrors `LocationError` from location_provider.dart but lives in core/
/// to avoid depending on features/.
enum GpsError {
  none,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  lowAccuracy,
}

/// GPS permission status returned by the location service layer.
///
/// Mirrors `GpsPermissionStatus` from real_gps_service.dart but lives in
/// core/ to avoid depending on features/.
enum GpsPermissionResult {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
}

/// Central game logic coordinator. Pure Dart — no Flutter, no Riverpod.
///
/// Runs forever at ProviderScope level. The map screen is a pure renderer
/// that reads from GameCoordinator and pushes `playerPosition` updates.
///
/// ## Dual-Position Model
///
/// | Field              | Source                   | Used for                        |
/// |--------------------|--------------------------|---------------------------------|
/// | `rawGpsPosition`   | GPS stream (1 Hz)        | Rubber-band target, accuracy UI |
/// | `playerPosition`   | Rubber-band (60 fps)     | All game logic — fog, discovery |
///
/// ## Data Flow
///
/// ```
/// GPS (1Hz) → rawGpsPosition
///                  ↓
/// MapScreen reads rawGpsPosition → RubberBand interpolates (60fps)
///                  ↓
/// RubberBand → updatePlayerPosition(lat, lon)
///                  ↓
/// GameCoordinator throttles to ~10Hz → runs fog/discovery/streaks
/// ```
///
/// ## Dependency Architecture
///
/// Accepts feature-layer dependencies as streams and callbacks via
/// constructor. Does NOT import from features/.
class GameCoordinator {
  final FogStateResolver _fogResolver;
  final StatsService _statsService;

  /// Whether the GPS source is real hardware (vs keyboard/simulation).
  final bool isRealGps;

  // ---------------------------------------------------------------------------
  // Dual-position state
  // ---------------------------------------------------------------------------

  Geographic? _rawGpsPosition;
  double _rawGpsAccuracy = 0.0;
  Geographic? _playerPosition;

  /// Raw GPS position from the location service (1 Hz).
  Geographic? get rawGpsPosition => _rawGpsPosition;

  /// Raw GPS accuracy in meters.
  double get rawGpsAccuracy => _rawGpsAccuracy;

  /// Interpolated player position from rubber-band (60 fps).
  /// This is the game's source of truth for fog, discovery, and stats.
  Geographic? get playerPosition => _playerPosition;

  // ---------------------------------------------------------------------------
  // Game tick throttle
  // ---------------------------------------------------------------------------

  /// Frame counter for throttling game logic in [updatePlayerPosition].
  /// Game logic runs at ~10 Hz (every 6th frame at 60 fps).
  int _gameLogicFrame = 0;

  /// Game logic runs every Nth display-update frame (~10 Hz at 60 fps).
  static const _kGameLogicInterval = 6;

  // ---------------------------------------------------------------------------
  // Streams — raw GPS position changes
  // ---------------------------------------------------------------------------

  final StreamController<({Geographic position, double accuracy})>
      _rawGpsController = StreamController<
          ({Geographic position, double accuracy})>.broadcast(sync: true);

  /// Stream of raw GPS position updates. MapScreen subscribes to feed
  /// the rubber-band controller.
  Stream<({Geographic position, double accuracy})> get onRawGpsUpdate =>
      _rawGpsController.stream;

  // ---------------------------------------------------------------------------
  // Output callbacks (wired by provider layer)
  // ---------------------------------------------------------------------------

  /// Called when the official player location should be pushed to
  /// LocationNotifier. Receives (position, accuracy).
  void Function(Geographic position, double accuracy)? onPlayerLocationUpdate;

  /// Called when GPS error state changes (permission, accuracy).
  void Function(GpsError error)? onGpsErrorChanged;

  /// Called when a new cell is visited (fog resolver emits).
  void Function()? onCellVisited;

  /// Called when an item is discovered. Receives the event and the newly
  /// created ItemInstance (with rolled intrinsic affix).
  void Function(DiscoveryEvent event, ItemInstance instance)? onItemDiscovered;

  // ---------------------------------------------------------------------------
  // Stream subscriptions
  // ---------------------------------------------------------------------------

  StreamSubscription<dynamic>? _gpsSubscription;
  StreamSubscription<dynamic>? _discoverySubscription;
  StreamSubscription<dynamic>? _fogCellSubscription;

  bool _started = false;

  // ---------------------------------------------------------------------------
  // Permission check callback
  // ---------------------------------------------------------------------------

  /// Async callback to check GPS permission. Set by the provider layer.
  Future<GpsPermissionResult?> Function()? checkPermission;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

  GameCoordinator({
    required FogStateResolver fogResolver,
    required StatsService statsService,
    this.isRealGps = false,
  })  : _fogResolver = fogResolver,
        _statsService = statsService;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Starts the game loop by subscribing to GPS and discovery streams.
  ///
  /// [gpsStream] — mapped from LocationService by the provider layer.
  /// [discoveryStream] — from DiscoveryService.onDiscovery.
  void start({
    required Stream<({Geographic position, double accuracy})> gpsStream,
    required Stream<DiscoveryEvent> discoveryStream,
  }) {
    if (_started) return;
    _started = true;

    _gpsSubscription = gpsStream.listen(_onRawGpsUpdate);

    _discoverySubscription = discoveryStream.listen(_onDiscovery);

    _fogCellSubscription = _fogResolver.onVisitedCellAdded.listen((_) {
      onCellVisited?.call();
    });

    _checkGpsPermission();
  }

  /// Stops all subscriptions. Can be restarted with [start].
  void stop() {
    _gpsSubscription?.cancel();
    _gpsSubscription = null;
    _discoverySubscription?.cancel();
    _discoverySubscription = null;
    _fogCellSubscription?.cancel();
    _fogCellSubscription = null;
    _gameLogicFrame = 0;
    _started = false;
  }

  /// Permanently releases all resources.
  void dispose() {
    stop();
    _rawGpsController.close();
  }

  /// Whether the game loop is running.
  bool get isStarted => _started;

  // ---------------------------------------------------------------------------
  // Public API — called by MapScreen
  // ---------------------------------------------------------------------------

  /// Called by the rubber-band controller at 60 fps with the interpolated
  /// display position.
  ///
  /// Internally throttles game logic to ~10 Hz. The first call always
  /// processes immediately.
  void updatePlayerPosition(double lat, double lon) {
    _playerPosition = Geographic(lat: lat, lon: lon);

    _gameLogicFrame++;
    if (_gameLogicFrame == 1 || _gameLogicFrame % _kGameLogicInterval == 0) {
      _processGameLogic(lat, lon);
    }
  }

  // ---------------------------------------------------------------------------
  // Private — GPS handling
  // ---------------------------------------------------------------------------

  void _onRawGpsUpdate(({Geographic position, double accuracy}) update) {
    _rawGpsPosition = update.position;
    _rawGpsAccuracy = update.accuracy;

    // Broadcast to MapScreen for rubber-band feeding.
    if (!_rawGpsController.isClosed) {
      _rawGpsController.add(update);
    }

    // GPS accuracy error handling (only for real GPS).
    if (isRealGps) {
      final isLowAccuracy = update.accuracy > kGpsAccuracyThreshold;
      if (isLowAccuracy) {
        onGpsErrorChanged?.call(GpsError.lowAccuracy);
      } else {
        onGpsErrorChanged?.call(GpsError.none);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Private — Discovery handling
  // ---------------------------------------------------------------------------

  static const _uuid = Uuid();

  void _onDiscovery(DiscoveryEvent event) {
    final instanceId = _uuid.v4();
    final intrinsicAffix = _statsService.rollIntrinsicAffix(
      scientificName: event.item.scientificName ?? '',
      instanceSeed: instanceId,
    );
    final instance = ItemInstance(
      id: instanceId,
      definitionId: event.item.id,
      acquiredAt: event.timestamp,
      acquiredInCellId: event.cellId,
      affixes: [intrinsicAffix],
    );
    onItemDiscovered?.call(event, instance);
  }

  // ---------------------------------------------------------------------------
  // Private — Game logic tick (~10 Hz)
  // ---------------------------------------------------------------------------

  void _processGameLogic(double lat, double lon) {
    // 1. Update fog-of-war state using player (marker) position.
    _fogResolver.onLocationUpdate(lat, lon);

    // 2. Push player position as the official location.
    onPlayerLocationUpdate?.call(
      Geographic(lat: lat, lon: lon),
      _rawGpsAccuracy,
    );
  }

  // ---------------------------------------------------------------------------
  // Private — Permission check
  // ---------------------------------------------------------------------------

  Future<void> _checkGpsPermission() async {
    final check = checkPermission;
    if (check == null) return;

    final result = await check();
    if (result == null) return;
    if (!_started) return;

    final error = switch (result) {
      GpsPermissionResult.denied => GpsError.permissionDenied,
      GpsPermissionResult.deniedForever => GpsError.permissionDeniedForever,
      GpsPermissionResult.serviceDisabled => GpsError.serviceDisabled,
      GpsPermissionResult.granted => GpsError.none,
    };

    if (error != GpsError.none) {
      onGpsErrorChanged?.call(error);
    }
  }
}
