import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/design_tokens.dart';
import '../primitives/meta_text.dart';

class EarthFieldRow extends StatelessWidget {
  const EarthFieldRow({
    required this.label,
    required this.value,
    this.helper,
    this.trailing,
    super.key,
  });

  final String label;
  final String value;
  final String? helper;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EarthMetaText(label),
                const SizedBox(height: Spacing.xs),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (helper != null) ...[
                  const SizedBox(height: Spacing.xs),
                  Text(
                    helper!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: Spacing.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}
