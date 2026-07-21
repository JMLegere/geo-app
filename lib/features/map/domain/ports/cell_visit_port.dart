import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';

abstract interface class CellVisitPort {
  Future<CellVisit> recordVisit({
    required String userId,
    required String cellId,
    required String clientEventId,
    String? traceId,
  });

  Future<Set<String>> getVisitedCellIds({
    required String userId,
    String? traceId,
  });

  Future<bool> isFirstVisit({
    required String userId,
    required String cellId,
    String? traceId,
  });
}
