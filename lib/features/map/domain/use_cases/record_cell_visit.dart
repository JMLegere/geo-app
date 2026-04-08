import 'package:earth_nova/core/observability/observable_use_case.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/trace_context.dart';
import 'package:earth_nova/features/map/domain/repositories/cell_repository.dart';

typedef RecordCellVisitInput = ({
  String userId,
  String cellId,
});

class RecordCellVisit extends ObservableUseCase<RecordCellVisitInput, void> {
  RecordCellVisit(this._repository, this._obs);

  final CellRepository _repository;
  final ObservabilityService _obs;

  @override
  ObservabilityService get obs => _obs;

  @override
  String get operationName => 'record_cell_visit';

  @override
  Future<void> call(RecordCellVisitInput input) {
    return super.call(input) as Future<void>;
  }

  @override
  Future<void> execute(RecordCellVisitInput input, TraceContext context) {
    return _repository.recordVisit(input.userId, input.cellId);
  }
}
