import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/pack/domain/repositories/pack_repository.dart';
import 'package:earth_nova/features/pack/domain/use_cases/fetch_pack_items.dart';

class FakePackRepository implements PackRepository {
  FakePackRepository({this.items = const [], this.shouldThrow = false});

  final List<Item> items;
  final bool shouldThrow;
  String? receivedTraceId;
  String? receivedUserId;

  @override
  Future<List<Item>> fetchActiveItems(
    String userId, {
    String? traceId,
  }) async {
    receivedUserId = userId;
    receivedTraceId = traceId;
    if (shouldThrow) throw Exception('Fake fetch error');
    return items;
  }
}

class TestObservabilityService extends ObservabilityService {
  TestObservabilityService() : super(sessionId: 'test-session');

  final List<({String event, String category, Map<String, dynamic>? data})>
      events = [];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    events.add((event: event, category: category, data: data));
    super.log(event, category, data: data);
  }
}

Item _testItem() => Item(
      id: 'item-1',
      definitionId: 'def-1',
      displayName: 'Test Ocelot',
      category: ItemCategory.fauna,
      acquiredAt: DateTime(2026, 1, 1),
      status: ItemStatus.active,
    );

void main() {
  group('FetchPackItems', () {
    test('logs started/completed and passes trace id to repository', () async {
      final repo = FakePackRepository(items: [_testItem()]);
      final obs = TestObservabilityService();
      final useCase = FetchPackItems(repo, obs);
      final result = await useCase('user-1');

      expect(result, hasLength(1));
      expect(result.first.id, 'item-1');

      final started =
          obs.events.firstWhere((e) => e.event == 'operation.started');
      final completed =
          obs.events.firstWhere((e) => e.event == 'operation.completed');

      expect(started.category, 'use_case');
      expect(started.data?['operation'], 'fetch_pack_items');
      expect(started.data?['trace_id'], isA<String>());
      expect(completed.data?['trace_id'], started.data?['trace_id']);
      expect(completed.data?['duration_ms'], isA<int>());
      expect(completed.data?['output'], {'count': 1});
      expect(repo.receivedTraceId, started.data?['trace_id']);
      expect(repo.receivedUserId, 'user-1');
    });

    test('logs failure and rethrows repository exceptions', () async {
      final repo = FakePackRepository(shouldThrow: true);
      final obs = TestObservabilityService();
      final useCase = FetchPackItems(repo, obs);

      await expectLater(() => useCase('user-1'), throwsException);

      final failed =
          obs.events.firstWhere((e) => e.event == 'operation.failed');
      expect(failed.category, 'use_case');
      expect(failed.data?['operation'], 'fetch_pack_items');
      expect(failed.data?['trace_id'], isA<String>());
      expect(failed.data?['duration_ms'], isA<int>());
      expect(failed.data?['error_type'], contains('Exception'));
    });
  });
}
