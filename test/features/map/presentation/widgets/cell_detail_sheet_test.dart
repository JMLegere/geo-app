import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/presentation/widgets/cell_detail_sheet.dart';

void main() {
  group('CellDetailSheet habitat display', () {
    testWidgets(
      'does not present single legacy Plains fallback as verified terrain',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CellDetailSheet(
                cell: _cell(
                  habitats: const [Habitat.plains],
                  habitatConfidence: 'legacy_unverified',
                ),
                visitCount: 1,
                isFirstVisit: false,
                currentRelationship: CellRelationship.explored,
              ),
            ),
          ),
        );

        expect(find.text('Terrain unclassified'), findsOneWidget);
        expect(find.text('Plains'), findsNothing);
      },
    );

    testWidgets(
      'shows classified plains when provenance verifies the terrain',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CellDetailSheet(
                cell: _cell(
                  habitats: const [Habitat.plains],
                  habitatConfidence: 'classified',
                ),
                visitCount: 1,
                isFirstVisit: false,
                currentRelationship: CellRelationship.explored,
              ),
            ),
          ),
        );

        expect(find.text('Plains'), findsOneWidget);
        expect(find.text('Terrain unclassified'), findsNothing);
      },
    );

    testWidgets(
      'shows urban when backend classification normalizes built-up terrain',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CellDetailSheet(
                cell: _cell(
                  habitats: const [Habitat.urban],
                  habitatConfidence: 'classified',
                ),
                visitCount: 1,
                isFirstVisit: false,
                currentRelationship: CellRelationship.present,
              ),
            ),
          ),
        );

        expect(find.text('Urban'), findsOneWidget);
      },
    );

    testWidgets(
      'preserves specific multi-habitat labels when available',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: CellDetailSheet(
                cell: _cell(habitats: const [
                  Habitat.forest,
                  Habitat.freshwater,
                ]),
                visitCount: 2,
                isFirstVisit: false,
                currentRelationship: CellRelationship.explored,
              ),
            ),
          ),
        );

        expect(find.text('Forest / Freshwater'), findsOneWidget);
      },
    );
  });
}

Cell _cell({
  required List<Habitat> habitats,
  String habitatConfidence = 'classified',
}) =>
    Cell(
      id: 'v_22982_-33322',
      habitats: habitats,
      polygons: const [],
      districtId: 'district_ca_downtown',
      cityId: 'city_fredericton',
      stateId: 'state_new_brunswick',
      countryId: 'country_canada',
      habitatConfidence: habitatConfidence,
    );
