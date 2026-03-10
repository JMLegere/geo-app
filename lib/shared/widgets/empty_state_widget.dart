import 'package:flutter/material.dart';
import 'package:earth_nova/shared/design_tokens.dart';

/// A reusable empty-state placeholder with an icon, title, optional
/// subtitle, and optional call-to-action button.
///
/// Usage:
/// ```dart
/// EmptyStateWidget(
///   icon: '🔬',
///   title: 'No species discovered yet',
///   subtitle: 'Start exploring to find wildlife!',
/// )
/// ```
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  /// Icon or short string shown as the visual anchor (large text).
  final String icon;

  /// Primary message — short and direct.
  final String title;

  /// Secondary message — optional context or encouragement.
  final String? subtitle;

  /// Label for the optional action button. Requires [onAction] to be set.
  final String? actionLabel;

  /// Callback invoked when the action button is tapped.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: Spacing.huge, vertical: Spacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Text(
              icon,
              style: TextStyle(fontSize: ComponentSizes.emptyStateIcon),
            ),
            Spacing.gapXl,

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.4,
              ),
            ),

            // Subtitle
            if (subtitle != null) ...[
              Spacing.gapSm,
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],

            // Action button
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: Spacing.xxl + Spacing.xs),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                      horizontal: Spacing.xxl, vertical: Spacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: Radii.borderLg,
                  ),
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
