import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observable_use_case_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/repositories/cell_repository.dart';
import 'package:earth_nova/features/map/domain/use_cases/fetch_nearby_cells.dart';
import 'package:earth_nova/features/map/domain/use_cases/get_visited_cells.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';

sealed class MapState {
  const MapState();
}

class MapStateLoading extends MapState {
  const MapStateLoading();
}

class MapStateReady extends MapState {
  const MapStateReady({
    required this.cells,
    required this.visitedCellIds,
    required this.location,
  });

  final List<Cell> cells;
  final Set<String> visitedCellIds;
  final LocationState location;
}

class MapStateError extends MapState {
  const MapStateError(this.message);
  final String message;
}

final mapObservabilityProvider = Provider<ObservabilityService>((ref) {
  throw UnimplementedError('Must be overridden with overrideWithValue');
});

final cellRepositoryProvider = Provider<CellRepository>((ref) {
  throw UnimplementedError('Must be overridden with overrideWithValue');
});

final fetchNearbyCellsProvider = Provider<FetchNearbyCells>(
  (ref) {
    ref.watch(observableUseCaseProvider);
    return FetchNearbyCells(ref.watch(cellRepositoryProvider));
  },
);

final getVisitedCellsProvider = Provider<GetVisitedCells>(
  (ref) {
    ref.watch(observableUseCaseProvider);
    return GetVisitedCells(ref.watch(cellRepositoryProvider));
  },
);

final mapProvider = NotifierProvider<MapNotifier, MapState>(MapNotifier.new);

const _kFetchRadiusMeters = 2000.0;
const _kRefetchThresholdMeters = 500.0;

class MapNotifier extends ObservableNotifier<MapState> {
  LocationState? _lastFetchPosition;

  @override
  ObservabilityService get obs => ref.watch(mapObservabilityProvider);

  @override
  String get category => 'map';

  @override
  MapState build() {
    ref.listen<LocationProviderState>(
      locationProvider,
      (_, next) {
        if (next is LocationProviderActive) {
          _onLocationUpdate(next.location);
          return;
        }

        if (next case LocationProviderError(message: final message)) {
          transition(MapStateError(message), 'map.data_fetch_error');
          return;
        }

        if (next is LocationProviderPermissionDenied) {
          transition(
            const MapStateError('Location permission denied'),
            'map.data_fetch_error',
          );
        }
      },
    );

    final currentLocation = ref.read(locationProvider);
    if (currentLocation is LocationProviderActive) {
      Future.microtask(() => _onLocationUpdate(currentLocation.location));
    }

    return const MapStateLoading();
  }

  void setZoom(double zoom) {
    obs.log('map.zoom_changed', category, data: {'zoom': zoom});
  }

  Future<void> _onLocationUpdate(LocationState location) async {
    if (!_shouldRefetch(location)) return;
    _lastFetchPosition = location;

    transition(const MapStateLoading(), 'map.cells_fetch_started', data: {
      'lat': location.lat,
      'lng': location.lng,
      'radius_meters': _kFetchRadiusMeters,
    });

    try {
      final fetchCells = ref.read(fetchNearbyCellsProvider);
      final getVisited = ref.read(getVisitedCellsProvider);
      final authState = ref.read(authProvider);
      final userId = authState.status == AuthStatus.authenticated
          ? authState.user!.id
          : '';

      final results = await Future.wait([
        fetchCells.call(
          (
            lat: location.lat,
            lng: location.lng,
            radiusMeters: _kFetchRadiusMeters,
          ),
        ),
        getVisited.call((userId: userId)),
      ]);

      final cells = results[0] as List<Cell>;
      final visitedIds = results[1] as Set<String>;

      final withPolygon = cells.where((c) => c.polygon.isNotEmpty).length;
      transition(
        MapStateReady(
          cells: cells,
          visitedCellIds: visitedIds,
          location: location,
        ),
        'map.cells_fetch_complete',
        data: {
          'total_cells': cells.length,
          'cells_with_polygon': withPolygon,
          'cells_without_polygon': cells.length - withPolygon,
          'visited_count': visitedIds.length,
        },
      );
    } catch (e, stack) {
      obs.logError(e, stack, event: 'map.data_fetch_error');
      transition(MapStateError(e.toString()), 'map.cells_fetch_error', data: {
        'error': e.toString(),
      });
    }
  }

  bool _shouldRefetch(LocationState location) {
    final last = _lastFetchPosition;
    if (last == null) return true;
    final dist = _haversineMeters(
      last.lat,
      last.lng,
      location.lat,
      location.lng,
    );
    return dist >= _kRefetchThresholdMeters;
  }

  double _haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  double _toRad(double deg) => deg * pi / 180;
}
