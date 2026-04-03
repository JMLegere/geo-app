import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/earth_nova_theme.dart';

/// A translucent frosted-glass container with backdrop blur.
///
/// Used for status bars, notification toasts, and overlays.
/// Adapts automatically to dark/light theme via [EarthNovaTheme].
class FrostedGlassContainer extends StatelessWidget {
  final Widget child;

  /// Backdrop blur sigma. Defaults to [Blurs.frostedGlass].
  final double blur;

  /// When true, renders border on bottom edge only (status bar style).
  final bool bottomBorderOnly;

  /// Border radius in logical pixels. Pass `0` for sharp corners.
  final double borderRadius;

  /// Inner padding. Defaults to [Spacing.paddingCard].
  final EdgeInsetsGeometry? padding;

  /// When true, uses notification-level opacity (higher contrast).
  final bool isNotification;

  const FrostedGlassContainer({
    super.key,
    required this.child,
    this.blur = Blurs.frostedGlass,
    this.bottomBorderOnly = false,
    this.borderRadius = Radii.lg,
    this.padding,
    this.isNotification = false,
  });

  @override
  Widget build(BuildContext context) {
    final nova = EarthNovaTheme.of(context);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tintOpacity = isNotification
        ? Opacities.frostedNotification
        : (isDark ? Opacities.frostedDark : Opacities.frostedLight);
    final tint = nova.frostedGlassTint.withValues(alpha: tintOpacity);

    final border = Border(
      bottom: BorderSide(
        color: cs.outline.withValues(alpha: Opacities.borderFrosted),
        width: 0.5,
      ),
    );
    final fullBorder = Border.all(
      color: cs.outline.withValues(alpha: Opacities.borderFrosted),
      width: 0.5,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding ?? Spacing.paddingCard,
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(borderRadius),
            border: bottomBorderOnly ? border : fullBorder,
          ),
          child: child,
        ),
      ),
    );
  }
}
