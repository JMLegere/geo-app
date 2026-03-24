import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/services/detection_zone_service.dart';
import 'package:earth_nova/core/state/cell_service_provider.dart';
import 'package:earth_nova/core/state/location_node_repository_provider.dart';

/// Singleton provider for [DetectionZoneService].
///
/// Computes the detection zone (current district + adjacent districts)
/// and exposes it as a stream for [FogStateResolver] integration.
final detectionZoneServiceProvider = Provider<DetectionZoneService>((ref) {
  final cellService = ref.watch(cellServiceProvider);
  final locationNodeRepo = ref.watch(locationNodeRepositoryProvider);
  final service = DetectionZoneService(
    cellService: cellService,
    locationNodeRepo: locationNodeRepo,
  );
  ref.onDispose(service.dispose);
  return service;
});
