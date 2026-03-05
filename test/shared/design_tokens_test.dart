import 'package:flutter/material.dart' hide Durations;
import 'package:flutter_test/flutter_test.dart';

import 'package:fog_of_world/shared/design_tokens.dart';

void main() {
  // ── Spacing ────────────────────────────────────────────────────────────────

  group('Spacing', () {
    test('scale is strictly increasing', () {
      final scale = [
        Spacing.xxs,
        Spacing.xs,
        Spacing.sm,
        Spacing.md,
        Spacing.lg,
        Spacing.xl,
        Spacing.xxl,
        Spacing.xxxl,
        Spacing.huge,
        Spacing.massive,
        Spacing.giant,
      ];
      for (var i = 1; i < scale.length; i++) {
        expect(scale[i], greaterThan(scale[i - 1]),
            reason: 'Spacing scale must be strictly increasing at index $i');
      }
    });

    test('pre-built EdgeInsets use scale values', () {
      expect(Spacing.paddingCard.left, equals(Spacing.lg));
      expect(Spacing.paddingCard.top, equals(Spacing.md));
      expect(Spacing.paddingToast.left, equals(Spacing.lg));
      expect(Spacing.paddingToast.top, equals(Spacing.md));
      expect(Spacing.paddingBadge.left, equals(Spacing.sm));
      expect(Spacing.paddingBadge.top, equals(Spacing.xxs));
    });

    test('gap SizedBoxes match named sizes', () {
      // Vertical gaps
      expect(Spacing.gapXs.height, equals(Spacing.xs));
      expect(Spacing.gapSm.height, equals(Spacing.sm));
      expect(Spacing.gapMd.height, equals(Spacing.md));
      expect(Spacing.gapLg.height, equals(Spacing.lg));
      expect(Spacing.gapXl.height, equals(Spacing.xl));
      expect(Spacing.gapXxl.height, equals(Spacing.xxl));
      expect(Spacing.gapHuge.height, equals(Spacing.huge));

      // Horizontal gaps
      expect(Spacing.gapHXs.width, equals(Spacing.xs));
      expect(Spacing.gapHSm.width, equals(Spacing.sm));
      expect(Spacing.gapHMd.width, equals(Spacing.md));
      expect(Spacing.gapHLg.width, equals(Spacing.lg));
    });
  });

  // ── Radii ──────────────────────────────────────────────────────────────────

  group('Radii', () {
    test('scale is strictly increasing', () {
      final scale = [
        Radii.xs,
        Radii.sm,
        Radii.md,
        Radii.lg,
        Radii.xl,
        Radii.xxl,
        Radii.xxxl,
        Radii.pill,
      ];
      for (var i = 1; i < scale.length; i++) {
        expect(scale[i], greaterThan(scale[i - 1]),
            reason: 'Radii scale must be strictly increasing at index $i');
      }
    });

    test('pre-built BorderRadius objects match raw values', () {
      expect(Radii.borderXs, equals(BorderRadius.circular(Radii.xs)));
      expect(Radii.borderSm, equals(BorderRadius.circular(Radii.sm)));
      expect(Radii.borderMd, equals(BorderRadius.circular(Radii.md)));
      expect(Radii.borderLg, equals(BorderRadius.circular(Radii.lg)));
      expect(Radii.borderXl, equals(BorderRadius.circular(Radii.xl)));
      expect(Radii.borderXxl, equals(BorderRadius.circular(Radii.xxl)));
      expect(Radii.borderXxxl, equals(BorderRadius.circular(Radii.xxxl)));
      expect(Radii.borderPill, equals(BorderRadius.circular(Radii.pill)));
    });
  });

  // ── Shadows ────────────────────────────────────────────────────────────────

  group('Shadows', () {
    test('all shadow lists are non-empty', () {
      expect(Shadows.soft, isNotEmpty);
      expect(Shadows.medium, isNotEmpty);
      expect(Shadows.elevated, isNotEmpty);
      expect(Shadows.elevatedDark, isNotEmpty);
    });

    test('blur radius increases with intensity', () {
      final softBlur = Shadows.soft.first.blurRadius;
      final mediumBlur = Shadows.medium.first.blurRadius;
      final elevatedBlur = Shadows.elevated.first.blurRadius;

      expect(mediumBlur, greaterThanOrEqualTo(softBlur));
      expect(elevatedBlur, greaterThan(mediumBlur));
    });
  });

  // ── Durations ──────────────────────────────────────────────────────────────

  group('Durations', () {
    test('animation durations are strictly increasing', () {
      final scale = [
        Durations.instant,
        Durations.quick,
        Durations.normal,
        Durations.slow,
      ];
      for (var i = 1; i < scale.length; i++) {
        expect(scale[i], greaterThan(scale[i - 1]),
            reason: 'Duration scale must be strictly increasing at index $i');
      }
    });

    test('toast durations are longer than animation durations', () {
      expect(Durations.discoveryToast, greaterThan(Durations.slow));
      expect(Durations.achievementToast, greaterThan(Durations.slow));
    });
  });

  // ── Blurs ──────────────────────────────────────────────────────────────────

  group('Blurs', () {
    test('all values are positive', () {
      expect(Blurs.subtle, greaterThan(0));
      expect(Blurs.statusBar, greaterThan(0));
      expect(Blurs.frostedGlass, greaterThan(0));
    });

    test('frostedGlass is strongest blur', () {
      expect(Blurs.frostedGlass, greaterThan(Blurs.statusBar));
      expect(Blurs.statusBar, greaterThan(Blurs.subtle));
    });
  });

  // ── Opacities ──────────────────────────────────────────────────────────────

  group('Opacities', () {
    test('all values are in valid range [0, 1]', () {
      final values = [
        Opacities.frostedDark,
        Opacities.frostedLight,
        Opacities.frostedNotification,
        Opacities.borderSubtle,
        Opacities.borderLight,
        Opacities.borderMedium,
        Opacities.borderFrosted,
        Opacities.habitatGradientStart,
        Opacities.habitatGradientEnd,
        Opacities.habitatGradientCardStart,
        Opacities.habitatGradientCardEnd,
        Opacities.chipBackground,
        Opacities.badgeBackground,
        Opacities.badgeBackgroundSubtle,
      ];
      for (final v in values) {
        expect(v, inInclusiveRange(0.0, 1.0), reason: 'Opacity $v out of range');
      }
    });

    test('notification frosted is most opaque', () {
      expect(Opacities.frostedNotification,
          greaterThan(Opacities.frostedLight));
      expect(Opacities.frostedLight, greaterThan(Opacities.frostedDark));
    });
  });

  // ── ComponentSizes ─────────────────────────────────────────────────────────

  group('ComponentSizes', () {
    test('all sizes are positive', () {
      expect(ComponentSizes.notificationIcon, greaterThan(0));
      expect(ComponentSizes.buttonHeight, greaterThan(0));
      expect(ComponentSizes.emptyStateEmoji, greaterThan(0));
      expect(ComponentSizes.notificationEmoji, greaterThan(0));
      expect(ComponentSizes.silhouetteBox, greaterThan(0));
    });
  });
}
