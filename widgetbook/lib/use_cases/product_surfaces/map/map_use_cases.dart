import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/domain/entities/map_level.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';
import 'package:earth_nova/ui/product_surfaces/map/rendering/cell_overlay_painter.dart';
import 'package:earth_nova/ui/product_surfaces/map/rendering/player_marker.dart';
import 'package:earth_nova/ui/product_surfaces/map/screens/city_screen.dart';
import 'package:earth_nova/ui/product_surfaces/map/screens/country_screen.dart';
import 'package:earth_nova/ui/product_surfaces/map/screens/district_screen.dart';
import 'package:earth_nova/ui/product_surfaces/map/screens/map_root_screen.dart';
import 'package:earth_nova/ui/product_surfaces/map/screens/map_screen.dart';
import 'package:earth_nova/ui/product_surfaces/map/screens/province_screen.dart';
import 'package:earth_nova/ui/product_surfaces/map/screens/world_screen.dart';
import 'package:earth_nova/ui/product_surfaces/map/widgets/cell_detail_sheet.dart';
import 'package:earth_nova/ui/product_surfaces/map/widgets/discovery_notification.dart';
import 'package:earth_nova/ui/product_surfaces/map/widgets/district_footprint_map.dart';
import 'package:earth_nova/ui/product_surfaces/map/widgets/hierarchy_exploration_map.dart';
import 'package:earth_nova/ui/product_surfaces/map/widgets/hierarchy_header.dart';
import 'package:earth_nova/ui/product_surfaces/map/widgets/map_status_bar.dart';
import 'package:earth_nova/ui/product_surfaces/map/widgets/pinch_hint.dart';
import 'package:earth_nova/ui/product_surfaces/map/widgets/shimmer_cells.dart';
import 'package:earth_nova_widgetbook/fixtures/map_fixtures.dart';
import 'package:earth_nova_widgetbook/fixtures/story_host.dart';
import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

const _path = '[Product Surfaces]/Map';

@widgetbook.UseCase(name: '00 Happy Path', type: MapRootScreen, path: _path)
Widget mapRootCell(BuildContext context) => earthNovaStory(
  overrides: MapStoryFixtures.overrides(),
  child: const MapRootScreen(),
);

@widgetbook.UseCase(
  name: 'District Territory',
  type: MapRootScreen,
  path: _path,
)
Widget mapRootDistrict(BuildContext context) => earthNovaStory(
  overrides: MapStoryFixtures.overrides(level: MapLevel.district),
  child: const MapRootScreen(),
);

@widgetbook.UseCase(name: '00 Happy Path', type: MapScreen, path: _path)
Widget mapScreenHappyPath(BuildContext context) => _mapScreen();

@widgetbook.UseCase(name: 'Loading', type: MapScreen, path: _path)
Widget mapScreenLoading(BuildContext context) =>
    _mapScreen(mapState: const MapStateLoading());

@widgetbook.UseCase(name: 'Refreshing', type: MapScreen, path: _path)
Widget mapScreenRefreshing(BuildContext context) => _mapScreen(
  mapState: MapStateRefreshing(
    previous: MapStoryFixtures.ready,
    refreshLocation: MapStoryFixtures.location,
  ),
);

@widgetbook.UseCase(name: 'Error', type: MapScreen, path: _path)
Widget mapScreenError(BuildContext context) => _mapScreen(
  mapState: const MapStateError('Nearby cells could not refresh.'),
);

@widgetbook.UseCase(name: 'Paused Discovery', type: MapScreen, path: _path)
Widget mapScreenPaused(BuildContext context) => _mapScreen(paused: true);

@widgetbook.UseCase(name: 'Debug Ring', type: MapScreen, path: _path)
Widget mapScreenDebugRing(BuildContext context) => _mapScreen(ring: true);

@widgetbook.UseCase(
  name: 'Dart Renderer Fallback',
  type: MapScreen,
  path: _path,
)
Widget mapScreenDartFallback(BuildContext context) =>
    _mapScreen(fallback: true);

