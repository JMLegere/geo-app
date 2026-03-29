import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/features/map/controllers/camera_bounds_controller.dart';

/// Provides the [CameraBoundsController] singleton.
///
/// The controller computes camera bounds from detection zone district
/// centroids and enforces them via smooth clamping.
final cameraBoundsProvider = Provider<CameraBoundsController>((ref) {
  return CameraBoundsController();
});
