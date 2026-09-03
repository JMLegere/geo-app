import 'dart:async';

import 'package:earth_nova/features/identification/data/repositories/supabase_identification_repository.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/identification/domain/entities/identification_entities.dart';
import 'package:earth_nova/features/identification/domain/use_cases/plan_item_identification.dart';
import 'package:earth_nova/features/item_knowledge/domain/entities/item_knowledge_entities.dart';
import 'package:flutter_test/flutter_test.dart';

const _itemId = '11111111-1111-4111-8111-111111111111';
const _playerId = '22222222-2222-4222-8222-222222222222';
const _versionId = '33333333-3333-4333-8333-333333333333';
const _valueCandidateId = '44444444-4444-4444-8444-444444444444';
const _noneCandidateId = '55555555-5555-4555-8555-555555555555';
const _serviceVersionId = '66666666-6666-4666-8666-666666666666';
const _acquiredAt = '2026-07-20T12:00:00.000Z';
const _committedAt = '2026-07-20T12:01:00.000Z';

void main() {
  group('SupabaseIdentificationRepository', () {
    test('classifies commit timeouts for durable retry without provider text', () async {
      final plan = await _plan(await prepareFrom(preparationResponse()));
      final repository = SupabaseIdentificationRepository(
        client: null,
        rpcCaller: (_, __) async => throw TimeoutException('provider secret'),
      );

      await expectLater(
        repository.commit(plan),
        throwsA(
          isA<IdentificationCommitFailure>()
              .having((error) => error.kind, 'kind', IdentificationFailureKind.network)
              .having((error) => error.toString(), 'safe message', isNot(contains('secret'))),
        ),
      );
    });

    test('prepares only through the named RPC with exact params', () async {
      late String name;
      late Map<String, dynamic> params;
      final repository = SupabaseIdentificationRepository(
        client: null,
        rpcCaller: (functionName, requestParams) async {
          name = functionName;
          params = requestParams;
          return preparationResponse();
        },
      );

      final preparation = await repository.prepare(
        ItemKnowledgeItemId(_itemId),
        traceId: 'shared-identification-trace',
      );

      expect(name, 'prepare_v3_item_identification');
      expect(params, <String, dynamic>{'p_item_id': _itemId});
      expect(preparation.item.playerId, _playerId);
      expect(preparation.item.baseItemVersion.revision, 7);
      expect(preparation.playerDiscovered, isFalse);
      expect(
        preparation.serviceAccess.serviceId.value,
        'service:identify_item_properties',
      );
      expect(preparation.serviceAccess.serviceVersion.versionId.value,
          _serviceVersionId);
    });

    test('keeps prepare and commit repository telemetry on the caller trace',
        () async {
      final events = <Map<String, Object?>>[];
      late ItemIdentificationPlan plan;
      final repository = SupabaseIdentificationRepository(
        client: null,
        rpcCaller: (functionName, _) async => switch (functionName) {
          'prepare_v3_item_identification' => preparationResponse(),
          'identify_v3_item' => aggregateResponse(plan),
          _ => throw StateError('Unexpected RPC'),
        },
        logEvent: (event, category, {data}) =>
            events.add({'event': event, 'category': category, 'data': data}),
      );

      const traceId = 'one-identification-action';
      final preparation = await repository.prepare(
        ItemKnowledgeItemId(_itemId),
        traceId: traceId,
      );
      plan = await _plan(preparation);
      await repository.commit(plan, traceId: traceId);

      final rpcEvents = events
          .where((event) => (event['event'] as String).startsWith('db.rpc_'))
          .toList(growable: false);
      expect(rpcEvents, hasLength(4));
      for (final event in rpcEvents) {
        expect((event['data'] as Map)['trace_id'], traceId);
      }
    });

    test('emits RPC terminal telemetry with safe failure diagnostics',
        () async {
      final events = <Map<String, Object?>>[];
      final success = SupabaseIdentificationRepository(
        client: null,
        rpcCaller: (_, __) async => preparationResponse(),
        logEvent: (event, category, {data}) =>
            events.add({'event': event, 'category': category, 'data': data}),
      );

      await success.prepare(
        ItemKnowledgeItemId(_itemId),
        traceId: 'shared-identification-trace',
      );
      expect(events.map((event) => event['event']), [
        'db.rpc_started',
        'db.rpc_completed',
      ]);
      expect((events.last['data'] as Map)['operation'],
          'prepare_v3_item_identification');
      expect((events.last['data'] as Map)['duration_ms'], isA<int>());

      expect(
        (events.last['data'] as Map)['trace_id'],
        'shared-identification-trace',
      );
      final failure = SupabaseIdentificationRepository(
        client: null,
        rpcCaller: (_, __) async => throw StateError('backend secret'),
        logEvent: (event, category, {data}) =>
            events.add({'event': event, 'category': category, 'data': data}),
      );
      await expectLater(
        failure.prepare(ItemKnowledgeItemId(_itemId)),
        throwsStateError,
      );
      expect(events.last['event'], 'db.rpc_failed');
      expect((events.last['data'] as Map)['error_message'],
          'repository_operation_failed');
    });
    test(
        'rejects malformed preparation keys, unexamined Items, and missing service access',
        () async {
      final missingService = preparationResponse()..remove('service_access');
      for (final response in <Map<String, dynamic>>[
        preparationResponse()..['extra'] = true,
        preparationResponse(itemId: 'not-a-uuid'),
        preparationResponse(state: 'identified'),
        preparationResponse(state: 'unexamined'),
        preparationResponse(
            discovery: true, discoveredAt: '2026-07-20T12:00:00'),
        missingService,
      ]) {
        final repository = SupabaseIdentificationRepository(
          client: null,
          rpcCaller: (_, __) async => response,
        );
        expect(
          () => repository.prepare(ItemKnowledgeItemId(_itemId)),
          throwsStateError,
        );
      }
    });

    test('rejects foreign discovery and server candidate disagreement',
        () async {
      final foreignDiscovery = preparationResponse(discovery: true);
      (foreignDiscovery['discovery'] as Map<String, dynamic>)['user_id'] =
          '66666666-6666-4666-8666-666666666666';
      final wrongCandidate =
          preparationResponse(selectedCandidateId: _noneCandidateId);

      for (final response in [foreignDiscovery, wrongCandidate]) {
        final repository = SupabaseIdentificationRepository(
          client: null,
          rpcCaller: (_, __) async => response,
        );
        expect(
          () => repository.prepare(ItemKnowledgeItemId(_itemId)),
          throwsStateError,
        );
      }
    });

    test('retains explicit None and agrees with the deterministic planner',
        () async {
      final preparationJson = preparationResponse(
        candidates: [
          candidate(
            id: _noneCandidateId,
            ordinal: 0,
            resultKind: 'none',
            resultId: null,
          ),
        ],
        selectedCandidateId: _noneCandidateId,
      );
      final repository = SupabaseIdentificationRepository(
        client: null,
        rpcCaller: (_, __) async => preparationJson,
      );

      final plan = await _plan(await repository.prepare(
        ItemKnowledgeItemId(_itemId),
      ));

      expect(plan.propertyResolutions.single.selectorCandidateId.value,
          _noneCandidateId);
      expect(
          plan.propertyResolutions.single.resolution, isA<NoPropertyValue>());
    });

    test('commits only the retained exact plan and parses its full aggregate',
        () async {
      late String name;
      late Map<String, dynamic> params;
      final plan = await _plan(await prepareFrom(preparationResponse()));
      final repository = SupabaseIdentificationRepository(
        client: null,
        rpcCaller: (functionName, requestParams) async {
          name = functionName;
          params = requestParams;
          return aggregateResponse(plan);
        },
      );

      final result = await repository.commit(plan, traceId: 'not-a-wire-param');

      expect(name, 'identify_v3_item');
      expect(params.keys, <String>[
        'p_item_id',
        'p_expected_base_item_id',
        'p_expected_base_item_version_id',
        'p_expected_service_id',
        'p_expected_service_version_id',
        'p_expected_villager_id',
        'p_property_resolutions',
      ]);
      expect(params['p_item_id'], _itemId);
      expect(params['p_expected_base_item_id'], 'base-item-1');
      expect(params['p_expected_base_item_version_id'], _versionId);
      expect(
        params['p_expected_service_id'],
        'service:identify_item_properties',
      );
      expect(params['p_expected_service_version_id'], _serviceVersionId);
      expect(params['p_expected_villager_id'], 'villager:rowan');
      expect(params['p_property_resolutions'], [
        <String, dynamic>{
          'ordinal': 0,
          'variable_property_key': 'property-1',
          'selector_id': 'selector-1',
          'selector_candidate_id': _valueCandidateId,
        },
      ]);
      expect(result.item, plan.item);
      expect(result.committedItem.id, _itemId);
      expect(result.propertyValues, hasLength(1));
      expect(
        result.propertyValues.single.resolution,
        isA<SelectedPropertyValue>(),
      );
    });

    test('accepts empty explicit plans and serializes an empty plan exactly',
        () async {
      final preparation =
          await prepareFrom(preparationResponse(properties: const []));
      final plan = ItemIdentificationPlan(
        item: preparation.item,
        propertyResolutions: const [],
        serviceAccess: preparation.serviceAccess,
      );
      late Map<String, dynamic> params;
      final repository = SupabaseIdentificationRepository(
        client: null,
        rpcCaller: (_, requestParams) async {
          params = requestParams;
          return aggregateResponse(plan);
        },
      );

      final result = await repository.commit(plan);

      expect(params['p_property_resolutions'], isEmpty);
      expect(result.propertyValues, isEmpty);
    });

    test('retries the retained service contract without exposing conflicts',
        () async {
      final plan = await _plan(await prepareFrom(preparationResponse()));
      final requests = <Map<String, dynamic>>[];
      final success = SupabaseIdentificationRepository(
        client: null,
        rpcCaller: (_, params) async {
          requests.add(params);
          return aggregateResponse(plan);
        },
      );

      final completed = await success.commit(plan);
      final conflict = SupabaseIdentificationRepository(
        client: null,
        rpcCaller: (_, params) async {
          requests.add(params);
          throw StateError('service changed conflict secret');
        },
      );

      await expectLater(conflict.commit(plan), throwsStateError);
      expect(requests, hasLength(2));
      for (final params in requests) {
        expect(params['p_expected_service_id'],
            'service:identify_item_properties');
        expect(params['p_expected_service_version_id'], _serviceVersionId);
        expect(params['p_expected_villager_id'], 'villager:rowan');
      }
      expect(completed.committedItem.id, _itemId);
      expect(completed.propertyValues, hasLength(1));
    });

    test('rejects aggregate owner and exact Version mismatches', () async {
      final plan = await _plan(await prepareFrom(preparationResponse()));
      final ownerMismatch = aggregateResponse(plan);
      (ownerMismatch['item'] as Map<String, dynamic>)['user_id'] =
          '66666666-6666-4666-8666-666666666666';
      final versionMismatch = aggregateResponse(plan);
      (versionMismatch['item']
              as Map<String, dynamic>)['base_item_version_id'] =
          '77777777-7777-4777-8777-777777777777';

      for (final response in [ownerMismatch, versionMismatch]) {
        final repository = SupabaseIdentificationRepository(
          client: null,
          rpcCaller: (_, __) async => response,
        );
        expect(() => repository.commit(plan), throwsStateError);
      }
    });

    test(
        'rejects changed plan echoes and replay-conflict backend failures safely',
        () async {
      final plan = await _plan(await prepareFrom(preparationResponse()));
      final changedPlan = aggregateResponse(plan);
      ((changedPlan['property_values'] as List).single
          as Map<String, dynamic>)['selector_candidate_id'] = _noneCandidateId;
      final changedRepository = SupabaseIdentificationRepository(
        client: null,
        rpcCaller: (_, __) async => changedPlan,
      );
      expect(() => changedRepository.commit(plan), throwsStateError);

      final failingRepository = SupabaseIdentificationRepository(
        client: null,
        rpcCaller: (_, __) async =>
            throw StateError('immutable receipt replay secret'),
      );
      await expectLater(
        failingRepository.commit(plan),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            isNot(contains('secret')),
          ),
        ),
      );
    });

    test('rejects malformed full Item binding and aggregate receipt/discovery',
        () async {
      final plan = await _plan(await prepareFrom(preparationResponse()));
      final malformedItem = aggregateResponse(plan);
      (malformedItem['item'] as Map<String, dynamic>)['habitats_json'] = '{}';
      final malformedReceipt = aggregateResponse(plan);
      (malformedReceipt['identification'] as Map<String, dynamic>)['kind'] =
          'automatic';
      final malformedDiscovery = aggregateResponse(plan);
      (malformedDiscovery['discovery']
          as Map<String, dynamic>)['discovered_at'] = 'not-a-time';

      for (final response in [
        malformedItem,
        malformedReceipt,
        malformedDiscovery
      ]) {
        final repository = SupabaseIdentificationRepository(
          client: null,
          rpcCaller: (_, __) async => response,
        );
        expect(() => repository.commit(plan), throwsStateError);
      }
    });
  });
}