Widget _mapScreen({
  MapState? mapState,
  bool paused = false,
  bool ring = false,
  bool fallback = false,
}) => earthNovaStory(
  overrides: MapStoryFixtures.overrides(
    mapState: mapState,
    paused: paused,
    ring: ring,
  ),
  child: fallback
      ? Stack(
          fit: StackFit.expand,
          children: [
            MapScreen(retainedRenderer: MapStoryUnavailableRetainedRenderer()),
            // The Dart fog painter covers MapLibre's DOM attribution.
            const Positioned(
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: ColoredBox(
                  color: Colors.white70,
                  child: Text(
                    '© OpenStreetMap contributors © CARTO',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
              ),
            ),
          ],
        )
      : const MapScreen(),
);

@widgetbook.UseCase(name: '00 Happy Path', type: DistrictScreen, path: _path)
Widget districtScreenHappyPath(BuildContext context) => earthNovaStory(
  overrides: MapStoryFixtures.overrides(),
  child: DistrictScreen(
    scopeId: 'district-halifax',
    cells: MapStoryFixtures.cells,
    visitedCellIds: MapStoryFixtures.ready.visitedCellIds,
    currentCellId: 'halifax-present',
  ),
);

@widgetbook.UseCase(name: 'Error', type: DistrictScreen, path: _path)
Widget districtScreenError(BuildContext context) => earthNovaStory(
  overrides: MapStoryFixtures.overrides(hierarchyFails: true),
  child: const DistrictScreen(scopeId: 'district-halifax'),
);

@widgetbook.UseCase(name: '00 Happy Path', type: CityScreen, path: _path)
Widget cityScreenHappyPath(BuildContext context) =>
    _territory(const CityScreen(scopeId: 'city-halifax'));

@widgetbook.UseCase(name: '00 Happy Path', type: ProvinceScreen, path: _path)
Widget provinceScreenHappyPath(BuildContext context) =>
    _territory(const ProvinceScreen(scopeId: 'province-nova-scotia'));

@widgetbook.UseCase(name: '00 Happy Path', type: CountryScreen, path: _path)
Widget countryScreenHappyPath(BuildContext context) =>
    _territory(const CountryScreen(scopeId: 'country-canada'));

@widgetbook.UseCase(name: '00 Happy Path', type: WorldScreen, path: _path)
Widget worldScreenHappyPath(BuildContext context) =>
    _territory(const WorldScreen());

Widget _territory(Widget child) =>
    earthNovaStory(overrides: MapStoryFixtures.overrides(), child: child);

@widgetbook.UseCase(name: '00 Happy Path', type: CellDetailSheet, path: _path)
Widget cellDetailSheetHappyPath(BuildContext context) => _cellDetail(
  knowledgeState: CellKnowledgeState.present,
  relationship: CellRelationship.present,
);

@widgetbook.UseCase(name: 'Shrouded', type: CellDetailSheet, path: _path)
Widget cellDetailSheetShrouded(BuildContext context) => _cellDetail(
  knowledgeState: CellKnowledgeState.shrouded,
  relationship: CellRelationship.unknown,
);

@widgetbook.UseCase(name: 'Informed', type: CellDetailSheet, path: _path)
Widget cellDetailSheetInformed(BuildContext context) => _cellDetail(
  knowledgeState: CellKnowledgeState.informed,
  relationship: CellRelationship.frontier,
  category: 'flora',
);

Widget _cellDetail({
  required CellKnowledgeState knowledgeState,
  required CellRelationship relationship,
  String? category,
}) => earthNovaStory(
  child: Scaffold(
    backgroundColor: Colors.black,
    body: Align(
      alignment: Alignment.bottomCenter,
      child: CellDetailSheet(
        cell: MapStoryFixtures.cells.first,
        visitCount: 3,
        isFirstVisit: false,
        currentRelationship: relationship,
        knowledgeState: knowledgeState,
        category: category,
      ),
    ),
  ),
);

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: DiscoveryNotification,
  path: _path,
)
Widget discoveryNotificationHappyPath(BuildContext context) => earthNovaStory(
  child: const Scaffold(
    body: Center(child: DiscoveryNotification(cellName: 'Halifax Harbour')),
  ),
);

