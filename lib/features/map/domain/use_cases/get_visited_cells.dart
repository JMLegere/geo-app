import 'package:earth_nova/features/map/domain/repositories/cell_repository.dart';

class GetVisitedCells {
  const GetVisitedCells(this._repository);
  final CellRepository _repository;

  Future<Set<String>> call(String userId) =>
      _repository.getVisitedCellIds(userId);
}
