import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/features/auth/models/auth_state.dart';
import 'package:earth_nova/features/auth/providers/auth_provider.dart';
import 'package:earth_nova/features/auth/widgets/auth_button.dart';
import 'package:earth_nova/shared/design_tokens.dart';

/// OTP code entry screen — shown after a phone number is submitted.
///
/// Displays the phone number the code was sent to, a single 6-digit input
/// field that auto-submits on completion, and a resend button with a 60-second
/// countdown timer.
///
/// Does NOT navigate directly — all routing is driven by [authProvider] state
/// changes observed by main.dart's `_resolveHome()`.
class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _codeController = TextEditingController();
  Timer? _resendTimer;
  int _secondsRemaining = 60;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_onCodeChanged);
    _startResendTimer();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _onCodeChanged() {
    setState(() {});
    // Auto-submit when full code is entered and not already verifying.
    final current = ref.read(authProvider);
    if (_codeController.text.length == 6 &&
        current.status != AuthStatus.otpVerifying) {
      _verify();
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _secondsRemaining = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) return;
    await ref
        .read(authProvider.notifier)
        .verifyOtp(phone: widget.phone, code: code);
  }

  Future<void> _resend() async {
    _codeController.clear();
    await ref.read(authProvider.notifier).sendOtp(widget.phone);
    _startResendTimer();
  }

  void _goBack() {
    ref.read(authProvider.notifier).setState(const AuthState.unauthenticated());
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isVerifying = authState.status == AuthStatus.otpVerifying;
    final canVerify = !isVerifying && _codeController.text.length == 6;

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xxxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Spacing.xxl),

              // ── Back button ─────────────────────────────────────────────
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: isVerifying ? null : _goBack,
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: colors.onSurface,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: colors.surfaceContainerHigh,
                    padding: const EdgeInsets.all(Spacing.sm),
                    minimumSize: const Size(40, 40),
                  ),
                ),
              ),

              const SizedBox(height: Spacing.huge),

              // ── Heading ─────────────────────────────────────────────────
              Text(
                'Verify your number',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: Spacing.sm),

              Text(
                'Enter the 6-digit code sent to ${widget.phone}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: Spacing.massive),

              // ── OTP input ────────────────────────────────────────────────
              TextFormField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                enabled: !isVerifying,
                textAlign: TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 24,
                  letterSpacing: 8,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: '······',
                  hintStyle: TextStyle(
                    color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                    fontSize: 24,
                    letterSpacing: 8,
                  ),
                  filled: true,
                  fillColor: colors.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.xl),
                    borderSide: BorderSide(color: colors.outline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.xl),
                    borderSide: BorderSide(color: colors.outline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.xl),
                    borderSide: BorderSide(color: colors.primary, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.xl),
                    borderSide: BorderSide(color: colors.error, width: 1.5),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Radii.xl),
                    borderSide: BorderSide(
                      color: colors.outline.withValues(alpha: 0.5),
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: Spacing.lg,
                    vertical: Spacing.xl,
                  ),
                ),
                onFieldSubmitted: (_) {
                  if (canVerify) _verify();
                },
              ),

              // ── Error message ────────────────────────────────────────────
              if (authState.errorMessage != null) ...[
                const SizedBox(height: Spacing.md),
                Text(
                  authState.errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: colors.error),
                ),
              ],

              const SizedBox(height: Spacing.xxl),

              // ── Verify button ────────────────────────────────────────────
              AuthButton(
                label: 'Verify',
                isLoading: isVerifying,
                onPressed: canVerify ? _verify : null,
              ),

              const SizedBox(height: Spacing.lg),
              OutlinedButton(
                onPressed: isVerifying
                    ? null
                    : () => ref
                        .read(authProvider.notifier)
                        .bypassVerification(widget.phone),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: colors.primary),
                  padding: const EdgeInsets.symmetric(
                    vertical: Spacing.md,
                    horizontal: Spacing.lg,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.xl),
                  ),
                ),
                child: Text(
                  'Skip Verification (Beta)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: colors.primary,
                  ),
                ),
              ),

              const SizedBox(height: Spacing.xl),

              // ── Resend row ───────────────────────────────────────────────
              Center(
                child: _secondsRemaining > 0
                    ? Text(
                        'Resend code (${_secondsRemaining}s)',
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.onSurfaceVariant,
                        ),
                      )
                    : TextButton(
                        onPressed: isVerifying ? null : _resend,
                        child: Text(
                          'Resend code',
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
              ),

              const SizedBox(height: Spacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }
}
