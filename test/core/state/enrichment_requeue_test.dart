import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/core/state/enrichment_consumer.dart';
import 'package:earth_nova/shared/constants.dart';

void main() {
  group('partitionEnrichmentCandidates', () {
    // --- Startup cap behaviour ---

    test('all ids in startup when total ≤ cap', () {
      final result = partitionEnrichmentCandidates(
        unenrichedIds: {'fauna_a', 'fauna_b', 'fauna_c'},
        incompleteIds: {},
      );
      expect(result.startup, hasLength(3));
      expect(result.deferred, isEmpty);
    });

    test('startup capped at kStartupEnrichmentCap when total > cap', () {
      // 15 unenriched → 10 startup, 5 deferred
      final unenriched = Set<String>.from(List.generate(15, (i) => 'fauna_$i'));
      final result = partitionEnrichmentCandidates(
        unenrichedIds: unenriched,
        incompleteIds: {},
      );
      expect(result.startup, hasLength(kStartupEnrichmentCap));
      expect(result.deferred, hasLength(5));
    });

    test('startup + deferred covers all ids (no loss)', () {
      final unenriched =
          Set<String>.from(List.generate(8, (i) => 'unenriched_$i'));
      final incomplete =
          Set<String>.from(List.generate(7, (i) => 'incomplete_$i'));
      final result = partitionEnrichmentCandidates(
        unenrichedIds: unenriched,
        incompleteIds: incomplete,
      );
      final all = <String>{...result.startup, ...result.deferred};
      expect(all.length, 15);
      expect(result.startup.length + result.deferred.length, 15);
    });

    test('empty input produces empty startup and deferred', () {
      final result = partitionEnrichmentCandidates(
        unenrichedIds: {},
        incompleteIds: {},
      );
      expect(result.startup, isEmpty);
      expect(result.deferred, isEmpty);
    });

    // --- Priority ordering ---

    test('unenriched ids appear before incomplete ids in startup', () {
      // cap=1: the slot must go to the unenriched species, not the incomplete
      final result = partitionEnrichmentCandidates(
        unenrichedIds: {'fauna_never_enriched'},
        incompleteIds: {'fauna_missing_size'},
        cap: 1,
      );
      expect(result.startup, contains('fauna_never_enriched'));
      expect(result.deferred, contains('fauna_missing_size'));
    });

    test('incomplete ids deferred when unenriched fills cap', () {
      final unenriched = Set<String>.from(
          List.generate(kStartupEnrichmentCap, (i) => 'unenriched_$i'));
      final result = partitionEnrichmentCandidates(
        unenrichedIds: unenriched,
        incompleteIds: {'fauna_with_no_size'},
      );
      // All 10 startup slots taken by unenriched; incomplete goes to deferred.
      expect(result.startup, hasLength(kStartupEnrichmentCap));
      expect(result.deferred, contains('fauna_with_no_size'));
    });

    // --- Custom cap ---

    test('cap=0 puts all ids in deferred', () {
      final result = partitionEnrichmentCandidates(
        unenrichedIds: {'a', 'b'},
        incompleteIds: {'c'},
        cap: 0,
      );
      expect(result.startup, isEmpty);
      expect(result.deferred, hasLength(3));
    });

    test('cap larger than total puts all in startup', () {
      final result = partitionEnrichmentCandidates(
        unenrichedIds: {'x', 'y'},
        incompleteIds: {'z'},
        cap: 100,
      );
      expect(result.startup, hasLength(3));
      expect(result.deferred, isEmpty);
    });
  });

  group('deferred drain batch logic', () {
    // Validates the drain-per-tick logic (List.removeRange + take) used
    // inside _requeueUnenrichedSpecies without needing a real Timer.

    test('first drain tick processes kDeferredEnrichmentBatchSize items', () {
      final queue = List<String>.generate(12, (i) => 'fauna_$i');
      final processed = <String>[];

      // Simulate one drain tick.
      final batchSize = queue.length.clamp(0, kDeferredEnrichmentBatchSize);
      processed.addAll(queue.take(batchSize));
      queue.removeRange(0, batchSize);

      expect(processed, hasLength(kDeferredEnrichmentBatchSize));
      expect(queue, hasLength(12 - kDeferredEnrichmentBatchSize));
    });

    test(
        'two drain ticks fully drains a queue of 2×kDeferredEnrichmentBatchSize',
        () {
      final total = kDeferredEnrichmentBatchSize * 2;
      final queue = List<String>.generate(total, (i) => 'fauna_$i');
      final processed = <String>[];

      for (var tick = 0; tick < 2; tick++) {
        final batchSize = queue.length.clamp(0, kDeferredEnrichmentBatchSize);
        processed.addAll(queue.take(batchSize));
        queue.removeRange(0, batchSize);
      }

      expect(processed, hasLength(total));
      expect(queue, isEmpty);
    });

    test('partial last batch drains remaining items without error', () {
      // 7 items: first tick takes 5, second tick takes 2.
      final queue = List<String>.generate(7, (i) => 'fauna_$i');
      final processed = <String>[];

      for (var tick = 0; tick < 2; tick++) {
        if (queue.isEmpty) break;
        final batchSize = queue.length.clamp(0, kDeferredEnrichmentBatchSize);
        processed.addAll(queue.take(batchSize));
        queue.removeRange(0, batchSize);
      }

      expect(processed, hasLength(7));
      expect(queue, isEmpty);
    });

    test('drain tick is a no-op on empty queue', () {
      final queue = <String>[];
      final processed = <String>[];

      // Should not throw on empty queue.
      if (queue.isNotEmpty) {
        final batchSize = queue.length.clamp(0, kDeferredEnrichmentBatchSize);
        processed.addAll(queue.take(batchSize));
        queue.removeRange(0, batchSize);
      }

      expect(processed, isEmpty);
    });
  });

  group('constants', () {
    test('kStartupEnrichmentCap is 10', () {
      expect(kStartupEnrichmentCap, 10);
    });

    test('kDeferredEnrichmentBatchSize is 5', () {
      expect(kDeferredEnrichmentBatchSize, 5);
    });

    test('kDeferredEnrichmentIntervalSeconds is 30', () {
      expect(kDeferredEnrichmentIntervalSeconds, 30);
    });

    test('batch size is less than cap (drain smaller than startup)', () {
      expect(kDeferredEnrichmentBatchSize, lessThan(kStartupEnrichmentCap));
    });
  });
}
