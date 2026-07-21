import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/encounter_content.dart';
import 'package:earth_nova/core/domain/content/exact_version_ref.dart';
import 'package:earth_nova/core/domain/content/stable_content_id.dart';
import 'package:earth_nova/core/domain/content/venue_content.dart';
import 'package:earth_nova/core/domain/entities/venue_id.dart';

/// Type marker for stable Condition content references.
///
/// Concrete condition kinds and evaluation belong to the rules slice.
final class ConditionContent {
  const ConditionContent._();
}

/// A stable reference to reusable authored Condition content.
typedef ConditionId = StableContentId<ConditionContent>;

/// Type marker for stable Selector content references.
final class SelectorContent {
  const SelectorContent._();
}

/// A stable reference to reusable authored Selector content.
typedef SelectorId = StableContentId<SelectorContent>;

/// An immutable nonblank identity for durable encounter-side records.
abstract class _NonBlankId {
  _NonBlankId(String value) : value = _canonical(value);

  final String value;

  static String _canonical(String value) {
    final canonical = value.trim();
    if (canonical.isEmpty) {
      throw ArgumentError.value(value, 'value', 'must not be blank');
    }
    return canonical;
  }

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

/// Identity for one durable Encounter occurrence.
final class EncounterId extends _NonBlankId {
  EncounterId(super.value);
}

/// Identity for one durable Cell Visit.
final class CellVisitId extends _NonBlankId {
  CellVisitId(super.value);
}

/// Identity for one immutable Cell Visit resolution.
final class CellVisitResolutionId extends _NonBlankId {
  CellVisitResolutionId(super.value);
}

/// Identity for one authored Encounter Option.
final class EncounterOptionId extends _NonBlankId {
  EncounterOptionId(super.value);
}

/// Identity for one authored Encounter Outcome.
final class EncounterOutcomeId extends _NonBlankId {
  EncounterOutcomeId(super.value);
}

/// Identity for one selected Selector candidate.
final class SelectorCandidateId extends _NonBlankId {
  SelectorCandidateId(super.value);
}

/// Identity for one immutable committed Encounter Outcome result.
final class EncounterOutcomeResultId extends _NonBlankId {
  EncounterOutcomeResultId(super.value);
}

/// A stable authored Encounter Definition identity.
///
/// It has no mutable latest-version lookup. An occurrence binds an exact
/// [EncounterDefinitionVersion.version] instead.
final class EncounterDefinition {
  const EncounterDefinition({required this.id});

  final StableContentId<EncounterContent> id;
}

/// One immutable version of an authored Encounter Definition.
final class EncounterDefinitionVersion {
  factory EncounterDefinitionVersion({
    required EncounterDefinition definition,
    required ExactVersionRef<EncounterContent> version,
    required String displayName,
    StableContentId<ConditionContent>? eligibilityConditionId,
    required bool isAutomatic,
    required Iterable<EncounterOption> options,
  }) {
    if (definition.id != version.stableId) {
      throw ArgumentError.value(
        version,
        'version',
        'must belong to definition.id',
      );
    }
    final canonicalDisplayName = _nonBlank(displayName, 'displayName');
    final orderedOptions = List<EncounterOption>.of(options);
    if (orderedOptions.isEmpty) {
      throw ArgumentError.value(options, 'options', 'must not be empty');
    }
    _validateOrdinals(orderedOptions, (option) => option.ordinal, 'options');
    orderedOptions.sort((left, right) => left.ordinal.compareTo(right.ordinal));
    final immutableOptions = List<EncounterOption>.unmodifiable(orderedOptions);

    final implicitCount =
        immutableOptions.where((option) => option.isImplicit).length;
    if (isAutomatic && (immutableOptions.length != 1 || implicitCount != 1)) {
      throw ArgumentError.value(
        options,
        'options',
        'automatic Versions require exactly one implicit Option',
      );
    }
    if (!isAutomatic && implicitCount != 0) {
      throw ArgumentError.value(
        options,
        'options',
        'manual Versions must not contain implicit Options',
      );
    }

    return EncounterDefinitionVersion._(
      definition: definition,
      version: version,
      displayName: canonicalDisplayName,
      eligibilityConditionId: eligibilityConditionId,
      isAutomatic: isAutomatic,
      options: immutableOptions,
    );
  }

  const EncounterDefinitionVersion._({
    required this.definition,
    required this.version,
    required this.displayName,
    required this.eligibilityConditionId,
    required this.isAutomatic,
    required this.options,
  });

  /// The stable content identity being versioned.
  final EncounterDefinition definition;

  /// The exact immutable version identity and revision.
  final ExactVersionRef<EncounterContent> version;

  final String displayName;

  /// Optional stable eligibility Condition reference.
  final StableContentId<ConditionContent>? eligibilityConditionId;

  final bool isAutomatic;

