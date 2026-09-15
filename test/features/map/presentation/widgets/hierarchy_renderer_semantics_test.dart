import 'dart:convert';

import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/ui/product_surfaces/map/widgets/district_footprint_map.dart';
import 'package:earth_nova/ui/product_surfaces/map/widgets/hierarchy_exploration_map.dart';
import 'package:earth_nova/features/map/domain/repositories/hierarchy_repository.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Hierarchy exploration renderer', () {
    test('visited progress remains neutral and increasingly legible', () {
      final colors = [
        explorationColor(0, 0),
        explorationColor(1, 1),
        explorationColor(10, 6),
        explorationColor(20, 16),
        explorationColor(40, 31),
        explorationColor(69, 51),
        explorationColor(70, 51),
        explorationColor(85, 51),
      ];

      for (final color in colors) {
        expect(_isNeutral(color), isTrue);
      }
      for (var i = 1; i < colors.length; i++) {
        expect(
          colors[i].computeLuminance(),
          greaterThan(colors[i - 1].computeLuminance()),
        );
      }
      expect(
        _contrastRatio(explorationColor(69.9, 51), const Color(0xFFF2F2F2)),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('keeps the existing cell-count and progress thresholds', () {
      expect(explorationColor(0, 1), explorationColor(0, 5));
      expect(explorationColor(0, 5), isNot(explorationColor(0, 6)));
      expect(explorationColor(0, 6), explorationColor(0, 15));
      expect(explorationColor(0, 15), isNot(explorationColor(0, 16)));
      expect(explorationColor(0, 16), explorationColor(0, 30));
      expect(explorationColor(0, 30), isNot(explorationColor(0, 31)));
      expect(explorationColor(0, 31), explorationColor(0, 50));
      expect(explorationColor(0, 50), isNot(explorationColor(69.9, 51)));
      expect(explorationColor(69.9, 51), isNot(explorationColor(70, 51)));
      expect(explorationColor(84.9, 51), isNot(explorationColor(85, 51)));
    });

    testWidgets('keeps one 80 by 60 tile and numeric cue per child', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      const children = [
        ChildAreaData(
          id: 'zero',
          name: 'Zero',
          cellsVisited: 0,
          cellsTotal: 10,
          progressPercent: 0,
        ),
        ChildAreaData(
          id: 'visited',
          name: 'Visited',
          cellsVisited: 12,
          cellsTotal: 20,
          progressPercent: 60,
        ),
        ChildAreaData(
          id: 'progress',
          name: 'Progress',
          cellsVisited: 18,
          cellsTotal: 20,
          progressPercent: 90,
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: SizedBox(
            width: 300,
            height: 120,
            child: HierarchyExplorationMap(
              children: children,
              playerLat: 45,
              playerLng: -66,
            ),
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Zero, 0 of 10 cells visited, 0% explored'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Visited, 12 of 20 cells visited, 60% explored'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Player location'), findsOneWidget);
      const tileConstraints = BoxConstraints.tightFor(width: 80, height: 60);
      final tiles = tester.widgetList<Container>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container && widget.constraints == tileConstraints,
        ),
      );
      expect(tiles, hasLength(children.length));
      semantics.dispose();
    });
  });

  group('District footprint renderer', () {
    test(
      'context, unvisited, visited, and current have neutral ordered cues',
      () {
        const context = districtFootprintContextStyle;
        final unvisited = districtFootprintCellStyle(
          isVisited: false,
          isCurrent: false,
        );
        final visited = districtFootprintCellStyle(
          isVisited: true,
          isCurrent: false,
        );
        final current = districtFootprintCellStyle(
          isVisited: true,
          isCurrent: true,
        );
        final currentUnvisited = districtFootprintCellStyle(
          isVisited: false,
          isCurrent: true,
        );

        for (final style in [
          context,
          unvisited,
          visited,
          current,
          currentUnvisited,
        ]) {
          expect(_isNeutral(style.fill), isTrue);
          expect(_isNeutral(style.stroke), isTrue);
        }
        expect(
          unvisited.fill.computeLuminance(),
          greaterThan(context.fill.computeLuminance()),
        );
        expect(
          visited.fill.computeLuminance(),
          greaterThan(unvisited.fill.computeLuminance()),
        );
        expect(visited.strokeWidth, greaterThan(unvisited.strokeWidth));
        expect(current.fill, visited.fill);
        expect(currentUnvisited.fill, unvisited.fill);
        expect(currentUnvisited.strokeWidth, current.strokeWidth);
        expect(current.strokeWidth, greaterThan(visited.strokeWidth));
        expect(
          current.stroke.computeLuminance(),
          greaterThan(visited.stroke.computeLuminance()),
        );
      },
    );

    testWidgets(
      'renders a cached boundary with polygon holes and multipolygons',
      (tester) async {
        final boundary = DistrictBoundary.tryParseGeoJson(
          jsonEncode({
            'type': 'MultiPolygon',
            'coordinates': [
              [
                [
                  [-66.65, 45.96],
                  [-66.64, 45.96],
                  [-66.64, 45.97],
                  [-66.65, 45.97],
                  [-66.65, 45.96],
                ],
                [
                  [-66.648, 45.963],
                  [-66.645, 45.963],
                  [-66.645, 45.966],
                  [-66.648, 45.966],
                  [-66.648, 45.963],
                ],
              ],
              [
                [
                  [-66.63, 45.96],
                  [-66.62, 45.96],
                  [-66.62, 45.97],
                  [-66.63, 45.97],
                  [-66.63, 45.96],
                ],
              ],
            ],
          }),
        )!;

        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 320,
              height: 240,
              child: DistrictFootprintMap(
                districtBoundary: boundary,
                cells: const [],
                currentDistrictId: 'district-1',
                visitedCellIds: const {},
              ),
            ),
          ),
        );

        final customPaint = tester.widget<CustomPaint>(
          find.descendant(
            of: find.byType(DistrictFootprintMap),
            matching: find.byType(CustomPaint),
          ),
        );
        final painter = customPaint.painter! as DistrictFootprintMapPainter;
        expect(painter.districtBoundary, same(boundary));
        expect(painter.districtBoundary!.polygons, hasLength(2));
        expect(painter.districtBoundary!.polygons.first, hasLength(2));
      },
    );

    testWidgets(
      'reports an unavailable boundary rather than a cell working-set footprint',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 320,
              height: 240,
              child: DistrictFootprintMap(
                cells: [
                  _cell(
                    id: 'district-cell',
                    districtId: 'district-1',
                    polygons: _square(45, -66),
                  ),
                ],
                currentDistrictId: 'district-1',
                visitedCellIds: const {},
              ),
            ),
          ),
        );

        expect(find.text('District boundary unavailable.'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(DistrictFootprintMap),
            matching: find.byType(CustomPaint),
          ),
          findsNothing,
        );
      },
    );

    testWidgets('keeps district/context counts and organic exterior paths', (
      tester,
    ) async {
      final boundary = DistrictBoundary.tryParseGeoJson(
        jsonEncode({
          'type': 'Polygon',
          'coordinates': [
            [
              [-66.008, 44.998],
              [-65.996, 44.998],
              [-65.996, 45.008],
              [-66.008, 45.008],
              [-66.008, 44.998],
            ],
          ],
        }),
      )!;
      final current = _cell(
        id: 'current',
        districtId: 'district-1',
        polygons: const [
          [
            [
              (lat: 45.0000, lng: -66.0000),
              (lat: 45.0004, lng: -65.9995),
              (lat: 45.0010, lng: -65.9993),
              (lat: 45.0014, lng: -66.0000),
              (lat: 45.0008, lng: -66.0006),
              (lat: 45.0000, lng: -66.0000),
            ],
          ],
          [
            [
              (lat: 45.0015, lng: -65.9998),
              (lat: 45.0018, lng: -65.9994),
              (lat: 45.0021, lng: -65.9999),
              (lat: 45.0015, lng: -65.9998),
            ],
          ],
        ],
      );
      final unvisited = _cell(
        id: 'unvisited',
        districtId: 'district-1',
        polygons: _square(45.003, -66.003),
      );
      final context = _cell(
        id: 'context',
        districtId: 'district-2',
        polygons: _square(45.006, -66.006),
      );
      final unavailable = _cell(
        id: 'unavailable',
        districtId: 'district-1',
        polygons: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 320,
            height: 240,
            child: DistrictFootprintMap(
              cells: [current, unvisited, context, unavailable],
              districtBoundary: boundary,
              currentDistrictId: 'district-1',
              visitedCellIds: const {'current'},
              currentCellId: 'current',
            ),
          ),
        ),
      );

      final customPaint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(DistrictFootprintMap),
          matching: find.byType(CustomPaint),
        ),
      );
      final painter = customPaint.painter! as DistrictFootprintMapPainter;
      expect(painter.districtCells.map((cell) => cell.id), [
        'current',
        'unvisited',
      ]);
      final semanticNodes = painter.semanticsBuilder(const Size(320, 240));
      expect(semanticNodes.map((node) => node.properties.label), [
        'Context cell',
        'Current cell',
        'Unvisited cell',
      ]);
      for (final node in semanticNodes) {
        expect(node.rect.width, greaterThan(0));
        expect(node.rect.height, greaterThan(0));
      }
      expect(painter.contextCells.map((cell) => cell.id), ['context']);
      expect(painter.currentCellId, 'current');
      expect(painter.visitedCellIds, {'current'});
      expect(painter.districtCells.first.polygons, same(current.polygons));
      expect(painter.districtCells.first.polygons, hasLength(2));
      expect(painter.districtCells.first.polygons.first.first, hasLength(6));
    });
  });
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

bool _isNeutral(Color color) {
  final value = color.toARGB32();
  final red = (value >> 16) & 0xff;
  final green = (value >> 8) & 0xff;
  final blue = value & 0xff;
  return (value >> 24) == 0xff && red == green && green == blue;
}

Cell _cell({
  required String id,
  required String districtId,
  required List<List<List<({double lat, double lng})>>> polygons,
}) => Cell(
  id: id,
  habitats: const [Habitat.urban],
  polygons: polygons,
  districtId: districtId,
  cityId: 'city-1',
  stateId: 'state-1',
  countryId: 'country-1',
  habitatConfidence: 'classified',
);

List<List<List<({double lat, double lng})>>> _square(double lat, double lng) =>
    [
      [
        [
          (lat: lat - 0.001, lng: lng - 0.001),
          (lat: lat - 0.001, lng: lng + 0.001),
          (lat: lat + 0.001, lng: lng + 0.001),
          (lat: lat + 0.001, lng: lng - 0.001),
          (lat: lat - 0.001, lng: lng - 0.001),
        ],
      ],
    ];
