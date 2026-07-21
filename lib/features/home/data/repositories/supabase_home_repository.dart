import 'package:earth_nova/features/home/data/dtos/home_dto.dart';
import 'package:earth_nova/features/home/domain/entities/home.dart';
import 'package:earth_nova/features/home/domain/repositories/home_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Injectable transport for the server-owned Home RPC surface.
typedef HomeRpcCaller = Future<Object?> Function(
  String functionName, {
  Map<String, Object?>? params,
});
typedef RepositoryLogEvent = void Function(
  String event,
  String category, {
  Map<String, dynamic>? data,
});

/// RPC-only adapter for durable Home reads.
///
/// `get_v3_home` derives the authenticated Player on the server. It must never
/// receive a client-supplied player identifier; the supplied identifier only
/// validates the returned ownership evidence.
final class SupabaseHomeRepository implements HomeRepository {
  static const _category = 'home.repository';

  SupabaseHomeRepository({
    required HomeRpcCaller rpc,
    RepositoryLogEvent? logEvent,
  })  : _rpc = rpc,
        _logEvent = logEvent;

  final HomeRpcCaller _rpc;
  final RepositoryLogEvent? _logEvent;

  factory SupabaseHomeRepository.fromSupabase(
    SupabaseClient client, {
    RepositoryLogEvent? logEvent,
  }) {
    return SupabaseHomeRepository(
      rpc: (functionName, {params}) => client.rpc(functionName, params: params),
      logEvent: logEvent,
    );
  }

  @override
  Future<Home> readHome(
    String playerId, {
    required String traceId,
  }) async {
    const operation = 'get_v3_home';
    final stopwatch = Stopwatch()..start();
    _logEvent?.call('db.rpc_started', _category, data: {
      'trace_id': traceId,
      'operation': operation,
    });
    try {
      HomeDto.validatePlayerId(playerId);
      final response = await _rpc(operation);
      final home = HomeDto.fromJson(response, playerId: playerId).toDomain();
      _logEvent?.call('db.rpc_completed', _category, data: {
        'trace_id': traceId,
        'operation': operation,
        'row_count': 1,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      return home;
    } on HomeFailure catch (error) {
      _logFailure(
        operation: operation,
        traceId: traceId,
        durationMs: stopwatch.elapsedMilliseconds,
        error: error,
      );
      rethrow;
    } catch (_) {
      const failure = HomeFailure.unavailable();
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
    required String traceId,
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
      HomeFailure(:final kind) => kind.name,
      _ => 'repository_operation_failed',
    };
