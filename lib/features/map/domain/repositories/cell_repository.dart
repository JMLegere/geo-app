import 'package:earth_nova/features/map/domain/entities/cell.dart';

abstract class CellRepository {
  Future<List<Cell>> fetchCellsInRadius(
      double lat, double lng, double radiusMeters,
      {String? traceId});

  Future<void> recordVisit(String userId, String cellId, {String? traceId});

  Future<Set<String>> getVisitedCellIds(String userId, {String? traceId});

  Future<bool> isFirstVisit(String userId, String cellId, {String? traceId});
}
