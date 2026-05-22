import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/observable_use_case.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/identification/domain/entities/discovery_item_draft.dart';
import 'package:earth_nova/features/identification/domain/repositories/item_repository.dart';

class AcquireDiscoveryItem extends ObservableUseCase<DiscoveryItemDraft, Item> {
  const AcquireDiscoveryItem(this._repository, this._obs);

  final ItemRepository _repository;
  final ObservabilityService _obs;

  @override
  ObservabilityService get obs => _obs;

  @override
  String get operationName => 'acquire_discovery_item';

  @override
  Future<Item> execute(DiscoveryItemDraft input, String traceId) {
    return _repository.acquireDiscoveryItem(input, traceId: traceId);
  }

  @override
  Object summarizeInput(DiscoveryItemDraft input) => {
        'definition_id': input.definitionId,
        'cell_id': input.acquiredInCellId,
        'map_cell_entry_id': input.mapCellEntryId,
      };

  @override
  Object summarizeOutput(Item output) => {
        'item_id': output.id,
        'definition_id': output.definitionId,
      };
}
