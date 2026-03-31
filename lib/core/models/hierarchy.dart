import 'package:flutter/foundation.dart';

import 'package:geobase/geobase.dart';

import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/features/map/models/district_infographic_data.dart';

/// A country in the geographic hierarchy.
@immutable
class HCountry {
  final String id;
  final String name;
  final double centroidLat;
  final double centroidLon;
  final String continent;
  final String? boundaryJson;

  const HCountry({
    required this.id,
    required this.name,
    required this.centroidLat,
    required this.centroidLon,
    required this.continent,
    this.boundaryJson,
  });

  factory HCountry.fromDrift(LocalCountry row) => HCountry(
        id: row.id,
        name: row.name,
        centroidLat: row.centroidLat,
        centroidLon: row.centroidLon,
        continent: row.continent,
        boundaryJson: row.boundaryJson,
      );

  /// Parse boundary rings from GeoJSON (reuses existing parser).
  List<List<Geographic>> get boundaryRings =>
      DistrictInfographicData.parseBoundaryRings(boundaryJson);
}

/// A state/province in the geographic hierarchy.
@immutable
class HState {
  final String id;
  final String name;
  final double centroidLat;
  final double centroidLon;
  final String countryId;
  final String? boundaryJson;

  const HState({
    required this.id,
    required this.name,
    required this.centroidLat,
    required this.centroidLon,
    required this.countryId,
    this.boundaryJson,
  });

  factory HState.fromDrift(LocalState row) => HState(
        id: row.id,
        name: row.name,
        centroidLat: row.centroidLat,
        centroidLon: row.centroidLon,
        countryId: row.countryId,
        boundaryJson: row.boundaryJson,
      );

  List<List<Geographic>> get boundaryRings =>
      DistrictInfographicData.parseBoundaryRings(boundaryJson);
}

/// A city/locality in the geographic hierarchy.
@immutable
class HCity {
  final String id;
  final String name;
  final double centroidLat;
  final double centroidLon;
  final String stateId;
  final String? boundaryJson;
  final int? cellsTotal;

  const HCity({
    required this.id,
    required this.name,
    required this.centroidLat,
    required this.centroidLon,
    required this.stateId,
    this.boundaryJson,
    this.cellsTotal,
  });

  factory HCity.fromDrift(LocalCity row) => HCity(
        id: row.id,
        name: row.name,
        centroidLat: row.centroidLat,
        centroidLon: row.centroidLon,
        stateId: row.stateId,
        boundaryJson: row.boundaryJson,
        cellsTotal: row.cellsTotal,
      );

  List<List<Geographic>> get boundaryRings =>
      DistrictInfographicData.parseBoundaryRings(boundaryJson);
}

/// A district/neighbourhood in the geographic hierarchy.
@immutable
class HDistrict {
  final String id;
  final String name;
  final double centroidLat;
  final double centroidLon;
  final String cityId;
  final String? boundaryJson;
  final int? cellsTotal;
  final String source;
  final String? sourceId;

  const HDistrict({
    required this.id,
    required this.name,
    required this.centroidLat,
    required this.centroidLon,
    required this.cityId,
    this.boundaryJson,
    this.cellsTotal,
    this.source = 'whosonfirst',
    this.sourceId,
  });

  factory HDistrict.fromDrift(LocalDistrict row) => HDistrict(
        id: row.id,
        name: row.name,
        centroidLat: row.centroidLat,
        centroidLon: row.centroidLon,
        cityId: row.cityId,
        boundaryJson: row.boundaryJson,
        cellsTotal: row.cellsTotal,
        source: row.source,
        sourceId: row.sourceId,
      );

  List<List<Geographic>> get boundaryRings =>
      DistrictInfographicData.parseBoundaryRings(boundaryJson);
}
