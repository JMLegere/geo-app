import 'dart:convert';

/// Returns MapLibre style layer ids that render text labels.
///
/// A symbol layer can render icons only, text only, or both. EarthNova keeps
/// icon-only map symbols available, but hides any symbol layer with a
/// `text-field` layout property so base-map cartography does not compete with
/// the fog and map-cell mosaic.
List<String> baseMapTextLabelLayerIdsFromStyle(String styleJson) {
  final Object? decoded;
  try {
    decoded = jsonDecode(styleJson);
  } catch (_) {
    return const [];
  }

  if (decoded is! Map<String, Object?>) return const [];
  final layers = decoded['layers'];
  if (layers is! List<Object?>) return const [];

  final layerIds = <String>[];
  for (final layer in layers) {
    if (layer is! Map<String, Object?>) continue;
    if (layer['type'] != 'symbol') continue;

    final layout = layer['layout'];
    if (layout is! Map<String, Object?>) continue;
    if (!layout.containsKey('text-field')) continue;

    final id = layer['id'];
    if (id is String && id.isNotEmpty) layerIds.add(id);
  }
  return layerIds;
}
