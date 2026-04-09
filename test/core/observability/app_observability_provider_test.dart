import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';

void main() {
  group('appObservabilityProvider', () {
    test('throws when not overridden', () {
      final container = ProviderContainer();

      final missingOverrideError = predicate<Object>(
        (error) => error
            .toString()
            .contains('Must be overridden with overrideWithValue'),
      );

      expect(
        () => container.read(appObservabilityProvider),
        throwsA(missingOverrideError),
      );

      container.dispose();
    });

    test('returns overridden ObservabilityService instance', () {
      final obs = ObservabilityService(sessionId: 'test-session');
      final container = ProviderContainer(
        overrides: [
          appObservabilityProvider.overrideWithValue(obs),
        ],
      );

      expect(container.read(appObservabilityProvider), same(obs));

      container.dispose();
    });
  });
}
