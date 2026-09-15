import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:earth_nova/app/sync/application/identification_sync_service.dart';
import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/identification/domain/entities/identification_entities.dart';
import 'package:earth_nova/features/identification/presentation/providers/items_provider.dart';
import 'package:earth_nova/ui/product_surfaces/identification/screens/identification_service_screen.dart';
import 'package:earth_nova/features/item_knowledge/domain/entities/item_knowledge_entities.dart';
import 'package:earth_nova/features/living_world/domain/entities/authored_living_world_entities.dart';
import 'package:earth_nova/ui/design_system.dart';
import 'package:earth_nova/shared/product/player_actions.dart';
import 'package:earth_nova/shared/product/product_action_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  group('IdentificationServiceScreen', () {
    testWidgets(
      'prepares once and cancel before reveal pops without committing',
      (tester) async {
        var prepareCalls = 0;
        var commitCalls = 0;
        final item = _examinedItem();

        await tester.pumpWidget(
          _host(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => IdentificationServiceScreen(
                        item: item,
                        prepare: (_) async {
                          prepareCalls++;
                          return _preparation(item.id);
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
        );

        await tester.tap(find.text('Open service'));
        await tester.pumpAndSettle();

        expect(prepareCalls, 1);
        expect(commitCalls, 0);
        expect(find.text('Rowan'), findsOneWidget);
        expect(find.text('Identification'), findsOneWidget);
        expect(find.text('Town'), findsNothing);

        await tester.tap(find.text('Start identification'));
        await tester.pump();
        expect(find.bySemanticsLabel('Hold to reveal'), findsOneWidget);
        expect(commitCalls, 0);

        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('Open service'), findsOneWidget);
        expect(prepareCalls, 1);
        expect(commitCalls, 0);
      },
    );

    testWidgets('prepare failures show only safe error copy', (tester) async {
      var commitCalls = 0;
      final item = _examinedItem();

      await tester.pumpWidget(
        _serviceHost(
          item: item,
          prepare: (_) => Future.error(StateError('private repository detail')),
          commit: (plan) async {
            commitCalls++;
            return _result(plan, item.identify());
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppErrorState), findsOneWidget);
      expect(find.text('Identification unavailable'), findsOneWidget);
      expect(find.text("Couldn't prepare Identification."), findsOneWidget);
      expect(find.textContaining('private repository detail'), findsNothing);
      expect(find.text('Start identification'), findsNothing);
      expect(commitCalls, 0);
    });

    testWidgets('rejects a preparation for a different exact Item ID', (
      tester,
    ) async {
      var commitCalls = 0;
      final item = _examinedItem();

      await tester.pumpWidget(
        _serviceHost(
          item: item,
          prepare: (_) async => _preparation('different-item'),
          commit: (plan) async {
            commitCalls++;
            return _result(plan, item.identify());
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Couldn't prepare Identification."), findsOneWidget);
      expect(find.text('Start identification'), findsNothing);
      expect(commitCalls, 0);
    });

    testWidgets(
      'exposes exact action surfaces and a hold-only pointer action',
      (tester) async {
        var commitCalls = 0;
        final item = _examinedItem();

        await tester.pumpWidget(
          _serviceHost(
            item: item,
            prepare: (_) async => _preparation(item.id),
            commit: (plan) async {
              commitCalls++;
              return _result(plan, item.identify());
            },
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is ProductActionSurface &&
                widget.actionId == PlayerActions.identifyUnidentifiedFind,
          ),
          findsOneWidget,
        );
        expect(
          tester
              .getSemantics(find.bySemanticsLabel('Start identification'))
              .getSemanticsData()
              .hasAction(SemanticsAction.tap),
          isTrue,
        );

        await tester.tap(find.text('Start identification'));
        await tester.pump();

        expect(commitCalls, 0);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is ProductActionSurface &&
                widget.actionId == PlayerActions.revealIdentification,
          ),
          findsOneWidget,
        );
        final hold = find.bySemanticsLabel('Hold to reveal');
        final semantics = tester.getSemantics(hold).getSemanticsData();
        expect(semantics.hasAction(SemanticsAction.longPress), isTrue);
        expect(semantics.hasAction(SemanticsAction.tap), isFalse);

        await tester.tap(hold, warnIfMissed: false);
        await tester.pump();
        expect(commitCalls, 0);

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();

        expect(commitCalls, 1);
        expect(
          find.byKey(ValueKey('identified-item-${item.id}')),
          findsOneWidget,
        );
      },
    );

    testWidgets('committing disables duplicate reveal and cancel actions', (
      tester,
    ) async {
      final item = _examinedItem();
      final result = Completer<ItemIdentificationResult>();
      var commitCalls = 0;
      ItemIdentificationPlan? committedPlan;

      await tester.pumpWidget(
        _serviceHost(
          item: item,
          prepare: (_) async => _preparation(item.id),
          commit: (plan) {
            commitCalls++;
            committedPlan = plan;
            return result.future;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start identification'));
      await tester.pump();
      await tester.longPress(find.byKey(const Key('hold-to-reveal')));
      await tester.pump();

      expect(commitCalls, 1);
      expect(committedPlan!.item.id.value, item.id);
      expect(find.bySemanticsLabel('Revealing identification'), findsOneWidget);
      expect(find.text('Revealing the prepared result…'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Revealing identification'))
            .getSemanticsData()
            .hasAction(SemanticsAction.longPress),
        isFalse,
      );
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Cancel'))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isFalse,
      );

      await tester.longPress(find.byKey(const Key('hold-to-reveal')));
      await tester.pump();
      expect(commitCalls, 1);

      result.complete(_result(committedPlan!, item.identify()));
      await tester.pumpAndSettle();

      expect(commitCalls, 1);
      expect(find.text('Identification revealed'), findsOneWidget);
      expect(find.text('Amberwing Warbler'), findsOneWidget);
      expect(find.text('Setophaga aestiva'), findsOneWidget);
    });

    testWidgets('commit failure returns to a safe retry state', (tester) async {
      final item = _examinedItem();
      var commitCalls = 0;

      await tester.pumpWidget(
        _serviceHost(
          item: item,
          prepare: (_) async => _preparation(item.id),
          commit: (plan) async {
            commitCalls++;
            if (commitCalls == 1) {
              throw StateError('private commit detail');
            }
            return _result(plan, item.identify());
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start identification'));
      await tester.pump();

      await tester.longPress(find.byKey(const Key('hold-to-reveal')));
      await tester.pumpAndSettle();

      expect(commitCalls, 1);
      expect(find.text('Identification was not revealed'), findsOneWidget);
      expect(
        find.text("Couldn't reveal Identification. Try again."),
        findsOneWidget,
      );
      expect(find.textContaining('private commit detail'), findsNothing);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Hold to reveal'))
            .getSemanticsData()
            .hasAction(SemanticsAction.longPress),
        isTrue,
      );

      await tester.longPress(find.byKey(const Key('hold-to-reveal')));
      await tester.pumpAndSettle();

      expect(commitCalls, 2);
      expect(find.text('Identification revealed'), findsOneWidget);
    });

    testWidgets('queued commit shows non-technical recovery status', (
      tester,
    ) async {
      final item = _examinedItem();
      await tester.pumpWidget(
        _serviceHost(
          item: item,
          prepare: (_) async => _preparation(item.id),
          commit: (_) async => throw const IdentificationSyncPending(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start identification'));
      await tester.pump();
      await tester.longPress(find.byKey(const Key('hold-to-reveal')));
      await tester.pumpAndSettle();

      expect(find.text('Identification saved'), findsOneWidget);
      expect(
        find.text('We will finish revealing it when your connection is ready.'),
        findsOneWidget,
      );
      expect(find.textContaining('queue'), findsNothing);
      expect(find.byKey(const Key('hold-to-reveal')), findsNothing);
    });

    testWidgets(
      'large text and reduced motion keep loading and actions usable',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 480));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final item = _examinedItem();
        final preparation = Completer<IdentificationPreparation>();

        await tester.pumpWidget(
          _serviceHost(
            item: item,
            prepare: (_) => preparation.future,
            commit: (plan) async => _result(plan, item.identify()),
            textScaler: const TextScaler.linear(2),
            disableAnimations: true,
          ),
        );
        await tester.pump();

        expect(find.text('Preparing identification'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('loading-dots-static')),
          findsOneWidget,
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);

        preparation.complete(_preparation(item.id));
        await tester.pumpAndSettle();

        expect(find.text('Start identification'), findsOneWidget);
        final card = tester.getRect(find.byType(AppCard));
        expect(card.left, greaterThanOrEqualTo(0));
        expect(card.right, lessThanOrEqualTo(320));
        expect(tester.takeException(), isNull);
      },
    );
  });
}

Widget _serviceHost({
  required Item item,
  required PrepareIdentification prepare,
  required CommitIdentification commit,
  TextScaler textScaler = TextScaler.noScaling,
  bool disableAnimations = false,
}) => _host(
  textScaler: textScaler,
  disableAnimations: disableAnimations,
  home: IdentificationServiceScreen(
    item: item,
    prepare: prepare,
    commit: commit,
  ),
);

Widget _host({
  required Widget home,
  TextScaler textScaler = TextScaler.noScaling,
  bool disableAnimations = false,
}) {
  final observability = ObservabilityService(
    sessionId: 'test-identification-service',
  );
  return ProviderScope(
    overrides: [
      appObservabilityProvider.overrideWithValue(observability),
      itemsObservabilityProvider.overrideWithValue(observability),
    ],
    child: MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: textScaler,
          disableAnimations: disableAnimations,
        ),
        child: ShadTheme(
          data: ShadThemeData(
            brightness: Brightness.dark,
            colorScheme: const ShadZincColorScheme.dark(),
          ),
          child: child!,
        ),
      ),
      home: home,
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
