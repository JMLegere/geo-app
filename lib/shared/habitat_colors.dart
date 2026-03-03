import 'package:flutter/material.dart';
import 'package:fog_of_world/core/models/habitat.dart';

/// Three-colour palette for a single habitat.
///
/// - [primary]   — dominant colour, used for large areas, headers, icons
/// - [secondary] — supporting colour, used for accents and secondary UI
/// - [accent]    — highlight colour, used for badges, status indicators, CTAs
@immutable
class HabitatPalette {
  const HabitatPalette({
    required this.primary,
    required this.secondary,
    required this.accent,
  });

  final Color primary;
  final Color secondary;
  final Color accent;
}

/// Habitat-specific colour palettes for game UI.
///
/// Each habitat reflects its ecological character:
/// forest is dark & mossy, desert is warm & dusty, saltwater is deep & steely.
///
/// ## Usage
/// ```dart
/// final palette = HabitatColors.of(habitat);
/// Container(color: palette.primary, ...)
/// ```
///
/// Note: [Habitat.colorHex] provides a single legacy hex string.
/// Prefer [HabitatColors.of] for multi-colour theming.
abstract final class HabitatColors {
  // ── Forest ─ deep green → moss → lime ─────────────────────────────────────
  static const HabitatPalette forest = HabitatPalette(
    primary: Color(0xFF1B4D20), // deep forest green
    secondary: Color(0xFF4A7A48), // moss
    accent: Color(0xFF8AC04A), // lime
  );

  // ── Plains ─ wheat → olive → tan ──────────────────────────────────────────
  static const HabitatPalette plains = HabitatPalette(
    primary: Color(0xFFC4A23A), // wheat gold
    secondary: Color(0xFF7A7D3E), // olive
    accent: Color(0xFFD4B896), // tan
  );

  // ── Freshwater ─ blue → cerulean → aqua ───────────────────────────────────
  static const HabitatPalette freshwater = HabitatPalette(
    primary: Color(0xFF1565C0), // blue
    secondary: Color(0xFF2A9D8F), // cerulean
    accent: Color(0xFF48CAE4), // aqua
  );

  // ── Saltwater ─ navy → steel blue → seafoam ───────────────────────────────
  static const HabitatPalette saltwater = HabitatPalette(
    primary: Color(0xFF0D3B6E), // navy
    secondary: Color(0xFF3B7CB6), // steel blue
    accent: Color(0xFF5EC6B8), // seafoam
  );

  // ── Swamp ─ dark olive → moss brown → sage ────────────────────────────────
  static const HabitatPalette swamp = HabitatPalette(
    primary: Color(0xFF3A4F2D), // dark olive
    secondary: Color(0xFF6B5E3E), // moss brown
    accent: Color(0xFF87A97A), // sage
  );

  // ── Mountain ─ slate → stone → ice blue ───────────────────────────────────
  static const HabitatPalette mountain = HabitatPalette(
    primary: Color(0xFF4A5568), // slate
    secondary: Color(0xFF7B7D7D), // stone
    accent: Color(0xFFA8C8D8), // ice blue
  );

  // ── Desert ─ sandy → terracotta → sunset orange ───────────────────────────
  static const HabitatPalette desert = HabitatPalette(
    primary: Color(0xFFC49A6C), // sandy
    secondary: Color(0xFFB85C38), // terracotta
    accent: Color(0xFFE8724A), // sunset orange
  );

  // ── Lookup ────────────────────────────────────────────────────────────────

  /// Returns the [HabitatPalette] for [habitat].
  static HabitatPalette of(Habitat habitat) => switch (habitat) {
        Habitat.forest => forest,
        Habitat.plains => plains,
        Habitat.freshwater => freshwater,
        Habitat.saltwater => saltwater,
        Habitat.swamp => swamp,
        Habitat.mountain => mountain,
        Habitat.desert => desert,
      };

  /// Convenience: primary colour for [habitat].
  ///
  /// Equivalent to `HabitatColors.of(habitat).primary`.
  static Color primaryFor(Habitat habitat) => of(habitat).primary;

  /// Convenience: accent colour for [habitat].
  ///
  /// Equivalent to `HabitatColors.of(habitat).accent`.
  static Color accentFor(Habitat habitat) => of(habitat).accent;
}
