import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/content_version_id.dart';
import 'package:earth_nova/core/domain/content/exact_version_ref.dart';
import 'package:earth_nova/core/domain/rules/selector.dart';
import 'package:earth_nova/features/identification/data/dtos/identification_wire_validation.dart';
import 'package:earth_nova/features/identification/domain/entities/identification_entities.dart';
import 'package:earth_nova/features/item_knowledge/domain/entities/item_knowledge_entities.dart';

/// Strict wire binding for prepare_v3_item_identification.
final class IdentificationPreparationDto {
  const IdentificationPreparationDto._(this._value);

  final IdentificationPreparation _value;

  factory IdentificationPreparationDto.fromJson(Map<String, dynamic> json) {
    final root = IdentificationWireValidation.object(
      json,
      const {'item', 'discovery', 'properties'},
    );
    final item = _parseItem(root['item']);
    final playerDiscovered = _parseDiscovery(root['discovery'], item);
    final properties = _parseProperties(root['properties'], item);
    return IdentificationPreparationDto._(
      IdentificationPreparation(
        item: item,
        playerDiscovered: playerDiscovered,
        properties: properties,
      ),
    );
  }

  IdentificationPreparation toDomain() => _value;
}

ItemKnowledgeItemRef _parseItem(Object? value) {
  final item = IdentificationWireValidation.object(value, const {
    'id',
    'user_id',
    'base_item_id',
    'base_item_version_id',
    'base_item_revision',
    'identification_state',
  });
  if (item['identification_state'] != 'unidentified') {
    IdentificationWireValidation.invalid();
  }
  final baseItemId = BaseItemId(
    IdentificationWireValidation.string(item['base_item_id']),
  );
  return ItemKnowledgeItemRef(
    id: ItemKnowledgeItemId(IdentificationWireValidation.uuid(item['id'])),
    playerId: IdentificationWireValidation.uuid(item['user_id']),
    baseItemId: baseItemId,
    baseItemVersion: ExactVersionRef<BaseItemContent>(
      stableId: baseItemId,
      versionId: ContentVersionId<BaseItemContent>(
        IdentificationWireValidation.uuid(item['base_item_version_id']),
      ),
      revision: IdentificationWireValidation.positiveInt(
        item['base_item_revision'],
      ),
    ),
  );
}

bool _parseDiscovery(Object? value, ItemKnowledgeItemRef item) {
  if (value == null) return false;
  final discovery = IdentificationWireValidation.object(value, const {
    'user_id',
    'base_item_id',
    'first_identified_item_id',
    'first_base_item_version_id',
    'provenance',
    'discovered_at',
  });
  if (IdentificationWireValidation.uuid(discovery['user_id']) !=
          item.playerId ||
      IdentificationWireValidation.string(discovery['base_item_id']) !=
          item.baseItemId.value) {
    IdentificationWireValidation.invalid();
  }
  IdentificationWireValidation.uuid(discovery['first_identified_item_id']);
  IdentificationWireValidation.uuid(discovery['first_base_item_version_id']);
  IdentificationWireValidation.string(discovery['provenance']);
  IdentificationWireValidation.timestamp(discovery['discovered_at']);
  return true;
}

List<IdentificationProperty> _parseProperties(
  Object? value,
  ItemKnowledgeItemRef item,
) {
  final properties = IdentificationWireValidation.array(value);
  return List<IdentificationProperty>.unmodifiable([
    for (var index = 0; index < properties.length; index++)
      _parseProperty(properties[index], item, index),
  ]);
}

IdentificationProperty _parseProperty(
  Object? value,
  ItemKnowledgeItemRef item,
  int expectedOrdinal,
) {
  final property = IdentificationWireValidation.object(value, const {
    'ordinal',
    'variable_property_key',
    'display_name',
    'selector_id',
    'candidates',
    'selected_candidate_id',
  });
  final definition = VariablePropertyDefinition(
    id: VariablePropertyDefinitionId(
      IdentificationWireValidation.string(property['variable_property_key']),
    ),
    baseItemId: item.baseItemId,
    baseItemVersion: item.baseItemVersion,
    selectorId: PropertySelectorId(
      IdentificationWireValidation.string(property['selector_id']),
    ),
  );
  final candidates = IdentificationWireValidation.array(property['candidates']);
  final selectorCandidates = <SelectorCandidate<String, Object?>>[
    for (var index = 0; index < candidates.length; index++)
      _parseCandidate(candidates[index], index),
  ];
  final selector = Selector<String, Object?>(candidates: selectorCandidates);
  final expectedSelectorCandidateId = PropertySelectorCandidateId(
    IdentificationWireValidation.uuid(property['selected_candidate_id']),
  );
  if (!selectorCandidates.any(
    (candidate) => candidate.id == expectedSelectorCandidateId.value,
  )) {
    IdentificationWireValidation.invalid();
  }
  return IdentificationProperty(
    ordinal: IdentificationWireValidation.ordinal(
      property['ordinal'],
      expectedOrdinal,
    ),
    definition: definition,
    selector: selector,
    expectedSelectorCandidateId: expectedSelectorCandidateId,
  );
}

SelectorCandidate<String, Object?> _parseCandidate(
  Object? value,
  int expectedOrdinal,
) {
  final candidate = IdentificationWireValidation.object(value, const {
    'id',
    'ordinal',
    'weight',
    'result_kind',
    'result_id',
  });
  final id = IdentificationWireValidation.uuid(candidate['id']);
  final weight =
      IdentificationWireValidation.positiveWeight(candidate['weight']);
  IdentificationWireValidation.ordinal(candidate['ordinal'], expectedOrdinal);
  return switch (candidate['result_kind']) {
    'value' => SelectorCandidate<String, Object?>.value(
        id: id,
        weight: weight,
        value: IdentificationWireValidation.string(candidate['result_id']),
      ),
    'none' when candidate['result_id'] == null =>
      SelectorCandidate<String, Object?>.none(id: id, weight: weight),
    _ => IdentificationWireValidation.invalid(),
  };
}
