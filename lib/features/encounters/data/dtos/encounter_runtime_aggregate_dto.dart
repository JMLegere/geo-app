import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/domain/content/encounter_content.dart';
import 'package:earth_nova/core/domain/content/venue_content.dart';
import 'package:earth_nova/core/domain/entities/venue_id.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/encounters/domain/entities/encounter_entities.dart';
import 'package:earth_nova/features/encounters/domain/repositories/encounter_repository.dart';

/// Strict parser for the aggregate returned by the two Encounter command RPCs.
///
/// Supabase JSON is intentionally treated as untrusted external data. Every
/// field is checked before constructing domain values so a malformed aggregate
/// cannot reach runtime state as a plausible partial success.
final class EncounterRuntimeAggregateDto {
  const EncounterRuntimeAggregateDto._(this._aggregate);

  final EncounterRuntimeAggregate _aggregate;

  factory EncounterRuntimeAggregateDto.fromJson(Object? json) {
    final aggregate = _requiredObject(json, 'aggregate');
    _requireKeys(
      aggregate,
      const <String>[
        'cell_visit_resolution',
        'encounter',
        'outcome_results',
        'generated_items',
      ],
      'aggregate',
    );
    final resolution = _parseResolution(
      _requiredObject(
          aggregate['cell_visit_resolution'], 'cell_visit_resolution'),
    );
    final encounterValue = aggregate['encounter'];
    final encounter = encounterValue == null
        ? null
        : _parseEncounter(_requiredObject(encounterValue, 'encounter'));
    final parsedItems = _parseGeneratedItems(aggregate['generated_items']);
    final parsedOutcomes = _parseOutcomes(aggregate['outcome_results']);

    _validateAggregate(
      resolution: resolution,
      encounter: encounter,
      outcomes: parsedOutcomes,
      generatedItems: parsedItems,
    );

    final outcomeResults = List<EncounterOutcomeResult>.unmodifiable(
      parsedOutcomes.map((outcome) => outcome.result),
    );
    final commits = <GeneratedItemCommit>[];
    final revealedVenueCommits = <RevealedVenueCommit>[
      for (final outcome in parsedOutcomes)
        if (outcome.knownAt case final knownAt?)
          RevealedVenueCommit(
            outcomeResult: switch (outcome.result) {
              final RevealVenueOutcomeResult result => result,
              _ => throw StateError(
                  'Known Venue evidence must link to a Reveal Venue result.',
                ),
            },
            knownAt: knownAt,
          ),
    ];
    final outcomesByGeneratedItemId = <String, _ParsedOutcome>{};
    for (final outcome in parsedOutcomes) {
      final generatedItemId = outcome.generatedItemId;
      if (generatedItemId != null) {
        outcomesByGeneratedItemId[generatedItemId] = outcome;
      }
    }
    for (final generatedItem in parsedItems) {
      final outcome = outcomesByGeneratedItemId[generatedItem.id];
      if (outcome == null || outcome.result is! GenerateItemOutcomeResult) {
        throw StateError(
            'generated_items must link to a Generate Item result.');
      }
      final result = outcome.result;
      if (result is! GenerateItemOutcomeResult) {
        throw StateError('Generated Item result must have Generate Item kind.');
      }
      if (result.resolvedBaseItemVersion != generatedItem.baseItemVersion) {
        throw StateError(
            'Generated Item exact Base Item Version must match its result.');
      }
      commits.add(
          GeneratedItemCommit(outcomeResult: result, item: generatedItem.item));
    }

    return EncounterRuntimeAggregateDto._(
      EncounterRuntimeAggregate(
        cellVisitResolution: resolution,
        encounter: encounter,
        outcomeResults: outcomeResults,
        generatedItemCommits: commits,
        revealedVenueCommits: revealedVenueCommits,
      ),
    );
  }

  EncounterRuntimeAggregate toDomain() => _aggregate;
}

