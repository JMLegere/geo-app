import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:earth_nova/core/domain/content/encounter_content.dart';
import 'package:earth_nova/core/domain/content/current_encounter_version_binding_repository.dart';
import 'package:earth_nova/core/domain/content/exact_version_ref.dart';
import 'package:earth_nova/core/domain/content/stable_content_id.dart';
import 'package:earth_nova/core/domain/rules/condition.dart';
import 'package:earth_nova/core/domain/rules/selector.dart';
import 'package:earth_nova/core/observability/observable_use_case.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/encounters/domain/entities/encounter_entities.dart';
import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';
import 'package:earth_nova/features/map/domain/rules/legacy_encounter_eligibility.dart';

/// The complete, immutable information needed to plan one Cell Visit selector
/// resolution. The roll source is injected so selection never has a hidden
/// dependency on mutable state or time.
final class ResolveCellVisitEncounterSelectorInput<Context> {
  const ResolveCellVisitEncounterSelectorInput({
    required this.cellVisit,
    required this.selectorId,
    required this.selector,
    required this.selectorContext,
    required this.rollSource,
  });

  /// The exact persisted visit that is being resolved.
  final CellVisit cellVisit;

  /// Stable identity of the authored Selector that was resolved.
  final SelectorId selectorId;

  /// The fully materialized Selector to resolve; it carries no repository.
  final Selector<StableContentId<EncounterContent>, Context> selector;

  /// Read-only context used only to evaluate candidate Conditions.
  final Context selectorContext;

  /// One normalized deterministic roll supplied by the caller.
  final NormalizedRollSource rollSource;
}

/// A pure resolution plan for one Cell Visit, apart from the one read-only
/// lookup that binds selected content to its exact current published Version.
sealed class CellVisitEncounterSelectionPlan {
  const CellVisitEncounterSelectionPlan({
    required this.cellVisit,
    required this.selectorId,
    required this.selectorCandidateId,
  });

  final CellVisit cellVisit;
  final SelectorId selectorId;
  final SelectorCandidateId selectorCandidateId;
}

/// An explicit selected None candidate. It deliberately has no Version binding.
final class NoEncounterCellVisitPlan extends CellVisitEncounterSelectionPlan {
  const NoEncounterCellVisitPlan({
    required super.cellVisit,
    required super.selectorId,
    required super.selectorCandidateId,
  });
}

/// A selected stable Encounter Definition, permanently bound to the exact
/// immutable Version returned while creating new state.
final class EncounterSelectedCellVisitPlan
    extends CellVisitEncounterSelectionPlan {
  const EncounterSelectedCellVisitPlan({
    required super.cellVisit,
    required super.selectorId,
    required super.selectorCandidateId,
    required this.definitionId,
    required this.definitionVersion,
    required this.isAutomatic,
  });

  final StableContentId<EncounterContent> definitionId;
  final ExactVersionRef<EncounterContent> definitionVersion;
  final bool isAutomatic;
}

/// The selected stable Definition cannot create new state without a current
/// published immutable Version.
final class MissingCurrentPublishedEncounterVersion implements Exception {
  const MissingCurrentPublishedEncounterVersion(this.definitionId);

  final StableContentId<EncounterContent> definitionId;

  @override
  String toString() =>
      'No current published Encounter Definition Version exists for '
      '${definitionId.value}.';
}

