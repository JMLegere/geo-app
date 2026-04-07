import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/repositories/location_repository.dart';
import 'package:earth_nova/features/map/domain/use_cases/get_location_stream.dart';

sealed class LocationProviderState {
  const LocationProviderState();
}

class LocationProviderLoading extends LocationProviderState {
  const LocationProviderLoading();
}

class LocationProviderActive extends LocationProviderState {
  const LocationProviderActive(this.location);
  final LocationState location;
}

class LocationProviderPermissionDenied extends LocationProviderState {
  const LocationProviderPermissionDenied();
}

class LocationProviderError extends LocationProviderState {
  const LocationProviderError(this.message);
  final String message;
}

final locationObservabilityProvider = Provider<ObservabilityService>((ref) {
  throw UnimplementedError('Must be overridden with overrideWithValue');
});

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  throw UnimplementedError('Must be overridden with overrideWithValue');
});

final getLocationStreamProvider = Provider<GetLocationStream>(
  (ref) => GetLocationStream(ref.watch(locationRepositoryProvider)),
);

final locationProvider =
    NotifierProvider<LocationNotifier, LocationProviderState>(
        LocationNotifier.new);

class LocationNotifier extends ObservableNotifier<LocationProviderState> {
  late final LocationRepository _repository;
  StreamSubscription<LocationState>? _subscription;

  @override
  ObservabilityService get obs => ref.watch(locationObservabilityProvider);

  @override
  String get category => 'map';

  @override
  LocationProviderState build() {
    _repository = ref.watch(locationRepositoryProvider);
    ref.onDispose(() => _subscription?.cancel());
    _start();
    return const LocationProviderLoading();
  }

  Future<void> _start() async {
    transition(const LocationProviderLoading(), 'map.gps_started');

    final granted = await _repository.requestPermission();
    if (!granted) {
      transition(const LocationProviderPermissionDenied(),
          'map.gps_permission_denied');
      return;
    }

    try {
      final initial = await _repository.getCurrentPosition();
      transition(LocationProviderActive(initial), 'map.gps_position_updated');
    } catch (e) {
      transition(LocationProviderError(e.toString()), 'map.gps_error');
      return;
    }

    _subscription = _repository.positionStream.listen(
      (position) {
        transition(
            LocationProviderActive(position), 'map.gps_position_updated');
      },
      onError: (Object e) {
        transition(LocationProviderError(e.toString()), 'map.gps_error');
      },
    );
  }
}
