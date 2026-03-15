import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import 'package:earth_nova/core/config/supabase_bootstrap.dart';
import 'package:earth_nova/core/engine/event_sink.dart';
import 'package:earth_nova/core/engine/game_event.dart';
import 'package:earth_nova/core/services/debug_log_buffer.dart';
import 'package:earth_nova/core/services/log_flush_service.dart';
import 'package:earth_nova/core/state/game_coordinator_provider.dart';
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
    // Capture full stack trace — the one-liner above tells us WHAT,
    // the stack tells us WHERE.
    final stack = details.stack;
    if (stack != null) {
      final frames = stack.toString().split('\n').take(15).join('\n');
      DebugLogBuffer.instance.add('[CRASH-STACK]\n$frames');
    }
  };

  // Replace the default error widget (red screen in debug, grey in release)
  // with a recovery-friendly fallback. Shows error summary + back button
  // so the user isn't stranded on a blank screen.
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return _GlobalErrorFallback(details: details);
  };

  // 6. Start remote log flush service (Supabase → app_logs table).
  //    Fire-and-forget every 30s + on app background. Skipped when
  //    Supabase is not configured (offline-only mode).
  LogFlushService? logFlushService;
  if (SupabaseBootstrap.initialized) {
    logFlushService = LogFlushService(Supabase.instance.client);
    logFlushService.start();
    // Flush immediately on crash so logs reach Supabase before the process dies.
    DebugLogBuffer.instance.onCrash = () {
      logFlushService!.flush();
    };
    DebugLogBuffer.instance.onAuthEvent = () {
      logFlushService!.flush();
    };
  }

  // Run inside a Zone that intercepts all print() output (which includes
  // debugPrint and MapLogger) and feeds it to the in-app debug log viewer,
  // AND catches any unhandled async exceptions (Future rejections, Timer
  // callbacks, microtask errors) that would otherwise crash the app.
  runZonedGuarded(
    () => runApp(UncontrolledProviderScope(
      container: container,
      child: _LogFlushObserver(
        logFlushService: logFlushService,
        child: const EarthNovaApp(),
      ),
    )),
    (Object error, StackTrace stack) {
      DebugLogBuffer.instance.add('[CRASH] Unhandled: $error');
      final frames = stack.toString().split('\n').take(15).join('\n');
      DebugLogBuffer.instance.add('[CRASH-STACK]\n$frames');
      debugPrint('[CRASH] Unhandled zone error: $error\n$stack');

      // Emit structured crash event + emergency flush so the last events
      // before the blank screen are captured in app_events.
      EventSink.instance?.add(GameEvent.system('crash', {
        'error': error.toString(),
        'stack_trace': frames,
      }));
      EventSink.instance?.flush();
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        DebugLogBuffer.instance.add(line);
        parent.print(zone, line); // preserve console output
      },
    ),
  );

  // Frame performance monitoring + rendering watchdog.
  var lastFrameTime = DateTime.now();

  SchedulerBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
    lastFrameTime = DateTime.now();
    for (final timing in timings) {
      final buildMs = timing.buildDuration.inMilliseconds;
      final rasterMs = timing.rasterDuration.inMilliseconds;
      final totalMs = buildMs + rasterMs;
      if (totalMs > 16) {
        debugPrint(
            '[FRAME-PERF] slow frame: build=${buildMs}ms raster=${rasterMs}ms total=${totalMs}ms');
        EventSink.instance?.add(GameEvent.performance('long_frame', {
          'build_ms': buildMs,
          'raster_ms': rasterMs,
          'total_ms': totalMs,
        }));
      }
    }
  });

  // Rendering watchdog: if no frames paint for 3+ seconds, the UI is dead
  // but the Dart VM is alive. This detects the "blank screen" condition
  // where rendering stops without a crash or tab kill.
  Timer.periodic(const Duration(seconds: 3), (_) {
    final gap = DateTime.now().difference(lastFrameTime);
    if (gap.inSeconds >= 3) {
      debugPrint('[RENDER-STALL] no frames for ${gap.inSeconds}s');
      EventSink.instance?.add(GameEvent.system('rendering_stalled', {
        'gap_seconds': gap.inSeconds,
      }));
    }
  });
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
    // Eagerly create GameCoordinator so hydration starts immediately on auth.
    // Without this, the provider is only accessed by MapScreen (inside TabShell),
    // which is gated behind isHydrated — causing a deadlock.
    ref.read(gameCoordinatorProvider);

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
      // Wait for profile hydration before routing — prevents flashing
      // OnboardingScreen while loadProfile() hasn't run yet.
      AuthStatus.authenticated when !playerState.isHydrated =>
        const LoadingScreen(key: ValueKey('loading')),
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
      AuthStatus.authenticated when !playerState.isHydrated =>
        'LoadingScreen (hydrating)',
      AuthStatus.authenticated =>
        playerState.hasCompletedOnboarding ? 'TabShell' : 'OnboardingScreen',
      AuthStatus.unauthenticated => 'LoginScreen',
    };
    debugPrint('[NAV] resolveHome → $pageName');

    return widget;
  }
}

/// Invisible widget that observes app lifecycle to flush logs when the app
/// is backgrounded. Wraps the widget tree so it receives lifecycle events.
class _LogFlushObserver extends StatefulWidget {
  const _LogFlushObserver({
    required this.logFlushService,
    required this.child,
  });

  final LogFlushService? logFlushService;
  final Widget child;

  @override
  State<_LogFlushObserver> createState() => _LogFlushObserverState();
}

class _LogFlushObserverState extends State<_LogFlushObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.logFlushService?.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Fire-and-forget — don't await.
      widget.logFlushService?.flush();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Recovery-friendly error widget that replaces the default red/blue crash
/// screen. Shows a brief error summary and a back button so the user isn't
/// stranded. Used by [ErrorWidget.builder] — renders outside the normal
/// widget tree, so it cannot use Theme or any inherited widget.
class _GlobalErrorFallback extends StatelessWidget {
  const _GlobalErrorFallback({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF161620),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                details.exceptionAsString().length > 120
                    ? '${details.exceptionAsString().substring(0, 120)}…'
                    : details.exceptionAsString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9E9EB0),
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Your progress is safe. Tap back or switch tabs.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF7A7A8E),
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
