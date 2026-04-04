import 'package:flutter/material.dart';

/// IUCN conservation status — canonical rarity definition including
/// display colors. This is the single source of truth; no widget should
/// hard-code rarity colors.
///
/// Color associations:
///   CR = purple (0xFF9C27B0) — rarest, most vivid
///   EN = gold   (0xFFFFD700) — urgent warning
///   VU = blue   (0xFF2196F3) — elevated concern
///   NT = green  (0xFF4CAF50) — watch-list
///   LC = gray   (0xFFCDD5DB) — stable, neutral
///   EX = dim    (0xFF757575) — gone, muted
enum IucnStatus {
  leastConcern(
    'LC',
    'Least Concern',
    Color(0xFFCDD5DB),
    Color(0xFF1A1A2E),
    borderAlpha: 0.15,
    glowAlpha: 0.0,
  ),
  nearThreatened(
    'NT',
    'Near Threatened',
    Color(0xFF4CAF50),
    Colors.white,
    borderAlpha: 0.50,
    glowAlpha: 0.0,
  ),
  vulnerable(
    'VU',
    'Vulnerable',
    Color(0xFF2196F3),
    Colors.white,
    borderAlpha: 0.65,
    glowAlpha: 0.15,
  ),
  endangered(
    'EN',
    'Endangered',
    Color(0xFFFFD700),
    Color(0xFF1A1A2E),
    borderAlpha: 0.85,
    glowAlpha: 0.25,
  ),
  criticallyEndangered(
    'CR',
    'Critically Endangered',
    Color(0xFF9C27B0),
    Colors.white,
    borderAlpha: 0.90,
    glowAlpha: 0.35,
  ),
  extinct(
    'EX',
    'Extinct',
    Color(0xFF757575),
    Colors.white,
    borderAlpha: 0.40,
    glowAlpha: 0.0,
  );

  const IucnStatus(
    this.code,
    this.displayName,
    this.color,
    this.fgColor, {
    required this.borderAlpha,
    required this.glowAlpha,
  });

  /// Short code for badge labels (e.g. "LC", "EN").
  final String code;

  /// Full display name (e.g. "Least Concern").
  final String displayName;

  /// The rarity accent color. Used for card borders, glow, and filter chips.
  final Color color;

  /// Foreground (text) color on the rarity badge — dark for light colors
  /// (EN gold, LC gray), white for all others.
  final Color fgColor;

  /// Border opacity on item cards (0.0–1.0).
  final double borderAlpha;

  /// BoxShadow blur alpha on item cards. 0.0 = no glow (NT, LC, EX).
  final double glowAlpha;

  /// Parse from a string (case-insensitive). Returns null if unknown.
  static IucnStatus? fromString(String? value) {
    if (value == null) return null;
    for (final status in IucnStatus.values) {
      if (status.name.toLowerCase() == value.toLowerCase() ||
          status.code.toLowerCase() == value.toLowerCase()) {
        return status;
      }
    }
    return null;
  }
}
