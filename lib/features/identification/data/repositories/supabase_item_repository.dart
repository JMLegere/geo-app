import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/identification/data/dtos/item_dto.dart';
import 'package:earth_nova/features/identification/domain/repositories/item_repository.dart';

typedef ItemFetchQuery = Future<List<Map<String, dynamic>>> Function(
    String userId);
typedef RepositoryLogEvent = void Function(
  String event,
  String category, {
  Map<String, dynamic>? data,
});

class SupabaseItemRepository implements ItemRepository {
  SupabaseItemRepository({
    required SupabaseClient? client,
    ItemFetchQuery? fetchItemsQuery,
    RepositoryLogEvent? logEvent,
  })  : _client = client,
        _fetchItemsQuery = fetchItemsQuery,
        _logEvent = logEvent;

  final SupabaseClient? _client;
  final ItemFetchQuery? _fetchItemsQuery;
  final RepositoryLogEvent? _logEvent;
  static const _category = 'identification.item_repository';

  @override
  Future<List<Item>> fetchItems(String userId, {String? traceId}) async {
    final stopwatch = Stopwatch()..start();
    _logEvent?.call('db.query_started', _category, data: {'trace_id': traceId});
    try {
      final response = await _runFetchItemsQuery(userId);
      final items =
          response.map((json) => ItemDto.fromJson(json).toDomain()).toList();
      _logEvent?.call('db.query_completed', _category, data: {
        'trace_id': traceId,
        'row_count': response.length,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      return items;
    } catch (error) {
      _logEvent?.call('db.query_failed', _category, data: {
        'trace_id': traceId,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _runFetchItemsQuery(String userId) async {
    if (_fetchItemsQuery != null) {
      return _fetchItemsQuery!(userId);
    }
    final client = _client;
    if (client == null) {
      throw StateError(
          'Supabase client is required when no fetchItemsQuery is provided.');
    }
    final response = await client
        .from('v3_items')
        .select()
        .eq('user_id', userId)
        .eq('status', 'active')
        .order('acquired_at', ascending: false);
    return (response as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }
}
