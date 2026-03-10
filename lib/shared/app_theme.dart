import 'package:flutter/material.dart';
import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/shared/earth_nova_theme.dart';

/// Visual identity for *EarthNova*.
///
/// Dark theme is primary — exploration games live in darkness, the map is
/// the centrepiece, and fog-of-war demands contrast.  Light theme is kept
/// as a secondary option (accessibility, daytime glare).
///
/// ## Palette
/// | Role       | Color     | Hex       |
/// |------------|-----------|-----------|
/// | Primary    | Deep teal | #006D77   |
/// | Secondary  | Warm amber| #E29578   |
/// | Tertiary   | Soft green| #83C5BE   |
/// | Error      | Coral red | #EF476F   |
/// | Surface    | Dark navy | #0D1B2A   |
/// | OnSurface  | Off-white | #E0E1DD   |
///
/// ## Usage
/// ```dart
/// MaterialApp(
///   theme: AppTheme.light(),
///   darkTheme: AppTheme.dark(),
///   themeMode: ThemeMode.dark,
/// )
/// ```
abstract final class AppTheme {
  // ── Brand tokens ──────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF006D77); // deep teal — exploration
  static const Color secondary = Color(0xFFE29578); // warm amber — discoveries
  static const Color tertiary = Color(0xFF83C5BE); // soft green — sanctuary
  static const Color error = Color(0xFFEF476F); // coral red — alerts

  // ── Dark surface stack ────────────────────────────────────────────────────
  static const Color _darkSurface = Color(0xFF0D1B2A); // base navy
  static const Color _darkSurfaceContainer = Color(0xFF132333); // +step
  static const Color _darkSurfaceContainerHigh = Color(0xFF1A2D40); // ++step
  static const Color _darkSurfaceContainerHighest = Color(0xFF243A50);
  static const Color _darkOnSurface = Color(0xFFE0E1DD); // off-white text
  static const Color _darkOnSurfaceVariant = Color(0xFFADB5BD); // muted text
  static const Color _darkOutline = Color(0xFF3D5060); // borders
  static const Color _darkOutlineVariant = Color(0xFF253444);

  // ── Light surface stack ───────────────────────────────────────────────────
  static const Color _lightSurface = Color(0xFFF4F7F9);
  static const Color _lightSurfaceContainer = Color(0xFFFFFFFF);
  static const Color _lightSurfaceContainerHigh = Color(0xFFECF1F5);
  static const Color _lightOnSurface = Color(0xFF0D1B2A);
  static const Color _lightOnSurfaceVariant = Color(0xFF4D6070);
  static const Color _lightOutline = Color(0xFFB0C4CF);

  // ── Theme factories ───────────────────────────────────────────────────────