CellVisitResolution _parseResolution(Map<String, Object?> json) {
  _requireKeys(
    json,
    const <String>[
      'id',
      'cell_visit_id',
      'selector_id',
      'selector_candidate_id',
      'resolution_kind',
      'encounter_definition_id',
      'resolved_at',
    ],
    'cell_visit_resolution',
  );
  final id = CellVisitResolutionId(
      _requiredUuid(json['id'], 'cell_visit_resolution.id'));
  final visitId = CellVisitId(
    _requiredUuid(json['cell_visit_id'], 'cell_visit_resolution.cell_visit_id'),
  );
  final selectorId = SelectorId(
    _requiredText(json['selector_id'], 'cell_visit_resolution.selector_id'),
  );
  final candidateId = SelectorCandidateId(
    _requiredUuid(
      json['selector_candidate_id'],
      'cell_visit_resolution.selector_candidate_id',
    ),
  );
  final resolvedAt = _requiredTimestamp(
    json['resolved_at'],
    'cell_visit_resolution.resolved_at',
  );

  return switch (json['resolution_kind']) {
    'none' => _parseNoneResolution(
        json,
        id: id,
        visitId: visitId,
        selectorId: selectorId,
        candidateId: candidateId,
        resolvedAt: resolvedAt,
      ),
    'encounter' => _parseSelectedResolution(
        json,
        id: id,
        visitId: visitId,
        selectorId: selectorId,
        candidateId: candidateId,
        resolvedAt: resolvedAt,
      ),
    _ => throw StateError('cell_visit_resolution.resolution_kind is invalid.'),
  };
}

CellVisitResolution _parseNoneResolution(
  Map<String, Object?> json, {
  required CellVisitResolutionId id,
  required CellVisitId visitId,
  required SelectorId selectorId,
  required SelectorCandidateId candidateId,
  required DateTime resolvedAt,
}) {
  if (json['encounter_definition_id'] != null) {
    throw StateError(
        'None Cell Visit resolution cannot name an Encounter Definition.');
  }
  return CellVisitResolution.none(
    id: id,
    cellVisitId: visitId,
    selectorId: selectorId,
    selectorCandidateId: candidateId,
    resolvedAt: resolvedAt,
  );
}

CellVisitResolution _parseSelectedResolution(
  Map<String, Object?> json, {
  required CellVisitResolutionId id,
  required CellVisitId visitId,
  required SelectorId selectorId,
  required SelectorCandidateId candidateId,
  required DateTime resolvedAt,
}) =>
    CellVisitResolution.selectedDefinition(
      id: id,
      cellVisitId: visitId,
      selectorId: selectorId,
      selectorCandidateId: candidateId,
      definitionId: StableContentId<EncounterContent>(
        _requiredText(
          json['encounter_definition_id'],
          'cell_visit_resolution.encounter_definition_id',
        ),
      ),
      resolvedAt: resolvedAt,
    );

EncounterOccurrence _parseEncounter(Map<String, Object?> json) {
  _requireKeys(
    json,
    const <String>[
      'id',
      'cell_visit_id',
      'cell_visit_resolution_id',
      'encounter_definition_id',
      'encounter_definition_version_id',
      'encounter_definition_revision',
      'selected_option_id',
      'resolution_status',
      'created_at',
      'resolved_at',
      'failure_code',
      'failure_details',
    ],
    'encounter',
  );
  final definitionId = StableContentId<EncounterContent>(
    _requiredText(
        json['encounter_definition_id'], 'encounter.encounter_definition_id'),
  );
  final definitionVersion = ExactVersionRef<EncounterContent>(
    stableId: definitionId,
    versionId: ContentVersionId<EncounterContent>(
      _requiredUuid(
        json['encounter_definition_version_id'],
        'encounter.encounter_definition_version_id',
      ),
    ),
    revision: _requiredPositiveInt(
      json['encounter_definition_revision'],
      'encounter.encounter_definition_revision',
    ),
  );
  final status = switch (json['resolution_status']) {
    'pending' => EncounterResolutionStatus.pending,
    'resolved' => EncounterResolutionStatus.resolved,
    'failed' => EncounterResolutionStatus.failed,
    _ => throw StateError('encounter.resolution_status is invalid.'),
  };
  final failureCode =
      _nullableText(json['failure_code'], 'encounter.failure_code');
  final failureDetails = _nullableStringMap(
    json['failure_details'],
    'encounter.failure_details',
  );
  final failure = failureCode == null
      ? null
      : EncounterFailure(
          code: failureCode, details: failureDetails ?? const {});
  if (failureCode == null && failureDetails != null) {
    throw StateError(
        'encounter.failure_details requires encounter.failure_code.');
  }

  return EncounterOccurrence(
    id: EncounterId(_requiredUuid(json['id'], 'encounter.id')),
    cellVisitId: CellVisitId(
        _requiredUuid(json['cell_visit_id'], 'encounter.cell_visit_id')),
    cellVisitResolutionId: CellVisitResolutionId(
      _requiredUuid(
        json['cell_visit_resolution_id'],
        'encounter.cell_visit_resolution_id',
      ),
    ),
    definitionVersion: definitionVersion,
    status: status,
    createdAt: _requiredTimestamp(json['created_at'], 'encounter.created_at'),
    selectedOptionId: _nullableUuidAs(
      json['selected_option_id'],
      'encounter.selected_option_id',
      EncounterOptionId.new,
    ),
    resolvedAt:
        _nullableTimestamp(json['resolved_at'], 'encounter.resolved_at'),
    failure: failure,
  );
}

