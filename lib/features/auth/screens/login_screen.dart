import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/features/auth/models/auth_state.dart';
import 'package:earth_nova/features/auth/providers/auth_provider.dart';
import 'package:earth_nova/features/auth/utils/phone_validation.dart';
import 'package:earth_nova/features/auth/widgets/auth_button.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/game_icons.dart';

/// Login screen — shown when auth state is [AuthStatus.unauthenticated].
///
/// Phone-only flow: enter 10-digit US number, tap "Continue". No OTP — the
/// phone number is the account identity. New users are created on first use,
/// returning users are signed in automatically.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();

  /// Inline validation error shown before hitting the provider.
  String? _localError;

  /// Country code prefix — hardcoded to +1 for now.
  static const _countryCode = '+1';

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onFieldChanged);
    _phoneController.dispose();
    super.dispose();
  }

  void _onFieldChanged() => setState(() {
        // Clear local validation error as the user types.
        if (_localError != null) _localError = null;
      });

  String get _fullPhone => '$_countryCode${_phoneController.text.trim()}';

  bool _isLoading(AuthStatus status) => status == AuthStatus.loading;

  Future<void> _signIn() async {
    final phone = _fullPhone;

    if (!isValidE164(phone)) {
      setState(() => _localError = 'Enter a valid phone number');
      return;
    }

    setState(() => _localError = null);
    await ref.read(authProvider.notifier).signInWithPhone(phone);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = _isLoading(authState.status);
    final canSubmit = !isLoading && _phoneController.text.trim().length >= 10;

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Visible error: local validation wins; provider error shown otherwise.
    final errorText = _localError ?? authState.errorMessage;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: Spacing.xxxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: Spacing.massive),

              // ── Brand ───────────────────────────────────────────────────────
              Text(
                GameIcons.globe,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: ComponentSizes.emptyStateIcon,
                  height: 1,
                ),
              ),
              Spacing.gapLg,
              Text(
                'EarthNova',
                textAlign: TextAlign.center,
                style: theme.textTheme.displaySmall?.copyWith(
                  color: colors.onSurface,
                ),
              ),
              Spacing.gapXs,
              Text(
                'Explore. Discover. Reveal.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),

              SizedBox(height: Spacing.massive),

              // ── Phone input ─────────────────────────────────────────────────
              _PhoneField(
                controller: _phoneController,
                enabled: !isLoading,
                countryCode: _countryCode,
                onSubmitted: canSubmit ? (_) => _signIn() : null,
              ),

              SizedBox(height: Spacing.xxl),

              // ── Submit button ───────────────────────────────────────────────
              AuthButton(
                label: 'Continue',
                isLoading: isLoading,
                onPressed: canSubmit ? _signIn : null,
              ),

              // ── Error message ───────────────────────────────────────────────
              if (errorText != null) ...[
                Spacing.gapMd,
                Text(
                  errorText,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.error,
                  ),
                ),
              ],

              SizedBox(height: Spacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Phone field ─────────────────────────────────────────────────────────────

/// Stateless phone-number text field with a fixed country-code prefix.
class _PhoneField extends StatelessWidget {
  const _PhoneField({
    required this.controller,
    required this.countryCode,
    this.enabled = true,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String countryCode;
  final bool enabled;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(Radii.xl);

    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      enabled: enabled,
      textInputAction: TextInputAction.done,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      style: TextStyle(color: colors.onSurface, fontSize: 16),
      decoration: InputDecoration(
        hintText: '5551234567',
        hintStyle: TextStyle(color: colors.onSurfaceVariant),
        prefixIcon: Padding(
          padding: EdgeInsets.only(
            left: Spacing.lg,
            right: Spacing.sm,
          ),
          child: Text(
            countryCode,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: colors.onSurface,
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: colors.surfaceContainerHigh,
        contentPadding: EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: colors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: colors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(
            color: colors.outline.withValues(alpha: 0.4),
          ),
        ),
      ),
      onSubmitted: onSubmitted,
    );
  }
}
