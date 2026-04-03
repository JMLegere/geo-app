import 'package:earth_nova/models/cell_event.dart';
import 'package:earth_nova/models/item_definition.dart';

/// Represents an item discovery triggered when a player enters a new cell.
///
/// [isNew] is true when the item is being added to the collection for the
/// first time, and false when the player has already collected it in a
/// previous cell.
///
/// [cellEventType] indicates whether the encounter was triggered by a cell
/// event (Migration, Nesting Site) instead of the normal species roll.
/// Null means a normal encounter.
class DiscoveryEvent {
  final ItemDefinition item;
  final String cellId;
  final bool isNew;
  final DateTime timestamp;

  /// Daily seed used for this encounter roll (for server re-derivation).
  final String? dailySeed;

  /// The cell event that triggered this encounter, or null for normal
  /// encounters. Used by the UI to show event-specific feedback
  /// (e.g. "Migration!" banner, nesting site animation).
  final CellEventType? cellEventType;

  const DiscoveryEvent({
    required this.item,
    required this.cellId,
    required this.isNew,
    required this.timestamp,
    this.dailySeed,
    this.cellEventType,
  });

  @override
  String toString() =>
      'DiscoveryEvent(item: ${item.displayName}, cellId: $cellId, '
      'isNew: $isNew, cellEventType: $cellEventType, '
      'timestamp: ${timestamp.toIso8601String()})';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiscoveryEvent &&
        other.item == item &&
        other.cellId == cellId &&
        other.isNew == isNew &&
        other.timestamp == timestamp &&
        other.dailySeed == dailySeed &&
        other.cellEventType == cellEventType;
  }

  @override
  int get hashCode =>
      Object.hash(item, cellId, isNew, timestamp, dailySeed, cellEventType);
}
