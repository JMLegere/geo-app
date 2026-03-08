import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/shared/app_theme.dart';
import 'package:earth_nova/shared/earth_nova_theme.dart';

void main() {
  // ── ThemeExtension registration ────────────────────────────────────────────

  group('EarthNovaTheme registration', () {
    test('dark theme contains EarthNovaTheme extension', () {
      final theme = AppTheme.dark();
      final ext = theme.extension<EarthNovaTheme>();
      expect(ext, isNotNull, reason: 'EarthNovaTheme must be registered in dark theme');
    });

    test('light theme contains EarthNovaTheme extension', () {
      final theme = AppTheme.light();
      final ext = theme.extension<EarthNovaTheme>();
      expect(ext, isNotNull, reason: 'EarthNovaTheme must be registered in light theme');
    });
  });

  // ── Properties ─────────────────────────────────────────────────────────────

  group('EarthNovaTheme properties', () {
    late EarthNovaTheme dark;
    late EarthNovaTheme light;

    setUp(() {
      dark = AppTheme.dark().extension<EarthNovaTheme>()!;
      light = AppTheme.light().extension<EarthNovaTheme>()!;
    });

    test('frosted glass tints have non-zero alpha', () {
      expect(dark.frostedGlassTint.a, greaterThan(0));
      expect(light.frostedGlassTint.a, greaterThan(0));
      expect(dark.frostedNotificationTint.a, greaterThan(0));
      expect(light.frostedNotificationTint.a, greaterThan(0));
    });

    test('shadows are non-empty', () {
      expect(dark.cardShadow, isNotEmpty);
      expect(dark.elevatedShadow, isNotEmpty);
      expect(light.cardShadow, isNotEmpty);
      expect(light.elevatedShadow, isNotEmpty);
    });

    test('success colors are defined', () {
      expect(dark.successColor, isNotNull);
      expect(dark.successContainerColor, isNotNull);
      expect(light.successColor, isNotNull);
      expect(light.successContainerColor, isNotNull);
    });
  });

  // ── copyWith ───────────────────────────────────────────────────────────────

  group('EarthNovaTheme.copyWith', () {
    test('returns identical instance when no args passed', () {
      final original = AppTheme.dark().extension<EarthNovaTheme>()!;
      final copy = original.copyWith();

      expect(copy.frostedGlassTint, equals(original.frostedGlassTint));
      expect(copy.frostedGlassBorder, equals(original.frostedGlassBorder));
      expect(copy.successColor, equals(original.successColor));
      expect(copy.cardShadow, equals(original.cardShadow));
    });

    test('overrides only specified fields', () {
      final original = AppTheme.dark().extension<EarthNovaTheme>()!;
      const red = Color(0xFFFF0000);
      final copy = original.copyWith(successColor: red);

      expect(copy.successColor, equals(red));
      expect(copy.frostedGlassTint, equals(original.frostedGlassTint));
    });
  });

  // ── lerp ───────────────────────────────────────────────────────────────────

  group('EarthNovaTheme.lerp', () {
    test('lerp at t=0 returns this, t=1 returns other', () {
      final dark = AppTheme.dark().extension<EarthNovaTheme>()!;
      final light = AppTheme.light().extension<EarthNovaTheme>()!;

      final at0 = dark.lerp(light, 0.0) as EarthNovaTheme;
      final at1 = dark.lerp(light, 1.0) as EarthNovaTheme;

      expect(at0.frostedGlassTint, equals(dark.frostedGlassTint));
      expect(at1.frostedGlassTint, equals(light.frostedGlassTint));
    });

    test('lerp with null returns this', () {
      final dark = AppTheme.dark().extension<EarthNovaTheme>()!;
      final result = dark.lerp(null, 0.5);
      expect(result, same(dark));
    });
  });

  // ── Static helpers ─────────────────────────────────────────────────────────

  group('EarthNovaTheme static helpers', () {
    test('rarityColor returns distinct colors for each status', () {
      final colors = IucnStatus.values
          .map(EarthNovaTheme.rarityColor)
          .toSet();
      expect(colors.length, equals(IucnStatus.values.length),
          reason: 'Each IUCN status should have a unique rarity color');
    });

    test('onRarityColor is dark for nearThreatened, white otherwise', () {
      // Near Threatened uses yellow badge — needs dark text
      final ntColor = EarthNovaTheme.onRarityColor(IucnStatus.nearThreatened);
      expect(ntColor, isNot(equals(Colors.white)));

      // All others use white text
      for (final status in IucnStatus.values) {
        if (status == IucnStatus.nearThreatened) continue;
        expect(EarthNovaTheme.onRarityColor(status), equals(Colors.white),
            reason: '$status should use white on-rarity color');
      }
    });

    test('rarityLabel returns 2-letter codes', () {
      for (final status in IucnStatus.values) {
        final label = EarthNovaTheme.rarityLabel(status);
        expect(label.length, equals(2),
            reason: '$status label "$label" should be 2 characters');
      }
    });

    test('rarityColor matches AppTheme.rarityColor', () {
      for (final status in IucnStatus.values) {
        expect(
          EarthNovaTheme.rarityColor(status),
          equals(AppTheme.rarityColor(status)),
          reason: 'EarthNovaTheme and AppTheme rarity colors must match for $status',
        );
      }
    });

    test('onRarityColor matches AppTheme.onRarityColor', () {
      for (final status in IucnStatus.values) {
        expect(
          EarthNovaTheme.onRarityColor(status),
          equals(AppTheme.onRarityColor(status)),
          reason: 'EarthNovaTheme and AppTheme on-rarity colors must match for $status',
        );
      }
    });
  });

  // ── BuildContext extension ─────────────────────────────────────────────────

  group('BuildContext extension', () {
    testWidgets('context.earthNova returns theme extension', (tester) async {
      late EarthNovaTheme capturedTheme;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) {
              capturedTheme = context.earthNova;
              return const SizedBox();
            },
          ),
        ),
      );

      expect(capturedTheme, isNotNull);
      expect(capturedTheme.frostedGlassTint.a, greaterThan(0));
    });
  });
}
