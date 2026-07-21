import 'package:earth_nova/features/encounters/data/dtos/encounter_runtime_aggregate_dto.dart';
import 'package:earth_nova/features/encounters/domain/entities/encounter_entities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EncounterRuntimeAggregateDto', () {
    test('parses the same committed aggregate idempotently', () {
      final first = EncounterRuntimeAggregateDto.fromJson(_selectedAggregate())
          .toDomain();
      final second = EncounterRuntimeAggregateDto.fromJson(_selectedAggregate())
          .toDomain();

      expect(first.cellVisitResolution.id, second.cellVisitResolution.id);
      expect(first.encounter?.definitionVersion,
          second.encounter?.definitionVersion);
      expect(first.encounter?.definitionVersion.revision, 3);
      expect(first.outcomeResults, hasLength(1));
      expect(first.outcomeResults.single.ordinal, 0);
      expect(first.generatedItemCommits, hasLength(1));
      expect(
        first.generatedItemCommits.single.outcomeResult,
        isA<GenerateItemOutcomeResult>(),
      );
      expect(first.generatedItemCommits.single.item.id, _itemId);
      expect(first.revealedVenueCommits, isEmpty);
    });

    test('preserves explicit None without an Encounter or Item commits', () {
      final aggregate =
          EncounterRuntimeAggregateDto.fromJson(_noneAggregate()).toDomain();

      expect(
        aggregate.cellVisitResolution.result,
        isA<NoEncounterDefinitionSelection>(),
      );
      expect(aggregate.encounter, isNull);
      expect(aggregate.outcomeResults, isEmpty);
      expect(aggregate.generatedItemCommits, isEmpty);
      expect(aggregate.revealedVenueCommits, isEmpty);
    });

    test('rejects a generated Item not linked from an outcome result', () {
      expect(
        () => EncounterRuntimeAggregateDto.fromJson(
          _selectedAggregate(generatedItemId: _otherItemId),
        ),
        throwsStateError,
      );
    });

    test('rejects a malformed exact Version triple', () {
      expect(
        () => EncounterRuntimeAggregateDto.fromJson(
          _selectedAggregate(encounterRevision: 0),
        ),
        throwsStateError,
      );
    });

    test('registers an unidentified generated Item without canonical evidence',
        () {
      final aggregate = _selectedAggregate();
      final outcome = (aggregate['outcome_results']! as List<Object?>).single
          as Map<String, Object?>;
      outcome['resolved_base_item_id'] = null;
      outcome['resolved_base_item_version_id'] = null;
      outcome['resolved_base_item_revision'] = null;
      final item = (aggregate['generated_items']! as List<Object?>).single
          as Map<String, Object?>;
      item
        ..remove('user_id')
        ..remove('definition_id')
        ..remove('scientific_name')
        ..remove('base_item_id')
        ..remove('base_item_version_id')
        ..remove('base_item_revision')
        ..['identification_state'] = 'unidentified';

      final parsed =
          EncounterRuntimeAggregateDto.fromJson(aggregate).toDomain();
      final commit = parsed.generatedItemCommits.single;

      expect(commit.item.isUnidentified, isTrue);
      expect(commit.item.definitionId, isNull);
      expect(commit.outcomeResult.resolvedBaseItemVersion, isNull);
    });
    test('parses first-known Reveal Venue evidence without an Item commit', () {
      final aggregate =
          EncounterRuntimeAggregateDto.fromJson(_revealAggregate()).toDomain();

      expect(aggregate.generatedItemCommits, isEmpty);
      expect(aggregate.revealedVenueCommits, hasLength(1));
      final commit = aggregate.revealedVenueCommits.single;
      expect(commit.venueId.value, _venueId);
      expect(
        commit.outcomeResult.resolvedVenueVersion.versionId.value,
        _venueVersionId,
      );
      expect(commit.outcomeResult.resolvedVenueVersion.revision, 5);
      expect(commit.knownAt, DateTime.utc(2026, 7, 20, 12, 0, 1));
    });

    test('parses mixed Item and Reveal Venue evidence', () {
      final aggregate =
          EncounterRuntimeAggregateDto.fromJson(_mixedAggregate()).toDomain();

      expect(aggregate.generatedItemCommits, hasLength(1));
      expect(aggregate.revealedVenueCommits, hasLength(1));
    });

    test('preserves ordered Reveal Venue evidence for the same stable Venue',
        () {
      final aggregate = EncounterRuntimeAggregateDto.fromJson(
        _repeatedRevealAggregate(),
      ).toDomain();

      expect(aggregate.revealedVenueCommits, hasLength(2));
      expect(
        aggregate.revealedVenueCommits.map((commit) => commit.venueId.value),
        everyElement(_venueId),
      );
    });

    test('rejects Item bindings on a Reveal Venue result', () {
      final aggregate = _revealAggregate();
      final result = (aggregate['outcome_results']! as List<Object?>).single
          as Map<String, Object?>;
      result['generated_item_id'] = _itemId;

      expect(
        () => EncounterRuntimeAggregateDto.fromJson(aggregate),
        throwsStateError,
      );
    });

    test('rejects Venue bindings on a Generate Item result', () {
      final aggregate = _selectedAggregate();
      final result = (aggregate['outcome_results']! as List<Object?>).single
          as Map<String, Object?>;
      result['resolved_venue_id'] = _venueId;

      expect(
        () => EncounterRuntimeAggregateDto.fromJson(aggregate),
        throwsStateError,
      );
    });

    test('rejects missing known Venue or duplicate output result evidence', () {
      final missing = _revealAggregate();
      final missingResult = (missing['outcome_results']! as List<Object?>)
          .single as Map<String, Object?>;
      missingResult['known_at'] = null;

      final duplicate = _mixedAggregate();
      final result = (duplicate['outcome_results']! as List<Object?>).last
          as Map<String, Object?>;
      final firstResult = (duplicate['outcome_results']! as List<Object?>).first
          as Map<String, Object?>;
      result['id'] = firstResult['id'];

      expect(
        () => EncounterRuntimeAggregateDto.fromJson(missing),
        throwsStateError,
      );
      expect(
        () => EncounterRuntimeAggregateDto.fromJson(duplicate),
        throwsStateError,
      );
    });
  });
}

