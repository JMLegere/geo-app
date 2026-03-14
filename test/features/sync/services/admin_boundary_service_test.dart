import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:earth_nova/core/models/location_node.dart';
import 'package:earth_nova/core/persistence/location_node_repository.dart';
import 'package:earth_nova/features/sync/services/admin_boundary_service.dart';

// =============================================================================
// Mocks
// =============================================================================

class MockLocationNodeRepository implements LocationNodeRepository {
  final List<LocationNode> upserted = [];
  List<LocationNode> existing = [];

  @override
  Future<void> upsert(LocationNode node) async => upserted.add(node);

  @override
  Future<List<LocationNode>> getAll() async => List.unmodifiable(existing);

  @override
  Future<LocationNode?> getByOsmId(int osmId) async {
    for (final n in existing) {
      if (n.osmId == osmId) return n;
    }
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      'MockLocationNodeRepository.${invocation.memberName}');
}

class MockFunctionsClient implements FunctionsClient {
  final List<({String functionName, Object? body})> invocations = [];

  FunctionResponse Function(String functionName, Object? body)? handler;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #invoke) {
      final name = invocation.positionalArguments[0] as String;
      final body = invocation.namedArguments[#body];
      invocations.add((functionName: name, body: body));

      if (handler != null) {
        try {
          return Future<FunctionResponse>.value(handler!(name, body));
        } catch (e) {
          return Future<FunctionResponse>.error(e);
        }
      }
      return Future<FunctionResponse>.value(
        FunctionResponse(data: null, status: 200),
      );
    }
    throw UnimplementedError('MockFunctionsClient.${invocation.memberName}');
  }
}

class MockGoTrueClient implements GoTrueClient {
  @override
  Session? get currentSession => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('MockGoTrueClient.${invocation.memberName}');
}

class MockSupabaseClient implements SupabaseClient {
  MockSupabaseClient(this.mockFunctions);

  final MockFunctionsClient mockFunctions;

  @override
  FunctionsClient get functions => mockFunctions;

  @override
  GoTrueClient get auth => MockGoTrueClient();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('MockSupabaseClient.${invocation.memberName}');
}

// =============================================================================
// Helpers
// =============================================================================

FunctionResponse _boundaryResponse(List<Map<String, Object?>> boundaries) =>
    FunctionResponse(
      status: 200,
      data: {'boundaries': boundaries},
    );

Map<String, Object?> _boundary({
  required String adminLevel,
  required String name,
  int? osmId,
  Map<String, Object?>? geometry,
}) =>
    {
      'admin_level': adminLevel,
      'name': name,
      'osm_id': osmId,
      'geometry_json':
          geometry ?? {'type': 'Polygon', 'coordinates': <Object>[]},
    };

LocationNode _makeNode({
  required String id,
  required AdminLevel adminLevel,
  String? geometryJson,
  int? osmId,
}) =>
    LocationNode(
      id: id,
      osmId: osmId,
      name: id,
      adminLevel: adminLevel,
      parentId: null,
      colorHex: null,
      geometryJson: geometryJson,
    );

// =============================================================================
// Tests
// =============================================================================

