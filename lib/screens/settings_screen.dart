import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/models/user_profile.dart';
import 'package:earth_nova/providers/auth_provider.dart';
import 'package:earth_nova/shared/constants.dart';
import 'package:earth_nova/shared/design_tokens.dart';

/// Account settings screen — user ID, sign out, version.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  String _resolveSubtitle(UserProfile? user) {
    if (user == null) return 'Loading…';
    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      return user.phoneNumber!;
    }
    if (user.email.isNotEmpty) return user.email;
    return 'No contact info';
  }

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await _showSignOutDialog(context);
    if (confirmed != true) return;
    if (!context.mounted) return;
    await ref.read(authProvider.notifier).signOut();
  }

  Future<bool?> _showSignOutDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final colors = Theme.of(context).colorScheme;
    final user = authState.user;
    final displayName = (user?.displayName?.isNotEmpty == true)
        ? user!.displayName!
        : 'Explorer';
    final subtitle = _resolveSubtitle(user);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.xl,
        ),
        children: [
          // Profile card
          _SectionCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colors.primaryContainer,
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                    style: TextStyle(
                        color: colors.onPrimaryContainer, fontSize: 20),
                  ),
                ),
                SizedBox(width: Spacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                      SizedBox(height: Spacing.xs),
                      Text(
                        subtitle,
                        style: TextStyle(
                            fontSize: 13, color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: Spacing.xxl),

          // Sign out
          _SectionCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Sign Out',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colors.error),
              ),
              trailing: Icon(Icons.logout, color: colors.error, size: 20),
              onTap: () => _handleSignOut(context, ref),
            ),
          ),

          SizedBox(height: Spacing.xxl),

          // Version
          _SectionCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Version',
                style: TextStyle(fontSize: 15, color: colors.onSurface),
              ),
              trailing: Text(
                kBuildTimestamp,
                style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: Spacing.paddingCard,
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: Radii.borderXxl,
        boxShadow: Shadows.medium,
      ),
      child: child,
    );
  }
}
