import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/design_tokens.dart';
import 'meta_text.dart';

enum EarthNoticeTone { info, success, warning, danger }

class EarthNotice extends StatelessWidget {
  const EarthNotice({
    required this.title,
    required this.message,
    this.tone = EarthNoticeTone.info,
    super.key,
  });

  final String title;
  final String message;
  final EarthNoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accentFor(tone, theme);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: accent.withValues(alpha: 0.56)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            EarthMetaText(title, tone: _metaToneFor(tone)),
            const SizedBox(height: Spacing.sm),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.onSurface,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Color _accentFor(EarthNoticeTone tone, ThemeData theme) {
  return switch (tone) {
    EarthNoticeTone.info => theme.colorScheme.primary,
    EarthNoticeTone.success => theme.colorScheme.tertiary,
    EarthNoticeTone.warning => theme.colorScheme.secondary,
    EarthNoticeTone.danger => theme.colorScheme.error,
  };
}

EarthMetaTone _metaToneFor(EarthNoticeTone tone) {
  return switch (tone) {
    EarthNoticeTone.info => EarthMetaTone.accent,
    EarthNoticeTone.success => EarthMetaTone.accent,
    EarthNoticeTone.warning => EarthMetaTone.accent,
    EarthNoticeTone.danger => EarthMetaTone.accent,
  };
}
