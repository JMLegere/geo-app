import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:earth_nova/features/map/data/dtos/cell_knowledge_projection_dto.dart';
import 'package:earth_nova/features/map/domain/entities/cell_knowledge_projection.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/domain/repositories/cell_knowledge_repository.dart';

typedef CellKnowledgeRpcQuery = Future<Object?> Function(
  String functionName,
  Map<String, Object?> params,
);
typedef CellKnowledgeRepositoryLogEvent = void Function(
  String event,
  String category, {
  Map<String, dynamic>? data,
});

class SupabaseCellKnowledgeRepository implements CellKnowledgeRepository {
  SupabaseCellKnowledgeRepository({
    required SupabaseClient? client,
    CellKnowledgeRpcQuery? rpcQuery,
    CellKnowledgeRepositoryLogEvent? logEvent,
  })  : _client = client,
        _rpcQuery = rpcQuery,
        _logEvent = logEvent;

  static const maxCellIdsPerRequest = 256;
  static const _category = 'cell_knowledge.repository';

  final SupabaseClient? _client;
  final CellKnowledgeRpcQuery? _rpcQuery;
  final CellKnowledgeRepositoryLogEvent? _logEvent;

  @override
  Future<Map<String, CellKnowledgeProjection>> fetchForCells(
    Iterable<String> cellIds, {
    String? traceId,
  }) async {
    final requestedIds = _boundedDistinctCellIds(cellIds);
    if (requestedIds.isEmpty) {
      return {};
    }

    const operation = 'fetch_player_cell_states';
    final stopwatch = Stopwatch()..start();
    _logEvent?.call('db.query_started', _category, data: {
      'trace_id': traceId,
      'operation': operation,
    });

    try {
      final response = await _runRpc(requestedIds);
      if (response is! List) {
        throw FormatException(
          'fetch_v3_player_cell_states must return a JSON array response.',
        );
      }

      final requestedIdSet = requestedIds.toSet();
      final projections = <String, CellKnowledgeProjection>{};
      for (final rawRow in response) {
        final row = _projectionRow(rawRow);
        final cellId = row['cell_id'];
        if (cellId is! String || cellId.isEmpty) {
          throw FormatException(
            'fetch_v3_player_cell_states rows require a non-empty cell_id.',
          );
        }
        if (!requestedIdSet.contains(cellId)) {
          throw FormatException(
            'fetch_v3_player_cell_states returned an unrequested cell_id.',
          );
        }
        if (projections.containsKey(cellId)) {
          throw FormatException(
            'fetch_v3_player_cell_states returned a duplicate cell_id.',
          );
        }

        projections[cellId] =
            CellKnowledgeProjectionDto.fromJson(_safeProjection(row)).toDomain();
      }

      for (final cellId in requestedIds) {
        projections.putIfAbsent(
          cellId,
          () => CellKnowledgeProjection(
            cellId: cellId,
            state: CellKnowledgeState.shrouded,
          ),
        );
      }
      _logEvent?.call('db.query_completed', _category, data: {
        'trace_id': traceId,
        'operation': operation,
        'row_count': response.length,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      return projections;
    } catch (error) {
      _logEvent?.call('db.query_failed', _category, data: {
        'trace_id': traceId,
        'operation': operation,
        'duration_ms': stopwatch.elapsedMilliseconds,
        'error_type': error.runtimeType.toString(),
        'error_message': _safeErrorMessage(error),
      });
      throw StateError('Fetching Cell knowledge failed.');
    }
  }

  Future<Object?> _runRpc(List<String> cellIds) {
    const functionName = 'fetch_v3_player_cell_states';
    final params = <String, Object?>{'p_cell_ids': cellIds};
    final rpcQuery = _rpcQuery;
    if (rpcQuery != null) {
      return rpcQuery(functionName, params);
    }

    final client = _client;
    if (client == null) {
      throw StateError(
          'Supabase client is required when no RPC query is provided.');
    }
    return client.rpc(functionName, params: params);
  }

  static List<String> _boundedDistinctCellIds(Iterable<String> cellIds) {
    final ids = <String>[];
    final seen = <String>{};
    for (final cellId in cellIds) {
      if (cellId.isEmpty || !seen.add(cellId)) {
        continue;
      }
      ids.add(cellId);
      if (ids.length == maxCellIdsPerRequest) {
        break;
      }
    }
    return ids;
  }

  static Map<String, Object?> _projectionRow(Object? rawRow) {
    if (rawRow is! Map) {
      throw FormatException(
        'fetch_v3_player_cell_states rows must be JSON objects.',
      );
    }

    final row = <String, Object?>{};
    for (final entry in rawRow.entries) {
      if (entry.key is! String) {
        throw FormatException(
          'fetch_v3_player_cell_states row keys must be strings.',
        );
      }
      row[entry.key as String] = entry.value;
    }
    return row;
  }

  static Map<String, Object?> _safeProjection(Map<String, Object?> row) {
    final category = row['category'];
    final opportunityCategory = row['opportunity_category'];
    if (category != null &&
        opportunityCategory != null &&
        category != opportunityCategory) {
      throw FormatException(
        'fetch_v3_player_cell_states returned conflicting category fields.',
      );
    }
    return {
      'cell_id': row['cell_id'],
      'state': row['state'],
      'category': category ?? opportunityCategory,
    };
  }
}

String _safeErrorMessage(Object error) => switch (error) {
      StateError() => 'invalid_repository_response',
      _ => 'repository_operation_failed',
    };
