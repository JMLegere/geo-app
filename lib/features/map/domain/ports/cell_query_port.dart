import 'package:earth_nova/features/map/domain/entities/cell.dart';

abstract interface class CellQueryPort {
  Future<List<Cell>> fetchNearbyCells({
    required double lat,
    required double lng,
    required double radiusMeters,
    String? traceId,
  });
}
