import 'package:flutter/material.dart';

/// Dark theme — primary EarthNova theme.
/// Deep navy surface, teal primary, warm amber secondary.
abstract final class AppTheme {
  // ── Brand tokens ──────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF006D77);
  static const Color secondary = Color(0xFFE29578);
  static const Color tertiary = Color(0xFF83C5BE);
  static const Color error = Color(0xFFEF476F);

  // ── Dark surface stack ────────────────────────────────────────────────────
  static const Color surface = Color(0xFF0D1B2A);
  static const Color surfaceContainer = Color(0xFF132333);
  static const Color surfaceContainerHigh = Color(0xFF1A2D40);
  static const Color surfaceContainerHighest = Color(0xFF243A50);
  static const Color onSurface = Color(0xFFE0E1DD);
  static const Color onSurfaceVariant = Color(0xFFADB5BD);
  static const Color outline = Color(0xFF3D5060);

  static ThemeData dark() {
    final cs = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: const Color(0xFF1A1A1A),
      tertiary: tertiary,
      onTertiary: surface,
      error: error,
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainer: surfaceContainer,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerHighest: surfaceContainerHighest,
      onSurfaceVariant: onSurfaceVariant,
      outline: outline,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: cs,
      scaffoldBackgroundColor: surface,
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceContainer,
        foregroundColor: onSurface,
        elevation: 0,
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: onSurface,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
