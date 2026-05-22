import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/identification/domain/entities/discovery_item_draft.dart';
import 'package:earth_nova/features/identification/domain/repositories/item_repository.dart';
import 'package:earth_nova/features/identification/domain/use_cases/identify_unidentified_find.dart';

class FakeItemRepository implements ItemRepository {
  FakeItemRepository({required this.item});

  final Item item;
  String? receivedTraceId;

  @override
  Future<Item> acquireDiscoveryItem(
    DiscoveryItemDraft draft, {
    String? traceId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<Item>> fetchItems(String userId, {String? traceId}) async => [item];

  @override
  Future<Item> identifyUnidentifiedFind(
    Item input, {
    String? traceId,
  }) async {
    receivedTraceId = traceId;
    return item.identify(at: DateTime.utc(2026, 5, 22));
  }
}

class TestObservabilityService extends ObservabilityService {
  TestObservabilityService() : super(sessionId: 'test-session');

  final List<({String event, String category, Map<String, dynamic>? data})> events = [];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    events.add((event: event, category: category, data: data));
    super.log(event, category, data: data);
  }
}

void main() {
  test('logs started/completed and passes trace id to repository', () async {
    final item = Item(
      id: 'item-1',
      definitionId: 'species-1',
      displayName: 'Unidentified fauna specimen',
      category: ItemCategory.fauna,
      acquiredAt: DateTime.utc(2026, 1, 1),
      status: ItemStatus.active,
      identificationState: ItemIdentificationState.unidentified,
      identifiedDisplayName: 'Amberwing Warbler',
      identifiedScientificName: 'Setophaga aestiva',
    );
    final repo = FakeItemRepository(item: item);
    final obs = TestObservabilityService();
    final useCase = IdentifyUnidentifiedFind(repo, obs);

    final result = await useCase(item);

    expect(repo.receivedTraceId, isNotNull);
    expect(result.identificationState, ItemIdentificationState.identified);
    expect(result.displayName, 'Amberwing Warbler');
    expect(obs.events.first.event, 'operation.started');
    expect(obs.events.last.event, 'operation.completed');
  });
}
