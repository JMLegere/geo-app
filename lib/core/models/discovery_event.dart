import 'package:fog_of_world/core/models/item_definition.dart';

/// Represents an item discovery triggered when a player enters a new cell.
///
/// [isNew] is true when the item is being added to the collection for the
/// first time, and false when the player has already collected it in a
/// previous cell.
class DiscoveryEvent {
  final ItemDefinition item;
  final String cellId;
  final bool isNew;
  final DateTime timestamp;

  /// Daily seed used for this encounter roll (for server re-derivation).
  final String? dailySeed;

  const DiscoveryEvent({
    required this.item,
    required this.cellId,
    required this.isNew,
    required this.timestamp,
    this.dailySeed,
  });

  @override
  String toString() =>
      'DiscoveryEvent(item: ${item.displayName}, cellId: $cellId, '
      'isNew: $isNew, timestamp: ${timestamp.toIso8601String()})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiscoveryEvent &&
        other.item == item &&
        other.cellId == cellId &&
        other.isNew == isNew &&
        other.timestamp == timestamp &&
        other.dailySeed == dailySeed;
  }

  @override
  int get hashCode => Object.hash(item, cellId, isNew, timestamp, dailySeed);
}
