import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/observable_use_case.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/identification/domain/repositories/item_repository.dart';

class ExaminePackItem extends ObservableUseCase<Item, Item> {
  const ExaminePackItem(this._repository, this._obs);

  final ItemRepository _repository;
  final ObservabilityService _obs;

  @override
  ObservabilityService get obs => _obs;

  @override
  String get operationName => 'examine_pack_item';

  @override
  Future<Item> execute(Item item, String traceId) =>
      _repository.examineItem(item, traceId: traceId);

  @override
  Object summarizeInput(Item input) => {'item_id': input.id};

  @override
  Object summarizeOutput(Item output) => {'item_id': output.id};
}
