import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/identification/domain/entities/identification_entities.dart';
import 'package:earth_nova/features/identification/presentation/screens/identification_service_screen.dart';
import 'package:earth_nova/features/identification/presentation/providers/items_provider.dart';
import 'package:earth_nova/features/item_knowledge/domain/entities/item_knowledge_entities.dart';
import 'package:earth_nova/features/living_world/domain/entities/authored_living_world_entities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IdentificationServiceScreen', () {
    testWidgets(
        'prepares once, shows provider, and cancel before reveal never commits',
        (tester) async {
      var prepareCalls = 0;
      var commitCalls = 0;
      final item = _examinedItem();
      final preparation = _preparation(item.id);
      final obs = ObservabilityService(
        sessionId: 'test-identification-service-cancel',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appObservabilityProvider.overrideWithValue(obs),
            itemsObservabilityProvider.overrideWithValue(obs),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => IdentificationServiceScreen(
                        item: item,
                        prepare: (_) async {
                          prepareCalls++;
                          return preparation;
                        },
                        commit: (plan) async {
                          commitCalls++;
                          return _result(plan, item.identify());
                        },
                      ),
                    ),
                  ),
                  child: const Text('Open service'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open service'));
      await tester.pumpAndSettle();

      expect(prepareCalls, 1);
      expect(commitCalls, 0);
      expect(find.text('Rowan'), findsOneWidget);
      expect(find.text('Identification'), findsOneWidget);
      expect(find.text('Town'), findsNothing);

      await tester.tap(find.text('Start identification'));
      await tester.pumpAndSettle();
      expect(find.text('Hold to reveal'), findsOneWidget);
      expect(commitCalls, 0);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Open service'), findsOneWidget);
      expect(prepareCalls, 1);
      expect(commitCalls, 0);
    });

    testWidgets('hold and reveal commits once and keeps the exact Item ID',
        (tester) async {
      var prepareCalls = 0;
      var commitCalls = 0;
      ItemIdentificationPlan? committedPlan;
      final item = _examinedItem();
      final identified = item.identify(at: DateTime.utc(2026, 4, 14));
      final obs = ObservabilityService(
        sessionId: 'test-identification-service-reveal',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appObservabilityProvider.overrideWithValue(obs),
            itemsObservabilityProvider.overrideWithValue(obs),
          ],
          child: MaterialApp(
            home: IdentificationServiceScreen(
              item: item,
              prepare: (_) async {
                prepareCalls++;
                return _preparation(item.id);
              },
              commit: (plan) async {
                commitCalls++;
                committedPlan = plan;
                return _result(plan, identified);
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start identification'));
      await tester.pumpAndSettle();
      expect(commitCalls, 0);

      await tester.longPress(find.text('Hold to reveal'));
      await tester.pumpAndSettle();

      expect(prepareCalls, 1);
      expect(commitCalls, 1);
      expect(committedPlan!.item.id.value, item.id);
      expect(
          find.byKey(ValueKey('identified-item-${item.id}')), findsOneWidget);
      expect(find.text('Amberwing Warbler'), findsOneWidget);
      expect(find.text('Setophaga aestiva'), findsOneWidget);
    });
  });
}

final _baseItemId = StableContentId<BaseItemContent>('fauna:amberwing');
final _baseItemVersion = ExactVersionRef<BaseItemContent>(
  stableId: _baseItemId,
  versionId: ContentVersionId<BaseItemContent>('base-item-version-7'),
  revision: 7,
);
final _serviceAccess = IdentificationServiceAccess(
  villagerId: VillagerId('villager:rowan'),
  villagerDisplayName: 'Rowan',
  serviceId: ServiceId('service:identify_item_properties'),
  serviceVersion: ExactVersionRef<ServiceContent>(
    stableId: StableContentId<ServiceContent>(
      'service:identify_item_properties',
    ),
    versionId: ContentVersionId<ServiceContent>('service-version-2'),
    revision: 2,
  ),
  serviceDisplayName: 'Identification',
);

Item _examinedItem() => Item(
      id: 'item-amberwing',
      definitionId: 'fauna:amberwing',
      baseItemId: _baseItemId.value,
      baseItemVersionId: _baseItemVersion.versionId.value,
      displayName: 'Amberwing Warbler',
      scientificName: 'Setophaga aestiva',
      category: ItemCategory.fauna,
      acquiredAt: DateTime.utc(2026, 4, 12),
      status: ItemStatus.active,
      examinationState: ItemExaminationState.examined,
      examinedAt: DateTime.utc(2026, 4, 13),
      identificationState: ItemIdentificationState.unidentified,
      identifiedDisplayName: 'Amberwing Warbler',
      identifiedScientificName: 'Setophaga aestiva',
    );

IdentificationPreparation _preparation(String itemId) =>
    IdentificationPreparation(
      item: ItemKnowledgeItemRef(
        id: ItemKnowledgeItemId(itemId),
        playerId: 'player-1',
        baseItemId: _baseItemId,
        baseItemVersion: _baseItemVersion,
      ),
      playerDiscovered: false,
      properties: const [],
      serviceAccess: _serviceAccess,
    );

ItemIdentificationResult _result(
  ItemIdentificationPlan plan,
  Item committedItem,
) =>
    ItemIdentificationResult(
      item: plan.item,
      committedItem: committedItem,
      discovery: ItemDiscovery(
        playerId: plan.item.playerId,
        baseItemId: plan.item.baseItemId,
      ),
      propertyValues: const [],
      identification: plan,
    );