@widgetbook.UseCase(name: '00 Happy Path', type: MapStatusBar, path: _path)
Widget mapStatusBarHappyPath(BuildContext context) => earthNovaStory(
  child: const Scaffold(
    body: MapStatusBar(
      cellsObserved: 42,
      totalSteps: 12480,
      streakDays: 7,
      paddingTop: 0,
    ),
  ),
);

@widgetbook.UseCase(name: 'Pending Visits', type: MapStatusBar, path: _path)
Widget mapStatusBarPending(BuildContext context) => earthNovaStory(
  child: const Scaffold(
    body: MapStatusBar(
      cellsObserved: 1,
      totalSteps: 1,
      streakDays: 1,
      pendingVisits: 2,
      paddingTop: 0,
    ),
  ),
);

@widgetbook.UseCase(name: '00 Happy Path', type: HierarchyHeader, path: _path)
Widget hierarchyHeaderHappyPath(BuildContext context) => earthNovaStory(
  child: const Scaffold(
    body: HierarchyHeader(
      scopeLevel: 'DISTRICT',
      scopeName: 'Downtown Halifax',
      scopeCode: 'DH',
      cellsVisited: 42,
      cellsTotal: 100,
      progressPercent: 42,
      rank: 3,
      explorerCount: 2,
    ),
  ),
);

@widgetbook.UseCase(name: 'Back Navigation', type: HierarchyHeader, path: _path)
Widget hierarchyHeaderBack(BuildContext context) => earthNovaStory(
  child: Scaffold(
    body: HierarchyHeader(
      scopeLevel: 'CITY',
      scopeName: 'Halifax',
      scopeCode: 'HX',
      cellsVisited: 42,
      cellsTotal: 100,
      progressPercent: 42,
      rank: 3,
      explorerCount: 2,
      parentScopeName: 'Nova Scotia',
      onBackTap: () {},
    ),
  ),
);

@widgetbook.UseCase(name: '00 Happy Path', type: PinchHint, path: _path)
Widget pinchHintHappyPath(BuildContext context) => earthNovaStory(
  child: const Scaffold(
    body: Center(
      child: PinchHint(lowerLevelLabel: 'Map', upperLevelLabel: 'City'),
    ),
  ),
);

@widgetbook.UseCase(name: 'Upper Boundary', type: PinchHint, path: _path)
Widget pinchHintUpperBoundary(BuildContext context) => earthNovaStory(
  child: const Scaffold(
    body: Center(
      child: PinchHint(lowerLevelLabel: 'Country', upperLevelLabel: null),
    ),
  ),
);

@widgetbook.UseCase(name: '00 Happy Path', type: ShimmerCells, path: _path)
Widget shimmerCellsHappyPath(BuildContext context) =>
    _shimmer(const Size(390, 640));

@widgetbook.UseCase(name: 'Wide Geometry', type: ShimmerCells, path: _path)
Widget shimmerCellsWide(BuildContext context) => _shimmer(const Size(960, 540));

Widget _shimmer(Size size) => earthNovaStory(
  child: Scaffold(
    body: Center(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: const ShimmerCells(
          cameraPosition: (lat: 44.6488, lng: -63.5752),
          zoom: 15,
        ),
      ),
    ),
  ),
);

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: HierarchyExplorationMap,
  path: _path,
)
Widget hierarchyExplorationMapHappyPath(BuildContext context) => earthNovaStory(
  child: HierarchyExplorationMap(
    children: const [
      ChildAreaData(
        id: 'harbour',
        name: 'Harbour',
        cellsVisited: 24,
        cellsTotal: 60,
        progressPercent: 40,
      ),
      ChildAreaData(
        id: 'north',
        name: 'North End',
        cellsVisited: 0,
        cellsTotal: 48,
        progressPercent: 0,
      ),
    ],
    playerLat: MapStoryFixtures.location.lat,
    playerLng: MapStoryFixtures.location.lng,
  ),
);

