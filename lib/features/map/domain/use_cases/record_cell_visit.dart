import 'package:earth_nova/core/observability/observable_use_case.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';

import 'package:earth_nova/features/map/domain/repositories/cell_repository.dart';

typedef RecordCellVisitInput = ({
  String userId,
  String cellId,
  String clientEventId,
});

class RecordCellVisit
    extends ObservableUseCase<RecordCellVisitInput, CellVisit> {
  RecordCellVisit(this._repository, this._obs);

  final CellRepository _repository;
  final ObservabilityService _obs;

  @override
  ObservabilityService get obs => _obs;

  @override
  String get operationName => 'record_cell_visit';

  @override
  Future<CellVisit> execute(RecordCellVisitInput input, String traceId) {
    if (input.clientEventId.isEmpty ||
        input.clientEventId != input.clientEventId.trim()) {
      throw ArgumentError.value(
        input.clientEventId,
        'clientEventId',
        'must be nonblank and already trimmed',
      );
    }

    return _repository.recordVisit(
      input.userId,
      input.cellId,
      input.clientEventId,
      traceId: traceId,
    );
  }
}
