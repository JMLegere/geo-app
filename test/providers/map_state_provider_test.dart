import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geobase/geobase.dart';

import 'package:earth_nova/providers/map_state_provider.dart';

void main() {
  group('MapStateNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('initial state has null center, default zoom, follow mode on', () {
      final state = container.read(mapStateProvider);
      expect(state.center, isNull);
      expect(state.zoom, 14.0);
      expect(state.selectedCellId, isNull);
      expect(state.followMode, true);
    });

    test('updateCamera sets center and zoom', () {
      final pos = Geographic(lat: 45.0, lon: -73.0);
      container.read(mapStateProvider.notifier).updateCamera(
            center: pos,
            zoom: 16.0,
          );

      final state = container.read(mapStateProvider);
      expect(state.center, pos);
      expect(state.zoom, 16.0);
    });

    test('updateCamera with only center preserves zoom', () {
      container
          .read(mapStateProvider.notifier)
          .updateCamera(center: Geographic(lat: 0, lon: 0), zoom: 10.0);
      container
          .read(mapStateProvider.notifier)
          .updateCamera(center: Geographic(lat: 1, lon: 1));

      final state = container.read(mapStateProvider);
      expect(state.center!.lat, 1.0);
      expect(state.zoom, 10.0);
    });

    test('setZoom changes zoom only', () {
      container.read(mapStateProvider.notifier).setZoom(3.0);
      expect(container.read(mapStateProvider).zoom, 3.0);
    });

    test('selectCell sets selectedCellId', () {
      container.read(mapStateProvider.notifier).selectCell('v_42_17');
      expect(container.read(mapStateProvider).selectedCellId, 'v_42_17');
    });

    test('clearSelectedCell sets selectedCellId to null', () {
      container.read(mapStateProvider.notifier).selectCell('v_42_17');
      container.read(mapStateProvider.notifier).clearSelectedCell();
      expect(container.read(mapStateProvider).selectedCellId, isNull);
    });

    test('setFollowMode toggles follow mode', () {
      container.read(mapStateProvider.notifier).setFollowMode(false);
      expect(container.read(mapStateProvider).followMode, false);

      container.read(mapStateProvider.notifier).setFollowMode(true);
      expect(container.read(mapStateProvider).followMode, true);
    });
  });

  group('MapState.copyWith', () {
    test('clearSelectedCell overrides selectedCellId to null', () {
      const state = MapState(selectedCellId: 'abc');
      final updated = state.copyWith(clearSelectedCell: true);
      expect(updated.selectedCellId, isNull);
    });

    test('copyWith preserves unset fields', () {
      final state = MapState(
        center: Geographic(lat: 1, lon: 2),
        zoom: 10,
        selectedCellId: 'x',
        followMode: false,
      );
      final updated = state.copyWith(zoom: 5);
      expect(updated.center, state.center);
      expect(updated.zoom, 5);
      expect(updated.selectedCellId, 'x');
      expect(updated.followMode, false);
    });
  });
}
