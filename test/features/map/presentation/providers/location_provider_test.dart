import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/observable_use_case_provider.dart';
import 'package:earth_nova/core/persistence/shared_preferences_provider.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/repositories/location_repository.dart';
import 'package:earth_nova/features/map/presentation/providers/desktop_controls_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';

class TestObservabilityService extends ObservabilityService {
  TestObservabilityService({super.deploymentEnvironment = 'unknown'})
      : super(sessionId: 'test-session');

  final List<({String event, String category, Map<String, dynamic>? data})>
      events = [];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    events.add((event: event, category: category, data: data));
    super.log(event, category, data: data);
  }

  List<String> get eventNames => events.map((e) => e.event).toList();
}

class ControllableMockLocationRepository implements LocationRepository {
  final _controller = StreamController<LocationState>.broadcast();
  bool _permissionGranted = true;
  LocationState? _currentPosition;
  bool _throwOnGetCurrent = false;
  Completer<bool>? _permissionCompleter;
  int permissionRequests = 0;
  int currentPositionRequests = 0;
  int positionStreamReads = 0;

  @override
  Stream<LocationState> get positionStream {
    positionStreamReads += 1;
    return _controller.stream;
  }

  @override
  Future<LocationState> getCurrentPosition({String? traceId}) async {
    currentPositionRequests += 1;
    if (_throwOnGetCurrent) throw Exception('Location unavailable');
    if (_currentPosition != null) return _currentPosition!;
    return LocationState(
      lat: 0.0,
      lng: 0.0,
      accuracy: 10.0,
      timestamp: DateTime(2026),
      isConfident: true,
    );
  }

  @override
  Future<bool> requestPermission({String? traceId}) async {
    permissionRequests += 1;
    final completer = _permissionCompleter;
    if (completer != null) return completer.future;
    return _permissionGranted;
  }

  void emitPosition(LocationState position) {
    _currentPosition = position;
    _controller.add(position);
  }

  void emitError(Object error) => _controller.addError(error);

  void setPermissionGranted(bool granted) => _permissionGranted = granted;
  void setThrowOnGetCurrent(bool value) => _throwOnGetCurrent = value;
  void hangPermissionRequest() {
    _permissionCompleter = Completer<bool>();
  }

  void dispose() => _controller.close();
}

class _AuthenticatedAuthNotifier extends AuthNotifier {
  _AuthenticatedAuthNotifier(this.userId);

  final String userId;

  @override
  AuthState build() => AuthState.authenticated(UserProfile(
        id: userId,
        phone: '+15555550100',
        createdAt: DateTime(2026),
      ));
}

class _DesktopControlsNotifier extends DesktopControlsNotifier {
  _DesktopControlsNotifier(this.enabled);

  final bool enabled;

  @override
  bool build() => enabled;
}

