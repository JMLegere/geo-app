import 'package:earth_nova/features/map/domain/entities/cell_border_crossing_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CellBorderCrossingEvent', () {
    test('serializes first-entry telemetry fields', () {
      final event = CellBorderCrossingEvent(
        borderCrossingId: 'crossing-1',
        previousCellId: 'cell-A',
        enteredCellId: 'cell-B',
        borderCrossingType: CellBorderCrossingType.firstEntry,
        isFirstVisit: true,
        occurredAt: DateTime.utc(2026, 5, 19, 12, 0),
        districtId: 'd2',
        cityId: 'c2',
        stateId: 's2',
        countryId: 'co1',
      );

      expect(event.toTelemetryData(), {
        'border_crossing_id': 'crossing-1',
        'map_cell_entry_id': 'crossing-1',
        'previous_cell_id': 'cell-A',
        'entered_cell_id': 'cell-B',
        'border_crossing_type': 'firstEntry',
        'is_first_visit': true,
        'occurred_at': '2026-05-19T12:00:00.000Z',
        'district_id': 'd2',
        'city_id': 'c2',
        'state_id': 's2',
        'country_id': 'co1',
      });
    });
  });
}
