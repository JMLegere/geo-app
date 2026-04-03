import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/data/sync/supabase_client.dart';
import 'package:earth_nova/data/sync/auth_service.dart';
import 'package:earth_nova/data/sync/mock_auth_service.dart';
import 'package:earth_nova/data/sync/supabase_auth.dart';
import 'package:earth_nova/models/auth_state.dart';
import 'package:earth_nova/providers/auth_provider.dart';
import 'package:earth_nova/screens/login_screen.dart';
import 'package:earth_nova/screens/loading_screen.dart';
import 'package:earth_nova/widgets/tab_shell.dart';
import 'package:earth_nova/shared/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseBootstrap.initialize();
  final AuthService authService =
      SupabaseBootstrap.initialized ? SupabaseAuthService() : MockAuthService();

  final container = ProviderContainer();

  // Inject auth service into the provider graph.
  container.read(authServiceProvider.notifier).state = authService;

  // Restore session. AuthNotifier starts at `loading` so LoadingScreen shows.
  try {
    final hasSession = await authService.restoreSession();
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
    container
        .read(authProvider.notifier)
        .setState(const AuthState.unauthenticated());
  }

  // Bridge auth service stream → auth provider for token refresh / sign-out.
  // ignore: cancel_subscriptions — lives for app lifetime
  authService.authStateChanges.listen((user) {
    if (user != null) {
      container
          .read(authProvider.notifier)
          .setState(AuthState.authenticated(user));
    } else {
      if (container.read(authProvider).status == AuthStatus.authenticated) {
        container
            .read(authProvider.notifier)
            .setState(const AuthState.unauthenticated());
      }
    }
  });

  runApp(UncontrolledProviderScope(
    container: container,
    child: const EarthNovaApp(),
  ));
}

class EarthNovaApp extends ConsumerWidget {
  const EarthNovaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    return MaterialApp(
      title: 'EarthNova',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      home: auth.when(
        loading: () => const LoadingScreen(),
        unauthenticated: () => const LoginScreen(),
        authenticated: (_) => const TabShell(),
        otpSent: (_) => const LoginScreen(),
      ),
    );
  }
}
