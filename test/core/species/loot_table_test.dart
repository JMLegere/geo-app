import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/species/loot_table.dart';

void main() {
  // ---------------------------------------------------------------------------
  // LootTable.roll — determinism
  // ---------------------------------------------------------------------------

  group('LootTable.roll determinism', () {
    test('same seed always produces the same result (100 iterations)', () {
      final table = LootTable<String>([
        ('apple', 50),
        ('banana', 30),
        ('cherry', 20),
      ]);

      final first = table.roll('test_seed');
      for (var i = 0; i < 100; i++) {
        expect(table.roll('test_seed'), equals(first),
            reason: 'Iteration $i: seed produced different result');
      }
    });

    test('different seeds produce different results (statistically)', () {
      final table = LootTable<int>(
        List.generate(100, (i) => (i, 1)),
      );

      final results = <int>{};
      for (var i = 0; i < 50; i++) {
        results.add(table.roll('seed_$i'));
      }
      // With 50 different seeds and 100 items of equal weight,
      // we expect significantly more than 1 unique result.
      expect(results.length, greaterThan(10),
          reason: 'Expected different seeds to produce varied results');
    });

    test('single-entry table always returns that entry', () {
      final table = LootTable<String>([('only', 1)]);
      for (var i = 0; i < 50; i++) {
        expect(table.roll('seed_$i'), equals('only'));
      }
    });

    test('respects weights — high-weight item selected ~proportionally', () {
      // 99% weight on 'common', 1% on 'rare'.
      final table = LootTable<String>([
        ('common', 9900),
        ('rare', 100),
      ]);

      var commonCount = 0;
      const trials = 1000;
      for (var i = 0; i < trials; i++) {
        if (table.roll('trial_$i') == 'common') commonCount++;
      }

      // Expect at least 90% common (true rate is 99%).
      expect(commonCount, greaterThan(900),
          reason: 'common should be selected ~99% of the time');
      // Expect at least 1 rare (not 0 — with 1000 trials this is very likely).
      expect(trials - commonCount, greaterThan(0),
          reason: 'rare should appear occasionally');
    });

    test('throws StateError on empty table', () {
      final table = LootTable<String>([]);
      expect(() => table.roll('seed'), throwsStateError);
    });

    test('deterministic across different LootTable instances with same data',
        () {
      final entries = [('x', 100), ('y', 200), ('z', 50)];
      final tableA = LootTable<String>(entries);
      final tableB = LootTable<String>(entries);

      for (var i = 0; i < 50; i++) {
        expect(tableA.roll('seed_$i'), equals(tableB.roll('seed_$i')),
            reason: 'Two instances with same data should produce same result');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // LootTable.rollMultiple
  // ---------------------------------------------------------------------------

  group('LootTable.rollMultiple', () {
    test('returns unique items (no duplicates)', () {
      final table = LootTable<String>([
        ('a', 100),
        ('b', 100),
        ('c', 100),
        ('d', 100),
        ('e', 100),
      ]);

      final results = table.rollMultiple('seed', 3);
      expect(results.length, equals(results.toSet().length),
          reason: 'rollMultiple should return unique items');
    });

    test('returns at most N items', () {
      final table = LootTable<int>(List.generate(20, (i) => (i, 10)));
      final results = table.rollMultiple('base', 5);
      expect(results.length, lessThanOrEqualTo(5));
    });

    test('returns exactly N items when table is large enough', () {
      final table = LootTable<int>(List.generate(20, (i) => (i, 10)));
      final results = table.rollMultiple('base', 5);
      expect(results.length, equals(5));
    });

    test('returns all items when N > table size', () {
      final table = LootTable<String>([
        ('a', 10),
        ('b', 10),
        ('c', 10),
      ]);

      final results = table.rollMultiple('base', 10);
      // Can't get more than 3 unique items from a 3-item table.
      expect(results.length, equals(3));
      expect(results.toSet(), containsAll(['a', 'b', 'c']));
    });
  });

  // ---------------------------------------------------------------------------
  // Weight distribution — 10^x scaling
  // ---------------------------------------------------------------------------

  group('LootTable weight distribution', () {
    test(
        'LC (100000) appears ~10x more often than NT (10000) over 10,000 rolls',
        () {
      // Two items with LC and NT weights.
      final table = LootTable<String>([
        ('LC', 100000),
        ('NT', 10000),
      ]);

      var lcCount = 0;
      var ntCount = 0;
      const rolls = 10000;

      for (var i = 0; i < rolls; i++) {
        final result = table.roll('dist_$i');
        if (result == 'LC') lcCount++;
        if (result == 'NT') ntCount++;
      }

      // LC should be ~10x more common than NT.
      // With 10,000 rolls: expected LC ≈ 9091, NT ≈ 909.
      // Allow generous bounds to avoid flakiness.
      expect(lcCount, greaterThan(ntCount * 7),
          reason: 'LC weight (100000) should dominate NT weight (10000)');
    });

    test('length and totalWeight reflect the entries', () {
      final table = LootTable<String>([
        ('a', 100000),
        ('b', 10000),
        ('c', 1000),
        ('d', 100),
        ('e', 10),
        ('f', 1),
      ]);

      expect(table.length, equals(6));
      expect(table.totalWeight, equals(111111));
    });
  });
}
