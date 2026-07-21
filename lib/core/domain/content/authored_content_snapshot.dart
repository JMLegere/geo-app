import 'content_version_id.dart';
import 'exact_version_ref.dart';
import 'publication_state.dart';
import 'stable_content_id.dart';

/// An immutable authored-content Version retained by stable identity and
/// revision.
///
/// This record is intentionally a snapshot only. It does not resolve a newer
/// Version, and callers must use its [reference] when binding durable state.
final class AuthoredContentSnapshot<T> {
  factory AuthoredContentSnapshot({
    required StableContentId<T> stableId,
    required ContentVersionId<T> versionId,
    required int revision,
    required PublicationState publicationState,
    required Map<String, Object?> authoredContent,
  }) =>
      AuthoredContentSnapshot<T>._(
        reference: ExactVersionRef<T>(
          stableId: stableId,
          versionId: versionId,
          revision: revision,
        ),
        publicationState: publicationState,
        authoredContent: _freezeAuthoredContent(authoredContent),
      );

  const AuthoredContentSnapshot._({
    required this.reference,
    required this.publicationState,
    required this.authoredContent,
  });

  /// The stable owner and exact immutable Version identity for this snapshot.
  final ExactVersionRef<T> reference;

  /// The Version lifecycle state at read time.
  final PublicationState publicationState;

  /// The typed, immutable authored payload for this exact Version.
  final Map<String, Object?> authoredContent;
}

Map<String, Object?> _freezeAuthoredContent(Map<String, Object?> source) {
  final result = <String, Object?>{};
  for (final entry in source.entries) {
    result[entry.key] = _freezeJson(entry.value, entry.key);
  }
  return Map<String, Object?>.unmodifiable(result);
}

Object? _freezeJson(Object? value, String path) {
  if (value == null || value is String || value is bool) return value;
  if (value is num) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, path, 'must be a finite JSON number');
    }
    return value;
  }
  if (value is List) {
    return List<Object?>.unmodifiable(
      value.indexed.map(
        (entry) => _freezeJson(entry.$2, '$path[${entry.$1}]'),
      ),
    );
  }
  if (value is Map) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw ArgumentError.value(
            value, path, 'JSON object keys must be strings');
      }
      result[key] = _freezeJson(entry.value, '$path.$key');
    }
    return Map<String, Object?>.unmodifiable(result);
  }
  throw ArgumentError.value(value, path, 'must be a JSON value');
}
