import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'spacing.dart';

/// Single typed token authority. Values are provisional until visual calibration.
abstract final class DesignPalette {
  static const base = Color(0xff0b1a14);
  static const raised = Color(0xff203e2f);
  static const inset = Color(0xff10251b);
  static const text = Color(0xffffedc8);
  static const emphasis = Color(0xfff6c25b);
  static const primary = Color(0xffaed28a);
  static const information = Color(0xff58bee5);
  static const muted = Color(0xffb2c3b6);
  static const outline = Color(0xff06110c);
  static const highlight = Color(0xff557661);
  static const unavailable = Color(0xff4b5650);
  static const shadow = Color(0x99000000);
  static const fogFrontierFill = Color(0xB81B1B1B);
  static const fogFrontierStroke = Color(0x995C5C5C);
}

abstract final class DesignMetrics {
  static const touchTarget = 44.0;
  static const radius = BorderRadius.all(Radius.circular(6));
  static const cardRadius = BorderRadius.all(Radius.circular(4));
  static const outline = 1.0;
  static const bevel = 5.0;
  static const navigationIcon = 32.0;
  static const statIcon = 28.0;
  static const inspectionMaxWidth = 720.0;
  static const backdropOpacity = .76;
  static int packColumns(double width) =>
      width <= 600 ? 5 : (width / 104).floor().clamp(6, 24);
}

abstract final class DesignMotion {
  static const press = Duration(milliseconds: 70);
  static const release = Duration(milliseconds: 100);
  static const open = Duration(milliseconds: 120);
  static const close = Duration(milliseconds: 80);
  static const reveal = Duration(milliseconds: 360);
  static const idle = Duration(milliseconds: 2400);
  static Duration resolve(Duration value, {required bool reduced}) =>
      reduced ? Duration.zero : value;
  static Duration of(BuildContext context, Duration value) =>
      resolve(value, reduced: MediaQuery.disableAnimationsOf(context));
}

abstract final class DesignTypography {
  // Use the pinned Shad foundation's bundled font. Exact EarthNova font
  // selection remains a measured review decision, not a binary repo asset.
  static const family = 'packages/shadcn_ui/Geist';
  static const body = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: DesignPalette.text,
    decoration: TextDecoration.none,
  );
  static final label = body.copyWith(color: DesignPalette.emphasis);
  static final value = body.copyWith(
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  static final itemName = body.copyWith(
    fontSize: 32,
    fontWeight: FontWeight.w900,
  );
  static final action = body.copyWith(
    fontSize: 21,
    fontWeight: FontWeight.w900,
    shadows: const [
      Shadow(color: DesignPalette.outline, offset: Offset(-1.5, -1.5)),
      Shadow(color: DesignPalette.outline, offset: Offset(1.5, -1.5)),
      Shadow(color: DesignPalette.outline, offset: Offset(-1.5, 1.5)),
      Shadow(color: DesignPalette.outline, offset: Offset(1.5, 1.5)),
      Shadow(color: DesignPalette.outline, offset: Offset(-1.5, 0)),
      Shadow(color: DesignPalette.outline, offset: Offset(1.5, 0)),
      Shadow(color: DesignPalette.outline, offset: Offset(0, -1.5)),
      Shadow(color: DesignPalette.outline, offset: Offset(0, 1.5)),
    ],
  );
  static final cost = value.copyWith(fontSize: 14);
  static final compact = body.copyWith(fontSize: 12);
  static final ribbon = body.copyWith(
    fontSize: 26,
    fontWeight: FontWeight.w900,
    color: DesignPalette.outline,
  );
}

enum AppSurfaceTone { raised, inset, light, card }

abstract final class DesignSurfaces {
  static BoxDecoration panel(AppSurfaceTone tone, {bool selected = false}) {
    final face = switch (tone) {
      AppSurfaceTone.raised => DesignPalette.raised,
      AppSurfaceTone.inset => DesignPalette.inset,
      AppSurfaceTone.light => DesignPalette.text,
      AppSurfaceTone.card => DesignPalette.raised,
    };
    final isInset = tone == AppSurfaceTone.inset;
    return BoxDecoration(
      borderRadius: tone == AppSurfaceTone.card
          ? DesignMetrics.cardRadius
          : DesignMetrics.radius,
      border: Border.all(
        color: selected ? DesignPalette.text : DesignPalette.outline,
      ),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(face, DesignPalette.highlight, isInset ? 0 : .4)!,
          face,
          Color.lerp(face, DesignPalette.outline, .25)!,
        ],
        stops: const [0, .1, 1],
      ),
      boxShadow: isInset
          ? const []
          : const [
              BoxShadow(
                color: DesignPalette.outline,
                offset: Offset(0, DesignMetrics.bevel),
              ),
              BoxShadow(
                color: DesignPalette.shadow,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
    );
  }

  static const progressGloss = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [DesignPalette.text, DesignPalette.information],
    stops: [0, .35],
  );
}

abstract final class AppDesignTheme {
  static ShadThemeData dark() => ShadThemeData(
    brightness: Brightness.dark,
    colorScheme: const ShadZincColorScheme.dark().copyWith(
      background: DesignPalette.base,
      foreground: DesignPalette.text,
      card: DesignPalette.raised,
      cardForeground: DesignPalette.text,
      popover: DesignPalette.raised,
      popoverForeground: DesignPalette.text,
      primary: DesignPalette.primary,
      primaryForeground: DesignPalette.outline,
      secondary: DesignPalette.raised,
      secondaryForeground: DesignPalette.text,
      muted: DesignPalette.inset,
      mutedForeground: DesignPalette.muted,
      accent: DesignPalette.highlight,
      accentForeground: DesignPalette.text,
      border: DesignPalette.outline,
      input: DesignPalette.inset,
      ring: DesignPalette.information,
    ),
    radius: DesignMetrics.radius,
    textTheme: ShadTextTheme(
      family: DesignTypography.family,
      p: DesignTypography.body,
      small: DesignTypography.compact,
      large: DesignTypography.action,
    ),
    cardTheme: const ShadCardTheme(padding: EdgeInsets.all(Spacing.lg)),
  );
}
