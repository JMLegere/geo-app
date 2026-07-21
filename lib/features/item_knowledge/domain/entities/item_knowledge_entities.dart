import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/exact_version_ref.dart';
import 'package:earth_nova/core/domain/content/stable_content_id.dart';
import 'package:earth_nova/core/domain/entities/item.dart';

/// A stable authored Base Item identity.
typedef BaseItemId = StableContentId<BaseItemContent>;

/// An immutable binding to one authored Base Item Version.
typedef BaseItemVersion = ExactVersionRef<BaseItemContent>;

/// An immutable nonblank identity used only by Item Knowledge contracts.
abstract class _NonBlankId {
  _NonBlankId(String value) : value = _nonBlank(value, 'value');

  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other.runtimeType == runtimeType &&
          other is _NonBlankId &&
          value == other.value;

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => value;
}

/// Identity for one durable generated Item as used by Item Knowledge.
final class ItemKnowledgeItemId extends _NonBlankId {
  ItemKnowledgeItemId(super.value);
}

/// Identity for one Variable Property definition.
final class VariablePropertyDefinitionId extends _NonBlankId {
  VariablePropertyDefinitionId(super.value);
}

/// Identity for the Selector owned by one Variable Property definition.
final class PropertySelectorId extends _NonBlankId {
  PropertySelectorId(super.value);
}

/// Identity for one authored candidate within a Property Selector.
final class PropertySelectorCandidateId extends _NonBlankId {
  PropertySelectorCandidateId(super.value);
}

/// The immutable Item linkage needed by Item Knowledge.
///
/// It deliberately contains the owner, stable Base Item identity, and exact
/// immutable Base Item Version. It does not resolve a newer Version.
final class ItemKnowledgeItemRef {
  factory ItemKnowledgeItemRef({
    required ItemKnowledgeItemId id,
    required String playerId,
    required BaseItemId baseItemId,
    required BaseItemVersion baseItemVersion,
  }) {
    if (baseItemVersion.stableId != baseItemId) {
      throw ArgumentError.value(
        baseItemVersion,
        'baseItemVersion',
        'must belong to baseItemId',
      );
    }
    return ItemKnowledgeItemRef._(
      id: id,
      playerId: _nonBlank(playerId, 'playerId'),
      baseItemId: baseItemId,
      baseItemVersion: baseItemVersion,
    );
  }

  const ItemKnowledgeItemRef._({
    required this.id,
    required this.playerId,
    required this.baseItemId,
    required this.baseItemVersion,
  });

  final ItemKnowledgeItemId id;
  final String playerId;
  final BaseItemId baseItemId;
  final BaseItemVersion baseItemVersion;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemKnowledgeItemRef &&
          id == other.id &&
          playerId == other.playerId &&
          baseItemId == other.baseItemId &&
          baseItemVersion == other.baseItemVersion;

  @override
  int get hashCode => Object.hash(id, playerId, baseItemId, baseItemVersion);
}

/// A player-scoped record that one stable Base Item is known.
///
/// Discovery intentionally keys the stable Base Item rather than an authored
/// Version, so a future Version does not create another Discovery.
final class ItemDiscovery {
  factory ItemDiscovery({
    required String playerId,
    required BaseItemId baseItemId,
  }) =>
      ItemDiscovery._(
        playerId: _nonBlank(playerId, 'playerId'),
        baseItemId: baseItemId,
      );

  const ItemDiscovery._({required this.playerId, required this.baseItemId});

  final String playerId;
  final BaseItemId baseItemId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemDiscovery &&
          playerId == other.playerId &&
          baseItemId == other.baseItemId;

  @override
  int get hashCode => Object.hash(playerId, baseItemId);
}

/// An effective Variable Property defined by one exact Base Item Version.
///
/// The Selector is named but not evaluated here; resolving it belongs to the
/// Identification runtime.
final class VariablePropertyDefinition {
  factory VariablePropertyDefinition({
    required VariablePropertyDefinitionId id,
    required BaseItemId baseItemId,
    required BaseItemVersion baseItemVersion,
    required PropertySelectorId selectorId,
  }) {
    if (baseItemVersion.stableId != baseItemId) {
      throw ArgumentError.value(
        baseItemVersion,
        'baseItemVersion',
        'must belong to baseItemId',
      );
    }
    return VariablePropertyDefinition._(
      id: id,
      baseItemId: baseItemId,
      baseItemVersion: baseItemVersion,
      selectorId: selectorId,
    );
  }

