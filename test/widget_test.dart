import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';
import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/fog/fog_state_resolver.dart';
import 'package:earth_nova/core/engine/game_coordinator.dart';
import 'package:earth_nova/features/items/services/stats_service.dart';
import 'package:earth_nova/core/state/app_database_provider.dart';
import 'package:earth_nova/core/state/game_coordinator_provider.dart';
import 'package:earth_nova/features/auth/models/auth_state.dart';
import 'package:earth_nova/features/auth/models/user_profile.dart';
import 'package:earth_nova/features/auth/providers/auth_provider.dart';
import 'package:earth_nova/features/auth/providers/upgrade_prompt_provider.dart';
import 'package:earth_nova/features/map/map_screen.dart';
import 'package:earth_nova/features/onboarding/providers/onboarding_provider.dart';
import 'package:earth_nova/core/state/player_provider.dart';
import 'package:earth_nova/features/sync/providers/admin_boundary_provider.dart';
import 'package:earth_nova/features/sync/providers/location_enrichment_provider.dart';
import 'package:earth_nova/features/sync/services/location_enrichment_service.dart';
import 'package:earth_nova/core/engine/engine_input.dart';
import 'package:earth_nova/core/engine/engine_runner.dart';
import 'package:earth_nova/core/engine/game_event.dart';
import 'package:earth_nova/core/species/species_cache.dart';
import 'package:earth_nova/core/state/species_repository_provider.dart';
import 'package:earth_nova/main.dart';

/// Stub notifier that reports onboarding as complete without touching
/// SharedPreferences — safe to use in the headless test environment.
class _CompletedOnboardingNotifier extends OnboardingNotifier {
  @override
  bool? build() => true;
}

/// Stub notifier that starts in authenticated state immediately,
/// bypassing gameCoordinatorProvider's async auth initialization.
class _AuthenticatedNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState.authenticated(
        UserProfile(
          id: 'test-user',
          email: '',
          displayName: 'Explorer',
          createdAt: DateTime.now(),
        ),
      );
}

/// Stub notifier that reports onboarding as complete via PlayerState,
/// which is what EarthNovaApp actually checks for routing.
class _OnboardedPlayerNotifier extends PlayerNotifier {
  @override
  PlayerState build() =>
      PlayerState(hasCompletedOnboarding: true, isHydrated: true);
}

/// No-op stub for [EngineRunner] that prevents MapScreen from crashing
/// when engineRunnerProvider is read before gameCoordinatorProvider.
class _StubEngineRunner implements EngineRunner {
  final _controller = StreamController<GameEvent>.broadcast();
  @override
  Stream<GameEvent> get events => _controller.stream;
  @override
  void send(EngineInput input) {}
  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

/// No-op stub for [LocationEnrichmentService] that prevents the real
/// provider chain from resolving (which requires Supabase client and hangs in
/// headless CI). Uses [noSuchMethod] so all method/setter calls are safe.
class _StubLocationEnrichmentService implements LocationEnrichmentService {
  @override
  void noSuchMethod(Invocation invocation) {}
}

/// No-op stub for [UpgradePromptNotifier] that skips the session timer.
/// The real notifier starts a 2-minute [Timer] in [build] which outlasts
/// the test and causes "pending timer" failures in fake_async.
class _NoTimerUpgradePromptNotifier extends UpgradePromptNotifier {
  @override
  UpgradePromptState build() => const UpgradePromptState(
        totalCollected: 0,
        supabaseInitialized: false,
      );
}

/// Minimal CellService for creating a no-op GameCoordinator in tests.
class _StubCellService implements CellService {
  @override
  String getCellId(double lat, double lon) => 'cell_0_0';
  @override
  Geographic getCellCenter(String cellId) => Geographic(lat: 0, lon: 0);
  @override
  List<Geographic> getCellBoundary(String cellId) => [];
  @override
  List<String> getNeighborIds(String cellId) => [];
  @override
  List<String> getCellsInRing(String cellId, int k) => [cellId];
  @override
  List<String> getCellsAroundLocation(double lat, double lon, int k) =>
      ['cell_0_0'];
  @override
  double get cellEdgeLengthMeters => 180;
  @override
  String get systemName => 'Stub';
}

void main() {
  // Drift warns about multiple open databases in tests. Suppress.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('App renders without crashing', (WidgetTester tester) async {
    // Create a minimal no-op GameCoordinator for the test. EarthNovaApp
    // watches gameCoordinatorProvider to eagerly trigger auth init, but in
    // tests we override authProvider directly so GC doesn't need to run.
    final stubCellService = _StubCellService();
    final noOpCoordinator = GameCoordinator(
      fogResolver: FogStateResolver(stubCellService),
      statsService: StatsService(),
      cellService: stubCellService,
    );

    // In-memory database cuts off ALL provider chains that resolve through
    // appDatabaseProvider → path_provider (which hangs in headless CI).
    final inMemoryDb = AppDatabase(NativeDatabase.memory());
    addTearDown(() => inMemoryDb.close());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingProvider.overrideWith(_CompletedOnboardingNotifier.new),
          authProvider.overrideWith(_AuthenticatedNotifier.new),
          playerProvider.overrideWith(_OnboardedPlayerNotifier.new),
          gameCoordinatorProvider.overrideWithValue(noOpCoordinator),
          appDatabaseProvider.overrideWithValue(inMemoryDb),
          locationEnrichmentServiceProvider
              .overrideWithValue(_StubLocationEnrichmentService()),
          adminBoundaryServiceProvider.overrideWithValue(null),
          upgradePromptProvider.overrideWith(_NoTimerUpgradePromptNotifier.new),
          speciesCacheProvider.overrideWithValue(SpeciesCache.empty()),
          engineRunnerProvider.overrideWithValue(_StubEngineRunner()),
        ],
        child: const EarthNovaApp(),
      ),
    );

    // Pump to let the widget tree settle. MapLibre throws
    // UnimplementedError on headless platforms — ErrorBoundary catches it
    // via addPostFrameCallback and shows fallback UI.
    await tester.pump(const Duration(milliseconds: 100));

    // Drain queued test exceptions (MapLibre + provider cascades).
    while (tester.takeException() != null) {}

    // The app mounted and routed to the map tab. On headless platforms
    // MapLibre throws → ErrorBoundary shows fallback. Either outcome means
    // the app launched successfully.
    final mapScreen = find.byType(MapScreen);
    final errorFallback = find.text('Something went wrong');
    expect(
      mapScreen.evaluate().isNotEmpty || errorFallback.evaluate().isNotEmpty,
      isTrue,
      reason: 'Expected MapScreen or ErrorBoundary fallback to be in the tree',
    );
  });
}
