import 'package:earth_nova/core/observability/observable_use_case.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/trace_context.dart';
import 'package:earth_nova/features/map/domain/repositories/cell_repository.dart';

typedef GetVisitedCellsInput = ({String userId});

class GetVisitedCells
    extends ObservableUseCase<GetVisitedCellsInput, Set<String>> {
  GetVisitedCells(this._repository, this._obs);

  final CellRepository _repository;
  final ObservabilityService _obs;

  @override
  ObservabilityService get obs => _obs;

  @override
  String get operationName => 'get_visited_cells';

  @override
  Future<Set<String>> call(GetVisitedCellsInput input) {
    return super.call(input) as Future<Set<String>>;
  }

  @override
  Future<Set<String>> execute(
      GetVisitedCellsInput input, TraceContext context) {
    return _repository.getVisitedCellIds(input.userId);
  }
}
