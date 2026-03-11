import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../shared/constants.dart';
import '../models/cell_event.dart';

/// Resolves the rotating daily event for a cell.
///
/// Deterministic: same dailySeed + same cellId = same event (or no event).
/// ~88% of cells have no event. ~12% have one, equally distributed across
/// all [CellEventType] values.
///
/// NOT stateful — all methods are static. No persistence.
class EventResolver {
  EventResolver._();

  /// Resolve event for a cell on a given day.
  ///
  /// Returns null for ~88% of cells (no event). For the ~12% with an event,
  /// the event type is equally distributed across all [CellEventType] values.
  ///
  /// Hash format: `SHA-256(dailySeed + "_event_" + cellId)`
  /// - First 4 bytes → uint32 → chance (% 100). If >= [kCellEventChancePercent], null.
  /// - Next 4 bytes → uint32 → event type index (% values.length).
  static CellEvent? resolve(String dailySeed, String cellId) {
    final hash =
        sha256.convert(utf8.encode('${dailySeed}_event_$cellId')).bytes;

    // First 4 bytes as unsigned 32-bit int (masked positive).
    final chance =
        ((hash[0] << 24) | (hash[1] << 16) | (hash[2] << 8) | hash[3]) &
            0x7FFFFFFF;
    if (chance % 100 >= kCellEventChancePercent) return null;

    // Next 4 bytes for event type selection.
    final typeValue =
        ((hash[4] << 24) | (hash[5] << 16) | (hash[6] << 8) | hash[7]) &
            0x7FFFFFFF;
    final eventIndex = typeValue % CellEventType.values.length;

    return CellEvent(
      type: CellEventType.values[eventIndex],
      cellId: cellId,
      dailySeed: dailySeed,
    );
  }
}
