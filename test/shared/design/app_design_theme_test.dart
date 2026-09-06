import 'package:earth_nova/shared/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  test('semantic foregrounds remain readable on the forest surfaces', () {
    for (final background in [
      DesignPalette.base,
      DesignPalette.raised,
      DesignPalette.inset,
    ]) {
      for (final foreground in [DesignPalette.text, DesignPalette.emphasis]) {
        final ratio =
            (foreground.computeLuminance() + .05) /
            (background.computeLuminance() + .05);
        expect(ratio, greaterThanOrEqualTo(4.5));
      }
    }
  });
  test('EarthNova overrides preserve unspecified Shad defaults', () {
    final theme = AppDesignTheme.dark();
    final defaults = ShadThemeData(
      brightness: Brightness.dark,
      colorScheme: const ShadZincColorScheme.dark(),
    );
    expect(theme.colorScheme.background, DesignPalette.base);
    expect(theme.colorScheme.foreground, DesignPalette.text);
    expect(theme.colorScheme.destructive, defaults.colorScheme.destructive);
    expect(theme.primaryButtonTheme.size, defaults.primaryButtonTheme.size);
  });
  test('provisional typography reuses the pinned Shad font asset', () {
    expect(DesignTypography.family, 'packages/shadcn_ui/Geist');
  });
  test('phone density stays at five while wider layouts add columns', () {
    for (final width in [320.0, 390.0, 430.0, 600.0]) {
      expect(DesignMetrics.packColumns(width), 5);
    }
    expect(DesignMetrics.packColumns(840), 8);
    expect(DesignMetrics.packColumns(1280), greaterThan(8));
    expect(DesignMetrics.touchTarget, greaterThanOrEqualTo(44));
  });
  test('reduced motion suppresses decorative durations', () {
    expect(
      DesignMotion.resolve(DesignMotion.press, reduced: true),
      Duration.zero,
    );
    expect(
      DesignMotion.resolve(DesignMotion.press, reduced: false),
      DesignMotion.press,
    );
    expect(DesignMotion.close, lessThan(DesignMotion.open));
    expect(DesignMotion.release.inMilliseconds, lessThanOrEqualTo(100));
  });
}
