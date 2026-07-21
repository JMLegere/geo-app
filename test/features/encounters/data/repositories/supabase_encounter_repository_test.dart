import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/domain/content/encounter_content.dart';
import 'package:earth_nova/features/encounters/data/repositories/supabase_encounter_repository.dart';
import 'package:earth_nova/features/encounters/domain/entities/encounter_entities.dart';
import 'package:earth_nova/features/encounters/domain/repositories/encounter_repository.dart';
import 'package:earth_nova/features/encounters/domain/use_cases/resolve_cell_visit_encounter_selector.dart';
import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupabaseEncounterRepository', () {
    test('commits explicit None with a null expected Version', () async {
      final fake = _FakeRpcGateway(_noneAggregate());
      final repository = SupabaseEncounterRepository(rpcGateway: fake.call);

      final aggregate = await repository.commitCellVisitSelection(_nonePlan(),
          traceId: _traceId);

      expect(aggregate.encounter, isNull);
      expect(fake.calls, hasLength(1));
      expect(fake.calls.single.functionName, 'resolve_v3_cell_visit_encounter');
      expect(
        fake.calls.single.parameters,
        <String, Object?>{
          'p_cell_visit_id': _visitId,
          'p_selector_id': _selectorId,
          'p_selector_candidate_id': _candidateId,
          'p_expected_encounter_definition_version_id': null,
        },
      );
    });

    test('commits a selected plan with its exact Version id', () async {
      final fake = _FakeRpcGateway(_selectedAggregate());
      final repository = SupabaseEncounterRepository(rpcGateway: fake.call);

      await repository.commitCellVisitSelection(_selectedPlan(),
          traceId: _traceId);

      expect(
        fake.calls.single
            .parameters['p_expected_encounter_definition_version_id'],
        _encounterVersionId,
      );
    });

    test('keeps caller trace equality in repository telemetry, not RPC payload',
        () async {
      final events = <Map<String, Object?>>[];
      final repository = SupabaseEncounterRepository(
        rpcGateway: _FakeRpcGateway(_selectedAggregate()).call,
        logEvent: (event, category, {data}) =>
            events.add({'event': event, 'category': category, 'data': data}),
      );

      await repository.commitCellVisitSelection(
        _selectedPlan(),
        traceId: _traceId,
      );
      await repository.resolveEncounterOutcomes(
        EncounterId(_encounterId),
        traceId: _traceId,
      );

      expect(events, hasLength(4));
      expect(
        events.map((event) => (event['data'] as Map)['trace_id']),
        everyElement(_traceId),
      );
    });
    test('sends null Option for automatic Outcome resolution', () async {
      final fake = _FakeRpcGateway(_selectedAggregate());
      final repository = SupabaseEncounterRepository(rpcGateway: fake.call);

      await repository.resolveEncounterOutcomes(EncounterId(_encounterId),
          traceId: _traceId);

      expect(fake.calls.single.functionName, 'resolve_v3_encounter_outcomes');
      expect(
        fake.calls.single.parameters,
        <String, Object?>{
          'p_encounter_id': _encounterId,
          'p_selected_option_id': null,
        },
      );
    });

    test('sends an explicit Option for manual Outcome resolution', () async {
      final fake = _FakeRpcGateway(_selectedAggregate());
      final repository = SupabaseEncounterRepository(rpcGateway: fake.call);

      await repository.resolveEncounterOutcomes(
        EncounterId(_encounterId),
        traceId: _traceId,
        selectedOptionId: EncounterOptionId(_optionId),
      );

      expect(fake.calls.single.parameters['p_selected_option_id'], _optionId);
    });

    test('rejects a selected response with a stale candidate', () async {
      final fake =
          _FakeRpcGateway(_selectedAggregate(candidateId: _otherCandidateId));
      final repository = SupabaseEncounterRepository(rpcGateway: fake.call);

      await expectLater(
        repository.commitCellVisitSelection(_selectedPlan(), traceId: _traceId),
        throwsA(isA<EncounterStalePlanFailure>()),
      );
    });

    test('fails closed when an RPC payload is malformed', () async {
      final fake = _FakeRpcGateway(<String, Object?>{
        'cell_visit_resolution': null,
        'encounter': null,
        'outcome_results': <Object?>[],
        'generated_items': <Object?>[],
      });
      final repository = SupabaseEncounterRepository(rpcGateway: fake.call);

      await expectLater(
        repository.commitCellVisitSelection(_nonePlan(), traceId: _traceId),
        throwsA(isA<EncounterMalformedResponseFailure>()),
      );
    });
    test('returns typed first-known Reveal Venue evidence', () async {
      final repository = SupabaseEncounterRepository(
        rpcGateway: _FakeRpcGateway(_revealAggregate()).call,
      );

      final aggregate = await repository.resolveEncounterOutcomes(
          EncounterId(_encounterId),
          traceId: _traceId);

      expect(aggregate.generatedItemCommits, isEmpty);
      expect(aggregate.revealedVenueCommits, hasLength(1));
      expect(
        aggregate.revealedVenueCommits.single.venueId.value,
        _venueId,
      );
    });

    test('fails closed for malformed Reveal Venue evidence', () async {
      final response = _revealAggregate();
      final outcome = (response['outcome_results']! as List<Object?>).single
          as Map<String, Object?>;
      outcome['known_at'] = null;
      final repository = SupabaseEncounterRepository(
        rpcGateway: _FakeRpcGateway(response).call,
      );

      await expectLater(
        repository.resolveEncounterOutcomes(EncounterId(_encounterId),
            traceId: _traceId),
        throwsA(isA<EncounterMalformedResponseFailure>()),
      );
    });

    test('maps PostgREST command failures to safe typed terminal failures',
        () async {
      const secret = 'raw-backend-message-that-must-not-be-logged';
      final cases = <({String code, Matcher matcher, String diagnostic})>[
        (
          code: '42501',
          matcher: isA<EncounterAuthenticationOrOwnershipFailure>(),
          diagnostic: 'sqlstate_42501',
        ),
        (
          code: '40001',
          matcher: isA<EncounterStalePlanFailure>(),
          diagnostic: 'sqlstate_40001',
        ),
        (
          code: 'P0001',
          matcher: isA<EncounterRetryInputConflictFailure>(),
          diagnostic: 'sqlstate_P0001',
        ),
        (
          code: 'invalid code with spaces',
          matcher: isA<EncounterDomainFailure>(),
          diagnostic: 'sqlstate_unknown',
        ),
      ];

      for (final testCase in cases) {
        final events = <Map<String, Object?>>[];
        final repository = SupabaseEncounterRepository(
          rpcGateway: (_, __) async => throw supabase.PostgrestException(
            message: secret,
            code: testCase.code,
          ),
          logEvent: (event, category, {data}) => events.add({
            'event': event,
            'category': category,
            'data': data,
          }),
        );

        await expectLater(
          repository.commitCellVisitSelection(_selectedPlan(),
              traceId: _traceId),
          throwsA(testCase.matcher),
        );

        final failure = events.singleWhere(
          (event) => event['event'] == 'db.rpc_failed',
        );
        final data = failure['data']! as Map<String, dynamic>;
        expect(data['error_message'], testCase.diagnostic);
        expect(data.values, isNot(contains(secret)));
      }
    });

    test('keeps malformed and unexpected RPC errors terminal and redacted',
        () async {
      const secret = 'untrusted-network-detail';
      final events = <Map<String, Object?>>[];
      final repository = SupabaseEncounterRepository(
        rpcGateway: (_, __) async => throw Exception(secret),
        logEvent: (event, category, {data}) => events.add({
          'event': event,
          'category': category,
          'data': data,
        }),
      );

      await expectLater(
        repository.commitCellVisitSelection(_selectedPlan(), traceId: _traceId),
        throwsA(
          isA<EncounterTransportFailure>().having(
            (EncounterTransportFailure failure) => failure.diagnosticCode,
            'safe diagnostic code',
            'transport_unexpected',
          ),
        ),
      );

      final data = events.singleWhere(
        (event) => event['event'] == 'db.rpc_failed',
      )['data']! as Map<String, dynamic>;
      expect(data['error_message'], 'transport_unexpected');
      expect(data.values, isNot(contains(secret)));
    });

    test('rejects pending and retry-conflicting terminal outcome responses',
        () async {
      final pending = _selectedAggregate();
      final pendingEncounter = pending['encounter']! as Map<String, Object?>;
      pendingEncounter
        ..['resolution_status'] = 'pending'
        ..['selected_option_id'] = null
        ..['resolved_at'] = null;
      pending['outcome_results'] = <Object?>[];
      pending['generated_items'] = <Object?>[];

      final conflictingOption = _selectedAggregate();
      final resolvedEncounter =
          conflictingOption['encounter']! as Map<String, Object?>;
      resolvedEncounter['selected_option_id'] = _otherCandidateId;

      await expectLater(
        SupabaseEncounterRepository(rpcGateway: _FakeRpcGateway(pending).call)
            .resolveEncounterOutcomes(
          EncounterId(_encounterId),
          traceId: _traceId,
        ),
        throwsA(isA<EncounterMalformedResponseFailure>()),
      );
      await expectLater(
        SupabaseEncounterRepository(
          rpcGateway: _FakeRpcGateway(conflictingOption).call,
        ).resolveEncounterOutcomes(
          EncounterId(_encounterId),
          traceId: _traceId,
          selectedOptionId: EncounterOptionId(_optionId),
        ),
        throwsA(isA<EncounterRetryInputConflictFailure>()),
      );
    });
  });
}

