import 'dart:async';

import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/identification/domain/entities/identification_entities.dart';
import 'package:earth_nova/features/identification/presentation/providers/items_provider.dart';
import 'package:earth_nova/features/identification/presentation/screens/identification_service_screen.dart';
import 'package:earth_nova/features/item_knowledge/domain/entities/item_knowledge_entities.dart';
import 'package:earth_nova/features/living_world/domain/entities/authored_living_world_entities.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'phase_five_capture_support.dart';
import 'phase_seven_capture_support.dart';

const _phaseSevenIdentificationAssets = [
  'identification/mobile-committing-390x844.png',
  'identification/desktop-start-hold-1440x900.png',
  'identification/desktop-committing-1440x900.png',
  'identification/desktop-identified-success-1440x900.png',
  'identification/desktop-preparation-failure-1440x900.png',
];

void main() {
  group('Phase five identification fixtures', () {
    test('declares the five phase seven identification assets', () {
      expect(_phaseSevenIdentificationAssets, hasLength(5));
      expect(_phaseSevenIdentificationAssets.toSet(), hasLength(5));
    });

    testWidgets('captures mobile prepared', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final item = _examinedItem();
      var prepareCalls = 0;
      var commitCalls = 0;

      await capturePhaseFiveFixture(
        tester,
        size: phaseFiveMobileSize,
        name: 'identification/mobile-prepared.png',
        child: _serviceHost(
          item: item,
          prepare: (received) async {
            expect(received, same(item));
            prepareCalls++;
            return _preparation(item.id);
          },
          commit: (plan) {
            expect(plan.item.id.value, item.id);
            commitCalls++;
            throw StateError('commit must not be called');
          },
        ),
      );

      expect(prepareCalls, 1);
      expect(commitCalls, 0);
      expect(find.text('Identification'), findsOneWidget);
      expect(find.text('Rowan'), findsOneWidget);
      expect(find.text('Start identification'), findsOneWidget);
    }, skip: !phaseFiveCaptureEnabled);

    testWidgets('captures mobile start-hold', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final item = _examinedItem();
      var prepareCalls = 0;
      var commitCalls = 0;
      final child = _serviceHost(
        item: item,
        prepare: (received) async {
          expect(received, same(item));
          prepareCalls++;
          return _preparation(item.id);
        },
        commit: (plan) {
          expect(plan.item.id.value, item.id);
          commitCalls++;
          throw StateError('commit must not be called');
        },
      );

      await _pumpMobileFixture(tester, child);
      await tester.tap(find.text('Start identification'));
      await tester.pump();
      await capturePhaseFiveFixture(
        tester,
        size: phaseFiveMobileSize,
        name: 'identification/mobile-start-hold.png',
        child: child,
      );

      expect(prepareCalls, 1);
      expect(commitCalls, 0);
      expect(find.bySemanticsLabel('Hold to reveal'), findsOneWidget);
    }, skip: !phaseFiveCaptureEnabled);

    testWidgets('captures mobile committing', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final item = _examinedItem();
      final pendingCommit = Completer<ItemIdentificationResult>();
      ItemIdentificationPlan? committedPlan;
      var prepareCalls = 0;
      var commitCalls = 0;
      final child = _serviceHost(
        item: item,
        prepare: (received) async {
          expect(received, same(item));
          prepareCalls++;
          return _preparation(item.id);
        },
        commit: (plan) {
          expect(plan.item.id.value, item.id);
          commitCalls++;
          committedPlan = plan;
          return pendingCommit.future;
        },
      );

      await capturePhaseSevenFixture(
        tester,
        size: phaseSevenMobileSize,
        name: 'identification/mobile-committing-390x844.png',
        child: child,
        prepare: (tester) async {
          await tester.tap(find.text('Start identification'));
          await tester.pump();
          await tester.longPress(find.byKey(const Key('hold-to-reveal')));
          await tester.pump();
          expect(
            find.bySemanticsLabel('Revealing identification'),
            findsOneWidget,
          );
        },
      );

      expect(prepareCalls, 1);
      expect(commitCalls, 1);
      expect(committedPlan!.item.id.value, item.id);
    }, skip: !phaseSevenCaptureEnabled);

    testWidgets('captures mobile identified success', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final item = _examinedItem();
      ItemIdentificationPlan? committedPlan;
      var prepareCalls = 0;
      var commitCalls = 0;
      final child = _serviceHost(
        item: item,
        prepare: (received) async {
          expect(received, same(item));
          prepareCalls++;
          return _preparation(item.id);
        },
        commit: (plan) async {
          expect(plan.item.id.value, item.id);
          commitCalls++;
          committedPlan = plan;
          return _result(plan, item.identify());
        },
      );

      await _pumpMobileFixture(tester, child);
      await tester.tap(find.text('Start identification'));
      await tester.pump();
      await tester.longPress(find.byKey(const Key('hold-to-reveal')));
      await tester.pumpAndSettle();
      await capturePhaseFiveFixture(
        tester,
        size: phaseFiveMobileSize,
        name: 'identification/mobile-identified-success.png',
        child: child,
      );

      expect(prepareCalls, 1);
      expect(commitCalls, 1);
      expect(committedPlan!.item.id.value, item.id);
      expect(
        find.byKey(ValueKey('identified-item-${item.id}')),
        findsOneWidget,
      );
      expect(find.text('Yellow Warbler'), findsOneWidget);
      expect(find.text('Setophaga aestiva'), findsOneWidget);
    }, skip: !phaseFiveCaptureEnabled);

    testWidgets(
      'captures mobile preparation failure without repository details',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final item = _examinedItem();
        var prepareCalls = 0;

        await capturePhaseFiveFixture(
          tester,
          size: phaseFiveMobileSize,
          name: 'identification/mobile-preparation-failure.png',
          child: _serviceHost(
            item: item,
            prepare: (received) {
              expect(received, same(item));
              prepareCalls++;
              return Future.error(
                StateError('private fixture repository detail'),
              );
            },
            commit: (_) => throw StateError('commit must not be called'),
          ),
        );

        expect(prepareCalls, 1);
        expect(find.text('Identification unavailable'), findsOneWidget);
        expect(find.text("Couldn't prepare Identification."), findsOneWidget);
        expect(
          find.textContaining('private fixture repository detail'),
          findsNothing,
        );
      },
      skip: !phaseFiveCaptureEnabled,
    );

    testWidgets('captures desktop prepared', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final item = _examinedItem();

      await capturePhaseFiveFixture(
        tester,
        size: phaseFiveDesktopSize,
        name: 'identification/desktop-prepared.png',
        child: _serviceHost(
          item: item,
          prepare: (received) async {
            expect(received, same(item));
            return _preparation(item.id);
          },
          commit: (_) => throw StateError('commit must not be called'),
        ),
      );

      expect(find.text('Identification'), findsOneWidget);
      expect(find.text('Rowan'), findsOneWidget);
      expect(find.text('Start identification'), findsOneWidget);
    }, skip: !phaseFiveCaptureEnabled);

    testWidgets('captures desktop start-hold', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final item = _examinedItem();
      var prepareCalls = 0;
      var commitCalls = 0;
      await capturePhaseSevenFixture(
        tester,
        size: phaseSevenDesktopSize,
        name: 'identification/desktop-start-hold-1440x900.png',
        child: _serviceHost(
          item: item,
          prepare: (received) async {
            expect(received, same(item));
            prepareCalls++;
            return _preparation(item.id);
          },
          commit: (plan) {
            expect(plan.item.id.value, item.id);
            commitCalls++;
            throw StateError('commit must not be called');
          },
        ),
        prepare: (tester) async {
          await tester.tap(find.text('Start identification'));
          await tester.pump();
          expect(find.bySemanticsLabel('Hold to reveal'), findsOneWidget);
        },
      );

      expect(prepareCalls, 1);
      expect(commitCalls, 0);
    }, skip: !phaseSevenCaptureEnabled);

    testWidgets('captures desktop committing', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final item = _examinedItem();
      final pendingCommit = Completer<ItemIdentificationResult>();
      ItemIdentificationPlan? committedPlan;
      var prepareCalls = 0;
      var commitCalls = 0;
      await capturePhaseSevenFixture(
        tester,
        size: phaseSevenDesktopSize,
        name: 'identification/desktop-committing-1440x900.png',
        child: _serviceHost(
          item: item,
          prepare: (received) async {
            expect(received, same(item));
            prepareCalls++;
            return _preparation(item.id);
          },
          commit: (plan) {
            expect(plan.item.id.value, item.id);
            commitCalls++;
            committedPlan = plan;
            return pendingCommit.future;
          },
        ),
        prepare: (tester) async {
          await tester.tap(find.text('Start identification'));
          await tester.pump();
          await tester.longPress(find.byKey(const Key('hold-to-reveal')));
          await tester.pump();
          expect(
            find.bySemanticsLabel('Revealing identification'),
            findsOneWidget,
          );
        },
      );

      expect(prepareCalls, 1);
      expect(commitCalls, 1);
      expect(committedPlan!.item.id.value, item.id);
    }, skip: !phaseSevenCaptureEnabled);

    testWidgets('captures desktop identified success', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final item = _examinedItem();
      ItemIdentificationPlan? committedPlan;
      var prepareCalls = 0;
      var commitCalls = 0;
      await capturePhaseSevenFixture(
        tester,
        size: phaseSevenDesktopSize,
        name: 'identification/desktop-identified-success-1440x900.png',
        child: _serviceHost(
          item: item,
          prepare: (received) async {
            expect(received, same(item));
            prepareCalls++;
            return _preparation(item.id);
          },
          commit: (plan) async {
            expect(plan.item.id.value, item.id);
            commitCalls++;
            committedPlan = plan;
            return _result(plan, item.identify());
          },
        ),
        prepare: (tester) async {
          await tester.tap(find.text('Start identification'));
          await tester.pump();
          await tester.longPress(find.byKey(const Key('hold-to-reveal')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(ValueKey('identified-item-${item.id}')),
            findsOneWidget,
          );
          expect(find.text('Yellow Warbler'), findsOneWidget);
          expect(find.text('Setophaga aestiva'), findsOneWidget);
        },
      );

      expect(prepareCalls, 1);
      expect(commitCalls, 1);
      expect(committedPlan!.item.id.value, item.id);
    }, skip: !phaseSevenCaptureEnabled);

    testWidgets(
      'captures desktop preparation failure without repository details',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final item = _examinedItem();
        var prepareCalls = 0;
        await capturePhaseSevenFixture(
          tester,
          size: phaseSevenDesktopSize,
          name: 'identification/desktop-preparation-failure-1440x900.png',
          child: _serviceHost(
            item: item,
            prepare: (received) {
              expect(received, same(item));
              prepareCalls++;
              return Future.error(
                StateError('private fixture repository detail'),
              );
            },
            commit: (_) => throw StateError('commit must not be called'),
          ),
          prepare: (tester) async {
            expect(find.text('Identification unavailable'), findsOneWidget);
            expect(
              find.text("Couldn't prepare Identification."),
              findsOneWidget,
            );
            expect(
              find.textContaining('private fixture repository detail'),
              findsNothing,
            );
          },
        );

        expect(prepareCalls, 1);
      },
      skip: !phaseSevenCaptureEnabled,
    );

    testWidgets(
      'captures mobile prepared at 200% text with reduced motion',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final item = _examinedItem();

        await capturePhaseFiveFixture(
          tester,
          size: phaseFiveMobileSize,
          name: 'identification/mobile-prepared-text-200-reduced-motion.png',
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: _serviceHost(
                item: item,
                prepare: (received) async {
                  expect(received, same(item));
                  return _preparation(item.id);
                },
                commit: (_) => throw StateError('commit must not be called'),
              ),
            ),
          ),
        );

        expect(find.text('Start identification'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
      skip: !phaseFiveCaptureEnabled,
    );
  });
}

