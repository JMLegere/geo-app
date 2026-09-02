import 'dart:async';

import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/home/domain/entities/home.dart';
import 'package:earth_nova/features/home/domain/repositories/home_repository.dart';
import 'package:earth_nova/features/home/presentation/providers/home_provider.dart';
import 'package:earth_nova/features/home/presentation/screens/home_screen.dart';
import 'package:earth_nova/shared/design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../home_test_data.dart';

final _player = UserProfile(
  id: playerId,
  phone: '5555555555',
  displayName: 'Explorer',
  createdAt: DateTime.utc(2026),
);

Home _home() =>
    Home(id: homeId, playerId: playerId, createdAt: DateTime.parse(createdAt));

final class _FixedAuthNotifier extends AuthNotifier {
  _FixedAuthNotifier(this._state);

  final AuthState _state;

  @override
  AuthState build() => _state;
}

final class _FakeHomeRepository implements HomeRepository {
  _FakeHomeRepository(this._read);

  final Future<Home> Function(String playerId) _read;
  final requests = <({String playerId, String traceId})>[];

  @override
  Future<Home> readHome(String playerId, {required String traceId}) async {
    requests.add((playerId: playerId, traceId: traceId));
    return _read(playerId);
  }
}

Future<void> _pumpHomeScreen(
  WidgetTester tester, {
  required AuthState authState,
  required HomeRepository repository,
}) async {
  final observability = ObservabilityService(sessionId: 'home-screen-test');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(() => _FixedAuthNotifier(authState)),
        homeRepositoryProvider.overrideWithValue(repository),
        homeObservabilityProvider.overrideWithValue(observability),
        appObservabilityProvider.overrideWithValue(observability),
      ],
      child: MaterialApp(
        home: ShadTheme(
          data: ShadThemeData(
            brightness: Brightness.dark,
            colorScheme: const ShadZincColorScheme.dark(),
          ),
          child: const HomeScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'loads the authenticated Player Home through the read-only provider',
    (tester) async {
      final repository = _FakeHomeRepository((_) async => _home());

      await _pumpHomeScreen(
        tester,
        authState: AuthState.authenticated(_player),
        repository: repository,
      );
      await tester.pumpAndSettle();

      expect(repository.requests, hasLength(1));
      expect(repository.requests.single.playerId, playerId);
      expect(
        repository.requests.single.traceId,
        startsWith('home-screen-test:home.load'),
      );
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Your permanent place in EarthNova.'), findsOneWidget);
      expect(find.text('Established'), findsWidgets);
    },
  );

  testWidgets('does not read Home while authentication is resolving', (
    tester,
  ) async {
    final repository = _FakeHomeRepository((_) async => _home());

    await _pumpHomeScreen(
      tester,
      authState: const AuthState.loading(),
      repository: repository,
    );

    expect(find.byType(LoadingDots), findsOneWidget);
    expect(find.text('Loading Home'), findsOneWidget);
    expect(repository.requests, isEmpty);
  });

  testWidgets('renders Home unavailable while signed out without reading', (
    tester,
  ) async {
    final repository = _FakeHomeRepository((_) async => _home());

    await _pumpHomeScreen(
      tester,
      authState: const AuthState.unauthenticated(),
      repository: repository,
    );

    expect(find.byType(AppNotice), findsOneWidget);
    expect(find.text('Home unavailable'), findsOneWidget);
    expect(
      find.text('Sign in to view your established Home identity.'),
      findsOneWidget,
    );
    expect(repository.requests, isEmpty);
  });

  testWidgets('renders loading state while the Home read is pending', (
    tester,
  ) async {
    final pending = Completer<Home>();
    final repository = _FakeHomeRepository((_) => pending.future);

    await _pumpHomeScreen(
      tester,
      authState: AuthState.authenticated(_player),
      repository: repository,
    );

    expect(find.text('Loading Home'), findsOneWidget);
    expect(
      find.textContaining('Confirming your personal Home identity'),
      findsOneWidget,
    );

    pending.complete(_home());
    await tester.pumpAndSettle();
  });

  testWidgets('renders retryable safe error state without leaking details', (
    tester,
  ) async {
    final repository = _FakeHomeRepository(
      (_) => Future<Home>.error(StateError('database password')),
    );

    await _pumpHomeScreen(
      tester,
      authState: AuthState.authenticated(_player),
      repository: repository,
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorState), findsOneWidget);
    expect(find.text('Home could not load'), findsOneWidget);
    expect(
      find.text('Unable to load your Home. Pull to retry.'),
      findsOneWidget,
    );
    expect(find.text('Retry Home load'), findsOneWidget);
    expect(find.textContaining('database password'), findsNothing);

    await tester.tap(find.text('Retry Home load'));
    await tester.pumpAndSettle();
    expect(repository.requests, hasLength(2));
  });

  testWidgets('keeps identity visible during a failed stale refresh', (
    tester,
  ) async {
    final refresh = Completer<Home>();
    var request = 0;
    final repository = _FakeHomeRepository((_) {
      request += 1;
      return request == 1 ? Future.value(_home()) : refresh.future;
    });

    await _pumpHomeScreen(
      tester,
      authState: AuthState.authenticated(_player),
      repository: repository,
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    final refreshFuture = container
        .read(homeProvider.notifier)
        .refresh(playerId);
    await tester.pump();

    expect(find.text('Your Home'), findsOneWidget);
    expect(find.text('Loading Home'), findsNothing);
    expect(find.text('July 21, 2026'), findsOneWidget);

    refresh.completeError(StateError('database password'));
    await refreshFuture;
    await tester.pumpAndSettle();

    expect(find.text('Your Home'), findsOneWidget);
    expect(find.text('Home refresh delayed'), findsOneWidget);
    expect(
      find.text('Unable to load your Home. Pull to retry.'),
      findsOneWidget,
    );
    expect(find.textContaining('database password'), findsNothing);
  });

  testWidgets('renders existing Home identity without raw ids or legacy copy', (
    tester,
  ) async {
    final repository = _FakeHomeRepository((_) async => _home());

    await _pumpHomeScreen(
      tester,
      authState: AuthState.authenticated(_player),
      repository: repository,
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('This Home is yours and stays with you.'), findsOneWidget);
    expect(
      find.text('Your Home follows your progress across EarthNova.'),
      findsOneWidget,
    );
    expect(find.text('July 21, 2026'), findsOneWidget);
    expect(find.text('The day this Home became yours.'), findsOneWidget);
    expect(find.byType(AppCard), findsOneWidget);
    expect(find.byType(AppFieldRow), findsNWidgets(3));
    expect(find.textContaining(homeId), findsNothing);
    expect(find.textContaining(playerId), findsNothing);
    expect(find.textContaining('Sanctuary'), findsNothing);
    expect(find.textContaining('Modules'), findsNothing);
    expect(find.textContaining('placement'), findsNothing);
    expect(find.textContaining('capacity'), findsNothing);
    expect(find.textContaining('upgrade'), findsNothing);
    expect(find.textContaining('storage'), findsNothing);
    expect(find.textContaining('progression'), findsNothing);
  });
}
