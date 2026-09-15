import 'dart:io';
import 'dart:ui' as ui;

import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/domain/entities/player_marker_state.dart';
import 'package:earth_nova/features/map/domain/repositories/hierarchy_repository.dart';
import 'package:earth_nova/ui/product_surfaces/map/rendering/cell_overlay_painter.dart';
import 'package:earth_nova/ui/product_surfaces/map/rendering/fog_renderer.dart';
import 'package:earth_nova/ui/product_surfaces/map/rendering/player_marker.dart';
import 'package:earth_nova/features/map/presentation/providers/player_marker_provider.dart';
import 'package:earth_nova/ui/product_surfaces/map/screens/map_screen.dart';
import 'package:earth_nova/ui/product_surfaces/map/widgets/district_footprint_map.dart';
import 'package:earth_nova/ui/product_surfaces/map/widgets/hierarchy_exploration_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_test/flutter_test.dart';

const _assetRoot = '.agents/qa/assets/shadcn-phase-4';
const _captureEnabled = bool.fromEnvironment('PHASE4_CAPTURE');
const _captureKey = ValueKey('phase-four-capture');
const _neutralScheme = ColorScheme.dark(
  surface: Color(0xFF181818),
  onSurface: Color(0xFFF2F2F2),
  onSurfaceVariant: Color(0xFFB0B0B0),
);
const _grayscaleMatrix = <double>[
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

class _StaticPlayerMarkerNotifier extends PlayerMarkerNotifier {
  @override
  PlayerMarkerState build() => const PlayerMarkerState(
    lat: 45.9636,
    lng: -66.6431,
    isRing: false,
    gapDistance: 0,
  );
}

void main() {
  final captures =
      <
        ({
          String name,
          Size size,
          Widget child,
          bool grayscale,
          bool hasPlayerMarker,
        })
      >[
        for (final viewport in const [
          (name: '390x844', size: Size(390, 844)),
          (name: '1440x900', size: Size(1440, 900)),
        ]) ...[
          (
            name: 'map/map-semantic-${viewport.name}.png',
            size: viewport.size,
            child: const _SemanticMapScene(),
            grayscale: false,
            hasPlayerMarker: true,
          ),
          (
            name: 'map/map-semantic-${viewport.name}-grayscale.png',
            size: viewport.size,
            child: const _SemanticMapScene(),
            grayscale: true,
            hasPlayerMarker: true,
          ),
        ],
        for (final fixture in const [
          (
            name: 'marker/marker-trust-rings-390x320.png',
            size: Size(390, 320),
            child: _MarkerTrustScene(),
          ),
          (
            name: 'district/district-organic-390x844.png',
            size: Size(390, 844),
            child: _DistrictScene(),
          ),
          (
            name: 'hierarchy/state-neutral-390x844.png',
            size: Size(390, 844),
            child: _StateHierarchyScene(),
          ),
          (
            name: 'hierarchy/world-neutral-390x844.png',
            size: Size(390, 844),
            child: _WorldHierarchyScene(),
          ),
        ]) ...[
          (
            name: fixture.name,
            size: fixture.size,
            child: fixture.child,
            grayscale: false,
            hasPlayerMarker: false,
          ),
          (
            name:
                '${fixture.name.substring(0, fixture.name.length - 4)}-grayscale.png',
            size: fixture.size,
            child: fixture.child,
            grayscale: true,
            hasPlayerMarker: false,
          ),
        ],
      ];

  for (final capture in captures) {
    testWidgets('renders ${capture.name}', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _capture(
        tester,
        size: capture.size,
        name: capture.name,
        child: capture.child,
        grayscale: capture.grayscale,
      );
      if (capture.hasPlayerMarker) {
        expect(find.byType(PlayerMarker), findsOneWidget);
      }
    }, skip: !_captureEnabled);
  }

  test('keeps Phase 4 evidence geometry and contrast objective', () {
    for (final cell in [..._mapCells, ..._districtCells]) {
      expect(cell.primaryExteriorRing.length, greaterThan(4));
    }
    expect(
      _contrastRatio(const Color(0xFFF2F2F2), explorationColor(69, 51)),
      greaterThanOrEqualTo(4.5),
    );
    final alphas = [
      _present,
      _explored,
      _informed,
      _shrouded,
    ].map((state) => FogRenderer.fillColor(state).a).toList();
    expect(alphas[0], lessThan(alphas[1]));
    expect(alphas[1], lessThan(alphas[2]));
    expect(alphas[2], lessThan(alphas[3]));
  });
}

