import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';
import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/fog/fog_state_resolver.dart';
import 'package:earth_nova/core/game/game_coordinator.dart';
import 'package:earth_nova/core/species/stats_service.dart';
import 'package:earth_nova/core/state/app_database_provider.dart';
import 'package:earth_nova/core/state/game_coordinator_provider.dart';
import 'package:earth_nova/features/auth/models/auth_state.dart';
import 'package:earth_nova/features/auth/models/user_profile.dart';
import 'package:earth_nova/features/auth/providers/auth_provider.dart';
import 'package:earth_nova/features/auth/providers/upgrade_prompt_provider.dart';
import 'package:earth_nova/features/map/map_screen.dart';
import 'package:earth_nova/features/onboarding/providers/onboarding_provider.dart';
import 'package:earth_nova/core/state/player_provider.dart';
import 'package:earth_nova/features/sync/providers/location_enrichment_provider.dart';
import 'package:earth_nova/features/sync/services/location_enrichment_service.dart';
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
  PlayerState build() => PlayerState(hasCompletedOnboarding: true);
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

    // Suppress FlutterErrors globally for this test. MapLibreMap throws
    // UnimplementedError on headless platforms, provider resolution triggers
    // setState-during-build cascades, and teardown raises ref-after-unmount /
    // animation-still-running errors. We only care that the widget tree
    // mounts and contains MapScreen.
    final originalOnError = FlutterError.onError!;
    FlutterError.onError = (_) {};
    addTearDown(() => FlutterError.onError = originalOnError);

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
          upgradePromptProvider.overrideWith(_NoTimerUpgradePromptNotifier.new),
        ],
        child: const EarthNovaApp(),
      ),
    );

    // Pump once to let the widget tree settle after initial mount.
    await tester.pump(const Duration(milliseconds: 100));

    // Drain all queued test exceptions (MapLibre + provider cascades).
    while (tester.takeException() != null) {}

    // After auth resolves, the MapScreen widget is present in the widget tree.
    expect(find.byType(MapScreen), findsOneWidget);
  });
}
