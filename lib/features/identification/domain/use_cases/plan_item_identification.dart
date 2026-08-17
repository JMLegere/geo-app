import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:earth_nova/core/domain/rules/selector.dart';
import 'package:earth_nova/core/observability/observable_use_case.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/identification/domain/entities/identification_entities.dart';
import 'package:earth_nova/features/item_knowledge/domain/entities/item_knowledge_entities.dart';
import 'package:earth_nova/features/item_knowledge/domain/rules/identification_requirement.dart';

/// Deterministically resolves every Variable Property for one prepared Item.
///
/// This use case is entirely pure. It derives each normalized roll from the
/// durable Item and Variable Property identities, evaluates no Conditions, and
/// does not call a repository, clock, random source, or progression system.
final class PlanItemIdentification extends ObservableUseCase<
    IdentificationPreparation, ItemIdentificationPlan> {
  const PlanItemIdentification(this._obs);

  final ObservabilityService _obs;

  @override
  ObservabilityService get obs => _obs;

  @override
  String get operationName => 'plan_item_identification';

  @override
  Future<ItemIdentificationPlan> execute(
    IdentificationPreparation preparation,
    String traceId,
  ) async {
    final properties = preparation.properties;
    _validateProperties(preparation.item, properties);

    if (!IdentificationRequirement.requires(
      playerDiscovered: preparation.playerDiscovered,
      variablePropertyCount: properties.length,
    )) {
      throw StateError('This Item does not require Identification.');
    }

    final resolutions = <PlannedPropertyResolution>[];
    for (final property in properties) {
      _validateConditionFreeSelector(property.selector);
      final candidate = property.selector.resolveCandidate(
        null,
        () => normalizedRollFor(
          itemId: preparation.item.id,
          variablePropertyId: property.definition.id,
        ),
      );
      if (candidate.id != property.expectedSelectorCandidateId.value) {
        throw StateError(
          'Prepared selector candidate does not match deterministic resolution.',
        );
      }
      resolutions.add(
        PlannedPropertyResolution(
          ordinal: property.ordinal,
          definition: property.definition,
          selectorCandidateId: PropertySelectorCandidateId(candidate.id),
          resolution: _propertyResolution(candidate),
        ),
      );
    }

    return ItemIdentificationPlan(
      item: preparation.item,
      serviceAccess: preparation.serviceAccess,
      propertyResolutions: resolutions,
    );
  }

  /// Computes the one normalized roll prescribed for an Item/property pair.
  ///
  /// The first eight hexadecimal SHA-256 digits form an unsigned 32-bit value
  /// which is divided by 2^32, therefore the result is always in [0, 1).
  static double normalizedRollFor({
    required ItemKnowledgeItemId itemId,
    required VariablePropertyDefinitionId variablePropertyId,
  }) {
    final input = '${itemId.value}\u001f${variablePropertyId.value}';
    final digest = sha256.convert(utf8.encode(input)).toString();
    final numerator = int.parse(digest.substring(0, 8), radix: 16);
    return numerator / 0x100000000;
  }
}

void _validateProperties(
  ItemKnowledgeItemRef item,
  List<IdentificationProperty> properties,
) {
  final definitionIds = <VariablePropertyDefinitionId>{};
  for (var index = 0; index < properties.length; index++) {
    final property = properties[index];
    if (property.ordinal != index) {
      throw ArgumentError.value(
        property.ordinal,
        'properties',
        'must have dense ordered ordinals starting at zero',
      );
    }
    if (property.definition.baseItemVersion != item.baseItemVersion) {
      throw ArgumentError.value(
        property.definition,
        'properties',
        'must belong to item.baseItemVersion exactly',
      );
    }
    if (!definitionIds.add(property.definition.id)) {
      throw ArgumentError.value(
        property.definition.id,
        'properties',
        'must not assign a Variable Property more than once',
      );
    }
  }
}

void _validateConditionFreeSelector(Selector<String, Object?> selector) {
  for (final candidate in selector.candidates) {
    if (candidate.condition != null) {
      throw ArgumentError.value(
        candidate,
        'selector',
        'conditioned candidates are not yet authoritatively supported',
      );
    }

    // Validate all authored outcomes before selecting one. In particular, this
    // rejects an invalid unselected value candidate instead of hiding it behind
    // weighted selection.
    _propertyResolution(candidate);
  }
}

PropertyValueResolution _propertyResolution(
  SelectorCandidate<String, Object?> candidate,
) =>
    switch (candidate.result) {
      SelectedValue<String>(:final value) => SelectedPropertyValue(value),
      SelectedNone<String>() => const NoPropertyValue(),
    };
