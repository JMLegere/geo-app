import 'package:earth_nova/features/living_world/data/dtos/living_world_dto.dart';
import 'package:earth_nova/features/living_world/domain/entities/living_world_knowledge.dart';
import 'package:earth_nova/features/living_world/domain/entities/town_projection.dart';
import 'package:earth_nova/features/living_world/domain/repositories/living_world_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Injectable transport for the only Living World RPC surfaces.
typedef LivingWorldRpcCaller = Future<Object?> Function(
  String functionName, {
  Map<String, Object?>? params,
});
typedef RepositoryLogEvent = void Function(
  String event,
  String category, {
  Map<String, dynamic>? data,
});

/// RPC-only boundary for durable Town reads and Venue Visit commands.
///
/// `get_v3_town` derives the authenticated player on the server and therefore
/// receives no user parameter. The local player id is used only to validate
/// the returned projection's durable ownership evidence.
final class SupabaseLivingWorldRepository implements LivingWorldRepository {
  static const _category = 'living_world.repository';

  SupabaseLivingWorldRepository({
    required LivingWorldRpcCaller rpc,
    RepositoryLogEvent? logEvent,
  })  : _rpc = rpc,
        _logEvent = logEvent;

  final LivingWorldRpcCaller _rpc;
  final RepositoryLogEvent? _logEvent;

  factory SupabaseLivingWorldRepository.fromSupabase(
    SupabaseClient client, {
    RepositoryLogEvent? logEvent,
  }) {
    return SupabaseLivingWorldRepository(
      rpc: (functionName, {params}) => client.rpc(functionName, params: params),
      logEvent: logEvent,
    );
  }

  @override
  Future<TownProjection> readTown(
    String playerId, {
    required String traceId,
  }) async {
    const operation = 'get_v3_town';
    return _trace<TownProjection>(
      operation: operation,
      traceId: traceId,
      rowCount: (_) => 1,
      action: () async {
        try {
          LivingWorldTownDto.validatePlayerId(playerId);
          final response = await _rpc(operation);
          return LivingWorldTownDto.fromJson(response, playerId: playerId)
              .toDomain();
        } on LivingWorldFailure {
          rethrow;
        } catch (_) {
          throw const LivingWorldFailure.unavailable();
        }
      },
    );
  }

  @override
  Future<VenueVisitResult> recordVenueVisit(
    RecordVenueVisitCommand command, {
    required String traceId,
  }) async {
    const operation = 'record_v3_venue_visit';
    return _trace<VenueVisitResult>(
      operation: operation,
      traceId: traceId,
      rowCount: (_) => 1,
      action: () async {
        try {
          LivingWorldVenueVisitResultDto.validateCommand(command);
          final response = await _rpc(
            operation,
            params: {
              'p_cell_visit_id': command.cellVisit.id,
              'p_venue_id': command.venueId.value,
              'p_expected_venue_version_id':
                  command.venueVersion.versionId.value,
            },
          );
          return LivingWorldVenueVisitResultDto.fromJson(
            response,
            command: command,
          ).toDomain();
        } on LivingWorldFailure {
          rethrow;
        } catch (_) {
          throw const LivingWorldFailure.unavailable();
        }
      },
    );
  }

  Future<T> _trace<T>({
    required String operation,
    required String traceId,
    required int Function(T result) rowCount,
    required Future<T> Function() action,
  }) async {
    final stopwatch = Stopwatch()..start();
    _logEvent?.call('db.rpc_started', _category, data: {
      'trace_id': traceId,
      'operation': operation,
    });
    try {
      final result = await action();
      _logEvent?.call('db.rpc_completed', _category, data: {
        'trace_id': traceId,
        'operation': operation,
        'row_count': rowCount(result),
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      return result;
    } catch (error) {
      _logEvent?.call('db.rpc_failed', _category, data: {
        'trace_id': traceId,
        'operation': operation,
        'duration_ms': stopwatch.elapsedMilliseconds,
        'error_type': error.runtimeType.toString(),
        'error_message': _safeErrorMessage(error),
      });
      rethrow;
    }
  }
}

String _safeErrorMessage(Object error) => switch (error) {
      LivingWorldFailure(:final kind) => kind.name,
      _ => 'repository_operation_failed',
    };
