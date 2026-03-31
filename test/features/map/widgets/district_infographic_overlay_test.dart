import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';

import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/fog/fog_state_resolver.dart';
import 'package:earth_nova/core/models/item_category.dart';
import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/core/models/location_node.dart';
import 'package:earth_nova/core/persistence/location_node_repository.dart';
import 'package:earth_nova/core/services/detection_zone_service.dart';
import 'package:earth_nova/core/state/detection_zone_provider.dart';
import 'package:earth_nova/core/state/fog_resolver_provider.dart';
import 'package:earth_nova/core/state/location_provider.dart';
import 'package:earth_nova/features/items/providers/items_provider.dart';
import 'package:earth_nova/features/map/widgets/district_infographic_overlay.dart';

// ── MockCellService ────────────────────────────────────────────────────────

class MockCellService implements CellService {
  final Map<String, Geographic> _centers;
  final Map<String, List<Geographic>> _boundaries;

  MockCellService({
    Map<String, Geographic>? centers,
    Map<String, List<Geographic>>? boundaries,
  })  : _centers = centers ?? {},
        _boundaries = boundaries ?? {};

  @override
  String getCellId(double lat, double lon) =>
      'cell_${lat.round()}_${lon.round()}';

  @override
  Geographic getCellCenter(String cellId) =>
      _centers[cellId] ?? const Geographic(lat: 45.0, lon: -66.0);

  @override
  List<Geographic> getCellBoundary(String cellId) =>
      _boundaries[cellId] ?? _makeRing();

  @override
  List<String> getNeighborIds(String cellId) => [];

  @override
  List<String> getCellsInRing(String cellId, int k) =>
      k == 0 ? [cellId] : [cellId];

  @override
  List<String> getCellsAroundLocation(double lat, double lon, int k) =>
      getCellsInRing(getCellId(lat, lon), k);

  @override
  double get cellEdgeLengthMeters => 180.0;

  @override
  String get systemName => 'MockCellService';
}

List<Geographic> _makeRing() => const [
      Geographic(lat: 45.0, lon: -66.0),
      Geographic(lat: 45.01, lon: -66.0),
      Geographic(lat: 45.01, lon: -65.99),
      Geographic(lat: 45.0, lon: -65.99),
    ];

// ── _FakeDetectionZoneService ──────────────────────────────────────────────

/// DetectionZoneService subclass with pre-configured test data.
class _FakeDetectionZoneService extends DetectionZoneService {
  final String? _fakeDistrictId;
  final Map<String, String> _fakeAttribution;

  _FakeDetectionZoneService({
    String? districtId,
    Map<String, String>? attribution,
    required CellService cellService,
    required LocationNodeRepository locationNodeRepo,
  })  : _fakeDistrictId = districtId,
        _fakeAttribution = attribution ?? {},
        super(cellService: cellService, locationNodeRepo: locationNodeRepo);

  @override
  String? get currentDistrictId => _fakeDistrictId;

  @override
  Map<String, String> get cellDistrictAttribution =>
      Map.unmodifiable(_fakeAttribution);
}

// ── Mock Notifiers ─────────────────────────────────────────────────────────

class _MockLocationNotifier extends LocationNotifier {
  final LocationState _initial;
  _MockLocationNotifier(this._initial);

  @override
  LocationState build() => _initial;
}

class _MockItemsNotifier extends ItemsNotifier {
  final ItemsState _initial;
  _MockItemsNotifier(this._initial);

  @override
  ItemsState build() => _initial;
}

// ── Factories ──────────────────────────────────────────────────────────────

AppDatabase _makeDb() => AppDatabase(NativeDatabase.memory());

FogStateResolver _makeFogResolver({
  required CellService cellService,
  Set<String> visitedCells = const {},
}) {
  final resolver = FogStateResolver(cellService);
  if (visitedCells.isNotEmpty) {
    resolver.loadVisitedCells(visitedCells);
  }
  return resolver;
}

