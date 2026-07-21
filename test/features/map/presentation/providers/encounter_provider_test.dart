import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/observable_use_case_provider.dart';
import 'package:earth_nova/features/identification/domain/entities/discovery_item_draft.dart';
import 'package:earth_nova/features/identification/domain/repositories/item_repository.dart';
import 'package:earth_nova/features/identification/presentation/providers/items_provider.dart';
import 'package:earth_nova/features/pack/data/repositories/legacy_item_repository_pack_adapter.dart';
import 'package:earth_nova/features/map/domain/entities/encounter.dart';
import 'package:earth_nova/features/map/domain/use_cases/compute_encounter.dart';
import 'package:earth_nova/features/map/presentation/providers/encounter_provider.dart';

class TestObservabilityService extends ObservabilityService {
  TestObservabilityService() : super(sessionId: 'test-session');

  final List<({String event, String category, Map<String, dynamic>? data})>
      events = [];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    events.add((event: event, category: category, data: data));
    super.log(event, category, data: data);
  }

  List<String> get eventNames => events.map((e) => e.event).toList();
}

class RecordingItemRepository implements ItemRepository {
  final acquiredDrafts = <DiscoveryItemDraft>[];
  final ownedItems = <Item>[];
  bool shouldThrowOnAcquire = false;

  @override
  Future<List<Item>> fetchItems(String userId, {String? traceId}) async {
    return ownedItems
        .where((item) => item.status == ItemStatus.active)
        .toList();
  }

  @override
  Future<Item> acquireDiscoveryItem(
    DiscoveryItemDraft draft, {
    String? traceId,
  }) async {
    if (shouldThrowOnAcquire) {
      throw Exception('acquire failed');
    }
    acquiredDrafts.add(draft);
    for (final item in ownedItems) {
      if (item.definitionId == draft.definitionId &&
          item.acquiredInCellId == draft.acquiredInCellId) {
        return item;
      }
    }
    final item = Item(
      id: 'owned-${acquiredDrafts.length}',
      definitionId: draft.definitionId,
      displayName: draft.displayName,
      scientificName: draft.scientificName,
      category: draft.category,
      rarity: draft.rarity,
      acquiredAt: DateTime(2026, 1, acquiredDrafts.length),
      acquiredInCellId: draft.acquiredInCellId,
      status: ItemStatus.active,
      taxonomicClass: draft.taxonomicClass,
      habitats: draft.habitats,
      continents: draft.continents,
      identificationState: draft.identificationState,
      identifiedAt: draft.identifiedAt,
      identifiedDisplayName: draft.identifiedDisplayName,
      identifiedScientificName: draft.identifiedScientificName,
      identifiedTaxonomicClass: draft.identifiedTaxonomicClass,
      identifiedHabitats: draft.identifiedHabitats,
      identifiedContinents: draft.identifiedContinents,
    );
    ownedItems.add(item);
    return item;
  }

  @override
  Future<Item> identifyUnidentifiedFind(
    Item item, {
    String? traceId,
  }) async {
    final identified = item.identify();
    final index = ownedItems.indexWhere((candidate) => candidate.id == item.id);
    if (index == -1) {
      ownedItems.add(identified);
    } else {
      ownedItems[index] = identified;
    }
    return identified;
  }
}