const _traceId = '0123456789abcdef0123456789abcdef';
const _resolutionId = '00000000-0000-4000-8000-000000000001';
const _visitId = '00000000-0000-4000-8000-000000000002';
const _candidateId = '00000000-0000-4000-8000-000000000003';
const _otherCandidateId = '00000000-0000-4000-8000-000000000013';
const _encounterId = '00000000-0000-4000-8000-000000000004';
const _encounterVersionId = '00000000-0000-4000-8000-000000000005';
const _optionId = '00000000-0000-4000-8000-000000000006';
const _resultId = '00000000-0000-4000-8000-000000000007';
const _outcomeId = '00000000-0000-4000-8000-000000000008';
const _baseVersionId = '00000000-0000-4000-8000-000000000009';
const _itemId = '00000000-0000-4000-8000-000000000010';
const _userId = '00000000-0000-4000-8000-000000000012';
const _selectorId = 'selector:legacy-cell-encounter';
const _venueId = 'venue:shoreline-observatory';
const _venueVersionId = '00000000-0000-4000-8000-000000000014';
const _revealResultId = '00000000-0000-4000-8000-000000000015';
const _revealOutcomeId = '00000000-0000-4000-8000-000000000016';

NoEncounterCellVisitPlan _nonePlan() => NoEncounterCellVisitPlan(
      cellVisit: _cellVisit(),
      selectorId: SelectorId(_selectorId),
      selectorCandidateId: SelectorCandidateId(_candidateId),
    );

