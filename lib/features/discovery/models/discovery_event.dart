import 'package:fog_of_world/core/models/item_definition.dart';

/// Represents a species discovery triggered when a player enters a new cell.
///
/// [isNew] is true when the species is being added to the collection for the
/// first time, and false when the player has already collected it in a
/// previous cell.
class DiscoveryEvent {
  final FaunaDefinition species;
  final String cellId;
  final bool isNew;
  final DateTime timestamp;

  const DiscoveryEvent({
    required this.species,
    required this.cellId,
    required this.isNew,
    required this.timestamp,
  });

  @override
  String toString() =>
      'DiscoveryEvent(species: ${species.displayName}, cellId: $cellId, '
      'isNew: $isNew, timestamp: ${timestamp.toIso8601String()})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiscoveryEvent &&
        other.species == species &&
        other.cellId == cellId &&
        other.isNew == isNew &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode =>
      Object.hash(species, cellId, isNew, timestamp);
}
