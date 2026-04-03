import 'package:geobase/geobase.dart';

import 'package:earth_nova/engine/engine_input.dart';
import 'package:earth_nova/engine/engine_runner.dart';
import 'package:earth_nova/engine/game_engine.dart';
import 'package:earth_nova/engine/game_event.dart';

/// [EngineRunner] that wraps [GameEngine] directly on the main thread.
///
/// This is the only runner for now. When native platforms require it, an
/// isolate-backed runner will move the engine off the UI thread — same
/// [EngineRunner] interface, different transport layer.
///
/// ## Usage
///
/// ```dart
/// final runner = MainThreadEngineRunner(engine);
/// runner.events.listen(_handleEvent);
///
/// // Start GPS + game loop
/// runner.startEngine(gpsStream: locationService.positionStream);
///
/// // Route inputs from rubber-band controller
/// runner.send(PositionUpdate(lat, lon, accuracy));
///
/// // Tear down
/// await runner.dispose();
/// ```
class MainThreadEngineRunner implements EngineRunner {
  MainThreadEngineRunner(this._engine);

  final GameEngine _engine;

  /// The wrapped [GameEngine]. Exposed for transitional use by the provider
  /// layer (e.g. to wire [CellPropertyResolver] after construction).
  /// Prefer [send] and [events] for all other access.
  GameEngine get engine => _engine;

  // ---------------------------------------------------------------------------
  // EngineRunner interface
  // ---------------------------------------------------------------------------

  @override
  Stream<GameEvent> get events => _engine.events;

  @override
  void send(EngineInput input) => _engine.send(input);

  @override
  Future<void> dispose() async => _engine.dispose();

  // ---------------------------------------------------------------------------
  // Lifecycle forwarding
  // ---------------------------------------------------------------------------

  /// Start the engine and subscribe to [gpsStream] for raw GPS updates.
  ///
  /// The rubber-band controller pushes interpolated positions separately
  /// via [send(PositionUpdate)]. The optional [gpsStream] argument is only
  /// needed to feed the raw-GPS broadcast (for the rubber-band target and
  /// GPS accuracy UI).
  void startEngine({
    Stream<({Geographic position, double accuracy})>? gpsStream,
  }) {
    _engine.start(gpsStream: gpsStream);
  }

  /// Stop the engine subscriptions. Can be restarted with [startEngine].
  void stopEngine() => _engine.stop();

  // ---------------------------------------------------------------------------
  // State proxies (convenience; prefer subscribing to [events])
  // ---------------------------------------------------------------------------

  /// Raw GPS position (1 Hz). Null before first GPS fix.
  Geographic? get rawGpsPosition => _engine.rawGpsPosition;

  /// Interpolated player position from rubber-band (60 fps → 10 Hz game logic).
  Geographic? get playerPosition => _engine.playerPosition;

  /// GPS accuracy in metres from the most recent raw fix.
  double get rawGpsAccuracy => _engine.rawGpsAccuracy;

  /// Read-only view of the cell properties cache.
  Map<String, dynamic> get cellPropertiesCache => _engine.cellPropertiesCache;

  /// Whether exploration is disabled (marker cell ≠ GPS cell).
  bool get explorationDisabled => _engine.explorationDisabled;

  /// Whether the engine game loop is currently running.
  bool get isRunning => _engine.isRunning;

  /// Raw GPS position stream (1 Hz). MapScreen subscribes for rubber-band.
  Stream<({Geographic position, double accuracy})> get onRawGpsUpdate =>
      _engine.onRawGpsUpdate;
}
