import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:earth_nova/features/map/data/dtos/cell_dto.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/repositories/cell_repository.dart';

typedef CellFetchQuery = Future<List<Map<String, dynamic>>> Function(
  double lat,
  double lng,
  double radiusMeters,
);
typedef CellRecordVisitQuery = Future<void> Function(
    String userId, String cellId);
typedef CellVisitedIdsQuery = Future<List<Map<String, dynamic>>> Function(
    String userId);
typedef CellFirstVisitQuery = Future<List<Map<String, dynamic>>> Function(
  String userId,
  String cellId,
);
typedef RepositoryLogEvent = void Function(
  String event,
  String category, {
  Map<String, dynamic>? data,
});

class SupabaseCellRepository implements CellRepository {
  SupabaseCellRepository({
    required SupabaseClient? client,
    CellFetchQuery? fetchCellsQuery,
    CellRecordVisitQuery? recordVisitQuery,
    CellVisitedIdsQuery? visitedCellIdsQuery,
    CellFirstVisitQuery? firstVisitQuery,
    RepositoryLogEvent? logEvent,
  })  : _client = client,
        _fetchCellsQuery = fetchCellsQuery,
        _recordVisitQuery = recordVisitQuery,
        _visitedCellIdsQuery = visitedCellIdsQuery,
        _firstVisitQuery = firstVisitQuery,
        _logEvent = logEvent;

  final SupabaseClient? _client;
  final CellFetchQuery? _fetchCellsQuery;
  final CellRecordVisitQuery? _recordVisitQuery;
  final CellVisitedIdsQuery? _visitedCellIdsQuery;
  final CellFirstVisitQuery? _firstVisitQuery;
  final RepositoryLogEvent? _logEvent;
  static const _category = 'map.cell_repository';

  @override
  Future<List<Cell>> fetchCellsInRadius(
      double lat, double lng, double radiusMeters,
      {String? traceId}) async {
    final stopwatch = Stopwatch()..start();
    _logEvent?.call('db.query_started', _category, data: {'trace_id': traceId});
    try {
      final response = await _runFetchCellsQuery(lat, lng, radiusMeters);
      final cells = response
          .map((json) => CellDto.fromJson({
                'cell_id': json['cell_id'],
                'habitats': json['habitats'] ?? [],
                'polygon': <Map<String, dynamic>>[],
                'district_id': null,
                'city_id': null,
                'state_id': null,
                'country_id': null,
              }).toDomain())
          .toList();
      _logEvent?.call('db.query_completed', _category, data: {
        'trace_id': traceId,
        'row_count': response.length,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      return cells;
    } catch (error) {
      _logEvent?.call('db.query_failed', _category, data: {
        'trace_id': traceId,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      rethrow;
    }
  }

  @override
  Future<void> recordVisit(String userId, String cellId,
      {String? traceId}) async {
    final stopwatch = Stopwatch()..start();
    _logEvent?.call('db.query_started', _category, data: {'trace_id': traceId});
    try {
      await _runRecordVisitQuery(userId, cellId);
      _logEvent?.call('db.query_completed', _category, data: {
        'trace_id': traceId,
        'row_count': 1,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
    } catch (error) {
      _logEvent?.call('db.query_failed', _category, data: {
        'trace_id': traceId,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      rethrow;
    }
  }

  @override
  Future<Set<String>> getVisitedCellIds(String userId,
      {String? traceId}) async {
    final stopwatch = Stopwatch()..start();
    _logEvent?.call('db.query_started', _category, data: {'trace_id': traceId});
    try {
      final response = await _runVisitedIdsQuery(userId);
      final result = response.map((row) => row['cell_id'] as String).toSet();
      _logEvent?.call('db.query_completed', _category, data: {
        'trace_id': traceId,
        'row_count': response.length,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      return result;
    } catch (error) {
      _logEvent?.call('db.query_failed', _category, data: {
        'trace_id': traceId,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      rethrow;
    }
  }

  @override
  Future<bool> isFirstVisit(String userId, String cellId,
      {String? traceId}) async {
    final stopwatch = Stopwatch()..start();
    _logEvent?.call('db.query_started', _category, data: {'trace_id': traceId});
    try {
      final response = await _runFirstVisitQuery(userId, cellId);
      _logEvent?.call('db.query_completed', _category, data: {
        'trace_id': traceId,
        'row_count': response.length,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      return response.isEmpty;
    } catch (error) {
      _logEvent?.call('db.query_failed', _category, data: {
        'trace_id': traceId,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _runFetchCellsQuery(
    double lat,
    double lng,
    double radiusMeters,
  ) async {
    if (_fetchCellsQuery != null) {
      return _fetchCellsQuery!(lat, lng, radiusMeters);
    }
    final client = _client;
    if (client == null) {
      throw StateError(
          'Supabase client is required when no fetchCellsQuery is provided.');
    }
    final response = await client
        .from('cell_properties')
        .select('cell_id, habitats, location_id');
    return (response as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> _runRecordVisitQuery(String userId, String cellId) async {
    if (_recordVisitQuery != null) {
      await _recordVisitQuery!(userId, cellId);
      return;
    }
    final client = _client;
    if (client == null) {
      throw StateError(
          'Supabase client is required when no recordVisitQuery is provided.');
    }
    await client.from('v3_cell_visits').insert({
      'user_id': userId,
      'cell_id': cellId,
    });
  }

  Future<List<Map<String, dynamic>>> _runVisitedIdsQuery(String userId) async {
    if (_visitedCellIdsQuery != null) {
      return _visitedCellIdsQuery!(userId);
    }
    final client = _client;
    if (client == null) {
      throw StateError(
          'Supabase client is required when no visitedCellIdsQuery is provided.');
    }
    final response = await client
        .from('v3_cell_visits')
        .select('cell_id')
        .eq('user_id', userId);
    return (response as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _runFirstVisitQuery(
    String userId,
    String cellId,
  ) async {
    if (_firstVisitQuery != null) {
      return _firstVisitQuery!(userId, cellId);
    }
    final client = _client;
    if (client == null) {
      throw StateError(
          'Supabase client is required when no firstVisitQuery is provided.');
    }
    final response = await client
        .from('v3_cell_visits')
        .select('id')
        .eq('user_id', userId)
        .eq('cell_id', cellId)
        .limit(1);
    return (response as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }
}
