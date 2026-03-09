import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/features/auth/models/auth_state.dart';
import 'package:earth_nova/features/auth/providers/auth_provider.dart';
import 'package:earth_nova/features/auth/screens/login_screen.dart';
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

/// Root widget — routes through onboarding on first launch, then to
/// [TabShell] when the user is authenticated, and to [LoginScreen] when
/// there is no session.
///
/// Auth is resolved BEFORE this widget is created (via [SupabaseBootstrap]
/// in [main]). Routing order:
/// 1. [AuthStatus.loading] → [_LoadingSplash]
/// 2. [AuthStatus.authenticated] + onboarding incomplete → [OnboardingScreen]
/// 3. [AuthStatus.authenticated] + onboarding complete → [TabShell]
/// 4. Any other status → [LoginScreen]
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
      home: _resolveHome(authState, playerState),
    );
  }

  Widget _resolveHome(AuthState authState, PlayerState playerState) {
    return switch (authState.status) {
      AuthStatus.loading => const _LoadingSplash(),
      AuthStatus.authenticated => playerState.hasCompletedOnboarding
          ? const TabShell()
          : const OnboardingScreen(),
      _ => const LoginScreen(), // unauthenticated, otpSent, otpVerifying
    };
  }
}

/// Lightweight splash shown while auth resolves.
///
/// Replaces the previous behavior of routing [AuthStatus.loading] directly to
/// the main screen, which triggered expensive Voronoi cell computation and
/// location service startup before auth was ready — freezing the UI on web.
class _LoadingSplash extends StatelessWidget {
  const _LoadingSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D1B2A), // AppTheme._darkSurface
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🌍', style: TextStyle(fontSize: 48)),
            SizedBox(height: 20),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFF4FC3F7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
