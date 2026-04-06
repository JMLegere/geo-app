class LocationState {
  const LocationState({
    required this.lat,
    required this.lng,
    required this.accuracy,
    required this.timestamp,
    required this.isConfident,
  });

  final double lat;
  final double lng;
  final double accuracy;
  final DateTime timestamp;
  final bool isConfident;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationState &&
          runtimeType == other.runtimeType &&
          lat == other.lat &&
          lng == other.lng &&
          accuracy == other.accuracy &&
          timestamp == other.timestamp &&
          isConfident == other.isConfident;

  @override
  int get hashCode => Object.hash(lat, lng, accuracy, timestamp, isConfident);
}
