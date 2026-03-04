import 'dart:async';
import 'dart:math';

import 'package:fog_of_world/core/cells/cell_service.dart';
import 'package:fog_of_world/core/fog/fog_event.dart';
import 'package:fog_of_world/core/models/fog_state.dart';
import 'package:fog_of_world/shared/constants.dart';

/// Computes fog-of-war visibility from player position and visit history.
///
/// Inspired by Civilization/StarCraft fog of war: state is COMPUTED at
/// resolution time, not stored per cell. The only persisted data is the set
/// of cells the player has physically entered ([visitedCellIds]).
///
/// ## Priority table for [resolve]
///
/// | Priority | State        | Condition                                          | Fog Density |
/// |----------|--------------|----------------------------------------------------|-------------|
/// | 1        | Observed     | Player is currently in this cell                   | 0.0         |
/// | 2        | Hidden       | Previously visited, not in current view            | 0.5         |
/// | 3        | Concealed    | Adjacent to player's current cell                  | 0.95        |
/// | 4        | Unexplored   | Frontier cell OR within [kDetectionRadiusMeters]   | 0.75        |
/// | 5        | Undetected   | >50 km from player and none of the above           | 1.0         |
///
/// ## Key behaviours
///
/// - **Dynamic state**: Leaving a cell transitions it from Observed → Hidden
///   the moment the player moves away. This is not a bug — it's the design.
/// - **No forward-only constraint**: States can go "backward" because they
///   are computed, not stored.
/// - **50 km detection**: On every [onLocationUpdate] call, cells within
///   [kDetectionRadiusMeters] that are not already Observed/Concealed/Hidden/
///   frontier resolve as [FogState.unexplored] via [resolve].
/// - **Event emission**: [onVisitedCellAdded] fires only when a NEW cell is
///   added to [visitedCellIds]. Dynamic state changes never emit events.
class FogStateResolver {
  final CellService _cellService;

  /// Cells the player has physically entered. The ONLY persisted data.
  final Set<String> _visitedCellIds = {};

  /// Cells adjacent to any visited cell, minus visited cells themselves.
  /// Maintained incrementally on each new cell visit.
  final Set<String> _explorationFrontier = {};

  /// All cells that have ever resolved as anything other than undetected.
  /// Once a cell is detected (via proximity, frontier, or visit), it stays
  /// at least [FogState.unexplored] permanently — fog never re-closes.
  final Set<String> _everDetectedCellIds = {};

  /// The cell containing the player, or null before any location update.
  String? _currentCellId;

  /// Immediate neighbors of [_currentCellId].
  Set<String> _currentNeighborIds = {};

  /// Current player latitude in degrees, or null before any location update.
  double? _playerLat;

  /// Current player longitude in degrees, or null before any location update.
  double? _playerLon;

  // sync: true ensures events are delivered synchronously during onLocationUpdate,
  // which simplifies both testing (no async needed) and render-loop integration.
  final StreamController<FogStateChangedEvent> _streamController =
      StreamController<FogStateChangedEvent>.broadcast(sync: true);

  FogStateResolver(this._cellService);

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Stream that fires when a new cell is first added to [visitedCellIds].
  ///
  /// Does NOT fire for computed state changes (e.g. Observed → Hidden when
  /// the player moves away). Those are derived on demand via [resolve].
  Stream<FogStateChangedEvent> get onVisitedCellAdded =>
      _streamController.stream;

  /// The cell ID the player is currently in, or null before any location update.
  String? get currentCellId => _currentCellId;

  /// Immediate neighbor cell IDs of the current cell. Empty before any update.
  Set<String> get currentNeighborIds => Set.unmodifiable(_currentNeighborIds);

  /// Immutable view of all cell IDs the player has physically entered.
  Set<String> get visitedCellIds => Set.unmodifiable(_visitedCellIds);

  /// Cells adjacent to any visited cell, minus visited cells themselves.
  ///
  /// Represents the exploration frontier — cells the player has detected
  /// but never physically entered. Maintained incrementally.
  Set<String> get explorationFrontier => Set.unmodifiable(_explorationFrontier);

  /// Computes and returns the [FogState] for [cellId] based on the current
  /// player position and visit history.
  ///
  /// State is NOT stored — repeated calls may return different results as the
  /// player moves. See the class-level priority table for resolution order.
  FogState resolve(String cellId) {
    if (cellId == _currentCellId) {
      _everDetectedCellIds.add(cellId);
      return FogState.observed;
    }
    if (_visitedCellIds.contains(cellId)) {
      _everDetectedCellIds.add(cellId);
      return FogState.hidden;
    }
    if (_currentNeighborIds.contains(cellId)) {
      _everDetectedCellIds.add(cellId);
      return FogState.concealed;
    }
    if (_explorationFrontier.contains(cellId)) {
      _everDetectedCellIds.add(cellId);
      return FogState.unexplored;
    }
    if (isCellWithinDetectionRadius(cellId)) {
      _everDetectedCellIds.add(cellId);
      return FogState.unexplored;
    }
    // Once detected, a cell never reverts to undetected.
    if (_everDetectedCellIds.contains(cellId)) return FogState.unexplored;
    return FogState.undetected;
  }

