import 'package:earth_nova/features/encounters/data/dtos/encounter_runtime_aggregate_dto.dart';
import 'package:earth_nova/features/encounters/domain/entities/encounter_entities.dart';
import 'package:earth_nova/features/encounters/domain/repositories/encounter_repository.dart';
import 'package:earth_nova/features/encounters/domain/use_cases/resolve_cell_visit_encounter_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Injectable RPC seam that keeps command-adapter tests independent of
/// [SupabaseClient] and makes the two allowed database effects explicit.
typedef EncounterRpcGateway = Future<Object?> Function(
  String functionName,
  Map<String, Object?> parameters,
);
typedef RepositoryLogEvent = void Function(
  String event,
  String category, {
  Map<String, dynamic>? data,
});

/// Supabase implementation of the two transactional Encounter command RPCs.
///
/// It deliberately exposes no table mutation API: all ownership, locking,
/// idempotency, and commits remain in the security-definer RPC boundary.
final class SupabaseEncounterRepository implements EncounterRepository {
  static const _category = 'encounters.repository';

  SupabaseEncounterRepository({
    required EncounterRpcGateway rpcGateway,
    RepositoryLogEvent? logEvent,
  })  : _rpcGateway = rpcGateway,
        _logEvent = logEvent;

  factory SupabaseEncounterRepository.fromSupabase(
    SupabaseClient client, {
    RepositoryLogEvent? logEvent,
  }) =>
      SupabaseEncounterRepository(
        rpcGateway: (functionName, parameters) async {
          final Object? response = await client.rpc(
            functionName,
            params: parameters,
          );
          return response;
        },
        logEvent: logEvent,
      );

  final EncounterRpcGateway _rpcGateway;
  final RepositoryLogEvent? _logEvent;

  @override
  Future<EncounterRuntimeAggregate> commitCellVisitSelection(
    CellVisitEncounterSelectionPlan plan, {
    required String traceId,
  }) async {
    final expectedVersionId = switch (plan) {
      NoEncounterCellVisitPlan() => null,
      EncounterSelectedCellVisitPlan(:final definitionVersion) =>
        definitionVersion.versionId.value,
    };
    final aggregate = await _callAggregate(
      'resolve_v3_cell_visit_encounter',
      <String, Object?>{
        'p_cell_visit_id': plan.cellVisit.id,
        'p_selector_id': plan.selectorId.value,
        'p_selector_candidate_id': plan.selectorCandidateId.value,
        'p_expected_encounter_definition_version_id': expectedVersionId,
      },
      traceId: traceId,
    );
    _validateSelectionResponse(plan, aggregate);
    return aggregate;
  }

  @override
  Future<EncounterRuntimeAggregate> resolveEncounterOutcomes(
    EncounterId encounterId, {
    required String traceId,
    EncounterOptionId? selectedOptionId,
  }) async {
    final aggregate = await _callAggregate(
      'resolve_v3_encounter_outcomes',
      <String, Object?>{
        'p_encounter_id': encounterId.value,
        'p_selected_option_id': selectedOptionId?.value,
      },
      traceId: traceId,
    );
    final encounter = aggregate.encounter;
    if (encounter == null || encounter.id != encounterId) {
      throw const EncounterStalePlanFailure('returned_encounter_mismatch');
    }
    if (encounter.status == EncounterResolutionStatus.pending) {
      throw const EncounterMalformedResponseFailure(
          'outcome_command_left_pending');
    }
    if (selectedOptionId != null &&
        encounter.selectedOptionId != selectedOptionId) {
      throw const EncounterRetryInputConflictFailure(
          'returned_option_mismatch');
    }
    return aggregate;
  }

  Future<EncounterRuntimeAggregate> _callAggregate(
    String functionName,
    Map<String, Object?> parameters, {
    required String traceId,
  }) async {
    final stopwatch = Stopwatch()..start();
    _logEvent?.call('db.rpc_started', _category, data: {
      'trace_id': traceId,
      'operation': functionName,
    });
    try {
      final response = await _rpcGateway(functionName, parameters);
      final aggregate =
          EncounterRuntimeAggregateDto.fromJson(response).toDomain();
      _logEvent?.call('db.rpc_completed', _category, data: {
        'trace_id': traceId,
        'operation': functionName,
        'row_count': 1,
        'duration_ms': stopwatch.elapsedMilliseconds,
      });
      return aggregate;
    } catch (error) {
      final failure = _safeFailure(error);
      _logEvent?.call('db.rpc_failed', _category, data: {
        'trace_id': traceId,
        'operation': functionName,
        'duration_ms': stopwatch.elapsedMilliseconds,
        'error_type': failure.runtimeType.toString(),
        'error_message': failure.diagnosticCode,
      });
      throw failure;
    }
  }

  void _validateSelectionResponse(
    CellVisitEncounterSelectionPlan plan,
    EncounterRuntimeAggregate aggregate,
  ) {
    final resolution = aggregate.cellVisitResolution;
    if (resolution.cellVisitId.value != plan.cellVisit.id ||
        resolution.selectorId != plan.selectorId ||
        resolution.selectorCandidateId != plan.selectorCandidateId) {
      throw const EncounterStalePlanFailure('returned_selection_mismatch');
    }

    switch (plan) {
      case NoEncounterCellVisitPlan():
        if (resolution.result is! NoEncounterDefinitionSelection ||
            aggregate.encounter != null) {
          throw const EncounterStalePlanFailure('returned_none_mismatch');
        }
        break;
      case EncounterSelectedCellVisitPlan(
          :final definitionId,
          :final definitionVersion,
        ):
        final resolutionResult = resolution.result;
        final encounter = aggregate.encounter;
        if (resolutionResult is! EncounterDefinitionSelection ||
            resolutionResult.definitionId != definitionId ||
            encounter == null ||
            encounter.definitionVersion != definitionVersion) {
          throw const EncounterStalePlanFailure('returned_version_mismatch');
        }
        break;
    }
  }
}

EncounterRepositoryFailure _safeFailure(Object error) => switch (error) {
      EncounterRepositoryFailure() => error,
      StateError() ||
      ArgumentError() ||
      FormatException() =>
        const EncounterMalformedResponseFailure('invalid_rpc_aggregate'),
      PostgrestException() => _mapPostgrestFailure(error),
      _ => const EncounterTransportFailure('transport_unexpected'),
    };

EncounterRepositoryFailure _mapPostgrestFailure(PostgrestException error) {
  final code = _safeDiagnosticCode(error.code);
  return switch (error.code) {
    '28000' || '42501' => EncounterAuthenticationOrOwnershipFailure(code),
    '40001' => EncounterStalePlanFailure(code),
    'P0001' => EncounterRetryInputConflictFailure(code),
    _ => EncounterDomainFailure(code),
  };
}

String _safeDiagnosticCode(String? code) {
  if (code != null && RegExp(r'^[A-Za-z0-9]{1,16}$').hasMatch(code)) {
    return 'sqlstate_$code';
  }
  return 'sqlstate_unknown';
}
