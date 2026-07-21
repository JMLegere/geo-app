/// A typed, immutable identity for authored content that remains stable across
/// revisions.
final class StableContentId<T> {
  factory StableContentId(String value) {
    final canonicalValue = value.trim();
    if (canonicalValue.isEmpty) {
      throw ArgumentError.value(value, 'value', 'must not be empty');
    }
    return StableContentId<T>._(canonicalValue);
  }

  const StableContentId._(this.value);

  /// The canonical opaque identifier value.
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StableContentId<T> &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => value;
}
