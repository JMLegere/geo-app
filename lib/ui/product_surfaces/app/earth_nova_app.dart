import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:earth_nova/app/readiness/app_readiness.dart';
import 'package:earth_nova/core/domain/entities/auth_state.dart' as app_auth;
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/home/presentation/providers/home_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_level_provider.dart';
import 'package:earth_nova/shared/debug/debug_level_param.dart';
import 'package:earth_nova/shared/debug/debug_mode_provider.dart';
import 'package:earth_nova/shared/observability/navigation/app_navigation_observer.dart';
import 'package:earth_nova/shared/observability/navigation/auth_home_navigation_transition_tracker.dart';
import 'package:earth_nova/ui/design_system.dart';
import 'package:earth_nova/ui/product_surfaces/app/app_readiness_gate.dart';
import 'package:earth_nova/ui/product_surfaces/auth/screens/loading_screen.dart';
import 'package:earth_nova/ui/product_surfaces/auth/screens/login_screen.dart';

class EarthNovaApp extends ConsumerStatefulWidget {
  const EarthNovaApp({super.key});

  @override
  ConsumerState<EarthNovaApp> createState() => _EarthNovaAppState();
}

class _EarthNovaAppState extends ConsumerState<EarthNovaApp>
    with WidgetsBindingObserver {
  late final AuthHomeNavigationTransitionTracker _authHomeTracker;
  String? _lastLifecycleState;
  bool _wasBackgrounded = false;
  @override
  void initState() {
    super.initState();
    _authHomeTracker = AuthHomeNavigationTransitionTracker(
      logger: ref.read(navigationScreenTransitionLoggerProvider),
    );
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).restoreSession();
      _applyDebugLevelParam();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final obs = ref.read(appObservabilityProvider);
    final previousState = _lastLifecycleState;
    _lastLifecycleState = state.name;
    obs.logFlowEvent(
      'app.lifecycle',
      TelemetryFlowPhase.stateChanged,
      'lifecycle',
      eventName: 'app.lifecycle_changed',
      previousState: previousState ?? 'unknown',
      nextState: state.name,
    );

    final isBackgrounded =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden;
    if (isBackgrounded) {
      _wasBackgrounded = true;
      obs.logFlowEvent(
        'app.lifecycle',
        TelemetryFlowPhase.completed,
        'lifecycle',
        eventName: 'app.backgrounded',
        nextState: state.name,
      );
      unawaited(obs.flush());
      return;
    }

    if (state == AppLifecycleState.resumed && _wasBackgrounded) {
      _wasBackgrounded = false;
      obs.logFlowEvent(
        'app.lifecycle',
        TelemetryFlowPhase.completed,
        'lifecycle',
        eventName: 'app.foregrounded',
        nextState: state.name,
      );
      obs.logFlowEvent(
        'app.lifecycle',
        TelemetryFlowPhase.completed,
        'lifecycle',
        eventName: 'app.warm_start',
        reason: 'resumed_after_background',
      );
    }
  }

  /// Reads `?level=<name>` from the URL and jumps to that map level.
  /// Only active when debug mode is enabled — no-op in production.
  /// Supported values: cell, district, city, state, country, world.
  void _applyDebugLevelParam() {
    if (!kIsWeb) return;
    if (!ref.read(debugModeProvider)) return;

    final param = Uri.base.queryParameters['level'];
    final level = debugLevelFromParam(param);
    if (level == null) return;

    ref.read(mapLevelProvider.notifier).jumpTo(level);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<app_auth.AuthState>(authProvider, (previous, next) {
      if (previous?.status == app_auth.AuthStatus.authenticated &&
          next.status != app_auth.AuthStatus.authenticated) {
        final previousUser = previous?.user;
        if (previousUser != null) {
          unawaited(
            ref.read(appReadinessProvider.notifier).purge(previousUser.id),
          );
        }
        ref.read(homeProvider.notifier).invalidate();
      }
    });
    final authState = ref.watch(authProvider);
    final screenName = authState.when(
      loading: () => 'loading',
      unauthenticated: () => 'login',
      authenticated: (_) => 'tab_shell',
      error: (_) => 'login',
    );
    _authHomeTracker.onScreenVisible(screenName);

    return ShadApp.custom(
      theme: AppDesignTheme.dark(),
      themeMode: ThemeMode.dark,
      appBuilder: (context) => MaterialApp(
        title: 'EarthNova',
        debugShowCheckedModeBanner: false,
        theme: Theme.of(context),
        supportedLocales: const [Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalShadLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        // Include mouse as a drag device so PageView horizontal scroll and
        // OverscrollNotification work correctly on Flutter web/desktop.
        // Flutter's default ScrollBehavior only enables drag for touch.
        scrollBehavior: const MaterialScrollBehavior().copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.stylus,
            PointerDeviceKind.trackpad,
          },
        ),
        navigatorObservers: [
          AppNavigationObserver(logEvent: ref.read(observabilityProvider).log),
        ],
        builder: (context, child) => ShadAppBuilder(child: child),
        home: authState.when(
          loading: () => const LoadingScreen(),
          unauthenticated: () => const LoginScreen(),
          authenticated: (user) =>
              AppReadinessGate(key: ValueKey(user.id), userId: user.id),
          error: (_) => const LoginScreen(),
        ),
      ),
    );
  }
}
