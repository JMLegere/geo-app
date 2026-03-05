import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:fog_of_world/shared/design_tokens.dart';
import 'package:fog_of_world/shared/earth_nova_theme.dart';

/// A translucent frosted-glass container with backdrop blur.
///
/// Used for status bars, notification toasts, and overlay panels.
/// Automatically adapts to dark/light theme via [EarthNovaTheme].
///
/// ## Usage
/// ```dart
/// FrostedGlassContainer(
///   blur: Blurs.frostedGlass,
///   child: Row(children: [...]),
/// )
/// ```
///
/// ## Variants
/// - Default: uses [EarthNovaTheme.frostedGlassTint] — for status bars, panels.
/// - `notification`: uses [EarthNovaTheme.frostedNotificationTint] — for toasts.
///
/// Set [isNotification] to `true` for the notification variant.
class FrostedGlassContainer extends StatelessWidget {
  const FrostedGlassContainer({
    required this.child,
    this.blur = Blurs.frostedGlass,
    this.borderRadius = Radii.xxxl,
    this.padding = Spacing.paddingToast,
    this.isNotification = false,
    this.bottomBorderOnly = false,
    super.key,
  });

  /// The widget displayed inside the frosted container.
  final Widget child;

  /// Backdrop blur sigma. Defaults to [Blurs.frostedGlass] (20).
  final double blur;

  /// Corner radius. Defaults to [Radii.xxxl] (16px).
  final double borderRadius;

  /// Inner padding. Defaults to [Spacing.paddingToast].
  final EdgeInsets padding;

  /// When true, uses the slightly opaquer notification tint + elevated shadow.
  final bool isNotification;

  /// When true, only shows a bottom border (for status bars flush to screen edge).
  final bool bottomBorderOnly;

  @override
  Widget build(BuildContext context) {
    final nova = context.earthNova;

    final tintColor =
        isNotification ? nova.frostedNotificationTint : nova.frostedGlassTint;
    final borderColor = isNotification
        ? nova.frostedNotificationBorder
        : nova.frostedGlassBorder;
    final shadow = isNotification ? nova.elevatedShadow : <BoxShadow>[];

    final shape = bottomBorderOnly
        ? BoxDecoration(
            color: tintColor,
            border: Border(
              bottom: BorderSide(color: borderColor, width: 0.5),
            ),
          )
        : BoxDecoration(
            color: tintColor,
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: shadow,
            border: Border.all(color: borderColor, width: 0.5),
          );

    final clip = bottomBorderOnly
        ? ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: Container(
                padding: padding,
                decoration: shape,
                child: child,
              ),
            ),
          )
        : ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: Container(
                padding: padding,
                decoration: shape,
                child: child,
              ),
            ),
          );

    return clip;
  }
}
