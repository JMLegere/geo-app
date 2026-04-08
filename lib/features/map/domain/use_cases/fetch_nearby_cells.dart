import 'package:earth_nova/core/observability/observable_use_case.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/repositories/cell_repository.dart';

typedef FetchNearbyCellsInput = ({
  double lat,
  double lng,
  double radiusMeters,
});

class FetchNearbyCells
    extends ObservableUseCase<FetchNearbyCellsInput, List<Cell>> {
  FetchNearbyCells(this._repository, this._obs);

  final CellRepository _repository;
  final ObservabilityService _obs;

  @override
  ObservabilityService get obs => _obs;

  @override
  String get operationName => 'fetch_nearby_cells';

  @override
  Future<List<Cell>> execute(FetchNearbyCellsInput input, String traceId) {
    return _repository.fetchCellsInRadius(
      input.lat,
      input.lng,
      input.radiusMeters,
    );
  }
}
