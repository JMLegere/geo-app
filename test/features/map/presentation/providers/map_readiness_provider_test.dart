import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';

import 'package:earth_nova/features/map/presentation/providers/map_readiness_provider.dart';

void main() {
  ProviderContainer container() {
    final result = ProviderContainer(
      overrides: [
        appObservabilityProvider.overrideWithValue(
          ObservabilityService(sessionId: 'map-readiness-test'),
        ),
      ],
    );
    addTearDown(result.dispose);
    return result;
  }

  group('MapReadinessNotifier', () {
    test('reaches steady state only after ordered required milestones', () {
      final scope = container();
      final readiness = scope.read(mapReadinessProvider.notifier);

      readiness.start();
      readiness.reportOverlayFramePainted(hasMeaningfulContent: true);
      readiness.reportCellsFetched(true);
      readiness.reportLocationReady(true);
      readiness.reportMapCreated();
      readiness.reportStyleLoaded();
      readiness.reportBaseMapSettled(source: 'map_idle');

      expect(scope.read(mapReadinessProvider).overlayFramePainted, isFalse);

      readiness.reportOverlayFramePainted(hasMeaningfulContent: true);

      expect(scope.read(mapReadinessProvider).isSteadyStateReady, isTrue);
    });

    test('rejects an overlay frame without meaningful map content', () {
      final scope = container();
      final readiness = scope.read(mapReadinessProvider.notifier);

      readiness.start();
      readiness.reportLocationReady(true);
      readiness.reportMapCreated();
      readiness.reportStyleLoaded();
      readiness.reportCellsFetched(true);
      readiness.reportBaseMapSettled(source: 'map_idle');

      expect(
        readiness.reportOverlayFramePainted(hasMeaningfulContent: false),
        isFalse,
      );
      expect(scope.read(mapReadinessProvider).isSteadyStateReady, isFalse);
    });

    test('reset clears every milestone', () {
      final scope = container();
      final readiness = scope.read(mapReadinessProvider.notifier);

      readiness.start();
      readiness.reportLocationReady(true);
      readiness.reportMapCreated();
      readiness.reportStyleLoaded();
      readiness.reportCellsFetched(true);
      readiness.reportBaseMapSettled(source: 'map_idle');
      readiness.reportOverlayFramePainted(hasMeaningfulContent: true);
      readiness.reset();

      final state = scope.read(mapReadinessProvider);
      expect(state.isSteadyStateReady, isFalse);
      expect(state.waitingFor, hasLength(6));
      expect(state.bootstrapTimedOut, isFalse);
    });

    testWidgets('settles the base map through the five-second fallback', (
      tester,
    ) async {
      final scope = container();
      final readiness = scope.read(mapReadinessProvider.notifier);

      readiness.start();
      readiness.reportMapCreated();
      readiness.reportStyleLoaded();
      readiness.reportCellsFetched(true);
      await tester.pump(kBaseMapSettledFallbackDelay);

      final state = scope.read(mapReadinessProvider);
      expect(state.baseMapSettled, isTrue);
      expect(state.baseMapSettledSource, 'style_loaded_fallback');
      readiness.reset();
    });

    testWidgets('marks an incomplete bootstrap after twelve seconds', (
      tester,
    ) async {
      final scope = container();

      scope.read(mapReadinessProvider.notifier).start();
      await tester.pump(kMapBootstrapTimeout);

      expect(scope.read(mapReadinessProvider).bootstrapTimedOut, isTrue);
    });

    testWidgets(
      'ignores cancelled fallback callbacks after reset and disposal',
      (tester) async {
        final scope = ProviderContainer(
          overrides: [
            appObservabilityProvider.overrideWithValue(
              ObservabilityService(sessionId: 'map-readiness-test'),
            ),
          ],
        );
        final readiness = scope.read(mapReadinessProvider.notifier);

        readiness.start();
        readiness.reportStyleLoaded();
        readiness.reset();
        await tester.pump(kBaseMapSettledFallbackDelay);
        expect(scope.read(mapReadinessProvider).baseMapSettled, isFalse);

        readiness.start();
        readiness.reportStyleLoaded();
        scope.dispose();
        await tester.pump(kMapBootstrapTimeout);
      },
    );
  });
}