void main() {
  group('EncounterProvider', () {
    late ProviderContainer container;
    late TestObservabilityService testObs;

    late RecordingItemRepository itemRepo;
    setUp(() {
      testObs = TestObservabilityService();
      itemRepo = RecordingItemRepository();
      container = ProviderContainer(
        overrides: [
          encounterObservabilityProvider.overrideWithValue(testObs),
          computeEncounterProvider.overrideWithValue(ComputeEncounter(testObs)),
          itemsObservabilityProvider.overrideWithValue(testObs),
          observableUseCaseProvider.overrideWithValue(testObs),
          itemRepositoryProvider.overrideWithValue(itemRepo),
          packRepositoryProvider.overrideWithValue(
            LegacyItemRepositoryPackAdapter(itemRepo),
          ),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state has no current encounter', () {
      final state = container.read(encounterProvider);
      expect(state.currentEncounter, isNull);
    });

    test('encounterObservabilityProvider throws when not overridden', () {
      final c = ProviderContainer();
      expect(() => c.read(encounterObservabilityProvider), throwsA(anything));
      c.dispose();
    });

    test('computeEncounterProvider builds from the observability override', () {
      final c = ProviderContainer(
        overrides: [
          encounterObservabilityProvider.overrideWithValue(testObs),
        ],
      );
      final useCase = c.read(computeEncounterProvider);
      expect(useCase.obs, same(testObs));
      c.dispose();
    });

    test('first visit triggers species encounter', () async {
      final notifier = container.read(encounterProvider.notifier);

      await notifier.onCellEntered(
        cellId: 'cell_123',
        isFirstVisit: true,
        seed: 'daily_seed_2026_04_06',
      );

      final state = container.read(encounterProvider);
      expect(state.currentEncounter, isNotNull);
      expect(state.currentEncounter!.type, EncounterType.species);
      expect(state.currentEncounter!.cellId, 'cell_123');

      // Verify observability logging
      expect(testObs.eventNames.contains('map.encounter_triggered'), isTrue);
      final encounterLog = testObs.events
          .firstWhere((l) => l.event == 'map.encounter_triggered');
      expect(encounterLog.data?['cellId'], 'cell_123');
      expect(encounterLog.data?['encounterType'], 'species');
    });

    test(
        'first visit with a user commits unidentified find before showing encounter',
        () async {
      final notifier = container.read(encounterProvider.notifier);

      await notifier.onCellEntered(
        cellId: 'cell_123',
        isFirstVisit: true,
        seed: 'daily_seed_2026_04_06',
        userId: 'user-123',
        mapCellEntryId: 'entry-1',
      );

      final state = container.read(encounterProvider);
      final packState = container.read(itemsProvider);

      expect(itemRepo.acquiredDrafts, hasLength(1));
      expect(itemRepo.acquiredDrafts.single.userId, 'user-123');
      expect(itemRepo.acquiredDrafts.single.acquiredInCellId, 'cell_123');
      expect(itemRepo.acquiredDrafts.single.mapCellEntryId, 'entry-1');
      expect(itemRepo.acquiredDrafts.single.identificationState,
          ItemIdentificationState.unidentified);
      expect(itemRepo.acquiredDrafts.single.displayName,
          'Unidentified fauna specimen');
      expect(itemRepo.acquiredDrafts.single.identifiedDisplayName, isNotNull);
      expect(state.currentEncounter, isNotNull);
      expect(state.currentEncounter!.acquiredItem, isNotNull);
      expect(state.currentEncounter!.acquiredItem!.id, 'owned-1');
      expect(state.currentEncounter!.acquiredItem!.identificationState,
          ItemIdentificationState.unidentified);
      expect(packState.items, hasLength(1));
      expect(packState.items.single.displayName, 'Unidentified fauna specimen');
      expect(packState.items.single.scientificName, isNull);
      expect(packState.items.single.identifiedDisplayName,
          state.currentEncounter!.displayName);
      expect(testObs.eventNames, contains('discovery.result_resolved'));
      expect(testObs.eventNames, contains('discovery.acquisition_committed'));
      expect(testObs.eventNames, contains('discovery.reward_presented'));
      expect(testObs.eventNames, contains('map.encounter_triggered'));
    });
    test('precomputed legacy writer acquires and registers exactly once',
        () async {
      final encounter = Encounter(
        type: EncounterType.species,
        speciesId: 'amberwing_warbler',
        displayName: 'Amberwing Warbler',
        cellId: 'cell_123',
        seed: 'shared-daily-seed',
      );
      final notifier = container.read(encounterProvider.notifier);

      await notifier.writePrecomputedLegacyEncounter(
        encounter: encounter,
        cellId: 'cell_123',
        mapCellEntryId: 'persisted-entry-1',
        userId: 'user-123',
      );
      await notifier.writePrecomputedLegacyEncounter(
        encounter: encounter,
        cellId: 'cell_123',
        mapCellEntryId: 'persisted-entry-1',
        userId: 'user-123',
      );

      expect(itemRepo.acquiredDrafts, hasLength(1));
      expect(
          itemRepo.acquiredDrafts.single.mapCellEntryId, 'persisted-entry-1');
      expect(container.read(itemsProvider).items, hasLength(1));
      expect(container.read(itemsProvider).items.single.id, 'owned-1');
      expect(
          container.read(encounterProvider).currentEncounter?.acquiredItem?.id,
          'owned-1');
    });

    test('continuing reward starts card flight and impacts Pack after landing',
        () async {
      final notifier = container.read(encounterProvider.notifier);

      await notifier.onCellEntered(
        cellId: 'cell_123',
        isFirstVisit: true,
        seed: 'daily_seed_2026_04_06',
        userId: 'user-123',
        mapCellEntryId: 'entry-1',
      );

      notifier.continueDiscoveryReward();

      var state = container.read(encounterProvider);
      expect(state.currentEncounter, isNull);
      expect(state.flyingReward, isNotNull);
      expect(state.packImpactCount, 0);
      expect(testObs.eventNames, contains('discovery.reward_continued'));
      expect(testObs.eventNames, isNot(contains('pack.reward_impact')));

      notifier.completeRewardFlight();

      state = container.read(encounterProvider);
      expect(state.flyingReward, isNull);
      expect(state.packImpactCount, 1);
      expect(testObs.eventNames, contains('pack.reward_impact'));
    });

    test('queued rewards wait until the active card flight completes',
        () async {
      final notifier = container.read(encounterProvider.notifier);

      await notifier.onCellEntered(
        cellId: 'cell_123',
        isFirstVisit: true,
        seed: 'daily_seed_2026_04_06',
        userId: 'user-123',
        mapCellEntryId: 'entry-1',
      );
      await notifier.onCellEntered(
        cellId: 'cell_456',
        isFirstVisit: true,
        seed: 'daily_seed_2026_04_07',
        userId: 'user-123',
        mapCellEntryId: 'entry-2',
      );

      var state = container.read(encounterProvider);
      expect(state.currentEncounter?.cellId, 'cell_123');
      expect(state.queuedRewards, hasLength(1));
      expect(state.queuedRewards.single.cellId, 'cell_456');
      expect(testObs.eventNames, contains('discovery.reward_queued'));

      notifier.continueDiscoveryReward();
      state = container.read(encounterProvider);
      expect(state.currentEncounter, isNull);
      expect(state.flyingReward?.cellId, 'cell_123');
      expect(state.queuedRewards, hasLength(1));

      notifier.completeRewardFlight();
      state = container.read(encounterProvider);
      expect(state.flyingReward, isNull);
      expect(state.currentEncounter?.cellId, 'cell_456');
      expect(state.queuedRewards, isEmpty);
    });

    test('reward continuation helpers are no-ops without active rewards', () {
      final notifier = container.read(encounterProvider.notifier);

      notifier.continueDiscoveryReward();
      notifier.completeRewardFlight();

      final state = container.read(encounterProvider);
      expect(state.currentEncounter, isNull);
      expect(state.flyingReward, isNull);
      expect(state.queuedRewards, isEmpty);
      expect(state.packImpactCount, 0);
      expect(testObs.eventNames, isNot(contains('discovery.reward_continued')));
      expect(testObs.eventNames, isNot(contains('pack.reward_impact')));
    });

    test('completed reward flight clears when there is no queued reward',
        () async {
      final notifier = container.read(encounterProvider.notifier);

      await notifier.onCellEntered(
        cellId: 'cell_123',
        isFirstVisit: true,
        seed: 'daily_seed_2026_04_06',
        userId: 'user-123',
        mapCellEntryId: 'entry-1',
      );
      notifier.continueDiscoveryReward();
      notifier.completeRewardFlight();

      final state = container.read(encounterProvider);
      expect(state.currentEncounter, isNull);
      expect(state.flyingReward, isNull);
      expect(state.queuedRewards, isEmpty);
      expect(testObs.eventNames, contains('discovery.reward_flight_completed'));
    });

    test('same map-cell entry id is acquired exactly once', () async {
      final notifier = container.read(encounterProvider.notifier);

      await notifier.onCellEntered(
        cellId: 'cell_123',
        isFirstVisit: true,
        seed: 'daily_seed_2026_04_06',
        userId: 'user-123',
        mapCellEntryId: 'entry-1',
      );
      await notifier.onCellEntered(
        cellId: 'cell_123',
        isFirstVisit: true,
        seed: 'daily_seed_2026_04_06',
        userId: 'user-123',
        mapCellEntryId: 'entry-1',
      );

      expect(itemRepo.acquiredDrafts, hasLength(1));
      expect(container.read(itemsProvider).items, hasLength(1));
    });

    test('acquisition failure does not show a false found encounter', () async {
      itemRepo.shouldThrowOnAcquire = true;
      final notifier = container.read(encounterProvider.notifier);

      await notifier.onCellEntered(
        cellId: 'cell_123',
        isFirstVisit: true,
        seed: 'daily_seed_2026_04_06',
        userId: 'user-123',
        mapCellEntryId: 'entry-1',
      );

      expect(container.read(encounterProvider).currentEncounter, isNull);
      expect(container.read(itemsProvider).items, isEmpty);
      expect(testObs.eventNames, contains('discovery.acquisition_failed'));
      expect(testObs.eventNames, isNot(contains('map.encounter_triggered')));
    });

    test(
        'seedless first visit uses legacy map-cell entry id and no acquisition',
        () async {
      final notifier = container.read(encounterProvider.notifier);

      await notifier.onCellEntered(
        cellId: 'cell_legacy',
        isFirstVisit: true,
      );

      final state = container.read(encounterProvider);
      final event = testObs.events
          .firstWhere((entry) => entry.event == 'map.encounter_triggered');
      expect(state.currentEncounter, isNotNull);
      expect(state.currentEncounter!.acquiredItem, isNull);
      expect(event.data?['map_cell_entry_id'],
          startsWith('legacy-map-cell-entry-cell_legacy-first-seed_'));
    });

    test('revisit with loot triggers critter encounter', () async {
      final notifier = container.read(encounterProvider.notifier);

      // First visit - species
      await notifier.onCellEntered(
        cellId: 'cell_123',
        isFirstVisit: true,
        seed: 'daily_seed',
      );

      // Check first state
      final firstState = container.read(encounterProvider);
      expect(firstState.currentEncounter?.type, EncounterType.species);

      // Clear current encounter
      notifier.dismissEncounter();

      // Revisit with loot
      await notifier.onCellEntered(
        cellId: 'cell_123',
        isFirstVisit: false,
        hasLoot: true,
        seed: 'daily_seed',
      );

      final state = container.read(encounterProvider);
      expect(state.currentEncounter, isNotNull);
      expect(state.currentEncounter!.type, EncounterType.critter);
    });

    test('revisit without loot does not trigger encounter', () async {
      final notifier = container.read(encounterProvider.notifier);

      // First visit
      await notifier.onCellEntered(
        cellId: 'cell_123',
        isFirstVisit: true,
        seed: 'daily_seed',
      );

      // Clear current encounter
      notifier.dismissEncounter();

      // Revisit without loot
      await notifier.onCellEntered(
        cellId: 'cell_123',
        isFirstVisit: false,
        hasLoot: false,
        seed: 'daily_seed',
      );

      final state = container.read(encounterProvider);
      expect(state.currentEncounter, isNull);
    });

    test('dismiss encounter clears current encounter', () async {
      final notifier = container.read(encounterProvider.notifier);

      await notifier.onCellEntered(
        cellId: 'cell_123',
        isFirstVisit: true,
        seed: 'daily_seed',
      );

      var state = container.read(encounterProvider);
      expect(state.currentEncounter, isNotNull);

      notifier.dismissEncounter();

      state = container.read(encounterProvider);
      expect(state.currentEncounter, isNull);

      // Verify dismiss logging
      expect(testObs.eventNames.contains('map.encounter_dismissed'), isTrue);
    });
  });

  group('EncounterState', () {
    test('copyWith preserves unchanged fields', () {
      const encounter = Encounter(
        type: EncounterType.species,
        speciesId: 'species_123',
        displayName: 'Test Warbler',
        cellId: 'cell_abc',
        seed: 'seed_xyz',
      );

      final state = EncounterState(currentEncounter: encounter);
      final copied = state.copyWith();

      expect(copied.currentEncounter, encounter);
      expect(copied.hasActiveReward, isTrue);
    });

    test('copyWith can clear encounter', () {
      const encounter = Encounter(
        type: EncounterType.species,
        speciesId: 'species_123',
        displayName: 'Test Warbler',
        cellId: 'cell_abc',
        seed: 'seed_xyz',
      );

      final state = EncounterState(currentEncounter: encounter);
      final copied = state.copyWith(currentEncounter: null);

      expect(copied.currentEncounter, isNull);
    });
  });
}
