import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/observability/observable_use_case_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/identification/data/repositories/mock_item_repository.dart';
import 'package:earth_nova/features/identification/domain/entities/identification_entities.dart';
import 'package:earth_nova/features/identification/domain/repositories/identification_repository.dart';
import 'package:earth_nova/features/item_knowledge/domain/entities/item_knowledge_entities.dart';
import 'package:earth_nova/features/living_world/domain/entities/authored_living_world_entities.dart';
import 'package:earth_nova/features/identification/presentation/providers/items_provider.dart';
import 'package:earth_nova/features/pack/data/repositories/legacy_item_repository_pack_adapter.dart';
import 'package:earth_nova/features/pack/domain/repositories/pack_repository.dart';

class TestObservabilityService extends ObservabilityService {
  TestObservabilityService() : super(sessionId: 'test-session');

  final List<({String event, String category, Map<String, dynamic>? data})>
      events = [];
  final List<({Object error, String event})> errors = [];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    events.add((event: event, category: category, data: data));
    super.log(event, category, data: data);
  }

  @override
  void logError(Object error, StackTrace stack,
      {String event = 'app.crash.unhandled'}) {
    errors.add((error: error, event: event));
    super.logError(error, stack, event: event);
  }

  List<String> get eventNames => events.map((e) => e.event).toList();
}

final _serviceAccess = IdentificationServiceAccess(
  villagerId: VillagerId('villager:rowan'),
  villagerDisplayName: 'Rowan',
  serviceId: ServiceId('service:identify_item_properties'),
  serviceVersion: ExactVersionRef<ServiceContent>(
    stableId:
        StableContentId<ServiceContent>('service:identify_item_properties'),
    versionId: ContentVersionId<ServiceContent>('service-version-2'),
    revision: 2,
  ),
  serviceDisplayName: 'Identification',
);

Item _testItem({
  String id = 'item-1',
  String name = 'Test Ocelot',
  ItemIdentificationState identificationState =
      ItemIdentificationState.identified,
  String? identifiedDisplayName,
}) =>
    Item(
      id: id,
      definitionId: 'species-1',
      displayName: name,
      category: ItemCategory.fauna,
      acquiredAt: DateTime(2026, 1, 1),
      status: ItemStatus.active,
      identificationState: identificationState,
      identifiedDisplayName: identifiedDisplayName,
    );

