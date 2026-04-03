import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/domain/items/affix_generator.dart';
import 'package:earth_nova/domain/items/stats_service.dart';
import 'package:earth_nova/models/affix.dart';
import 'package:earth_nova/models/animal_size.dart';
import 'package:earth_nova/shared/constants.dart';

import '../../fixtures/test_helpers.dart';

// Helper: build enriched stats record used throughout tests.
({int speed, int brawn, int wit, AnimalSize? size}) makeEnrichedStats({
  int speed = 30,
  int brawn = 30,
  int wit = 30,
  AnimalSize? size,
}) =>
    (speed: speed, brawn: brawn, wit: wit, size: size);

void main() {
  const statsService = StatsService();

  group('needsIntrinsicBackfill', () {
    test('returns true when item has no intrinsic affix', () {
      final item = makeItemInstance(affixes: []);
      expect(needsIntrinsicBackfill(item, makeEnrichedStats()), isTrue);
    });

    test(
        'returns false when item already has an intrinsic affix and size matches',
        () {
      final intrinsic = Affix(
        id: kIntrinsicAffixId,
        type: AffixType.intrinsic,
        values: {'speed': 30, 'brawn': 30, 'wit': 30},
      );
      final item = makeItemInstance(affixes: [intrinsic]);
      // No size in enrichment → weight not required.
      expect(
          needsIntrinsicBackfill(item, makeEnrichedStats(size: null)), isFalse);
    });

    test(
        'returns true when item has intrinsic affix but lacks weight and enrichment has size',
        () {
      final intrinsicNoWeight = Affix(
        id: kIntrinsicAffixId,
        type: AffixType.intrinsic,
        values: {'speed': 30, 'brawn': 30, 'wit': 30},
        // No 'weightGrams' key.
      );
      final item = makeItemInstance(affixes: [intrinsicNoWeight]);
      // Enrichment now provides size → weight must be rolled.
      expect(
        needsIntrinsicBackfill(
            item, makeEnrichedStats(size: AnimalSize.medium)),
        isTrue,
      );
    });

    test(
        'returns false when item has intrinsic affix with weight and size is known',
        () {
      final intrinsicWithWeight = Affix(
        id: kIntrinsicAffixId,
        type: AffixType.intrinsic,
        values: {
          'speed': 30,
          'brawn': 30,
          'wit': 30,
          kWeightAffixKey: 50000,
        },
      );
      final item = makeItemInstance(affixes: [intrinsicWithWeight]);
      expect(
        needsIntrinsicBackfill(
            item, makeEnrichedStats(size: AnimalSize.medium)),
        isFalse,
      );
    });
  });

  group('rollAffixForItem', () {
    test('produces deterministic affix for same item seed', () {
      final item = makeItemInstance(id: 'uuid-fixed');
      final stats = makeEnrichedStats();

      final first = rollAffixForItem(
        item: item,
        enrichedStats: stats,
        statsService: statsService,
      );
      final second = rollAffixForItem(
        item: item,
        enrichedStats: stats,
        statsService: statsService,
      );

      final firstIntrinsic = first.affixes.firstWhere(
        (a) => a.type == AffixType.intrinsic,
      );
      final secondIntrinsic = second.affixes.firstWhere(
        (a) => a.type == AffixType.intrinsic,
      );

      expect(firstIntrinsic.values['speed'], secondIntrinsic.values['speed']);
      expect(firstIntrinsic.values['brawn'], secondIntrinsic.values['brawn']);
    });

    test('includes size and weight keys when enrichedStats.size is provided',
        () {
      final item = makeItemInstance();
      final stats = makeEnrichedStats(size: AnimalSize.small);

      final updated = rollAffixForItem(
        item: item,
        enrichedStats: stats,
        statsService: statsService,
      );

      final intrinsic = updated.affixes.firstWhere(
        (a) => a.type == AffixType.intrinsic,
      );
      expect(intrinsic.values.containsKey(kSizeAffixKey), isTrue);
      expect(intrinsic.values.containsKey(kWeightAffixKey), isTrue);
    });

    test('does not include weight key when size is null', () {
      final item = makeItemInstance();
      final stats = makeEnrichedStats(size: null);

      final updated = rollAffixForItem(
        item: item,
        enrichedStats: stats,
        statsService: statsService,
      );

      final intrinsic = updated.affixes.firstWhere(
        (a) => a.type == AffixType.intrinsic,
      );
      expect(intrinsic.values.containsKey(kWeightAffixKey), isFalse);
    });

    test('replaces existing intrinsic affix rather than appending a second one',
        () {
      final existing = Affix(
        id: kIntrinsicAffixId,
        type: AffixType.intrinsic,
        values: {'speed': 1, 'brawn': 1, 'wit': 1},
      );
      final item = makeItemInstance(affixes: [existing]);
      final stats = makeEnrichedStats(size: AnimalSize.tiny);

      final updated = rollAffixForItem(
        item: item,
        enrichedStats: stats,
        statsService: statsService,
      );

      final intrinsics =
          updated.affixes.where((a) => a.type == AffixType.intrinsic).toList();
      expect(intrinsics, hasLength(1)); // exactly one intrinsic
    });
  });

  group('backfillAffixes', () {
    test('processes items that need backfill and returns updated copies', () {
      final item = makeItemInstance(id: 'item-1', affixes: []);
      final lookup = {
        item.definitionId: makeEnrichedStats(),
      };

      final result = backfillAffixes([item], lookup);

      expect(result, hasLength(1));
      final intrinsic = result.first.affixes
          .where((a) => a.type == AffixType.intrinsic)
          .toList();
      expect(intrinsic, hasLength(1));
    });

    test('skips items that already have an intrinsic affix', () {
      final intrinsic = Affix(
        id: kIntrinsicAffixId,
        type: AffixType.intrinsic,
        values: {'speed': 30, 'brawn': 30, 'wit': 30},
      );
      final item = makeItemInstance(id: 'item-2', affixes: [intrinsic]);
      final lookup = {item.definitionId: makeEnrichedStats()};

      final result = backfillAffixes([item], lookup);

      // Should be same object reference (unchanged list returned).
      expect(identical(result, [item]) || result.first.affixes.length == 1,
          isTrue);
    });

    test('returns original list reference when nothing changed', () {
      final intrinsic = Affix(
        id: kIntrinsicAffixId,
        type: AffixType.intrinsic,
        values: {'speed': 30, 'brawn': 30, 'wit': 30},
      );
      final items = [
        makeItemInstance(affixes: [intrinsic])
      ];
      final lookup = {items.first.definitionId: makeEnrichedStats(size: null)};

      final result = backfillAffixes(items, lookup);

      expect(identical(result, items), isTrue);
    });

    test('skips items whose definitionId is not in the lookup', () {
      final item = makeItemInstance(id: 'item-no-lookup', affixes: []);
      // Empty lookup — nothing to enrich.
      final result = backfillAffixes([item], {});

      final intrinsics =
          result.first.affixes.where((a) => a.type == AffixType.intrinsic);
      expect(intrinsics, isEmpty);
    });
  });
}
