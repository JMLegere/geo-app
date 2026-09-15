import 'package:flutter/material.dart';

import '../foundations/spacing.dart';
import '../primitives/app_text.dart';

class AppFieldRow extends StatelessWidget {
  const AppFieldRow({
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(label, role: AppTextRole.label),
                const SizedBox(height: Spacing.xs),
                AppText(value, role: AppTextRole.value),
                if (helper != null) ...[
                  const SizedBox(height: Spacing.xs),
                  AppText(helper!, role: AppTextRole.compact),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: Spacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}