List<_ParsedOutcome> _parseOutcomes(Object? value) {
  final entries = _requiredList(value, 'outcome_results');
  final outcomes = <_ParsedOutcome>[];
  var previousOrdinal = -1;
  final ids = <String>{};
  final generatedItemIds = <String>{};
  final outcomeIds = <String>{};

  for (var index = 0; index < entries.length; index += 1) {
    final json = _requiredObject(entries[index], 'outcome_results[$index]');
    _requireKeys(
      json,
      const <String>[
        'id',
        'encounter_id',
        'outcome_ordinal',
        'encounter_outcome_id',
        'outcome_kind',
        'resolved_base_item_id',
        'resolved_base_item_version_id',
        'resolved_base_item_revision',
        'generated_item_id',
        'resolved_venue_id',
        'resolved_venue_version_id',
        'resolved_venue_revision',
        'known_at',
        'created_at',
      ],
      'outcome_results[$index]',
    );
    final id = _requiredUuid(json['id'], 'outcome_results[$index].id');
    if (!ids.add(id)) {
      throw StateError('outcome_results ids must be unique.');
    }
    final ordinal = _requiredNonNegativeInt(
      json['outcome_ordinal'],
      'outcome_results[$index].outcome_ordinal',
    );
    if (ordinal <= previousOrdinal) {
      throw StateError('outcome_results must be ordered by unique ordinal.');
    }
    previousOrdinal = ordinal;
    final encounterId = EncounterId(
      _requiredUuid(
          json['encounter_id'], 'outcome_results[$index].encounter_id'),
    );
    final common = _OutcomeFields(
      id: EncounterOutcomeResultId(id),
      encounterId: encounterId,
      outcomeId: EncounterOutcomeId(
        _requiredUuid(
          json['encounter_outcome_id'],
          'outcome_results[$index].encounter_outcome_id',
        ),
      ),
      ordinal: ordinal,
      createdAt: _requiredTimestamp(
          json['created_at'], 'outcome_results[$index].created_at'),
    );
    if (!outcomeIds.add(common.outcomeId.value)) {
      throw StateError(
          'outcome_results encounter_outcome_id values must be unique.');
    }

    switch (json['outcome_kind']) {
      case 'generate_item':
        if (json['resolved_venue_id'] != null ||
            json['resolved_venue_version_id'] != null ||
            json['resolved_venue_revision'] != null ||
            json['known_at'] != null) {
          throw StateError(
            'Generate Item result cannot contain Reveal Venue evidence.',
          );
        }
        final generatedItemId = _requiredUuid(
          json['generated_item_id'],
          'outcome_results[$index].generated_item_id',
        );
        if (!generatedItemIds.add(generatedItemId)) {
          throw StateError(
              'generated_item_id must have one Generate Item result.');
        }
        outcomes.add(
          _ParsedOutcome(
            result: GenerateItemOutcomeResult(
              id: common.id,
              encounterId: common.encounterId,
              outcomeId: common.outcomeId,
              ordinal: common.ordinal,
              createdAt: common.createdAt,
              resolvedBaseItemVersion: _baseItemVersionFromResult(json, index),
            ),
            generatedItemId: generatedItemId,
          ),
        );
        break;
      case 'reveal_venue':
        if (json['resolved_base_item_id'] != null ||
            json['resolved_base_item_version_id'] != null ||
            json['resolved_base_item_revision'] != null ||
            json['generated_item_id'] != null) {
          throw StateError(
              'Reveal Venue result cannot contain generated Item binding.');
        }
        final venueId = VenueId(
          _requiredText(
            json['resolved_venue_id'],
            'outcome_results[$index].resolved_venue_id',
          ),
        );
        outcomes.add(
          _ParsedOutcome(
            result: RevealVenueOutcomeResult(
              id: common.id,
              encounterId: common.encounterId,
              outcomeId: common.outcomeId,
              ordinal: common.ordinal,
              createdAt: common.createdAt,
              venueId: venueId,
              resolvedVenueVersion: _venueVersionFromResult(json, index),
            ),
            knownAt: _requiredTimestamp(
              json['known_at'],
              'outcome_results[$index].known_at',
            ),
          ),
        );
        break;
      default:
        throw StateError('outcome_results[$index].outcome_kind is invalid.');
    }
  }
  return List<_ParsedOutcome>.unmodifiable(outcomes);
}