void main() {
  late MockLocationNodeRepository repo;
  late MockFunctionsClient mockFunctions;
  late MockSupabaseClient mockClient;

  setUp(() {
    repo = MockLocationNodeRepository();
    mockFunctions = MockFunctionsClient();
    mockClient = MockSupabaseClient(mockFunctions);
  });

  group('AdminBoundaryService', () {
    test('requestBoundaries upserts nodes with geometryJson to repository',
        () async {
      mockFunctions.handler = (_, __) => _boundaryResponse([
            _boundary(adminLevel: 'country', name: 'Canada', osmId: 1001),
            _boundary(adminLevel: 'state', name: 'New Brunswick', osmId: 1002),
          ]);

      final service = AdminBoundaryService(
        client: mockClient,
        repository: repo,
      );

      await service.requestBoundaries(45.9636, -66.6431);

      expect(repo.upserted, hasLength(2));
      expect(repo.upserted[0].adminLevel, AdminLevel.country);
      expect(repo.upserted[0].name, 'Canada');
      expect(repo.upserted[0].geometryJson, isNotNull);
      expect(repo.upserted[1].adminLevel, AdminLevel.state);
      expect(repo.upserted[1].name, 'New Brunswick');
      expect(repo.upserted[1].geometryJson, isNotNull);
    });

    test('callback fires with correct node IDs after upsert', () async {
      mockFunctions.handler = (_, __) => _boundaryResponse([
            _boundary(adminLevel: 'country', name: 'Canada', osmId: 1001),
            _boundary(adminLevel: 'state', name: 'New Brunswick', osmId: 1002),
          ]);

      final capturedIds = <String>[];
      final service = AdminBoundaryService(
        client: mockClient,
        repository: repo,
        onBoundariesResolved: capturedIds.addAll,
      );

      await service.requestBoundaries(45.9636, -66.6431);

      expect(capturedIds, hasLength(2));
      expect(capturedIds, contains('country_canada'));
      expect(capturedIds, contains('state_new_brunswick'));
    });

    test('deduplication: second call with same coords skips Edge Function call',
        () async {
      mockFunctions.handler = (_, __) => _boundaryResponse([
            _boundary(adminLevel: 'country', name: 'Canada', osmId: 1001),
          ]);

      final service = AdminBoundaryService(
        client: mockClient,
        repository: repo,
      );

      await service.requestBoundaries(45.9636, -66.6431);
      await service.requestBoundaries(45.9636, -66.6431);

      // Edge Function invoked only once despite two requestBoundaries calls.
      expect(mockFunctions.invocations, hasLength(1));
    });

    test('Edge Function failure: no crash and callback not fired', () async {
      mockFunctions.handler =
          (_, __) => throw const FunctionException(status: 500);

      final callbackFired = <List<String>>[];
      final service = AdminBoundaryService(
        client: mockClient,
        repository: repo,
        onBoundariesResolved: callbackFired.add,
      );

      await expectLater(
        service.requestBoundaries(45.9636, -66.6431),
        completes,
      );

      expect(callbackFired, isEmpty);
      expect(repo.upserted, isEmpty);
    });

    test('boundaries with null geometry_json are skipped', () async {
      mockFunctions.handler = (_, __) => FunctionResponse(
            status: 200,
            data: {
              'boundaries': <Map<String, Object?>>[
                {
                  'admin_level': 'country',
                  'name': 'Canada',
                  'osm_id': 1001,
                  'geometry_json': null, // null geometry — should be skipped
                },
                _boundary(adminLevel: 'state', name: 'New Brunswick'),
              ],
            },
          );

      final service = AdminBoundaryService(
        client: mockClient,
        repository: repo,
      );

      await service.requestBoundaries(45.9636, -66.6431);

      // Only the state boundary (non-null geometry) upserted.
      expect(repo.upserted, hasLength(1));
      expect(repo.upserted[0].adminLevel, AdminLevel.state);
    });

    test('existing node found by osmId is updated with new geometry', () async {
      const osmId = 9999;
      const existingNodeId = 'country_existing';
      repo.existing = [
        _makeNode(
          id: existingNodeId,
          adminLevel: AdminLevel.country,
          geometryJson: null, // no geometry yet
          osmId: osmId,
        ),
      ];

      mockFunctions.handler = (_, __) => _boundaryResponse([
            _boundary(
              adminLevel: 'country',
              name: 'Canada',
              osmId: osmId,
              geometry: {'type': 'Polygon', 'coordinates': <Object>[]},
            ),
          ]);

      final capturedIds = <String>[];
      final service = AdminBoundaryService(
        client: mockClient,
        repository: repo,
        onBoundariesResolved: capturedIds.addAll,
      );

      await service.requestBoundaries(45.9636, -66.6431);

      // Existing node's ID is used, not a newly generated one.
      expect(repo.upserted, hasLength(1));
      expect(repo.upserted[0].id, existingNodeId);
      expect(repo.upserted[0].geometryJson, isNotNull);
      expect(capturedIds, contains(existingNodeId));
    });

    test('deduplication skips call when all 4 admin levels already cached',
        () async {
      // Pre-populate repository with all 4 required levels + geometry.
      repo.existing = [
        _makeNode(
          id: 'country_canada',
          adminLevel: AdminLevel.country,
          geometryJson: '{"type":"Polygon"}',
        ),
        _makeNode(
          id: 'state_new_brunswick',
          adminLevel: AdminLevel.state,
          geometryJson: '{"type":"Polygon"}',
        ),
        _makeNode(
          id: 'city_fredericton',
          adminLevel: AdminLevel.city,
          geometryJson: '{"type":"Polygon"}',
        ),
        _makeNode(
          id: 'district_downtown',
          adminLevel: AdminLevel.district,
          geometryJson: '{"type":"Polygon"}',
        ),
      ];

      final service = AdminBoundaryService(
        client: mockClient,
        repository: repo,
      );

      await service.requestBoundaries(45.9636, -66.6431);

      // Edge Function not called because all levels are cached locally.
      expect(mockFunctions.invocations, isEmpty);
    });

    test('coords differing in 5th decimal place are treated as same location',
        () async {
      mockFunctions.handler = (_, __) => _boundaryResponse([
            _boundary(adminLevel: 'country', name: 'Canada', osmId: 1001),
          ]);

      final service = AdminBoundaryService(
        client: mockClient,
        repository: repo,
      );

      // Same to 4 decimal places → debounced.
      await service.requestBoundaries(45.96360, -66.64310);
      await service.requestBoundaries(45.96361, -66.64311); // differs at 5th

      expect(mockFunctions.invocations, hasLength(1));
    });

    test('different coords trigger separate Edge Function calls', () async {
      mockFunctions.handler = (_, __) => _boundaryResponse([
            _boundary(adminLevel: 'country', name: 'Canada', osmId: 1001),
          ]);

      final service = AdminBoundaryService(
        client: mockClient,
        repository: repo,
      );

      await service.requestBoundaries(45.9636, -66.6431);
      await service.requestBoundaries(
          48.8566, 2.3522); // Paris, different location

      expect(mockFunctions.invocations, hasLength(2));
    });

    test('empty boundaries list does not fire callback', () async {
      mockFunctions.handler = (_, __) =>
          FunctionResponse(status: 200, data: {'boundaries': <Object>[]});

      final callbackFired = <List<String>>[];
      final service = AdminBoundaryService(
        client: mockClient,
        repository: repo,
        onBoundariesResolved: callbackFired.add,
      );

      await service.requestBoundaries(45.9636, -66.6431);

      expect(callbackFired, isEmpty);
      expect(repo.upserted, isEmpty);
    });
  });
}
