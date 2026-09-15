import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/ui/design_system.dart';
import 'package:earth_nova/shared/observability/widgets/observable_interaction.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
  bool _isSignInError = false;

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
      _isSignInError = false;
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
      setState(() {
        _errorText = authState.errorMessage;
        _isSignInError = true;
      });
    }
  }

  void _submitOrShowValidation(VoidCallback? submit) {
    if (!_isValid) {
      if (_phoneController.text.isNotEmpty) {
        setState(() {
          _errorText = 'Enter at least 10 digits.';
          _isSignInError = false;
        });
      }
      return;
    }
    submit?.call();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;
    final obs = ref.watch(appObservabilityProvider);
    final canContinue = _isValid && !isLoading;
    final errorMessage = _errorText == null
        ? null
        : _isSignInError
        ? 'Sign-in failed. $_errorText'
        : _errorText;
    void logger({
      required String event,
      required String category,
      Map<String, dynamic>? data,
    }) {
      obs.log(event, category, data: data);
    }

    final submit = ObservableInteraction.wrapAsyncCallback(
      logger: logger,
      screenName: 'login_screen',
      widgetName: 'continue_button',
      actionType: 'submit',
      payload: const {'flow': 'auth.sign_in'},
      telemetryOnlyReason:
          'Auth submit is account access outside the SuperBDD gameplay action catalog.',
      callback: _onContinue,
    );

    return ObservableScreen(
      screenName: 'login_screen',
      observability: obs,
      builder: (_) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              key: const Key('login_scroll'),
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: AppCard(
                  title: 'Welcome',
                  description: 'Enter your phone number to continue.',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: ShadInput(
                          key: const Key('phone_input'),
                          controller: _phoneController,
                          enabled: !isLoading,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [_PhoneInputFormatter()],
                          leading: const Text('+1'),
                          placeholder: const Text('(555) 123-4567'),
                          onSubmitted: (_) => _submitOrShowValidation(
                            canContinue ? submit : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 32),
                        child: errorMessage == null
                            ? const SizedBox.shrink()
                            : Semantics(
                                label: 'error: $errorMessage',
                                liveRegion: true,
                                child: ExcludeSemantics(
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        size: 20,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          errorMessage,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.error,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                      AppButton(
                        key: const Key('continue_button'),
                        label: 'Continue',
                        expand: true,
                        isLoading: isLoading,
                        onPressed: canContinue ? submit : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
