/// A typed, immutable opaque identity for one authored content version.
///
/// The version identity is separate from its revision number. This allows a
/// durable reference to bind both the exact version record and its human-
/// meaningful revision without requiring a mutable lookup.
final class ContentVersionId<T> {
  factory ContentVersionId(String value) {
    final canonicalValue = value.trim();
    if (canonicalValue.isEmpty) {
      throw ArgumentError.value(value, 'value', 'must not be empty');
    }
    return ContentVersionId<T>._(canonicalValue);
  }

  const ContentVersionId._(this.value);

  /// The canonical opaque identifier value.
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContentVersionId<T> &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => value;
}
