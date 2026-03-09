import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';
import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/fog/fog_state_resolver.dart';
import 'package:earth_nova/core/game/game_coordinator.dart';
import 'package:earth_nova/core/species/stats_service.dart';
import 'package:earth_nova/core/state/game_coordinator_provider.dart';
import 'package:earth_nova/features/auth/models/auth_state.dart';
import 'package:earth_nova/features/auth/models/user_profile.dart';
import 'package:earth_nova/features/auth/providers/auth_provider.dart';
import 'package:earth_nova/features/map/map_screen.dart';
import 'package:earth_nova/features/onboarding/providers/onboarding_provider.dart';
import 'package:earth_nova/core/state/player_provider.dart';
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
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    // Create a minimal no-op GameCoordinator for the test. EarthNovaApp
    // watches gameCoordinatorProvider to eagerly trigger auth init, but in
    // tests we override authProvider directly so GC doesn't need to run.
    final noOpCoordinator = GameCoordinator(
      fogResolver: FogStateResolver(_StubCellService()),
      statsService: StatsService(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          onboardingProvider.overrideWith(_CompletedOnboardingNotifier.new),
          authProvider.overrideWith(_AuthenticatedNotifier.new),
          playerProvider.overrideWith(_OnboardedPlayerNotifier.new),
          gameCoordinatorProvider.overrideWithValue(noOpCoordinator),
        ],
        child: const EarthNovaApp(),
      ),
    );

    // Auth starts authenticated via override — should go straight to TabShell.
    // MapLibreMap is a platform view that throws UnimplementedError in the
    // headless test environment. Clear it so the test can verify the screen
    // scaffolding.
    await tester.pump(const Duration(milliseconds: 100));
    tester.takeException();

    // After auth resolves, the MapScreen widget is present in the widget tree.
    expect(find.byType(MapScreen), findsOneWidget);
  });
}
