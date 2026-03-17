import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/world/services/event_resolver.dart';
import 'package:earth_nova/core/models/cell_event.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Determinism
  // ---------------------------------------------------------------------------

  group('EventResolver determinism', () {
    test('same seed + same cell = same result', () {
      final a = EventResolver.resolve('seed_2026_03_10', 'v_42_17');
      final b = EventResolver.resolve('seed_2026_03_10', 'v_42_17');

      if (a == null) {
        expect(b, isNull);
      } else {
        expect(b, isNotNull);
        expect(b!.type, equals(a.type));
        expect(b.cellId, equals(a.cellId));
        expect(b.dailySeed, equals(a.dailySeed));
      }
    });

    test('different seed + same cell = potentially different result', () {
      // Run across many seeds — at least one should differ
      final results = <CellEvent?>{};
      for (var i = 0; i < 50; i++) {
        results.add(EventResolver.resolve('seed_$i', 'v_42_17'));
      }
      // With 50 trials, we should have both null and non-null results
      expect(results.contains(null), isTrue,
          reason: 'Expected some cells to have no event');
      expect(results.any((e) => e != null), isTrue,
          reason: 'Expected some cells to have events');
    });

    test('same seed + different cell = potentially different result', () {
      final results = <CellEvent?>{};
      for (var i = 0; i < 50; i++) {
        results.add(EventResolver.resolve('fixed_seed', 'v_${i}_0'));
      }
      expect(results.contains(null), isTrue);
      expect(results.any((e) => e != null), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Event distribution
  // ---------------------------------------------------------------------------

  group('EventResolver distribution', () {
    test('~12% of cells have events (within tolerance)', () {
      var eventCount = 0;
      const trials = 10000;

      for (var i = 0; i < trials; i++) {
        if (EventResolver.resolve('test_seed', 'cell_$i') != null) {
          eventCount++;
        }
      }

      final percentage = eventCount / trials * 100;
      // 12% ± 3% tolerance (statistically 3σ for this sample size)
      expect(percentage, greaterThan(9.0),
          reason: 'Event rate $percentage% is too low (expected ~12%)');
      expect(percentage, lessThan(15.0),
          reason: 'Event rate $percentage% is too high (expected ~12%)');
    });

    test('all event types appear with roughly equal frequency', () {
      final typeCounts = <CellEventType, int>{};
      for (final t in CellEventType.values) {
        typeCounts[t] = 0;
      }

      const trials = 50000;
      for (var i = 0; i < trials; i++) {
        final event = EventResolver.resolve('dist_seed', 'cell_$i');
        if (event != null) {
          typeCounts[event.type] = typeCounts[event.type]! + 1;
        }
      }

      // All types should appear
      for (final t in CellEventType.values) {
        expect(typeCounts[t]!, greaterThan(0),
            reason: '${t.name} never appeared in $trials trials');
      }

      // Check rough equality — each type should be within 30% of the mean
      final totalEvents = typeCounts.values.reduce((a, b) => a + b);
      final mean = totalEvents / CellEventType.values.length;
      for (final entry in typeCounts.entries) {
        expect(entry.value, greaterThan(mean * 0.7),
            reason:
                '${entry.key.name} count ${entry.value} is too far below mean $mean');
        expect(entry.value, lessThan(mean * 1.3),
            reason:
                '${entry.key.name} count ${entry.value} is too far above mean $mean');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Event properties
  // ---------------------------------------------------------------------------

  group('EventResolver event properties', () {
    test('returned event has correct cellId and dailySeed', () {
      // Find a cell that has an event
      CellEvent? event;
      for (var i = 0; i < 1000; i++) {
        event = EventResolver.resolve('prop_test', 'v_$i');
        if (event != null) break;
      }

      expect(event, isNotNull, reason: 'No event found in 1000 cells');
      expect(event!.dailySeed, equals('prop_test'));
      expect(event.cellId, startsWith('v_'));
    });

    test('event type is a valid CellEventType', () {
      for (var i = 0; i < 100; i++) {
        final event = EventResolver.resolve('type_test', 'cell_$i');
        if (event != null) {
          expect(CellEventType.values, contains(event.type));
        }
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Edge cases
  // ---------------------------------------------------------------------------

  group('EventResolver edge cases', () {
    test('empty seed produces result without crash', () {
      expect(() => EventResolver.resolve('', 'v_0_0'), returnsNormally);
    });

    test('empty cellId produces result without crash', () {
      expect(() => EventResolver.resolve('seed', ''), returnsNormally);
    });

    test('very long seed string works', () {
      final longSeed = 'a' * 10000;
      expect(() => EventResolver.resolve(longSeed, 'v_0_0'), returnsNormally);
    });

    test('offline fallback seed works', () {
      expect(
        () => EventResolver.resolve('offline_no_rotation', 'v_42_17'),
        returnsNormally,
      );
    });
  });
}