Future<void> _capture(
  WidgetTester tester, {
  required Size size,
  required String name,
  required Widget child,
  bool grayscale = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  await (FontLoader('packages/shadcn_ui/Geist')
        ..addFont(rootBundle.load('packages/shadcn_ui/fonts/Geist[wght].ttf')))
      .load();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        playerMarkerProvider.overrideWith(_StaticPlayerMarkerNotifier.new),
      ],
      child: ShadApp(
        home: Theme(
          data: ThemeData(
            useMaterial3: true,
            colorScheme: _neutralScheme,
            fontFamily: 'packages/shadcn_ui/Geist',
          ),
          child: MediaQuery(
            data: MediaQueryData(size: size, disableAnimations: true),
            child: RepaintBoundary(
              key: _captureKey,
              child: grayscale
                  ? ColorFiltered(
                      colorFilter: const ColorFilter.matrix(_grayscaleMatrix),
                      child: child,
                    )
                  : child,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  final image = await boundary.toImage(pixelRatio: 1);
  expect(image.width, size.width.toInt());
  expect(image.height, size.height.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();

  final file = File('$_assetRoot/$name');
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
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

class _SemanticMapScene extends StatelessWidget {
  const _SemanticMapScene();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF686868),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          return Stack(
            fit: StackFit.expand,
            children: [
              const CustomPaint(painter: _FixtureBasemapPainter()),
              RepaintBoundary(
                child: CustomPaint(
                  painter: CellOverlayPainter(
                    cellsWithStates: const [
                      (cell: _mapPresent, state: _present),
                      (cell: _mapInformed, state: _informed),
                      (cell: _mapExplored, state: _explored),
                      (cell: _mapShrouded, state: _shrouded),
                    ],
                    project: (coord) =>
                        Offset(coord.lng * size.width, coord.lat * size.height),
                  ),
                ),
              ),
              const Align(
                alignment: Alignment(-0.5, -0.5),
                child: PlayerMarker(trust: PlayerMarkerTrust.trusted),
              ),
              const Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: MapCellKnowledgeLegend(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FixtureBasemapPainter extends CustomPainter {
  const _FixtureBasemapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF686868),
    );
    final road = Paint()
      ..color = const Color(0xFFBBBBBB)
      ..strokeWidth = 5;
    final minorRoad = Paint()
      ..color = const Color(0xFF3D3D3D)
      ..strokeWidth = 2;
    for (var i = -2; i < 8; i++) {
      final y = size.height * (i / 6);
      canvas.drawLine(
        Offset.zero.translate(0, y),
        Offset(size.width, y + size.height * 0.22),
        road,
      );
      final x = size.width * (i / 6);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.width * 0.18, size.height),
        minorRoad,
      );
    }
    canvas.drawCircle(
      Offset(size.width * 0.76, size.height * 0.24),
      size.shortestSide * 0.12,
      Paint()..color = const Color(0xFF909090),
    );
  }

  @override
  bool shouldRepaint(covariant _FixtureBasemapPainter oldDelegate) => false;
}

class _MarkerTrustScene extends StatelessWidget {
  const _MarkerTrustScene();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF181818),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Marker trust states',
                style: TextStyle(color: Color(0xFFF2F2F2), fontSize: 18),
              ),
            ),
            Expanded(
              child: Row(
                children: const [
                  Expanded(
                    child: _MarkerSubstrate(
                      label: 'LOW CONFIDENCE · LIGHT',
                      color: Color(0xFFE8E8E8),
                      trust: PlayerMarkerTrust.lowConfidence,
                      darkLabel: true,
                    ),
                  ),
                  Expanded(
                    child: _MarkerSubstrate(
                      label: 'PAUSED · DARK',
                      color: Color(0xFF181818),
                      trust: PlayerMarkerTrust.paused,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkerSubstrate extends StatelessWidget {
  const _MarkerSubstrate({
    required this.label,
    required this.color,
    required this.trust,
    this.darkLabel = false,
  });

  final String label;
  final Color color;
  final PlayerMarkerTrust trust;
  final bool darkLabel;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: color,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PlayerMarker(trust: trust),
          const SizedBox(height: 20),
          Text(
            label,
            style: TextStyle(
              color: darkLabel
                  ? const Color(0xFF181818)
                  : const Color(0xFFF2F2F2),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _DistrictScene extends StatelessWidget {
  const _DistrictScene();

  @override
  Widget build(BuildContext context) {
    return const DistrictFootprintMap(
      districtBoundary: _districtFixtureBoundary,
      cells: _districtCells,
      currentDistrictId: 'district-a',
      visitedCellIds: {'district-current', 'district-visited'},
      currentCellId: 'district-current',
    );
  }
}

class _StateHierarchyScene extends StatelessWidget {
  const _StateHierarchyScene();

  @override
  Widget build(BuildContext context) {
    return const HierarchyExplorationMap(
      children: [
        ChildAreaData(
          id: 'district-0',
          name: 'North',
          cellsVisited: 0,
          cellsTotal: 80,
          progressPercent: 0,
        ),
        ChildAreaData(
          id: 'district-5',
          name: 'West',
          cellsVisited: 5,
          cellsTotal: 80,
          progressPercent: 6.25,
        ),
        ChildAreaData(
          id: 'district-16',
          name: 'Central',
          cellsVisited: 16,
          cellsTotal: 80,
          progressPercent: 20,
        ),
        ChildAreaData(
          id: 'district-31',
          name: 'East',
          cellsVisited: 31,
          cellsTotal: 80,
          progressPercent: 38.75,
        ),
        ChildAreaData(
          id: 'district-51',
          name: 'South',
          cellsVisited: 51,
          cellsTotal: 74,
          progressPercent: 69,
        ),
        ChildAreaData(
          id: 'district-70',
          name: 'Coast',
          cellsVisited: 70,
          cellsTotal: 100,
          progressPercent: 70,
        ),
      ],
      playerLat: 45.96,
      playerLng: -66.64,
    );
  }
}

class _WorldHierarchyScene extends StatelessWidget {
  const _WorldHierarchyScene();

  @override
  Widget build(BuildContext context) {
    return const HierarchyExplorationMap(
      children: [
        ChildAreaData(
          id: 'country-0',
          name: 'Unseen',
          cellsVisited: 0,
          cellsTotal: 100,
          progressPercent: 0,
        ),
        ChildAreaData(
          id: 'country-12',
          name: 'Surveyed',
          cellsVisited: 12,
          cellsTotal: 100,
          progressPercent: 12,
        ),
        ChildAreaData(
          id: 'country-35',
          name: 'Known',
          cellsVisited: 35,
          cellsTotal: 100,
          progressPercent: 35,
        ),
        ChildAreaData(
          id: 'country-69',
          name: 'Mapped',
          cellsVisited: 69,
          cellsTotal: 100,
          progressPercent: 69,
        ),
        ChildAreaData(
          id: 'country-78',
          name: 'Familiar',
          cellsVisited: 78,
          cellsTotal: 100,
          progressPercent: 78,
        ),
        ChildAreaData(
          id: 'country-92',
          name: 'Complete',
          cellsVisited: 92,
          cellsTotal: 100,
          progressPercent: 92,
        ),
      ],
      playerLat: null,
      playerLng: null,
    );
  }
}

const _present = CellState(
  knowledgeState: CellKnowledgeState.present,
  relationship: CellRelationship.present,
  contents: CellContents.empty,
);
const _informed = CellState(
  knowledgeState: CellKnowledgeState.informed,
  category: 'fauna',
  relationship: CellRelationship.explored,
  contents: CellContents.empty,
);
const _explored = CellState(
  knowledgeState: CellKnowledgeState.explored,
  relationship: CellRelationship.explored,
  contents: CellContents.empty,
);
const _shrouded = CellState(
  knowledgeState: CellKnowledgeState.shrouded,
  relationship: CellRelationship.unknown,
  contents: CellContents.empty,
);

const _mapPresent = Cell(
  id: 'present',
  habitats: [],
  polygons: [
    [
      [
        (lat: 0.02, lng: 0.02),
        (lat: 0.02, lng: 0.49),
        (lat: 0.28, lng: 0.52),
        (lat: 0.52, lng: 0.47),
        (lat: 0.48, lng: 0.25),
        (lat: 0.55, lng: 0.02),
      ],
    ],
  ],
  districtId: 'district-a',
  cityId: 'city-a',
  stateId: 'state-a',
  countryId: 'country-a',
);
const _mapInformed = Cell(
  id: 'informed',
  habitats: [],
  polygons: [
    [
      [
        (lat: 0.02, lng: 0.49),
        (lat: 0.02, lng: 0.98),
        (lat: 0.50, lng: 0.98),
        (lat: 0.54, lng: 0.72),
        (lat: 0.52, lng: 0.47),
        (lat: 0.28, lng: 0.52),
      ],
    ],
  ],
  districtId: 'district-a',
  cityId: 'city-a',
  stateId: 'state-a',
  countryId: 'country-a',
);
const _mapExplored = Cell(
  id: 'explored',
  habitats: [],
  polygons: [
    [
      [
        (lat: 0.55, lng: 0.02),
        (lat: 0.48, lng: 0.25),
        (lat: 0.52, lng: 0.47),
        (lat: 0.75, lng: 0.50),
        (lat: 0.98, lng: 0.46),
        (lat: 0.98, lng: 0.02),
      ],
    ],
  ],
  districtId: 'district-a',
  cityId: 'city-a',
  stateId: 'state-a',
  countryId: 'country-a',
);
const _mapShrouded = Cell(
  id: 'shrouded',
  habitats: [],
  polygons: [
    [
      [
        (lat: 0.52, lng: 0.47),
        (lat: 0.54, lng: 0.72),
        (lat: 0.50, lng: 0.98),
        (lat: 0.98, lng: 0.98),
        (lat: 0.98, lng: 0.46),
        (lat: 0.75, lng: 0.50),
      ],
    ],
  ],
  districtId: 'district-a',
  cityId: 'city-a',
  stateId: 'state-a',
  countryId: 'country-a',
);
const _mapCells = [_mapPresent, _mapInformed, _mapExplored, _mapShrouded];

const _districtFixtureBoundary = DistrictBoundary(
  polygons: [
    [
      [
        (lat: 45.958, lng: -66.653),
        (lat: 45.958, lng: -66.635),
        (lat: 45.972, lng: -66.635),
        (lat: 45.972, lng: -66.653),
        (lat: 45.958, lng: -66.653),
      ],
    ],
  ],
);

const _districtCells = [
  Cell(
    id: 'district-current',
    habitats: [],
    polygons: [
      [
        [
          (lat: 45.9650, lng: -66.6470),
          (lat: 45.9661, lng: -66.6440),
          (lat: 45.9648, lng: -66.6410),
          (lat: 45.9622, lng: -66.6402),
          (lat: 45.9608, lng: -66.6432),
          (lat: 45.9621, lng: -66.6464),
        ],
      ],
    ],
    districtId: 'district-a',
    cityId: 'city-a',
    stateId: 'state-a',
    countryId: 'country-a',
  ),
  Cell(
    id: 'district-visited',
    habitats: [],
    polygons: [
      [
        [
          (lat: 45.9690, lng: -66.6510),
          (lat: 45.9710, lng: -66.6471),
          (lat: 45.9698, lng: -66.6440),
          (lat: 45.9661, lng: -66.6440),
          (lat: 45.9650, lng: -66.6470),
          (lat: 45.9667, lng: -66.6504),
        ],
      ],
    ],
    districtId: 'district-a',
    cityId: 'city-a',
    stateId: 'state-a',
    countryId: 'country-a',
  ),
  Cell(
    id: 'district-unvisited',
    habitats: [],
    polygons: [
      [
        [
          (lat: 45.9648, lng: -66.6410),
          (lat: 45.9661, lng: -66.6380),
          (lat: 45.9637, lng: -66.6358),
          (lat: 45.9605, lng: -66.6367),
          (lat: 45.9594, lng: -66.6395),
          (lat: 45.9622, lng: -66.6402),
        ],
      ],
    ],
    districtId: 'district-a',
    cityId: 'city-a',
    stateId: 'state-a',
    countryId: 'country-a',
  ),
  Cell(
    id: 'context-north',
    habitats: [],
    polygons: [
      [
        [
          (lat: 45.9737, lng: -66.6550),
          (lat: 45.9750, lng: -66.6495),
          (lat: 45.9733, lng: -66.6443),
          (lat: 45.9710, lng: -66.6471),
          (lat: 45.9690, lng: -66.6510),
          (lat: 45.9708, lng: -66.6544),
        ],
      ],
    ],
    districtId: 'district-b',
    cityId: 'city-a',
    stateId: 'state-a',
    countryId: 'country-a',
  ),
  Cell(
    id: 'context-east',
    habitats: [],
    polygons: [
      [
        [
          (lat: 45.9698, lng: -66.6440),
          (lat: 45.9714, lng: -66.6397),
          (lat: 45.9685, lng: -66.6355),
          (lat: 45.9661, lng: -66.6380),
          (lat: 45.9648, lng: -66.6410),
          (lat: 45.9661, lng: -66.6440),
        ],
      ],
    ],
    districtId: 'district-c',
    cityId: 'city-a',
    stateId: 'state-a',
    countryId: 'country-a',
  ),
];
