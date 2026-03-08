import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/features/auth/models/auth_state.dart';
import 'package:earth_nova/features/auth/providers/auth_provider.dart';
import 'package:earth_nova/features/auth/widgets/auth_button.dart';

/// Sign-up screen — pushed on top of the login screen.
///
/// Pops itself when auth succeeds so `EarthNovaApp`'s home switch can reveal
/// the map screen cleanly.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _onFieldChanged() => setState(() {});

  bool _canSubmit(bool isLoading) =>
      !isLoading &&
      _emailController.text.isNotEmpty &&
      _passwordController.text.isNotEmpty;

  Future<void> _signUp() async {
    await ref.read(authProvider.notifier).signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _displayNameController.text.trim().isNotEmpty
              ? _displayNameController.text.trim()
              : null,
        );
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

    // Pop back to login when auth succeeds; main.dart then shows MapScreen.
    ref.listen<AuthState>(authProvider, (_, next) {
      if (next.isLoggedIn && mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: colors.primary),
          onPressed:
              isLoading ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),

                // ── Title ─────────────────────────────────────────────────────
                Text(
                  'Sign Up',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Start your exploration journey',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 40),

                // ── Display name (optional) ───────────────────────────────────
                _buildTextField(
                  controller: _displayNameController,
                  label: 'Display Name (optional)',
                  hint: 'Explorer',
                  enabled: !isLoading,
                ),
                const SizedBox(height: 16),

                // ── Email ─────────────────────────────────────────────────────
                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'your@email.com',
                  keyboardType: TextInputType.emailAddress,
                  enabled: !isLoading,
                ),
                const SizedBox(height: 16),

                // ── Password ──────────────────────────────────────────────────
                _buildTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: '••••••••',
                  obscureText: true,
                  enabled: !isLoading,
                ),
                const SizedBox(height: 28),

                // ── Create account button ─────────────────────────────────────
                AuthButton(
                  label: 'Create Account',
                  isLoading: isLoading,
                  onPressed: _canSubmit(isLoading) ? _signUp : null,
                ),

                // ── Error message ─────────────────────────────────────────────
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

                // ── Back to sign in ───────────────────────────────────────────
                TextButton(
                  onPressed:
                      isLoading ? null : () => Navigator.of(context).pop(),
                  child: Text(
                    'Already have an account? Sign In',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colors.primary,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    final colors = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      enabled: enabled,
      style: TextStyle(color: colors.onSurface),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
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
    );
  }
}
