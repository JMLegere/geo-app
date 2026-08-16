import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/domain/content/encounter_content.dart';
import 'package:earth_nova/features/encounters/domain/entities/encounter_entities.dart';

/// Strict parser for the flat pending-Encounter read RPC projection.
final class PendingEncounterDto {
  factory PendingEncounterDto.fromJson(Map<String, Object?> json) =>
      PendingEncounterDto._(Map<String, Object?>.unmodifiable(json));

  const PendingEncounterDto._(this._json);

  final Map<String, Object?> _json;

  PendingEncounter toDomain() {
    _requireKeys(_json, const <String>[
      'cell_id',
      'encounter_id',
      'cell_visit_id',
      'cell_visit_resolution_id',
      'encounter_definition_id',
      'encounter_definition_version_id',
      'encounter_definition_revision',
      'created_at',
      'definition_display_name',
      'options',
    ]);
    final definitionId = StableContentId<EncounterContent>(
      _requiredText(
          _json['encounter_definition_id'], 'encounter_definition_id'),
    );
    return PendingEncounter(
      cellId: _requiredText(_json['cell_id'], 'cell_id'),
      encounter: EncounterOccurrence(
        id: EncounterId(_requiredUuid(_json['encounter_id'], 'encounter_id')),
        cellVisitId:
            CellVisitId(_requiredUuid(_json['cell_visit_id'], 'cell_visit_id')),
        cellVisitResolutionId: CellVisitResolutionId(_requiredUuid(
          _json['cell_visit_resolution_id'],
          'cell_visit_resolution_id',
        )),
        definitionVersion: ExactVersionRef<EncounterContent>(
          stableId: definitionId,
          versionId: ContentVersionId<EncounterContent>(_requiredUuid(
            _json['encounter_definition_version_id'],
            'encounter_definition_version_id',
          )),
          revision: _requiredPositiveInt(
            _json['encounter_definition_revision'],
            'encounter_definition_revision',
          ),
        ),
        status: EncounterResolutionStatus.pending,
        createdAt: _requiredTimestamp(_json['created_at'], 'created_at'),
      ),
      definitionDisplayName: _requiredText(
          _json['definition_display_name'], 'definition_display_name'),
      options: _parseOptions(_json['options']),
    );
  }
}

List<PendingEncounterOption> _parseOptions(Object? value) {
  if (value is! List || value.isEmpty) {
    throw StateError('options must be a nonempty list.');
  }
  final options = <PendingEncounterOption>[];
  for (var index = 0; index < value.length; index++) {
    final json = _requiredObject(value[index], 'options[$index]');
    _requireKeys(json, const <String>['id', 'ordinal', 'display_name']);
    final ordinal =
        _requiredNonNegativeInt(json['ordinal'], 'options[$index].ordinal');
    if (options.isNotEmpty && options.last.ordinal >= ordinal) {
      throw StateError('options must be ordered by increasing ordinal.');
    }
    options.add(PendingEncounterOption(
      id: EncounterOptionId(_requiredUuid(json['id'], 'options[$index].id')),
      ordinal: ordinal,
      displayName:
          _requiredText(json['display_name'], 'options[$index].display_name'),
    ));
  }
  return options;
}

Map<String, Object?> _requiredObject(Object? value, String field) {
  if (value is! Map) throw StateError('$field must be an object.');
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) throw StateError('$field keys must be strings.');
    result[entry.key] = entry.value;
  }
  return result;
}

void _requireKeys(Map<String, Object?> json, List<String> keys) {
  for (final key in keys) {
    if (!json.containsKey(key)) {
      throw StateError('pending projection lacks $key.');
    }
  }
}

String _requiredText(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw StateError('$field must be a nonblank string.');
  }
  return value.trim();
}

String _requiredUuid(Object? value, String field) {
  final text = _requiredText(value, field);
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(text)) {
    throw StateError('$field must be a UUID.');
  }
  return text;
}

int _requiredPositiveInt(Object? value, String field) {
  if (value is! int || value <= 0) {
    throw StateError('$field must be a positive integer.');
  }
  return value;
}

int _requiredNonNegativeInt(Object? value, String field) {
  if (value is! int || value < 0) {
    throw StateError('$field must be a nonnegative integer.');
  }
  return value;
}

DateTime _requiredTimestamp(Object? value, String field) {
  final timestamp = DateTime.tryParse(_requiredText(value, field));
  if (timestamp == null) {
    throw StateError('$field must be an ISO-8601 timestamp.');
  }
  return timestamp;
}
