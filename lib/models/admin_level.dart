/// 6-level administrative hierarchy for location nodes.
/// World > Continent > Country > State > City > District.
enum AdminLevel {
  /// Synthetic root node — the entire world
  world,

  /// admin_level 1 — Continent (implicit from country)
  continent,

  /// admin_level 2 — Country
  country,

  /// admin_level 4 — State/Province
  state,

  /// admin_level 6-8 — City/Town
  city,

  /// admin_level 9-10 — District/Neighborhood
  district;

  String get displayName => switch (this) {
        AdminLevel.world => 'World',
        AdminLevel.continent => 'Continent',
        AdminLevel.country => 'Country',
        AdminLevel.state => 'State/Province',
        AdminLevel.city => 'City',
        AdminLevel.district => 'District',
      };

  static AdminLevel fromString(String value) {
    return AdminLevel.values.firstWhere(
      (level) => level.name == value,
      orElse: () => throw ArgumentError('Unknown AdminLevel: $value'),
    );
  }

  @override
  String toString() => name;
}