const _resolutionId = '00000000-0000-4000-8000-000000000001';
const _visitId = '00000000-0000-4000-8000-000000000002';
const _candidateId = '00000000-0000-4000-8000-000000000003';
const _encounterId = '00000000-0000-4000-8000-000000000004';
const _versionId = '00000000-0000-4000-8000-000000000005';
const _optionId = '00000000-0000-4000-8000-000000000006';
const _resultId = '00000000-0000-4000-8000-000000000007';
const _outcomeId = '00000000-0000-4000-8000-000000000008';
const _baseVersionId = '00000000-0000-4000-8000-000000000009';
const _itemId = '00000000-0000-4000-8000-000000000010';
const _otherItemId = '00000000-0000-4000-8000-000000000011';
const _userId = '00000000-0000-4000-8000-000000000012';
const _venueId = 'venue:shoreline-observatory';
const _venueVersionId = '00000000-0000-4000-8000-000000000013';
const _revealResultId = '00000000-0000-4000-8000-000000000014';
const _revealOutcomeId = '00000000-0000-4000-8000-000000000015';

Map<String, Object?> _selectedAggregate({
  String generatedItemId = _itemId,
  int encounterRevision = 3,
}) =>
    <String, Object?>{
      'cell_visit_resolution': <String, Object?>{
        'id': _resolutionId,
        'cell_visit_id': _visitId,
        'selector_id': 'selector:legacy-cell-encounter',
        'selector_candidate_id': _candidateId,
        'resolution_kind': 'encounter',
        'encounter_definition_id': 'encounter:amberwing',
        'resolved_at': '2026-07-20T12:00:00.000Z',
      },
      'encounter': <String, Object?>{
        'id': _encounterId,
        'cell_visit_id': _visitId,
        'cell_visit_resolution_id': _resolutionId,
        'encounter_definition_id': 'encounter:amberwing',
        'encounter_definition_version_id': _versionId,
        'encounter_definition_revision': encounterRevision,
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
          'outcome_ordinal': 0,
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
          'id': generatedItemId,
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
  aggregate['outcome_results'] = <Object?>[_revealOutcomeResult()];
  aggregate['generated_items'] = <Object?>[];
  return aggregate;
}

Map<String, Object?> _mixedAggregate() {
  final aggregate = _selectedAggregate();
  aggregate['outcome_results'] = <Object?>[
    (aggregate['outcome_results']! as List<Object?>).single,
    _revealOutcomeResult(),
  ];
  return aggregate;
}

Map<String, Object?> _repeatedRevealAggregate() {
  final aggregate = _revealAggregate();
  aggregate['outcome_results'] = <Object?>[
    _revealOutcomeResult(),
    _revealOutcomeResult(
      id: '00000000-0000-4000-8000-000000000016',
      outcomeId: '00000000-0000-4000-8000-000000000017',
      ordinal: 2,
    ),
  ];
  return aggregate;
}

Map<String, Object?> _revealOutcomeResult({
  String id = _revealResultId,
  String outcomeId = _revealOutcomeId,
  int ordinal = 1,
}) =>
    <String, Object?>{
      'id': id,
      'encounter_id': _encounterId,
      'outcome_ordinal': ordinal,
      'encounter_outcome_id': outcomeId,
      'outcome_kind': 'reveal_venue',
      'resolved_base_item_id': null,
      'resolved_base_item_version_id': null,
      'resolved_base_item_revision': null,
      'generated_item_id': null,
      'resolved_venue_id': _venueId,
      'resolved_venue_version_id': _venueVersionId,
      'resolved_venue_revision': 5,
      'known_at': '2026-07-20T12:00:01.000Z',
      'created_at': '2026-07-20T12:00:01.000Z',
    };

Map<String, Object?> _noneAggregate() => <String, Object?>{
      'cell_visit_resolution': <String, Object?>{
        'id': _resolutionId,
        'cell_visit_id': _visitId,
        'selector_id': 'selector:legacy-cell-encounter',
        'selector_candidate_id': _candidateId,
        'resolution_kind': 'none',
        'encounter_definition_id': null,
        'resolved_at': '2026-07-20T12:00:00.000Z',
      },
      'encounter': null,
      'outcome_results': <Object?>[],
      'generated_items': <Object?>[],
    };
