import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/models/item.dart';
import 'package:earth_nova/providers/auth_provider.dart';
import 'package:earth_nova/providers/items_provider.dart';
import 'package:earth_nova/services/item_service.dart';
import 'package:earth_nova/services/mock_auth_service.dart';
import 'package:earth_nova/services/observability_service.dart';

// Re-use the test observability service from auth_provider_test.
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

/// Mock item service for testing — no Supabase dependency.
class MockItemService implements ItemService {
  List<Item> items = [];
  bool shouldThrow = false;

  @override
  Future<List<Item>> fetchItems(String userId) async {
    if (shouldThrow) {
      throw Exception('Simulated fetch error');
    }
    return items;
  }
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
    late MockAuthService auth;
    late MockItemService itemService;

    setUp(() async {
      obs = TestObservabilityService();
      auth = MockAuthService();
      itemService = MockItemService();
      container = ProviderContainer(
        overrides: [
          observabilityProvider.overrideWithValue(obs),
          authServiceProvider.overrideWithValue(auth),
          itemServiceProvider.overrideWithValue(itemService),
        ],
      );

      // Sign in so items can be fetched.
      container.read(authProvider);
      await container
          .read(authProvider.notifier)
          .signInWithPhone('+15551234567');
      obs.events.clear(); // Clear auth events.
    });

    tearDown(() {
      container.dispose();
      auth.dispose();
    });

    test('fetchItems logs fetch_started then fetch_success', () async {
      itemService.items = [_testItem()];
      container.read(itemsProvider);

      await container.read(itemsProvider.notifier).fetchItems();

      expect(obs.eventNames, contains('items.fetch_started'));
      expect(obs.eventNames, contains('items.fetch_success'));

      final startIdx = obs.eventNames.indexOf('items.fetch_started');
      final successIdx = obs.eventNames.indexOf('items.fetch_success');
      expect(startIdx, lessThan(successIdx));
    });

    test('fetchItems logs count in fetch_success data', () async {
      itemService.items = [_testItem(id: '1'), _testItem(id: '2')];
      container.read(itemsProvider);

      await container.read(itemsProvider.notifier).fetchItems();

      final successEvent =
          obs.events.firstWhere((e) => e.event == 'items.fetch_success');
      expect(successEvent.data, isNotNull);
      expect(successEvent.data!['count'], 2);
    });

    test('fetchItems uses category data', () async {
      itemService.items = [_testItem()];
      container.read(itemsProvider);

      await container.read(itemsProvider.notifier).fetchItems();

      for (final event in obs.events) {
        expect(event.category, 'data');
      }
    });

    test('fetchItems logs fetch_error on failure', () async {
      itemService.shouldThrow = true;
      container.read(itemsProvider);

      await container.read(itemsProvider.notifier).fetchItems();

      expect(obs.errors.map((e) => e.event), contains('items.fetch_error'));
    });

    test('fetchItems sets error state on failure', () async {
      itemService.shouldThrow = true;
      container.read(itemsProvider);

      await container.read(itemsProvider.notifier).fetchItems();

      final state = container.read(itemsProvider);
      expect(state.error, isNotNull);
      expect(state.isLoading, isFalse);
    });

    test('fetchItems does nothing when not authenticated', () async {
      // Create a fresh container without signing in.
      final freshContainer = ProviderContainer(
        overrides: [
          observabilityProvider.overrideWithValue(obs),
          authServiceProvider.overrideWithValue(MockAuthService()),
          itemServiceProvider.overrideWithValue(itemService),
        ],
      );
      obs.events.clear();

      freshContainer.read(itemsProvider);
      // Force unauthenticated state.
      freshContainer.read(authProvider);
      await freshContainer.read(authProvider.notifier).restoreSession();
      obs.events.clear();

      await freshContainer.read(itemsProvider.notifier).fetchItems();

      // Should be a no-op — no items events logged.
      expect(obs.eventNames.where((e) => e.startsWith('items.')), isEmpty);

      freshContainer.dispose();
    });

    test('fetchItems with empty result logs count 0', () async {
      itemService.items = [];
      container.read(itemsProvider);

      await container.read(itemsProvider.notifier).fetchItems();

      final successEvent =
          obs.events.firstWhere((e) => e.event == 'items.fetch_success');
      expect(successEvent.data!['count'], 0);
    });
  });
}
