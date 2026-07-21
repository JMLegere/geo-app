import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/identification/data/dtos/identification_wire_validation.dart';
import 'package:earth_nova/features/identification/data/dtos/item_dto.dart';
import 'package:earth_nova/features/identification/domain/entities/identification_entities.dart';
import 'package:earth_nova/features/item_knowledge/domain/entities/item_knowledge_entities.dart';

/// Strict wire binding for identify_v3_item's committed aggregate.
final class IdentificationAggregateDto {
  const IdentificationAggregateDto._(this._value);

  final ItemIdentificationResult _value;

  factory IdentificationAggregateDto.fromJson(
    Map<String, dynamic> json, {
    required ItemIdentificationPlan plan,
  }) {
    final root = IdentificationWireValidation.object(json, const {
      'item',
      'discovery',
      'property_values',
      'identification',
    });
    final committedItem = _parseAndValidateItem(root['item'], plan.item);
    final discovery = _parseDiscovery(root['discovery'], plan.item);
    final propertyValues = _parsePropertyValues(root['property_values'], plan);
    _parseReceipt(root['identification']);
    return IdentificationAggregateDto._(
      ItemIdentificationResult(
        item: plan.item,
        committedItem: committedItem,
        discovery: discovery,
        propertyValues: propertyValues,
        identification: plan,
      ),
    );
  }

  ItemIdentificationResult toDomain() => _value;
}

Item _parseAndValidateItem(Object? value, ItemKnowledgeItemRef expected) {
  final item = IdentificationWireValidation.object(value, const {
    'id',
    'user_id',
    'definition_id',
    'display_name',
    'scientific_name',
    'category',
    'rarity',
    'icon_url',
    'icon_url_frame2',
    'art_url',
    'acquired_at',
    'acquired_in_cell_id',
    'status',
    'taxonomic_class',
    'habitats_json',
    'continents_json',
    'identification_state',
    'identified_at',
    'base_item_id',
    'base_item_version_id',
    'base_item_revision',
  });
  if (IdentificationWireValidation.uuid(item['id']) != expected.id.value ||
      IdentificationWireValidation.uuid(item['user_id']) != expected.playerId ||
      IdentificationWireValidation.string(item['base_item_id']) !=
          expected.baseItemId.value ||
      IdentificationWireValidation.uuid(item['base_item_version_id']) !=
          expected.baseItemVersion.versionId.value ||
      IdentificationWireValidation.positiveInt(item['base_item_revision']) !=
          expected.baseItemVersion.revision ||
      item['identification_state'] != 'identified') {
    IdentificationWireValidation.invalid();
  }
  IdentificationWireValidation.string(item['definition_id']);
  IdentificationWireValidation.string(item['display_name']);
  IdentificationWireValidation.nullableString(item['scientific_name']);
  if (item['category'] is! String ||
      !ItemCategory.values
          .any((category) => category.name == item['category'])) {
    IdentificationWireValidation.invalid();
  }
  IdentificationWireValidation.nullableString(item['rarity']);
  IdentificationWireValidation.nullableString(item['icon_url']);
  IdentificationWireValidation.nullableString(item['icon_url_frame2']);
  IdentificationWireValidation.nullableString(item['art_url']);
  IdentificationWireValidation.timestamp(item['acquired_at']);
  IdentificationWireValidation.nullableUuid(item['acquired_in_cell_id']);
  if (item['status'] is! String ||
      !ItemStatus.values.any((status) => status.name == item['status'])) {
    IdentificationWireValidation.invalid();
  }
  IdentificationWireValidation.nullableString(item['taxonomic_class']);
  IdentificationWireValidation.jsonStringArray(item['habitats_json']);
  IdentificationWireValidation.jsonStringArray(item['continents_json']);
  IdentificationWireValidation.timestamp(item['identified_at']);

  try {
    return ItemDto.fromJson(item).toDomain();
  } catch (_) {
    IdentificationWireValidation.invalid();
  }
}

ItemDiscovery _parseDiscovery(Object? value, ItemKnowledgeItemRef expected) {
  final discovery = IdentificationWireValidation.object(value, const {
    'user_id',
    'base_item_id',
    'first_identified_item_id',
    'first_base_item_version_id',
    'provenance',
    'discovered_at',
  });
  if (IdentificationWireValidation.uuid(discovery['user_id']) !=
          expected.playerId ||
      IdentificationWireValidation.string(discovery['base_item_id']) !=
          expected.baseItemId.value ||
      IdentificationWireValidation.uuid(
              discovery['first_identified_item_id']) !=
          expected.id.value ||
      IdentificationWireValidation.uuid(
            discovery['first_base_item_version_id'],
          ) !=
          expected.baseItemVersion.versionId.value) {
    IdentificationWireValidation.invalid();
  }
  IdentificationWireValidation.string(discovery['provenance']);
  IdentificationWireValidation.timestamp(discovery['discovered_at']);
  return ItemDiscovery(
    playerId: expected.playerId,
    baseItemId: expected.baseItemId,
  );
}

List<PropertyValue> _parsePropertyValues(
  Object? value,
  ItemIdentificationPlan plan,
) {
  final rows = IdentificationWireValidation.array(value);
  if (rows.length != plan.propertyResolutions.length) {
    IdentificationWireValidation.invalid();
  }
  return List<PropertyValue>.unmodifiable([
    for (var index = 0; index < rows.length; index++)
      _parsePropertyValue(rows[index], plan, index),
  ]);
}

PropertyValue _parsePropertyValue(
  Object? value,
  ItemIdentificationPlan plan,
  int expectedOrdinal,
) {
  final row = IdentificationWireValidation.object(value, const {
    'ordinal',
    'variable_property_key',
    'selector_id',
    'selector_candidate_id',
    'resolution_kind',
    'resolved_value_id',
    'resolved_at',
  });
  final planned = plan.propertyResolutions[expectedOrdinal];
  if (IdentificationWireValidation.ordinal(row['ordinal'], expectedOrdinal) !=
          planned.ordinal ||
      IdentificationWireValidation.string(row['variable_property_key']) !=
          planned.definition.id.value ||
      IdentificationWireValidation.string(row['selector_id']) !=
          planned.definition.selectorId.value ||
      IdentificationWireValidation.uuid(row['selector_candidate_id']) !=
          planned.selectorCandidateId.value) {
    IdentificationWireValidation.invalid();
  }
  final resolution = switch (planned.resolution) {
    SelectedPropertyValue(:final valueId)
        when row['resolution_kind'] == 'value' &&
            row['resolved_value_id'] == valueId =>
      planned.resolution,
    NoPropertyValue()
        when row['resolution_kind'] == 'none' &&
            row['resolved_value_id'] == null =>
      planned.resolution,
    _ => IdentificationWireValidation.invalid(),
  };
  IdentificationWireValidation.timestamp(row['resolved_at']);
  return PropertyValue(
    item: plan.item,
    definition: planned.definition,
    resolution: resolution,
  );
}

void _parseReceipt(Object? value) {
  final receipt = IdentificationWireValidation.object(value, const {
    'kind',
    'committed_at',
  });
  if (receipt['kind'] != 'explicit') IdentificationWireValidation.invalid();
  IdentificationWireValidation.timestamp(receipt['committed_at']);
}
