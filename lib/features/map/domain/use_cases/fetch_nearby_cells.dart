import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/repositories/cell_repository.dart';

class FetchNearbyCells {
  const FetchNearbyCells(this._repository);
  final CellRepository _repository;

  Future<List<Cell>> call({
    required double lat,
    required double lng,
    required double radiusMeters,
  }) =>
      _repository.fetchCellsInRadius(lat, lng, radiusMeters);
}