EncounterSelectedCellVisitPlan _selectedPlan() =>
    EncounterSelectedCellVisitPlan(
      cellVisit: _cellVisit(),
      selectorId: SelectorId(_selectorId),
      selectorCandidateId: SelectorCandidateId(_candidateId),
      definitionId: StableContentId<EncounterContent>('encounter:amberwing'),
      definitionVersion: ExactVersionRef<EncounterContent>(
        stableId: StableContentId<EncounterContent>('encounter:amberwing'),
        versionId: ContentVersionId<EncounterContent>(_encounterVersionId),
        revision: 3,
      ),
    );

CellVisit _cellVisit() => CellVisit(
      id: _visitId,
      cellId: 'cell:one',
      userId: _userId,
      visitedAt: DateTime.utc(2026, 7, 20, 12),
    );

Map<String, Object?> _noneAggregate() => <String, Object?>{
      'cell_visit_resolution': <String, Object?>{
        'id': _resolutionId,
        'cell_visit_id': _visitId,
        'selector_id': _selectorId,
        'selector_candidate_id': _candidateId,
        'resolution_kind': 'none',
        'encounter_definition_id': null,
        'resolved_at': '2026-07-20T12:00:00.000Z',
      },
      'encounter': null,
      'outcome_results': <Object?>[],
      'generated_items': <Object?>[],
    };

