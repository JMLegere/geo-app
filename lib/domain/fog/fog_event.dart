import 'package:earth_nova/models/fog_state.dart';

/// Event emitted when a new cell is added to the visited set.
///
/// Fired by `FogStateResolver` when the player physically enters a cell for
/// the first time. Dynamic computed state changes (e.g. Observed → Hidden
/// when the player moves away) do NOT emit events — they are derived on
/// demand via `FogStateResolver.resolve()`.
/// Listeners (view layer, persistence, analytics) react independently.
class FogStateChangedEvent {
  final String cellId;
  final FogState oldState;
  final FogState newState;
  final DateTime timestamp;

  FogStateChangedEvent({
    required this.cellId,
    required this.oldState,
    required this.newState,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'FogStateChangedEvent(cellId: $cellId, $oldState → $newState, '
      'at: ${timestamp.toIso8601String()})';
}
