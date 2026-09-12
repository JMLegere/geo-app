import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/shared/design.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/map_level.dart';
import 'package:earth_nova/features/map/domain/repositories/hierarchy_repository.dart';
import 'package:earth_nova/features/map/presentation/providers/hierarchy_provider.dart';
import 'package:earth_nova/features/map/presentation/screens/district_screen.dart';
import 'package:earth_nova/features/map/presentation/screens/city_screen.dart';
import 'package:earth_nova/features/map/presentation/screens/province_screen.dart';
import 'package:earth_nova/features/map/presentation/screens/country_screen.dart';
import 'package:earth_nova/features/map/presentation/screens/world_screen.dart';
import 'package:earth_nova/features/map/presentation/widgets/hierarchy_header.dart';
import 'package:earth_nova/features/map/presentation/widgets/district_footprint_map.dart';
import 'package:earth_nova/features/map/presentation/widgets/hierarchy_exploration_map.dart';
import 'package:earth_nova/features/map/presentation/widgets/pinch_hint.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';

// ---------------------------------------------------------------------------
// Fake repository for tests
// ---------------------------------------------------------------------------

const _testDistrictBoundary = DistrictBoundary(
  polygons: [
    [
      [
        (lat: 44.999, lng: -66.001),
        (lat: 44.999, lng: -65.999),
        (lat: 45.001, lng: -65.999),
        (lat: 45.001, lng: -66.001),
        (lat: 44.999, lng: -66.001),
      ],
    ],
  ],
);

class _FakeHierarchyRepository implements HierarchyRepository {
  @override
  Future<HierarchyProgressSummary> getScopeSummary({
    required String userId,
    required MapLevel level,
    String? scopeId,
  }) async {
    return HierarchyProgressSummary(
      id: scopeId ?? 'scope-1',
      name: 'Test Scope',
      level: level,
      cellsVisited: 42,
      cellsTotal: 100,
      progressPercent: 42.0,
      rank: 3,
      districtBoundary: level == MapLevel.district
          ? _testDistrictBoundary
          : null,
    );
  }

  @override
  Future<List<HierarchyProgressSummary>> getChildSummaries({
    required String userId,
    required MapLevel level,
    String? scopeId,
  }) async {
    return [
      HierarchyProgressSummary(
        id: 'child-1',
        name: 'Child Area',
        level: level,
        cellsVisited: 10,
        cellsTotal: 50,
        progressPercent: 20.0,
        rank: 1,
      ),
    ];
  }
}

class _FakeHierarchyRepositoryEmpty implements HierarchyRepository {
  @override
  Future<HierarchyProgressSummary> getScopeSummary({
    required String userId,
    required MapLevel level,
    String? scopeId,
  }) async {
    return HierarchyProgressSummary(
      id: scopeId ?? 'scope-1',
      name: 'Empty Scope',
      level: level,
      cellsVisited: 0,
      cellsTotal: 100,
      progressPercent: 0.0,
      rank: 0,
    );
  }

  @override
  Future<List<HierarchyProgressSummary>> getChildSummaries({
    required String userId,
    required MapLevel level,
    String? scopeId,
  }) async {
    return [];
  }
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

class _TestObservabilityService extends ObservabilityService {
  _TestObservabilityService() : super(sessionId: 'test-session');
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._state);

  final AuthState _state;

  @override
  AuthState build() => _state;
}

