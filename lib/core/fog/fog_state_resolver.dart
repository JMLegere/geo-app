import 'dart:async';
import 'dart:math';

import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/fog/fog_event.dart';
import 'package:earth_nova/core/models/fog_state.dart';
import 'package:earth_nova/shared/constants.dart';
import 'package:flutter/foundation.dart';

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
/// | 4        | Unexplored   | Frontier cell OR within [kAwarenessRadiusMeters]   | 0.75        |
/// | 5        | Undetected   | >50 km from player and none of the above           | 1.0         |
///
/// ## Key behaviours
///
/// - **Dynamic state**: Leaving a cell transitions it from Observed → Hidden
///   the moment the player moves away. This is not a bug — it's the design.
/// - **No forward-only constraint**: States can go "backward" because they
///   are computed, not stored.
/// - **50 km detection**: On every [onLocationUpdate] call, cells within
///   [kAwarenessRadiusMeters] that are not already Observed/Concealed/Hidden/
///   frontier resolve as [FogState.detected] via [resolve].
/// - **Event emission**: [onVisitedCellAdded] fires only when a NEW cell is
///   added to [visitedCellIds]. Dynamic state changes never emit events.
class FogStateResolver {
  final CellService _cellService;

  /// Cells the player has physically entered. The ONLY persisted data.
  final Set<String> _visitedCellIds = {};

  /// Cells adjacent to any visited cell, minus visited cells themselves.
  /// Maintained incrementally on each new cell visit.
  final Set<String> _visitedPerimeter = {};

  /// All cells that have ever resolved as anything other than undetected.
  /// Once a cell is detected (via proximity, frontier, or visit), it stays
  /// at least [FogState.detected] permanently — fog never re-closes.
  final Set<String> _knownCellIds = {};

  /// The cell containing the player, or null before any location update.
  String? _currentCellId;

  /// Immediate neighbors of [_currentCellId].
  Set<String> _adjacentCellIds = {};

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
  Set<String> get adjacentCellIds => Set.unmodifiable(_adjacentCellIds);

  /// Immutable view of all cell IDs the player has physically entered.
  Set<String> get visitedCellIds => Set.unmodifiable(_visitedCellIds);

  /// Cells adjacent to any visited cell, minus visited cells themselves.
  ///
  /// Represents the visited perimeter — cells the player has detected
  /// but never physically entered. Maintained incrementally.
  Set<String> get visitedPerimeter => Set.unmodifiable(_visitedPerimeter);

  /// Computes and returns the [FogState] for [cellId] based on the current
  /// player position and visit history.
  ///
  /// State is NOT stored — repeated calls may return different results as the
  /// player moves. See the class-level priority table for resolution order.
  FogState resolve(String cellId) {
    if (cellId == _currentCellId) {
      _knownCellIds.add(cellId);
      return FogState.active;
    }
    if (_visitedCellIds.contains(cellId)) {
      _knownCellIds.add(cellId);
      return FogState.visited;
    }
    if (_adjacentCellIds.contains(cellId)) {
      _knownCellIds.add(cellId);
      return FogState.nearby;
    }
    if (_visitedPerimeter.contains(cellId)) {
      _knownCellIds.add(cellId);
      return FogState.detected;
    }
    if (isCellWithinAwarenessRadius(cellId)) {
      _knownCellIds.add(cellId);
      return FogState.detected;
    }
    // Once detected, a cell never reverts to undetected.
    if (_knownCellIds.contains(cellId)) return FogState.detected;
    return FogState.unknown;
  }

  /// Core game-loop entry point. Called on every player location update.
  ///
  /// 1. Stores the current player position for distance calculations.
  /// 2. Resolves the current cell and its immediate neighbors.
  /// 3. If the current cell is new (first visit), adds it to [visitedCellIds],
  ///    updates [visitedPerimeter], and emits a [FogStateChangedEvent] with
  ///    [FogState.active] (player is physically present).
  void onLocationUpdate(double lat, double lon) {
    _playerLat = lat;
    _playerLon = lon;

    final newCellId = _cellService.getCellId(lat, lon);
    _currentCellId = newCellId;
    _adjacentCellIds = _cellService.getNeighborIds(newCellId).toSet();

    if (!_visitedCellIds.contains(newCellId)) {
      _markCellEntered(newCellId, FogState.active);
    }
  }

