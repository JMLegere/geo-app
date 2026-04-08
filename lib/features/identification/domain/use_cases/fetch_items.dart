import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/observable_use_case.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/identification/domain/repositories/item_repository.dart';

class FetchItems extends ObservableUseCase<String, List<Item>> {
  const FetchItems(this._repository, this._obs);

  final ItemRepository _repository;
  final ObservabilityService _obs;

  @override
  ObservabilityService get obs => _obs;

  @override
  String get operationName => 'fetch_items';

  @override
  Future<List<Item>> execute(String userId, String traceId) =>
      _repository.fetchItems(userId, traceId: traceId);

  @override
  Object summarizeOutput(List<Item> output) => {'count': output.length};
}
