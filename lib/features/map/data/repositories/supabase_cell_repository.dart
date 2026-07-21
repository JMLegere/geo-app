import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:earth_nova/features/map/data/repositories/supabase_cell_query_adapter.dart';
import 'package:earth_nova/features/map/data/repositories/supabase_cell_visit_adapter.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';

import 'package:earth_nova/features/map/domain/ports/cell_query_port.dart';
import 'package:earth_nova/features/map/domain/ports/cell_visit_port.dart';
import 'package:earth_nova/features/map/domain/repositories/cell_repository.dart';

typedef RepositoryLogEvent = void Function(
  String event,
  String category, {
  Map<String, dynamic>? data,
});

/// Legacy bridge for existing providers/use cases.
///
/// New map code should depend on [CellQueryPort] for world geometry and
/// [CellVisitPort] for player history. This repository remains while the current
/// providers still expect one combined cell API.
class SupabaseCellRepository implements CellRepository {
  SupabaseCellRepository({
    required SupabaseClient? client,
    CellQueryPort? queryPort,
    CellVisitPort? visitPort,
    CellFetchQuery? fetchCellsQuery,
    CellVisitRpcQuery? rpcQuery,
    CellVisitedIdsQuery? visitedCellIdsQuery,
    CellFirstVisitQuery? firstVisitQuery,
    RepositoryLogEvent? logEvent,
  })  : _queryPort = queryPort ??
            SupabaseCellQueryAdapter(
              client: client,
              fetchCellsQuery: fetchCellsQuery,
            ),
        _visitPort = visitPort ??
            SupabaseCellVisitAdapter(
              client: client,
              rpcQuery: rpcQuery,
              visitedCellIdsQuery: visitedCellIdsQuery,
              firstVisitQuery: firstVisitQuery,
            ),
        _logEvent = logEvent;

  final CellQueryPort _queryPort;
  final CellVisitPort _visitPort;
  final RepositoryLogEvent? _logEvent;
  static const _category = 'map.cell_repository';

  @override
  Future<List<Cell>> fetchCellsInRadius(
    double lat,
    double lng,
    double radiusMeters, {
    String? traceId,
  }) async {
    return _trace<List<Cell>>(
      traceId: traceId,
      operation: 'fetch_cells_in_radius',
      rowCount: (cells) => cells.length,
      action: () => _queryPort.fetchNearbyCells(
        lat: lat,
        lng: lng,
        radiusMeters: radiusMeters,
        traceId: traceId,
      ),
    );
  }

  @override
  Future<CellVisit> recordVisit(
    String userId,
    String cellId,
    String clientEventId, {
    String? traceId,
  }) {
    return _trace<CellVisit>(
      traceId: traceId,
      operation: 'record_cell_visit',
      rowCount: (_) => 1,
      action: () => _visitPort.recordVisit(
        userId: userId,
        cellId: cellId,
        clientEventId: clientEventId,
        traceId: traceId,
      ),
    );
  }

  @override
  Future<Set<String>> getVisitedCellIds(
    String userId, {
    String? traceId,
  }) async {
    return _trace<Set<String>>(
      traceId: traceId,
      operation: 'get_visited_cell_ids',
      rowCount: (ids) => ids.length,
      action: () => _visitPort.getVisitedCellIds(
        userId: userId,
        traceId: traceId,
      ),
    );
  }

  @override
  Future<bool> isFirstVisit(
    String userId,
    String cellId, {
    String? traceId,
  }) async {
    return _trace<bool>(
      traceId: traceId,
      operation: 'is_first_visit',
      rowCount: (_) => 1,
      action: () => _visitPort.isFirstVisit(
        userId: userId,
        cellId: cellId,
        traceId: traceId,
      ),
    );
  }

  Future<T> _trace<T>({
    required String? traceId,
    required String operation,
    required Future<T> Function() action,
    required int Function(T result) rowCount,
  }) async {
    final stopwatch = Stopwatch()..start();
    _logEvent?.call('db.query_started', _category, data: {
      'trace_id': traceId,
      'operation': operation,
    });

    try {
      final result = await action();
      _logEvent?.call('db.query_completed', _category, data: {
        'trace_id': traceId,
        'operation': operation,
        'row_count': rowCount(result),
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      return result;
    } catch (error) {
      final failure = _safeCellFailure(error);
      _logEvent?.call('db.query_failed', _category, data: {
        'trace_id': traceId,
        'operation': operation,
        'duration_ms': stopwatch.elapsedMilliseconds,
        'error_type': failure.runtimeType.toString(),
        'error_message': failure.kind.name,
      });
      throw failure;
    }
  }
}

CellRepositoryFailure _safeCellFailure(Object error) => switch (error) {
      CellRepositoryFailure() => error,
      StateError() ||
      ArgumentError() ||
      FormatException() ||
      TypeError() =>
        const CellRepositoryFailure.malformedPayload(),
      _ => const CellRepositoryFailure.unavailable(),
    };
