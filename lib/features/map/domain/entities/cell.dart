import 'dart:ui';

import 'package:earth_nova/core/domain/entities/habitat.dart';

typedef GeoCoord = ({double lat, double lng});

class Cell {
  const Cell({
    required this.id,
    required this.habitats,
    required this.polygon,
    required this.districtId,
    required this.cityId,
    required this.stateId,
    required this.countryId,
  });

  final String id;
  final List<Habitat> habitats;
  final List<GeoCoord> polygon;
  final String districtId;
  final String cityId;
  final String stateId;
  final String countryId;

  Color get blendedColor => Habitat.blendHabitats(habitats);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cell &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          _listEquals(habitats, other.habitats) &&
          _geoCoordListEquals(polygon, other.polygon) &&
          districtId == other.districtId &&
          cityId == other.cityId &&
          stateId == other.stateId &&
          countryId == other.countryId;

  @override
  int get hashCode => Object.hashAll([
        id,
        habitats.join(','),
        polygon.map((p) => '${p.lat},${p.lng}').join(';'),
        districtId,
        cityId,
        stateId,
        countryId,
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
