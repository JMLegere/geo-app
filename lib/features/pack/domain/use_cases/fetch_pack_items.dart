import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/observable_use_case.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/pack/domain/repositories/pack_repository.dart';

class FetchPackItems extends ObservableUseCase<String, List<Item>> {
  const FetchPackItems(this._repository, this._obs);

  final PackRepository _repository;
  final ObservabilityService _obs;

  @override
  ObservabilityService get obs => _obs;

  @override
  String get operationName => 'fetch_pack_items';

  @override
  Future<List<Item>> execute(String userId, String traceId) =>
      _repository.fetchActiveItems(userId, traceId: traceId);

  @override
  Object summarizeOutput(List<Item> output) => {'count': output.length};
}
