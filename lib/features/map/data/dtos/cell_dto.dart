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
  });

  final String cellId;
  final List<String> habitats;
  final List<List<List<Map<String, double>>>> polygons;
  final String districtId;
  final String cityId;
  final String stateId;
  final String countryId;

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
      );

  Cell toDomain() => Cell(
        id: cellId,
        habitats:
            habitats.map(Habitat.fromString).whereType<Habitat>().toList(),
        polygons: [
          for (final polygon in polygons)
            [
              for (final ring in polygon)
                [for (final point in ring) (lat: point['lat']!, lng: point['lng']!)],
            ],
        ],
        districtId: districtId,
        cityId: cityId,
        stateId: stateId,
        countryId: countryId,
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
                      .map((point) => _parsePoint(Map<String, dynamic>.from(point)))
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
