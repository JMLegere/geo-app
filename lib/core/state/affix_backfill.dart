import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/models/affix.dart';
import 'package:earth_nova/core/models/animal_size.dart';
import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/core/models/write_queue_entry.dart';
import 'package:earth_nova/core/persistence/item_instance_repository.dart';
import 'package:earth_nova/features/items/services/stats_service.dart';
import 'package:earth_nova/features/items/providers/items_provider.dart';
import 'package:earth_nova/features/sync/services/queue_processor.dart';
import 'package:earth_nova/shared/constants.dart';

/// Check if an item needs intrinsic affix backfill.
///
/// Returns true when EITHER:
/// - Item has no intrinsic affix at all (needs stats + weight)
/// - Item has intrinsic affix but lacks weight AND enrichment now has size
///   (was enriched before size field was added, needs weight rolled)
bool needsIntrinsicBackfill(
  ItemInstance item,
  ({int speed, int brawn, int wit, AnimalSize? size}) enrichedStats,
) {
  final intrinsic = item.affixes.cast<Affix?>().firstWhere(
        (a) => a!.type == AffixType.intrinsic,
        orElse: () => null,
      );

  // No intrinsic affix at all — needs full backfill.
  if (intrinsic == null) return true;

  // Has intrinsic affix but enrichment now has size and item lacks weight.
  if (enrichedStats.size != null &&
      !intrinsic.values.containsKey(kWeightAffixKey)) {
    return true;
  }

  return false;
}

/// Roll an intrinsic affix for a single item and persist the update.
///
/// Shared by both the real-time [onEnriched] path and the startup sweep.
/// Updates: in-memory inventory, SQLite, and write queue.
Future<void> rollAndPersistIntrinsicAffix({
  required ItemInstance item,
  required ({int speed, int brawn, int wit, AnimalSize? size}) enrichedStats,
  required Ref ref,
  required StatsService statsService,
  required ItemInstanceRepository itemRepo,
  required QueueProcessor queueProcessor,
  required String userId,
}) async {
  final baseStats = (
    speed: enrichedStats.speed,
    brawn: enrichedStats.brawn,
    wit: enrichedStats.wit,
  );
  final intrinsic = statsService.rollIntrinsicAffix(
    scientificName: item.scientificName ?? '',
    instanceSeed: item.id,
    enrichedBaseStats: baseStats,
  );

  // If size is known, roll a deterministic weight and merge into affix.
  Affix finalAffix;
  final size = enrichedStats.size;
  if (size != null) {
    final weightGrams = statsService.rollWeightGrams(
      size: size,
      instanceSeed: item.id,
    );
    finalAffix = Affix(
      id: intrinsic.id,
      type: intrinsic.type,
      values: {
        ...intrinsic.values,
        kSizeAffixKey: size.name,
        kWeightAffixKey: weightGrams,
      },
    );
  } else {
    finalAffix = intrinsic;
  }

  // Replace existing intrinsic affix if present (e.g., re-enrichment added
  // size to a previously stats-only affix), otherwise prepend new one.
  final existingIntrinsic = item.affixes.any(
    (a) => a.type == AffixType.intrinsic,
  );
  final List<Affix> newAffixes;
  if (existingIntrinsic) {
    newAffixes = item.affixes
        .map((a) => a.type == AffixType.intrinsic ? finalAffix : a)
        .toList();
  } else {
    newAffixes = [finalAffix, ...item.affixes];
  }

  final updated = item.copyWith(affixes: newAffixes);

  // 1. Update in-memory inventory.
  ref.read(itemsProvider.notifier).updateItem(updated);

  // 2. Persist to SQLite.
  try {
    await itemRepo.updateItem(updated, userId);
  } catch (e) {
    debugPrint(
      '[GameCoordinator] failed to persist backfilled item '
      '${item.id}: $e',
    );
  }

  // 3. Enqueue for Supabase sync.
  try {
    final payload = jsonEncode({
      'id': updated.id,
      'definition_id': updated.definitionId,
      'display_name': updated.displayName,
      'scientific_name': updated.scientificName,
      'category_name': updated.category.name,
      'rarity_name': updated.rarity?.name,
      'habitats_json': updated.habitatsToJson(),
      'continents_json': updated.continentsToJson(),
      'taxonomic_class': updated.taxonomicClass,
      'affixes': updated.affixesToJson(),
      'badges_json': updated.badgesToJson(),
      'parent_a_id': updated.parentAId,
      'parent_b_id': updated.parentBId,
      'acquired_at': updated.acquiredAt.toIso8601String(),
      'acquired_in_cell_id': updated.acquiredInCellId,
      'daily_seed': updated.dailySeed,
      'status': updated.status.name,
    });

    await queueProcessor.enqueue(
      entityType: WriteQueueEntityType.itemInstance,
      entityId: updated.id,
      operation: WriteQueueOperation.upsert,
      payload: payload,
      userId: userId,
    );
  } catch (e) {
    debugPrint(
      '[GameCoordinator] failed to enqueue backfilled item '
      '${item.id}: $e',
    );
  }
}

