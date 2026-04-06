import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/shared/constants.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';
import 'package:earth_nova/shared/theme/design_tokens.dart';

class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (raw.isEmpty) return newValue.copyWith(text: '');

    final digits = raw.length > 10 ? raw.substring(0, 10) : raw;

    final buf = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i == 0) buf.write('(');
      if (i == 3) buf.write(') ');
      if (i == 6) buf.write('-');
      buf.write(digits[i]);
    }

    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

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
    setState(() {
      if (_errorText != null) _errorText = null;
    });
  }

  bool get _isValid {
    final digits = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
    return digits.length >= 10;
  }

  Future<void> _onContinue() async {
    if (!_isValid) return;
    final phone = '+1${_phoneController.text.replaceAll(RegExp(r'[^\d]'), '')}';
    await ref.read(authProvider.notifier).signInWithPhone(phone);
    final authState = ref.read(authProvider);
    if (authState.status == AuthStatus.error) {
      setState(() => _errorText = authState.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                TextField(
                  controller: _phoneController,
                  enabled: !isLoading,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [_PhoneInputFormatter()],
                  decoration: InputDecoration(
                    prefixText: '+1 ',
                    prefixStyle: TextStyle(
                      color: AppTheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                    hintText: '(555) 123-4567',
                    counterText: '',
                    errorText: _errorText,
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: Spacing.lg),
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
