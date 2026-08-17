import 'dart:io';

import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/domain/content/current_encounter_version_binding_repository.dart';
import 'package:earth_nova/core/domain/content/encounter_content.dart';
import 'package:earth_nova/core/domain/rules/selector.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/trace_context.dart';
import 'package:earth_nova/features/encounters/application/encounter_engine_mode.dart';
import 'package:earth_nova/features/encounters/application/encounter_entry_coordinator.dart';
import 'package:earth_nova/features/encounters/domain/entities/encounter_entities.dart';
import 'package:earth_nova/features/encounters/domain/repositories/encounter_repository.dart';
import 'package:earth_nova/features/encounters/domain/use_cases/resolve_cell_visit_encounter_selector.dart';
import 'package:earth_nova/features/encounters/presentation/providers/encounter_entry_provider.dart';
import 'package:earth_nova/features/encounters/presentation/providers/pending_encounter_provider.dart';
import 'package:earth_nova/features/identification/domain/entities/discovery_item_draft.dart';
import 'package:earth_nova/features/identification/domain/repositories/item_repository.dart';
import 'package:earth_nova/features/identification/presentation/providers/items_provider.dart';
import 'package:earth_nova/features/pack/domain/repositories/pack_repository.dart';
import 'package:earth_nova/features/map/domain/entities/cell_border_crossing_event.dart';
import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';
import 'package:earth_nova/features/map/domain/entities/encounter.dart';
import 'package:earth_nova/features/map/domain/rules/legacy_encounter_eligibility.dart';
import 'package:earth_nova/features/map/domain/use_cases/compute_encounter.dart';
import 'package:earth_nova/features/map/presentation/providers/encounter_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/exploration_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _definitionId = StableContentId<EncounterContent>('encounter:warbler');
final _definitionVersion = ExactVersionRef<EncounterContent>(
  stableId: _definitionId,
  versionId: ContentVersionId<EncounterContent>('version:warbler:1'),
  revision: 1,
);
final _baseItemId = StableContentId<BaseItemContent>('item:warbler');
final _baseItemVersion = ExactVersionRef<BaseItemContent>(
  stableId: _baseItemId,
  versionId: ContentVersionId<BaseItemContent>('version:item:warbler:1'),
  revision: 1,
);

CellVisit _visit() => CellVisit(
      id: 'visit-1',
      cellId: 'cell-1',
      userId: 'player-1',
      visitedAt: DateTime.utc(2026, 7, 20),
    );

CellBorderCrossingEvent _border() => CellBorderCrossingEvent(
      borderCrossingId: 'border-1',
      previousCellId: 'cell-0',
      enteredCellId: 'cell-1',
      borderCrossingType: CellBorderCrossingType.firstEntry,
      isFirstVisit: true,
      occurredAt: DateTime.utc(2026, 7, 20),
      districtId: 'district-1',
      cityId: 'city-1',
      stateId: 'state-1',
      countryId: 'country-1',
    );

EncounterEntryContext _context({
  CellVisit? visit,
  bool isFirstVisit = true,
  bool hasLootCompatibility = false,
  String deterministicSeed = 'seed-1',
  String mapEntryId = 'map-entry-1',
}) {
  final persistedVisit = visit ?? _visit();
  return EncounterEntryContext(
    rootTrace: TraceContext(
      traceId: '0123456789abcdef0123456789abcdef',
      spanId: '0123456789abcdef',
      startTime: DateTime.utc(2026, 7, 20),
    ),
    persistedCellVisit: persistedVisit,
    userId: persistedVisit.userId,
    mapEntryId: mapEntryId,
    deterministicSeed: deterministicSeed,
    isFirstVisit: isFirstVisit,
    hasLootCompatibility: hasLootCompatibility,
    borderContext: EncounterBorderContext(
      enteredCellId: persistedVisit.cellId,
      previousCellId: 'cell-0',
    ),
  );
}

final _legacyEncounter = Encounter(
  type: EncounterType.species,
  speciesId: 'amberwing_warbler',
  displayName: 'Amberwing Warbler',
  cellId: 'cell-1',
  seed: 'seed-1',
);

LegacyEncounterComputation _legacySelection() =>
    LegacyEncounterComputation.selected(
      selectorCandidateId: SelectorCandidateId('candidate:warbler'),
      definitionId: _definitionId,
      legacyEncounter: _legacyEncounter,
    );

EncounterSelectedCellVisitPlan _selectionPlan(CellVisit visit) =>
    EncounterSelectedCellVisitPlan(
      cellVisit: visit,
      selectorId: SelectorId('selector:legacy-cell-encounter'),
      selectorCandidateId: SelectorCandidateId('candidate:warbler'),
      definitionId: _definitionId,
      definitionVersion: _definitionVersion,
      isAutomatic: true,
    );

