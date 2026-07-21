import 'authored_content_snapshot.dart';
import 'content_version_id.dart';
import 'encounter_content.dart';
import 'stable_content_id.dart';

/// Read-only authored Encounter Definition content access.
///
/// The current read is only for creating future state. Existing state must use
/// the supplied exact Version ID and must never resolve through the current
/// Version pointer.
abstract interface class EncounterContentRepository {
  Future<AuthoredContentSnapshot<EncounterContent>?>
      currentPublishedForNewState(
    StableContentId<EncounterContent> stableId,
  );

  Future<AuthoredContentSnapshot<EncounterContent>?>
      exactVersionForExistingState(
    ContentVersionId<EncounterContent> versionId,
  );
}
