import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/home/domain/entities/home.dart';
import 'package:earth_nova/features/home/domain/repositories/home_repository.dart';
import 'package:earth_nova/features/home/presentation/providers/home_provider.dart';
import 'package:earth_nova/features/home/presentation/screens/home_screen.dart';
import 'package:earth_nova/features/living_world/data/dtos/living_world_dto.dart';
import 'package:earth_nova/features/living_world/domain/entities/living_world_knowledge.dart';
import 'package:earth_nova/features/living_world/domain/entities/town_projection.dart';
import 'package:earth_nova/features/living_world/domain/repositories/living_world_repository.dart';
import 'package:earth_nova/features/living_world/presentation/providers/town_provider.dart';
import 'package:earth_nova/features/living_world/presentation/screens/town_screen.dart';
import 'package:earth_nova/features/living_world/presentation/screens/venue_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../features/home/home_test_data.dart' as home_fixture;
import '../features/living_world/data/living_world_test_data.dart'
    as town_fixture;
import 'phase_five_capture_support.dart';
import 'phase_seven_capture_support.dart';

const _phaseSevenTownAssets = [
  'places/town-empty-1440x900.png',
  'places/town-error-retry-1440x900.png',
];

void main() {
  test('declares the two phase seven Town assets', () {
    expect(_phaseSevenTownAssets, hasLength(2));
    expect(_phaseSevenTownAssets.toSet(), hasLength(2));
  });

  final town = _townProjection();
  final captures = <({String name, Size size, Widget child, String expected})>[
    (
      name: 'places/town-populated-390x844.png',
      size: phaseFiveMobileSize,
      child: _townScene(_TownRepository((_) async => town)),
      expected: 'Marin Current',
    ),
    (
      name: 'places/town-empty-390x844.png',
      size: phaseFiveMobileSize,
      child: _townScene(
        _TownRepository((_) async => _townProjection(withVenue: false)),
      ),
      expected: 'No Venues known yet',
    ),
    (
      name: 'places/town-error-retry-390x844.png',
      size: phaseFiveMobileSize,
      child: _townScene(
        _TownRepository(
          (_) => Future<TownProjection>.error(
            const LivingWorldFailure.unavailable(),
          ),
        ),
      ),
      expected: 'Retry Town load',
    ),
    (
      name: 'places/town-populated-1440x900.png',
      size: phaseFiveDesktopSize,
      child: _townScene(_TownRepository((_) async => town)),
      expected: 'Marin Current',
    ),
    (
      name: 'places/venue-detail-introduced-390x844.png',
      size: phaseFiveMobileSize,
      child: _venueScene(town.venues.single),
      expected: 'Villagers and Services',
    ),
    (
      name: 'places/venue-detail-introduced-1440x900.png',
      size: phaseFiveDesktopSize,
      child: _venueScene(town.venues.single),
      expected: 'Villagers and Services',
    ),
    (
      name: 'home/home-identity-390x844.png',
      size: phaseFiveMobileSize,
      child: _homeScene(_HomeRepository((_) async => _home())),
      expected: 'Your Home',
    ),
    (
      name: 'home/home-identity-1440x900.png',
      size: phaseFiveDesktopSize,
      child: _homeScene(_HomeRepository((_) async => _home())),
      expected: 'Your Home',
    ),
    (
      name: 'home/home-error-retry-390x844.png',
      size: phaseFiveMobileSize,
      child: _homeScene(
        _HomeRepository(
          (_) => Future<Home>.error(const HomeFailure.unavailable()),
        ),
      ),
      expected: 'Retry Home load',
    ),
  ];

  for (final capture in captures) {
    testWidgets('captures ${capture.name}', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await capturePhaseFiveFixture(
        tester,
        size: capture.size,
        name: capture.name,
        child: capture.child,
      );
      expect(find.text(capture.expected), findsOneWidget);
    }, skip: !phaseFiveCaptureEnabled);
  }

  for (final capture in <({String name, Widget child, String expected})>[
    (
      name: 'places/town-empty-1440x900.png',
      child: _townScene(
        _TownRepository((_) async => _townProjection(withVenue: false)),
      ),
      expected: 'No Venues known yet',
    ),
    (
      name: 'places/town-error-retry-1440x900.png',
      child: _townScene(
        _TownRepository(
          (_) => Future<TownProjection>.error(
            const LivingWorldFailure.unavailable(),
          ),
        ),
      ),
      expected: 'Retry Town load',
    ),
  ]) {
    testWidgets('captures ${capture.name}', (tester) async {
      await capturePhaseSevenFixture(
        tester,
        size: phaseSevenDesktopSize,
        name: capture.name,
        child: capture.child,
        prepare: (tester) async {
          expect(find.text(capture.expected), findsOneWidget);
        },
      );
    }, skip: !phaseSevenCaptureEnabled);
  }

  testWidgets('uses read-only production Places and Home surfaces', (
    tester,
  ) async {
    final repository = _TownRepository((_) async => town);
    await _pumpObjective(tester, _townScene(repository));

    expect(find.byType(TownScreen), findsOneWidget);
    expect(find.text('Harbor Current'), findsOneWidget);
    expect(find.text('Marin Current'), findsOneWidget);
    expect(find.textContaining('00000000-'), findsNothing);
    expect(find.textContaining('Visit'), findsNothing);
    expect(repository.visitRequests, 0);

    await _pumpObjective(tester, _venueScene(town.venues.single));

    expect(find.byType(VenueDetailScreen), findsOneWidget);
    expect(find.text('Villagers and Services'), findsOneWidget);
    expect(find.text('Repairs'), findsOneWidget);
    expect(find.text('Opening soon'), findsOneWidget);
    expect(find.textContaining('00000000-'), findsNothing);
    expect(find.textContaining('Visit'), findsNothing);

    await _pumpObjective(
      tester,
      _homeScene(_HomeRepository((_) async => _home())),
    );

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Your Home'), findsOneWidget);
    expect(find.text('Established'), findsWidgets);
    expect(find.textContaining(home_fixture.homeId), findsNothing);
    expect(find.textContaining(home_fixture.playerId), findsNothing);
    expect(find.textContaining('Modules'), findsNothing);
  });
}

