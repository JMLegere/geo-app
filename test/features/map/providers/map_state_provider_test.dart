import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/features/map/providers/map_state_provider.dart';

void main() {
  group('MapState', () {
    // -------------------------------------------------------------------------
    // Value equality
    // -------------------------------------------------------------------------

    test('two identical MapStates are equal', () {
      const a = MapState(isReady: false, zoom: 15.0);
      const b = MapState(isReady: false, zoom: 15.0);
      expect(a, equals(b));
    });

    test('MapStates with different isReady are not equal', () {
      const a = MapState(isReady: false, zoom: 15.0);
      const b = MapState(isReady: true, zoom: 15.0);
      expect(a, isNot(equals(b)));
    });

    test('MapStates with different zoom are not equal', () {
      const a = MapState(isReady: false, zoom: 13.0);
      const b = MapState(isReady: false, zoom: 15.0);
      expect(a, isNot(equals(b)));
    });

    // -------------------------------------------------------------------------
    // copyWith
    // -------------------------------------------------------------------------

    test('copyWith preserves unchanged fields', () {
      const original = MapState(
        isReady: true,
        zoom: 15.0,
        cameraLat: 37.7749,
        cameraLon: -122.4194,
      );

      final copy = original.copyWith(zoom: 16.0);

      expect(copy.isReady, equals(true));
      expect(copy.cameraLat, equals(37.7749));
      expect(copy.cameraLon, equals(-122.4194));
      expect(copy.zoom, equals(16.0));
    });

    test('copyWith can update isReady', () {
      const original = MapState(isReady: false, zoom: 15.0);
      final ready = original.copyWith(isReady: true);
      expect(ready.isReady, isTrue);
      expect(ready.zoom, equals(15.0));
    });

    test('copyWith can update camera position', () {
      const original = MapState(isReady: true, zoom: 15.0);
      final withCamera = original.copyWith(cameraLat: 51.5, cameraLon: -0.1);
      expect(withCamera.cameraLat, equals(51.5));
      expect(withCamera.cameraLon, equals(-0.1));
      expect(withCamera.isReady, isTrue);
    });
  });

  group('MapStateNotifier', () {
    // -------------------------------------------------------------------------
    // Initial state
    // -------------------------------------------------------------------------

    test('initial state has isReady = false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(mapStateProvider);
      expect(state.isReady, isFalse);
    });

    test('initial state has default zoom of 15.0', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(mapStateProvider);
      expect(state.zoom, equals(15.0));
    });

    test('initial state has null camera position', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(mapStateProvider);
      expect(state.cameraLat, isNull);
      expect(state.cameraLon, isNull);
    });

    // -------------------------------------------------------------------------
    // markReady
    // -------------------------------------------------------------------------

    test('markReady sets isReady to true', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(mapStateProvider.notifier).markReady();

      expect(container.read(mapStateProvider).isReady, isTrue);
    });

    test('markReady does not change other fields', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Set camera first.
      container.read(mapStateProvider.notifier).updateCameraPosition(37.7, -122.4);
      container.read(mapStateProvider.notifier).updateZoom(16.0);

      container.read(mapStateProvider.notifier).markReady();

      final state = container.read(mapStateProvider);
      expect(state.cameraLat, equals(37.7));
      expect(state.cameraLon, equals(-122.4));
      expect(state.zoom, equals(16.0));
    });

    // -------------------------------------------------------------------------
    // updateCameraPosition
    // -------------------------------------------------------------------------

    test('updateCameraPosition sets cameraLat and cameraLon', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(mapStateProvider.notifier).updateCameraPosition(51.5074, -0.1278);

      final state = container.read(mapStateProvider);
      expect(state.cameraLat, equals(51.5074));
      expect(state.cameraLon, equals(-0.1278));
    });

    test('updateCameraPosition does not change isReady or zoom', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(mapStateProvider.notifier).markReady();

      container.read(mapStateProvider.notifier).updateCameraPosition(48.8566, 2.3522);

      final state = container.read(mapStateProvider);
      expect(state.isReady, isTrue);
      expect(state.zoom, equals(15.0)); // default
    });

    test('updateCameraPosition can be called multiple times', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(mapStateProvider.notifier).updateCameraPosition(10.0, 20.0);
      container.read(mapStateProvider.notifier).updateCameraPosition(11.0, 21.0);

      final state = container.read(mapStateProvider);
      expect(state.cameraLat, equals(11.0));
      expect(state.cameraLon, equals(21.0));
    });

    // -------------------------------------------------------------------------
    // updateZoom
    // -------------------------------------------------------------------------

    test('updateZoom changes zoom level', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(mapStateProvider.notifier).updateZoom(13.5);

      expect(container.read(mapStateProvider).zoom, equals(13.5));
    });

    test('updateZoom does not change isReady or camera position', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(mapStateProvider.notifier).markReady();
      container.read(mapStateProvider.notifier).updateCameraPosition(37.7, -122.4);
      container.read(mapStateProvider.notifier).updateZoom(14.0);

      final state = container.read(mapStateProvider);
      expect(state.isReady, isTrue);
      expect(state.cameraLat, equals(37.7));
      expect(state.zoom, equals(14.0));
    });

    // -------------------------------------------------------------------------
    // reset
    // -------------------------------------------------------------------------

    test('reset returns state to initial values', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Mutate state.
      container.read(mapStateProvider.notifier).markReady();
      container.read(mapStateProvider.notifier).updateCameraPosition(10.0, 20.0);
      container.read(mapStateProvider.notifier).updateZoom(16.0);

      container.read(mapStateProvider.notifier).reset();

      final state = container.read(mapStateProvider);
      expect(state.isReady, isFalse);
      expect(state.cameraLat, isNull);
      expect(state.cameraLon, isNull);
      expect(state.zoom, equals(15.0));
    });

    // -------------------------------------------------------------------------
    // Reactive updates
    // -------------------------------------------------------------------------

    test('provider emits new state on each mutation', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final states = <MapState>[];
      container.listen(mapStateProvider, (_, state) => states.add(state));

      container.read(mapStateProvider.notifier).markReady();
      container.read(mapStateProvider.notifier).updateCameraPosition(37.7, -122.4);
      container.read(mapStateProvider.notifier).updateZoom(16.0);

      expect(states.length, equals(3));
      expect(states[0].isReady, isTrue);
      expect(states[1].cameraLat, equals(37.7));
      expect(states[2].zoom, equals(16.0));
    });
  });
}
