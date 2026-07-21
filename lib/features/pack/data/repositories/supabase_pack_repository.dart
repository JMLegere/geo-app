import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/identification/data/dtos/item_dto.dart';
import 'package:earth_nova/features/pack/domain/repositories/pack_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef PackActiveItemsQuery = Future<List<Map<String, dynamic>>> Function(
  String userId,
);
typedef PackRpcCaller = Future<dynamic> Function(
  String functionName,
  Map<String, dynamic> params,
);
typedef PackRepositoryLogEvent = void Function(
  String event,
  String category, {
  Map<String, dynamic>? data,
});

/// Supabase read adapter for the Player's active owned Item instances.
///
/// This boundary intentionally has no acquisition, Identification, mutation, or
/// Index operations. Item rows are parsed through the shared strict [ItemDto].
class SupabasePackRepository implements PackRepository {
  SupabasePackRepository({
    required SupabaseClient? client,
    PackActiveItemsQuery? fetchActiveItemsQuery,
    PackRpcCaller? rpcCaller,
    PackRepositoryLogEvent? logEvent,
  })  : _client = client,
        _fetchActiveItemsQuery = fetchActiveItemsQuery,
        _rpcCaller = rpcCaller,
        _logEvent = logEvent;

  final SupabaseClient? _client;
  final PackActiveItemsQuery? _fetchActiveItemsQuery;
  final PackRpcCaller? _rpcCaller;
  final PackRepositoryLogEvent? _logEvent;

  static const _category = 'pack.repository';

  @override
  Future<List<Item>> fetchActiveItems(
    String userId, {
    String? traceId,
  }) async {
    final stopwatch = Stopwatch()..start();
    _logEvent?.call('db.query_started', _category, data: {
      'trace_id': traceId,
      'operation': 'fetch_active_items',
    });

    try {
      final response = await _runFetchActiveItemsQuery(userId);
      final items = response
          .map(ItemDto.fromJson)
          .map((dto) => dto.toDomain())
          .toList(growable: false);
      _logEvent?.call('db.query_completed', _category, data: {
        'trace_id': traceId,
        'operation': 'fetch_active_items',
        'row_count': response.length,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      return items;
    } catch (error) {
      _logEvent?.call('db.query_failed', _category, data: {
        'trace_id': traceId,
        'operation': 'fetch_active_items',
        'duration_ms': stopwatch.elapsedMilliseconds,
        'error_type': error.runtimeType.toString(),
        'error_message': _safeErrorMessage(error),
      });
      throw StateError('Fetching Pack Items failed.');
    }
  }

  Future<List<Map<String, dynamic>>> _runFetchActiveItemsQuery(
    String userId,
  ) async {
    final query = _fetchActiveItemsQuery;
    if (query != null) return query(userId);

    final dynamic response;
    final caller = _rpcCaller;
    if (caller != null) {
      response = await caller('fetch_v3_pack_items', const {});
    } else {
      final client = _client;
      if (client == null) {
        throw StateError(
          'Supabase client is required when no Pack query or RPC caller is provided.',
        );
      }
      response = await client.rpc('fetch_v3_pack_items');
    }

    if (response is! Map || response['items'] is! List) {
      throw StateError('Pack Item projection must return an items array.');
    }
    return (response['items'] as List).map((row) {
      if (row is! Map) {
        throw StateError('Pack Item projection contains a non-object row.');
      }
      return Map<String, dynamic>.from(row);
    }).toList(growable: false);
  }
}

String _safeErrorMessage(Object error) => switch (error) {
      StateError() => 'invalid_repository_response',
      _ => 'repository_operation_failed',
    };
