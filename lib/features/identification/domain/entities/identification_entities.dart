import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/domain/rules/selector.dart';
import 'package:earth_nova/features/item_knowledge/domain/entities/item_knowledge_entities.dart';
import 'package:earth_nova/features/living_world/domain/entities/authored_living_world_entities.dart';

/// Exact current Service evidence supplied by the authoritative preparation.
final class IdentificationServiceAccess {
  factory IdentificationServiceAccess({
    required VillagerId villagerId,
    required String villagerDisplayName,
    required ServiceId serviceId,
    required ExactVersionRef<ServiceContent> serviceVersion,
    required String serviceDisplayName,
  }) {
    if (serviceId.value != serviceVersion.stableId.value) {
      throw ArgumentError.value(
        serviceVersion,
        'serviceVersion',
        'must belong to serviceId',
      );
    }
    return IdentificationServiceAccess._(
      villagerId: villagerId,
      villagerDisplayName: villagerDisplayName,
      serviceId: serviceId,
      serviceVersion: serviceVersion,
      serviceDisplayName: serviceDisplayName,
    );
  }

  const IdentificationServiceAccess._({
    required this.villagerId,
    required this.villagerDisplayName,
    required this.serviceId,
    required this.serviceVersion,
    required this.serviceDisplayName,
  });

  final VillagerId villagerId;
  final String villagerDisplayName;
  final ServiceId serviceId;
  final ExactVersionRef<ServiceContent> serviceVersion;
  final String serviceDisplayName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdentificationServiceAccess &&
          villagerId == other.villagerId &&
          villagerDisplayName == other.villagerDisplayName &&
          serviceId == other.serviceId &&
          serviceVersion == other.serviceVersion &&
          serviceDisplayName == other.serviceDisplayName;

  @override
  int get hashCode => Object.hash(
        villagerId,
        villagerDisplayName,
        serviceId,
        serviceVersion,
        serviceDisplayName,
      );
}

/// Immutable server-prepared input for one exact Item Identification command.
///
/// The Item's exact Base Item Version is carried by [item]. The planner never
/// resolves a newer authored version and never mutates this preparation.
final class IdentificationPreparation {
  factory IdentificationPreparation({
    required ItemKnowledgeItemRef item,
    required bool playerDiscovered,
    required IdentificationServiceAccess serviceAccess,
    required Iterable<IdentificationProperty> properties,
  }) =>
      IdentificationPreparation._(
        item: item,
        playerDiscovered: playerDiscovered,
        properties: List<IdentificationProperty>.unmodifiable(properties),
        serviceAccess: serviceAccess,
      );

  const IdentificationPreparation._({
    required this.item,
    required this.playerDiscovered,
    required this.properties,
    required this.serviceAccess,
  });

  final ItemKnowledgeItemRef item;
  final bool playerDiscovered;
  final List<IdentificationProperty> properties;
  final IdentificationServiceAccess serviceAccess;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdentificationPreparation &&
          item == other.item &&
          playerDiscovered == other.playerDiscovered &&
          _sameList(properties, other.properties) &&
          serviceAccess == other.serviceAccess;

  @override
  int get hashCode => Object.hash(
        item,
        playerDiscovered,
        Object.hashAll(properties),
        serviceAccess,
      );
}

/// One ordered Variable Property assignment from an exact Base Item Version.
///
/// [selector] uses the shared generic weighting algorithm.
/// Identification does not support conditional candidates yet; the identification
/// planner rejects them before resolving any candidate.
final class IdentificationProperty {
  factory IdentificationProperty({
    required int ordinal,
    required VariablePropertyDefinition definition,
    required Selector<String, Object?> selector,
    required PropertySelectorCandidateId expectedSelectorCandidateId,
  }) {
    if (ordinal < 0) {
      throw ArgumentError.value(ordinal, 'ordinal', 'must not be negative');
    }
    return IdentificationProperty._(
      ordinal: ordinal,
      definition: definition,
      selector: selector,
      expectedSelectorCandidateId: expectedSelectorCandidateId,
    );
  }