  /// Ordered, immutable branches owned by this Version.
  final List<EncounterOption> options;
}

/// A resolvable ordered branch of an [EncounterDefinitionVersion].
final class EncounterOption {
  factory EncounterOption({
    required EncounterOptionId id,
    required int ordinal,
    required String displayName,
    StableContentId<ConditionContent>? conditionId,
    required bool isImplicit,
    required Iterable<EncounterOutcome> outcomes,
  }) {
    _validateOrdinal(ordinal, 'ordinal');
    final orderedOutcomes = List<EncounterOutcome>.of(outcomes);
    if (orderedOutcomes.isEmpty) {
      throw ArgumentError.value(outcomes, 'outcomes', 'must not be empty');
    }
    _validateOrdinals(
      orderedOutcomes,
      (outcome) => outcome.ordinal,
      'outcomes',
    );
    orderedOutcomes
        .sort((left, right) => left.ordinal.compareTo(right.ordinal));
    final immutableOutcomes =
        List<EncounterOutcome>.unmodifiable(orderedOutcomes);
    return EncounterOption._(
      id: id,
      ordinal: ordinal,
      displayName: _nonBlank(displayName, 'displayName'),
      conditionId: conditionId,
      isImplicit: isImplicit,
      outcomes: immutableOutcomes,
    );
  }

  const EncounterOption._({
    required this.id,
    required this.ordinal,
    required this.displayName,
    required this.conditionId,
    required this.isImplicit,
    required this.outcomes,
  });

  final EncounterOptionId id;
  final int ordinal;
  final String displayName;

  /// Optional stable eligibility Condition reference.
  final StableContentId<ConditionContent>? conditionId;

  final bool isImplicit;

  /// Ordered, immutable operations applied when this option resolves.
  final List<EncounterOutcome> outcomes;
}

/// An atomic typed operation in an ordered [EncounterOption.outcomes] sequence.
sealed class EncounterOutcome {
  const EncounterOutcome({required this.id, required this.ordinal});

  final EncounterOutcomeId id;
  final int ordinal;
}

/// Generates exactly one Item from the selected Base Item's current Version.
///
/// Authored content names only [baseItemId]. The exact Base Item Version belongs
/// only in the committed [GenerateItemOutcomeResult].
final class GenerateItemOutcome extends EncounterOutcome {
  GenerateItemOutcome({
    required super.id,
    required super.ordinal,
    required this.baseItemId,
  }) {
    _validateOrdinal(ordinal, 'ordinal');
  }

  final StableContentId<BaseItemContent> baseItemId;
}

/// Makes one Venue known to the Player.
final class RevealVenueOutcome extends EncounterOutcome {
  RevealVenueOutcome({
    required super.id,
    required super.ordinal,
    required this.venueId,
  }) {
    _validateOrdinal(ordinal, 'ordinal');
  }

  final VenueId venueId;
}

/// One immutable resolved Cell Visit selector result.
final class CellVisitResolution {
  factory CellVisitResolution.none({
    required CellVisitResolutionId id,
    required CellVisitId cellVisitId,
    required SelectorId selectorId,
    required SelectorCandidateId selectorCandidateId,
    required DateTime resolvedAt,
  }) =>
      CellVisitResolution._(
        id: id,
        cellVisitId: cellVisitId,
        selectorId: selectorId,
        selectorCandidateId: selectorCandidateId,
        result: const NoEncounterDefinitionSelection(),
        resolvedAt: resolvedAt,
      );

  factory CellVisitResolution.selectedDefinition({
    required CellVisitResolutionId id,
    required CellVisitId cellVisitId,
    required SelectorId selectorId,
    required SelectorCandidateId selectorCandidateId,
    required StableContentId<EncounterContent> definitionId,
    required DateTime resolvedAt,
  }) =>
      CellVisitResolution._(
        id: id,
        cellVisitId: cellVisitId,
        selectorId: selectorId,
        selectorCandidateId: selectorCandidateId,
        result: EncounterDefinitionSelection(definitionId),
        resolvedAt: resolvedAt,
      );

  const CellVisitResolution._({
    required this.id,
    required this.cellVisitId,
    required this.selectorId,
    required this.selectorCandidateId,
    required this.result,
    required this.resolvedAt,
  });

  final CellVisitResolutionId id;
  final CellVisitId cellVisitId;
  final SelectorId selectorId;
  final SelectorCandidateId selectorCandidateId;
  final CellVisitResolutionResult result;
  final DateTime resolvedAt;
}

/// The closed result set of a Cell Visit's Encounter Definition selector.
sealed class CellVisitResolutionResult {
  const CellVisitResolutionResult();
}

/// An explicit selected None candidate; no Encounter occurrence is created.
final class NoEncounterDefinitionSelection extends CellVisitResolutionResult {
  const NoEncounterDefinitionSelection();
}

/// A selected stable Encounter Definition candidate.
final class EncounterDefinitionSelection extends CellVisitResolutionResult {
  const EncounterDefinitionSelection(this.definitionId);

  final StableContentId<EncounterContent> definitionId;
}

/// Durable resolution state for an [EncounterOccurrence].
enum EncounterResolutionStatus { pending, resolved, failed }

/// Immutable runtime failure evidence for a failed Encounter occurrence.
final class EncounterFailure {
  factory EncounterFailure({
    required String code,
    Map<String, String> details = const {},
  }) =>
      EncounterFailure._(
        code: _nonBlank(code, 'code'),
        details: Map<String, String>.unmodifiable(details),
      );

