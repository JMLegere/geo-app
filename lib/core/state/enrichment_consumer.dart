import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/models/affix.dart';
import 'package:earth_nova/core/models/animal_size.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/core/models/write_queue_entry.dart';
import 'package:earth_nova/core/persistence/item_instance_repository.dart';
import 'package:earth_nova/features/items/services/stats_service.dart';
import 'package:earth_nova/features/items/providers/items_provider.dart';
import 'package:earth_nova/features/sync/providers/enrichment_provider.dart';
import 'package:earth_nova/core/state/species_repository_provider.dart';
import 'package:earth_nova/features/sync/services/enrichment_service.dart';
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

/// Re-queue enrichment requests for fauna in inventory that lack enrichment
/// or have incomplete enrichment (e.g., enriched before size field was added).
///
/// Covers species that were dropped due to rate limits, app restarts (in-memory
/// queue lost), pipeline changes, or new enrichment fields added after initial
/// enrichment. Waits for species data to load, then compares inventory fauna
/// against the enrichment cache.
///
/// Only [kStartupEnrichmentCap] species are queued immediately. The remainder
/// are placed in [deferredQueue] and processed by a [Timer.periodic] started
/// here (handle returned via [onTimerCreated] so the caller can cancel on
/// dispose). This prevents a 200+ second serial call storm at session start
/// (e.g. 109 species × 4.2s/req with max 2 concurrent = ~230 seconds).
Future<void> requeueUnenrichedSpecies({
  required Ref ref,
  required Map<String, ({int speed, int brawn, int wit, AnimalSize? size})>
      enrichmentCache,
  required List<({String definitionId, FaunaDefinition fauna, bool force})>
      deferredQueue,
  required void Function(Timer) onTimerCreated,
}) async {
  try {
    final speciesRepo = ref.read(speciesRepositoryProvider);
    final speciesData = await speciesRepo.getAll();
    final inventory = ref.read(itemsProvider);

    // Capture enrichmentService before any async gap — the provider is a
    // non-autoDispose singleton, so this instance is valid for the session.
    final enrichmentService = ref.read(enrichmentServiceProvider);

    // Build lookup map for fauna definitions by ID.
    final faunaById = <String, FaunaDefinition>{};
    for (final fauna in speciesData) {
      faunaById[fauna.id] = fauna;
    }

    // Find unique fauna definition IDs in inventory that lack enrichment
    // or have incomplete enrichment (e.g., missing size from older pipeline).
    // Uses faunaById to naturally filter to fauna items only (ItemInstance
    // has no category field — the species data map is the filter).
    //
    // Snapshot the items list to avoid ConcurrentModificationError — enrichment
    // callbacks can mutate inventory while we iterate.
    final unenrichedIds = <String>{};
    final incompleteIds = <String>{};
    final itemsSnapshot = List<ItemInstance>.of(inventory.items);
    for (final item in itemsSnapshot) {
      if (!faunaById.containsKey(item.definitionId)) continue;

      if (!enrichmentCache.containsKey(item.definitionId)) {
        unenrichedIds.add(item.definitionId);
      } else if (enrichmentCache[item.definitionId]!.size == null) {
        incompleteIds.add(item.definitionId);
      }
    }

    if (unenrichedIds.isEmpty && incompleteIds.isEmpty) return;

    // Partition: unenriched first (higher priority — never enriched), then
    // incomplete (have a DB row but missing size). Startup batch capped at
    // kStartupEnrichmentCap; remainder deferred for lazy background drain.
    final partition = partitionEnrichmentCandidates(
      unenrichedIds: unenrichedIds,
      incompleteIds: incompleteIds,
    );

    // Queue the startup batch immediately.
    // Incomplete enrichments need force=true so the Edge Function deletes the
    // stale row and re-enriches from scratch.
    for (final defId in partition.startup) {
      final fauna = faunaById[defId]!;
      enrichmentService.requestEnrichment(
        definitionId: fauna.id,
        scientificName: fauna.scientificName,
        commonName: fauna.displayName,
        taxonomicClass: fauna.taxonomicClass,
        force: incompleteIds.contains(defId),
        priority: EnrichmentPriority.low,
      );
    }

    // Populate the deferred queue with the remainder.
    for (final defId in partition.deferred) {
      final fauna = faunaById[defId]!;
      deferredQueue.add((
        definitionId: defId,
        fauna: fauna,
        force: incompleteIds.contains(defId),
      ));
    }

    debugPrint(
      '[GameCoordinator] enrichment requeue: ${partition.startup.length} '
      'immediate, ${partition.deferred.length} deferred '
      '(${unenrichedIds.length} unenriched, '
      '${incompleteIds.length} incomplete)',
    );

    // Start the background drain timer only when there are deferred items.
    // Fires every kDeferredEnrichmentIntervalSeconds, processes
    // kDeferredEnrichmentBatchSize items per tick, and self-cancels when
    // the queue is empty.
    if (deferredQueue.isNotEmpty) {
      final drainTimer = Timer.periodic(
        const Duration(seconds: kDeferredEnrichmentIntervalSeconds),
        (_) {
          if (deferredQueue.isEmpty) return;
          final batchSize = deferredQueue.length.clamp(
            0,
            kDeferredEnrichmentBatchSize,
          );
          final batch = deferredQueue.take(batchSize).toList();
          deferredQueue.removeRange(0, batch.length);
          for (final entry in batch) {
            enrichmentService.requestEnrichment(
              definitionId: entry.definitionId,
              scientificName: entry.fauna.scientificName,
              commonName: entry.fauna.displayName,
              taxonomicClass: entry.fauna.taxonomicClass,
              force: entry.force,
              priority: EnrichmentPriority.low,
            );
          }
          debugPrint(
            '[GameCoordinator] deferred enrichment drain: '
            '${batch.length} queued, ${deferredQueue.length} remaining',
          );
        },
      );
      onTimerCreated(drainTimer);
    }
  } catch (e) {
    debugPrint('[GameCoordinator] failed to re-queue unenriched species: $e');
  }
}

/// Partitions enrichment candidate IDs into a startup batch and a deferred
/// remainder.
///
/// Priority: [unenrichedIds] first (never enriched = higher priority), then
/// [incompleteIds] (have a DB row but missing the size field). The startup
/// batch is capped at [cap] (defaults to [kStartupEnrichmentCap]).
///
/// Exposed as a non-private function so it can be unit-tested directly.
({List<String> startup, List<String> deferred}) partitionEnrichmentCandidates({
  required Set<String> unenrichedIds,
  required Set<String> incompleteIds,
  int cap = kStartupEnrichmentCap,
}) {
  // Spread preserves LinkedHashSet insertion order: unenriched first.
  final allIds = [...unenrichedIds, ...incompleteIds];
  return (
    startup: allIds.take(cap).toList(),
    deferred: allIds.skip(cap).toList(),
  );
}
