import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';

class CellDto {
  const CellDto({
    required this.cellId,
    required this.habitats,
    required this.polygons,
    required this.districtId,
    required this.cityId,
    required this.stateId,
    required this.countryId,
    required this.geometrySourceVersion,
    required this.geometryGenerationMode,
    required this.centroidDatasetVersion,
    required this.geometryContract,
    required this.habitatSourceVersion,
    required this.habitatConfidence,
  });

  final String cellId;
  final List<String> habitats;
  final List<List<List<Map<String, double>>>> polygons;
  final String districtId;
  final String cityId;
  final String stateId;
  final String countryId;
  final String geometrySourceVersion;
  final String geometryGenerationMode;
  final String centroidDatasetVersion;
  final String geometryContract;
  final String habitatSourceVersion;
  final String habitatConfidence;

  factory CellDto.fromJson(Map<String, dynamic> json) => CellDto(
        cellId: json['cell_id'] as String,
        habitats: (json['habitats'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        polygons: _parsePolygons(json),
        districtId: json['district_id'] as String? ?? '',
        cityId: json['city_id'] as String? ?? '',
        stateId: json['state_id'] as String? ?? '',
        countryId: json['country_id'] as String? ?? '',
        geometrySourceVersion: json['geometry_source_version'] as String? ?? '',
        geometryGenerationMode:
            json['geometry_generation_mode'] as String? ?? '',
        centroidDatasetVersion:
            json['centroid_dataset_version'] as String? ?? '',
        geometryContract: json['geometry_contract'] as String? ?? '',
        habitatSourceVersion: json['habitat_source_version'] as String? ?? '',
        habitatConfidence: json['habitat_confidence'] as String? ?? '',
      );
  Map<String, dynamic> toJson() => {
        'cell_id': cellId,
        'habitats': habitats,
        'polygons': polygons,
        'district_id': districtId,
        'city_id': cityId,
        'state_id': stateId,
        'country_id': countryId,
        'geometry_source_version': geometrySourceVersion,
        'geometry_generation_mode': geometryGenerationMode,
        'centroid_dataset_version': centroidDatasetVersion,
        'geometry_contract': geometryContract,
        'habitat_source_version': habitatSourceVersion,
        'habitat_confidence': habitatConfidence,
      };

  factory CellDto.fromDomain(Cell cell) => CellDto(
        cellId: cell.id,
        habitats: cell.habitats.map((habitat) => habitat.name).toList(),
        polygons: [
          for (final polygon in cell.polygons)
            [
              for (final ring in polygon)
                [
                  for (final point in ring)
                    {'lat': point.lat, 'lng': point.lng},
                ],
            ],
        ],
        districtId: cell.districtId,
        cityId: cell.cityId,
        stateId: cell.stateId,
        countryId: cell.countryId,
        geometrySourceVersion: cell.geometrySourceVersion,
        geometryGenerationMode: cell.geometryGenerationMode,
        centroidDatasetVersion: cell.centroidDatasetVersion,
        geometryContract: cell.geometryContract,
        habitatSourceVersion: cell.habitatSourceVersion,
        habitatConfidence: cell.habitatConfidence,
      );

  Cell toDomain() => Cell(
        id: cellId,
        habitats:
            habitats.map(Habitat.fromString).whereType<Habitat>().toList(),
        polygons: [
          for (final polygon in polygons)
            [
              for (final ring in polygon)
                [
                  for (final point in ring)
                    (lat: point['lat']!, lng: point['lng']!)
                ],
            ],
        ],
        districtId: districtId,
        cityId: cityId,
        stateId: stateId,
        countryId: countryId,
        geometrySourceVersion: geometrySourceVersion,
        geometryGenerationMode: geometryGenerationMode,
        centroidDatasetVersion: centroidDatasetVersion,
        geometryContract: geometryContract,
        habitatSourceVersion: habitatSourceVersion,
        habitatConfidence: habitatConfidence,
      );

  static List<List<List<Map<String, double>>>> _parsePolygons(
    Map<String, dynamic> json,
  ) {
    final nested = json['polygons'];
    if (nested is List<dynamic>) {
      return nested
          .whereType<List<dynamic>>()
          .map(
            (polygon) => polygon
                .whereType<List<dynamic>>()
                .map(
                  (ring) => ring
                      .whereType<Map>()
                      .map((point) =>
                          _parsePoint(Map<String, dynamic>.from(point)))
                      .toList(growable: false),
                )
                .toList(growable: false),
          )
          .toList(growable: false);
    }

    final legacy = json['polygon'];
    if (legacy is List<dynamic>) {
      final ring = legacy
          .whereType<Map>()
          .map((point) => _parsePoint(Map<String, dynamic>.from(point)))
          .toList(growable: false);
      if (ring.isEmpty) return const [];
      return [
        [ring],
      ];
    }

    return const [];
  }

  static Map<String, double> _parsePoint(Map<String, dynamic> point) => {
        'lat': (point['lat'] as num).toDouble(),
        'lng': (point['lng'] as num).toDouble(),
      };
}
