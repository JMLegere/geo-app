import 'dart:js_interop';

import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/player_marker_state.dart';
import 'package:earth_nova/ui/product_surfaces/map/rendering/player_marker.dart';
import 'package:earth_nova/ui/product_surfaces/map/rendering/cell_tessellation_render_model.dart';
import 'package:earth_nova/ui/product_surfaces/map/rendering/retained_cell_scene.dart';

@JS('__earthnovaMapLibreMap')
external JSObject? get _activeMap;
@JS('EarthNovaRetainedMapRenderer')
external _RendererApi? get _rendererApi;

@JS()
@staticInterop
class _RendererApi {}

extension _RendererApiMethods on _RendererApi {
  external _RendererHandle? attach(JSObject map);
}

@JS()
@staticInterop
class _RendererHandle {}

extension _RendererHandleMethods on _RendererHandle {
  external JSBoolean get isAttached;
  external set onCellTap(JSFunction callback);
  external JSPromise<JSAny?> updateScene(JSAny? payload);
  external void updatePlayer(JSAny? payload);
  external void updateCameraTarget(JSAny? payload);
  external void dispose();
}

class RetainedMapRenderer {
  RetainedMapRenderer({this.onCellTap});
  void Function(String cellId)? onCellTap;
  final _scene = RetainedCellScene();
  _RendererHandle? _handle;
  bool _disposed = false;

  bool get isAttached => _handle?.isAttached.toDart ?? false;

  Future<bool> attach() async {
    if (_disposed) return false;
    if (isAttached) return true;
    final map = _activeMap;
    final api = _rendererApi;
    if (map == null || api == null) return false;
    final handle = api.attach(map);
    if (handle == null) return false;
    _scene.reset();
    handle.onCellTap = ((JSString id) => onCellTap?.call(id.toDart)).toJS;
    _handle = handle;
    return true;
  }

  Future<void> updateScene(
    List<CellStateEntry> entries, {
    List<Map<String, Object?>> venues = const [],
  }) async {
    final handle = _handle;
    if (handle == null || _disposed) return;
    // No await before encoding/submission: overlapping calls cannot reorder.
    await handle
        .updateScene(_scene.update(entries, venues: venues).jsify())
        .toDart;
  }

  void updatePlayer(
    PlayerMarkerState marker, {
    required PlayerMarkerTrust trust,
  }) {
    if (_disposed) return;
    _handle?.updatePlayer(
      {
        'lat': marker.lat,
        'lng': marker.lng,
        'isRing': marker.isRing,
        'gapDistance': marker.gapDistance,
        'trust': trust.name,
      }.jsify(),
    );
  }

  void updateCameraTarget(GeoCoord target) {
    if (_disposed) return;
    _handle?.updateCameraTarget({'lat': target.lat, 'lng': target.lng}.jsify());
  }

  void dispose() {
    _disposed = true;
    _handle?.dispose();
    _handle = null;
  }
}
