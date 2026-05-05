import 'dart:async';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/browser_telemetry_session_bridge.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/observable_use_case_provider.dart';
import 'package:earth_nova/core/supabase/supabase_bootstrap.dart';
import 'package:earth_nova/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:earth_nova/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/auth/presentation/screens/loading_screen.dart';
import 'package:earth_nova/features/auth/presentation/screens/login_screen.dart';
import 'package:earth_nova/features/identification/data/repositories/mock_item_repository.dart';
import 'package:earth_nova/features/identification/data/repositories/supabase_item_repository.dart';
import 'package:earth_nova/features/identification/domain/repositories/item_repository.dart';
import 'package:earth_nova/features/identification/presentation/providers/items_provider.dart';
import 'package:earth_nova/features/map/data/repositories/fallback_location_repository.dart';
import 'package:earth_nova/features/map/data/repositories/geolocator_location_repository.dart';
import 'package:earth_nova/features/map/data/repositories/mock_cell_repository.dart';
import 'package:earth_nova/features/map/data/repositories/supabase_cell_repository.dart';
import 'package:earth_nova/features/map/domain/repositories/cell_repository.dart';
import 'package:earth_nova/features/map/domain/repositories/location_repository.dart';
import 'package:earth_nova/features/map/presentation/providers/encounter_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/exploration_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/player_marker_provider.dart';
import 'package:earth_nova/features/map/data/repositories/mobile_wake_lock_repository.dart';
import 'package:earth_nova/features/map/data/repositories/mock_hierarchy_repository.dart';
import 'package:earth_nova/features/map/data/repositories/noop_wake_lock_repository.dart';
import 'package:earth_nova/features/map/data/repositories/supabase_hierarchy_repository.dart';
import 'package:earth_nova/features/map/data/repositories/web_wake_lock_repository.dart';
import 'package:earth_nova/features/map/domain/repositories/hierarchy_repository.dart';
import 'package:earth_nova/features/map/domain/repositories/wake_lock_repository.dart';
import 'package:earth_nova/features/map/presentation/providers/hierarchy_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_level_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/visit_queue_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/wake_lock_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:earth_nova/shared/debug/debug_level_param.dart';
import 'package:earth_nova/shared/debug/debug_mode_provider.dart';
import 'package:earth_nova/shared/observability/navigation/app_navigation_observer.dart';
import 'package:earth_nova/shared/observability/navigation/auth_home_navigation_transition_tracker.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';
import 'package:earth_nova/shared/widgets/tab_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sessionId = readBrowserTelemetrySessionId() ?? const Uuid().v4();

  final supabaseUrl = const String.fromEnvironment('SUPABASE_URL');
  final supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY');

  SupabaseClient? supabaseClient;
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await SupabaseBootstrap.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      supabaseClient = Supabase.instance.client;
    } catch (e) {
      debugPrint('[Main] Supabase init failed: $e');
    }
  }

  final obs = ObservabilityService(
    sessionId: sessionId,
    client: supabaseClient,
  );
  publishTelemetrySessionToBrowser(sessionId);
  final startupSpan = obs.startSpan('app.startup');
  final navigationLogger = NavigationScreenTransitionLogger(logEvent: obs.log);
  obs.startPeriodicFlush();

  obs.logFlowEvent(
    'app.startup',
    TelemetryFlowPhase.started,
    'lifecycle',
    eventName: 'app.cold_start',
    span: startupSpan,
    data: {
      'version':
          const String.fromEnvironment('APP_VERSION', defaultValue: 'dev'),
      'platform': 'web',
    },
  );

  if (supabaseClient != null) {
    obs.logFlowEvent(
      'app.startup',
      TelemetryFlowPhase.dependencyReady,
      'infrastructure',
      eventName: 'supabase.init_success',
      span: startupSpan,
      dependency: 'supabase',
    );
  } else {
    obs.logFlowEvent(
      'app.startup',
      TelemetryFlowPhase.dependencyFailed,
      'infrastructure',
      eventName: 'supabase.init_failure',
      span: startupSpan,
      dependency: 'supabase',
      data: {'error': 'No SUPABASE_URL provided'},
    );
  }

  final AuthRepository authRepository = supabaseClient != null
      ? SupabaseAuthRepository(client: supabaseClient, logEvent: obs.log)
      : MockAuthRepository();

  final ItemRepository itemRepository = supabaseClient != null
      ? SupabaseItemRepository(client: supabaseClient, logEvent: obs.log)
      : MockItemRepository();

  final CellRepository cellRepository = supabaseClient != null
      ? SupabaseCellRepository(client: supabaseClient, logEvent: obs.log)
      : MockCellRepository();

  final LocationRepository locationRepository = FallbackLocationRepository(
    real: GeolocatorLocationRepository(),
    logEvent: obs.log,
  );

  final WakeLockRepository wakeLockRepository = _buildWakeLockRepository();

  final prefs = await SharedPreferences.getInstance();

  final HierarchyRepository hierarchyRepository = supabaseClient != null
      ? SupabaseHierarchyRepository(client: supabaseClient, logEvent: obs.log)
      : MockHierarchyRepository();

  FlutterError.onError = (details) {
    obs.logError(details.exception, details.stack ?? StackTrace.current,
        event: 'app.crash.flutter');
  };

  runZonedGuarded(
    () => runApp(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          itemRepositoryProvider.overrideWithValue(itemRepository),
          cellRepositoryProvider.overrideWithValue(cellRepository),
          locationRepositoryProvider.overrideWithValue(locationRepository),
          observabilityProvider.overrideWithValue(obs),
          appObservabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          itemsObservabilityProvider.overrideWithValue(obs),
          mapObservabilityProvider.overrideWithValue(obs),
          locationObservabilityProvider.overrideWithValue(obs),
          encounterObservabilityProvider.overrideWithValue(obs),
          explorationObservabilityProvider.overrideWithValue(obs),
          playerMarkerObservabilityProvider.overrideWithValue(obs),
          visitQueueObservabilityProvider.overrideWithValue(obs),
          wakeLockObservabilityProvider.overrideWithValue(obs),
          wakeLockRepositoryProvider.overrideWithValue(wakeLockRepository),
          mapLevelObservabilityProvider.overrideWithValue(obs),
          hierarchyObservabilityProvider.overrideWithValue(obs),
          hierarchyRepositoryProvider.overrideWithValue(hierarchyRepository),
          navigationScreenTransitionLoggerProvider
              .overrideWithValue(navigationLogger),
          debugModeObservabilityProvider.overrideWithValue(obs),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const _EarthNovaApp(),
      ),
    ),
    (error, stack) {
      obs.logError(error, stack, event: 'app.crash.unhandled');
    },
  );
  obs.logFlowEvent(
    'app.startup',
    TelemetryFlowPhase.completed,
    'lifecycle',
    eventName: 'app.startup.completed',
    span: startupSpan,
    reason: 'run_app_invoked',
  );
  obs.endSpan(
    startupSpan,
    statusCode: TelemetrySpanStatus.ok,
    statusMessage: 'run_app_invoked',
  );
}

WakeLockRepository _buildWakeLockRepository() {
  if (kIsWeb) return WebWakeLockRepository();
  if (defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.android) {
    return MobileWakeLockRepository();
  }
  return NoopWakeLockRepository();
}

class _EarthNovaApp extends ConsumerStatefulWidget {
  const _EarthNovaApp();

  @override
  ConsumerState<_EarthNovaApp> createState() => _EarthNovaAppState();
}

class _EarthNovaAppState extends ConsumerState<_EarthNovaApp>
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

    final isBackgrounded = state == AppLifecycleState.paused ||
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
    final authState = ref.watch(authProvider);
    final screenName = authState.when(
      loading: () => 'loading',
      unauthenticated: () => 'login',
      authenticated: (_) => 'home',
      error: (_) => 'login',
    );
    _authHomeTracker.onScreenVisible(screenName);

    return MaterialApp(
      title: 'EarthNova',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
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
      home: authState.when(
        loading: () => const LoadingScreen(),
        unauthenticated: () => const LoginScreen(),
        authenticated: (_) => const TabShell(),
        error: (_) => const LoginScreen(),
      ),
    );
  }
}
