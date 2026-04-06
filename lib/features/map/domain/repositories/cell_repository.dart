import 'package:earth_nova/features/map/domain/entities/cell.dart';

abstract class CellRepository {
  Future<List<Cell>> fetchCellsInRadius(
    double lat,
    double lng,
    double radiusMeters,
  );

  Future<void> recordVisit(String userId, String cellId);

  Future<Set<String>> getVisitedCellIds(String userId);

  Future<bool> isFirstVisit(String userId, String cellId);
}
