import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:earth_nova/features/map/data/dtos/cell_visit_dto.dart';
import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';

import 'package:earth_nova/features/map/domain/ports/cell_visit_port.dart';

typedef CellVisitRpcQuery = Future<Object?> Function(
  String functionName,
  Map<String, Object?> params,
);
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
    CellVisitRpcQuery? rpcQuery,
    CellVisitedIdsQuery? visitedCellIdsQuery,
    CellFirstVisitQuery? firstVisitQuery,
  })  : _client = client,
        _rpcQuery = rpcQuery,
        _visitedCellIdsQuery = visitedCellIdsQuery,
        _firstVisitQuery = firstVisitQuery;

  final SupabaseClient? _client;
  final CellVisitRpcQuery? _rpcQuery;
  final CellVisitedIdsQuery? _visitedCellIdsQuery;
  final CellFirstVisitQuery? _firstVisitQuery;

  @override
  Future<CellVisit> recordVisit({
    required String userId,
    required String cellId,
    required String clientEventId,
    String? traceId,
  }) async {
    final response = await _runRecordVisitRpc(cellId, clientEventId);
    final visit = CellVisitDto.fromJson(
      _requiredRecordVisitResponseObject(response),
    ).toDomain();

    if (visit.userId != userId ||
        visit.cellId != cellId ||
        visit.clientEventId != clientEventId) {
      throw StateError(
        'record_v3_cell_visit returned a Cell Visit that does not match '
        'the requested ownership or identity.',
      );
    }
    return visit;
  }

  Future<Object?> _runRecordVisitRpc(
    String cellId,
    String clientEventId,
  ) async {
    const functionName = 'record_v3_cell_visit';
    final params = <String, Object?>{
      'p_cell_id': cellId,
      'p_client_event_id': clientEventId,
    };
    if (_rpcQuery != null) {
      return _rpcQuery!(functionName, params);
    }

    final client = _client;
    if (client == null) {
      throw StateError(
        'Supabase client is required when no RPC query is provided.',
      );
    }

    return client.rpc(functionName, params: params);
  }

  static Map<String, Object?> _requiredRecordVisitResponseObject(
    Object? response,
  ) {
    if (response is! Map) {
      throw FormatException(
        'record_v3_cell_visit must return a JSON object response.',
      );
    }

    final row = <String, Object?>{};
    for (final entry in response.entries) {
      final key = entry.key;
      if (key is! String) {
        throw FormatException(
          'record_v3_cell_visit response object keys must be strings.',
        );
      }
      row[key] = entry.value;
    }
    return row;
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
