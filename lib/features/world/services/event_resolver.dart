import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:earth_nova/shared/constants.dart';
import 'package:earth_nova/core/models/cell_event.dart';

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
  /// Two independent checks with separate hash keys:
  /// - Nesting site: ~[kNestingSiteChancePercent]% of cells (guaranteed EN/CR/EX).
  /// - Migration: ~[kCellEventChancePercent]% of cells (foreign-continent species).
  ///
  /// Nesting sites are checked first and take priority. Each uses its own
  /// domain-separated hash so the two events are statistically independent.
  static CellEvent? resolve(String dailySeed, String cellId) {
    // Check for nesting site first (rarer — guarantees rare species).
    final nestingHash =
        sha256.convert(utf8.encode('${dailySeed}_nesting_$cellId')).bytes;
    final nestingChance = ((nestingHash[0] << 24) |
            (nestingHash[1] << 16) |
            (nestingHash[2] << 8) |
            nestingHash[3]) &
        0x7FFFFFFF;
    if (nestingChance % 100 < kNestingSiteChancePercent) {
      return CellEvent(
        type: CellEventType.nestingSite,
        cellId: cellId,
        dailySeed: dailySeed,
      );
    }

    // Check for migration event.
    final migrationHash =
        sha256.convert(utf8.encode('${dailySeed}_migration_$cellId')).bytes;
    final migrationChance = ((migrationHash[0] << 24) |
            (migrationHash[1] << 16) |
            (migrationHash[2] << 8) |
            migrationHash[3]) &
        0x7FFFFFFF;
    if (migrationChance % 100 < kCellEventChancePercent) {
      return CellEvent(
        type: CellEventType.migration,
        cellId: cellId,
        dailySeed: dailySeed,
      );
    }

    return null;
  }
}