NoEncounterCellVisitPlan _nonePlan(CellVisit visit) => NoEncounterCellVisitPlan(
      cellVisit: visit,
      selectorId: SelectorId('selector:legacy-cell-encounter'),
      selectorCandidateId: SelectorCandidateId('candidate:none'),
    );

EncounterOccurrence _encounter(EncounterResolutionStatus status) =>
    EncounterOccurrence(
      id: EncounterId('encounter-1'),
      cellVisitId: CellVisitId('visit-1'),
      cellVisitResolutionId: CellVisitResolutionId('resolution-1'),
      definitionVersion: _definitionVersion,
      status: status,
      createdAt: DateTime.utc(2026, 7, 20),
      selectedOptionId: status == EncounterResolutionStatus.resolved
          ? EncounterOptionId('option-1')
          : null,
      resolvedAt: status == EncounterResolutionStatus.resolved
          ? DateTime.utc(2026, 7, 20, 0, 1)
          : null,
    );

GeneratedItemCommit _itemCommit({
  String suffix = '1',
  int ordinal = 0,
}) {
  final result = GenerateItemOutcomeResult(
    id: EncounterOutcomeResultId('result-$suffix'),
    encounterId: EncounterId('encounter-1'),
    outcomeId: EncounterOutcomeId('outcome-$suffix'),
    ordinal: ordinal,
    createdAt: DateTime.utc(2026, 7, 20, 0, 1),
    resolvedBaseItemVersion: _baseItemVersion,
  );
  return GeneratedItemCommit(
    outcomeResult: result,
    item: Item(
      id: 'item-$suffix',
      definitionId: _baseItemId.value,
      displayName: 'Amberwing Warbler $suffix',
      category: ItemCategory.fauna,
      acquiredAt: DateTime.utc(2026, 7, 20, 0, 1),
      status: ItemStatus.active,
    ),
  );
}

EncounterRuntimeAggregate _aggregate({
  required CellVisit visit,
  required CellVisitEncounterSelectionPlan selection,
  EncounterOccurrence? encounter,
  Iterable<GeneratedItemCommit> commits = const [],
  Iterable<EncounterOutcomeResult> outcomeResults = const [],
}) =>
    EncounterRuntimeAggregate(
      cellVisitResolution: selection is NoEncounterCellVisitPlan
          ? CellVisitResolution.none(
              id: CellVisitResolutionId('resolution-1'),
              cellVisitId: CellVisitId(visit.id),
              selectorId: selection.selectorId,
              selectorCandidateId: selection.selectorCandidateId,
              resolvedAt: visit.visitedAt,
            )
          : CellVisitResolution.selectedDefinition(
              id: CellVisitResolutionId('resolution-1'),
              cellVisitId: CellVisitId(visit.id),
              selectorId: selection.selectorId,
              selectorCandidateId: selection.selectorCandidateId,
              definitionId:
                  (selection as EncounterSelectedCellVisitPlan).definitionId,
              resolvedAt: visit.visitedAt,
            ),
      encounter: encounter,
      outcomeResults: outcomeResults,
      generatedItemCommits: commits,
      revealedVenueCommits: const [],
    );

final class _RecordingObservabilityService extends ObservabilityService {
  _RecordingObservabilityService() : super(sessionId: 'test-session');

  final List<({String event, String category, Map<String, dynamic>? data})>
      events = [];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    events.add((event: event, category: category, data: data));
  }
}

final class _RecordingEncounterRepository implements EncounterRepository {
  _RecordingEncounterRepository({
    required this.selectionResult,
    required this.outcomeResult,
    this.pendingEncounter,
  });

  final EncounterRuntimeAggregate selectionResult;
  final EncounterRuntimeAggregate outcomeResult;
  PendingEncounter? pendingEncounter;
  final List<CellVisitEncounterSelectionPlan> committedPlans = [];
  final List<EncounterId> resolvedEncounterIds = [];
  final List<String> pendingReadCellIds = [];
  final List<String> traceIds = [];

  @override
  Future<EncounterRuntimeAggregate> commitCellVisitSelection(
    CellVisitEncounterSelectionPlan plan, {
    required String traceId,
  }) async {
    committedPlans.add(plan);
    traceIds.add(traceId);
    return selectionResult;
  }

  @override
  Future<PendingEncounter?> readPendingEncounterForCell(
    String cellId, {
    required String traceId,
  }) async {
    pendingReadCellIds.add(cellId);
    traceIds.add(traceId);
    return pendingEncounter;
  }

  @override
  Future<EncounterRuntimeAggregate> resolveEncounterOutcomes(
    EncounterId encounterId, {
    required String traceId,
    EncounterOptionId? selectedOptionId,
  }) async {
    resolvedEncounterIds.add(encounterId);
    traceIds.add(traceId);
    return outcomeResult;
  }
}

