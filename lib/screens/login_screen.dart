import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/models/auth_state.dart';
import 'package:earth_nova/providers/auth_provider.dart';
import 'package:earth_nova/shared/design_tokens.dart';

/// Phone-only login screen.
///
/// Calls signInWithPhone — derives credentials from phone, no OTP from user.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  String? _localError;

  static const _countryCode = '+1';
  static final _e164Regex = RegExp(r'^\+[1-9]\d{0,14}$');

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

  void _onFieldChanged() {
    if (_localError != null) setState(() => _localError = null);
  }

  String get _fullPhone => '$_countryCode${_phoneController.text.trim()}';

  bool get _isValidPhone => _e164Regex.hasMatch(_fullPhone);

  Future<void> _signIn() async {
    if (!_isValidPhone) {
      setState(() => _localError = 'Enter a valid phone number');
      return;
    }
    setState(() => _localError = null);
    await ref.read(authProvider.notifier).signInWithPhone(_fullPhone);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;
    final canSubmit = !isLoading && _phoneController.text.trim().length >= 10;
    final errorText = _localError ?? authState.errorMessage;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: Spacing.xxxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: Spacing.massive),

              // Brand
              const Icon(Icons.explore, size: 52, color: Colors.green),
              Spacing.gapLg,
              Text(
                'EarthNova',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: colors.onSurface,
                    ),
              ),
              Spacing.gapXs,
              Text(
                'Explore. Discover. Reveal.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),

              SizedBox(height: Spacing.massive),

              // Phone input
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                enabled: !isLoading,
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
                    padding: EdgeInsets.symmetric(horizontal: Spacing.lg),
                    child: Text(
                      _countryCode,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                  filled: true,
                  fillColor: colors.surfaceContainerHigh,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: Spacing.lg,
                    vertical: Spacing.lg,
                  ),
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
                ),
                onSubmitted: canSubmit ? (_) => _signIn() : null,
              ),

              SizedBox(height: Spacing.xxl),

              // Submit
              SizedBox(
                height: ComponentSizes.buttonHeight,
                child: ElevatedButton(
                  onPressed: canSubmit ? _signIn : null,
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),
              ),

              // Error
              if (errorText != null) ...[
                Spacing.gapMd,
                Text(
                  errorText,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.error),
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
