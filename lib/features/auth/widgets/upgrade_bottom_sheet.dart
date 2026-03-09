import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/features/auth/models/auth_state.dart';
import 'package:earth_nova/features/auth/providers/auth_provider.dart';
import 'package:earth_nova/shared/design_tokens.dart';

/// Modal bottom sheet for adding a phone number to an account.
///
/// The phone number becomes the cross-platform account identifier, tying
/// together Game Center, Google Play, and web sessions.
///
/// Auto-closes when the user successfully authenticates (transitions
/// to [AuthStatus.authenticated]).
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
  ConsumerState<UpgradeBottomSheet> createState() => _UpgradeBottomSheetState();
}

class _UpgradeBottomSheetState extends ConsumerState<UpgradeBottomSheet> {
  final _phoneController = TextEditingController();

  /// Country code prefix — hardcoded to +1 for now.
  static const _countryCode = '+1';

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onFieldChanged() => setState(() {});

  bool get _canSubmit => _phoneController.text.length >= 10;

  String get _fullPhoneNumber => '$_countryCode${_phoneController.text.trim()}';

  Future<void> _linkPhoneNumber() async {
    if (!_canSubmit) return;
    await ref.read(authProvider.notifier).sendOtp(_fullPhoneNumber);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Auto-close when authentication succeeds.
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
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
                'Add Phone Number',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
              ),
              Spacing.gapSm,
              Text(
                'Keep your progress across all devices',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),

              Spacing.gapXxl,

              // ── Phone number field ──────────────────────────────────────────
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                enabled: !isLoading,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                style: TextStyle(color: colors.onSurface, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  hintText: '5551234567',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    child: Text(
                      _countryCode,
                      style: TextStyle(
                        fontSize: 16,
                        color: colors.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
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
                onSubmitted: (_) => _linkPhoneNumber(),
              ),

              Spacing.gapXl,

              // ── Continue button ─────────────────────────────────────────────
              SizedBox(
                height: ComponentSizes.buttonHeight,
                child: ElevatedButton(
                  onPressed: isLoading || !_canSubmit ? null : _linkPhoneNumber,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    disabledBackgroundColor:
                        colors.primary.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: Radii.borderXl,
                    ),
                  ),
                  child: isLoading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(colors.onPrimary),
                          ),
                        )
                      : const Text(
                          'Continue',
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
}
