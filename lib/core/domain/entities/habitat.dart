enum Habitat {
  forest('Forest', 0xFF4CAF50),
  ocean('Ocean', 0xFF9C27B0),
  freshwater('Freshwater', 0xFF2196F3),
  swamp('Swamp', 0xFF9E9E9E),
  desert('Desert', 0xFFFF9800),
  plains('Plains', 0xFFFFEB3B),
  urban('Urban', 0xFF607D8B),
  mountain('Mountain', 0xFFF44336);

  const Habitat(this.label, this.colorValue);

  final String label;

  /// Opaque ARGB value consumed by presentation adapters.
  final int colorValue;

  static Habitat? fromString(String? value) {
    if (value == null || value.isEmpty) return null;
    final normalized = value.trim().toLowerCase();
    for (final h in Habitat.values) {
      if (h.label.toLowerCase() == normalized) return h;
    }
    return _aliases[normalized];
  }

  /// Blends habitat ARGB values without a Flutter color dependency.
  static int blendColorValues(List<Habitat> habitats) {
    if (habitats.isEmpty) return 0x00000000;

    var red = 0;
    var green = 0;
    var blue = 0;
    for (final habitat in habitats) {
      red += (habitat.colorValue >> 16) & 0xFF;
      green += (habitat.colorValue >> 8) & 0xFF;
      blue += habitat.colorValue & 0xFF;
    }

    final count = habitats.length;
    final blendedRed = (red / count).round();
    final blendedGreen = (green / count).round();
    final blendedBlue = (blue / count).round();
    return 0xFF000000 | (blendedRed << 16) | (blendedGreen << 8) | blendedBlue;
  }
}

const Map<String, Habitat> _aliases = {
  'grassland': Habitat.plains,
  'cropland': Habitat.plains,
  'meadow': Habitat.plains,
  'wetland': Habitat.swamp,
  'coastal': Habitat.ocean,
  'urban': Habitat.urban,
  'builtup': Habitat.urban,
  'built_up': Habitat.urban,
  'built-up': Habitat.urban,
  'residential': Habitat.urban,
  'commercial': Habitat.urban,
  'industrial': Habitat.urban,
  'woodland': Habitat.forest,
};