ExactVersionRef<BaseItemContent>? _baseItemVersionFromResult(
  Map<String, Object?> json,
  int index,
) {
  final values = <Object?>[
    json['resolved_base_item_id'],
    json['resolved_base_item_version_id'],
    json['resolved_base_item_revision'],
  ];
  if (values.every((value) => value == null)) return null;
  if (values.any((value) => value == null)) {
    throw StateError(
        'outcome_results[$index] Base Item Version evidence must be complete.');
  }
  return ExactVersionRef<BaseItemContent>(
    stableId: StableContentId<BaseItemContent>(
      _requiredText(
        json['resolved_base_item_id'],
        'outcome_results[$index].resolved_base_item_id',
      ),
    ),
    versionId: ContentVersionId<BaseItemContent>(
      _requiredUuid(
        json['resolved_base_item_version_id'],
        'outcome_results[$index].resolved_base_item_version_id',
      ),
    ),
    revision: _requiredPositiveInt(
      json['resolved_base_item_revision'],
      'outcome_results[$index].resolved_base_item_revision',
    ),
  );
}

ExactVersionRef<VenueContent> _venueVersionFromResult(
  Map<String, Object?> json,
  int index,
) =>
    ExactVersionRef<VenueContent>(
      stableId: StableContentId<VenueContent>(
        _requiredText(
          json['resolved_venue_id'],
          'outcome_results[$index].resolved_venue_id',
        ),
      ),
      versionId: ContentVersionId<VenueContent>(
        _requiredUuid(
          json['resolved_venue_version_id'],
          'outcome_results[$index].resolved_venue_version_id',
        ),
      ),
      revision: _requiredPositiveInt(
        json['resolved_venue_revision'],
        'outcome_results[$index].resolved_venue_revision',
      ),
    );

