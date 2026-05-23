import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/design_tokens.dart';
import '../primitives/meta_text.dart';

enum EarthPanelTone { defaultTone, accent, success, warning }

class EarthPanel extends StatelessWidget {
  const EarthPanel({
    required this.title,
    required this.child,
    this.eyebrow,
    this.actions = const [],
    this.tone = EarthPanelTone.defaultTone,
    super.key,
  });

  final String title;
  final String? eyebrow;
  final Widget child;
  final List<Widget> actions;
  final EarthPanelTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accentFor(tone, theme);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(Radii.xxl),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.surface.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (eyebrow != null) ...[
                        EarthMetaText(eyebrow!, tone: EarthMetaTone.accent),
                        const SizedBox(height: Spacing.xs),
                      ],
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppTheme.onSurface,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(width: Spacing.md),
                  Wrap(
                    spacing: Spacing.sm,
                    runSpacing: Spacing.sm,
                    alignment: WrapAlignment.end,
                    children: actions,
                  ),
                ],
              ],
            ),
            const SizedBox(height: Spacing.lg),
            child,
          ],
        ),
      ),
    );
  }
}

Color _accentFor(EarthPanelTone tone, ThemeData theme) {
  return switch (tone) {
    EarthPanelTone.defaultTone => AppTheme.outline,
    EarthPanelTone.accent => theme.colorScheme.primary,
    EarthPanelTone.success => theme.colorScheme.tertiary,
    EarthPanelTone.warning => theme.colorScheme.secondary,
  };
}
