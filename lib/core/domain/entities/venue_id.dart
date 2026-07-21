/// Stable identity for one discoverable Venue.
///
/// A Venue identity is shared by Encounter reveal evidence and the living-world
/// feature, while Venue behavior remains owned by living world.
final class VenueId {
  VenueId(String value) : value = _canonical(value);

  final String value;

  static String _canonical(String value) {
    final canonical = value.trim();
    if (canonical.isEmpty) {
      throw ArgumentError.value(value, 'value', 'must not be blank');
    }
    return canonical;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is VenueId && value == other.value;

  @override
  int get hashCode => Object.hash(VenueId, value);

  @override
  String toString() => value;
}