  const VariablePropertyDefinition._({
    required this.id,
    required this.baseItemId,
    required this.baseItemVersion,
    required this.selectorId,
  });

  final VariablePropertyDefinitionId id;
  final BaseItemId baseItemId;
  final BaseItemVersion baseItemVersion;
  final PropertySelectorId selectorId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VariablePropertyDefinition &&
          id == other.id &&
          baseItemId == other.baseItemId &&
          baseItemVersion == other.baseItemVersion &&
          selectorId == other.selectorId;

  @override
  int get hashCode => Object.hash(id, baseItemId, baseItemVersion, selectorId);
}

/// The explicit result of resolving a Variable Property Selector.
sealed class PropertyValueResolution {
  const PropertyValueResolution();
}

/// A concrete value selected by a Variable Property Selector.
final class SelectedPropertyValue extends PropertyValueResolution {
  SelectedPropertyValue(String valueId)
      : valueId = _nonBlank(valueId, 'valueId');

  final String valueId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectedPropertyValue && valueId == other.valueId;

  @override
  int get hashCode => Object.hash(SelectedPropertyValue, valueId);
}

/// An explicit resolved absence from a Variable Property Selector.
final class NoPropertyValue extends PropertyValueResolution {
  const NoPropertyValue();

  @override
  bool operator ==(Object other) => other is NoPropertyValue;

  @override
  int get hashCode => Object.hash(NoPropertyValue, 0);
}

/// A permanent flattened Property Value on one Item.
///
/// The definition and Item must bind the exact same Base Item Version. A null
/// resolution is rejected so absence must be represented by [NoPropertyValue].
final class PropertyValue {
  factory PropertyValue({
    required ItemKnowledgeItemRef item,
    required VariablePropertyDefinition definition,
    required PropertyValueResolution? resolution,
  }) {
    if (item.baseItemVersion != definition.baseItemVersion) {
      throw ArgumentError.value(
        definition,
        'definition',
        'must belong to item.baseItemVersion exactly',
      );
    }
    if (resolution == null) {
      throw ArgumentError.value(
        resolution,
        'resolution',
        'must be explicit; use NoPropertyValue for a resolved absence',
      );
    }
    return PropertyValue._(
      item: item,
      definition: definition,
      resolution: resolution,
    );
  }

  const PropertyValue._({
    required this.item,
    required this.definition,
    required this.resolution,
  });

  final ItemKnowledgeItemRef item;
  final VariablePropertyDefinition definition;
  final PropertyValueResolution resolution;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PropertyValue &&
          item == other.item &&
          definition == other.definition &&
          resolution == other.resolution;

  @override
  int get hashCode => Object.hash(item, definition, resolution);
}

/// The five scientific activity tracks available to every Player.
enum Discipline {
  zoology,
  botany,
  geology,
  paleontology,
  archaeology;

  /// Returns no Discipline for categories that have no assigned field.
  static Discipline? forCategory(ItemCategory category) => switch (category) {
        ItemCategory.fauna => Discipline.zoology,
        ItemCategory.flora => Discipline.botany,
        ItemCategory.mineral => Discipline.geology,
        ItemCategory.fossil => Discipline.paleontology,
        ItemCategory.artifact => Discipline.archaeology,
        ItemCategory.food || ItemCategory.orb => null,
      };
}

/// A Player's accumulated progression state in one [Discipline].
///
/// This contract preserves XP and its visible Level without imposing an XP
/// curve, thresholds, unlocks, or activation behavior.
final class DisciplineProgress {
  factory DisciplineProgress({
    required String playerId,
    required Discipline discipline,
    required int experience,
    required int level,
  }) {
    if (experience < 0) {
      throw ArgumentError.value(
          experience, 'experience', 'must not be negative');
    }
    if (level <= 0) {
      throw ArgumentError.value(level, 'level', 'must be greater than zero');
    }
    return DisciplineProgress._(
      playerId: _nonBlank(playerId, 'playerId'),
      discipline: discipline,
      experience: experience,
      level: level,
    );
  }

  const DisciplineProgress._({
    required this.playerId,
    required this.discipline,
    required this.experience,
    required this.level,
  });

  final String playerId;
  final Discipline discipline;
  final int experience;
  final int level;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DisciplineProgress &&
          playerId == other.playerId &&
          discipline == other.discipline &&
          experience == other.experience &&
          level == other.level;

  @override
  int get hashCode => Object.hash(playerId, discipline, experience, level);
}

String _nonBlank(String value, String name) {
  final canonical = value.trim();
  if (canonical.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be blank');
  }
  return canonical;
}
