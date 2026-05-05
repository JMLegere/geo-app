class CameraFollowState {
  const CameraFollowState({
    required this.lat,
    required this.lng,
    required this.hasFix,
    required this.gapDistance,
  });

  const CameraFollowState.noFix()
      : lat = 0.0,
        lng = 0.0,
        hasFix = false,
        gapDistance = 0.0;

  final double lat;
  final double lng;
  final bool hasFix;
  final double gapDistance;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CameraFollowState &&
          runtimeType == other.runtimeType &&
          lat == other.lat &&
          lng == other.lng &&
          hasFix == other.hasFix &&
          gapDistance == other.gapDistance;

  @override
  int get hashCode => Object.hash(lat, lng, hasFix, gapDistance);
}
