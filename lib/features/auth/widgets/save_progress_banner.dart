import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/features/auth/providers/upgrade_prompt_provider.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/widgets/frosted_glass_container.dart';

/// Persistent banner that prompts anonymous users to sign in and save their
/// progress once they have crossed the upgrade threshold.
///
/// ## Usage
/// Place inside a [Stack] or above game UI. Pass [onUpgradeTap] to handle the
/// sign-in flow (e.g. show the UpgradeBottomSheet):
///
/// ```dart
/// SaveProgressBanner(
///   onUpgradeTap: () => _showUpgradeSheet(context),
/// )
/// ```
///
/// ## Behaviour
/// - Watches [upgradePromptProvider] for [UpgradePromptState.showBanner].
/// - Renders nothing ([SizedBox.shrink]) when `showBanner` is false.
/// - Tapping either the banner body or the "Sign In" button calls [onUpgradeTap].
/// - Banner is always visible once shown — no dismiss button (the banner
///   disappears when [UpgradePromptState.showBanner] becomes false).
class SaveProgressBanner extends ConsumerWidget {
  const SaveProgressBanner({
    required this.onUpgradeTap,
    super.key,
  });

  /// Called when the user taps the banner or the "Sign In" CTA button.
  final VoidCallback onUpgradeTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showBanner = ref.watch(
      upgradePromptProvider.select((s) => s.showBanner),
    );

    if (!showBanner) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onUpgradeTap,
      behavior: HitTestBehavior.opaque,
      child: FrostedGlassContainer(
        isNotification: true,
        child: Row(
          children: [
            // Cloud upload icon
            Container(
              width: ComponentSizes.notificationIcon,
              height: ComponentSizes.notificationIcon,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: Radii.borderLg,
              ),
              child: Icon(
                Icons.cloud_upload_outlined,
                size: ComponentSizes.notificationIconSize,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            Spacing.gapHMd,

            // Text block
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Save your progress',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: Spacing.xxs),
                  Text(
                    'Sign in to keep your discoveries',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            Spacing.gapHSm,

            // CTA button
            OutlinedButton(
              onPressed: onUpgradeTap,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: Spacing.xs,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: Radii.borderMd,
                ),
              ),
              child: Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
