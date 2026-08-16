import 'package:earth_nova/features/encounters/data/dtos/pending_encounter_dto.dart';
import 'package:earth_nova/features/encounters/domain/entities/encounter_entities.dart';
import 'package:flutter_test/flutter_test.dart';

const _encounterId = '00000000-0000-4000-8000-000000000004';
const _visitId = '00000000-0000-4000-8000-000000000002';
const _resolutionId = '00000000-0000-4000-8000-000000000001';
const _versionId = '00000000-0000-4000-8000-000000000005';
const _optionId = '00000000-0000-4000-8000-000000000006';

Map<String, Object?> _pendingRow() => <String, Object?>{
      'cell_id': 'cell:one',
      'encounter_id': _encounterId,
      'cell_visit_id': _visitId,
      'cell_visit_resolution_id': _resolutionId,
      'encounter_definition_id': 'encounter:red-fox',
      'encounter_definition_version_id': _versionId,
      'encounter_definition_revision': 2,
      'created_at': '2026-07-20T12:00:00.000Z',
      'definition_display_name': 'Red fox',
      'options': <Object?>[
        <String, Object?>{
          'id': _optionId,
          'ordinal': 0,
          'display_name': 'Observe the fox',
        },
      ],
    };

void main() {
  test('parses only the exact pending occurrence and visible options', () {
    final pending = PendingEncounterDto.fromJson(_pendingRow()).toDomain();

    expect(pending.cellId, 'cell:one');
    expect(pending.encounter.id, EncounterId(_encounterId));
    expect(pending.encounter.status, EncounterResolutionStatus.pending);
    expect(pending.encounter.definitionVersion.stableId.value,
        'encounter:red-fox');
    expect(pending.encounter.definitionVersion.versionId.value, _versionId);
    expect(pending.encounter.definitionVersion.revision, 2);
    expect(pending.definitionDisplayName, 'Red fox');
    expect(pending.options.single.id, EncounterOptionId(_optionId));
    expect(pending.options.single.ordinal, 0);
  });

  test('rejects missing, blank, empty, and unordered pending projections', () {
    final missingName = _pendingRow()..remove('definition_display_name');
    final blankName = _pendingRow()..['definition_display_name'] = ' ';
    final noOptions = _pendingRow()..['options'] = <Object?>[];
    final unordered = _pendingRow()
      ..['options'] = <Object?>[
        <String, Object?>{
          'id': '00000000-0000-4000-8000-000000000016',
          'ordinal': 1,
          'display_name': 'Late',
        },
        <String, Object?>{
          'id': _optionId,
          'ordinal': 0,
          'display_name': 'Early',
        },
      ];

    for (final row in [missingName, blankName, noOptions, unordered]) {
      expect(
        () => PendingEncounterDto.fromJson(row).toDomain(),
        throwsA(isA<StateError>()),
      );
    }
  });
}
