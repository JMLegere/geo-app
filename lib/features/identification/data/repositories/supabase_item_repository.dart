import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/identification/data/dtos/item_dto.dart';
import 'package:earth_nova/features/identification/domain/entities/discovery_item_draft.dart';
import 'package:earth_nova/features/identification/domain/repositories/item_repository.dart';

typedef ItemFetchQuery = Future<List<Map<String, dynamic>>> Function(
    String userId);
typedef ItemAcquireQuery = Future<Map<String, dynamic>> Function(
  DiscoveryItemDraft draft,
);
typedef ItemAcquireRpcCaller = Future<dynamic> Function(
  String functionName,
  Map<String, dynamic> params,
);
typedef ItemFetchRpcCaller = Future<dynamic> Function(
  String functionName,
  Map<String, dynamic> params,
);
typedef ItemIdentifyQuery = Future<Map<String, dynamic>> Function(
  Item item,
);
typedef RepositoryLogEvent = void Function(
  String event,
  String category, {
  Map<String, dynamic>? data,
});

class SupabaseItemRepository implements ItemRepository {
  SupabaseItemRepository({
    required SupabaseClient? client,
    ItemFetchQuery? fetchItemsQuery,
    ItemFetchRpcCaller? fetchItemsRpcCaller,
    RepositoryLogEvent? logEvent,
    ItemAcquireQuery? acquireDiscoveryItemQuery,
    ItemAcquireRpcCaller? acquireDiscoveryItemRpcCaller,
    ItemIdentifyQuery? identifyUnidentifiedFindQuery,
    ItemAcquireRpcCaller? examineItemRpcCaller,
  })  : _client = client,
        _fetchItemsQuery = fetchItemsQuery,
        _fetchItemsRpcCaller = fetchItemsRpcCaller,
        _acquireDiscoveryItemQuery = acquireDiscoveryItemQuery,
        _acquireDiscoveryItemRpcCaller = acquireDiscoveryItemRpcCaller,
        _identifyUnidentifiedFindQuery = identifyUnidentifiedFindQuery,
        _examineItemRpcCaller = examineItemRpcCaller,
        _logEvent = logEvent;

  final SupabaseClient? _client;
  final ItemFetchQuery? _fetchItemsQuery;
  final ItemFetchRpcCaller? _fetchItemsRpcCaller;
  final ItemAcquireQuery? _acquireDiscoveryItemQuery;
  final ItemAcquireRpcCaller? _acquireDiscoveryItemRpcCaller;
  final ItemIdentifyQuery? _identifyUnidentifiedFindQuery;
  final ItemAcquireRpcCaller? _examineItemRpcCaller;
  final RepositoryLogEvent? _logEvent;
  static const _category = 'identification.item_repository';

