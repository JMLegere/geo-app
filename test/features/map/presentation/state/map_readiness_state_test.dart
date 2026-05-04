import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/map/presentation/state/map_readiness_state.dart';

void main() {
  group('MapReadinessState', () {
    test('is not steady-state ready until every milestone is true', () {
      const state = MapReadinessState(
        locationReady: true,
        mapCreated: true,
        styleLoaded: true,
        baseMapSettled: true,
        cellsFetched: true,
        overlayFramePainted: false,
      );

      expect(state.isSteadyStateReady, isFalse);
      expect(state.waitingFor, ['overlay_frame_painted']);
    });

    test('is steady-state ready only after map, data, and overlay are ready',
        () {
      const state = MapReadinessState(
        locationReady: true,
        mapCreated: true,
        styleLoaded: true,
        baseMapSettled: true,
        cellsFetched: true,
        overlayFramePainted: true,
      );

      expect(state.isSteadyStateReady, isTrue);
      expect(state.waitingFor, isEmpty);
    });

    test('log payload names every readiness milestone', () {
      const state = MapReadinessState.initial();

      expect(state.toLogData(), containsPair('location_ready', false));
      expect(state.toLogData(), containsPair('map_created', false));
      expect(state.toLogData(), containsPair('style_loaded', false));
      expect(state.toLogData(), containsPair('base_map_settled', false));
      expect(state.toLogData(), containsPair('cells_fetched', false));
      expect(state.toLogData(), containsPair('overlay_frame_painted', false));
      expect(state.toLogData(), containsPair('steady_state_ready', false));
      expect(
        state.toLogData()['waiting_for'],
        [
          'location',
          'map_created',
          'style_loaded',
          'base_map_settled',
          'cells_fetched',
          'overlay_frame_painted',
        ],
      );
    });
  });
}
