import 'package:earth_nova/features/map/domain/entities/map_level.dart';
import 'package:earth_nova/features/map/domain/repositories/hierarchy_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef HierarchyRpcCaller = Future<List<Map<String, dynamic>>> Function(
  String functionName,
  Map<String, dynamic> params,
);
typedef RepositoryLogEvent = void Function(
  String event,
  String category, {
  Map<String, dynamic>? data,
});

class SupabaseHierarchyRepository implements HierarchyRepository {
  SupabaseHierarchyRepository({
    required SupabaseClient client,
    HierarchyRpcCaller? rpcCaller,
    RepositoryLogEvent? logEvent,
  })  : _client = client,
        _rpcCaller = rpcCaller,
        _logEvent = logEvent;

  final SupabaseClient _client;
  final HierarchyRpcCaller? _rpcCaller;
  final RepositoryLogEvent? _logEvent;
  static const _category = 'map.hierarchy_repository';

  @override
  Future<HierarchyProgressSummary> getScopeSummary({
    required String userId,
    required MapLevel level,
    String? scopeId,
  }) async {
    final rows = await _runRpc('get_hierarchy_scope_summary', {
      'p_user_id': userId,
      'p_scope_level': level.name,
      'p_scope_id': scopeId,
    });

    if (rows.isEmpty) {
      throw StateError(
        'No scope summary returned for level=${level.name}, scopeId=$scopeId.',
      );
    }

    return _summaryFromRow(rows.first);
  }

  @override
  Future<List<HierarchyProgressSummary>> getChildSummaries({
    required String userId,
    required MapLevel level,
    String? scopeId,
  }) async {
    final rows = await _runRpc('get_hierarchy_child_summaries_with_rank', {
      'p_user_id': userId,
      'p_scope_level': level.name,
      'p_scope_id': scopeId,
    });

    return rows.map(_summaryFromRow).toList();
  }

  Future<List<Map<String, dynamic>>> _runRpc(
    String functionName,
    Map<String, dynamic> params,
  ) async {
    final stopwatch = Stopwatch()..start();
    _logEvent?.call('db.rpc_started', _category, data: {
      'operation': functionName,
      'rpc_function': functionName,
      'scope_level': params['p_scope_level'],
      'scope_id': params['p_scope_id'],
    });
    try {
      final response = _rpcCaller != null
          ? await _rpcCaller!(functionName, params)
          : await _client.rpc(functionName, params: params);
      if (response is! List) {
        _logEvent?.call('db.rpc_completed', _category, data: {
          'operation': functionName,
          'rpc_function': functionName,
          'row_count': 0,
          'duration_ms': stopwatch.elapsedMilliseconds,
        });
        return [];
      }

      final rows = response
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      _logEvent?.call('db.rpc_completed', _category, data: {
        'operation': functionName,
        'rpc_function': functionName,
        'row_count': rows.length,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      return rows;
    } catch (error) {
      _logEvent?.call('db.rpc_failed', _category, data: {
        'operation': functionName,
        'rpc_function': functionName,
        'duration_ms': stopwatch.elapsedMilliseconds,
        'error_type': error.runtimeType.toString(),
        'error_message': error.toString(),
      });
      rethrow;
    }
  }

  HierarchyProgressSummary _summaryFromRow(Map<String, dynamic> row) {
    return HierarchyProgressSummary(
      id: row['id'] as String? ?? '',
      name: row['name'] as String? ?? '',
      level: _mapLevelFromSql(row['level'] as String? ?? ''),
      cellsVisited: _asInt(row['cells_visited']),
      cellsTotal: _asInt(row['cells_total']),
      progressPercent: _asDouble(row['progress_percent']),
      rank: _asInt(row['rank']),
    );
  }

  MapLevel _mapLevelFromSql(String value) {
    return switch (value) {
      'cell' => MapLevel.cell,
      'district' => MapLevel.district,
      'city' => MapLevel.city,
      'state' => MapLevel.state,
      'country' => MapLevel.country,
      'world' => MapLevel.world,
      _ => throw StateError('Unknown map level: $value'),
    };
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
