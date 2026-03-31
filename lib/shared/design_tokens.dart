import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// EarthNova Design Tokens
//
// Centralized visual constants for spacing, radii, shadows, animation, blur,
// and opacity. Every widget should reference these instead of inline literals.
//
// Game-balance constants live in constants.dart — this file is VISUAL ONLY.
// ═══════════════════════════════════════════════════════════════════════════════

// ── Spacing (8px base grid) ─────────────────────────────────────────────────

/// Spacing scale for padding, margin, and gap values.
///
/// Based on an 8px grid with half-steps for fine control.
/// Usage: `SizedBox(height: Spacing.md)`, `EdgeInsets.all(Spacing.lg)`.
abstract final class Spacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
  static const double massive = 48;
  static const double giant = 64;

  // ── Pre-built EdgeInsets ──────────────────────────────────────────────────

  /// Horizontal padding for cards and list items.
  static const EdgeInsets paddingCardH = EdgeInsets.symmetric(horizontal: lg);

  /// Standard card padding (horizontal + vertical).
  static const EdgeInsets paddingCard =
      EdgeInsets.symmetric(horizontal: lg, vertical: md);

  /// Screen-level horizontal padding.
  static const EdgeInsets paddingScreenH = EdgeInsets.symmetric(horizontal: lg);

  /// Notification/toast padding.
  static const EdgeInsets paddingToast =
      EdgeInsets.symmetric(horizontal: lg, vertical: md);

  /// Chip/badge inner padding.
  static const EdgeInsets paddingBadge =
      EdgeInsets.symmetric(horizontal: sm, vertical: xxs);

  /// Compact badge padding (rarity labels).
  static const EdgeInsets paddingBadgeCompact =
      EdgeInsets.symmetric(horizontal: 6, vertical: 2);

  // ── Pre-built SizedBox gaps ──────────────────────────────────────────────

  static const SizedBox gapXs = SizedBox(height: xs);
  static const SizedBox gapSm = SizedBox(height: sm);
  static const SizedBox gapMd = SizedBox(height: md);
  static const SizedBox gapLg = SizedBox(height: lg);
  static const SizedBox gapXl = SizedBox(height: xl);
  static const SizedBox gapXxl = SizedBox(height: xxl);
  static const SizedBox gapHuge = SizedBox(height: huge);

  static const SizedBox gapHXs = SizedBox(width: xs);
  static const SizedBox gapHSm = SizedBox(width: sm);
  static const SizedBox gapHMd = SizedBox(width: md);
  static const SizedBox gapHLg = SizedBox(width: lg);
}

// ── Border Radius ───────────────────────────────────────────────────────────

/// Border radius scale — consistent rounding across all components.
///
/// Usage: `borderRadius: Radii.md` in BoxDecoration.
abstract final class Radii {
  // Raw values
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 10;
  static const double xl = 12;
  static const double xxl = 14;
  static const double xxxl = 16;
  static const double pill = 100;

  // Pre-built BorderRadius objects
  static final BorderRadius borderXs = BorderRadius.circular(xs);
  static final BorderRadius borderSm = BorderRadius.circular(sm);
  static final BorderRadius borderMd = BorderRadius.circular(md);
  static final BorderRadius borderLg = BorderRadius.circular(lg);
  static final BorderRadius borderXl = BorderRadius.circular(xl);
  static final BorderRadius borderXxl = BorderRadius.circular(xxl);
  static final BorderRadius borderXxxl = BorderRadius.circular(xxxl);
  static final BorderRadius borderPill = BorderRadius.circular(pill);
}

// ── Shadows ─────────────────────────────────────────────────────────────────

