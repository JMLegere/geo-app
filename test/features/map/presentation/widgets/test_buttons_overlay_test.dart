import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/observability/observable_use_case_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/entities/map_level.dart';
import 'package:earth_nova/features/map/domain/repositories/location_repository.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_level_provider.dart';
import 'package:earth_nova/features/map/presentation/widgets/test_buttons_overlay.dart';

class _FakeObservability extends ObservabilityService {
  _FakeObservability() : super(sessionId: 'test');
}

class _FakeLocationRepository implements LocationRepository {
  final _controller = StreamController<LocationState>.broadcast();

  @override
  Stream<LocationState> get positionStream => _controller.stream;

  @override
  Future<LocationState> getCurrentPosition({String? traceId}) async =>
      LocationState(
        lat: 0,
        lng: 0,
        accuracy: 10,
        timestamp: DateTime(2026),
        isConfident: true,
      );

  @override
  Future<bool> requestPermission({String? traceId}) async => true;

  void dispose() => _controller.close();
}

ProviderContainer _makeContainer(_FakeLocationRepository repo) {
  final obs = _FakeObservability();
  return ProviderContainer(
    overrides: [
      mapLevelObservabilityProvider.overrideWithValue(obs),
      locationObservabilityProvider.overrideWithValue(obs),
      observableUseCaseProvider.overrideWithValue(obs),
      locationRepositoryProvider.overrideWithValue(repo),
    ],
  );
}

Widget _wrap(Widget child, ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('MapLevelNotifier.jumpTo', () {
    test('jumpTo transitions to target level', () {
      final repo = _FakeLocationRepository();
      final container = _makeContainer(repo);
      addTearDown(() {
        container.dispose();
        repo.dispose();
      });

      final notifier = container.read(mapLevelProvider.notifier);
      notifier.jumpTo(MapLevel.district);

      expect(container.read(mapLevelProvider), MapLevel.district);
    });

    test('jumpTo is no-op when already at target level', () {
      final repo = _FakeLocationRepository();
      final container = _makeContainer(repo);
      addTearDown(() {
        container.dispose();
        repo.dispose();
      });

      final notifier = container.read(mapLevelProvider.notifier);
      notifier.pinchClose();
      expect(container.read(mapLevelProvider), MapLevel.district);

      notifier.jumpTo(MapLevel.district);
      expect(container.read(mapLevelProvider), MapLevel.district);
    });
  });

  group('TestButtonsOverlay', () {
    testWidgets('renders GPS status row', (tester) async {
      final repo = _FakeLocationRepository();
      final container = _makeContainer(repo);
      addTearDown(() {
        container.dispose();
        repo.dispose();
      });

      await tester.pumpWidget(_wrap(const TestButtonsOverlay(), container));
      await tester.pump();

      expect(find.text('GPS'), findsOneWidget);
    });

    testWidgets('renders level status row', (tester) async {
      final repo = _FakeLocationRepository();
      final container = _makeContainer(repo);
      addTearDown(() {
        container.dispose();
        repo.dispose();
      });

      await tester.pumpWidget(_wrap(const TestButtonsOverlay(), container));
      await tester.pump();

      expect(find.text('Level'), findsOneWidget);
    });

    testWidgets('debug_level_root button is present', (tester) async {
      final repo = _FakeLocationRepository();
      final container = _makeContainer(repo);
      addTearDown(() {
        container.dispose();
        repo.dispose();
      });

      await tester.pumpWidget(_wrap(const TestButtonsOverlay(), container));
      await tester.pump();

      expect(find.byKey(const Key('debug_level_root')), findsOneWidget);
    });

    testWidgets('tapping debug_level_root calls jumpTo(MapLevel.cell)',
        (tester) async {
      final repo = _FakeLocationRepository();
      final container = _makeContainer(repo);
      addTearDown(() {
        container.dispose();
        repo.dispose();
      });

      final notifier = container.read(mapLevelProvider.notifier);
      notifier.pinchClose();
      expect(container.read(mapLevelProvider), MapLevel.district);

      await tester.pumpWidget(_wrap(const TestButtonsOverlay(), container));
      await tester.pump();
      await tester.tap(find.byKey(const Key('debug_level_root')));
      await tester.pump();

      expect(container.read(mapLevelProvider), MapLevel.cell);
    });
  });
}
