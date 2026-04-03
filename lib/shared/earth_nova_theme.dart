import 'package:flutter/material.dart';

import 'package:earth_nova/models/iucn_status.dart';
import 'package:earth_nova/shared/design_tokens.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// EarthNova Theme Extension
//
// Game-specific theme properties that vary between dark and light modes.
// Access via `context.earthNova` or `EarthNovaTheme.of(context)`.
//
// For values that DON'T change between themes (rarity colors, habitat colors),
// use the static helpers on this class directly.
// ═══════════════════════════════════════════════════════════════════════════════

/// Game-specific theme properties that augment the Material [ColorScheme].
///
/// Provides theme-aware frosted glass, shadow, and semantic game colours.
///
/// ## Usage
/// ```dart
/// // Via BuildContext extension (preferred)
/// final nova = context.earthNova;
/// Container(color: nova.frostedGlassTint, ...);
///
/// // Via static accessor
/// final nova = EarthNovaTheme.of(context);
///
/// // Static helpers (theme-independent)
/// final color = EarthNovaTheme.rarityColor(IucnStatus.endangered);
/// final label = EarthNovaTheme.rarityLabel(IucnStatus.endangered);
/// ```
@immutable
class EarthNovaTheme extends ThemeExtension<EarthNovaTheme> {
  const EarthNovaTheme({
    required this.frostedGlassTint,
    required this.frostedGlassBorder,
    required this.frostedNotificationTint,
    required this.frostedNotificationBorder,
    required this.cardShadow,
    required this.elevatedShadow,
    required this.successColor,
    required this.successContainerColor,
  });

  // ── Instance properties (theme-dependent) ─────────────────────────────────

  /// Frosted glass background tint for status bars and panels.
  final Color frostedGlassTint;

  /// Frosted glass border colour.
  final Color frostedGlassBorder;

  /// Frosted glass background tint for notification toasts (slightly opaquer).
  final Color frostedNotificationTint;

  /// Frosted glass border colour for notification toasts.
  final Color frostedNotificationBorder;

  /// Standard card shadow (soft for light, deeper for dark).
  final List<BoxShadow> cardShadow;

  /// Elevated shadow for overlays and modals.
  final List<BoxShadow> elevatedShadow;

  /// Achievement / success accent.
  final Color successColor;

  /// Achievement / success container background.
  final Color successContainerColor;

  // ── Factories ─────────────────────────────────────────────────────────────

  /// Dark mode — naval frosted-glass, deeper shadows.
  factory EarthNovaTheme.dark(ColorScheme cs) => EarthNovaTheme(
        frostedGlassTint:
            cs.surfaceContainer.withValues(alpha: Opacities.frostedDark),
        frostedGlassBorder: cs.outline.withValues(alpha: Opacities.borderLight),
        frostedNotificationTint: cs.surfaceContainerHigh
            .withValues(alpha: Opacities.frostedNotification),
        frostedNotificationBorder:
            cs.outline.withValues(alpha: Opacities.borderLight),
        cardShadow: Shadows.medium,
        elevatedShadow: Shadows.elevatedDark,
        successColor: const Color(0xFF10B981),
        successContainerColor: const Color(0xFF10B981)
            .withValues(alpha: Opacities.badgeBackground),
      );

  /// Light mode — white frosted-glass, softer shadows.
  factory EarthNovaTheme.light(ColorScheme cs) => EarthNovaTheme(
        frostedGlassTint:
            Colors.white.withValues(alpha: Opacities.frostedLight),
        frostedGlassBorder:
            Colors.white.withValues(alpha: Opacities.borderFrosted),
        frostedNotificationTint:
            Colors.white.withValues(alpha: Opacities.frostedLight),
        frostedNotificationBorder:
            Colors.white.withValues(alpha: Opacities.borderFrosted),
        cardShadow: Shadows.soft,
        elevatedShadow: Shadows.elevated,
        successColor: const Color(0xFF10B981),
        successContainerColor: const Color(0xFF10B981)
            .withValues(alpha: Opacities.badgeBackgroundSubtle),
      );

  // ── Static accessors ──────────────────────────────────────────────────────

  /// Retrieve from the nearest [Theme]. Falls back to dark theme defaults
  /// if the extension has not been registered (e.g. in tests with a bare
  /// [MaterialApp]).
  static EarthNovaTheme of(BuildContext context) =>
      Theme.of(context).extension<EarthNovaTheme>() ??
      EarthNovaTheme.dark(Theme.of(context).colorScheme);

