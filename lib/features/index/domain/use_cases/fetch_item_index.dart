import 'package:earth_nova/core/observability/observable_use_case.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/index/domain/entities/index_entry.dart';
import 'package:earth_nova/features/index/domain/repositories/item_index_repository.dart';

/// Reads the complete stable Base Item Index projection.
final class FetchItemIndex extends ObservableUseCase<void, List<IndexEntry>> {
  const FetchItemIndex(this._repository, this._obs);

  final ItemIndexRepository _repository;
  final ObservabilityService _obs;

  @override
  ObservabilityService get obs => _obs;

  @override
  String get operationName => 'item_index.fetch';

  @override
  Future<List<IndexEntry>> execute(void input, String traceId) async {
    try {
      return await _repository.fetchIndex(traceId: traceId);
    } on ItemIndexFailure {
      rethrow;
    } catch (_) {
      throw const ItemIndexFailure.unavailable();
    }
  }

  @override
  Object summarizeOutput(List<IndexEntry> output) =>
      {'entry_count': output.length};
}
