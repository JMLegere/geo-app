enum GameRegion {
  africa('Africa'),
  asia('Asia'),
  europe('Europe'),
  northAmerica('N. America'),
  southAmerica('S. America'),
  oceania('Oceania'),
  unknown('Unknown');

  const GameRegion(this.label);

  final String label;

  static GameRegion? fromString(String? value) {
    if (value == null || value.isEmpty) return null;
    final lower = value.toLowerCase();
    for (final r in GameRegion.values) {
      if (r.label.toLowerCase() == lower) return r;
    }
    if (lower == 'north america') return northAmerica;
    if (lower == 'south america') return southAmerica;
    return null;
  }
}