Map<String, Object?> _selectedAggregate({String candidateId = _candidateId}) =>
    <String, Object?>{
      'cell_visit_resolution': <String, Object?>{
        'id': _resolutionId,
        'cell_visit_id': _visitId,
        'selector_id': _selectorId,
        'selector_candidate_id': candidateId,
        'resolution_kind': 'encounter',
        'encounter_definition_id': 'encounter:amberwing',
        'resolved_at': '2026-07-20T12:00:00.000Z',
      },
      'encounter': <String, Object?>{
        'id': _encounterId,
        'cell_visit_id': _visitId,
        'cell_visit_resolution_id': _resolutionId,
        'encounter_definition_id': 'encounter:amberwing',
        'encounter_definition_version_id': _encounterVersionId,
        'encounter_definition_revision': 3,
        'selected_option_id': _optionId,
        'resolution_status': 'resolved',
        'created_at': '2026-07-20T12:00:00.000Z',
        'resolved_at': '2026-07-20T12:00:01.000Z',
        'failure_code': null,
        'failure_details': null,
      },
      'outcome_results': <Object?>[
        <String, Object?>{
          'id': _resultId,
          'encounter_id': _encounterId,
          'outcome_ordinal': 1,
          'encounter_outcome_id': _outcomeId,
          'outcome_kind': 'generate_item',
          'resolved_base_item_id': 'fauna:amberwing',
          'resolved_base_item_version_id': _baseVersionId,
          'resolved_base_item_revision': 4,
          'generated_item_id': _itemId,
          'resolved_venue_id': null,
          'resolved_venue_version_id': null,
          'resolved_venue_revision': null,
          'known_at': null,
          'created_at': '2026-07-20T12:00:01.000Z',
        },
      ],
      'generated_items': <Object?>[
        <String, Object?>{
          'id': _itemId,
          'user_id': _userId,
          'definition_id': 'fauna:amberwing',
          'display_name': 'Amberwing Warbler',
          'scientific_name': 'Setophaga amberwing',
          'category': 'fauna',
          'acquired_at': '2026-07-20T12:00:01.000Z',
          'acquired_in_cell_id': 'cell:one',
          'status': 'active',
          'base_item_id': 'fauna:amberwing',
          'base_item_version_id': _baseVersionId,
          'base_item_revision': 4,
        },
      ],
    };

Map<String, Object?> _revealAggregate() {
  final aggregate = _selectedAggregate();
  aggregate['outcome_results'] = <Object?>[
    <String, Object?>{
      'id': _revealResultId,
      'encounter_id': _encounterId,
      'outcome_ordinal': 1,
      'encounter_outcome_id': _revealOutcomeId,
      'outcome_kind': 'reveal_venue',
      'resolved_base_item_id': null,
      'resolved_base_item_version_id': null,
      'resolved_base_item_revision': null,
      'generated_item_id': null,
      'resolved_venue_id': _venueId,
      'resolved_venue_version_id': _venueVersionId,
      'resolved_venue_revision': 3,
      'known_at': '2026-07-20T12:00:01.000Z',
      'created_at': '2026-07-20T12:00:01.000Z',
    },
  ];
  aggregate['generated_items'] = <Object?>[];
  return aggregate;
}

final class _FakeRpcGateway {
  _FakeRpcGateway(this.response);

  final Object? response;
  final List<_RpcCall> calls = <_RpcCall>[];

  Future<Object?> call(
      String functionName, Map<String, Object?> parameters) async {
    calls.add(
      _RpcCall(
        functionName: functionName,
        parameters: Map<String, Object?>.unmodifiable(parameters),
      ),
    );
    return response;
  }
}

final class _RpcCall {
  const _RpcCall({required this.functionName, required this.parameters});

  final String functionName;
  final Map<String, Object?> parameters;
}
