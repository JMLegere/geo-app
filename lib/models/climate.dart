
/// 4 climate zones derived from real latitude.
///
/// Boundaries:
/// - Tropic:     0°–23.5° (equatorial belt)
/// - Temperate:  23.5°–55° (mid-latitudes)
/// - Boreal:     55°–66.5° (subarctic)
/// - Frigid:     66.5°–90° (polar)
enum Climate {
  tropic,
  temperate,
  boreal,
  frigid;

  String get displayName => switch (this) {
        Climate.tropic => 'Tropic',
        Climate.temperate => 'Temperate',
        Climate.boreal => 'Boreal',
        Climate.frigid => 'Frigid',
      };

  /// Derive climate from absolute latitude (handles southern hemisphere).
  static Climate fromLatitude(double latitude) {
    final absLat = latitude.abs();
    if (absLat <= 23.5) return Climate.tropic;
    if (absLat <= 55.0) return Climate.temperate;
    if (absLat <= 66.5) return Climate.boreal;
    return Climate.frigid;
  }

  static Climate fromString(String value) {
    return Climate.values.firstWhere(
      (c) => c.name == value,
      orElse: () => throw ArgumentError('Unknown Climate: $value'),
    );
  }

  @override
  String toString() => name;
}