  // ── Rarity (theme-independent) ────────────────────────────────────────────

  /// Badge background colour for each IUCN rarity tier.
  ///
  /// White → green → blue → gold → purple → amber.
  static Color rarityColor(IucnStatus status) => switch (status) {
        IucnStatus.leastConcern => const Color(0xFFFFFFFF), // white
        IucnStatus.nearThreatened => const Color(0xFF4CAF50), // green
        IucnStatus.vulnerable => const Color(0xFF2196F3), // blue
        IucnStatus.endangered => const Color(0xFFFFD700), // gold
        IucnStatus.criticallyEndangered => const Color(0xFF9C27B0), // purple
        IucnStatus.extinct => const Color(0xFFFFC107), // amber
      };

  /// Badge foreground colour — dark text on light backgrounds (white, gold,
  /// amber), white on everything else.
  static Color onRarityColor(IucnStatus status) => switch (status) {
        IucnStatus.leastConcern => const Color(0xFF1A1A2E), // dark on white
        IucnStatus.endangered => const Color(0xFF1A1A2E), // dark on gold
        IucnStatus.extinct => const Color(0xFF1A1A2E), // dark on amber
        _ => Colors.white,
      };

  /// Short IUCN code for badge labels.
  static String rarityLabel(IucnStatus status) => switch (status) {
        IucnStatus.leastConcern => 'LC',
        IucnStatus.nearThreatened => 'NT',
        IucnStatus.vulnerable => 'VU',
        IucnStatus.endangered => 'EN',
        IucnStatus.criticallyEndangered => 'CR',
        IucnStatus.extinct => 'EX',
      };

  // ── ThemeExtension overrides ──────────────────────────────────────────────

  @override
  EarthNovaTheme copyWith({
    Color? frostedGlassTint,
    Color? frostedGlassBorder,
    Color? frostedNotificationTint,
    Color? frostedNotificationBorder,
    List<BoxShadow>? cardShadow,
    List<BoxShadow>? elevatedShadow,
    Color? successColor,
    Color? successContainerColor,
  }) {
    return EarthNovaTheme(
      frostedGlassTint: frostedGlassTint ?? this.frostedGlassTint,
      frostedGlassBorder: frostedGlassBorder ?? this.frostedGlassBorder,
      frostedNotificationTint:
          frostedNotificationTint ?? this.frostedNotificationTint,
      frostedNotificationBorder:
          frostedNotificationBorder ?? this.frostedNotificationBorder,
      cardShadow: cardShadow ?? this.cardShadow,
      elevatedShadow: elevatedShadow ?? this.elevatedShadow,
      successColor: successColor ?? this.successColor,
      successContainerColor:
          successContainerColor ?? this.successContainerColor,
    );
  }

  @override
  ThemeExtension<EarthNovaTheme> lerp(
    covariant ThemeExtension<EarthNovaTheme>? other,
    double t,
  ) {
    if (other is! EarthNovaTheme) return this;
    return EarthNovaTheme(
      frostedGlassTint:
          Color.lerp(frostedGlassTint, other.frostedGlassTint, t)!,
      frostedGlassBorder:
          Color.lerp(frostedGlassBorder, other.frostedGlassBorder, t)!,
      frostedNotificationTint: Color.lerp(
          frostedNotificationTint, other.frostedNotificationTint, t)!,
      frostedNotificationBorder: Color.lerp(
          frostedNotificationBorder, other.frostedNotificationBorder, t)!,
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
      elevatedShadow: t < 0.5 ? elevatedShadow : other.elevatedShadow,
      successColor: Color.lerp(successColor, other.successColor, t)!,
      successContainerColor:
          Color.lerp(successContainerColor, other.successContainerColor, t)!,
    );
  }
}

// ── BuildContext extension ───────────────────────────────────────────────────

/// Convenience extension for accessing [EarthNovaTheme] from any widget.
///
/// ```dart
/// final nova = context.earthNova;
/// Container(color: nova.frostedGlassTint);
/// ```
extension EarthNovaBuildContext on BuildContext {
  /// Shorthand for `EarthNovaTheme.of(this)`.
  EarthNovaTheme get earthNova => EarthNovaTheme.of(this);
}
