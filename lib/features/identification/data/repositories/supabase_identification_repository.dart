import 'package:earth_nova/features/identification/data/dtos/identification_aggregate_dto.dart';
import 'package:earth_nova/features/identification/data/dtos/identification_preparation_dto.dart';
import 'package:earth_nova/features/identification/domain/entities/identification_entities.dart';
import 'package:earth_nova/features/identification/domain/repositories/identification_repository.dart';
import 'package:earth_nova/features/item_knowledge/domain/entities/item_knowledge_entities.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Injectable RPC transport used by [SupabaseIdentificationRepository].
typedef IdentificationRpcCaller = Future<dynamic> Function(
  String functionName,
  Map<String, dynamic> params,
);
typedef RepositoryLogEvent = void Function(
  String event,
  String category, {
  Map<String, dynamic>? data,
});

/// RPC-only authoritative boundary for Item Identification commands.
final class SupabaseIdentificationRepository
    implements IdentificationRepository {
  static const _category = 'identification.repository';

  SupabaseIdentificationRepository({
    required SupabaseClient? client,
    IdentificationRpcCaller? rpcCaller,
    RepositoryLogEvent? logEvent,
  })  : _client = client,
        _rpcCaller = rpcCaller,
        _logEvent = logEvent;

  final SupabaseClient? _client;
  final IdentificationRpcCaller? _rpcCaller;
  final RepositoryLogEvent? _logEvent;

  @override
  Future<IdentificationPreparation> prepare(
    ItemKnowledgeItemId itemId, {
    String? traceId,
  }) async {
    const operation = 'prepare_v3_item_identification';
    return _trace<IdentificationPreparation>(
      operation: operation,
      traceId: traceId,
      action: () async {
        try {
          final response = await _rpc(
            operation,
            <String, dynamic>{'p_item_id': itemId.value},
          );
          return IdentificationPreparationDto.fromJson(
            _responseObject(response),
          ).toDomain();
        } catch (_) {
          throw StateError('Item Identification preparation failed.');
        }
      },
    );
  }

  @override
  Future<ItemIdentificationResult> commit(
    ItemIdentificationPlan plan, {
    String? traceId,
  }) async {
    const operation = 'identify_v3_item';
    return _trace<ItemIdentificationResult>(
      operation: operation,
      traceId: traceId,
      action: () async {
        try {
          final response = await _rpc(
            operation,
            <String, dynamic>{
              'p_item_id': plan.item.id.value,
              'p_expected_base_item_id': plan.item.baseItemId.value,
              'p_expected_base_item_version_id':
                  plan.item.baseItemVersion.versionId.value,
              'p_expected_service_id': plan.serviceAccess.serviceId.value,
              'p_expected_service_version_id':
                  plan.serviceAccess.serviceVersion.versionId.value,
              'p_expected_villager_id': plan.serviceAccess.villagerId.value,
              'p_property_resolutions': _serializePlan(plan),
            },
          );
          return IdentificationAggregateDto.fromJson(
            _responseObject(response),
            plan: plan,
          ).toDomain();
        } catch (_) {
          throw StateError('Item Identification commit failed.');
        }
      },
    );
  }

  Future<dynamic> _rpc(String functionName, Map<String, dynamic> params) {
    final caller = _rpcCaller;
    if (caller != null) return caller(functionName, params);
    final client = _client;
    if (client == null) {
      throw StateError('Item Identification RPC transport is unavailable.');
    }
    return client.rpc(functionName, params: params);
  }

  Future<T> _trace<T>({
    required String operation,
    required String? traceId,
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
        'row_count': 1,
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

Map<String, dynamic> _responseObject(dynamic response) {
  if (response is! Map) {
    throw StateError('Invalid Item Identification response.');
  }
  final result = <String, dynamic>{};
  for (final entry in response.entries) {
    if (entry.key is! String) {
      throw StateError('Invalid Item Identification response.');
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

List<Map<String, dynamic>> _serializePlan(ItemIdentificationPlan plan) =>
    List<Map<String, dynamic>>.unmodifiable([
      for (final resolution in plan.propertyResolutions)
        <String, dynamic>{
          'ordinal': resolution.ordinal,
          'variable_property_key': resolution.definition.id.value,
          'selector_id': resolution.definition.selectorId.value,
          'selector_candidate_id': resolution.selectorCandidateId.value,
        },
    ]);

String _safeErrorMessage(Object error) => switch (error) {
      StateError() => 'repository_operation_failed',
      _ => 'repository_operation_failed',
    };
