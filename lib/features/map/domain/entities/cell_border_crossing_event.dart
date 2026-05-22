enum CellBorderCrossingType {
  firstEntry,
  reEntry,
}

class CellBorderCrossingEvent {
  const CellBorderCrossingEvent({
    required this.borderCrossingId,
    required this.previousCellId,
    required this.enteredCellId,
    required this.borderCrossingType,
    required this.isFirstVisit,
    required this.occurredAt,
    required this.districtId,
    required this.cityId,
    required this.stateId,
    required this.countryId,
  });

  final String borderCrossingId;
  String get mapCellEntryId => borderCrossingId;
  final String? previousCellId;
  final String enteredCellId;
  final CellBorderCrossingType borderCrossingType;
  final bool isFirstVisit;
  final DateTime occurredAt;
  final String districtId;
  final String cityId;
  final String stateId;
  final String countryId;

  Map<String, dynamic> toTelemetryData() {
    return {
      'border_crossing_id': borderCrossingId,
      'map_cell_entry_id': mapCellEntryId,
      'previous_cell_id': previousCellId,
      'entered_cell_id': enteredCellId,
      'border_crossing_type': borderCrossingType.name,
      'is_first_visit': isFirstVisit,
      'occurred_at': occurredAt.toIso8601String(),
      'district_id': districtId,
      'city_id': cityId,
      'state_id': stateId,
      'country_id': countryId,
    };
  }
}