Future<void> _pumpMobileFixture(WidgetTester tester, Widget child) =>
    pumpPhaseFiveFixture(tester, size: phaseFiveMobileSize, child: child);

Widget _serviceHost({
  required Item item,
  required PrepareIdentification prepare,
  required CommitIdentification commit,
}) {
  final observability = ObservabilityService(
    sessionId: 'phase-five-identification-fixture',
  );
  return ProviderScope(
    overrides: [
      appObservabilityProvider.overrideWithValue(observability),
      itemsObservabilityProvider.overrideWithValue(observability),
    ],
    child: IdentificationServiceScreen(
      item: item,
      prepare: prepare,
      commit: commit,
    ),
  );
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
  displayName: 'Yellow Warbler',
  scientificName: 'Setophaga aestiva',
  category: ItemCategory.fauna,
  acquiredAt: DateTime.utc(2026, 4, 12),
  status: ItemStatus.active,
  examinationState: ItemExaminationState.examined,
  examinedAt: DateTime.utc(2026, 4, 13),
  identificationState: ItemIdentificationState.unidentified,
  identifiedDisplayName: 'Yellow Warbler',
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
) => ItemIdentificationResult(
  item: plan.item,
  committedItem: committedItem,
  discovery: ItemDiscovery(
    playerId: plan.item.playerId,
    baseItemId: plan.item.baseItemId,
  ),
  propertyValues: const [],
  identification: plan,
);
