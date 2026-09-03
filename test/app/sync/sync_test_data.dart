import 'package:earth_nova/app/sync/domain/pending_command.dart';
import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/identification/domain/entities/identification_entities.dart';
import 'package:earth_nova/features/item_knowledge/domain/entities/item_knowledge_entities.dart';
import 'package:earth_nova/features/living_world/domain/entities/authored_living_world_entities.dart';

const testPlayerId = 'player-1';

ItemIdentificationPlan testIdentificationPlan({
  String itemId = 'item-1',
  String playerId = testPlayerId,
  String villagerDisplayName = 'Rowan',
}) {
  final baseItemId = StableContentId<BaseItemContent>('base-item-1');
  return ItemIdentificationPlan(
    item: ItemKnowledgeItemRef(
      id: ItemKnowledgeItemId(itemId),
      playerId: playerId,
      baseItemId: baseItemId,
      baseItemVersion: ExactVersionRef<BaseItemContent>(
        stableId: baseItemId,
        versionId: ContentVersionId<BaseItemContent>('version-1'),
        revision: 1,
      ),
    ),
    serviceAccess: IdentificationServiceAccess(
      villagerId: VillagerId('villager:rowan'),
      villagerDisplayName: villagerDisplayName,
      serviceId: ServiceId('service:identification'),
      serviceVersion: ExactVersionRef<ServiceContent>(
        stableId: StableContentId<ServiceContent>('service:identification'),
        versionId: ContentVersionId<ServiceContent>('service-version-1'),
        revision: 1,
      ),
      serviceDisplayName: 'Identification',
    ),
    propertyResolutions: const [],
  );
}

ItemIdentificationResult testIdentificationResult(
  ItemIdentificationPlan plan,
) {
  final committedItem = Item(
    id: plan.item.id.value,
    definitionId: plan.item.baseItemId.value,
    baseItemId: plan.item.baseItemId.value,
    baseItemVersionId: plan.item.baseItemVersion.versionId.value,
    displayName: 'Northern cardinal',
    category: ItemCategory.fauna,
    acquiredAt: DateTime.utc(2026, 9, 1),
    status: ItemStatus.active,
    identificationState: ItemIdentificationState.identified,
  );
  return ItemIdentificationResult(
    item: plan.item,
    committedItem: committedItem,
    discovery: ItemDiscovery(
      playerId: plan.item.playerId,
      baseItemId: plan.item.baseItemId,
    ),
    propertyValues: const [],
    identification: plan,
  );
}

PendingCommand testPendingCommand({
  String commandId = 'command-1',
  String itemId = 'item-1',
  String playerId = testPlayerId,
  String environment = 'local',
  PendingCommandState state = PendingCommandState.pending,
  int attemptCount = 0,
}) =>
    PendingCommand(
      schemaVersion: PendingCommand.currentSchemaVersion,
      commandId: commandId,
      idempotencyKey: 'identify:$itemId',
      kind: PendingCommandKind.identifyItem,
      payloadVersion: IdentificationCommandPayload.currentVersion,
      payload: IdentificationCommandPayload(
        plan: testIdentificationPlan(itemId: itemId, playerId: playerId),
      ),
      environment: environment,
      playerId: playerId,
      enqueuedAt: DateTime.utc(2026, 9, 1),
      attemptCount: attemptCount,
      state: state,
    );
