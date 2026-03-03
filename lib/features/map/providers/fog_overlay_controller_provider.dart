import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fog_of_world/core/state/cell_service_provider.dart';
import 'package:fog_of_world/core/state/fog_resolver_provider.dart';
import 'package:fog_of_world/features/map/controllers/fog_overlay_controller.dart';

/// Provides the [FogOverlayController] for computing fog render data.
///
/// Depends on [cellServiceProvider] and [fogResolverProvider]. Call
/// [FogOverlayController.update] on camera moves and location updates.
final fogOverlayControllerProvider = Provider<FogOverlayController>((ref) {
  final cellService = ref.watch(cellServiceProvider);
  final fogResolver = ref.watch(fogResolverProvider);
  return FogOverlayController(
    cellService: cellService,
    fogResolver: fogResolver,
  );
});
