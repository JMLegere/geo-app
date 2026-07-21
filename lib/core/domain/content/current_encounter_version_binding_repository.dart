import 'content_identity.dart';
import 'encounter_content.dart';

/// Least-privilege read boundary for binding a newly selected Encounter
/// Definition to its current published immutable Version.
///
/// Cell Visit planning needs only this exact identity and revision. It must not
/// load Options, Outcomes, or Outcome payloads before a durable Encounter is
/// created.

/// Safe failure for the least-privilege current Version binding boundary.
final class CurrentEncounterVersionBindingFailure implements Exception {
  const CurrentEncounterVersionBindingFailure(this.diagnosticCode);

  final String diagnosticCode;

  @override
  String toString() => '$runtimeType($diagnosticCode)';
}

abstract interface class CurrentEncounterVersionBindingRepository {
  Future<ExactVersionRef<EncounterContent>?>
      currentPublishedVersionForNewCellVisit(
    StableContentId<EncounterContent> definitionId, {
    String? traceId,
  });
}