PendingEncounter _pendingEncounter({String cellId = 'cell-1'}) =>
    PendingEncounter(
      cellId: cellId,
      encounter: _encounter(EncounterResolutionStatus.pending),
      definitionDisplayName: 'Amberwing Warbler',
      options: [
        PendingEncounterOption(
          id: EncounterOptionId('option-1'),
          ordinal: 0,
          displayName: 'Observe quietly',
        ),
      ],
    );

final class _RecordingPendingEncounterNotifier
    extends PendingEncounterNotifier {
  final List<PendingEncounter> shown = [];
  int refreshes = 0;

  @override
  PendingEncounterState build() => const PendingEncounterNone();

  @override
  void show(PendingEncounter pendingEncounter) {
    shown.add(pendingEncounter);
  }

  @override
  Future<void> refresh() async {
    refreshes += 1;
  }
}

final class _NoAcquireItemRepository implements ItemRepository {
  int acquireCalls = 0;

  @override
  Future<Item> acquireDiscoveryItem(
    DiscoveryItemDraft draft, {
    String? traceId,
  }) async {
    acquireCalls += 1;
    throw StateError('Committed encounter rewards must not be acquired again.');
  }

  @override
  Future<List<Item>> fetchItems(String userId, {String? traceId}) async => [];

  @override
  Future<Item> identifyUnidentifiedFind(
    Item item, {
    String? traceId,
  }) async =>
      item;
  @override
  Future<Item> examineItem(Item item, {String? traceId}) =>
      throw UnimplementedError();
}

final class _StubComputeEncounter extends ComputeEncounter {
  _StubComputeEncounter(this.result) : super(_RecordingObservabilityService());

  final Encounter? result;
  ComputeEncounterInput? receivedInput;

  @override
  Future<Encounter?> execute(
    ComputeEncounterInput input,
    String traceId,
  ) async {
    receivedInput = input;
    return result;
  }
}

final class _RecordingItemRepository implements ItemRepository {
  final List<DiscoveryItemDraft> acquiredDrafts = [];

  @override
  Future<Item> acquireDiscoveryItem(
    DiscoveryItemDraft draft, {
    String? traceId,
  }) async {
    acquiredDrafts.add(draft);
    return _itemCommit().item;
  }

  @override
  Future<List<Item>> fetchItems(String userId, {String? traceId}) async => [];

  @override
  Future<Item> identifyUnidentifiedFind(
    Item item, {
    String? traceId,
  }) async =>
      item;
  @override
  Future<Item> examineItem(Item item, {String? traceId}) =>
      throw UnimplementedError();
}

final class _EmptyPackRepository implements PackRepository {
  @override
  Future<List<Item>> fetchActiveItems(String userId, {String? traceId}) async =>
      [];
}

final class _FixedCurrentEncounterVersionBindingRepository
    implements CurrentEncounterVersionBindingRepository {
  _FixedCurrentEncounterVersionBindingRepository(this.binding);

  final ExactVersionRef<EncounterContent>? binding;
  final List<StableContentId<EncounterContent>> requestedDefinitionIds = [];

  @override
  Future<CurrentEncounterVersionBinding?>
      currentPublishedVersionForNewCellVisit(
    StableContentId<EncounterContent> definitionId, {
    String? traceId,
  }) async {
    requestedDefinitionIds.add(definitionId);
    final exactVersion = binding;
    return exactVersion == null
        ? null
        : CurrentEncounterVersionBinding(
            version: exactVersion,
            isAutomatic: true,
          );
  }
}

