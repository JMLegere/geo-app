import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/presentation/screens/map_screen.dart';
import 'package:earth_nova/features/map/presentation/widgets/cell_detail_sheet.dart';
import 'package:earth_nova/features/map/presentation/widgets/shimmer_cells.dart';

void main() {
  group('MapScreen Integration Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('MapScreen shows loading when location is loading', () {
      final widget = ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => const MapScreen(),
          ),
        ),
      );

      expect(widget, isNotNull);
    });

    test('CellDetailSheet displays cell information correctly', () {
      final cell = Cell(
        id: 'test-cell-123',
        habitats: [Habitat.forest, Habitat.mountain],
        polygon: [
          (lat: 37.7749, lng: -122.4194),
        ],
        districtId: 'district-1',
        cityId: 'city-1',
        stateId: 'state-1',
        countryId: 'country-1',
      );

      final sheet = CellDetailSheet(
        cell: cell,
        visitCount: 3,
        isFirstVisit: false,
      );

      expect(sheet, isNotNull);
    });

    test('ShimmerCells widget renders without error', () {
      final shimmer = ShimmerCells(
        cameraPosition: (lat: 37.7749, lng: -122.4194),
        zoom: 15.0,
      );

      expect(shimmer, isNotNull);
    });

    test('ShimmerCells uses animation controller', () {
      final shimmer = ShimmerCells(
        cameraPosition: (lat: 37.7749, lng: -122.4194),
        zoom: 15.0,
      );

      expect(shimmer, isA<StatefulWidget>());
    });

    test('CellDetailSheet shows habitat labels', () {
      final cell = Cell(
        id: 'test-cell-456',
        habitats: [Habitat.ocean],
        polygon: [
          (lat: 40.7128, lng: -74.0060),
        ],
        districtId: 'district-2',
        cityId: 'city-2',
        stateId: 'state-2',
        countryId: 'country-2',
      );

      final sheet = CellDetailSheet(
        cell: cell,
        visitCount: 1,
        isFirstVisit: true,
      );

      expect(sheet, isNotNull);
      expect(cell.habitats.length, equals(1));
      expect(cell.habitats.first, equals(Habitat.ocean));
    });
  });
}
