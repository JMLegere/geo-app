import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/design_tokens.dart';

enum EarthTagTone { neutral, accent, success, warning, danger }

class EarthTag extends StatelessWidget {
  const EarthTag({
    required this.label,
    this.icon,
    this.tone = EarthTagTone.neutral,
    super.key,
  });

  final String label;
  final IconData? icon;
  final EarthTagTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = _colorsFor(tone, theme);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: colors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: colors.foreground),
              const SizedBox(width: Spacing.xs),
            ],
            Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.foreground,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

({Color background, Color border, Color foreground}) _colorsFor(
  EarthTagTone tone,
  ThemeData theme,
) {
  return switch (tone) {
    EarthTagTone.neutral => (
        background:
            theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.8),
        border: AppTheme.outline.withValues(alpha: 0.7),
        foreground: theme.colorScheme.onSurfaceVariant,
      ),
    EarthTagTone.accent => (
        background: theme.colorScheme.secondary.withValues(alpha: 0.18),
        border: theme.colorScheme.secondary.withValues(alpha: 0.58),
        foreground: theme.colorScheme.secondary,
      ),
    EarthTagTone.success => (
        background: theme.colorScheme.tertiary.withValues(alpha: 0.16),
        border: theme.colorScheme.tertiary.withValues(alpha: 0.56),
        foreground: theme.colorScheme.tertiary,
      ),
    EarthTagTone.warning => (
        background: theme.colorScheme.secondary.withValues(alpha: 0.22),
        border: theme.colorScheme.secondary.withValues(alpha: 0.72),
        foreground: theme.colorScheme.secondary,
      ),
    EarthTagTone.danger => (
        background: theme.colorScheme.error.withValues(alpha: 0.16),
        border: theme.colorScheme.error.withValues(alpha: 0.58),
        foreground: theme.colorScheme.error,
      ),
  };
}
