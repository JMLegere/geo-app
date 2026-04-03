import 'dart:convert';
import 'package:crypto/crypto.dart';

/// A generic Path of Exile-style weighted loot table.
///
/// Items have weights — higher weight = more likely to be selected.
/// Selection is deterministic when seeded (same seed → same result).
///
/// Typical usage with IUCN weights:
/// ```dart
/// final table = LootTable<FaunaDefinition>(
///   species.map((s) => (s, s.rarity!.weight)).toList(),
/// );
/// final result = table.roll('cell_x123_y456');
/// ```
class LootTable<T> {
  final List<(T item, int weight)> _entries;
  final int _totalWeight;

  LootTable(List<(T item, int weight)> entries)
      : _entries = List.unmodifiable(entries),
        _totalWeight = entries.fold(0, (sum, e) => sum + e.$2);

  /// Number of entries in the table.
  int get length => _entries.length;

  /// Total weight across all entries.
  int get totalWeight => _totalWeight;

  /// Roll the loot table once with a deterministic seed.
  ///
  /// Uses SHA-256 hash of [seed] to generate a deterministic random value,
  /// then walks the weighted entries to find the selected item.
  T roll(String seed) {
    if (_entries.isEmpty) throw StateError('Cannot roll an empty loot table');
    if (_totalWeight <= 0) throw StateError('Total weight must be positive');

    final hash = sha256.convert(utf8.encode(seed)).bytes;
    // Use first 4 bytes as a 32-bit unsigned int, mod totalWeight.
    // Mask with 0x7FFFFFFF to ensure positive value.
    final value =
        ((hash[0] << 24) | (hash[1] << 16) | (hash[2] << 8) | hash[3]) &
            0x7FFFFFFF;
    final roll = value % _totalWeight;

    var cumulative = 0;
    for (final (item, weight) in _entries) {
      cumulative += weight;
      if (roll < cumulative) return item;
    }
    // Fallback (shouldn't happen with correct math).
    return _entries.last.$1;
  }

  /// Roll the table [n] times with deterministic seeds.
  ///
  /// Each roll uses "${baseSeed}_$attempt" as its seed.
  /// Returns unique items only (no duplicates). If the table has fewer than
  /// [n] unique items, returns all available unique items.
  List<T> rollMultiple(String baseSeed, int n) {
    final results = <T>[];
    final seen = <T>{};
    var attempt = 0;
    final maxAttempts = n * 10; // prevent infinite loop on small tables

    while (results.length < n && attempt < maxAttempts) {
      final item = roll('${baseSeed}_$attempt');
      if (seen.add(item)) {
        results.add(item);
      }
      attempt++;
    }
    return results;
  }
}
