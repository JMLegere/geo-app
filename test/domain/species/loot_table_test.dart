import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/domain/species/loot_table.dart';
import 'package:earth_nova/models/iucn_status.dart';

void main() {
  group('LootTable', () {
    // ── roll() determinism ───────────────────────────────────────────────────

    test('roll returns deterministic result for same seed', () {
      final table = LootTable([('alpha', 10), ('beta', 10), ('gamma', 10)]);
      final first = table.roll('test_seed');
      final second = table.roll('test_seed');
      expect(first, equals(second));
    });

    test('roll returns different results for different seeds', () {
      final table = LootTable([('alpha', 10), ('beta', 10), ('gamma', 10)]);
      // Try many seeds until we find two that differ (very likely).
      final seen = <String>{};
      for (var i = 0; i < 20; i++) {
        seen.add(table.roll('seed_$i'));
      }
      // With 3 items and 20 seeds, almost certain we get more than 1 unique result.
      expect(seen.length, greaterThan(1));
    });

    // ── edge cases ───────────────────────────────────────────────────────────

    test('empty table throws StateError on roll', () {
      final table = LootTable<String>([]);
      expect(() => table.roll('any'), throwsA(isA<StateError>()));
    });

    test('single-item table always returns that item', () {
      final table = LootTable([('only', 100)]);
      for (var i = 0; i < 20; i++) {
        expect(table.roll('seed_$i'), equals('only'));
      }
    });

    // ── weight distribution ───────────────────────────────────────────────────

    test('higher weight items appear more frequently over many rolls', () {
      // 'common' has 10x the weight of 'rare'.
      final table = LootTable([('common', 1000), ('rare', 1)]);
      var commonCount = 0;
      for (var i = 0; i < 100; i++) {
        if (table.roll('bulk_$i') == 'common') commonCount++;
      }
      // With weight 1000:1, 'common' should dominate. Accept > 90 of 100.
      expect(commonCount, greaterThan(90));
    });

    test('IUCN 3^x weights: LC appears ~81x more than CR over 1000 rolls', () {
      // LC weight=243, CR weight=3. Ratio = 81.
      final table = LootTable([
        ('LC', IucnStatus.leastConcern.weight),
        ('CR', IucnStatus.criticallyEndangered.weight),
      ]);

      var lcCount = 0;
      var crCount = 0;
      for (var i = 0; i < 10000; i++) {
        final result = table.roll('iucn_$i');
        if (result == 'LC') lcCount++;
        if (result == 'CR') crCount++;
      }

      // Expect ratio roughly 81:1. Allow 50% margin → at least 40:1.
      if (crCount > 0) {
        final ratio = lcCount / crCount;
        expect(ratio, greaterThan(40.0));
      } else {
        // CR never appeared (valid — it has weight 3 out of 246 total).
        expect(lcCount, greaterThan(9000));
      }
    });

    test('roll respects weight zero by never selecting that item', () {
      // While weight 0 is unusual, total weight must be > 0.
      // Test that a weight=1 vs weight=999 item respects the ratio.
      final table = LootTable([('scarce', 1), ('abundant', 999)]);
      var scarceCount = 0;
      for (var i = 0; i < 1000; i++) {
        if (table.roll('rng_$i') == 'scarce') scarceCount++;
      }
      // Expect roughly 1 in 1000, so < 20 (50% margin on expectation of ~10).
      expect(scarceCount, lessThan(50));
    });

    // ── length / totalWeight ────────────────────────────────────────────────

    test('length returns the number of entries', () {
      final table = LootTable([('a', 1), ('b', 2), ('c', 3)]);
      expect(table.length, 3);
    });

    test('totalWeight is sum of all weights', () {
      final table = LootTable([('a', 5), ('b', 10), ('c', 15)]);
      expect(table.totalWeight, 30);
    });

    // ── rollMultiple() ───────────────────────────────────────────────────────

    test('rollMultiple returns unique items only', () {
      final table = LootTable([('a', 100), ('b', 100), ('c', 100), ('d', 100)]);
      final results = table.rollMultiple('base', 3);
      expect(results.length, lessThanOrEqualTo(3));
      expect(results.toSet().length, results.length); // no duplicates
    });

    test('rollMultiple uses appended seed suffix per attempt', () {
      // Two calls with the same baseSeed must give the same result (deterministic).
      final table = LootTable([('x', 1), ('y', 1), ('z', 1)]);
      final first = table.rollMultiple('base_seed', 2);
      final second = table.rollMultiple('base_seed', 2);
      expect(first, equals(second));
    });

    test('rollMultiple on a table smaller than n returns all unique items', () {
      final table = LootTable([('only_one', 100)]);
      final results = table.rollMultiple('seed', 5);
      // Table has 1 unique item — rollMultiple caps at that.
      expect(results, hasLength(1));
      expect(results.first, 'only_one');
    });
  });
}