Future<IdentificationPreparation> prepareFrom(Map<String, dynamic> response) =>
    SupabaseIdentificationRepository(
      client: null,
      rpcCaller: (_, __) async => response,
    ).prepare(ItemKnowledgeItemId(_itemId));

Future<ItemIdentificationPlan> _plan(
  IdentificationPreparation preparation,
) =>
    PlanItemIdentification(
      ObservabilityService(sessionId: 'identification-repository-test'),
    ).execute(preparation, 'identification-repository-test-trace');
Map<String, dynamic> preparationResponse({
  String itemId = _itemId,
  String state = 'unidentified',
  bool discovery = false,
  String? discoveredAt,
  List<Map<String, dynamic>>? candidates,
  String selectedCandidateId = _valueCandidateId,
  List<Map<String, dynamic>>? properties,
}) =>
    <String, dynamic>{
      'item': <String, dynamic>{
        'id': itemId,
        'user_id': _playerId,
        'base_item_id': 'base-item-1',
        'base_item_version_id': _versionId,
        'base_item_revision': 7,
        'identification_state': state,
      },
      'service_access': <String, dynamic>{
        'villager_id': 'villager:rowan',
        'villager_display_name': 'Rowan',
        'service_id': 'service:identify_item_properties',
        'service_version_id': _serviceVersionId,
        'service_version_revision': 2,
        'service_display_name': 'Identification',
      },
      'discovery': discovery
          ? <String, dynamic>{
              'user_id': _playerId,
              'base_item_id': 'base-item-1',
              'first_identified_item_id': _itemId,
              'first_base_item_version_id': _versionId,
              'provenance': 'explicit_identification',
              'discovered_at': discoveredAt ?? _committedAt,
            }
          : null,
      'properties': properties ??
          [
            <String, dynamic>{
              'ordinal': 0,
              'variable_property_key': 'property-1',
              'display_name': 'Property one',
              'selector_id': 'selector-1',
              'candidates': candidates ??
                  [
                    candidate(
                      id: _valueCandidateId,
                      ordinal: 0,
                      resultKind: 'value',
                      resultId: 'value-1',
                    ),
                  ],
              'selected_candidate_id': selectedCandidateId,
            },
          ],
    };

