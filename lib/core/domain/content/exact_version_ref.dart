import 'content_version_id.dart';
import 'stable_content_id.dart';

/// An immutable binding to one stable content identity and one exact revision.
///
/// The reference intentionally contains no latest/current lookup or mutation
/// behavior. Callers must provide the exact version selected for the binding.
final class ExactVersionRef<T> {
  factory ExactVersionRef({
    required StableContentId<T> stableId,
    required ContentVersionId<T> versionId,
    required int revision,
  }) {
    if (revision <= 0) {
      throw ArgumentError.value(
        revision,
        'revision',
        'must be greater than zero',
      );
    }
    return ExactVersionRef<T>._(
      stableId: stableId,
      versionId: versionId,
      revision: revision,
    );
  }

  const ExactVersionRef._({
    required this.stableId,
    required this.versionId,
    required this.revision,
  });

  /// The stable identity whose content this version belongs to.
  final StableContentId<T> stableId;

  /// The immutable identity of the exact version record.
  final ContentVersionId<T> versionId;

  /// The positive, author-assigned revision number bound by this reference.
  final int revision;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExactVersionRef<T> &&
          runtimeType == other.runtimeType &&
          stableId == other.stableId &&
          versionId == other.versionId &&
          revision == other.revision;

  @override
  int get hashCode => Object.hash(runtimeType, stableId, versionId, revision);
}
