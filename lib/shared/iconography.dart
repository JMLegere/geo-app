/// Iconography — canonical emoji vocabulary for EarthNova.
///
/// All game icons are defined once in [AppIcons] as static constants.
/// Enums and widgets reference these constants — never inline emoji literals.
///
/// Every emoji is unique across the entire system (35 total, zero conflicts).
/// To change an icon, update the single constant in [AppIcons].
library;

// ─── Central icon registry ────────────────────────────────────────────────────

/// Single source of truth for every emoji/icon in the app.
///
/// Organized by domain. No widget should contain a hardcoded emoji string —
/// always reference `AppIcons.xxx` instead.
abstract final class AppIcons {
  // ── Item categories ─────────────────────────────────────────────────────
  static const String fauna = '🦊';
  static const String flora = '🌿';
  static const String mineral = '💎';
  static const String fossil = '🦴';
  static const String artifact = '🏺';
  static const String food = '🍄';
  static const String orb = '🔮';

  // ── Taxonomic groups ────────────────────────────────────────────────────
  static const String mammals = '🦁';
  static const String birds = '🦅';
  static const String reptiles = '🦎';
  static const String amphibians = '🐸';
  static const String fish = '🐟';
  static const String invertebrates = '🦋';

  // ── Habitats ────────────────────────────────────────────────────────────
  static const String forest = '🌲';
  static const String plains = '🌾';
  static const String freshwater = '💧';
  static const String saltwater = '🌊';
  static const String swamp = '🌱';
  static const String mountain = '🏔️';
  static const String desert = '🌵';

  // ── Regions ─────────────────────────────────────────────────────────────
  static const String africa = '🌍';
  static const String asia = '🌏';
  static const String europe = '🏛️';
  static const String northAmerica = '🌎';
  static const String southAmerica = '🌺';
  static const String oceania = '🪃';

  // ── Sort modes ──────────────────────────────────────────────────────────
  static const String sortRecent = '🕐';
  static const String sortRarity = '⭐';
  static const String sortName = '🔤';

  // ── Shared / system ─────────────────────────────────────────────────────
  static const String unknown = '❓';
  static const String search = '🔍';

  // ── Navigation / screens ────────────────────────────────────────────────
  static const String map = '🗺️';
  static const String sanctuary = '🌿'; // Same glyph as flora — context differs
}

// ─── Taxonomic groups ─────────────────────────────────────────────────────────

/// Maps IUCN `taxonomic_class` strings to user-facing filter groups.
///
/// 25 raw DB classes → 7 groups. The [fromTaxonomicClass] factory handles
/// the full mapping. Unknown/null classes map to [other].
enum TaxonomicGroup {
  mammals(AppIcons.mammals, 'Mammals'),
  birds(AppIcons.birds, 'Birds'),
  reptiles(AppIcons.reptiles, 'Reptiles'),
  amphibians(AppIcons.amphibians, 'Amphibians'),
  fish(AppIcons.fish, 'Fish'),
  invertebrates(AppIcons.invertebrates, 'Invertebrates'),
  other(AppIcons.unknown, 'Other');

  const TaxonomicGroup(this.icon, this.label);

  /// Emoji icon for filter toggles and compact bar chips.
  final String icon;

  /// Display label for expanded panel row headers.
  final String label;

