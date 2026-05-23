import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/design_tokens.dart';

enum EarthActionTone { primary, secondary, neutral, danger }

class EarthActionButton extends StatelessWidget {
  const EarthActionButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = EarthActionTone.primary,
    this.expand = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final EarthActionTone tone;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = _foregroundFor(tone, theme);
    final background = _backgroundFor(tone, theme);
    final disabledBackground = theme.colorScheme.surfaceContainerHigh;

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: background,
      disabledBackgroundColor: disabledBackground,
      foregroundColor: foreground,
      disabledForegroundColor: theme.colorScheme.onSurfaceVariant,
      minimumSize: const Size(0, ComponentSizes.buttonHeight),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.sm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
      textStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
    );

    final child = icon == null
        ? ElevatedButton(
            onPressed: onPressed,
            style: buttonStyle,
            child: Text(label),
          )
        : ElevatedButton.icon(
            onPressed: onPressed,
            style: buttonStyle,
            icon: Icon(icon, size: 18),
            label: Text(label),
          );

    if (!expand) return child;

    return SizedBox(
      width: double.infinity,
      child: child,
    );
  }
}

Color _backgroundFor(EarthActionTone tone, ThemeData theme) {
  return switch (tone) {
    EarthActionTone.primary => theme.colorScheme.primary,
    EarthActionTone.secondary => theme.colorScheme.secondary,
    EarthActionTone.neutral => theme.colorScheme.surfaceContainerHighest,
    EarthActionTone.danger => theme.colorScheme.error,
  };
}

Color _foregroundFor(EarthActionTone tone, ThemeData theme) {
  return switch (tone) {
    EarthActionTone.primary => theme.colorScheme.onPrimary,
    EarthActionTone.secondary => theme.colorScheme.onSecondary,
    EarthActionTone.neutral => AppTheme.onSurface,
    EarthActionTone.danger => theme.colorScheme.onError,
  };
}
