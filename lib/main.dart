import 'dart:async';
import 'dart:math';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:earth_nova/app/readiness/app_readiness_gate.dart';
import 'package:earth_nova/shared/design.dart';
import 'package:earth_nova/app/readiness/app_readiness.dart';
import 'package:earth_nova/app/sync/application/identification_sync_provider.dart';
import 'package:earth_nova/app/save/application/checkpoint_sync_provider.dart';
import 'package:earth_nova/app/save/data/supabase_checkpoint_gateway.dart';
import 'package:earth_nova/app/readiness/client_working_set.dart';
import 'package:earth_nova/app/sync/application/identification_sync_service.dart';
import 'package:earth_nova/app/sync/application/sync_retry_policy.dart';
import 'package:earth_nova/app/sync/data/shared_preferences_pending_command_store.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/browser_telemetry_session_bridge.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/observable_use_case_provider.dart';
import 'package:earth_nova/core/supabase/supabase_bootstrap.dart';
import 'package:earth_nova/core/persistence/shared_preferences_provider.dart';
import 'package:earth_nova/core/domain/entities/auth_state.dart' as app_auth;
import 'package:earth_nova/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:earth_nova/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:earth_nova/features/auth/domain/repositories/auth_repository.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/auth/presentation/screens/loading_screen.dart';
import 'package:earth_nova/features/auth/presentation/screens/login_screen.dart';
import 'package:earth_nova/features/encounters/presentation/providers/encounter_entry_provider.dart';
import 'package:earth_nova/features/home/data/repositories/supabase_home_repository.dart';
import 'package:earth_nova/features/home/domain/entities/home.dart';
import 'package:earth_nova/features/home/domain/repositories/home_repository.dart';
import 'package:earth_nova/features/home/presentation/providers/home_provider.dart';
import 'package:earth_nova/features/identification/data/repositories/mock_item_repository.dart';
import 'package:earth_nova/features/identification/data/repositories/supabase_item_repository.dart';
import 'package:earth_nova/features/identification/domain/repositories/item_repository.dart';
import 'package:earth_nova/features/identification/data/repositories/supabase_identification_repository.dart';
import 'package:earth_nova/features/identification/data/repositories/supabase_item_property_value_repository.dart';
import 'package:earth_nova/features/identification/domain/repositories/identification_repository.dart';
import 'package:earth_nova/features/identification/domain/repositories/item_property_value_repository.dart';
import 'package:earth_nova/features/identification/presentation/providers/items_provider.dart';
import 'package:earth_nova/features/index/data/repositories/mock_item_index_repository.dart';
import 'package:earth_nova/features/index/data/repositories/supabase_item_index_repository.dart';
import 'package:earth_nova/features/index/domain/repositories/item_index_repository.dart';
import 'package:earth_nova/features/index/presentation/providers/item_index_provider.dart';
import 'package:earth_nova/features/living_world/data/repositories/supabase_living_world_repository.dart';
import 'package:earth_nova/features/living_world/domain/entities/living_world_knowledge.dart';
import 'package:earth_nova/features/living_world/domain/entities/town_projection.dart';
import 'package:earth_nova/features/living_world/domain/repositories/living_world_repository.dart';
import 'package:earth_nova/features/living_world/presentation/providers/town_provider.dart';
import 'package:earth_nova/features/pack/data/repositories/legacy_item_repository_pack_adapter.dart';
import 'package:earth_nova/features/pack/data/repositories/supabase_pack_repository.dart';
import 'package:earth_nova/features/pack/domain/repositories/pack_repository.dart';
import 'package:earth_nova/features/map/data/repositories/fallback_location_repository.dart';
import 'package:earth_nova/features/map/data/repositories/geolocator_location_repository.dart';
import 'package:earth_nova/features/map/data/repositories/mock_cell_repository.dart';
import 'package:earth_nova/features/map/data/repositories/supabase_cell_repository.dart';
import 'package:earth_nova/features/map/data/repositories/supabase_cell_knowledge_repository.dart';
import 'package:earth_nova/features/map/domain/repositories/cell_repository.dart';
import 'package:earth_nova/features/map/domain/entities/cell_knowledge_projection.dart';
import 'package:earth_nova/features/map/domain/repositories/cell_knowledge_repository.dart';
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
  final prefs = await SharedPreferences.getInstance();

  obs.logFlowEvent(
    'app.startup',
    TelemetryFlowPhase.started,
    'lifecycle',
    eventName: 'app.cold_start',
    span: startupSpan,
    data: {
      'version': const String.fromEnvironment(
        'APP_VERSION',
        defaultValue: 'dev',
      ),
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

  // Encounter acquisition remains on the legacy ItemRepository boundary.
  final ItemRepository itemRepository = supabaseClient != null
      ? SupabaseItemRepository(client: supabaseClient, logEvent: obs.log)
      : MockItemRepository();

  final PackRepository packRepository = supabaseClient != null
      ? SupabasePackRepository(client: supabaseClient, logEvent: obs.log)
      : LegacyItemRepositoryPackAdapter(itemRepository);

  final ItemPropertyValueRepository? itemPropertyValueRepository =
      supabaseClient != null
      ? SupabaseItemPropertyValueRepository(client: supabaseClient)
      : null;

  final IdentificationRepository? identificationRepository =
      supabaseClient != null
      ? SupabaseIdentificationRepository(
          client: supabaseClient,
          logEvent: obs.log,
        )
      : null;
  final random = Random();
  const deploymentEnvironment = String.fromEnvironment(
    'DEPLOYMENT_ENVIRONMENT',
    defaultValue: 'unknown',
  );

  final ItemIndexRepository itemIndexRepository = supabaseClient != null
      ? SupabaseItemIndexRepository.fromSupabase(
          supabaseClient,
          logEvent: obs.log,
        )
      : const MockItemIndexRepository();

  final LivingWorldRepository livingWorldRepository = supabaseClient != null
      ? SupabaseLivingWorldRepository.fromSupabase(
          supabaseClient,
          logEvent: obs.log,
        )
      : const _EmptyLivingWorldRepository();

  final HomeRepository homeRepository = supabaseClient != null
      ? SupabaseHomeRepository.fromSupabase(supabaseClient, logEvent: obs.log)
      : const _PreviewHomeRepository();

  final CellRepository cellRepository = supabaseClient != null
      ? SupabaseCellRepository(client: supabaseClient, logEvent: obs.log)
      : MockCellRepository();
  final CellKnowledgeRepository cellKnowledgeRepository = supabaseClient != null
      ? SupabaseCellKnowledgeRepository(
          client: supabaseClient,
          logEvent: obs.log,
        )
      : const _EmptyCellKnowledgeRepository();

  final LocationRepository locationRepository = FallbackLocationRepository(
    real: GeolocatorLocationRepository(),
    logEvent: obs.log,
  );

  final WakeLockRepository wakeLockRepository = _buildWakeLockRepository();

  final HierarchyRepository hierarchyRepository = supabaseClient != null
      ? SupabaseHierarchyRepository(client: supabaseClient, logEvent: obs.log)
      : MockHierarchyRepository();

  FlutterError.onError = (details) {
    obs.logError(
      details.exception,
      details.stack ?? StackTrace.current,
      event: 'app.crash.flutter',
    );
  };

  runZonedGuarded(
    () => runApp(
      ProviderScope(
        overrides: [
          checkpointLocalSaveStoreProvider.overrideWith(
            (ref) => ref.watch(localSaveStoreProvider),
          ),
          checkpointGatewayProvider.overrideWithValue(
            supabaseClient == null
                ? null
                : SupabaseCheckpointGateway(supabaseClient),
          ),
          authRepositoryProvider.overrideWithValue(authRepository),
          itemRepositoryProvider.overrideWithValue(itemRepository),
          packRepositoryProvider.overrideWithValue(packRepository),
          itemPropertyValueRepositoryProvider.overrideWithValue(
            itemPropertyValueRepository,
          ),
          identificationRepositoryProvider.overrideWithValue(
            identificationRepository,
          ),
          identificationSyncServiceProvider.overrideWith((ref) {
            final repository = identificationRepository;
            if (repository == null ||
                (deploymentEnvironment != 'local' &&
                    deploymentEnvironment != 'prod')) {
              return null;
            }
            final service = IdentificationSyncService(
              environment: deploymentEnvironment,
              store: SharedPreferencesPendingCommandStore(prefs),
              repository: repository,
              retryPolicy: const SyncRetryPolicy(),
              now: () => DateTime.now().toUtc(),
              commandId: () => const Uuid().v4(),
              jitterUnit: random.nextDouble,
              logEvent: (event, category, {data}) =>
                  obs.log(event, category, data: data),
              backgroundApplyCanonicalResult: (result) async {
                ref
                    .read(itemsProvider.notifier)
                    .registerOwnedDiscovery(result.committedItem);
                await ref.read(appReadinessProvider.notifier).persistCurrent();
              },
            );
            ref.onDispose(service.dispose);
            return service;
          }),
          itemIndexRepositoryProvider.overrideWithValue(itemIndexRepository),
          livingWorldRepositoryProvider.overrideWithValue(
            livingWorldRepository,
          ),
          livingWorldObservabilityProvider.overrideWithValue(obs),
          homeRepositoryProvider.overrideWithValue(homeRepository),
          homeObservabilityProvider.overrideWithValue(obs),
          cellRepositoryProvider.overrideWithValue(cellRepository),
          cellKnowledgeRepositoryProvider.overrideWithValue(
            cellKnowledgeRepository,
          ),
          locationRepositoryProvider.overrideWithValue(locationRepository),
          nullableSupabaseClientProvider.overrideWithValue(supabaseClient),
          observabilityProvider.overrideWithValue(obs),
          appObservabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          itemsObservabilityProvider.overrideWithValue(obs),
          itemIndexObservabilityProvider.overrideWithValue(obs),
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
          navigationScreenTransitionLoggerProvider.overrideWithValue(
            navigationLogger,
          ),
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

final class _PreviewHomeRepository implements HomeRepository {
  const _PreviewHomeRepository();

  @override
  Future<Home> readHome(String playerId, {required String traceId}) async {
    assert(traceId.isNotEmpty);
    return Home(
      id: 'preview-home',
      playerId: playerId,
      createdAt: DateTime.utc(2026, 7, 21),
    );
  }
}

final class _EmptyCellKnowledgeRepository implements CellKnowledgeRepository {
  const _EmptyCellKnowledgeRepository();

  @override
  Future<Map<String, CellKnowledgeProjection>> fetchForCells(
    Iterable<String> cellIds, {
    String? traceId,
  }) async => const {};
}

final class _EmptyLivingWorldRepository implements LivingWorldRepository {
  const _EmptyLivingWorldRepository();

  @override
  Future<TownProjection> readTown(
    String playerId, {
    required String traceId,
  }) async {
    return TownProjection(playerId: playerId);
  }

  @override
  Future<VenueVisitResult> recordVenueVisit(
    RecordVenueVisitCommand command, {
    required String traceId,
  }) async {
    throw const LivingWorldFailure.unavailable();
  }
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
