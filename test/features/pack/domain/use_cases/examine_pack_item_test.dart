import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/identification/domain/entities/discovery_item_draft.dart';
import 'package:earth_nova/features/identification/domain/repositories/item_repository.dart';
import 'package:earth_nova/features/pack/domain/use_cases/examine_pack_item.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeItemRepository implements ItemRepository {
  FakeItemRepository({this.response, this.shouldThrow = false});

  final Item? response;
  bool shouldThrow;
  Item? receivedItem;
  String? receivedTraceId;
  int examineCalls = 0;

  @override
  Future<Item> examineItem(Item item, {String? traceId}) async {
    examineCalls++;
    receivedItem = item;
    receivedTraceId = traceId;
    if (shouldThrow) throw StateError('examination failed');
    return response!;
  }

  @override
  Future<Item> acquireDiscoveryItem(
    DiscoveryItemDraft draft, {
    String? traceId,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<Item>> fetchItems(String userId, {String? traceId}) =>
      throw UnimplementedError();

  @override
  Future<Item> identifyUnidentifiedFind(Item item, {String? traceId}) =>
      throw UnimplementedError();
}

class TestObservabilityService extends ObservabilityService {
  TestObservabilityService() : super(sessionId: 'test-session');

  final List<({String event, String category, Map<String, dynamic>? data})>
      events = [];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    events.add((event: event, category: category, data: data));
  }
}

Item _unexaminedItem() => Item(
      id: 'item-1',
      displayName: 'Unidentified fauna specimen',
      category: ItemCategory.fauna,
      acquiredAt: DateTime.utc(2026, 4, 12),
      status: ItemStatus.active,
      identificationState: ItemIdentificationState.unidentified,
      examinationState: ItemExaminationState.unexamined,
    );

void main() {
  group('ExaminePackItem', () {
    test('examines one Item in one command and preserves trace lineage',
        () async {
      final unexamined = _unexaminedItem();
      final examined = unexamined.copyWith(
        definitionId: 'fauna:northern_cardinal',
        baseItemId: 'fauna:northern_cardinal',
        baseItemVersionId: '123e4567-e89b-12d3-a456-426614174000',
        displayName: 'Northern cardinal',
        examinationState: ItemExaminationState.examined,
        examinedAt: DateTime.utc(2026, 4, 13),
      );
      final repository = FakeItemRepository(response: examined);
      final observability = TestObservabilityService();
      final useCase = ExaminePackItem(repository, observability);

      final result = await useCase(unexamined);

      expect(result, same(examined));
      expect(repository.examineCalls, 1);
      expect(repository.receivedItem, same(unexamined));
      final started = observability.events.singleWhere(
        (event) => event.event == 'operation.started',
      );
      final completed = observability.events.singleWhere(
        (event) => event.event == 'operation.completed',
      );
      expect(started.data?['operation'], 'examine_pack_item');
      expect(started.data?['input'], {'item_id': unexamined.id});
      expect(started.data?['trace_id'], isA<String>());
      expect(repository.receivedTraceId, started.data?['trace_id']);
      expect(completed.data?['trace_id'], started.data?['trace_id']);
      expect(completed.data?['output'], {'item_id': examined.id});
    });

    test('rethrows a failed examination so its caller can preserve state',
        () async {
      final repository = FakeItemRepository(shouldThrow: true);
      final observability = TestObservabilityService();
      final useCase = ExaminePackItem(repository, observability);

      await expectLater(() => useCase(_unexaminedItem()), throwsStateError);

      expect(repository.examineCalls, 1);
      final failed = observability.events.singleWhere(
        (event) => event.event == 'operation.failed',
      );
      expect(failed.data?['operation'], 'examine_pack_item');
      expect(failed.data?['trace_id'], isA<String>());
      expect(failed.data?['error_type'], 'StateError');
    });
  });
}