/// Retroactively roll intrinsic affixes for items of a single species.
///
/// Called by [onEnriched] when a new enrichment arrives in-session.
Future<void> backfillIntrinsicAffixes({
  required String definitionId,
  required ({int speed, int brawn, int wit, AnimalSize? size}) enrichedStats,
  required Ref ref,
  required StatsService statsService,
  required ItemInstanceRepository itemRepo,
  required QueueProcessor queueProcessor,
  required String userId,
}) async {
  final inventory = ref.read(itemsProvider);
  final itemsToFix = inventory.items
      .where(
        (item) =>
            item.definitionId == definitionId &&
            needsIntrinsicBackfill(item, enrichedStats),
      )
      .toList();

  if (itemsToFix.isEmpty) return;

  debugPrint(
    '[GameCoordinator] backfilling intrinsic affixes for '
    '${itemsToFix.length} items of $definitionId',
  );

  for (final item in itemsToFix) {
    await rollAndPersistIntrinsicAffix(
      item: item,
      enrichedStats: enrichedStats,
      ref: ref,
      statsService: statsService,
      itemRepo: itemRepo,
      queueProcessor: queueProcessor,
      userId: userId,
    );
  }
}

/// Startup sweep: backfill intrinsic affixes for ALL items in inventory
/// where enrichment data exists but the item has no intrinsic affix.
///
/// This is the primary safety net — runs on every startup after both
/// inventory and enrichment cache are populated. Catches:
///   - Items discovered before this fix was deployed
///   - Missed onEnriched callbacks (app crash, race conditions)
///   - Items hydrated from Supabase that were created without affixes
///   - Any other edge case where enrichment exists but stats don't
Future<void> backfillAllMissingAffixes({
  required Ref ref,
  required Map<String, ({int speed, int brawn, int wit, AnimalSize? size})>
      enrichmentCache,
  required StatsService statsService,
  required ItemInstanceRepository itemRepo,
  required QueueProcessor queueProcessor,
  required String userId,
}) async {
  try {
    final inventory = ref.read(itemsProvider);
    final itemsToFix = inventory.items
        .where(
          (item) =>
              enrichmentCache.containsKey(item.definitionId) &&
              needsIntrinsicBackfill(
                item,
                enrichmentCache[item.definitionId]!,
              ),
        )
        .toList();

    if (itemsToFix.isEmpty) return;

    debugPrint(
      '[GameCoordinator] startup backfill: ${itemsToFix.length} '
      'items need intrinsic affix update',
    );

    for (final item in itemsToFix) {
      await rollAndPersistIntrinsicAffix(
        item: item,
        enrichedStats: enrichmentCache[item.definitionId]!,
        ref: ref,
        statsService: statsService,
        itemRepo: itemRepo,
        queueProcessor: queueProcessor,
        userId: userId,
      );
    }

    debugPrint(
      '[GameCoordinator] startup backfill complete: '
      '${itemsToFix.length} items fixed',
    );
  } catch (e) {
    debugPrint('[GameCoordinator] startup backfill failed: $e');
  }
}
