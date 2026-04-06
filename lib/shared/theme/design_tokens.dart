import 'package:flutter/material.dart';

/// Spacing scale based on an 8px grid.
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
}

/// Border radius scale.
abstract final class Radii {
  static const double xs = 4;
  static const double sm = 6;
  static const double md = 8;
  static const double lg = 10;
  static const double xl = 12;
  static const double xxl = 14;
  static const double xxxl = 16;
  static const double pill = 100;
}

/// Animation durations.
abstract final class Durations {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration quick = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
  static const Duration ellipsis = Duration(milliseconds: 400);
}

/// Standard animation curves.
abstract final class AppCurves {
  static const Curve standard = Curves.easeInOut;
  static const Curve fadeIn = Curves.easeOut;
}

/// Component sizes.
abstract final class ComponentSizes {
  static const double buttonHeight = 52;
  static const double emptyStateIcon = 52;

  // ── Filter system ─────────────────────────────────────────────────────────

  /// Square icon-only toggle chip (taxon / habitat / region).
  static const double filterToggleSize = 36;

  /// Minimum touch target width — applied as invisible padding if needed.
  static const double filterToggleMinWidth = 44;

  /// Rarity toggle width — wider than square to fit 2-char code at 13px.
  static const double rarityToggleWidth = 48;

  /// Sort toggle height — same as filterToggleSize; width is auto.
  static const double sortToggleHeight = 36;

  /// Collapsed filter bar total height (tappable area).
  static const double compactBarHeight = 44;

  /// Mini filter chip in compact bar (emoji only, no border).
  static const double miniChipSize = 22;

  // ── Icon font sizes ───────────────────────────────────────────────────────

  /// Emoji font size in category row (top, always visible).
  static const double categoryRowEmoji = 20;

  /// Emoji font size in expanded filter panel toggles.
  static const double filterPanelEmoji = 18;

  /// Emoji font size in compact bar mini-chips.
  static const double compactBarEmoji = 13;

  /// Font size for IUCN code text in rarity toggles and badges.
  static const double rarityCodeFont = 13;

  /// Font size for sort/filter chip labels (below icon in sort row).
  static const double filterLabelFont = 10;
}
