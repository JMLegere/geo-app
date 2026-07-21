import 'package:earth_nova/features/index/data/dtos/item_index_dto.dart';
import 'package:earth_nova/features/index/domain/entities/index_entry.dart';
import 'package:earth_nova/features/index/domain/repositories/item_index_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Injectable no-parameter RPC boundary for the frozen Item Index projection.
typedef ItemIndexRpcCaller = Future<Object?> Function(String functionName);
typedef RepositoryLogEvent = void Function(
  String event,
  String category, {
  Map<String, dynamic>? data,
});

/// Reads only the stable Base Item Index projection.
///
/// It deliberately does not accept a user id because `fetch_v3_item_index()`
/// derives the authenticated principal server-side. No Pack Item, current
/// Version, property value, or write operation is exposed here.
final class SupabaseItemIndexRepository implements ItemIndexRepository {
  static const _category = 'index.item_repository';

  SupabaseItemIndexRepository({
    required ItemIndexRpcCaller rpc,
    RepositoryLogEvent? logEvent,
  })  : _rpc = rpc,
        _logEvent = logEvent;

  final ItemIndexRpcCaller _rpc;
  final RepositoryLogEvent? _logEvent;

  factory SupabaseItemIndexRepository.fromSupabase(
    SupabaseClient client, {
    RepositoryLogEvent? logEvent,
  }) {
    return SupabaseItemIndexRepository(
      rpc: (functionName) => client.rpc(functionName),
      logEvent: logEvent,
    );
  }

  @override
  Future<List<IndexEntry>> fetchIndex({String? traceId}) async {
    const operation = 'fetch_v3_item_index';
    final stopwatch = Stopwatch()..start();
    _logEvent?.call('db.rpc_started', _category, data: {
      'trace_id': traceId,
      'operation': operation,
    });
    try {
      final response = await _rpc(operation);
      final index = ItemIndexDto.fromJson(response).toDomain();
      _logEvent?.call('db.rpc_completed', _category, data: {
        'trace_id': traceId,
        'operation': operation,
        'row_count': index.length,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      return index;
    } on ItemIndexFailure catch (error) {
      _logFailure(
        operation: operation,
        traceId: traceId,
        durationMs: stopwatch.elapsedMilliseconds,
        error: error,
      );
      rethrow;
    } catch (_) {
      const failure = ItemIndexFailure.unavailable();
      _logFailure(
        operation: operation,
        traceId: traceId,
        durationMs: stopwatch.elapsedMilliseconds,
        error: failure,
      );
      throw failure;
    }
  }

  void _logFailure({
    required String operation,
    required String? traceId,
    required int durationMs,
    required Object error,
  }) {
    _logEvent?.call('db.rpc_failed', _category, data: {
      'trace_id': traceId,
      'operation': operation,
      'duration_ms': durationMs,
      'error_type': error.runtimeType.toString(),
      'error_message': _safeErrorMessage(error),
    });
  }
}

String _safeErrorMessage(Object error) => switch (error) {
      ItemIndexFailure(:final kind) => kind.name,
      _ => 'repository_operation_failed',
    };
