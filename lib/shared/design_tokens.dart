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
}