ItemInstance _makeInstance({String definitionId = 'def_x'}) {
  return ItemInstance(
    id: 'inst_$definitionId',
    definitionId: definitionId,
    displayName: 'Test Species',
    category: ItemCategory.fauna,
    affixes: const [],
    acquiredAt: DateTime(2026),
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('no data fallback', () {
    testWidgets('renders fallback when no districtId available',
        (tester) async {
      final db = _makeDb();
      addTearDown(db.close);
      final repo = LocationNodeRepository(db);
      final cellService = MockCellService();

      final fakeZone = _FakeDetectionZoneService(
        districtId: null,
        cellService: cellService,
        locationNodeRepo: repo,
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [
          detectionZoneServiceProvider.overrideWith((_) => fakeZone),
          fogResolverProvider
              .overrideWith((_) => _makeFogResolver(cellService: cellService)),
          locationProvider
              .overrideWith(() => _MockLocationNotifier(LocationState())),
          itemsProvider.overrideWith(() => _MockItemsNotifier(ItemsState())),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DistrictInfographicOverlay(
              onDismiss: () {},
              locationNodesMap: {},
              cellService: cellService,
            ),
          ),
        ),
      ));

      await tester.pump();

      expect(find.text('District data not available'), findsOneWidget);
    });

    testWidgets('tapping fallback dismisses overlay', (tester) async {
      final db = _makeDb();
      addTearDown(db.close);
      final repo = LocationNodeRepository(db);
      final cellService = MockCellService();

      final fakeZone = _FakeDetectionZoneService(
        districtId: null,
        cellService: cellService,
        locationNodeRepo: repo,
      );

      var dismissed = false;

      await tester.pumpWidget(ProviderScope(
        overrides: [
          detectionZoneServiceProvider.overrideWith((_) => fakeZone),
          fogResolverProvider
              .overrideWith((_) => _makeFogResolver(cellService: cellService)),
          locationProvider
              .overrideWith(() => _MockLocationNotifier(LocationState())),
          itemsProvider.overrideWith(() => _MockItemsNotifier(ItemsState())),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DistrictInfographicOverlay(
              onDismiss: () => dismissed = true,
              locationNodesMap: {},
              cellService: cellService,
            ),
          ),
        ),
      ));

      await tester.pump();

      await tester.tap(find.text('District data not available'));
      // Advance past the 350ms fade-out (Durations.slow). Cannot use
      // pumpAndSettle because _pulseCtrl repeats forever.
      await tester.pump(const Duration(milliseconds: 500));

      expect(dismissed, isTrue);
    });
  });

  group('with district data', () {
    const districtId = 'district_1';

    // 10 cells attributed to the district.
    const allCellIds = [
      'cell_45_-66',
      'cell_45_-65',
      'cell_46_-66',
      'cell_44_-66',
      'cell_44_-65',
      'cell_43_-66',
      'cell_43_-65',
      'cell_42_-66',
      'cell_42_-65',
      'cell_41_-66',
    ];

    final attribution = {for (final c in allCellIds) c: districtId};

    final cellCenters = {
      'cell_45_-66': const Geographic(lat: 45.0, lon: -66.0),
      'cell_45_-65': const Geographic(lat: 45.0, lon: -65.99),
      'cell_46_-66': const Geographic(lat: 45.01, lon: -66.0),
      'cell_44_-66': const Geographic(lat: 44.0, lon: -66.0),
      'cell_44_-65': const Geographic(lat: 44.0, lon: -65.99),
      'cell_43_-66': const Geographic(lat: 43.0, lon: -66.0),
      'cell_43_-65': const Geographic(lat: 43.0, lon: -65.99),
      'cell_42_-66': const Geographic(lat: 42.0, lon: -66.0),
      'cell_42_-65': const Geographic(lat: 42.0, lon: -65.99),
      'cell_41_-66': const Geographic(lat: 41.0, lon: -66.0),
    };

    const locationNodesMap = {
      districtId: LocationNode(
        id: districtId,
        osmId: null,
        name: 'Test District',
        adminLevel: AdminLevel.district,
        parentId: null,
        colorHex: null,
        geometryJson: null,
      ),
    };

    late AppDatabase db;
    late LocationNodeRepository repo;
    late MockCellService cellService;

    setUp(() {
      db = _makeDb();
      repo = LocationNodeRepository(db);
      cellService = MockCellService(centers: cellCenters);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('renders district name in header', (tester) async {
      final fakeZone = _FakeDetectionZoneService(
        districtId: districtId,
        attribution: attribution,
        cellService: cellService,
        locationNodeRepo: repo,
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [
          detectionZoneServiceProvider.overrideWith((_) => fakeZone),
          fogResolverProvider.overrideWith((_) => _makeFogResolver(
              cellService: cellService,
              visitedCells: {'cell_45_-66', 'cell_45_-65', 'cell_46_-66'})),
          locationProvider.overrideWith(() => _MockLocationNotifier(
                LocationState(
                    currentPosition: const Geographic(lat: 45.0, lon: -66.0)),
              )),
          itemsProvider.overrideWith(() => _MockItemsNotifier(ItemsState())),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DistrictInfographicOverlay(
              onDismiss: () {},
              locationNodesMap: locationNodesMap,
              cellService: cellService,
            ),
          ),
        ),
      ));

      await tester.pump();

      expect(find.text('Test District'), findsOneWidget);
    });

    testWidgets('renders exploration percentage', (tester) async {
      // 3 explored / 10 total = 30.0%
      final fakeZone = _FakeDetectionZoneService(
        districtId: districtId,
        attribution: attribution,
        cellService: cellService,
        locationNodeRepo: repo,
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [
          detectionZoneServiceProvider.overrideWith((_) => fakeZone),
          fogResolverProvider.overrideWith((_) => _makeFogResolver(
              cellService: cellService,
              visitedCells: {'cell_45_-66', 'cell_45_-65', 'cell_46_-66'})),
          locationProvider.overrideWith(() => _MockLocationNotifier(
                LocationState(
                    currentPosition: const Geographic(lat: 45.0, lon: -66.0)),
              )),
          itemsProvider.overrideWith(() => _MockItemsNotifier(ItemsState())),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DistrictInfographicOverlay(
              onDismiss: () {},
              locationNodesMap: locationNodesMap,
              cellService: cellService,
            ),
          ),
        ),
      ));

      await tester.pump();

      expect(find.text('30.0%'), findsOneWidget);
    });

    testWidgets('renders cell count', (tester) async {
      // 3 explored cells → stats bar shows "3".
      final fakeZone = _FakeDetectionZoneService(
        districtId: districtId,
        attribution: attribution,
        cellService: cellService,
        locationNodeRepo: repo,
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [
          detectionZoneServiceProvider.overrideWith((_) => fakeZone),
          fogResolverProvider.overrideWith((_) => _makeFogResolver(
              cellService: cellService,
              visitedCells: {'cell_45_-66', 'cell_45_-65', 'cell_46_-66'})),
          locationProvider.overrideWith(() => _MockLocationNotifier(
                LocationState(
                    currentPosition: const Geographic(lat: 45.0, lon: -66.0)),
              )),
          itemsProvider.overrideWith(() => _MockItemsNotifier(ItemsState())),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DistrictInfographicOverlay(
              onDismiss: () {},
              locationNodesMap: locationNodesMap,
              cellService: cellService,
            ),
          ),
        ),
      ));

      await tester.pump();

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('renders species count', (tester) async {
      final fakeZone = _FakeDetectionZoneService(
        districtId: districtId,
        attribution: attribution,
        cellService: cellService,
        locationNodeRepo: repo,
      );

      final fakeItems = ItemsState(
        items: List.generate(5, (i) => _makeInstance(definitionId: 'def_$i')),
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [
          detectionZoneServiceProvider.overrideWith((_) => fakeZone),
          fogResolverProvider.overrideWith((_) => _makeFogResolver(
              cellService: cellService,
              visitedCells: {'cell_45_-66', 'cell_45_-65', 'cell_46_-66'})),
          locationProvider.overrideWith(() => _MockLocationNotifier(
                LocationState(
                    currentPosition: const Geographic(lat: 45.0, lon: -66.0)),
              )),
          itemsProvider.overrideWith(() => _MockItemsNotifier(fakeItems)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DistrictInfographicOverlay(
              onDismiss: () {},
              locationNodesMap: locationNodesMap,
              cellService: cellService,
            ),
          ),
        ),
      ));

      await tester.pump();

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('back button calls onDismiss', (tester) async {
      final fakeZone = _FakeDetectionZoneService(
        districtId: districtId,
        attribution: attribution,
        cellService: cellService,
        locationNodeRepo: repo,
      );

      var dismissed = false;

      await tester.pumpWidget(ProviderScope(
        overrides: [
          detectionZoneServiceProvider.overrideWith((_) => fakeZone),
          fogResolverProvider.overrideWith((_) => _makeFogResolver(
              cellService: cellService,
              visitedCells: {'cell_45_-66', 'cell_45_-65', 'cell_46_-66'})),
          locationProvider.overrideWith(() => _MockLocationNotifier(
                LocationState(
                    currentPosition: const Geographic(lat: 45.0, lon: -66.0)),
              )),
          itemsProvider.overrideWith(() => _MockItemsNotifier(ItemsState())),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DistrictInfographicOverlay(
              onDismiss: () => dismissed = true,
              locationNodesMap: locationNodesMap,
              cellService: cellService,
            ),
          ),
        ),
      ));

      await tester.pump();

      final backButton = find.byIcon(Icons.arrow_back);
      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      // Advance past the 350ms fade-out (Durations.slow). Cannot use
      // pumpAndSettle because _pulseCtrl repeats forever.
      await tester.pump(const Duration(milliseconds: 500));

      expect(dismissed, isTrue);
    });
  });

  group('dispose', () {
    testWidgets('clears painter cache on dispose without crashing',
        (tester) async {
      final db = _makeDb();
      addTearDown(db.close);
      final repo = LocationNodeRepository(db);
      final cellService = MockCellService();

      final fakeZone = _FakeDetectionZoneService(
        districtId: null,
        cellService: cellService,
        locationNodeRepo: repo,
      );

      await tester.pumpWidget(ProviderScope(
        overrides: [
          detectionZoneServiceProvider.overrideWith((_) => fakeZone),
          fogResolverProvider
              .overrideWith((_) => _makeFogResolver(cellService: cellService)),
          locationProvider
              .overrideWith(() => _MockLocationNotifier(LocationState())),
          itemsProvider.overrideWith(() => _MockItemsNotifier(ItemsState())),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DistrictInfographicOverlay(
              onDismiss: () {},
              locationNodesMap: {},
              cellService: cellService,
            ),
          ),
        ),
      ));

      await tester.pump();

      // Swap out the widget to trigger dispose on the overlay.
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.pump();

      // No crash = DistrictInfographicPainter.clearCache() completed cleanly.
      expect(tester.takeException(), isNull);
    });
  });
}
