import 'package:earth_nova/features/map/domain/repositories/cell_repository.dart';

class RecordCellVisit {
  const RecordCellVisit(this._repository);
  final CellRepository _repository;

  Future<void> call({
    required String userId,
    required String cellId,
  }) =>
      _repository.recordVisit(userId, cellId);
}