void main() {
  group('encounter entry runtime provider', () {
    test(
        'production Supabase Encounter repositories receive the active observability logger',
        () {
      final source = File(
        'lib/features/encounters/presentation/providers/encounter_entry_provider.dart',
      ).readAsStringSync();
      final currentVersionBindingProvider = source.substring(
        source.indexOf(
          'final currentEncounterVersionBindingRepositoryProvider =',
        ),
        source.indexOf('final encounterCommandRepositoryProvider ='),
      );
      final commandRepositoryProvider = source.substring(
        source.indexOf('final encounterCommandRepositoryProvider ='),
        source.indexOf('final resolveCellVisitEncounterSelectorProvider ='),
      );

      for (final providerSource in [
        currentVersionBindingProvider,
        commandRepositoryProvider,
      ]) {
        expect(
          providerSource,
          contains('final obs = ref.watch(encounterObservabilityProvider);'),
        );
        expect(providerSource, contains('logEvent: obs.log,'));
      }
      expect(
        currentVersionBindingProvider,
        contains(
          'SupabaseCurrentEncounterVersionBindingRepository.fromSupabase(',
        ),
      );
      expect(
        commandRepositoryProvider,
        contains('SupabaseEncounterRepository.fromSupabase('),
      );
    });

    test(
        'composes the selector planner with the narrow current Version binding port',
        () async {
      final definitionId = legacyCellEncounterDefinitionIds.first;
      final binding = ExactVersionRef<EncounterContent>(
        stableId: definitionId,
        versionId: ContentVersionId<EncounterContent>('version:warbler:9'),
        revision: 9,
      );
      final repository =
          _FixedCurrentEncounterVersionBindingRepository(binding);
      final container = ProviderContainer(
        overrides: [
          currentEncounterVersionBindingRepositoryProvider
              .overrideWithValue(repository),
          encounterObservabilityProvider.overrideWithValue(
            _RecordingObservabilityService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final plan =
          await container.read(resolveCellVisitEncounterSelectorProvider)(
        ResolveCellVisitEncounterSelectorInput(
          cellVisit: _visit(),
          selectorId: legacyCellEncounterSelectorId,
          selector: buildLegacyCellEncounterCompatibilitySelector(),
          selectorContext: const LegacyEncounterEligibilityContext(
            isFirstVisit: true,
            hasLegacyLoot: false,
          ),
          rollSource: () => 0,
        ),
      );

      final selected = plan as EncounterSelectedCellVisitPlan;
      expect(selected.definitionId, definitionId);
      expect(selected.definitionVersion, binding);
      expect(repository.requestedDefinitionIds, [definitionId]);
    });

    test(
        'legacy computation preserves compute inputs and returns the compatible selected candidate',
        () async {
      final compute = _StubComputeEncounter(_legacyEncounter);
      final context = _context();
      final container = ProviderContainer(
        overrides: [
          computeEncounterProvider.overrideWithValue(compute),
        ],
      );
      addTearDown(container.dispose);

      final computation =
          await container.read(legacyEncounterComputationProvider)(context);
      final selectedCandidate =
          buildLegacyCellEncounterCompatibilitySelector().resolveCandidate(
        const LegacyEncounterEligibilityContext(
          isFirstVisit: true,
          hasLegacyLoot: false,
        ),
        () => legacyCellEncounterRoll(
          seed: context.deterministicSeed,
          cellId: context.persistedCellVisit.cellId,
        ),
      );

      expect(compute.receivedInput, (
        cellId: context.persistedCellVisit.cellId,
        seed: context.deterministicSeed,
        isFirstVisit: true,
        hasLoot: false,
      ));
      expect(computation.isEligible, isTrue);
      expect(
        computation.selectorCandidateId,
        SelectorCandidateId(selectedCandidate.id),
      );
      expect(
        computation.definitionId,
        (selectedCandidate.result
                as SelectedValue<StableContentId<EncounterContent>>)
            .value,
      );
      expect(computation.legacyEncounter, same(_legacyEncounter));
    });

    test(
        'legacy computation returns no selection when legacy compute returns null',
        () async {
      final compute = _StubComputeEncounter(null);
      final container = ProviderContainer(
        overrides: [
          computeEncounterProvider.overrideWithValue(compute),
        ],
      );
      addTearDown(container.dispose);

      final computation =
          await container.read(legacyEncounterComputationProvider)(
        _context(isFirstVisit: false, hasLootCompatibility: false),
      );

      expect(computation.isEligible, isFalse);
      expect(computation.selectorCandidateId, isNull);
      expect(computation.definitionId, isNull);
      expect(computation.legacyEncounter, isNull);
    });

    test(
        'legacy computation rejects a legacy result when compatibility selection is None',
        () async {
      final compute = _StubComputeEncounter(_legacyEncounter);
      final container = ProviderContainer(
        overrides: [
          computeEncounterProvider.overrideWithValue(compute),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(legacyEncounterComputationProvider)(
          _context(isFirstVisit: false, hasLootCompatibility: false),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Legacy encounter compute selected no compatible candidate.',
          ),
        ),
      );
    });

    test('versioned planner maps selected and explicit None selector plans',
        () async {
      final context = _context();
      final selectedCandidate =
          buildLegacyCellEncounterCompatibilitySelector().resolveCandidate(
        const LegacyEncounterEligibilityContext(
          isFirstVisit: true,
          hasLegacyLoot: false,
        ),
        () => legacyCellEncounterRoll(
          seed: context.deterministicSeed,
          cellId: context.persistedCellVisit.cellId,
        ),
      );
      final selectedDefinition = (selectedCandidate.result
              as SelectedValue<StableContentId<EncounterContent>>)
          .value;
      final version = ExactVersionRef<EncounterContent>(
        stableId: selectedDefinition,
        versionId: ContentVersionId<EncounterContent>(
          'version:${selectedDefinition.value}:1',
        ),
        revision: 1,
      );
      final bindingRepository =
          _FixedCurrentEncounterVersionBindingRepository(version);
      final container = ProviderContainer(
        overrides: [
          currentEncounterVersionBindingRepositoryProvider
              .overrideWithValue(bindingRepository),
          encounterObservabilityProvider.overrideWithValue(
            _RecordingObservabilityService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final selected =
          await container.read(versionedEncounterPlannerProvider)(context);
      final none = await container.read(versionedEncounterPlannerProvider)(
        _context(isFirstVisit: false, hasLootCompatibility: false),
      );

      expect(selected.selection, isA<EncounterSelectedCellVisitPlan>());
      expect(selected.isAutomatic, isTrue);
      expect(
        (selected.selection as EncounterSelectedCellVisitPlan)
            .definitionVersion,
        version,
      );
      expect(none.selection, isA<NoEncounterCellVisitPlan>());
      expect(none.isAutomatic, isFalse);
      expect(
        bindingRepository.requestedDefinitionIds,
        [(selected.selection as EncounterSelectedCellVisitPlan).definitionId],
      );
    });

    test('null Supabase client exposes explicit unavailable repository errors',
        () async {
      final visit = _visit();
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await expectLater(
        container
            .read(currentEncounterVersionBindingRepositoryProvider)
            .currentPublishedVersionForNewCellVisit(_definitionId),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Encounter Version binding requires Supabase.',
          ),
        ),
      );
      final repository = container.read(encounterCommandRepositoryProvider);
      await expectLater(
        repository.commitCellVisitSelection(
          _selectionPlan(visit),
          traceId: 'trace-1',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Encounter commands require Supabase.',
          ),
        ),
      );
      await expectLater(
        repository.resolveEncounterOutcomes(
          EncounterId('encounter-1'),
          traceId: 'trace-1',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
        'writer and committed rewards presenter delegate the exact persisted visit context',
        () async {
      final context = _context();
      final itemRepository = _RecordingItemRepository();
      final obs = _RecordingObservabilityService();
      final container = ProviderContainer(
        overrides: [
          encounterObservabilityProvider.overrideWithValue(obs),
          itemsObservabilityProvider.overrideWithValue(obs),
          itemRepositoryProvider.overrideWithValue(itemRepository),
          packRepositoryProvider.overrideWithValue(_EmptyPackRepository()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(legacyEncounterWriterProvider)(
        context,
        _legacySelection(),
      );

      expect(itemRepository.acquiredDrafts, hasLength(1));
      final draft = itemRepository.acquiredDrafts.single;
      expect(draft.userId, context.userId);
      expect(draft.acquiredInCellId, context.persistedCellVisit.cellId);
      expect(draft.mapCellEntryId, context.mapEntryId);
      expect(
        container.read(encounterProvider).currentEncounter?.acquiredItem?.id,
        'item-1',
      );

      final presenterContext = _context(mapEntryId: 'map-entry-2');
      final secondItem = _itemCommit(suffix: 'presented', ordinal: 1);
      await container.read(committedRewardsPresenterProvider)(
        presenterContext,
        _legacySelection(),
        [secondItem],
      );

      expect(
        container.read(itemsProvider).items.map((item) => item.id),
        unorderedEquals(['item-1', 'item-presented']),
      );
      expect(
        container.read(encounterProvider).queuedRewards.single.acquiredItem?.id,
        'item-presented',
      );
      expect(
        obs.events
            .where((event) => event.event == 'discovery.acquisition_committed')
            .map((event) => event.data?['map_cell_entry_id']),
        [context.mapEntryId, presenterContext.mapEntryId],
      );
    });

    test(
        'shadow planning never invokes command repository and falls back to legacy on planner failure',
        () async {
      final visit = _visit();
      final plan = _selectionPlan(visit);
      final repository = _RecordingEncounterRepository(
        selectionResult: _aggregate(visit: visit, selection: plan),
        outcomeResult: _aggregate(visit: visit, selection: plan),
      );
      var legacyWrites = 0;
      final container = ProviderContainer(
        overrides: [
          encounterEngineModeResolutionProvider.overrideWithValue(
            EncounterEngineModeResolution.parse(
              requestedValue: 'shadowPlanning',
              clientVerifiedWriteAuthorized: false,
            ),
          ),
          legacyEncounterComputationProvider.overrideWithValue(
            (_) async => _legacySelection(),
          ),
          legacyEncounterWriterProvider.overrideWithValue(
            (_, __) async => legacyWrites += 1,
          ),
          versionedEncounterPlannerProvider.overrideWithValue(
            (_) async => throw StateError('planner unavailable'),
          ),
          encounterCommandRepositoryProvider.overrideWithValue(repository),
          committedRewardsPresenterProvider.overrideWithValue(
            (_, __, ___) async => fail('shadow mode must not present a commit'),
          ),
          encounterDailySeedProvider.overrideWithValue('seed-1'),
          encounterObservabilityProvider.overrideWithValue(
            _RecordingObservabilityService(),
          ),
          explorationObservabilityProvider.overrideWithValue(
            _RecordingObservabilityService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(persistedCellVisitEncounterHandlerProvider)(
        visit,
        _border(),
      );

      expect(legacyWrites, 1);
      expect(repository.committedPlans, isEmpty);
      expect(repository.resolvedEncounterIds, isEmpty);
    });

    test(
        'authorized v3 invokes the two RPC-owned operations, registers all committed Items, and presents them in Outcome order',
        () async {
      final visit = _visit();
      final plan = _selectionPlan(visit);
      final firstItem = _itemCommit(suffix: 'first', ordinal: 0);
      final secondItem = _itemCommit(suffix: 'second', ordinal: 1);
      final repository = _RecordingEncounterRepository(
        selectionResult: _aggregate(
          visit: visit,
          selection: plan,
          encounter: _encounter(EncounterResolutionStatus.pending),
        ),
        outcomeResult: _aggregate(
          visit: visit,
          selection: plan,
          encounter: _encounter(EncounterResolutionStatus.resolved),
          commits: [firstItem, secondItem],
          outcomeResults: [firstItem.outcomeResult, secondItem.outcomeResult],
        ),
      );
      final itemRepository = _NoAcquireItemRepository();
      final obs = _RecordingObservabilityService();
      final container = ProviderContainer(
        overrides: [
          encounterEngineModeResolutionProvider.overrideWithValue(
            EncounterEngineModeResolution.parse(
              requestedValue: 'v3Authoritative',
              clientVerifiedWriteAuthorized: true,
            ),
          ),
          legacyEncounterComputationProvider.overrideWithValue(
            (_) async => _legacySelection(),
          ),
          legacyEncounterWriterProvider.overrideWithValue(
            (_, __) async =>
                fail('authoritative mode must not use legacy writer'),
          ),
          versionedEncounterPlannerProvider.overrideWithValue(
            (_) async => VersionedEncounterPlan.selected(
              selection: plan,
              isAutomatic: true,
            ),
          ),
          encounterCommandRepositoryProvider.overrideWithValue(repository),
          encounterDailySeedProvider.overrideWithValue('seed-1'),
          encounterObservabilityProvider.overrideWithValue(obs),
          explorationObservabilityProvider.overrideWithValue(obs),
          itemsObservabilityProvider.overrideWithValue(obs),
          itemRepositoryProvider.overrideWithValue(itemRepository),
          packRepositoryProvider.overrideWithValue(_EmptyPackRepository()),
        ],
      );
      addTearDown(container.dispose);
      final rootTrace = TraceContext(
        traceId: '0123456789abcdef0123456789abcdef',
        spanId: '0123456789abcdef',
        startTime: DateTime.utc(2026, 7, 20),
      );

      await container.read(persistedCellVisitEncounterHandlerProvider)(
        visit,
        _border(),
        rootTrace: rootTrace,
      );

      expect(repository.committedPlans, hasLength(1));
      expect(repository.committedPlans.single.cellVisit, same(visit));
      expect(
        container.read(itemsProvider).items.map((item) => item.id),
        unorderedEquals(['item-first', 'item-second']),
      );
      expect(
        container.read(encounterProvider).currentEncounter?.acquiredItem?.id,
        'item-first',
      );
      expect(
        container
            .read(encounterProvider)
            .queuedRewards
            .map((reward) => reward.acquiredItem?.id),
        ['item-second'],
      );
      expect(
        obs.events
            .where((entry) => entry.event == 'discovery.reward_presented'),
        hasLength(1),
      );
      expect(
        repository.traceIds,
        [rootTrace.traceId, rootTrace.traceId, rootTrace.traceId],
      );
      expect(
        obs.events
            .where((entry) => entry.category == 'encounter')
            .map((entry) => entry.data?['trace_id']),
        everyElement(rootTrace.traceId),
      );
    });

    test('explicit None commits selection only and creates no reward',
        () async {
      final visit = _visit();
      final plan = _nonePlan(visit);
      final repository = _RecordingEncounterRepository(
        selectionResult: _aggregate(visit: visit, selection: plan),
        outcomeResult: _aggregate(visit: visit, selection: plan),
      );
      var presented = 0;
      final container = ProviderContainer(
        overrides: [
          encounterEngineModeResolutionProvider.overrideWithValue(
            EncounterEngineModeResolution.parse(
              requestedValue: 'v3Authoritative',
              clientVerifiedWriteAuthorized: true,
            ),
          ),
          legacyEncounterComputationProvider.overrideWithValue(
            (_) async => const LegacyEncounterComputation.noSelection(),
          ),
          legacyEncounterWriterProvider.overrideWithValue(
            (_, __) async =>
                fail('authoritative mode must not use legacy writer'),
          ),
          versionedEncounterPlannerProvider.overrideWithValue(
            (_) async => VersionedEncounterPlan.none(plan),
          ),
          encounterCommandRepositoryProvider.overrideWithValue(repository),
          committedRewardsPresenterProvider.overrideWithValue(
            (_, __, ___) async => presented += 1,
          ),
          encounterDailySeedProvider.overrideWithValue('seed-1'),
          encounterObservabilityProvider.overrideWithValue(
            _RecordingObservabilityService(),
          ),
          explorationObservabilityProvider.overrideWithValue(
            _RecordingObservabilityService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(persistedCellVisitEncounterHandlerProvider)(
        visit,
        _border(),
      );

      expect(repository.committedPlans, hasLength(1));
      expect(repository.resolvedEncounterIds, isEmpty);
      expect(presented, 0);
    });

    test(
        'authoritative re-entry shows the existing pending encounter without planning, committing, or resolving',
        () async {
      final visit = _visit();
      final plan = _selectionPlan(visit);
      final pending = _pendingEncounter();
      final repository = _RecordingEncounterRepository(
        selectionResult: _aggregate(visit: visit, selection: plan),
        outcomeResult: _aggregate(visit: visit, selection: plan),
        pendingEncounter: pending,
      );
      final pendingNotifier = _RecordingPendingEncounterNotifier();
      var plannerCalls = 0;
      final container = ProviderContainer(
        overrides: [
          encounterEngineModeResolutionProvider.overrideWithValue(
            EncounterEngineModeResolution.parse(
              requestedValue: 'v3Authoritative',
              clientVerifiedWriteAuthorized: true,
            ),
          ),
          legacyEncounterComputationProvider.overrideWithValue(
            (_) async => fail('existing pending encounter must short-circuit'),
          ),
          versionedEncounterPlannerProvider.overrideWithValue((_) async {
            plannerCalls += 1;
            throw StateError('existing pending encounter must not plan');
          }),
          encounterCommandRepositoryProvider.overrideWithValue(repository),
          pendingEncounterProvider.overrideWith(() => pendingNotifier),
          encounterDailySeedProvider.overrideWithValue('seed-1'),
          encounterObservabilityProvider.overrideWithValue(
            _RecordingObservabilityService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(persistedCellVisitEncounterHandlerProvider)(
        visit,
        _border(),
      );

      expect(repository.pendingReadCellIds, ['cell-1']);
      expect(plannerCalls, 0);
      expect(repository.committedPlans, isEmpty);
      expect(repository.resolvedEncounterIds, isEmpty);
      expect(pendingNotifier.shown, [same(pending)]);
      expect(pendingNotifier.refreshes, 0);
    });

    test(
        'a newly committed manual encounter refreshes pending state without resolving or presenting rewards',
        () async {
      final visit = _visit();
      final plan = _selectionPlan(visit);
      final repository = _RecordingEncounterRepository(
        selectionResult: _aggregate(
          visit: visit,
          selection: plan,
          encounter: _encounter(EncounterResolutionStatus.pending),
        ),
        outcomeResult: _aggregate(visit: visit, selection: plan),
      );
      final pendingNotifier = _RecordingPendingEncounterNotifier();
      final container = ProviderContainer(
        overrides: [
          encounterEngineModeResolutionProvider.overrideWithValue(
            EncounterEngineModeResolution.parse(
              requestedValue: 'v3Authoritative',
              clientVerifiedWriteAuthorized: true,
            ),
          ),
          legacyEncounterComputationProvider.overrideWithValue(
            (_) async => _legacySelection(),
          ),
          legacyEncounterWriterProvider.overrideWithValue(
            (_, __) async =>
                fail('authoritative mode must not use legacy writer'),
          ),
          versionedEncounterPlannerProvider.overrideWithValue(
            (_) async => VersionedEncounterPlan.selected(
              selection: plan,
              isAutomatic: false,
            ),
          ),
          encounterCommandRepositoryProvider.overrideWithValue(repository),
          committedRewardsPresenterProvider.overrideWithValue(
            (_, __, ___) async =>
                fail('manual pending encounter must not present rewards'),
          ),
          pendingEncounterProvider.overrideWith(() => pendingNotifier),
          encounterDailySeedProvider.overrideWithValue('seed-1'),
          encounterObservabilityProvider.overrideWithValue(
            _RecordingObservabilityService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(persistedCellVisitEncounterHandlerProvider)(
        visit,
        _border(),
      );

      expect(repository.pendingReadCellIds, ['cell-1']);
      expect(repository.committedPlans, hasLength(1));
      expect(repository.resolvedEncounterIds, isEmpty);
      expect(pendingNotifier.shown, isEmpty);
      expect(pendingNotifier.refreshes, 1);
    });

    test(
        'persisted, comparison, and terminal traces retain mode, gate, comparison, and mutation dimensions',
        () async {
      final visit = _visit();
      final plan = _selectionPlan(visit);
      final obs = _RecordingObservabilityService();
      final repository = _RecordingEncounterRepository(
        selectionResult: _aggregate(visit: visit, selection: plan),
        outcomeResult: _aggregate(visit: visit, selection: plan),
      );
      final mode = EncounterEngineModeResolution.parse(
        requestedValue: 'v3Authoritative',
        clientVerifiedWriteAuthorized: false,
      );
      final container = ProviderContainer(
        overrides: [
          encounterEngineModeResolutionProvider.overrideWithValue(mode),
          legacyEncounterComputationProvider.overrideWithValue(
            (_) async => _legacySelection(),
          ),
          legacyEncounterWriterProvider.overrideWithValue((_, __) async {}),
          versionedEncounterPlannerProvider.overrideWithValue(
            (_) async => VersionedEncounterPlan.selected(
              selection: plan,
              isAutomatic: true,
            ),
          ),
          encounterCommandRepositoryProvider.overrideWithValue(repository),
          committedRewardsPresenterProvider
              .overrideWithValue((_, __, ___) async {}),
          encounterDailySeedProvider.overrideWithValue('seed-1'),
          encounterObservabilityProvider.overrideWithValue(obs),
          explorationObservabilityProvider.overrideWithValue(obs),
        ],
      );
      addTearDown(container.dispose);

      await container.read(persistedCellVisitEncounterHandlerProvider)(
        visit,
        _border(),
      );

      final persisted = obs.events.singleWhere(
        (entry) => entry.event == 'encounter.entry.persisted_visit',
      );
      final comparison = obs.events.singleWhere(
        (entry) => entry.event == 'encounter.entry.comparison',
      );
      final terminal = obs.events.singleWhere(
        (entry) => entry.event == 'encounter.entry.terminal',
      );
      for (final event in [persisted, comparison, terminal]) {
        expect(event.data?['persisted_cell_visit_id'], 'visit-1');
        expect(event.data?['cell_id'], 'cell-1');
        expect(event.data?['map_cell_entry_id'], 'border-1');
        expect(event.data?['requested_mode'], 'v3Authoritative');
        expect(event.data?['effective_mode'], 'shadowPlanning');
        expect(
          event.data?['mode_gate'],
          'v3ClientVerifiedWritesNotAuthorized',
        );
        expect(event.data, isNot(contains('user_id')));
      }
      expect(comparison.data?['eligibility_comparison'], 'matched');
      expect(comparison.data?['candidate_comparison'], 'matched');
      expect(comparison.data?['definition_comparison'], 'matched');
      expect(
        comparison.data?['exact_version_comparison'],
        'notComparableLegacyDoesNotBindExactVersion',
      );
      expect(terminal.data?['terminal'], 'shadowPlanningExecutedLegacy');
      expect(terminal.data?['item_mutation_owner'], 'legacy');
      expect(repository.committedPlans, isEmpty);
    });

    test('coordination exceptions emit a complete safe terminal trace',
        () async {
      final visit = _visit();
      final plan = _selectionPlan(visit);
      final obs = _RecordingObservabilityService();
      final repository = _RecordingEncounterRepository(
        selectionResult: _aggregate(visit: visit, selection: plan),
        outcomeResult: _aggregate(visit: visit, selection: plan),
      );
      final container = ProviderContainer(
        overrides: [
          encounterEngineModeResolutionProvider.overrideWithValue(
            EncounterEngineModeResolution.parse(
              requestedValue: 'legacy',
              clientVerifiedWriteAuthorized: false,
            ),
          ),
          legacyEncounterComputationProvider.overrideWithValue(
            (_) async => throw StateError('safe-test-failure'),
          ),
          legacyEncounterWriterProvider.overrideWithValue((_, __) async {}),
          versionedEncounterPlannerProvider.overrideWithValue(
            (_) async => VersionedEncounterPlan.selected(
              selection: plan,
              isAutomatic: true,
            ),
          ),
          encounterCommandRepositoryProvider.overrideWithValue(repository),
          committedRewardsPresenterProvider
              .overrideWithValue((_, __, ___) async {}),
          encounterDailySeedProvider.overrideWithValue('seed-1'),
          encounterObservabilityProvider.overrideWithValue(obs),
          explorationObservabilityProvider.overrideWithValue(obs),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(persistedCellVisitEncounterHandlerProvider)(
          visit,
          _border(),
        ),
        throwsA(isA<StateError>()),
      );

      final terminal = obs.events.singleWhere(
        (entry) => entry.event == 'encounter.entry.terminal',
      );
      expect(terminal.data?['terminal'], 'coordinationFailed');
      expect(terminal.data?['item_mutation_owner'], 'unknown');
      expect(terminal.data?['requested_mode'], 'legacy');
      expect(terminal.data?['effective_mode'], 'legacy');
      expect(terminal.data?['error_type'], 'StateError');
      expect(terminal.data, isNot(contains('user_id')));
      expect(
        terminal.data?.values,
        isNot(contains(contains('safe-test-failure'))),
      );
    });
  });
}
