import 'dart:async';

import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/identification/domain/entities/identification_entities.dart';
import 'package:earth_nova/features/identification/presentation/providers/items_provider.dart';
import 'package:earth_nova/features/item_knowledge/domain/entities/item_knowledge_entities.dart';
import 'package:earth_nova/features/living_world/domain/entities/authored_living_world_entities.dart';
import 'package:riverpod/misc.dart';

final storyIdentificationItem = Item(
  id: 'story-amberwing',
  definitionId: 'fauna:amberwing',
  baseItemId: 'fauna:amberwing',
  baseItemVersionId: 'story-amberwing-r1',
  displayName: 'Amberwing Warbler',
  scientificName: 'Setophaga aestiva',
  category: ItemCategory.fauna,
  acquiredAt: DateTime.utc(2026, 4, 12),
  status: ItemStatus.active,
  identificationState: ItemIdentificationState.unidentified,
  examinationState: ItemExaminationState.examined,
  examinedAt: DateTime.utc(2026, 4, 13),
  identifiedDisplayName: 'Amberwing Warbler',
  identifiedScientificName: 'Setophaga aestiva',
);

final _storyBaseItemId = StableContentId<BaseItemContent>('fauna:amberwing');
final _storyBaseItemVersion = ExactVersionRef<BaseItemContent>(
  stableId: _storyBaseItemId,
  versionId: ContentVersionId<BaseItemContent>('story-amberwing-r1'),
  revision: 1,
);

final storyIdentificationPreparation = IdentificationPreparation(
  item: ItemKnowledgeItemRef(
    id: ItemKnowledgeItemId(storyIdentificationItem.id),
    playerId: 'widgetbook-player',
    baseItemId: _storyBaseItemId,
    baseItemVersion: _storyBaseItemVersion,
  ),
  playerDiscovered: false,
  properties: const [],
  serviceAccess: IdentificationServiceAccess(
    villagerId: VillagerId('villager:rowan'),
    villagerDisplayName: 'Rowan',
    serviceId: ServiceId('service:identify_item_properties'),
    serviceVersion: ExactVersionRef<ServiceContent>(
      stableId: StableContentId<ServiceContent>(
        'service:identify_item_properties',
      ),
      versionId: ContentVersionId<ServiceContent>('story-identification-r1'),
      revision: 1,
    ),
    serviceDisplayName: 'Identification',
  ),
);

final storyIdentifiedItem = storyIdentificationItem.identify(
  at: DateTime.utc(2026, 4, 14),
);

List<Override> identificationStoryOverrides() => [
  appObservabilityProvider.overrideWithValue(
    ObservabilityService(sessionId: 'widgetbook-identification-app'),
  ),
  itemsObservabilityProvider.overrideWithValue(
    ObservabilityService(sessionId: 'widgetbook-identification-items'),
  ),
];

Future<IdentificationPreparation> storyPrepareIdentification(Item _) async =>
    storyIdentificationPreparation;

Future<IdentificationPreparation> storyPendingPreparation(Item _) =>
    Completer<IdentificationPreparation>().future;

Future<IdentificationPreparation> storyFailPreparation(Item _) =>
    Future<IdentificationPreparation>.error(StateError('story preparation'));

Future<ItemIdentificationResult> storyCommitIdentification(
  ItemIdentificationPlan plan,
) async => ItemIdentificationResult(
  item: plan.item,
  committedItem: storyIdentifiedItem,
  discovery: ItemDiscovery(
    playerId: plan.item.playerId,
    baseItemId: plan.item.baseItemId,
  ),
  propertyValues: const [],
  identification: plan,
);

Future<ItemIdentificationResult> storyPendingCommit(ItemIdentificationPlan _) =>
    Completer<ItemIdentificationResult>().future;

Future<ItemIdentificationResult> storyFailCommit(ItemIdentificationPlan _) =>
    Future<ItemIdentificationResult>.error(StateError('story commit'));
