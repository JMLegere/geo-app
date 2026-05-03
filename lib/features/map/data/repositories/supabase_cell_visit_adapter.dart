import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:earth_nova/features/map/domain/ports/cell_visit_port.dart';

typedef CellRecordVisitQuery = Future<void> Function(
    String userId, String cellId);
typedef CellVisitedIdsQuery = Future<List<Map<String, dynamic>>> Function(
  String userId,
);
typedef CellFirstVisitQuery = Future<List<Map<String, dynamic>>> Function(
  String userId,
  String cellId,
);

class SupabaseCellVisitAdapter implements CellVisitPort {
  SupabaseCellVisitAdapter({
    required SupabaseClient? client,
    CellRecordVisitQuery? recordVisitQuery,
    CellVisitedIdsQuery? visitedCellIdsQuery,
    CellFirstVisitQuery? firstVisitQuery,
  })  : _client = client,
        _recordVisitQuery = recordVisitQuery,
        _visitedCellIdsQuery = visitedCellIdsQuery,
        _firstVisitQuery = firstVisitQuery;

  final SupabaseClient? _client;
  final CellRecordVisitQuery? _recordVisitQuery;
  final CellVisitedIdsQuery? _visitedCellIdsQuery;
  final CellFirstVisitQuery? _firstVisitQuery;

  @override
  Future<void> recordVisit({
    required String userId,
    required String cellId,
    String? traceId,
  }) async {
    if (_recordVisitQuery != null) {
      await _recordVisitQuery!(userId, cellId);
      return;
    }

    final client = _client;
    if (client == null) {
      throw StateError(
        'Supabase client is required when no recordVisitQuery is provided.',
      );
    }

    await client.from('v3_cell_visits').insert({
      'user_id': userId,
      'cell_id': cellId,
    });
  }

  @override
  Future<Set<String>> getVisitedCellIds({
    required String userId,
    String? traceId,
  }) async {
    final response = await _runVisitedIdsQuery(userId);
    return response.map((row) => row['cell_id'] as String).toSet();
  }

  @override
  Future<bool> isFirstVisit({
    required String userId,
    required String cellId,
    String? traceId,
  }) async {
    final response = await _runFirstVisitQuery(userId, cellId);
    return response.isEmpty;
  }

  Future<List<Map<String, dynamic>>> _runVisitedIdsQuery(String userId) async {
    if (_visitedCellIdsQuery != null) {
      return _visitedCellIdsQuery!(userId);
    }

    final client = _client;
    if (client == null) {
      throw StateError(
        'Supabase client is required when no visitedCellIdsQuery is provided.',
      );
    }

    final response = await client
        .from('v3_cell_visits')
        .select('cell_id')
        .eq('user_id', userId);

    return (response as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
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
        'Supabase client is required when no firstVisitQuery is provided.',
      );
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
        .toList(growable: false);
  }
}
