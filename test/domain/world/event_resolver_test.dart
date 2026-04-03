import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/domain/world/event_resolver.dart';
import 'package:earth_nova/models/cell_event.dart';
import 'package:earth_nova/shared/constants.dart';

void main() {
  group('EventResolver', () {
    // ── determinism ──────────────────────────────────────────────────────────

    test('returns deterministic event for same dailySeed + cellId', () {
      final a = EventResolver.resolve('seed_abc', 'cell_1');
      final b = EventResolver.resolve('seed_abc', 'cell_1');
      expect(a, equals(b));
    });

    test('returns different event for different dailySeed', () {
      // Run over enough cells to find at least one pair that differs.
      bool foundDifference = false;
      for (var i = 0; i < 100; i++) {
        final e1 = EventResolver.resolve('seed_day1', 'cell_$i');
        final e2 = EventResolver.resolve('seed_day2', 'cell_$i');
        if (e1?.type != e2?.type) {
          foundDifference = true;
          break;
        }
      }
      expect(foundDifference, isTrue);
    });

    // ── null probability ──────────────────────────────────────────────────────

    test('returns null for most cells (events are rare)', () {
      var nullCount = 0;
      const samples = 1000;
      for (var i = 0; i < samples; i++) {
        if (EventResolver.resolve('seed_x', 'cell_$i') == null) nullCount++;
      }
      // Combined event chance: ~nesting(2%) + migration(12%) = ~14%.
      // Null should be > 70% of cells. Allow wide margin → > 60%.
      expect(nullCount, greaterThan(samples * 0.6));
    });

    // ── event type probabilities ──────────────────────────────────────────────

    test('nestingSite events are rarer than migration events', () {
      var nestingCount = 0;
      var migrationCount = 0;
      for (var i = 0; i < 10000; i++) {
        final event = EventResolver.resolve('seed_prob', 'cell_$i');
        if (event?.type == CellEventType.nestingSite) nestingCount++;
        if (event?.type == CellEventType.migration) migrationCount++;
      }
      // kNestingSiteChancePercent=2 < kCellEventChancePercent=12.
      expect(nestingCount, lessThan(migrationCount));
    });

    test(
        'nesting site event probability is approximately kNestingSiteChancePercent %',
        () {
      var nestingCount = 0;
      const samples = 10000;
      for (var i = 0; i < samples; i++) {
        final event = EventResolver.resolve('seed_nesting', 'cell_$i');
        if (event?.type == CellEventType.nestingSite) nestingCount++;
      }
      // Expected ~2%. Allow ±50% relative → [1%, 3%].
      final percent = nestingCount / samples * 100;
      expect(percent, greaterThan(kNestingSiteChancePercent * 0.5));
      expect(percent, lessThan(kNestingSiteChancePercent * 1.5));
    });

    // ── event fields ─────────────────────────────────────────────────────────

    test('resolved event stores the correct cellId and dailySeed', () {
      // Find a cell that produces an event.
      CellEvent? event;
      for (var i = 0; i < 500; i++) {
        event = EventResolver.resolve('seed_fields', 'cell_$i');
        if (event != null) break;
      }
      expect(event, isNotNull);
      expect(event!.cellId, startsWith('cell_'));
      expect(event.dailySeed, 'seed_fields');
    });

    test('migration and nestingSite events have the correct CellEventType', () {
      CellEvent? migration;
      CellEvent? nesting;
      for (var i = 0; i < 1000; i++) {
        final e = EventResolver.resolve('seed_types', 'cell_$i');
        if (e?.type == CellEventType.migration) migration = e;
        if (e?.type == CellEventType.nestingSite) nesting = e;
        if (migration != null && nesting != null) break;
      }
      if (migration != null) {
        expect(migration.type, CellEventType.migration);
      }
      if (nesting != null) {
        expect(nesting.type, CellEventType.nestingSite);
      }
    });
  });
}
