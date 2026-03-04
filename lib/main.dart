import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fog_of_world/features/auth/models/auth_state.dart';
import 'package:fog_of_world/features/auth/providers/auth_provider.dart';
import 'package:fog_of_world/features/auth/screens/login_screen.dart';
import 'package:fog_of_world/features/map/map_screen.dart';
import 'package:fog_of_world/features/onboarding/providers/onboarding_provider.dart';
import 'package:fog_of_world/features/onboarding/screens/onboarding_screen.dart';
import 'package:fog_of_world/features/sync/services/supabase_bootstrap.dart';
import 'package:fog_of_world/shared/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initializeSupabase(); // Non-blocking — resolves in background.
  runApp(const ProviderScope(child: FogOfWorldApp()));
}

/// Root widget — routes through onboarding on first launch, then to
/// [MapScreen] when the user is authenticated or in guest mode, and to
/// [LoginScreen] when there is no session.
///
/// Routing order:
/// 1. `onboardingProvider == null` → neutral splash (no flash on cold start)
/// 2. `onboardingProvider == false` → [OnboardingScreen] (first launch only)
/// 3. auth loading / authenticated / guest → [MapScreen]
/// 4. unauthenticated → [LoginScreen]
class FogOfWorldApp extends ConsumerWidget {
  const FogOfWorldApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarded = ref.watch(onboardingProvider);
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'Fog of World',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: _resolveHome(onboarded, authState),
    );
  }

  Widget _resolveHome(bool? onboarded, AuthState authState) {
    // Still reading SharedPreferences — show blank scaffold to avoid flicker.
    if (onboarded == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1B2A), // AppTheme._darkSurface
      );
    }

    // First launch — onboarding not yet completed.
    if (!onboarded) {
      return const OnboardingScreen();
    }

    // Onboarding complete — use existing auth routing.
    return switch (authState.status) {
      AuthStatus.authenticated || AuthStatus.guest => const MapScreen(),
      AuthStatus.loading => const _LoadingSplash(),
      _ => const LoginScreen(),
    };
  }
}

/// Lightweight splash shown while Supabase initializes and auth resolves.
///
/// Replaces the previous behavior of routing [AuthStatus.loading] to
/// [MapScreen], which triggered expensive Voronoi cell computation and
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
