import 'package:earth_nova/features/map/domain/entities/map_level.dart';

/// Parses a `?level=` query parameter value into a [MapLevel].
/// Returns null for unknown or missing values.
///
/// Used by the debug URL hook in main.dart — extracted here for testability.
/// Only called on web when debug mode is enabled.
MapLevel? debugLevelFromParam(String? param) {
  if (param == null) return null;
  return MapLevel.values.where((l) => l.name == param).firstOrNull;
}
