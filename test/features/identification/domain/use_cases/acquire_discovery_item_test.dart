import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/identification/domain/entities/discovery_item_draft.dart';
import 'package:earth_nova/features/identification/domain/repositories/item_repository.dart';
import 'package:earth_nova/features/identification/domain/use_cases/acquire_discovery_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final useCase = AcquireDiscoveryItem(
    _UnusedItemRepository(),
    ObservabilityService(sessionId: 'test-session'),
  );

  test('acquisition telemetry summaries do not expose hidden Item identity',
      () {
    final input = DiscoveryItemDraft(
      userId: 'user-1',
      definitionId: 'species.amberwing_warbler.abc12345',
      displayName: 'Amberwing Warbler',
      category: ItemCategory.fauna,
      acquiredInCellId: 'cell-1',
      mapCellEntryId: 'entry-1',
      scientificName: 'Setophaga aestiva',
      taxonomicClass: 'Aves',
      habitats: const ['forest'],
      continents: const ['North America'],
    );
    final output = Item(
      id: 'opaque-item-id',
      displayName: 'Unidentified fauna specimen',
      category: ItemCategory.fauna,
      acquiredAt: DateTime.utc(2026, 7, 21),
      status: ItemStatus.active,
      identificationState: ItemIdentificationState.unidentified,
    );

    final inputSummary = useCase.summarizeInput(input) as Map<String, dynamic>;
    final outputSummary =
        useCase.summarizeOutput(output) as Map<String, dynamic>;

    expect(inputSummary, {
      'category': 'fauna',
      'has_map_cell_entry_provenance': true,
    });
    expect(outputSummary, {
      'item_id': 'opaque-item-id',
      'category': 'fauna',
      'status': 'active',
      'identification_state': 'unidentified',
    });
    expect(inputSummary.values.join(), isNot(contains(input.definitionId)));
    expect(outputSummary.values.join(), isNot(contains('definition')));
  });
}

final class _UnusedItemRepository implements ItemRepository {
  @override
  Future<Item> acquireDiscoveryItem(DiscoveryItemDraft draft,
      {String? traceId}) {
    throw UnimplementedError();
  }

  @override
  Future<List<Item>> fetchItems(String userId, {String? traceId}) {
    throw UnimplementedError();
  }

  @override
  Future<Item> identifyUnidentifiedFind(Item item, {String? traceId}) {
    throw UnimplementedError();
  }
  @override
  Future<Item> examineItem(Item item, {String? traceId}) =>
      throw UnimplementedError();
}