  const IdentificationProperty._({
    required this.ordinal,
    required this.definition,
    required this.selector,
    required this.expectedSelectorCandidateId,
  });

  final int ordinal;
  final VariablePropertyDefinition definition;
  final Selector<String, Object?> selector;

  final PropertySelectorCandidateId expectedSelectorCandidateId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IdentificationProperty &&
          ordinal == other.ordinal &&
          definition == other.definition &&
          _sameSelector(selector, other.selector) &&
          expectedSelectorCandidateId == other.expectedSelectorCandidateId;

  @override
  int get hashCode => Object.hash(
        ordinal,
        definition,
        _selectorHash(selector),
        expectedSelectorCandidateId,
      );
}

/// One immutable planned resolution, including exact authored candidate
/// evidence and an explicit concrete-or-None outcome.
final class PlannedPropertyResolution {
  factory PlannedPropertyResolution({
    required int ordinal,
    required VariablePropertyDefinition definition,
    required PropertySelectorCandidateId selectorCandidateId,
    required PropertyValueResolution resolution,
  }) {
    if (ordinal < 0) {
      throw ArgumentError.value(ordinal, 'ordinal', 'must not be negative');
    }
    return PlannedPropertyResolution._(
      ordinal: ordinal,
      definition: definition,
      selectorCandidateId: selectorCandidateId,
      resolution: resolution,
    );
  }

  const PlannedPropertyResolution._({
    required this.ordinal,
    required this.definition,
    required this.selectorCandidateId,
    required this.resolution,
  });

  final int ordinal;
  final VariablePropertyDefinition definition;
  final PropertySelectorCandidateId selectorCandidateId;
  final PropertyValueResolution resolution;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlannedPropertyResolution &&
          ordinal == other.ordinal &&
          definition == other.definition &&
          selectorCandidateId == other.selectorCandidateId &&
          resolution == other.resolution;

  @override
  int get hashCode => Object.hash(
        ordinal,
        definition,
        selectorCandidateId,
        resolution,
      );
}

/// An immutable complete Identification command payload.
///
/// This is deliberately a value object: a caller retains this exact instance
/// for commit retry instead of asking the planner to resolve candidates again.
final class ItemIdentificationPlan {
  factory ItemIdentificationPlan({
    required ItemKnowledgeItemRef item,
    required IdentificationServiceAccess serviceAccess,
    required Iterable<PlannedPropertyResolution> propertyResolutions,
  }) {
    final resolutions = List<PlannedPropertyResolution>.unmodifiable(
      propertyResolutions,
    );
    _validatePlannedResolutions(item, resolutions);
    return ItemIdentificationPlan._(
      item: item,
      propertyResolutions: resolutions,
      serviceAccess: serviceAccess,
    );
  }

  const ItemIdentificationPlan._({
    required this.item,
    required this.propertyResolutions,
    required this.serviceAccess,
  });

  final ItemKnowledgeItemRef item;
  final List<PlannedPropertyResolution> propertyResolutions;

  final IdentificationServiceAccess serviceAccess;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemIdentificationPlan &&
          item == other.item &&
          _sameList(propertyResolutions, other.propertyResolutions) &&
          serviceAccess == other.serviceAccess;

  @override
  int get hashCode =>
      Object.hash(item, Object.hashAll(propertyResolutions), serviceAccess);
}

