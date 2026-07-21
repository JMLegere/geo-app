import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';

abstract class CellRepository {
  Future<List<Cell>> fetchCellsInRadius(
      double lat, double lng, double radiusMeters,
      {String? traceId});

  Future<CellVisit> recordVisit(
    String userId,
    String cellId,
    String clientEventId, {
    String? traceId,
  });

  Future<Set<String>> getVisitedCellIds(String userId, {String? traceId});

  Future<bool> isFirstVisit(String userId, String cellId, {String? traceId});
}

/// Safe failure emitted by Cell repository boundaries.
///
/// It deliberately carries only stable domain-safe diagnostic information, so
/// callers and use-case telemetry cannot expose transport, SQL, or payload
/// details supplied by the backend.
final class CellRepositoryFailure implements Exception {
  const CellRepositoryFailure._(this.kind);

  const CellRepositoryFailure.unavailable()
      : this._(CellRepositoryFailureKind.unavailable);
  const CellRepositoryFailure.malformedPayload()
      : this._(CellRepositoryFailureKind.malformedPayload);

  final CellRepositoryFailureKind kind;

  @override
  String toString() => 'Cell request failed (${kind.name}).';
}

enum CellRepositoryFailureKind {
  unavailable,
  malformedPayload,
}
