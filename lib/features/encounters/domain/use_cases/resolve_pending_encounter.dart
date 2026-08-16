import 'package:earth_nova/core/observability/observable_use_case.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/encounters/domain/entities/encounter_entities.dart';
import 'package:earth_nova/features/encounters/domain/repositories/encounter_repository.dart';

/// The explicit player choice used to resolve a visible pending Encounter.
final class ResolvePendingEncounterInput {
  const ResolvePendingEncounterInput({
    required this.pendingEncounter,
    required this.optionId,
  });

  final PendingEncounter pendingEncounter;
  final EncounterOptionId optionId;
}

/// Resolves an authored pending Encounter option and returns its durable result.
final class ResolvePendingEncounter extends ObservableUseCase<
    ResolvePendingEncounterInput, EncounterRuntimeAggregate> {
  const ResolvePendingEncounter(this._repository, this._obs);

  final EncounterRepository _repository;
  final ObservabilityService _obs;

  @override
  ObservabilityService get obs => _obs;

  @override
  String get operationName => 'resolve_pending_encounter';

  @override
  Future<EncounterRuntimeAggregate> execute(
    ResolvePendingEncounterInput input,
    String traceId,
  ) async {
    if (!input.pendingEncounter.options
        .any((option) => option.id == input.optionId)) {
      throw ArgumentError.value(
        input.optionId,
        'optionId',
        'must be an option on pendingEncounter',
      );
    }

    final aggregate = await _repository.resolveEncounterOutcomes(
      input.pendingEncounter.encounter.id,
      selectedOptionId: input.optionId,
      traceId: traceId,
    );
    _requireResolvedAggregate(aggregate, input);
    return aggregate;
  }
}

void _requireResolvedAggregate(
  EncounterRuntimeAggregate aggregate,
  ResolvePendingEncounterInput input,
) {
  final encounter = aggregate.encounter;
  if (encounter == null ||
      encounter.id != input.pendingEncounter.encounter.id ||
      encounter.status != EncounterResolutionStatus.resolved ||
      encounter.selectedOptionId != input.optionId ||
      !_hasCompleteOutcomeEvidence(aggregate, encounter.id) ||
      aggregate.generatedItemCommits.length != 1) {
    throw StateError(
        'Encounter resolution did not return the selected committed result.');
  }
}

bool _hasCompleteOutcomeEvidence(
  EncounterRuntimeAggregate aggregate,
  EncounterId encounterId,
) {
  final generatedResults = <GenerateItemOutcomeResult>[];
  final revealedVenueResults = <RevealVenueOutcomeResult>[];
  for (final result in aggregate.outcomeResults) {
    if (result.encounterId != encounterId) return false;
    switch (result) {
      case GenerateItemOutcomeResult():
        generatedResults.add(result);
      case RevealVenueOutcomeResult():
        revealedVenueResults.add(result);
    }
  }
  return aggregate.generatedItemCommits.every(
        (commit) => commit.outcomeResult.encounterId == encounterId,
      ) &&
      aggregate.revealedVenueCommits.every(
        (commit) => commit.outcomeResult.encounterId == encounterId,
      ) &&
      generatedResults.length == aggregate.generatedItemCommits.length &&
      revealedVenueResults.length == aggregate.revealedVenueCommits.length &&
      _hasSameOutcomeIds(
        generatedResults.map((result) => result.id),
        aggregate.generatedItemCommits.map((commit) => commit.outcomeResult.id),
      ) &&
      _hasSameOutcomeIds(
        revealedVenueResults.map((result) => result.id),
        aggregate.revealedVenueCommits.map((commit) => commit.outcomeResult.id),
      );
}

bool _hasSameOutcomeIds(
  Iterable<EncounterOutcomeResultId> expected,
  Iterable<EncounterOutcomeResultId> actual,
) {
  final expectedIds = expected.toList(growable: false);
  final actualIds = actual.toList(growable: false);
  if (expectedIds.length != actualIds.length) return false;
  for (var index = 0; index < expectedIds.length; index += 1) {
    if (expectedIds[index] != actualIds[index]) return false;
  }
  return true;
}
