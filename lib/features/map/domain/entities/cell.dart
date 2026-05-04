import 'dart:ui';

import 'package:earth_nova/core/domain/entities/habitat.dart';

typedef GeoCoord = ({double lat, double lng});
typedef GeoRing = List<GeoCoord>;
typedef GeoPolygon = List<GeoRing>;
typedef GeoMultiPolygon = List<GeoPolygon>;

class Cell {
  const Cell({
    required this.id,
    required this.habitats,
    required this.polygons,
    required this.districtId,
    required this.cityId,
    required this.stateId,
    required this.countryId,
    this.geometrySourceVersion = '',
    this.geometryGenerationMode = '',
    this.centroidDatasetVersion = '',
    this.geometryContract = '',
  });

  final String id;
  final List<Habitat> habitats;
  final GeoMultiPolygon polygons;
  final String districtId;
  final String cityId;
  final String stateId;
  final String countryId;
  final String geometrySourceVersion;
  final String geometryGenerationMode;
  final String centroidDatasetVersion;
  final String geometryContract;

  bool get hasRenderableGeometry => polygons.any(
        (polygon) => polygon.isNotEmpty && polygon.first.length >= 3,
      );

  GeoRing get primaryExteriorRing {
    for (final polygon in polygons) {
      if (polygon.isNotEmpty && polygon.first.length >= 3) {
        return polygon.first;
      }
    }
    return const [];
  }

  List<GeoCoord> get exteriorPoints => [
        for (final polygon in polygons)
          if (polygon.isNotEmpty) ...polygon.first,
      ];

  Color get blendedColor => Habitat.blendHabitats(habitats);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cell &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          _listEquals(habitats, other.habitats) &&
          _multiPolygonEquals(polygons, other.polygons) &&
          districtId == other.districtId &&
          cityId == other.cityId &&
          stateId == other.stateId &&
          countryId == other.countryId &&
          geometrySourceVersion == other.geometrySourceVersion &&
          geometryGenerationMode == other.geometryGenerationMode &&
          centroidDatasetVersion == other.centroidDatasetVersion &&
          geometryContract == other.geometryContract;

  @override
  int get hashCode => Object.hashAll([
        id,
        habitats.join(','),
        polygons
            .map(
              (polygon) => polygon
                  .map(
                    (ring) => ring.map((p) => '${p.lat},${p.lng}').join(';'),
                  )
                  .join('|'),
            )
            .join('||'),
        districtId,
        cityId,
        stateId,
        countryId,
        geometrySourceVersion,
        geometryGenerationMode,
        centroidDatasetVersion,
        geometryContract,
      ]);
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _geoCoordListEquals(List<GeoCoord> a, List<GeoCoord> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].lat != b[i].lat || a[i].lng != b[i].lng) return false;
  }
  return true;
}

bool _polygonEquals(GeoPolygon a, GeoPolygon b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!_geoCoordListEquals(a[i], b[i])) return false;
  }
  return true;
}

bool _multiPolygonEquals(GeoMultiPolygon a, GeoMultiPolygon b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!_polygonEquals(a[i], b[i])) return false;
  }
  return true;
}
