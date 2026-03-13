import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/config/supabase_bootstrap.dart';
import 'package:earth_nova/core/services/debug_log_buffer.dart';
import 'package:earth_nova/core/state/player_provider.dart';
import 'package:earth_nova/features/auth/models/auth_state.dart';
import 'package:earth_nova/features/auth/providers/auth_provider.dart';
import 'package:earth_nova/features/auth/screens/loading_screen.dart';
import 'package:earth_nova/features/auth/screens/login_screen.dart';
import 'package:earth_nova/features/auth/screens/otp_verification_screen.dart';
import 'package:earth_nova/features/auth/services/auth_service.dart';
import 'package:earth_nova/features/auth/services/mock_auth_service.dart';
import 'package:earth_nova/features/auth/services/supabase_auth_service.dart';
import 'package:earth_nova/features/navigation/screens/tab_shell.dart';
import 'package:earth_nova/features/onboarding/screens/onboarding_screen.dart';
import 'package:earth_nova/shared/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseBootstrap.initialize();

  // 1. Create the appropriate AuthService based on Supabase availability.
  final AuthService authService =
      SupabaseBootstrap.initialized ? SupabaseAuthService() : MockAuthService();

  // 2. Create the ProviderContainer so we can inject the service and
  //    restore the session before the first frame.
  final container = ProviderContainer();

  // 3. Inject auth service into the provider graph.
  container.read(authServiceProvider.notifier).set(authService);

  // 4. Attempt session restore. AuthNotifier starts at `loading` so
  //    LoadingScreen shows while this runs.
  try {
    debugPrint('[AUTH] restoring session…');
    final hasSession = await authService.restoreSession();
    debugPrint('[AUTH] restoreSession → $hasSession');
    if (hasSession) {
      final user = await authService.getCurrentUser();
      if (user != null) {
        container
            .read(authProvider.notifier)
            .setState(AuthState.authenticated(user));
      } else {
        container
            .read(authProvider.notifier)
            .setState(const AuthState.unauthenticated());
      }
    } else {
      container
          .read(authProvider.notifier)
          .setState(const AuthState.unauthenticated());
    }
  } catch (e) {
    debugPrint('[AUTH] session restore failed: $e');
    container
        .read(authProvider.notifier)
        .setState(const AuthState.unauthenticated());
  }

  // 5. Bridge auth service stream → auth provider for token refresh,
  //    session expiry, and external sign-out events.
  // ignore: cancel_subscriptions, unused_local_variable — lives for app lifetime
  final authStreamSub = authService.authStateChanges.listen((user) {
    if (user != null) {
      container
          .read(authProvider.notifier)
          .setState(AuthState.authenticated(user));
    } else {
      container
          .read(authProvider.notifier)
          .setState(const AuthState.unauthenticated());
    }
  });

  // Global error handlers — catch framework errors and unhandled zone
  // exceptions so the user never sees a raw red/blue crash screen.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    DebugLogBuffer.instance
        .add('[CRASH] FlutterError: ${details.exceptionAsString()}');
  };

  // Replace the default error widget (red screen in debug, grey in release)
  // with a minimal dark container. Individual screens can still use
  // ErrorBoundary for richer fallback UI.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return const ColoredBox(color: Color(0xFF161620));
  };

  // Run inside a Zone that intercepts all print() output (which includes
  // debugPrint and MapLogger) and feeds it to the in-app debug log viewer,
  // AND catches any unhandled async exceptions (Future rejections, Timer
  // callbacks, microtask errors) that would otherwise crash the app.
  runZonedGuarded(
    () => runApp(UncontrolledProviderScope(
      container: container,
      child: const EarthNovaApp(),
    )),
    (Object error, StackTrace stack) {
      DebugLogBuffer.instance.add('[CRASH] Unhandled: $error');
      debugPrint('[CRASH] Unhandled zone error: $error\n$stack');
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        DebugLogBuffer.instance.add(line);
        parent.print(zone, line); // preserve console output
      },
    ),
  );
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
    final widget = switch (authState.status) {
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

    final pageName = switch (authState.status) {
      AuthStatus.loading => 'LoadingScreen',
      AuthStatus.otpSent || AuthStatus.otpVerifying => 'OtpVerificationScreen',
      AuthStatus.authenticated =>
        playerState.hasCompletedOnboarding ? 'TabShell' : 'OnboardingScreen',
      AuthStatus.unauthenticated => 'LoginScreen',
    };
    debugPrint('[NAV] resolveHome → $pageName');

    return widget;
  }
}