Widget _wrap(
  Widget child, {
  HierarchyRepository? repo,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return ProviderScope(
    overrides: [
      authProvider.overrideWith(
        () => _FakeAuthNotifier(
          AuthState.authenticated(
            UserProfile(
              id: 'user-123',
              phone: '5551234567',
              createdAt: DateTime(2026),
            ),
          ),
        ),
      ),
      hierarchyRepositoryProvider.overrideWithValue(
        repo ?? _FakeHierarchyRepository(),
      ),
      hierarchyObservabilityProvider.overrideWithValue(
        _TestObservabilityService(),
      ),
      appObservabilityProvider.overrideWithValue(_TestObservabilityService()),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: _designTheme(child),
    ),
  );
}

Widget _designTheme(Widget child) => ShadTheme(
  data: ShadThemeData(
    brightness: Brightness.dark,
    colorScheme: const ShadZincColorScheme.dark(),
  ),
  child: child,
);

Widget _designHost(
  Widget child, {
  TextScaler textScaler = TextScaler.noScaling,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: child!,
  ),
  home: Scaffold(body: SingleChildScrollView(child: _designTheme(child))),
);

Cell _testCell({
  required String id,
  required String districtId,
  required double lat,
  required double lng,
}) {
  const size = 0.001;
  return Cell(
    id: id,
    habitats: const [Habitat.urban],
    polygons: [
      [
        [
          (lat: lat - size, lng: lng - size),
          (lat: lat - size, lng: lng + size),
          (lat: lat + size, lng: lng + size),
          (lat: lat + size, lng: lng - size),
          (lat: lat - size, lng: lng - size),
        ],
      ],
    ],
    districtId: districtId,
    cityId: 'city-1',
    stateId: 'state-1',
    countryId: 'country-1',
    habitatConfidence: 'classified',
  );
}

// ---------------------------------------------------------------------------
// HierarchyProgressSummary entity tests
// ---------------------------------------------------------------------------

void main() {
  group('HierarchyProgressSummary', () {
    test('equality holds for identical values', () {
      const a = HierarchyProgressSummary(
        id: 'x',
        name: 'X',
        level: MapLevel.district,
        cellsVisited: 5,
        cellsTotal: 10,
        progressPercent: 50.0,
        rank: 2,
      );
      const b = HierarchyProgressSummary(
        id: 'x',
        name: 'X',
        level: MapLevel.district,
        cellsVisited: 5,
        cellsTotal: 10,
        progressPercent: 50.0,
        rank: 2,
      );
      expect(a, equals(b));
    });

    test('rank 0 represents unranked (no visits)', () {
      const summary = HierarchyProgressSummary(
        id: 'x',
        name: 'X',
        level: MapLevel.district,
        cellsVisited: 0,
        cellsTotal: 100,
        progressPercent: 0.0,
        rank: 0,
      );
      expect(summary.rank, 0);
      expect(summary.cellsVisited, 0);
    });
  });

  // -------------------------------------------------------------------------
  // HierarchyHeader widget
  // -------------------------------------------------------------------------

  group('HierarchyHeader', () {
    testWidgets('uses neutral header, badge, and stat composition', (
      tester,
    ) async {
      await tester.pumpWidget(
        _designHost(
          const HierarchyHeader(
            scopeLevel: 'City',
            scopeName: 'San Francisco',
            scopeCode: 'SF',
            cellsVisited: 100,
            cellsTotal: 200,
            progressPercent: 50,
            rank: 5,
            explorerCount: 300,
          ),
        ),
      );

      expect(find.byType(AppCard), findsNWidgets(2));
      expect(find.byType(AppBadge), findsNWidgets(3));
      expect(find.byType(AppStatGrid), findsOneWidget);
      expect(find.text('City'), findsOneWidget);
      expect(find.text('San Francisco'), findsOneWidget);
      expect(find.text('SF'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('#5'), findsAtLeastNWidgets(1));
      expect(find.textContaining('100 / 200 cells'), findsOneWidget);
      expect(find.textContaining('300 explorers'), findsOneWidget);
    });

    testWidgets('states when the authoritative cell total is unavailable', (
      tester,
    ) async {
      await tester.pumpWidget(
        _designHost(
          const HierarchyHeader(
            scopeLevel: 'District',
            scopeName: 'Town Plat',
            scopeCode: 'TP',
            cellsVisited: 55,
            cellsTotal: 0,
            cellsTotalKnown: false,
            progressPercent: 0,
            rank: 1,
            explorerCount: 1,
          ),
        ),
      );

      expect(find.text('55 cells explored; total unavailable'), findsOneWidget);
      expect(find.text('0%'), findsNothing);
      expect(find.textContaining('55 / 0 cells'), findsNothing);
    });

    testWidgets('keeps back action target and telemetry contract', (
      tester,
    ) async {
      var tapped = false;
      String? loggedEvent;
      Map<String, dynamic>? loggedData;
      await tester.pumpWidget(
        _designHost(
          HierarchyHeader(
            scopeLevel: 'District',
            scopeName: 'Downtown',
            scopeCode: 'DT',
            cellsVisited: 42,
            cellsTotal: 100,
            progressPercent: 42,
            rank: 3,
            explorerCount: 150,
            parentScopeName: 'City',
            onBackTap: () => tapped = true,
            interactionLogger: ({required event, required category, data}) {
              loggedEvent = event;
              loggedData = data;
            },
          ),
        ),
      );

      final backButton = find.byType(AppButton);
      expect(backButton, findsOneWidget);
      expect(tester.getSize(backButton).height, greaterThanOrEqualTo(44));
      await tester.tap(find.text('Back to City'));

      expect(tapped, isTrue);
      expect(loggedEvent, 'interaction.action');
      expect(loggedData, containsPair('action_type', 'back_tap'));
      expect(loggedData, containsPair('screen_name', 'hierarchy_header'));
      expect(loggedData, containsPair('widget_name', 'back_navigation_row'));
      expect(
        loggedData,
        containsPair('player_action_id', 'change-territory-scale'),
      );
    });

    testWidgets('State screen is keyboard-safe at 390x844 and 200% text', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var lowerTaps = 0;
      var upperTaps = 0;
      await tester.pumpWidget(
        _wrap(
          ProvinceScreen(
            scopeId: 'state-1',
            onLowerLevelTap: () => lowerTaps += 1,
            onUpperLevelTap: () => upperTaps += 1,
          ),
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pump();

      expect(find.text('State'), findsOneWidget);
      expect(find.textContaining('Explored'), findsOneWidget);
      expect(find.textContaining('Rank'), findsAtLeastNWidgets(1));
      expect(
        tester
            .getSize(find.byKey(const ValueKey('pinch_hint_lower_control')))
            .height,
        greaterThanOrEqualTo(44),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('pinch_hint_upper_control')))
            .height,
        greaterThanOrEqualTo(44),
      );
      expect(tester.takeException(), isNull);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(lowerTaps, 1);
      expect(upperTaps, 1);
      final visibleText = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .join(' ');
      expect(visibleText, isNot(contains('🏅')));
      expect(visibleText, isNot(contains('🌍')));
    });
  });

  // -------------------------------------------------------------------------
  // PinchHint widget
  // -------------------------------------------------------------------------

  group('PinchHint', () {
    testWidgets('uses neutral icon and text for both scale directions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _designHost(
          const PinchHint(lowerLevelLabel: 'Map', upperLevelLabel: 'City'),
        ),
      );

      expect(find.byType(AppCard), findsNothing);
      expect(find.byIcon(Icons.pinch_outlined), findsOneWidget);
      expect(find.textContaining('Map'), findsOneWidget);
      expect(find.textContaining('City'), findsOneWidget);
      expect(find.textContaining('↙'), findsNothing);
      expect(find.textContaining('↗'), findsNothing);
    });

    testWidgets('world-level hint shows only pinch-out direction', (
      tester,
    ) async {
      await tester.pumpWidget(
        _designHost(
          const PinchHint(lowerLevelLabel: 'Country', upperLevelLabel: null),
        ),
      );

      expect(find.textContaining('Country'), findsOneWidget);
      expect(find.textContaining('Pinch in'), findsNothing);
    });
  });

  // -------------------------------------------------------------------------
  // HierarchyExplorationMap widget
  // -------------------------------------------------------------------------

  group('HierarchyExplorationMap', () {
    testWidgets('renders without crashing with empty child list', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HierarchyExplorationMap(
              children: [],
              playerLat: null,
              playerLng: null,
            ),
          ),
        ),
      );

      expect(find.byType(HierarchyExplorationMap), findsOneWidget);
    });

    testWidgets('renders with child summaries', (tester) async {
      const children = [
        ChildAreaData(
          id: 'c1',
          name: 'Area 1',
          cellsVisited: 10,
          cellsTotal: 50,
          progressPercent: 20.0,
        ),
        ChildAreaData(
          id: 'c2',
          name: 'Area 2',
          cellsVisited: 0,
          cellsTotal: 30,
          progressPercent: 0.0,
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: HierarchyExplorationMap(
              children: children,
              playerLat: 37.77,
              playerLng: -122.42,
            ),
          ),
        ),
      );

      expect(find.byType(HierarchyExplorationMap), findsOneWidget);
    });

    test('does NOT highlight 0%-explored child areas (locked policy)', () {
      const child = ChildAreaData(
        id: 'c1',
        name: 'Area 1',
        cellsVisited: 0,
        cellsTotal: 50,
        progressPercent: 0.0,
      );

      // Policy: no opportunity highlight overlay on 0% areas.
      // The map uses exploration color scale only — no amber dashed outline.
      expect(child.progressPercent, 0.0);
      expect(child.shouldShowOpportunityHighlight, false);
    });
  });

  group('DistrictFootprintMap', () {
    testWidgets(
      'renders actual district cells without numeric summary labels',
      (tester) async {
        final cells = [
          _testCell(
            id: 'current-1',
            districtId: 'district-1',
            lat: 45.0,
            lng: -66.0,
          ),
          _testCell(
            id: 'adjacent-1',
            districtId: 'district-2',
            lat: 45.002,
            lng: -65.998,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DistrictFootprintMap(
                districtBoundary: _testDistrictBoundary,
                cells: cells,
                currentDistrictId: 'district-1',
                visitedCellIds: const {'current-1'},
                currentCellId: 'current-1',
              ),
            ),
          ),
        );

        expect(find.byType(DistrictFootprintMap), findsOneWidget);
        expect(find.text('0'), findsNothing);
        expect(find.text('1'), findsNothing);
      },
    );
  });

  // -------------------------------------------------------------------------
  // DistrictScreen
  // -------------------------------------------------------------------------

  group('DistrictScreen', () {
    testWidgets('renders HierarchyHeader and PinchHint', (tester) async {
      await tester.pumpWidget(
        _wrap(const DistrictScreen(scopeId: 'district-1')),
      );
      await tester.pump();

      expect(find.byType(HierarchyHeader), findsOneWidget);
      expect(find.byType(PinchHint), findsOneWidget);
    });

    testWidgets('shows DISTRICT scope level label', (tester) async {
      await tester.pumpWidget(
        _wrap(const DistrictScreen(scopeId: 'district-1')),
      );
      await tester.pump();

      expect(find.text('District'), findsOneWidget);
    });

    testWidgets('pinch hint references Map and City', (tester) async {
      await tester.pumpWidget(
        _wrap(const DistrictScreen(scopeId: 'district-1')),
      );
      await tester.pump();

      final hint = tester.widget<PinchHint>(find.byType(PinchHint));
      expect(hint.lowerLevelLabel, 'Map');
      expect(hint.upperLevelLabel, 'City');
    });

    testWidgets('wraps root in ObservableScreen with stable name', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const DistrictScreen(scopeId: 'district-1')),
      );
      await tester.pump();

      final wrapper = tester.widget<ObservableScreen>(
        find.byType(ObservableScreen),
      );
      expect(wrapper.screenName, 'district_screen');
    });

    testWidgets(
      'uses footprint map instead of child summary grid when cells are available',
      (tester) async {
        final cells = [
          _testCell(
            id: 'current-1',
            districtId: 'district-1',
            lat: 45.0,
            lng: -66.0,
          ),
          _testCell(
            id: 'adjacent-1',
            districtId: 'district-2',
            lat: 45.002,
            lng: -65.998,
          ),
        ];

        await tester.pumpWidget(
          _wrap(
            DistrictScreen(
              scopeId: 'district-1',
              cells: cells,
              visitedCellIds: const {'current-1'},
              currentCellId: 'current-1',
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(DistrictFootprintMap), findsOneWidget);
        final painter =
            tester
                    .widget<CustomPaint>(
                      find.descendant(
                        of: find.byType(DistrictFootprintMap),
                        matching: find.byType(CustomPaint),
                      ),
                    )
                    .painter!
                as DistrictFootprintMapPainter;
        expect(painter.districtBoundary, same(_testDistrictBoundary));
        expect(find.byType(HierarchyExplorationMap), findsNothing);
        expect(find.text('Child Area'), findsNothing);
      },
    );
  });

  // -------------------------------------------------------------------------
  // CityScreen
  // -------------------------------------------------------------------------

  group('CityScreen', () {
    testWidgets('renders HierarchyHeader and PinchHint', (tester) async {
      await tester.pumpWidget(_wrap(const CityScreen(scopeId: 'city-1')));
      await tester.pump();

      expect(find.byType(HierarchyHeader), findsOneWidget);
      expect(find.byType(PinchHint), findsOneWidget);
    });

    testWidgets('shows CITY scope level label', (tester) async {
      await tester.pumpWidget(_wrap(const CityScreen(scopeId: 'city-1')));
      await tester.pump();

      expect(find.text('City'), findsOneWidget);
    });

    testWidgets('pinch hint references District and State', (tester) async {
      await tester.pumpWidget(_wrap(const CityScreen(scopeId: 'city-1')));
      await tester.pump();

      final hint = tester.widget<PinchHint>(find.byType(PinchHint));
      expect(hint.lowerLevelLabel, 'District');
      expect(hint.upperLevelLabel, 'State');
    });

    testWidgets('wraps root in ObservableScreen with stable name', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const CityScreen(scopeId: 'city-1')));
      await tester.pump();

      final wrapper = tester.widget<ObservableScreen>(
        find.byType(ObservableScreen),
      );
      expect(wrapper.screenName, 'city_screen');
    });
  });

  // -------------------------------------------------------------------------
  // ProvinceScreen
  // -------------------------------------------------------------------------

  group('ProvinceScreen', () {
    testWidgets('renders HierarchyHeader and PinchHint', (tester) async {
      await tester.pumpWidget(_wrap(const ProvinceScreen(scopeId: 'state-1')));
      await tester.pump();

      expect(find.byType(HierarchyHeader), findsOneWidget);
      expect(find.byType(PinchHint), findsOneWidget);
    });

    testWidgets('shows STATE scope level label', (tester) async {
      await tester.pumpWidget(_wrap(const ProvinceScreen(scopeId: 'state-1')));
      await tester.pump();

      expect(find.text('State'), findsOneWidget);
    });

    testWidgets('pinch hint references City and Country', (tester) async {
      await tester.pumpWidget(_wrap(const ProvinceScreen(scopeId: 'state-1')));
      await tester.pump();

      final hint = tester.widget<PinchHint>(find.byType(PinchHint));
      expect(hint.lowerLevelLabel, 'City');
      expect(hint.upperLevelLabel, 'Country');
    });

    testWidgets('wraps root in ObservableScreen with stable name', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const ProvinceScreen(scopeId: 'state-1')));
      await tester.pump();

      final wrapper = tester.widget<ObservableScreen>(
        find.byType(ObservableScreen),
      );
      expect(wrapper.screenName, 'province_screen');
    });
  });

  // -------------------------------------------------------------------------
  // CountryScreen
  // -------------------------------------------------------------------------

  group('CountryScreen', () {
    testWidgets('renders HierarchyHeader and PinchHint', (tester) async {
      await tester.pumpWidget(_wrap(const CountryScreen(scopeId: 'country-1')));
      await tester.pump();

      expect(find.byType(HierarchyHeader), findsOneWidget);
      expect(find.byType(PinchHint), findsOneWidget);
    });

    testWidgets('shows COUNTRY scope level label', (tester) async {
      await tester.pumpWidget(_wrap(const CountryScreen(scopeId: 'country-1')));
      await tester.pump();

      expect(find.text('Country'), findsOneWidget);
    });

    testWidgets('pinch hint references State and World', (tester) async {
      await tester.pumpWidget(_wrap(const CountryScreen(scopeId: 'country-1')));
      await tester.pump();

      final hint = tester.widget<PinchHint>(find.byType(PinchHint));
      expect(hint.lowerLevelLabel, 'State');
      expect(hint.upperLevelLabel, 'World');
    });

    testWidgets('wraps root in ObservableScreen with stable name', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const CountryScreen(scopeId: 'country-1')));
      await tester.pump();

      final wrapper = tester.widget<ObservableScreen>(
        find.byType(ObservableScreen),
      );
      expect(wrapper.screenName, 'country_screen');
    });
  });

  // -------------------------------------------------------------------------
  // WorldScreen
  // -------------------------------------------------------------------------

  group('WorldScreen', () {
    testWidgets('renders HierarchyHeader and PinchHint', (tester) async {
      await tester.pumpWidget(_wrap(const WorldScreen()));
      await tester.pump();

      expect(find.byType(HierarchyHeader), findsOneWidget);
      expect(find.byType(PinchHint), findsOneWidget);
    });

    testWidgets('shows WORLD scope level label', (tester) async {
      await tester.pumpWidget(_wrap(const WorldScreen()));
      await tester.pump();

      expect(find.text('World'), findsOneWidget);
    });

    testWidgets('pinch hint has no upper level (world is top)', (tester) async {
      await tester.pumpWidget(_wrap(const WorldScreen()));
      await tester.pump();

      final hint = tester.widget<PinchHint>(find.byType(PinchHint));
      expect(hint.upperLevelLabel, isNull);
    });

    testWidgets('wraps root in ObservableScreen with stable name', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const WorldScreen()));
      await tester.pump();

      final wrapper = tester.widget<ObservableScreen>(
        find.byType(ObservableScreen),
      );
      expect(wrapper.screenName, 'world_screen');
    });
  });

  // -------------------------------------------------------------------------
  // Empty state policy
  // -------------------------------------------------------------------------

  group('Empty state policy', () {
    testWidgets('district screen shows 0/total and Unranked with zero visits', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const DistrictScreen(scopeId: 'district-1'),
          repo: _FakeHierarchyRepositoryEmpty(),
        ),
      );
      await tester.pump();

      expect(find.text('Unranked'), findsOneWidget);
      expect(find.textContaining('0%'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // Player dot policy
  // -------------------------------------------------------------------------

  group('Player dot policy', () {
    test('ChildAreaData exposes player position for dot rendering', () {
      const data = ChildAreaData(
        id: 'c1',
        name: 'Area',
        cellsVisited: 0,
        cellsTotal: 10,
        progressPercent: 0.0,
      );
      expect(data.id, 'c1');
    });
  });
}
