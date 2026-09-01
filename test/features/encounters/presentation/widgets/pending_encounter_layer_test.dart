import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/app/readiness/app_readiness.dart';
import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/content_version_id.dart';
import 'package:earth_nova/core/domain/content/encounter_content.dart';
import 'package:earth_nova/core/domain/content/exact_version_ref.dart';
import 'package:earth_nova/core/domain/content/stable_content_id.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/trace_context.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/encounters/domain/entities/encounter_entities.dart';
import 'package:earth_nova/features/encounters/domain/repositories/encounter_repository.dart';
import 'package:earth_nova/features/encounters/presentation/providers/pending_encounter_provider.dart';
import 'package:earth_nova/features/encounters/presentation/widgets/pending_encounter_layer.dart';
import 'package:earth_nova/shared/design.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  group('PendingEncounterLayer', () {
    for (final state in <PendingEncounterState>[
      const PendingEncounterNone(),
      const PendingEncounterLoading(),
      const PendingEncounterFailure(),
    ]) {
      testWidgets('renders nothing for $state', (tester) async {
        await _pump(tester, state);

        expect(find.byType(PendingEncounterLayer), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('Pending encounter')),
          findsNothing,
        );
        expect(find.byType(Card), findsNothing);
        expect(find.byType(Text), findsNothing);
      });
    }

    testWidgets('ready encounter dispatches its first authored option once', (
      tester,
    ) async {
      final pending = _pendingEncounter();
      final notifier = await _pump(tester, PendingEncounterReady(pending));
      final action = find.byKey(const Key('resolve-present-encounter'));

      expect(find.byType(AppCard), findsOneWidget);
      expect(find.byType(AppFieldRow), findsOneWidget);
      expect(find.byType(AppButton), findsOneWidget);
      expect(find.byType(EarthPanel), findsNothing);
      expect(find.byType(EarthActionButton), findsNothing);
      expect(tester.getSize(action).height, greaterThanOrEqualTo(44));

      expect(action, findsOneWidget);
      expect(find.text('Red Fox'), findsOneWidget);
      expect(find.text('Observe quietly'), findsOneWidget);
      expect(
        tester.getSemantics(action),
        matchesSemantics(
          label: 'Pending encounter: Red Fox. Option: Observe quietly.',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      await tester.tap(action);
      await tester.pump();

      expect(notifier.resolveCalls, [pending.options.first.id]);
    });

    testWidgets('passes gestures outside the card through to the map', (
      tester,
    ) async {
      final pending = _pendingEncounter();
      var mapTaps = 0;
      final notifier = await _pump(
        tester,
        PendingEncounterReady(pending),
        onMapTap: () => mapTaps++,
      );

      await tester.tapAt(const Offset(8, 8));
      await tester.pump();

      expect(mapTaps, 1);
      expect(notifier.resolveCalls, isEmpty);

      await tester.tap(find.text('Red Fox'));
      await tester.pump();

      expect(mapTaps, 1);
      expect(notifier.resolveCalls, isEmpty);
    });

    testWidgets(
      'keeps the action reachable with long content at narrow 200% text',
      (tester) async {
        tester.view.physicalSize = const Size(390, 360);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final pending = _pendingEncounter(
          definitionDisplayName:
              'Red fox moving through a narrow river corridor after sunset',
          optionDisplayName:
              'Observe quietly from a safe distance while recording its route through the habitat',
        );
        await _pump(
          tester,
          PendingEncounterFailure(
            pendingEncounter: pending,
            optionId: pending.options.first.id,
          ),
          readiness: AppReadinessPhase.degraded,
          textScale: 2,
        );
        final action = find.byKey(const Key('resolve-present-encounter'));

        expect(tester.takeException(), isNull);
        expect(find.byType(SingleChildScrollView), findsOneWidget);

        await tester.ensureVisible(action);
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(tester.getTopLeft(action).dy, greaterThanOrEqualTo(0));
        expect(tester.getBottomRight(action).dy, lessThanOrEqualTo(360));
        expect(tester.getSize(action).height, greaterThanOrEqualTo(44));
        expect(
          tester.getSemantics(action),
          matchesSemantics(
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
            hasTapAction: false,
          ),
        );
      },
    );

    testWidgets('resolving encounter is disabled and shows progress', (
      tester,
    ) async {
      final pending = _pendingEncounter();
      final action = find.byKey(const Key('resolve-present-encounter'));

      await _pump(
        tester,
        PendingEncounterResolving(pending, pending.options.first.id),
      );

      expect(action, findsOneWidget);
      expect(find.byType(AppButton), findsOneWidget);
      expect(find.byType(LoadingDots), findsOneWidget);
      expect(
        find.descendant(
          of: action,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: action, matching: find.text('Resolving…')),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(action),
        matchesSemantics(
          label:
              'Resolving pending encounter: Red Fox. Option: Observe quietly.',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          isLiveRegion: true,
          hasTapAction: false,
        ),
      );
    });

    testWidgets('failed encounter exposes one retry', (tester) async {
      final pending = _pendingEncounter();
      final notifier = await _pump(
        tester,
        PendingEncounterFailure(
          pendingEncounter: pending,
          optionId: pending.options.first.id,
        ),
      );
      final action = find.byKey(const Key('resolve-present-encounter'));

      expect(action, findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(AppNotice), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'error: Resolution failed. Your choice was not applied. Try again.',
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(action),
        matchesSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      await tester.tap(action);
      await tester.pump();

      expect(notifier.retryCalls, 1);
      expect(notifier.resolveCalls, isEmpty);
    });

    testWidgets('degraded session disables server-authoritative resolution', (
      tester,
    ) async {
      final pending = _pendingEncounter();
      final notifier = await _pump(
        tester,
        PendingEncounterReady(pending),
        readiness: AppReadinessPhase.degraded,
      );
      final action = find.byKey(const Key('resolve-present-encounter'));

      expect(
        find.descendant(of: action, matching: find.text('Sync required')),
        findsOneWidget,
      );
      expect(find.byType(AppNotice), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'warning: Sync required. Reconnect before resolving this encounter.',
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(action),
        matchesSemantics(
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
          hasTapAction: false,
        ),
      );
      await tester.tap(action, warnIfMissed: false);
      expect(notifier.resolveCalls, isEmpty);
    });

    testWidgets('resolved encounter leaves reward presentation to the modal', (
      tester,
    ) async {
      final pending = _pendingEncounter();

      await _pump(
        tester,
        PendingEncounterResolved(pending, _resolvedAggregate(pending)),
      );

      expect(find.byType(Card), findsNothing);
      expect(find.byKey(const Key('resolve-present-encounter')), findsNothing);
      expect(find.byType(Text), findsNothing);
    });
  });
}

