import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/core/observability/observable_use_case_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/map/data/repositories/mock_cell_repository.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/repositories/location_repository.dart';
import 'package:earth_nova/features/map/presentation/providers/exploration_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';

class _FakeLocationRepository implements LocationRepository {
  @override
  Stream<LocationState> get positionStream => const Stream.empty();

  @override
  Future<LocationState> getCurrentPosition({String? traceId}) async =>
      LocationState(
        lat: 0,
        lng: 0,
        accuracy: 1,
        timestamp: DateTime(2026),
        isConfident: true,
      );

  @override
  Future<bool> requestPermission({String? traceId}) async => true;
}

void main() {
  test('use case providers require observableUseCaseProvider override', () {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(MockAuthRepository()),
        cellRepositoryProvider.overrideWithValue(MockCellRepository()),
        locationRepositoryProvider.overrideWithValue(_FakeLocationRepository()),
      ],
    );

    final missingOverrideError = predicate<Object>(
      (error) => error
          .toString()
          .contains('Must be overridden with overrideWithValue'),
    );

    expect(() => container.read(signInWithPhoneProvider),
        throwsA(missingOverrideError));
    expect(
      () => container.read(signOutProvider),
      throwsA(missingOverrideError),
    );
    expect(
      () => container.read(restoreSessionProvider),
      throwsA(missingOverrideError),
    );
    expect(
      () => container.read(fetchNearbyCellsProvider),
      throwsA(missingOverrideError),
    );
    expect(
      () => container.read(getVisitedCellsProvider),
      throwsA(missingOverrideError),
    );
    expect(
      () => container.read(recordCellVisitProvider),
      throwsA(missingOverrideError),
    );
    expect(
      () => container.read(getLocationStreamProvider),
      throwsA(missingOverrideError),
    );

    container.dispose();
  });

  test('use case providers are readable when observableUseCaseProvider is set',
      () {
    final obs = ObservabilityService(sessionId: 'test-session');
    final container = ProviderContainer(
      overrides: [
        observableUseCaseProvider.overrideWithValue(obs),
        authRepositoryProvider.overrideWithValue(MockAuthRepository()),
        cellRepositoryProvider.overrideWithValue(MockCellRepository()),
        locationRepositoryProvider.overrideWithValue(_FakeLocationRepository()),
        // Override feature-specific observability providers
        observabilityProvider.overrideWithValue(obs),
        mapObservabilityProvider.overrideWithValue(obs),
        explorationObservabilityProvider.overrideWithValue(obs),
        locationObservabilityProvider.overrideWithValue(obs),
      ],
    );

    expect(container.read(signInWithPhoneProvider), isNotNull);
    expect(container.read(signOutProvider), isNotNull);
    expect(container.read(restoreSessionProvider), isNotNull);
    expect(container.read(fetchNearbyCellsProvider), isNotNull);
    expect(container.read(getVisitedCellsProvider), isNotNull);
    expect(container.read(recordCellVisitProvider), isNotNull);
    expect(container.read(getLocationStreamProvider), isNotNull);

    container.dispose();
  });
}
