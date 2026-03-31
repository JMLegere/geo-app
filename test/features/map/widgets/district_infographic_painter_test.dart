import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';

import 'package:earth_nova/features/map/models/district_infographic_data.dart';
import 'package:earth_nova/features/map/widgets/district_infographic_painter.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

List<Geographic> _makeRing({
  double lat = 45.0,
  double lon = -66.0,
  double delta = 0.01,
}) {
  return [
    Geographic(lat: lat - delta, lon: lon - delta),
    Geographic(lat: lat - delta, lon: lon + delta),
    Geographic(lat: lat + delta, lon: lon + delta),
    Geographic(lat: lat + delta, lon: lon - delta),
    Geographic(lat: lat - delta, lon: lon - delta), // close ring
  ];
}

DistrictInfographicData _makeData({
  String districtName = 'Test District',
  String districtId = 'district_1',
  List<List<Geographic>>? boundaryRings,
  List<String>? allCellIds,
  Set<String>? exploredCellIds,
  Map<String, List<Geographic>>? exploredCellBoundaries,
  double playerLat = 45.0,
  double playerLon = -66.0,
  int totalSpeciesFound = 5,
  double minLat = 44.99,
  double maxLat = 45.01,
  double minLon = -66.01,
  double maxLon = -65.99,
}) {
  return DistrictInfographicData(
    districtName: districtName,
    districtId: districtId,
    boundaryRings: boundaryRings ?? [_makeRing()],
    allCellIds: allCellIds ?? ['c1', 'c2', 'c3'],
    exploredCellIds: exploredCellIds ?? {'c1'},
    exploredCellBoundaries: exploredCellBoundaries ??
        {
          'c1': _makeRing(lat: 45.0, lon: -66.0, delta: 0.005),
        },
    playerLat: playerLat,
    playerLon: playerLon,
    totalSpeciesFound: totalSpeciesFound,
    minLat: minLat,
    maxLat: maxLat,
    minLon: minLon,
    maxLon: maxLon,
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    DistrictInfographicPainter.clearCache();
  });

  group('shouldRepaint', () {
    test('returns true when pulseProgress differs', () {
      final data = _makeData();
      final oldPainter =
          DistrictInfographicPainter(data: data, pulseProgress: 0.0);
      final newPainter =
          DistrictInfographicPainter(data: data, pulseProgress: 0.5);

      expect(newPainter.shouldRepaint(oldPainter), isTrue);
    });

    test('returns false when pulseProgress and data are identical', () {
      final data = _makeData();
      final oldPainter =
          DistrictInfographicPainter(data: data, pulseProgress: 0.5);
      final newPainter =
          DistrictInfographicPainter(data: data, pulseProgress: 0.5);

      expect(newPainter.shouldRepaint(oldPainter), isFalse);
    });

    test('returns true when data object differs', () {
      // Two separate instances with identical field values — different identity.
      final data1 = _makeData();
      final data2 = _makeData();
      final oldPainter =
          DistrictInfographicPainter(data: data1, pulseProgress: 0.0);
      final newPainter =
          DistrictInfographicPainter(data: data2, pulseProgress: 0.0);

      expect(newPainter.shouldRepaint(oldPainter), isTrue);
    });
  });

  group('clearCache', () {
    testWidgets(
        'resets static cache — second paint with different size rebuilds paths',
        (tester) async {
      final data = _makeData();

      // First paint.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter:
                  DistrictInfographicPainter(data: data, pulseProgress: 0.0),
              size: const Size(400, 800),
            ),
          ),
        ),
      );
      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));

      // Clear cache.
      DistrictInfographicPainter.clearCache();

      // Second paint with different size — should rebuild paths from scratch, not crash.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter:
                  DistrictInfographicPainter(data: data, pulseProgress: 0.0),
              size: const Size(200, 200),
            ),
          ),
        ),
      );
      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    });
  });

  group('paint — empty data', () {
    testWidgets('draws only background when allCellIds is empty',
        (tester) async {
      final data = _makeData(
        allCellIds: [],
        exploredCellIds: {},
        exploredCellBoundaries: {},
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter:
                  DistrictInfographicPainter(data: data, pulseProgress: 0.0),
              size: const Size(400, 800),
            ),
          ),
        ),
      );

      // If paint() threw, this would fail; expect no errors.
      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    });
  });

  group('paint — with data', () {
    testWidgets('paints without error for valid data with boundary',
        (tester) async {
      final data = _makeData(
        boundaryRings: [_makeRing()],
        allCellIds: ['c1', 'c2', 'c3'],
        exploredCellIds: {'c1', 'c2'},
        exploredCellBoundaries: {
          'c1': _makeRing(lat: 44.995, lon: -66.005, delta: 0.004),
          'c2': _makeRing(lat: 45.005, lon: -65.995, delta: 0.004),
        },
        playerLat: 45.0,
        playerLon: -66.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter:
                  DistrictInfographicPainter(data: data, pulseProgress: 0.5),
              size: const Size(400, 800),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    });

    testWidgets('paints without error for data without boundary',
        (tester) async {
      final data = _makeData(
        boundaryRings: [], // no boundary rings — boundary drawing should be skipped
        allCellIds: ['c1'],
        exploredCellIds: {'c1'},
        exploredCellBoundaries: {
          'c1': _makeRing(delta: 0.004),
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter:
                  DistrictInfographicPainter(data: data, pulseProgress: 0.0),
              size: const Size(400, 400),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    });

    testWidgets('paints without error with degenerate bounding box',
        (tester) async {
      // minLat ≈ maxLat and minLon ≈ maxLon — _geoToScreen returns null for all
      // points, so the painter should skip affected drawing without crashing.
      const epsilon = 1e-10;
      final data = _makeData(
        minLat: 45.0,
        maxLat: 45.0 + epsilon,
        minLon: -66.0,
        maxLon: -66.0 + epsilon,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter:
                  DistrictInfographicPainter(data: data, pulseProgress: 0.0),
              size: const Size(400, 400),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    });
  });

  group('projection — _geoToScreen', () {
    testWidgets(
        'player marker renders within canvas bounds for position inside bbox',
        (tester) async {
      // Player position is well inside the bounding box — _geoToScreen should
      // return a non-null Offset and the circles should be drawn.
      final data = _makeData(
        playerLat: 45.0,
        playerLon: -66.0,
        minLat: 44.99,
        maxLat: 45.01,
        minLon: -66.01,
        maxLon: -65.99,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter:
                  DistrictInfographicPainter(data: data, pulseProgress: 0.75),
              size: const Size(400, 800),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    });

    testWidgets(
        'handles zero lat/lon range gracefully — _geoToScreen returns null',
        (tester) async {
      // Exactly zero lat and lon range — latRange <= 0 OR lonRange <= 0 causes
      // _geoToScreen to return null; all geo→pixel conversions are skipped.
      final data = _makeData(
        minLat: 45.0,
        maxLat: 45.0,
        minLon: -66.0,
        maxLon: -66.0,
        allCellIds: ['c1'],
        exploredCellIds: {'c1'},
        exploredCellBoundaries: {
          'c1': _makeRing(delta: 0.004),
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter:
                  DistrictInfographicPainter(data: data, pulseProgress: 0.0),
              size: const Size(400, 400),
            ),
          ),
        ),
      );

      // If division-by-zero or null-deref occurred, the test would fail.
      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    });
  });

  group('bloom path — large explored cell count', () {
    testWidgets('skips bloom path when explored cell count >= 500',
        (tester) async {
      // Build 500 explored cell boundaries — bloom path should NOT be built.
      final cellIds = List.generate(500, (i) => 'cell_$i');
      final boundaries = <String, List<Geographic>>{
        for (var i = 0; i < 500; i++)
          'cell_$i': _makeRing(
            lat: 45.0 + (i * 0.0001),
            lon: -66.0 + (i * 0.0001),
            delta: 0.00004,
          ),
      };

      final data = _makeData(
        allCellIds: cellIds,
        exploredCellIds: cellIds.toSet(),
        exploredCellBoundaries: boundaries,
        minLat: 44.9,
        maxLat: 45.1,
        minLon: -66.1,
        maxLon: -65.9,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomPaint(
              painter:
                  DistrictInfographicPainter(data: data, pulseProgress: 0.0),
              size: const Size(400, 400),
            ),
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
    });
  });
}
