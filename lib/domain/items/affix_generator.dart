import 'package:earth_nova/models/affix.dart';
import 'package:earth_nova/models/animal_size.dart';
import 'package:earth_nova/models/item_instance.dart';
import 'package:earth_nova/domain/items/stats_service.dart';
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

/// Roll an intrinsic affix for a single item. Pure — no side effects.
///
/// Uses [enrichedStats] for base stats (brawn/wit/speed) and optional
/// [AnimalSize] for deterministic weight rolling. Returns a new
/// [ItemInstance] with the rolled intrinsic affix merged into its affix list.
///
/// If [enrichedStats.size] is available, the returned affix also includes
/// [kSizeAffixKey] and [kWeightAffixKey] values.
///
/// Shared by both the real-time `onEnriched` path and the startup sweep.
ItemInstance rollAffixForItem({
  required ItemInstance item,
  required ({int speed, int brawn, int wit, AnimalSize? size}) enrichedStats,
  required StatsService statsService,
}) {
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

  return item.copyWith(affixes: newAffixes);
}

/// Retroactively roll intrinsic affixes for all eligible items.
///
/// Pure function — no Riverpod, no persistence. Returns a new list of
/// [ItemInstance]s with intrinsic affixes rolled for any item that:
/// - Belongs to a definition in [enrichedStatsLookup]
/// - Passes [needsIntrinsicBackfill] for that definition's enrichment
///
/// Callers are responsible for persisting the returned items to SQLite and
/// the write queue.
///
/// [enrichedStatsLookup] maps definitionId →
/// `({int speed, int brawn, int wit, AnimalSize? size})`.
List<ItemInstance> backfillAffixes(
  List<ItemInstance> items,
  Map<String, ({int speed, int brawn, int wit, AnimalSize? size})>
      enrichedStatsLookup,
) {
  const statsService = StatsService();
  final result = <ItemInstance>[];
  var changed = false;

  for (final item in items) {
    final enrichedStats = enrichedStatsLookup[item.definitionId];
    if (enrichedStats == null || !needsIntrinsicBackfill(item, enrichedStats)) {
      result.add(item);
      continue;
    }

    final updated = rollAffixForItem(
      item: item,
      enrichedStats: enrichedStats,
      statsService: statsService,
    );
    result.add(updated);
    changed = true;
  }

  // Return the original list reference if nothing changed (avoids allocation).
  return changed ? result : items;
}
