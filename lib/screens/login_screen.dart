import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/models/auth_state.dart';
import 'package:earth_nova/providers/auth_provider.dart';
import 'package:earth_nova/shared/app_theme.dart';
import 'package:earth_nova/shared/constants.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/widgets/loading_dots.dart';

/// Login screen — phone number input + Continue button.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onPhoneChanged() {
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
  }

  bool get _isValid {
    final digits = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
    return digits.length >= 10;
  }

  Future<void> _onContinue() async {
    if (!_isValid) return;
    final phone = '+1${_phoneController.text.replaceAll(RegExp(r'[^\d]'), '')}';
    await ref.read(authProvider.notifier).signInWithPhone(phone);
    final state = ref.read(authProvider);
    if (state.status == AuthStatus.error) {
      setState(() => _errorText = state.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Brand
                const Text(
                  AppConstants.appName,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: Spacing.xs),
                Text(
                  'Explore. Discover. Reveal.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Spacing.huge),

                // Phone input
                TextField(
                  controller: _phoneController,
                  enabled: !isLoading,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  decoration: InputDecoration(
                    prefixText: '+1 ',
                    prefixStyle: TextStyle(
                      color: AppTheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                    hintText: '555 123 4567',
                    counterText: '',
                    errorText: _errorText,
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: Spacing.lg),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isValid && !isLoading ? _onContinue : null,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
