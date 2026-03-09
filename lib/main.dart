import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/features/auth/models/auth_state.dart';
import 'package:earth_nova/features/auth/providers/auth_provider.dart';
import 'package:earth_nova/features/auth/screens/loading_screen.dart';
import 'package:earth_nova/features/auth/screens/login_screen.dart';
import 'package:earth_nova/features/auth/screens/otp_verification_screen.dart';
import 'package:earth_nova/features/navigation/screens/tab_shell.dart';
import 'package:earth_nova/features/onboarding/screens/onboarding_screen.dart';
import 'package:earth_nova/core/config/supabase_bootstrap.dart';
import 'package:earth_nova/core/state/player_provider.dart';
import 'package:earth_nova/shared/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseBootstrap.initialize();
  runApp(const ProviderScope(child: EarthNovaApp()));
}

/// Root widget — routes declaratively through the full auth flow based on
/// [AuthStatus]. Routing order:
///
/// 1. [AuthStatus.loading]    → [LoadingScreen] (auth/hydration in progress)
/// 2. [AuthStatus.otpSent]    → [OtpVerificationScreen] (OTP input)
/// 3. [AuthStatus.otpVerifying] → [OtpVerificationScreen] (same screen, verifying)
/// 4. [AuthStatus.authenticated] + onboarding incomplete → [OnboardingScreen]
/// 5. [AuthStatus.authenticated] + onboarding complete  → [TabShell]
/// 6. [AuthStatus.unauthenticated] → [LoginScreen]
///
/// Wrapped in [AnimatedSwitcher] for smooth 300ms cross-fades between states.
/// otpSent and otpVerifying share the same [ValueKey] so the OTP screen does
/// not rebuild (and lose input state) when verification starts.
class EarthNovaApp extends ConsumerWidget {
  const EarthNovaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final playerState = ref.watch(playerProvider);

    return MaterialApp(
      title: 'EarthNova',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _resolveHome(authState, playerState),
      ),
    );
  }

  Widget _resolveHome(AuthState authState, PlayerState playerState) {
    return switch (authState.status) {
      AuthStatus.loading => const LoadingScreen(
          key: ValueKey('loading'),
        ),
      AuthStatus.otpSent || AuthStatus.otpVerifying => OtpVerificationScreen(
          key: const ValueKey('otp'),
          phone: authState.phone!,
        ),
      AuthStatus.authenticated => playerState.hasCompletedOnboarding
          ? const TabShell(key: ValueKey('tabshell'))
          : const OnboardingScreen(key: ValueKey('onboarding')),
      AuthStatus.unauthenticated => const LoginScreen(
          key: ValueKey('login'),
        ),
    };
  }
}
