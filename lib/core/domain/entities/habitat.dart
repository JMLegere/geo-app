import 'dart:ui';

enum Habitat {
  forest('Forest', Color(0xFF4CAF50)),
  ocean('Ocean', Color(0xFF9C27B0)),
  freshwater('Freshwater', Color(0xFF2196F3)),
  swamp('Swamp', Color(0xFF9E9E9E)),
  desert('Desert', Color(0xFFFF9800)),
  plains('Plains', Color(0xFFFFEB3B)),
  mountain('Mountain', Color(0xFFF44336));

  const Habitat(this.label, this.color);

  final String label;
  final Color color;

  static Habitat? fromString(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final h in Habitat.values) {
      if (h.label.toLowerCase() == value.toLowerCase()) return h;
    }
    return null;
  }

  static Color blendHabitats(List<Habitat> habitats) {
    if (habitats.isEmpty) return const Color(0x00000000);
    var r = 0.0;
    var g = 0.0;
    var b = 0.0;
    for (final h in habitats) {
      r += h.color.r;
      g += h.color.g;
      b += h.color.b;
    }
    final count = habitats.length;
    return Color.from(
      alpha: 1.0,
      red: r / count,
      green: g / count,
      blue: b / count,
    );
  }
}
