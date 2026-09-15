import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/player_marker_state.dart';
import 'package:earth_nova/ui/product_surfaces/map/rendering/player_marker.dart';
import 'package:earth_nova/ui/product_surfaces/map/rendering/cell_tessellation_render_model.dart';

/// Native platforms retain the Flutter painter and their existing controller.
class RetainedMapRenderer {
  RetainedMapRenderer({this.onCellTap});
  void Function(String cellId)? onCellTap;
  bool get isAttached => false;
  Future<bool> attach() async => false;
  Future<void> updateScene(
    List<CellStateEntry> entries, {
    List<Map<String, Object?>> venues = const [],
  }) async {}
  void updatePlayer(
    PlayerMarkerState marker, {
    required PlayerMarkerTrust trust,
  }) {}
  void updateCameraTarget(GeoCoord target) {}
  void dispose() {}
}
