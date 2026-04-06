enum Habitat {
  forest('Forest'),
  plains('Plains'),
  freshwater('Freshwater'),
  saltwater('Saltwater'),
  swamp('Swamp'),
  mountain('Mountain'),
  desert('Desert'),
  unknown('Unknown');

  const Habitat(this.label);

  final String label;

  static Habitat? fromString(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final h in Habitat.values) {
      if (h.label.toLowerCase() == value.toLowerCase()) return h;
    }
    return null;
  }
}