Future<_TestPendingEncounterNotifier> _pump(
  WidgetTester tester,
  PendingEncounterState state, {
  AppReadinessPhase readiness = AppReadinessPhase.usable,
  VoidCallback? onMapTap,
  double textScale = 1,
}) async {
  final notifier = _TestPendingEncounterNotifier(state);
  final observability = ObservabilityService(sessionId: 'test');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appObservabilityProvider.overrideWithValue(observability),
        appReadinessProvider.overrideWith(
          () => _StaticReadinessNotifier(readiness),
        ),
        pendingEncounterProvider.overrideWith(() => notifier),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: ShadTheme(
            data: ShadThemeData(
              brightness: Brightness.light,
              colorScheme: const ShadZincColorScheme.light(),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  key: const Key('map-surface'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onMapTap,
                  child: const SizedBox.expand(),
                ),
                const Positioned.fill(child: PendingEncounterLayer()),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return notifier;
}

final class _StaticReadinessNotifier extends AppReadinessNotifier {
  _StaticReadinessNotifier(this.phase);

  final AppReadinessPhase phase;

  @override
  AppReadinessState build() => AppReadinessState(
    phase: phase,
    completedCheckpoints: AppReadinessState.requiredCheckpoints,
  );

  @override
  Future<void> start(String userId) async {}
}

final class _TestPendingEncounterNotifier extends PendingEncounterNotifier {
  _TestPendingEncounterNotifier(this.value);

  final PendingEncounterState value;
  final List<EncounterOptionId> resolveCalls = [];
  int retryCalls = 0;

  @override
  PendingEncounterState build() => value;

  @override
  Future<void> resolve(
    EncounterOptionId optionId, {
    TraceContext? parent,
  }) async {
    resolveCalls.add(optionId);
  }

  @override
  Future<void> retryResolution({TraceContext? parent}) async {
    retryCalls++;
  }
}

PendingEncounter _pendingEncounter({
  String definitionDisplayName = 'Red Fox',
  String optionDisplayName = 'Observe quietly',
}) {
  return PendingEncounter(
    cellId: 'cell-red-fox',
    encounter: EncounterOccurrence(
      id: EncounterId('encounter-red-fox'),
      cellVisitId: CellVisitId('visit-red-fox'),
      cellVisitResolutionId: CellVisitResolutionId('resolution-red-fox'),
      definitionVersion: ExactVersionRef<EncounterContent>(
        stableId: StableContentId<EncounterContent>('encounter:red_fox'),
        versionId: ContentVersionId<EncounterContent>('red-fox-r2'),
        revision: 2,
      ),
      status: EncounterResolutionStatus.pending,
      createdAt: DateTime.utc(2026, 8, 16),
    ),
    definitionDisplayName: definitionDisplayName,
    options: [
      PendingEncounterOption(
        id: EncounterOptionId('observe-quietly'),
        ordinal: 0,
        displayName: optionDisplayName,
      ),
      PendingEncounterOption(
        id: EncounterOptionId('follow-tracks'),
        ordinal: 1,
        displayName: 'Follow its tracks',
      ),
    ],
  );
}

EncounterRuntimeAggregate _resolvedAggregate(PendingEncounter pending) {
  final baseItemVersion = ExactVersionRef<BaseItemContent>(
    stableId: StableContentId<BaseItemContent>('item:red_fox'),
    versionId: ContentVersionId<BaseItemContent>('red-fox-item-r2'),
    revision: 2,
  );
  final outcome = GenerateItemOutcomeResult(
    id: EncounterOutcomeResultId('result-red-fox'),
    encounterId: pending.encounter.id,
    outcomeId: EncounterOutcomeId('outcome-red-fox'),
    ordinal: 0,
    createdAt: DateTime.utc(2026, 8, 16, 0, 1),
    resolvedBaseItemVersion: baseItemVersion,
  );

  return EncounterRuntimeAggregate(
    cellVisitResolution: CellVisitResolution.selectedDefinition(
      id: pending.encounter.cellVisitResolutionId,
      cellVisitId: pending.encounter.cellVisitId,
      selectorId: SelectorId('selector-pending'),
      selectorCandidateId: SelectorCandidateId('candidate-pending'),
      definitionId: pending.encounter.definitionVersion.stableId,
      resolvedAt: DateTime.utc(2026, 8, 16, 0, 1),
    ),
    encounter: EncounterOccurrence(
      id: pending.encounter.id,
      cellVisitId: pending.encounter.cellVisitId,
      cellVisitResolutionId: pending.encounter.cellVisitResolutionId,
      definitionVersion: pending.encounter.definitionVersion,
      status: EncounterResolutionStatus.resolved,
      createdAt: pending.encounter.createdAt,
      selectedOptionId: pending.options.first.id,
      resolvedAt: DateTime.utc(2026, 8, 16, 0, 1),
    ),
    outcomeResults: [outcome],
    generatedItemCommits: [
      GeneratedItemCommit(
        outcomeResult: outcome,
        item: Item(
          id: 'item-red-fox',
          definitionId: baseItemVersion.stableId.value,
          displayName: 'Red Fox',
          category: ItemCategory.fauna,
          acquiredAt: outcome.createdAt,
          status: ItemStatus.active,
        ),
      ),
    ],
    revealedVenueCommits: const [],
  );
}