void main() {
  group('LocationNotifier', () {
    late ProviderContainer container;
    late TestObservabilityService obs;
    late ControllableMockLocationRepository repo;

    setUp(() {
      obs = TestObservabilityService();
      repo = ControllableMockLocationRepository();
      container = ProviderContainer(
        overrides: [
          locationObservabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          locationRepositoryProvider.overrideWithValue(repo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      repo.dispose();
    });

    test('initial state is loading', () {
      final state = container.read(locationProvider);
      expect(state, isA<LocationProviderLoading>());
    });

    test('transitions to active after receiving first position', () async {
      container.read(locationProvider);

      final position = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      repo.emitPosition(position);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(locationProvider);
      expect(state, isA<LocationProviderActive>());
      final active = state as LocationProviderActive;
      expect(active.location.lat, 37.7749);
      expect(active.location.lng, -122.4194);
    });

    test('transitions to permissionDenied when permission is denied', () async {
      repo.setPermissionGranted(false);

      final c = ProviderContainer(
        overrides: [
          locationObservabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          locationRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(c.dispose);

      c.read(locationProvider);
      await Future<void>.delayed(Duration.zero);

      final state = c.read(locationProvider);
      expect(state, isA<LocationProviderPermissionDenied>());
    });

    test('transitions to error when getCurrentPosition throws', () async {
      repo.setThrowOnGetCurrent(true);

      final c = ProviderContainer(
        overrides: [
          locationObservabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          locationRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(c.dispose);

      c.read(locationProvider);
      await Future<void>.delayed(Duration.zero);

      final state = c.read(locationProvider);
      expect(state, isA<LocationProviderError>());
      final error = state as LocationProviderError;
      expect(error.message, isNotEmpty);
    });

    test('logs map.gps_started event on build', () async {
      container.read(locationProvider);
      await Future<void>.delayed(Duration.zero);

      expect(obs.eventNames, contains('map.gps_started'));
    });

    test('logs map.gps_position_updated on each position', () async {
      container.read(locationProvider);

      final position = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      repo.emitPosition(position);
      await Future<void>.delayed(Duration.zero);

      expect(obs.eventNames, contains('map.gps_position_updated'));
    });

    test('logs map.gps_permission_denied when permission denied', () async {
      repo.setPermissionGranted(false);

      final c = ProviderContainer(
        overrides: [
          locationObservabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          locationRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(c.dispose);

      c.read(locationProvider);
      await Future<void>.delayed(Duration.zero);

      expect(obs.eventNames, contains('map.gps_permission_denied'));
    });

    test('logs map.gps_error when error occurs', () async {
      repo.setThrowOnGetCurrent(true);

      final c = ProviderContainer(
        overrides: [
          locationObservabilityProvider.overrideWithValue(obs),
          locationRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(c.dispose);

      c.read(locationProvider);
      await Future<void>.delayed(Duration.zero);

      expect(obs.eventNames, contains('map.gps_error'));
    });

    testWidgets('logs GPS startup wait stage when permission request hangs',
        (tester) async {
      repo.hangPermissionRequest();

      final c = ProviderContainer(
        overrides: [
          locationObservabilityProvider.overrideWithValue(obs),
          observableUseCaseProvider.overrideWithValue(obs),
          locationRepositoryProvider.overrideWithValue(repo),
        ],
      );

      c.read(locationProvider);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      final event = obs.events.lastWhere(
        (event) => event.event == 'map.gps_startup_waiting',
      );
      expect(event.data?['startup_stage'], 'permission_request');
      expect(event.data?['dependency'], 'gps');
      expect(event.data?['phase'], TelemetryFlowPhase.waitingOn.wireName);

      c.dispose();
      await tester.pump();
    });
    test('uses category map', () async {
      container.read(locationProvider);
      await Future<void>.delayed(Duration.zero);

      for (final event in obs.events) {
        expect(event.category, 'map');
      }
    });

    test('updates state on multiple position emissions', () async {
      container.read(locationProvider);

      final pos1 = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      final pos2 = LocationState(
        lat: 37.7750,
        lng: -122.4195,
        accuracy: 3.0,
        timestamp: DateTime(2026, 1, 1, 0, 0, 1),
        isConfident: true,
      );

      repo.emitPosition(pos1);
      await Future<void>.delayed(Duration.zero);
      repo.emitPosition(pos2);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(locationProvider);
      expect(state, isA<LocationProviderActive>());
      final active = state as LocationProviderActive;
      expect(active.location.lat, 37.7750);
    });

    test('stream error transitions to paused (not permanent error)', () async {
      container.read(locationProvider);

      final position = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      repo.emitPosition(position);
      await Future<void>.delayed(Duration.zero);

      // Confirm active before error
      expect(container.read(locationProvider), isA<LocationProviderActive>());

      // Emit a stream error (e.g. geolocator timeout)
      repo.emitError(Exception('GPS timeout'));
      await Future<void>.delayed(Duration.zero);

      // Must NOT transition to LocationProviderError — shows paused banner instead
      final state = container.read(locationProvider);
      expect(
        state,
        isA<LocationProviderPaused>(),
        reason: 'A transient stream error must show a paused banner, '
            'not strand the user on a permanent error screen.',
      );
    });

    test('stream error recovery resumes active state automatically', () async {
      container.read(locationProvider);

      final position = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      repo.emitPosition(position);
      await Future<void>.delayed(Duration.zero);

      // Trigger paused state via stream error
      repo.emitError(Exception('GPS timeout'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(locationProvider), isA<LocationProviderPaused>());

      // GPS recovers — emit a new position
      final recoveredPosition = LocationState(
        lat: 37.7750,
        lng: -122.4195,
        accuracy: 5.0,
        timestamp: DateTime(2026, 1, 1, 0, 0, 5),
        isConfident: true,
      );
      repo.emitPosition(recoveredPosition);
      await Future<void>.delayed(Duration.zero);

      // Must resume active without manual refresh
      final state = container.read(locationProvider);
      expect(
        state,
        isA<LocationProviderActive>(),
        reason: 'Discovery must resume automatically when GPS returns.',
      );
      final active = state as LocationProviderActive;
      expect(active.location.lat, 37.7750);
    });

    test('stream error logs map.gps_paused event', () async {
      container.read(locationProvider);

      final position = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      repo.emitPosition(position);
      await Future<void>.delayed(Duration.zero);

      repo.emitError(Exception('GPS timeout'));
      await Future<void>.delayed(Duration.zero);

      expect(obs.eventNames, contains('map.gps_paused'));
    });

    test('GPS recovery logs map.gps_resumed event', () async {
      container.read(locationProvider);

      final position = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      repo.emitPosition(position);
      await Future<void>.delayed(Duration.zero);

      repo.emitError(Exception('GPS timeout'));
      await Future<void>.delayed(Duration.zero);

      final recoveredPosition = LocationState(
        lat: 37.7750,
        lng: -122.4195,
        accuracy: 5.0,
        timestamp: DateTime(2026, 1, 1, 0, 0, 5),
        isConfident: true,
      );
      repo.emitPosition(recoveredPosition);
      await Future<void>.delayed(Duration.zero);

      expect(obs.eventNames, contains('map.gps_resumed'));
    });

    test('stream error is logged as map.gps_stream_error', () async {
      container.read(locationProvider);

      final position = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      repo.emitPosition(position);
      await Future<void>.delayed(Duration.zero);

      repo.emitError(Exception('GPS timeout'));
      await Future<void>.delayed(Duration.zero);

      expect(obs.eventNames, contains('map.gps_stream_error'));
    });

    test('stream error does not log map.gps_error (no permanent error state)',
        () async {
      container.read(locationProvider);

      final position = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026),
        isConfident: true,
      );
      repo.emitPosition(position);
      await Future<void>.delayed(Duration.zero);

      repo.emitError(Exception('transient error'));
      await Future<void>.delayed(Duration.zero);

      // map.gps_error is only for getCurrentPosition failures, not stream errors
      expect(obs.eventNames, isNot(contains('map.gps_error')));
    });
    test('debug movement uses Fredericton fallback and activates location',
        () async {
      container.read(locationProvider);
      await Future<void>.delayed(Duration.zero);

      container
          .read(locationProvider.notifier)
          .moveDebugLocation(DebugLocationMoveDirection.north);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(locationProvider);
      expect(state, isA<LocationProviderActive>());
      final location = switch (state) {
        LocationProviderActive(location: final location) => location,
        _ => fail('Expected debug location to be active'),
      };
      expect(location.lat, greaterThan(45.9636));
      expect(location.lng, closeTo(-66.6431, 0.000001));
      expect(location.isConfident, isTrue);
      expect(obs.eventNames, contains('map.debug_location_updated'));
    });

    test('debug movement can target an explicit unvisited-cell coordinate',
        () async {
      container.read(locationProvider);
      await Future<void>.delayed(Duration.zero);

      container.read(locationProvider.notifier).moveDebugLocationTo(
            lat: 45.9642,
            lng: -66.6424,
            targetCellId: 'cell-target',
            reason: 'nearest_unvisited_cell',
          );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(locationProvider);
      expect(state, isA<LocationProviderActive>());
      final location = switch (state) {
        LocationProviderActive(location: final location) => location,
        _ => fail('Expected explicit debug target to be active'),
      };
      expect(location.lat, 45.9642);
      expect(location.lng, -66.6424);
      expect(location.isConfident, isTrue);

      final event = obs.events.lastWhere(
        (event) => event.event == 'map.debug_location_updated',
      );
      expect(event.data?['source'], 'debug_controls');
      expect(event.data?['target_cell_id'], 'cell-target');
      expect(event.data?['reason'], 'nearest_unvisited_cell');
      expect(event.data?['geo_location_enabled'], isFalse);
    });

    test('debug movement ignores later real GPS stream updates', () async {
      container.read(locationProvider);
      await Future<void>.delayed(Duration.zero);

      container
          .read(locationProvider.notifier)
          .moveDebugLocation(DebugLocationMoveDirection.east);
      await Future<void>.delayed(Duration.zero);
      final debugState = container.read(locationProvider);
      final debugLocation = switch (debugState) {
        LocationProviderActive(location: final location) => location,
        _ => fail('Expected debug location to be active'),
      };

      repo.emitPosition(LocationState(
        lat: 1.0,
        lng: 2.0,
        accuracy: 5.0,
        timestamp: DateTime(2026, 1, 1, 0, 0, 2),
        isConfident: true,
      ));
      await Future<void>.delayed(Duration.zero);

      final state = container.read(locationProvider);
      final location = switch (state) {
        LocationProviderActive(location: final location) => location,
        _ => fail('Expected debug location to remain active'),
      };
      expect(location, debugLocation);
    });

    test('resumeGps leaves debug mode and accepts real GPS again', () async {
      container.read(locationProvider);
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(locationProvider.notifier);
      notifier.moveDebugLocation(DebugLocationMoveDirection.west);
      await Future<void>.delayed(Duration.zero);
      notifier.resumeGps();
      await Future<void>.delayed(Duration.zero);

      final gpsPosition = LocationState(
        lat: 37.7749,
        lng: -122.4194,
        accuracy: 5.0,
        timestamp: DateTime(2026, 1, 1, 0, 0, 3),
        isConfident: true,
      );
      repo.emitPosition(gpsPosition);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(locationProvider);
      final location = switch (state) {
        LocationProviderActive(location: final location) => location,
        _ => fail('Expected GPS location to be active after resume'),
      };
      expect(location, gpsPosition);
      expect(obs.eventNames, contains('map.debug_location_disabled'));
    });
    group('Desktop Mode location', () {
      Future<ProviderContainer> desktopContainer({
        required SharedPreferences prefs,
        required TestObservabilityService obs,
        required ControllableMockLocationRepository repo,
        required String userId,
        required bool enabled,
      }) async {
        return ProviderContainer(
          overrides: [
            locationObservabilityProvider.overrideWithValue(obs),
            observableUseCaseProvider.overrideWithValue(obs),
            observabilityProvider.overrideWithValue(obs),
            locationRepositoryProvider.overrideWithValue(repo),
            sharedPreferencesProvider.overrideWithValue(prefs),
            authProvider.overrideWith(() => _AuthenticatedAuthNotifier(userId)),
            desktopControlsAvailableProvider.overrideWithValue(true),
            desktopControlsProvider
                .overrideWith(() => _DesktopControlsNotifier(enabled)),
          ],
        );
      }

      test(
          'uses Fredericton without touching GPS when Desktop Mode is available',
          () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repo = ControllableMockLocationRepository();
        final container = await desktopContainer(
          prefs: prefs,
          obs: TestObservabilityService(deploymentEnvironment: 'desktop-test'),
          repo: repo,
          userId: 'player-a',
          enabled: false,
        );
        addTearDown(container.dispose);
        addTearDown(repo.dispose);

        final state = container.read(locationProvider);
        final location = (state as LocationProviderActive).location;
        expect(location.lat, 45.9636);
        expect(location.lng, -66.6431);
        expect(repo.permissionRequests, 0);
        expect(repo.currentPositionRequests, 0);
        expect(repo.positionStreamReads, 0);
      });

      test('restores the persisted environment and Player Position', () async {
        SharedPreferences.setMockInitialValues({
          'desktop_player_position.desktop-test.player-a.lat': 45.9642,
          'desktop_player_position.desktop-test.player-a.lng': -66.6424,
        });
        final prefs = await SharedPreferences.getInstance();
        final repo = ControllableMockLocationRepository();
        final container = await desktopContainer(
          prefs: prefs,
          obs: TestObservabilityService(deploymentEnvironment: 'desktop-test'),
          repo: repo,
          userId: 'player-a',
          enabled: false,
        );
        addTearDown(container.dispose);
        addTearDown(repo.dispose);

        final location =
            (container.read(locationProvider) as LocationProviderActive)
                .location;
        expect(location.lat, 45.9642);
        expect(location.lng, -66.6424);
        expect(location.accuracy, 1.0);
        expect(location.isConfident, isTrue);
        expect(repo.permissionRequests, 0);
        expect(repo.currentPositionRequests, 0);
        expect(repo.positionStreamReads, 0);
      });

      test(
          'moves in metres, clamps coordinates, and persists only when flushed',
          () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repo = ControllableMockLocationRepository();
        final container = await desktopContainer(
          prefs: prefs,
          obs: TestObservabilityService(deploymentEnvironment: 'desktop-test'),
          repo: repo,
          userId: 'player-a',
          enabled: true,
        );
        addTearDown(container.dispose);
        addTearDown(repo.dispose);

        final notifier = container.read(locationProvider.notifier);
        container.read(locationProvider);
        notifier.moveDesktopByMeters(north: 111320.0, east: 111320.0);

        final moved =
            (container.read(locationProvider) as LocationProviderActive)
                .location;
        expect(moved.lat, closeTo(46.9636, 0.000001));
        expect(moved.lng, greaterThan(-66.6431));
        expect(moved.accuracy, 1.0);
        expect(moved.isConfident, isTrue);
        expect(
          prefs
              .containsKey('desktop_player_position.desktop-test.player-a.lat'),
          isFalse,
        );

        notifier.moveDesktopByMeters(north: 1e12, east: 1e12);
        final clamped =
            (container.read(locationProvider) as LocationProviderActive)
                .location;
        expect(clamped.lat, 85.0);
        expect(clamped.lng, 180.0);

        await notifier.persistDesktopPosition();
        expect(
          prefs.getDouble('desktop_player_position.desktop-test.player-a.lat'),
          85.0,
        );
        expect(
          prefs.getDouble('desktop_player_position.desktop-test.player-a.lng'),
          180.0,
        );
      });

      test('does not move while Desktop Mode is disabled', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repo = ControllableMockLocationRepository();
        final container = await desktopContainer(
          prefs: prefs,
          obs: TestObservabilityService(deploymentEnvironment: 'desktop-test'),
          repo: repo,
          userId: 'player-a',
          enabled: false,
        );
        addTearDown(container.dispose);
        addTearDown(repo.dispose);

        final initial = container.read(locationProvider);
        container
            .read(locationProvider.notifier)
            .moveDesktopByMeters(north: 50.0, east: 50.0);
        expect(container.read(locationProvider), same(initial));
      });

      test('keeps persisted Player Positions isolated by account', () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final obs =
            TestObservabilityService(deploymentEnvironment: 'desktop-test');
        final firstRepo = ControllableMockLocationRepository();
        final first = await desktopContainer(
          prefs: prefs,
          obs: obs,
          repo: firstRepo,
          userId: 'player-a',
          enabled: true,
        );
        addTearDown(first.dispose);
        addTearDown(firstRepo.dispose);
        first.read(locationProvider);
        first
            .read(locationProvider.notifier)
            .moveDesktopByMeters(north: 100.0, east: 0.0);
        await first.read(locationProvider.notifier).persistDesktopPosition();

        final secondRepo = ControllableMockLocationRepository();
        final second = await desktopContainer(
          prefs: prefs,
          obs: obs,
          repo: secondRepo,
          userId: 'player-b',
          enabled: true,
        );
        addTearDown(second.dispose);
        addTearDown(secondRepo.dispose);

        final secondLocation =
            (second.read(locationProvider) as LocationProviderActive).location;
        expect(secondLocation.lat, 45.9636);
        expect(secondLocation.lng, -66.6431);
      });
    });
  });
}
