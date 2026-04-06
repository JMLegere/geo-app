class PlayerMarkerState {
  const PlayerMarkerState({
    required this.lat,
    required this.lng,
    required this.isRing,
    required this.gapDistance,
  });

  final double lat;
  final double lng;
  final bool isRing;
  final double gapDistance;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerMarkerState &&
          runtimeType == other.runtimeType &&
          lat == other.lat &&
          lng == other.lng &&
          isRing == other.isRing &&
          gapDistance == other.gapDistance;

  @override
  int get hashCode => Object.hash(lat, lng, isRing, gapDistance);
}