/// Resolves a Cell Visit Selector and binds a selected Definition to exactly
/// one immutable published Version. Existing state must use that binding, never
/// this use case or another current-version lookup.
final class ResolveCellVisitEncounterSelector<Context>
    extends ObservableUseCase<ResolveCellVisitEncounterSelectorInput<Context>,
        CellVisitEncounterSelectionPlan> {
  const ResolveCellVisitEncounterSelector(
    this._versionBindingRepository,
    this._obs,
  );

  final CurrentEncounterVersionBindingRepository _versionBindingRepository;
  final ObservabilityService _obs;

  @override
  ObservabilityService get obs => _obs;

  @override
  String get operationName => 'resolve_cell_visit_encounter_selector';

  @override
  Future<CellVisitEncounterSelectionPlan> execute(
    ResolveCellVisitEncounterSelectorInput<Context> input,
    String traceId,
  ) async {
    final candidate = input.selector.resolveCandidate(
      input.selectorContext,
      input.rollSource,
    );
    final candidateId = SelectorCandidateId(candidate.id);

    switch (candidate.result) {
      case SelectedNone<StableContentId<EncounterContent>>():
        return NoEncounterCellVisitPlan(
          cellVisit: input.cellVisit,
          selectorId: input.selectorId,
          selectorCandidateId: candidateId,
        );
      case SelectedValue<StableContentId<EncounterContent>>(:final value):
        final binding = await _versionBindingRepository
            .currentPublishedVersionForNewCellVisit(value, traceId: traceId);
        if (binding == null) {
          throw MissingCurrentPublishedEncounterVersion(value);
        }
        if (binding.version.stableId != value) {
          throw StateError(
            'The current published Encounter Definition Version for '
            '${value.value} belongs to ${binding.version.stableId.value}.',
          );
        }
        return EncounterSelectedCellVisitPlan(
          cellVisit: input.cellVisit,
          selectorId: input.selectorId,
          selectorCandidateId: candidateId,
          definitionId: value,
          definitionVersion: binding.version,
          isAutomatic: binding.isAutomatic,
        );
    }
  }
}

/// Stable identity of the compatibility Selector seeded for the legacy map
/// encounter catalog.
final SelectorId legacyCellEncounterSelectorId =
    SelectorId('selector:legacy-cell-encounter');

/// The canonical ordering shared with the legacy `ComputeEncounter` catalog.
const List<String> legacyCellEncounterSlugs = [
  'amberwing_warbler',
  'red_fox',
  'monarch_butterfly',
  'painted_turtle',
  'snowshoe_hare',
  'brook_trout',
  'great_blue_heron',
  'eastern_chipmunk',
];

/// Stable Encounter Definition identities in [legacyCellEncounterSlugs] order.
final List<StableContentId<EncounterContent>> legacyCellEncounterDefinitionIds =
    List<StableContentId<EncounterContent>>.unmodifiable([
  for (final slug in legacyCellEncounterSlugs)
    StableContentId<EncounterContent>('encounter:fauna:$slug'),
]);

/// Produces the lowercase PostgreSQL `md5(...)::uuid` representation used by
/// the compatibility selector candidate seed.
String legacyCellEncounterCandidateId(String slug) {
  final digest = md5
      .convert(
        utf8.encode('earthnova:legacy-encounter-selector-candidate:$slug'),
      )
      .toString();
  return '${digest.substring(0, 8)}-'
      '${digest.substring(8, 12)}-'
      '${digest.substring(12, 16)}-'
      '${digest.substring(16, 20)}-'
      '${digest.substring(20)}';
}

/// Builds the compatibility Selector with equal weights, explicit None, and
/// only the existing first-visit-or-loot Condition leaves. It is compatibility
/// behavior, not new canonical encounter policy.
Selector<StableContentId<EncounterContent>, LegacyEncounterEligibilityContext>
    buildLegacyCellEncounterCompatibilitySelector() {
  final eligibility = legacyEncounterEligibilityCondition();
  return Selector<StableContentId<EncounterContent>,
      LegacyEncounterEligibilityContext>(
    candidates: [
      for (var index = 0;
          index < legacyCellEncounterDefinitionIds.length;
          index++)
        SelectorCandidate.value(
          id: legacyCellEncounterCandidateId(legacyCellEncounterSlugs[index]),
          value: legacyCellEncounterDefinitionIds[index],
          weight: 1,
          condition: eligibility,
        ),
      SelectorCandidate.none(
        id: legacyCellEncounterCandidateId('none'),
        weight: 1,
        condition: NotCondition<LegacyEncounterEligibilityContext>(eligibility),
      ),
    ],
  );
}

/// Converts the same SHA-256 shard used by legacy `ComputeEncounter` into a
/// normalized roll that selects its modulo-eight catalog index under equal
/// weights. The midpoint avoids floating boundary ambiguity.
double legacyCellEncounterRoll({required String seed, required String cellId}) {
  final hashText = sha256.convert(utf8.encode('${seed}_$cellId')).toString();
  final hashValue = int.parse(hashText.substring(0, 8), radix: 16);
  final catalogIndex = hashValue % legacyCellEncounterDefinitionIds.length;
  return (catalogIndex + 0.5) / legacyCellEncounterDefinitionIds.length;
}
