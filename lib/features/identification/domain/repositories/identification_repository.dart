import 'package:earth_nova/features/identification/domain/entities/identification_entities.dart';
import 'package:earth_nova/features/item_knowledge/domain/entities/item_knowledge_entities.dart';

/// Authoritative boundary for preparing and committing Item Identification.
///
/// Callers prepare and plan once, then retain that [ItemIdentificationPlan]
/// for any commit retry. Implementations must use the Item's exact Version and
/// must not expose direct client table writes.
abstract interface class IdentificationRepository {
  Future<IdentificationPreparation> prepare(
    ItemKnowledgeItemId itemId, {
    String? traceId,
  });

  Future<ItemIdentificationResult> commit(
    ItemIdentificationPlan plan, {
    String? traceId,
  });
}
