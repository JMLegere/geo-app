/// The Player's single durable personal-base identity.
///
/// Home is deliberately only identity. Module composition, placement, and
/// lifecycle remain outside this slice until their domain is resolved.
final class Home {
  Home({
    required String id,
    required String playerId,
    required DateTime createdAt,
  })  : id = _nonBlank(id, 'id'),
        playerId = _nonBlank(playerId, 'playerId'),
        createdAt = createdAt.toUtc();

  final String id;
  final String playerId;
  final DateTime createdAt;
}

String _nonBlank(String value, String name) {
  final canonical = value.trim();
  if (canonical.isEmpty) {
    throw ArgumentError.value(value, name, 'must be nonblank');
  }
  return canonical;
}
