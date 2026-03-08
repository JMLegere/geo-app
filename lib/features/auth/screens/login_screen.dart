import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fog_of_world/features/auth/models/auth_state.dart';
import 'package:fog_of_world/features/auth/providers/auth_provider.dart';
import 'package:fog_of_world/features/auth/widgets/auth_button.dart';

/// Login screen — shown when auth state is [AuthStatus.unauthenticated].
///
/// Provides a unified phone-number flow: new numbers create an account,
/// existing numbers sign in. No separate signup screen.
///
/// Also offers "Continue as Guest" for anonymous play.
///
/// Navigation: sign-in success is handled by the auth-state switch in
/// `FogOfWorldApp` which replaces this screen with the map.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

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

  bool _canSubmit(bool isLoading) =>
      !isLoading && _phoneController.text.length >= 10;

  String get _fullPhoneNumber => '$_countryCode${_phoneController.text.trim()}';

  Future<void> _signIn() async {
    if (!_canSubmit(false)) return;
    await ref
        .read(authProvider.notifier)
        .signInWithPhone(phoneNumber: _fullPhoneNumber);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 80),

                Icon(
                  Icons.explore_rounded,
                  size: 64,
                  color: colors.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  'Fog of World',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Explore. Discover. Reveal.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 56),

                // ── Phone number field ──────────────────────────────────────
                _buildPhoneField(
                  controller: _phoneController,
                  enabled: !isLoading,
                ),
                const SizedBox(height: 28),

                AuthButton(
                  label: 'Continue',
                  isLoading: isLoading,
                  onPressed: _canSubmit(isLoading) ? _signIn : null,
                ),

                if (authState.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    authState.errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.error,
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                Divider(color: colors.outlineVariant),
                const SizedBox(height: 24),

                TextButton(
                  onPressed: isLoading
                      ? null
                      : () {
                          ref.read(authProvider.notifier).continueAsGuest();
                        },
                  child: Text(
                    'Continue as Guest',
                    style: TextStyle(
                      fontSize: 15,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Phone number input with fixed +1 prefix.
  Widget _buildPhoneField({
    required TextEditingController controller,
    bool enabled = true,
  }) {
    final colors = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      enabled: enabled,
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
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: colors.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      onFieldSubmitted: (_) => _signIn(),
    );
  }
}