  /// Primary theme — dark map with naval palette.
  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF00444B),
      onPrimaryContainer: const Color(0xFF9FDBDF),
      secondary: secondary,
      onSecondary: const Color(0xFF1A1A1A),
      secondaryContainer: const Color(0xFF7A3B22),
      onSecondaryContainer: const Color(0xFFFFDAC6),
      tertiary: tertiary,
      onTertiary: _darkSurface,
      tertiaryContainer: const Color(0xFF1C5C67),
      onTertiaryContainer: const Color(0xFFBEECF0),
      error: error,
      onError: Colors.white,
      errorContainer: const Color(0xFF6E1428),
      onErrorContainer: const Color(0xFFFFB3BE),
      surface: _darkSurface,
      onSurface: _darkOnSurface,
      surfaceContainerLowest: _darkSurface,
      surfaceContainerLow: const Color(0xFF0F1E2C),
      surfaceContainer: _darkSurfaceContainer,
      surfaceContainerHigh: _darkSurfaceContainerHigh,
      surfaceContainerHighest: _darkSurfaceContainerHighest,
      onSurfaceVariant: _darkOnSurfaceVariant,
      outline: _darkOutline,
      outlineVariant: _darkOutlineVariant,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: _darkOnSurface,
      onInverseSurface: _darkSurface,
      inversePrimary: primary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      extensions: [EarthNovaTheme.dark(colorScheme)],
      textTheme: _buildTextTheme(
        baseColor: _darkOnSurface,
        mutedColor: _darkOnSurfaceVariant,
      ),
      scaffoldBackgroundColor: _darkSurface,
      appBarTheme: AppBarTheme(
        backgroundColor: _darkSurfaceContainer,
        foregroundColor: _darkOnSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.6),
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: _darkOnSurface,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: _darkOnSurface),
      ),
      cardTheme: CardThemeData(
        color: _darkSurfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: _darkOutline,
        thickness: 0.5,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: _darkOnSurface, size: 24),
      chipTheme: ChipThemeData(
        backgroundColor: _darkSurfaceContainerHigh,
        selectedColor: primary.withValues(alpha: 0.25),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        side: const BorderSide(color: _darkOutline, width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _darkSurfaceContainer,
        selectedItemColor: primary,
        unselectedItemColor: _darkOnSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _darkSurfaceContainerHighest,
        contentTextStyle: const TextStyle(color: _darkOnSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: _darkSurfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          color: _darkOnSurface,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Secondary theme — bright map for daytime use.
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFB3E9EC),
      onPrimaryContainer: const Color(0xFF002326),
      secondary: secondary,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFFFDBC9),
      onSecondaryContainer: const Color(0xFF3A1500),
      tertiary: const Color(0xFF006B76),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFA9ECF5),
      onTertiaryContainer: const Color(0xFF001F24),
      error: error,
      onError: Colors.white,
      errorContainer: const Color(0xFFFFDADE),
      onErrorContainer: const Color(0xFF400011),
      surface: _lightSurface,
      onSurface: _lightOnSurface,
      surfaceContainerLowest: _lightSurface,
      surfaceContainerLow: const Color(0xFFF7F9FB),
      surfaceContainer: _lightSurfaceContainer,
      surfaceContainerHigh: _lightSurfaceContainerHigh,
      surfaceContainerHighest: const Color(0xFFE3EBF0),
      onSurfaceVariant: _lightOnSurfaceVariant,
      outline: _lightOutline,
      outlineVariant: const Color(0xFFD5E0E7),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: const Color(0xFF2E3C45),
      onInverseSurface: const Color(0xFFECF0F4),
      inversePrimary: tertiary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      extensions: [EarthNovaTheme.light(colorScheme)],
      textTheme: _buildTextTheme(
        baseColor: _lightOnSurface,
        mutedColor: _lightOnSurfaceVariant,
      ),
      scaffoldBackgroundColor: _lightSurface,
      appBarTheme: AppBarTheme(
        backgroundColor: _lightSurfaceContainer,
        foregroundColor: _lightOnSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: _lightOnSurface,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: _lightOnSurface),
      ),
      cardTheme: CardThemeData(
        color: _lightSurfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: _lightOutline,
        thickness: 0.5,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: _lightOnSurface, size: 24),
      chipTheme: ChipThemeData(
        backgroundColor: _lightSurfaceContainerHigh,
        selectedColor: primary.withValues(alpha: 0.15),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        side: const BorderSide(color: _lightOutline, width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: _lightSurfaceContainer,
        selectedItemColor: primary,
        unselectedItemColor: _lightOnSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _lightOnSurface,
        contentTextStyle: const TextStyle(color: _lightSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Text theme ─────────────────────────────────────────────────────────────

  static TextTheme _buildTextTheme({
    required Color baseColor,
    required Color mutedColor,
  }) {
    return TextTheme(
      // Display — bold, for full-screen titles like "Your Sanctuary"
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w700,
        color: baseColor,
        letterSpacing: -0.5,
        height: 1.1,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.w700,
        color: baseColor,
        letterSpacing: -0.3,
        height: 1.15,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        color: baseColor,
        letterSpacing: -0.2,
        height: 1.2,
      ),

      // Headline — semi-bold, for section headers like "Forest Species"
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: baseColor,
        letterSpacing: -0.2,
        height: 1.25,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: baseColor,
        letterSpacing: -0.1,
        height: 1.3,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: baseColor,
        letterSpacing: -0.1,
        height: 1.3,
      ),

      // Title — medium weight, for card titles like "Red Fox"
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        color: baseColor,
        letterSpacing: -0.1,
        height: 1.35,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: baseColor,
        letterSpacing: 0.1,
        height: 1.5,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: baseColor,
        letterSpacing: 0.1,
        height: 1.45,
      ),

      // Body — regular weight, readable for descriptions
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: baseColor,
        letterSpacing: 0,
        height: 1.6,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: baseColor,
        letterSpacing: 0.15,
        height: 1.55,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: mutedColor,
        letterSpacing: 0.2,
        height: 1.5,
      ),

      // Label — small, for stats and metadata
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: baseColor,
        letterSpacing: 0.1,
        height: 1.4,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: baseColor,
        letterSpacing: 0.3,
        height: 1.35,
      ),
      labelSmall: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: mutedColor,
        letterSpacing: 0.5,
        height: 1.3,
      ),
    );
  }

  // ── Rarity colours ─────────────────────────────────────────────────────────

  /// Badge background colour for each IUCN rarity tier.
  ///
  /// Used consistently across `DiscoveryNotificationOverlay`, species cards,
  /// and pack filters.  White → green → blue → gold → purple → amber.
  static Color rarityColor(IucnStatus status) => switch (status) {
        IucnStatus.leastConcern => const Color(0xFFFFFFFF), // white
        IucnStatus.nearThreatened => const Color(0xFF4CAF50), // green
        IucnStatus.vulnerable => const Color(0xFF2196F3), // blue
        IucnStatus.endangered => const Color(0xFFFFD700), // gold
        IucnStatus.criticallyEndangered => const Color(0xFF9C27B0), // purple
        IucnStatus.extinct => const Color(0xFFFFC107), // amber
      };

  /// Badge foreground (text / icon) colour for each IUCN rarity tier.
  ///
  /// Light backgrounds (white, gold, amber) need dark text; others use white.
  static Color onRarityColor(IucnStatus status) => switch (status) {
        IucnStatus.leastConcern => const Color(0xFF1A1A2E), // dark on white
        IucnStatus.endangered => const Color(0xFF1A1A2E), // dark on gold
        IucnStatus.extinct => const Color(0xFF1A1A2E), // dark on amber
        _ => Colors.white,
      };
}
