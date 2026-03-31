import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/services/detection_zone_service.dart';
import 'package:earth_nova/core/state/cell_service_provider.dart';
import 'package:earth_nova/core/state/hierarchy_repository_provider.dart';

/// Singleton [DetectionZoneService] for computing the player's detection zone.
final detectionZoneServiceProvider = Provider<DetectionZoneService>((ref) {
  final cellService = ref.watch(cellServiceProvider);
  final hierarchyRepo = ref.watch(hierarchyRepositoryProvider);
  final service = DetectionZoneService(
    cellService: cellService,
    hierarchyRepo: hierarchyRepo,
  );
  ref.onDispose(service.dispose);
  return service;
});
