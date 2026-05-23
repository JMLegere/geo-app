import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

enum EarthMetaTone { muted, accent, inverse }

class EarthMetaText extends StatelessWidget {
  const EarthMetaText(
    this.text, {
    this.tone = EarthMetaTone.muted,
    this.textAlign,
    super.key,
  });

  final String text;
  final EarthMetaTone tone;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      text.toUpperCase(),
      textAlign: textAlign,
      style: theme.textTheme.labelSmall?.copyWith(
        color: _colorFor(tone, theme),
        fontFamily: 'monospace',
        fontWeight: FontWeight.w700,
        letterSpacing: 0.7,
      ),
    );
  }
}

Color _colorFor(EarthMetaTone tone, ThemeData theme) {
  return switch (tone) {
    EarthMetaTone.muted => theme.colorScheme.onSurfaceVariant,
    EarthMetaTone.accent => theme.colorScheme.secondary,
    EarthMetaTone.inverse => AppTheme.surface,
  };
}
