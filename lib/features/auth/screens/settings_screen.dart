import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/features/auth/models/user_profile.dart';
import 'package:earth_nova/features/auth/providers/auth_provider.dart';
import 'package:earth_nova/features/sync/providers/sync_provider.dart';
import 'package:earth_nova/shared/constants.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/widgets/identicon_avatar.dart';

/// Account settings screen.
///
/// Displays:
/// - Profile section: avatar, display name, phone/email.
/// - Sign-out with simple confirmation dialog.
/// - App version info.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Resolves the subtitle text under the display name.
  ///
  /// Priority: phone number → email → fallback.
  String _resolveSubtitle(UserProfile? user) {
    if (user == null) return 'Loading…';
    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      return user.phoneNumber!;
    }
    if (user.email.isNotEmpty) return user.email;
    return 'No contact info';
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  // ---------------------------------------------------------------------------
  // Sign-out
  // ---------------------------------------------------------------------------

  Future<void> _handleSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await _showSignOutDialog(context);
    if (confirmed != true) return;
    // Guard against widget disposal during async gap.
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final colors = Theme.of(context).colorScheme;

    final user = authState.user;

    final displayName = (user?.displayName?.isNotEmpty == true)
        ? user!.displayName!
        : 'Explorer';
    // Show phone number for phone-auth users, email for email users.
    final subtitle = _resolveSubtitle(user);
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: colors.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.xl,
        ),
        children: [
          // ── Profile Card ────────────────────────────────────────────────────
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Identicon avatar — matches the shell-level icon.
                    IdenticonAvatar(
                      seed: user?.id ?? 'anonymous',
                      size: 56,
                    ),
                    Spacing.gapHLg,
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
                          Spacing.gapXs,
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Spacing.gapXxl,

          // ── Cloud Sync ────────────────────────────────────────────────────────
          _SectionCard(
            child: Consumer(
              builder: (context, ref, _) {
                final syncStatus = ref.watch(syncProvider);
                final isSyncing = syncStatus.type.name == 'syncing';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    isSyncing ? 'Syncing...' : 'Sync Now',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colors.primary,
                    ),
                  ),
                  subtitle: syncStatus.lastSyncedAt != null
                      ? Text(
                          'Last synced: ${_formatTime(syncStatus.lastSyncedAt!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        )
                      : null,
                  trailing: isSyncing
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.primary,
                          ),
                        )
                      : Icon(Icons.cloud_upload,
                          color: colors.primary, size: 20),
                  onTap: isSyncing
                      ? null
                      : () => ref.read(syncProvider.notifier).syncNow(),
                );
              },
            ),
          ),

          Spacing.gapXxl,

          // ── Sign Out ────────────────────────────────────────────────────────
          _SectionCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: colors.error,
                ),
              ),
              trailing: Icon(Icons.logout, color: colors.error, size: 20),
              onTap: () => _handleSignOut(context, ref),
            ),
          ),

          Spacing.gapXxl,

          // ── App Info ────────────────────────────────────────────────────────
          _SectionCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Version',
                style: TextStyle(
                  fontSize: 15,
                  color: colors.onSurface,
                ),
              ),
              trailing: Text(
                kBuildTimestamp,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/// A lightly styled card container for settings sections.
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
