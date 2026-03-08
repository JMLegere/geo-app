import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/features/map/controllers/camera_controller.dart';

/// Provides the [CameraController] for map follow/free mode logic.
///
/// Plain Dart class — no lifecycle management needed. The map screen wires
/// [CameraController.onCameraMove] to the MapLibre controller in onMapCreated.
final cameraControllerProvider = Provider<CameraController>((ref) {
  return CameraController();
});
