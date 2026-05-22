import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/observable_use_case.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/identification/domain/repositories/item_repository.dart';

class IdentifyUnidentifiedFind extends ObservableUseCase<Item, Item> {
  const IdentifyUnidentifiedFind(this._repository, this._obs);

  final ItemRepository _repository;
  final ObservabilityService _obs;

  @override
  ObservabilityService get obs => _obs;

  @override
  String get operationName => 'identify_unidentified_find';

  @override
  Future<Item> execute(Item input, String traceId) {
    return _repository.identifyUnidentifiedFind(input, traceId: traceId);
  }
}
