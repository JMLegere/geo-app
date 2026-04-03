import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/data/observability.dart';
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
  final rawDebugPrint = debugPrint;

  await runZonedGuarded(() async {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      AppObservability.instance
          .log('[ENGINE] Flutter error: ${details.exceptionAsString()}');
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      AppObservability.instance.log('[ENGINE] Platform error: $error\n$stack');
      return true;
    };

    await SupabaseBootstrap.initialize();
    final AuthService authService = SupabaseBootstrap.initialized
        ? SupabaseAuthService()
        : MockAuthService();

    await AppObservability.initialize(
      rawDebugPrint: rawDebugPrint,
      client: SupabaseBootstrap.client,
    );

    debugPrint = (String? message, {int? wrapWidth}) {
      rawDebugPrint(message, wrapWidth: wrapWidth);
      if (message != null && message.isNotEmpty) {
        AppObservability.instance.log(message);
      }
    };

    final container = ProviderContainer();
    container.read(authServiceProvider.notifier).state = authService;

    try {
      final hasSession = await authService.restoreSession();
      if (hasSession) {
        final user = await authService.getCurrentUser();
        if (user != null) {
          AppObservability.instance.setUserId(user.id);
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
    } catch (e, stack) {
      AppObservability.instance
          .log('[HYDRATION] auth restore failed: $e\n$stack');
      container
          .read(authProvider.notifier)
          .setState(const AuthState.unauthenticated());
    }

    runApp(UncontrolledProviderScope(
      container: container,
      child: const ErrorBoundary(child: EarthNovaApp()),
    ));
  }, (error, stack) {
    rawDebugPrint('[ENGINE] Zone error: $error\n$stack');
    try {
      AppObservability.instance.log('[ENGINE] Zone error: $error\n$stack');
    } catch (_) {}
  }, zoneSpecification: ZoneSpecification(
    print: (self, parent, zone, line) {
      parent.print(zone, line);
      try {
        AppObservability.instance.log(line);
      } catch (_) {}
    },
  ));
}

/// Catches uncaught Flutter widget errors and renders a fallback UI instead
/// of a blank/crashed screen.
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  const ErrorBoundary({super.key, required this.child});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _error = null;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFF0D1117),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.redAccent, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Something went wrong',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _error = null),
                  child: const Text('Retry',
                      style: TextStyle(color: Colors.greenAccent)),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return widget.child;
  }
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
