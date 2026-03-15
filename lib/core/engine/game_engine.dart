import 'dart:async';

import 'package:geobase/geobase.dart';

import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/engine/engine_input.dart';
import 'package:earth_nova/core/services/observability_buffer.dart';
import 'package:earth_nova/core/engine/game_event.dart';
import 'package:earth_nova/core/fog/fog_state_resolver.dart';
import 'package:earth_nova/core/game/game_coordinator.dart';
import 'package:earth_nova/core/models/cell_properties.dart';
import 'package:earth_nova/core/models/discovery_event.dart';
import 'package:earth_nova/core/species/stats_service.dart';

/// Adapter that wraps [GameCoordinator] and converts its callback-based
/// output into a single [GameEvent] stream.
///
/// GameEngine is the new public API. GameCoordinator stays unchanged
/// internally. The engine:
/// 1. Creates a coordinator (composition, not inheritance)
/// 2. Wires all callbacks to emit [GameEvent]s
/// 3. Routes [EngineInput] commands to coordinator methods
/// 4. Owns [ObservabilityBuffer] emission (coordinator gets no obs to avoid
///    double-emission)
class GameEngine {
  final GameCoordinator _coordinator;
  final ObservabilityBuffer? _obs;
  final StreamController<GameEvent> _controller =
      StreamController<GameEvent>.broadcast(sync: true);

  GameEngine({
    required FogStateResolver fogResolver,
    required StatsService statsService,
    required CellService cellService,
    bool isRealGps = false,
    ObservabilityBuffer? obs,
  })  : _obs = obs,
        _coordinator = GameCoordinator(
          fogResolver: fogResolver,
          statsService: statsService,
          cellService: cellService,
          isRealGps: isRealGps,
          // obs intentionally null — engine owns all event emission.
        ) {
    _wireCallbacks();
  }

  // ---------------------------------------------------------------------------
  // Output
  // ---------------------------------------------------------------------------

  /// Single event stream for all game events. Broadcast — multiple consumers
  /// (persistence, UI, analytics) can listen concurrently.
  Stream<GameEvent> get events => _controller.stream;

  // ---------------------------------------------------------------------------
  // Transitional access
  // ---------------------------------------------------------------------------

  /// The wrapped coordinator. Exposed for transitional use by the provider
  /// layer while migration is in progress. Prefer [send] and [events].
  GameCoordinator get coordinator => _coordinator;

  // ---------------------------------------------------------------------------
  // Input
  // ---------------------------------------------------------------------------

  /// Routes an [EngineInput] command to the appropriate coordinator method.
  void send(EngineInput input) {
    try {
      switch (input) {
        case PositionUpdate(:final lat, :final lon):
          _coordinator.updatePlayerPosition(lat, lon);
        case AuthChanged(:final userId):
          _coordinator.setCurrentUserId(userId);
        case CellTapped():
          break; // future: cell interaction
        case AppBackgrounded():
          _obs?.flush();
        case AppResumed():
          break; // future: refresh seed
      }
    } catch (e, stack) {
      _emitCrash(e, stack, 'send(${input.runtimeType})');
    }
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Starts the game loop by subscribing to GPS and discovery streams.
  void start({
    required Stream<({Geographic position, double accuracy})> gpsStream,
    required Stream<DiscoveryEvent> discoveryStream,
  }) {
    _coordinator.start(gpsStream: gpsStream, discoveryStream: discoveryStream);
  }

  /// Stops all subscriptions. Can be restarted with [start].
  void stop() => _coordinator.stop();

  /// Permanently releases all resources.
  void dispose() {
    _coordinator.dispose();
    _obs?.flush();
    _controller.close();
  }

  // ---------------------------------------------------------------------------
  // State proxies
  // ---------------------------------------------------------------------------

  /// Raw GPS position from the location service (1 Hz).
  Geographic? get rawGpsPosition => _coordinator.rawGpsPosition;

  /// Interpolated player position (60 fps rubber-band).
  Geographic? get playerPosition => _coordinator.playerPosition;

  /// Raw GPS accuracy in meters.
  double get rawGpsAccuracy => _coordinator.rawGpsAccuracy;

  /// Read-only cell properties cache.
  Map<String, CellProperties> get cellPropertiesCache =>
      _coordinator.cellPropertiesCache;

  /// Whether exploration is disabled (marker cell ≠ GPS cell).
  bool get explorationDisabled => _coordinator.explorationDisabled;

  /// Whether the game loop is running.
  bool get isStarted => _coordinator.isStarted;

  /// Stream of raw GPS position updates.
  Stream<({Geographic position, double accuracy})> get onRawGpsUpdate =>
      _coordinator.onRawGpsUpdate;

  // ---------------------------------------------------------------------------
  // Private — callback → event wiring
  // ---------------------------------------------------------------------------

  void _wireCallbacks() {
    // onPlayerLocationUpdate fires at ~10Hz — too noisy for structured events.
    // Position data is in locationProvider; no event needed.
    _coordinator.onPlayerLocationUpdate = (position, accuracy) {};

    _coordinator.onCellVisited = (cellId) {
      try {
        _emit(GameEvent.state('cell_visited', {
          'cell_id': cellId,
        }));
      } catch (e, stack) {
        _emitCrash(e, stack, 'onCellVisited');
      }
    };

    _coordinator.onItemDiscovered = (event, instance) {
      try {
        _emit(GameEvent.state('species_discovered', {
          'item_id': instance.id,
          'definition_id': instance.definitionId,
          'display_name': instance.displayName,
          'scientific_name': instance.scientificName,
          'category': instance.category.name,
          'rarity': instance.rarity?.name,
          'cell_id': event.cellId,
          'has_enrichment': instance.affixes.isNotEmpty,
          'affix_count': instance.affixes.length,
          'daily_seed': event.dailySeed,
          'cell_event_type': event.cellEventType?.name,
        }));
      } catch (e, stack) {
        _emitCrash(e, stack, 'onItemDiscovered');
      }
    };

    _coordinator.onGpsErrorChanged = (error) {
      try {
        _emit(GameEvent.system('gps_error_changed', {
          'error': error.name,
        }));
      } catch (e, stack) {
        _emitCrash(e, stack, 'onGpsErrorChanged');
      }
    };

    _coordinator.onCellPropertiesResolved = (properties) {
      try {
        _emit(GameEvent.state('cell_properties_resolved', {
          'cell_id': properties.cellId,
          'habitats': properties.habitats.map((h) => h.name).toList(),
          'climate': properties.climate.name,
          'continent': properties.continent.name,
          'location_id': properties.locationId,
        }));
      } catch (e, stack) {
        _emitCrash(e, stack, 'onCellPropertiesResolved');
      }
    };

    _coordinator.onExplorationDisabledChanged = (disabled) {
      try {
        _emit(GameEvent.system('exploration_disabled_changed', {
          'disabled': disabled,
        }));
      } catch (e, stack) {
        _emitCrash(e, stack, 'onExplorationDisabledChanged');
      }
    };
  }

  /// Emits a [GameEvent] to both the stream controller and the event sink.
  void _emit(GameEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
    _obs?.event(event.event, event.data);
  }

  /// Emits a crash event when a callback handler or send() throws.
  void _emitCrash(Object error, StackTrace stack, String context) {
    _emit(GameEvent.system('crash', {
      'error': error.toString(),
      'stack_trace': stack.toString().split('\n').take(10).join('\n'),
      'context': context,
    }));
  }
}