@widgetbook.UseCase(
  name: 'Expected Absence',
  type: HierarchyExplorationMap,
  path: _path,
)
Widget hierarchyExplorationMapEmpty(BuildContext context) => earthNovaStory(
  child: const HierarchyExplorationMap(
    children: [],
    playerLat: null,
    playerLng: null,
  ),
);

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: DistrictFootprintMap,
  path: _path,
)
Widget districtFootprintMapHappyPath(BuildContext context) => earthNovaStory(
  child: DistrictFootprintMap(
    cells: MapStoryFixtures.cells,
    currentDistrictId: 'district-halifax',
    visitedCellIds: MapStoryFixtures.ready.visitedCellIds,
    currentCellId: 'halifax-present',
  ),
);

@widgetbook.UseCase(
  name: 'Geometry Unavailable',
  type: DistrictFootprintMap,
  path: _path,
)
Widget districtFootprintMapUnavailable(BuildContext context) => earthNovaStory(
  child: const DistrictFootprintMap(
    cells: [],
    currentDistrictId: 'district-halifax',
    visitedCellIds: {},
  ),
);

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: MapCellKnowledgeLegend,
  path: _path,
)
Widget mapCellKnowledgeLegendHappyPath(BuildContext context) => earthNovaStory(
  child: const Scaffold(body: Center(child: MapCellKnowledgeLegend())),
);

@widgetbook.UseCase(name: '00 Happy Path', type: PlayerMarker, path: _path)
Widget playerMarkerHappyPath(BuildContext context) => earthNovaStory(
  overrides: MapStoryFixtures.overrides(),
  child: const Scaffold(
    body: Center(child: PlayerMarker(trust: PlayerMarkerTrust.trusted)),
  ),
);

@widgetbook.UseCase(name: 'Ring', type: PlayerMarker, path: _path)
Widget playerMarkerRing(BuildContext context) => earthNovaStory(
  overrides: MapStoryFixtures.overrides(ring: true),
  child: const Scaffold(
    body: Center(child: PlayerMarker(trust: PlayerMarkerTrust.lowConfidence)),
  ),
);

@widgetbook.UseCase(
  name: '00 Happy Path',
  type: CellOverlayPainter,
  path: _path,
)
Widget cellOverlayPainterHappyPath(BuildContext context) =>
    _overlay(CellKnowledgeState.present);

@widgetbook.UseCase(name: 'Informed', type: CellOverlayPainter, path: _path)
Widget cellOverlayPainterInformed(BuildContext context) =>
    _overlay(CellKnowledgeState.informed, category: 'flora');

@widgetbook.UseCase(name: 'Explored', type: CellOverlayPainter, path: _path)
Widget cellOverlayPainterExplored(BuildContext context) =>
    _overlay(CellKnowledgeState.explored);

@widgetbook.UseCase(name: 'Shrouded', type: CellOverlayPainter, path: _path)
Widget cellOverlayPainterShrouded(BuildContext context) =>
    _overlay(CellKnowledgeState.shrouded);

@widgetbook.UseCase(
  name: 'Wide Geometry',
  type: CellOverlayPainter,
  path: _path,
)
Widget cellOverlayPainterWide(BuildContext context) =>
    _overlay(CellKnowledgeState.present, size: const Size(960, 540));

Widget _overlay(
  CellKnowledgeState knowledgeState, {
  String? category,
  Size size = const Size(390, 640),
}) {
  final relationship = switch (knowledgeState) {
    CellKnowledgeState.present => CellRelationship.present,
    CellKnowledgeState.informed => CellRelationship.frontier,
    CellKnowledgeState.explored => CellRelationship.explored,
    CellKnowledgeState.shrouded => CellRelationship.unknown,
  };
  return earthNovaStory(
    child: Scaffold(
      backgroundColor: const Color(0xFF172A3A),
      body: Center(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: CustomPaint(
            painter: CellOverlayPainter(
              cellsWithStates: [
                (
                  cell: MapStoryFixtures.cells.first,
                  state: CellState(
                    knowledgeState: knowledgeState,
                    category: category,
                    relationship: relationship,
                    contents: CellContents.empty,
                  ),
                ),
              ],
              cameraPosition: (
                lat: MapStoryFixtures.location.lat,
                lng: MapStoryFixtures.location.lng,
              ),
              zoom: 15,
              cameraPixelOffset: Offset(size.width / 2, size.height / 2),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
}