/// The immutable canonical result of a successfully committed Identification.
///
/// The repository returns a result only after the server has atomically
/// committed the Item projection, canonical Discovery, Property Values, and
/// command receipt. The result retains the original exact plan evidence.
final class ItemIdentificationResult {
  factory ItemIdentificationResult({
    required ItemKnowledgeItemRef item,
    required Item committedItem,
    required ItemDiscovery discovery,
    required Iterable<PropertyValue> propertyValues,
    required ItemIdentificationPlan identification,
  }) {
    if (item != identification.item) {
      throw ArgumentError.value(
        identification,
        'identification',
        'must belong to item',
      );
    }
    if (discovery.playerId != item.playerId ||
        discovery.baseItemId != item.baseItemId) {
      throw ArgumentError.value(
        discovery,
        'discovery',
        'must belong to item player and stable Base Item',
      );
    }

    if (committedItem.id != item.id.value ||
        committedItem.baseItemId != item.baseItemId.value ||
        committedItem.baseItemVersionId !=
            item.baseItemVersion.versionId.value ||
        committedItem.identificationState !=
            ItemIdentificationState.identified) {
      throw ArgumentError.value(
        committedItem,
        'committedItem',
        'must retain the identified Item exact binding',
      );
    }

    final values = List<PropertyValue>.unmodifiable(propertyValues);
    if (values.length != identification.propertyResolutions.length) {
      throw ArgumentError.value(
        propertyValues,
        'propertyValues',
        'must be complete for identification',
      );
    }
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      final planned = identification.propertyResolutions[index];
      if (value.item != item ||
          value.definition != planned.definition ||
          value.resolution != planned.resolution) {
        throw ArgumentError.value(
          value,
          'propertyValues',
          'must be ordered and match the exact planned resolution',
        );
      }
    }

    return ItemIdentificationResult._(
      item: item,
      committedItem: committedItem,
      discovery: discovery,
      propertyValues: values,
      identification: identification,
    );
  }

  const ItemIdentificationResult._({
    required this.item,
    required this.discovery,
    required this.propertyValues,
    required this.identification,
    required this.committedItem,
  });

  final ItemKnowledgeItemRef item;
  final ItemDiscovery discovery;
  final List<PropertyValue> propertyValues;
  final Item committedItem;
  final ItemIdentificationPlan identification;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemIdentificationResult &&
          item == other.item &&
          committedItem == other.committedItem &&
          discovery == other.discovery &&
          _sameList(propertyValues, other.propertyValues) &&
          identification == other.identification;

  @override
  int get hashCode => Object.hash(
        item,
        discovery,
        Object.hashAll(propertyValues),
        identification,
        committedItem,
      );
}

bool _sameList<T>(List<T> first, List<T> second) {
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}

bool _sameSelector(
  Selector<String, Object?> first,
  Selector<String, Object?> second,
) {
  if (first.candidates.length != second.candidates.length) return false;
  for (var index = 0; index < first.candidates.length; index++) {
    final firstCandidate = first.candidates[index];
    final secondCandidate = second.candidates[index];
    if (firstCandidate.id != secondCandidate.id ||
        firstCandidate.weight != secondCandidate.weight ||
        firstCandidate.condition != secondCandidate.condition ||
        firstCandidate.result != secondCandidate.result) {
      return false;
    }
  }
  return true;
}

int _selectorHash(Selector<String, Object?> selector) => Object.hashAll(
      selector.candidates.map(
        (candidate) => Object.hash(
          candidate.id,
          candidate.weight,
          candidate.condition,
          candidate.result,
        ),
      ),
    );

void _validatePlannedResolutions(
  ItemKnowledgeItemRef item,
  List<PlannedPropertyResolution> resolutions,
) {
  final definitionIds = <VariablePropertyDefinitionId>{};
  for (var index = 0; index < resolutions.length; index++) {
    final resolution = resolutions[index];
    if (resolution.ordinal != index) {
      throw ArgumentError.value(
        resolution.ordinal,
        'propertyResolutions',
        'must have dense ordered ordinals starting at zero',
      );
    }
    if (resolution.definition.baseItemVersion != item.baseItemVersion) {
      throw ArgumentError.value(
        resolution.definition,
        'propertyResolutions',
        'must belong to item.baseItemVersion exactly',
      );
    }
    if (!definitionIds.add(resolution.definition.id)) {
      throw ArgumentError.value(
        resolution.definition.id,
        'propertyResolutions',
        'must not resolve a Variable Property more than once',
      );
    }
  }
}