/// Shadow definitions — soft watercolour-appropriate shadows.
///
/// Dark mode uses higher opacity; light mode uses lower. Pass the
/// appropriate list to `BoxDecoration.boxShadow`.
abstract final class Shadows {
  /// Subtle card shadow — species tiles, sanctuary tiles.
  static const List<BoxShadow> soft = [
    BoxShadow(
      color: Color(0x0F000000), // 6% black
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  /// Medium card shadow — species cards, notification toasts.
  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x12000000), // 7% black
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Elevated shadow — frosted glass overlays, modals.
  static const List<BoxShadow> elevated = [
    BoxShadow(
      color: Color(0x1F000000), // 12% black
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  /// Dark-mode elevated shadow — higher contrast for dark surfaces.
  static const List<BoxShadow> elevatedDark = [
    BoxShadow(
      color: Color(0x66000000), // 40% black
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];
}

// ── Animation ───────────────────────────────────────────────────────────────

/// Standard animation durations.
abstract final class Durations {
  /// Micro interactions — icon state, opacity toggles.
  static const Duration instant = Duration(milliseconds: 100);

  /// Quick transitions — chip select, badge appear.
  static const Duration quick = Duration(milliseconds: 150);

  /// Default transitions — page changes, indicator dot.
  static const Duration normal = Duration(milliseconds: 250);

  /// Slide-in/slide-out — notification toasts, overlays.
  static const Duration slow = Duration(milliseconds: 350);

  /// Auto-dismiss for discovery toasts.
  static const Duration discoveryToast = Duration(seconds: 3);

  /// Auto-dismiss for achievement toasts.
  static const Duration achievementToast = Duration(seconds: 4);

  /// Auto-dismiss for sync status toasts.
  static const Duration syncToast = Duration(seconds: 2);

  /// Player marker pulse cycle.
  static const Duration markerPulse = Duration(seconds: 2);

  /// Full cycle for the prismatic/rainbow border on first-discovery item cards.
  ///
  /// One complete revolution of the HSV spectrum around the card edge.
  /// Slow and hypnotic — 3.5 s keeps it magical without being distracting.
  static const Duration prismaticCycle = Duration(milliseconds: 3500);

  /// Full cycle for the sprite idle breathing animation.
  static const Duration spriteIdle = Duration(milliseconds: 1800);

  /// District infographic scale+fade transition.
  static const Duration infographicTransition = Duration(milliseconds: 300);
}

/// Standard animation curves.
abstract final class AppCurves {
  /// Default easing — most transitions.
  static const Curve standard = Curves.easeInOut;

  /// Slide-in from off-screen — toasts, overlays.
  static const Curve slideIn = Curves.easeOutCubic;

  /// Fade-in — opacity transitions.
  static const Curve fadeIn = Curves.easeOut;

  /// Bounce effect — achievement unlock, discovery moment.
  static const Curve bounce = Curves.elasticOut;
}

// ── Blur ─────────────────────────────────────────────────────────────────────

/// Backdrop blur sigma values for frosted-glass effects.
abstract final class Blurs {
  /// Status bar — lighter blur over map.
  static const double statusBar = 12;

  /// Notification cards — stronger frosted-glass effect.
  static const double frostedGlass = 20;

  /// Subtle background blur — detail sheets.
  static const double subtle = 8;
}

// ── Opacity ─────────────────────────────────────────────────────────────────

/// Named opacity values for consistent translucency.
abstract final class Opacities {
  // Frosted glass tints
  static const double frostedDark = 0.82;
  static const double frostedLight = 0.88;
  static const double frostedNotification = 0.92;

  // Borders
  static const double borderSubtle = 0.2;
  static const double borderLight = 0.25;
  static const double borderMedium = 0.3;
  static const double borderFrosted = 0.6;

  // Habitat gradients (for card backgrounds)
  static const double habitatGradientStart = 0.20;
  static const double habitatGradientEnd = 0.05;
  static const double habitatGradientCardStart = 0.35;
  static const double habitatGradientCardEnd = 0.12;

  // Chip/badge backgrounds
  static const double chipBackground = 0.5;
  static const double badgeBackground = 0.15;
  static const double badgeBackgroundSubtle = 0.12;
}

// ── Component Sizes ─────────────────────────────────────────────────────────

/// Fixed sizes for common components.
abstract final class ComponentSizes {
  /// Notification icon container (discovery, achievement toasts).
  static const double notificationIcon = 44;

  /// Standard button height.
  static const double buttonHeight = 52;

  /// Empty-state icon size.
  static const double emptyStateIcon = 52;

  /// Notification icon size (font/icon size inside notification container).
  static const double notificationIconSize = 24;

  /// Silhouette placeholder size (uncollected species).
  static const double silhouetteBox = 48;
}