  /// Core game-loop entry point. Called on every player location update.
  ///
  /// 1. Stores the current player position for distance calculations.
  /// 2. Resolves the current cell and its immediate neighbors.
  /// 3. If the current cell is new (first visit), adds it to [visitedCellIds],
  ///    updates [explorationFrontier], and emits a [FogStateChangedEvent].
  void onLocationUpdate(double lat, double lon) {
    _playerLat = lat;
    _playerLon = lon;

    final newCellId = _cellService.getCellId(lat, lon);
    _currentCellId = newCellId;
    _currentNeighborIds = _cellService.getNeighborIds(newCellId).toSet();

    if (!_visitedCellIds.contains(newCellId)) {
      // Capture old computed state before adding to visited set.
      final wasInFrontier = _explorationFrontier.contains(newCellId);
      final oldState =
          wasInFrontier ? FogState.unexplored : FogState.undetected;

      _visitedCellIds.add(newCellId);
      _explorationFrontier.remove(newCellId);

      for (final neighbor in _cellService.getNeighborIds(newCellId)) {
        if (!_visitedCellIds.contains(neighbor)) {
          _explorationFrontier.add(neighbor);
        }
      }

      // newState is Observed: the cell is now the current cell.
      _streamController.add(
        FogStateChangedEvent(
          cellId: newCellId,
          oldState: oldState,
          newState: FogState.observed,
        ),
      );
    }
  }

  /// Restores visited cells from persistence.
  ///
  /// Call once at startup before any [onLocationUpdate] calls. Clears all
  /// existing in-memory state and recomputes [explorationFrontier].
  /// Does NOT emit events for the restored cells.
  void loadVisitedCells(Set<String> cells) {
    _visitedCellIds.clear();
    _explorationFrontier.clear();
    _everDetectedCellIds.clear();

    for (final cellId in cells) {
      _visitedCellIds.add(cellId);
      _everDetectedCellIds.add(cellId);
      // Do NOT add to explorationFrontier yet — wait until all visited cells
      // are loaded to avoid re-adding visited cells as frontier.
    }

    // Build frontier from scratch after loading all visited cells.
    // Frontier cells are also "ever detected".
    for (final cellId in _visitedCellIds) {
      for (final neighbor in _cellService.getNeighborIds(cellId)) {
        if (!_visitedCellIds.contains(neighbor)) {
          _explorationFrontier.add(neighbor);
          _everDetectedCellIds.add(neighbor);
        }
      }
    }
  }

  /// Returns a copy of [visitedCellIds] for persistence.
  ///
  /// The result can be passed directly to [loadVisitedCells] for a
  /// round-trip restore.
  Set<String> getVisitedCells() => Set.unmodifiable(_visitedCellIds);

  /// Returns the Haversine distance in metres from the current player position
  /// to the center of [cellId].
  ///
  /// Returns [double.infinity] if no location update has been made yet.
  double distanceToCell(String cellId) {
    if (_playerLat == null || _playerLon == null) return double.infinity;
    final center = _cellService.getCellCenter(cellId);
    return _haversine(_playerLat!, _playerLon!, center.lat, center.lon);
  }

  /// Returns true if [cellId] is within [kDetectionRadiusMeters] of the player.
  ///
  /// Returns false if no location update has been made yet.
  bool isCellWithinDetectionRadius(String cellId) {
    return distanceToCell(cellId) <= kDetectionRadiusMeters;
  }

  /// Releases the stream controller. Call when this resolver is no longer needed.
  void dispose() {
    _streamController.close();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Haversine great-circle distance formula.
  ///
  /// Returns the distance in metres between two WGS-84 coordinates.
  /// Earth mean radius used: 6 371 000 m.
  static double _haversine(
    double lat1Deg,
    double lon1Deg,
    double lat2Deg,
    double lon2Deg,
  ) {
    const r = 6371000.0; // Earth mean radius in metres
    final lat1 = lat1Deg * pi / 180.0;
    final lat2 = lat2Deg * pi / 180.0;
    final deltaLat = (lat2Deg - lat1Deg) * pi / 180.0;
    final deltaLon = (lon2Deg - lon1Deg) * pi / 180.0;

    final a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1) * cos(lat2) * sin(deltaLon / 2) * sin(deltaLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }
}