Future<void> _pumpObjective(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(ShadApp(key: UniqueKey(), home: child));
  await tester.pumpAndSettle();
}

Widget _townScene(_TownRepository repository) {
  final observability = ObservabilityService(sessionId: 'phase-five-town');
  return ProviderScope(
    overrides: [
      appObservabilityProvider.overrideWithValue(observability),
      livingWorldObservabilityProvider.overrideWithValue(observability),
      livingWorldRepositoryProvider.overrideWithValue(repository),
      authProvider.overrideWith(
        () => _FixedAuthNotifier(_authenticatedTownPlayer()),
      ),
    ],
    child: const TownScreen(),
  );
}

Widget _venueScene(TownVenue venue) {
  return ProviderScope(
    overrides: [
      appObservabilityProvider.overrideWithValue(
        ObservabilityService(sessionId: 'phase-five-venue'),
      ),
    ],
    child: VenueDetailScreen(venue: venue),
  );
}

Widget _homeScene(_HomeRepository repository) {
  final observability = ObservabilityService(sessionId: 'phase-five-home');
  return ProviderScope(
    overrides: [
      appObservabilityProvider.overrideWithValue(observability),
      homeObservabilityProvider.overrideWithValue(observability),
      homeRepositoryProvider.overrideWithValue(repository),
      authProvider.overrideWith(
        () => _FixedAuthNotifier(_authenticatedHomePlayer()),
      ),
    ],
    child: const HomeScreen(),
  );
}

AuthState _authenticatedTownPlayer() {
  return AuthState.authenticated(
    UserProfile(
      id: town_fixture.playerId,
      phone: '5065550101',
      displayName: 'Explorer',
      createdAt: DateTime.utc(2026, 7, 21),
    ),
  );
}

AuthState _authenticatedHomePlayer() {
  return AuthState.authenticated(
    UserProfile(
      id: home_fixture.playerId,
      phone: '5065550101',
      displayName: 'Explorer',
      createdAt: DateTime.utc(2026, 7, 21),
    ),
  );
}

TownProjection _townProjection({bool withVenue = true}) {
  return LivingWorldTownDto.fromJson(
    withVenue ? town_fixture.town() : const {'venues': <Object?>[]},
    playerId: town_fixture.playerId,
  ).toDomain();
}

Home _home() {
  return Home(
    id: home_fixture.homeId,
    playerId: home_fixture.playerId,
    createdAt: DateTime.parse(home_fixture.createdAt),
  );
}

final class _FixedAuthNotifier extends AuthNotifier {
  _FixedAuthNotifier(this._state);

  final AuthState _state;

  @override
  AuthState build() => _state;
}

final class _TownRepository implements LivingWorldRepository {
  _TownRepository(this._read);

  final Future<TownProjection> Function(String playerId) _read;
  int visitRequests = 0;

  @override
  Future<TownProjection> readTown(String playerId, {required String traceId}) =>
      _read(playerId);

  @override
  Future<VenueVisitResult> recordVenueVisit(
    RecordVenueVisitCommand command, {
    required String traceId,
  }) async {
    visitRequests += 1;
    throw const LivingWorldFailure.unavailable();
  }
}

final class _HomeRepository implements HomeRepository {
  _HomeRepository(this._read);

  final Future<Home> Function(String playerId) _read;

  @override
  Future<Home> readHome(String playerId, {required String traceId}) =>
      _read(playerId);
}
