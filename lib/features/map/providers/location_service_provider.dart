import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/features/location/services/location_service.dart';

/// Provides the [LocationService] for GPS/simulation location updates.
///
/// The service is created but NOT auto-started. The map screen calls
/// [LocationService.start] and [LocationService.stop] to control the
/// tracking lifecycle — this way tracking only runs when the map is visible.
final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService();
  ref.onDispose(() => service.dispose());
  return service;
});