  /// Maps an IUCN `taxonomic_class` database string to a [TaxonomicGroup].
  ///
  /// Returns [other] for unknown, empty, or null classes.
  /// Mapping based on actual DB values (32,752 species queried 2026-04-04):
  ///   MAMMALIA(4071) → mammals
  ///   AVES(5366) → birds
  ///   REPTILIA(5378) → reptiles
  ///   AMPHIBIA(3449) → amphibians
  ///   ACTINOPTERYGII(9161), CHONDRICHTHYES(592), SARCOPTERYGII(3),
  ///     MYXINI(29), CEPHALASPIDOMORPHI(23) → fish
  ///   Everything else (INSECTA, GASTROPODA, MALACOSTRACA, BIVALVIA,
  ///     DIPLOPODA, CEPHALOPODA, ARACHNIDA, ANTHOZOA, CLITELLATA,
  ///     HOLOTHUROIDEA, BRANCHIOPODA, UDEONYCHOPHORA, CHILOPODA,
  ///     ENOPLA, MEROSTOMATA, HYDROZOA) → invertebrates
  static TaxonomicGroup fromTaxonomicClass(String? cls) {
    if (cls == null || cls.isEmpty) return other;
    return switch (cls.toUpperCase()) {
      'MAMMALIA' => mammals,
      'AVES' => birds,
      'REPTILIA' => reptiles,
      'AMPHIBIA' => amphibians,
      // Bony fish, cartilaginous fish, lobe-finned fish, hagfish, lampreys
      'ACTINOPTERYGII' ||
      'CHONDRICHTHYES' ||
      'SARCOPTERYGII' ||
      'MYXINI' ||
      'CEPHALASPIDOMORPHI' =>
        fish,
      // All invertebrate classes
      'INSECTA' ||
      'GASTROPODA' ||
      'MALACOSTRACA' ||
      'BIVALVIA' ||
      'DIPLOPODA' ||
      'CEPHALOPODA' ||
      'ARACHNIDA' ||
      'ANTHOZOA' ||
      'CLITELLATA' ||
      'HOLOTHUROIDEA' ||
      'BRANCHIOPODA' ||
      'UDEONYCHOPHORA' ||
      'CHILOPODA' ||
      'ENOPLA' ||
      'MEROSTOMATA' ||
      'HYDROZOA' =>
        invertebrates,
      _ => other,
    };
  }
}

// ─── Habitats ─────────────────────────────────────────────────────────────────

/// Game habitat biomes. Maps from species `habitats_json` array elements.
///
/// Values match the 7 game habitats defined in `.agents/constraints.md`
/// plus an [unknown] fallback for the "Unknown" DB value.
enum Habitat {
  forest(AppIcons.forest, 'Forest'),
  plains(AppIcons.plains, 'Plains'),
  freshwater(AppIcons.freshwater, 'Freshwater'),
  saltwater(AppIcons.saltwater, 'Saltwater'),
  swamp(AppIcons.swamp, 'Swamp'),
  mountain(AppIcons.mountain, 'Mountain'),
  desert(AppIcons.desert, 'Desert'),
  unknown(AppIcons.unknown, 'Unknown');

  const Habitat(this.icon, this.label);
  final String icon;
  final String label;

  /// Parse from a database habitat string (case-insensitive).
  /// Returns null for unrecognized values.
  static Habitat? fromString(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final h in Habitat.values) {
      if (h.label.toLowerCase() == value.toLowerCase()) return h;
    }
    return null;
  }
}

// ─── Regions ──────────────────────────────────────────────────────────────────

/// Geographic regions for species range filtering.
///
/// Values match actual `continents_json` DB values (queried 2026-04-04).
/// Note: no Antarctica in DB data — all 32,752 species are in 6 continents.
enum GameRegion {
  africa(AppIcons.africa, 'Africa'),
  asia(AppIcons.asia, 'Asia'),
  europe(AppIcons.europe, 'Europe'),
  northAmerica(AppIcons.northAmerica, 'N. America'),
  southAmerica(AppIcons.southAmerica, 'S. America'),
  oceania(AppIcons.oceania, 'Oceania'),
  unknown(AppIcons.unknown, 'Unknown');

  const GameRegion(this.icon, this.label);
  final String icon;
  final String label;

  /// Parse from a database continent string (case-insensitive).
  /// Handles "North America" → [northAmerica], "South America" → [southAmerica].
  /// Returns null for unrecognized values.
  static GameRegion? fromString(String? value) {
    if (value == null || value.isEmpty) return null;
    final lower = value.toLowerCase();
    for (final r in GameRegion.values) {
      if (r.label.toLowerCase() == lower) return r;
    }
    // Handle DB format with space
    if (lower == 'north america') return northAmerica;
    if (lower == 'south america') return southAmerica;
    return null;
  }
}

// ─── Sort modes ───────────────────────────────────────────────────────────────

/// Sort modes for the Pack screen. Promoted from private `_SortMode`.
///
/// Sort toggles use `AppTheme.secondary` (amber) when selected, vs
/// `AppTheme.primary` (teal) for filter toggles. Pill shape distinguishes
/// sort from filter (pill = single-select, rounded square = multi-select).
enum PackSortMode {
  recent(AppIcons.sortRecent, 'Recent'),
  rarity(AppIcons.sortRarity, 'Rarity'),
  name(AppIcons.sortName, 'A→Z');

  const PackSortMode(this.icon, this.label);
  final String icon;
  final String label;
}