List<_ParsedGeneratedItem> _parseGeneratedItems(Object? value) {
  final entries = _requiredList(value, 'generated_items');
  final items = <_ParsedGeneratedItem>[];
  final ids = <String>{};
  for (var index = 0; index < entries.length; index += 1) {
    final json = _requiredObject(entries[index], 'generated_items[$index]');
    _requireKeys(
      json,
      const <String>[
        'id',
        'display_name',
        'category',
        'acquired_at',
        'acquired_in_cell_id',
        'status',
      ],
      'generated_items[$index]',
    );
    final id = _requiredUuid(json['id'], 'generated_items[$index].id');
    if (!ids.add(id)) {
      throw StateError('generated_items ids must be unique.');
    }
    final identificationState = _itemIdentificationState(
      json['identification_state'],
      'generated_items[$index].identification_state',
    );
    final baseItemVersion =
        _nullableBaseItemVersionFromGeneratedItem(json, index);
    final definitionId = _nullableText(
      json['definition_id'],
      'generated_items[$index].definition_id',
    );
    if (identificationState == ItemIdentificationState.unidentified) {
      if (definitionId != null || baseItemVersion != null) {
        throw StateError(
            'Unidentified generated Items must not expose canonical identity.');
      }
    } else if (definitionId == null ||
        baseItemVersion == null ||
        definitionId != baseItemVersion.stableId.value) {
      throw StateError(
          'Identified generated Items require matching Base Item identity.');
    }
    items.add(
      _ParsedGeneratedItem(
        id: id,
        baseItemVersion: baseItemVersion,
        item: Item(
          id: id,
          definitionId: definitionId,
          displayName: _requiredText(
            json['display_name'],
            'generated_items[$index].display_name',
          ),
          scientificName: _nullableText(
            json['scientific_name'],
            'generated_items[$index].scientific_name',
          ),
          category: _itemCategory(
              json['category'], 'generated_items[$index].category'),
          acquiredAt: _requiredTimestamp(
            json['acquired_at'],
            'generated_items[$index].acquired_at',
          ),
          acquiredInCellId: _nullableText(
            json['acquired_in_cell_id'],
            'generated_items[$index].acquired_in_cell_id',
          ),
          status: _itemStatus(json['status'], 'generated_items[$index].status'),
          identificationState: identificationState,
        ),
      ),
    );
  }
  return List<_ParsedGeneratedItem>.unmodifiable(items);
}

ExactVersionRef<BaseItemContent>? _nullableBaseItemVersionFromGeneratedItem(
  Map<String, Object?> json,
  int index,
) {
  final values = <Object?>[
    json['base_item_id'],
    json['base_item_version_id'],
    json['base_item_revision'],
  ];
  if (values.every((value) => value == null)) return null;
  if (values.any((value) => value == null)) {
    throw StateError(
        'generated_items[$index] Base Item Version evidence must be complete.');
  }
  return ExactVersionRef<BaseItemContent>(
    stableId: StableContentId<BaseItemContent>(
      _requiredText(
          json['base_item_id'], 'generated_items[$index].base_item_id'),
    ),
    versionId: ContentVersionId<BaseItemContent>(
      _requiredUuid(
        json['base_item_version_id'],
        'generated_items[$index].base_item_version_id',
      ),
    ),
    revision: _requiredPositiveInt(
      json['base_item_revision'],
      'generated_items[$index].base_item_revision',
    ),
  );
}

void _validateAggregate({
  required CellVisitResolution resolution,
  required EncounterOccurrence? encounter,
  required List<_ParsedOutcome> outcomes,
  required List<_ParsedGeneratedItem> generatedItems,
}) {
  final selectedDefinition = switch (resolution.result) {
    NoEncounterDefinitionSelection() => null,
    EncounterDefinitionSelection(:final definitionId) => definitionId,
  };
  if (selectedDefinition == null) {
    if (encounter != null || outcomes.isNotEmpty || generatedItems.isNotEmpty) {
      throw StateError(
          'Explicit None resolution cannot contain Encounter state.');
    }
    return;
  }
  if (encounter == null ||
      encounter.cellVisitId != resolution.cellVisitId ||
      encounter.cellVisitResolutionId != resolution.id ||
      encounter.definitionVersion.stableId != selectedDefinition) {
    throw StateError(
        'Encounter must match its selected Cell Visit resolution.');
  }
  for (final outcome in outcomes) {
    if (outcome.result.encounterId != encounter.id) {
      throw StateError(
          'Outcome result must belong to the aggregate Encounter.');
    }
  }
  switch (encounter.status) {
    case EncounterResolutionStatus.pending:
    case EncounterResolutionStatus.failed:
      if (outcomes.isNotEmpty || generatedItems.isNotEmpty) {
        throw StateError(
            'Unresolved or failed Encounter cannot contain commits.');
      }
      break;
    case EncounterResolutionStatus.resolved:
      if (outcomes.isEmpty) {
        throw StateError(
            'Resolved Encounter must contain ordered Outcome results.');
      }
      break;
  }
  if (outcomes.where((outcome) => outcome.generatedItemId != null).length !=
      generatedItems.length) {
    throw StateError(
        'Every Generate Item result must link one generated Item.');
  }
}