  const EncounterFailure._({required this.code, required this.details});

  final String code;

  /// String-only structured diagnostics; never executable or dynamic payload.
  final Map<String, String> details;
}

/// One player-owned Encounter occurrence bound to an exact Definition Version.
final class EncounterOccurrence {
  factory EncounterOccurrence({
    required EncounterId id,
    required CellVisitId cellVisitId,
    required CellVisitResolutionId cellVisitResolutionId,
    required ExactVersionRef<EncounterContent> definitionVersion,
    required EncounterResolutionStatus status,
    required DateTime createdAt,
    EncounterOptionId? selectedOptionId,
    DateTime? resolvedAt,
    EncounterFailure? failure,
  }) {
    switch (status) {
      case EncounterResolutionStatus.pending:
        if (selectedOptionId != null || resolvedAt != null || failure != null) {
          throw ArgumentError(
            'Pending Encounters must not have a selected Option, resolution time, or failure.',
          );
        }
      case EncounterResolutionStatus.resolved:
        if (selectedOptionId == null || resolvedAt == null || failure != null) {
          throw ArgumentError(
            'Resolved Encounters require a selected Option and resolution time, without failure.',
          );
        }
      case EncounterResolutionStatus.failed:
        if (resolvedAt != null || failure == null) {
          throw ArgumentError(
            'Failed Encounters require failure evidence and no resolution time.',
          );
        }
    }
    return EncounterOccurrence._(
      id: id,
      cellVisitId: cellVisitId,
      cellVisitResolutionId: cellVisitResolutionId,
      definitionVersion: definitionVersion,
      status: status,
      createdAt: createdAt,
      selectedOptionId: selectedOptionId,
      resolvedAt: resolvedAt,
      failure: failure,
    );
  }

  const EncounterOccurrence._({
    required this.id,
    required this.cellVisitId,
    required this.cellVisitResolutionId,
    required this.definitionVersion,
    required this.status,
    required this.createdAt,
    required this.selectedOptionId,
    required this.resolvedAt,
    required this.failure,
  });

  final EncounterId id;
  final CellVisitId cellVisitId;
  final CellVisitResolutionId cellVisitResolutionId;

  /// Exact immutable content binding selected when this occurrence was created.
  final ExactVersionRef<EncounterContent> definitionVersion;

  final EncounterResolutionStatus status;
  final DateTime createdAt;
  final EncounterOptionId? selectedOptionId;
  final DateTime? resolvedAt;
  final EncounterFailure? failure;
}

/// Immutable durable evidence of one committed ordered Encounter Outcome.
sealed class EncounterOutcomeResult {
  const EncounterOutcomeResult({
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

/// Committed result of [GenerateItemOutcome].
///
/// The exact Base Item Version is intentionally absent when its generated Item
/// remains unidentified. Identification is the sole player-facing reveal path.
final class GenerateItemOutcomeResult extends EncounterOutcomeResult {
  GenerateItemOutcomeResult({
    required super.id,
    required super.encounterId,
    required super.outcomeId,
    required super.ordinal,
    required super.createdAt,
    this.resolvedBaseItemVersion,
  }) {
    _validateOrdinal(ordinal, 'ordinal');
  }

  final ExactVersionRef<BaseItemContent>? resolvedBaseItemVersion;
}

/// Committed result of [RevealVenueOutcome], bound to an exact Venue Version.
final class RevealVenueOutcomeResult extends EncounterOutcomeResult {
  RevealVenueOutcomeResult({
    required super.id,
    required super.encounterId,
    required super.outcomeId,
    required super.ordinal,
    required super.createdAt,
    required this.venueId,
    required this.resolvedVenueVersion,
  }) {
    _validateOrdinal(ordinal, 'ordinal');
    if (resolvedVenueVersion.stableId.value != venueId.value) {
      throw ArgumentError.value(
        resolvedVenueVersion,
        'resolvedVenueVersion',
        'must belong to venueId',
      );
    }
  }

  /// The stable Venue made known by this committed outcome.
  final VenueId venueId;

  /// The immutable published Venue Version first made known by this outcome.
  final ExactVersionRef<VenueContent> resolvedVenueVersion;
}

String _nonBlank(String value, String name) {
  final canonical = value.trim();
  if (canonical.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be blank');
  }
  return canonical;
}

void _validateOrdinal(int ordinal, String name) {
  if (ordinal < 0) {
    throw ArgumentError.value(ordinal, name, 'must be nonnegative');
  }
}

void _validateOrdinals<T>(
  Iterable<T> values,
  int Function(T value) ordinalOf,
  String name,
) {
  final ordinals = <int>{};
  for (final value in values) {
    final ordinal = ordinalOf(value);
    _validateOrdinal(ordinal, name);
    if (!ordinals.add(ordinal)) {
      throw ArgumentError.value(values, name, 'must have unique ordinals');
    }
  }
}
