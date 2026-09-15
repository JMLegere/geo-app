import 'package:earth_nova/app/readiness/app_readiness.dart';
import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/content_version_id.dart';
import 'package:earth_nova/core/domain/content/encounter_content.dart';
import 'package:earth_nova/core/domain/content/exact_version_ref.dart';
import 'package:earth_nova/core/domain/content/stable_content_id.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/trace_context.dart';
import 'package:earth_nova/features/encounters/domain/entities/encounter_entities.dart';
import 'package:earth_nova/features/encounters/domain/repositories/encounter_repository.dart';
import 'package:earth_nova/features/encounters/presentation/providers/pending_encounter_provider.dart';
import 'package:riverpod/misc.dart';

final storyPendingEncounter = PendingEncounter(
  cellId: 'story-cell-red-fox',
  encounter: EncounterOccurrence(
    id: EncounterId('story-encounter-red-fox'),
    cellVisitId: CellVisitId('story-visit-red-fox'),
    cellVisitResolutionId: CellVisitResolutionId('story-resolution-red-fox'),
    definitionVersion: ExactVersionRef<EncounterContent>(
      stableId: StableContentId<EncounterContent>('encounter:red_fox'),
      versionId: ContentVersionId<EncounterContent>('story-red-fox-r1'),
      revision: 1,
    ),
    status: EncounterResolutionStatus.pending,
    createdAt: DateTime.utc(2026, 8, 16),
  ),
  definitionDisplayName: 'Red Fox',
  options: [
    PendingEncounterOption(
      id: EncounterOptionId('story-observe-quietly'),
      ordinal: 0,
      displayName: 'Observe quietly',
    ),
  ],
);

List<Override> pendingEncounterStoryOverrides(PendingEncounterState state) => [
  appObservabilityProvider.overrideWithValue(
    ObservabilityService(sessionId: 'widgetbook-pending-encounter'),
  ),
  appReadinessProvider.overrideWith(StoryReadinessNotifier.new),
  pendingEncounterProvider.overrideWith(
    () => StoryPendingEncounterNotifier(state),
  ),
];

final class StoryReadinessNotifier extends AppReadinessNotifier {
  @override
  AppReadinessState build() => AppReadinessState(
    phase: AppReadinessPhase.usable,
    completedCheckpoints: AppReadinessState.requiredCheckpoints,
  );
}

final class StoryPendingEncounterNotifier extends PendingEncounterNotifier {
  StoryPendingEncounterNotifier(this.value);

  final PendingEncounterState value;

  @override
  PendingEncounterState build() => value;

  @override
  Future<void> resolve(EncounterOptionId _, {TraceContext? parent}) async {}

  @override
  Future<void> retryResolution({TraceContext? parent}) async {}
}

final storyResolvedEncounter = PendingEncounterResolved(
  storyPendingEncounter,
  EncounterRuntimeAggregate(
    cellVisitResolution: CellVisitResolution.selectedDefinition(
      id: storyPendingEncounter.encounter.cellVisitResolutionId,
      cellVisitId: storyPendingEncounter.encounter.cellVisitId,
      selectorId: SelectorId('story-pending'),
      selectorCandidateId: SelectorCandidateId('story-pending'),
      definitionId: storyPendingEncounter.encounter.definitionVersion.stableId,
      resolvedAt: DateTime.utc(2026, 8, 16, 0, 1),
    ),
    encounter: EncounterOccurrence(
      id: storyPendingEncounter.encounter.id,
      cellVisitId: storyPendingEncounter.encounter.cellVisitId,
      cellVisitResolutionId:
          storyPendingEncounter.encounter.cellVisitResolutionId,
      definitionVersion: storyPendingEncounter.encounter.definitionVersion,
      status: EncounterResolutionStatus.resolved,
      createdAt: storyPendingEncounter.encounter.createdAt,
      selectedOptionId: storyPendingEncounter.options.first.id,
      resolvedAt: DateTime.utc(2026, 8, 16, 0, 1),
    ),
    outcomeResults: [
      GenerateItemOutcomeResult(
        id: EncounterOutcomeResultId('story-result-red-fox'),
        encounterId: storyPendingEncounter.encounter.id,
        outcomeId: EncounterOutcomeId('story-outcome-red-fox'),
        ordinal: 0,
        createdAt: DateTime.utc(2026, 8, 16, 0, 1),
        resolvedBaseItemVersion: ExactVersionRef<BaseItemContent>(
          stableId: StableContentId<BaseItemContent>('fauna:red_fox'),
          versionId: ContentVersionId<BaseItemContent>('story-red-fox-item-r1'),
          revision: 1,
        ),
      ),
    ],
    generatedItemCommits: const [],
    revealedVenueCommits: const [],
  ),
);
