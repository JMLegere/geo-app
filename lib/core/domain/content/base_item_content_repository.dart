import 'authored_content_snapshot.dart';
import 'base_item_content.dart';
import 'content_version_id.dart';
import 'stable_content_id.dart';

/// Read-only authored Base Item content access.
///
/// The current read is only for creating future state. Existing state must use
/// the supplied exact Version ID and must never resolve through the current
/// Version pointer.
abstract interface class BaseItemContentRepository {
  Future<AuthoredContentSnapshot<BaseItemContent>?> currentPublishedForNewState(
    StableContentId<BaseItemContent> stableId,
  );

  Future<AuthoredContentSnapshot<BaseItemContent>?>
      exactVersionForExistingState(
    ContentVersionId<BaseItemContent> versionId,
  );
}
