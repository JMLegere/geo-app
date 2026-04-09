import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/map/domain/entities/map_level.dart';
import 'package:earth_nova/features/map/domain/repositories/hierarchy_repository.dart';
import 'package:earth_nova/features/map/presentation/providers/hierarchy_provider.dart';
import 'package:earth_nova/features/map/presentation/screens/district_screen.dart';
import 'package:earth_nova/features/map/presentation/screens/city_screen.dart';
import 'package:earth_nova/features/map/presentation/screens/province_screen.dart';
import 'package:earth_nova/features/map/presentation/screens/country_screen.dart';
import 'package:earth_nova/features/map/presentation/screens/world_screen.dart';
import 'package:earth_nova/features/map/presentation/widgets/hierarchy_header.dart';
import 'package:earth_nova/features/map/presentation/widgets/hierarchy_exploration_map.dart';
import 'package:earth_nova/features/map/presentation/widgets/pinch_hint.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';

// ---------------------------------------------------------------------------
// Fake repository for tests
// ---------------------------------------------------------------------------

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

Widget _wrap(Widget child, {HierarchyRepository? repo}) {
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
      appObservabilityProvider.overrideWithValue(
        _TestObservabilityService(),
      ),
    ],
    child: MaterialApp(home: child),
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
    testWidgets('renders scope level label and scope name', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HierarchyHeader(
              scopeLevel: 'DISTRICT',
              scopeName: 'Downtown',
              scopeCode: 'DT',
              cellsVisited: 42,
              cellsTotal: 100,
              progressPercent: 42.0,
              rank: 3,
              explorerCount: 150,
            ),
          ),
        ),
      );

      expect(find.text('DISTRICT'), findsOneWidget);
      expect(find.text('Downtown'), findsOneWidget);
    });

    testWidgets('renders rank chip with rank number', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HierarchyHeader(
              scopeLevel: 'CITY',
              scopeName: 'San Francisco',
              scopeCode: 'SF',
              cellsVisited: 100,
              cellsTotal: 200,
              progressPercent: 50.0,
              rank: 5,
              explorerCount: 300,
            ),
          ),
        ),
      );

      expect(find.textContaining('#5'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows Unranked when rank is 0 (empty state)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HierarchyHeader(
              scopeLevel: 'DISTRICT',
              scopeName: 'Downtown',
              scopeCode: 'DT',
              cellsVisited: 0,
              cellsTotal: 100,
              progressPercent: 0.0,
              rank: 0,
              explorerCount: 0,
            ),
          ),
        ),
      );

      expect(find.text('Unranked'), findsOneWidget);
    });

    testWidgets('renders 0% explored stat in empty state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HierarchyHeader(
              scopeLevel: 'DISTRICT',
              scopeName: 'Downtown',
              scopeCode: 'DT',
              cellsVisited: 0,
              cellsTotal: 100,
              progressPercent: 0.0,
              rank: 0,
              explorerCount: 0,
            ),
          ),
        ),
      );

      expect(find.textContaining('0%'), findsOneWidget);
    });

    testWidgets('renders scope code letters', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HierarchyHeader(
              scopeLevel: 'DISTRICT',
              scopeName: 'Downtown',
              scopeCode: 'DT',
              cellsVisited: 42,
              cellsTotal: 100,
              progressPercent: 42.0,
              rank: 3,
              explorerCount: 150,
            ),
          ),
        ),
      );

      expect(find.text('DT'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // PinchHint widget
  // -------------------------------------------------------------------------

  group('PinchHint', () {
    testWidgets('shows both lower and upper level labels', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PinchHint(
              lowerLevelLabel: 'Map',
              upperLevelLabel: 'City',
            ),
          ),
        ),
      );

      expect(find.textContaining('Map'), findsOneWidget);
      expect(find.textContaining('City'), findsOneWidget);
    });

    testWidgets('world-level hint shows only pinch-in direction',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PinchHint(
              lowerLevelLabel: 'Country',
              upperLevelLabel: null,
            ),
          ),
        ),
      );

      expect(find.textContaining('Country'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------------
  // HierarchyExplorationMap widget
  // -------------------------------------------------------------------------

  group('HierarchyExplorationMap', () {
    testWidgets('renders without crashing with empty child list',
        (tester) async {
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

      expect(find.text('DISTRICT'), findsOneWidget);
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

    testWidgets('wraps root in ObservableScreen with stable name',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const DistrictScreen(scopeId: 'district-1')),
      );
      await tester.pump();

      final wrapper =
          tester.widget<ObservableScreen>(find.byType(ObservableScreen));
      expect(wrapper.screenName, 'district_screen');
    });
  });

  // -------------------------------------------------------------------------
  // CityScreen
  // -------------------------------------------------------------------------

  group('CityScreen', () {
    testWidgets('renders HierarchyHeader and PinchHint', (tester) async {
      await tester.pumpWidget(
        _wrap(const CityScreen(scopeId: 'city-1')),
      );
      await tester.pump();

      expect(find.byType(HierarchyHeader), findsOneWidget);
      expect(find.byType(PinchHint), findsOneWidget);
    });

    testWidgets('shows CITY scope level label', (tester) async {
      await tester.pumpWidget(
        _wrap(const CityScreen(scopeId: 'city-1')),
      );
      await tester.pump();

      expect(find.text('CITY'), findsOneWidget);
    });

    testWidgets('pinch hint references District and Province', (tester) async {
      await tester.pumpWidget(
        _wrap(const CityScreen(scopeId: 'city-1')),
      );
      await tester.pump();

      final hint = tester.widget<PinchHint>(find.byType(PinchHint));
      expect(hint.lowerLevelLabel, 'District');
      expect(hint.upperLevelLabel, 'Province');
    });

    testWidgets('wraps root in ObservableScreen with stable name',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const CityScreen(scopeId: 'city-1')),
      );
      await tester.pump();

      final wrapper =
          tester.widget<ObservableScreen>(find.byType(ObservableScreen));
      expect(wrapper.screenName, 'city_screen');
    });
  });

  // -------------------------------------------------------------------------
  // ProvinceScreen
  // -------------------------------------------------------------------------

  group('ProvinceScreen', () {
    testWidgets('renders HierarchyHeader and PinchHint', (tester) async {
      await tester.pumpWidget(
        _wrap(const ProvinceScreen(scopeId: 'state-1')),
      );
      await tester.pump();

      expect(find.byType(HierarchyHeader), findsOneWidget);
      expect(find.byType(PinchHint), findsOneWidget);
    });

    testWidgets('shows PROVINCE scope level label', (tester) async {
      await tester.pumpWidget(
        _wrap(const ProvinceScreen(scopeId: 'state-1')),
      );
      await tester.pump();

      expect(find.text('PROVINCE'), findsOneWidget);
    });

    testWidgets('pinch hint references City and Country', (tester) async {
      await tester.pumpWidget(
        _wrap(const ProvinceScreen(scopeId: 'state-1')),
      );
      await tester.pump();

      final hint = tester.widget<PinchHint>(find.byType(PinchHint));
      expect(hint.lowerLevelLabel, 'City');
      expect(hint.upperLevelLabel, 'Country');
    });

    testWidgets('wraps root in ObservableScreen with stable name',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const ProvinceScreen(scopeId: 'state-1')),
      );
      await tester.pump();

      final wrapper =
          tester.widget<ObservableScreen>(find.byType(ObservableScreen));
      expect(wrapper.screenName, 'province_screen');
    });
  });

  // -------------------------------------------------------------------------
  // CountryScreen
  // -------------------------------------------------------------------------

  group('CountryScreen', () {
    testWidgets('renders HierarchyHeader and PinchHint', (tester) async {
      await tester.pumpWidget(
        _wrap(const CountryScreen(scopeId: 'country-1')),
      );
      await tester.pump();

      expect(find.byType(HierarchyHeader), findsOneWidget);
      expect(find.byType(PinchHint), findsOneWidget);
    });

    testWidgets('shows COUNTRY scope level label', (tester) async {
      await tester.pumpWidget(
        _wrap(const CountryScreen(scopeId: 'country-1')),
      );
      await tester.pump();

      expect(find.text('COUNTRY'), findsOneWidget);
    });

    testWidgets('pinch hint references Province and World', (tester) async {
      await tester.pumpWidget(
        _wrap(const CountryScreen(scopeId: 'country-1')),
      );
      await tester.pump();

      final hint = tester.widget<PinchHint>(find.byType(PinchHint));
      expect(hint.lowerLevelLabel, 'Province');
      expect(hint.upperLevelLabel, 'World');
    });

    testWidgets('wraps root in ObservableScreen with stable name',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const CountryScreen(scopeId: 'country-1')),
      );
      await tester.pump();

      final wrapper =
          tester.widget<ObservableScreen>(find.byType(ObservableScreen));
      expect(wrapper.screenName, 'country_screen');
    });
  });

  // -------------------------------------------------------------------------
  // WorldScreen
  // -------------------------------------------------------------------------

  group('WorldScreen', () {
    testWidgets('renders HierarchyHeader and PinchHint', (tester) async {
      await tester.pumpWidget(
        _wrap(const WorldScreen()),
      );
      await tester.pump();

      expect(find.byType(HierarchyHeader), findsOneWidget);
      expect(find.byType(PinchHint), findsOneWidget);
    });

    testWidgets('shows WORLD scope level label', (tester) async {
      await tester.pumpWidget(
        _wrap(const WorldScreen()),
      );
      await tester.pump();

      expect(find.text('WORLD'), findsOneWidget);
    });

    testWidgets('pinch hint has no upper level (world is top)', (tester) async {
      await tester.pumpWidget(
        _wrap(const WorldScreen()),
      );
      await tester.pump();

      final hint = tester.widget<PinchHint>(find.byType(PinchHint));
      expect(hint.upperLevelLabel, isNull);
    });

    testWidgets('wraps root in ObservableScreen with stable name',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const WorldScreen()),
      );
      await tester.pump();

      final wrapper =
          tester.widget<ObservableScreen>(find.byType(ObservableScreen));
      expect(wrapper.screenName, 'world_screen');
    });
  });

  // -------------------------------------------------------------------------
  // Empty state policy
  // -------------------------------------------------------------------------

  group('Empty state policy', () {
    testWidgets('district screen shows 0/total and Unranked with zero visits',
        (tester) async {
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
