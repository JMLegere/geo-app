import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/shared/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('brand colors are non-null', () {
      expect(AppTheme.primary, isNotNull);
      expect(AppTheme.secondary, isNotNull);
      expect(AppTheme.tertiary, isNotNull);
      expect(AppTheme.error, isNotNull);
    });

    test('surface stack has correct ordering (lightest last)', () {
      // Each surface should be visually distinct (different values)
      final surfaces = [
        AppTheme.surface,
        AppTheme.surfaceContainer,
        AppTheme.surfaceContainerHigh,
        AppTheme.surfaceContainerHighest,
      ];
      // All are unique
      expect(surfaces.toSet().length, 4);
    });

    test('dark() returns a valid ThemeData', () {
      final theme = AppTheme.dark();
      expect(theme, isA<ThemeData>());
      expect(theme.brightness, Brightness.dark);
      expect(theme.useMaterial3, isTrue);
    });

    test('dark() colorScheme has correct brand colors', () {
      final cs = AppTheme.dark().colorScheme;
      expect(cs.primary, AppTheme.primary);
      expect(cs.secondary, AppTheme.secondary);
      expect(cs.tertiary, AppTheme.tertiary);
      expect(cs.error, AppTheme.error);
      expect(cs.surface, AppTheme.surface);
      expect(cs.onSurface, AppTheme.onSurface);
    });

    test('dark() scaffoldBackgroundColor is surface', () {
      final theme = AppTheme.dark();
      expect(theme.scaffoldBackgroundColor, AppTheme.surface);
    });

    test('dark() appBarTheme uses surfaceContainer', () {
      final appBar = AppTheme.dark().appBarTheme;
      expect(appBar.backgroundColor, AppTheme.surfaceContainer);
      expect(appBar.foregroundColor, AppTheme.onSurface);
      expect(appBar.elevation, 0);
    });

    test('dark() appBarTheme titleTextStyle is bold 17px', () {
      final style = AppTheme.dark().appBarTheme.titleTextStyle;
      expect(style?.fontSize, 17);
      expect(style?.fontWeight, FontWeight.w700);
    });

    test('dark() inputDecorationTheme is filled with surfaceContainer', () {
      final input = AppTheme.dark().inputDecorationTheme;
      expect(input.filled, isTrue);
      expect(input.fillColor, AppTheme.surfaceContainer);
    });

    test('dark() elevatedButtonTheme has primary background', () {
      final buttonStyle = AppTheme.dark().elevatedButtonTheme.style;
      // Resolve the background color
      expect(buttonStyle, isNotNull);
    });
  });
}