  @override
  Future<List<Item>> fetchItems(String userId, {String? traceId}) async {
    final stopwatch = Stopwatch()..start();
    _logEvent?.call('db.query_started', _category, data: {
      'trace_id': traceId,
      'operation': 'fetch_items',
    });
    try {
      final response = await _runFetchItemsQuery(userId);
      final items =
          response.map((json) => ItemDto.fromJson(json).toDomain()).toList();
      _logEvent?.call('db.query_completed', _category, data: {
        'trace_id': traceId,
        'operation': 'fetch_items',
        'row_count': response.length,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      return items;
    } catch (error) {
      _logEvent?.call('db.query_failed', _category, data: {
        'trace_id': traceId,
        'operation': 'fetch_items',
        'duration_ms': stopwatch.elapsedMilliseconds,
        'error_type': error.runtimeType.toString(),
        'error_message': _safeErrorMessage(error),
      });
      throw StateError('Fetching Pack Items failed.');
    }
  }

  @override
  Future<Item> acquireDiscoveryItem(
    DiscoveryItemDraft draft, {
    String? traceId,
  }) async {
    final stopwatch = Stopwatch()..start();
    _logEvent?.call('db.query_started', _category, data: {
      'trace_id': traceId,
      'operation': 'acquire_discovery_item',
      'definition_id': draft.definitionId,
      'cell_id': draft.acquiredInCellId,
      'map_cell_entry_id': draft.mapCellEntryId,
    });
    try {
      final response = await _runAcquireDiscoveryItemQuery(draft);
      final item = ItemDto.fromJson(response).toDomain();
      _logEvent?.call('db.query_completed', _category, data: {
        'trace_id': traceId,
        'operation': 'acquire_discovery_item',
        'item_id': item.id,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      return item;
    } catch (error) {
      _logEvent?.call('db.query_failed', _category, data: {
        'trace_id': traceId,
        'operation': 'acquire_discovery_item',
        'definition_id': draft.definitionId,
        'duration_ms': stopwatch.elapsedMilliseconds,
        'error_type': error.runtimeType.toString(),
        'error_message': _safeErrorMessage(error),
      });
      throw StateError('Acquiring the Item failed.');
    }
  }

  @override
  Future<Item> identifyUnidentifiedFind(
    Item item, {
    String? traceId,
  }) async {
    final stopwatch = Stopwatch()..start();
    _logEvent?.call('db.query_started', _category, data: {
      'trace_id': traceId,
      'operation': 'identify_unidentified_find',
      'item_id': item.id,
      'definition_id': item.definitionId,
    });
    try {
      final response = await _runIdentifyUnidentifiedFindQuery(item);
      final identified = ItemDto.fromJson(response).toDomain();
      _logEvent?.call('db.query_completed', _category, data: {
        'trace_id': traceId,
        'operation': 'identify_unidentified_find',
        'item_id': identified.id,
        'definition_id': identified.definitionId,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      return identified;
    } catch (error) {
      _logEvent?.call('db.query_failed', _category, data: {
        'trace_id': traceId,
        'operation': 'identify_unidentified_find',
        'item_id': item.id,
        'definition_id': item.definitionId,
        'duration_ms': stopwatch.elapsedMilliseconds,
        'error_type': error.runtimeType.toString(),
        'error_message': _safeErrorMessage(error),
      });
      throw StateError('Identifying the Item failed.');
    }
  }

  @override
  Future<Item> examineItem(Item item, {String? traceId}) async {
    final stopwatch = Stopwatch()..start();
    _logEvent?.call('db.query_started', _category, data: {
      'trace_id': traceId,
      'operation': 'examine_item',
      'item_id': item.id,
    });
    try {
      final response = await _runExamineItemQuery(item);
      final examined = ItemDto.fromJson(response).toDomain();
      if (examined.id != item.id || !examined.isExamined) {
        throw StateError('Examination returned an invalid Item projection.');
      }
      _logEvent?.call('db.query_completed', _category, data: {
        'trace_id': traceId,
        'operation': 'examine_item',
        'item_id': examined.id,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      return examined;
    } catch (error) {
      _logEvent?.call('db.query_failed', _category, data: {
        'trace_id': traceId,
        'operation': 'examine_item',
        'item_id': item.id,
        'duration_ms': stopwatch.elapsedMilliseconds,
        'error_type': error.runtimeType.toString(),
        'error_message': _safeErrorMessage(error),
      });
      throw StateError('Examining the Item failed.');
    }
  }

  Future<List<Map<String, dynamic>>> _runFetchItemsQuery(String userId) async {
    final query = _fetchItemsQuery;
    if (query != null) return query(userId);

    final dynamic response;
    final caller = _fetchItemsRpcCaller;
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

  Future<Map<String, dynamic>> _runAcquireDiscoveryItemQuery(
    DiscoveryItemDraft draft,
  ) async {
    if (_acquireDiscoveryItemQuery != null) {
      final response = await _acquireDiscoveryItemQuery!(draft);
      return _requireAcquiredDiscoveryItemResponse(response, draft);
    }

    final params = _legacyAcquisitionRpcParams(draft);
    final dynamic response;
    if (_acquireDiscoveryItemRpcCaller != null) {
      response = await _acquireDiscoveryItemRpcCaller!(
        'acquire_v3_legacy_discovery_item',
        params,
      );
    } else {
      final client = _client;
      if (client == null) {
        throw StateError(
          'Supabase client is required when no acquisition query or RPC caller is provided.',
        );
      }
      response = await client.rpc(
        'acquire_v3_legacy_discovery_item',
        params: params,
      );
    }
    return _requireAcquiredDiscoveryItemResponse(response, draft);
  }

  Future<Map<String, dynamic>> _runExamineItemQuery(Item item) async {
    final dynamic response;
    final caller = _examineItemRpcCaller;
    if (caller != null) {
      response = await caller('examine_v3_item', {'p_item_id': item.id});
    } else {
      final client = _client;
      if (client == null) {
        throw StateError(
          'Supabase client is required when no examination RPC caller is provided.',
        );
      }
      response = await client.rpc(
        'examine_v3_item',
        params: {'p_item_id': item.id},
      );
    }
    if (response is! Map) {
      throw StateError('Examination must return exactly one Item object.');
    }
    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>> _runIdentifyUnidentifiedFindQuery(
    Item item,
  ) async {
    if (_identifyUnidentifiedFindQuery != null) {
      return _identifyUnidentifiedFindQuery!(item);
    }
    throw StateError(
      'Direct Item Identification is unavailable; use the authoritative command.',
    );
  }

  Map<String, dynamic> _legacyAcquisitionRpcParams(
    DiscoveryItemDraft draft,
  ) =>
      {
        'p_definition_id': draft.definitionId,
        'p_acquired_in_cell_id': draft.acquiredInCellId,
        'p_map_cell_entry_id': draft.mapCellEntryId,
      };

  Map<String, dynamic> _requireAcquiredDiscoveryItemResponse(
    dynamic response,
    DiscoveryItemDraft draft,
  ) {
    if (response is! Map) {
      throw StateError(
        'Legacy discovery acquisition must return exactly one Item object.',
      );
    }
    final item = Map<String, dynamic>.from(response);
    if (item['acquired_in_cell_id'] != draft.acquiredInCellId ||
        !_hasNonBlankString(item['id']) ||
        !_hasNonBlankString(item['display_name']) ||
        !_hasNonBlankString(item['category']) ||
        item['identification_state'] != 'unidentified') {
      throw StateError(
        'Legacy discovery acquisition returned an invalid safe Item projection.',
      );
    }
    return item;
  }

  bool _hasNonBlankString(dynamic value) =>
      value is String && value.trim().isNotEmpty;
}

String _safeErrorMessage(Object error) => switch (error) {
      StateError() => 'invalid_repository_response',
      _ => 'repository_operation_failed',
    };
