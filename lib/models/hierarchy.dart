import 'package:earth_nova/data/database.dart';

/// A country in the geographic hierarchy.
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

  factory HCountry.fromDrift(HierarchyCountry row) => HCountry(
        id: row.id,
        name: row.name,
        centroidLat: row.centroidLat,
        centroidLon: row.centroidLon,
        continent: row.continent,
        boundaryJson: row.boundaryJson,
      );
}

/// A state/province in the geographic hierarchy.
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

  factory HState.fromDrift(HierarchyState row) => HState(
        id: row.id,
        name: row.name,
        centroidLat: row.centroidLat,
        centroidLon: row.centroidLon,
        countryId: row.countryId,
        boundaryJson: row.boundaryJson,
      );
}

/// A city/locality in the geographic hierarchy.
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

  factory HCity.fromDrift(HierarchyCity row) => HCity(
        id: row.id,
        name: row.name,
        centroidLat: row.centroidLat,
        centroidLon: row.centroidLon,
        stateId: row.stateId,
        boundaryJson: row.boundaryJson,
        cellsTotal: row.cellsTotal,
      );
}

/// A district/neighbourhood in the geographic hierarchy.
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

  factory HDistrict.fromDrift(HierarchyDistrict row) => HDistrict(
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
}
