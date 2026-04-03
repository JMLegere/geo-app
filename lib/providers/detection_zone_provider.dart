import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/domain/cells/detection_zone_service.dart';
import 'package:earth_nova/providers/cell_provider.dart';

final detectionZoneProvider = Provider<DetectionZoneService>((ref) {
  final cellService = ref.watch(cellServiceProvider);
  final service = DetectionZoneService(cellService: cellService);
  ref.onDispose(service.dispose);
  return service;
});
