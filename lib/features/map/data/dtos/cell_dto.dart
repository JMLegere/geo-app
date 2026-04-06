import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';

class CellDto {
  const CellDto({
    required this.cellId,
    required this.habitats,
    required this.polygon,
    required this.districtId,
    required this.cityId,
    required this.stateId,
    required this.countryId,
  });

  final String cellId;
  final List<String> habitats;
  final List<Map<String, double>> polygon;
  final String districtId;
  final String cityId;
  final String stateId;
  final String countryId;

  factory CellDto.fromJson(Map<String, dynamic> json) => CellDto(
        cellId: json['cell_id'] as String,
        habitats: (json['habitats'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
        polygon: (json['polygon'] as List<dynamic>? ?? []).map((e) {
          final point = e as Map<String, dynamic>;
          return {
            'lat': (point['lat'] as num).toDouble(),
            'lng': (point['lng'] as num).toDouble(),
          };
        }).toList(),
        districtId: json['district_id'] as String? ?? '',
        cityId: json['city_id'] as String? ?? '',
        stateId: json['state_id'] as String? ?? '',
        countryId: json['country_id'] as String? ?? '',
      );

  Cell toDomain() => Cell(
        id: cellId,
        habitats:
            habitats.map(Habitat.fromString).whereType<Habitat>().toList(),
        polygon: polygon.map((p) => (lat: p['lat']!, lng: p['lng']!)).toList(),
        districtId: districtId,
        cityId: cityId,
        stateId: stateId,
        countryId: countryId,
      );
}