final class RecordingIdentificationRepository
    implements IdentificationRepository {
  RecordingIdentificationRepository({
    required this.preparation,
    required this.committedItem,
    this.shouldFailCommit = false,
  });

  final IdentificationPreparation preparation;
  final Item committedItem;
  bool shouldFailCommit;
  int prepareCalls = 0;
  int commitCalls = 0;
  ItemIdentificationPlan? committedPlan;
  String? preparedTraceId;
  String? committedTraceId;

  @override
  Future<IdentificationPreparation> prepare(
    ItemKnowledgeItemId itemId, {
    String? traceId,
  }) async {
    prepareCalls++;
    preparedTraceId = traceId;
    if (itemId != preparation.item.id) {
      throw StateError('Unexpected item id.');
    }
    return preparation;
  }

  @override
  Future<ItemIdentificationResult> commit(
    ItemIdentificationPlan plan, {
    String? traceId,
  }) async {
    commitCalls++;
    committedTraceId = traceId;
    committedPlan = plan;
    if (shouldFailCommit) throw StateError('Commit failed.');
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
}

RecordingIdentificationRepository _authoritativeRepositoryFor(
  Item item, {
  bool shouldFailCommit = false,
}) {
  final baseItemId = StableContentId<BaseItemContent>('base-item-1');
  final itemRef = ItemKnowledgeItemRef(
    id: ItemKnowledgeItemId(item.id),
    playerId: 'player-1',
    baseItemId: baseItemId,
    baseItemVersion: ExactVersionRef(
      stableId: baseItemId,
      versionId: ContentVersionId<BaseItemContent>('version-1'),
      revision: 1,
    ),
  );
  return RecordingIdentificationRepository(
    preparation: IdentificationPreparation(
      item: itemRef,
      playerDiscovered: false,
      properties: const [],
      serviceAccess: _serviceAccess,
    ),
    committedItem: item.identify(),
    shouldFailCommit: shouldFailCommit,
  );
}

final class RecordingExaminationItemRepository extends MockItemRepository {
  RecordingExaminationItemRepository({
    required this.examinedItem,
    this.shouldFail = false,
  });

  final Item examinedItem;
  bool shouldFail;
  int examineCalls = 0;
  Item? receivedItem;

  @override
  Future<Item> examineItem(Item item, {String? traceId}) async {
    examineCalls++;
    receivedItem = item;
    if (shouldFail) throw StateError('Examination failed.');
    return examinedItem;
  }
}

final class ReloadingPackRepository implements PackRepository {
  ReloadingPackRepository(this.fetch);

  final Future<List<Item>> Function() fetch;
  int fetchCalls = 0;

  @override
  Future<List<Item>> fetchActiveItems(
    String userId, {
    String? traceId,
  }) {
    fetchCalls++;
    return fetch();
  }
}

void main() {
  group('ItemsNotifier observability', () {
    late ProviderContainer container;
    late TestObservabilityService obs;
    late MockAuthRepository auth;
    late MockItemRepository itemRepo;

    setUp(() async {
      obs = TestObservabilityService();
      auth = MockAuthRepository();
      itemRepo = MockItemRepository();
      container = ProviderContainer(
        overrides: [
          observabilityProvider.overrideWithValue(obs),
          itemsObservabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          authRepositoryProvider.overrideWithValue(auth),
          itemRepositoryProvider.overrideWithValue(itemRepo),
          packRepositoryProvider.overrideWithValue(
            LegacyItemRepositoryPackAdapter(itemRepo),
          ),
        ],
      );

      container.read(authProvider);
      await container
          .read(authProvider.notifier)
          .signInWithPhone('+15551234567');
      obs.events.clear();
    });

    tearDown(() {
      container.dispose();
      auth.dispose();
    });

    test('fetchItems logs fetch_started then fetch_success', () async {
      itemRepo = MockItemRepository(items: [_testItem()]);
      container = ProviderContainer(
        overrides: [
          observabilityProvider.overrideWithValue(obs),
          itemsObservabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          authRepositoryProvider.overrideWithValue(auth),
          itemRepositoryProvider.overrideWithValue(itemRepo),
          packRepositoryProvider.overrideWithValue(
            LegacyItemRepositoryPackAdapter(itemRepo),
          ),
        ],
      );
      container.read(authProvider);
      await container
          .read(authProvider.notifier)
          .signInWithPhone('+15551234567');
      obs.events.clear();

      container.read(itemsProvider);
      await container.read(itemsProvider.notifier).fetchItems();

      expect(obs.eventNames, contains('items.fetch_started'));
      expect(obs.eventNames, contains('items.fetch_success'));

      final startIdx = obs.eventNames.indexOf('items.fetch_started');
      final successIdx = obs.eventNames.indexOf('items.fetch_success');
      expect(startIdx, lessThan(successIdx));
    });

    test('fetchItems logs count in fetch_success data', () async {
      final repo =
          MockItemRepository(items: [_testItem(id: '1'), _testItem(id: '2')]);
      final c = ProviderContainer(
        overrides: [
          observabilityProvider.overrideWithValue(obs),
          itemsObservabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          authRepositoryProvider.overrideWithValue(auth),
          itemRepositoryProvider.overrideWithValue(repo),
          packRepositoryProvider.overrideWithValue(
            LegacyItemRepositoryPackAdapter(repo),
          ),
        ],
      );
      c.read(authProvider);
      await c.read(authProvider.notifier).signInWithPhone('+15551234567');
      obs.events.clear();

      c.read(itemsProvider);
      await c.read(itemsProvider.notifier).fetchItems();

      final successEvent =
          obs.events.firstWhere((e) => e.event == 'items.fetch_success');
      expect(successEvent.data, isNotNull);
      expect(successEvent.data!['count'], 2);
      c.dispose();
    });

    test('fetchItems uses category data', () async {
      final repo = MockItemRepository(items: [_testItem()]);
      final c = ProviderContainer(
        overrides: [
          observabilityProvider.overrideWithValue(obs),
          itemsObservabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          authRepositoryProvider.overrideWithValue(auth),
          itemRepositoryProvider.overrideWithValue(repo),
          packRepositoryProvider.overrideWithValue(
            LegacyItemRepositoryPackAdapter(repo),
          ),
        ],
      );
      c.read(authProvider);
      await c.read(authProvider.notifier).signInWithPhone('+15551234567');
      obs.events.clear();

      c.read(itemsProvider);
      await c.read(itemsProvider.notifier).fetchItems();

      final providerEvents =
          obs.events.where((event) => event.event.startsWith('items.'));

      for (final event in providerEvents) {
        expect(event.category, 'data');
      }
      c.dispose();
    });

    test('fetchItems logs fetch_error on failure', () async {
      final repo = MockItemRepository(shouldThrow: true);
      final c = ProviderContainer(
        overrides: [
          observabilityProvider.overrideWithValue(obs),
          itemsObservabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          authRepositoryProvider.overrideWithValue(auth),
          itemRepositoryProvider.overrideWithValue(repo),
          packRepositoryProvider.overrideWithValue(
            LegacyItemRepositoryPackAdapter(repo),
          ),
        ],
      );
      c.read(authProvider);
      await c.read(authProvider.notifier).signInWithPhone('+15551234567');
      obs.events.clear();

      c.read(itemsProvider);
      await c.read(itemsProvider.notifier).fetchItems();

      expect(obs.eventNames, contains('items.fetch_error'));
      c.dispose();
    });

    test('fetchItems sets error state on failure', () async {
      final repo = MockItemRepository(shouldThrow: true);
      final c = ProviderContainer(
        overrides: [
          observabilityProvider.overrideWithValue(obs),
          itemsObservabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          authRepositoryProvider.overrideWithValue(auth),
          itemRepositoryProvider.overrideWithValue(repo),
          packRepositoryProvider.overrideWithValue(
            LegacyItemRepositoryPackAdapter(repo),
          ),
        ],
      );
      c.read(authProvider);
      await c.read(authProvider.notifier).signInWithPhone('+15551234567');
      obs.events.clear();

      c.read(itemsProvider);
      await c.read(itemsProvider.notifier).fetchItems();

      final state = c.read(itemsProvider);
      expect(state.error, isNotNull);
      expect(state.isLoading, isFalse);
      c.dispose();
    });

    test('fetchItems does nothing when not authenticated', () async {
      final freshAuth = MockAuthRepository();
      final freshContainer = ProviderContainer(
        overrides: [
          observabilityProvider.overrideWithValue(obs),
          itemsObservabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          authRepositoryProvider.overrideWithValue(freshAuth),
          itemRepositoryProvider.overrideWithValue(MockItemRepository()),
          packRepositoryProvider.overrideWithValue(
            LegacyItemRepositoryPackAdapter(MockItemRepository()),
          ),
        ],
      );
      obs.events.clear();

      freshContainer.read(itemsProvider);
      freshContainer.read(authProvider);
      await freshContainer.read(authProvider.notifier).restoreSession();
      obs.events.clear();

      await freshContainer.read(itemsProvider.notifier).fetchItems();

      expect(obs.eventNames.where((e) => e.startsWith('items.')), isEmpty);

      freshContainer.dispose();
      freshAuth.dispose();
    });

    test('itemRepositoryProvider throws when not overridden', () {
      final c = ProviderContainer(
        overrides: [
          observabilityProvider.overrideWithValue(obs),
          itemsObservabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          authRepositoryProvider.overrideWithValue(auth),
        ],
      );
      expect(() => c.read(itemRepositoryProvider), throwsA(anything));
      c.dispose();
    });

    test('itemsObservabilityProvider throws when not overridden', () {
      final c = ProviderContainer(
        overrides: [
          observabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          authRepositoryProvider.overrideWithValue(auth),
          itemRepositoryProvider.overrideWithValue(MockItemRepository()),
          packRepositoryProvider.overrideWithValue(
            LegacyItemRepositoryPackAdapter(MockItemRepository()),
          ),
        ],
      );
      expect(() => c.read(itemsObservabilityProvider), throwsA(anything));
      c.dispose();
    });

    test('ItemsState copyWith preserves unset fields', () {
      final state = ItemsState(
        items: [_testItem()],
        isLoading: true,
        error: 'err',
      );
      final copied = state.copyWith(isLoading: false);
      expect(copied.items, hasLength(1));
      expect(copied.isLoading, isFalse);
      expect(copied.error, isNull); // error resets via named param default
    });

    test('ItemsState equality and hashCode', () {
      const a = ItemsState();
      const b = ItemsState();
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);

      final c = ItemsState(items: [_testItem()]);
      expect(a, isNot(equals(c)));
    });

    test('ItemsState equality reaches error field comparison', () {
      final sharedItems = [_testItem()];
      final a = ItemsState(items: sharedItems, error: 'a');
      final b = ItemsState(items: sharedItems, error: 'b');
      expect(a, isNot(equals(b)));
    });

    test('fetchItems with empty result logs count 0', () async {
      final repo = MockItemRepository();
      final c = ProviderContainer(
        overrides: [
          observabilityProvider.overrideWithValue(obs),
          itemsObservabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          authRepositoryProvider.overrideWithValue(auth),
          itemRepositoryProvider.overrideWithValue(repo),
          packRepositoryProvider.overrideWithValue(
            LegacyItemRepositoryPackAdapter(repo),
          ),
        ],
      );
      c.read(authProvider);
      await c.read(authProvider.notifier).signInWithPhone('+15551234567');
      obs.events.clear();

      c.read(itemsProvider);
      await c.read(itemsProvider.notifier).fetchItems();

      final successEvent =
          obs.events.firstWhere((e) => e.event == 'items.fetch_success');
      expect(successEvent.data!['count'], 0);
      c.dispose();
    });

    test('registerOwnedDiscovery adds a committed discovery to Pack state', () {
      container.read(itemsProvider);
      final item = _testItem(id: 'discovery-1', name: 'Amberwing Warbler');

      container.read(itemsProvider.notifier).registerOwnedDiscovery(item);

      final state = container.read(itemsProvider);
      expect(state.items, [item]);
      expect(obs.eventNames, contains('items.owned_discovery_registered'));
    });

    test('registerOwnedDiscovery dedupes the same owned item id', () {
      container.read(itemsProvider);
      final item = _testItem(id: 'discovery-1', name: 'Amberwing Warbler');

      container.read(itemsProvider.notifier).registerOwnedDiscovery(item);
      container.read(itemsProvider.notifier).registerOwnedDiscovery(item);

      expect(container.read(itemsProvider).items, hasLength(1));
    });

    test('identifyUnidentifiedFind updates Pack item to identified state',
        () async {
      final unidentified = _testItem(
        id: 'discovery-1',
        name: 'Unidentified fauna specimen',
        identificationState: ItemIdentificationState.unidentified,
        identifiedDisplayName: 'Amberwing Warbler',
      );
      itemRepo = MockItemRepository(items: [unidentified]);
      container = ProviderContainer(
        overrides: [
          observabilityProvider.overrideWithValue(obs),
          itemsObservabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          authRepositoryProvider.overrideWithValue(auth),
          itemRepositoryProvider.overrideWithValue(itemRepo),
          packRepositoryProvider.overrideWithValue(
            LegacyItemRepositoryPackAdapter(itemRepo),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(authProvider);
      await container
          .read(authProvider.notifier)
          .signInWithPhone('+15551234567');
      container.read(itemsProvider);
      container
          .read(itemsProvider.notifier)
          .registerOwnedDiscovery(unidentified);
      final identified = await container
          .read(itemsProvider.notifier)
          .identifyUnidentifiedFind(unidentified.id);

      expect(identified, isNotNull);
      expect(
          identified!.identificationState, ItemIdentificationState.identified);
      expect(identified.displayName, 'Amberwing Warbler');
      expect(container.read(itemsProvider).items.single.displayName,
          'Amberwing Warbler');
    });
    test(
        'authoritative identification prepares, plans once, and commits the Pack row',
        () async {
      final unidentified = Item(
        id: 'authoritative-item',
        definitionId: 'species-1',
        baseItemId: 'base-item-1',
        baseItemVersionId: 'version-1',
        displayName: 'Unidentified fauna specimen',
        category: ItemCategory.fauna,
        acquiredAt: DateTime(2026, 1, 1),
        status: ItemStatus.active,
        identificationState: ItemIdentificationState.unidentified,
        identifiedDisplayName: 'Amberwing Warbler',
      );
      final authoritative = _authoritativeRepositoryFor(unidentified);
      final legacy = MockItemRepository(shouldThrow: true);
      final c = ProviderContainer(
        overrides: [
          observabilityProvider.overrideWithValue(obs),
          itemsObservabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          authRepositoryProvider.overrideWithValue(auth),
          itemRepositoryProvider.overrideWithValue(legacy),
          packRepositoryProvider.overrideWithValue(
            LegacyItemRepositoryPackAdapter(legacy),
          ),
          identificationRepositoryProvider.overrideWithValue(authoritative),
        ],
      );
      addTearDown(c.dispose);

      c.read(itemsProvider.notifier).registerOwnedDiscovery(unidentified);
      final identified = await c
          .read(itemsProvider.notifier)
          .identifyUnidentifiedFind(unidentified.id);

      expect(identified, same(authoritative.committedItem));
      expect(c.read(itemsProvider).items.single,
          same(authoritative.committedItem));
      expect(authoritative.prepareCalls, 1);
      expect(authoritative.commitCalls, 1);
      expect(authoritative.committedPlan, isNotNull);
      expect(authoritative.preparedTraceId, isNotNull);
      expect(authoritative.committedTraceId, authoritative.preparedTraceId);
      final completed = obs.events.lastWhere(
        (event) => event.event == 'items.identification_completed',
      );
      expect(completed.data!['mode'], 'authoritative');
      expect(completed.data!['terminal'], 'committed');
      expect(completed.data!['trace_id'], authoritative.preparedTraceId);
    });

    test('authoritative commit failure retains the original Pack row',
        () async {
      final unidentified = Item(
        id: 'failed-authoritative-item',
        definitionId: 'species-1',
        baseItemId: 'base-item-1',
        baseItemVersionId: 'version-1',
        displayName: 'Unidentified fauna specimen',
        category: ItemCategory.fauna,
        acquiredAt: DateTime(2026, 1, 1),
        status: ItemStatus.active,
        identificationState: ItemIdentificationState.unidentified,
        identifiedDisplayName: 'Amberwing Warbler',
      );
      final authoritative = _authoritativeRepositoryFor(
        unidentified,
        shouldFailCommit: true,
      );
      final legacy = MockItemRepository(shouldThrow: true);
      final c = ProviderContainer(
        overrides: [
          observabilityProvider.overrideWithValue(obs),
          itemsObservabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          authRepositoryProvider.overrideWithValue(auth),
          itemRepositoryProvider.overrideWithValue(legacy),
          packRepositoryProvider.overrideWithValue(
            LegacyItemRepositoryPackAdapter(legacy),
          ),
          identificationRepositoryProvider.overrideWithValue(authoritative),
        ],
      );
      addTearDown(c.dispose);

      c.read(itemsProvider.notifier).registerOwnedDiscovery(unidentified);
      final identified = await c
          .read(itemsProvider.notifier)
          .identifyUnidentifiedFind(unidentified.id);

      expect(identified, isNull);
      expect(c.read(itemsProvider).items.single, same(unidentified));
      expect(authoritative.prepareCalls, 1);
      expect(authoritative.commitCalls, 1);
    });
    test(
        'authoritative failure preserves state and a retry recovers the same row',
        () async {
      final unidentified = Item(
        id: 'retry-authoritative-item',
        definitionId: 'species-1',
        baseItemId: 'base-item-1',
        baseItemVersionId: 'version-1',
        displayName: 'Unidentified fauna specimen',
        category: ItemCategory.fauna,
        acquiredAt: DateTime(2026, 1, 1),
        status: ItemStatus.active,
        identificationState: ItemIdentificationState.unidentified,
        identifiedDisplayName: 'Amberwing Warbler',
      );
      final authoritative = _authoritativeRepositoryFor(
        unidentified,
        shouldFailCommit: true,
      );
      final legacy = MockItemRepository(shouldThrow: true);
      final c = ProviderContainer(
        overrides: [
          observabilityProvider.overrideWithValue(obs),
          itemsObservabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          authRepositoryProvider.overrideWithValue(auth),
          itemRepositoryProvider.overrideWithValue(legacy),
          packRepositoryProvider.overrideWithValue(
            LegacyItemRepositoryPackAdapter(legacy),
          ),
          identificationRepositoryProvider.overrideWithValue(authoritative),
        ],
      );
      addTearDown(c.dispose);
      c.read(itemsProvider.notifier).registerOwnedDiscovery(unidentified);

      expect(
        await c
            .read(itemsProvider.notifier)
            .identifyUnidentifiedFind(unidentified.id),
        isNull,
      );
      expect(c.read(itemsProvider).items.single, same(unidentified));
      expect(c.read(itemsProvider).error,
          "Couldn't identify that find. Try again.");

      authoritative.shouldFailCommit = false;
      final recovered = await c
          .read(itemsProvider.notifier)
          .identifyUnidentifiedFind(unidentified.id);

      expect(recovered, same(authoritative.committedItem));
      expect(c.read(itemsProvider).items.single,
          same(authoritative.committedItem));
      expect(c.read(itemsProvider).error, isNull);
      expect(authoritative.prepareCalls, 2);
      expect(authoritative.commitCalls, 2);
      final completed = obs.events
          .where((event) => event.event == 'items.identification_completed')
          .toList();
      expect(completed.last.data!['terminal'], 'committed');
      expect(completed.last.data!['mode'], 'authoritative');
    });
    test(
        'examines only the tapped Item before reloading the authoritative Pack projection',
        () async {
      final target = Item(
        id: 'target',
        displayName: 'Unidentified fauna specimen',
        category: ItemCategory.fauna,
        acquiredAt: DateTime.utc(2026, 4, 12),
        status: ItemStatus.active,
        identificationState: ItemIdentificationState.unidentified,
        examinationState: ItemExaminationState.unexamined,
      );
      final sameDefinition = target.copyWith(id: 'same-definition');
      final examined = target.copyWith(
        definitionId: 'fauna:northern_cardinal',
        baseItemId: 'fauna:northern_cardinal',
        baseItemVersionId: '123e4567-e89b-12d3-a456-426614174000',
        displayName: 'Northern cardinal',
        examinationState: ItemExaminationState.examined,
        examinedAt: DateTime.utc(2026, 4, 13),
      );
      final reload = Completer<List<Item>>();
      final itemRepository =
          RecordingExaminationItemRepository(examinedItem: examined);
      final packRepository = ReloadingPackRepository(() => reload.future);
      final c = ProviderContainer(
        overrides: [
          observabilityProvider.overrideWithValue(obs),
          itemsObservabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          authRepositoryProvider.overrideWithValue(auth),
          itemRepositoryProvider.overrideWithValue(itemRepository),
          packRepositoryProvider.overrideWithValue(packRepository),
        ],
      );
      addTearDown(c.dispose);
      c.read(authProvider);
      await c.read(authProvider.notifier).signInWithPhone('+15551234567');
      c.read(itemsProvider.notifier).registerOwnedDiscovery(target);
      c.read(itemsProvider.notifier).registerOwnedDiscovery(sameDefinition);

      final examination =
          c.read(itemsProvider.notifier).examinePackItem(target.id);
      await Future<void>.delayed(Duration.zero);
      expect(itemRepository.receivedItem, same(target));
      expect(c.read(itemsProvider).items.first, same(sameDefinition));
      expect(c.read(itemsProvider).items.last, same(examined));
      expect(packRepository.fetchCalls, 1);

      final current = examined.copyWith(
        displayName: 'Current northern cardinal',
      );
      final future = _testItem(id: 'future', name: 'Future Item');
      reload.complete([future, current, sameDefinition]);
      await examination;

      expect(
        c.read(itemsProvider).items.map((item) => item.id),
        ['future', 'target', 'same-definition'],
      );
      expect(c.read(itemsProvider).items[1], same(current));
    });

    test(
        'preserves state on examination failure and retries one idempotent command',
        () async {
      final target = Item(
        id: 'retry-target',
        displayName: 'Unidentified flora specimen',
        category: ItemCategory.flora,
        acquiredAt: DateTime.utc(2026, 4, 12),
        status: ItemStatus.active,
        identificationState: ItemIdentificationState.unidentified,
        examinationState: ItemExaminationState.unexamined,
      );
      final examined = target.copyWith(
        definitionId: 'flora:oak',
        baseItemId: 'flora:oak',
        baseItemVersionId: '123e4567-e89b-12d3-a456-426614174001',
        displayName: 'Oak',
        examinationState: ItemExaminationState.examined,
      );
      final itemRepository = RecordingExaminationItemRepository(
        examinedItem: examined,
        shouldFail: true,
      );
      final packRepository = ReloadingPackRepository(() async => [examined]);
      final c = ProviderContainer(
        overrides: [
          observabilityProvider.overrideWithValue(obs),
          itemsObservabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          authRepositoryProvider.overrideWithValue(auth),
          itemRepositoryProvider.overrideWithValue(itemRepository),
          packRepositoryProvider.overrideWithValue(packRepository),
        ],
      );
      addTearDown(c.dispose);
      c.read(authProvider);
      await c.read(authProvider.notifier).signInWithPhone('+15551234567');
      c.read(itemsProvider.notifier).registerOwnedDiscovery(target);

      await c.read(itemsProvider.notifier).examinePackItem(target.id);

      expect(itemRepository.examineCalls, 1);
      expect(c.read(itemsProvider).items.single, same(target));
      expect(packRepository.fetchCalls, 0);
      expect(c.read(itemsProvider).error, isNotNull);

      itemRepository.shouldFail = false;
      await c.read(itemsProvider.notifier).examinePackItem(target.id);

      expect(itemRepository.examineCalls, 2);
      expect(packRepository.fetchCalls, 1);
      expect(c.read(itemsProvider).items.single, same(examined));
      expect(c.read(itemsProvider).error, isNull);
    });
  });
}
