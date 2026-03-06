import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fog_of_world/features/auth/models/auth_state.dart';
import 'package:fog_of_world/features/auth/providers/auth_provider.dart';
import 'package:fog_of_world/shared/design_tokens.dart';

/// Modal bottom sheet for upgrading an anonymous account to a permanent account.
///
/// Presents email/password form and OAuth options (Google, Apple).
/// Auto-closes when the user successfully upgrades (transitions to
/// authenticated with `isAnonymous: false`).
///
/// ## Usage
/// ```dart
/// await UpgradeBottomSheet.show(context);
/// ```
class UpgradeBottomSheet extends ConsumerStatefulWidget {
  const UpgradeBottomSheet({super.key});

  /// Shows the upgrade bottom sheet as a modal.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const UpgradeBottomSheet(),
    );
  }

  @override
  ConsumerState<UpgradeBottomSheet> createState() =>
      _UpgradeBottomSheetState();
}

class _UpgradeBottomSheetState extends ConsumerState<UpgradeBottomSheet> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _upgradeWithEmail() async {
    final displayName = _displayNameController.text.trim();
    await ref.read(authProvider.notifier).upgradeWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: displayName.isEmpty ? null : displayName,
        );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Auto-close when upgrade succeeds (anonymous → permanent account).
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated && !next.isAnonymous) {
        if (mounted) Navigator.pop(context);
      }
    });

    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Radii.xxxl),
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: Spacing.xxxl,
            right: Spacing.xxxl,
            bottom: MediaQuery.of(context).viewInsets.bottom + Spacing.xxxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Handle bar ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.onSurface.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),

              Spacing.gapXl,

              // ── Header ──────────────────────────────────────────────────────
              Text(
                'Save Your Progress',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
              ),
              Spacing.gapSm,
              Text(
                'Keep your discoveries safe',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),

              Spacing.gapXxl,

              // ── Email field ─────────────────────────────────────────────────
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'your@email.com',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                enabled: !isLoading,
                colors: colors,
              ),
              Spacing.gapMd,

              // ── Password field ──────────────────────────────────────────────
              _buildTextField(
                controller: _passwordController,
                label: 'Password',
                hint: '••••••••',
                prefixIcon: Icons.lock_outlined,
                obscureText: true,
                enabled: !isLoading,
                colors: colors,
              ),
              Spacing.gapMd,

              // ── Display name field (optional) ───────────────────────────────
              _buildTextField(
                controller: _displayNameController,
                label: 'Display Name (optional)',
                hint: 'Your name',
                prefixIcon: Icons.person_outlined,
                enabled: !isLoading,
                colors: colors,
              ),

              Spacing.gapXl,

              // ── Create Account button ───────────────────────────────────────
              SizedBox(
                height: ComponentSizes.buttonHeight,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _upgradeWithEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: Radii.borderXl,
                    ),
                  ),
                  child: const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // ── Error message ───────────────────────────────────────────────
              if (authState.errorMessage != null) ...[
                Spacing.gapMd,
                Text(
                  authState.errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.error,
                  ),
                ),
              ],

              Spacing.gapXl,

              // ── Divider with "or" ───────────────────────────────────────────
              Row(
                children: [
                  Expanded(child: Divider(color: colors.outlineVariant)),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Spacing.md,
                    ),
                    child: Text(
                      'or',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                  ),
                  Expanded(child: Divider(color: colors.outlineVariant)),
                ],
              ),

              Spacing.gapXl,

              // ── Google button ───────────────────────────────────────────────
              SizedBox(
                height: ComponentSizes.buttonHeight,
                child: OutlinedButton(
                  onPressed: isLoading
                      ? null
                      : () => ref
                          .read(authProvider.notifier)
                          .linkOAuth(provider: 'google'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: Radii.borderXl,
                    ),
                  ),
                  child: const Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Spacing.gapMd,

              // ── Apple button ────────────────────────────────────────────────
              SizedBox(
                height: ComponentSizes.buttonHeight,
                child: OutlinedButton(
                  onPressed: isLoading
                      ? null
                      : () => ref
                          .read(authProvider.notifier)
                          .linkOAuth(provider: 'apple'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: Radii.borderXl,
                    ),
                  ),
                  child: const Text(
                    'Continue with Apple',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              Spacing.gapSm,

              // ── Not now ─────────────────────────────────────────────────────
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Not now',
                  style: TextStyle(
                    fontSize: 15,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),

              Spacing.gapSm,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    required ColorScheme colors,
    bool obscureText = false,
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      enabled: enabled,
      style: TextStyle(color: colors.onSurface),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(prefixIcon, color: colors.onSurfaceVariant),
        filled: true,
        fillColor: colors.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: Radii.borderXl,
          borderSide: BorderSide(color: colors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: Radii.borderXl,
          borderSide: BorderSide(color: colors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Radii.borderXl,
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.lg,
        ),
      ),
    );
  }
}
