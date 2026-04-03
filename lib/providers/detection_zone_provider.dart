import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/domain/cells/detection_zone_service.dart';
import 'package:earth_nova/providers/cell_provider.dart';
import 'package:earth_nova/providers/hierarchy_provider.dart';

final detectionZoneProvider = Provider<DetectionZoneService>((ref) {
  final cellService = ref.watch(cellServiceProvider);
  final hierarchyRepo = ref.watch(hierarchyRepoProvider);
  final service = DetectionZoneService(cellService: cellService);
  service.districtLoader = () => hierarchyRepo.getAllDistricts();
  ref.onDispose(service.dispose);
  return service;
});