Map<String, dynamic> candidate({
  required String id,
  required int ordinal,
  required String resultKind,
  required Object? resultId,
  double weight = 1,
}) =>
    <String, dynamic>{
      'id': id,
      'ordinal': ordinal,
      'weight': weight,
      'result_kind': resultKind,
      'result_id': resultId,
    };

Map<String, dynamic> aggregateResponse(ItemIdentificationPlan plan) =>
    <String, dynamic>{
      'item': <String, dynamic>{
        'id': _itemId,
        'user_id': _playerId,
        'definition_id': 'definition-1',
        'display_name': 'Identified specimen',
        'scientific_name': null,
        'category': 'fauna',
        'rarity': null,
        'icon_url': null,
        'icon_url_frame2': null,
        'art_url': null,
        'acquired_at': _acquiredAt,
        'acquired_in_cell_id': null,
        'status': 'active',
        'taxonomic_class': null,
        'habitats_json': '[]',
        'continents_json': '[]',
        'identification_state': 'identified',
        'identified_at': _committedAt,
        'base_item_id': 'base-item-1',
        'base_item_version_id': _versionId,
        'base_item_revision': 7,
      },
      'discovery': <String, dynamic>{
        'user_id': _playerId,
        'base_item_id': 'base-item-1',
        'first_identified_item_id': _itemId,
        'first_base_item_version_id': _versionId,
        'provenance': 'explicit_identification',
        'discovered_at': _committedAt,
      },
      'property_values': [
        for (final resolution in plan.propertyResolutions)
          <String, dynamic>{
            'ordinal': resolution.ordinal,
            'variable_property_key': resolution.definition.id.value,
            'selector_id': resolution.definition.selectorId.value,
            'selector_candidate_id': resolution.selectorCandidateId.value,
            'resolution_kind': switch (resolution.resolution) {
              SelectedPropertyValue() => 'value',
              NoPropertyValue() => 'none',
            },
            'resolved_value_id': switch (resolution.resolution) {
              SelectedPropertyValue(:final valueId) => valueId,
              NoPropertyValue() => null,
            },
            'resolved_at': _committedAt,
          },
      ],
      'identification': <String, dynamic>{
        'kind': 'explicit',
        'committed_at': _committedAt,
      },
    };
