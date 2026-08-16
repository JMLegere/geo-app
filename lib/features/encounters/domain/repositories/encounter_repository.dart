import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/domain/entities/venue_id.dart';
import 'package:earth_nova/features/encounters/domain/entities/encounter_entities.dart';
import 'package:earth_nova/features/encounters/domain/use_cases/resolve_cell_visit_encounter_selector.dart';

/// Runtime boundary for Encounter command RPCs and the pending-read projection.
///
/// The client never writes Encounter runtime tables directly. Commands return
/// complete committed runtime aggregates; the read exposes only pending state.
abstract interface class EncounterRepository {
  Future<EncounterRuntimeAggregate> commitCellVisitSelection(
    CellVisitEncounterSelectionPlan plan, {
    required String traceId,
  });

  Future<EncounterRuntimeAggregate> resolveEncounterOutcomes(
    EncounterId encounterId, {
    required String traceId,
    EncounterOptionId? selectedOptionId,
  });

  /// Reads the sole visible pending Encounter for a trusted cell, if any.
  Future<PendingEncounter?> readPendingEncounterForCell(
    String cellId, {
    required String traceId,
  });
}

/// A typed committed view returned by either Encounter command RPC.
final class EncounterRuntimeAggregate {
  EncounterRuntimeAggregate({
    required this.cellVisitResolution,
    required this.encounter,
    required Iterable<EncounterOutcomeResult> outcomeResults,
    required Iterable<GeneratedItemCommit> generatedItemCommits,
    required Iterable<RevealedVenueCommit> revealedVenueCommits,
  })  : outcomeResults = List<EncounterOutcomeResult>.unmodifiable(
          outcomeResults,
        ),
        generatedItemCommits = List<GeneratedItemCommit>.unmodifiable(
          generatedItemCommits,
        ),
        revealedVenueCommits = List<RevealedVenueCommit>.unmodifiable(
          revealedVenueCommits,
        );

  /// The one immutable selector result for the Cell Visit, including explicit
  /// [NoEncounterDefinitionSelection] when no Encounter was selected.
  final CellVisitResolution cellVisitResolution;

  /// Absent exactly for an explicit None Cell Visit resolution.
  final EncounterOccurrence? encounter;

  /// Ordered immutable Outcome evidence. It is empty until an Encounter is
  /// resolved and remains empty if resolution fails before committing results.
  final List<EncounterOutcomeResult> outcomeResults;

  /// Generated Item mutations, linked to their exact Generate Item result.
  ///
  /// This list is intentionally empty when no Item-producing Outcome commits.
  final List<GeneratedItemCommit> generatedItemCommits;

  /// First-known Venue mutations, linked to their Reveal Venue result.
  ///
  /// This contains immutable evidence only; it intentionally does not invoke
  /// Venue visit or presentation behavior.
  final List<RevealedVenueCommit> revealedVenueCommits;
}

/// One durable Item commit linked to the Generate Item Outcome that created it.
final class GeneratedItemCommit {
  GeneratedItemCommit({
    required this.outcomeResult,
    required this.item,
  }) {
    final resolvedVersion = outcomeResult.resolvedBaseItemVersion;
    if (resolvedVersion != null &&
        item.definitionId != resolvedVersion.stableId.value) {
      throw ArgumentError.value(
        item,
        'item',
        'must belong to the Generate Item result stable Base Item identity',
      );
    }
    if (resolvedVersion == null &&
        (!item.isUnidentified || item.definitionId != null)) {
      throw ArgumentError.value(
        item,
        'item',
        'unidentified generated Items must not expose canonical identity',
      );
    }
  }

  final GenerateItemOutcomeResult outcomeResult;
  final Item item;

  ExactVersionRef<BaseItemContent>? get resolvedBaseItemVersion =>
      outcomeResult.resolvedBaseItemVersion;
}

/// One durable first-known Venue commit linked to Reveal Venue outcome evidence.
final class RevealedVenueCommit {
  const RevealedVenueCommit({
    required this.outcomeResult,
    required this.knownAt,
  });

  final RevealVenueOutcomeResult outcomeResult;
  final DateTime knownAt;

  VenueId get venueId => outcomeResult.venueId;
}

/// A safe, typed failure emitted by the Encounter command repository.
sealed class EncounterRepositoryFailure implements Exception {
  const EncounterRepositoryFailure(this.diagnosticCode);

  /// A stable, safe code suitable for telemetry; never a server error message.
  final String diagnosticCode;

  @override
  String toString() => '$runtimeType($diagnosticCode)';
}

/// The request did not have an authenticated owner, or ownership was denied.
final class EncounterAuthenticationOrOwnershipFailure
    extends EncounterRepositoryFailure {
  const EncounterAuthenticationOrOwnershipFailure(super.diagnosticCode);
}

/// The exact Version in a submitted selection plan is no longer current.
final class EncounterStalePlanFailure extends EncounterRepositoryFailure {
  const EncounterStalePlanFailure(super.diagnosticCode);
}

/// A retry changed a previously committed command input.
final class EncounterRetryInputConflictFailure
    extends EncounterRepositoryFailure {
  const EncounterRetryInputConflictFailure(super.diagnosticCode);
}

/// The command was rejected by an Encounter domain invariant.
final class EncounterDomainFailure extends EncounterRepositoryFailure {
  const EncounterDomainFailure(super.diagnosticCode);
}

/// An RPC response did not satisfy the durable aggregate contract.
final class EncounterMalformedResponseFailure
    extends EncounterRepositoryFailure {
  const EncounterMalformedResponseFailure(super.diagnosticCode);
}

/// The RPC could not be completed for a non-domain transport or unexpected
/// reason. Its code is intentionally generic to avoid leaking backend details.
final class EncounterTransportFailure extends EncounterRepositoryFailure {
  const EncounterTransportFailure(super.diagnosticCode);
}