  /// Marks [cellId] as visited without moving the player's position.
  ///
  /// Used for remote exploration (e.g., step spending) where the player
  /// spends resources to reveal a frontier cell without physically traveling.
  ///
  /// The cell must be on the [visitedPerimeter] — only cells adjacent to
  /// already-visited cells can be unlocked remotely. This enforces geographic
  /// reachability: players cannot jump over unexplored territory.
  ///
  /// Emits a [FogStateChangedEvent] with [FogState.visited] (not observed —
  /// the player is not physically present). Downstream listeners such as
  /// [DiscoveryService] can react to this event identically to physical visits.
  ///
  /// **Does NOT** modify [currentCellId], [adjacentCellIds], or the stored
  /// player coordinates — the player's position context is unchanged.
  ///
  /// Throws [ArgumentError] if [cellId] is not in [visitedPerimeter].
  /// Silent no-op if [cellId] is already in [visitedCellIds].
  void revealCell(String cellId) {
    // Silent no-op: already visited cells carry no additional state change.
    if (_visitedCellIds.contains(cellId)) return;

    // Enforce frontier constraint: only reachable cells can be revealed.
    if (!_visitedPerimeter.contains(cellId)) {
      throw ArgumentError(
        'Cannot reveal cell: "$cellId" is not in the visited perimeter. '
        'Only cells adjacent to visited cells can be revealed.',
      );
    }

    // Remote visit = hidden (player is not there — just revealed).
    _markCellEntered(cellId, FogState.visited);
  }

  /// Restores visited cells from persistence.
  ///
  /// Call once at startup before any [onLocationUpdate] calls. Clears all
  /// existing in-memory state and recomputes [visitedPerimeter].
  /// Does NOT emit events for the restored cells.
  void loadVisitedCells(Set<String> cells) {
    _visitedCellIds.clear();
    _visitedPerimeter.clear();
    _knownCellIds.clear();

    for (final cellId in cells) {
      _visitedCellIds.add(cellId);
      _knownCellIds.add(cellId);
      // Do NOT add to visitedPerimeter yet — wait until all visited cells
      // are loaded to avoid re-adding visited cells as perimeter.
    }

    // Build perimeter from scratch after loading all visited cells.
    // Perimeter cells are also "known".
    for (final cellId in _visitedCellIds) {
      for (final neighbor in _cellService.getNeighborIds(cellId)) {
        if (!_visitedCellIds.contains(neighbor)) {
          _visitedPerimeter.add(neighbor);
          _knownCellIds.add(neighbor);
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

  /// Returns true if [cellId] is within [kAwarenessRadiusMeters] of the player.
  ///
  /// Returns false if no location update has been made yet.
  bool isCellWithinAwarenessRadius(String cellId) {
    return distanceToCell(cellId) <= kAwarenessRadiusMeters;
  }

  /// Releases the stream controller. Call when this resolver is no longer needed.
  void dispose() {
    _streamController.close();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Shared cell-enter logic called by both [onLocationUpdate] and
  /// [revealCell].
  ///
  /// Adds [cellId] to [visitedCellIds], removes it from
  /// [visitedPerimeter], expands the perimeter with [cellId]'s unvisited
  /// neighbors, and emits a [FogStateChangedEvent] with [newState].
  ///
  /// The caller is responsible for the perimeter/visited pre-check: this
  /// method assumes [cellId] is not already in [visitedCellIds].
  void _markCellEntered(String cellId, FogState newState) {
    // Capture old computed state before mutating the visited set.
    final wasInPerimeter = _visitedPerimeter.contains(cellId);
    final oldState = wasInPerimeter ? FogState.detected : FogState.unknown;

    _visitedCellIds.add(cellId);
    _visitedPerimeter.remove(cellId);

    for (final neighbor in _cellService.getNeighborIds(cellId)) {
      if (!_visitedCellIds.contains(neighbor)) {
        _visitedPerimeter.add(neighbor);
      }
    }

    debugPrint(
        '[FOG] cell_entered cell=$cellId old=${oldState.name} new=${newState.name} perimeter=${_visitedPerimeter.length}');
    _streamController.add(
      FogStateChangedEvent(
        cellId: cellId,
        oldState: oldState,
        newState: newState,
      ),
    );
  }

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