Map<String, Object?> _requiredObject(Object? value, String field) {
  if (value is! Map) throw StateError('$field must be an object.');
  final object = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) throw StateError('$field keys must be strings.');
    object[entry.key] = entry.value;
  }
  return object;
}

void _requireKeys(
  Map<String, Object?> object,
  List<String> keys,
  String field,
) {
  for (final key in keys) {
    if (!object.containsKey(key)) {
      throw StateError('$field must contain $key.');
    }
  }
}

List<Object?> _requiredList(Object? value, String field) {
  if (value is! List) throw StateError('$field must be a list.');
  return List<Object?>.unmodifiable(value);
}

String _requiredText(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw StateError('$field must be a nonblank string.');
  }
  return value.trim();
}

String? _nullableText(Object? value, String field) =>
    value == null ? null : _requiredText(value, field);

String _requiredUuid(Object? value, String field) {
  final text = _requiredText(value, field);
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(text)) {
    throw StateError('$field must be a UUID.');
  }
  return text;
}

T? _nullableUuidAs<T>(
  Object? value,
  String field,
  T Function(String value) create,
) =>
    value == null ? null : create(_requiredUuid(value, field));

int _requiredPositiveInt(Object? value, String field) {
  if (value is! int || value <= 0) {
    throw StateError('$field must be a positive integer.');
  }
  return value;
}

int _requiredNonNegativeInt(Object? value, String field) {
  if (value is! int || value < 0) {
    throw StateError('$field must be a non-negative integer.');
  }
  return value;
}

DateTime _requiredTimestamp(Object? value, String field) {
  final parsed = DateTime.tryParse(_requiredText(value, field));
  if (parsed == null) throw StateError('$field must be an ISO-8601 timestamp.');
  return parsed;
}

DateTime? _nullableTimestamp(Object? value, String field) =>
    value == null ? null : _requiredTimestamp(value, field);

Map<String, String>? _nullableStringMap(Object? value, String field) {
  if (value == null) return null;
  final object = _requiredObject(value, field);
  final result = <String, String>{};
  for (final entry in object.entries) {
    result[entry.key] = _requiredText(entry.value, '$field.${entry.key}');
  }
  return Map<String, String>.unmodifiable(result);
}

ItemCategory _itemCategory(Object? value, String field) => switch (value) {
      'fauna' => ItemCategory.fauna,
      'flora' => ItemCategory.flora,
      'mineral' => ItemCategory.mineral,
      'fossil' => ItemCategory.fossil,
      'artifact' => ItemCategory.artifact,
      'food' => ItemCategory.food,
      'orb' => ItemCategory.orb,
      _ => throw StateError('$field is not a known Item category.'),
    };

ItemIdentificationState _itemIdentificationState(Object? value, String field) =>
    switch (value) {
      null => ItemIdentificationState.identified,
      'unidentified' => ItemIdentificationState.unidentified,
      'identified' => ItemIdentificationState.identified,
      _ => throw StateError('$field is not a known identification state.'),
    };

ItemStatus _itemStatus(Object? value, String field) => switch (value) {
      'active' => ItemStatus.active,
      'donated' => ItemStatus.donated,
      'placed' => ItemStatus.placed,
      'released' => ItemStatus.released,
      'traded' => ItemStatus.traded,
      _ => throw StateError('$field is not a known Item status.'),
    };

final class _OutcomeFields {
  const _OutcomeFields({
    required this.id,
    required this.encounterId,
    required this.outcomeId,
    required this.ordinal,
    required this.createdAt,
  });

  final EncounterOutcomeResultId id;
  final EncounterId encounterId;
  final EncounterOutcomeId outcomeId;
  final int ordinal;
  final DateTime createdAt;
}

final class _ParsedOutcome {
  const _ParsedOutcome({
    required this.result,
    this.generatedItemId,
    this.knownAt,
  });

  final EncounterOutcomeResult result;
  final String? generatedItemId;
  final DateTime? knownAt;
}

final class _ParsedGeneratedItem {
  const _ParsedGeneratedItem({
    required this.id,
    required this.item,
    required this.baseItemVersion,
  });

  final String id;
  final Item item;
  final ExactVersionRef<BaseItemContent>? baseItemVersion;
}
