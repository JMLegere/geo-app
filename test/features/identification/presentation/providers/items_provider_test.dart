import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/identification/data/repositories/mock_item_repository.dart';
import 'package:earth_nova/features/identification/presentation/providers/items_provider.dart';

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

Item _testItem({
  String id = 'item-1',
  String name = 'Test Ocelot',
}) =>
    Item(
      id: id,
      definitionId: 'species-1',
      displayName: name,
      category: ItemCategory.fauna,
      acquiredAt: DateTime(2026, 1, 1),
      status: ItemStatus.active,
    );

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
          authRepositoryProvider.overrideWithValue(auth),
          itemRepositoryProvider.overrideWithValue(itemRepo),
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
          authRepositoryProvider.overrideWithValue(auth),
          itemRepositoryProvider.overrideWithValue(itemRepo),
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
          authRepositoryProvider.overrideWithValue(auth),
          itemRepositoryProvider.overrideWithValue(repo),
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
          authRepositoryProvider.overrideWithValue(auth),
          itemRepositoryProvider.overrideWithValue(repo),
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
          authRepositoryProvider.overrideWithValue(auth),
          itemRepositoryProvider.overrideWithValue(repo),
        ],
      );
      c.read(authProvider);
      await c.read(authProvider.notifier).signInWithPhone('+15551234567');
      obs.events.clear();

      c.read(itemsProvider);
      await c.read(itemsProvider.notifier).fetchItems();

      expect(obs.errors.map((e) => e.event), contains('items.fetch_error'));
      c.dispose();
    });

    test('fetchItems sets error state on failure', () async {
      final repo = MockItemRepository(shouldThrow: true);
      final c = ProviderContainer(
        overrides: [
          observabilityProvider.overrideWithValue(obs),
          itemsObservabilityProvider.overrideWithValue(obs),
          authRepositoryProvider.overrideWithValue(auth),
          itemRepositoryProvider.overrideWithValue(repo),
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
          authRepositoryProvider.overrideWithValue(freshAuth),
          itemRepositoryProvider.overrideWithValue(MockItemRepository()),
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
          authRepositoryProvider.overrideWithValue(auth),
        ],
      );
      expect(() => c.read(itemRepositoryProvider), throwsA(anything));
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

    test('fetchItems with empty result logs count 0', () async {
      final repo = MockItemRepository();
      final c = ProviderContainer(
        overrides: [
          observabilityProvider.overrideWithValue(obs),
          itemsObservabilityProvider.overrideWithValue(obs),
          authRepositoryProvider.overrideWithValue(auth),
          itemRepositoryProvider.overrideWithValue(repo),
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
  });
}
